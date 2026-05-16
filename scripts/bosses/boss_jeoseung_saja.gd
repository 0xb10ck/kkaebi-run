extends BossBase

# B03 저승사자 — 검은 도포 명부의 사령. 3페이즈(명부 기록/사령 호출/명부 개방).
# 패턴: 명부 기록, 기록 처형, 사슬 던지기, 갓 베기, 망령 호출, 명부 낙뢰, 점멸 베기, 명부 개방,
#       즉사 게이지, 망령 폭풍, 점멸 베기(강).

const _ROBE_BLACK: Color = Color(0.08, 0.06, 0.10, 0.95)
const _HAT_RIM: Color = Color(0.04, 0.03, 0.06, 0.95)
const _GLOW_PURPLE: Color = Color(0.30, 0.10, 0.40, 0.95)

var _body: Polygon2D
var _record_count: int = 0          # P1 명부 기록 누적.
var _death_meter_pct: float = 0.0   # P3 즉사 게이지(0~100).


func _apply_data(d: BossData) -> void:
	var rx: float = float(max(28, int(d.sprite_size_px.x / 2)))
	var ry: float = float(max(44, int(d.sprite_size_px.y / 2)))
	_body = BossCombat.make_rect(_ROBE_BLACK, rx * 2.0, ry * 2.0)
	_body.name = "JeoseungSajaRobe"
	add_child(_body)
	var hat: Polygon2D = BossCombat.make_rect(_HAT_RIM, rx * 2.4, ry * 0.3)
	hat.name = "JeoseungSajaHat"
	hat.position = Vector2(0, -ry * 0.95)
	add_child(hat)


func _on_phase_transition_completed(new_index: int) -> void:
	if _body == null:
		return
	if new_index == 1:
		# 갓 벗고 머리카락 검은 안개 — 색감 약간 변화.
		_body.color = Color(0.12, 0.08, 0.16, 0.95)
	elif new_index >= 2:
		_body.color = _GLOW_PURPLE
		_death_meter_pct = 0.0


func _execute_pattern(p: BossPattern) -> void:
	var dmg: int = BossCombat.resolve_damage(p, current_phase)
	match String(p.id):
		"js_record":
			# 패시브 기록. MVP: 발동 시 누적 +1, 5 이상이면 처형 트리거 준비.
			_record_count = min(5, _record_count + 1)
			return
		"js_execute":
			# 기록 처형 — 플레이어 위치 반경 120 원형.
			if _record_count < 5:
				return
			BossCombat.hit_circle(self, BossCombat.player_pos(self), BossCombat.r(p, 120.0), dmg)
			_record_count = 0
		"js_chain", "js_chain_p2":
			BossCombat.hit_line_forward(self, BossCombat.r(p, 36.0) * 2.0, BossCombat.l(p, 600.0), dmg)
		"js_hat_slash":
			BossCombat.hit_cone_forward(self, BossCombat.r(p, 110.0), BossCombat.a(p, 130.0), dmg)
		"js_ghost_call":
			# 망령 4체 소환 — MVP: 보스 주변 접근 광역.
			BossCombat.hit_circle(self, global_position, 80.0, dmg)
		"js_thunder":
			# 검은 원 3지점 — MVP: 플레이어 위치 광역.
			BossCombat.hit_circle(self, BossCombat.player_pos(self), BossCombat.r(p, 100.0), dmg)
		"js_blink_slash", "js_blink_slash_p3":
			var pp: Vector2 = BossCombat.player_pos(self)
			var dir_to_p: Vector2 = (pp - global_position).normalized()
			global_position = pp - dir_to_p * 80.0
			BossCombat.hit_cone_dir(self, dir_to_p, BossCombat.r(p, 130.0), BossCombat.a(p, 90.0), dmg)
		"js_book_open":
			# 명부 개방 — 화면 광역.
			BossCombat.hit_screen(dmg)
		"js_death_meter":
			# 즉사 게이지 증가. 가득 차면 350 데미지 사명 발동.
			_death_meter_pct = min(100.0, _death_meter_pct + 15.0)
			if _death_meter_pct >= 100.0:
				BossCombat.deal(max(1, int(p.damage)))
				_death_meter_pct = 0.0
		"js_ghost_storm":
			BossCombat.hit_circle(self, global_position, BossCombat.r(p, 300.0), dmg)
		_:
			BossCombat.dispatch_by_shape(self, p, dmg)
