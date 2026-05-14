extends Control


# §2.5 — 캐릭터 선택 화면. resources/characters/*.tres를 자동 로드해
# MetaState.unlocked_characters에 따라 잠금/해금 카드를 표시한다.
# 카드 탭 → GameState.selected_character_id에 저장.

const CHAR_RES_DIR: String = "res://resources/characters"
const MAIN_MENU_PATH: String = "res://scenes/main_menu/main_menu.tscn"
const CARD_SIZE: Vector2 = Vector2(210, 240)


@onready var _grid: GridContainer = $Scroll/CardGrid
@onready var _selected_label: Label = $SelectedLabel
@onready var _back_button: Button = $BackButton

var _characters: Array[CharacterData] = []


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_load_characters()
	_build_cards()
	_refresh_selected_label()


func _load_characters() -> void:
	_characters.clear()
	var dir: DirAccess = DirAccess.open(CHAR_RES_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".tres"):
			var res: Resource = load("%s/%s" % [CHAR_RES_DIR, name])
			if res is CharacterData:
				_characters.append(res)
		name = dir.get_next()
	dir.list_dir_end()
	_characters.sort_custom(func(a: CharacterData, b: CharacterData) -> bool:
		return String(a.id) < String(b.id))


func _build_cards() -> void:
	for child in _grid.get_children():
		child.queue_free()
	for data in _characters:
		_grid.add_child(_make_card(data))


func _make_card(data: CharacterData) -> Control:
	var unlocked: bool = _is_unlocked(data.id)
	var card: Button = Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.toggle_mode = false
	card.disabled = false
	card.focus_mode = Control.FOCUS_ALL
	card.alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_theme_font_size_override("font_size", 14)
	card.text = "%s\n\n%s" % [data.display_name_ko, _format_stat_line(data, unlocked)]
	if unlocked:
		card.modulate = Color(1, 1, 1, 1)
	else:
		card.modulate = Color(0.55, 0.5, 0.45, 1)
		card.text = "%s\n\n(잠금)\n도깨비 구슬 %d개 필요" % [data.display_name_ko, data.unlock_cost_orbs]
	card.pressed.connect(_on_card_pressed.bind(data))
	return card


func _format_stat_line(data: CharacterData, _unlocked: bool) -> String:
	return "HP %d  ATK %d\nMS %d  AS %.2fs" % [
		data.base_hp, data.base_attack,
		int(round(data.base_move_speed)), data.base_attack_speed,
	]


func _is_unlocked(id: StringName) -> bool:
	if MetaState == null:
		return id == &"ttukttaki"
	return MetaState.unlocked_characters.has(id)


func _on_card_pressed(data: CharacterData) -> void:
	if not _is_unlocked(data.id):
		EventBus.toast_requested.emit("아직 해금되지 않은 캐릭터입니다.", 1.5)
		return
	if GameState != null:
		GameState.selected_character_id = data.id
	if ChapterManager != null and ChapterManager.has_method("select_character"):
		ChapterManager.current_character_id = data.id
	_refresh_selected_label()
	EventBus.toast_requested.emit("%s 도깨비님을 선택하셨습니다." % data.display_name_ko, 1.5)


func _refresh_selected_label() -> void:
	if GameState == null or GameState.selected_character_id == &"":
		_selected_label.text = "선택된 캐릭터: 없음"
		return
	var id: StringName = GameState.selected_character_id
	for c in _characters:
		if c.id == id:
			_selected_label.text = "선택된 캐릭터: %s" % c.display_name_ko
			return
	_selected_label.text = "선택된 캐릭터: %s" % String(id)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
