class_name EventBloodMoon
extends EventBase

# 이벤트 6 — 피의 달.
# 챕터 3~5, 시간 5:00 이후. 강제 발동(선택 불가).
# 60초간 — 몬스터 출현 ×2, 경험치 ×2, 금화 ×1.5, 피해 +15%.
# 첫 1회 끝까지 버티면 "혈월의 도깨비" 칭호.

const DURATION: float = 60.0
const SPAWN_MULT: float = 2.0
const XP_MULT: float = 2.0
const GOLD_MULT: float = 1.5
const DAMAGE_TAKEN_MULT: float = 1.15
const TITLE_ID: StringName = &"title_blood_moon_dokkaebi"

var _active: bool = false


func get_event_id() -> StringName: return &"event_blood_moon"
func get_base_weight() -> float: return 5.0
func get_max_per_run() -> int: return 1


func _allowed(chapter: int, time_s: float, _hp_pct: float, _h: Dictionary) -> bool:
	return chapter >= 3 and chapter <= 5 and time_s >= 300.0


func _build_payload() -> Dictionary:
	return {
		"name_ko": "피의 달",
		"force": true,
		"duration_s": DURATION,
		"effects": {
			"spawn_mult": SPAWN_MULT,
			"xp_mult": XP_MULT,
			"gold_mult": GOLD_MULT,
			"damage_taken_mult": DAMAGE_TAKEN_MULT,
		},
	}


func _run() -> void:
	if _active:
		return
	_active = true
	_apply_multipliers(true)
	EventBus.toast_requested.emit("피의 달이 떠올랐습니다. 60초간 버티십시오.", 3.0)
	_spawn_timer(DURATION, Callable(self, "_end"))


func _end() -> void:
	if not _active:
		return
	_apply_multipliers(false)
	_active = false
	var p: Node = _player()
	var alive: bool = p != null and ("hp" in p) and int(p.hp) > 0
	if alive:
		_grant_completion_reward()


func _apply_multipliers(enable: bool) -> void:
	# 외부 시스템(스포너/픽업)이 GameState 의 곱연산 필드를 참조한다.
	if "spawn_rate_mult" in GameState:
		var prev: float = float(GameState.spawn_rate_mult)
		GameState.spawn_rate_mult = (prev * SPAWN_MULT) if enable else max(0.001, prev / SPAWN_MULT)
	if "exp_gain_mult" in GameState:
		var prev_x: float = float(GameState.exp_gain_mult)
		GameState.exp_gain_mult = (prev_x * XP_MULT) if enable else max(0.001, prev_x / XP_MULT)
	if "gold_gain_mult" in GameState:
		var prev_g: float = float(GameState.gold_gain_mult)
		GameState.gold_gain_mult = (prev_g * GOLD_MULT) if enable else max(0.001, prev_g / GOLD_MULT)
	if "damage_taken_mult" in GameState:
		var prev_d: float = float(GameState.damage_taken_mult)
		GameState.damage_taken_mult = (prev_d * DAMAGE_TAKEN_MULT) if enable else max(0.001, prev_d / DAMAGE_TAKEN_MULT)
	if enable:
		EventBus.environment_entered.emit(&"env_blood_moon", Vector2.ZERO)
	else:
		EventBus.environment_exited.emit(&"env_blood_moon", Vector2.ZERO)


func _grant_completion_reward() -> void:
	# 첫 1회 — 칭호 부여(중복 부여 무시는 메타 측에서 처리).
	if MetaState.has_method("unlock_title"):
		MetaState.unlock_title(TITLE_ID)
	else:
		# 폴백: achievements 딕셔너리에 칭호 표식만 남긴다.
		if "achievements" in MetaState:
			var ach: Dictionary = MetaState.achievements
			if not ach.has(TITLE_ID):
				ach[TITLE_ID] = {"unlocked_at": int(Time.get_unix_time_from_system())}
				MetaState.achievements = ach
	EventBus.toast_requested.emit("혈월의 도깨비 칭호를 얻으셨습니다.", 3.0)


# 외부에서 조회 — 진행 중 받는 추가 피해 배율.
func get_damage_taken_multiplier() -> float:
	return DAMAGE_TAKEN_MULT if _active else 1.0


func is_active() -> bool:
	return _active
