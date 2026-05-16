extends EnemyBase

# M50 노름꾼 도깨비 — 일반 추적. 매 yut_throw_interval_s(5.0s)마다 윷 던지기 발동:
# 5가지 결과(개/도/걸/윷/모) 균등 추첨 후 결과별 효과 실행.
#  - 모: 자기 정면(또는 플레이어 방향)에 mo_fire_aoe_size_px(32) 화염 단발 mo_fire_aoe_damage(18).
#  - 윷: 4방향(상/하/좌/우) 엽전 투사체 동시 발사(enemy_projectile 재사용, yut_coin_damage 12).
#  - 걸: 플레이어 이속 geol_player_slow_value(-0.2) 3초 디버프.
#  - 도: 자기 HP +do_self_heal_amount(20) 회복(max_hp 초과 금지).
#  - 개: 허수(아무 효과 없음, 짧은 cosmetic 모션).

const ENEMY_PROJECTILE: PackedScene = preload("res://scenes/enemies/enemy_projectile.tscn")

const DEFAULT_YUT_INTERVAL_S: float = 5.0
const DEFAULT_YUT_RANGE_PX: float = 240.0
const DEFAULT_MO_AOE_SIZE_PX: float = 32.0
const DEFAULT_MO_AOE_DAMAGE: int = 18
const DEFAULT_YUT_COIN_COUNT: int = 4
const DEFAULT_YUT_COIN_DAMAGE: int = 12
const DEFAULT_YUT_COIN_SPEED_PX: float = 180.0
const DEFAULT_GEOL_SLOW_VALUE: float = -0.2
const DEFAULT_GEOL_SLOW_DURATION_S: float = 3.0
const DEFAULT_DO_SELF_HEAL: int = 20

const FALLBACK_COLOR: Color = Color(0.80, 0.20, 0.25, 1.0)
const FALLBACK_W: float = 16.0
const FALLBACK_H: float = 22.0
const COIN_COLOR: Color = Color(0.95, 0.85, 0.30, 0.95)
const FIRE_COLOR: Color = Color(0.95, 0.45, 0.20, 0.85)
const YUT_STICK_COLOR: Color = Color(0.85, 0.75, 0.55, 1.0)

enum Outcome { GAE, DO, GEOL, YUT, MO }

var _yut_interval: float = DEFAULT_YUT_INTERVAL_S
var _yut_range: float = DEFAULT_YUT_RANGE_PX
var _mo_aoe_size: float = DEFAULT_MO_AOE_SIZE_PX
var _mo_aoe_damage: int = DEFAULT_MO_AOE_DAMAGE
var _yut_coin_count: int = DEFAULT_YUT_COIN_COUNT
var _yut_coin_damage: int = DEFAULT_YUT_COIN_DAMAGE
var _yut_coin_speed: float = DEFAULT_YUT_COIN_SPEED_PX
var _geol_slow_value: float = DEFAULT_GEOL_SLOW_VALUE
var _geol_slow_duration: float = DEFAULT_GEOL_SLOW_DURATION_S
var _do_self_heal: int = DEFAULT_DO_SELF_HEAL
var _outcomes: Array = ["gae", "do", "geol", "yut", "mo"]

var _throw_cd_timer: float = 0.0
var _last_outcome: int = Outcome.GAE
var _outcome_flash: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 45
		move_speed = 60.0
		contact_damage = 7
		exp_drop_value = 16
		coin_drop_value = 1
		coin_drop_chance = 0.70
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("yut_throw_interval_s"):
			_yut_interval = float(params["yut_throw_interval_s"])
		if params.has("yut_throw_range_px"):
			_yut_range = float(params["yut_throw_range_px"])
		if params.has("mo_fire_aoe_size_px"):
			_mo_aoe_size = float(params["mo_fire_aoe_size_px"])
		if params.has("mo_fire_aoe_damage"):
			_mo_aoe_damage = int(params["mo_fire_aoe_damage"])
		if params.has("yut_coin_directions"):
			_yut_coin_count = int(params["yut_coin_directions"])
		if params.has("yut_coin_damage"):
			_yut_coin_damage = int(params["yut_coin_damage"])
		if params.has("yut_coin_projectile_speed"):
			_yut_coin_speed = float(params["yut_coin_projectile_speed"])
		if params.has("geol_player_slow_value"):
			_geol_slow_value = float(params["geol_player_slow_value"])
		if params.has("geol_player_slow_duration_s"):
			_geol_slow_duration = float(params["geol_player_slow_duration_s"])
		if params.has("do_self_heal_amount"):
			_do_self_heal = int(params["do_self_heal_amount"])
		if params.has("yut_outcomes"):
			_outcomes = params["yut_outcomes"]
		if data.attack_cooldown > 0.0:
			_yut_interval = data.attack_cooldown
		if data.ranged_range_px > 0.0:
			_yut_range = data.ranged_range_px
	hp = max_hp
	_throw_cd_timer = _yut_interval


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_throw_cd_timer = maxf(0.0, _throw_cd_timer - delta)
	if _outcome_flash > 0.0:
		_outcome_flash = maxf(0.0, _outcome_flash - delta)
	# 일반 추적/접촉/슬로우/스턴은 베이스 위임.
	super._physics_process(delta)
	if _throw_cd_timer <= 0.0:
		_throw_yut()
		_throw_cd_timer = _yut_interval
	queue_redraw()


func _throw_yut() -> void:
	# 5가지 결과 균등(또는 사양 명시) 추첨.
	var pool: Array = _outcomes if (_outcomes != null and not _outcomes.is_empty()) else ["gae", "do", "geol", "yut", "mo"]
	var pick: String = str(pool[randi() % pool.size()])
	_last_outcome = _outcome_from_string(pick)
	_outcome_flash = 0.40
	match _last_outcome:
		Outcome.MO:
			_resolve_mo()
		Outcome.YUT:
			_resolve_yut()
		Outcome.GEOL:
			_resolve_geol()
		Outcome.DO:
			_resolve_do()
		Outcome.GAE:
			_resolve_gae()


func _outcome_from_string(s: String) -> int:
	match s:
		"mo":
			return Outcome.MO
		"yut":
			return Outcome.YUT
		"geol":
			return Outcome.GEOL
		"do":
			return Outcome.DO
		_:
			return Outcome.GAE


func _resolve_mo() -> void:
	# 자기 정면(플레이어 방향)에 _mo_aoe_size × _mo_aoe_size 화염 단발.
	if not is_instance_valid(target):
		return
	var dir: Vector2 = (target.global_position - global_position)
	if dir.length_squared() <= 0.0001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	# AOE 박스 중심 — 자기 위치 + 정면 × (_mo_aoe_size × 0.5).
	var right: Vector2 = Vector2(dir.y, -dir.x)
	var center: Vector2 = global_position + dir * (_mo_aoe_size * 0.5)
	var rel: Vector2 = target.global_position - center
	var local_y: float = rel.dot(dir)
	var local_x: float = rel.dot(right)
	if absf(local_x) <= _mo_aoe_size * 0.5 and absf(local_y) <= _mo_aoe_size * 0.5:
		if target.has_method("take_damage"):
			target.take_damage(_mo_aoe_damage)


func _resolve_yut() -> void:
	# 4방향(상/하/좌/우) 엽전 동시 발사.
	var dirs: Array = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	var n: int = mini(_yut_coin_count, dirs.size())
	for i in n:
		var p: EnemyProjectile = ENEMY_PROJECTILE.instantiate()
		p.speed = _yut_coin_speed
		p.damage = _yut_coin_damage
		p.lifetime = _yut_range / maxf(1.0, _yut_coin_speed)
		p.direction = dirs[i]
		p.hit_radius = 6.0
		p.color = COIN_COLOR
		var scene: Node = get_tree().current_scene
		if scene != null:
			scene.add_child(p)
		else:
			get_parent().add_child(p)
		p.global_position = global_position


func _resolve_geol() -> void:
	# 플레이어 이속 -20% 3초 — apply_slow는 곱셈 팩터(0~1) 형태. -0.2 → factor 0.8.
	if not is_instance_valid(target):
		return
	var factor: float = clampf(1.0 + _geol_slow_value, 0.05, 1.0)
	if target.has_method("apply_slow"):
		target.apply_slow(factor, _geol_slow_duration)


func _resolve_do() -> void:
	# 자기 HP +_do_self_heal 회복(max_hp 초과 금지).
	hp = mini(max_hp, hp + _do_self_heal)


func _resolve_gae() -> void:
	# 허수 — 아무 효과 없음.
	pass


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	if _outcome_flash > 0.0:
		match _last_outcome:
			Outcome.MO:
				c = c.lerp(FIRE_COLOR, 0.30)
			Outcome.YUT:
				c = c.lerp(COIN_COLOR, 0.30)
			Outcome.GEOL:
				c = c.lerp(Color(0.40, 0.70, 1.0, 1.0), 0.30)
			Outcome.DO:
				c = c.lerp(Color(0.40, 0.95, 0.40, 1.0), 0.30)
			Outcome.GAE:
				c = c.lerp(Color(0.50, 0.50, 0.55, 1.0), 0.25)
	# 본체 — 다홍 조끼 도깨비.
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 한 손에 윷가락 4개(왼쪽).
	for i in 4:
		var x: float = -FALLBACK_W * 0.5 - 4.0 + float(i) * 0.8
		draw_line(Vector2(x, -FALLBACK_H * 0.10), Vector2(x, FALLBACK_H * 0.20), YUT_STICK_COLOR, 1.0)
	# 다른 손에 엽전 한 꿰미(오른쪽).
	draw_circle(Vector2(FALLBACK_W * 0.5 + 3.0, 0.0), 1.6, COIN_COLOR)
	draw_circle(Vector2(FALLBACK_W * 0.5 + 3.0, 4.0), 1.6, COIN_COLOR)
	# 직전 결과 텍스트 대신 — 결과별 작은 표식.
	if _outcome_flash > 0.0:
		var ind_pos: Vector2 = Vector2(0.0, -FALLBACK_H * 0.5 - 5.0)
		match _last_outcome:
			Outcome.MO:
				draw_circle(ind_pos, 2.5, FIRE_COLOR)
			Outcome.YUT:
				for i in 4:
					var ang: float = TAU * float(i) / 4.0
					draw_line(ind_pos, ind_pos + Vector2(cos(ang), sin(ang)) * 4.0, COIN_COLOR, 1.0)
			Outcome.GEOL:
				draw_circle(ind_pos, 2.0, Color(0.40, 0.70, 1.0, 0.9))
			Outcome.DO:
				draw_circle(ind_pos, 2.0, Color(0.40, 0.95, 0.40, 0.9))
			Outcome.GAE:
				draw_line(ind_pos + Vector2(-2.0, -2.0), ind_pos + Vector2(2.0, 2.0), Color(0.55, 0.55, 0.60, 0.7), 1.0)
				draw_line(ind_pos + Vector2(-2.0, 2.0), ind_pos + Vector2(2.0, -2.0), Color(0.55, 0.55, 0.60, 0.7), 1.0)
