# Art Pipeline (Kkaebi Run)

`docs/art-palette.json` + `docs/art-asset-spec.md` 를 단일 소스로 픽셀아트 PNG들을 일괄 생성한다.

## 산출물

| 카테고리 | 출력 위치 | 시트 크기 |
|---------|----------|-----------|
| 캐릭터(6종) | `assets/generated/characters/<id>.png` | 640×32 (20프레임) |
| 일반 몬스터 | `assets/generated/monsters/<id>.png` | 320×32 (10프레임) |
| 보스/미니보스 | `assets/generated/bosses/<id>.png` | 768×64 (12프레임) |
| 챕터 타일셋(5) | `assets/generated/tilesets/<chapter>/tileset.png` + 개별 타일 | 8×8 그리드 시트 |
| 스킬 이펙트 | `assets/generated/effects/fx_<shape>_<key>.png` | 128×32 (4프레임) |
| UI | `assets/generated/ui/*.png` | 다양 |

각 PNG 옆에 Godot 4 호환 `.import` 사이드카가 함께 생성된다(이미 있으면 보존).

## 설치

가상환경 권장:

```bash
python3 -m venv .venv
source .venv/bin/activate    # Windows: .venv\Scripts\activate
python -m pip install -r tools/art_pipeline/requirements.txt
```

시스템 파이썬에 직접 설치해도 동작한다(Pillow>=10).

## 실행

프로젝트 루트(`kkaebi-run/`)에서:

```bash
python -m tools.art_pipeline.build_all
```

부분 빌드:

```bash
python -m tools.art_pipeline.build_all --only=characters
python -m tools.art_pipeline.build_all --only=monsters,effects
```

기타 옵션:

| 옵션 | 설명 |
|------|------|
| `--out PATH` | 출력 루트 디렉토리 변경 (기본: `assets/generated`) |
| `--no-import` | Godot `.import` 사이드카 생성 스킵 |
| `--force` | 캐시 무시하고 전 카테고리 재빌드 |

## 캐싱 정책

- `assets/generated/.art_cache.json` 에 카테고리별 빌드 상태를 저장한다.
- 캐시 키는 `<category>::<sha256(art-palette.json)[:16]>` — 팔레트가 바뀌면 자동 무효화된다.
- 카테고리 폴더가 존재하고 캐시가 히트하면 스킵한다.
- 강제 재빌드는 `--force` 또는 캐시 파일 삭제.

## 폴더 구조

```
tools/art_pipeline/
├── __init__.py
├── README.md
├── requirements.txt
├── palette.py          # JSON 로더, 색 헬퍼(밝게/어둡게/외곽선)
├── primitives.py       # 픽셀 도형 (원/타원/사각/물방울/외곽선/대칭 stamp/시프트/스케일/시트 합성)
├── character.py        # SD 캐릭터 (640×32, idle4+run6+attack4+hit2+die4)
├── monster.py          # 일반 몬스터 (320×32, idle4+attack3+die3, 카테고리별 실루엣)
├── boss.py             # 보스 (768×64, idle4+attack4+die4, 캐릭터 렌더러 ×2)
├── tileset.py          # 16×16 ground/wall/deco 챕터별 5종 + 8×8 시트
├── effects.py          # 스킬 이펙트 32×32 4프레임 — projectile/aoe/aura × 6 색
├── ui.py               # 버튼(9-slice), 한지/나무 패널, HP바, 스킬 프레임, 레벨업, 로고, 배경
├── godot_import.py     # Godot 4 `.import` 사이드카 생성기
└── build_all.py        # 진입점 (CLI: --only, --out, --no-import, --force)
```

## 디자인 원칙

- **디더링 없음**, 외곽선 1px (`#1A1A1A`).
- 좌표는 항상 안전 클리핑 (out-of-bounds 무시).
- 모든 색은 `art-palette.json` 토큰만 사용. 자유 HEX는 헬퍼(`lighten`/`darken`)로 파생.
- 프레임 메타는 PNG 옆에 `<id>.frames.json` 으로 동봉.
- 신규 파일만 추가. 기존 코드/씬/리소스를 수정하지 않는다.
