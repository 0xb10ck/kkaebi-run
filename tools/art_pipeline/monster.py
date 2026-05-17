"""Normal monster renderer.

32x32 per frame, animations: idle(4) + attack(3) + die(3) = 10 frames -> 320x32 sheet.
Category-driven silhouette: ghost, dokkaebi, beast, plant, aerial.
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import List, Tuple

from PIL import Image

from . import primitives as P
from .palette import RGB, hex_to_rgb, outline_color

FRAME = 32
CX = 16


@dataclass
class MonsterSpec:
    monster_id: str
    main: RGB
    sub: RGB
    category: str  # 귀신/도깨비/짐승/식물/공중 (or English)


def _norm(cat: str) -> str:
    c = cat.lower()
    if "귀신" in cat or "ghost" in c:
        return "ghost"
    if "도깨비" in cat or "dokkaebi" in c:
        return "dokkaebi"
    if "짐승" in cat or "beast" in c:
        return "beast"
    if "식물" in cat or "plant" in c:
        return "plant"
    if "공중" in cat or "aerial" in c or "날개" in cat or "fly" in c:
        return "aerial"
    return "ghost"


def _draw_ghost(s: MonsterSpec, body_dy: int = 0) -> Image.Image:
    img = P.new_canvas(FRAME, FRAME)
    o = outline_color()
    P.fill_ellipse(img, CX, 14 + body_dy, 8, 7, s.main)
    # wisp tail
    P.fill_ellipse(img, CX - 4, 22 + body_dy, 2, 2, s.sub)
    P.fill_ellipse(img, CX, 24 + body_dy, 2, 2, s.sub)
    P.fill_ellipse(img, CX + 4, 22 + body_dy, 2, 2, s.sub)
    # eyes
    P.put(img, CX - 2, 13 + body_dy, o)
    P.put(img, CX + 2, 13 + body_dy, o)
    return P.add_outline(img, o)


def _draw_dokkaebi(s: MonsterSpec, body_dy: int = 0) -> Image.Image:
    img = P.new_canvas(FRAME, FRAME)
    o = outline_color()
    P.fill_ellipse(img, CX, 19 + body_dy, 9, 8, s.main)
    # horns
    P.put(img, CX - 6, 12 + body_dy, s.sub)
    P.put(img, CX - 5, 11 + body_dy, s.sub)
    P.put(img, CX + 5, 11 + body_dy, s.sub)
    P.put(img, CX + 6, 12 + body_dy, s.sub)
    # legs
    P.fill_rect(img, 12, 27, 14, 30, s.sub)
    P.fill_rect(img, 17, 27, 19, 30, s.sub)
    # eyes
    P.put(img, CX - 2, 18 + body_dy, o)
    P.put(img, CX + 2, 18 + body_dy, o)
    # fang
    P.put(img, CX, 21 + body_dy, (255, 255, 255))
    return P.add_outline(img, o)


def _draw_beast(s: MonsterSpec, body_dy: int = 0) -> Image.Image:
    img = P.new_canvas(FRAME, FRAME)
    o = outline_color()
    # body horizontal
    P.fill_ellipse(img, CX - 1, 19 + body_dy, 9, 5, s.main)
    # head
    P.fill_ellipse(img, CX + 7, 17 + body_dy, 4, 3, s.main)
    # ears
    P.put(img, CX + 7, 13 + body_dy, s.sub)
    P.put(img, CX + 9, 13 + body_dy, s.sub)
    # four legs
    P.fill_rect(img, 9, 24, 10, 30, s.sub)
    P.fill_rect(img, 13, 24, 14, 30, s.sub)
    P.fill_rect(img, 18, 24, 19, 30, s.sub)
    P.fill_rect(img, 22, 24, 23, 30, s.sub)
    # tail
    P.hline(img, 4, 7, 18 + body_dy, s.sub)
    P.put(img, 3, 17 + body_dy, s.sub)
    # eye
    P.put(img, CX + 8, 16 + body_dy, o)
    return P.add_outline(img, o)


def _draw_plant(s: MonsterSpec, body_dy: int = 0) -> Image.Image:
    img = P.new_canvas(FRAME, FRAME)
    o = outline_color()
    # trunk
    P.fill_rect(img, 13, 17 + body_dy, 18, 28, s.main)
    # leaves crown
    P.fill_ellipse(img, CX - 4, 14 + body_dy, 3, 2, s.sub)
    P.fill_ellipse(img, CX + 4, 14 + body_dy, 3, 2, s.sub)
    P.fill_ellipse(img, CX, 11 + body_dy, 3, 2, s.sub)
    # roots
    P.put(img, 11, 30, s.sub)
    P.put(img, 14, 31, s.sub)
    P.put(img, 17, 31, s.sub)
    P.put(img, 20, 30, s.sub)
    # eyes
    P.put(img, CX - 2, 22 + body_dy, o)
    P.put(img, CX + 1, 22 + body_dy, o)
    return P.add_outline(img, o)


def _draw_aerial(s: MonsterSpec, body_dy: int = 0, wing_phase: int = 0) -> Image.Image:
    img = P.new_canvas(FRAME, FRAME)
    o = outline_color()
    P.fill_ellipse(img, CX, 16 + body_dy, 4, 4, s.main)
    if wing_phase == 0:
        P.fill_ellipse(img, CX - 8, 13 + body_dy, 4, 2, s.sub)
        P.fill_ellipse(img, CX + 8, 13 + body_dy, 4, 2, s.sub)
    else:
        P.fill_ellipse(img, CX - 8, 17 + body_dy, 4, 2, s.sub)
        P.fill_ellipse(img, CX + 8, 17 + body_dy, 4, 2, s.sub)
    # eyes
    P.put(img, CX - 1, 15 + body_dy, o)
    P.put(img, CX + 1, 15 + body_dy, o)
    return P.add_outline(img, o)


def _draw(s: MonsterSpec, *, body_dy: int = 0, wing_phase: int = 0) -> Image.Image:
    cat = _norm(s.category)
    if cat == "ghost":
        return _draw_ghost(s, body_dy)
    if cat == "dokkaebi":
        return _draw_dokkaebi(s, body_dy)
    if cat == "beast":
        return _draw_beast(s, body_dy)
    if cat == "plant":
        return _draw_plant(s, body_dy)
    if cat == "aerial":
        return _draw_aerial(s, body_dy, wing_phase)
    return _draw_ghost(s, body_dy)


def render_monster_sheet(spec: MonsterSpec, out_dir: Path) -> Tuple[Path, Path]:
    is_aerial = _norm(spec.category) == "aerial"
    frames: List[Image.Image] = []
    # idle 4
    frames.append(_draw(spec, body_dy=0, wing_phase=0))
    frames.append(_draw(spec, body_dy=-1, wing_phase=1 if is_aerial else 0))
    frames.append(_draw(spec, body_dy=0, wing_phase=0))
    frames.append(_draw(spec, body_dy=1, wing_phase=1 if is_aerial else 0))
    # attack 3 (anticipation/strike/recover)
    base = _draw(spec, body_dy=0)
    frames.append(P.shift(base, -2, 0))
    frames.append(P.shift(P.red_flash(base, 0.4), 2, 0))
    frames.append(base)
    # die 3
    frames.append(P.shift(base, 1, 1))
    frames.append(P.shift(base, 3, 4))
    flat = P.new_canvas(FRAME, FRAME)
    flat.paste(base, (4, 9), base)
    frames.append(flat)

    sheet = P.compose_horizontal(frames)
    out_dir.mkdir(parents=True, exist_ok=True)
    sheet_path = out_dir / f"{spec.monster_id}.png"
    sheet.save(sheet_path)

    meta = {
        "monster_id": spec.monster_id,
        "category": spec.category,
        "frame_size": [FRAME, FRAME],
        "sheet_size": list(sheet.size),
        "total_frames": 10,
        "anims": [
            {"name": "idle", "start": 0, "count": 4},
            {"name": "attack", "start": 4, "count": 3},
            {"name": "die", "start": 7, "count": 3},
        ],
    }
    meta_path = out_dir / f"{spec.monster_id}.frames.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
    return sheet_path, meta_path


# Seed catalog covering 5 categories (subset of M01~M53). Extend as needed.
DEFAULT_MONSTERS: List[Tuple[str, str, str, str]] = [
    ("m01_dokkaebibul", "#5BCEFA", "#7BC8F6", "공중"),
    ("m02_dalgyalgwisin", "#FFFFFF", "#D4A574", "귀신"),
    ("m03_mulgwisin", "#2E8C8C", "#5BAD8A", "귀신"),
    ("m04_eodukshini", "#0D0D14", "#2D2D2D", "귀신"),
    ("m05_geuseundae", "#B3B3A6", "#D4A574", "귀신"),
    ("m06_bitjarugwisin", "#D9B873", "#8B5A2B", "도깨비"),
    ("m07_songakshi", "#F2F2EB", "#9C7BD0", "귀신"),
    ("m08_mongdalgwisin", "#8C738C", "#2D2D2D", "귀신"),
    ("m09_duduri", "#C77333", "#8B5A2B", "도깨비"),
    ("m10_samdugu", "#261A1A", "#E85D3A", "짐승"),
    ("m11_horangi", "#80B3F2", "#7BC8F6", "짐승"),
    ("m12_metdwaeji", "#33261A", "#8B5A2B", "짐승"),
    ("m13_neoguri", "#8C8073", "#D4A574", "짐승"),
    ("m14_dukkeobi", "#8C6633", "#5BAD8A", "짐승"),
    ("m15_geomi", "#733373", "#2D2D2D", "짐승"),
    ("m16_noru", "#A68C66", "#F4E8D0", "짐승"),
    ("m17_namu", "#664D26", "#5BAD8A", "식물"),
    ("m18_deonggul", "#265933", "#5BAD8A", "식물"),
    ("m19_kamagwi", "#1A1A1F", "#2D2D2D", "공중"),
]


def build_all_monsters(out_dir: Path) -> List[Path]:
    outs: List[Path] = []
    for mid, main, sub, cat in DEFAULT_MONSTERS:
        spec = MonsterSpec(monster_id=mid, main=hex_to_rgb(main), sub=hex_to_rgb(sub), category=cat)
        a, b = render_monster_sheet(spec, out_dir)
        outs.extend([a, b])
    return outs
