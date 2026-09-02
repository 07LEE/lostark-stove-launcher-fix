# 로스트아크 STOVE 런처 크래시 픽스

[한국어](README.md) · [English](docs/README.en.md)

리눅스에서 Wine으로 STOVE 런처(로스트아크 한국 클라이언트)를 실행할 때, 업데이트 확인 단계에서 아무 안내 없이 종료되는 문제를 우회합니다.

## 설치

[Releases](../../releases/latest)에서 `STOVE-launcher-fix.desktop`을 받아 실행합니다. "신뢰할 수 없는 앱 런처" 창이 뜨면 **신뢰하고 실행**을 클릭합니다.

기존 STOVE 런처 스크립트를 백업하고 그 자리에 설치합니다. 이후에는 STOVE 아이콘으로 실행합니다.

런처가 뜨면 **게임실행** 버튼을 누릅니다. 이 스크립트는 버전 번호만 맞출 뿐 패치 파일을 받지 않습니다. 실제 게임 파일은 게임실행이 실행하는 무결성 검사가 내려받습니다.

## 안 될 때

STOVE 위치를 못 찾거나, 실행했는데 곧바로 종료되면 창이 떠서 물어봅니다. 안내대로 폴더를 고르면 저장되고 다시 묻지 않습니다.

실행 기록은 `~/.local/state/stove-launcher/stove-autofix.log`에 남습니다.

## AI 에이전트로 설치

Lutris, Bottles, Flatpak Wine처럼 설치 방식이 특이하면 위 설치 스크립트가 맞지 않을 수 있습니다. 이 경우 [skills/stove-launcher-fix](skills/stove-launcher-fix)의 스킬을 Claude Code·Codex·Antigravity 같은 AI 코딩 에이전트에 전달하면, 실제 설치 상태를 진단해 맞춰 설치합니다. 크래시 우회 로직은 `stove-launcher.sh`를 그대로 쓰고 경로 탐지와 연결만 대신합니다.

에이전트에 위 폴더 링크를 주고 설치해달라고 하면 됩니다. 저장소를 미리 받아둘 필요는 없습니다.
