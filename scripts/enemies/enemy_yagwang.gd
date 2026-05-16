extends EnemyBase

# M24 야광귀 — 빠른 회피(이속 100). 평소 일정 거리 유지, 5초마다 접근해 0.3초 접촉 시도 → 성공 시 신발 도둑 디버프.
# 디버프: 이속 -50% 5초. 본인 처치 시 디버프 해제 + 금화 보너스 +50%.

const DEFAULT_STEAL_INTERVAL_S: float = 5.0
const DEFAULT_STEAL_CONTACT_WINDOW_S: float = 0.3
const DEFAULT_STEAL_CONTACT_DAMAGE: int = 7
const DEFAULT_STEAL_SLOW_MULT: float = 0.5
const DEFAULT_STEAL_SLOW_DURATION_S: float = 5.0
const DEFAULT_EVASION_SPEED_PX: float = 100.0
const DEFAULT_GOLD_BONUS_MULT: float = 1.5
const DEFAULT_ON_DEATH_CLEAR_DEBUFF: bool = true

const EVADE_HOLD_DISTANCE_MIN: float = 80.0
const EVADE_HOLD_DISTANCE_MAX: float = 160.0
const STEAL_TOUCH_RADIUS_PX: float = 18.0

const FALLBACK_COLOR: Color = Color(0.10, 0.10, 0.15, 1.0)
const FALLBACK_W: float = 16.0
const FALLBACK_H: float = 22.0

enum State { EVADE, APPROACH, STEAL_CONTACT }

var _steal_interval: float = DEFAULT_STEAL_INTERVAL_S
var _steal_window: float = DEFAULT_STEAL_CONTACT_WINDOW_S
var _steal_contact_damage: int = DEFAULT_STEAL_CONTACT_DAMAGE
var _steal_slow_mult: float = DEFAULT_STEAL_SLOW_MULT
var _steal_slow_duration: float = DEFAULT_STEAL_SLOW_DURATION_S
var _evasion_speed: float = DEFAULT_EVASION_SPEED_PX
var _gold_bonus_mult: float = DEFAULT_GOLD_BONUS_MULT
var _on_death_clear_debuff: bool = DEFAULT_ON_DEATH_CLEAR_DEBUFF

var _state: int = State.EVADE
var _state_timer: float = 0.0
var _cycle_timer: float = 0.0
var _stolen_applied: bool = false


func _ready() -> void:
	if data == null:
		max_hp = 24
		move_speed = 100.0
		contact_damage = 5
		exp_drop_value = 9
		coin_drop_value = 1
		coin_drop_chance = 0.40
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("steal_interval_s"):
			_steal_interval = float(params["steal_interval_s"])
		if params.has("steal_contact_window_s"):
			_steal_window = float(params["steal_contact_window_s"])
		if params.has("steal_contact_damage"):
			_steal_contact_damage = int(params["steal_contact_damage"])
		if params.has("steal_slow_mult"):
			_steal_slow_mult = float(params["steal_slow_mult"])
		if params.has("steal_slow_duration_s"):
			_steal_slow_duration = float(params["steal_slow_duration_s"])
		if params.has("evasion_speed_px"):
			_evasion_speed = float(params["evasion_speed_px"])
		if params.has("on_death_gold_bonus_mult"):
			_gold_bonus_mult = float(params["on_death_gold_bonus_mult"])
		if params.has("on_death_clear_debuff"):
			_on_death_clear_debuff = bool(params["on_death_clear_debuff"])
	move_speed = _evasion_speed
	hp = max_hp
	_cycle_timer = _steal_interval


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	if not is_instance_valid(target):
		target = _resolve_target()
		if not is_instance_valid(target):
			return
	_tick_slow_stun(delta)
	if _stun_remaining > 0.0:
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return
	match _state:
		State.EVADE:
			_run_evade(delta)
		State.APPROACH:
			_run_approach(delta)
		State.STEAL_CONTACT:
			_run_steal_contact(delta)
	queue_redraw()


func _tick_slow_stun(delta: float) -> void:
	_contact_timer = maxf(0.0, _contact_timer - delta)
	if _slow_remaining > 0.0:
		_slow_remaining -= delta
		if _slow_remaining <= 0.0:
			_slow_remaining = 0.0
			_slow_factor = 1.0
	if _stun_remaining > 0.0:
		_stun_remaining = maxf(0.0, _stun_remaining - delta)


func _run_evade(delta: float) -> void:
	_cycle_timer = maxf(0.0, _cycle_timer - delta)
	var d: float = global_position.distance_to(target.global_position)
	var dir: Vector2
	if d < EVADE_HOLD_DISTANCE_MIN:
		# 너무 가까우면 옆으로 빠짐(수직 + 약간 후퇴).
		var away: Vector2 = (global_position - target.global_position)
		if away.length_squared() < 0.001:
			away = Vector2(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0)
		away = away.normalized()
		var perp: Vector2 = Vector2(-away.y, away.x)
		dir = (perp + away * 0.4).normalized()
	elif d > EVADE_HOLD_DISTANCE_MAX:
		# 너무 멀면 접근.
		dir = (target.global_position - global_position).normalized()
	else:
		# 일정 거리 유지(작은 좌우 흔들림).
		var perp_dir: Vector2 = Vector2(-(target.global_position - global_position).normalized().y, (target.global_position - global_position).normalized().x)
		dir = perp_dir * (1.0 if (int(Time.get_ticks_msec() / 600) % 2 == 0) else -1.0)
	velocity = dir * move_speed * _slow_factor
	move_and_slide()
	if _cycle_timer <= 0.0:
		_state = State.APPROACH


func _run_approach(_delta: float) -> void:
	# 신발 훔치기 — 플레이어에게 직선 접근.
	var dir: Vector2 = (target.global_position - global_position)
	var d: float = dir.length()
	if d > 0.001:
		dir = dir / d
	velocity = dir * move_speed * 1.15 * _slow_factor
	move_and_slide()
	if d <= STEAL_TOUCH_RADIUS_PX + 4.0:
		_state = State.STEAL_CONTACT
		_state_timer = _steal_window


func _run_steal_contact(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	velocity = (target.global_position - global_position).normalized() * move_speed * 0.4 * _slow_factor
	move_and_slide()
	# 0.3초 접촉 시도 — 접촉 성공 시 디버프 + 약한 접촉 데미지.
	var d: float = global_position.distance_to(target.global_position)
	if d <= STEAL_TOUCH_RADIUS_PX:
		_apply_steal()
		_finish_steal_cycle()
		return
	if _state_timer <= 0.0:
		_finish_steal_cycle()


func _apply_steal() -> void:
	if not is_instance_valid(target):
		return
	if target.has_method("apply_slow"):
		target.apply_slow(_steal_slow_mult, _steal_slow_duration)
		_stolen_applied = true
	if target.has_method("take_damage"):
		target.take_damage(_steal_contact_damage)


func _finish_steal_cycle() -> void:
	_state = State.EVADE
	_cycle_timer = _steal_interval


func die() -> void:
	if is_dying:
		return
	# 처치 시 본인이 부여한 디버프 해제.
	if _on_death_clear_debuff and _stolen_applied:
		_clear_player_steal_debuff()
	super.die()


func _clear_player_steal_debuff() -> void:
	if not is_instance_valid(target):
		return
	# 1) 플레이어가 명시적 해제 메서드를 제공하면 사용.
	if target.has_method("clear_slow"):
		target.clear_slow()
		return
	# 2) 폴백: 슬로우 관련 내부 필드를 직접 리셋(player.gd 컨벤션).
	if "_slow_factor" in target:
		target._slow_factor = 1.0
	if "_slow_remaining" in target:
		target._slow_remaining = 0.0


func _notify_main_on_kill() -> void:
	# 금화 보너스 +50%(드롭 로직에서 배율 곱). 부모 호출 전에 일시 증액.
	var main: Node = get_tree().current_scene
	if main == null:
		return
	if main.has_method("on_enemy_killed"):
		main.on_enemy_killed()
	if coin_drop_value > 0 and randf() < coin_drop_chance:
		var bonus_amount: int = int(round(float(coin_drop_value) * _gold_bonus_mult))
		if main.has_method("on_coin_dropped"):
			main.on_coin_dropped(maxi(1, bonus_amount))


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 빛나는 두 눈.
	draw_circle(Vector2(-FALLBACK_W * 0.2, -FALLBACK_H * 0.2), 1.6, Color(1.0, 0.95, 0.55, 1.0))
	draw_circle(Vector2(FALLBACK_W * 0.2, -FALLBACK_H * 0.2), 1.6, Color(1.0, 0.95, 0.55, 1.0))
	# 등 뒤 부대 자루(갈색 둥근 형태).
	draw_circle(Vector2(0.0, FALLBACK_H * 0.3), 5.0, Color(0.45, 0.30, 0.15, 1.0))
	# 검은 두건 윗부분.
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5 - 2.0), Vector2(FALLBACK_W, 4.0)), Color(0.05, 0.05, 0.05, 1.0))
	if _state == State.APPROACH or _state == State.STEAL_CONTACT:
		draw_arc(Vector2.ZERO, STEAL_TOUCH_RADIUS_PX, 0.0, TAU, 24, Color(1.0, 0.9, 0.4, 0.55), 1.2)
