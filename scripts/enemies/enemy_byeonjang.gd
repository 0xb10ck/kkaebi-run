extends EnemyBase

# M52 변장 도깨비 — 스폰 시 보물 상자 또는 금화 더미 외형으로 위장(50:50).
# 위장 중에는 이동/공격 없이 정지하며 받는 피해 × disguise_damage_taken_mult(0.3).
# 플레이어가 reveal_trigger_player_radius_px(40) 이내 진입하거나 피격(reveal_trigger_on_hit=true) 시
# 정체를 드러내며 자기 주변 disguise_burst_radius_px(80) 광역 데미지 disguise_burst_damage(10) 발동.
# 정체 해제 후에는 일반 추적(chase_after_reveal=true). 재발동은 disguise_burst_cooldown_s(4.0) 이후
# 동일 광역 공격을 반복할 수 있다(주변 80px에 플레이어가 있을 때만).

const DEFAULT_REVEAL_RADIUS_PX: float = 40.0
const DEFAULT_REVEAL_ON_HIT: bool = true
const DEFAULT_BURST_RADIUS_PX: float = 80.0
const DEFAULT_BURST_DAMAGE: int = 10
const DEFAULT_BURST_COOLDOWN_S: float = 4.0
const DEFAULT_DISGUISE_DAMAGE_MULT: float = 0.30
const DEFAULT_CHASE_AFTER_REVEAL: bool = true

const FALLBACK_COLOR: Color = Color(0.85, 0.70, 0.20, 1.0)
const FALLBACK_W: float = 16.0
const FALLBACK_H: float = 16.0
const CHEST_WOOD: Color = Color(0.45, 0.30, 0.15, 1.0)
const CHEST_TRIM: Color = Color(0.85, 0.65, 0.20, 1.0)
const COIN_COLOR: Color = Color(0.95, 0.85, 0.25, 1.0)
const COIN_SHADE: Color = Color(0.70, 0.55, 0.15, 1.0)
const REVEAL_GLOW: Color = Color(0.95, 0.55, 0.25, 0.45)
const BURST_COLOR: Color = Color(1.0, 0.70, 0.30, 0.35)

enum Form { TREASURE_CHEST, GOLD_PILE, REVEALED }

var _reveal_radius: float = DEFAULT_REVEAL_RADIUS_PX
var _reveal_on_hit: bool = DEFAULT_REVEAL_ON_HIT
var _burst_radius: float = DEFAULT_BURST_RADIUS_PX
var _burst_damage: int = DEFAULT_BURST_DAMAGE
var _burst_cooldown: float = DEFAULT_BURST_COOLDOWN_S
var _disguise_damage_mult: float = DEFAULT_DISGUISE_DAMAGE_MULT
var _chase_after_reveal: bool = DEFAULT_CHASE_AFTER_REVEAL
var _chest_chance: float = 0.5

var _form: int = Form.TREASURE_CHEST
var _is_revealed: bool = false
var _burst_cd_timer: float = 0.0
var _burst_flash: float = 0.0
var _reveal_flash: float = 0.0


func _ready() -> void:
	if data == null:
		max_hp = 40
		move_speed = 80.0
		contact_damage = 10
		exp_drop_value = 18
		coin_drop_value = 1
		coin_drop_chance = 0.70
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("reveal_trigger_player_radius_px"):
			_reveal_radius = float(params["reveal_trigger_player_radius_px"])
		if params.has("reveal_trigger_on_hit"):
			_reveal_on_hit = bool(params["reveal_trigger_on_hit"])
		if params.has("disguise_burst_radius_px"):
			_burst_radius = float(params["disguise_burst_radius_px"])
		if params.has("disguise_burst_damage"):
			_burst_damage = int(params["disguise_burst_damage"])
		if params.has("disguise_burst_cooldown_s"):
			_burst_cooldown = float(params["disguise_burst_cooldown_s"])
		if params.has("disguise_damage_taken_mult"):
			_disguise_damage_mult = float(params["disguise_damage_taken_mult"])
		if params.has("chase_after_reveal"):
			_chase_after_reveal = bool(params["chase_after_reveal"])
		if params.has("disguise_treasure_chest_chance"):
			_chest_chance = float(params["disguise_treasure_chest_chance"])
		if data.ranged_range_px > 0.0:
			_burst_radius = data.ranged_range_px
		if data.ranged_damage > 0:
			_burst_damage = data.ranged_damage
		if data.ranged_cooldown > 0.0:
			_burst_cooldown = data.ranged_cooldown
	hp = max_hp
	# 스폰 시 변장 형태 결정 — chest 또는 gold pile.
	_form = Form.TREASURE_CHEST if randf() < _chest_chance else Form.GOLD_PILE
	_is_revealed = false
	_burst_cd_timer = 0.0


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_contact_timer = maxf(0.0, _contact_timer - delta)
	if _slow_remaining > 0.0:
		_slow_remaining -= delta
		if _slow_remaining <= 0.0:
			_slow_remaining = 0.0
			_slow_factor = 1.0
	if _stun_remaining > 0.0:
		_stun_remaining = maxf(0.0, _stun_remaining - delta)
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return
	if _burst_flash > 0.0:
		_burst_flash = maxf(0.0, _burst_flash - delta)
	if _reveal_flash > 0.0:
		_reveal_flash = maxf(0.0, _reveal_flash - delta)
	_burst_cd_timer = maxf(0.0, _burst_cd_timer - delta)
	if not is_instance_valid(target):
		target = _resolve_target()
		if not is_instance_valid(target):
			velocity = Vector2.ZERO
			move_and_slide()
			queue_redraw()
			return
	if not _is_revealed:
		_run_disguised()
	else:
		_run_revealed(delta)
	queue_redraw()


func _run_disguised() -> void:
	# 정지 — 이동/공격 없음.
	velocity = Vector2.ZERO
	move_and_slide()
	var d: float = global_position.distance_to(target.global_position)
	if d <= _reveal_radius:
		_reveal()


func _run_revealed(delta: float) -> void:
	if _chase_after_reveal:
		var dir: Vector2 = (target.global_position - global_position).normalized()
		velocity = dir * move_speed * _slow_factor
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	# 재발동 — 정체 해제 후에도 burst_cooldown마다 80px 안에 플레이어가 있으면 광역.
	if _burst_cd_timer <= 0.0 and is_instance_valid(target):
		var d: float = global_position.distance_to(target.global_position)
		if d <= _burst_radius:
			_emit_burst()
			_burst_cd_timer = _burst_cooldown
	if _contact_timer <= 0.0 and _contact_area:
		for body in _contact_area.get_overlapping_bodies():
			if body == target:
				_deal_contact_damage()
				break


func _reveal() -> void:
	if _is_revealed:
		return
	_is_revealed = true
	_form = Form.REVEALED
	_reveal_flash = 0.4
	_emit_burst()
	_burst_cd_timer = _burst_cooldown


func _emit_burst() -> void:
	if not is_instance_valid(target):
		return
	_burst_flash = 0.30
	var d: float = global_position.distance_to(target.global_position)
	if d <= _burst_radius:
		if target.has_method("take_damage"):
			target.take_damage(_burst_damage)


func take_damage(amount: int, attacker: Object = null) -> void:
	# 위장 중에는 받는 피해 ×0.3 — 그리고 피격은 reveal 트리거.
	var amt: int = amount
	if not _is_revealed:
		amt = int(round(float(amount) * _disguise_damage_mult))
		amt = maxi(amt, 0)
	super.take_damage(amt, attacker)
	if not _is_revealed and _reveal_on_hit and not is_dying:
		_reveal()


func _draw() -> void:
	var base_c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	match _form:
		Form.TREASURE_CHEST:
			_draw_chest()
		Form.GOLD_PILE:
			_draw_pile()
		Form.REVEALED:
			_draw_goblin(base_c)
	if _burst_flash > 0.0:
		var alpha: float = BURST_COLOR.a * (_burst_flash / 0.30)
		var col: Color = Color(BURST_COLOR.r, BURST_COLOR.g, BURST_COLOR.b, alpha)
		draw_circle(Vector2.ZERO, _burst_radius, col)
	if _reveal_flash > 0.0:
		draw_arc(Vector2.ZERO, FALLBACK_W * 0.9, 0.0, TAU, 24, REVEAL_GLOW, 2.0)


func _draw_chest() -> void:
	# 보물 상자 — 16×14 박스 + 황금 띠.
	var w: float = FALLBACK_W
	var h: float = 14.0
	draw_rect(Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h)), CHEST_WOOD)
	draw_rect(Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h)), CHEST_TRIM, false, 1.0)
	# 가로 황금 띠.
	draw_rect(Rect2(Vector2(-w * 0.5, -1.0), Vector2(w, 2.0)), CHEST_TRIM)
	# 자물쇠.
	draw_rect(Rect2(Vector2(-2.0, -1.5), Vector2(4.0, 3.0)), Color(0.95, 0.85, 0.30, 1.0))


func _draw_pile() -> void:
	# 금화 더미 — 작은 원반 4~5개.
	var coins: Array = [
		Vector2(-4.0, 2.0),
		Vector2(4.0, 2.0),
		Vector2(0.0, 1.0),
		Vector2(-2.0, -1.0),
		Vector2(2.0, -1.0),
	]
	for p in coins:
		draw_circle(p, 3.5, COIN_SHADE)
		draw_circle(p + Vector2(0.0, -0.5), 3.0, COIN_COLOR)


func _draw_goblin(c: Color) -> void:
	# 정체 — 작은 도깨비.
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 작은 뿔 두 개.
	var horn: Color = Color(c.r * 0.55, c.g * 0.55, c.b * 0.55, 1.0)
	draw_line(Vector2(-FALLBACK_W * 0.30, -FALLBACK_H * 0.5), Vector2(-FALLBACK_W * 0.30, -FALLBACK_H * 0.5 - 4.0), horn, 1.5)
	draw_line(Vector2(FALLBACK_W * 0.30, -FALLBACK_H * 0.5), Vector2(FALLBACK_W * 0.30, -FALLBACK_H * 0.5 - 4.0), horn, 1.5)
	# 노란 눈.
	draw_circle(Vector2(-FALLBACK_W * 0.20, -FALLBACK_H * 0.15), 1.6, Color(0.95, 0.90, 0.30, 1.0))
	draw_circle(Vector2(FALLBACK_W * 0.20, -FALLBACK_H * 0.15), 1.6, Color(0.95, 0.90, 0.30, 1.0))
	# 입.
	draw_line(Vector2(-3.0, FALLBACK_H * 0.15), Vector2(3.0, FALLBACK_H * 0.15), Color(0.10, 0.05, 0.05, 1.0), 1.0)
