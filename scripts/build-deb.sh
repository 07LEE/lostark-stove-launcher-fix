#!/bin/bash
# 더블클릭으로 설치할 수 있는 .deb 패키지를 만든다.
#
# GNOME(파일 관리자)은 .desktop이든 .sh든 더블클릭하면 텍스트 편집기로 연다.
# .deb은 앱 센터로 연결되므로, 터미널 없이 설치할 수 있는 경로는 이것뿐이다.
#
# 사용법: ./scripts/build-deb.sh [버전]   (기본 버전: 1.0.0)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/stove-launcher.sh"
VERSION="${1:-1.0.0}"
PKG="lostark-stove-launcher-fix"
# AppStream 컴포넌트 ID는 역도메인 형식이어야 한다. 각 구간은 숫자로 시작할 수 없어서
# 계정명 07LEE 앞에 밑줄을 붙인다(AppStream 권장 표기).
APPID="io.github._07lee.LostArkStoveLauncherFix"
OUT_DIR="$ROOT/dist"
BUILD="$OUT_DIR/${PKG}_${VERSION}"

bash -n "$SRC" || { echo "문법 오류가 있는 스크립트는 배포할 수 없습니다: $SRC" >&2; exit 1; }

rm -rf "$BUILD"
mkdir -p "$BUILD/DEBIAN" "$BUILD/usr/bin" "$BUILD/usr/share/applications"

install -m 755 "$SRC" "$BUILD/usr/bin/stove-launcher-fix"

cat > "$BUILD/usr/share/applications/$APPID.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=STOVE launcher fix
Name[ko]=STOVE (수정)
Comment=Launch the STOVE launcher with the update-check crash workaround
Comment[ko]=업데이트 확인 크래시 우회를 적용해 STOVE 런처를 실행합니다
Exec=/usr/bin/stove-launcher-fix
Terminal=false
Categories=Game;
StartupWMClass=STOVE.exe
EOF

mkdir -p "$BUILD/usr/share/metainfo"
cat > "$BUILD/usr/share/metainfo/$APPID.metainfo.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>$APPID</id>
  <name>STOVE launcher fix</name>
  <name xml:lang="ko">STOVE 런처 수정</name>
  <summary>Fix for the Lost Ark KR launcher crashing at its update check</summary>
  <summary xml:lang="ko">로스트아크 STOVE 런처 업데이트 확인 크래시 우회</summary>
  <metadata_license>MIT</metadata_license>
  <project_license>MIT</project_license>
  <developer id="io.github.lee07">
    <name>07LEE</name>
  </developer>
  <description>
    <p>
      The STOVE launcher crashes at its update check when it runs under Wine on Linux.
      This launches STOVE with the manifest version pre-aligned, so the comparison that
      crashes never runs. Start "STOVE launcher fix" from your applications list; the
      game itself is patched by the integrity check behind the launcher's play button.
    </p>
    <p xml:lang="ko">
      리눅스에서 Wine으로 STOVE 런처를 실행하면 업데이트 확인 단계에서 종료됩니다.
      매니페스트 버전을 미리 맞춰써서 크래시가 나는 비교 경로를 건너뜁니다. 앱 목록의
      "STOVE (수정)"으로 실행하고, 런처가 뜨면 게임실행 버튼을 누르면 됩니다.
    </p>
  </description>
  <launchable type="desktop-id">$APPID.desktop</launchable>
  <url type="homepage">https://github.com/07LEE/lostark-stove-launcher-fix</url>
  <url type="bugtracker">https://github.com/07LEE/lostark-stove-launcher-fix/issues</url>
  <categories>
    <category>Game</category>
  </categories>
  <content_rating type="oars-1.1"/>
  <releases>
    <release version="$VERSION" date="${RELEASE_DATE:-$(TZ=Asia/Seoul date +%Y-%m-%d)}"/>
  </releases>
</component>
EOF

cat > "$BUILD/DEBIAN/control" <<EOF
Package: $PKG
Version: $VERSION
Section: games
Priority: optional
Architecture: all
Depends: bash
Recommends: zenity, libnotify-bin
Maintainer: 07LEE <95900411+07LEE@users.noreply.github.com>
Description: Lost Ark KR STOVE launcher crash fix
 The STOVE launcher crashes at its update check under Wine on Linux.
 This package launches STOVE with the version number pre-aligned so the
 crashing comparison never runs. Install it, then start "STOVE launcher fix"
 from your applications list.
EOF

dpkg-deb --build --root-owner-group "$BUILD" >/dev/null
DEB="$OUT_DIR/${PKG}_${VERSION}_all.deb"
mv "$BUILD.deb" "$DEB"
rm -rf "$BUILD"

# 패키지 안의 스크립트가 원본과 같은지 확인한다.
tmp="$(mktemp -d)"
dpkg-deb -x "$DEB" "$tmp"
cmp "$tmp/usr/bin/stove-launcher-fix" "$SRC"
bash -n "$tmp/usr/bin/stove-launcher-fix"
desktop-file-validate "$tmp/usr/share/applications/$APPID.desktop" 2>/dev/null || true
rm -rf "$tmp"

echo "생성됨: $DEB"
dpkg-deb --info "$DEB" | sed -n '2,8p'
