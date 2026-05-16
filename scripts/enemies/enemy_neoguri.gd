extends EnemyBase

# M13 너구리 변신술사 — 평소 추적. 5초마다 1장 일반 몹(M01~M09) 외형으로 둔갑(시각만).
# 플레이어 50px 진입 또는 피격 시 둔갑 해제 + 자기 주변 80px AOE.

const DEFAULT_DISGUISE_INTERVAL_S: float = 5.0
const DEFAULT_REVEAL_DISTANCE_PX: float = 50.0
const DEFAULT_FAN_STRIKE_RADIUS_PX: float = 80.0

const DISGUISE_POOL_PATHS: Array[String] = [
	"res://resources/enemies/chapter1/m01_dokkaebibul.tres",
	"res://resources/enemies/chapter1/m02_dalgyalgwisin.tres",
	"res://resources/enemies/chapter1/m03_mulgwisin.tres",
	"res://resources/enemies/chapter1/m04_eodukshini.tres",
	"res://resources/enemies/chapter1/m05_geuseundae.tres",
	"res://resources/enemies/chapter1/m06_bitjarugwisin.tres",
	"res://resources/enemies/chapter1/m07_songakshi.tres",
	"res://resources/enemies/chapter1/m08_mongdalgwisin.tres",
	"res://resources/enemies/chapter1/m09_duduri.tres",
]

const FALLBACK_COLOR: Color = Color(0.55, 0.50, 0.45, 1.0)
const FALLBACK_W: float = 14.0
const FALLBACK_H: float = 22.0

var _disguise_interval: float = DEFAULT_DISGUISE_INTERVAL_S
var _reveal_distance: float = DEFAULT_REVEAL_DISTANCE_PX
var _fan_radius: float = DEFAULT_FAN_STRIKE_RADIUS_PX
var _fan_damage: int = 8

var _disguise_pool: Array[EnemyData] = []
var _disguised: bool = false
var _disguise_color: Color = FALLBACK_COLOR
var _disguise_size: Vector2 = Vector2(FALLBACK_W, FALLBACK_H)
var _disguise_timer: float = 0.0
var _reveal_flash_timer: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 28
		move_speed = 65.0
		contact_damage = 6
		exp_drop_value = 9
		coin_drop_value = 1
		coin_drop_chance = 0.26
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("disguise_interval_s"):
			_disguise_interval = float(params["disguise_interval_s"])
		if params.has("disguise_reveal_distance_px"):
			_reveal_distance = float(params["disguise_reveal_distance_px"])
		if params.has("fan_strike_radius_px"):
			_fan_radius = float(params["fan_strike_radius_px"])
		if data.ranged_damage > 0:
			_fan_damage = data.ranged_damage
	_load_disguise_pool()
	_disguise_timer = _disguise_interval
	hp = max_hp


func _load_disguise_pool() -> void:
	_disguise_pool.clear()
	for path in DISGUISE_POOL_PATHS:
		if not ResourceLoader.exists(path):
			continue
		var res: Resource = load(path)
		if res is EnemyData:
			_disguise_pool.append(res)


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_reveal_flash_timer = maxf(0.0, _reveal_flash_timer - delta)
	_disguise_timer = maxf(0.0, _disguise_timer - delta)
	if _disguised:
		if is_instance_valid(target):
			if global_position.distance_to(target.global_position) <= _reveal_distance:
				_break_disguise()
	else:
		if _disguise_timer <= 0.0:
			_apply_random_disguise()
	super._physics_process(delta)
	queue_redraw()


func _apply_random_disguise() -> void:
	if _disguise_pool.is_empty():
		_disguise_timer = _disguise_interval
		return
	var pick: EnemyData = _disguise_pool[randi() % _disguise_pool.size()]
	if pick == null:
		_disguise_timer = _disguise_interval
		return
	_disguised = true
	_disguise_color = pick.placeholder_color
	var sx: float = maxf(8.0, float(pick.sprite_size_px.x))
	var sy: float = maxf(8.0, float(pick.sprite_size_px.y))
	_disguise_size = Vector2(sx * 0.5, sy * 0.5)


func _break_disguise() -> void:
	if not _disguised:
		return
	_disguised = false
	_reveal_flash_timer = 0.3
	_disguise_timer = _disguise_interval
	_unleash_fan_strike()


func _unleash_fan_strike() -> void:
	if is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= _fan_radius:
			if target.has_method("take_damage"):
				target.take_damage(_fan_damage)


func take_damage(amount: int, attacker: Object = null) -> void:
	var was_disguised: bool = _disguised
	super.take_damage(amount, attacker)
	if was_disguised and not is_dying:
		_break_disguise()


func _draw() -> void:
	if _disguised:
		var dc: Color = _disguise_color
		var ds: Vector2 = _disguise_size
		draw_rect(Rect2(-ds * 0.5, ds), dc)
		return
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	if _reveal_flash_timer > 0.0:
		c = c.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.6)
		draw_arc(Vector2.ZERO, _fan_radius, 0.0, TAU, 32, Color(1.0, 0.8, 0.3, 0.4), 2.0)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 눈가 검은 무늬.
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.45, -FALLBACK_H * 0.25), Vector2(FALLBACK_W * 0.9, 3.0)), Color(0.1, 0.1, 0.1, 1.0))
