extends EnemyBase

# M10 삼두구 — 평소 추적, 주기적으로 3방향 부채꼴 음파(0.4s 정지 예고 후 발사) + 1초 직선 돌진을 번갈아 수행.

const DEFAULT_HOWL_CONE_DEG: float = 30.0
const DEFAULT_HOWL_SIDE_ANGLE_DEG: float = 45.0
const DEFAULT_HOWL_RANGE_PX: float = 220.0
const DEFAULT_HOWL_PAUSE_S: float = 0.4
const DEFAULT_HOWL_STUN_S: float = 0.5
const DEFAULT_HOWL_COOLDOWN_S: float = 3.0
const DEFAULT_DASH_SPEED_MULT: float = 1.3
const DEFAULT_DASH_DURATION_S: float = 1.0
const DEFAULT_DASH_COOLDOWN_S: float = 3.0

const FALLBACK_COLOR: Color = Color(0.15, 0.10, 0.10, 1.0)
const FALLBACK_W: float = 22.0
const FALLBACK_H: float = 18.0

enum State { CHASE, HOWL_TELEGRAPH, DASH }

var _howl_cone_half_rad: float = deg_to_rad(DEFAULT_HOWL_CONE_DEG * 0.5)
var _howl_side_rad: float = deg_to_rad(DEFAULT_HOWL_SIDE_ANGLE_DEG)
var _howl_range: float = DEFAULT_HOWL_RANGE_PX
var _howl_pause_s: float = DEFAULT_HOWL_PAUSE_S
var _howl_stun_s: float = DEFAULT_HOWL_STUN_S
var _howl_cooldown_s: float = DEFAULT_HOWL_COOLDOWN_S
var _dash_speed_mult: float = DEFAULT_DASH_SPEED_MULT
var _dash_duration_s: float = DEFAULT_DASH_DURATION_S
var _dash_cooldown_s: float = DEFAULT_DASH_COOLDOWN_S
var _ranged_damage: int = 9

var _state: int = State.CHASE
var _state_timer: float = 0.0
var _special_cd_timer: float = 0.0
var _next_special_is_dash: bool = false
var _dash_dir: Vector2 = Vector2.RIGHT
var _facing_dir: Vector2 = Vector2.RIGHT


func _ready() -> void:
	if data == null:
		max_hp = 35
		move_speed = 75.0
		contact_damage = 8
		exp_drop_value = 8
		coin_drop_value = 1
		coin_drop_chance = 0.22
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("howl_cone_deg"):
			_howl_cone_half_rad = deg_to_rad(float(params["howl_cone_deg"]) * 0.5)
		if params.has("howl_side_angle_deg"):
			_howl_side_rad = deg_to_rad(float(params["howl_side_angle_deg"]))
		if params.has("howl_self_pause_s"):
			_howl_pause_s = float(params["howl_self_pause_s"])
		if params.has("howl_stun_duration_s"):
			_howl_stun_s = float(params["howl_stun_duration_s"])
		if params.has("howl_cooldown_s"):
			_howl_cooldown_s = float(params["howl_cooldown_s"])
		if params.has("dash_speed_mult"):
			_dash_speed_mult = float(params["dash_speed_mult"])
		if params.has("dash_duration_s"):
			_dash_duration_s = float(params["dash_duration_s"])
		if params.has("dash_cooldown_s"):
			_dash_cooldown_s = float(params["dash_cooldown_s"])
		if data.ranged_range_px > 0.0:
			_howl_range = data.ranged_range_px
		if data.ranged_damage > 0:
			_ranged_damage = data.ranged_damage
		if data.ranged_cooldown > 0.0:
			_howl_cooldown_s = data.ranged_cooldown
	_special_cd_timer = _howl_cooldown_s
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	match _state:
		State.CHASE:
			_run_chase(delta)
		State.HOWL_TELEGRAPH:
			_run_howl_telegraph(delta)
		State.DASH:
			_run_dash(delta)
	queue_redraw()


func _run_chase(delta: float) -> void:
	_special_cd_timer = maxf(0.0, _special_cd_timer - delta)
	super._physics_process(delta)
	if is_instance_valid(target):
		var to_t: Vector2 = target.global_position - global_position
		if to_t.length_squared() > 0.01:
			_facing_dir = to_t.normalized()
	if _special_cd_timer <= 0.0 and is_instance_valid(target):
		if _next_special_is_dash:
			_enter_dash()
		else:
			_enter_howl_telegraph()


func _enter_howl_telegraph() -> void:
	_state = State.HOWL_TELEGRAPH
	_state_timer = _howl_pause_s
	if is_instance_valid(target):
		var to_t: Vector2 = target.global_position - global_position
		if to_t.length_squared() > 0.01:
			_facing_dir = to_t.normalized()


func _run_howl_telegraph(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	# 짖기 직전 정지(이동 없음).
	velocity = Vector2.ZERO
	move_and_slide()
	if _state_timer <= 0.0:
		_unleash_howl()
		_state = State.CHASE
		_special_cd_timer = _howl_cooldown_s
		_next_special_is_dash = true


func _unleash_howl() -> void:
	if not is_instance_valid(target):
		return
	var to_t: Vector2 = target.global_position - global_position
	var d: float = to_t.length()
	if d > _howl_range:
		return
	if d < 0.001:
		return
	var to_dir: Vector2 = to_t / d
	var cone_centers: Array[Vector2] = [
		_facing_dir,
		_facing_dir.rotated(_howl_side_rad),
		_facing_dir.rotated(-_howl_side_rad),
	]
	for center in cone_centers:
		if center.dot(to_dir) >= cos(_howl_cone_half_rad):
			if target.has_method("take_damage"):
				target.take_damage(_ranged_damage)
			if target.has_method("apply_stun"):
				target.apply_stun(_howl_stun_s)
			elif target.has_method("apply_slow"):
				target.apply_slow(0.05, _howl_stun_s)
			return


func _enter_dash() -> void:
	if not is_instance_valid(target):
		return
	_state = State.DASH
	_state_timer = _dash_duration_s
	var to_t: Vector2 = target.global_position - global_position
	if to_t.length_squared() > 0.01:
		_dash_dir = to_t.normalized()
		_facing_dir = _dash_dir


func _run_dash(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	_contact_timer = maxf(0.0, _contact_timer - delta)
	velocity = _dash_dir * move_speed * _dash_speed_mult * _slow_factor
	move_and_slide()
	if _contact_timer <= 0.0 and _contact_area:
		for body in _contact_area.get_overlapping_bodies():
			if body == target:
				_deal_contact_damage()
				break
	if _state_timer <= 0.0:
		_state = State.CHASE
		_special_cd_timer = _dash_cooldown_s
		_next_special_is_dash = false


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 세 머리 표시(전/좌/우 작은 원).
	var head_r: float = 3.0
	var fwd: Vector2 = _facing_dir * (FALLBACK_W * 0.5)
	var left_dir: Vector2 = _facing_dir.rotated(_howl_side_rad) * (FALLBACK_W * 0.45)
	var right_dir: Vector2 = _facing_dir.rotated(-_howl_side_rad) * (FALLBACK_W * 0.45)
	draw_circle(fwd, head_r, Color(0.9, 0.2, 0.2, 1.0))
	draw_circle(left_dir, head_r, Color(0.9, 0.2, 0.2, 1.0))
	draw_circle(right_dir, head_r, Color(0.9, 0.2, 0.2, 1.0))
	if _state == State.HOWL_TELEGRAPH:
		var warn: Color = Color(1.0, 0.55, 0.2, 0.5)
		var centers: Array[Vector2] = [
			_facing_dir,
			_facing_dir.rotated(_howl_side_rad),
			_facing_dir.rotated(-_howl_side_rad),
		]
		for cc in centers:
			var base_a: float = cc.angle()
			draw_arc(Vector2.ZERO, _howl_range, base_a - _howl_cone_half_rad, base_a + _howl_cone_half_rad, 24, warn, 2.0)
	elif _state == State.DASH:
		draw_line(Vector2.ZERO, _dash_dir * (FALLBACK_W * 0.7), Color(1.0, 0.6, 0.3, 0.8), 2.0)
