extends Node2D

@export var max_range: float = 220.0
@export var damage: int = 14
@export var cooldown: float = 1.0

var _cd: float = 0.0
var _line: Line2D = null
var _line_lifetime: float = 0.0


func _ready() -> void:
	_line = Line2D.new()
	_line.width = 6.0
	_line.default_color = Palette.WOOD_GREEN
	_line.visible = false
	add_child(_line)


func _process(delta: float) -> void:
	if _line_lifetime > 0.0:
		_line_lifetime -= delta
		if _line_lifetime <= 0.0:
			_line.visible = false
	_cd -= delta
	if _cd > 0.0:
		return
	var target := _find_nearest_enemy()
	if target == null:
		return
	_cd = cooldown
	if target.has_method("take_damage"):
		target.take_damage(damage)
	var local_target := to_local(target.global_position)
	_line.clear_points()
	_line.add_point(Vector2.ZERO)
	_line.add_point(local_target)
	_line.visible = true
	_line_lifetime = 0.15


func _find_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var min_dsq := max_range * max_range
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e.has_method("is_dying") and e.is_dying():
			continue
		var d: float = e.global_position.distance_squared_to(global_position)
		if d < min_dsq:
			min_dsq = d
			nearest = e
	return nearest
