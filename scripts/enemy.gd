class_name Enemy
extends CharacterBody2D


const CONTACT_COOLDOWN: float = 0.5
const EXP_GEM_PATH: String = "res://scenes/gameplay/exp_gem.tscn"


@export var max_hp: int = 10
@export var move_speed: float = 60.0
@export var contact_damage: int = 10
@export var exp_drop_value: int = 1


var hp: int = 10
var target: Node2D
var is_dying: bool = false

var _contact_timer: float = 0.0

@onready var _contact_area: Area2D = $ContactArea if has_node("ContactArea") else null


func _ready() -> void:
	hp = max_hp
	target = _resolve_target()
	if _contact_area:
		_contact_area.body_entered.connect(_on_contact_body_entered)
		_contact_area.area_entered.connect(_on_contact_area_entered)


func _resolve_target() -> Node2D:
	var t: Node = get_tree().get_first_node_in_group("player")
	if t and t is Node2D:
		return t
	var scene: Node = get_tree().current_scene
	if scene and scene.has_node("Player"):
		var p: Node = scene.get_node("Player")
		if p is Node2D:
			return p
	return null


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_contact_timer = maxf(0.0, _contact_timer - delta)
	if not is_instance_valid(target):
		target = _resolve_target()
		if not is_instance_valid(target):
			return
	var dir: Vector2 = (target.global_position - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()
	if _contact_timer <= 0.0 and _contact_area:
		for body in _contact_area.get_overlapping_bodies():
			if body == target:
				_deal_contact_damage()
				break


func _on_contact_body_entered(body: Node) -> void:
	if body == target:
		_deal_contact_damage()


func _on_contact_area_entered(_area: Area2D) -> void:
	pass


func _deal_contact_damage() -> void:
	if is_dying or _contact_timer > 0.0:
		return
	if not is_instance_valid(target):
		return
	if target.has_method("take_damage"):
		target.take_damage(contact_damage)
	_on_contact_hit(target)
	_contact_timer = CONTACT_COOLDOWN


func _on_contact_hit(_player: Node2D) -> void:
	pass


func take_damage(amount: int) -> void:
	if is_dying:
		return
	hp = max(0, hp - amount)
	if hp <= 0:
		die()


func die() -> void:
	if is_dying:
		return
	is_dying = true
	_drop_exp_gem()
	queue_free()


func _drop_exp_gem() -> void:
	if exp_drop_value <= 0:
		return
	if not ResourceLoader.exists(EXP_GEM_PATH):
		return
	var scene: PackedScene = load(EXP_GEM_PATH)
	if scene == null:
		return
	var gem: Node2D = scene.instantiate()
	if gem == null:
		return
	gem.global_position = global_position
	if gem.has_method("set_value"):
		gem.set_value(exp_drop_value)
	elif "value" in gem:
		gem.value = exp_drop_value
	var main: Node = get_tree().current_scene
	var container: Node = null
	if main and main.has_node("GemContainer"):
		container = main.get_node("GemContainer")
	if container:
		container.add_child(gem)
	elif main:
		main.add_child(gem)


func _draw() -> void:
	pass
