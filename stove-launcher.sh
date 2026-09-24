#!/bin/bash
# stove-launcher.sh — STOVE(로스트아크) 업데이트 확인 단계 크래시 우회 실행 스크립트.
#
# 하는 일: STOVE를 켜기 전에 로컬 매니페스트(GameManifest_45.upf)의 local_version을
# STOVE가 캐시해둔 최신 버전 번호로 맞춰 써서, 버전 비교 중 죽는 코드 경로를 건너뛴다.
# 실제 게임 파일 업데이트는 런처의 "게임실행" 버튼이 도는 무결성 검사가 처리한다.
#
# 이 파일은 설치 프로그램을 겸한다: 설치된 위치가 아닌 곳(다운로드 폴더 등)에서 실행하면
# 기존 STOVE 런처를 찾아 백업한 뒤 자기 자신을 그 자리에 복사하고 종료하고,
# 이미 설치된 위치에서 실행되면 바로 STOVE를 띄운다.
#
# 설정값 — 아래 값들은 ~/.config/stove-launcher/env 에 `: "${이름:=값}"` 형태로 적으면
# 바뀐다. 셸에서 직접 export한 값이 그 파일보다, 그 파일이 아래 기본값보다 우선한다.
#
#   WINEPREFIX           STOVE가 설치된 Wine prefix.      기본: ~/.wine-stove-staging
#   STOVE_WINE_DIR       쓸 Wine 빌드 디렉터리(bin/wine이 그 아래). 기본: PATH의 wine
#   STOVE_DIR            STOVE.exe가 있는 폴더.  기본: <prefix>/drive_c/ProgramData/Smilegate/STOVE
#   STOVE_GAME_MANIFEST  로컬 매니페스트 파일.
#                        기본: <prefix>/drive_c/ProgramData/Smilegate/Games/LOSTARK/
#                              combinedata_manifest/GameManifest_45.upf
#   STOVE_GM_CACHE_DIR   STOVE가 최신 버전 정보를 캐시하는 폴더.
#                        기본: <prefix>/drive_c/users/<사용자>/AppData/Local/STOVE/GameManifest
#   STOVE_NVIDIA_PRIME   NVIDIA PRIME 오프로드 사용(1/0). 기본: NVIDIA 있으면 1, 없으면 0
#   STOVE_LOG_FILE       로그 파일. 기본: ~/.local/state/stove-launcher/stove-autofix.log
#   STOVE_LAUNCHER_CONFIG  설정 파일 자체의 경로. 기본: ~/.config/stove-launcher/env
#
# 필요한 것: bash, wine. (python 등 추가 의존성 없음)

set -u

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
CONFIG_FILE="${STOVE_LAUNCHER_CONFIG:-$HOME/.config/stove-launcher/env}"

# 아이콘에서 실행되면 stdout/stderr가 안 보인다. 실패를 알릴 통로는 알림뿐이다.
notify() {
    local urgency="$1" title="$2" body="$3"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$urgency" "$title" "$body" 2>/dev/null
    elif command -v zenity >/dev/null 2>&1; then
        zenity --info --title="$title" --text="$body" >/dev/null 2>&1 &
    elif command -v kdialog >/dev/null 2>&1; then
        kdialog --title "$title" --passivepopup "$body" 10 >/dev/null 2>&1 &
    fi
    return 0
}

# 바탕화면 폴더명은 로케일마다 다르다(한국어는 ~/바탕화면).
desktop_dirs() {
    local d
    d="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
    if [ -n "$d" ] && [ "$d" != "$HOME" ] && [ "$d" != "$HOME/Desktop" ]; then
        echo "$d"
    fi
    echo "$HOME/Desktop"
}

collect_exec_paths() {
    local search_dirs=("$HOME/.local/share/applications")
    local d
    while IFS= read -r d; do
        search_dirs+=("$d")
    done < <(desktop_dirs)

    local files=()
    while IFS= read -r f; do
        files+=("$f")
    done < <(find "${search_dirs[@]}" -maxdepth 1 -iname '*stove*.desktop' 2>/dev/null | sort)

    local f exec_line exec_path seen=""
    for f in "${files[@]}"; do
        [ -f "$f" ] || continue
        # 윈도우에서 편집한 .desktop은 CRLF라 경로 끝에 \r이 붙는다.
        exec_line="$(grep -m1 '^Exec=' "$f" 2>/dev/null | sed 's/^Exec=//; s/\r$//')"
        [ -n "$exec_line" ] || continue
        case "$exec_line" in
            \"*) exec_path="${exec_line#\"}"; exec_path="${exec_path%%\"*}" ;;
            *) exec_path="${exec_line%% *}" ;;
        esac
        [ -n "$exec_path" ] || continue
        case "$seen" in
            *"|$exec_path|"*) continue ;;
        esac
        seen="$seen|$exec_path|"
        echo "$exec_path"
    done
}

# Wine이 만든 메뉴 항목은 applications 하위 폴더에 있어서 더 깊이 훑는다.
find_stove_icon() {
    local dirs=("$HOME/.local/share/applications") d f icon
    while IFS= read -r d; do
        dirs+=("$d")
    done < <(desktop_dirs)

    while IFS= read -r f; do
        icon="$(grep -m1 '^Icon=' "$f" 2>/dev/null | sed 's/^Icon=//; s/\r$//')"
        if [ -n "$icon" ]; then
            echo "$icon"
            return 0
        fi
    done < <(find "${dirs[@]}" -maxdepth 4 -iname '*stove*.desktop' 2>/dev/null | sort)
    return 1
}

# Exec가 /usr/bin/flatpak 이나 lutris 래퍼를 가리키는 경우가 있다. 그런 건 덮어쓰면 안 된다.
is_safe_target() {
    local p="$1"
    [ -f "$p" ] && [ -w "$p" ] || return 1
    case "$p" in "$HOME"/*) ;; *) return 1 ;; esac
    [ "$(head -c2 "$p" 2>/dev/null)" = "#!" ] || return 1
    return 0
}

EXEC_PATHS=()
while IFS= read -r p; do
    [ -n "$p" ] && EXEC_PATHS+=("$p")
done < <(collect_exec_paths)

# 아이콘 중 하나라도 이 파일을 가리키면 설치된 것이다. 첫 후보만 보면, 아이콘이 여러 개일 때
# 설치된 스크립트가 자기를 설치 대상으로 착각해 게임을 영영 안 띄운다.
IS_INSTALLED=0
# 패키지로 설치된 경우(/usr/bin 등)는 자기 복제를 하지 않고 바로 런처로 동작한다.
case "$SELF" in
    /usr/*|/opt/*) IS_INSTALLED=1 ;;
esac
for p in ${EXEC_PATHS+"${EXEC_PATHS[@]}"}; do
    if [ "$SELF" = "$(readlink -f "$p" 2>/dev/null)" ]; then
        IS_INSTALLED=1
        break
    fi
done

if [ "$IS_INSTALLED" = "0" ]; then
    # ── 설치 모드 ──
    INSTALL_PATH=""
    OTHER_TARGETS=()
    for p in ${EXEC_PATHS+"${EXEC_PATHS[@]}"}; do
        if [ -z "$INSTALL_PATH" ] && is_safe_target "$p"; then
            INSTALL_PATH="$p"
        else
            OTHER_TARGETS+=("$p")
        fi
    done

    FALLBACK=0
    if [ -z "$INSTALL_PATH" ]; then
        FALLBACK=1
        INSTALL_PATH="$HOME/.local/bin/stove-launcher.sh"
    fi

    if [ -f "$INSTALL_PATH" ] && cmp -s "$SELF" "$INSTALL_PATH"; then
        echo "이미 최신 버전이 설치돼 있습니다: $INSTALL_PATH"
        notify normal "STOVE 런처 수정" "이미 설치돼 있습니다. STOVE 아이콘을 누르면 됩니다."
        exit 0
    fi

    if ! mkdir -p "$(dirname "$INSTALL_PATH")"; then
        echo "설치 폴더를 만들 수 없습니다: $(dirname "$INSTALL_PATH")" >&2
        notify critical "STOVE 런처 설치 실패" "설치 폴더를 만들 수 없습니다."
        exit 1
    fi

    # 옛 스크립트에 하드코딩된 Wine 경로를 설정 파일로 옮긴다. 안 그러면 크래시가 안 나던
    # 그 빌드 대신 시스템 기본 wine으로 조용히 바뀐다.
    migrate_wine_settings() {
        local old="$1"
        [ -f "$CONFIG_FILE" ] && return 0
        local old_wine_dir old_prefix
        old_wine_dir="$(grep -oE '[^"[:space:]]+/bin/wineserver' "$old" 2>/dev/null | head -n1 | sed 's#/bin/wineserver$##')"
        old_prefix="$(grep -m1 -oE 'WINEPREFIX="[^"]+"|WINEPREFIX=[^"[:space:]]+' "$old" 2>/dev/null | sed 's/^WINEPREFIX=//;s/^"//;s/"$//')"

        # $WINE_DIR/bin/wineserver 처럼 변수를 거친 경로는 변수명이 그대로 뽑힌다.
        # 그걸 설정 파일에 쓰면 정의되지 않은 변수라 set -u에 걸려 죽는다.
        case "$old_wine_dir" in *'$'*|*'`'*) old_wine_dir="" ;; esac
        case "$old_prefix" in *'$'*|*'`'*) old_prefix="" ;; esac

        [ -z "$old_wine_dir" ] && [ -z "$old_prefix" ] && return 0

        mkdir -p "$(dirname "$CONFIG_FILE")" || return 0
        {
            [ -n "$old_wine_dir" ] && echo ": \"\${STOVE_WINE_DIR:=$old_wine_dir}\""
            [ -n "$old_prefix" ] && echo ": \"\${WINEPREFIX:=$old_prefix}\""
        } > "$CONFIG_FILE"
        local kept="${old_wine_dir:+STOVE_WINE_DIR=$old_wine_dir }${old_prefix:+WINEPREFIX=$old_prefix}"
        echo "기존 커스텀 Wine 설정을 $CONFIG_FILE 에 보존했습니다 ($kept)."
    }

    if [ -f "$INSTALL_PATH" ]; then
        backup="${INSTALL_PATH}.bak.$(date '+%Y%m%d%H%M%S')"
        if ! cp "$INSTALL_PATH" "$backup"; then
            echo "기존 파일 백업에 실패해서 설치를 중단합니다: $INSTALL_PATH" >&2
            notify critical "STOVE 런처 설치 실패" "기존 파일을 백업할 수 없어 중단했습니다."
            exit 1
        fi
        echo "기존 파일 백업: $backup"
        migrate_wine_settings "$backup"
    fi

    if ! cp "$SELF" "$INSTALL_PATH"; then
        echo "설치 실패: $INSTALL_PATH 에 쓸 수 없습니다." >&2
        notify critical "STOVE 런처 설치 실패" "$INSTALL_PATH 에 쓸 수 없습니다."
        exit 1
    fi
    chmod +x "$INSTALL_PATH" 2>/dev/null

    echo "설치 완료: $INSTALL_PATH"

    make_desktop_entry() {
        local file="$1" name="$2" icon
        icon="$(find_stove_icon || true)"
        mkdir -p "$(dirname "$file")"
        cat > "$file" <<EOF
[Desktop Entry]
Name=$name
Comment=STOVE 런처 (업데이트 크래시 우회 적용)
Exec=$INSTALL_PATH
Terminal=false
Type=Application
Categories=Game;
StartupWMClass=STOVE.exe
EOF
        [ -n "$icon" ] && printf 'Icon=%s\n' "$icon" >> "$file"
        chmod +x "$file" 2>/dev/null
        command -v update-desktop-database >/dev/null 2>&1 && \
            update-desktop-database "$(dirname "$file")" 2>/dev/null
        echo "아이콘을 만들었습니다: $file"
    }

    if [ "$FALLBACK" = "1" ] && [ "${#EXEC_PATHS[@]}" -eq 0 ]; then
        make_desktop_entry "$HOME/.local/share/applications/STOVE.desktop" "STOVE"
        notify normal "STOVE 런처 수정 설치 완료" "앱 목록에서 STOVE를 실행하세요."
    elif [ "$FALLBACK" = "1" ]; then
        # 기존 아이콘은 그대로 두고 새 아이콘을 만들어준다. 숨김 폴더의 .desktop을 직접
        # 고치라고 하면 대상 사용자는 해결하지 못한다.
        echo "주의: 기존 STOVE 아이콘이 교체할 수 없는 대상(${EXEC_PATHS[0]})을 실행합니다." >&2
        if command -v zenity >/dev/null 2>&1 && zenity --question --title="STOVE 런처 수정" \
            --text="기존 STOVE 아이콘은 다른 방식(Flatpak·Lutris 등)으로 실행되어 그대로 두었습니다.\n\n수정된 런처로 실행하는 새 아이콘을 만들까요?" 2>/dev/null; then
            make_desktop_entry "$HOME/.local/share/applications/STOVE-fixed.desktop" "STOVE (수정)"
            notify normal "STOVE 런처 수정 설치 완료" "앱 목록의 'STOVE (수정)' 아이콘으로 실행하세요."
        else
            echo "아이콘이 $INSTALL_PATH 를 실행하도록 직접 연결해야 합니다." >&2
            notify critical "STOVE 런처 수정 — 추가 설정 필요" \
                "기존 STOVE 아이콘이 $INSTALL_PATH 를 실행하도록 연결해주세요."
        fi
    else
        if [ "${#OTHER_TARGETS[@]}" -gt 0 ]; then
            echo "참고: 다른 STOVE 아이콘도 있습니다(${OTHER_TARGETS[*]}). 그 아이콘은 그대로입니다." >&2
        fi
        echo "이제부터는 STOVE 아이콘을 누르면 됩니다."
        notify normal "STOVE 런처 수정 설치 완료" "이제부터는 STOVE 아이콘을 누르면 됩니다."
    fi
    exit 0
fi

# 패키지로 설치된 경우 앱 목록 아이콘은 기본 이미지다. 이 컴퓨터에 STOVE 아이콘이
# 있으면 그걸 쓰도록 사용자 레벨 .desktop을 만들어 시스템 항목보다 우선시킨다.
# (STOVE 로고를 패키지에 넣어 배포하지 않기 위한 방법이다.)
adopt_local_icon() {
    local sys="/usr/share/applications/io.github._07lee.LostArkStoveLauncherFix.desktop"
    local user="$HOME/.local/share/applications/io.github._07lee.LostArkStoveLauncherFix.desktop"
    [ -f "$sys" ] || return 0
    [ -f "$user" ] && return 0

    local icon
    icon="$(find_stove_icon || true)"
    [ -n "$icon" ] || return 0
    case "$icon" in io.github._07lee.*) return 0 ;; esac

    mkdir -p "$(dirname "$user")" || return 0
    { grep -v '^Icon=' "$sys"; printf 'Icon=%s\n' "$icon"; } > "$user" || return 0
    chmod +x "$user" 2>/dev/null
    command -v update-desktop-database >/dev/null 2>&1 && \
        update-desktop-database "$(dirname "$user")" 2>/dev/null
    log "adopted local STOVE icon: $icon"
}
# ── 여기서부터는 STOVE를 띄우는 부분 ──
# 설정 파일의 각 줄이 ${VAR:=...} 형태라, 셸에서 export한 값이 그대로 이긴다.
# shellcheck disable=SC1090
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

LOG_FILE="${STOVE_LOG_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/stove-launcher/stove-autofix.log}"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
log() { echo "$(date '+%F %T') $*" >> "$LOG_FILE" 2>/dev/null; }

case "$SELF" in
    /usr/*|/opt/*) adopt_local_icon ;;
esac

WINEPREFIX="${WINEPREFIX:-$HOME/.wine-stove-staging}"

WINE_DIR="${STOVE_WINE_DIR:-}"
if [ -n "$WINE_DIR" ]; then
    export PATH="$WINE_DIR/bin:$PATH"
    WINE_BIN="$WINE_DIR/bin/wine"
    export WINESERVER="$WINE_DIR/bin/wineserver"
    export WINELOADER="$WINE_DIR/bin/wine"
else
    WINE_BIN="$(command -v wine)"
fi

export WINEPREFIX
export WINEDEBUG="${WINEDEBUG:--all}"
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"

# 로케일이 생성돼 있지 않은 배포판에서 강제하면 자식 프로세스마다 setlocale 경고가 난다.
if [ -z "${LC_ALL:-}" ] && locale -a 2>/dev/null | grep -qiE '^ko_KR\.(utf8|utf-8)$'; then
    export LC_ALL=ko_KR.UTF-8
    export LANG="${LANG:-ko_KR.UTF-8}"
fi

# NVIDIA가 없는 PC에서 이걸 켜면 libGLX_nvidia.so를 찾다 GL 초기화가 깨진다.
if [ -z "${STOVE_NVIDIA_PRIME:-}" ]; then
    if [ -d /proc/driver/nvidia ] || command -v nvidia-smi >/dev/null 2>&1; then
        STOVE_NVIDIA_PRIME=1
    else
        STOVE_NVIDIA_PRIME=0
    fi
fi
if [ "$STOVE_NVIDIA_PRIME" = "1" ]; then
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
fi

# prefix 기본값은 사람마다 다르다. 못 찾으면 찾아보고, 그래도 없으면 GUI로 묻고 저장한다.
# 터미널을 안 쓰는 사용자는 설정 파일을 직접 만들 수 없다.
persist_setting() {
    local name="$1" value="$2"
    mkdir -p "$(dirname "$CONFIG_FILE")" 2>/dev/null || return 1
    grep -q "{$name:=" "$CONFIG_FILE" 2>/dev/null && return 0
    printf ': "${%s:=%s}"\n' "$name" "$value" >> "$CONFIG_FILE" 2>/dev/null
}

find_stove_prefixes() {
    local d
    for d in "$HOME"/.wine* "$HOME"/Games/* "$HOME"/.local/share/wineprefixes/* \
             "$HOME"/.local/share/lutris/prefixes/* "$HOME"/.local/share/bottles/bottles/* \
             "$HOME"/.var/app/com.usebottles.bottles/data/bottles/bottles/* \
             "$HOME"/.var/app/org.winehq.Wine/data/wine; do
        [ -f "$d/drive_c/ProgramData/Smilegate/STOVE/STOVE.exe" ] && echo "$d"
    done 2>/dev/null | sort -u
}

# 후보가 여럿이면 버전 캐시가 쌓인 쪽이 실제로 쓰는 prefix다.
prefix_has_cache() {
    local p="$1" u
    for u in "$p"/drive_c/users/*/AppData/Local/STOVE/GameManifest; do
        compgen -G "$u/45_*.json" >/dev/null 2>&1 && return 0
    done
    return 1
}

if [ -z "${STOVE_DIR:-}" ] && [ ! -d "$WINEPREFIX/drive_c/ProgramData/Smilegate/STOVE" ]; then
    log "STOVE not found in $WINEPREFIX, searching"
    FOUND=()
    while IFS= read -r p; do
        [ -n "$p" ] && FOUND+=("$p")
    done < <(find_stove_prefixes)

    PICKED=""
    if [ "${#FOUND[@]}" -eq 1 ]; then
        PICKED="${FOUND[0]}"
    elif [ "${#FOUND[@]}" -gt 1 ]; then
        for p in "${FOUND[@]}"; do
            if prefix_has_cache "$p"; then PICKED="$p"; break; fi
        done
        if [ -z "$PICKED" ] && command -v zenity >/dev/null 2>&1; then
            PICKED="$(zenity --list --title="STOVE 위치 선택" \
                --text="STOVE가 설치된 곳을 골라주세요." \
                --column="경로" "${FOUND[@]}" 2>/dev/null)"
        fi
        [ -z "$PICKED" ] && PICKED="${FOUND[0]}"
    elif command -v zenity >/dev/null 2>&1; then
        zenity --info --title="STOVE 런처" \
            --text="STOVE 설치 위치를 찾지 못했습니다.\n다음 창에서 STOVE를 설치한 Wine 폴더(drive_c가 들어 있는 폴더)를 골라주세요." 2>/dev/null
        PICKED="$(zenity --file-selection --directory --title="STOVE를 설치한 Wine 폴더 선택" 2>/dev/null)"
        if [ -n "$PICKED" ] && [ ! -f "$PICKED/drive_c/ProgramData/Smilegate/STOVE/STOVE.exe" ]; then
            notify critical "STOVE 런처 오류" "고른 폴더에서 STOVE.exe를 찾지 못했습니다: $PICKED"
            log "user picked $PICKED but STOVE.exe is not there"
            exit 1
        fi
    fi

    if [ -n "$PICKED" ]; then
        WINEPREFIX="$PICKED"
        export WINEPREFIX
        persist_setting WINEPREFIX "$PICKED"
        log "using detected prefix $PICKED"
    fi
fi

STOVE_DIR="${STOVE_DIR:-$WINEPREFIX/drive_c/ProgramData/Smilegate/STOVE}"
GAME_MANIFEST="${STOVE_GAME_MANIFEST:-$WINEPREFIX/drive_c/ProgramData/Smilegate/Games/LOSTARK/combinedata_manifest/GameManifest_45.upf}"

if [ -z "${STOVE_GM_CACHE_DIR:-}" ]; then
    WIN_USER_DIR="$(find "$WINEPREFIX/drive_c/users" -mindepth 1 -maxdepth 1 -type d \
        ! -name Public ! -name "Default User" ! -name "All Users" 2>/dev/null | sort | head -n1)"
    GM_CACHE_DIR="${WIN_USER_DIR:-$WINEPREFIX/drive_c/users/${USER:-$(id -un)}}/AppData/Local/STOVE/GameManifest"
else
    GM_CACHE_DIR="$STOVE_GM_CACHE_DIR"
fi

LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/stove-launcher-${USER:-$(id -u)}.lock"

if [ -z "$WINE_BIN" ] || [ ! -x "$WINE_BIN" ]; then
    echo "wine 실행 파일을 찾을 수 없습니다. STOVE_WINE_DIR을 설정하거나 PATH를 확인하세요." >&2
    log "wine not found (STOVE_WINE_DIR=${STOVE_WINE_DIR:-unset})"
    notify critical "STOVE 런처 오류" "wine 실행 파일을 찾을 수 없습니다."
    exit 1
fi

# 락 파일을 못 여는 경우 "이미 실행 중"으로 오판하지 않고 락 없이 진행한다.
# exec에 2>/dev/null을 붙이면 스크립트 전체의 stderr가 사라지므로 먼저 확인한다.
if : >>"$LOCK_FILE" 2>/dev/null; then
    exec 9>>"$LOCK_FILE"
    if ! flock -n 9; then
        log "another instance is already running, exiting"
        notify normal "STOVE" "이미 실행 중입니다 — 잠시만 기다려주세요"
        exit 0
    fi
else
    log "cannot open lock file ($LOCK_FILE), continuing without lock"
fi

# JSON을 파싱해 다시 쓰지 않고 두 값만 치환한다. 나머지는 바이트 그대로 남고,
# python 같은 추가 의존성도 필요 없다.
sync_local_version() {
    [ -f "$GAME_MANIFEST" ] || return 0

    local current best
    current="$(sed -n 's/.*"local_version"[[:space:]]*:[[:space:]]*\([0-9]\{1,\}\).*/\1/p' "$GAME_MANIFEST" 2>>"$LOG_FILE" | head -n1)"
    [ -n "$current" ] || { log "manifest has no numeric local_version, skipping"; return 0; }

    best="$current"
    if [ -d "$GM_CACHE_DIR" ]; then
        local f v
        for f in "$GM_CACHE_DIR"/45_*.json; do
            [ -e "$f" ] || continue
            v="${f##*/45_}"; v="${v%.json}"
            case "$v" in ''|*[!0-9]*) continue ;; esac
            v=$((10#$v))
            [ "$v" -gt "$best" ] && best="$v"
        done
    fi

    [ "$best" = "$current" ] && return 0

    local orig="${GAME_MANIFEST}.orig" tmp="${GAME_MANIFEST}.tmp"
    [ -f "$orig" ] || cp -p "$GAME_MANIFEST" "$orig" 2>>"$LOG_FILE"

    # 바로 덮어쓰면 도중에 죽었을 때 매니페스트가 깨진 채로 남는다.
    if ! cp -p "$GAME_MANIFEST" "$tmp" 2>>"$LOG_FILE"; then
        log "cannot create temp manifest ($tmp)"
        return 1
    fi
    if sed -e "s/\(\"local_version\"[[:space:]]*:[[:space:]]*\)[0-9]\{1,\}/\1$best/" \
           -e "s/45_[0-9]\{1,\}\.json/45_$best.json/g" \
           "$GAME_MANIFEST" > "$tmp" 2>>"$LOG_FILE" && [ -s "$tmp" ]; then
        mv -f "$tmp" "$GAME_MANIFEST"
        echo "synced local_version $current -> $best"
    else
        rm -f "$tmp"
        log "manifest rewrite failed, left untouched"
        return 1
    fi
}

if [ ! -d "$STOVE_DIR" ]; then
    echo "STOVE_DIR($STOVE_DIR)을 찾을 수 없습니다. WINEPREFIX 설정을 확인하세요." >&2
    log "STOVE_DIR not found: $STOVE_DIR"
    notify critical "STOVE 런처 오류" "STOVE 설치 경로($STOVE_DIR)를 찾을 수 없습니다."
    exit 1
fi
if [ ! -f "$STOVE_DIR/STOVE.exe" ]; then
    echo "STOVE.exe를 찾을 수 없습니다: $STOVE_DIR/STOVE.exe" >&2
    log "STOVE.exe not found in $STOVE_DIR"
    notify critical "STOVE 런처 오류" "STOVE.exe를 찾을 수 없습니다 ($STOVE_DIR)."
    exit 1
fi
cd "$STOVE_DIR"

# 이미 떠 있으면 두 번째 실행은 기존 창에 넘기고 몇 초 만에 끝난다. 크래시가 아니다.
already_running=0
pgrep -f 'STOVE\.exe' >/dev/null 2>&1 && already_running=1

max_attempts=2
shortest_run=99999
for attempt in $(seq 1 "$max_attempts"); do
    sync_result="$(sync_local_version)"
    [ -n "$sync_result" ] && log "attempt $attempt: $sync_result"

    log "attempt $attempt: launching STOVE.exe"
    run_start=$SECONDS
    # 락 fd(9)를 넘기지 않는다. wineserver 같은 백그라운드 프로세스가 물고 있으면 STOVE가
    # 죽어도 락이 안 풀려서 다음 실행이 전부 "이미 실행 중"으로 막힌다.
    "$WINE_BIN" "$STOVE_DIR/STOVE.exe" >/dev/null 2>&1 9>&-
    run_time=$(( SECONDS - run_start ))
    [ "$run_time" -lt "$shortest_run" ] && shortest_run=$run_time
    log "attempt $attempt: STOVE.exe exited after ${run_time}s"

    post_sync="$(sync_local_version)"
    if [ -z "$post_sync" ]; then
        break
    fi
    log "attempt $attempt: new target version detected after run ($post_sync), retrying"
done

# 정상이면 사용자가 닫을 때까지 살아 있다. 몇 초 만에 끝났으면 크래시고, 원인은 대개 Wine 빌드다.
if [ "$shortest_run" -lt 8 ] && [ "$already_running" = "0" ] \
   && [ -z "${STOVE_WINE_DIR:-}" ] && command -v zenity >/dev/null 2>&1; then
    log "STOVE.exe exited after ${shortest_run}s, offering wine build picker"
    if zenity --question --title="STOVE 런처" \
        --text="STOVE가 곧바로 종료됐습니다. 지금 쓰는 Wine 빌드에서 나는 문제일 수 있습니다.\n\n다른 Wine 빌드를 지정하시겠습니까?\n(bin/wine 이 들어 있는 폴더를 고릅니다)" 2>/dev/null; then
        picked_wine="$(zenity --file-selection --directory --title="Wine 빌드 폴더 선택" 2>/dev/null)"
        if [ -n "$picked_wine" ] && [ -x "$picked_wine/bin/wine" ]; then
            persist_setting STOVE_WINE_DIR "$picked_wine"
            log "user picked wine build $picked_wine"
            notify normal "STOVE 런처" "Wine 빌드를 저장했습니다. STOVE 아이콘을 다시 눌러주세요."
        elif [ -n "$picked_wine" ]; then
            notify critical "STOVE 런처" "고른 폴더에 bin/wine 이 없습니다: $picked_wine"
        fi
    fi
fi
