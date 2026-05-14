extends EnemyBase


func _ready() -> void:
	if data == null:
		max_hp = 8
		move_speed = 80.0
		contact_damage = 4
		exp_drop_value = 1
		coin_drop_value = 1
		coin_drop_chance = 0.10
	super._ready()
	hp = max_hp


func _draw() -> void:
	draw_circle(Vector2.ZERO, 10.0, Color("#E03C3C"))
