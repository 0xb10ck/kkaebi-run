extends Control

@export var lifetime: float = 1.8
@export var fade_in_time: float = 0.3
@export var fade_out_time: float = 0.3

var _label: Label = null
var _t: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	offset_left = 0.0
	offset_top = 90.0
	offset_right = 1280.0
	offset_bottom = 150.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", Palette.WHITE_MAIN)
	_label.add_theme_color_override("font_outline_color", Palette.TEXT_OUTLINE)
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	modulate.a = 0.0


func show_text(text: String) -> void:
	if _label:
		_label.text = text
	_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t < fade_in_time:
		modulate.a = clamp(_t / fade_in_time, 0.0, 1.0)
	elif _t < lifetime - fade_out_time:
		modulate.a = 1.0
	elif _t < lifetime:
		modulate.a = clamp((lifetime - _t) / fade_out_time, 0.0, 1.0)
	else:
		queue_free()
