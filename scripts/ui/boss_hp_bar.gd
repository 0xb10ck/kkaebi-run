extends CanvasLayer

# §6 — 보스 HP 바 UI. 보스명/페이즈 인디케이터/HP 비율 막대를 한 줄에 표시한다.
# BossBase의 phase_changed 시그널을 듣고, _process로 HP 비율을 폴링한다.

@onready var _root: Control = $Root
@onready var _name_label: Label = $Root/Bar/NameLabel
@onready var _phase_label: Label = $Root/Bar/PhaseLabel
@onready var _hp_bar: ProgressBar = $Root/Bar/HpBar

var _boss: Node
var _data: BossData
var _total_phases: int = 1
var _current_phase: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false


func bind_boss(boss: Node, data: BossData) -> void:
	_boss = boss
	_data = data
	if data == null:
		return
	_total_phases = max(1, data.phases.size())
	_current_phase = 0
	_name_label.text = data.display_name_ko
	_phase_label.text = _format_phase()
	_hp_bar.min_value = 0.0
	_hp_bar.max_value = 1.0
	_hp_bar.value = 1.0
	_root.visible = true
	if boss != null and boss.has_signal("phase_changed"):
		boss.connect("phase_changed", _on_phase_changed)
	if boss != null and boss.has_signal("died"):
		boss.connect("died", _on_boss_died)


func _process(_delta: float) -> void:
	if not is_instance_valid(_boss) or _data == null:
		return
	var ratio: float = 1.0
	var current_hp: int = int(_boss.get("current_hp"))
	if _data.hp > 0:
		ratio = clamp(float(current_hp) / float(_data.hp), 0.0, 1.0)
	_hp_bar.value = ratio


func _on_phase_changed(new_index: int) -> void:
	_current_phase = new_index
	_phase_label.text = _format_phase()


func _on_boss_died(_boss_id: StringName) -> void:
	_root.visible = false


func _format_phase() -> String:
	return "페이즈 %d / %d" % [_current_phase + 1, _total_phases]
