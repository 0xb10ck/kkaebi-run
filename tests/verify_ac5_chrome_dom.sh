#!/usr/bin/env bash
# AC5 검증: Chrome 활성 탭에서 document.body.innerText.length 가 0보다 큰지 확인.
#
# 사용: bash tests/verify_ac5_chrome_dom.sh [MIN_LENGTH]
#   MIN_LENGTH 미지정 시 기본값 1 (즉 0보다 크면 PASS).
#
# 종료코드:
#   0 = innerText length >= MIN_LENGTH (PASS)
#   1 = length 가 부족 (FAIL)
#   2 = Chrome 자동화/JS-from-AppleEvents 권한 환경 오류

set -u

MIN_LENGTH="${1:-1}"

log() { echo "[ac5] $*"; }
err() { echo "[ac5][ERROR] $*" >&2; }

# 1) Chrome 실행/창 존재 확인.
if ! pgrep -x "Google Chrome" >/dev/null 2>&1; then
  err "Chrome 이 실행되어 있지 않습니다. 먼저 verify_ac4_chrome_url.sh 를 실행하거나 Chrome 을 띄우세요."
  exit 2
fi

WINDOW_COUNT_OUTPUT="$(osascript -e 'tell application "Google Chrome" to count windows' 2>&1)"
if [ $? -ne 0 ]; then
  err "Chrome window count 조회 실패: ${WINDOW_COUNT_OUTPUT}"
  err "  → bash tests/setup_chrome_automation.sh 를 먼저 실행하고 자동화 권한을 허용하세요."
  exit 2
fi
if [ "${WINDOW_COUNT_OUTPUT}" = "0" ]; then
  err "Chrome 창이 없습니다. 먼저 verify_ac4_chrome_url.sh 로 qa_report.html 을 띄우세요."
  exit 2
fi

# 2) JavaScript 평가 실행.
#    bash 3.2(macOS 기본) heredoc-in-$() 이슈 + AppleScript 의 window's apostrophe 충돌을
#    피하기 위해 osascript -e 멀티 라인 형태로, "active tab of front window" 표기를 사용한다.
RAW_OUTPUT="$(osascript \
  -e 'tell application "Google Chrome"' \
  -e 'execute active tab of front window javascript "String(document.body.innerText.length)"' \
  -e 'end tell' 2>&1)"
OSA_STATUS=$?

# 3) 권한 관련 에러 식별.
if [ $OSA_STATUS -ne 0 ]; then
  err "JavaScript 실행 실패 (osascript exit=${OSA_STATUS}): ${RAW_OUTPUT}"
  case "$RAW_OUTPUT" in
    *"JavaScript"*|*"javascript"*|*"-1743"*|*"not allowed"*|*"-1728"*)
      err "Chrome 'View → Developer → Allow JavaScript from Apple Events' 가 OFF 일 가능성이 큽니다."
      err "또는 macOS Automation 권한이 거부되어 있을 수 있습니다."
      err "  → bash tests/setup_chrome_automation.sh 의 안내를 따라 활성화하세요."
      ;;
  esac
  exit 2
fi

# 4) 결과 정제 — execute javascript 는 빈 값을 반환할 수도 있음.
INNER_LEN_RAW="$(printf '%s' "$RAW_OUTPUT" | tr -d '\r' | tail -n 1)"

if [ -z "$INNER_LEN_RAW" ]; then
  err "innerText length 결과가 비어 있습니다. Allow JavaScript from Apple Events 가 꺼져 있을 때 발생합니다."
  err "  → bash tests/setup_chrome_automation.sh 안내 확인."
  exit 2
fi

case "$INNER_LEN_RAW" in
  ''|*[!0-9]*)
    err "innerText length 결과를 정수로 해석할 수 없습니다: '${INNER_LEN_RAW}'"
    exit 2
    ;;
esac

# 5) 부가 evidence — 현재 URL 도 함께 출력.
ACTIVE_URL="$(osascript -e 'tell application "Google Chrome" to get URL of active tab of front window' 2>/dev/null || echo "<unknown>")"

echo "----- AC5 Evidence -----"
echo "active_tab_url            : ${ACTIVE_URL}"
echo "document.body.innerText.length : ${INNER_LEN_RAW}"
echo "min_required_length       : ${MIN_LENGTH}"
echo "------------------------"

# 6) 판정.
if [ "$INNER_LEN_RAW" -ge "$MIN_LENGTH" ]; then
  log "PASS — innerText length(${INNER_LEN_RAW}) ≥ ${MIN_LENGTH}."
  exit 0
else
  err "FAIL — innerText length(${INNER_LEN_RAW}) < ${MIN_LENGTH}."
  exit 1
fi
