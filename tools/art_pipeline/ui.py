"""UI assets: 9-slice buttons, panels (hanji/wood), HP bar, skill frame,
level-up panel, main-menu logo, paper background.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List, Tuple

from PIL import Image

from . import primitives as P
from .palette import RGB, darken, hex_to_rgb, lighten, load_palette, outline_color, ui_colors


def _9slice_button(state: str, w: int = 64, h: int = 32) -> Image.Image:
    c = ui_colors("button_state")
    fill = c[state]
    o = c["outline"]
    img = P.new_canvas(w, h)
    # rounded rect fill
    P.fill_rect(img, 1, 1, w - 2, h - 2, fill)
    # corner round (cut corner pixels)
    for (x, y) in [(1, 1), (1, h - 2), (w - 2, 1), (w - 2, h - 2)]:
        img.putpixel((x, y), (0, 0, 0, 0))
    # highlight top
    P.hline(img, 2, w - 3, 2, lighten(fill, 0.25))
    # shadow bottom
    P.hline(img, 2, w - 3, h - 3, darken(fill, 0.25))
    # outline
    img = P.add_outline(img, o)
    return img


def render_buttons(out_dir: Path) -> List[Path]:
    outs: List[Path] = []
    for st in ("normal", "hover", "pressed"):
        img = _9slice_button(st)
        p = out_dir / f"button_{st}.png"
        img.save(p)
        outs.append(p)
    return outs


def _hanji_panel(w: int = 128, h: int = 64) -> Image.Image:
    c = ui_colors("panel_hanji")
    img = P.new_canvas(w, h, (c["fill"][0], c["fill"][1], c["fill"][2], 255))
    # paper texture: subtle deco dots
    for y in range(2, h - 2, 5):
        for x in range(3, w - 3, 7):
            img.putpixel((x, y), (c["edge"][0], c["edge"][1], c["edge"][2], 255))
    # edge band
    P.rect_outline(img, 0, 0, w - 1, h - 1, c["ink"])
    P.rect_outline(img, 2, 2, w - 3, h - 3, c["edge"])
    return img


def _wood_panel(w: int = 128, h: int = 64) -> Image.Image:
    c = ui_colors("panel_wood")
    img = P.new_canvas(w, h, (c["fill"][0], c["fill"][1], c["fill"][2], 255))
    # plank lines
    for y in (h // 3, (h * 2) // 3):
        P.hline(img, 1, w - 2, y, c["edge"])
    # corner nails
    for (x, y) in [(3, 3), (w - 4, 3), (3, h - 4), (w - 4, h - 4)]:
        img.putpixel((x, y), (c["ink"][0], c["ink"][1], c["ink"][2], 255))
    P.rect_outline(img, 0, 0, w - 1, h - 1, c["ink"])
    return img


def render_panels(out_dir: Path) -> List[Path]:
    outs: List[Path] = []
    p = out_dir / "panel_hanji.png"
    _hanji_panel().save(p)
    outs.append(p)
    p2 = out_dir / "panel_wood.png"
    _wood_panel().save(p2)
    outs.append(p2)
    return outs


def _hp_bar(w: int = 64, h: int = 8, ratio: float = 0.8) -> Image.Image:
    c = ui_colors("hp_bar")
    img = P.new_canvas(w, h)
    # back
    P.fill_rect(img, 1, 1, w - 2, h - 2, c["back"])
    # fill
    fw = max(0, int((w - 4) * ratio))
    if fw > 0:
        P.fill_rect(img, 2, 2, 1 + fw, h - 3, c["fill"])
    # edge
    P.rect_outline(img, 0, 0, w - 1, h - 1, c["edge"])
    return img


def render_hp_bar(out_dir: Path) -> List[Path]:
    p = out_dir / "hp_bar_full.png"
    _hp_bar(ratio=1.0).save(p)
    p2 = out_dir / "hp_bar_half.png"
    _hp_bar(ratio=0.5).save(p2)
    return [p, p2]


def _skill_frame(w: int = 32, h: int = 32) -> Image.Image:
    c = ui_colors("skill_frame")
    img = P.new_canvas(w, h, (c["fill"][0], c["fill"][1], c["fill"][2], 255))
    P.rect_outline(img, 0, 0, w - 1, h - 1, c["edge"])
    P.rect_outline(img, 1, 1, w - 2, h - 2, c["highlight"])
    # corner accents
    for (x, y) in [(2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3)]:
        img.putpixel((x, y), (c["edge"][0], c["edge"][1], c["edge"][2], 255))
    return img


def render_skill_frame(out_dir: Path) -> List[Path]:
    p = out_dir / "skill_frame.png"
    _skill_frame().save(p)
    return [p]


def _level_up_panel(w: int = 128, h: int = 64) -> Image.Image:
    c = ui_colors("level_up_panel")
    img = P.new_canvas(w, h, (c["fill"][0], c["fill"][1], c["fill"][2], 255))
    P.rect_outline(img, 0, 0, w - 1, h - 1, c["edge"])
    P.rect_outline(img, 2, 2, w - 3, h - 3, c["ink_title"])
    # ribbon mark across top
    P.fill_rect(img, 4, 4, w - 5, 9, c["ink_title"])
    P.hline(img, 4, w - 5, 11, c["edge"])
    return img


def render_level_up_panel(out_dir: Path) -> List[Path]:
    p = out_dir / "level_up_panel.png"
    _level_up_panel().save(p)
    return [p]


def _logo(w: int = 128, h: int = 32) -> Image.Image:
    c = ui_colors("logo")
    img = P.new_canvas(w, h, (c["back"][0], c["back"][1], c["back"][2], 255))
    # Pixel-block "K" "R" letters as decorative stamp
    P.fill_rect(img, 8, 8, 10, 24, c["ink"])
    P.fill_rect(img, 11, 14, 13, 17, c["ink"])
    P.fill_rect(img, 14, 8, 16, 13, c["ink"])
    P.fill_rect(img, 14, 18, 16, 24, c["ink"])
    # R
    P.fill_rect(img, 22, 8, 24, 24, c["ink"])
    P.fill_rect(img, 25, 8, 28, 9, c["ink"])
    P.fill_rect(img, 28, 10, 29, 14, c["ink"])
    P.fill_rect(img, 25, 15, 28, 16, c["ink"])
    P.fill_rect(img, 26, 17, 29, 24, c["ink"])
    # Vermilion seal block on the right
    P.fill_rect(img, w - 24, 4, w - 6, 24, c["fill"])
    P.rect_outline(img, w - 24, 4, w - 6, 24, c["ink"])
    P.fill_rect(img, w - 19, 9, w - 11, 19, c["back"])
    return img


def render_logo(out_dir: Path) -> List[Path]:
    p = out_dir / "logo.png"
    _logo().save(p)
    return [p]


def _paper_background(w: int = 128, h: int = 64) -> Image.Image:
    palette = load_palette()
    bg = hex_to_rgb(palette["base"]["paper_bg"])
    edge = hex_to_rgb(palette["base"]["hanji_yellow"])
    img = P.new_canvas(w, h, (bg[0], bg[1], bg[2], 255))
    for y in range(2, h, 6):
        P.hline(img, 0, w - 1, y, lighten(edge, 0.5))
    return img


def render_background(out_dir: Path) -> List[Path]:
    p = out_dir / "main_menu_bg.png"
    _paper_background().save(p)
    return [p]


def build_all_ui(out_dir: Path) -> List[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    outs: List[Path] = []
    outs.extend(render_buttons(out_dir))
    outs.extend(render_panels(out_dir))
    outs.extend(render_hp_bar(out_dir))
    outs.extend(render_skill_frame(out_dir))
    outs.extend(render_level_up_panel(out_dir))
    outs.extend(render_logo(out_dir))
    outs.extend(render_background(out_dir))

    meta = {
        "buttons": ["normal", "hover", "pressed"],
        "panels": ["hanji", "wood"],
        "hp_bar": ["full", "half"],
        "level_up_panel": "level_up_panel.png",
        "logo": "logo.png",
        "background": "main_menu_bg.png",
    }
    with open(out_dir / "ui.json", "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
    return outs
