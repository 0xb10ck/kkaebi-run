#!/usr/bin/env bash
# kkaebi-run QA 자동 실행 스크립트.
# 사용: bash tests/run_qa.sh
# 종료코드: 0 = 모든 모듈 PASS, 1 = 한 모듈이라도 FAIL.

set -u

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [ ! -x "$GODOT_BIN" ]; then
  if command -v godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot)"
  else
    echo "[QA] godot binary not found (tried $GODOT_BIN and PATH)" >&2
    exit 127
  fi
fi

cd "$PROJECT_DIR"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --script res://tests/qa_runner.gd
exit $?
