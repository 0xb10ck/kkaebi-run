"""Auto-wire Sprite2D + texture into monster/boss .tscn files.

Install dependency:
    pip install Pillow

Run:
    python tools/wire_enemies_bosses.py
    python tools/wire_enemies_bosses.py --exclude scenes/enemies/m01_dokkaebibul.tscn

Scope: only modifies .tscn files under scenes/enemies, scenes/monsters,
scenes/bosses. Other categories (characters, UI, skills, tileset, main menu)
are never touched. .gd / .tres / .cfg / .godot files are never modified.
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TOOLS = Path(__file__).resolve().parent
BACKUP_DIR = TOOLS / "wire_enemies_bosses_backup"
REPORT_PATH = TOOLS / "wire_enemies_bosses_report.md"

MONSTER_SCENE_DIRS = [ROOT / "scenes" / "enemies", ROOT / "scenes" / "monsters"]
BOSS_SCENE_DIRS = [ROOT / "scenes" / "bosses"]
MONSTER_ASSET_DIRS = [ROOT / "assets" / "sprites" / "monsters", ROOT / "assets" / "monsters"]
BOSS_ASSET_DIRS = [ROOT / "assets" / "sprites" / "bosses", ROOT / "assets" / "bosses"]
MONSTER_CELL = 32
BOSS_CELL = 64

LOAD_STEPS_RE = re.compile(r"load_steps=(\d+)")


def parse_header_kv(header: str) -> dict:
    out: dict = {}
    for m in re.finditer(r'(\w+)="([^"]*)"|(\w+)=([^\s\]]+)', header):
        if m.group(1) is not None:
            out[m.group(1)] = m.group(2)
        else:
            val = m.group(4)
            try:
                out[m.group(3)] = int(val)
            except ValueError:
                out[m.group(3)] = val
    return out


def derive_slug(stem: str, kind: str) -> tuple[str, str | None]:
    m = re.match(r"^(m\d{2})_(.+)$", stem)
    if m:
        return m.group(2), stem
    m = re.match(r"^(mb\d{2}|b\d{2})_(.+)$", stem)
    if m:
        return m.group(2), stem
    if stem.startswith("enemy_"):
        return stem[6:], None
    if stem.startswith("boss_"):
        return stem[5:], None
    return stem, None


def find_asset(slug: str, full_stem: str | None, kind: str, asset_dirs: list[Path]) -> Path | None:
    candidates: list[Path] = []
    for ad in asset_dirs:
        candidates.append(ad / slug / f"{slug}.png")
        candidates.append(ad / slug / f"{slug}_idle.png")
        if full_stem:
            candidates.append(ad / full_stem / f"{full_stem}.png")
            candidates.append(ad / full_stem / f"{slug}.png")
            candidates.append(ad / full_stem / f"{full_stem}_idle.png")
        candidates.append(ad / f"{slug}.png")
    for c in candidates:
        if c.is_file():
            return c
    if kind == "monster":
        prefix_re = re.compile(rf"^m\d{{2}}_{re.escape(slug)}$")
    else:
        prefix_re = re.compile(rf"^(b\d{{2}}|mb\d{{2}})_{re.escape(slug)}$")
    for ad in asset_dirs:
        if not ad.is_dir():
            continue
        for sub in sorted(ad.iterdir()):
            if sub.is_dir() and prefix_re.match(sub.name):
                for p in (sub / f"{sub.name}.png", sub / f"{slug}.png", sub / f"{sub.name}_idle.png"):
                    if p.is_file():
                        return p
    return None


def compute_frames(img_path: Path, cell: int) -> tuple[tuple[int, int] | None, str | None]:
    with Image.open(img_path) as im:
        w, h = im.size
    if cell <= 0 or w % cell != 0 or h % cell != 0:
        return None, f"image {w}x{h} not divisible by cell {cell}"
    hframes = w // cell
    vframes = h // cell
    if hframes < 1 or vframes < 1:
        return None, f"frame count invalid ({hframes}x{vframes})"
    return (hframes, vframes), None


def res_path_for(asset_path: Path) -> str:
    return "res://" + asset_path.relative_to(ROOT).as_posix()


def parse_blocks(text: str) -> list[dict]:
    lines = text.split("\n")
    blocks: list[dict] = []
    current: dict | None = None
    for line in lines:
        if line.startswith("["):
            if current is not None:
                blocks.append(current)
            if line.startswith("[gd_scene"):
                kind = "gd_scene"
            elif line.startswith("[ext_resource"):
                kind = "ext_resource"
            elif line.startswith("[sub_resource"):
                kind = "sub_resource"
            elif line.startswith("[node"):
                kind = "node"
            else:
                kind = "other"
            current = {"kind": kind, "header": line, "body": []}
        else:
            if current is None:
                current = {"kind": "pre", "header": "", "body": [line]}
            else:
                current["body"].append(line)
    if current is not None:
        blocks.append(current)
    return blocks


def render_blocks(blocks: list[dict]) -> str:
    out: list[str] = []
    for b in blocks:
        if b["kind"] == "pre":
            out.extend(b["body"])
            continue
        out.append(b["header"])
        out.extend(b["body"])
    return "\n".join(out)


def insert_block_after(
    blocks: list[dict], after_idx: int, new_block: dict, *, transfer_trailing_blank: bool = True
) -> None:
    """Insert ``new_block`` immediately after ``blocks[after_idx]``.

    When ``transfer_trailing_blank`` is True (default — used for ext_resource
    blocks so consecutive ext_resources stay adjacent), trailing blank lines on
    the previous block are moved onto the new block. When False (used for node
    insertion so the visual blank line between sibling nodes is preserved),
    both the previous block and the new block are guaranteed to end with one
    blank line.
    """
    prev = blocks[after_idx]
    if transfer_trailing_blank:
        transferred: list[str] = []
        while prev["body"] and prev["body"][-1] == "":
            transferred.insert(0, prev["body"].pop())
        if not transferred:
            transferred = [""]
        body = list(new_block["body"])
        while body and body[-1] == "":
            body.pop()
        body.extend(transferred)
        new_block["body"] = body
    else:
        if not prev["body"] or prev["body"][-1] != "":
            prev["body"].append("")
        body = list(new_block["body"])
        if not body or body[-1] != "":
            body.append("")
        new_block["body"] = body
    blocks.insert(after_idx + 1, new_block)


def find_root_node_idx(blocks: list[dict]) -> int:
    for idx, b in enumerate(blocks):
        if b["kind"] != "node":
            continue
        attrs = parse_header_kv(b["header"])
        if "parent" not in attrs:
            return idx
    return -1


def has_animated_sprite(blocks: list[dict]) -> bool:
    for b in blocks:
        if b["kind"] != "node":
            continue
        attrs = parse_header_kv(b["header"])
        if attrs.get("type") == "AnimatedSprite2D":
            return True
    return False


def collect_root_child_names(blocks: list[dict]) -> set[str]:
    names: set[str] = set()
    for b in blocks:
        if b["kind"] != "node":
            continue
        attrs = parse_header_kv(b["header"])
        if attrs.get("parent") == ".":
            n = attrs.get("name")
            if n:
                names.add(n)
    return names


def collect_ext_resources(blocks: list[dict]) -> list[dict]:
    out: list[dict] = []
    for idx, b in enumerate(blocks):
        if b["kind"] != "ext_resource":
            continue
        attrs = parse_header_kv(b["header"])
        out.append({"idx": idx, "id": attrs.get("id"), "path": attrs.get("path"), "type": attrs.get("type")})
    return out


def find_sprite2d_block_with_texture(blocks: list[dict], ext_id_to_path: dict, target_path: str) -> int:
    for idx, b in enumerate(blocks):
        if b["kind"] != "node":
            continue
        attrs = parse_header_kv(b["header"])
        if attrs.get("type") != "Sprite2D":
            continue
        for ln in b["body"]:
            m = re.search(r'texture\s*=\s*ExtResource\("([^"]+)"\)', ln)
            if m and ext_id_to_path.get(m.group(1)) == target_path:
                return idx
    return -1


def update_sprite_body(body: list[str], ext_id: str, hframes: int, vframes: int) -> list[str]:
    target = {
        "texture": f'ExtResource("{ext_id}")',
        "hframes": str(hframes),
        "vframes": str(vframes),
        "frame": "0",
        "centered": "true",
    }
    seen: set[str] = set()
    trailing: list[str] = []
    body = list(body)
    while body and body[-1] == "":
        trailing.append(body.pop())
    new_body: list[str] = []
    for ln in body:
        m = re.match(r"^(\w+)\s*=\s*(.+)$", ln)
        if m and m.group(1) in target and m.group(1) not in seen:
            new_body.append(f"{m.group(1)} = {target[m.group(1)]}")
            seen.add(m.group(1))
        else:
            new_body.append(ln)
    for k in ("texture", "hframes", "vframes", "frame", "centered"):
        if k not in seen:
            new_body.append(f"{k} = {target[k]}")
    new_body.extend(trailing)
    return new_body


def smallest_free_int_prefix(existing_ids) -> int:
    used: set[int] = set()
    for s in existing_ids:
        if s is None:
            continue
        m = re.match(r"^(\d+)", str(s))
        if m:
            used.add(int(m.group(1)))
    n = 1
    while n in used:
        n += 1
    return n


def increment_load_steps(blocks: list[dict]) -> None:
    for b in blocks:
        if b["kind"] != "gd_scene":
            continue
        def _bump(m: re.Match) -> str:
            return f"load_steps={int(m.group(1)) + 1}"
        new_hdr, count = LOAD_STEPS_RE.subn(_bump, b["header"])
        if count == 0:
            new_hdr = b["header"].replace("[gd_scene ", "[gd_scene load_steps=2 ", 1)
        b["header"] = new_hdr
        return


def process_scene(scene_path: Path, asset_path: Path, cell: int) -> tuple[str, object]:
    text = scene_path.read_text(encoding="utf-8")
    blocks = parse_blocks(text)
    root_idx = find_root_node_idx(blocks)
    if root_idx == -1:
        return "skipped", "no root node"
    root_attrs = parse_header_kv(blocks[root_idx]["header"])
    root_type = root_attrs.get("type", "")
    if root_type in {"CollisionShape2D", "AnimatedSprite2D", "Sprite2D"}:
        return "manual", f"unsafe root type {root_type}"
    if has_animated_sprite(blocks):
        return "manual", "AnimatedSprite2D present"

    frames, err = compute_frames(asset_path, cell)
    if not frames:
        return "manual", err or "frame compute failed"
    hframes, vframes = frames

    target_res_path = res_path_for(asset_path)
    ext_resources = collect_ext_resources(blocks)
    ext_id_for_path: str | None = None
    for er in ext_resources:
        if er["path"] == target_res_path and er["type"] == "Texture2D":
            ext_id_for_path = er["id"]
            break

    added_ext = False
    if ext_id_for_path is None:
        new_int = smallest_free_int_prefix([er["id"] for er in ext_resources])
        new_ext_id = f"{new_int}_sprite_tex"
        new_header = f'[ext_resource type="Texture2D" path="{target_res_path}" id="{new_ext_id}"]'
        last_ext = -1
        gd_scene_idx = -1
        for i, b in enumerate(blocks):
            if b["kind"] == "gd_scene":
                gd_scene_idx = i
            if b["kind"] == "ext_resource":
                last_ext = i
        after_idx = last_ext if last_ext >= 0 else gd_scene_idx
        if after_idx < 0:
            return "skipped", "no gd_scene header"
        insert_block_after(blocks, after_idx, {"kind": "ext_resource", "header": new_header, "body": []})
        added_ext = True
        ext_id = new_ext_id
    else:
        ext_id = ext_id_for_path

    ext_resources = collect_ext_resources(blocks)
    ext_id_to_path = {er["id"]: er["path"] for er in ext_resources}

    existing_sprite_idx = find_sprite2d_block_with_texture(blocks, ext_id_to_path, target_res_path)
    if existing_sprite_idx != -1:
        blocks[existing_sprite_idx]["body"] = update_sprite_body(
            blocks[existing_sprite_idx]["body"], ext_id, hframes, vframes
        )
        action = "updated"
    else:
        child_names = collect_root_child_names(blocks)
        chosen = None
        for cand in ("Sprite", "Sprite2D", "Sprite2D2", "Sprite2D3", "EnemySprite", "BossSprite"):
            if cand not in child_names:
                chosen = cand
                break
        if chosen is None:
            chosen = "Sprite2DAuto"
        header = f'[node name="{chosen}" type="Sprite2D" parent="."]'
        body = [
            f'texture = ExtResource("{ext_id}")',
            f"hframes = {hframes}",
            f"vframes = {vframes}",
            "frame = 0",
            "centered = true",
        ]
        root_idx_now = find_root_node_idx(blocks)
        after_idx = root_idx_now
        insert_block_after(
            blocks,
            after_idx,
            {"kind": "node", "header": header, "body": body},
            transfer_trailing_blank=False,
        )
        action = "added"

    if added_ext:
        increment_load_steps(blocks)

    new_text = render_blocks(blocks).rstrip("\n") + "\n"

    rel = scene_path.relative_to(ROOT)
    backup_target = BACKUP_DIR / rel
    backup_target.parent.mkdir(parents=True, exist_ok=True)
    if not backup_target.exists():
        shutil.copy2(scene_path, backup_target)

    scene_path.write_text(new_text, encoding="utf-8")
    return action, {
        "asset": str(asset_path.relative_to(ROOT)),
        "hframes": hframes,
        "vframes": vframes,
        "ext_added": added_ext,
        "ext_id": ext_id,
        "node_name": chosen if action == "added" else None,
    }


def gather_scenes(dirs: list[Path]) -> list[Path]:
    out: list[Path] = []
    for d in dirs:
        if not d.is_dir():
            continue
        for p in sorted(d.iterdir()):
            if p.is_file() and p.suffix == ".tscn":
                out.append(p)
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        help="Exclude a scene path (repeatable). Path may be relative to project root.",
    )
    args = parser.parse_args(argv)

    exclude = set()
    for e in args.exclude:
        p = Path(e)
        if not p.is_absolute():
            p = ROOT / p
        try:
            exclude.add(str(p.resolve().relative_to(ROOT)))
        except ValueError:
            exclude.add(str(p))

    BACKUP_DIR.mkdir(parents=True, exist_ok=True)

    summary = {
        "monster": {"updated": 0, "added": 0, "manual": 0, "skipped": 0, "total": 0, "missing": [], "ext_added": 0, "frames": {}},
        "boss": {"updated": 0, "added": 0, "manual": 0, "skipped": 0, "total": 0, "missing": [], "ext_added": 0, "frames": {}},
    }
    details = {"monster": [], "boss": []}

    for kind, scene_dirs, asset_dirs, cell in (
        ("monster", MONSTER_SCENE_DIRS, MONSTER_ASSET_DIRS, MONSTER_CELL),
        ("boss", BOSS_SCENE_DIRS, BOSS_ASSET_DIRS, BOSS_CELL),
    ):
        for scene in gather_scenes(scene_dirs):
            rel = str(scene.relative_to(ROOT))
            summary[kind]["total"] += 1
            if rel in exclude:
                summary[kind]["skipped"] += 1
                details[kind].append(f"- `{rel}` -> **skipped** (excluded by --exclude)")
                continue
            slug, full_stem = derive_slug(scene.stem, kind)
            asset = find_asset(slug, full_stem, kind, asset_dirs)
            if asset is None:
                summary[kind]["manual"] += 1
                summary[kind]["missing"].append(rel)
                details[kind].append(f"- `{rel}` -> **manual** (no asset for slug `{slug}`)")
                continue
            action, info = process_scene(scene, asset, cell)
            if action == "added":
                summary[kind]["added"] += 1
                if isinstance(info, dict) and info.get("ext_added"):
                    summary[kind]["ext_added"] += 1
                key = f'{info["hframes"]}x{info["vframes"]}'
                summary[kind]["frames"][key] = summary[kind]["frames"].get(key, 0) + 1
                details[kind].append(
                    f"- `{rel}` -> **added** Sprite2D name=`{info['node_name']}` "
                    f"texture=`{info['asset']}` frames={info['hframes']}x{info['vframes']}"
                )
            elif action == "updated":
                summary[kind]["updated"] += 1
                if isinstance(info, dict):
                    key = f'{info["hframes"]}x{info["vframes"]}'
                    summary[kind]["frames"][key] = summary[kind]["frames"].get(key, 0) + 1
                details[kind].append(f"- `{rel}` -> **updated** existing Sprite2D")
            elif action == "manual":
                summary[kind]["manual"] += 1
                details[kind].append(f"- `{rel}` -> **manual** ({info})")
            else:
                summary[kind]["skipped"] += 1
                details[kind].append(f"- `{rel}` -> **skipped** ({info})")

    lines: list[str] = []
    lines.append("# Wire Enemies/Bosses Report")
    lines.append("")
    lines.append("## Summary")
    for kind in ("monster", "boss"):
        s = summary[kind]
        lines.append(
            f"- {kind}: total={s['total']} added={s['added']} updated={s['updated']} "
            f"manual={s['manual']} skipped={s['skipped']} new_ext_resources={s['ext_added']}"
        )
    lines.append("")
    lines.append("## Constants")
    lines.append(f"- monster cell: {MONSTER_CELL}px")
    lines.append(f"- boss cell: {BOSS_CELL}px")
    for kind in ("monster", "boss"):
        if summary[kind]["frames"]:
            stats = ", ".join(f"{k}={v}" for k, v in sorted(summary[kind]["frames"].items()))
            lines.append(f"- {kind} hframes/vframes distribution: {stats}")
    lines.append("")
    for kind in ("monster", "boss"):
        lines.append(f"## {kind.title()} scenes")
        if not details[kind]:
            lines.append("(none)")
        else:
            lines.extend(details[kind])
        lines.append("")
    for kind in ("monster", "boss"):
        miss = summary[kind]["missing"]
        if miss:
            lines.append(f"## Missing {kind} assets ({len(miss)})")
            for m in miss:
                lines.append(f"- {m}")
            lines.append("")

    REPORT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"report written: {REPORT_PATH}")
    for kind in ("monster", "boss"):
        s = summary[kind]
        print(
            f"{kind}: total={s['total']} added={s['added']} updated={s['updated']} "
            f"manual={s['manual']} skipped={s['skipped']} new_ext={s['ext_added']}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
