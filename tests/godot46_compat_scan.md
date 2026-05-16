# Godot 4.6.2 호환성 스캔 결과

작업 디렉토리: `/Users/0xb10ck/kkaebi-run`
대상: Godot 4.2 → 4.6.2 업그레이드

## 1. project.godot

| 항목 | 변경 전 | 변경 후 |
|---|---|---|
| `[application] config/features` | `PackedStringArray("4.2", "GL Compatibility")` | `PackedStringArray("4.6", "GL Compatibility")` |

그 외 섹션(`[autoload]`, `[display]`, `[input]`, `[layer_names]`, `[rendering]`)은 변경 없음.
렌더링 관련 features 문자열(`GL Compatibility`)은 보존했다.

## 2. .tscn / .tres 포맷 헤더 분포

총 파일 수: **266**

| 확장자 | 파일 수 |
|---|---|
| `.tres` | 129 |
| `.tscn` | 137 |

| `format=` | 파일 수 | 4.6 호환 |
|---|---|---|
| 3 | 266 | OK (그대로 로드) |

헤더 이상 항목: 없음.

### ext_resource 경로 검사

스캔 규칙: `[ext_resource ... path="res://..."]` 의 대상 파일 또는 `.import` 짝의 원본 파일 존재 확인.

누락/오타 경로: **0건**

## 3. GDScript deprecated API 스캔 및 자동 패치

스캔한 `.gd` 파일 수: **163** (`scripts/**/*.gd`)
주석(`#`) 및 문자열 리터럴 내부는 매칭에서 제외.

| 패턴 | 발견 건수 | 처리 |
|---|---|---|
| `PackedScene.instance()` → `.instantiate()` | 0 | 없음 |
| `yield` 키워드 → `await` | 0 | 없음 |
| 옛 3-인자 `connect("sig", obj, "method")` | 0 | 없음 |
| `tween_callback(callable, args)` (2-인자) | 0 | 없음 (`.bind()` 치환 불필요) |
| `RenderingServer.*` 호출 | 0 | 4.6에서 시그니처 유지 — 변경 없음 |
| `PhysicsServer2D/3D.*` 호출 | 0 | 4.6 유지 — 변경 없음 |
| `@onready` / `@export` / `@tool` / `@icon` 등 annotation | (변경 금지 대상) | 변경 없음 |
| `create_tween().tween_property(...).from()/from_current()` | (변경 금지 대상) | 변경 없음 |

`tween_callback` 호출(2건, 모두 단일 Callable 인자 형태)은 이미 4.x 시그니처를 따르고 있어 패치 대상이 아니다.
- `scripts/ui/result_screen.gd:61` — `tw.tween_callback(_restart_btn.grab_focus)`
- `scripts/bosses/cutscene.gd:65` — `tw.tween_callback(func() -> void: finished.emit())`

`.connect(...)` 호출(4건)은 모두 4.x 시그니처(`"signal_name", Callable)`)로 이미 마이그레이션 되어 있다.
- `scripts/ui/boss_hp_bar.gd:36`, `:38`
- `scripts/bosses/boss_base.gd:94`
- `scripts/bosses/boss_arena.gd:110`

### manual-review 필요 항목

없음.

## 4. 한글 인코딩(UTF-8 replacement char) 검사

명령:
```
grep -RIn $'\xef\xbf\xbd' project.godot scripts/ scenes/ resources/ tests/
```

결과: **0건**

## 5. 변경 파일 요약

| 파일 | 변경 내용 | 치환 건수 |
|---|---|---|
| `project.godot` | `[application] config/features` 의 `"4.2"` → `"4.6"` | 1 |

총 치환 건수: **1**.
GDScript / `.tscn` / `.tres` 의 자동 패치 변경은 없음(deprecated 패턴 미발견).
