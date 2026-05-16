extends SceneTree

# tests/test_meta.gd — 메타 진행(영구 강화 · 신목 · 도감) 검증 (Godot 4 headless).
# 실행:
#   godot --headless --path /Users/0xb10ck/kkaebi-run --script tests/test_meta.gd
#
# 검증 항목
#   1) SaveStore: 임의 데이터 → save_data() → load_data() 후 동일 데이터 복원.
#   2) 8종 영구 강화(max_hp / attack / move_speed / xp_gain / gold_gain /
#      revive / choice_extra / luck) 각각에 대해:
#        - 충분한 도깨비 구슬 부여 → apply_upgrade_purchase() 호출
#        - 비용만큼 정확히 차감, level 0→1 으로 갱신
#        - 골드 부족 시 구매 실패, 레벨 변하지 않음
#        - GameState.reset_for_run() 후 효과가 스탯/배율/카운트에 반영됨
#   3) 신목(shinmok): donate_to_shinmok() 호출로 단계 1→2 진행 + 비용 차감 +
#      shinmok_advanced 시그널 발화 + divine_tree_level 별칭이 stage-1 매핑.
#   4) EventBus.enemy_killed 발화 시:
#        - MetaState.stats.total_kills 가 1 증가
#        - codex_monsters[enemy_id] 가 discovered=true / killed_count=1
#        - 첫 발견 시 codex_entry_unlocked 가 발화
#        - 두 번째 발화 시 killed_count=2 로 누적
#
# 실패 시 exit code 1. push_error 는 SCRIPT ERROR 로 집계되어 종료 코드를
# 어지럽히므로 모든 메시지는 print() 만 사용한다.
#
# 본 테스트는 user://save.json 을 임시 수정한다. 시작 시 원본을 백업하고
# 종료 시 복원/제거하므로 실제 진행도에는 영향이 없다.
#
# --script 실행 모드에서는 autoload 글로벌 식별자(EventBus/MetaState/...)가
# 컴파일 타임에 해상되지 않는다. SceneTree.root 에서 노드로 가져와 사용한다.


const UPGRADE_KEYS: Array[StringName] = [
	&"max_hp", &"attack", &"move_speed",
	&"xp_gain", &"gold_gain",
	&"revive", &"choice_extra", &"luck",
]

var errors: Array[String] = []
var passes: int = 0
var _orig_save_text: String = ""
var _orig_save_existed: bool = false
var _event_bus: Node
var _meta_state: Node
var _game_state: Node


func _initialize() -> void:
	# 자동로드 _ready() 가 모두 끝난 첫 프레임에서 진입한다.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_event_bus = root.get_node_or_null(NodePath("EventBus"))
	_meta_state = root.get_node_or_null(NodePath("MetaState"))
	_game_state = root.get_node_or_null(NodePath("GameState"))
	if _event_bus == null:
		_fail("[setup] EventBus autoload missing")
	if _meta_state == null:
		_fail("[setup] MetaState autoload missing")
	if _game_state == null:
		_fail("[setup] GameState autoload missing")

	_backup_save_file()
	if _event_bus and _meta_state and _game_state:
		_test_save_round_trip()
		_test_permanent_upgrades()
		_test_shinmok_donate()
		_test_enemy_killed_codex_and_stats()
	_restore_save_file()
	_print_summary()
	quit(0 if errors.is_empty() else 1)


# ───────────────────────────────────────────────────────────────────────────
# 1) SaveStore round-trip
# ───────────────────────────────────────────────────────────────────────────

func _test_save_round_trip() -> void:
	var src: Dictionary = SaveStore.default_data()
	src["saved_at"] = 1234567890
	src["build"] = "test-roundtrip"
	var meta: Dictionary = src["meta"]
	meta["currency"] = {
		"dokkaebi_orbs": 4242, "shinmok_leaves": 7, "myth_shards": 3,
	}
	meta["shinmok"] = {"stage": 4}
	meta["upgrades"] = {
		"max_hp": 5, "attack": 4, "move_speed": 3,
		"xp_gain": 2, "gold_gain": 1,
		"revive": 5, "choice_extra": 2, "luck": 3,
	}
	meta["characters"] = {
		"unlocked": ["ttukttaki", "dosuni"],
		"affinity": {"ttukttaki": 12, "dosuni": 5},
		"affinity_nodes": {"ttukttaki": ["nodeA"], "dosuni": []},
	}
	meta["codex"] = {
		"monsters": {
			"slime": {"discovered": true, "killed_count": 9, "first_seen_at": 11},
		},
		"relics": {},
		"places": {},
	}
	meta["achievements"] = {
		"ach_first_clear": {
			"progress": 1, "target": 1, "reward_orbs": 50, "claimed": false,
		},
	}
	meta["stats"] = {
		"total_kills": 99, "total_bosses_defeated": 2, "total_runs": 3,
		"total_clears": 1, "total_deaths": 1, "total_gold_earned": 1234,
		"play_time_seconds": 567.5,
	}
	src["meta"] = meta

	var ok: bool = SaveStore.save_data(src)
	_expect(ok, "[SaveStore] save_data() returned true")

	var loaded: Dictionary = SaveStore.load_data()
	_expect(int(loaded.get("version", -1)) == SaveStore.CURRENT_VERSION,
			"[SaveStore] version preserved (got %d)" % int(loaded.get("version", -1)))
	_expect(int(loaded.get("saved_at", 0)) == 1234567890,
			"[SaveStore] saved_at preserved")
	_expect(String(loaded.get("build", "")) == "test-roundtrip",
			"[SaveStore] build preserved")

	var lm: Dictionary = loaded.get("meta", {})
	var cur: Dictionary = lm.get("currency", {})
	_expect(int(cur.get("dokkaebi_orbs", -1)) == 4242,
			"[SaveStore] currency.dokkaebi_orbs round-trip")
	_expect(int(cur.get("shinmok_leaves", -1)) == 7,
			"[SaveStore] currency.shinmok_leaves round-trip")
	_expect(int(cur.get("myth_shards", -1)) == 3,
			"[SaveStore] currency.myth_shards round-trip")
	_expect(int(lm.get("shinmok", {}).get("stage", -1)) == 4,
			"[SaveStore] shinmok.stage round-trip")

	var ups: Dictionary = lm.get("upgrades", {})
	for k in ["max_hp", "attack", "move_speed", "xp_gain", "gold_gain",
			  "revive", "choice_extra", "luck"]:
		_expect(ups.has(k), "[SaveStore] upgrades has key '%s'" % k)
	_expect(int(ups.get("max_hp", -1)) == 5, "[SaveStore] upgrades.max_hp preserved")
	_expect(int(ups.get("luck", -1)) == 3, "[SaveStore] upgrades.luck preserved")

	var chars: Dictionary = lm.get("characters", {})
	var unlocked: Array = chars.get("unlocked", [])
	_expect(unlocked.has("dosuni"), "[SaveStore] characters.unlocked round-trip")
	var affinity: Dictionary = chars.get("affinity", {})
	_expect(int(affinity.get("ttukttaki", -1)) == 12,
			"[SaveStore] characters.affinity round-trip")

	var monsters: Dictionary = lm.get("codex", {}).get("monsters", {})
	_expect(monsters.has("slime"),
			"[SaveStore] codex.monsters has 'slime'")
	if monsters.has("slime"):
		_expect(int(monsters["slime"].get("killed_count", 0)) == 9,
				"[SaveStore] codex.monsters['slime'].killed_count preserved")

	var ach: Dictionary = lm.get("achievements", {})
	_expect(ach.has("ach_first_clear"),
			"[SaveStore] achievements round-trip")

	var stats: Dictionary = lm.get("stats", {})
	_expect(int(stats.get("total_kills", -1)) == 99,
			"[SaveStore] stats.total_kills round-trip")
	_expect(int(stats.get("total_gold_earned", -1)) == 1234,
			"[SaveStore] stats.total_gold_earned round-trip")


# ───────────────────────────────────────────────────────────────────────────
# 2) 8종 영구 강화: 비용 차감 + GameState 반영
# ───────────────────────────────────────────────────────────────────────────

func _test_permanent_upgrades() -> void:
	for key in UPGRADE_KEYS:
		_reset_meta_state()
		# 신목 게이팅 영향을 피하기 위해 최고 단계로 올린다.
		_meta_state.shinmok_stage = 6
		var cost: int = int(_meta_state.get_upgrade_cost(key, 1))
		_expect(cost > 0,
				"[upgrades:%s] cost_for(level 1) > 0 (got %d)"
				% [String(key), cost])

		# 부족한 골드 → 실패
		_meta_state.dokkaebi_orbs = max(0, cost - 1)
		var fail_ok: bool = bool(_meta_state.apply_upgrade_purchase(key))
		_expect(not fail_ok,
				"[upgrades:%s] purchase fails when orbs < cost" % String(key))
		_expect(int(_meta_state.get_upgrade_level(key)) == 0,
				"[upgrades:%s] level unchanged after failed purchase" % String(key))

		# 충분한 골드 → 성공
		_meta_state.dokkaebi_orbs = cost + 1000
		var before: int = _meta_state.dokkaebi_orbs
		var ok: bool = bool(_meta_state.apply_upgrade_purchase(key))
		_expect(ok,
				"[upgrades:%s] purchase succeeds with enough orbs" % String(key))
		_expect(int(_meta_state.get_upgrade_level(key)) == 1,
				"[upgrades:%s] level == 1 after purchase (got %d)"
				% [String(key), int(_meta_state.get_upgrade_level(key))])
		var spent: int = before - int(_meta_state.dokkaebi_orbs)
		_expect(spent == cost,
				"[upgrades:%s] orbs spent == cost (spent=%d cost=%d)"
				% [String(key), spent, cost])

		# GameState 반영 — reset_for_run() 이 apply_meta_bonuses() 를 호출
		_game_state.reset_for_run(&"ttukttaki", &"ch01_dumeong")
		_verify_upgrade_effect_on_game_state(key)


func _verify_upgrade_effect_on_game_state(key: StringName) -> void:
	var effect: float = float(_meta_state.get_upgrade_effect(key))
	_expect(effect > 0.0,
			"[upgrades:%s] get_upgrade_effect() > 0 at level 1 (got %.4f)"
			% [String(key), effect])
	match key:
		&"max_hp":
			var expected_hp: int = int(round(100.0 * (1.0 + effect)))
			_expect(int(_game_state.max_hp) == expected_hp,
					"[upgrades:max_hp] gs.max_hp == %d (got %d)"
					% [expected_hp, int(_game_state.max_hp)])
			_expect(int(_game_state.current_hp) == expected_hp,
					"[upgrades:max_hp] gs.current_hp == max_hp after reset")
		&"attack":
			var expected_atk: int = int(round(10.0 * (1.0 + effect)))
			_expect(int(_game_state.attack) == expected_atk,
					"[upgrades:attack] gs.attack == %d (got %d)"
					% [expected_atk, int(_game_state.attack)])
		&"move_speed":
			var expected_ms: float = 100.0 * (1.0 + effect)
			_expect(abs(float(_game_state.move_speed) - expected_ms) < 1e-3,
					"[upgrades:move_speed] gs.move_speed ~= %.3f (got %.3f)"
					% [expected_ms, float(_game_state.move_speed)])
		&"xp_gain":
			_expect(abs(float(_game_state.bonus_xp_gain_mult) - (1.0 + effect)) < 1e-3,
					"[upgrades:xp_gain] bonus_xp_gain_mult ~= %.3f (got %.3f)"
					% [1.0 + effect, float(_game_state.bonus_xp_gain_mult)])
		&"gold_gain":
			_expect(abs(float(_game_state.bonus_gold_gain_mult) - (1.0 + effect)) < 1e-3,
					"[upgrades:gold_gain] bonus_gold_gain_mult ~= %.3f (got %.3f)"
					% [1.0 + effect, float(_game_state.bonus_gold_gain_mult)])
		&"revive":
			_expect(int(_game_state.revives_remaining) == int(effect),
					"[upgrades:revive] revives_remaining == %d (got %d)"
					% [int(effect), int(_game_state.revives_remaining)])
		&"choice_extra":
			_expect(abs(float(_game_state.choice_extra_chance) - effect) < 1e-3,
					"[upgrades:choice_extra] choice_extra_chance ~= %.3f (got %.3f)"
					% [effect, float(_game_state.choice_extra_chance)])
		&"luck":
			var expected_luck: float = effect * 100.0
			_expect(abs(float(_game_state.luck_percent) - expected_luck) < 1e-3,
					"[upgrades:luck] luck_percent ~= %.3f (got %.3f)"
					% [expected_luck, float(_game_state.luck_percent)])


# ───────────────────────────────────────────────────────────────────────────
# 3) 신목(shinmok) 헌납
# ───────────────────────────────────────────────────────────────────────────

func _test_shinmok_donate() -> void:
	_reset_meta_state()
	_meta_state.shinmok_stage = 1
	var cost: int = int(_meta_state.get_next_shinmok_cost())
	_expect(cost > 0,
			"[shinmok] get_next_shinmok_cost(stage 1->2) > 0 (got %d)" % cost)
	_expect(int(_meta_state.divine_tree_level) == 0,
			"[shinmok] divine_tree_level == 0 at stage 1")

	# 부족한 골드 → 실패
	_meta_state.dokkaebi_orbs = max(0, cost - 1)
	_expect(not bool(_meta_state.donate_to_shinmok()),
			"[shinmok] donate fails when orbs < cost")
	_expect(int(_meta_state.shinmok_stage) == 1,
			"[shinmok] stage unchanged after failed donate (got %d)"
			% int(_meta_state.shinmok_stage))

	# 충분한 골드 → 성공 + 시그널 발화
	_meta_state.dokkaebi_orbs = cost + 50
	var before_orbs: int = _meta_state.dokkaebi_orbs
	var advanced_hit: Array = [false, -1]
	var on_advanced := func(new_stage: int) -> void:
		advanced_hit[0] = true
		advanced_hit[1] = int(new_stage)
	_event_bus.shinmok_advanced.connect(on_advanced)
	var ok: bool = bool(_meta_state.donate_to_shinmok())
	_event_bus.shinmok_advanced.disconnect(on_advanced)

	_expect(ok, "[shinmok] donate_to_shinmok() succeeded with enough orbs")
	_expect(int(_meta_state.shinmok_stage) == 2,
			"[shinmok] stage advanced 1->2 (got %d)" % int(_meta_state.shinmok_stage))
	_expect(int(before_orbs - _meta_state.dokkaebi_orbs) == cost,
			"[shinmok] orbs deducted == cost (deducted=%d cost=%d)"
			% [int(before_orbs - _meta_state.dokkaebi_orbs), cost])
	_expect(bool(advanced_hit[0]),
			"[shinmok] EventBus.shinmok_advanced emitted")
	_expect(int(advanced_hit[1]) == 2,
			"[shinmok] shinmok_advanced new_stage == 2 (got %d)"
			% int(advanced_hit[1]))
	_expect(int(_meta_state.divine_tree_level) == int(_meta_state.shinmok_stage) - 1,
			"[shinmok] divine_tree_level == shinmok_stage - 1 (lv=%d stage=%d)"
			% [int(_meta_state.divine_tree_level), int(_meta_state.shinmok_stage)])


# ───────────────────────────────────────────────────────────────────────────
# 4) EventBus.enemy_killed → 도감/통계 갱신
# ───────────────────────────────────────────────────────────────────────────

func _test_enemy_killed_codex_and_stats() -> void:
	_reset_meta_state()
	var enemy_id: StringName = &"test_dummy_slime"

	_expect(int(_meta_state.stats.get("total_kills", -1)) == 0,
			"[enemy_killed] total_kills == 0 before emit (got %d)"
			% int(_meta_state.stats.get("total_kills", -1)))
	_expect(not _meta_state.codex_monsters.has(enemy_id),
			"[enemy_killed] codex empty for enemy_id before emit")

	# 첫 처치: discovered=true, killed_count=1, codex_entry_unlocked 발화
	var unlocked_seen: Array = []
	var on_codex := func(category: StringName, eid: StringName) -> void:
		unlocked_seen.append([String(category), String(eid)])
	_event_bus.codex_entry_unlocked.connect(on_codex)

	_event_bus.enemy_killed.emit(enemy_id, Vector2.ZERO, &"basic_attack")

	_expect(int(_meta_state.stats.get("total_kills", -1)) == 1,
			"[enemy_killed] total_kills incremented to 1 (got %d)"
			% int(_meta_state.stats.get("total_kills", -1)))
	_expect(_meta_state.codex_monsters.has(enemy_id),
			"[enemy_killed] codex_monsters has '%s'" % String(enemy_id))
	var entry: Dictionary = _meta_state.codex_monsters.get(enemy_id, {})
	_expect(bool(entry.get("discovered", false)),
			"[enemy_killed] codex entry discovered == true")
	_expect(int(entry.get("killed_count", 0)) == 1,
			"[enemy_killed] codex killed_count == 1 (got %d)"
			% int(entry.get("killed_count", -1)))
	_expect(bool(_meta_state.is_codex_entry_unlocked(&"monsters", enemy_id)),
			"[enemy_killed] is_codex_entry_unlocked('monsters', id) == true")

	var saw_unlock: bool = false
	for pair in unlocked_seen:
		if pair[0] == "monsters" and pair[1] == String(enemy_id):
			saw_unlock = true
			break
	_expect(saw_unlock,
			"[enemy_killed] codex_entry_unlocked emitted for first discovery")

	# 두 번째 처치: killed_count 누적, discovered 유지
	unlocked_seen.clear()
	_event_bus.enemy_killed.emit(enemy_id, Vector2.ZERO, &"basic_attack")
	_event_bus.codex_entry_unlocked.disconnect(on_codex)

	_expect(int(_meta_state.stats.get("total_kills", -1)) == 2,
			"[enemy_killed] total_kills incremented to 2 (got %d)"
			% int(_meta_state.stats.get("total_kills", -1)))
	var entry2: Dictionary = _meta_state.codex_monsters.get(enemy_id, {})
	_expect(int(entry2.get("killed_count", 0)) == 2,
			"[enemy_killed] killed_count incremented to 2 (got %d)"
			% int(entry2.get("killed_count", -1)))
	# 일회성 도전과제(ach_kill_*)의 라이브 진행도는 total_kills 직참조 — 누적 반영
	_expect(int(_meta_state.stats.get("total_kills", 0)) == 2,
			"[enemy_killed] achievement live progress (kills) == 2")


# ───────────────────────────────────────────────────────────────────────────
# 헬퍼
# ───────────────────────────────────────────────────────────────────────────

func _reset_meta_state() -> void:
	# restore_from_save({}) 는 early-return 하므로 명시적 기본 dict 로 호출.
	var default_meta: Dictionary = SaveStore.default_data().get("meta", {})
	_meta_state.restore_from_save(default_meta)


func _backup_save_file() -> void:
	var path: String = SaveStore.PATH
	if not FileAccess.file_exists(path):
		_orig_save_existed = false
		return
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		_orig_save_existed = false
		return
	_orig_save_text = f.get_as_text()
	f.close()
	_orig_save_existed = true


func _restore_save_file() -> void:
	var path: String = SaveStore.PATH
	if _orig_save_existed:
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(_orig_save_text)
			f.close()
	else:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


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
	print("-- test_meta summary --")
	print("PASS: %d" % passes)
	print("FAIL: %d" % errors.size())
	if not errors.is_empty():
		print("Failed checks:")
		for e in errors:
			print("  - %s" % e)
