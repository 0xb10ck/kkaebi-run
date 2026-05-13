class_name FrostRing
extends SkillBase


const RING_RADIUS: float = 100.0
const SLOW_FACTOR: float = 0.7
const SLOW_DURATION: float = 0.2
const RING_COLOR: Color = Color("#3C7CE0", 0.4)
const RING_WIDTH: float = 2.0
const RING_SEGMENTS: int = 48


@onready var _area: Area2D = $Area2D


func _ready() -> void:
	cooldown = 0.0
	super._ready()


func _process(_delta: float) -> void:
	if _area:
		for body in _area.get_overlapping_bodies():
			if is_instance_valid(body) and body.has_method("apply_slow"):
				body.apply_slow(SLOW_FACTOR, SLOW_DURATION)
	queue_redraw()


func _draw() -> void:
	var prev: Vector2 = Vector2(RING_RADIUS, 0.0)
	for i in range(1, RING_SEGMENTS + 1):
		var a: float = TAU * float(i) / float(RING_SEGMENTS)
		var cur: Vector2 = Vector2(cos(a), sin(a)) * RING_RADIUS
		draw_line(prev, cur, RING_COLOR, RING_WIDTH)
		prev = cur
