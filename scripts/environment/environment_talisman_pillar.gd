extends Area2D

# meta-systems-spec §5.4 부적 기둥 — 공격 5회 파괴.
# 파괴 시 반경 200 적 5초 스턴 + 자기회복 10%.
# 활성 상태에서 반경 96 내 적 공격력 -20% (적 AI가 is_in_aura/get_enemy_atk_debuff 조회).

const ENV_ID: StringName = &"env_talisman_pillar"
const MAX_HITS: int = 5
const STUN_RADIUS: float = 200.0
const STUN_DURATION: float = 5.0
const HEAL_PCT: float = 0.10
const AURA_RADIUS: float = 96.0
const ENEMY_ATK_DEBUFF: float = 0.20

var _hits_left: int = MAX_HITS
var _destroyed: bool = false


func _ready() -> void:
	add_to_group("environment")
	add_to_group("env_talisman_pillar")
	collision_layer = 32
	collision_mask = 1 | 4 | 2 | 64        # player + enemy + player_attack + projectile_player
	monitoring = true
	body_entered.connect(_on_body_entered)


# 플레이어 공격(근접/투사체)에서 호출.
func take_damage(_amount: int, _source: Variant = null) -> void:
	if _destroyed:
		return
	_hits_left = max(0, _hits_left - 1)
	if _hits_left <= 0:
		_destroy()


func _destroy() -> void:
	_destroyed = true
	# 1) 반경 내 적 스턴.
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not ("global_position" in e):
			continue
		if (e.global_position as Vector2).distance_to(global_position) <= STUN_RADIUS:
			if e.has_method("apply_stun"):
				e.apply_stun(STUN_DURATION)
			elif e.has_method("apply_slow"):
				e.apply_slow(0.05, STUN_DURATION)
	# 2) 플레이어 회복 HP 10%.
	var p: Node = _player()
	if p and "hp" in p and "max_hp" in p:
		var heal: int = max(1, int(round(float(p.max_hp) * HEAL_PCT)))
		var new_hp: int = min(int(p.max_hp), int(p.hp) + heal)
		p.hp = new_hp
		if p.has_signal("hp_changed"):
			p.hp_changed.emit(new_hp, int(p.max_hp))
		EventBus.player_healed.emit(heal, ENV_ID)
	EventBus.environment_exited.emit(ENV_ID, global_position)
	EventBus.toast_requested.emit("부적 기둥이 적을 정화합니다.", 2.0)
	queue_free()


# 적 AI가 호출 — 본 기둥의 디버프 반경 안인지.
func is_in_aura(world_pos: Vector2) -> bool:
	if _destroyed:
		return false
	return world_pos.distance_to(global_position) <= AURA_RADIUS


func get_enemy_atk_debuff() -> float:
	return ENEMY_ATK_DEBUFF if not _destroyed else 0.0


func is_destroyed() -> bool:
	return _destroyed


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		EventBus.environment_entered.emit(ENV_ID, global_position)


func _player() -> Node:
	var arr: Array[Node] = get_tree().get_nodes_in_group("player")
	return arr[0] if not arr.is_empty() else null
