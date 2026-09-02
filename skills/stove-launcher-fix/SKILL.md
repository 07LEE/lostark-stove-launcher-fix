---
name: stove-launcher-fix
description: Diagnose and install the workaround for the STOVE launcher (Korean Lost Ark client) crashing at its update check under Wine on Linux. Use when STOVE or Lost Ark KR exits with no message at the update-check step, keeps crashing on relaunch, or when the project's own installer does not fit because the game lives in an unusual place (Lutris, Bottles, Flatpak Wine, a custom Wine prefix).
---

This skill installs an existing, tested workaround on the user's machine. It does not invent a new one.

**Find the repository root first.** This skill may have been installed on its own, away from the repository. Locate the `lostark-stove-launcher-fix` repository root — the directory holding `stove-launcher.sh` and `README.md` — and work from that absolute path. If it is not present, ask the user before cloning:

```
git clone https://github.com/07LEE/lostark-stove-launcher-fix.git
```

**Do not reimplement the workaround.** `stove-launcher.sh` already handles it: it reads the newest version number STOVE cached, writes it into the local manifest so the crashing comparison never runs, and launches the game. It also installs itself, detects the Wine prefix, and asks the user through `zenity` dialogs when it cannot. Your job is only to handle what that script cannot work out on its own, and then let it run. Never edit `GameManifest_45.upf` by hand and never write a replacement sync routine.

## 1. Diagnose (read only — change nothing yet)

1. Desktop environment: `echo $XDG_CURRENT_DESKTOP`, `echo $DISPLAY $WAYLAND_DISPLAY`.
2. Find every STOVE shortcut — do not assume there is one:
   ```
   find "$HOME/.local/share/applications" "$HOME/Desktop" -maxdepth 1 -iname '*stove*.desktop' 2>/dev/null
   ```
   Wine's own installers also write entries under `~/.local/share/applications/wine/Programs/`, which that search does not reach. Look there too, and consider Lutris (`~/.local/share/lutris/`), Bottles (`~/.local/share/bottles/`, `~/.var/app/com.usebottles.bottles/`), Flatpak Wine (`~/.var/app/org.winehq.Wine/`) and Steam (`~/.local/share/Steam/steamapps/compatdata/`). Asking the user how they installed STOVE is usually faster than guessing — ask early.
3. Read the `Exec=` target of each shortcut and work out the Wine prefix, the Wine build in use, and the STOVE folder (normally `<prefix>/drive_c/ProgramData/Smilegate/STOVE`).
4. Confirm the manifest at `<prefix>/drive_c/ProgramData/Smilegate/Games/LOSTARK/combinedata_manifest/GameManifest_45.upf` and the version cache under the Windows user folder (`AppData/Local/STOVE/GameManifest`, holding `45_<digits>.json` files). Record where they actually are if they differ.
5. If the user already has a launcher script working around this, read it and note how it differs from `stove-launcher.sh`.

Summarise what you found and confirm it with the user before changing anything — especially if the prefix or STOVE folder was a guess.

## 2. Install

Run the repository's `stove-launcher.sh`. Do not write a new script.

- The script installs itself over the launcher script an existing STOVE shortcut points at, after backing it up. It only replaces a writable shell script under the user's home; anything else (a Flatpak or Lutris wrapper) is left alone and it offers to create a separate shortcut instead.
- Values it cannot detect go in `~/.config/stove-launcher/env`, which it reads on every run:
  ```
  : "${WINEPREFIX:=/actual/prefix}"
  : "${STOVE_WINE_DIR:=/wine/build/where/it/does/not/crash}"
  : "${STOVE_GM_CACHE_DIR:=/actual/GameManifest/folder}"
  ```
  The full list of settings is in the comment block at the top of `stove-launcher.sh`.
- **If the game is launched through a tool's own configuration rather than a `.desktop` file** — a Lutris pre-launch script, a Bottles entry — explain how to hook `stove-launcher.sh` in and let the user decide. Do not edit that tool's configuration without asking.
- If the manifest layout itself differs from what the script assumes (no `45_`-prefixed cache files, a different folder structure), stop and explain the situation instead of forcing a fit.

## 3. Verify

- Check the log (`~/.local/state/stove-launcher/stove-autofix.log`) for a line like `synced local_version 1234 -> 1237`, which shows the workaround ran.
- With the user's agreement, launch STOVE once and watch it come up. Tell them to press **게임실행** (the Start Game button) — that is what downloads the actual patch.
- Report what changed, including where the backup went.

## Cautions

- You are modifying files on someone's machine. Back up anything you overwrite and ask when you are unsure. Never touch the game files inside the Wine prefix — only the launcher script and shortcuts.
- The repository is the source of truth for the workaround. If it looks wrong, say so rather than quietly writing your own version.
