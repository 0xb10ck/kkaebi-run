class_name BossCutscene
extends CanvasLayer

# §5.3 — 보스 등장/사망 컷인 베이스. 페이드 + 이름 + 출전 1줄. 서브클래스로 확장 가능.

signal finished

@export var duration_s: float = 2.5
@export var portrait_texture: Texture2D
@export var name_label_ko: String = ""
@export var subtitle_label_ko: String = ""
@export var bg_color: Color = Color(0, 0, 0, 0.7)

var _bg: ColorRect
var _name_label: Label
var _subtitle_label: Label


func _ready() -> void:
	layer = 30
	_bg = ColorRect.new()
	_bg.color = Color(bg_color.r, bg_color.g, bg_color.b, 0.0)
	_bg.anchor_right = 1.0
	_bg.anchor_bottom = 1.0
	add_child(_bg)
	_name_label = Label.new()
	_name_label.text = name_label_ko
	_name_label.add_theme_font_size_override("font_size", 36)
	_name_label.modulate = Color(1, 1, 1, 0)
	_name_label.anchor_left = 0.0
	_name_label.anchor_top = 0.4
	_name_label.anchor_right = 1.0
	_name_label.anchor_bottom = 0.55
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_name_label)
	_subtitle_label = Label.new()
	_subtitle_label.text = subtitle_label_ko
	_subtitle_label.add_theme_font_size_override("font_size", 16)
	_subtitle_label.modulate = Color(1, 1, 1, 0)
	_subtitle_label.anchor_left = 0.0
	_subtitle_label.anchor_top = 0.56
	_subtitle_label.anchor_right = 1.0
	_subtitle_label.anchor_bottom = 0.68
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_subtitle_label)


func play() -> void:
	var fade_in: float = min(0.4, duration_s * 0.25)
	var hold: float = max(0.0, duration_s - fade_in * 2.0)
	var fade_out: float = fade_in
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_bg, "color:a", bg_color.a, fade_in)
	tw.tween_property(_name_label, "modulate:a", 1.0, fade_in)
	tw.tween_property(_subtitle_label, "modulate:a", 1.0, fade_in)
	tw.set_parallel(false)
	tw.tween_interval(hold)
	tw.set_parallel(true)
	tw.tween_property(_bg, "color:a", 0.0, fade_out)
	tw.tween_property(_name_label, "modulate:a", 0.0, fade_out)
	tw.tween_property(_subtitle_label, "modulate:a", 0.0, fade_out)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void: finished.emit())
