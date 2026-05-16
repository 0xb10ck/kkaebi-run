extends EnemyBase

# M12 멧돼지 요괴 — 평소 느린 추적(이속 50). 5초 쿨다운마다 0.5초 발구르기 예고 후 직선 돌진(이속 160).
# 돌진 중 벽 충돌 시 1.5초 자기 스턴 + 받는 데미지 ×1.5. 돌진 중 플레이어 명중 시 1회 데미지 후 종료.

const DEFAULT_CHARGE_TELEGRAPH_S: float = 0.5
const DEFAULT_CHARGE_SPEED_PX: float = 160.0
const DEFAULT_CHARGE_DURATION_S: float = 1.5
const DEFAULT_CHARGE_COOLDOWN_S: float = 5.0
const DEFAULT_WALL_STUN_S: float = 1.5
const DEFAULT_WALL_DAMAGE_TAKEN_MULT: float = 1.5

const FALLBACK_COLOR: Color = Color(0.20, 0.15, 0.10, 1.0)
const FALLBACK_W: float = 22.0
const FALLBACK_H: float = 18.0

enum State { CHASE, TELEGRAPH, CHARGE }

var _charge_telegraph: float = DEFAULT_CHARGE_TELEGRAPH_S
var _charge_speed: float = DEFAULT_CHARGE_SPEED_PX
var _charge_duration: float = DEFAULT_CHARGE_DURATION_S
var _charge_cooldown: float = DEFAULT_CHARGE_COOLDOWN_S
var _wall_stun_s: float = DEFAULT_WALL_STUN_S
var _wall_damage_mult: float = DEFAULT_WALL_DAMAGE_TAKEN_MULT

var _state: int = State.CHASE
var _state_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _charge_dir: Vector2 = Vector2.RIGHT
var _stun_damage_boost_remaining: float = 0.0
var _shake_phase: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 50
		move_speed = 50.0
		contact_damage = 14
		exp_drop_value = 12
		coin_drop_value = 1
		coin_drop_chance = 0.28
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("charge_telegraph_s"):
			_charge_telegraph = float(params["charge_telegraph_s"])
		if params.has("charge_speed_px"):
			_charge_speed = float(params["charge_speed_px"])
		if params.has("charge_duration_s"):
			_charge_duration = float(params["charge_duration_s"])
		if params.has("charge_cooldown_s"):
			_charge_cooldown = float(params["charge_cooldown_s"])
		if params.has("wall_collide_stun_s"):
			_wall_stun_s = float(params["wall_collide_stun_s"])
		if params.has("wall_collide_damage_taken_mult"):
			_wall_damage_mult = float(params["wall_collide_damage_taken_mult"])
	_cooldown_timer = _charge_cooldown
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_stun_damage_boost_remaining = maxf(0.0, _stun_damage_boost_remaining - delta)
	_shake_phase = fmod(_shake_phase + delta * 18.0, TAU)
	match _state:
		State.CHASE:
			_run_chase(delta)
		State.TELEGRAPH:
			_run_telegraph(delta)
		State.CHARGE:
			_run_charge(delta)
	queue_redraw()


func _run_chase(delta: float) -> void:
	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	super._physics_process(delta)
	if _cooldown_timer <= 0.0 and is_instance_valid(target):
		_state = State.TELEGRAPH
		_state_timer = _charge_telegraph


func _run_telegraph(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	# 발 구르기 — 정지.
	velocity = Vector2.ZERO
	move_and_slide()
	if _state_timer <= 0.0:
		_enter_charge()


func _enter_charge() -> void:
	if not is_instance_valid(target):
		_state = State.CHASE
		_cooldown_timer = _charge_cooldown
		return
	var to_t: Vector2 = target.global_position - global_position
	if to_t.length_squared() > 0.01:
		_charge_dir = to_t.normalized()
	_state = State.CHARGE
	_state_timer = _charge_duration


func _run_charge(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	_contact_timer = maxf(0.0, _contact_timer - delta)
	velocity = _charge_dir * _charge_speed * _slow_factor
	move_and_slide()
	# 플레이어 충돌 — 1회 데미지 후 돌진 종료.
	if _contact_area:
		for body in _contact_area.get_overlapping_bodies():
			if body == target:
				_deal_contact_damage()
				_end_charge(false)
				return
	# 벽/장애물 충돌 검사 — 플레이어가 아닌 collider가 있으면 벽으로 간주.
	for i in get_slide_collision_count():
		var col: KinematicCollision2D = get_slide_collision(i)
		if col == null:
			continue
		var collider: Object = col.get_collider()
		if collider == null:
			continue
		if collider == target:
			continue
		if collider is Node and (collider as Node).is_in_group("player"):
			continue
		_end_charge(true)
		return
	if _state_timer <= 0.0:
		_end_charge(false)


func _end_charge(hit_wall: bool) -> void:
	_state = State.CHASE
	_cooldown_timer = _charge_cooldown
	if hit_wall:
		apply_stun(_wall_stun_s)
		_stun_damage_boost_remaining = _wall_stun_s


func take_damage(amount: int, attacker: Object = null) -> void:
	var amt: int = amount
	if _stun_damage_boost_remaining > 0.0:
		amt = int(round(float(amount) * _wall_damage_mult))
	super.take_damage(amt, attacker)


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	var shake: Vector2 = Vector2.ZERO
	if _state == State.TELEGRAPH:
		shake = Vector2(sin(_shake_phase) * 1.5, 0.0)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5) + shake, Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 빨간 눈.
	draw_circle(Vector2(-FALLBACK_W * 0.25, -FALLBACK_H * 0.15) + shake, 2.0, Color(0.9, 0.1, 0.1, 1.0))
	draw_circle(Vector2(FALLBACK_W * 0.25, -FALLBACK_H * 0.15) + shake, 2.0, Color(0.9, 0.1, 0.1, 1.0))
	if _state == State.TELEGRAPH:
		# 발구르기 예고 — 발 밑 먼지구름.
		draw_arc(Vector2(0, FALLBACK_H * 0.5), 10.0, 0.0, PI, 16, Color(0.7, 0.6, 0.4, 0.5), 1.5)
	elif _state == State.CHARGE:
		draw_line(Vector2.ZERO, _charge_dir * (FALLBACK_W * 0.7), Color(1.0, 0.4, 0.2, 0.8), 2.0)
	if _stun_damage_boost_remaining > 0.0:
		draw_arc(Vector2.ZERO, FALLBACK_W * 0.6, 0.0, TAU, 24, Color(1.0, 1.0, 0.4, 0.5), 1.5)
