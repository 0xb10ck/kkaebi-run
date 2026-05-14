extends Control


# §2.5 — 영구 강화 화면. 8종 MetaUpgradeData를 그리드로 표시.
# 구매 버튼 → MetaState.purchase_upgrade(key) → 구슬 차감 + 레벨 증가.

const UPGRADE_RES_DIR: String = "res://resources/meta_upgrades"
const MAIN_MENU_PATH: String = "res://scenes/main_menu/main_menu.tscn"
const CARD_SIZE: Vector2 = Vector2(210, 170)


@onready var _grid: GridContainer = $Scroll/Grid
@onready var _orbs_label: Label = $OrbsLabel
@onready var _back_button: Button = $BackButton

var _upgrades: Array[MetaUpgradeData] = []
var _key_to_card: Dictionary = {}


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_load_upgrades()
	_build_cards()
	_refresh_orbs()
	if Engine.has_singleton("EventBus"):
		EventBus.meta_changed.connect(_on_meta_changed)
		EventBus.meta_currency_changed.connect(_on_currency_changed)


func _load_upgrades() -> void:
	_upgrades.clear()
	var dir: DirAccess = DirAccess.open(UPGRADE_RES_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".tres"):
			var res: Resource = load("%s/%s" % [UPGRADE_RES_DIR, name])
			if res is MetaUpgradeData:
				_upgrades.append(res)
				if MetaState != null:
					MetaState.register_upgrade_def(res)
		name = dir.get_next()
	dir.list_dir_end()
	_upgrades.sort_custom(func(a: MetaUpgradeData, b: MetaUpgradeData) -> bool:
		return String(a.key) < String(b.key))


func _build_cards() -> void:
	_key_to_card.clear()
	for child in _grid.get_children():
		child.queue_free()
	for u in _upgrades:
		var card: Control = _make_card(u)
		_grid.add_child(card)
		_key_to_card[u.key] = card


func _make_card(u: MetaUpgradeData) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE
	var v: VBoxContainer = VBoxContainer.new()
	v.name = "Body"
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)

	var name_label: Label = Label.new()
	name_label.text = u.display_name_ko
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.878, 0.761, 0.235, 1))
	v.add_child(name_label)

	var level_label: Label = Label.new()
	level_label.name = "LevelLabel"
	level_label.add_theme_font_size_override("font_size", 13)
	level_label.add_theme_color_override("font_color", Color(0.941, 0.929, 0.902, 0.9))
	v.add_child(level_label)

	var effect_label: Label = Label.new()
	effect_label.name = "EffectLabel"
	effect_label.add_theme_font_size_override("font_size", 12)
	effect_label.add_theme_color_override("font_color", Color(0.941, 0.929, 0.902, 0.75))
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(effect_label)

	var buy_button: Button = Button.new()
	buy_button.name = "BuyButton"
	buy_button.add_theme_font_size_override("font_size", 13)
	buy_button.pressed.connect(_on_buy_pressed.bind(u.key))
	v.add_child(buy_button)

	_apply_card_state(panel, u)
	return panel


func _apply_card_state(card: Control, u: MetaUpgradeData) -> void:
	var level_label: Label = card.get_node_or_null("Body/LevelLabel")
	var effect_label: Label = card.get_node_or_null("Body/EffectLabel")
	var buy_button: Button = card.get_node_or_null("Body/BuyButton")
	if level_label == null or effect_label == null or buy_button == null:
		return

	var lv: int = 0
	var max_lv: int = u.max_level
	var current_effect: float = 0.0
	var next_effect: float = 0.0
	var cost: int = u.cost_for(1)
	var orbs: int = 0
	var gated: bool = false
	if MetaState != null:
		lv = MetaState.get_upgrade_level(u.key)
		max_lv = MetaState.get_upgrade_max_level(u.key)
		current_effect = MetaState.get_upgrade_effect(u.key)
		next_effect = u.effect_at(lv + 1)
		cost = MetaState.get_upgrade_cost(u.key, lv + 1)
		orbs = int(MetaState.dokkaebi_orbs)
		gated = MetaState.shinmok_stage < u.requires_shinmok_stage

	level_label.text = "Lv.%d / %d" % [lv, max_lv]
	effect_label.text = "현재 +%s\n다음 +%s" % [_fmt_effect(u, current_effect), _fmt_effect(u, next_effect)]

	if lv >= max_lv:
		buy_button.text = "만렙 도달"
		buy_button.disabled = true
	elif gated:
		buy_button.text = "신목 Lv.%d 필요" % u.requires_shinmok_stage
		buy_button.disabled = true
	else:
		buy_button.text = "강화하기 (%d개)" % cost
		buy_button.disabled = orbs < cost


func _fmt_effect(u: MetaUpgradeData, e: float) -> String:
	match u.effect_kind:
		&"additive_percent":
			return "%.0f%%" % (e * 100.0)
		&"count":
			return "%d회" % int(round(e))
		_:
			return "%.2f" % e


func _on_buy_pressed(key: StringName) -> void:
	if MetaState == null:
		return
	var ok: bool = MetaState.purchase_upgrade(key)
	if ok:
		EventBus.toast_requested.emit("강화가 완료되었습니다.", 1.2)
	else:
		EventBus.toast_requested.emit("구슬이 부족하거나 조건을 충족하지 못했습니다.", 1.5)
	_refresh_all()


func _refresh_all() -> void:
	for u in _upgrades:
		var card: Control = _key_to_card.get(u.key, null)
		if card:
			_apply_card_state(card, u)
	_refresh_orbs()


func _refresh_orbs() -> void:
	if MetaState == null:
		_orbs_label.text = "도깨비 구슬 0개"
		return
	_orbs_label.text = "도깨비 구슬 %d개" % int(MetaState.dokkaebi_orbs)


func _on_meta_changed(_key: StringName, _value: Variant) -> void:
	_refresh_all()


func _on_currency_changed(_currency: StringName, _value: int) -> void:
	_refresh_all()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
