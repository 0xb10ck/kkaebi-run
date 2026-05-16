class_name DaggerThrow
extends SkillBase


const PROJECTILE_SPEED: float = 900.0
const PROJECTILE_RANGE: float = 9999.0
const PROJECTILE_LENGTH: float = 14.0
const PROJECTILE_WIDTH: float = 3.0
const PROJECTILE_COLOR: Color = Color(0.95, 0.95, 0.95, 1)
const PROJECTILE_HIT_RADIUS: float = 10.0

# LV1~5 stats
const DAMAGE_BASE: Array = [30, 40, 52, 68, 88]
const ATK_COEF: Array = [0.5, 0.65, 0.85, 1.1, 1.4]
const COOLDOWNS: Array = [2.0, 1.75, 1.5, 1.25, 1.0]
const PIERCE: Array = [2, 3, 4, 5, 6]
const CRIT_BONUS: Array = [0.05, 0.08, 0.11, 0.14, 0.18]


func _ready() -> void:
	cooldown = COOLDOWNS[0]
	super._ready()


func set_level(new_level: int) -> void:
	super.set_level(new_level)
	var idx: int = clamp(level - 1, 0, COOLDOWNS.size() - 1)
	base_cooldown = COOLDOWNS[idx]
	cooldown = COOLDOWNS[idx]


func _cast() -> void:
	var target: Node2D = _find_farthest_enemy()
	if not is_instance_valid(target):
		return
	var dir: Vector2 = (target.global_position - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	_spawn_projectile(global_position, dir)


func _find_farthest_enemy() -> Node2D:
	var farthest: Node2D = null
	var max_d2: float = -1.0
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node2D):
			continue
		var d2: float = (e.global_position - global_position).length_squared()
		if d2 > max_d2:
			max_d2 = d2
			farthest = e
	return farthest


func _spawn_projectile(origin: Vector2, dir: Vector2) -> void:
	var idx: int = clamp(level - 1, 0, DAMAGE_BASE.size() - 1)
	var p: DaggerProjectile = DaggerProjectile.new()
	p.top_level = true
	p.direction = dir
	p.damage = int(round(float(DAMAGE_BASE[idx]) * damage_multiplier))
	p.speed = PROJECTILE_SPEED
	p.max_range = PROJECTILE_RANGE
	p.pierce_remaining = int(PIERCE[idx])
	p.crit_bonus = float(CRIT_BONUS[idx])
	p.hit_radius = PROJECTILE_HIT_RADIUS
	p.owner_skill = self
	add_child(p)
	p.global_position = origin
	p.rotation = dir.angle()


class DaggerProjectile extends Node2D:
	var direction: Vector2 = Vector2.RIGHT
	var damage: int = 30
	var speed: float = 900.0
	var max_range: float = 9999.0
	var pierce_remaining: int = 2
	var crit_bonus: float = 0.05
	var hit_radius: float = 10.0
	var owner_skill: Node = null
	var _traveled: float = 0.0
	var _hit_ids: Dictionary = {}

	func _ready() -> void:
		queue_redraw()

	func _process(delta: float) -> void:
		var step: float = speed * delta
		global_position += direction * step
		_traveled += step
		if _traveled >= max_range:
			queue_free()
			return
		_check_hits()

	func _check_hits() -> void:
		var tree: SceneTree = get_tree()
		if tree == null:
			return
		for e in tree.get_nodes_in_group("enemy"):
			if not is_instance_valid(e) or not (e is Node2D):
				continue
			var id: int = e.get_instance_id()
			if _hit_ids.has(id):
				continue
			if (e as Node2D).global_position.distance_to(global_position) <= hit_radius:
				_hit_target(e as Node2D)
				_hit_ids[id] = true
				pierce_remaining -= 1
				if pierce_remaining <= 0:
					queue_free()
					return

	func _hit_target(target: Node2D) -> void:
		var final_damage: int = damage
		if randf() < crit_bonus:
			final_damage = damage * 2
		if target.has_method("take_damage"):
			target.take_damage(final_damage)
		if owner_skill and owner_skill.has_signal("hit_enemy"):
			owner_skill.emit_signal("hit_enemy", target, final_damage)

	func _draw() -> void:
		var half_l: float = PROJECTILE_LENGTH * 0.5
		var half_w: float = PROJECTILE_WIDTH * 0.5
		draw_rect(Rect2(-half_l, -half_w, PROJECTILE_LENGTH, PROJECTILE_WIDTH), PROJECTILE_COLOR)
