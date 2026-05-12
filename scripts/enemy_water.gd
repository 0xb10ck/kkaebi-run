extends Enemy


const SLOW_FACTOR: float = 0.5
const SLOW_DURATION: float = 1.5


func _ready() -> void:
	max_hp = 15
	move_speed = 80.0
	contact_damage = 12
	exp_drop_value = 5
	hp = max_hp
	super._ready()


func _on_contact_hit(player: Node2D) -> void:
	if player and player.has_method("apply_slow"):
		player.apply_slow(SLOW_FACTOR, SLOW_DURATION)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color("#4CAF50"))
