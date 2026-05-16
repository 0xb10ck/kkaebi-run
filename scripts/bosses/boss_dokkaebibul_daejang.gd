extends BossBase

# B01 도깨비불 대장 — 푸른 화염 구체. 3페이즈(잔불 통제/화염 폭주/마지막 등롱).
# 패턴: 잔불 부하 소환, 푸른 화구 3연사, 등롱 흔들기, 접촉 점화, 화염의 길, 도약 점화, 화구 5연사,
#       마지막 등롱, 추적 화구, 화염 회전, 분노 폭발.

const _FLAME_BLUE: Color = Color(0.24, 0.80, 1.00, 0.95)
const _FLAME_VIOLET: Color = Color(0.45, 0.50, 1.00, 0.95)
const _FLAME_WHITE: Color = Color(0.85, 0.95, 1.00, 0.95)

var _core: Polygon2D


func _apply_data(d: BossData) -> void:
	var radius: float = float(max(40, int(d.sprite_size_px.x / 2)))
	_core = BossCombat.make_disc(_FLAME_BLUE, radius)
	_core.name = "FlameCore"
	add_child(_core)


func _on_phase_transition_completed(new_index: int) -> void:
	if _core == null:
		return
	if new_index == 1:
		_core.color = _FLAME_VIOLET
		position.y -= 60.0
	elif new_index >= 2:
		_core.color = _FLAME_WHITE


func _execute_pattern(p: BossPattern) -> void:
	var dmg: int = BossCombat.resolve_damage(p, current_phase)
	match String(p.id):
		"dl_minion_summon":
			# 부하 3마리 소환 — MVP: 보스 주변 접근 광역 모사.
			BossCombat.hit_circle(self, global_position, 60.0, dmg)
		"dl_fireball_3":
			# 직선 화구 3발 — MVP: 정면 직선 길이 600.
			BossCombat.hit_line_forward(self, 80.0, 600.0, dmg)
		"dl_lantern_swing":
			BossCombat.hit_circle(self, global_position, BossCombat.r(p, 160.0), dmg)
		"dl_contact_ignite", "dl_contact_ignite_p2":
			# 단일 접촉 + 화상 도트. MVP: 근접 90px 단일 + 도트는 향후 작업.
			var range_px: float = 90.0 if String(p.id) == "dl_contact_ignite" else 100.0
			BossCombat.hit_circle(self, global_position, range_px, dmg)
		"dl_fire_path":
			# 십자/Y자 직선 3개 — MVP: 정면 길이 600 직선.
			BossCombat.hit_line_forward(self, BossCombat.r(p, 30.0) * 2.0, 600.0, dmg)
		"dl_jump_ignite":
			# 도약 점화 — 착지점 반경 + 잔여 화염 장판.
			var pp: Vector2 = BossCombat.player_pos(self)
			global_position = pp
			BossCombat.hit_circle(self, pp, BossCombat.r(p, 120.0), dmg)
		"dl_fan_5":
			# 부채꼴 60도 5발 — MVP: 부채꼴 광역.
			BossCombat.hit_cone_forward(self, 600.0, 60.0, dmg)
		"dl_final_lantern":
			BossCombat.hit_screen(dmg)
		"dl_homing_fire":
			# 호밍 화구 2발 — MVP: 플레이어 위치 광역.
			BossCombat.hit_circle(self, BossCombat.player_pos(self), 80.0, dmg)
		"dl_fire_rotation":
			# 8갈래 직선 회전 — MVP: 보스 중심 반경 200 광역.
			BossCombat.hit_circle(self, global_position, BossCombat.r(p, 200.0), dmg)
		"dl_wrath_burst":
			BossCombat.hit_circle(self, global_position, BossCombat.r(p, 360.0), dmg)
		_:
			BossCombat.dispatch_by_shape(self, p, dmg)
