class_name CharacterData
extends Resource

# §3.5 — 6종 캐릭터. 메타 강화 미적용 기본값 + 무기/패시브/궁극 + 친밀도 트리.

@export var id: StringName
@export var display_name_ko: String
@export_multiline var lore_ko: String = ""
@export var sprite_size_px: Vector2i = Vector2i(48, 48)
@export var sprite_texture: Texture2D
@export var portrait_texture: Texture2D

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
@export var ultimate_id: StringName
@export var ultimate_cooldown_s: float = 45.0
@export var ultimate_params: Dictionary = {}

# === 시작 스킬 가중치 (skill_id -> float) ===
@export var start_weight_overrides: Dictionary = {}

# === 해금 ===
@export var unlock_cost_orbs: int = 0
@export var unlock_requires: Array[StringName] = []
@export var unlocked_by_default: bool = false

# === 친밀도 트리 ===
@export var affinity_tree: Array[AffinityNode] = []
@export var affinity_max: int = 20
