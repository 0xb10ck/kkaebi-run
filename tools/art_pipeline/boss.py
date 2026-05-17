"""Boss / mini-boss renderer.

64x64 per frame, animations: idle(4) + attack(4) + die(4) = 12 frames -> 768x64 sheet.
Extends character renderer at 2x scale, with extra detail slots.
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Tuple

from PIL import Image

from . import primitives as P
from .character import CharacterSpec, _attack, _die, _draw_base, _idle
from .palette import RGB, hex_to_rgb, outline_color


@dataclass
class BossSpec:
    boss_id: str
    main: RGB
    sub: RGB
    point: RGB
    motif: str = "투구"
    detail_slot: Optional[str] = "crown"
    has_weapon: bool = True


def _to_char(spec: BossSpec) -> CharacterSpec:
    return CharacterSpec(
        char_id=spec.boss_id,
        main=spec.main,
        sub=spec.sub,
        point=spec.point,
        motif=spec.motif,
        has_weapon=spec.has_weapon,
        detail_slot=spec.detail_slot,
        scale=2,
    )


def render_boss_sheet(spec: BossSpec, out_dir: Path) -> Tuple[Path, Path]:
    cspec = _to_char(spec)
    idle = _idle(cspec)
    attack = _attack(cspec)
    die = _die(cspec)
    frames: List[Image.Image] = idle + attack + die  # 4+4+4
    # scale to 64x64
    frames = [P.scale_nearest(f, 2) for f in frames]

    sheet = P.compose_horizontal(frames)
    out_dir.mkdir(parents=True, exist_ok=True)
    sheet_path = out_dir / f"{spec.boss_id}.png"
    sheet.save(sheet_path)

    meta = {
        "boss_id": spec.boss_id,
        "frame_size": [64, 64],
        "sheet_size": list(sheet.size),
        "total_frames": 12,
        "anims": [
            {"name": "idle", "start": 0, "count": 4},
            {"name": "attack", "start": 4, "count": 4},
            {"name": "die", "start": 8, "count": 4},
        ],
        "motif": spec.motif,
        "detail_slot": spec.detail_slot,
    }
    meta_path = out_dir / f"{spec.boss_id}.frames.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
    return sheet_path, meta_path


# Seed boss catalog (b01~b06 + mb01~mb05). HEX values are placeholders aligned to chapter mood.
DEFAULT_BOSSES: List[Tuple[str, str, str, str, str, Optional[str]]] = [
    # (id, main, sub, point, motif, detail_slot)
    ("b01_dosa",       "#2D2D2D", "#1A1A1A", "#F0C75E", "투구",   "crown"),
    ("b02_eosa",       "#3F8FCC", "#7BC8F6", "#F4E8D0", "투구",   "shoulder_spike"),
    ("b03_yeomdaewang","#A33B22", "#E85D3A", "#F0C75E", "투구",   "crown"),
    ("b04_seonin",     "#5BAD8A", "#327A5C", "#F0C75E", "잎",     "crown"),
    ("b05_chunghonbul","#E85D3A", "#A33B22", "#F0C75E", "불꽃",   None),
    ("b06_sinmok_will","#664D26", "#5BAD8A", "#D4A574", "잎",     "shoulder_spike"),
    ("mb01_balsin",    "#5A3A1C", "#8B5A2B", "#C9A06A", "투구",   None),
    ("mb02_baekho",    "#7BC8F6", "#5BAD8A", "#FFFFFF", "별",     None),
    ("mb03_yeongma",   "#9C7BD0", "#6B4FA0", "#F0C75E", "마스크", None),
    ("mb04_geumikgu",  "#F0C75E", "#D4A574", "#FFFFFF", "투구",   "shoulder_spike"),
    ("mb05_haetae",    "#D4A574", "#8B5A2B", "#F0C75E", "별",     None),
]


def build_all_bosses(out_dir: Path) -> List[Path]:
    outs: List[Path] = []
    for bid, main, sub, point, motif, slot in DEFAULT_BOSSES:
        spec = BossSpec(
            boss_id=bid,
            main=hex_to_rgb(main),
            sub=hex_to_rgb(sub),
            point=hex_to_rgb(point),
            motif=motif,
            detail_slot=slot,
        )
        a, b = render_boss_sheet(spec, out_dir)
        outs.extend([a, b])
    return outs
