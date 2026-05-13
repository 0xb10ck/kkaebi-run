extends Node2D

const ENEMY_FIRE: PackedScene = preload("res://scenes/gameplay/enemy_fire.tscn")
const ENEMY_EGG: PackedScene = preload("res://scenes/gameplay/enemy_egg.tscn")
const ENEMY_WATER: PackedScene = preload("res://scenes/gameplay/enemy_water.tscn")
const LEVEL_UP_PANEL: PackedScene = preload("res://scenes/ui/level_up_panel.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const RESULT_SCENE: PackedScene = preload("res://scenes/ui/result_screen.tscn")
const PAUSE_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
const TOAST_SCENE: PackedScene = preload("res://scenes/ui/toast.tscn")
const MAIN_MENU_PATH: String = "res://scenes/main_menu/main_menu.tscn"

const STAGE_DURATION: float = 300.0

const SPAWN_RADIUS_MIN: float = 300.0
const SPAWN_RADIUS_MAX: float = 400.0

const EGG_FLOCK_SIZE: int = 4
const EGG_FLOCK_SPACING: float = 30.0

const ENEMY_CAP: int = 120
const ZERO_POLL_INTERVAL: float = 1.0

# §7.5 toast copy.
const TOAST_START: String = "도깨비님, 두멍마을을 지켜 주십시오."
const TOAST_FIRST_LEVEL: String = "힘이 차오릅니다. 신통을 골라 주십시오."
const TOAST_AT_90S: String = "물귀신이 다가옵니다. 발을 조심하십시오."
const TOAST_AT_240S: String = "검은 안개가 짙어집니다. 곧 끝이 보입니다."
const TOAST_AT_290S: String = "잠시만 더 버텨 주십시오."
const TOAST_CLEAR_IMMINENT: String = "두멍마을의 새벽이 밝아옵니다."

# Fire the "clear imminent" toast a few seconds before the stage clears so the
# 1.5s toast fully plays before the result screen takes over.
const TOAST_CLEAR_IMMINENT_AT: float = 297.0

# §5.2 spawn curve. Rows are sorted by t_start ascending — _current_tier() picks
# the latest row whose t_start <= elapsed. {type}_n=0 means that type is off in
# the tier; in that case the timer polls every ZERO_POLL_INTERVAL seconds.
const SPAWN_TIERS: Array = [
	{"t_start":   0.0, "fire_n":  8, "fire_p": 15.0, "egg_n": 0, "egg_p": 20.0, "water_n": 0, "water_p": 30.0},
	{"t_start":  30.0, "fire_n": 12, "fire_p": 15.0, "egg_n": 1, "egg_p": 20.0, "water_n": 0, "water_p": 30.0},
	{"t_start":  90.0, "fire_n": 16, "fire_p": 15.0, "egg_n": 2, "egg_p": 20.0, "water_n": 1, "water_p": 30.0},
	{"t_start": 150.0, "fire_n": 24, "fire_p": 15.0, "egg_n": 3, "egg_p": 20.0, "water_n": 1, "water_p": 20.0},
	{"t_start": 210.0, "fire_n": 32, "fire_p": 15.0, "egg_n": 4, "egg_p": 20.0, "water_n": 2, "water_p": 20.0},
	{"t_start": 270.0, "fire_n": 40, "fire_p": 10.0, "egg_n": 6, "egg_p": 15.0, "water_n": 3, "water_p": 15.0},
]


enum State { PLAYING, DEAD, CLEARED }


@onready var time_left: float = STAGE_DURATION
@onready var player: Node2D = $Player
@onready var enemy_container: Node2D = $EnemyContainer

var _fire_timer: float = 0.0
var _egg_timer: float = 0.0
var _water_timer: float = 0.0
var skill_manager: SkillManager
var level_up_panel: CanvasLayer
var _level_up_queue: int = 0
var _level_up_showing: bool = false

var _state: int = State.PLAYING
var kill_count: int = 0
var coins: int = 0
var max_level: int = 1

var _current_exp: int = 0
var _current_exp_to_next: int = 10
var _current_level: int = 1

var _hud: CanvasLayer
var _result_screen: CanvasLayer
var _pause_menu: CanvasLayer
var _toast: CanvasLayer

var _toast_first_level_done: bool = false
var _toast_90_done: bool = false
var _toast_240_done: bool = false
var _toast_290_done: bool = false
var _toast_clear_done: bool = false


func _ready() -> void:
	get_tree().paused = false
	skill_manager = SkillManager.new()
	skill_manager.name = "SkillManager"
	add_child(skill_manager)
	level_up_panel = LEVEL_UP_PANEL.instantiate()
	add_child(level_up_panel)
	if level_up_panel.has_signal("closed"):
		level_up_panel.closed.connect(_on_level_up_panel_closed)

	_hud = HUD_SCENE.instantiate()
	add_child(_hud)
	_pause_menu = PAUSE_SCENE.instantiate()
	add_child(_pause_menu)
	_result_screen = RESULT_SCENE.instantiate()
	add_child(_result_screen)
	_toast = TOAST_SCENE.instantiate()
	add_child(_toast)

	if is_instance_valid(player):
		if player.has_signal("hp_changed"):
			player.hp_changed.connect(_on_player_hp_changed)
		if player.has_signal("exp_changed"):
			player.exp_changed.connect(_on_player_exp_changed)
		if player.has_signal("level_up"):
			player.level_up.connect(_on_player_level_up)
		if player.has_signal("died"):
			player.died.connect(_on_player_died)

	_hud.pause_pressed.connect(_pause_menu.open_pause)
	_pause_menu.restart_pressed.connect(_on_restart_requested)
	_pause_menu.main_menu_pressed.connect(_on_main_menu_requested)
	_result_screen.restart_pressed.connect(_on_restart_requested)
	_result_screen.main_menu_pressed.connect(_on_main_menu_requested)

	if is_instance_valid(player):
		_current_level = int(player.level)
		max_level = _current_level
		_current_exp = int(player.exp)
		_current_exp_to_next = int(player.exp_to_next)
		_hud.set_hp(int(player.hp), int(player.max_hp))
		_hud.set_exp(_current_exp, _current_exp_to_next, _current_level)
	_hud.set_coins(coins)
	_hud.set_time(time_left)

	_show_toast(TOAST_START)


func _on_player_level_up(level: int) -> void:
	_current_level = level
	max_level = max(max_level, level)
	if _hud:
		_hud.set_exp(_current_exp, _current_exp_to_next, level)
		_hud.level_up_effect()
	if not _toast_first_level_done:
		_toast_first_level_done = true
		_show_toast(TOAST_FIRST_LEVEL)
	_level_up_queue += 1
	_present_next_offer()


func _on_player_hp_changed(hp: int, max_hp: int) -> void:
	if _hud:
		_hud.set_hp(hp, max_hp)


func _on_player_exp_changed(exp_value: int, exp_to_next: int) -> void:
	_current_exp = exp_value
	_current_exp_to_next = exp_to_next
	if _hud:
		_hud.set_exp(exp_value, exp_to_next, _current_level)


func _on_player_died() -> void:
	if _state != State.PLAYING:
		return
	_state = State.DEAD
	if _pause_menu:
		_pause_menu.set_locked(true)
	var survive_sec: int = int(round(STAGE_DURATION - time_left))
	if _result_screen:
		_result_screen.show_result(survive_sec, kill_count, max_level, coins)


func _on_stage_cleared() -> void:
	if _state != State.PLAYING:
		return
	_state = State.CLEARED
	if _pause_menu:
		_pause_menu.set_locked(true)
	if _result_screen:
		_result_screen.show_result(int(STAGE_DURATION), kill_count, max_level, coins)


func _on_restart_requested() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_main_menu_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _present_next_offer() -> void:
	if _level_up_showing:
		return
	if _level_up_queue <= 0:
		return
	if not is_instance_valid(skill_manager) or not is_instance_valid(level_up_panel) or not is_instance_valid(player):
		return
	if _state != State.PLAYING:
		_level_up_queue = 0
		return
	var offers: Array = skill_manager.get_offer()
	if offers.is_empty():
		_level_up_queue = 0
		return
	_level_up_showing = true
	if _pause_menu:
		_pause_menu.set_locked(true)
	level_up_panel.show_offer(offers, player, skill_manager)


func _on_level_up_panel_closed() -> void:
	_level_up_showing = false
	_level_up_queue = max(0, _level_up_queue - 1)
	if _pause_menu and _state == State.PLAYING:
		_pause_menu.set_locked(false)
	_present_next_offer()


# Called by Enemy.die() — see scripts/enemy.gd
func on_enemy_killed() -> void:
	kill_count += 1


# Called by Enemy.die() — see scripts/enemy.gd
func on_coin_dropped(amount: int) -> void:
	coins += amount
	if _hud:
		_hud.set_coins(coins)


func _process(delta: float) -> void:
	if _state != State.PLAYING:
		return
	time_left = maxf(0.0, time_left - delta)
	if _hud:
		_hud.set_time(time_left)
	var elapsed: float = STAGE_DURATION - time_left
	_tick_time_toasts(elapsed)
	if time_left <= 0.0:
		_on_stage_cleared()
		return
	_tick_spawns(delta)


func _tick_time_toasts(elapsed: float) -> void:
	if not _toast_90_done and elapsed >= 90.0:
		_toast_90_done = true
		_show_toast(TOAST_AT_90S)
	if not _toast_240_done and elapsed >= 240.0:
		_toast_240_done = true
		_show_toast(TOAST_AT_240S)
	if not _toast_290_done and elapsed >= 290.0:
		_toast_290_done = true
		_show_toast(TOAST_AT_290S)
	if not _toast_clear_done and elapsed >= TOAST_CLEAR_IMMINENT_AT:
		_toast_clear_done = true
		_show_toast(TOAST_CLEAR_IMMINENT)


func _show_toast(text: String) -> void:
	if _toast and _toast.has_method("show_message"):
		_toast.show_message(text)


func _tick_spawns(delta: float) -> void:
	var elapsed: float = STAGE_DURATION - time_left
	var tier: Dictionary = _current_tier(elapsed)

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		if int(tier["fire_n"]) > 0:
			_spawn_single(ENEMY_FIRE, elapsed)
			_fire_timer = float(tier["fire_p"]) / float(tier["fire_n"])
		else:
			_fire_timer = ZERO_POLL_INTERVAL

	_egg_timer -= delta
	if _egg_timer <= 0.0:
		if int(tier["egg_n"]) > 0:
			_spawn_egg_flock(elapsed)
			_egg_timer = float(tier["egg_p"]) / float(tier["egg_n"])
		else:
			_egg_timer = ZERO_POLL_INTERVAL

	_water_timer -= delta
	if _water_timer <= 0.0:
		if int(tier["water_n"]) > 0:
			_spawn_single(ENEMY_WATER, elapsed)
			_water_timer = float(tier["water_p"]) / float(tier["water_n"])
		else:
			_water_timer = ZERO_POLL_INTERVAL


func _current_tier(elapsed: float) -> Dictionary:
	var picked: Dictionary = SPAWN_TIERS[0]
	for row in SPAWN_TIERS:
		if elapsed >= float(row["t_start"]):
			picked = row
		else:
			break
	return picked


func _spawn_single(scene: PackedScene, elapsed: float) -> void:
	_enforce_cap(1)
	var enemy: Node2D = scene.instantiate()
	enemy.global_position = _random_spawn_point()
	enemy_container.add_child(enemy)
	if enemy.has_method("apply_time_scaling"):
		enemy.apply_time_scaling(elapsed)


func _spawn_egg_flock(elapsed: float) -> void:
	_enforce_cap(EGG_FLOCK_SIZE)
	var center: Vector2 = _random_spawn_point()
	var half: float = EGG_FLOCK_SPACING * 0.5
	var offsets: Array = [
		Vector2(-half, -half),
		Vector2( half, -half),
		Vector2(-half,  half),
		Vector2( half,  half),
	]
	for off in offsets:
		var enemy: Node2D = ENEMY_EGG.instantiate()
		enemy.global_position = center + off
		enemy_container.add_child(enemy)
		if enemy.has_method("apply_time_scaling"):
			enemy.apply_time_scaling(elapsed)


func _enforce_cap(extra: int) -> void:
	var available: int = ENEMY_CAP - enemy_container.get_child_count()
	while available < extra:
		var farthest: Node2D = _find_farthest_enemy()
		if farthest == null:
			return
		enemy_container.remove_child(farthest)
		farthest.queue_free()
		available += 1


func _find_farthest_enemy() -> Node2D:
	if not is_instance_valid(player):
		return null
	var farthest: Node2D = null
	var max_dist_sq: float = -1.0
	var ppos: Vector2 = player.global_position
	for child in enemy_container.get_children():
		if not (child is Enemy):
			continue
		if child.is_dying:
			continue
		var d: float = (child.global_position - ppos).length_squared()
		if d > max_dist_sq:
			max_dist_sq = d
			farthest = child
	return farthest


func _random_spawn_point() -> Vector2:
	if not is_instance_valid(player):
		return Vector2.ZERO
	var side: int = randi() % 4
	var base_angle: float
	match side:
		0:
			base_angle = -PI / 2.0
		1:
			base_angle = PI / 2.0
		2:
			base_angle = PI
		_:
			base_angle = 0.0
	var angle: float = base_angle + randf_range(-PI / 4.0, PI / 4.0)
	var radius: float = randf_range(SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX)
	return player.global_position + Vector2(cos(angle), sin(angle)) * radius
