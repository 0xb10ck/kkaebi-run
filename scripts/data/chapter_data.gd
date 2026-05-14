class_name ChapterData
extends Resource

# §3.6 — 6장 챕터 정의. 스폰 풀/스케일/보스/이벤트/보상.

@export var id: StringName
@export var display_name_ko: String
@export var chapter_number: int = 1
@export_multiline var description_ko: String = ""
@export var background_color: Color = Color("#2A2A35")
@export var background_texture: Texture2D
@export var ambient_bgm: AudioStream
@export var unlock_shinmok_required: int = 1
@export var unlock_requires: Array[StringName] = []

# === 스테이지 구성 ===
@export var stage_count: int = 3
@export var stage_duration_s: float = 300.0

# === 스폰 ===
@export var enemy_pool: Array[StringName] = []
@export var enemy_weights: Dictionary = {}
@export var hp_scale: float = 1.0
@export var damage_scale: float = 1.0
@export var move_speed_scale: float = 1.0
@export var spawn_curve_id: StringName = &"default"

# === 보스 ===
@export var mini_boss_id: StringName = &""
@export var chapter_boss_id: StringName = &""

# === 환경 / 이벤트 ===
@export var environment_pool: Array[GameEnums.EnvKind] = []
@export var environment_density: float = 0.4
@export var event_pool: Array[GameEnums.EventKind] = []
@export var event_probability_per_min: float = 0.25

# === 보상 ===
@export var clear_base_orbs: int = 30
@export var clear_first_bonus_orbs: int = 0
@export var hard_mode_unlocked: bool = false
@export var hard_difficulty_mult: float = 1.5
