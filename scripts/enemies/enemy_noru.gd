extends EnemyBase

# M16 노루귀신 — 회피형. 플레이어 ≤150px이면 도주(이속 ×1.4) + 1.8s 쿨다운마다 뿔 투사체 후방 발사.
# 사거리 280px. 거리 ≥300px이면 추적 재개. 150~300px 구간은 기존 상태 유지(히스테리시스).

const ENEMY_PROJECTILE: PackedScene = preload("res://scenes/enemies/enemy_projectile.tscn")

const DEFAULT_FLEE_TRIGGER_PX: float = 150.0
const DEFAULT_FLEE_RESUME_PX: float = 300.0
const DEFAULT_FLEE_SPEED_MULT: float = 1.4
const DEFAULT_HORN_COOLDOWN_S: float = 1.8
const DEFAULT_HORN_RANGE_PX: float = 280.0
const DEFAULT_HORN_SPEED_PX: float = 180.0
const DEFAULT_HORN_DAMAGE: int = 7
const DEFAULT_HORN_TELEGRAPH_S: float = 0.15

const HORN_COLOR: Color = Color(0.85, 0.75, 0.55, 1.0)
const FALLBACK_COLOR: Color = Color(0.65, 0.55, 0.40, 1.0)
const FALLBACK_W: float = 16.0
const FALLBACK_H: float = 22.0

enum State { CHASE, FLEE }

var _flee_trigger_px: float = DEFAULT_FLEE_TRIGGER_PX
var _flee_resume_px: float = DEFAULT_FLEE_RESUME_PX
var _flee_speed_mult: float = DEFAULT_FLEE_SPEED_MULT
var _horn_cooldown: float = DEFAULT_HORN_COOLDOWN_S
var _horn_range: float = DEFAULT_HORN_RANGE_PX
var _horn_speed: float = DEFAULT_HORN_SPEED_PX
var _horn_damage: int = DEFAULT_HORN_DAMAGE
var _horn_telegraph: float = DEFAULT_HORN_TELEGRAPH_S

var _state: int = State.CHASE
var _horn_cd_timer: float = 0.0
var _horn_telegraph_timer: float = 0.0
var _is_horn_telegraphing: bool = false
var _last_flee_dir: Vector2 = Vector2.RIGHT


func _ready() -> void:
	if data == null:
		max_hp = 22
		move_speed = 80.0
		contact_damage = 5
		exp_drop_value = 7
		coin_drop_value = 1
		coin_drop_chance = 0.20
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("flee_trigger_distance_px"):
			_flee_trigger_px = float(params["flee_trigger_distance_px"])
		if params.has("flee_resume_distance_px"):
			_flee_resume_px = float(params["flee_resume_distance_px"])
		if params.has("flee_speed_mult"):
			_flee_speed_mult = float(params["flee_speed_mult"])
		if data.ranged_cooldown > 0.0:
			_horn_cooldown = data.ranged_cooldown
		if data.ranged_range_px > 0.0:
			_horn_range = data.ranged_range_px
		if data.ranged_projectile_speed > 0.0:
			_horn_speed = data.ranged_projectile_speed
		if data.ranged_damage > 0:
			_horn_damage = data.ranged_damage
		if data.ranged_telegraph > 0.0:
			_horn_telegraph = data.ranged_telegraph
	_horn_cd_timer = _horn_cooldown
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_update_state()
	match _state:
		State.CHASE:
			super._physics_process(delta)
		State.FLEE:
			_run_flee(delta)
	_tick_horn(delta)
	queue_redraw()


func _update_state() -> void:
	if not is_instance_valid(target):
		return
	var d: float = global_position.distance_to(target.global_position)
	if _state == State.CHASE and d <= _flee_trigger_px:
		_state = State.FLEE
	elif _state == State.FLEE and d >= _flee_resume_px:
		_state = State.CHASE


func _run_flee(delta: float) -> void:
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
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var away: Vector2 = global_position - target.global_position
	if away.length_squared() < 0.001:
		away = Vector2.RIGHT
	var dir: Vector2 = away.normalized()
	_last_flee_dir = dir
	velocity = dir * move_speed * _flee_speed_mult * _slow_factor
	move_and_slide()
	if _contact_timer <= 0.0 and _contact_area:
		for body in _contact_area.get_overlapping_bodies():
			if body == target:
				_deal_contact_damage()
				break


func _tick_horn(delta: float) -> void:
	if _state != State.FLEE:
		return
	if _is_horn_telegraphing:
		_horn_telegraph_timer = maxf(0.0, _horn_telegraph_timer - delta)
		if _horn_telegraph_timer <= 0.0:
			_is_horn_telegraphing = false
			_fire_horn()
			_horn_cd_timer = _horn_cooldown
		return
	_horn_cd_timer = maxf(0.0, _horn_cd_timer - delta)
	if _horn_cd_timer <= 0.0 and is_instance_valid(target):
		_is_horn_telegraphing = true
		_horn_telegraph_timer = _horn_telegraph


func _fire_horn() -> void:
	if not is_instance_valid(target):
		return
	# 후방 발사 — 자신의 진행 방향 반대(= 플레이어 쪽).
	var to_player: Vector2 = target.global_position - global_position
	if to_player.length_squared() < 0.001:
		to_player = -_last_flee_dir
	var dir_n: Vector2 = to_player.normalized()
	var p: EnemyProjectile = ENEMY_PROJECTILE.instantiate()
	p.speed = _horn_speed
	p.damage = _horn_damage
	p.direction = dir_n
	p.lifetime = _horn_range / maxf(1.0, _horn_speed)
	p.hit_radius = 6.0
	p.color = HORN_COLOR
	var scene: Node = get_tree().current_scene
	if scene != null:
		scene.add_child(p)
	else:
		get_parent().add_child(p)
	p.global_position = global_position


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 텅 빈 흰 눈.
	draw_circle(Vector2(-FALLBACK_W * 0.25, -FALLBACK_H * 0.2), 1.6, Color(0.95, 0.95, 0.95, 1.0))
	draw_circle(Vector2(FALLBACK_W * 0.25, -FALLBACK_H * 0.2), 1.6, Color(0.95, 0.95, 0.95, 1.0))
	# 뿔(머리 위로 두 개).
	var horn: Color = Color(0.85, 0.75, 0.55, 1.0)
	draw_line(Vector2(-FALLBACK_W * 0.2, -FALLBACK_H * 0.5), Vector2(-FALLBACK_W * 0.3, -FALLBACK_H * 0.5 - 6.0), horn, 1.5)
	draw_line(Vector2(FALLBACK_W * 0.2, -FALLBACK_H * 0.5), Vector2(FALLBACK_W * 0.3, -FALLBACK_H * 0.5 - 6.0), horn, 1.5)
	if _state == State.FLEE:
		draw_line(Vector2.ZERO, _last_flee_dir * (FALLBACK_W * 0.7), Color(1.0, 0.9, 0.6, 0.6), 1.5)
	if _is_horn_telegraphing:
		draw_arc(Vector2.ZERO, FALLBACK_W * 0.6, 0.0, TAU, 24, Color(1.0, 0.9, 0.6, 0.8), 1.5)
