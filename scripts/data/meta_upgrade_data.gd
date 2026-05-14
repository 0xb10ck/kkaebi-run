class_name MetaUpgradeData
extends Resource

# §3.7 — 8개 영구 강화의 비용/효과 표.
# key ∈ &"max_hp" | &"attack" | &"move_speed" | &"xp_gain" | &"gold_gain"
#     | &"revive" | &"choice_extra" | &"luck"

# 풀스펙 명세 보조 enum. 기존 effect_kind(StringName)와 매핑된다.
enum EffectType {
	HP_MULT,
	ATK_MULT,
	MS_MULT,
	EXP_MULT,
	COIN_MULT,
	REVIVE_COUNT,
	CHOICE_COUNT,
	LUCK_MULT,
}

@export var key: StringName
@export var display_name_ko: String
@export_multiline var description_ko: String = ""
@export var icon_texture: Texture2D
@export var max_level: int = 5
@export var costs_orbs: Array[int] = [50, 100, 200, 400, 800]
@export var effects: Array[float] = [0.10, 0.20, 0.35, 0.55, 0.80]

# effect_kind: &"additive_percent" | &"additive_flat" | &"count"
@export var effect_kind: StringName = &"additive_percent"
@export var apply_target: StringName

# 신목 단계 게이트. 일부 강화는 신목 Lv.4/Lv.3에서 잠금.
@export var requires_shinmok_stage: int = 1


func cost_for(next_level: int) -> int:
	# next_level 1..max_level
	if costs_orbs.is_empty():
		return 0
	var idx: int = clamp(next_level - 1, 0, costs_orbs.size() - 1)
	return costs_orbs[idx]


func effect_at(level: int) -> float:
	if effects.is_empty() or level <= 0:
		return 0.0
	var idx: int = clamp(level - 1, 0, effects.size() - 1)
	return effects[idx]


# === AC 명세 별칭 표면 (AC3) ===

var cost_per_level: Array[int]:
	get:
		return costs_orbs
	set(value):
		costs_orbs = value

var effect_per_level: Array[float]:
	get:
		return effects
	set(value):
		effects = value

# 풀스펙 명세 별칭: id / description / effect_type
# key(StringName) ↔ EffectType 매핑은 apply_target 보다는 key 자체를 기준으로 한다.

var id: StringName:
	get:
		return key
	set(value):
		key = value

var description: String:
	get:
		return description_ko
	set(value):
		description_ko = value

var effect_type: int:
	get:
		match String(key):
			"max_hp":
				return EffectType.HP_MULT
			"attack":
				return EffectType.ATK_MULT
			"move_speed":
				return EffectType.MS_MULT
			"xp_gain":
				return EffectType.EXP_MULT
			"gold_gain":
				return EffectType.COIN_MULT
			"revive":
				return EffectType.REVIVE_COUNT
			"choice_extra":
				return EffectType.CHOICE_COUNT
			"luck":
				return EffectType.LUCK_MULT
			_:
				return EffectType.HP_MULT
	set(value):
		match value:
			EffectType.HP_MULT:
				key = &"max_hp"
			EffectType.ATK_MULT:
				key = &"attack"
			EffectType.MS_MULT:
				key = &"move_speed"
			EffectType.EXP_MULT:
				key = &"xp_gain"
			EffectType.COIN_MULT:
				key = &"gold_gain"
			EffectType.REVIVE_COUNT:
				key = &"revive"
			EffectType.CHOICE_COUNT:
				key = &"choice_extra"
			EffectType.LUCK_MULT:
				key = &"luck"
