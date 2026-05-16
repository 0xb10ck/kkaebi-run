extends EnemyBase

# M11 호랑이 망령 — 매복형. 시야 밖에서 출현 → 1.5초 직선 돌격 → 1.5초 정지(취약).
# 정지 중 피격 시 주변 80px 둔화 포효 발동. 전체 사이클 쿨다운 6초.

const DEFAULT_AMBUSH_DISTANCE_PX: float = 200.0
const DEFAULT_CHARGE_SPEED_PX: float = 175.0
const DEFAULT_CHARGE_DURATION_S: float = 1.5
const DEFAULT_POST_CHARGE_STUN_S: float = 1.5
const DEFAULT_CHARGE_COOLDOWN_S: float = 6.0
const DEFAULT_HIT_ROAR_RADIUS_PX: float = 80.0
const DEFAULT_HIT_ROAR_SLOW_DURATION_S: float = 0.5
const DEFAULT_HIT_ROAR_SLOW_MULT: float = 0.7
const VIEW_MARGIN_PX: float = 32.0

const FALLBACK_COLOR: Color = Color(0.5, 0.7, 0.95, 0.8)
const FALLBACK_W: float = 22.0
const FALLBACK_H: float = 14.0

enum State { REPOSITION, CHARGE, VULNERABLE, COOLDOWN }

var _ambush_distance: float = DEFAULT_AMBUSH_DISTANCE_PX
var _charge_speed: float = DEFAULT_CHARGE_SPEED_PX
var _charge_duration: float = DEFAULT_CHARGE_DURATION_S
var _post_charge_stun: float = DEFAULT_POST_CHARGE_STUN_S
var _charge_cooldown: float = DEFAULT_CHARGE_COOLDOWN_S
var _roar_radius: float = DEFAULT_HIT_ROAR_RADIUS_PX
var _roar_slow_duration: float = DEFAULT_HIT_ROAR_SLOW_DURATION_S
var _roar_slow_mult: float = DEFAULT_HIT_ROAR_SLOW_MULT

var _state: int = State.REPOSITION
var _state_timer: float = 0.0
var _cycle_timer: float = 0.0
var _charge_dir: Vector2 = Vector2.RIGHT
var _roar_triggered: bool = false


func _ready() -> void:
	if data == null:
		max_hp = 40
		move_speed = 70.0
		contact_damage = 12
		exp_drop_value = 10
		coin_drop_value = 1
		coin_drop_chance = 0.30
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("ambush_spawn_distance_px"):
			_ambush_distance = float(params["ambush_spawn_distance_px"])
		if params.has("charge_speed_px"):
			_charge_speed = float(params["charge_speed_px"])
		if params.has("charge_duration_s"):
			_charge_duration = float(params["charge_duration_s"])
		if params.has("post_charge_stun_s"):
			_post_charge_stun = float(params["post_charge_stun_s"])
		if params.has("charge_cooldown_s"):
			_charge_cooldown = float(params["charge_cooldown_s"])
		if params.has("hit_roar_radius_px"):
			_roar_radius = float(params["hit_roar_radius_px"])
		if params.has("hit_roar_slow_duration_s"):
			_roar_slow_duration = float(params["hit_roar_slow_duration_s"])
		if params.has("hit_roar_slow_mult"):
			_roar_slow_mult = float(params["hit_roar_slow_mult"])
	hp = max_hp
	_enter_reposition()


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_cycle_timer = maxf(0.0, _cycle_timer - delta)
	match _state:
		State.REPOSITION:
			_run_reposition(delta)
		State.CHARGE:
			_run_charge(delta)
		State.VULNERABLE:
			_run_vulnerable(delta)
		State.COOLDOWN:
			_run_cooldown(delta)
	queue_redraw()


func _enter_reposition() -> void:
	_state = State.REPOSITION
	_state_timer = 0.0


func _run_reposition(_delta: float) -> void:
	# 시야 밖(카메라 기준)에서 플레이어로부터 일정 거리 떨어진 지점으로 즉시 이동.
	if not is_instance_valid(target):
		target = _resolve_target()
		if not is_instance_valid(target):
			return
	var angle: float = randf() * TAU
	var spawn_pos: Vector2 = target.global_position + Vector2(cos(angle), sin(angle)) * _ambush_distance
	spawn_pos = _push_outside_camera_view(spawn_pos)
	global_position = spawn_pos
	_charge_dir = (target.global_position - global_position).normalized()
	_state = State.CHARGE
	_state_timer = _charge_duration


func _push_outside_camera_view(p: Vector2) -> Vector2:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return p
	var view_size: Vector2 = get_viewport_rect().size
	var cam_pos: Vector2 = cam.global_position
	var half_w: float = view_size.x * 0.5 + VIEW_MARGIN_PX
	var half_h: float = view_size.y * 0.5 + VIEW_MARGIN_PX
	var dx: float = p.x - cam_pos.x
	var dy: float = p.y - cam_pos.y
	if absf(dx) < half_w and absf(dy) < half_h:
		# 카메라 view 안 — 가장 가까운 가장자리로 밀어낸다.
		if absf(dx) >= absf(dy):
			p.x = cam_pos.x + (half_w if dx >= 0.0 else -half_w)
		else:
			p.y = cam_pos.y + (half_h if dy >= 0.0 else -half_h)
	return p


func _run_charge(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	_contact_timer = maxf(0.0, _contact_timer - delta)
	velocity = _charge_dir * _charge_speed * _slow_factor
	move_and_slide()
	if _contact_timer <= 0.0 and _contact_area:
		for body in _contact_area.get_overlapping_bodies():
			if body == target:
				_deal_contact_damage()
				break
	if _state_timer <= 0.0:
		_state = State.VULNERABLE
		_state_timer = _post_charge_stun
		_roar_triggered = false
		velocity = Vector2.ZERO


func _run_vulnerable(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	velocity = Vector2.ZERO
	move_and_slide()
	if _state_timer <= 0.0:
		_state = State.COOLDOWN
		# 전체 사이클 6초 — 돌격(1.5) + 취약(1.5) = 3초 소요 → 남은 3초 쿨다운.
		_cycle_timer = maxf(0.0, _charge_cooldown - _charge_duration - _post_charge_stun)


func _run_cooldown(delta: float) -> void:
	# 쿨다운 중 — 일반 추적 동작.
	super._physics_process(delta)
	if _cycle_timer <= 0.0:
		_enter_reposition()


func take_damage(amount: int, attacker: Object = null) -> void:
	var was_vulnerable: bool = _state == State.VULNERABLE
	super.take_damage(amount, attacker)
	if was_vulnerable and not is_dying and not _roar_triggered:
		_roar_triggered = true
		_emit_hit_roar()


func _emit_hit_roar() -> void:
	if is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= _roar_radius:
			if target.has_method("apply_slow"):
				target.apply_slow(_roar_slow_mult, _roar_slow_duration)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self:
			continue
		if not (e is EnemyBase):
			continue
		var eb: EnemyBase = e
		if eb.is_dying:
			continue
		if (eb as Node2D).global_position.distance_to(global_position) <= _roar_radius:
			eb.apply_slow(_roar_slow_mult, _roar_slow_duration)


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	if _state == State.VULNERABLE:
		c = c.lerp(Color(1.0, 1.0, 1.0, 0.9), 0.3)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 줄무늬.
	var stripe: Color = Color(1.0, 1.0, 1.0, 0.5)
	for i in 3:
		var x: float = -FALLBACK_W * 0.4 + float(i) * (FALLBACK_W * 0.4)
		draw_line(Vector2(x, -FALLBACK_H * 0.5), Vector2(x, FALLBACK_H * 0.5), stripe, 1.0)
	if _state == State.CHARGE:
		draw_line(Vector2.ZERO, _charge_dir * (FALLBACK_W * 0.8), Color(0.7, 0.9, 1.0, 0.9), 2.0)
	elif _state == State.VULNERABLE:
		draw_arc(Vector2.ZERO, _roar_radius, 0.0, TAU, 32, Color(1.0, 0.9, 0.4, 0.25), 1.5)
