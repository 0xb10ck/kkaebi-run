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
		"desc": "피격 시 30% 확률로 반사합니다",
		"scene": preload("res://scenes/skills/gold_shield.tscn"),
	},
	"rock_throw": {
		"name": "바위 투척",
		"color": "#E0C23C",
		"desc": "가장 먼 적에게 발사, 스턴 0.5초",
		"scene": preload("res://scenes/skills/rock_throw.tscn"),
	},
}


var owned: Dictionary = {}


func get_offer() -> Array:
	var unowned_ids: Array = []
	for id in SKILL_DEFS.keys():
		if not owned.has(id):
			unowned_ids.append(id)

	var pool: Array
	if unowned_ids.size() > 0:
		pool = unowned_ids.duplicate()
	else:
		pool = []
		for id in owned.keys():
			if int(owned[id]["level"]) < MAX_SKILL_LEVEL:
				pool.append(id)

	pool.shuffle()
	var picked: Array = pool.slice(0, OFFER_SIZE)

	var offers: Array = []
	for id in picked:
		var def: Dictionary = SKILL_DEFS[id]
		var is_owned: bool = owned.has(id)
		var current_level: int = 0
		if is_owned:
			current_level = int(owned[id]["level"])
		offers.append({
			"id": id,
			"name": def["name"],
			"color": def["color"],
			"desc": def["desc"],
			"owned": is_owned,
			"current_level": current_level,
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
