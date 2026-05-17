#!/usr/bin/env python3
"""Asset/scene inventory collector.

Scans assets/ and scenes/ trees, produces:
- tools/wire_assets/inventory.json — machine-readable matches
- tools/wire_assets/inventory.md   — human report split into ready / manual

Conservative: only reports what scenes already contain texture-bearing
target nodes (Sprite2D / AnimatedSprite2D / TextureRect / NinePatchRect / TileMap).
Anything else is recorded as manual.
"""

from __future__ import annotations

import json
import os
import re
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Optional

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow not installed. Run: pip install Pillow", file=sys.stderr)
    sys.exit(2)


ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets"
SCENES = ROOT / "scenes"
OUT_DIR = Path(__file__).resolve().parent
OUT_JSON = OUT_DIR / "inventory.json"
OUT_MD = OUT_DIR / "inventory.md"


# ---- UI mapping table (asset -> scene + node + node_type) ----
# Each tuple: (asset_relpath_under_assets, scene_relpath_under_scenes, node_path, expected_node_type)
UI_MAP: list[tuple[str, str, str, str]] = [
    ("ui/main_menu_bg.png",     "main_menu/main_menu.tscn", "Background",            "TextureRect"),
    ("ui/logo.png",             "main_menu/main_menu.tscn", "Logo",                  "TextureRect"),
    ("ui/button_normal.png",    "main_menu/main_menu.tscn", "Buttons/StartButton",   "Button"),
    ("ui/button_hover.png",     "main_menu/main_menu.tscn", "Buttons/StartButton",   "Button"),
    ("ui/button_pressed.png",   "main_menu/main_menu.tscn", "Buttons/StartButton",   "Button"),
    ("ui/panel_frame.png",      "ui/pause_menu.tscn",       "Panel",                 "NinePatchRect"),
    ("ui/hp_bar_frame.png",     "ui/hud.tscn",              "HPBarFrame",            "NinePatchRect"),
    ("ui/hp_bar_fill.png",      "ui/hud.tscn",              "HPBarFill",             "TextureRect"),
    ("ui/skill_icon_frame.png", "ui/hud.tscn",              "SkillIconFrame",        "NinePatchRect"),
    ("ui/level_up_bg.png",      "ui/level_up_panel.tscn",   "Background",            "TextureRect"),
]


# Node types eligible for automatic texture wiring.
WIRABLE_NODE_TYPES = {
    "Sprite2D", "AnimatedSprite2D", "TextureRect", "NinePatchRect", "TileMap",
}


@dataclass
class Entry:
    kind: str
    scene_path: str
    target_node: Optional[str]
    target_node_type: Optional[str]
    asset_path: str
    asset_size: list[int]
    hframes: int
    vframes: int
    suggested_action: str
    note: str = ""


# ---- scene parsing helpers ----

NODE_HEADER_RE = re.compile(
    r'^\[node\s+name="([^"]+)"(?:\s+type="([^"]+)")?(?:\s+parent="([^"]*)")?'
)


def parse_scene_nodes(scene_file: Path) -> dict[str, str]:
    """Return mapping of full node path -> node type for a .tscn file.

    Root node has parent absent. Children use parent="." or "Parent/Sub".
    """
    nodes: dict[str, str] = {}
    root_name: Optional[str] = None
    try:
        text = scene_file.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return nodes

    # Track most recent node header. Inherited instance nodes may have no type;
    # we only care about explicit types here (wiring targets), so skip those.
    for line in text.splitlines():
        if not line.startswith("[node "):
            continue
        m = NODE_HEADER_RE.match(line)
        if not m:
            continue
        name, ntype, parent = m.group(1), m.group(2), m.group(3)
        if parent is None:
            root_name = name
            if ntype:
                nodes[name] = ntype
        else:
            if parent == ".":
                full = f"{root_name}/{name}" if root_name else name
            elif root_name is not None:
                full = f"{root_name}/{parent}/{name}"
            else:
                full = f"{parent}/{name}"
            # Also store node by its non-rooted path (used to look up by node path).
            if ntype:
                nodes[full] = ntype
                # Also index by path without root prefix (callers usually know that form).
                without_root = full.split("/", 1)[1] if "/" in full else full
                nodes.setdefault(without_root, ntype)
    return nodes


def find_node_type(nodes: dict[str, str], wanted_path: str) -> Optional[str]:
    """Resolve a wanted node path against parsed nodes (with/without root prefix)."""
    if wanted_path in nodes:
        return nodes[wanted_path]
    # Try matching by suffix (when parsed node path includes root prefix).
    for full, ntype in nodes.items():
        if full == wanted_path:
            return ntype
        if full.endswith("/" + wanted_path):
            return ntype
    return None


# ---- asset metadata helpers ----

def read_image_size(path: Path) -> tuple[int, int]:
    with Image.open(path) as im:
        return im.size  # (w, h)


def read_frames_meta(asset_png: Path) -> tuple[int, int]:
    """Return (hframes, vframes). Defaults to (1, 1) when no metadata.

    Looks for:
      <stem>.frames.json next to the file (new format with frame_size/sheet_size)
      <stem>.json (legacy idle metadata with size+frames)
    """
    for sibling in (
        asset_png.with_suffix("").with_suffix(".frames.json"),
        asset_png.with_suffix(".json"),
        asset_png.with_suffix("").parent / (asset_png.stem + ".frames.json"),
        asset_png.with_suffix("").parent / (asset_png.stem + ".json"),
    ):
        if sibling.exists():
            try:
                meta = json.loads(sibling.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError, UnicodeDecodeError):
                continue
            if "frame_size" in meta and "sheet_size" in meta:
                fw, fh = meta["frame_size"][0], meta["frame_size"][1]
                sw, sh = meta["sheet_size"][0], meta["sheet_size"][1]
                hf = max(1, sw // max(1, fw))
                vf = max(1, sh // max(1, fh))
                return hf, vf
            if "size" in meta and "frames" in meta:
                # legacy hstrip
                return int(meta["frames"]), 1
    # Fallback: infer from image dimensions assuming square frames at min(w, h).
    try:
        w, h = read_image_size(asset_png)
        frame = min(w, h)
        if frame > 0:
            return max(1, w // frame), max(1, h // frame)
    except Exception:
        pass
    return 1, 1


def res_path(asset: Path) -> str:
    rel = asset.relative_to(ROOT).as_posix()
    return f"res://{rel}"


# ---- collectors ----

def collect_characters() -> list[Entry]:
    entries: list[Entry] = []
    char_dir = ASSETS / "sprites" / "characters"
    if not char_dir.exists():
        return entries
    for sub in sorted(char_dir.iterdir()):
        if not sub.is_dir():
            continue
        cid = sub.name
        # Prefer <id>/<id>_idle.png per spec, fall back to <id>/<id>.png.
        candidates = [
            sub / f"{cid}_idle.png",
            sub / f"{cid}.png",
            char_dir / f"{cid}_idle.png",
        ]
        png = next((p for p in candidates if p.exists()), None)
        if png is None:
            continue
        scene_candidates = [
            SCENES / "characters" / f"{cid}.tscn",
            SCENES / "players" / f"{cid}.tscn",
            SCENES / "player" / f"{cid}.tscn",
        ]
        scene = next((s for s in scene_candidates if s.exists()), None)
        size = list(read_image_size(png))
        hf, vf = read_frames_meta(png)
        if scene is None:
            entries.append(Entry(
                kind="character",
                scene_path="",
                target_node=None,
                target_node_type=None,
                asset_path=res_path(png),
                asset_size=size,
                hframes=hf,
                vframes=vf,
                suggested_action="missing_scene",
                note=f"no character scene for {cid}",
            ))
            continue
        nodes = parse_scene_nodes(scene)
        # Look for a Sprite2D / AnimatedSprite2D child of the root.
        target_node, target_type = _first_wirable(nodes, prefer=("Sprite2D", "AnimatedSprite2D"))
        entries.append(Entry(
            kind="character",
            scene_path=res_path(scene),
            target_node=target_node,
            target_node_type=target_type,
            asset_path=res_path(png),
            asset_size=size,
            hframes=hf,
            vframes=vf,
            suggested_action=_action_for(target_type),
            note="" if target_node else "no Sprite2D/AnimatedSprite2D in scene",
        ))
    return entries


def collect_monsters() -> list[Entry]:
    entries: list[Entry] = []
    base = ASSETS / "sprites" / "monsters"
    if not base.exists():
        return entries
    for sub in sorted(base.iterdir()):
        if not sub.is_dir():
            continue
        slug = sub.name
        png = sub / f"{slug}.png"
        if not png.exists():
            continue
        scene = SCENES / "enemies" / f"{slug}.tscn"
        size = list(read_image_size(png))
        hf, vf = read_frames_meta(png)
        if not scene.exists():
            entries.append(Entry(
                kind="monster",
                scene_path="",
                target_node=None,
                target_node_type=None,
                asset_path=res_path(png),
                asset_size=size,
                hframes=hf,
                vframes=vf,
                suggested_action="missing_scene",
                note=f"no enemy scene for {slug}",
            ))
            continue
        nodes = parse_scene_nodes(scene)
        target_node, target_type = _first_wirable(nodes, prefer=("Sprite2D", "AnimatedSprite2D"))
        entries.append(Entry(
            kind="monster",
            scene_path=res_path(scene),
            target_node=target_node,
            target_node_type=target_type,
            asset_path=res_path(png),
            asset_size=size,
            hframes=hf,
            vframes=vf,
            suggested_action=_action_for(target_type),
            note="" if target_node else "no Sprite2D/AnimatedSprite2D in scene",
        ))
    return entries


def collect_bosses() -> list[Entry]:
    entries: list[Entry] = []
    base = ASSETS / "sprites" / "bosses"
    if not base.exists():
        return entries
    for sub in sorted(base.iterdir()):
        if not sub.is_dir():
            continue
        slug = sub.name
        png = sub / f"{slug}.png"
        if not png.exists():
            continue
        # Preferred scene names: <slug>.tscn, then boss_<rest>.tscn where rest = slug w/o leading b\d+_|mb\d+_
        scene_candidates = [SCENES / "bosses" / f"{slug}.tscn"]
        m = re.match(r"^(?:m?b\d+_)(.+)$", slug)
        if m:
            rest = m.group(1)
            scene_candidates.append(SCENES / "bosses" / f"boss_{rest}.tscn")
        scene = next((s for s in scene_candidates if s.exists()), None)
        size = list(read_image_size(png))
        hf, vf = read_frames_meta(png)
        if scene is None:
            entries.append(Entry(
                kind="boss",
                scene_path="",
                target_node=None,
                target_node_type=None,
                asset_path=res_path(png),
                asset_size=size,
                hframes=hf,
                vframes=vf,
                suggested_action="missing_scene",
                note=f"no boss scene for {slug}",
            ))
            continue
        nodes = parse_scene_nodes(scene)
        target_node, target_type = _first_wirable(nodes, prefer=("Sprite2D", "AnimatedSprite2D"))
        entries.append(Entry(
            kind="boss",
            scene_path=res_path(scene),
            target_node=target_node,
            target_node_type=target_type,
            asset_path=res_path(png),
            asset_size=size,
            hframes=hf,
            vframes=vf,
            suggested_action=_action_for(target_type),
            note="" if target_node else "no Sprite2D/AnimatedSprite2D in scene",
        ))
    return entries


def collect_effects() -> list[Entry]:
    entries: list[Entry] = []
    base = ASSETS / "sprites" / "effects"
    if not base.exists():
        return entries
    for sub in sorted(base.iterdir()):
        if not sub.is_dir():
            continue
        skill_id = sub.name
        png = sub / f"{skill_id}.png"
        if not png.exists():
            continue
        scene = SCENES / "skills" / f"{skill_id}.tscn"
        size = list(read_image_size(png))
        hf, vf = read_frames_meta(png)
        if not scene.exists():
            entries.append(Entry(
                kind="effect",
                scene_path="",
                target_node=None,
                target_node_type=None,
                asset_path=res_path(png),
                asset_size=size,
                hframes=hf,
                vframes=vf,
                suggested_action="missing_scene",
                note=f"no skill scene for {skill_id}",
            ))
            continue
        nodes = parse_scene_nodes(scene)
        target_node, target_type = _first_wirable(nodes, prefer=("Sprite2D", "AnimatedSprite2D"))
        entries.append(Entry(
            kind="effect",
            scene_path=res_path(scene),
            target_node=target_node,
            target_node_type=target_type,
            asset_path=res_path(png),
            asset_size=size,
            hframes=hf,
            vframes=vf,
            suggested_action=_action_for(target_type),
            note="" if target_node else "no Sprite2D/AnimatedSprite2D in scene",
        ))
    return entries


def collect_ui() -> list[Entry]:
    entries: list[Entry] = []
    for asset_rel, scene_rel, node_path, expected_type in UI_MAP:
        asset = ASSETS / asset_rel
        scene = SCENES / scene_rel
        if not asset.exists():
            entries.append(Entry(
                kind="ui",
                scene_path=(res_path(scene) if scene.exists() else ""),
                target_node=node_path,
                target_node_type=expected_type,
                asset_path=f"res://assets/{asset_rel}",
                asset_size=[0, 0],
                hframes=1,
                vframes=1,
                suggested_action="missing_asset",
                note=f"asset not found: {asset_rel}",
            ))
            continue
        size = list(read_image_size(asset))
        if not scene.exists():
            entries.append(Entry(
                kind="ui",
                scene_path="",
                target_node=node_path,
                target_node_type=expected_type,
                asset_path=res_path(asset),
                asset_size=size,
                hframes=1,
                vframes=1,
                suggested_action="missing_scene",
                note=f"scene not found: {scene_rel}",
            ))
            continue
        nodes = parse_scene_nodes(scene)
        found_type = find_node_type(nodes, node_path)
        if found_type is None:
            entries.append(Entry(
                kind="ui",
                scene_path=res_path(scene),
                target_node=node_path,
                target_node_type=expected_type,
                asset_path=res_path(asset),
                asset_size=size,
                hframes=1,
                vframes=1,
                suggested_action="manual_add_node",
                note=f"node {node_path} not present in {scene_rel}",
            ))
        elif found_type not in WIRABLE_NODE_TYPES:
            entries.append(Entry(
                kind="ui",
                scene_path=res_path(scene),
                target_node=node_path,
                target_node_type=found_type,
                asset_path=res_path(asset),
                asset_size=size,
                hframes=1,
                vframes=1,
                suggested_action="manual_replace_node",
                note=f"node {node_path} is {found_type}, expected {expected_type}",
            ))
        else:
            entries.append(Entry(
                kind="ui",
                scene_path=res_path(scene),
                target_node=node_path,
                target_node_type=found_type,
                asset_path=res_path(asset),
                asset_size=size,
                hframes=1,
                vframes=1,
                suggested_action="wire_texture",
            ))
    return entries


def collect_tilesets() -> list[Entry]:
    entries: list[Entry] = []
    base = ASSETS / "tilesets"
    if not base.exists():
        return entries
    for sub in sorted(base.iterdir()):
        if not sub.is_dir():
            continue
        chapter_id = sub.name
        png = sub / f"{chapter_id}_tiles.png"
        if not png.exists():
            continue
        scene_candidates = [
            SCENES / "chapters" / f"{chapter_id}_run.tscn",
            SCENES / "run" / f"{chapter_id}.tscn",
        ]
        scene = next((s for s in scene_candidates if s.exists()), None)
        size = list(read_image_size(png))
        if scene is None:
            entries.append(Entry(
                kind="tileset",
                scene_path="",
                target_node=None,
                target_node_type=None,
                asset_path=res_path(png),
                asset_size=size,
                hframes=1,
                vframes=1,
                suggested_action="missing_scene",
                note=f"no chapter run scene for {chapter_id}",
            ))
            continue
        nodes = parse_scene_nodes(scene)
        target_node = None
        target_type = None
        for want in ("GroundLayer", "TileMap"):
            t = find_node_type(nodes, want)
            if t is not None:
                target_node = want
                target_type = t
                break
        if target_node is None:
            entries.append(Entry(
                kind="tileset",
                scene_path=res_path(scene),
                target_node=None,
                target_node_type=None,
                asset_path=res_path(png),
                asset_size=size,
                hframes=1,
                vframes=1,
                suggested_action="manual_add_node",
                note=f"no GroundLayer/TileMap in {scene.name}",
            ))
            continue
        # tile_set itself must not be touched; only the texture slot of the TileMap
        # can be wired, and only when the existing tile_set already references a texture.
        # That requires deeper parsing of tile_set sub-resources; out of scope here.
        entries.append(Entry(
            kind="tileset",
            scene_path=res_path(scene),
            target_node=target_node,
            target_node_type=target_type,
            asset_path=res_path(png),
            asset_size=size,
            hframes=1,
            vframes=1,
            suggested_action="manual_tileset",
            note="tile_set resource untouched by policy; wire textures via editor",
        ))
    return entries


def _first_wirable(nodes: dict[str, str], prefer: tuple[str, ...]) -> tuple[Optional[str], Optional[str]]:
    """Return (node_path, node_type) for the first node matching a preferred type."""
    for want in prefer:
        for path, ntype in nodes.items():
            if ntype == want:
                return path, ntype
    return None, None


def _action_for(node_type: Optional[str]) -> str:
    if node_type is None:
        return "manual_add_node"
    if node_type == "Sprite2D":
        return "wire_sprite"
    if node_type == "AnimatedSprite2D":
        return "skip_animated_sprite"
    if node_type in WIRABLE_NODE_TYPES:
        return "wire_texture"
    return "manual_replace_node"


# ---- output ----

READY_ACTIONS = {"wire_sprite", "wire_texture"}


def write_json(entries: list[Entry]) -> None:
    payload = [asdict(e) for e in entries]
    OUT_JSON.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def write_md(entries: list[Entry]) -> None:
    ready = [e for e in entries if e.suggested_action in READY_ACTIONS]
    manual = [e for e in entries if e.suggested_action not in READY_ACTIONS]

    lines: list[str] = []
    lines.append("# Asset → Scene Inventory")
    lines.append("")
    lines.append(f"- Total entries: {len(entries)}")
    lines.append(f"- Ready to auto-wire: {len(ready)}")
    lines.append(f"- Manual / missing:    {len(manual)}")
    lines.append("")

    def render(rows: list[Entry], title: str) -> None:
        lines.append(f"## {title} ({len(rows)})")
        lines.append("")
        if not rows:
            lines.append("_none_")
            lines.append("")
            return
        lines.append("| kind | scene | node (type) | asset | size | frames | action | note |")
        lines.append("|---|---|---|---|---|---|---|---|")
        for e in rows:
            scene = e.scene_path or "—"
            node = e.target_node or "—"
            ntype = e.target_node_type or "—"
            size = f"{e.asset_size[0]}x{e.asset_size[1]}" if e.asset_size and e.asset_size[0] else "—"
            frames = f"{e.hframes}x{e.vframes}"
            lines.append(
                f"| {e.kind} | `{scene}` | `{node}` ({ntype}) | `{e.asset_path}` | {size} | {frames} | `{e.suggested_action}` | {e.note} |"
            )
        lines.append("")

    render(ready, "Ready")
    render(manual, "Manual / Missing")

    OUT_MD.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    entries: list[Entry] = []
    entries.extend(collect_characters())
    entries.extend(collect_monsters())
    entries.extend(collect_bosses())
    entries.extend(collect_effects())
    entries.extend(collect_ui())
    entries.extend(collect_tilesets())

    write_json(entries)
    write_md(entries)

    ready = sum(1 for e in entries if e.suggested_action in READY_ACTIONS)
    print(f"[inventory] wrote {OUT_JSON.relative_to(ROOT)} and {OUT_MD.relative_to(ROOT)}")
    print(f"[inventory] entries: {len(entries)} (ready={ready}, manual={len(entries) - ready})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
