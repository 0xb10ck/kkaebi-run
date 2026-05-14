extends Node2D

# §4 — ChapterData 기반 스테이지 씬.
# ChapterManager.current_chapter_data로부터 스테이지 길이/배경/스폰 풀을 받아 동작한다.
# 데이터가 비어 있으면 1장(두멍마을) 폴백 곡선을 그대로 사용해 호환성 유지.

const ENEMY_FIRE: PackedScene = preload("res://scenes/enemies/enemy_fire.tscn")
const ENEMY_EGG: PackedScene = preload("res://scenes/enemies/enemy_egg.tscn")
const ENEMY_WATER: PackedScene = preload("res://scenes/enemies/enemy_water.tscn")
const LEVEL_UP_PANEL: PackedScene = preload("res://scenes/ui/level_up_panel.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const RESULT_SCENE: PackedScene = preload("res://scenes/ui/result_screen.tscn")
const PAUSE_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
const TOAST_SCENE: PackedScene = preload("res://scenes/ui/toast.tscn")
const MAIN_MENU_PATH: String = "res://scenes/main_menu/main_menu.tscn"

const DEFAULT_STAGE_DURATION: float = 300.0

const SPAWN_RADIUS_MIN: float = 300.0
const SPAWN_RADIUS_MAX: float = 400.0
const EGG_FLOCK_SIZE: int = 4
const EGG_FLOCK_SPACING: float = 30.0
const ENEMY_CAP: int = 120
const ZERO_POLL_INTERVAL: float = 1.0

# §7.5 — 두멍마을(ch01) 기준 토스트. 챕터 변경 시 텍스트는 ChapterData에서 받아오도록 확장 여지.
const TOAST_START: String = "도깨비님, 스테이지가 시작되었습니다. 부디 마을을 지켜 주십시오."
const TOAST_FIRST_LEVEL: String = "힘이 차오릅니다. 신통을 골라 주십시오."
const TOAST_AT_90S: String = "잡귀의 기세가 거세집니다. 발을 조심하십시오."
const TOAST_AT_240S: String = "검은 안개가 짙어집니다. 곧 끝이 보입니다."
const TOAST_AT_290S: String = "잠시만 더 버텨 주십시오."
const TOAST_CLEAR_IMMINENT: String = "새벽이 밝아옵니다. 보스의 자취가 멀지 않습니다."
const TOAST_CLEAR_IMMINENT_BEFORE_END: float = 3.0

# §5.2 spawn curve 기본 데이터 — ChapterData가 비었을 때만 사용.
const DEFAULT_SPAWN_TIERS: Array = [
	{"t_start":   0.0, "fire_n":  8, "fire_p": 15.0, "egg_n": 0, "egg_p": 20.0, "water_n": 0, "water_p": 30.0},
	{"t_start":  30.0, "fire_n": 12, "fire_p": 15.0, "egg_n": 1, "egg_p": 20.0, "water_n": 0, "water_p": 30.0},
	{"t_start":  90.0, "fire_n": 16, "fire_p": 15.0, "egg_n": 2, "egg_p": 20.0, "water_n": 1, "water_p": 30.0},
	{"t_start": 150.0, "fire_n": 24, "fire_p": 15.0, "egg_n": 3, "egg_p": 20.0, "water_n": 1, "water_p": 20.0},
	{"t_start": 210.0, "fire_n": 32, "fire_p": 15.0, "egg_n": 4, "egg_p": 20.0, "water_n": 2, "water_p": 20.0},
	{"t_start": 270.0, "fire_n": 40, "fire_p": 10.0, "egg_n": 6, "egg_p": 15.0, "water_n": 3, "water_p": 15.0},
]

enum State { PLAYING, DEAD, CLEARED }


@onready var player: Node2D = $Player
@onready var enemy_container: Node2D = $EnemyContainer
@onready var background: ColorRect = $Background
@onready var skill_manager: Node = SkillManager

# 챕터 의존 상태 — _ready에서 ChapterData로부터 채워짐.
var stage_duration_s: float = DEFAULT_STAGE_DURATION
var spawn_tiers: Array = DEFAULT_SPAWN_TIERS
var hp_scale: float = 1.0
var damage_scale: float = 1.0
var move_speed_scale: float = 1.0
var time_left: float = DEFAULT_STAGE_DURATION

var _fire_timer: float = 0.0
var _egg_timer: float = 0.0
var _water_timer: float = 0.0

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
	_apply_chapter_context()
	time_left = stage_duration_s

	if skill_manager != null and skill_manager.has_method("reset_for_run"):
		skill_manager.reset_for_run(null)

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


func _apply_chapter_context() -> void:
	# ChapterManager가 자동로드라 항상 존재. 데이터는 비어 있을 수 있음.
	var data: ChapterData = null
	if ChapterManager != null:
		data = ChapterManager.current_chapter_data
	if data == null:
		stage_duration_s = DEFAULT_STAGE_DURATION
		spawn_tiers = DEFAULT_SPAWN_TIERS
		return
	stage_duration_s = data.stage_duration_s if data.stage_duration_s > 0.0 else DEFAULT_STAGE_DURATION
	hp_scale = data.hp_scale
	damage_scale = data.damage_scale
	move_speed_scale = data.move_speed_scale
	spawn_tiers = _build_spawn_tiers_from_chapter(data)
	if background != null and data.background_color.a > 0.0:
		background.color = data.background_color


# §4 — ChapterData.spawn_curve_id 기반 곡선 빌드. 풀스펙 곡선이 .tres로 외화되기 전까지는
# 기본 곡선을 챕터 난이도 스케일에 맞춰 양만 부풀린다.
func _build_spawn_tiers_from_chapter(data: ChapterData) -> Array:
	var scale_n: float = 1.0
	if data.chapter_number > 1:
		scale_n = 1.0 + 0.18 * float(data.chapter_number - 1)
	var out: Array = []
	for row in DEFAULT_SPAWN_TIERS:
		var fire_n: int = int(round(float(row["fire_n"]) * scale_n))
		var egg_n: int = int(round(float(row["egg_n"]) * scale_n))
		var water_n: int = int(round(float(row["water_n"]) * scale_n))
		out.append({
			"t_start": float(row["t_start"]),
			"fire_n": fire_n, "fire_p": float(row["fire_p"]),
			"egg_n": egg_n, "egg_p": float(row["egg_p"]),
			"water_n": water_n, "water_p": float(row["water_p"]),
		})
	return out


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
	var survive_sec: int = int(round(stage_duration_s - time_left))
	EventBus.player_died.emit()
	if _result_screen:
		_result_screen.show_result(survive_sec, kill_count, max_level, coins)


func _on_stage_cleared() -> void:
	if _state != State.PLAYING:
		return
	_state = State.CLEARED
	if _pause_menu:
		_pause_menu.set_locked(true)
	# §2.5 — 스테이지 종료를 ChapterManager에 통보. 다음 스테이지/보스로 위임.
	if ChapterManager != null:
		ChapterManager.on_stage_cleared()


func _on_restart_requested() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_main_menu_requested() -> void:
	get_tree().paused = false
	if ChapterManager != null:
		ChapterManager.quit_to_main_menu()
	else:
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


func on_enemy_killed() -> void:
	kill_count += 1


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
	var elapsed: float = stage_duration_s - time_left
	_tick_time_toasts(elapsed)
	if time_left <= 0.0:
		_on_stage_cleared()
		return
	_tick_spawns(delta)


func _tick_time_toasts(elapsed: float) -> void:
	if not _toast_90_done and elapsed >= 90.0:
		_toast_90_done = true
		_show_toast(TOAST_AT_90S)
	if not _toast_240_done and elapsed >= stage_duration_s - 60.0:
		_toast_240_done = true
		_show_toast(TOAST_AT_240S)
	if not _toast_290_done and elapsed >= stage_duration_s - 10.0:
		_toast_290_done = true
		_show_toast(TOAST_AT_290S)
	if not _toast_clear_done and elapsed >= stage_duration_s - TOAST_CLEAR_IMMINENT_BEFORE_END:
		_toast_clear_done = true
		_show_toast(TOAST_CLEAR_IMMINENT)


func _show_toast(text: String) -> void:
	if _toast and _toast.has_method("show_message"):
		_toast.show_message(text)


func _tick_spawns(delta: float) -> void:
	var elapsed: float = stage_duration_s - time_left
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
	var picked: Dictionary = spawn_tiers[0]
	for row in spawn_tiers:
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
	_apply_chapter_scaling(enemy)


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
		_apply_chapter_scaling(enemy)


func _apply_chapter_scaling(enemy: Node2D) -> void:
	# 챕터 hp/damage/speed 스케일을 적이 노출한 필드에 곱한다. 필드 없으면 무시.
	if hp_scale != 1.0 and "max_hp" in enemy:
		enemy.max_hp = int(round(float(enemy.max_hp) * hp_scale))
		if "hp" in enemy:
			enemy.hp = enemy.max_hp
	if damage_scale != 1.0 and "contact_damage" in enemy:
		enemy.contact_damage = int(round(float(enemy.contact_damage) * damage_scale))
	if move_speed_scale != 1.0 and "move_speed" in enemy:
		enemy.move_speed = enemy.move_speed * move_speed_scale


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
		if not (child is EnemyBase):
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
