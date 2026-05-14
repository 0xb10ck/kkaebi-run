extends Control


# §2.5 — 도전과제 화면. 일회성/일일/주간 3탭.
# 진행도 바 + 보상 수령 버튼 → MetaState.claim_achievement(id) 호출.

const MAIN_MENU_PATH: String = "res://scenes/main_menu/main_menu.tscn"

# Placeholder 정의 — id/카테고리/이름/설명/목표/보상.
# 실제 데이터는 AchievementData .tres로 교체 예정.
const ACHIEVEMENT_DEFS: Array = [
	# 일회성
	{"id": &"ach_first_clear", "cat": &"once",   "name": "첫 챕터를 마치셨습니다", "desc": "1장 두멍마을을 클리어해 주십시오.", "target": 1, "reward": 50},
	{"id": &"ach_kill_1000",  "cat": &"once",   "name": "천 마리의 요괴", "desc": "누적 1,000마리를 처치해 주십시오.", "target": 1000, "reward": 80},
	{"id": &"ach_unlock_3",   "cat": &"once",   "name": "동료를 모으셨습니다", "desc": "캐릭터 3명을 해금해 주십시오.", "target": 3, "reward": 100},
	# 일일
	{"id": &"ach_daily_run",  "cat": &"daily",  "name": "오늘의 출정", "desc": "오늘 한 차례 런을 마쳐 주십시오.", "target": 1, "reward": 20},
	{"id": &"ach_daily_kill", "cat": &"daily",  "name": "오늘의 사냥꾼", "desc": "오늘 200마리를 처치해 주십시오.", "target": 200, "reward": 30},
	# 주간
	{"id": &"ach_weekly_boss","cat": &"weekly", "name": "이번 주의 토벌", "desc": "이번 주 보스를 5회 처치해 주십시오.", "target": 5, "reward": 80},
	{"id": &"ach_weekly_orbs","cat": &"weekly", "name": "이번 주의 수확", "desc": "이번 주 도깨비 구슬 500개를 모아 주십시오.", "target": 500, "reward": 60},
]

enum Category { ONCE, DAILY, WEEKLY }


@onready var _once_tab: Button = $Tabs/OnceTab
@onready var _daily_tab: Button = $Tabs/DailyTab
@onready var _weekly_tab: Button = $Tabs/WeeklyTab
@onready var _list: VBoxContainer = $Scroll/List
@onready var _back_button: Button = $BackButton

var _current_category: Category = Category.ONCE


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_once_tab.pressed.connect(_select_category.bind(Category.ONCE))
	_daily_tab.pressed.connect(_select_category.bind(Category.DAILY))
	_weekly_tab.pressed.connect(_select_category.bind(Category.WEEKLY))
	_select_category(Category.ONCE)


func _select_category(c: Category) -> void:
	_current_category = c
	_once_tab.button_pressed = c == Category.ONCE
	_daily_tab.button_pressed = c == Category.DAILY
	_weekly_tab.button_pressed = c == Category.WEEKLY
	_rebuild_list()


func _rebuild_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	var cat_key: StringName = _category_key(_current_category)
	for d in ACHIEVEMENT_DEFS:
		if d.cat != cat_key:
			continue
		_list.add_child(_make_row(d))


func _category_key(c: Category) -> StringName:
	match c:
		Category.ONCE: return &"once"
		Category.DAILY: return &"daily"
		_: return &"weekly"


func _make_row(d: Dictionary) -> Control:
	var id: StringName = d.id
	var target: int = int(d.target)
	var reward: int = int(d.reward)
	var progress: int = 0
	var claimed: bool = false
	if MetaState != null:
		var entry: Dictionary = MetaState.achievements.get(id, {})
		progress = int(entry.get("progress", 0))
		claimed = bool(entry.get("claimed", false))

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
	name_label.text = String(d.name)
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.878, 0.761, 0.235, 1))
	info.add_child(name_label)

	var desc_label: Label = Label.new()
	desc_label.text = String(d.desc)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.941, 0.929, 0.902, 0.85))
	info.add_child(desc_label)

	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = target
	bar.value = clamp(progress, 0, target)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	info.add_child(bar)

	var progress_label: Label = Label.new()
	progress_label.text = "%d / %d  보상 %d개" % [min(progress, target), target, reward]
	progress_label.add_theme_font_size_override("font_size", 11)
	progress_label.add_theme_color_override("font_color", Color(0.941, 0.929, 0.902, 0.75))
	info.add_child(progress_label)

	var claim: Button = Button.new()
	claim.custom_minimum_size = Vector2(96, 80)
	claim.add_theme_font_size_override("font_size", 13)
	if claimed:
		claim.text = "수령 완료"
		claim.disabled = true
	elif progress < target:
		claim.text = "진행 중"
		claim.disabled = true
	else:
		claim.text = "수령하기"
		claim.disabled = false
	claim.pressed.connect(_on_claim_pressed.bind(id, target, reward))
	row.add_child(claim)
	return panel


func _on_claim_pressed(id: StringName, target: int, reward: int) -> void:
	if MetaState == null:
		return
	# 도전과제 엔트리가 아직 존재하지 않을 수도 있으므로 진행도 정합성을 한 번 보정.
	var entry: Dictionary = MetaState.achievements.get(id, {})
	entry["progress"] = max(int(entry.get("progress", 0)), target)
	entry["target"] = target
	entry["reward_orbs"] = reward
	entry["claimed"] = bool(entry.get("claimed", false))
	MetaState.achievements[id] = entry
	var ok: bool = MetaState.claim_achievement(id)
	if ok:
		EventBus.toast_requested.emit("보상을 수령하셨습니다.", 1.5)
	else:
		EventBus.toast_requested.emit("아직 수령할 수 없습니다.", 1.5)
	_rebuild_list()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
