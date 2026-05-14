class_name ShinmokStageData
extends Resource

# §6.2 — 신목 6단계. 단계별 다음 단계로 가는 비용 + 도달 시 해금/보상.

@export var stage: int = 1
@export var display_name_ko: String
@export var orb_cost_to_advance: int = 0
@export var leaf_cost_to_advance: int = 0
@export var unlocks: Array[StringName] = []
@export var visual_texture: Texture2D
@export var grants_orbs_on_reach: int = 0
@export var grants_shards_on_reach: int = 0
