class_name EnemyData
extends Resource

# §3.2 — 53종 적 데이터. 코드 인플레이션 차단을 위해 모든 수치는 본 리소스로 외화.

# === 정체 ===
@export var id: StringName
@export var display_name_ko: String
@export_multiline var lore_ko: String = ""
@export var sprite_size_px: Vector2i = Vector2i(16, 16)
@export var sprite_texture: Texture2D
@export var placeholder_color: Color = Color.WHITE

# === 기본 스탯 (챕터 1 기준) ===
@export var base_hp: int = 10
@export var base_move_speed: float = 50.0
@export var base_contact_damage: int = 3
@export var attack_cooldown: float = 1.0
@export var detection_radius: float = 800.0
@export var hitbox_radius: float = 8.0

# === 원거리 공격 ===
@export var ranged_kind: GameEnums.RangedKind = GameEnums.RangedKind.NONE
@export var ranged_damage: int = 0
@export var ranged_range_px: float = 0.0
@export var ranged_projectile_speed: float = 0.0
@export var ranged_cooldown: float = 2.0
@export var ranged_telegraph: float = 0.0

# === 특수 능력 (다중 가능) ===
@export var special_abilities: Array[GameEnums.SpecialAbility] = []
@export var special_params: Dictionary = {}

# === 군집/AI ===
@export var group_ai: GameEnums.GroupAIKind = GameEnums.GroupAIKind.NONE
@export var group_size: int = 1
@export var group_spacing_px: float = 30.0
@export var ai_aggression: float = 1.0
@export_range(0.0, 1.0, 0.05) var flock_cohesion: float = 0.0

# === 보상 ===
@export var exp_value: int = 1
@export var gold_drop_chance: float = 0.0
@export var gold_drop_amount: int = 0
@export var orb_value: int = 0

# === 출현 ===
@export var chapters: Array[int] = [1]
@export var spawn_weight: int = 100
@export var min_stage_time_s: float = 0.0
@export var max_concurrent: int = 999


# === AC 명세 별칭 표면 (AC3) ===
# 외부 시스템/테스트가 참조하는 식별자명에 맞추기 위한 얇은 별칭.
# 값은 기존 필드를 그대로 가리킨다.

var ranged_attack: int:
	get:
		return ranged_damage
	set(value):
		ranged_damage = value

var special_ability: GameEnums.SpecialAbility:
	get:
		if special_abilities.is_empty():
			return GameEnums.SpecialAbility.NONE
		return special_abilities[0]
	set(value):
		if special_abilities.is_empty():
			special_abilities = [value]
		else:
			special_abilities[0] = value

var swarm_ai: GameEnums.GroupAIKind:
	get:
		return group_ai
	set(value):
		group_ai = value

# 풀스펙 명세 별칭: has_ranged_attack / ranged_range / projectile_speed / flock_*
# 외부에서 사용하는 별명을 기존 @export 필드에 그대로 매핑한다.

var has_ranged_attack: bool:
	get:
		return ranged_kind != GameEnums.RangedKind.NONE
	set(value):
		if value:
			if ranged_kind == GameEnums.RangedKind.NONE:
				ranged_kind = GameEnums.RangedKind.STRAIGHT
		else:
			ranged_kind = GameEnums.RangedKind.NONE

var ranged_range: float:
	get:
		return ranged_range_px
	set(value):
		ranged_range_px = value

var projectile_speed: float:
	get:
		return ranged_projectile_speed
	set(value):
		ranged_projectile_speed = value

var flock_size: int:
	get:
		return group_size
	set(value):
		group_size = value

var flock_spacing: float:
	get:
		return group_spacing_px
	set(value):
		group_spacing_px = value
