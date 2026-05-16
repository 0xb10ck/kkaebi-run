extends EnemyBase

# M25 백골귀 — 일반 추적. HP 0 도달 시 즉사하지 않고 "분해 상태"로 1.5초 보류.
# 분해 동안 추가 피격이 들어오면 진짜 사망. 피격 없이 1.5초가 지나면 HP 30%로 부활, 이속 영구 +20%.
# 부활은 인스턴스당 1회만 발동(이미 1회 발동했다면 이후 HP 0 도달 시 즉시 사망).

const DEFAULT_REASSEMBLE_WINDOW_S: float = 1.5
const DEFAULT_REVIVE_HP_PCT: float = 0.30
const DEFAULT_POST_SPEED_MULT: float = 1.20
const DEFAULT_MAX_TRIGGERS: int = 1
const DEFAULT_CANCEL_ON_HIT: bool = true

const FALLBACK_COLOR: Color = Color(0.85, 0.80, 0.65, 1.0)
const FALLBACK_W: float = 26.0
const FALLBACK_H: float = 34.0

enum State { NORMAL, DISASSEMBLED }

var _reassemble_window: float = DEFAULT_REASSEMBLE_WINDOW_S
var _revive_hp_pct: float = DEFAULT_REVIVE_HP_PCT
var _post_speed_mult: float = DEFAULT_POST_SPEED_MULT
var _max_triggers: int = DEFAULT_MAX_TRIGGERS
var _cancel_on_hit: bool = DEFAULT_CANCEL_ON_HIT

var _state: int = State.NORMAL
var _reassemble_timer: float = 0.0
var _trigger_count: int = 0


func _ready() -> void:
	if data == null:
		max_hp = 36
		move_speed = 60.0
		contact_damage = 8
		exp_drop_value = 11
		coin_drop_value = 1
		coin_drop_chance = 0.24
	super._ready()
	if data != null:
		var params: Dictionary = data.special_params
		if params.has("reassemble_window_s"):
			_reassemble_window = float(params["reassemble_window_s"])
		if params.has("reassemble_revive_hp_pct"):
			_revive_hp_pct = float(params["reassemble_revive_hp_pct"])
		if params.has("reassemble_post_speed_mult"):
			_post_speed_mult = float(params["reassemble_post_speed_mult"])
		if params.has("reassemble_max_triggers"):
			_max_triggers = int(params["reassemble_max_triggers"])
		if params.has("reassemble_cancel_on_hit_during_window"):
			_cancel_on_hit = bool(params["reassemble_cancel_on_hit_during_window"])
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	match _state:
		State.NORMAL:
			super._physics_process(delta)
		State.DISASSEMBLED:
			_run_disassembled(delta)
	queue_redraw()


func _run_disassembled(delta: float) -> void:
	# 분해 동안: 이동 불가, 접촉 데미지 비활성.
	velocity = Vector2.ZERO
	move_and_slide()
	_reassemble_timer = maxf(0.0, _reassemble_timer - delta)
	if _reassemble_timer <= 0.0:
		_revive()


func take_damage(amount: int, attacker: Object = null) -> void:
	if is_dying:
		return
	if _state == State.DISASSEMBLED:
		# 분해 중 추가 피격 — 진짜 사망.
		if _cancel_on_hit:
			hp = 0
			_finalize_death()
		return
	# 일반 상태에서 피격 처리.
	if attacker != null:
		var aid: int = attacker.get_instance_id()
		var now: float = Time.get_ticks_msec() / 1000.0
		if _last_hit_by.has(aid) and (now - float(_last_hit_by[aid])) < REHIT_COOLDOWN:
			return
		_last_hit_by[aid] = now
	hp = max(0, hp - amount)
	if hp <= 0:
		_on_hp_zero()


func _on_hp_zero() -> void:
	# 이미 부활 가능 횟수를 소진했으면 즉시 사망.
	if _trigger_count >= _max_triggers:
		_finalize_death()
		return
	# 분해 상태 진입.
	_state = State.DISASSEMBLED
	_reassemble_timer = _reassemble_window
	_trigger_count += 1


func _revive() -> void:
	hp = maxi(1, int(round(float(max_hp) * _revive_hp_pct)))
	move_speed = move_speed * _post_speed_mult
	_state = State.NORMAL


func _finalize_death() -> void:
	die()


func _draw() -> void:
	var c: Color = data.placeholder_color if data != null else FALLBACK_COLOR
	if _state == State.DISASSEMBLED:
		# 분해 — 흩어진 뼛조각 표시.
		var bone: Color = Color(c.r, c.g, c.b, 0.7)
		draw_rect(Rect2(Vector2(-FALLBACK_W * 0.45, -FALLBACK_H * 0.1), Vector2(FALLBACK_W * 0.35, 3.0)), bone)
		draw_rect(Rect2(Vector2(FALLBACK_W * 0.10, -FALLBACK_H * 0.25), Vector2(FALLBACK_W * 0.35, 3.0)), bone)
		draw_rect(Rect2(Vector2(-FALLBACK_W * 0.20, FALLBACK_H * 0.15), Vector2(FALLBACK_W * 0.40, 3.0)), bone)
		draw_circle(Vector2(0.0, -FALLBACK_H * 0.30), 4.0, bone)
		# 부활 진행 인디케이터.
		var ratio: float = 1.0 - clamp(_reassemble_timer / maxf(0.001, _reassemble_window), 0.0, 1.0)
		draw_arc(Vector2.ZERO, 14.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 24, Color(0.95, 0.85, 0.4, 0.85), 1.5)
		return
	# 일반 상태 — 누런 해골 병사.
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.5), Vector2(FALLBACK_W, FALLBACK_H)), c)
	# 갑옷 잔해(가슴 회색 띠).
	draw_rect(Rect2(Vector2(-FALLBACK_W * 0.5, -FALLBACK_H * 0.1), Vector2(FALLBACK_W, FALLBACK_H * 0.18)), Color(0.45, 0.45, 0.50, 0.85))
	# 두 눈(검은 구멍).
	draw_circle(Vector2(-FALLBACK_W * 0.18, -FALLBACK_H * 0.28), 1.6, Color(0.05, 0.05, 0.05, 1.0))
	draw_circle(Vector2(FALLBACK_W * 0.18, -FALLBACK_H * 0.28), 1.6, Color(0.05, 0.05, 0.05, 1.0))
	# 부러진 창(오른쪽 비스듬한 회색 막대).
	draw_line(Vector2(FALLBACK_W * 0.35, FALLBACK_H * 0.05), Vector2(FALLBACK_W * 0.65, -FALLBACK_H * 0.45), Color(0.35, 0.30, 0.22, 1.0), 1.8)
	# 부활 후 강화 표시(약한 황색 외곽선).
	if _trigger_count > 0:
		draw_arc(Vector2.ZERO, FALLBACK_W * 0.55, 0.0, TAU, 24, Color(1.0, 0.9, 0.4, 0.45), 1.2)
