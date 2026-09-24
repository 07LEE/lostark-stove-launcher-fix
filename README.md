# 로스트아크 STOVE 런처 크래시 픽스

[한국어](README.md) · [English](docs/README.en.md)

우분투에서 Wine으로 STOVE 런처(로스트아크 한국 클라이언트)를 실행할 때, 업데이트 확인 단계에서 아무 안내 없이 종료되는 문제를 우회합니다.

## 설치

[Releases](../../releases/latest)에서 .deb 파일을 받아 더블클릭하면 앱 센터가 열립니다. **Install** 버튼을 누른 뒤, 앱 목록에서 STOVE (수정) 항목을 실행합니다.

런처가 뜨면 **게임실행** 버튼을 누릅니다. 이 스크립트는 버전 번호만 맞출 뿐 패치 파일을 받지 않습니다. 실제 게임 파일은 게임실행이 실행하는 무결성 검사가 내려받습니다.

## 안 될 때

STOVE 설치 위치를 찾지 못하거나 실행 직후 종료되면 폴더를 선택하는 창이 뜹니다. 한 번 선택하면 저장되어 다시 묻지 않습니다.

실행 기록은 `~/.local/state/stove-launcher/stove-autofix.log`에 남습니다.

## AI 에이전트로 설치

Lutris, Bottles, Flatpak Wine처럼 설치 방식이 특이하면 위 설치 방법이 맞지 않을 수 있습니다. 이 경우 [skills/stove-launcher-fix](skills/stove-launcher-fix)의 스킬을 Claude Code·Codex·Antigravity 같은 AI 코딩 에이전트에 전달하면, 실제 설치 상태를 진단해 맞춰 설치합니다. 크래시 우회 로직은 `stove-launcher.sh`를 그대로 쓰고 경로 탐지와 연결만 대신합니다.

에이전트에 위 폴더 링크를 주고 설치해달라고 하면 됩니다. 저장소를 미리 받아둘 필요는 없습니다.
