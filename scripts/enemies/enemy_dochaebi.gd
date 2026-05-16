extends EnemyBase

# M28 도채비 — 일반 추적.
# 뒤집기(Swap): 플레이어 정면 50px 이내에 있을 때 0.5초 예고 후 위치 교환. 쿨다운 6초.
# 사망 시: 자기 주변 60px 이내의 "도깨비 계열" 몬스터(group: dokkaebi)에게 공격력 +25%, 5초 버프.

const DEFAULT_SWAP_FRONT_DISTANCE_PX: float = 50.0
const DEFAULT_SWAP_TELEGRAPH_S: float = 0.5
const DEFAULT_SWAP_COOLDOWN_S: float = 6.0
const DEFAULT_DEATH_BUFF_RADIUS_PX: float = 60.0
const DEFAULT_DEATH_BUFF_ATTACK_BONUS: float = 0.25
const DEFAULT_DEATH_BUFF_DURATION_S: float = 5.0
const DEFAULT_DEATH_BUFF_FAMILY: String = "dokkaebi"

const DOKKAEBI_GROUP: StringName = &"dokkaebi"
const FRONT_ARC_DOT_THRESHOLD: float = 0.0  # 0이면 ±90도(반평면) — 플레이어 정면 반평면 내부.

const FALLBACK_COLOR: Color = Color(0.30, 0.20, 0.40, 1.0)
const FALLBACK_W: float = 26.0
const FALLBACK_H: float = 34.0

enum State { CHASE, SWAP_TELEGRAPH, SWAP_RESOLVE, COOLDOWN }

var _swap_front_distance: float = DEFAULT_SWAP_FRONT_DISTANCE_PX
var _swap_telegraph: float = DEFAULT_SWAP_TELEGRAPH_S
var _swap_cooldown: float = DEFAULT_SWAP_COOLDOWN_S
var _death_buff_radius: float = DEFAULT_DEATH_BUFF_RADIUS_PX
var _death_buff_bonus: float = DEFAULT_DEATH_BUFF_ATTACK_BONUS
var _death_buff_duration: float = DEFAULT_DEATH_BUFF_DURATION_S
var _death_buff_family: String = DEFAULT_DEATH_BUFF_FAMILY

var _state: int = State.CHASE
var _state_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _last_player_dir: Vector2 = Vector2.RIGHT


func _ready() -> void:
	if data == null:
		max_hp = 32
		move_speed = 70.0
		contact_damage = 9
		exp_drop_value = 10
		coin_drop_value = 1
		coin_drop_chance = 0.26
	super._ready()
	add_to_group(DOKKAEBI_GROUP)
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("swap_trigger_front_distance_px"):
			_swap_front_distance = float(params["swap_trigger_front_distance_px"])
		if params.has("swap_telegraph_s"):
			_swap_telegraph = float(params["swap_telegraph_s"])
		if params.has("swap_cooldown_s"):
			_swap_cooldown = float(params["swap_cooldown_s"])
		if params.has("death_buff_radius_px"):
			_death_buff_radius = float(params["death_buff_radius_px"])
		if params.has("death_buff_attack_bonus"):
			_death_buff_bonus = float(params["death_buff_attack_bonus"])
		if params.has("death_buff_duration_s"):
			_death_buff_duration = float(params["death_buff_duration_s"])
		if params.has("death_buff_target_family"):
			_death_buff_family = String(params["death_buff_target_family"])
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	if not is_instance_valid(target):
		target = _resolve_target()
		if not is_instance_valid(target):
			return
	_update_player_dir()
	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	match _state:
		State.CHASE:
			_run_chase(delta)
		State.SWAP_TELEGRAPH:
			_run_swap_telegraph(delta)
		State.SWAP_RESOLVE:
			_run_swap_resolve(delta)
		State.COOLDOWN:
			_run_cooldown(delta)
	queue_redraw()


func _update_player_dir() -> void:
	if target is CharacterBody2D:
		var v: Vector2 = (target as CharacterBody2D).velocity
		if v.length_squared() > 1.0:
			_last_player_dir = v.normalized()


func _run_chase(delta: float) -> void:
	super._physics_process(delta)
	# 트리거: 플레이어 정면(=진행방향 반평면) 50px 이내에 있을 때.
	if _cooldown_timer > 0.0:
		return
	if not is_instance_valid(target):
		return
	var to_self: Vector2 = global_position - target.global_position
	var d: float = to_self.length()
	if d > _swap_front_distance:
		return
	if d > 0.001:
		var dot: float = to_self.normalized().dot(_last_player_dir)
		if dot < FRONT_ARC_DOT_THRESHOLD:
			return
	_state = State.SWAP_TELEGRAPH
	_state_timer = _swap_telegraph


func _run_swap_telegraph(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	_state_timer = maxf(0.0, _state_timer - delta)
	if _state_timer <= 0.0:
		_state = State.SWAP_RESOLVE


func _run_swap_resolve(_delta: float) -> void:
	if is_instance_valid(target):
		var my_pos: Vector2 = global_position
		global_position = target.global_position
		target.global_position = my_pos
	_state = State.COOLDOWN
	_cooldown_timer = _swap_cooldown


func _run_cooldown(delta: float) -> void:
	# 쿨다운 동안에도 평소처럼 추적.
	super._physics_process(delta)
	if _cooldown_timer <= 0.0:
		_state = State.CHASE


func die() -> void:
	if is_dying:
		return
	_apply_death_buff_to_dokkaebi_allies()
	super.die()


func _apply_death_buff_to_dokkaebi_allies() -> void:
	# group(dokkaebi)에 속한 주변 도깨비 계열에게 공격력 +25% / 5초 버프.
	var allies: Array = get_tree().get_nodes_in_group(DOKKAEBI_GROUP)
	for a in allies:
		if a == self:
			continue
		if not is_instance_valid(a):
			continue
		if not (a is Node2D):
			continue
		if a is EnemyBase and (a as EnemyBase).is_dying:
			continue
		var n2d: Node2D = a as Node2D
		if n2d.global_position.distance_to(global_position) > _death_buff_radius:
			continue
		_apply_attack_buff_to(a)


func _apply_attack_buff_to(node: Object) -> void:
	# 1) 노드가 명시적 버프 API를 제공하면 사용.
	if node.has_method("apply_attack_buff"):
		node.apply_attack_buff(_death_buff_bonus, _death_buff_duration)
		return
	# 2) 폴백: contact_damage를 일시 가산하고 타이머로 원복.
	if not ("contact_damage" in node):
		return
	var base_dmg: int = int(node.contact_damage)
	var bonus: int = int(round(float(base_dmg) * _death_buff_bonus))
	if bonus <= 0:
		return
	node.contact_damage = base_dmg + bonus
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var timer: SceneTreeTimer = tree.create_timer(_death_buff_duration)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(node):
			return
		if "contact_damage" in node:
			node.contact_damage = max(0, int(node.contact_damage) - bonus)
	)


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	# 검보랏빛 몸체.
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 한쪽 뿔(오른쪽만, 왼쪽은 부러진 형태).
	draw_line(Vector2(FALLBACK_W * 0.25, -FALLBACK_H * 0.5), Vector2(FALLBACK_W * 0.35, -FALLBACK_H * 0.7), Color(0.85, 0.75, 0.55, 1.0), 1.8)
	draw_line(Vector2(-FALLBACK_W * 0.25, -FALLBACK_H * 0.5), Vector2(-FALLBACK_W * 0.30, -FALLBACK_H * 0.58), Color(0.85, 0.75, 0.55, 1.0), 1.4)
	# 빛나는 눈(노랑).
	draw_circle(Vector2(-FALLBACK_W * 0.18, -FALLBACK_H * 0.22), 1.6, Color(1.0, 0.95, 0.4, 1.0))
	draw_circle(Vector2(FALLBACK_W * 0.18, -FALLBACK_H * 0.22), 1.6, Color(1.0, 0.95, 0.4, 1.0))
	# 부러진 방망이(오른쪽 갈색 짧은 막대).
	draw_line(Vector2(FALLBACK_W * 0.40, FALLBACK_H * 0.10), Vector2(FALLBACK_W * 0.55, FALLBACK_H * 0.30), Color(0.45, 0.30, 0.18, 1.0), 2.0)
	if _state == State.SWAP_TELEGRAPH:
		# 예고: 자기와 플레이어 사이 점선.
		if is_instance_valid(target):
			var local_target: Vector2 = target.global_position - global_position
			draw_line(Vector2.ZERO, local_target, Color(0.95, 0.5, 1.0, 0.7), 1.4)
			draw_arc(local_target, 8.0, 0.0, TAU, 16, Color(0.95, 0.5, 1.0, 0.85), 1.2)
