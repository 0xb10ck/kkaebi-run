extends EnemyBase

# M44 그림자 도깨비 — 일반 추적. 플레이어가 직전 4초 이내에 발동/획득한 스킬을 추적해
# mimic_cooldown_s(4.0s)마다 단순화된 형태(직선 투사체)로 1회 모방 발사한다.
# 시각적으로는 enemy_projectile을 재사용하되 modulate 색만 다르게 표시한다.
# 마지막 스킬 정보는 player.last_skill_id 또는 EventBus.skill_acquired 시그널을 통해 수집한다.
# 둘 다 없으면 nil 처리(이번 사이클 모방 안 함).

const ENEMY_PROJECTILE: PackedScene = preload("res://scenes/enemies/enemy_projectile.tscn")

const DEFAULT_MIMIC_WINDOW_S: float = 4.0
const DEFAULT_MIMIC_COOLDOWN_S: float = 4.0
const DEFAULT_MIMIC_DAMAGE: int = 12
const DEFAULT_MIMIC_RANGE_PX: float = 200.0
const DEFAULT_MIMIC_SPEED_PX: float = 180.0

const FALLBACK_COLOR: Color = Color(0.13, 0.10, 0.13, 1.0)
const FALLBACK_W: float = 20.0
const FALLBACK_H: float = 24.0
const RED_EYE_COLOR: Color = Color(0.95, 0.20, 0.20, 1.0)

const SKILL_COLOR_MAP: Dictionary = {
	&"fire_orb": Color(0.95, 0.40, 0.30, 0.95),
	&"frost_ring": Color(0.45, 0.75, 1.00, 0.95),
	&"vine_whip": Color(0.45, 0.85, 0.45, 0.95),
	&"gold_shield": Color(0.95, 0.90, 0.45, 0.95),
	&"rock_throw": Color(0.85, 0.75, 0.45, 0.95),
}
const DEFAULT_MIMIC_COLOR: Color = Color(0.25, 0.20, 0.30, 0.95)

var _mimic_window: float = DEFAULT_MIMIC_WINDOW_S
var _mimic_cooldown: float = DEFAULT_MIMIC_COOLDOWN_S
var _mimic_damage: int = DEFAULT_MIMIC_DAMAGE
var _mimic_range: float = DEFAULT_MIMIC_RANGE_PX
var _mimic_speed: float = DEFAULT_MIMIC_SPEED_PX

var _mimic_cd_timer: float = 0.0
var _last_skill_id: StringName = &""
var _last_skill_time: float = -1.0
var _fire_flash: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 70
		move_speed = 90.0
		contact_damage = 14
		exp_drop_value = 25
		coin_drop_value = 1
		coin_drop_chance = 0.48
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("mimic_player_skill_window_s"):
			_mimic_window = float(params["mimic_player_skill_window_s"])
		if params.has("mimic_cooldown_s"):
			_mimic_cooldown = float(params["mimic_cooldown_s"])
		if params.has("mimic_damage"):
			_mimic_damage = int(params["mimic_damage"])
		if params.has("mimic_range_px"):
			_mimic_range = float(params["mimic_range_px"])
		if data.ranged_damage > 0:
			_mimic_damage = data.ranged_damage
		if data.ranged_range_px > 0.0:
			_mimic_range = data.ranged_range_px
		if data.ranged_cooldown > 0.0:
			_mimic_cooldown = data.ranged_cooldown
	hp = max_hp
	_mimic_cd_timer = _mimic_cooldown
	# 글로벌 스킬 시그널 구독 — 플레이어 노드에 별도 last_skill_id가 있으면 그쪽을 우선한다.
	if Engine.has_singleton("EventBus") or _has_event_bus_autoload():
		EventBus.skill_acquired.connect(_on_skill_acquired)
		EventBus.skill_leveled.connect(_on_skill_leveled)


func _has_event_bus_autoload() -> bool:
	return get_tree() != null and get_tree().root.has_node("EventBus")


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_mimic_cd_timer = maxf(0.0, _mimic_cd_timer - delta)
	if _fire_flash > 0.0:
		_fire_flash = maxf(0.0, _fire_flash - delta)
	# 일반 추적/접촉/슬로우/스턴은 베이스 위임.
	super._physics_process(delta)
	if _mimic_cd_timer <= 0.0 and is_instance_valid(target):
		_try_mimic_fire()
		_mimic_cd_timer = _mimic_cooldown
	queue_redraw()


func _try_mimic_fire() -> void:
	var skill_id: StringName = _resolve_last_skill()
	if skill_id == &"":
		# 직전 4초 이내에 모방할 스킬 정보가 없음 — nil 처리(이번 사이클 모방 안 함).
		return
	_fire_mimic_projectile(skill_id)
	_fire_flash = 0.25


func _resolve_last_skill() -> StringName:
	# 1순위: 플레이어 노드의 last_skill_id (있으면).
	if is_instance_valid(target):
		if "last_skill_id" in target:
			var raw: Variant = target.get("last_skill_id")
			if raw != null and StringName(raw) != &"":
				return StringName(raw)
	# 2순위: 글로벌 시그널로 수집한 최근 스킬 — 윈도우(4s) 안일 때만 유효.
	if _last_skill_id != &"" and _last_skill_time >= 0.0:
		var now: float = Time.get_ticks_msec() / 1000.0
		if (now - _last_skill_time) <= _mimic_window:
			return _last_skill_id
	return &""


func _fire_mimic_projectile(skill_id: StringName) -> void:
	if not is_instance_valid(target):
		return
	var p: EnemyProjectile = ENEMY_PROJECTILE.instantiate()
	p.speed = _mimic_speed
	p.damage = _mimic_damage
	p.lifetime = _mimic_range / maxf(1.0, _mimic_speed)
	p.direction = (target.global_position - global_position).normalized()
	p.hit_radius = 7.0
	p.color = SKILL_COLOR_MAP.get(skill_id, DEFAULT_MIMIC_COLOR)
	var scene: Node = get_tree().current_scene
	if scene != null:
		scene.add_child(p)
	else:
		get_parent().add_child(p)
	p.global_position = global_position


func _on_skill_acquired(skill_id: StringName, _level: int) -> void:
	_last_skill_id = skill_id
	_last_skill_time = Time.get_ticks_msec() / 1000.0


func _on_skill_leveled(skill_id: StringName, _level: int) -> void:
	_last_skill_id = skill_id
	_last_skill_time = Time.get_ticks_msec() / 1000.0


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	if _fire_flash > 0.0:
		c = c.lerp(Color(0.95, 0.20, 0.20, 1.0), 0.30)
	# 본체 — 어두운 도깨비 실루엣.
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 외곽 흐림.
	var edge: Color = Color(c.r * 0.5, c.g * 0.5, c.b * 0.5, 0.55)
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), edge, false, 1.0)
	# 한쪽 눈만 붉음 — 정체성 상실 표식.
	draw_circle(Vector2(-FALLBACK_W * 0.20, -FALLBACK_H * 0.20), 1.8, RED_EYE_COLOR)
	# 다른 쪽은 비어 있음.
	draw_circle(Vector2(FALLBACK_W * 0.20, -FALLBACK_H * 0.20), 1.0, Color(0.05, 0.05, 0.05, 1.0))
	if _fire_flash > 0.0:
		var glow: Color = Color(1.0, 0.40, 0.30, 0.45 * (_fire_flash / 0.25))
		draw_arc(Vector2.ZERO, FALLBACK_W * 0.8, 0.0, TAU, 24, glow, 1.5)
