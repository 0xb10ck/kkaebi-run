class_name EventGoblinMarket
extends EventBase

# 이벤트 1 — 도깨비 시장.
# 챕터 1~5, 시간 2:00 이후, HP 30% 이상. 30초 머무름. 미구매 시 사라짐.

const ENTITY_SCENE: String = "res://scenes/events/event_goblin_market.tscn"
const ENTITY_LIFETIME: float = 30.0

var _entity: Node2D


func get_event_id() -> StringName: return &"event_goblin_market"
func get_base_weight() -> float: return 22.0
func get_max_per_run() -> int: return 1


func _allowed(chapter: int, time_s: float, hp_pct: float, _h: Dictionary) -> bool:
	return chapter >= 1 and chapter <= 5 and time_s >= 120.0 and hp_pct >= 0.30


func modifier(_chapter: int, _hp_pct: float) -> float:
	# 신목 Lv.4 이상 출현 보정 × 1.2
	if "shinmok_stage" in MetaState and int(MetaState.shinmok_stage) >= 4:
		return 1.2
	return 1.0


func _build_payload() -> Dictionary:
	return {
		"name_ko": "도깨비 시장",
		"choices": [
			{"id": &"heal_potion",  "label": "회복 약초 (HP 30% 회복)", "cost_gold": 80},
			{"id": &"random_skill", "label": "임의 일반 스킬 LV1",      "cost_gold": 120},
			{"id": &"orbs_5",       "label": "도깨비 구슬 5개",         "cost_gold": 200},
		],
		"lifetime_s": ENTITY_LIFETIME,
	}


func _run() -> void:
	_spawn_entity()
	_spawn_timer(ENTITY_LIFETIME, Callable(self, "_expire"))


func _spawn_entity() -> void:
	if ResourceLoader.exists(ENTITY_SCENE):
		_entity = (load(ENTITY_SCENE) as PackedScene).instantiate() as Node2D
	else:
		_entity = Node2D.new()
		_entity.name = "GoblinMarket"
	_entity.global_position = _spawn_pos()
	get_tree().current_scene.add_child(_entity)


func _spawn_pos() -> Vector2:
	var p: Node = _player()
	var c: Vector2 = (p.global_position if p else Vector2.ZERO)
	return c + Vector2(randf_range(-180, 180), randf_range(-180, 180))


func _expire() -> void:
	if is_instance_valid(_entity):
		_entity.queue_free()


# UI/HUD가 호출.
func apply_choice(choice_id: StringName) -> void:
	var p: Node = _player()
	match choice_id:
		&"heal_potion":
			if not _can_pay(80): return
			_pay(80)
			if p and "hp" in p and "max_hp" in p:
				var amt: int = max(1, int(round(float(p.max_hp) * 0.30)))
				var new_hp: int = min(int(p.max_hp), int(p.hp) + amt)
				p.hp = new_hp
				if p.has_signal("hp_changed"):
					p.hp_changed.emit(new_hp, int(p.max_hp))
				EventBus.player_healed.emit(amt, get_event_id())
		&"random_skill":
			if not _can_pay(120): return
			_pay(120)
			if SkillManager.has_method("grant_random_skill"):
				SkillManager.grant_random_skill(GameEnums.Rarity.COMMON)
		&"orbs_5":
			if not _can_pay(200): return
			_pay(200)
			if MetaState.has_method("add_dokkaebi_orbs"):
				MetaState.add_dokkaebi_orbs(5)
	_expire()


func _can_pay(amount: int) -> bool:
	return "gold" in GameState and int(GameState.gold) >= amount


func _pay(amount: int) -> void:
	if "gold" in GameState:
		GameState.gold = max(0, int(GameState.gold) - amount)
