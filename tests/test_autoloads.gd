extends SceneTree

# tests/test_autoloads.gd — 5종 Autoload 부트 검증 (Godot 4 headless)
# 실행:
#   godot --headless --path /Users/0xb10ck/kkaebi-run --script tests/test_autoloads.gd
#
# 검증 항목
#   1) project.godot 의 5종 Autoload(EventBus / GameState / SkillManager /
#      MetaState / ChapterManager) 가 SceneTree.root 아래에 존재한다.
#   2) 각 매니저의 초기 상태가 기대값과 일치한다.
#      - GameState: 런 진입 전 휘발 필드(character_id/chapter_id 빈 값,
#        stage_index/level/current_xp/kill_count/gold 기본, no_hit_run=true).
#      - ChapterManager: _ready() 직후 state == MAIN_MENU,
#        current_chapter_id / current_character_id 빈 값, current_stage_index == 0.
#      - SkillManager: owned 비어 있음, legendary_acquired_this_run == 0.
#      - MetaState: shinmok_stage >= 1, upgrades 가 Dictionary,
#        unlocked_characters 에 기본 캐릭터(ttukttaki) 포함.
#      - EventBus: 핵심 시그널(run_started / player_died / save_requested /
#        save_completed) 가 정의되어 있다.
#   3) SaveStore (RefCounted 헬퍼) 의 load_data() 가 version 필드를 가진
#      Dictionary 를 반환한다. (저장 파일 미존재 시에도 기본값으로 성공.)
#
# 종료 코드: 모든 체크 통과 시 0, 하나라도 실패하면 1.
#
# push_error 는 SCRIPT ERROR 로 집계되어 헤드리스 종료 코드를 어지럽히므로
# 모든 메시지는 print() 만 사용한다.


const AUTOLOAD_NAMES: Array[String] = [
	"EventBus",
	"GameState",
	"SkillManager",
	"MetaState",
	"ChapterManager",
]

var errors: Array[String] = []
var passes: int = 0


func _initialize() -> void:
	# 자동로드 _ready() 가 모두 끝난 첫 프레임에 진입한다.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_check_autoloads_present()
	_check_event_bus()
	_check_game_state()
	_check_chapter_manager()
	_check_skill_manager()
	_check_meta_state()
	_check_save_store()
	_print_summary()
	quit(0 if errors.is_empty() else 1)


# ───────────────────────────────────────────────────────────────────────────
# 개별 체크
# ───────────────────────────────────────────────────────────────────────────

func _check_autoloads_present() -> void:
	for name in AUTOLOAD_NAMES:
		var node: Node = root.get_node_or_null(NodePath(name))
		if node == null:
			_fail("[autoload] %s: get_node returned null" % name)
		else:
			_pass("[autoload] %s present (path=%s)" % [name, node.get_path()])


func _check_event_bus() -> void:
	var bus: Node = root.get_node_or_null(NodePath("EventBus"))
	if bus == null:
		return
	for sig in ["run_started", "player_died", "save_requested", "save_completed"]:
		if bus.has_signal(sig):
			_pass("[EventBus] signal '%s' defined" % sig)
		else:
			_fail("[EventBus] signal '%s' missing" % sig)


func _check_game_state() -> void:
	var gs: Node = root.get_node_or_null(NodePath("GameState"))
	if gs == null:
		return
	_expect(gs.character_id == StringName(""),
			"[GameState] character_id is empty StringName (no run yet)")
	_expect(gs.chapter_id == StringName(""),
			"[GameState] chapter_id is empty StringName (no run yet)")
	_expect(int(gs.stage_index) == 0, "[GameState] stage_index == 0")
	_expect(int(gs.level) == 1, "[GameState] level == 1")
	_expect(int(gs.current_xp) == 0, "[GameState] current_xp == 0")
	_expect(int(gs.kill_count) == 0, "[GameState] kill_count == 0")
	_expect(int(gs.gold) == 0, "[GameState] gold == 0")
	_expect(bool(gs.no_hit_run) == true, "[GameState] no_hit_run == true")
	_expect(float(gs.elapsed_run) == 0.0, "[GameState] elapsed_run == 0.0")


func _check_chapter_manager() -> void:
	var cm: Node = root.get_node_or_null(NodePath("ChapterManager"))
	if cm == null:
		return
	# _ready() 가 state 를 MAIN_MENU 로 진입시킨다.
	var expected_state: int = int(cm.FlowState.MAIN_MENU)
	_expect(int(cm.state) == expected_state,
			"[ChapterManager] state == MAIN_MENU after boot (got %d)" % int(cm.state))
	_expect(cm.current_chapter_id == StringName(""),
			"[ChapterManager] current_chapter_id default empty")
	_expect(cm.current_character_id == StringName(""),
			"[ChapterManager] current_character_id default empty")
	_expect(int(cm.current_stage_index) == 0,
			"[ChapterManager] current_stage_index == 0")


func _check_skill_manager() -> void:
	var sm: Node = root.get_node_or_null(NodePath("SkillManager"))
	if sm == null:
		return
	var owned: Variant = sm.owned
	if not (owned is Dictionary):
		_fail("[SkillManager] owned is not a Dictionary (got %s)" % typeof(owned))
	else:
		_expect((owned as Dictionary).is_empty(),
				"[SkillManager] owned dictionary empty at boot")
	_expect(int(sm.legendary_acquired_this_run) == 0,
			"[SkillManager] legendary_acquired_this_run == 0")


func _check_meta_state() -> void:
	var ms: Node = root.get_node_or_null(NodePath("MetaState"))
	if ms == null:
		return
	# _load_from_disk() 가 저장 파일을 덮어쓸 수 있으므로 하한선만 검증한다.
	_expect(int(ms.shinmok_stage) >= 1,
			"[MetaState] shinmok_stage >= 1 (got %d)" % int(ms.shinmok_stage))
	_expect(ms.upgrades is Dictionary, "[MetaState] upgrades is Dictionary")
	_expect(ms.unlocked_characters is Array,
			"[MetaState] unlocked_characters is Array")
	if ms.unlocked_characters is Array:
		var unlocked: Array = ms.unlocked_characters
		_expect(unlocked.has(StringName("ttukttaki")),
				"[MetaState] default character 'ttukttaki' unlocked")


func _check_save_store() -> void:
	# SaveStore 는 class_name(RefCounted) — autoload 가 아닌 정적 헬퍼.
	# load_data() 는 저장 파일이 없으면 default_data() 를 반환한다(성공 경로).
	var raw: Variant = SaveStore.load_data()
	if typeof(raw) != TYPE_DICTIONARY:
		_fail("[SaveStore] load_data() did not return Dictionary (got %d)" % typeof(raw))
		return
	var data: Dictionary = raw
	if not data.has("version"):
		_fail("[SaveStore] load_data() result missing 'version' field")
		return
	var v: int = int(data.get("version", 0))
	if v < 1:
		_fail("[SaveStore] load_data() returned version < 1 (got %d)" % v)
		return
	_pass("[SaveStore] load_data() succeeded (version=%d, has_meta=%s)"
			% [v, str(data.has("meta"))])


# ───────────────────────────────────────────────────────────────────────────
# 유틸
# ───────────────────────────────────────────────────────────────────────────

func _expect(cond: bool, label: String) -> void:
	if cond:
		_pass(label)
	else:
		_fail(label)


func _pass(label: String) -> void:
	passes += 1
	print("PASS  %s" % label)


func _fail(label: String) -> void:
	errors.append(label)
	print("FAIL  %s" % label)


func _print_summary() -> void:
	print("")
	print("-- test_autoloads summary --")
	print("PASS: %d" % passes)
	print("FAIL: %d" % errors.size())
	if not errors.is_empty():
		print("Failed checks:")
		for e in errors:
			print("  - %s" % e)
