class_name Samaejinhwa
extends SkillBase


const MARK_SPAWN_INTERVAL: float = 0.5
const MARK_LIFE: float = 5.0
const MARK_SENSE_RADIUS: float = 50.0
const MARK_EXPLOSION_RADIUS: float = 70.0
const MIN_MOVE_TO_MARK: float = 8.0
const BASE_DAMAGE: int = 30
const BASE_MAX_MARKS: int = 20
const MARK_COLOR: Color = Color(0.98, 0.15, 0.20, 0.85)
const MARK_INNER_COLOR: Color = Color(1.0, 0.6, 0.2, 0.7)


var _spawn_acc: float = 0.0
var _last_mark_pos: Vector2 = Vector2.INF
var _marks: Array[Node2D] = []


func _ready() -> void:
	cooldown = 0.0
	super._ready()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_instance_valid(player) or not (player is Node2D):
		return
	_spawn_acc += delta
	if _spawn_acc < MARK_SPAWN_INTERVAL:
		return
	_spawn_acc = 0.0
	var p_pos: Vector2 = (player as Node2D).global_position
	if _last_mark_pos == Vector2.INF or p_pos.distance_to(_last_mark_pos) >= MIN_MOVE_TO_MARK:
		_spawn_mark(p_pos)
		_last_mark_pos = p_pos


func _spawn_mark(pos: Vector2) -> void:
	var max_marks: int = BASE_MAX_MARKS + 5 * (level - 1)
	while _marks.size() >= max_marks:
		var old: Node2D = _marks.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var dmg: int = int(round(float(BASE_DAMAGE) * damage_multiplier))
	var mark: FlameMark = FlameMark.new()
	mark.top_level = true
	mark.damage = dmg
	mark.life_total = MARK_LIFE
	mark.sense_radius = MARK_SENSE_RADIUS
	mark.explosion_radius = MARK_EXPLOSION_RADIUS
	mark.owner_skill = self
	add_child(mark)
	mark.global_position = pos
	mark.tree_exited.connect(_on_mark_removed.bind(mark))
	_marks.append(mark)


func _on_mark_removed(mark: Node2D) -> void:
	_marks.erase(mark)


class FlameMark extends Node2D:
	const FM_MARK_COLOR: Color = Color(0.98, 0.15, 0.20, 0.85)
	const FM_MARK_INNER_COLOR: Color = Color(1.0, 0.6, 0.2, 0.7)
	var damage: int = 30
	var life_total: float = 5.0
	var sense_radius: float = 50.0
	var explosion_radius: float = 70.0
	var owner_skill: Node = null
	var _life: float = 0.0
	var _exploded: bool = false
	var _exp_anim: float = 0.0

	func _ready() -> void:
		queue_redraw()

	func _process(delta: float) -> void:
		if _exploded:
			_exp_anim += delta
			queue_redraw()
			if _exp_anim >= 0.2:
				queue_free()
			return
		_life += delta
		if _life >= life_total:
			queue_free()
			return
		_check_contact()
		queue_redraw()

	func _check_contact() -> void:
		var tree: SceneTree = get_tree()
		if tree == null:
			return
		for e in tree.get_nodes_in_group("enemy"):
			if not (e is Node2D):
				continue
			var d2: float = (e.global_position - global_position).length_squared()
			if d2 <= sense_radius * sense_radius:
				_explode()
				return

	func _explode() -> void:
		if _exploded:
			return
		_exploded = true
		_exp_anim = 0.0
		var tree: SceneTree = get_tree()
		if tree == null:
			return
		for e in tree.get_nodes_in_group("enemy"):
			if not (e is Node2D):
				continue
			var d2: float = (e.global_position - global_position).length_squared()
			if d2 > explosion_radius * explosion_radius:
				continue
			if e.has_method("take_damage"):
				e.take_damage(damage)
				if owner_skill and owner_skill.has_signal("hit_enemy"):
					owner_skill.emit_signal("hit_enemy", e, damage)
			if e.has_method("apply_burn"):
				e.apply_burn(6.0, 3.0)
			elif e.has_method("apply_dot"):
				e.apply_dot(&"burn", 6.0, 3.0)
		queue_redraw()

	func _draw() -> void:
		if _exploded:
			var t: float = clamp(_exp_anim / 0.2, 0.0, 1.0)
			var r: float = explosion_radius * (0.4 + 0.6 * t)
			var a: float = 1.0 - t
			draw_circle(Vector2.ZERO, r, Color(1.0, 0.45, 0.1, a * 0.8))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(1.0, 0.9, 0.3, a), 2.0)
			return
		var fade: float = clamp(1.0 - (_life / life_total) * 0.6, 0.0, 1.0)
		var pulse: float = 0.85 + 0.15 * sin(_life * 8.0)
		var rr: float = 9.0 * pulse
		draw_circle(Vector2.ZERO, rr * 1.4, Color(FM_MARK_INNER_COLOR.r, FM_MARK_INNER_COLOR.g, FM_MARK_INNER_COLOR.b, FM_MARK_INNER_COLOR.a * fade * 0.5))
		draw_circle(Vector2.ZERO, rr, Color(FM_MARK_COLOR.r, FM_MARK_COLOR.g, FM_MARK_COLOR.b, FM_MARK_COLOR.a * fade))
