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

# §4 — 챕터별 일반 몬스터 풀 매핑.
# 1~5장은 chapter_number == .tres 디렉토리 인덱스, 히든(6장)은 hidden/ 하위.
# 각 엔트리: {key, scene_path, data_path}. game_scene이 PackedScene/EnemyData를 로드해 사용.
const MONSTER_POOL_BY_CHAPTER: Dictionary = {
	1: [
		{"key": "m01", "scene_path": "res://scenes/enemies/m01_dokkaebibul.tscn", "data_path": "res://resources/enemies/chapter1/m01_dokkaebibul.tres"},
		{"key": "m02", "scene_path": "res://scenes/enemies/m02_dalgyalgwisin.tscn", "data_path": "res://resources/enemies/chapter1/m02_dalgyalgwisin.tres"},
		{"key": "m03", "scene_path": "res://scenes/enemies/m03_mulgwisin.tscn", "data_path": "res://resources/enemies/chapter1/m03_mulgwisin.tres"},
		{"key": "m04", "scene_path": "res://scenes/enemies/m04_eodukshini.tscn", "data_path": "res://resources/enemies/chapter1/m04_eodukshini.tres"},
		{"key": "m05", "scene_path": "res://scenes/enemies/m05_geuseundae.tscn", "data_path": "res://resources/enemies/chapter1/m05_geuseundae.tres"},
		{"key": "m06", "scene_path": "res://scenes/enemies/m06_bitjarugwisin.tscn", "data_path": "res://resources/enemies/chapter1/m06_bitjarugwisin.tres"},
		{"key": "m07", "scene_path": "res://scenes/enemies/m07_songakshi.tscn", "data_path": "res://resources/enemies/chapter1/m07_songakshi.tres"},
		{"key": "m08", "scene_path": "res://scenes/enemies/m08_mongdalgwisin.tscn", "data_path": "res://resources/enemies/chapter1/m08_mongdalgwisin.tres"},
		{"key": "m09", "scene_path": "res://scenes/enemies/m09_duduri.tscn", "data_path": "res://resources/enemies/chapter1/m09_duduri.tres"},
	],
	2: [
		{"key": "m10", "scene_path": "res://scenes/enemies/m10_samdugu.tscn", "data_path": "res://resources/enemies/chapter2/m10_samdugu.tres"},
		{"key": "m11", "scene_path": "res://scenes/enemies/m11_horangi.tscn", "data_path": "res://resources/enemies/chapter2/m11_horangi.tres"},
		{"key": "m12", "scene_path": "res://scenes/enemies/m12_metdwaeji.tscn", "data_path": "res://resources/enemies/chapter2/m12_metdwaeji.tres"},
		{"key": "m13", "scene_path": "res://scenes/enemies/m13_neoguri.tscn", "data_path": "res://resources/enemies/chapter2/m13_neoguri.tres"},
		{"key": "m14", "scene_path": "res://scenes/enemies/m14_dukkeobi.tscn", "data_path": "res://resources/enemies/chapter2/m14_dukkeobi.tres"},
		{"key": "m15", "scene_path": "res://scenes/enemies/m15_geomi.tscn", "data_path": "res://resources/enemies/chapter2/m15_geomi.tres"},
		{"key": "m16", "scene_path": "res://scenes/enemies/m16_noru.tscn", "data_path": "res://resources/enemies/chapter2/m16_noru.tres"},
		{"key": "m17", "scene_path": "res://scenes/enemies/m17_namu.tscn", "data_path": "res://resources/enemies/chapter2/m17_namu.tres"},
		{"key": "m18", "scene_path": "res://scenes/enemies/m18_deonggul.tscn", "data_path": "res://resources/enemies/chapter2/m18_deonggul.tres"},
		{"key": "m19", "scene_path": "res://scenes/enemies/m19_kamagwi.tscn", "data_path": "res://resources/enemies/chapter2/m19_kamagwi.tres"},
	],
	3: [
		{"key": "m20", "scene_path": "res://scenes/enemies/m20_cheonyeo_gwisin.tscn", "data_path": "res://resources/enemies/chapter3/m20_cheonyeo_gwisin.tres"},
		{"key": "m21", "scene_path": "res://scenes/enemies/m21_jeoseung_gae.tscn", "data_path": "res://resources/enemies/chapter3/m21_jeoseung_gae.tres"},
		{"key": "m22", "scene_path": "res://scenes/enemies/m22_mangryang.tscn", "data_path": "res://resources/enemies/chapter3/m22_mangryang.tres"},
		{"key": "m23", "scene_path": "res://scenes/enemies/m23_gangshi.tscn", "data_path": "res://resources/enemies/chapter3/m23_gangshi.tres"},
		{"key": "m24", "scene_path": "res://scenes/enemies/m24_yagwang_gwi.tscn", "data_path": "res://resources/enemies/chapter3/m24_yagwang_gwi.tres"},
		{"key": "m25", "scene_path": "res://scenes/enemies/m25_baekgol_gwi.tscn", "data_path": "res://resources/enemies/chapter3/m25_baekgol_gwi.tres"},
		{"key": "m26", "scene_path": "res://scenes/enemies/m26_gaeksahon.tscn", "data_path": "res://resources/enemies/chapter3/m26_gaeksahon.tres"},
		{"key": "m27", "scene_path": "res://scenes/enemies/m27_saseul_gwi.tscn", "data_path": "res://resources/enemies/chapter3/m27_saseul_gwi.tres"},
		{"key": "m28", "scene_path": "res://scenes/enemies/m28_dochaebi.tscn", "data_path": "res://resources/enemies/chapter3/m28_dochaebi.tres"},
		{"key": "m29", "scene_path": "res://scenes/enemies/m29_chasahon.tscn", "data_path": "res://resources/enemies/chapter3/m29_chasahon.tres"},
	],
	4: [
		{"key": "m30", "scene_path": "res://scenes/enemies/m30_bulgasari.tscn", "data_path": "res://resources/enemies/chapter4/m30_bulgasari.tres"},
		{"key": "m31", "scene_path": "res://scenes/enemies/m31_yacha.tscn", "data_path": "res://resources/enemies/chapter4/m31_yacha.tres"},
		{"key": "m32", "scene_path": "res://scenes/enemies/m32_nachal.tscn", "data_path": "res://resources/enemies/chapter4/m32_nachal.tres"},
		{"key": "m33", "scene_path": "res://scenes/enemies/m33_cheonnyeo.tscn", "data_path": "res://resources/enemies/chapter4/m33_cheonnyeo.tres"},
		{"key": "m34", "scene_path": "res://scenes/enemies/m34_noegong.tscn", "data_path": "res://resources/enemies/chapter4/m34_noegong.tres"},
		{"key": "m35", "scene_path": "res://scenes/enemies/m35_pungbaek.tscn", "data_path": "res://resources/enemies/chapter4/m35_pungbaek.tres"},
		{"key": "m36", "scene_path": "res://scenes/enemies/m36_usa.tscn", "data_path": "res://resources/enemies/chapter4/m36_usa.tres"},
		{"key": "m37", "scene_path": "res://scenes/enemies/m37_hak.tscn", "data_path": "res://resources/enemies/chapter4/m37_hak.tres"},
		{"key": "m38", "scene_path": "res://scenes/enemies/m38_gareungbinga.tscn", "data_path": "res://resources/enemies/chapter4/m38_gareungbinga.tres"},
		{"key": "m39", "scene_path": "res://scenes/enemies/m39_cheonma.tscn", "data_path": "res://resources/enemies/chapter4/m39_cheonma.tres"},
	],
	5: [
		{"key": "m40", "scene_path": "res://scenes/enemies/m40_heukpung.tscn", "data_path": "res://resources/enemies/chapter5/m40_heukpung.tres"},
		{"key": "m41", "scene_path": "res://scenes/enemies/m41_bihyeongrang_grimja.tscn", "data_path": "res://resources/enemies/chapter5/m41_bihyeongrang_grimja.tres"},
		{"key": "m42", "scene_path": "res://scenes/enemies/m42_heukmusa.tscn", "data_path": "res://resources/enemies/chapter5/m42_heukmusa.tres"},
		{"key": "m43", "scene_path": "res://scenes/enemies/m43_yeonggwi.tscn", "data_path": "res://resources/enemies/chapter5/m43_yeonggwi.tres"},
		{"key": "m44", "scene_path": "res://scenes/enemies/m44_grimja_dokkaebi.tscn", "data_path": "res://resources/enemies/chapter5/m44_grimja_dokkaebi.tres"},
		{"key": "m45", "scene_path": "res://scenes/enemies/m45_ohyeomdoen_shinmok_gaji.tscn", "data_path": "res://resources/enemies/chapter5/m45_ohyeomdoen_shinmok_gaji.tres"},
		{"key": "m46", "scene_path": "res://scenes/enemies/m46_heukryong_saekki.tscn", "data_path": "res://resources/enemies/chapter5/m46_heukryong_saekki.tres"},
		{"key": "m47", "scene_path": "res://scenes/enemies/m47_geomeun_angae_jamyeong.tscn", "data_path": "res://resources/enemies/chapter5/m47_geomeun_angae_jamyeong.tres"},
		{"key": "m48", "scene_path": "res://scenes/enemies/m48_sijang_dokkaebi.tscn", "data_path": "res://resources/enemies/chapter5/m48_sijang_dokkaebi.tres"},
		{"key": "m49", "scene_path": "res://scenes/enemies/m49_geokkuro_dokkaebi.tscn", "data_path": "res://resources/enemies/chapter5/m49_geokkuro_dokkaebi.tres"},
	],
	6: [
		{"key": "m50", "scene_path": "res://scenes/enemies/m50_noreumkkun.tscn", "data_path": "res://resources/enemies/hidden/m50_noreumkkun.tres"},
		{"key": "m51", "scene_path": "res://scenes/enemies/m51_sulchwihan.tscn", "data_path": "res://resources/enemies/hidden/m51_sulchwihan.tres"},
		{"key": "m52", "scene_path": "res://scenes/enemies/m52_byeonjang.tscn", "data_path": "res://resources/enemies/hidden/m52_byeonjang.tres"},
		{"key": "m53", "scene_path": "res://scenes/enemies/m53_ssireum.tscn", "data_path": "res://resources/enemies/hidden/m53_ssireum.tres"},
	],
}

# §4 — 보스 11종(미니 5 + 챕터 6) id → scene_path.
const BOSS_SCENE_BY_ID: Dictionary = {
	&"mb01_jangsanbeom": "res://scenes/bosses/boss_jangsanbeom.tscn",
	&"mb02_imugi": "res://scenes/bosses/boss_imugi.tscn",
	&"mb03_chagwishin": "res://scenes/bosses/boss_chagwishin.tscn",
	&"mb04_geumdwaeji": "res://scenes/bosses/boss_geumdwaeji.tscn",
	&"mb05_geomeun_dokkaebi": "res://scenes/bosses/boss_geomeun_dokkaebi.tscn",
	&"b01_dokkaebibul_daejang": "res://scenes/bosses/boss_dokkaebibul_daejang.tscn",
	&"b02_gumiho": "res://scenes/bosses/boss_gumiho.tscn",
	&"b03_jeoseung_saja": "res://scenes/bosses/boss_jeoseung_saja.tscn",
	&"b04_cheondung_janggun": "res://scenes/bosses/boss_cheondung_janggun.tscn",
	&"b05_heuk_ryong": "res://scenes/bosses/boss_heuk_ryong.tscn",
	&"b06_daewang_dokkaebi": "res://scenes/bosses/boss_daewang_dokkaebi.tscn",
}

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


# === AC 명세 별칭 — stage → boss → interlude → next_chapter 순서로 외부 호출 ===

func advance_stage() -> void:
	on_stage_cleared()


func start_boss_battle() -> void:
	advance_to_boss()


func start_interlude() -> void:
	start_intermission()


func start_next_chapter() -> void:
	advance_to_next_chapter()


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


# === 매핑 헬퍼 ===

# 현재 챕터의 일반 몬스터 풀(.tres + .tscn 경로 묶음). 챕터가 비었거나 미등록이면 빈 배열.
func get_monster_pool_for_current_chapter() -> Array:
	var num: int = current_chapter_data.chapter_number if current_chapter_data else 1
	return get_monster_pool_for_chapter(num)


# 챕터 번호로 일반 몬스터 풀을 반환. 1~6 외의 번호면 빈 배열.
func get_monster_pool_for_chapter(chapter_number: int) -> Array:
	return MONSTER_POOL_BY_CHAPTER.get(chapter_number, [])


# 현재 챕터의 미니보스 id. 데이터가 비면 &"".
func get_mini_boss_id() -> StringName:
	return current_chapter_data.mini_boss_id if current_chapter_data else &""


# 현재 챕터의 메인(챕터) 보스 id. 데이터가 비면 &"".
func get_main_boss_id() -> StringName:
	return current_chapter_data.chapter_boss_id if current_chapter_data else &""


# 보스 id → 보스 씬 경로. 미등록 id면 빈 문자열.
func get_boss_scene_path(boss_id: StringName) -> String:
	return BOSS_SCENE_BY_ID.get(boss_id, "")


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
