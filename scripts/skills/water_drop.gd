class_name WaterDrop
extends SkillBase


const PROJECTILE_SPEED: float = 600.0
const PROJECTILE_RADIUS: float = 6.0
const PROJECTILE_COLOR: Color = Color(0.30, 0.65, 0.95, 1.0)
const PROJECTILE_MAX_LIFE: float = 2.5
const SLOW_FACTOR: float = 0.75
const SLOW_DURATION: float = 0.5
const SEARCH_RANGE: float = 300.0


const BASE_DAMAGE_BY_LEVEL: Array = [18, 24, 31, 40, 52]
const PROJECTILES_BY_LEVEL: Array = [1, 1, 2, 2, 3]
const COOLDOWN_BY_LEVEL: Array = [2.5, 2.2, 2.0, 1.7, 1.5]


func _ready() -> void:
	cooldown = COOLDOWN_BY_LEVEL[0]
	super._ready()


func set_level(new_level: int) -> void:
	super.set_level(new_level)
	var idx: int = clamp(level - 1, 0, COOLDOWN_BY_LEVEL.size() - 1)
	base_cooldown = COOLDOWN_BY_LEVEL[idx]
	cooldown = base_cooldown


func _current_damage() -> int:
	var idx: int = clamp(level - 1, 0, BASE_DAMAGE_BY_LEVEL.size() - 1)
	var base: float = float(BASE_DAMAGE_BY_LEVEL[idx])
	return int(round(base * damage_multiplier))


func _current_projectile_count() -> int:
	var idx: int = clamp(level - 1, 0, PROJECTILES_BY_LEVEL.size() - 1)
	return int(PROJECTILES_BY_LEVEL[idx])


func _cast() -> void:
	var target: Node2D = _find_nearest_enemy()
	if not is_instance_valid(target):
		return
	var dmg: int = _current_damage()
	var count: int = _current_projectile_count()
	for i in count:
		_spawn_projectile(global_position, target, dmg, i, count)


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var min_d2: float = SEARCH_RANGE * SEARCH_RANGE
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node2D):
			continue
		var d2: float = (e.global_position - global_position).length_squared()
		if d2 < min_d2:
			min_d2 = d2
			nearest = e
	return nearest


func _spawn_projectile(origin: Vector2, target: Node2D, dmg: int, idx: int, total: int) -> void:
	var p: WaterDropProjectile = WaterDropProjectile.new()
	p.top_level = true
	p.target = target
	p.damage = dmg
	p.speed = PROJECTILE_SPEED
	p.radius = PROJECTILE_RADIUS
	p.color = PROJECTILE_COLOR
	p.slow_factor = SLOW_FACTOR
	p.slow_duration = SLOW_DURATION
	p.max_life = PROJECTILE_MAX_LIFE
	p.owner_skill = self
	var spread: float = 0.0
	if total > 1:
		spread = (float(idx) - float(total - 1) * 0.5) * 0.25
	p.initial_spread = spread
	add_child(p)
	p.global_position = origin


class WaterDropProjectile extends Node2D:
	var target: Node2D
	var damage: int = 18
	var speed: float = 600.0
	var radius: float = 6.0
	var color: Color = Color(0.30, 0.65, 0.95, 1.0)
	var slow_factor: float = 0.75
	var slow_duration: float = 0.5
	var max_life: float = 2.5
	var owner_skill: Node = null
	var initial_spread: float = 0.0
	var _life: float = 0.0
	var _dir: Vector2 = Vector2.RIGHT
	var _initialized: bool = false

	func _ready() -> void:
		if is_instance_valid(target):
			var to_target: Vector2 = target.global_position - global_position
			if to_target.length_squared() > 0.0:
				_dir = to_target.normalized().rotated(initial_spread)
		_initialized = true
		queue_redraw()

	func _process(delta: float) -> void:
		_life += delta
		if _life >= max_life:
			queue_free()
			return
		if is_instance_valid(target):
			var to_target: Vector2 = target.global_position - global_position
			if to_target.length_squared() > 0.0:
				_dir = to_target.normalized()
		global_position += _dir * speed * delta
		if is_instance_valid(target):
			if global_position.distance_to(target.global_position) <= radius + 6.0:
				_hit_target()

	func _hit_target() -> void:
		if not is_instance_valid(target):
			queue_free()
			return
		if target.has_method("take_damage"):
			target.take_damage(damage)
		if target.has_method("apply_slow"):
			target.apply_slow(slow_factor, slow_duration)
		if owner_skill and owner_skill.has_signal("hit_enemy"):
			owner_skill.emit_signal("hit_enemy", target, damage)
		queue_free()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, color)
