extends SceneTree

# Scene-flow smoke test — Godot 4 headless mode (-s script).
# 실행: godot --headless --path /Users/0xb10ck/kkaebi-run --script tests/test_scene_flow.gd
#
# 시뮬레이션 흐름:
#   1) main_menu.tscn 로딩 (change_scene_to_file)
#   2) 캐릭터 선택 화면 진입 (character_select.tscn)
#   3) 챕터 선택 화면 진입 (chapter_select.tscn)
#   4) 게임 진입 (ChapterManager.begin_run → game_scene.tscn)
#
# 각 단계 직후 current_scene(== get_tree().current_scene from node script) 가
# null 이 아니고 기대한 루트 노드 이름인지 검증한다.
#
# push_error / SCRIPT ERROR 감지:
#   - 본 스크립트는 push_error 를 호출하지 않는다(push_error 자체로 ERROR 카운트가 올라가
#     의도치 않은 fail 을 만든다).
#   - user://logs/godot.log 가 존재하면 시작 시점의 끝 오프셋을 기억해 두고,
#     테스트 종료 후 그 이후로 추가된 내용에서 "SCRIPT ERROR" / "PARSE ERROR" 라인을
#     검출하면 fail. (project.godot 에 file logging 이 꺼져 있어 파일이 없으면
#     베스트-에포트로 스킵한다.)
#
# user://save.json 은 시작/종료 시 백업/복원.


const MAIN_MENU_PATH: String = "res://scenes/main_menu/main_menu.tscn"
const CHARACTER_SELECT_PATH: String = "res://scenes/ui/character_select.tscn"
const CHAPTER_SELECT_PATH: String = "res://scenes/ui/chapter_select.tscn"
const GAME_SCENE_PATH: String = "res://scenes/gameplay/game_scene.tscn"

const SAVE_PATH: String = "user://save.json"
const LOG_PATH: String = "user://logs/godot.log"

const CHAR_ID: StringName = &"ttukttaki"
const CHAPTER_ID: StringName = &"ch01_dumeong"

# change_scene_to_file 은 deferred 라 최소 두 프레임은 양보해야 새 current_scene 이 잡힌다.
# game_scene 은 _ready 에서 많은 노드를 추가하므로 여유 있게 5 프레임.
const FRAMES_AFTER_CHANGE: int = 5
const FRAMES_AFTER_GAME_SCENE: int = 8

var errors: Array[String] = []
var log_start_size: int = -1


func _initialize() -> void:
	# 자동로드(_ready) 가 마칠 시간을 한 프레임 양보한 뒤 메인 시퀀스 실행.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var save_backup: Dictionary = _backup_save()
	log_start_size = _current_log_size()

	# 챕터1(두멍마을) 은 폴백상 shinmok_stage 1 부터 해금되어 있지만
	# 안전을 위해 MetaState 가 있으면 stage 1 이상을 보장.
	_ensure_chapter1_unlocked()

	var ok1: bool = await _step_load_main_menu()
	var ok2: bool = await _step_open_character_select()
	var ok3: bool = await _step_open_chapter_select()
	var ok4: bool = await _step_enter_game_scene()

	_check_log_for_errors()

	_restore_save(save_backup)

	var all_ok: bool = ok1 and ok2 and ok3 and ok4 and errors.is_empty()
	_print_summary(all_ok)
	quit(0 if all_ok else 1)


# ─────────────────────────────────────────────────────────────────────────────
# Steps
# ─────────────────────────────────────────────────────────────────────────────

func _step_load_main_menu() -> bool:
	print("[SCENE-FLOW] step 1: load main_menu.tscn")
	if not ResourceLoader.exists(MAIN_MENU_PATH):
		_err("main_menu scene missing at %s" % MAIN_MENU_PATH)
		return false
	var rc: int = change_scene_to_file(MAIN_MENU_PATH)
	if rc != OK:
		_err("change_scene_to_file(main_menu) returned %d" % rc)
		return false
	await _wait_frames(FRAMES_AFTER_CHANGE)
	if current_scene == null:
		_err("after main_menu load: current_scene is null")
		return false
	if current_scene.name != "MainMenu":
		_err("after main_menu load: current_scene.name=%s expected MainMenu" % current_scene.name)
		return false
	return true


func _step_open_character_select() -> bool:
	print("[SCENE-FLOW] step 2: character_select.tscn")
	if not ResourceLoader.exists(CHARACTER_SELECT_PATH):
		_err("character_select scene missing at %s" % CHARACTER_SELECT_PATH)
		return false
	# 사용자가 메인 메뉴에서 "캐릭터" 버튼을 눌렀을 때 호출되는 경로와 동일하게 전환.
	var rc: int = change_scene_to_file(CHARACTER_SELECT_PATH)
	if rc != OK:
		_err("change_scene_to_file(character_select) returned %d" % rc)
		return false
	await _wait_frames(FRAMES_AFTER_CHANGE)
	if current_scene == null:
		_err("after character_select load: current_scene is null")
		return false
	if current_scene.name != "CharacterSelect":
		_err("after character_select load: current_scene.name=%s expected CharacterSelect" % current_scene.name)
		return false
	# 캐릭터 카드 탭 시뮬레이션 — GameState.selected_character_id 설정.
	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		_err("character_select: GameState autoload missing")
		return false
	gs.set("selected_character_id", CHAR_ID)
	if gs.get("selected_character_id") != CHAR_ID:
		_err("character_select: failed to set GameState.selected_character_id")
		return false
	return true


func _step_open_chapter_select() -> bool:
	print("[SCENE-FLOW] step 3: chapter_select.tscn")
	if not ResourceLoader.exists(CHAPTER_SELECT_PATH):
		_err("chapter_select scene missing at %s" % CHAPTER_SELECT_PATH)
		return false
	var rc: int = change_scene_to_file(CHAPTER_SELECT_PATH)
	if rc != OK:
		_err("change_scene_to_file(chapter_select) returned %d" % rc)
		return false
	await _wait_frames(FRAMES_AFTER_CHANGE)
	if current_scene == null:
		_err("after chapter_select load: current_scene is null")
		return false
	if current_scene.name != "ChapterSelect":
		_err("after chapter_select load: current_scene.name=%s expected ChapterSelect" % current_scene.name)
		return false
	return true


func _step_enter_game_scene() -> bool:
	print("[SCENE-FLOW] step 4: begin_run → game_scene.tscn")
	if not ResourceLoader.exists(GAME_SCENE_PATH):
		_err("game_scene missing at %s" % GAME_SCENE_PATH)
		return false
	var cm: Node = root.get_node_or_null("ChapterManager")
	if cm == null:
		_err("game_scene: ChapterManager autoload missing")
		return false
	# 챕터 선택 화면에서 "출정하기" 누른 흐름을 그대로 시뮬레이션.
	cm.call("select_character", CHAR_ID)
	if cm.get("current_character_id") != CHAR_ID:
		_err("game_scene: select_character did not set current_character_id")
		return false
	if not bool(cm.call("is_chapter_unlocked", CHAPTER_ID)):
		_err("game_scene: chapter %s reported locked (shinmok=%d)" % [
			String(CHAPTER_ID),
			_shinmok_stage(),
		])
		return false
	cm.call("select_chapter", CHAPTER_ID)
	cm.call("begin_run")
	await _wait_frames(FRAMES_AFTER_GAME_SCENE)
	if current_scene == null:
		_err("after begin_run: current_scene is null")
		return false
	if current_scene.name != "GameScene":
		_err("after begin_run: current_scene.name=%s expected GameScene" % current_scene.name)
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _wait_frames(n: int) -> void:
	for i in n:
		await process_frame


func _err(msg: String) -> void:
	errors.append(msg)
	print("[SCENE-FLOW] FAIL — ", msg)


func _ensure_chapter1_unlocked() -> void:
	# ch01 은 폴백(레지스트리 미등록 또는 unlock_shinmok_required<=1)이라 기본 해금이지만
	# MetaState.shinmok_stage 가 0 인 비정상 상태를 안전망으로 보강한다.
	var ms: Node = root.get_node_or_null("MetaState")
	if ms == null:
		return
	if int(ms.get("shinmok_stage")) < 1:
		ms.set("shinmok_stage", 1)


func _shinmok_stage() -> int:
	var ms: Node = root.get_node_or_null("MetaState")
	if ms == null:
		return -1
	return int(ms.get("shinmok_stage"))


func _current_log_size() -> int:
	if not FileAccess.file_exists(LOG_PATH):
		return -1
	var f: FileAccess = FileAccess.open(LOG_PATH, FileAccess.READ)
	if f == null:
		return -1
	var size: int = int(f.get_length())
	f.close()
	return size


func _check_log_for_errors() -> void:
	# file logging 이 꺼져 있어 로그 파일이 없으면 검사 스킵(베스트-에포트).
	if log_start_size < 0:
		print("[SCENE-FLOW] log file %s not present — skipping log-scan" % LOG_PATH)
		return
	if not FileAccess.file_exists(LOG_PATH):
		print("[SCENE-FLOW] log file disappeared — skipping log-scan")
		return
	var f: FileAccess = FileAccess.open(LOG_PATH, FileAccess.READ)
	if f == null:
		print("[SCENE-FLOW] cannot reopen log file — skipping log-scan")
		return
	var total: int = int(f.get_length())
	if total <= log_start_size:
		f.close()
		return
	f.seek(log_start_size)
	var appended: String = f.get_buffer(total - log_start_size).get_string_from_utf8()
	f.close()
	# SCRIPT ERROR / PARSE ERROR 만 fail 로 간주. 일반 ERROR: 는 외부 리소스 누락 등
	# 본 테스트와 무관할 수 있어 별도 라인으로 표시만 한다.
	for raw_line in appended.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty():
			continue
		if line.begins_with("SCRIPT ERROR") or line.begins_with("PARSE ERROR") or line.begins_with("USER SCRIPT ERROR"):
			_err("log captured: %s" % line)


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
	if backup.get("existed", false):
		var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_buffer(backup["bytes"])
			f.close()
	else:
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _print_summary(all_ok: bool) -> void:
	print("───────────────────────────────────────────────────────────")
	print("[SCENE-FLOW] result: ", "PASS" if all_ok else "FAIL")
	if not errors.is_empty():
		print("[SCENE-FLOW] errors:")
		for e in errors:
			print("  - ", e)
	print("───────────────────────────────────────────────────────────")
