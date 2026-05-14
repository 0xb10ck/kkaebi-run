extends EnemyBase

# M03 물귀신 — 접촉 시 둔화 디버프(DRAG_SLOW). 챕터1에선 단순 접촉 슬로우만 구현.

const DEFAULT_DRAG_SPEED_MULT: float = 0.6
const DEFAULT_DRAG_DURATION_S: float = 3.0
const FALLBACK_COLOR: Color = Color(0.18, 0.55, 0.55, 1.0)
const FALLBACK_RADIUS: float = 12.0

var _drag_speed_mult: float = DEFAULT_DRAG_SPEED_MULT
var _drag_duration: float = DEFAULT_DRAG_DURATION_S


func _ready() -> void:
	if data == null:
		max_hp = 18
		move_speed = 35.0
		contact_damage = 5
		exp_drop_value = 4
		coin_drop_value = 1
		coin_drop_chance = 0.15
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("drag_speed_mult"):
			_drag_speed_mult = float(params["drag_speed_mult"])
		if params.has("drag_duration_s"):
			_drag_duration = float(params["drag_duration_s"])
	hp = max_hp


func _on_contact_hit(player: Node2D) -> void:
	if player and player.has_method("apply_slow"):
		player.apply_slow(_drag_speed_mult, _drag_duration)


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	draw_circle(Vector2.ZERO, FALLBACK_RADIUS, c)
