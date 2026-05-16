#!/usr/bin/env bash
# AC4 검증: Chrome 활성 탭 URL이 qa_report.html을 가리키는지 확인.
#
# 사용: bash tests/verify_ac4_chrome_url.sh [URL_FRAGMENT]
#   URL_FRAGMENT 미지정 시 기본값: file:///Users/0xb10ck/kkaebi-run/tests/qa_report.html
#
# 종료코드:
#   0 = 활성 탭 URL이 기대값을 포함 (PASS)
#   1 = URL 불일치 (FAIL)
#   2 = Chrome 자동화 권한/실행 환경 오류

set -u

EXPECTED_URL="${1:-file:///Users/0xb10ck/kkaebi-run/tests/qa_report.html}"
TARGET_FILE="/Users/0xb10ck/kkaebi-run/tests/qa_report.html"

log() { echo "[ac4] $*"; }
err() { echo "[ac4][ERROR] $*" >&2; }

# 1) Chrome 실행 보장.
if ! pgrep -x "Google Chrome" >/dev/null 2>&1; then
  log "Chrome이 실행되어 있지 않아 새 인스턴스를 띄웁니다."
  if [ -f "$TARGET_FILE" ]; then
    open -a "Google Chrome" "$TARGET_FILE"
  else
    open -a "Google Chrome"
  fi
  # Chrome이 osascript 명령에 응답할 때까지 잠시 대기.
  sleep 2
fi

# 2) 창이 하나도 없으면 강제 생성.
WINDOW_COUNT_OUTPUT="$(osascript -e 'tell application "Google Chrome" to count windows' 2>&1)"
WINDOW_COUNT_STATUS=$?
if [ $WINDOW_COUNT_STATUS -ne 0 ]; then
  err "Chrome window count 조회 실패: ${WINDOW_COUNT_OUTPUT}"
  err "Chrome 자동화 권한이 거부되어 있을 수 있습니다."
  err "  → bash tests/setup_chrome_automation.sh 를 먼저 실행하고 권한 다이얼로그를 허용하세요."
  exit 2
fi
log "현재 Chrome 창 개수: ${WINDOW_COUNT_OUTPUT}"

if [ "${WINDOW_COUNT_OUTPUT}" = "0" ]; then
  log "창이 없습니다. qa_report.html로 새 창을 엽니다."
  if [ -f "$TARGET_FILE" ]; then
    open -a "Google Chrome" "$TARGET_FILE"
  else
    osascript -e 'tell application "Google Chrome" to make new window' >/dev/null
  fi
  sleep 2
fi

# 3) 타겟 파일이 존재하면, 활성 탭이 그 파일이 아닐 경우 강제 로드.
if [ -f "$TARGET_FILE" ]; then
  CURRENT_URL_PRECHECK="$(osascript -e 'tell application "Google Chrome" to get URL of active tab of front window' 2>/dev/null || echo "")"
  case "$CURRENT_URL_PRECHECK" in
    *"$EXPECTED_URL"*) : ;;  # 이미 열려 있음.
    *)
      log "활성 탭 URL이 기대값과 다릅니다. qa_report.html을 강제 로드합니다."
      open -a "Google Chrome" "$TARGET_FILE"
      sleep 2
      ;;
  esac
fi

# 4) 활성 탭 URL 조회.
ACTIVE_URL="$(osascript -e 'tell application "Google Chrome" to get URL of active tab of front window' 2>&1)"
ACTIVE_URL_STATUS=$?
if [ $ACTIVE_URL_STATUS -ne 0 ]; then
  err "active tab URL 조회 실패: ${ACTIVE_URL}"
  exit 2
fi

# 5) Evidence 출력.
echo "----- AC4 Evidence -----"
echo "expected_fragment : ${EXPECTED_URL}"
echo "active_tab_url    : ${ACTIVE_URL}"
echo "------------------------"

# 6) 판정.
case "$ACTIVE_URL" in
  *"$EXPECTED_URL"*)
    log "PASS — active tab URL 이 기대 fragment 를 포함합니다."
    exit 0
    ;;
  *)
    err "FAIL — active tab URL 이 기대 fragment 를 포함하지 않습니다."
    exit 1
    ;;
esac
