extends EnemyBase

# M42 흑무사 — 매우 느린 접근. 근접 시 greatcleave_telegraph_s(1.0s) 예고 후
# 전방 greatcleave_box_w_px × greatcleave_box_h_px (64×96) 박스 단발 greatcleave_damage(22) 내려치기.
# 직후 self_stun_after_s(1.0s) 자체 경직 — 그 동안 받는 피해 ×self_stun_taken_damage_mult(1.5).
# 사이클 쿨다운: attack_cooldown(3.5s).

const DEFAULT_TELEGRAPH_S: float = 1.0
const DEFAULT_BOX_W_PX: float = 64.0
const DEFAULT_BOX_H_PX: float = 96.0
const DEFAULT_CLEAVE_DAMAGE: int = 22
const DEFAULT_SELF_STUN_S: float = 1.0
const DEFAULT_TAKEN_DAMAGE_MULT: float = 1.5
const DEFAULT_ATTACK_RANGE_PX: float = 96.0
const DEFAULT_ATTACK_COOLDOWN_S: float = 3.5

const FALLBACK_COLOR: Color = Color(0.10, 0.10, 0.12, 1.0)
const FALLBACK_W: float = 24.0
const FALLBACK_H: float = 28.0

enum State { APPROACH, TELEGRAPH, RECOVER }

var _telegraph_s: float = DEFAULT_TELEGRAPH_S
var _box_w: float = DEFAULT_BOX_W_PX
var _box_h: float = DEFAULT_BOX_H_PX
var _cleave_damage: int = DEFAULT_CLEAVE_DAMAGE
var _self_stun_s: float = DEFAULT_SELF_STUN_S
var _taken_damage_mult: float = DEFAULT_TAKEN_DAMAGE_MULT
var _attack_range: float = DEFAULT_ATTACK_RANGE_PX
var _attack_cooldown: float = DEFAULT_ATTACK_COOLDOWN_S

var _state: int = State.APPROACH
var _state_timer: float = 0.0
var _attack_cd_timer: float = 0.0
var _cleave_dir: Vector2 = Vector2.RIGHT


func _ready() -> void:
	if data == null:
		max_hp = 110
		move_speed = 40.0
		contact_damage = 22
		exp_drop_value = 28
		coin_drop_value = 1
		coin_drop_chance = 0.50
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("greatcleave_telegraph_s"):
			_telegraph_s = float(params["greatcleave_telegraph_s"])
		if params.has("greatcleave_box_w_px"):
			_box_w = float(params["greatcleave_box_w_px"])
		if params.has("greatcleave_box_h_px"):
			_box_h = float(params["greatcleave_box_h_px"])
		if params.has("greatcleave_damage"):
			_cleave_damage = int(params["greatcleave_damage"])
		if params.has("self_stun_after_s"):
			_self_stun_s = float(params["self_stun_after_s"])
		if params.has("self_stun_taken_damage_mult"):
			_taken_damage_mult = float(params["self_stun_taken_damage_mult"])
		if data.ranged_range_px > 0.0:
			_attack_range = data.ranged_range_px
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
	match _state:
		State.APPROACH:
			_run_approach()
			if _attack_cd_timer <= 0.0:
				var d: float = global_position.distance_to(target.global_position)
				if d <= _attack_range:
					_enter_telegraph()
		State.TELEGRAPH:
			_run_telegraph(delta)
		State.RECOVER:
			_run_recover(delta)
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


func _enter_telegraph() -> void:
	_state = State.TELEGRAPH
	_state_timer = _telegraph_s
	var v: Vector2 = target.global_position - global_position
	if v.length_squared() > 0.0001:
		_cleave_dir = v.normalized()
	else:
		_cleave_dir = Vector2.RIGHT
	velocity = Vector2.ZERO


func _run_telegraph(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	velocity = Vector2.ZERO
	move_and_slide()
	if _state_timer <= 0.0:
		_execute_cleave()
		_state = State.RECOVER
		_state_timer = _self_stun_s


func _execute_cleave() -> void:
	# 전방 _box_w × _box_h 박스 단발. 박스 중심: 자신 위치 + _cleave_dir × (_box_h × 0.5).
	if not is_instance_valid(target):
		return
	var forward: Vector2 = _cleave_dir
	var right: Vector2 = Vector2(forward.y, -forward.x)
	var center: Vector2 = global_position + forward * (_box_h * 0.5)
	var rel: Vector2 = target.global_position - center
	var local_y: float = rel.dot(forward)
	var local_x: float = rel.dot(right)
	if absf(local_x) <= _box_w * 0.5 and absf(local_y) <= _box_h * 0.5:
		if target.has_method("take_damage"):
			target.take_damage(_cleave_damage)


func _run_recover(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	velocity = Vector2.ZERO
	move_and_slide()
	if _state_timer <= 0.0:
		_state = State.APPROACH
		_attack_cd_timer = _attack_cooldown


func take_damage(amount: int, attacker: Object = null) -> void:
	if is_dying:
		return
	var modified: int = amount
	if _state == State.RECOVER:
		modified = int(round(float(amount) * _taken_damage_mult))
	super.take_damage(modified, attacker)


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	if _state == State.TELEGRAPH:
		c = c.lerp(Color(0.95, 0.30, 0.20, 1.0), 0.30)
	elif _state == State.RECOVER:
		c = c.lerp(Color(0.95, 0.85, 0.20, 1.0), 0.30)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 투구 빨간 술.
	var plume: Color = Color(0.95, 0.20, 0.20, 1.0)
	draw_rect(Rect2(Vector2(-2.0, -FALLBACK_H * 0.5 - 4.0), Vector2(4.0, 4.0)), plume)
	var blade: Color = Color(0.80, 0.80, 0.90, 1.0)
	if _state == State.TELEGRAPH:
		# 무기 들어올림 placeholder — 위로 들어 올린 도.
		var up: Vector2 = -_cleave_dir * (FALLBACK_H * 0.8)
		draw_line(Vector2.ZERO, up, blade, 3.0)
		# 예고 박스 외곽선.
		var forward: Vector2 = _cleave_dir
		var right: Vector2 = Vector2(forward.y, -forward.x)
		var center: Vector2 = _cleave_dir * (_box_h * 0.5)
		var p0: Vector2 = center + right * (_box_w * 0.5) + forward * (_box_h * 0.5)
		var p1: Vector2 = center - right * (_box_w * 0.5) + forward * (_box_h * 0.5)
		var p2: Vector2 = center - right * (_box_w * 0.5) - forward * (_box_h * 0.5)
		var p3: Vector2 = center + right * (_box_w * 0.5) - forward * (_box_h * 0.5)
		var prog: float = 1.0 - clampf(_state_timer / maxf(0.001, _telegraph_s), 0.0, 1.0)
		var warn: Color = Color(1.0, 0.30, 0.20, 0.30 + 0.45 * prog)
		draw_line(p0, p1, warn, 1.5)
		draw_line(p1, p2, warn, 1.5)
		draw_line(p2, p3, warn, 1.5)
		draw_line(p3, p0, warn, 1.5)
	else:
		# 어깨에 멘 도(평상시).
		draw_line(Vector2(0.0, -FALLBACK_H * 0.5), Vector2(0.0, -FALLBACK_H * 0.5 - 8.0), blade, 2.0)
	if _state == State.RECOVER:
		# 경직 표시 — 노란 호.
		draw_arc(Vector2.ZERO, FALLBACK_W * 0.9, 0.0, TAU, 20, Color(1.0, 0.90, 0.30, 0.45), 1.5)
