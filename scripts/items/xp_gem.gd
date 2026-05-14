class_name ExpGem
extends Area2D

# §8.1 — exp_gem.gd 이전. EventBus.xp_collected는 Player가 발신(이중 카운트 방지).

@export var value: int = 1
@export var tier: int = 0  # 0=소, 1=중, 2=대


var target: Node2D = null
var attract_speed: float = 400.0
var attract_radius: float = 60.0


func _ready() -> void:
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		var player: Node = get_tree().get_first_node_in_group("player")
		if player and player is Node2D:
			var p2d: Node2D = player as Node2D
			if global_position.distance_to(p2d.global_position) < attract_radius:
				target = p2d
	if is_instance_valid(target):
		var dir: Vector2 = (target.global_position - global_position).normalized()
		global_position += dir * attract_speed * delta


func set_value(v: int) -> void:
	value = v
	if v >= 5:
		tier = 2
	elif v >= 2:
		tier = 1
	else:
		tier = 0
	queue_redraw()


func get_value() -> int:
	return value


func collect() -> void:
	queue_free()


func _draw() -> void:
	var s: float = 4.0
	match tier:
		0:
			s = 4.0
		1:
			s = 6.0
		2:
			s = 9.0
	var color: Color = Color("#E0C23C")
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -s),
		Vector2(s, 0.0),
		Vector2(0.0, s),
		Vector2(-s, 0.0),
	])
	draw_colored_polygon(pts, color)
