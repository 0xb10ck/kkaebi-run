extends EnemyBase

# M05 그슨대 — 250px 미만이면 세로로 신장 연장, 일정 길이 이상이면 머리 내려치기 즉시 히트박스.

const DEFAULT_TRIGGER_PX: float = 250.0
const DEFAULT_STEP_PX: float = 6.0
const DEFAULT_STEP_INTERVAL_S: float = 0.5
const DEFAULT_MAX_LENGTH_PX: float = 64.0
const DEFAULT_RANGED_ACTIVATE_LENGTH_PX: float = 48.0

const FALLBACK_COLOR: Color = Color(0.70, 0.70, 0.65, 1.0)
const FALLBACK_WIDTH: float = 16.0
const BASE_HEIGHT: float = 24.0

var _trigger_px: float = DEFAULT_TRIGGER_PX
var _step_px: float = DEFAULT_STEP_PX
var _step_interval: float = DEFAULT_STEP_INTERVAL_S
var _max_length: float = DEFAULT_MAX_LENGTH_PX
var _ranged_activate_length: float = DEFAULT_RANGED_ACTIVATE_LENGTH_PX

var _current_length: float = BASE_HEIGHT
var _step_timer: float = 0.0
var _attack_cd_timer: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 16
		move_speed = 55.0
		contact_damage = 4
		exp_drop_value = 3
		coin_drop_value = 1
		coin_drop_chance = 0.10
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("stretch_trigger_distance_px"):
			_trigger_px = float(params["stretch_trigger_distance_px"])
		if params.has("stretch_step_px"):
			_step_px = float(params["stretch_step_px"])
		if params.has("stretch_step_interval_s"):
			_step_interval = float(params["stretch_step_interval_s"])
		if params.has("max_length_px"):
			_max_length = float(params["max_length_px"])
		if params.has("ranged_activate_length_px"):
			_ranged_activate_length = float(params["ranged_activate_length_px"])
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_step_timer = maxf(0.0, _step_timer - delta)
	_attack_cd_timer = maxf(0.0, _attack_cd_timer - delta)
	if is_instance_valid(target):
		var dist: float = global_position.distance_to(target.global_position)
		if dist < _trigger_px:
			if _step_timer <= 0.0:
				_step_timer = _step_interval
				_current_length = minf(_max_length, _current_length + _step_px)
				queue_redraw()
				if _current_length >= _ranged_activate_length and _attack_cd_timer <= 0.0:
					_perform_head_strike()
		else:
			# 거리가 멀어지면 신장이 천천히 원상복구.
			if _current_length > BASE_HEIGHT:
				_current_length = maxf(BASE_HEIGHT, _current_length - _step_px * delta / maxf(0.01, _step_interval))
				queue_redraw()
	super._physics_process(delta)


func _perform_head_strike() -> void:
	if not is_instance_valid(target):
		return
	var cd: float = data.ranged_cooldown if data != null else 2.0
	_attack_cd_timer = cd
	var dmg: int = data.ranged_damage if data != null else 5
	var range_px: float = _current_length * 2.0
	# 즉시 히트박스 — 사거리 내에 있으면 곧바로 데미지.
	if global_position.distance_to(target.global_position) <= range_px:
		if target.has_method("take_damage"):
			target.take_damage(dmg)


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	var half_w: float = FALLBACK_WIDTH * 0.5
	# 머리는 위쪽으로 신장. (0,0) = 발 위치 기준.
	draw_rect(Rect2(Vector2(-half_w, -_current_length), Vector2(FALLBACK_WIDTH, _current_length)), c)
