#!/usr/bin/env python3
"""Wire character (6) + main menu assets to .tscn files.

Strict rules (do NOT violate):
- Only .tscn files may be modified. Never edit .gd/.tres/.cfg/.godot.
- Character scene: locate root or first child Sprite2D and set texture/hframes/vframes/frame.
  If the scene uses AnimatedSprite2D, record as manual and skip (sprite_frames must not be touched).
- Main menu scene: connect Background and Logo textures, preferring named nodes.
- Each modified file is backed up to tools/wire_chars_menu_backup/<original-relpath>.
"""

from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path
from typing import Optional

from PIL import Image

REPO = Path(__file__).resolve().parent.parent
TOOLS = REPO / "tools"
BACKUP = TOOLS / "wire_chars_menu_backup"
REPORT = TOOLS / "wire_chars_menu_report.md"

CHARACTERS = ["barami", "byeolee", "dolsoe", "geurimja", "hwalee", "ttukttaki"]

BG_NAMES = ("Background", "BG", "MenuBG")
LOGO_NAMES = ("Logo", "Title", "Brand")

MAIN_MENU_BG = "res://assets/ui/main_menu_bg.png"
MAIN_MENU_LOGO = "res://assets/ui/logo.png"


# ---------------- file discovery ----------------

def find_char_scene(cid: str) -> Optional[Path]:
    p1 = REPO / "scenes" / "characters" / f"{cid}.tscn"
    p2 = REPO / "scenes" / "players" / f"{cid}.tscn"
    if p1.exists():
        return p1
    if p2.exists():
        return p2
    return None


def find_main_menu_scene() -> Optional[Path]:
    for rel in (
        "scenes/main_menu/main_menu.tscn",
        "scenes/ui/main_menu.tscn",
        "scenes/main_menu.tscn",
    ):
        p = REPO / rel
        if p.exists():
            return p
    return None


def pick_char_png(cid: str) -> Optional[Path]:
    base = REPO / "assets" / "sprites" / "characters" / cid
    for name in (f"{cid}.png", f"{cid}_idle.png"):
        p = base / name
        if p.exists():
            return p
    return None


def png_hframes(png: Path) -> tuple[Optional[int], int, int]:
    with Image.open(png) as img:
        w, h = img.size
    if h != 32 or w % 32 != 0:
        return None, w, h
    return w // 32, w, h


def backup_file(p: Path) -> None:
    rel = p.relative_to(REPO)
    target = BACKUP / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(p, target)


# ---------------- .tscn parsing ----------------

EXT_RE = re.compile(r'^\[ext_resource\s+([^\]]+)\]', re.M)
NODE_RE = re.compile(r'^\[node\s+([^\]]+)\]', re.M)
SECTION_RE = re.compile(r'^\[(node|sub_resource|ext_resource|connection|editable|resource)[^\]]*\]', re.M)
LOAD_STEPS_RE = re.compile(r'(\[gd_scene[^\]]*load_steps=)(\d+)')
GD_SCENE_RE = re.compile(r'^\[gd_scene[^\]]*\]\s*\n', re.M)


def find_ext_resources(text: str) -> list[dict]:
    out = []
    for m in EXT_RE.finditer(text):
        attrs = m.group(1)
        type_m = re.search(r'type="([^"]+)"', attrs)
        path_m = re.search(r'path="([^"]+)"', attrs)
        id_m = re.search(r'id="([^"]+)"', attrs)
        out.append({
            "type": type_m.group(1) if type_m else "",
            "path": path_m.group(1) if path_m else "",
            "id": id_m.group(1) if id_m else "",
            "start": m.start(),
            "end": m.end(),
        })
    return out


def find_node_blocks(text: str) -> list[dict]:
    headers = list(NODE_RE.finditer(text))
    blocks = []
    for i, m in enumerate(headers):
        attrs = m.group(1)
        name_m = re.search(r'name="([^"]+)"', attrs)
        type_m = re.search(r'type="([^"]+)"', attrs)
        parent_m = re.search(r'parent="([^"]+)"', attrs)
        rest = text[m.end():]
        nxt = SECTION_RE.search(rest)
        body_end = m.end() + (nxt.start() if nxt else len(rest))
        blocks.append({
            "name": name_m.group(1) if name_m else "",
            "type": type_m.group(1) if type_m else "",
            "parent": parent_m.group(1) if parent_m else "",
            "header_start": m.start(),
            "header_end": m.end(),
            "body_end": body_end,
        })
    return blocks


def ensure_ext_resource(text: str, restype: str, respath: str) -> tuple[str, Optional[str], bool]:
    """Reuse existing ext_resource for `respath`, else insert a new one with smallest free int id."""
    exts = find_ext_resources(text)
    for e in exts:
        if e["path"] == respath:
            return text, e["id"], False

    used = set()
    for e in exts:
        try:
            used.add(int(e["id"]))
        except (ValueError, TypeError):
            pass
    nid = 1
    while nid in used:
        nid += 1
    nid_s = str(nid)

    line = f'[ext_resource type="{restype}" path="{respath}" id="{nid_s}"]\n'

    if exts:
        last = exts[-1]
        nl = text.find("\n", last["end"])
        insert_pos = (nl + 1) if nl != -1 else len(text)
        new_text = text[:insert_pos] + line + text[insert_pos:]
    else:
        h = GD_SCENE_RE.search(text)
        if not h:
            return text, None, False
        insert_pos = h.end()
        new_text = text[:insert_pos] + "\n" + line + text[insert_pos:]

    new_text, n = LOAD_STEPS_RE.subn(
        lambda m: f"{m.group(1)}{int(m.group(2)) + 1}", new_text, count=1
    )
    return new_text, nid_s, True


def set_block_props(text: str, block: dict, props: list[tuple[str, str]]) -> str:
    body = text[block["header_end"]:block["body_end"]]
    for prop, val in props:
        line_re = re.compile(rf'^{re.escape(prop)}\s*=\s*.*$', re.M)
        if line_re.search(body):
            body = line_re.sub(f"{prop} = {val}", body, count=1)
        else:
            body = f"\n{prop} = {val}" + body
    return text[:block["header_end"]] + body + text[block["body_end"]:]


# ---------------- wiring ----------------

def wire_character(cid: str, scene: Path, png: Path, hframes: int, report: list[str]) -> dict:
    rec = {"cid": cid, "scene": str(scene.relative_to(REPO)), "status": "", "details": ""}
    text = scene.read_text(encoding="utf-8")
    blocks = find_node_blocks(text)
    sprite = next((b for b in blocks if b["type"] == "Sprite2D"), None)
    animated = next((b for b in blocks if b["type"] == "AnimatedSprite2D"), None)

    if sprite is None:
        if animated is not None:
            rec["status"] = "manual"
            rec["details"] = "AnimatedSprite2D present; sprite_frames must not be modified"
        else:
            rec["status"] = "manual"
            rec["details"] = "no Sprite2D node found"
        return rec

    respath = "res://" + str(png.relative_to(REPO))
    backup_file(scene)
    new_text, ext_id, added = ensure_ext_resource(text, "Texture2D", respath)
    if ext_id is None:
        rec["status"] = "manual"
        rec["details"] = "could not register ext_resource (missing gd_scene header?)"
        return rec

    blocks2 = find_node_blocks(new_text)
    target = next(
        (b for b in blocks2
         if b["name"] == sprite["name"] and b["type"] == "Sprite2D"
         and b["parent"] == sprite["parent"]),
        None,
    )
    if target is None:
        rec["status"] = "manual"
        rec["details"] = "lost track of Sprite2D after ext_resource insertion"
        return rec

    new_text = set_block_props(new_text, target, [
        ("texture", f'ExtResource("{ext_id}")'),
        ("hframes", str(hframes)),
        ("vframes", "1"),
        ("frame", "0"),
    ])

    if new_text != text:
        scene.write_text(new_text, encoding="utf-8")
        rec["status"] = "wired"
        rec["details"] = (
            f"Sprite2D `{sprite['name']}` <- `{respath}` "
            f"(id={ext_id}, hframes={hframes}, {'NEW' if added else 'reused'})"
        )
    else:
        rec["status"] = "noop"
        rec["details"] = "already wired"
    return rec


def find_named_block(blocks, names, type_filter=None, parent=".") -> Optional[dict]:
    for nm in names:
        for b in blocks:
            if b["name"] == nm and (type_filter is None or b["type"] in type_filter):
                return b
    return None


def wire_main_menu(scene: Path, report: list[str]) -> list[dict]:
    out = []
    text = scene.read_text(encoding="utf-8")
    backed_up = False

    for slot, respath, names in (
        ("background", MAIN_MENU_BG, BG_NAMES),
        ("logo", MAIN_MENU_LOGO, LOGO_NAMES),
    ):
        rec = {"slot": slot, "status": "", "details": ""}
        blocks = find_node_blocks(text)

        target = find_named_block(blocks, names, type_filter=("TextureRect", "Sprite2D"))
        if target is None:
            # Fallback: ordered TextureRect/Sprite2D scan.
            visuals = [b for b in blocks if b["type"] in ("TextureRect", "Sprite2D")]
            if slot == "background" and visuals:
                target = visuals[0]
            elif slot == "logo":
                # Prefer 2nd TextureRect, otherwise first Sprite2D child.
                tex_rects = [b for b in visuals if b["type"] == "TextureRect"]
                if len(tex_rects) >= 2:
                    target = tex_rects[1]
                else:
                    sprites = [b for b in visuals if b["type"] == "Sprite2D"]
                    if sprites:
                        target = sprites[0]
        if target is None:
            rec["status"] = "manual"
            rec["details"] = f"no suitable node found for {slot}"
            out.append(rec)
            continue

        if not backed_up:
            backup_file(scene)
            backed_up = True

        new_text, ext_id, added = ensure_ext_resource(text, "Texture2D", respath)
        if ext_id is None:
            rec["status"] = "manual"
            rec["details"] = "ext_resource registration failed"
            out.append(rec)
            continue

        blocks2 = find_node_blocks(new_text)
        target2 = next(
            (b for b in blocks2
             if b["name"] == target["name"] and b["type"] == target["type"]
             and b["parent"] == target["parent"]),
            None,
        )
        if target2 is None:
            rec["status"] = "manual"
            rec["details"] = "node lost after ext_resource insert"
            out.append(rec)
            continue

        new_text = set_block_props(new_text, target2, [
            ("texture", f'ExtResource("{ext_id}")'),
        ])

        if new_text != text:
            rec["status"] = "wired"
            rec["details"] = (
                f"{target['type']} `{target['name']}` <- `{respath}` "
                f"(id={ext_id}, {'NEW' if added else 'reused'})"
            )
            text = new_text
        else:
            rec["status"] = "noop"
            rec["details"] = (
                f"{target['type']} `{target['name']}` already wired to `{respath}` (id={ext_id})"
            )
        out.append(rec)

    # Write only if something changed.
    original = scene.read_text(encoding="utf-8")
    if text != original:
        scene.write_text(text, encoding="utf-8")
    return out


# ---------------- driver ----------------

def main() -> int:
    BACKUP.mkdir(parents=True, exist_ok=True)
    char_records: list[dict] = []
    menu_records: list[dict] = []
    notes: list[str] = []

    for cid in CHARACTERS:
        scene = find_char_scene(cid)
        if scene is None:
            char_records.append({
                "cid": cid, "scene": "",
                "status": "manual",
                "details": "no scene file at scenes/characters or scenes/players",
            })
            continue
        png = pick_char_png(cid)
        if png is None:
            char_records.append({
                "cid": cid, "scene": str(scene.relative_to(REPO)),
                "status": "manual",
                "details": "no <id>.png or <id>_idle.png under assets/sprites/characters/<id>/",
            })
            continue
        hf, w, h = png_hframes(png)
        if hf is None:
            char_records.append({
                "cid": cid, "scene": str(scene.relative_to(REPO)),
                "status": "manual",
                "details": f"unexpected sheet size {w}x{h} (need height=32, width%32==0)",
            })
            continue
        char_records.append(wire_character(cid, scene, png, hf, notes))

    menu_scene = find_main_menu_scene()
    if menu_scene is None:
        menu_records.append({
            "slot": "scene", "status": "manual",
            "details": "no main_menu.tscn found in expected locations",
        })
    else:
        for r in wire_main_menu(menu_scene, notes):
            r["scene"] = str(menu_scene.relative_to(REPO))
            menu_records.append(r)

    # ---------------- report ----------------

    changed_files: set[str] = set()
    new_ext_count = 0  # informational; we don't separately track per-file
    manual_items = 0
    wired_items = 0

    for r in char_records + menu_records:
        if r["status"] == "wired":
            wired_items += 1
            if "scene" in r and r["scene"]:
                changed_files.add(r["scene"])
            if "NEW" in r.get("details", ""):
                new_ext_count += 1
        elif r["status"] == "manual":
            manual_items += 1

    summary = []
    summary.append("# wire_chars_menu — report")
    summary.append("")
    summary.append(f"- characters processed: {len(CHARACTERS)}")
    summary.append(f"- .tscn files modified: {len(changed_files)}")
    summary.append(f"- new ext_resource entries: {new_ext_count}")
    summary.append(f"- wired actions: {wired_items}")
    summary.append(f"- manual entries: {manual_items}")
    summary.append("")
    summary.append("## Characters")
    summary.append("")
    for r in char_records:
        summary.append(
            f"- **{r['cid']}** (`{r.get('scene','')}`) — `{r['status']}` — {r['details']}"
        )
    summary.append("")
    summary.append("## Main menu")
    summary.append("")
    for r in menu_records:
        summary.append(
            f"- **{r['slot']}** (`{r.get('scene','')}`) — `{r['status']}` — {r['details']}"
        )
    summary.append("")
    summary.append("## Changed .tscn files")
    summary.append("")
    if changed_files:
        for f in sorted(changed_files):
            summary.append(f"- `{f}`")
    else:
        summary.append("- (none)")
    summary.append("")
    if notes:
        summary.append("## Notes")
        for n in notes:
            summary.append(f"- {n}")
        summary.append("")

    REPORT.write_text("\n".join(summary) + "\n", encoding="utf-8")
    print(f"wrote report: {REPORT.relative_to(REPO)}")
    print(f"changed .tscn files: {len(changed_files)}, manual entries: {manual_items}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
