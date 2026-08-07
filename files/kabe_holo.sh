#!/system/bin/sh
# ═══════════════════════════════════════════════════════
#   KABE PRIVATE — PREMIUM EDITION — NO KEY VERSION
# ═══════════════════════════════════════════════════════

# ── Colors ─────────────────────────────────────────────
_0='\033[0m'
_R='\033[38;5;196m'
_G='\033[38;5;46m'
_C='\033[38;5;51m'
_P='\033[38;5;135m'
_Y='\033[38;5;220m'
_W='\033[38;5;255m'
_D='\033[38;5;240m'
_S='\033[38;5;208m'
_T='\033[38;5;87m'
BLD='\033[1m'
DIM='\033[2m'
ITL='\033[3m'

# ── Obfuscated config ──────────────────────────────────
_x(){ echo "$1"|base64 -d 2>/dev/null; }
_BD=$(_x "L2RhdGEvbG9jYWwvdG1wLy5rYWJlX3ByaXZhdGVfY29yZQ==")
_VR=$(_x "djEuMA==")

# ── Root check ─────────────────────────────────────────
[ "$(id -u)" -ne 0 ] && {
    clear
    printf "\n  ${_R}${BLD}  ACCESS DENIED  ${_0}\n"
    printf "  ${_D}  Root privileges required.${_0}\n\n"
    exit 1
}

# ── UI Components ───────────────────────────────────────
_line() {
    printf "${_D}  ──────────────────────────────────────────────────${_0}\n"
}
_line2() {
    printf "${_P}  ══════════════════════════════════════════════════${_0}\n"
}
_br() { printf "\n"; }
_row() {
    printf "  ${_D}%-18s${_0}${_W}%s${_0}\n" "$1" "$2"
}
_tag() {
    case "$1" in
        ok)      printf "${_G}  ✔  ${_0}${_W}$2${_0}\n" ;;
        err)     printf "${_R}  ✘  ${_0}${_W}$2${_0}\n" ;;
        info)    printf "${_T}  ◆  ${_0}${_D}$2${_0}\n" ;;
        warn)    printf "${_Y}  ▲  ${_0}${_W}$2${_0}\n" ;;
        load)    printf "${_P}  ◈  ${_0}${_W}$2${_0}\n" ;;
    esac
}
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

# ── BANNER ─────────────────────────────────────────────
_banner() {
    clear
    _br
    printf "${_P}${BLD}"
    printf "  ██╗  ██╗██╗   ██╗██████╗ ███████╗██████╗  ██████╗██╗  ██╗███████╗██████╗ \n"
    printf "  ██║ ██╔╝██║   ██║██╔══██╗██╔════╝██╔══██╗██╔════╝██║  ██║██╔════╝██╔══██╗\n"
    printf "${_R}"
    printf "  █████╔╝ ██║   ██║██████╔╝█████╗  ██████╔╝██║     ███████║█████╗  ██████╔╝\n"
    printf "  ██╔═██╗ ██║   ██║██╔═══╝ ██╔══╝  ██╔══██╗██║     ██╔══██║██╔══╝  ██╔══██╗\n"
    printf "${_P}"
    printf "  ██║  ██╗╚██████╔╝██║     ███████╗██║  ██║╚██████╗██║  ██║███████╗██║  ██║\n"
    printf "  ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝\n"
    printf "${_0}"
    _br
    printf "  ${_D}                  PRIVATE  ·  HOLO  ·  ${_VR}${_0}\n"
    _br
    _line2
    _br
}

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

# ── Direct execution via argument ──────────────────────
if [ -n "$1" ]; then
    [ ! -d "$_BD" ] && mkdir -p "$_BD" && chmod 700 "$_BD"
    case "$1" in
        1) _patch "$_PM" "MAX" 1; exit $? ;;
        2) _patch "$_PM" "MAX" 2; exit $? ;;
        3) _restore "$_PM" "MAX"; exit $? ;;
        4) _patch "$_PR" "STD" 1; exit $? ;;
        5) _patch "$_PR" "STD" 2; exit $? ;;
        6) _restore "$_PR" "STD"; exit $? ;;
        *) echo "Invalid choice: $1"; exit 1 ;;
    esac
fi

# ── Main menu ──────────────────────────────────────────
_banner
_tag info "Kabe Private — Loaded"
sleep 1

while true; do
    _banner

    printf "  ${_G}  ● AUTHENTICATED${_0}   ${_D}|${_0}   ${_T}  ◆ OFFLINE${_0}\n"
    _br
    _line
    _br

    printf "  ${_P}${BLD}  FREE FIRE MAX${_0}\n"
    _br
    printf "  ${_D}  [${_0}${_W}1${_0}${_D}]${_0}   ${_G}✦${_0}  Activate  ${_W}HOLOGRAM${_0}\n"
    printf "  ${_D}  [${_0}${_W}2${_0}${_D}]${_0}   ${_G}◈${_0}  Activate  ${_W}GLOO INVISIBLE${_0}\n"
    printf "  ${_D}  [${_0}${_W}3${_0}${_D}]${_0}   ${_Y}⟲${_0}  Restore   ${_D}Original Data${_0}\n"
    _br
    _line
    _br

    printf "  ${_C}${BLD}  FREE FIRE NORMAL${_0}\n"
    _br
    printf "  ${_D}  [${_0}${_W}4${_0}${_D}]${_0}   ${_G}✦${_0}  Activate  ${_W}HOLOGRAM${_0}\n"
    printf "  ${_D}  [${_0}${_W}5${_0}${_D}]${_0}   ${_G}◈${_0}  Activate  ${_W}GLOO INVISIBLE${_0}\n"
    printf "  ${_D}  [${_0}${_W}6${_0}${_D}]${_0}   ${_Y}⟲${_0}  Restore   ${_D}Original Data${_0}\n"
    _br
    _line
    _br

    printf "  ${_D}  [${_0}${_W}7${_0}${_D}]${_0}   ${_R}✕${_0}  Exit\n"
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
        7) _tag info "Session closed."
           _br; sleep 1; exit 0 ;;
        *) _tag err "Invalid command."; sleep 1; continue ;;
    esac

    _br
    printf "  ${_D}  Press [Enter] to continue...${_0}"
    read _
done
