class_name FlameBarrier
extends SkillBase


const HP_TRIGGER_RATIO: float = 0.70
const BARRIER_RADIUS: float = 110.0
const DAMAGE_PER_SECOND: int = 12
const DURATION: float = 5.0
const TICK_INTERVAL: float = 0.25
const KNOCKBACK_PX: float = 30.0
const RING_COLOR: Color = Color(0.9, 0.3, 0.1, 0.55)
const RING_INNER_COLOR: Color = Color(1.0, 0.7, 0.3, 0.25)
const RING_SEGMENTS: int = 48


@onready var _area: Area2D = $Area2D


var _active: bool = false
var _active_time: float = 0.0
var _tick_acc: float = 0.0
var _since_last_activation: float = INF
var _inside_last_tick: Dictionary = {}


func _ready() -> void:
	cooldown = 18.0
	base_cooldown = cooldown
	super._ready()
	_since_last_activation = base_cooldown


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_since_last_activation += delta
	_maybe_activate()
	if _active:
		_active_time += delta
		_tick_acc += delta
		if _tick_acc >= TICK_INTERVAL:
			_tick_acc -= TICK_INTERVAL
			_tick_damage()
		if _active_time >= DURATION:
			_deactivate()
	queue_redraw()


func _maybe_activate() -> void:
	if _active:
		return
	if _since_last_activation < base_cooldown:
		return
	if not is_instance_valid(player):
		return
	var hp: float = float(player.get("hp")) if player.get("hp") != null else -1.0
	var max_hp: float = float(player.get("max_hp")) if player.get("max_hp") != null else -1.0
	if hp <= 0.0 or max_hp <= 0.0:
		return
	if hp / max_hp <= HP_TRIGGER_RATIO:
		_activate()


func _activate() -> void:
	_active = true
	_active_time = 0.0
	_tick_acc = 0.0
	_since_last_activation = 0.0
	_inside_last_tick.clear()
	queue_redraw()


func _deactivate() -> void:
	_active = false
	_inside_last_tick.clear()
	queue_redraw()


func _tick_damage() -> void:
	var dmg_per_sec: int = int(round(float(DAMAGE_PER_SECOND) * damage_multiplier))
	var dmg_tick: int = int(round(float(dmg_per_sec) * TICK_INTERVAL))
	var current_inside: Dictionary = {}
	var enemies: Array = []
	if _area:
		enemies = _area.get_overlapping_bodies()
	else:
		enemies = get_tree().get_nodes_in_group("enemy")
	for body in enemies:
		if not is_instance_valid(body):
			continue
		if not body.is_in_group("enemy"):
			continue
		var id: int = body.get_instance_id()
		current_inside[id] = true
		if dmg_tick > 0 and body.has_method("take_damage"):
			body.take_damage(dmg_tick)
			hit_enemy.emit(body, dmg_tick)
		if not _inside_last_tick.has(id):
			_apply_knockback(body)
	_inside_last_tick = current_inside


func _apply_knockback(body: Node) -> void:
	if not is_instance_valid(body) or not (body is Node2D):
		return
	var dir: Vector2 = (body as Node2D).global_position - global_position
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	if body.has_method("apply_knockback"):
		body.apply_knockback(dir * KNOCKBACK_PX)
	elif body.has_method("apply_impulse"):
		body.apply_impulse(dir * KNOCKBACK_PX)
	else:
		(body as Node2D).global_position += dir * KNOCKBACK_PX


func _draw() -> void:
	if not _active:
		return
	var flicker: float = 0.85 + 0.15 * sin(_active_time * 18.0)
	var r: float = BARRIER_RADIUS * flicker
	var inner_col: Color = Color(RING_INNER_COLOR.r, RING_INNER_COLOR.g, RING_INNER_COLOR.b, RING_INNER_COLOR.a * flicker)
	draw_circle(Vector2.ZERO, r, inner_col)
	var prev: Vector2 = Vector2(r, 0.0)
	for i in range(1, RING_SEGMENTS + 1):
		var a: float = TAU * float(i) / float(RING_SEGMENTS)
		var cur: Vector2 = Vector2(cos(a), sin(a)) * r
		draw_line(prev, cur, RING_COLOR, 3.0)
		prev = cur
