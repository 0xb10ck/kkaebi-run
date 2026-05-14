extends Control


# §2.5 — 도감 화면. 요괴/신물/장소 3탭.
# 잠금 카드는 실루엣 박스, 해금 카드는 이름 + 설명을 표시.

const MAIN_MENU_PATH: String = "res://scenes/main_menu/main_menu.tscn"
const CARD_SIZE: Vector2 = Vector2(210, 130)


@onready var _monsters_tab: Button = $Tabs/MonstersTab
@onready var _relics_tab: Button = $Tabs/RelicsTab
@onready var _places_tab: Button = $Tabs/PlacesTab
@onready var _progress_label: Label = $ProgressLabel
@onready var _grid: GridContainer = $Scroll/Grid
@onready var _back_button: Button = $BackButton

# 카테고리별 placeholder 엔트리. 실제 게임에서는 EnemyData/RelicData/ChapterData에서 수집.
# {id, name, summary}
const MONSTER_ENTRIES: Array = [
	{"id": &"m01_dokkaebibul", "name": "도깨비불", "summary": "두멍마을의 옅은 푸른 도깨비입니다."},
	{"id": &"m02_egg_specter", "name": "알 귀신", "summary": "껍데기를 두른 작은 귀신입니다."},
	{"id": &"m03_water_ghost", "name": "물귀신", "summary": "발목을 잡아 끄는 검푸른 손길입니다."},
	{"id": &"mb01_jangsanbeom", "name": "장산범", "summary": "안개를 가르는 거대한 백호 미니보스입니다."},
	{"id": &"b01_dokkaebibul_daejang", "name": "도깨비불 대장", "summary": "1장의 챕터 보스입니다."},
]

const RELIC_ENTRIES: Array = [
	{"id": &"r01_dokkaebi_bangmang", "name": "도깨비 방망이", "summary": "원하는 것을 두드려 내는 신물입니다."},
	{"id": &"r02_buksu_bujeok", "name": "북수 부적", "summary": "한 번의 피격을 막아 주는 부적입니다."},
	{"id": &"r03_haetae_oksae", "name": "해태 옥새", "summary": "사악한 기운을 정화하는 옥새입니다."},
]

const PLACE_ENTRIES: Array = [
	{"id": &"ch01_dumeong", "name": "두멍마을", "summary": "안개에 잠긴 시작의 마을입니다."},
	{"id": &"ch02_sinryeong", "name": "신령의 숲", "summary": "오래된 숲의 깊은 곳입니다."},
	{"id": &"ch03_hwangcheon", "name": "지하 황천", "summary": "죽음의 강이 흐르는 지하 세계입니다."},
	{"id": &"ch04_cheonsang", "name": "천상계", "summary": "구름 위의 신의 영역입니다."},
	{"id": &"ch05_sinmok_heart", "name": "신목의 심장", "summary": "모든 여정의 끝, 신목의 중심입니다."},
	{"id": &"ch_hidden_market", "name": "도깨비 시장", "summary": "이따금 나타나는 보물의 장입니다."},
]

enum Category { MONSTERS, RELICS, PLACES }

var _current_category: Category = Category.MONSTERS


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_monsters_tab.pressed.connect(_select_category.bind(Category.MONSTERS))
	_relics_tab.pressed.connect(_select_category.bind(Category.RELICS))
	_places_tab.pressed.connect(_select_category.bind(Category.PLACES))
	_select_category(Category.MONSTERS)


func _select_category(c: Category) -> void:
	_current_category = c
	_monsters_tab.button_pressed = c == Category.MONSTERS
	_relics_tab.button_pressed = c == Category.RELICS
	_places_tab.button_pressed = c == Category.PLACES
	_rebuild_grid()


func _rebuild_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var entries: Array = _entries_for_category(_current_category)
	var unlocked_count: int = 0
	for e in entries:
		var unlocked: bool = _is_unlocked(e.id)
		if unlocked:
			unlocked_count += 1
		_grid.add_child(_make_card(e, unlocked))
	_progress_label.text = "%s  %d / %d" % [_category_label(_current_category), unlocked_count, entries.size()]


func _category_label(c: Category) -> String:
	match c:
		Category.MONSTERS: return "요괴 도감"
		Category.RELICS:   return "신물 도감"
		_:                 return "장소 도감"


func _entries_for_category(c: Category) -> Array:
	match c:
		Category.MONSTERS: return MONSTER_ENTRIES
		Category.RELICS:   return RELIC_ENTRIES
		_:                 return PLACE_ENTRIES


func _is_unlocked(id: StringName) -> bool:
	if MetaState == null:
		return false
	var category_name: StringName = &"monsters"
	match _current_category:
		Category.MONSTERS: category_name = &"monsters"
		Category.RELICS:   category_name = &"relics"
		Category.PLACES:   category_name = &"places"
	return MetaState.is_codex_entry_unlocked(category_name, id)


func _make_card(entry: Dictionary, unlocked: bool) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE
	var v: VBoxContainer = VBoxContainer.new()
	v.name = "Body"
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)

	if unlocked:
		var name_label: Label = Label.new()
		name_label.text = String(entry.get("name", ""))
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", Color(0.878, 0.761, 0.235, 1))
		v.add_child(name_label)

		var summary: Label = Label.new()
		summary.text = String(entry.get("summary", ""))
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.add_theme_font_size_override("font_size", 12)
		summary.add_theme_color_override("font_color", Color(0.941, 0.929, 0.902, 0.85))
		v.add_child(summary)
	else:
		var silhouette: ColorRect = ColorRect.new()
		silhouette.custom_minimum_size = Vector2(180, 80)
		silhouette.color = Color(0.18, 0.16, 0.14, 1)
		v.add_child(silhouette)

		var locked_label: Label = Label.new()
		locked_label.text = "??? (미해금)"
		locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		locked_label.add_theme_font_size_override("font_size", 12)
		locked_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5, 1))
		v.add_child(locked_label)
	return panel


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
