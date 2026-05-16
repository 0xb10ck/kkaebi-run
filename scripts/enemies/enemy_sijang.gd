extends EnemyBase

# M48 시장 도깨비 — 평소 호객 모션(좌우 흔들림), 플레이어가 flee_trigger_distance_px 이내로
# 접근하면 좌판 접고 도주(반대 방향 이동, 이속 그대로).
# 사망 시 coin_burst_chance(0.5) 확률로 환전 폭발 — 금화 ×coin_burst_gold_multiplier(3)
# 지급 + 자기 위치 반경 coin_burst_radius_px(50) 단발 coin_burst_damage(5).

const DEFAULT_FLEE_TRIGGER_PX: float = 150.0
const DEFAULT_COIN_BURST_CHANCE: float = 0.5
const DEFAULT_COIN_BURST_GOLD_MULT: int = 3
const DEFAULT_COIN_BURST_RADIUS_PX: float = 50.0
const DEFAULT_COIN_BURST_DAMAGE: int = 5
const DEFAULT_HAWK_WOBBLE_PX: float = 4.0
const DEFAULT_HAWK_WOBBLE_HZ: float = 1.5

const FALLBACK_COLOR: Color = Color(0.62, 0.45, 0.20, 1.0)
const FALLBACK_W: float = 16.0
const FALLBACK_H: float = 22.0
const HOOD_COLOR: Color = Color(0.45, 0.25, 0.15, 1.0)
const COIN_COLOR: Color = Color(0.95, 0.85, 0.30, 1.0)
const BURST_COLOR: Color = Color(0.95, 0.75, 0.20, 0.55)

enum State { HAWK, FLEE }

var _flee_trigger: float = DEFAULT_FLEE_TRIGGER_PX
var _coin_burst_chance: float = DEFAULT_COIN_BURST_CHANCE
var _coin_burst_gold_mult: int = DEFAULT_COIN_BURST_GOLD_MULT
var _coin_burst_radius: float = DEFAULT_COIN_BURST_RADIUS_PX
var _coin_burst_damage: int = DEFAULT_COIN_BURST_DAMAGE
var _coin_burst_enabled: bool = true
var _hawk_wobble_px: float = DEFAULT_HAWK_WOBBLE_PX
var _hawk_wobble_hz: float = DEFAULT_HAWK_WOBBLE_HZ

var _state: int = State.HAWK
var _wobble_phase: float = 0.0
var _hawk_origin_x: float = 0.0
var _origin_set: bool = false


func _ready() -> void:
	if data == null:
		max_hp = 35
		move_speed = 90.0
		contact_damage = 6
		exp_drop_value = 12
		coin_drop_value = 1
		coin_drop_chance = 0.80
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("coin_burst_on_death"):
			_coin_burst_enabled = bool(params["coin_burst_on_death"])
		if params.has("coin_burst_chance"):
			_coin_burst_chance = float(params["coin_burst_chance"])
		if params.has("coin_burst_gold_multiplier"):
			_coin_burst_gold_mult = int(params["coin_burst_gold_multiplier"])
		if params.has("coin_burst_radius_px"):
			_coin_burst_radius = float(params["coin_burst_radius_px"])
		if params.has("coin_burst_damage"):
			_coin_burst_damage = int(params["coin_burst_damage"])
	hp = max_hp
	_wobble_phase = randf() * TAU


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
			queue_redraw()
			return
	if not _origin_set:
		_hawk_origin_x = global_position.x
		_origin_set = true
	_wobble_phase = fmod(_wobble_phase + delta * TAU * _hawk_wobble_hz, TAU)
	var d: float = global_position.distance_to(target.global_position)
	if d <= _flee_trigger:
		_state = State.FLEE
	else:
		_state = State.HAWK
	match _state:
		State.HAWK:
			_run_hawk(delta)
		State.FLEE:
			_run_flee()
	# 접촉 데미지(스쳤을 때 처리) — 베이스 패턴 따라.
	if _contact_timer <= 0.0 and _contact_area:
		for body in _contact_area.get_overlapping_bodies():
			if body == target:
				_deal_contact_damage()
				break
	queue_redraw()


func _run_hawk(_delta: float) -> void:
	# 호객 모션 — 좌우 미세 이동. 본위치 ±_hawk_wobble_px.
	var wobble_x: float = sin(_wobble_phase) * _hawk_wobble_px
	var desired_x: float = _hawk_origin_x + wobble_x
	var dx: float = desired_x - global_position.x
	velocity = Vector2(dx * 4.0, 0.0)
	move_and_slide()


func _run_flee() -> void:
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var away: Vector2 = global_position - target.global_position
	if away.length_squared() <= 0.0001:
		away = Vector2.RIGHT
	else:
		away = away.normalized()
	velocity = away * move_speed * _slow_factor
	move_and_slide()
	# 도주 중에는 본위치를 따라 이동 — 안정 위치 갱신.
	_hawk_origin_x = global_position.x


func die() -> void:
	if is_dying:
		return
	# 환전 폭발 — 베이스 die() 이전에 보너스 금화/광역 데미지 처리(베이스가 queue_free 호출).
	if _coin_burst_enabled and randf() < _coin_burst_chance:
		_trigger_coin_burst()
	super.die()


func _trigger_coin_burst() -> void:
	var main: Node = get_tree().current_scene if get_tree() != null else null
	# 금화 ×_coin_burst_gold_mult 지급(베이스 보너스 외 별도).
	if main != null and main.has_method("on_coin_dropped"):
		var bonus_amount: int = maxi(1, coin_drop_value) * maxi(1, _coin_burst_gold_mult)
		main.on_coin_dropped(bonus_amount)
	# 반경 _coin_burst_radius 단발 _coin_burst_damage.
	if is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= _coin_burst_radius:
			if target.has_method("take_damage"):
				target.take_damage(_coin_burst_damage)


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	# 본체 — 상인.
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 두건.
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5 - 3.0), Vector2(FALLBACK_W, 4.0)), HOOD_COLOR)
	# 좌판 — HAWK 상태에서만 펼친 좌판 표시.
	if _state == State.HAWK:
		var tray: Color = Color(0.55, 0.40, 0.18, 1.0)
		draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5 - 3.0, FALLBACK_H * 0.30), Vector2(FALLBACK_W + 6.0, 2.0)), tray)
		# 좌판 위 엽전 ×3.
		draw_circle(Vector2(-FALLBACK_W * 0.30, FALLBACK_H * 0.25), 1.5, COIN_COLOR)
		draw_circle(Vector2(0.0, FALLBACK_H * 0.25), 1.5, COIN_COLOR)
		draw_circle(Vector2(FALLBACK_W * 0.30, FALLBACK_H * 0.25), 1.5, COIN_COLOR)
	else:
		# 도주 — 좌판 접힌 상태(엉덩이 뒤).
		draw_rect(Rect2(Vector2(0.0, FALLBACK_H * 0.0), Vector2(4.0, 6.0)), Color(0.55, 0.40, 0.18, 1.0))
