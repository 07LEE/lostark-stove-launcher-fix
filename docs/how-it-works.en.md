# How it works

[한국어](how-it-works.md) · English

A record of what `stove-launcher.sh` works around. It covers the `InstallStartTask` crash and nothing else — accounts, login, and region restrictions are outside what it touches.

## Symptoms

- The STOVE launcher exits at the update-check (`InstallStartTask`) stage with no message.
- Running it again crashes at the same point, every time.
- Reproduced on some Wine builds and not others.

## Root cause

STOVE.exe decides what needs updating by diffing the local manifest (`GameManifest_45.upf`) against the latest manifest the server hands it. That diff is what dies on the affected Wine builds.

Before it dies, though, STOVE.exe has already cached the real latest version as `AppData/Local/STOVE/GameManifest/45_<version>.json`. So the crash is in the code path that compares two manifests of different versions — not a network or file-access problem.

## The workaround

1. Before launching, find the largest `45_<digits>.json` number in the cache folder above.
2. Write that number into `local_version` of the local `GameManifest_45.upf`, and rewrite the `45_<n>.json` part of the file to match.
3. STOVE concludes it is already up to date, never enters the crashing diff path, and starts normally.
4. The actual patch is handled by the integrity check that **게임실행** (Start Game) runs in the launcher. That path works, and nothing downloads until you press it.
5. If the server version goes up again while STOVE is running, the script syncs once more and relaunches — at most twice per run.

The first time it modifies the manifest, it copies the original to `GameManifest_45.upf.orig`; later edits go to a temporary file that is moved over the manifest atomically. Apart from those two values the file stays byte for byte identical. If the game or launcher changes the crashing code itself, the workaround may stop working.

## What the installer does

`stove-launcher.sh` is its own installer. Run from anywhere other than its installed location it installs itself; run from the installed location it launches STOVE. Installed from the .deb it lives in `/usr/bin`, and anything under a system path always runs as the launcher.

Installing, it reads the `Exec=` target of every `.desktop` file with `stove` in the name under `~/.local/share/applications`, your desktop folder (xdg-user-dir) and `~/Desktop`. It replaces the first target that is safe to replace — a writable file under your home directory that starts with `#!` — after copying it to `<path>.bak.<timestamp>`.

- If no such target exists and there is no STOVE shortcut at all, it installs to `~/.local/bin/stove-launcher.sh` and creates a `.desktop` entry.
- If a shortcut launches something that is not a script (a Flatpak or Lutris wrapper), it is left alone. A zenity dialog offers to create a new `STOVE (수정)` shortcut instead; if zenity is missing or you decline, you only get a notification and must repoint `Exec=` yourself.
- If the same content is already installed, it does nothing.

Just before replacing the old script, it copies the Wine path (`.../bin/wineserver`) and `WINEPREFIX=` value found in the backup into `~/.config/stove-launcher/env`. Paths built from shell variables are skipped, since an undefined variable would kill the script, and an existing config file is never overwritten.

A new shortcut copies the `Icon=` of your existing STOVE entry. The .deb cannot ship the STOVE logo, so it starts with a default icon; on first run the launcher finds this machine's STOVE icon and writes a per-user `.desktop` in `~/.local/share/applications/` that takes precedence over the system entry.

## Settings

Precedence: a value exported in your shell > `~/.config/stove-launcher/env` > the script's default. The config file does not exist by default; create it if you need it.

| Variable | Default | Meaning |
| --- | --- | --- |
| `WINEPREFIX` | `~/.wine-stove-staging` | Wine prefix STOVE is installed in |
| `STOVE_WINE_DIR` | (`wine` on `PATH`) | Wine build to use (`bin/wine` and `bin/wineserver` must be under it) |
| `STOVE_DIR` | `<prefix>/drive_c/ProgramData/Smilegate/STOVE` | Folder holding `STOVE.exe` |
| `STOVE_GAME_MANIFEST` | `<prefix>/drive_c/ProgramData/Smilegate/Games/LOSTARK/combinedata_manifest/GameManifest_45.upf` | Local manifest |
| `STOVE_GM_CACHE_DIR` | `<prefix>/drive_c/users/<user>/AppData/Local/STOVE/GameManifest` | Where STOVE caches the newest version |
| `STOVE_NVIDIA_PRIME` | auto-detected | NVIDIA PRIME offload. `1` if an NVIDIA driver is present, else `0` |
| `STOVE_LOG_FILE` | `~/.local/state/stove-launcher/stove-autofix.log` | Log file |
| `STOVE_LAUNCHER_CONFIG` | `~/.config/stove-launcher/env` | Config file |

Adjust things through these variables rather than editing `stove-launcher.sh`, which installs overwrite.

## Extras

- Single-instance guard: click the icon several times and only the first run gets through; the rest show `이미 실행 중입니다` ("already running") and exit. If you see that when nothing is running, flock (from util-linux) is probably missing.
- STOVE discovery: if the default prefix has no STOVE, it looks for `STOVE.exe` under `~/.wine*`, `~/Games/*`, and Lutris, Bottles and Flatpak Wine locations. If none is found it asks with zenity and saves the answer to the config file.
- Wine build picker: with `STOVE_WINE_DIR` unset, if STOVE exits within 8 seconds a dialog offers to pick another Wine build and saves it.
- No runtime dependency: the manifest is edited with sed, so no Python or jq is needed.

## Windows user folder detection

The Windows user folder in the Wine prefix (`drive_c/users/<name>`) can differ from your login name, so the script takes the first folder in name order, excluding `Public`, `Default User` and `All Users`. If one prefix holds several Windows users it can pick the wrong one; the log then has no `synced local_version …` line and the crash returns. The right folder contains `AppData/Local/STOVE/GameManifest`. Point the script at the `GameManifest` folder itself in `~/.config/stove-launcher/env`:

```sh
: "${STOVE_GM_CACHE_DIR:=/home/you/.wine-stove-staging/drive_c/users/you/AppData/Local/STOVE/GameManifest}"
```
