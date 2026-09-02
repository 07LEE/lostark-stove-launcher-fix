# 동작 방식

[한국어](how-it-works.md) · [English](how-it-works.en.md)

`stove-launcher.sh`가 무엇을 우회하는지에 대한 기록입니다.

## 증상

- STOVE 런처 실행 시 업데이트 체크(`InstallStartTask`) 단계에서 아무 안내 없이 튕김
- 재실행해도 같은 지점에서 반복적으로 크래시
- 특정 Wine 빌드(예: wine-staging)에서 재현됨

## 원인

STOVE.exe의 업데이트 로직은 로컬에 저장된 매니페스트(`GameManifest_45.upf`)와 서버가 내려주는 최신 매니페스트를 비교(diff)해서 업데이트 대상을 판단합니다. 이 diff 과정이 해당 Wine 빌드에서 죽는 것으로 보입니다.

다만 STOVE.exe는 죽기 직전까지 서버에서 받아온 "진짜 최신 버전" 정보를 `AppData/Local/STOVE/GameManifest/45_<version>.json` 캐시 파일로 남겨 둡니다. 즉 죽는 원인은 "버전이 다른 두 매니페스트를 비교하는 코드 경로" 자체이지, 네트워크나 파일 접근 문제가 아닙니다.

## 우회 방법

1. 실행 전에 캐시 폴더에서 가장 높은 버전 번호를 찾습니다.
2. 로컬 `GameManifest_45.upf`의 `local_version` 값을 그 번호로 미리 맞춰 씁니다.
3. STOVE는 이미 최신 버전이라고 판단해, 크래시가 나는 diff 경로를 타지 않습니다.
4. 실제 패치는 런처에서 **게임실행** 버튼을 누를 때 도는 무결성 검사가 내려받습니다. 이 검사는 별도의 정상 동작하는 코드 경로입니다.
5. 실행 중에 서버 버전이 또 올라가면 한 번 더 동기화한 뒤 재시도합니다. 한 번 실행에 최대 2회입니다.

이 스크립트는 매니페스트의 **버전 번호만** 미리 맞춰서 크래시 경로를 피하는 우회책입니다. 실제 패치 파일 자체를 받아오지는 않으므로, 런처가 뜬 뒤 게임실행 버튼은 반드시 눌러야 합니다. 게임/런처가 버전업되어 크래시 원인 코드 자체가 바뀌면 이 우회책이 더 이상 듣지 않을 수 있습니다.

## 설치할 때 하는 일

`stove-launcher.sh`는 설치 프로그램을 겸합니다. 설치된 자리가 아닌 곳에서 실행되면 설치 모드로, 설치된 자리에서 실행되면 런처 모드로 동작합니다.

설치 모드에서는 `~/.local/share/applications`, 바탕화면 폴더(로케일에 따라 `~/바탕화면`일 수 있어 `xdg-user-dir`로 찾습니다), `~/Desktop`에서 이름에 `stove`가 들어가는 `.desktop` 파일을 찾아 `Exec=` 대상을 읽습니다. 그중 **교체해도 되는 첫 번째 대상**(홈 아래 있고, 쓰기 가능하고, `#!`로 시작하는 스크립트)을 백업(`<경로>.bak.<시각>`)한 뒤 그 자리에 자신을 복사합니다.

- 조건에 맞는 대상이 없고 STOVE 아이콘 자체가 없으면 `~/.local/bin/stove-launcher.sh`에 설치하고 `.desktop`도 새로 만듭니다.
- 아이콘은 있지만 Flatpak·Lutris 래퍼처럼 스크립트가 아닌 것을 실행 중이면 건드리지 않습니다. 그걸 덮어쓰면 게임 실행 자체가 깨지기 때문입니다. 이 경우 사용자가 직접 `Exec=`를 바꿔야 합니다.
- 이미 같은 내용이 설치돼 있으면 아무것도 하지 않습니다.

교체 직전에는 백업해둔 옛 스크립트에서 Wine 설정을 추출해 `~/.config/stove-launcher/env`에 보존합니다. `.../bin/wineserver`로 끝나는 경로와 `WINEPREFIX=` 값을 문자열로 찾는 방식이라, 변수로 조립된 경로(`$WINE_DIR/bin/wineserver`)나 명령 치환이 섞인 값은 일부러 건너뜁니다 — 그대로 옮겨 적으면 다음 실행 때 정의되지 않은 변수 때문에 스크립트가 죽습니다. 설정 파일이 이미 있으면 덮어쓰지 않습니다.

## 설정 값

우선순위는 **셸에서 export한 값 > `~/.config/stove-launcher/env` > 스크립트 기본값** 순입니다.

| 변수 | 기본값 | 설명 |
| --- | --- | --- |
| `WINEPREFIX` | `~/.wine-stove-staging` | STOVE를 설치한 Wine prefix |
| `STOVE_WINE_DIR` | (PATH의 `wine`) | 사용할 Wine 빌드 경로. `bin/wine`, `bin/wineserver`가 그 아래에 있어야 합니다 |
| `STOVE_DIR` | `<prefix>/drive_c/ProgramData/Smilegate/STOVE` | `STOVE.exe`가 있는 폴더 |
| `STOVE_GAME_MANIFEST` | `<prefix>/drive_c/ProgramData/Smilegate/Games/LOSTARK/combinedata_manifest/GameManifest_45.upf` | 로컬 매니페스트 파일 |
| `STOVE_GM_CACHE_DIR` | `<prefix>/drive_c/users/<사용자>/AppData/Local/STOVE/GameManifest` | STOVE가 최신 버전 정보를 캐시하는 폴더 |
| `STOVE_NVIDIA_PRIME` | 자동 감지 | NVIDIA PRIME 오프로드 사용 여부. NVIDIA 드라이버가 있으면 `1`, 없으면 `0` |
| `STOVE_LOG_FILE` | `~/.local/state/stove-launcher/stove-autofix.log` | 로그 파일 경로 |
| `STOVE_LAUNCHER_CONFIG` | `~/.config/stove-launcher/env` | 설정 파일 경로 |

설정 파일이 없으면 만들어도 됩니다. 아이콘을 새로 만들 때는 기존 STOVE 아이콘의 `Icon=` 값을 물려받으므로, 앱 목록에 STOVE 아이콘 그대로 표시됩니다.

## 부가 기능

- **중복 실행 방지**: 바탕화면 아이콘을 여러 번 눌러도 `flock`으로 두 번째 실행은 알림만 띄우고 조용히 종료됩니다.
- **로그**: 모든 시도가 `~/.local/state/stove-launcher/stove-autofix.log`에 타임스탬프와 함께 남습니다.
- **의존성 없음**: 매니페스트 수정은 `sed`로 처리해서 python 같은 런타임이 필요 없습니다. 값 두 개만 치환하므로 나머지 내용은 그대로 남고, 최초 1회 `.orig` 백업을 남긴 뒤 임시 파일로 쓰고 원자적으로 교체합니다.

## Windows 사용자 폴더 자동 탐지

Wine prefix 안의 Windows 사용자 폴더명(`drive_c/users/<이름>`)은 실제 로그인 계정명과 다를 수 있어서, 스크립트가 `Public`/`Default User`/`All Users`를 제외하고 이름순으로 첫 번째 폴더를 자동으로 찾아 씁니다. 한 prefix에 Windows 사용자가 여러 명이면 잘못 찾을 수 있는데, 그럴 때는 스크립트를 고치지 말고(설치/업데이트 때 덮어써집니다) `~/.config/stove-launcher/env`에 `: "${STOVE_GM_CACHE_DIR:=<실제 경로>}"`를 적습니다.

## 환경별 차이

개인적으로 겪은 환경(특정 Wine 빌드 + NVIDIA PRIME 하이브리드 그래픽)을 기준으로 작성되었습니다. 다른 환경에서는 위 [설정 값](#설정-값)을 참고해 조정합니다.
