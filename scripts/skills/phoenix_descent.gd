class_name PhoenixDescent
extends SkillBase


const WINDUP_DURATION: float = 1.5
const SPREAD_DURATION: float = 0.5
const STRIKE_BASE_COUNT: int = 12
const STRIKE_RADIUS: float = 90.0
const BASE_DAMAGE: int = 40
const VIEW_MIN: Vector2 = Vector2(64.0, 64.0)
const VIEW_MAX: Vector2 = Vector2(1216.0, 656.0)
const PHOENIX_COLOR: Color = Color(0.99, 0.65, 0.18, 0.6)
const PHOENIX_INNER: Color = Color(1.0, 0.95, 0.5, 0.5)


enum State { READY, WINDUP, STRIKING }


var _state: int = State.READY
var _state_time: float = 0.0
var _strikes_total: int = 0
var _strikes_spawned: int = 0
var _next_strike_at: float = 0.0
var _active_explosions: Array[PDExplosion] = []


func _ready() -> void:
	cooldown = 0.0
	super._ready()


func cast_active() -> bool:
	if _state != State.READY:
		return false
	_state = State.WINDUP
	_state_time = 0.0
	_strikes_total = STRIKE_BASE_COUNT + 2 * (level - 1)
	_strikes_spawned = 0
	_next_strike_at = 0.0
	queue_redraw()
	return true


func is_ready_to_cast() -> bool:
	return _state == State.READY


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	match _state:
		State.READY:
			pass
		State.WINDUP:
			_state_time += delta
			if _state_time >= WINDUP_DURATION:
				_state = State.STRIKING
				_state_time = 0.0
				_strikes_spawned = 0
				_next_strike_at = 0.0
			queue_redraw()
		State.STRIKING:
			_state_time += delta
			while _strikes_spawned < _strikes_total and _state_time >= _next_strike_at:
				_spawn_strike()
				_strikes_spawned += 1
				if _strikes_total > 1:
					_next_strike_at = SPREAD_DURATION * float(_strikes_spawned) / float(_strikes_total - 1) if _strikes_total > 1 else 0.0
				else:
					_next_strike_at = SPREAD_DURATION
			if _strikes_spawned >= _strikes_total and _state_time >= SPREAD_DURATION:
				_state = State.READY
			queue_redraw()


func _spawn_strike() -> void:
	var pos: Vector2 = Vector2(randf_range(VIEW_MIN.x, VIEW_MAX.x), randf_range(VIEW_MIN.y, VIEW_MAX.y))
	var dmg: int = int(round(float(BASE_DAMAGE) * damage_multiplier))
	var ex: PDExplosion = PDExplosion.new()
	ex.top_level = true
	ex.damage = dmg
	ex.radius = STRIKE_RADIUS
	ex.owner_skill = self
	add_child(ex)
	ex.global_position = pos


class PDExplosion extends Node2D:
	const LIFE: float = 0.35
	var damage: int = 40
	var radius: float = 90.0
	var owner_skill: Node = null
	var _life: float = 0.0
	var _dealt: bool = false

	func _ready() -> void:
		queue_redraw()
		_apply_damage()

	func _process(delta: float) -> void:
		_life += delta
		if _life >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _apply_damage() -> void:
		if _dealt:
			return
		_dealt = true
		var tree: SceneTree = get_tree()
		if tree == null:
			return
		for e in tree.get_nodes_in_group("enemy"):
			if not (e is Node2D):
				continue
			var d2: float = (e.global_position - global_position).length_squared()
			if d2 > radius * radius:
				continue
			if e.has_method("take_damage"):
				e.take_damage(damage)
				if owner_skill and owner_skill.has_signal("hit_enemy"):
					owner_skill.emit_signal("hit_enemy", e, damage)
			if e.has_method("apply_burn"):
				e.apply_burn(8.0, 3.0)

	func _draw() -> void:
		var t: float = clamp(_life / LIFE, 0.0, 1.0)
		var r: float = radius * (0.4 + 0.7 * t)
		var a: float = 1.0 - t
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.5, 0.1, a * 0.6))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(1.0, 0.9, 0.4, a), 2.0)


func _draw() -> void:
	if _state != State.WINDUP:
		return
	if not is_instance_valid(player) or not (player is Node2D):
		return
	var t: float = clamp(_state_time / WINDUP_DURATION, 0.0, 1.0)
	var height: float = lerp(400.0, 40.0, t)
	var local_origin: Vector2 = Vector2.ZERO
	var top: Vector2 = local_origin + Vector2(0.0, -height)
	var wing: float = lerp(140.0, 60.0, t)
	var body: PackedVector2Array = PackedVector2Array()
	body.push_back(top)
	body.push_back(top + Vector2(-wing, 60.0))
	body.push_back(top + Vector2(-wing * 0.4, 50.0))
	body.push_back(top + Vector2(0.0, 90.0))
	body.push_back(top + Vector2(wing * 0.4, 50.0))
	body.push_back(top + Vector2(wing, 60.0))
	body.push_back(top)
	var inner_col: Color = PHOENIX_INNER
	draw_polygon(body, PackedColorArray([inner_col, PHOENIX_COLOR, PHOENIX_COLOR, inner_col, PHOENIX_COLOR, PHOENIX_COLOR, inner_col]))
	draw_circle(local_origin, 18.0 + 6.0 * t, Color(1.0, 0.85, 0.3, 0.4 + 0.4 * t))
