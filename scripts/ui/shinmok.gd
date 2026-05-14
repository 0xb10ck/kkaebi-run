extends Control


# §2.5 — 신목 화면. 6단계 시각화 + 다음 단계 비용 + 헌납 버튼.
# 헌납 버튼 → MetaState.donate_to_shinmok() → 단계 진행.

const MAIN_MENU_PATH: String = "res://scenes/main_menu/main_menu.tscn"

const STAGE_COLORS: Array[Color] = [
	Color(0.43, 0.32, 0.18, 1.0),
	Color(0.55, 0.42, 0.20, 1.0),
	Color(0.42, 0.55, 0.24, 1.0),
	Color(0.32, 0.66, 0.30, 1.0),
	Color(0.85, 0.70, 0.30, 1.0),
	Color(0.95, 0.88, 0.55, 1.0),
]

# 단계별 해금 컨텐츠 안내(텍스트 placeholder, .tres 도입 후 대체).
const STAGE_UNLOCKS: Array[String] = [
	"Lv.0: 두멍마을(1장) 챕터 진입",
	"Lv.1: 영구 강화 4종 해금",
	"Lv.2: 신령의 숲(2장) 챕터 해금",
	"Lv.3: 영구 강화 6종 해금 + 캐릭터 1명 추가",
	"Lv.4: 천상계(4장) 챕터 해금 + 도깨비 시장 등장률 상승",
	"Lv.5: 신목의 심장(5장) 챕터 해금 + 최종 진행",
]


@onready var _stage_label: Label = $StageLabel
@onready var _visual: ColorRect = $Visual
@onready var _orbs_label: Label = $OrbsLabel
@onready var _cost_label: Label = $CostLabel
@onready var _donate_button: Button = $DonateButton
@onready var _unlocks_body: Label = $UnlocksBody
@onready var _back_button: Button = $BackButton


func _ready() -> void:
	_donate_button.pressed.connect(_on_donate_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	if Engine.has_singleton("EventBus"):
		EventBus.shinmok_advanced.connect(_on_shinmok_advanced)
		EventBus.meta_currency_changed.connect(_on_currency_changed)
	_refresh_all()


func _refresh_all() -> void:
	var stage: int = 0
	var orbs: int = 0
	var cost: int = 0
	if MetaState != null:
		stage = int(MetaState.shinmok_stage) - 1
		orbs = int(MetaState.dokkaebi_orbs)
		cost = int(MetaState.get_next_shinmok_cost())
	stage = clamp(stage, 0, STAGE_COLORS.size() - 1)
	_visual.color = STAGE_COLORS[stage]
	var size_px: float = 80.0 + float(stage) * 24.0
	var center_x: float = 240.0
	var center_y: float = 210.0
	_visual.offset_left = center_x - size_px * 0.5
	_visual.offset_top = center_y - size_px * 0.5
	_visual.offset_right = center_x + size_px * 0.5
	_visual.offset_bottom = center_y + size_px * 0.5

	_stage_label.text = "신목 Lv.%d / 5" % stage
	_orbs_label.text = "도깨비 구슬 %d개" % orbs

	if stage >= 5:
		_cost_label.text = "신목이 완전히 자랐습니다."
		_donate_button.text = "최종 단계 도달"
		_donate_button.disabled = true
	else:
		_cost_label.text = "다음 단계 헌납 비용: %d개" % cost
		_donate_button.text = "헌납하기 (%d개)" % cost
		_donate_button.disabled = orbs < cost

	_unlocks_body.text = _format_unlocks(stage)


func _format_unlocks(current_stage: int) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for i in STAGE_UNLOCKS.size():
		var line: String = STAGE_UNLOCKS[i]
		if i <= current_stage:
			lines.append("✓ %s" % line)
		else:
			lines.append("· %s" % line)
	return "\n".join(lines)


func _on_donate_pressed() -> void:
	if MetaState == null:
		return
	var ok: bool = MetaState.donate_to_shinmok()
	if ok:
		EventBus.toast_requested.emit("신목이 한 단계 자랐습니다.", 1.5)
	else:
		EventBus.toast_requested.emit("구슬이 부족합니다.", 1.5)
	_refresh_all()


func _on_shinmok_advanced(_stage: int) -> void:
	_refresh_all()


func _on_currency_changed(_currency: StringName, _value: int) -> void:
	_refresh_all()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
