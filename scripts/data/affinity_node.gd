class_name AffinityNode
extends Resource

# §3.5 — 캐릭터 친밀도 트리의 단일 노드.

@export var id: StringName
@export var affinity_required: int = 3
@export var prerequisites: Array[StringName] = []
@export var branch: StringName = &"trunk"  # &"trunk" | &"left" | &"right"
@export var display_name_ko: String
@export_multiline var description_ko: String = ""
@export var effect_kind: StringName = &"stat_mult"  # &"stat_mult" | &"skill_unlock" | &"new_passive"
@export var effect_params: Dictionary = {}
