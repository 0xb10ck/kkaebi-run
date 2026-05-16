class_name EventInvisibleCap
extends EventBase

# 이벤트 7 — 도깨비감투 발견.
# 챕터 1~5, HP 40% 이하. 기본 확률 6% (HP 20% 이하 시 ×2).
# 즉시 사용 또는 보관(런 1회 한정).
# 사용 시 10초간 완전 투명(무적 + 공격 가능), 종료 직후 1초간 이속 50% 감소.

const STEALTH_DURATION: float = 10.0
const POST_STEALTH_SLOW_DURATION: float = 1.0
const POST_STEALTH_SLOW_FACTOR: float = 0.50

var _stored: bool = false                  # 보관 중인 감투 (런 1회 한정)
var _stealth_active: bool = false


func get_event_id() -> StringName: return &"event_invisible_cap"
func get_base_weight() -> float: return 6.0
func get_max_per_run() -> int: return 1


func _allowed(chapter: int, _time_s: float, hp_pct: float, _h: Dictionary) -> bool:
	return chapter >= 1 and chapter <= 5 and hp_pct <= 0.40


# HP 20% 이하 시 ×2 가중.
func modifier(_chapter: int, hp_pct: float) -> float:
	return 2.0 if hp_pct <= 0.20 else 1.0


func _build_payload() -> Dictionary:
	return {
		"name_ko": "도깨비감투 발견",
		"choices": [
			{"id": &"use_now", "label": "즉시 사용 (10초 완전 투명)"},
			{"id": &"store",   "label": "보관 (런 1회 한정)"},
		],
		"stealth_duration_s": STEALTH_DURATION,
		"post_stealth_slow_s": POST_STEALTH_SLOW_DURATION,
	}


func _run() -> void:
	EventBus.toast_requested.emit("도깨비감투를 발견하셨습니다.", 2.5)


func apply_choice(choice_id: StringName) -> void:
	match choice_id:
		&"use_now":
			_activate_stealth()
		&"store":
			_stored = true
			EventBus.toast_requested.emit("도깨비감투를 보관하셨습니다.", 2.0)


# 보관된 감투를 외부에서 즉발 사용. 성공 시 true.
func use_stored() -> bool:
	if not _stored or _stealth_active:
		return false
	_stored = false
	_activate_stealth()
	return true


func _activate_stealth() -> void:
	if _stealth_active:
		return
	_stealth_active = true
	var p: Node = _player()
	# 투명 + 무적: invincible 플래그 + 모듈레이트 알파 다운.
	if p:
		if "invincible" in p:
			p.invincible = true
		if p is CanvasItem:
			(p as CanvasItem).modulate.a = 0.25
		if p.is_in_group("player"):
			p.add_to_group("stealth")
	EventBus.toast_requested.emit("10초간 모습이 사라졌습니다.", 2.5)
	_spawn_timer(STEALTH_DURATION, Callable(self, "_end_stealth"))


func _end_stealth() -> void:
	if not _stealth_active:
		return
	_stealth_active = false
	var p: Node = _player()
	if p:
		if "invincible" in p:
			p.invincible = false
		if p is CanvasItem:
			(p as CanvasItem).modulate.a = 1.0
		if p.is_in_group("stealth"):
			p.remove_from_group("stealth")
		# 종료 직후 1초간 이속 50% 감소.
		if p.has_method("apply_slow"):
			p.apply_slow(POST_STEALTH_SLOW_FACTOR, POST_STEALTH_SLOW_DURATION)
	EventBus.toast_requested.emit("도깨비감투의 효과가 끝났습니다.", 1.5)


func is_stored() -> bool:
	return _stored


func is_stealth_active() -> bool:
	return _stealth_active
