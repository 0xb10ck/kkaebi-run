class_name EnemyProjectile
extends Area2D

# 공용 적 투사체. M08 몽달귀신 종이꽃 등 직선 투사체에 사용한다.
# Layers: collision_layer = PROJECTILE_ENEMY (1<<7=128), collision_mask = PLAYER (1<<0=1).

@export var speed: float = 160.0
@export var damage: int = 5
@export var lifetime: float = 3.0
@export var direction: Vector2 = Vector2.RIGHT
@export var hit_radius: float = 6.0
@export var color: Color = Color.WHITE
@export var homing_target: Node2D = null
@export var pierce: bool = false

const OFFSCREEN_MARGIN_PX: float = 256.0

var _life: float = 0.0
var _viewport_size: Vector2 = Vector2.ZERO

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null


func _ready() -> void:
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()
	if _collision_shape and _collision_shape.shape is CircleShape2D:
		(_collision_shape.shape as CircleShape2D).radius = hit_radius
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_viewport_size = get_viewport_rect().size
	queue_redraw()


func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= lifetime:
		queue_free()
		return
	if homing_target != null and is_instance_valid(homing_target):
		var to_target: Vector2 = (homing_target.global_position - global_position)
		if to_target.length_squared() > 0.0001:
			direction = to_target.normalized()
	global_position += direction * speed * delta
	# 화면 밖 마진 초과 시 정리 (메모리 누수 방지).
	var cam: Camera2D = get_viewport().get_camera_2d()
	var view_center: Vector2 = cam.global_position if cam != null else global_position
	var dx: float = absf(global_position.x - view_center.x)
	var dy: float = absf(global_position.y - view_center.y)
	if dx > _viewport_size.x * 0.5 + OFFSCREEN_MARGIN_PX:
		queue_free()
		return
	if dy > _viewport_size.y * 0.5 + OFFSCREEN_MARGIN_PX:
		queue_free()
		return


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	var owner_node: Node = area.get_parent()
	if owner_node != null:
		_try_hit(owner_node)


func _try_hit(target: Node) -> void:
	if target == null:
		return
	if not target.is_in_group("player"):
		return
	if target.has_method("take_damage"):
		target.take_damage(damage)
	if not pierce:
		queue_free()


func _draw() -> void:
	# 임시 시각화 — 스프라이트 부재 시 색깔 원으로 렌더.
	draw_circle(Vector2.ZERO, hit_radius, color)
