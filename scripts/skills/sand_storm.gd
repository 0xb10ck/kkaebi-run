class_name SandStorm
extends SkillBase


const DPS_BY_LEVEL: Array = [8, 12, 17, 21, 25]
const DPS_COEF_BY_LEVEL: Array = [0.15, 0.25, 0.35, 0.45, 0.5]
const COOLDOWN_BY_LEVEL: Array = [18.0, 16.0, 14.0, 12.0, 11.0]
const DURATION_BY_LEVEL: Array = [5.0, 6.0, 7.0, 7.5, 8.0]
const RADIUS_BY_LEVEL: Array = [160.0, 180.0, 200.0, 220.0, 250.0]
const TICK_INTERVAL: float = 0.5
const SLOW_FACTOR: float = 0.80
const SLOW_DURATION: float = 0.6


var _active_zone: Zone = null


func _ready() -> void:
	cooldown = COOLDOWN_BY_LEVEL[0]
	super._ready()


func set_level(new_level: int) -> void:
	super.set_level(new_level)
	var idx: int = clamp(level - 1, 0, COOLDOWN_BY_LEVEL.size() - 1)
	base_cooldown = COOLDOWN_BY_LEVEL[idx]
	cooldown = base_cooldown


func _current_dps() -> int:
	var idx: int = clamp(level - 1, 0, DPS_BY_LEVEL.size() - 1)
	return int(round(float(DPS_BY_LEVEL[idx]) * damage_multiplier))


func _current_duration() -> float:
	var idx: int = clamp(level - 1, 0, DURATION_BY_LEVEL.size() - 1)
	return float(DURATION_BY_LEVEL[idx])


func _current_radius() -> float:
	var idx: int = clamp(level - 1, 0, RADIUS_BY_LEVEL.size() - 1)
	return float(RADIUS_BY_LEVEL[idx])


func _physics_process(delta: float) -> void:
	if is_instance_valid(player) and player is Node2D:
		global_position = (player as Node2D).global_position
	if is_instance_valid(_active_zone):
		return
	if cooldown <= 0.0:
		return
	time_since_cast += delta
	if time_since_cast >= cooldown:
		time_since_cast = 0.0
		_cast()


func _cast() -> void:
	var zone: Zone = Zone.new()
	zone.dps = _current_dps()
	zone.life_left = _current_duration()
	zone.radius = _current_radius()
	zone.tick_interval = TICK_INTERVAL
	zone.slow_factor = SLOW_FACTOR
	zone.slow_duration = SLOW_DURATION
	zone.owner_skill = self
	add_child(zone)
	_active_zone = zone


class Zone extends Node2D:
	var dps: int = 8
	var life_left: float = 5.0
	var radius: float = 160.0
	var tick_interval: float = 0.5
	var slow_factor: float = 0.8
	var slow_duration: float = 0.6
	var owner_skill: Node = null
	var _tick_timer: float = 0.0
	var _spin: float = 0.0

	const SEGMENTS: int = 36
	const ARC_COLOR: Color = Color(0.85, 0.70, 0.30, 0.30)
	const ARC_COLOR_INNER: Color = Color(0.95, 0.80, 0.45, 0.18)

	func _process(delta: float) -> void:
		life_left -= delta
		_spin += delta * 2.5
		_tick_timer += delta
		if _tick_timer >= tick_interval:
			_tick_timer = 0.0
			_tick_damage()
		if life_left <= 0.0:
			queue_free()
			return
		queue_redraw()

	func _tick_damage() -> void:
		var tick_dmg: int = max(1, int(round(float(dps) * tick_interval)))
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e):
				continue
			if not (e is Node2D):
				continue
			var d: float = (e.global_position - global_position).length()
			if d > radius:
				continue
			if e.has_method("take_damage"):
				e.take_damage(tick_dmg)
			if e.has_method("apply_slow"):
				e.apply_slow(slow_factor, slow_duration)
			if owner_skill and owner_skill.has_signal("hit_enemy"):
				owner_skill.emit_signal("hit_enemy", e, tick_dmg)

	func _draw() -> void:
		var rings: int = 3
		for r in range(rings):
			var rr: float = radius * (0.4 + 0.3 * float(r))
			var prev: Vector2 = Vector2(rr, 0.0).rotated(_spin + float(r) * 0.4)
			for i in range(1, SEGMENTS + 1):
				var a: float = TAU * float(i) / float(SEGMENTS) + _spin + float(r) * 0.4
				var cur: Vector2 = Vector2(cos(a), sin(a)) * rr
				var col: Color = ARC_COLOR if r == 0 else ARC_COLOR_INNER
				draw_line(prev, cur, col, 2.0)
				prev = cur
		draw_circle(Vector2.ZERO, radius, Color(0.85, 0.70, 0.30, 0.08))
