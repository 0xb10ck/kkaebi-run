class_name CharacterData
extends Resource

# §3.5 — 6종 캐릭터. 메타 강화 미적용 기본값 + 무기/패시브/궁극 + 친밀도 트리.

@export var id: StringName
@export var display_name_ko: String
@export_multiline var lore_ko: String = ""
@export var sprite_size_px: Vector2i = Vector2i(48, 48)
@export var sprite_texture: Texture2D
@export var portrait_texture: Texture2D

# === 역할 / 분류 ===
@export var role: String = ""  # 딜러 / 탱커 / 서포터 / 하이브리드 등 자유 텍스트

# === 기본 스탯 ===
@export var base_hp: int = 100
@export var base_move_speed: float = 100.0
@export var base_attack: int = 10
@export var base_attack_speed: float = 1.0
@export var base_pickup_radius: float = 60.0
@export var base_luck: float = 0.0
@export var base_crit: float = 5.0
@export var base_cdr: float = 0.0
@export var base_intelligence: int = 10

# === 무기 ===
@export var weapon_scene: PackedScene
@export var weapon_radius_px: float = 70.0
@export var weapon_damage_coef: float = 1.0
@export var weapon_hit_cooldown_s: float = 1.0
@export var weapon_max_targets: int = 6

# === 고유 패시브 / 궁극기 ===
@export var passive_id: StringName
@export var passive_params: Dictionary = {}
@export_multiline var passive_description: String = ""
@export var ultimate_id: StringName
@export var ultimate_cooldown_s: float = 45.0
@export var ultimate_params: Dictionary = {}
@export_multiline var ultimate_description: String = ""

# === 시작 보유 스킬 (런 시작 시 자동 보유) ===
@export var starting_skill_ids: Array[StringName] = []

# === 시작 스킬 가중치 (skill_id -> float) ===
@export var start_weight_overrides: Dictionary = {}

# === 해금 ===
@export var unlock_cost_orbs: int = 0
@export var unlock_requires: Array[StringName] = []
@export var unlocked_by_default: bool = false

# === 친밀도 트리 ===
@export var affinity_tree: Array[AffinityNode] = []
@export var affinity_max: int = 20


# === AC 명세 별칭 표면 (AC3) ===
# base_weapon: weapon_scene과 동일. 외부 식별자명 호환.
# unlock_condition: unlock_requires + unlock_cost_orbs를 묶은 Dictionary.

var base_weapon: PackedScene:
	get:
		return weapon_scene
	set(value):
		weapon_scene = value

var unlock_condition: Dictionary:
	get:
		return {
			"requires": unlock_requires,
			"cost_orbs": unlock_cost_orbs,
		}
	set(value):
		if value.has("requires"):
			var req: Array[StringName] = []
			for item in value["requires"]:
				req.append(StringName(String(item)))
			unlock_requires = req
		if value.has("cost_orbs"):
			unlock_cost_orbs = int(value["cost_orbs"])

# 풀스펙 명세 별칭: default_weapon_scene / affinity_bonuses
# 외부에서 사용하는 식별자명을 기존 @export 필드에 매핑한다.

var default_weapon_scene: PackedScene:
	get:
		return weapon_scene
	set(value):
		weapon_scene = value

var affinity_bonuses: Array[Dictionary]:
	get:
		var result: Array[Dictionary] = []
		for node in affinity_tree:
			if node == null:
				continue
			result.append({
				"id": node.id,
				"affinity_required": node.affinity_required,
				"branch": node.branch,
				"effect_kind": node.effect_kind,
				"effect_params": node.effect_params,
			})
		return result
