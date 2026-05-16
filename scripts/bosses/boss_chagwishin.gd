extends BossBase

# MB03 차귀신 — 검은 망토 형체, 수레를 끄는 명부 사령. 2페이즈(수레 운용/텔레포트).
# 패턴: 수레 돌진, 영혼 손님 소환, 강제 탑승, 수레바퀴 파편, 곡소리 광역, 그림자 점멸, 망령 화살, 사슬 끌어당김.

const _CLOAK_BLACK: Color = Color(0.07, 0.06, 0.10, 0.95)
const _CLOAK_GLOW: Color = Color(0.25, 0.20, 0.45, 0.95)
const _CART_BROWN: Color = Color(0.42, 0.28, 0.18, 0.95)

var _body: Polygon2D
var _cart: Polygon2D


func _apply_data(d: BossData) -> void:
	var rx: float = float(max(28, int(d.sprite_size_px.x / 2)))
	var ry: float = float(max(40, int(d.sprite_size_px.y / 2)))
	_body = BossCombat.make_ellipse(_CLOAK_BLACK, rx, ry)
	_body.name = "ChagwishinCloak"
	add_child(_body)
	_cart = BossCombat.make_rect(_CART_BROWN, 112.0, 64.0)
	_cart.name = "ChagwishinCart"
	_cart.position = Vector2(-rx - 32, 8)
	add_child(_cart)


func _on_phase_transition_completed(new_index: int) -> void:
	# P2: 수레가 부서지고 키 1.2배.
	if new_index >= 1:
		if _cart != null:
			_cart.visible = false
		if _body != null:
			_body.color = _CLOAK_GLOW
			_body.scale = Vector2(1.0, 1.2)


func _execute_pattern(p: BossPattern) -> void:
	var dmg: int = BossCombat.resolve_damage(p, current_phase)
	match String(p.id):
		"cg_cart_rush":
			BossCombat.hit_line_forward(self, BossCombat.r(p, 60.0) * 2.0, BossCombat.l(p, 560.0), dmg)
		"cg_soul_summon":
			# 영혼 손님 3마리(MVP: 소환 인스턴스 생략, 보스 주변 광역 접근 데미지).
			BossCombat.hit_circle(self, global_position, BossCombat.r(p, 60.0), dmg)
		"cg_force_ride":
			# 단일 대상 사슬 — 근접 100px 이내 플레이어에 데미지 + 방향 반전(slow로 모사).
			var pp: Vector2 = BossCombat.player_pos(self)
			if global_position.distance_to(pp) <= 100.0:
				BossCombat.deal(dmg)
				_apply_player_slow(0.5, 2.0)
		"cg_wheel_shrapnel":
			# 보스 중심 반경 180 원형 + 8갈래 직선 600 — MVP: 광역 단일 판정.
			BossCombat.hit_circle(self, global_position, BossCombat.r(p, 180.0), dmg)
		"cg_wail":
			BossCombat.hit_screen(dmg)
		"cg_shadow_blink":
			# 플레이어 등 뒤 120px 출현 → 전방 직선 베기.
			var dir_to_p: Vector2 = (BossCombat.player_pos(self) - global_position).normalized()
			global_position = BossCombat.player_pos(self) - dir_to_p * 120.0
			BossCombat.hit_line_from(self, global_position, dir_to_p, 50.0, 160.0, dmg)
		"cg_arrow":
			# 호밍 화살 3발 — MVP: 플레이어 위치 광역.
			BossCombat.hit_circle(self, BossCombat.player_pos(self), 40.0, dmg)
		"cg_chain_pull":
			# 직선 사슬 — 적중 시 보스 앞 100px로 끌어당김 + 1.0s 스턴.
			var dir: Vector2 = BossCombat.facing(self)
			BossCombat.hit_line_forward(self, BossCombat.r(p, 30.0) * 2.0, BossCombat.l(p, 600.0), dmg)
			var pp2: Vector2 = BossCombat.player_pos(self)
			var to_p: Vector2 = pp2 - global_position
			var along: float = to_p.dot(dir)
			var perp: float = absf(to_p.dot(Vector2(-dir.y, dir.x)))
			if along >= 0.0 and along <= 600.0 and perp <= 30.0:
				_apply_player_slow(0.05, 1.0)
		_:
			BossCombat.dispatch_by_shape(self, p, dmg)


func _apply_player_slow(factor: float, duration: float) -> void:
	var t: Node = get_tree().get_first_node_in_group("player")
	if t != null and t.has_method("apply_slow"):
		t.call("apply_slow", factor, duration)
