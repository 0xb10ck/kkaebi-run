extends EnemyBase

# M23 강시 — 0.6초 점프(포물선) → 0.4초 정지 반복. 점프 중 공중 무적.
# 정지 단계에서 머리 32×16 약점 히트박스 활성 — 명중 시 데미지 ×2, 누적 100 도달 시 즉사.

const DEFAULT_HOP_DURATION_S: float = 0.6
const DEFAULT_HOP_PAUSE_S: float = 0.4
const DEFAULT_WEAKSPOT_W: float = 32.0
const DEFAULT_WEAKSPOT_H: float = 16.0
const DEFAULT_WEAKSPOT_OFFSET_Y: float = -16.0
const DEFAULT_WEAKSPOT_DAMAGE_MULT: float = 2.0
const DEFAULT_WEAKSPOT_INSTAKILL_DAMAGE: int = 100
const HOP_ARC_HEIGHT_PX: float = 36.0
const HOP_MAX_DISTANCE_PX: float = 96.0

const FALLBACK_COLOR: Color = Color(0.20, 0.30, 0.30, 1.0)
const FALLBACK_W: float = 22.0
const FALLBACK_H: float = 34.0

enum State { PAUSE, HOP }

var _hop_duration: float = DEFAULT_HOP_DURATION_S
var _hop_pause: float = DEFAULT_HOP_PAUSE_S
var _weakspot_w: float = DEFAULT_WEAKSPOT_W
var _weakspot_h: float = DEFAULT_WEAKSPOT_H
var _weakspot_offset_y: float = DEFAULT_WEAKSPOT_OFFSET_Y
var _weakspot_damage_mult: float = DEFAULT_WEAKSPOT_DAMAGE_MULT
var _weakspot_instakill_dmg: int = DEFAULT_WEAKSPOT_INSTAKILL_DAMAGE

var _state: int = State.PAUSE
var _state_timer: float = 0.0
var _hop_t: float = 0.0
var _hop_from: Vector2 = Vector2.ZERO
var _hop_to: Vector2 = Vector2.ZERO
var _hop_visual_y: float = 0.0

var _invuln: bool = false
var _weakspot_accum: int = 0


func _ready() -> void:
	if data == null:
		max_hp = 38
		move_speed = 60.0
		contact_damage = 9
		exp_drop_value = 10
		coin_drop_value = 1
		coin_drop_chance = 0.25
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("hop_duration_s"):
			_hop_duration = float(params["hop_duration_s"])
		if params.has("hop_pause_s"):
			_hop_pause = float(params["hop_pause_s"])
		if params.has("weakspot_hitbox_w"):
			_weakspot_w = float(params["weakspot_hitbox_w"])
		if params.has("weakspot_hitbox_h"):
			_weakspot_h = float(params["weakspot_hitbox_h"])
		if params.has("weakspot_offset_y_px"):
			_weakspot_offset_y = float(params["weakspot_offset_y_px"])
		if params.has("weakspot_damage_mult"):
			_weakspot_damage_mult = float(params["weakspot_damage_mult"])
		if params.has("weakspot_instakill_damage"):
			_weakspot_instakill_dmg = int(params["weakspot_instakill_damage"])
	hp = max_hp
	_state = State.PAUSE
	_state_timer = _hop_pause


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	match _state:
		State.PAUSE:
			_run_pause(delta)
		State.HOP:
			_run_hop(delta)
	queue_redraw()


func _run_pause(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	_contact_timer = maxf(0.0, _contact_timer - delta)
	velocity = Vector2.ZERO
	move_and_slide()
	# 정지 중 접촉 데미지(겹쳐 있으면).
	if _contact_timer <= 0.0 and _contact_area:
		for body in _contact_area.get_overlapping_bodies():
			if body == target:
				_deal_contact_damage()
				break
	if _state_timer <= 0.0 and is_instance_valid(target):
		_start_hop()


func _start_hop() -> void:
	_state = State.HOP
	_state_timer = _hop_duration
	_hop_t = 0.0
	_hop_from = global_position
	var dir: Vector2 = target.global_position - global_position
	var d: float = dir.length()
	if d > 0.001:
		dir = dir / d
	else:
		dir = Vector2.RIGHT
	var hop_dist: float = minf(d, HOP_MAX_DISTANCE_PX)
	_hop_to = global_position + dir * hop_dist
	_invuln = true


func _run_hop(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	_hop_t = clampf(1.0 - (_state_timer / maxf(0.001, _hop_duration)), 0.0, 1.0)
	var pos: Vector2 = _hop_from.lerp(_hop_to, _hop_t)
	_hop_visual_y = -sin(PI * _hop_t) * HOP_ARC_HEIGHT_PX
	global_position = pos
	if _state_timer <= 0.0:
		_land()


func _land() -> void:
	global_position = _hop_to
	_hop_visual_y = 0.0
	_invuln = false
	_state = State.PAUSE
	_state_timer = _hop_pause


func _is_weakspot_active() -> bool:
	return _state == State.PAUSE and not _invuln


func _is_hit_in_weakspot(attacker: Object) -> bool:
	# 정지 단계에서만 약점 활성. 공격자가 위치 정보를 들고 있을 때만 정확 판정.
	if not _is_weakspot_active():
		return false
	if attacker == null:
		return false
	var atk_pos: Vector2 = Vector2.INF
	if attacker is Node2D:
		atk_pos = (attacker as Node2D).global_position
	elif "global_position" in attacker:
		atk_pos = attacker.global_position
	if atk_pos == Vector2.INF:
		return false
	var local: Vector2 = atk_pos - global_position
	var head_center: Vector2 = Vector2(0.0, _weakspot_offset_y)
	var dx: float = absf(local.x - head_center.x)
	var dy: float = absf(local.y - head_center.y)
	return dx <= _weakspot_w * 0.5 and dy <= _weakspot_h * 0.5


func take_damage(amount: int, attacker: Object = null) -> void:
	if is_dying:
		return
	# 점프 중 공중 무적.
	if _invuln:
		return
	var final_amount: int = amount
	if _is_hit_in_weakspot(attacker):
		final_amount = int(round(float(amount) * _weakspot_damage_mult))
		_weakspot_accum += final_amount
		if _weakspot_accum >= _weakspot_instakill_dmg:
			# 약점 누적 즉사.
			hp = 0
			die()
			return
	super.take_damage(final_amount, attacker)


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	var draw_pos: Vector2 = Vector2(0.0, _hop_visual_y)
	# 청나라식 관복(몸통).
	draw_rect(Rect2(draw_pos - Vector2(FALLBACK_W * 0.5, FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 정면으로 뻗은 팔.
	var arm: Color = c.lerp(Color(0.6, 0.6, 0.65, 1.0), 0.4)
	draw_rect(Rect2(draw_pos + Vector2(FALLBACK_W * 0.4, -FALLBACK_H * 0.1), Vector2(8.0, 4.0)), arm)
	# 약점(이마 부적) — 정지 단계에선 노랑색이 진하게, 점프 중엔 흐릿하게.
	var paper: Color = Color(0.95, 0.85, 0.30, 1.0) if _is_weakspot_active() else Color(0.95, 0.85, 0.30, 0.35)
	draw_rect(Rect2(draw_pos + Vector2(-_weakspot_w * 0.5, _weakspot_offset_y - _weakspot_h * 0.5), Vector2(_weakspot_w, _weakspot_h)), paper)
	# 약점 누적 게이지.
	if _weakspot_accum > 0:
		var ratio: float = clampf(float(_weakspot_accum) / float(maxi(1, _weakspot_instakill_dmg)), 0.0, 1.0)
		draw_rect(Rect2(draw_pos + Vector2(-_weakspot_w * 0.5, _weakspot_offset_y - _weakspot_h * 0.5 - 4.0), Vector2(_weakspot_w * ratio, 2.0)), Color(0.95, 0.3, 0.3, 0.9))
	if _state == State.HOP:
		# 그림자.
		var seg: int = 16
		for i in seg:
			var a1: float = TAU * float(i) / float(seg)
			var a2: float = TAU * float(i + 1) / float(seg)
			var p1: Vector2 = Vector2(cos(a1) * FALLBACK_W * 0.45, sin(a1) * FALLBACK_W * 0.18)
			var p2: Vector2 = Vector2(cos(a2) * FALLBACK_W * 0.45, sin(a2) * FALLBACK_W * 0.18)
			draw_line(p1, p2, Color(0, 0, 0, 0.3), 1.0)
