extends EnemyBase

# M35 풍백 — 일반 추적. 부채를 휘둘러 직선 바람 투사체 발사.
# 발사 전 wind_homing_track_duration_s 동안 타겟의 현재 위치를 계속 추적하다가
# 트랙 종료 시점의 방향으로 직선 발사한다. 발사 후엔 직선 진행(homing 없음).
# 패시브: 받는 원거리 데미지(공격자에 is_ranged 표식이 있으면) ×0.5.

const ENEMY_PROJECTILE: PackedScene = preload("res://scenes/enemies/enemy_projectile.tscn")

const DEFAULT_WIND_WIDTH_PX: float = 32.0
const DEFAULT_WIND_LENGTH_PX: float = 200.0
const DEFAULT_HOMING_TRACK_S: float = 0.2
const DEFAULT_RANGED_DMG_TAKEN_MULT: float = 0.5
const DEFAULT_RANGED_COOLDOWN_S: float = 1.8
const DEFAULT_RANGED_RANGE_PX: float = 200.0
const DEFAULT_RANGED_SPEED: float = 260.0
const DEFAULT_RANGED_DAMAGE: int = 12

const WIND_COLOR: Color = Color(0.70, 0.85, 0.95, 0.85)

const FALLBACK_COLOR: Color = Color(0.55, 0.40, 0.25, 1.0)
const FALLBACK_W: float = 22.0
const FALLBACK_H: float = 28.0

enum State { CHASE, TELEGRAPH }

var _wind_width: float = DEFAULT_WIND_WIDTH_PX
var _wind_length: float = DEFAULT_WIND_LENGTH_PX
var _homing_track: float = DEFAULT_HOMING_TRACK_S
var _ranged_dmg_taken_mult: float = DEFAULT_RANGED_DMG_TAKEN_MULT
var _attack_cd: float = DEFAULT_RANGED_COOLDOWN_S
var _ranged_range: float = DEFAULT_RANGED_RANGE_PX
var _ranged_speed: float = DEFAULT_RANGED_SPEED
var _ranged_damage: int = DEFAULT_RANGED_DAMAGE

var _state: int = State.CHASE
var _state_timer: float = 0.0
var _cd_timer: float = 0.0
var _aim_dir: Vector2 = Vector2.RIGHT


func _ready() -> void:
	if data == null:
		max_hp = 48
		move_speed = 70.0
		contact_damage = 7
		exp_drop_value = 17
		coin_drop_value = 1
		coin_drop_chance = 0.38
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("wind_projectile_width_px"):
			_wind_width = float(params["wind_projectile_width_px"])
		if params.has("wind_projectile_length_px"):
			_wind_length = float(params["wind_projectile_length_px"])
		if params.has("wind_homing_track_duration_s"):
			_homing_track = float(params["wind_homing_track_duration_s"])
		if params.has("ranged_damage_taken_mult"):
			_ranged_dmg_taken_mult = float(params["ranged_damage_taken_mult"])
		if data.ranged_cooldown > 0.0:
			_attack_cd = data.ranged_cooldown
		if data.ranged_range_px > 0.0:
			_ranged_range = data.ranged_range_px
		if data.ranged_projectile_speed > 0.0:
			_ranged_speed = data.ranged_projectile_speed
		if data.ranged_damage > 0:
			_ranged_damage = data.ranged_damage
	hp = max_hp
	_cd_timer = _attack_cd


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_contact_timer = maxf(0.0, _contact_timer - delta)
	if _slow_remaining > 0.0:
		_slow_remaining -= delta
		if _slow_remaining <= 0.0:
			_slow_remaining = 0.0
			_slow_factor = 1.0
	if _stun_remaining > 0.0:
		_stun_remaining = maxf(0.0, _stun_remaining - delta)
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return
	if not is_instance_valid(target):
		target = _resolve_target()
		if not is_instance_valid(target):
			velocity = Vector2.ZERO
			move_and_slide()
			return
	_cd_timer = maxf(0.0, _cd_timer - delta)
	match _state:
		State.CHASE:
			_run_chase()
		State.TELEGRAPH:
			_run_telegraph(delta)
	queue_redraw()


func _run_chase() -> void:
	var to_t: Vector2 = target.global_position - global_position
	var d: float = to_t.length()
	if d > 0.001:
		velocity = (to_t / d) * move_speed * _slow_factor
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if _cd_timer <= 0.0 and d <= _ranged_range:
		_enter_telegraph()


func _enter_telegraph() -> void:
	_state = State.TELEGRAPH
	_state_timer = _homing_track
	_aim_dir = (target.global_position - global_position).normalized()


func _run_telegraph(delta: float) -> void:
	# 약한 호밍 — 트랙 동안 플레이어 현재 위치를 계속 따라간다. 발사는 트랙 종료 시점의 방향으로.
	velocity = Vector2.ZERO
	move_and_slide()
	var v: Vector2 = target.global_position - global_position
	if v.length_squared() > 0.0001:
		_aim_dir = v.normalized()
	_state_timer = maxf(0.0, _state_timer - delta)
	if _state_timer <= 0.0:
		_fire_wind()
		_state = State.CHASE
		_cd_timer = _attack_cd


func _fire_wind() -> void:
	var p: EnemyProjectile = ENEMY_PROJECTILE.instantiate()
	p.speed = _ranged_speed
	p.damage = _ranged_damage
	p.lifetime = _wind_length / maxf(1.0, _ranged_speed)
	p.direction = _aim_dir
	p.hit_radius = _wind_width * 0.5
	p.color = WIND_COLOR
	p.homing_target = null
	var scene: Node = get_tree().current_scene
	if scene != null:
		scene.add_child(p)
	else:
		get_parent().add_child(p)
	p.global_position = global_position + _aim_dir * (FALLBACK_W * 0.5 + 4.0)


func take_damage(amount: int, attacker: Object = null) -> void:
	if is_dying:
		return
	var scaled: int = amount
	if _is_ranged_attacker(attacker):
		scaled = maxi(0, int(round(float(amount) * _ranged_dmg_taken_mult)))
	super.take_damage(scaled, attacker)


func _is_ranged_attacker(attacker: Object) -> bool:
	if attacker == null:
		return false
	# 명시적 플래그/메타가 우선.
	if "is_ranged" in attacker:
		return bool(attacker.is_ranged)
	if attacker is Node and (attacker as Node).has_meta(&"ranged_attack"):
		return bool((attacker as Node).get_meta(&"ranged_attack"))
	# 폴백 — 플레이어 본체에 의한 직접 타격이 아니면 원거리로 간주.
	if attacker is Node and (attacker as Node).is_in_group("player"):
		return false
	return true


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 푸른 바람 망토.
	var cape: Color = Color(0.35, 0.55, 0.85, 0.85)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5 - 2.0, -FALLBACK_H * 0.2), Vector2(FALLBACK_W + 4.0, FALLBACK_H * 0.5)), cape)
	# 갈색 두건.
	var hood: Color = Color(0.45, 0.30, 0.18, 1.0)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.45, -FALLBACK_H * 0.5 - 4.0), Vector2(FALLBACK_W * 0.9, 5.0)), hood)
	# 양손 부채.
	var fan: Color = Color(0.95, 0.92, 0.80, 1.0)
	draw_circle(Vector2(-FALLBACK_W * 0.5 - 3.0, -2.0), 3.5, fan)
	draw_circle(Vector2(FALLBACK_W * 0.5 + 3.0, -2.0), 3.5, fan)
	if _state == State.TELEGRAPH:
		# 발사 직전 호밍 예고 — 조준선 + 폭 표시.
		var warn: Color = Color(0.85, 0.95, 1.0, 0.55)
		var aim: Vector2 = _aim_dir * _wind_length
		draw_line(Vector2.ZERO, aim, warn, 1.5)
		var perp: Vector2 = Vector2(-_aim_dir.y, _aim_dir.x) * (_wind_width * 0.5)
		draw_line(perp, aim + perp, warn, 1.0)
		draw_line(-perp, aim - perp, warn, 1.0)
