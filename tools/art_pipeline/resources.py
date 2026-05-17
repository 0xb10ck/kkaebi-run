"""Discover IDs and metadata from Godot .tres resources.

Parses lightweight key=value lines (no full Godot resource parser) sufficient for:
- characters/*.tres  (6)
- enemies/**/m*.tres (53 normal monsters; legacy/ is excluded)
- bosses/*.tres      (11 boss + miniboss)
- skills/*.tres      (30 skills)
- chapters/*.tres    (5 main chapters; ch_hidden_market excluded)
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from .palette import RGB, hex_to_rgb, project_root


# --- Element / rarity → palette key & shape ---------------------------------

_ELEMENT_TO_PALETTE = {
    0: "shadow",   # NONE → shadow tone
    1: "fire",
    2: "water",
    3: "wood",
    4: "metal",
    5: "earth",
    6: "shadow",
    7: "metal",
}

_RARITY_TO_SHAPE = {
    0: "projectile",
    1: "aoe",
    2: "aura",
}


def element_to_palette_key(element: int) -> str:
    return _ELEMENT_TO_PALETTE.get(int(element), "shadow")


def rarity_to_shape(rarity: int) -> str:
    return _RARITY_TO_SHAPE.get(int(rarity), "projectile")


# --- Monster category heuristic ---------------------------------------------

MONSTER_CATEGORY: Dict[str, str] = {
    "m01_dokkaebibul":            "공중",
    "m02_dalgyalgwisin":          "귀신",
    "m03_mulgwisin":              "귀신",
    "m04_eodukshini":             "귀신",
    "m05_geuseundae":             "귀신",
    "m06_bitjarugwisin":          "귀신",
    "m07_songakshi":              "귀신",
    "m08_mongdalgwisin":          "귀신",
    "m09_duduri":                 "도깨비",
    "m10_samdugu":                "짐승",
    "m11_horangi":                "짐승",
    "m12_metdwaeji":              "짐승",
    "m13_neoguri":                "짐승",
    "m14_dukkeobi":               "짐승",
    "m15_geomi":                  "짐승",
    "m16_noru":                   "짐승",
    "m17_namu":                   "식물",
    "m18_deonggul":               "식물",
    "m19_kamagwi":                "공중",
    "m20_cheonyeo_gwisin":        "귀신",
    "m21_jeoseung_gae":           "짐승",
    "m22_mangryang":              "귀신",
    "m23_gangshi":                "귀신",
    "m24_yagwang_gwi":            "귀신",
    "m25_baekgol_gwi":            "귀신",
    "m26_gaeksahon":              "귀신",
    "m27_saseul_gwi":             "귀신",
    "m28_dochaebi":               "도깨비",
    "m29_chasahon":               "귀신",
    "m30_bulgasari":              "짐승",
    "m31_yacha":                  "도깨비",
    "m32_nachal":                 "도깨비",
    "m33_cheonnyeo":              "공중",
    "m34_noegong":                "공중",
    "m35_pungbaek":               "공중",
    "m36_usa":                    "공중",
    "m37_hak":                    "공중",
    "m38_gareungbinga":           "공중",
    "m39_cheonma":                "짐승",
    "m40_heukpung":               "공중",
    "m41_bihyeongrang_grimja":    "귀신",
    "m42_heukmusa":               "귀신",
    "m43_yeonggwi":               "귀신",
    "m44_grimja_dokkaebi":        "도깨비",
    "m45_ohyeomdoen_shinmok_gaji": "식물",
    "m46_heukryong_saekki":       "공중",
    "m47_geomeun_angae_jamyeong": "귀신",
    "m48_sijang_dokkaebi":        "도깨비",
    "m49_geokkuro_dokkaebi":      "도깨비",
    "m50_noreumkkun":             "도깨비",
    "m51_sulchwihan":             "도깨비",
    "m52_byeonjang":              "도깨비",
    "m53_ssireum":                "짐승",
}


# --- Boss palette mapping (id → (main, sub, point, motif, detail)) ---------

# Real ids from resources/bosses/*.tres. Motifs/details chosen from lore.
BOSS_SPECS: Dict[str, Tuple[str, str, str, str, Optional[str]]] = {
    "b01_dokkaebibul_daejang":   ("#5BCEFA", "#3F8FCC", "#F0C75E", "불꽃",   "crown"),
    "b02_gumiho":                ("#E85D3A", "#A33B22", "#F0C75E", "별",     "shoulder_spike"),
    "b03_jeoseung_saja":         ("#2D2D2D", "#1A1A1A", "#FFFFFF", "투구",   "crown"),
    "b04_cheondung_janggun":     ("#7BC8F6", "#3F8FCC", "#F0C75E", "투구",   "shoulder_spike"),
    "b05_heuk_ryong":            ("#1A1A1A", "#2D2D2D", "#9C7BD0", "마스크", "crown"),
    "b06_daewang_dokkaebi":      ("#A33B22", "#664D26", "#F0C75E", "투구",   "shoulder_spike"),
    "mb01_jangsanbeom":          ("#F4E8D0", "#D4A574", "#1A1A1A", "별",     None),
    "mb02_imugi":                ("#327A5C", "#5BAD8A", "#F0C75E", "잎",     None),
    "mb03_chagwishin":           ("#5A3A1C", "#2D2D2D", "#F0C75E", "투구",   None),
    "mb04_geumdwaeji":           ("#F0C75E", "#D4A574", "#FFFFFF", "별",     "shoulder_spike"),
    "mb05_geomeun_dokkaebi":     ("#1A1A1A", "#2D2D2D", "#E85D3A", "마스크", None),
}


# --- Lightweight .tres scalar reader ----------------------------------------

_STRINGNAME_RE = re.compile(r'^\s*id\s*=\s*&"([^"]+)"\s*$', re.M)
_INT_RE = re.compile(r'^\s*(\w+)\s*=\s*(-?\d+)\s*$', re.M)
_COLOR_RE = re.compile(
    r'(\w+)\s*=\s*Color\(\s*([\d.\-]+)\s*,\s*([\d.\-]+)\s*,\s*([\d.\-]+)\s*,\s*([\d.\-]+)\s*\)'
)
_RESOURCE_BLOCK_RE = re.compile(r'^\[resource\]\s*$(.*?)\Z', re.M | re.S)


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _resource_block(text: str) -> str:
    m = _RESOURCE_BLOCK_RE.search(text)
    return m.group(1) if m else text


def _get_id(block: str) -> Optional[str]:
    m = _STRINGNAME_RE.search(block)
    return m.group(1) if m else None


def _get_int(block: str, key: str) -> Optional[int]:
    for m in _INT_RE.finditer(block):
        if m.group(1) == key:
            return int(m.group(2))
    return None


def _get_color(block: str, key: str) -> Optional[Tuple[float, float, float, float]]:
    for m in _COLOR_RE.finditer(block):
        if m.group(1) == key:
            return (float(m.group(2)), float(m.group(3)), float(m.group(4)), float(m.group(5)))
    return None


def _color_to_rgb(c: Tuple[float, float, float, float]) -> RGB:
    return (int(round(c[0] * 255)), int(round(c[1] * 255)), int(round(c[2] * 255)))


# --- Public discovery API ----------------------------------------------------

@dataclass(frozen=True)
class MonsterInfo:
    monster_id: str
    main: RGB
    sub: RGB
    category: str
    source: Path


@dataclass(frozen=True)
class BossInfo:
    boss_id: str
    main: RGB
    sub: RGB
    point: RGB
    motif: str
    detail_slot: Optional[str]
    source: Path


@dataclass(frozen=True)
class SkillInfo:
    skill_id: str
    element: int
    rarity: int
    palette_key: str
    shape: str
    source: Path


def project_resources_root() -> Path:
    return project_root() / "resources"


def discover_characters() -> List[str]:
    base = project_resources_root() / "characters"
    return sorted(p.stem for p in base.glob("*.tres"))


def discover_monsters() -> List[MonsterInfo]:
    base = project_resources_root() / "enemies"
    out: List[MonsterInfo] = []
    for p in sorted(base.rglob("m*.tres")):
        if "legacy" in p.parts:
            continue
        text = _read(p)
        block = _resource_block(text)
        mid = _get_id(block) or p.stem
        col = _get_color(block, "placeholder_color")
        if col:
            base_rgb = _color_to_rgb(col)
            r, g, b = base_rgb
            sub = (max(0, r - 40), max(0, g - 40), max(0, b - 40))
        else:
            base_rgb = (180, 180, 180)
            sub = (130, 130, 130)
        cat = MONSTER_CATEGORY.get(mid, "귀신")
        out.append(MonsterInfo(monster_id=mid, main=base_rgb, sub=sub, category=cat, source=p))
    return out


def discover_bosses() -> List[BossInfo]:
    base = project_resources_root() / "bosses"
    out: List[BossInfo] = []
    for p in sorted(base.glob("*.tres")):
        text = _read(p)
        block = _resource_block(text)
        bid = _get_id(block) or p.stem
        spec = BOSS_SPECS.get(bid)
        if spec is None:
            main_hex, sub_hex, point_hex, motif, detail = "#7BC8F6", "#3F8FCC", "#F0C75E", "투구", "crown"
        else:
            main_hex, sub_hex, point_hex, motif, detail = spec
        out.append(BossInfo(
            boss_id=bid,
            main=hex_to_rgb(main_hex),
            sub=hex_to_rgb(sub_hex),
            point=hex_to_rgb(point_hex),
            motif=motif,
            detail_slot=detail,
            source=p,
        ))
    return out


def discover_skills() -> List[SkillInfo]:
    base = project_resources_root() / "skills"
    out: List[SkillInfo] = []
    for p in sorted(base.glob("*.tres")):
        text = _read(p)
        block = _resource_block(text)
        sid = _get_id(block) or p.stem
        elem = _get_int(block, "element") or 0
        rar = _get_int(block, "rarity") or 0
        out.append(SkillInfo(
            skill_id=sid,
            element=elem,
            rarity=rar,
            palette_key=element_to_palette_key(elem),
            shape=rarity_to_shape(rar),
            source=p,
        ))
    return out


# The 5 main chapters (excludes hidden market by chapter_number).
_MAIN_CHAPTER_IDS = ("ch01_dumeong", "ch02_sinryeong", "ch03_hwangcheon", "ch04_cheonsang", "ch05_sinmok_heart")


def discover_chapters() -> List[str]:
    return list(_MAIN_CHAPTER_IDS)
