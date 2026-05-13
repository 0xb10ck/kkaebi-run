class_name RockThrow
extends SkillBase


const DAMAGE: int = 40
const STUN_DURATION: float = 0.5
const PROJECTILE_SPEED: float = 300.0
const PROJECTILE_SIZE: float = 8.0
const PROJECTILE_COLOR: Color = Color("#E0C23C")
const PROJECTILE_HIT_RADIUS: float = 8.0
const PROJECTILE_MAX_LIFE: float = 5.0


func _ready() -> void:
	cooldown = 2.0
	super._ready()


func _cast() -> void:
	var target: Node2D = _find_farthest_enemy()
	if not is_instance_valid(target):
		return
	_spawn_projectile(global_position, target)


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


func _spawn_projectile(origin: Vector2, target: Node2D) -> void:
	var p: RockProjectile = RockProjectile.new()
	p.top_level = true
	p.target = target
	p.damage = int(round(float(DAMAGE) * damage_multiplier))
	p.stun_duration = STUN_DURATION
	p.speed = PROJECTILE_SPEED
	p.box_size = PROJECTILE_SIZE
	p.color = PROJECTILE_COLOR
	p.hit_radius = PROJECTILE_HIT_RADIUS
	p.max_life = PROJECTILE_MAX_LIFE
	p.owner_skill = self
	add_child(p)
	p.global_position = origin


class RockProjectile extends Node2D:
	var target: Node2D
	var damage: int = 40
	var stun_duration: float = 0.5
	var speed: float = 300.0
	var box_size: float = 8.0
	var color: Color = Color.WHITE
	var hit_radius: float = 8.0
	var max_life: float = 5.0
	var owner_skill: Node = null
	var _life: float = 0.0
	var _last_dir: Vector2 = Vector2.ZERO

	func _ready() -> void:
		if is_instance_valid(target):
			_last_dir = (target.global_position - global_position).normalized()
		queue_redraw()

	func _process(delta: float) -> void:
		_life += delta
		if _life >= max_life:
			queue_free()
			return
		var dir: Vector2 = _last_dir
		if is_instance_valid(target):
			dir = (target.global_position - global_position).normalized()
			_last_dir = dir
		global_position += dir * speed * delta
		if is_instance_valid(target):
			if global_position.distance_to(target.global_position) <= hit_radius:
				_hit_target()

	func _hit_target() -> void:
		if not is_instance_valid(target):
			queue_free()
			return
		if target.has_method("take_damage"):
			target.take_damage(damage)
		if target.has_method("apply_stun"):
			target.apply_stun(stun_duration)
		if owner_skill and owner_skill.has_signal("hit_enemy"):
			owner_skill.emit_signal("hit_enemy", target, damage)
		queue_free()

	func _draw() -> void:
		var half: float = box_size * 0.5
		draw_rect(Rect2(-half, -half, box_size, box_size), color)
