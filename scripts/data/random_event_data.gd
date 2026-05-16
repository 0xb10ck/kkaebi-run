class_name RandomEventData
extends Resource

# meta-systems-spec §8.2 — 런 내 랜덤 이벤트 데이터 리소스.
# EventManager가 .tres 풀을 읽어 weight/condition으로 추첨한다.

@export var id: StringName
@export var display_name_ko: String
@export_multiline var description_ko: String = ""

# 종류 — GameEnums.EventKind 와 매핑.
@export var event_kind: GameEnums.EventKind = GameEnums.EventKind.GOBLIN_MARKET

# === 발동 조건 ===
@export var base_weight: float = 0.10                      # 0..1 (스펙 §4.2 기본 확률을 0..1로 정규화)
@export var allowed_chapters: PackedInt32Array = PackedInt32Array([1, 2, 3, 4, 5])
@export var time_min_s: float = 0.0                        # 챕터 내 경과 시간(초) 하한
@export var time_max_s: float = 9999.0                     # 상한 (기본: 사실상 무제한)
@export var hp_pct_min: float = 0.0                        # 0..1
@export var hp_pct_max: float = 1.0                        # 0..1
@export var requires_post_boss_kill: bool = false          # 보스 처치 직후 N초 창에서만 (Spirit Blessing)
@export var post_boss_window_s: float = 30.0
@export var once_per_run: bool = false                     # 한 런 1회만
@export var max_per_run: int = 2                           # §4.1 — 같은 이벤트 최대 2회

# === 라이프사이클 ===
@export var duration_s: float = 30.0                       # 이벤트 활성 지속 시간

# === 가중치 보정 ===
# 신목 단계, HP 비율 등에 따른 곱 보정. 키: "shinmok_ge_4", "hp_lt_20".
@export var weight_modifiers: Dictionary = {}

# 구현 스크립트 경로 (EventManager가 load/new 함).
@export var script_path: String = ""

# 시각 / 안내.
@export var icon_color: Color = Color(1, 1, 1, 1)
@export var toast_text_ko: String = ""
