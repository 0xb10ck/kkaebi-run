extends EnemyBase

# M19 까마귀떼 — 군집 단일 HP. 플레이어 머리 위로 비행 집결 → 4s마다 수직 강하(32x64 단발) → 산개 → 재집결.
# 강하 명중 시 플레이어에게 1초 시야 흐림(또는 슬로우 폴백).

const DEFAULT_DIVE_INTERVAL_S: float = 4.0
const DEFAULT_DIVE_HITBOX_W: float = 32.0
const DEFAULT_DIVE_HITBOX_H: float = 64.0
const DEFAULT_BLUR_DURATION_S: float = 1.0
const DEFAULT_REGATHER_S: float = 1.0
const DEFAULT_OVERHEAD_OFFSET_PX: float = 90.0
const DEFAULT_DIVE_SPEED_PX: float = 360.0
const DEFAULT_SCATTER_DURATION_S: float = 0.6
const DEFAULT_SCATTER_SPEED_PX: float = 180.0
const DEFAULT_BLUR_SLOW_MULT: float = 0.6
const DEFAULT_UNIT_COUNT: int = 6

const FALLBACK_COLOR: Color = Color(0.10, 0.10, 0.12, 1.0)
const FALLBACK_UNIT_W: float = 8.0
const FALLBACK_UNIT_H: float = 6.0
const GATHER_ARRIVAL_PX: float = 20.0

enum State { GATHER, DIVE, SCATTER }

var _dive_interval: float = DEFAULT_DIVE_INTERVAL_S
var _dive_w: float = DEFAULT_DIVE_HITBOX_W
var _dive_h: float = DEFAULT_DIVE_HITBOX_H
var _blur_duration: float = DEFAULT_BLUR_DURATION_S
var _regather_s: float = DEFAULT_REGATHER_S
var _overhead_offset: float = DEFAULT_OVERHEAD_OFFSET_PX
var _dive_speed: float = DEFAULT_DIVE_SPEED_PX
var _scatter_duration: float = DEFAULT_SCATTER_DURATION_S
var _scatter_speed: float = DEFAULT_SCATTER_SPEED_PX
var _unit_count: int = DEFAULT_UNIT_COUNT

var _state: int = State.GATHER
var _state_timer: float = 0.0
var _dive_cd_timer: float = 0.0
var _dive_target_y: float = 0.0
var _dive_hit_resolved: bool = false
var _scatter_dirs: Array[Vector2] = []
var _gather_offsets: Array[Vector2] = []


func _ready() -> void:
	if data == null:
		max_hp = 18
		move_speed = 90.0
		contact_damage = 5
		exp_drop_value = 6
		coin_drop_value = 1
		coin_drop_chance = 0.18
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("dive_interval_s"):
			_dive_interval = float(params["dive_interval_s"])
		if params.has("dive_hitbox_w"):
			_dive_w = float(params["dive_hitbox_w"])
		if params.has("dive_hitbox_h"):
			_dive_h = float(params["dive_hitbox_h"])
		if params.has("dive_blur_duration_s"):
			_blur_duration = float(params["dive_blur_duration_s"])
		if params.has("regather_after_dive_s"):
			_regather_s = float(params["regather_after_dive_s"])
		if params.has("swarm_unit_count"):
			_unit_count = int(params["swarm_unit_count"])
	_dive_cd_timer = _dive_interval
	hp = max_hp
	_init_gather_offsets()


func _init_gather_offsets() -> void:
	_gather_offsets.clear()
	var count: int = maxi(1, _unit_count)
	for i in count:
		var angle: float = TAU * float(i) / float(count)
		_gather_offsets.append(Vector2(cos(angle), sin(angle)) * 10.0)


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
			velocity = Vector2.ZERO
			move_and_slide()
			return
	match _state:
		State.GATHER:
			_run_gather(delta)
		State.DIVE:
			_run_dive(delta)
		State.SCATTER:
			_run_scatter(delta)
	queue_redraw()


func _run_gather(delta: float) -> void:
	_dive_cd_timer = maxf(0.0, _dive_cd_timer - delta)
	var overhead: Vector2 = target.global_position + Vector2(0.0, -_overhead_offset)
	var to_overhead: Vector2 = overhead - global_position
	var dist: float = to_overhead.length()
	if dist > 4.0:
		velocity = to_overhead.normalized() * move_speed * _slow_factor
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if _dive_cd_timer <= 0.0 and dist < GATHER_ARRIVAL_PX:
		_enter_dive()


func _enter_dive() -> void:
	_state = State.DIVE
	_dive_target_y = target.global_position.y
	_dive_hit_resolved = false
	# 안전 한도: 강하 거리 + 약간의 여유 시간.
	var travel: float = maxf(0.0, _dive_target_y - global_position.y) + _dive_h
	_state_timer = travel / maxf(1.0, _dive_speed) + 0.3


func _run_dive(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	velocity = Vector2(0.0, _dive_speed * _slow_factor)
	move_and_slide()
	if not _dive_hit_resolved:
		_check_dive_hit()
	if _state_timer <= 0.0 or global_position.y >= _dive_target_y + _dive_h * 0.5:
		_enter_scatter()


func _check_dive_hit() -> void:
	if not is_instance_valid(target):
		return
	var half_w: float = _dive_w * 0.5
	var half_h: float = _dive_h * 0.5
	var dx: float = absf(target.global_position.x - global_position.x)
	var dy: float = absf(target.global_position.y - global_position.y)
	if dx <= half_w and dy <= half_h:
		if target.has_method("take_damage"):
			target.take_damage(contact_damage)
		_apply_vision_blur()
		_dive_hit_resolved = true


func _apply_vision_blur() -> void:
	if not is_instance_valid(target):
		return
	if target.has_method("apply_vision_blur"):
		target.apply_vision_blur(_blur_duration)
		return
	# 폴백: 플레이어 시야 흐림 컴포넌트 부재 시 약한 슬로우로 대체.
	if target.has_method("apply_slow"):
		target.apply_slow(DEFAULT_BLUR_SLOW_MULT, _blur_duration)


func _enter_scatter() -> void:
	_state = State.SCATTER
	_state_timer = _scatter_duration
	_scatter_dirs.clear()
	var count: int = maxi(1, _unit_count)
	for i in count:
		var angle: float = randf() * TAU
		_scatter_dirs.append(Vector2(cos(angle), sin(angle)))


func _run_scatter(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	# 위쪽으로 잠시 떠올라 산개 후 재집결.
	velocity = Vector2(0.0, -_scatter_speed * 0.4 * _slow_factor)
	move_and_slide()
	if _state_timer <= 0.0:
		_state = State.GATHER
		# 다음 강하까지 _dive_interval 대기(재집결 시간 포함).
		_dive_cd_timer = maxf(_regather_s, _dive_interval - _scatter_duration)


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	var beak: Color = Color(0.95, 0.85, 0.20, 1.0)
	match _state:
		State.GATHER:
			for off in _gather_offsets:
				draw_rect(Rect2(off - Vector2(FALLBACK_UNIT_W * 0.5, FALLBACK_UNIT_H * 0.5), Vector2(FALLBACK_UNIT_W, FALLBACK_UNIT_H)), c)
				draw_circle(off + Vector2(FALLBACK_UNIT_W * 0.5, 0.0), 1.0, beak)
		State.DIVE:
			var count: int = maxi(1, _unit_count)
			var half_count: int = count / 2
			for i in count:
				var off: Vector2 = Vector2(0.0, float(i - half_count) * (FALLBACK_UNIT_H + 1.0))
				draw_rect(Rect2(off - Vector2(FALLBACK_UNIT_W * 0.5, FALLBACK_UNIT_H * 0.5), Vector2(FALLBACK_UNIT_W, FALLBACK_UNIT_H)), c)
			# 강하 히트박스 가이드.
			draw_rect(Rect2(-Vector2(_dive_w * 0.5, _dive_h * 0.5), Vector2(_dive_w, _dive_h)), Color(0.95, 0.85, 0.20, 0.15), true)
		State.SCATTER:
			for i in _scatter_dirs.size():
				var dir: Vector2 = _scatter_dirs[i]
				var off2: Vector2 = dir * 14.0
				draw_rect(Rect2(off2 - Vector2(FALLBACK_UNIT_W * 0.5, FALLBACK_UNIT_H * 0.5), Vector2(FALLBACK_UNIT_W, FALLBACK_UNIT_H)), c)
