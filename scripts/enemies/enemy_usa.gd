extends EnemyBase

# M36 우사 — 부유 추적(중력 없음, 일반 추적과 동일하게 처리).
# rain_interval_s 마다 자기 주변 rain_radius_px 비 영역(Area2D) 생성, rain_duration_s 지속.
# 비 영역 안의 플레이어: 공격 mult ×rain_player_attack_mult(=0.8). 영역 안에서 발생한
# 화(火) 속성 효과 mult ×rain_fire_effect_mult(=0.5). 메타 키를 플레이어에 부여/제거하는 방식.

const DEFAULT_RAIN_INTERVAL_S: float = 5.0
const DEFAULT_RAIN_RADIUS_PX: float = 200.0
const DEFAULT_RAIN_DURATION_S: float = 4.0
const DEFAULT_RAIN_ATTACK_MULT: float = 0.8
const DEFAULT_RAIN_FIRE_MULT: float = 0.5

const META_ATTACK_MULT: StringName = &"usa_rain_attack_mult"
const META_FIRE_MULT: StringName = &"usa_rain_fire_mult"

const FALLBACK_COLOR: Color = Color(0.30, 0.45, 0.75, 1.0)
const FALLBACK_W: float = 22.0
const FALLBACK_H: float = 28.0

var _rain_interval: float = DEFAULT_RAIN_INTERVAL_S
var _rain_radius: float = DEFAULT_RAIN_RADIUS_PX
var _rain_duration: float = DEFAULT_RAIN_DURATION_S
var _rain_attack_mult: float = DEFAULT_RAIN_ATTACK_MULT
var _rain_fire_mult: float = DEFAULT_RAIN_FIRE_MULT

var _rain_cd_timer: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 50
		move_speed = 55.0
		contact_damage = 7
		exp_drop_value = 17
		coin_drop_value = 1
		coin_drop_chance = 0.36
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("rain_interval_s"):
			_rain_interval = float(params["rain_interval_s"])
		if params.has("rain_radius_px"):
			_rain_radius = float(params["rain_radius_px"])
		if params.has("rain_duration_s"):
			_rain_duration = float(params["rain_duration_s"])
		if params.has("rain_player_attack_mult"):
			_rain_attack_mult = float(params["rain_player_attack_mult"])
		if params.has("rain_fire_effect_mult"):
			_rain_fire_mult = float(params["rain_fire_effect_mult"])
		if data.ranged_cooldown > 0.0:
			_rain_interval = data.ranged_cooldown
	hp = max_hp
	_rain_cd_timer = _rain_interval


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_rain_cd_timer = maxf(0.0, _rain_cd_timer - delta)
	if _rain_cd_timer <= 0.0:
		_spawn_rain()
		_rain_cd_timer = _rain_interval
	# 부유 추적은 베이스의 일반 추적과 동일하게 처리(중력 미적용).
	super._physics_process(delta)
	queue_redraw()


func _spawn_rain() -> void:
	var parent: Node = get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return
	var area: RainArea = RainArea.new()
	area.radius = _rain_radius
	area.duration = _rain_duration
	area.attack_mult = _rain_attack_mult
	area.fire_mult = _rain_fire_mult
	parent.add_child(area)
	area.global_position = global_position


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 푸른 도포 + 삿갓.
	var hat: Color = Color(0.55, 0.45, 0.25, 1.0)
	draw_polygon(
		PackedVector2Array([
			Vector2(-FALLBACK_W * 0.65, -FALLBACK_H * 0.5 - 1.0),
			Vector2(FALLBACK_W * 0.65, -FALLBACK_H * 0.5 - 1.0),
			Vector2(0.0, -FALLBACK_H * 0.5 - 6.0),
		]),
		PackedColorArray([hat, hat, hat])
	)
	# 호리병에서 흘러나오는 비.
	var drop: Color = Color(0.55, 0.75, 0.95, 0.85)
	draw_circle(Vector2(FALLBACK_W * 0.5 + 3.0, 0.0), 2.5, drop)
	for i in 3:
		var x: float = FALLBACK_W * 0.5 + 3.0 + float(i) * 1.2
		draw_line(Vector2(x, 3.0), Vector2(x, 8.0 + float(i) * 1.5), drop, 1.0)


class RainArea extends Area2D:
	const KEY_ATTACK_MULT: StringName = &"usa_rain_attack_mult"
	const KEY_FIRE_MULT: StringName = &"usa_rain_fire_mult"

	var radius: float = 200.0
	var duration: float = 4.0
	var attack_mult: float = 0.8
	var fire_mult: float = 0.5
	var _life: float = 0.0
	var _shape: CollisionShape2D
	var _inside: Array = []  # WeakRef[Node]

	func _ready() -> void:
		monitoring = true
		collision_layer = 0
		collision_mask = 1
		_shape = CollisionShape2D.new()
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = radius
		_shape.shape = circle
		add_child(_shape)
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
		queue_redraw()

	func _process(delta: float) -> void:
		_life += delta
		if _life >= duration:
			_clear_all_buffs()
			queue_free()
			return
		queue_redraw()

	func _on_body_entered(body: Node) -> void:
		if body == null:
			return
		if not body.is_in_group("player"):
			return
		(body as Node).set_meta(KEY_ATTACK_MULT, attack_mult)
		(body as Node).set_meta(KEY_FIRE_MULT, fire_mult)
		_inside.append(weakref(body))

	func _on_body_exited(body: Node) -> void:
		if body == null:
			return
		if not body.is_in_group("player"):
			return
		_remove_meta(body)
		_inside = _inside.filter(func(r): return r.get_ref() != null and r.get_ref() != body)

	func _clear_all_buffs() -> void:
		for ref in _inside:
			var n: Node = ref.get_ref()
			if n != null:
				_remove_meta(n)
		_inside.clear()

	func _remove_meta(n: Node) -> void:
		if n.has_meta(KEY_ATTACK_MULT):
			n.remove_meta(KEY_ATTACK_MULT)
		if n.has_meta(KEY_FIRE_MULT):
			n.remove_meta(KEY_FIRE_MULT)

	func _draw() -> void:
		var fade: float = 1.0 - clampf(_life / maxf(0.001, duration), 0.0, 1.0)
		var fill: Color = Color(0.55, 0.75, 0.95, 0.18 * fade)
		draw_circle(Vector2.ZERO, radius, fill)
		var ring: Color = Color(0.55, 0.75, 0.95, 0.55 * fade)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, ring, 1.5)
		# 비 표시 — 사선 빗줄기 패턴.
		var line: Color = Color(0.70, 0.85, 1.0, 0.50 * fade)
		var step: float = 18.0
		var n: int = int(radius * 2.0 / step)
		for i in n:
			var x: float = -radius + float(i) * step
			draw_line(Vector2(x, -radius * 0.5), Vector2(x - 6.0, radius * 0.5), line, 1.0)
