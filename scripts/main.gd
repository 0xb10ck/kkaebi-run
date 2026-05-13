extends Node2D

const ENEMY_FIRE: PackedScene = preload("res://scenes/gameplay/enemy_fire.tscn")
const ENEMY_EGG: PackedScene = preload("res://scenes/gameplay/enemy_egg.tscn")
const ENEMY_WATER: PackedScene = preload("res://scenes/gameplay/enemy_water.tscn")
const LEVEL_UP_PANEL: PackedScene = preload("res://scenes/ui/level_up_panel.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const RESULT_SCENE: PackedScene = preload("res://scenes/ui/result_screen.tscn")
const PAUSE_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
const MAIN_MENU_PATH: String = "res://scenes/main_menu/main_menu.tscn"

const STAGE_DURATION: float = 300.0
const SPAWN_INTERVAL_INITIAL: float = 2.0
const SPAWN_INTERVAL_MIN: float = 0.3
const SPAWN_INTERVAL_STEP: float = 0.2
const SPAWN_INTERVAL_PERIOD: float = 30.0

const SPAWN_RADIUS_MIN: float = 300.0
const SPAWN_RADIUS_MAX: float = 400.0

const EGG_FLOCK_MIN: int = 3
const EGG_FLOCK_MAX: int = 5
const EGG_FLOCK_SPREAD: float = 40.0

const COUNT_TIER1_AT: float = 100.0
const COUNT_TIER2_AT: float = 200.0


enum State { PLAYING, DEAD, CLEARED }


@onready var time_left: float = STAGE_DURATION
@onready var player: Node2D = $Player
@onready var enemy_container: Node2D = $EnemyContainer

var _spawn_timer: float = 0.0
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
		_hud.set_hp(int(player.hp), int(player.MAX_HP))
		_hud.set_exp(_current_exp, _current_exp_to_next, _current_level)
	_hud.set_coins(coins)
	_hud.set_time(time_left)


func _on_player_level_up(level: int) -> void:
	_current_level = level
	max_level = max(max_level, level)
	if _hud:
		_hud.set_exp(_current_exp, _current_exp_to_next, level)
		_hud.level_up_effect()
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
	if time_left <= 0.0:
		_on_stage_cleared()
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_wave()
		_spawn_timer = _current_spawn_interval()


func _current_spawn_interval() -> float:
	var elapsed: float = STAGE_DURATION - time_left
	var step_count: int = int(elapsed / SPAWN_INTERVAL_PERIOD)
	var interval: float = SPAWN_INTERVAL_INITIAL - SPAWN_INTERVAL_STEP * float(step_count)
	return maxf(SPAWN_INTERVAL_MIN, interval)


func _current_spawn_count() -> int:
	var elapsed: float = STAGE_DURATION - time_left
	if elapsed < COUNT_TIER1_AT:
		return 1
	if elapsed < COUNT_TIER2_AT:
		return 2
	return 3


func _spawn_wave() -> void:
	var count: int = _current_spawn_count()
	for i in count:
		var pick: int = randi() % 3
		if pick == 0:
			_spawn_single(ENEMY_FIRE)
		elif pick == 1:
			_spawn_egg_flock()
		else:
			_spawn_single(ENEMY_WATER)


func _spawn_single(scene: PackedScene) -> void:
	var enemy: Node2D = scene.instantiate()
	enemy.global_position = _random_spawn_point()
	enemy_container.add_child(enemy)


func _spawn_egg_flock() -> void:
	var center: Vector2 = _random_spawn_point()
	var n: int = randi_range(EGG_FLOCK_MIN, EGG_FLOCK_MAX)
	for i in n:
		var offset: Vector2 = Vector2(
			randf_range(-EGG_FLOCK_SPREAD, EGG_FLOCK_SPREAD),
			randf_range(-EGG_FLOCK_SPREAD, EGG_FLOCK_SPREAD)
		)
		var enemy: Node2D = ENEMY_EGG.instantiate()
		enemy.global_position = center + offset
		enemy_container.add_child(enemy)


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
