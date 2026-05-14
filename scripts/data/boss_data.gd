class_name BossData
extends Resource

# §3.3 — 11종 보스(미니5 + 챕터6) 정의. 페이즈/패턴 큐 + 컷인/보상.

@export var id: StringName
@export var display_name_ko: String
@export_multiline var lore_ko: String = ""
@export var sprite_size_px: Vector2i = Vector2i(80, 56)
@export var sprite_texture: Texture2D
@export var hitbox_size_px: Vector2 = Vector2(64, 40)
@export var is_mini_boss: bool = false

# === 기본 스탯 ===
@export var hp: int = 1800
@export var armor: int = 0
@export var base_move_speed: float = 150.0
@export var melee_damage: int = 14

# === 페이즈 ===
@export var phase_transition_mode: GameEnums.BossPhaseTransition = GameEnums.BossPhaseTransition.HP_THRESHOLD
@export var phases: Array[BossPhase] = []

# === 컷인 / 연출 ===
@export var intro_cutscene_id: StringName = &""
@export var intro_duration_s: float = 2.5
@export var death_cutscene_duration_s: float = 2.0
@export var theme_bgm: AudioStream
@export var spawn_se: AudioStream
@export var defeat_se: AudioStream

# === 보상 ===
@export var first_kill_orbs: int = 50
@export var first_kill_leaves: int = 0
@export var rekill_orbs: int = 5
@export var grants_codex_entry: StringName = &""

# === 출현 ===
@export var chapter: int = 1
@export var trigger_time_s: float = 225.0  # 미니보스 3:45
@export var seal_stone_skippable: bool = true
