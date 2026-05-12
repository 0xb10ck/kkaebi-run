extends Node2D

const ENEMY_FIRE: PackedScene = preload("res://scenes/gameplay/enemy_fire.tscn")
const ENEMY_EGG: PackedScene = preload("res://scenes/gameplay/enemy_egg.tscn")
const ENEMY_WATER: PackedScene = preload("res://scenes/gameplay/enemy_water.tscn")

const STAGE_DURATION: float = 300.0
const SPAWN_INTERVAL_INITIAL: float = 2.0
const SPAWN_INTERVAL_MIN: float = 0.3
const SPAWN_INTERVAL_STEP: float = 0.2
const SPAWN_INTERVAL_PERIOD: float = 30.0

const SPAWN_RADIUS_MIN: float = 300.0
const SPAWN_RADIUS_MAX: float = 400.0

const EGG_FLOCK_MIN: int = 3
const EGG_FLOCK_MAX: int = 5
const EGG_FLOCK_SPREAD: float = 40.0

const COUNT_TIER1_AT: float = 100.0
const COUNT_TIER2_AT: float = 200.0

@onready var time_left: float = STAGE_DURATION
@onready var player: Node2D = $Player
@onready var enemy_container: Node2D = $EnemyContainer

var _spawn_timer: float = 0.0


func _process(delta: float) -> void:
	if time_left <= 0.0:
		return
	time_left = maxf(0.0, time_left - delta)
	if time_left <= 0.0:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_wave()
		_spawn_timer = _current_spawn_interval()


func _current_spawn_interval() -> float:
	var elapsed: float = STAGE_DURATION - time_left
	var step_count: int = int(elapsed / SPAWN_INTERVAL_PERIOD)
	var interval: float = SPAWN_INTERVAL_INITIAL - SPAWN_INTERVAL_STEP * float(step_count)
	return maxf(SPAWN_INTERVAL_MIN, interval)


func _current_spawn_count() -> int:
	var elapsed: float = STAGE_DURATION - time_left
	if elapsed < COUNT_TIER1_AT:
		return 1
	if elapsed < COUNT_TIER2_AT:
		return 2
	return 3


func _spawn_wave() -> void:
	var count: int = _current_spawn_count()
	for i in count:
		var pick: int = randi() % 3
		if pick == 0:
			_spawn_single(ENEMY_FIRE)
		elif pick == 1:
			_spawn_egg_flock()
		else:
			_spawn_single(ENEMY_WATER)


func _spawn_single(scene: PackedScene) -> void:
	var enemy: Node2D = scene.instantiate()
	enemy.global_position = _random_spawn_point()
	enemy_container.add_child(enemy)


func _spawn_egg_flock() -> void:
	var center: Vector2 = _random_spawn_point()
	var n: int = randi_range(EGG_FLOCK_MIN, EGG_FLOCK_MAX)
	for i in n:
		var offset: Vector2 = Vector2(
			randf_range(-EGG_FLOCK_SPREAD, EGG_FLOCK_SPREAD),
			randf_range(-EGG_FLOCK_SPREAD, EGG_FLOCK_SPREAD)
		)
		var enemy: Node2D = ENEMY_EGG.instantiate()
		enemy.global_position = center + offset
		enemy_container.add_child(enemy)


func _random_spawn_point() -> Vector2:
	if not is_instance_valid(player):
		return Vector2.ZERO
	var side: int = randi() % 4
	var base_angle: float
	match side:
		0:
			base_angle = -PI / 2.0
		1:
			base_angle = PI / 2.0
		2:
			base_angle = PI
		_:
			base_angle = 0.0
	var angle: float = base_angle + randf_range(-PI / 4.0, PI / 4.0)
	var radius: float = randf_range(SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX)
	return player.global_position + Vector2(cos(angle), sin(angle)) * radius
