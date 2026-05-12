extends Node

signal skill_acquired(skill_id: StringName)

const ALL_SKILL_IDS: Array[StringName] = [
	&"dokkebibul", &"seori_ring", &"deonggul_whip", &"gold_shield", &"bawi_throw"
]

const BONUS_CARDS: Array[Dictionary] = [
	{ "id": &"bonus_max_hp", "title": "최대 HP +20", "description": "최대 체력이 20 증가하고, 현재 체력도 20 회복됩니다." },
	{ "id": &"bonus_move_speed", "title": "이동 속도 +5%", "description": "이동 속도가 5%만큼 영구적으로 빨라집니다." },
	{ "id": &"bonus_xp_gain", "title": "경험치 +10%", "description": "획득하는 경험치가 10%만큼 증가합니다." },
]

var skill_db: Dictionary = {}
var owned: Array[StringName] = []


func _ready() -> void:
	_load_skills()


func _load_skills() -> void:
	skill_db.clear()
	var paths := {
		&"dokkebibul": "res://scripts/data/resources/skills/dokkebibul.tres",
		&"seori_ring": "res://scripts/data/resources/skills/seori_ring.tres",
		&"deonggul_whip": "res://scripts/data/resources/skills/deonggul_whip.tres",
		&"gold_shield": "res://scripts/data/resources/skills/gold_shield.tres",
		&"bawi_throw": "res://scripts/data/resources/skills/bawi_throw.tres",
	}
	for id in paths.keys():
		var res: Resource = load(paths[id])
		if res != null:
			skill_db[id] = res


func reset() -> void:
	owned.clear()


func is_owned(id: StringName) -> bool:
	return owned.has(id)


func acquire(id: StringName) -> void:
	if owned.has(id):
		return
	owned.append(id)
	skill_acquired.emit(id)


func draw_three_cards() -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	var available_skills: Array[StringName] = []
	for sid in ALL_SKILL_IDS:
		if not owned.has(sid):
			available_skills.append(sid)
	available_skills.shuffle()
	for sid in available_skills:
		if cards.size() >= 3:
			break
		var data: SkillData = skill_db.get(sid, null)
		if data == null:
			continue
		cards.append({
			"kind": "skill",
			"id": sid,
			"title": data.display_name_ko,
			"description": data.description_ko,
			"icon_color": data.icon_color,
			"data": data,
		})
	# 부족분은 보너스 카드로 채운다 (중복 허용 안 함, 같은 화면 기준)
	var bonuses := BONUS_CARDS.duplicate()
	bonuses.shuffle()
	for b in bonuses:
		if cards.size() >= 3:
			break
		cards.append({
			"kind": "bonus",
			"id": b["id"],
			"title": b["title"],
			"description": b["description"],
			"icon_color": Color(0.88, 0.76, 0.24, 1.0),
		})
	# 그래도 3장이 안 되면 무작위 보너스를 중복 허용으로 마저 채움 (5종 모두 소지 후 케이스)
	while cards.size() < 3:
		var b := BONUS_CARDS[randi() % BONUS_CARDS.size()]
		cards.append({
			"kind": "bonus",
			"id": b["id"],
			"title": b["title"],
			"description": b["description"],
			"icon_color": Color(0.88, 0.76, 0.24, 1.0),
		})
	return cards
