extends EnemyBase

# M07 손각시 — 평소 느린 랜덤 워킹. 플레이어 300px 이내 진입 시 5초 추적 → 1.5초 도주.
# HP 50% 이하가 되면 ±100px 랜덤 워프(쿨다운 4s).

const DEFAULT_HP_THRESHOLD: float = 0.5
const DEFAULT_TELEPORT_RANGE_PX: float = 100.0
const DEFAULT_TELEPORT_CD_S: float = 4.0
const DEFAULT_ENGAGE_S: float = 5.0
const DEFAULT_RETREAT_S: float = 1.5
const DEFAULT_DETECT_RANGE_PX: float = 300.0
const IDLE_WANDER_RETARGET_S: float = 1.5
const IDLE_WANDER_RADIUS_PX: float = 48.0
const IDLE_SPEED_MULT: float = 0.35

const FALLBACK_COLOR: Color = Color(0.95, 0.95, 0.92, 1.0)
const FALLBACK_W: float = 14.0
const FALLBACK_H: float = 24.0

enum State { IDLE, ENGAGE, RETREAT }

var _hp_threshold: float = DEFAULT_HP_THRESHOLD
var _teleport_range: float = DEFAULT_TELEPORT_RANGE_PX
var _teleport_cd: float = DEFAULT_TELEPORT_CD_S
var _engage_s: float = DEFAULT_ENGAGE_S
var _retreat_s: float = DEFAULT_RETREAT_S
var _detect_range: float = DEFAULT_DETECT_RANGE_PX

var _state: int = State.IDLE
var _state_timer: float = 0.0
var _teleport_cd_timer: float = 0.0
var _flash_timer: float = 0.0
var _wander_target: Vector2 = Vector2.ZERO
var _wander_retarget_timer: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 20
		move_speed = 50.0
		contact_damage = 6
		exp_drop_value = 4
		coin_drop_value = 1
		coin_drop_chance = 0.14
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("teleport_hp_threshold"):
			_hp_threshold = float(params["teleport_hp_threshold"])
		if params.has("teleport_range_px"):
			_teleport_range = float(params["teleport_range_px"])
		if params.has("teleport_cooldown_s"):
			_teleport_cd = float(params["teleport_cooldown_s"])
		if params.has("engage_duration_s"):
			_engage_s = float(params["engage_duration_s"])
		if params.has("retreat_duration_s"):
			_retreat_s = float(params["retreat_duration_s"])
		if params.has("detect_range_px"):
			_detect_range = float(params["detect_range_px"])
	_wander_target = global_position
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_teleport_cd_timer = maxf(0.0, _teleport_cd_timer - delta)
	_flash_timer = maxf(0.0, _flash_timer - delta)

	if float(hp) / maxf(1.0, float(max_hp)) <= _hp_threshold and _teleport_cd_timer <= 0.0:
		_perform_teleport()

	match _state:
		State.IDLE:
			_run_idle(delta)
		State.ENGAGE:
			_run_engage(delta)
		State.RETREAT:
			_run_retreat(delta)
	queue_redraw()


func _run_idle(delta: float) -> void:
	_contact_timer = maxf(0.0, _contact_timer - delta)
	_wander_retarget_timer = maxf(0.0, _wander_retarget_timer - delta)
	if _wander_retarget_timer <= 0.0:
		_wander_retarget_timer = IDLE_WANDER_RETARGET_S
		var ang: float = randf() * TAU
		var r: float = randf() * IDLE_WANDER_RADIUS_PX
		_wander_target = global_position + Vector2(cos(ang), sin(ang)) * r
	if is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= _detect_range:
			_state = State.ENGAGE
			_state_timer = _engage_s
			return
	var to_w: Vector2 = _wander_target - global_position
	var dir: Vector2 = Vector2.ZERO
	if to_w.length() > 4.0:
		dir = to_w.normalized()
	velocity = dir * move_speed * IDLE_SPEED_MULT * _slow_factor
	move_and_slide()


func _run_engage(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	# 일반 추적은 부모의 _physics_process가 담당.
	super._physics_process(delta)
	if _state_timer <= 0.0:
		_state = State.RETREAT
		_state_timer = _retreat_s


func _run_retreat(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	_contact_timer = maxf(0.0, _contact_timer - delta)
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		move_and_slide()
	else:
		var away: Vector2 = (global_position - target.global_position).normalized()
		velocity = away * move_speed * _slow_factor
		move_and_slide()
	if _state_timer <= 0.0:
		_state = State.IDLE
		_wander_retarget_timer = 0.0


func _perform_teleport() -> void:
	var angle: float = randf() * TAU
	var offset: Vector2 = Vector2(cos(angle), sin(angle)) * _teleport_range
	global_position = global_position + offset
	_teleport_cd_timer = _teleport_cd
	_flash_timer = 0.3


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	if _flash_timer > 0.0:
		c = Color(1.0, 1.0, 1.0, 0.7)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
