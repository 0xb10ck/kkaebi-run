extends Node

const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/MainMenu.tscn")
const GAME_SCENE: PackedScene = preload("res://scenes/GameScene.tscn")

var current: Node = null


func _ready() -> void:
	_go_to_menu()


func _go_to_menu() -> void:
	var menu := MAIN_MENU_SCENE.instantiate()
	_swap_scene(menu)
	if menu.has_signal("start_pressed"):
		menu.start_pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
	_go_to_game()


func _go_to_game() -> void:
	var game := GAME_SCENE.instantiate()
	_swap_scene(game)
	if game.has_signal("request_restart"):
		game.request_restart.connect(_on_restart_pressed)
	if game.has_signal("request_main_menu"):
		game.request_main_menu.connect(_on_menu_pressed)


func _on_restart_pressed() -> void:
	get_tree().paused = false
	_go_to_game()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	_go_to_menu()


func _swap_scene(new_scene: Node) -> void:
	if current and is_instance_valid(current):
		current.queue_free()
	current = new_scene
	add_child(new_scene)
