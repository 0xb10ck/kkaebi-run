extends SceneTree

# tests/test_environment_events.gd — 환경 5종 + 랜덤 이벤트 7종 검증 (Godot 4 headless).
# 실행:
#   godot --headless --path /Users/0xb10ck/kkaebi-run --script tests/test_environment_events.gd
#
# 검증 항목
#   1) 환경 5종(env_fog / env_poison_marsh / env_thornbush / env_spirit_altar /
#      env_talisman_pillar) 각각을 강제 트리거하여 플레이어 stats 변화를 측정.
#      지속시간/사용 종료 시점에서 원래 값으로 원복(또는 env_exited 발신)되는지 확인.
#   2) 랜덤 이벤트 7종(blood_moon / demon_curse / goblin_market / invisible_cap /
#      spirit_blessing / treasure_chest / wandering_dokkaebi) 트리거 시
#      EventBus.random_event_triggered 발화 + 종료 시점에서 종료 시그널/상태 복원 확인.
#
# push_error 는 SCRIPT ERROR 로 집계되므로 print() 만 사용한다.


class MockPlayer extends Node2D:
	signal hp_changed(hp: int, max_hp: int)
	var max_hp: int = 100
	var hp: int = 100
	var move_speed_mult: float = 1.0
	var invincible: bool = false
	var slow_factor: float = 1.0
	var slow_until: float = 0.0
	var stun_remaining: float = 0.0

	func _ready() -> void:
		add_to_group("player")

	func take_damage(amount: int) -> void:
		if invincible:
			return
		hp = max(0, hp - amount)
		hp_changed.emit(hp, max_hp)

	func apply_slow(factor: float, duration: float) -> void:
		slow_factor = factor
		slow_until = Time.get_unix_time_from_system() + duration

	func apply_stun(duration: float) -> void:
		stun_remaining = duration


var errors: Array[String] = []
var passes: int = 0

# Captured EventBus signal payloads.
var _env_entered_log: Array = []
var _env_exited_log: Array = []
var _random_event_log: Array = []
var _toast_log: Array = []
var _player_healed_log: Array = []

# Saved GameState fields to restore after tests that mutate autoloads.
var _saved_attack: int = 0
var _saved_gold: int = 0

var _player: MockPlayer
var _holder: Node
var _bus: Node            # EventBus autoload — 런타임 노드 조회
var _game_state: Node     # GameState autoload


func _initialize() -> void:
	# 자동로드 _ready() 가 끝난 첫 프레임에 진입.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_setup_world()
	_test_environments()
	_test_random_events()
	_teardown_world()
	_print_summary()
	quit(0 if errors.is_empty() else 1)


# ───────────────────────────────────────────────────────────────────────────
# Setup / Teardown
# ───────────────────────────────────────────────────────────────────────────

func _setup_world() -> void:
	# 오토로드는 --script 실행 컨텍스트에서 식별자로 접근이 불가능하므로
	# 런타임에 root 의 자식 노드로 조회한다.
	_bus = root.get_node("EventBus")
	_game_state = root.get_node("GameState")

	_holder = Node.new()
	_holder.name = "TestHolder"
	root.add_child(_holder)
	# 일부 이벤트가 get_tree().current_scene.add_child(...) 를 호출하므로
	# 테스트 전용 루트를 current_scene 으로 지정한다.
	current_scene = _holder

	_player = MockPlayer.new()
	_player.name = "MockPlayer"
	_holder.add_child(_player)

	# EventBus 신호 캡처.
	_bus.environment_entered.connect(_on_env_entered)
	_bus.environment_exited.connect(_on_env_exited)
	_bus.random_event_triggered.connect(_on_random_event)
	_bus.toast_requested.connect(_on_toast)
	_bus.player_healed.connect(_on_player_healed)

	# GameState 필드 백업.
	_saved_attack = int(_game_state.attack) if "attack" in _game_state else 0
	_saved_gold = int(_game_state.gold) if "gold" in _game_state else 0


func _teardown_world() -> void:
	if _bus and _bus.environment_entered.is_connected(_on_env_entered):
		_bus.environment_entered.disconnect(_on_env_entered)
	if _bus and _bus.environment_exited.is_connected(_on_env_exited):
		_bus.environment_exited.disconnect(_on_env_exited)
	if _bus and _bus.random_event_triggered.is_connected(_on_random_event):
		_bus.random_event_triggered.disconnect(_on_random_event)
	if _bus and _bus.toast_requested.is_connected(_on_toast):
		_bus.toast_requested.disconnect(_on_toast)
	if _bus and _bus.player_healed.is_connected(_on_player_healed):
		_bus.player_healed.disconnect(_on_player_healed)

	# GameState 복원.
	if _game_state and "attack" in _game_state:
		_game_state.attack = _saved_attack
	if _game_state and "gold" in _game_state:
		_game_state.gold = _saved_gold

	if is_instance_valid(_holder):
		_holder.queue_free()


func _on_env_entered(env_id: StringName, _pos: Vector2) -> void:
	_env_entered_log.append(env_id)

func _on_env_exited(env_id: StringName, _pos: Vector2) -> void:
	_env_exited_log.append(env_id)

func _on_random_event(event_id: StringName, _payload: Dictionary) -> void:
	_random_event_log.append(event_id)

func _on_toast(text: String, _duration: float) -> void:
	_toast_log.append(text)

func _on_player_healed(amount: int, _source: StringName) -> void:
	_player_healed_log.append(amount)


func _reset_logs() -> void:
	_env_entered_log.clear()
	_env_exited_log.clear()
	_random_event_log.clear()
	_toast_log.clear()
	_player_healed_log.clear()


func _reset_player() -> void:
	_player.hp = _player.max_hp
	_player.move_speed_mult = 1.0
	_player.invincible = false
	_player.slow_factor = 1.0


# ───────────────────────────────────────────────────────────────────────────
# 환경 5종
# ───────────────────────────────────────────────────────────────────────────

func _test_environments() -> void:
	_section("[ENVIRONMENTS]")
	_test_env_fog()
	_test_env_poison_marsh()
	_test_env_thornbush()
	_test_env_spirit_altar()
	_test_env_talisman_pillar()


func _test_env_fog() -> void:
	_section("env_fog")
	_reset_logs()
	_reset_player()

	var FogScript: GDScript = load("res://scripts/environment/environment_fog.gd")
	var fog: Node = FogScript.new()
	_holder.add_child(fog)

	# Baseline before player enters.
	var detect_baseline: float = 1.0 - float(fog.DETECT_REDUCTION)
	_expect(fog.get_vision_multiplier() == 1.0, "env_fog: vision baseline == 1.0")
	_expect(fog.get_range_multiplier() == 1.0, "env_fog: range baseline == 1.0")
	_expect(is_equal_approx(fog.get_detect_multiplier(), detect_baseline),
			"env_fog: detect baseline == %.2f" % detect_baseline)

	# Force trigger entry — vision / range multipliers drop.
	fog._on_body_entered(_player)
	_expect(_env_entered_log.has(&"env_fog"), "env_fog: env_entered signal fired on entry")
	var vision_inside: float = 1.0 - float(fog.VISION_REDUCTION)
	var range_inside: float = 1.0 - float(fog.RANGE_REDUCTION)
	_expect(is_equal_approx(fog.get_vision_multiplier(), vision_inside),
			"env_fog: vision == %.2f inside" % vision_inside)
	_expect(is_equal_approx(fog.get_range_multiplier(), range_inside),
			"env_fog: range == %.2f inside" % range_inside)

	# Player exits — multipliers revert to baseline.
	fog._on_body_exited(_player)
	_expect(_env_exited_log.has(&"env_fog"), "env_fog: env_exited signal fired on exit")
	_expect(fog.get_vision_multiplier() == 1.0, "env_fog: vision restored to 1.0 after exit")
	_expect(fog.get_range_multiplier() == 1.0, "env_fog: range restored to 1.0 after exit")

	# clear_for(duration) — detect multiplier rises to 1.0; expiry reverts to baseline.
	fog._on_body_entered(_player)
	fog.clear_for(60.0)
	_expect(fog.get_detect_multiplier() == 1.0, "env_fog: detect == 1.0 while cleared")
	# 지속시간 만료 시뮬레이션 — _cleared_until_unix 를 과거로 강제.
	fog._cleared_until_unix = 0.0
	_expect(is_equal_approx(fog.get_detect_multiplier(), detect_baseline),
			"env_fog: detect reverts to baseline after clear duration expires")

	fog.queue_free()


func _test_env_poison_marsh() -> void:
	_section("env_poison_marsh")
	_reset_logs()
	_reset_player()

	var MarshScript: GDScript = load("res://scripts/environment/environment_poison_marsh.gd")
	var marsh: Node = MarshScript.new()
	_holder.add_child(marsh)

	# Player enters marsh.
	marsh._on_body_entered(_player)
	_expect(_env_entered_log.has(&"env_poison_marsh"),
			"env_poison_marsh: env_entered signal fired on entry")
	_expect(marsh.is_active(), "env_poison_marsh: is_active() before evaporation")

	# Force a tick — player takes TICK_DAMAGE and is slowed.
	var hp_before: int = _player.hp
	marsh._apply_tick()
	_expect(_player.hp == hp_before - int(marsh.TICK_DAMAGE),
			"env_poison_marsh: tick applies %d damage (was %d → %d)" %
				[int(marsh.TICK_DAMAGE), hp_before, _player.hp])
	_expect(is_equal_approx(_player.slow_factor, float(marsh.SLOW_FACTOR)),
			"env_poison_marsh: slow_factor == %.2f after tick" % float(marsh.SLOW_FACTOR))

	# Reset stats and verify evaporate() suspends ticks (지속시간 만료 = 증발 상태).
	_reset_player()
	marsh.evaporate(60.0)
	_expect(not marsh.is_active(),
			"env_poison_marsh: inactive while evaporated (effect cleared)")
	var hp_b: int = _player.hp
	var slow_b: float = _player.slow_factor
	# _process 가 unaktive 분기를 타도 데미지/슬로우가 적용되지 않아야 한다.
	marsh._tick = float(marsh.TICK_INTERVAL) + 1.0
	marsh._process(0.1)
	_expect(_player.hp == hp_b,
			"env_poison_marsh: HP unchanged while evaporated (값 원복)")
	_expect(is_equal_approx(_player.slow_factor, slow_b),
			"env_poison_marsh: slow_factor unchanged while evaporated (값 원복)")

	# 증발 지속시간 만료 → 다시 활성.
	marsh._evaporated_until_unix = 0.0
	_expect(marsh.is_active(),
			"env_poison_marsh: re-active after evaporate duration expires")

	marsh.queue_free()


func _test_env_thornbush() -> void:
	_section("env_thornbush")
	_reset_logs()
	_reset_player()

	var BushScript: GDScript = load("res://scripts/environment/environment_thornbush.gd")
	var bush: Node = BushScript.new()
	_holder.add_child(bush)

	bush._on_body_entered(_player)
	_expect(_env_entered_log.has(&"env_thornbush"),
			"env_thornbush: env_entered signal fired on entry")

	var hp_before: int = _player.hp
	bush._apply_tick()
	var expected_dmg: int = max(1, int(round(float(_player.max_hp) * float(bush.DAMAGE_PCT))))
	_expect(_player.hp == hp_before - expected_dmg,
			"env_thornbush: tick deals %d damage (3%% of max_hp)" % expected_dmg)
	_expect(is_equal_approx(_player.slow_factor, float(bush.SLOW_FACTOR)),
			"env_thornbush: slow_factor == %.2f after tick" % float(bush.SLOW_FACTOR))

	# 5회 공격으로 파괴 — env_exited 발신, 슬로우는 외부 시스템에서 자동 만료(원복) 대상.
	for i in range(int(bush.MAX_HITS)):
		bush.take_damage(1, null)
	_expect(_env_exited_log.has(&"env_thornbush"),
			"env_thornbush: env_exited signal fired on destruction (지속 종료)")


func _test_env_spirit_altar() -> void:
	_section("env_spirit_altar")
	_reset_logs()
	_reset_player()

	var AltarScript: GDScript = load("res://scripts/environment/environment_spirit_altar.gd")
	var altar: Node = AltarScript.new()
	_holder.add_child(altar)

	altar._on_body_entered(_player)
	_expect(_env_entered_log.has(&"env_spirit_altar"),
			"env_spirit_altar: env_entered signal fired on entry")

	var hp_before: int = _player.hp
	var cost: int = max(1, int(round(float(_player.max_hp) * float(altar.HP_COST_PCT_DEFAULT))))
	altar._try_use()
	_expect(_player.hp == hp_before - cost,
			"env_spirit_altar: HP cost %d paid (HP %d → %d)" %
				[cost, hp_before, _player.hp])
	_expect(altar.is_used(),
			"env_spirit_altar: marked as used (한 런 1회 종료)")
	_expect(_env_exited_log.has(&"env_spirit_altar"),
			"env_spirit_altar: env_exited signal fired after use (사용 종료 시그널)")

	altar.queue_free()


func _test_env_talisman_pillar() -> void:
	_section("env_talisman_pillar")
	_reset_logs()
	_reset_player()
	# HP 를 50% 로 낮춰 회복 효과를 측정 가능하게.
	_player.hp = max(1, int(_player.max_hp / 2))

	var PillarScript: GDScript = load("res://scripts/environment/environment_talisman_pillar.gd")
	var pillar: Node = PillarScript.new()
	_holder.add_child(pillar)
	pillar.global_position = Vector2.ZERO

	# 활성 오라 — 반경 안 적의 atk 디버프 활성.
	_expect(pillar.is_in_aura(Vector2(10, 10)),
			"env_talisman_pillar: is_in_aura true near origin (오라 활성)")
	_expect(is_equal_approx(pillar.get_enemy_atk_debuff(), float(pillar.ENEMY_ATK_DEBUFF)),
			"env_talisman_pillar: enemy_atk_debuff == %.2f while active" %
				float(pillar.ENEMY_ATK_DEBUFF))

	var hp_before: int = _player.hp
	for i in range(int(pillar.MAX_HITS)):
		pillar.take_damage(1, null)
	_expect(pillar.is_destroyed(),
			"env_talisman_pillar: destroyed after %d hits" % int(pillar.MAX_HITS))

	var expected_heal: int = max(1, int(round(float(_player.max_hp) * float(pillar.HEAL_PCT))))
	_expect(_player.hp == hp_before + expected_heal,
			"env_talisman_pillar: player healed by %d (HP %d → %d)" %
				[expected_heal, hp_before, _player.hp])
	_expect(_player_healed_log.has(expected_heal),
			"env_talisman_pillar: player_healed signal fired with amount %d" % expected_heal)
	_expect(_env_exited_log.has(&"env_talisman_pillar"),
			"env_talisman_pillar: env_exited signal fired on destruction (지속 종료)")
	# 파괴 후 오라/디버프 원복.
	_expect(pillar.get_enemy_atk_debuff() == 0.0,
			"env_talisman_pillar: enemy_atk_debuff == 0.0 after destruction (값 원복)")
	_expect(not pillar.is_in_aura(Vector2(10, 10)),
			"env_talisman_pillar: is_in_aura false after destruction (값 원복)")


# ───────────────────────────────────────────────────────────────────────────
# 랜덤 이벤트 7종
# ───────────────────────────────────────────────────────────────────────────

func _test_random_events() -> void:
	_section("[RANDOM EVENTS]")
	_test_event_blood_moon()
	_test_event_demon_curse()
	_test_event_goblin_market()
	_test_event_invisible_cap()
	_test_event_spirit_blessing()
	_test_event_treasure_chest()
	_test_event_wandering_dokkaebi()


func _test_event_blood_moon() -> void:
	_section("event_blood_moon")
	_reset_logs()

	var EvScript: GDScript = load("res://scripts/events/event_blood_moon.gd")
	var ev: Node = EvScript.new()
	_holder.add_child(ev)

	ev.trigger()
	_expect(_random_event_log.has(&"event_blood_moon"),
			"event_blood_moon: random_event_triggered 발화 (효과 시그널)")
	_expect(_env_entered_log.has(&"env_blood_moon"),
			"event_blood_moon: env_entered env_blood_moon 발화 at start")
	_expect(ev.is_active(), "event_blood_moon: is_active() == true")

	# 60초 지속시간 만료 시뮬레이션 — _end() 직접 호출.
	ev._end()
	_expect(not ev.is_active(), "event_blood_moon: is_active() == false after _end")
	_expect(_env_exited_log.has(&"env_blood_moon"),
			"event_blood_moon: env_exited env_blood_moon 발화 (종료 시그널)")

	ev.queue_free()


func _test_event_demon_curse() -> void:
	_section("event_demon_curse")
	_reset_logs()

	var EvScript: GDScript = load("res://scripts/events/event_demon_curse.gd")
	var ev: Node = EvScript.new()
	_holder.add_child(ev)

	ev.trigger()
	_expect(_random_event_log.has(&"event_demon_curse"),
			"event_demon_curse: random_event_triggered 발화 (효과 시그널)")

	# fog 선택지 — env_entered env_fog_curse 발화.
	ev.apply_choice(&"fog")
	_expect(_env_entered_log.has(&"env_fog_curse"),
			"event_demon_curse: env_entered env_fog_curse on fog choice")
	_expect(ev.is_active(), "event_demon_curse: is_active() after fog choice")

	# 지속시간 만료 시뮬레이션.
	ev._resolve()
	_expect(_env_exited_log.has(&"env_fog_curse"),
			"event_demon_curse: env_exited env_fog_curse at resolve (종료 시그널)")
	_expect(not ev.is_active(), "event_demon_curse: is_active() == false after resolve")

	ev.queue_free()


func _test_event_goblin_market() -> void:
	_section("event_goblin_market")
	_reset_logs()

	var EvScript: GDScript = load("res://scripts/events/event_goblin_market.gd")
	var ev: Node = EvScript.new()
	_holder.add_child(ev)

	ev.trigger()
	_expect(_random_event_log.has(&"event_goblin_market"),
			"event_goblin_market: random_event_triggered 발화 (효과 시그널)")
	_expect(is_instance_valid(ev._entity),
			"event_goblin_market: 상인 엔티티 스폰됨")

	# 30초 수명 만료 시뮬레이션 — _expire() 직접 호출.
	var entity_ref: Node2D = ev._entity
	ev._expire()
	# queue_free 는 프레임 끝에 처리 — is_queued_for_deletion 으로 즉시 확인.
	_expect(entity_ref.is_queued_for_deletion(),
			"event_goblin_market: 엔티티가 _expire 후 queue_free 됨 (종료)")

	ev.queue_free()


func _test_event_invisible_cap() -> void:
	_section("event_invisible_cap")
	_reset_logs()
	_reset_player()

	var EvScript: GDScript = load("res://scripts/events/event_invisible_cap.gd")
	var ev: Node = EvScript.new()
	_holder.add_child(ev)

	ev.trigger()
	_expect(_random_event_log.has(&"event_invisible_cap"),
			"event_invisible_cap: random_event_triggered 발화 (효과 시그널)")

	# 즉시 사용 — 투명/무적 활성.
	ev.apply_choice(&"use_now")
	_expect(ev.is_stealth_active(), "event_invisible_cap: stealth 활성")
	_expect(_player.invincible, "event_invisible_cap: 플레이어 invincible == true")
	_expect(_player.is_in_group("stealth"), "event_invisible_cap: 플레이어 stealth 그룹")

	# 10초 지속 만료 시뮬레이션.
	_toast_log.clear()
	ev._end_stealth()
	_expect(not ev.is_stealth_active(),
			"event_invisible_cap: stealth 비활성 after _end_stealth")
	_expect(not _player.invincible,
			"event_invisible_cap: invincible 원복 == false")
	_expect(not _player.is_in_group("stealth"),
			"event_invisible_cap: 플레이어 stealth 그룹 원복")
	_expect(_toast_log.size() > 0,
			"event_invisible_cap: toast_requested 발화 (종료 시그널)")
	_expect(is_equal_approx(_player.slow_factor, float(ev.POST_STEALTH_SLOW_FACTOR)),
			"event_invisible_cap: 종료 직후 1초 슬로우 적용")

	ev.queue_free()


func _test_event_spirit_blessing() -> void:
	_section("event_spirit_blessing")
	_reset_logs()
	_reset_player()

	var EvScript: GDScript = load("res://scripts/events/event_spirit_blessing.gd")
	var ev: Node = EvScript.new()
	_holder.add_child(ev)

	ev.trigger()
	_expect(_random_event_log.has(&"event_spirit_blessing"),
			"event_spirit_blessing: random_event_triggered 발화 (효과 시그널)")

	# ms_up 선택 — 플레이어 이속 배율 *1.40.
	var ms_before: float = _player.move_speed_mult
	ev.apply_choice(&"ms_up")
	_expect(is_equal_approx(_player.move_speed_mult, ms_before * float(ev.MS_BUFF_MULT)),
			"event_spirit_blessing: move_speed_mult *%.2f 적용" % float(ev.MS_BUFF_MULT))

	# 60초 지속시간 만료 — _end_buff() 직접 호출 시 원복.
	ev._end_buff()
	_expect(is_equal_approx(_player.move_speed_mult, ms_before),
			"event_spirit_blessing: move_speed_mult 원복 after _end_buff (종료)")
	_expect(is_equal_approx(_player.slow_factor, 0.05),
			"event_spirit_blessing: 종료 직후 1초 행동 불가 슬로우(0.05) 적용 (종료 효과)")

	ev.queue_free()


func _test_event_treasure_chest() -> void:
	_section("event_treasure_chest")
	_reset_logs()
	_reset_player()
	# 풀 HP 로 — normal 의 "HP 풀회복" 분기가 0 회복으로 끝나도 충돌 없음.
	_player.hp = _player.max_hp

	var EvScript: GDScript = load("res://scripts/events/event_treasure_chest.gd")
	var ev: Node = EvScript.new()
	_holder.add_child(ev)

	ev.trigger()
	_expect(_random_event_log.has(&"event_treasure_chest"),
			"event_treasure_chest: random_event_triggered 발화 (효과 시그널)")
	_expect(is_instance_valid(ev._entity),
			"event_treasure_chest: 상자 엔티티 스폰됨")

	# 결정적 결과를 위해 chest_type 을 normal 로 고정하고 _on_opened 직접 호출.
	# (개봉 = 보물상자 이벤트의 "종료" 분기 — 토스트 시그널 발화 + 엔티티 free.)
	ev._chest_type = &"normal"
	var entity_ref: Node2D = ev._entity
	_toast_log.clear()
	ev._on_opened()
	_expect(_toast_log.size() > 0,
			"event_treasure_chest: 개봉 시 toast_requested 발화 (종료 시그널)")
	_expect(entity_ref.is_queued_for_deletion(),
			"event_treasure_chest: 개봉 후 엔티티 queue_free (종료)")

	ev.queue_free()


func _test_event_wandering_dokkaebi() -> void:
	_section("event_wandering_dokkaebi")
	_reset_logs()
	_reset_player()

	var EvScript: GDScript = load("res://scripts/events/event_wandering_dokkaebi.gd")
	var ev: Node = EvScript.new()
	_holder.add_child(ev)

	ev.trigger()
	_expect(_random_event_log.has(&"event_wandering_dokkaebi"),
			"event_wandering_dokkaebi: random_event_triggered 발화 (효과 시그널)")
	_expect(is_instance_valid(ev._entity),
			"event_wandering_dokkaebi: 도깨비 엔티티 스폰됨")

	# 30초 수명 만료 시뮬레이션 — _on_timeout() 직접 호출.
	var entity_ref: Node2D = ev._entity
	_toast_log.clear()
	ev._on_timeout()
	_expect(_toast_log.size() > 0,
			"event_wandering_dokkaebi: 타임아웃 시 toast_requested 발화 (종료 시그널)")
	_expect(entity_ref.is_queued_for_deletion(),
			"event_wandering_dokkaebi: 타임아웃 후 엔티티 queue_free (종료)")

	ev.queue_free()


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


func _section(name: String) -> void:
	print("")
	print("── %s ──" % name)


func _print_summary() -> void:
	print("")
	print("-- test_environment_events summary --")
	print("PASS: %d" % passes)
	print("FAIL: %d" % errors.size())
	if not errors.is_empty():
		print("Failed checks:")
		for e in errors:
			print("  - %s" % e)
