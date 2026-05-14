extends EnemyBase

# M01 도깨비불 — 단순 추적. 접촉 후 잠시 물러난다.

const DEFAULT_RETREAT_DISTANCE_PX: float = 24.0
const DEFAULT_RETREAT_DURATION_S: float = 0.5
const FALLBACK_COLOR: Color = Color(0.357, 0.808, 0.980, 1.0)
const FALLBACK_RADIUS: float = 6.0

var _retreat_distance: float = DEFAULT_RETREAT_DISTANCE_PX
var _retreat_duration: float = DEFAULT_RETREAT_DURATION_S
var _retreat_timer: float = 0.0
var _retreat_dir: Vector2 = Vector2.ZERO


func _ready() -> void:
	if data == null:
		max_hp = 10
		move_speed = 50.0
		contact_damage = 3
		exp_drop_value = 2
		coin_drop_value = 1
		coin_drop_chance = 0.08
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("retreat_distance_px"):
			_retreat_distance = float(params["retreat_distance_px"])
		if params.has("retreat_duration_s"):
			_retreat_duration = float(params["retreat_duration_s"])
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	if _retreat_timer > 0.0:
		_retreat_timer = maxf(0.0, _retreat_timer - delta)
		velocity = _retreat_dir * move_speed
		move_and_slide()
		return
	super._physics_process(delta)


func _on_contact_hit(_player: Node2D) -> void:
	if not is_instance_valid(target):
		return
	_retreat_dir = (global_position - target.global_position).normalized()
	_retreat_timer = _retreat_duration


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	draw_circle(Vector2.ZERO, FALLBACK_RADIUS, c)
