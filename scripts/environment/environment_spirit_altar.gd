extends Area2D

# meta-systems-spec §5.5 신령 제단 — 상호작용 시 HP -30% 헌납 → 전설 스킬 1개 즉시 획득(LV1).
# 한 런 1회, HP <= 30% 면 활성 불가. 환경친화 LV3: 헌납량 15%.

const ENV_ID: StringName = &"env_spirit_altar"
const HP_COST_PCT_DEFAULT: float = 0.30
const HP_COST_PCT_FRIENDLY: float = 0.15
const MIN_HP_PCT_TO_USE: float = 0.30
const INTERACT_ACTION: String = "ui_accept"

var _used: bool = false
var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("environment")
	add_to_group("env_spirit_altar")
	collision_layer = 32
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if _used or not _player_in_range:
		return
	if Input.is_action_just_pressed(INTERACT_ACTION):
		_try_use()


func _try_use() -> void:
	var p: Node = _player()
	if p == null:
		return
	if not _hp_ok(p):
		EventBus.toast_requested.emit("HP가 부족하여 헌납할 수 없습니다.", 2.0)
		return
	var max_hp_val: int = int(p.max_hp) if "max_hp" in p else 100
	var cost: int = max(1, int(round(float(max_hp_val) * _cost_pct())))
	if p.has_method("take_damage"):
		p.take_damage(cost)
	# 전설 스킬 1개 부여.
	if SkillManager.has_method("grant_random_skill"):
		SkillManager.grant_random_skill(GameEnums.Rarity.LEGENDARY)
	else:
		EventBus.skill_acquired.emit(&"legendary_random", 1)
	_used = true
	EventBus.environment_exited.emit(ENV_ID, global_position)
	EventBus.toast_requested.emit("신령의 가호를 받았습니다.", 2.5)


func _cost_pct() -> float:
	# "환경 친화" LV3 보정 — MetaState에 등록되어 있을 때만.
	if MetaState.has_method("get_upgrade_level"):
		var lv: int = MetaState.get_upgrade_level(&"env_friendly")
		if lv >= 3:
			return HP_COST_PCT_FRIENDLY
	return HP_COST_PCT_DEFAULT


func _hp_ok(p: Node) -> bool:
	if not ("hp" in p) or not ("max_hp" in p):
		return false
	var ratio: float = float(p.hp) / float(max(1, int(p.max_hp)))
	return ratio >= MIN_HP_PCT_TO_USE


func _player() -> Node:
	var arr: Array[Node] = get_tree().get_nodes_in_group("player")
	return arr[0] if not arr.is_empty() else null


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.environment_entered.emit(ENV_ID, global_position)
		if not _used:
			EventBus.toast_requested.emit("스페이스: 신령에게 HP를 헌납 — 전설 스킬 획득", 3.0)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		EventBus.environment_exited.emit(ENV_ID, global_position)


func is_used() -> bool:
	return _used
