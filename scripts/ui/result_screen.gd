extends CanvasLayer

signal retry_pressed
signal main_menu_pressed

var _title_label: Label
var _subtitle_label: Label
var _stat_labels: Dictionary = {}
var _retry_btn: Button
var _menu_btn: Button


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	bg.color = Color(0.0, 0.0, 0.0, 0.72)
	bg.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bg)

	_title_label = Label.new()
	_title_label.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	_title_label.offset_left = 0.0
	_title_label.offset_top = 80.0
	_title_label.offset_right = 1280.0
	_title_label.offset_bottom = 150.0
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 48)
	_title_label.add_theme_color_override("font_color", Palette.WHITE_MAIN)
	_title_label.add_theme_color_override("font_outline_color", Palette.TEXT_OUTLINE)
	_title_label.add_theme_constant_override("outline_size", 6)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	_subtitle_label.offset_left = 60.0
	_subtitle_label.offset_top = 160.0
	_subtitle_label.offset_right = 1220.0
	_subtitle_label.offset_bottom = 220.0
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 22)
	_subtitle_label.add_theme_color_override("font_color", Palette.WHITE_DARK)
	_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle_label)

	var divider := Label.new()
	divider.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	divider.offset_left = 0.0
	divider.offset_top = 240.0
	divider.offset_right = 1280.0
	divider.offset_bottom = 270.0
	divider.text = "─────  결 산  ─────"
	divider.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	divider.add_theme_font_size_override("font_size", 20)
	divider.add_theme_color_override("font_color", Palette.WHITE_DARK)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(divider)

	var stat_keys := [["time", "생존 시간"], ["kills", "처치한 잡귀"], ["level", "도달 레벨"], ["gold", "획득한 금화"]]
	var y := 290.0
	for k in stat_keys:
		var row := Control.new()
		row.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
		row.offset_left = 440.0
		row.offset_top = y
		row.offset_right = 840.0
		row.offset_bottom = y + 32.0
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)
		var lbl := Label.new()
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		lbl.text = k[1]
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Palette.WHITE_MAIN)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lbl)
		var value_lbl := Label.new()
		value_lbl.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_lbl.add_theme_font_size_override("font_size", 22)
		value_lbl.add_theme_color_override("font_color", Palette.YELLOW_LIGHT)
		value_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(value_lbl)
		_stat_labels[k[0]] = value_lbl
		y += 40.0

	_retry_btn = Button.new()
	_retry_btn.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	_retry_btn.offset_left = 480.0
	_retry_btn.offset_top = 500.0
	_retry_btn.offset_right = 800.0
	_retry_btn.offset_bottom = 556.0
	_retry_btn.text = "다시 도전하기"
	_retry_btn.add_theme_font_size_override("font_size", 28)
	_retry_btn.add_theme_color_override("font_color", Palette.WHITE_MAIN)
	_retry_btn.pressed.connect(_on_retry)
	add_child(_retry_btn)

	_menu_btn = Button.new()
	_menu_btn.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	_menu_btn.offset_left = 480.0
	_menu_btn.offset_top = 572.0
	_menu_btn.offset_right = 800.0
	_menu_btn.offset_bottom = 620.0
	_menu_btn.text = "메인 메뉴로 돌아가기"
	_menu_btn.add_theme_font_size_override("font_size", 24)
	_menu_btn.add_theme_color_override("font_color", Palette.WHITE_MAIN)
	_menu_btn.pressed.connect(_on_menu)
	add_child(_menu_btn)


func show_result(title: String, subtitle: String, elapsed: float, kills: int, level: int, gold: int) -> void:
	_title_label.text = title
	_subtitle_label.text = subtitle
	var sec := int(elapsed)
	var m := sec / 60
	var s := sec % 60
	_stat_labels["time"].text = "%02d분 %02d초" % [m, s]
	_stat_labels["kills"].text = "%d마리" % kills
	_stat_labels["level"].text = "Lv. %d" % level
	_stat_labels["gold"].text = "%d냥" % gold
	visible = true


func _on_retry() -> void:
	emit_signal("retry_pressed")


func _on_menu() -> void:
	emit_signal("main_menu_pressed")
