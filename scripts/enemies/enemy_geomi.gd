extends EnemyBase

# M15 거미요괴 — 평소 일반 추적(이속 80). 7초마다 자기 후방 60px에 80x80 거미줄 트랩 생성(8s 지속).
# 트랩 위 플레이어 이속 -50% 3초. 스폰 시 새끼거미 2마리 동행, 모체 사망 시 새끼거미들은 도주.

const DEFAULT_WEB_SIZE_W: float = 80.0
const DEFAULT_WEB_SIZE_H: float = 80.0
const DEFAULT_WEB_BACK_OFFSET_PX: float = 60.0
const DEFAULT_WEB_DURATION_S: float = 8.0
const DEFAULT_WEB_SLOW_MULT: float = 0.5
const DEFAULT_WEB_SLOW_DURATION_S: float = 3.0
const DEFAULT_WEB_COOLDOWN_S: float = 7.0
const DEFAULT_SPIDERLING_COUNT: int = 2
const SPIDERLING_FOLLOW_DIST_PX: float = 28.0
const SPIDERLING_SPEED: float = 95.0
const SPIDERLING_FLEE_SPEED_MULT: float = 1.3
const SPIDERLING_FLEE_LIFETIME_S: float = 3.0

const FALLBACK_COLOR: Color = Color(0.45, 0.20, 0.45, 1.0)
const FALLBACK_W: float = 18.0
const FALLBACK_H: float = 14.0

var _web_size: Vector2 = Vector2(DEFAULT_WEB_SIZE_W, DEFAULT_WEB_SIZE_H)
var _web_back_offset: float = DEFAULT_WEB_BACK_OFFSET_PX
var _web_duration: float = DEFAULT_WEB_DURATION_S
var _web_slow_mult: float = DEFAULT_WEB_SLOW_MULT
var _web_slow_duration: float = DEFAULT_WEB_SLOW_DURATION_S
var _web_cooldown: float = DEFAULT_WEB_COOLDOWN_S
var _spiderling_count: int = DEFAULT_SPIDERLING_COUNT

var _web_cd_timer: float = 0.0
var _move_dir: Vector2 = Vector2.RIGHT
var _spiderlings: Array = []
var _spiderlings_spawned: bool = false


func _ready() -> void:
	if data == null:
		max_hp = 30
		move_speed = 80.0
		contact_damage = 6
		exp_drop_value = 8
		coin_drop_value = 1
		coin_drop_chance = 0.24
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("web_size_w") and params.has("web_size_h"):
			_web_size = Vector2(float(params["web_size_w"]), float(params["web_size_h"]))
		if params.has("web_back_offset_px"):
			_web_back_offset = float(params["web_back_offset_px"])
		if params.has("web_duration_s"):
			_web_duration = float(params["web_duration_s"])
		if params.has("web_slow_mult"):
			_web_slow_mult = float(params["web_slow_mult"])
		if params.has("web_slow_duration_s"):
			_web_slow_duration = float(params["web_slow_duration_s"])
		if params.has("web_cooldown_s"):
			_web_cooldown = float(params["web_cooldown_s"])
		if params.has("spiderling_count"):
			_spiderling_count = int(params["spiderling_count"])
	_web_cd_timer = _web_cooldown
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	if not _spiderlings_spawned:
		_spawn_spiderlings()
		_spiderlings_spawned = true
	_web_cd_timer = maxf(0.0, _web_cd_timer - delta)
	var prev_pos: Vector2 = global_position
	super._physics_process(delta)
	var moved: Vector2 = global_position - prev_pos
	if moved.length_squared() > 0.0001:
		_move_dir = moved.normalized()
	if _web_cd_timer <= 0.0:
		_spawn_web_trap()
		_web_cd_timer = _web_cooldown
	queue_redraw()


func _spawn_web_trap() -> void:
	var parent: Node = get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return
	var trap: WebTrap = WebTrap.new()
	trap.size = _web_size
	trap.duration = _web_duration
	trap.slow_mult = _web_slow_mult
	trap.slow_duration = _web_slow_duration
	parent.add_child(trap)
	trap.global_position = global_position - _move_dir * _web_back_offset


func _spawn_spiderlings() -> void:
	var parent: Node = get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return
	var count: int = maxi(0, _spiderling_count)
	for i in count:
		var s: Spiderling = Spiderling.new()
		s.mother = self
		s.follow_distance = SPIDERLING_FOLLOW_DIST_PX
		s.move_speed_value = SPIDERLING_SPEED
		s.flee_speed_mult = SPIDERLING_FLEE_SPEED_MULT
		s.flee_lifetime = SPIDERLING_FLEE_LIFETIME_S
		var angle: float = TAU * float(i) / float(maxi(1, count))
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * SPIDERLING_FOLLOW_DIST_PX
		parent.add_child(s)
		s.global_position = global_position + offset
		_spiderlings.append(s)


func die() -> void:
	if is_dying:
		return
	for s in _spiderlings:
		if is_instance_valid(s):
			(s as Spiderling).enter_flee()
	_spiderlings.clear()
	super.die()


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 다리 표시.
	var leg: Color = Color(0.25, 0.10, 0.25, 1.0)
	for i in 3:
		var x: float = -FALLBACK_W * 0.45 + float(i) * (FALLBACK_W * 0.45)
		draw_line(Vector2(x, -FALLBACK_H * 0.5), Vector2(x - 3.0, -FALLBACK_H * 0.5 - 4.0), leg, 1.0)
		draw_line(Vector2(x, FALLBACK_H * 0.5), Vector2(x - 3.0, FALLBACK_H * 0.5 + 4.0), leg, 1.0)
	# 해골 무늬 점.
	draw_circle(Vector2(0, -1.0), 1.5, Color(0.95, 0.95, 0.95, 1.0))


class WebTrap extends Area2D:
	var size: Vector2 = Vector2(80, 80)
	var duration: float = 8.0
	var slow_mult: float = 0.5
	var slow_duration: float = 3.0
	var _life: float = 0.0
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
		body_entered.connect(_on_body_entered)

	func _process(delta: float) -> void:
		_life += delta
		if _life >= duration:
			queue_free()
			return
		queue_redraw()

	func _on_body_entered(body: Node) -> void:
		if body == null:
			return
		if not body.is_in_group("player"):
			return
		if body.has_method("apply_slow"):
			body.apply_slow(slow_mult, slow_duration)

	func _draw() -> void:
		var fade: float = 1.0 - clampf(_life / maxf(0.001, duration), 0.0, 1.0)
		var fill: Color = Color(0.85, 0.85, 0.95, 0.35 * fade)
		draw_rect(Rect2(-size * 0.5, size), fill, true)
		var line_col: Color = Color(0.95, 0.95, 1.0, 0.55 * fade)
		var hw: float = size.x * 0.5
		var hh: float = size.y * 0.5
		draw_line(Vector2(-hw, -hh), Vector2(hw, hh), line_col, 1.0)
		draw_line(Vector2(hw, -hh), Vector2(-hw, hh), line_col, 1.0)
		draw_line(Vector2(-hw, 0), Vector2(hw, 0), line_col, 1.0)
		draw_line(Vector2(0, -hh), Vector2(0, hh), line_col, 1.0)


class Spiderling extends CharacterBody2D:
	var mother: Node2D
	var move_speed_value: float = 95.0
	var follow_distance: float = 28.0
	var flee_speed_mult: float = 1.3
	var flee_lifetime: float = 3.0
	var _fleeing: bool = false
	var _flee_dir: Vector2 = Vector2.RIGHT
	var _flee_age: float = 0.0

	func _ready() -> void:
		add_to_group("enemy_spiderling")
		queue_redraw()

	func _physics_process(delta: float) -> void:
		if _fleeing:
			_flee_age += delta
			if _flee_age >= flee_lifetime:
				queue_free()
				return
			velocity = _flee_dir * move_speed_value * flee_speed_mult
			move_and_slide()
			return
		if not is_instance_valid(mother):
			enter_flee()
			return
		var to_mom: Vector2 = mother.global_position - global_position
		var dist: float = to_mom.length()
		if dist > follow_distance:
			velocity = to_mom.normalized() * move_speed_value
		else:
			velocity = Vector2.ZERO
		move_and_slide()

	func enter_flee() -> void:
		if _fleeing:
			return
		_fleeing = true
		_flee_age = 0.0
		var player: Node = get_tree().get_first_node_in_group("player")
		if player is Node2D:
			var away: Vector2 = global_position - (player as Node2D).global_position
			if away.length_squared() > 0.01:
				_flee_dir = away.normalized()
			else:
				_flee_dir = Vector2(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0).normalized()
		else:
			_flee_dir = Vector2(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0).normalized()
		if _flee_dir.length_squared() < 0.001:
			_flee_dir = Vector2.RIGHT

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 4.0, Color(0.45, 0.20, 0.45, 1.0))
		draw_circle(Vector2(-2.0, -1.0), 0.8, Color(0.95, 0.95, 0.95, 1.0))
		draw_circle(Vector2(2.0, -1.0), 0.8, Color(0.95, 0.95, 0.95, 1.0))
