class_name FlintBurst
extends SkillBase


const DAMAGE_BASE: int = 25
const CAST_RANGE: float = 400.0
const EXPLOSION_RADIUS: float = 90.0
const EXPLOSION_LIFE: float = 0.25
const EXPLOSION_COLOR: Color = Color(0.95, 0.55, 0.20, 1.0)


func _ready() -> void:
	cooldown = 4.5
	super._ready()


func _cast() -> void:
	var target: Node2D = _find_nearest_enemy_in_range(CAST_RANGE)
	if not is_instance_valid(target):
		return
	var dmg: int = int(round(float(DAMAGE_BASE) * damage_multiplier))
	_spawn_explosion(target.global_position, dmg)


func _find_nearest_enemy_in_range(max_range: float) -> Node2D:
	var nearest: Node2D = null
	var min_d2: float = max_range * max_range
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node2D):
			continue
		var d2: float = (e.global_position - global_position).length_squared()
		if d2 <= min_d2:
			min_d2 = d2
			nearest = e
	return nearest


func _spawn_explosion(pos: Vector2, dmg: int) -> void:
	var ex: FlintExplosion = FlintExplosion.new()
	ex.top_level = true
	ex.damage = dmg
	ex.radius = EXPLOSION_RADIUS
	ex.life_total = EXPLOSION_LIFE
	ex.color = EXPLOSION_COLOR
	ex.owner_skill = self
	add_child(ex)
	ex.global_position = pos


class FlintExplosion extends Node2D:
	var damage: int = 25
	var radius: float = 90.0
	var life_total: float = 0.25
	var color: Color = Color(0.95, 0.55, 0.20, 1.0)
	var owner_skill: Node = null
	var _life: float = 0.0
	var _dealt: bool = false

	func _ready() -> void:
		queue_redraw()
		_apply_damage()

	func _process(delta: float) -> void:
		_life += delta
		if _life >= life_total:
			queue_free()
			return
		queue_redraw()

	func _apply_damage() -> void:
		if _dealt:
			return
		_dealt = true
		var tree: SceneTree = get_tree()
		if tree == null:
			return
		for e in tree.get_nodes_in_group("enemy"):
			if not (e is Node2D):
				continue
			var d2: float = (e.global_position - global_position).length_squared()
			if d2 > radius * radius:
				continue
			if e.has_method("take_damage"):
				e.take_damage(damage)
				if owner_skill and owner_skill.has_signal("hit_enemy"):
					owner_skill.emit_signal("hit_enemy", e, damage)

	func _draw() -> void:
		var t: float = clamp(_life / life_total, 0.0, 1.0)
		var r: float = radius * (0.4 + 0.6 * t)
		var a: float = 1.0 - t
		var c: Color = Color(color.r, color.g, color.b, a)
		draw_circle(Vector2.ZERO, r, c)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(1.0, 0.9, 0.4, a), 2.0)
