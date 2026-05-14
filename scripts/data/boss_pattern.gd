class_name BossPattern
extends Resource

# §3.3 — 보스 단일 패턴(어택). BossPhase.pattern_queue 안에 가중치 랜덤으로 사용.

@export var id: StringName
@export var display_name_ko: String
@export var shape: GameEnums.PatternShape = GameEnums.PatternShape.CIRCLE_AOE
@export var weight: int = 10
@export var cooldown_s: float = 5.0

# === 텔레그래프 ===
@export var telegraph_duration_s: float = 1.0
@export var telegraph_vfx_id: StringName = &""
@export var telegraph_se: AudioStream

# === 판정 ===
@export var hitbox_radius_px: float = 80.0
@export var hitbox_length_px: float = 0.0
@export var hitbox_angle_deg: float = 60.0
@export var damage: int = 20
@export var status_effect: StringName = &""
@export var status_duration_s: float = 0.0
@export var knockback_px: float = 0.0

# === 투사체 / 소환 ===
@export var projectile_speed: float = 0.0
@export var projectile_count: int = 1
@export var projectile_spread_deg: float = 0.0
@export var summon_enemy_id: StringName = &""
@export var summon_count: int = 0
