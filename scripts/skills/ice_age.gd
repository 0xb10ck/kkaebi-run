class_name IceAge
extends SkillBase


const TINT_COLOR: Color = Color(0.50, 0.85, 1.0, 0.12)
const TINT_RECT_SIZE: float = 4096.0
const TINT_DURATION: float = 0.5


const BASE_DAMAGE_BY_LEVEL: Array = [40, 60, 85, 115, 150]
const FREEZE_DURATION_BY_LEVEL: Array = [2.0, 2.5, 3.0, 3.5, 4.0]
const COOLDOWN_BY_LEVEL: Array = [75.0, 65.0, 55.0, 45.0, 35.0]


var _tint_time_left: float = 0.0


func _ready() -> void:
	cooldown = COOLDOWN_BY_LEVEL[0]
	super._ready()


func set_level(new_level: int) -> void:
	super.set_level(new_level)
	var idx: int = clamp(level - 1, 0, COOLDOWN_BY_LEVEL.size() - 1)
	base_cooldown = COOLDOWN_BY_LEVEL[idx]
	cooldown = base_cooldown


func _current_damage() -> int:
	var idx: int = clamp(level - 1, 0, BASE_DAMAGE_BY_LEVEL.size() - 1)
	return int(round(float(BASE_DAMAGE_BY_LEVEL[idx]) * damage_multiplier))


func _current_freeze_duration() -> float:
	var idx: int = clamp(level - 1, 0, FREEZE_DURATION_BY_LEVEL.size() - 1)
	return float(FREEZE_DURATION_BY_LEVEL[idx])


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _tint_time_left > 0.0:
		_tint_time_left -= delta
		queue_redraw()


func _cast() -> void:
	var freeze_duration: float = _current_freeze_duration()
	var dmg: int = _current_damage()
	var frozen: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		if e.has_method("apply_stun"):
			e.apply_stun(freeze_duration)
		elif e.has_method("apply_slow"):
			e.apply_slow(0.05, freeze_duration)
		frozen.append(e)
	_tint_time_left = TINT_DURATION
	queue_redraw()
	_schedule_unfreeze(frozen, freeze_duration, dmg)


func _schedule_unfreeze(targets: Array, after_seconds: float, dmg: int) -> void:
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = max(0.05, after_seconds)
	add_child(timer)
	timer.timeout.connect(func() -> void:
		for e in targets:
			if not is_instance_valid(e):
				continue
			if e.has_method("take_damage"):
				e.take_damage(dmg)
			if has_signal("hit_enemy"):
				emit_signal("hit_enemy", e, dmg)
		timer.queue_free()
	)
	timer.start()


func _draw() -> void:
	if _tint_time_left <= 0.0:
		return
	var half: float = TINT_RECT_SIZE * 0.5
	draw_rect(Rect2(-half, -half, TINT_RECT_SIZE, TINT_RECT_SIZE), TINT_COLOR)
