class_name ForestWrath
extends SkillBase


const DAMAGE_BASE: int = 35
const STRIKE_COUNT: int = 18
const SPREAD_WINDOW_S: float = 3.0
const STRIKE_RADIUS_PX: float = 60.0
const TELEGRAPH_S: float = 0.2
const TELEGRAPH_COLOR: Color = Color(0.50, 0.85, 0.45, 0.35)
const STRIKE_COLOR: Color = Color(0.20, 0.60, 0.20, 1.0)
const THORN_COLOR: Color = Color(0.12, 0.45, 0.18, 1.0)


var _pending: Array = []  # array of dicts {time, pos}
var _in_progress: bool = false
var _window_t: float = 0.0


func _ready() -> void:
	cooldown = 70.0
	super._ready()


func _cast() -> void:
	if _in_progress:
		return
	_in_progress = true
	_window_t = 0.0
	_pending.clear()
	for i in STRIKE_COUNT:
		var t: float = randf() * SPREAD_WINDOW_S
		_pending.append({"time": t, "pos": _random_screen_pos()})
	_pending.sort_custom(func(a, b): return a.time < b.time)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _in_progress:
		return
	_window_t += delta
	while not _pending.is_empty() and _pending[0].time <= _window_t:
		var entry: Dictionary = _pending.pop_front()
		_spawn_strike(entry.pos)
	if _pending.is_empty() and _window_t >= SPREAD_WINDOW_S:
		_in_progress = false


func _random_screen_pos() -> Vector2:
	var vp: Vector2 = Vector2(1280.0, 720.0)
	var tree: SceneTree = get_tree()
	if tree and tree.root:
		vp = tree.root.get_visible_rect().size
	var cam_pos: Vector2 = Vector2.ZERO
	if is_instance_valid(player) and player is Node2D:
		cam_pos = (player as Node2D).global_position
	var half: Vector2 = vp * 0.5
	var x: float = cam_pos.x + randf_range(-half.x + 40.0, half.x - 40.0)
	var y: float = cam_pos.y + randf_range(-half.y + 40.0, half.y - 40.0)
	return Vector2(x, y)


func _spawn_strike(pos: Vector2) -> void:
	var dmg: int = int(round(float(DAMAGE_BASE) * damage_multiplier))
	var st: ThornStrike = ThornStrike.new()
	st.top_level = true
	st.damage = dmg
	st.radius_px = STRIKE_RADIUS_PX
	st.telegraph_s = TELEGRAPH_S
	st.owner_skill = self
	add_child(st)
	st.global_position = pos


class ThornStrike extends Node2D:
	var damage: int = 35
	var radius_px: float = 60.0
	var telegraph_s: float = 0.2
	var owner_skill: Node = null
	var _t: float = 0.0
	var _struck: bool = false
	var _fade: float = 0.0

	func _ready() -> void:
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		if not _struck and _t >= telegraph_s:
			_strike()
		if _struck:
			_fade += delta
			queue_redraw()
			if _fade >= 0.25:
				queue_free()

	func _strike() -> void:
		_struck = true
		for e in get_tree().get_nodes_in_group("enemy"):
			if not (e is Node2D):
				continue
			if global_position.distance_to((e as Node2D).global_position) <= radius_px:
				if e.has_method("take_damage"):
					e.take_damage(damage)
					if owner_skill and owner_skill.has_signal("hit_enemy"):
						owner_skill.emit_signal("hit_enemy", e, damage)
		queue_redraw()

	func _draw() -> void:
		if not _struck:
			draw_circle(Vector2.ZERO, radius_px, ForestWrath.TELEGRAPH_COLOR)
			return
		var alpha: float = clampf(1.0 - _fade / 0.25, 0.0, 1.0)
		var ring: Color = ForestWrath.STRIKE_COLOR
		ring.a = alpha
		draw_arc(Vector2.ZERO, radius_px, 0.0, TAU, 32, ring, 3.0)
		var spikes: int = 12
		for i in spikes:
			var a: float = TAU * float(i) / float(spikes)
			var inner: Vector2 = Vector2(cos(a), sin(a)) * (radius_px * 0.55)
			var outer: Vector2 = Vector2(cos(a), sin(a)) * radius_px
			var c: Color = ForestWrath.THORN_COLOR
			c.a = alpha
			draw_line(inner, outer, c, 3.0)
