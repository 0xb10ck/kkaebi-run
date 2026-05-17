#!/usr/bin/env python3
"""Conservative .tscn wiring tool.

Reads inventory.json and updates ONLY .tscn files. Adds ext_resource entries
and texture slot lines for nodes that already exist with a compatible type.

Rules (strictly observed):
- Never touch .gd, .tres, .cfg, .godot files.
- Never add or remove nodes.
- Never modify sub_resources, tile_set definitions, or scene structure.
- If a path is already an ext_resource, reuse its id; otherwise pick the
  smallest unused integer id.
- Sprite2D: set texture, hframes, vframes=1, frame=0.
- AnimatedSprite2D: skip (untouched), record manual.
- TextureRect / NinePatchRect: set texture only.
- TileMap: skip (manual) — texture lives inside tile_set.
- Back up every file before writing to tools/wire_assets/backup/<sha>/<relpath>.
- Output report at tools/wire_assets/wire_report.md.
"""

from __future__ import annotations

import hashlib
import json
import re
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = Path(__file__).resolve().parent
INVENTORY_JSON = OUT_DIR / "inventory.json"
BACKUP_DIR = OUT_DIR / "backup"
REPORT_MD = OUT_DIR / "wire_report.md"


HEADER_RE = re.compile(r'^\[gd_scene(?:\s+load_steps=(\d+))?\s+format=\d+.*\]')
EXT_RES_RE = re.compile(
    r'^\[ext_resource\s+type="([^"]+)"\s+path="([^"]+)"\s+id="([^"]+)"\]'
)
NODE_HEADER_RE = re.compile(
    r'^\[node\s+name="([^"]+)"(?:\s+type="([^"]+)")?(?:\s+parent="([^"]*)")?'
)
SECTION_HEADER_RE = re.compile(r'^\[')


WIRE_ACTIONS = {"wire_sprite", "wire_texture"}


@dataclass
class WireResult:
    file: str
    changed: bool
    actions: list[str]
    skipped: list[str]


# ---- helpers ----

def res_to_fs(res_path: str) -> Path:
    assert res_path.startswith("res://"), res_path
    return ROOT / res_path[len("res://"):]


def fs_to_res(p: Path) -> str:
    return f"res://{p.relative_to(ROOT).as_posix()}"


def sha1_path(rel: str) -> str:
    return hashlib.sha1(rel.encode("utf-8")).hexdigest()[:12]


def backup_file(scene_fs: Path) -> Path:
    rel = scene_fs.relative_to(ROOT).as_posix()
    digest = sha1_path(rel)
    dst = BACKUP_DIR / digest / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    if not dst.exists():
        shutil.copy2(scene_fs, dst)
    return dst


# ---- scene model ----

@dataclass
class ExtRes:
    type: str
    path: str
    id: str


@dataclass
class Scene:
    lines: list[str]
    header_index: int = -1
    load_steps: int = 0
    ext_resources: list[tuple[int, ExtRes]] = None     # (line index, ext)
    ext_block_end: int = -1                             # line index right after last ext_resource
    nodes: dict[str, tuple[int, int, Optional[str]]] = None  # path -> (start, end_exclusive, type)
    root_name: Optional[str] = None


def parse_scene(scene_fs: Path) -> Scene:
    text = scene_fs.read_text(encoding="utf-8")
    lines = text.splitlines()
    scene = Scene(lines=lines, ext_resources=[], nodes={})

    # Header
    for i, line in enumerate(lines):
        m = HEADER_RE.match(line)
        if m:
            scene.header_index = i
            scene.load_steps = int(m.group(1)) if m.group(1) else 0
            break

    # ext_resources (must appear before nodes, optionally before sub_resources)
    last_ext_idx = -1
    for i, line in enumerate(lines):
        m = EXT_RES_RE.match(line)
        if m:
            scene.ext_resources.append((i, ExtRes(type=m.group(1), path=m.group(2), id=m.group(3))))
            last_ext_idx = i
    scene.ext_block_end = (last_ext_idx + 1) if last_ext_idx >= 0 else (scene.header_index + 1)

    # nodes (capture range until next section header)
    section_starts: list[tuple[int, str]] = []
    for i, line in enumerate(lines):
        if SECTION_HEADER_RE.match(line):
            section_starts.append((i, line))

    root_name: Optional[str] = None
    for idx, (start, header_line) in enumerate(section_starts):
        if not header_line.startswith("[node "):
            continue
        m = NODE_HEADER_RE.match(header_line)
        if not m:
            continue
        name, ntype, parent = m.group(1), m.group(2), m.group(3)
        end = section_starts[idx + 1][0] if idx + 1 < len(section_starts) else len(lines)
        if parent is None:
            root_name = name
            full = name
        elif parent == ".":
            full = f"{root_name}/{name}" if root_name else name
        else:
            full = f"{root_name}/{parent}/{name}" if root_name else f"{parent}/{name}"
        scene.nodes[full] = (start, end, ntype)
        # also short form without root prefix
        if "/" in full:
            scene.nodes.setdefault(full.split("/", 1)[1], (start, end, ntype))
    scene.root_name = root_name
    return scene


# ---- mutation primitives ----

def next_free_id(scene: Scene) -> str:
    used_nums: set[int] = set()
    for _, ext in scene.ext_resources:
        m = re.match(r"^(\d+)", ext.id)
        if m:
            used_nums.add(int(m.group(1)))
    n = 1
    while n in used_nums:
        n += 1
    return f"{n}_wire"


def find_or_add_ext_resource(scene: Scene, res_type: str, res_path: str) -> tuple[str, bool]:
    """Return (id, added_bool). Adds an ext_resource line if missing."""
    for _, ext in scene.ext_resources:
        if ext.path == res_path:
            return ext.id, False
    new_id = next_free_id(scene)
    line = f'[ext_resource type="{res_type}" path="{res_path}" id="{new_id}"]'
    insert_at = scene.ext_block_end
    scene.lines.insert(insert_at, line)
    scene.ext_resources.append((insert_at, ExtRes(type=res_type, path=res_path, id=new_id)))
    scene.ext_block_end += 1
    # Shift any nodes whose ranges are at or after insertion point.
    shifted: dict[str, tuple[int, int, Optional[str]]] = {}
    for k, (s, e, t) in scene.nodes.items():
        if s >= insert_at:
            shifted[k] = (s + 1, e + 1, t)
        elif e > insert_at:
            shifted[k] = (s, e + 1, t)
        else:
            shifted[k] = (s, e, t)
    scene.nodes = shifted
    return new_id, True


def update_load_steps(scene: Scene, added: int) -> None:
    if scene.header_index < 0 or added <= 0:
        return
    line = scene.lines[scene.header_index]
    m = HEADER_RE.match(line)
    if not m:
        return
    if m.group(1) is None:
        # No load_steps present; insert one.
        new_line = line.replace("[gd_scene", f"[gd_scene load_steps={1 + added}", 1)
    else:
        new_total = int(m.group(1)) + added
        new_line = re.sub(r"load_steps=\d+", f"load_steps={new_total}", line, count=1)
    scene.lines[scene.header_index] = new_line
    scene.load_steps = scene.load_steps + added if scene.load_steps else 1 + added


def set_or_replace_property_in_node(
    scene: Scene, node_path: str, key: str, value: str
) -> bool:
    """Set `key = value` in the node block. Returns True if a write happened."""
    info = scene.nodes.get(node_path)
    if info is None and "/" not in node_path and scene.root_name:
        info = scene.nodes.get(f"{scene.root_name}/{node_path}")
    if info is None:
        # Try matching by tail.
        for path, val in scene.nodes.items():
            if path.endswith("/" + node_path):
                info = val
                break
    if info is None:
        return False
    start, end, _ = info

    # Look for existing `key = ...` within the node block (after the header line).
    prop_re = re.compile(rf"^{re.escape(key)}\s*=")
    insert_pos = start + 1
    # Skip blank lines right after header for nicer insertion.
    for i in range(start + 1, end):
        line = scene.lines[i]
        if prop_re.match(line):
            scene.lines[i] = f"{key} = {value}"
            return True
    # Insert before the trailing blank line (if any) at end of block.
    insert_at = end
    while insert_at - 1 > start and scene.lines[insert_at - 1].strip() == "":
        insert_at -= 1
    scene.lines.insert(insert_at, f"{key} = {value}")
    # Shift node ranges.
    shifted: dict[str, tuple[int, int, Optional[str]]] = {}
    for k, (s, e, t) in scene.nodes.items():
        if s >= insert_at:
            shifted[k] = (s + 1, e + 1, t)
        elif e > insert_at:
            shifted[k] = (s, e + 1, t)
        else:
            shifted[k] = (s, e, t)
    scene.nodes = shifted
    return True


# ---- wiring per-entry ----

def wire_entry(entry: dict, scene: Scene) -> tuple[bool, list[str], list[str]]:
    """Apply one entry. Returns (changed, actions_log, skipped_log)."""
    actions: list[str] = []
    skipped: list[str] = []
    node_path: Optional[str] = entry.get("target_node")
    asset: str = entry.get("asset_path", "")
    if not node_path or not asset:
        skipped.append(f"no node/asset for entry: {entry.get('kind')} {entry.get('scene_path')}")
        return False, actions, skipped

    info = scene.nodes.get(node_path)
    if info is None and scene.root_name:
        info = scene.nodes.get(f"{scene.root_name}/{node_path}")
    if info is None:
        for path, val in scene.nodes.items():
            if path.endswith("/" + node_path):
                info = val
                break
    if info is None:
        skipped.append(f"node missing in scene: {node_path}")
        return False, actions, skipped
    _, _, node_type = info
    if node_type not in {"Sprite2D", "TextureRect", "NinePatchRect"}:
        # AnimatedSprite2D and TileMap are explicitly never auto-wired by this tool.
        skipped.append(f"node type {node_type} not auto-wirable: {node_path}")
        return False, actions, skipped

    ext_id, added = find_or_add_ext_resource(scene, "Texture2D", asset)
    if added:
        actions.append(f"+ext_resource Texture2D {asset} -> id={ext_id}")
    set_or_replace_property_in_node(scene, node_path, "texture", f'ExtResource("{ext_id}")')
    actions.append(f"node {node_path}.texture = ExtResource({ext_id})")

    if node_type == "Sprite2D":
        hf = int(entry.get("hframes") or 1)
        set_or_replace_property_in_node(scene, node_path, "hframes", str(hf))
        set_or_replace_property_in_node(scene, node_path, "vframes", "1")
        set_or_replace_property_in_node(scene, node_path, "frame", "0")
        actions.append(f"node {node_path}.hframes={hf} vframes=1 frame=0")

    if added:
        update_load_steps(scene, 1)
    return True, actions, skipped


# ---- driver ----

def main() -> int:
    if not INVENTORY_JSON.exists():
        print(f"ERROR: {INVENTORY_JSON} not found. Run inventory.py first.", file=sys.stderr)
        return 2

    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    entries = json.loads(INVENTORY_JSON.read_text(encoding="utf-8"))

    # Group entries by scene path for batched edits.
    by_scene: dict[str, list[dict]] = {}
    manual_or_missing: list[dict] = []
    for e in entries:
        if e.get("suggested_action") in WIRE_ACTIONS and e.get("scene_path"):
            by_scene.setdefault(e["scene_path"], []).append(e)
        else:
            manual_or_missing.append(e)

    results: list[WireResult] = []
    total_new_ext = 0
    total_nodes_touched = 0

    for scene_res, items in sorted(by_scene.items()):
        scene_fs = res_to_fs(scene_res)
        if not scene_fs.exists():
            results.append(WireResult(file=scene_res, changed=False, actions=[], skipped=[f"scene not found on disk: {scene_fs}"]))
            continue
        backup_file(scene_fs)
        scene = parse_scene(scene_fs)
        original = "\n".join(scene.lines)
        all_actions: list[str] = []
        all_skipped: list[str] = []
        any_changed = False
        for entry in items:
            changed, actions, skipped = wire_entry(entry, scene)
            any_changed = any_changed or changed
            all_actions.extend(actions)
            all_skipped.extend(skipped)
            if changed:
                total_nodes_touched += 1
                total_new_ext += sum(1 for a in actions if a.startswith("+ext_resource"))

        new_text = "\n".join(scene.lines)
        # Preserve trailing newline if original had one.
        original_text = scene_fs.read_text(encoding="utf-8")
        if original_text.endswith("\n") and not new_text.endswith("\n"):
            new_text += "\n"
        if any_changed and new_text != original_text:
            scene_fs.write_text(new_text, encoding="utf-8")
        results.append(WireResult(
            file=scene_res,
            changed=any_changed and new_text != original_text,
            actions=all_actions,
            skipped=all_skipped,
        ))

    write_report(results, manual_or_missing, total_new_ext, total_nodes_touched)
    changed_files = sum(1 for r in results if r.changed)
    print(f"[wire] scenes processed: {len(results)}  changed: {changed_files}")
    print(f"[wire] new ext_resource: {total_new_ext}  nodes wired: {total_nodes_touched}")
    print(f"[wire] report: {REPORT_MD.relative_to(ROOT)}")
    return 0


def write_report(results: list[WireResult], manual: list[dict], new_ext: int, nodes_touched: int) -> None:
    changed_files = [r for r in results if r.changed]
    lines: list[str] = []
    lines.append("# Wire Report")
    lines.append("")
    lines.append(f"- Scenes inspected:    {len(results)}")
    lines.append(f"- Scenes changed:      {len(changed_files)}")
    lines.append(f"- Nodes wired:         {nodes_touched}")
    lines.append(f"- New ext_resource:    {new_ext}")
    lines.append(f"- Manual / missing:    {len(manual)}")
    lines.append("")
    lines.append("## Changed scenes")
    lines.append("")
    if not changed_files:
        lines.append("_none — every node either lacked a wirable target or was already wired._")
        lines.append("")
    else:
        for r in changed_files:
            lines.append(f"### `{r.file}`")
            for a in r.actions:
                lines.append(f"- {a}")
            if r.skipped:
                lines.append("")
                lines.append("Skipped within this scene:")
                for s in r.skipped:
                    lines.append(f"- {s}")
            lines.append("")
    lines.append("## Manual / missing items")
    lines.append("")
    if not manual:
        lines.append("_none_")
    else:
        lines.append("| kind | scene | node | asset | action | note |")
        lines.append("|---|---|---|---|---|---|")
        for e in manual:
            lines.append(
                f"| {e.get('kind','')} | `{e.get('scene_path','') or '—'}` | "
                f"`{e.get('target_node','') or '—'}` | `{e.get('asset_path','')}` | "
                f"`{e.get('suggested_action','')}` | {e.get('note','')} |"
            )
    REPORT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
