extends EnemyBase

# M08 몽달귀신 — 종이꽃 직선 투사체 원거리. 손각시(M07)와 함께 있으면 외로움 페어 버프 발동.

const ENEMY_PROJECTILE: PackedScene = preload("res://scenes/enemies/enemy_projectile.tscn")

const DEFAULT_PARTNER_ID: StringName = &"m07_songakshi"
const DEFAULT_PAIR_SPEED_MULT: float = 1.30
const DEFAULT_PAIR_DAMAGE_MULT: float = 1.20
const PAIR_RANGE_PX: float = 240.0
const PAIR_RECHECK_INTERVAL_S: float = 0.5
const PAPER_FLOWER_COLOR: Color = Color(0.95, 0.5, 0.7)

const FALLBACK_COLOR: Color = Color(0.55, 0.45, 0.55, 1.0)
const FALLBACK_W: float = 14.0
const FALLBACK_H: float = 24.0

var _partner_id: StringName = DEFAULT_PARTNER_ID
var _pair_speed_mult: float = DEFAULT_PAIR_SPEED_MULT
var _pair_damage_mult: float = DEFAULT_PAIR_DAMAGE_MULT

var _attack_cd: float = 1.8
var _attack_timer: float = 0.0
var _telegraph_timer: float = 0.0
var _is_telegraphing: bool = false
var _ranged_range: float = 200.0
var _ranged_speed: float = 160.0
var _ranged_damage: int = 5

var _base_move_speed: float = 55.0
var _base_contact_damage: int = 4
var _pair_check_timer: float = 0.0
var _pair_active: bool = false


func _ready() -> void:
	if data == null:
		max_hp = 18
		move_speed = 55.0
		contact_damage = 4
		exp_drop_value = 4
		coin_drop_value = 1
		coin_drop_chance = 0.12
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("loneliness_partner_id"):
			_partner_id = StringName(str(params["loneliness_partner_id"]))
		if params.has("loneliness_speed_buff_mult"):
			_pair_speed_mult = float(params["loneliness_speed_buff_mult"])
		if params.has("loneliness_damage_buff_mult"):
			_pair_damage_mult = float(params["loneliness_damage_buff_mult"])
		if data.ranged_cooldown > 0.0:
			_attack_cd = data.ranged_cooldown
		if data.ranged_range_px > 0.0:
			_ranged_range = data.ranged_range_px
		if data.ranged_projectile_speed > 0.0:
			_ranged_speed = data.ranged_projectile_speed
		if data.ranged_damage > 0:
			_ranged_damage = data.ranged_damage
	_base_move_speed = move_speed
	_base_contact_damage = contact_damage
	_attack_timer = _attack_cd
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_pair_check_timer = maxf(0.0, _pair_check_timer - delta)
	if _pair_check_timer <= 0.0:
		_pair_check_timer = PAIR_RECHECK_INTERVAL_S
		_update_pair_buff()

	if _is_telegraphing:
		_telegraph_timer = maxf(0.0, _telegraph_timer - delta)
		if _telegraph_timer <= 0.0:
			_is_telegraphing = false
			_fire_paper_flower()
			_attack_timer = _attack_cd
	else:
		_attack_timer = maxf(0.0, _attack_timer - delta)
		if _attack_timer <= 0.0 and is_instance_valid(target):
			if global_position.distance_to(target.global_position) <= _ranged_range:
				_is_telegraphing = true
				var tel: float = data.ranged_telegraph if data != null else 0.2
				_telegraph_timer = tel
	super._physics_process(delta)


func _update_pair_buff() -> void:
	var partner_present: bool = false
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self:
			continue
		if not (e is EnemyBase):
			continue
		var d: EnemyData = (e as EnemyBase).data
		if d == null:
			continue
		if d.id != _partner_id:
			continue
		if (e as Node2D).global_position.distance_to(global_position) <= PAIR_RANGE_PX:
			partner_present = true
			break
	if partner_present and not _pair_active:
		_pair_active = true
		move_speed = _base_move_speed * _pair_speed_mult
		contact_damage = int(round(float(_base_contact_damage) * _pair_damage_mult))
	elif not partner_present and _pair_active:
		_pair_active = false
		move_speed = _base_move_speed
		contact_damage = _base_contact_damage


func _fire_paper_flower() -> void:
	if not is_instance_valid(target):
		return
	var p: EnemyProjectile = ENEMY_PROJECTILE.instantiate()
	p.speed = _ranged_speed
	var dmg: int = _ranged_damage
	if _pair_active:
		dmg = int(round(float(dmg) * _pair_damage_mult))
	p.damage = dmg
	p.lifetime = _ranged_range / maxf(1.0, _ranged_speed)
	p.direction = (target.global_position - global_position).normalized()
	p.hit_radius = 6.0
	p.color = PAPER_FLOWER_COLOR
	var scene: Node = get_tree().current_scene
	if scene != null:
		scene.add_child(p)
	else:
		get_parent().add_child(p)
	p.global_position = global_position


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	if _pair_active:
		c = c.lerp(Color(1.0, 0.55, 0.7), 0.4)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	if _is_telegraphing:
		draw_circle(Vector2(0, -FALLBACK_H * 0.5), 4.0, Color(1.0, 0.4, 0.4, 0.7))
