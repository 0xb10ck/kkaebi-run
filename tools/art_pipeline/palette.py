"""Palette loader and color helpers.

Single source of truth: docs/art-palette.json.
docs/art-asset-spec.md overrides on conflict (the JSON is updated to match).
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, Optional, Tuple

RGB = Tuple[int, int, int]
RGBA = Tuple[int, int, int, int]


def project_root() -> Path:
    return Path(__file__).resolve().parents[2]


def palette_path(root: Optional[Path] = None) -> Path:
    return (root or project_root()) / "docs" / "art-palette.json"


_cache: Optional[Dict] = None


def load_palette(root: Optional[Path] = None) -> Dict:
    global _cache
    if _cache is None:
        with open(palette_path(root), "r", encoding="utf-8") as f:
            _cache = json.load(f)
    return _cache


def reset_cache() -> None:
    global _cache
    _cache = None


def hex_to_rgb(h: str) -> RGB:
    s = h.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


def rgb_to_hex(c: RGB) -> str:
    return "#{:02X}{:02X}{:02X}".format(c[0], c[1], c[2])


def hex_to_rgba(h: str, a: int = 255) -> RGBA:
    r, g, b = hex_to_rgb(h)
    return (r, g, b, a)


def lighten(c: RGB, amount: float = 0.2) -> RGB:
    return (
        min(255, int(c[0] + (255 - c[0]) * amount)),
        min(255, int(c[1] + (255 - c[1]) * amount)),
        min(255, int(c[2] + (255 - c[2]) * amount)),
    )


def darken(c: RGB, amount: float = 0.2) -> RGB:
    return (
        max(0, int(c[0] * (1.0 - amount))),
        max(0, int(c[1] * (1.0 - amount))),
        max(0, int(c[2] * (1.0 - amount))),
    )


def outline_color(root: Optional[Path] = None) -> RGB:
    return hex_to_rgb(load_palette(root)["global"]["outline_hex"])


def base_color(token: str) -> RGB:
    return hex_to_rgb(load_palette()["base"][token])


def character_colors(char_id: str) -> Dict[str, RGB]:
    e = load_palette()["characters"][char_id]
    return {
        "main": hex_to_rgb(e["main"]),
        "sub": hex_to_rgb(e["sub"]),
        "point": hex_to_rgb(e["point"]),
        "props": e.get("props", []),
    }


def chapter_tileset(chapter_id: str) -> Dict[str, RGB]:
    e = load_palette()["chapter_tilesets"][chapter_id]
    return {
        "ground": hex_to_rgb(e["ground"]),
        "wall": hex_to_rgb(e["wall"]),
        "deco": hex_to_rgb(e["deco"]),
        "accent": hex_to_rgb(e["accent"]),
    }


def skill_colors(key: str) -> Dict[str, RGB]:
    e = load_palette()["skill_effect_keys"][key]
    return {
        "main": hex_to_rgb(e["main"]),
        "sub": hex_to_rgb(e["sub"]),
        "outline": hex_to_rgb(e["outline"]),
    }


def ui_colors(slot: str) -> Dict[str, RGB]:
    e = load_palette()["ui"][slot]
    return {k: hex_to_rgb(v) for k, v in e.items()}
