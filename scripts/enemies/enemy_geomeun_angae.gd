extends EnemyBase

# M47 검은 안개 잡령 — 일반 추적. 접촉 시 플레이어에게 공격력 -20% 디버프(5s).
# 사망 시 respawn_delay_s(10.0s) 뒤 동일 위치에 같은 종(EnemyData)을 재인스턴스화한다.
# 핵심 오염원(전역 그룹 "corruption_core") 파괴 시 리스폰 중지 — 재스폰 직전 그룹 검사.

const DEFAULT_RESPAWN_DELAY_S: float = 10.0
const DEFAULT_RESPAWN_SAME_POSITION: bool = true
const DEFAULT_RESPAWN_STOPS_WHEN_CORRUPTION_DESTROYED: bool = true
const DEFAULT_CONTACT_DEBUFF_VALUE: float = -0.2
const DEFAULT_CONTACT_DEBUFF_DURATION_S: float = 5.0
const DEFAULT_ATTACK_SLOW_FALLBACK_MULT: float = 0.85

const CORRUPTION_CORE_GROUP: StringName = &"corruption_core"

const FALLBACK_COLOR: Color = Color(0.10, 0.10, 0.13, 0.85)
const FALLBACK_RADIUS: float = 14.0
const EYE_COLOR: Color = Color(0.95, 0.95, 0.95, 1.0)

var _respawn_delay: float = DEFAULT_RESPAWN_DELAY_S
var _respawn_same_position: bool = DEFAULT_RESPAWN_SAME_POSITION
var _respawn_stops_when_corruption: bool = DEFAULT_RESPAWN_STOPS_WHEN_CORRUPTION_DESTROYED
var _contact_debuff_value: float = DEFAULT_CONTACT_DEBUFF_VALUE
var _contact_debuff_duration: float = DEFAULT_CONTACT_DEBUFF_DURATION_S

var _drift_phase: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 25
		move_speed = 70.0
		contact_damage = 6
		exp_drop_value = 5
		coin_drop_value = 1
		coin_drop_chance = 0.12
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("respawn_delay_s"):
			_respawn_delay = float(params["respawn_delay_s"])
		if params.has("respawn_same_position"):
			_respawn_same_position = bool(params["respawn_same_position"])
		if params.has("respawn_stops_when_corruption_source_destroyed"):
			_respawn_stops_when_corruption = bool(params["respawn_stops_when_corruption_source_destroyed"])
		if params.has("contact_debuff_value"):
			_contact_debuff_value = float(params["contact_debuff_value"])
		if params.has("contact_debuff_duration_s"):
			_contact_debuff_duration = float(params["contact_debuff_duration_s"])
	hp = max_hp
	_drift_phase = randf() * TAU


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_drift_phase = fmod(_drift_phase + delta * 3.0, TAU)
	# 일반 추적은 베이스에 위임.
	super._physics_process(delta)
	queue_redraw()


func _on_contact_hit(_player: Node2D) -> void:
	# 접촉 시 플레이어에게 공격력 -20% 디버프(5s). 다양한 디버프 API 폴백.
	if not is_instance_valid(target):
		return
	if target.has_method("apply_attack_modifier"):
		target.apply_attack_modifier(_contact_debuff_value, _contact_debuff_duration)
		return
	if target.has_method("apply_attack_debuff"):
		target.apply_attack_debuff(_contact_debuff_value, _contact_debuff_duration)
		return
	if target.has_method("apply_debuff"):
		target.apply_debuff(&"attack_down", _contact_debuff_value, _contact_debuff_duration)
		return
	# 폴백: 플레이어 디버프 API 부재 시 약한 슬로우로 대체(공격력 디버프의 체감 근사).
	if target.has_method("apply_slow"):
		target.apply_slow(DEFAULT_ATTACK_SLOW_FALLBACK_MULT, _contact_debuff_duration)


func die() -> void:
	if is_dying:
		return
	# 사망 위치/씬/원본 데이터를 잡아둔 뒤, 베이스 die()가 queue_free()를 호출한다.
	var death_pos: Vector2 = global_position
	var death_scene: Node = get_tree().current_scene if get_tree() != null else null
	var origin_data: EnemyData = data
	var origin_script: Script = get_script()
	super.die()
	# 큐프리 이후에도 SceneTreeTimer는 살아 있음 — 재스폰 예약.
	if _respawn_delay <= 0.0:
		return
	if death_scene == null:
		return
	if not is_instance_valid(death_scene):
		return
	var spawn_pos: Vector2 = death_pos if _respawn_same_position else death_pos
	# 트리 차원에서 타이머 발급 — 자기 노드가 free된 뒤에도 콜백 가능.
	var tree: SceneTree = death_scene.get_tree()
	if tree == null:
		return
	var timer: SceneTreeTimer = tree.create_timer(_respawn_delay)
	timer.timeout.connect(_on_respawn_timer.bind(death_scene, spawn_pos, origin_data, origin_script))


func _on_respawn_timer(scene_ref: Node, spawn_pos: Vector2, origin_data: EnemyData, origin_script: Script) -> void:
	if scene_ref == null or not is_instance_valid(scene_ref):
		return
	# 핵심 오염원 파괴 시 리스폰 중지.
	if _respawn_stops_when_corruption and _is_corruption_destroyed(scene_ref):
		return
	if origin_script == null:
		return
	# EnemyBase는 CharacterBody2D 파생 — set_script 전에 실제 C++ 클래스가 일치해야 한다.
	var n: CharacterBody2D = CharacterBody2D.new()
	n.set_script(origin_script)
	if not (n is EnemyBase):
		n.queue_free()
		return
	var e: EnemyBase = n as EnemyBase
	e.data = origin_data
	scene_ref.add_child(e)
	e.global_position = spawn_pos


func _is_corruption_destroyed(scene_ref: Node) -> bool:
	if scene_ref == null:
		return false
	var tree: SceneTree = scene_ref.get_tree()
	if tree == null:
		return false
	# 그룹에 살아 있는 핵심 오염원이 하나도 없으면 파괴된 것으로 본다.
	var nodes: Array = tree.get_nodes_in_group(CORRUPTION_CORE_GROUP)
	if nodes.is_empty():
		# 핵심 오염원이 처음부터 없는 스테이지 — 보수적으로 false(리스폰 계속).
		return false
	for n in nodes:
		if n is Node and is_instance_valid(n):
			return false
	return true


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	# 본체 — 부드럽게 흩어지는 안개 원.
	draw_circle(Vector2.ZERO, FALLBACK_RADIUS, c)
	# 외곽 흔들림 — 두 겹의 옅은 호.
	var edge1: Color = Color(c.r, c.g, c.b, 0.40)
	var edge2: Color = Color(c.r, c.g, c.b, 0.25)
	draw_arc(Vector2.ZERO, FALLBACK_RADIUS + 2.0 + sin(_drift_phase) * 1.5, 0.0, TAU, 20, edge1, 1.0)
	draw_arc(Vector2.ZERO, FALLBACK_RADIUS + 5.0 + cos(_drift_phase * 1.3) * 2.0, 0.0, TAU, 24, edge2, 1.0)
	# 한 쌍의 흰 눈.
	draw_circle(Vector2(-4.0, -2.0), 1.6, EYE_COLOR)
	draw_circle(Vector2(4.0, -2.0), 1.6, EYE_COLOR)
