class_name ThousandSwords
extends SkillBase


const DROP_INTERVAL_TOTAL: float = 2.0
const MARKER_DURATION: float = 0.3
const SWORD_RADIUS: float = 80.0
const SCREEN_HALF_W: float = 320.0
const SCREEN_HALF_H: float = 180.0
const MARKER_COLOR: Color = Color(1.0, 0.95, 0.3, 0.55)
const SWORD_COLOR: Color = Color(0.95, 0.95, 0.85, 1)
const ELITE_CRIT_BONUS: float = 1.0

# Stage 1~5 stats
const SWORD_DMG: Array = [60, 90, 130, 180, 240]
const ATK_COEF: Array = [0.8, 1.2, 1.7, 2.3, 3.0]
const SWORD_COUNT: Array = [10, 14, 18, 22, 28]
const COOLDOWNS: Array = [100.0, 90.0, 80.0, 70.0, 60.0]


func _ready() -> void:
	cooldown = 0.0
	super._ready()


func set_level(new_level: int) -> void:
	super.set_level(new_level)
	var idx: int = clamp(level - 1, 0, COOLDOWNS.size() - 1)
	base_cooldown = COOLDOWNS[idx]


func _physics_process(_delta: float) -> void:
	if is_instance_valid(player) and player is Node2D:
		global_position = (player as Node2D).global_position


func cast_active() -> void:
	var idx: int = clamp(level - 1, 0, SWORD_COUNT.size() - 1)
	var count: int = int(SWORD_COUNT[idx])
	var dmg: int = int(round(float(SWORD_DMG[idx]) * damage_multiplier))
	for i in count:
		var delay: float = DROP_INTERVAL_TOTAL * float(i) / float(max(count - 1, 1))
		_schedule_drop(delay, dmg)


func _schedule_drop(delay: float, dmg: int) -> void:
	var t: SceneTreeTimer = get_tree().create_timer(delay)
	t.timeout.connect(_spawn_sword.bind(dmg))


func _spawn_sword(dmg: int) -> void:
	var target_pos: Vector2 = _pick_drop_position()
	var sd: SwordDrop = SwordDrop.new()
	sd.top_level = true
	sd.damage = dmg
	sd.radius = SWORD_RADIUS
	sd.marker_duration = MARKER_DURATION
	sd.elite_crit_bonus = ELITE_CRIT_BONUS
	sd.owner_skill = self
	add_child(sd)
	sd.global_position = target_pos


func _pick_drop_position() -> Vector2:
	var elites: Array = get_tree().get_nodes_in_group("elite")
	var candidates: Array = []
	for e in elites:
		if e is Node2D:
			candidates.append(e)
	if candidates.is_empty():
		var bosses: Array = get_tree().get_nodes_in_group("boss")
		for b in bosses:
			if b is Node2D:
				candidates.append(b)
	if not candidates.is_empty():
		var pick: Node2D = candidates[randi() % candidates.size()]
		return pick.global_position
	var ox: float = randf_range(-SCREEN_HALF_W, SCREEN_HALF_W)
	var oy: float = randf_range(-SCREEN_HALF_H, SCREEN_HALF_H)
	return global_position + Vector2(ox, oy)


class SwordDrop extends Node2D:
	var damage: int = 60
	var radius: float = 80.0
	var marker_duration: float = 0.3
	var elite_crit_bonus: float = 1.0
	var owner_skill: Node = null
	var _phase: String = "marker"
	var _time_left: float = 0.0

	func _ready() -> void:
		_phase = "marker"
		_time_left = marker_duration
		queue_redraw()

	func _process(delta: float) -> void:
		_time_left -= delta
		queue_redraw()
		if _phase == "marker" and _time_left <= 0.0:
			_strike()
			queue_free()

	func _strike() -> void:
		var r2: float = radius * radius
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e) or not (e is Node2D):
				continue
			var d2: float = ((e as Node2D).global_position - global_position).length_squared()
			if d2 > r2:
				continue
			var dmg: int = damage
			if e.is_in_group("elite") or e.is_in_group("boss"):
				if randf() < elite_crit_bonus:
					dmg = damage * 2
			if e.has_method("take_damage"):
				e.take_damage(dmg)
			if owner_skill and owner_skill.has_signal("hit_enemy"):
				owner_skill.emit_signal("hit_enemy", e, dmg)

	func _draw() -> void:
		if _phase == "marker":
			draw_circle(Vector2.ZERO, radius, MARKER_COLOR)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, SWORD_COLOR, 2.0)
