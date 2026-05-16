extends EnemyBase

# M51 술취한 도깨비 — 갈지자(z) 이동(매 zigzag_change_interval_s마다 ±zigzag_angle_change_deg 회전).
# 자기 주변 aura_dot_radius_px(60) 안에 플레이어가 있으면 aura_dot_tick_interval_s(0.5s)마다
# aura_dot_damage(2) 도트 데미지. HP가 enrage_hp_threshold_pct(0.30) 이하로 떨어지면
# 취중폭주(ENRAGE): 이속 ×enrage_move_speed_mult(2.0), 직선 돌진 시도(폭 enrage_charge_width_px(32),
# 길이 enrage_charge_length_px(48)) — 돌진 박스 안 플레이어에게 데미지 ×enrage_charge_damage_mult(1.5).

const DEFAULT_ZIGZAG_ANGLE_DEG: float = 30.0
const DEFAULT_ZIGZAG_INTERVAL_S: float = 0.5
const DEFAULT_AURA_RADIUS_PX: float = 60.0
const DEFAULT_AURA_DAMAGE: int = 2
const DEFAULT_AURA_TICK_S: float = 0.5
const DEFAULT_ENRAGE_HP_PCT: float = 0.30
const DEFAULT_ENRAGE_SPEED_MULT: float = 2.0
const DEFAULT_ENRAGE_CHARGE_WIDTH: float = 32.0
const DEFAULT_ENRAGE_CHARGE_LENGTH: float = 48.0
const DEFAULT_ENRAGE_CHARGE_DAMAGE_MULT: float = 1.5

const FALLBACK_COLOR: Color = Color(0.78, 0.65, 0.55, 1.0)
const FALLBACK_W: float = 16.0
const FALLBACK_H: float = 20.0
const FACE_COLOR: Color = Color(0.95, 0.55, 0.55, 1.0)
const NOSE_COLOR: Color = Color(0.95, 0.30, 0.30, 1.0)
const BOTTLE_COLOR: Color = Color(0.55, 0.40, 0.25, 1.0)
const AURA_COLOR: Color = Color(0.85, 0.80, 0.55, 0.18)
const CHARGE_COLOR: Color = Color(0.95, 0.45, 0.35, 0.35)

enum State { DRUNK_WANDER, ENRAGE }

var _zigzag_angle_deg: float = DEFAULT_ZIGZAG_ANGLE_DEG
var _zigzag_interval: float = DEFAULT_ZIGZAG_INTERVAL_S
var _aura_radius: float = DEFAULT_AURA_RADIUS_PX
var _aura_damage: int = DEFAULT_AURA_DAMAGE
var _aura_tick: float = DEFAULT_AURA_TICK_S
var _enrage_hp_pct: float = DEFAULT_ENRAGE_HP_PCT
var _enrage_speed_mult: float = DEFAULT_ENRAGE_SPEED_MULT
var _enrage_charge_enabled: bool = true
var _enrage_charge_width: float = DEFAULT_ENRAGE_CHARGE_WIDTH
var _enrage_charge_length: float = DEFAULT_ENRAGE_CHARGE_LENGTH
var _enrage_charge_damage_mult: float = DEFAULT_ENRAGE_CHARGE_DAMAGE_MULT

var _state: int = State.DRUNK_WANDER
var _zigzag_timer: float = 0.0
var _aura_timer: float = 0.0
var _wobble_dir: Vector2 = Vector2.RIGHT
var _enrage_charge_dir: Vector2 = Vector2.RIGHT
var _enrage_speed_applied: bool = false
var _enrage_flash: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 50
		move_speed = 60.0
		contact_damage = 8
		exp_drop_value = 15
		coin_drop_value = 1
		coin_drop_chance = 0.55
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("zigzag_angle_change_deg"):
			_zigzag_angle_deg = float(params["zigzag_angle_change_deg"])
		if params.has("zigzag_change_interval_s"):
			_zigzag_interval = float(params["zigzag_change_interval_s"])
		if params.has("aura_dot_radius_px"):
			_aura_radius = float(params["aura_dot_radius_px"])
		if params.has("aura_dot_damage"):
			_aura_damage = int(params["aura_dot_damage"])
		if params.has("aura_dot_tick_interval_s"):
			_aura_tick = float(params["aura_dot_tick_interval_s"])
		if params.has("enrage_hp_threshold_pct"):
			_enrage_hp_pct = float(params["enrage_hp_threshold_pct"])
		if params.has("enrage_move_speed_mult"):
			_enrage_speed_mult = float(params["enrage_move_speed_mult"])
		if params.has("enrage_charge_enabled"):
			_enrage_charge_enabled = bool(params["enrage_charge_enabled"])
		if params.has("enrage_charge_width_px"):
			_enrage_charge_width = float(params["enrage_charge_width_px"])
		if params.has("enrage_charge_length_px"):
			_enrage_charge_length = float(params["enrage_charge_length_px"])
		if params.has("enrage_charge_damage_mult"):
			_enrage_charge_damage_mult = float(params["enrage_charge_damage_mult"])
		if data.ranged_range_px > 0.0:
			_aura_radius = data.ranged_range_px
		if data.ranged_damage > 0:
			_aura_damage = data.ranged_damage
		if data.ranged_cooldown > 0.0:
			_aura_tick = data.ranged_cooldown
	hp = max_hp
	_zigzag_timer = _zigzag_interval
	_aura_timer = _aura_tick
	_wobble_dir = Vector2.RIGHT


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
	_check_enrage_threshold()
	if _enrage_flash > 0.0:
		_enrage_flash = maxf(0.0, _enrage_flash - delta)
	match _state:
		State.DRUNK_WANDER:
			_run_drunk(delta)
		State.ENRAGE:
			_run_enrage(delta)
	_tick_aura(delta)
	if _contact_timer <= 0.0 and _contact_area:
		for body in _contact_area.get_overlapping_bodies():
			if body == target:
				_deal_contact_damage()
				break
	queue_redraw()


func _check_enrage_threshold() -> void:
	if _state == State.ENRAGE:
		return
	if max_hp <= 0:
		return
	var pct: float = float(hp) / float(max_hp)
	if pct <= _enrage_hp_pct:
		_state = State.ENRAGE
		_enrage_flash = 0.5
		if not _enrage_speed_applied:
			move_speed = move_speed * _enrage_speed_mult
			_enrage_speed_applied = true


func _run_drunk(delta: float) -> void:
	_zigzag_timer = maxf(0.0, _zigzag_timer - delta)
	if _zigzag_timer <= 0.0:
		_pick_wobble_dir()
		_zigzag_timer = _zigzag_interval
	# 갈지자 — 플레이어 방향을 기본 축으로 잡고 좌우로 wobble.
	var to_t: Vector2 = target.global_position - global_position
	var base_dir: Vector2 = to_t.normalized() if to_t.length_squared() > 0.0001 else Vector2.RIGHT
	var rad: float = deg_to_rad(_zigzag_angle_deg) * _wobble_dir.x
	var rotated: Vector2 = base_dir.rotated(rad)
	velocity = rotated * move_speed * _slow_factor
	move_and_slide()


func _pick_wobble_dir() -> void:
	# +1(우회전) 또는 -1(좌회전)을 균등 추첨. 매번 부호가 바뀌도록 강제하지는 않는다.
	_wobble_dir = Vector2((1.0 if randi() % 2 == 0 else -1.0), 0.0)


func _run_enrage(delta: float) -> void:
	if not _enrage_charge_enabled:
		# 폭주 단순화 — 직선 추격(이속 부스트만 적용된 상태).
		var dir: Vector2 = (target.global_position - global_position).normalized()
		velocity = dir * move_speed * _slow_factor
		move_and_slide()
		return
	# 방향은 매 프레임 재계산(돌진 시도이지 고정 직선이 아님).
	var to_t: Vector2 = target.global_position - global_position
	if to_t.length_squared() > 0.0001:
		_enrage_charge_dir = to_t.normalized()
	velocity = _enrage_charge_dir * move_speed * _slow_factor
	move_and_slide()
	_apply_enrage_charge_box_damage()


func _apply_enrage_charge_box_damage() -> void:
	# 자기 정면 박스(폭 _enrage_charge_width, 길이 _enrage_charge_length) 안에 들어온
	# 플레이어에게 접촉 데미지 × _enrage_charge_damage_mult 적용. 일반 접촉 쿨다운에 묶인다.
	if _contact_timer > 0.0:
		return
	if not is_instance_valid(target):
		return
	var fwd: Vector2 = _enrage_charge_dir
	var right: Vector2 = Vector2(fwd.y, -fwd.x)
	var center: Vector2 = global_position + fwd * (_enrage_charge_length * 0.5)
	var rel: Vector2 = target.global_position - center
	var local_y: float = rel.dot(fwd)
	var local_x: float = rel.dot(right)
	if absf(local_x) <= _enrage_charge_width * 0.5 and absf(local_y) <= _enrage_charge_length * 0.5:
		if target.has_method("take_damage"):
			var dmg: int = int(round(float(contact_damage) * _enrage_charge_damage_mult))
			target.take_damage(dmg)
		_contact_timer = CONTACT_COOLDOWN


func _tick_aura(delta: float) -> void:
	_aura_timer = maxf(0.0, _aura_timer - delta)
	if _aura_timer > 0.0:
		return
	_aura_timer = _aura_tick
	if not is_instance_valid(target):
		return
	var d: float = global_position.distance_to(target.global_position)
	if d > _aura_radius:
		return
	if target.has_method("take_damage"):
		target.take_damage(_aura_damage)


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	if _state == State.ENRAGE:
		c = c.lerp(Color(0.95, 0.40, 0.30, 1.0), 0.30)
	if _enrage_flash > 0.0:
		c = c.lerp(Color(1.0, 0.85, 0.30, 1.0), 0.40 * (_enrage_flash / 0.5))
	# 술기운 도트 오라.
	draw_circle(Vector2.ZERO, _aura_radius, AURA_COLOR)
	# 본체.
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 홍조 — 양 뺨.
	draw_circle(Vector2(-FALLBACK_W * 0.30, -FALLBACK_H * 0.10), 2.0, FACE_COLOR)
	draw_circle(Vector2(FALLBACK_W * 0.30, -FALLBACK_H * 0.10), 2.0, FACE_COLOR)
	# 빨간 코.
	draw_circle(Vector2(0.0, -FALLBACK_H * 0.05), 2.2, NOSE_COLOR)
	# 양손 호리병.
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5 - 4.0, -2.0), Vector2(3.0, 6.0)), BOTTLE_COLOR)
	draw_rect(Rect2(Vector2(FALLBACK_W * 0.5 + 1.0, -2.0), Vector2(3.0, 6.0)), BOTTLE_COLOR)
	if _state == State.ENRAGE and _enrage_charge_enabled:
		# 돌진 박스 시각화.
		var fwd: Vector2 = _enrage_charge_dir
		var right: Vector2 = Vector2(fwd.y, -fwd.x)
		var pts: PackedVector2Array = PackedVector2Array()
		var half_w: float = _enrage_charge_width * 0.5
		var len: float = _enrage_charge_length
		pts.append(right * half_w)
		pts.append(right * half_w + fwd * len)
		pts.append(-right * half_w + fwd * len)
		pts.append(-right * half_w)
		pts.append(right * half_w)
		draw_colored_polygon(pts, CHARGE_COLOR)
