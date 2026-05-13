class_name VineWhip
extends SkillBase


const DAMAGE: int = 25
const LINE_DURATION: float = 0.2
const LINE_COLOR: Color = Color("#4CAF50")
const LINE_WIDTH: float = 4.0


var _active_lines: Array = []


func _ready() -> void:
	cooldown = 1.5
	super._ready()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _active_lines.is_empty():
		return
	for line in _active_lines:
		line.time_left -= delta
	_active_lines = _active_lines.filter(func(l): return l.time_left > 0.0)
	queue_redraw()


func _draw() -> void:
	for line in _active_lines:
		var local_from: Vector2 = to_local(line.from)
		var local_to: Vector2 = to_local(line.to)
		draw_line(local_from, local_to, LINE_COLOR, LINE_WIDTH)


func _cast() -> void:
	var target: Node2D = _find_nearest_enemy()
	if not is_instance_valid(target):
		return
	var dmg: int = int(round(float(DAMAGE) * damage_multiplier))
	if target.has_method("take_damage"):
		target.take_damage(dmg)
		hit_enemy.emit(target, dmg)
	_spawn_line(global_position, target.global_position)


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


func _spawn_line(from: Vector2, to: Vector2) -> void:
	_active_lines.append({"from": from, "to": to, "time_left": LINE_DURATION})
	queue_redraw()
