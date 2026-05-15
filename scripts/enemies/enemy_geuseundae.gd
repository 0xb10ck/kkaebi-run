extends EnemyBase

# M05 그슨대 — 250px 미만이면 0.5초마다 세로 길이 +6px(최대 64).
# 길이 48 이상이면 enemy_projectile.tscn 직선 투사체로 머리 내려치기(쿨다운 2.0s).

const ENEMY_PROJECTILE: PackedScene = preload("res://scenes/enemies/enemy_projectile.tscn")

const DEFAULT_TRIGGER_PX: float = 250.0
const DEFAULT_STEP_PX: float = 6.0
const DEFAULT_STEP_INTERVAL_S: float = 0.5
const DEFAULT_MAX_LENGTH_PX: float = 64.0
const DEFAULT_RANGED_ACTIVATE_LENGTH_PX: float = 48.0
const DEFAULT_RANGED_COOLDOWN_S: float = 2.0
const DEFAULT_PROJECTILE_SPEED: float = 220.0
const STRIKE_COLOR: Color = Color(0.95, 0.95, 0.90, 1.0)

const FALLBACK_COLOR: Color = Color(0.70, 0.70, 0.65, 1.0)
const FALLBACK_WIDTH: float = 16.0
const BASE_HEIGHT: float = 24.0

var _trigger_px: float = DEFAULT_TRIGGER_PX
var _step_px: float = DEFAULT_STEP_PX
var _step_interval: float = DEFAULT_STEP_INTERVAL_S
var _max_length: float = DEFAULT_MAX_LENGTH_PX
var _ranged_activate_length: float = DEFAULT_RANGED_ACTIVATE_LENGTH_PX
var _ranged_cooldown: float = DEFAULT_RANGED_COOLDOWN_S
var _ranged_damage: int = 5
var _ranged_speed: float = DEFAULT_PROJECTILE_SPEED

var _current_length: float = BASE_HEIGHT
var _step_timer: float = 0.0
var _attack_cd_timer: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 16
		move_speed = 55.0
		contact_damage = 4
		exp_drop_value = 3
		coin_drop_value = 1
		coin_drop_chance = 0.10
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("stretch_trigger_distance_px"):
			_trigger_px = float(params["stretch_trigger_distance_px"])
		if params.has("stretch_step_px"):
			_step_px = float(params["stretch_step_px"])
		if params.has("stretch_step_interval_s"):
			_step_interval = float(params["stretch_step_interval_s"])
		if params.has("max_length_px"):
			_max_length = float(params["max_length_px"])
		if params.has("ranged_activate_length_px"):
			_ranged_activate_length = float(params["ranged_activate_length_px"])
		if data.ranged_cooldown > 0.0:
			_ranged_cooldown = data.ranged_cooldown
		if data.ranged_damage > 0:
			_ranged_damage = data.ranged_damage
		if data.ranged_projectile_speed > 0.0:
			_ranged_speed = data.ranged_projectile_speed
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_step_timer = maxf(0.0, _step_timer - delta)
	_attack_cd_timer = maxf(0.0, _attack_cd_timer - delta)
	if is_instance_valid(target):
		var dist: float = global_position.distance_to(target.global_position)
		if dist < _trigger_px:
			if _step_timer <= 0.0:
				_step_timer = _step_interval
				_current_length = minf(_max_length, _current_length + _step_px)
				queue_redraw()
				if _current_length >= _ranged_activate_length and _attack_cd_timer <= 0.0:
					_fire_head_strike()
		else:
			# 거리가 멀어지면 신장이 천천히 원상복구.
			if _current_length > BASE_HEIGHT:
				_current_length = maxf(BASE_HEIGHT, _current_length - _step_px * delta / maxf(0.01, _step_interval))
				queue_redraw()
	super._physics_process(delta)


func _fire_head_strike() -> void:
	if not is_instance_valid(target):
		return
	_attack_cd_timer = _ranged_cooldown
	var p: EnemyProjectile = ENEMY_PROJECTILE.instantiate()
	p.speed = _ranged_speed
	p.damage = _ranged_damage
	var range_px: float = _current_length * 2.0
	p.lifetime = range_px / maxf(1.0, _ranged_speed)
	p.direction = (target.global_position - global_position).normalized()
	p.hit_radius = 6.0
	p.color = STRIKE_COLOR
	var scene: Node = get_tree().current_scene
	if scene != null:
		scene.add_child(p)
	else:
		get_parent().add_child(p)
	# 머리 끝 위치(스프라이트 상단)에서 발사.
	p.global_position = global_position + Vector2(0, -_current_length)


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	var half_w: float = FALLBACK_WIDTH * 0.5
	# 머리는 위쪽으로 신장. (0,0) = 발 위치 기준.
	draw_rect(Rect2(Vector2(-half_w, -_current_length), Vector2(FALLBACK_WIDTH, _current_length)), c)
