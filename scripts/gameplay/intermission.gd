extends Control

# §2.5 — 보스 처치 후 막간 화면. 다음 챕터로 진행 또는 메인 메뉴로 복귀.
# 풀스펙에서는 상점/대화 이벤트가 채워질 자리. MVP 골격은 안내 + 진행 버튼.

@onready var _title: Label = $Panel/Title
@onready var _body: Label = $Panel/Body
@onready var _next_button: Button = $Panel/NextButton
@onready var _menu_button: Button = $Panel/MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	_apply_chapter_context()
	_next_button.pressed.connect(_on_next_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_next_button.grab_focus()


func _apply_chapter_context() -> void:
	var chapter_name: String = "이번 챕터"
	if ChapterManager != null and ChapterManager.current_chapter_data != null:
		chapter_name = ChapterManager.current_chapter_data.display_name_ko
	_title.text = "%s의 보스를 물리치셨습니다" % chapter_name
	_body.text = "잠시 숨을 고르십시오. 신목이 다음 길을 안내해 드립니다."

	# 다음 챕터가 없으면 버튼 라벨을 바꿔 종료 흐름으로 안내.
	if ChapterManager != null and ChapterManager.has_method("get_chapter_list"):
		var next_id: StringName = _next_chapter_id()
		if next_id == &"":
			_next_button.text = "여정을 마치겠습니다"
		else:
			_next_button.text = "다음 챕터로 떠나겠습니다"


func _next_chapter_id() -> StringName:
	var arr: Array = ChapterManager.get_chapter_list()
	for i in arr.size():
		var data: ChapterData = arr[i]
		if data.id == ChapterManager.current_chapter_id and i + 1 < arr.size():
			return arr[i + 1].id
	return &""


func _on_next_pressed() -> void:
	if ChapterManager != null:
		ChapterManager.advance_to_next_chapter()


func _on_menu_pressed() -> void:
	if ChapterManager != null:
		ChapterManager.quit_to_main_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
