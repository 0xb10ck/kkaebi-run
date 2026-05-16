class_name EventBase
extends Node

# 모든 랜덤 이벤트의 공통 인터페이스.
# 매니저(EventManager)가 가중치 추첨 후 trigger()를 호출.
# 자식 클래스는 get_event_id / get_base_weight / get_max_per_run /
# _allowed / modifier / _build_payload / _run / apply_choice 를 override.


# === 자식이 오버라이드 ===

func get_event_id() -> StringName:
	return &""


func get_base_weight() -> float:
	return 0.0


func get_max_per_run() -> int:
	return 2


func is_allowed(chapter: int, time_s: float, hp_pct: float, history: Dictionary) -> bool:
	if int(history.get(get_event_id(), 0)) >= get_max_per_run():
		return false
	return _allowed(chapter, time_s, hp_pct, history)


func modifier(_chapter: int, _hp_pct: float) -> float:
	return 1.0


func trigger() -> void:
	var payload: Dictionary = _build_payload()
	EventBus.random_event_triggered.emit(get_event_id(), payload)
	_run()


# === 하위 클래스 override 지점 ===

func _allowed(_chapter: int, _time_s: float, _hp_pct: float, _history: Dictionary) -> bool:
	return true


func _build_payload() -> Dictionary:
	return {}


func _run() -> void:
	pass


# 사용자 선택 처리 — 기본은 무동작.
func apply_choice(_choice_id: StringName) -> void:
	pass


# === 공용 헬퍼 ===

func _player() -> Node:
	var arr: Array[Node] = get_tree().get_nodes_in_group("player")
	return arr[0] if not arr.is_empty() else null


func _hp_pct(p: Node) -> float:
	if p == null or not ("hp" in p) or not ("max_hp" in p):
		return 1.0
	return float(p.hp) / float(max(1, int(p.max_hp)))


func _spawn_timer(duration: float, callback: Callable) -> void:
	get_tree().create_timer(duration, false).timeout.connect(callback)
