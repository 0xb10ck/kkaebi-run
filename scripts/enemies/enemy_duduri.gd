extends EnemyBase

# M09 두두리 — 200~300px 거리 유지. 2초마다 자기 중심 음파 AoE. 주변 챕터1 몹에 이속 버프 오라.

const DEFAULT_KEEP_MIN_PX: float = 200.0
const DEFAULT_KEEP_MAX_PX: float = 300.0
const DEFAULT_DRUM_AURA_PX: float = 240.0
const DEFAULT_AURA_SPEED_MULT: float = 1.25
const DEFAULT_SHOCKWAVE_KNOCKBACK_S: float = 0.3
const AURA_REFRESH_INTERVAL_S: float = 0.5

const FALLBACK_COLOR: Color = Color(0.78, 0.45, 0.20, 1.0)
const FALLBACK_RADIUS: float = 14.0

var _keep_min: float = DEFAULT_KEEP_MIN_PX
var _keep_max: float = DEFAULT_KEEP_MAX_PX
var _aura_radius: float = DEFAULT_DRUM_AURA_PX
var _aura_speed_mult: float = DEFAULT_AURA_SPEED_MULT
var _shock_knockback_s: float = DEFAULT_SHOCKWAVE_KNOCKBACK_S

var _shock_cd: float = 2.0
var _shock_timer: float = 0.0
var _shock_telegraph_timer: float = 0.0
var _is_telegraphing: bool = false
var _shock_radius: float = 100.0
var _shock_damage: int = 5

var _aura_refresh_timer: float = 0.0
var _buffed_allies: Array[WeakRef] = []


func _ready() -> void:
	if data == null:
		max_hp = 22
		move_speed = 45.0
		contact_damage = 3
		exp_drop_value = 5
		coin_drop_value = 1
		coin_drop_chance = 0.18
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("keep_distance_min_px"):
			_keep_min = float(params["keep_distance_min_px"])
		if params.has("keep_distance_max_px"):
			_keep_max = float(params["keep_distance_max_px"])
		if params.has("drum_aura_radius_px"):
			_aura_radius = float(params["drum_aura_radius_px"])
		if params.has("drum_aura_speed_buff_mult"):
			_aura_speed_mult = float(params["drum_aura_speed_buff_mult"])
		if params.has("shockwave_knockback_duration_s"):
			_shock_knockback_s = float(params["shockwave_knockback_duration_s"])
		if data.ranged_cooldown > 0.0:
			_shock_cd = data.ranged_cooldown
		if data.ranged_range_px > 0.0:
			_shock_radius = data.ranged_range_px
		if data.ranged_damage > 0:
			_shock_damage = data.ranged_damage
	_shock_timer = _shock_cd
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_aura_refresh_timer = maxf(0.0, _aura_refresh_timer - delta)
	if _aura_refresh_timer <= 0.0:
		_aura_refresh_timer = AURA_REFRESH_INTERVAL_S
		_refresh_aura()

	if _is_telegraphing:
		_shock_telegraph_timer = maxf(0.0, _shock_telegraph_timer - delta)
		if _shock_telegraph_timer <= 0.0:
			_is_telegraphing = false
			_unleash_shockwave()
			_shock_timer = _shock_cd
	else:
		_shock_timer = maxf(0.0, _shock_timer - delta)
		if _shock_timer <= 0.0:
			_is_telegraphing = true
			var tel: float = data.ranged_telegraph if data != null else 0.15
			_shock_telegraph_timer = tel

	_run_keep_distance(delta)
	queue_redraw()


func _run_keep_distance(delta: float) -> void:
	_contact_timer = maxf(0.0, _contact_timer - delta)
	if not is_instance_valid(target):
		target = _resolve_target()
		if not is_instance_valid(target):
			return
	var to_target: Vector2 = target.global_position - global_position
	var dist: float = to_target.length()
	var dir: Vector2 = Vector2.ZERO
	if dist > _keep_max:
		dir = to_target.normalized()
	elif dist < _keep_min:
		dir = -to_target.normalized()
	# 거리 범위 내면 천천히 횡이동(직각 방향).
	else:
		var tangent: Vector2 = Vector2(-to_target.y, to_target.x).normalized()
		dir = tangent * 0.5
	velocity = dir * move_speed * _slow_factor
	move_and_slide()


func _unleash_shockwave() -> void:
	if is_instance_valid(target):
		var d: float = global_position.distance_to(target.global_position)
		if d <= _shock_radius:
			if target.has_method("take_damage"):
				target.take_damage(_shock_damage)
			# 넉백 = stun으로 대체 (player apply_stun이 있다면).
			if target.has_method("apply_stun"):
				target.apply_stun(_shock_knockback_s)


func _refresh_aura() -> void:
	# 기존 버프 대상에서 effect 해제는 일괄 — 매 갱신마다 buff 적용을 재계산.
	# 단순 구현: 매 0.5초마다 현재 오라 안의 적의 move_speed를 일시 부스트.
	# 버프 누적 방지를 위해 base_move_speed 저장 필드를 활용.
	for ref in _buffed_allies:
		var prev: Node = ref.get_ref()
		if prev != null and prev is EnemyBase and prev != self:
			var meta_key: StringName = &"duduri_base_speed"
			if (prev as Node).has_meta(meta_key):
				(prev as EnemyBase).move_speed = (prev as Node).get_meta(meta_key)
				(prev as Node).remove_meta(meta_key)
	_buffed_allies.clear()

	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self:
			continue
		if not (e is EnemyBase):
			continue
		var eb: EnemyBase = e
		if eb.is_dying:
			continue
		var d2: EnemyData = eb.data
		if d2 == null:
			continue
		# chapter1 일반 몹만 대상.
		if not (1 in d2.chapters):
			continue
		if (eb as Node2D).global_position.distance_to(global_position) <= _aura_radius:
			var meta_key2: StringName = &"duduri_base_speed"
			if not (eb as Node).has_meta(meta_key2):
				(eb as Node).set_meta(meta_key2, eb.move_speed)
				eb.move_speed = eb.move_speed * _aura_speed_mult
			_buffed_allies.append(weakref(eb))


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	draw_circle(Vector2.ZERO, FALLBACK_RADIUS, c)
	# 북 표면.
	draw_arc(Vector2.ZERO, FALLBACK_RADIUS * 0.6, 0.0, TAU, 16, Color(0.5, 0.2, 0.1, 1.0), 2.0)
	if _is_telegraphing:
		draw_arc(Vector2.ZERO, _shock_radius, 0.0, TAU, 48, Color(1.0, 0.5, 0.2, 0.5), 2.0)
