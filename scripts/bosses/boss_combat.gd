class_name BossCombat
extends RefCounted

# 보스 11종 공통 판정/시각 헬퍼. boss_<slug>.gd 들이 정적 함수로 호출한다.
# 본 파일은 신규 — 기존 보스 관련 파일을 건드리지 않으면서 보스 스크립트 중복을 줄인다.


static func player_pos(boss: Node2D) -> Vector2:
	var t: Node = boss.get_tree().get_first_node_in_group("player")
	if t is Node2D:
		return (t as Node2D).global_position
	return boss.global_position


static func facing(boss: Node2D) -> Vector2:
	var d: Vector2 = player_pos(boss) - boss.global_position
	if d.length_squared() < 0.0001:
		return Vector2.RIGHT
	return d.normalized()


static func resolve_damage(p: BossPattern, phase: BossPhase) -> int:
	var mult: float = phase.damage_mult if phase != null else 1.0
	return max(0, int(round(float(p.damage) * mult)))


static func r(p: BossPattern, fallback: float) -> float:
	return p.hitbox_radius_px if p.hitbox_radius_px > 0.0 else fallback


static func l(p: BossPattern, fallback: float) -> float:
	return p.hitbox_length_px if p.hitbox_length_px > 0.0 else fallback


static func a(p: BossPattern, fallback: float) -> float:
	return p.hitbox_angle_deg if p.hitbox_angle_deg > 0.0 else fallback


static func deal(dmg: int) -> void:
	if dmg <= 0:
		return
	if GameState != null and GameState.has_method("deal_damage_to_player"):
		GameState.deal_damage_to_player(dmg, &"boss_pattern")


static func hit_circle(boss: Node2D, center: Vector2, radius: float, dmg: int) -> void:
	if dmg <= 0:
		return
	if player_pos(boss).distance_to(center) <= radius:
		deal(dmg)


static func hit_donut(boss: Node2D, center: Vector2, inner: float, outer: float, dmg: int) -> void:
	if dmg <= 0:
		return
	var d: float = player_pos(boss).distance_to(center)
	if d >= inner and d <= outer:
		deal(dmg)


static func hit_line_forward(boss: Node2D, width: float, length: float, dmg: int) -> void:
	if dmg <= 0:
		return
	var dir: Vector2 = facing(boss)
	var to_p: Vector2 = player_pos(boss) - boss.global_position
	var along: float = to_p.dot(dir)
	var perp: float = absf(to_p.dot(Vector2(-dir.y, dir.x)))
	if along >= 0.0 and along <= length and perp <= width * 0.5:
		deal(dmg)


static func hit_line_from(boss: Node2D, origin: Vector2, dir: Vector2, width: float, length: float, dmg: int) -> void:
	if dmg <= 0:
		return
	var to_p: Vector2 = player_pos(boss) - origin
	var nd: Vector2 = dir.normalized() if dir.length_squared() > 0.0 else Vector2.RIGHT
	var along: float = to_p.dot(nd)
	var perp: float = absf(to_p.dot(Vector2(-nd.y, nd.x)))
	if along >= 0.0 and along <= length and perp <= width * 0.5:
		deal(dmg)


static func hit_cone_forward(boss: Node2D, radius: float, angle_deg: float, dmg: int) -> void:
	_cone(boss, facing(boss), radius, angle_deg, dmg)


static func hit_cone_back(boss: Node2D, radius: float, angle_deg: float, dmg: int) -> void:
	_cone(boss, -facing(boss), radius, angle_deg, dmg)


static func hit_cone_dir(boss: Node2D, dir: Vector2, radius: float, angle_deg: float, dmg: int) -> void:
	_cone(boss, dir, radius, angle_deg, dmg)


static func _cone(boss: Node2D, dir: Vector2, radius: float, angle_deg: float, dmg: int) -> void:
	if dmg <= 0:
		return
	var to_p: Vector2 = player_pos(boss) - boss.global_position
	if to_p.length() > radius:
		return
	var nd: Vector2 = dir.normalized() if dir.length_squared() > 0.0 else Vector2.RIGHT
	var ang: float = absf(rad_to_deg(to_p.angle_to(nd)))
	if ang <= angle_deg * 0.5:
		deal(dmg)


static func hit_screen(dmg: int) -> void:
	deal(dmg)


# 모양 미지정/일반 케이스에 쓰는 fallback 디스패치.
static func dispatch_by_shape(boss: Node2D, p: BossPattern, dmg: int) -> void:
	match int(p.shape):
		GameEnums.PatternShape.CIRCLE_AOE:
			hit_circle(boss, boss.global_position, r(p, 100.0), dmg)
		GameEnums.PatternShape.LINE_AOE, GameEnums.PatternShape.PROJECTILE_STRAIGHT:
			hit_line_forward(boss, r(p, 40.0) * 2.0, l(p, 320.0), dmg)
		GameEnums.PatternShape.CONE_AOE:
			hit_cone_forward(boss, r(p, 100.0), a(p, 90.0), dmg)
		GameEnums.PatternShape.SCREEN_AOE:
			hit_screen(dmg)
		GameEnums.PatternShape.MELEE_LUNGE:
			hit_circle(boss, boss.global_position, r(p, 100.0), dmg)
		GameEnums.PatternShape.PROJECTILE_BARRAGE:
			# 다탄 — 보스 중심 원형 광역으로 근사.
			hit_circle(boss, boss.global_position, r(p, 140.0), dmg)
		GameEnums.PatternShape.PROJECTILE_HOMING:
			# 호밍 — 플레이어 위치 근처 광역으로 근사.
			hit_circle(boss, player_pos(boss), r(p, 80.0), dmg)
		_:
			pass


# === 시각 헬퍼 ===

static func make_disc(color: Color, radius: float) -> Polygon2D:
	var poly: Polygon2D = Polygon2D.new()
	poly.color = color
	var pts: PackedVector2Array = PackedVector2Array()
	var segs: int = 24
	for i in segs:
		var ang: float = TAU * float(i) / float(segs)
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	poly.polygon = pts
	return poly


static func make_ellipse(color: Color, rx: float, ry: float) -> Polygon2D:
	var poly: Polygon2D = Polygon2D.new()
	poly.color = color
	var pts: PackedVector2Array = PackedVector2Array()
	var segs: int = 28
	for i in segs:
		var ang: float = TAU * float(i) / float(segs)
		pts.append(Vector2(cos(ang) * rx, sin(ang) * ry))
	poly.polygon = pts
	return poly


static func make_rect(color: Color, w: float, h: float) -> Polygon2D:
	var poly: Polygon2D = Polygon2D.new()
	poly.color = color
	poly.polygon = PackedVector2Array([
		Vector2(-w * 0.5, -h * 0.5),
		Vector2(w * 0.5, -h * 0.5),
		Vector2(w * 0.5, h * 0.5),
		Vector2(-w * 0.5, h * 0.5),
	])
	return poly
