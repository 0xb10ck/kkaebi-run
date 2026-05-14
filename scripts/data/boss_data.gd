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
@export var reward_myth_fragments: int = 0
@export var reward_artifact_id: StringName = &""

# === 씬 참조 (옵션) ===
@export var scene: PackedScene

# === 출현 ===
@export var chapter: int = 1
@export var trigger_time_s: float = 225.0  # 미니보스 3:45
@export var seal_stone_skippable: bool = true


# === AC 명세 별칭 표면 (AC3) ===
# patterns: 모든 phase의 pattern_queue를 평탄화해 단일 배열로 노출.
# transition_hp: 각 phase의 hp_threshold_percent 모음.

var patterns: Array:
	get:
		var result: Array = []
		for phase in phases:
			if phase == null:
				continue
			for p in phase.pattern_queue:
				result.append(p)
		return result

var transition_hp: Array[float]:
	get:
		var result: Array[float] = []
		for phase in phases:
			if phase == null:
				continue
			result.append(phase.hp_threshold_percent)
		return result

# 풀스펙 명세 별칭: max_hp / defense / move_speed / phase_hp_thresholds / reward_* / sprite_size
# 외부에서 쓰는 식별자명을 기존 @export 필드에 매핑한다.

var max_hp: float:
	get:
		return float(hp)
	set(value):
		hp = int(value)

var defense: float:
	get:
		return float(armor)
	set(value):
		armor = int(value)

var move_speed: float:
	get:
		return base_move_speed
	set(value):
		base_move_speed = value

var phase_hp_thresholds: Array[float]:
	get:
		return transition_hp

var reward_orbs: int:
	get:
		return first_kill_orbs
	set(value):
		first_kill_orbs = value

var reward_leaves: int:
	get:
		return first_kill_leaves
	set(value):
		first_kill_leaves = value

var sprite_size: Vector2i:
	get:
		return sprite_size_px
	set(value):
		sprite_size_px = value
