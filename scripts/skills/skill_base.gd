class_name SkillBase
extends Node2D


signal hit_enemy(enemy: Node, damage: int)


var player: Node
var level: int = 1
var cooldown: float = 1.0
var time_since_cast: float = 0.0
var base_cooldown: float = -1.0
var damage_multiplier: float = 1.0


func _ready() -> void:
	if base_cooldown < 0.0:
		base_cooldown = cooldown
	if player == null:
		player = get_tree().get_first_node_in_group("player")


func set_level(new_level: int) -> void:
	level = max(1, new_level)
	damage_multiplier = 1.0 + 0.2 * float(level - 1)
	if base_cooldown > 0.0:
		var factor: float = max(0.5, 1.0 - 0.05 * float(level - 1))
		cooldown = base_cooldown * factor


func _physics_process(delta: float) -> void:
	if is_instance_valid(player) and player is Node2D:
		global_position = (player as Node2D).global_position
	if cooldown <= 0.0:
		return
	time_since_cast += delta
	if time_since_cast >= cooldown:
		time_since_cast = 0.0
		_cast()


func _cast() -> void:
	pass
