extends EnemyBase

# M30 불가사리 — 매우 높은 HP, 매우 느린 이동.
# 금(金) 속성 피격 시 ×2 데미지, 그 외 속성은 ×0.7.
# 10초마다 자기 주변 40px 내 'metal_shard' 그룹 노드를 흡수하여 1개당 HP +5 회복.

const DEFAULT_METAL_ABSORB_INTERVAL_S: float = 10.0
const DEFAULT_METAL_ABSORB_RADIUS_PX: float = 40.0
const DEFAULT_METAL_ABSORB_HEAL_PER_SHARD: int = 5
const DEFAULT_WEAKNESS_ELEMENT: int = GameEnums.Element.METAL
const DEFAULT_WEAKNESS_MULT: float = 2.0
const DEFAULT_RESIST_OTHER_MULT: float = 0.7
const METAL_SHARD_GROUP: StringName = &"metal_shard"

const FALLBACK_COLOR: Color = Color(0.15, 0.13, 0.18, 1.0)
const FALLBACK_W: float = 28.0
const FALLBACK_H: float = 22.0

var _absorb_interval: float = DEFAULT_METAL_ABSORB_INTERVAL_S
var _absorb_radius: float = DEFAULT_METAL_ABSORB_RADIUS_PX
var _absorb_heal: int = DEFAULT_METAL_ABSORB_HEAL_PER_SHARD
var _weakness_element: int = DEFAULT_WEAKNESS_ELEMENT
var _weakness_mult: float = DEFAULT_WEAKNESS_MULT
var _resist_other_mult: float = DEFAULT_RESIST_OTHER_MULT

var _absorb_timer: float = 0.0
var _last_absorb_glow: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 90
		move_speed = 40.0
		contact_damage = 14
		exp_drop_value = 22
		coin_drop_value = 1
		coin_drop_chance = 0.50
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("metal_absorb_interval_s"):
			_absorb_interval = float(params["metal_absorb_interval_s"])
		if params.has("metal_absorb_radius_px"):
			_absorb_radius = float(params["metal_absorb_radius_px"])
		if params.has("metal_absorb_heal_per_shard"):
			_absorb_heal = int(params["metal_absorb_heal_per_shard"])
		if params.has("weakness_element"):
			_weakness_element = int(params["weakness_element"])
		if params.has("weakness_damage_mult"):
			_weakness_mult = float(params["weakness_damage_mult"])
		if params.has("resist_other_elements_mult"):
			_resist_other_mult = float(params["resist_other_elements_mult"])
	hp = max_hp
	_absorb_timer = _absorb_interval


func _physics_process(delta: float) -> void:
	if is_dying:
		super._physics_process(delta)
		return
	_absorb_timer = maxf(0.0, _absorb_timer - delta)
	if _last_absorb_glow > 0.0:
		_last_absorb_glow = maxf(0.0, _last_absorb_glow - delta)
	if _absorb_timer <= 0.0:
		_run_metal_absorb()
		_absorb_timer = _absorb_interval
	super._physics_process(delta)
	queue_redraw()


func _run_metal_absorb() -> void:
	var nodes: Array = get_tree().get_nodes_in_group(METAL_SHARD_GROUP)
	if nodes.is_empty():
		return
	var absorbed: int = 0
	for n in nodes:
		if not is_instance_valid(n):
			continue
		if not (n is Node2D):
			continue
		var n2d: Node2D = n
		if n2d.global_position.distance_to(global_position) <= _absorb_radius:
			absorbed += 1
			n2d.queue_free()
	if absorbed > 0:
		hp = mini(max_hp, hp + _absorb_heal * absorbed)
		_last_absorb_glow = 0.4


func take_damage(amount: int, attacker: Object = null) -> void:
	if is_dying:
		return
	var mult: float = _element_multiplier_for(attacker)
	var scaled: int = maxi(0, int(round(float(amount) * mult)))
	super.take_damage(scaled, attacker)


func _element_multiplier_for(attacker: Object) -> float:
	# 공격자 노드/스킬에 element 필드가 있으면 참조한다.
	# 1) 약점 속성(금) → ×_weakness_mult
	# 2) 명시된 다른 속성(NONE 제외) → ×_resist_other_mult
	# 3) 속성 정보 없음/NONE → ×1.0
	var el: int = -1
	if attacker != null:
		if "element" in attacker:
			el = int(attacker.element)
		elif attacker.has_method("get") and attacker.get("element") != null:
			el = int(attacker.get("element"))
	if el < 0:
		return 1.0
	if el == _weakness_element:
		return _weakness_mult
	if el == GameEnums.Element.NONE:
		return 1.0
	return _resist_other_mult


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	if _last_absorb_glow > 0.0:
		c = c.lerp(Color(0.85, 0.85, 0.55, 1.0), 0.45)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 몸에 박힌 금속 조각 4개.
	var metal: Color = Color(0.75, 0.78, 0.82, 1.0)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.35, -FALLBACK_H * 0.2), Vector2(4.0, 3.0)), metal)
	draw_rect(Rect2(Vector2(FALLBACK_W * 0.15, -FALLBACK_H * 0.3), Vector2(3.0, 4.0)), metal)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.1, FALLBACK_H * 0.1), Vector2(4.0, 3.0)), metal)
	draw_rect(Rect2(Vector2(FALLBACK_W * 0.25, FALLBACK_H * 0.05), Vector2(3.0, 3.0)), metal)
	# 작은 뿔.
	draw_line(Vector2(-4.0, -FALLBACK_H * 0.5), Vector2(-4.0, -FALLBACK_H * 0.5 - 4.0), Color(0.85, 0.85, 0.85, 1.0), 1.5)
	draw_line(Vector2(4.0, -FALLBACK_H * 0.5), Vector2(4.0, -FALLBACK_H * 0.5 - 4.0), Color(0.85, 0.85, 0.85, 1.0), 1.5)
	if _last_absorb_glow > 0.0:
		draw_arc(Vector2.ZERO, _absorb_radius, 0.0, TAU, 32, Color(0.95, 0.85, 0.40, 0.35), 1.5)
