class_name SkillData
extends Resource

# §3.4 — 30종 스킬 데이터. 레벨별 수치는 SkillLevel 배열로 분리.

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


func level_at(level_index: int) -> SkillLevel:
	# Defensive accessor — clamps to available range so SkillBase can read LV1 even
	# before a tres has been populated with 5 entries.
	if levels.is_empty():
		return SkillLevel.new()
	var idx: int = clamp(level_index - 1, 0, levels.size() - 1)
	return levels[idx]
