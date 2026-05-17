"""Single entry point for the pixel-art generation pipeline.

Default behaviour now produces the **production layout** under ``assets/``:

    assets/sprites/characters/<id>/<id>.png + <id>.frames.json
    assets/sprites/monsters/<id>/<id>.png   + <id>.frames.json
    assets/sprites/bosses/<id>/<id>.png     + <id>.frames.json
    assets/sprites/effects/<skill_id>/<skill_id>.png + <skill_id>.frames.json
    assets/tilesets/<chapter_id>/<chapter_id>_tiles.png + per-tile PNG + tileset.json
    assets/ui/buttons/   (button_normal/hover/pressed.png)
    assets/ui/panels/    (panel_frame, hp_bar_bg, hp_bar_fill, skill_icon_frame, level_up_panel)
    assets/ui/logo/      (logo, title_bg)

IDs are discovered from ``resources/`` (see :mod:`tools.art_pipeline.resources`).
Godot ``.import`` sidecars are emitted next to every PNG (existing sidecars are
preserved).

Usage:
    python -m tools.art_pipeline.build_all                # build everything
    python -m tools.art_pipeline.build_all --only=ui      # build a single category
    python -m tools.art_pipeline.build_all --no-import    # skip .import sidecars
    python -m tools.art_pipeline.build_all --out PATH     # custom assets root
    python -m tools.art_pipeline.build_all --no-manifest  # skip MANIFEST.md

Categories: characters, monsters, bosses, tilesets, effects, ui
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Callable, Dict, Iterable, List, Tuple

from PIL import Image

from . import primitives as P
from .boss import BossSpec, render_boss_sheet
from .character import default_spec_for as character_default_spec, render_character_sheet
from .effects import _render_one as _render_effect_shape  # type: ignore
from .godot_import import write_sidecars_for
from .monster import MonsterSpec, render_monster_sheet
from .palette import (
    darken,
    hex_to_rgb,
    lighten,
    load_palette,
    palette_path,
    project_root,
    ui_colors,
)
from .resources import (
    discover_bosses,
    discover_characters,
    discover_chapters,
    discover_monsters,
    discover_skills,
)
from .tileset import render_chapter_tileset
from .ui import (
    _9slice_button,
    _hanji_panel,
    _hp_bar,
    _level_up_panel,
    _logo,
    _paper_background,
    _skill_frame,
)


CATEGORIES = ("characters", "monsters", "bosses", "tilesets", "effects", "ui")


def default_output_root() -> Path:
    return project_root() / "assets"


# --- Sub-category output roots ---------------------------------------------

def _sprites_root(assets_root: Path) -> Path:
    return assets_root / "sprites"


def _cat_root(assets_root: Path, cat: str) -> Path:
    if cat in {"characters", "monsters", "bosses", "effects"}:
        return _sprites_root(assets_root) / cat
    if cat == "tilesets":
        return assets_root / "tilesets"
    if cat == "ui":
        return assets_root / "ui"
    raise ValueError(f"unknown category: {cat}")


# --- Production builders ---------------------------------------------------

def build_characters_prod(out_root: Path) -> List[Path]:
    outs: List[Path] = []
    for cid in discover_characters():
        spec = character_default_spec(cid)
        per_dir = out_root / cid
        sheet, meta = render_character_sheet(spec, per_dir)
        outs.extend([sheet, meta])
    return outs


def build_monsters_prod(out_root: Path) -> List[Path]:
    outs: List[Path] = []
    for info in discover_monsters():
        spec = MonsterSpec(monster_id=info.monster_id, main=info.main, sub=info.sub, category=info.category)
        per_dir = out_root / info.monster_id
        sheet, meta = render_monster_sheet(spec, per_dir)
        outs.extend([sheet, meta])
    return outs


def build_bosses_prod(out_root: Path) -> List[Path]:
    outs: List[Path] = []
    for info in discover_bosses():
        spec = BossSpec(
            boss_id=info.boss_id,
            main=info.main,
            sub=info.sub,
            point=info.point,
            motif=info.motif,
            detail_slot=info.detail_slot,
            has_weapon=True,
        )
        per_dir = out_root / info.boss_id
        sheet, meta = render_boss_sheet(spec, per_dir)
        outs.extend([sheet, meta])
    return outs


_EFFECT_FRAME_COUNT = 4


def _write_effect_frames_json(out_path: Path, skill_id: str, palette_key: str, shape: str, rarity: int, element: int) -> None:
    meta = {
        "skill_id": skill_id,
        "element": element,
        "rarity": rarity,
        "shape": shape,
        "palette_key": palette_key,
        "frame_size": [32, 32],
        "sheet_size": [32 * _EFFECT_FRAME_COUNT, 32],
        "total_frames": _EFFECT_FRAME_COUNT,
        "anims": [
            {"name": "play", "start": 0, "count": _EFFECT_FRAME_COUNT},
        ],
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)


def build_effects_prod(out_root: Path) -> List[Path]:
    outs: List[Path] = []
    for info in discover_skills():
        per_dir = out_root / info.skill_id
        per_dir.mkdir(parents=True, exist_ok=True)
        sheet = _render_effect_shape(info.shape, info.palette_key)
        sheet_path = per_dir / f"{info.skill_id}.png"
        sheet.save(sheet_path)
        meta_path = per_dir / f"{info.skill_id}.frames.json"
        _write_effect_frames_json(meta_path, info.skill_id, info.palette_key, info.shape, info.rarity, info.element)
        outs.extend([sheet_path, meta_path])
    return outs


def build_tilesets_prod(out_root: Path) -> List[Path]:
    outs: List[Path] = []
    for cid in discover_chapters():
        per_dir = out_root / cid
        per_dir.mkdir(parents=True, exist_ok=True)
        # render_chapter_tileset writes tileset.png + individual tiles + tileset.json
        sheet, individual = render_chapter_tileset(cid, out_root)
        # Rename "tileset.png" → "<chapter_id>_tiles.png" (spec layout).
        renamed = per_dir / f"{cid}_tiles.png"
        if sheet.exists():
            if renamed.exists():
                renamed.unlink()
            sheet.rename(renamed)
        outs.append(renamed)
        outs.extend(individual)
        meta_path = per_dir / "tileset.json"
        if meta_path.exists():
            outs.append(meta_path)
    return outs


# --- UI (spec layout) ------------------------------------------------------

def _hp_bar_bg(w: int = 64, h: int = 8) -> Image.Image:
    c = ui_colors("hp_bar")
    img = P.new_canvas(w, h)
    P.fill_rect(img, 1, 1, w - 2, h - 2, c["back"])
    P.rect_outline(img, 0, 0, w - 1, h - 1, c["edge"])
    return img


def _hp_bar_fill(w: int = 64, h: int = 8) -> Image.Image:
    c = ui_colors("hp_bar")
    img = P.new_canvas(w, h)
    P.fill_rect(img, 1, 1, w - 2, h - 2, c["fill"])
    # subtle gloss highlight
    P.hline(img, 2, w - 3, 2, lighten(c["fill"], 0.3))
    P.hline(img, 2, w - 3, h - 3, darken(c["fill"], 0.3))
    P.rect_outline(img, 0, 0, w - 1, h - 1, c["edge"])
    return img


def _title_bg(w: int = 192, h: int = 96) -> Image.Image:
    """Title screen background — paper texture with vermilion seal in corner."""
    palette = load_palette()
    bg = hex_to_rgb(palette["base"]["paper_bg"])
    edge = hex_to_rgb(palette["base"]["hanji_yellow"])
    vermillion = hex_to_rgb(palette["base"]["vermillion"])
    img = P.new_canvas(w, h, (bg[0], bg[1], bg[2], 255))
    # Paper grain
    for y in range(2, h, 6):
        P.hline(img, 0, w - 1, y, lighten(edge, 0.5))
    # Border frame
    P.rect_outline(img, 0, 0, w - 1, h - 1, hex_to_rgb(palette["base"]["ink"]))
    P.rect_outline(img, 2, 2, w - 3, h - 3, edge)
    # Vermilion stamp lower-right
    sx0, sy0, sx1, sy1 = w - 28, h - 28, w - 8, h - 8
    P.fill_rect(img, sx0, sy0, sx1, sy1, vermillion)
    P.rect_outline(img, sx0, sy0, sx1, sy1, hex_to_rgb(palette["base"]["ink_outline"]))
    P.fill_rect(img, sx0 + 4, sy0 + 4, sx1 - 4, sy1 - 4, bg)
    return img


def build_ui_prod(out_root: Path) -> List[Path]:
    buttons_dir = out_root / "buttons"
    panels_dir = out_root / "panels"
    logo_dir = out_root / "logo"
    for d in (buttons_dir, panels_dir, logo_dir):
        d.mkdir(parents=True, exist_ok=True)

    outs: List[Path] = []

    # buttons/
    for st in ("normal", "hover", "pressed"):
        p = buttons_dir / f"button_{st}.png"
        _9slice_button(st).save(p)
        outs.append(p)

    # panels/
    pf = panels_dir / "panel_frame.png"
    _hanji_panel().save(pf)
    outs.append(pf)

    bg = panels_dir / "hp_bar_bg.png"
    _hp_bar_bg().save(bg)
    outs.append(bg)

    fill = panels_dir / "hp_bar_fill.png"
    _hp_bar_fill().save(fill)
    outs.append(fill)

    sk = panels_dir / "skill_icon_frame.png"
    _skill_frame().save(sk)
    outs.append(sk)

    lvl = panels_dir / "level_up_panel.png"
    _level_up_panel().save(lvl)
    outs.append(lvl)

    # logo/
    lg = logo_dir / "logo.png"
    _logo().save(lg)
    outs.append(lg)

    tb = logo_dir / "title_bg.png"
    _title_bg().save(tb)
    outs.append(tb)

    # ui.json index
    meta = {
        "buttons": ["normal", "hover", "pressed"],
        "panels": [
            "panel_frame.png",
            "hp_bar_bg.png",
            "hp_bar_fill.png",
            "skill_icon_frame.png",
            "level_up_panel.png",
        ],
        "logo": ["logo.png", "title_bg.png"],
    }
    with open(out_root / "ui.json", "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)

    return outs


# --- Orchestration ---------------------------------------------------------

def _cache_path(assets_root: Path) -> Path:
    return assets_root / ".art_cache.json"


def _hash_palette_signature() -> str:
    p = palette_path()
    if not p.exists():
        return "no-palette"
    digest = hashlib.sha256(p.read_bytes()).hexdigest()
    return digest[:16]


def _load_cache(assets_root: Path) -> Dict[str, str]:
    cp = _cache_path(assets_root)
    if not cp.exists():
        return {}
    try:
        with open(cp, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def _save_cache(assets_root: Path, cache: Dict[str, str]) -> None:
    assets_root.mkdir(parents=True, exist_ok=True)
    with open(_cache_path(assets_root), "w", encoding="utf-8") as f:
        json.dump(cache, f, ensure_ascii=False, indent=2)


def _builders(assets_root: Path) -> Dict[str, Callable[[], List[Path]]]:
    return {
        "characters": lambda: build_characters_prod(_cat_root(assets_root, "characters")),
        "monsters":   lambda: build_monsters_prod(_cat_root(assets_root, "monsters")),
        "bosses":     lambda: build_bosses_prod(_cat_root(assets_root, "bosses")),
        "tilesets":   lambda: build_tilesets_prod(_cat_root(assets_root, "tilesets")),
        "effects":    lambda: build_effects_prod(_cat_root(assets_root, "effects")),
        "ui":         lambda: build_ui_prod(_cat_root(assets_root, "ui")),
    }


# --- Validation + MANIFEST -------------------------------------------------

def _is_image_meaningful(path: Path, *, min_unique_alpha: int = 1) -> Tuple[bool, str]:
    """Open and check that the PNG is not fully transparent or fully one color."""
    try:
        with Image.open(path) as img:
            img = img.convert("RGBA")
            w, h = img.size
            if w == 0 or h == 0:
                return False, f"zero-size: {w}x{h}"
            extrema = img.getextrema()  # ((minR, maxR), (minG,...), (minB,...), (minA, maxA))
            min_a, max_a = extrema[3]
            if max_a == 0:
                return False, "fully transparent"
            min_r, max_r = extrema[0]
            min_g, max_g = extrema[1]
            min_b, max_b = extrema[2]
            if min_r == max_r and min_g == max_g and min_b == max_b and (min_r, min_g, min_b) == (0, 0, 0):
                return False, "all black"
            return True, f"{w}x{h} alpha=[{min_a},{max_a}]"
    except Exception as e:  # pragma: no cover
        return False, f"open-error: {e}"


def _image_size(path: Path) -> Tuple[int, int]:
    with Image.open(path) as img:
        return img.size


def _list_png(root: Path) -> List[Path]:
    if not root.exists():
        return []
    return sorted(root.rglob("*.png"))


def _frames_json_for(png: Path) -> Path:
    return png.with_name(png.stem + ".frames.json")


def _frame_count_for(png: Path) -> Tuple[int, int]:
    """Returns (declared_frames, frame_w)."""
    meta = _frames_json_for(png)
    if meta.exists():
        try:
            data = json.loads(meta.read_text(encoding="utf-8"))
            fw = int(data.get("frame_size", [0, 0])[0] or 0)
            tf = int(data.get("total_frames", 0) or 0)
            return tf, fw
        except Exception:
            return 0, 0
    return 0, 0


def write_manifest(assets_root: Path, bad: Iterable[Tuple[Path, str]]) -> Path:
    manifest = assets_root / "MANIFEST.md"
    by_section: Dict[str, List[Path]] = {
        "sprites/characters": _list_png(_cat_root(assets_root, "characters")),
        "sprites/monsters":   _list_png(_cat_root(assets_root, "monsters")),
        "sprites/bosses":     _list_png(_cat_root(assets_root, "bosses")),
        "sprites/effects":    _list_png(_cat_root(assets_root, "effects")),
        "tilesets":           _list_png(_cat_root(assets_root, "tilesets")),
        "ui":                 _list_png(_cat_root(assets_root, "ui")),
    }

    total = sum(len(v) for v in by_section.values())
    bad_list = list(bad)

    lines: List[str] = []
    lines.append("# Asset Manifest")
    lines.append("")
    lines.append(f"- Total PNGs: **{total}**")
    lines.append(f"- Generator: `tools/art_pipeline/build_all.py`")
    lines.append(f"- Palette signature: `{_hash_palette_signature()}`")
    if bad_list:
        lines.append(f"- ⚠ Failed PNG validation: **{len(bad_list)}** (see end of file)")
    else:
        lines.append(f"- PNG pixel validation: ✓ all files have meaningful content")
    lines.append("")

    for section, paths in by_section.items():
        lines.append(f"## {section} ({len(paths)})")
        lines.append("")
        if not paths:
            lines.append("_(empty)_")
            lines.append("")
            continue
        lines.append("| File | Size | Frames |")
        lines.append("|---|---|---|")
        for p in paths:
            rel = p.relative_to(assets_root)
            try:
                w, h = _image_size(p)
                size = f"{w}x{h}"
            except Exception:
                size = "?"
            tf, _ = _frame_count_for(p)
            frames = str(tf) if tf else "—"
            lines.append(f"| `{rel}` | {size} | {frames} |")
        lines.append("")

    if bad_list:
        lines.append("## ⚠ Validation failures")
        lines.append("")
        for p, msg in bad_list:
            rel = p.relative_to(assets_root) if assets_root in p.parents else p
            lines.append(f"- `{rel}` — {msg}")
        lines.append("")

    manifest.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return manifest


# --- Entry point -----------------------------------------------------------

def run(only: List[str], assets_root: Path, write_import: bool, force: bool, write_manifest_flag: bool) -> int:
    load_palette()  # surface JSON errors early
    builders = _builders(assets_root)

    selected = list(only) if only else list(CATEGORIES)
    for cat in selected:
        if cat not in builders:
            print(f"[error] unknown category: {cat}", file=sys.stderr)
            return 2

    cache = {} if force else _load_cache(assets_root)
    sig = _hash_palette_signature()
    all_outputs: List[Path] = []

    for cat in selected:
        cat_root = _cat_root(assets_root, cat)
        cache_key = f"{cat}::{sig}"
        if not force and cache.get(cache_key) == "ok" and cat_root.exists() and any(cat_root.rglob("*.png")):
            print(f"[skip] {cat} (cache hit, palette unchanged)")
            for p in cat_root.rglob("*.png"):
                all_outputs.append(p)
            continue

        print(f"[build] {cat}")
        outs = builders[cat]()
        for p in outs:
            if isinstance(p, Path) and p.suffix == ".png":
                all_outputs.append(p)
        cache[cache_key] = "ok"

    _save_cache(assets_root, cache)

    if write_import:
        print(f"[import] writing .import sidecars for {len(all_outputs)} PNG(s)")
        write_sidecars_for(all_outputs)

    # Validate
    bad: List[Tuple[Path, str]] = []
    for p in all_outputs:
        ok, msg = _is_image_meaningful(p)
        if not ok:
            bad.append((p, msg))
    if bad:
        print(f"[warn] {len(bad)} PNG(s) failed pixel validation")
        for p, msg in bad[:10]:
            print(f"  - {p}: {msg}")

    if write_manifest_flag:
        mp = write_manifest(assets_root, bad)
        print(f"[manifest] {mp}")

    print(f"[done] outputs under: {assets_root}")
    return 1 if bad else 0


def main(argv: List[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="art_pipeline", description=__doc__)
    parser.add_argument(
        "--only",
        type=str,
        default="",
        help="comma-separated subset of: " + ",".join(CATEGORIES),
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=None,
        help="output assets root (default: <project>/assets)",
    )
    parser.add_argument(
        "--no-import",
        action="store_true",
        help="skip writing Godot .import sidecars",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="ignore cache and rebuild everything",
    )
    parser.add_argument(
        "--no-manifest",
        action="store_true",
        help="skip writing assets/MANIFEST.md",
    )
    args = parser.parse_args(argv)

    only = [s.strip() for s in args.only.split(",") if s.strip()] if args.only else []
    assets_root = args.out or default_output_root()
    return run(
        only=only,
        assets_root=assets_root,
        write_import=not args.no_import,
        force=args.force,
        write_manifest_flag=not args.no_manifest,
    )


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
