# 깨비런 — 풀스펙 아키텍처 설계 (Full Spec Architecture)

> **버전**: 1.0
> **작성일**: 2026-05-14
> **상위 문서**: `docs/kkaebi-run-gdd-v2.md`, `docs/monsters-full-spec.md`(53종), `docs/bosses-full-spec.md`(11종), `docs/skills-full-spec.md`(30종), `docs/characters-full-spec.md`(6종), `docs/meta-systems-spec.md`
> **이전 버전**: `docs/phase1-architecture.md` (MVP — 적 3 / 스킬 5 / 5분 1스테이지)
> **엔진**: Godot 4.2, GDScript, GL Compatibility, 1280×720, 데스크톱 + 웹(HTML5)
> **목표**: 엔지니어가 본 문서만 보고 풀스펙 게임을 추가 설계 결정 없이 구현할 수 있는 수준의 구조 확정.

---

## Architecture Decision

### Problem
풀스펙(6챕터 / 53몬스터 / 11보스 / 30스킬 / 6캐릭터 / 8영구강화 / 신목 6단계 / 7랜덤이벤트 / 5환경요소 / 30+도전과제)을 Godot 4.2 위에서 한 코드베이스로 구현해야 한다. **(1) 디렉토리, (2) 자동로드, (3) 이벤트 흐름, (4) 데이터 리소스 스키마, (5) 보스/메타/세이브 하위 시스템, (6) 기존 MVP 코드를 어떻게 마이그레이션할 것인가**를 한 번에 확정한다.

### Option A
**MVP 점진 확장** — 현재 flat `scripts/`, `scenes/gameplay`에 보스/메타/챕터를 그대로 덧붙인다.
- Pros: 즉시 코딩 가능, 마이그레이션 비용 0.
- Cons: 53종 적·30종 스킬·11보스가 한 폴더에 쌓이면서 충돌·이름공간 오염, 보스 패턴/메타 강화/이벤트가 `main.gd`로 빨려들어가 단일 5,000줄 스크립트가 된다. 디버깅·테스트 모두 불가.

### Option B
**풀스펙 디렉토리 + 5 자동로드 + 데이터 외화 + EventBus** — 책임별 디렉토리(scenes/scripts/resources 각각 9~12 하위), 자동로드 5개(GameState/SkillManager/MetaState/ChapterManager/EventBus), 모든 수치는 `.tres` 리소스로 외화, 글로벌 통신은 EventBus 시그널로 단일화.
- Pros: 53 적·30 스킬·11 보스가 데이터 추가만으로 끝남. 보스 BossBase 한 곳에 페이즈/패턴/텔레그래프 일반화 → 11종에 재사용. 메타/세이브/이벤트가 독립 시스템으로 분리되어 단위 테스트 가능. 웹/데스크톱 세이브 차이를 한 곳(`SaveStore`)에서 흡수.
- Cons: 자동로드 5개의 초기화 의존성을 명시해야 함(§2.6). 디렉토리가 28개로 늘어 초기 탐색 비용이 있음.

### Decision
**Option B**를 풀스펙에 적용한다. MVP 코드는 §8의 매핑 표대로 옮긴다.

### Why
- 53 + 30 + 11 = 94종의 게임 객체 수치를 코드에 박을 수 없다. `.tres` 외화가 강제된다.
- 11보스의 페이즈/패턴/텔레그래프/컷인은 같은 골격을 공유하지만 수치만 다르다. BossBase 일반화가 11번의 중복을 막는다.
- 메타(영구강화/신목/도감/도전/친밀도)는 런 외부에서도 살아남아야 한다. MetaState 자동로드 + JSON 영속 저장이 필수.
- 챕터→스테이지→보스→막간→챕터 흐름은 ChapterManager가 상태머신으로 한 군데 보유해야 한다. `main.gd` 분기로 처리하면 무한 모드/하드/히든 추가 시 무너진다.
- EventBus가 없으면 `XPGem → Player → GameScene → HUD → MetaState` 같은 호출 사슬이 생긴다. 글로벌 시그널 카탈로그 하나에서 발신/수신을 한 줄로 한다.

### Backend decision
**백엔드 없음.** 단일 클라이언트, 웹(HTML5) 빌드. 일일/주간 도전은 `meta-systems-spec.md` §7.1 결정적 의사난수(시드 = 날짜 정수)로 서버리스 환경에서 동기. 멀티/리더보드는 스코프 밖.

### Persistence decision
**`user://save.json` 단일 파일.** 데스크톱은 직접 JSON 파일, 웹은 Godot의 `user://` 자동 IndexedDB 매핑(`/userfs/`)에 그대로 위임. 스키마는 §7. 버전 필드 + 마이그레이션 함수 체인으로 호환성 유지.

### Evolution path
- **무한 모드 / 하드 / 히든 챕터**: `ChapterData` 추가 + ChapterManager 분기. 코드 변경 최소.
- **신규 보스 / 신규 적**: `.tres` 1개 + 페이즈/패턴 데이터 추가. BossBase/EnemyBase 수정 불필요.
- **신규 스킬 / 진화**: `SkillData.tres` + 씬 스크립트. `levels[0..4]` 배열로 레벨링.
- **신규 캐릭터**: `CharacterData.tres` + 친밀도 트리 데이터. 별도 무기 씬이 필요한 경우만 씬 추가.
- **랜덤 이벤트 추가**: `events/` 디렉토리에 씬 + 데이터. EventManager가 자동 로드.

---

## 1. 디렉토리 구조

### 1.1 전체 트리

```
kkaebi-run/
├── project.godot
├── icon.svg
├── assets/                                # 스프라이트/SE/BGM (외부 에셋)
│   ├── sprites/{characters,enemies,bosses,skills,environment,ui}/
│   ├── audio/{bgm,se}/
│   └── fonts/
├── docs/                                  # 본 문서 포함 모든 설계 문서
├── resources/                             # @export 데이터 (.tres)
│   ├── enemies/                           # 53개 EnemyData.tres
│   ├── bosses/                            # 11개 BossData.tres
│   ├── skills/                            # 30개 SkillData.tres + 진화 12개
│   ├── characters/                        # 6개 CharacterData.tres + 친밀도 트리
│   ├── chapters/                          # 6개 ChapterData.tres
│   └── meta_upgrades/                     # 8개 MetaUpgradeData.tres
├── scenes/
│   ├── main_menu/                         # MainMenu, CharacterSelect, ChapterSelect, ShinmokScreen
│   ├── gameplay/                          # GameScene(루트), Intermission, PauseMenu
│   ├── player/                            # Player.tscn, Weapon.tscn (+ 캐릭터별 무기 변형)
│   ├── enemies/                           # EnemyBase.tscn + 53개 instance(또는 prefab) + AI behavior 씬
│   ├── bosses/                            # BossBase.tscn + 11개 inherits scene, IntroCutscene, PatternTelegraph
│   ├── skills/                            # 30개 + projectiles/, 진화 12개
│   ├── items/                             # XPGem, Gold, ShinmokLeaf, MythShard, Chest
│   ├── systems/                           # EnemySpawner, PoolManager, BossTrigger, EventTrigger
│   ├── ui/                                # HUD, LevelUpUI, ResultScreen, Toast, BossHPBar, Achievement
│   ├── environment/                       # Thornbush, Fog, PoisonMarsh, TalismanPillar, SpiritAltar
│   └── events/                            # GoblinMarket, SpiritBlessing, Curse, Chest, Wanderer, BloodMoon, InvisibleCap
├── scripts/
│   ├── constants/                         # palette.gd, layers.gd, ids.gd
│   ├── data/                              # *_data.gd (Resource 정의)
│   ├── systems/                           # autoloads + main.gd + spawner + pool + difficulty
│   ├── player/                            # player.gd, weapon.gd, hurtbox.gd
│   ├── enemies/                           # enemy_base.gd + 특수 AI mixin
│   ├── bosses/                            # boss_base.gd + pattern.gd + telegraph.gd + cutscene.gd
│   ├── skills/                            # skill_base.gd + 30개 + projectiles/
│   ├── items/                             # xp_gem.gd, gold.gd, etc.
│   ├── environment/                       # 환경 요소 5종 스크립트
│   ├── events/                            # 랜덤 이벤트 7종 스크립트 + event_manager.gd
│   ├── meta/                              # save_store.gd, meta_state_ops.gd, achievement.gd, codex.gd
│   └── ui/                                # 각 UI 위젯 스크립트
└── tests/                                 # GUT 도입 시 (Phase 2)
```

### 1.2 디렉토리 역할 및 명명 규칙

| 디렉토리 | 역할 | 명명 규칙 |
|---------|------|----------|
| `resources/enemies/` | 53종 적 수치 | `m{NN}_{snake_name}.tres` (예: `m01_dokkaebibul.tres`) |
| `resources/bosses/` | 미니보스 5 + 챕터보스 6 | `mb{NN}_{name}.tres`, `b{NN}_{name}.tres` |
| `resources/skills/` | 30종 + 진화 12종 | `{element}_{NN}_{name}.tres` (예: `fire_01_dokkaebibul.tres`), 진화는 `evo_{lhs}_{rhs}.tres` |
| `resources/characters/` | 6종 캐릭터 | `c{NN}_{name}.tres` (예: `c01_ttukttaki.tres`) + `affinity_{name}.tres` |
| `resources/chapters/` | 6장 | `ch{NN}_{name}.tres` (예: `ch01_dumeong.tres`) |
| `resources/meta_upgrades/` | 8개 영구강화 | `meta_{key}.tres` (예: `meta_max_hp.tres`) |
| `scenes/*` | 씬 파일 | `PascalCase.tscn` |
| `scripts/*` | GDScript | `snake_case.gd`, `class_name` 은 `PascalCase` |
| `scenes/enemies/*.tscn` | 개별 적 씬은 prefab 1개로 통일 가능 — `EnemyBase.tscn` 단일 + `data` 슬롯 주입 권장 | — |
| `scenes/bosses/{name}.tscn` | 보스는 패턴/스프라이트가 다양해 개별 씬 권장 | `BossDokkaebibulDaejang.tscn` 등 |

> **규칙**: 모든 게임 수치는 `resources/`의 `.tres`에 있어야 한다. 스크립트의 매직 넘버는 `scripts/constants/`로 격리한다.

---

## 2. 자동로드(Autoload) — 5개

자동로드는 정확히 5개. 그 외 전역 상태 금지. 등록은 `project.godot` 아래 순서대로:

```ini
[autoload]
EventBus="*res://scripts/systems/event_bus.gd"
GameState="*res://scripts/systems/game_state.gd"
SkillManager="*res://scripts/systems/skill_manager.gd"
MetaState="*res://scripts/systems/meta_state.gd"
ChapterManager="*res://scripts/systems/chapter_manager.gd"
```

**초기화 순서 보장**: EventBus → GameState → SkillManager → MetaState → ChapterManager.
- EventBus는 누구도 참조하지 않으므로 항상 먼저.
- MetaState `_ready()`는 SaveStore에서 JSON 로드 → GameState/SkillManager는 참조하지 않음.
- ChapterManager는 MetaState의 잠금/해금 데이터를 읽어야 하므로 마지막.
- 자동로드끼리 직접 함수 호출 금지. **모든 횡단 통신은 EventBus 시그널.**

### 2.1 EventBus (`scripts/systems/event_bus.gd`)

글로벌 시그널 카탈로그. 변수/상태 없음. 시그널만.

```gdscript
extends Node

# === 런 라이프사이클 ===
signal run_started(character_id: StringName, chapter_id: StringName)
signal run_ended(reason: StringName, stats: Dictionary)   # reason ∈ &"death"|&"clear"|&"abandon"
signal stage_started(chapter_id: StringName, stage_index: int)
signal stage_cleared(chapter_id: StringName, stage_index: int)
signal chapter_cleared(chapter_id: StringName, first_clear: bool)
signal intermission_entered(chapter_id: StringName)
signal intermission_exited(next_chapter_id: StringName)

# === 전투 / 생존 ===
signal player_damaged(amount: int, source: StringName)
signal player_healed(amount: int, source: StringName)
signal player_died()
signal player_revived(source: StringName)                 # source ∈ &"meta_revive"|&"item"
signal enemy_killed(enemy_id: StringName, pos: Vector2, by_skill: StringName)
signal boss_phase_changed(boss_id: StringName, phase_index: int)
signal boss_defeated(boss_id: StringName, time_taken: float, no_hit: bool)
signal boss_pattern_started(boss_id: StringName, pattern_id: StringName)
signal boss_pattern_telegraphed(pattern_id: StringName, duration: float)

# === 진행 ===
signal xp_collected(value: int)
signal gold_collected(value: int)
signal level_changed(new_level: int)
signal level_up_choices_offered(choices: Array)           # Array[Dictionary] (kind/id/data)
signal level_up_choice_selected(choice: Dictionary)
signal skill_acquired(skill_id: StringName, level: int)
signal skill_leveled(skill_id: StringName, new_level: int)
signal skill_evolved(from_ids: Array[StringName], to_id: StringName)

# === 메타 / 영속 ===
signal save_requested(reason: StringName)                  # &"autosave"|&"manual"|&"quit"
signal save_completed(success: bool)
signal meta_changed(key: StringName, new_value: Variant)   # currency / upgrades / unlocks
signal shinmok_advanced(new_stage: int)
signal achievement_unlocked(achievement_id: StringName)
signal character_unlocked(character_id: StringName)
signal codex_entry_unlocked(category: StringName, entry_id: StringName)

# === 이벤트 / 환경 ===
signal random_event_triggered(event_id: StringName, payload: Dictionary)
signal environment_entered(env_id: StringName, pos: Vector2)
signal environment_exited(env_id: StringName, pos: Vector2)
signal daily_challenge_progress(challenge_id: StringName, progress: int, target: int)

# === UI ===
signal toast_requested(text: String, duration: float)
signal hud_visibility_changed(visible: bool)
signal pause_requested(paused: bool)
```

> **사용 규칙**: 발신자는 자기 영역의 사실만 발신("적이 죽었다"), 의미 변환은 수신자가 한다("도전 진행도 +1"). 한 시그널을 두 자동로드가 동시에 듣는 건 정상 — 이중 처리만 막으면 된다.

### 2.2 GameState (`scripts/systems/game_state.gd`)

런 단위 휘발 상태. `EventBus.run_started`에서 `reset()`.

```gdscript
extends Node

# === 캐릭터/런 컨텍스트 ===
var character_id: StringName = &""
var character_data: CharacterData              # 활성 캐릭터 사본 (메타 보너스 적용 후)
var chapter_id: StringName = &""
var chapter_data: ChapterData
var stage_index: int = 0                       # 챕터 내 스테이지 0..N
var run_seed: int = 0                          # 결정적 의사난수 시드

# === 플레이어 스탯 (메타+캐릭터+런보너스 합산값) ===
var max_hp: int
var current_hp: int
var move_speed: float
var attack: int
var attack_speed: float
var pickup_radius: float
var luck_percent: float
var crit_percent: float
var cdr_percent: float
var intelligence: int                          # 스킬 데미지 계수 변수 INT

# === 진행 ===
var elapsed_run: float = 0.0
var elapsed_stage: float = 0.0
var level: int = 1
var current_xp: int = 0
var kill_count: int = 0
var gold: int = 0

# === 영구 보너스 (메타 강화에서 한 번 적용 후 변하지 않음) ===
var meta_bonus: Dictionary = {}                # key -> additive_or_mult
var revives_remaining: int = 0                 # MetaUpgrade "부활"에서 충전

# === 일시 상태 ===
var invuln_until: float = 0.0
var slow_until: float = 0.0; var slow_factor: float = 1.0
var no_hit_run: bool = true                    # 보스 무피격 트래커

# === API ===
func reset_for_run(char_id: StringName, ch_id: StringName) -> void
func apply_meta_bonuses() -> void              # MetaState에서 읽어와 max_hp/atk/ms/... 갱신
func add_xp(value: int) -> void                # 보너스 배율 후 누적, 임계치 도달 시 level_changed
func required_xp_for(lv: int) -> int           # 곡선: round(8 * lv ^ 1.55)
func deal_damage_to_player(amount: int, source: StringName) -> int   # 최종 데미지 반환
func heal_player(amount: int, source: StringName) -> void
func register_kill(enemy_id: StringName, pos: Vector2, by_skill: StringName) -> void
func add_gold(amount: int) -> void
func consume_revive() -> bool                  # 1소모 후 부활, false면 사망 확정
func snapshot_for_save() -> Dictionary         # 빈 사전(휘발 데이터는 저장 안 함; 통계는 MetaState로 발신)
```

### 2.3 SkillManager (`scripts/systems/skill_manager.gd`)

스킬 풀 + 보유 + 레벨링 + 진화. 캐릭터별 시작 가중치 반영.

```gdscript
extends Node

const MAX_SKILL_LEVEL: int = 5
const MAX_OWNED: int = 8                        # 액티브 6 + 패시브 2 (skills-full-spec §0.3 R7)
const OFFER_SIZE: int = 3

var skill_db: Dictionary = {}                   # StringName -> SkillData
var evolution_db: Dictionary = {}               # StringName -> EvolutionData
var owned: Dictionary = {}                      # id -> level (1..5)
var legendary_acquired_this_run: int = 0        # R0.3 한 런 최대 2종

func _ready() -> void
func reset_for_run(char_data: CharacterData) -> void
func is_owned(id: StringName) -> bool
func level_of(id: StringName) -> int
func can_offer(id: StringName) -> bool          # R2/R3/R7 검사
func acquire_or_level(id: StringName) -> void   # 신규 → 1렙, 보유 → +1 (cap 5)
func draw_three_cards() -> Array                # Array[Dictionary] (R1~R7 적용)
func check_evolution_candidates() -> Array      # 진화 가능 조합 반환
func perform_evolution(combo_id: StringName) -> void   # 재료 스킬 제거 → 진화 스킬 추가
```

진화 데이터는 `EvolutionData`(class_name): `requires: Array[StringName]` (재료 ID들, 모두 LV5 필요), `result: SkillData`, `min_chapter: int`(예: 3).

### 2.4 MetaState (`scripts/systems/meta_state.gd`)

영속 메타 상태. 모든 변경은 `save_requested`를 발신해 SaveStore가 처리.

```gdscript
extends Node

# === 재화 ===
var dokkaebi_orbs: int = 0
var shinmok_leaves: int = 0
var myth_shards: int = 0

# === 신목 ===
var shinmok_stage: int = 1                                    # 1..6 (meta-systems §2.1)

# === 영구 강화 8항목 ===
var upgrades: Dictionary = {}                                 # key(StringName) -> level(int, 0..5)
# keys: &"max_hp", &"attack", &"move_speed", &"xp_gain", &"gold_gain",
#       &"revive", &"choice_extra", &"luck"

# === 캐릭터 ===
var unlocked_characters: Array[StringName] = [&"ttukttaki"]
var character_affinity: Dictionary = {}                       # char_id -> int (친밀도 0..N)
var character_affinity_nodes: Dictionary = {}                 # char_id -> Array[StringName] (해금된 트리 노드)

# === 도감 ===
var codex_monsters: Dictionary = {}                           # monster_id -> {discovered, killed_count, first_seen_at}
var codex_relics: Dictionary = {}                             # relic_id -> {acquired, first_at}
var codex_places: Dictionary = {}                             # chapter_id -> {visited, cleared, first_at}

# === 도전 과제 ===
var achievements: Dictionary = {}                             # id -> {progress, target, unlocked, claimed}
var daily_seed_day: int = -1
var daily_active: Array[StringName] = []                      # 오늘의 3개
var daily_progress: Dictionary = {}                           # id -> int
var weekly_seed_week: int = -1
var weekly_active: Array[StringName] = []                     # 이번 주 1개
var weekly_progress: Dictionary = {}

# === 통계 ===
var stats: Dictionary = {                                     # 누적 통계
    "total_kills": 0, "total_bosses_defeated": 0, "total_runs": 0,
    "total_clears": 0, "total_deaths": 0, "total_gold_earned": 0,
    "play_time_seconds": 0.0,
}

# === 세이브 ===
var save_version: int = 2                                     # §7.3 마이그레이션 키
var last_save_at_unix: int = 0

# === API ===
func _ready() -> void                                         # SaveStore.load() 호출
func get_upgrade_level(key: StringName) -> int
func get_upgrade_effect(key: StringName) -> float             # MetaUpgradeData 참조
func apply_upgrade_purchase(key: StringName) -> bool          # 비용 검사 → 차감 → 레벨업
func can_unlock_character(id: StringName) -> bool             # 비용/조건 검사
func unlock_character(id: StringName) -> bool
func add_affinity(char_id: StringName, amount: int) -> void
func record_kill(enemy_id: StringName) -> void
func record_boss_defeated(boss_id: StringName, time_taken: float, no_hit: bool) -> int  # 정산 구슬
func advance_shinmok() -> bool                                # 비용 검사 → 단계 +1
func compute_run_settlement(stats_in: Dictionary) -> Dictionary  # final_orbs 계산 (§1.2.3 공식)
func update_daily_challenges(today_unix: int) -> void
func update_weekly_challenges(today_unix: int) -> void
func report_challenge_progress(challenge_id: StringName, delta: int) -> void
func is_codex_complete_for(category: StringName) -> bool
func snapshot_for_save() -> Dictionary                        # JSON 직렬화용
func restore_from_save(d: Dictionary) -> void
```

### 2.5 ChapterManager (`scripts/systems/chapter_manager.gd`)

챕터/스테이지 흐름 상태머신. `EventBus.run_started` 발신·수신을 모두 담당.

```gdscript
extends Node

enum FlowState {
    BOOT, MAIN_MENU, CHARACTER_SELECT, CHAPTER_SELECT, SHINMOK_SCREEN,
    LOADING, IN_STAGE, BOSS_BATTLE, INTERMISSION, RESULT, QUITTING
}

var state: FlowState = FlowState.BOOT
var current_character_id: StringName = &""
var current_chapter_id: StringName = &""
var current_stage_index: int = 0
var current_chapter_data: ChapterData

# === API ===
func goto_main_menu() -> void
func select_character(id: StringName) -> void
func select_chapter(id: StringName) -> void                   # 잠금 검사
func begin_run() -> void                                       # run_started 발신, GameState.reset
func enter_stage(index: int) -> void
func on_stage_cleared() -> void                                # 마지막 스테이지면 보스로
func enter_boss() -> void
func on_boss_defeated(boss_id: StringName, time: float, no_hit: bool) -> void
func enter_intermission() -> void                              # 상점/강화
func exit_intermission_to_next_chapter() -> void
func on_player_died() -> void                                  # 부활 가능 검사 → 실패 정산
func quit_to_main_menu() -> void

# === 흐름 헬퍼 ===
func is_chapter_unlocked(id: StringName) -> bool               # MetaState.shinmok_stage / codex 기반
func get_chapter_list() -> Array[ChapterData]
```

### 2.6 자동로드 의존성 다이어그램

```
project.godot 등록 순서 ↓                   런타임 호출 방향 →
┌──────────┐
│ EventBus │ ← 모두가 발신/수신 (싱글톤이지만 상태 없음)
└──────────┘
┌──────────┐    참조 없음 (다른 자동로드 직접 호출 금지)
│ GameState│
└──────────┘
┌──────────────┐  SkillData(resource) preload, GameState/MetaState는 EventBus 경유로만
│ SkillManager │
└──────────────┘
┌───────────┐   SaveStore(scripts/meta/save_store.gd) 호출, others EventBus
│ MetaState │
└───────────┘
┌────────────────┐  MetaState 직접 *읽기*만 허용(잠금 검사 등), 쓰기는 EventBus
│ ChapterManager │
└────────────────┘
```

> **읽기 허용 예외**: ChapterManager가 `MetaState.shinmok_stage`를 직접 읽는 것은 허용한다(잠금 검사는 빈번하고 동기). **쓰기**는 절대 직접 하지 않고 EventBus를 통해 MetaState가 자기 변경.

---

## 3. 데이터 리소스 클래스 스키마

모든 리소스는 `scripts/data/*.gd`에 `class_name`으로 정의, 실제 인스턴스는 `resources/*/`의 `.tres`. `@export`로 인스펙터 노출.

### 3.1 공통 enum (`scripts/data/enums.gd`)

```gdscript
class_name GameEnums

enum Element { NONE, FIRE, WATER, WOOD, METAL, EARTH }
enum Rarity { COMMON, RARE, LEGENDARY }
enum TriggerMode { AUTO, ACTIVE, PASSIVE, REACTIVE }          # SkillData.trigger_mode
enum RangedKind {                                              # EnemyData.ranged_kind
    NONE, STRAIGHT, HOMING, ARC, AOE_DROP, CHANNEL_BEAM
}
enum SpecialAbility {                                          # EnemyData.special_abilities (bitmask 가능)
    NONE,
    CHARGE,                # 돌진 (달걀귀신)
    DRAG_SLOW,             # 끌어당기기 (물귀신)
    GAZE_GROWTH,           # 응시 증대 (어둑시니)
    GROUP_SWARM,           # 군집
    SPAWN_MINIONS,         # 분열/소환
    PHASE_TELEPORT,        # 순간이동
    INVISIBLE,             # 은신
    EXPLODE_ON_DEATH,      # 자폭
    POISON_TRAIL,          # 독장판
    SHIELD_REGEN,          # 방어 재생
    ENRAGE_LOW_HP,         # 광폭화
    HEALER,                # 아군 회복
    CALL_REINFORCEMENTS,   # 증원 호출
    FREEZE,                # 빙결
    KNOCKBACK_AURA,        # 넉백 오라
    LIFESTEAL,             # 흡혈
    REFLECT,               # 데미지 반사
    PIERCE_SHIELD,         # 보호막 관통
    STATUS_CURSE           # 저주 부여
}
enum GroupAIKind {                                             # EnemyData.group_ai
    NONE,
    FLOCK_CENTER,          # 중심점 추적 + 오프셋
    LINE_FORMATION,        # 일렬 행진
    CIRCLE_FORMATION,      # 원형 포위
    RANDOM_SCATTER,        # 산개
    LEADER_FOLLOWERS       # 리더 1 + 추종자 N
}
enum BossPhaseTransition {                                     # BossData.phase_transition_mode
    HP_THRESHOLD,          # HP % 기반 (기본)
    HP_AND_TIME,           # HP 또는 경과 시간 (먼저 도래)
    TIMED_ONLY,            # 시간만
    SCRIPTED               # 페이즈별 특수 조건
}
enum PatternShape {                                            # BossPattern.shape
    CIRCLE_AOE, LINE_AOE, CONE_AOE, SCREEN_AOE,
    PROJECTILE_STRAIGHT, PROJECTILE_HOMING, PROJECTILE_BARRAGE,
    MELEE_LUNGE, SUMMON_MINIONS, BUFF_SELF, DEBUFF_PLAYER, GRAB
}
enum EnvKind { THORNBUSH, FOG, POISON_MARSH, TALISMAN_PILLAR, SPIRIT_ALTAR }
enum EventKind {
    GOBLIN_MARKET, SPIRIT_BLESSING, DEMON_CURSE, TREASURE_CHEST,
    WANDERING_DOKKAEBI, BLOOD_MOON, INVISIBLE_CAP
}
```

### 3.2 EnemyData (`scripts/data/enemy_data.gd`)

```gdscript
class_name EnemyData
extends Resource

# === 정체 ===
@export var id: StringName                                # &"m01_dokkaebibul" 등
@export var display_name_ko: String                       # "도깨비불"
@export_multiline var lore_ko: String = ""                # 도감용 출전/외형 설명
@export var sprite_size_px: Vector2i = Vector2i(16, 16)
@export var sprite_texture: Texture2D                     # null 이면 placeholder_color 사용
@export var placeholder_color: Color = Color.WHITE

# === 기본 스탯 (챕터 1 기준값; 스폰 시 스케일링 적용) ===
@export var base_hp: int = 10
@export var base_move_speed: float = 50.0                 # px/s
@export var base_contact_damage: int = 3
@export var attack_cooldown: float = 1.0
@export var detection_radius: float = 800.0
@export var hitbox_radius: float = 8.0

# === 원거리 공격 ===
@export var ranged_kind: GameEnums.RangedKind = GameEnums.RangedKind.NONE
@export var ranged_damage: int = 0
@export var ranged_range_px: float = 0.0
@export var ranged_projectile_speed: float = 0.0
@export var ranged_cooldown: float = 2.0
@export var ranged_telegraph: float = 0.0                 # 예고 시간(s), 0이면 즉발

# === 특수 능력 ===
@export var special_abilities: Array[GameEnums.SpecialAbility] = []   # 다중 가능
@export var special_params: Dictionary = {}               # {SpecialAbility -> {param: value}}
# 예: { SpecialAbility.DRAG_SLOW: { range: 200, slow: 0.4, duration: 3.0, cooldown: 5.0 } }

# === 군집/AI ===
@export var group_ai: GameEnums.GroupAIKind = GameEnums.GroupAIKind.NONE
@export var group_size: int = 1
@export var group_spacing_px: float = 30.0
@export var ai_aggression: float = 1.0                    # 0..1, 후퇴 빈도 역수

# === 보상 ===
@export var exp_value: int = 1
@export var gold_drop_chance: float = 0.0                 # 0..1
@export var gold_drop_amount: int = 0
@export var orb_value: int = 0                            # 0이면 금화 환산 (대부분 0)

# === 출현 ===
@export var chapters: Array[int] = [1]                    # 1..5, -1 = 히든
@export var spawn_weight: int = 100                       # 챕터 내 가중치
@export var min_stage_time_s: float = 0.0                 # 이 시점 이전엔 스폰 금지
@export var max_concurrent: int = 999                     # 화면 내 최대 동시 개수
```

### 3.3 BossData (`scripts/data/boss_data.gd`) + BossPhase / BossPattern

```gdscript
class_name BossData
extends Resource

@export var id: StringName
@export var display_name_ko: String
@export_multiline var lore_ko: String = ""
@export var sprite_size_px: Vector2i = Vector2i(80, 56)
@export var sprite_texture: Texture2D
@export var hitbox_size_px: Vector2 = Vector2(64, 40)
@export var is_mini_boss: bool = false                    # 미니보스 5종 / 챕터보스 6종

# === 기본 스탯 ===
@export var hp: int = 1800
@export var armor: int = 0                                # 최종피해 = max(1, in - armor*0.7)
@export var base_move_speed: float = 150.0
@export var melee_damage: int = 14

# === 페이즈 ===
@export var phase_transition_mode: GameEnums.BossPhaseTransition = GameEnums.BossPhaseTransition.HP_THRESHOLD
@export var phases: Array[BossPhase] = []                 # 보통 2~3개

# === 컷인/연출 ===
@export var intro_cutscene_id: StringName = &""           # PackedScene id (CutsceneRegistry)
@export var intro_duration_s: float = 2.5
@export var death_cutscene_duration_s: float = 2.0
@export var theme_bgm: AudioStream
@export var spawn_se: AudioStream
@export var defeat_se: AudioStream

# === 보상 ===
@export var first_kill_orbs: int = 50
@export var first_kill_leaves: int = 0
@export var rekill_orbs: int = 5
@export var grants_codex_entry: StringName = &""

# === 출현 ===
@export var chapter: int = 1
@export var trigger_time_s: float = 225.0                 # 미니보스 3:45
@export var seal_stone_skippable: bool = true             # 봉인석 파괴 시 즉시 등장
```

```gdscript
class_name BossPhase
extends Resource

@export var phase_index: int = 0
@export var hp_threshold_percent: float = 1.0             # 이 페이즈로 들어가는 임계 (1.0 = 시작)
@export var time_threshold_s: float = 0.0                 # HP_AND_TIME 모드에서 사용
@export var transition_invuln_s: float = 1.5
@export var transition_camera_shake: float = 0.3          # 0..1
@export var transition_vfx_id: StringName = &""
@export var idle_min_s: float = 0.6
@export var idle_max_s: float = 1.4
@export var pattern_queue: Array[BossPattern] = []        # 가중치 랜덤, 직전 패턴 -50%
@export var move_speed_mult: float = 1.0
@export var damage_mult: float = 1.0
@export var keyword_ko: String = ""                       # 디버그/도감용 "유인기" 등
```

```gdscript
class_name BossPattern
extends Resource

@export var id: StringName
@export var display_name_ko: String
@export var shape: GameEnums.PatternShape
@export var weight: int = 10                              # 선택 가중치
@export var cooldown_s: float = 5.0

# === 텔레그래프 ===
@export var telegraph_duration_s: float = 1.0
@export var telegraph_vfx_id: StringName = &""            # "red_circle"/"red_line"/"red_vignette"
@export var telegraph_se: AudioStream

# === 판정 ===
@export var hitbox_radius_px: float = 80.0                # 원형/콘 공통
@export var hitbox_length_px: float = 0.0                 # 직선/콘 길이
@export var hitbox_angle_deg: float = 60.0                # 콘 각도
@export var damage: int = 20
@export var status_effect: StringName = &""               # &""|&"burn"|&"slow"|&"stun"|&"poison"|&"curse"
@export var status_duration_s: float = 0.0
@export var knockback_px: float = 0.0

# === 투사체/소환 파라미터 ===
@export var projectile_speed: float = 0.0
@export var projectile_count: int = 1
@export var projectile_spread_deg: float = 0.0
@export var summon_enemy_id: StringName = &""
@export var summon_count: int = 0
```

### 3.4 SkillData (`scripts/data/skill_data.gd`) + SkillLevel

```gdscript
class_name SkillData
extends Resource

@export var id: StringName                                # &"fire_01_dokkaebibul"
@export var display_name_ko: String                       # "도깨비불"
@export_multiline var description_ko: String = ""
@export var element: GameEnums.Element
@export var rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON
@export var trigger_mode: GameEnums.TriggerMode = GameEnums.TriggerMode.AUTO
@export var scene: PackedScene                            # Player.SkillAnchor에 인스턴스화
@export var icon_color: Color = Color.WHITE
@export var icon_texture: Texture2D

# === 레벨링 ===
@export var max_level: int = 5
@export var levels: Array[SkillLevel] = []                # 정확히 5개 (LV1..LV5)

# === 등장 조건 ===
@export var min_chapter_to_offer: int = 1                 # 일부 전설은 3
@export var character_weight_overrides: Dictionary = {}   # char_id -> float (시작 가중치)

# === 시너지/진화 ===
@export var synergy_partners: Array[StringName] = []      # 상생 쌍
@export var counter_partners: Array[StringName] = []      # 상극 쌍
@export var evolution_targets: Array[StringName] = []     # 진화 가능 결과 ID 들
```

```gdscript
class_name SkillLevel
extends Resource

@export var damage_formula: String = "8 + INT*0.2"        # 평가 가능한 표현식
@export var damage_base: float = 8.0                      # 파싱 실패 시 폴백
@export var damage_int_coef: float = 0.2
@export var cooldown_s: float = 8.0
@export var range_px: float = 80.0
@export var radius_px: float = 0.0
@export var duration_s: float = 0.0
@export var tick_interval_s: float = 0.0                  # DoT/오라용
@export var projectile_count: int = 0
@export var projectile_speed: float = 0.0
@export var status_effect: StringName = &""               # &"burn"|&"slow"|&"stun"|...
@export var status_potency: float = 0.0                   # %감속, DoT/s, 등
@export var status_duration_s: float = 0.0
@export var stack_max: int = 1
@export var extras: Dictionary = {}                       # 스킬 특수 파라미터 (회전속도 deg/s 등)
```

> **레벨별 수치 5개를 한 줄에 적지 않고 `Array[SkillLevel]`로 분리**하는 이유: 인스펙터에서 직접 LV3만 수정할 수 있고, 진화 결과물도 같은 클래스로 재사용 가능.

### 3.5 CharacterData (`scripts/data/character_data.gd`) + AffinityNode

```gdscript
class_name CharacterData
extends Resource

@export var id: StringName                                # &"ttukttaki", &"hwari", ...
@export var display_name_ko: String
@export_multiline var lore_ko: String = ""
@export var sprite_size_px: Vector2i = Vector2i(48, 48)
@export var sprite_texture: Texture2D
@export var portrait_texture: Texture2D                   # 캐릭터 선택 화면용

# === 기본 스탯 (메타 미강화) ===
@export var base_hp: int = 100
@export var base_move_speed: float = 100.0
@export var base_attack: int = 10
@export var base_attack_speed: float = 1.0
@export var base_pickup_radius: float = 60.0
@export var base_luck: float = 0.0
@export var base_crit: float = 5.0
@export var base_cdr: float = 0.0
@export var base_intelligence: int = 10

# === 무기 ===
@export var weapon_scene: PackedScene                     # 캐릭터별 변형 가능
@export var weapon_radius_px: float = 70.0
@export var weapon_damage_coef: float = 1.0               # ATK × coef
@export var weapon_hit_cooldown_s: float = 1.0
@export var weapon_max_targets: int = 6

# === 고유 패시브 / 궁극기 ===
@export var passive_id: StringName                        # &"goblin_merchants_touch" 등
@export var passive_params: Dictionary = {}               # {"gold_mult": 1.20}
@export var ultimate_id: StringName
@export var ultimate_cooldown_s: float = 45.0
@export var ultimate_params: Dictionary = {}

# === 시작 스킬 가중치 ===
@export var start_weight_overrides: Dictionary = {}       # skill_id -> float (×1.0 기준)

# === 해금 ===
@export var unlock_cost_orbs: int = 0
@export var unlock_requires: Array[StringName] = []       # &"clear_chapter_1" 등 조건 ID
@export var unlocked_by_default: bool = false

# === 친밀도 트리 ===
@export var affinity_tree: Array[AffinityNode] = []
@export var affinity_max: int = 20                        # 친밀도 만렙
```

```gdscript
class_name AffinityNode
extends Resource

@export var id: StringName                                # &"ttukttaki_t_root", &"ttukttaki_t_left_01" ...
@export var affinity_required: int = 3                    # 친밀도 N에서 해금
@export var prerequisites: Array[StringName] = []         # 선행 노드 ID들
@export var branch: StringName = &"trunk"                 # &"trunk"|&"left"|&"right"
@export var display_name_ko: String
@export_multiline var description_ko: String
@export var effect_kind: StringName                       # &"stat_mult"|&"skill_unlock"|&"new_passive"
@export var effect_params: Dictionary = {}
```

### 3.6 ChapterData (`scripts/data/chapter_data.gd`)

```gdscript
class_name ChapterData
extends Resource

@export var id: StringName                                # &"ch01_dumeong"
@export var display_name_ko: String                       # "두멍마을"
@export var chapter_number: int = 1                       # 1..6
@export_multiline var description_ko: String = ""
@export var background_color: Color = Color("#2A2A35")
@export var background_texture: Texture2D
@export var ambient_bgm: AudioStream
@export var unlock_shinmok_required: int = 1              # MetaState.shinmok_stage 최소값
@export var unlock_requires: Array[StringName] = []       # &"clear_ch01" 등

# === 스테이지 구성 ===
@export var stage_count: int = 3                          # 챕터 내 일반 스테이지 수
@export var stage_duration_s: float = 300.0               # 스테이지당 5분

# === 스폰 ===
@export var enemy_pool: Array[StringName] = []            # 챕터 등장 적 ID 들
@export var enemy_weights: Dictionary = {}                # enemy_id -> int (가중치)
@export var hp_scale: float = 1.0                         # 챕터별 배율 (monsters §0.2 표 그대로)
@export var damage_scale: float = 1.0
@export var move_speed_scale: float = 1.0
@export var spawn_curve_id: StringName = &"default"       # SpawnCurves 리소스 키

# === 보스 ===
@export var mini_boss_id: StringName = &""                # 3:45 등장
@export var chapter_boss_id: StringName = &""             # 최종

# === 환경/이벤트 ===
@export var environment_pool: Array[GameEnums.EnvKind] = []
@export var environment_density: float = 0.4              # 0..1
@export var event_pool: Array[GameEnums.EventKind] = []
@export var event_probability_per_min: float = 0.25

# === 보상 ===
@export var clear_base_orbs: int = 30
@export var clear_first_bonus_orbs: int = 0
@export var hard_mode_unlocked: bool = false              # 신목 Lv.5+에서 활성
@export var hard_difficulty_mult: float = 1.5
```

### 3.7 MetaUpgradeData (`scripts/data/meta_upgrade_data.gd`)

8개 영구 강화의 비용/효과 표.

```gdscript
class_name MetaUpgradeData
extends Resource

@export var key: StringName                               # &"max_hp", &"attack", &"move_speed",
                                                          # &"xp_gain", &"gold_gain",
                                                          # &"revive", &"choice_extra", &"luck"
@export var display_name_ko: String
@export_multiline var description_ko: String = ""
@export var icon_texture: Texture2D
@export var max_level: int = 5
@export var costs_orbs: Array[int] = [50, 100, 200, 400, 800]
                                                          # 길이 = max_level, [LV1, LV2, ... LV5]
@export var effects: Array[float] = [0.10, 0.20, 0.35, 0.55, 0.80]
                                                          # 의미는 effect_kind에 따라
@export var effect_kind: StringName = &"additive_percent" # &"additive_percent"|&"additive_flat"|&"count"
@export var apply_target: StringName                      # &"max_hp"|&"attack"|&"move_speed"|...
@export var requires_shinmok_stage: int = 1
```

#### 3.7.1 8개 영구 강화 — 비용/효과 표 (확정값)

| key | 적용 대상 | LV1 효과 | LV2 | LV3 | LV4 | LV5 | LV1 비용 | LV2 | LV3 | LV4 | LV5 | 합계 |
|-----|----------|----------|-----|-----|-----|-----|----------|-----|-----|-----|-----|------|
| `max_hp` | 최대 HP +%  | +5% | +10% | +18% | +28% | +40% | 30 | 60 | 120 | 240 | 480 | 930 |
| `attack` | ATK +% | +4% | +8% | +14% | +22% | +32% | 40 | 80 | 160 | 320 | 640 | 1240 |
| `move_speed` | 이동속도 +% | +3% | +6% | +10% | +15% | +20% | 35 | 70 | 140 | 280 | 560 | 1085 |
| `xp_gain` | EXP 획득 +% | +5% | +10% | +18% | +28% | +40% | 30 | 60 | 120 | 240 | 480 | 930 |
| `gold_gain` | 금화 획득 +% | +8% | +16% | +28% | +44% | +65% | 25 | 50 | 100 | 200 | 400 | 775 |
| `revive` | 부활 횟수 +1 | 1 | 2 | 2 | 3 | 3 | 100 | 250 | 500 | 1000 | 2000 | 3850 |
| `choice_extra` | 레벨업 3택 → 4택 확률 +% | +5% | +10% | +18% | +28% | +40% | 60 | 120 | 240 | 480 | 960 | 1860 |
| `luck` | 고급↑ 등장 확률 +%p | +2 | +4 | +7 | +11 | +16 | 50 | 100 | 200 | 400 | 800 | 1550 |

(누적 만렙 합계 ≈ 12,220 구슬. 신목 단계 잠금 — `revive` Lv4 이상은 신목 Lv.4 필요, `choice_extra` Lv3 이상은 Lv.3 필요.)

> `effect_kind = "additive_percent"`이면 `apply_target` 변수에 `(1 + effect[level-1])`을 곱한다. `"count"`(revive)는 `effect[level-1]`을 정수로 캐스팅해 카운트로. `"additive_flat"`은 그대로 더한다.

---

## 4. 챕터/스테이지 흐름 다이어그램

### 4.1 상위 흐름 (ChapterManager.FlowState)

```
                       ┌──────────────────────────────────────────────────┐
                       │                                                  ▼
[BOOT]                 │                                          ┌───────────────┐
   │ SaveStore.load()  │                                          │  MAIN_MENU    │
   ▼                   │                                          │ scenes/main_  │
[MAIN_MENU] ──────────┴── "캐릭터" ─────────────────────────────► │ menu.tscn     │
   │ "시작"                                                       └───────┬───────┘
   ▼                                                                       │
[CHARACTER_SELECT] ── unlocked 캐릭터 grid                          ▲      │
   │ 선택                                                           │      │
   ▼                                                       quit_to_menu    │
[CHAPTER_SELECT] ── unlocked 챕터 list (신목 잠금/하드 표시)         │      │
   │ 챕터 선택                                                     │      │
   ▼                                                                │      │
[LOADING] (0.6s 페이드)                                              │      │
   │ run_started 발신                                                │      │
   ▼                                                                │      │
┌────────────────────────────────────────────┐                       │      │
│  IN_STAGE (loop until stage_count 도달)    │                       │      │
│    ┌─────────────────────────────────┐    │                       │      │
│    │ Stage 0 (5분)                   │    │                       │      │
│    │  - EnemySpawner 가동            │    │                       │      │
│    │  - 환경/이벤트 트리거            │    │                       │      │
│    │  - 3:45 mini_boss_id 트리거     │    │                       │      │
│    │  - 5:00 stage_cleared            │    │                       │      │
│    └─────────────────────────────────┘    │                       │      │
│              │                              │                       │      │
│              ▼                              │                       │      │
│    if last_stage → BOSS_BATTLE              │                       │      │
│    else → next Stage                        │                       │      │
└────────────────────────────────────────────┘                       │      │
   │ 마지막 스테이지 종료                                              │      │
   ▼                                                                  │      │
[BOSS_BATTLE]                                                          │      │
   │ chapter_boss_id 등장 (IntroCutscene 2.5s)                         │      │
   │ boss_defeated or player_died                                      │      │
   ▼                                                                  │      │
[INTERMISSION] (보스 처치 시)                                          │      │
   │ scenes/gameplay/intermission.tscn                                 │      │
   │  - 도깨비 시장 / 영구 강화 / 캐릭터 친밀도                          │      │
   │  - "다음 챕터로" or "그만두기"                                     │      │
   ▼                                                                  │      │
[CHAPTER_SELECT] (다음 챕터 자동 선택) ─── 다음 챕터 시작 ─────────┐    │      │
                                                              │    │      │
[RESULT] (사망 또는 마지막 챕터 클리어)                          │    │      │
   │ MetaState.compute_run_settlement 호출 → save_requested      │    │      │
   │  - 통계 카운트업                                            │    │      │
   │  - "다시 도전" / "메인 메뉴"                                 │    │      │
   ▼                                                            │    │      │
[MAIN_MENU] ◄───────────────────────────────────────────────────┴────┘      │
                                                                            │
[SHINMOK_SCREEN] (메인 메뉴 → 신목 강화/도감/도전) ◄───── "신목" 버튼 ───────┘
```

### 4.2 씬 전환 메커니즘

- `Main.tscn` (scenes/gameplay/main.tscn) 루트는 `SceneContainer`(Node)와 `FadeOverlay`(CanvasLayer)만 보유.
- ChapterManager가 `change_scene(new_scene: PackedScene)` 호출 → 0.4s 페이드아웃 → 기존 child `queue_free` → 신규 인스턴스 add → 페이드인.
- 어떤 화면에서도 `EventBus.pause_requested(true)` 발신 시 `get_tree().paused = true`로 전환. 일시정지 패널 외 모든 노드 `PROCESS_MODE_PAUSABLE`.

### 4.3 상태 전이 표 (정확 명세)

| From | Trigger | To | 사이드 이펙트 |
|------|---------|----|--------------|
| BOOT | `_ready` 완료 | MAIN_MENU | SaveStore.load → MetaState 복원 |
| MAIN_MENU | "시작" 버튼 | CHARACTER_SELECT | 캐릭터 grid 렌더 |
| MAIN_MENU | "신목" 버튼 | SHINMOK_SCREEN | — |
| CHARACTER_SELECT | 캐릭터 선택 + "다음" | CHAPTER_SELECT | `current_character_id` 설정 |
| CHAPTER_SELECT | 챕터 선택 + "시작" | LOADING | `current_chapter_id` 설정 |
| LOADING | 페이드 완료 | IN_STAGE | GameScene 인스턴스화, `run_started` 발신 |
| IN_STAGE | stage_clear (5분) | IN_STAGE (다음) or BOSS_BATTLE (마지막 스테이지) | 페이드 또는 BossSpawn 트리거 |
| BOSS_BATTLE | boss_defeated | INTERMISSION | 보상 정산 시그널 발신 |
| BOSS_BATTLE | player_died (부활 0) | RESULT | run_ended(&"death") |
| BOSS_BATTLE | player_died (부활 ≥1) | BOSS_BATTLE | revive 소모, 보스 무피격 플래그 해제 |
| INTERMISSION | "다음 챕터" | LOADING | 다음 챕터 id 자동 |
| INTERMISSION | "그만두기" | RESULT | run_ended(&"clear", 챕터=N) |
| 모든 IN_STAGE/BOSS | "메인 메뉴" (Pause) | MAIN_MENU | run_ended(&"abandon") |
| RESULT | "다시 도전" | LOADING | 같은 캐릭터+챕터로 재시작 |
| RESULT | "메인 메뉴" | MAIN_MENU | — |
| SHINMOK_SCREEN | "뒤로" | MAIN_MENU | save_requested 발신 |

---

## 5. 보스전 시스템 설계

### 5.1 BossBase (`scripts/bosses/boss_base.gd`)

11종 보스가 공통으로 상속. 페이즈/패턴 큐/텔레그래프/컷인 hook을 일반화.

```gdscript
class_name BossBase
extends CharacterBody2D

@export var data: BossData                            # @export로 인스턴스 씬에 주입

# === 런타임 상태 ===
var current_phase_index: int = 0
var current_phase: BossPhase
var current_hp: int
var last_pattern_id: StringName = &""
var pattern_cooldowns: Dictionary = {}                # pattern_id -> ready_at_time
var fsm_state: StringName = &"intro"                  # &"intro"|&"idle"|&"telegraph"|&"pattern"|&"recover"|&"transition"|&"dying"
var fsm_timer: float = 0.0
var spawn_time: float = 0.0
var no_hit: bool = true
var invuln: bool = true                               # intro/transition 동안 true

@onready var sprite: Sprite2D = $Sprite
@onready var hurtbox: Area2D = $HurtBox
@onready var telegraph_layer: Node2D = $TelegraphLayer
@onready var pattern_anchor: Node2D = $PatternAnchor

# === 표준 라이프사이클 ===
func _ready() -> void:
    _apply_data(data)
    current_phase = data.phases[0]
    spawn_time = Time.get_unix_time_from_system()
    _play_intro_cutscene()

func _physics_process(delta: float) -> void:
    fsm_timer += delta
    match fsm_state:
        &"intro": _tick_intro(delta)
        &"idle": _tick_idle(delta)
        &"telegraph": _tick_telegraph(delta)
        &"pattern": _tick_pattern(delta)
        &"recover": _tick_recover(delta)
        &"transition": _tick_transition(delta)
        &"dying": _tick_dying(delta)

# === 페이즈 전환 (HP 기반) ===
func _check_phase_transition() -> bool:
    if current_phase_index + 1 >= data.phases.size():
        return false
    var next: BossPhase = data.phases[current_phase_index + 1]
    var hp_ratio: float = float(current_hp) / float(data.hp)
    var due: bool = false
    match data.phase_transition_mode:
        GameEnums.BossPhaseTransition.HP_THRESHOLD:
            due = hp_ratio <= next.hp_threshold_percent
        GameEnums.BossPhaseTransition.HP_AND_TIME:
            due = hp_ratio <= next.hp_threshold_percent or fsm_timer >= next.time_threshold_s
        GameEnums.BossPhaseTransition.TIMED_ONLY:
            due = (Time.get_unix_time_from_system() - spawn_time) >= next.time_threshold_s
        GameEnums.BossPhaseTransition.SCRIPTED:
            due = _scripted_transition_due(current_phase_index + 1)
    if due:
        _begin_phase_transition(current_phase_index + 1)
    return due

func _begin_phase_transition(new_index: int) -> void:
    fsm_state = &"transition"
    invuln = true
    fsm_timer = 0.0
    EventBus.boss_phase_changed.emit(data.id, new_index)
    _on_phase_transition_started(new_index)            # virtual hook
    _spawn_transition_vfx(current_phase.transition_vfx_id)
    _camera_shake(current_phase.transition_camera_shake)

func _tick_transition(delta: float) -> void:
    if fsm_timer >= current_phase.transition_invuln_s:
        current_phase_index += 1
        current_phase = data.phases[current_phase_index]
        invuln = false
        fsm_state = &"idle"
        fsm_timer = 0.0
        _on_phase_transition_completed(current_phase_index) # virtual hook

# === 패턴 큐 ===
func _select_next_pattern() -> BossPattern:
    var now: float = Time.get_unix_time_from_system()
    var candidates: Array[BossPattern] = []
    var weights: Array[int] = []
    for p in current_phase.pattern_queue:
        if pattern_cooldowns.get(p.id, 0.0) <= now:
            var w: int = p.weight
            if p.id == last_pattern_id:
                w = int(w * 0.5)
            candidates.append(p)
            weights.append(w)
    if candidates.is_empty():
        return null
    var pick: int = _weighted_random_index(weights)
    return candidates[pick]

# === 텔레그래프 hook ===
func _tick_telegraph(delta: float) -> void:
    if fsm_timer >= _telegraph_remaining():
        fsm_state = &"pattern"
        fsm_timer = 0.0
        _execute_pattern(_pending_pattern)              # virtual

# 보스별 서브클래스가 오버라이드하는 hook들:
func _on_phase_transition_started(_new_index: int) -> void: pass     # 외형 변화
func _on_phase_transition_completed(_new_index: int) -> void: pass   # 페이즈별 특수 셋업
func _execute_pattern(_pattern: BossPattern) -> void:                # 실제 데미지 판정
    # 기본 구현: shape 별 디스패치 → _exec_circle_aoe / _exec_line_aoe / ...
    pass
func _scripted_transition_due(_index: int) -> bool: return false
func _play_intro_cutscene() -> void:                                 # 기본 cutscene
    var c: Node = CutsceneRegistry.spawn(data.intro_cutscene_id)
    if c:
        add_child(c)
        await c.finished
    fsm_state = &"idle"; invuln = false

# === 피격 ===
func take_damage(amount: int, source: StringName) -> void:
    if invuln: return
    no_hit = false if source != &"" else no_hit       # 비-환경 데미지면 무피격 해제
    var final_dmg: int = max(1, amount - int(data.armor * 0.7))
    current_hp -= final_dmg
    if current_hp <= 0:
        _die()
    else:
        _check_phase_transition()

func _die() -> void:
    fsm_state = &"dying"
    invuln = true
    EventBus.boss_defeated.emit(data.id, Time.get_unix_time_from_system() - spawn_time, no_hit)
```

### 5.2 텔레그래프 일반화 (`scripts/bosses/telegraph.gd`)

```gdscript
class_name Telegraph
extends Node2D

@export var vfx_kind: StringName = &"red_circle"      # &"red_circle"|&"red_line"|&"red_cone"|&"red_vignette"
@export var duration_s: float = 1.0
@export var radius_px: float = 80.0
@export var length_px: float = 0.0
@export var angle_deg: float = 60.0
@export var follow_target: Node2D                     # 옵션 (예: 플레이어 따라가는 장판)

signal expired

func start() -> void                                  # 0→1 채워지는 셰이더 또는 알파 트윈
func cancel() -> void
```

`BossBase._tick_telegraph` 안에서 `Telegraph` 인스턴스를 `telegraph_layer`에 add하고 `expired` 신호를 듣는다. 패턴이 실제 데미지 판정을 시작하는 시점은 Telegraph가 expire한 그 프레임.

### 5.3 컷인 연출 (`scripts/bosses/cutscene.gd` + CutsceneRegistry)

```gdscript
class_name BossCutscene
extends CanvasLayer

signal finished

@export var duration_s: float = 2.5
@export var portrait_texture: Texture2D
@export var name_label_ko: String
@export var subtitle_label_ko: String
@export var bg_color: Color = Color(0, 0, 0, 0.7)

func play() -> void:
    # 1) 화면 어둡게 페이드 in
    # 2) 보스 이름 + 출전 한 줄 페이드 in
    # 3) duration_s 대기
    # 4) 페이드 out → emit_signal("finished")
```

`CutsceneRegistry`는 `scripts/systems/cutscene_registry.gd`의 일반 노드(자동로드 아님) — `spawn(id) -> Node`로 `BossCutscene` 또는 `DeathCutscene` 인스턴스를 반환. `id`는 `BossData.intro_cutscene_id`에 박힌 StringName.

### 5.4 보스별 페이즈 데이터 예 (장산범 MB01)

`resources/bosses/mb01_jangsanbeom.tres`:
```
data.hp = 1800, armor = 2
phases = [
  BossPhase(
    phase_index = 0,
    hp_threshold_percent = 1.0,
    transition_invuln_s = 1.5,
    idle_min_s = 0.8, idle_max_s = 1.4,
    pattern_queue = [pattern_jb_voice_lure, pattern_jb_charge, pattern_jb_claw],
    keyword_ko = "유인기",
  ),
  BossPhase(
    phase_index = 1,
    hp_threshold_percent = 0.40,
    transition_invuln_s = 2.0,
    transition_camera_shake = 0.5,
    idle_min_s = 0.5, idle_max_s = 1.0,
    pattern_queue = [pattern_jb_charge, pattern_jb_claw, pattern_jb_roar],
    move_speed_mult = 1.3,
    damage_mult = 1.2,
    keyword_ko = "광폭",
  ),
]
```

---

## 6. 메타 성장 시스템 설계

### 6.1 MetaState 저장 키 구조

`MetaState.snapshot_for_save()`가 만드는 JSON 직렬화 사전. 본 사전 그대로 `user://save.json`의 `meta` 필드에 저장된다.

```jsonc
{
  "version": 2,
  "saved_at": 1747200000,
  "currency": {
    "dokkaebi_orbs": 0,
    "shinmok_leaves": 0,
    "myth_shards": 0
  },
  "shinmok": {
    "stage": 1
  },
  "upgrades": {
    "max_hp": 0, "attack": 0, "move_speed": 0,
    "xp_gain": 0, "gold_gain": 0,
    "revive": 0, "choice_extra": 0, "luck": 0
  },
  "characters": {
    "unlocked": ["ttukttaki"],
    "affinity": { "ttukttaki": 0 },
    "affinity_nodes": { "ttukttaki": [] }
  },
  "codex": {
    "monsters": { "m01_dokkaebibul": { "discovered": false, "killed_count": 0, "first_seen_at": 0 } },
    "relics":   { "shinmok_leaf":     { "acquired": false, "first_at": 0 } },
    "places":   { "ch01_dumeong":     { "visited": false, "cleared": false, "first_at": 0 } }
  },
  "achievements": {
    "first_kill":  { "progress": 0, "target": 1, "unlocked": false, "claimed": false }
  },
  "challenges": {
    "daily_seed_day": -1, "daily_active": [], "daily_progress": {},
    "weekly_seed_week": -1, "weekly_active": [], "weekly_progress": {}
  },
  "stats": {
    "total_kills": 0, "total_bosses_defeated": 0, "total_runs": 0,
    "total_clears": 0, "total_deaths": 0, "total_gold_earned": 0,
    "play_time_seconds": 0.0
  }
}
```

### 6.2 신목 6단계 데이터 모델

```gdscript
class_name ShinmokStageData
extends Resource

@export var stage: int = 1                              # 1..6
@export var display_name_ko: String                     # "묘목" / "어린 나무" / ... / "신목"
@export var orb_cost_to_advance: int = 0                # 다음 단계로 가는 비용
@export var leaf_cost_to_advance: int = 0
@export var unlocks: Array[StringName] = []             # &"chapter_2", &"meta_revive_lv4" 등
@export var visual_texture: Texture2D
@export var grants_orbs_on_reach: int = 0
@export var grants_shards_on_reach: int = 0
```

`resources/meta_upgrades/shinmok_stages.tres` (Array[ShinmokStageData] 길이 6):

| stage | name | orb→next | leaf→next | unlocks (도달 시) | 보상 |
|-------|------|---------|----------|--------------------|------|
| 1 | 묘목 | 300 | 1 | (기본) | — |
| 2 | 어린 나무 | 800 | 2 | chapter_2, meta_choice_extra_lv3 | +50 구슬 |
| 3 | 자라는 나무 | 2,000 | 3 | chapter_3, evolution_unlocked, legendary_pool | +100 구슬, +1 신화 조각 |
| 4 | 큰 나무 | 4,500 | 4 | chapter_4, meta_revive_lv4, hidden_chapter | +200 구슬 |
| 5 | 우람한 나무 | 10,000 | 5 | chapter_5, hard_mode | +400 구슬, +3 신화 조각 |
| 6 | 신목 | — | — | infinite_mode, codex_extras | +800 구슬, +5 신화 조각, +1 캐릭터 슬롯 |

> 신목 단계는 메타 게이트로 사용. `ChapterData.unlock_shinmok_required`와 `MetaUpgradeData.requires_shinmok_stage` 양쪽에서 참조.

### 6.3 영구 강화 8항목

§3.7.1의 표를 그대로 사용. `resources/meta_upgrades/meta_{key}.tres` 8개.

각 강화 적용은 `GameState.apply_meta_bonuses()`에서 한 번에 처리:

```
for key in [&"max_hp", &"attack", &"move_speed", &"xp_gain", &"gold_gain", &"luck"]:
    var lv: int = MetaState.get_upgrade_level(key)
    if lv > 0:
        var mult: float = MetaUpgradeData[key].effects[lv-1]   # 0.05, 0.10, ...
        match key:
            &"max_hp":      max_hp = int(max_hp * (1.0 + mult))
            &"attack":      attack = int(attack * (1.0 + mult))
            &"move_speed":  move_speed *= (1.0 + mult)
            &"xp_gain":     bonus_xp_gain_mult *= (1.0 + mult)
            &"gold_gain":   bonus_gold_gain_mult *= (1.0 + mult)
            &"luck":        luck_percent += mult * 100.0       # additive %p
current_hp = max_hp
revives_remaining = int(MetaUpgradeData[&"revive"].effects[MetaState.get_upgrade_level(&"revive")-1]) if lv > 0 else 0
choice_extra_chance = MetaUpgradeData[&"choice_extra"].effects[lv-1] if lv > 0 else 0.0
```

### 6.4 캐릭터 해금 / 친밀도 트리

#### 해금
- 조건: `CharacterData.unlock_requires` 모두 만족 + `unlock_cost_orbs` 보유.
- 처리: `MetaState.unlock_character(id)` → `unlocked_characters` 추가 → `EventBus.character_unlocked` 발신.
- 메인 메뉴 캐릭터 선택 화면에서 잠금 사유 표시("챕터 3 클리어 필요" 등).

#### 친밀도
- 획득 경로:
  - 같은 캐릭터로 챕터 클리어: +2 친밀도
  - 보스 첫 처치: +1
  - 선물 상자(50 구슬): +1 (도깨비 시장 이벤트)
  - 도전 과제: 특정 도전에 +N
- 친밀도 노드 해금:
  - `affinity_required` 도달 시 자동 해금? NO — 사용자가 메인 메뉴 친밀도 트리 화면에서 명시적으로 "해금" 클릭(자원 소모는 없음, 단지 선택). 분기 노드는 한 쪽만 선택 가능.
  - 노드 효과는 `AffinityNode.effect_kind`에 따라:
    - `&"stat_mult"`: `effect_params = {"target": "attack", "mult": 1.10}` → CharacterData 사본 스탯에 적용
    - `&"skill_unlock"`: 시작 시 해당 스킬 LV1 보유
    - `&"new_passive"`: 새 패시브 ID 부여

데이터: `resources/characters/affinity_{character}.tres` (Array[AffinityNode]).

### 6.5 도감 데이터 구조

3개 카테고리 × N 엔트리.

```jsonc
"codex": {
  "monsters": {
    "m01_dokkaebibul": {
      "discovered": true,           // 한 번이라도 조우
      "killed_count": 142,
      "first_seen_at": 1747100000
    },
    // ... 53개 + 11 보스
  },
  "relics": {
    "shinmok_leaf":     { "acquired": true, "first_at": 1747100000 },
    "dokkaebi_bangmangi": { "acquired": false, "first_at": 0 },
    // 신물 N개
  },
  "places": {
    "ch01_dumeong":     { "visited": true, "cleared": true, "first_at": 1747100000 },
    "ch01_hidden_well": { "visited": false, "cleared": false, "first_at": 0 },
    // 챕터 6 + 히든 장소들
  }
}
```

수신 시그널:
- `enemy_killed` → `codex.monsters[id].killed_count += 1`, 최초면 `discovered = true`, `first_seen_at` 기록.
- `boss_defeated` → 위와 동일 + `record_boss_defeated()` 정산.
- `chapter_cleared` → `codex.places[id].cleared = true`.
- `EventBus.codex_entry_unlocked(category, entry_id)` → 신물/장소 명시적 해금.

---

## 7. 세이브/로드

### 7.1 위치 / 형식

- **파일**: `user://save.json` 단일 파일. 백업 1개 추가 보관: `user://save.backup.json` (성공 저장 시 직전 파일을 백업).
- **포맷**: UTF-8 JSON. 들여쓰기 0 (공간 절약). 한국어 문자열은 그대로 박는다(이스케이프 불필요).
- **데스크톱**: `user://` = OS별 표준(`~/.local/share/godot/app_userdata/KKAEBI RUN/`).
- **웹(HTML5)**: Godot 4가 자동으로 IndexedDB(`/userfs/`)에 매핑한다 — **추가 코드 불필요**. `OS.has_feature("web")`이면 명시적 `flush`를 위해 `JavaScriptBridge.eval("FS.syncfs(false, e => {})")`를 저장 직후 호출(데이터 손실 방지).

### 7.2 JSON 스키마 전체

```jsonc
{
  "version": 2,                              // int — §7.3 마이그레이션 키
  "saved_at": 1747200000,                    // int — Unix 초
  "build": "0.2.0",                          // string — 게임 버전
  "platform": "web",                          // string — &"web"|&"desktop"

  "meta": {                                  // ← MetaState.snapshot_for_save()와 동일 구조
    "version": 2,
    "saved_at": 1747200000,
    "currency": {
      "dokkaebi_orbs": 0,                    // int
      "shinmok_leaves": 0,                   // int
      "myth_shards": 0                       // int
    },
    "shinmok": { "stage": 1 },               // int 1..6

    "upgrades": {                            // dict<string,int> (level 0..5)
      "max_hp": 0, "attack": 0, "move_speed": 0,
      "xp_gain": 0, "gold_gain": 0,
      "revive": 0, "choice_extra": 0, "luck": 0
    },

    "characters": {
      "unlocked": ["ttukttaki"],             // Array[string]
      "affinity": { "ttukttaki": 0 },        // dict<string,int>
      "affinity_nodes": { "ttukttaki": [] }  // dict<string, Array[string]>
    },

    "codex": {
      "monsters": {                          // dict<string, object>
        "m01_dokkaebibul": {
          "discovered": false,               // bool
          "killed_count": 0,                 // int
          "first_seen_at": 0                 // int unix
        }
      },
      "relics": {
        "shinmok_leaf": { "acquired": false, "first_at": 0 }
      },
      "places": {
        "ch01_dumeong": { "visited": false, "cleared": false, "first_at": 0 }
      }
    },

    "achievements": {                        // dict<string, object>
      "first_kill": { "progress": 0, "target": 1, "unlocked": false, "claimed": false }
    },

    "challenges": {
      "daily_seed_day": -1,                  // int (epoch_day)
      "daily_active": [],                    // Array[string] (id 3개)
      "daily_progress": {},                  // dict<string,int>
      "weekly_seed_week": -1,                // int (epoch_week)
      "weekly_active": [],                   // Array[string] (id 1개)
      "weekly_progress": {}                  // dict<string,int>
    },

    "stats": {                               // dict<string, number>
      "total_kills": 0,
      "total_bosses_defeated": 0,
      "total_runs": 0,
      "total_clears": 0,
      "total_deaths": 0,
      "total_gold_earned": 0,
      "play_time_seconds": 0.0
    }
  },

  "settings": {                              // ← OptionsState (별도, 자동저장)
    "bgm_volume": 0.8,                       // float 0..1
    "se_volume": 1.0,
    "language": "ko",                        // future-proof
    "input_mode": "touch_or_keyboard",
    "screen_shake": 1.0
  }
}
```

### 7.3 버전 마이그레이션

`SaveStore.load()`는 다음 체인을 순차 적용:

```gdscript
const CURRENT_VERSION: int = 2

func _migrate(d: Dictionary) -> Dictionary:
    var v: int = int(d.get("version", 0))
    while v < CURRENT_VERSION:
        match v:
            0: d = _migrate_0_to_1(d)        # phase1 → 풀스펙 초기
            1: d = _migrate_1_to_2(d)        # luck/choice_extra 분리, codex 추가
            _: break
        v = int(d["version"])
    return d

func _migrate_0_to_1(d: Dictionary) -> Dictionary:
    # phase1은 save.json이 없었음 → 빈 사전이 들어옴
    d["version"] = 1
    d["meta"] = _default_meta()
    return d

func _migrate_1_to_2(d: Dictionary) -> Dictionary:
    var m: Dictionary = d.get("meta", {})
    var ups: Dictionary = m.get("upgrades", {})
    ups["luck"] = ups.get("luck", 0)
    ups["choice_extra"] = ups.get("choice_extra", 0)
    m["upgrades"] = ups
    m["codex"] = m.get("codex", _default_codex())
    m["challenges"] = m.get("challenges", _default_challenges())
    d["meta"] = m
    d["version"] = 2
    return d
```

규칙:
- **삭제 금지**: 한 번 키를 만들면 마이그레이션이 옮기거나 무시. 직접 삭제하지 않는다.
- **추가만**: 새 키는 `get(key, default)` 패턴으로 안전하게 읽는다.
- **타입 변경**: 마이그레이션 함수에서 명시적으로 변환.
- **저장 실패**: write 도중 예외 → `save.backup.json`에서 복원 시도, 실패 시 새 게임으로 폴백 + 토스트 "세이브 파일이 손상되었습니다".

### 7.4 SaveStore API (`scripts/meta/save_store.gd`)

```gdscript
class_name SaveStore

const PATH: String = "user://save.json"
const BACKUP_PATH: String = "user://save.backup.json"
const CURRENT_VERSION: int = 2

static func exists() -> bool
static func load() -> Dictionary                       # 마이그레이션 포함
static func save(d: Dictionary) -> bool                # backup → write → web flush
static func _atomic_write(path: String, data: String) -> bool
static func _web_flush() -> void                        # JavaScriptBridge.eval("FS.syncfs")
static func default_data() -> Dictionary
```

저장 트리거:
- `EventBus.save_requested(&"autosave")` — 챕터 클리어, 보스 처치, 메타 강화 구매, 신목 단계 도달, 캐릭터 해금 후.
- `EventBus.save_requested(&"manual")` — 옵션 화면의 "저장" 버튼.
- `EventBus.save_requested(&"quit")` — 메인 메뉴 진입, `notification(NOTIFICATION_WM_CLOSE_REQUEST)`.

---

## 8. 기존 MVP 코드 마이그레이션 계획

### 8.1 파일 매핑 표

| 현재 경로 | 새 경로 | 변경 사항 |
|-----------|---------|----------|
| `scripts/main.gd` | `scripts/systems/main.gd` | 게임 상태(HP/score 등)를 떼어 `GameState` 자동로드로 분리. 씬 전환 로직만 남기고 `ChapterManager.change_scene()` 호출로 변경. |
| `scripts/main_menu.gd` | `scripts/ui/main_menu.gd` | "시작" 클릭 시 `ChapterManager.goto_character_select()` 호출. 신목/도감/도전 버튼 추가. |
| `scripts/player.gd` | `scripts/player/player.gd` | 하드코딩 스탯을 `GameState` 변수로 교체. `CharacterData` 주입 슬롯 추가. 무기는 `Weapon.tscn`으로 분리(현재 player.gd 내부). |
| `scripts/enemy.gd` | `scripts/enemies/enemy_base.gd` | 통합 EnemyBase로 일반화. `@export var data: EnemyData`. AI는 `enemies/ai/*.gd` mixin으로 분리. |
| `scripts/enemy_fire.gd` | `resources/enemies/m01_dokkaebibul.tres` | 코드 삭제. 데이터만 `.tres`로 이전(HP=10, MS=50, etc.). 씬은 `EnemyBase.tscn` 단일 사용. |
| `scripts/enemy_egg.gd` | `resources/enemies/m02_dalgyalgwisin.tres` + `scripts/enemies/ai/group_charge.gd` | 데이터는 `.tres`, "돌진" 특수 로직은 SpecialAbility.CHARGE mixin으로. |
| `scripts/enemy_water.gd` | `resources/enemies/m03_mulgwisin.tres` + SpecialAbility.DRAG_SLOW | 동일 패턴. |
| `scripts/exp_gem.gd` | `scripts/items/xp_gem.gd` | 거의 그대로. EventBus.xp_collected 발신만 추가. |
| `scripts/skill_manager.gd` | `scripts/systems/skill_manager.gd` | 자동로드 유지. 하드코딩 SKILL_DEFS/BONUS_DEFS 사전을 `SkillData.tres` 로딩으로 교체. `acquire()` → `acquire_or_level()`, `draw_three_cards()` R1~R7 규칙 반영. |
| `scripts/skills/skill_base.gd` | `scripts/skills/skill_base.gd` | 그대로 유지. `@export var data: SkillData` + `current_level` 추가. |
| `scripts/skills/fire_orb.gd` | `scripts/skills/fire_orb.gd` | 하드코딩 데미지를 `data.levels[current_level-1].damage_*`로 교체. |
| `scripts/skills/frost_ring.gd` | 동일 위치 | 동일. SkillData.tres에 5레벨 수치. |
| `scripts/skills/vine_whip.gd` | 동일 위치 | 동일. |
| `scripts/skills/gold_shield.gd` | 동일 위치 | 동일. |
| `scripts/skills/rock_throw.gd` | 동일 위치 | 동일. |
| `scripts/hud.gd` | `scripts/ui/hud.gd` | `GameState` 신호 대신 `EventBus` 신호 구독으로 교체. BossHPBar 등 풀스펙 요소 추가. |
| `scripts/level_up_panel.gd` | `scripts/ui/level_up_panel.gd` | `SkillManager.draw_three_cards()` 새 인터페이스 사용. `choice_extra` 강화 반영해 4택 가능. |
| `scripts/pause_menu.gd` | `scripts/ui/pause_menu.gd` | 그대로. "메인 메뉴" 버튼이 `EventBus.run_ended(&"abandon")` 발신. |
| `scripts/result_screen.gd` | `scripts/ui/result_screen.gd` | `MetaState.compute_run_settlement()` 결과 표시. 누적 카운트업 애니메이션 유지. |
| `scripts/toast.gd` | `scripts/ui/toast.gd` | `EventBus.toast_requested` 구독으로 변경. |
| `scenes/gameplay/main.tscn` | `scenes/gameplay/main.tscn` | 그대로. SceneContainer + FadeOverlay 패턴 유지. |
| `scenes/gameplay/player.tscn` | `scenes/player/player.tscn` | 이동. Weapon 노드를 별도 씬 인스턴스로 분리. |
| `scenes/gameplay/enemy_*.tscn` | `scenes/enemies/EnemyBase.tscn` (단일) | 통합. 인스펙터에서 `data` 슬롯에 `.tres` 주입. |
| `scenes/gameplay/exp_gem.tscn` | `scenes/items/XPGem.tscn` | 이동만. |
| `scenes/skills/*.tscn` | `scenes/skills/*.tscn` | 위치 동일. `SkillData.tres`의 `scene` 필드와 연결. |
| `scenes/main_menu/main_menu.tscn` | `scenes/main_menu/main_menu.tscn` | 신목/도감/도전/캐릭터 버튼 추가. |
| `scenes/ui/*.tscn` | `scenes/ui/*.tscn` | 위치 동일. BossHPBar.tscn, AchievementToast.tscn 신규. |
| `project.godot [autoload]` | 동일 섹션 | `SkillManager` 1개 → `EventBus / GameState / SkillManager / MetaState / ChapterManager` 5개. |
| `project.godot [layer_names]` | 동일 섹션 | 4개 → 8개 확장 (player, player_attack, enemy, enemy_attack, exp_gem, environment, projectile_player, projectile_enemy). |

### 8.2 마이그레이션 순서 (엔지니어 체크리스트)

1. **M1 — 디렉토리 신설**: `scenes/{player,enemies,bosses,items,systems,environment,events}`, `scripts/{constants,data,bosses,environment,events,meta}`, `resources/{enemies,bosses,skills,characters,chapters,meta_upgrades}`.
2. **M2 — 데이터 클래스 도입**: `enums.gd`, `enemy_data.gd`, `boss_data.gd` (+ `boss_phase.gd`, `boss_pattern.gd`), `skill_data.gd` (+ `skill_level.gd`), `character_data.gd` (+ `affinity_node.gd`), `chapter_data.gd`, `meta_upgrade_data.gd`, `shinmok_stage_data.gd`.
3. **M3 — EventBus 자동로드 추가**: §2.1 전체 시그널 카탈로그.
4. **M4 — GameState 자동로드 추가**: 현재 `main.gd`의 HP/score 변수를 옮긴다. `main.gd`는 변수 참조만 `GameState.x`로 치환.
5. **M5 — MetaState + SaveStore**: 빈 세이브로 시작 → load/save 동작 확인 (web/desktop 모두).
6. **M6 — ChapterManager**: 현재 main_menu → main 전환 흐름을 ChapterManager로 흡수. 단일 챕터 ChapterData만 만들어 동작 확인.
7. **M7 — EnemyBase 통합**: 3종 enemy_*.gd를 EnemyBase + 3개 `.tres`로 변환. `enemy_*.gd`는 삭제(필요 시 SpecialAbility로 살림).
8. **M8 — SkillData 외화**: 5개 스킬을 `.tres` 5개로. 스크립트의 `@export`는 그대로 두되 `data.levels[lv-1]` 기반으로 읽도록 변경.
9. **M9 — CharacterData 도입**: 뚝딱이 1종만. 메타 보너스 적용 흐름 검증.
10. **M10 — 보스 BossBase**: 챕터 1 미니보스(장산범) + 챕터 1 보스 1종부터. 11종 전체 데이터는 점진.
11. **M11 — 환경/이벤트**: 가장 단순한 가시덤불 + 도깨비 시장부터.
12. **M12 — 친밀도/도감/도전**: MetaState UI 화면.
13. **M13 — 웹 빌드 회귀**: 마이그레이션 직후 매 단계 후 HTML5 export로 IndexedDB 저장 동작 확인.

> 각 단계 종료 시 기존 MVP 회귀(5분 1스테이지 플레이 + 결과화면)가 깨지지 않는지 수동 검증 후 다음 단계로 진행.

### 8.3 마이그레이션 중 임시 호환 계층

- `SkillManager.acquire()` 옛 시그니처(매개변수 1개)를 `acquire_or_level()`이 흡수. 옛 호출은 deprecated 주석만 달고 한 PR 안에서 모두 새 이름으로 치환.
- `main.gd`의 HP 변수를 `GameState.current_hp`로 옮긴 직후, 옛 코드의 다른 참조가 발견되면 즉시 동시 수정. 절대 별칭 변수 만들지 않는다.
- 옛 `enemy_*.gd`는 새 `EnemyBase` 도입 직후 같은 PR에서 삭제. "임시로 남겨두자" 금지.

---

## 9. 본 설계가 명시적으로 포함하지 않는 것

- **에셋 임포트 파이프라인 / 도트 작업 워크플로우** — 별도 아트 가이드.
- **로컬라이제이션 시스템** — 한국어 단일. i18n 도입은 출시 후.
- **멀티플레이 / 리더보드 / 클라우드 세이브** — 영구 스코프 밖.
- **에디터 플러그인** — `.tres` 직접 편집으로 충분.
- **단위 테스트 프레임워크(GUT)** — Phase 2 옵션. 본 마이그레이션은 수동 회귀 검증.
- **모바일 IAP / 광고** — `docs/monetization-plan.md`가 별도 정의.

---

*풀스펙 아키텍처 v1.0 — 깨비런 Solution Architect, 2026-05-14*
