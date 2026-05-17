"""
Generate idle sprite sheets for the 6 player characters.

Usage:
    pip install Pillow
    python tools/generate_sprites.py

Output (flat, directly under assets/sprites/characters/):
    assets/sprites/characters/<id>_idle.png    (128x32 RGBA, 4-frame hstrip)
    assets/sprites/characters/<id>_idle.json   (frame metadata)

Any stale outputs from the previous per-character subfolder layout
(<id>/<id>_idle.png and <id>/frames.json) are removed on each run.
"""

import json
import os
import sys

from PIL import Image

# ---------- palette (한지 톤) ----------
HANJI_YELLOW = (212, 165, 116)
JADE         = ( 91, 173, 138)
INK          = ( 45,  45,  45)
VERMILLION   = (232,  93,  58)
SKY          = (123, 200, 246)
GOLD         = (240, 199,  94)
PURPLE       = (156, 123, 208)
BROWN_ARMOR  = (139,  90,  43)
LEAF_GREEN   = ( 91, 173, 138)
OUTLINE      = ( 26,  26,  26)
SKIN         = (255, 220, 178)
WHITE        = (255, 255, 255)

CHARACTERS = [
    # id,         main color,   motif key
    ("barami",    SKY,          "headband"),
    ("byeolee",   PURPLE,       "star"),
    ("dolsoe",    BROWN_ARMOR,  "armor"),
    ("geurimja",  INK,          "white_eyes"),
    ("hwalee",    VERMILLION,   "flame"),
    ("ttukttaki", LEAF_GREEN,   "leaf"),
]

CANVAS = 32
FRAMES = 4
# Sine-like breathing offset (in pixels), applied to the entire character.
FRAME_SHIFTS = [0, -1, 0, 1]


def darken(rgb, factor=0.8):
    return tuple(max(0, min(255, int(c * factor))) for c in rgb)


def _put(px, x, y, color):
    if 0 <= x < CANVAS and 0 <= y < CANVAS:
        if len(color) == 3:
            color = color + (255,)
        px[x, y] = color


def _fill_rect(px, x0, y0, x1, y1, color, dy=0):
    """Inclusive-coordinate filled rectangle, shifted by dy on the y axis."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            _put(px, x, y + dy, color)


def _fill_head(px, dy=0):
    """Fill the head as an ellipse bounded by (8..23, 4..16)."""
    cx = (8 + 23) / 2.0
    cy = (4 + 16) / 2.0
    rx = (23 - 8) / 2.0
    ry = (16 - 4) / 2.0
    for y in range(4, 17):
        for x in range(8, 24):
            ndx = (x + 0.5 - cx) / rx
            ndy = (y + 0.5 - cy) / ry
            if ndx * ndx + ndy * ndy <= 1.0:
                _put(px, x, y + dy, SKIN)


def _draw_motif(px, motif, main, dy=0):
    if motif == "headband":
        # White band across the forehead.
        for x in range(9, 23):
            _put(px, x, 8 + dy, WHITE)
    elif motif == "star":
        # Small gold plus-shaped star above the head.
        cx, cy = 15, 2
        _put(px, cx, cy + dy, GOLD)
        _put(px, cx - 1, cy + dy, GOLD)
        _put(px, cx + 1, cy + dy, GOLD)
        _put(px, cx, cy - 1 + dy, GOLD)
        _put(px, cx, cy + 1 + dy, GOLD)
    elif motif == "armor":
        # Darker shoulder line across the chest top, with gold studs on each shoulder.
        for x in range(9, 22):
            _put(px, x, 16 + dy, darken(main, 0.6))
        _put(px, 10, 17 + dy, GOLD)
        _put(px, 21, 17 + dy, GOLD)
    elif motif == "white_eyes":
        # Handled in _draw_eyes (eye color flipped to white).
        pass
    elif motif == "flame":
        # Small gold flame above the head.
        cx, cy = 15, 2
        _put(px, cx, cy + dy, GOLD)
        _put(px, cx, cy + 1 + dy, GOLD)
        _put(px, cx - 1, cy + 1 + dy, GOLD)
        _put(px, cx + 1, cy + 1 + dy, GOLD)
    elif motif == "leaf":
        # Small gold leaf above the head.
        cx, cy = 15, 2
        _put(px, cx, cy + dy, GOLD)
        _put(px, cx + 1, cy + dy, GOLD)
        _put(px, cx, cy + 1 + dy, GOLD)


def _draw_eyes(px, motif, dy=0):
    color = WHITE if motif == "white_eyes" else OUTLINE
    _put(px, 13, 11 + dy, color)
    _put(px, 18, 11 + dy, color)


def _add_outline(img):
    """Add a 1-pixel OUTLINE around every opaque region using 4-neighborhood."""
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
        px[x, y] = OUTLINE + (255,)


def _fill_hair_cap(px, color, dy=0):
    """Thin cap of main color across the top of the head (y=4..5)."""
    cx = (8 + 23) / 2.0
    rx = (23 - 8) / 2.0
    for y in (4, 5):
        ndy = (y + 0.5 - (4 + 16) / 2.0) / ((16 - 4) / 2.0)
        for x in range(8, 24):
            ndx = (x + 0.5 - cx) / rx
            if ndx * ndx + ndy * ndy <= 1.0:
                _put(px, x, y + dy, color)


def _draw_frame(main, motif, dy):
    img = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    px = img.load()

    # Body (widened past the recommendation so the SD silhouette is full
    # enough to land inside the 30..50% transparency band).
    _fill_rect(px, 9, 16, 22, 27, main, dy=dy)
    # Arms (wider, longer).
    _fill_rect(px, 5, 17, 9, 25, main, dy=dy)
    _fill_rect(px, 22, 17, 26, 25, main, dy=dy)
    # Legs (darker main color, wider).
    leg_color = darken(main, 0.8)
    _fill_rect(px, 10, 28, 14, 31, leg_color, dy=dy)
    _fill_rect(px, 17, 28, 21, 31, leg_color, dy=dy)
    # Head (SKIN-tone ellipse on top of body).
    _fill_head(px, dy=dy)
    # Hair cap — main color across the crown for silhouette density.
    # (Geurimja's "hair" is the same INK as its body; reads as a hood.)
    _fill_hair_cap(px, main, dy=dy)
    # Motif (chest band, headband, flame, etc.)
    _draw_motif(px, motif, main, dy=dy)
    # Eyes
    _draw_eyes(px, motif, dy=dy)
    # Outline (applied AFTER shift + all drawing).
    _add_outline(img)
    return img


def _build_sheet(main, motif):
    sheet = Image.new("RGBA", (CANVAS * FRAMES, CANVAS), (0, 0, 0, 0))
    for i, dy in enumerate(FRAME_SHIFTS):
        frame = _draw_frame(main, motif, dy)
        sheet.paste(frame, (i * CANVAS, 0), frame)
    return sheet


def _alpha_ratio(img):
    """Ratio of fully transparent pixels (alpha == 0)."""
    w, h = img.size
    px = img.load()
    transparent = sum(
        1 for y in range(h) for x in range(w) if px[x, y][3] == 0
    )
    return transparent / (w * h)


def main_run():
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    base = os.path.join(project_root, "assets", "sprites", "characters")
    os.makedirs(base, exist_ok=True)

    failures = []
    for char_id, color, motif in CHARACTERS:
        sheet = _build_sheet(color, motif)
        sheet_path = os.path.join(base, f"{char_id}_idle.png")
        sheet.save(sheet_path, "PNG")

        frames_path = os.path.join(base, f"{char_id}_idle.json")
        with open(frames_path, "w", encoding="utf-8") as f:
            json.dump(
                {
                    "size": [CANVAS, CANVAS],
                    "frames": FRAMES,
                    "layout": "hstrip",
                    "sheet": f"{char_id}_idle.png",
                },
                f,
                ensure_ascii=False,
                indent=2,
            )

        legacy_dir = os.path.join(base, char_id)
        for legacy in (
            os.path.join(legacy_dir, f"{char_id}_idle.png"),
            os.path.join(legacy_dir, "frames.json"),
        ):
            if os.path.isfile(legacy):
                os.remove(legacy)

        ratio = _alpha_ratio(sheet)
        ok = 0.30 <= ratio <= 0.50
        tag = "OK" if ok else "FAIL"
        print(
            f"[{tag}] {char_id}: {sheet_path} "
            f"size={sheet.size} transparent_ratio={ratio:.3f}"
        )
        print(f"[OK] {char_id}: {frames_path}")
        if not ok:
            failures.append((char_id, ratio))

    if failures:
        print(
            f"[ERROR] {len(failures)} sprite(s) outside 0.30..0.50 transparent ratio:",
            file=sys.stderr,
        )
        for cid, r in failures:
            print(f"  - {cid}: {r:.3f}", file=sys.stderr)
        sys.exit(2)

    print(f"[DONE] generated {len(CHARACTERS)} idle sprite sheets.")


if __name__ == "__main__":
    main_run()
