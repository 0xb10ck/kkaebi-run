"""Scaffold Sprite2D nodes into monster scenes.

For each `scenes/enemies/mXX_*.tscn`, add a `Sprite2D` node bound to the
matching PNG under `assets/sprites/monsters/<monster_id>/`. Uses the
sprite-sheet frame count from `<monster_id>.frames.json` to set `hframes`
so only the first cell renders by default.

Idempotent: scenes that already reference the monster PNG are skipped.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCENES_DIR = REPO_ROOT / "scenes" / "enemies"
SPRITES_DIR = REPO_ROOT / "assets" / "sprites" / "monsters"

MONSTER_SCENE_RE = re.compile(r"^m\d+_.+\.tscn$")
LOAD_STEPS_RE = re.compile(r"^\[gd_scene load_steps=(\d+) format=(\d+)\]")
EXT_RESOURCE_RE = re.compile(r"^\[ext_resource\b.*\bid=\"([^\"]+)\"")


def discover_monster_scenes() -> list[Path]:
    return sorted(p for p in SCENES_DIR.iterdir() if MONSTER_SCENE_RE.match(p.name))


def monster_id_from_scene(scene_path: Path) -> str:
    return scene_path.stem


def png_res_path(monster_id: str) -> str:
    return f"res://assets/sprites/monsters/{monster_id}/{monster_id}.png"


def load_total_frames(monster_id: str) -> int:
    frames_json = SPRITES_DIR / monster_id / f"{monster_id}.frames.json"
    data = json.loads(frames_json.read_text(encoding="utf-8"))
    total = int(data.get("total_frames", 1))
    return max(total, 1)


def already_wired(text: str, png_path: str) -> bool:
    return png_path in text


def patch_scene(scene_path: Path) -> tuple[bool, str]:
    monster_id = monster_id_from_scene(scene_path)
    sprite_png = SPRITES_DIR / monster_id / f"{monster_id}.png"
    if not sprite_png.exists():
        return False, f"skip: no sprite PNG for {monster_id}"

    text = scene_path.read_text(encoding="utf-8")
    res_path = png_res_path(monster_id)
    if already_wired(text, res_path):
        return False, f"skip: {monster_id} already references sprite"

    lines = text.splitlines()

    # Bump load_steps by 1 (we add one ext_resource).
    new_lines: list[str] = []
    bumped = False
    ext_ids: list[str] = []
    last_ext_idx = -1
    for i, line in enumerate(lines):
        m = LOAD_STEPS_RE.match(line)
        if m and not bumped:
            new_steps = int(m.group(1)) + 1
            line = f"[gd_scene load_steps={new_steps} format={m.group(2)}]"
            bumped = True
        new_lines.append(line)
        em = EXT_RESOURCE_RE.match(line)
        if em:
            ext_ids.append(em.group(1))
            last_ext_idx = len(new_lines) - 1

    if not bumped:
        return False, f"skip: {monster_id} has no [gd_scene] header"
    if last_ext_idx < 0:
        return False, f"skip: {monster_id} has no existing ext_resource to anchor to"

    # Build a unique ext_resource id. Existing ids look like "1_script", "2_data".
    next_num = 1
    for eid in ext_ids:
        try:
            num = int(eid.split("_", 1)[0])
        except ValueError:
            continue
        next_num = max(next_num, num + 1)
    new_ext_id = f"{next_num}_sprite"

    ext_line = (
        f'[ext_resource type="Texture2D" path="{res_path}" id="{new_ext_id}"]'
    )
    # Insert directly after the last existing ext_resource.
    new_lines.insert(last_ext_idx + 1, ext_line)

    # Append Sprite2D node at end (child of root via parent=".").
    hframes = load_total_frames(monster_id)
    sprite_block = [
        "",
        '[node name="Sprite2D" type="Sprite2D" parent="."]',
        f'texture = ExtResource("{new_ext_id}")',
        f"hframes = {hframes}",
        "frame = 0",
    ]
    new_lines.extend(sprite_block)

    # Preserve trailing newline if original had one.
    out = "\n".join(new_lines)
    if text.endswith("\n") and not out.endswith("\n"):
        out += "\n"

    scene_path.write_text(out, encoding="utf-8")
    return True, f"wired: {scene_path.name} -> {res_path} (hframes={hframes})"


def main() -> int:
    scenes = discover_monster_scenes()
    if not scenes:
        print("no monster scenes found", file=sys.stderr)
        return 1

    changed = 0
    for scene in scenes:
        ok, msg = patch_scene(scene)
        print(msg)
        if ok:
            changed += 1

    print(f"\nDone. Scenes changed: {changed}/{len(scenes)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
