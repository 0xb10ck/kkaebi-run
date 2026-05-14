extends Node2D

# §5 — 챕터 보스 아레나. BossData를 받아 BossBase 인스턴스를 띄우고
# 플레이어/HUD/보스 HP 바를 연결한다. 실제 패턴은 BossBase 베이스가 처리하지만
# 본 화면은 베이스 페이즈 시스템의 동작 확인을 위한 '더미 패턴' 1개를 보장한다.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const BOSS_HP_BAR_SCENE: PackedScene = preload("res://scenes/ui/boss_hp_bar.tscn")
const PAUSE_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
const RESULT_SCENE: PackedScene = preload("res://scenes/ui/result_screen.tscn")
const TOAST_SCENE: PackedScene = preload("res://scenes/ui/toast.tscn")
const DUMMY_BOSS_SCRIPT: GDScript = preload("res://scripts/bosses/dummy_boss.gd")
const BOSS_RES_DIR: String = "res://resources/bosses"

@onready var background: ColorRect = $Background
@onready var boss_anchor: Node2D = $BossAnchor
@onready var player_anchor: Node2D = $PlayerAnchor

var boss: Node
var boss_data: BossData
var player: Node2D
var _hud: CanvasLayer
var _boss_hp_bar: CanvasLayer
var _pause_menu: CanvasLayer
var _result_screen: CanvasLayer
var _toast: CanvasLayer

var _kill_count: int = 0
var _coins: int = 0
var _max_level: int = 1
var _arena_started_at: float = 0.0


func _ready() -> void:
	get_tree().paused = false
	_arena_started_at = Time.get_unix_time_from_system()

	boss_data = _resolve_boss_data()
	if ChapterManager != null and ChapterManager.current_chapter_data != null:
		var c: ChapterData = ChapterManager.current_chapter_data
		if c.background_color.a > 0.0 and background != null:
			background.color = c.background_color

	_spawn_player()
	_spawn_boss()
	_spawn_ui()
	_show_intro_toast()


func _resolve_boss_data() -> BossData:
	var id: StringName = &""
	if ChapterManager != null and ChapterManager.current_boss_id != &"":
		id = ChapterManager.current_boss_id
	elif ChapterManager != null and ChapterManager.current_chapter_data != null:
		id = ChapterManager.current_chapter_data.chapter_boss_id
	if id == &"":
		id = &"b01_dokkaebibul_daejang"

	var direct: String = "%s/%s.tres" % [BOSS_RES_DIR, String(id)]
	var res: Resource = load(direct) if ResourceLoader.exists(direct) else null
	if res is BossData:
		return res

	# 디렉토리 스캔 폴백 — id 매칭.
	var dir: DirAccess = DirAccess.open(BOSS_RES_DIR)
	if dir == null:
		return null
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if not dir.current_is_dir() and (name.ends_with(".tres") or name.ends_with(".res")):
			var path: String = BOSS_RES_DIR + "/" + name
			var data: Resource = load(path)
			if data is BossData and data.id == id:
				dir.list_dir_end()
				return data
		name = dir.get_next()
	dir.list_dir_end()
	return null


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	if player_anchor:
		player.global_position = player_anchor.global_position
	else:
		player.global_position = Vector2(240, 600)
	add_child(player)


func _spawn_boss() -> void:
	if boss_data == null:
		push_warning("BossArena: boss data not resolved — running empty arena")
		return
	# 베이스 클래스가 _execute_pattern을 비워두므로, 본 화면은 더미 서브클래스를 사용해
	# '텔레그래프 → 1초 후 데미지 판정'을 한 번 이상 보장. set_script 이후 dummy_boss는
	# BossBase를 상속하므로 data/no_hit 등 모든 BossBase 필드가 접근 가능하다.
	var body: CharacterBody2D = CharacterBody2D.new()
	body.set_script(DUMMY_BOSS_SCRIPT)
	body.set("data", boss_data)
	body.name = "Boss_" + String(boss_data.id)
	boss = body
	if boss_anchor:
		boss.global_position = boss_anchor.global_position
	else:
		boss.global_position = Vector2(240, 200)
	add_child(boss)
	if boss.has_signal("died"):
		boss.connect("died", _on_boss_died)


func _spawn_ui() -> void:
	_hud = HUD_SCENE.instantiate()
	add_child(_hud)
	_pause_menu = PAUSE_SCENE.instantiate()
	add_child(_pause_menu)
	_result_screen = RESULT_SCENE.instantiate()
	add_child(_result_screen)
	_toast = TOAST_SCENE.instantiate()
	add_child(_toast)
	_boss_hp_bar = BOSS_HP_BAR_SCENE.instantiate()
	add_child(_boss_hp_bar)
	if boss != null and boss_data != null and _boss_hp_bar.has_method("bind_boss"):
		_boss_hp_bar.bind_boss(boss, boss_data)

	if is_instance_valid(player):
		if player.has_signal("hp_changed"):
			player.hp_changed.connect(func(hp: int, mx: int) -> void: _hud.set_hp(hp, mx))
		if player.has_signal("died"):
			player.died.connect(_on_player_died)
		_hud.set_hp(int(player.hp), int(player.max_hp))

	_hud.set_time(0.0)
	_hud.set_coins(0)
	_hud.pause_pressed.connect(_pause_menu.open_pause)
	_pause_menu.restart_pressed.connect(_on_restart_requested)
	_pause_menu.main_menu_pressed.connect(_on_main_menu_requested)
	_result_screen.restart_pressed.connect(_on_restart_requested)
	_result_screen.main_menu_pressed.connect(_on_main_menu_requested)


func _show_intro_toast() -> void:
	if boss_data == null or _toast == null or not _toast.has_method("show_message"):
		return
	_toast.show_message("도깨비님, %s이(가) 나타났습니다." % boss_data.display_name_ko)


# === Boss/Player 결과 핸들러 ===

func _on_boss_died(_boss_id: StringName) -> void:
	# BossBase가 EventBus.boss_defeated를 이미 emit한다. ChapterManager가 다음 흐름을 결정.
	if _toast and _toast.has_method("show_message"):
		_toast.show_message("보스를 물리치셨습니다. 한숨 돌리십시오.")
	# 죽음 컷씬이 끝나기 충분한 시간 + 막간 화면 전환.
	var t: SceneTreeTimer = get_tree().create_timer(max(1.5, boss_data.death_cutscene_duration_s + 0.5))
	t.timeout.connect(_advance_after_boss)


func _advance_after_boss() -> void:
	if ChapterManager == null:
		return
	var time_taken: float = Time.get_unix_time_from_system() - _arena_started_at
	var no_hit: bool = true
	if boss != null:
		no_hit = bool(boss.get("no_hit"))
	ChapterManager.on_boss_defeated(boss_data.id, time_taken, no_hit)


func _on_player_died() -> void:
	if _pause_menu:
		_pause_menu.set_locked(true)
	EventBus.player_died.emit()
	if _result_screen:
		_result_screen.show_result(0, _kill_count, _max_level, _coins)


func _on_restart_requested() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_main_menu_requested() -> void:
	get_tree().paused = false
	if ChapterManager != null:
		ChapterManager.quit_to_main_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
