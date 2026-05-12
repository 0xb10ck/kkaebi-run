extends CanvasLayer

signal card_selected(card_data: Dictionary)

const CARD_WIDTH: float = 260.0
const CARD_HEIGHT: float = 340.0
const CARD_GAP: float = 28.0

var cards_root: Control = null
var _cards: Array = []
var _buttons: Array = []


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bg)
	var title := Label.new()
	title.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	title.offset_left = 0.0
	title.offset_top = 60.0
	title.offset_right = 1280.0
	title.offset_bottom = 130.0
	title.text = "신통을 골라 주십시오"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Palette.WHITE_MAIN)
	title.add_theme_color_override("font_outline_color", Palette.TEXT_OUTLINE)
	title.add_theme_constant_override("outline_size", 6)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	cards_root = Control.new()
	cards_root.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	cards_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(cards_root)


func populate(cards: Array) -> void:
	_cards.clear()
	for c in cards:
		_cards.append(c)
	for c in cards_root.get_children():
		c.queue_free()
	_buttons.clear()
	var n := _cards.size()
	var total_w := CARD_WIDTH * float(n) + CARD_GAP * float(max(0, n - 1))
	var start_x := (1280.0 - total_w) * 0.5
	var y := 170.0
	for i in range(n):
		var data: Dictionary = _cards[i]
		var btn := Button.new()
		btn.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
		btn.offset_left = start_x + float(i) * (CARD_WIDTH + CARD_GAP)
		btn.offset_top = y
		btn.offset_right = btn.offset_left + CARD_WIDTH
		btn.offset_bottom = y + CARD_HEIGHT
		btn.add_theme_color_override("font_color", Palette.WHITE_MAIN)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_on_card_pressed.bind(i))
		cards_root.add_child(btn)

		var inner := VBoxContainer.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		inner.offset_left = 16.0
		inner.offset_top = 18.0
		inner.offset_right = -16.0
		inner.offset_bottom = -16.0
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(inner)

		var icon_row := CenterContainer.new()
		icon_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(icon_row)
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(96.0, 96.0)
		var ic: Color = data.get("icon_color", Palette.WHITE_MAIN)
		icon.color = ic
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_row.add_child(icon)

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0.0, 16.0)
		inner.add_child(spacer)

		var name_label := Label.new()
		name_label.text = "[%d] %s" % [i + 1, str(data.get("title", "신통"))]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", Palette.WHITE_MAIN)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(name_label)

		var desc := Label.new()
		desc.text = str(data.get("description", ""))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 14)
		desc.add_theme_color_override("font_color", Palette.WHITE_DARK)
		desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(desc)
		_buttons.append(btn)


func show_modal() -> void:
	visible = true


func hide_modal() -> void:
	visible = false


func is_visible() -> bool:
	return visible


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("skill_select_1"):
		_select(0)
	elif event.is_action_pressed("skill_select_2"):
		_select(1)
	elif event.is_action_pressed("skill_select_3"):
		_select(2)


func _on_card_pressed(idx: int) -> void:
	_select(idx)


func _select(idx: int) -> void:
	if idx < 0 or idx >= _cards.size():
		return
	var data: Dictionary = _cards[idx]
	emit_signal("card_selected", data)
