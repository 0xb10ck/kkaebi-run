extends Control


# §2.5 — 도감 화면. 몬스터/보스/스킬 3탭.
# resources/enemies/**/*.tres, resources/bosses/*.tres, resources/skills/*.tres 자동 로드.
# 잠금 카드는 실루엣 + "???", 해금 카드는 sprite_size_px와 placeholder_color로
# placeholder 박스를 그리고 lore_ko 본문을 보여 준다.
#
# 잠금 해제 출처: 몬스터는 MetaState.codex_monsters("discovered"=true), 보스도
# 같은 dict의 보스 id 키, 스킬은 codex_relics에 우선 두되 진행/획득 정보를 사용한다.

const MAIN_MENU_PATH: String = "res://scenes/main_menu/main_menu.tscn"
const CARD_SIZE: Vector2 = Vector2(210, 220)
const PLACEHOLDER_MAX: Vector2 = Vector2(180, 96)
const PLACEHOLDER_MIN: Vector2 = Vector2(24, 24)

const ENEMY_DIRS: Array[String] = [
	"res://resources/enemies/chapter1",
	"res://resources/enemies/chapter2",
	"res://resources/enemies/chapter3",
	"res://resources/enemies/chapter4",
	"res://resources/enemies/chapter5",
	"res://resources/enemies/hidden",
]
const BOSS_DIR: String = "res://resources/bosses"
const SKILL_DIR: String = "res://resources/skills"


@onready var _monsters_tab: Button = $Tabs/MonstersTab
@onready var _bosses_tab: Button = $Tabs/RelicsTab
@onready var _skills_tab: Button = $Tabs/PlacesTab
@onready var _progress_label: Label = $ProgressLabel
@onready var _grid: GridContainer = $Scroll/Grid
@onready var _back_button: Button = $BackButton

enum Category { MONSTERS, BOSSES, SKILLS }

var _monsters: Array[EnemyData] = []
var _bosses: Array[BossData] = []
var _skills: Array[SkillData] = []
var _current_category: Category = Category.MONSTERS


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	# 탭 레이블을 새 분류명으로 교체 (.tscn 노드 구조는 그대로).
	_monsters_tab.text = "몬스터"
	_bosses_tab.text = "보스"
	_skills_tab.text = "스킬"
	_monsters_tab.pressed.connect(_select_category.bind(Category.MONSTERS))
	_bosses_tab.pressed.connect(_select_category.bind(Category.BOSSES))
	_skills_tab.pressed.connect(_select_category.bind(Category.SKILLS))
	if not EventBus.codex_entry_unlocked.is_connected(_on_codex_entry_unlocked):
		EventBus.codex_entry_unlocked.connect(_on_codex_entry_unlocked)
	_load_all_resources()
	_select_category(Category.MONSTERS)


func _load_all_resources() -> void:
	_monsters.clear()
	for d in ENEMY_DIRS:
		for res in _load_resources_in(d):
			if res is EnemyData:
				_monsters.append(res)
	_monsters.sort_custom(func(a: EnemyData, b: EnemyData) -> bool:
		return String(a.id) < String(b.id))

	_bosses.clear()
	for res in _load_resources_in(BOSS_DIR):
		if res is BossData:
			_bosses.append(res)
	_bosses.sort_custom(func(a: BossData, b: BossData) -> bool:
		# 미니보스 → 챕터보스, 그다음 id 순.
		if a.is_mini_boss != b.is_mini_boss:
			return a.is_mini_boss
		return String(a.id) < String(b.id))

	_skills.clear()
	for res in _load_resources_in(SKILL_DIR):
		if res is SkillData:
			_skills.append(res)
	_skills.sort_custom(func(a: SkillData, b: SkillData) -> bool:
		return String(a.id) < String(b.id))


func _load_resources_in(dir_path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tres"):
			var res: Resource = load("%s/%s" % [dir_path, entry])
			if res != null:
				out.append(res)
		entry = dir.get_next()
	dir.list_dir_end()
	return out


func _select_category(c: Category) -> void:
	_current_category = c
	_monsters_tab.button_pressed = c == Category.MONSTERS
	_bosses_tab.button_pressed = c == Category.BOSSES
	_skills_tab.button_pressed = c == Category.SKILLS
	_rebuild_grid()


func _rebuild_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var total: int = 0
	var unlocked_count: int = 0
	match _current_category:
		Category.MONSTERS:
			total = _monsters.size()
			for m in _monsters:
				var unlocked: bool = _is_monster_unlocked(m.id)
				if unlocked:
					unlocked_count += 1
				_grid.add_child(_make_monster_card(m, unlocked))
		Category.BOSSES:
			total = _bosses.size()
			for b in _bosses:
				var unlocked: bool = _is_boss_unlocked(b.id)
				if unlocked:
					unlocked_count += 1
				_grid.add_child(_make_boss_card(b, unlocked))
		Category.SKILLS:
			total = _skills.size()
			for s in _skills:
				var unlocked: bool = _is_skill_unlocked(s.id)
				if unlocked:
					unlocked_count += 1
				_grid.add_child(_make_skill_card(s, unlocked))
	_progress_label.text = "%s  %d / %d" % [_category_label(_current_category), unlocked_count, total]


func _category_label(c: Category) -> String:
	match c:
		Category.MONSTERS: return "몬스터 도감"
		Category.BOSSES:   return "보스 도감"
		_:                 return "스킬 도감"


# === unlock checks ============================================================

func _is_monster_unlocked(id: StringName) -> bool:
	if MetaState == null:
		return false
	var e: Dictionary = MetaState.codex_monsters.get(id, {})
	return bool(e.get("discovered", false))


func _is_boss_unlocked(id: StringName) -> bool:
	# 보스 처치도 record_boss_defeated()를 통해 codex_monsters에 기록된다.
	if MetaState == null:
		return false
	var e: Dictionary = MetaState.codex_monsters.get(id, {})
	return bool(e.get("discovered", false))


func _is_skill_unlocked(id: StringName) -> bool:
	# 스킬은 SkillManager.획득 이력이나 MetaState.codex_relics를 활용한다.
	if MetaState == null:
		return false
	var e: Dictionary = MetaState.codex_relics.get(id, {})
	if bool(e.get("acquired", false)) or bool(e.get("discovered", false)):
		return true
	if SkillManager != null and SkillManager.has_method("has_ever_acquired"):
		return bool(SkillManager.has_ever_acquired(id))
	return false


# === card builders ============================================================

func _make_monster_card(data: EnemyData, unlocked: bool) -> Control:
	return _make_card(
		data.display_name_ko,
		data.lore_ko,
		_to_vec2(data.sprite_size_px),
		data.placeholder_color,
		unlocked,
	)


func _make_boss_card(data: BossData, unlocked: bool) -> Control:
	var col: Color = Color(0.85, 0.35, 0.35, 1)  # 보스 기본 placeholder 색.
	# BossData는 placeholder_color가 없으므로 미니/챕터 보스 구분으로 톤만 다르게.
	if data.is_mini_boss:
		col = Color(0.80, 0.55, 0.30, 1)
	return _make_card(
		data.display_name_ko,
		data.lore_ko,
		_to_vec2(data.sprite_size_px),
		col,
		unlocked,
	)


func _make_skill_card(data: SkillData, unlocked: bool) -> Control:
	# 스킬은 sprite가 아닌 아이콘 컬러를 placeholder로 사용. 크기는 표준 32x32.
	return _make_card(
		data.display_name_ko,
		data.description_ko,
		Vector2(32, 32),
		data.icon_color,
		unlocked,
	)


func _make_card(
	name_ko: String,
	body_ko: String,
	sprite_size: Vector2,
	placeholder_col: Color,
	unlocked: bool,
) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE

	var v: VBoxContainer = VBoxContainer.new()
	v.name = "Body"
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(v)

	# placeholder 박스 (sprite_size_px 비율 보존, 카드 폭에 맞춰 스케일).
	var placeholder_area: CenterContainer = CenterContainer.new()
	placeholder_area.custom_minimum_size = Vector2(0, PLACEHOLDER_MAX.y + 8)
	v.add_child(placeholder_area)

	var placeholder: ColorRect = ColorRect.new()
	placeholder.custom_minimum_size = _scaled_placeholder_size(sprite_size)
	if unlocked:
		placeholder.color = placeholder_col
	else:
		placeholder.color = Color(0.16, 0.14, 0.13, 1.0)
	placeholder_area.add_child(placeholder)

	# 이름
	var name_label: Label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 15)
	if unlocked:
		name_label.text = name_ko
		name_label.add_theme_color_override("font_color", Color(0.878, 0.761, 0.235, 1))
	else:
		name_label.text = "???"
		name_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5, 1))
	v.add_child(name_label)

	# 설명 / lore
	var lore_label: Label = Label.new()
	lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore_label.add_theme_font_size_override("font_size", 12)
	if unlocked:
		lore_label.text = body_ko if body_ko != "" else "(설명이 아직 기록되지 않았습니다.)"
		lore_label.add_theme_color_override("font_color", Color(0.941, 0.929, 0.902, 0.85))
	else:
		lore_label.text = "(미해금 — 더 많이 만나야 합니다.)"
		lore_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5, 1))
	v.add_child(lore_label)

	return panel


func _scaled_placeholder_size(sprite_size: Vector2) -> Vector2:
	# sprite_size_px의 가로/세로 비율을 유지하면서 카드 안에 맞게 스케일.
	if sprite_size.x <= 0.0 or sprite_size.y <= 0.0:
		return PLACEHOLDER_MIN
	var scale_x: float = PLACEHOLDER_MAX.x / sprite_size.x
	var scale_y: float = PLACEHOLDER_MAX.y / sprite_size.y
	var s: float = min(scale_x, scale_y)
	# 너무 작은 placeholder는 보이지 않으므로 하한선 확보.
	s = max(s, PLACEHOLDER_MIN.x / max(sprite_size.x, 1.0))
	return Vector2(sprite_size.x * s, sprite_size.y * s)


func _to_vec2(v: Vector2i) -> Vector2:
	return Vector2(float(v.x), float(v.y))


func _on_codex_entry_unlocked(_category: StringName, _entry_id: StringName) -> void:
	# 카테고리에 상관없이 현재 보고 있는 그리드를 새로 고친다.
	_rebuild_grid()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
