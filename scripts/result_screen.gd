extends CanvasLayer


signal restart_pressed
signal main_menu_pressed


const STAGE_FULL_SEC: int = 300

const TITLE_DIED: String = "쓰러지셨습니다"
const SUBTITLE_DIED: String = "다음에는 더 멀리 가실 수 있습니다"
const TITLE_CLEAR: String = "5분을 버텨내셨습니다"
const SUBTITLE_CLEAR: String = "깨비런 첫 스테이지를 클리어하셨어요"


@onready var _root: Control = $Root
@onready var _panel: Control = $Root/Panel
@onready var _title: Label = $Root/Panel/Title
@onready var _subtitle: Label = $Root/Panel/Subtitle
@onready var _survive_val: Label = $Root/Panel/Stats/SurviveRow/Value
@onready var _kills_val: Label = $Root/Panel/Stats/KillsRow/Value
@onready var _level_val: Label = $Root/Panel/Stats/LevelRow/Value
@onready var _coins_val: Label = $Root/Panel/Stats/CoinsRow/Value
@onready var _restart_btn: Button = $Root/Panel/RestartButton
@onready var _main_menu_btn: Button = $Root/Panel/MainMenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_restart_btn.pressed.connect(_on_restart)
	_main_menu_btn.pressed.connect(_on_main_menu)


func show_result(survive_sec: int, kills: int, level: int, coins: int) -> void:
	var cleared: bool = survive_sec >= STAGE_FULL_SEC
	if cleared:
		_title.text = TITLE_CLEAR
		_subtitle.text = SUBTITLE_CLEAR
	else:
		_title.text = TITLE_DIED
		_subtitle.text = SUBTITLE_DIED
	var mm: int = survive_sec / 60
	var ss: int = survive_sec % 60
	_survive_val.text = "%02d:%02d" % [mm, ss]
	_kills_val.text = str(kills)
	_level_val.text = "레벨 %d" % level
	_coins_val.text = str(coins)
	get_tree().paused = true
	_root.visible = true
	_root.modulate.a = 0.0
	_panel.scale = Vector2(0.96, 0.96)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_root, "modulate:a", 1.0, 0.25)
	tw.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.25)
	tw.set_parallel(false)
	tw.tween_callback(_restart_btn.grab_focus)


func _on_restart() -> void:
	restart_pressed.emit()


func _on_main_menu() -> void:
	main_menu_pressed.emit()
