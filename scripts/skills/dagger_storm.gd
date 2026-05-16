class_name DaggerStorm
extends SkillBase


const PROJECTILE_SPEED: float = 700.0
const PROJECTILE_LENGTH: float = 12.0
const PROJECTILE_WIDTH: float = 3.0
const PROJECTILE_COLOR: Color = Color(0.90, 0.92, 0.70, 1)
const PROJECTILE_HIT_RADIUS: float = 10.0
const PIERCE: int = 1
const CRIT_BONUS: float = 0.08

# LV1~5 stats
const DAMAGE_BASE: Array = [22, 32, 45, 55, 65]
const ATK_COEF: Array = [0.35, 0.5, 0.7, 0.85, 1.0]
const COOLDOWNS: Array = [8.0, 7.0, 6.5, 5.5, 5.0]
const DAGGER_COUNT: Array = [8, 10, 12, 14, 16]
const RANGE_PX: Array = [320.0, 340.0, 360.0, 380.0, 400.0]


func _ready() -> void:
	cooldown = COOLDOWNS[0]
	super._ready()


func set_level(new_level: int) -> void:
	super.set_level(new_level)
	var idx: int = clamp(level - 1, 0, COOLDOWNS.size() - 1)
	base_cooldown = COOLDOWNS[idx]
	cooldown = COOLDOWNS[idx]


func _cast() -> void:
	var idx: int = clamp(level - 1, 0, DAGGER_COUNT.size() - 1)
	var count: int = int(DAGGER_COUNT[idx])
	var dmg: int = int(round(float(DAMAGE_BASE[idx]) * damage_multiplier))
	var max_range: float = float(RANGE_PX[idx])
	for i in count:
		var a: float = TAU * float(i) / float(count)
		var dir: Vector2 = Vector2(cos(a), sin(a))
		_spawn_projectile(global_position, dir, dmg, max_range)


func _spawn_projectile(origin: Vector2, dir: Vector2, dmg: int, max_range: float) -> void:
	var p: StormDagger = StormDagger.new()
	p.top_level = true
	p.direction = dir
	p.damage = dmg
	p.speed = PROJECTILE_SPEED
	p.max_range = max_range
	p.pierce_remaining = PIERCE
	p.crit_bonus = CRIT_BONUS
	p.hit_radius = PROJECTILE_HIT_RADIUS
	p.owner_skill = self
	add_child(p)
	p.global_position = origin
	p.rotation = dir.angle()


class StormDagger extends Node2D:
	var direction: Vector2 = Vector2.RIGHT
	var damage: int = 22
	var speed: float = 700.0
	var max_range: float = 320.0
	var pierce_remaining: int = 1
	var crit_bonus: float = 0.08
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
