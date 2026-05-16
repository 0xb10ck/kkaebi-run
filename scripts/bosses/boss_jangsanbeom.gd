extends BossBase

# MB01 장산범 — 흰 털 호랑이 요괴. 2페이즈(유인기/광폭화).
# 패턴: 가짜 보물 미끼, 사람 목소리 유인, 측면 급습, 발톱 후리기, 광폭 도약 연타, 위장 해제 포효, 그림자 분신.

const _BODY_COLOR_P1: Color = Color(0.93, 0.92, 0.88, 0.95)
const _BODY_COLOR_P2: Color = Color(0.55, 0.40, 0.32, 0.95)
const _STRIPE_COLOR: Color = Color(0.20, 0.15, 0.12, 0.85)

var _body: Polygon2D


func _apply_data(d: BossData) -> void:
	var radius: float = float(max(28, int(d.sprite_size_px.x / 2)))
	_body = BossCombat.make_disc(_BODY_COLOR_P1, radius)
	_body.name = "JangsanbeomBody"
	add_child(_body)
	var stripes: Polygon2D = BossCombat.make_rect(_STRIPE_COLOR, radius, radius * 0.2)
	stripes.name = "JangsanbeomStripes"
	add_child(stripes)


func _on_phase_transition_completed(new_index: int) -> void:
	if new_index >= 1 and _body != null:
		_body.color = _BODY_COLOR_P2


func _execute_pattern(p: BossPattern) -> void:
	var dmg: int = BossCombat.resolve_damage(p, current_phase)
	match String(p.id):
		"jb_voice_lure":
			return
		"jb_fake_treasure":
			BossCombat.hit_circle(self, global_position, BossCombat.r(p, 60.0), dmg)
		"jb_charge":
			BossCombat.hit_line_forward(self, BossCombat.r(p, 30.0) * 2.0, BossCombat.l(p, 320.0), dmg)
		"jb_claw", "jb_claw_p2":
			BossCombat.hit_cone_forward(self, BossCombat.r(p, 100.0), BossCombat.a(p, 110.0), dmg)
		"jb_leap_combo":
			var pp: Vector2 = BossCombat.player_pos(self)
			BossCombat.hit_circle(self, pp, BossCombat.r(p, 80.0), dmg)
			BossCombat.hit_circle(self, pp + Vector2(-70, 0), BossCombat.r(p, 80.0), dmg)
			BossCombat.hit_circle(self, pp + Vector2(70, 0), BossCombat.r(p, 80.0), dmg)
		"jb_roar":
			# 위장 해제 포효 — 데미지 0, 추후 idle 단축으로 공속 +30% 표면 모사.
			if current_phase != null:
				current_phase.idle_min_s = max(0.2, current_phase.idle_min_s * 0.77)
				current_phase.idle_max_s = max(0.4, current_phase.idle_max_s * 0.77)
		"jb_shadow_clone":
			BossCombat.hit_circle(self, global_position, BossCombat.r(p, 40.0), dmg)
		_:
			BossCombat.dispatch_by_shape(self, p, dmg)
