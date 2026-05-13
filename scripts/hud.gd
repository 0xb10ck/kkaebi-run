extends CanvasLayer


const PAPER_COLOR: Color = Color("#F0EDE6")
const RED_COLOR: Color = Color("#E03C3C")
const GOLD_COLOR: Color = Color("#E0C23C")
const HP_BAR_W: float = 280.0
const EXP_BAR_W: float = 280.0
const TIMER_WARN_THRESHOLD: float = 10.0


signal pause_pressed


@onready var _hp_bg: ColorRect = $HPBarBg
@onready var _hp_fill: ColorRect = $HPBarBg/HPBarFill
@onready var _hp_label: Label = $HPBarBg/HPLabel
@onready var _exp_bg: ColorRect = $EXPBarBg
@onready var _exp_fill: ColorRect = $EXPBarBg/EXPBarFill
@onready var _level_label: Label = $LevelLabel
@onready var _coin_label: Label = $CoinLabel
@onready var _timer_label: Label = $TimerLabel
@onready var _pause_button: Button = $PauseButton


var _timer_warning: bool = false
var _blink_t: float = 0.0


func _ready() -> void:
	_pause_button.pressed.connect(_on_pause_pressed)


func _process(delta: float) -> void:
	if _timer_warning:
		_blink_t += delta
		var phase: float = fmod(_blink_t, 1.0)
		_timer_label.modulate.a = 1.0 if phase < 0.5 else 0.6
	else:
		_blink_t = 0.0
		if _timer_label.modulate.a != 1.0:
			_timer_label.modulate.a = 1.0


func set_hp(cur: int, max_hp: int) -> void:
	var ratio: float = 0.0
	if max_hp > 0:
		ratio = clamp(float(cur) / float(max_hp), 0.0, 1.0)
	_hp_fill.size.x = HP_BAR_W * ratio
	_hp_label.text = "%d / %d" % [cur, max_hp]


func set_exp(cur: int, max_exp: int, level: int) -> void:
	var ratio: float = 0.0
	if max_exp > 0:
		ratio = clamp(float(cur) / float(max_exp), 0.0, 1.0)
	_exp_fill.size.x = EXP_BAR_W * ratio
	_level_label.text = "Lv. %d" % level


func set_time(sec: float) -> void:
	var s: int = int(maxf(0.0, ceil(sec)))
	var mm: int = s / 60
	var ss: int = s % 60
	_timer_label.text = "%02d:%02d" % [mm, ss]
	var warn: bool = sec <= TIMER_WARN_THRESHOLD and sec > 0.0
	if warn != _timer_warning:
		_timer_warning = warn
		if warn:
			_timer_label.add_theme_color_override("font_color", RED_COLOR)
		else:
			_timer_label.add_theme_color_override("font_color", PAPER_COLOR)


func set_coins(n: int) -> void:
	_coin_label.text = "금화 %d" % n


func level_up_effect() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_level_label, "scale", Vector2(1.2, 1.2), 0.1)
	tw.tween_property(_level_label, "scale", Vector2(1.0, 1.0), 0.1)


func _on_pause_pressed() -> void:
	pause_pressed.emit()
