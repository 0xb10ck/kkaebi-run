class_name MetalChain
extends SkillBase


const RANGE_PX: float = 500.0
const CHAIN_COLOR: Color = Color(0.85, 0.75, 0.25, 1)
const CHAIN_WIDTH: float = 3.0
const CHAIN_DURATION: float = 0.35
const PULL_DURATION: float = 0.3

# LV1~5 stats
const DAMAGE_BASE: Array = [25, 35, 50, 60, 70]
const ATK_COEF: Array = [0.4, 0.6, 0.85, 0.95, 1.1]
const COOLDOWNS: Array = [9.0, 8.0, 7.0, 6.0, 5.0]
const PULL_DISTANCE: Array = [80.0, 110.0, 140.0, 170.0, 200.0]
const BIND_DURATION: Array = [1.0, 1.25, 1.5, 1.75, 2.0]


var _active_chains: Array = []


func _ready() -> void:
	cooldown = COOLDOWNS[0]
	super._ready()


func set_level(new_level: int) -> void:
	super.set_level(new_level)
	var idx: int = clamp(level - 1, 0, COOLDOWNS.size() - 1)
	base_cooldown = COOLDOWNS[idx]
	cooldown = COOLDOWNS[idx]


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_tick_chains(delta)


func _tick_chains(delta: float) -> void:
	if _active_chains.is_empty():
		return
	for c in _active_chains:
		c.time_left -= delta
		if is_instance_valid(c.target) and c.pull_time_left > 0.0:
			var step: float = delta / PULL_DURATION
			var pull_vec: Vector2 = c.pull_dir * c.pull_distance * step
			(c.target as Node2D).global_position += pull_vec
			c.pull_time_left -= delta
	_active_chains = _active_chains.filter(func(c): return c.time_left > 0.0)
	queue_redraw()


func _draw() -> void:
	for c in _active_chains:
		if not is_instance_valid(c.target):
			continue
		var local_to: Vector2 = to_local((c.target as Node2D).global_position)
		draw_line(Vector2.ZERO, local_to, CHAIN_COLOR, CHAIN_WIDTH)


func _cast() -> void:
	var target: Node2D = _pick_target()
	if not is_instance_valid(target):
		return
	var idx: int = clamp(level - 1, 0, DAMAGE_BASE.size() - 1)
	var dmg: int = int(round(float(DAMAGE_BASE[idx]) * damage_multiplier))
	var bind_s: float = float(BIND_DURATION[idx])
	var pull_dist: float = float(PULL_DISTANCE[idx])
	if target.has_method("take_damage"):
		target.take_damage(dmg)
		hit_enemy.emit(target, dmg)
	if target.has_method("apply_stun"):
		target.apply_stun(bind_s)
	elif "is_bound" in target:
		target.is_bound = true
	var dir_to_player: Vector2 = (global_position - target.global_position).normalized()
	if dir_to_player == Vector2.ZERO:
		dir_to_player = Vector2.RIGHT
	_active_chains.append({
		"target": target,
		"time_left": CHAIN_DURATION,
		"pull_time_left": PULL_DURATION,
		"pull_dir": dir_to_player,
		"pull_distance": pull_dist,
	})
	queue_redraw()


func _pick_target() -> Node2D:
	var range2: float = RANGE_PX * RANGE_PX
	var elite_target: Node2D = null
	var elite_d2: float = INF
	var farthest: Node2D = null
	var max_d2: float = -1.0
	var elites: Array = get_tree().get_nodes_in_group("elite")
	for e in elites:
		if not (e is Node2D):
			continue
		var d2: float = (e.global_position - global_position).length_squared()
		if d2 <= range2 and d2 < elite_d2:
			elite_d2 = d2
			elite_target = e
	if is_instance_valid(elite_target):
		return elite_target
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node2D):
			continue
		var d2: float = (e.global_position - global_position).length_squared()
		if d2 <= range2 and d2 > max_d2:
			max_d2 = d2
			farthest = e
	return farthest
