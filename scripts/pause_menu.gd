extends CanvasLayer


signal restart_pressed
signal main_menu_pressed


@onready var _root: Control = $Root
@onready var _continue_btn: Button = $Root/Panel/ContinueButton
@onready var _restart_btn: Button = $Root/Panel/RestartButton
@onready var _main_menu_btn: Button = $Root/Panel/MainMenuButton


var _locked: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_continue_btn.pressed.connect(_on_continue)
	_restart_btn.pressed.connect(_on_restart)
	_main_menu_btn.pressed.connect(_on_main_menu)


func _unhandled_input(event: InputEvent) -> void:
	if _locked:
		return
	if event.is_action_pressed("ui_cancel"):
		if _root.visible:
			_close_internal()
		else:
			_open_internal()
		get_viewport().set_input_as_handled()


func open_pause() -> void:
	if _locked:
		return
	if _root.visible:
		return
	_open_internal()


func close_pause() -> void:
	if _root.visible:
		_close_internal()


func set_locked(locked: bool) -> void:
	_locked = locked
	if locked and _root.visible:
		_close_internal()


func _open_internal() -> void:
	_root.visible = true
	get_tree().paused = true
	_continue_btn.grab_focus()


func _close_internal() -> void:
	_root.visible = false
	get_tree().paused = false


func _on_continue() -> void:
	_close_internal()


func _on_restart() -> void:
	_close_internal()
	restart_pressed.emit()


func _on_main_menu() -> void:
	_close_internal()
	main_menu_pressed.emit()
