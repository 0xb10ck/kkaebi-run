class_name FireOrb
extends SkillBase


const ORB_COUNT: int = 3
const ORB_ORBIT_RADIUS: float = 60.0
const ORB_DRAW_RADIUS: float = 6.0
const ROTATION_SPEED: float = 3.0
const DAMAGE_PER_HIT: int = 8
const HIT_COOLDOWN: float = 0.3
const ORB_COLOR: Color = Color("#E03C3C")
const ENEMY_COLLISION_LAYER_BIT: int = 4


var _angle: float = 0.0
var _orb_areas: Array[Area2D] = []
var _enemy_cooldowns: Dictionary = {}


func _ready() -> void:
	cooldown = 0.0
	super._ready()
	for i in ORB_COUNT:
		var area: Area2D = _build_orb_area()
		add_child(area)
		_orb_areas.append(area)
	_update_orb_positions()


func _build_orb_area() -> Area2D:
	var area: Area2D = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = ENEMY_COLLISION_LAYER_BIT
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = ORB_DRAW_RADIUS
	shape.shape = circle
	area.add_child(shape)
	return area


func _process(delta: float) -> void:
	_angle += ROTATION_SPEED * delta
	_update_orb_positions()
	_tick_cooldowns(delta)
	_apply_damage_to_overlaps()
	queue_redraw()


func _update_orb_positions() -> void:
	for i in _orb_areas.size():
		var a: float = _angle + TAU * float(i) / float(ORB_COUNT)
		_orb_areas[i].position = Vector2(cos(a), sin(a)) * ORB_ORBIT_RADIUS


func _tick_cooldowns(delta: float) -> void:
	var to_remove: Array = []
	for k in _enemy_cooldowns.keys():
		_enemy_cooldowns[k] -= delta
		if _enemy_cooldowns[k] <= 0.0:
			to_remove.append(k)
	for k in to_remove:
		_enemy_cooldowns.erase(k)


func _apply_damage_to_overlaps() -> void:
	var dmg: int = int(round(float(DAMAGE_PER_HIT) * damage_multiplier))
	for area in _orb_areas:
		for body in area.get_overlapping_bodies():
			if not is_instance_valid(body):
				continue
			if not body.has_method("take_damage"):
				continue
			var id: int = body.get_instance_id()
			if _enemy_cooldowns.has(id):
				continue
			body.take_damage(dmg)
			hit_enemy.emit(body, dmg)
			_enemy_cooldowns[id] = HIT_COOLDOWN


func _draw() -> void:
	for i in ORB_COUNT:
		var a: float = _angle + TAU * float(i) / float(ORB_COUNT)
		var pos: Vector2 = Vector2(cos(a), sin(a)) * ORB_ORBIT_RADIUS
		draw_circle(pos, ORB_DRAW_RADIUS, ORB_COLOR)
