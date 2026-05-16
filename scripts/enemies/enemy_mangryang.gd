extends EnemyBase

# M22 망량 — 일반 추적 + 근접 contact_damage. 무리(3~6) 스폰을 가정.
# 결속(Bond): 같은 그룹의 망량이 처치되면 남은 개체에 누적 버프 — 이속 +10%, 데미지 +15% (스택 최대 5).
# 자신이 처치될 때 같은 그룹에 알림 → 다른 개체의 _on_ally_killed 호출.

const DEFAULT_BOND_GROUP_ID: StringName = &"m22_mangryang"
const DEFAULT_SPEED_BONUS_PER_KILL: float = 0.10
const DEFAULT_DAMAGE_BONUS_PER_KILL: float = 0.15
const DEFAULT_BOND_STACK_MAX: int = 5

const FALLBACK_COLOR: Color = Color(0.40, 0.45, 0.40, 0.85)
const FALLBACK_W: float = 16.0
const FALLBACK_H: float = 24.0

var _bond_group_id: StringName = DEFAULT_BOND_GROUP_ID
var _bond_speed_bonus: float = DEFAULT_SPEED_BONUS_PER_KILL
var _bond_damage_bonus: float = DEFAULT_DAMAGE_BONUS_PER_KILL
var _bond_stack_max: int = DEFAULT_BOND_STACK_MAX

var _bond_stacks: int = 0
var _base_move_speed_snapshot: float = 0.0
var _base_contact_damage_snapshot: int = 0


func _ready() -> void:
	if data == null:
		max_hp = 30
		move_speed = 70.0
		contact_damage = 8
		exp_drop_value = 9
		coin_drop_value = 1
		coin_drop_chance = 0.22
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("bond_group_id"):
			_bond_group_id = StringName(str(params["bond_group_id"]))
		if params.has("bond_speed_bonus_per_kill"):
			_bond_speed_bonus = float(params["bond_speed_bonus_per_kill"])
		if params.has("bond_damage_bonus_per_kill"):
			_bond_damage_bonus = float(params["bond_damage_bonus_per_kill"])
		if params.has("bond_stack_max"):
			_bond_stack_max = int(params["bond_stack_max"])
	add_to_group(_bond_group_id)
	_base_move_speed_snapshot = move_speed
	_base_contact_damage_snapshot = contact_damage
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	# 일반 추적은 EnemyBase 그대로 사용.
	super._physics_process(delta)
	queue_redraw()


func _on_ally_killed() -> void:
	if is_dying:
		return
	if _bond_stacks >= _bond_stack_max:
		return
	_bond_stacks += 1
	_apply_bond_stats()


func _apply_bond_stats() -> void:
	# 누적 곱연산. 스택당 +bonus.
	var speed_mult: float = pow(1.0 + _bond_speed_bonus, float(_bond_stacks))
	var dmg_mult: float = pow(1.0 + _bond_damage_bonus, float(_bond_stacks))
	move_speed = _base_move_speed_snapshot * speed_mult
	contact_damage = int(round(float(_base_contact_damage_snapshot) * dmg_mult))


func die() -> void:
	if is_dying:
		return
	# 죽기 직전 같은 그룹의 다른 망량에게 결속 알림.
	for n in get_tree().get_nodes_in_group(_bond_group_id):
		if n == self:
			continue
		if n is EnemyBase and not (n as EnemyBase).is_dying:
			if n.has_method("_on_ally_killed"):
				n._on_ally_killed()
	super.die()


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	# 누적 스택에 따라 색이 점점 짙어지는 시각 표현.
	if _bond_stacks > 0:
		var t: float = clampf(float(_bond_stacks) / float(maxi(1, _bond_stack_max)), 0.0, 1.0)
		c = c.lerp(Color(0.85, 0.2, 0.2, 0.95), t * 0.55)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 긴 팔 표시(좌우).
	var arm: Color = Color(0.30, 0.32, 0.28, 0.9)
	draw_line(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.1), Vector2(-FALLBACK_W * 0.5 - 5.0, FALLBACK_H * 0.4), arm, 1.5)
	draw_line(Vector2(FALLBACK_W * 0.5, -FALLBACK_H * 0.1), Vector2(FALLBACK_W * 0.5 + 5.0, FALLBACK_H * 0.4), arm, 1.5)
	# 흙·물풀 흔적(작은 점들).
	draw_circle(Vector2(-FALLBACK_W * 0.2, FALLBACK_H * 0.3), 1.2, Color(0.25, 0.18, 0.10, 1.0))
	draw_circle(Vector2(FALLBACK_W * 0.15, FALLBACK_H * 0.35), 1.2, Color(0.20, 0.30, 0.15, 1.0))
	# 스택 표시(머리 위 작은 점).
	for i in _bond_stacks:
		draw_circle(Vector2(-FALLBACK_W * 0.5 + float(i) * 3.0, -FALLBACK_H * 0.5 - 3.0), 1.2, Color(0.95, 0.4, 0.4, 1.0))
