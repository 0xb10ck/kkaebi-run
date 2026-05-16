extends EnemyBase

# M17 나무귀신 — 매우 느린 이동(이속 35). 5초 사이클: 1.5s 정지(뿌리 박기) → 0.5s 예고 → 5지점 가시 AOE.
# 정지/예고 상태 동안 받는 데미지 ×1.5.

const DEFAULT_CYCLE_INTERVAL_S: float = 5.0
const DEFAULT_ROOT_PAUSE_S: float = 1.5
const DEFAULT_TELEGRAPH_S: float = 0.5
const DEFAULT_AOE_RADIUS_PX: float = 120.0
const DEFAULT_SPIKE_COUNT: int = 5
const DEFAULT_SPIKE_W: float = 24.0
const DEFAULT_SPIKE_H: float = 24.0
const DEFAULT_DAMAGE_TAKEN_MULT: float = 1.5
const DEFAULT_SPIKE_DAMAGE: int = 8

const FALLBACK_COLOR: Color = Color(0.40, 0.30, 0.15, 1.0)
const FALLBACK_W: float = 22.0
const FALLBACK_H: float = 30.0

enum State { MOVE, ROOT_PAUSE, TELEGRAPH }

var _cycle_interval: float = DEFAULT_CYCLE_INTERVAL_S
var _root_pause: float = DEFAULT_ROOT_PAUSE_S
var _telegraph_s: float = DEFAULT_TELEGRAPH_S
var _aoe_radius: float = DEFAULT_AOE_RADIUS_PX
var _spike_count: int = DEFAULT_SPIKE_COUNT
var _spike_w: float = DEFAULT_SPIKE_W
var _spike_h: float = DEFAULT_SPIKE_H
var _damage_mult: float = DEFAULT_DAMAGE_TAKEN_MULT
var _spike_damage: int = DEFAULT_SPIKE_DAMAGE

var _state: int = State.MOVE
var _state_timer: float = 0.0
var _cycle_timer: float = 0.0
var _spike_positions: Array[Vector2] = []


func _ready() -> void:
	if data == null:
		max_hp = 45
		move_speed = 35.0
		contact_damage = 6
		exp_drop_value = 10
		coin_drop_value = 1
		coin_drop_chance = 0.26
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("root_interval_s"):
			_cycle_interval = float(params["root_interval_s"])
		if params.has("root_pause_s"):
			_root_pause = float(params["root_pause_s"])
		if params.has("root_telegraph_s"):
			_telegraph_s = float(params["root_telegraph_s"])
		if params.has("root_aoe_radius_px"):
			_aoe_radius = float(params["root_aoe_radius_px"])
		if params.has("root_spike_count"):
			_spike_count = int(params["root_spike_count"])
		if params.has("root_spike_hitbox_w"):
			_spike_w = float(params["root_spike_hitbox_w"])
		if params.has("root_spike_hitbox_h"):
			_spike_h = float(params["root_spike_hitbox_h"])
		if params.has("damage_taken_mult_during_root"):
			_damage_mult = float(params["damage_taken_mult_during_root"])
		if data.ranged_damage > 0:
			_spike_damage = data.ranged_damage
	_cycle_timer = _cycle_interval
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	match _state:
		State.MOVE:
			_run_move(delta)
		State.ROOT_PAUSE:
			_run_root_pause(delta)
		State.TELEGRAPH:
			_run_telegraph(delta)
	queue_redraw()


func _run_move(delta: float) -> void:
	_cycle_timer = maxf(0.0, _cycle_timer - delta)
	super._physics_process(delta)
	if _cycle_timer <= 0.0:
		_state = State.ROOT_PAUSE
		_state_timer = _root_pause


func _run_root_pause(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	_contact_timer = maxf(0.0, _contact_timer - delta)
	velocity = Vector2.ZERO
	move_and_slide()
	if _state_timer <= 0.0:
		_prepare_spikes()
		_state = State.TELEGRAPH
		_state_timer = _telegraph_s


func _prepare_spikes() -> void:
	_spike_positions.clear()
	var count: int = maxi(0, _spike_count)
	for i in count:
		var angle: float = randf() * TAU
		var r: float = sqrt(randf()) * _aoe_radius
		_spike_positions.append(global_position + Vector2(cos(angle), sin(angle)) * r)


func _run_telegraph(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	_contact_timer = maxf(0.0, _contact_timer - delta)
	velocity = Vector2.ZERO
	move_and_slide()
	if _state_timer <= 0.0:
		_strike_spikes()
		_state = State.MOVE
		_cycle_timer = _cycle_interval
		_spike_positions.clear()


func _strike_spikes() -> void:
	if not is_instance_valid(target):
		return
	var half_w: float = _spike_w * 0.5
	var half_h: float = _spike_h * 0.5
	for sp in _spike_positions:
		var dx: float = absf(target.global_position.x - sp.x)
		var dy: float = absf(target.global_position.y - sp.y)
		if dx <= half_w and dy <= half_h:
			if target.has_method("take_damage"):
				target.take_damage(_spike_damage)
			return


func take_damage(amount: int, attacker: Object = null) -> void:
	var amt: int = amount
	if _state == State.ROOT_PAUSE or _state == State.TELEGRAPH:
		amt = int(round(float(amount) * _damage_mult))
	super.take_damage(amt, attacker)


func _draw() -> void:
	var base_color: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	var draw_color: Color = base_color
	if _state == State.ROOT_PAUSE or _state == State.TELEGRAPH:
		draw_color = base_color.lerp(Color(0.20, 0.15, 0.05, 1.0), 0.3)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), draw_color)
	# 옹이 눈.
	draw_circle(Vector2(-FALLBACK_W * 0.2, -FALLBACK_H * 0.2), 2.0, Color(0.10, 0.05, 0.0, 1.0))
	draw_circle(Vector2(FALLBACK_W * 0.2, -FALLBACK_H * 0.2), 2.0, Color(0.10, 0.05, 0.0, 1.0))
	if _state == State.ROOT_PAUSE:
		# 발 밑 뿌리 박기 표시.
		var root_col: Color = Color(0.30, 0.20, 0.10, 0.85)
		for i in 4:
			var x: float = -FALLBACK_W * 0.45 + float(i) * (FALLBACK_W * 0.30)
			draw_line(Vector2(x, FALLBACK_H * 0.5), Vector2(x - 3.0, FALLBACK_H * 0.5 + 6.0), root_col, 1.5)
	if _state == State.TELEGRAPH:
		var warn: Color = Color(1.0, 0.4, 0.2, 0.7)
		var half_w: float = _spike_w * 0.5
		var half_h: float = _spike_h * 0.5
		for sp in _spike_positions:
			var local: Vector2 = sp - global_position
			draw_rect(Rect2(local - Vector2(half_w, half_h), Vector2(_spike_w, _spike_h)), warn, false, 2.0)
