extends Node2D

@export var rotation_radius: float = 80.0
@export var rotation_speed_deg: float = 360.0
@export var damage: int = 12
@export var same_target_cooldown: float = 0.4

@onready var head: Node2D = $WeaponHead
@onready var hit_area: Area2D = $WeaponHead/HitArea

var _angle_rad: float = 0.0
var _recent_hits: Dictionary = {}


func _process(delta: float) -> void:
	_angle_rad += deg_to_rad(rotation_speed_deg) * delta
	head.position = Vector2(cos(_angle_rad), sin(_angle_rad)) * rotation_radius
	head.rotation = _angle_rad + PI * 0.5
	_apply_damage()


func _apply_damage() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# 만료된 히트 기록 청소
	if _recent_hits.size() > 200:
		for k in _recent_hits.keys():
			if now - float(_recent_hits[k]) > same_target_cooldown * 2.0:
				_recent_hits.erase(k)
	for body in hit_area.get_overlapping_bodies():
		if not is_instance_valid(body):
			continue
		if not body.has_method("take_damage"):
			continue
		var key := body.get_instance_id()
		var last: float = _recent_hits.get(key, -999.0)
		if now - last >= same_target_cooldown:
			_recent_hits[key] = now
			body.take_damage(damage)
