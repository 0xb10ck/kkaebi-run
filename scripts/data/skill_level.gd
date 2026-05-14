class_name SkillLevel
extends Resource

# §3.4 — 스킬 단일 레벨 수치. SkillData.levels[0..4]에 정확히 5개.

@export var damage_formula: String = "8 + INT*0.2"
@export var damage_base: float = 8.0
@export var damage_int_coef: float = 0.2
@export var cooldown_s: float = 8.0
@export var range_px: float = 80.0
@export var radius_px: float = 0.0
@export var duration_s: float = 0.0
@export var tick_interval_s: float = 0.0
@export var projectile_count: int = 0
@export var projectile_speed: float = 0.0
@export var status_effect: StringName = &""
@export var status_potency: float = 0.0
@export var status_duration_s: float = 0.0
@export var stack_max: int = 1
@export var extras: Dictionary = {}
