extends Control


# §2.5 — 신목 화면. 6단계 시각화 + 다음 단계 비용 + 헌납 버튼.
# 헌납 버튼 → MetaState.donate_to_shinmok() → 단계 진행 → 자동 저장.
# 신목은 '뿌리 → 줄기 → 가지 → 잎' 노드 트리로 표현되며, 단계가 오를수록 노드가 켜진다.

const MAIN_MENU_PATH: String = "res://scenes/main_menu/main_menu.tscn"

# 단계별 신목 색상 (배경 모듈레이션 + 트리 톤).
const STAGE_COLORS: Array[Color] = [
	Color(0.43, 0.32, 0.18, 1.0),
	Color(0.55, 0.42, 0.20, 1.0),
	Color(0.42, 0.55, 0.24, 1.0),
	Color(0.32, 0.66, 0.30, 1.0),
	Color(0.85, 0.70, 0.30, 1.0),
	Color(0.95, 0.88, 0.55, 1.0),
]

const NODE_KIND_ROOT: StringName = &"root"
const NODE_KIND_TRUNK: StringName = &"trunk"
const NODE_KIND_BRANCH: StringName = &"branch"
const NODE_KIND_LEAF: StringName = &"leaf"

# 단계별 해금 컨텐츠 안내. ShinmokStageData .tres 도입 시 대체.
const STAGE_UNLOCKS: Array[String] = [
	"Lv.0 — 뿌리: 두멍마을(1장) 챕터 진입",
	"Lv.1 — 줄기: 영구 강화 4종 해금",
	"Lv.2 — 가지: 신령의 숲(2장) 챕터 해금",
	"Lv.3 — 잎: 영구 강화 6종 해금 + 캐릭터 1명 추가",
	"Lv.4 — 큰잎: 천상계(4장) 챕터 해금 + 도깨비 시장 등장률 상승",
	"Lv.5 — 만개: 신목의 심장(5장) 챕터 해금 + 최종 진행",
]

# 노드 트리 정의: 각 노드는 (kind, stage_required, relative_pos_in_visual)
# 좌표는 Visual 박스 내부에서의 정규화 위치 (0..1).
const TREE_NODES: Array[Dictionary] = [
	{"kind": NODE_KIND_ROOT,   "stage": 0, "pos": Vector2(0.30, 0.92)},
	{"kind": NODE_KIND_ROOT,   "stage": 0, "pos": Vector2(0.70, 0.92)},
	{"kind": NODE_KIND_TRUNK,  "stage": 1, "pos": Vector2(0.50, 0.72)},
	{"kind": NODE_KIND_TRUNK,  "stage": 1, "pos": Vector2(0.50, 0.55)},
	{"kind": NODE_KIND_BRANCH, "stage": 2, "pos": Vector2(0.30, 0.45)},
	{"kind": NODE_KIND_BRANCH, "stage": 2, "pos": Vector2(0.70, 0.45)},
	{"kind": NODE_KIND_LEAF,   "stage": 3, "pos": Vector2(0.20, 0.28)},
	{"kind": NODE_KIND_LEAF,   "stage": 3, "pos": Vector2(0.80, 0.28)},
	{"kind": NODE_KIND_LEAF,   "stage": 4, "pos": Vector2(0.40, 0.18)},
	{"kind": NODE_KIND_LEAF,   "stage": 4, "pos": Vector2(0.60, 0.18)},
	{"kind": NODE_KIND_LEAF,   "stage": 5, "pos": Vector2(0.50, 0.06)},
]


@onready var _stage_label: Label = $StageLabel
@onready var _visual: ColorRect = $Visual
@onready var _orbs_label: Label = $OrbsLabel
@onready var _cost_label: Label = $CostLabel
@onready var _donate_button: Button = $DonateButton
@onready var _unlocks_body: Label = $UnlocksBody
@onready var _back_button: Button = $BackButton

var _node_widgets: Array[ColorRect] = []


func _ready() -> void:
	_donate_button.pressed.connect(_on_donate_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	if not EventBus.shinmok_advanced.is_connected(_on_shinmok_advanced):
		EventBus.shinmok_advanced.connect(_on_shinmok_advanced)
	if not EventBus.meta_currency_changed.is_connected(_on_currency_changed):
		EventBus.meta_currency_changed.connect(_on_currency_changed)
	_visual.resized.connect(_layout_tree_widgets)
	_build_tree_widgets()
	_refresh_all()


func _build_tree_widgets() -> void:
	for w in _node_widgets:
		if is_instance_valid(w):
			w.queue_free()
	_node_widgets.clear()
	for node_def in TREE_NODES:
		var dot: ColorRect = ColorRect.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var size_px: Vector2 = _node_size_for(node_def["kind"])
		dot.custom_minimum_size = size_px
		dot.size = size_px
		_visual.add_child(dot)
		_node_widgets.append(dot)
	_layout_tree_widgets()


func _layout_tree_widgets() -> void:
	var box: Vector2 = _visual.size
	if box.x <= 0.0 or box.y <= 0.0:
		box = Vector2(
			_visual.offset_right - _visual.offset_left,
			_visual.offset_bottom - _visual.offset_top,
		)
	for i in TREE_NODES.size():
		if i >= _node_widgets.size():
			break
		var node_def: Dictionary = TREE_NODES[i]
		var rel: Vector2 = node_def["pos"]
		var widget: ColorRect = _node_widgets[i]
		var size_px: Vector2 = widget.size
		widget.position = Vector2(
			rel.x * box.x - size_px.x * 0.5,
			rel.y * box.y - size_px.y * 0.5,
		)


func _node_size_for(kind: StringName) -> Vector2:
	match kind:
		NODE_KIND_ROOT:   return Vector2(20, 12)
		NODE_KIND_TRUNK:  return Vector2(16, 22)
		NODE_KIND_BRANCH: return Vector2(18, 14)
		NODE_KIND_LEAF:   return Vector2(16, 16)
		_:                return Vector2(14, 14)


func _node_color_for(kind: StringName, unlocked: bool) -> Color:
	if not unlocked:
		return Color(0.18, 0.16, 0.14, 0.95)
	match kind:
		NODE_KIND_ROOT:   return Color(0.50, 0.36, 0.20, 1.0)
		NODE_KIND_TRUNK:  return Color(0.60, 0.42, 0.22, 1.0)
		NODE_KIND_BRANCH: return Color(0.40, 0.60, 0.28, 1.0)
		NODE_KIND_LEAF:   return Color(0.85, 0.70, 0.30, 1.0)
		_:                return Color(0.85, 0.85, 0.85, 1.0)


func _refresh_all() -> void:
	var stage: int = 0
	var orbs: int = 0
	var cost: int = 0
	if MetaState != null:
		stage = int(MetaState.shinmok_stage) - 1
		orbs = int(MetaState.dokkaebi_orbs)
		cost = int(MetaState.get_next_shinmok_cost())
	stage = clamp(stage, 0, STAGE_COLORS.size() - 1)

	_visual.color = STAGE_COLORS[stage].darkened(0.55)
	_layout_tree_widgets()
	for i in TREE_NODES.size():
		if i >= _node_widgets.size():
			break
		var node_def: Dictionary = TREE_NODES[i]
		var required: int = int(node_def["stage"])
		var unlocked: bool = stage >= required
		_node_widgets[i].color = _node_color_for(node_def["kind"], unlocked)

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
