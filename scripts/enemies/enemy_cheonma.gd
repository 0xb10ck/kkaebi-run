extends EnemyBase

# M39 천마 — 곡선 우회 추적(이속 120). 발굽 두드림 + 직선 돌격.
# 곡선 이동: 플레이어 방향 벡터에 수직 성분을 일정 비율로 섞어 큰 곡선 궤적으로 접근.
# 발굽: 일정 쿨다운마다 플레이어 발밑에 60×60 균열 placeholder 생성 → hoof_patch_fuse_s 후
#       화(火) 속성 도트 영역(데미지 dps/초, hoof_patch_duration_s 지속)으로 발화.
# 5초마다 직선 돌격: charge_duration_s 동안 이속 ×charge_speed_mult, 종료 시 일반 상태 복귀.

const DEFAULT_HOOF_PATCH_SIZE_PX: float = 60.0
const DEFAULT_HOOF_PATCH_FUSE_S: float = 2.0
const DEFAULT_HOOF_PATCH_DURATION_S: float = 3.0
const DEFAULT_HOOF_PATCH_DPS: int = 4
const DEFAULT_HOOF_PATCH_ELEMENT: int = GameEnums.Element.FIRE
const DEFAULT_HOOF_PATCH_COOLDOWN_S: float = 3.0
const DEFAULT_CHARGE_INTERVAL_S: float = 5.0
const DEFAULT_CHARGE_SPEED_MULT: float = 2.0
const DEFAULT_CHARGE_DURATION_S: float = 1.2

const CURVE_TANGENT_BLEND: float = 0.35

const FALLBACK_COLOR: Color = Color(0.10, 0.10, 0.15, 1.0)
const FALLBACK_W: float = 32.0
const FALLBACK_H: float = 22.0

enum State { ROAM, CHARGE }

var _patch_size: float = DEFAULT_HOOF_PATCH_SIZE_PX
var _patch_fuse: float = DEFAULT_HOOF_PATCH_FUSE_S
var _patch_duration: float = DEFAULT_HOOF_PATCH_DURATION_S
var _patch_dps: int = DEFAULT_HOOF_PATCH_DPS
var _patch_element: int = DEFAULT_HOOF_PATCH_ELEMENT
var _patch_cooldown: float = DEFAULT_HOOF_PATCH_COOLDOWN_S
var _charge_interval: float = DEFAULT_CHARGE_INTERVAL_S
var _charge_speed_mult: float = DEFAULT_CHARGE_SPEED_MULT
var _charge_duration: float = DEFAULT_CHARGE_DURATION_S

var _state: int = State.ROAM
var _state_timer: float = 0.0
var _patch_cd_timer: float = 0.0
var _charge_cd_timer: float = 0.0
var _charge_dir: Vector2 = Vector2.RIGHT
var _tangent_sign: float = 1.0


func _ready() -> void:
	if data == null:
		max_hp = 60
		move_speed = 120.0
		contact_damage = 13
		exp_drop_value = 20
		coin_drop_value = 1
		coin_drop_chance = 0.40
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("hoof_patch_size_px"):
			_patch_size = float(params["hoof_patch_size_px"])
		if params.has("hoof_patch_fuse_s"):
			_patch_fuse = float(params["hoof_patch_fuse_s"])
		if params.has("hoof_patch_duration_s"):
			_patch_duration = float(params["hoof_patch_duration_s"])
		if params.has("hoof_patch_dps"):
			_patch_dps = int(params["hoof_patch_dps"])
		if params.has("hoof_patch_element"):
			_patch_element = int(params["hoof_patch_element"])
		if params.has("charge_interval_s"):
			_charge_interval = float(params["charge_interval_s"])
		if params.has("charge_speed_mult"):
			_charge_speed_mult = float(params["charge_speed_mult"])
		if params.has("charge_duration_s"):
			_charge_duration = float(params["charge_duration_s"])
		if data.ranged_cooldown > 0.0:
			_patch_cooldown = data.ranged_cooldown
	hp = max_hp
	_patch_cd_timer = _patch_cooldown
	_charge_cd_timer = _charge_interval
	_tangent_sign = 1.0 if randf() < 0.5 else -1.0


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
	_patch_cd_timer = maxf(0.0, _patch_cd_timer - delta)
	_charge_cd_timer = maxf(0.0, _charge_cd_timer - delta)
	match _state:
		State.ROAM:
			_run_roam()
			if _charge_cd_timer <= 0.0:
				_enter_charge()
			elif _patch_cd_timer <= 0.0:
				_drop_patch()
				_patch_cd_timer = _patch_cooldown
		State.CHARGE:
			_run_charge(delta)
	_handle_contact_on_charge()
	queue_redraw()


func _run_roam() -> void:
	var to_t: Vector2 = target.global_position - global_position
	var d: float = to_t.length()
	if d <= 0.001:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var dir: Vector2 = to_t / d
	# 큰 곡선 — 플레이어 방향 + 수직 접선 성분 블렌드.
	var tangent: Vector2 = Vector2(-dir.y, dir.x) * _tangent_sign
	var blend: Vector2 = dir * (1.0 - CURVE_TANGENT_BLEND) + tangent * CURVE_TANGENT_BLEND
	if blend.length_squared() > 0.0001:
		blend = blend.normalized()
	velocity = blend * move_speed * _slow_factor
	move_and_slide()


func _enter_charge() -> void:
	_state = State.CHARGE
	_state_timer = _charge_duration
	var v: Vector2 = target.global_position - global_position
	if v.length_squared() > 0.0001:
		_charge_dir = v.normalized()
	else:
		_charge_dir = Vector2.RIGHT


func _run_charge(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	velocity = _charge_dir * move_speed * _charge_speed_mult * _slow_factor
	move_and_slide()
	if _state_timer <= 0.0:
		_state = State.ROAM
		_charge_cd_timer = _charge_interval
		_tangent_sign = -_tangent_sign


func _handle_contact_on_charge() -> void:
	# 돌격 중에도 접촉 데미지 적용 — 베이스의 ContactArea가 있으면 사용, 없으면 거리 폴백.
	if _state != State.CHARGE:
		return
	if _contact_timer > 0.0:
		return
	if not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) <= FALLBACK_W * 0.5 + 10.0:
		if target.has_method("take_damage"):
			target.take_damage(contact_damage)
		_contact_timer = CONTACT_COOLDOWN


func _drop_patch() -> void:
	var parent: Node = get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return
	var spot: Vector2 = target.global_position if is_instance_valid(target) else global_position
	var patch: HoofPatch = HoofPatch.new()
	patch.size_px = _patch_size
	patch.fuse_s = _patch_fuse
	patch.duration_s = _patch_duration
	patch.dps = _patch_dps
	patch.element = _patch_element
	parent.add_child(patch)
	patch.global_position = spot


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	if _state == State.CHARGE:
		c = c.lerp(Color(0.95, 0.30, 0.20, 1.0), 0.35)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 부러진 날개 — 등쪽 작은 호.
	var wing: Color = Color(0.20, 0.20, 0.25, 1.0)
	draw_arc(Vector2(-2.0, -FALLBACK_H * 0.4), 6.0, -PI * 0.6, -PI * 0.1, 12, wing, 2.0)
	# 붉게 타는 눈.
	var eye: Color = Color(1.0, 0.30, 0.20, 1.0)
	draw_circle(Vector2(FALLBACK_W * 0.30, -FALLBACK_H * 0.15), 1.8, eye)
	# 발굽.
	var hoof: Color = Color(0.85, 0.80, 0.45, 1.0)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.45, FALLBACK_H * 0.5 - 1.0), Vector2(4.0, 3.0)), hoof)
	draw_rect(Rect2(Vector2(FALLBACK_W * 0.30, FALLBACK_H * 0.5 - 1.0), Vector2(4.0, 3.0)), hoof)
	if _state == State.CHARGE:
		# 돌격 잔상.
		var trail: Color = Color(1.0, 0.55, 0.30, 0.40)
		var back: Vector2 = -_charge_dir * 12.0
		draw_line(Vector2.ZERO, back, trail, 3.0)


class HoofPatch extends Node2D:
	var size_px: float = 60.0
	var fuse_s: float = 2.0
	var duration_s: float = 3.0
	var dps: int = 4
	var element: int = GameEnums.Element.FIRE

	var _age: float = 0.0
	var _state: int = 0  # 0 = 균열(fuse), 1 = 발화 영역(active).
	var _area: Area2D = null
	var _tick_acc: float = 0.0
	var _inside: Array = []  # WeakRef[Node]

	func _ready() -> void:
		add_to_group("hoof_patch")
		queue_redraw()

	func _process(delta: float) -> void:
		_age += delta
		if _state == 0:
			if _age >= fuse_s:
				_ignite()
		else:
			_tick_acc += delta
			# 매 1초마다 dps 만큼 도트 적용.
			while _tick_acc >= 1.0:
				_tick_acc -= 1.0
				_tick_inside()
			if _age >= fuse_s + duration_s:
				queue_free()
				return
		queue_redraw()

	func _ignite() -> void:
		_state = 1
		_area = Area2D.new()
		_area.monitoring = true
		_area.collision_layer = 0
		_area.collision_mask = 1
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(size_px, size_px)
		shape.shape = rect
		_area.add_child(shape)
		_area.body_entered.connect(_on_body_entered)
		_area.body_exited.connect(_on_body_exited)
		_area.set_meta(&"element", element)
		add_child(_area)

	func _on_body_entered(body: Node) -> void:
		if body == null:
			return
		if not body.is_in_group("player"):
			return
		_inside.append(weakref(body))

	func _on_body_exited(body: Node) -> void:
		if body == null:
			return
		_inside = _inside.filter(func(r): return r.get_ref() != null and r.get_ref() != body)

	func _tick_inside() -> void:
		for ref in _inside:
			var n: Node = ref.get_ref()
			if n == null:
				continue
			if n.has_method("take_damage"):
				n.take_damage(dps)

	func _draw() -> void:
		var half: float = size_px * 0.5
		if _state == 0:
			# 균열 placeholder — 어두운 사각 + 점멸하는 빨간 균열선.
			var fuse_progress: float = clampf(_age / maxf(0.001, fuse_s), 0.0, 1.0)
			var crack: Color = Color(0.20, 0.10, 0.10, 0.40 + 0.40 * fuse_progress)
			draw_rect(Rect2(Vector2(-half, -half), Vector2(size_px, size_px)), crack, true)
			var line: Color = Color(0.85, 0.30, 0.20, 0.55 + 0.40 * fuse_progress)
			draw_line(Vector2(-half * 0.7, -half * 0.4), Vector2(half * 0.5, half * 0.6), line, 1.5)
			draw_line(Vector2(-half * 0.3, half * 0.5), Vector2(half * 0.6, -half * 0.3), line, 1.5)
		else:
			# 발화 — 화 속성 도트 영역.
			var fire_progress: float = 1.0 - clampf((_age - fuse_s) / maxf(0.001, duration_s), 0.0, 1.0)
			var fill: Color = Color(1.0, 0.45, 0.20, 0.35 * fire_progress)
			draw_rect(Rect2(Vector2(-half, -half), Vector2(size_px, size_px)), fill, true)
			var border: Color = Color(1.0, 0.65, 0.20, 0.75 * fire_progress)
			draw_rect(Rect2(Vector2(-half, -half), Vector2(size_px, size_px)), border, false, 1.5)
