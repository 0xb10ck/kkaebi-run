class_name Landslide
extends SkillBase


const DAMAGE_BY_LEVEL: Array = [70, 100, 140, 190, 250]
const ATK_COEF_BY_LEVEL: Array = [1.0, 1.4, 1.9, 2.5, 3.2]
const MAX_HITS_BY_LEVEL: Array = [2, 3, 3, 4, 5]
const COOLDOWN_BY_LEVEL: Array = [60.0, 55.0, 48.0, 42.0, 35.0]
const KNOCKBACK_PX: float = 100.0
const ROLL_SPEED: float = 700.0
const ROLL_WIDTH: float = 200.0
const ROLL_LENGTH: float = 1280.0
const SCREEN_HALF_W: float = 640.0
const SCREEN_HALF_H: float = 360.0
const BOULDER_COLOR: Color = Color(0.45, 0.40, 0.35, 1.0)
const DUST_COLOR: Color = Color(0.65, 0.55, 0.40, 0.35)


var _active_boulder: Boulder = null


func _ready() -> void:
	cooldown = COOLDOWN_BY_LEVEL[0]
	super._ready()


func set_level(new_level: int) -> void:
	super.set_level(new_level)
	var idx: int = clamp(level - 1, 0, COOLDOWN_BY_LEVEL.size() - 1)
	base_cooldown = COOLDOWN_BY_LEVEL[idx]
	cooldown = base_cooldown


func _current_damage() -> int:
	var idx: int = clamp(level - 1, 0, DAMAGE_BY_LEVEL.size() - 1)
	return int(round(float(DAMAGE_BY_LEVEL[idx]) * damage_multiplier))


func _current_max_hits() -> int:
	var idx: int = clamp(level - 1, 0, MAX_HITS_BY_LEVEL.size() - 1)
	return int(MAX_HITS_BY_LEVEL[idx])


func _physics_process(delta: float) -> void:
	if is_instance_valid(player) and player is Node2D:
		global_position = (player as Node2D).global_position
	if is_instance_valid(_active_boulder):
		return
	if cooldown <= 0.0:
		return
	time_since_cast += delta
	if time_since_cast >= cooldown:
		time_since_cast = 0.0
		_cast()


func _cast() -> void:
	var from_left: bool = randi() % 2 == 0
	var boulder: Boulder = Boulder.new()
	boulder.top_level = true
	boulder.from_left = from_left
	boulder.damage = _current_damage()
	boulder.max_hits_per_enemy = _current_max_hits()
	boulder.knockback_px = KNOCKBACK_PX
	boulder.roll_speed = ROLL_SPEED
	boulder.roll_width = ROLL_WIDTH
	boulder.roll_length = ROLL_LENGTH
	boulder.owner_skill = self
	add_child(boulder)
	var origin_y: float = global_position.y + randf_range(-SCREEN_HALF_H * 0.5, SCREEN_HALF_H * 0.5)
	if from_left:
		boulder.global_position = Vector2(global_position.x - SCREEN_HALF_W - 100.0, origin_y)
	else:
		boulder.global_position = Vector2(global_position.x + SCREEN_HALF_W + 100.0, origin_y)
	_active_boulder = boulder


class Boulder extends Node2D:
	var from_left: bool = true
	var damage: int = 70
	var max_hits_per_enemy: int = 2
	var knockback_px: float = 100.0
	var roll_speed: float = 700.0
	var roll_width: float = 200.0
	var roll_length: float = 1280.0
	var owner_skill: Node = null
	var _travelled: float = 0.0
	var _hits_per_enemy: Dictionary = {}
	var _hit_cooldown: Dictionary = {}
	var _spin: float = 0.0

	const HIT_REUSE_COOLDOWN: float = 0.25
	const BODY_RADIUS: float = 90.0

	func _process(delta: float) -> void:
		_spin += delta * 6.0
		var dir: float = 1.0 if from_left else -1.0
		var step: float = roll_speed * delta
		global_position.x += dir * step
		_travelled += step
		var to_remove: Array = []
		for k in _hit_cooldown.keys():
			_hit_cooldown[k] -= delta
			if _hit_cooldown[k] <= 0.0:
				to_remove.append(k)
		for k in to_remove:
			_hit_cooldown.erase(k)
		_apply_damage_along_path()
		if _travelled >= roll_length:
			queue_free()
		queue_redraw()

	func _apply_damage_along_path() -> void:
		var half_w: float = roll_width * 0.5
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e) or not (e is Node2D):
				continue
			var dy: float = abs((e as Node2D).global_position.y - global_position.y)
			if dy > half_w:
				continue
			var dx: float = abs((e as Node2D).global_position.x - global_position.x)
			if dx > BODY_RADIUS:
				continue
			var id: int = e.get_instance_id()
			if _hit_cooldown.has(id):
				continue
			var hits_done: int = int(_hits_per_enemy.get(id, 0))
			if hits_done >= max_hits_per_enemy:
				continue
			if e.has_method("take_damage"):
				e.take_damage(damage)
			if e.has_method("apply_knockback"):
				var nudge_dir: Vector2 = Vector2(1.0 if from_left else -1.0, 0.0)
				e.apply_knockback(nudge_dir * knockback_px)
			if owner_skill and owner_skill.has_signal("hit_enemy"):
				owner_skill.emit_signal("hit_enemy", e, damage)
			_hits_per_enemy[id] = hits_done + 1
			_hit_cooldown[id] = HIT_REUSE_COOLDOWN

	func _draw() -> void:
		var dust_count: int = 5
		for i in dust_count:
			var ox: float = -float(i) * 18.0 * (1.0 if from_left else -1.0)
			var oy: float = sin(_spin + float(i)) * 8.0
			draw_circle(Vector2(ox, oy), 14.0 + float(i) * 2.0, DUST_COLOR)
		draw_circle(Vector2.ZERO, BODY_RADIUS, BOULDER_COLOR)
		draw_arc(Vector2.ZERO, BODY_RADIUS, 0.0, TAU, 24, Color(0.25, 0.20, 0.15, 1.0), 3.0)
		var stripe_color: Color = Color(0.30, 0.25, 0.20, 1.0)
		for i in 4:
			var a: float = _spin + TAU * float(i) / 4.0
			draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * BODY_RADIUS, stripe_color, 4.0)
