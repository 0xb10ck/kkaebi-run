"""UI asset generator for kkaebi-run (hanji/dokkaebi theme).

Generates deterministic PNG assets used by menus, HUD and panels.
No dithering, no anti-aliasing.

Install:
    pip install Pillow

Run:
    python tools/generate_ui.py
"""

import os
import random as _random
import sys

from PIL import Image


# Palette (hanji / wood / dokkaebi tones) ---------------------------------
HANJI_BG    = (244, 232, 208, 255)
HANJI_DARK  = (212, 165, 116, 255)
WOOD        = (139,  90,  43, 255)
WOOD_DARK   = ( 90,  58,  30, 255)
INK         = ( 45,  45,  45, 255)
OUTLINE     = ( 26,  26,  26, 255)
GOLD        = (240, 199,  94, 255)
JADE        = ( 91, 173, 138, 255)
VERMILLION  = (232,  93,  58, 255)
HP_RED      = (214,  71,  57, 255)
HP_DARK     = (120,  30,  28, 255)
CLOTH       = (244, 232, 208, 255)
SKY         = (123, 200, 246, 255)
WHITE       = (255, 255, 255, 255)
TRANSPARENT = (0, 0, 0, 0)


OUT_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui")
)


def log(msg):
    print(f"[generate_ui] {msg}", flush=True)


def save(img, name):
    path = os.path.join(OUT_DIR, name)
    img.save(path, "PNG")
    log(f"wrote {name} ({img.size[0]}x{img.size[1]} RGBA)")


def _mix(c1, c2, t):
    return tuple(int(round(c1[i] * (1 - t) + c2[i] * t)) for i in range(4))


def _opaque(c):
    return (c[0], c[1], c[2], 255)


def _punch_corners(px, w, h):
    """Set the 4 outermost corner pixels transparent (subtle rounding, sanity check)."""
    px[0, 0] = TRANSPARENT
    px[w - 1, 0] = TRANSPARENT
    px[0, h - 1] = TRANSPARENT
    px[w - 1, h - 1] = TRANSPARENT


# ---------------------------------------------------------------- panel_frame
def make_panel_frame():
    """64x64 9-patch: hanji base + 2px wood border + 1px inner outline + 4x4 rounded corners."""
    w = h = 64
    img = Image.new("RGBA", (w, h), TRANSPARENT)
    px = img.load()

    # 4x4 corner shape (1 = inside the rounded rect)
    corner = [
        [0, 0, 1, 1],
        [0, 1, 1, 1],
        [1, 1, 1, 1],
        [1, 1, 1, 1],
    ]
    cw = 4

    def inside(x, y):
        if x < cw and y < cw:
            return corner[y][x] == 1
        if x >= w - cw and y < cw:
            return corner[y][w - 1 - x] == 1
        if x < cw and y >= h - cw:
            return corner[h - 1 - y][x] == 1
        if x >= w - cw and y >= h - cw:
            return corner[h - 1 - y][w - 1 - x] == 1
        return True

    for y in range(h):
        for x in range(w):
            if not inside(x, y):
                continue
            d = min(x, w - 1 - x, y, h - 1 - y)
            if d == 0:
                px[x, y] = WOOD_DARK
            elif d == 1:
                px[x, y] = WOOD
            elif d == 2:
                px[x, y] = OUTLINE
            else:
                px[x, y] = HANJI_BG

    save(img, "panel_frame.png")


# ------------------------------------------------------------------- buttons
def _make_button(name, base, border, border_w, press_offset=0, sparkle=False):
    w, h = 96, 32
    img = Image.new("RGBA", (w, h), TRANSPARENT)
    px = img.load()

    for y in range(h):
        for x in range(w):
            yy = y - press_offset
            if yy < 0:
                # "depressed" feel: top row left transparent
                continue
            d = min(x, w - 1 - x, yy, h - 1 - yy)
            if d < border_w:
                px[x, y] = border
            else:
                px[x, y] = base

    # round corners 2px so 9-patch slice (>=4px corner region) still works
    for (cx, cy) in [(0, 0), (1, 0), (0, 1),
                     (w - 1, 0), (w - 2, 0), (w - 1, 1),
                     (0, h - 1), (1, h - 1), (0, h - 2),
                     (w - 1, h - 1), (w - 2, h - 1), (w - 1, h - 2)]:
        px[cx, cy] = TRANSPARENT

    if sparkle:
        # top-right 1px white sparkle, just inside the border
        px[w - 4, 2] = WHITE

    save(img, name)


def make_buttons():
    _make_button("button_normal.png",  HANJI_BG,   WOOD,      border_w=1)
    _make_button("button_hover.png",   HANJI_BG,   GOLD,      border_w=2, sparkle=True)
    _make_button("button_pressed.png", HANJI_DARK, WOOD_DARK, border_w=1, press_offset=1)


# ------------------------------------------------------------------- hp bars
def make_hp_bar_frame():
    """128x16 outer 2px wood frame, hollow interior (alpha = 0)."""
    w, h = 128, 16
    img = Image.new("RGBA", (w, h), TRANSPARENT)
    px = img.load()
    for y in range(h):
        for x in range(w):
            d = min(x, w - 1 - x, y, h - 1 - y)
            if d < 2:
                px[x, y] = WOOD
    save(img, "hp_bar_frame.png")


def make_hp_bar_fill():
    """124x12 simple 3-tone gradient HP_DARK -> HP_RED, no outline, no dithering."""
    w, h = 124, 12
    img = Image.new("RGBA", (w, h), TRANSPARENT)
    px = img.load()

    mid = _opaque(_mix(HP_DARK, HP_RED, 0.5))
    third = w // 3
    bands = [
        (0,         third,     HP_DARK),
        (third,     2 * third, mid),
        (2 * third, w,         HP_RED),
    ]
    for x0, x1, color in bands:
        for x in range(x0, x1):
            for y in range(h):
                px[x, y] = color

    _punch_corners(px, w, h)
    save(img, "hp_bar_fill.png")


# ----------------------------------------------------------- skill icon frame
def make_skill_icon_frame():
    """40x40 hanji base + 2px gold border + inner 32x32 slot slightly darker."""
    w = h = 40
    img = Image.new("RGBA", (w, h), HANJI_BG)
    px = img.load()

    for y in range(h):
        for x in range(w):
            d = min(x, w - 1 - x, y, h - 1 - y)
            if d < 2:
                px[x, y] = GOLD

    slot = _opaque(_mix(HANJI_BG, HANJI_DARK, 0.35))
    for y in range(4, 4 + 32):
        for x in range(4, 4 + 32):
            px[x, y] = slot

    _punch_corners(px, w, h)
    save(img, "skill_icon_frame.png")


# -------------------------------------------------------------- level up bg
def make_level_up_bg():
    """320x200 hanji bg + 4px wood frame + top label band (darker) inside the frame."""
    w, h = 320, 200
    img = Image.new("RGBA", (w, h), HANJI_BG)
    px = img.load()

    for y in range(h):
        for x in range(w):
            d = min(x, w - 1 - x, y, h - 1 - y)
            if d < 4:
                px[x, y] = WOOD

    label = _opaque(_mix(HANJI_BG, HANJI_DARK, 0.35))
    for y in range(4, 36):
        for x in range(4, w - 4):
            px[x, y] = label

    _punch_corners(px, w, h)
    save(img, "level_up_bg.png")


# ------------------------------------------------------------- main_menu_bg
def make_main_menu_bg():
    """480x854 vertical gradient (SKY top -> HANJI_BG bottom) + bottom-quarter hanji noise."""
    w, h = 480, 854
    img = Image.new("RGBA", (w, h), TRANSPARENT)
    px = img.load()

    for y in range(h):
        t = y / (h - 1)
        c = _opaque(_mix(SKY, HANJI_BG, t))
        for x in range(w):
            px[x, y] = c

    rng = _random.Random(0xCAFEBABE)
    start_y = (h * 3) // 4
    for y in range(start_y, h):
        for x in range(w):
            r = rng.random()
            if r < 0.06:
                cur = px[x, y]
                px[x, y] = _opaque(_mix(cur, HANJI_DARK, 0.25))
            elif r < 0.09:
                cur = px[x, y]
                px[x, y] = (
                    min(cur[0] + 8, 255),
                    min(cur[1] + 8, 255),
                    min(cur[2] + 8, 255),
                    255,
                )

    _punch_corners(px, w, h)
    save(img, "main_menu_bg.png")


# ------------------------------------------------------------- 5x7 bitmap font
FONT_5x7 = {
    'K': [
        "1...1",
        "1..1.",
        "1.1..",
        "11...",
        "1.1..",
        "1..1.",
        "1...1",
    ],
    'A': [
        ".111.",
        "1...1",
        "1...1",
        "11111",
        "1...1",
        "1...1",
        "1...1",
    ],
    'E': [
        "11111",
        "1....",
        "1....",
        "1111.",
        "1....",
        "1....",
        "11111",
    ],
    'B': [
        "1111.",
        "1...1",
        "1...1",
        "1111.",
        "1...1",
        "1...1",
        "1111.",
    ],
    'I': [
        "11111",
        "..1..",
        "..1..",
        "..1..",
        "..1..",
        "..1..",
        "11111",
    ],
    'R': [
        "1111.",
        "1...1",
        "1...1",
        "1111.",
        "1.1..",
        "1..1.",
        "1...1",
    ],
    'U': [
        "1...1",
        "1...1",
        "1...1",
        "1...1",
        "1...1",
        "1...1",
        ".111.",
    ],
    'N': [
        "1...1",
        "11..1",
        "11..1",
        "1.1.1",
        "1.1.1",
        "1..11",
        "1...1",
    ],
    ' ': ["....."] * 7,
}


def _draw_text_5x7(px, x0, y0, text, color, scale=1):
    cell_w = 5 * scale + 1 * scale  # 1 cell spacing
    for i, ch in enumerate(text):
        glyph = FONT_5x7.get(ch, FONT_5x7[' '])
        gx = x0 + i * cell_w
        for r, row in enumerate(glyph):
            for c, p in enumerate(row):
                if p == '1':
                    for sy in range(scale):
                        for sx in range(scale):
                            px[gx + c * scale + sx, y0 + r * scale + sy] = color


# ------------------------------------------------------- triangle (no AA fill)
def _sign(a, b, c):
    return (a[0] - c[0]) * (b[1] - c[1]) - (b[0] - c[0]) * (a[1] - c[1])


def _point_in_tri(p, a, b, c):
    d1 = _sign(p, a, b)
    d2 = _sign(p, b, c)
    d3 = _sign(p, c, a)
    has_neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
    has_pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
    return not (has_neg and has_pos)


def _fill_triangle(px, p1, p2, p3, color, w, h):
    xs = [p[0] for p in (p1, p2, p3)]
    ys = [p[1] for p in (p1, p2, p3)]
    for y in range(max(0, min(ys)), min(h, max(ys) + 1)):
        for x in range(max(0, min(xs)), min(w, max(xs) + 1)):
            if _point_in_tri((x, y), p1, p2, p3):
                px[x, y] = color


# ---------------------------------------------------------------------- logo
def make_logo():
    """256x96 transparent logo: dokkaebi head + horns + hanji band + 'KKAEBI RUN' bitmap."""
    w, h = 256, 96
    img = Image.new("RGBA", (w, h), TRANSPARENT)
    px = img.load()

    # 1) dokkaebi head: filled disc (no AA)
    head_cx, head_cy, head_r = 40, 56, 26
    for y in range(h):
        for x in range(w):
            dx = x - head_cx
            dy = y - head_cy
            if dx * dx + dy * dy <= head_r * head_r:
                px[x, y] = INK

    # 2) two vermillion horns (triangles, outward-leaning)
    _fill_triangle(px,
                   (head_cx - 14, head_cy - head_r + 5),
                   (head_cx - 2,  head_cy - head_r + 3),
                   (head_cx - 22, head_cy - head_r - 14),
                   VERMILLION, w, h)
    _fill_triangle(px,
                   (head_cx + 2,  head_cy - head_r + 3),
                   (head_cx + 14, head_cy - head_r + 5),
                   (head_cx + 22, head_cy - head_r - 14),
                   VERMILLION, w, h)

    # 3) 1px outline around head + horns (transparent pixels adjacent to drawn pixels)
    pending = []
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            if px[x, y] != TRANSPARENT:
                continue
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    n = px[x + dx, y + dy]
                    if n == INK or n == VERMILLION:
                        pending.append((x, y))
                        break
                else:
                    continue
                break
    for (x, y) in pending:
        px[x, y] = OUTLINE

    # 4) hanji band on the right + 1px outline
    band_x0, band_x1 = 80, 248
    band_y0, band_y1 = 32, 64
    for y in range(band_y0, band_y1):
        for x in range(band_x0, band_x1):
            px[x, y] = HANJI_BG
    for x in range(band_x0, band_x1):
        px[x, band_y0] = OUTLINE
        px[x, band_y1 - 1] = OUTLINE
    for y in range(band_y0, band_y1):
        px[band_x0, y] = OUTLINE
        px[band_x1 - 1, y] = OUTLINE

    # 5) bitmap text "KKAEBI RUN" centered on band, scale=2 -> 12px cells, 14px tall
    text = "KKAEBI RUN"
    scale = 2
    cell_w = 5 * scale + 1 * scale  # 12
    text_w = len(text) * cell_w - 1 * scale  # drop trailing space
    text_h = 7 * scale
    text_x = band_x0 + ((band_x1 - band_x0) - text_w) // 2
    text_y = band_y0 + ((band_y1 - band_y0) - text_h) // 2
    _draw_text_5x7(px, text_x, text_y, text, INK, scale=scale)

    save(img, "logo.png")


# ------------------------------------------------------------------------ main
def main():
    log(f"output dir: {OUT_DIR}")
    os.makedirs(OUT_DIR, exist_ok=True)

    make_panel_frame()
    make_buttons()
    make_hp_bar_frame()
    make_hp_bar_fill()
    make_skill_icon_frame()
    make_level_up_bg()
    make_main_menu_bg()
    make_logo()

    log("done")


if __name__ == "__main__":
    sys.exit(main())
