class_name ThornVine
extends SkillBase


const DAMAGE_PER_S: float = 7.0
const BLEED_PER_S: float = 4.0
const DURATION_S: float = 6.0
const TICK_INTERVAL_S: float = 0.25
const WIDTH_PX: float = 240.0
const DEPTH_PX: float = 160.0
const SLOW_FACTOR: float = 0.5
const FORWARD_OFFSET: float = 50.0
const BED_FILL: Color = Color(0.30, 0.55, 0.25, 0.45)
const BED_OUTLINE: Color = Color(0.18, 0.40, 0.18, 0.85)


func _ready() -> void:
	cooldown = 11.0
	super._ready()


func _cast() -> void:
	var forward: Vector2 = _get_player_forward()
	var dmg_per_s: float = DAMAGE_PER_S * damage_multiplier
	var bleed_per_s: float = BLEED_PER_S * damage_multiplier
	var bed: ThornBed = ThornBed.new()
	bed.top_level = true
	bed.damage_per_s = dmg_per_s
	bed.bleed_per_s = bleed_per_s
	bed.duration_s = DURATION_S
	bed.tick_interval_s = TICK_INTERVAL_S
	bed.width_px = WIDTH_PX
	bed.depth_px = DEPTH_PX
	bed.slow_factor = SLOW_FACTOR
	bed.owner_skill = self
	bed.facing = forward
	add_child(bed)
	bed.global_position = global_position + forward * FORWARD_OFFSET


func _get_player_forward() -> Vector2:
	if is_instance_valid(player):
		if "last_move_dir" in player:
			var d: Vector2 = player.last_move_dir
			if d.length() > 0.001:
				return d.normalized()
		if "facing" in player:
			var f: Vector2 = player.facing
			if f.length() > 0.001:
				return f.normalized()
	return Vector2.RIGHT


class ThornBed extends Node2D:
	var damage_per_s: float = 7.0
	var bleed_per_s: float = 4.0
	var duration_s: float = 6.0
	var tick_interval_s: float = 0.25
	var width_px: float = 240.0
	var depth_px: float = 160.0
	var slow_factor: float = 0.5
	var facing: Vector2 = Vector2.RIGHT
	var owner_skill: Node = null
	var _elapsed: float = 0.0
	var _tick_acc: float = 0.0
	var _area: Area2D = null

	func _ready() -> void:
		rotation = facing.angle()
		_area = Area2D.new()
		_area.collision_layer = 0
		_area.collision_mask = 4
		var cs: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(width_px, depth_px)
		cs.shape = rect
		_area.add_child(cs)
		add_child(_area)
		queue_redraw()

	func _process(delta: float) -> void:
		_elapsed += delta
		_tick_acc += delta
		if _tick_acc >= tick_interval_s:
			_apply_tick(tick_interval_s)
			_tick_acc = 0.0
		if _elapsed >= duration_s:
			queue_free()

	func _apply_tick(dt: float) -> void:
		if not is_instance_valid(_area):
			return
		var dmg: int = int(round(damage_per_s * dt))
		if dmg <= 0:
			dmg = 1
		for body in _area.get_overlapping_bodies():
			if not is_instance_valid(body):
				continue
			if body.has_method("take_damage"):
				body.take_damage(dmg)
				if owner_skill and owner_skill.has_signal("hit_enemy"):
					owner_skill.emit_signal("hit_enemy", body, dmg)
			if body.has_method("apply_slow"):
				body.apply_slow(1.0 - slow_factor, tick_interval_s + 0.1)
			if body.has_method("apply_bleed"):
				body.apply_bleed(bleed_per_s, tick_interval_s + 0.1)
			elif body.has_method("apply_status"):
				body.apply_status(&"bleed", bleed_per_s, tick_interval_s + 0.1)

	func _draw() -> void:
		var half_w: float = width_px * 0.5
		var half_d: float = depth_px * 0.5
		draw_rect(Rect2(-half_w, -half_d, width_px, depth_px), ThornVine.BED_FILL, true)
		draw_rect(Rect2(-half_w, -half_d, width_px, depth_px), ThornVine.BED_OUTLINE, false, 2.0)
		# scatter thorns
		var step: float = 24.0
		var x: float = -half_w + 12.0
		while x < half_w:
			var y: float = -half_d + 16.0
			while y < half_d:
				draw_line(Vector2(x, y), Vector2(x + 6.0, y - 8.0), ThornVine.BED_OUTLINE, 1.5)
				draw_line(Vector2(x, y), Vector2(x - 6.0, y - 8.0), ThornVine.BED_OUTLINE, 1.5)
				y += 32.0
			x += step
