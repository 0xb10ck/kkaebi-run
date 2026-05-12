extends Node

signal enemy_died(world_pos: Vector2, enemy_data: EnemyData)

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/Enemy.tscn")
const MAX_ENEMIES: int = 120
const SPAWN_DISTANCE_MIN: float = 720.0
const SPAWN_DISTANCE_MAX: float = 820.0

const DATA_DOKKEBIBUL: EnemyData = preload("res://scripts/data/resources/enemies/dokkebibul.tres")
const DATA_DALGYALGWISIN: EnemyData = preload("res://scripts/data/resources/enemies/dalgyalgwisin.tres")
const DATA_MULGWISIN: EnemyData = preload("res://scripts/data/resources/enemies/mulgwisin.tres")

# 시간 구간별 스폰 레이트 (마리 / 초)
const SCHEDULE: Array = [
	{ "until": 30.0, "dok": 8.0 / 15.0, "dal_groups": 0.0, "mul": 0.0 },
	{ "until": 90.0, "dok": 12.0 / 15.0, "dal_groups": 1.0 / 20.0, "mul": 0.0 },
	{ "until": 150.0, "dok": 16.0 / 15.0, "dal_groups": 2.0 / 20.0, "mul": 1.0 / 30.0 },
	{ "until": 210.0, "dok": 24.0 / 15.0, "dal_groups": 3.0 / 20.0, "mul": 1.0 / 20.0 },
	{ "until": 270.0, "dok": 32.0 / 15.0, "dal_groups": 4.0 / 20.0, "mul": 2.0 / 20.0 },
	{ "until": 300.0, "dok": 40.0 / 10.0, "dal_groups": 6.0 / 15.0, "mul": 3.0 / 15.0 },
]

var container: Node = null
var player: Node2D = null
var active: bool = false

var _dok_acc: float = 0.0
var _dal_acc: float = 0.0
var _mul_acc: float = 0.0


func configure(container_node: Node, player_node: Node2D) -> void:
	container = container_node
	player = player_node


func start() -> void:
	_dok_acc = 0.0
	_dal_acc = 0.0
	_mul_acc = 0.0
	active = true


func stop() -> void:
	active = false


func _process(delta: float) -> void:
	if not active:
		return
	if container == null or player == null or not is_instance_valid(player):
		return
	if GameState.elapsed >= GameState.STAGE_DURATION:
		return
	var rates := _rates_at(GameState.elapsed)
	_dok_acc += rates["dok"] * delta
	_dal_acc += rates["dal_groups"] * delta
	_mul_acc += rates["mul"] * delta
	while _dok_acc >= 1.0:
		_dok_acc -= 1.0
		_spawn(DATA_DOKKEBIBUL)
	while _dal_acc >= 1.0:
		_dal_acc -= 1.0
		_spawn_group(DATA_DALGYALGWISIN, DATA_DALGYALGWISIN.group_size, DATA_DALGYALGWISIN.group_spacing_px)
	while _mul_acc >= 1.0:
		_mul_acc -= 1.0
		_spawn(DATA_MULGWISIN)


func _rates_at(t: float) -> Dictionary:
	for entry in SCHEDULE:
		if t < float(entry["until"]):
			return entry
	return SCHEDULE[SCHEDULE.size() - 1]


func _spawn(data: EnemyData) -> void:
	_ensure_capacity()
	var pos := _random_spawn_position()
	_spawn_at(data, pos)


func _spawn_group(data: EnemyData, count: int, spacing: float) -> void:
	_ensure_capacity(count)
	var center := _random_spawn_position()
	var perp := (center - player.global_position).rotated(PI * 0.5).normalized()
	var start_offset := -(float(count - 1) * spacing * 0.5)
	for i in range(count):
		var pos: Vector2 = center + perp * (start_offset + float(i) * spacing)
		_spawn_at(data, pos)


func _spawn_at(data: EnemyData, pos: Vector2) -> void:
	var mults := DifficultyCurve.multipliers(GameState.elapsed)
	var enemy: CharacterBody2D = ENEMY_SCENE.instantiate()
	enemy.global_position = pos
	enemy.setup(data, mults["hp"], mults["speed"], mults["damage"])
	enemy.died.connect(_on_enemy_died)
	container.add_child(enemy)


func _on_enemy_died(world_pos: Vector2, data: EnemyData) -> void:
	enemy_died.emit(world_pos, data)


func _random_spawn_position() -> Vector2:
	var angle := randf() * TAU
	var dist := randf_range(SPAWN_DISTANCE_MIN, SPAWN_DISTANCE_MAX)
	return player.global_position + Vector2(cos(angle), sin(angle)) * dist


func _ensure_capacity(needed: int = 1) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var to_kill := enemies.size() + needed - MAX_ENEMIES
	if to_kill <= 0:
		return
	# 가장 멀리 있는 개체부터 디스폰
	var by_distance := enemies.duplicate()
	by_distance.sort_custom(func(a, b):
		var da: float = a.global_position.distance_squared_to(player.global_position)
		var db: float = b.global_position.distance_squared_to(player.global_position)
		return da > db
	)
	for i in range(min(to_kill, by_distance.size())):
		var e: Node = by_distance[i]
		if is_instance_valid(e):
			e.queue_free()
