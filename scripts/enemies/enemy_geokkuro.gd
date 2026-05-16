extends EnemyBase

# M49 거꾸로 도깨비 — 평소 비활성(이동/공격/시야 비활성). 플레이어가
# activation_radius_px(100) 이내 진입 시 활성화 — mirror_input_duration_s(3.0s) 동안
# 플레이어 좌/우 입력 반전 디버프를 부여하고 본인은 도주(반대 방향).
# 활성화 후 mirror_input_cooldown_s(8.0s) 쿨다운(쿨다운 동안 다시 진입해도 트리거 안 됨).

const DEFAULT_ACTIVATION_RADIUS_PX: float = 100.0
const DEFAULT_MIRROR_DURATION_S: float = 3.0
const DEFAULT_MIRROR_COOLDOWN_S: float = 8.0
const DEFAULT_INACTIVE_ALPHA: float = 0.35

const FALLBACK_COLOR: Color = Color(0.55, 0.30, 0.55, 1.0)
const FALLBACK_W: float = 16.0
const FALLBACK_H: float = 22.0
const HAND_COLOR: Color = Color(0.95, 0.85, 0.75, 1.0)

enum State { INACTIVE, ACTIVE_FLEE }

var _activation_radius: float = DEFAULT_ACTIVATION_RADIUS_PX
var _mirror_duration: float = DEFAULT_MIRROR_DURATION_S
var _mirror_cooldown: float = DEFAULT_MIRROR_COOLDOWN_S
var _flee_during_debuff: bool = true
var _deactivate_after_debuff: bool = true

var _state: int = State.INACTIVE
var _state_timer: float = 0.0
var _cd_timer: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 30
		move_speed = 70.0
		contact_damage = 5
		exp_drop_value = 12
		coin_drop_value = 1
		coin_drop_chance = 0.50
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("activation_radius_px"):
			_activation_radius = float(params["activation_radius_px"])
		if params.has("mirror_input_duration_s"):
			_mirror_duration = float(params["mirror_input_duration_s"])
		if params.has("mirror_input_cooldown_s"):
			_mirror_cooldown = float(params["mirror_input_cooldown_s"])
		if params.has("flee_during_debuff"):
			_flee_during_debuff = bool(params["flee_during_debuff"])
		if params.has("deactivate_after_debuff"):
			_deactivate_after_debuff = bool(params["deactivate_after_debuff"])
		if data.attack_cooldown > 0.0:
			_mirror_cooldown = data.attack_cooldown
	hp = max_hp
	modulate.a = DEFAULT_INACTIVE_ALPHA


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
		queue_redraw()
		return
	if not is_instance_valid(target):
		target = _resolve_target()
		if not is_instance_valid(target):
			velocity = Vector2.ZERO
			move_and_slide()
			queue_redraw()
			return
	_cd_timer = maxf(0.0, _cd_timer - delta)
	match _state:
		State.INACTIVE:
			_run_inactive()
		State.ACTIVE_FLEE:
			_run_active_flee(delta)
	queue_redraw()


func _run_inactive() -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	# 쿨다운 동안에는 트리거 안 됨.
	if _cd_timer > 0.0:
		return
	var d: float = global_position.distance_to(target.global_position)
	if d <= _activation_radius:
		_activate()


func _activate() -> void:
	_state = State.ACTIVE_FLEE
	_state_timer = _mirror_duration
	modulate.a = 1.0
	_apply_mirror_input(_mirror_duration)


func _run_active_flee(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	if _flee_during_debuff and is_instance_valid(target):
		var away: Vector2 = global_position - target.global_position
		if away.length_squared() <= 0.0001:
			away = Vector2.RIGHT
		else:
			away = away.normalized()
		velocity = away * move_speed * _slow_factor
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if _state_timer <= 0.0:
		if _deactivate_after_debuff:
			_state = State.INACTIVE
			modulate.a = DEFAULT_INACTIVE_ALPHA
		_cd_timer = _mirror_cooldown


func _apply_mirror_input(duration: float) -> void:
	if not is_instance_valid(target):
		return
	# 플레이어가 좌우 반전 API를 갖고 있으면 그것을 우선 호출.
	if target.has_method("apply_mirror_input"):
		target.apply_mirror_input(duration)
		return
	if target.has_method("apply_control_invert"):
		target.apply_control_invert(&"horizontal", duration)
		return
	if target.has_method("apply_debuff"):
		target.apply_debuff(&"mirror_input_horizontal", 1.0, duration)
		return
	# 폴백: 글로벌 control_invert 플래그가 있으면 셋. 시간 경과 후 해제 — SceneTreeTimer로 예약.
	if "control_invert_horizontal" in target:
		target.set("control_invert_horizontal", true)
		var t: SceneTreeTimer = get_tree().create_timer(duration)
		t.timeout.connect(_on_mirror_input_expired.bind(target))


func _on_mirror_input_expired(player_ref: Node) -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	if "control_invert_horizontal" in player_ref:
		player_ref.set("control_invert_horizontal", false)


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	# 본체 — 거꾸로 선 자세(머리 아래).
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 머리(아래쪽).
	draw_circle(Vector2(0.0, FALLBACK_H * 0.5 - 1.0), 4.0, c)
	# 두 손바닥(위쪽 — 손바닥으로 걷는 자세).
	draw_circle(Vector2(-FALLBACK_W * 0.30, -FALLBACK_H * 0.5 - 2.0), 2.0, HAND_COLOR)
	draw_circle(Vector2(FALLBACK_W * 0.30, -FALLBACK_H * 0.5 - 2.0), 2.0, HAND_COLOR)
	# 옷자락(거꾸로 — 위로 펄럭).
	var cloth: Color = Color(c.r * 0.6, c.g * 0.6, c.b * 0.7, 1.0)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, 4.0)), cloth)
	if _state == State.ACTIVE_FLEE:
		# 활성화 — 보라색 광채.
		var prog: float = clampf(_state_timer / maxf(0.001, _mirror_duration), 0.0, 1.0)
		var glow: Color = Color(0.85, 0.45, 0.95, 0.30 + 0.30 * prog)
		draw_arc(Vector2.ZERO, FALLBACK_W * 0.9, 0.0, TAU, 24, glow, 2.0)
	elif _cd_timer > 0.0:
		# 쿨다운 표시 — 옅은 회색 호.
		var cd_prog: float = 1.0 - clampf(_cd_timer / maxf(0.001, _mirror_cooldown), 0.0, 1.0)
		var cd_col: Color = Color(0.50, 0.50, 0.55, 0.25)
		draw_arc(Vector2.ZERO, FALLBACK_W * 0.7, -PI * 0.5, -PI * 0.5 + TAU * cd_prog, 24, cd_col, 1.5)
