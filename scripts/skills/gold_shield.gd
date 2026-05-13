class_name GoldShield
extends SkillBase


const SHIELD_CHANCE: float = 0.3
const SHIELD_RADIUS: float = 24.0
const SHIELD_COLOR: Color = Color("#F0EDE6", 0.4)


func _ready() -> void:
	cooldown = 0.0
	super._ready()
	if is_instance_valid(player):
		player.set("shield_chance", SHIELD_CHANCE)


func _draw() -> void:
	draw_circle(Vector2.ZERO, SHIELD_RADIUS, SHIELD_COLOR)


func _exit_tree() -> void:
	if is_instance_valid(player):
		player.set("shield_chance", 0.0)
