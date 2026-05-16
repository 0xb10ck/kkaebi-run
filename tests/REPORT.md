# tests/REPORT.md — Kkaebi-Run QA 통합 리포트

> 본 문서는 **수동 관리되는 안정 리포트**다.
> `tests/qa_runner.gd`가 매 실행마다 `tests/qa_report.json` / `tests/qa_report.md`를
> 재생성하므로(워킹 트리 오염 원인), 두 파일은 `.gitignore`로 추적에서 제외했다.
> 본 REPORT.md만 형상관리 대상으로 유지한다.

## Summary

- **Status**: ✅ PASS
- **QA modules**: 12 / 12 PASS (errors 0, regression 0)
- **QA harness**: `tests/qa_runner.gd` (`bash tests/run_qa.sh`)
- **Headless test scripts**: 10종 `tests/test_*.gd` 모두 정상 (Godot 4 `--headless --script` 기준)
- **Korean encoding (mojibake)**: 0건 (U+FFFD 그렙 — `.gd` / `.tres` / `.tscn` / `.md` / `.json`)
- **Last verified**: 2026-05-16, exit code 0

## 전체 AC(Acceptance Criteria) 통과 항목

### 1. 기획서 카운트 (docs/phase1-spec.md · full-spec)

| 항목 | 목표 | 실측 | 상태 | 근거 |
|------|-----:|-----:|:----:|------|
| 일반 몬스터 | 53종 | 53 | ✅ | `resources/enemies/chapter1..5` 49 + `hidden` 4 |
| 보스 / 미니보스 | 11종 | 11 | ✅ | `resources/bosses/` (`b01..b06` + `mb01..mb05`) |
| 스킬 | 30종 | 30 | ✅ | `resources/skills/`, `SkillManager` 30 등록 |
| 캐릭터 | 6종 | 6 | ✅ | `ttukttaki`, `dolsoe`, `barami`, `byeolee`, `hwalee`, `geurimja` |
| 환경 | 5종 | 5 | ✅ | `resources/environments/*.tres` |
| 이벤트 | 7종 | 7 | ✅ | `resources/events/*.tres` |
| UI 화면 (최소) | 6종 | 14 | ✅ | 필수 6(HUD, 결과, 일시정지, 캐릭터 선택, 챕터 선택, 메인 메뉴) + 부가 8 |
| 메인 게임 씬 | 동작 | OK | ✅ | `MainGameScene` 로드/실행 |
| 메타 시스템 | 동작 | OK | ✅ | `MetaProgressManager` 시드 오브 로드 + 영구 강화 적용 |

### 2. qa_runner.gd 모듈별 결과 (12 / 12 PASS)

| # | Module | Result | 비고 |
|--:|--------|:------:|------|
| 1 | `load_gd` | ✅ PASS | GDScript 163 파일 파스 성공 |
| 2 | `load_tscn` | ✅ PASS | 씬 137개 로드 성공 |
| 3 | `load_tres` | ✅ PASS | 리소스 129개 로드 성공 |
| 4 | `autoloads` | ✅ PASS | EventBus / GameState / SkillManager / MetaState / ChapterManager 부팅 |
| 5 | `chapter` | ✅ PASS | 6 챕터(본편 5 + 히든 1) 노출 |
| 6 | `boss` | ✅ PASS | 11종 보스(`checked: 11`) |
| 7 | `skill` | ✅ PASS | 30종 스킬(`checked: 30`) |
| 8 | `character` | ✅ PASS | 6종 캐릭터 stats 검증 |
| 9 | `env_event` | ✅ PASS | 환경 5 + 이벤트 7 |
| 10 | `ui` | ✅ PASS | UI 씬 14개 로드 |
| 11 | `meta` | ✅ PASS | `MetaProgressManager` 시드 오브 로드 |
| 12 | `integration` | ✅ PASS | `skills_registered: 30` |

### 3. 헤드리스 시나리오 스크립트 (`tests/test_*.gd`)

10종 모두 `extends SceneTree` 기반 Godot 4 헤드리스 스크립트. 각 스크립트는 단독으로
`godot --headless --path . --script tests/<file>.gd` 실행이 가능하며,
실패 시 exit code 1을 반환한다.

| # | Script | 검증 범위 |
|--:|--------|-----------|
| 1 | `test_autoloads.gd` | 5종 Autoload 부트 + 초기 상태 + EventBus 시그널 정의 |
| 2 | `test_bosses.gd` | 11종 보스 페이즈 전환 · 사망 · 보상 · 다음 챕터 해금 흐름 |
| 3 | `test_chapters.gd` | 챕터 1~5 + 히든(6) 데이터 로드 + 60초 스폰 풀 시뮬레이션 |
| 4 | `test_characters.gd` | 6종 캐릭터 stats가 .tres = 스펙(§0.3/§X.2)과 일치 |
| 5 | `test_environment_events.gd` | 환경 5 + 랜덤 이벤트 7 동작 |
| 6 | `test_full_playthrough.gd` | ch01 시작 → 처치/레벨업/스킬 → 보스 → 다음 챕터 → 결과/메타 정산 풀 시뮬 |
| 7 | `test_meta.gd` | SaveStore round-trip + 영구 강화 · 신목 · 도감 |
| 8 | `test_monsters.gd` | 53종 일반 몬스터(M01..M53) 이동/공격 스모크 |
| 9 | `test_scene_flow.gd` | 메인 메뉴 → 캐릭터/챕터 선택 → 게임 → 결과 화면 전이 |
| 10 | `test_ui.gd` | UI 8종(메인 메뉴 · HUD · 레벨업 · 일시정지 · 결과 · 보스 HP · 도감 · 도전과제) 스모크 |

## 수정 항목(Fix) 목록

본 통합 리포트가 작성된 시점까지 누적된 수정 사항.

| 분류 | 항목 | 상태 |
|------|------|:----:|
| QA harness | `tests/qa_runner.gd` 파스 버그 수정 후 12/12 PASS 유지 | ✅ |
| QA harness | `tests/run_qa.sh` 헬퍼(GODOT_BIN auto-detect, exit code 전달) 추가 | ✅ |
| QA harness | `tests/qa_report.json` / `tests/qa_report.md` 자동 생성 — 추적 제외 | ✅ |
| Test scripts | `tests/test_*.gd` 10종 헤드리스 시나리오 도입 | ✅ |
| Workflow | QA 실행 후에도 `git status` clean 유지 — `.gitignore` 등록 + `git rm --cached` | ✅ |
| Regression | 12 모듈 회귀 0, 한글 mojibake 0 | ✅ |

> 본 라운드 신규 모듈/회귀 결함: **없음**. qa_runner 1 cycle 클린 PASS.

## 운영 메모

- `tests/qa_report.json` / `tests/qa_report.md`는 `qa_runner.gd`가 매 실행마다 덮어쓴다.
  형상관리 대상에서 제외되었으므로 워킹 트리 dirty 원인이 더 이상 발생하지 않는다.
  필요 시 로컬에서 `bash tests/run_qa.sh`로 재생성하여 참고용으로 사용한다.
- 본 `REPORT.md`는 수동 갱신 대상이다. AC 카운트나 모듈 구성이 변할 때만 업데이트한다.

---

tests 전체 통과 + 에러 0건
