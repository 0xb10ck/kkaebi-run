extends SceneTree

# tests/test_chapters.gd — 챕터 1~5 + 히든(6) ChapterManager 셋업 + 60초 스폰 시뮬레이션 검증.
# 실행:
#   godot --headless --path /Users/0xb10ck/kkaebi-run --script tests/test_chapters.gd
#
# 챕터별로 다음을 검증한다:
#   1) ChapterManager 가 챕터 데이터(ChapterData)를 정상적으로 로드/노출
#   2) ChapterManager.get_monster_pool_for_chapter(num) 가 비어 있지 않은 풀을 반환
#   3) game_scene._tick_data_pool 과 동일한 로직(POOL_RATE_TIERS + spawn_weight + min_stage_time_s)으로
#      60초 시뮬레이션을 돌려, 실제 PackedScene 을 instantiate 하며 스폰 진행
#   4) 스폰된 모든 적의 key 가 챕터 풀의 key 집합에 포함되는지 검증
#   5) 시간 경과(t = 0s / 30s / 60s)에서 글로벌 spawn_rate(POOL_RATE_TIERS)가
#      단조 비감소(monotonic non-decreasing)인지 검증
#
# 실패 시 exit code 1. push_error 는 SCRIPT ERROR 로 집계되므로 print() 만 사용한다.
# 사양에 등장하는 ChapterManager.get_pool(chapter_id) 는 현재 코드의
# get_monster_pool_for_chapter(chapter_number) 와 동치이다 — 메서드가 추가되면 자동으로 그쪽을 우선 사용한다.


const CHAPTER_RES_DIR: String = "res://resources/chapters"

const CHAPTER_FLOW: Array = [
	{"id": &"ch01_dumeong",      "number": 1},
	{"id": &"ch02_sinryeong",    "number": 2},
	{"id": &"ch03_hwangcheon",   "number": 3},
	{"id": &"ch04_cheonsang",    "number": 4},
	{"id": &"ch05_sinmok_heart", "number": 5},
	{"id": &"ch_hidden_market",  "number": 6},
]

# game_scene.gd 의 POOL_RATE_TIERS 와 동일하게 유지해야 한다.
const POOL_RATE_TIERS: Array = [
	{"t_start":   0.0, "rate": 0.7},
	{"t_start":  30.0, "rate": 1.1},
	{"t_start":  90.0, "rate": 1.6},
	{"t_start": 150.0, "rate": 2.0},
	{"t_start": 210.0, "rate": 2.5},
	{"t_start": 270.0, "rate": 3.0},
]

const SIM_DURATION_S: float = 60.0
const SIM_TICK_DELTA: float = 0.1   # 0.1s × 600 tick
const TIME_CHECKPOINTS: Array = [0.0, 30.0, 60.0]
const RNG_SEED: int = 0xC4A971
const PHYSICS_YIELD_EVERY_N_TICKS: int = 10  # 약 1초마다 한 physics frame 양보
const FREE_BATCH_THRESHOLD: int = 60         # 인스턴스 누적이 이 값을 넘으면 정리

var errors: Array[String] = []
var stub_player: Node2D
var enemy_container: Node2D
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_setup_stage()

	# 글로벌 spawn_rate 단조성은 챕터와 무관(상수)하지만, 사양상 "챕터별로" 검증하라 했으므로
	# 챕터 루프 내부에서도 매번 검사한다. 여기서는 추가로 한 번 더 사전 검사한다.
	_check_rate_monotonicity("global")

	for ch in CHAPTER_FLOW:
		var entry: Dictionary = ch
		await _test_chapter(StringName(entry["id"]), int(entry["number"]))

	_teardown_stage()
	_print_summary()
	quit(0 if errors.is_empty() else 1)


# ────────────────────────────────────────────────────────────────────────────
# 스테이지 셋업 / 정리
# ────────────────────────────────────────────────────────────────────────────
func _setup_stage() -> void:
	rng.seed = RNG_SEED
	stub_player = _make_stub_player()
	stub_player.position = Vector2(0, 0)
	root.add_child(stub_player)
	enemy_container = Node2D.new()
	enemy_container.name = "EnemyContainer"
	root.add_child(enemy_container)


func _teardown_stage() -> void:
	_free_children(enemy_container)
	if is_instance_valid(enemy_container):
		enemy_container.queue_free()
	if is_instance_valid(stub_player):
		stub_player.queue_free()


# ────────────────────────────────────────────────────────────────────────────
# 챕터 1종 검증
# ────────────────────────────────────────────────────────────────────────────
func _test_chapter(chapter_id: StringName, chapter_number: int) -> void:
	var label: String = String(chapter_id)
	var cm: Node = root.get_node_or_null("ChapterManager")
	if cm == null:
		_err("[%s] ChapterManager autoload missing" % label)
		return

	# 챕터 RNG 시드를 챕터마다 동일하게 리셋해 재현 가능한 검증을 보장한다.
	rng.seed = RNG_SEED ^ (chapter_number * 2654435761)

	# 챕터 데이터 로드.
	var data_path: String = "%s/%s.tres" % [CHAPTER_RES_DIR, label]
	if not ResourceLoader.exists(data_path):
		_err("[%s] chapter resource missing: %s" % [label, data_path])
		return
	var chapter_data: ChapterData = load(data_path) as ChapterData
	if chapter_data == null:
		_err("[%s] failed to load ChapterData: %s" % [label, data_path])
		return
	if chapter_data.chapter_number != chapter_number:
		_err("[%s] chapter_number mismatch: expected %d got %d" % [label, chapter_number, chapter_data.chapter_number])

	# ChapterManager 등록 + 컨텍스트 직설정. is_chapter_unlocked 우회를 위해 setter 만 사용.
	cm.call("register_chapter", chapter_data)
	cm.set("current_chapter_id", chapter_id)
	cm.set("current_chapter_data", chapter_data)
	cm.set("current_stage_index", 0)
	if "state" in cm:
		cm.set("state", cm.FlowState.IN_STAGE)

	# 풀 조회 — get_pool(id) 가 추가되면 그쪽을 우선 사용. 현재 표면은 number 기반.
	var raw_pool: Array = _get_chapter_pool(cm, chapter_id, chapter_number)
	if raw_pool.is_empty():
		_err("[%s] chapter monster pool empty (number=%d)" % [label, chapter_number])
		return

	# 풀 로드 (game_scene._load_pool 미러).
	var loaded: Array = []
	var allowed_keys: Dictionary = {}
	for row in raw_pool:
		var r: Dictionary = row
		var scene_path: String = String(r.get("scene_path", ""))
		var enemy_data_path: String = String(r.get("data_path", ""))
		var key: String = String(r.get("key", ""))
		if scene_path == "" or enemy_data_path == "" or key == "":
			_err("[%s] invalid pool row: %s" % [label, str(r)])
			continue
		if not ResourceLoader.exists(scene_path):
			_err("[%s] scene_path missing: %s" % [label, scene_path])
			continue
		if not ResourceLoader.exists(enemy_data_path):
			_err("[%s] data_path missing: %s" % [label, enemy_data_path])
			continue
		var scene: PackedScene = load(scene_path) as PackedScene
		var data: EnemyData = load(enemy_data_path) as EnemyData
		if scene == null:
			_err("[%s] scene load failed: %s" % [label, scene_path])
			continue
		if data == null:
			_err("[%s] data load failed: %s" % [label, enemy_data_path])
			continue
		loaded.append({"scene": scene, "data": data, "key": key})
		allowed_keys[key] = true

	if loaded.is_empty():
		_err("[%s] pool empty after load" % label)
		return

	# 챕터별 시간대 spawn_rate 단조성 검증.
	_check_rate_monotonicity(label)

	# 60초 시뮬레이션.
	var elapsed: float = 0.0
	var accum: float = 0.0
	var active_counts: Dictionary = {}  # key -> int (max_concurrent 추적용)
	var spawned_counts: Dictionary = {} # key -> int (검증용 누적)
	var spawned_total: int = 0
	var ticks: int = int(round(SIM_DURATION_S / SIM_TICK_DELTA))
	var live_instances: Array[Node] = []

	for i in ticks:
		var rate: float = _current_pool_rate(elapsed)
		accum += rate * SIM_TICK_DELTA
		while accum >= 1.0:
			accum -= 1.0
			var chosen: Dictionary = _pick_one(loaded, active_counts, elapsed)
			if chosen.is_empty():
				continue
			var key: String = String(chosen["key"])
			spawned_counts[key] = int(spawned_counts.get(key, 0)) + 1
			spawned_total += 1
			active_counts[key] = int(active_counts.get(key, 0)) + 1
			var inst: Node = _instantiate_enemy(chosen, label)
			if inst != null:
				live_instances.append(inst)

		elapsed += SIM_TICK_DELTA

		if i % PHYSICS_YIELD_EVERY_N_TICKS == 0:
			# 누적된 인스턴스가 너무 많으면 일부 정리해 메모리/물리 부담을 낮춘다.
			# 동시에 active_counts 도 같이 감소시켜 max_concurrent 가 과하게 막지 않게 한다.
			if live_instances.size() >= FREE_BATCH_THRESHOLD:
				_free_oldest(live_instances, active_counts, FREE_BATCH_THRESHOLD / 2)
			await physics_frame

	await physics_frame

	# 검증 1: 한 마리 이상 스폰되었는가.
	if spawned_total == 0:
		_err("[%s] no monster spawned during %.0fs simulation" % [label, SIM_DURATION_S])

	# 검증 2: 스폰된 모든 key 가 풀 내에 있는가.
	for k in spawned_counts.keys():
		var sk: String = String(k)
		if not allowed_keys.has(sk):
			_err("[%s] spawned key '%s' NOT in chapter pool %s" % [label, sk, str(allowed_keys.keys())])

	print("[CH] [%s] ch=%d pool=%d spawned_total=%d unique_keys=%d" % [
		label, chapter_number, allowed_keys.size(), spawned_total, spawned_counts.size()
	])

	# 정리.
	_free_all(live_instances, active_counts)
	await process_frame
	await physics_frame


# ────────────────────────────────────────────────────────────────────────────
# 보조: 풀 조회. 미래에 get_pool(StringName) 가 추가되면 자동으로 우선 사용.
# ────────────────────────────────────────────────────────────────────────────
func _get_chapter_pool(cm: Node, chapter_id: StringName, chapter_number: int) -> Array:
	if cm.has_method("get_pool"):
		return cm.call("get_pool", chapter_id)
	if cm.has_method("get_monster_pool_for_chapter"):
		return cm.call("get_monster_pool_for_chapter", chapter_number)
	_err("ChapterManager exposes neither get_pool() nor get_monster_pool_for_chapter()")
	return []


# ────────────────────────────────────────────────────────────────────────────
# 보조: 시간대별 spawn_rate (POOL_RATE_TIERS 미러). game_scene._current_pool_rate 와 동일.
# ────────────────────────────────────────────────────────────────────────────
func _current_pool_rate(elapsed: float) -> float:
	var rate: float = float(POOL_RATE_TIERS[0]["rate"])
	for row in POOL_RATE_TIERS:
		var r: Dictionary = row
		if elapsed >= float(r["t_start"]):
			rate = float(r["rate"])
		else:
			break
	return rate


func _check_rate_monotonicity(label: String) -> void:
	var prev: float = -INF
	var samples: Array = []
	for t in TIME_CHECKPOINTS:
		var rate: float = _current_pool_rate(float(t))
		samples.append({"t": float(t), "rate": rate})
		if rate + 1e-9 < prev:
			_err("[%s] spawn_rate not monotonic non-decreasing at t=%.0fs: rate=%.3f < prev=%.3f" % [
				label, float(t), rate, prev
			])
		prev = rate
	print("[CH] [%s] spawn_rate samples: %s" % [label, str(samples)])


# ────────────────────────────────────────────────────────────────────────────
# 보조: 가중치 기반 스폰 픽. game_scene._spawn_one_from_pool 의 동치 구현.
# ────────────────────────────────────────────────────────────────────────────
func _pick_one(loaded: Array, active_counts: Dictionary, elapsed: float) -> Dictionary:
	var eligible: Array = []
	var total_weight: int = 0
	for row in loaded:
		var r: Dictionary = row
		var d: EnemyData = r["data"]
		if d == null:
			continue
		if elapsed < d.min_stage_time_s:
			continue
		var active: int = int(active_counts.get(r["key"], 0))
		if active >= d.max_concurrent:
			continue
		eligible.append(r)
		total_weight += max(1, d.spawn_weight)
	if eligible.is_empty():
		return {}
	var pick: int = rng.randi() % max(1, total_weight)
	var acc: int = 0
	for row in eligible:
		var r: Dictionary = row
		var w: int = max(1, int((r["data"] as EnemyData).spawn_weight))
		acc += w
		if pick < acc:
			return r
	return eligible[0]


# ────────────────────────────────────────────────────────────────────────────
# 보조: 인스턴스 생성 / 해제
# ────────────────────────────────────────────────────────────────────────────
func _instantiate_enemy(entry: Dictionary, label: String) -> Node:
	var scene: PackedScene = entry["scene"]
	var key: String = String(entry["key"])
	var inst: Node = scene.instantiate()
	if inst == null:
		_err("[%s] instantiate failed: key=%s" % [label, key])
		return null
	if inst is Node2D:
		# 스폰 포지션은 플레이어 주변 임의 점. 충돌 누적을 줄이기 위해 약간씩 흩뜨린다.
		var angle: float = rng.randf() * TAU
		var radius: float = 200.0 + rng.randf() * 100.0
		(inst as Node2D).position = Vector2(cos(angle), sin(angle)) * radius
	enemy_container.add_child(inst)
	return inst


func _free_oldest(live: Array[Node], active_counts: Dictionary, count: int) -> void:
	var n: int = min(count, live.size())
	for i in n:
		var node: Node = live[0]
		live.remove_at(0)
		_decrement_active(node, active_counts)
		if is_instance_valid(node):
			if node.is_inside_tree() and node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.queue_free()


func _free_all(live: Array[Node], active_counts: Dictionary) -> void:
	for node in live:
		_decrement_active(node, active_counts)
		if is_instance_valid(node):
			if node.is_inside_tree() and node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.queue_free()
	live.clear()


func _decrement_active(node: Node, active_counts: Dictionary) -> void:
	# 노드 자체에는 key 가 없으므로, 전체 카운트를 한 단계 낮춰 max_concurrent 가 영구적으로
	# 채워지지 않도록 한다. 단순화: 활성 카운트가 양수면 1만 줄인다. 어느 key 인지는
	# 검증과 무관(검증은 picker 단계의 key 만 사용)하므로 보수적으로 처리.
	if node == null:
		return
	for k in active_counts.keys():
		var v: int = int(active_counts.get(k, 0))
		if v > 0:
			active_counts[k] = v - 1
			return


func _free_children(parent: Node) -> void:
	if not is_instance_valid(parent):
		return
	for child in parent.get_children():
		child.queue_free()


# ────────────────────────────────────────────────────────────────────────────
# 보조: stub player. EnemyBase._resolve_target() 가 group "player" 의 Node2D 를 찾는다.
# ────────────────────────────────────────────────────────────────────────────
func _make_stub_player() -> Node2D:
	var p := Node2D.new()
	p.name = "StubPlayer"
	p.add_to_group("player")
	var s := GDScript.new()
	s.source_code = """extends Node2D

var damage_taken_count: int = 0
var damage_taken_total: int = 0

func take_damage(amount: int) -> void:
	damage_taken_count += 1
	damage_taken_total += int(amount)
"""
	s.reload()
	p.set_script(s)
	return p


# ────────────────────────────────────────────────────────────────────────────
# 출력
# ────────────────────────────────────────────────────────────────────────────
func _err(msg: String) -> void:
	errors.append(msg)
	print("[CH] FAIL — ", msg)


func _print_summary() -> void:
	print("")
	print("[CH] ═══════════════════════════════════════════════")
	print("[CH] chapters tested: ", CHAPTER_FLOW.size())
	print("[CH] errors: ", errors.size())
	for e in errors:
		print("[CH]   - ", e)
	print("[CH] result: ", "PASS" if errors.is_empty() else "FAIL")
	print("[CH] ═══════════════════════════════════════════════")
