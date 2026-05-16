extends SceneTree

# tests/test_bosses.gd — 11종 보스(미니5 + 챕터6) 페이즈 / 사망 / 보상 / 챕터 전환 스모크 테스트.
# 실행:
#   godot --headless --path /Users/0xb10ck/kkaebi-run --script tests/test_bosses.gd
#
# 각 보스 씬에 대해 다음을 검증한다:
#  1) 씬 인스턴스화 + SceneTree.root 부착 + _ready/인트로 완료 대기.
#  2) phase_changed / EventBus.boss_phase_changed 시그널을 spy로 연결.
#  3) data.phases[1..]의 hp_threshold_percent 직전(살짝 위) → 직후(살짝 아래)로
#     current_hp 를 강제 조정하고 boss._check_phase_transition() 호출.
#       - 직전: 시그널 발화 X
#       - 직후: phase_changed(new_index) 발화 + EventBus.boss_phase_changed 발화
#  4) transition_invuln_s 동안 physics_frame 을 흘려보낸 뒤 current_phase_index 가
#     새 인덱스로 안착했는지 + current_phase == data.phases[new_index] + pattern_queue
#     가 비어 있지 않은지 ( = 해당 페이즈 패턴 노드 활성화) 검증.
#  5) 모든 페이즈 임계 통과 후 boss.invuln=false / fsm_state=&"idle" 강제, current_hp=1
#     로 두고 take_damage(armor+5) 호출 → _die() 발화.
#       - boss.died(boss_id) 시그널 발화
#       - EventBus.boss_defeated(boss_id, ...) 발화
#       - MetaState.dokkaebi_orbs 증가 (= EventBus.boss_defeated 수신 → record_boss_defeated
#         → add to dokkaebi_orbs. 보상 정산 발화 증거. GameState.add_orbs 등과 동치 위치)
#  6) 다음 챕터 잠금 해제 흐름: 보스 아레나가 _advance_after_boss 에서 호출하는
#     ChapterManager.on_boss_defeated(boss_id, time, no_hit) 를 그대로 호출한 뒤
#     EventBus.chapter_cleared 가 emit 되는지 확인. (= ChapterManager.unlock_next 등가 — 본
#     코드베이스에서 챕터 진행을 다음 단계로 풀어 주는 공개 API.)
#
# 하나라도 실패하면 exit code 1. push_error 는 SCRIPT ERROR 로 집계되므로 print() 만 사용한다.


const BOSSES: Array[Dictionary] = [
	{"label": "ch1_mini_jangsanbeom",      "scene": "res://scenes/bosses/mb01_jangsanbeom.tscn",        "id": &"mb01_jangsanbeom",       "chapter": &"ch01_dumeong"},
	{"label": "ch1_main_dokkaebibul",      "scene": "res://scenes/bosses/b01_dokkaebibul_daejang.tscn", "id": &"b01_dokkaebibul_daejang","chapter": &"ch01_dumeong"},
	{"label": "ch2_mini_imugi",            "scene": "res://scenes/bosses/mb02_imugi.tscn",              "id": &"mb02_imugi",             "chapter": &"ch02_sinryeong"},
	{"label": "ch2_main_gumiho",           "scene": "res://scenes/bosses/b02_gumiho.tscn",              "id": &"b02_gumiho",             "chapter": &"ch02_sinryeong"},
	{"label": "ch3_mini_chagwishin",       "scene": "res://scenes/bosses/mb03_chagwishin.tscn",         "id": &"mb03_chagwishin",        "chapter": &"ch03_hwangcheon"},
	{"label": "ch3_main_jeoseung_saja",    "scene": "res://scenes/bosses/b03_jeoseung_saja.tscn",       "id": &"b03_jeoseung_saja",      "chapter": &"ch03_hwangcheon"},
	{"label": "ch4_mini_geumdwaeji",       "scene": "res://scenes/bosses/mb04_geumdwaeji.tscn",         "id": &"mb04_geumdwaeji",        "chapter": &"ch04_cheonsang"},
	{"label": "ch4_main_cheondung",        "scene": "res://scenes/bosses/b04_cheondung_janggun.tscn",   "id": &"b04_cheondung_janggun",  "chapter": &"ch04_cheonsang"},
	{"label": "ch5_mini_geomeun_dokkaebi", "scene": "res://scenes/bosses/mb05_geomeun_dokkaebi.tscn",   "id": &"mb05_geomeun_dokkaebi",  "chapter": &"ch05_sinmok_heart"},
	{"label": "ch5_main_heuk_ryong",       "scene": "res://scenes/bosses/b05_heuk_ryong.tscn",          "id": &"b05_heuk_ryong",         "chapter": &"ch05_sinmok_heart"},
	{"label": "ch6_main_daewang_dokkaebi", "scene": "res://scenes/bosses/b06_daewang_dokkaebi.tscn",    "id": &"b06_daewang_dokkaebi",   "chapter": &"ch_hidden_market"},
]

# transition_invuln_s 의 최대값(가장 긴 케이스 = 2.2s) + 여유. 60fps physics 기준 약 3초.
const TRANSITION_WAIT_FRAMES: int = 200

var errors: Array[String] = []
var passes: int = 0
var stub_player: Node2D
var _chapter_manager: Node
var _event_bus: Node
var _meta_state: Node


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	# 자동로드는 스크립트 컴파일 스코프에 글로벌로 보이지 않는다 — root 의 자식으로 접근.
	_chapter_manager = root.get_node_or_null("ChapterManager")
	_event_bus = root.get_node_or_null("EventBus")
	_meta_state = root.get_node_or_null("MetaState")
	if _chapter_manager == null or _event_bus == null or _meta_state == null:
		_record_fail("setup", "autoloads missing — ChapterManager=%s EventBus=%s MetaState=%s" % [
			str(_chapter_manager), str(_event_bus), str(_meta_state)
		])
		_print_summary()
		quit(1)
		return

	# 보스 패턴이 BossCombat.player_pos() 를 호출할 수 있으므로 "player" 그룹 stub 1개를
	# 멀리 두고 공용으로 둔다. 데미지 판정 거리는 충분히 멀리 떨어져 트리거되지 않는다.
	stub_player = _make_stub_player()
	root.add_child(stub_player)

	for entry in BOSSES:
		await _test_boss(entry)

	if is_instance_valid(stub_player):
		stub_player.queue_free()
		await process_frame

	_print_summary()
	quit(0 if errors.is_empty() else 1)


# ────────────────────────────────────────────────────────────────────
# 보스 1종 검증
# ────────────────────────────────────────────────────────────────────
func _test_boss(entry: Dictionary) -> void:
	var label: String = String(entry["label"])
	var scene_path: String = String(entry["scene"])
	var boss_id: StringName = StringName(entry["id"])
	var chapter_id: StringName = StringName(entry["chapter"])

	if not ResourceLoader.exists(scene_path):
		_record_fail(label, "scene missing: %s" % scene_path)
		return

	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		_record_fail(label, "scene load failed: %s" % scene_path)
		return

	# ChapterManager 컨텍스트 — on_boss_defeated() 가 chapter_cleared 발신 시 참조.
	_chapter_manager.set("current_chapter_id", chapter_id)
	var chapter_registry: Dictionary = _chapter_manager.get("_chapter_registry")
	_chapter_manager.set("current_chapter_data", chapter_registry.get(chapter_id, null))
	_chapter_manager.set("current_boss_id", boss_id)

	var boss: Node = packed.instantiate()
	if boss == null:
		_record_fail(label, "instantiate failed")
		return

	root.add_child(boss)
	# _ready + 인트로 (CutsceneRegistry 가 null 반환 → BossBase._on_intro_finished 즉시 호출).
	await process_frame
	await physics_frame

	if not is_instance_valid(boss):
		_record_fail(label, "boss freed before assertions")
		return

	var data: BossData = boss.get("data")
	if data == null:
		_record_fail(label, "data is null after _ready")
		_safe_free(boss)
		await process_frame
		return

	if data.phases.is_empty():
		_record_fail(label, "data.phases is empty")
		_safe_free(boss)
		await process_frame
		return

	# 인트로 직후 invuln 이 풀려 있어야 한다.
	if bool(boss.get("invuln")):
		# 안전 timeout — _tick_intro 가 intro_duration_s+1.5 안에 idle 로 전이한다.
		for _i in 60:
			await physics_frame
			if not bool(boss.get("invuln")):
				break
		if bool(boss.get("invuln")):
			_record_fail(label, "intro did not finish (invuln still true)")
			_safe_free(boss)
			await process_frame
			return

	# ── 시그널 spy 연결 ──────────────────────────────────────────────
	var phase_signal_indices: Array = []
	var on_phase_changed: Callable = func(idx: int) -> void:
		phase_signal_indices.append(idx)
	boss.phase_changed.connect(on_phase_changed)

	var ev_phase_indices: Array = []
	var on_ev_phase_changed: Callable = func(_b: StringName, idx: int) -> void:
		ev_phase_indices.append(idx)
	_event_bus.boss_phase_changed.connect(on_ev_phase_changed)

	# ── 페이즈 임계 검증 ───────────────────────────────────────────────
	var phase_ok: bool = true
	var phase_msgs: Array[String] = []

	for next_index in range(1, data.phases.size()):
		var next_phase: BossPhase = data.phases[next_index]
		var threshold: float = next_phase.hp_threshold_percent

		# (a) 직전(살짝 위) — 전환 NO.
		var above_ratio: float = clamp(threshold + 0.03, 0.001, 0.999)
		var above_hp: int = int(ceil(float(data.hp) * above_ratio))
		above_hp = clamp(above_hp, 1, data.hp)
		boss.current_hp = above_hp
		var before_local: int = phase_signal_indices.size()
		var before_bus: int = ev_phase_indices.size()
		boss._check_phase_transition()
		if phase_signal_indices.size() != before_local or ev_phase_indices.size() != before_bus:
			phase_ok = false
			phase_msgs.append("phase[%d] signal fired prematurely at hp_ratio=%.3f (threshold=%.3f)" % [
				next_index, float(above_hp) / float(data.hp), threshold
			])
			break

		# (b) 직후(살짝 아래) — 전환 발화.
		var below_ratio: float = clamp(threshold - 0.03, 0.0, 0.999)
		var below_hp: int = int(floor(float(data.hp) * below_ratio))
		below_hp = clamp(below_hp, 0, data.hp - 1)
		boss.current_hp = below_hp
		boss._check_phase_transition()

		if phase_signal_indices.is_empty() or int(phase_signal_indices[-1]) != next_index:
			phase_ok = false
			phase_msgs.append("phase[%d] phase_changed signal not emitted (got=%s)" % [
				next_index, str(phase_signal_indices)
			])
			break
		if ev_phase_indices.is_empty() or int(ev_phase_indices[-1]) != next_index:
			phase_ok = false
			phase_msgs.append("phase[%d] EventBus.boss_phase_changed not emitted (got=%s)" % [
				next_index, str(ev_phase_indices)
			])
			break

		# transition_invuln_s 이 흐르면 _tick_transition 이 current_phase_index 를 올린다.
		var settled: bool = false
		for _i in TRANSITION_WAIT_FRAMES:
			await physics_frame
			if not is_instance_valid(boss):
				break
			if int(boss.current_phase_index) == next_index:
				settled = true
				break
		if not is_instance_valid(boss):
			phase_ok = false
			phase_msgs.append("phase[%d] boss freed during transition wait" % next_index)
			break
		if not settled:
			phase_ok = false
			phase_msgs.append("phase[%d] FSM did not settle (cur_index=%d state=%s)" % [
				next_index, int(boss.current_phase_index), str(boss.fsm_state)
			])
			break

		var cur_phase: BossPhase = boss.get("current_phase")
		if cur_phase != data.phases[next_index]:
			phase_ok = false
			phase_msgs.append("phase[%d] current_phase reference mismatch" % next_index)
			break
		if cur_phase.pattern_queue.is_empty():
			phase_ok = false
			phase_msgs.append("phase[%d] pattern_queue empty — patterns inactive" % next_index)
			break

	# 페이즈 검증 실패 시 정리 후 다음 보스로.
	if not phase_ok:
		_disconnect_safe(boss, "phase_changed", on_phase_changed)
		_event_bus.boss_phase_changed.disconnect(on_ev_phase_changed)
		_record_fail(label, "phase check: " + "; ".join(phase_msgs))
		_safe_free(boss)
		await process_frame
		return

	# ── 사망 + 보상 + 챕터 전환 검증 ────────────────────────────────────
	# 마지막 페이즈 transition 종료 후 idle 로 안착했어야 정상이지만, 안전을 위해 강제.
	boss.invuln = false
	boss.fsm_state = &"idle"

	var died_emissions: Array = []
	var on_died: Callable = func(bid: StringName) -> void:
		died_emissions.append(bid)
	boss.died.connect(on_died)

	var bus_defeats: Array = []
	var on_bus_defeated: Callable = func(bid: StringName, t: float, nh: bool) -> void:
		bus_defeats.append({"id": bid, "time": t, "no_hit": nh})
	EventBus.boss_defeated.connect(on_bus_defeated)

	var orbs_before: int = int(MetaState.dokkaebi_orbs)
	var currency_changes: Array = []
	var on_currency_changed: Callable = func(cur: StringName, val: int) -> void:
		currency_changes.append({"currency": cur, "new_value": val})
	EventBus.meta_currency_changed.connect(on_currency_changed)

	var cleared_emissions: Array = []
	var on_chapter_cleared: Callable = func(ch_id: StringName, first: bool) -> void:
		cleared_emissions.append({"chapter": ch_id, "first_clear": first})
	EventBus.chapter_cleared.connect(on_chapter_cleared)

	# HP 강제 1 + armor 를 충분히 넘어 1 이상 데미지가 들어가도록 큰 값.
	boss.current_hp = 1
	boss.no_hit = true
	var fatal_amount: int = max(2, int(data.armor) + 5)
	boss.take_damage(fatal_amount, &"test_bosses")

	# died / boss_defeated 핸들러는 동기로 실행되지만 큐 정리 차원에서 한 프레임 양보.
	await process_frame

	var death_ok: bool = true
	var death_msgs: Array[String] = []

	if died_emissions.is_empty() or StringName(died_emissions[0]) != boss_id:
		death_ok = false
		death_msgs.append("died signal not emitted for %s (got=%s)" % [String(boss_id), str(died_emissions)])

	var bus_match: bool = false
	for r in bus_defeats:
		if StringName(r["id"]) == boss_id:
			bus_match = true
			break
	if not bus_match:
		death_ok = false
		death_msgs.append("EventBus.boss_defeated not emitted for %s (got=%s)" % [String(boss_id), str(bus_defeats)])

	# 보상 정산: MetaState.record_boss_defeated 가 dokkaebi_orbs 를 증가시켜야 한다.
	var orbs_after: int = int(MetaState.dokkaebi_orbs)
	if orbs_after <= orbs_before:
		death_ok = false
		death_msgs.append("MetaState.dokkaebi_orbs did not increase (%d → %d)" % [orbs_before, orbs_after])

	# ChapterManager 의 다음-챕터 전환(=unlock_next 등가) 트리거 검증.
	# BossArena._advance_after_boss 와 동일한 호출 시퀀스.
	var cleared_before: int = cleared_emissions.size()
	ChapterManager.on_boss_defeated(boss_id, 1.0, true)
	await process_frame

	if cleared_emissions.size() == cleared_before:
		death_ok = false
		death_msgs.append("EventBus.chapter_cleared not emitted after ChapterManager.on_boss_defeated")
	elif StringName(cleared_emissions[-1]["chapter"]) != chapter_id:
		death_ok = false
		death_msgs.append("chapter_cleared chapter id mismatch: got=%s expected=%s" % [
			String(cleared_emissions[-1]["chapter"]), String(chapter_id)
		])

	# ── spy 해제 ────────────────────────────────────────────────────
	_disconnect_safe(boss, "phase_changed", on_phase_changed)
	_disconnect_safe(boss, "died", on_died)
	EventBus.boss_phase_changed.disconnect(on_ev_phase_changed)
	EventBus.boss_defeated.disconnect(on_bus_defeated)
	EventBus.meta_currency_changed.disconnect(on_currency_changed)
	EventBus.chapter_cleared.disconnect(on_chapter_cleared)

	if not death_ok:
		_record_fail(label, "death check: " + "; ".join(death_msgs))
		_safe_free(boss)
		await process_frame
		await physics_frame
		return

	passes += 1
	print("[BOSS] PASS — %s — phases=%d local=%s bus=%s orbs+%d cleared=%s" % [
		label, data.phases.size(),
		str(phase_signal_indices), str(ev_phase_indices),
		orbs_after - orbs_before,
		String(cleared_emissions[-1]["chapter"])
	])

	_safe_free(boss)
	await process_frame
	await physics_frame


# ────────────────────────────────────────────────────────────────────
# Stub 플레이어 — BossCombat.player_pos() 가 group("player") 노드를 찾도록.
# ────────────────────────────────────────────────────────────────────
func _make_stub_player() -> Node2D:
	var p: Node2D = Node2D.new()
	p.name = "StubPlayer"
	p.add_to_group("player")
	# 보스 패턴 판정에 닿지 않도록 충분히 멀리.
	p.position = Vector2(100000, 100000)
	return p


# ────────────────────────────────────────────────────────────────────
# 출력 / 유틸
# ────────────────────────────────────────────────────────────────────
func _disconnect_safe(obj: Object, signal_name: String, cb: Callable) -> void:
	if not is_instance_valid(obj):
		return
	if obj.is_connected(signal_name, cb):
		obj.disconnect(signal_name, cb)


func _safe_free(n: Node) -> void:
	if is_instance_valid(n) and not n.is_queued_for_deletion():
		n.queue_free()


func _record_fail(label: String, msg: String) -> void:
	var line := "[%s] %s" % [label, msg]
	errors.append(line)
	print("[BOSS] FAIL — %s" % line)


func _print_summary() -> void:
	print("")
	print("[BOSS] ═══════════════════════════════════════════════")
	print("[BOSS] bosses tested: %d" % BOSSES.size())
	print("[BOSS] passes: %d  failures: %d" % [passes, errors.size()])
	if not errors.is_empty():
		print("[BOSS] failures:")
		for e in errors:
			print("[BOSS]   - %s" % e)
	print("[BOSS] result: %s" % ("PASS" if errors.is_empty() else "FAIL"))
	print("[BOSS] ═══════════════════════════════════════════════")
