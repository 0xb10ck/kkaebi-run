class_name EarthWall
extends SkillBase


const HP_TRIGGER_RATIO: float = 0.60
const WALL_FORWARD_OFFSET: float = 60.0
const WALL_COLOR: Color = Color(0.55, 0.40, 0.25, 1.0)
const WALL_OUTLINE_COLOR: Color = Color(0.30, 0.20, 0.12, 1.0)
const KNOCKBACK_PX: float = 120.0

const WALL_HP_BY_LEVEL: Array = [60, 90, 130, 180, 240]
const BURST_DAMAGE_BY_LEVEL: Array = [30, 45, 65, 90, 120]
const BURST_COEF_BY_LEVEL: Array = [0.4, 0.55, 0.7, 0.9, 1.0]
const COOLDOWN_BY_LEVEL: Array = [14.0, 12.0, 11.0, 9.5, 8.0]
const DURATION_BY_LEVEL: Array = [4.0, 4.5, 5.0, 5.5, 6.0]
const BURST_RADIUS: float = 110.0
const WALL_WIDTH: float = 180.0
const WALL_HEIGHT: float = 80.0


var _facing: Vector2 = Vector2.RIGHT
var _active_wall: Node2D = null


func _ready() -> void:
	cooldown = COOLDOWN_BY_LEVEL[0]
	super._ready()


func set_level(new_level: int) -> void:
	super.set_level(new_level)
	var idx: int = clamp(level - 1, 0, COOLDOWN_BY_LEVEL.size() - 1)
	base_cooldown = COOLDOWN_BY_LEVEL[idx]
	cooldown = base_cooldown


func _physics_process(delta: float) -> void:
	if is_instance_valid(player) and player is Node2D:
		var p: Node2D = player as Node2D
		if "velocity" in p:
			var v: Vector2 = p.velocity
			if v.length() > 0.01:
				_facing = v.normalized()
		global_position = p.global_position
	if cooldown <= 0.0:
		return
	time_since_cast += delta
	if is_instance_valid(_active_wall):
		return
	if not _should_trigger():
		return
	if time_since_cast < cooldown:
		return
	time_since_cast = 0.0
	_cast()


func _should_trigger() -> bool:
	if not is_instance_valid(player):
		return false
	if not ("hp" in player) or not ("max_hp" in player):
		return false
	var hp_f: float = float(player.hp)
	var max_f: float = float(player.max_hp)
	if max_f <= 0.0:
		return false
	return (hp_f / max_f) <= HP_TRIGGER_RATIO


func _current_wall_hp() -> int:
	var idx: int = clamp(level - 1, 0, WALL_HP_BY_LEVEL.size() - 1)
	return int(WALL_HP_BY_LEVEL[idx])


func _current_burst_damage() -> int:
	var idx: int = clamp(level - 1, 0, BURST_DAMAGE_BY_LEVEL.size() - 1)
	return int(round(float(BURST_DAMAGE_BY_LEVEL[idx]) * damage_multiplier))


func _current_duration() -> float:
	var idx: int = clamp(level - 1, 0, DURATION_BY_LEVEL.size() - 1)
	return float(DURATION_BY_LEVEL[idx])


func _cast() -> void:
	if not is_instance_valid(player) or not (player is Node2D):
		return
	var origin: Vector2 = (player as Node2D).global_position + _facing * WALL_FORWARD_OFFSET
	var wall: Wall = Wall.new()
	wall.top_level = true
	wall.max_hp_v = _current_wall_hp()
	wall.hp_v = wall.max_hp_v
	wall.life_left = _current_duration()
	wall.burst_damage = _current_burst_damage()
	wall.owner_skill = self
	wall.facing = _facing
	add_child(wall)
	wall.global_position = origin
	_active_wall = wall


class Wall extends StaticBody2D:
	var max_hp_v: int = 60
	var hp_v: int = 60
	var life_left: float = 4.0
	var burst_damage: int = 30
	var owner_skill: Node = null
	var facing: Vector2 = Vector2.RIGHT
	var _dmg_area: Area2D
	var _enemies_hit_cooldown: Dictionary = {}

	const WIDTH: float = 180.0
	const HEIGHT: float = 80.0
	const BRADIUS: float = 110.0
	const KNOCK: float = 120.0

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		rotation = facing.angle()
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(HEIGHT, WIDTH)
		shape.shape = rect
		add_child(shape)
		_dmg_area = Area2D.new()
		_dmg_area.collision_layer = 0
		_dmg_area.collision_mask = 4
		var ashape: CollisionShape2D = CollisionShape2D.new()
		var arect: RectangleShape2D = RectangleShape2D.new()
		arect.size = Vector2(HEIGHT, WIDTH)
		ashape.shape = arect
		_dmg_area.add_child(ashape)
		add_child(_dmg_area)
		queue_redraw()

	func take_damage(amount: int, _attacker: Object = null) -> void:
		hp_v = max(0, hp_v - int(amount))
		if hp_v <= 0:
			_burst_and_die()
		queue_redraw()

	func _process(delta: float) -> void:
		life_left -= delta
		var to_remove: Array = []
		for k in _enemies_hit_cooldown.keys():
			_enemies_hit_cooldown[k] -= delta
			if _enemies_hit_cooldown[k] <= 0.0:
				to_remove.append(k)
		for k in to_remove:
			_enemies_hit_cooldown.erase(k)
		if _dmg_area:
			for body in _dmg_area.get_overlapping_bodies():
				if not is_instance_valid(body):
					continue
				if not body.has_method("take_damage"):
					continue
				var id: int = body.get_instance_id()
				if _enemies_hit_cooldown.has(id):
					continue
				var tick_dmg: int = max(1, int(burst_damage / 3))
				body.take_damage(tick_dmg)
				take_damage(max(1, int(tick_dmg / 2)))
				_enemies_hit_cooldown[id] = 0.4
		if life_left <= 0.0:
			_burst_and_die()
		queue_redraw()

	func _burst_and_die() -> void:
		if not is_inside_tree():
			return
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e):
				continue
			if not (e is Node2D):
				continue
			var d: float = (e.global_position - global_position).length()
			if d > BRADIUS:
				continue
			if e.has_method("take_damage"):
				e.take_damage(burst_damage)
			if e.has_method("apply_knockback"):
				var dir: Vector2 = (e.global_position - global_position).normalized()
				e.apply_knockback(dir * KNOCK)
			if owner_skill and owner_skill.has_signal("hit_enemy"):
				owner_skill.emit_signal("hit_enemy", e, burst_damage)
		queue_free()

	func _draw() -> void:
		var rect: Rect2 = Rect2(-HEIGHT * 0.5, -WIDTH * 0.5, HEIGHT, WIDTH)
		var ratio: float = 1.0
		if max_hp_v > 0:
			ratio = float(hp_v) / float(max_hp_v)
		var fill: Color = Color(0.55, 0.40, 0.25, lerp(0.55, 0.95, ratio))
		draw_rect(rect, fill)
		draw_rect(rect, Color(0.30, 0.20, 0.12, 1.0), false, 2.0)
