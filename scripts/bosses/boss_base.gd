class_name BossBase
extends CharacterBody2D

# §5.1 — 11종 보스 공통 베이스. 페이즈 전환(HP 비율) + 패턴 큐 + 텔레그래프 hook + 컷인 hook.
# 실제 패턴/이펙트는 서브클래스가 _execute_pattern() 등 hook을 오버라이드해서 구현.

@export var data: BossData

# === 시그널 ===
signal intro_finished
signal pattern_executed(pattern_id: StringName)
signal phase_changed(new_index: int)
signal died(boss_id: StringName)
# AC5 명세 표면: telegraph 진입 시 발신.
signal telegraph_signal(pattern_id: StringName, duration_s: float)

# === 런타임 상태 ===
var current_phase_index: int = 0
var current_phase: BossPhase
var current_hp: int = 0
var last_pattern_id: StringName = &""
var pattern_cooldowns: Dictionary = {}
var fsm_state: StringName = &"intro"  # intro|idle|telegraph|pattern|recover|transition|dying
var fsm_timer: float = 0.0
var spawn_time: float = 0.0
var no_hit: bool = true
var invuln: bool = true

var _idle_target_s: float = 0.0
var _pending_pattern: BossPattern
var _telegraph_total_s: float = 0.0
var _pattern_remaining_s: float = 0.0

# AC5 명세 표면: 페이즈별 HP 임계 캐시. _ready에서 data.phases로부터 채운다.
var phase_thresholds: Array[float] = []

@onready var sprite: Node = get_node_or_null("Sprite")
@onready var hurtbox: Node = get_node_or_null("HurtBox")
@onready var telegraph_layer: Node2D = _ensure_telegraph_layer()
@onready var pattern_anchor: Node2D = _ensure_pattern_anchor()


func _ready() -> void:
	if data == null:
		push_warning("BossBase: data is null; boss will be inert")
		return
	_apply_data(data)
	if data.phases.size() > 0:
		current_phase = data.phases[0]
	current_hp = data.hp
	spawn_time = Time.get_unix_time_from_system()
	# AC5: phase_thresholds 캐시 — data.phases의 hp_threshold_percent를 미리 모아둔다.
	phase_thresholds = []
	for phase in data.phases:
		if phase == null:
			continue
		phase_thresholds.append(phase.hp_threshold_percent)
	_play_intro_cutscene()


# AC5 명세 표면: 컷인 진입점. 외부에서 동일 의미로 호출 가능.
func cutscene_hook() -> void:
	_play_intro_cutscene()


func _physics_process(delta: float) -> void:
	if data == null:
		return
	fsm_timer += delta
	match String(fsm_state):
		"intro": _tick_intro(delta)
		"idle": _tick_idle(delta)
		"telegraph": _tick_telegraph(delta)
		"pattern": _tick_pattern(delta)
		"recover": _tick_recover(delta)
		"transition": _tick_transition(delta)
		"dying": _tick_dying(delta)


# === 라이프사이클 hooks ===

func _apply_data(_d: BossData) -> void:
	# 서브클래스가 sprite/animation 적용. 베이스는 무동작.
	pass


func _play_intro_cutscene() -> void:
	var c: Node = CutsceneRegistry.spawn(data.intro_cutscene_id) if data.intro_cutscene_id != &"" else null
	if c != null:
		add_child(c)
		if c.has_method("play"):
			c.call("play")
		if c.has_signal("finished"):
			c.connect("finished", _on_intro_finished, CONNECT_ONE_SHOT)
		else:
			_on_intro_finished()
	else:
		# 컷인 없음 — 즉시 idle.
		_on_intro_finished()


func _on_intro_finished() -> void:
	intro_finished.emit()
	fsm_state = &"idle"
	fsm_timer = 0.0
	invuln = false
	_pick_next_idle_target()


# === idle / telegraph / pattern ===

func _tick_intro(_delta: float) -> void:
	# 컷인 신호가 _on_intro_finished를 호출하므로 본 tick에서는 안전 타임아웃만.
	if fsm_timer >= max(0.5, data.intro_duration_s + 1.5):
		_on_intro_finished()


func _tick_idle(_delta: float) -> void:
	if _check_phase_transition():
		return
	if fsm_timer < _idle_target_s:
		return
	var next: BossPattern = _select_next_pattern()
	if next == null:
		_pick_next_idle_target()
		fsm_timer = 0.0
		return
	_pending_pattern = next
	_telegraph_total_s = next.telegraph_duration_s
	fsm_state = &"telegraph"
	fsm_timer = 0.0
	_emit_telegraph(next)
	EventBus.boss_pattern_telegraphed.emit(next.id, _telegraph_total_s)


func _tick_telegraph(_delta: float) -> void:
	if fsm_timer < _telegraph_remaining():
		return
	fsm_state = &"pattern"
	fsm_timer = 0.0
	_pattern_remaining_s = 0.2  # 기본 판정 윈도우 — 서브클래스 _execute_pattern 안에서 조정 가능.
	EventBus.boss_pattern_started.emit(data.id, _pending_pattern.id)
	_execute_pattern(_pending_pattern)
	last_pattern_id = _pending_pattern.id
	pattern_cooldowns[_pending_pattern.id] = Time.get_unix_time_from_system() + _pending_pattern.cooldown_s
	pattern_executed.emit(_pending_pattern.id)


func _tick_pattern(_delta: float) -> void:
	if fsm_timer < _pattern_remaining_s:
		return
	fsm_state = &"recover"
	fsm_timer = 0.0


func _tick_recover(_delta: float) -> void:
	if fsm_timer < 0.2:
		return
	if _check_phase_transition():
		return
	_pick_next_idle_target()
	fsm_state = &"idle"
	fsm_timer = 0.0


func _telegraph_remaining() -> float:
	return max(0.0, _telegraph_total_s)


func _pick_next_idle_target() -> void:
	if current_phase == null:
		_idle_target_s = 1.0
		return
	_idle_target_s = randf_range(current_phase.idle_min_s, current_phase.idle_max_s)


# === 패턴 선택 (가중치 + 직전 -50%) ===

func _select_next_pattern() -> BossPattern:
	if current_phase == null:
		return null
	var now: float = Time.get_unix_time_from_system()
	var candidates: Array = []
	var weights: Array = []
	for p in current_phase.pattern_queue:
		var ready_at: float = float(pattern_cooldowns.get(p.id, 0.0))
		if ready_at > now:
			continue
		var w: int = max(1, p.weight)
		if p.id == last_pattern_id:
			w = max(1, int(w * 0.5))
		candidates.append(p)
		weights.append(w)
	if candidates.is_empty():
		return null
	return candidates[_weighted_random_index(weights)]


func _weighted_random_index(weights: Array) -> int:
	var total: int = 0
	for w in weights:
		total += int(w)
	if total <= 0:
		return 0
	var roll: int = randi() % total
	var cum: int = 0
	for i in weights.size():
		cum += int(weights[i])
		if roll < cum:
			return i
	return weights.size() - 1


# === 페이즈 전환 ===

func _check_phase_transition() -> bool:
	if data == null:
		return false
	if current_phase_index + 1 >= data.phases.size():
		return false
	var next: BossPhase = data.phases[current_phase_index + 1]
	var hp_ratio: float = 1.0
	if data.hp > 0:
		hp_ratio = float(current_hp) / float(data.hp)
	var due: bool = false
	match data.phase_transition_mode:
		GameEnums.BossPhaseTransition.HP_THRESHOLD:
			due = hp_ratio <= next.hp_threshold_percent
		GameEnums.BossPhaseTransition.HP_AND_TIME:
			due = hp_ratio <= next.hp_threshold_percent or fsm_timer >= next.time_threshold_s
		GameEnums.BossPhaseTransition.TIMED_ONLY:
			due = (Time.get_unix_time_from_system() - spawn_time) >= next.time_threshold_s
		GameEnums.BossPhaseTransition.SCRIPTED:
			due = _scripted_transition_due(current_phase_index + 1)
	if due:
		_begin_phase_transition(current_phase_index + 1)
	return due


func _begin_phase_transition(new_index: int) -> void:
	fsm_state = &"transition"
	invuln = true
	fsm_timer = 0.0
	EventBus.boss_phase_changed.emit(data.id, new_index)
	phase_changed.emit(new_index)
	_on_phase_transition_started(new_index)
	if current_phase:
		_spawn_transition_vfx(current_phase.transition_vfx_id)
		_camera_shake(current_phase.transition_camera_shake)


func _tick_transition(_delta: float) -> void:
	var dur: float = current_phase.transition_invuln_s if current_phase else 1.5
	if fsm_timer < dur:
		return
	current_phase_index += 1
	current_phase = data.phases[current_phase_index]
	invuln = false
	fsm_state = &"idle"
	fsm_timer = 0.0
	_pick_next_idle_target()
	_on_phase_transition_completed(current_phase_index)


# === 피격 / 사망 ===

func take_damage(amount: int, source: StringName = &"") -> void:
	if invuln or data == null:
		return
	if source != &"":
		no_hit = false
	var final_dmg: int = max(1, amount - int(data.armor * 0.7))
	current_hp -= final_dmg
	if current_hp <= 0:
		_die()
	else:
		_check_phase_transition()


func _die() -> void:
	fsm_state = &"dying"
	invuln = true
	fsm_timer = 0.0
	var time_taken: float = Time.get_unix_time_from_system() - spawn_time
	died.emit(data.id)
	EventBus.boss_defeated.emit(data.id, time_taken, no_hit)


func _tick_dying(_delta: float) -> void:
	if fsm_timer < data.death_cutscene_duration_s:
		return
	queue_free()


# === 텔레그래프 / 카메라 hook (서브클래스 오버라이드 가능) ===

func emit_telegraph(p: BossPattern) -> void:
	_emit_telegraph(p)


func _emit_telegraph(p: BossPattern) -> void:
	# AC5: telegraph 진입 시 telegraph_signal 발신.
	telegraph_signal.emit(p.id, p.telegraph_duration_s)
	if telegraph_layer == null:
		return
	var t: Telegraph = Telegraph.new()
	t.vfx_kind = p.telegraph_vfx_id if p.telegraph_vfx_id != &"" else &"red_circle"
	t.duration_s = p.telegraph_duration_s
	t.radius_px = p.hitbox_radius_px
	t.length_px = p.hitbox_length_px
	t.angle_deg = p.hitbox_angle_deg
	telegraph_layer.add_child(t)
	t.expired.connect(func() -> void:
		if is_instance_valid(t):
			t.queue_free())
	t.start()


func _spawn_transition_vfx(_vfx_id: StringName) -> void:
	# 서브클래스가 페이즈 전환 이펙트를 스폰. 베이스는 무동작.
	pass


func _camera_shake(_strength: float) -> void:
	# 카메라 셰이크. 베이스는 무동작 — 카메라가 노출되면 서브클래스가 처리.
	pass


# === 추상 hook (서브클래스가 오버라이드) ===

func _on_phase_transition_started(_new_index: int) -> void:
	pass


func _on_phase_transition_completed(_new_index: int) -> void:
	pass


func _execute_pattern(_pattern: BossPattern) -> void:
	# 서브클래스가 shape별 디스패치(원형/직선/콘/투사체)로 데미지 판정 수행.
	pass


func _scripted_transition_due(_next_index: int) -> bool:
	return false


# === 내부 ===

func _ensure_telegraph_layer() -> Node2D:
	var n: Node = get_node_or_null("TelegraphLayer")
	if n is Node2D:
		return n
	var layer: Node2D = Node2D.new()
	layer.name = "TelegraphLayer"
	add_child(layer)
	return layer


func _ensure_pattern_anchor() -> Node2D:
	var n: Node = get_node_or_null("PatternAnchor")
	if n is Node2D:
		return n
	var anchor: Node2D = Node2D.new()
	anchor.name = "PatternAnchor"
	add_child(anchor)
	return anchor
