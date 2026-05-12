# 깨비런 Phase 1 — 시스템/씬 구조 설계

> **버전**: 1.0
> **작성일**: 2026-05-12
> **기준 문서**: `docs/phase1-spec.md` (본 레포), `docs/kkaebi-run-gdd-v2.md` / `docs/kkaebi-run-asset-concept.md` (ai-company 레포)
> **엔진**: Godot 4.2, GDScript, GL Compatibility, 1280×720, 웹 빌드
> **목표**: 엔지니어가 추가 설계 결정 없이 즉시 구현 진입할 수 있는 수준의 구조 확정

---

## Architecture Decision

### Problem
Phase 1 MVP(5분 1스테이지, 적 3종, 스킬 5종, 레벨업 3택, HUD, 결과 화면)를 Godot 4.2 위에서 구현할 때, **(1) 씬 분할 단위, (2) 스크립트 디렉터리 배치, (3) 글로벌 상태 관리(자동로드), (4) 시스템 간 통신(신호), (5) 데이터 정의 위치(리소스)**를 어떻게 잡을지 결정해야 한다.

### Option A
**모놀리식 구조** — `Main.tscn` + `GameScene.tscn` 단 2개에 모든 로직을 인라인. 적/스킬은 코드 안에서 `if id == "..."` 분기로 처리.
- Pros: 파일 수 최소(~6개), 초기 코딩 빠름, 의존 그래프 단순
- Cons: 5분 동안 동시 적 120체 + 투사체/이펙트 풀링을 한 스크립트에 욱여넣으면 가독성/성능 모두 무너진다. Phase 2에서 스킬 진화·시너지·보스 추가 시 사실상 전면 재작성이 필요하다.

### Option B
**분해형 + 자동로드 + 리소스 데이터** — 씬을 책임 단위(Player/Weapon/Enemy/Spawner/HUD/UI/Skill)로 분할, 글로벌 상태는 `GameState`·`SkillManager` 두 자동로드로만 한정, 적/스킬 수치는 `EnemyData`·`SkillData` Resource(`.tres`)로 분리.
- Pros: 책임 경계 명확 → 디버깅 용이, Phase 2 확장(스킬·적·보스 추가)이 신규 `.tres` 추가만으로 끝남, 신호 기반 단방향 흐름으로 호출 경로가 짧다.
- Cons: 초기 파일 수가 ~25개, 자동로드 2개 사이의 초기화 순서를 신경 써야 함(아래 §3에서 해결).

### Decision
**Option B**를 Phase 1 MVP에 적용한다.

### Why
- §5.1 스폰 명세에 따라 화면 내 일반 적 최대 120체 + 오라/투사체/EXP 보석을 동시 처리해야 한다. 단일 거대 스크립트는 풀링·신호 단방향성 두 가지를 모두 잃는다.
- §4 스킬 5종은 동작 방식이 전부 다르다(회전 오브 / 오라 / 자동 발사 / 보호막 / 투사체). 공통 인터페이스 `Skill.gd`를 두고 씬 단위로 분리해야 각각 독립적으로 디버깅 가능.
- §10에서 Phase 2 이후 들어올 스킬 레벨업·시너지·진화·미니보스는 데이터 행 추가/씬 추가만으로 끝나야 한다. MVP에서 코드/데이터 경계를 미리 그어두는 비용이 미루는 비용보다 작다.

### Backend decision
**백엔드 없음.** 단일 클라이언트, 웹 빌드(HTML5). 멀티플레이/리더보드/원격 저장 모두 §0 스코프 밖.

### Persistence decision
**MVP 단계 영구 저장 없음.** 결과 화면 통계는 메모리에서만 유지된다(`다시 도전하기` 시 리셋). Phase 2에서 메타 강화가 들어올 때 `user://save.json`(데스크톱) / IndexedDB(웹)으로 도입.

### Evolution path
- **Phase 2 — 스킬 레벨업/시너지**: `SkillData`에 `levels: Array[SkillLevelData]` 필드 추가, `SkillManager`에 `evolve()` 메서드 추가. 기존 5개 `.tres`는 `levels[0]`만 채워서 호환.
- **Phase 2 — 보스/미니보스**: `scenes/bosses/`, `scripts/bosses/` 신설. `EnemySpawner`의 윈도우 기반 스폰 옆에 `timeline` 기반 보스 큐를 병렬로 추가.
- **Phase 2 — 메타 강화**: 자동로드에 `MetaState`(영구 저장) 추가, 메인 메뉴 씬에 강화 화면 추가.

---

## 1. 씬 트리 구조

### 1.1 전체 씬 인벤토리

| 씬 파일 | 루트 노드 타입 | 역할 |
|---------|---------------|------|
| `scenes/Main.tscn` | `Node` | 진입점. `MainMenu` ↔ `GameScene` ↔ `ResultScreen` 전환 컨트롤 |
| `scenes/MainMenu.tscn` | `Control` | MVP는 로고 + `시작하기` 버튼 1개 |
| `scenes/GameScene.tscn` | `Node2D` | 인게임 본체. 아래 §1.2 참조 |
| `scenes/player/Player.tscn` | `CharacterBody2D` | 뚝딱이 본체 |
| `scenes/player/Weapon.tscn` | `Node2D` | 도깨비방망이 회전 타격 |
| `scenes/enemies/EnemyBase.tscn` | `CharacterBody2D` | 적 공통 베이스 (스크립트만 다름) |
| `scenes/enemies/Dokkebibul.tscn` | inherits `EnemyBase` | 도깨비불 — `data: EnemyData` 슬롯에 `dokkebibul.tres` 주입 |
| `scenes/enemies/Dalgyalgwisin.tscn` | inherits `EnemyBase` | 달걀귀신 |
| `scenes/enemies/Mulgwisin.tscn` | inherits `EnemyBase` | 물귀신 (둔화 효과 포함) |
| `scenes/systems/EnemySpawner.tscn` | `Node` | §5 시간대별 스폰 곡선 실행 |
| `scenes/items/XPGem.tscn` | `Area2D` | EXP 보석 — 값별 색상만 다름 |
| `scenes/items/Gold.tscn` | `Area2D` | 금화 |
| `scenes/skills/Dokkebibul.tscn` | `Node2D` | 회전 오브 3개 (스킬, 적 도깨비불과 동명이라 클래스명 `DokkebibulSkill`) |
| `scenes/skills/SeoriRing.tscn` | `Area2D` | 서리고리 오라 |
| `scenes/skills/DeonggulWhip.tscn` | `Node2D` | 덩굴채찍 자동 발사 |
| `scenes/skills/GoldShield.tscn` | `Node2D` | 금빛방패 보호막 |
| `scenes/skills/BawiThrow.tscn` | `Node2D` | 바위투척 |
| `scenes/skills/projectiles/BawiProjectile.tscn` | `Area2D` | 바위 투사체 |
| `scenes/ui/HUD.tscn` | `CanvasLayer` | §6 HUD 5요소 |
| `scenes/ui/LevelUpUI.tscn` | `CanvasLayer` | 레벨업 3택 모달 |
| `scenes/ui/ResultScreen.tscn` | `CanvasLayer` | 사망/클리어 결과 화면 |
| `scenes/ui/Toast.tscn` | `Control` | 상단 중앙 1.5초 토스트 |

### 1.2 GameScene 노드 트리

```
GameScene (Node2D)                                    [scripts/systems/game_scene.gd]
├── World (Node2D)                                   z_index=0
│   ├── Background (ColorRect, 1280×720)             #2A2A35 어두운 밤하늘
│   ├── Player (CharacterBody2D)                     [player/player.gd]
│   │   ├── Sprite (ColorRect 48×48, 임시)            #7CAADC
│   │   ├── HurtBox (Area2D)
│   │   │   └── CollisionShape2D (CircleShape2D, r=12)
│   │   ├── PickupArea (Area2D, r=60)                ← EXP 보석/금화 흡인 트리거
│   │   │   └── CollisionShape2D
│   │   ├── Weapon (Weapon.tscn 인스턴스)             [player/weapon.gd]
│   │   │   └── WeaponHead (Area2D)                  ← 방망이 헤드
│   │   │       ├── CollisionShape2D (CapsuleShape2D, 28×40)
│   │   │       └── Sprite (ColorRect 28×40, 임시)    #8B7A1A 갈색
│   │   └── SkillAnchor (Node2D)                     ← 패시브 스킬 부모(회전 오브 등)
│   ├── EnemyContainer (Node2D)                      ← 모든 적의 부모(풀에서 attach)
│   ├── ProjectileContainer (Node2D)                 ← 바위/덩굴
│   ├── XPGemContainer (Node2D)
│   ├── GoldContainer (Node2D)
│   └── EffectContainer (Node2D)                     ← 사망 이펙트, 히트 스파크
├── Camera2D                                          smoothing on, follow Player
├── EnemySpawner (EnemySpawner.tscn)                  [systems/enemy_spawner.gd]
├── PoolManager (Node)                                [systems/pool_manager.gd]
├── HUD (HUD.tscn, CanvasLayer)                       layer=10
├── LevelUpUI (LevelUpUI.tscn, CanvasLayer)           layer=20, 평소 hide()
├── ResultScreen (ResultScreen.tscn, CanvasLayer)     layer=30, 평소 hide()
└── ToastLayer (CanvasLayer)                          layer=15, Toast 인스턴스의 부모
```

> **Camera2D 위치**: Player의 자식이 아니라 `World` 직속 자식으로 두고, `_process`에서 `global_position = player.global_position`을 따라가게 한다. Player 회전/스케일 영향을 받지 않기 위함.

### 1.3 Main 씬 트리

```
Main (Node)                                           [systems/main.gd]
├── SceneContainer (Node)                             ← 현재 활성 씬을 child로 보유
└── FadeOverlay (CanvasLayer, layer=100)
    └── ColorRect (검정, alpha 0)                     ← 씬 전환 페이드 0.4s
```

흐름:
- 게임 시작 → `MainMenu.tscn`을 `SceneContainer` 자식으로 add
- 시작 버튼 → 페이드아웃 → 기존 자식 free → `GameScene.tscn` add → 페이드인
- 결과 화면 `다시 도전하기` → `GameScene.tscn`을 다시 instantiate(완전 리셋)
- 결과 화면 `메인 메뉴로 돌아가기` → `MainMenu.tscn` 재로드

---

## 2. 스크립트 디렉터리 배치

```
scripts/
├── constants/
│   └── palette.gd                       # class_name Palette (오방색 + 보조)
├── data/
│   ├── enemy_data.gd                    # class_name EnemyData : Resource
│   ├── skill_data.gd                    # class_name SkillData : Resource
│   └── resources/
│       ├── enemies/
│       │   ├── dokkebibul.tres
│       │   ├── dalgyalgwisin.tres
│       │   └── mulgwisin.tres
│       └── skills/
│           ├── dokkebibul.tres
│           ├── seori_ring.tres
│           ├── deonggul_whip.tres
│           ├── gold_shield.tres
│           └── bawi_throw.tres
├── systems/
│   ├── game_state.gd                    # Autoload (GameState)
│   ├── skill_manager.gd                 # Autoload (SkillManager)
│   ├── main.gd                          # Main.tscn 루트 스크립트
│   ├── game_scene.gd                    # GameScene.tscn 루트 스크립트
│   ├── enemy_spawner.gd
│   ├── pool_manager.gd
│   └── difficulty_curve.gd              # 시간 경과 강화 계산 헬퍼 (static func)
├── player/
│   ├── player.gd                        # CharacterBody2D, HP/이동/피격 처리
│   └── weapon.gd                        # 도깨비방망이 회전 + 같은 적 재타격 쿨
├── enemies/
│   ├── enemy_base.gd                    # 공통 추적 AI, HP, 사망 신호
│   └── mulgwisin.gd                     # extends enemy_base, 접촉 시 둔화 추가
├── skills/
│   ├── skill.gd                         # class_name Skill, 공통 인터페이스
│   ├── dokkebibul_skill.gd
│   ├── seori_ring_skill.gd
│   ├── deonggul_whip_skill.gd
│   ├── gold_shield_skill.gd
│   ├── bawi_throw_skill.gd
│   └── bawi_projectile.gd
├── items/
│   ├── xp_gem.gd
│   └── gold.gd
└── ui/
    ├── hud.gd
    ├── level_up_ui.gd
    ├── skill_card.gd                    # 카드 1장 위젯
    ├── result_screen.gd
    └── toast.gd
```

> **파일명 규칙**: `snake_case.gd`(Godot 표준). 씬은 `PascalCase.tscn`. `class_name`은 `PascalCase`.

---

## 3. 자동로드(Autoload) 싱글톤

**자동로드는 정확히 2개만 둔다.** 그 외 글로벌 상태는 만들지 않는다.

### 3.1 GameState (`res://scripts/systems/game_state.gd`)

런 단위 휘발 상태. 씬 전환 시 `reset()`을 호출하면 초기값으로 돌아간다.

```gdscript
extends Node

signal hp_changed(current: int, max: int)
signal xp_changed(current: int, required: int)
signal level_changed(new_level: int)
signal kill_count_changed(count: int)
signal gold_changed(amount: int)
signal time_milestone(seconds: int)    # 정수 초마다 발화
signal game_over(reason: StringName)   # "death" | "clear"

const STAGE_DURATION := 300.0          # 5분

# 플레이어 상태
var max_hp: int = 100
var current_hp: int = 100

# 진행
var elapsed: float = 0.0
var level: int = 1
var current_xp: int = 0
var kill_count: int = 0
var gold: int = 0

# 영구 누적 보너스 (보너스 카드)
var bonus_max_hp: int = 0
var bonus_move_speed_mult: float = 1.0   # 0.05씩 곱
var bonus_xp_gain_mult: float = 1.0      # 0.10씩 곱

func reset() -> void: ...
func add_xp(value: int) -> void:         # 보너스 배율 적용 후 누적, 임계치 도달 시 level_changed 발화
func required_xp_for(level_n: int) -> int:  # §3.2 공식
func deal_damage_to_player(amount: int) -> void:  # 무적/방패 검사는 호출 측이 함
func register_kill() -> void:
func add_gold(amount: int) -> void:
```

### 3.2 SkillManager (`res://scripts/systems/skill_manager.gd`)

스킬 풀과 보유 현황 관리. 씬에 직접 노드를 붙이지는 않고, `GameScene`이 `skill_acquired` 신호를 받아 인스턴스화 후 `Player.SkillAnchor`에 add한다.

```gdscript
extends Node

signal skill_acquired(skill_id: StringName)

const ALL_SKILL_IDS: Array[StringName] = [
    &"dokkebibul", &"seori_ring", &"deonggul_whip", &"gold_shield", &"bawi_throw"
]

var skill_db: Dictionary = {}     # id -> SkillData (preload 모음, _ready에서 채움)
var owned: Array[StringName] = []

func reset() -> void
func is_owned(id: StringName) -> bool
func acquire(id: StringName) -> void                   # owned 추가 + skill_acquired 발화
func draw_three_cards() -> Array[Dictionary]
    # 반환 형식 예:
    # [{ "kind": "skill", "id": &"dokkebibul", "data": SkillData },
    #  { "kind": "bonus", "id": &"max_hp_plus_20" }, ... ]
    # 규칙은 phase1-spec.md §3.3 그대로 구현
```

### 3.3 자동로드 등록 (project.godot)

```ini
[autoload]

GameState="*res://scripts/systems/game_state.gd"
SkillManager="*res://scripts/systems/skill_manager.gd"
```

> **초기화 순서**: `GameState` → `SkillManager` 순으로 위에 적는다. `SkillManager._ready()`가 `GameState`를 참조해도 안전하도록. 실제로는 둘이 서로 참조하지 않는 게 안전 — 통신은 신호로만.

### 3.4 자동로드를 두지 않는 것들

- **스코어/통계** → `GameState` 안 같은 변수
- **현재 씬 참조** → `Main`이 직접 보유
- **풀 매니저** → `GameScene` 자식 노드 (`PoolManager`). 씬 종료 시 같이 사라져야 한다.

---

## 4. 신호(Signal) 흐름

원칙: **호출은 아래쪽, 신호는 위쪽**. 부모는 자식의 신호를 듣고, 자식은 부모의 함수를 직접 호출하지 않는다. 멀리 떨어진 노드끼리는 자동로드의 신호로 연결한다.

### 4.1 핵심 흐름 (요구된 4가지)

```
[적 사망]
  Enemy.take_damage(amount)
    └─ if hp <= 0:
         emit_signal("died", global_position, data.exp_value, data.gold_drop_chance, data.gold_drop_amount)
         queue_free()
  GameScene._on_enemy_died(pos, exp, gold_chance, gold_amount)
    ├─ XPGemContainer에 XPGem 인스턴스 추가 (pos, exp)
    ├─ randf() < gold_chance → GoldContainer에 Gold 인스턴스 추가
    └─ GameState.register_kill()

[EXP 수집]
  XPGem._on_area_entered(area)        # area == Player.PickupArea
    └─ 흡인 시작 (Tween, 300 px/s) → Player 도달 시:
         emit_signal("collected", value)
         queue_free()
  GameScene._on_xp_collected(value)
    └─ GameState.add_xp(value)

[레벨업 → 카드 표시]
  GameState.add_xp(value)
    └─ if current_xp >= required:
         level += 1
         emit_signal("level_changed", level)
  GameScene._on_level_changed(new_level)
    ├─ get_tree().paused = true
    ├─ LevelUpUI.populate(SkillManager.draw_three_cards())
    └─ LevelUpUI.show()
  LevelUpUI._on_card_selected(card_data)
    ├─ if kind == "skill": SkillManager.acquire(id)
    ├─ if kind == "bonus": GameState에 보너스 적용
    ├─ LevelUpUI.hide()
    └─ get_tree().paused = false

[스킬 획득 → 인스턴스화]
  SkillManager.acquire(id)
    └─ emit_signal("skill_acquired", id)
  GameScene._on_skill_acquired(id)
    └─ Player.SkillAnchor에 SkillData.scene 인스턴스 추가

[플레이어 사망]
  Player.take_damage(amount)
    └─ 무적/방패 검사 후 GameState.current_hp -= amount
         if current_hp <= 0:
           emit_signal("died")
  GameScene._on_player_died()
    ├─ 1.0초 연출 (Tween: time_scale 0.3, alpha 0→0.6)
    ├─ ResultScreen.show_death(GameState 통계)
    └─ get_tree().paused = true
```

### 4.2 그 외 신호 매핑

| 발신 | 신호 | 수신 | 동작 |
|------|------|------|------|
| `GameState` | `hp_changed` | `HUD` | HP 바 갱신 |
| `GameState` | `xp_changed` | `HUD` | EXP 바 갱신 |
| `GameState` | `level_changed` | `HUD` | `Lv. N` 라벨 갱신 (모달 표시는 GameScene이 담당) |
| `GameState` | `gold_changed` | `HUD` | 금화 숫자 갱신 |
| `GameState` | `time_milestone(t)` | `GameScene` | t==90/240/290/300에 토스트 호출, t==300이면 클리어 |
| `SkillManager` | `skill_acquired` | `HUD` | 우하단 스킬 슬롯 아이콘 추가 |
| `EnemySpawner` | (자체 타이머) | — | `_spawn_enemy(id)`를 내부에서 호출, `EnemyContainer`에 add |
| `Player` | `died` | `GameScene` | 결과 화면 표시 |
| `Enemy` | `died` | `GameScene` | XP/금화 드롭 |
| `XPGem` | `collected` | `GameScene` | xp 누적 |
| `Gold` | `collected` | `GameScene` | 금화 누적 |
| `ResultScreen` | `retry_pressed` | `Main` | 씬 재로드 |
| `ResultScreen` | `main_menu_pressed` | `Main` | 메인 메뉴 전환 |

### 4.3 일시 정지 처리

- 레벨업/결과 화면: `get_tree().paused = true`.
- 카드 UI/결과 화면 노드는 모두 `process_mode = Node.PROCESS_MODE_ALWAYS`로 설정한다(`@export`로 기본값 지정).
- HUD는 `PROCESS_MODE_PAUSABLE`로 그대로 둔다(어차피 멈춰도 표시되는 값들).
- 토스트 메시지는 `PROCESS_MODE_ALWAYS`로 두면 일시 정지 중에도 페이드되어 사라지므로, `PROCESS_MODE_PAUSABLE`로 두어 정지 중 멈추게 한다.

---

## 5. 데이터 리소스 스키마

### 5.1 EnemyData (`res://scripts/data/enemy_data.gd`)

```gdscript
class_name EnemyData
extends Resource

@export var id: StringName                # &"dokkebibul" / &"dalgyalgwisin" / &"mulgwisin"
@export var display_name_ko: String       # 사용자 노출명 (디버그/도감용)

# 스탯
@export var hp: int = 1
@export var move_speed: float = 80.0      # px/s
@export var contact_damage: int = 4
@export var hitbox_radius: float = 12.0

# 보상
@export var exp_value: int = 1
@export var gold_drop_chance: float = 0.0 # 0.0~1.0
@export var gold_drop_amount: int = 0

# 시각 (Phase 1은 ColorRect 플레이스홀더)
@export var sprite_size: Vector2i = Vector2i(24, 24)
@export var placeholder_color: Color = Color.WHITE
@export var sprite_texture: Texture2D     # null 이면 ColorRect 사용

# 특수 효과 (물귀신용)
@export var on_contact_effect: StringName = &""   # &"" | &"slow_player"
@export var slow_factor: float = 0.0              # 0.30 = 30% 감속
@export var slow_duration: float = 0.0            # 초

# 군집 스폰 (달걀귀신용)
@export var group_size: int = 1                   # 4면 4마리 한 무리
@export var group_spacing_px: float = 30.0
```

#### `.tres` 인스턴스 값 (phase1-spec.md §2 그대로)

**`dokkebibul.tres`**
```
id = &"dokkebibul"
display_name_ko = "도깨비불"
hp = 8, move_speed = 80, contact_damage = 4, hitbox_radius = 12
exp_value = 1, gold_drop_chance = 0.10, gold_drop_amount = 1
sprite_size = (24, 24), placeholder_color = #6BA3FF
on_contact_effect = &""
group_size = 1
```

**`dalgyalgwisin.tres`**
```
id = &"dalgyalgwisin"
display_name_ko = "달걀귀신"
hp = 15, move_speed = 140, contact_damage = 6, hitbox_radius = 14
exp_value = 2, gold_drop_chance = 0.15, gold_drop_amount = 1
sprite_size = (32, 32), placeholder_color = #F0EDE6
group_size = 4, group_spacing_px = 30
```

**`mulgwisin.tres`**
```
id = &"mulgwisin"
display_name_ko = "물귀신"
hp = 40, move_speed = 50, contact_damage = 10, hitbox_radius = 20
exp_value = 5, gold_drop_chance = 0.50, gold_drop_amount = 2
sprite_size = (48, 48), placeholder_color = #4CAF50
on_contact_effect = &"slow_player", slow_factor = 0.30, slow_duration = 1.0
group_size = 1
```

### 5.2 SkillData (`res://scripts/data/skill_data.gd`)

```gdscript
class_name SkillData
extends Resource

@export var id: StringName                # &"dokkebibul" / &"seori_ring" / ...
@export var display_name_ko: String       # 카드 노출명, 예: "도깨비불"
@export var description_ko: String        # 카드 설명문 (한국어 존댓말)

enum Element { FIRE, WATER, WOOD, METAL, EARTH }
@export var element: Element

@export var scene: PackedScene            # 획득 시 Player.SkillAnchor에 인스턴스화
@export var icon_color: Color             # HUD 슬롯 테두리 색 (Phase 1 임시)
@export var icon_texture: Texture2D       # null이면 ColorRect 사용
```

> 스킬별 수치(데미지/쿨다운/반경 등)는 **스킬 씬 스크립트의 `@export` 변수에 박는다**. SkillData에 넣지 않는 이유는, Phase 2에서 같은 SkillData를 공유하면서 레벨별 수치만 다를 때 별도의 `SkillLevelData` 리소스로 빼는 게 자연스럽기 때문 — MVP에서는 씬 스크립트가 단일 진실원.

#### 스킬 씬별 `@export` 수치 (phase1-spec.md §4 그대로)

**`dokkebibul_skill.gd`**
```gdscript
@export var orb_count: int = 3
@export var rotation_radius: float = 110.0
@export var rotation_speed_deg: float = 240.0
@export var damage_per_hit: int = 6
@export var same_target_cooldown: float = 0.5
```

**`seori_ring_skill.gd`**
```gdscript
@export var aura_radius: float = 90.0
@export var tick_damage: int = 2
@export var tick_interval: float = 0.2
@export var slow_factor: float = 0.25
@export var slow_duration: float = 1.5
```

**`deonggul_whip_skill.gd`**
```gdscript
@export var max_range: float = 220.0
@export var damage: int = 14
@export var cooldown: float = 1.0
```

**`gold_shield_skill.gd`**
```gdscript
@export var max_stack: int = 1
@export var regen_cooldown: float = 5.0
```

**`bawi_throw_skill.gd`**
```gdscript
@export var max_range: float = 400.0
@export var projectile_speed: float = 360.0
@export var damage: int = 20
@export var stun_duration: float = 0.5
@export var cooldown: float = 2.5
```

---

## 6. 오방색 팔레트 상수 (`scripts/constants/palette.gd`)

```gdscript
class_name Palette

# === 오방색 메인 (kkaebi-run-asset-concept.md §1.1) ===
const RED_MAIN   := Color("#E03C3C")    # 적(赤), 화(火), HP 바, 결과화면 강조 버튼
const RED_LIGHT  := Color("#FF6B6B")
const RED_DARK   := Color("#8B1A1A")

const BLUE_MAIN  := Color("#3C7CE0")    # 청(靑), 수(水)
const BLUE_LIGHT := Color("#6BA3FF")    # 도깨비불 플레이스홀더
const BLUE_DARK  := Color("#1A3F8B")

const YELLOW_MAIN  := Color("#E0C23C")  # 황(黃), 토(土), 금화 텍스트
const YELLOW_LIGHT := Color("#FFE066")
const YELLOW_DARK  := Color("#8B7A1A")

const WHITE_MAIN  := Color("#F0EDE6")   # 백(白), 금(金), 달걀귀신 플레이스홀더, 기본 텍스트
const WHITE_PURE  := Color("#FFFFFF")
const WHITE_DARK  := Color("#C8C3B8")

const BLACK_MAIN  := Color("#2A2A35")   # 흑(黑), 배경, 외곽선
const BLACK_LIGHT := Color("#45455A")   # 트랙 색, 보조 버튼
const BLACK_DARK  := Color("#0F0F15")

# === 보조 ===
const WOOD_GREEN     := Color("#4CAF50")  # 목(木), 물귀신 플레이스홀더
const SHINMOK_GOLD   := Color("#FFD700")  # 신목 금빛, EXP 바
const POISON_PURPLE  := Color("#9C27B0")
const SKIN_KKAEBI    := Color("#7CAADC")  # 도깨비 피부, 뚝딱이 플레이스홀더
const SKIN_KKAEBI_DK := Color("#5B8DB8")

# === UI 토큰 ===
const TEXT_BODY        := WHITE_MAIN
const TEXT_OUTLINE     := BLACK_MAIN
const HP_GAUGE         := RED_MAIN
const HP_OUTLINE       := BLACK_DARK
const EXP_GAUGE        := SHINMOK_GOLD
const EXP_TRACK        := BLACK_LIGHT
const GOLD_TEXT        := YELLOW_MAIN
const BTN_PRIMARY_BG   := RED_MAIN
const BTN_SECONDARY_BG := BLACK_LIGHT

# === 스킬 속성별 ===
const ELEMENT_FIRE  := RED_MAIN
const ELEMENT_WATER := BLUE_MAIN
const ELEMENT_WOOD  := WOOD_GREEN
const ELEMENT_METAL := WHITE_MAIN
const ELEMENT_EARTH := YELLOW_MAIN

# === EXP 보석 가치별 색 ===
static func gem_color(exp_value: int) -> Color:
    if exp_value >= 5: return RED_MAIN       # 물귀신 드롭
    if exp_value >= 2: return WOOD_GREEN     # 달걀귀신 드롭
    return BLUE_LIGHT                         # 도깨비불 드롭
```

> 모든 색은 `Palette.RED_MAIN` 형식으로만 참조하고, 코드 안에 hex 리터럴을 적지 않는다. 톤 조정 시 한 곳만 고치면 끝.

---

## 7. 임시 픽셀아트 플레이스홀더 전략

### 7.1 원칙

1. **에셋 의존 없이 빌드/플레이 가능해야 한다.** 도트 작업이 늦어지면 게임플레이 검증도 같이 지연된다 — 분리한다.
2. **단색 ColorRect 또는 단색 텍스처**만 사용. 회전/스케일 변환이 필요한 곳(방망이 회전, 회전 오브, 바위 투사체)도 ColorRect로 충분.
3. **모든 색은 `Palette` 상수에서 가져온다.** 진짜 스프라이트로 교체할 때는 ColorRect 노드를 Sprite2D로 바꾸고 텍스처를 꽂으면 끝.

### 7.2 노드별 플레이스홀더 표

| 대상 | 플레이스홀더 노드 | 크기 | 색 (Palette) |
|------|------------------|------|--------------|
| 뚝딱이 본체 | `ColorRect` (사각형) | 48×48 | `SKIN_KKAEBI` |
| 도깨비방망이 헤드 | `ColorRect` | 28×40 | `YELLOW_DARK` |
| 도깨비불 (적) | `ColorRect` 또는 Polygon2D 원 | 24×24 | `BLUE_LIGHT` |
| 달걀귀신 (적) | `ColorRect` | 32×32 | `WHITE_MAIN` |
| 물귀신 (적) | `ColorRect`, alpha=0.7 | 48×48 | `WOOD_GREEN` |
| EXP 보석 (1) | `ColorRect` 또는 Polygon2D 다이아몬드 | 12×12 | `BLUE_LIGHT` |
| EXP 보석 (2) | 동일 | 14×14 | `WOOD_GREEN` |
| EXP 보석 (5) | 동일 | 16×16 | `RED_MAIN` |
| 금화 | `ColorRect` 또는 Polygon2D 원 | 12×12 | `YELLOW_MAIN` |
| 도깨비불 스킬 오브 | `ColorRect` | 16×16 | `RED_LIGHT` |
| 서리고리 오라 | 반투명 원 (`Polygon2D` + `arc_points`) | r=90 | `BLUE_MAIN`, alpha=0.25 |
| 덩굴채찍 라인 | `Line2D` | 두께 6 | `WOOD_GREEN` |
| 금빛방패 링 | 빈 원 (`Polygon2D` 링) | r=36 | `WHITE_PURE`, alpha=0.6 |
| 바위 투사체 | `ColorRect` 또는 Polygon2D 원 | 14×14 | `YELLOW_DARK` |
| 히트 스파크 | `CPUParticles2D`, square texture | — | `WHITE_PURE` |
| 배경 | `ColorRect` 전체 | 1280×720 | `BLACK_MAIN` |

### 7.3 EnemyBase의 플레이스홀더 적용

`enemy_base.gd._ready()` 안에서 `data: EnemyData`를 받아 자동 적용한다.

```gdscript
@export var data: EnemyData
@onready var sprite: ColorRect = $Sprite
@onready var hitbox: CollisionShape2D = $HurtBox/CollisionShape2D

func _ready() -> void:
    if data.sprite_texture:
        # 실제 텍스처가 있으면 ColorRect를 Sprite2D로 교체할 수 있도록 미리 분기 (Phase 2)
        pass
    sprite.size = data.sprite_size
    sprite.position = -Vector2(data.sprite_size) * 0.5
    sprite.color = data.placeholder_color
    (hitbox.shape as CircleShape2D).radius = data.hitbox_radius
    hp = data.hp
```

### 7.4 실제 스프라이트로 교체 시

1. `assets/sprites/{대상}.png` 추가.
2. 씬에서 `ColorRect` 노드를 우클릭 → `Sprite2D`로 변경(또는 새 Sprite2D 추가 후 ColorRect 삭제).
3. `EnemyData.sprite_texture`에 텍스처를 꽂는다.
4. `enemy_base.gd._ready()`의 분기를 활성화.

엔진 측면의 다른 코드 변경은 필요 없다.

---

## 8. 동시성·성능 메모

엔지니어가 구현 중 마주칠 성능 함정을 미리 정리한다.

1. **풀링 필수 대상**: 적 3종, EXP 보석, 금화, 바위 투사체, 히트 스파크. `PoolManager`가 `pool[id] = Array[Node]`로 관리하고 `acquire(id)` / `release(node)`만 노출한다.
2. **물리 레이어**:
   - 1: `player` (HurtBox)
   - 2: `enemies` (HurtBox + 접촉 영역)
   - 3: `player_pickup` (PickupArea)
   - 4: `enemy_drops` (XPGem, Gold)
   - 5: `weapon` (WeaponHead, 스킬 오라, 투사체)
   - mask: `weapon` → `enemies`만, `player` → `enemies`만, `player_pickup` → `enemy_drops`만.
3. **신호 vs 폴링**: 같은 적 재타격 쿨다운(§1.2 0.4s, §4.1 도깨비불 0.5s)은 적 노드 안에 `Dictionary[StringName, float]` 형태로 "타격원 ID → 마지막 타격 시간"을 저장한다. 신호 베이스로 만들면 호출 빈도가 폭증.
4. **`process_mode`**: 일시 정지 중에도 회전해야 하는 노드는 없음 — 방망이/회전 오브/스폰 타이머 모두 `PAUSABLE`이어도 무방.
5. **시간 강화 계산**: `difficulty_curve.gd`에 `static func multipliers(t: float) -> Dictionary` 한 줄로. `EnemySpawner._spawn(id)`에서 호출 후 `EnemyData`의 사본을 만들지 말고 적 노드의 멤버 변수에 곱해서 주입(데이터 자체는 불변).

---

## 9. 파일 구현 체크리스트 (엔지니어용)

순서대로 만들면 빈 프로젝트에서 MVP까지 도달한다.

- [ ] **C1. 인프라**: `palette.gd`, `enemy_data.gd`, `skill_data.gd`, 3개 `.tres`(적), 5개 `.tres`(스킬). 데이터부터 작성한다.
- [ ] **C2. 자동로드**: `game_state.gd`, `skill_manager.gd` + `project.godot` 등록. 단위 테스트 가능 수준까지(스폰 없이 EXP 더해서 `level_changed` 발화 확인).
- [ ] **C3. Player + Weapon**: 이동, HP, 무적 시간, 방망이 회전 + 같은 적 재타격 쿨 (적 없이 데미지 카운터 로그로 확인).
- [ ] **C4. EnemyBase + 3종**: 추적 AI, 사망 신호, 임시 ColorRect. 한 마리 수동 배치로 동작 확인.
- [ ] **C5. EnemySpawner**: §5.2 윈도우 곡선 + 시간 경과 강화. 빈 GameScene에서 5분 돌려서 동시 적 수 화면 카운터로 확인.
- [ ] **C6. XPGem + Gold**: 드롭, 흡인, 수집, GameState 반영.
- [ ] **C7. HUD**: 5요소(HP/Lv/타이머/금화/EXP/스킬 슬롯) + Palette 토큰 적용. GameState 신호 전부 연결.
- [ ] **C8. LevelUpUI**: 3택 모달, `draw_three_cards()` 결과 표시, 키보드 1/2/3.
- [ ] **C9. 스킬 5종**: 한 개씩 — 도깨비불 → 서리고리 → 덩굴채찍 → 금빛방패 → 바위투척.
- [ ] **C10. 토스트**: §7.5 6종 트리거 + 한국어 문구.
- [ ] **C11. ResultScreen + Main 전환**: 사망/클리어 분기, 통계 카운트업.
- [ ] **C12. 빌드/검증**: HTML5 export, 브라우저에서 5분 플레이 + §5.3 체크포인트로 밸런스 1차 측정.

---

## 10. 본 설계가 명시적으로 포함하지 않는 것

`phase1-spec.md §10`의 Phase 2 이연 항목 외에, 본 아키텍처 단계에서도 다음은 의도적으로 정의하지 않았다:

- **세이브/로드 포맷** — 영구 저장이 없으므로.
- **에셋 임포트 파이프라인** — 임시 ColorRect로 충분.
- **로컬라이제이션 시스템** — 모든 문자열을 한국어로 직접 박는다. i18n 도입은 출시 직전.
- **에디터 툴/플러그인** — `.tres` 직접 편집으로 충분.
- **단위 테스트 프레임워크 도입** — 체크리스트 각 단계의 수동 검증으로 대체. GUT/추가 의존성 없이 진행.

---

*Phase 1 아키텍처 문서 v1.0 — 깨비런 제작팀 (Solution Architect)*
