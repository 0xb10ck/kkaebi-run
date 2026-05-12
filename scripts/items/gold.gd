extends Area2D

signal collected(amount: int)

const ATTRACT_SPEED: float = 300.0

@export var amount: int = 1
@onready var sprite: ColorRect = $Sprite

var _target: Node2D = null
var _attracting: bool = false


func setup(a: int) -> void:
	amount = a


func _ready() -> void:
	add_to_group("gold_drops")
	area_entered.connect(_on_area_entered)


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
		collected.emit(amount)
		queue_free()
		return
	global_position += to_t.normalized() * step
