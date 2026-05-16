extends BossBase

# B06 장난꾸러기 대왕 도깨비 — 도깨비 시장 대왕. 3페이즈(방망이/축제/가면 광기).
# 패턴: 방망이 변신(칼/망치/부채), 주사위 룰렛, 빙글 점멸, 축제 폭죽, 미니게임(씨름/윷놀이),
#       도깨비방망이 회오리, 가면(분노/환희/혼돈), 도깨비 시장 붕괴, 빙글 점멸(강), 방망이 변신(랜덤).

const _MASK_RED: Color = Color(0.78, 0.18, 0.22, 0.95)
const _MASK_FESTIVAL: Color = Color(0.95, 0.55, 0.18, 0.95)
const _MASK_CHAOS: Color = Color(0.55, 0.18, 0.78, 0.95)
const _BODY_COLOR: Color = Color(0.40, 0.22, 0.55, 0.95)

var _body: Polygon2D
var _mask: Polygon2D
var _active_mask: StringName = &""  # P3에서 장착 중인 가면.


func _apply_data(d: BossData) -> void:
	var rx: float = float(max(44, int(d.sprite_size_px.x / 2)))
	var ry: float = float(max(56, int(d.sprite_size_px.y / 2)))
	_body = BossCombat.make_rect(_BODY_COLOR, rx * 2.0, ry * 2.0)
	_body.name = "DaewangBody"
	add_child(_body)
	_mask = BossCombat.make_disc(_MASK_RED, rx * 0.6)
	_mask.name = "DaewangMask"
	_mask.position = Vector2(0, -ry * 0.5)
	add_child(_mask)


func _on_phase_transition_completed(new_index: int) -> void:
	if _mask == null:
		return
	if new_index == 1:
		_mask.color = _MASK_FESTIVAL
	elif new_index >= 2:
		_mask.color = _MASK_CHAOS


func _execute_pattern(p: BossPattern) -> void:
	var dmg: int = BossCombat.resolve_damage(p, current_phase)
	match String(p.id):
		"dw_sword":
			# 방망이 — 칼: 직선 베기 폭 60px / 사거리 500px.
			BossCombat.hit_line_forward(self, 60.0, BossCombat.l(p, 500.0), dmg)
		"dw_hammer":
			# 방망이 — 망치: 근접 원형 반경 160px.
			BossCombat.hit_circle(self, global_position, BossCombat.r(p, 160.0), dmg)
		"dw_fan":
			# 방망이 — 부채: 정면 부채꼴 130도, 반경 320px.
			BossCombat.hit_cone_forward(self, 320.0, BossCombat.a(p, 130.0), dmg)
		"dw_dice":
			# 주사위 룰렛 — 1~6 결과 무작위 적용.
			_roll_dice(p)
		"dw_blink":
			# 빙글 점멸 — 위치만 변경, 데미지 없음.
			_blink_random(180.0)
			return
		"dw_firework":
			# 축제 폭죽 — 임의 8지점. MVP: 보스 중심 360도 8방향 원형.
			var r_fw: float = BossCombat.r(p, 90.0)
			for i in 8:
				var ang: float = TAU * float(i) / 8.0
				var off: Vector2 = Vector2(cos(ang), sin(ang)) * 200.0
				BossCombat.hit_circle(self, global_position + off, r_fw, dmg)
		"dw_minigame_ssireum":
			# 미니게임 — 씨름: MVP는 자동 실패 페널티 적용(달성 UI 미구현).
			BossCombat.deal(dmg)
		"dw_minigame_yut":
			# 미니게임 — 윷놀이: MVP는 자동 "도" 결과 → 소량 데미지.
			BossCombat.deal(dmg)
		"dw_club_spin":
			# 도깨비방망이 회오리 — 보스 중심 반경 220px.
			BossCombat.hit_circle(self, global_position, BossCombat.r(p, 220.0), dmg)
		"dw_mask_rage":
			# 가면 — 분노: 근접 +30% / 빈도 +20%. MVP: idle 단축 + damage_mult 가산.
			_active_mask = &"rage"
			if _mask != null:
				_mask.color = _MASK_RED
			if current_phase != null:
				current_phase.idle_min_s = max(0.2, current_phase.idle_min_s * 0.83)
				current_phase.idle_max_s = max(0.4, current_phase.idle_max_s * 0.83)
				current_phase.damage_mult = max(1.0, current_phase.damage_mult * 1.30)
			return
		"dw_mask_joy":
			# 가면 — 환희: 모든 패턴 + 폭죽 1발(반경 80px) 동반.
			_active_mask = &"joy"
			if _mask != null:
				_mask.color = _MASK_FESTIVAL
			BossCombat.hit_circle(self, BossCombat.player_pos(self), 80.0, 20)
			return
		"dw_mask_chaos":
			# 가면 — 혼돈: 모든 패턴 텔레그래프 -50%.
			_active_mask = &"chaos"
			if _mask != null:
				_mask.color = _MASK_CHAOS
			# 큐의 텔레그래프 시간을 절반으로 축소 — MVP 표면.
			if current_phase != null:
				for q in current_phase.pattern_queue:
					if q != null:
						q.telegraph_duration_s = max(0.1, q.telegraph_duration_s * 0.5)
			return
		"dw_market_collapse":
			# 도깨비 시장 붕괴 — 8발 직선 파편. MVP: 보스 중심 광역.
			BossCombat.hit_circle(self, global_position, 280.0, dmg)
		"dw_blink_p3":
			# 빙글 점멸(강) — 위치 변경 + 종료 시 반경 100 원형.
			_blink_random(140.0)
			BossCombat.hit_circle(self, global_position, BossCombat.r(p, 100.0), dmg)
		"dw_random_morph":
			# 방망이 변신 — 랜덤(칼/망치/부채 중 1).
			var pick: int = randi() % 3
			if pick == 0:
				BossCombat.hit_line_forward(self, 60.0, 500.0, dmg)
			elif pick == 1:
				BossCombat.hit_circle(self, global_position, 160.0, dmg)
			else:
				BossCombat.hit_cone_forward(self, 320.0, 130.0, dmg)
		_:
			BossCombat.dispatch_by_shape(self, p, dmg)


func _roll_dice(p: BossPattern) -> void:
	var face: int = (randi() % 6) + 1
	match face:
		1:
			# 보스 HP +500 회복.
			current_hp = min(data.hp, current_hp + 500)
		2:
			# 플레이어 이속 -30% (5s).
			_apply_player_slow(0.7, 5.0)
		3:
			# 360도 8발 투사체 — MVP: 보스 중심 광역.
			var d3: int = max(1, int(p.damage if p.damage > 0 else 22))
			BossCombat.hit_circle(self, global_position, 200.0, d3)
		4:
			# 보스 5초간 방어력 +10.
			if data != null:
				data.armor += 10
				get_tree().create_timer(5.0).timeout.connect(func() -> void:
					if data != null:
						data.armor = max(0, data.armor - 10))
		5:
			# 플레이어 5초간 받는 피해 +20% — MVP: 둔화로 표면 대체.
			_apply_player_slow(0.85, 5.0)
		6:
			# 플레이어 5초간 받는 피해 -20% (보스 자해) — MVP: 보스가 소량 자해.
			current_hp = max(1, current_hp - 200)


func _blink_random(radius: float) -> void:
	var pp: Vector2 = BossCombat.player_pos(self)
	var ang: float = randf() * TAU
	var off: Vector2 = Vector2(cos(ang), sin(ang)) * radius
	global_position = pp + off


func _apply_player_slow(factor: float, duration: float) -> void:
	var t: Node = get_tree().get_first_node_in_group("player")
	if t != null and t.has_method("apply_slow"):
		t.call("apply_slow", factor, duration)
