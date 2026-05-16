class_name Earthquake
extends SkillBase


const SHOCKWAVE_DAMAGE_BY_LEVEL: Array = [80, 120, 160, 200, 220]
const SHOCKWAVE_ATK_COEF_BY_LEVEL: Array = [1.1, 1.6, 2.0, 2.4, 2.8]
const PILLAR_DAMAGE_RATIO: float = 0.30
const PILLAR_DURATION: float = 3.0
const PILLAR_TICK_INTERVAL: float = 1.0
const PILLAR_RADIUS: float = 50.0
const PILLAR_COUNT: int = 15
const STUN_DURATION_BY_LEVEL: Array = [0.7, 0.9, 1.1, 1.3, 1.5]
const BOSS_SLOW_FACTOR: float = 0.5
const BOSS_SLOW_DURATION: float = 1.5
const COOLDOWN_BY_LEVEL: Array = [80.0, 73.0, 66.0, 58.0, 50.0]
const SCREEN_HALF_W: float = 640.0
const SCREEN_HALF_H: float = 360.0
const CRACK_COLOR: Color = Color(0.85, 0.65, 0.25, 0.55)
const PILLAR_COLOR: Color = Color(0.55, 0.40, 0.25, 1.0)
const PILLAR_OUTLINE: Color = Color(0.30, 0.20, 0.12, 1.0)


func _ready() -> void:
	cooldown = 0.0
	super._ready()


func set_level(new_level: int) -> void:
	super.set_level(new_level)
	var idx: int = clamp(level - 1, 0, COOLDOWN_BY_LEVEL.size() - 1)
	base_cooldown = COOLDOWN_BY_LEVEL[idx]


func _physics_process(_delta: float) -> void:
	if is_instance_valid(player) and player is Node2D:
		global_position = (player as Node2D).global_position


func cast_active() -> void:
	var idx: int = clamp(level - 1, 0, SHOCKWAVE_DAMAGE_BY_LEVEL.size() - 1)
	var dmg: int = int(round(float(SHOCKWAVE_DAMAGE_BY_LEVEL[idx]) * damage_multiplier))
	var stun_dur: float = float(STUN_DURATION_BY_LEVEL[idx])
	_apply_screen_shockwave(dmg, stun_dur)
	for i in PILLAR_COUNT:
		var pos: Vector2 = _pick_pillar_position(i)
		_spawn_pillar(pos, max(1, int(round(float(dmg) * PILLAR_DAMAGE_RATIO))))


func _apply_screen_shockwave(dmg: int, stun_dur: float) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not (e is Node2D):
			continue
		if e.has_method("take_damage"):
			e.take_damage(dmg)
		if e.is_in_group("boss"):
			if e.has_method("apply_slow"):
				e.apply_slow(BOSS_SLOW_FACTOR, BOSS_SLOW_DURATION)
		else:
			if e.has_method("apply_stun"):
				e.apply_stun(stun_dur)
		if has_signal("hit_enemy"):
			emit_signal("hit_enemy", e, dmg)


func _pick_pillar_position(i: int) -> Vector2:
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	var candidates: Array = []
	for e in enemies:
		if e is Node2D:
			candidates.append(e)
	if candidates.size() > i:
		candidates.shuffle()
		return (candidates[i] as Node2D).global_position
	var ox: float = randf_range(-SCREEN_HALF_W, SCREEN_HALF_W)
	var oy: float = randf_range(-SCREEN_HALF_H, SCREEN_HALF_H)
	return global_position + Vector2(ox, oy)


func _spawn_pillar(pos: Vector2, tick_dmg: int) -> void:
	var pillar: Pillar = Pillar.new()
	pillar.top_level = true
	pillar.tick_damage = tick_dmg
	pillar.life_left = PILLAR_DURATION
	pillar.tick_interval = PILLAR_TICK_INTERVAL
	pillar.radius = PILLAR_RADIUS
	pillar.owner_skill = self
	add_child(pillar)
	pillar.global_position = pos


class Pillar extends Node2D:
	var tick_damage: int = 24
	var life_left: float = 3.0
	var tick_interval: float = 1.0
	var radius: float = 50.0
	var owner_skill: Node = null
	var _tick_timer: float = 0.0
	var _grow: float = 0.0

	const FILL_COLOR: Color = Color(0.55, 0.40, 0.25, 1.0)
	const OUTLINE_COLOR: Color = Color(0.30, 0.20, 0.12, 1.0)
	const GLOW_COLOR: Color = Color(0.85, 0.65, 0.25, 0.35)

	func _process(delta: float) -> void:
		life_left -= delta
		_grow = min(1.0, _grow + delta * 6.0)
		_tick_timer += delta
		if _tick_timer >= tick_interval:
			_tick_timer = 0.0
			_tick_damage()
		if life_left <= 0.0:
			queue_free()
			return
		queue_redraw()

	func _tick_damage() -> void:
		var r2: float = radius * radius
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e) or not (e is Node2D):
				continue
			var d2: float = ((e as Node2D).global_position - global_position).length_squared()
			if d2 > r2:
				continue
			if e.has_method("take_damage"):
				e.take_damage(tick_damage)
			if owner_skill and owner_skill.has_signal("hit_enemy"):
				owner_skill.emit_signal("hit_enemy", e, tick_damage)

	func _draw() -> void:
		var visual_r: float = radius * _grow
		draw_circle(Vector2.ZERO, visual_r * 1.2, GLOW_COLOR)
		draw_circle(Vector2.ZERO, visual_r, FILL_COLOR)
		draw_arc(Vector2.ZERO, visual_r, 0.0, TAU, 24, OUTLINE_COLOR, 2.0)
		for i in 6:
			var a: float = TAU * float(i) / 6.0
			var p1: Vector2 = Vector2(cos(a), sin(a)) * visual_r * 0.3
			var p2: Vector2 = Vector2(cos(a), sin(a)) * visual_r * 0.95
			draw_line(p1, p2, OUTLINE_COLOR, 2.0)
