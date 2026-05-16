class_name EventWanderingDokkaebi
extends EventBase

# 이벤트 5 — 떠돌이 도깨비.
# 챕터 2~5, 시간 3:30 이후, 1런 1회. 수수께끼 3택.
#  - 정답: 무작위 시너지 진화 강제 발동 또는 신화 조각 3
#  - 오답: HP 20% 손실, 30초간 시야 페이드
#  - 회피: 30초 후 자동 소멸

const ENTITY_LIFETIME: float = 30.0
const WRONG_ANSWER_HP_LOSS: float = 0.20
const WRONG_ANSWER_FADE_S: float = 30.0
const CORRECT_REWARD_MYTH: int = 3

var _entity: Node2D
var _correct_choice: StringName = &""
var _resolved: bool = false


func get_event_id() -> StringName: return &"event_wandering_dokkaebi"
func get_base_weight() -> float: return 8.0
func get_max_per_run() -> int: return 1


func _allowed(chapter: int, time_s: float, _hp_pct: float, _h: Dictionary) -> bool:
	return chapter >= 2 and chapter <= 5 and time_s >= 210.0


func _build_payload() -> Dictionary:
	# 챕터별 풀에서 5개 중 1개 랜덤 — 본 스텁은 3지선다.
	# 정답 위치는 무작위. 도감 진행도 50%↑ 시 1지 제거(힌트) — 본 스텁은 미적용.
	var idx: int = randi() % 3
	_correct_choice = [&"answer_a", &"answer_b", &"answer_c"][idx]
	return {
		"name_ko": "떠돌이 도깨비",
		"riddle_ko": "수수께끼를 풀어 보십시오.",
		"choices": [
			{"id": &"answer_a", "label": "A 선택지"},
			{"id": &"answer_b", "label": "B 선택지"},
			{"id": &"answer_c", "label": "C 선택지"},
			{"id": &"flee",     "label": "회피"},
		],
		"lifetime_s": ENTITY_LIFETIME,
	}


func _run() -> void:
	_spawn_entity()
	_spawn_timer(ENTITY_LIFETIME, Callable(self, "_on_timeout"))


func _spawn_entity() -> void:
	var scene_path: String = "res://scenes/events/event_wandering_dokkaebi.tscn"
	if ResourceLoader.exists(scene_path):
		_entity = (load(scene_path) as PackedScene).instantiate() as Node2D
	else:
		_entity = Node2D.new()
		_entity.name = "WanderingDokkaebi"
	var p: Node = _player()
	var c: Vector2 = (p.global_position if p else Vector2.ZERO)
	_entity.global_position = c + Vector2(randf_range(-180, 180), randf_range(-180, 180))
	get_tree().current_scene.add_child(_entity)


func apply_choice(choice_id: StringName) -> void:
	if _resolved:
		return
	if choice_id == &"flee":
		_resolved = true
		_cleanup()
		EventBus.toast_requested.emit("떠돌이 도깨비가 사라졌습니다.", 2.0)
		return
	_resolved = true
	if choice_id == _correct_choice:
		_grant_correct_reward()
	else:
		_apply_wrong_penalty()
	_cleanup()


func _grant_correct_reward() -> void:
	# 50% 확률: 시너지 진화 강제 / 나머지: 신화 조각 3.
	if randf() < 0.5 and SkillManager.has_method("force_synergy_evolution"):
		SkillManager.force_synergy_evolution()
		EventBus.toast_requested.emit("시너지가 진화했습니다.", 2.5)
	else:
		if "myth_shards" in MetaState:
			MetaState.myth_shards += CORRECT_REWARD_MYTH
		EventBus.toast_requested.emit("정답입니다. 신화 조각 +%d." % CORRECT_REWARD_MYTH, 2.5)


func _apply_wrong_penalty() -> void:
	var p: Node = _player()
	if p and "hp" in p and "max_hp" in p:
		var dmg: int = max(1, int(round(float(p.max_hp) * WRONG_ANSWER_HP_LOSS)))
		if p.has_method("take_damage"):
			p.take_damage(dmg)
	EventBus.environment_entered.emit(&"env_vision_fade", Vector2.ZERO)
	_spawn_timer(WRONG_ANSWER_FADE_S, Callable(self, "_clear_vision_fade"))
	EventBus.toast_requested.emit("오답입니다. 시야가 흐려집니다.", 2.5)


func _clear_vision_fade() -> void:
	EventBus.environment_exited.emit(&"env_vision_fade", Vector2.ZERO)


func _on_timeout() -> void:
	if _resolved:
		return
	_resolved = true
	_cleanup()
	EventBus.toast_requested.emit("떠돌이 도깨비가 떠나갔습니다.", 2.0)


func _cleanup() -> void:
	if is_instance_valid(_entity):
		_entity.queue_free()
		_entity = null
