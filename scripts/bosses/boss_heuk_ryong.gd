extends BossBase

# B05 흑룡 — 검은 비늘 거대 용. 3페이즈(흑염/안개/각성).
# 패턴: 흑염 브레스, 비늘 폭발, 꼬리 휩쓸기, 측면 비행, 검은 안개, 그림자 새끼용, 흑염 폭격,
#       비늘 폭발(강), 흑염+뇌우 콤보, 절멸 브레스, 회전 비행 돌진, 그림자 새끼용 폭주, 최후의 검은 신목.

const _SCALE_BLACK: Color = Color(0.06, 0.05, 0.08, 0.95)
const _SCALE_PURPLE: Color = Color(0.20, 0.06, 0.32, 0.95)
const _SCALE_AWAKEN: Color = Color(0.40, 0.06, 0.55, 0.95)
const _CRACK_PURPLE: Color = Color(0.65, 0.20, 0.95, 0.85)

var _body: Polygon2D
var _crack: Polygon2D


func _apply_data(d: BossData) -> void:
	var rx: float = float(max(48, int(d.sprite_size_px.x / 2)))
	var ry: float = float(max(48, int(d.sprite_size_px.y / 2)))
	_body = BossCombat.make_ellipse(_SCALE_BLACK, rx, ry)
	_body.name = "HeukRyongBody"
	add_child(_body)
	_crack = BossCombat.make_rect(_CRACK_PURPLE, rx * 0.15, ry * 0.9)
	_crack.name = "HeukRyongCrack"
	_crack.visible = false
	add_child(_crack)


func _on_phase_transition_completed(new_index: int) -> void:
	if _body == null:
		return
	if new_index == 1:
		_body.color = _SCALE_PURPLE
		if _crack != null:
			_crack.visible = true
	elif new_index >= 2:
		_body.color = _SCALE_AWAKEN
		if _crack != null:
			_crack.visible = true
			_crack.scale = Vector2(1.8, 1.2)


func _execute_pattern(p: BossPattern) -> void:
	var dmg: int = BossCombat.resolve_damage(p, current_phase)
	match String(p.id):
		"hr_black_breath":
			# 흑염 브레스 — 정면 부채꼴 90도, 반경 600px.
			BossCombat.hit_cone_forward(self, BossCombat.r(p, 600.0), BossCombat.a(p, 90.0), dmg)
		"hr_scale_burst":
			# 비늘 폭발 — 8갈래 360도. MVP: 보스 중심 광역.
			BossCombat.hit_circle(self, global_position, BossCombat.r(p, 320.0), dmg)
		"hr_tail_sweep":
			# 꼬리 휩쓸기 — 보스 후방 부채꼴 220도, 반경 280px.
			BossCombat.hit_cone_back(self, BossCombat.r(p, 280.0), BossCombat.a(p, 220.0), dmg)
		"hr_flyby":
			# 측면 비행 — 화면 가장자리 직선(폭 200px).
			BossCombat.hit_line_forward(self, 200.0, BossCombat.l(p, 1200.0), dmg)
		"hr_dark_fog":
			# 검은 안개 — 데미지 0, 시야 차단. MVP: 플레이어 둔화 표면.
			_apply_player_slow(0.8, 8.0)
			return
		"hr_shadow_drake":
			# 그림자 새끼용 3체 소환. MVP: 보스 주변 광역.
			BossCombat.hit_circle(self, global_position, 120.0, dmg)
		"hr_breath_bomb":
			# 흑염 폭격 — 임의 5지점. MVP: 플레이어 위치 + 좌우 ±120 + 상하 ±120 = 5점.
			var pp: Vector2 = BossCombat.player_pos(self)
			var r_b: float = BossCombat.r(p, 100.0)
			BossCombat.hit_circle(self, pp, r_b, dmg)
			BossCombat.hit_circle(self, pp + Vector2(-120, 0), r_b, dmg)
			BossCombat.hit_circle(self, pp + Vector2(120, 0), r_b, dmg)
			BossCombat.hit_circle(self, pp + Vector2(0, -120), r_b, dmg)
			BossCombat.hit_circle(self, pp + Vector2(0, 120), r_b, dmg)
		"hr_scale_burst_p2":
			BossCombat.hit_circle(self, global_position, BossCombat.r(p, 360.0), dmg)
		"hr_breath_thunder":
			# 흑염+뇌우 콤보 — 부채꼴 120도, 반경 700px + 임의 6지점 낙뢰.
			BossCombat.hit_cone_forward(self, BossCombat.r(p, 700.0), BossCombat.a(p, 120.0), dmg)
			for i in 6:
				var ang: float = TAU * float(i) / 6.0
				var off: Vector2 = Vector2(cos(ang), sin(ang)) * 220.0
				BossCombat.hit_circle(self, global_position + off, 100.0, max(1, int(dmg * 0.6)))
		"hr_annihilate":
			# 절멸 브레스 — 화면 가로 직선 띠(폭 200px).
			BossCombat.hit_line_forward(self, 200.0, BossCombat.l(p, 1200.0), dmg)
		"hr_spinning_flyby":
			# 회전 비행 돌진 — 사선 직선 × 2회.
			BossCombat.hit_line_forward(self, BossCombat.r(p, 75.0) * 2.0, BossCombat.l(p, 1400.0), dmg)
			BossCombat.hit_line_forward(self, BossCombat.r(p, 75.0) * 2.0, BossCombat.l(p, 1400.0), dmg)
		"hr_drake_storm":
			BossCombat.hit_circle(self, global_position, 160.0, dmg)
		"hr_final_judgement":
			# 최후의 검은 신목 — 화면 전체 광역(부적 기둥 미구현 — 무조건 적중).
			BossCombat.hit_screen(dmg)
		_:
			BossCombat.dispatch_by_shape(self, p, dmg)


func _apply_player_slow(factor: float, duration: float) -> void:
	var t: Node = get_tree().get_first_node_in_group("player")
	if t != null and t.has_method("apply_slow"):
		t.call("apply_slow", factor, duration)
