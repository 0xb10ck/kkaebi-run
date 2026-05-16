extends EnemyBase

# M14 두꺼비 요괴 — 점프 이동(0.6s 포물선) → 착지 시 반경 60px AOE → 1.5초 정지 반복.
# 점프 중 무적. 별도 쿨다운(2.5s)으로 직선 독액 투사체 발사, 명중 시 3초간 1초당 1 도트 데미지.

const ENEMY_PROJECTILE: PackedScene = preload("res://scenes/enemies/enemy_projectile.tscn")

const DEFAULT_JUMP_DURATION_S: float = 0.6
const DEFAULT_JUMP_PAUSE_S: float = 1.5
const DEFAULT_LANDING_AOE_RADIUS_PX: float = 60.0
const DEFAULT_JUMP_ARC_HEIGHT_PX: float = 40.0
const DEFAULT_POISON_DOT_PER_SEC: int = 1
const DEFAULT_POISON_DURATION_S: float = 3.0
const DEFAULT_RANGED_COOLDOWN_S: float = 2.5

const ACID_COLOR: Color = Color(0.55, 0.85, 0.30, 1.0)

const FALLBACK_COLOR: Color = Color(0.55, 0.40, 0.20, 1.0)
const FALLBACK_W: float = 18.0
const FALLBACK_H: float = 12.0

enum State { IDLE, JUMP }

var _jump_duration: float = DEFAULT_JUMP_DURATION_S
var _jump_pause: float = DEFAULT_JUMP_PAUSE_S
var _landing_radius: float = DEFAULT_LANDING_AOE_RADIUS_PX
var _arc_height: float = DEFAULT_JUMP_ARC_HEIGHT_PX
var _poison_per_sec: int = DEFAULT_POISON_DOT_PER_SEC
var _poison_duration: float = DEFAULT_POISON_DURATION_S
var _ranged_cooldown: float = DEFAULT_RANGED_COOLDOWN_S
var _ranged_range: float = 240.0
var _ranged_speed: float = 200.0
var _ranged_damage: int = 6
var _ranged_telegraph: float = 0.2

var _state: int = State.IDLE
var _state_timer: float = 0.0
var _jump_t: float = 0.0
var _jump_from: Vector2 = Vector2.ZERO
var _jump_to: Vector2 = Vector2.ZERO
var _jump_visual_offset: float = 0.0

var _ranged_cd_timer: float = 0.0
var _ranged_telegraph_timer: float = 0.0
var _is_ranged_telegraphing: bool = false

var _dot_remaining: float = 0.0
var _dot_tick_timer: float = 0.0

var _invuln: bool = false


func _ready() -> void:
	if data == null:
		max_hp = 32
		move_speed = 0.0
		contact_damage = 7
		exp_drop_value = 8
		coin_drop_value = 1
		coin_drop_chance = 0.22
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("jump_duration_s"):
			_jump_duration = float(params["jump_duration_s"])
		if params.has("jump_pause_s"):
			_jump_pause = float(params["jump_pause_s"])
		if params.has("landing_aoe_radius_px"):
			_landing_radius = float(params["landing_aoe_radius_px"])
		if params.has("jump_arc_height_px"):
			_arc_height = float(params["jump_arc_height_px"])
		if params.has("poison_dot_per_sec"):
			_poison_per_sec = int(params["poison_dot_per_sec"])
		if params.has("poison_duration_s"):
			_poison_duration = float(params["poison_duration_s"])
		if data.ranged_cooldown > 0.0:
			_ranged_cooldown = data.ranged_cooldown
		if data.ranged_range_px > 0.0:
			_ranged_range = data.ranged_range_px
		if data.ranged_projectile_speed > 0.0:
			_ranged_speed = data.ranged_projectile_speed
		if data.ranged_damage > 0:
			_ranged_damage = data.ranged_damage
		if data.ranged_telegraph > 0.0:
			_ranged_telegraph = data.ranged_telegraph
	_state = State.IDLE
	_state_timer = _jump_pause
	_ranged_cd_timer = _ranged_cooldown
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_tick_poison_dot(delta)
	_tick_ranged(delta)
	match _state:
		State.IDLE:
			_run_idle(delta)
		State.JUMP:
			_run_jump(delta)
	queue_redraw()


func _run_idle(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	velocity = Vector2.ZERO
	move_and_slide()
	if _contact_timer > 0.0:
		_contact_timer = maxf(0.0, _contact_timer - delta)
	# 정지 중에도 플레이어가 겹치면 접촉 데미지.
	if _contact_timer <= 0.0 and _contact_area:
		for body in _contact_area.get_overlapping_bodies():
			if body == target:
				_deal_contact_damage()
				break
	if _state_timer <= 0.0 and is_instance_valid(target):
		_start_jump()


func _start_jump() -> void:
	_state = State.JUMP
	_state_timer = _jump_duration
	_jump_t = 0.0
	_jump_from = global_position
	_jump_to = target.global_position
	_invuln = true


func _run_jump(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	_jump_t = clampf(1.0 - (_state_timer / maxf(0.001, _jump_duration)), 0.0, 1.0)
	var pos: Vector2 = _jump_from.lerp(_jump_to, _jump_t)
	_jump_visual_offset = -sin(PI * _jump_t) * _arc_height
	global_position = pos
	if _state_timer <= 0.0:
		_land()


func _land() -> void:
	global_position = _jump_to
	_invuln = false
	_state = State.IDLE
	_state_timer = _jump_pause
	_jump_visual_offset = 0.0
	# 착지 AOE.
	if is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= _landing_radius:
			if target.has_method("take_damage"):
				target.take_damage(contact_damage)


func _tick_ranged(delta: float) -> void:
	if _is_ranged_telegraphing:
		_ranged_telegraph_timer = maxf(0.0, _ranged_telegraph_timer - delta)
		if _ranged_telegraph_timer <= 0.0:
			_is_ranged_telegraphing = false
			_fire_acid_spit()
			_ranged_cd_timer = _ranged_cooldown
		return
	_ranged_cd_timer = maxf(0.0, _ranged_cd_timer - delta)
	if _ranged_cd_timer <= 0.0 and is_instance_valid(target):
		var d: float = global_position.distance_to(target.global_position)
		if d <= _ranged_range:
			_is_ranged_telegraphing = true
			_ranged_telegraph_timer = _ranged_telegraph


func _fire_acid_spit() -> void:
	if not is_instance_valid(target):
		return
	var p: EnemyProjectile = ENEMY_PROJECTILE.instantiate()
	p.speed = _ranged_speed
	p.damage = _ranged_damage
	p.lifetime = _ranged_range / maxf(1.0, _ranged_speed)
	p.direction = (target.global_position - global_position).normalized()
	p.hit_radius = 6.0
	p.color = ACID_COLOR
	p.body_entered.connect(_on_acid_projectile_hit)
	var scene: Node = get_tree().current_scene
	if scene != null:
		scene.add_child(p)
	else:
		get_parent().add_child(p)
	p.global_position = global_position


func _on_acid_projectile_hit(body: Node) -> void:
	if body == null:
		return
	if not body.is_in_group("player"):
		return
	_start_poison_dot()


func _start_poison_dot() -> void:
	_dot_remaining = _poison_duration
	_dot_tick_timer = 1.0


func _tick_poison_dot(delta: float) -> void:
	if _dot_remaining <= 0.0:
		return
	_dot_remaining = maxf(0.0, _dot_remaining - delta)
	_dot_tick_timer = maxf(0.0, _dot_tick_timer - delta)
	if _dot_tick_timer <= 0.0:
		_dot_tick_timer = 1.0
		if is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(_poison_per_sec)


func take_damage(amount: int, attacker: Object = null) -> void:
	if _invuln:
		return
	super.take_damage(amount, attacker)


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	var draw_pos: Vector2 = Vector2(0.0, _jump_visual_offset)
	draw_rect(Rect2(draw_pos - Vector2(FALLBACK_W * 0.5, FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 등의 노란 점.
	draw_circle(draw_pos + Vector2(-FALLBACK_W * 0.2, -FALLBACK_H * 0.15), 2.0, Color(0.95, 0.85, 0.2, 1.0))
	draw_circle(draw_pos + Vector2(FALLBACK_W * 0.2, -FALLBACK_H * 0.15), 2.0, Color(0.95, 0.85, 0.2, 1.0))
	if _state == State.JUMP:
		# 그림자.
		draw_ellipse_outline(Vector2.ZERO, FALLBACK_W * 0.4, FALLBACK_H * 0.25, Color(0, 0, 0, 0.3))
	if _is_ranged_telegraphing:
		draw_circle(draw_pos + Vector2(0, -FALLBACK_H * 0.5), 3.0, Color(0.6, 0.95, 0.3, 0.8))


func draw_ellipse_outline(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var seg: int = 24
	for i in seg:
		var a: float = TAU * float(i) / float(seg)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	pts.append(pts[0])
	for i in pts.size() - 1:
		draw_line(pts[i], pts[i + 1], col, 1.5)
