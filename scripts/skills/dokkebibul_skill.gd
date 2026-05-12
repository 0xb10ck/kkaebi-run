extends Node2D

@export var orb_count: int = 3
@export var rotation_radius: float = 110.0
@export var rotation_speed_deg: float = 240.0
@export var damage_per_hit: int = 6
@export var same_target_cooldown: float = 0.5

var _angle_rad: float = 0.0
var _orbs: Array = []
var _recent_hits: Dictionary = {}


func _ready() -> void:
	_spawn_orbs()


func _spawn_orbs() -> void:
	for o in _orbs:
		if is_instance_valid(o):
			o.queue_free()
	_orbs.clear()
	for i in range(orb_count):
		var orb := Area2D.new()
		orb.collision_layer = 16
		orb.collision_mask = 2
		var shape := CollisionShape2D.new()
		var cs := CircleShape2D.new()
		cs.radius = 14.0
		shape.shape = cs
		orb.add_child(shape)
		var visual := ColorRect.new()
		visual.offset_left = -8.0
		visual.offset_top = -8.0
		visual.offset_right = 8.0
		visual.offset_bottom = 8.0
		visual.color = Palette.RED_LIGHT
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		orb.add_child(visual)
		add_child(orb)
		_orbs.append(orb)


func _process(delta: float) -> void:
	_angle_rad += deg_to_rad(rotation_speed_deg) * delta
	var n: float = float(orb_count) if orb_count > 0 else 1.0
	for i in range(_orbs.size()):
		var orb: Area2D = _orbs[i]
		if not is_instance_valid(orb):
			continue
		var a := _angle_rad + (TAU * float(i) / n)
		orb.position = Vector2(cos(a), sin(a)) * rotation_radius
	_apply_damage()


func _apply_damage() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _recent_hits.size() > 200:
		for k in _recent_hits.keys():
			if now - float(_recent_hits[k]) > same_target_cooldown * 2.0:
				_recent_hits.erase(k)
	for orb in _orbs:
		if not is_instance_valid(orb):
			continue
		for body in orb.get_overlapping_bodies():
			if not is_instance_valid(body) or not body.has_method("take_damage"):
				continue
			var key := body.get_instance_id()
			var last: float = _recent_hits.get(key, -999.0)
			if now - last >= same_target_cooldown:
				_recent_hits[key] = now
				body.take_damage(damage_per_hit)
