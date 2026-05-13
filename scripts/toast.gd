extends CanvasLayer


# Total visible time ~1.5s (fade-in + hold + fade-out).
const FADE_IN_TIME: float = 0.25
const HOLD_TIME: float = 1.0
const FADE_OUT_TIME: float = 0.25


@onready var _label: Label = $Label

var _tween: Tween


func _ready() -> void:
	# Toast must keep playing while game is paused (e.g. during level-up panel).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label.process_mode = Node.PROCESS_MODE_ALWAYS
	_label.modulate.a = 0.0


func show_message(text: String) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_label.text = text
	_label.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 1.0, FADE_IN_TIME)
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(_label, "modulate:a", 0.0, FADE_OUT_TIME)
