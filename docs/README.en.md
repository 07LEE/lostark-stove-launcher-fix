# Lost Ark KR — STOVE launcher crash fix

[한국어](../README.md) · English

Works around the STOVE launcher (Korean Lost Ark client) crashing with no message at the update-check step under Wine on Ubuntu.

STOVE and the game are Korean software: the launcher UI, this script's notifications, and its messages are all Korean. Where you have to recognise Korean text, it is quoted and translated below.

## Install

Download the .deb from [Releases](../../../releases/latest) and double-click it. App Center opens; press **Install**, then start STOVE launcher fix from your applications list.

Once the launcher window opens, press the **게임실행** (Start Game) button. This script only pre-aligns the version number to avoid the crash; it does not download patch files. The actual game files are updated by the integrity check that 게임실행 runs.

## If it does not work

If STOVE cannot be located, or it exits immediately after launching, a dialog asks you to pick the folder it needs. Your answer is saved and you are not asked again.

The run log is at `~/.local/state/stove-launcher/stove-autofix.log`.

### What the Korean notifications say

| Notification | Meaning |
| --- | --- |
| 이미 설치돼 있습니다. STOVE 아이콘을 누르면 됩니다. | Already installed — click the STOVE shortcut. |
| 이제부터는 STOVE 아이콘을 누르면 됩니다. | Installed; from now on click the STOVE shortcut. |
| 앱 목록에서 STOVE를 실행하세요. | Installed, and a shortcut was created; launch STOVE from your applications list. |
| 앱 목록의 'STOVE (수정)' 아이콘으로 실행하세요. | Installed; your old shortcut was left alone, so use the new "STOVE (수정)" entry. |
| 기존 STOVE 아이콘이 …를 실행하도록 연결해주세요. | Installed, but your shortcut launches something else — repoint it at the script. |
| 설치 폴더를 만들 수 없습니다. | Could not create the install folder. |
| 기존 파일을 백업할 수 없어 중단했습니다. | Could not back up the existing file; install aborted. |
| …에 쓸 수 없습니다. | Could not write the script to that path; install failed. |
| wine 실행 파일을 찾을 수 없습니다. | Cannot find the `wine` binary — set `STOVE_WINE_DIR`. |
| STOVE 설치 경로(…)를 찾을 수 없습니다. | Cannot find your STOVE folder — check `WINEPREFIX` / `STOVE_DIR`. |
| STOVE.exe를 찾을 수 없습니다 … | `STOVE.exe` is not in `STOVE_DIR`. |
| Wine 빌드를 저장했습니다. STOVE 아이콘을 다시 눌러주세요. | Wine build saved; click the STOVE shortcut again. |
| 고른 폴더에서 STOVE.exe를 찾지 못했습니다 / 고른 폴더에 bin/wine 이 없습니다 | The folder you picked has no `STOVE.exe` / no `bin/wine`. |
| 이미 실행 중입니다 — 잠시만 기다려주세요 | Already running. If you see this when STOVE is not open, flock may be missing. |

## AI coding agents

If your install is unusual — Lutris, Bottles, Flatpak Wine — the install method above may not fit it. Hand [skills/stove-launcher-fix](../skills/stove-launcher-fix) to an agent like Claude Code, Codex, or Antigravity and it will inspect what is actually installed on your machine and wire it up. The crash workaround is still plain `stove-launcher.sh`; the skill only handles path discovery and hookup.

Give your agent the link to that folder and ask it to install the skill. You do not need to clone the repository first.
