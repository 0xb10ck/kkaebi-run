#!/usr/bin/env python3
"""Batch-inject Sprite2D + texture into enemy/boss .tscn scenes.

- Scope: scenes/enemies/*.tscn, scenes/monsters/*.tscn (if exists), scenes/bosses/*.tscn
- Only modifies .tscn files. Never touches .gd / .tres / .cfg / .godot.
- Backs up original files to tools/wire_sprite2d_backup/<relative_path> before edit.
- Writes report to tools/wire_sprite2d_report.md.
"""
from __future__ import annotations

import os
import re
import shutil
import struct
import sys
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BACKUP_DIR = ROOT / "tools" / "wire_sprite2d_backup"
REPORT_PATH = ROOT / "tools" / "wire_sprite2d_report.md"

TARGET_DIRS = [
    ("enemies", ROOT / "scenes" / "enemies"),
    ("monsters", ROOT / "scenes" / "monsters"),
    ("bosses", ROOT / "scenes" / "bosses"),
]

MONSTER_NUM_RE = re.compile(r"^(m\d{2}_.+)\.tscn$")
BOSS_NUM_RE = re.compile(r"^((?:b|mb)\d{2}_.+)\.tscn$")
BOSS_PREFIX_RE = re.compile(r"^(boss_.+)\.tscn$")
ENEMY_PREFIX_RE = re.compile(r"^(enemy_.+)\.tscn$")

EXT_RES_RE = re.compile(
    r'^\[ext_resource\s+type="([^"]+)"\s+path="([^"]+)"\s+id="([^"]+)"\]\s*$'
)
NODE_HEADER_RE = re.compile(r'^\[node\s+name="([^"]+)"\s+type="([^"]+)"(?:\s+parent="([^"]*)")?')


def png_dimensions(png_path: Path):
    try:
        with open(png_path, "rb") as f:
            header = f.read(24)
        if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
            return None
        if header[12:16] != b"IHDR":
            return None
        width, height = struct.unpack(">II", header[16:24])
        return int(width), int(height)
    except OSError:
        return None


def classify_scene(scope: str, filename: str):
    """Return (stem, expected_png_relpath, cell_size, label) or None."""
    if scope in ("enemies", "monsters"):
        m = MONSTER_NUM_RE.match(filename)
        if m:
            stem = m.group(1)
            return stem, f"assets/sprites/monsters/{stem}/{stem}.png", 32, "monster_num"
        m = ENEMY_PREFIX_RE.match(filename)
        if m:
            stem = m.group(1)
            slug = stem[len("enemy_"):]
            cand1 = ROOT / "assets" / "sprites" / "monsters" / slug / f"{slug}.png"
            cand2 = ROOT / "assets" / "sprites" / "enemies" / f"{stem}.png"
            if cand1.exists():
                return slug, f"assets/sprites/monsters/{slug}/{slug}.png", 32, "enemy_prefix"
            if cand2.exists():
                return stem, f"assets/sprites/enemies/{stem}.png", 32, "enemy_prefix"
            return None
    elif scope == "bosses":
        m = BOSS_NUM_RE.match(filename)
        if m:
            stem = m.group(1)
            return stem, f"assets/sprites/bosses/{stem}/{stem}.png", 64, "boss_num"
        m = BOSS_PREFIX_RE.match(filename)
        if m:
            stem = m.group(1)
            cand1 = ROOT / "assets" / "sprites" / "bosses" / stem / f"{stem}.png"
            cand2 = ROOT / "assets" / "sprites" / "bosses" / f"{stem}.png"
            if cand1.exists():
                return stem, f"assets/sprites/bosses/{stem}/{stem}.png", 64, "boss_prefix"
            if cand2.exists():
                return stem, f"assets/sprites/bosses/{stem}.png", 64, "boss_prefix"
            return None
    return None


def compute_frames(png_w: int, png_h: int, cell: int):
    if png_w % cell != 0 or png_h % cell != 0:
        return None, None
    if png_h == cell:
        return png_w // cell, 1
    return png_w // cell, png_h // cell


def parse_ext_resources(lines):
    out = []
    for i, line in enumerate(lines):
        m = EXT_RES_RE.match(line)
        if m:
            out.append((i, m.group(1), m.group(2), m.group(3)))
    return out


def find_gd_scene_line(lines):
    for i, line in enumerate(lines):
        if line.startswith("[gd_scene"):
            return i
    return -1


def update_load_steps(line: str, delta: int) -> str:
    m = re.search(r'load_steps=(\d+)', line)
    if not m:
        if "load_steps=" not in line:
            return re.sub(r'\[gd_scene\s+', f'[gd_scene load_steps={1 + delta} ', line, count=1)
        return line
    new_val = int(m.group(1)) + delta
    return line[:m.start(1)] + str(new_val) + line[m.end(1):]


def smallest_unused_int_id(existing_ids):
    n = 1
    while str(n) in existing_ids:
        n += 1
    return str(n)


def find_root_node_line(lines):
    for i, line in enumerate(lines):
        m = NODE_HEADER_RE.match(line)
        if m and m.group(3) is None:
            return i
    return -1


def find_existing_sprite_block(lines):
    """Find root-child Sprite/Sprite2D node block. Returns (start, end, type, name) or None."""
    for i, line in enumerate(lines):
        m = NODE_HEADER_RE.match(line)
        if not m:
            continue
        ntype, parent = m.group(2), m.group(3)
        if parent != ".":
            continue
        if ntype in ("Sprite2D", "Sprite"):
            j = i + 1
            while j < len(lines):
                stripped = lines[j].lstrip()
                if stripped.startswith("[") and "]" in stripped:
                    break
                j += 1
            return (i, j, ntype, m.group(1))
    return None


def has_animated_sprite(lines):
    for line in lines:
        m = NODE_HEADER_RE.match(line)
        if m and m.group(2) == "AnimatedSprite2D":
            return True
    return False


def patch_scene(scene_path: Path, png_relpath: str, cell: int):
    result = {
        "path": str(scene_path.relative_to(ROOT)),
        "status": "skipped",
        "reason": "",
        "ext_added": False,
        "ext_id": "",
        "hframes": None,
        "vframes": None,
        "png_size": None,
    }

    png_abs = ROOT / png_relpath
    if not png_abs.exists():
        result["status"] = "manual"
        result["reason"] = f"missing PNG: {png_relpath}"
        return result
    # Godot requires a sibling .png.import for the resource loader to recognize the texture.
    if not (png_abs.parent / (png_abs.name + ".import")).exists():
        result["status"] = "manual"
        result["reason"] = f"missing .import for PNG: {png_relpath}"
        return result

    text = scene_path.read_text(encoding="utf-8")
    trailing_newline = text.endswith("\n")
    lines = text.split("\n")
    if trailing_newline and lines and lines[-1] == "":
        lines.pop()

    if has_animated_sprite(lines):
        result["status"] = "manual"
        result["reason"] = "AnimatedSprite2D present"
        return result

    dims = png_dimensions(png_abs)
    if dims is None:
        result["status"] = "manual"
        result["reason"] = "PNG header parse failed"
        return result
    pw, ph = dims
    result["png_size"] = (pw, ph)
    hframes, vframes = compute_frames(pw, ph, cell)
    result["hframes"], result["vframes"] = hframes, vframes

    res_path = f"res://{png_relpath}"

    ext_list = parse_ext_resources(lines)
    existing_ids = {e[3] for e in ext_list}
    matched_id = None
    for _, etype, epath, eid in ext_list:
        if epath == res_path and etype == "Texture2D":
            matched_id = eid
            break

    ext_added = False
    if matched_id is None:
        new_id = smallest_unused_int_id(existing_ids)
        new_ext_line = f'[ext_resource type="Texture2D" path="{res_path}" id="{new_id}"]'
        if ext_list:
            insert_after = ext_list[-1][0]
        else:
            insert_after = find_gd_scene_line(lines)
        lines.insert(insert_after + 1, new_ext_line)
        gd_idx = find_gd_scene_line(lines)
        if gd_idx >= 0:
            lines[gd_idx] = update_load_steps(lines[gd_idx], +1)
        matched_id = new_id
        ext_added = True

    result["ext_id"] = matched_id
    result["ext_added"] = ext_added

    sprite_lines = [
        '[node name="Sprite" type="Sprite2D" parent="."]',
        f'texture = ExtResource("{matched_id}")',
        'centered = true',
    ]
    if hframes is not None and vframes is not None:
        sprite_lines.append(f'hframes = {hframes}')
        if vframes > 1:
            sprite_lines.append(f'vframes = {vframes}')
    sprite_lines.append('frame = 0')

    existing = find_existing_sprite_block(lines)
    if existing is not None:
        start, end, _ntype, _name = existing
        block = lines[start:end]
        new_block = [block[0]]
        seen = set()
        for ln in block[1:]:
            ls = ln.strip()
            if ls.startswith("texture ="):
                new_block.append(f'texture = ExtResource("{matched_id}")')
                seen.add("texture")
            elif ls.startswith("hframes ="):
                if hframes is not None:
                    new_block.append(f'hframes = {hframes}')
                    seen.add("hframes")
            elif ls.startswith("vframes ="):
                if hframes is not None and vframes is not None and vframes > 1:
                    new_block.append(f'vframes = {vframes}')
                    seen.add("vframes")
            elif ls.startswith("frame ="):
                new_block.append('frame = 0')
                seen.add("frame")
            else:
                new_block.append(ln)
        if "texture" not in seen:
            new_block.append(f'texture = ExtResource("{matched_id}")')
        if hframes is not None and "hframes" not in seen:
            new_block.append(f'hframes = {hframes}')
        if hframes is not None and vframes is not None and vframes > 1 and "vframes" not in seen:
            new_block.append(f'vframes = {vframes}')
        if "frame" not in seen:
            new_block.append('frame = 0')
        lines[start:end] = new_block
        result["status"] = "updated_existing"
    else:
        root_idx = find_root_node_line(lines)
        if root_idx < 0:
            result["status"] = "skipped"
            result["reason"] = "no root node found"
            return result
        j = root_idx + 1
        while j < len(lines):
            stripped = lines[j].lstrip()
            if stripped.startswith("[") and "]" in stripped:
                break
            j += 1
        insert_block = []
        if j > 0 and lines[j - 1].strip() != "":
            insert_block.append("")
        insert_block.extend(sprite_lines)
        insert_block.append("")
        lines[j:j] = insert_block
        result["status"] = "updated"

    new_text = "\n".join(lines)
    if trailing_newline and not new_text.endswith("\n"):
        new_text += "\n"

    rel = scene_path.relative_to(ROOT)
    backup_path = BACKUP_DIR / rel
    backup_path.parent.mkdir(parents=True, exist_ok=True)
    if not backup_path.exists():
        shutil.copy2(scene_path, backup_path)

    scene_path.write_text(new_text, encoding="utf-8")
    return result


def main():
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    excluded_stems = set()
    if len(sys.argv) > 2 and sys.argv[1] == "--exclude":
        excluded_stems = set(s for s in sys.argv[2].split(",") if s)

    all_results = []
    summary = OrderedDict()
    for scope, dpath in TARGET_DIRS:
        scope_results = []
        if not dpath.exists():
            summary[scope] = {"total": 0, "updated": 0, "updated_existing": 0,
                              "manual": 0, "skipped": 0, "ext_added": 0}
            all_results.append((scope, scope_results))
            continue
        files = sorted(dpath.glob("*.tscn"))
        for f in files:
            classification = classify_scene(scope, f.name)
            if classification is None:
                scope_results.append({
                    "path": str(f.relative_to(ROOT)),
                    "status": "skipped",
                    "reason": "pattern mismatch or no PNG",
                    "ext_added": False, "ext_id": "",
                    "hframes": None, "vframes": None, "png_size": None,
                })
                continue
            stem, png_rel, cell, label = classification
            if stem in excluded_stems:
                scope_results.append({
                    "path": str(f.relative_to(ROOT)),
                    "status": "skipped",
                    "reason": "excluded via --exclude",
                    "ext_added": False, "ext_id": "",
                    "hframes": None, "vframes": None, "png_size": None,
                })
                continue
            res = patch_scene(f, png_rel, cell)
            res["label"] = label
            res["stem"] = stem
            scope_results.append(res)
        s = {"total": len(scope_results), "updated": 0, "updated_existing": 0,
             "manual": 0, "skipped": 0, "ext_added": 0}
        for r in scope_results:
            if r["status"] == "updated":
                s["updated"] += 1
            elif r["status"] == "updated_existing":
                s["updated_existing"] += 1
            elif r["status"] == "manual":
                s["manual"] += 1
            else:
                s["skipped"] += 1
            if r.get("ext_added"):
                s["ext_added"] += 1
        summary[scope] = s
        all_results.append((scope, scope_results))

    out = []
    out.append("# wire_sprite2d report")
    out.append("")
    out.append("## Summary")
    out.append("")
    out.append("| scope | total | updated | updated_existing | manual | skipped | new ext_resource |")
    out.append("|---|---|---|---|---|---|---|")
    for scope, s in summary.items():
        out.append(f"| {scope} | {s['total']} | {s['updated']} | {s['updated_existing']} | "
                   f"{s['manual']} | {s['skipped']} | {s['ext_added']} |")
    out.append("")
    out.append("## hframes/vframes statistics")
    out.append("")
    hf_counter = {}
    for _, results in all_results:
        for r in results:
            if r["status"] in ("updated", "updated_existing") and r["hframes"] is not None:
                key = f"hframes={r['hframes']},vframes={r['vframes']}"
                hf_counter[key] = hf_counter.get(key, 0) + 1
    if hf_counter:
        for k, v in sorted(hf_counter.items()):
            out.append(f"- {k}: {v}")
    else:
        out.append("- (none)")
    out.append("")
    out.append("## Manual / missing PNG list")
    out.append("")
    any_manual = False
    for scope, results in all_results:
        for r in results:
            if r["status"] == "manual":
                any_manual = True
                out.append(f"- [{scope}] {r['path']}: {r['reason']}")
    if not any_manual:
        out.append("- (none)")
    out.append("")
    out.append("## Per-file details")
    out.append("")
    for scope, results in all_results:
        out.append(f"### {scope}")
        out.append("")
        for r in results:
            extra = ""
            if r.get("png_size"):
                extra += f" size={r['png_size'][0]}x{r['png_size'][1]}"
            if r.get("hframes") is not None:
                extra += f" hframes={r['hframes']} vframes={r['vframes']}"
            if r.get("ext_added"):
                extra += " ext_added"
            if r.get("ext_id"):
                extra += f" ext_id={r['ext_id']}"
            line = f"- [{r['status']}] {r['path']}{extra}"
            if r.get("reason"):
                line += f" ({r['reason']})"
            out.append(line)
        out.append("")

    REPORT_PATH.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"Report written: {REPORT_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
