extends BossBase

# B02 구미호 — 흰 한복 여인 → 9꼬리 → 거대 여우. 3페이즈.
# 패턴: 여우불 3연사, 꼬리 회전, 분신 소환, 점멸 회피, 매혹의 시선, 9꼬리 탄막, 순간이동 후방 베기,
#       거대 꼬리 휩쓸기, 광역 매혹 + 폭격, 꼬리 9발 강화, 최후의 돌진, 컷오프 물기.

const _ROBE_WHITE: Color = Color(0.96, 0.94, 0.92, 0.95)
const _ROBE_PINK: Color = Color(0.95, 0.65, 0.78, 0.95)
const _FUR_WHITE: Color = Color(0.98, 0.96, 0.94, 0.95)

var _body: Polygon2D


func _apply_data(d: BossData) -> void:
	var rx: float = float(max(28, int(d.sprite_size_px.x / 2)))
	var ry: float = float(max(40, int(d.sprite_size_px.y / 2)))
	_body = BossCombat.make_ellipse(_ROBE_WHITE, rx, ry)
	_body.name = "GumihoBody"
	add_child(_body)


func _on_phase_transition_completed(new_index: int) -> void:
	if _body == null:
		return
	if new_index == 1:
		_body.color = _ROBE_PINK
	elif new_index >= 2:
		# P3 거대 여우 변신 — 외형 2.4배 확대 + 흰 털 색.
		_body.color = _FUR_WHITE
		_body.scale = Vector2(2.4, 1.5)


func _execute_pattern(p: BossPattern) -> void:
	var dmg: int = BossCombat.resolve_damage(p, current_phase)
	match String(p.id):
		"gh_foxfire_3":
			# 호밍 화구 3발 — MVP: 플레이어 위치 광역 1회.
			BossCombat.hit_circle(self, BossCombat.player_pos(self), 80.0, dmg)
		"gh_tail_spin", "gh_tail_spin_p2":
			BossCombat.hit_circle(self, global_position, BossCombat.r(p, 120.0), dmg)
		"gh_clone":
			# 분신 2체 — MVP: 좌우 광역.
			BossCombat.hit_circle(self, global_position + Vector2(-80, 0), 40.0, dmg)
			BossCombat.hit_circle(self, global_position + Vector2(80, 0), 40.0, dmg)
		"gh_blink":
			# 점멸 회피 — 위치만 변경, 데미지 없음.
			var pp: Vector2 = BossCombat.player_pos(self)
			var off: Vector2 = Vector2(randf_range(-200.0, 200.0), randf_range(-200.0, 200.0))
			global_position = pp + off
			return
		"gh_charm_field":
			# 매혹 장판 3지점 — MVP: 화면 광역 디버프 표면(데미지 0 + slow).
			_apply_player_slow(0.7, 3.0)
		"gh_tail_9", "gh_tail_barrage":
			# 9갈래 직선 — MVP: 보스 중심 큰 광역.
			BossCombat.hit_circle(self, global_position, 180.0, dmg)
		"gh_teleport_slash":
			# 등 뒤 80px 점멸 + 부채꼴 베기.
			var pp2: Vector2 = BossCombat.player_pos(self)
			var dir_to_p: Vector2 = (pp2 - global_position).normalized()
			global_position = pp2 - dir_to_p * 80.0
			BossCombat.hit_cone_dir(self, dir_to_p, BossCombat.r(p, 110.0), BossCombat.a(p, 90.0), dmg)
		"gh_giant_sweep":
			BossCombat.hit_cone_forward(self, BossCombat.r(p, 360.0), BossCombat.a(p, 200.0), dmg)
		"gh_charm_bomb":
			# 매혹 + 화구 4발 — MVP: 화면 광역 + 디버프.
			BossCombat.hit_screen(dmg)
			_apply_player_slow(0.7, 3.0)
		"gh_final_charge":
			# 최후의 돌진 — 화면 끝→끝, 폭 200px.
			BossCombat.hit_line_forward(self, 200.0, 1200.0, dmg)
		"gh_bite":
			BossCombat.hit_cone_forward(self, BossCombat.r(p, 220.0), BossCombat.a(p, 60.0), dmg)
		_:
			BossCombat.dispatch_by_shape(self, p, dmg)


func _apply_player_slow(factor: float, duration: float) -> void:
	var t: Node = get_tree().get_first_node_in_group("player")
	if t != null and t.has_method("apply_slow"):
		t.call("apply_slow", factor, duration)
