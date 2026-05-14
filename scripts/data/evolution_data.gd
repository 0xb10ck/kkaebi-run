class_name EvolutionData
extends Resource

# §2.3 — 스킬 진화 조합. 모든 재료 LV5 + min_chapter 도달 시 진화 가능.

@export var id: StringName
@export var display_name_ko: String
@export var requires: Array[StringName] = []  # 재료 스킬 ID들 (전부 LV5 필요)
@export var result: SkillData
@export var min_chapter: int = 3
