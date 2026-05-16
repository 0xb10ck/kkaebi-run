extends BossBase

# MB05 검은 도깨비 — 플레이어 미러 색 반전 도깨비. 2페이즈(모방/진화).
# 패턴: 스킬 학습, 모방 발사, 거울 분신, 방망이 휘두르기, 합성 모방, 자기 복제 폭주, 욕망의 사슬.

const _MIRROR_BLACK: Color = Color(0.08, 0.05, 0.10, 0.95)
const _MIRROR_RED: Color = Color(0.55, 0.10, 0.18, 0.95)

var _body: Polygon2D
var _learned_skills: Array[StringName] = []  # 학습된 스킬 식별자 큐.


func _apply_data(d: BossData) -> void:
	var rx: float = float(max(24, int(d.sprite_size_px.x / 2)))
	var ry: float = float(max(24, int(d.sprite_size_px.y / 2)))
	_body = BossCombat.make_rect(_MIRROR_BLACK, rx * 2.0, ry * 2.0)
	_body.name = "GeomeunDokkaebiBody"
	add_child(_body)


func _on_phase_transition_completed(new_index: int) -> void:
	if new_index >= 1 and _body != null:
		_body.color = _MIRROR_RED


func _execute_pattern(p: BossPattern) -> void:
	var dmg: int = BossCombat.resolve_damage(p, current_phase)
	match String(p.id):
		"bd_skill_learn":
			# 학습만 — 데미지 0. 마지막 학습 슬롯 추가(MVP: 익명 토큰).
			_learned_skills.append(&"learned_%d" % _learned_skills.size())
			return
		"bd_mimic_fire":
			# 학습 스킬 재현 — MVP: 보스 정면 광역.
			if _learned_skills.is_empty():
				return
			BossCombat.hit_circle(self, BossCombat.player_pos(self), BossCombat.r(p, 80.0), dmg)
		"bd_mirror_clone":
			# 분신 2체 모방 데미지 — MVP: 보스 양옆 광역.
			var left: Vector2 = global_position + Vector2(-50, 0)
			var right: Vector2 = global_position + Vector2(50, 0)
			BossCombat.hit_circle(self, left, 60.0, dmg)
			BossCombat.hit_circle(self, right, 60.0, dmg)
		"bd_club_swing", "bd_club_swing_p2":
			BossCombat.hit_cone_forward(self, BossCombat.r(p, 110.0), BossCombat.a(p, 130.0), dmg)
		"bd_fusion_mimic":
			# 두 스킬 합성 — MVP: 보스 중심 큰 광역.
			if _learned_skills.size() < 2:
				return
			BossCombat.hit_circle(self, global_position, 160.0, dmg)
		"bd_self_copy":
			# 분신 4체 — MVP: 보스 사방 4개 광역.
			var offs: Array[Vector2] = [Vector2(-80, 0), Vector2(80, 0), Vector2(0, -80), Vector2(0, 80)]
			for o in offs:
				BossCombat.hit_circle(self, global_position + o, 60.0, dmg)
		"bd_desire_chain":
			# 사슬 직선 + 조작 반전 1.0s.
			BossCombat.hit_line_forward(self, BossCombat.r(p, 36.0) * 2.0, BossCombat.l(p, 600.0), dmg)
		_:
			BossCombat.dispatch_by_shape(self, p, dmg)
