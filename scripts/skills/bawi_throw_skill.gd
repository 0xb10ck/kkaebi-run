extends Node2D

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/skills/projectiles/BawiProjectile.tscn")

@export var max_range: float = 400.0
@export var projectile_speed: float = 360.0
@export var damage: int = 20
@export var stun_duration: float = 0.5
@export var cooldown: float = 2.5

var _cd: float = 0.0


func _process(delta: float) -> void:
	_cd -= delta
	if _cd > 0.0:
		return
	var target := _find_target()
	if target == null:
		return
	_cd = cooldown
	var proj := PROJECTILE_SCENE.instantiate()
	proj.global_position = global_position
	var dir: Vector2 = target.global_position - global_position
	if proj.has_method("setup"):
		proj.setup(damage, projectile_speed, dir, stun_duration)
	var container: Node = _get_container()
	if container:
		container.add_child(proj)
	else:
		get_tree().current_scene.add_child(proj)


func _get_container() -> Node:
	var nodes := get_tree().get_nodes_in_group("projectile_container")
	if nodes.size() > 0:
		return nodes[0]
	return null


func _find_target() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var best: Node2D = null
	var best_hp := -1
	var max_dsq := max_range * max_range
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e.has_method("is_dying") and e.is_dying():
			continue
		if e.global_position.distance_squared_to(global_position) > max_dsq:
			continue
		var hp := 0
		if "current_hp" in e:
			hp = int(e.current_hp)
		if hp > best_hp:
			best_hp = hp
			best = e
	return best
