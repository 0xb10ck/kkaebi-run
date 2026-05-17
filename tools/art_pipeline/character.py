"""SD-proportion character renderer.

32x32 per frame, animations: idle(4) + run(6) + attack(4) + hit(2) + die(4) = 20 frames.
Output: <out_dir>/<char_id>.png (640x32 sheet) + <char_id>.frames.json.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from PIL import Image

from . import primitives as P
from .palette import (
    RGB,
    character_colors,
    hex_to_rgb,
    lighten,
    load_palette,
    outline_color,
)

FRAME = 32
CX = 16  # vertical mirror axis


@dataclass
class CharacterSpec:
    char_id: str
    main: RGB
    sub: RGB
    point: RGB
    motif: str = "none"           # 머리띠 / 별 / 잎 / 불꽃 / 투구 / 마스크 / none
    has_weapon: bool = False
    detail_slot: Optional[str] = None  # boss extension hook
    scale: int = 1


def _draw_motif(img: Image.Image, head_top: int, motif: str, main: RGB, point: RGB) -> None:
    if motif in ("머리띠", "headband"):
        P.hline(img, CX - 5, CX + 4, head_top + 2, point)
        P.put(img, CX - 1, head_top + 1, point)
        P.put(img, CX, head_top + 1, point)
    elif motif in ("별", "star"):
        P.put(img, CX, head_top - 1, point)
        P.put(img, CX - 1, head_top, point)
        P.put(img, CX + 1, head_top, point)
        P.put(img, CX, head_top + 1, point)
    elif motif in ("잎", "leaf"):
        P.put(img, CX, head_top - 2, point)
        P.put(img, CX - 1, head_top - 1, point)
        P.put(img, CX + 1, head_top - 1, point)
    elif motif in ("불꽃", "flame"):
        P.put(img, CX, head_top - 2, point)
        P.put(img, CX - 1, head_top - 1, point)
        P.put(img, CX + 1, head_top - 1, point)
        P.put(img, CX, head_top, point)
    elif motif in ("투구", "helmet"):
        P.hline(img, CX - 5, CX + 4, head_top, point)
        P.hline(img, CX - 5, CX + 4, head_top + 1, point)
        P.put(img, CX - 5, head_top + 2, point)
        P.put(img, CX + 4, head_top + 2, point)
    elif motif in ("마스크", "mask"):
        P.fill_rect(img, CX - 4, head_top + 5, CX + 3, head_top + 7, (40, 40, 40))
        P.put(img, CX - 2, head_top + 5, point)
        P.put(img, CX + 1, head_top + 5, point)


def _draw_base(
    spec: CharacterSpec,
    *,
    leg_l: int = 0,
    leg_r: int = 0,
    arm_l: int = 0,
    arm_r: int = 0,
    body_dy: int = 0,
    head_dy: int = 0,
    weapon_dx: int = 0,
    weapon_dy: int = 0,
    weapon_extended: bool = False,
) -> Image.Image:
    img = P.new_canvas(FRAME, FRAME)
    o = outline_color()
    main, sub, point = spec.main, spec.sub, spec.point

    head_top = 7 + head_dy
    head_cy = head_top + 5
    # Head silhouette (rounded)
    P.fill_ellipse(img, CX, head_cy, 6, 5, main)
    # Face (lighter inset)
    face = lighten(main, 0.35)
    P.fill_ellipse(img, CX, head_cy + 1, 5, 4, face)
    # Eyes
    P.put(img, CX - 2, head_cy, o)
    P.put(img, CX + 1, head_cy, o)

    # Body (10x9)
    by0 = 17 + body_dy
    by1 = 25 + body_dy
    P.fill_rect(img, 11, by0, 20, by1, main)
    # body shading lower belt
    P.fill_rect(img, 11, by1 - 2, 20, by1, sub)

    # Arms (left/right)
    ay0 = 18 + body_dy
    ay1 = 21 + body_dy
    P.fill_rect(img, 8, ay0 + arm_l, 10, ay1 + arm_l, main)
    P.fill_rect(img, 21, ay0 + arm_r, 23, ay1 + arm_r, main)
    # hand point
    P.put(img, 9, ay1 + arm_l, point)
    P.put(img, 22, ay1 + arm_r, point)

    # Legs
    ly0 = 26
    ly1 = 30
    P.fill_rect(img, 12, ly0 + leg_l, 14, ly1, sub)
    P.fill_rect(img, 17, ly0 + leg_r, 19, ly1, sub)
    # boots / feet
    P.hline(img, 11, 14, ly1, o)
    P.hline(img, 17, 20, ly1, o)

    # Motif
    _draw_motif(img, head_top, spec.motif, main, point)

    # Optional detail slot for boss variants
    if spec.detail_slot == "shoulder_spike":
        P.put(img, 10, by0 - 1, point)
        P.put(img, 21, by0 - 1, point)
    elif spec.detail_slot == "crown":
        P.hline(img, CX - 5, CX + 4, head_top - 1, point)
        P.put(img, CX - 4, head_top - 2, point)
        P.put(img, CX, head_top - 2, point)
        P.put(img, CX + 3, head_top - 2, point)

    # Weapon
    if spec.has_weapon:
        wx = 22 + weapon_dx
        wy = ay0 + 1 + weapon_dy
        if weapon_extended:
            P.hline(img, wx, min(FRAME - 1, wx + 5), wy, point)
            P.put(img, wx + 5, wy - 1, point)
            P.put(img, wx + 5, wy + 1, point)
        else:
            P.vline(img, wx, max(0, wy - 4), wy + 1, point)
            P.put(img, wx, max(0, wy - 5), point)

    # Outline 1px
    img = P.add_outline(img, o)
    return img


def _idle(spec: CharacterSpec) -> List[Image.Image]:
    return [
        _draw_base(spec, head_dy=0, body_dy=0),
        _draw_base(spec, head_dy=-1, body_dy=0),
        _draw_base(spec, head_dy=0, body_dy=0),
        _draw_base(spec, head_dy=0, body_dy=1),
    ]


def _run(spec: CharacterSpec) -> List[Image.Image]:
    return [
        _draw_base(spec, leg_l=0, leg_r=0, arm_l=0, arm_r=0, body_dy=0),
        _draw_base(spec, leg_l=-1, leg_r=0, arm_l=1, arm_r=-1, body_dy=-1),
        _draw_base(spec, leg_l=-2, leg_r=0, arm_l=2, arm_r=-2, body_dy=-1),
        _draw_base(spec, leg_l=0, leg_r=0, arm_l=0, arm_r=0, body_dy=0),
        _draw_base(spec, leg_l=0, leg_r=-1, arm_l=-1, arm_r=1, body_dy=-1),
        _draw_base(spec, leg_l=0, leg_r=-2, arm_l=-2, arm_r=2, body_dy=-1),
    ]


def _attack(spec: CharacterSpec) -> List[Image.Image]:
    return [
        _draw_base(spec, arm_r=-1, weapon_dx=-1, weapon_dy=-2),
        _draw_base(spec, arm_r=-2, weapon_extended=True, weapon_dx=-1, weapon_dy=-1),
        _draw_base(spec, arm_r=-3, weapon_extended=True, weapon_dx=0, weapon_dy=0),
        _draw_base(spec, arm_r=0),
    ]


def _hit(spec: CharacterSpec) -> List[Image.Image]:
    base = _draw_base(spec)
    flashed = P.red_flash(base, 0.7)
    return [flashed, P.shift(flashed, -1, 0)]


def _die(spec: CharacterSpec) -> List[Image.Image]:
    base = _draw_base(spec)
    f0 = base
    f1 = P.shift(base, 1, 1)
    f2 = P.shift(base, 2, 4)
    # final: collapsed at bottom
    f3 = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    f3.paste(base, (3, 8), base)
    return [f0, f1, f2, f3]


def render_character_sheet(spec: CharacterSpec, out_dir: Path) -> Tuple[Path, Path]:
    frames: List[Image.Image] = []
    frames += _idle(spec)
    frames += _run(spec)
    frames += _attack(spec)
    frames += _hit(spec)
    frames += _die(spec)

    if spec.scale > 1:
        frames = [P.scale_nearest(f, spec.scale) for f in frames]

    sheet = P.compose_horizontal(frames)
    out_dir.mkdir(parents=True, exist_ok=True)
    sheet_path = out_dir / f"{spec.char_id}.png"
    sheet.save(sheet_path)

    fw = FRAME * spec.scale
    meta = {
        "char_id": spec.char_id,
        "frame_size": [fw, fw],
        "sheet_size": list(sheet.size),
        "total_frames": 20,
        "anims": [
            {"name": "idle", "start": 0, "count": 4},
            {"name": "run", "start": 4, "count": 6},
            {"name": "attack", "start": 10, "count": 4},
            {"name": "hit", "start": 14, "count": 2},
            {"name": "die", "start": 16, "count": 4},
        ],
        "motif": spec.motif,
        "has_weapon": spec.has_weapon,
    }
    meta_path = out_dir / f"{spec.char_id}.frames.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
    return sheet_path, meta_path


_DEFAULT_MOTIF: Dict[str, str] = {
    "barami": "머리띠",
    "byeolee": "별",
    "dolsoe": "투구",
    "geurimja": "마스크",
    "hwalee": "불꽃",
    "ttukttaki": "잎",
}
_DEFAULT_WEAPON: Dict[str, bool] = {
    "dolsoe": True,
    "geurimja": True,
    "hwalee": True,
    "barami": False,
    "byeolee": False,
    "ttukttaki": False,
}


def default_spec_for(char_id: str) -> CharacterSpec:
    colors = character_colors(char_id)
    return CharacterSpec(
        char_id=char_id,
        main=colors["main"],
        sub=colors["sub"],
        point=colors["point"],
        motif=_DEFAULT_MOTIF.get(char_id, "none"),
        has_weapon=_DEFAULT_WEAPON.get(char_id, False),
    )


def build_all_characters(out_dir: Path) -> List[Path]:
    outputs: List[Path] = []
    palette = load_palette()
    for cid in palette["characters"].keys():
        spec = default_spec_for(cid)
        sp, mp = render_character_sheet(spec, out_dir)
        outputs.extend([sp, mp])
    return outputs
