extends EnemyBase

# M46 흑룡 새끼 — 공중 부유 추적(지상 함정/장판류 면역). 사거리 breath_range_px(300)에서
# 직선 검은 화염 입김(폭 breath_width_px 40, 길이 breath_length_px 200, 단발 breath_damage 18).
# enemy_projectile 재사용 + 자체 박스 히트 검사로 광폭 라인을 표현.
# 매 mist_burst_interval_s(6.0s)마다 자기 중심 반경 mist_burst_radius_px(100) 검은 안개 폭발 —
# mist_burst_telegraph_s(1.0s) 예고 후 폭발: mist_burst_damage(14) + 명중 시 mist_burst_blur_duration_s(1.5s)
# 시야 흐림 디버프(apply_vision_blur 폴백 시 약한 슬로우).

const ENEMY_PROJECTILE: PackedScene = preload("res://scenes/enemies/enemy_projectile.tscn")

const DEFAULT_BREATH_WIDTH_PX: float = 40.0
const DEFAULT_BREATH_LENGTH_PX: float = 200.0
const DEFAULT_BREATH_DAMAGE: int = 18
const DEFAULT_BREATH_RANGE_PX: float = 300.0
const DEFAULT_BREATH_COOLDOWN_S: float = 6.0
const DEFAULT_BREATH_TELEGRAPH_S: float = 0.3
const DEFAULT_BREATH_SPEED_PX: float = 220.0
const DEFAULT_MIST_INTERVAL_S: float = 6.0
const DEFAULT_MIST_RADIUS_PX: float = 100.0
const DEFAULT_MIST_TELEGRAPH_S: float = 1.0
const DEFAULT_MIST_DAMAGE: int = 14
const DEFAULT_MIST_BLUR_DURATION_S: float = 1.5
const DEFAULT_BLUR_SLOW_FALLBACK_MULT: float = 0.6

const FALLBACK_COLOR: Color = Color(0.06, 0.05, 0.10, 1.0)
const FALLBACK_W: float = 24.0
const FALLBACK_H: float = 20.0
const BREATH_COLOR: Color = Color(0.10, 0.05, 0.15, 0.95)
const MIST_COLOR: Color = Color(0.20, 0.15, 0.25, 0.45)
const HORN_COLOR: Color = Color(0.60, 0.55, 0.55, 1.0)
const EYE_COLOR: Color = Color(0.95, 0.20, 0.25, 1.0)

var _breath_width: float = DEFAULT_BREATH_WIDTH_PX
var _breath_length: float = DEFAULT_BREATH_LENGTH_PX
var _breath_damage: int = DEFAULT_BREATH_DAMAGE
var _breath_range: float = DEFAULT_BREATH_RANGE_PX
var _breath_cooldown: float = DEFAULT_BREATH_COOLDOWN_S
var _breath_telegraph: float = DEFAULT_BREATH_TELEGRAPH_S
var _breath_speed: float = DEFAULT_BREATH_SPEED_PX
var _mist_interval: float = DEFAULT_MIST_INTERVAL_S
var _mist_radius: float = DEFAULT_MIST_RADIUS_PX
var _mist_telegraph: float = DEFAULT_MIST_TELEGRAPH_S
var _mist_damage: int = DEFAULT_MIST_DAMAGE
var _mist_blur_duration: float = DEFAULT_MIST_BLUR_DURATION_S
var _airborne: bool = true
var _immune_ground_traps: bool = true

var _breath_cd_timer: float = 0.0
var _mist_cd_timer: float = 0.0
var _mist_telegraph_timer: float = 0.0
var _is_mist_telegraphing: bool = false
var _breath_flash: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 100
		move_speed = 75.0
		contact_damage = 16
		exp_drop_value = 32
		coin_drop_value = 1
		coin_drop_chance = 0.60
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("breath_width_px"):
			_breath_width = float(params["breath_width_px"])
		if params.has("breath_length_px"):
			_breath_length = float(params["breath_length_px"])
		if params.has("breath_damage"):
			_breath_damage = int(params["breath_damage"])
		if params.has("breath_range_px"):
			_breath_range = float(params["breath_range_px"])
		if params.has("breath_cooldown_s"):
			_breath_cooldown = float(params["breath_cooldown_s"])
		if params.has("mist_burst_interval_s"):
			_mist_interval = float(params["mist_burst_interval_s"])
		if params.has("mist_burst_radius_px"):
			_mist_radius = float(params["mist_burst_radius_px"])
		if params.has("mist_burst_telegraph_s"):
			_mist_telegraph = float(params["mist_burst_telegraph_s"])
		if params.has("mist_burst_damage"):
			_mist_damage = int(params["mist_burst_damage"])
		if params.has("mist_burst_blur_duration_s"):
			_mist_blur_duration = float(params["mist_burst_blur_duration_s"])
		if params.has("airborne"):
			_airborne = bool(params["airborne"])
		if params.has("immune_ground_traps"):
			_immune_ground_traps = bool(params["immune_ground_traps"])
		if data.ranged_range_px > 0.0:
			_breath_range = data.ranged_range_px
		if data.ranged_damage > 0:
			_breath_damage = data.ranged_damage
		if data.ranged_cooldown > 0.0:
			_breath_cooldown = data.ranged_cooldown
		if data.ranged_telegraph > 0.0:
			_breath_telegraph = data.ranged_telegraph
	hp = max_hp
	_breath_cd_timer = _breath_cooldown
	_mist_cd_timer = _mist_interval
	if _airborne:
		add_to_group("airborne")


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_breath_cd_timer = maxf(0.0, _breath_cd_timer - delta)
	if _breath_flash > 0.0:
		_breath_flash = maxf(0.0, _breath_flash - delta)
	# 안개 폭발 사이클 — 추적 가능 여부와 무관하게 진행.
	if _is_mist_telegraphing:
		_mist_telegraph_timer = maxf(0.0, _mist_telegraph_timer - delta)
		if _mist_telegraph_timer <= 0.0:
			_execute_mist_burst()
			_is_mist_telegraphing = false
			_mist_cd_timer = _mist_interval
	else:
		_mist_cd_timer = maxf(0.0, _mist_cd_timer - delta)
		if _mist_cd_timer <= 0.0:
			_is_mist_telegraphing = true
			_mist_telegraph_timer = _mist_telegraph
	# 추적/접촉/슬로우/스턴은 베이스 위임 — 공중 부유는 별도 처리 없음(이동 패턴 동일).
	super._physics_process(delta)
	# 사거리 안이면 화염 입김 발사.
	if _breath_cd_timer <= 0.0 and is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= _breath_range:
			_fire_breath()
			_breath_cd_timer = _breath_cooldown
	queue_redraw()


func _fire_breath() -> void:
	if not is_instance_valid(target):
		return
	var dir: Vector2 = (target.global_position - global_position)
	if dir.length_squared() <= 0.0001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	# enemy_projectile 재사용 — 가시 위주. 즉시 박스 히트 검사로 광폭 라인 데미지 처리.
	var p: EnemyProjectile = ENEMY_PROJECTILE.instantiate()
	p.speed = _breath_speed
	p.damage = _breath_damage
	p.lifetime = _breath_length / maxf(1.0, _breath_speed)
	p.direction = dir
	p.hit_radius = maxf(8.0, _breath_width * 0.4)
	p.color = BREATH_COLOR
	var scene: Node = get_tree().current_scene
	if scene != null:
		scene.add_child(p)
	else:
		get_parent().add_child(p)
	p.global_position = global_position
	# 광폭 라인 단발 — 라인 박스 안에 있으면 즉시 1회 적중.
	var right: Vector2 = Vector2(dir.y, -dir.x)
	var rel: Vector2 = target.global_position - global_position
	var local_y: float = rel.dot(dir)
	var local_x: float = rel.dot(right)
	if local_y >= 0.0 and local_y <= _breath_length and absf(local_x) <= _breath_width * 0.5:
		if target.has_method("take_damage"):
			target.take_damage(_breath_damage)
	_breath_flash = 0.30


func _execute_mist_burst() -> void:
	if not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) <= _mist_radius:
		if target.has_method("take_damage"):
			target.take_damage(_mist_damage)
		_apply_vision_blur()


func _apply_vision_blur() -> void:
	if not is_instance_valid(target):
		return
	if target.has_method("apply_vision_blur"):
		target.apply_vision_blur(_mist_blur_duration)
		return
	# 폴백: 시야 흐림 컴포넌트 부재 시 약한 슬로우로 대체.
	if target.has_method("apply_slow"):
		target.apply_slow(DEFAULT_BLUR_SLOW_FALLBACK_MULT, _mist_blur_duration)


func take_damage(amount: int, attacker: Object = null) -> void:
	if is_dying:
		return
	# 지상 함정/장판류 면역 — 공격자가 trap/ground 그룹이면 무시.
	if _immune_ground_traps and attacker != null and attacker is Node:
		var atk: Node = attacker as Node
		if atk.is_in_group("trap") or atk.is_in_group("ground_trap") or atk.is_in_group("ground"):
			return
	super.take_damage(amount, attacker)


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	if _breath_flash > 0.0:
		c = c.lerp(BREATH_COLOR, 0.30)
	# 가로로 약간 긴 본체 — 작은 뱀-드래곤.
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 두 작은 뿔.
	draw_line(Vector2(-FALLBACK_W * 0.25, -FALLBACK_H * 0.5), Vector2(-FALLBACK_W * 0.25, -FALLBACK_H * 0.5 - 4.0), HORN_COLOR, 2.0)
	draw_line(Vector2(FALLBACK_W * 0.25, -FALLBACK_H * 0.5), Vector2(FALLBACK_W * 0.25, -FALLBACK_H * 0.5 - 4.0), HORN_COLOR, 2.0)
	# 빨간 눈.
	draw_circle(Vector2(-FALLBACK_W * 0.20, -FALLBACK_H * 0.15), 1.6, EYE_COLOR)
	draw_circle(Vector2(FALLBACK_W * 0.20, -FALLBACK_H * 0.15), 1.6, EYE_COLOR)
	# 입 — 검은 안개 흘러나옴.
	draw_circle(Vector2(FALLBACK_W * 0.45, FALLBACK_H * 0.10), 2.0, BREATH_COLOR)
	# 부유 표식 — 그림자 원(아래쪽).
	draw_arc(Vector2(0.0, FALLBACK_H * 0.5 + 4.0), 6.0, 0.0, TAU, 12, Color(0.05, 0.05, 0.08, 0.45), 1.0)
	# 안개 폭발 예고.
	if _is_mist_telegraphing:
		var prog: float = 1.0 - clampf(_mist_telegraph_timer / maxf(0.001, _mist_telegraph), 0.0, 1.0)
		var warn: Color = Color(0.30, 0.20, 0.40, 0.20 + 0.45 * prog)
		draw_arc(Vector2.ZERO, _mist_radius, 0.0, TAU, 40, warn, 2.0)
		draw_circle(Vector2.ZERO, _mist_radius * (0.3 + 0.7 * prog), MIST_COLOR)
