extends CharacterBody2D

signal died(world_pos: Vector2, enemy_data: EnemyData)

var data: EnemyData
var max_hp: int = 1
var current_hp: int = 1
var current_speed: float = 80.0
var current_damage: int = 4

var _slow_until: float = 0.0
var _slow_factor: float = 0.0
var _stun_until: float = 0.0
var _player: Node2D = null
var _dying: bool = false
var _initialized: bool = false


@onready var sprite: ColorRect = $Sprite
@onready var hurt_shape: CollisionShape2D = $HurtBox/CollisionShape2D
@onready var body_shape: CollisionShape2D = $BodyCollision


func setup(d: EnemyData, hp_mult: float, speed_mult: float, damage_mult: float) -> void:
	data = d
	max_hp = max(1, int(round(d.hp * hp_mult)))
	current_hp = max_hp
	current_speed = d.move_speed * speed_mult
	current_damage = max(1, int(round(d.contact_damage * damage_mult)))
	if is_inside_tree():
		_apply_visuals()


func _ready() -> void:
	add_to_group("enemies")
	if data != null:
		_apply_visuals()
	_acquire_player()


func _acquire_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]


func _apply_visuals() -> void:
	if data == null or sprite == null:
		return
	var w := float(data.sprite_size.x)
	var h := float(data.sprite_size.y)
	sprite.offset_left = -w * 0.5
	sprite.offset_top = -h * 0.5
	sprite.offset_right = w * 0.5
	sprite.offset_bottom = h * 0.5
	sprite.color = data.placeholder_color
	var s := hurt_shape.shape as CircleShape2D
	if s != null:
		s.radius = data.hitbox_radius
	var bs := body_shape.shape as CircleShape2D
	if bs != null:
		bs.radius = data.hitbox_radius
	_initialized = true


func _physics_process(_delta: float) -> void:
	if _dying or data == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _stun_until:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if _player == null or not is_instance_valid(_player):
		_acquire_player()
		if _player == null:
			return
	var to_player: Vector2 = _player.global_position - global_position
	if to_player.length() < 0.01:
		velocity = Vector2.ZERO
	else:
		var slow_mult := 1.0
		if now < _slow_until:
			slow_mult = max(0.05, 1.0 - _slow_factor)
		velocity = to_player.normalized() * current_speed * slow_mult
	move_and_slide()


func take_damage(amount: int) -> void:
	if _dying:
		return
	current_hp -= amount
	if current_hp <= 0:
		_dying = true
		died.emit(global_position, data)
		queue_free()


func apply_slow(factor: float, duration: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_slow_until = max(_slow_until, now + duration)
	_slow_factor = factor


func apply_stun(duration: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_stun_until = max(_stun_until, now + duration)


func get_enemy_data() -> EnemyData:
	return data


func get_current_damage() -> int:
	return current_damage


func is_dying() -> bool:
	return _dying
