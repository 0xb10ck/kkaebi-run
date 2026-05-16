class_name SeedBurst
extends SkillBase


const TARGET_COUNT: int = 4
const RANGE_PX: float = 280.0
const DAMAGE_BASE: int = 10
const SHARD_RANGE_PX: float = 100.0
const SHARD_DAMAGE_RATIO: float = 0.7
const SEED_SPEED: float = 360.0
const SEED_HIT_RADIUS: float = 10.0
const SEED_FUSE_S: float = 1.0
const SEED_MAX_LIFE: float = 3.0
const SEED_COLOR: Color = Color(0.55, 0.45, 0.20, 1.0)
const SHARD_COLOR: Color = Color(0.60, 0.50, 0.25, 1.0)
const SHARD_SPEED: float = 280.0
const SHARD_HIT_RADIUS: float = 8.0


func _ready() -> void:
	cooldown = 5.0
	super._ready()


func _cast() -> void:
	var targets: Array = _find_nearest_enemies(TARGET_COUNT, RANGE_PX)
	if targets.is_empty():
		return
	var dmg: int = int(round(float(DAMAGE_BASE) * damage_multiplier))
	for t in targets:
		if not is_instance_valid(t):
			continue
		_spawn_seed(global_position, t, dmg)


func _find_nearest_enemies(count: int, max_range: float) -> Array:
	var pool: Array = []
	var max_r2: float = max_range * max_range
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node2D):
			continue
		var d2: float = (e.global_position - global_position).length_squared()
		if d2 <= max_r2:
			pool.append({"node": e, "d2": d2})
	pool.sort_custom(func(a, b): return a.d2 < b.d2)
	var picked: Array = []
	for i in min(count, pool.size()):
		picked.append(pool[i].node)
	return picked


func _spawn_seed(origin: Vector2, target: Node2D, damage: int) -> void:
	var s: SeedProjectile = SeedProjectile.new()
	s.top_level = true
	s.target = target
	s.damage = damage
	s.shard_damage = int(round(float(damage) * SHARD_DAMAGE_RATIO))
	s.owner_skill = self
	add_child(s)
	s.global_position = origin


class SeedProjectile extends Node2D:
	var target: Node2D
	var damage: int = 10
	var shard_damage: int = 7
	var owner_skill: Node = null
	var _life: float = 0.0
	var _exploded: bool = false
	var _fuse: float = 0.0
	var _last_dir: Vector2 = Vector2.ZERO

	func _ready() -> void:
		if is_instance_valid(target):
			_last_dir = (target.global_position - global_position).normalized()
		queue_redraw()

	func _process(delta: float) -> void:
		_life += delta
		if _life >= SeedBurst.SEED_MAX_LIFE:
			queue_free()
			return
		if _exploded:
			_fuse -= delta
			if _fuse <= 0.0:
				_explode()
			return
		var dir: Vector2 = _last_dir
		if is_instance_valid(target):
			dir = (target.global_position - global_position).normalized()
			_last_dir = dir
		global_position += dir * SeedBurst.SEED_SPEED * delta
		if is_instance_valid(target):
			if global_position.distance_to(target.global_position) <= SeedBurst.SEED_HIT_RADIUS:
				_on_primary_hit()

	func _on_primary_hit() -> void:
		if is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(damage)
			if owner_skill and owner_skill.has_signal("hit_enemy"):
				owner_skill.emit_signal("hit_enemy", target, damage)
		_exploded = true
		_fuse = SeedBurst.SEED_FUSE_S
		queue_redraw()

	func _explode() -> void:
		var dirs: Array = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
		for d in dirs:
			var shard: SeedShard = SeedShard.new()
			shard.top_level = true
			shard.direction = d
			shard.damage = shard_damage
			shard.owner_skill = owner_skill
			get_tree().current_scene.add_child(shard)
			shard.global_position = global_position
		queue_free()

	func _draw() -> void:
		var col: Color = SeedBurst.SEED_COLOR
		if _exploded:
			col = SeedBurst.SHARD_COLOR
		draw_circle(Vector2.ZERO, 5.0, col)


class SeedShard extends Node2D:
	var direction: Vector2 = Vector2.RIGHT
	var damage: int = 7
	var owner_skill: Node = null
	var _traveled: float = 0.0
	var _hit_ids: Dictionary = {}

	func _ready() -> void:
		queue_redraw()

	func _process(delta: float) -> void:
		var step: float = SeedBurst.SHARD_SPEED * delta
		global_position += direction * step
		_traveled += step
		if _traveled >= SeedBurst.SHARD_RANGE_PX:
			queue_free()
			return
		_check_hit()

	func _check_hit() -> void:
		for e in get_tree().get_nodes_in_group("enemy"):
			if not (e is Node2D):
				continue
			var id: int = e.get_instance_id()
			if _hit_ids.has(id):
				continue
			if global_position.distance_to((e as Node2D).global_position) <= SeedBurst.SHARD_HIT_RADIUS:
				if e.has_method("take_damage"):
					e.take_damage(damage)
					if owner_skill and owner_skill.has_signal("hit_enemy"):
						owner_skill.emit_signal("hit_enemy", e, damage)
				_hit_ids[id] = true

	func _draw() -> void:
		var perp: Vector2 = Vector2(-direction.y, direction.x) * 2.0
		var tip: Vector2 = direction * 6.0
		var pts: PackedVector2Array = PackedVector2Array([tip, perp, -perp])
		draw_colored_polygon(pts, SeedBurst.SHARD_COLOR)
