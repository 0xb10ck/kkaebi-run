extends CharacterBody2D


const SPEED: float = 180.0
const BASE_MAX_HP: int = 100
const INVINCIBLE_TIME: float = 0.6
const ATTACK_INTERVAL: float = 1.0
const ATTACK_RADIUS: float = 80.0
const ATTACK_DAMAGE: int = 12
const BAT_ROTATION_SPEED: float = TAU


signal hp_changed(hp: int, max_hp: int)
signal level_up(level: int)
signal exp_changed(exp: int, exp_to_next: int)
signal died


var max_hp: int = BASE_MAX_HP
var hp: int = BASE_MAX_HP
var level: int = 1
var exp: int = 0
var exp_to_next: int = 5
var invincible: bool = false
var attack_timer: float = 0.0
var move_speed_mult: float = 1.0
var exp_gain_mult: float = 1.0
var _slow_factor: float = 1.0
var _slow_remaining: float = 0.0

@onready var _attack_area: Area2D = $AttackArea
@onready var _exp_pickup_area: Area2D = $ExpPickupArea
@onready var _camera: Camera2D = $Camera2D
@onready var _bat: Node2D = $Bat

var _dead: bool = false


func _ready() -> void:
	add_to_group("player")
	_camera.make_current()
	_exp_pickup_area.area_entered.connect(_on_exp_pickup_area_entered)
	hp_changed.emit(hp, max_hp)
	level_up.emit(level)
	exp_changed.emit(exp, exp_to_next)


func _physics_process(delta: float) -> void:
	if _dead:
		velocity = Vector2.ZERO
		return
	if _slow_remaining > 0.0:
		_slow_remaining -= delta
		if _slow_remaining <= 0.0:
			_slow_remaining = 0.0
			_slow_factor = 1.0
	var dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * SPEED * move_speed_mult * _slow_factor
	move_and_slide()

	if is_instance_valid(_bat):
		_bat.rotation = fmod(_bat.rotation + BAT_ROTATION_SPEED * delta, TAU)

	attack_timer += delta
	if attack_timer >= ATTACK_INTERVAL:
		attack_timer = 0.0
		_perform_attack()


func _perform_attack() -> void:
	for body in _attack_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(ATTACK_DAMAGE, self)
	for area in _attack_area.get_overlapping_areas():
		if area.has_method("take_damage"):
			area.take_damage(ATTACK_DAMAGE, self)


func apply_slow(factor: float, duration: float) -> void:
	if _dead:
		return
	var f: float = clamp(factor, 0.05, 1.0)
	if f < _slow_factor:
		_slow_factor = f
	if duration > _slow_remaining:
		_slow_remaining = duration


func take_damage(amount: int) -> void:
	if _dead or invincible:
		return
	var shield: Node = get_node_or_null("GoldShield")
	if shield and shield.has_method("try_absorb") and shield.try_absorb():
		return
	hp = max(0, hp - amount)
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		_dead = true
		died.emit()
		return
	invincible = true
	await get_tree().create_timer(INVINCIBLE_TIME).timeout
	if is_instance_valid(self):
		invincible = false


func apply_bonus(bonus_id: String) -> void:
	if _dead:
		return
	match bonus_id:
		"bonus_max_hp":
			max_hp += 20
			hp += 20
			hp_changed.emit(hp, max_hp)
		"bonus_speed":
			move_speed_mult += 0.05
		"bonus_exp_gain":
			exp_gain_mult += 0.10


func _on_exp_pickup_area_entered(area: Area2D) -> void:
	if _dead:
		return
	var value: int = 1
	if area.has_method("get_value"):
		value = int(area.get_value())
	elif "value" in area:
		value = int(area.get("value"))
	if area.has_method("collect"):
		area.collect()
	else:
		area.queue_free()
	var adjusted: int = int(round(float(value) * exp_gain_mult))
	if adjusted < 1:
		adjusted = 1
	_add_exp(adjusted)


func _add_exp(amount: int) -> void:
	exp += amount
	while exp >= exp_to_next:
		exp -= exp_to_next
		level += 1
		exp_to_next = _required_exp_for_level(level)
		level_up.emit(level)
	exp_changed.emit(exp, exp_to_next)


func _required_exp_for_level(lv: int) -> int:
	if lv <= 1:
		return 5
	elif lv == 2:
		return 8
	elif lv == 3:
		return 12
	elif lv == 4:
		return 16
	else:
		return 16 + (lv - 4) * 6


func _draw() -> void:
	draw_circle(Vector2.ZERO, 14.0, Color("#3C7CE0"))
