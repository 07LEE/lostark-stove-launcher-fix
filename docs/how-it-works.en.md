# How it works

[한국어](how-it-works.md) · English

A record of what `stove-launcher.sh` works around. It covers the `InstallStartTask` crash and nothing else — accounts, login, and region restrictions are outside what this script touches.

## Symptoms

- The STOVE launcher exits at the update-check (`InstallStartTask`) stage with no message.
- Running it again crashes at the same point, every time.
- Reproduced on some Wine builds and not others.

## Root cause

STOVE.exe decides what needs updating by diffing the locally stored manifest (`GameManifest_45.upf`) against the latest manifest the server hands it. That diff is what dies on the affected Wine builds.

Before it dies, though, STOVE.exe has already written the real latest version it fetched into its cache, as `AppData/Local/STOVE/GameManifest/45_<version>.json`. So the crash is in the code path that compares two manifests of different versions — not a network or file-access problem.

## The workaround

1. Before launching, find the highest version number in the cache folder above. Cache file names are matched against `45_<digits>.json` and the largest number wins.
2. Write that number into the `local_version` field of the local `GameManifest_45.upf`, and rewrite the `45_<n>.json` part of `project_url` to match.
3. STOVE then concludes it is already up to date, never enters the crashing diff path, and starts normally.
4. The actual patch is handled when you press **게임실행** (Start Game) in the launcher. That runs STOVE's integrity check, which is a separate, working code path. Nothing downloads until you press it.
5. If the server version goes up again while STOVE is running, the script syncs once more and relaunches — at most twice per run.

The manifest is not overwritten in place. The first time the script modifies it, it copies the original to `GameManifest_45.upf.orig` and keeps that copy. Each edit is written to a temporary file and moved over the manifest atomically, so a process death mid-write cannot leave truncated JSON behind. Only those two values change; the rest of the file stays byte for byte identical.

This is a workaround: it aligns the version number to dodge the crashing path. If the game or launcher changes the crashing code itself, it may stop working.

## What the installer does

`stove-launcher.sh` is its own installer. Run from anywhere other than its installed location it installs itself; run from the installed location it launches STOVE. Installed from the `.deb` it lives in `/usr/bin`, and anything under a system path always runs as the launcher, never as the installer.

Installing, it searches `~/.local/share/applications`, your localized desktop folder (found via `xdg-user-dir`, so `~/바탕화면` and the like work), and `~/Desktop` for `.desktop` files with `stove` in the name, and reads each `Exec=` target. It replaces the first target that is safe to replace — a regular, writable file under your home directory that starts with `#!` — after copying it to `<path>.bak.<timestamp>`.

- If no such target exists and there is no STOVE shortcut at all, it installs to `~/.local/bin/stove-launcher.sh` and creates a `.desktop` entry for it.
- If a shortcut exists but launches something that is not a script (a Flatpak or Lutris wrapper), it is left alone — overwriting it could break launching the game — and you are asked to repoint it yourself.
- If the same content is already installed, it does nothing.

Just before replacing the old script, Wine settings are extracted from the backup into `~/.config/stove-launcher/env`: a path ending in `bin/wineserver`, and a `WINEPREFIX=` value. The match is textual, so paths assembled from shell variables (`$WINE_DIR/bin/wineserver`) or command substitution are deliberately skipped — copying them verbatim would leave an undefined variable that kills the script on the next run. An existing config file is never overwritten.

## Settings

Precedence: **a value exported in your shell > `~/.config/stove-launcher/env` > the script's default**.

| Variable | Default | Meaning |
| --- | --- | --- |
| `WINEPREFIX` | `~/.wine-stove-staging` | Wine prefix STOVE is installed in |
| `STOVE_WINE_DIR` | (`wine` on `PATH`) | Wine build to use (`bin/wine` and `bin/wineserver` must be under it) |
| `STOVE_DIR` | `<prefix>/drive_c/ProgramData/Smilegate/STOVE` | Folder holding `STOVE.exe` |
| `STOVE_GAME_MANIFEST` | `<prefix>/drive_c/ProgramData/Smilegate/Games/LOSTARK/combinedata_manifest/GameManifest_45.upf` | Local manifest file |
| `STOVE_GM_CACHE_DIR` | `<prefix>/drive_c/users/<user>/AppData/Local/STOVE/GameManifest` | Where STOVE caches the newest version info |
| `STOVE_NVIDIA_PRIME` | auto-detected | NVIDIA PRIME offload. `1` if an NVIDIA driver is present, `0` if not |
| `STOVE_LOG_FILE` | `~/.local/state/stove-launcher/stove-autofix.log` | Log file path |
| `STOVE_LAUNCHER_CONFIG` | `~/.config/stove-launcher/env` | Config file path |

When it creates a shortcut, it copies the `Icon=` value from your existing STOVE entry, so the new one keeps the STOVE icon.

## Extras

- **Single-instance guard**: click the icon several times and only the first run gets through; the rest show `이미 실행 중입니다` ("already running") and exit. If you see that when nothing is running, `flock` (from `util-linux`) is probably missing — any `flock` failure reads as "already running". If the lock file itself cannot be opened, the script continues without a lock instead of falsely reporting it, and notes that in the log.
- **Logging**: every attempt is timestamped in `~/.local/state/stove-launcher/stove-autofix.log` (`XDG_STATE_HOME` is honoured; `STOVE_LOG_FILE` overrides it). The lock lives at `${XDG_RUNTIME_DIR:-/tmp}/stove-launcher-<user>.lock`.
- **No runtime dependency**: the manifest edit is done with `sed`, so no Python or `jq` is needed.

## Windows user folder detection

The Windows user folder inside the Wine prefix (`drive_c/users/<name>`) can differ from your login name, so the script takes the first folder in name order, excluding `Public`, `Default User`, and `All Users`. If one prefix holds several Windows users, it can pick the wrong one.

The log tells you: a successful run leaves `attempt 1: synced local_version 1234 -> 1237`, while a run that looked in the wrong folder writes nothing and leaves only `attempt 1: launching STOVE.exe`, and the crash comes back. List the candidates with `ls "$WINEPREFIX/drive_c/users"`; the right one has `AppData/Local/STOVE/GameManifest` with `45_<digits>.json` files in it.

Do not edit the script to fix this — installs overwrite it. Put the path in `~/.config/stove-launcher/env`:

```sh
: "${STOVE_GM_CACHE_DIR:=/home/you/.wine-stove-staging/drive_c/users/you/AppData/Local/STOVE/GameManifest}"
```

It must point at the `GameManifest` folder itself. The leading `:` keeps the line a no-op and `:=` assigns only when the variable is not already set, which is what makes an exported shell value win over the config file.

## Environment differences

These notes come from one setup: a specific Wine build plus NVIDIA PRIME hybrid graphics. On a different machine, adjust things through the variables in [Settings](#settings) above rather than editing `stove-launcher.sh`, which installs overwrite.
