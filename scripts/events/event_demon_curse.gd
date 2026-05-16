class_name EventDemonCurse
extends EventBase

# 이벤트 3 — 요괴의 저주.
# 챕터 1~5, 시간 3:00 이후. 3지선다.

const DURATION_FLIP: float = 30.0
const DURATION_FOG: float = 45.0
const REFUSE_GOLD_PCT: float = 0.20
const FLIP_REWARD_ORBS: int = 10
const FOG_REWARD_MYTH: int = 1
const DAMAGE_TAKEN_DURING_DEBUFF: float = 1.20

var _active_choice: StringName = &""


func get_event_id() -> StringName: return &"event_demon_curse"
func get_base_weight() -> float: return 18.0
func get_max_per_run() -> int: return 2


func _allowed(chapter: int, time_s: float, _hp_pct: float, _h: Dictionary) -> bool:
	return chapter >= 1 and chapter <= 5 and time_s >= 180.0


func _build_payload() -> Dictionary:
	return {
		"name_ko": "요괴의 저주",
		"choices": [
			{"id": &"flip",   "label": "화면 좌우 반전 30초",
				"reward": {"orbs": FLIP_REWARD_ORBS}},
			{"id": &"fog",    "label": "짙은 안개 45초",
				"reward": {"myth_shard": FOG_REWARD_MYTH}},
			{"id": &"refuse", "label": "거부 (금화 20%% 헌납으로 회피)",
				"reward": {}},
		],
		"damage_taken_extra": DAMAGE_TAKEN_DURING_DEBUFF,
	}


func _run() -> void:
	pass


func apply_choice(choice_id: StringName) -> void:
	if _active_choice != &"":
		return
	_active_choice = choice_id
	match choice_id:
		&"flip":
			_apply_screen_flip(true)
			EventBus.toast_requested.emit("화면이 좌우로 뒤집힙니다.", 2.0)
			_spawn_timer(DURATION_FLIP, Callable(self, "_resolve"))
		&"fog":
			EventBus.environment_entered.emit(&"env_fog_curse", Vector2.ZERO)
			EventBus.toast_requested.emit("짙은 안개가 시야를 가립니다.", 2.0)
			_spawn_timer(DURATION_FOG, Callable(self, "_resolve"))
		&"refuse":
			var paid: int = int(round(float(GameState.gold) * REFUSE_GOLD_PCT)) if "gold" in GameState else 0
			if "gold" in GameState:
				GameState.gold = max(0, int(GameState.gold) - paid)
			EventBus.toast_requested.emit("저주를 회피했습니다.", 2.0)
			_active_choice = &""
		_:
			_active_choice = &""


func _apply_screen_flip(enable: bool) -> void:
	var p: Node = _player()
	if p == null or not p.has_node("Camera2D"):
		return
	var cam: Camera2D = p.get_node("Camera2D") as Camera2D
	if cam:
		var sign: float = -1.0 if enable else 1.0
		cam.zoom.x = absf(cam.zoom.x) * sign


func _resolve() -> void:
	var p: Node = _player()
	var alive: bool = p != null and ("hp" in p) and int(p.hp) > 0
	if _active_choice == &"flip":
		_apply_screen_flip(false)
	elif _active_choice == &"fog":
		EventBus.environment_exited.emit(&"env_fog_curse", Vector2.ZERO)
	if alive:
		_grant_reward()
	_active_choice = &""


func _grant_reward() -> void:
	match _active_choice:
		&"flip":
			if MetaState.has_method("add_dokkaebi_orbs"):
				MetaState.add_dokkaebi_orbs(FLIP_REWARD_ORBS)
			EventBus.toast_requested.emit("저주를 견뎌냈습니다. (구슬 +%d)" % FLIP_REWARD_ORBS, 2.5)
		&"fog":
			if "myth_shards" in MetaState:
				MetaState.myth_shards += FOG_REWARD_MYTH
			EventBus.toast_requested.emit("저주를 견뎌냈습니다. (신화 조각 +%d)" % FOG_REWARD_MYTH, 2.5)


# 다른 시스템이 조회 — 디버프 진행 중 받는 피해 +20%.
func get_damage_taken_multiplier() -> float:
	return DAMAGE_TAKEN_DURING_DEBUFF if _active_choice in [&"flip", &"fog"] else 1.0


func is_active() -> bool:
	return _active_choice != &""
