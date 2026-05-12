extends Node2D

signal request_restart
signal request_main_menu

const XP_GEM_SCENE: PackedScene = preload("res://scenes/items/XPGem.tscn")
const GOLD_SCENE: PackedScene = preload("res://scenes/items/Gold.tscn")
const LEVEL_UP_UI_SCENE: PackedScene = preload("res://scenes/ui/LevelUpUI.tscn")
const RESULT_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/ResultScreen.tscn")
const TOAST_SCENE: PackedScene = preload("res://scenes/ui/Toast.tscn")

@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $World/Player
@onready var enemy_container: Node2D = $World/EnemyContainer
@onready var xp_container: Node2D = $World/XPGemContainer
@onready var gold_container: Node2D = $World/GoldContainer
@onready var projectile_container: Node2D = $World/ProjectileContainer
@onready var camera: Camera2D = $Camera2D
@onready var spawner: Node = $EnemySpawner

var level_up_ui: CanvasLayer
var result_screen: CanvasLayer
var toast_layer: CanvasLayer

var _pending_level_ups: int = 0
var _game_ended: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	GameState.reset()
	SkillManager.reset()

	projectile_container.add_to_group("projectile_container")

	toast_layer = CanvasLayer.new()
	toast_layer.name = "ToastLayer"
	toast_layer.layer = 15
	add_child(toast_layer)

	level_up_ui = LEVEL_UP_UI_SCENE.instantiate()
	add_child(level_up_ui)

	result_screen = RESULT_SCREEN_SCENE.instantiate()
	add_child(result_screen)

	spawner.configure(enemy_container, player)
	spawner.enemy_died.connect(_on_enemy_died)
	spawner.start()

	player.died.connect(_on_player_died)

	GameState.level_changed.connect(_on_level_changed)
	GameState.time_milestone.connect(_on_time_milestone)
	GameState.game_over.connect(_on_game_over)

	level_up_ui.card_selected.connect(_on_card_selected)
	result_screen.retry_pressed.connect(_on_retry_pressed)
	result_screen.main_menu_pressed.connect(_on_main_menu_pressed)

	_show_toast("도깨비님, 두멍마을을 지켜 주십시오.")


func _process(delta: float) -> void:
	if not _game_ended:
		GameState.tick_time(delta)
	if camera and is_instance_valid(player):
		camera.global_position = player.global_position


func _on_enemy_died(world_pos: Vector2, data: EnemyData) -> void:
	GameState.register_kill()
	if data == null:
		return
	var gem := XP_GEM_SCENE.instantiate()
	gem.setup(data.exp_value)
	gem.global_position = world_pos
	gem.collected.connect(_on_gem_collected)
	xp_container.add_child(gem)
	if data.gold_drop_chance > 0.0 and randf() < data.gold_drop_chance:
		var g := GOLD_SCENE.instantiate()
		g.setup(data.gold_drop_amount)
		g.global_position = world_pos + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		g.collected.connect(_on_gold_collected)
		gold_container.add_child(g)


func _on_gem_collected(value: int) -> void:
	GameState.add_xp(value)


func _on_gold_collected(amount: int) -> void:
	GameState.add_gold(amount)


func _on_level_changed(new_level: int) -> void:
	if new_level <= 1:
		return
	if new_level == 2:
		_show_toast("힘이 차오릅니다. 신통을 골라 주십시오.")
	_pending_level_ups += 1
	if not level_up_ui.is_visible():
		_open_next_modal()


func _open_next_modal() -> void:
	if _pending_level_ups <= 0:
		get_tree().paused = false
		return
	var cards := SkillManager.draw_three_cards()
	level_up_ui.populate(cards)
	level_up_ui.show_modal()
	get_tree().paused = true


func _on_card_selected(card_data: Dictionary) -> void:
	var kind: String = String(card_data.get("kind", "skill"))
	var id: StringName = card_data.get("id", &"")
	if kind == "skill":
		SkillManager.acquire(id)
		_instance_skill(id)
	elif kind == "bonus":
		match id:
			&"bonus_max_hp":
				GameState.apply_bonus_max_hp(20)
			&"bonus_move_speed":
				GameState.apply_bonus_move_speed(0.05)
			&"bonus_xp_gain":
				GameState.apply_bonus_xp_gain(0.10)
	_pending_level_ups -= 1
	if _pending_level_ups > 0:
		_open_next_modal()
	else:
		level_up_ui.hide_modal()
		get_tree().paused = false


func _instance_skill(id: StringName) -> void:
	var data: SkillData = SkillManager.skill_db.get(id, null)
	if data == null or data.scene_path == "":
		return
	var scene: PackedScene = load(data.scene_path)
	if scene == null:
		return
	var inst := scene.instantiate()
	player.skill_anchor.add_child(inst)


func _on_time_milestone(t: int) -> void:
	match t:
		90:
			_show_toast("물귀신이 다가옵니다. 발을 조심하십시오.")
		240:
			_show_toast("검은 안개가 짙어집니다. 곧 끝이 보입니다.")
		290:
			_show_toast("잠시만 더 버텨 주십시오.")
		300:
			_show_toast("두멍마을의 새벽이 밝아옵니다.")


func _on_player_died() -> void:
	# GameState already fired game_over from deal_damage_to_player.
	pass


func _on_game_over(reason: StringName) -> void:
	if _game_ended:
		return
	_game_ended = true
	if spawner and spawner.has_method("stop"):
		spawner.stop()
	var title: String
	var subtitle: String
	if reason == &"clear":
		title = "스테이지를 완수하셨습니다"
		subtitle = "두멍마을의 밤이 다시 조용해졌습니다. 도깨비님 덕분입니다."
	else:
		title = "도깨비가 잠들었습니다"
		subtitle = "신목의 기운을 다시 모으기까지 잠시 기다려 주십시오."
	if level_up_ui:
		level_up_ui.hide_modal()
	result_screen.show_result(title, subtitle, GameState.elapsed, GameState.kill_count, GameState.level, GameState.gold)
	get_tree().paused = true


func _on_retry_pressed() -> void:
	get_tree().paused = false
	emit_signal("request_restart")


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	emit_signal("request_main_menu")


func _show_toast(text: String) -> void:
	if toast_layer == null:
		return
	var t := TOAST_SCENE.instantiate()
	toast_layer.add_child(t)
	if t.has_method("show_text"):
		t.show_text(text)
