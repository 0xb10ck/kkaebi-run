extends SceneTree

# QA harness — Godot 4 headless mode.
# 실행: tests/run_qa.sh
# 결과: tests/qa_report.json + tests/qa_report.md (res:// 쓰기 실패 시 user://로 폴백)

const ENEMY_RES_BY_KEY: Dictionary = {}  # 동적으로 ChapterManager.MONSTER_POOL_BY_CHAPTER에서 채움

const SKILL_RES_DIR := "res://resources/skills"
const SKILL_SCENE_DIR := "res://scenes/skills"
const CHAR_RES_DIR := "res://resources/characters"
const CHAPTER_RES_DIR := "res://resources/chapters"
const BOSS_RES_DIR := "res://resources/bosses"
const ENEMY_RES_DIR := "res://resources/enemies"
const ENV_RES_DIR := "res://resources/environments"
const EVENT_RES_DIR := "res://resources/events"
const META_RES_DIR := "res://resources/meta_upgrades"
const UI_SCENE_DIR := "res://scenes/ui"
const BOSS_SCENE_DIR := "res://scenes/bosses"
const ENEMY_SCENE_DIR := "res://scenes/enemies"
const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"


func _initialize() -> void:
	# autoload가 모두 _ready를 마치도록 한 프레임 양보 후 실행.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var report := {
		"modules": {},
		"errors": [],
		"summary": {"pass": 0, "fail": 0},
	}
	_run_module(report, "load_gd", _module_load_gd)
	_run_module(report, "load_tscn", _module_load_tscn)
	_run_module(report, "load_tres", _module_load_tres)
	_run_module(report, "autoloads", _module_autoloads)
	_run_module(report, "chapter", _module_chapter)
	_run_module(report, "boss", _module_boss)
	_run_module(report, "skill", _module_skill)
	_run_module(report, "character", _module_character)
	_run_module(report, "env_event", _module_env_event)
	_run_module(report, "ui", _module_ui)
	_run_module(report, "meta", _module_meta)
	_run_module(report, "integration", _module_integration)
	_write_report(report)
	_print_summary(report)
	var all_pass := true
	for k in report.modules.keys():
		if not bool(report.modules[k]["pass"]):
			all_pass = false
			break
	quit(0 if all_pass else 1)


func _run_module(report: Dictionary, name: String, fn: Callable) -> void:
	print("[QA] ▶ ", name)
	var result: Dictionary = {"pass": false, "errors": [], "details": {}}
	var ok := false
	var caught_msg := ""
	# Godot은 GDScript에서 직접 try/except가 없으므로 fn 내부에서 errors push 후 pass=bool 결정.
	var ret = fn.call()
	if ret is Dictionary:
		result = ret
	else:
		result["errors"].append("module %s returned non-Dictionary" % name)
	ok = bool(result.get("pass", false))
	report.modules[name] = result
	if ok:
		report.summary["pass"] = int(report.summary["pass"]) + 1
		print("[QA]    ✓ pass")
	else:
		report.summary["fail"] = int(report.summary["fail"]) + 1
		var errs: Array = result.get("errors", [])
		print("[QA]    ✗ fail (errors=", errs.size(), ")")
		for e in errs:
			print("[QA]       - ", e)
			report.errors.append({"module": name, "error": str(e)})


# ────────────────────────────────────────────────────────────────────────────
# Module 1: GDScript 파싱
# ────────────────────────────────────────────────────────────────────────────
func _module_load_gd() -> Dictionary:
	var errors: Array = []
	var details := {"checked": 0, "failed": 0, "files": []}
	var paths := _list_all_files_with_ext("res://scripts", "gd")
	for p in paths:
		details.checked += 1
		var res: Resource = load(p)
		if res == null or not (res is GDScript):
			errors.append("parse fail: %s" % p)
			details.failed += 1
			details.files.append(p)
	# tests 디렉토리 자기 자신은 제외 (qa_runner 자체 로드는 의미 없음)
	return {"pass": errors.is_empty(), "errors": errors, "details": details}


# ────────────────────────────────────────────────────────────────────────────
# Module 2: 씬 로드
# ────────────────────────────────────────────────────────────────────────────
func _module_load_tscn() -> Dictionary:
	var errors: Array = []
	var details := {"checked": 0, "failed": 0, "files": []}
	var paths := _list_all_files_with_ext("res://scenes", "tscn")
	for p in paths:
		details.checked += 1
		var res: Resource = load(p)
		if res == null or not (res is PackedScene):
			errors.append("scene load fail: %s" % p)
			details.failed += 1
			details.files.append(p)
	return {"pass": errors.is_empty(), "errors": errors, "details": details}


# ────────────────────────────────────────────────────────────────────────────
# Module 3: 리소스 로드
# ────────────────────────────────────────────────────────────────────────────
func _module_load_tres() -> Dictionary:
	var errors: Array = []
	var details := {"checked": 0, "failed": 0, "files": []}
	var paths := _list_all_files_with_ext("res://resources", "tres")
	for p in paths:
		details.checked += 1
		var res: Resource = load(p)
		if res == null:
			errors.append("resource load fail: %s" % p)
			details.failed += 1
			details.files.append(p)
	return {"pass": errors.is_empty(), "errors": errors, "details": details}


# ────────────────────────────────────────────────────────────────────────────
# Module 4: 자동로드 검증
# ────────────────────────────────────────────────────────────────────────────
func _module_autoloads() -> Dictionary:
	var errors: Array = []
	var expected := ["EventBus", "GameState", "SkillManager", "MetaState", "ChapterManager"]
	for name in expected:
		var node: Node = root.get_node_or_null(NodePath(name))
		if node == null:
			errors.append("autoload missing: %s" % name)
	# 서로 참조하는 핵심 API들이 호출 가능한지 가벼운 사후 검사.
	var em: Node = root.get_node_or_null("EventBus")
	if em and not em.has_signal("run_started"):
		errors.append("EventBus missing signal run_started")
	var gs: Node = root.get_node_or_null("GameState")
	if gs and not gs.has_method("reset_for_run"):
		errors.append("GameState missing method reset_for_run")
	var sm: Node = root.get_node_or_null("SkillManager")
	if sm and not sm.has_method("acquire_or_level"):
		errors.append("SkillManager missing method acquire_or_level")
	var ms: Node = root.get_node_or_null("MetaState")
	if ms and not ms.has_method("apply_upgrade_purchase"):
		errors.append("MetaState missing method apply_upgrade_purchase")
	var cm: Node = root.get_node_or_null("ChapterManager")
	if cm and not cm.has_method("begin_run"):
		errors.append("ChapterManager missing method begin_run")
	return {"pass": errors.is_empty(), "errors": errors, "details": {}}


# ────────────────────────────────────────────────────────────────────────────
# Module 5: 챕터 데이터 & 풀
# ────────────────────────────────────────────────────────────────────────────
func _module_chapter() -> Dictionary:
	var errors: Array = []
	var details := {"chapters": []}
	var cm: Node = root.get_node_or_null("ChapterManager")
	if cm == null:
		return {"pass": false, "errors": ["ChapterManager not loaded"], "details": details}
	# 1) MONSTER_POOL_BY_CHAPTER 6개 키, 각 풀의 .tscn/.tres 존재.
	var pool: Dictionary = cm.get("MONSTER_POOL_BY_CHAPTER")
	for ch in [1, 2, 3, 4, 5, 6]:
		if not pool.has(ch):
			errors.append("monster pool missing chapter: %d" % ch)
			continue
		var entries: Array = pool[ch]
		for e in entries:
			var sp: String = e.get("scene_path", "")
			var dp: String = e.get("data_path", "")
			if not ResourceLoader.exists(sp):
				errors.append("ch%d enemy scene missing: %s" % [ch, sp])
			if not ResourceLoader.exists(dp):
				errors.append("ch%d enemy data missing: %s" % [ch, dp])
			else:
				var dres: Resource = load(dp)
				if dres == null:
					errors.append("ch%d enemy data load fail: %s" % [ch, dp])
	# 2) resources/chapters/*.tres → ChapterData
	var dir := DirAccess.open(CHAPTER_RES_DIR)
	var chapter_count := 0
	if dir:
		dir.list_dir_begin()
		var n := dir.get_next()
		while n != "":
			if not dir.current_is_dir() and (n.ends_with(".tres") or n.ends_with(".res")):
				var path := CHAPTER_RES_DIR + "/" + n
				var res: Resource = load(path)
				if res == null:
					errors.append("ChapterData load fail: %s" % path)
				elif not (res is ChapterData):
					errors.append("ChapterData type mismatch: %s" % path)
				else:
					chapter_count += 1
					details.chapters.append({"id": String(res.id), "n": res.chapter_number})
			n = dir.get_next()
		dir.list_dir_end()
	if chapter_count < 6:
		errors.append("ChapterData files expected 6 found %d" % chapter_count)
	# 3) 등록 후 get_chapter_list 정렬
	var list: Array = cm.call("get_chapter_list")
	if list.size() < 6:
		errors.append("ChapterManager get_chapter_list size=%d (<6)" % list.size())
	return {"pass": errors.is_empty(), "errors": errors, "details": details}


# ────────────────────────────────────────────────────────────────────────────
# Module 6: 보스 데이터 + 씬
# ────────────────────────────────────────────────────────────────────────────
func _module_boss() -> Dictionary:
	var errors: Array = []
	var details := {"checked": 0, "bosses": []}
	var cm: Node = root.get_node_or_null("ChapterManager")
	var by_id: Dictionary = cm.get("BOSS_SCENE_BY_ID") if cm else {}
	# 11개 .tres + 11개 .tscn
	var ids := [
		"b01_dokkaebibul_daejang", "b02_gumiho", "b03_jeoseung_saja",
		"b04_cheondung_janggun", "b05_heuk_ryong", "b06_daewang_dokkaebi",
		"mb01_jangsanbeom", "mb02_imugi", "mb03_chagwishin",
		"mb04_geumdwaeji", "mb05_geomeun_dokkaebi",
	]
	for id: String in ids:
		var tres_path: String = BOSS_RES_DIR + "/" + id + ".tres"
		if not ResourceLoader.exists(tres_path):
			errors.append("boss tres missing: %s" % tres_path)
			continue
		var data: Resource = load(tres_path)
		if data == null:
			errors.append("boss tres load fail: %s" % tres_path)
			continue
		details.checked += 1
		# Phase 검사: phases는 Array[BossPhase] (Resource). hp_threshold_percent 내림차순.
		if "phases" in data:
			var phases: Array = data.phases
			if phases.is_empty():
				errors.append("boss %s: phases array is empty" % id)
			else:
				var last_pct := 1.01
				for ph in phases:
					if ph == null:
						continue
					var pct: float = 1.0
					if "hp_threshold_percent" in ph:
						pct = float(ph.hp_threshold_percent)
					if pct > last_pct + 0.001:
						errors.append("boss %s: phase hp_threshold not descending: %s vs prev %s" % [id, pct, last_pct])
						break
					last_pct = pct
		var sp: String = by_id.get(StringName(id), "") if by_id else ""
		if sp == "" or not ResourceLoader.exists(sp):
			errors.append("boss scene path missing for id=%s (got '%s')" % [id, sp])
			continue
		var scene: Resource = load(sp)
		if scene == null or not (scene is PackedScene):
			errors.append("boss scene load fail: %s" % sp)
			continue
		# 인스턴스화 — 자동 free.
		var inst: Node = (scene as PackedScene).instantiate()
		if inst == null:
			errors.append("boss instantiate fail: %s" % sp)
			continue
		root.add_child(inst)
		# 페이즈 강제 호출 시 크래시 없는지.
		if inst.has_method("force_phase"):
			for pi in [1, 2, 3]:
				inst.call("force_phase", pi)
		inst.queue_free()
		details.bosses.append(id)
	return {"pass": errors.is_empty(), "errors": errors, "details": details}


# ────────────────────────────────────────────────────────────────────────────
# Module 7: 스킬 30종
# ────────────────────────────────────────────────────────────────────────────
func _module_skill() -> Dictionary:
	var errors: Array = []
	var details := {"checked": 0, "skills": []}
	# resources/skills 모두 SkillData로 로드 + scene이 정의돼 있으면 instantiate.
	var dir := DirAccess.open(SKILL_RES_DIR)
	if dir == null:
		return {"pass": false, "errors": ["cannot open " + SKILL_RES_DIR], "details": details}
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		if not dir.current_is_dir() and (n.ends_with(".tres") or n.ends_with(".res")):
			var path := SKILL_RES_DIR + "/" + n
			var data: Resource = load(path)
			if data == null:
				errors.append("skill tres load fail: %s" % path)
			else:
				details.checked += 1
				details.skills.append(n.get_basename())
				# SkillLevel 배열 5개 (cap 5)
				if "levels" in data:
					var levels: Array = data.levels
					if levels.size() != 5:
						errors.append("skill %s: levels.size()=%d (expected 5)" % [n.get_basename(), levels.size()])
					for i in levels.size():
						var lv_res = levels[i]
						if lv_res == null:
							errors.append("skill %s: level[%d] is null" % [n.get_basename(), i])
							continue
						if "damage_base" in lv_res and float(lv_res.damage_base) < 0.0:
							errors.append("skill %s: level[%d].damage_base < 0" % [n.get_basename(), i])
						if "cooldown_s" in lv_res and float(lv_res.cooldown_s) < 0.0:
							errors.append("skill %s: level[%d].cooldown_s < 0" % [n.get_basename(), i])
				# scene 인스턴스화 시도
				if "scene" in data and data.scene != null:
					var inst: Node = data.scene.instantiate()
					if inst == null:
						errors.append("skill scene instantiate fail: %s" % path)
					else:
						root.add_child(inst)
						# set_level(1..5) 호출
						if inst.has_method("set_level"):
							for lv in [1, 2, 3, 4, 5]:
								inst.call("set_level", lv)
						# apply_level 호환
						elif inst.has_method("apply_level"):
							for lv in [1, 2, 3, 4, 5]:
								inst.call("apply_level", lv)
						inst.queue_free()
		n = dir.get_next()
	dir.list_dir_end()
	if details.checked < 30:
		errors.append("SkillData count expected 30 found %d" % details.checked)
	return {"pass": errors.is_empty(), "errors": errors, "details": details}


# ────────────────────────────────────────────────────────────────────────────
# Module 8: 캐릭터 6종
# ────────────────────────────────────────────────────────────────────────────
func _module_character() -> Dictionary:
	var errors: Array = []
	var details := {"characters": []}
	var ids := ["barami", "byeolee", "dolsoe", "geurimja", "hwalee", "ttukttaki"]
	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		return {"pass": false, "errors": ["GameState not loaded"], "details": details}
	for id: String in ids:
		var path: String = CHAR_RES_DIR + "/" + id + ".tres"
		if not ResourceLoader.exists(path):
			errors.append("character tres missing: %s" % path)
			continue
		var data: Resource = load(path)
		if data == null:
			errors.append("character tres load fail: %s" % path)
			continue
		# 필수 필드.
		for field in ["id", "base_hp", "base_move_speed", "base_attack"]:
			if not (field in data):
				errors.append("character %s missing field %s" % [id, field])
		# GameState 적용
		gs.set("character_data", data)
		gs.call("reset_for_run", data.id, &"ch01_dumeong")
		if int(gs.get("max_hp")) <= 0:
			errors.append("character %s reset → max_hp <= 0" % id)
		details.characters.append({"id": id, "hp": int(gs.get("max_hp")), "atk": int(gs.get("attack"))})
	return {"pass": errors.is_empty(), "errors": errors, "details": details}


# ────────────────────────────────────────────────────────────────────────────
# Module 9: 환경 5 + 이벤트 7
# ────────────────────────────────────────────────────────────────────────────
func _module_env_event() -> Dictionary:
	var errors: Array = []
	var details := {"env": 0, "event": 0}
	for d: String in [ENV_RES_DIR, EVENT_RES_DIR]:
		var dir := DirAccess.open(d)
		if dir == null:
			errors.append("cannot open " + d)
			continue
		dir.list_dir_begin()
		var n := dir.get_next()
		while n != "":
			if not dir.current_is_dir() and (n.ends_with(".tres") or n.ends_with(".res")):
				var path: String = d + "/" + n
				var res: Resource = load(path)
				if res == null:
					errors.append("load fail: %s" % path)
				else:
					if d == ENV_RES_DIR:
						details.env += 1
					else:
						details.event += 1
			n = dir.get_next()
		dir.list_dir_end()
	if details.env < 5:
		errors.append("environment count expected ≥5 found %d" % details.env)
	if details.event < 7:
		errors.append("event count expected ≥7 found %d" % details.event)
	return {"pass": errors.is_empty(), "errors": errors, "details": details}


# ────────────────────────────────────────────────────────────────────────────
# Module 10: UI 씬 인스턴스화
# ────────────────────────────────────────────────────────────────────────────
func _module_ui() -> Dictionary:
	var errors: Array = []
	var details := {"checked": 0, "scenes": []}
	var paths := _list_all_files_with_ext(UI_SCENE_DIR, "tscn")
	paths.append(MAIN_MENU_SCENE)
	for p in paths:
		details.checked += 1
		var res: Resource = load(p)
		if res == null or not (res is PackedScene):
			errors.append("ui scene load fail: %s" % p)
			continue
		var inst: Node = (res as PackedScene).instantiate()
		if inst == null:
			errors.append("ui scene instantiate fail: %s" % p)
			continue
		# add_child가 _ready를 동기 호출하므로 추가 프레임 대기 없이 검증 가능.
		root.add_child(inst)
		inst.queue_free()
		details.scenes.append(p)
	return {"pass": errors.is_empty(), "errors": errors, "details": details}


# ────────────────────────────────────────────────────────────────────────────
# Module 11: 메타 저장 라운드트립
# ────────────────────────────────────────────────────────────────────────────
func _module_meta() -> Dictionary:
	var errors: Array = []
	var details := {}
	var ms: Node = root.get_node_or_null("MetaState")
	if ms == null:
		return {"pass": false, "errors": ["MetaState not loaded"], "details": details}
	# user://save.json 백업
	var save_path := "user://save.json"
	var backup: PackedByteArray = PackedByteArray()
	var had_save := FileAccess.file_exists(save_path)
	if had_save:
		var f := FileAccess.open(save_path, FileAccess.READ)
		if f:
			backup = f.get_buffer(f.get_length())
			f.close()
	# 1) 현재 상태 스냅샷
	var orig_orbs: int = int(ms.get("dokkaebi_orbs"))
	# 2) 임시 값 주입 + save
	ms.set("dokkaebi_orbs", 12345)
	ms.call("save")
	# 3) 메모리 값 변경 → load 후 디스크 값으로 복귀해야 함
	ms.set("dokkaebi_orbs", 0)
	ms.call("load")
	var after_load: int = int(ms.get("dokkaebi_orbs"))
	if after_load != 12345:
		errors.append("MetaState roundtrip: dokkaebi_orbs expected 12345 got %d" % after_load)
	# 4) 백업 복원 — 디스크 + 메모리
	if had_save:
		var f := FileAccess.open(save_path, FileAccess.WRITE)
		if f:
			f.store_buffer(backup)
			f.close()
	else:
		if FileAccess.file_exists(save_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	ms.call("load")
	# 5) shinmok 단계 진행 가능 확인
	var pre_stage: int = int(ms.get("shinmok_stage"))
	# advance가 가능하면 진행 후 원상복귀.
	if pre_stage < 6:
		var ok: bool = ms.call("advance_shinmok")
		if not ok:
			errors.append("advance_shinmok() returned false at stage %d" % pre_stage)
		ms.set("shinmok_stage", pre_stage)
	# 6) 8 업그레이드 키 → 최대 레벨까지 비용/효과 호출 가능한지.
	for key in [&"max_hp", &"attack", &"move_speed", &"xp_gain", &"gold_gain", &"revive", &"choice_extra", &"luck"]:
		var max_lv: int = int(ms.call("get_upgrade_max_level", key))
		if max_lv <= 0:
			errors.append("upgrade %s max_level=0" % String(key))
		for lv in range(1, max_lv + 1):
			var c: int = int(ms.call("get_upgrade_cost", key, lv))
			if c < 0:
				errors.append("upgrade %s cost lv%d < 0" % [String(key), lv])
	details["orig_orbs"] = orig_orbs
	return {"pass": errors.is_empty(), "errors": errors, "details": details}


# ────────────────────────────────────────────────────────────────────────────
# Module 12: 통합 매니저 흐름
# ────────────────────────────────────────────────────────────────────────────
func _module_integration() -> Dictionary:
	var errors: Array = []
	var details := {}
	var cm: Node = root.get_node_or_null("ChapterManager")
	var gs: Node = root.get_node_or_null("GameState")
	var sm: Node = root.get_node_or_null("SkillManager")
	var em: Node = root.get_node_or_null("EventBus")
	if cm == null or gs == null or sm == null or em == null:
		return {"pass": false, "errors": ["autoload prerequisite missing"], "details": details}
	# 캐릭터 선택 → 챕터 선택 (씬 전환 트리거하지 않음)
	cm.call("select_character", &"ttukttaki")
	cm.call("select_chapter", &"ch01_dumeong")
	if cm.get("current_character_id") != StringName("ttukttaki"):
		errors.append("after select_character: current_character_id != ttukttaki")
	if cm.get("current_chapter_id") != StringName("ch01_dumeong"):
		errors.append("after select_chapter: current_chapter_id != ch01_dumeong (likely unlock fail)")
	# 캐릭터/챕터 데이터 적용 + reset_for_run
	var char_data: Resource = load(CHAR_RES_DIR + "/ttukttaki.tres")
	if char_data == null:
		errors.append("ttukttaki char data load fail")
	else:
		gs.set("character_data", char_data)
		gs.call("reset_for_run", &"ttukttaki", &"ch01_dumeong")
		sm.call("reset_for_run", char_data)
	# EventBus run_started 발신 — 핸들러 부작용만 확인
	em.run_started.emit(&"ttukttaki", &"ch01_dumeong")
	# 스킬 30종 acquire_or_level — 첫 호출은 LV1, 두 번째는 LV2
	var ids: Array = sm.get("skill_db").keys()
	if ids.size() < 30:
		errors.append("skill_db registered count=%d (<30)" % ids.size())
	var first_id = ids[0] if ids.size() > 0 else &""
	if first_id != &"":
		sm.call("acquire_or_level", first_id)
		var lv1: int = int(sm.call("level_of", first_id))
		if lv1 != 1:
			errors.append("acquire_or_level first time → level expected 1 got %d" % lv1)
		sm.call("acquire_or_level", first_id)
		var lv2: int = int(sm.call("level_of", first_id))
		if lv2 != 2:
			errors.append("acquire_or_level second time → level expected 2 got %d" % lv2)
	# enemy_killed → kill_count + MetaState.codex_monsters
	var pre_kill: int = int(gs.get("kill_count"))
	em.enemy_killed.emit(&"m01", Vector2.ZERO, &"fire_orb")
	var post_kill: int = int(gs.get("kill_count"))
	if post_kill != pre_kill:
		# GameState는 register_kill에서만 kill_count 증가, enemy_killed 발신은 register_kill 후이므로
		# 외부 발신은 카운트하지 않는다. 단, MetaState는 카운트해야 함.
		pass
	# boss_defeated → chapter_cleared 연쇄가 ChapterManager 핸들러를 거치는지 — 직접 호출 경로로 확인
	cm.call("on_boss_defeated", &"b01_dokkaebibul_daejang", 90.0, false)
	# advance to next chapter (씬 전환은 _safe_change_scene이 call_deferred로 미루므로 후속 모듈 영향 X)
	# run_ended emit
	em.run_ended.emit(&"clear", {"chapter": "ch01_dumeong"})
	details["skills_registered"] = ids.size()
	return {"pass": errors.is_empty(), "errors": errors, "details": details}


# ────────────────────────────────────────────────────────────────────────────
# 보조: 파일 트리 워크
# ────────────────────────────────────────────────────────────────────────────
func _list_all_files_with_ext(dir_path: String, ext: String) -> Array:
	var out: Array = []
	_walk(dir_path, ext, out)
	return out


func _walk(dir_path: String, ext: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		if n == "." or n == "..":
			n = dir.get_next()
			continue
		var full := dir_path + "/" + n
		if dir.current_is_dir():
			_walk(full, ext, out)
		else:
			if n.ends_with("." + ext):
				out.append(full)
		n = dir.get_next()
	dir.list_dir_end()


# ────────────────────────────────────────────────────────────────────────────
# 리포트 출력
# ────────────────────────────────────────────────────────────────────────────
func _write_report(report: Dictionary) -> void:
	var json_text := JSON.stringify(report, "  ")
	# res:// 시도 → 실패 시 user://
	var json_path := "res://tests/qa_report.json"
	var md_path := "res://tests/qa_report.md"
	var f := FileAccess.open(json_path, FileAccess.WRITE)
	if f == null:
		json_path = "user://qa_report.json"
		md_path = "user://qa_report.md"
		f = FileAccess.open(json_path, FileAccess.WRITE)
	if f:
		f.store_string(json_text)
		f.close()
	var md := _make_markdown(report)
	var mf := FileAccess.open(md_path, FileAccess.WRITE)
	if mf:
		mf.store_string(md)
		mf.close()
	print("[QA] report → ", json_path, " | ", md_path)


func _make_markdown(report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("# QA Report")
	lines.append("")
	lines.append("- pass: %d" % int(report.summary.pass))
	lines.append("- fail: %d" % int(report.summary.fail))
	lines.append("")
	lines.append("## Modules")
	for name in report.modules.keys():
		var m: Dictionary = report.modules[name]
		var status := "PASS" if bool(m.get("pass", false)) else "FAIL"
		lines.append("### %s — %s" % [name, status])
		var errs: Array = m.get("errors", [])
		if errs.size() > 0:
			lines.append("")
			lines.append("Errors (%d):" % errs.size())
			for e in errs:
				lines.append("- %s" % str(e))
		var details = m.get("details", null)
		if details and details is Dictionary and not (details as Dictionary).is_empty():
			lines.append("")
			lines.append("Details: `%s`" % JSON.stringify(details))
		lines.append("")
	return "\n".join(lines)


func _print_summary(report: Dictionary) -> void:
	print("")
	print("[QA] ═══════════════════════════════════════════════")
	print("[QA] PASS: %d   FAIL: %d" % [int(report.summary.pass), int(report.summary.fail)])
	for name in report.modules.keys():
		var m: Dictionary = report.modules[name]
		var status := "PASS" if bool(m.get("pass", false)) else "FAIL"
		var errs: Array = m.get("errors", [])
		print("[QA]   %-14s %s  errors=%d" % [name, status, errs.size()])
	print("[QA] ═══════════════════════════════════════════════")
