extends Area2D

signal collected(value: int)

const ATTRACT_SPEED: float = 300.0

@export var value: int = 1
@onready var sprite: ColorRect = $Sprite

var _target: Node2D = null
var _attracting: bool = false


func setup(v: int) -> void:
	value = v
	if is_inside_tree():
		_apply_visuals()


func _ready() -> void:
	add_to_group("xp_gems")
	area_entered.connect(_on_area_entered)
	_apply_visuals()


func _apply_visuals() -> void:
	if sprite == null:
		return
	var size := 12.0
	if value >= 5:
		size = 16.0
	elif value >= 2:
		size = 14.0
	sprite.offset_left = -size * 0.5
	sprite.offset_top = -size * 0.5
	sprite.offset_right = size * 0.5
	sprite.offset_bottom = size * 0.5
	sprite.color = Palette.gem_color(value)


func _on_area_entered(area: Area2D) -> void:
	if _attracting:
		return
	var parent := area.get_parent()
	if parent and parent.is_in_group("player"):
		_target = parent
		_attracting = true


func _process(delta: float) -> void:
	if not _attracting or _target == null or not is_instance_valid(_target):
		return
	var to_t: Vector2 = _target.global_position - global_position
	var step := ATTRACT_SPEED * delta
	if to_t.length() <= step + 6.0:
		collected.emit(value)
		queue_free()
		return
	global_position += to_t.normalized() * step
