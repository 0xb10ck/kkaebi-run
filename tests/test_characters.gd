extends SceneTree

# tests/test_characters.gd — 6종 캐릭터 검증 (Godot 4 headless)
# 실행:
#   godot --headless --path /Users/0xb10ck/kkaebi-run --script tests/test_characters.gd
#
# 검증 항목 (캐릭터당):
#   (a) stats(hp/speed/attack/attack_speed) 가 .tres 데이터 = 스펙(§0.3/§X.2)과 정확히 일치
#   (b) 시작 스킬 목록이 docs/characters-full-spec.md §X.5("시작 보유 스킬")와 일치
#       ※ Phase 1 본 테스트 기준 단일 소스 오브 트루스
#       ※ phase1-spec.md 는 뚝딱이(§1)만 다루므로, 6종 스펙은 characters-full-spec.md 를 사용
#   (c) Player 씬을 인스턴스화하여 _physics_process 를 일정 프레임 돌렸을 때
#       (c.1) position 변화(이동)
#       (c.2) attack 메서드 호출(공격) — Player.attack_timer 가 ATTACK_INTERVAL 도달 후
#             0 으로 리셋되는지로 _perform_attack() 호출을 감지
#
# push_error 는 SCRIPT ERROR 로 집계되므로 print() 만 사용한다.


const CHAR_DIR := "res://resources/characters"
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"

const MOVE_FRAMES := 30      # 약 0.5초 @ 60Hz
const ATTACK_FRAMES := 70    # 약 1.16초 — Player.ATTACK_INTERVAL(1.0s) 1회 초과
const PHYSICS_DT := 1.0 / 60.0
const MOVE_THRESHOLD_PX := 10.0

# docs/characters-full-spec.md §0.3, §X.2, §X.5 인용. 본 테스트의 기댓값 표.
# starting_skill_ids 는 §X.5 "시작 보유 스킬" — 뚝딱이는 §1.5 에 "시작 보유 스킬: 없음" 명시.
# 바라미 SU-02 '서리 칼날' 은 아직 resources/skills/ 에 .tres 파일이 없으므로
# 식별자만 "frost_blade" 로 가정한다(구현 갭, 시작 스킬 인코딩 필요).
const EXPECTED: Dictionary = {
	&"ttukttaki": {
		"display_name_ko": "뚝딱이",
		"base_hp": 100,
		"base_move_speed": 100.0,
		"base_attack": 10,
		"base_attack_speed": 1.0,
		"starting_skill_ids": [],
	},
	&"hwalee": {
		"display_name_ko": "화리",
		"base_hp": 85,
		"base_move_speed": 100.0,
		"base_attack": 12,
		"base_attack_speed": 0.9,
		"starting_skill_ids": [&"fire_orb"],          # 도깨비불 HWA-01
	},
	&"barami": {
		"display_name_ko": "바라미",
		"base_hp": 80,
		"base_move_speed": 125.0,
		"base_attack": 8,
		"base_attack_speed": 0.7,
		"starting_skill_ids": [&"frost_blade"],        # 서리 칼날 SU-02 (리소스 부재)
	},
	&"dolsoe": {
		"display_name_ko": "돌쇠",
		"base_hp": 150,
		"base_move_speed": 80.0,
		"base_attack": 9,
		"base_attack_speed": 1.3,
		"starting_skill_ids": [&"earth_wall"],         # 흙벽 TO-01
	},
	&"byeolee": {
		"display_name_ko": "별이",
		"base_hp": 90,
		"base_move_speed": 95.0,
		"base_attack": 9,
		"base_attack_speed": 1.0,
		"starting_skill_ids": [&"fire_orb"],           # 도깨비불 HWA-01
	},
	&"geurimja": {
		"display_name_ko": "그림자",
		"base_hp": 85,
		"base_move_speed": 110.0,
		"base_attack": 11,
		"base_attack_speed": 0.85,
		"starting_skill_ids": [&"dagger_throw"],       # 비수 투척 GE-02
	},
}


var errors: Array[String] = []
var passes: int = 0
var _player_scene: PackedScene


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	if not ResourceLoader.exists(PLAYER_SCENE_PATH):
		_fail("[setup] player scene missing: %s" % PLAYER_SCENE_PATH)
		_finish()
		return
	_player_scene = load(PLAYER_SCENE_PATH) as PackedScene
	if _player_scene == null:
		_fail("[setup] player scene load failed: %s" % PLAYER_SCENE_PATH)
		_finish()
		return

	for cid in EXPECTED.keys():
		await _test_character(cid as StringName)

	_finish()


func _finish() -> void:
	_print_summary()
	quit(0 if errors.is_empty() else 1)


# ────────────────────────────────────────────────────────────────────────────
# 캐릭터 1종 검증
# ────────────────────────────────────────────────────────────────────────────
func _test_character(cid: StringName) -> void:
	var label := String(cid)
	var path := "%s/%s.tres" % [CHAR_DIR, label]
	if not ResourceLoader.exists(path):
		_fail("[%s] .tres missing: %s" % [label, path])
		return
	var res: Resource = load(path)
	if res == null:
		_fail("[%s] .tres load failed: %s" % [label, path])
		return
	if not (res is CharacterData):
		_fail("[%s] not CharacterData (got %s)" % [label, res.get_class()])
		return
	var data: CharacterData = res
	var exp: Dictionary = EXPECTED[cid]

	# (a) 스탯 — .tres 데이터가 스펙 표와 정확히 일치
	_check(label, "id",
		data.id == cid,
		"id &\"%s\" != &\"%s\"" % [String(data.id), label])
	_check(label, "display_name_ko",
		data.display_name_ko == String(exp["display_name_ko"]),
		"display_name_ko '%s' != '%s'" % [data.display_name_ko, String(exp["display_name_ko"])])
	_check(label, "base_hp",
		data.base_hp == int(exp["base_hp"]),
		"base_hp %d != %d" % [data.base_hp, int(exp["base_hp"])])
	_check(label, "base_move_speed",
		_feq(data.base_move_speed, float(exp["base_move_speed"])),
		"base_move_speed %.3f != %.3f" % [data.base_move_speed, float(exp["base_move_speed"])])
	_check(label, "base_attack",
		data.base_attack == int(exp["base_attack"]),
		"base_attack %d != %d" % [data.base_attack, int(exp["base_attack"])])
	_check(label, "base_attack_speed",
		_feq(data.base_attack_speed, float(exp["base_attack_speed"])),
		"base_attack_speed %.3f != %.3f" % [data.base_attack_speed, float(exp["base_attack_speed"])])

	# (b) 시작 스킬 목록
	_check_starting_skills(label, data, exp["starting_skill_ids"])

	# (c) 인스턴스화 → 물리 시뮬 → 위치 변화 + 공격 발생
	await _check_physics_and_attack(cid, data)


# ────────────────────────────────────────────────────────────────────────────
# (b) 시작 스킬 검증
#   CharacterData 에 정식 `starting_skill_ids: Array[StringName]` 필드가 있으면 그걸 사용,
#   없으면 메타데이터 → 마지막으로 start_weight_overrides 의 무한대 가중치를
#   "자동 보유(auto-grant)" 로 간주하는 폴백을 시도한다.
# ────────────────────────────────────────────────────────────────────────────
func _check_starting_skills(label: String, data: CharacterData, expected_raw: Array) -> void:
	var actual: Array = []
	if "starting_skill_ids" in data:
		var v: Variant = data.get("starting_skill_ids")
		if v is Array:
			for x in (v as Array):
				actual.append(StringName(String(x)))
	elif data.has_meta(&"starting_skill_ids"):
		var v2: Variant = data.get_meta(&"starting_skill_ids")
		if v2 is Array:
			for x in (v2 as Array):
				actual.append(StringName(String(x)))
	else:
		# 폴백: start_weight_overrides 에 무한대(또는 매우 큰) 가중치를 둔 항목은 자동 보유로 간주.
		for k in data.start_weight_overrides.keys():
			var w: float = float(data.start_weight_overrides[k])
			if is_inf(w) or w >= 1000.0:
				actual.append(StringName(String(k)))

	var expected: Array = []
	for x in expected_raw:
		expected.append(StringName(String(x)))

	_check(label, "starting_skill_ids",
		_sn_array_equal(actual, expected),
		"starting_skill_ids %s != %s" % [_fmt_sn_array(actual), _fmt_sn_array(expected)])


# ────────────────────────────────────────────────────────────────────────────
# (c) 인스턴스화 + 물리 + 공격
# ────────────────────────────────────────────────────────────────────────────
func _check_physics_and_attack(cid: StringName, data: CharacterData) -> void:
	var label := String(cid)
	var player: Node = _player_scene.instantiate()
	if player == null:
		_fail("[%s] player instantiate failed" % label)
		return

	# 가능하다면 캐릭터 데이터 주입 (player.gd 가 character_data 필드를 가지면 적용).
	# 현재는 필드가 없어 no-op 이지만 향후 6캐릭터 인스턴스화 지원 시 자동 연결되도록 한다.
	if "character_data" in player:
		player.set("character_data", data)

	# 화면 좌상단 근처에 배치 (씬의 기본 좌표는 (240, 427) — 영향 없음).
	if player is Node2D:
		(player as Node2D).position = Vector2(100, 100)

	root.add_child(player)

	# _ready + autoload 적용 한 프레임 대기.
	await physics_frame

	if not is_instance_valid(player) or not player.is_inside_tree():
		_fail("[%s] player not in tree after add_child" % label)
		return

	# (c.1) 이동 — ui_right 입력 시뮬, MOVE_FRAMES 회 물리 진행.
	var start_pos: Vector2 = Vector2.ZERO
	if player is Node2D:
		start_pos = (player as Node2D).position
	Input.action_press(&"ui_right")
	for i in MOVE_FRAMES:
		await physics_frame
	Input.action_release(&"ui_right")
	var end_pos: Vector2 = start_pos
	if player is Node2D:
		end_pos = (player as Node2D).position
	var moved: float = (end_pos - start_pos).length()
	_check(label, "physics_move",
		moved >= MOVE_THRESHOLD_PX,
		"position 이동량 %.2fpx (start=%s end=%s, threshold=%.1fpx)" % [moved, start_pos, end_pos, MOVE_THRESHOLD_PX])

	# (c.2) 공격 — ATTACK_FRAMES 회 추가 물리 진행. Player.attack_timer 가
	# ATTACK_INTERVAL(1.0s) 도달 시 _perform_attack() 호출 직후 0 으로 리셋되는 동작 검증.
	# ATTACK_FRAMES * PHYSICS_DT ≈ 1.16s → 정상 동작이면 최소 1회 리셋되어 attack_timer < 1.0.
	if "attack_timer" in player:
		var atk_before: float = float(player.get("attack_timer"))
		for i in ATTACK_FRAMES:
			await physics_frame
		var atk_after: float = float(player.get("attack_timer"))
		var attacked: bool = atk_after < 1.0
		_check(label, "attack_fired",
			attacked,
			"attack_timer 가 reset되지 않음 (before=%.3f after=%.3f, 기대: _perform_attack() 호출로 < 1.0)" % [atk_before, atk_after])
	else:
		_fail("[%s] attack_fired — player.attack_timer 필드가 존재하지 않음 (공격 호출 감지 불가)" % label)

	# 정리: 다음 캐릭터 테스트가 깨끗한 트리에서 시작되도록 노드 해제 후 한 프레임 대기.
	if is_instance_valid(player):
		player.queue_free()
	await process_frame


# ────────────────────────────────────────────────────────────────────────────
# 검증 / 출력 헬퍼
# ────────────────────────────────────────────────────────────────────────────
func _check(label: String, name: String, cond: bool, fail_msg: String) -> void:
	if cond:
		passes += 1
		print("[CHAR] PASS — [%s] %s" % [label, name])
	else:
		_fail("[%s] %s — %s" % [label, name, fail_msg])


func _fail(msg: String) -> void:
	errors.append(msg)
	print("[CHAR] FAIL — %s" % msg)


func _feq(a: float, b: float) -> bool:
	return absf(a - b) <= 0.0001 * maxf(1.0, absf(b))


func _sn_array_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	var ai: Array[String] = []
	var bi: Array[String] = []
	for x in a:
		ai.append(String(x))
	for x in b:
		bi.append(String(x))
	ai.sort()
	bi.sort()
	for i in ai.size():
		if ai[i] != bi[i]:
			return false
	return true


func _fmt_sn_array(a: Array) -> String:
	var parts: Array[String] = []
	for x in a:
		parts.append("&\"%s\"" % String(x))
	return "[%s]" % ", ".join(parts)


func _print_summary() -> void:
	print("")
	print("[CHAR] ═══════════════════════════════════════════════")
	print("[CHAR] characters tested: %d" % EXPECTED.size())
	print("[CHAR] passes: %d  failures: %d" % [passes, errors.size()])
	if not errors.is_empty():
		for e in errors:
			print("[CHAR]   - %s" % e)
	print("[CHAR] result: %s" % ("PASS" if errors.is_empty() else "FAIL"))
	print("[CHAR] ═══════════════════════════════════════════════")
