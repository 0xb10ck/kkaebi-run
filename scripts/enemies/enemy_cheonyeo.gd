extends EnemyBase

# M20 처녀귀신 — 평소 부유 추적, 4초 사이클로 사라졌다가 플레이어 등 뒤 80px에 워프 후 광역 공격.
# 사이클: FLOAT → FADE → WARP → TELEGRAPH → AOE → COOLDOWN.
# 워프 직전 0.2초 흐림 이펙트로 위치 노출, 재출현 후 0.3초 예고선 표시, 반경 80px 단발 광역 데미지.

const DEFAULT_FLOAT_OFFSET_PX: float = 10.0
const DEFAULT_TELEPORT_INTERVAL_S: float = 4.0
const DEFAULT_TELEPORT_OFFSET_BEHIND_PX: float = 80.0
const DEFAULT_TELEPORT_FLASH_TIME_S: float = 0.2
const DEFAULT_AOE_RADIUS_PX: float = 80.0
const DEFAULT_AOE_TELEGRAPH_S: float = 0.3
const DEFAULT_AOE_DAMAGE: int = 9
const FADE_DURATION_S: float = 0.15

const FALLBACK_COLOR: Color = Color(0.92, 0.92, 0.95, 0.95)
const FALLBACK_W: float = 22.0
const FALLBACK_H: float = 38.0

enum State { FLOAT, FADE, WARP_FLASH, TELEGRAPH, AOE_HIT, COOLDOWN }

var _float_offset_px: float = DEFAULT_FLOAT_OFFSET_PX
var _teleport_interval: float = DEFAULT_TELEPORT_INTERVAL_S
var _teleport_offset: float = DEFAULT_TELEPORT_OFFSET_BEHIND_PX
var _teleport_flash_time: float = DEFAULT_TELEPORT_FLASH_TIME_S
var _aoe_radius: float = DEFAULT_AOE_RADIUS_PX
var _aoe_telegraph: float = DEFAULT_AOE_TELEGRAPH_S
var _aoe_damage: int = DEFAULT_AOE_DAMAGE

var _state: int = State.FLOAT
var _state_timer: float = 0.0
var _cycle_timer: float = 0.0
var _last_player_dir: Vector2 = Vector2.RIGHT
var _aoe_resolved: bool = false


func _ready() -> void:
	if data == null:
		max_hp = 50
		move_speed = 55.0
		contact_damage = 9
		exp_drop_value = 12
		coin_drop_value = 1
		coin_drop_chance = 0.32
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("float_offset_px"):
			_float_offset_px = float(params["float_offset_px"])
		if params.has("teleport_interval_s"):
			_teleport_interval = float(params["teleport_interval_s"])
		if params.has("teleport_offset_behind_px"):
			_teleport_offset = float(params["teleport_offset_behind_px"])
		if params.has("teleport_flash_time_s"):
			_teleport_flash_time = float(params["teleport_flash_time_s"])
		if params.has("aoe_radius_px"):
			_aoe_radius = float(params["aoe_radius_px"])
		if params.has("aoe_telegraph_s"):
			_aoe_telegraph = float(params["aoe_telegraph_s"])
		if params.has("aoe_damage"):
			_aoe_damage = int(params["aoe_damage"])
	hp = max_hp
	_state = State.FLOAT
	_cycle_timer = _teleport_interval


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_track_player_dir()
	match _state:
		State.FLOAT:
			_run_float(delta)
		State.FADE:
			_run_fade(delta)
		State.WARP_FLASH:
			_run_warp_flash(delta)
		State.TELEGRAPH:
			_run_telegraph(delta)
		State.AOE_HIT:
			_run_aoe_hit(delta)
		State.COOLDOWN:
			_run_cooldown(delta)
	queue_redraw()


func _track_player_dir() -> void:
	if not is_instance_valid(target):
		return
	if target is CharacterBody2D:
		var v: Vector2 = (target as CharacterBody2D).velocity
		if v.length_squared() > 1.0:
			_last_player_dir = v.normalized()


func _run_float(delta: float) -> void:
	# 평소 부유 추적 — EnemyBase 추적 로직 재사용.
	super._physics_process(delta)
	_cycle_timer = maxf(0.0, _cycle_timer - delta)
	if _cycle_timer <= 0.0:
		_state = State.FADE
		_state_timer = FADE_DURATION_S
		visible = false
		_set_collision_active(false)


func _run_fade(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	_state_timer = maxf(0.0, _state_timer - delta)
	if _state_timer <= 0.0:
		_state = State.WARP_FLASH
		_state_timer = _teleport_flash_time
		_do_warp_to_behind_player()
		visible = true


func _do_warp_to_behind_player() -> void:
	if not is_instance_valid(target):
		return
	var behind_dir: Vector2 = -_last_player_dir
	if behind_dir.length_squared() < 0.001:
		behind_dir = (global_position - target.global_position).normalized()
		if behind_dir.length_squared() < 0.001:
			behind_dir = Vector2.RIGHT
	global_position = target.global_position + behind_dir * _teleport_offset


func _run_warp_flash(delta: float) -> void:
	# 0.2초 흐림 이펙트로 노출.
	velocity = Vector2.ZERO
	move_and_slide()
	_state_timer = maxf(0.0, _state_timer - delta)
	if _state_timer <= 0.0:
		_state = State.TELEGRAPH
		_state_timer = _aoe_telegraph
		_set_collision_active(true)


func _run_telegraph(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	_state_timer = maxf(0.0, _state_timer - delta)
	if _state_timer <= 0.0:
		_state = State.AOE_HIT
		_aoe_resolved = false
		_state_timer = 0.05
		_resolve_aoe_hit()


func _run_aoe_hit(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	_state_timer = maxf(0.0, _state_timer - delta)
	if _state_timer <= 0.0:
		_state = State.COOLDOWN
		_cycle_timer = maxf(0.0, _teleport_interval - FADE_DURATION_S - _teleport_flash_time - _aoe_telegraph)


func _run_cooldown(delta: float) -> void:
	super._physics_process(delta)
	_cycle_timer = maxf(0.0, _cycle_timer - delta)
	if _cycle_timer <= 0.0:
		_state = State.FADE
		_state_timer = FADE_DURATION_S
		visible = false
		_set_collision_active(false)


func _resolve_aoe_hit() -> void:
	if _aoe_resolved:
		return
	_aoe_resolved = true
	if not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) <= _aoe_radius:
		if target.has_method("take_damage"):
			target.take_damage(_aoe_damage)


func _set_collision_active(active: bool) -> void:
	# 사라진 동안 충돌 비활성.
	if active:
		collision_layer = 1
		collision_mask = 1
	else:
		collision_layer = 0
		collision_mask = 0


func _draw() -> void:
	if not visible:
		return
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	var draw_pos: Vector2 = Vector2(0.0, -_float_offset_px)
	# 흐림 이펙트(워프 직전).
	if _state == State.WARP_FLASH:
		c = c.lerp(Color(1.0, 0.4, 0.4, 0.6), 0.5)
	# 소복(흰 직사각형) + 검은 머리카락 윗부분.
	draw_rect(Rect2(draw_pos - Vector2(FALLBACK_W * 0.5, FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	draw_rect(Rect2(draw_pos + Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H * 0.35)), Color(0.05, 0.05, 0.05, 0.95))
	# 빨간 댕기 점.
	draw_circle(draw_pos + Vector2(-FALLBACK_W * 0.45, FALLBACK_H * 0.0), 1.4, Color(0.9, 0.15, 0.15, 1.0))
	draw_circle(draw_pos + Vector2(FALLBACK_W * 0.45, FALLBACK_H * 0.0), 1.4, Color(0.9, 0.15, 0.15, 1.0))
	# 예고 표시.
	if _state == State.TELEGRAPH:
		draw_arc(Vector2.ZERO, _aoe_radius, 0.0, TAU, 32, Color(0.95, 0.85, 0.4, 0.75), 1.5)
	elif _state == State.AOE_HIT:
		draw_arc(Vector2.ZERO, _aoe_radius, 0.0, TAU, 32, Color(1.0, 0.4, 0.4, 0.55), 2.0)
