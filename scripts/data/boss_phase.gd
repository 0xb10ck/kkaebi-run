class_name BossPhase
extends Resource

# §3.3 — 보스 페이즈. BossData.phases[*]로 직렬. HP 임계 도달 시 다음 페이즈로 전환.

@export var phase_index: int = 0
@export var hp_threshold_percent: float = 1.0  # 이 페이즈로 진입하는 HP 비율 (1.0 = 시작)
@export var time_threshold_s: float = 0.0      # HP_AND_TIME / TIMED_ONLY 모드에서 사용
@export var transition_invuln_s: float = 1.5
@export var transition_camera_shake: float = 0.3
@export var transition_vfx_id: StringName = &""
@export var idle_min_s: float = 0.6
@export var idle_max_s: float = 1.4
@export var pattern_queue: Array[BossPattern] = []
@export var move_speed_mult: float = 1.0
@export var damage_mult: float = 1.0
@export var keyword_ko: String = ""
