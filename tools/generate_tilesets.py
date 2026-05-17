"""
Generate per-chapter tilesets (5 chapters x 7 tile types) for kkaebi-run.

Each chapter produces, under assets/tilesets/<chapter_id>/:
    <chapter_id>_<tile_name>.png  -- 7 individual 16x16 RGBA tiles
    <chapter_id>_tiles.png        -- 112x16 horizontal strip sheet
    tiles.json                    -- sheet metadata

Tile order on every sheet:
    ground, ground_alt, wall_top, wall_side, deco1, deco2, deco_glow

Determinism: each chapter uses a fixed integer seed, so re-running the
script produces byte-identical PNGs.

Outline color #1A1A1A is applied only to wall edges and deco shape
borders. Ground tiles are never outlined so they tile seamlessly.

Usage:
    pip install Pillow
    python tools/generate_tilesets.py
"""

import json
import os
import random
import sys

from PIL import Image

TILE = 16
TILE_ORDER = [
    "ground",
    "ground_alt",
    "wall_top",
    "wall_side",
    "deco1",
    "deco2",
    "deco_glow",
]
SHEET_W = TILE * len(TILE_ORDER)  # 112
SHEET_H = TILE

OUTLINE = (26, 26, 26, 255)   # #1A1A1A
TRANSPARENT = (0, 0, 0, 0)

CHAPTERS = [
    {
        "id": "ch01_dumeong",
        "seed": 1101,
        "palette": {
            "base": (54, 84, 54),     # forest green
            "dark": (32, 52, 32),     # deep shade
            "wood": (90, 58, 30),     # brown
            "high": (108, 156, 84),   # leaf highlight
            "glow": (108, 156, 84),
        },
        "deco1": "grass",
        "deco2": "mushroom",
    },
    {
        "id": "ch02_sinryeong",
        "seed": 2202,
        "palette": {
            "base": (91, 173, 138),   # jade
            "dark": (40, 80, 72),     # deep shade
            "high": (240, 240, 220),  # starlight white
            "glow": (240, 199, 94),   # gold glow
        },
        "deco1": "star",
        "deco2": "stardust",
    },
    {
        "id": "ch03_hwangcheon",
        "seed": 3303,
        "palette": {
            "base": (66, 40, 82),     # purple
            "dark": (110, 110, 118),  # gray
            "high": (220, 210, 180),  # bone
            "glow": (170, 160, 180),  # fog as glow
        },
        "deco1": "bone",
        "deco2": "fog",
    },
    {
        "id": "ch04_cheonsang",
        "seed": 4404,
        "palette": {
            "base": (123, 200, 246),  # sky
            "dark": (90, 150, 200),   # cloud shadow
            "high": (245, 250, 255),  # cloud white
            "glow": (240, 199, 94),   # gold
        },
        "deco1": "cloud",
        "deco2": "gold_bead",
    },
    {
        "id": "ch05_sinmok_heart",
        "seed": 5505,
        "palette": {
            "base": (120, 80, 40),    # warm wood
            "dark": (70, 42, 18),     # dark grain
            "high": (240, 199, 94),   # sap gold
            "glow": (140, 220, 160),  # bioluminescent green
        },
        "deco1": "sap_drop",
        "deco2": "glow_speck",
    },
]


# ----------------------------------------------------------------- helpers

def _as_rgba(c):
    return c if len(c) == 4 else c + (255,)


def _new_tile(fill=None):
    if fill is None:
        return Image.new("RGBA", (TILE, TILE), TRANSPARENT)
    return Image.new("RGBA", (TILE, TILE), _as_rgba(fill))


def _put(px, x, y, color):
    if 0 <= x < TILE and 0 <= y < TILE:
        px[x, y] = _as_rgba(color)


def _outline_opaque(img):
    """Add a 1-pixel OUTLINE around every opaque region (4-neighborhood)."""
    w, h = img.size
    px = img.load()
    targets = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] != 0:
                continue
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] != 0:
                    targets.append((x, y))
                    break
    for x, y in targets:
        px[x, y] = OUTLINE


# ----------------------------------------------------------------- ground

def _make_ground(pal, seed, alt=False):
    # Solid base fill -- outer 1px ring stays pure base color so tiles
    # remain seamless. Inner area gets a small amount of deterministic
    # dark/highlight noise.
    img = _new_tile(pal["base"])
    px = img.load()
    rng = random.Random(seed + (37 if alt else 0))
    dark = pal["dark"]
    high = pal["high"]
    n_dark = 14 if alt else 12
    n_high = 5 if alt else 4
    for _ in range(n_dark):
        x = rng.randint(1, TILE - 2)
        y = rng.randint(1, TILE - 2)
        _put(px, x, y, dark)
    for _ in range(n_high):
        x = rng.randint(1, TILE - 2)
        y = rng.randint(1, TILE - 2)
        _put(px, x, y, high)
    for _ in range(2):
        x = rng.randint(2, TILE - 3)
        y = rng.randint(2, TILE - 3)
        _put(px, x, y, dark)
        _put(px, x + 1, y, dark)
    return img


# ----------------------------------------------------------------- walls

def _make_wall_top(pal, seed):
    img = _new_tile(pal["base"])
    px = img.load()
    dark = pal["dark"]
    high = pal["high"]
    # Outline around entire perimeter.
    for y in range(TILE):
        px[0, y] = OUTLINE
        px[TILE - 1, y] = OUTLINE
    for x in range(TILE):
        px[x, 0] = OUTLINE
        px[x, TILE - 1] = OUTLINE
    # Top 2 inner rows lit (light-facing face).
    for x in range(1, TILE - 1):
        px[x, 1] = _as_rgba(high)
        px[x, 2] = _as_rgba(high)
    # Deterministic grain inside.
    rng = random.Random(seed + 71)
    for _ in range(10):
        x = rng.randint(2, TILE - 3)
        y = rng.randint(4, TILE - 3)
        px[x, y] = _as_rgba(dark)
    return img


def _make_wall_side(pal, seed):
    img = _new_tile(pal["base"])
    px = img.load()
    dark = pal["dark"]
    # Vertical outlines on the left and right edges.
    for y in range(TILE):
        px[0, y] = OUTLINE
        px[TILE - 1, y] = OUTLINE
    # Centered vertical grain streaks (stone/wood).
    rng = random.Random(seed + 113)
    for x in range(2, TILE - 2):
        if rng.random() < 0.45:
            y0 = rng.randint(1, TILE - 5)
            length = rng.randint(2, 4)
            for y in range(y0, min(TILE - 1, y0 + length)):
                px[x, y] = _as_rgba(dark)
    return img


# ----------------------------------------------------------------- decos

def _draw_grass(px, pal, seed):
    rng = random.Random(seed + 11)
    blade = pal["high"]
    tip = pal["glow"]
    for bx in (3, 7, 11):
        h = 3 + rng.randint(0, 2)
        for y in range(TILE - 1 - h, TILE - 1):
            _put(px, bx, y, blade)
        _put(px, bx, TILE - 1 - h, tip)


def _draw_mushroom(px, pal, seed):
    stem = (220, 210, 200)
    cap = pal["wood"]
    spot = pal["high"]
    for y in range(10, 14):
        _put(px, 7, y, stem)
        _put(px, 8, y, stem)
    for x in range(5, 11):
        _put(px, x, 9, cap)
    for x in range(4, 12):
        _put(px, x, 8, cap)
    for x in range(5, 11):
        _put(px, x, 7, cap)
    _put(px, 6, 8, spot)
    _put(px, 9, 8, spot)


def _draw_star(px, pal, seed):
    cx, cy = 8, 8
    gold = pal["glow"]
    white = pal["high"]
    _put(px, cx, cy, white)
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        _put(px, cx + dx, cy + dy, gold)
    for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2)):
        _put(px, cx + dx, cy + dy, gold)


def _draw_stardust(px, pal, seed):
    rng = random.Random(seed + 13)
    white = pal["high"]
    gold = pal["glow"]
    for _ in range(10):
        x = rng.randint(1, TILE - 2)
        y = rng.randint(1, TILE - 2)
        _put(px, x, y, gold if rng.random() < 0.4 else white)


def _draw_bone(px, pal, seed):
    bone = pal["high"]
    for x in range(4, 12):
        _put(px, x, 8, bone)
        _put(px, x, 9, bone)
    _put(px, 3, 7, bone)
    _put(px, 3, 10, bone)
    _put(px, 2, 8, bone)
    _put(px, 2, 9, bone)
    _put(px, 12, 7, bone)
    _put(px, 12, 10, bone)
    _put(px, 13, 8, bone)
    _put(px, 13, 9, bone)


def _draw_fog(px, pal, seed):
    rng = random.Random(seed + 17)
    fog = pal["glow"]
    for _ in range(18):
        x = rng.randint(0, TILE - 1)
        y = rng.randint(0, TILE - 1)
        a = rng.choice((120, 160, 200))
        px[x, y] = (fog[0], fog[1], fog[2], a)


def _draw_cloud(px, pal, seed):
    white = pal["high"]
    dark = pal["dark"]
    coords = [
        (5, 9), (6, 9), (7, 9), (8, 9), (9, 9), (10, 9),
        (4, 10), (5, 10), (6, 10), (7, 10),
        (8, 10), (9, 10), (10, 10), (11, 10),
        (5, 11), (6, 11), (7, 11), (8, 11), (9, 11), (10, 11),
        (6, 8), (7, 8), (9, 8),
    ]
    for x, y in coords:
        _put(px, x, y, white)
    for x in (5, 7, 9):
        _put(px, x, 11, dark)


def _draw_gold_bead(px, pal, seed):
    gold = pal["glow"]
    white = pal["high"]
    coords = [
        (7, 6), (8, 6),
        (6, 7), (7, 7), (8, 7), (9, 7),
        (6, 8), (7, 8), (8, 8), (9, 8),
        (7, 9), (8, 9),
    ]
    for x, y in coords:
        _put(px, x, y, gold)
    _put(px, 7, 7, white)


def _draw_sap_drop(px, pal, seed):
    sap = pal["high"]
    _put(px, 8, 5, sap)
    _put(px, 7, 6, sap)
    _put(px, 8, 6, sap)
    _put(px, 9, 6, sap)
    _put(px, 7, 7, sap)
    _put(px, 8, 7, sap)
    _put(px, 9, 7, sap)
    _put(px, 8, 8, sap)


def _draw_glow_speck(px, pal, seed):
    rng = random.Random(seed + 19)
    glow = pal["glow"]
    for _ in range(5):
        x = rng.randint(2, TILE - 3)
        y = rng.randint(2, TILE - 3)
        _put(px, x, y, glow)


DECO_DRAWERS = {
    "grass": _draw_grass,
    "mushroom": _draw_mushroom,
    "star": _draw_star,
    "stardust": _draw_stardust,
    "bone": _draw_bone,
    "fog": _draw_fog,
    "cloud": _draw_cloud,
    "gold_bead": _draw_gold_bead,
    "sap_drop": _draw_sap_drop,
    "glow_speck": _draw_glow_speck,
}

# Soft / glowing decos read better without a dark border.
NO_OUTLINE_DECOS = {"fog", "stardust", "glow_speck"}


def _make_deco(pal, seed, kind):
    img = _new_tile()
    px = img.load()
    DECO_DRAWERS[kind](px, pal, seed)
    if kind not in NO_OUTLINE_DECOS:
        _outline_opaque(img)
    return img


# ----------------------------------------------------------------- glow

def _make_deco_glow(pal, seed):
    # Radial glow: a 4-pixel bright core (r < 1.0) plus a halo that fades
    # out by r ~= 6. Yields ~30..60% transparent pixels overall, which
    # satisfies the deco_glow alpha-zero target band (0.30..0.80).
    img = _new_tile()
    px = img.load()
    glow = pal["glow"]
    cx, cy = 7.5, 7.5

    bands = (
        (1.0, 255),
        (2.0, 220),
        (3.0, 160),
        (4.0, 110),
        (5.0, 70),
        (6.0, 35),
    )

    for y in range(TILE):
        for x in range(TILE):
            dx = x + 0.5 - cx
            dy = y + 0.5 - cy
            r = (dx * dx + dy * dy) ** 0.5
            alpha = 0
            for limit, a in bands:
                if r < limit:
                    alpha = a
                    break
            if alpha > 0:
                px[x, y] = (glow[0], glow[1], glow[2], alpha)
    return img


# ----------------------------------------------------------------- pipeline

def _build_chapter(chapter):
    pal = chapter["palette"]
    seed = chapter["seed"]
    return {
        "ground": _make_ground(pal, seed, alt=False),
        "ground_alt": _make_ground(pal, seed, alt=True),
        "wall_top": _make_wall_top(pal, seed),
        "wall_side": _make_wall_side(pal, seed),
        "deco1": _make_deco(pal, seed + 23, chapter["deco1"]),
        "deco2": _make_deco(pal, seed + 29, chapter["deco2"]),
        "deco_glow": _make_deco_glow(pal, seed),
    }


def _alpha_zero_ratio(img):
    w, h = img.size
    px = img.load()
    zero = sum(1 for y in range(h) for x in range(w) if px[x, y][3] == 0)
    return zero / (w * h)


def main_run():
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_root = os.path.join(project_root, "assets", "tilesets")
    os.makedirs(out_root, exist_ok=True)

    failures = []

    for chapter in CHAPTERS:
        cid = chapter["id"]
        cdir = os.path.join(out_root, cid)
        os.makedirs(cdir, exist_ok=True)
        tiles = _build_chapter(chapter)

        sheet = Image.new("RGBA", (SHEET_W, SHEET_H), TRANSPARENT)

        for idx, name in enumerate(TILE_ORDER):
            tile = tiles[name]
            if tile.size != (TILE, TILE):
                failures.append(
                    f"{cid}/{name}: size {tile.size} != ({TILE},{TILE})"
                )
                continue
            if tile.mode != "RGBA":
                failures.append(
                    f"{cid}/{name}: mode {tile.mode} != RGBA"
                )
                continue
            tile_path = os.path.join(cdir, f"{cid}_{name}.png")
            tile.save(tile_path, "PNG")
            sheet.paste(tile, (idx * TILE, 0), tile)
            print(f"[OK] {cid}/{name} -> {tile_path}")

        sheet_path = os.path.join(cdir, f"{cid}_tiles.png")
        sheet.save(sheet_path, "PNG")
        if sheet.size != (SHEET_W, SHEET_H):
            failures.append(
                f"{cid}/sheet: size {sheet.size} != ({SHEET_W},{SHEET_H})"
            )
        print(f"[OK] {cid}/sheet -> {sheet_path} size={sheet.size}")

        meta_path = os.path.join(cdir, "tiles.json")
        with open(meta_path, "w", encoding="utf-8") as f:
            json.dump(
                {
                    "tile_size": TILE,
                    "order": TILE_ORDER,
                    "sheet": f"{cid}_tiles.png",
                },
                f,
                ensure_ascii=False,
                indent=2,
            )
        print(f"[OK] {cid}/tiles.json -> {meta_path}")

        g_ratio = _alpha_zero_ratio(tiles["ground"])
        glow_ratio = _alpha_zero_ratio(tiles["deco_glow"])

        if not (0.0 <= g_ratio <= 0.05):
            failures.append(
                f"{cid}/ground: alpha-zero ratio {g_ratio:.3f} not in 0.00..0.05"
            )
        if not (0.30 <= glow_ratio <= 0.80):
            failures.append(
                f"{cid}/deco_glow: alpha-zero ratio {glow_ratio:.3f} "
                f"not in 0.30..0.80"
            )
        print(
            f"[CHECK] {cid} ground_alpha0={g_ratio:.3f} "
            f"glow_alpha0={glow_ratio:.3f}"
        )

    if failures:
        print("[FAIL] verification failures:", file=sys.stderr)
        for msg in failures:
            print(f"  - {msg}", file=sys.stderr)
        sys.exit(2)

    print(f"[DONE] generated tilesets for {len(CHAPTERS)} chapters.")


if __name__ == "__main__":
    main_run()
