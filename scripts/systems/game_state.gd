extends Node

# §2.2 — 런 단위 휘발 상태. EventBus.run_started에서 reset_for_run().
# 자동로드 — 2번째. 다른 자동로드 직접 호출 금지(EventBus 경유).

# === 캐릭터/런 컨텍스트 ===
var character_id: StringName = &""
var character_data: CharacterData
var chapter_id: StringName = &""
var chapter_data: ChapterData
var stage_index: int = 0
var run_seed: int = 0

# 메인 메뉴에서 사용자가 고른 캐릭터 ID — 런이 시작되기 전까지 보존된다.
var selected_character_id: StringName = &""

# === 플레이어 스탯 (메타+캐릭터+런보너스 합산) ===
var max_hp: int = 100
var current_hp: int = 100
var move_speed: float = 100.0
var attack: int = 10
var attack_speed: float = 1.0
var pickup_radius: float = 60.0
var luck_percent: float = 0.0
var crit_percent: float = 5.0
var cdr_percent: float = 0.0
var intelligence: int = 10

# 보너스 배율 (메타 강화 적용 후)
var bonus_xp_gain_mult: float = 1.0
var bonus_gold_gain_mult: float = 1.0
var choice_extra_chance: float = 0.0

# === 진행 ===
var elapsed_run: float = 0.0
var elapsed_stage: float = 0.0
var level: int = 1
var current_xp: int = 0
var kill_count: int = 0
var gold: int = 0

# === 영구 보너스 / 일시 상태 ===
var meta_bonus: Dictionary = {}
var revives_remaining: int = 0
var invuln_until: float = 0.0
var slow_until: float = 0.0
var slow_factor: float = 1.0
var no_hit_run: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.run_started.connect(_on_run_started)
	EventBus.player_damaged.connect(_on_player_damaged_log)
	EventBus.xp_collected.connect(_on_xp_collected)
	EventBus.gold_collected.connect(_on_gold_collected)


# === 외부 API ===

func reset_for_run(char_id: StringName, ch_id: StringName) -> void:
	character_id = char_id
	chapter_id = ch_id
	stage_index = 0
	elapsed_run = 0.0
	elapsed_stage = 0.0
	level = 1
	current_xp = 0
	kill_count = 0
	gold = 0
	no_hit_run = true
	# 기본 스탯 (캐릭터/메타 미적용 fallback)
	max_hp = 100
	current_hp = max_hp
	move_speed = 100.0
	attack = 10
	attack_speed = 1.0
	pickup_radius = 60.0
	luck_percent = 0.0
	crit_percent = 5.0
	cdr_percent = 0.0
	intelligence = 10
	bonus_xp_gain_mult = 1.0
	bonus_gold_gain_mult = 1.0
	choice_extra_chance = 0.0
	if character_data:
		_apply_character_base(character_data)
	apply_meta_bonuses()


func apply_meta_bonuses() -> void:
	# §6.3 — 8 영구 강화의 효과를 한 번에 적용. 1) 비율형은 (1+effect) 곱.
	# 2) "count"는 정수 캐스팅. 3) "additive_flat"은 그대로 더함.
	meta_bonus.clear()
	# 비율형
	for key in [&"max_hp", &"attack", &"move_speed", &"xp_gain", &"gold_gain"]:
		var lv: int = MetaState.get_upgrade_level(key)
		if lv <= 0:
			continue
		var mult: float = MetaState.get_upgrade_effect(key)
		meta_bonus[key] = mult
		match key:
			&"max_hp":
				max_hp = int(round(float(max_hp) * (1.0 + mult)))
			&"attack":
				attack = int(round(float(attack) * (1.0 + mult)))
			&"move_speed":
				move_speed *= (1.0 + mult)
			&"xp_gain":
				bonus_xp_gain_mult *= (1.0 + mult)
			&"gold_gain":
				bonus_gold_gain_mult *= (1.0 + mult)
	# %p 가산형
	var luck_lv: int = MetaState.get_upgrade_level(&"luck")
	if luck_lv > 0:
		luck_percent += MetaState.get_upgrade_effect(&"luck") * 100.0
		meta_bonus[&"luck"] = luck_percent
	# 카운트형
	var revive_lv: int = MetaState.get_upgrade_level(&"revive")
	revives_remaining = int(MetaState.get_upgrade_effect(&"revive")) if revive_lv > 0 else 0
	var choice_lv: int = MetaState.get_upgrade_level(&"choice_extra")
	choice_extra_chance = MetaState.get_upgrade_effect(&"choice_extra") if choice_lv > 0 else 0.0
	current_hp = max_hp


func add_xp(value: int) -> void:
	var adjusted: int = int(round(float(max(1, value)) * bonus_xp_gain_mult))
	current_xp += adjusted
	var leveled_up: bool = false
	while current_xp >= required_xp_for(level):
		current_xp -= required_xp_for(level)
		level += 1
		leveled_up = true
	if leveled_up:
		EventBus.level_changed.emit(level)


func required_xp_for(lv: int) -> int:
	# §2.2 — 곡선: round(8 * lv ^ 1.55)
	return int(round(8.0 * pow(float(lv), 1.55)))


func deal_damage_to_player(amount: int, source: StringName) -> int:
	if Time.get_unix_time_from_system() < invuln_until:
		return 0
	current_hp = max(0, current_hp - amount)
	no_hit_run = false
	EventBus.player_damaged.emit(amount, source)
	if current_hp <= 0:
		if revives_remaining > 0:
			revives_remaining -= 1
			current_hp = max_hp
			EventBus.player_revived.emit(&"meta_revive")
		else:
			EventBus.player_died.emit()
	return amount


func heal_player(amount: int, source: StringName) -> void:
	if amount <= 0 or current_hp <= 0:
		return
	current_hp = min(max_hp, current_hp + amount)
	EventBus.player_healed.emit(amount, source)


func register_kill(enemy_id: StringName, pos: Vector2, by_skill: StringName) -> void:
	kill_count += 1
	EventBus.enemy_killed.emit(enemy_id, pos, by_skill)


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	var adjusted: int = int(round(float(amount) * bonus_gold_gain_mult))
	gold += adjusted
	EventBus.gold_collected.emit(adjusted)


func consume_revive() -> bool:
	if revives_remaining <= 0:
		return false
	revives_remaining -= 1
	current_hp = max_hp
	EventBus.player_revived.emit(&"meta_revive")
	return true


func snapshot_for_save() -> Dictionary:
	# 휘발 상태는 저장하지 않는다. 누적 통계는 MetaState로 발신.
	return {}


# === 내부 ===

func _apply_character_base(d: CharacterData) -> void:
	max_hp = d.base_hp
	current_hp = d.base_hp
	move_speed = d.base_move_speed
	attack = d.base_attack
	attack_speed = d.base_attack_speed
	pickup_radius = d.base_pickup_radius
	luck_percent = d.base_luck
	crit_percent = d.base_crit
	cdr_percent = d.base_cdr
	intelligence = d.base_intelligence


func _on_run_started(char_id: StringName, ch_id: StringName) -> void:
	# ChapterManager가 reset_for_run을 호출하지 않은 경우의 보호.
	if character_id != char_id or chapter_id != ch_id:
		reset_for_run(char_id, ch_id)


func _on_player_damaged_log(_amount: int, _source: StringName) -> void:
	pass


func _on_xp_collected(value: int) -> void:
	add_xp(value)


func _on_gold_collected(_amount: int) -> void:
	# add_gold가 발신하므로 이 hook은 외부 collector 전용. 이중 카운트 방지.
	pass
