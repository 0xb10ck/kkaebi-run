extends Area2D

var damage: int = 20
var speed: float = 360.0
var direction: Vector2 = Vector2.RIGHT
var stun_dur: float = 0.5
var _lifetime: float = 2.5


func setup(dmg: int, spd: float, dir: Vector2, stun: float) -> void:
	damage = dmg
	speed = spd
	if dir.length() > 0.0:
		direction = dir.normalized()
	stun_dur = stun


func _ready() -> void:
	collision_layer = 16
	collision_mask = 2
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	global_position += direction * speed * delta
	rotation += delta * 6.0
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if not is_instance_valid(body):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	if body.has_method("apply_stun"):
		body.apply_stun(stun_dur)
	queue_free()
