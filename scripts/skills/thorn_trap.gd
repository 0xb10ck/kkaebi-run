class_name ThornTrap
extends SkillBase


const TRAP_DAMAGE_BY_LEVEL: Array = [50, 70, 95, 115, 130]
const TRAP_COEF_BY_LEVEL: Array = [0.7, 0.95, 1.2, 1.45, 1.7]
const TRAP_COUNT_BY_LEVEL: Array = [2, 2, 3, 3, 4]
const COOLDOWN_BY_LEVEL: Array = [15.0, 13.0, 11.0, 10.0, 9.0]
const TRAP_LIFE: float = 10.0
const TRIGGER_RADIUS: float = 40.0
const BLAST_RADIUS: float = 100.0
const STUN_DURATION: float = 0.5
const PLACE_RANGE: float = 320.0


func _ready() -> void:
	cooldown = COOLDOWN_BY_LEVEL[0]
	super._ready()


func set_level(new_level: int) -> void:
	super.set_level(new_level)
	var idx: int = clamp(level - 1, 0, COOLDOWN_BY_LEVEL.size() - 1)
	base_cooldown = COOLDOWN_BY_LEVEL[idx]
	cooldown = base_cooldown


func _current_damage() -> int:
	var idx: int = clamp(level - 1, 0, TRAP_DAMAGE_BY_LEVEL.size() - 1)
	return int(round(float(TRAP_DAMAGE_BY_LEVEL[idx]) * damage_multiplier))


func _current_count() -> int:
	var idx: int = clamp(level - 1, 0, TRAP_COUNT_BY_LEVEL.size() - 1)
	return int(TRAP_COUNT_BY_LEVEL[idx])


func _cast() -> void:
	var positions: Array = _pick_positions(_current_count())
	for pos in positions:
		_spawn_trap(pos)


func _pick_positions(count: int) -> Array:
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	var result: Array = []
	var candidates: Array = []
	for e in enemies:
		if not is_instance_valid(e) or not (e is Node2D):
			continue
		var d: float = (e.global_position - global_position).length()
		if d <= PLACE_RANGE:
			candidates.append(e)
	candidates.shuffle()
	for i in range(min(count, candidates.size())):
		result.append((candidates[i] as Node2D).global_position)
	# fill remaining with random offset near player
	while result.size() < count:
		var ang: float = randf() * TAU
		var dist: float = randf_range(60.0, PLACE_RANGE)
		result.append(global_position + Vector2(cos(ang), sin(ang)) * dist)
	return result


func _spawn_trap(pos: Vector2) -> void:
	var trap: Trap = Trap.new()
	trap.top_level = true
	trap.trap_damage = _current_damage()
	trap.life_left = TRAP_LIFE
	trap.trigger_radius = TRIGGER_RADIUS
	trap.blast_radius = BLAST_RADIUS
	trap.stun_duration = STUN_DURATION
	trap.owner_skill = self
	add_child(trap)
	trap.global_position = pos


class Trap extends Node2D:
	var trap_damage: int = 50
	var life_left: float = 10.0
	var trigger_radius: float = 40.0
	var blast_radius: float = 100.0
	var stun_duration: float = 0.5
	var owner_skill: Node = null
	var _triggered: bool = false
	var _flash: float = 0.0

	const TRAP_COLOR: Color = Color(0.50, 0.45, 0.25, 0.55)
	const TRAP_OUTLINE: Color = Color(0.35, 0.30, 0.18, 0.85)
	const FLASH_COLOR: Color = Color(0.85, 0.20, 0.20, 0.55)

	func _process(delta: float) -> void:
		life_left -= delta
		if _flash > 0.0:
			_flash -= delta
		if _triggered:
			if _flash <= 0.0:
				queue_free()
			else:
				queue_redraw()
			return
		if life_left <= 0.0:
			queue_free()
			return
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e) or not (e is Node2D):
				continue
			var d: float = (e.global_position - global_position).length()
			if d <= trigger_radius:
				_trigger(e)
				return
		queue_redraw()

	func _trigger(stepper: Node) -> void:
		_triggered = true
		_flash = 0.3
		var stepper_class: String = ""
		if stepper is Node:
			stepper_class = (stepper as Node).get_class()
		var stepper_script_name: String = ""
		if stepper is Node and (stepper as Node).get_script():
			var s = (stepper as Node).get_script()
			if s and s.resource_path:
				stepper_script_name = s.resource_path
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e) or not (e is Node2D):
				continue
			var d: float = (e.global_position - global_position).length()
			if d <= blast_radius:
				if e.has_method("take_damage"):
					e.take_damage(trap_damage)
				if owner_skill and owner_skill.has_signal("hit_enemy"):
					owner_skill.emit_signal("hit_enemy", e, trap_damage)
		# stun same-type enemies on screen
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e):
				continue
			var same: bool = false
			if stepper_script_name != "" and e is Node and (e as Node).get_script():
				var sc = (e as Node).get_script()
				if sc and sc.resource_path == stepper_script_name:
					same = true
			elif stepper_class != "" and e is Node and (e as Node).get_class() == stepper_class:
				same = true
			if same and e.has_method("apply_stun"):
				e.apply_stun(stun_duration)
		queue_redraw()

	func _draw() -> void:
		if _triggered:
			draw_circle(Vector2.ZERO, blast_radius, FLASH_COLOR)
			return
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		var col: Color = TRAP_COLOR
		col.a = 0.35 + 0.25 * pulse
		draw_circle(Vector2.ZERO, trigger_radius, col)
		draw_arc(Vector2.ZERO, trigger_radius, 0.0, TAU, 24, TRAP_OUTLINE, 1.5)
		# thorn spikes
		for i in range(8):
			var a: float = TAU * float(i) / 8.0
			var p1: Vector2 = Vector2(cos(a), sin(a)) * trigger_radius * 0.4
			var p2: Vector2 = Vector2(cos(a), sin(a)) * trigger_radius * 0.9
			draw_line(p1, p2, TRAP_OUTLINE, 2.0)
