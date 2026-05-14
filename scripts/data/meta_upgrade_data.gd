class_name MetaUpgradeData
extends Resource

# §3.7 — 8개 영구 강화의 비용/효과 표.
# key ∈ &"max_hp" | &"attack" | &"move_speed" | &"xp_gain" | &"gold_gain"
#     | &"revive" | &"choice_extra" | &"luck"

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
