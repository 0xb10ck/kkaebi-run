class_name EventTreasureChest
extends EventBase

# 이벤트 4 — 보물 상자.
# 챕터 1~5, 시간 4:00 이후. 일반 70% / 고급 25% / 봉인 5%.

const ENTITY_SCENE: String = "res://scenes/events/event_treasure_chest.tscn"
const PREMIUM_LEGENDARY_CHANCE: float = 0.70
const SEALED_WAVE_TIME: float = 30.0
const SEALED_KILL_TARGET: int = 10

var _entity: Node2D
var _chest_type: StringName = &""


func get_event_id() -> StringName: return &"event_treasure_chest"
func get_base_weight() -> float: return 15.0
func get_max_per_run() -> int: return 2


func _allowed(chapter: int, time_s: float, _hp_pct: float, _h: Dictionary) -> bool:
	return chapter >= 1 and chapter <= 5 and time_s >= 240.0


func _build_payload() -> Dictionary:
	_chest_type = _roll_chest_type()
	return {
		"name_ko": "보물 상자",
		"chest_type": String(_chest_type),
	}


func _run() -> void:
	_spawn_entity()


func _roll_chest_type() -> StringName:
	var r: float = randf()
	if r < 0.70:
		return &"normal"
	elif r < 0.95:
		return &"premium"
	else:
		return &"sealed"


func _spawn_entity() -> void:
	if ResourceLoader.exists(ENTITY_SCENE):
		_entity = (load(ENTITY_SCENE) as PackedScene).instantiate() as Node2D
	else:
		_entity = Node2D.new()
		_entity.name = "TreasureChest"
	if "chest_type" in _entity:
		_entity.chest_type = _chest_type
	_entity.global_position = _spawn_pos()
	get_tree().current_scene.add_child(_entity)
	if _entity.has_signal("opened"):
		_entity.opened.connect(_on_opened)


func _spawn_pos() -> Vector2:
	var p: Node = _player()
	var c: Vector2 = (p.global_position if p else Vector2.ZERO)
	return c + Vector2(randf_range(-220, 220), randf_range(-220, 220))


func _on_opened() -> void:
	match _chest_type:
		&"normal":   _open_normal()
		&"premium":  _open_premium()
		&"sealed":   _open_sealed()
	if is_instance_valid(_entity):
		_entity.queue_free()


func _open_normal() -> void:
	var roll: int = randi() % 3
	match roll:
		0:
			var amt: int = randi_range(100, 300)
			if GameState.has_method("add_gold"):
				GameState.add_gold(amt)
			EventBus.toast_requested.emit("금화 %d을(를) 얻었습니다." % amt, 2.0)
		1:
			if SkillManager.has_method("grant_random_skill"):
				SkillManager.grant_random_skill(GameEnums.Rarity.COMMON)
			EventBus.toast_requested.emit("새로운 스킬을 얻었습니다.", 2.0)
		2:
			var p: Node = _player()
			if p and "hp" in p and "max_hp" in p:
				var heal: int = int(p.max_hp) - int(p.hp)
				p.hp = int(p.max_hp)
				if p.has_signal("hp_changed"):
					p.hp_changed.emit(int(p.hp), int(p.max_hp))
				if heal > 0:
					EventBus.player_healed.emit(heal, get_event_id())
			EventBus.toast_requested.emit("HP가 가득 찼습니다.", 2.0)


func _open_premium() -> void:
	if randf() < PREMIUM_LEGENDARY_CHANCE:
		if SkillManager.has_method("grant_random_skill"):
			SkillManager.grant_random_skill(GameEnums.Rarity.LEGENDARY)
		EventBus.toast_requested.emit("전설 스킬을 얻었습니다.", 2.5)
	else:
		var p: Node = _player()
		if p and "hp" in p and "max_hp" in p:
			var dmg: int = max(1, int(round(float(p.max_hp) * 0.50)))
			if p.has_method("take_damage"):
				p.take_damage(dmg)
		EventBus.toast_requested.emit("함정이었습니다.", 2.0)


func _open_sealed() -> void:
	EventBus.toast_requested.emit("봉인된 상자 — 30초 안에 적 %d마리를 처치하십시오." % SEALED_KILL_TARGET, 3.0)
	var initial: int = int(GameState.kill_count) if "kill_count" in GameState else 0
	_spawn_timer(SEALED_WAVE_TIME, Callable(self, "_resolve_sealed").bind(initial))


func _resolve_sealed(initial_kills: int) -> void:
	var now: int = int(GameState.kill_count) if "kill_count" in GameState else 0
	if now - initial_kills >= SEALED_KILL_TARGET:
		if "myth_shards" in MetaState:
			MetaState.myth_shards += 2
		EventBus.toast_requested.emit("봉인 해제! 신화 조각 2를 얻었습니다.", 2.5)
	else:
		EventBus.toast_requested.emit("봉인을 풀지 못했습니다.", 2.0)
