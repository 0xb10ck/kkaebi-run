extends EnemyBase

# M53 씨름 도깨비 — 직선 돌진(charge_cooldown_s 5.0s마다). 충돌 시 grapple_window_s(0.5s) 잡기 판정.
# 잡기 윈도우 안에 플레이어가 회피(grapple_evade_input_releases=true) 입력을 하면 즉시 풀려난다.
# 회피 미입력 시 grapple_restraint_duration_s(0.8s) 동안 플레이어 행동 불가 + 들어올림 던지기
# grapple_throw_damage(24)(또는 contact_damage × grapple_throw_damage_mult(2.0)). 잡기 성공/실패
# 모두 grapple_self_stagger_s(1.5s) 자체 경직.

const DEFAULT_CHARGE_COOLDOWN_S: float = 5.0
const DEFAULT_CHARGE_SPEED_PX: float = 160.0
const DEFAULT_CHARGE_DURATION_S: float = 1.2
const DEFAULT_GRAPPLE_WINDOW_S: float = 0.5
const DEFAULT_GRAPPLE_RESTRAINT_S: float = 0.8
const DEFAULT_GRAPPLE_THROW_DAMAGE: int = 24
const DEFAULT_GRAPPLE_THROW_DAMAGE_MULT: float = 2.0
const DEFAULT_GRAPPLE_SELF_STAGGER_S: float = 1.5

const FALLBACK_COLOR: Color = Color(0.45, 0.30, 0.20, 1.0)
const FALLBACK_W: float = 20.0
const FALLBACK_H: float = 24.0
const BELT_COLOR: Color = Color(0.95, 0.85, 0.35, 1.0)
const SKIN_COLOR: Color = Color(0.85, 0.65, 0.50, 1.0)
const TELEGRAPH_COLOR: Color = Color(0.95, 0.55, 0.25, 0.55)
const GRAPPLE_COLOR: Color = Color(0.95, 0.30, 0.30, 0.50)

enum State { CHASE, CHARGE, GRAPPLE, STAGGER }

var _charge_cooldown: float = DEFAULT_CHARGE_COOLDOWN_S
var _charge_speed: float = DEFAULT_CHARGE_SPEED_PX
var _charge_duration: float = DEFAULT_CHARGE_DURATION_S
var _grapple_window: float = DEFAULT_GRAPPLE_WINDOW_S
var _grapple_evade_releases: bool = true
var _grapple_restraint: float = DEFAULT_GRAPPLE_RESTRAINT_S
var _grapple_throw_damage: int = DEFAULT_GRAPPLE_THROW_DAMAGE
var _grapple_throw_damage_mult: float = DEFAULT_GRAPPLE_THROW_DAMAGE_MULT
var _grapple_self_stagger: float = DEFAULT_GRAPPLE_SELF_STAGGER_S
var _charge_enabled: bool = true

var _state: int = State.CHASE
var _state_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _charge_dir: Vector2 = Vector2.RIGHT
var _grapple_grabbed: bool = false
var _restraint_applied: bool = false


func _ready() -> void:
	if data == null:
		max_hp = 70
		move_speed = 70.0
		contact_damage = 12
		exp_drop_value = 22
		coin_drop_value = 1
		coin_drop_chance = 0.65
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("charge_attack"):
			_charge_enabled = bool(params["charge_attack"])
		if params.has("charge_cooldown_s"):
			_charge_cooldown = float(params["charge_cooldown_s"])
		if params.has("grapple_window_s"):
			_grapple_window = float(params["grapple_window_s"])
		if params.has("grapple_evade_input_releases"):
			_grapple_evade_releases = bool(params["grapple_evade_input_releases"])
		if params.has("grapple_restraint_duration_s"):
			_grapple_restraint = float(params["grapple_restraint_duration_s"])
		if params.has("grapple_throw_damage"):
			_grapple_throw_damage = int(params["grapple_throw_damage"])
		if params.has("grapple_throw_damage_mult"):
			_grapple_throw_damage_mult = float(params["grapple_throw_damage_mult"])
		if params.has("grapple_self_stagger_s"):
			_grapple_self_stagger = float(params["grapple_self_stagger_s"])
		if data.attack_cooldown > 0.0:
			_charge_cooldown = data.attack_cooldown
	hp = max_hp
	_cooldown_timer = _charge_cooldown


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
	match _state:
		State.CHASE:
			_run_chase(delta)
		State.CHARGE:
			_run_charge(delta)
		State.GRAPPLE:
			_run_grapple(delta)
		State.STAGGER:
			_run_stagger(delta)
	queue_redraw()


func _run_chase(delta: float) -> void:
	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	# 일반 추적.
	var dir: Vector2 = (target.global_position - global_position).normalized()
	velocity = dir * move_speed * _slow_factor
	move_and_slide()
	# 접촉 데미지 — 일반 추적 중에는 평타.
	if _contact_timer <= 0.0 and _contact_area:
		for body in _contact_area.get_overlapping_bodies():
			if body == target:
				_deal_contact_damage()
				break
	if _charge_enabled and _cooldown_timer <= 0.0:
		_enter_charge()


func _enter_charge() -> void:
	var to_t: Vector2 = target.global_position - global_position
	if to_t.length_squared() > 0.0001:
		_charge_dir = to_t.normalized()
	_state = State.CHARGE
	_state_timer = _charge_duration


func _run_charge(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	velocity = _charge_dir * _charge_speed * _slow_factor
	move_and_slide()
	# 충돌 시 잡기 진입.
	if _contact_area:
		for body in _contact_area.get_overlapping_bodies():
			if body == target:
				_enter_grapple()
				return
	if _state_timer <= 0.0:
		# 돌진 시간 내 접촉 실패 — 잡기 실패 처리.
		_enter_stagger()


func _enter_grapple() -> void:
	_state = State.GRAPPLE
	_state_timer = _grapple_window
	_grapple_grabbed = false
	_restraint_applied = false
	# 잡기 윈도우 시작 — 플레이어 행동 불가 부여(회피 미입력 시 풀리지 않음).
	_apply_player_restraint(_grapple_window + _grapple_restraint)
	_restraint_applied = true


func _run_grapple(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	# 잡기 중 — 플레이어를 자기 위치 근처로 끌어붙임.
	velocity = Vector2.ZERO
	move_and_slide()
	if _grapple_evade_releases and _player_pressed_evade():
		_release_grapple_early()
		return
	if _state_timer <= 0.0:
		_resolve_throw()


func _resolve_throw() -> void:
	_grapple_grabbed = true
	if is_instance_valid(target) and target.has_method("take_damage"):
		var dmg: int = _grapple_throw_damage
		if dmg <= 0:
			dmg = int(round(float(contact_damage) * _grapple_throw_damage_mult))
		target.take_damage(dmg)
	# 던지기 종료 — 플레이어 행동 불가 잔여분은 자연 해제(_apply_player_restraint에서 셋팅한
	# duration 만료까지 유지).
	_enter_stagger()


func _release_grapple_early() -> void:
	# 회피 입력으로 즉시 해제 — 플레이어 행동 불가도 즉시 해제.
	_release_player_restraint()
	_enter_stagger()


func _enter_stagger() -> void:
	_state = State.STAGGER
	_state_timer = _grapple_self_stagger
	_cooldown_timer = _charge_cooldown
	velocity = Vector2.ZERO


func _run_stagger(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	velocity = Vector2.ZERO
	move_and_slide()
	if _state_timer <= 0.0:
		_state = State.CHASE


func _apply_player_restraint(duration: float) -> void:
	if not is_instance_valid(target):
		return
	# 가능한 API를 순서대로 시도 — apply_stun → apply_restraint → set_grappled → apply_slow(0.05).
	if target.has_method("apply_stun"):
		target.apply_stun(duration)
		return
	if target.has_method("apply_restraint"):
		target.apply_restraint(duration)
		return
	if target.has_method("set_grappled"):
		target.set_grappled(true, duration)
		return
	if "grappled" in target:
		target.set("grappled", true)
		var t: SceneTreeTimer = get_tree().create_timer(duration)
		t.timeout.connect(_on_grapple_expired.bind(target))
		return
	# 폴백 — 이동 거의 정지로 환산. 플레이어가 apply_slow를 지원하면 0.05 factor.
	if target.has_method("apply_slow"):
		target.apply_slow(0.05, duration)


func _release_player_restraint() -> void:
	if not is_instance_valid(target):
		return
	if target.has_method("release_grapple"):
		target.release_grapple()
		return
	if target.has_method("clear_stun"):
		target.clear_stun()
		return
	if "grappled" in target:
		target.set("grappled", false)


func _on_grapple_expired(player_ref: Node) -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	if "grappled" in player_ref:
		player_ref.set("grappled", false)


func _player_pressed_evade() -> bool:
	# 플레이어 노드의 회피 입력을 확인 — has_method/property를 순서대로 검사한다.
	if is_instance_valid(target):
		if target.has_method("is_evading"):
			return bool(target.call("is_evading"))
		if target.has_method("is_dodging"):
			return bool(target.call("is_dodging"))
		if "evade_pressed" in target:
			return bool(target.get("evade_pressed"))
		if "is_dodging" in target:
			return bool(target.get("is_dodging"))
	# Input 액션 — "evade" 또는 "dodge"가 정의되어 있으면 활용.
	if InputMap.has_action(&"evade") and Input.is_action_just_pressed("evade"):
		return true
	if InputMap.has_action(&"dodge") and Input.is_action_just_pressed("dodge"):
		return true
	return false


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	# 본체 — 우락부락한 장사 체격.
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 머리.
	draw_circle(Vector2(0.0, -FALLBACK_H * 0.5 - 2.0), 5.0, SKIN_COLOR)
	# 외다리 — 한쪽만 굵게.
	draw_rect(Rect2(Vector2(-2.0, FALLBACK_H * 0.5), Vector2(4.0, 6.0)), c)
	# 샅바 — 노란 띠.
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, FALLBACK_H * 0.10), Vector2(FALLBACK_W, 4.0)), BELT_COLOR)
	# 어깨 근육 강조.
	draw_circle(Vector2(-FALLBACK_W * 0.5 - 1.0, -FALLBACK_H * 0.20), 3.0, SKIN_COLOR)
	draw_circle(Vector2(FALLBACK_W * 0.5 + 1.0, -FALLBACK_H * 0.20), 3.0, SKIN_COLOR)
	match _state:
		State.CHARGE:
			# 돌진 방향 화살.
			draw_line(Vector2.ZERO, _charge_dir * (FALLBACK_W * 0.8), TELEGRAPH_COLOR, 2.5)
		State.GRAPPLE:
			# 잡기 — 붉은 광채.
			var prog: float = clampf(_state_timer / maxf(0.001, _grapple_window), 0.0, 1.0)
			var col: Color = Color(GRAPPLE_COLOR.r, GRAPPLE_COLOR.g, GRAPPLE_COLOR.b, GRAPPLE_COLOR.a * prog)
			draw_arc(Vector2.ZERO, FALLBACK_W * 0.7, 0.0, TAU, 24, col, 2.0)
		State.STAGGER:
			# 경직 — 위로 별 표식.
			var p: Vector2 = Vector2(0.0, -FALLBACK_H * 0.5 - 8.0)
			draw_circle(p, 1.6, Color(0.95, 0.90, 0.40, 0.80))
			draw_circle(p + Vector2(-3.0, 1.0), 1.4, Color(0.95, 0.90, 0.40, 0.65))
			draw_circle(p + Vector2(3.0, 1.0), 1.4, Color(0.95, 0.90, 0.40, 0.65))
		_:
			pass
