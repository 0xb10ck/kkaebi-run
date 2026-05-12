extends Node

signal hp_changed(current: int, max_value: int)
signal xp_changed(current: int, required: int)
signal level_changed(new_level: int)
signal kill_count_changed(count: int)
signal gold_changed(amount: int)
signal time_milestone(seconds: int)
signal game_over(reason: StringName)

const STAGE_DURATION := 300.0

var max_hp: int = 100
var current_hp: int = 100

var elapsed: float = 0.0
var level: int = 1
var current_xp: int = 0
var kill_count: int = 0
var gold: int = 0

var bonus_max_hp: int = 0
var bonus_move_speed_mult: float = 1.0
var bonus_xp_gain_mult: float = 1.0

var _game_over_fired: bool = false


func reset() -> void:
	max_hp = 100 + bonus_max_hp
	current_hp = max_hp
	elapsed = 0.0
	level = 1
	current_xp = 0
	kill_count = 0
	gold = 0
	bonus_max_hp = 0
	bonus_move_speed_mult = 1.0
	bonus_xp_gain_mult = 1.0
	max_hp = 100
	current_hp = 100
	_game_over_fired = false
	hp_changed.emit(current_hp, max_hp)
	xp_changed.emit(current_xp, required_xp_for(level))
	level_changed.emit(level)
	kill_count_changed.emit(kill_count)
	gold_changed.emit(gold)


func required_xp_for(level_n: int) -> int:
	# Lv N -> Lv (N+1) 누적 EXP
	if level_n <= 0:
		return 5
	if level_n == 1:
		return 5
	if level_n == 2:
		return 8
	if level_n == 3:
		return 12
	if level_n == 4:
		return 16
	return 16 + (level_n - 4) * 6


func add_xp(value: int) -> void:
	if _game_over_fired:
		return
	var actual := int(round(value * bonus_xp_gain_mult))
	if actual <= 0:
		actual = 1
	current_xp += actual
	var leveled_up := false
	while current_xp >= required_xp_for(level):
		current_xp -= required_xp_for(level)
		level += 1
		leveled_up = true
		level_changed.emit(level)
	xp_changed.emit(current_xp, required_xp_for(level))
	if leveled_up:
		# 카운트가 동기화되도록 마지막에 한 번 더 emit (HUD 안전망)
		pass


func deal_damage_to_player(amount: int) -> void:
	if _game_over_fired:
		return
	current_hp = max(0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		_game_over_fired = true
		game_over.emit(&"death")


func register_kill() -> void:
	kill_count += 1
	kill_count_changed.emit(kill_count)


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func apply_bonus_max_hp(delta_amount: int) -> void:
	bonus_max_hp += delta_amount
	max_hp += delta_amount
	current_hp = min(max_hp, current_hp + delta_amount)
	hp_changed.emit(current_hp, max_hp)


func apply_bonus_move_speed(mult_delta: float) -> void:
	bonus_move_speed_mult *= (1.0 + mult_delta)


func apply_bonus_xp_gain(mult_delta: float) -> void:
	bonus_xp_gain_mult *= (1.0 + mult_delta)


func trigger_clear() -> void:
	if _game_over_fired:
		return
	_game_over_fired = true
	game_over.emit(&"clear")


func tick_time(delta: float) -> void:
	if _game_over_fired:
		return
	var prev_sec := int(elapsed)
	elapsed += delta
	var sec := int(elapsed)
	if sec != prev_sec:
		time_milestone.emit(sec)
		if sec >= int(STAGE_DURATION):
			trigger_clear()
