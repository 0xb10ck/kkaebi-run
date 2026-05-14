extends Node

# §2.5 — 챕터/스테이지 흐름 상태머신. MetaState는 직접 *읽기*만 허용.

enum FlowState {
	BOOT,
	MAIN_MENU,
	CHARACTER_SELECT,
	CHAPTER_SELECT,
	SHINMOK_SCREEN,
	LOADING,
	IN_STAGE,
	BOSS_BATTLE,
	INTERMISSION,
	RESULT,
	QUITTING,
}

const GAME_SCENE_PATH: String = "res://scenes/gameplay/game_scene.tscn"
const BOSS_ARENA_PATH: String = "res://scenes/bosses/boss_arena.tscn"
const INTERMISSION_PATH: String = "res://scenes/ui/intermission.tscn"
const MAIN_MENU_PATH: String = "res://scenes/main_menu/main_menu.tscn"
const CHAPTER_RES_DIR: String = "res://resources/chapters"

var state: FlowState = FlowState.BOOT
var current_character_id: StringName = &""
var current_chapter_id: StringName = &""
var current_stage_index: int = 0
var current_chapter_data: ChapterData
var current_boss_id: StringName = &""

# 챕터 데이터 레지스트리 (id -> ChapterData). resources/chapters/*.tres가 로드되면 채워진다.
var _chapter_registry: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	state = FlowState.MAIN_MENU
	_autoload_chapter_resources()
	EventBus.boss_defeated.connect(_on_boss_defeated_signal)
	EventBus.player_died.connect(_on_player_died_signal)
	EventBus.stage_cleared.connect(_on_stage_cleared_signal)


# resources/chapters/*.tres 자동 로드. 누락된 경우 폴백.
func _autoload_chapter_resources() -> void:
	var dir: DirAccess = DirAccess.open(CHAPTER_RES_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if not dir.current_is_dir() and (name.ends_with(".tres") or name.ends_with(".res")):
			var path: String = CHAPTER_RES_DIR + "/" + name
			var res: Resource = load(path)
			if res is ChapterData:
				register_chapter(res)
		name = dir.get_next()
	dir.list_dir_end()


# === public API ===

func goto_main_menu() -> void:
	state = FlowState.MAIN_MENU


func select_character(id: StringName) -> void:
	current_character_id = id
	state = FlowState.CHAPTER_SELECT


func select_chapter(id: StringName) -> void:
	if not is_chapter_unlocked(id):
		return
	current_chapter_id = id
	current_chapter_data = _chapter_registry.get(id, null)
	state = FlowState.LOADING


func begin_run() -> void:
	current_stage_index = 0
	state = FlowState.IN_STAGE
	# 챕터를 지정 없이 시작했다면 1장으로 폴백.
	if current_chapter_id == &"":
		current_chapter_id = &"ch01_dumeong"
		current_chapter_data = _chapter_registry.get(current_chapter_id, null)
	EventBus.run_started.emit(current_character_id, current_chapter_id)
	EventBus.stage_started.emit(current_chapter_id, current_stage_index)
	_safe_change_scene(GAME_SCENE_PATH)


func enter_stage(index: int) -> void:
	current_stage_index = index
	state = FlowState.IN_STAGE
	EventBus.stage_started.emit(current_chapter_id, index)


func on_stage_cleared() -> void:
	var last_stage: bool = false
	if current_chapter_data:
		last_stage = current_stage_index >= current_chapter_data.stage_count - 1
	EventBus.stage_cleared.emit(current_chapter_id, current_stage_index)
	if last_stage:
		advance_to_boss()
	else:
		enter_stage(current_stage_index + 1)


func enter_boss() -> void:
	state = FlowState.BOSS_BATTLE


# 씬 전환 포함: 보스 아레나로 진입.
func advance_to_boss() -> void:
	state = FlowState.BOSS_BATTLE
	current_boss_id = current_chapter_data.chapter_boss_id if current_chapter_data else &""
	_safe_change_scene(BOSS_ARENA_PATH)


func on_boss_defeated(boss_id: StringName, time_taken: float, no_hit: bool) -> void:
	var first_clear: bool = not _is_chapter_marked_cleared(current_chapter_id)
	EventBus.boss_defeated.emit(boss_id, time_taken, no_hit)
	EventBus.chapter_cleared.emit(current_chapter_id, first_clear)
	start_intermission()


func enter_intermission() -> void:
	state = FlowState.INTERMISSION
	EventBus.intermission_entered.emit(current_chapter_id)


# 씬 전환 포함: 막간 화면으로 이동.
func start_intermission() -> void:
	state = FlowState.INTERMISSION
	EventBus.intermission_entered.emit(current_chapter_id)
	_safe_change_scene(INTERMISSION_PATH)


# 씬 전환 포함: 다음 챕터 첫 스테이지로 이동. 다음 챕터 없으면 메인 메뉴.
func advance_to_next_chapter() -> void:
	var next_id: StringName = _next_chapter_id(current_chapter_id)
	EventBus.intermission_exited.emit(next_id)
	if next_id != &"":
		current_chapter_id = next_id
		current_chapter_data = _chapter_registry.get(next_id, null)
		current_stage_index = 0
		state = FlowState.LOADING
		EventBus.stage_started.emit(current_chapter_id, current_stage_index)
		state = FlowState.IN_STAGE
		_safe_change_scene(GAME_SCENE_PATH)
	else:
		state = FlowState.RESULT
		EventBus.run_ended.emit(&"clear", {"chapter": String(current_chapter_id)})
		_safe_change_scene(MAIN_MENU_PATH)


func exit_intermission_to_next_chapter() -> void:
	# 하위 호환 별칭 — 씬 전환 포함 메서드로 위임.
	advance_to_next_chapter()


func on_player_died() -> void:
	# GameState가 부활 가능 여부를 결정. 본 핸들러는 마지막 사망(부활 불가)만 받는다.
	state = FlowState.RESULT
	EventBus.run_ended.emit(&"death", {"chapter": String(current_chapter_id)})


func quit_to_main_menu() -> void:
	if state == FlowState.IN_STAGE or state == FlowState.BOSS_BATTLE:
		EventBus.run_ended.emit(&"abandon", {"chapter": String(current_chapter_id)})
	state = FlowState.MAIN_MENU
	_safe_change_scene(MAIN_MENU_PATH)


# === 헬퍼: 씬 전환 안전 호출 ===

func _safe_change_scene(path: String) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.paused = false
	# 다음 프레임으로 미뤄 현재 콜백 스택을 안전히 마무리.
	tree.call_deferred("change_scene_to_file", path)


# === 흐름 헬퍼 ===

func is_chapter_unlocked(id: StringName) -> bool:
	var data: ChapterData = _chapter_registry.get(id, null)
	if data == null:
		# 데이터가 없으면 챕터1만 기본 잠금 해제 — 풀 데이터 도입 전 안전한 폴백.
		return id == &"ch01_dumeong" or id == &""
	if MetaState.shinmok_stage < data.unlock_shinmok_required:
		return false
	for req in data.unlock_requires:
		if not _is_chapter_marked_cleared(req):
			return false
	return true


func get_chapter_list() -> Array[ChapterData]:
	var arr: Array[ChapterData] = []
	for k in _chapter_registry.keys():
		arr.append(_chapter_registry[k])
	arr.sort_custom(func(a: ChapterData, b: ChapterData) -> bool: return a.chapter_number < b.chapter_number)
	return arr


func register_chapter(data: ChapterData) -> void:
	if data == null:
		return
	_chapter_registry[data.id] = data


# === 내부 ===

func _on_boss_defeated_signal(_boss_id: StringName, _t: float, _no_hit: bool) -> void:
	# on_boss_defeated()는 GameScene이 직접 호출. EventBus 수신은 통계 목적의 후행 hook.
	pass


func _on_player_died_signal() -> void:
	# 본 핸들러는 GameScene이 부활 분기를 마친 뒤 호출되도록 설계. 직접 수신 시는 무동작.
	pass


func _on_stage_cleared_signal(_ch: StringName, _idx: int) -> void:
	pass


func _is_chapter_marked_cleared(chapter_id: StringName) -> bool:
	var entry: Dictionary = MetaState.codex_places.get(chapter_id, {})
	return bool(entry.get("cleared", false))


func _next_chapter_id(current: StringName) -> StringName:
	var arr: Array[ChapterData] = get_chapter_list()
	for i in arr.size():
		if arr[i].id == current and i + 1 < arr.size():
			return arr[i + 1].id
	return &""
