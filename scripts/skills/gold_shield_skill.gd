extends Node2D

@export var max_stack: int = 1
@export var regen_cooldown: float = 5.0

var stack: int = 0
var _cd: float = 0.0
var _visual: ColorRect = null
var _player_ref: Node = null


func _ready() -> void:
	_visual = ColorRect.new()
	_visual.offset_left = -36.0
	_visual.offset_top = -36.0
	_visual.offset_right = 36.0
	_visual.offset_bottom = 36.0
	_visual.color = Color(1.0, 1.0, 1.0, 0.0)
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_visual)
	stack = max_stack
	_update_visual()
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_method("register_shield"):
		_player_ref = players[0]
		_player_ref.register_shield(self)


func _process(delta: float) -> void:
	if stack >= max_stack:
		return
	_cd -= delta
	if _cd <= 0.0:
		stack = min(max_stack, stack + 1)
		_update_visual()


func consume_shield() -> bool:
	if stack > 0:
		stack -= 1
		_cd = regen_cooldown
		_update_visual()
		return true
	return false


func _update_visual() -> void:
	if _visual:
		if stack > 0:
			_visual.color = Color(1.0, 1.0, 1.0, 0.5)
		else:
			_visual.color = Color(1.0, 1.0, 1.0, 0.0)


func _exit_tree() -> void:
	if _player_ref and is_instance_valid(_player_ref) and _player_ref.has_method("unregister_shield"):
		_player_ref.unregister_shield(self)
