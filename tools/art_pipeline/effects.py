"""Skill effect sprites.

32x32 per frame, 4 frames per effect -> 128x32 sheet.
Shapes: projectile (radial trail), aoe (expanding ring), aura (pulsing).
Color keys: fire / water / wood / metal / earth / shadow (per palette).
Aliases requested in task: light/lightning/ice/fire/wind/earth/star map to existing keys.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List, Tuple

from PIL import Image

from . import primitives as P
from .palette import RGB, hex_to_rgb, load_palette, outline_color, skill_colors

FRAME = 32
CX = 16
CY = 16


# Logical key -> palette key (we only have 6 base color keys; aliases reuse).
KEY_ALIAS: Dict[str, str] = {
    "fire": "fire",
    "water": "water",
    "ice": "water",
    "wood": "wood",
    "wind": "wood",
    "metal": "metal",
    "light": "metal",
    "lightning": "metal",
    "star": "metal",
    "earth": "earth",
    "shadow": "shadow",
}

SHAPES = ("projectile", "aoe", "aura")


def _projectile_frame(idx: int, main: RGB, sub: RGB, outline: RGB) -> Image.Image:
    img = P.new_canvas(FRAME, FRAME)
    # head moves left->right; trail behind
    head_x = 6 + idx * 6
    P.fill_circle(img, head_x, CY, 3, main)
    P.fill_circle(img, head_x, CY, 1, sub)
    # trail dots behind
    for i in range(1, 4):
        tx = head_x - i * 3
        if tx >= 0:
            P.fill_circle(img, tx, CY, max(1, 3 - i), sub)
    return P.add_outline(img, outline)


def _aoe_frame(idx: int, main: RGB, sub: RGB, outline: RGB) -> Image.Image:
    img = P.new_canvas(FRAME, FRAME)
    r = 3 + idx * 4
    # ring (filled annulus)
    P.fill_circle(img, CX, CY, r, sub)
    if r > 2:
        P.fill_circle(img, CX, CY, r - 2, (0, 0, 0, 0))
    # core highlight
    P.fill_circle(img, CX, CY, 1, main)
    return P.add_outline(img, outline)


def _aura_frame(idx: int, main: RGB, sub: RGB, outline: RGB) -> Image.Image:
    img = P.new_canvas(FRAME, FRAME)
    pulse_radii = [5, 7, 9, 7]
    r = pulse_radii[idx % len(pulse_radii)]
    P.fill_circle(img, CX, CY, r, sub)
    P.fill_circle(img, CX, CY, max(1, r - 3), main)
    # 4 little sparks rotating
    spark = (idx % 4)
    sparks = [(CX, CY - r - 1), (CX + r + 1, CY), (CX, CY + r + 1), (CX - r - 1, CY)]
    sx, sy = sparks[spark]
    P.put(img, sx, sy, main)
    return P.add_outline(img, outline)


def _render_one(shape: str, palette_key: str) -> Image.Image:
    colors = skill_colors(palette_key)
    main = colors["main"]
    sub = colors["sub"]
    outline = colors["outline"]
    frames: List[Image.Image] = []
    for i in range(4):
        if shape == "projectile":
            frames.append(_projectile_frame(i, main, sub, outline))
        elif shape == "aoe":
            frames.append(_aoe_frame(i, main, sub, outline))
        elif shape == "aura":
            frames.append(_aura_frame(i, main, sub, outline))
        else:
            raise ValueError(f"unknown shape: {shape}")
    return P.compose_horizontal(frames)


def render_effect_sheet(shape: str, key: str, out_dir: Path) -> Path:
    palette_key = KEY_ALIAS.get(key, key)
    if palette_key not in load_palette()["skill_effect_keys"]:
        raise ValueError(f"unknown skill key: {key} (resolved to {palette_key})")
    sheet = _render_one(shape, palette_key)
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"fx_{shape}_{key}.png"
    sheet.save(out_path)
    return out_path


def build_all_effects(out_dir: Path) -> List[Path]:
    outs: List[Path] = []
    keys = sorted(set(KEY_ALIAS.keys()))
    for shape in SHAPES:
        for k in keys:
            outs.append(render_effect_sheet(shape, k, out_dir))
    meta = {
        "shapes": list(SHAPES),
        "keys": keys,
        "key_alias": KEY_ALIAS,
        "frame_size": [FRAME, FRAME],
        "sheet_size": [FRAME * 4, FRAME],
    }
    with open(out_dir / "effects.json", "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
    return outs
