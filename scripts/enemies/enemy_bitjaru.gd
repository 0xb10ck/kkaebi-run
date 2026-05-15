extends EnemyBase

# M06 빗자루귀신 — 5초마다 0.5초 예고 후 자기 중심 도넛 AoE (내경 24 ~ 외경 64).

const DEFAULT_INNER_PX: float = 24.0
const DEFAULT_OUTER_PX: float = 64.0
const DEFAULT_TELEGRAPH_S: float = 0.5
const DEFAULT_COOLDOWN_S: float = 5.0
const DEFAULT_SPIN_RPS: float = 1.0

const FALLBACK_COLOR: Color = Color(0.85, 0.72, 0.45, 1.0)
const FALLBACK_W: float = 10.0
const FALLBACK_H: float = 16.0

var _inner_px: float = DEFAULT_INNER_PX
var _outer_px: float = DEFAULT_OUTER_PX
var _telegraph_s: float = DEFAULT_TELEGRAPH_S
var _cooldown_s: float = DEFAULT_COOLDOWN_S
var _spin_rps: float = DEFAULT_SPIN_RPS
var _ranged_damage: int = 4

var _cooldown_timer: float = 0.0
var _telegraph_timer: float = 0.0
var _is_telegraphing: bool = false
var _spin_phase: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 12
		move_speed = 60.0
		contact_damage = 3
		exp_drop_value = 3
		coin_drop_value = 1
		coin_drop_chance = 0.12
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("donut_inner_px"):
			_inner_px = float(params["donut_inner_px"])
		if params.has("donut_outer_px"):
			_outer_px = float(params["donut_outer_px"])
		if params.has("blur_duration_s"):
			_telegraph_s = float(params["blur_duration_s"])
		if params.has("spin_visual_rps"):
			_spin_rps = float(params["spin_visual_rps"])
		if data.ranged_telegraph > 0.0:
			_telegraph_s = data.ranged_telegraph
		if data.ranged_cooldown > 0.0:
			_cooldown_s = data.ranged_cooldown
		if data.ranged_damage > 0:
			_ranged_damage = data.ranged_damage
		if data.ranged_range_px > 0.0:
			_outer_px = data.ranged_range_px
	_cooldown_timer = _cooldown_s
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_spin_phase = fmod(_spin_phase + delta * _spin_rps, 1.0)
	queue_redraw()
	if _is_telegraphing:
		_telegraph_timer = maxf(0.0, _telegraph_timer - delta)
		if _telegraph_timer <= 0.0:
			_is_telegraphing = false
			_unleash_donut()
			_cooldown_timer = _cooldown_s
		# 텔레그래프 중에도 이동은 한다.
	else:
		_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
		if _cooldown_timer <= 0.0:
			_is_telegraphing = true
			_telegraph_timer = _telegraph_s
	super._physics_process(delta)


func _unleash_donut() -> void:
	if not is_instance_valid(target):
		return
	var d: float = global_position.distance_to(target.global_position)
	if d >= _inner_px and d <= _outer_px:
		if target.has_method("take_damage"):
			target.take_damage(_ranged_damage)


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	var angle: float = _spin_phase * TAU
	# 회전하는 빗자루 표현 (단순 막대).
	var tip: Vector2 = Vector2(cos(angle), sin(angle)) * FALLBACK_H
	draw_line(Vector2.ZERO, tip, c, FALLBACK_W * 0.4)
	if _is_telegraphing:
		# 예고 도넛 — 외경 윤곽 + 내경 윤곽.
		var warn: Color = Color(1.0, 0.4, 0.4, 0.55)
		draw_arc(Vector2.ZERO, _outer_px, 0.0, TAU, 32, warn, 2.0)
		draw_arc(Vector2.ZERO, _inner_px, 0.0, TAU, 24, warn, 2.0)
