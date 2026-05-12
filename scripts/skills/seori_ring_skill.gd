extends Area2D

@export var aura_radius: float = 90.0
@export var tick_damage: int = 2
@export var tick_interval: float = 0.2
@export var slow_factor: float = 0.25
@export var slow_duration: float = 1.5

var _tick_acc: float = 0.0


func _ready() -> void:
	collision_layer = 16
	collision_mask = 2
	var shape := $CollisionShape2D as CollisionShape2D
	if shape and shape.shape is CircleShape2D:
		(shape.shape as CircleShape2D).radius = aura_radius
	var visual := get_node_or_null("Visual") as ColorRect
	if visual:
		visual.offset_left = -aura_radius
		visual.offset_top = -aura_radius
		visual.offset_right = aura_radius
		visual.offset_bottom = aura_radius


func _process(delta: float) -> void:
	_tick_acc += delta
	if _tick_acc < tick_interval:
		return
	while _tick_acc >= tick_interval:
		_tick_acc -= tick_interval
	for body in get_overlapping_bodies():
		if not is_instance_valid(body):
			continue
		if body.has_method("take_damage"):
			body.take_damage(tick_damage)
		if body.has_method("apply_slow"):
			body.apply_slow(slow_factor, slow_duration)
