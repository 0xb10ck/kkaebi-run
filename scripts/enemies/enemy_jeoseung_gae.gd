extends EnemyBase

# M21 저승개 — 끈질긴 추적(이속 90). 일직선이 아니라 플레이어 진행 방향에 수직으로 우회 접근.
# 상태머신: APPROACH → FLANK → STRIKE.
# 같은 그룹("jeoseung_gae")에 다른 개체가 있으면 협공 모드: 자신의 위치를 비교해 좌/우 측면 분담.

const DEFAULT_FLANK_ROTATION_DEG: float = 90.0
const DEFAULT_FLANK_APPROACH_OFFSET_PX: float = 60.0
const DEFAULT_FLANK_ENGAGE_DISTANCE_PX: float = 200.0
const STRIKE_RANGE_PX: float = 40.0
const APPROACH_TO_FLANK_PX: float = 240.0
const FLANK_HOLD_DURATION_S: float = 0.6

const GROUP_NAME: StringName = &"jeoseung_gae"

const FALLBACK_COLOR: Color = Color(0.05, 0.05, 0.08, 1.0)
const FALLBACK_W: float = 30.0
const FALLBACK_H: float = 18.0

enum State { APPROACH, FLANK, STRIKE }

var _flank_rotation_dir_deg: float = DEFAULT_FLANK_ROTATION_DEG
var _flank_offset: float = DEFAULT_FLANK_APPROACH_OFFSET_PX
var _flank_engage: float = DEFAULT_FLANK_ENGAGE_DISTANCE_PX

var _state: int = State.APPROACH
var _state_timer: float = 0.0
var _flank_side: int = 1  # +1 = 오른쪽(플레이어 진행방향 기준), -1 = 왼쪽
var _last_player_dir: Vector2 = Vector2.RIGHT


func _ready() -> void:
	if data == null:
		max_hp = 45
		move_speed = 90.0
		contact_damage = 10
		exp_drop_value = 11
		coin_drop_value = 1
		coin_drop_chance = 0.28
	super._ready()
	add_to_group(GROUP_NAME)
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("flank_rotation_dir_deg"):
			_flank_rotation_dir_deg = float(params["flank_rotation_dir_deg"])
		if params.has("flank_approach_offset_px"):
			_flank_offset = float(params["flank_approach_offset_px"])
		if params.has("flank_engage_distance_px"):
			_flank_engage = float(params["flank_engage_distance_px"])
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	if not is_instance_valid(target):
		target = _resolve_target()
		if not is_instance_valid(target):
			return
	_update_player_dir()
	_update_flank_side()
	match _state:
		State.APPROACH:
			_run_approach(delta)
		State.FLANK:
			_run_flank(delta)
		State.STRIKE:
			_run_strike(delta)
	queue_redraw()


func _update_player_dir() -> void:
	if target is CharacterBody2D:
		var v: Vector2 = (target as CharacterBody2D).velocity
		if v.length_squared() > 1.0:
			_last_player_dir = v.normalized()


func _update_flank_side() -> void:
	# 협공 분담: 같은 그룹의 다른 개체가 존재하면 자기 위치 기준으로 좌/우 자동 선택.
	# 자신의 위치 벡터(=플레이어→자신)를 플레이어 진행방향에 사영하여 좌(=-1)/우(=+1)를 결정.
	var perp: Vector2 = Vector2(-_last_player_dir.y, _last_player_dir.x)
	var rel: Vector2 = global_position - target.global_position
	var dot: float = rel.dot(perp)
	var allies: Array = get_tree().get_nodes_in_group(GROUP_NAME)
	var has_partner: bool = false
	for a in allies:
		if a == self:
			continue
		if a is EnemyBase and not (a as EnemyBase).is_dying:
			has_partner = true
			break
	if has_partner:
		# 두 개체가 좌/우 반대편에서 접근 — 자기 사영 부호 기준.
		_flank_side = 1 if dot >= 0.0 else -1
	else:
		# 단독이면 자기 위치 기준으로 자연스러운 측면 선택.
		_flank_side = 1 if dot >= 0.0 else -1


func _compute_flank_target() -> Vector2:
	# 플레이어 진행 방향에 수직(perp)으로 _flank_offset만큼 떨어진 옆구리 지점.
	var perp: Vector2 = Vector2(-_last_player_dir.y, _last_player_dir.x)
	var rot_rad: float = deg_to_rad(_flank_rotation_dir_deg)
	# rotation deg가 90이면 단순 perp, 다른 값이면 진행방향과 약간 회전한 측면.
	var lateral: Vector2 = _last_player_dir.rotated(rot_rad)
	if lateral.length_squared() < 0.001:
		lateral = perp
	return target.global_position + lateral.normalized() * _flank_offset * float(_flank_side)


func _run_approach(delta: float) -> void:
	# 일직선 추적이 아닌 측면 우회 — 일정 거리 이상에선 옆구리 지점으로 이동.
	var dist: float = global_position.distance_to(target.global_position)
	var goal: Vector2
	if dist > APPROACH_TO_FLANK_PX:
		# 멀면 옆구리 지점으로 빠르게 이동.
		goal = _compute_flank_target()
	else:
		goal = _compute_flank_target()
	var dir: Vector2 = (goal - global_position)
	if dir.length_squared() > 0.001:
		dir = dir.normalized()
	else:
		dir = (target.global_position - global_position).normalized()
	velocity = dir * move_speed * _slow_factor
	move_and_slide()
	_handle_stun_and_slow(delta)
	if dist <= _flank_engage:
		_state = State.FLANK
		_state_timer = FLANK_HOLD_DURATION_S


func _run_flank(delta: float) -> void:
	# 옆구리 위치를 잠시 유지하다가 측면에서 STRIKE로 들어간다.
	var goal: Vector2 = _compute_flank_target()
	var dir: Vector2 = (goal - global_position)
	if dir.length_squared() > 1.0:
		velocity = dir.normalized() * move_speed * _slow_factor
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_handle_stun_and_slow(delta)
	_state_timer = maxf(0.0, _state_timer - delta)
	# 측면 위치에 충분히 도달했거나 시간이 지나면 STRIKE.
	if _state_timer <= 0.0 or global_position.distance_to(goal) < 12.0:
		_state = State.STRIKE


func _run_strike(delta: float) -> void:
	# 측면에서 플레이어로 직선 돌격.
	_contact_timer = maxf(0.0, _contact_timer - delta)
	var dir: Vector2 = (target.global_position - global_position)
	var d: float = dir.length()
	if d > 0.001:
		dir = dir / d
	velocity = dir * move_speed * 1.15 * _slow_factor
	move_and_slide()
	_handle_stun_and_slow(delta)
	if _contact_timer <= 0.0 and _contact_area:
		for body in _contact_area.get_overlapping_bodies():
			if body == target:
				_deal_contact_damage()
				break
	# 너무 멀어지면 다시 APPROACH로.
	if d > _flank_engage * 1.5:
		_state = State.APPROACH


func _handle_stun_and_slow(delta: float) -> void:
	if _slow_remaining > 0.0:
		_slow_remaining -= delta
		if _slow_remaining <= 0.0:
			_slow_remaining = 0.0
			_slow_factor = 1.0
	if _stun_remaining > 0.0:
		_stun_remaining = maxf(0.0, _stun_remaining - delta)


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 입에서 흐르는 푸른 도깨비불.
	draw_circle(Vector2(FALLBACK_W * 0.45, FALLBACK_H * 0.05), 2.2, Color(0.4, 0.8, 1.0, 0.9))
	# 사슬(목 두꺼운 회색 띠).
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.35, -FALLBACK_H * 0.5 - 2.0), Vector2(FALLBACK_W * 0.4, 3.0)), Color(0.55, 0.55, 0.60, 0.9))
	# 눈(빨강).
	draw_circle(Vector2(FALLBACK_W * 0.25, -FALLBACK_H * 0.1), 1.2, Color(0.95, 0.15, 0.15, 1.0))
	if _state == State.FLANK or _state == State.STRIKE:
		# 측면 진입 표시.
		var perp: Vector2 = Vector2(-_last_player_dir.y, _last_player_dir.x) * float(_flank_side)
		draw_line(Vector2.ZERO, perp * (FALLBACK_W * 0.6), Color(0.6, 0.85, 1.0, 0.6), 1.5)
