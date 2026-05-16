class_name WorldTreeBlessing
extends SkillBase


const HOLY_DPS: float = 25.0
const TICK_INTERVAL_S: float = 1.0
const DURATION_S: float = 6.0
const ATK_BONUS: float = 0.30
const DMG_TAKEN_MULT: float = 0.80
const MOVE_SPEED_BONUS: float = 0.15
const TREE_COLOR: Color = Color(0.60, 0.95, 0.55, 1.0)
const TRUNK_COLOR: Color = Color(0.55, 0.40, 0.20, 1.0)
const AURA_COLOR: Color = Color(0.80, 1.0, 0.75, 0.18)


var _active_tree: WorldTree = null


func _ready() -> void:
	cooldown = 0.0  # manual ACTIVE
	super._ready()


func _cast() -> void:
	# AUTO disabled — this is ACTIVE. cast_active() must be called explicitly.
	pass


func cast_active() -> void:
	if is_instance_valid(_active_tree):
		return
	var dps: float = HOLY_DPS * damage_multiplier
	var tree_node: WorldTree = WorldTree.new()
	tree_node.top_level = true
	tree_node.holy_dps = dps
	tree_node.duration_s = DURATION_S
	tree_node.tick_interval_s = TICK_INTERVAL_S
	tree_node.atk_bonus = ATK_BONUS
	tree_node.dmg_taken_mult = DMG_TAKEN_MULT
	tree_node.move_speed_bonus = MOVE_SPEED_BONUS
	tree_node.player = player
	tree_node.owner_skill = self
	get_tree().current_scene.add_child(tree_node)
	tree_node.global_position = _screen_center()
	_active_tree = tree_node


func _screen_center() -> Vector2:
	var cam_pos: Vector2 = Vector2(640.0, 360.0)
	if is_instance_valid(player) and player is Node2D:
		cam_pos = (player as Node2D).global_position
	return cam_pos


class WorldTree extends Node2D:
	var holy_dps: float = 25.0
	var duration_s: float = 6.0
	var tick_interval_s: float = 1.0
	var atk_bonus: float = 0.30
	var dmg_taken_mult: float = 0.80
	var move_speed_bonus: float = 0.15
	var player: Node = null
	var owner_skill: Node = null
	var _elapsed: float = 0.0
	var _tick_acc: float = 0.0
	var _buff_applied: bool = false

	func _ready() -> void:
		_apply_buff()
		queue_redraw()

	func _process(delta: float) -> void:
		_elapsed += delta
		_tick_acc += delta
		if _tick_acc >= tick_interval_s:
			_apply_tick()
			_tick_acc = 0.0
		if _elapsed >= duration_s:
			_remove_buff()
			queue_free()

	func _apply_buff() -> void:
		if not is_instance_valid(player):
			return
		if player.has_method("apply_buff"):
			player.apply_buff({
				"atk_bonus": atk_bonus,
				"dmg_taken_mult": dmg_taken_mult,
				"move_speed_bonus": move_speed_bonus,
				"duration_s": duration_s,
				"source": &"world_tree_blessing",
			})
		else:
			if "atk_bonus" in player:
				player.atk_bonus += atk_bonus
			if "dmg_taken_mult" in player:
				player.dmg_taken_mult *= dmg_taken_mult
			if "move_speed_bonus" in player:
				player.move_speed_bonus += move_speed_bonus
		_buff_applied = true

	func _remove_buff() -> void:
		if not _buff_applied or not is_instance_valid(player):
			return
		if player.has_method("remove_buff"):
			player.remove_buff(&"world_tree_blessing")
		else:
			if "atk_bonus" in player:
				player.atk_bonus -= atk_bonus
			if "dmg_taken_mult" in player and dmg_taken_mult > 0.0:
				player.dmg_taken_mult /= dmg_taken_mult
			if "move_speed_bonus" in player:
				player.move_speed_bonus -= move_speed_bonus
		_buff_applied = false

	func _apply_tick() -> void:
		var dmg: int = int(round(holy_dps * tick_interval_s))
		if dmg <= 0:
			dmg = 1
		for e in get_tree().get_nodes_in_group("enemy"):
			if not (e is Node2D):
				continue
			if e.has_method("take_damage"):
				e.take_damage(dmg)
				if owner_skill and owner_skill.has_signal("hit_enemy"):
					owner_skill.emit_signal("hit_enemy", e, dmg)

	func _draw() -> void:
		# aura
		draw_circle(Vector2.ZERO, 220.0, WorldTreeBlessing.AURA_COLOR)
		draw_circle(Vector2.ZERO, 140.0, WorldTreeBlessing.AURA_COLOR)
		# trunk
		draw_rect(Rect2(-10.0, -10.0, 20.0, 70.0), WorldTreeBlessing.TRUNK_COLOR)
		# canopy
		draw_circle(Vector2(0.0, -40.0), 44.0, WorldTreeBlessing.TREE_COLOR)
		draw_circle(Vector2(-28.0, -20.0), 28.0, WorldTreeBlessing.TREE_COLOR)
		draw_circle(Vector2(28.0, -20.0), 28.0, WorldTreeBlessing.TREE_COLOR)
		draw_circle(Vector2(0.0, -70.0), 30.0, WorldTreeBlessing.TREE_COLOR)
