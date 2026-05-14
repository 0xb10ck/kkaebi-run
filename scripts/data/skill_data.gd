class_name SkillData
extends Resource

# §3.4 — 30종 스킬 데이터. 레벨별 수치는 SkillLevel 배열로 분리.

# 풀스펙 명세 보조 enum. 기존 GameEnums.Rarity / GameEnums.TriggerMode 와 1:1 매핑.
enum Grade { COMMON, RARE, LEGENDARY }
enum ActivationMode { AUTO, ACTIVE, PASSIVE }

@export var id: StringName
@export var display_name_ko: String
@export_multiline var description_ko: String = ""
@export var element: GameEnums.Element = GameEnums.Element.NONE
@export var rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON
@export var trigger_mode: GameEnums.TriggerMode = GameEnums.TriggerMode.AUTO
@export var scene: PackedScene
@export var icon_color: Color = Color.WHITE
@export var icon_texture: Texture2D

# === 레벨링 ===
@export var max_level: int = 5
@export var levels: Array[SkillLevel] = []

# === 등장 조건 ===
@export var min_chapter_to_offer: int = 1
@export var character_weight_overrides: Dictionary = {}

# === 시너지 / 진화 ===
@export var synergy_partners: Array[StringName] = []
@export var counter_partners: Array[StringName] = []
@export var evolution_targets: Array[StringName] = []

# === 해금 ===
@export_multiline var unlock_condition: String = ""


func level_at(level_index: int) -> SkillLevel:
	# Defensive accessor — clamps to available range so SkillBase can read LV1 even
	# before a tres has been populated with 5 entries.
	if levels.is_empty():
		return SkillLevel.new()
	var idx: int = clamp(level_index - 1, 0, levels.size() - 1)
	return levels[idx]


# === AC 명세 별칭 표면 (AC3) ===

var level_values: Array[SkillLevel]:
	get:
		return levels
	set(value):
		levels = value

var trigger_type: GameEnums.TriggerMode:
	get:
		return trigger_mode
	set(value):
		trigger_mode = value

# 풀스펙 명세 별칭: grade / activation_mode / level_stats
# 기존 GameEnums.Rarity / TriggerMode / levels(SkillLevel) 에 매핑한다.

var grade: int:
	get:
		match rarity:
			GameEnums.Rarity.RARE:
				return Grade.RARE
			GameEnums.Rarity.LEGENDARY:
				return Grade.LEGENDARY
			_:
				return Grade.COMMON
	set(value):
		match value:
			Grade.RARE:
				rarity = GameEnums.Rarity.RARE
			Grade.LEGENDARY:
				rarity = GameEnums.Rarity.LEGENDARY
			_:
				rarity = GameEnums.Rarity.COMMON

var activation_mode: int:
	get:
		match trigger_mode:
			GameEnums.TriggerMode.ACTIVE:
				return ActivationMode.ACTIVE
			GameEnums.TriggerMode.PASSIVE, GameEnums.TriggerMode.REACTIVE:
				return ActivationMode.PASSIVE
			_:
				return ActivationMode.AUTO
	set(value):
		match value:
			ActivationMode.ACTIVE:
				trigger_mode = GameEnums.TriggerMode.ACTIVE
			ActivationMode.PASSIVE:
				trigger_mode = GameEnums.TriggerMode.PASSIVE
			_:
				trigger_mode = GameEnums.TriggerMode.AUTO

var level_stats: Array[Dictionary]:
	get:
		var result: Array[Dictionary] = []
		for lv in levels:
			if lv == null:
				result.append({})
				continue
			result.append({
				"damage": lv.damage_base,
				"cooldown": lv.cooldown_s,
				"range": lv.range_px,
				"radius": lv.radius_px,
				"duration": lv.duration_s,
				"projectiles": lv.projectile_count,
			})
		return result
