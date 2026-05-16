class_name DragonKingWrath
extends SkillBase


const PILLAR_COUNT: int = 5
const PILLAR_RADIUS: float = 70.0
const PILLAR_HEIGHT: float = 400.0
const PILLAR_WIDTH: float = 60.0
const PILLAR_COLOR: Color = Color(0.15, 0.45, 0.85, 0.75)
const TELEGRAPH_COLOR: Color = Color(0.15, 0.45, 0.85, 0.35)
const TELEGRAPH_DELAY: float = 0.3
const AIRBORNE_DURATION: float = 1.2
const SHOCKWAVE_RADIUS: float = 100.0
const SHOCKWAVE_DAMAGE_RATIO: float = 0.40
const SHOCKWAVE_COLOR: Color = Color(0.45, 0.75, 1.0, 0.45)
const SCREEN_HALF: float = 320.0


const BASE_DAMAGE_BY_LEVEL: Array = [55, 80, 110, 150, 200]
const COOLDOWN_BY_LEVEL: Array = [80.0, 70.0, 60.0, 55.0, 50.0]


func _ready() -> void:
	cooldown = 0.0
	super._ready()


func set_level(new_level: int) -> void:
	super.set_level(new_level)
	base_cooldown = 0.0
	cooldown = 0.0


func _current_pillar_damage() -> int:
	var idx: int = clamp(level - 1, 0, BASE_DAMAGE_BY_LEVEL.size() - 1)
	return int(round(float(BASE_DAMAGE_BY_LEVEL[idx]) * damage_multiplier))


func cast_active() -> void:
	var dmg: int = _current_pillar_damage()
	for i in PILLAR_COUNT:
		var offset: Vector2 = Vector2(
			randf_range(-SCREEN_HALF, SCREEN_HALF),
			randf_range(-SCREEN_HALF, SCREEN_HALF)
		)
		var target_pos: Vector2 = global_position + offset
		_spawn_pillar(target_pos, dmg)


func _spawn_pillar(pos: Vector2, dmg: int) -> void:
	var pillar: Pillar = Pillar.new()
	pillar.top_level = true
	pillar.pillar_damage = dmg
	pillar.shockwave_damage = int(round(float(dmg) * SHOCKWAVE_DAMAGE_RATIO))
	pillar.pillar_radius = PILLAR_RADIUS
	pillar.shockwave_radius = SHOCKWAVE_RADIUS
	pillar.telegraph_delay = TELEGRAPH_DELAY
	pillar.airborne_duration = AIRBORNE_DURATION
	pillar.pillar_height = PILLAR_HEIGHT
	pillar.pillar_width = PILLAR_WIDTH
	pillar.pillar_color = PILLAR_COLOR
	pillar.telegraph_color = TELEGRAPH_COLOR
	pillar.shockwave_color = SHOCKWAVE_COLOR
	pillar.owner_skill = self
	add_child(pillar)
	pillar.global_position = pos


class Pillar extends Node2D:
	var pillar_damage: int = 55
	var shockwave_damage: int = 22
	var pillar_radius: float = 70.0
	var shockwave_radius: float = 100.0
	var telegraph_delay: float = 0.3
	var airborne_duration: float = 1.2
	var pillar_height: float = 400.0
	var pillar_width: float = 60.0
	var pillar_color: Color = Color(0.15, 0.45, 0.85, 0.75)
	var telegraph_color: Color = Color(0.15, 0.45, 0.85, 0.35)
	var shockwave_color: Color = Color(0.45, 0.75, 1.0, 0.45)
	var owner_skill: Node = null

	enum State { TELEGRAPH, PILLAR, AIRBORNE, SHOCKWAVE, DONE }
	var _state: int = State.TELEGRAPH
	var _state_time: float = 0.0

	func _process(delta: float) -> void:
		_state_time += delta
		match _state:
			State.TELEGRAPH:
				if _state_time >= telegraph_delay:
					_resolve_pillar()
					_state = State.AIRBORNE
					_state_time = 0.0
			State.AIRBORNE:
				if _state_time >= airborne_duration:
					_resolve_shockwave()
					_state = State.SHOCKWAVE
					_state_time = 0.0
			State.SHOCKWAVE:
				if _state_time >= 0.25:
					_state = State.DONE
					queue_free()
					return
		queue_redraw()

	func _resolve_pillar() -> void:
		for e in get_tree().get_nodes_in_group("enemy"):
			if not (e is Node2D):
				continue
			var d: float = (e.global_position - global_position).length()
			if d <= pillar_radius:
				if e.has_method("take_damage"):
					e.take_damage(pillar_damage)
				if owner_skill and owner_skill.has_signal("hit_enemy"):
					owner_skill.emit_signal("hit_enemy", e, pillar_damage)

	func _resolve_shockwave() -> void:
		for e in get_tree().get_nodes_in_group("enemy"):
			if not (e is Node2D):
				continue
			var d: float = (e.global_position - global_position).length()
			if d <= shockwave_radius:
				if e.has_method("take_damage"):
					e.take_damage(shockwave_damage)
				if owner_skill and owner_skill.has_signal("hit_enemy"):
					owner_skill.emit_signal("hit_enemy", e, shockwave_damage)

	func _draw() -> void:
		match _state:
			State.TELEGRAPH:
				draw_circle(Vector2.ZERO, pillar_radius, telegraph_color)
			State.AIRBORNE, State.PILLAR:
				var half_w: float = pillar_width * 0.5
				draw_rect(Rect2(-half_w, -pillar_height, pillar_width, pillar_height), pillar_color)
				draw_circle(Vector2.ZERO, pillar_radius, telegraph_color)
			State.SHOCKWAVE:
				draw_circle(Vector2.ZERO, shockwave_radius, shockwave_color)
			_:
				pass
