# 동작 방식

[한국어](how-it-works.md) · [English](how-it-works.en.md)

`stove-launcher.sh`가 무엇을 우회하는지에 대한 기록입니다. 다루는 것은 `InstallStartTask` 크래시뿐이며, 계정·로그인·지역 제한은 건드리지 않습니다.

## 증상

- STOVE 런처 실행 시 업데이트 체크(`InstallStartTask`) 단계에서 아무 안내 없이 종료됨
- 다시 실행해도 같은 지점에서 반복적으로 크래시
- 일부 Wine 빌드에서만 재현됨

## 원인

STOVE.exe는 로컬 매니페스트(`GameManifest_45.upf`)와 서버가 내려주는 최신 매니페스트를 비교(diff)해서 업데이트 대상을 판단합니다. 이 diff가 해당 Wine 빌드에서 죽는 것으로 보입니다.

다만 STOVE.exe는 죽기 전에 서버에서 받아온 최신 버전을 `AppData/Local/STOVE/GameManifest/45_<version>.json` 캐시로 남겨 둡니다. 즉 원인은 버전이 다른 두 매니페스트를 비교하는 코드 경로이지, 네트워크나 파일 접근 문제가 아닙니다.

## 우회 방법

1. 실행 전에 위 캐시 폴더에서 가장 큰 `45_<숫자>.json`의 숫자를 찾습니다.
2. 로컬 `GameManifest_45.upf`의 `local_version`을 그 숫자로 바꾸고, 파일 안의 `45_<숫자>.json` 부분도 맞춥니다.
3. STOVE는 이미 최신이라고 판단해 크래시가 나는 diff 경로를 타지 않고 정상 시작합니다.
4. 실제 패치는 런처의 **게임실행** 버튼이 도는 무결성 검사가 내려받습니다. 이 경로는 정상 동작하며, 버튼을 누르기 전에는 아무것도 내려받지 않습니다.
5. 실행 중 서버 버전이 또 올라가면 한 번 더 동기화하고 다시 실행합니다. 한 번 실행에 최대 2회입니다.

매니페스트는 처음 수정할 때 `GameManifest_45.upf.orig`로 백업하고, 이후에는 임시 파일에 쓴 뒤 원자적으로 교체합니다. 위 두 값 외에는 바이트 단위로 그대로입니다. 게임이나 런처가 크래시 원인 코드를 바꾸면 이 우회책은 듣지 않을 수 있습니다.

## 설치할 때 하는 일

`stove-launcher.sh`는 설치 프로그램을 겸합니다. 설치된 자리가 아닌 곳에서 실행하면 설치 모드, 설치된 자리에서 실행하면 런처 모드로 동작합니다. .deb으로 설치되면 `/usr/bin`에 놓이고, 시스템 경로에서는 항상 런처로만 동작합니다.

설치 모드는 `~/.local/share/applications`, 바탕화면 폴더(xdg-user-dir), `~/Desktop`에서 이름에 `stove`가 들어가는 `.desktop`의 `Exec=` 대상을 읽습니다. 그중 교체해도 되는 첫 대상(홈 아래에 있고, 쓰기 가능하며, `#!`로 시작하는 스크립트)을 `<경로>.bak.<시각>`으로 백업한 뒤 그 자리에 자신을 복사합니다.

- 대상이 없고 STOVE 아이콘도 없으면 `~/.local/bin/stove-launcher.sh`에 설치하고 `.desktop`을 새로 만듭니다.
- 아이콘이 Flatpak·Lutris 래퍼처럼 스크립트가 아닌 것을 실행하면 덮어쓰지 않습니다. zenity로 물어본 뒤 `STOVE (수정)` 아이콘을 새로 만들고, zenity가 없거나 거절하면 알림만 띄웁니다. 이 경우 `Exec=`를 직접 바꿔야 합니다.
- 같은 내용이 이미 설치돼 있으면 아무것도 하지 않습니다.

교체 직전에 옛 스크립트에서 Wine 경로(`.../bin/wineserver`)와 `WINEPREFIX=` 값을 찾아 `~/.config/stove-launcher/env`에 옮깁니다. 변수로 조립된 경로는 정의되지 않은 변수로 스크립트를 죽일 수 있어 건너뛰며, 설정 파일이 이미 있으면 덮어쓰지 않습니다.

새 아이콘은 기존 STOVE 아이콘의 `Icon=` 값을 물려받습니다. .deb은 STOVE 로고를 넣을 수 없어 기본 아이콘으로 시작하고, 처음 실행할 때 이 컴퓨터의 STOVE 아이콘을 찾아 사용자용 `.desktop`(`~/.local/share/applications/`)을 만들어 시스템 항목보다 우선시킵니다.

## 설정 값

우선순위는 셸에서 export한 값 > `~/.config/stove-launcher/env` > 스크립트 기본값입니다. 설정 파일은 기본으로 없으므로 필요하면 만듭니다.

| 변수 | 기본값 | 설명 |
| --- | --- | --- |
| `WINEPREFIX` | `~/.wine-stove-staging` | STOVE를 설치한 Wine prefix |
| `STOVE_WINE_DIR` | (PATH의 `wine`) | 사용할 Wine 빌드 경로. 그 아래에 `bin/wine`, `bin/wineserver`가 있어야 합니다 |
| `STOVE_DIR` | `<prefix>/drive_c/ProgramData/Smilegate/STOVE` | `STOVE.exe`가 있는 폴더 |
| `STOVE_GAME_MANIFEST` | `<prefix>/drive_c/ProgramData/Smilegate/Games/LOSTARK/combinedata_manifest/GameManifest_45.upf` | 로컬 매니페스트 |
| `STOVE_GM_CACHE_DIR` | `<prefix>/drive_c/users/<사용자>/AppData/Local/STOVE/GameManifest` | 최신 버전 캐시 폴더 |
| `STOVE_NVIDIA_PRIME` | 자동 감지 | NVIDIA PRIME 오프로드. NVIDIA 드라이버가 있으면 `1`, 없으면 `0` |
| `STOVE_LOG_FILE` | `~/.local/state/stove-launcher/stove-autofix.log` | 로그 파일 |
| `STOVE_LAUNCHER_CONFIG` | `~/.config/stove-launcher/env` | 설정 파일 |

`stove-launcher.sh`를 고치지 말고(설치할 때 덮어써집니다) 이 변수들로 조정하세요.

## 부가 기능

- 중복 실행 방지: 아이콘을 여러 번 눌러도 첫 실행만 통과하고 나머지는 `이미 실행 중입니다` 알림 후 종료됩니다. 아무것도 실행 중이 아닌데 뜬다면 flock(util-linux)이 없을 가능성이 큽니다.
- STOVE 위치 탐지: 기본 prefix에 STOVE가 없으면 `~/.wine*`, `~/Games/*`, Lutris·Bottles·Flatpak Wine 경로에서 `STOVE.exe`를 찾습니다. 못 찾으면 zenity로 폴더를 묻고 설정 파일에 저장합니다.
- Wine 빌드 선택: `STOVE_WINE_DIR`이 없는 상태에서 STOVE가 8초 안에 종료되면 다른 Wine 빌드를 고르는 창을 띄우고 저장합니다.
- 런타임 의존성 없음: 매니페스트는 sed로 수정하므로 Python이나 jq가 필요 없습니다.

## Windows 사용자 폴더 탐지

Wine prefix 안의 Windows 사용자 폴더(`drive_c/users/<이름>`)는 로그인 계정명과 다를 수 있어, `Public`/`Default User`/`All Users`를 뺀 첫 폴더를 이름순으로 씁니다. 한 prefix에 사용자가 여러 명이면 잘못 고를 수 있으며, 이때는 로그에 `synced local_version …` 줄이 없고 크래시가 다시 납니다. `AppData/Local/STOVE/GameManifest`가 있는 폴더가 맞는 폴더입니다. `~/.config/stove-launcher/env`에 `GameManifest` 폴더 자체를 적어 지정합니다.

```sh
: "${STOVE_GM_CACHE_DIR:=/home/you/.wine-stove-staging/drive_c/users/you/AppData/Local/STOVE/GameManifest}"
```
