class_name EventSpiritBlessing
extends EventBase

# 이벤트 2 — 신령의 축복.
# 챕터 2~5, 보스 처치 직후 30초 내 (외부에서 트리거 보정), HP 50% 이상.
# 60초간 버프, 종료 시 1초간 모든 행동 불가.

const DURATION: float = 60.0
const STUN_AFTER: float = 1.0
const ATK_BUFF_MULT: float = 1.30
const MS_BUFF_MULT: float = 1.40

var _active_buff: StringName = &""


func get_event_id() -> StringName: return &"event_spirit_blessing"
func get_base_weight() -> float: return 10.0
func get_max_per_run() -> int: return 2


func _allowed(chapter: int, _time_s: float, hp_pct: float, _h: Dictionary) -> bool:
	return chapter >= 2 and chapter <= 5 and hp_pct >= 0.50


func _build_payload() -> Dictionary:
	return {
		"name_ko": "신령의 축복",
		"choices": [
			{"id": &"atk_up", "label": "공격력 +30% (60초)"},
			{"id": &"ms_up",  "label": "이동속도 +40% (60초)"},
		],
		"duration_s": DURATION,
		"penalty_stun_s": STUN_AFTER,
	}


func _run() -> void:
	pass


func apply_choice(choice_id: StringName) -> void:
	if _active_buff != &"":
		return
	match choice_id:
		&"atk_up":
			if "attack" in GameState:
				GameState.attack = int(round(float(GameState.attack) * ATK_BUFF_MULT))
			_active_buff = &"atk_up"
		&"ms_up":
			var p: Node = _player()
			if p and "move_speed_mult" in p:
				p.move_speed_mult *= MS_BUFF_MULT
			_active_buff = &"ms_up"
		_:
			return
	EventBus.toast_requested.emit("신령의 가호를 받았습니다.", 2.0)
	_spawn_timer(DURATION, Callable(self, "_end_buff"))


func _end_buff() -> void:
	var p: Node = _player()
	match _active_buff:
		&"atk_up":
			if "attack" in GameState:
				GameState.attack = int(round(float(GameState.attack) / ATK_BUFF_MULT))
		&"ms_up":
			if p and "move_speed_mult" in p:
				p.move_speed_mult /= MS_BUFF_MULT
	# 영혼이 빠져나가는 연출 — 1초간 행동 불가 (apply_slow는 0.05로 클램프).
	if p and p.has_method("apply_slow"):
		p.apply_slow(0.05, STUN_AFTER)
	_active_buff = &""
