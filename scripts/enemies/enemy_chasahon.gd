extends EnemyBase

# M29 차사혼 — 일반 추적 + 마크 워프 강타.
# 사이클: 0.5초 명부 펼치기(예고) → 플레이어 머리 위 빨간 마커 생성/추적 → 5초 후 마커 위치로 워프 + 즉시 강타(데미지 ×2).
# 사이클 쿨다운 8초. 본인 사망 시 진행 중인 마커 즉시 제거.

const DEFAULT_MARK_TELEGRAPH_S: float = 0.5
const DEFAULT_MARK_DURATION_S: float = 5.0
const DEFAULT_WARP_STRIKE_DAMAGE_MULT: float = 2.0
const DEFAULT_MARK_COOLDOWN_S: float = 8.0
const DEFAULT_CANCEL_MARK_ON_DEATH: bool = true

const MARK_HEAD_OFFSET_Y: float = -28.0
const MARK_SIZE_PX: float = 9.0

const FALLBACK_COLOR: Color = Color(0.10, 0.05, 0.15, 1.0)
const FALLBACK_W: float = 26.0
const FALLBACK_H: float = 42.0

enum State { CHASE, TELEGRAPH, MARK_ACTIVE, WARP_STRIKE, COOLDOWN }

var _mark_telegraph: float = DEFAULT_MARK_TELEGRAPH_S
var _mark_duration: float = DEFAULT_MARK_DURATION_S
var _warp_strike_damage_mult: float = DEFAULT_WARP_STRIKE_DAMAGE_MULT
var _mark_cooldown: float = DEFAULT_MARK_COOLDOWN_S
var _cancel_mark_on_death: bool = DEFAULT_CANCEL_MARK_ON_DEATH
var _warp_strike_damage_override: int = -1

var _state: int = State.CHASE
var _state_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _mark_node: Node2D = null
var _mark_remaining: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 42
		move_speed = 55.0
		contact_damage = 7
		exp_drop_value = 14
		coin_drop_value = 1
		coin_drop_chance = 0.32
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("mark_telegraph_s"):
			_mark_telegraph = float(params["mark_telegraph_s"])
		if params.has("mark_duration_s"):
			_mark_duration = float(params["mark_duration_s"])
		if params.has("warp_strike_damage_mult"):
			_warp_strike_damage_mult = float(params["warp_strike_damage_mult"])
		if params.has("mark_cooldown_s"):
			_mark_cooldown = float(params["mark_cooldown_s"])
		if params.has("cancel_mark_on_death"):
			_cancel_mark_on_death = bool(params["cancel_mark_on_death"])
		if params.has("warp_strike_damage"):
			_warp_strike_damage_override = int(params["warp_strike_damage"])
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	if not is_instance_valid(target):
		target = _resolve_target()
		if not is_instance_valid(target):
			return
	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	match _state:
		State.CHASE:
			_run_chase(delta)
		State.TELEGRAPH:
			_run_telegraph(delta)
		State.MARK_ACTIVE:
			_run_mark_active(delta)
		State.WARP_STRIKE:
			_run_warp_strike(delta)
		State.COOLDOWN:
			_run_cooldown(delta)
	queue_redraw()


func _run_chase(delta: float) -> void:
	super._physics_process(delta)
	if _cooldown_timer <= 0.0:
		_state = State.TELEGRAPH
		_state_timer = _mark_telegraph


func _run_telegraph(delta: float) -> void:
	# 명부 펼치기 — 정지 + 예고.
	velocity = Vector2.ZERO
	move_and_slide()
	_state_timer = maxf(0.0, _state_timer - delta)
	if _state_timer <= 0.0:
		_spawn_mark()
		_state = State.MARK_ACTIVE
		_mark_remaining = _mark_duration


func _spawn_mark() -> void:
	if _mark_node != null and is_instance_valid(_mark_node):
		_mark_node.queue_free()
	var m: Node2D = Node2D.new()
	m.name = "ChasahonMark"
	m.set_script(_get_mark_script())
	# 마커가 매 프레임 플레이어 머리 위에 따라붙도록 follow_target / offset 전달.
	if "follow_target" in m:
		m.follow_target = target
	if "offset_y" in m:
		m.offset_y = MARK_HEAD_OFFSET_Y
	if "size_px" in m:
		m.size_px = MARK_SIZE_PX
	var main: Node = get_tree().current_scene
	if main != null:
		main.add_child(m)
	else:
		get_tree().root.add_child(m)
	if is_instance_valid(target):
		m.global_position = target.global_position + Vector2(0.0, MARK_HEAD_OFFSET_Y)
	_mark_node = m


func _get_mark_script() -> GDScript:
	# 인라인 GDScript — 플레이어 머리 위를 따라다니는 빨간 마커.
	var src: String = (
		"extends Node2D\n"
		+ "var follow_target: Node2D = null\n"
		+ "var offset_y: float = -28.0\n"
		+ "var size_px: float = 9.0\n"
		+ "func _process(_delta: float) -> void:\n"
		+ "    if follow_target != null and is_instance_valid(follow_target):\n"
		+ "        global_position = follow_target.global_position + Vector2(0.0, offset_y)\n"
		+ "    queue_redraw()\n"
		+ "func _draw() -> void:\n"
		+ "    var s: float = size_px\n"
		+ "    var col: Color = Color(0.95, 0.15, 0.15, 0.95)\n"
		+ "    draw_line(Vector2(-s, -s), Vector2(s, s), col, 2.0)\n"
		+ "    draw_line(Vector2(-s, s), Vector2(s, -s), col, 2.0)\n"
		+ "    draw_arc(Vector2.ZERO, s + 2.0, 0.0, TAU, 24, Color(0.95, 0.15, 0.15, 0.65), 1.5)\n"
	)
	var gd: GDScript = GDScript.new()
	gd.source_code = src
	gd.reload()
	return gd


func _run_mark_active(delta: float) -> void:
	# 마크 활성 동안 평소처럼 추적.
	super._physics_process(delta)
	_mark_remaining = maxf(0.0, _mark_remaining - delta)
	if _mark_remaining <= 0.0:
		_state = State.WARP_STRIKE


func _run_warp_strike(_delta: float) -> void:
	# 마커가 현재 머무는 지점(플레이어 위 오프셋 위치)으로 워프 + 즉시 강타.
	var strike_pos: Vector2 = global_position
	if _mark_node != null and is_instance_valid(_mark_node):
		strike_pos = _mark_node.global_position
	global_position = strike_pos
	var dmg: int = _warp_strike_damage_override if _warp_strike_damage_override > 0 else int(round(float(contact_damage) * _warp_strike_damage_mult))
	if is_instance_valid(target):
		if target.has_method("take_damage"):
			target.take_damage(dmg)
	_clear_mark()
	_state = State.COOLDOWN
	_cooldown_timer = _mark_cooldown


func _run_cooldown(delta: float) -> void:
	super._physics_process(delta)
	if _cooldown_timer <= 0.0:
		_state = State.CHASE


func _clear_mark() -> void:
	if _mark_node != null and is_instance_valid(_mark_node):
		_mark_node.queue_free()
	_mark_node = null


func die() -> void:
	if is_dying:
		return
	if _cancel_mark_on_death:
		_clear_mark()
	super.die()


func _exit_tree() -> void:
	# 안전망 — 어떤 경로로든 노드가 트리에서 제거되면 마커도 함께 정리.
	if _mark_node != null and is_instance_valid(_mark_node):
		_mark_node.queue_free()
	_mark_node = null


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	# 검은 도포 몸체.
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.4), Vector2(FALLBACK_W, FALLBACK_H * 0.9)), c)
	# 큰 갓(상단 넓은 검정 사각형).
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.75, -FALLBACK_H * 0.5), Vector2(FALLBACK_W * 1.5, FALLBACK_H * 0.15)), Color(0.05, 0.05, 0.08, 1.0))
	# 흰 명부 두루마리(왼손).
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.55, -FALLBACK_H * 0.05), Vector2(FALLBACK_W * 0.25, FALLBACK_H * 0.20)), Color(0.95, 0.95, 0.90, 1.0))
	# 얼굴은 어둠 — 미세한 두 점.
	draw_circle(Vector2(-FALLBACK_W * 0.10, -FALLBACK_H * 0.32), 1.2, Color(0.85, 0.15, 0.15, 0.95))
	draw_circle(Vector2(FALLBACK_W * 0.10, -FALLBACK_H * 0.32), 1.2, Color(0.85, 0.15, 0.15, 0.95))
	if _state == State.TELEGRAPH:
		# 명부 펼치기 — 황금색 호.
		draw_arc(Vector2.ZERO, FALLBACK_W * 0.65, 0.0, TAU, 24, Color(1.0, 0.85, 0.4, 0.65), 1.4)
	elif _state == State.MARK_ACTIVE:
		# 마크 활성 표시(가는 점선 느낌 — 두 짧은 호).
		draw_arc(Vector2.ZERO, FALLBACK_W * 0.55, 0.0, PI * 0.5, 12, Color(0.95, 0.20, 0.20, 0.55), 1.2)
		draw_arc(Vector2.ZERO, FALLBACK_W * 0.55, PI, PI * 1.5, 12, Color(0.95, 0.20, 0.20, 0.55), 1.2)
