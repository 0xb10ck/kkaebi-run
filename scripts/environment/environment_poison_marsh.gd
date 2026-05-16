extends Area2D

# meta-systems-spec §5.3 독 늪 — 0.5s마다 5 고정 데미지, 이속 -30%. 영구.
# 토 "흙벽"으로 일시 차단, 화 "산불"로 60s 증발.

const ENV_ID: StringName = &"env_poison_marsh"
const TICK_INTERVAL: float = 0.5
const TICK_DAMAGE: int = 5
const SLOW_FACTOR: float = 0.70                 # -30%
const SLOW_DURATION: float = 0.6
const EVAPORATE_DURATION: float = 60.0

@export var size: Vector2 = Vector2(64, 64)

var _player_inside: bool = false
var _enemies_inside: Array[Node] = []
var _tick: float = 0.0
var _evaporated_until_unix: float = 0.0
var _blocked: bool = false


func _ready() -> void:
	add_to_group("environment")
	add_to_group("env_poison_marsh")
	collision_layer = 32
	collision_mask = 1 | 4
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if _is_inactive():
		return
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
			if p.has_method("take_damage"):
				p.take_damage(TICK_DAMAGE)
			if p.has_method("apply_slow"):
				p.apply_slow(SLOW_FACTOR, SLOW_DURATION)
	for e in _enemies_inside:
		if not is_instance_valid(e):
			continue
		if e.has_method("take_damage"):
			e.take_damage(TICK_DAMAGE, self)
		if e.has_method("apply_slow"):
			e.apply_slow(SLOW_FACTOR, SLOW_DURATION)
	_enemies_inside = _enemies_inside.filter(func(n: Node) -> bool: return is_instance_valid(n))


# 화 "산불" 스킬에서 호출 — 60초간 증발.
func evaporate(duration: float = EVAPORATE_DURATION) -> void:
	_evaporated_until_unix = Time.get_unix_time_from_system() + duration
	EventBus.environment_exited.emit(ENV_ID, global_position)


# 토 "흙벽" 스킬에서 호출 — 그 위에 벽이 있는 동안 차단.
func set_blocked(blocked: bool) -> void:
	_blocked = blocked
	if blocked:
		EventBus.environment_exited.emit(ENV_ID, global_position)


func is_active() -> bool:
	return not _is_inactive()


func _is_inactive() -> bool:
	if _blocked:
		return true
	return Time.get_unix_time_from_system() < _evaporated_until_unix


func _player() -> Node:
	var arr: Array[Node] = get_tree().get_nodes_in_group("player")
	return arr[0] if not arr.is_empty() else null


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
