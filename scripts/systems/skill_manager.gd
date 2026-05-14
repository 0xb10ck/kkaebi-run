extends Node

# §2.3 — 스킬 풀 + 보유 + 레벨링 + 진화. 자동로드 — 3번째.
# MVP 호환: 옛 get_offer() / acquire(skill_id, player) 시그니처를 유지.
# 풀스펙: SkillData.tres 기반 draw_three_cards / acquire_or_level / 진화 검사.

const MAX_SKILL_LEVEL: int = 5
const MAX_OWNED: int = 8
const OFFER_SIZE: int = 3

# MVP 하드코딩 풀 — SkillData.tres가 등록되기 전 폴백.
const _MVP_SKILL_DEFS: Dictionary = {
	"fire_orb": {
		"name": "도깨비불",
		"color": "#E03C3C",
		"desc": "주변을 회전하는 불꽃 3개",
		"scene_path": "res://scenes/skills/fire_orb.tscn",
	},
	"frost_ring": {
		"name": "서리 고리",
		"color": "#3C7CE0",
		"desc": "주변 적의 이속을 30% 감소시킵니다",
		"scene_path": "res://scenes/skills/frost_ring.tscn",
	},
	"vine_whip": {
		"name": "덩굴 채찍",
		"color": "#4CAF50",
		"desc": "가장 가까운 적을 직선 타격합니다",
		"scene_path": "res://scenes/skills/vine_whip.tscn",
	},
	"gold_shield": {
		"name": "금빛 방패",
		"color": "#F0EDE6",
		"desc": "1회 피격을 완전히 막아주는 보호막. 소진 후 5초 뒤 재생성됩니다.",
		"scene_path": "res://scenes/skills/gold_shield.tscn",
	},
	"rock_throw": {
		"name": "바위 투척",
		"color": "#E0C23C",
		"desc": "가장 먼 적에게 발사, 스턴 0.5초",
		"scene_path": "res://scenes/skills/rock_throw.tscn",
	},
}

const _MVP_BONUS_DEFS: Dictionary = {
	"bonus_max_hp": {
		"name": "최대 HP +20",
		"color": "#E07A3C",
		"desc": "최대 체력이 20 증가하고 즉시 회복됩니다.",
	},
	"bonus_speed": {
		"name": "이동 속도 +5%",
		"color": "#7AC4FF",
		"desc": "이동 속도가 영구적으로 5% 증가합니다.",
	},
	"bonus_exp_gain": {
		"name": "경험치 획득량 +10%",
		"color": "#B8E03C",
		"desc": "경험치 보석에서 얻는 경험치가 영구적으로 10% 증가합니다.",
	},
}

# 풀스펙 레지스트리 (.tres 도입 후 채움)
var skill_db: Dictionary = {}       # StringName -> SkillData
var evolution_db: Dictionary = {}   # StringName -> EvolutionData

# 보유 — MVP에서는 {id: {scene, instance, level}}, 풀스펙은 {id: level}
# 두 패턴 모두를 owned 사전 안에서 다룬다 (entry 형식으로 판별).
var owned: Dictionary = {}

# 풀스펙 한 런 동안 등장한 전설 스킬 수 (R0.3 한 런 최대 2종)
var legendary_acquired_this_run: int = 0

# 현재 활성 캐릭터 (가중치 계산용)
var _active_character: CharacterData


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.run_started.connect(_on_run_started)


func register_skill(data: SkillData) -> void:
	if data == null:
		return
	skill_db[data.id] = data


func register_evolution(data: EvolutionData) -> void:
	if data == null:
		return
	evolution_db[data.id] = data


func reset_for_run(char_data: CharacterData) -> void:
	owned.clear()
	legendary_acquired_this_run = 0
	_active_character = char_data


# === MVP 호환 API ===

func get_offer() -> Array:
	var unowned_ids: Array = []
	for id in _MVP_SKILL_DEFS.keys():
		if not owned.has(id):
			unowned_ids.append(id)
	unowned_ids.shuffle()
	var skill_pick_count: int = min(unowned_ids.size(), OFFER_SIZE)
	var skill_picks: Array = unowned_ids.slice(0, skill_pick_count)
	var bonus_slots: int = OFFER_SIZE - skill_pick_count
	var offers: Array = []
	for id in skill_picks:
		var def: Dictionary = _MVP_SKILL_DEFS[id]
		offers.append({
			"type": "skill",
			"id": id,
			"name": def["name"],
			"color": def["color"],
			"desc": def["desc"],
			"owned": false,
			"current_level": 0,
		})
	if bonus_slots > 0:
		var bonus_ids: Array = _MVP_BONUS_DEFS.keys()
		bonus_ids.shuffle()
		var picked_bonus: Array = bonus_ids.slice(0, bonus_slots)
		for bid in picked_bonus:
			var bdef: Dictionary = _MVP_BONUS_DEFS[bid]
			offers.append({
				"type": "bonus",
				"id": bid,
				"name": bdef["name"],
				"color": bdef["color"],
				"desc": bdef["desc"],
				"owned": false,
				"current_level": 0,
			})
	EventBus.level_up_choices_offered.emit(offers)
	return offers


func acquire(skill_id: String, player: Node) -> void:
	# MVP 호환: 미보유면 인스턴스화 후 player의 자식으로 add. 보유면 set_level().
	if not _MVP_SKILL_DEFS.has(skill_id):
		return
	var def: Dictionary = _MVP_SKILL_DEFS[skill_id]
	if owned.has(skill_id):
		var entry: Dictionary = owned[skill_id]
		var new_level: int = min(MAX_SKILL_LEVEL, int(entry["level"]) + 1)
		entry["level"] = new_level
		var inst: Node = entry["instance"]
		if is_instance_valid(inst) and inst.has_method("set_level"):
			inst.set_level(new_level)
		EventBus.skill_leveled.emit(StringName(skill_id), new_level)
		return
	if not is_instance_valid(player):
		return
	var scene: PackedScene = load(String(def["scene_path"]))
	if scene == null:
		return
	var instance: Node = scene.instantiate()
	if "player" in instance:
		instance.set("player", player)
	player.add_child(instance)
	owned[skill_id] = {
		"scene": scene,
		"instance": instance,
		"level": 1,
	}
	EventBus.skill_acquired.emit(StringName(skill_id), 1)


# === 풀스펙 API (점진 도입) ===

func is_owned(id: StringName) -> bool:
	return owned.has(String(id)) or owned.has(id)


func level_of(id: StringName) -> int:
	var key: Variant = id if owned.has(id) else String(id)
	if not owned.has(key):
		return 0
	var entry: Variant = owned[key]
	if entry is Dictionary:
		return int(entry.get("level", 0))
	return int(entry)


func can_offer(id: StringName) -> bool:
	# R2/R3/R7 검사를 풀스펙 도입 시 채운다. MVP에서는 단순 카운트.
	if owned.size() >= MAX_OWNED and not is_owned(id):
		return false
	return true


func acquire_or_level(id: StringName) -> void:
	# 풀스펙 진입점: 신규면 LV1, 보유면 +1 (cap 5).
	if not skill_db.has(id):
		return
	if not is_owned(id):
		owned[id] = 1
		EventBus.skill_acquired.emit(id, 1)
		var sd: SkillData = skill_db[id]
		if sd.rarity == GameEnums.Rarity.LEGENDARY:
			legendary_acquired_this_run += 1
		return
	var lv: int = level_of(id)
	if lv >= MAX_SKILL_LEVEL:
		return
	owned[id] = lv + 1
	EventBus.skill_leveled.emit(id, lv + 1)


func draw_three_cards() -> Array:
	# 풀스펙 R1~R7 카드 추첨. .tres 풀이 비어 있으면 MVP get_offer()로 폴백.
	if skill_db.is_empty():
		return get_offer()
	var pool: Array = []
	for id in skill_db.keys():
		if can_offer(id):
			pool.append(id)
	pool.shuffle()
	var picks: Array = pool.slice(0, OFFER_SIZE)
	var offers: Array = []
	for id in picks:
		var data: SkillData = skill_db[id]
		offers.append({
			"type": "skill",
			"id": String(id),
			"name": data.display_name_ko,
			"color": data.icon_color.to_html(false),
			"desc": data.description_ko,
			"owned": is_owned(id),
			"current_level": level_of(id),
		})
	EventBus.level_up_choices_offered.emit(offers)
	return offers


func check_evolution_candidates() -> Array:
	var arr: Array = []
	for ev_id in evolution_db.keys():
		var ev: EvolutionData = evolution_db[ev_id]
		var all_ready: bool = true
		for req in ev.requires:
			if level_of(req) < MAX_SKILL_LEVEL:
				all_ready = false
				break
		if all_ready:
			arr.append(ev)
	return arr


func perform_evolution(combo_id: StringName) -> void:
	if not evolution_db.has(combo_id):
		return
	var ev: EvolutionData = evolution_db[combo_id]
	var from_ids: Array = []
	for req in ev.requires:
		owned.erase(req)
		from_ids.append(req)
	owned[ev.result.id] = 1
	skill_db[ev.result.id] = ev.result
	EventBus.skill_evolved.emit(from_ids, ev.result.id)


# === 내부 ===

func _on_run_started(_char_id: StringName, _ch_id: StringName) -> void:
	if _active_character:
		reset_for_run(_active_character)
	else:
		owned.clear()
		legendary_acquired_this_run = 0
