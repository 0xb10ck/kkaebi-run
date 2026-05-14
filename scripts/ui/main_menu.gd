extends Control


# §2.5 — 메인 메뉴. 7개 진입점(시작/캐릭터/영구 강화/신목/도감/도전과제/설정) +
# 신목 Lv.0~5 시각화 placeholder. 시작하기는 챕터 선택으로 이동.

const DEFAULT_CHARACTER_ID: StringName = &"ttukttaki"
const DEFAULT_CHAPTER_ID: StringName = &"ch01_dumeong"
const CHAPTER_SELECT_PATH: String = "res://scenes/ui/chapter_select.tscn"
const CHARACTER_SELECT_PATH: String = "res://scenes/ui/character_select.tscn"
const PERMANENT_UPGRADE_PATH: String = "res://scenes/ui/permanent_upgrade.tscn"
const SHINMOK_PATH: String = "res://scenes/ui/shinmok.tscn"
const CODEX_PATH: String = "res://scenes/ui/codex.tscn"
const ACHIEVEMENTS_PATH: String = "res://scenes/ui/achievements.tscn"

# §10 신목 6단계 placeholder 외형 (Lv.0~5).
const SHINMOK_COLORS: Array[Color] = [
	Color(0.43, 0.32, 0.18, 1.0),  # Lv.0 — 메마른 흙색
	Color(0.55, 0.42, 0.20, 1.0),  # Lv.1 — 어린 가지
	Color(0.42, 0.55, 0.24, 1.0),  # Lv.2 — 푸른 잎
	Color(0.32, 0.66, 0.30, 1.0),  # Lv.3 — 무성한 신록
	Color(0.85, 0.70, 0.30, 1.0),  # Lv.4 — 황금빛
	Color(0.95, 0.88, 0.55, 1.0),  # Lv.5 — 완성된 신목
]


@onready var _start_button: Button = $Buttons/StartButton
@onready var _character_button: Button = $Buttons/CharacterButton
@onready var _upgrade_button: Button = $Buttons/UpgradeButton
@onready var _shinmok_button: Button = $Buttons/ShinmokButton
@onready var _codex_button: Button = $Buttons/CodexButton
@onready var _achievements_button: Button = $Buttons/AchievementsButton
@onready var _settings_button: Button = $Buttons/SettingsButton
@onready var _shinmok_visual: ColorRect = $Shinmok/ShinmokVisual
@onready var _shinmok_label: Label = $Shinmok/ShinmokLabel
@onready var _orbs_label: Label = $OrbsLabel


func _ready() -> void:
	get_tree().paused = false
	_start_button.pressed.connect(_on_start_pressed)
	_character_button.pressed.connect(_on_character_pressed)
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	_shinmok_button.pressed.connect(_on_shinmok_pressed)
	_codex_button.pressed.connect(_on_codex_pressed)
	_achievements_button.pressed.connect(_on_achievements_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_refresh_shinmok_visual()
	_refresh_orbs_label()
	if Engine.has_singleton("EventBus"):
		EventBus.shinmok_advanced.connect(_on_shinmok_advanced)
		EventBus.meta_currency_changed.connect(_on_currency_changed)
	_start_button.grab_focus()


func _refresh_shinmok_visual() -> void:
	if MetaState == null:
		return
	var stage: int = clamp(int(MetaState.shinmok_stage) - 1, 0, SHINMOK_COLORS.size() - 1)
	_shinmok_visual.color = SHINMOK_COLORS[stage]
	# 단계가 올라갈수록 사각형이 커진다 (24~190px 사이).
	var size_px: float = 80.0 + float(stage) * 22.0
	var center_x: float = 110.0
	var center_y: float = 110.0
	_shinmok_visual.offset_left = center_x - size_px * 0.5
	_shinmok_visual.offset_top = center_y - size_px * 0.5
	_shinmok_visual.offset_right = center_x + size_px * 0.5
	_shinmok_visual.offset_bottom = center_y + size_px * 0.5
	_shinmok_label.text = "신목 Lv.%d" % (stage)


func _refresh_orbs_label() -> void:
	if MetaState == null:
		_orbs_label.text = "도깨비 구슬 0개"
		return
	_orbs_label.text = "도깨비 구슬 %d개" % int(MetaState.dokkaebi_orbs)


func _on_shinmok_advanced(_new_stage: int) -> void:
	_refresh_shinmok_visual()


func _on_currency_changed(_currency: StringName, _value: int) -> void:
	_refresh_orbs_label()


func _on_start_pressed() -> void:
	# 캐릭터를 메뉴에서 따로 고른 적이 없으면 기본 캐릭터를 선택해 둔다.
	if GameState != null and GameState.selected_character_id == &"":
		GameState.selected_character_id = DEFAULT_CHARACTER_ID
	get_tree().change_scene_to_file(CHAPTER_SELECT_PATH)


func _on_character_pressed() -> void:
	get_tree().change_scene_to_file(CHARACTER_SELECT_PATH)


func _on_upgrade_pressed() -> void:
	get_tree().change_scene_to_file(PERMANENT_UPGRADE_PATH)


func _on_shinmok_pressed() -> void:
	get_tree().change_scene_to_file(SHINMOK_PATH)


func _on_codex_pressed() -> void:
	get_tree().change_scene_to_file(CODEX_PATH)


func _on_achievements_pressed() -> void:
	get_tree().change_scene_to_file(ACHIEVEMENTS_PATH)


func _on_settings_pressed() -> void:
	# 설정 화면은 후속 작업. MVP에선 토스트만 표시.
	EventBus.toast_requested.emit("설정 화면은 곧 준비됩니다.", 1.5)
