class_name SinmokBlessing
extends SkillBase


const HEAL_PER_TICK: int = 5
const TICK_INTERVAL_S: float = 4.0
const RADIUS_PX: float = 120.0
const DURATION_S: float = 12.0
const SHINMOK_HP: int = 50
const SLOW_FACTOR: float = 0.20
const SLOW_DURATION_S: float = 4.5
const TREE_COLOR: Color = Color(0.35, 0.75, 0.45, 0.85)
const AURA_COLOR: Color = Color(0.45, 0.85, 0.55, 0.15)


var _shinmok: ShinmokTree = null


func _ready() -> void:
	cooldown = 30.0
	super._ready()


func _cast() -> void:
	if is_instance_valid(_shinmok):
		return
	var heal: int = int(round(float(HEAL_PER_TICK) * damage_multiplier))
	var t: ShinmokTree = ShinmokTree.new()
	t.top_level = true
	t.heal_amount = heal
	t.tick_interval_s = TICK_INTERVAL_S
	t.radius_px = RADIUS_PX
	t.duration_s = DURATION_S
	t.hp = SHINMOK_HP
	t.slow_factor = SLOW_FACTOR
	t.slow_duration_s = SLOW_DURATION_S
	t.player = player
	t.owner_skill = self
	add_child(t)
	t.global_position = global_position
	_shinmok = t


class ShinmokTree extends Node2D:
	var heal_amount: int = 5
	var tick_interval_s: float = 4.0
	var radius_px: float = 120.0
	var duration_s: float = 12.0
	var hp: int = 50
	var slow_factor: float = 0.20
	var slow_duration_s: float = 4.5
	var player: Node = null
	var owner_skill: Node = null
	var _elapsed: float = 0.0
	var _next_tick: float = 0.0
	var _area: Area2D = null

	func _ready() -> void:
		_area = Area2D.new()
		_area.collision_layer = 0
		_area.collision_mask = 4
		var cs: CollisionShape2D = CollisionShape2D.new()
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = radius_px
		cs.shape = circle
		_area.add_child(cs)
		add_child(_area)
		add_to_group("shinmok")
		queue_redraw()

	func _process(delta: float) -> void:
		_elapsed += delta
		_next_tick -= delta
		if _next_tick <= 0.0:
			_next_tick = tick_interval_s
			_apply_tick()
		if _elapsed >= duration_s or hp <= 0:
			queue_free()

	func _apply_tick() -> void:
		if is_instance_valid(player):
			if player.has_method("heal"):
				player.heal(heal_amount)
			elif "hp" in player:
				player.hp += heal_amount
		if not is_instance_valid(_area):
			return
		for body in _area.get_overlapping_bodies():
			if is_instance_valid(body) and body.has_method("apply_slow"):
				body.apply_slow(1.0 - slow_factor, slow_duration_s)

	func take_damage(amount: int) -> void:
		hp -= amount
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius_px, SinmokBlessing.AURA_COLOR)
		# trunk
		draw_rect(Rect2(-4.0, -2.0, 8.0, 22.0), Color(0.40, 0.25, 0.15, 1.0))
		# canopy
		draw_circle(Vector2(0.0, -14.0), 16.0, SinmokBlessing.TREE_COLOR)
		draw_circle(Vector2(-10.0, -6.0), 10.0, SinmokBlessing.TREE_COLOR)
		draw_circle(Vector2(10.0, -6.0), 10.0, SinmokBlessing.TREE_COLOR)
