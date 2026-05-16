class_name FlameBreath
extends SkillBase


const DAMAGE_PER_TICK: int = 6
const TICK_INTERVAL: float = 0.25
const DURATION: float = 2.0
const CAST_RANGE: float = 220.0
const CONE_ANGLE_DEG: float = 60.0
const BURN_PER_SEC: float = 5.0
const BURN_DURATION: float = 4.0
const CONE_COLOR_INNER: Color = Color(0.98, 0.78, 0.30, 0.55)
const CONE_COLOR_OUTER: Color = Color(0.95, 0.40, 0.10, 0.25)


enum State { IDLE, SPRAYING }


var _state: int = State.IDLE
var _spray_time: float = 0.0
var _tick_acc: float = 0.0
var _dir: Vector2 = Vector2.RIGHT


func _ready() -> void:
	cooldown = 9.0
	super._ready()


func _cast() -> void:
	var aim: Vector2 = _resolve_direction()
	if aim == Vector2.ZERO:
		return
	_dir = aim
	_state = State.SPRAYING
	_spray_time = 0.0
	_tick_acc = 0.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _state != State.SPRAYING:
		return
	_spray_time += delta
	_tick_acc += delta
	if _tick_acc >= TICK_INTERVAL:
		_tick_acc -= TICK_INTERVAL
		_apply_cone_damage()
	if _spray_time >= DURATION:
		_state = State.IDLE
	queue_redraw()


func _resolve_direction() -> Vector2:
	if is_instance_valid(player):
		if player.has_method("get_facing_dir"):
			var d: Variant = player.get_facing_dir()
			if d is Vector2 and (d as Vector2).length() > 0.01:
				return (d as Vector2).normalized()
		var last_dir: Variant = player.get("last_move_dir") if player.get("last_move_dir") != null else null
		if last_dir is Vector2 and (last_dir as Vector2).length() > 0.01:
			return (last_dir as Vector2).normalized()
	var nearest: Node2D = _find_nearest_enemy()
	if is_instance_valid(nearest):
		var v: Vector2 = nearest.global_position - global_position
		if v.length() > 0.01:
			return v.normalized()
	return Vector2.RIGHT


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var min_d2: float = INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node2D):
			continue
		var d2: float = (e.global_position - global_position).length_squared()
		if d2 < min_d2:
			min_d2 = d2
			nearest = e
	return nearest


func _apply_cone_damage() -> void:
	var dmg: int = int(round(float(DAMAGE_PER_TICK) * damage_multiplier))
	var half_rad: float = deg_to_rad(CONE_ANGLE_DEG * 0.5)
	var range2: float = CAST_RANGE * CAST_RANGE
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node2D):
			continue
		var to_e: Vector2 = e.global_position - global_position
		if to_e.length_squared() > range2:
			continue
		if to_e.length() < 0.01:
			continue
		var ang: float = abs(_dir.angle_to(to_e))
		if ang > half_rad:
			continue
		if e.has_method("take_damage"):
			e.take_damage(dmg)
			hit_enemy.emit(e, dmg)
		_apply_burn(e)


func _apply_burn(target: Node) -> void:
	if not is_instance_valid(target):
		return
	if target.has_method("apply_burn"):
		target.apply_burn(BURN_PER_SEC, BURN_DURATION)
	elif target.has_method("apply_dot"):
		target.apply_dot(&"burn", BURN_PER_SEC, BURN_DURATION)
	elif target.has_method("apply_slow"):
		target.apply_slow(0.85, 0.3)


func _draw() -> void:
	if _state != State.SPRAYING:
		return
	var half_rad: float = deg_to_rad(CONE_ANGLE_DEG * 0.5)
	var base_ang: float = _dir.angle()
	var t: float = clamp(_spray_time / DURATION, 0.0, 1.0)
	var reach: float = CAST_RANGE * (0.85 + 0.15 * sin(t * TAU * 4.0))
	var pts: PackedVector2Array = PackedVector2Array()
	pts.push_back(Vector2.ZERO)
	var segs: int = 18
	for i in range(segs + 1):
		var a: float = base_ang - half_rad + (2.0 * half_rad) * float(i) / float(segs)
		pts.push_back(Vector2(cos(a), sin(a)) * reach)
	var col_a: PackedColorArray = PackedColorArray()
	col_a.push_back(CONE_COLOR_INNER)
	for i in range(segs + 1):
		col_a.push_back(CONE_COLOR_OUTER)
	draw_polygon(pts, col_a)
