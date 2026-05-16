extends Area2D

# meta-systems-spec §5.1 가시덤불 — 0.5s마다 최대 HP의 3% 대미지, 이속 -20%.
# 화/금 속성 스킬로 파괴 (5회), 파괴 시 금화 10 드랍.

const ENV_ID: StringName = &"env_thornbush"
const TICK_INTERVAL: float = 0.5
const DAMAGE_PCT: float = 0.03
const ENEMY_TICK_DAMAGE: int = 5
const SLOW_FACTOR: float = 0.80
const SLOW_DURATION: float = 0.6
const MAX_HITS: int = 5
const GOLD_DROP: int = 10

@export var size: Vector2 = Vector2(32, 32)

var _hits_left: int = MAX_HITS
var _player_inside: bool = false
var _enemies_inside: Array[Node] = []
var _tick: float = 0.0


func _ready() -> void:
	add_to_group("environment")
	add_to_group("env_thornbush")
	collision_layer = 32                    # environment
	collision_mask = 1 | 4                  # player + enemy
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if not _player_inside and _enemies_inside.is_empty():
		return
	_tick += delta
	if _tick < TICK_INTERVAL:
		return
	_tick = 0.0
	_apply_tick()


func _apply_tick() -> void:
	if _player_inside:
		var p: Node = _player()
		if p:
			var max_hp_val: int = int(p.max_hp) if "max_hp" in p else 100
			var dmg: int = max(1, int(round(float(max_hp_val) * DAMAGE_PCT)))
			if p.has_method("take_damage"):
				p.take_damage(dmg)
			if p.has_method("apply_slow"):
				p.apply_slow(SLOW_FACTOR, SLOW_DURATION)
	for e in _enemies_inside:
		if not is_instance_valid(e):
			continue
		if e.has_method("take_damage"):
			e.take_damage(ENEMY_TICK_DAMAGE, self)
		if e.has_method("apply_slow"):
			e.apply_slow(SLOW_FACTOR, SLOW_DURATION)
	_enemies_inside = _enemies_inside.filter(func(n: Node) -> bool: return is_instance_valid(n))


# 화/금 속성 스킬에서 호출. 두 번째 인자는 호출 측 호환.
func take_damage(_amount: int, _source: Variant = null) -> void:
	_hits_left = max(0, _hits_left - 1)
	if _hits_left <= 0:
		_destroy()


func _destroy() -> void:
	if "add_gold" in GameState:
		GameState.add_gold(GOLD_DROP)
	EventBus.environment_exited.emit(ENV_ID, global_position)
	queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		EventBus.environment_entered.emit(ENV_ID, global_position)
	elif body.is_in_group("enemy"):
		if not _enemies_inside.has(body):
			_enemies_inside.append(body)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		EventBus.environment_exited.emit(ENV_ID, global_position)
	elif body.is_in_group("enemy"):
		_enemies_inside.erase(body)


func _player() -> Node:
	var arr: Array[Node] = get_tree().get_nodes_in_group("player")
	return arr[0] if not arr.is_empty() else null
