extends EnemyBase

# M38 가릉빈가 — 노래 오라: song_radius_px 안 플레이어에게 song_tick_interval_s 마다 song_tick_damage 도트.
# 노래 중 자신 이동 속도는 song_self_move_speed_during(=0.0)으로 정지.
# 피격 누적이 scream_threshold_damage 이상이면 비명 발동: scream_radius_px AOE 단발 scream_damage,
# 자신 이동 속도 ×scream_speed_buff_mult, scream_speed_buff_duration_s 동안. 누적 카운터 리셋.
# 비명 동안에는 노래 자체는 유지되되 이속만 base × scream_speed_buff_mult로 풀린다.

const DEFAULT_SONG_RADIUS_PX: float = 180.0
const DEFAULT_SONG_TICK_INTERVAL_S: float = 0.5
const DEFAULT_SONG_TICK_DAMAGE: int = 1
const DEFAULT_SONG_SELF_SPEED: float = 0.0
const DEFAULT_SCREAM_THRESHOLD: int = 50
const DEFAULT_SCREAM_RADIUS_PX: float = 80.0
const DEFAULT_SCREAM_DAMAGE: int = 6
const DEFAULT_SCREAM_BUFF_MULT: float = 1.5
const DEFAULT_SCREAM_BUFF_DURATION_S: float = 10.0

const FALLBACK_COLOR: Color = Color(0.45, 0.80, 0.70, 1.0)
const FALLBACK_W: float = 20.0
const FALLBACK_H: float = 28.0

var _song_radius: float = DEFAULT_SONG_RADIUS_PX
var _song_tick_interval: float = DEFAULT_SONG_TICK_INTERVAL_S
var _song_tick_damage: int = DEFAULT_SONG_TICK_DAMAGE
var _song_self_speed: float = DEFAULT_SONG_SELF_SPEED
var _scream_threshold: int = DEFAULT_SCREAM_THRESHOLD
var _scream_radius: float = DEFAULT_SCREAM_RADIUS_PX
var _scream_damage: int = DEFAULT_SCREAM_DAMAGE
var _scream_buff_mult: float = DEFAULT_SCREAM_BUFF_MULT
var _scream_buff_duration: float = DEFAULT_SCREAM_BUFF_DURATION_S

var _base_move_speed: float = 0.0
var _song_tick_timer: float = 0.0
var _damage_accum: int = 0
var _scream_buff_remaining: float = 0.0
var _scream_flash: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 42
		move_speed = 50.0
		contact_damage = 5
		exp_drop_value = 15
		coin_drop_value = 1
		coin_drop_chance = 0.34
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("song_radius_px"):
			_song_radius = float(params["song_radius_px"])
		if params.has("song_tick_interval_s"):
			_song_tick_interval = float(params["song_tick_interval_s"])
		if params.has("song_tick_damage"):
			_song_tick_damage = int(params["song_tick_damage"])
		if params.has("song_self_move_speed_during"):
			_song_self_speed = float(params["song_self_move_speed_during"])
		if params.has("scream_threshold_damage"):
			_scream_threshold = int(params["scream_threshold_damage"])
		if params.has("scream_radius_px"):
			_scream_radius = float(params["scream_radius_px"])
		if params.has("scream_damage"):
			_scream_damage = int(params["scream_damage"])
		if params.has("scream_speed_buff_mult"):
			_scream_buff_mult = float(params["scream_speed_buff_mult"])
		if params.has("scream_speed_buff_duration_s"):
			_scream_buff_duration = float(params["scream_speed_buff_duration_s"])
	hp = max_hp
	_base_move_speed = move_speed
	_song_tick_timer = _song_tick_interval


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
	if _scream_buff_remaining > 0.0:
		_scream_buff_remaining = maxf(0.0, _scream_buff_remaining - delta)
	if _scream_flash > 0.0:
		_scream_flash = maxf(0.0, _scream_flash - delta)
	if not is_instance_valid(target):
		target = _resolve_target()
		if not is_instance_valid(target):
			velocity = Vector2.ZERO
			move_and_slide()
			return
	# 노래 중 자기 이동 — 비명 버프가 활성이면 base × mult, 아니면 song_self_speed.
	var cur_speed: float = _song_self_speed
	if _scream_buff_remaining > 0.0:
		cur_speed = _base_move_speed * _scream_buff_mult
	if cur_speed > 0.0:
		var to_t: Vector2 = target.global_position - global_position
		var d: float = to_t.length()
		if d > 0.001:
			velocity = (to_t / d) * cur_speed * _slow_factor
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_song_tick_timer = maxf(0.0, _song_tick_timer - delta)
	if _song_tick_timer <= 0.0:
		_apply_song_tick()
		_song_tick_timer = _song_tick_interval
	queue_redraw()


func _apply_song_tick() -> void:
	if not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) > _song_radius:
		return
	if target.has_method("take_damage"):
		target.take_damage(_song_tick_damage)


func take_damage(amount: int, attacker: Object = null) -> void:
	if is_dying:
		return
	var prev_hp: int = hp
	super.take_damage(amount, attacker)
	if is_dying:
		return
	var actual: int = prev_hp - hp
	if actual > 0:
		_damage_accum += actual
		if _damage_accum >= _scream_threshold:
			_trigger_scream()
			_damage_accum = 0


func _trigger_scream() -> void:
	# 80px AOE 단발 데미지.
	if is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= _scream_radius:
			if target.has_method("take_damage"):
				target.take_damage(_scream_damage)
	# 이속 버프 — 활성화. _physics_process 에서 base × mult 로 적용.
	_scream_buff_remaining = _scream_buff_duration
	_scream_flash = 0.35


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	if _scream_flash > 0.0:
		c = c.lerp(Color(1.0, 1.0, 0.85, 0.9), 0.5)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 공작 꽁지(아래쪽 부채꼴).
	var tail: Color = Color(0.30, 0.55, 0.80, 0.85)
	draw_arc(Vector2(0.0, FALLBACK_H * 0.5), FALLBACK_W * 0.7, -PI, 0.0, 20, tail, 2.0)
	# 부적(양손).
	var paper: Color = Color(0.98, 0.95, 0.80, 1.0)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5 - 4.0, -4.0), Vector2(3.0, 7.0)), paper)
	draw_rect(Rect2(Vector2(FALLBACK_W * 0.5 + 1.0, -4.0), Vector2(3.0, 7.0)), paper)
	# 노래 오라 표시.
	var aura: Color = Color(0.55, 0.95, 0.85, 0.18)
	draw_circle(Vector2.ZERO, _song_radius, aura)
	draw_arc(Vector2.ZERO, _song_radius, 0.0, TAU, 48, Color(0.55, 0.95, 0.85, 0.45), 1.5)
	if _scream_flash > 0.0:
		var sc: Color = Color(1.0, 0.85, 0.40, 0.6)
		draw_arc(Vector2.ZERO, _scream_radius, 0.0, TAU, 36, sc, 2.0)
