extends EnemyBase

# M32 나찰 — 광역 곡도 휘두름(반경 80px, 1초 예고).
# HP 50% 이하 진입 시 분노(1회 전용): 공격 속도 ×1.5(쿨다운 1/1.5), 이속 +20%.

const DEFAULT_AOE_RADIUS_PX: float = 80.0
const DEFAULT_AOE_TELEGRAPH_S: float = 1.0
const DEFAULT_AOE_DAMAGE: int = 11
const DEFAULT_AOE_COOLDOWN_S: float = 3.0
const DEFAULT_ENRAGE_HP_THRESHOLD: float = 0.5
const DEFAULT_ENRAGE_ATTACK_SPEED_MULT: float = 1.5
const DEFAULT_ENRAGE_MOVE_SPEED_MULT: float = 1.2

const FALLBACK_COLOR: Color = Color(0.78, 0.18, 0.18, 1.0)
const FALLBACK_W: float = 28.0
const FALLBACK_H: float = 32.0

enum State { CHASE, TELEGRAPH }

var _aoe_radius: float = DEFAULT_AOE_RADIUS_PX
var _aoe_telegraph: float = DEFAULT_AOE_TELEGRAPH_S
var _aoe_damage: int = DEFAULT_AOE_DAMAGE
var _aoe_cooldown: float = DEFAULT_AOE_COOLDOWN_S
var _enrage_threshold: float = DEFAULT_ENRAGE_HP_THRESHOLD
var _enrage_atk_mult: float = DEFAULT_ENRAGE_ATTACK_SPEED_MULT
var _enrage_move_mult: float = DEFAULT_ENRAGE_MOVE_SPEED_MULT

var _state: int = State.CHASE
var _state_timer: float = 0.0
var _cd_timer: float = 0.0
var _enraged: bool = false


func _ready() -> void:
	if data == null:
		max_hp = 75
		move_speed = 70.0
		contact_damage = 14
		exp_drop_value = 20
		coin_drop_value = 1
		coin_drop_chance = 0.42
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("aoe_radius_px"):
			_aoe_radius = float(params["aoe_radius_px"])
		if params.has("aoe_telegraph_s"):
			_aoe_telegraph = float(params["aoe_telegraph_s"])
		if params.has("aoe_damage"):
			_aoe_damage = int(params["aoe_damage"])
		if params.has("enrage_hp_threshold"):
			_enrage_threshold = float(params["enrage_hp_threshold"])
		if params.has("enrage_attack_speed_mult"):
			_enrage_atk_mult = float(params["enrage_attack_speed_mult"])
		if params.has("enrage_move_speed_mult"):
			_enrage_move_mult = float(params["enrage_move_speed_mult"])
		if data.ranged_damage > 0:
			_aoe_damage = data.ranged_damage
		if data.ranged_range_px > 0.0:
			_aoe_radius = data.ranged_range_px
		if data.ranged_cooldown > 0.0:
			_aoe_cooldown = data.ranged_cooldown
		if data.ranged_telegraph > 0.0:
			_aoe_telegraph = data.ranged_telegraph
	hp = max_hp
	_cd_timer = _aoe_cooldown


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_cd_timer = maxf(0.0, _cd_timer - delta)
	match _state:
		State.CHASE:
			_run_chase(delta)
		State.TELEGRAPH:
			_run_telegraph(delta)
	queue_redraw()


func _run_chase(delta: float) -> void:
	super._physics_process(delta)
	if _cd_timer <= 0.0 and is_instance_valid(target):
		var d: float = global_position.distance_to(target.global_position)
		if d <= _aoe_radius + 8.0:
			_enter_telegraph()


func _enter_telegraph() -> void:
	_state = State.TELEGRAPH
	_state_timer = _aoe_telegraph


func _run_telegraph(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	velocity = Vector2.ZERO
	move_and_slide()
	if _state_timer <= 0.0:
		_unleash_aoe()
		_state = State.CHASE
		_cd_timer = _aoe_cooldown


func _unleash_aoe() -> void:
	if not is_instance_valid(target):
		return
	var d: float = global_position.distance_to(target.global_position)
	if d <= _aoe_radius:
		if target.has_method("take_damage"):
			target.take_damage(_aoe_damage)


func take_damage(amount: int, attacker: Object = null) -> void:
	super.take_damage(amount, attacker)
	if is_dying or _enraged:
		return
	if max_hp > 0 and float(hp) <= float(max_hp) * _enrage_threshold:
		_enter_enrage()


func _enter_enrage() -> void:
	_enraged = true
	# 공격 속도 ×1.5 → 쿨다운 1/1.5.
	if _enrage_atk_mult > 0.0:
		_aoe_cooldown = _aoe_cooldown / _enrage_atk_mult
		_aoe_telegraph = _aoe_telegraph / _enrage_atk_mult
	# 이속 +20% (영구).
	move_speed = move_speed * _enrage_move_mult


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	if _enraged:
		c = c.lerp(Color(1.0, 0.55, 0.20, 1.0), 0.3)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 세 머리(중앙·좌·우).
	var head: Color = Color(0.95, 0.30, 0.30, 1.0)
	draw_circle(Vector2(0.0, -FALLBACK_H * 0.5 - 3.0), 3.5, head)
	draw_circle(Vector2(-7.0, -FALLBACK_H * 0.5 - 1.0), 2.8, head)
	draw_circle(Vector2(7.0, -FALLBACK_H * 0.5 - 1.0), 2.8, head)
	# 큰 곡도(아래쪽 호).
	var blade: Color = Color(0.85, 0.85, 0.90, 1.0)
	draw_arc(Vector2(FALLBACK_W * 0.5 + 6.0, 0.0), 8.0, -PI * 0.4, PI * 0.4, 12, blade, 2.0)
	if _state == State.TELEGRAPH:
		var warn: Color = Color(1.0, 0.35, 0.20, 0.30)
		draw_arc(Vector2.ZERO, _aoe_radius, 0.0, TAU, 36, warn, 2.0)
		# 진척도 표시(시간이 흐를수록 옅어짐).
		var prog: float = clamp(1.0 - _state_timer / maxf(0.001, _aoe_telegraph), 0.0, 1.0)
		draw_arc(Vector2.ZERO, _aoe_radius * 0.5, 0.0, TAU * prog, 32, Color(1.0, 0.65, 0.20, 0.45), 1.5)
