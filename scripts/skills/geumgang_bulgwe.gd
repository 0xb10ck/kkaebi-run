class_name GeumgangBulgwe
extends SkillBase


const HP_TRIGGER_RATIO: float = 0.30
const RADIUS_PX: float = 70.0
const TICK_INTERVAL: float = 0.25
const BODY_COLOR: Color = Color(0.99, 0.85, 0.30, 0.55)
const BODY_RADIUS: float = 22.0

# Stage 1~5 stats
const INVULN_S: Array = [3.0, 3.5, 4.0, 4.5, 5.0]
const CONTACT_DPS: Array = [50, 75, 100, 125, 150]
const ATK_COEF: Array = [0.7, 1.0, 1.3, 1.55, 1.8]
const COOLDOWNS: Array = [90.0, 80.0, 72.0, 66.0, 60.0]


var _active: bool = false
var _active_time_left: float = 0.0
var _tick_accumulator: float = 0.0
var _ready_to_trigger: bool = true
var _cooldown_timer: float = 0.0
var _was_invulnerable_before: bool = false


func _ready() -> void:
	cooldown = 0.0
	super._ready()


func set_level(new_level: int) -> void:
	super.set_level(new_level)
	var idx: int = clamp(level - 1, 0, COOLDOWNS.size() - 1)
	base_cooldown = COOLDOWNS[idx]


func _physics_process(delta: float) -> void:
	if is_instance_valid(player) and player is Node2D:
		global_position = (player as Node2D).global_position

	if not _ready_to_trigger:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			_ready_to_trigger = true

	if _active:
		_tick_active(delta)
	else:
		_check_trigger()


func _check_trigger() -> void:
	if not _ready_to_trigger:
		return
	if not is_instance_valid(player):
		return
	var hp: float = _get_player_hp()
	var max_hp: float = _get_player_max_hp()
	if max_hp <= 0.0:
		return
	if hp / max_hp <= HP_TRIGGER_RATIO:
		_activate()


func _activate() -> void:
	_active = true
	var idx: int = clamp(level - 1, 0, INVULN_S.size() - 1)
	_active_time_left = float(INVULN_S[idx])
	_tick_accumulator = 0.0
	_ready_to_trigger = false
	_cooldown_timer = float(COOLDOWNS[idx])
	if is_instance_valid(player):
		if player.has_method("set_invulnerable"):
			player.set_invulnerable(true)
		elif "invulnerable" in player:
			_was_invulnerable_before = bool(player.invulnerable)
			player.invulnerable = true
	queue_redraw()


func _deactivate() -> void:
	_active = false
	if is_instance_valid(player):
		if player.has_method("set_invulnerable"):
			player.set_invulnerable(false)
		elif "invulnerable" in player:
			player.invulnerable = _was_invulnerable_before
	queue_redraw()


func _tick_active(delta: float) -> void:
	_active_time_left -= delta
	_tick_accumulator += delta
	while _tick_accumulator >= TICK_INTERVAL:
		_tick_accumulator -= TICK_INTERVAL
		_apply_contact_damage()
	if _active_time_left <= 0.0:
		_deactivate()


func _apply_contact_damage() -> void:
	var idx: int = clamp(level - 1, 0, CONTACT_DPS.size() - 1)
	var dps: float = float(CONTACT_DPS[idx])
	var tick_damage: int = int(round(dps * TICK_INTERVAL * damage_multiplier))
	if tick_damage <= 0:
		return
	var r2: float = RADIUS_PX * RADIUS_PX
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not (e is Node2D):
			continue
		var d2: float = ((e as Node2D).global_position - global_position).length_squared()
		if d2 <= r2 and e.has_method("take_damage"):
			e.take_damage(tick_damage)
			hit_enemy.emit(e, tick_damage)


func _get_player_hp() -> float:
	if not is_instance_valid(player):
		return 0.0
	if "hp" in player:
		return float(player.hp)
	if "current_hp" in player:
		return float(player.current_hp)
	return 0.0


func _get_player_max_hp() -> float:
	if not is_instance_valid(player):
		return 0.0
	if "max_hp" in player:
		return float(player.max_hp)
	return 0.0


func _draw() -> void:
	if _active:
		draw_circle(Vector2.ZERO, BODY_RADIUS, BODY_COLOR)
