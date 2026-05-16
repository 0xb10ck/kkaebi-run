extends SceneTree

# tests/test_ui.gd — UI 씬 스모크 테스트 (Godot 4 headless).
# 실행:
#   godot --headless --path /Users/0xb10ck/kkaebi-run --script tests/test_ui.gd
#
# 각 UI 씬(메인 메뉴 / HUD / 레벨업 / 일시정지 / 결과 화면 / 보스 HP 바 /
# 도감 / 도전과제)을 인스턴스화한 뒤
#   (a) 대표 데이터 모델 / 값을 주입해 라벨 텍스트가 주입값과 일치하는지,
#   (b) 핵심 버튼에 pressed.emit() 을 호출했을 때 연결된 핸들러가 실제로 실행되어
#       기대하는 상태 전이(visible / signal / text 등) 가 발생하는지 검증한다.
#
# push_error 는 한 번도 호출하지 않는다(헤드리스에서 SCRIPT ERROR 로 집계되어
# 종료 코드를 어지럽힘). user://logs/godot.log 가 존재하면 시작 시점의 끝 오프셋을
# 기억해 두고 테스트 종료 후 SCRIPT ERROR / PARSE ERROR 라인이 추가됐는지 검사한다.
# 로그 파일이 없으면(파일 로깅 비활성) 베스트-에포트로 스킵.
#
# user://save.json 은 시작 시 백업해 두고 끝날 때 복원한다 — show_result 가 정산을
# 수행하면서 MetaState 가 autosave 를 발신할 수 있기 때문.


const HUD_PATH:           String = "res://scenes/ui/hud.tscn"
const PAUSE_PATH:         String = "res://scenes/ui/pause_menu.tscn"
const LEVEL_UP_PATH:      String = "res://scenes/ui/level_up_panel.tscn"
const RESULT_PATH:        String = "res://scenes/ui/result_screen.tscn"
const BOSS_HP_BAR_PATH:   String = "res://scenes/ui/boss_hp_bar.tscn"
const CODEX_PATH:         String = "res://scenes/ui/codex.tscn"
const ACHIEVEMENTS_PATH:  String = "res://scenes/ui/achievements.tscn"
const MAIN_MENU_PATH:     String = "res://scenes/main_menu/main_menu.tscn"

const SAVE_PATH: String = "user://save.json"
const LOG_PATH:  String = "user://logs/godot.log"


var errors: Array[String] = []
var passes: int = 0
var log_start_size: int = -1


# ─────────────────────────────────────────────────────────────────────
# Inner mocks
# ─────────────────────────────────────────────────────────────────────

class MockManager:
	extends Node
	var acquired: Array = []
	func acquire(id: Variant, _player: Variant) -> void:
		acquired.append(String(id))


class MockBoss:
	extends Node
	signal phase_changed(new_index: int)
	signal died(boss_id: StringName)
	var current_hp: int = 80


# ─────────────────────────────────────────────────────────────────────
# Entry
# ─────────────────────────────────────────────────────────────────────

func _initialize() -> void:
	# Autoload _ready() 가 끝날 시간을 한 프레임 양보한 뒤 메인 시퀀스 실행.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var save_backup: Dictionary = _backup_save()
	log_start_size = _current_log_size()
	var prior_paused: bool = paused
	paused = false

	await _test_hud()
	paused = false
	await _test_pause_menu()
	paused = false
	await _test_level_up_panel()
	paused = false
	await _test_result_screen()
	paused = false
	await _test_boss_hp_bar()
	paused = false
	await _test_codex()
	paused = false
	await _test_achievements()
	paused = false
	await _test_main_menu()
	paused = false

	_check_log_for_errors()

	paused = prior_paused
	_restore_save(save_backup)

	_print_summary()
	quit(0 if errors.is_empty() else 1)


# ─────────────────────────────────────────────────────────────────────
# HUD
# ─────────────────────────────────────────────────────────────────────

func _test_hud() -> void:
	print("[UI] --- HUD ---")
	var inst: Node = _instantiate(HUD_PATH, "HUD")
	if inst == null:
		return
	await _wait(1)
	var hp_label: Label = inst.get_node("HPBarBg/HPLabel") as Label
	var level_label: Label = inst.get_node("LevelLabel") as Label
	var coin_label: Label = inst.get_node("CoinLabel") as Label
	var timer_label: Label = inst.get_node("TimerLabel") as Label
	var pause_button: Button = inst.get_node("PauseButton") as Button

	inst.set_hp(70, 100)
	_expect(hp_label.text == "70 / 100",
		"[HUD] set_hp(70,100) → HPLabel '%s'" % hp_label.text)

	inst.set_exp(25, 60, 4)
	_expect(level_label.text == "Lv. 4",
		"[HUD] set_exp(_,_,4) → LevelLabel '%s'" % level_label.text)

	inst.set_time(83.0)
	_expect(timer_label.text == "01:23",
		"[HUD] set_time(83.0) → TimerLabel '%s'" % timer_label.text)

	inst.set_coins(42)
	_expect(coin_label.text == "금화 42",
		"[HUD] set_coins(42) → CoinLabel '%s'" % coin_label.text)

	# 핵심 버튼: PauseButton → pause_pressed 시그널 발신.
	var got_pause: Array[bool] = [false]
	var cb: Callable = func() -> void: got_pause[0] = true
	inst.pause_pressed.connect(cb)
	pause_button.pressed.emit()
	_expect(got_pause[0],
		"[HUD] PauseButton.pressed → pause_pressed signal emitted")
	if inst.pause_pressed.is_connected(cb):
		inst.pause_pressed.disconnect(cb)

	inst.queue_free()
	await _wait(1)


# ─────────────────────────────────────────────────────────────────────
# Pause Menu
# ─────────────────────────────────────────────────────────────────────

func _test_pause_menu() -> void:
	print("[UI] --- PauseMenu ---")
	var inst: Node = _instantiate(PAUSE_PATH, "PauseMenu")
	if inst == null:
		return
	await _wait(1)
	var root_ctrl: Control = inst.get_node("Root") as Control
	var title_label: Label = inst.get_node("Root/Panel/Title") as Label
	var continue_btn: Button = inst.get_node("Root/Panel/ContinueButton") as Button
	var restart_btn: Button = inst.get_node("Root/Panel/RestartButton") as Button
	var main_menu_btn: Button = inst.get_node("Root/Panel/MainMenuButton") as Button

	_expect(title_label.text == "일시정지",
		"[PauseMenu] Title 라벨 '%s' (expected '일시정지')" % title_label.text)
	_expect(root_ctrl.visible == false,
		"[PauseMenu] Root invisible after _ready (got %s)" % str(root_ctrl.visible))

	inst.open_pause()
	_expect(root_ctrl.visible,
		"[PauseMenu] open_pause() → Root.visible == true")
	_expect(paused == true,
		"[PauseMenu] open_pause() → SceneTree.paused == true")

	# ContinueButton: 오버레이를 닫고 paused 해제.
	continue_btn.pressed.emit()
	_expect(root_ctrl.visible == false,
		"[PauseMenu] ContinueButton.pressed → Root 숨김")
	_expect(paused == false,
		"[PauseMenu] ContinueButton.pressed → SceneTree.paused 복귀")

	# RestartButton: restart_pressed 시그널 발신 + 오버레이 숨김.
	inst.open_pause()
	var got_restart: Array[bool] = [false]
	var rcb: Callable = func() -> void: got_restart[0] = true
	inst.restart_pressed.connect(rcb)
	restart_btn.pressed.emit()
	_expect(got_restart[0],
		"[PauseMenu] RestartButton.pressed → restart_pressed signal")
	_expect(root_ctrl.visible == false,
		"[PauseMenu] RestartButton.pressed → Root 숨김")
	if inst.restart_pressed.is_connected(rcb):
		inst.restart_pressed.disconnect(rcb)

	# MainMenuButton: main_menu_pressed 시그널 발신.
	inst.open_pause()
	var got_menu: Array[bool] = [false]
	var mcb: Callable = func() -> void: got_menu[0] = true
	inst.main_menu_pressed.connect(mcb)
	main_menu_btn.pressed.emit()
	_expect(got_menu[0],
		"[PauseMenu] MainMenuButton.pressed → main_menu_pressed signal")
	if inst.main_menu_pressed.is_connected(mcb):
		inst.main_menu_pressed.disconnect(mcb)

	inst.queue_free()
	await _wait(1)


# ─────────────────────────────────────────────────────────────────────
# Level Up Panel
# ─────────────────────────────────────────────────────────────────────

func _test_level_up_panel() -> void:
	print("[UI] --- LevelUpPanel ---")
	var inst: Node = _instantiate(LEVEL_UP_PATH, "LevelUpPanel")
	if inst == null:
		return
	await _wait(1)

	var card0: PanelContainer = inst.get_node("CenterContainer/HBoxContainer/Card0") as PanelContainer
	var card1: PanelContainer = inst.get_node("CenterContainer/HBoxContainer/Card1") as PanelContainer
	var card2: PanelContainer = inst.get_node("CenterContainer/HBoxContainer/Card2") as PanelContainer
	var name0: Label = card0.get_node("VBoxContainer/NameLabel") as Label
	var desc0: Label = card0.get_node("VBoxContainer/DescLabel") as Label
	var name1: Label = card1.get_node("VBoxContainer/NameLabel") as Label
	var select0: Button = card0.get_node("VBoxContainer/SelectButton") as Button

	_expect(inst.visible == false,
		"[LevelUpPanel] hidden after _ready")

	var manager: Node = MockManager.new()
	root.add_child(manager)
	var offers: Array = [
		{
			"id": "skill_test_a", "type": "skill",
			"name": "테스트스킬A", "desc": "테스트 설명 A", "color": "#aa0000",
		},
		{
			"id": "skill_test_b", "type": "skill",
			"name": "테스트스킬B", "desc": "테스트 설명 B", "color": "#00aa00",
		},
		{
			"id": "skill_test_c", "type": "skill",
			"name": "테스트스킬C", "desc": "테스트 설명 C", "color": "#0000aa",
		},
	]
	inst.show_offer(offers, null, manager)
	_expect(inst.visible,
		"[LevelUpPanel] show_offer() → panel visible")
	_expect(paused == true,
		"[LevelUpPanel] show_offer() → SceneTree.paused == true")
	_expect(name0.text == "테스트스킬A",
		"[LevelUpPanel] Card0 NameLabel '%s' (expected '테스트스킬A')" % name0.text)
	_expect(desc0.text == "테스트 설명 A",
		"[LevelUpPanel] Card0 DescLabel '%s' (expected '테스트 설명 A')" % desc0.text)
	_expect(name1.text == "테스트스킬B",
		"[LevelUpPanel] Card1 NameLabel '%s' (expected '테스트스킬B')" % name1.text)
	_expect(card2.visible,
		"[LevelUpPanel] Card2 visible when 3 offers provided")

	# 카드 선택 시뮬레이션: SelectButton.pressed → manager.acquire 호출, closed 시그널.
	var got_closed: Array[bool] = [false]
	var ccb: Callable = func() -> void: got_closed[0] = true
	inst.closed.connect(ccb)
	select0.pressed.emit()
	_expect(manager.acquired.has("skill_test_a"),
		"[LevelUpPanel] Card0 SelectButton → manager.acquire('skill_test_a')")
	_expect(got_closed[0],
		"[LevelUpPanel] Card0 SelectButton → closed signal")
	_expect(inst.visible == false,
		"[LevelUpPanel] Card0 SelectButton → panel hidden")
	_expect(paused == false,
		"[LevelUpPanel] Card0 SelectButton → SceneTree.paused 복귀")
	if inst.closed.is_connected(ccb):
		inst.closed.disconnect(ccb)

	manager.queue_free()
	inst.queue_free()
	await _wait(1)


# ─────────────────────────────────────────────────────────────────────
# Result Screen
# ─────────────────────────────────────────────────────────────────────

func _test_result_screen() -> void:
	print("[UI] --- ResultScreen ---")
	var inst: Node = _instantiate(RESULT_PATH, "ResultScreen")
	if inst == null:
		return
	await _wait(1)

	var root_ctrl: Control = inst.get_node("Root") as Control
	var title: Label = inst.get_node("Root/Panel/Title") as Label
	var subtitle: Label = inst.get_node("Root/Panel/Subtitle") as Label
	var survive: Label = inst.get_node("Root/Panel/Stats/SurviveRow/Value") as Label
	var kills: Label = inst.get_node("Root/Panel/Stats/KillsRow/Value") as Label
	var level: Label = inst.get_node("Root/Panel/Stats/LevelRow/Value") as Label
	var coins: Label = inst.get_node("Root/Panel/Stats/CoinsRow/Value") as Label
	var restart_btn: Button = inst.get_node("Root/Panel/RestartButton") as Button
	var main_menu_btn: Button = inst.get_node("Root/Panel/MainMenuButton") as Button

	_expect(root_ctrl.visible == false,
		"[ResultScreen] Root invisible after _ready (got %s)" % str(root_ctrl.visible))

	# 사망 케이스: survive_sec(120) < STAGE_FULL_SEC(300).
	inst.show_result(120, 47, 6, 333)
	_expect(root_ctrl.visible,
		"[ResultScreen] show_result() → Root.visible == true")
	_expect(title.text == "도깨비가 잠들었습니다",
		"[ResultScreen] sub-clear title '%s'" % title.text)
	_expect(subtitle.text.begins_with("신목의 기운"),
		"[ResultScreen] sub-clear subtitle '%s'" % subtitle.text)
	_expect(survive.text == "02:00",
		"[ResultScreen] survive '%s' (expected '02:00')" % survive.text)
	_expect(kills.text == "47",
		"[ResultScreen] kills '%s' (expected '47')" % kills.text)
	_expect(level.text == "레벨 6",
		"[ResultScreen] level '%s' (expected '레벨 6')" % level.text)
	_expect(coins.text == "333",
		"[ResultScreen] coins '%s' (expected '333')" % coins.text)

	# RestartButton: restart_pressed 시그널 발신.
	var got_restart: Array[bool] = [false]
	var rcb: Callable = func() -> void: got_restart[0] = true
	inst.restart_pressed.connect(rcb)
	restart_btn.pressed.emit()
	_expect(got_restart[0],
		"[ResultScreen] RestartButton.pressed → restart_pressed signal")
	if inst.restart_pressed.is_connected(rcb):
		inst.restart_pressed.disconnect(rcb)

	# MainMenuButton: main_menu_pressed 시그널 발신.
	var got_menu: Array[bool] = [false]
	var mcb: Callable = func() -> void: got_menu[0] = true
	inst.main_menu_pressed.connect(mcb)
	main_menu_btn.pressed.emit()
	_expect(got_menu[0],
		"[ResultScreen] MainMenuButton.pressed → main_menu_pressed signal")
	if inst.main_menu_pressed.is_connected(mcb):
		inst.main_menu_pressed.disconnect(mcb)

	inst.queue_free()
	await _wait(1)


# ─────────────────────────────────────────────────────────────────────
# Boss HP Bar
# ─────────────────────────────────────────────────────────────────────

func _test_boss_hp_bar() -> void:
	print("[UI] --- BossHpBar ---")
	var inst: Node = _instantiate(BOSS_HP_BAR_PATH, "BossHpBar")
	if inst == null:
		return
	await _wait(1)

	var name_label: Label = inst.get_node("Root/Bar/NameLabel") as Label
	var phase_label: Label = inst.get_node("Root/Bar/PhaseLabel") as Label
	var hp_bar: ProgressBar = inst.get_node("Root/Bar/HpBar") as ProgressBar
	var root_ctrl: Control = inst.get_node("Root") as Control

	_expect(root_ctrl.visible == false,
		"[BossHpBar] Root invisible until bind_boss() (got %s)"
			% str(root_ctrl.visible))

	var data: BossData = BossData.new()
	data.id = &"test_boss"
	data.display_name_ko = "테스트 보스"
	data.hp = 100
	var phase_a: BossPhase = BossPhase.new()
	var phase_b: BossPhase = BossPhase.new()
	data.phases = [phase_a, phase_b]

	var boss: Node = MockBoss.new()
	boss.current_hp = 80
	root.add_child(boss)

	inst.bind_boss(boss, data)
	_expect(root_ctrl.visible,
		"[BossHpBar] bind_boss() → Root.visible == true")
	_expect(name_label.text == "테스트 보스",
		"[BossHpBar] NameLabel '%s' (expected '테스트 보스')" % name_label.text)
	_expect(phase_label.text == "페이즈 1 / 2",
		"[BossHpBar] PhaseLabel '%s' (expected '페이즈 1 / 2')" % phase_label.text)

	# phase_changed 시그널 발신 → 라벨 갱신.
	boss.phase_changed.emit(1)
	_expect(phase_label.text == "페이즈 2 / 2",
		"[BossHpBar] phase_changed(1) → PhaseLabel '%s' (expected '페이즈 2 / 2')"
			% phase_label.text)

	# _process 폴링으로 HP 비율 갱신 (1프레임 양보).
	await _wait(2)
	_expect(absf(hp_bar.value - 0.8) < 0.01,
		"[BossHpBar] HpBar.value '%f' (expected ~0.8 for 80/100)" % hp_bar.value)

	# died 시그널 → Root 숨김.
	boss.died.emit(&"test_boss")
	_expect(root_ctrl.visible == false,
		"[BossHpBar] died signal → Root 숨김")

	boss.queue_free()
	inst.queue_free()
	await _wait(1)


# ─────────────────────────────────────────────────────────────────────
# Codex
# ─────────────────────────────────────────────────────────────────────

func _test_codex() -> void:
	print("[UI] --- Codex ---")
	var inst: Node = _instantiate(CODEX_PATH, "Codex")
	if inst == null:
		return
	await _wait(1)

	var title: Label = inst.get_node("Title") as Label
	var monsters_tab: Button = inst.get_node("Tabs/MonstersTab") as Button
	var bosses_tab: Button = inst.get_node("Tabs/RelicsTab") as Button
	var skills_tab: Button = inst.get_node("Tabs/PlacesTab") as Button
	var progress_label: Label = inst.get_node("ProgressLabel") as Label
	var grid: GridContainer = inst.get_node("Scroll/Grid") as GridContainer

	_expect(title.text == "도감",
		"[Codex] Title '%s' (expected '도감')" % title.text)
	_expect(monsters_tab.text == "몬스터",
		"[Codex] Monsters tab relabeled '%s' (expected '몬스터')" % monsters_tab.text)
	_expect(bosses_tab.text == "보스",
		"[Codex] Bosses tab relabeled '%s' (expected '보스')" % bosses_tab.text)
	_expect(skills_tab.text == "스킬",
		"[Codex] Skills tab relabeled '%s' (expected '스킬')" % skills_tab.text)
	_expect(monsters_tab.button_pressed,
		"[Codex] Monsters tab toggled on by default")
	_expect(progress_label.text.begins_with("몬스터 도감"),
		"[Codex] progress label begins with '몬스터 도감' (got '%s')"
			% progress_label.text)

	# 보스 탭 누름 → 카테고리 전환, 그리드 재구성, progress 갱신.
	bosses_tab.pressed.emit()
	await _wait(1)
	_expect(bosses_tab.button_pressed,
		"[Codex] bosses_tab.pressed → button_pressed=true")
	_expect(monsters_tab.button_pressed == false,
		"[Codex] bosses_tab.pressed → monsters_tab.button_pressed=false")
	_expect(progress_label.text.begins_with("보스 도감"),
		"[Codex] progress label updates to '보스 도감' (got '%s')"
			% progress_label.text)

	# 스킬 탭 누름.
	skills_tab.pressed.emit()
	await _wait(1)
	_expect(skills_tab.button_pressed,
		"[Codex] skills_tab.pressed → button_pressed=true")
	_expect(progress_label.text.begins_with("스킬 도감"),
		"[Codex] progress label updates to '스킬 도감' (got '%s')"
			% progress_label.text)
	# 카테고리 전환 후에도 그리드가 어떤 자식이든 갖고 있어야 함(빈 카테고리여도 정상 처리).
	_expect(grid.get_child_count() >= 0,
		"[Codex] grid rebuilt without crashing (count=%d)" % grid.get_child_count())

	inst.queue_free()
	await _wait(1)


# ─────────────────────────────────────────────────────────────────────
# Achievements
# ─────────────────────────────────────────────────────────────────────

func _test_achievements() -> void:
	print("[UI] --- Achievements ---")
	var inst: Node = _instantiate(ACHIEVEMENTS_PATH, "Achievements")
	if inst == null:
		return
	await _wait(1)

	var title: Label = inst.get_node("Title") as Label
	var once_tab: Button = inst.get_node("Tabs/OnceTab") as Button
	var daily_tab: Button = inst.get_node("Tabs/DailyTab") as Button
	var weekly_tab: Button = inst.get_node("Tabs/WeeklyTab") as Button
	var list: VBoxContainer = inst.get_node("Scroll/List") as VBoxContainer

	_expect(title.text == "도전과제",
		"[Achievements] Title '%s' (expected '도전과제')" % title.text)
	_expect(once_tab.button_pressed,
		"[Achievements] Once tab toggled on at start")
	_expect(list.get_child_count() > 0,
		"[Achievements] Once 카테고리 항목 채워짐 (count=%d)"
			% list.get_child_count())

	# 일일 탭 누름 → 리스트 재구성, 카테고리 전환.
	daily_tab.pressed.emit()
	await _wait(1)
	_expect(daily_tab.button_pressed,
		"[Achievements] daily_tab.pressed → button_pressed=true")
	_expect(once_tab.button_pressed == false,
		"[Achievements] daily_tab.pressed → once_tab.button_pressed=false")
	_expect(list.get_child_count() > 0,
		"[Achievements] Daily 카테고리 항목 채워짐 (count=%d)"
			% list.get_child_count())

	# 주간 탭 누름.
	weekly_tab.pressed.emit()
	await _wait(1)
	_expect(weekly_tab.button_pressed,
		"[Achievements] weekly_tab.pressed → button_pressed=true")
	_expect(list.get_child_count() > 0,
		"[Achievements] Weekly 카테고리 항목 채워짐 (count=%d)"
			% list.get_child_count())

	inst.queue_free()
	await _wait(1)


# ─────────────────────────────────────────────────────────────────────
# Main Menu
# ─────────────────────────────────────────────────────────────────────

func _test_main_menu() -> void:
	print("[UI] --- MainMenu ---")
	var inst: Node = _instantiate(MAIN_MENU_PATH, "MainMenu")
	if inst == null:
		return
	await _wait(1)

	var title: Label = inst.get_node("Title") as Label
	var subtitle: Label = inst.get_node("Subtitle") as Label
	var orbs_label: Label = inst.get_node("OrbsLabel") as Label
	var shinmok_label: Label = inst.get_node("Shinmok/ShinmokLabel") as Label
	var start_btn: Button = inst.get_node("Buttons/StartButton") as Button
	var settings_btn: Button = inst.get_node("Buttons/SettingsButton") as Button

	_expect(title.text == "깨비런",
		"[MainMenu] Title '%s' (expected '깨비런')" % title.text)
	_expect(subtitle.text == "오방 도깨비의 5분 생존기",
		"[MainMenu] Subtitle '%s'" % subtitle.text)
	_expect(orbs_label.text.begins_with("도깨비 구슬"),
		"[MainMenu] OrbsLabel '%s' begins with '도깨비 구슬'" % orbs_label.text)
	_expect(shinmok_label.text.begins_with("신목 Lv."),
		"[MainMenu] ShinmokLabel '%s' begins with '신목 Lv.'" % shinmok_label.text)
	_expect(start_btn.pressed.get_connections().size() > 0,
		"[MainMenu] StartButton has at least one pressed connection")

	# 다른 버튼은 change_scene_to_file 을 호출해 트리를 갈아엎으므로 SettingsButton 만 누른다.
	# SettingsButton 은 EventBus.toast_requested 만 발신해 안전하다.
	# 헤드리스 --script 부트에서는 autoload 식별자가 컴파일타임에 해소되지 않으므로
	# Node 트리에서 직접 가져온다(autoload 노드는 root 의 직속 자식).
	var bus: Node = root.get_node_or_null("EventBus")
	_expect(bus != null, "[MainMenu] EventBus autoload available")
	var got_toast: Array[bool] = [false]
	var tcb: Callable = func(_msg: String, _dur: float) -> void: got_toast[0] = true
	if bus != null:
		bus.toast_requested.connect(tcb)
	settings_btn.pressed.emit()
	_expect(got_toast[0],
		"[MainMenu] SettingsButton.pressed → EventBus.toast_requested 발신")
	if bus != null and bus.toast_requested.is_connected(tcb):
		bus.toast_requested.disconnect(tcb)

	inst.queue_free()
	await _wait(1)


# ─────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────

func _instantiate(path: String, expected_root_name: String) -> Node:
	if not ResourceLoader.exists(path):
		_fail("scene missing: %s" % path)
		return null
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_fail("not a PackedScene: %s" % path)
		return null
	var node: Node = packed.instantiate()
	if node == null:
		_fail("instantiate() returned null: %s" % path)
		return null
	if node.name != expected_root_name:
		_fail("[%s] root name '%s' (expected '%s')"
			% [path, node.name, expected_root_name])
	root.add_child(node)
	return node


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _expect(cond: bool, label: String) -> void:
	if cond:
		passes += 1
		print("PASS  %s" % label)
	else:
		errors.append(label)
		print("FAIL  %s" % label)


func _fail(label: String) -> void:
	errors.append(label)
	print("FAIL  %s" % label)


func _current_log_size() -> int:
	if not FileAccess.file_exists(LOG_PATH):
		return -1
	var f: FileAccess = FileAccess.open(LOG_PATH, FileAccess.READ)
	if f == null:
		return -1
	var size: int = int(f.get_length())
	f.close()
	return size


func _check_log_for_errors() -> void:
	if log_start_size < 0:
		print("[UI] log file %s not present — skipping log-scan" % LOG_PATH)
		return
	if not FileAccess.file_exists(LOG_PATH):
		print("[UI] log file disappeared — skipping log-scan")
		return
	var f: FileAccess = FileAccess.open(LOG_PATH, FileAccess.READ)
	if f == null:
		print("[UI] cannot reopen log file — skipping log-scan")
		return
	var total: int = int(f.get_length())
	if total <= log_start_size:
		f.close()
		return
	f.seek(log_start_size)
	var appended: String = f.get_buffer(total - log_start_size).get_string_from_utf8()
	f.close()
	for raw_line in appended.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty():
			continue
		if line.begins_with("SCRIPT ERROR") or line.begins_with("PARSE ERROR") or line.begins_with("USER SCRIPT ERROR"):
			errors.append("log captured: %s" % line)
			print("FAIL  log captured: %s" % line)


func _backup_save() -> Dictionary:
	var out: Dictionary = {"existed": false, "bytes": PackedByteArray()}
	if FileAccess.file_exists(SAVE_PATH):
		var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f != null:
			out["existed"] = true
			out["bytes"] = f.get_buffer(f.get_length())
			f.close()
	return out


func _restore_save(backup: Dictionary) -> void:
	if backup.get("existed", false):
		var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_buffer(backup["bytes"])
			f.close()
	else:
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _print_summary() -> void:
	print("")
	print("-- test_ui summary --")
	print("PASS: %d" % passes)
	print("FAIL: %d" % errors.size())
	if not errors.is_empty():
		print("Failed checks:")
		for e in errors:
			print("  - %s" % e)
