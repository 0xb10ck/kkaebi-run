extends EnemyBase

# M41 비형랑의 그림자 — 직선 접근 → 검 휘두름 → 후퇴 반복.
# 휘두름 직전 guard_window_s(0.13s) "가드" 자세: 그 동안 받는 데미지 ×guard_damage_mult(0.3).
# 가드 종료 직후 "카운터" 발동: 자기 주변 counter_radius_px(60) 단발,
# 데미지 counter_damage 또는 (contact_damage × counter_damage_mult(1.5)).
# 카운터 후 짧은 후퇴 페이즈 → 다시 접근. 사이클 쿨다운 attack_cooldown(2.5s).

const DEFAULT_GUARD_WINDOW_S: float = 0.13
const DEFAULT_GUARD_DAMAGE_MULT: float = 0.3
const DEFAULT_COUNTER_RADIUS_PX: float = 60.0
const DEFAULT_COUNTER_DAMAGE_MULT: float = 1.5
const DEFAULT_COUNTER_DAMAGE: int = 22
const DEFAULT_APPROACH_TRIGGER_PX: float = 60.0
const DEFAULT_ATTACK_COOLDOWN_S: float = 2.5
const DEFAULT_RETREAT_DURATION_S: float = 0.6

const FALLBACK_COLOR: Color = Color(0.12, 0.12, 0.16, 1.0)
const FALLBACK_W: float = 18.0
const FALLBACK_H: float = 28.0

enum State { APPROACH, GUARD, COUNTER, RETREAT }

var _guard_window: float = DEFAULT_GUARD_WINDOW_S
var _guard_damage_mult: float = DEFAULT_GUARD_DAMAGE_MULT
var _counter_radius: float = DEFAULT_COUNTER_RADIUS_PX
var _counter_damage_mult: float = DEFAULT_COUNTER_DAMAGE_MULT
var _counter_damage: int = DEFAULT_COUNTER_DAMAGE
var _approach_trigger: float = DEFAULT_APPROACH_TRIGGER_PX
var _attack_cooldown: float = DEFAULT_ATTACK_COOLDOWN_S
var _retreat_duration: float = DEFAULT_RETREAT_DURATION_S

var _state: int = State.APPROACH
var _state_timer: float = 0.0
var _attack_cd_timer: float = 0.0
var _retreat_dir: Vector2 = Vector2.RIGHT
var _counter_flash: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 65
		move_speed = 80.0
		contact_damage = 15
		exp_drop_value = 23
		coin_drop_value = 1
		coin_drop_chance = 0.42
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("guard_window_s"):
			_guard_window = float(params["guard_window_s"])
		if params.has("guard_damage_mult"):
			_guard_damage_mult = float(params["guard_damage_mult"])
		if params.has("counter_radius_px"):
			_counter_radius = float(params["counter_radius_px"])
		if params.has("counter_damage_mult"):
			_counter_damage_mult = float(params["counter_damage_mult"])
		if params.has("counter_damage"):
			_counter_damage = int(params["counter_damage"])
		if data.ranged_range_px > 0.0:
			_approach_trigger = data.ranged_range_px
		if data.attack_cooldown > 0.0:
			_attack_cooldown = data.attack_cooldown
	hp = max_hp


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
			return
	_attack_cd_timer = maxf(0.0, _attack_cd_timer - delta)
	if _counter_flash > 0.0:
		_counter_flash = maxf(0.0, _counter_flash - delta)
	match _state:
		State.APPROACH:
			_run_approach()
			if _attack_cd_timer <= 0.0:
				var d: float = global_position.distance_to(target.global_position)
				if d <= _approach_trigger:
					_enter_guard()
		State.GUARD:
			_run_guard(delta)
		State.COUNTER:
			_run_counter()
		State.RETREAT:
			_run_retreat(delta)
	queue_redraw()


func _run_approach() -> void:
	var to_t: Vector2 = target.global_position - global_position
	var d: float = to_t.length()
	if d <= 0.001:
		velocity = Vector2.ZERO
	else:
		velocity = (to_t / d) * move_speed * _slow_factor
	move_and_slide()
	if _contact_timer <= 0.0 and _contact_area:
		for body in _contact_area.get_overlapping_bodies():
			if body == target:
				_deal_contact_damage()
				break


func _enter_guard() -> void:
	_state = State.GUARD
	_state_timer = _guard_window
	velocity = Vector2.ZERO


func _run_guard(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	velocity = Vector2.ZERO
	move_and_slide()
	if _state_timer <= 0.0:
		_state = State.COUNTER


func _run_counter() -> void:
	# 자기 주변 _counter_radius 단발 데미지 — counter_damage 우선, 없으면 contact × mult.
	var dmg: int = _counter_damage
	if dmg <= 0:
		dmg = int(round(float(contact_damage) * _counter_damage_mult))
	if is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= _counter_radius:
			if target.has_method("take_damage"):
				target.take_damage(dmg)
	# 후퇴 페이즈 진입 — 플레이어 반대 방향.
	var away: Vector2 = global_position - target.global_position
	if away.length_squared() <= 0.0001:
		away = Vector2.RIGHT
	_retreat_dir = away.normalized()
	_state = State.RETREAT
	_state_timer = _retreat_duration
	_attack_cd_timer = _attack_cooldown
	_counter_flash = 0.25


func _run_retreat(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	velocity = _retreat_dir * move_speed * _slow_factor
	move_and_slide()
	if _state_timer <= 0.0:
		_state = State.APPROACH


func take_damage(amount: int, attacker: Object = null) -> void:
	if is_dying:
		return
	var modified: int = amount
	if _state == State.GUARD:
		modified = int(round(float(amount) * _guard_damage_mult))
		if modified < 0:
			modified = 0
	super.take_damage(modified, attacker)


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	if _state == State.GUARD:
		c = c.lerp(Color(0.40, 0.60, 1.0, 1.0), 0.35)
	elif _counter_flash > 0.0:
		c = c.lerp(Color(1.0, 0.30, 0.30, 1.0), 0.45)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 검은 머리띠.
	var band: Color = Color(0.85, 0.20, 0.20, 1.0)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5 + 2.0), Vector2(FALLBACK_W, 2.0)), band)
	# 한쪽 손의 흐릿한 칼.
	var blade: Color = Color(0.80, 0.80, 0.90, 0.85)
	draw_line(Vector2(FALLBACK_W * 0.5, -2.0), Vector2(FALLBACK_W * 0.5 + 8.0, -8.0), blade, 2.0)
	if _state == State.GUARD:
		# 가드 자세 — 푸른 광채 호.
		var prog: float = clampf(_state_timer / maxf(0.001, _guard_window), 0.0, 1.0)
		var guard_col: Color = Color(0.40, 0.60, 1.0, 0.30 + 0.30 * prog)
		draw_arc(Vector2.ZERO, FALLBACK_W * 0.9, 0.0, TAU, 24, guard_col, 1.5)
	if _counter_flash > 0.0:
		var counter_col: Color = Color(1.0, 0.40, 0.30, 0.55 * (_counter_flash / 0.25))
		draw_arc(Vector2.ZERO, _counter_radius, 0.0, TAU, 36, counter_col, 2.0)
