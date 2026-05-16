extends EnemyBase

# M33 천녀 잔영 — 부유 이동. 카메라 외곽 쪽으로 회피하는 경향.
# 3초마다 정면 90° 부채꼴 빛 공격(사거리 160px, 0.3s 예고).
# 명중 시 플레이어 1.5초 시야 흐림 디버프.

const DEFAULT_CONE_ANGLE_DEG: float = 90.0
const DEFAULT_CONE_RANGE_PX: float = 160.0
const DEFAULT_FLASH_TELEGRAPH_S: float = 0.3
const DEFAULT_FLASH_DAMAGE: int = 12
const DEFAULT_FLASH_COOLDOWN_S: float = 3.0
const DEFAULT_BLIND_DURATION_S: float = 1.5
const DEFAULT_FLOAT_OFFSET_PX: float = 12.0

const PREFERRED_DISTANCE_MIN_PX: float = 120.0
const PREFERRED_DISTANCE_MAX_PX: float = 180.0
const EDGE_BIAS_STRENGTH: float = 0.7
const BLUR_SLOW_FALLBACK_MULT: float = 0.6

const FALLBACK_COLOR: Color = Color(0.92, 0.88, 0.95, 0.9)
const FALLBACK_W: float = 18.0
const FALLBACK_H: float = 26.0

enum State { DRIFT, TELEGRAPH }

var _cone_half_rad: float = deg_to_rad(DEFAULT_CONE_ANGLE_DEG * 0.5)
var _cone_range: float = DEFAULT_CONE_RANGE_PX
var _flash_telegraph: float = DEFAULT_FLASH_TELEGRAPH_S
var _flash_damage: int = DEFAULT_FLASH_DAMAGE
var _flash_cooldown: float = DEFAULT_FLASH_COOLDOWN_S
var _blind_duration: float = DEFAULT_BLIND_DURATION_S
var _float_offset: float = DEFAULT_FLOAT_OFFSET_PX
var _prefers_edge: bool = true

var _state: int = State.DRIFT
var _state_timer: float = 0.0
var _cd_timer: float = 0.0
var _facing_dir: Vector2 = Vector2.RIGHT
var _float_phase: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 50
		move_speed = 60.0
		contact_damage = 9
		exp_drop_value = 16
		coin_drop_value = 1
		coin_drop_chance = 0.38
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("cone_angle_deg"):
			_cone_half_rad = deg_to_rad(float(params["cone_angle_deg"]) * 0.5)
		if params.has("cone_range_px"):
			_cone_range = float(params["cone_range_px"])
		if params.has("flash_telegraph_s"):
			_flash_telegraph = float(params["flash_telegraph_s"])
		if params.has("flash_damage"):
			_flash_damage = int(params["flash_damage"])
		if params.has("blind_duration_s"):
			_blind_duration = float(params["blind_duration_s"])
		if params.has("float_offset_px"):
			_float_offset = float(params["float_offset_px"])
		if params.has("prefers_screen_edge"):
			_prefers_edge = bool(params["prefers_screen_edge"])
		if data.ranged_range_px > 0.0:
			_cone_range = data.ranged_range_px
		if data.ranged_damage > 0:
			_flash_damage = data.ranged_damage
		if data.ranged_cooldown > 0.0:
			_flash_cooldown = data.ranged_cooldown
		if data.ranged_telegraph > 0.0:
			_flash_telegraph = data.ranged_telegraph
	hp = max_hp
	_cd_timer = _flash_cooldown
	_float_phase = randf() * TAU


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_contact_timer = maxf(0.0, _contact_timer - delta)
	if _slow_remaining > 0.0:
		_slow_remaining -= delta
		if _slow_remaining <= 0.0:
			_slow_remaining = 0.0
			_slow_factor = 1.0
	if _stun_remaining > 0.0:
		_stun_remaining = maxf(0.0, _stun_remaining - delta)
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if not is_instance_valid(target):
		target = _resolve_target()
		if not is_instance_valid(target):
			return
	_cd_timer = maxf(0.0, _cd_timer - delta)
	_float_phase = fmod(_float_phase + delta * 2.0, TAU)
	match _state:
		State.DRIFT:
			_run_drift(delta)
		State.TELEGRAPH:
			_run_telegraph(delta)
	queue_redraw()


func _run_drift(_delta: float) -> void:
	var to_t: Vector2 = target.global_position - global_position
	var d: float = to_t.length()
	if d > 0.001:
		_facing_dir = to_t / d
	var move_dir: Vector2 = Vector2.ZERO
	if d < PREFERRED_DISTANCE_MIN_PX:
		# 너무 가까움 — 후퇴.
		move_dir = -_facing_dir
	elif d > PREFERRED_DISTANCE_MAX_PX:
		# 너무 멀음 — 접근.
		move_dir = _facing_dir
	else:
		# 유지 — 옆으로 천천히.
		move_dir = Vector2(-_facing_dir.y, _facing_dir.x)
	if _prefers_edge:
		var edge_dir: Vector2 = _edge_bias_dir()
		if edge_dir.length_squared() > 0.001:
			move_dir = (move_dir * (1.0 - EDGE_BIAS_STRENGTH) + edge_dir * EDGE_BIAS_STRENGTH)
			if move_dir.length_squared() > 0.001:
				move_dir = move_dir.normalized()
	# 부유: 수직 미세 흔들림 더하기.
	var bob: Vector2 = Vector2(0.0, sin(_float_phase) * _float_offset * 0.05)
	velocity = move_dir * move_speed * _slow_factor + bob * 60.0
	move_and_slide()
	if _cd_timer <= 0.0 and is_in_cone(target.global_position):
		_enter_telegraph()


func _edge_bias_dir() -> Vector2:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return Vector2.ZERO
	var view_size: Vector2 = get_viewport_rect().size
	var cam_pos: Vector2 = cam.global_position
	var half_w: float = view_size.x * 0.5
	var half_h: float = view_size.y * 0.5
	var rel: Vector2 = global_position - cam_pos
	# 어느 가장자리가 가까운지 — 그 가장자리 쪽으로 향한다.
	var nx: float = rel.x / maxf(1.0, half_w)
	var ny: float = rel.y / maxf(1.0, half_h)
	if absf(nx) >= absf(ny):
		return Vector2(sign(nx) if nx != 0.0 else (1.0 if randf() < 0.5 else -1.0), 0.0)
	return Vector2(0.0, sign(ny) if ny != 0.0 else (1.0 if randf() < 0.5 else -1.0))


func is_in_cone(p: Vector2) -> bool:
	var v: Vector2 = p - global_position
	var d: float = v.length()
	if d < 0.001 or d > _cone_range:
		return false
	return (v / d).dot(_facing_dir) >= cos(_cone_half_rad)


func _enter_telegraph() -> void:
	_state = State.TELEGRAPH
	_state_timer = _flash_telegraph
	if is_instance_valid(target):
		var v: Vector2 = target.global_position - global_position
		if v.length_squared() > 0.001:
			_facing_dir = v.normalized()


func _run_telegraph(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	velocity = Vector2.ZERO
	move_and_slide()
	if _state_timer <= 0.0:
		_unleash_flash()
		_state = State.DRIFT
		_cd_timer = _flash_cooldown


func _unleash_flash() -> void:
	if not is_instance_valid(target):
		return
	if not is_in_cone(target.global_position):
		return
	if target.has_method("take_damage"):
		target.take_damage(_flash_damage)
	_apply_vision_blur()


func _apply_vision_blur() -> void:
	if not is_instance_valid(target):
		return
	if target.has_method("apply_vision_blur"):
		target.apply_vision_blur(_blind_duration)
		return
	# 폴백: 시야 흐림 컴포넌트 부재 시 약한 슬로우.
	if target.has_method("apply_slow"):
		target.apply_slow(BLUR_SLOW_FALLBACK_MULT, _blind_duration)


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	# 흰 천의 형태(가로로 살짝 넓은 사다리꼴 느낌의 사각형).
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 옷자락 끝 검게 변질.
	var hem: Color = Color(0.10, 0.08, 0.12, 0.9)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, FALLBACK_H * 0.35), Vector2(FALLBACK_W, FALLBACK_H * 0.15)), hem)
	# 정면 표시(작은 표식).
	draw_line(Vector2.ZERO, _facing_dir * (FALLBACK_W * 0.6), Color(1.0, 0.95, 1.0, 0.7), 1.0)
	if _state == State.TELEGRAPH:
		var warn: Color = Color(1.0, 0.95, 0.60, 0.30)
		var base_a: float = _facing_dir.angle()
		draw_arc(Vector2.ZERO, _cone_range, base_a - _cone_half_rad, base_a + _cone_half_rad, 32, warn, 2.0)
		# 부채꼴 양 옆 가이드 라인.
		var left: Vector2 = _facing_dir.rotated(-_cone_half_rad) * _cone_range
		var right: Vector2 = _facing_dir.rotated(_cone_half_rad) * _cone_range
		draw_line(Vector2.ZERO, left, warn, 1.0)
		draw_line(Vector2.ZERO, right, warn, 1.0)
