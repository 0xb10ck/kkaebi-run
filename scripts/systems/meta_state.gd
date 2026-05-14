extends Node

# §2.4 — 영속 메타 상태. 모든 변경은 save_requested로 SaveStore에 위임.
# 자동로드 — 4번째.

# === 재화 ===
var dokkaebi_orbs: int = 0
var shinmok_leaves: int = 0
var myth_shards: int = 0

# === 신목 ===
var shinmok_stage: int = 1

# === 영구 강화 (key -> level 0..5) ===
var upgrades: Dictionary = {}

# === 캐릭터 ===
var unlocked_characters: Array[StringName] = [&"ttukttaki"]
var character_affinity: Dictionary = {}
var character_affinity_nodes: Dictionary = {}

# === 도감 ===
var codex_monsters: Dictionary = {}
var codex_relics: Dictionary = {}
var codex_places: Dictionary = {}

# === 도전 과제 ===
var achievements: Dictionary = {}
var daily_seed_day: int = -1
var daily_active: Array[StringName] = []
var daily_progress: Dictionary = {}
var weekly_seed_week: int = -1
var weekly_active: Array[StringName] = []
var weekly_progress: Dictionary = {}

# === 통계 ===
var stats: Dictionary = {
	"total_kills": 0, "total_bosses_defeated": 0, "total_runs": 0,
	"total_clears": 0, "total_deaths": 0, "total_gold_earned": 0,
	"play_time_seconds": 0.0,
}

# === 세이브 ===
var save_version: int = 2
var last_save_at_unix: int = 0

# === 강화 정의 레지스트리 (key -> MetaUpgradeData) ===
# 풀스펙 .tres가 들어오면 채워진다. 비어 있어도 §3.7.1의 기본값을 코드 폴백으로 사용.
var _upgrade_defs: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_upgrade_defaults()
	_load_from_disk()
	EventBus.save_requested.connect(_on_save_requested)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.chapter_cleared.connect(_on_chapter_cleared)
	EventBus.character_unlocked.connect(_on_character_unlocked_external)


# === public API ===

func get_upgrade_level(key: StringName) -> int:
	return int(upgrades.get(key, 0))


func get_upgrade_effect(key: StringName) -> float:
	var lv: int = get_upgrade_level(key)
	if lv <= 0:
		return 0.0
	if _upgrade_defs.has(key):
		var def: MetaUpgradeData = _upgrade_defs[key]
		return def.effect_at(lv)
	# 폴백: §3.7.1 표
	var table: Array = _fallback_effects(key)
	if table.is_empty():
		return 0.0
	var idx: int = clamp(lv - 1, 0, table.size() - 1)
	return float(table[idx])


func get_upgrade_max_level(key: StringName) -> int:
	if _upgrade_defs.has(key):
		return (_upgrade_defs[key] as MetaUpgradeData).max_level
	return 5


func get_upgrade_cost(key: StringName, next_level: int) -> int:
	if _upgrade_defs.has(key):
		return (_upgrade_defs[key] as MetaUpgradeData).cost_for(next_level)
	var table: Array = _fallback_costs(key)
	if table.is_empty():
		return 0
	var idx: int = clamp(next_level - 1, 0, table.size() - 1)
	return int(table[idx])


func apply_upgrade_purchase(key: StringName) -> bool:
	var lv: int = get_upgrade_level(key)
	var max_lv: int = get_upgrade_max_level(key)
	if lv >= max_lv:
		return false
	var required_shinmok: int = 1
	if _upgrade_defs.has(key):
		required_shinmok = (_upgrade_defs[key] as MetaUpgradeData).requires_shinmok_stage
	if shinmok_stage < required_shinmok:
		return false
	var cost: int = get_upgrade_cost(key, lv + 1)
	if dokkaebi_orbs < cost:
		return false
	dokkaebi_orbs -= cost
	upgrades[key] = lv + 1
	EventBus.meta_changed.emit(key, lv + 1)
	EventBus.meta_currency_changed.emit(&"dokkaebi_orbs", dokkaebi_orbs)
	EventBus.save_requested.emit(&"autosave")
	return true


func can_unlock_character(id: StringName) -> bool:
	if unlocked_characters.has(id):
		return false
	# 비용/조건 검사는 풀 데이터 도입 후 _upgrade_defs/CharacterRegistry에서 처리.
	return true


func unlock_character(id: StringName) -> bool:
	if unlocked_characters.has(id):
		return false
	unlocked_characters.append(id)
	if not character_affinity.has(id):
		character_affinity[id] = 0
	if not character_affinity_nodes.has(id):
		character_affinity_nodes[id] = []
	EventBus.character_unlocked.emit(id)
	EventBus.save_requested.emit(&"autosave")
	return true


func add_affinity(char_id: StringName, amount: int) -> void:
	if amount == 0:
		return
	var cur: int = int(character_affinity.get(char_id, 0))
	character_affinity[char_id] = max(0, cur + amount)


func record_kill(enemy_id: StringName) -> void:
	stats["total_kills"] = int(stats.get("total_kills", 0)) + 1
	var entry: Dictionary = codex_monsters.get(enemy_id, {"discovered": false, "killed_count": 0, "first_seen_at": 0})
	if not bool(entry.get("discovered", false)):
		entry["discovered"] = true
		entry["first_seen_at"] = int(Time.get_unix_time_from_system())
		EventBus.codex_entry_unlocked.emit(&"monsters", enemy_id)
	entry["killed_count"] = int(entry.get("killed_count", 0)) + 1
	codex_monsters[enemy_id] = entry


func record_boss_defeated(boss_id: StringName, time_taken: float, no_hit: bool) -> int:
	stats["total_bosses_defeated"] = int(stats.get("total_bosses_defeated", 0)) + 1
	var entry: Dictionary = codex_monsters.get(boss_id, {"discovered": false, "killed_count": 0, "first_seen_at": 0})
	var is_first: bool = not bool(entry.get("discovered", false))
	if is_first:
		entry["discovered"] = true
		entry["first_seen_at"] = int(Time.get_unix_time_from_system())
		EventBus.codex_entry_unlocked.emit(&"monsters", boss_id)
	entry["killed_count"] = int(entry.get("killed_count", 0)) + 1
	codex_monsters[boss_id] = entry
	var earned: int = 50 if is_first else 5
	dokkaebi_orbs += earned
	if no_hit and time_taken > 0.0:
		# 무피격 보너스 — 풀스펙 §1.2.3 공식 자리 표시.
		earned += 10
		dokkaebi_orbs += 10
	EventBus.meta_currency_changed.emit(&"dokkaebi_orbs", dokkaebi_orbs)
	return earned


func advance_shinmok() -> bool:
	# 풀 데이터 도입 시 ShinmokStageData[stage]에서 비용을 읽어 처리.
	# 본 스텁은 마지막 단계 가드만.
	if shinmok_stage >= 6:
		return false
	shinmok_stage += 1
	EventBus.shinmok_advanced.emit(shinmok_stage)
	EventBus.save_requested.emit(&"autosave")
	return true


func compute_run_settlement(stats_in: Dictionary) -> Dictionary:
	# §1.2.3 — 생존 시간 / 처치 수 / 도달 레벨 / 챕터 진행도 기반 도깨비 구슬 정산.
	# 항목별 기여를 분리해 디버깅과 차후 튜닝을 쉽게 한다.
	var kills: int = int(stats_in.get("kills", 0))
	var survive_sec: int = int(stats_in.get("survive_sec", 0))
	var level: int = int(stats_in.get("level", 1))
	var chapter_number: int = int(stats_in.get("chapter_number", 1))
	var clear_bonus: int = int(stats_in.get("clear_bonus_orbs", 0))

	# 가중치는 풀스펙 §1.2.3 자리. 임시 폴백 값:
	#  - 처치 1회 = 0.5 구슬
	#  - 생존 1초 = 0.1 구슬
	#  - 레벨 1당 = 4 구슬
	#  - 챕터 번호당 = 10 구슬 (도달 깊이 보상)
	var from_kills: int = int(round(kills * 0.5))
	var from_time: int = int(round(survive_sec * 0.1))
	var from_level: int = max(0, (level - 1) * 4)
	var from_chapter: int = max(0, (chapter_number - 1) * 10)
	var orbs: int = from_kills + from_time + from_level + from_chapter + max(0, clear_bonus)
	add_dokkaebi_orbs(orbs)
	return {
		"orbs": orbs,
		"from_kills": from_kills,
		"from_time": from_time,
		"from_level": from_level,
		"from_chapter": from_chapter,
		"from_clear_bonus": clear_bonus,
	}


func add_dokkaebi_orbs(amount: int) -> void:
	# 외부에서 직접 구슬을 부여할 때 사용. 음수는 무시.
	if amount <= 0:
		return
	dokkaebi_orbs += amount
	EventBus.meta_currency_changed.emit(&"dokkaebi_orbs", dokkaebi_orbs)
	EventBus.save_requested.emit(&"autosave")


func update_daily_challenges(today_unix: int) -> void:
	var today_day: int = today_unix / 86400
	if today_day == daily_seed_day:
		return
	daily_seed_day = today_day
	daily_active = []
	daily_progress = {}


func update_weekly_challenges(today_unix: int) -> void:
	var week: int = today_unix / (86400 * 7)
	if week == weekly_seed_week:
		return
	weekly_seed_week = week
	weekly_active = []
	weekly_progress = {}


func report_challenge_progress(challenge_id: StringName, delta: int) -> void:
	if daily_active.has(challenge_id):
		var p: int = int(daily_progress.get(challenge_id, 0)) + delta
		daily_progress[challenge_id] = p
		EventBus.daily_challenge_progress.emit(challenge_id, p, 0)
	if weekly_active.has(challenge_id):
		var w: int = int(weekly_progress.get(challenge_id, 0)) + delta
		weekly_progress[challenge_id] = w


func is_codex_complete_for(category: StringName) -> bool:
	# 풀 데이터 도입 후 카테고리별 토탈과 비교. 본 스텁은 false.
	return false


func register_upgrade_def(def: MetaUpgradeData) -> void:
	# §3.7 .tres가 로드되면 호출. 코드 폴백을 덮어쓴다.
	_upgrade_defs[def.key] = def


# === 직렬화 ===

func snapshot_for_save() -> Dictionary:
	return {
		"version": save_version,
		"saved_at": int(Time.get_unix_time_from_system()),
		"currency": {
			"dokkaebi_orbs": dokkaebi_orbs,
			"shinmok_leaves": shinmok_leaves,
			"myth_shards": myth_shards,
		},
		"shinmok": {"stage": shinmok_stage},
		"upgrades": upgrades.duplicate(true),
		"characters": {
			"unlocked": _array_to_strings(unlocked_characters),
			"affinity": character_affinity.duplicate(true),
			"affinity_nodes": character_affinity_nodes.duplicate(true),
		},
		"codex": {
			"monsters": codex_monsters.duplicate(true),
			"relics": codex_relics.duplicate(true),
			"places": codex_places.duplicate(true),
		},
		"achievements": achievements.duplicate(true),
		"challenges": {
			"daily_seed_day": daily_seed_day,
			"daily_active": _array_to_strings(daily_active),
			"daily_progress": daily_progress.duplicate(true),
			"weekly_seed_week": weekly_seed_week,
			"weekly_active": _array_to_strings(weekly_active),
			"weekly_progress": weekly_progress.duplicate(true),
		},
		"stats": stats.duplicate(true),
	}


func restore_from_save(m: Dictionary) -> void:
	if m.is_empty():
		return
	var cur: Dictionary = m.get("currency", {})
	dokkaebi_orbs = int(cur.get("dokkaebi_orbs", 0))
	shinmok_leaves = int(cur.get("shinmok_leaves", 0))
	myth_shards = int(cur.get("myth_shards", 0))
	shinmok_stage = int(m.get("shinmok", {"stage": 1}).get("stage", 1))
	var ups: Dictionary = m.get("upgrades", {})
	upgrades = {}
	for k in Ids.ALL_UPGRADE_KEYS:
		upgrades[k] = int(ups.get(String(k), 0))
	var chars: Dictionary = m.get("characters", {})
	unlocked_characters = _strings_to_stringnames(chars.get("unlocked", ["ttukttaki"]))
	character_affinity = chars.get("affinity", {"ttukttaki": 0}).duplicate(true)
	character_affinity_nodes = chars.get("affinity_nodes", {"ttukttaki": []}).duplicate(true)
	var cdx: Dictionary = m.get("codex", {})
	codex_monsters = cdx.get("monsters", {}).duplicate(true)
	codex_relics = cdx.get("relics", {}).duplicate(true)
	codex_places = cdx.get("places", {}).duplicate(true)
	achievements = m.get("achievements", {}).duplicate(true)
	var ch: Dictionary = m.get("challenges", {})
	daily_seed_day = int(ch.get("daily_seed_day", -1))
	daily_active = _strings_to_stringnames(ch.get("daily_active", []))
	daily_progress = ch.get("daily_progress", {}).duplicate(true)
	weekly_seed_week = int(ch.get("weekly_seed_week", -1))
	weekly_active = _strings_to_stringnames(ch.get("weekly_active", []))
	weekly_progress = ch.get("weekly_progress", {}).duplicate(true)
	stats = m.get("stats", stats).duplicate(true)


# === 공개 세이브/로드 API (§5) ===

func save() -> bool:
	# user://save.json 직렬화. EventBus.save_completed가 결과를 통보.
	_on_save_requested(&"explicit")
	return true


func load() -> void:
	# user://save.json 역직렬화. SaveStore가 버전 마이그레이션 수행.
	_load_from_disk()


# === 메타 화면용 공개 API (§2.4) ===
# UI 코드가 부르는 표면 명칭에 맞춘 얇은 wrapper. 내부 로직은 그대로 유지.

# shinmok_level 별칭 (외부에서 stage가 아닌 level로 표기).
var shinmok_level: int:
	get:
		return shinmok_stage


func purchase_upgrade(key: StringName) -> bool:
	return apply_upgrade_purchase(key)


# 신목 다음 단계 헌납 비용. 폴백 표 — ShinmokStageData .tres 도입 시 대체.
func get_next_shinmok_cost() -> int:
	if shinmok_stage >= 6:
		return 0
	var table: Array[int] = [0, 100, 250, 600, 1200, 2400]
	var idx: int = clamp(shinmok_stage, 0, table.size() - 1)
	return table[idx]


# 신목 헌납 — 다음 단계 비용을 도깨비 구슬로 지불하고 단계 진행.
func donate_to_shinmok() -> bool:
	if shinmok_stage >= 6:
		return false
	var cost: int = get_next_shinmok_cost()
	if dokkaebi_orbs < cost:
		return false
	dokkaebi_orbs -= cost
	EventBus.meta_currency_changed.emit(&"dokkaebi_orbs", dokkaebi_orbs)
	return advance_shinmok()


# 도전과제 보상 수령 — claimed=true로 표시하고 보상 통화 지급.
# achievements 엔트리 스키마: {progress, target, reward_orbs, claimed}
func claim_achievement(achievement_id: StringName) -> bool:
	var entry: Dictionary = achievements.get(achievement_id, {})
	if entry.is_empty():
		return false
	if bool(entry.get("claimed", false)):
		return false
	var progress: int = int(entry.get("progress", 0))
	var target: int = int(entry.get("target", 0))
	if progress < target:
		return false
	var reward: int = int(entry.get("reward_orbs", 0))
	entry["claimed"] = true
	achievements[achievement_id] = entry
	if reward > 0:
		add_dokkaebi_orbs(reward)
	EventBus.achievement_unlocked.emit(achievement_id)
	EventBus.save_requested.emit(&"autosave")
	return true


# 도감 잠금 해제 여부 — 카테고리 ∈ &"monsters" | &"relics" | &"places"
func is_codex_entry_unlocked(category: StringName, entry_id: StringName) -> bool:
	var dict: Dictionary = codex_monsters
	match category:
		&"monsters": dict = codex_monsters
		&"relics":   dict = codex_relics
		&"places":   dict = codex_places
	var e: Dictionary = dict.get(entry_id, {})
	return bool(e.get("discovered", false)) or bool(e.get("visited", false))


# === 내부 ===

func _load_from_disk() -> void:
	var data: Dictionary = SaveStore.load_data()
	last_save_at_unix = int(data.get("saved_at", 0))
	var m: Dictionary = data.get("meta", {})
	restore_from_save(m)


func _on_save_requested(_reason: StringName) -> void:
	var full: Dictionary = SaveStore.default_data()
	full["version"] = save_version
	full["saved_at"] = int(Time.get_unix_time_from_system())
	full["meta"] = snapshot_for_save()
	# settings는 OptionsState 도입 후 채운다. 지금은 default 보존.
	var ok: bool = SaveStore.save_data(full)
	last_save_at_unix = int(full["saved_at"])
	EventBus.save_completed.emit(ok)


func _on_enemy_killed(enemy_id: StringName, _pos: Vector2, _by_skill: StringName) -> void:
	record_kill(enemy_id)


func _on_boss_defeated(boss_id: StringName, time_taken: float, no_hit: bool) -> void:
	record_boss_defeated(boss_id, time_taken, no_hit)
	EventBus.save_requested.emit(&"autosave")


func _on_chapter_cleared(chapter_id: StringName, first_clear: bool) -> void:
	var entry: Dictionary = codex_places.get(chapter_id, {"visited": false, "cleared": false, "first_at": 0})
	entry["visited"] = true
	if first_clear or not bool(entry.get("cleared", false)):
		entry["cleared"] = true
		entry["first_at"] = int(Time.get_unix_time_from_system())
	codex_places[chapter_id] = entry
	if first_clear:
		stats["total_clears"] = int(stats.get("total_clears", 0)) + 1
	EventBus.save_requested.emit(&"autosave")


func _on_character_unlocked_external(_id: StringName) -> void:
	# unlock_character() 내부에서 이미 발신했으므로 외부 트리거만 처리.
	pass


func _init_upgrade_defaults() -> void:
	for k in Ids.ALL_UPGRADE_KEYS:
		if not upgrades.has(k):
			upgrades[k] = 0


# §3.7.1 폴백 표 — .tres 도입 전 동작 보장.
func _fallback_effects(key: StringName) -> Array:
	match key:
		&"max_hp":      return [0.05, 0.10, 0.18, 0.28, 0.40]
		&"attack":      return [0.04, 0.08, 0.14, 0.22, 0.32]
		&"move_speed":  return [0.03, 0.06, 0.10, 0.15, 0.20]
		&"xp_gain":     return [0.05, 0.10, 0.18, 0.28, 0.40]
		&"gold_gain":   return [0.08, 0.16, 0.28, 0.44, 0.65]
		&"revive":      return [1.0, 2.0, 2.0, 3.0, 3.0]
		&"choice_extra":return [0.05, 0.10, 0.18, 0.28, 0.40]
		&"luck":        return [0.02, 0.04, 0.07, 0.11, 0.16]
	return []


func _fallback_costs(key: StringName) -> Array:
	match key:
		&"max_hp":      return [30, 60, 120, 240, 480]
		&"attack":      return [40, 80, 160, 320, 640]
		&"move_speed":  return [35, 70, 140, 280, 560]
		&"xp_gain":     return [30, 60, 120, 240, 480]
		&"gold_gain":   return [25, 50, 100, 200, 400]
		&"revive":      return [100, 250, 500, 1000, 2000]
		&"choice_extra":return [60, 120, 240, 480, 960]
		&"luck":        return [50, 100, 200, 400, 800]
	return []


func _array_to_strings(arr: Variant) -> Array:
	var out: Array = []
	if arr is Array:
		for v in arr:
			out.append(String(v))
	return out


func _strings_to_stringnames(arr: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if arr is Array:
		for v in arr:
			out.append(StringName(String(v)))
	return out
