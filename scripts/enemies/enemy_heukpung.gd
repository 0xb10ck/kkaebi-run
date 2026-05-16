extends EnemyBase

# M40 흑풍 — 평소 modulate.a = invisible_alpha 로 거의 투명, 일반 추적은 유지.
# 플레이어가 reveal_distance_px 이내로 진입하면 즉시 가시화(modulate.a = 1.0)
# + 자기 주변 swing_radius_px 광역 단발 swing_damage 데미지(예고 없음).
# 가시화 후 reveal_duration_s 가 지나면 다시 투명 상태로 복귀.
# 미니맵 비표시: "minimap_hidden" 그룹에 추가 (외부 미니맵 시스템이 이를 보고 제외하도록 신호).

const DEFAULT_INVISIBLE_ALPHA: float = 0.2
const DEFAULT_REVEAL_DISTANCE_PX: float = 80.0
const DEFAULT_REVEAL_DURATION_S: float = 3.0
const DEFAULT_SWING_RADIUS_PX: float = 100.0
const DEFAULT_SWING_DAMAGE: int = 14
const DEFAULT_MINIMAP_HIDDEN: bool = true

const FALLBACK_COLOR: Color = Color(0.08, 0.08, 0.10, 1.0)
const FALLBACK_RADIUS: float = 20.0

var _invisible_alpha: float = DEFAULT_INVISIBLE_ALPHA
var _reveal_distance: float = DEFAULT_REVEAL_DISTANCE_PX
var _reveal_duration: float = DEFAULT_REVEAL_DURATION_S
var _swing_radius: float = DEFAULT_SWING_RADIUS_PX
var _swing_damage: int = DEFAULT_SWING_DAMAGE
var _minimap_hidden: bool = DEFAULT_MINIMAP_HIDDEN

var _is_visible_phase: bool = false
var _visible_timer: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 60
		move_speed = 80.0
		contact_damage = 14
		exp_drop_value = 22
		coin_drop_value = 1
		coin_drop_chance = 0.44
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("invisible_alpha"):
			_invisible_alpha = float(params["invisible_alpha"])
		if params.has("reveal_distance_px"):
			_reveal_distance = float(params["reveal_distance_px"])
		if params.has("reveal_duration_s"):
			_reveal_duration = float(params["reveal_duration_s"])
		if params.has("swing_radius_px"):
			_swing_radius = float(params["swing_radius_px"])
		if params.has("swing_damage"):
			_swing_damage = int(params["swing_damage"])
		if params.has("minimap_hidden"):
			_minimap_hidden = bool(params["minimap_hidden"])
	hp = max_hp
	if _minimap_hidden:
		add_to_group("minimap_hidden")
	_enter_invisible()


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	# 베이스의 추적/접촉/슬로우/스턴 처리를 그대로 사용 — 투명 중에도 추적은 진행한다.
	super._physics_process(delta)
	if _is_visible_phase:
		_visible_timer = maxf(0.0, _visible_timer - delta)
		if _visible_timer <= 0.0:
			_enter_invisible()
	else:
		if is_instance_valid(target):
			var d: float = global_position.distance_to(target.global_position)
			if d <= _reveal_distance:
				_trigger_reveal()
	queue_redraw()


func _enter_invisible() -> void:
	_is_visible_phase = false
	_visible_timer = 0.0
	modulate.a = _invisible_alpha


func _trigger_reveal() -> void:
	_is_visible_phase = true
	_visible_timer = _reveal_duration
	modulate.a = 1.0
	# 자기 주변 _swing_radius 광역 단발 _swing_damage — 예고 0.
	if is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= _swing_radius:
			if target.has_method("take_damage"):
				target.take_damage(_swing_damage)


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	# 검은 회오리 본체.
	draw_circle(Vector2.ZERO, FALLBACK_RADIUS, c)
	# 안쪽 빨간 눈 두 개.
	var eye: Color = Color(1.0, 0.20, 0.20, 1.0)
	draw_circle(Vector2(-4.0, -2.0), 1.5, eye)
	draw_circle(Vector2(4.0, -2.0), 1.5, eye)
	# 외곽 흐림(점선 원).
	var edge: Color = Color(0.20, 0.18, 0.20, 0.55)
	draw_arc(Vector2.ZERO, FALLBACK_RADIUS + 3.0, 0.0, TAU, 20, edge, 1.0)
	if _is_visible_phase:
		# 가시화 잔향 — 휘두름 반경 표시(짧은 시간).
		var prog: float = clampf(_visible_timer / maxf(0.001, _reveal_duration), 0.0, 1.0)
		var swing_col: Color = Color(1.0, 0.40, 0.30, 0.35 * prog)
		draw_arc(Vector2.ZERO, _swing_radius, 0.0, TAU, 40, swing_col, 1.5)
