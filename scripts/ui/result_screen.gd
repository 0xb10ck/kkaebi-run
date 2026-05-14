extends CanvasLayer


signal restart_pressed
signal main_menu_pressed


const STAGE_FULL_SEC: int = 300

# §7.2 / §7.3 result-screen copy.
const TITLE_DIED: String = "도깨비가 잠들었습니다"
const SUBTITLE_DIED: String = "신목의 기운을 다시 모으기까지 잠시 기다려 주십시오."
const TITLE_CLEAR: String = "스테이지를 완수하셨습니다"
const SUBTITLE_CLEAR: String = "두멍마을의 밤이 다시 조용해졌습니다. 도깨비님 덕분입니다."


@onready var _root: Control = $Root
@onready var _panel: Control = $Root/Panel
@onready var _title: Label = $Root/Panel/Title
@onready var _subtitle: Label = $Root/Panel/Subtitle
@onready var _survive_val: Label = $Root/Panel/Stats/SurviveRow/Value
@onready var _kills_val: Label = $Root/Panel/Stats/KillsRow/Value
@onready var _level_val: Label = $Root/Panel/Stats/LevelRow/Value
@onready var _coins_val: Label = $Root/Panel/Stats/CoinsRow/Value
@onready var _orbs_val: Label = $Root/Panel/Stats/OrbsRow/Value
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
	_orbs_val.text = _settle_and_format(survive_sec, kills, level, cleared)
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


# §8 — 런 종료 정산. MetaState.compute_run_settlement()로 위임하고 EventBus.run_ended emit.
func _settle_and_format(survive_sec: int, kills: int, level: int, cleared: bool) -> String:
	var chapter_number: int = 1
	var chapter_id: StringName = &""
	var clear_base_orbs: int = 0
	var clear_first_bonus_orbs: int = 0
	if ChapterManager != null:
		chapter_id = ChapterManager.current_chapter_id
		if ChapterManager.current_chapter_data != null:
			var data: ChapterData = ChapterManager.current_chapter_data
			chapter_number = data.chapter_number
			clear_base_orbs = data.clear_base_orbs
			clear_first_bonus_orbs = data.clear_first_bonus_orbs

	var clear_bonus: int = 0
	if cleared:
		clear_bonus = clear_base_orbs
		# 첫 클리어 보너스는 codex_places에 cleared 마크가 없을 때만.
		var entry: Dictionary = {}
		if MetaState != null:
			entry = MetaState.codex_places.get(chapter_id, {})
		if not bool(entry.get("cleared", false)):
			clear_bonus += clear_first_bonus_orbs

	var stats_in: Dictionary = {
		"kills": kills,
		"survive_sec": survive_sec,
		"level": level,
		"chapter_number": chapter_number,
		"clear_bonus_orbs": clear_bonus,
	}
	var orbs_total: int = 0
	if MetaState != null and MetaState.has_method("compute_run_settlement"):
		var summary: Dictionary = MetaState.compute_run_settlement(stats_in)
		orbs_total = int(summary.get("orbs", 0))

	# §2.1 — 런 종료 통보. 외부 수신자(통계/도전과제)가 활용.
	if EventBus != null:
		var reason: StringName = Ids.RUN_CLEAR if cleared else Ids.RUN_DEATH
		EventBus.run_ended.emit(reason, {
			"kills": kills,
			"survive_sec": survive_sec,
			"level": level,
			"coins": coins_passthrough_value(),
			"chapter": String(chapter_id),
			"orbs_earned": orbs_total,
		})
	return "%d 개" % orbs_total


# coins는 show_result로 전달된 값이 _coins_val에 텍스트로만 들어 있으므로 다시 파싱하기보다는
# 호출부에서 보존된 값을 노출. 단순화를 위해 _coins_val.text에서 정수 파싱.
func coins_passthrough_value() -> int:
	return int(_coins_val.text)


func _on_restart() -> void:
	restart_pressed.emit()


func _on_main_menu() -> void:
	main_menu_pressed.emit()
