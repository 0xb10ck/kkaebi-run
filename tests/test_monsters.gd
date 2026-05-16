extends SceneTree

# tests/test_monsters.gd — 53종 일반 몬스터(M01..M53) 동작 스모크 테스트 (Godot 4 headless)
# 실행:
#   godot --headless --path /Users/0xb10ck/kkaebi-run --script tests/test_monsters.gd
#
# 검증 항목 (몬스터당):
#   각 몬스터 씬을 load + instantiate → SceneTree에 add → 60 physics tick 진행 후
#     (a) global_position이 초기값 대비 변화 (>= MOVE_THRESHOLD_PX)
#     (b) attack 이 발생 — stub player의 take_damage 호출 OR
#                       EnemyBase._contact_timer > 0 OR
#                       _physics_process 동안 root 자식 수 증가(투사체/이펙트 스폰)
#   둘 중 하나만 충족하면 PASS. 둘 다 미충족이면 FAIL.
#
# 하나라도 실패하면 exit code 1로 종료한다.
# push_error 는 SCRIPT ERROR 로 집계되므로 print() 만 사용한다.


const SCENES_DIR := "res://scenes/enemies"
const MONSTER_COUNT := 53
const PHYSICS_TICKS := 60
const MOVE_THRESHOLD_PX := 1.0

# 몬스터 ID → 씬 파일명 매핑 (m01..m53). 디렉토리 정렬과 동일.
const MONSTER_FILES: Array[String] = [
	"m01_dokkaebibul.tscn",
	"m02_dalgyalgwisin.tscn",
	"m03_mulgwisin.tscn",
	"m04_eodukshini.tscn",
	"m05_geuseundae.tscn",
	"m06_bitjarugwisin.tscn",
	"m07_songakshi.tscn",
	"m08_mongdalgwisin.tscn",
	"m09_duduri.tscn",
	"m10_samdugu.tscn",
	"m11_horangi.tscn",
	"m12_metdwaeji.tscn",
	"m13_neoguri.tscn",
	"m14_dukkeobi.tscn",
	"m15_geomi.tscn",
	"m16_noru.tscn",
	"m17_namu.tscn",
	"m18_deonggul.tscn",
	"m19_kamagwi.tscn",
	"m20_cheonyeo_gwisin.tscn",
	"m21_jeoseung_gae.tscn",
	"m22_mangryang.tscn",
	"m23_gangshi.tscn",
	"m24_yagwang_gwi.tscn",
	"m25_baekgol_gwi.tscn",
	"m26_gaeksahon.tscn",
	"m27_saseul_gwi.tscn",
	"m28_dochaebi.tscn",
	"m29_chasahon.tscn",
	"m30_bulgasari.tscn",
	"m31_yacha.tscn",
	"m32_nachal.tscn",
	"m33_cheonnyeo.tscn",
	"m34_noegong.tscn",
	"m35_pungbaek.tscn",
	"m36_usa.tscn",
	"m37_hak.tscn",
	"m38_gareungbinga.tscn",
	"m39_cheonma.tscn",
	"m40_heukpung.tscn",
	"m41_bihyeongrang_grimja.tscn",
	"m42_heukmusa.tscn",
	"m43_yeonggwi.tscn",
	"m44_grimja_dokkaebi.tscn",
	"m45_ohyeomdoen_shinmok_gaji.tscn",
	"m46_heukryong_saekki.tscn",
	"m47_geomeun_angae_jamyeong.tscn",
	"m48_sijang_dokkaebi.tscn",
	"m49_geokkuro_dokkaebi.tscn",
	"m50_noreumkkun.tscn",
	"m51_sulchwihan.tscn",
	"m52_byeonjang.tscn",
	"m53_ssireum.tscn",
]


var errors: Array[String] = []
var passes: int = 0
var results: Array[Dictionary] = []


func _initialize() -> void:
	# 자동로드(_ready)가 마치도록 한 프레임 양보.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	if MONSTER_FILES.size() != MONSTER_COUNT:
		_record_fail("setup", "MONSTER_FILES.size() %d != %d" % [MONSTER_FILES.size(), MONSTER_COUNT])
		_finish()
		return

	for f in MONSTER_FILES:
		await _test_one(f)

	_finish()


func _finish() -> void:
	_print_summary()
	quit(0 if errors.is_empty() else 1)


# ────────────────────────────────────────────────────────────────────────────
# 1종 검증
# ────────────────────────────────────────────────────────────────────────────
func _test_one(file_name: String) -> void:
	var label := file_name.get_basename()  # 예: "m01_dokkaebibul"
	var path := "%s/%s" % [SCENES_DIR, file_name]

	if not ResourceLoader.exists(path):
		_record_fail(label, "scene missing: %s" % path)
		return

	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_record_fail(label, "scene load failed: %s" % path)
		return

	# Stub 플레이어 (group "player" + take_damage 카운터).
	var stub: Node2D = _make_stub_player()
	stub.position = Vector2(200, 200)
	root.add_child(stub)

	var monster: Node = packed.instantiate()
	if monster == null:
		_record_fail(label, "instantiate failed: %s" % path)
		stub.queue_free()
		await process_frame
		return

	# 플레이어와 100px 떨어진 곳에 배치. 가까이 두면 첫 frame에 contact가 일어나면서 동시에
	# 이동 검출이 흐려질 수 있어, 둘 다 충분히 검출되도록 거리를 둔다.
	if monster is Node2D:
		(monster as Node2D).position = Vector2(300, 200)

	var initial_root_children: int = root.get_child_count()
	root.add_child(monster)
	# _ready + autoload 적용 한 프레임 대기.
	await physics_frame

	if not is_instance_valid(monster) or not monster.is_inside_tree():
		_record_fail(label, "monster not in tree after add_child")
		if is_instance_valid(stub):
			stub.queue_free()
		await process_frame
		return

	# 변장형 몬스터(M52 변장 도깨비) — 위장 중에는 스폰 후 정지·무공격이 의도된 거동이다.
	# reveal_trigger_on_hit 경로로 위장을 해제해 위장 해제 후 추격/광역 거동을 60 tick 안에 검증한다.
	# (피해량 1 은 disguise_damage_taken_mult(0.3) 적용 후 0 으로 절삭되어 HP 가 깎이지 않는다.)
	if "_is_revealed" in monster and not bool(monster.get("_is_revealed")) and monster.has_method("take_damage"):
		monster.call("take_damage", 1, null)

	var start_pos: Vector2 = Vector2.ZERO
	if monster is Node2D:
		start_pos = (monster as Node2D).global_position

	# 60 physics tick 진행. 도중에 monster가 queue_free 될 수도 있어 매 프레임 유효성 체크.
	for i in PHYSICS_TICKS:
		await physics_frame
		if not is_instance_valid(monster):
			break

	# 결과 수집.
	var end_pos: Vector2 = start_pos
	var contact_timer: float = 0.0
	if is_instance_valid(monster):
		if monster is Node2D:
			end_pos = (monster as Node2D).global_position
		if "_contact_timer" in monster:
			contact_timer = float(monster.get("_contact_timer"))
	var moved_px: float = (end_pos - start_pos).length()
	var moved: bool = moved_px >= MOVE_THRESHOLD_PX

	var damage_count: int = int(stub.get("damage_taken_count"))
	# stub은 add_child 시점에 root.get_child_count()를 1 증가시키므로,
	# monster 본체(add_child 후 +1)까지 더한 baseline 대비 추가 자식 = 새로 스폰된 노드.
	# initial_root_children 시점 = stub만 들어간 상태. monster add 후 +1.
	# 자식이 더 많아졌다면 monster가 무언가 스폰했다는 의미.
	var baseline_children: int = initial_root_children + 1
	# monster가 queue_free 되었더라도 그 자체로는 "attack"의 증거로 보지 않는다.
	var current_children: int = root.get_child_count()
	var spawned: bool = current_children > baseline_children + (0 if not is_instance_valid(monster) else 0)
	# 위 식은 monster가 살아있을 땐 baseline_children (stub+monster)와 비교,
	# 죽었을 땐 stub만 남은 상태와 비교해 너무 관대해질 수 있으므로 보정한다.
	if not is_instance_valid(monster):
		spawned = current_children > initial_root_children + 1  # stub만 남음 + 스폰된 자식
	var attack_seen: bool = damage_count > 0 or contact_timer > 0.0 or spawned

	var pass_ok: bool = moved or attack_seen
	var detail := "moved=%.2fpx attack(damage_hits=%d contact_timer=%.3f spawned_children=%s)" % [
		moved_px, damage_count, contact_timer, str(spawned)
	]

	results.append({
		"label": label,
		"pass": pass_ok,
		"detail": detail,
	})
	if pass_ok:
		passes += 1
		print("[MON] PASS — %s — %s" % [label, detail])
	else:
		_record_fail(label, detail)

	# 정리.
	if is_instance_valid(monster):
		monster.queue_free()
	if is_instance_valid(stub):
		stub.queue_free()
	# 한 프레임 + 한 physics_frame 으로 큐 정리 + 다음 테스트 격리.
	await process_frame
	await physics_frame


# ────────────────────────────────────────────────────────────────────────────
# Stub 플레이어 — "player" 그룹 + take_damage 카운터.
# EnemyBase._resolve_target() 가 grouped Node2D를 찾도록 한다.
# ────────────────────────────────────────────────────────────────────────────
func _make_stub_player() -> Node2D:
	var p := Node2D.new()
	p.name = "StubPlayer"
	p.add_to_group("player")
	# 동적 take_damage 메서드를 부여하기 위해 스크립트를 부착한다.
	var s := GDScript.new()
	s.source_code = """extends Node2D

var damage_taken_count: int = 0
var damage_taken_total: int = 0

func take_damage(amount: int) -> void:
	damage_taken_count += 1
	damage_taken_total += int(amount)
"""
	s.reload()
	p.set_script(s)
	return p


# ────────────────────────────────────────────────────────────────────────────
# 출력 헬퍼
# ────────────────────────────────────────────────────────────────────────────
func _record_fail(label: String, msg: String) -> void:
	var line := "[%s] %s" % [label, msg]
	errors.append(line)
	results.append({
		"label": label,
		"pass": false,
		"detail": msg,
	})
	print("[MON] FAIL — %s" % line)


func _print_summary() -> void:
	print("")
	print("[MON] ═══════════════════════════════════════════════")
	print("[MON] monsters tested: %d" % MONSTER_FILES.size())
	print("[MON] passes: %d  failures: %d" % [passes, errors.size()])
	if not errors.is_empty():
		print("[MON] failures:")
		for e in errors:
			print("[MON]   - %s" % e)
	print("[MON] result: %s" % ("PASS" if errors.is_empty() else "FAIL"))
	print("[MON] ═══════════════════════════════════════════════")
