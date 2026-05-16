extends BossBase

# B04 천둥장군 — 황금 갑주의 뇌신. 3페이즈(망치/뇌격/폭풍).
# 패턴: 망치 내려치기, 충격파, 도약 강하, 뇌격 투창, 낙뢰 격자, 정전기 장판, 호밍 뇌구,
#       회전 망치, 폭풍 강림, 풍백·우사 소환, 천둥 직선, 회전 망치(강), 분노 낙뢰.

const _ARMOR_GOLD: Color = Color(0.86, 0.70, 0.22, 0.95)
const _ARMOR_BLUE: Color = Color(0.55, 0.62, 0.95, 0.95)
const _ARMOR_STORM: Color = Color(0.30, 0.30, 0.60, 0.95)
const _HALO_BLUE: Color = Color(0.55, 0.80, 1.00, 0.55)

var _body: Polygon2D
var _halo: Polygon2D


func _apply_data(d: BossData) -> void:
	var rx: float = float(max(44, int(d.sprite_size_px.x / 2)))
	var ry: float = float(max(56, int(d.sprite_size_px.y / 2)))
	_halo = BossCombat.make_disc(_HALO_BLUE, max(rx, ry) * 1.3)
	_halo.name = "ThunderHalo"
	add_child(_halo)
	_body = BossCombat.make_rect(_ARMOR_GOLD, rx * 2.0, ry * 2.0)
	_body.name = "ThunderBody"
	add_child(_body)


func _on_phase_transition_completed(new_index: int) -> void:
	if _body == null:
		return
	if new_index == 1:
		_body.color = _ARMOR_BLUE
	elif new_index >= 2:
		_body.color = _ARMOR_STORM
		if _halo != null:
			_halo.scale = Vector2(1.4, 1.4)


func _execute_pattern(p: BossPattern) -> void:
	var dmg: int = BossCombat.resolve_damage(p, current_phase)
	match String(p.id):
		"th_hammer":
			# 망치 내려치기 — 보스 중심 원형.
			BossCombat.hit_circle(self, global_position, BossCombat.r(p, 160.0), dmg)
		"th_shockwave":
			# 충격파 — 도넛(내반경 160 / 외반경 320).
			BossCombat.hit_donut(self, global_position, 160.0, BossCombat.r(p, 320.0), dmg)
		"th_jump_smash":
			# 도약 강하 — 플레이어 위치 착지점 원형.
			BossCombat.hit_circle(self, BossCombat.player_pos(self), BossCombat.r(p, 180.0), dmg)
		"th_thunder_spear":
			# 뇌격 투창 — 정면 직선(폭 60px, 사거리 700px).
			BossCombat.hit_line_forward(self, 60.0, 700.0, dmg)
		"th_lightning_grid":
			# 낙뢰 격자 — 플레이어 위치 + 좌우 ±100 격자점 3개.
			var pp: Vector2 = BossCombat.player_pos(self)
			var r_grid: float = BossCombat.r(p, 50.0)
			BossCombat.hit_circle(self, pp, r_grid, dmg)
			BossCombat.hit_circle(self, pp + Vector2(-100, 0), r_grid, dmg)
			BossCombat.hit_circle(self, pp + Vector2(100, 0), r_grid, dmg)
		"th_static_field":
			# 정전기 장판 — 보스 중심 원형 + 플레이어 둔화.
			BossCombat.hit_circle(self, global_position, BossCombat.r(p, 80.0), dmg)
			_apply_player_slow(0.8, 6.0)
		"th_homing_bolt":
			# 호밍 뇌구 2발 — MVP: 플레이어 위치 광역 + 보스 정면 광역.
			BossCombat.hit_circle(self, BossCombat.player_pos(self), 80.0, dmg)
			BossCombat.hit_circle(self, global_position + BossCombat.facing(self) * 120.0, 80.0, dmg)
		"th_rotating_hammer":
			BossCombat.hit_circle(self, global_position, BossCombat.r(p, 200.0), dmg)
		"th_storm":
			# 폭풍 강림 — 1초 간격 3회 화면 광역.
			BossCombat.hit_screen(dmg)
			BossCombat.hit_screen(dmg)
			BossCombat.hit_screen(dmg)
		"th_summon_pungwoo":
			# 풍백·우사 소환 — 데미지 0. 소환은 외부 시스템 위임.
			return
		"th_thunder_line":
			BossCombat.hit_line_forward(self, BossCombat.r(p, 35.0) * 2.0, BossCombat.l(p, 1200.0), dmg)
		"th_rotating_hammer_p3":
			BossCombat.hit_circle(self, global_position, BossCombat.r(p, 240.0), dmg)
		"th_wrath_lightning":
			# 분노 낙뢰 — 화면 전체 광역.
			BossCombat.hit_screen(dmg)
		_:
			BossCombat.dispatch_by_shape(self, p, dmg)


func _apply_player_slow(factor: float, duration: float) -> void:
	var t: Node = get_tree().get_first_node_in_group("player")
	if t != null and t.has_method("apply_slow"):
		t.call("apply_slow", factor, duration)
