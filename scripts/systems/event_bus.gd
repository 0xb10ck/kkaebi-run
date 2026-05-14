extends Node

# §2.1 — 글로벌 시그널 카탈로그. 상태 없음, 시그널만.
# 발신자는 자기 영역의 사실만 발신("적이 죽었다"); 의미 변환은 수신자가 한다.

# === 런 라이프사이클 ===
signal run_started(character_id: StringName, chapter_id: StringName)
signal run_ended(reason: StringName, stats: Dictionary)
signal stage_started(chapter_id: StringName, stage_index: int)
signal stage_cleared(chapter_id: StringName, stage_index: int)
signal chapter_cleared(chapter_id: StringName, first_clear: bool)
signal intermission_entered(chapter_id: StringName)
signal intermission_exited(next_chapter_id: StringName)

# === 전투 / 생존 ===
signal player_damaged(amount: int, source: StringName)
signal player_healed(amount: int, source: StringName)
signal player_died()
signal player_revived(source: StringName)
signal enemy_killed(enemy_id: StringName, pos: Vector2, by_skill: StringName)
signal boss_phase_changed(boss_id: StringName, phase_index: int)
signal boss_defeated(boss_id: StringName, time_taken: float, no_hit: bool)
signal boss_pattern_started(boss_id: StringName, pattern_id: StringName)
signal boss_pattern_telegraphed(pattern_id: StringName, duration: float)

# === 진행 ===
signal xp_collected(value: int)
signal gold_collected(value: int)
signal level_changed(new_level: int)
signal level_up_choices_offered(choices: Array)
signal level_up_choice_selected(choice: Dictionary)
signal skill_acquired(skill_id: StringName, level: int)
signal skill_leveled(skill_id: StringName, new_level: int)
signal skill_evolved(from_ids: Array, to_id: StringName)

# === 메타 / 영속 ===
signal save_requested(reason: StringName)
signal save_completed(success: bool)
signal meta_changed(key: StringName, new_value: Variant)
signal shinmok_advanced(new_stage: int)
signal achievement_unlocked(achievement_id: StringName)
signal character_unlocked(character_id: StringName)
signal codex_entry_unlocked(category: StringName, entry_id: StringName)
signal meta_currency_changed(currency: StringName, new_value: int)

# === 이벤트 / 환경 ===
signal random_event_triggered(event_id: StringName, payload: Dictionary)
signal environment_entered(env_id: StringName, pos: Vector2)
signal environment_exited(env_id: StringName, pos: Vector2)
signal daily_challenge_progress(challenge_id: StringName, progress: int, target: int)

# === UI ===
signal toast_requested(text: String, duration: float)
signal hud_visibility_changed(visible: bool)
signal pause_requested(paused: bool)


func _ready() -> void:
	# EventBus는 의도적으로 첫 번째 자동로드 — 누구도 참조하지 않는다.
	process_mode = Node.PROCESS_MODE_ALWAYS
