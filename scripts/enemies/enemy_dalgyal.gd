extends EnemyBase

# M02 달걀귀신 — 무리지어 다니며 근접 시 일제 돌진(CHARGE).

const DEFAULT_TRIGGER_PX: float = 50.0
const DEFAULT_CHARGE_MULT: float = 1.6
const DEFAULT_CHARGE_DURATION_S: float = 0.8
const DEFAULT_CHARGE_COOLDOWN_S: float = 4.0
const FALLBACK_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const FALLBACK_RX: float = 10.0
const FALLBACK_RY: float = 12.0
const EGG_SEGMENTS: int = 24

var _trigger_px: float = DEFAULT_TRIGGER_PX
var _charge_mult: float = DEFAULT_CHARGE_MULT
var _charge_duration: float = DEFAULT_CHARGE_DURATION_S
var _charge_cooldown: float = DEFAULT_CHARGE_COOLDOWN_S
var _charge_timer: float = 0.0
var _charge_cd_timer: float = 0.0
var _charge_dir: Vector2 = Vector2.ZERO


func _ready() -> void:
	if data == null:
		max_hp = 8
		move_speed = 70.0
		contact_damage = 4
		exp_drop_value = 2
		coin_drop_value = 1
		coin_drop_chance = 0.06
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("charge_trigger_distance_px"):
			_trigger_px = float(params["charge_trigger_distance_px"])
		if params.has("charge_speed_mult"):
			_charge_mult = float(params["charge_speed_mult"])
		if params.has("charge_duration_s"):
			_charge_duration = float(params["charge_duration_s"])
		if params.has("charge_cooldown_s"):
			_charge_cooldown = float(params["charge_cooldown_s"])
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	if _charge_cd_timer > 0.0:
		_charge_cd_timer = maxf(0.0, _charge_cd_timer - delta)
	if _charge_timer > 0.0:
		_charge_timer = maxf(0.0, _charge_timer - delta)
		_contact_timer = maxf(0.0, _contact_timer - delta)
		velocity = _charge_dir * move_speed * _charge_mult * _slow_factor
		move_and_slide()
		if _contact_timer <= 0.0 and _contact_area:
			for body in _contact_area.get_overlapping_bodies():
				if body == target:
					_deal_contact_damage()
					break
		return
	# 평상시 추적 + 트리거 거리 도달 시 돌진 시작.
	if not is_instance_valid(target):
		super._physics_process(delta)
		return
	var dist: float = global_position.distance_to(target.global_position)
	if _charge_cd_timer <= 0.0 and dist <= _trigger_px:
		_charge_dir = (target.global_position - global_position).normalized()
		_charge_timer = _charge_duration
		_charge_cd_timer = _charge_cooldown
		return
	super._physics_process(delta)


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	var points: PackedVector2Array = PackedVector2Array()
	for i in EGG_SEGMENTS:
		var a: float = TAU * float(i) / float(EGG_SEGMENTS)
		points.append(Vector2(cos(a) * FALLBACK_RX, sin(a) * FALLBACK_RY))
	draw_colored_polygon(points, c)
