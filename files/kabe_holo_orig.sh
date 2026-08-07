#!/system/bin/sh
# ═══════════════════════════════════════════════════════
#   © KURAMA MODS — PREMIUM EDITION — ALL RIGHTS RESERVED
#   Unauthorized redistribution will be prosecuted.
#   Contact: @KuramaModz
# ═══════════════════════════════════════════════════════

# ── Colors ─────────────────────────────────────────────
_0='\033[0m'
_R='\033[38;5;196m'       # Bright red
_G='\033[38;5;46m'        # Neon green
_C='\033[38;5;51m'        # Cyan
_P='\033[38;5;135m'       # Purple
_Y='\033[38;5;220m'       # Gold
_W='\033[38;5;255m'       # White
_D='\033[38;5;240m'       # Dark grey
_S='\033[38;5;208m'       # Orange
_T='\033[38;5;87m'        # Teal
BLD='\033[1m'
DIM='\033[2m'
ITL='\033[3m'

# ── Obfuscated config ──────────────────────────────────
_x(){ echo "$1"|base64 -d 2>/dev/null; }
_FB=$(_x "aHR0cHM6Ly9rdXJhbWEtMWIyMjQtZGVmYXVsdC1ydGRiLmZpcmViYXNlaW8uY29t")
_KS=$(_x "L2RhdGEvbG9jYWwvdG1wLy5rbV9rZXk=")
_BD=$(_x "L2RhdGEvbG9jYWwvdG1wLy5rdXJhbWFfbW9kc19jb3Jl")
_TG=$(_x "QEt1cmFtYU1vZHo=")
_VR=$(_x "djEuMA==")

# ── Root check ─────────────────────────────────────────
[ "$(id -u)" -ne 0 ] && {
    clear
    printf "\n  ${_R}${BLD}  ACCESS DENIED  ${_0}\n"
    printf "  ${_D}  Root privileges required.${_0}\n\n"
    exit 1
}

# ── Expire check ───────────────────────────────────────
_EXP=1830297600
_NOW=$(date +%s 2>/dev/null)
{ [ -z "$_NOW" ] || [ "$_NOW" -lt 1700000000 ]; } && {
    printf "\n  ${_R}  No internet connection.${_0}\n\n"; exit 1; }
[ "$_NOW" -gt "$_EXP" ] && {
    printf "\n  ${_R}  License expired.${_0}\n\n"; exit 1; }

# ── UI Components ───────────────────────────────────────

# Полная ширина линия
_line() {
    printf "${_D}  ──────────────────────────────────────────────────${_0}\n"
}
_line2() {
    printf "${_P}  ══════════════════════════════════════════════════${_0}\n"
}

# Пустая строка
_br() { printf "\n"; }

# Лейбл-значение строка
_row() {
    printf "  ${_D}%-18s${_0}${_W}%s${_0}\n" "$1" "$2"
}

# Статус строка
_tag() {
    case "$1" in
        ok)      printf "${_G}  ✔  ${_0}${_W}$2${_0}\n" ;;
        err)     printf "${_R}  ✘  ${_0}${_W}$2${_0}\n" ;;
        info)    printf "${_T}  ◆  ${_0}${_D}$2${_0}\n" ;;
        warn)    printf "${_Y}  ▲  ${_0}${_W}$2${_0}\n" ;;
        load)    printf "${_P}  ◈  ${_0}${_W}$2${_0}\n" ;;
    esac
}

# Прогресс бар
_bar() {
    _MSG="$1"
    printf "\n  ${_D}  DEPLOYING  [${_0}"
    for _I in $(seq 1 40); do
        printf "${_P}▰${_0}"
        sleep 0.04
    done
    printf "${_D}]${_0}  ${_G}DONE${_0}\n"
    printf "  ${_G}  ✔  ${_W}$_MSG${_0}\n\n"
}

# Спиннер
_spin() {
    _MSG="$1"; _S2="$2"
    _FR="▹▸▹▸▹"
    _END=$(( $(date +%s) + _S2 ))
    while [ $(date +%s) -lt $_END ]; do
        for _F in $(echo "$_FR" | fold -w1); do
            printf "\r  ${_P}${_F}${_0}  ${_D}$_MSG${_0}   "
            sleep 0.12
        done
    done
    printf "\r  ${_G}✔${_0}  ${_W}$_MSG${_0}\n"
}

# ── BANNER ─────────────────────────────────────────────
_banner() {
    clear
    _br
    printf "${_P}${BLD}"
    printf "  ██╗  ██╗██╗   ██╗██████╗  █████╗ ███╗   ███╗ █████╗ \n"
    printf "  ██║ ██╔╝██║   ██║██╔══██╗██╔══██╗████╗ ████║██╔══██╗\n"
    printf "${_R}"
    printf "  █████╔╝ ██║   ██║██████╔╝███████║██╔████╔██║███████║\n"
    printf "  ██╔═██╗ ██║   ██║██╔══██╗██╔══██║██║╚██╔╝██║██╔══██║\n"
    printf "${_P}"
    printf "  ██║  ██╗╚██████╔╝██║  ██║██║  ██║██║ ╚═╝ ██║██║  ██║\n"
    printf "  ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝\n"
    printf "${_0}"
    _br
    printf "  ${_D}                  MODS  ·  HOLO  ·  ${_VR}${_0}\n"
    printf "  ${_D}                  ${_TG}${_0}\n"
    _br
    _line2
    _br
}

# ── HTTP ───────────────────────────────────────────────
_http() {
    _U="$1"
    command -v curl >/dev/null 2>&1 && {
        _Z=$(curl -s --max-time 15 "$_U" 2>/dev/null)
        [ -n "$_Z" ] && echo "$_Z" && return 0; }
    for _P2 in \
        /data/data/com.termux/files/usr/bin/curl \
        /data/user/0/com.termux/files/usr/bin/curl \
        /sdcard/curl; do
        [ -f "$_P2" ] && {
            _Z=$("$_P2" -s --max-time 15 "$_U" 2>/dev/null)
            [ -n "$_Z" ] && echo "$_Z" && return 0; }
    done
    command -v wget >/dev/null 2>&1 && {
        _Z=$(wget -q -O - --timeout=15 "$_U" 2>/dev/null)
        [ -n "$_Z" ] && echo "$_Z" && return 0; }
    for _P2 in \
        /data/data/com.termux/files/usr/bin/wget \
        /system/xbin/wget /sbin/wget; do
        [ -f "$_P2" ] && {
            _Z=$("$_P2" -q -O - --timeout=15 "$_U" 2>/dev/null)
            [ -n "$_Z" ] && echo "$_Z" && return 0; }
    done
    command -v toybox >/dev/null 2>&1 && {
        _Z=$(toybox wget -O - "$_U" 2>/dev/null)
        [ -n "$_Z" ] && echo "$_Z" && return 0; }
    return 1
}

# ── JSON ───────────────────────────────────────────────
_json() {
    _F="$1"; _D2="$2"
    _C2=$(echo "$_D2" | tr -d '\n\r' | sed 's/[[:space:]]*:[[:space:]]*/:/g')
    _V=$(echo "$_C2" | sed "s/.*\"${_F}\":\"\([^\"]*\)\".*/\1/")
    [ "$_V" = "$_C2" ] && _V=$(echo "$_C2" | sed "s/.*\"${_F}\":\([^,}]*\).*/\1/" | tr -d ' ')
    [ "$_V" = "$_C2" ] && _V=""
    echo "$_V"
}

# ── Firebase verify ────────────────────────────────────
_verify() {
    _KEY="$1"
    _br
    _spin "Connecting to server..." 1
    _spin "Verifying license key..." 1
    _br

    _RESP=$(_http "${_FB}/keys/${_KEY}.json")
    if [ $? -ne 0 ] || [ -z "$_RESP" ]; then
        _tag err "No HTTP client found on device."
        _br
        _tag info "Solution 1 — Install Termux → run: pkg install curl"
        _tag info "Solution 2 — Copy curl binary to /sdcard/curl"
        return 1
    fi

    [ "$_RESP" = "null" ] && {
        _tag err "License key not found."
        _tag info "Purchase a key at $_TG"
        return 1; }

    _ST=$(_json "status" "$_RESP")
    _ST=$(echo "$_ST" | tr 'A-Z' 'a-z' | tr -d ' ')

    case "$_ST" in
        active)
            _VAL=$(_json "validity" "$_RESP")
            _br
            printf "  ${_G}"
            printf "  ┌───────────────────────────────────────────┐\n"
            printf "  │                                           │\n"
            printf "  │   ✔   ACCESS GRANTED                     │\n"
            printf "  │       Welcome to Kurama Mods              │\n"
            if [ -n "$_VAL" ]; then
            printf "  │       Valid until  :  %-20s│\n" "$_VAL"
            else
            printf "  │       License Type :  LIFETIME            │\n"
            fi
            printf "  │                                           │\n"
            printf "  └───────────────────────────────────────────┘\n"
            printf "  ${_0}"
            echo "$_KEY" > "$_KS"
            return 0 ;;
        blocked)
            _tag err "Key is BLOCKED."
            _tag info "Contact $_TG for support."
            return 1 ;;
        expired)
            _tag err "Key has EXPIRED."
            _tag info "Renew your license at $_TG"
            return 1 ;;
        *)
            _tag err "Unknown status: '$_ST'"
            return 1 ;;
    esac
}

# ── Login screen ───────────────────────────────────────
_login_screen() {
    _banner
    printf "  ${_D}  AUTHENTICATION REQUIRED${_0}\n"
    _br
    _line
    _br

    _SAVED=""
    [ -f "$_KS" ] && _SAVED=$(cat "$_KS" 2>/dev/null | tr -d '\n\r')

    if [ -n "$_SAVED" ]; then
        _row "Saved key" "$_SAVED"
        _br
        printf "  ${_D}  Use saved key? [Enter = yes  /  n = no] :${_0}  "
        read _USE
        if [ "$_USE" != "n" ] && [ "$_USE" != "N" ]; then
            _verify "$_SAVED"; return $?
        fi
        _br
    fi

    printf "  ${_Y}  LICENSE KEY${_0}  ${_D}→${_0}  "
    read _K
    _K=$(echo "$_K" | tr -d ' \t\n\r')
    [ -z "$_K" ] && { _tag err "Empty key."; exit 1; }
    _verify "$_K"
    return $?
}

# ── Auth retry ─────────────────────────────────────────
_OK=0
for _AT in 1 2 3; do
    _login_screen
    [ $? -eq 0 ] && { _OK=1; break; }
    if [ "$_AT" -lt 3 ]; then
        _br
        _tag warn "Attempt $_AT / 3 — Press Enter to retry..."
        read _
    fi
done

[ "$_OK" -ne 1 ] && {
    _br
    _tag err "ACCESS DENIED  —  3 failed attempts."
    _br
    exit 1
}

sleep 1

# ── Obfuscated patch strings ───────────────────────────
_O1=$(_x "ZjAwY2VmMGYwYjFiYTI2NDdiZTZmMmU1MjE3NjhhNzI=")
_N1=$(_x "MjE2YTcxMTNiN2YxYmM3NGViMjI4OWQ0N2YyYTQwNmQ=")
_OG=$(_x "ZmIxNDlkMGRiODYzMDU2NDZiMTg3ZGJlNDI5ZDhjMjM=")
_NG=$(_x "ODNkY2JlYWM2MmM3Y2U1NDM4MTFiOTQ3ZjZmYzEyZTU=")
_PM=$(_x "L2RhdGEvdXNlci8wL2NvbS5kdHMuZnJlZWZpcmVtYXgvZmlsZXMvc3BsaXRfYXNzZXRfcGFja19pbnN0YWxsX3RpbWUuYXBrLnBkY2FjaGU=")
_PR=$(_x "L2RhdGEvdXNlci8wL2NvbS5kdHMuZnJlZWZpcmV0aC9maWxlcy9zcGxpdF9hc3NldF9wYWNrX2luc3RhbGxfdGltZS5hcGsucGRjYWNoZQ==")

# ── Patch ──────────────────────────────────────────────
_patch() {
    _PTH="$1"; _GM="$2"; _MD="$3"
    _FN=$(basename "$_PTH")
    [ "$_GM" = "MAX" ] \
        && _BAK="${_BD}/${_FN}_max.bak" \
        || _BAK="${_BD}/${_FN}_reg.bak"

    _br
    if [ ! -f "$_PTH" ]; then
        _tag err "Game file not found."
        printf "  ${_D}  Expected: $_PTH${_0}\n"
        return 1
    fi

    _tag ok "Game file located."
    [ ! -d "$_BD" ] && mkdir -p "$_BD" && chmod 700 "$_BD"
    if [ ! -f "$_BAK" ]; then
        cp "$_PTH" "$_BAK"
        _tag info "Backup saved."
    fi

    if [ "$_MD" -eq 1 ]; then
        sed -i "s/$_O1/$_N1/g" "$_PTH" && _bar "HOLOGRAM INJECTED" \
            || { _tag err "Patch failed."; return 1; }
    else
        sed -i "s/$_OG/$_NG/g" "$_PTH" && _bar "GLOO WALL INVISIBLE INJECTED" \
            || { _tag err "Patch failed."; return 1; }
    fi

    chmod 660 "$_PTH"
    chown vold:everybody "$_PTH" 2>/dev/null || chmod 777 "$_PTH"
}

# ── Restore ────────────────────────────────────────────
_restore() {
    _PTH="$1"; _GM="$2"
    _FN=$(basename "$_PTH")
    [ "$_GM" = "MAX" ] \
        && _BAK="${_BD}/${_FN}_max.bak" \
        || _BAK="${_BD}/${_FN}_reg.bak"
    _br
    _tag load "Restoring $_GM..."
    if [ -f "$_BAK" ]; then
        cp "$_BAK" "$_PTH" && _bar "ORIGINAL DATA RESTORED"
    elif [ -f "$_PTH" ]; then
        sed -i "s/$_N1/$_O1/g" "$_PTH"
        sed -i "s/$_NG/$_OG/g" "$_PTH"
        _bar "MANUAL REVERT COMPLETE"
    else
        _tag err "Game file not found."
        return 1
    fi
    chmod 660 "$_PTH"
    chown vold:everybody "$_PTH" 2>/dev/null || chmod 777 "$_PTH"
}

# ── Main menu ──────────────────────────────────────────
while true; do
    _banner

    # Status bar
    printf "  ${_G}  ● AUTHENTICATED${_0}   ${_D}|${_0}   ${_T}  ◆ ONLINE${_0}   ${_D}|${_0}   ${_D}Firebase${_0}\n"
    _br
    _line
    _br

    # FREE FIRE MAX section
    printf "  ${_P}${BLD}  FREE FIRE MAX${_0}\n"
    _br
    printf "  ${_D}  [${_0}${_W}1${_0}${_D}]${_0}   ${_G}✦${_0}  Activate  ${_W}HOLOGRAM${_0}\n"
    printf "  ${_D}  [${_0}${_W}2${_0}${_D}]${_0}   ${_G}◈${_0}  Activate  ${_W}GLOO INVISIBLE${_0}\n"
    printf "  ${_D}  [${_0}${_W}3${_0}${_D}]${_0}   ${_Y}⟲${_0}  Restore   ${_D}Original Data${_0}\n"
    _br
    _line
    _br

    # FREE FIRE STANDARD section
    printf "  ${_C}${BLD}  FREE FIRE NORMAL${_0}\n"
    _br
    printf "  ${_D}  [${_0}${_W}4${_0}${_D}]${_0}   ${_G}✦${_0}  Activate  ${_W}HOLOGRAM${_0}\n"
    printf "  ${_D}  [${_0}${_W}5${_0}${_D}]${_0}   ${_G}◈${_0}  Activate  ${_W}GLOO INVISIBLE${_0}\n"
    printf "  ${_D}  [${_0}${_W}6${_0}${_D}]${_0}   ${_Y}⟲${_0}  Restore   ${_D}Original Data${_0}\n"
    _br
    _line
    _br

    # Exit
    printf "  ${_D}  [${_0}${_W}7${_0}${_D}]${_0}   ${_R}✕${_0}  Disconnect and Exit\n"
    _br
    _line2
    _br

    printf "  ${_Y}  SELECT${_0}  ${_D}→${_0}  "
    read _CH
    _br

    case $_CH in
        1) _patch "$_PM" "MAX" 1 ;;
        2) _patch "$_PM" "MAX" 2 ;;
        3) _restore "$_PM" "MAX" ;;
        4) _patch "$_PR" "STD" 1 ;;
        5) _patch "$_PR" "STD" 2 ;;
        6) _restore "$_PR" "STD" ;;
        7) _tag info "Session closed.  $_TG"
           _br; sleep 1; exit 0 ;;
        *) _tag err "Invalid command."; sleep 1; continue ;;
    esac

    _br
    printf "  ${_D}  Press [Enter] to continue...${_0}"
    read _
done
