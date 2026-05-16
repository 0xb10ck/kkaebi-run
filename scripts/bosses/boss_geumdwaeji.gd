extends BossBase

# MB04 금돼지 — 거대 황금 멧돼지. 2페이즈(돌진/탐욕).
# 패턴: 금화 살포, 유혹 금화 트랩, 직선 돌진, 송곳니 올려치기, 금화 흡수, 광폭 회전 돌진, 황금 쇼크웨이브.

const _GOLD_HIDE: Color = Color(0.90, 0.72, 0.18, 0.95)
const _METAL_HIDE: Color = Color(1.00, 0.84, 0.28, 0.95)
const _TUSK_COLOR: Color = Color(0.95, 0.93, 0.85, 0.95)

var _body: Polygon2D


func _apply_data(d: BossData) -> void:
	var rx: float = float(max(48, int(d.sprite_size_px.x / 2)))
	var ry: float = float(max(36, int(d.sprite_size_px.y / 2)))
	_body = BossCombat.make_ellipse(_GOLD_HIDE, rx, ry)
	_body.name = "GeumdwaejiBody"
	add_child(_body)
	var tusk: Polygon2D = BossCombat.make_rect(_TUSK_COLOR, rx * 0.3, ry * 0.15)
	tusk.name = "GeumdwaejiTusk"
	tusk.position = Vector2(rx * 0.85, 0)
	add_child(tusk)


func _on_phase_transition_completed(new_index: int) -> void:
	if new_index >= 1 and _body != null:
		_body.color = _METAL_HIDE


func _execute_pattern(p: BossPattern) -> void:
	var dmg: int = BossCombat.resolve_damage(p, current_phase)
	match String(p.id):
		"gd_coin_scatter":
			# 12갈래 금화 투사체 — MVP: 보스 중심 광역 1타.
			BossCombat.hit_circle(self, global_position, BossCombat.r(p, 300.0), dmg)
		"gd_lure_trap":
			# 화면 임의 3지점 — MVP: 플레이어 위치 폭발 1회.
			BossCombat.hit_circle(self, BossCombat.player_pos(self), BossCombat.r(p, 80.0), dmg)
		"gd_line_charge":
			BossCombat.hit_line_forward(self, BossCombat.r(p, 45.0) * 2.0, BossCombat.l(p, 600.0), dmg)
		"gd_tusk", "gd_tusk_p2":
			BossCombat.hit_cone_forward(self, BossCombat.r(p, 130.0), BossCombat.a(p, 90.0), dmg)
		"gd_coin_absorb":
			# 화면의 금화 흡수 + 보스 HP 회복. MVP: 일정량 회복 모사.
			current_hp = min(data.hp, current_hp + 200)
		"gd_spin_charge":
			# 곡선 돌진(궤적 폭 110px) — MVP: 정면 직선 광역.
			BossCombat.hit_line_forward(self, 110.0, BossCombat.l(p, 480.0), dmg)
		"gd_shockwave":
			# 동심원 3겹(160/260/360) — MVP: 합산 광역.
			BossCombat.hit_circle(self, global_position, 360.0, dmg)
		_:
			BossCombat.dispatch_by_shape(self, p, dmg)
