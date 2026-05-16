extends EnemyBase

# M31 야차 — 빠른 근접 추적. 근접 시 3연타 도끼 콤보.
# 피격 직전 50% 확률로 ±60px 옆구르기 회피, 회피 중 무적, 1초 쿨다운.

const DEFAULT_TRIPLE_STRIKE_COUNT: int = 3
const DEFAULT_TRIPLE_STRIKE_INTERVAL_S: float = 0.25
const DEFAULT_COMBO_COOLDOWN_S: float = 2.5
const DEFAULT_DODGE_CHANCE: float = 0.5
const DEFAULT_DODGE_DISTANCE_PX: float = 60.0
const DEFAULT_DODGE_COOLDOWN_S: float = 1.0
const DEFAULT_DODGE_DURATION_S: float = 0.18

const MELEE_RANGE_PX: float = 24.0
const FALLBACK_COLOR: Color = Color(0.45, 0.65, 0.55, 1.0)
const FALLBACK_W: float = 20.0
const FALLBACK_H: float = 24.0

enum State { CHASE, COMBO, DODGE }

var _strike_count: int = DEFAULT_TRIPLE_STRIKE_COUNT
var _strike_interval: float = DEFAULT_TRIPLE_STRIKE_INTERVAL_S
var _combo_cooldown: float = DEFAULT_COMBO_COOLDOWN_S
var _dodge_chance: float = DEFAULT_DODGE_CHANCE
var _dodge_distance: float = DEFAULT_DODGE_DISTANCE_PX
var _dodge_cooldown: float = DEFAULT_DODGE_COOLDOWN_S
var _dodge_duration: float = DEFAULT_DODGE_DURATION_S

var _state: int = State.CHASE
var _state_timer: float = 0.0
var _combo_cd_timer: float = 0.0
var _strikes_remaining: int = 0
var _strike_timer: float = 0.0
var _dodge_cd_timer: float = 0.0
var _dodge_invuln: bool = false
var _dodge_origin: Vector2 = Vector2.ZERO
var _dodge_target: Vector2 = Vector2.ZERO


func _ready() -> void:
	if data == null:
		max_hp = 55
		move_speed = 95.0
		contact_damage = 11
		exp_drop_value = 16
		coin_drop_value = 1
		coin_drop_chance = 0.36
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("triple_strike_count"):
			_strike_count = int(params["triple_strike_count"])
		if params.has("triple_strike_interval_s"):
			_strike_interval = float(params["triple_strike_interval_s"])
		if params.has("dodge_chance"):
			_dodge_chance = float(params["dodge_chance"])
		if params.has("dodge_distance_px"):
			_dodge_distance = float(params["dodge_distance_px"])
		if params.has("dodge_cooldown_s"):
			_dodge_cooldown = float(params["dodge_cooldown_s"])
		if data.attack_cooldown > 0.0:
			_combo_cooldown = data.attack_cooldown
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
		return
	_combo_cd_timer = maxf(0.0, _combo_cd_timer - delta)
	_dodge_cd_timer = maxf(0.0, _dodge_cd_timer - delta)
	if not is_instance_valid(target):
		target = _resolve_target()
		if not is_instance_valid(target):
			return
	match _state:
		State.CHASE:
			_run_chase(delta)
		State.COMBO:
			_run_combo(delta)
		State.DODGE:
			_run_dodge(delta)
	queue_redraw()


func _run_chase(_delta: float) -> void:
	var to_t: Vector2 = target.global_position - global_position
	var d: float = to_t.length()
	if d > 0.001:
		velocity = (to_t / d) * move_speed * _slow_factor
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if d <= MELEE_RANGE_PX and _combo_cd_timer <= 0.0:
		_enter_combo()


func _enter_combo() -> void:
	_state = State.COMBO
	_strikes_remaining = _strike_count
	_strike_timer = 0.0  # 첫 타격은 즉시.


func _run_combo(delta: float) -> void:
	# 콤보 중에는 제자리 — 단발 데미지를 _strike_interval 간격으로 적용.
	velocity = Vector2.ZERO
	move_and_slide()
	_strike_timer = maxf(0.0, _strike_timer - delta)
	if _strikes_remaining > 0 and _strike_timer <= 0.0:
		_deliver_strike()
		_strikes_remaining -= 1
		_strike_timer = _strike_interval
	if _strikes_remaining <= 0 and _strike_timer <= 0.0:
		_state = State.CHASE
		_combo_cd_timer = _combo_cooldown


func _deliver_strike() -> void:
	if not is_instance_valid(target):
		return
	var d: float = global_position.distance_to(target.global_position)
	if d > MELEE_RANGE_PX + 6.0:
		return
	if target.has_method("take_damage"):
		target.take_damage(contact_damage)


func take_damage(amount: int, attacker: Object = null) -> void:
	if is_dying:
		return
	if _dodge_invuln:
		return
	if _dodge_cd_timer <= 0.0 and randf() < _dodge_chance:
		_start_dodge(attacker)
		return
	super.take_damage(amount, attacker)


func _start_dodge(attacker: Object) -> void:
	_state = State.DODGE
	_state_timer = _dodge_duration
	_dodge_invuln = true
	_dodge_cd_timer = _dodge_cooldown
	# 공격 방향에 수직(=옆)으로 무작위 부호.
	var ref_dir: Vector2 = Vector2.RIGHT
	if attacker != null and attacker is Node2D:
		var a: Vector2 = (attacker as Node2D).global_position
		var v: Vector2 = global_position - a
		if v.length_squared() > 0.001:
			ref_dir = v.normalized()
	elif is_instance_valid(target):
		var v2: Vector2 = global_position - target.global_position
		if v2.length_squared() > 0.001:
			ref_dir = v2.normalized()
	var perp: Vector2 = Vector2(-ref_dir.y, ref_dir.x)
	if randi() % 2 == 0:
		perp = -perp
	_dodge_origin = global_position
	_dodge_target = global_position + perp * _dodge_distance


func _run_dodge(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	var t: float = 1.0 - clamp(_state_timer / _dodge_duration, 0.0, 1.0)
	# 빠른 트윈(선형 보간) — CharacterBody2D는 직접 위치 이동.
	global_position = _dodge_origin.lerp(_dodge_target, t)
	velocity = Vector2.ZERO
	if _state_timer <= 0.0:
		_dodge_invuln = false
		_state = State.CHASE


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	if _dodge_invuln:
		c = c.lerp(Color(1.0, 1.0, 1.0, 0.6), 0.5)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 송곳니.
	var fang: Color = Color(1.0, 1.0, 1.0, 0.9)
	draw_line(Vector2(-2.0, -2.0), Vector2(-2.0, 2.0), fang, 1.0)
	draw_line(Vector2(2.0, -2.0), Vector2(2.0, 2.0), fang, 1.0)
	# 양손 도끼 표시.
	var axe: Color = Color(0.20, 0.20, 0.22, 1.0)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5 - 4.0, -2.0), Vector2(4.0, 6.0)), axe)
	draw_rect(Rect2(Vector2(FALLBACK_W * 0.5, -2.0), Vector2(4.0, 6.0)), axe)
	if _state == State.COMBO:
		# 콤보 시각 표시 — 잔여 타수만큼 작은 표식.
		var marker: Color = Color(1.0, 0.4, 0.3, 0.85)
		for i in _strikes_remaining:
			draw_circle(Vector2(-6.0 + float(i) * 6.0, -FALLBACK_H * 0.5 - 6.0), 1.6, marker)
