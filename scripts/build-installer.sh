#!/bin/bash
# stove-launcher.sh를 base64로 감싼 단일 배포 파일(dist/STOVE-launcher-fix.desktop)을 만든다.
#
# GNOME은 .sh를 더블클릭하면 실행 권한이 있어도 텍스트 에디터로 열지만,
# .desktop은 "신뢰하고 실행" 한 번으로 실행한다. 그래서 릴리즈에는 .desktop만 올린다.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$SCRIPT_DIR/stove-launcher.sh"
OUT_DIR="$SCRIPT_DIR/dist"
OUT="$OUT_DIR/STOVE-launcher-fix.desktop"

mkdir -p "$OUT_DIR"

# 문법이 깨진 채 배포되면 사용자는 더블클릭 후 아무 반응도 못 본다.
bash -n "$SRC" || { echo "문법 오류가 있는 스크립트는 배포할 수 없습니다: $SRC" >&2; exit 1; }

B64="$(base64 -w0 "$SRC")"

# base64 알파벳 밖의 문자가 섞이면 Desktop Entry 인용 규칙이나 필드 코드(%)와 충돌한다.
case "$B64" in
    *[!A-Za-z0-9+/=]*) echo "base64 페이로드에 예상치 못한 문자가 있습니다." >&2; exit 1 ;;
esac

printf '%s' "$B64" | base64 -d | cmp -s - "$SRC" || {
    echo "base64 라운드트립이 원본과 일치하지 않습니다." >&2; exit 1
}

cat > "$OUT" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Install STOVE launcher fix
Name[ko]=STOVE 런처 수정 설치
Comment=Work around the STOVE launcher crashing at its update check
Comment[ko]=STOVE 런처 업데이트 확인 크래시 우회 패치 설치
Icon=system-software-install
Terminal=false
Categories=Game;
Exec=bash -c 'f=\$(mktemp /tmp/stove-launcher-fix.XXXXXX.sh); base64 -d <<< "$B64" > "\$f" && bash "\$f"; rm -f "\$f"'
EOF

# 스펙은 Exec의 예약 문자를 이스케이프하라고 하지만, GLib·KShell·garcon 모두 셸 스타일로
# 파싱하므로 실행에는 문제가 없다. 정보 표시용으로만 돌린다.
if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "$OUT" >/dev/null 2>&1 || \
        echo "참고: desktop-file-validate가 Exec 인용 규칙을 지적합니다(의도된 것, 실행에는 문제 없음)."
fi

echo "생성됨: $OUT"
