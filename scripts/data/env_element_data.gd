class_name EnvElementData
extends Resource

# meta-systems-spec §8.5 — 환경 요소 데이터 리소스.
# `.tres`로 직렬화되어 환경 인스턴스의 파라미터(지속/강도/적용 대상 등)를 제공한다.

@export var id: StringName
@export var display_name_ko: String
@export_multiline var lore_ko: String = ""

# 종류 — GameEnums.EnvKind 와 매핑.
@export var env_kind: GameEnums.EnvKind = GameEnums.EnvKind.THORNBUSH

# 영역 크기(px). Area2D CollisionShape2D 폭/높이로 사용.
@export var size_px: Vector2 = Vector2(32, 32)

# === 효과 강도 ===
@export var damage_per_tick: int = 0                       # 0이면 비활성
@export var damage_pct_of_max_hp: float = 0.0              # 0..1, 0이면 비활성
@export var tick_interval_s: float = 0.5
@export var slow_factor: float = 1.0                       # 1.0 = 둔화 없음, 0.8 = -20%
@export var slow_duration_s: float = 0.0
@export var vision_reduction: float = 0.0                  # 0..1
@export var range_reduction: float = 0.0                   # 0..1, 원거리 스킬 사거리 감소
@export var detect_reduction: float = 0.0                  # 0..1, 몬스터 탐지 감소

# === 라이프사이클 ===
@export var duration_s: float = -1.0                       # -1 = 영구
@export var max_hits: int = 0                              # 0 = 파괴 불가
@export var gold_drop_on_destroy: int = 0

# 파괴/제거 가능한 속성 — "fire","water","wood","metal","earth" 소문자.
@export var destructible_by: PackedStringArray = PackedStringArray()

# === 등장 ===
@export var spawn_chapters: PackedInt32Array = PackedInt32Array()
@export var spawn_count_per_chapter: Dictionary = {}       # {"2": 15, "4": 10}

# 실제 환경 노드를 만들어내는 스크립트 또는 씬 경로.
@export var script_path: String = ""
@export var scene_path: String = ""

# 시각 보조.
@export var placeholder_color: Color = Color(1, 1, 1, 1)
@export var sprite_texture: Texture2D
