extends CanvasLayer

const HP_BAR_W: float = 320.0
const HP_BAR_H: float = 32.0
const EXP_BAR_W: float = 1280.0
const EXP_BAR_H: float = 16.0
const SLOT_SIZE: float = 40.0
const SLOT_GAP: float = 8.0

var hp_fill: ColorRect
var hp_label: Label
var level_label: Label
var timer_label: Label
var gold_label: Label
var exp_fill: ColorRect
var exp_label: Label
var skill_slots_root: Control


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build()
	GameState.hp_changed.connect(_on_hp_changed)
	GameState.xp_changed.connect(_on_xp_changed)
	GameState.level_changed.connect(_on_level_changed)
	GameState.gold_changed.connect(_on_gold_changed)
	SkillManager.skill_acquired.connect(_on_skill_acquired)
	_on_hp_changed(GameState.current_hp, GameState.max_hp)
	_on_xp_changed(GameState.current_xp, GameState.required_xp_for(GameState.level))
	_on_level_changed(GameState.level)
	_on_gold_changed(GameState.gold)
	_rebuild_skill_slots()


func _process(_delta: float) -> void:
	if timer_label:
		timer_label.text = _format_time(GameState.elapsed)


func _build() -> void:
	# === HP Bar ===
	var hp_root := Control.new()
	hp_root.name = "HPBar"
	hp_root.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	hp_root.offset_left = 20.0
	hp_root.offset_top = 20.0
	hp_root.offset_right = 20.0 + HP_BAR_W
	hp_root.offset_bottom = 20.0 + HP_BAR_H
	hp_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hp_root)
	var hp_outline := ColorRect.new()
	hp_outline.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	hp_outline.color = Palette.HP_OUTLINE
	hp_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_root.add_child(hp_outline)
	var hp_track := ColorRect.new()
	hp_track.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	hp_track.offset_left = 2.0
	hp_track.offset_top = 2.0
	hp_track.offset_right = HP_BAR_W - 2.0
	hp_track.offset_bottom = HP_BAR_H - 2.0
	hp_track.color = Palette.BLACK_LIGHT
	hp_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_root.add_child(hp_track)
	hp_fill = ColorRect.new()
	hp_fill.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	hp_fill.offset_left = 2.0
	hp_fill.offset_top = 2.0
	hp_fill.offset_right = HP_BAR_W - 2.0
	hp_fill.offset_bottom = HP_BAR_H - 2.0
	hp_fill.color = Palette.HP_GAUGE
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_root.add_child(hp_fill)
	hp_label = Label.new()
	hp_label.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.add_theme_color_override("font_color", Palette.WHITE_MAIN)
	hp_label.add_theme_color_override("font_outline_color", Palette.TEXT_OUTLINE)
	hp_label.add_theme_constant_override("outline_size", 4)
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_root.add_child(hp_label)

	# === Level Label ===
	level_label = Label.new()
	level_label.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	level_label.offset_left = 20.0
	level_label.offset_top = 60.0
	level_label.offset_right = 220.0
	level_label.offset_bottom = 90.0
	level_label.add_theme_color_override("font_color", Palette.WHITE_MAIN)
	level_label.add_theme_color_override("font_outline_color", Palette.TEXT_OUTLINE)
	level_label.add_theme_constant_override("outline_size", 4)
	level_label.add_theme_font_size_override("font_size", 20)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(level_label)

	# === Timer ===
	timer_label = Label.new()
	timer_label.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	timer_label.offset_left = 580.0
	timer_label.offset_top = 14.0
	timer_label.offset_right = 700.0
	timer_label.offset_bottom = 58.0
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 32)
	timer_label.add_theme_color_override("font_color", Palette.WHITE_MAIN)
	timer_label.add_theme_color_override("font_outline_color", Palette.TEXT_OUTLINE)
	timer_label.add_theme_constant_override("outline_size", 4)
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(timer_label)

	# === Gold ===
	gold_label = Label.new()
	gold_label.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	gold_label.offset_left = 1080.0
	gold_label.offset_top = 18.0
	gold_label.offset_right = 1260.0
	gold_label.offset_bottom = 50.0
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_label.add_theme_color_override("font_color", Palette.GOLD_TEXT)
	gold_label.add_theme_color_override("font_outline_color", Palette.TEXT_OUTLINE)
	gold_label.add_theme_constant_override("outline_size", 4)
	gold_label.add_theme_font_size_override("font_size", 22)
	gold_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gold_label)

	# === EXP Bar ===
	var exp_root := Control.new()
	exp_root.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	exp_root.offset_left = 0.0
	exp_root.offset_top = 704.0
	exp_root.offset_right = EXP_BAR_W
	exp_root.offset_bottom = 720.0
	exp_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(exp_root)
	var exp_track := ColorRect.new()
	exp_track.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	exp_track.color = Palette.EXP_TRACK
	exp_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exp_root.add_child(exp_track)
	exp_fill = ColorRect.new()
	exp_fill.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	exp_fill.offset_left = 0.0
	exp_fill.offset_top = 0.0
	exp_fill.offset_right = EXP_BAR_W
	exp_fill.offset_bottom = EXP_BAR_H
	exp_fill.color = Palette.EXP_GAUGE
	exp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exp_root.add_child(exp_fill)
	exp_label = Label.new()
	exp_label.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	exp_label.offset_right = -12.0
	exp_label.offset_left = 12.0
	exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	exp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exp_label.add_theme_color_override("font_color", Palette.BLACK_DARK)
	exp_label.add_theme_font_size_override("font_size", 12)
	exp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exp_root.add_child(exp_label)

	# === Skill Slots Root ===
	skill_slots_root = Control.new()
	skill_slots_root.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	var slots_w := SkillManager.ALL_SKILL_IDS.size() * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP
	skill_slots_root.offset_left = 1280.0 - 20.0 - slots_w
	skill_slots_root.offset_top = 660.0
	skill_slots_root.offset_right = 1280.0 - 20.0
	skill_slots_root.offset_bottom = 700.0
	skill_slots_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(skill_slots_root)


func _format_time(t: float) -> String:
	var seconds := int(t)
	var m := seconds / 60
	var s := seconds % 60
	return "%02d:%02d" % [m, s]


func _on_hp_changed(cur: int, mx: int) -> void:
	if hp_fill == null:
		return
	var ratio: float = clamp(float(cur) / max(1.0, float(mx)), 0.0, 1.0)
	hp_fill.offset_right = 2.0 + (HP_BAR_W - 4.0) * ratio
	hp_label.text = "%d / %d" % [cur, mx]


func _on_xp_changed(cur: int, req: int) -> void:
	if exp_fill == null:
		return
	var ratio: float = clamp(float(cur) / max(1.0, float(req)), 0.0, 1.0)
	exp_fill.offset_right = EXP_BAR_W * ratio
	exp_label.text = "Lv %d → %d   (%d / %d)" % [GameState.level, GameState.level + 1, cur, req]


func _on_level_changed(lv: int) -> void:
	if level_label:
		level_label.text = "Lv. %d" % lv
	if exp_label:
		exp_label.text = "Lv %d → %d   (%d / %d)" % [GameState.level, GameState.level + 1, GameState.current_xp, GameState.required_xp_for(GameState.level)]


func _on_gold_changed(g: int) -> void:
	if gold_label:
		gold_label.text = "금화 %d냥" % g


func _on_skill_acquired(_id: StringName) -> void:
	_rebuild_skill_slots()


func _rebuild_skill_slots() -> void:
	if skill_slots_root == null:
		return
	for c in skill_slots_root.get_children():
		c.queue_free()
	var idx := 0
	for sid in SkillManager.ALL_SKILL_IDS:
		var slot := ColorRect.new()
		slot.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
		slot.offset_left = idx * (SLOT_SIZE + SLOT_GAP)
		slot.offset_top = 0.0
		slot.offset_right = slot.offset_left + SLOT_SIZE
		slot.offset_bottom = SLOT_SIZE
		if SkillManager.is_owned(sid):
			var data: SkillData = SkillManager.skill_db.get(sid, null)
			if data:
				slot.color = data.icon_color
			else:
				slot.color = Palette.WHITE_DARK
		else:
			slot.color = Color(Palette.BLACK_LIGHT.r, Palette.BLACK_LIGHT.g, Palette.BLACK_LIGHT.b, 0.4)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skill_slots_root.add_child(slot)
		idx += 1
