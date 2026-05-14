extends EnemyBase

# M04 어둑시니 — 플레이어 시야(전방 cone) 안에 들어가면 매 초 데미지/크기가 점진 성장.
# 시야 밖일 땐 속도 보너스를 받아 빠르게 접근.

const DEFAULT_VISION_DEG: float = 120.0
const DEFAULT_GROWTH_PER_SEC: float = 1.1
const DEFAULT_MAX_GROWTH_MULT: float = 2.0
const DEFAULT_SPEED_OUTSIDE_MULT: float = 1.5
const FALLBACK_COLOR: Color = Color(0.05, 0.05, 0.08, 1.0)
const FALLBACK_BASE_RADIUS: float = 9.6

var _vision_cos: float = cos(deg_to_rad(60.0))
var _growth_per_sec: float = DEFAULT_GROWTH_PER_SEC
var _max_growth_mult: float = DEFAULT_MAX_GROWTH_MULT
var _speed_outside_mult: float = DEFAULT_SPEED_OUTSIDE_MULT

var _current_growth_mult: float = 1.0
var _base_max_hp: int = 14
var _base_contact_damage: int = 4
var _base_move_speed: float = 45.0
var _base_draw_radius: float = FALLBACK_BASE_RADIUS


func _ready() -> void:
	if data == null:
		max_hp = 14
		move_speed = 45.0
		contact_damage = 4
		exp_drop_value = 3
		coin_drop_value = 1
		coin_drop_chance = 0.10
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("vision_cone_deg"):
			var half_deg: float = float(params["vision_cone_deg"]) * 0.5
			_vision_cos = cos(deg_to_rad(half_deg))
		if params.has("growth_per_sec"):
			_growth_per_sec = float(params["growth_per_sec"])
		if params.has("max_growth_mult"):
			_max_growth_mult = float(params["max_growth_mult"])
		if params.has("speed_outside_vision_mult"):
			_speed_outside_mult = float(params["speed_outside_vision_mult"])
	_base_max_hp = max_hp
	_base_contact_damage = contact_damage
	_base_move_speed = move_speed
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	if is_instance_valid(target):
		var in_vision: bool = _is_in_player_vision()
		if in_vision:
			# 매 초 ×1.1 → multiplier = pow(growth_per_sec, delta)
			_current_growth_mult = minf(_max_growth_mult, _current_growth_mult * pow(_growth_per_sec, delta))
			_apply_growth_factor()
			# 평상 속도로 추적.
			move_speed = _base_move_speed * _current_growth_mult
		else:
			# 시야 밖에서는 일시적으로 가속.
			move_speed = _base_move_speed * _current_growth_mult * _speed_outside_mult
	super._physics_process(delta)


func _apply_growth_factor() -> void:
	contact_damage = int(round(float(_base_contact_damage) * _current_growth_mult))
	# max_hp는 즉시 변하지 않게 둔다 (살아남으면 강해지는 느낌은 데미지·속도만으로 충분).
	queue_redraw()


func _is_in_player_vision() -> bool:
	if not is_instance_valid(target):
		return false
	# 플레이어 시야 cone — 플레이어의 facing direction을 알 수 없으면 마지막 이동 방향을 폴백.
	var facing: Vector2 = Vector2.RIGHT
	if "facing" in target and target.facing is Vector2:
		facing = target.facing
	elif "facing_direction" in target and target.facing_direction is Vector2:
		facing = target.facing_direction
	elif "velocity" in target and target.velocity is Vector2 and target.velocity.length_squared() > 0.01:
		facing = (target.velocity as Vector2).normalized()
	if facing.length_squared() < 0.0001:
		facing = Vector2.RIGHT
	else:
		facing = facing.normalized()
	var to_self: Vector2 = (global_position - target.global_position)
	if to_self.length_squared() < 0.0001:
		return true
	to_self = to_self.normalized()
	return to_self.dot(facing) >= _vision_cos


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	draw_circle(Vector2.ZERO, _base_draw_radius * _current_growth_mult, c)
