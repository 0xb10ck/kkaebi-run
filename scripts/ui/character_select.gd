extends Control


# §2.5 — 캐릭터 선택 화면. resources/characters/*.tres를 자동 로드해
# MetaState.unlocked_characters에 따라 잠금/해금 카드를 표시한다.
# 카드 탭 → GameState.selected_character_id 저장 → 챕터 선택 화면으로 이동.

const CHAR_RES_DIR: String = "res://resources/characters"
const MAIN_MENU_PATH: String = "res://scenes/main_menu/main_menu.tscn"
const CHAPTER_SELECT_PATH: String = "res://scenes/ui/chapter_select.tscn"
const CARD_SIZE: Vector2 = Vector2(210, 280)
const ROUTE_DELAY_SEC: float = 0.45


@onready var _grid: GridContainer = $Scroll/CardGrid
@onready var _selected_label: Label = $SelectedLabel
@onready var _back_button: Button = $BackButton

var _characters: Array[CharacterData] = []
var _routing: bool = false


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_load_characters()
	_build_cards()
	_refresh_selected_label()
	if not EventBus.character_unlocked.is_connected(_on_character_unlocked):
		EventBus.character_unlocked.connect(_on_character_unlocked)


func _load_characters() -> void:
	_characters.clear()
	var dir: DirAccess = DirAccess.open(CHAR_RES_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tres"):
			var res: Resource = load("%s/%s" % [CHAR_RES_DIR, entry])
			if res is CharacterData:
				_characters.append(res)
		entry = dir.get_next()
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
	card.focus_mode = Control.FOCUS_ALL
	card.alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_theme_font_size_override("font_size", 13)
	card.clip_text = false
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if unlocked:
		card.text = "%s\n\n%s" % [data.display_name_ko, _format_stat_block(data)]
		card.modulate = Color(1, 1, 1, 1)
	else:
		var cost_text: String
		if data.unlock_cost_orbs > 0:
			cost_text = "도깨비 구슬 %d개 필요" % data.unlock_cost_orbs
		else:
			cost_text = "추후 해금"
		card.text = "%s\n\n(잠금)\n%s" % [data.display_name_ko, cost_text]
		card.modulate = Color(0.55, 0.5, 0.45, 1)
	card.pressed.connect(_on_card_pressed.bind(data))
	return card


func _format_stat_block(data: CharacterData) -> String:
	# HP / 이속 / 공격력 / 특수 4행. 특수는 passive_id 또는 ultimate_id 우선.
	return "HP %d   이속 %d\n공격력 %d   공속 %.2fs\n특수: %s" % [
		data.base_hp,
		int(round(data.base_move_speed)),
		data.base_attack,
		data.base_attack_speed,
		_format_special(data),
	]


func _format_special(data: CharacterData) -> String:
	if data.passive_id != &"":
		return String(data.passive_id)
	if data.ultimate_id != &"":
		return String(data.ultimate_id)
	return "기본"


func _is_unlocked(id: StringName) -> bool:
	if MetaState == null:
		return id == &"ttukttaki"
	return MetaState.unlocked_characters.has(id)


func _on_card_pressed(data: CharacterData) -> void:
	if _routing:
		return
	if not _is_unlocked(data.id):
		EventBus.toast_requested.emit("아직 해금되지 않은 캐릭터입니다.", 1.5)
		return
	if GameState != null:
		GameState.selected_character_id = data.id
	if ChapterManager != null:
		ChapterManager.current_character_id = data.id
	_refresh_selected_label()
	EventBus.toast_requested.emit("%s 도깨비님을 선택하셨습니다." % data.display_name_ko, 1.2)
	EventBus.save_requested.emit(&"autosave")
	_routing = true
	get_tree().create_timer(ROUTE_DELAY_SEC).timeout.connect(_route_to_chapter_select)


func _route_to_chapter_select() -> void:
	get_tree().change_scene_to_file(CHAPTER_SELECT_PATH)


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


func _on_character_unlocked(_id: StringName) -> void:
	_build_cards()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
