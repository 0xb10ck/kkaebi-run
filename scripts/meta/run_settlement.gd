class_name RunSettlement
extends RefCounted

# AC11 — 런 종료 정산. MetaState.compute_run_settlement에 위임하여 도깨비 구슬을 산정.
# MetaState가 내부적으로 add_dokkaebi_orbs(orbs)를 호출해 자동 누적·저장한다.


func settle(kills: int, time: float, chapter: int, level: int = 1) -> int:
	var stats_in: Dictionary = {
		"kills": kills,
		"survive_sec": int(round(time)),
		"level": level,
		"chapter_number": chapter,
	}
	var summary: Dictionary = MetaState.compute_run_settlement(stats_in)
	return int(summary.get("orbs", 0))
