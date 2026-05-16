extends EnemyBase

# M37 학 요괴 — 공중(부유) 회피형. 일반 추적 + 부리 찌르기 직선 투사체.
# 피격 직전 공격 속성이 지상/토 계열이면 ground_attack_dodge_chance 확률로 회피(무효).
# dive_interval_s 마다 강하 공격: 플레이어의 현재 위치로 짧게 lerp 강하 → 100x40 단발 데미지 → 복귀.

const ENEMY_PROJECTILE: PackedScene = preload("res://scenes/enemies/enemy_projectile.tscn")

const DEFAULT_GROUND_DODGE_CHANCE: float = 0.5
const DEFAULT_DIVE_INTERVAL_S: float = 5.0
const DEFAULT_DIVE_W: float = 100.0
const DEFAULT_DIVE_H: float = 40.0
const DEFAULT_DIVE_DAMAGE: int = 9
const DEFAULT_PECK_COOLDOWN_S: float = 5.0
const DEFAULT_PECK_RANGE_PX: float = 240.0
const DEFAULT_PECK_SPEED: float = 320.0
const DEFAULT_PECK_DAMAGE: int = 11
const DEFAULT_PECK_TELEGRAPH_S: float = 0.3

const DIVE_DESCEND_S: float = 0.35
const DIVE_HOLD_S: float = 0.08
const DIVE_ASCEND_S: float = 0.30
const DODGE_INVULN_S: float = 0.18

const PECK_COLOR: Color = Color(0.95, 0.95, 0.92, 1.0)

const FALLBACK_COLOR: Color = Color(0.95, 0.95, 0.92, 1.0)
const FALLBACK_W: float = 24.0
const FALLBACK_H: float = 18.0

enum State { CHASE, PECK_TELEGRAPH, DIVE_DESCEND, DIVE_HOLD, DIVE_ASCEND }

var _ground_dodge_chance: float = DEFAULT_GROUND_DODGE_CHANCE
var _dive_interval: float = DEFAULT_DIVE_INTERVAL_S
var _dive_w: float = DEFAULT_DIVE_W
var _dive_h: float = DEFAULT_DIVE_H
var _dive_damage: int = DEFAULT_DIVE_DAMAGE
var _peck_cd: float = DEFAULT_PECK_COOLDOWN_S
var _peck_range: float = DEFAULT_PECK_RANGE_PX
var _peck_speed: float = DEFAULT_PECK_SPEED
var _peck_damage: int = DEFAULT_PECK_DAMAGE
var _peck_telegraph: float = DEFAULT_PECK_TELEGRAPH_S

var _state: int = State.CHASE
var _state_timer: float = 0.0
var _peck_cd_timer: float = 0.0
var _dive_cd_timer: float = 0.0
var _aim_dir: Vector2 = Vector2.RIGHT

var _dive_start_pos: Vector2 = Vector2.ZERO
var _dive_target_pos: Vector2 = Vector2.ZERO

var _dodge_anim_remaining: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 38
		move_speed = 100.0
		contact_damage = 9
		exp_drop_value = 15
		coin_drop_value = 1
		coin_drop_chance = 0.32
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("ground_attack_dodge_chance"):
			_ground_dodge_chance = float(params["ground_attack_dodge_chance"])
		if params.has("dive_interval_s"):
			_dive_interval = float(params["dive_interval_s"])
		if params.has("dive_hitbox_w_px"):
			_dive_w = float(params["dive_hitbox_w_px"])
		if params.has("dive_hitbox_h_px"):
			_dive_h = float(params["dive_hitbox_h_px"])
		if params.has("dive_damage"):
			_dive_damage = int(params["dive_damage"])
		if data.ranged_cooldown > 0.0:
			_peck_cd = data.ranged_cooldown
		if data.ranged_range_px > 0.0:
			_peck_range = data.ranged_range_px
		if data.ranged_projectile_speed > 0.0:
			_peck_speed = data.ranged_projectile_speed
		if data.ranged_damage > 0:
			_peck_damage = data.ranged_damage
		if data.ranged_telegraph > 0.0:
			_peck_telegraph = data.ranged_telegraph
	hp = max_hp
	_peck_cd_timer = _peck_cd
	_dive_cd_timer = _dive_interval


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
	if _dodge_anim_remaining > 0.0:
		_dodge_anim_remaining = maxf(0.0, _dodge_anim_remaining - delta)
	if not is_instance_valid(target):
		target = _resolve_target()
		if not is_instance_valid(target):
			velocity = Vector2.ZERO
			move_and_slide()
			return
	_peck_cd_timer = maxf(0.0, _peck_cd_timer - delta)
	_dive_cd_timer = maxf(0.0, _dive_cd_timer - delta)
	match _state:
		State.CHASE:
			_run_chase(delta)
		State.PECK_TELEGRAPH:
			_run_peck_telegraph(delta)
		State.DIVE_DESCEND:
			_run_dive_descend(delta)
		State.DIVE_HOLD:
			_run_dive_hold(delta)
		State.DIVE_ASCEND:
			_run_dive_ascend(delta)
	queue_redraw()


func _run_chase(_delta: float) -> void:
	var to_t: Vector2 = target.global_position - global_position
	var d: float = to_t.length()
	if d > 0.001:
		velocity = (to_t / d) * move_speed * _slow_factor
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	# 우선순위: 강하 > 부리찌르기.
	if _dive_cd_timer <= 0.0:
		_enter_dive()
		return
	if _peck_cd_timer <= 0.0 and d <= _peck_range:
		_enter_peck()


func _enter_peck() -> void:
	_state = State.PECK_TELEGRAPH
	_state_timer = _peck_telegraph
	_aim_dir = (target.global_position - global_position).normalized()


func _run_peck_telegraph(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	# 짧은 예고 — 발사 직전 조준 갱신.
	var v: Vector2 = target.global_position - global_position
	if v.length_squared() > 0.0001:
		_aim_dir = v.normalized()
	_state_timer = maxf(0.0, _state_timer - delta)
	if _state_timer <= 0.0:
		_fire_peck()
		_state = State.CHASE
		_peck_cd_timer = _peck_cd


func _fire_peck() -> void:
	var p: EnemyProjectile = ENEMY_PROJECTILE.instantiate()
	p.speed = _peck_speed
	p.damage = _peck_damage
	p.lifetime = _peck_range / maxf(1.0, _peck_speed)
	p.direction = _aim_dir
	p.hit_radius = 5.0
	p.color = PECK_COLOR
	p.homing_target = null
	var scene: Node = get_tree().current_scene
	if scene != null:
		scene.add_child(p)
	else:
		get_parent().add_child(p)
	p.global_position = global_position + _aim_dir * (FALLBACK_W * 0.5 + 4.0)


func _enter_dive() -> void:
	_state = State.DIVE_DESCEND
	_state_timer = DIVE_DESCEND_S
	_dive_start_pos = global_position
	_dive_target_pos = target.global_position


func _run_dive_descend(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	var t: float = 1.0 - clampf(_state_timer / maxf(0.001, DIVE_DESCEND_S), 0.0, 1.0)
	global_position = _dive_start_pos.lerp(_dive_target_pos, t)
	velocity = Vector2.ZERO
	if _state_timer <= 0.0:
		_apply_dive_hit()
		_state = State.DIVE_HOLD
		_state_timer = DIVE_HOLD_S


func _apply_dive_hit() -> void:
	if not is_instance_valid(target):
		return
	var dx: float = absf(target.global_position.x - global_position.x)
	var dy: float = absf(target.global_position.y - global_position.y)
	if dx <= _dive_w * 0.5 and dy <= _dive_h * 0.5:
		if target.has_method("take_damage"):
			target.take_damage(_dive_damage)


func _run_dive_hold(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	velocity = Vector2.ZERO
	move_and_slide()
	if _state_timer <= 0.0:
		_state = State.DIVE_ASCEND
		_state_timer = DIVE_ASCEND_S


func _run_dive_ascend(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	var t: float = 1.0 - clampf(_state_timer / maxf(0.001, DIVE_ASCEND_S), 0.0, 1.0)
	global_position = _dive_target_pos.lerp(_dive_start_pos, t)
	velocity = Vector2.ZERO
	if _state_timer <= 0.0:
		_state = State.CHASE
		_dive_cd_timer = _dive_interval


func take_damage(amount: int, attacker: Object = null) -> void:
	if is_dying:
		return
	if _dodge_anim_remaining > 0.0:
		return
	if _is_ground_attack(attacker) and randf() < _ground_dodge_chance:
		_dodge_anim_remaining = DODGE_INVULN_S
		return
	super.take_damage(amount, attacker)


func _is_ground_attack(attacker: Object) -> bool:
	if attacker == null:
		return false
	var el: int = -1
	if "element" in attacker:
		el = int(attacker.element)
	elif attacker is Node and (attacker as Node).has_meta(&"element"):
		el = int((attacker as Node).get_meta(&"element"))
	if el < 0:
		return false
	return el == GameEnums.Element.EARTH


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	if _dodge_anim_remaining > 0.0:
		c = c.lerp(Color(1.0, 1.0, 1.0, 0.5), 0.5)
	# 학의 몸통(가로로 약간 긴 타원형 느낌의 사각형).
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 검은 부리.
	var beak: Color = Color(0.10, 0.10, 0.10, 1.0)
	var beak_tip: Vector2 = _aim_dir * (FALLBACK_W * 0.5 + 4.0)
	draw_line(Vector2.ZERO, beak_tip, beak, 2.0)
	# 검은 발톱.
	draw_circle(Vector2(-FALLBACK_W * 0.25, FALLBACK_H * 0.5 + 2.0), 1.2, beak)
	draw_circle(Vector2(FALLBACK_W * 0.25, FALLBACK_H * 0.5 + 2.0), 1.2, beak)
	# 강하 표시 — 강하 중에는 아래쪽으로 작은 잔상.
	if _state == State.DIVE_DESCEND or _state == State.DIVE_HOLD:
		var warn: Color = Color(1.0, 0.95, 0.85, 0.35)
		draw_rect(Rect2(Vector2(-_dive_w * 0.5, -_dive_h * 0.5), Vector2(_dive_w, _dive_h)), warn, true)
		draw_rect(Rect2(Vector2(-_dive_w * 0.5, -_dive_h * 0.5), Vector2(_dive_w, _dive_h)), Color(1.0, 0.85, 0.65, 0.6), false, 1.5)
	if _state == State.PECK_TELEGRAPH:
		var warn2: Color = Color(0.95, 0.95, 1.0, 0.55)
		draw_line(Vector2.ZERO, _aim_dir * _peck_range, warn2, 1.0)
