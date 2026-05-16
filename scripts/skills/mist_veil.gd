class_name MistVeil
extends SkillBase


const VEIL_RADIUS: float = 130.0
const VEIL_COLOR: Color = Color(0.55, 0.70, 0.85, 0.30)
const VEIL_RING_COLOR: Color = Color(0.55, 0.70, 0.85, 0.55)
const SLOW_FACTOR: float = 0.60
const SLOW_DURATION: float = 0.5
const HP_THRESHOLD: float = 0.5


const COOLDOWN_BY_LEVEL: Array = [22.0, 20.0, 18.0, 16.0, 14.0]
const DURATION_BY_LEVEL: Array = [4.0, 4.5, 5.0, 5.5, 6.0]
const EVASION_BY_LEVEL: Array = [0.15, 0.20, 0.25, 0.30, 0.35]


@onready var _area: Area2D = $Area2D


var _active: bool = false
var _active_time_left: float = 0.0
var _ready_to_trigger: bool = false


func _ready() -> void:
	cooldown = COOLDOWN_BY_LEVEL[0]
	super._ready()


func set_level(new_level: int) -> void:
	super.set_level(new_level)
	var idx: int = clamp(level - 1, 0, COOLDOWN_BY_LEVEL.size() - 1)
	base_cooldown = COOLDOWN_BY_LEVEL[idx]
	cooldown = base_cooldown


func _current_duration() -> float:
	var idx: int = clamp(level - 1, 0, DURATION_BY_LEVEL.size() - 1)
	return float(DURATION_BY_LEVEL[idx])


func _current_evasion_bonus() -> float:
	var idx: int = clamp(level - 1, 0, EVASION_BY_LEVEL.size() - 1)
	return float(EVASION_BY_LEVEL[idx])


func _physics_process(delta: float) -> void:
	if is_instance_valid(player) and player is Node2D:
		global_position = (player as Node2D).global_position

	time_since_cast += delta
	if time_since_cast >= base_cooldown:
		_ready_to_trigger = true

	if _active:
		_active_time_left -= delta
		_apply_active_effects()
		if _active_time_left <= 0.0:
			_deactivate()
		queue_redraw()
	else:
		if _ready_to_trigger and _player_hp_below_threshold():
			_activate()


func _player_hp_below_threshold() -> bool:
	if not is_instance_valid(player):
		return false
	var hp: float = -1.0
	var max_hp: float = -1.0
	if "current_hp" in player:
		hp = float(player.current_hp)
	elif "hp" in player:
		hp = float(player.hp)
	if "max_hp" in player:
		max_hp = float(player.max_hp)
	if hp < 0.0 or max_hp <= 0.0:
		return false
	return (hp / max_hp) <= HP_THRESHOLD


func _activate() -> void:
	_active = true
	_active_time_left = _current_duration()
	_ready_to_trigger = false
	time_since_cast = 0.0
	var bonus: float = _current_evasion_bonus()
	if is_instance_valid(player):
		if player.has_method("set_evade_bonus"):
			player.set_evade_bonus(bonus)
		else:
			player.set("evade_bonus", bonus)
	queue_redraw()


func _deactivate() -> void:
	_active = false
	_active_time_left = 0.0
	if is_instance_valid(player):
		if player.has_method("set_evade_bonus"):
			player.set_evade_bonus(0.0)
		else:
			player.set("evade_bonus", 0.0)
	queue_redraw()


func _apply_active_effects() -> void:
	if _area == null:
		return
	for body in _area.get_overlapping_bodies():
		if is_instance_valid(body) and body.has_method("apply_slow"):
			body.apply_slow(SLOW_FACTOR, SLOW_DURATION)


func _draw() -> void:
	if not _active:
		return
	draw_circle(Vector2.ZERO, VEIL_RADIUS, VEIL_COLOR)
	var segments: int = 48
	var prev: Vector2 = Vector2(VEIL_RADIUS, 0.0)
	for i in range(1, segments + 1):
		var a: float = TAU * float(i) / float(segments)
		var cur: Vector2 = Vector2(cos(a), sin(a)) * VEIL_RADIUS
		draw_line(prev, cur, VEIL_RING_COLOR, 2.0)
		prev = cur
