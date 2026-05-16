extends EnemyBase

# M18 덩굴요괴 — 거의 정지(이속 10). 거리 ≤100px이면 정면 120° 부채꼴 채찍 공격.
# 7초마다 자기 주변 160x160 덩굴 장판 생성(8s 지속, 안에 있는 플레이어 이속 -30% 디버프).

const DEFAULT_WHIP_TRIGGER_PX: float = 100.0
const DEFAULT_WHIP_CONE_DEG: float = 120.0
const DEFAULT_WHIP_COOLDOWN_S: float = 2.0
const DEFAULT_WHIP_TELEGRAPH_S: float = 0.3
const DEFAULT_WHIP_DAMAGE: int = 6
const DEFAULT_FIELD_W: float = 160.0
const DEFAULT_FIELD_H: float = 160.0
const DEFAULT_FIELD_DURATION_S: float = 8.0
const DEFAULT_FIELD_SLOW_MULT: float = 0.7
const DEFAULT_FIELD_COOLDOWN_S: float = 7.0

const FALLBACK_COLOR: Color = Color(0.15, 0.35, 0.20, 1.0)
const FALLBACK_W: float = 26.0
const FALLBACK_H: float = 14.0

enum State { IDLE, WHIP_TELEGRAPH }

var _whip_trigger: float = DEFAULT_WHIP_TRIGGER_PX
var _whip_cone_half_rad: float = deg_to_rad(DEFAULT_WHIP_CONE_DEG * 0.5)
var _whip_cooldown: float = DEFAULT_WHIP_COOLDOWN_S
var _whip_telegraph: float = DEFAULT_WHIP_TELEGRAPH_S
var _whip_damage: int = DEFAULT_WHIP_DAMAGE
var _field_size: Vector2 = Vector2(DEFAULT_FIELD_W, DEFAULT_FIELD_H)
var _field_duration: float = DEFAULT_FIELD_DURATION_S
var _field_slow_mult: float = DEFAULT_FIELD_SLOW_MULT
var _field_cooldown: float = DEFAULT_FIELD_COOLDOWN_S

var _state: int = State.IDLE
var _state_timer: float = 0.0
var _whip_cd_timer: float = 0.0
var _field_cd_timer: float = 0.0
var _facing_dir: Vector2 = Vector2.RIGHT


func _ready() -> void:
	if data == null:
		max_hp = 28
		move_speed = 10.0
		contact_damage = 4
		exp_drop_value = 7
		coin_drop_value = 1
		coin_drop_chance = 0.18
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("whip_trigger_distance_px"):
			_whip_trigger = float(params["whip_trigger_distance_px"])
		if params.has("whip_cone_deg"):
			_whip_cone_half_rad = deg_to_rad(float(params["whip_cone_deg"]) * 0.5)
		if params.has("vine_field_w") and params.has("vine_field_h"):
			_field_size = Vector2(float(params["vine_field_w"]), float(params["vine_field_h"]))
		if params.has("vine_field_duration_s"):
			_field_duration = float(params["vine_field_duration_s"])
		if params.has("vine_field_slow_mult"):
			_field_slow_mult = float(params["vine_field_slow_mult"])
		if params.has("vine_field_cooldown_s"):
			_field_cooldown = float(params["vine_field_cooldown_s"])
		if data.ranged_damage > 0:
			_whip_damage = data.ranged_damage
	_whip_cd_timer = _whip_cooldown
	_field_cd_timer = _field_cooldown
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_field_cd_timer = maxf(0.0, _field_cd_timer - delta)
	_whip_cd_timer = maxf(0.0, _whip_cd_timer - delta)
	if is_instance_valid(target):
		var to_t: Vector2 = target.global_position - global_position
		if to_t.length_squared() > 0.01:
			_facing_dir = to_t.normalized()
	match _state:
		State.IDLE:
			_run_idle(delta)
		State.WHIP_TELEGRAPH:
			_run_whip_telegraph(delta)
	if _field_cd_timer <= 0.0:
		_spawn_vine_field()
		_field_cd_timer = _field_cooldown
	queue_redraw()


func _run_idle(delta: float) -> void:
	super._physics_process(delta)
	if not is_instance_valid(target):
		return
	var d: float = global_position.distance_to(target.global_position)
	if d <= _whip_trigger and _whip_cd_timer <= 0.0:
		_state = State.WHIP_TELEGRAPH
		_state_timer = _whip_telegraph


func _run_whip_telegraph(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	_contact_timer = maxf(0.0, _contact_timer - delta)
	velocity = Vector2.ZERO
	move_and_slide()
	if _state_timer <= 0.0:
		_strike_whip()
		_state = State.IDLE
		_whip_cd_timer = _whip_cooldown


func _strike_whip() -> void:
	if not is_instance_valid(target):
		return
	var to_t: Vector2 = target.global_position - global_position
	var d: float = to_t.length()
	if d > _whip_trigger:
		return
	if d < 0.001:
		return
	var to_dir: Vector2 = to_t / d
	if _facing_dir.dot(to_dir) >= cos(_whip_cone_half_rad):
		var dmg: int = _whip_damage if _whip_damage > 0 else contact_damage
		if target.has_method("take_damage"):
			target.take_damage(dmg)


func _spawn_vine_field() -> void:
	var parent: Node = get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return
	var field: VineField = VineField.new()
	field.size = _field_size
	field.duration = _field_duration
	field.slow_mult = _field_slow_mult
	parent.add_child(field)
	field.global_position = global_position


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 외눈.
	draw_circle(Vector2.ZERO, 3.0, Color(0.95, 0.95, 0.5, 1.0))
	draw_circle(Vector2.ZERO, 1.2, Color(0.0, 0.0, 0.0, 1.0))
	if _state == State.WHIP_TELEGRAPH:
		var warn: Color = Color(0.40, 0.90, 0.40, 0.5)
		var base_a: float = _facing_dir.angle()
		draw_arc(Vector2.ZERO, _whip_trigger, base_a - _whip_cone_half_rad, base_a + _whip_cone_half_rad, 24, warn, 2.0)


class VineField extends Area2D:
	var size: Vector2 = Vector2(160, 160)
	var duration: float = 8.0
	var slow_mult: float = 0.7
	var _life: float = 0.0
	var _tick: float = 0.0
	var _shape: CollisionShape2D

	func _ready() -> void:
		monitoring = true
		collision_layer = 0
		collision_mask = 1
		_shape = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = size
		_shape.shape = rect
		add_child(_shape)

	func _process(delta: float) -> void:
		_life += delta
		if _life >= duration:
			queue_free()
			return
		_tick = maxf(0.0, _tick - delta)
		if _tick <= 0.0:
			_tick = 0.25
			for body in get_overlapping_bodies():
				if body == null:
					continue
				if not body.is_in_group("player"):
					continue
				if body.has_method("apply_slow"):
					body.apply_slow(slow_mult, 0.4)
		queue_redraw()

	func _draw() -> void:
		var fade: float = 1.0 - clampf(_life / maxf(0.001, duration), 0.0, 1.0)
		var fill: Color = Color(0.20, 0.45, 0.20, 0.35 * fade)
		draw_rect(Rect2(-size * 0.5, size), fill, true)
		var line_col: Color = Color(0.10, 0.30, 0.15, 0.6 * fade)
		var seg: int = 6
		var step: Vector2 = size / float(seg)
		for i in seg + 1:
			var x: float = -size.x * 0.5 + float(i) * step.x
			draw_line(Vector2(x, -size.y * 0.5), Vector2(x, size.y * 0.5), line_col, 1.0)
			var y: float = -size.y * 0.5 + float(i) * step.y
			draw_line(Vector2(-size.x * 0.5, y), Vector2(size.x * 0.5, y), line_col, 1.0)
