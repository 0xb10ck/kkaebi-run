#!/usr/bin/env python3
"""Wire boss .tscn scenes to their sprite assets.

For each scene under scenes/bosses/ (excluding boss_arena.tscn) this script:
  1) Adds an `ext_resource` entry for the matching sprite PNG under
     `res://assets/sprites/bosses/<boss_key>/<boss_key>.png`.
  2) Bumps `load_steps` by 1.
  3) Appends a `Sprite2D` node wired to that texture, using `hframes` from
     the sprite's accompanying `.frames.json` (sheet_size / frame_size).

Idempotent: re-running on an already-wired scene leaves it unchanged.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCENES_DIR = ROOT / "scenes" / "bosses"
SPRITES_DIR = ROOT / "assets" / "sprites" / "bosses"

# scene filename (no .tscn) -> sprite key (folder under assets/sprites/bosses/)
SCENE_TO_KEY: dict[str, str] = {
    # Main bosses (b01..b06)
    "b01_dokkaebibul_daejang": "b01_dokkaebibul_daejang",
    "b02_gumiho": "b02_gumiho",
    "b03_jeoseung_saja": "b03_jeoseung_saja",
    "b04_cheondung_janggun": "b04_cheondung_janggun",
    "b05_heuk_ryong": "b05_heuk_ryong",
    "b06_daewang_dokkaebi": "b06_daewang_dokkaebi",
    # Mid bosses (mb01..mb05)
    "mb01_jangsanbeom": "mb01_jangsanbeom",
    "mb02_imugi": "mb02_imugi",
    "mb03_chagwishin": "mb03_chagwishin",
    "mb04_geumdwaeji": "mb04_geumdwaeji",
    "mb05_geomeun_dokkaebi": "mb05_geomeun_dokkaebi",
    # boss_* aliases share the same sprite as their numbered scene
    "boss_dokkaebibul_daejang": "b01_dokkaebibul_daejang",
    "boss_gumiho": "b02_gumiho",
    "boss_jeoseung_saja": "b03_jeoseung_saja",
    "boss_cheondung_janggun": "b04_cheondung_janggun",
    "boss_heuk_ryong": "b05_heuk_ryong",
    "boss_daewang_dokkaebi": "b06_daewang_dokkaebi",
    "boss_jangsanbeom": "mb01_jangsanbeom",
    "boss_imugi": "mb02_imugi",
    "boss_chagwishin": "mb03_chagwishin",
    "boss_geumdwaeji": "mb04_geumdwaeji",
    "boss_geomeun_dokkaebi": "mb05_geomeun_dokkaebi",
}

HEADER_RE = re.compile(r'^\[gd_scene\s+load_steps=(\d+)\s+format=(\d+)(.*)\]$', re.MULTILINE)
EXT_RES_RE = re.compile(r'^\[ext_resource\b[^\]]*\]', re.MULTILINE)


def hframes_for(key: str) -> int:
    """Compute hframes = sheet_size.x / frame_size.x from the boss frames.json."""
    fjson = SPRITES_DIR / key / f"{key}.frames.json"
    meta = json.loads(fjson.read_text())
    fw = int(meta["frame_size"][0])
    sw = int(meta["sheet_size"][0])
    if fw <= 0:
        raise ValueError(f"{fjson}: frame_size width must be > 0")
    if sw % fw != 0:
        raise ValueError(
            f"{fjson}: sheet width {sw} not divisible by frame width {fw}"
        )
    return sw // fw


def texture_res_path(key: str) -> str:
    return f"res://assets/sprites/bosses/{key}/{key}.png"


def wire_scene(scene_path: Path, key: str) -> str:
    """Returns one of: 'wired', 'already', 'error:<reason>'."""
    text = scene_path.read_text()
    tex_path = texture_res_path(key)

    if tex_path in text:
        return "already"

    header_match = HEADER_RE.search(text)
    if not header_match:
        return "error:no gd_scene header"

    old_load_steps = int(header_match.group(1))
    fmt = header_match.group(2)
    tail = header_match.group(3)  # e.g. ' uid="uid://..."'
    new_header = f'[gd_scene load_steps={old_load_steps + 1} format={fmt}{tail}]'
    text = text[: header_match.start()] + new_header + text[header_match.end():]

    # Pick a unique ext_resource id. Existing scenes use "1_script", "2_data";
    # "3_sprite" is reserved by convention. Bail out if it collides.
    if 'id="3_sprite"' in text:
        return "error:id 3_sprite already in use"

    ext_iter = list(EXT_RES_RE.finditer(text))
    if not ext_iter:
        return "error:no existing ext_resource to anchor insertion"
    last_ext = ext_iter[-1]
    insert_at = last_ext.end()
    new_ext = f'\n[ext_resource type="Texture2D" path="{tex_path}" id="3_sprite"]'
    text = text[:insert_at] + new_ext + text[insert_at:]

    # Append Sprite2D node. Ensure exactly one trailing newline before append.
    if not text.endswith("\n"):
        text += "\n"
    hframes = hframes_for(key)
    sprite_block = (
        '\n[node name="Sprite2D" type="Sprite2D" parent="."]\n'
        'texture = ExtResource("3_sprite")\n'
        f'hframes = {hframes}\n'
        'frame = 0\n'
    )
    text += sprite_block

    scene_path.write_text(text)
    return "wired"


def main() -> int:
    if not SCENES_DIR.is_dir():
        print(f"FATAL: {SCENES_DIR} not found", file=sys.stderr)
        return 2

    results: dict[str, list[str]] = {"wired": [], "already": [], "error": [], "missing_sprite": []}
    for stem, key in sorted(SCENE_TO_KEY.items()):
        scene = SCENES_DIR / f"{stem}.tscn"
        if not scene.is_file():
            results["error"].append(f"{stem}.tscn: scene file missing")
            continue
        png = SPRITES_DIR / key / f"{key}.png"
        if not png.is_file():
            results["missing_sprite"].append(f"{stem}.tscn -> {key}.png missing")
            continue
        outcome = wire_scene(scene, key)
        if outcome.startswith("error"):
            results["error"].append(f"{stem}.tscn: {outcome}")
        else:
            results[outcome].append(stem)

    print(f"Wired:           {len(results['wired'])}")
    for s in results["wired"]:
        print(f"  + {s}")
    print(f"Already wired:   {len(results['already'])}")
    for s in results["already"]:
        print(f"  = {s}")
    if results["missing_sprite"]:
        print(f"Missing sprite:  {len(results['missing_sprite'])}")
        for s in results["missing_sprite"]:
            print(f"  ! {s}")
    if results["error"]:
        print(f"Errors:          {len(results['error'])}")
        for s in results["error"]:
            print(f"  X {s}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
