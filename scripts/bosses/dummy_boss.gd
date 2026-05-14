extends BossBase

# §5 — 보스 아레나 동작 확인용 더미 보스. BossBase 페이즈 시스템(텔레그래프 → 1초 후 데미지)이
# 도는지를 시각적으로 확인할 수 있도록 _execute_pattern에서 즉시 데미지를 적용하는 1패턴 보장.

func _apply_data(_d: BossData) -> void:
	# 간단한 시각 표시 — 둥근 보스 원판.
	var visual: Polygon2D = Polygon2D.new()
	visual.name = "DummySprite"
	visual.color = Color(0.741, 0.314, 0.314, 0.95)
	var pts: PackedVector2Array = PackedVector2Array()
	var radius: float = float(max(20, _d.sprite_size_px.x / 2))
	var segs: int = 24
	for i in segs:
		var a: float = TAU * float(i) / float(segs)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	visual.polygon = pts
	add_child(visual)


func _execute_pattern(p: BossPattern) -> void:
	# 텔레그래프는 BossBase가 emit. 본 hook은 텔레그래프가 종료된 직후 즉시 데미지 판정.
	# MVP 단계에선 GameState에 직접 데미지를 가해 페이즈 전환 동작을 검증.
	var dmg: int = max(1, int(p.damage))
	if GameState != null and GameState.has_method("deal_damage_to_player"):
		GameState.deal_damage_to_player(dmg, &"boss_pattern")
	# 0.2s 판정 윈도우는 베이스가 설정 — 추가 처리 없음.
