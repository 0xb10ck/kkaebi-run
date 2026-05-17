"""16x16 tilesets per chapter.

Generates 5 ground + 5 wall + 5 deco = 15 tiles per chapter, plus an 8x8 grid
sheet (filling the rest with transparent slots).
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import List, Tuple

from PIL import Image

from . import primitives as P
from .palette import RGB, chapter_tileset, darken, lighten, load_palette, outline_color

TILE = 16


def _tile_canvas(fill: RGB) -> Image.Image:
    img = P.new_canvas(TILE, TILE, (fill[0], fill[1], fill[2], 255))
    return img


def _ground_variants(base: RGB, accent: RGB) -> List[Image.Image]:
    """5 ground tile variants."""
    tiles: List[Image.Image] = []
    light = lighten(base, 0.15)
    dark = darken(base, 0.15)

    # 0: plain with subtle dots
    t = _tile_canvas(base)
    for (x, y) in [(2, 3), (7, 5), (12, 2), (4, 11), (11, 13)]:
        P.put(t, x, y, dark)
    tiles.append(t)

    # 1: pebbles
    t = _tile_canvas(base)
    P.fill_circle(t, 4, 4, 1, dark)
    P.fill_circle(t, 11, 6, 1, dark)
    P.fill_circle(t, 6, 11, 1, dark)
    P.fill_circle(t, 13, 13, 1, light)
    tiles.append(t)

    # 2: cracked
    t = _tile_canvas(base)
    P.hline(t, 1, 7, 8, dark)
    P.hline(t, 7, 14, 9, dark)
    P.vline(t, 9, 9, 14, dark)
    tiles.append(t)

    # 3: grassy edge (deco/accent tipped)
    t = _tile_canvas(base)
    for x in range(0, TILE, 2):
        P.put(t, x, 0, accent)
        P.put(t, x + 1, 1, accent)
    tiles.append(t)

    # 4: lit highlight
    t = _tile_canvas(base)
    P.fill_rect(t, 0, 0, 15, 1, light)
    P.fill_rect(t, 0, 14, 15, 15, dark)
    tiles.append(t)
    return tiles


def _wall_variants(base: RGB, accent: RGB) -> List[Image.Image]:
    tiles: List[Image.Image] = []
    light = lighten(base, 0.2)
    dark = darken(base, 0.2)
    o = outline_color()

    # 0: brick
    t = _tile_canvas(base)
    P.hline(t, 0, 15, 0, o)
    P.hline(t, 0, 15, 7, o)
    P.hline(t, 0, 15, 15, o)
    P.vline(t, 0, 0, 7, o)
    P.vline(t, 7, 0, 7, o)
    P.vline(t, 3, 8, 15, o)
    P.vline(t, 11, 8, 15, o)
    tiles.append(t)

    # 1: stone slab
    t = _tile_canvas(base)
    P.rect_outline(t, 0, 0, 15, 15, o)
    P.hline(t, 1, 14, 7, dark)
    tiles.append(t)

    # 2: cracked wall
    t = _tile_canvas(base)
    P.hline(t, 2, 12, 5, dark)
    P.vline(t, 6, 5, 12, dark)
    P.hline(t, 6, 13, 10, dark)
    tiles.append(t)

    # 3: corner brick light highlight
    t = _tile_canvas(base)
    P.rect_outline(t, 0, 0, 15, 15, o)
    P.hline(t, 1, 14, 1, light)
    P.vline(t, 1, 1, 14, light)
    tiles.append(t)

    # 4: deco accent inset
    t = _tile_canvas(base)
    P.rect_outline(t, 0, 0, 15, 15, o)
    P.fill_rect(t, 6, 6, 9, 9, accent)
    tiles.append(t)
    return tiles


def _deco_variants(deco: RGB, accent: RGB) -> List[Image.Image]:
    tiles: List[Image.Image] = []
    o = outline_color()

    # 0: small plant
    t = P.new_canvas(TILE, TILE)
    P.fill_ellipse(t, 8, 10, 3, 2, deco)
    P.fill_ellipse(t, 5, 8, 2, 2, deco)
    P.fill_ellipse(t, 11, 8, 2, 2, deco)
    P.vline(t, 8, 11, 14, darken(deco, 0.3))
    tiles.append(P.add_outline(t, o))

    # 1: lantern (accent)
    t = P.new_canvas(TILE, TILE)
    P.fill_rect(t, 6, 4, 9, 11, accent)
    P.fill_rect(t, 7, 12, 8, 13, accent)
    P.fill_rect(t, 5, 3, 10, 3, o)
    P.put(t, 7, 7, (255, 255, 255))
    tiles.append(P.add_outline(t, o))

    # 2: stone pillar
    t = P.new_canvas(TILE, TILE)
    P.fill_rect(t, 5, 2, 10, 14, deco)
    P.fill_rect(t, 4, 13, 11, 14, darken(deco, 0.3))
    tiles.append(P.add_outline(t, o))

    # 3: pebble cluster
    t = P.new_canvas(TILE, TILE)
    P.fill_circle(t, 5, 10, 2, deco)
    P.fill_circle(t, 10, 11, 2, darken(deco, 0.2))
    P.fill_circle(t, 8, 8, 1, accent)
    tiles.append(P.add_outline(t, o))

    # 4: rune mark
    t = P.new_canvas(TILE, TILE)
    P.fill_circle(t, 8, 8, 5, deco)
    P.fill_circle(t, 8, 8, 3, accent)
    P.put(t, 8, 8, o)
    tiles.append(P.add_outline(t, o))
    return tiles


def render_chapter_tileset(chapter_id: str, out_dir: Path) -> Tuple[Path, List[Path]]:
    cols = chapter_tileset(chapter_id)
    ground = _ground_variants(cols["ground"], cols["accent"])
    wall = _wall_variants(cols["wall"], cols["accent"])
    deco = _deco_variants(cols["deco"], cols["accent"])
    all_tiles: List[Image.Image] = ground + wall + deco

    # 8x8 grid (64 slots) with the 15 tiles in the first two rows
    pad_count = 64 - len(all_tiles)
    blank = P.new_canvas(TILE, TILE)
    padded = list(all_tiles) + [blank] * pad_count
    sheet = P.compose_grid(padded, cols=8)

    chapter_dir = out_dir / chapter_id
    chapter_dir.mkdir(parents=True, exist_ok=True)
    sheet_path = chapter_dir / "tileset.png"
    sheet.save(sheet_path)

    individual: List[Path] = []
    labels = (
        [f"ground_{i:02d}" for i in range(5)]
        + [f"wall_{i:02d}" for i in range(5)]
        + [f"deco_{i:02d}" for i in range(5)]
    )
    for label, tile in zip(labels, all_tiles):
        p = chapter_dir / f"{label}.png"
        tile.save(p)
        individual.append(p)

    meta = {
        "chapter_id": chapter_id,
        "tile_size": [TILE, TILE],
        "sheet_size": list(sheet.size),
        "grid_cols": 8,
        "slot_order": labels,
    }
    meta_path = chapter_dir / "tileset.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)

    return sheet_path, individual


def build_all_tilesets(out_dir: Path) -> List[Path]:
    outs: List[Path] = []
    palette = load_palette()
    for chapter_id in palette["chapter_tilesets"].keys():
        sheet, indiv = render_chapter_tileset(chapter_id, out_dir)
        outs.append(sheet)
        outs.extend(indiv)
    return outs
