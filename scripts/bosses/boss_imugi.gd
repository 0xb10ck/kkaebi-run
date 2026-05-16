extends BossBase

# MB02 이무기 — 짙은 녹색 비늘 뱀. 2페이즈(몸통 활용/미완성 여의주).
# 패턴: 몸통 돌진, 꼬리 휩쓸기, 동굴 잠수, 비늘 튕기기, 여의주 폭주, 물 장판, 광폭 돌진, 꼬리 채찍.

const _SCALE_GREEN: Color = Color(0.18, 0.45, 0.28, 0.95)
const _SCALE_TEAL: Color = Color(0.18, 0.55, 0.55, 0.95)
const _ORB_COLOR: Color = Color(0.40, 0.95, 0.85, 0.95)

var _body: Polygon2D


func _apply_data(d: BossData) -> void:
	var rx: float = float(max(36, int(d.sprite_size_px.x / 2)))
	var ry: float = float(max(28, int(d.sprite_size_px.y / 2)))
	_body = BossCombat.make_ellipse(_SCALE_GREEN, rx, ry)
	_body.name = "ImugiBody"
	add_child(_body)
	var orb: Polygon2D = BossCombat.make_disc(_ORB_COLOR, ry * 0.25)
	orb.name = "ImugiOrb"
	orb.position = Vector2(rx * 0.6, 0)
	add_child(orb)


func _on_phase_transition_completed(new_index: int) -> void:
	if new_index >= 1 and _body != null:
		_body.color = _SCALE_TEAL


func _execute_pattern(p: BossPattern) -> void:
	var dmg: int = BossCombat.resolve_damage(p, current_phase)
	match String(p.id):
		"im_body_charge", "im_fury_charge":
			BossCombat.hit_line_forward(self, BossCombat.r(p, 40.0) * 2.0, BossCombat.l(p, 480.0), dmg)
		"im_tail_sweep":
			BossCombat.hit_cone_back(self, BossCombat.r(p, 140.0), BossCombat.a(p, 220.0), dmg)
		"im_dive":
			# 동굴 잠수 → 착탄점 3곳 원형. MVP: 플레이어 위치 + 좌우 ±100px.
			var pp: Vector2 = BossCombat.player_pos(self)
			BossCombat.hit_circle(self, pp, BossCombat.r(p, 100.0), dmg)
			BossCombat.hit_circle(self, pp + Vector2(-100, 0), BossCombat.r(p, 100.0), dmg)
			BossCombat.hit_circle(self, pp + Vector2(100, 0), BossCombat.r(p, 100.0), dmg)
		"im_scale_burst":
			# 360도 6갈래 직선 투사체 — MVP: 보스 중심 광역 1타.
			BossCombat.hit_circle(self, global_position, BossCombat.r(p, 120.0), dmg)
		"im_yeoui_burst":
			BossCombat.hit_circle(self, global_position, BossCombat.r(p, 220.0), dmg)
		"im_water_field":
			# 물 장판 토하기 — 직선상 3개 원형. MVP: 즉시 1회 데미지(도트 표면).
			var dir: Vector2 = BossCombat.facing(self)
			var base: Vector2 = global_position + dir * 80.0
			for i in 3:
				BossCombat.hit_circle(self, base + dir * (140.0 * float(i)), BossCombat.r(p, 70.0), dmg)
		"im_tail_whip":
			BossCombat.hit_line_forward(self, BossCombat.r(p, 40.0) * 2.0, BossCombat.l(p, 200.0), dmg)
		_:
			BossCombat.dispatch_by_shape(self, p, dmg)
