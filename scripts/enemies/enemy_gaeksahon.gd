extends EnemyBase

# M26 객사혼 — 플레이어를 추적하지 않는다.
# 이동: 이속 30으로 랜덤 방향 부유(주기적으로 방향 재추첨, 화면 경계 회피).
# 플레이어가 30px 이내로 진입하면 자폭: 반경 60px 폭발, 데미지 = contact ×2(단발). 폭발 직후 본인 queue_free.

const DEFAULT_TRIGGER_DISTANCE_PX: float = 30.0
const DEFAULT_BURST_RADIUS_PX: float = 60.0
const DEFAULT_BURST_DAMAGE_MULT: float = 2.0
const DEFAULT_WANDER_SPEED_PX: float = 30.0
const DEFAULT_APPROACH_SPEED_PX: float = 120.0

const WANDER_REPATH_INTERVAL_S: float = 1.4
const BOUNDARY_MARGIN_PX: float = 24.0
const BURST_TELEGRAPH_S: float = 0.12

const FALLBACK_COLOR: Color = Color(0.55, 0.55, 0.65, 0.70)
const FALLBACK_W: float = 20.0
const FALLBACK_H: float = 28.0

enum State { WANDER, BURST }

var _trigger_distance: float = DEFAULT_TRIGGER_DISTANCE_PX
var _burst_radius: float = DEFAULT_BURST_RADIUS_PX
var _burst_damage_mult: float = DEFAULT_BURST_DAMAGE_MULT
var _wander_speed: float = DEFAULT_WANDER_SPEED_PX
var _approach_speed: float = DEFAULT_APPROACH_SPEED_PX
var _burst_damage_override: int = -1

var _state: int = State.WANDER
var _wander_dir: Vector2 = Vector2.RIGHT
var _wander_timer: float = 0.0
var _burst_timer: float = 0.0
var _burst_resolved: bool = false


func _ready() -> void:
	if data == null:
		max_hp = 14
		move_speed = 30.0
		contact_damage = 6
		exp_drop_value = 8
		coin_drop_value = 1
		coin_drop_chance = 0.20
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("trigger_distance_px"):
			_trigger_distance = float(params["trigger_distance_px"])
		if params.has("burst_radius_px"):
			_burst_radius = float(params["burst_radius_px"])
		if params.has("burst_damage_mult"):
			_burst_damage_mult = float(params["burst_damage_mult"])
		if params.has("approach_speed_px"):
			_approach_speed = float(params["approach_speed_px"])
		if params.has("burst_damage"):
			_burst_damage_override = int(params["burst_damage"])
	move_speed = _wander_speed
	hp = max_hp
	_pick_new_wander_direction()


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	if not is_instance_valid(target):
		target = _resolve_target()
	match _state:
		State.WANDER:
			_run_wander(delta)
		State.BURST:
			_run_burst(delta)
	queue_redraw()


func _run_wander(delta: float) -> void:
	_wander_timer = maxf(0.0, _wander_timer - delta)
	if _wander_timer <= 0.0:
		_pick_new_wander_direction()
	_avoid_screen_boundary()
	velocity = _wander_dir * _wander_speed
	move_and_slide()
	# 트리거 검사 — 플레이어가 _trigger_distance 이내에 있으면 자폭 시퀀스 진입.
	if is_instance_valid(target):
		var d: float = global_position.distance_to(target.global_position)
		if d <= _trigger_distance:
			_state = State.BURST
			_burst_timer = BURST_TELEGRAPH_S
			_burst_resolved = false


func _run_burst(delta: float) -> void:
	# 자폭 직전 살짝 플레이어 쪽으로 빨려들 듯 이동.
	if is_instance_valid(target):
		var dir: Vector2 = (target.global_position - global_position)
		if dir.length_squared() > 0.001:
			velocity = dir.normalized() * _approach_speed
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_burst_timer = maxf(0.0, _burst_timer - delta)
	if _burst_timer <= 0.0 and not _burst_resolved:
		_resolve_burst()


func _resolve_burst() -> void:
	_burst_resolved = true
	var dmg: int = _burst_damage_override if _burst_damage_override > 0 else int(round(float(contact_damage) * _burst_damage_mult))
	if is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= _burst_radius:
			if target.has_method("take_damage"):
				target.take_damage(dmg)
	# 폭발 직후 본인 사망.
	die()


func _pick_new_wander_direction() -> void:
	var angle: float = randf() * TAU
	_wander_dir = Vector2(cos(angle), sin(angle))
	_wander_timer = WANDER_REPATH_INTERVAL_S * (0.7 + randf() * 0.6)


func _avoid_screen_boundary() -> void:
	# 카메라 뷰포트 기준으로 화면 경계에 가까우면 안쪽으로 진로 반사.
	var viewport_rect: Rect2 = get_viewport_rect()
	var cam: Camera2D = get_viewport().get_camera_2d()
	var view_center: Vector2 = cam.global_position if cam != null else viewport_rect.position + viewport_rect.size * 0.5
	var half: Vector2 = viewport_rect.size * 0.5
	var rel: Vector2 = global_position - view_center
	if rel.x < -half.x + BOUNDARY_MARGIN_PX and _wander_dir.x < 0.0:
		_wander_dir.x = -_wander_dir.x
	elif rel.x > half.x - BOUNDARY_MARGIN_PX and _wander_dir.x > 0.0:
		_wander_dir.x = -_wander_dir.x
	if rel.y < -half.y + BOUNDARY_MARGIN_PX and _wander_dir.y < 0.0:
		_wander_dir.y = -_wander_dir.y
	elif rel.y > half.y - BOUNDARY_MARGIN_PX and _wander_dir.y > 0.0:
		_wander_dir.y = -_wander_dir.y


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	# 흐릿한 회색 영혼(타원형).
	draw_circle(Vector2(0.0, -2.0), FALLBACK_W * 0.45, c)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.35, -2.0), Vector2(FALLBACK_W * 0.7, FALLBACK_H * 0.45)), c)
	# 머리 숙임 — 어두운 점 두 개.
	draw_circle(Vector2(-FALLBACK_W * 0.15, -FALLBACK_H * 0.12), 1.2, Color(0.20, 0.20, 0.25, 0.85))
	draw_circle(Vector2(FALLBACK_W * 0.15, -FALLBACK_H * 0.12), 1.2, Color(0.20, 0.20, 0.25, 0.85))
	# 옅은 발광 외곽.
	draw_arc(Vector2.ZERO, FALLBACK_W * 0.55, 0.0, TAU, 28, Color(0.8, 0.85, 1.0, 0.30), 1.0)
	if _state == State.BURST:
		# 폭발 예고선.
		var t: float = 1.0 - clamp(_burst_timer / maxf(0.001, BURST_TELEGRAPH_S), 0.0, 1.0)
		draw_arc(Vector2.ZERO, _burst_radius * (0.4 + 0.6 * t), 0.0, TAU, 32, Color(1.0, 0.4, 0.3, 0.55), 1.4)
