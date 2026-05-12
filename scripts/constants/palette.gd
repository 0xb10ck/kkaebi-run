class_name Palette
extends RefCounted

# === 오방색 메인 (kkaebi-run-asset-concept.md §1.1) ===
const RED_MAIN   := Color("#E03C3C")
const RED_LIGHT  := Color("#FF6B6B")
const RED_DARK   := Color("#8B1A1A")

const BLUE_MAIN  := Color("#3C7CE0")
const BLUE_LIGHT := Color("#6BA3FF")
const BLUE_DARK  := Color("#1A3F8B")

const YELLOW_MAIN  := Color("#E0C23C")
const YELLOW_LIGHT := Color("#FFE066")
const YELLOW_DARK  := Color("#8B7A1A")

const WHITE_MAIN  := Color("#F0EDE6")
const WHITE_PURE  := Color("#FFFFFF")
const WHITE_DARK  := Color("#C8C3B8")

const BLACK_MAIN  := Color("#2A2A35")
const BLACK_LIGHT := Color("#45455A")
const BLACK_DARK  := Color("#0F0F15")

# === 보조 ===
const WOOD_GREEN     := Color("#4CAF50")
const SHINMOK_GOLD   := Color("#FFD700")
const POISON_PURPLE  := Color("#9C27B0")
const SKIN_KKAEBI    := Color("#7CAADC")
const SKIN_KKAEBI_DK := Color("#5B8DB8")

# === UI 토큰 ===
const TEXT_BODY        := WHITE_MAIN
const TEXT_OUTLINE     := BLACK_MAIN
const HP_GAUGE         := RED_MAIN
const HP_OUTLINE       := BLACK_DARK
const EXP_GAUGE        := SHINMOK_GOLD
const EXP_TRACK        := BLACK_LIGHT
const GOLD_TEXT        := YELLOW_MAIN
const BTN_PRIMARY_BG   := RED_MAIN
const BTN_SECONDARY_BG := BLACK_LIGHT

# === 스킬 속성별 ===
const ELEMENT_FIRE  := RED_MAIN
const ELEMENT_WATER := BLUE_MAIN
const ELEMENT_WOOD  := WOOD_GREEN
const ELEMENT_METAL := WHITE_MAIN
const ELEMENT_EARTH := YELLOW_MAIN

static func gem_color(exp_value: int) -> Color:
	if exp_value >= 5:
		return RED_MAIN
	if exp_value >= 2:
		return WOOD_GREEN
	return BLUE_LIGHT
