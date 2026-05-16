extends SceneTree

# Full-playthrough simulation — Godot 4 headless mode.
# 실행: godot --headless --path . --script tests/test_full_playthrough.gd
#
# 한 번 실행으로 다음을 자동 통과한다:
#   ch01 시작 → 일반 몬스터 처치(register_kill) → XP/레벨업 →
#   스킬 획득 → 미니보스/메인보스 클리어(EventBus.boss_defeated emit) →
#   다음 챕터 해금 → 최종 챕터(히든) 보스 클리어 →
#   결과 화면 진입(show_result) → 메타 보상 정산(영구 재화 증가 확인) →
#   메인 메뉴 복귀(scene load + instantiate).
#
# 통과 기준: 도중 SCRIPT ERROR / PARSE ERROR 0건 + 검증 항목 0 fail.
# push_error 는 자체로 SCRIPT ERROR 로 집계되므로 본 테스트는 print()만 사용한다.
# user://save.json 은 시작/종료 시 백업/복원하여 실제 저장본을 보존한다.


const CHAR_RES_DIR: String = "res://resources/characters"
const CHAPTER_RES_DIR: String = "res://resources/chapters"
const MAIN_MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"
const RESULT_SCENE: String = "res://scenes/ui/result_screen.tscn"
const SAVE_PATH: String = "user://save.json"

const CHAR_ID: StringName = &"ttukttaki"
const KILLS_PER_CHAPTER: int = 30
const XP_PER_KILL: int = 8

const CHAPTER_FLOW: Array[StringName] = [
	&"ch01_dumeong",
	&"ch02_sinryeong",
	&"ch03_hwangcheon",
	&"ch04_cheonsang",
	&"ch05_sinmok_heart",
	&"ch_hidden_market",
]

var errors: Array[String] = []
var boss_defeated_count: int = 0


func _initialize() -> void:
	# 자동로드(_ready)가 마치도록 한 프레임 양보.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var save_backup: Dictionary = _backup_save()
	var em: Node = root.get_node_or_null("EventBus")
	if em != null:
		em.boss_defeated.connect(_on_boss_defeated)

	var initial_orbs: int = -1
	var ms: Node = root.get_node_or_null("MetaState")
	if ms != null:
		initial_orbs = int(ms.get("dokkaebi_orbs"))

	# 단계별 실행 — 앞 단계가 실패하면 이후 단계도 그대로 호출하되 errors 에 모아 보고.
	var ok_setup: bool = _step_setup()
	var ok_chapters: bool = _step_per_chapter()
	var ok_combat: bool = _step_instant_kill_helper()
	var ok_result: bool = _step_result_settlement(initial_orbs)
	var ok_menu: bool = _step_return_to_main_menu()

	# 최종 종합 — 영구 재화가 시작 시점보다 늘어야 한다.
	if ms != null and initial_orbs >= 0:
		var final_orbs: int = int(ms.get("dokkaebi_orbs"))
		if final_orbs <= initial_orbs:
			_err("meta currency dokkaebi_orbs did not increase: initial=%d final=%d" % [initial_orbs, final_orbs])

	_restore_save(save_backup)

	if em != null and em.boss_defeated.is_connected(_on_boss_defeated):
		em.boss_defeated.disconnect(_on_boss_defeated)

	var all_ok: bool = ok_setup and ok_chapters and ok_combat and ok_result and ok_menu and errors.is_empty()
	_print_summary(all_ok)
	quit(0 if all_ok else 1)


func _err(msg: String) -> void:
	# push_error 는 SCRIPT ERROR 로 집계되므로 사용하지 않는다.
	errors.append(msg)
	print("[FULL-PLAY] FAIL — ", msg)


func _on_boss_defeated(_boss_id: StringName, _t: float, _no_hit: bool) -> void:
	boss_defeated_count += 1


# ────────────────────────────────────────────────────────────────────────────
# Step 1: 사전 준비 — 모든 챕터 해금 가능하도록 신목 단계를 끌어올린다.
# ────────────────────────────────────────────────────────────────────────────
func _step_setup() -> bool:
	var ms: Node = root.get_node_or_null("MetaState")
	var cm: Node = root.get_node_or_null("ChapterManager")
	var gs: Node = root.get_node_or_null("GameState")
	var sm: Node = root.get_node_or_null("SkillManager")
	var em: Node = root.get_node_or_null("EventBus")
	if ms == null or cm == null or gs == null or sm == null or em == null:
		_err("required autoloads missing (MetaState/ChapterManager/GameState/SkillManager/EventBus)")
		return false
	# 모든 챕터 해금에 필요한 최소 신목 단계는 5. shinmok_stage 가 1 부터 시작하므로 advance 호출.
	var safety: int = 0
	while int(ms.get("shinmok_stage")) < 5 and safety < 12:
		var ok: bool = bool(ms.call("advance_shinmok"))
		if not ok:
			_err("advance_shinmok() returned false at stage %d" % int(ms.get("shinmok_stage")))
			break
		safety += 1
	if int(ms.get("shinmok_stage")) < 5:
		_err("shinmok_stage failed to reach 5 (got %d)" % int(ms.get("shinmok_stage")))
		return false
	return true


# ────────────────────────────────────────────────────────────────────────────
# Step 2: 6 챕터 순회. 챕터마다 몬스터 처치 → XP/레벨업 → 스킬 획득 → 미니/메인 보스.
# ChapterManager 의 scene 전환 API(begin_run/advance_to_next_chapter 등)는 호출하지 않는다.
# 대신 EventBus 신호와 ChapterManager 의 직접 상태 setter 만 사용해 시뮬레이션한다.
# ────────────────────────────────────────────────────────────────────────────
func _step_per_chapter() -> bool:
	var cm: Node = root.get_node_or_null("ChapterManager")
	var gs: Node = root.get_node_or_null("GameState")
	var sm: Node = root.get_node_or_null("SkillManager")
	var em: Node = root.get_node_or_null("EventBus")
	var ms: Node = root.get_node_or_null("MetaState")

	var char_data: Resource = load(CHAR_RES_DIR + "/" + String(CHAR_ID) + ".tres")
	if char_data == null:
		_err("character data load fail: %s" % CHAR_ID)
		return false
	cm.call("select_character", CHAR_ID)
	if cm.get("current_character_id") != CHAR_ID:
		_err("select_character did not set current_character_id")
		return false

	var any_level_up: bool = false
	for chapter_id: StringName in CHAPTER_FLOW:
		if not cm.call("is_chapter_unlocked", chapter_id):
			_err("chapter %s expected unlocked at this point but is_chapter_unlocked=false (shinmok=%d)" % [String(chapter_id), int(ms.get("shinmok_stage"))])
			return false
		cm.call("select_chapter", chapter_id)
		if cm.get("current_chapter_id") != chapter_id:
			_err("select_chapter did not set current_chapter_id for %s" % String(chapter_id))
			return false
		var chapter_data: ChapterData = cm.get("current_chapter_data")
		if chapter_data == null:
			_err("current_chapter_data null for %s" % String(chapter_id))
			return false
		# 런 컨텍스트 초기화.
		gs.set("character_data", char_data)
		gs.call("reset_for_run", CHAR_ID, chapter_id)
		sm.call("reset_for_run", char_data)
		em.run_started.emit(CHAR_ID, chapter_id)

		# 챕터별 일반 몬스터 풀에서 enemy_id 를 뽑아 register_kill 로 처치 시뮬레이션.
		var pool: Array = cm.call("get_monster_pool_for_chapter", chapter_data.chapter_number)
		if pool.is_empty():
			_err("chapter %s monster pool empty" % String(chapter_id))
			return false
		var pre_kill: int = int(gs.get("kill_count"))
		var pre_level: int = int(gs.get("level"))
		for i in KILLS_PER_CHAPTER:
			var entry: Dictionary = pool[i % pool.size()]
			var key: StringName = StringName(String(entry.get("key", "m00")))
			gs.call("register_kill", key, Vector2.ZERO, &"fire_orb")
			em.xp_collected.emit(XP_PER_KILL)  # GameState._on_xp_collected → add_xp
		var post_kill: int = int(gs.get("kill_count"))
		if post_kill - pre_kill != KILLS_PER_CHAPTER:
			_err("chapter %s: kill_count delta expected %d got %d" % [String(chapter_id), KILLS_PER_CHAPTER, post_kill - pre_kill])
		var post_level: int = int(gs.get("level"))
		if post_level <= pre_level:
			_err("chapter %s: level did not advance after %d kills (pre=%d post=%d)" % [String(chapter_id), KILLS_PER_CHAPTER, pre_level, post_level])
		else:
			any_level_up = true

		# 스킬 획득/강화 — skill_db 에 등록된 스킬을 레벨업 횟수만큼 acquire_or_level.
		var sids: Array = sm.get("skill_db").keys()
		if sids.is_empty():
			_err("chapter %s: skill_db empty — cannot acquire" % String(chapter_id))
		else:
			var acquire_count: int = clamp(post_level - 1, 1, min(3, sids.size()))
			for j in acquire_count:
				var sid: StringName = sids[j % sids.size()]
				sm.call("acquire_or_level", sid)
			if sm.get("owned").size() == 0:
				_err("chapter %s: SkillManager.owned empty after acquire_or_level" % String(chapter_id))

		# 미니보스 처치 — id 가 비어 있는 챕터(히든)는 건너뛴다.
		var mini_id: StringName = chapter_data.mini_boss_id
		var pre_orbs: int = int(ms.get("dokkaebi_orbs"))
		if String(mini_id) != "":
			em.boss_defeated.emit(mini_id, 60.0, false)
		# 챕터 메인 보스 처치 — 항상 존재.
		var boss_id: StringName = chapter_data.chapter_boss_id
		if String(boss_id) == "":
			_err("chapter %s: chapter_boss_id empty" % String(chapter_id))
			continue
		em.boss_defeated.emit(boss_id, 90.0, false)
		var post_orbs: int = int(ms.get("dokkaebi_orbs"))
		if post_orbs <= pre_orbs:
			_err("chapter %s: dokkaebi_orbs did not increase from boss_defeated (pre=%d post=%d)" % [String(chapter_id), pre_orbs, post_orbs])
		# 챕터 클리어 마킹 — 다음 챕터의 unlock 조건(이전 챕터 cleared) 충족 용도.
		em.chapter_cleared.emit(chapter_id, true)
		var places: Dictionary = ms.get("codex_places")
		var entry: Dictionary = places.get(chapter_id, {})
		if not bool(entry.get("cleared", false)):
			_err("chapter %s: codex_places.cleared was not marked true" % String(chapter_id))

	if not any_level_up:
		_err("no chapter triggered a level up")
	return errors.is_empty()


# ────────────────────────────────────────────────────────────────────────────
# Step 3: 인스턴트 킬 헬퍼 — 실제 보스 씬을 인스턴스화하고 take_damage 로 강제 처치.
# 컷인 ID 는 CutsceneRegistry._PATHS 에 등록되지 않아 spawn() 이 null 을 반환,
# BossBase 는 add_child 시점에 동기로 _on_intro_finished() → fsm_state="idle", invuln=false 로 진입.
# 직후 invuln 해제와 current_hp=1 강제 + 큰 데미지로 _die() → EventBus.boss_defeated 발신을 검증.
# ────────────────────────────────────────────────────────────────────────────
func _step_instant_kill_helper() -> bool:
	var cm: Node = root.get_node_or_null("ChapterManager")
	if cm == null:
		_err("instant_kill: ChapterManager missing")
		return false
	var boss_id: StringName = &"b06_daewang_dokkaebi"
	var scene_path: String = String(cm.call("get_boss_scene_path", boss_id))
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		_err("instant_kill: boss scene path missing for %s" % String(boss_id))
		return false
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		_err("instant_kill: boss scene load fail: %s" % scene_path)
		return false
	var inst: Node = scene.instantiate()
	if inst == null:
		_err("instant_kill: boss instantiate fail: %s" % scene_path)
		return false
	root.add_child(inst)
	# add_child 직후에는 컷인이 없으면 _on_intro_finished 이 동기로 호출돼 idle 진입 상태.
	var pre_count: int = boss_defeated_count
	# 안전하게 무적 해제 + HP 1로 만들어 take_damage 로 즉사.
	if "invuln" in inst:
		inst.set("invuln", false)
	if "current_hp" in inst:
		inst.set("current_hp", 1)
	if inst.has_method("take_damage"):
		inst.call("take_damage", 999999, &"test_instant_kill")
	else:
		_err("instant_kill: boss instance has no take_damage()")
	# 자원 정리 — _tick_dying 자연 free 를 기다리지 않고 즉시 해제.
	inst.queue_free()
	if boss_defeated_count <= pre_count:
		_err("instant_kill: EventBus.boss_defeated not received after take_damage")
		return false
	return true


# ────────────────────────────────────────────────────────────────────────────
# Step 4: 결과 화면 → 메타 보상 정산. result_screen.tscn 인스턴스화 후 show_result 호출.
# show_result 내부에서 MetaState.compute_run_settlement 가 dokkaebi_orbs 를 증가시킨다.
# ────────────────────────────────────────────────────────────────────────────
func _step_result_settlement(_initial_orbs: int) -> bool:
	var ms: Node = root.get_node_or_null("MetaState")
	if ms == null:
		_err("result: MetaState missing")
		return false
	if not ResourceLoader.exists(RESULT_SCENE):
		_err("result: scene missing: %s" % RESULT_SCENE)
		return false
	var scene: PackedScene = load(RESULT_SCENE) as PackedScene
	if scene == null:
		_err("result: scene load fail: %s" % RESULT_SCENE)
		return false
	var inst: Node = scene.instantiate()
	if inst == null:
		_err("result: scene instantiate fail")
		return false
	root.add_child(inst)
	var pre_orbs: int = int(ms.get("dokkaebi_orbs"))
	if inst.has_method("show_result"):
		# survive_sec=STAGE_FULL_SEC(300) 이상이면 cleared 처리되어 first-clear 보너스 포함.
		inst.call("show_result", 300, 250, 18, 120)
	else:
		_err("result: show_result method missing")
	var post_orbs: int = int(ms.get("dokkaebi_orbs"))
	if post_orbs <= pre_orbs:
		_err("result: compute_run_settlement did not add orbs (pre=%d post=%d)" % [pre_orbs, post_orbs])
	# 결과 화면이 트리에 떠 있는 동안 paused=true 가 설정되므로 명시적으로 해제 후 정리.
	# SceneTree 컨텍스트에서는 self.paused 가 곧 트리의 paused 플래그다.
	paused = false
	inst.queue_free()
	return true


# ────────────────────────────────────────────────────────────────────────────
# Step 5: 메인 메뉴 복귀 — change_scene_to_file 은 deferred 라 SceneTree 컨텍스트에서
# 실제 전환은 무의미. 대신 main_menu.tscn 의 로드/인스턴스화가 에러 없이 끝나는지만 확인.
# ChapterManager 상태도 MAIN_MENU 로 되돌린다.
# ────────────────────────────────────────────────────────────────────────────
func _step_return_to_main_menu() -> bool:
	var cm: Node = root.get_node_or_null("ChapterManager")
	if cm == null:
		_err("main_menu: ChapterManager missing")
		return false
	if not ResourceLoader.exists(MAIN_MENU_SCENE):
		_err("main_menu: scene missing: %s" % MAIN_MENU_SCENE)
		return false
	var scene: PackedScene = load(MAIN_MENU_SCENE) as PackedScene
	if scene == null:
		_err("main_menu: scene load fail: %s" % MAIN_MENU_SCENE)
		return false
	var inst: Node = scene.instantiate()
	if inst == null:
		_err("main_menu: instantiate fail: %s" % MAIN_MENU_SCENE)
		return false
	root.add_child(inst)
	# 상태머신을 MAIN_MENU 로 — quit_to_main_menu 는 _safe_change_scene 을 호출하므로
	# 결과만 setter 로 흉내내 부작용을 피한다.
	if "state" in cm:
		cm.set("state", cm.FlowState.MAIN_MENU)
	inst.queue_free()
	return true


# ────────────────────────────────────────────────────────────────────────────
# Save 백업/복원 — user://save.json 는 MetaState 핸들러가 테스트 도중 자동 저장한다.
# ────────────────────────────────────────────────────────────────────────────
func _backup_save() -> Dictionary:
	var out: Dictionary = {"existed": false, "bytes": PackedByteArray()}
	if FileAccess.file_exists(SAVE_PATH):
		var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f != null:
			out["existed"] = true
			out["bytes"] = f.get_buffer(f.get_length())
			f.close()
	return out


func _restore_save(backup: Dictionary) -> void:
	var existed: bool = bool(backup.get("existed", false))
	var bytes: PackedByteArray = backup.get("bytes", PackedByteArray())
	if existed:
		var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_buffer(bytes)
			f.close()
	else:
		# 백업이 없었으면 테스트가 새로 만든 세이브를 지워 원상복귀.
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	# 메모리 상의 MetaState 도 디스크와 동기화.
	var ms: Node = root.get_node_or_null("MetaState")
	if ms != null and ms.has_method("load"):
		ms.call("load")


# ────────────────────────────────────────────────────────────────────────────
# 리포트
# ────────────────────────────────────────────────────────────────────────────
func _print_summary(all_ok: bool) -> void:
	print("")
	print("[FULL-PLAY] ═══════════════════════════════════════════════")
	print("[FULL-PLAY] chapters traversed: ", CHAPTER_FLOW.size())
	print("[FULL-PLAY] boss_defeated signals: ", boss_defeated_count)
	print("[FULL-PLAY] errors: ", errors.size())
	for e in errors:
		print("[FULL-PLAY]   - ", e)
	print("[FULL-PLAY] result: ", "PASS" if all_ok else "FAIL")
	print("[FULL-PLAY] ═══════════════════════════════════════════════")
