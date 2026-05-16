extends EnemyBase

# M43 영귀 — 매 phase_toggle_interval_s(2.0s)마다 작은형/큰형 토글.
# 작은형: 이속 100 / HP 1 / 접촉 5 / 스프라이트 16×16.
# 큰형: 이속 50 / HP 30 / 접촉 12 / 스프라이트 40×48.
# 큰형 진입 시 1회 비명: 자기 주변 big_form_scream_radius_px(50) 광역 단발 big_form_scream_damage(8).
# 토글 시 HP는 새 형태의 상한으로 재설정(refill_hp_on_toggle).

const DEFAULT_TOGGLE_INTERVAL_S: float = 2.0
const DEFAULT_SMALL_HP: int = 1
const DEFAULT_SMALL_SPEED: float = 100.0
const DEFAULT_SMALL_CONTACT: int = 5
const DEFAULT_SMALL_W: float = 16.0
const DEFAULT_SMALL_H: float = 16.0
const DEFAULT_BIG_HP: int = 30
const DEFAULT_BIG_SPEED: float = 50.0
const DEFAULT_BIG_CONTACT: int = 12
const DEFAULT_BIG_W: float = 40.0
const DEFAULT_BIG_H: float = 48.0
const DEFAULT_SCREAM_RADIUS_PX: float = 50.0
const DEFAULT_SCREAM_DAMAGE: int = 8

const FALLBACK_COLOR: Color = Color(0.20, 0.18, 0.25, 1.0)

enum Form { SMALL, BIG }

var _toggle_interval: float = DEFAULT_TOGGLE_INTERVAL_S
var _small_hp: int = DEFAULT_SMALL_HP
var _small_speed: float = DEFAULT_SMALL_SPEED
var _small_contact: int = DEFAULT_SMALL_CONTACT
var _small_w: float = DEFAULT_SMALL_W
var _small_h: float = DEFAULT_SMALL_H
var _big_hp: int = DEFAULT_BIG_HP
var _big_speed: float = DEFAULT_BIG_SPEED
var _big_contact: int = DEFAULT_BIG_CONTACT
var _big_w: float = DEFAULT_BIG_W
var _big_h: float = DEFAULT_BIG_H
var _scream_radius: float = DEFAULT_SCREAM_RADIUS_PX
var _scream_damage: int = DEFAULT_SCREAM_DAMAGE

var _form: int = Form.SMALL
var _toggle_timer: float = 0.0
var _scream_flash: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 30
		move_speed = 50.0
		contact_damage = 12
		exp_drop_value = 14
		coin_drop_value = 1
		coin_drop_chance = 0.30
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("phase_toggle_interval_s"):
			_toggle_interval = float(params["phase_toggle_interval_s"])
		if params.has("small_form_hp"):
			_small_hp = int(params["small_form_hp"])
		if params.has("small_form_move_speed"):
			_small_speed = float(params["small_form_move_speed"])
		if params.has("small_form_contact_damage"):
			_small_contact = int(params["small_form_contact_damage"])
		if params.has("small_form_sprite_w_px"):
			_small_w = float(params["small_form_sprite_w_px"])
		if params.has("small_form_sprite_h_px"):
			_small_h = float(params["small_form_sprite_h_px"])
		if params.has("big_form_hp"):
			_big_hp = int(params["big_form_hp"])
		if params.has("big_form_move_speed"):
			_big_speed = float(params["big_form_move_speed"])
		if params.has("big_form_contact_damage"):
			_big_contact = int(params["big_form_contact_damage"])
		if params.has("big_form_sprite_w_px"):
			_big_w = float(params["big_form_sprite_w_px"])
		if params.has("big_form_sprite_h_px"):
			_big_h = float(params["big_form_sprite_h_px"])
		if params.has("big_form_scream_radius_px"):
			_scream_radius = float(params["big_form_scream_radius_px"])
		if params.has("big_form_scream_damage"):
			_scream_damage = int(params["big_form_scream_damage"])
	_enter_small()
	_toggle_timer = _toggle_interval


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	# 토글은 시간 기반 — 추적 가능 여부와 무관하게 흘러간다.
	_toggle_timer = maxf(0.0, _toggle_timer - delta)
	if _toggle_timer <= 0.0:
		_toggle_form()
		_toggle_timer = _toggle_interval
	if _scream_flash > 0.0:
		_scream_flash = maxf(0.0, _scream_flash - delta)
	# 추적/접촉/슬로우/스턴은 베이스에 위임 — 형태 변경된 move_speed/contact_damage 즉시 반영.
	super._physics_process(delta)
	queue_redraw()


func _toggle_form() -> void:
	if _form == Form.SMALL:
		_enter_big()
	else:
		_enter_small()


func _enter_small() -> void:
	_form = Form.SMALL
	max_hp = _small_hp
	hp = max_hp
	move_speed = _small_speed
	contact_damage = _small_contact


func _enter_big() -> void:
	_form = Form.BIG
	max_hp = _big_hp
	hp = max_hp
	move_speed = _big_speed
	contact_damage = _big_contact
	# 큰형 진입 — 비명: 자기 주변 _scream_radius 광역 단발.
	if is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= _scream_radius:
			if target.has_method("take_damage"):
				target.take_damage(_scream_damage)
	_scream_flash = 0.4


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	var w: float = _big_w if _form == Form.BIG else _small_w
	var h: float = _big_h if _form == Form.BIG else _small_h
	if _form == Form.BIG and _scream_flash > 0.0:
		c = c.lerp(Color(1.0, 0.85, 0.50, 1.0), 0.4)
	# 흐릿한 인간 실루엣 placeholder.
	draw_rect(Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h)), c)
	# 두 눈.
	var eye: Color = Color(0.95, 0.25, 0.40, 1.0)
	var eye_r: float = 1.0 if _form == Form.SMALL else 1.8
	var ey: float = -h * 0.20
	draw_circle(Vector2(-w * 0.20, ey), eye_r, eye)
	draw_circle(Vector2(w * 0.20, ey), eye_r, eye)
	# 외곽 흐림.
	var edge: Color = Color(c.r * 0.5, c.g * 0.5, c.b * 0.5, 0.55)
	draw_rect(Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h)), edge, false, 1.0)
	if _form == Form.BIG and _scream_flash > 0.0:
		var sc: Color = Color(1.0, 0.70, 0.30, 0.55 * (_scream_flash / 0.4))
		draw_arc(Vector2.ZERO, _scream_radius, 0.0, TAU, 32, sc, 2.0)
