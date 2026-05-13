extends Control


const MAIN_SCENE: String = "res://scenes/gameplay/main.tscn"


@onready var _start_button: Button = $StartButton


func _ready() -> void:
	get_tree().paused = false
	_start_button.pressed.connect(_on_start)
	_start_button.grab_focus()


func _on_start() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)
