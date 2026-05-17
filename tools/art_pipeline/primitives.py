"""Pixel-art primitives. Out-of-bounds is silently ignored. No dithering."""
from __future__ import annotations

from typing import Sequence, Tuple, Union

from PIL import Image

ColorIn = Union[Tuple[int, int, int], Tuple[int, int, int, int]]
RGBA = Tuple[int, int, int, int]


def to_rgba(c: ColorIn) -> RGBA:
    if len(c) == 3:
        return (c[0], c[1], c[2], 255)
    return (c[0], c[1], c[2], c[3])


def new_canvas(w: int, h: int, fill: ColorIn = (0, 0, 0, 0)) -> Image.Image:
    return Image.new("RGBA", (w, h), to_rgba(fill))


def put(img: Image.Image, x: int, y: int, color: ColorIn) -> None:
    w, h = img.size
    if 0 <= x < w and 0 <= y < h:
        img.putpixel((x, y), to_rgba(color))


def hline(img: Image.Image, x0: int, x1: int, y: int, color: ColorIn) -> None:
    if x0 > x1:
        x0, x1 = x1, x0
    for x in range(x0, x1 + 1):
        put(img, x, y, color)


def vline(img: Image.Image, x: int, y0: int, y1: int, color: ColorIn) -> None:
    if y0 > y1:
        y0, y1 = y1, y0
    for y in range(y0, y1 + 1):
        put(img, x, y, color)


def fill_rect(img: Image.Image, x0: int, y0: int, x1: int, y1: int, color: ColorIn) -> None:
    if x0 > x1:
        x0, x1 = x1, x0
    if y0 > y1:
        y0, y1 = y1, y0
    for y in range(y0, y1 + 1):
        hline(img, x0, x1, y, color)


def rect_outline(img: Image.Image, x0: int, y0: int, x1: int, y1: int, color: ColorIn) -> None:
    hline(img, x0, x1, y0, color)
    hline(img, x0, x1, y1, color)
    vline(img, x0, y0, y1, color)
    vline(img, x1, y0, y1, color)


def fill_circle(img: Image.Image, cx: int, cy: int, r: int, color: ColorIn) -> None:
    if r <= 0:
        put(img, cx, cy, color)
        return
    r2 = r * r
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r2:
                put(img, cx + dx, cy + dy, color)


def circle_outline(img: Image.Image, cx: int, cy: int, r: int, color: ColorIn) -> None:
    if r <= 0:
        put(img, cx, cy, color)
        return
    r2 = r * r
    inner = (r - 1) * (r - 1)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            d = dx * dx + dy * dy
            if inner < d <= r2:
                put(img, cx + dx, cy + dy, color)


def fill_ellipse(img: Image.Image, cx: int, cy: int, rx: int, ry: int, color: ColorIn) -> None:
    if rx <= 0 or ry <= 0:
        put(img, cx, cy, color)
        return
    rx2, ry2 = rx * rx, ry * ry
    for dy in range(-ry, ry + 1):
        for dx in range(-rx, rx + 1):
            if (dx * dx) * ry2 + (dy * dy) * rx2 <= rx2 * ry2:
                put(img, cx + dx, cy + dy, color)


def droplet(img: Image.Image, cx: int, top_y: int, radius: int, color: ColorIn) -> None:
    """Round bottom, pointed top droplet shape."""
    if radius <= 0:
        return
    fill_circle(img, cx, top_y + radius, radius, color)
    for i in range(radius):
        w = max(0, radius - i - 1)
        hline(img, cx - w, cx + w, top_y + i, color)


def stamp_mirror(img: Image.Image, x: int, y: int, color: ColorIn, axis_x: int) -> None:
    """Set pixel and its mirror across vertical axis_x line."""
    put(img, x, y, color)
    mx = 2 * axis_x - x
    if mx != x:
        put(img, mx, y, color)


def shift(img: Image.Image, dx: int, dy: int) -> Image.Image:
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (dx, dy), img)
    return out


def scale_nearest(img: Image.Image, factor: int) -> Image.Image:
    if factor == 1:
        return img.copy()
    return img.resize((img.width * factor, img.height * factor), Image.NEAREST)


def mirror_horizontal(img: Image.Image) -> Image.Image:
    return img.transpose(Image.FLIP_LEFT_RIGHT)


def compose_horizontal(frames: Sequence[Image.Image]) -> Image.Image:
    if not frames:
        raise ValueError("compose_horizontal: empty frame list")
    fw, fh = frames[0].size
    sheet = Image.new("RGBA", (fw * len(frames), fh), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        if fr.size != (fw, fh):
            raise ValueError(f"frame {i} size mismatch: {fr.size} vs {(fw, fh)}")
        sheet.paste(fr, (i * fw, 0), fr)
    return sheet


def compose_grid(tiles: Sequence[Image.Image], cols: int) -> Image.Image:
    if not tiles:
        raise ValueError("compose_grid: empty tiles")
    tw, th = tiles[0].size
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGBA", (tw * cols, th * rows), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        r, c = divmod(i, cols)
        sheet.paste(t, (c * tw, r * th), t)
    return sheet


def add_outline(img: Image.Image, color: ColorIn, threshold_alpha: int = 1) -> Image.Image:
    """Add a 1px 4-neighbor outline around any opaque pixel."""
    w, h = img.size
    out = img.copy()
    src = img.load()
    dst = out.load()
    c = to_rgba(color)
    for y in range(h):
        for x in range(w):
            if src[x, y][3] >= threshold_alpha:
                continue
            opaque_neighbor = False
            if x > 0 and src[x - 1, y][3] >= threshold_alpha:
                opaque_neighbor = True
            elif x + 1 < w and src[x + 1, y][3] >= threshold_alpha:
                opaque_neighbor = True
            elif y > 0 and src[x, y - 1][3] >= threshold_alpha:
                opaque_neighbor = True
            elif y + 1 < h and src[x, y + 1][3] >= threshold_alpha:
                opaque_neighbor = True
            if opaque_neighbor:
                dst[x, y] = c
    return out


def red_flash(img: Image.Image, intensity: float = 0.65) -> Image.Image:
    out = img.copy()
    px = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            r = int(r + (255 - r) * intensity)
            g = int(g * (1.0 - intensity * 0.7))
            b = int(b * (1.0 - intensity * 0.7))
            px[x, y] = (r, g, b, a)
    return out


def crop_safe(img: Image.Image, x0: int, y0: int, w: int, h: int) -> Image.Image:
    return img.crop((x0, y0, x0 + w, y0 + h))
