extends Enemy


const EGG_RX: float = 9.0
const EGG_RY: float = 12.0
const EGG_SEGMENTS: int = 24


func _ready() -> void:
	max_hp = 4
	move_speed = 120.0
	contact_damage = 5
	exp_drop_value = 1
	hp = max_hp
	super._ready()


func _draw() -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in EGG_SEGMENTS:
		var a: float = TAU * float(i) / float(EGG_SEGMENTS)
		points.append(Vector2(cos(a) * EGG_RX, sin(a) * EGG_RY))
	draw_colored_polygon(points, Color("#F0EDE6"))
