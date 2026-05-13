class_name VineWhip
extends SkillBase


const DAMAGE: int = 25
const LINE_DURATION: float = 0.2
const LINE_COLOR: Color = Color("#4CAF50")
const LINE_WIDTH: float = 4.0


func _ready() -> void:
	cooldown = 1.5
	super._ready()


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
	var line: Line2D = Line2D.new()
	line.top_level = true
	line.width = LINE_WIDTH
	line.default_color = LINE_COLOR
	line.add_point(from)
	line.add_point(to)
	add_child(line)
	var timer: SceneTreeTimer = get_tree().create_timer(LINE_DURATION)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(line):
			line.queue_free()
	)
