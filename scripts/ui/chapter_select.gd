extends Control


# §2.5 — 챕터 선택 화면. ChapterManager에 등록된 ChapterData 6종을 표시.
# 잠금 상태(MetaState.shinmok_stage + 선행 챕터 클리어)에 따라 선택 가능 여부 결정.
# 선택 시 ChapterManager.select_chapter(id) → begin_run() 호출.

const MAIN_MENU_PATH: String = "res://scenes/main_menu/main_menu.tscn"
const CHARACTER_SELECT_PATH: String = "res://scenes/ui/character_select.tscn"
const DEFAULT_CHARACTER_ID: StringName = &"ttukttaki"


@onready var _list: VBoxContainer = $Scroll/List
@onready var _character_label: Label = $CharacterLabel
@onready var _back_button: Button = $BackButton


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_refresh_character_label()
	_rebuild_list()


func _refresh_character_label() -> void:
	if GameState == null or GameState.selected_character_id == &"":
		_character_label.text = "기본 캐릭터 뚝딱이 도깨비님으로 출정합니다"
		return
	var char_id: StringName = GameState.selected_character_id
	var name: String = String(char_id)
	var path: String = "res://resources/characters/%s.tres" % String(char_id)
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is CharacterData:
			name = res.display_name_ko
	_character_label.text = "%s 도깨비님으로 출정합니다" % name


func _rebuild_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	if ChapterManager == null:
		return
	var chapters: Array[ChapterData] = ChapterManager.get_chapter_list()
	for ch in chapters:
		_list.add_child(_make_row(ch))


func _make_row(ch: ChapterData) -> Control:
	var unlocked: bool = false
	if ChapterManager != null:
		unlocked = ChapterManager.is_chapter_unlocked(ch.id)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 96)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Body"
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_label: Label = Label.new()
	name_label.text = "%d장. %s" % [ch.chapter_number, ch.display_name_ko]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.878, 0.761, 0.235, 1))
	info.add_child(name_label)

	var desc: Label = Label.new()
	desc.text = ch.description_ko if unlocked else "신목 Lv.%d 이상에서 해금됩니다." % ch.unlock_shinmok_required
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.941, 0.929, 0.902, 0.85))
	info.add_child(desc)

	var meta: Label = Label.new()
	meta.text = "스테이지 %d개  |  보스 %s" % [ch.stage_count, _boss_label(ch.chapter_boss_id)]
	meta.add_theme_font_size_override("font_size", 11)
	meta.add_theme_color_override("font_color", Color(0.941, 0.929, 0.902, 0.65))
	info.add_child(meta)

	var go: Button = Button.new()
	go.custom_minimum_size = Vector2(96, 80)
	go.add_theme_font_size_override("font_size", 13)
	if unlocked:
		go.text = "출정하기"
		go.disabled = false
	else:
		go.text = "잠김"
		go.disabled = true
	go.pressed.connect(_on_chapter_pressed.bind(ch.id))
	row.add_child(go)

	if not unlocked:
		panel.modulate = Color(0.55, 0.5, 0.45, 1)
	return panel


func _boss_label(boss_id: StringName) -> String:
	if boss_id == &"":
		return "미정"
	return String(boss_id)


func _on_chapter_pressed(chapter_id: StringName) -> void:
	if ChapterManager == null:
		return
	if not ChapterManager.is_chapter_unlocked(chapter_id):
		EventBus.toast_requested.emit("아직 해금되지 않은 챕터입니다.", 1.5)
		return
	var char_id: StringName = DEFAULT_CHARACTER_ID
	if GameState != null and GameState.selected_character_id != &"":
		char_id = GameState.selected_character_id
	ChapterManager.select_character(char_id)
	ChapterManager.select_chapter(chapter_id)
	ChapterManager.begin_run()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
