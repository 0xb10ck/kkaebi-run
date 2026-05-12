extends Enemy


func _ready() -> void:
	max_hp = 8
	move_speed = 60.0
	contact_damage = 8
	exp_drop_value = 1
	hp = max_hp
	super._ready()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 10.0, Color("#E03C3C"))
