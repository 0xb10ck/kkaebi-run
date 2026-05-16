extends EnemyBase

# M27 사슬귀 — 원거리 "사슬 던지기".
# 거리 ≈ 200px 이내이면 직선 방향으로 사슬 발사(시각적 라인 표시, 짧은 진행 트윈/raycast 기반 판정).
# 명중 시 플레이어를 자신 위치로 끌어옴 + 플레이어 0.5초 행동불가(스턴).
# 인양 직후 본인 1초 정지 → 근접 단발 공격. 전체 사이클 쿨다운 4초.

const DEFAULT_CHAIN_RANGE_PX: float = 200.0
const DEFAULT_CHAIN_PROJECTILE_SPEED_PX: float = 600.0
const DEFAULT_CHAIN_DAMAGE: int = 8
const DEFAULT_PULL_IMMOBILIZE_S: float = 0.5
const DEFAULT_POST_PULL_PAUSE_S: float = 1.0
const DEFAULT_POST_PULL_MELEE_DAMAGE: int = 10
const DEFAULT_CHAIN_COOLDOWN_S: float = 4.0
const DEFAULT_CHAIN_TELEGRAPH_S: float = 0.3

const CHAIN_HIT_RADIUS_PX: float = 16.0
const MELEE_RANGE_PX: float = 26.0
const CHASE_HOLD_DISTANCE_PX: float = 180.0

const FALLBACK_COLOR: Color = Color(0.40, 0.40, 0.45, 1.0)
const FALLBACK_W: float = 26.0
const FALLBACK_H: float = 34.0

enum State { CHASE, TELEGRAPH, THROW, PULL_RESOLVE, POST_PULL_PAUSE, MELEE, COOLDOWN }

var _chain_range: float = DEFAULT_CHAIN_RANGE_PX
var _chain_projectile_speed: float = DEFAULT_CHAIN_PROJECTILE_SPEED_PX
var _chain_damage: int = DEFAULT_CHAIN_DAMAGE
var _pull_immobilize: float = DEFAULT_PULL_IMMOBILIZE_S
var _post_pull_pause: float = DEFAULT_POST_PULL_PAUSE_S
var _post_pull_melee_damage: int = DEFAULT_POST_PULL_MELEE_DAMAGE
var _chain_cooldown: float = DEFAULT_CHAIN_COOLDOWN_S
var _chain_telegraph: float = DEFAULT_CHAIN_TELEGRAPH_S

var _state: int = State.CHASE
var _state_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _chain_origin: Vector2 = Vector2.ZERO
var _chain_dir: Vector2 = Vector2.RIGHT
var _chain_tip: Vector2 = Vector2.ZERO
var _chain_max_distance: float = 0.0
var _chain_traveled: float = 0.0
var _chain_hit_target: bool = false
var _melee_resolved: bool = false


func _ready() -> void:
	if data == null:
		max_hp = 40
		move_speed = 50.0
		contact_damage = 10
		exp_drop_value = 12
		coin_drop_value = 1
		coin_drop_chance = 0.28
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("chain_range_px"):
			_chain_range = float(params["chain_range_px"])
		if params.has("chain_projectile_speed_px"):
			_chain_projectile_speed = float(params["chain_projectile_speed_px"])
		if params.has("chain_damage"):
			_chain_damage = int(params["chain_damage"])
		if params.has("pull_immobilize_s"):
			_pull_immobilize = float(params["pull_immobilize_s"])
		if params.has("post_pull_pause_s"):
			_post_pull_pause = float(params["post_pull_pause_s"])
		if params.has("post_pull_melee_damage"):
			_post_pull_melee_damage = int(params["post_pull_melee_damage"])
		if params.has("chain_cooldown_s"):
			_chain_cooldown = float(params["chain_cooldown_s"])
		if data.ranged_telegraph > 0.0:
			_chain_telegraph = data.ranged_telegraph
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	if not is_instance_valid(target):
		target = _resolve_target()
		if not is_instance_valid(target):
			return
	_tick_status(delta)
	if _stun_remaining > 0.0:
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return
	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	match _state:
		State.CHASE:
			_run_chase(delta)
		State.TELEGRAPH:
			_run_telegraph(delta)
		State.THROW:
			_run_throw(delta)
		State.PULL_RESOLVE:
			_run_pull_resolve(delta)
		State.POST_PULL_PAUSE:
			_run_post_pull_pause(delta)
		State.MELEE:
			_run_melee(delta)
		State.COOLDOWN:
			_run_cooldown(delta)
	queue_redraw()


func _tick_status(delta: float) -> void:
	_contact_timer = maxf(0.0, _contact_timer - delta)
	if _slow_remaining > 0.0:
		_slow_remaining -= delta
		if _slow_remaining <= 0.0:
			_slow_remaining = 0.0
			_slow_factor = 1.0
	if _stun_remaining > 0.0:
		_stun_remaining = maxf(0.0, _stun_remaining - delta)


func _run_chase(_delta: float) -> void:
	var to_target: Vector2 = target.global_position - global_position
	var d: float = to_target.length()
	# 사거리 내이고 쿨다운이 끝났으면 사슬 던지기 시퀀스 진입.
	if d <= _chain_range and _cooldown_timer <= 0.0:
		_state = State.TELEGRAPH
		_state_timer = _chain_telegraph
		velocity = Vector2.ZERO
		move_and_slide()
		return
	# 사거리보다 멀면 접근, 너무 가까우면 살짝 거리 유지.
	var dir: Vector2
	if d > CHASE_HOLD_DISTANCE_PX:
		dir = to_target.normalized() if d > 0.001 else Vector2.ZERO
	elif d < CHASE_HOLD_DISTANCE_PX * 0.6:
		dir = (-to_target.normalized()) if d > 0.001 else Vector2.ZERO
	else:
		dir = Vector2.ZERO
	velocity = dir * move_speed * _slow_factor
	move_and_slide()


func _run_telegraph(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	_state_timer = maxf(0.0, _state_timer - delta)
	if _state_timer <= 0.0:
		_begin_throw()


func _begin_throw() -> void:
	_chain_origin = global_position
	var to_target: Vector2 = target.global_position - global_position
	if to_target.length_squared() < 0.001:
		_chain_dir = Vector2.RIGHT
	else:
		_chain_dir = to_target.normalized()
	_chain_max_distance = _chain_range
	_chain_traveled = 0.0
	_chain_tip = _chain_origin
	_chain_hit_target = false
	_state = State.THROW


func _run_throw(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	# 사슬 끝 진행 — projectile_speed × delta 만큼 전진, 사거리 도달 시 회수.
	_chain_traveled = minf(_chain_max_distance, _chain_traveled + _chain_projectile_speed * delta)
	_chain_tip = _chain_origin + _chain_dir * _chain_traveled
	# 진행 중 타겟과 충돌 검사.
	if is_instance_valid(target):
		if _chain_tip.distance_to(target.global_position) <= CHAIN_HIT_RADIUS_PX:
			_chain_hit_target = true
			_state = State.PULL_RESOLVE
			return
	if _chain_traveled >= _chain_max_distance:
		# 빗나감 — 쿨다운으로.
		_state = State.COOLDOWN
		_cooldown_timer = _chain_cooldown


func _run_pull_resolve(_delta: float) -> void:
	# 끌어옴 + 행동불가 + 약한 데미지.
	if is_instance_valid(target):
		target.global_position = global_position
		if target.has_method("take_damage"):
			target.take_damage(_chain_damage)
		if target.has_method("apply_stun"):
			target.apply_stun(_pull_immobilize)
	_state = State.POST_PULL_PAUSE
	_state_timer = _post_pull_pause
	_melee_resolved = false


func _run_post_pull_pause(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	_state_timer = maxf(0.0, _state_timer - delta)
	if _state_timer <= 0.0:
		_state = State.MELEE


func _run_melee(_delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	if _melee_resolved:
		_state = State.COOLDOWN
		_cooldown_timer = _chain_cooldown
		return
	_melee_resolved = true
	if is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= MELEE_RANGE_PX:
			if target.has_method("take_damage"):
				target.take_damage(_post_pull_melee_damage)
	_state = State.COOLDOWN
	_cooldown_timer = _chain_cooldown


func _run_cooldown(_delta: float) -> void:
	# 쿨다운 동안에는 일반 추적 거동 복귀.
	if _cooldown_timer <= 0.0:
		_state = State.CHASE
		return
	var to_target: Vector2 = target.global_position - global_position
	var d: float = to_target.length()
	var dir: Vector2 = to_target.normalized() if d > 0.001 else Vector2.ZERO
	velocity = dir * move_speed * 0.8 * _slow_factor
	move_and_slide()


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	# 회색 갑옷 몸체.
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 어두운 투구.
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H * 0.30)), Color(0.18, 0.18, 0.22, 1.0))
	# 두 눈(붉은 점).
	draw_circle(Vector2(-FALLBACK_W * 0.20, -FALLBACK_H * 0.32), 1.2, Color(0.95, 0.20, 0.20, 1.0))
	draw_circle(Vector2(FALLBACK_W * 0.20, -FALLBACK_H * 0.32), 1.2, Color(0.95, 0.20, 0.20, 1.0))
	# 사슬 — 텔레그래프 / 진행 / 인양 시 표시.
	if _state == State.TELEGRAPH:
		# 예고선.
		var to_target: Vector2 = (target.global_position - global_position) if is_instance_valid(target) else Vector2.RIGHT * _chain_range
		var aim: Vector2 = to_target.normalized() * minf(to_target.length(), _chain_range)
		draw_line(Vector2.ZERO, aim, Color(0.85, 0.85, 0.4, 0.6), 1.6)
	elif _state == State.THROW or _state == State.PULL_RESOLVE:
		var local_tip: Vector2 = _chain_tip - global_position
		draw_line(Vector2.ZERO, local_tip, Color(0.70, 0.70, 0.75, 0.95), 2.0)
		# 사슬 끝 갈고리.
		draw_circle(local_tip, 2.6, Color(0.55, 0.55, 0.60, 1.0))
	elif _state == State.POST_PULL_PAUSE or _state == State.MELEE:
		draw_arc(Vector2.ZERO, MELEE_RANGE_PX, 0.0, TAU, 24, Color(1.0, 0.5, 0.4, 0.50), 1.2)
