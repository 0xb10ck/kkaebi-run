class_name GoldShield
extends SkillBase


const SHIELD_RADIUS: float = 24.0
const SHIELD_COLOR: Color = Color("#F0EDE6", 0.4)
const RESPAWN_TIME: float = 5.0


var has_shield: bool = true
var _respawn_timer: float = 0.0


func _ready() -> void:
	cooldown = 0.0
	super._ready()
	has_shield = true
	_respawn_timer = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if has_shield:
		return
	_respawn_timer = maxf(0.0, _respawn_timer - delta)
	if _respawn_timer <= 0.0:
		has_shield = true
		queue_redraw()


func try_absorb() -> bool:
	if not has_shield:
		return false
	has_shield = false
	_respawn_timer = RESPAWN_TIME
	queue_redraw()
	return true


func _draw() -> void:
	if has_shield:
		draw_circle(Vector2.ZERO, SHIELD_RADIUS, SHIELD_COLOR)
