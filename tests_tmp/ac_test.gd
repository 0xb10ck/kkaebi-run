extends SceneTree

var phase_changed_count: int = 0
var run_started_called: bool = false

func _initialize() -> void:
	# Defer until autoloads are ready - one frame
	process_frame.connect(_run_tests_once, CONNECT_ONE_SHOT)

func _run_tests_once() -> void:
	_run_tests()
	quit()

func _run_tests() -> void:
	print("=== AC_TEST_START ===")
	var EB: Node = root.get_node("EventBus")
	var CM: Node = root.get_node("ChapterManager")
	var MS: Node = root.get_node("MetaState")

	EB.run_started.connect(_on_run_started)
	EB.run_started.emit(&"test_char", &"ch01_dumeong")
	print("AC10:run_started_callback=", run_started_called)

	var ch_list: Array = CM.get_chapter_list()
	print("AC4:chapters_count=", ch_list.size())
	print("AC4:advance_stage=", CM.has_method("advance_stage"))
	print("AC4:start_boss_battle=", CM.has_method("start_boss_battle"))
	print("AC4:start_interlude=", CM.has_method("start_interlude"))
	print("AC4:start_next_chapter=", CM.has_method("start_next_chapter"))

	var prev_orbs: int = MS.dokkaebi_orbs
	var prev_dtl: int = MS.divine_tree_level
	MS.dokkaebi_orbs = 1234
	MS.divine_tree_level = 3
	print("AC7:set divine=", MS.divine_tree_level, " orbs=", MS.dokkaebi_orbs)
	if MS.has_method("save"):
		MS.save()
	var fa: FileAccess = FileAccess.open("user://save.json", FileAccess.READ)
	if fa != null:
		print("AC7:save_json_exists=true size=", fa.get_length())
		fa.close()
	else:
		print("AC7:save_json_exists=false")
	MS.dokkaebi_orbs = 0
	MS.divine_tree_level = 0
	if MS.has_method("load"):
		MS.load()
	print("AC7:after_load orbs=", MS.dokkaebi_orbs, " divine=", MS.divine_tree_level)

	var rs: RunSettlement = RunSettlement.new()
	var before: int = MS.dokkaebi_orbs
	var settled: int = rs.settle(100, 600.0, 2)
	var after: int = MS.dokkaebi_orbs
	print("AC11:settled=", settled, " before=", before, " after=", after, " delta=", after - before)

	var BossBaseScript: Script = load("res://scripts/bosses/boss_base.gd")
	var boss_node: Node = BossBaseScript.new()
	var bd: BossData = BossData.new()
	bd.id = &"dummy"
	bd.max_hp = 1000
	var p1: BossPhase = BossPhase.new()
	p1.hp_threshold_percent = 0.5
	var p2: BossPhase = BossPhase.new()
	p2.hp_threshold_percent = 0.25
	bd.phases = [p1, p2]
	boss_node.phase_changed.connect(_on_phase_changed)
	root.add_child(boss_node)
	if boss_node.has_method("setup"):
		boss_node.setup(bd)
	if "current_hp" in boss_node:
		boss_node.current_hp = 500
		if boss_node.has_method("_check_phase_transition"):
			boss_node._check_phase_transition()
		boss_node.current_hp = 200
		if boss_node.has_method("_check_phase_transition"):
			boss_node._check_phase_transition()
	elif boss_node.has_method("apply_damage"):
		boss_node.apply_damage(500)
		boss_node.apply_damage(300)
	print("AC5:phase_changed_count=", phase_changed_count)
	print("AC5:has_phase_thresholds=", "phase_thresholds" in boss_node)
	if "phase_thresholds" in boss_node:
		print("AC5:phase_thresholds=", boss_node.phase_thresholds)
	print("AC5:current_hp_after=", boss_node.current_hp if "current_hp" in boss_node else "N/A")

	var mm: Node = load("res://scenes/main_menu/main_menu.tscn").instantiate()
	root.add_child(mm)
	var buttons: Node = mm.get_node_or_null("Buttons")
	var cnt: int = buttons.get_child_count() if buttons != null else 0
	print("AC9:buttons_count=", cnt)
	if buttons != null:
		for c in buttons.get_children():
			print("AC9:btn=", c.name)

	MS.dokkaebi_orbs = prev_orbs
	MS.divine_tree_level = prev_dtl
	print("=== AC_TEST_END ===")

func _on_run_started(_a: StringName, _b: StringName) -> void:
	run_started_called = true

func _on_phase_changed(_idx: int) -> void:
	phase_changed_count += 1
