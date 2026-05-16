extends EnemyBase

# M34 뇌공 — 플레이어와 약 250px 거리를 유지(가까우면 후퇴, 멀면 접근).
# 단발 낙뢰: ranged_cooldown(기본 2.0초)마다 플레이어 현재 발밑에 1초 예고 후 32x32 단발 데미지.
# 군집 낙뢰: 4초마다 자기 자신 중심 8방향 45° 간격 80px 거리 지점에 동시 1초 예고 후 동시 발동.

const DEFAULT_MAINTAIN_DISTANCE_PX: float = 250.0
const DEFAULT_LIGHTNING_HITBOX_PX: float = 32.0
const DEFAULT_LIGHTNING_TELEGRAPH_S: float = 1.0
const DEFAULT_LIGHTNING_DAMAGE: int = 14
const DEFAULT_LIGHTNING_COOLDOWN_S: float = 2.0
const DEFAULT_BURST_INTERVAL_S: float = 4.0
const DEFAULT_BURST_DIRECTIONS: int = 8
const DEFAULT_BURST_RADIUS_PX: float = 80.0

const DISTANCE_HYSTERESIS_PX: float = 18.0
const FALLBACK_COLOR: Color = Color(0.15, 0.30, 0.85, 1.0)
const FALLBACK_W: float = 20.0
const FALLBACK_H: float = 24.0

var _maintain_distance: float = DEFAULT_MAINTAIN_DISTANCE_PX
var _hitbox: float = DEFAULT_LIGHTNING_HITBOX_PX
var _telegraph: float = DEFAULT_LIGHTNING_TELEGRAPH_S
var _lightning_damage: int = DEFAULT_LIGHTNING_DAMAGE
var _single_cooldown: float = DEFAULT_LIGHTNING_COOLDOWN_S
var _burst_interval: float = DEFAULT_BURST_INTERVAL_S
var _burst_dirs: int = DEFAULT_BURST_DIRECTIONS
var _burst_radius: float = DEFAULT_BURST_RADIUS_PX

var _single_cd_timer: float = 0.0
var _burst_cd_timer: float = 0.0

# 보류 낙뢰 — 각 원소: { "pos": Vector2, "t": float, "dmg": int, "hit": float, "resolved": bool }
var _pending_strikes: Array = []


func _ready() -> void:
	if data == null:
		max_hp = 45
		move_speed = 55.0
		contact_damage = 6
		exp_drop_value = 17
		coin_drop_value = 1
		coin_drop_chance = 0.36
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("maintain_distance_px"):
			_maintain_distance = float(params["maintain_distance_px"])
		if params.has("lightning_hitbox_px"):
			_hitbox = float(params["lightning_hitbox_px"])
		if params.has("lightning_telegraph_s"):
			_telegraph = float(params["lightning_telegraph_s"])
		if params.has("lightning_damage"):
			_lightning_damage = int(params["lightning_damage"])
		if params.has("burst_interval_s"):
			_burst_interval = float(params["burst_interval_s"])
		if params.has("burst_directions"):
			_burst_dirs = int(params["burst_directions"])
		if params.has("burst_radius_px"):
			_burst_radius = float(params["burst_radius_px"])
		if data.ranged_damage > 0:
			_lightning_damage = data.ranged_damage
		if data.ranged_cooldown > 0.0:
			_single_cooldown = data.ranged_cooldown
		if data.ranged_telegraph > 0.0:
			_telegraph = data.ranged_telegraph
		if data.ranged_range_px > 0.0:
			_maintain_distance = data.ranged_range_px
	hp = max_hp
	_single_cd_timer = _single_cooldown
	_burst_cd_timer = _burst_interval


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
		_tick_strikes(delta)
		queue_redraw()
		return
	if not is_instance_valid(target):
		target = _resolve_target()
		if not is_instance_valid(target):
			velocity = Vector2.ZERO
			move_and_slide()
			return
	_run_kite()
	_single_cd_timer = maxf(0.0, _single_cd_timer - delta)
	_burst_cd_timer = maxf(0.0, _burst_cd_timer - delta)
	if _single_cd_timer <= 0.0:
		_cast_single_strike()
		_single_cd_timer = _single_cooldown
	if _burst_cd_timer <= 0.0:
		_cast_burst_strikes()
		_burst_cd_timer = _burst_interval
	_tick_strikes(delta)
	queue_redraw()


func _run_kite() -> void:
	var to_t: Vector2 = target.global_position - global_position
	var d: float = to_t.length()
	var dir: Vector2 = Vector2.ZERO
	if d > 0.001:
		dir = to_t / d
	var move_dir: Vector2 = Vector2.ZERO
	if d < _maintain_distance - DISTANCE_HYSTERESIS_PX:
		# 너무 가까움 — 후퇴.
		move_dir = -dir
	elif d > _maintain_distance + DISTANCE_HYSTERESIS_PX:
		# 너무 멀음 — 접근.
		move_dir = dir
	else:
		# 유지 — 옆으로 천천히 회전(스트레이프).
		move_dir = Vector2(-dir.y, dir.x)
	velocity = move_dir * move_speed * _slow_factor
	move_and_slide()


func _cast_single_strike() -> void:
	if not is_instance_valid(target):
		return
	_pending_strikes.append({
		"pos": target.global_position,
		"t": _telegraph,
		"dmg": _lightning_damage,
		"hit": _hitbox,
		"resolved": false,
	})


func _cast_burst_strikes() -> void:
	var count: int = maxi(1, _burst_dirs)
	for i in count:
		var angle: float = TAU * float(i) / float(count)
		var pos: Vector2 = global_position + Vector2(cos(angle), sin(angle)) * _burst_radius
		_pending_strikes.append({
			"pos": pos,
			"t": _telegraph,
			"dmg": _lightning_damage,
			"hit": _hitbox,
			"resolved": false,
		})


func _tick_strikes(delta: float) -> void:
	if _pending_strikes.is_empty():
		return
	var keep: Array = []
	for s in _pending_strikes:
		s["t"] = maxf(0.0, float(s["t"]) - delta)
		if s["t"] <= 0.0 and not bool(s["resolved"]):
			_resolve_strike(s)
			s["resolved"] = true
			# 발동 직후 짧게 표시했다가 사라지도록 0으로 유지 — 즉시 제거.
			continue
		keep.append(s)
	_pending_strikes = keep


func _resolve_strike(s: Dictionary) -> void:
	if not is_instance_valid(target):
		return
	var pos: Vector2 = s["pos"]
	var half: float = float(s["hit"]) * 0.5
	var dx: float = absf(target.global_position.x - pos.x)
	var dy: float = absf(target.global_position.y - pos.y)
	if dx <= half and dy <= half:
		if target.has_method("take_damage"):
			target.take_damage(int(s["dmg"]))


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 작은 망치(왼손).
	var hammer: Color = Color(0.70, 0.55, 0.25, 1.0)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5 - 4.0, -2.0), Vector2(4.0, 5.0)), hammer)
	# 작은 북(오른손).
	var drum: Color = Color(0.85, 0.40, 0.30, 1.0)
	draw_circle(Vector2(FALLBACK_W * 0.5 + 3.0, 0.0), 3.0, drum)
	# 등의 번개 깃발 표식.
	var flag: Color = Color(0.95, 0.95, 0.30, 1.0)
	draw_line(Vector2(0.0, -FALLBACK_H * 0.5), Vector2(0.0, -FALLBACK_H * 0.5 - 8.0), flag, 1.5)
	# 보류 낙뢰 예고/발동 표시.
	for s in _pending_strikes:
		var pos: Vector2 = s["pos"]
		var local: Vector2 = pos - global_position
		var half: float = float(s["hit"]) * 0.5
		if bool(s["resolved"]):
			# 발동 — 강한 흰빛.
			draw_rect(Rect2(local - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), Color(1.0, 1.0, 0.95, 0.85), true)
		else:
			# 예고 — 점멸하는 노란/자주색 마커.
			var t: float = float(s["t"])
			var ratio: float = 1.0 - clamp(t / maxf(0.001, _telegraph), 0.0, 1.0)
			var warn: Color = Color(0.95, 0.85, 0.20, 0.25 + 0.45 * ratio)
			draw_rect(Rect2(local - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), warn, false, 1.5)
			# 중심 십자.
			draw_line(local + Vector2(-half * 0.5, 0.0), local + Vector2(half * 0.5, 0.0), warn, 1.0)
			draw_line(local + Vector2(0.0, -half * 0.5), local + Vector2(0.0, half * 0.5), warn, 1.0)
