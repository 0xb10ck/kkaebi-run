class_name EventManager
extends Node

# meta-systems-spec §4 — 런 내 랜덤 이벤트 매니저.
# 7종 이벤트를 통일된 인터페이스로 등록(register)하고, 가중치 추첨(roll)으로
# 활성화한다. 같은 이벤트 최대 2회, 보스 1분 전 ~ 보스전 중 미발동 등 공통
# 발동 룰을 처리한다.
#
# 등록 인터페이스(§4 공통 사양):
#   register(event_id: StringName, weight: float, condition_fn: Callable, event: EventBase)
#
# - weight 는 §4.2 의 % 값(22.0 == 22%). 추첨 시 100 으로 나누어 확률로 본다.
# - condition_fn(chapter, time_s, hp_pct, history) -> bool 가 false면 풀에서 제외.
# - event 는 EventBase 인스턴스. 추첨 후 trigger() 가 호출된다.
#
# 자동로드 의무 없음: 게임 씬 루트에서 add_child 로 붙여 쓰면 충분하다.

const ROLL_INTERVAL_DEFAULT: float = 60.0          # 평균 8분 챕터 / 평균 2~3회 → 약 60s 주기
const BOSS_LOCKOUT_BEFORE_S: float = 60.0          # 보스 등장 1분 전부터 미발동
const HISTORY_MAX_DEFAULT: int = 2                  # §4.1: 같은 이벤트 최대 2회


# 단일 등록 엔트리.
class EventEntry:
	var id: StringName
	var weight: float
	var condition_fn: Callable
	var event: EventBase
	var max_per_run: int = HISTORY_MAX_DEFAULT

	func _init(p_id: StringName, p_weight: float, p_cond: Callable, p_event: EventBase) -> void:
		id = p_id
		weight = p_weight
		condition_fn = p_cond
		event = p_event
		if p_event != null:
			max_per_run = p_event.get_max_per_run()


# event_id -> EventEntry
var _entries: Dictionary = {}

# event_id -> int (한 런에서 발동된 횟수)
var _history: Dictionary = {}

# 보스 등장 예정 절대 시각(초). 0 이면 lockout 비활성.
var _boss_window_start_s: float = 0.0
var _boss_window_end_s: float = 0.0

# 현재 챕터 / 챕터 경과 시간(초).
var _current_chapter: int = 1
var _chapter_elapsed_s: float = 0.0
var _enabled: bool = true

# 자동 추첨 타이머.
@export var auto_roll_enabled: bool = true
@export var roll_interval_s: float = ROLL_INTERVAL_DEFAULT
var _roll_accum_s: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# 외부에서 _current_chapter / _chapter_elapsed_s 를 갱신하지 않는 경우
	# ChapterManager 가 stage_started 를 발신할 때 _on_stage_started 로 동기화.
	EventBus.stage_started.connect(_on_stage_started)
	EventBus.boss_pattern_telegraphed.connect(_on_boss_telegraphed)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.run_ended.connect(_on_run_ended)


func _process(delta: float) -> void:
	_chapter_elapsed_s += delta
	if not _enabled or not auto_roll_enabled:
		return
	_roll_accum_s += delta
	if _roll_accum_s >= roll_interval_s:
		_roll_accum_s = 0.0
		roll_event()


# === public ===

# 표준 등록 인터페이스. event 는 nullable (외부에서 trigger 책임을 지는 경우).
func register(event_id: StringName, weight: float, condition_fn: Callable, event: EventBase = null) -> void:
	_entries[event_id] = EventEntry.new(event_id, weight, condition_fn, event)
	if event != null and event.get_parent() == null:
		add_child(event)


func unregister(event_id: StringName) -> void:
	if _entries.has(event_id):
		var entry: EventEntry = _entries[event_id]
		if entry.event and entry.event.get_parent() == self:
			entry.event.queue_free()
		_entries.erase(event_id)


func is_registered(event_id: StringName) -> bool:
	return _entries.has(event_id)


func get_event(event_id: StringName) -> EventBase:
	if _entries.has(event_id):
		return (_entries[event_id] as EventEntry).event
	return null


# 외부에서 챕터/경과 시간/HP 비율을 직접 주입할 수도 있다(테스트 용도).
func set_chapter(chapter: int) -> void:
	_current_chapter = chapter
	_chapter_elapsed_s = 0.0


func get_history() -> Dictionary:
	return _history.duplicate()


func reset_history() -> void:
	_history.clear()
	_chapter_elapsed_s = 0.0
	_roll_accum_s = 0.0


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


# meta-systems-spec §4.2 roll_event 의사코드와 동등.
# 반환: 발동된 이벤트의 id (없으면 빈 StringName).
func roll_event() -> StringName:
	if not _enabled:
		return &""
	if _in_boss_lockout():
		return &""
	var hp_pct: float = _resolve_hp_pct()
	var pool: Array = []
	var total_weight: float = 0.0
	for eid in _entries.keys():
		var entry: EventEntry = _entries[eid]
		var history_count: int = int(_history.get(eid, 0))
		if history_count >= entry.max_per_run:
			continue
		if not _check_condition(entry, hp_pct):
			continue
		var w: float = _effective_weight(entry, hp_pct)
		if w <= 0.0:
			continue
		pool.append([entry, w])
		total_weight += w
	if pool.is_empty() or total_weight <= 0.0:
		return &""
	# 84% 합계, 16% 침묵 구간. roll > total/100 이면 침묵.
	var roll: float = randf() * 100.0
	if roll > total_weight:
		return &""
	# 비례 분배.
	var t: float = randf() * total_weight
	var acc: float = 0.0
	for item in pool:
		var picked: EventEntry = item[0]
		acc += float(item[1])
		if t <= acc:
			_history[picked.id] = int(_history.get(picked.id, 0)) + 1
			if picked.event:
				picked.event.trigger()
			return picked.id
	return &""


# 특정 이벤트를 강제로 발동 (디버그 / 스크립트 트리거).
func force_trigger(event_id: StringName) -> bool:
	if not _entries.has(event_id):
		return false
	var entry: EventEntry = _entries[event_id]
	if entry.event == null:
		return false
	_history[event_id] = int(_history.get(event_id, 0)) + 1
	entry.event.trigger()
	return true


# === internals ===

func _check_condition(entry: EventEntry, hp_pct: float) -> bool:
	# 1) EventBase.is_allowed (스크립트 사양)
	if entry.event and not entry.event.is_allowed(_current_chapter, _chapter_elapsed_s, hp_pct, _history):
		return false
	# 2) 외부 condition_fn 추가 게이트 (선택)
	if entry.condition_fn.is_valid():
		var ok: Variant = entry.condition_fn.call(_current_chapter, _chapter_elapsed_s, hp_pct, _history)
		if ok is bool and not bool(ok):
			return false
	return true


func _effective_weight(entry: EventEntry, hp_pct: float) -> float:
	var modifier: float = 1.0
	if entry.event:
		modifier = entry.event.modifier(_current_chapter, hp_pct)
	return entry.weight * modifier


func _resolve_hp_pct() -> float:
	var arr: Array[Node] = get_tree().get_nodes_in_group("player")
	if arr.is_empty():
		return 1.0
	var p: Node = arr[0]
	if not ("hp" in p) or not ("max_hp" in p):
		return 1.0
	return float(p.hp) / float(max(1, int(p.max_hp)))


func _in_boss_lockout() -> bool:
	if _boss_window_start_s <= 0.0:
		return false
	return _chapter_elapsed_s >= _boss_window_start_s and _chapter_elapsed_s <= _boss_window_end_s


# 보스 등장 예고 신호 — lockout 창 설정.
func set_boss_window(start_s: float, end_s: float) -> void:
	_boss_window_start_s = start_s
	_boss_window_end_s = end_s


func clear_boss_window() -> void:
	_boss_window_start_s = 0.0
	_boss_window_end_s = 0.0


# === EventBus 연동 (선택) ===

func _on_stage_started(_chapter_id: StringName, stage_index: int) -> void:
	_current_chapter = max(1, stage_index + 1)
	_chapter_elapsed_s = 0.0
	_roll_accum_s = 0.0
	clear_boss_window()


func _on_boss_telegraphed(_pattern_id: StringName, _duration: float) -> void:
	# 텔레그래프 단계에서는 새 이벤트 발동 금지.
	set_boss_window(_chapter_elapsed_s, _chapter_elapsed_s + BOSS_LOCKOUT_BEFORE_S)


func _on_boss_defeated(_boss_id: StringName, _time_taken: float, _no_hit: bool) -> void:
	clear_boss_window()


func _on_run_ended(_reason: StringName, _stats: Dictionary) -> void:
	reset_history()
