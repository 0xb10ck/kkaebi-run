#!/usr/bin/env bash
# Chrome AppleScript 자동화 권한 활성화 스크립트.
# AC4/AC5 검증 스크립트(verify_ac4_chrome_url.sh, verify_ac5_chrome_dom.sh)를
# 돌리기 전에 한 번 실행한다.
#
# 사용: bash tests/setup_chrome_automation.sh
# 종료코드: 0 = 설정 성공, 1 = 실패.

set -u

EXPECTED_DOMAIN="com.google.Chrome"

echo "[chrome-setup] AppleScriptEnabled 플래그를 활성화합니다…"
if ! defaults write "$EXPECTED_DOMAIN" AppleScriptEnabled -bool true; then
  echo "[chrome-setup][ERROR] defaults write 실패. Chrome이 설치되어 있는지 확인하세요." >&2
  exit 1
fi

CURRENT_VALUE="$(defaults read "$EXPECTED_DOMAIN" AppleScriptEnabled 2>/dev/null || echo "<unset>")"
echo "[chrome-setup] 현재 값: AppleScriptEnabled=${CURRENT_VALUE}"

if [ "$CURRENT_VALUE" != "1" ]; then
  echo "[chrome-setup][ERROR] 값이 1로 설정되지 않았습니다 (현재: ${CURRENT_VALUE})." >&2
  exit 1
fi

cat <<'EOF'

[chrome-setup] 다음 사항을 수동으로 확인해 주세요:

  1) Chrome 메뉴 → View → Developer → Allow JavaScript from Apple Events
     체크되어 있어야 AC5(DOM innerText) 검증이 동작합니다.
     defaults 만으로는 이 메뉴가 자동 체크되지 않는 빌드가 있어 수동 확인이 필요합니다.

  2) 처음 osascript로 Chrome을 제어할 때 macOS가 권한 다이얼로그를 띄웁니다.
       "Terminal" (또는 현재 셸을 호스팅하는 앱) wants access to control "Google Chrome"
     반드시 OK 를 눌러 허용하세요.
     이미 거부했다면:
       System Settings → Privacy & Security → Automation →
         Terminal (또는 iTerm/Claude 등) → Google Chrome 체크 박스 ON.

  3) System Events 폴백(메뉴 조작 자동화)을 쓰는 경우 Accessibility 권한이 추가로 필요합니다:
       System Settings → Privacy & Security → Accessibility →
         Terminal (또는 사용 중인 셸 호스트 앱) 추가 후 ON.

[chrome-setup] 위 항목을 확인했다면 이제 다음 명령으로 검증을 실행할 수 있습니다:
    bash tests/verify_ac4_chrome_url.sh
    bash tests/verify_ac5_chrome_dom.sh

EOF

exit 0
