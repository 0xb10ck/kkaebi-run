extends CharacterBody2D

signal died

@export var base_speed: float = 180.0
@export var iframe_duration: float = 0.6

@onready var hurt_box: Area2D = $HurtBox
@onready var pickup_area: Area2D = $PickupArea
@onready var weapon: Node2D = $Weapon
@onready var skill_anchor: Node2D = $SkillAnchor

var _iframe_until: float = 0.0
var _slow_until: float = 0.0
var _slow_factor: float = 0.0
var _shields: Array = []
var _alive: bool = true


func _ready() -> void:
	add_to_group("player")


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	var dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if dir.length() > 0.0:
		dir = dir.normalized()
	var now := _now()
	var slow_mult := 1.0
	if now < _slow_until:
		slow_mult = 1.0 - _slow_factor
	var speed := base_speed * GameState.bonus_move_speed_mult * slow_mult
	velocity = dir * speed
	move_and_slide()
	_tick_contact_damage(now)


func _tick_contact_damage(now: float) -> void:
	if now < _iframe_until:
		return
	for body in hurt_box.get_overlapping_bodies():
		if body == self:
			continue
		if body.has_method("get_enemy_data"):
			var data: EnemyData = body.get_enemy_data()
			if data == null:
				continue
			var dmg := int(round(body.get_current_damage()))
			apply_enemy_contact(dmg, data, now)
			break


func apply_enemy_contact(amount: int, data: EnemyData, now: float = -1.0) -> void:
	if not _alive:
		return
	if now < 0.0:
		now = _now()
	if now < _iframe_until:
		return
	if _try_consume_shield():
		_iframe_until = now + iframe_duration
		return
	GameState.deal_damage_to_player(amount)
	_iframe_until = now + iframe_duration
	if data and data.on_contact_effect == &"slow_player":
		_slow_until = now + data.slow_duration
		_slow_factor = data.slow_factor
	if GameState.current_hp <= 0 and _alive:
		_alive = false
		died.emit()


func register_shield(shield: Node) -> void:
	if not _shields.has(shield):
		_shields.append(shield)


func unregister_shield(shield: Node) -> void:
	_shields.erase(shield)


func _try_consume_shield() -> bool:
	for s in _shields:
		if is_instance_valid(s) and s.has_method("consume_shield"):
			if s.consume_shield():
				return true
	return false


func is_alive() -> bool:
	return _alive


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
