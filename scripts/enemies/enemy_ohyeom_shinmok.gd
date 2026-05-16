extends EnemyBase

# M45 오염된 신목 가지 — 완전 고정(이속 0), 맵 지정 위치 스폰.
# 사거리 whip_range_px(280) 안에 플레이어가 있으면 whip_cooldown_s(2.5s)마다
# 직선 가지 채찍(whip_damage 16) 단발 발사. enemy_projectile 재사용.
# 사거리 안 누적 black_seed_dwell_required_s(8.0s) 채워지면 3방향(-45/0/+45) 검은 씨앗
# 산탄 발사(각 black_seed_damage 8). 산탄 발동 후 누적 카운터 리셋.

const ENEMY_PROJECTILE: PackedScene = preload("res://scenes/enemies/enemy_projectile.tscn")

const DEFAULT_WHIP_RANGE_PX: float = 280.0
const DEFAULT_WHIP_DAMAGE: int = 16
const DEFAULT_WHIP_COOLDOWN_S: float = 2.5
const DEFAULT_WHIP_SPEED_PX: float = 300.0
const DEFAULT_BLACK_SEED_DWELL_S: float = 8.0
const DEFAULT_BLACK_SEED_COUNT: int = 3
const DEFAULT_BLACK_SEED_DAMAGE: int = 8
const DEFAULT_BLACK_SEED_SPEED_PX: float = 180.0

const FALLBACK_COLOR: Color = Color(0.18, 0.10, 0.22, 1.0)
const FALLBACK_W: float = 16.0
const FALLBACK_H: float = 28.0
const BUD_COLOR: Color = Color(0.95, 0.25, 0.20, 1.0)
const WHIP_COLOR: Color = Color(0.40, 0.25, 0.45, 0.95)
const SEED_COLOR: Color = Color(0.10, 0.05, 0.10, 0.95)

var _whip_range: float = DEFAULT_WHIP_RANGE_PX
var _whip_damage: int = DEFAULT_WHIP_DAMAGE
var _whip_cooldown: float = DEFAULT_WHIP_COOLDOWN_S
var _whip_speed: float = DEFAULT_WHIP_SPEED_PX
var _seed_dwell_required: float = DEFAULT_BLACK_SEED_DWELL_S
var _seed_count: int = DEFAULT_BLACK_SEED_COUNT
var _seed_damage: int = DEFAULT_BLACK_SEED_DAMAGE
var _seed_speed: float = DEFAULT_BLACK_SEED_SPEED_PX
var _seed_angles_deg: Array = [-45.0, 0.0, 45.0]

var _whip_cd_timer: float = 0.0
var _seed_dwell_accum: float = 0.0
var _whip_flash: float = 0.0
var _seed_flash: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 80
		move_speed = 0.0
		contact_damage = 0
		exp_drop_value = 24
		coin_drop_value = 1
		coin_drop_chance = 0.38
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("whip_range_px"):
			_whip_range = float(params["whip_range_px"])
		if params.has("whip_damage"):
			_whip_damage = int(params["whip_damage"])
		if params.has("whip_cooldown_s"):
			_whip_cooldown = float(params["whip_cooldown_s"])
		if params.has("black_seed_dwell_required_s"):
			_seed_dwell_required = float(params["black_seed_dwell_required_s"])
		if params.has("black_seed_count"):
			_seed_count = int(params["black_seed_count"])
		if params.has("black_seed_damage"):
			_seed_damage = int(params["black_seed_damage"])
		if params.has("black_seed_projectile_speed"):
			_seed_speed = float(params["black_seed_projectile_speed"])
		if params.has("black_seed_angles_deg"):
			_seed_angles_deg = params["black_seed_angles_deg"]
		if data.ranged_range_px > 0.0:
			_whip_range = data.ranged_range_px
		if data.ranged_damage > 0:
			_whip_damage = data.ranged_damage
		if data.ranged_cooldown > 0.0:
			_whip_cooldown = data.ranged_cooldown
	# 완전 고정.
	move_speed = 0.0
	contact_damage = 0
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	# 기본 베이스의 추적/접촉 처리를 사용하지 않는다 — 고정형. 슬로우/스턴 처리만 직접 갱신.
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
	velocity = Vector2.ZERO
	move_and_slide()
	if not is_instance_valid(target):
		target = _resolve_target()
		if not is_instance_valid(target):
			queue_redraw()
			return
	_whip_cd_timer = maxf(0.0, _whip_cd_timer - delta)
	if _whip_flash > 0.0:
		_whip_flash = maxf(0.0, _whip_flash - delta)
	if _seed_flash > 0.0:
		_seed_flash = maxf(0.0, _seed_flash - delta)
	var d: float = global_position.distance_to(target.global_position)
	var in_range: bool = d <= _whip_range
	if in_range:
		_seed_dwell_accum += delta
		if _whip_cd_timer <= 0.0:
			_fire_whip()
			_whip_cd_timer = _whip_cooldown
	# 누적 시간 도달 시 산탄. 사거리 밖이어도 발동 직후 리셋.
	if _seed_dwell_accum >= _seed_dwell_required:
		_fire_black_seeds()
		_seed_dwell_accum = 0.0
	queue_redraw()


func _fire_whip() -> void:
	if not is_instance_valid(target):
		return
	var dir: Vector2 = (target.global_position - global_position)
	if dir.length_squared() <= 0.0001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	var p: EnemyProjectile = ENEMY_PROJECTILE.instantiate()
	p.speed = _whip_speed
	p.damage = _whip_damage
	p.lifetime = _whip_range / maxf(1.0, _whip_speed)
	p.direction = dir
	p.hit_radius = 7.0
	p.color = WHIP_COLOR
	_spawn_into_scene(p)
	_whip_flash = 0.20


func _fire_black_seeds() -> void:
	if not is_instance_valid(target):
		return
	var forward: Vector2 = (target.global_position - global_position)
	if forward.length_squared() <= 0.0001:
		forward = Vector2.DOWN
	else:
		forward = forward.normalized()
	var angles: Array = _seed_angles_deg
	if angles == null or angles.is_empty():
		angles = [-45.0, 0.0, 45.0]
	var count: int = mini(_seed_count, angles.size())
	for i in count:
		var deg: float = float(angles[i])
		var dir: Vector2 = forward.rotated(deg_to_rad(deg))
		var p: EnemyProjectile = ENEMY_PROJECTILE.instantiate()
		p.speed = _seed_speed
		p.damage = _seed_damage
		p.lifetime = _whip_range / maxf(1.0, _seed_speed)
		p.direction = dir
		p.hit_radius = 6.0
		p.color = SEED_COLOR
		_spawn_into_scene(p)
	_seed_flash = 0.35


func _spawn_into_scene(p: EnemyProjectile) -> void:
	var scene: Node = get_tree().current_scene
	if scene != null:
		scene.add_child(p)
	else:
		get_parent().add_child(p)
	p.global_position = global_position


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	if _whip_flash > 0.0:
		c = c.lerp(WHIP_COLOR, 0.30)
	# 비틀어진 가지 — 세로로 긴 본체.
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 끝의 빨간 봉오리.
	var bud_color: Color = BUD_COLOR
	if _seed_flash > 0.0:
		bud_color = bud_color.lerp(Color(0.10, 0.05, 0.10, 1.0), 0.5)
	draw_circle(Vector2(0.0, -FALLBACK_H * 0.5 - 2.0), 3.0, bud_color)
	# 잎사귀 가시.
	var thorn: Color = Color(0.30, 0.55, 0.30, 1.0)
	draw_line(Vector2(-FALLBACK_W * 0.5, 0.0), Vector2(-FALLBACK_W * 0.5 - 4.0, -2.0), thorn, 1.0)
	draw_line(Vector2(FALLBACK_W * 0.5, 2.0), Vector2(FALLBACK_W * 0.5 + 4.0, 0.0), thorn, 1.0)
	# 누적 게이지 — 봉오리 아래 작은 막대로 표시.
	var prog: float = clampf(_seed_dwell_accum / maxf(0.001, _seed_dwell_required), 0.0, 1.0)
	if prog > 0.0:
		var bar_w: float = FALLBACK_W * prog
		draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5 - 6.0), Vector2(bar_w, 1.5)), Color(0.95, 0.30, 0.20, 0.85))
	# 사거리 외곽 점선(약하게).
	var rng_col: Color = Color(0.50, 0.30, 0.55, 0.18)
	draw_arc(Vector2.ZERO, _whip_range, 0.0, TAU, 48, rng_col, 1.0)
	if _whip_flash > 0.0:
		var glow: Color = Color(0.60, 0.40, 0.70, 0.40 * (_whip_flash / 0.20))
		draw_arc(Vector2.ZERO, FALLBACK_W * 0.9, 0.0, TAU, 20, glow, 1.5)
