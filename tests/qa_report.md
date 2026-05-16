# QA Report

## Summary — PASS

- **Status**: ✅ PASS (errors 0, regression 0)
- **Modules passed**: 12 / 12
- **Cycles run**: 1 (clean pass on first run — no fix iteration required)
- **Korean encoding (mojibake)**: 0건 (U+FFFD replacement char grep across .gd/.tres/.tscn/.md/.json)
- **Files modified this session**: 없음 (직전 단계에서 `tests/qa_runner.gd` 파스 버그 수정 후 12/12 PASS 유지)

## 기획서 대비 항목 체크리스트 (docs/phase1-spec.md + full-spec)

| 항목 | 목표 | 실측 | 상태 | 근거 |
|------|-----:|-----:|:----:|------|
| 몬스터 일반 | 53종 | 53 | ✅ | `resources/enemies/chapter1..5` 49 + `hidden` 4 (= 53). `legacy/`(3)는 별도 보존본 |
| 보스 / 미니보스 | 11종 | 11 | ✅ | `resources/bosses/` 6 챕터 보스 + 5 미니보스 (`b01..b06`, `mb01..mb05`) |
| 스킬 | 30종 | 30 | ✅ | `resources/skills/`, `SkillManager`가 30 모두 등록(integration 모듈) |
| 캐릭터 | 6종 | 6 | ✅ | `ttukttaki`, `dolsoe`, `barami`, `byeolee`, `hwalee`, `geurimja` |
| 환경 | 5종 | 5 | ✅ | `resources/environments/*.tres` |
| 이벤트 | 7종 | 7 | ✅ | `resources/events/*.tres` |
| UI 화면 | 6종 (스펙 최소) | 14 | ✅ | 필수 6 (HUD, 결과화면, 일시정지, 캐릭터 선택, 챕터 선택, 메인 메뉴) 포함 + 부가 8 (codex, achievements, level_up_panel, intermission, boss_hp_bar, permanent_upgrade, shinmok, toast) |
| 게임 화면 (런 진행) | 동작 | OK | ✅ | `MainGameScene` 로드/실행 검증 (load_tscn) |
| 메타 시스템 | 동작 | OK | ✅ | `meta` 모듈 PASS (`MetaProgressManager` 시드 오브 1299로드, 영구 업그레이드 적용 경로) |

## QA 모듈별 결과

### load_gd — PASS
- Details: `{"checked":163,"failed":0,"files":[]}`
- GDScript 163 파일 모두 파스 성공.

### load_tscn — PASS
- Details: `{"checked":137,"failed":0,"files":[]}`
- 씬 파일 137개 로드 성공.

### load_tres — PASS
- Details: `{"checked":129,"failed":0,"files":[]}`
- 리소스 .tres 129개 로드 성공.

### autoloads — PASS
- ChapterManager, SkillManager, MetaProgressManager 등 autoload 정상.

### chapter — PASS
- Details: `{"chapters":[{"id":"ch05_sinmok_heart","n":5},{"id":"ch03_hwangcheon","n":3},{"id":"ch02_sinryeong","n":2},{"id":"ch04_cheonsang","n":4},{"id":"ch_hidden_market","n":6},{"id":"ch01_dumeong","n":1}]}`
- 6 챕터 (5 본편 + 1 히든마켓).

### boss — PASS
- Details: `{"bosses":["b01_dokkaebibul_daejang","b02_gumiho","b03_jeoseung_saja","b04_cheondung_janggun","b05_heuk_ryong","b06_daewang_dokkaebi","mb01_jangsanbeom","mb02_imugi","mb03_chagwishin","mb04_geumdwaeji","mb05_geomeun_dokkaebi"],"checked":11}`

### skill — PASS
- Details: `{"checked":30,"skills":["geumgang_bulgwe","seed_burst","frost_ring","dragon_palace_wave","samaejinhwa","flint_burst","sand_storm","sinmok_blessing","world_tree_blessing","metal_chain","fire_orb","vine_whip","water_drop","phoenix_descent","rock_throw","earthquake","thorn_trap","earth_wall","thousand_swords","dagger_throw","flame_barrier","ice_age","thorn_vine","gold_shield","dragon_king_wrath","flame_breath","forest_wrath","landslide","mist_veil","dagger_storm"]}`

### character — PASS
- Details: `{"characters":[{"atk":8,"hp":80,"id":"barami"},{"atk":9,"hp":90,"id":"byeolee"},{"atk":9,"hp":150,"id":"dolsoe"},{"atk":11,"hp":85,"id":"geurimja"},{"atk":12,"hp":85,"id":"hwalee"},{"atk":10,"hp":100,"id":"ttukttaki"}]}`

### env_event — PASS
- Details: `{"env":5,"event":7}`

### ui — PASS
- Details: `{"checked":14,"scenes":["res://scenes/ui/result_screen.tscn","res://scenes/ui/character_select.tscn","res://scenes/ui/intermission.tscn","res://scenes/ui/shinmok.tscn","res://scenes/ui/toast.tscn","res://scenes/ui/permanent_upgrade.tscn","res://scenes/ui/pause_menu.tscn","res://scenes/ui/codex.tscn","res://scenes/ui/level_up_panel.tscn","res://scenes/ui/chapter_select.tscn","res://scenes/ui/boss_hp_bar.tscn","res://scenes/ui/hud.tscn","res://scenes/ui/achievements.tscn","res://scenes/main_menu/main_menu.tscn"]}`

### meta — PASS
- Details: `{"orig_orbs":1299}`

### integration — PASS
- Details: `{"skills_registered":30}`

## Outstanding Issues

없음. 모든 모듈 PASS, 회귀 0, 한글 깨짐 0, 기획서 카운트 100% 충족.
