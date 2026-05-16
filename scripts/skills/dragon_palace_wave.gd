class_name DragonPalaceWave
extends SkillBase


const EXPAND_SPEED: float = 500.0
const WAVE_COLOR: Color = Color(0.20, 0.55, 0.85, 0.55)
const WAVE_WIDTH: float = 4.0
const SLOW_FACTOR: float = 0.70
const SLOW_DURATION: float = 2.0


const BASE_DAMAGE_BY_LEVEL: Array = [35, 45, 58, 75, 95]
const RADIUS_BY_LEVEL: Array = [200.0, 230.0, 260.0, 300.0, 340.0]
const COOLDOWN_BY_LEVEL: Array = [12.0, 11.0, 10.0, 9.0, 8.0]
const KNOCKBACK_BY_LEVEL: Array = [80.0, 95.0, 110.0, 130.0, 150.0]


func _ready() -> void:
	cooldown = COOLDOWN_BY_LEVEL[0]
	super._ready()


func set_level(new_level: int) -> void:
	super.set_level(new_level)
	var idx: int = clamp(level - 1, 0, COOLDOWN_BY_LEVEL.size() - 1)
	base_cooldown = COOLDOWN_BY_LEVEL[idx]
	cooldown = base_cooldown


func _current_damage() -> int:
	var idx: int = clamp(level - 1, 0, BASE_DAMAGE_BY_LEVEL.size() - 1)
	return int(round(float(BASE_DAMAGE_BY_LEVEL[idx]) * damage_multiplier))


func _current_max_radius() -> float:
	var idx: int = clamp(level - 1, 0, RADIUS_BY_LEVEL.size() - 1)
	return float(RADIUS_BY_LEVEL[idx])


func _current_knockback() -> float:
	var idx: int = clamp(level - 1, 0, KNOCKBACK_BY_LEVEL.size() - 1)
	return float(KNOCKBACK_BY_LEVEL[idx])


func _cast() -> void:
	var wave: Wave = Wave.new()
	wave.top_level = true
	wave.max_radius = _current_max_radius()
	wave.expand_speed = EXPAND_SPEED
	wave.damage = _current_damage()
	wave.knockback = _current_knockback()
	wave.slow_factor = SLOW_FACTOR
	wave.slow_duration = SLOW_DURATION
	wave.color = WAVE_COLOR
	wave.line_width = WAVE_WIDTH
	wave.owner_skill = self
	add_child(wave)
	wave.global_position = global_position


class Wave extends Node2D:
	var max_radius: float = 200.0
	var expand_speed: float = 500.0
	var damage: int = 35
	var knockback: float = 80.0
	var slow_factor: float = 0.70
	var slow_duration: float = 2.0
	var color: Color = Color(0.20, 0.55, 0.85, 0.55)
	var line_width: float = 4.0
	var owner_skill: Node = null
	var _current_radius: float = 0.0
	var _hit_ids: Dictionary = {}

	func _process(delta: float) -> void:
		_current_radius += expand_speed * delta
		if _current_radius >= max_radius:
			_current_radius = max_radius
			_apply_to_enemies()
			queue_redraw()
			queue_free()
			return
		_apply_to_enemies()
		queue_redraw()

	func _apply_to_enemies() -> void:
		for e in get_tree().get_nodes_in_group("enemy"):
			if not (e is Node2D):
				continue
			var id: int = e.get_instance_id()
			if _hit_ids.has(id):
				continue
			var d: float = (e.global_position - global_position).length()
			if d <= _current_radius:
				_hit_ids[id] = true
				if e.has_method("take_damage"):
					e.take_damage(damage)
				if e.has_method("apply_slow"):
					e.apply_slow(slow_factor, slow_duration)
				if e.has_method("apply_knockback"):
					var dir: Vector2 = (e.global_position - global_position).normalized()
					if dir.length_squared() == 0.0:
						dir = Vector2.RIGHT
					e.apply_knockback(dir * knockback)
				if owner_skill and owner_skill.has_signal("hit_enemy"):
					owner_skill.emit_signal("hit_enemy", e, damage)

	func _draw() -> void:
		var segments: int = 64
		var prev: Vector2 = Vector2(_current_radius, 0.0)
		for i in range(1, segments + 1):
			var a: float = TAU * float(i) / float(segments)
			var cur: Vector2 = Vector2(cos(a), sin(a)) * _current_radius
			draw_line(prev, cur, color, line_width)
			prev = cur
