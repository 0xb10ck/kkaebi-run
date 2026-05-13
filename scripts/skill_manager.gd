class_name SkillManager
extends Node


const MAX_SKILL_LEVEL: int = 5
const OFFER_SIZE: int = 3

const SKILL_DEFS: Dictionary = {
	"fire_orb": {
		"name": "도깨비불",
		"color": "#E03C3C",
		"desc": "주변을 회전하는 불꽃 3개",
		"scene": preload("res://scenes/skills/fire_orb.tscn"),
	},
	"frost_ring": {
		"name": "서리 고리",
		"color": "#3C7CE0",
		"desc": "주변 적의 이속을 30% 감소시킵니다",
		"scene": preload("res://scenes/skills/frost_ring.tscn"),
	},
	"vine_whip": {
		"name": "덩굴 채찍",
		"color": "#4CAF50",
		"desc": "가장 가까운 적을 직선 타격합니다",
		"scene": preload("res://scenes/skills/vine_whip.tscn"),
	},
	"gold_shield": {
		"name": "금빛 방패",
		"color": "#F0EDE6",
		"desc": "1회 피격을 완전히 막아주는 보호막. 소진 후 5초 뒤 재생성됩니다.",
		"scene": preload("res://scenes/skills/gold_shield.tscn"),
	},
	"rock_throw": {
		"name": "바위 투척",
		"color": "#E0C23C",
		"desc": "가장 먼 적에게 발사, 스턴 0.5초",
		"scene": preload("res://scenes/skills/rock_throw.tscn"),
	},
}

const BONUS_DEFS: Dictionary = {
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


var owned: Dictionary = {}


func get_offer() -> Array:
	var unowned_ids: Array = []
	for id in SKILL_DEFS.keys():
		if not owned.has(id):
			unowned_ids.append(id)
	unowned_ids.shuffle()

	var skill_pick_count: int = min(unowned_ids.size(), OFFER_SIZE)
	var skill_picks: Array = unowned_ids.slice(0, skill_pick_count)
	var bonus_slots: int = OFFER_SIZE - skill_pick_count

	var offers: Array = []
	for id in skill_picks:
		var def: Dictionary = SKILL_DEFS[id]
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
		var bonus_ids: Array = BONUS_DEFS.keys()
		bonus_ids.shuffle()
		var picked_bonus: Array = bonus_ids.slice(0, bonus_slots)
		for bid in picked_bonus:
			var bdef: Dictionary = BONUS_DEFS[bid]
			offers.append({
				"type": "bonus",
				"id": bid,
				"name": bdef["name"],
				"color": bdef["color"],
				"desc": bdef["desc"],
				"owned": false,
				"current_level": 0,
			})

	return offers


func acquire(skill_id: String, player: Node) -> void:
	if not SKILL_DEFS.has(skill_id):
		return
	var def: Dictionary = SKILL_DEFS[skill_id]
	var scene: PackedScene = def["scene"]
	if owned.has(skill_id):
		var entry: Dictionary = owned[skill_id]
		var new_level: int = min(MAX_SKILL_LEVEL, int(entry["level"]) + 1)
		entry["level"] = new_level
		var inst: Node = entry["instance"]
		if is_instance_valid(inst) and inst.has_method("set_level"):
			inst.set_level(new_level)
		return

	if not is_instance_valid(player):
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
