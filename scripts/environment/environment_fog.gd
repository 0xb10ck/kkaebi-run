extends Area2D

# meta-systems-spec §5.2 짙은 안개 — 영역 내 시야 50% 감소, 원거리 사거리 -25%,
# 몬스터 탐지 -30%. 화 LV3↑ 스킬로 30초간 걷어낼 수 있음.

const ENV_ID: StringName = &"env_fog"
const RANGE_REDUCTION: float = 0.25
const DETECT_REDUCTION: float = 0.30
const VISION_REDUCTION: float = 0.50
const CLEAR_DURATION: float = 30.0

@export var size: Vector2 = Vector2(256, 256)   # 8x8 타일 (32px 가정)

var _cleared_until_unix: float = 0.0
var _player_inside: bool = false


func _ready() -> void:
	add_to_group("environment")
	add_to_group("env_fog")
	collision_layer = 32
	collision_mask = 1 | 4
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if _is_cleared():
		return
	if body.is_in_group("player"):
		_player_inside = true
		EventBus.environment_entered.emit(ENV_ID, global_position)
		EventBus.toast_requested.emit("짙은 안개에 둘러싸였습니다.", 2.0)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		EventBus.environment_exited.emit(ENV_ID, global_position)


# 화 LV3↑ 스킬에서 호출 — 일시적으로 안개 효과 차단.
func clear_for(duration: float = CLEAR_DURATION) -> void:
	_cleared_until_unix = Time.get_unix_time_from_system() + duration
	if _player_inside:
		EventBus.environment_exited.emit(ENV_ID, global_position)


func _is_cleared() -> bool:
	return Time.get_unix_time_from_system() < _cleared_until_unix


# 외부에서 시야/탐지 보정값 조회.
func get_vision_multiplier() -> float:
	return 1.0 - VISION_REDUCTION if (_player_inside and not _is_cleared()) else 1.0


func get_range_multiplier() -> float:
	return 1.0 - RANGE_REDUCTION if (_player_inside and not _is_cleared()) else 1.0


func get_detect_multiplier() -> float:
	return 1.0 - DETECT_REDUCTION if not _is_cleared() else 1.0


func contains_point(world_pos: Vector2) -> bool:
	if _is_cleared():
		return false
	var half: Vector2 = size * 0.5
	var local: Vector2 = world_pos - global_position
	return absf(local.x) <= half.x and absf(local.y) <= half.y
