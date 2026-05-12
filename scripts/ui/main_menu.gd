extends Control

signal start_pressed


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT, true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	bg.color = Palette.BLACK_MAIN
	bg.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bg)

	var title := Label.new()
	title.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	title.offset_left = 0.0
	title.offset_top = 160.0
	title.offset_right = 1280.0
	title.offset_bottom = 260.0
	title.text = "깨비런"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Palette.SHINMOK_GOLD)
	title.add_theme_color_override("font_outline_color", Palette.BLACK_DARK)
	title.add_theme_constant_override("outline_size", 8)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	var subtitle := Label.new()
	subtitle.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	subtitle.offset_left = 0.0
	subtitle.offset_top = 280.0
	subtitle.offset_right = 1280.0
	subtitle.offset_bottom = 320.0
	subtitle.text = "두멍마을의 새벽까지 살아 남으십시오."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Palette.WHITE_DARK)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(subtitle)

	var hint := Label.new()
	hint.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	hint.offset_left = 0.0
	hint.offset_top = 326.0
	hint.offset_right = 1280.0
	hint.offset_bottom = 360.0
	hint.text = "이동: WASD 또는 방향키    /    선택: 마우스 또는 1·2·3"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Palette.WHITE_DARK)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	btn.offset_left = 540.0
	btn.offset_top = 420.0
	btn.offset_right = 740.0
	btn.offset_bottom = 480.0
	btn.text = "시작하기"
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", Palette.WHITE_MAIN)
	btn.pressed.connect(_on_start)
	add_child(btn)


func _on_start() -> void:
	start_pressed.emit()
