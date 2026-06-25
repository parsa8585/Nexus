#!/bin/bash
# nexus.sh - Created by Prs

# ── Prevent session timeout while script is running ──────────────
unset TMOUT
export TMOUT=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

W=52

sep_top() { printf "${CYAN}+"; printf '=%.0s' $(seq 1 $W); printf "+${NC}\n"; }
sep_mid() { printf "${CYAN}+"; printf -- '-%.0s' $(seq 1 $W); printf "+${NC}\n"; }
sep_bot() { printf "${CYAN}+"; printf '=%.0s' $(seq 1 $W); printf "+${NC}\n"; }

row() {
    local TEXT="$1"
    printf "${CYAN}|${NC}%-${W}s${CYAN}|${NC}\n" "$TEXT"
}

rowc() {
    local VIS=$1
    local STR="$2"
    local PAD=$(( W - VIS ))
    printf "${CYAN}|${NC}${STR}"
    printf "%${PAD}s" ""
    printf "${CYAN}|${NC}\n"
}

blank() { row ""; }

make_bar() {
    local PCT=$1
    local BWIDTH=$(( W - 2 ))
    local FILLED=$(( PCT * BWIDTH / 100 ))
    [ "$FILLED" -gt "$BWIDTH" ] && FILLED=$BWIDTH
    local EMPTY=$(( BWIDTH - FILLED ))
    local COLOR="$GREEN"
    [ "$PCT" -gt 60 ] && COLOR="$YELLOW"
    [ "$PCT" -gt 85 ] && COLOR="$RED"
    local BAR="${COLOR}"
    local i
    for (( i=0; i<FILLED; i++ )); do BAR+="#"; done
    BAR+="${DIM}"
    for (( i=0; i<EMPTY;  i++ )); do BAR+="-"; done
    BAR+="${NC}"
    rowc $(( BWIDTH + 2 )) "  ${BAR}"
}

# ── Safe curl wrapper (fallback-friendly) ────────────────────────
_curl() {
    curl -s --max-time 4 --connect-timeout 3 "$@" 2>/dev/null || true
}

# ── Server Info ──────────────────────────────────────────────────
get_server_info() {
    SRV_HOSTNAME=$(hostname 2>/dev/null || echo "N/A")

    # Helper: validate IPv4 format
    _valid_ip4() {
        echo "$1" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    }
    # Helper: validate IPv6 format
    _valid_ip6() {
        echo "$1" | grep -qE '^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$'
    }

    # IPv4 — try multiple sources, validate each result
    _raw=$(_curl -4 ifconfig.me); _valid_ip4 "$_raw" && SRV_IP4="$_raw" || SRV_IP4=""
    if [ -z "$SRV_IP4" ]; then
        _raw=$(_curl api.ipify.org); _valid_ip4 "$_raw" && SRV_IP4="$_raw" || SRV_IP4=""
    fi
    if [ -z "$SRV_IP4" ]; then
        _raw=$(_curl -4 icanhazip.com | tr -d '[:space:]'); _valid_ip4 "$_raw" && SRV_IP4="$_raw" || SRV_IP4=""
    fi
    if [ -z "$SRV_IP4" ]; then
        _raw=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/{print $7}' | head -1)
        _valid_ip4 "$_raw" && SRV_IP4="$_raw" || SRV_IP4=""
    fi
    [ -z "$SRV_IP4" ] && SRV_IP4="N/A"

    # IPv6 — validate result
    _raw=$(_curl -6 ifconfig.me); _valid_ip6 "$_raw" && SRV_IP6="$_raw" || SRV_IP6=""
    if [ -z "$SRV_IP6" ]; then
        _raw=$(ip -6 addr show scope global 2>/dev/null \
            | grep -oE '([0-9a-f]{0,4}:){2,7}[0-9a-f]{0,4}' | head -1)
        _valid_ip6 "$_raw" && SRV_IP6="$_raw" || SRV_IP6=""
    fi
    [ -z "$SRV_IP6" ] && SRV_IP6="N/A"

    SRV_OS=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || uname -s)
    SRV_KERNEL=$(uname -r 2>/dev/null || echo "N/A")
    SRV_UPTIME=$(uptime -p 2>/dev/null | sed 's/up //' || uptime 2>/dev/null | awk -F',' '{print $1}' | awk '{print $3,$4}')
    [ -z "$SRV_UPTIME" ] && SRV_UPTIME="N/A"
    SRV_LOAD=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "N/A")

    # Country — validate: must be plain text, no HTML tags
    if [ "$SRV_IP4" != "N/A" ]; then
        _raw=$(_curl "http://ip-api.com/line/${SRV_IP4}?fields=country")
        # Reject if contains HTML or is longer than 60 chars
        if [ -n "$_raw" ] && ! echo "$_raw" | grep -q '<' && [ "${#_raw}" -lt 60 ]; then
            SRV_COUNTRY="$_raw"
        else
            _raw=$(_curl "https://ipinfo.io/${SRV_IP4}/country" | tr -d '[:space:]')
            if [ -n "$_raw" ] && ! echo "$_raw" | grep -q '<' && [ "${#_raw}" -le 3 ]; then
                SRV_COUNTRY="$_raw"
            else
                SRV_COUNTRY="Unknown"
            fi
        fi
    else
        SRV_COUNTRY="Unknown"
    fi

    if   [ "$EUID" -eq 0 ];                    then SRV_USER="root [sudo]"
    elif groups 2>/dev/null | grep -qw sudo;   then SRV_USER="$(whoami) [sudo]"
    else                                             SRV_USER="$(whoami) [no sudo]"
    fi
}

# ── Main Menu ────────────────────────────────────────────────────
show_menu() {
    get_server_info; clear
    sep_top
    row "$(printf '%*s%s' $(( (W - 16) / 2 )) '' 'Nexus v1.2')"
    row "$(printf '%*s%s' $(( (W - 14) / 2 )) '' 'Created by Prs')"
    sep_mid
    blank
    row "$(printf '  %-12s: %-*s' 'Hostname'  $(( W-16 )) "${SRV_HOSTNAME:0:$((W-16))}")"
    row "$(printf '  %-12s: %-*s' 'IPv4'      $(( W-16 )) "${SRV_IP4:0:$((W-16))}")"
    row "$(printf '  %-12s: %-*s' 'IPv6'      $(( W-16 )) "${SRV_IP6:0:$((W-16))}")"
    row "$(printf '  %-12s: %-*s' 'Country'   $(( W-16 )) "${SRV_COUNTRY:0:$((W-16))}")"
    row "$(printf '  %-12s: %-*s' 'OS'        $(( W-16 )) "${SRV_OS:0:$((W-16))}")"
    row "$(printf '  %-12s: %-*s' 'Kernel'    $(( W-16 )) "${SRV_KERNEL:0:$((W-16))}")"
    row "$(printf '  %-12s: %-*s' 'Uptime'    $(( W-16 )) "${SRV_UPTIME:0:$((W-16))}")"
    row "$(printf '  %-12s: %-*s' 'Load'      $(( W-16 )) "${SRV_LOAD:0:$((W-16))}")"
    row "$(printf '  %-12s: %-*s' 'User'      $(( W-16 )) "${SRV_USER:0:$((W-16))}")"
    blank
    sep_mid
    blank
    row "   1.  System Manager"
    row "   2.  Monitoring & Diagnostics"
    row "   3.  Network Configuration"
    row "   4.  Security & Firewall"
    row "   5.  User Manager"
    row "   6.  Panel & SSL"
    row "   7.  Telegram Bot Panel"
    row "   0.  Exit"
    blank
    sep_bot
    echo ""
    echo -ne "  ${YELLOW}> Select option: ${NC}"
}

# ── 1. System Update & Cleanup ───────────────────────────────────
system_update() {
    local DIRECT_OPT="${1:-}"
    # check package manager
    local PKG_MGR=""
    if command -v apt &>/dev/null;    then PKG_MGR="apt"
    elif command -v apt-get &>/dev/null; then PKG_MGR="apt-get"
    elif command -v yum &>/dev/null;  then PKG_MGR="yum"
    elif command -v dnf &>/dev/null;  then PKG_MGR="dnf"
    fi

    _pkg_update()    { $PKG_MGR update -y 2>&1 || true; }
    _pkg_upgrade()   { $PKG_MGR upgrade -y 2>&1 || true; }
    _pkg_fullup()    {
        if [ "$PKG_MGR" = "apt" ] || [ "$PKG_MGR" = "apt-get" ]; then
            $PKG_MGR full-upgrade -y 2>&1 || true
        else
            $PKG_MGR upgrade -y 2>&1 || true
        fi
    }
    _pkg_clean()     {
        if [ "$PKG_MGR" = "apt" ] || [ "$PKG_MGR" = "apt-get" ]; then
            apt clean 2>/dev/null; apt autoclean 2>/dev/null
        elif [ "$PKG_MGR" = "yum" ] || [ "$PKG_MGR" = "dnf" ]; then
            $PKG_MGR clean all 2>/dev/null
        fi
    }
    _pkg_autoremove() {
        if [ "$PKG_MGR" = "apt" ] || [ "$PKG_MGR" = "apt-get" ]; then
            apt autoremove -y 2>&1 || true
        elif [ "$PKG_MGR" = "yum" ] || [ "$PKG_MGR" = "dnf" ]; then
            $PKG_MGR autoremove -y 2>&1 || true
        fi
    }
    _pkg_purge() {
        if [ "$PKG_MGR" = "apt" ] || [ "$PKG_MGR" = "apt-get" ]; then
            local PKGS
            PKGS=$(dpkg -l 2>/dev/null | awk '/^rc/{print $2}')
            if [ -n "$PKGS" ]; then
                apt purge -y $PKGS 2>/dev/null || true
                echo -e "  ${GREEN}[OK] Purge complete.${NC}"
            else
                echo -e "  ${DIM}Nothing to purge.${NC}"
            fi
        else
            echo -e "  ${YELLOW}[!] Purge only supported on apt systems.${NC}"
        fi
    }

    _run_opt() {
        local O="$1"
        clear
        if [ -z "$PKG_MGR" ]; then
            sep_top; row "  System Update"; sep_mid; blank
            rowc 40 "  ${RED}[!] No supported package manager found.${NC}"
            blank; sep_bot; echo ""
            echo -ne "  ${DIM}Press any key...${NC}"; read -n 1; return
        fi
        case $O in
            1)
                sep_top; row "         Update Package List"; sep_mid; echo ""
                echo -e "\n  ${CYAN}[*] Updating package list...${NC}\n"
                _pkg_update
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            2)
                sep_top; row "           Upgrade Packages"; sep_mid; echo ""
                echo -e "\n  ${CYAN}[*] Upgrading packages...${NC}\n"
                _pkg_upgrade
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            3)
                sep_top; row "    Purge & Clean & Autoremove"; sep_mid; echo ""
                echo -e "\n  ${CYAN}[*] Purging config files...${NC}\n"
                _pkg_purge
                echo -e "\n  ${CYAN}[*] Cleaning cache...${NC}\n"
                _pkg_clean
                echo -e "\n  ${CYAN}[*] Removing unused packages...${NC}\n"
                _pkg_autoremove
                echo -e "\n  ${GREEN}[OK] All done.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            4)
                sep_top; row "       Update & Upgrade (All)"; sep_mid; echo ""
                echo -e "\n  ${CYAN}[*] Running full update cycle...${NC}\n"
                _pkg_update; _pkg_upgrade; _pkg_fullup; _pkg_autoremove; _pkg_clean
                echo -e "\n  ${GREEN}[OK] All done.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            5)
                sep_top; row "    All: Update + Upgrade + Autoclean"; sep_mid; echo ""
                echo -e "\n  ${CYAN}[*] Step 1/3 — Updating package list...${NC}\n"
                _pkg_update
                echo -e "\n  ${CYAN}[*] Step 2/3 — Upgrading packages...${NC}\n"
                _pkg_upgrade
                echo -e "\n  ${CYAN}[*] Step 3/3 — Autoremove & Clean...${NC}\n"
                _pkg_autoremove; _pkg_clean
                echo -e "\n  ${GREEN}[OK] Done: update + upgrade + autoclean complete.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
        esac
    }

    # If called with a direct option, run it and return
    if [ -n "$DIRECT_OPT" ]; then
        _run_opt "$DIRECT_OPT"; return
    fi
}

# ── 2. SSH Monitor ───────────────────────────────────────────────
ssh_monitor() {
    tput smcup 2>/dev/null; tput civis 2>/dev/null
    trap 'tput rmcup 2>/dev/null; tput cnorm 2>/dev/null; return' INT

    while true; do
        SESSIONS=$(w -h 2>/dev/null || who 2>/dev/null | awk '{print $1,$2,"","","","","",""}')
        COUNT=0; [ -n "$SESSIONS" ] && COUNT=$(echo "$SESSIONS" | grep -c . 2>/dev/null || echo 0)

        declare -A IP_MAP
        # Build map: username → real remote IP from SSH_CLIENT in sshd process env
        # sshd forks a child per session; that child has SSH_CLIENT set
        declare -A USER_IP_MAP
        for _pid in /proc/[0-9]*/environ; do
            _p=$(echo "$_pid" | grep -oE '[0-9]+')
            [ -z "$_p" ] && continue
            # Only look at sshd processes
            _cmd=$(cat "/proc/${_p}/comm" 2>/dev/null)
            [ "$_cmd" != "sshd" ] && continue
            _env=$(cat "/proc/${_p}/environ" 2>/dev/null | tr '\0' '\n')
            _ssh_client=$(echo "$_env" | grep '^SSH_CLIENT=' | cut -d= -f2 | awk '{print $1}')
            [ -z "$_ssh_client" ] && continue
            # Skip private/loopback
            echo "$_ssh_client" | grep -qE '^(127\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|::1)' && continue
            _uname=$(echo "$_env" | grep '^USER=' | cut -d= -f2)
            [ -z "$_uname" ] && _uname=$(cat "/proc/${_p}/loginuid" 2>/dev/null                 | xargs -I{} getent passwd {} 2>/dev/null | cut -d: -f1)
            [ -n "$_uname" ] && USER_IP_MAP["$_uname"]="$_ssh_client"
        done

        # Map PTY → IP via ss (for non-tunnel direct connections)
        while IFS= read -r ssline; do
            FOREIGN=$(echo "$ssline" | awk '{print $5}')
            PROC=$(echo "$ssline"    | awk '{print $NF}')
            RAW_IP=$(echo "$FOREIGN" | sed 's/\[//g;s/\]//g' | rev | cut -d':' -f2- | rev)
            echo "$RAW_IP" | grep -qE '^(127\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)' && continue
            PTS=$(echo "$PROC" | grep -oE 'pts/[0-9]+' | head -1)
            [ -n "$PTS" ] && [ -n "$RAW_IP" ] && IP_MAP["$PTS"]="$RAW_IP"
        done < <(ss -tnp 2>/dev/null | grep -i sshd || true)

        # Fallback: who output (contains real IP in parentheses for direct SSH)
        declare -A WHO_MAP
        while IFS= read -r wholine; do
            W_TTY=$(echo "$wholine" | awk '{print $2}')
            W_IP=$(echo "$wholine"  | grep -oE '\([0-9a-fA-F:.]+\)' | tr -d '()')
            echo "$W_IP" | grep -qE '^(127\.|::1)' && continue
            [ -n "$W_TTY" ] && [ -n "$W_IP" ] && WHO_MAP["$W_TTY"]="$W_IP"
        done < <(who 2>/dev/null || true)

        OUT=""
        OUT+="$(sep_top)"$'\n'
        OUT+="$(row "$(printf '%*s%s' $(( (W - 21) / 2 )) '' 'SSH Active Sessions')")"$'\n'
        OUT+="$(row "  Q=back    $(date '+%Y-%m-%d %H:%M:%S')")"$'\n'
        OUT+="$(sep_mid)"$'\n'
        OUT+="$(row "  Online Users: $COUNT")"$'\n'
        OUT+="$(sep_mid)"$'\n'
        OUT+="$(row "  USER       IP              LOGIN   IDLE WHAT")"$'\n'
        OUT+="$(sep_mid)"$'\n'

        if [ "$COUNT" -eq 0 ]; then
            OUT+="$(row "  No active SSH sessions")"$'\n'
        else
            while IFS= read -r sess; do
                [ -z "$sess" ] && continue
                U=$(    echo "$sess" | awk '{print $1}')
                TTY=$(  echo "$sess" | awk '{print $2}')
                LOGIN=$(echo "$sess" | awk '{print $4}')
                IDLE=$( echo "$sess" | awk '{print $5}')
                WHAT=$( echo "$sess" | awk '{print $8}' | cut -c1-8)

                # Priority: PTY→IP (ss) > USER→IP (SSH_CLIENT env) > who > unknown
                if [ -n "${IP_MAP[$TTY]}" ]; then
                    IP="${IP_MAP[$TTY]}"
                elif [ -n "${USER_IP_MAP[$U]}" ]; then
                    IP="${USER_IP_MAP[$U]}"
                elif [ -n "${WHO_MAP[$TTY]}" ]; then
                    IP="${WHO_MAP[$TTY]}"
                else
                    IP="unknown"
                fi

                LINE=$(printf "  %-10s%-16s%-9s%-6s%s" \
                    "$U" "${IP:0:15}" "$LOGIN" "$IDLE" "$WHAT")
                OUT+="$(row "$LINE")"$'\n'
            done <<< "$SESSIONS"
        fi
        OUT+="$(sep_bot)"$'\n'

        unset IP_MAP WHO_MAP USER_IP_MAP

        tput cup 0 0 2>/dev/null
        printf '%s' "$OUT"
        tput ed 2>/dev/null

        read -t 3 -n 1 key 2>/dev/null || true
        [[ "$key" = "q" || "$key" = "Q" ]] && break
    done
    trap - INT; tput rmcup 2>/dev/null; tput cnorm 2>/dev/null
}

# ── 3. Network Monitor ───────────────────────────────────────────
network_monitor() {
    # Check /proc/net/dev exists
    if [ ! -f /proc/net/dev ]; then
        echo -e "\n  ${RED}[ERR] /proc/net/dev not found.${NC}"; sleep 2; return
    fi

    tput smcup 2>/dev/null; tput civis 2>/dev/null
    trap 'tput rmcup 2>/dev/null; tput cnorm 2>/dev/null; return' INT

    # Detect interface
    IFACE=""
    IFACE=$(ip route 2>/dev/null | grep '^default' | awk '{print $5}' | head -1)
    [ -z "$IFACE" ] && IFACE=$(ip link 2>/dev/null | awk -F: '/^[0-9]/ && !/lo/{gsub(/ /,"",$2); print $2; exit}')
    [ -z "$IFACE" ] && IFACE=$(grep -v '^\s*lo\|Inter\|face' /proc/net/dev 2>/dev/null | awk -F: 'NR==1{gsub(/ /,"",$1); print $1}')
    if [ -z "$IFACE" ]; then
        tput rmcup 2>/dev/null; tput cnorm 2>/dev/null
        echo -e "\n  ${RED}[ERR] Could not detect network interface.${NC}"; sleep 2; return
    fi

    read_rx() { awk -v iface="${IFACE}:" '$1==iface{print $2}' /proc/net/dev 2>/dev/null || echo 0; }
    read_tx() { awk -v iface="${IFACE}:" '$1==iface{print $10}' /proc/net/dev 2>/dev/null || echo 0; }

    PREV_RX=$(read_rx); PREV_TX=$(read_tx)
    PREV_TIME=$(date +%s%N 2>/dev/null || echo 0)

    fmt_speed() {
        local B=${1:-0}
        if   [ "$B" -gt 1048576 ]; then printf "%.1f MB/s" "$(awk "BEGIN{printf \"%.1f\",$B/1048576}")"
        elif [ "$B" -gt 1024 ];    then printf "%d KB/s" "$(( B/1024 ))"
        else                            printf "%d B/s" "$B"
        fi
    }

    while true; do
        sleep 1
        NOW=$(date +%s%N 2>/dev/null || echo 0)
        CUR_RX=$(read_rx); CUR_TX=$(read_tx)

        ELAPSED=1
        if [ "$NOW" -gt 0 ] && [ "$PREV_TIME" -gt 0 ]; then
            ELAPSED=$(( (NOW - PREV_TIME) / 1000000 ))
            [ "$ELAPSED" -le 0 ] && ELAPSED=1
        fi

        RX_RATE=$(( (CUR_RX - PREV_RX) * 1000 / ELAPSED ))
        TX_RATE=$(( (CUR_TX - PREV_TX) * 1000 / ELAPSED ))
        [ "$RX_RATE" -lt 0 ] && RX_RATE=0
        [ "$TX_RATE" -lt 0 ] && TX_RATE=0
        PREV_RX=$CUR_RX; PREV_TX=$CUR_TX; PREV_TIME=$NOW

        RX_STR=$(fmt_speed $RX_RATE)
        TX_STR=$(fmt_speed $TX_RATE)

        # numfmt fallback
        if command -v numfmt &>/dev/null; then
            RX_TOT=$(numfmt --to=iec $CUR_RX 2>/dev/null || echo "${CUR_RX}B")
            TX_TOT=$(numfmt --to=iec $CUR_TX 2>/dev/null || echo "${CUR_TX}B")
        else
            RX_TOT=$(awk "BEGIN{printf \"%.1fM\",$CUR_RX/1048576}" 2>/dev/null || echo "${CUR_RX}B")
            TX_TOT=$(awk "BEGIN{printf \"%.1fM\",$CUR_TX/1048576}" 2>/dev/null || echo "${CUR_TX}B")
        fi

        RX_PKT=$(awk -v iface="${IFACE}:" '$1==iface{print $3}' /proc/net/dev 2>/dev/null || echo 0)
        TX_PKT=$(awk -v iface="${IFACE}:" '$1==iface{print $11}' /proc/net/dev 2>/dev/null || echo 0)

        BAR_MAX=10485760
        RX_PCT=$(( RX_RATE * 100 / (BAR_MAX+1) )); [ "$RX_PCT" -gt 100 ] && RX_PCT=100
        TX_PCT=$(( TX_RATE * 100 / (BAR_MAX+1) )); [ "$TX_PCT" -gt 100 ] && TX_PCT=100

        OUT=""
        OUT+="$(sep_top)"$'\n'
        OUT+="$(row "  Network Monitor  -  Interface: $IFACE")"$'\n'
        OUT+="$(row "  Q=back    $(date '+%Y-%m-%d %H:%M:%S')")"$'\n'
        OUT+="$(sep_mid)"$'\n'
        OUT+="$(row "")"$'\n'
        OUT+="$(row "  Download : $(printf '%-14s' "$RX_STR")  Total: $RX_TOT")"$'\n'
        OUT+="$(make_bar $RX_PCT)"$'\n'
        OUT+="$(row "")"$'\n'
        OUT+="$(row "  Upload   : $(printf '%-14s' "$TX_STR")  Total: $TX_TOT")"$'\n'
        OUT+="$(make_bar $TX_PCT)"$'\n'
        OUT+="$(row "")"$'\n'
        OUT+="$(sep_mid)"$'\n'
        OUT+="$(row "  RX Packets : $RX_PKT")"$'\n'
        OUT+="$(row "  TX Packets : $TX_PKT")"$'\n'
        OUT+="$(row "  Interface  : $IFACE")"$'\n'
        OUT+="$(sep_bot)"$'\n'

        tput cup 0 0 2>/dev/null
        printf '%s' "$OUT"
        tput ed 2>/dev/null

        read -t 1 -n 1 key 2>/dev/null || true
        [[ "$key" = "q" || "$key" = "Q" ]] && break
    done
    trap - INT; tput rmcup 2>/dev/null; tput cnorm 2>/dev/null
}

# ── 4. System Resources ──────────────────────────────────────────
system_resources() {
    tput smcup 2>/dev/null; tput civis 2>/dev/null
    trap 'tput rmcup 2>/dev/null; tput cnorm 2>/dev/null; return' INT

    while true; do
        # CPU — read all fields (user nice system idle iowait irq softirq steal)
        if [ -f /proc/stat ]; then
            read -r _cpu a1 b1 c1 d1 e1 f1 g1 h1 _ < /proc/stat
            sleep 1
            read -r _cpu a2 b2 c2 d2 e2 f2 g2 h2 _ < /proc/stat
            TOTAL1=$(( a1+b1+c1+d1+e1+f1+g1+h1 ))
            TOTAL2=$(( a2+b2+c2+d2+e2+f2+g2+h2 ))
            DTOT=$(( TOTAL2 - TOTAL1 ))
            DIDL=$(( d2 - d1 ))
            [ "$DTOT" -le 0 ] && DTOT=1
            CPU_PCT=$(( 100*(DTOT-DIDL)/DTOT ))
            [ "$CPU_PCT" -lt 0 ] && CPU_PCT=0
            [ "$CPU_PCT" -gt 100 ] && CPU_PCT=100
        else
            sleep 1; CPU_PCT=0
        fi

        CPU_CORES=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)
        CPU_MODEL=$(grep "model name" /proc/cpuinfo 2>/dev/null \
            | head -1 | cut -d':' -f2 | xargs 2>/dev/null | cut -c1-28)
        [ -z "$CPU_MODEL" ] && CPU_MODEL=$(uname -m 2>/dev/null || echo "Unknown")

        # RAM
        RAM_TOTAL=$(awk '/MemTotal/{print int($2/1024)}'     /proc/meminfo 2>/dev/null || echo 0)
        RAM_AVAIL=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
        RAM_FREE=$( awk '/MemFree/{print int($2/1024)}'      /proc/meminfo 2>/dev/null || echo 0)
        RAM_CACHE=$(awk '/^Cached/{print int($2/1024)}'      /proc/meminfo 2>/dev/null || echo 0)
        RAM_USED=$(( RAM_TOTAL - RAM_AVAIL ))
        [ "$RAM_USED" -lt 0 ] && RAM_USED=0
        RAM_PCT=$(( RAM_TOTAL > 0 ? RAM_USED * 100 / RAM_TOTAL : 0 ))

        # SWAP
        SWAP_TOTAL=$(awk '/SwapTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
        SWAP_FREE=$( awk '/SwapFree/{print int($2/1024)}'  /proc/meminfo 2>/dev/null || echo 0)
        SWAP_USED=$(( SWAP_TOTAL - SWAP_FREE ))
        SWAP_PCT=0
        [ "$SWAP_TOTAL" -gt 0 ] && SWAP_PCT=$(( SWAP_USED*100/SWAP_TOTAL ))

        # Disk
        DISK_USED=$(df -h / 2>/dev/null | awk 'NR==2{print $3}' || echo "N/A")
        DISK_TOTAL=$(df -h / 2>/dev/null | awk 'NR==2{print $2}' || echo "N/A")
        DISK_FREE=$(df -h / 2>/dev/null | awk 'NR==2{print $4}' || echo "N/A")
        DISK_PCT=$(df / 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}' || echo 0)
        [ -z "$DISK_PCT" ] || ! [[ "$DISK_PCT" =~ ^[0-9]+$ ]] && DISK_PCT=0

        UPTIME_STR=$(uptime -p 2>/dev/null | sed 's/up //' || uptime 2>/dev/null | awk '{print $3,$4}' | tr -d ',')
        [ -z "$UPTIME_STR" ] && UPTIME_STR="N/A"
        LOAD=$(awk '{print $1" "$2" "$3}' /proc/loadavg 2>/dev/null || echo "N/A")
        PROCS=$(ps aux 2>/dev/null | wc -l || echo "N/A")
        THREADS=$(ps -eo nlwp 2>/dev/null | tail -n+2 | awk '{s+=$1}END{print s}' || echo "N/A")

        # CPU Temperature
        CPU_TEMP="N/A"
        if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
            _T=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
            [ -n "$_T" ] && CPU_TEMP=$(awk "BEGIN{printf \"%.1f°C\", $_T/1000}")
        elif command -v sensors &>/dev/null; then
            CPU_TEMP=$(sensors 2>/dev/null | grep -E 'Core 0|Package|Tdie|Tctl' \
                | head -1 | grep -oE '[+-][0-9]+\.[0-9]+°C' | head -1)
            [ -z "$CPU_TEMP" ] && CPU_TEMP="N/A"
        fi
        # Temp color
        TEMP_COLOR="$GREEN"
        if [[ "$CPU_TEMP" =~ ^[0-9]+\. ]]; then
            _TV=$(echo "$CPU_TEMP" | grep -oE '[0-9]+' | head -1)
            [ "$_TV" -gt 70 ] && TEMP_COLOR="$YELLOW"
            [ "$_TV" -gt 85 ] && TEMP_COLOR="$RED"
        fi

        OUT=""
        OUT+="$(sep_top)"$'\n'
        OUT+="$(row "           System Resources")"$'\n'
        OUT+="$(row "  Q=back    $(date '+%Y-%m-%d %H:%M:%S')")"$'\n'
        OUT+="$(sep_mid)"$'\n'
        OUT+="$(row "")"$'\n'
        OUT+="$(row "  CPU  ${CPU_MODEL}  ${CPU_PCT}%")"$'\n'
        OUT+="$(make_bar $CPU_PCT)"$'\n'
        OUT+="$(row "  Cores: $CPU_CORES    Load: $LOAD")"$'\n'
        OUT+="$(row "")"$'\n'
        OUT+="$(row "  RAM  Used:${RAM_USED}MB Free:${RAM_FREE}MB Cache:${RAM_CACHE}MB")"$'\n'
        OUT+="$(make_bar $RAM_PCT)"$'\n'
        OUT+="$(row "  Total: ${RAM_TOTAL}MB")"$'\n'
        OUT+="$(row "")"$'\n'
        OUT+="$(row "  SWAP  Used:${SWAP_USED}MB  Total:${SWAP_TOTAL}MB")"$'\n'
        OUT+="$(make_bar $SWAP_PCT)"$'\n'
        OUT+="$(row "")"$'\n'
        OUT+="$(row "  DISK  Used:${DISK_USED}  Free:${DISK_FREE}  Total:${DISK_TOTAL}")"$'\n'
        OUT+="$(make_bar $DISK_PCT)"$'\n'
        OUT+="$(row "")"$'\n'
        OUT+="$(sep_mid)"$'\n'
        OUT+="$(row "  Uptime   : $UPTIME_STR")"$'\n'
        OUT+="$(row "  Processes: $PROCS    Threads: $THREADS")"$'\n'
        OUT+="$(sep_bot)"$'\n'

        tput cup 0 0 2>/dev/null
        printf '%s' "$OUT"
        tput ed 2>/dev/null

        read -t 1 -n 1 key 2>/dev/null || true
        [[ "$key" = "q" || "$key" = "Q" ]] && break
    done
    trap - INT; tput rmcup 2>/dev/null; tput cnorm 2>/dev/null
}

# ── 5. User Manager ──────────────────────────────────────────────
user_manager() {
    while true; do
        clear
        TOTAL_USERS=$(awk -F: '$3>=1000 && $7~/bash|sh/' /etc/passwd 2>/dev/null | wc -l || echo 0)
        ONLINE_USERS=$(w -h 2>/dev/null | wc -l || who 2>/dev/null | wc -l || echo 0)

        sep_top
        row "$(printf '%*s%s' $(( (W - 16) / 2 )) '' 'SSH User Manager')"
        row "$(printf '%*s%s' $(( (W - 14) / 2 )) '' 'Created by Prs')"
        sep_mid
        row "  Total Users : $TOTAL_USERS    Online Now : $ONLINE_USERS"
        sep_mid
        row ""
        row "   1.  Create New User"
        row "   2.  Remove User"
        row "   3.  List All SSH Users"
        row "   4.  Modify User"
        row "   5.  Modify Group"
        row "   0.  Back to Main Menu"
        row ""
        sep_bot
        echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"
        read -r OPT; echo ""

        case $OPT in
            1)
                # ── Step 1: Username ──────────────────────────────
                while true; do
                    clear
                    sep_top; row "          Create New SSH User"; sep_mid
                    row "  Step 1/4 : Username"; sep_bot; echo ""
                    echo -ne "  ${YELLOW}Username (or 0 to cancel): ${NC}"; read -r USERNAME
                    [ "$USERNAME" = "0" ] && break
                    if [ -z "$USERNAME" ]; then
                        echo -e "  ${RED}Username cannot be empty. Try again.${NC}"; sleep 2; continue
                    fi
                    if ! echo "$USERNAME" | grep -qE '^[a-z_][a-z0-9_-]{0,31}$'; then
                        echo -e "  ${RED}Invalid username. Use lowercase letters, numbers, _ or -.${NC}"
                        sleep 2; continue
                    fi
                    if id "$USERNAME" &>/dev/null; then
                        echo -e "  ${RED}User '$USERNAME' already exists.${NC}"; sleep 2; continue
                    fi

                    # ── Step 2: Password ──────────────────────────
                    while true; do
                        clear
                        sep_top; row "          Create New SSH User"; sep_mid
                        row "  Step 2/4 : Password  (user: $USERNAME)"; sep_bot; echo ""
                        echo -ne "  ${YELLOW}Password (or 0 to go back): ${NC}"; read -rs PASSWORD; echo ""
                        [ "$PASSWORD" = "0" ] && break
                        if [ -z "$PASSWORD" ]; then
                            echo -e "  ${RED}Password cannot be empty. Try again.${NC}"; sleep 2; continue
                        fi

                        # ── Step 3: Access Level ──────────────────
                        while true; do
                            clear
                            sep_top; row "          Create New SSH User"; sep_mid
                            row "  Step 3/4 : Access Level  (user: $USERNAME)"; sep_bot; echo ""
                            echo -e "   1. Normal user (no sudo)"
                            echo -e "   2. Sudo user (admin)"
                            echo -e "   3. Custom group only"
                            echo -e "   0. Back"
                            echo -ne "\n  ${YELLOW}> Select access level: ${NC}"
                            read -n 1 ACCESS_OPT; echo ""
                            [ "$ACCESS_OPT" = "0" ] && break

                            # ── Step 4: Additional Group ──────────
                            ADD_GROUP=""
                            while true; do
                                clear
                                sep_top; row "          Create New SSH User"; sep_mid
                                row "  Step 4/4 : Additional Group  (user: $USERNAME)"; sep_bot; echo ""
                                echo -e "  ${DIM}Available groups:${NC}"
                                getent group 2>/dev/null | awk -F: '$3>=1000 || $1~/docker|www-data|sudo|adm/{printf "  %-20s GID:%s\n",$1,$3}' | head -15
                                echo ""
                                echo -e "  ${CYAN}Enter an extra group to also add this user to,${NC}"
                                echo -e "  ${CYAN}or leave blank to skip, or 0 to go back.${NC}"
                                echo -ne "\n  ${YELLOW}Extra group (blank=skip, 0=back): ${NC}"; read -r ADD_GROUP
                                [ "$ADD_GROUP" = "0" ] && ADD_GROUP="" && break 2   # back to access level
                                # Accept blank (skip) or a valid/new group name
                                if [ -n "$ADD_GROUP" ] && ! echo "$ADD_GROUP" | grep -qE '^[a-z_][a-z0-9_-]{0,31}$'; then
                                    echo -e "  ${RED}Invalid group name.${NC}"; sleep 2; continue
                                fi
                                break
                            done

                            # ── Create the user ───────────────────
                            clear
                            sep_top; row "          Create New SSH User"; sep_mid; blank
                            echo -e "  ${CYAN}[*] Creating user '$USERNAME'...${NC}"
                            if ! useradd -m -s /bin/bash "$USERNAME" 2>/dev/null; then
                                echo -e "  ${RED}[ERR] Failed to create user. Are you root?${NC}"
                                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1; break 3
                            fi
                            if ! echo "$USERNAME:$PASSWORD" | chpasswd 2>/dev/null; then
                                echo -e "  ${RED}[ERR] Failed to set password.${NC}"
                                userdel -r "$USERNAME" 2>/dev/null
                                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1; break 3
                            fi
                            echo -e "  ${GREEN}[OK] User '$USERNAME' created.${NC}"

                            case $ACCESS_OPT in
                                1)
                                    echo -e "  ${DIM}Access: Normal user (no sudo).${NC}" ;;
                                2)
                                    usermod -aG sudo "$USERNAME" 2>/dev/null && \
                                        echo -e "  ${GREEN}[OK] Added to sudo group.${NC}" || \
                                        echo -e "  ${YELLOW}[!] Could not add to sudo group.${NC}" ;;
                                3)
                                    echo -ne "  ${YELLOW}Custom group name: ${NC}"; read -r CGROUP
                                    if [ -n "$CGROUP" ]; then
                                        getent group "$CGROUP" &>/dev/null || groupadd "$CGROUP" 2>/dev/null
                                        usermod -aG "$CGROUP" "$USERNAME" 2>/dev/null && \
                                            echo -e "  ${GREEN}[OK] Added to group '$CGROUP'.${NC}" || \
                                            echo -e "  ${YELLOW}[!] Could not add to group '$CGROUP'.${NC}"
                                    fi ;;
                                *)
                                    echo -e "  ${DIM}No special access assigned.${NC}" ;;
                            esac

                            # Additional group
                            if [ -n "$ADD_GROUP" ]; then
                                getent group "$ADD_GROUP" &>/dev/null || groupadd "$ADD_GROUP" 2>/dev/null
                                usermod -aG "$ADD_GROUP" "$USERNAME" 2>/dev/null && \
                                    echo -e "  ${GREEN}[OK] Also added to group '$ADD_GROUP'.${NC}" || \
                                    echo -e "  ${YELLOW}[!] Could not add to group '$ADD_GROUP'.${NC}"
                            fi

                            echo -e "\n  ${GREEN}Summary:${NC}"
                            echo -e "  User     : $USERNAME"
                            echo -e "  Groups   : $(id -Gn "$USERNAME" 2>/dev/null | tr ' ' ',')"
                            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                            break 3   # done — exit all loops back to user_manager
                        done  # access level loop
                    done  # password loop
                    break   # username accepted, password/access done or backed out
                done  # username loop
                ;;
            2)
                clear
                sep_top; row "           Remove User"; sep_bot; echo ""
                echo -ne "  ${YELLOW}Username to remove: ${NC}"; read -r DELUSER
                [ -z "$DELUSER" ] && continue
                if ! id "$DELUSER" &>/dev/null; then
                    echo -e "  ${RED}User '$DELUSER' not found.${NC}"; sleep 2; continue
                fi
                # Prevent removing root or current user
                if [ "$DELUSER" = "root" ]; then
                    echo -e "  ${RED}[ERR] Cannot remove root.${NC}"; sleep 2; continue
                fi
                if [ "$DELUSER" = "$(whoami)" ]; then
                    echo -e "  ${RED}[ERR] Cannot remove yourself.${NC}"; sleep 2; continue
                fi
                echo -ne "  ${RED}Are you sure? (y/N): ${NC}"; read -n 1 CONFIRM; echo ""
                if [[ "$CONFIRM" = "y" || "$CONFIRM" = "Y" ]]; then
                    echo -e "  ${CYAN}[*] Killing active sessions...${NC}"
                    pkill -9 -u "$DELUSER" 2>/dev/null; sleep 1
                    echo -e "  ${CYAN}[*] Removing user...${NC}"
                    local DEL_ERR
                    DEL_ERR=$(userdel -r "$DELUSER" 2>&1)
                    local DEL_EXIT=$?
                    if [ $DEL_EXIT -eq 0 ]; then
                        echo -e "  ${GREEN}[OK] User '$DELUSER' removed successfully.${NC}"
                    elif ! id "$DELUSER" &>/dev/null; then
                        # userdel returned error but user is gone — treat as success
                        echo -e "  ${GREEN}[OK] User '$DELUSER' removed.${NC}"
                        [ -n "$DEL_ERR" ] && echo -e "  ${DIM}(Note: ${DEL_ERR})${NC}"
                    else
                        echo -e "  ${RED}[ERR] Failed to remove '$DELUSER'.${NC}"
                        echo -e "  ${RED}${DEL_ERR}${NC}"
                        echo -e "  ${YELLOW}[*] Trying force remove...${NC}"
                        # Force: remove from passwd/shadow manually
                        sed -i "/^${DELUSER}:/d" /etc/passwd 2>/dev/null
                        sed -i "/^${DELUSER}:/d" /etc/shadow 2>/dev/null
                        sed -i "/^${DELUSER}:/d" /etc/group 2>/dev/null
                        if ! id "$DELUSER" &>/dev/null; then
                            echo -e "  ${GREEN}[OK] User '$DELUSER' force-removed.${NC}"
                        else
                            echo -e "  ${RED}[ERR] Could not remove. Are you root?${NC}"
                        fi
                    fi
                else
                    echo -e "  ${DIM}Cancelled.${NC}"
                fi
                echo -ne "
  ${DIM}Press any key...${NC}"; read -n 1 ;;
            3)
                clear
                sep_top
                row "$(printf '%*s%s' $(( (W - 13) / 2 )) '' 'SSH User List')"
                sep_mid
                # Header row — no color in cells so printf width is exact
                printf "${CYAN}|${NC}%-13s${CYAN}|${NC}%-10s${CYAN}|${NC}%-9s${CYAN}|${NC}%-17s${CYAN}|${NC}\n" \
                    "  USERNAME" "  ACCOUNT" " SESSION" "  GROUPS"
                sep_mid
                awk -F: '$3>=1000 && $7~/bash|sh/{print $1}' /etc/passwd 2>/dev/null | while read -r u; do
                    GRPS=$(id -Gn "$u" 2>/dev/null | tr ' ' ',' | cut -c1-15)
                    # Account lock status — build padded plain label, print color separately
                    _LS=$(passwd -S "$u" 2>/dev/null | awk '{print $2}')
                    if [ "$_LS" = "L" ] || [ "$_LS" = "LK" ]; then
                        ACC_C="${RED}"; ACC_L=" disabled "
                    else
                        ACC_C="${GREEN}"; ACC_L=" enabled  "
                    fi
                    # Session status
                    if w -h 2>/dev/null | awk '{print $1}' | grep -qw "$u" 2>/dev/null || \
                       who 2>/dev/null | awk '{print $1}' | grep -qw "$u" 2>/dev/null; then
                        SES_C="${GREEN}"; SES_L=" *online "
                    else
                        SES_C="${DIM}";  SES_L=" offline "
                    fi
                    # Fixed-width cells: color wraps only the label (no spaces inside escape)
                    # Col widths: 13 | 10 | 9 | 17  → total inner = 13+10+9+17 + 4 borders = 53... adjust
                    # W=52: |13|10|9|17| = 13+1+10+1+9+1+17+1 = 53 → use 13|10|9|16
                    printf "${CYAN}|${NC}  %-11s${CYAN}|${NC}${ACC_C}%-10s${NC}${CYAN}|${NC}${SES_C}%-9s${NC}${CYAN}|${NC}  %-15s${CYAN}|${NC}\n" \
                        "${u:0:11}" "$ACC_L" "$SES_L" "${GRPS:0:15}"
                done
                sep_bot; echo ""
                echo -ne "  ${DIM}Press any key...${NC}"; read -n 1
                ;;
            4) modify_user ;;
            5) modify_group ;;
            0) return ;;
            *) echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# ── 5b. Modify User ──────────────────────────────────────────────
modify_user() {
    while true; do
        clear
        sep_top
        row "$(printf '%*s%s' $(( (W - 11) / 2 )) '' 'Modify User')"
        sep_mid
        row ""
        row "   1.  Add User to Group"
        row "   2.  Remove User from Group"
        row "   3.  Set User Permission (sudo)"
        row "   4.  Change Username"
        row "   5.  Change Password"
        row "   6.  Change Shell"
        row "   7.  Enable / Disable User"
        row "   0.  Back"
        row ""
        sep_bot
        echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"
        read -r MUOPT; echo ""

        case $MUOPT in
            1)
                clear
                sep_top; row "         Add User to Group"; sep_bot; echo ""
                echo -ne "  ${YELLOW}Username : ${NC}"; read -r ADDUSER
                [ -z "$ADDUSER" ] && continue
                if ! id "$ADDUSER" &>/dev/null; then
                    echo -e "  ${RED}User '$ADDUSER' not found.${NC}"; sleep 2; continue
                fi
                echo -ne "  ${YELLOW}Group    : ${NC}"; read -r ADDGROUP
                [ -z "$ADDGROUP" ] && echo -e "  ${RED}Group cannot be empty.${NC}" && sleep 2 && continue
                if ! getent group "$ADDGROUP" &>/dev/null; then
                    echo -ne "  ${YELLOW}Group '$ADDGROUP' not found. Create it? (y/N): ${NC}"
                    read -n 1 MKGRP; echo ""
                    if [[ "$MKGRP" = "y" || "$MKGRP" = "Y" ]]; then
                        groupadd "$ADDGROUP" && echo -e "  ${GREEN}[OK] Group '$ADDGROUP' created.${NC}" || \
                            { echo -e "  ${RED}[ERR] Could not create group.${NC}"; sleep 2; continue; }
                    else
                        echo -e "  ${DIM}Cancelled.${NC}"; sleep 2; continue
                    fi
                fi
                usermod -aG "$ADDGROUP" "$ADDUSER" && \
                    echo -e "  ${GREEN}[OK] '$ADDUSER' added to '$ADDGROUP'.${NC}" || \
                    echo -e "  ${RED}[ERR] Failed.${NC}"
                echo -e "  ${DIM}Groups: $(id -Gn "$ADDUSER" 2>/dev/null | tr ' ' ',')${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                ;;
            2)
                clear
                sep_top; row "      Remove User from Group"; sep_bot; echo ""
                echo -ne "  ${YELLOW}Username : ${NC}"; read -r RMUSER
                [ -z "$RMUSER" ] && continue
                if ! id "$RMUSER" &>/dev/null; then
                    echo -e "  ${RED}User '$RMUSER' not found.${NC}"; sleep 2; continue
                fi
                echo -e "  ${DIM}Groups: $(id -Gn "$RMUSER" 2>/dev/null | tr ' ' ',')${NC}"
                echo -ne "  ${YELLOW}Group to remove from: ${NC}"; read -r RMGROUP
                [ -z "$RMGROUP" ] && echo -e "  ${RED}Group cannot be empty.${NC}" && sleep 2 && continue
                if ! getent group "$RMGROUP" &>/dev/null; then
                    echo -e "  ${RED}Group '$RMGROUP' does not exist.${NC}"; sleep 2; continue
                fi
                if gpasswd -d "$RMUSER" "$RMGROUP" 2>/dev/null; then
                    echo -e "  ${GREEN}[OK] '$RMUSER' removed from '$RMGROUP'.${NC}"
                    echo -e "  ${DIM}Groups: $(id -Gn "$RMUSER" 2>/dev/null | tr ' ' ',')${NC}"
                else
                    echo -e "  ${RED}[ERR] Failed. User may not be in that group.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                ;;
            3)
                clear
                sep_top; row "      Set User Permission (sudo)"; sep_bot; echo ""
                echo -ne "  ${YELLOW}Username: ${NC}"; read -r PERMUSER
                [ -z "$PERMUSER" ] && continue
                if ! id "$PERMUSER" &>/dev/null; then
                    echo -e "  ${RED}User '$PERMUSER' not found.${NC}"; sleep 2; continue
                fi
                echo ""
                echo -e "  ${CYAN}Current sudoers rule for '$PERMUSER':${NC}"
                if [ -f "/etc/sudoers.d/${PERMUSER}" ]; then
                    cat "/etc/sudoers.d/${PERMUSER}" 2>/dev/null | while IFS= read -r l; do echo "  $l"; done
                else
                    echo -e "  ${DIM}No sudoers rule found.${NC}"
                fi
                echo ""
                echo -e "  ${CYAN}Set permission:${NC}"
                echo -e "   1. Full sudo (ALL commands)"
                echo -e "   2. Custom commands (NOPASSWD)"
                echo -e "   3. Read-only (no sudo) — remove rule"
                echo -e "   4. Docker access"
                echo -e "   5. Remove all sudoers rules"
                echo -ne "\n  ${YELLOW}> Select: ${NC}"
                read -n 1 UPERM; echo ""
                case $UPERM in
                    1)
                        echo "${PERMUSER} ALL=(ALL:ALL) ALL" > "/etc/sudoers.d/${PERMUSER}" 2>/dev/null && \
                            echo -e "  ${GREEN}[OK] Full sudo granted to '$PERMUSER'.${NC}" || \
                            echo -e "  ${RED}[ERR] Failed.${NC}" ;;
                    2)
                        echo -ne "  ${YELLOW}Commands (e.g. /bin/systemctl,/usr/bin/apt): ${NC}"; read -r UCMDS
                        if [ -z "$UCMDS" ]; then
                            echo -e "  ${RED}Empty. Skipped.${NC}"
                        else
                            echo "${PERMUSER} ALL=(ALL) NOPASSWD: ${UCMDS}" > "/etc/sudoers.d/${PERMUSER}" 2>/dev/null && \
                                echo -e "  ${GREEN}[OK] Custom rule applied.${NC}" || \
                                echo -e "  ${RED}[ERR] Failed.${NC}"
                        fi ;;
                    3)
                        rm -f "/etc/sudoers.d/${PERMUSER}" 2>/dev/null
                        echo -e "  ${GREEN}[OK] '$PERMUSER' set to no sudo.${NC}" ;;
                    4)
                        echo "${PERMUSER} ALL=(ALL) NOPASSWD: /usr/bin/docker" > "/etc/sudoers.d/${PERMUSER}_docker" 2>/dev/null && \
                            echo -e "  ${GREEN}[OK] Docker access granted to '$PERMUSER'.${NC}" || \
                            echo -e "  ${RED}[ERR] Failed.${NC}" ;;
                    5)
                        rm -f "/etc/sudoers.d/${PERMUSER}" "/etc/sudoers.d/${PERMUSER}_docker" 2>/dev/null
                        echo -e "  ${GREEN}[OK] All sudoers rules removed for '$PERMUSER'.${NC}" ;;
                    *) echo -e "  ${DIM}Cancelled.${NC}" ;;
                esac
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                ;;
            4)
                clear
                sep_top; row "           Change Username"; sep_bot; echo ""
                echo -ne "  ${YELLOW}Current username : ${NC}"; read -r OLD_UNAME
                [ -z "$OLD_UNAME" ] && continue
                if ! id "$OLD_UNAME" &>/dev/null; then
                    echo -e "  ${RED}User '$OLD_UNAME' not found.${NC}"; sleep 2; continue
                fi
                if [ "$OLD_UNAME" = "root" ]; then
                    echo -e "  ${RED}[ERR] Cannot rename root.${NC}"; sleep 2; continue
                fi
                echo -ne "  ${YELLOW}New username     : ${NC}"; read -r NEW_UNAME
                [ -z "$NEW_UNAME" ] && echo -e "  ${RED}Cancelled.${NC}" && sleep 1 && continue
                if ! echo "$NEW_UNAME" | grep -qE '^[a-z_][a-z0-9_-]{0,31}$'; then
                    echo -e "  ${RED}Invalid username. Use lowercase letters, numbers, _ or -.${NC}"
                    sleep 2; continue
                fi
                if id "$NEW_UNAME" &>/dev/null; then
                    echo -e "  ${RED}Username '$NEW_UNAME' already taken.${NC}"; sleep 2; continue
                fi
                # Rename user and home directory
                usermod -l "$NEW_UNAME" "$OLD_UNAME" 2>/dev/null && \
                    usermod -d "/home/${NEW_UNAME}" -m "$NEW_UNAME" 2>/dev/null
                if id "$NEW_UNAME" &>/dev/null; then
                    # Also rename primary group if it matches old username
                    if getent group "$OLD_UNAME" &>/dev/null; then
                        groupmod -n "$NEW_UNAME" "$OLD_UNAME" 2>/dev/null && \
                            echo -e "  ${DIM}[OK] Primary group renamed to '$NEW_UNAME'.${NC}" || true
                    fi
                    echo -e "  ${GREEN}[OK] Username changed: '$OLD_UNAME' → '$NEW_UNAME'.${NC}"
                else
                    echo -e "  ${RED}[ERR] Failed to rename user.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                ;;
            5)
                clear
                sep_top; row "           Change Password"; sep_bot; echo ""
                echo -ne "  ${YELLOW}Username : ${NC}"; read -r CHPASS_USER
                [ -z "$CHPASS_USER" ] && continue
                if ! id "$CHPASS_USER" &>/dev/null; then
                    echo -e "  ${RED}User '$CHPASS_USER' not found.${NC}"; sleep 2; continue
                fi
                echo -ne "  ${YELLOW}New password : ${NC}"; read -rs CHPASS_NEW; echo ""
                [ -z "$CHPASS_NEW" ] && echo -e "  ${RED}Cancelled.${NC}" && sleep 1 && continue
                echo -ne "  ${YELLOW}Confirm      : ${NC}"; read -rs CHPASS_CONF; echo ""
                if [ "$CHPASS_NEW" != "$CHPASS_CONF" ]; then
                    echo -e "  ${RED}[ERR] Passwords do not match.${NC}"; sleep 2; continue
                fi
                if echo "${CHPASS_USER}:${CHPASS_NEW}" | chpasswd 2>/dev/null; then
                    echo -e "  ${GREEN}[OK] Password changed for '$CHPASS_USER'.${NC}"
                else
                    echo -e "  ${RED}[ERR] Failed to change password.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                ;;
            6)
                clear
                sep_top; row "            Change Shell"; sep_bot; echo ""
                echo -ne "  ${YELLOW}Username : ${NC}"; read -r CHSH_USER
                [ -z "$CHSH_USER" ] && continue
                if ! id "$CHSH_USER" &>/dev/null; then
                    echo -e "  ${RED}User '$CHSH_USER' not found.${NC}"; sleep 2; continue
                fi
                CUR_SHELL=$(getent passwd "$CHSH_USER" | cut -d: -f7)
                echo -e "  ${DIM}Current shell: ${CUR_SHELL}${NC}"
                echo ""
                echo -e "   1. /bin/bash"
                echo -e "   2. /bin/sh"
                echo -e "   3. /usr/sbin/nologin  (disable login)"
                echo -e "   4. /bin/false          (disable login)"
                echo -e "   5. Custom path"
                echo -ne "\n  ${YELLOW}> Select: ${NC}"
                read -n 1 SHOPT; echo ""
                case $SHOPT in
                    1) NEW_SHELL="/bin/bash" ;;
                    2) NEW_SHELL="/bin/sh" ;;
                    3) NEW_SHELL="/usr/sbin/nologin" ;;
                    4) NEW_SHELL="/bin/false" ;;
                    5)
                        echo -ne "  ${YELLOW}Shell path: ${NC}"; read -r NEW_SHELL
                        [ -z "$NEW_SHELL" ] && echo -e "  ${DIM}Cancelled.${NC}" && sleep 1 && continue ;;
                    *) echo -e "  ${DIM}Cancelled.${NC}"; sleep 1; continue ;;
                esac
                if usermod -s "$NEW_SHELL" "$CHSH_USER" 2>/dev/null; then
                    echo -e "  ${GREEN}[OK] Shell set to '$NEW_SHELL' for '$CHSH_USER'.${NC}"
                else
                    echo -e "  ${RED}[ERR] Failed. Shell path may not exist.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                ;;
            7)
                clear
                sep_top; row "        Enable / Disable User"; sep_bot; echo ""
                echo -ne "  ${YELLOW}Username : ${NC}"; read -r TGUSER
                [ -z "$TGUSER" ] && continue
                if ! id "$TGUSER" &>/dev/null; then
                    echo -e "  ${RED}User '$TGUSER' not found.${NC}"; sleep 2; continue
                fi
                if [ "$TGUSER" = "root" ]; then
                    echo -e "  ${RED}[ERR] Cannot disable root.${NC}"; sleep 2; continue
                fi
                if [ "$TGUSER" = "$(whoami)" ]; then
                    echo -e "  ${RED}[ERR] Cannot disable yourself.${NC}"; sleep 2; continue
                fi
                # Check current lock status
                LOCK_STATUS=$(passwd -S "$TGUSER" 2>/dev/null | awk '{print $2}')
                echo ""
                if [ "$LOCK_STATUS" = "L" ] || [ "$LOCK_STATUS" = "LK" ]; then
                    rowc 44 "  Status : ${RED}● Disabled (locked)${NC}"
                else
                    rowc 46 "  Status : ${GREEN}● Enabled (active)${NC}"
                fi
                echo ""
                echo -e "   1. Enable user  (unlock)"
                echo -e "   2. Disable user (lock)"
                echo -ne "\n  ${YELLOW}> Select: ${NC}"
                read -n 1 TGOPT; echo ""
                case $TGOPT in
                    1)
                        if usermod -U "$TGUSER" 2>/dev/null && usermod -s /bin/bash "$TGUSER" 2>/dev/null; then
                            echo -e "  ${GREEN}[OK] User '$TGUSER' has been enabled.${NC}"
                        else
                            echo -e "  ${RED}[ERR] Failed to enable user.${NC}"
                        fi ;;
                    2)
                        pkill -9 -u "$TGUSER" 2>/dev/null || true
                        if usermod -L "$TGUSER" 2>/dev/null && usermod -s /usr/sbin/nologin "$TGUSER" 2>/dev/null; then
                            echo -e "  ${GREEN}[OK] User '$TGUSER' has been disabled.${NC}"
                            echo -e "  ${DIM}Active sessions terminated.${NC}"
                        else
                            echo -e "  ${RED}[ERR] Failed to disable user.${NC}"
                        fi ;;
                    *) echo -e "  ${DIM}Cancelled.${NC}" ;;
                esac
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                ;;
            0) return ;;
            *) echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# ── 5c. Modify Group — create/delete & permission management ───────
modify_group() {
    while true; do
        clear
        sep_top
        row "$(printf '%*s%s' $(( (W - 12) / 2 )) '' 'Modify Group')"
        sep_mid
        row ""
        row "   1.  Create Group"
        row "   2.  Remove Group"
        row "   3.  Set Group Permissions"
        row "   4.  List Groups & Permissions"
        row "   0.  Back"
        row ""
        sep_bot
        echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"
        read -r MGOPT; echo ""

        case $MGOPT in
            1)
                clear
                sep_top; row "           Create Group"; sep_bot; echo ""
                echo -ne "  ${YELLOW}Group name: ${NC}"; read -r NEWGROUP
                [ -z "$NEWGROUP" ] && continue
                if getent group "$NEWGROUP" &>/dev/null; then
                    echo -e "  ${YELLOW}[!] Group '$NEWGROUP' already exists.${NC}"
                else
                    groupadd "$NEWGROUP" 2>/dev/null && \
                        echo -e "  ${GREEN}[OK] Group '$NEWGROUP' created.${NC}" || \
                        { echo -e "  ${RED}[ERR] Failed. Are you root?${NC}"; echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1; continue; }
                fi
                echo ""
                echo -e "  ${CYAN}Assign permissions to group '$NEWGROUP':${NC}"
                echo -e "   1. sudo  — full admin (wheel/sudo)"
                echo -e "   2. docker — access to Docker daemon"
                echo -e "   3. www-data — web server group"
                echo -e "   4. Custom sudoers rule (specific commands)"
                echo -e "   5. No special permissions"
                echo -ne "\n  ${YELLOW}> Select: ${NC}"
                read -n 1 GPERM; echo ""
                case $GPERM in
                    1)
                        if getent group sudo &>/dev/null; then
                            # Add group to sudoers via drop-in
                            echo "%${NEWGROUP} ALL=(ALL:ALL) ALL" > "/etc/sudoers.d/${NEWGROUP}" 2>/dev/null && \
                                echo -e "  ${GREEN}[OK] Group '$NEWGROUP' granted sudo.${NC}" || \
                                echo -e "  ${RED}[ERR] Could not write sudoers rule.${NC}"
                        else
                            echo -e "  ${YELLOW}[!] sudo group not found; added sudoers rule.${NC}"
                            echo "%${NEWGROUP} ALL=(ALL:ALL) ALL" > "/etc/sudoers.d/${NEWGROUP}" 2>/dev/null
                        fi ;;
                    2)
                        if getent group docker &>/dev/null; then
                            # Allow group members to run docker by making newgroup a docker supplementary link via sudoers
                            echo "%${NEWGROUP} ALL=(ALL) NOPASSWD: /usr/bin/docker" > "/etc/sudoers.d/${NEWGROUP}_docker" 2>/dev/null && \
                                echo -e "  ${GREEN}[OK] Group '$NEWGROUP' granted docker (via sudoers).${NC}" || \
                                echo -e "  ${RED}[ERR] Failed.${NC}"
                        else
                            echo -e "  ${YELLOW}[!] Docker not installed; no docker group found.${NC}"
                        fi ;;
                    3)
                        usermod -aG www-data "$NEWGROUP" 2>/dev/null || true
                        echo -e "  ${GREEN}[OK] Group '$NEWGROUP' associated with www-data.${NC}"
                        echo -e "  ${DIM}(Add users to '$NEWGROUP' for web server access)${NC}" ;;
                    4)
                        echo -ne "  ${YELLOW}Allowed commands (e.g. /bin/systemctl): ${NC}"; read -r GCMDS
                        if [ -z "$GCMDS" ]; then
                            echo -e "  ${RED}Empty. Skipped.${NC}"
                        else
                            echo "%${NEWGROUP} ALL=(ALL) NOPASSWD: ${GCMDS}" > "/etc/sudoers.d/${NEWGROUP}" 2>/dev/null && \
                                echo -e "  ${GREEN}[OK] Sudoers rule created for '$NEWGROUP'.${NC}" || \
                                echo -e "  ${RED}[ERR] Failed.${NC}"
                        fi ;;
                    *)
                        echo -e "  ${DIM}No permissions assigned.${NC}" ;;
                esac
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            2)
                clear
                sep_top; row "           Remove Group"; sep_bot; echo ""
                echo -ne "  ${YELLOW}Group name to remove: ${NC}"; read -r DELGROUP
                [ -z "$DELGROUP" ] && continue
                if ! getent group "$DELGROUP" &>/dev/null; then
                    echo -e "  ${RED}Group '$DELGROUP' not found.${NC}"; sleep 2; continue
                fi
                echo -ne "  ${RED}Remove group '$DELGROUP'? (y/N): ${NC}"; read -n 1 CONFIRM; echo ""
                if [[ "$CONFIRM" = "y" || "$CONFIRM" = "Y" ]]; then
                    groupdel "$DELGROUP" 2>/dev/null && \
                        echo -e "  ${GREEN}[OK] Group '$DELGROUP' removed.${NC}" || \
                        echo -e "  ${RED}[ERR] Failed.${NC}"
                    rm -f "/etc/sudoers.d/${DELGROUP}" "/etc/sudoers.d/${DELGROUP}_docker" 2>/dev/null
                else
                    echo -e "  ${DIM}Cancelled.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            3)
                clear
                sep_top; row "       Set Group Permissions"; sep_bot; echo ""
                echo -e "  ${CYAN}Custom groups:${NC}"
                awk -F: '$3>=1000{printf "  %-20s GID: %s  Members: %s\n",$1,$3,$4}' /etc/group 2>/dev/null
                echo ""
                echo -ne "  ${YELLOW}Group name: ${NC}"; read -r PERMGROUP
                [ -z "$PERMGROUP" ] && continue
                if ! getent group "$PERMGROUP" &>/dev/null; then
                    echo -e "  ${RED}Group '$PERMGROUP' not found.${NC}"; sleep 2; continue
                fi
                echo ""
                echo -e "  ${CYAN}Current sudoers rule for '$PERMGROUP':${NC}"
                if [ -f "/etc/sudoers.d/${PERMGROUP}" ]; then
                    cat "/etc/sudoers.d/${PERMGROUP}" 2>/dev/null | while IFS= read -r l; do echo "  $l"; done
                else
                    echo -e "  ${DIM}No sudoers rule found.${NC}"
                fi
                echo ""
                echo -e "  ${CYAN}Set permission:${NC}"
                echo -e "   1. Full sudo (ALL commands)"
                echo -e "   2. Custom commands (NOPASSWD)"
                echo -e "   3. Read-only (no sudo) — remove rule"
                echo -e "   4. Docker access"
                echo -e "   5. Remove all sudoers rules"
                echo -ne "\n  ${YELLOW}> Select: ${NC}"
                read -n 1 SPERM; echo ""
                case $SPERM in
                    1)
                        echo "%${PERMGROUP} ALL=(ALL:ALL) ALL" > "/etc/sudoers.d/${PERMGROUP}" 2>/dev/null && \
                            echo -e "  ${GREEN}[OK] Full sudo granted to '$PERMGROUP'.${NC}" || \
                            echo -e "  ${RED}[ERR] Failed.${NC}" ;;
                    2)
                        echo -ne "  ${YELLOW}Commands (e.g. /bin/systemctl,/usr/bin/apt): ${NC}"; read -r SCMDS
                        if [ -z "$SCMDS" ]; then
                            echo -e "  ${RED}Empty. Skipped.${NC}"
                        else
                            echo "%${PERMGROUP} ALL=(ALL) NOPASSWD: ${SCMDS}" > "/etc/sudoers.d/${PERMGROUP}" 2>/dev/null && \
                                echo -e "  ${GREEN}[OK] Custom rule applied.${NC}" || \
                                echo -e "  ${RED}[ERR] Failed.${NC}"
                        fi ;;
                    3)
                        rm -f "/etc/sudoers.d/${PERMGROUP}" 2>/dev/null
                        echo -e "  ${GREEN}[OK] '$PERMGROUP' set to no sudo.${NC}" ;;
                    4)
                        echo "%${PERMGROUP} ALL=(ALL) NOPASSWD: /usr/bin/docker" > "/etc/sudoers.d/${PERMGROUP}_docker" 2>/dev/null && \
                            echo -e "  ${GREEN}[OK] Docker access granted to '$PERMGROUP'.${NC}" || \
                            echo -e "  ${RED}[ERR] Failed.${NC}" ;;
                    5)
                        rm -f "/etc/sudoers.d/${PERMGROUP}" "/etc/sudoers.d/${PERMGROUP}_docker" 2>/dev/null
                        echo -e "  ${GREEN}[OK] All sudoers rules removed for '$PERMGROUP'.${NC}" ;;
                    *) echo -e "  ${DIM}Cancelled.${NC}" ;;
                esac
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                ;;
            4)
                clear
                sep_top; row "       List Groups & Permissions"; sep_mid
                echo ""
                printf "  ${CYAN}%-20s %-6s %-s${NC}\n" "GROUP" "GID" "MEMBERS"
                printf "  %s\n" "$(printf '%.0s-' {1..50})"
                while IFS=: read -r GNAME _ GGID GMEMBERS; do
                    if [ "${GGID:-0}" -ge 1000 ] 2>/dev/null || \
                       echo "sudo docker www-data wheel" | grep -qw "$GNAME"; then
                        SUDOERS_TAG=""
                        [ -f "/etc/sudoers.d/${GNAME}" ] && SUDOERS_TAG=" ${YELLOW}[sudo]${NC}"
                        # Build full member list: combine /etc/group members + users whose primary group matches
                        PRIMARY_MEMBERS=$(awk -F: -v gid="$GGID" '$4==gid{print $1}' /etc/passwd 2>/dev/null | tr '\n' ',' | sed 's/,$//')
                        ALL_MEMBERS="${GMEMBERS}"
                        [ -n "$PRIMARY_MEMBERS" ] && [ -n "$ALL_MEMBERS" ] && ALL_MEMBERS="${ALL_MEMBERS},${PRIMARY_MEMBERS}"
                        [ -z "$ALL_MEMBERS" ] && ALL_MEMBERS="$PRIMARY_MEMBERS"
                        [ -z "$ALL_MEMBERS" ] && ALL_MEMBERS="<none>"
                        printf "  %-20s %-6s " "${GNAME:0:19}" "$GGID"
                        echo -e "${ALL_MEMBERS}${SUDOERS_TAG}"
                    fi
                done < /etc/group 2>/dev/null
                echo ""
                echo -e "  ${CYAN}[Sudoers drop-in files (/etc/sudoers.d/)]${NC}"
                ls /etc/sudoers.d/ 2>/dev/null | grep -v "README" | while read -r f; do
                    echo -e "  ${DIM}$f:${NC}"
                    cat "/etc/sudoers.d/$f" 2>/dev/null | while IFS= read -r l; do echo "    $l"; done
                done
                echo ""; echo -ne "  ${DIM}Press any key...${NC}"; read -n 1
                ;;
            0) return ;;
            *) echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# ── 6. Fail2ban Manager ──────────────────────────────────────────
fail2ban_manager() {
    while true; do
        clear
        sep_top
        row "$(printf '%*s%s' $(( (W - 17) / 2 )) '' 'Fail2ban Manager')"
        sep_mid

        if ! command -v fail2ban-client &>/dev/null; then
            blank
            rowc 38 "  ${RED}!! Fail2ban is not installed !!${NC}"
            blank
            sep_mid
            row "   1.  Install & Enable Fail2ban"
            row "   0.  Back"
            blank
            sep_bot
            echo ""
            echo -ne "  ${YELLOW}> Select option: ${NC}"
            read -n 1 FOPT; echo ""
            case $FOPT in
                1)
                    echo -e "\n  ${CYAN}[*] Installing fail2ban...${NC}\n"
                    if command -v apt &>/dev/null; then
                        apt update && apt install -y fail2ban
                    elif command -v yum &>/dev/null; then
                        yum install -y fail2ban
                    elif command -v dnf &>/dev/null; then
                        dnf install -y fail2ban
                    else
                        echo -e "  ${RED}[ERR] No supported package manager found.${NC}"
                        echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1; continue
                    fi
                    systemctl enable fail2ban 2>/dev/null && systemctl start fail2ban 2>/dev/null
                    if command -v fail2ban-client &>/dev/null; then
                        echo -e "\n  ${GREEN}[OK] Fail2ban installed and started.${NC}"
                    else
                        echo -e "\n  ${RED}[ERR] Installation may have failed.${NC}"
                    fi
                    echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                    ;;
                0) return ;;
            esac
            continue
        fi

        # Status
        F2B_STATUS=$(systemctl is-active fail2ban 2>/dev/null || echo "unknown")
        F2B_ENABLED=$(systemctl is-enabled fail2ban 2>/dev/null || echo "unknown")

        # Banned counts — graceful if jail not found
        BANNED_COUNT=0; TOTAL_BAN=0
        if [ "$F2B_STATUS" = "active" ]; then
            BANNED_COUNT=$(fail2ban-client status sshd 2>/dev/null \
                | grep -i "banned ip" | awk -F: '{print $2}' | wc -w || echo 0)
            TOTAL_BAN=$(fail2ban-client status sshd 2>/dev/null \
                | grep -i "total banned" | awk '{print $NF}' || echo 0)
        fi

        blank
        if [ "$F2B_STATUS" = "active" ]; then
            rowc 34 "  Status  : ${GREEN}Active${NC}"
        else
            rowc 36 "  Status  : ${RED}Inactive${NC}"
        fi
        if [ "$F2B_ENABLED" = "enabled" ]; then
            rowc 31 "  Enabled : ${GREEN}Yes (auto-start on)${NC}"
        elif [ "$F2B_ENABLED" = "disabled" ]; then
            rowc 39 "  Enabled : ${RED}No  (auto-start off)${NC}"
        else
            rowc 14 "  Enabled : ${YELLOW}${F2B_ENABLED}${NC}"
        fi
        row "  Banned IPs (SSH)  : ${BANNED_COUNT:-0}"
        row "  Total Bans (SSH)  : ${TOTAL_BAN:-0}"
        blank
        sep_mid
        blank
        row "   1.  Show Status (all jails)"
        row "   2.  Show Banned IPs (SSH)"
        row "   3.  Unban an IP"
        row "   4.  Ban an IP manually"
        if [ "$F2B_STATUS" = "active" ]; then
            row "   5.  Stop Fail2ban"
        else
            row "   5.  Start Fail2ban"
        fi
        row "   6.  Restart Fail2ban"
        row "   7.  Uninstall Fail2ban"
        row "   0.  Back"
        blank
        sep_bot
        echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"
        read -n 1 FOPT; echo ""

        case $FOPT in
            1)
                echo ""
                fail2ban-client status 2>/dev/null || \
                    echo -e "  ${RED}[ERR] fail2ban-client not responding.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                ;;
            2)
                echo ""
                echo -e "  ${CYAN}Banned IPs in [sshd]:${NC}"
                BIPS=$(fail2ban-client status sshd 2>/dev/null | grep -i "banned ip" | cut -d: -f2)
                if [ -z "$BIPS" ]; then
                    echo -e "  ${DIM}No banned IPs or sshd jail not active.${NC}"
                else
                    echo "$BIPS"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                ;;
            3)
                clear
                sep_top; row "         Unban IP Addresses"; sep_mid; blank
                row "  Enter IPs one by one. Leave empty to finish."
                blank; sep_bot; echo ""
                while true; do
                    echo -ne "  ${YELLOW}IP to unban (or Enter to finish): ${NC}"; read -r UNBAN_IP
                    [ -z "$UNBAN_IP" ] && break
                    if fail2ban-client set sshd unbanip "$UNBAN_IP" 2>/dev/null; then
                        echo -e "  ${GREEN}[OK] '$UNBAN_IP' unbanned.${NC}"
                    else
                        echo -e "  ${YELLOW}[!] Could not unban '$UNBAN_IP' (may not be banned).${NC}"
                    fi
                done
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                ;;
            4)
                clear
                sep_top; row "          Ban IP Addresses"; sep_mid; blank
                row "  Enter IPs one by one. Leave empty to finish."
                blank; sep_bot; echo ""
                while true; do
                    echo -ne "  ${YELLOW}IP to ban (or Enter to finish): ${NC}"; read -r BAN_IP
                    [ -z "$BAN_IP" ] && break
                    if fail2ban-client set sshd banip "$BAN_IP" 2>/dev/null; then
                        echo -e "  ${GREEN}[OK] '$BAN_IP' banned.${NC}"
                    else
                        echo -e "  ${YELLOW}[!] Could not ban '$BAN_IP'.${NC}"
                    fi
                done
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                ;;
            5)
                if [ "$F2B_STATUS" = "active" ]; then
                    systemctl stop fail2ban 2>/dev/null && \
                        echo -e "  ${YELLOW}[OK] Fail2ban stopped.${NC}" || \
                        echo -e "  ${RED}[ERR] Could not stop.${NC}"
                else
                    systemctl start fail2ban 2>/dev/null && \
                        echo -e "  ${GREEN}[OK] Fail2ban started.${NC}" || \
                        echo -e "  ${RED}[ERR] Could not start.${NC}"
                fi
                sleep 2 ;;
            6)
                systemctl restart fail2ban 2>/dev/null && \
                    echo -e "  ${GREEN}[OK] Fail2ban restarted.${NC}" || \
                    echo -e "  ${RED}[ERR] Could not restart.${NC}"
                sleep 2 ;;
            7)
                echo -ne "\n  ${RED}Uninstall Fail2ban? (y/N): ${NC}"; read -n 1 CNFRM; echo ""
                if [[ "$CNFRM" = "y" || "$CNFRM" = "Y" ]]; then
                    systemctl stop fail2ban 2>/dev/null; systemctl disable fail2ban 2>/dev/null
                    if command -v apt &>/dev/null; then
                        apt remove -y fail2ban 2>/dev/null; apt autoremove -y 2>/dev/null
                    elif command -v yum &>/dev/null; then
                        yum remove -y fail2ban 2>/dev/null
                    elif command -v dnf &>/dev/null; then
                        dnf remove -y fail2ban 2>/dev/null
                    fi
                    echo -e "  ${GREEN}[OK] Fail2ban removed.${NC}"
                    echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1; return
                else
                    echo -e "  ${DIM}Cancelled.${NC}"; sleep 1
                fi ;;
            0) return ;;
            *) echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# ── 7. Port Manager ──────────────────────────────────────────────
port_manager() {

    # Detect available tool: ss preferred, fallback netstat
    _ss_listen() {
        if command -v ss &>/dev/null; then
            ss -tlnup 2>/dev/null | tail -n +2
        elif command -v netstat &>/dev/null; then
            netstat -tlnup 2>/dev/null | tail -n +3
        fi
    }
    _ss_all() {
        if command -v ss &>/dev/null; then
            ss -tunap 2>/dev/null | tail -n +2
        elif command -v netstat &>/dev/null; then
            netstat -tunap 2>/dev/null | tail -n +3
        fi
    }

    _get_pname() {
        local PROC="$1"
        local PID
        PID=$(echo "$PROC" | grep -oE 'pid=[0-9]+' | cut -d= -f2)
        if [ -n "$PID" ]; then
            ps -p "$PID" -o comm= 2>/dev/null || echo ""
        else
            # netstat style: PID/name
            echo "$PROC" | grep -oE '[0-9]+/[^ ]+' | cut -d/ -f2 | head -1
        fi
    }

    _show_port_header() {
        printf "  %-8s %-22s %-12s %s\n" "PROTO" "LOCAL ADDR" "STATE" "PROCESS"
        printf "  %s\n" "$(printf '%.0s-' {1..54})"
    }
    _show_conn_header() {
        printf "  %-6s %-21s %-21s %-12s %s\n" "PROTO" "LOCAL" "PEER" "STATE" "PROCESS"
        printf "  %s\n" "$(printf '%.0s-' {1..72})"
    }

    while true; do
        clear
        sep_top
        row "$(printf '%*s%s' $(( (W - 14) / 2 )) '' 'Port Manager')"
        sep_mid
        blank
        row "   1.  Open Ports (firewall / listening)"
        row "   2.  Ports In Use (active connections)"
        row "   3.  Search by port number"
        row "   4.  Search by process name"
        row "   5.  Port Inspector (full detail)"
        row "   0.  Back"
        blank
        sep_bot
        echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"
        read -n 1 POPT; echo ""

        case $POPT in
            1)
                clear; sep_top; row "         Open Ports (Firewall)"; sep_mid; echo ""
                if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
                    echo -e "  ${CYAN}[UFW Rules]${NC}\n"
                    ufw status numbered 2>/dev/null | grep -v "^Status" | grep -v "^$" | \
                        awk '{printf "  %s\n", $0}'
                    echo ""
                elif command -v iptables &>/dev/null; then
                    echo -e "  ${CYAN}[iptables ACCEPT rules]${NC}\n"
                    iptables -L INPUT -n --line-numbers 2>/dev/null | grep -i "ACCEPT" | \
                        awk '{printf "  %s\n", $0}'
                    echo ""
                else
                    echo -e "  ${YELLOW}[!] No active firewall (ufw/iptables).${NC}\n"
                fi
                echo -e "  ${CYAN}[Listening Ports]${NC}\n"
                _show_port_header
                _ss_listen | while read -r line; do
                    PROTO=$(echo "$line" | awk '{print $1}')
                    STATE=$(echo "$line" | awk '{print $2}')
                    LOCAL=$(echo "$line" | awk '{print $4}')
                    [ -z "$LOCAL" ] && LOCAL=$(echo "$line" | awk '{print $3}')
                    PNAME=$(_get_pname "$(echo "$line" | awk '{print $NF}')")
                    printf "  %-8s %-22s %-12s %s\n" "$PROTO" "${LOCAL:0:21}" "$STATE" "$PNAME"
                done
                echo ""; echo -ne "  ${DIM}Press any key...${NC}"; read -n 1
                ;;
            2)
                clear; sep_top; row "      Ports In Use (Active Connections)"; sep_mid; echo ""
                echo -e "  ${CYAN}[Active TCP/UDP Connections]${NC}\n"
                _show_conn_header
                _ss_all | while read -r line; do
                    PROTO=$(echo "$line" | awk '{print $1}')
                    STATE=$(echo "$line" | awk '{print $2}')
                    LOCAL=$(echo "$line" | awk '{print $5}')
                    PEER=$(echo "$line"  | awk '{print $6}')
                    [ -z "$LOCAL" ] && LOCAL=$(echo "$line" | awk '{print $4}')
                    [ -z "$PEER"  ] && PEER=$(echo "$line"  | awk '{print $5}')
                    PNAME=$(_get_pname "$(echo "$line" | awk '{print $NF}')")
                    printf "  %-6s %-21s %-21s %-12s %s\n" \
                        "$PROTO" "${LOCAL:0:20}" "${PEER:0:20}" "$STATE" "$PNAME"
                done
                echo ""; echo -ne "  ${DIM}Press any key...${NC}"; read -n 1
                ;;
            3)
                clear; sep_top; row "       Search by Port Number"; sep_mid; echo ""
                echo -ne "  ${YELLOW}Port number to search: ${NC}"; read -r SRCH_PORT
                [ -z "$SRCH_PORT" ] && continue
                echo ""
                echo -e "  ${CYAN}[Listening on :${SRCH_PORT}]${NC}\n"
                _show_port_header
                FOUND_L=0
                while read -r line; do
                    LOCAL=$(echo "$line" | awk '{print $4}')
                    [ -z "$LOCAL" ] && LOCAL=$(echo "$line" | awk '{print $3}')
                    PORT_NUM=$(echo "$LOCAL" | rev | cut -d: -f1 | rev)
                    if [ "$PORT_NUM" = "$SRCH_PORT" ]; then
                        PROTO=$(echo "$line" | awk '{print $1}')
                        STATE=$(echo "$line" | awk '{print $2}')
                        PNAME=$(_get_pname "$(echo "$line" | awk '{print $NF}')")
                        printf "  %-8s %-22s %-12s %s\n" "$PROTO" "${LOCAL:0:21}" "$STATE" "$PNAME"
                        FOUND_L=1
                    fi
                done < <(_ss_listen)
                [ "$FOUND_L" -eq 0 ] && echo -e "  ${DIM}Nothing listening on port ${SRCH_PORT}.${NC}"
                echo ""
                echo -e "  ${CYAN}[Active connections on :${SRCH_PORT}]${NC}\n"
                _show_conn_header
                FOUND_C=0
                while read -r line; do
                    LOCAL=$(echo "$line" | awk '{print $5}')
                    PEER=$(echo "$line"  | awk '{print $6}')
                    [ -z "$LOCAL" ] && LOCAL=$(echo "$line" | awk '{print $4}')
                    [ -z "$PEER"  ] && PEER=$(echo "$line"  | awk '{print $5}')
                    LPORT=$(echo "$LOCAL" | rev | cut -d: -f1 | rev)
                    PPORT=$(echo "$PEER"  | rev | cut -d: -f1 | rev)
                    if [ "$LPORT" = "$SRCH_PORT" ] || [ "$PPORT" = "$SRCH_PORT" ]; then
                        PROTO=$(echo "$line" | awk '{print $1}')
                        STATE=$(echo "$line" | awk '{print $2}')
                        PNAME=$(_get_pname "$(echo "$line" | awk '{print $NF}')")
                        printf "  %-6s %-21s %-21s %-12s %s\n" \
                            "$PROTO" "${LOCAL:0:20}" "${PEER:0:20}" "$STATE" "$PNAME"
                        FOUND_C=1
                    fi
                done < <(_ss_all)
                [ "$FOUND_C" -eq 0 ] && echo -e "  ${DIM}No active connections on port ${SRCH_PORT}.${NC}"
                echo ""; echo -ne "  ${DIM}Press any key...${NC}"; read -n 1
                ;;
            4)
                clear; sep_top; row "       Search by Process Name"; sep_mid; echo ""
                echo -ne "  ${YELLOW}Process name to search: ${NC}"; read -r SRCH_PROC
                [ -z "$SRCH_PROC" ] && continue
                echo ""
                echo -e "  ${CYAN}[Listening sockets for '${SRCH_PROC}']${NC}\n"
                _show_port_header
                FOUND_L=0
                while read -r line; do
                    PNAME=$(_get_pname "$(echo "$line" | awk '{print $NF}')")
                    if echo "$PNAME" | grep -qi "$SRCH_PROC" 2>/dev/null; then
                        PROTO=$(echo "$line" | awk '{print $1}')
                        STATE=$(echo "$line" | awk '{print $2}')
                        LOCAL=$(echo "$line" | awk '{print $4}')
                        [ -z "$LOCAL" ] && LOCAL=$(echo "$line" | awk '{print $3}')
                        printf "  %-8s %-22s %-12s %s\n" "$PROTO" "${LOCAL:0:21}" "$STATE" "$PNAME"
                        FOUND_L=1
                    fi
                done < <(_ss_listen)
                [ "$FOUND_L" -eq 0 ] && echo -e "  ${DIM}No listening ports for '${SRCH_PROC}'.${NC}"
                echo ""
                echo -e "  ${CYAN}[Active connections for '${SRCH_PROC}']${NC}\n"
                _show_conn_header
                FOUND_C=0
                while read -r line; do
                    PNAME=$(_get_pname "$(echo "$line" | awk '{print $NF}')")
                    if echo "$PNAME" | grep -qi "$SRCH_PROC" 2>/dev/null; then
                        PROTO=$(echo "$line" | awk '{print $1}')
                        STATE=$(echo "$line" | awk '{print $2}')
                        LOCAL=$(echo "$line" | awk '{print $5}')
                        PEER=$(echo "$line"  | awk '{print $6}')
                        [ -z "$LOCAL" ] && LOCAL=$(echo "$line" | awk '{print $4}')
                        [ -z "$PEER"  ] && PEER=$(echo "$line"  | awk '{print $5}')
                        printf "  %-6s %-21s %-21s %-12s %s\n" \
                            "$PROTO" "${LOCAL:0:20}" "${PEER:0:20}" "$STATE" "$PNAME"
                        FOUND_C=1
                    fi
                done < <(_ss_all)
                [ "$FOUND_C" -eq 0 ] && echo -e "  ${DIM}No active connections for '${SRCH_PROC}'.${NC}"
                echo ""; echo -ne "  ${DIM}Press any key...${NC}"; read -n 1
                ;;
            5)
                clear; sep_top; row "         Port Inspector"; sep_mid; echo ""
                echo -ne "  ${YELLOW}Port number to inspect: ${NC}"; read -r INSP_PORT
                [ -z "$INSP_PORT" ] && continue
                clear; sep_top
                row "$(printf '  Port Inspector  :  %-*s' $(( W-20 )) ":${INSP_PORT}")"
                sep_mid

                echo ""
                echo -e "  ${CYAN}[Process]${NC}"
                INSP_LINE=$(_ss_listen | awk -v p=":$INSP_PORT" '$4 ~ p || $3 ~ p')
                if [ -n "$INSP_LINE" ]; then
                    INSP_PID=$(echo "$INSP_LINE" | grep -oE 'pid=[0-9]+' | cut -d= -f2 | head -1)
                    INSP_PNAME=$(ps -p "$INSP_PID" -o comm= 2>/dev/null || echo "unknown")
                    INSP_CMD=$(ps -p "$INSP_PID" -o args= 2>/dev/null | cut -c1-44 || echo "N/A")
                    printf "  %-12s: %s\n" "Process"  "${INSP_PNAME:-unknown}"
                    printf "  %-12s: %s\n" "PID"      "${INSP_PID:-N/A}"
                    printf "  %-12s: %s\n" "Command"  "${INSP_CMD:-N/A}"
                else
                    echo -e "  ${DIM}No process listening on port ${INSP_PORT}.${NC}"
                fi

                echo ""
                echo -e "  ${CYAN}[Listening Sockets]${NC}"
                printf "  %-8s %-22s %s\n" "PROTO" "LOCAL ADDR" "STATE"
                printf "  %s\n" "$(printf '%.0s-' {1..44})"
                FOUND_L=0
                while IFS= read -r line; do
                    LOCAL=$(echo "$line" | awk '{print $4}')
                    [ -z "$LOCAL" ] && LOCAL=$(echo "$line" | awk '{print $3}')
                    PORT_NUM=$(echo "$LOCAL" | rev | cut -d: -f1 | rev)
                    if [ "$PORT_NUM" = "$INSP_PORT" ]; then
                        PROTO=$(echo "$line" | awk '{print $1}')
                        STATE=$(echo "$line" | awk '{print $2}')
                        printf "  %-8s %-22s %s\n" "$PROTO" "${LOCAL:0:21}" "$STATE"
                        FOUND_L=1
                    fi
                done < <(_ss_listen)
                [ "$FOUND_L" -eq 0 ] && echo -e "  ${DIM}None${NC}"

                echo ""
                echo -e "  ${CYAN}[Active Connections]${NC}"
                printf "  %-6s %-21s %-21s %s\n" "PROTO" "LOCAL" "PEER" "STATE"
                printf "  %s\n" "$(printf '%.0s-' {1..62})"
                FOUND_C=0
                while IFS= read -r line; do
                    LOCAL=$(echo "$line" | awk '{print $5}')
                    PEER=$(echo "$line"  | awk '{print $6}')
                    [ -z "$LOCAL" ] && LOCAL=$(echo "$line" | awk '{print $4}')
                    [ -z "$PEER"  ] && PEER=$(echo "$line"  | awk '{print $5}')
                    LPORT=$(echo "$LOCAL" | rev | cut -d: -f1 | rev)
                    PPORT=$(echo "$PEER"  | rev | cut -d: -f1 | rev)
                    if [ "$LPORT" = "$INSP_PORT" ] || [ "$PPORT" = "$INSP_PORT" ]; then
                        PROTO=$(echo "$line" | awk '{print $1}')
                        STATE=$(echo "$line" | awk '{print $2}')
                        printf "  %-6s %-21s %-21s %s\n" \
                            "$PROTO" "${LOCAL:0:20}" "${PEER:0:20}" "$STATE"
                        FOUND_C=1
                    fi
                done < <(_ss_all)
                [ "$FOUND_C" -eq 0 ] && echo -e "  ${DIM}None${NC}"

                echo ""
                echo -e "  ${CYAN}[Firewall]${NC}"
                if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
                    UFW_RULE=$(ufw status 2>/dev/null | grep -w "$INSP_PORT")
                    if [ -n "$UFW_RULE" ]; then
                        echo "$UFW_RULE" | while IFS= read -r r; do echo "  $r"; done
                    else
                        echo -e "  ${YELLOW}No UFW rule for port ${INSP_PORT}.${NC}"
                    fi
                elif command -v iptables &>/dev/null; then
                    IPT_RULE=$(iptables -L INPUT -n 2>/dev/null | grep "$INSP_PORT")
                    if [ -n "$IPT_RULE" ]; then
                        echo "$IPT_RULE" | while IFS= read -r r; do echo "  $r"; done
                    else
                        echo -e "  ${DIM}No iptables rule for port ${INSP_PORT}.${NC}"
                    fi
                else
                    echo -e "  ${DIM}No firewall detected.${NC}"
                fi

                echo ""; sep_bot
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                ;;
            0) return ;;
            *) echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# ── 8. Speed Test ────────────────────────────────────────────────
speed_test() {
    while true; do
        clear
        sep_top
        row "$(printf '%*s%s' $(( (W - 14) / 2 )) '' 'Speed Test')"
        sep_mid
        blank

        ST_BIN=""
        command -v speedtest-cli &>/dev/null && ST_BIN="speedtest-cli"
        command -v speedtest     &>/dev/null && ST_BIN="speedtest"

        if [ -z "$ST_BIN" ]; then
            rowc 38 "  ${RED}!! speedtest-cli is not installed !!${NC}"
            blank
            sep_mid
            row "   1.  Install speedtest-cli (pip3)"
            row "   2.  Install speedtest-cli (apt)"
            row "   0.  Back"
            blank
            sep_bot
            echo ""
            echo -ne "  ${YELLOW}> Select option: ${NC}"
            read -n 1 SOPT; echo ""
            case $SOPT in
                1)
                    echo -e "\n  ${CYAN}[*] Installing via pip3...${NC}\n"
                    if ! command -v pip3 &>/dev/null; then
                        echo -e "  ${CYAN}[*] Installing python3-pip first...${NC}\n"
                        apt install -y python3-pip 2>/dev/null || \
                            yum install -y python3-pip 2>/dev/null || \
                            dnf install -y python3-pip 2>/dev/null
                    fi
                    pip3 install speedtest-cli 2>&1 | tail -3
                    echo -e "  ${GREEN}[OK] Done.${NC}"
                    echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                2)
                    echo -e "\n  ${CYAN}[*] Installing via apt...${NC}\n"
                    apt update 2>/dev/null && apt install -y speedtest-cli 2>/dev/null || \
                        echo -e "  ${YELLOW}[!] apt install failed. Try pip3 option.${NC}"
                    echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                0) return ;;
            esac
            continue
        fi

        row "   1.  Auto Test (nearest server)"
        row "   2.  Pick Server by ID"
        row "   3.  List Available Servers"
        row "   4.  Uninstall speedtest-cli"
        row "   0.  Back"
        blank
        sep_bot
        echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"
        read -n 1 SOPT; echo ""

        case $SOPT in
            1)
                echo -e "\n  ${CYAN}[*] Running speed test...${NC}\n"
                $ST_BIN --simple 2>&1 | while IFS= read -r line; do echo "  $line"; done || \
                    echo -e "  ${RED}[ERR] Speed test failed.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            2)
                echo -ne "\n  ${YELLOW}Server ID: ${NC}"; read -r SRV_ID
                [ -z "$SRV_ID" ] && continue
                echo -e "\n  ${CYAN}[*] Testing with server $SRV_ID...${NC}\n"
                $ST_BIN --server "$SRV_ID" --simple 2>&1 | while IFS= read -r line; do echo "  $line"; done || \
                    echo -e "  ${RED}[ERR] Speed test failed.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            3)
                echo -e "\n  ${CYAN}[*] Fetching server list...${NC}\n"
                $ST_BIN --list 2>/dev/null | head -30 | while IFS= read -r line; do echo "  $line"; done
                echo -e "\n  ${DIM}(Top 30 servers)${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            4)
                echo -ne "\n  ${RED}Uninstall speedtest-cli? (y/N): ${NC}"; read -n 1 CNFRM; echo ""
                if [[ "$CNFRM" = "y" || "$CNFRM" = "Y" ]]; then
                    pip3 uninstall speedtest-cli -y 2>/dev/null || true
                    apt remove -y speedtest-cli 2>/dev/null || true
                    echo -e "  ${GREEN}[OK] speedtest-cli removed.${NC}"
                else
                    echo -e "  ${DIM}Cancelled.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            0) return ;;
            *) echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# ── 9. SSL Certificate Checker ────────────────────────────────────
ssl_checker() {

    # Check openssl available
    if ! command -v openssl &>/dev/null; then
        clear; sep_top
        row "$(printf '%*s%s' $(( (W - 22) / 2 )) '' 'SSL Certificate Checker')"
        sep_mid; blank
        rowc 36 "  ${RED}!! openssl is not installed !!${NC}"
        blank
        row "   1.  Install openssl"
        row "   0.  Back"
        blank; sep_bot; echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"; read -n 1 OPT; echo ""
        case $OPT in
            1)
                apt install -y openssl 2>/dev/null || \
                yum install -y openssl 2>/dev/null || \
                dnf install -y openssl 2>/dev/null
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            0) return ;;
        esac
        return
    fi

    _ssl_check_domain() {
        local DOMAIN="$1"
        local CONNECT_HOST="${2:-$1}"
        local PORT="${3:-443}"
        local RESOLVED_IP="${4:-}"
        # If no resolved IP passed in, resolve now
        if [ -z "$RESOLVED_IP" ]; then
            if command -v dig &>/dev/null; then
                RESOLVED_IP=$(dig +short "$CONNECT_HOST" 2>/dev/null | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
            elif command -v getent &>/dev/null; then
                RESOLVED_IP=$(getent hosts "$CONNECT_HOST" 2>/dev/null | awk '{print $1}' | head -1)
            fi
        fi
        [ -z "$RESOLVED_IP" ] && RESOLVED_IP="N/A"

        echo -e "\n  ${CYAN}[*] Checking: ${DOMAIN} → ${RESOLVED_IP}:${PORT}${NC}\n"

        local RAW
        # Use timeout command for compatibility with all OpenSSL versions
        RAW=$(echo Q | timeout 10 openssl s_client \
            -servername "$DOMAIN" \
            -connect "${CONNECT_HOST}:${PORT}" 2>/dev/null)

        # If timeout not available, try without
        if [ -z "$RAW" ] && ! command -v timeout &>/dev/null; then
            RAW=$(echo Q | openssl s_client \
                -servername "$DOMAIN" \
                -connect "${CONNECT_HOST}:${PORT}" 2>/dev/null)
        fi

        if [ -z "$RAW" ]; then
            echo -e "  ${RED}[ERR] Could not connect to ${CONNECT_HOST}:${PORT}${NC}"
            echo -e "  ${DIM}Make sure:${NC}"
            echo -e "  ${DIM}  - Domain/IP is correct${NC}"
            echo -e "  ${DIM}  - Port $PORT is open${NC}"
            echo -e "  ${DIM}  - SSL is configured on that port${NC}"
            if [ "$CONNECT_HOST" = "$DOMAIN" ]; then
                echo -e "  ${DIM}  - If behind Cloudflare, use Option 2 with server IP${NC}"
            fi
            return
        fi

        local CERT
        CERT=$(echo "$RAW" | openssl x509 2>/dev/null)
        if [ -z "$CERT" ]; then
            echo -e "  ${RED}[ERR] Connected but no valid certificate found.${NC}"
            return
        fi

        local SUBJECT ISSUER NOT_BEFORE NOT_AFTER DAYS_LEFT SAN
        SUBJECT=$(echo "$CERT" | openssl x509 -noout -subject 2>/dev/null \
            | sed 's/subject=//' | xargs)
        ISSUER=$(echo "$CERT" | openssl x509 -noout -issuer 2>/dev/null \
            | sed 's/issuer=//' | xargs | cut -c1-34)
        NOT_BEFORE=$(echo "$CERT" | openssl x509 -noout -startdate 2>/dev/null \
            | cut -d= -f2)
        NOT_AFTER=$(echo "$CERT" | openssl x509 -noout -enddate 2>/dev/null \
            | cut -d= -f2)
        SAN=$(echo "$CERT" | openssl x509 -noout -text 2>/dev/null \
            | grep -A1 "Subject Alternative" | tail -1 \
            | tr ',' '\n' | sed 's/DNS://g;s/ //g' | head -4 | tr '\n' ' ')
        [ -z "$SAN" ] && SAN="N/A"

        DAYS_LEFT="N/A"
        if [ -n "$NOT_AFTER" ]; then
            EXPIRE_EPOCH=$(date -d "$NOT_AFTER" +%s 2>/dev/null \
                || date -j -f "%b %d %T %Y %Z" "$NOT_AFTER" +%s 2>/dev/null \
                || echo 0)
            NOW_EPOCH=$(date +%s)
            if [ "$EXPIRE_EPOCH" -gt 0 ]; then
                DAYS_LEFT=$(( (EXPIRE_EPOCH - NOW_EPOCH) / 86400 ))
            fi
        fi

        local DAY_COLOR="$GREEN"
        [[ "$DAYS_LEFT" =~ ^[0-9]+$ ]] && [ "$DAYS_LEFT" -lt 30 ] && DAY_COLOR="$YELLOW"
        [[ "$DAYS_LEFT" =~ ^[0-9]+$ ]] && [ "$DAYS_LEFT" -lt 7  ] && DAY_COLOR="$RED"

        sep_mid
        printf "  %-14s: %s\n" "Domain"     "$DOMAIN"
        printf "  %-14s: %s\n" "Server IP"  "${RESOLVED_IP}"
        printf "  %-14s: %s\n" "Subject"    "${SUBJECT:0:34}"
        printf "  %-14s: %s\n" "Issuer"     "${ISSUER:0:34}"
        printf "  %-14s: %s\n" "Valid From" "$NOT_BEFORE"
        printf "  %-14s: %s\n" "Expires"    "$NOT_AFTER"
        printf "  %-14s: "     "Days Left"
        echo -e "${DAY_COLOR}${DAYS_LEFT} days${NC}"
        printf "  %-14s: %s\n" "Alt Names"  "${SAN:0:34}"
        sep_mid
    }

    while true; do
        clear
        sep_top
        row "$(printf '%*s%s' $(( (W - 22) / 2 )) '' 'SSL Certificate Checker')"
        sep_mid
        blank
        row "   1.  Check Domain (Standalone)"
        row "   2.  Check Domain (Web Server / custom IP)"
        row "   0.  Back"
        blank
        sep_bot
        echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"
        read -n 1 LOPT; echo ""

        case $LOPT in
            1)
                echo -ne "\n  ${YELLOW}Domain (e.g. example.com): ${NC}"; read -r CHKDOM
                [ -z "$CHKDOM" ] && continue
                echo -ne "  ${YELLOW}Port [443]: ${NC}"; read -r CHKPORT
                [ -z "$CHKPORT" ] && CHKPORT=443
                # Resolve domain IP to show alongside domain name
                _SA_IP=""
                if command -v dig &>/dev/null; then
                    _SA_IP=$(dig +short "$CHKDOM" 2>/dev/null | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
                elif command -v getent &>/dev/null; then
                    _SA_IP=$(getent hosts "$CHKDOM" 2>/dev/null | awk '{print $1}' | head -1)
                fi
                _ssl_check_domain "$CHKDOM" "$CHKDOM" "$CHKPORT" "$_SA_IP"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                ;;
            2)
                echo -e "\n  ${DIM}Connect via server IP with domain as SNI${NC}\n"
                echo -ne "  ${YELLOW}Domain name (SNI): ${NC}"; read -r CF_DOMAIN
                [ -z "$CF_DOMAIN" ] && continue
                RESOLVED_IP=""
                if command -v dig &>/dev/null; then
                    RESOLVED_IP=$(dig +short "$CF_DOMAIN" 2>/dev/null \
                        | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
                elif command -v nslookup &>/dev/null; then
                    RESOLVED_IP=$(nslookup "$CF_DOMAIN" 2>/dev/null \
                        | awk '/^Address:/{print $2}' | grep -v '#' | head -1)
                elif command -v getent &>/dev/null; then
                    RESOLVED_IP=$(getent hosts "$CF_DOMAIN" 2>/dev/null | awk '{print $1}' | head -1)
                fi
                [ -n "$RESOLVED_IP" ] && echo -e "  ${DIM}Resolved IP: ${RESOLVED_IP}${NC}"
                echo -ne "  ${YELLOW}Server IP [${RESOLVED_IP:-your-server-ip}]: ${NC}"; read -r CF_IP
                [ -z "$CF_IP" ] && CF_IP="$RESOLVED_IP"
                [ -z "$CF_IP" ] && echo -e "  ${RED}IP cannot be empty.${NC}" && sleep 2 && continue
                echo -ne "  ${YELLOW}Port [443]: ${NC}"; read -r CF_PORT
                [ -z "$CF_PORT" ] && CF_PORT=443
                _ssl_check_domain "$CF_DOMAIN" "$CF_IP" "$CF_PORT"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                ;;
            0) return ;;
            *) echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# ── 10. VPN Panel Manager ────────────────────────────────────────
install_xui() {

    # helper: generic service control
    _svc_ctrl() {
        local SVC="$1"
        clear
        sep_top; row "       Service Control: $SVC"; sep_mid; blank
        row "   1.  Start"
        row "   2.  Stop"
        row "   3.  Restart"
        row "   4.  Status"
        blank; sep_bot; echo ""
        echo -ne "  ${YELLOW}> Select: ${NC}"; read -n 1 SC; echo ""
        case $SC in
            1) systemctl start   "$SVC" 2>/dev/null && \
                   echo -e "  ${GREEN}[OK] Started.${NC}" || \
                   echo -e "  ${RED}[ERR] Failed to start.${NC}" ;;
            2) systemctl stop    "$SVC" 2>/dev/null && \
                   echo -e "  ${YELLOW}[OK] Stopped.${NC}" || \
                   echo -e "  ${RED}[ERR] Failed to stop.${NC}" ;;
            3) systemctl restart "$SVC" 2>/dev/null && \
                   echo -e "  ${GREEN}[OK] Restarted.${NC}" || \
                   echo -e "  ${RED}[ERR] Failed to restart.${NC}" ;;
            4) systemctl status  "$SVC" --no-pager 2>/dev/null | head -20 || \
                   echo -e "  ${RED}[ERR] Service not found.${NC}" ;;
            *) echo -e "  ${RED}Invalid.${NC}" ;;
        esac
        echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
    }

    # helper: ensure curl
    _need_curl() {
        if ! command -v curl &>/dev/null; then
            echo -e "\n  ${CYAN}[*] Installing curl...${NC}\n"
            apt install -y curl 2>/dev/null || yum install -y curl 2>/dev/null || \
                dnf install -y curl 2>/dev/null
        fi
        command -v curl &>/dev/null
    }

    while true; do
        clear
        sep_top
        row "$(printf '%*s%s' $(( (W - 18) / 2 )) '' 'VPN Panel Manager')"
        sep_mid
        blank
        row "   1.  3x-UI        (MHSanaei)"
        row "   2.  X-UI         (Alireza0)"
        row "   3.  Marzban      (Gozargah)"
        row "   4.  Hiddify      (hiddify)"
        row "   5.  PasarGuard   (PasarGuard)"
        row "   0.  Back"
        blank
        sep_bot
        echo ""
        echo -ne "  ${YELLOW}> Select panel: ${NC}"
        read -r XOPT; echo ""

        case $XOPT in
            # ── 3x-UI ────────────────────────────────────────────
            1)
                while true; do
                    clear; sep_top
                    row "$(printf '%*s%s' $(( (W-16)/2 )) '' '3x-UI  (MHSanaei)')"
                    sep_mid; blank
                    IS_INST=0
                    { command -v x-ui &>/dev/null || [ -f /usr/local/x-ui/x-ui ]; } && IS_INST=1
                    if [ "$IS_INST" -eq 1 ]; then
                        STA=$(systemctl is-active x-ui 2>/dev/null || echo "unknown")
                        rowc 20 "  ${GREEN}Installed — Status: ${STA}${NC}"; blank
                    fi
                    row "   1.  Install / Update"
                    row "   2.  Service Control"
                    row "   3.  Uninstall"
                    row "   0.  Back"
                    blank; sep_bot; echo ""
                    echo -ne "  ${YELLOW}> Select: ${NC}"; read -r XO; echo ""
                    case $XO in
                        1)
                            _need_curl || { echo -e "  ${RED}[ERR] curl required.${NC}"; sleep 2; continue; }
                            echo -e "\n  ${CYAN}[*] Installing 3x-UI...${NC}\n"
                            bash <(curl -Ls https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh) 2>&1 || \
                                echo -e "  ${RED}[ERR] Install failed. Check connection.${NC}"
                            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                        2) _svc_ctrl x-ui ;;
                        3)
                            echo -ne "\n  ${RED}Uninstall 3x-UI? (y/N): ${NC}"; read -n 1 C; echo ""
                            if [[ "$C" = "y" || "$C" = "Y" ]]; then
                                x-ui uninstall 2>/dev/null || {
                                    systemctl stop x-ui 2>/dev/null
                                    systemctl disable x-ui 2>/dev/null
                                    rm -rf /usr/local/x-ui /usr/bin/x-ui
                                    systemctl daemon-reload 2>/dev/null
                                }
                                echo -e "  ${GREEN}[OK] Removed.${NC}"
                            else echo -e "  ${DIM}Cancelled.${NC}"; fi
                            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                        0) break ;;
                        *) echo -e "  ${RED}Invalid.${NC}"; sleep 1 ;;
                    esac
                done ;;

            # ── X-UI ─────────────────────────────────────────────
            2)
                while true; do
                    clear; sep_top
                    row "$(printf '%*s%s' $(( (W-16)/2 )) '' 'X-UI   (Alireza0)')"
                    sep_mid; blank
                    IS_INST=0
                    { command -v x-ui &>/dev/null || [ -f /usr/local/x-ui/x-ui ]; } && IS_INST=1
                    if [ "$IS_INST" -eq 1 ]; then
                        STA=$(systemctl is-active x-ui 2>/dev/null || echo "unknown")
                        rowc 20 "  ${GREEN}Installed — Status: ${STA}${NC}"; blank
                    fi
                    row "   1.  Install / Update"
                    row "   2.  Service Control"
                    row "   3.  Uninstall"
                    row "   0.  Back"
                    blank; sep_bot; echo ""
                    echo -ne "  ${YELLOW}> Select: ${NC}"; read -r XO; echo ""
                    XUI_SCRIPT="https://raw.githubusercontent.com/alireza0/x-ui/master/install.sh"
                    case $XO in
                        1)
                            _need_curl || { echo -e "  ${RED}[ERR] curl required.${NC}"; sleep 2; continue; }
                            echo -e "\n  ${CYAN}[*] Installing X-UI...${NC}\n"
                            bash <(curl -Ls "$XUI_SCRIPT") 2>&1 || \
                                echo -e "  ${RED}[ERR] Install failed.${NC}"
                            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                        2) _svc_ctrl x-ui ;;
                        3)
                            echo -ne "\n  ${RED}Uninstall X-UI? (y/N): ${NC}"; read -n 1 C; echo ""
                            if [[ "$C" = "y" || "$C" = "Y" ]]; then
                                x-ui uninstall 2>/dev/null || {
                                    systemctl stop x-ui 2>/dev/null
                                    systemctl disable x-ui 2>/dev/null
                                    rm -rf /usr/local/x-ui /usr/bin/x-ui
                                    systemctl daemon-reload 2>/dev/null
                                }
                                echo -e "  ${GREEN}[OK] Removed.${NC}"
                            else echo -e "  ${DIM}Cancelled.${NC}"; fi
                            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                        0) break ;;
                        *) echo -e "  ${RED}Invalid.${NC}"; sleep 1 ;;
                    esac
                done ;;

            # ── Marzban ──────────────────────────────────────────
            3)
                while true; do
                    clear; sep_top
                    row "$(printf '%*s%s' $(( (W-18)/2 )) '' 'Marzban  (Gozargah)')"
                    sep_mid; blank
                    IS_INST=0
                    { [ -f /usr/local/bin/marzban ] || [ -d /opt/marzban ]; } && IS_INST=1
                    if [ "$IS_INST" -eq 1 ]; then
                        STA=$(systemctl is-active marzban 2>/dev/null || echo "unknown")
                        rowc 20 "  ${GREEN}Installed — Status: ${STA}${NC}"; blank
                    fi
                    row "   1.  Install (SQLite)"
                    row "   2.  Install (MariaDB)"
                    row "   3.  Install (MySQL)"
                    row "   4.  Service Control"
                    row "   5.  Uninstall"
                    row "   0.  Back"
                    blank; sep_bot; echo ""
                    echo -ne "  ${YELLOW}> Select: ${NC}"; read -r XO; echo ""
                    MZ_SCRIPT="https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh"
                    case $XO in
                        1)
                            _need_curl || { echo -e "  ${RED}[ERR] curl required.${NC}"; sleep 2; continue; }
                            echo -e "\n  ${CYAN}[*] Installing Marzban (SQLite)...${NC}\n"
                            bash <(curl -sL "$MZ_SCRIPT") @ install 2>&1 || \
                                echo -e "  ${RED}[ERR] Install failed.${NC}"
                            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                        2)
                            _need_curl || { echo -e "  ${RED}[ERR] curl required.${NC}"; sleep 2; continue; }
                            echo -e "\n  ${CYAN}[*] Installing Marzban (MariaDB)...${NC}\n"
                            bash <(curl -sL "$MZ_SCRIPT") @ install --database mariadb 2>&1 || \
                                echo -e "  ${RED}[ERR] Install failed.${NC}"
                            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                        3)
                            _need_curl || { echo -e "  ${RED}[ERR] curl required.${NC}"; sleep 2; continue; }
                            echo -e "\n  ${CYAN}[*] Installing Marzban (MySQL)...${NC}\n"
                            bash <(curl -sL "$MZ_SCRIPT") @ install --database mysql 2>&1 || \
                                echo -e "  ${RED}[ERR] Install failed.${NC}"
                            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                        4) _svc_ctrl marzban ;;
                        5)
                            echo -ne "\n  ${RED}Uninstall Marzban? (y/N): ${NC}"; read -n 1 C; echo ""
                            if [[ "$C" = "y" || "$C" = "Y" ]]; then
                                { _need_curl && bash <(curl -sL "$MZ_SCRIPT") @ uninstall 2>/dev/null; } || {
                                    systemctl stop marzban 2>/dev/null
                                    systemctl disable marzban 2>/dev/null
                                    rm -rf /opt/marzban /usr/local/bin/marzban
                                    systemctl daemon-reload 2>/dev/null
                                }
                                echo -e "  ${GREEN}[OK] Removed.${NC}"
                            else echo -e "  ${DIM}Cancelled.${NC}"; fi
                            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                        0) break ;;
                        *) echo -e "  ${RED}Invalid.${NC}"; sleep 1 ;;
                    esac
                done ;;

            # ── Hiddify ──────────────────────────────────────────
            4)
                while true; do
                    clear; sep_top
                    row "$(printf '%*s%s' $(( (W-16)/2 )) '' 'Hiddify  (hiddify)')"
                    sep_mid; blank
                    IS_INST=0
                    [ -d /opt/hiddify-manager ] && IS_INST=1
                    if [ "$IS_INST" -eq 1 ]; then
                        STA=$(systemctl is-active hiddify-panel 2>/dev/null || echo "unknown")
                        rowc 20 "  ${GREEN}Installed — Status: ${STA}${NC}"; blank
                    fi
                    row "   1.  Install Hiddify Manager"
                    row "   2.  Service Control"
                    row "   3.  Uninstall"
                    row "   0.  Back"
                    blank; sep_bot; echo ""
                    echo -ne "  ${YELLOW}> Select: ${NC}"; read -r XO; echo ""
                    HD_SCRIPT="https://raw.githubusercontent.com/hiddify/hiddify-manager/main/common/download_install.sh"
                    case $XO in
                        1)
                            _need_curl || { echo -e "  ${RED}[ERR] curl required.${NC}"; sleep 2; continue; }
                            echo -e "\n  ${CYAN}[*] Installing Hiddify Manager...${NC}\n"
                            bash <(curl -Lfo- "$HD_SCRIPT") 2>&1 || \
                                echo -e "  ${RED}[ERR] Install failed.${NC}"
                            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                        2) _svc_ctrl hiddify-panel ;;
                        3)
                            echo -ne "\n  ${RED}Uninstall Hiddify? (y/N): ${NC}"; read -n 1 C; echo ""
                            if [[ "$C" = "y" || "$C" = "Y" ]]; then
                                { [ -f /opt/hiddify-manager/install.sh ] && \
                                    bash /opt/hiddify-manager/install.sh uninstall 2>/dev/null; } || true
                                systemctl stop hiddify-panel 2>/dev/null
                                systemctl disable hiddify-panel 2>/dev/null
                                rm -rf /opt/hiddify-manager 2>/dev/null
                                systemctl daemon-reload 2>/dev/null
                                echo -e "  ${GREEN}[OK] Removed.${NC}"
                            else echo -e "  ${DIM}Cancelled.${NC}"; fi
                            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                        0) break ;;
                        *) echo -e "  ${RED}Invalid.${NC}"; sleep 1 ;;
                    esac
                done ;;

            # ── PasarGuard ───────────────────────────────────────
            5)
                while true; do
                    clear; sep_top
                    row "$(printf '%*s%s' $(( (W-20)/2 )) '' 'PasarGuard  (PasarGuard)')"
                    sep_mid; blank
                    IS_INST=0
                    [ -d /opt/pasarguard ] && IS_INST=1
                    if [ "$IS_INST" -eq 1 ]; then
                        STA=$(systemctl is-active pasarguard 2>/dev/null || echo "unknown")
                        rowc 20 "  ${GREEN}Installed — Status: ${STA}${NC}"; blank
                    fi
                    row "   1.  Install (SQLite)"
                    row "   2.  Install (MariaDB)"
                    row "   3.  Install (MySQL)"
                    row "   4.  Service Control"
                    row "   5.  Uninstall"
                    row "   0.  Back"
                    blank; sep_bot; echo ""
                    echo -ne "  ${YELLOW}> Select: ${NC}"; read -r XO; echo ""
                    PG_SCRIPT="https://github.com/PasarGuard/scripts/raw/main/pasarguard.sh"
                    case $XO in
                        1)
                            _need_curl || { echo -e "  ${RED}[ERR] curl required.${NC}"; sleep 2; continue; }
                            echo -e "\n  ${CYAN}[*] Installing PasarGuard (SQLite)...${NC}\n"
                            bash <(curl -fsSL "$PG_SCRIPT") @ install 2>&1 || \
                                echo -e "  ${RED}[ERR] Install failed.${NC}"
                            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                        2)
                            _need_curl || { echo -e "  ${RED}[ERR] curl required.${NC}"; sleep 2; continue; }
                            echo -e "\n  ${CYAN}[*] Installing PasarGuard (MariaDB)...${NC}\n"
                            bash <(curl -fsSL "$PG_SCRIPT") @ install --database mariadb 2>&1 || \
                                echo -e "  ${RED}[ERR] Install failed.${NC}"
                            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                        3)
                            _need_curl || { echo -e "  ${RED}[ERR] curl required.${NC}"; sleep 2; continue; }
                            echo -e "\n  ${CYAN}[*] Installing PasarGuard (MySQL)...${NC}\n"
                            bash <(curl -fsSL "$PG_SCRIPT") @ install --database mysql 2>&1 || \
                                echo -e "  ${RED}[ERR] Install failed.${NC}"
                            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                        4) _svc_ctrl pasarguard ;;
                        5)
                            echo -ne "\n  ${RED}Uninstall PasarGuard? (y/N): ${NC}"; read -n 1 C; echo ""
                            if [[ "$C" = "y" || "$C" = "Y" ]]; then
                                { _need_curl && bash <(curl -fsSL "$PG_SCRIPT") @ uninstall 2>/dev/null; } || {
                                    systemctl stop pasarguard 2>/dev/null
                                    systemctl disable pasarguard 2>/dev/null
                                    rm -rf /opt/pasarguard /var/lib/pasarguard 2>/dev/null
                                    systemctl daemon-reload 2>/dev/null
                                }
                                echo -e "  ${GREEN}[OK] Removed.${NC}"
                            else echo -e "  ${DIM}Cancelled.${NC}"; fi
                            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                        0) break ;;
                        *) echo -e "  ${RED}Invalid.${NC}"; sleep 1 ;;
                    esac
                done ;;

            0) return ;;
            *) echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# ── Live Connection Monitor ──────────────────────────────────────
live_connection_monitor() {
    tput smcup 2>/dev/null; tput civis 2>/dev/null
    trap 'tput rmcup 2>/dev/null; tput cnorm 2>/dev/null; return' INT

    while true; do
        TOTAL_CONN=$(ss -tnp 2>/dev/null | tail -n +2 | wc -l || echo 0)
        ESTAB=$(ss -tnp 2>/dev/null | grep -c ESTAB || echo 0)
        TIME_WAIT=$(ss -tn 2>/dev/null | grep -c TIME-WAIT || echo 0)
        LISTEN_COUNT=$(ss -tlnp 2>/dev/null | tail -n +2 | wc -l || echo 0)

        OUT=""
        OUT+="$(sep_top)"$'\n'
        OUT+="$(row "$(printf '%*s%s' $(( (W - 24) / 2 )) '' 'Live Connection Monitor')")"$'\n'
        OUT+="$(row "  Q=back    $(date '+%Y-%m-%d %H:%M:%S')")"$'\n'
        OUT+="$(sep_mid)"$'\n'
        OUT+="$(row "  Total Connections : $TOTAL_CONN")"$'\n'
        OUT+="$(row "  Established       : $ESTAB")"$'\n'
        OUT+="$(row "  TIME-WAIT         : $TIME_WAIT")"$'\n'
        OUT+="$(row "  Listening Ports   : $LISTEN_COUNT")"$'\n'
        OUT+="$(sep_mid)"$'\n'
        OUT+="$(row "  PROTO  LOCAL                 PEER                  STATE")"$'\n'
        OUT+="$(sep_mid)"$'\n'

        COUNT=0
        while IFS= read -r line; do
            [ $COUNT -ge 15 ] && break
            PROTO=$(echo "$line" | awk '{print $1}')
            STATE=$(echo "$line" | awk '{print $2}')
            LOCAL=$(echo "$line" | awk '{print $5}')
            PEER=$(echo "$line"  | awk '{print $6}')
            [ -z "$LOCAL" ] && LOCAL=$(echo "$line" | awk '{print $4}')
            [ -z "$PEER"  ] && PEER=$(echo "$line"  | awk '{print $5}')
            LINE=$(printf "  %-6s %-21s %-21s %s" \
                "${PROTO:0:5}" "${LOCAL:0:20}" "${PEER:0:20}" "${STATE:0:10}")
            OUT+="$(row "$LINE")"$'\n'
            COUNT=$(( COUNT + 1 ))
        done < <(ss -tnp 2>/dev/null | tail -n +2 | grep -v "127.0.0.1" | head -20)

        [ "$COUNT" -eq 0 ] && OUT+="$(row "  No active connections")"$'\n'
        OUT+="$(sep_bot)"$'\n'

        tput cup 0 0 2>/dev/null
        printf '%s' "$OUT"
        tput ed 2>/dev/null

        read -t 2 -n 1 key 2>/dev/null || true
        [[ "$key" = "q" || "$key" = "Q" ]] && break
    done
    trap - INT; tput rmcup 2>/dev/null; tput cnorm 2>/dev/null
}

# ── DNS Manager ──────────────────────────────────────────────────
dns_manager() {
    while true; do
        clear
        sep_top
        row "$(printf '%*s%s' $(( (W - 12) / 2 )) '' 'DNS Manager')"
        sep_mid; blank

        # Current DNS
        DNS_CURRENT=""
        if [ -f /etc/resolv.conf ]; then
            DNS_CURRENT=$(grep "^nameserver" /etc/resolv.conf 2>/dev/null \
                | awk '{print $2}' | head -3 | tr '\n' '  ')
        fi
        [ -z "$DNS_CURRENT" ] && DNS_CURRENT="N/A"
        row "  Current DNS: $DNS_CURRENT"
        blank; sep_mid; blank
        row "   1.  Show Current DNS"
        row "   2.  Set DNS (custom)"
        row "   3.  Set DNS — Google (8.8.8.8)"
        row "   4.  Set DNS — Cloudflare (1.1.1.1)"
        row "   5.  Set DNS — Shecan (178.22.122.100)"
        row "   6.  Flush DNS Cache"
        row "   7.  Test DNS (nslookup / dig)"
        row "   8.  Reverse DNS Lookup"
        row "   0.  Back"
        blank; sep_bot; echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"
        read -n 1 DOPT; echo ""

        _set_dns() {
            local DNS1="$1" DNS2="${2:-}"
            cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null
            {
                echo "# Generated by server_manager"
                echo "nameserver $DNS1"
                [ -n "$DNS2" ] && echo "nameserver $DNS2"
            } > /etc/resolv.conf
            echo -e "  ${GREEN}[OK] DNS set to: $DNS1 ${DNS2}${NC}"
        }

        case $DOPT in
            1)
                echo ""
                echo -e "  ${CYAN}[/etc/resolv.conf]${NC}\n"
                cat /etc/resolv.conf 2>/dev/null | while IFS= read -r l; do echo "  $l"; done
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            2)
                echo -ne "\n  ${YELLOW}Primary DNS   : ${NC}"; read -r D1
                echo -ne "  ${YELLOW}Secondary DNS : ${NC}"; read -r D2
                [ -z "$D1" ] && echo -e "  ${RED}Empty.${NC}" && sleep 1 && continue
                _set_dns "$D1" "$D2"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            3) _set_dns "8.8.8.8" "8.8.4.4"
               echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            4) _set_dns "1.1.1.1" "1.0.0.1"
               echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            5) _set_dns "178.22.122.100" "185.51.200.2"
               echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            6)
                echo ""
                if command -v systemd-resolve &>/dev/null; then
                    systemd-resolve --flush-caches 2>/dev/null && \
                        echo -e "  ${GREEN}[OK] systemd-resolved cache flushed.${NC}" || true
                fi
                if command -v nscd &>/dev/null; then
                    nscd -i hosts 2>/dev/null && \
                        echo -e "  ${GREEN}[OK] nscd cache flushed.${NC}" || true
                fi
                echo -e "  ${GREEN}[OK] DNS flush attempted.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            7)
                echo -ne "\n  ${YELLOW}Domain to test: ${NC}"; read -r TEST_DOM
                [ -z "$TEST_DOM" ] && continue
                echo ""
                if command -v dig &>/dev/null; then
                    dig "$TEST_DOM" 2>&1 | while IFS= read -r l; do echo "  $l"; done
                elif command -v nslookup &>/dev/null; then
                    nslookup "$TEST_DOM" 2>&1 | while IFS= read -r l; do echo "  $l"; done
                else
                    echo -e "  ${RED}[ERR] dig and nslookup not found.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            8)
                echo -ne "\n  ${YELLOW}IP for reverse lookup: ${NC}"; read -r REV_IP
                [ -z "$REV_IP" ] && continue
                echo ""
                if command -v dig &>/dev/null; then
                    dig -x "$REV_IP" 2>&1 | while IFS= read -r l; do echo "  $l"; done
                elif command -v nslookup &>/dev/null; then
                    nslookup "$REV_IP" 2>&1 | while IFS= read -r l; do echo "  $l"; done
                else
                    echo -e "  ${RED}[ERR] dig and nslookup not found.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            0) return ;;
            *) echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# ── IPTables Manager ─────────────────────────────────────────────
iptables_manager() {
    while true; do
        clear
        sep_top
        row "$(printf '%*s%s' $(( (W - 17) / 2 )) '' 'IPTables Manager')"
        sep_mid; blank

        if ! command -v iptables &>/dev/null; then
            rowc 36 "  ${RED}!! iptables not installed !!${NC}"
            blank; sep_mid
            row "   1.  Install iptables"
            row "   0.  Back"
            blank; sep_bot; echo ""
            echo -ne "  ${YELLOW}> Select option: ${NC}"; read -n 1 IO; echo ""
            case $IO in
                1) apt install -y iptables 2>/dev/null || \
                   yum install -y iptables 2>/dev/null || \
                   dnf install -y iptables 2>/dev/null
                   echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                0) return ;;
            esac; continue
        fi

        IN_RULES=$(iptables -L INPUT --line-numbers -n 2>/dev/null | grep -c "^[0-9]" || echo 0)
        FW_RULES=$(iptables -L FORWARD --line-numbers -n 2>/dev/null | grep -c "^[0-9]" || echo 0)
        row "  INPUT rules: $IN_RULES    FORWARD rules: $FW_RULES"
        blank; sep_mid; blank
        row "   1.  List All Rules"
        row "   2.  List INPUT rules"
        row "   3.  Allow port (TCP)"
        row "   4.  Allow port (UDP)"
        row "   5.  Block IP"
        row "   6.  Unblock IP"
        row "   7.  Delete rule by line number"
        row "   8.  Flush ALL rules (reset)"
        row "   9.  Save rules (iptables-save)"
        row "   10. Restore rules (iptables-restore)"
        row "   0.  Back"
        blank; sep_bot; echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"
        read -r IOPT; echo ""

        case $IOPT in
            1)
                echo ""
                iptables -L -v -n --line-numbers 2>/dev/null | while IFS= read -r l; do echo "  $l"; done
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            2)
                echo ""
                iptables -L INPUT -v -n --line-numbers 2>/dev/null | while IFS= read -r l; do echo "  $l"; done
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            3)
                echo -ne "\n  ${YELLOW}Port to allow (TCP): ${NC}"; read -r IPT_PORT
                [ -z "$IPT_PORT" ] && continue
                iptables -A INPUT -p tcp --dport "$IPT_PORT" -j ACCEPT 2>/dev/null && \
                    echo -e "  ${GREEN}[OK] Port $IPT_PORT/tcp allowed.${NC}" || \
                    echo -e "  ${RED}[ERR] Failed.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            4)
                echo -ne "\n  ${YELLOW}Port to allow (UDP): ${NC}"; read -r IPT_PORT
                [ -z "$IPT_PORT" ] && continue
                iptables -A INPUT -p udp --dport "$IPT_PORT" -j ACCEPT 2>/dev/null && \
                    echo -e "  ${GREEN}[OK] Port $IPT_PORT/udp allowed.${NC}" || \
                    echo -e "  ${RED}[ERR] Failed.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            5)
                echo -ne "\n  ${YELLOW}IP to block: ${NC}"; read -r BLK_IP
                [ -z "$BLK_IP" ] && continue
                iptables -A INPUT -s "$BLK_IP" -j DROP 2>/dev/null && \
                    echo -e "  ${GREEN}[OK] $BLK_IP blocked.${NC}" || \
                    echo -e "  ${RED}[ERR] Failed.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            6)
                echo -ne "\n  ${YELLOW}IP to unblock: ${NC}"; read -r UBK_IP
                [ -z "$UBK_IP" ] && continue
                iptables -D INPUT -s "$UBK_IP" -j DROP 2>/dev/null && \
                    echo -e "  ${GREEN}[OK] $UBK_IP unblocked.${NC}" || \
                    echo -e "  ${YELLOW}[!] Rule not found or failed.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            7)
                echo ""
                iptables -L INPUT --line-numbers -n 2>/dev/null | while IFS= read -r l; do echo "  $l"; done
                echo -ne "\n  ${YELLOW}Line number to delete: ${NC}"; read -r DEL_LINE
                [ -z "$DEL_LINE" ] && continue
                iptables -D INPUT "$DEL_LINE" 2>/dev/null && \
                    echo -e "  ${GREEN}[OK] Rule $DEL_LINE deleted.${NC}" || \
                    echo -e "  ${RED}[ERR] Failed.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            8)
                echo -ne "\n  ${RED}Flush ALL iptables rules? (y/N): ${NC}"; read -n 1 C; echo ""
                if [[ "$C" = "y" || "$C" = "Y" ]]; then
                    iptables -F 2>/dev/null
                    iptables -X 2>/dev/null
                    iptables -P INPUT   ACCEPT 2>/dev/null
                    iptables -P FORWARD ACCEPT 2>/dev/null
                    iptables -P OUTPUT  ACCEPT 2>/dev/null
                    echo -e "  ${GREEN}[OK] All rules flushed, policies set to ACCEPT.${NC}"
                else
                    echo -e "  ${DIM}Cancelled.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            9)
                SAVE_FILE="/etc/iptables/rules.v4"
                mkdir -p /etc/iptables 2>/dev/null
                iptables-save 2>/dev/null > "$SAVE_FILE" && \
                    echo -e "  ${GREEN}[OK] Saved to $SAVE_FILE${NC}" || \
                    echo -e "  ${RED}[ERR] iptables-save failed.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            10)
                SAVE_FILE="/etc/iptables/rules.v4"
                if [ -f "$SAVE_FILE" ]; then
                    iptables-restore < "$SAVE_FILE" 2>/dev/null && \
                        echo -e "  ${GREEN}[OK] Rules restored from $SAVE_FILE${NC}" || \
                        echo -e "  ${RED}[ERR] Restore failed.${NC}"
                else
                    echo -e "  ${RED}[ERR] $SAVE_FILE not found.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            0) return ;;
            *) echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# ── NAT Manager ──────────────────────────────────────────────────
nat_manager() {
    while true; do
        clear
        sep_top
        row "$(printf '%*s%s' $(( (W - 12) / 2 )) '' 'NAT Manager')"
        sep_mid; blank

        # Detect primary interface
        NAT_IFACE=$(ip route 2>/dev/null | grep '^default' | awk '{print $5}' | head -1)
        [ -z "$NAT_IFACE" ] && NAT_IFACE="eth0"

        IP_FWD=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo 0)
        if [ "$IP_FWD" = "1" ]; then
            rowc 32 "  IP Forward: ${GREEN}Enabled${NC}"
        else
            rowc 33 "  IP Forward: ${RED}Disabled${NC}"
        fi
        row "  Interface : $NAT_IFACE"
        blank; sep_mid; blank
        row "   1.  Enable IP Forwarding"
        row "   2.  Disable IP Forwarding"
        row "   3.  List NAT rules (MASQUERADE)"
        row "   4.  Add MASQUERADE (outbound NAT)"
        row "   5.  Remove MASQUERADE"
        row "   6.  Add Port Forward (DNAT)"
        row "   7.  List all PREROUTING rules"
        row "   8.  Flush NAT table"
        row "   0.  Back"
        blank; sep_bot; echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"
        read -r NOPT; echo ""

        case $NOPT in
            1)
                echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null
                sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf 2>/dev/null
                echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf 2>/dev/null
                echo -e "  ${GREEN}[OK] IP Forwarding enabled (persistent).${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            2)
                echo 0 > /proc/sys/net/ipv4/ip_forward 2>/dev/null
                sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf 2>/dev/null
                echo "net.ipv4.ip_forward=0" >> /etc/sysctl.conf 2>/dev/null
                echo -e "  ${YELLOW}[OK] IP Forwarding disabled.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            3)
                echo ""
                iptables -t nat -L POSTROUTING -v -n --line-numbers 2>/dev/null | \
                    while IFS= read -r l; do echo "  $l"; done
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            4)
                echo -ne "\n  ${YELLOW}Interface [$NAT_IFACE]: ${NC}"; read -r MQ_IFACE
                [ -z "$MQ_IFACE" ] && MQ_IFACE="$NAT_IFACE"
                iptables -t nat -A POSTROUTING -o "$MQ_IFACE" -j MASQUERADE 2>/dev/null && \
                    echo -e "  ${GREEN}[OK] MASQUERADE added on $MQ_IFACE.${NC}" || \
                    echo -e "  ${RED}[ERR] Failed.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            5)
                echo -ne "\n  ${YELLOW}Interface [$NAT_IFACE]: ${NC}"; read -r MQ_IFACE
                [ -z "$MQ_IFACE" ] && MQ_IFACE="$NAT_IFACE"
                iptables -t nat -D POSTROUTING -o "$MQ_IFACE" -j MASQUERADE 2>/dev/null && \
                    echo -e "  ${GREEN}[OK] MASQUERADE removed.${NC}" || \
                    echo -e "  ${YELLOW}[!] Rule not found or failed.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            6)
                echo -ne "\n  ${YELLOW}Incoming port       : ${NC}"; read -r PF_SRC_PORT
                echo -ne "  ${YELLOW}Destination IP      : ${NC}"; read -r PF_DST_IP
                echo -ne "  ${YELLOW}Destination port    : ${NC}"; read -r PF_DST_PORT
                echo -ne "  ${YELLOW}Protocol [tcp]      : ${NC}"; read -r PF_PROTO
                [ -z "$PF_PROTO" ] && PF_PROTO="tcp"
                [ -z "$PF_SRC_PORT" ] || [ -z "$PF_DST_IP" ] || [ -z "$PF_DST_PORT" ] && \
                    echo -e "  ${RED}Missing input.${NC}" && sleep 2 && continue
                iptables -t nat -A PREROUTING -p "$PF_PROTO" --dport "$PF_SRC_PORT" \
                    -j DNAT --to-destination "${PF_DST_IP}:${PF_DST_PORT}" 2>/dev/null && \
                    echo -e "  ${GREEN}[OK] Forward :$PF_SRC_PORT -> $PF_DST_IP:$PF_DST_PORT${NC}" || \
                    echo -e "  ${RED}[ERR] Failed.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            7)
                echo ""
                iptables -t nat -L PREROUTING -v -n --line-numbers 2>/dev/null | \
                    while IFS= read -r l; do echo "  $l"; done
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            8)
                echo -ne "\n  ${RED}Flush entire NAT table? (y/N): ${NC}"; read -n 1 C; echo ""
                if [[ "$C" = "y" || "$C" = "Y" ]]; then
                    iptables -t nat -F 2>/dev/null
                    echo -e "  ${GREEN}[OK] NAT table flushed.${NC}"
                else
                    echo -e "  ${DIM}Cancelled.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            0) return ;;
            *) echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# ── MTR Tool ─────────────────────────────────────────────────────
mtr_tool() {
    clear
    sep_top
    row "$(printf '%*s%s' $(( (W - 3) / 2 )) '' 'MTR')"
    sep_mid; blank

    if ! command -v mtr &>/dev/null; then
        rowc 32 "  ${RED}!! mtr is not installed !!${NC}"
        blank; sep_mid
        row "   1.  Install mtr"
        row "   0.  Back"
        blank; sep_bot; echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"; read -n 1 MO; echo ""
        case $MO in
            1)
                apt install -y mtr-tiny 2>/dev/null || \
                apt install -y mtr 2>/dev/null || \
                yum install -y mtr 2>/dev/null || \
                dnf install -y mtr 2>/dev/null
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            0) return ;;
        esac
        return
    fi

    row "   1.  Run MTR (interactive)"
    row "   2.  Run MTR (report — 10 cycles)"
    row "   0.  Back"
    blank; sep_bot; echo ""
    echo -ne "  ${YELLOW}> Select option: ${NC}"; read -n 1 MO; echo ""
    case $MO in
        1)
            echo -ne "\n  ${YELLOW}Target host/IP: ${NC}"; read -r MTR_HOST
            [ -z "$MTR_HOST" ] && return
            echo -e "\n  ${CYAN}[*] Running MTR to $MTR_HOST (q to quit)...${NC}\n"
            mtr "$MTR_HOST" ;;
        2)
            echo -ne "\n  ${YELLOW}Target host/IP: ${NC}"; read -r MTR_HOST
            [ -z "$MTR_HOST" ] && return
            echo -e "\n  ${CYAN}[*] MTR report for $MTR_HOST (10 cycles)...${NC}\n"
            mtr -r -c 10 "$MTR_HOST" 2>&1 | while IFS= read -r l; do echo "  $l"; done
            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
        0) return ;;
        *) echo -e "  ${RED}Invalid.${NC}"; sleep 1 ;;
    esac
}

# ── MTU Finder ───────────────────────────────────────────────────
mtu_finder() {
    clear
    sep_top
    row "$(printf '%*s%s' $(( (W - 10) / 2 )) '' 'MTU Finder')"
    sep_mid; blank

    # Detect current MTU
    DEF_IFACE=$(ip route 2>/dev/null | grep '^default' | awk '{print $5}' | head -1)
    CUR_MTU=$(ip link show "$DEF_IFACE" 2>/dev/null | grep -oE 'mtu [0-9]+' | awk '{print $2}')
    [ -z "$CUR_MTU" ] && CUR_MTU="N/A"

    row "  Interface : ${DEF_IFACE:-N/A}"
    row "  Current MTU: $CUR_MTU"
    blank; sep_mid; blank
    row "   1.  Auto-detect optimal MTU (ping method)"
    row "   2.  Set MTU manually"
    row "   3.  Show all interfaces MTU"
    row "   0.  Back"
    blank; sep_bot; echo ""
    echo -ne "  ${YELLOW}> Select option: ${NC}"; read -n 1 MOPT; echo ""

    case $MOPT in
        1)
            echo -ne "\n  ${YELLOW}Target host [8.8.8.8]: ${NC}"; read -r MTU_HOST
            [ -z "$MTU_HOST" ] && MTU_HOST="8.8.8.8"
            echo -e "\n  ${CYAN}[*] Finding optimal MTU (binary search)...${NC}\n"
            MTU_LO=576; MTU_HI=1500; MTU_BEST=576
            while [ "$MTU_LO" -le "$MTU_HI" ]; do
                MTU_MID=$(( (MTU_LO + MTU_HI) / 2 ))
                PKT_SIZE=$(( MTU_MID - 28 ))   # 20 IP + 8 ICMP
                [ "$PKT_SIZE" -lt 1 ] && PKT_SIZE=1
                if ping -M do -s "$PKT_SIZE" -c 2 -W 1 "$MTU_HOST" &>/dev/null; then
                    MTU_BEST=$MTU_MID
                    MTU_LO=$(( MTU_MID + 1 ))
                    echo -e "  ${GREEN}[+] MTU $MTU_MID OK${NC}"
                else
                    MTU_HI=$(( MTU_MID - 1 ))
                    echo -e "  ${DIM}[-] MTU $MTU_MID too large${NC}"
                fi
            done
            echo -e "\n  ${GREEN}[RESULT] Optimal MTU: $MTU_BEST${NC}"
            echo -ne "\n  Apply this MTU to $DEF_IFACE? (y/N): "; read -n 1 AC; echo ""
            if [[ "$AC" = "y" || "$AC" = "Y" ]]; then
                ip link set dev "$DEF_IFACE" mtu "$MTU_BEST" 2>/dev/null && \
                    echo -e "  ${GREEN}[OK] MTU set to $MTU_BEST on $DEF_IFACE${NC}" || \
                    echo -e "  ${RED}[ERR] Failed.${NC}"
            fi
            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
        2)
            echo -ne "\n  ${YELLOW}Interface [$DEF_IFACE]: ${NC}"; read -r SET_IFACE
            [ -z "$SET_IFACE" ] && SET_IFACE="$DEF_IFACE"
            echo -ne "  ${YELLOW}MTU value: ${NC}"; read -r SET_MTU
            [ -z "$SET_MTU" ] && continue
            ip link set dev "$SET_IFACE" mtu "$SET_MTU" 2>/dev/null && \
                echo -e "  ${GREEN}[OK] MTU set to $SET_MTU on $SET_IFACE${NC}" || \
                echo -e "  ${RED}[ERR] Failed.${NC}"
            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
        3)
            echo ""
            ip link show 2>/dev/null | awk '/^[0-9]/{
                iface=$2; gsub(/:$/,"",iface)
                mtu="N/A"
            } /mtu/{
                for(i=1;i<=NF;i++) if($i=="mtu") mtu=$(i+1)
                printf "  %-16s MTU: %s\n", iface, mtu
            }' | head -20
            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
        0) return ;;
        *) echo -e "  ${RED}Invalid.${NC}"; sleep 1 ;;
    esac
}

# ── BBR / BBRv2 / ACCEL Manager ──────────────────────────────────
bbr_manager() {
    while true; do
        clear
        sep_top
        row "$(printf '%*s%s' $(( (W - 22) / 2 )) '' 'BBR / BBRv2 / ACCEL')"
        sep_mid; blank

        # Current congestion control
        CUR_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "N/A")
        CUR_QDISC=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "N/A")
        AVAIL_CC=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || echo "N/A")
        KERNEL_VER=$(uname -r)

        row "  Kernel        : $KERNEL_VER"
        row "  Current CC    : $CUR_CC"
        row "  Qdisc         : $CUR_QDISC"
        row "  Available CC  : $AVAIL_CC"
        blank; sep_mid; blank
        row "   1.  Enable BBR (stable)"
        row "   2.  Enable BBRv2 (if kernel supports)"
        row "   3.  Enable CUBIC (default)"
        row "   4.  Set qdisc to fq (recommended)"
        row "   5.  Set qdisc to fq_codel"
        row "   6.  Show full TCP tuning info"
        row "   7.  Apply optimal BBR config (BBR+fq)"
        row "   0.  Back"
        blank; sep_bot; echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"; read -n 1 BOPT; echo ""

        _apply_cc() {
            local CC="$1" QD="${2:-}"
            sysctl -w net.ipv4.tcp_congestion_control="$CC" 2>/dev/null
            [ -n "$QD" ] && sysctl -w net.core.default_qdisc="$QD" 2>/dev/null
            # Persist
            sed -i '/tcp_congestion_control/d' /etc/sysctl.conf 2>/dev/null
            sed -i '/default_qdisc/d' /etc/sysctl.conf 2>/dev/null
            echo "net.ipv4.tcp_congestion_control=$CC" >> /etc/sysctl.conf
            [ -n "$QD" ] && echo "net.core.default_qdisc=$QD" >> /etc/sysctl.conf
            sysctl -p &>/dev/null
        }

        case $BOPT in
            1)
                modprobe tcp_bbr 2>/dev/null || true
                if sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qw bbr; then
                    _apply_cc "bbr" "fq"
                    echo -e "  ${GREEN}[OK] BBR enabled with fq qdisc.${NC}"
                else
                    echo -e "  ${RED}[ERR] BBR not available. Kernel >= 4.9 required.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            2)
                modprobe tcp_bbr2 2>/dev/null || modprobe tcp_bbr 2>/dev/null || true
                if sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qw bbr2; then
                    _apply_cc "bbr2" "fq"
                    echo -e "  ${GREEN}[OK] BBRv2 enabled.${NC}"
                else
                    echo -e "  ${YELLOW}[!] BBRv2 not available on this kernel.${NC}"
                    echo -e "  ${DIM}Tip: Install kernel 6.x+ for BBRv2 support.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            3)
                _apply_cc "cubic"
                echo -e "  ${GREEN}[OK] CUBIC (default) set.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            4)
                sysctl -w net.core.default_qdisc=fq 2>/dev/null && \
                    echo -e "  ${GREEN}[OK] qdisc set to fq.${NC}" || \
                    echo -e "  ${RED}[ERR] Failed.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            5)
                sysctl -w net.core.default_qdisc=fq_codel 2>/dev/null && \
                    echo -e "  ${GREEN}[OK] qdisc set to fq_codel.${NC}" || \
                    echo -e "  ${RED}[ERR] Failed.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            6)
                echo ""
                echo -e "  ${CYAN}[TCP Congestion Control Info]${NC}"
                sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{printf "  %s\n",$0}'
                sysctl net.core.default_qdisc 2>/dev/null | awk '{printf "  %s\n",$0}'
                sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | awk '{printf "  %s\n",$0}'
                sysctl net.ipv4.tcp_rmem 2>/dev/null | awk '{printf "  %s\n",$0}'
                sysctl net.ipv4.tcp_wmem 2>/dev/null | awk '{printf "  %s\n",$0}'
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            7)
                modprobe tcp_bbr 2>/dev/null || true
                if sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qw bbr; then
                    _apply_cc "bbr" "fq"
                    # Additional TCP tuning
                    sysctl -w net.ipv4.tcp_fastopen=3 &>/dev/null
                    sysctl -w net.ipv4.tcp_slow_start_after_idle=0 &>/dev/null
                    sysctl -w net.ipv4.tcp_mtu_probing=1 &>/dev/null
                    echo -e "  ${GREEN}[OK] Optimal BBR config applied:${NC}"
                    echo -e "  ${DIM}  - BBR congestion control${NC}"
                    echo -e "  ${DIM}  - fq qdisc${NC}"
                    echo -e "  ${DIM}  - TCP Fast Open${NC}"
                    echo -e "  ${DIM}  - MTU probing${NC}"
                else
                    echo -e "  ${RED}[ERR] BBR not available. Kernel >= 4.9 required.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            0) return ;;
            *) echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# ── Check Port 80 & 443 ──────────────────────────────────────────
check_web_ports() {
    clear
    sep_top
    row "$(printf '%*s%s' $(( (W - 20) / 2 )) '' 'Check Port 80 & 443')"
    sep_mid; blank

    _check_port() {
        local PORT="$1"
        local LABEL="$2"

        # 1) Listening on server?
        local LISTENING="No"
        if ss -tlnp 2>/dev/null | grep -qE ":${PORT}[[:space:]]|:${PORT}$"; then
            LISTENING="Yes"
        fi

        # 2) Firewall status
        local FW_OK="Unknown"
        if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
            if ufw status 2>/dev/null | grep -qw "$PORT"; then
                FW_OK="Allowed"
            else
                FW_OK="Blocked"
            fi
        elif command -v iptables &>/dev/null; then
            if iptables -L INPUT -n 2>/dev/null | grep -q "dpt:${PORT}"; then
                FW_OK="Allowed"
            else
                FW_OK="Blocked"
            fi
        else
            FW_OK="No firewall"
        fi

        # 3) Actually connectable on this server?
        local USABLE="Closed"
        if timeout 3 bash -c ">/dev/tcp/127.0.0.1/${PORT}" 2>/dev/null; then
            USABLE="Open"
        fi

        # 4) Summary verdict
        local VERDICT VCOLOR
        if [ "$LISTENING" = "Yes" ] && [ "$USABLE" = "Open" ] && [ "$FW_OK" != "Blocked" ]; then
            VERDICT="✔ Available"; VCOLOR="${GREEN}"
        elif [ "$LISTENING" = "No" ] && [ "$USABLE" = "Closed" ]; then
            VERDICT="✘ Not in use"; VCOLOR="${DIM}"
        else
            VERDICT="⚠ Partial"; VCOLOR="${YELLOW}"
        fi

        sep_mid
        row "  Port ${PORT} — ${LABEL}"
        sep_mid

        # Listening row
        if [ "$LISTENING" = "Yes" ]; then
            rowc 36 "  Listening  : ${GREEN}Yes — service active${NC}"
        else
            rowc 29 "  Listening  : ${RED}No${NC}"
        fi

        # Firewall row
        if [ "$FW_OK" = "Allowed" ]; then
            rowc 35 "  Firewall   : ${GREEN}Allowed${NC}"
        elif [ "$FW_OK" = "Blocked" ]; then
            rowc 34 "  Firewall   : ${RED}Blocked${NC}"
        else
            rowc 37 "  Firewall   : ${DIM}No firewall${NC}"
        fi

        # Connectable row
        if [ "$USABLE" = "Open" ]; then
            rowc 32 "  Connect    : ${GREEN}Open${NC}"
        else
            rowc 31 "  Connect    : ${RED}Closed${NC}"
        fi

        # Verdict row
        local VVIS=$(( ${#VERDICT} + 15 ))
        rowc $VVIS "  Status     : ${VCOLOR}${VERDICT}${NC}"
    }

    _check_port 80  "HTTP"
    _check_port 443 "HTTPS"
    blank; sep_bot; echo ""
    echo -ne "  ${DIM}Press any key...${NC}"; read -n 1
}

# ── Submenu: System ──────────────────────────────────────────────
menu_system() {
    while true; do
        clear
        sep_top
        row "$(printf '%*s%s' $(( (W - 14) / 2 )) '' 'System Manager')"
        sep_mid; blank
        row "   1.  Update"
        row "   2.  Upgrade"
        row "   3.  Purge & Clean & Autoremove"
        row "   4.  Update & Upgrade (All)"
        row "   5.  All  (Update + Upgrade + Autoclean)"
        row "   6.  Repository Manager"
        row "   0.  Back"
        blank; sep_bot; echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"
        read -n 1 OPT; echo ""
        case $OPT in
            1) system_update 1 ;;
            2) system_update 2 ;;
            3) system_update 3 ;;
            4) system_update 4 ;;
            5) system_update 5 ;;
            6) repository_manager ;;
            0) return ;;
            *) echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# ── iftop Monitor ────────────────────────────────────────────────
iftop_monitor() {
    clear
    sep_top
    row "$(printf '%*s%s' $(( (W - 5) / 2 )) '' 'iftop')"
    sep_mid; blank

    if ! command -v iftop &>/dev/null; then
        rowc 34 "  ${RED}!! iftop is not installed !!${NC}"
        blank; sep_mid; blank
        row "   1.  Install iftop"
        row "   0.  Back"
        blank; sep_bot; echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"; read -n 1 IO; echo ""
        case $IO in
            1)
                echo -e "\n  ${CYAN}[*] Installing iftop...${NC}\n"
                if command -v apt &>/dev/null; then
                    apt update -y && apt install -y iftop
                elif command -v yum &>/dev/null; then
                    yum install -y iftop
                elif command -v dnf &>/dev/null; then
                    dnf install -y iftop
                else
                    echo -e "  ${RED}[ERR] No supported package manager found.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            0) return ;;
        esac
        return
    fi

    # Detect default interface
    local IFACE
    IFACE=$(ip route 2>/dev/null | grep '^default' | awk '{print $5}' | head -1)
    [ -z "$IFACE" ] && IFACE=""

    row "   1.  Run iftop (default interface)"
    row "   2.  Run iftop (pick interface)"
    row "   3.  Run iftop (no DNS resolve)"
    row "   0.  Back"
    blank; sep_bot; echo ""
    echo -ne "  ${YELLOW}> Select option: ${NC}"; read -n 1 IO; echo ""
    case $IO in
        1)
            clear
            echo -e "  ${CYAN}[*] Starting iftop on ${IFACE:-auto}...${NC}"
            echo -e "  ${DIM}Press  q  inside iftop to exit.${NC}\n"
            sleep 1
            if [ -n "$IFACE" ]; then
                iftop -i "$IFACE" 2>/dev/null || iftop 2>/dev/null
            else
                iftop 2>/dev/null
            fi
            echo -ne "\n  ${DIM}Press any key to return...${NC}"; read -n 1 ;;
        2)
            echo -ne "\n  ${YELLOW}Interface (e.g. eth0): ${NC}"; read -r CUST_IFACE
            [ -z "$CUST_IFACE" ] && return
            clear
            echo -e "  ${CYAN}[*] Starting iftop on $CUST_IFACE...${NC}"
            echo -e "  ${DIM}Press  q  inside iftop to exit.${NC}\n"
            sleep 1
            iftop -i "$CUST_IFACE" 2>/dev/null || echo -e "  ${RED}[ERR] Interface not found.${NC}"
            echo -ne "\n  ${DIM}Press any key to return...${NC}"; read -n 1 ;;
        3)
            clear
            echo -e "  ${CYAN}[*] Starting iftop (no DNS)...${NC}"
            echo -e "  ${DIM}Press  q  inside iftop to exit.${NC}\n"
            sleep 1
            if [ -n "$IFACE" ]; then
                iftop -n -i "$IFACE" 2>/dev/null || iftop -n 2>/dev/null
            else
                iftop -n 2>/dev/null
            fi
            echo -ne "\n  ${DIM}Press any key to return...${NC}"; read -n 1 ;;
        0) return ;;
        *) echo -e "  ${RED}Invalid.${NC}"; sleep 1 ;;
    esac
}

# ── Repository Manager ───────────────────────────────────────────
repository_manager() {
    while true; do
        clear
        sep_top
        row "$(printf '%*s%s' $(( (W - 20) / 2 )) '' 'Repository Manager')"
        sep_mid; blank

        # Detect package manager
        local PKG_MGR=""
        if command -v apt &>/dev/null || command -v apt-get &>/dev/null; then
            PKG_MGR="apt"
        elif command -v yum &>/dev/null; then
            PKG_MGR="yum"
        elif command -v dnf &>/dev/null; then
            PKG_MGR="dnf"
        fi

        if [ -z "$PKG_MGR" ]; then
            rowc 42 "  ${RED}!! No supported package manager found !!${NC}"
            blank; sep_bot; echo ""
            echo -ne "  ${DIM}Press any key...${NC}"; read -n 1; return
        fi

        row "  Package Manager : $PKG_MGR"
        blank; sep_mid; blank
        row "   1.  Auto-find best mirror (ping test)"
        row "   2.  Show current repositories"
        row "   3.  Add repository"
        row "   4.  Backup current sources"
        row "   5.  Restore backup"
        row "   0.  Back"
        blank; sep_bot; echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"
        read -r ROPT; echo ""

        case $ROPT in
            # ── Auto find best mirror ──────────────────────────
            1)
                clear
                sep_top; row "$(printf '%*s%s' $(( (W-22)/2 )) '' 'Auto-Find Best Mirror')"; sep_mid; blank

                # Detect OS
                local OS_ID OS_VER
                if [ -f /etc/os-release ]; then
                    OS_ID=$(grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
                    OS_VER=$(grep "^VERSION_ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
                fi
                [ -z "$OS_ID" ] && OS_ID=$(uname -s | tr '[:upper:]' '[:lower:]')
                row "  OS: $OS_ID $OS_VER"
                blank

                # Define mirror lists per distro
                local MIRRORS=()
                if [[ "$OS_ID" == "ubuntu" ]]; then
                    MIRRORS=(
                        # ── Iranian mirrors ──────────────────────
                        "http://ir.archive.ubuntu.com/ubuntu"
                        "http://mirror.arvancloud.ir/ubuntu"
                        "http://mirror.parsdns.com/ubuntu"
                        "http://ubuntu.razavi.ac.ir/ubuntu"
                        "http://mirror.amn.ir/ubuntu"
                        "http://mirror.iranserver.com/ubuntu"
                        "http://mirror.novin.net/ubuntu"
                        # ── Global mirrors ───────────────────────
                        "http://archive.ubuntu.com/ubuntu"
                        "http://de.archive.ubuntu.com/ubuntu"
                        "http://fr.archive.ubuntu.com/ubuntu"
                        "http://nl.archive.ubuntu.com/ubuntu"
                        "http://tr.archive.ubuntu.com/ubuntu"
                        "http://mirror.math.princeton.edu/pub/ubuntu"
                        "http://mirrors.edge.kernel.org/ubuntu"
                        "http://mirrors.163.com/ubuntu"
                        "http://mirror.kakao.com/ubuntu"
                    )
                elif [[ "$OS_ID" == "debian" ]]; then
                    MIRRORS=(
                        # ── Iranian mirrors ──────────────────────
                        "http://mirror.arvancloud.ir/debian"
                        "http://mirror.parsdns.com/debian"
                        "http://mirror.novin.net/debian"
                        "http://mirror.iranserver.com/debian"
                        "http://mirror.amn.ir/debian"
                        # ── Global mirrors ───────────────────────
                        "http://deb.debian.org/debian"
                        "http://ftp.de.debian.org/debian"
                        "http://ftp.fr.debian.org/debian"
                        "http://ftp.nl.debian.org/debian"
                        "http://ftp.us.debian.org/debian"
                        "http://ftp.uk.debian.org/debian"
                        "http://mirror.it.debian.org/debian"
                        "http://mirrors.163.com/debian"
                        "http://mirrors.tuna.tsinghua.edu.cn/debian"
                    )
                elif [[ "$OS_ID" == "centos" ]] || [[ "$OS_ID" == "rhel" ]]; then
                    MIRRORS=(
                        # ── Iranian mirrors ──────────────────────
                        "http://mirror.arvancloud.ir/centos"
                        "http://mirror.iranserver.com/centos"
                        "http://mirror.novin.net/centos"
                        # ── Global mirrors ───────────────────────
                        "http://mirror.centos.org/centos"
                        "http://centos.mirror.digitalpacific.com.au"
                        "http://mirrors.kernel.org/centos"
                        "http://mirror.math.princeton.edu/pub/centos"
                        "http://mirrors.163.com/centos"
                    )
                else
                    rowc 42 "  ${YELLOW}[!] No mirror list for '$OS_ID'.${NC}"
                    row "  Supported: ubuntu, debian, centos/rhel"
                    blank; sep_bot; echo ""
                    echo -ne "  ${DIM}Press any key...${NC}"; read -n 1; continue
                fi

                # ── Ping test all mirrors — real-time display ──
                # Table columns: |[ID]|HOST(36)|PING(8)| = 4+1+36+1+8 = 50 + 2 pipes = 52 = W
                local _C1=4 _C2=36 _C3=8   # visible widths per column (no borders)
                clear
                sep_top
                row "$(printf '%*s%s' $(( (W-22)/2 )) '' 'Auto-Find Best Mirror')"
                sep_mid
                row "  OS: $OS_ID $OS_VER"
                sep_mid
                # header row  |[ID] |HOST                                |PING    |
                printf "${CYAN}|${NC}%-${_C1}s${CYAN}|${NC}%-${_C2}s${CYAN}|${NC}%-${_C3}s${CYAN}|${NC}\n" \
                    " ID" " Mirror Host" " Ping"
                sep_mid

                local BEST_MIRROR="" BEST_PING=99999 BEST_IDX=0
                local M_URLS=() M_PINGS=() M_HOSTS=()

                local IDX=1
                for MIRROR_URL in "${MIRRORS[@]}"; do
                    local HOST PING_MS
                    HOST=$(echo "$MIRROR_URL" | sed 's|https\?://||' | cut -d/ -f1)
                    local SHORT_H; SHORT_H=$(printf "%-${_C2}s" " ${HOST:0:$(( _C2-1 ))}")
                    local ID_STR; ID_STR=$(printf "[%2d]" "$IDX")
                    # show "testing..." in real-time on same line
                    printf "${CYAN}|${NC}%-${_C1}s${CYAN}|${NC}%s${CYAN}|${NC}%-${_C3}s${CYAN}|${NC}\r" \
                        " ${ID_STR}" "${SHORT_H}" " ..."
                    PING_MS=$(ping -c 2 -W 2 "$HOST" 2>/dev/null \
                        | grep 'avg' | awk -F'/' '{printf "%d", $5}' 2>/dev/null)
                    if [ -z "$PING_MS" ] || [ "$PING_MS" = "0" ]; then
                        PING_MS=$(curl -o /dev/null -s --max-time 4 --connect-timeout 3 \
                            -w "%{time_connect}" "${MIRROR_URL}/" 2>/dev/null \
                            | awk '{printf "%d", $1*1000}')
                    fi
                    [ -z "$PING_MS" ] && PING_MS=9999

                    # print final result line (overwrite the "..." line)
                    local PING_STR COLOR_ON COLOR_OFF
                    PING_STR="${PING_MS}ms"
                    if [ "$PING_MS" -lt 100 ] 2>/dev/null; then
                        COLOR_ON=$GREEN; COLOR_OFF=$NC
                    elif [ "$PING_MS" -lt 500 ] 2>/dev/null; then
                        COLOR_ON=$YELLOW; COLOR_OFF=$NC
                    else
                        COLOR_ON=$RED; COLOR_OFF=$NC
                    fi
                    printf "${CYAN}|${NC}%-${_C1}s${CYAN}|${NC}%s${CYAN}|${NC}${COLOR_ON}%-${_C3}s${COLOR_OFF}${CYAN}|${NC}\n" \
                        " ${ID_STR}" "${SHORT_H}" " ${PING_STR}"

                    M_URLS+=("$MIRROR_URL")
                    M_PINGS+=("$PING_MS")
                    M_HOSTS+=("$HOST")

                    if [ "$PING_MS" -lt "$BEST_PING" ] 2>/dev/null; then
                        BEST_PING=$PING_MS
                        BEST_MIRROR=$MIRROR_URL
                        BEST_IDX=$IDX
                    fi
                    (( IDX++ ))
                done

                # ── Show best and let user choose ─────────────
                blank; sep_mid; blank
                rowc $(( 26 + ${#BEST_MIRROR} )) \
                    "  ${GREEN}★  Best: [${BEST_IDX}] ${BEST_MIRROR}${NC}"
                rowc 20 "  ${GREEN}   Ping: ${BEST_PING}ms${NC}"
                blank
                row "  Enter ID to apply, or press Enter for best (★)"
                sep_bot; echo ""
                echo -ne "  ${YELLOW}> Mirror ID [${BEST_IDX}]: ${NC}"; read -r SEL_ID; echo ""

                # Determine chosen mirror
                local CHOSEN_MIRROR="" CHOSEN_PING=""
                if [ -z "$SEL_ID" ]; then
                    CHOSEN_MIRROR="$BEST_MIRROR"
                    CHOSEN_PING="$BEST_PING"
                elif [[ "$SEL_ID" =~ ^[0-9]+$ ]] && \
                     [ "$SEL_ID" -ge 1 ] && \
                     [ "$SEL_ID" -le "${#M_URLS[@]}" ]; then
                    CHOSEN_MIRROR="${M_URLS[$((SEL_ID-1))]}"
                    CHOSEN_PING="${M_PINGS[$((SEL_ID-1))]}"
                else
                    echo -e "  ${RED}[ERR] Invalid ID. Cancelled.${NC}"
                    echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1; continue
                fi

                echo -e "  ${CYAN}[*] Applying: ${CHOSEN_MIRROR} (${CHOSEN_PING}ms)${NC}"
                echo -ne "  ${YELLOW}Confirm? (y/N): ${NC}"; read -n 1 APPLY; echo ""
                if [[ "$APPLY" = "y" || "$APPLY" = "Y" ]]; then
                    local BACKUP_DATE
                    BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
                    if [[ "$PKG_MGR" == "apt" ]]; then
                        cp /etc/apt/sources.list "/etc/apt/sources.list.bak.${BACKUP_DATE}" 2>/dev/null
                        if [[ "$OS_ID" == "ubuntu" ]]; then
                            local OLD_MIRROR
                            OLD_MIRROR=$(grep -oE 'http[s]?://[^ ]+' /etc/apt/sources.list 2>/dev/null \
                                | grep -v "security\|updates\|backports\|proposed" \
                                | head -1 | sed 's|/ubuntu.*||; s|/dists.*||')
                            [ -z "$OLD_MIRROR" ] && OLD_MIRROR="http://archive.ubuntu.com/ubuntu"
                            sed -i "s|${OLD_MIRROR}|${CHOSEN_MIRROR}|g" /etc/apt/sources.list 2>/dev/null
                        elif [[ "$OS_ID" == "debian" ]]; then
                            local OLD_MIRROR
                            OLD_MIRROR=$(grep -oE 'http[s]?://[^ ]+' /etc/apt/sources.list 2>/dev/null \
                                | head -1 | sed 's|/debian.*||; s|/dists.*||')
                            [ -z "$OLD_MIRROR" ] && OLD_MIRROR="http://deb.debian.org"
                            sed -i "s|${OLD_MIRROR}|${CHOSEN_MIRROR%/debian}|g" /etc/apt/sources.list 2>/dev/null
                        fi
                        echo -e "  ${GREEN}[OK] Mirror changed. Backup: sources.list.bak.${BACKUP_DATE}${NC}"
                        echo -e "  ${DIM}Run 'apt update' to apply.${NC}"
                    elif [[ "$PKG_MGR" == "yum" ]] || [[ "$PKG_MGR" == "dnf" ]]; then
                        echo -e "  ${YELLOW}[!] yum/dnf: edit /etc/yum.repos.d/ manually.${NC}"
                        echo -e "  ${DIM}Selected mirror: ${CHOSEN_MIRROR}${NC}"
                    fi
                else
                    echo -e "  ${DIM}Cancelled.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                ;;

            # ── Show current repos ─────────────────────────────
            2)
                clear
                echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${WHITE}  Current Repositories${NC}"
                echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
                if [[ "$PKG_MGR" == "apt" ]]; then
                    echo -e "${CYAN}  /etc/apt/sources.list${NC}"
                    echo -e "${DIM}  ─────────────────────${NC}"
                    if [ -s /etc/apt/sources.list ]; then
                        grep -v "^#" /etc/apt/sources.list 2>/dev/null | grep -v "^$" \
                            | grep -oE 'https?://[^ ]+' \
                            | sort -u \
                            | while IFS= read -r l; do echo "  $l"; done
                    else
                        echo -e "  ${DIM}(empty)${NC}"
                    fi
                    local HAS_D=0
                    for F in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
                        [ -f "$F" ] || continue
                        HAS_D=1
                        echo ""
                        echo -e "${CYAN}  $(basename "$F")${NC}"
                        echo -e "${DIM}  ─────────────────────${NC}"
                        grep -v "^#" "$F" 2>/dev/null | grep -v "^$" \
                            | grep -oE 'https?://[^ ]+' \
                            | sort -u \
                            | while IFS= read -r l; do echo "  $l"; done
                    done
                    [ "$HAS_D" -eq 0 ] && echo -e "\n  ${DIM}(sources.list.d/ is empty)${NC}"
                elif [[ "$PKG_MGR" == "yum" ]] || [[ "$PKG_MGR" == "dnf" ]]; then
                    for F in /etc/yum.repos.d/*.repo; do
                        [ -f "$F" ] || continue
                        echo -e "${CYAN}  $(basename "$F")${NC}"
                        echo -e "${DIM}  ─────────────────────${NC}"
                        grep -v "^#" "$F" 2>/dev/null | grep -v "^$" \
                            | grep -E '^baseurl=|^mirrorlist=' \
                            | sed 's/^baseurl=//;s/^mirrorlist=//' \
                            | while IFS= read -r l; do echo "  $l"; done
                        echo ""
                    done
                fi
                echo ""
                echo -ne "  ${DIM}Press any key...${NC}"; read -n 1
                ;;

            # ── Add repository ─────────────────────────────────
            3)
                clear
                sep_top; row "$(printf '%*s%s' $(( (W-18)/2 )) '' 'Add Repository')"; sep_mid; blank
                if [[ "$PKG_MGR" == "apt" ]]; then
                    row "   1.  Add PPA (add-apt-repository)"
                    row "   2.  Add custom deb line"
                    row "   0.  Back"
                    blank; sep_bot; echo ""
                    echo -ne "  ${YELLOW}> Select: ${NC}"; read -n 1 AR; echo ""
                    case $AR in
                        1)
                            echo -ne "\n  ${YELLOW}PPA (e.g. ppa:nginx/stable): ${NC}"; read -r PPA_NAME
                            [ -z "$PPA_NAME" ] && continue
                            if command -v add-apt-repository &>/dev/null; then
                                add-apt-repository -y "$PPA_NAME" 2>&1 | tail -5
                                apt-get update -y 2>&1 | tail -3
                                echo -e "  ${GREEN}[OK] PPA added.${NC}"
                            else
                                echo -e "  ${YELLOW}[!] add-apt-repository not found. Installing software-properties-common...${NC}"
                                apt-get install -y software-properties-common 2>/dev/null && \
                                    add-apt-repository -y "$PPA_NAME" 2>&1 | tail -5 && \
                                    apt-get update -y 2>&1 | tail -3 && \
                                    echo -e "  ${GREEN}[OK] PPA added.${NC}" || \
                                    echo -e "  ${RED}[ERR] Failed.${NC}"
                            fi
                            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                        2)
                            echo -ne "\n  ${YELLOW}Repo line (deb http://...): ${NC}"; read -r DEB_LINE
                            [ -z "$DEB_LINE" ] && continue
                            echo -ne "  ${YELLOW}File name (without .list): ${NC}"; read -r DEB_FILE
                            [ -z "$DEB_FILE" ] && DEB_FILE="custom"
                            echo "$DEB_LINE" >> "/etc/apt/sources.list.d/${DEB_FILE}.list" 2>/dev/null && \
                                echo -e "  ${GREEN}[OK] Added to /etc/apt/sources.list.d/${DEB_FILE}.list${NC}" || \
                                echo -e "  ${RED}[ERR] Failed.${NC}"
                            apt-get update -y 2>&1 | tail -3
                            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                        0) continue ;;
                    esac
                elif [[ "$PKG_MGR" == "yum" ]] || [[ "$PKG_MGR" == "dnf" ]]; then
                    echo -ne "\n  ${YELLOW}Repo URL (.repo file URL): ${NC}"; read -r REPO_URL
                    [ -z "$REPO_URL" ] && continue
                    local REPO_FILE
                    REPO_FILE="/etc/yum.repos.d/$(basename "$REPO_URL")"
                    curl -fsSL "$REPO_URL" -o "$REPO_FILE" 2>/dev/null && \
                        echo -e "  ${GREEN}[OK] Repo added: $REPO_FILE${NC}" || \
                        echo -e "  ${RED}[ERR] Failed to download repo file.${NC}"
                    echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                fi
                ;;

            # ── Backup ────────────────────────────────────────
            4)
                local BDATE BFILE
                BDATE=$(date +%Y%m%d_%H%M%S)
                if [[ "$PKG_MGR" == "apt" ]]; then
                    BFILE="/etc/apt/sources.list.bak.${BDATE}"
                    cp /etc/apt/sources.list "$BFILE" 2>/dev/null && \
                        echo -e "\n  ${GREEN}[OK] Backup saved: $BFILE${NC}" || \
                        echo -e "\n  ${RED}[ERR] Backup failed.${NC}"
                elif [[ "$PKG_MGR" == "yum" ]] || [[ "$PKG_MGR" == "dnf" ]]; then
                    BFILE="/etc/yum.repos.d.bak.${BDATE}"
                    cp -r /etc/yum.repos.d "$BFILE" 2>/dev/null && \
                        echo -e "\n  ${GREEN}[OK] Backup saved: $BFILE${NC}" || \
                        echo -e "\n  ${RED}[ERR] Backup failed.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                ;;

            # ── Restore backup ────────────────────────────────
            5)
                clear
                sep_top; row "$(printf '%*s%s' $(( (W-16)/2 )) '' 'Restore Backup')"; sep_mid; blank
                if [[ "$PKG_MGR" == "apt" ]]; then
                    local BFILES=()
                    while IFS= read -r f; do BFILES+=("$f"); done \
                        < <(ls /etc/apt/sources.list.bak.* 2>/dev/null | sort -r)
                    if [ ${#BFILES[@]} -eq 0 ]; then
                        row "  No backups found in /etc/apt/"
                        blank; sep_bot; echo ""
                        echo -ne "  ${DIM}Press any key...${NC}"; read -n 1; continue
                    fi
                    local i=1
                    for BF in "${BFILES[@]}"; do
                        row "   $i.  $(basename "$BF")"
                        (( i++ ))
                    done
                    row "   0.  Back"
                    blank; sep_bot; echo ""
                    echo -ne "  ${YELLOW}> Select: ${NC}"; read -r RIDX; echo ""
                    if [[ "$RIDX" =~ ^[0-9]+$ ]] && [ "$RIDX" -ge 1 ] && [ "$RIDX" -le "${#BFILES[@]}" ]; then
                        local CHOSEN="${BFILES[$((RIDX-1))]}"
                        cp "$CHOSEN" /etc/apt/sources.list 2>/dev/null && \
                            echo -e "  ${GREEN}[OK] Restored from $CHOSEN${NC}" || \
                            echo -e "  ${RED}[ERR] Restore failed.${NC}"
                        apt-get update -y 2>&1 | tail -3
                    else
                        echo -e "  ${DIM}Cancelled.${NC}"
                    fi
                else
                    echo -e "  ${YELLOW}[!] Manual restore: copy back your /etc/yum.repos.d.bak.*${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                ;;

            0) return ;;
            *) echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}


# ── Submenu: Monitoring ───────────────────────────────────────────
menu_monitoring() {
    while true; do
        clear
        sep_top
        row "$(printf '%*s%s' $(( (W - 21) / 2 )) '' 'Monitoring & Diagnostics')"
        sep_mid; blank
        row "   1.  SSH Sessions"
        row "   2.  Network Usage"
        row "   3.  System Usage"
        row "   4.  iftop (Live Traffic)"
        row "   5.  Speed Test"
        row "   0.  Back"
        blank; sep_bot; echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"
        read -r OPT; echo ""
        case $OPT in
            1) ssh_monitor ;;
            2) network_monitor ;;
            3) system_resources ;;
            4) iftop_monitor ;;
            5) speed_test ;;
            0) return ;;
            *) echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# ── UFW Install / Manage ─────────────────────────────────────────
ufw_install_manager() {
    while true; do
        clear
        sep_top
        row "$(printf '%*s%s' $(( (W - 19) / 2 )) '' 'UFW Firewall Manager')"
        sep_mid

        UFW_STATUS="not installed"
        UFW_ACTIVE="inactive"
        UFW_ENABLED_AT_BOOT="disabled"
        if command -v ufw &>/dev/null; then
            UFW_ACTIVE=$(ufw status 2>/dev/null | awk 'NR==1{print $2}' | tr '[:upper:]' '[:lower:]')
            UFW_ENABLED_AT_BOOT=$(systemctl is-enabled ufw 2>/dev/null || echo "disabled")
            UFW_STATUS="installed"
        fi

        blank
        if [ "$UFW_STATUS" = "not installed" ]; then
            rowc 40 "  ${RED}!! UFW is not installed !!${NC}"
            blank; sep_mid; blank
            row "   1.  Install UFW"
            row "   0.  Back"
            blank; sep_bot; echo ""
            echo -ne "  ${YELLOW}> Select option: ${NC}"
            read -n 1 UOPT; echo ""
            case $UOPT in
                1)
                    echo -e "\n  ${CYAN}[*] Installing UFW...${NC}\n"
                    if command -v apt &>/dev/null; then
                        apt update && apt install -y ufw
                    elif command -v yum &>/dev/null; then
                        yum install -y ufw
                    elif command -v dnf &>/dev/null; then
                        dnf install -y ufw
                    else
                        echo -e "  ${RED}[ERR] No supported package manager found.${NC}"
                        echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1; continue
                    fi
                    if command -v ufw &>/dev/null; then
                        echo -e "\n  ${GREEN}[OK] UFW installed.${NC}"
                    else
                        echo -e "\n  ${RED}[ERR] Installation failed.${NC}"
                    fi
                    echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                0) return ;;
            esac; continue
        fi

        # UFW installed — show status
        if [ "$UFW_ACTIVE" = "active" ]; then
            rowc 32 "  Status    : ${GREEN}Active${NC}"
        else
            rowc 34 "  Status    : ${RED}Inactive${NC}"
        fi
        if [ "$UFW_ENABLED_AT_BOOT" = "enabled" ]; then
            rowc 31 "  Boot      : ${GREEN}Enabled (auto-start)${NC}"
        else
            rowc 33 "  Boot      : ${RED}Disabled${NC}"
        fi

        # Count rules
        UFW_RULES=$(ufw status numbered 2>/dev/null | grep -c "^\[" || echo 0)
        row "  Rules     : ${UFW_RULES}"
        blank; sep_mid; blank

        row "   1.  Show All Rules"
        row "   2.  Allow Port (TCP)"
        row "   3.  Allow Port (UDP)"
        row "   4.  Allow Port (TCP+UDP)"
        row "   5.  Block Port"
        row "   6.  Allow IP"
        row "   7.  Block IP"
        row "   8.  Delete Rule by Number"
        row "   9.  Enable UFW"
        row "   10. Disable UFW"
        row "   11. Reset All Rules"
        row "   12. Uninstall UFW"
        row "   0.  Back"
        blank; sep_bot; echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"
        read -r UOPT; echo ""

        case $UOPT in
            1)
                echo ""
                ufw status numbered 2>/dev/null | while IFS= read -r l; do echo "  $l"; done
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            2)
                echo -ne "\n  ${YELLOW}Port (TCP) to allow: ${NC}"; read -r UFW_PORT
                [ -z "$UFW_PORT" ] && continue
                ufw allow "${UFW_PORT}/tcp" 2>/dev/null && \
                    echo -e "  ${GREEN}[OK] Port ${UFW_PORT}/tcp allowed.${NC}" || \
                    echo -e "  ${RED}[ERR] Failed.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            3)
                echo -ne "\n  ${YELLOW}Port (UDP) to allow: ${NC}"; read -r UFW_PORT
                [ -z "$UFW_PORT" ] && continue
                ufw allow "${UFW_PORT}/udp" 2>/dev/null && \
                    echo -e "  ${GREEN}[OK] Port ${UFW_PORT}/udp allowed.${NC}" || \
                    echo -e "  ${RED}[ERR] Failed.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            4)
                echo -ne "\n  ${YELLOW}Port (TCP+UDP) to allow: ${NC}"; read -r UFW_PORT
                [ -z "$UFW_PORT" ] && continue
                ufw allow "$UFW_PORT" 2>/dev/null && \
                    echo -e "  ${GREEN}[OK] Port ${UFW_PORT} (tcp+udp) allowed.${NC}" || \
                    echo -e "  ${RED}[ERR] Failed.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            5)
                echo -ne "\n  ${YELLOW}Port to block: ${NC}"; read -r UFW_PORT
                [ -z "$UFW_PORT" ] && continue
                ufw deny "$UFW_PORT" 2>/dev/null && \
                    echo -e "  ${GREEN}[OK] Port ${UFW_PORT} blocked.${NC}" || \
                    echo -e "  ${RED}[ERR] Failed.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            6)
                echo -ne "\n  ${YELLOW}IP to allow: ${NC}"; read -r UFW_IP
                [ -z "$UFW_IP" ] && continue
                ufw allow from "$UFW_IP" 2>/dev/null && \
                    echo -e "  ${GREEN}[OK] IP ${UFW_IP} allowed.${NC}" || \
                    echo -e "  ${RED}[ERR] Failed.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            7)
                echo -ne "\n  ${YELLOW}IP to block: ${NC}"; read -r UFW_IP
                [ -z "$UFW_IP" ] && continue
                ufw deny from "$UFW_IP" 2>/dev/null && \
                    echo -e "  ${GREEN}[OK] IP ${UFW_IP} blocked.${NC}" || \
                    echo -e "  ${RED}[ERR] Failed.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            8)
                echo ""
                ufw status numbered 2>/dev/null | while IFS= read -r l; do echo "  $l"; done
                echo -ne "\n  ${YELLOW}Rule number to delete: ${NC}"; read -r UFW_RNUM
                [ -z "$UFW_RNUM" ] && continue
                echo "y" | ufw delete "$UFW_RNUM" 2>/dev/null && \
                    echo -e "  ${GREEN}[OK] Rule $UFW_RNUM deleted.${NC}" || \
                    echo -e "  ${RED}[ERR] Failed.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            9)
                echo "y" | ufw enable 2>/dev/null && \
                    echo -e "  ${GREEN}[OK] UFW enabled.${NC}" || \
                    echo -e "  ${RED}[ERR] Failed.${NC}"
                sleep 2 ;;
            10)
                ufw disable 2>/dev/null && \
                    echo -e "  ${YELLOW}[OK] UFW disabled.${NC}" || \
                    echo -e "  ${RED}[ERR] Failed.${NC}"
                sleep 2 ;;
            11)
                echo -ne "\n  ${RED}Reset ALL UFW rules? (y/N): ${NC}"; read -n 1 C; echo ""
                if [[ "$C" = "y" || "$C" = "Y" ]]; then
                    echo "y" | ufw reset 2>/dev/null && \
                        echo -e "  ${GREEN}[OK] UFW rules reset.${NC}" || \
                        echo -e "  ${RED}[ERR] Failed.${NC}"
                else
                    echo -e "  ${DIM}Cancelled.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            12)
                echo -ne "\n  ${RED}Uninstall UFW? (y/N): ${NC}"; read -n 1 C; echo ""
                if [[ "$C" = "y" || "$C" = "Y" ]]; then
                    ufw disable 2>/dev/null
                    if command -v apt &>/dev/null; then
                        apt remove -y ufw 2>/dev/null; apt autoremove -y 2>/dev/null
                    elif command -v yum &>/dev/null; then
                        yum remove -y ufw 2>/dev/null
                    elif command -v dnf &>/dev/null; then
                        dnf remove -y ufw 2>/dev/null
                    fi
                    echo -e "  ${GREEN}[OK] UFW removed.${NC}"
                    echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1; return
                else
                    echo -e "  ${DIM}Cancelled.${NC}"; sleep 1
                fi ;;
            0) return ;;
            *) echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# ── Change Hostname ───────────────────────────────────────────────
change_hostname() {
    while true; do
        clear
        sep_top
        row "$(printf '%*s%s' $(( (W - 15) / 2 )) '' 'Change Hostname')"
        sep_mid; blank
        local CUR_HOST
        CUR_HOST=$(hostname 2>/dev/null || echo "N/A")
        row "  Current Hostname : $CUR_HOST"
        blank; sep_bot; echo ""
        echo -ne "  ${YELLOW}New hostname (or 0 to cancel): ${NC}"; read -r NEW_HOST
        [ "$NEW_HOST" = "0" ] || [ -z "$NEW_HOST" ] && return
        if ! echo "$NEW_HOST" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'; then
            echo -e "  ${RED}Invalid hostname. Use letters, numbers, and hyphens only.${NC}"
            sleep 2; continue
        fi
        # Apply hostname
        echo "$NEW_HOST" > /etc/hostname 2>/dev/null || true
        hostnamectl set-hostname "$NEW_HOST" 2>/dev/null || hostname "$NEW_HOST" 2>/dev/null || true
        # Update /etc/hosts
        if grep -q "127.0.1.1" /etc/hosts 2>/dev/null; then
            sed -i "s/127\.0\.1\.1.*/127.0.1.1\t${NEW_HOST}/" /etc/hosts 2>/dev/null
        else
            echo -e "127.0.1.1\t${NEW_HOST}" >> /etc/hosts 2>/dev/null
        fi
        echo -e "\n  ${GREEN}[OK] Hostname changed to '${NEW_HOST}'.${NC}"
        echo -e "  ${DIM}A reconnect or reboot may be needed to reflect everywhere.${NC}"
        echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
        return
    done
}

# ── Submenu: Network ──────────────────────────────────────────────
menu_network() {
    while true; do
        clear
        sep_top
        row "$(printf '%*s%s' $(( (W - 20) / 2 )) '' 'Network Configuration')"
        sep_mid; blank
        row "   1.  Netplan Manager (Network Config GUI)"
        row "   2.  DNS Manager"
        row "   3.  Change Hostname"
        row "   4.  MTR"
        row "   5.  MTU Finder"
        row "   6.  BBR / BBRv2 / ACCEL"
        row "   0.  Back"
        blank; sep_bot; echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"
        read -r OPT; echo ""
        case $OPT in
            1) menu_netplan ;;
            2) dns_manager ;;
            3) change_hostname ;;
            4) mtr_tool ;;
            5) mtu_finder ;;
            6) bbr_manager ;;
            0) return ;;
            *) echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# ── Submenu: Security & Firewall ──────────────────────────────────
menu_security() {
    while true; do
        clear
        sep_top
        row "$(printf '%*s%s' $(( (W - 18) / 2 )) '' 'Security & Firewall')"
        sep_mid; blank
        row "   1.  Port Manager"
        row "   2.  IPTables Manager"
        row "   3.  NAT Manager"
        row "   4.  Install / Manage UFW"
        row "   5.  Fail2ban Manager"
        row "   0.  Back"
        blank; sep_bot; echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"
        read -r OPT; echo ""
        case $OPT in
            1) port_manager ;;
            2) iptables_manager ;;
            3) nat_manager ;;
            4) ufw_install_manager ;;
            5) fail2ban_manager ;;
            0) return ;;
            *) echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# ── Netplan Manager (Graphical Network Config) ─────────────────────
# Manages a dedicated, self-contained netplan file so it never clobbers
# existing cloud-init / distro netplan configs. State is kept in simple
# shell-sourceable files under $_NP_STATE_DIR (one per interface) and the
# real YAML under $_NP_YAML is fully regenerated from that state every time.

_NP_STATE_DIR="/etc/svmngr-netplan-state"
_NP_YAML="/etc/netplan/90-server-manager.yaml"
_NP_BACKUP_DIR="/etc/svmngr-netplan-backups"
_NPGUI=""

_np_ensure_dirs() {
    mkdir -p "$_NP_STATE_DIR" "$_NP_BACKUP_DIR" /etc/netplan 2>/dev/null
}

# ── Detect / install a graphical (TUI) front-end ────────────────────
_np_detect_gui() {
    if command -v whiptail &>/dev/null; then
        _NPGUI="whiptail"
    elif command -v dialog &>/dev/null; then
        _NPGUI="dialog"
    else
        _NPGUI=""
        if command -v apt &>/dev/null || command -v apt-get &>/dev/null; then
            echo -e "  ${CYAN}[*] Installing 'whiptail' for the graphical interface...${NC}"
            (apt-get install -y whiptail 2>/dev/null || apt install -y whiptail 2>/dev/null) >/dev/null
            command -v whiptail &>/dev/null && _NPGUI="whiptail"
        fi
    fi
}

# ── Thin GUI wrappers (fallback to the script's classic text UI) ────
_np_msgbox() {  # title text
    local TITLE="$1" TEXT="$2"
    if [ -n "$_NPGUI" ]; then
        $_NPGUI --title " $TITLE " --msgbox "$TEXT" 22 76
    else
        clear; sep_top; row "  $TITLE"; sep_bot; echo ""
        echo -e "$TEXT" | while IFS= read -r l; do echo "  $l"; done
        echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
    fi
}

_np_textbox() {  # title file
    local TITLE="$1" FILE="$2"
    if [ -n "$_NPGUI" ] && [ "$_NPGUI" = "whiptail" ]; then
        whiptail --title " $TITLE " --scrolltext --textbox "$FILE" 26 78
    elif [ -n "$_NPGUI" ] && [ "$_NPGUI" = "dialog" ]; then
        dialog --title " $TITLE " --textbox "$FILE" 26 78
    else
        clear; sep_top; row "  $TITLE"; sep_bot; echo ""
        cat "$FILE" 2>/dev/null | while IFS= read -r l; do echo "  $l"; done
        echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
    fi
}

_np_yesno() {  # title text  -> return 0=yes 1=no
    local TITLE="$1" TEXT="$2"
    if [ -n "$_NPGUI" ]; then
        $_NPGUI --title " $TITLE " --yesno "$TEXT" 12 76
        return $?
    else
        echo -ne "  ${RED}${TEXT} (y/N): ${NC}"; local R; read -n 1 R; echo ""
        [[ "$R" = "y" || "$R" = "Y" ]] && return 0 || return 1
    fi
}

_np_input() {  # title prompt default  -> prints result on stdout, exit 1 if cancelled
    local TITLE="$1" PROMPT="$2" DEFAULT="$3"
    if [ -n "$_NPGUI" ]; then
        local RES EX
        RES=$($_NPGUI --title " $TITLE " --inputbox "$PROMPT" 11 76 "$DEFAULT" 3>&1 1>&2 2>&3)
        EX=$?
        [ $EX -ne 0 ] && return 1
        echo "$RES"; return 0
    else
        echo -ne "  ${YELLOW}${PROMPT} [${DEFAULT}]: ${NC}" >&2
        local RES; read -r RES
        [ -z "$RES" ] && RES="$DEFAULT"
        echo "$RES"; return 0
    fi
}

# menu: title text tag1 item1 tag2 item2 ...  -> prints chosen tag, exit 1 if cancelled
_np_menu() {
    local TITLE="$1" TEXT="$2"; shift 2
    if [ -n "$_NPGUI" ]; then
        local RES EX
        RES=$($_NPGUI --title " $TITLE " --menu "$TEXT" 24 76 14 "$@" 3>&1 1>&2 2>&3)
        EX=$?
        [ $EX -ne 0 ] && return 1
        echo "$RES"; return 0
    else
        clear; sep_top; row "  $TITLE"; sep_mid; blank
        echo -e "  ${DIM}${TEXT}${NC}"; echo ""
        local TAGS=()
        while [ $# -gt 0 ]; do
            echo "   $1)  $2"
            TAGS+=("$1")
            shift 2
        done
        echo ""; sep_bot; echo ""
        echo -ne "  ${YELLOW}> Select (0=back): ${NC}"
        local SEL; read -r SEL
        [ -z "$SEL" ] && return 1
        echo "$SEL"; return 0
    fi
}

# checklist: title text tag1 item1 status1 tag2 item2 status2 ... -> prints chosen tags
_np_checklist() {
    local TITLE="$1" TEXT="$2"; shift 2
    if [ -n "$_NPGUI" ]; then
        local RES EX
        RES=$($_NPGUI --title " $TITLE " --checklist "$TEXT" 24 76 14 "$@" 3>&1 1>&2 2>&3)
        EX=$?
        [ $EX -ne 0 ] && return 1
        echo "$RES"; return 0
    else
        clear; sep_top; row "  $TITLE"; sep_mid; blank
        echo -e "  ${DIM}${TEXT}${NC}"; echo ""
        local TAGS=()
        while [ $# -gt 0 ]; do
            echo "   ${1})  $2"
            TAGS+=("$1")
            shift 3
        done
        echo ""
        echo -ne "  ${YELLOW}Enter tags separated by space (blank=none): ${NC}"
        local SEL; read -r SEL
        echo "$SEL"; return 0
    fi
}

# ── State helpers ────────────────────────────────────────────────────
_np_iface_file() { echo "${_NP_STATE_DIR}/${1}.conf"; }

_np_load_iface() {  # iface -> sets NP_* globals
    NP_DHCP4="no"; NP_DHCP6="no"; NP_ADDR=""; NP_GW4=""; NP_DNS=""; NP_SEARCH=""; NP_ROUTES=""
    local F; F=$(_np_iface_file "$1")
    [ -f "$F" ] && source "$F"
}

_np_save_iface() {  # iface
    local F; F=$(_np_iface_file "$1")
    {
        printf 'NP_DHCP4=%q\n'  "$NP_DHCP4"
        printf 'NP_DHCP6=%q\n'  "$NP_DHCP6"
        printf 'NP_ADDR=%q\n'   "$NP_ADDR"
        printf 'NP_GW4=%q\n'    "$NP_GW4"
        printf 'NP_DNS=%q\n'    "$NP_DNS"
        printf 'NP_SEARCH=%q\n' "$NP_SEARCH"
        printf 'NP_ROUTES=%q\n' "$NP_ROUTES"
    } > "$F"
}

_np_list_configured() {
    ls "$_NP_STATE_DIR" 2>/dev/null | sed -n 's/\.conf$//p'
}

_np_list_system_ifaces() {
    ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | sed 's/@.*//' | grep -vE '^(lo)$'
}

_np_all_known_ifaces() {
    { _np_list_system_ifaces; _np_list_configured; } | sort -u
}

# ── YAML generation (regenerated fully from state every time) ──────
_np_rebuild_yaml() {
    _np_ensure_dirs
    local IFACES; IFACES=$(_np_list_configured)
    {
        echo "# Managed by Server Manager — Netplan GUI. Do not edit by hand."
        echo "network:"
        echo "  version: 2"
        echo "  renderer: networkd"
        if [ -z "$IFACES" ]; then
            echo "  ethernets: {}"
        else
            echo "  ethernets:"
            local IFACE
            for IFACE in $IFACES; do
                _np_load_iface "$IFACE"
                echo "    ${IFACE}:"
                if [ "$NP_DHCP4" = "yes" ]; then
                    echo "      dhcp4: true"
                else
                    echo "      dhcp4: false"
                fi
                [ "$NP_DHCP6" = "yes" ] && echo "      dhcp6: true"

                if [ -n "$NP_ADDR" ]; then
                    local ADDR_LIST
                    ADDR_LIST=$(echo "$NP_ADDR" | tr ',' '\n' | sed '/^$/d' | sed 's/^ *//;s/ *$//' | paste -sd, -)
                    echo "      addresses: [${ADDR_LIST}]"
                fi

                # routes: default gateway (if set) + any extra routes
                local HAVE_ROUTES="no"
                if [ -n "$NP_GW4" ] || [ -n "$NP_ROUTES" ]; then
                    HAVE_ROUTES="yes"
                    echo "      routes:"
                    if [ -n "$NP_GW4" ]; then
                        echo "        - to: default"
                        echo "          via: ${NP_GW4}"
                    fi
                    if [ -n "$NP_ROUTES" ]; then
                        local R TO VIA
                        IFS=';' read -ra _RT <<< "$NP_ROUTES"
                        for R in "${_RT[@]}"; do
                            [ -z "$R" ] && continue
                            TO="${R%%|*}"; VIA="${R##*|}"
                            echo "        - to: ${TO}"
                            echo "          via: ${VIA}"
                        done
                    fi
                fi

                if [ -n "$NP_DNS" ] || [ -n "$NP_SEARCH" ]; then
                    echo "      nameservers:"
                    if [ -n "$NP_DNS" ]; then
                        local DNS_LIST
                        DNS_LIST=$(echo "$NP_DNS" | tr ',' '\n' | sed '/^$/d' | sed 's/^ *//;s/ *$//' | paste -sd, -)
                        echo "        addresses: [${DNS_LIST}]"
                    fi
                    if [ -n "$NP_SEARCH" ]; then
                        local SR_LIST
                        SR_LIST=$(echo "$NP_SEARCH" | tr ',' '\n' | sed '/^$/d' | sed 's/^ *//;s/ *$//' | paste -sd, -)
                        echo "        search: [${SR_LIST}]"
                    fi
                fi
            done
        fi
    } > "$_NP_YAML" 2>/dev/null
    rm -f "${_NP_YAML}.draft" 2>/dev/null
    chmod 600 "$_NP_YAML" 2>/dev/null
    chown root:root "$_NP_YAML" 2>/dev/null
}

# ── Backup / Restore ─────────────────────────────────────────────────
_np_backup_now() {
    _np_ensure_dirs
    local TS; TS=$(date +%Y%m%d-%H%M%S)
    tar czf "${_NP_BACKUP_DIR}/netplan-${TS}.tar.gz" -C / etc/netplan 2>/dev/null
    echo "${_NP_BACKUP_DIR}/netplan-${TS}.tar.gz"
}

_np_backup_restore_menu() {
    while true; do
        local CHOICE
        CHOICE=$(_np_menu "Backup / Restore" "Manage netplan backups" \
            1 "Create Backup Now" \
            2 "Restore From Backup" \
            3 "List Backups" \
            0 "Back") || return
        case "$CHOICE" in
            1)
                local B; B=$(_np_backup_now)
                _np_msgbox "Backup" "Backup created:\n${B}" ;;
            2)
                local FILES=() i=1
                while IFS= read -r f; do
                    FILES+=("$i" "$(basename "$f")")
                    i=$((i+1))
                done < <(ls -1t "${_NP_BACKUP_DIR}"/*.tar.gz 2>/dev/null)
                if [ "${#FILES[@]}" -eq 0 ]; then
                    _np_msgbox "Restore" "No backups found."
                    continue
                fi
                local SEL; SEL=$(_np_menu "Restore Backup" "Choose a backup to restore" "${FILES[@]}" 0 "Cancel") || continue
                [ "$SEL" = "0" ] && continue
                local IDX=$((SEL))
                local PICKED; PICKED=$(ls -1t "${_NP_BACKUP_DIR}"/*.tar.gz 2>/dev/null | sed -n "${IDX}p")
                [ -z "$PICKED" ] && continue
                if _np_yesno "Confirm Restore" "This will OVERWRITE /etc/netplan with:\n${PICKED}\n\nA safety backup of the CURRENT state will be made first.\n\nContinue?"; then
                    _np_backup_now >/dev/null
                    tar xzf "$PICKED" -C / 2>/dev/null
                    _np_msgbox "Restore" "Restored. Review and Apply from the Apply menu when ready."
                fi ;;
            3)
                local LIST="/tmp/.np_backups_$$"
                ls -lh "${_NP_BACKUP_DIR}" 2>/dev/null > "$LIST"
                [ -s "$LIST" ] || echo "No backups yet." > "$LIST"
                _np_textbox "Backups" "$LIST"
                rm -f "$LIST" ;;
            0) return ;;
        esac
    done
}

# ── Apply / Validate ──────────────────────────────────────────────────
_np_apply_menu() {
    while true; do
        local CHOICE
        CHOICE=$(_np_menu "Apply Changes" "Render: ${_NP_YAML}" \
            1 "Validate Only (safe, no changes applied)" \
            2 "Apply with Auto-Rollback (netplan try, recommended)" \
            3 "Apply Now (immediate, may drop SSH if misconfigured)" \
            0 "Back") || return
        case "$CHOICE" in
            1)
                local OUT; OUT=$(netplan generate --debug 2>&1)
                local EX=$?
                local LOG="/tmp/.np_validate_$$"
                if [ $EX -eq 0 ]; then
                    echo "[OK] Configuration is syntactically valid." > "$LOG"
                else
                    echo "[ERR] Validation failed:" > "$LOG"
                fi
                echo "" >> "$LOG"
                echo "$OUT" >> "$LOG"
                _np_textbox "Validation Result" "$LOG"
                rm -f "$LOG" ;;
            2)
                _np_backup_now >/dev/null
                if _np_yesno "netplan try" "This will apply the config for 120 seconds.\nIf you do NOT confirm within that window\n(by pressing ENTER in the terminal),\nit auto-reverts to the previous config.\n\nProceed?"; then
                    clear
                    sep_top; row "  netplan try — press ENTER to keep, wait to revert"; sep_bot; echo ""
                    netplan try --timeout 120
                    echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                fi ;;
            3)
                _np_backup_now >/dev/null
                if _np_yesno "Apply Now" "WARNING: this applies network changes immediately.\nIf the new config is wrong you may lose SSH access.\n\nA backup was just taken (see Backup/Restore menu).\n\nApply now?"; then
                    clear
                    sep_top; row "  Applying netplan configuration..."; sep_bot; echo ""
                    netplan apply 2>&1
                    echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1
                fi ;;
            0) return ;;
        esac
    done
}

# ── Interface configuration wizard ───────────────────────────────────
_np_configure_iface() {
    local IFLIST=() i=1
    local F
    while IFS= read -r F; do
        IFLIST+=("$F" "interface")
    done < <(_np_all_known_ifaces)
    [ "${#IFLIST[@]}" -eq 0 ] && { _np_msgbox "Configure Interface" "No network interfaces detected."; return; }

    local IFACE
    IFACE=$(_np_menu "Configure Interface" "Select an interface to configure" "${IFLIST[@]}" 0 "Back") || return
    [ "$IFACE" = "0" ] && return

    _np_load_iface "$IFACE"

    local MODE="dhcp"
    [ "$NP_DHCP4" != "yes" ] && MODE="static"
    local MCHOICE
    MCHOICE=$(_np_menu "Mode — $IFACE" "Current: ${MODE}" \
        1 "DHCP (automatic)" \
        2 "Static IP" \
        0 "Cancel") || return

    case "$MCHOICE" in
        1)
            NP_DHCP4="yes"; NP_ADDR=""; NP_GW4=""
            ;;
        2)
            NP_DHCP4="no"
            local A; A=$(_np_input "Static Address — $IFACE" "IP address with CIDR (e.g. 10.0.0.5/24):" "$NP_ADDR") || return
            [ -z "$A" ] && { _np_msgbox "Cancelled" "Address cannot be empty."; return; }
            NP_ADDR="$A"
            local G; G=$(_np_input "Gateway — $IFACE" "Default gateway (blank = none):" "$NP_GW4") || return
            NP_GW4="$G"
            ;;
        *) return ;;
    esac

    local D; D=$(_np_input "DNS Servers — $IFACE" "Comma-separated DNS servers (blank = none):" "$NP_DNS") || return
    NP_DNS="$D"
    local S; S=$(_np_input "Search Domains — $IFACE" "Comma-separated search domains (blank = none):" "$NP_SEARCH") || return
    NP_SEARCH="$S"

    if _np_yesno "Enable DHCPv6?" "Also enable DHCPv6 (dhcp6) on $IFACE?"; then
        NP_DHCP6="yes"
    else
        NP_DHCP6="no"
    fi

    _np_save_iface "$IFACE"
    _np_rebuild_yaml

    local PREVIEW="/tmp/.np_preview_$$"
    cp "$_NP_YAML" "$PREVIEW" 2>/dev/null
    _np_textbox "Preview — ${_NP_YAML}" "$PREVIEW"
    rm -f "$PREVIEW"

    if _np_yesno "Apply Now?" "Configuration saved for $IFACE.\nOpen the Apply menu now?"; then
        _np_apply_menu
    fi
}

_np_manage_routes() {
    local IFLIST=() F
    while IFS= read -r F; do IFLIST+=("$F" "configured"); done < <(_np_list_configured)
    [ "${#IFLIST[@]}" -eq 0 ] && { _np_msgbox "Manage Routes" "No configured interfaces yet.\nConfigure an interface first."; return; }

    local IFACE
    IFACE=$(_np_menu "Manage Routes" "Select interface" "${IFLIST[@]}" 0 "Back") || return
    [ "$IFACE" = "0" ] && return
    _np_load_iface "$IFACE"

    while true; do
        local ROUTE_DISP="(none)"
        [ -n "$NP_ROUTES" ] && ROUTE_DISP=$(echo "$NP_ROUTES" | tr ';' '\n' | sed '/^$/d' | sed 's/|/  via  /')
        local CHOICE
        CHOICE=$(_np_menu "Routes — $IFACE" "Extra static routes:\n${ROUTE_DISP}" \
            1 "Add Route" \
            2 "Remove a Route" \
            0 "Back") || return
        case "$CHOICE" in
            1)
                local TO; TO=$(_np_input "Add Route — $IFACE" "Destination network (e.g. 192.168.50.0/24):" "") || continue
                [ -z "$TO" ] && continue
                local VIA; VIA=$(_np_input "Add Route — $IFACE" "Via (gateway IP):" "") || continue
                [ -z "$VIA" ] && continue
                if [ -n "$NP_ROUTES" ]; then
                    NP_ROUTES="${NP_ROUTES};${TO}|${VIA}"
                else
                    NP_ROUTES="${TO}|${VIA}"
                fi
                _np_save_iface "$IFACE"; _np_rebuild_yaml ;;
            2)
                [ -z "$NP_ROUTES" ] && { _np_msgbox "Remove Route" "No extra routes to remove."; continue; }
                local TAGS=() n=1 R
                IFS=';' read -ra _RT <<< "$NP_ROUTES"
                for R in "${_RT[@]}"; do
                    [ -z "$R" ] && continue
                    TAGS+=("$n" "${R/|/ via }")
                    n=$((n+1))
                done
                local SEL; SEL=$(_np_menu "Remove Route — $IFACE" "Select route to remove" "${TAGS[@]}" 0 "Cancel") || continue
                [ "$SEL" = "0" ] && continue
                local NEW="" idx=1
                for R in "${_RT[@]}"; do
                    [ -z "$R" ] && continue
                    if [ "$idx" != "$SEL" ]; then
                        [ -n "$NEW" ] && NEW="${NEW};${R}" || NEW="${R}"
                    fi
                    idx=$((idx+1))
                done
                NP_ROUTES="$NEW"
                _np_save_iface "$IFACE"; _np_rebuild_yaml ;;
            0) return ;;
        esac
    done
}

_np_remove_iface() {
    local IFLIST=() F
    while IFS= read -r F; do IFLIST+=("$F" "configured"); done < <(_np_list_configured)
    [ "${#IFLIST[@]}" -eq 0 ] && { _np_msgbox "Remove Configuration" "No configured interfaces to remove."; return; }
    local IFACE
    IFACE=$(_np_menu "Remove Configuration" "Select interface to remove from the managed config" "${IFLIST[@]}" 0 "Back") || return
    [ "$IFACE" = "0" ] && return
    if _np_yesno "Confirm" "Remove ALL managed netplan settings for '$IFACE'?\n(The interface itself is not touched, only this tool's config for it.)"; then
        rm -f "$(_np_iface_file "$IFACE")"
        _np_rebuild_yaml
        _np_msgbox "Removed" "'$IFACE' removed from the managed config.\nDon't forget to Apply for it to take effect."
    fi
}

_np_status() {
    local F="/tmp/.np_status_$$"
    {
        echo "[Interfaces]"
        ip -brief addr show 2>/dev/null || ip addr show 2>/dev/null
        echo ""
        echo "[Default Route]"
        ip route show default 2>/dev/null
        echo ""
        echo "[DNS]"
        if command -v resolvectl &>/dev/null; then
            resolvectl status 2>/dev/null | grep -E "DNS Servers|Link" 
        else
            grep -i nameserver /etc/resolv.conf 2>/dev/null
        fi
    } > "$F"
    _np_textbox "Live Network Status" "$F"
    rm -f "$F"
}

_np_view_others() {
    local OTHERS=() i=1 f
    while IFS= read -r f; do
        OTHERS+=("$i" "$(basename "$f")")
        i=$((i+1))
    done < <(ls -1 /etc/netplan/*.yaml /etc/netplan/*.yml 2>/dev/null | grep -v "^${_NP_YAML}$")
    if [ "${#OTHERS[@]}" -eq 0 ]; then
        _np_msgbox "Other Netplan Files" "No other netplan files found besides the managed one."
        return
    fi
    local SEL; SEL=$(_np_menu "Other Netplan Files" "Read-only — these belong to the system / cloud-init, not this tool" "${OTHERS[@]}" 0 "Back") || return
    [ "$SEL" = "0" ] && return
    local PICKED; PICKED=$(ls -1 /etc/netplan/*.yaml /etc/netplan/*.yml 2>/dev/null | grep -v "^${_NP_YAML}$" | sed -n "${SEL}p")
    [ -n "$PICKED" ] && _np_textbox "$(basename "$PICKED")" "$PICKED"
}

# ── Main Netplan menu ────────────────────────────────────────────────
menu_netplan() {
    if ! command -v netplan &>/dev/null; then
        clear
        sep_top; row "  Netplan Manager"; sep_mid; echo ""
        echo -e "  ${RED}[!] 'netplan' is not installed on this system.${NC}"
        if command -v apt &>/dev/null; then
            echo -ne "\n  ${YELLOW}Install netplan.io now? (y/N): ${NC}"; read -n 1 INST; echo ""
            if [[ "$INST" = "y" || "$INST" = "Y" ]]; then
                apt update -y 2>/dev/null; apt install -y netplan.io 2>/dev/null
                command -v netplan &>/dev/null || { echo -e "  ${RED}[ERR] Install failed.${NC}"; sleep 2; return; }
            else
                return
            fi
        else
            echo -e "  ${DIM}No apt available to auto-install. Aborting.${NC}"
            sleep 2; return
        fi
    fi

    _np_ensure_dirs
    _np_detect_gui
    [ -z "$_NPGUI" ] && _np_msgbox "Netplan Manager" "Graphical front-end (whiptail/dialog) not available.\nFalling back to the classic text menu — still fully functional."

    while true; do
        local CHOICE
        CHOICE=$(_np_menu "Netplan Manager" "Graphical network configuration\nManaged file: ${_NP_YAML}" \
            1 "Live Network Status" \
            2 "Configure Interface (DHCP / Static)" \
            3 "Manage Extra Routes" \
            4 "Remove Interface Configuration" \
            5 "View Managed Config (YAML)" \
            6 "View Other Netplan Files (read-only)" \
            7 "Apply / Validate Changes" \
            8 "Backup / Restore" \
            0 "Back") || return

        case "$CHOICE" in
            1) _np_status ;;
            2) _np_configure_iface ;;
            3) _np_manage_routes ;;
            4) _np_remove_iface ;;
            5)
                _np_rebuild_yaml
                _np_textbox "Managed Config" "$_NP_YAML" ;;
            6) _np_view_others ;;
            7) _np_apply_menu ;;
            8) _np_backup_restore_menu ;;
            0) return ;;
        esac
    done
}

# ── Submenu: Panel & SSL ──────────────────────────────────────────
menu_panel() {
    while true; do
        clear
        sep_top
        row "$(printf '%*s%s' $(( (W - 12) / 2 )) '' 'Panel & SSL')"
        sep_mid; blank
        row "   1.  SSL Certificate Checker"
        row "   2.  Install VPN Panel"
        row "   3.  Check Port 80 & 443"
        row "   0.  Back"
        blank; sep_bot; echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"
        read -r OPT; echo ""
        case $OPT in
            1) ssl_checker ;;
            2) install_xui ;;
            3) check_web_ports ;;
            0) return ;;
            *) echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# ════════════════════════════════════════════════════════════════
# ── Telegram Notifier ───────────────────────────────────────────
# ════════════════════════════════════════════════════════════════

TG_CFG="/etc/server_manager_tg.conf"

_tg_load_cfg() {
    TG_BOT_TOKEN=""; TG_CHAT_ID=""
    [ -f "$TG_CFG" ] && source "$TG_CFG" 2>/dev/null
}

_tg_save_cfg() {
    cat > "$TG_CFG" <<EOF
TG_BOT_TOKEN="${TG_BOT_TOKEN}"
TG_CHAT_ID="${TG_CHAT_ID}"
EOF
    chmod 600 "$TG_CFG" 2>/dev/null
}

# Send a message via Telegram Bot API
_tg_send() {
    local MSG="$1"
    local PARSE="${2:-HTML}"
    [ -z "$TG_BOT_TOKEN" ] || [ -z "$TG_CHAT_ID" ] && return 1
    curl -s --max-time 10 \
        "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TG_CHAT_ID}" \
        -d "parse_mode=${PARSE}" \
        --data-urlencode "text=${MSG}" \
        >/dev/null 2>&1
    return $?
}

# Test connection and return result string
_tg_test() {
    [ -z "$TG_BOT_TOKEN" ] || [ -z "$TG_CHAT_ID" ] && echo "not_configured" && return
    local RES
    RES=$(curl -s --max-time 8 \
        "https://api.telegram.org/bot${TG_BOT_TOKEN}/getMe" 2>/dev/null)
    echo "$RES" | grep -q '"ok":true' && echo "ok" || echo "fail"
}

# ── Build report strings ─────────────────────────────────────────

_tg_build_traffic_report() {
    local HOURS="${1:-6}"
    local IFACE
    IFACE=$(ip route 2>/dev/null | grep '^default' | awk '{print $5}' | head -1)
    [ -z "$IFACE" ] && IFACE="eth0"

    local RX_NOW TX_NOW RX_PREV TX_PREV
    RX_NOW=$(awk -v iface="${IFACE}:" '$1==iface{print $2}' /proc/net/dev 2>/dev/null || echo 0)
    TX_NOW=$(awk -v iface="${IFACE}:" '$1==iface{print $10}' /proc/net/dev 2>/dev/null || echo 0)

    # Store snapshot for delta calculation
    local SNAP_FILE="/tmp/.tg_traffic_snap"
    local SNAP_TIME_FILE="/tmp/.tg_traffic_snap_time"

    if [ -f "$SNAP_FILE" ] && [ -f "$SNAP_TIME_FILE" ]; then
        RX_PREV=$(awk 'NR==1{print $1}' "$SNAP_FILE" 2>/dev/null || echo 0)
        TX_PREV=$(awk 'NR==1{print $2}' "$SNAP_FILE" 2>/dev/null || echo 0)
        local SNAP_TS NOW_TS ELAPSED_H
        SNAP_TS=$(cat "$SNAP_TIME_FILE" 2>/dev/null || echo 0)
        NOW_TS=$(date +%s)
        ELAPSED_H=$(( (NOW_TS - SNAP_TS) / 3600 ))
        [ "$ELAPSED_H" -le 0 ] && ELAPSED_H=1
    else
        RX_PREV=0; TX_PREV=0; ELAPSED_H=$HOURS
    fi

    echo "${RX_NOW} ${TX_NOW}" > "$SNAP_FILE"
    date +%s > "$SNAP_TIME_FILE"

    local RX_DELTA TX_DELTA
    RX_DELTA=$(( RX_NOW - RX_PREV ))
    TX_DELTA=$(( TX_NOW - TX_PREV ))
    [ "$RX_DELTA" -lt 0 ] && RX_DELTA=0
    [ "$TX_DELTA" -lt 0 ] && TX_DELTA=0

    _fmt_bytes() {
        local B=$1
        if   [ "$B" -gt 1073741824 ]; then awk "BEGIN{printf \"%.2f GB\",$B/1073741824}"
        elif [ "$B" -gt 1048576 ];    then awk "BEGIN{printf \"%.2f MB\",$B/1048576}"
        elif [ "$B" -gt 1024 ];       then awk "BEGIN{printf \"%.2f KB\",$B/1024}"
        else echo "${B} B"
        fi
    }

    local RX_TOT TX_TOT RX_H TX_H
    RX_TOT=$(awk -v b="$RX_NOW" 'BEGIN{if(b>1073741824)printf "%.2f GB",b/1073741824; else if(b>1048576)printf "%.2f MB",b/1048576; else printf "%.2f KB",b/1024}')
    TX_TOT=$(awk -v b="$TX_NOW" 'BEGIN{if(b>1073741824)printf "%.2f GB",b/1073741824; else if(b>1048576)printf "%.2f MB",b/1048576; else printf "%.2f KB",b/1024}')
    local RX_D_STR TX_D_STR
    RX_D_STR=$(_fmt_bytes "$RX_DELTA")
    TX_D_STR=$(_fmt_bytes "$TX_DELTA")

    local HOSTNAME
    HOSTNAME=$(hostname 2>/dev/null || echo "server")
    local NOW_DATE
    NOW_DATE=$(date '+%Y-%m-%d %H:%M:%S')

    cat <<EOF
🌐 <b>Traffic Report</b> — ${HOSTNAME}
🕐 <b>Time:</b> ${NOW_DATE}
📡 <b>Interface:</b> ${IFACE}
⏱ <b>Period:</b> last ~${ELAPSED_H}h

📥 <b>Download (period):</b> ${RX_D_STR}
📤 <b>Upload   (period):</b> ${TX_D_STR}

📊 <b>Total since boot:</b>
  ↓ ${RX_TOT}
  ↑ ${TX_TOT}
EOF
}

_tg_build_ssh_report() {
    local HOSTNAME
    HOSTNAME=$(hostname 2>/dev/null || echo "server")
    local NOW_DATE
    NOW_DATE=$(date '+%Y-%m-%d %H:%M:%S')

    local ONLINE_LIST ONLINE_COUNT
    ONLINE_LIST=$(w -h 2>/dev/null || who 2>/dev/null)
    ONLINE_COUNT=$(echo "$ONLINE_LIST" | grep -c . 2>/dev/null || echo 0)
    [ -z "$ONLINE_LIST" ] && ONLINE_COUNT=0

    local ALL_USERS
    ALL_USERS=$(awk -F: '$3>=1000 && $7~/bash|sh/{print $1}' /etc/passwd 2>/dev/null)

    local MSG
    MSG="👥 <b>SSH Session Report</b> — ${HOSTNAME}
🕐 <b>Time:</b> ${NOW_DATE}
━━━━━━━━━━━━━━━━━━━━━

🟢 <b>Online (${ONLINE_COUNT}):</b>"

    if [ "$ONLINE_COUNT" -eq 0 ]; then
        MSG+="
  <i>No active sessions</i>"
    else
        while IFS= read -r sess; do
            [ -z "$sess" ] && continue
            local U TTY LOGIN IDLE IP
            U=$(echo "$sess" | awk '{print $1}')
            TTY=$(echo "$sess" | awk '{print $2}')
            LOGIN=$(echo "$sess" | awk '{print $4}')
            IDLE=$(echo "$sess" | awk '{print $5}')
            IP=$(who 2>/dev/null | awk -v t="$TTY" '$2==t{gsub(/[()]/,"",$5); print $5}')
            [ -z "$IP" ] && IP="local"
            MSG+="
  👤 <b>${U}</b>  🖥 ${TTY}  🌍 ${IP}  🕐 login:${LOGIN}  idle:${IDLE}"
        done <<< "$ONLINE_LIST"
    fi

    MSG+="
━━━━━━━━━━━━━━━━━━━━━
🔴 <b>Offline users:</b>"

    local OFFLINE_FOUND=0
    while IFS= read -r U; do
        [ -z "$U" ] && continue
        if ! echo "$ONLINE_LIST" | awk '{print $1}' | grep -qw "$U" 2>/dev/null; then
            local LAST_LOGIN
            LAST_LOGIN=$(last "$U" 2>/dev/null | head -1 | awk '{print $4,$5,$6,$7}' | xargs)
            [ -z "$LAST_LOGIN" ] && LAST_LOGIN="never"
            MSG+="
  👤 <b>${U}</b>  last: ${LAST_LOGIN}"
            OFFLINE_FOUND=1
        fi
    done <<< "$ALL_USERS"
    [ "$OFFLINE_FOUND" -eq 0 ] && MSG+="
  <i>All users online</i>"

    echo "$MSG"
}

_tg_build_sysusage_report() {
    local HOSTNAME
    HOSTNAME=$(hostname 2>/dev/null || echo "server")
    local NOW_DATE
    NOW_DATE=$(date '+%Y-%m-%d %H:%M:%S')

    # CPU
    local a1 b1 c1 d1 e1 f1 g1 h1 a2 b2 c2 d2 e2 f2 g2 h2
    read -r _c a1 b1 c1 d1 e1 f1 g1 h1 _ < /proc/stat
    sleep 1
    read -r _c a2 b2 c2 d2 e2 f2 g2 h2 _ < /proc/stat
    local TOTAL1 TOTAL2 DTOT DIDL CPU_PCT
    TOTAL1=$(( a1+b1+c1+d1+e1+f1+g1+h1 ))
    TOTAL2=$(( a2+b2+c2+d2+e2+f2+g2+h2 ))
    DTOT=$(( TOTAL2 - TOTAL1 )); [ "$DTOT" -le 0 ] && DTOT=1
    DIDL=$(( d2 - d1 ))
    CPU_PCT=$(( 100*(DTOT-DIDL)/DTOT ))
    [ "$CPU_PCT" -lt 0 ] && CPU_PCT=0
    [ "$CPU_PCT" -gt 100 ] && CPU_PCT=100

    local CPU_CORES LOAD
    CPU_CORES=$(nproc 2>/dev/null || echo 1)
    LOAD=$(awk '{print $1" "$2" "$3}' /proc/loadavg 2>/dev/null || echo "N/A")

    # RAM
    local RAM_TOTAL RAM_AVAIL RAM_USED RAM_PCT
    RAM_TOTAL=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
    RAM_AVAIL=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
    RAM_USED=$(( RAM_TOTAL - RAM_AVAIL ))
    [ "$RAM_USED" -lt 0 ] && RAM_USED=0
    RAM_PCT=$(( RAM_TOTAL > 0 ? RAM_USED*100/RAM_TOTAL : 0 ))

    # SWAP
    local SWAP_TOTAL SWAP_FREE SWAP_USED SWAP_PCT
    SWAP_TOTAL=$(awk '/SwapTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
    SWAP_FREE=$(awk '/SwapFree/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
    SWAP_USED=$(( SWAP_TOTAL - SWAP_FREE ))
    SWAP_PCT=0
    [ "$SWAP_TOTAL" -gt 0 ] && SWAP_PCT=$(( SWAP_USED*100/SWAP_TOTAL ))

    # Disk
    local DISK_USED DISK_TOTAL DISK_FREE DISK_PCT
    DISK_USED=$(df -h / 2>/dev/null | awk 'NR==2{print $3}' || echo "N/A")
    DISK_TOTAL=$(df -h / 2>/dev/null | awk 'NR==2{print $2}' || echo "N/A")
    DISK_FREE=$(df -h / 2>/dev/null | awk 'NR==2{print $4}' || echo "N/A")
    DISK_PCT=$(df / 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5);print $5}' || echo 0)

    # Procs
    local PROCS UPTIME_STR
    PROCS=$(ps aux 2>/dev/null | wc -l || echo "N/A")
    UPTIME_STR=$(uptime -p 2>/dev/null | sed 's/up //' || echo "N/A")

    _bar() {
        local P=$1 W=20 F E
        F=$(( P * W / 100 ))
        [ "$F" -gt "$W" ] && F=$W
        E=$(( W - F ))
        local B=""
        local i
        for (( i=0; i<F; i++ )); do B+="█"; done
        for (( i=0; i<E; i++ )); do B+="░"; done
        echo "$B"
    }

    local CPU_ICON="🟢"; [ "$CPU_PCT" -gt 60 ] && CPU_ICON="🟡"; [ "$CPU_PCT" -gt 85 ] && CPU_ICON="🔴"
    local RAM_ICON="🟢"; [ "$RAM_PCT" -gt 60 ] && RAM_ICON="🟡"; [ "$RAM_PCT" -gt 85 ] && RAM_ICON="🔴"
    local DSK_ICON="🟢"; [ "$DISK_PCT" -gt 70 ] && DSK_ICON="🟡"; [ "$DISK_PCT" -gt 90 ] && DSK_ICON="🔴"

    cat <<EOF
📊 <b>System Usage</b> — ${HOSTNAME}
🕐 <b>Time:</b> ${NOW_DATE}
━━━━━━━━━━━━━━━━━━━━━

${CPU_ICON} <b>CPU:</b> ${CPU_PCT}%  (${CPU_CORES} cores)
<code>$(_bar $CPU_PCT)</code>
📈 Load: ${LOAD}

${RAM_ICON} <b>RAM:</b> ${RAM_PCT}%  (${RAM_USED}MB / ${RAM_TOTAL}MB)
<code>$(_bar $RAM_PCT)</code>

💾 <b>SWAP:</b> ${SWAP_PCT}%  (${SWAP_USED}MB / ${SWAP_TOTAL}MB)
<code>$(_bar $SWAP_PCT)</code>

${DSK_ICON} <b>Disk (/):</b> ${DISK_PCT}%
  Used: ${DISK_USED}  Free: ${DISK_FREE}  Total: ${DISK_TOTAL}
<code>$(_bar $DISK_PCT)</code>

🔄 Processes: ${PROCS}  |  ⏱ Uptime: ${UPTIME_STR}
EOF
}

# ── Telegram: User Manager remote actions ───────────────────────
_tg_usermanager_report() {
    local HOSTNAME
    HOSTNAME=$(hostname 2>/dev/null || echo "server")
    local NOW_DATE
    NOW_DATE=$(date '+%Y-%m-%d %H:%M:%S')

    local USERS_LIST
    USERS_LIST=$(awk -F: '$3>=1000 && $7~/bash|sh/{print $1}' /etc/passwd 2>/dev/null)
    local USER_COUNT
    USER_COUNT=$(echo "$USERS_LIST" | grep -c . 2>/dev/null || echo 0)
    [ -z "$USERS_LIST" ] && USER_COUNT=0

    local MSG="👤 <b>User Manager Report</b> — ${HOSTNAME}
🕐 <b>Time:</b> ${NOW_DATE}
━━━━━━━━━━━━━━━━━━━━━
📋 <b>Total SSH users: ${USER_COUNT}</b>
"
    while IFS= read -r U; do
        [ -z "$U" ] && continue
        local GRPS SUDO_TAG ONLINE_TAG
        GRPS=$(id -Gn "$U" 2>/dev/null | tr ' ' ',')
        SUDO_TAG=""
        echo "$GRPS" | grep -qw "sudo" && SUDO_TAG=" 🔑sudo"
        ONLINE_TAG="🔴off"
        w -h 2>/dev/null | awk '{print $1}' | grep -qw "$U" 2>/dev/null && ONLINE_TAG="🟢on"
        MSG+="  👤 <b>${U}</b>${SUDO_TAG}  ${ONLINE_TAG}
     Groups: ${GRPS}
"
    done <<< "$USERS_LIST"

    echo "$MSG"
}

# ── Traffic daemon: background loop ─────────────────────────────
_tg_traffic_daemon_start() {
    local HOURS="$1"
    local INTERVAL=$(( HOURS * 3600 ))
    local PIDFILE="/tmp/.tg_traffic_daemon.pid"
    local LOGFILE="/tmp/.tg_traffic_daemon.log"

    # Kill existing daemon
    if [ -f "$PIDFILE" ]; then
        local OLD_PID
        OLD_PID=$(cat "$PIDFILE" 2>/dev/null)
        kill "$OLD_PID" 2>/dev/null || true
        rm -f "$PIDFILE"
    fi

    _tg_load_cfg

    (
        # Reset snapshot
        rm -f /tmp/.tg_traffic_snap /tmp/.tg_traffic_snap_time
        while true; do
            sleep "$INTERVAL"
            source "$TG_CFG" 2>/dev/null
            local MSG
            MSG=$(_tg_build_traffic_report "$HOURS")
            _tg_send "$MSG" "HTML"
            echo "$(date): traffic report sent" >> "$LOGFILE"
        done
    ) &
    local DPID=$!
    echo "$DPID" > "$PIDFILE"
    echo "$DPID"
}

_tg_traffic_daemon_stop() {
    local PIDFILE="/tmp/.tg_traffic_daemon.pid"
    if [ -f "$PIDFILE" ]; then
        local PID
        PID=$(cat "$PIDFILE" 2>/dev/null)
        kill "$PID" 2>/dev/null && echo "stopped" || echo "not_running"
        rm -f "$PIDFILE"
    else
        echo "not_running"
    fi
}

_tg_traffic_daemon_status() {
    local PIDFILE="/tmp/.tg_traffic_daemon.pid"
    if [ -f "$PIDFILE" ]; then
        local PID
        PID=$(cat "$PIDFILE" 2>/dev/null)
        kill -0 "$PID" 2>/dev/null && echo "running:$PID" || echo "dead"
    else
        echo "stopped"
    fi
}

# ── Telegram: remote user management via polling ────────────────
_tg_get_updates() {
    local OFFSET="${1:-0}"
    curl -s --max-time 10 \
        "https://api.telegram.org/bot${TG_BOT_TOKEN}/getUpdates?offset=${OFFSET}&timeout=5" \
        2>/dev/null
}

_tg_remote_usermanager() {
    _tg_load_cfg
    local OFFSET_FILE="/tmp/.tg_usermgr_offset"
    local PIDFILE="/tmp/.tg_usermgr_daemon.pid"
    local LOGFILE="/tmp/.tg_usermgr_daemon.log"

    if [ -f "$PIDFILE" ]; then
        local OLD_PID
        OLD_PID=$(cat "$PIDFILE" 2>/dev/null)
        kill "$OLD_PID" 2>/dev/null || true
        rm -f "$PIDFILE"
    fi

    local HELP_MSG="🤖 <b>User Manager Bot</b>

📋 <b>Available commands:</b>
/listusers — list all SSH users
/adduser &lt;name&gt; &lt;pass&gt; — create user
/deluser &lt;name&gt; — remove user
/listgroups — list groups &amp; perms
/addgroup &lt;name&gt; — create group
/delgroup &lt;name&gt; — remove group
/addusertogroup &lt;user&gt; &lt;group&gt; — add
/removefromgroup &lt;user&gt; &lt;group&gt; — remove
/setperm &lt;group&gt; sudo — full sudo
/setperm &lt;group&gt; docker — docker access
/setperm &lt;group&gt; remove — remove rules
/sshsessions — online/offline users
/sysusage — system resources
/traffic — traffic report
/status — server status
/help — this message"

    (
        source "$TG_CFG" 2>/dev/null
        local OFFSET=0
        [ -f "$OFFSET_FILE" ] && OFFSET=$(cat "$OFFSET_FILE" 2>/dev/null || echo 0)

        _tg_send "$HELP_MSG" "HTML" >/dev/null

        while true; do
            local RAW UPDATES
            RAW=$(_tg_get_updates "$OFFSET")
            UPDATES=$(echo "$RAW" | grep -o '"update_id":[0-9]*' | grep -o '[0-9]*')

            if [ -n "$UPDATES" ]; then
                while IFS= read -r UID_LINE; do
                    [ -z "$UID_LINE" ] && continue
                    local UPDATE_ID="$UID_LINE"
                    OFFSET=$(( UPDATE_ID + 1 ))
                    echo "$OFFSET" > "$OFFSET_FILE"

                    # Extract message text
                    local MSG_TEXT
                    MSG_TEXT=$(echo "$RAW" | python3 -c "
import sys,json
data=json.load(sys.stdin)
for u in data.get('result',[]):
    if str(u.get('update_id',''))=='${UPDATE_ID}':
        print(u.get('message',{}).get('text',''))
" 2>/dev/null || echo "")
                    [ -z "$MSG_TEXT" ] && continue

                    local CMD ARG1 ARG2
                    CMD=$(echo "$MSG_TEXT" | awk '{print $1}')
                    ARG1=$(echo "$MSG_TEXT" | awk '{print $2}')
                    ARG2=$(echo "$MSG_TEXT" | awk '{print $3}')

                    local REPLY=""
                    case "$CMD" in
                        /help|/start)
                            REPLY="$HELP_MSG" ;;
                        /listusers)
                            REPLY=$(_tg_usermanager_report) ;;
                        /sshsessions)
                            REPLY=$(_tg_build_ssh_report) ;;
                        /sysusage)
                            REPLY=$(_tg_build_sysusage_report) ;;
                        /traffic)
                            REPLY=$(_tg_build_traffic_report 1) ;;
                        /status)
                            local H KER UP LOAD4
                            H=$(hostname 2>/dev/null)
                            KER=$(uname -r 2>/dev/null)
                            UP=$(uptime -p 2>/dev/null | sed 's/up //')
                            LOAD4=$(awk '{print $1}' /proc/loadavg 2>/dev/null)
                            REPLY="🖥 <b>Server Status</b>
Hostname: <code>${H}</code>
Kernel: <code>${KER}</code>
Uptime: ${UP}
Load: ${LOAD4}" ;;
                        /adduser)
                            if [ -z "$ARG1" ] || [ -z "$ARG2" ]; then
                                REPLY="❌ Usage: /adduser &lt;username&gt; &lt;password&gt;"
                            elif id "$ARG1" &>/dev/null; then
                                REPLY="❌ User <b>${ARG1}</b> already exists."
                            else
                                if useradd -m -s /bin/bash "$ARG1" 2>/dev/null && \
                                   echo "${ARG1}:${ARG2}" | chpasswd 2>/dev/null; then
                                    REPLY="✅ User <b>${ARG1}</b> created."
                                else
                                    REPLY="❌ Failed to create user <b>${ARG1}</b>."
                                fi
                            fi ;;
                        /deluser)
                            if [ -z "$ARG1" ]; then
                                REPLY="❌ Usage: /deluser &lt;username&gt;"
                            elif ! id "$ARG1" &>/dev/null; then
                                REPLY="❌ User <b>${ARG1}</b> not found."
                            else
                                pkill -u "$ARG1" 2>/dev/null || true
                                if userdel -r "$ARG1" 2>/dev/null; then
                                    REPLY="✅ User <b>${ARG1}</b> removed."
                                else
                                    REPLY="❌ Failed to remove <b>${ARG1}</b>."
                                fi
                            fi ;;
                        /listgroups)
                            local GREPORT
                            GREPORT="👥 <b>Groups &amp; Permissions</b>
"
                            while IFS=: read -r GN _ GID GM; do
                                [ "${GID:-0}" -ge 1000 ] 2>/dev/null || \
                                echo "sudo docker www-data wheel" | grep -qw "$GN" || continue
                                local SR=""
                                [ -f "/etc/sudoers.d/${GN}" ] && SR=" 🔑"
                                GREPORT+="  <b>${GN}</b>${SR}  GID:${GID}  members: ${GM:-none}
"
                            done < /etc/group 2>/dev/null
                            REPLY="$GREPORT" ;;
                        /addgroup)
                            if [ -z "$ARG1" ]; then
                                REPLY="❌ Usage: /addgroup &lt;groupname&gt;"
                            elif getent group "$ARG1" &>/dev/null; then
                                REPLY="⚠️ Group <b>${ARG1}</b> already exists."
                            else
                                groupadd "$ARG1" 2>/dev/null && \
                                    REPLY="✅ Group <b>${ARG1}</b> created." || \
                                    REPLY="❌ Failed to create group <b>${ARG1}</b>."
                            fi ;;
                        /delgroup)
                            if [ -z "$ARG1" ]; then
                                REPLY="❌ Usage: /delgroup &lt;groupname&gt;"
                            elif ! getent group "$ARG1" &>/dev/null; then
                                REPLY="❌ Group <b>${ARG1}</b> not found."
                            else
                                groupdel "$ARG1" 2>/dev/null && \
                                    REPLY="✅ Group <b>${ARG1}</b> removed." || \
                                    REPLY="❌ Failed."
                            fi ;;
                        /addusertogroup)
                            if [ -z "$ARG1" ] || [ -z "$ARG2" ]; then
                                REPLY="❌ Usage: /addusertogroup &lt;user&gt; &lt;group&gt;"
                            elif ! id "$ARG1" &>/dev/null; then
                                REPLY="❌ User <b>${ARG1}</b> not found."
                            elif ! getent group "$ARG2" &>/dev/null; then
                                REPLY="❌ Group <b>${ARG2}</b> not found."
                            else
                                usermod -aG "$ARG2" "$ARG1" 2>/dev/null && \
                                    REPLY="✅ <b>${ARG1}</b> added to <b>${ARG2}</b>." || \
                                    REPLY="❌ Failed."
                            fi ;;
                        /removefromgroup)
                            if [ -z "$ARG1" ] || [ -z "$ARG2" ]; then
                                REPLY="❌ Usage: /removefromgroup &lt;user&gt; &lt;group&gt;"
                            else
                                gpasswd -d "$ARG1" "$ARG2" 2>/dev/null && \
                                    REPLY="✅ <b>${ARG1}</b> removed from <b>${ARG2}</b>." || \
                                    REPLY="❌ Failed or user not in group."
                            fi ;;
                        /setperm)
                            # /setperm <group> <sudo|docker|remove>
                            local PGROUP="$ARG1" PTYPE="$ARG2"
                            if [ -z "$PGROUP" ] || [ -z "$PTYPE" ]; then
                                REPLY="❌ Usage: /setperm &lt;group&gt; &lt;sudo|docker|remove&gt;"
                            elif ! getent group "$PGROUP" &>/dev/null; then
                                REPLY="❌ Group <b>${PGROUP}</b> not found."
                            else
                                case "$PTYPE" in
                                    sudo)
                                        echo "%${PGROUP} ALL=(ALL:ALL) ALL" > "/etc/sudoers.d/${PGROUP}" 2>/dev/null && \
                                            REPLY="✅ Full sudo granted to <b>${PGROUP}</b>." || \
                                            REPLY="❌ Failed." ;;
                                    docker)
                                        echo "%${PGROUP} ALL=(ALL) NOPASSWD: /usr/bin/docker" > "/etc/sudoers.d/${PGROUP}_docker" 2>/dev/null && \
                                            REPLY="✅ Docker access granted to <b>${PGROUP}</b>." || \
                                            REPLY="❌ Failed." ;;
                                    remove)
                                        rm -f "/etc/sudoers.d/${PGROUP}" "/etc/sudoers.d/${PGROUP}_docker" 2>/dev/null
                                        REPLY="✅ Sudoers rules removed for <b>${PGROUP}</b>." ;;
                                    *)
                                        REPLY="❌ Unknown permission type. Use: sudo | docker | remove" ;;
                                esac
                            fi ;;
                        /*)
                            REPLY="❓ Unknown command. Send /help for list." ;;
                    esac

                    [ -n "$REPLY" ] && _tg_send "$REPLY" "HTML"
                    echo "$(date): cmd=${CMD} arg1=${ARG1}" >> "$LOGFILE"
                done <<< "$UPDATES"
            fi

            sleep 2
        done
    ) &
    local DPID=$!
    echo "$DPID" > "$PIDFILE"
    echo "$DPID"
}

_tg_remote_usermanager_stop() {
    local PIDFILE="/tmp/.tg_usermgr_daemon.pid"
    if [ -f "$PIDFILE" ]; then
        local PID
        PID=$(cat "$PIDFILE" 2>/dev/null)
        kill "$PID" 2>/dev/null && echo "stopped" || echo "not_running"
        rm -f "$PIDFILE"
    else
        echo "not_running"
    fi
}

# ── Main Telegram Notifier Menu ──────────────────────────────────
telegram_notifier() {
    _tg_load_cfg
    while true; do
        clear
        sep_top
        row "$(printf '%*s%s' $(( (W - 18) / 2 )) '' 'Telegram Notifier')"
        sep_mid; blank

        # ── Bot status line ──────────────────────────────────────
        local BOT_STATUS="not_configured"
        if [ -z "$TG_BOT_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then
            rowc 38 "  Bot Status : ${RED}Not Connected${NC}"
        else
            local CONN_STR
            CONN_STR=$(_tg_test)
            if [ "$CONN_STR" = "ok" ]; then
                rowc 34 "  Bot Status : ${GREEN}Connected${NC}"
                BOT_STATUS="ok"
            else
                rowc 36 "  Bot Status : ${RED}Not Connected${NC}"
                BOT_STATUS="fail"
            fi
        fi

        # ── Chat ID line ─────────────────────────────────────────
        if [ -n "$TG_CHAT_ID" ]; then
            rowc $(( 14 + ${#TG_CHAT_ID} )) \
                "  Chat ID    : ${GREEN}${TG_CHAT_ID}${NC}"
        else
            rowc 30 "  Chat ID    : ${RED}Not Set${NC}"
        fi

        blank; sep_mid; blank
        row "   1.  Set Bot Token & Chat ID"
        row "   2.  Test Connection"
        row "   3.  Traffic Report"
        row "   0.  Back"
        blank; sep_bot; echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"
        read -n 1 TOPT; echo ""

        case $TOPT in
            # ── 1. Setup ────────────────────────────────────────
            1)
                clear
                sep_top; row "$(printf '%*s%s' $(( (W-22)/2 )) '' 'Set Bot Token & Chat ID')"; sep_mid; blank
                row "  How to get Bot Token:"
                row "  1. Open Telegram > search @BotFather"
                row "  2. Send /newbot and follow instructions"
                row "  3. Copy the token BotFather gives you"
                blank
                row "  How to get Chat ID:"
                row "  1. Start your bot (send /start to it)"
                row "  2. Visit: api.telegram.org/bot<TOKEN>/getUpdates"
                row "  3. Find  \"chat\":{\"id\": YOUR_CHAT_ID}"
                blank; sep_bot; echo ""
                echo -ne "  ${YELLOW}Bot Token : ${NC}"; read -r NEW_TOKEN
                [ -z "$NEW_TOKEN" ] && echo -e "  ${RED}Cancelled.${NC}" && sleep 1 && continue
                echo -ne "  ${YELLOW}Chat ID   : ${NC}"; read -r NEW_CHAT
                [ -z "$NEW_CHAT" ] && echo -e "  ${RED}Cancelled.${NC}" && sleep 1 && continue
                TG_BOT_TOKEN="$NEW_TOKEN"
                TG_CHAT_ID="$NEW_CHAT"
                _tg_save_cfg
                echo -e "\n  ${GREEN}[OK] Saved.${NC}"
                echo -e "  ${CYAN}[*] Testing connection...${NC}"
                local T_RES
                T_RES=$(_tg_test)
                if [ "$T_RES" = "ok" ]; then
                    echo -e "  ${GREEN}[OK] Bot connected!${NC}"
                    _tg_send "✅ <b>Server Manager connected!</b>
Host: <code>$(hostname)</code>
Time: $(date '+%Y-%m-%d %H:%M:%S')" "HTML"
                    echo -e "  ${GREEN}[OK] Test message sent to Telegram.${NC}"
                else
                    echo -e "  ${RED}[ERR] Cannot reach bot. Check token/chat ID.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;

            # ── 2. Test ─────────────────────────────────────────
            2)
                echo ""
                if [ -z "$TG_BOT_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then
                    echo -e "  ${RED}[ERR] Bot not configured. Use option 1 first.${NC}"
                    sleep 2; continue
                fi
                echo -e "  ${CYAN}[*] Testing connection...${NC}"
                local T2
                T2=$(_tg_test)
                if [ "$T2" = "ok" ]; then
                    echo -e "  ${GREEN}[OK] Connected!${NC}"
                    _tg_send "🔔 <b>Test Message</b>
From: <code>$(hostname)</code>
Time: $(date '+%Y-%m-%d %H:%M:%S')
Status: ✅ OK" "HTML"
                    echo -e "  ${GREEN}[OK] Test message sent to Telegram.${NC}"
                else
                    echo -e "  ${RED}[ERR] Connection failed. Check token/chat ID.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;

            # ── 3. Traffic Report ────────────────────────────────
            3)
                while true; do
                    clear
                    sep_top
                    row "$(printf '%*s%s' $(( (W-16)/2 )) '' 'Traffic Report')"
                    sep_mid; blank

                    # Daemon status
                    local TS TPID_DISP
                    TS=$(_tg_traffic_daemon_status)
                    if echo "$TS" | grep -q "^running"; then
                        TPID_DISP=$(echo "$TS" | cut -d: -f2)
                        rowc 42 "  Auto-send : ${GREEN}Running (PID ${TPID_DISP})${NC}"
                    else
                        rowc 35 "  Auto-send : ${RED}Stopped${NC}"
                    fi

                    # Total traffic since boot
                    local IFACE_D
                    IFACE_D=$(ip route 2>/dev/null | grep '^default' | awk '{print $5}' | head -1)
                    [ -z "$IFACE_D" ] && IFACE_D="eth0"
                    local RX_B TX_B
                    RX_B=$(awk -v iface="${IFACE_D}:" '$1==iface{print $2}' /proc/net/dev 2>/dev/null || echo 0)
                    TX_B=$(awk -v iface="${IFACE_D}:" '$1==iface{print $10}' /proc/net/dev 2>/dev/null || echo 0)
                    _fmtb() {
                        local B=$1
                        if   [ "$B" -gt 1073741824 ]; then awk "BEGIN{printf \"%.2f GB\",$B/1073741824}"
                        elif [ "$B" -gt 1048576 ];    then awk "BEGIN{printf \"%.2f MB\",$B/1048576}"
                        elif [ "$B" -gt 1024 ];       then awk "BEGIN{printf \"%.2f KB\",$B/1024}"
                        else echo "${B} B"; fi
                    }
                    local RX_TOT_D TX_TOT_D
                    RX_TOT_D=$(_fmtb "$RX_B")
                    TX_TOT_D=$(_fmtb "$TX_B")
                    row "  Interface : $IFACE_D"
                    row "  Total ↓   : $RX_TOT_D  (since boot)"
                    row "  Total ↑   : $TX_TOT_D  (since boot)"

                    blank; sep_mid; blank
                    row "   1.  Send traffic report NOW (period)"
                    row "   2.  Show total traffic (since boot)"
                    row "   3.  Start auto-send (every N hours)"
                    row "   4.  Stop auto-send"
                    row "   0.  Back"
                    blank; sep_bot; echo ""
                    echo -ne "  ${YELLOW}> Select: ${NC}"
                    read -n 1 T3OPT; echo ""
                    case $T3OPT in
                        1)
                            echo -e "\n  ${CYAN}[*] Building period traffic report...${NC}"
                            local TREP
                            TREP=$(_tg_build_traffic_report 0)
                            _tg_send "$TREP" "HTML" && \
                                echo -e "  ${GREEN}[OK] Report sent to Telegram.${NC}" || \
                                echo -e "  ${RED}[ERR] Failed. Check connection.${NC}"
                            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                        2)
                            echo -e "\n  ${CYAN}[*] Sending total traffic report...${NC}"
                            local IFACE_T RX_T TX_T RX_TS TX_TS
                            IFACE_T=$(ip route 2>/dev/null | grep '^default' | awk '{print $5}' | head -1)
                            [ -z "$IFACE_T" ] && IFACE_T="eth0"
                            RX_T=$(awk -v iface="${IFACE_T}:" '$1==iface{print $2}' /proc/net/dev 2>/dev/null || echo 0)
                            TX_T=$(awk -v iface="${IFACE_T}:" '$1==iface{print $10}' /proc/net/dev 2>/dev/null || echo 0)
                            RX_TS=$(_fmtb "$RX_T")
                            TX_TS=$(_fmtb "$TX_T")
                            local TOTAL_MSG
                            TOTAL_MSG="📊 <b>Total Traffic Since Boot</b>
🖥 Host: <code>$(hostname)</code>
🕐 Time: $(date '+%Y-%m-%d %H:%M:%S')
📡 Interface: <b>${IFACE_T}</b>

📥 <b>Download:</b> ${RX_TS}
📤 <b>Upload:</b>   ${TX_TS}"
                            _tg_send "$TOTAL_MSG" "HTML" && \
                                echo -e "  ${GREEN}[OK] Total traffic sent to Telegram.${NC}" || \
                                echo -e "  ${RED}[ERR] Failed. Check connection.${NC}"
                            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                        3)
                            echo -ne "\n  ${YELLOW}Send every how many hours? [6]: ${NC}"
                            read -r TRF_H
                            [ -z "$TRF_H" ] && TRF_H=6
                            if ! [[ "$TRF_H" =~ ^[0-9]+$ ]] || [ "$TRF_H" -lt 1 ]; then
                                echo -e "  ${RED}Invalid. Must be a number >= 1.${NC}"; sleep 2; continue
                            fi
                            local DPID
                            DPID=$(_tg_traffic_daemon_start "$TRF_H")
                            echo -e "  ${GREEN}[OK] Auto-send started (every ${TRF_H}h). PID: ${DPID}${NC}"
                            _tg_send "📡 <b>Traffic auto-send started</b>
Will report every <b>${TRF_H} hours</b>.
Host: <code>$(hostname)</code>" "HTML"
                            echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
                        4)
                            local STOP_R
                            STOP_R=$(_tg_traffic_daemon_stop)
                            [ "$STOP_R" = "stopped" ] && \
                                echo -e "  ${GREEN}[OK] Auto-send stopped.${NC}" || \
                                echo -e "  ${YELLOW}[!] Was not running.${NC}"
                            sleep 2 ;;
                        0) break ;;
                        *) echo -e "  ${RED}Invalid.${NC}"; sleep 1 ;;
                    esac
                done ;;

            0) return ;;
            *) echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
        _tg_load_cfg
    done
}

# ── Telegram Bot Panel ───────────────────────────────────────────
# Uses Telegram inline keyboard to create a glass-panel UI in chat.
# On /start: sends a beautiful glass-style menu with inline buttons.
# Each button calls back to the bot which executes the action.

TG_BOT_CFG="/etc/server_manager_tg.cfg"

_tgb_load() {
    TG_BOT_TOKEN="${TG_BOT_TOKEN:-}"
    TG_CHAT_ID="${TG_CHAT_ID:-}"
    [ -f "$TG_BOT_CFG" ] && source "$TG_BOT_CFG" 2>/dev/null
    [ -f "/etc/server_manager_telegram.cfg" ] && source "/etc/server_manager_telegram.cfg" 2>/dev/null
}

_tgb_save() {
    cat > "$TG_BOT_CFG" 2>/dev/null <<EOF
TG_BOT_TOKEN="${TG_BOT_TOKEN}"
TG_CHAT_ID="${TG_CHAT_ID}"
EOF
    chmod 600 "$TG_BOT_CFG" 2>/dev/null
}

_tgb_api() {
    local METHOD="$1"; shift
    curl -s --max-time 10 \
        "https://api.telegram.org/bot${TG_BOT_TOKEN}/${METHOD}" \
        "$@" 2>/dev/null
}

_tgb_build_menu_msg() {
    local HOST IP4 IP6 UP LOAD
    HOST=$(hostname 2>/dev/null || echo "server")
    IP4=$(_curl -4 ifconfig.me 2>/dev/null || echo "N/A")
    IP6=$(ip -6 addr show scope global 2>/dev/null \
        | grep -oE '([0-9a-f]{0,4}:){2,7}[0-9a-f]{0,4}' | head -1 || echo "N/A")
    [ -z "$IP6" ] && IP6="N/A"
    UP=$(uptime -p 2>/dev/null | sed 's/up //' || echo "N/A")
    LOAD=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "N/A")

    # CPU %
    local CPU_PCT
    CPU_PCT=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print 100-$8}' | cut -d. -f1)
    [ -z "$CPU_PCT" ] && CPU_PCT=$(awk '/^cpu /{t=$2+$3+$4+$5+$6+$7+$8; i=$5; printf "%d",(t-i)*100/t}' /proc/stat 2>/dev/null || echo "N/A")

    # RAM
    local RAM_T RAM_A RAM_U RAM_PCT
    RAM_T=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
    RAM_A=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
    RAM_U=$(( RAM_T - RAM_A )); [ "$RAM_U" -lt 0 ] && RAM_U=0
    RAM_PCT=$(( RAM_T > 0 ? RAM_U*100/RAM_T : 0 ))

    # Disk
    local DISK_U DISK_T DISK_F DISK_PCT
    DISK_U=$(df -h / 2>/dev/null | awk 'NR==2{print $3}' || echo "N/A")
    DISK_T=$(df -h / 2>/dev/null | awk 'NR==2{print $2}' || echo "N/A")
    DISK_F=$(df -h / 2>/dev/null | awk 'NR==2{print $4}' || echo "N/A")
    DISK_PCT=$(df / 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5);print $5}' || echo 0)

    # Network speed (1s sample)
    local IFACE RX1 TX1 RX2 TX2 RX_BPS TX_BPS RX_RATE TX_RATE
    IFACE=$(ip route 2>/dev/null | grep '^default' | awk '{print $5}' | head -1)
    [ -z "$IFACE" ] && IFACE="eth0"
    RX1=$(awk -v i="${IFACE}:" '$1==i{print $2}' /proc/net/dev 2>/dev/null || echo 0)
    TX1=$(awk -v i="${IFACE}:" '$1==i{print $10}' /proc/net/dev 2>/dev/null || echo 0)
    sleep 1
    RX2=$(awk -v i="${IFACE}:" '$1==i{print $2}' /proc/net/dev 2>/dev/null || echo 0)
    TX2=$(awk -v i="${IFACE}:" '$1==i{print $10}' /proc/net/dev 2>/dev/null || echo 0)
    RX_BPS=$(( RX2 - RX1 )); [ "$RX_BPS" -lt 0 ] && RX_BPS=0
    TX_BPS=$(( TX2 - TX1 )); [ "$TX_BPS" -lt 0 ] && TX_BPS=0
    _spd() {
        local B=$1
        if   [ "$B" -gt 1048576 ]; then awk "BEGIN{printf \"%.1f MB/s\",$B/1048576}"
        elif [ "$B" -gt 1024 ];    then printf "%d KB/s" "$(( B/1024 ))"
        else printf "%d B/s" "$B"; fi
    }
    RX_RATE=$(_spd $RX_BPS)
    TX_RATE=$(_spd $TX_BPS)

    # Total DL/UL since boot
    local RX_TOTAL TX_TOTAL
    RX_TOTAL=$(awk -v i="${IFACE}:" '$1==i{print $2}' /proc/net/dev 2>/dev/null || echo 0)
    TX_TOTAL=$(awk -v i="${IFACE}:" '$1==i{print $10}' /proc/net/dev 2>/dev/null || echo 0)
    _fmtb() {
        local B=$1
        if   [ "$B" -gt 1073741824 ]; then awk "BEGIN{printf \"%.2f GB\",$B/1073741824}"
        elif [ "$B" -gt 1048576 ];    then awk "BEGIN{printf \"%.2f MB\",$B/1048576}"
        elif [ "$B" -gt 1024 ];       then printf "%d KB" "$(( B/1024 ))"
        else printf "%d B" "$B"; fi
    }
    local RX_TOT_STR TX_TOT_STR
    RX_TOT_STR=$(_fmtb $RX_TOTAL)
    TX_TOT_STR=$(_fmtb $TX_TOTAL)

    echo "
         🪟 <b>Server Manager</b>
━━━━━━━━━━━━━━━━━━━━━
🖥  Hostname: <b>${HOST}</b>
🌐  IPv4: <code>${IP4}</code>
🌐  IPv6: <code>${IP6}</code>
⏱  Uptime: ${UP}
📊  Load: ${LOAD}
━━━━━━━━━━━━━━━━━━━━━
🔥 CPU:  <b>${CPU_PCT}%</b>
🧠 RAM:  <b>${RAM_PCT}%</b>  (${RAM_U} / ${RAM_T} MB)
💾 Disk: <b>${DISK_PCT}%</b>  Used: ${DISK_U} / ${DISK_T}  Free: ${DISK_F}
━━━━━━━━━━━━━━━━━━━━━
📥 DL Speed:  <b>${RX_RATE}</b>
📤 UL Speed:  <b>${TX_RATE}</b>
📊 Total DL:  <b>${RX_TOT_STR}</b>
📊 Total UL:  <b>${TX_TOT_STR}</b>
━━━━━━━━━━━━━━━━━━━━━
<i>Select an option below:</i>"
}

_tgb_build_menu_kb() {
    echo '{
  "inline_keyboard": [
    [
      {"text":"🖥 SSH Sessions",   "callback_data":"ssh_session"},
      {"text":"🔄 Refresh",        "callback_data":"main_menu"}
    ],
    [
      {"text":"🔌 Port Manager",   "callback_data":"port_report"},
      {"text":"🔥 Manage UFW",     "callback_data":"ufw_report"}
    ],
    [
      {"text":"🛡 Manage Fail2ban","callback_data":"f2b_report"}
    ]
  ]
}'
}


_tgb_send_glass_menu() {
    local CHAT="$1"
    local MSG KB
    MSG=$(_tgb_build_menu_msg)
    KB=$(_tgb_build_menu_kb)

    local MENU_ID_FILE="/tmp/.tgbot_menu_msgid_${CHAT}"
    local EXISTING_ID=""
    [ -f "$MENU_ID_FILE" ] && EXISTING_ID=$(cat "$MENU_ID_FILE" 2>/dev/null)

    # Delete old panel message first (so only one panel exists at a time)
    if [ -n "$EXISTING_ID" ]; then
        _tgb_api deleteMessage \
            -d "chat_id=${CHAT}" \
            -d "message_id=${EXISTING_ID}" >/dev/null 2>&1 || true
        rm -f "$MENU_ID_FILE"
    fi

    # Send fresh panel and save its message_id
    local SEND_RES
    SEND_RES=$(_tgb_api sendMessage \
        -d "chat_id=${CHAT}" \
        -d "parse_mode=HTML" \
        --data-urlencode "text=${MSG}" \
        -d "reply_markup=${KB}")
    local NEW_ID
    NEW_ID=$(echo "$SEND_RES" | grep -o '"message_id":[0-9]*' | grep -o '[0-9]*' | head -1)
    [ -n "$NEW_ID" ] && echo "$NEW_ID" > "$MENU_ID_FILE"
}

# Speed test: edit existing message with server list keyboard
_tgb_speed_server_list_edit() {
    local CHAT="$1" MSG_ID="$2"
    local ST_BIN=""
    command -v speedtest-cli &>/dev/null && ST_BIN="speedtest-cli"
    command -v speedtest     &>/dev/null && ST_BIN="speedtest"
    python3 -m speedtest --version &>/dev/null 2>&1 && ST_BIN="python3 -m speedtest"

    if [ -z "$ST_BIN" ]; then
        _tgb_edit_back_btn "$CHAT" "$MSG_ID" "⚡ <b>Speed Test</b>
⏳ speedtest-cli not found. Installing..."
        if command -v pip3 &>/dev/null; then
            pip3 install speedtest-cli --quiet 2>/dev/null && ST_BIN="speedtest-cli"
        elif command -v pip &>/dev/null; then
            pip install speedtest-cli --quiet 2>/dev/null && ST_BIN="speedtest-cli"
        fi
        if [ -z "$ST_BIN" ]; then
            _tgb_edit_back_btn "$CHAT" "$MSG_ID" "⚡ <b>Speed Test</b>
❌ Could not install speedtest-cli.
Run manually: <code>pip3 install speedtest-cli</code>"
            return
        fi
    fi

    _tgb_edit_back_btn "$CHAT" "$MSG_ID" "⚡ <b>Speed Test</b>
⏳ Fetching nearby servers..."

    local RAW_LIST
    RAW_LIST=$(python3 -m speedtest --list 2>/dev/null | grep -E '^\s+[0-9]+\)' | head -10)
    [ -z "$RAW_LIST" ] && RAW_LIST=$(speedtest-cli --list 2>/dev/null | grep -E '^\s+[0-9]+\)' | head -10)
    [ -z "$RAW_LIST" ] && RAW_LIST=$(speedtest --list 2>/dev/null | grep -E '^\s+[0-9]+\)' | head -10)

    if [ -z "$RAW_LIST" ]; then
        _tgb_edit_back_btn "$CHAT" "$MSG_ID" "⚡ <b>Speed Test</b>
⏳ No server list. Running auto..."
        local REPLY; REPLY=$(_tgb_run_speed "auto")
        _tgb_edit_back_btn "$CHAT" "$MSG_ID" "$REPLY"
        return
    fi

    local KEYBOARD='{"inline_keyboard":['
    local FIRST=1
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local SRV_ID SRV_NAME
        SRV_ID=$(echo "$line" | grep -oE '^\s*[0-9]+' | tr -d ' ')
        SRV_NAME=$(echo "$line" | sed "s/^\s*${SRV_ID})\s*//" | sed 's/ \[.*km\].*//' | cut -c1-38 | sed 's/"/\\"/g')
        [ -z "$SRV_ID" ] && continue
        [ "$FIRST" = "0" ] && KEYBOARD+=","
        KEYBOARD+="[{\"text\":\"📡 ${SRV_NAME}\",\"callback_data\":\"spd_run:${SRV_ID}\"}]"
        FIRST=0
    done <<< "$RAW_LIST"
    KEYBOARD+=",[{\"text\":\"⚡ Auto — best server\",\"callback_data\":\"spd_run:auto\"}]"
    KEYBOARD+=",[{\"text\":\"🔙 Back to Menu\",\"callback_data\":\"main_menu\"}]]}"

    local MSG="⚡ <b>Speed Test — Choose a Server</b>
━━━━━━━━━━━━━━━━━━━━━
Select which server to run the test from:"

    _tgb_edit_msg "$CHAT" "$MSG_ID" "$MSG" "$KEYBOARD"
}

_tgb_answer_callback() {
    local CALLBACK_ID="$1" TEXT="$2"
    _tgb_api answerCallbackQuery \
        -d "callback_query_id=${CALLBACK_ID}" \
        --data-urlencode "text=${TEXT}" \
        >/dev/null
}

# Edit existing message in-place (replaces text + keyboard)
_tgb_edit_msg() {
    local CHAT="$1" MSG_ID="$2" MSG="$3" KEYBOARD="${4:-}"
    if [ -n "$KEYBOARD" ]; then
        _tgb_api editMessageText \
            -d "chat_id=${CHAT}" \
            -d "message_id=${MSG_ID}" \
            -d "parse_mode=HTML" \
            --data-urlencode "text=${MSG}" \
            -d "reply_markup=${KEYBOARD}" \
            >/dev/null 2>&1 || true
    else
        _tgb_api editMessageText \
            -d "chat_id=${CHAT}" \
            -d "message_id=${MSG_ID}" \
            -d "parse_mode=HTML" \
            --data-urlencode "text=${MSG}" \
            >/dev/null 2>&1 || true
    fi
}

# Edit in-place with Back button
_tgb_edit_back_btn() {
    local CHAT="$1" MSG_ID="$2" MSG="$3"
    local KB='{"inline_keyboard":[[{"text":"🔙 Back to Menu","callback_data":"main_menu"}]]}'
    _tgb_edit_msg "$CHAT" "$MSG_ID" "$MSG" "$KB"
}

_tgb_send_reply() {
    local CHAT="$1" MSG="$2"
    _tgb_api sendMessage \
        -d "chat_id=${CHAT}" \
        -d "parse_mode=HTML" \
        --data-urlencode "text=${MSG}" \
        >/dev/null
}

_tgb_send_back_btn() {
    local CHAT="$1" MSG="$2"
    local KEYBOARD='{"inline_keyboard":[[{"text":"🔙 Back to Menu","callback_data":"main_menu"}]]}'
    _tgb_api sendMessage \
        -d "chat_id=${CHAT}" \
        -d "parse_mode=HTML" \
        --data-urlencode "text=${MSG}" \
        -d "reply_markup=${KEYBOARD}" \
        >/dev/null
}

_tgb_ssh_report() {
    local HOST; HOST=$(hostname 2>/dev/null || echo "server")
    local NOW; NOW=$(date '+%Y-%m-%d %H:%M:%S')

    # Same source as ssh_monitor: w -h gives user/tty/login/idle/what
    local SESSIONS; SESSIONS=$(w -h 2>/dev/null || who 2>/dev/null | awk '{print $1,$2,"","","","","",""}')
    local COUNT=0
    [ -n "$SESSIONS" ] && COUNT=$(echo "$SESSIONS" | grep -c . 2>/dev/null || echo 0)

    # Build IP_MAP from ss (PTY -> IP)
    declare -A IP_MAP
    while IFS= read -r ssline; do
        local _FOREIGN _PROC _PTS _RAW_IP
        _FOREIGN=$(echo "$ssline" | awk '{print $5}')
        _PROC=$(echo "$ssline" | awk '{print $NF}')
        _PTS=$(echo "$_PROC" | grep -oE 'pts/[0-9]+' | head -1)
        _RAW_IP=$(echo "$_FOREIGN" | sed 's/\[//g;s/\]//g' | rev | cut -d: -f2- | rev)
        [ -n "$_PTS" ] && [ -n "$_RAW_IP" ] && IP_MAP["$_PTS"]="$_RAW_IP"
    done < <(ss -tnp 2>/dev/null | grep -i sshd || true)

    # WHO_MAP fallback
    declare -A WHO_MAP
    while IFS= read -r wholine; do
        local _W_TTY _W_IP
        _W_TTY=$(echo "$wholine" | awk '{print $2}')
        _W_IP=$(echo "$wholine" | grep -oE '\([0-9a-fA-F:.]+\)' | tr -d '()')
        [ -n "$_W_TTY" ] && [ -n "$_W_IP" ] && WHO_MAP["$_W_TTY"]="$_W_IP"
    done < <(who 2>/dev/null || true)

    local MSG="🖥 <b>SSH Sessions</b> — ${HOST}
🕐 ${NOW}
━━━━━━━━━━━━━━━━━━━━━
🟢 <b>Active: ${COUNT}</b>
━━━━━━━━━━━━━━━━━━━━━
"
    if [ "$COUNT" -gt 0 ]; then
        while IFS= read -r sess; do
            [ -z "$sess" ] && continue
            local U TTY LOGIN IDLE WHAT IP
            U=$(    echo "$sess" | awk '{print $1}')
            TTY=$(  echo "$sess" | awk '{print $2}')
            LOGIN=$(echo "$sess" | awk '{print $4}')
            IDLE=$( echo "$sess" | awk '{print $5}')
            WHAT=$( echo "$sess" | awk '{print $8}')
            if [ -n "${IP_MAP[$TTY]}" ]; then
                IP="${IP_MAP[$TTY]}"
            elif [ -n "${WHO_MAP[$TTY]}" ]; then
                IP="${WHO_MAP[$TTY]}"
            else
                IP="—"
            fi
            MSG+="👤 <b>${U}</b>  📟 <code>${TTY}</code>
🌍 <code>${IP}</code>
🕐 Login: ${LOGIN}  💤 Idle: ${IDLE}  ⚙️ ${WHAT}
━━━━━━━━━━━━━━━━━━━━━
"
        done <<< "$SESSIONS"
    else
        MSG+="  <i>No active sessions</i>"
    fi

    unset IP_MAP WHO_MAP
    echo "$MSG"
}

_tgb_net_report() {
    local HOST; HOST=$(hostname 2>/dev/null || echo "server")
    local NOW; NOW=$(date '+%Y-%m-%d %H:%M:%S')
    local IFACE RX TX
    IFACE=$(ip route 2>/dev/null | grep '^default' | awk '{print $5}' | head -1)
    [ -z "$IFACE" ] && IFACE="eth0"
    RX=$(awk -v i="${IFACE}:" '$1==i{print $2}' /proc/net/dev 2>/dev/null || echo 0)
    TX=$(awk -v i="${IFACE}:" '$1==i{print $10}' /proc/net/dev 2>/dev/null || echo 0)
    _fb() { local B=$1
        if [ "$B" -gt 1073741824 ]; then awk "BEGIN{printf \"%.2f GB\",$B/1073741824}"
        elif [ "$B" -gt 1048576 ]; then awk "BEGIN{printf \"%.2f MB\",$B/1048576}"
        elif [ "$B" -gt 1024 ]; then awk "BEGIN{printf \"%.2f KB\",$B/1024}"
        else echo "${B} B"; fi; }
    local IP4; IP4=$(_curl -4 ifconfig.me 2>/dev/null || echo "N/A")
    local IP6; IP6=$(ip -6 addr show scope global 2>/dev/null | grep -oE '([0-9a-f]{0,4}:){2,7}[0-9a-f]{0,4}' | head -1 || echo "N/A")
    echo "🌐 <b>Network Monitor</b> — ${HOST}
🕐 ${NOW}
━━━━━━━━━━━━━━━━━━━━━
📡 Interface: <b>${IFACE}</b>
🌐 IPv4: <code>${IP4}</code>
🌐 IPv6: <code>${IP6}</code>
━━━━━━━━━━━━━━━━━━━━━
📥 Download (since boot): $(_fb $RX)
📤 Upload   (since boot): $(_fb $TX)"
}

_tgb_sys_report() {
    _tg_build_sysusage_report
}

_tgb_srv_status() {
    local H KER UP LOAD4 MEM_PCT DSK_PCT
    H=$(hostname 2>/dev/null)
    KER=$(uname -r 2>/dev/null)
    UP=$(uptime -p 2>/dev/null | sed 's/up //')
    LOAD4=$(awk '{print $1" "$2" "$3}' /proc/loadavg 2>/dev/null)
    local RAM_T RAM_A RAM_U RAM_P
    RAM_T=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
    RAM_A=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
    RAM_U=$(( RAM_T - RAM_A )); [ "$RAM_U" -lt 0 ] && RAM_U=0
    RAM_P=$(( RAM_T > 0 ? RAM_U*100/RAM_T : 0 ))
    local DSK_U DSK_T DSK_FR DSK_P
    DSK_U=$(df -h / 2>/dev/null | awk 'NR==2{print $3}')
    DSK_T=$(df -h / 2>/dev/null | awk 'NR==2{print $2}')
    DSK_FR=$(df -h / 2>/dev/null | awk 'NR==2{print $4}')
    DSK_P=$(df / 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5);print $5}')
    echo "✅ <b>Server Status</b>
🖥 Host: <code>${H}</code>
🐧 Kernel: <code>${KER}</code>
⏱ Uptime: ${UP}
📊 Load: ${LOAD4}
━━━━━━━━━━━━━━━━━━━━━
🧠 RAM: ${RAM_P}%  (${RAM_U}MB / ${RAM_T}MB)
💾 Disk: ${DSK_P}%  Used:${DSK_U}  Free:${DSK_FR}  Total:${DSK_T}"
}

_tgb_ufw_report() {
    if ! command -v ufw &>/dev/null; then
        echo "🔥 <b>UFW Firewall</b>
❌ UFW is not installed on this server."
        return
    fi
    local STATUS RULES
    STATUS=$(ufw status 2>/dev/null | head -1)
    RULES=$(ufw status numbered 2>/dev/null | grep "^\[" | sed 's/^/  /' | head -20)
    [ -z "$RULES" ] && RULES="  <i>No rules defined</i>"
    echo "🔥 <b>UFW Firewall</b>
${STATUS}
━━━━━━━━━━━━━━━━━━━━━
<code>${RULES}</code>"
}

_tgb_f2b_report() {
    if ! command -v fail2ban-client &>/dev/null; then
        echo "🛡 <b>Fail2ban</b>
❌ Fail2ban is not installed."
        return
    fi
    local ST BANNED TOTAL
    ST=$(systemctl is-active fail2ban 2>/dev/null || echo "unknown")
    BANNED=$(fail2ban-client status sshd 2>/dev/null | grep -i "banned ip" | awk -F: '{print $2}' | xargs || echo "none")
    TOTAL=$(fail2ban-client status sshd 2>/dev/null | grep -i "total banned" | awk '{print $NF}' || echo "0")
    echo "🛡 <b>Fail2ban</b>
Status: <b>${ST}</b>
Banned IPs (SSH): <code>${BANNED:-none}</code>
Total bans: ${TOTAL}"
}

_tgb_port_report() {
    local HOST; HOST=$(hostname 2>/dev/null || echo "server")
    local NOW; NOW=$(date '+%Y-%m-%d %H:%M:%S')
    local PORTS
    if command -v ss &>/dev/null; then
        PORTS=$(ss -tlnp 2>/dev/null | awk 'NR>1{print $4}' | grep -oE '[0-9]+$' | sort -nu | head -20 | tr '\n' ' ')
    elif command -v netstat &>/dev/null; then
        PORTS=$(netstat -tlnp 2>/dev/null | awk 'NR>2{print $4}' | grep -oE '[0-9]+$' | sort -nu | head -20 | tr '\n' ' ')
    else
        PORTS="N/A"
    fi
    echo "🔌 <b>Port Manager</b> — ${HOST}
🕐 ${NOW}
━━━━━━━━━━━━━━━━━━━━━
<b>Listening TCP Ports:</b>
<code>${PORTS}</code>"
}

# ── Speed Test: send server list as inline buttons ───────────────
# ── Speed Test: run with specific server ID ──────────────────────
_tgb_run_speed() {
    local SERVER_ID="${1:-auto}"
    local ST_BIN=""
    command -v speedtest-cli &>/dev/null && ST_BIN="speedtest-cli"
    command -v speedtest     &>/dev/null && ST_BIN="speedtest"
    # Also try via python3 -m speedtest
    python3 -m speedtest --version &>/dev/null 2>&1 && ST_BIN="python3 -m speedtest"
    if [ -z "$ST_BIN" ]; then
        echo "⚡ <b>Speed Test</b>
❌ speedtest-cli not found.
Install: <code>pip3 install speedtest-cli</code>"
        return
    fi

    local RES
    if [ "$SERVER_ID" = "auto" ]; then
        RES=$($ST_BIN --simple 2>/dev/null)
    else
        RES=$($ST_BIN --simple --server "$SERVER_ID" 2>/dev/null)
    fi

    [ -z "$RES" ] && RES="Test failed. Check internet connection."

    local PING DL UL
    PING=$(echo "$RES" | grep -i "ping"     | awk '{print $2,$3}')
    DL=$(  echo "$RES" | grep -i "download" | awk '{print $2,$3}')
    UL=$(  echo "$RES" | grep -i "upload"   | awk '{print $2,$3}')
    [ -z "$PING" ] && PING="N/A"
    [ -z "$DL"   ] && DL="N/A"
    [ -z "$UL"   ] && UL="N/A"

    local SRV_LABEL="Auto"
    [ "$SERVER_ID" != "auto" ] && SRV_LABEL="Server #${SERVER_ID}"

    echo "⚡ <b>Speed Test Result</b>
📡 <b>${SRV_LABEL}</b>
🕐 $(date '+%Y-%m-%d %H:%M:%S')
━━━━━━━━━━━━━━━━━━━━━
🏓 Ping:     <b>${PING:-N/A}</b>
📥 Download: <b>${DL:-N/A}</b>
📤 Upload:   <b>${UL:-N/A}</b>"
}

# ── Main Bot Polling Loop ─────────────────────────────────────────
_tgb_polling_loop() {
    _tgb_load
    local OFFSET_FILE="/tmp/.tgbot_panel_offset"
    local PIDFILE="/tmp/.tgbot_panel.pid"
    local LOGFILE="/tmp/.tgbot_panel.log"
    local OFFSET=0
    [ -f "$OFFSET_FILE" ] && OFFSET=$(cat "$OFFSET_FILE" 2>/dev/null || echo 0)

    echo $$ > "$PIDFILE"
    echo "$(date): Bot started (PID $$)" >> "$LOGFILE"

    while true; do
        local RAW
        RAW=$(curl -s --max-time 15 \
            "https://api.telegram.org/bot${TG_BOT_TOKEN}/getUpdates?offset=${OFFSET}&timeout=10" \
            2>/dev/null)

        [ -z "$RAW" ] && sleep 3 && continue

        # Extract update IDs
        local IDS
        IDS=$(echo "$RAW" | grep -o '"update_id":[0-9]*' | grep -o '[0-9]*')
        [ -z "$IDS" ] && sleep 2 && continue

        while IFS= read -r UID_LINE; do
            [ -z "$UID_LINE" ] && continue
            OFFSET=$(( UID_LINE + 1 ))
            echo "$OFFSET" > "$OFFSET_FILE"

            # Parse via python3 or python
            local PARSED
            PARSED=$(echo "$RAW" | python3 -c "
import sys,json
try:
    data=json.load(sys.stdin)
    for u in data.get('result',[]):
        uid=str(u.get('update_id',''))
        if uid != '${UID_LINE}': continue
        chat_id=''
        text=''
        cb_id=''
        cb_data=''
        msg_id=''
        if 'message' in u:
            chat_id=str(u['message']['chat']['id'])
            text=u['message'].get('text','')
            msg_id=str(u['message'].get('message_id',''))
        elif 'callback_query' in u:
            cb=u['callback_query']
            chat_id=str(cb['message']['chat']['id'])
            cb_id=str(cb['id'])
            cb_data=cb.get('data','')
            msg_id=str(cb['message'].get('message_id',''))
        print('CHAT:'+chat_id)
        print('TEXT:'+text)
        print('CBID:'+cb_id)
        print('CBDATA:'+cb_data)
        print('MSGID:'+msg_id)
except: pass
" 2>/dev/null)

            local CHAT_ID MSG_TEXT CB_ID CB_DATA MSG_ID
            CHAT_ID=$(echo "$PARSED" | grep '^CHAT:'  | cut -d: -f2-)
            MSG_TEXT=$(echo "$PARSED" | grep '^TEXT:'  | cut -d: -f2-)
            CB_ID=$(  echo "$PARSED" | grep '^CBID:'  | cut -d: -f2-)
            CB_DATA=$(echo "$PARSED" | grep '^CBDATA:'| cut -d: -f2-)
            MSG_ID=$( echo "$PARSED" | grep '^MSGID:' | cut -d: -f2-)

            [ -z "$CHAT_ID" ] && continue

            # ── Security: only respond to authorized chat IDs ──────
            if [ -n "$TG_CHAT_ID" ] && [ "$CHAT_ID" != "$TG_CHAT_ID" ]; then
                echo "$(date): IGNORED unauthorized chat=${CHAT_ID}" >> "$LOGFILE"
                continue
            fi

            # Handle callback (button press)
            if [ -n "$CB_DATA" ]; then
                _tgb_answer_callback "$CB_ID" "⏳ Processing..."
                local REPLY=""
                case "$CB_DATA" in
                    main_menu)
                        local MENU_MSG MENU_KB
                        MENU_MSG=$(_tgb_build_menu_msg)
                        MENU_KB=$(_tgb_build_menu_kb)
                        _tgb_edit_msg "$CHAT_ID" "$MSG_ID" "$MENU_MSG" "$MENU_KB"
                        # Keep menu ID in sync so /start also edits this message
                        echo "$MSG_ID" > "/tmp/.tgbot_menu_msgid_${CHAT_ID}"
                        echo "$(date): cb=main_menu chat=${CHAT_ID}" >> "$LOGFILE"
                        continue ;;
                    ssh_session)
                        REPLY=$(_tgb_ssh_report) ;;
                    ufw_report)
                        REPLY=$(_tgb_ufw_report) ;;
                    f2b_report)
                        REPLY=$(_tgb_f2b_report) ;;
                    port_report)
                        REPLY=$(_tgb_port_report) ;;
                    *)
                        REPLY="❓ Unknown action." ;;
                esac
                [ -n "$REPLY" ] && _tgb_edit_back_btn "$CHAT_ID" "$MSG_ID" "$REPLY"
                echo "$(date): cb=${CB_DATA} chat=${CHAT_ID}" >> "$LOGFILE"

            # Handle text message — ONLY /start opens the panel; all other text silently ignored
            elif [ -n "$MSG_TEXT" ]; then
                local CMD; CMD=$(echo "$MSG_TEXT" | awk '{print $1}')
                if [ "$CMD" = "/start" ]; then
                    _tgb_send_glass_menu "$CHAT_ID"
                fi
                # Everything else (plain text, other commands) — ignore, no reply
                echo "$(date): msg=${CMD} chat=${CHAT_ID}" >> "$LOGFILE"
            fi

        done <<< "$IDS"
    done
}

# ── Telegram Bot Panel Menu ───────────────────────────────────────
menu_telegram_bot() {
    _tgb_load
    local PIDFILE="/tmp/.tgbot_panel.pid"

    while true; do
        clear
        sep_top
        row "$(printf '%*s%s' $(( (W - 20) / 2 )) '' 'Telegram Bot Panel')"
        sep_mid; blank

        # Bot status
        local BOT_RUNNING="no"
        if [ -f "$PIDFILE" ]; then
            local BPID; BPID=$(cat "$PIDFILE" 2>/dev/null)
            kill -0 "$BPID" 2>/dev/null && BOT_RUNNING="yes"
        fi

        if [ -z "$TG_BOT_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then
            rowc 42 "  Bot Token  : ${RED}Not Configured${NC}"
        else
            local TOK_DISP; TOK_DISP="${TG_BOT_TOKEN:0:10}...${TG_BOT_TOKEN: -4}"
            row "  Bot Token  : ${TOK_DISP}"
            row "  Chat ID    : ${TG_CHAT_ID}"
        fi

        if [ "$BOT_RUNNING" = "yes" ]; then
            rowc 44 "  Bot Status : ${GREEN}● Running (PID ${BPID})${NC}"
        else
            rowc 36 "  Bot Status : ${RED}● Stopped${NC}"
        fi

        blank; sep_mid; blank
        row "   1.  Configure Bot Token & Chat ID"
        row "   2.  Test Connection"
        row "   3.  Start Bot (polling)"
        row "   4.  Stop Bot"
        row "   5.  Send Glass Menu NOW to Telegram"
        row "   6.  View Bot Log"
        row "   0.  Back"
        blank; sep_bot; echo ""
        echo -ne "  ${YELLOW}> Select option: ${NC}"
        read -n 1 TBOPT; echo ""

        case $TBOPT in
            1)
                clear
                sep_top; row "$(printf '%*s%s' $(( (W-26)/2 )) '' 'Configure Telegram Bot')"; sep_mid; blank
                row "  How to get Bot Token:"
                row "  1. Open Telegram > search @BotFather"
                row "  2. Send /newbot and follow steps"
                row "  3. Copy the token BotFather gives you"
                blank
                row "  How to get Chat ID:"
                row "  1. Send /start to your bot"
                row "  2. Visit: api.telegram.org/bot<TOKEN>/getUpdates"
                row "  3. Find \"chat\":{\"id\": YOUR_CHAT_ID}"
                blank; sep_bot; echo ""
                echo -ne "  ${YELLOW}Bot Token : ${NC}"; read -r NEW_TOKEN
                [ -z "$NEW_TOKEN" ] && echo -e "  ${RED}Cancelled.${NC}" && sleep 1 && continue
                echo -ne "  ${YELLOW}Chat ID   : ${NC}"; read -r NEW_CHAT
                [ -z "$NEW_CHAT" ] && echo -e "  ${RED}Cancelled.${NC}" && sleep 1 && continue
                TG_BOT_TOKEN="$NEW_TOKEN"
                TG_CHAT_ID="$NEW_CHAT"
                _tgb_save
                # also save to old config if it exists
                _tg_save_cfg 2>/dev/null || true
                echo -e "\n  ${GREEN}[OK] Saved.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            2)
                echo ""
                if [ -z "$TG_BOT_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then
                    echo -e "  ${RED}[ERR] Not configured. Use option 1 first.${NC}"
                    sleep 2; continue
                fi
                echo -e "  ${CYAN}[*] Testing connection...${NC}"
                local T_RES
                T_RES=$(curl -s --max-time 8 \
                    "https://api.telegram.org/bot${TG_BOT_TOKEN}/getMe" 2>/dev/null)
                if echo "$T_RES" | grep -q '"ok":true'; then
                    local BOT_NAME
                    BOT_NAME=$(echo "$T_RES" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
                    echo -e "  ${GREEN}[OK] Connected! Bot: @${BOT_NAME}${NC}"
                else
                    echo -e "  ${RED}[ERR] Cannot reach bot. Check token.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            3)
                if [ -z "$TG_BOT_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then
                    echo -e "\n  ${RED}[ERR] Configure bot first (option 1).${NC}"
                    sleep 2; continue
                fi
                if [ "$BOT_RUNNING" = "yes" ]; then
                    echo -e "\n  ${YELLOW}[!] Bot already running (PID ${BPID}).${NC}"
                    sleep 2; continue
                fi
                echo -e "\n  ${CYAN}[*] Starting bot in background...${NC}"
                # Launch polling loop detached
                (
                    export TG_BOT_TOKEN TG_CHAT_ID
                    _tgb_polling_loop
                ) </dev/null >/dev/null 2>&1 &
                local NEW_PID=$!
                echo "$NEW_PID" > "$PIDFILE"
                sleep 1
                if kill -0 "$NEW_PID" 2>/dev/null; then
                    echo -e "  ${GREEN}[OK] Bot started (PID ${NEW_PID}).${NC}"
                    # Send initial glass menu
                    sleep 1
                    _tgb_send_glass_menu "$TG_CHAT_ID" && \
                        echo -e "  ${GREEN}[OK] Glass menu sent to Telegram.${NC}" || \
                        echo -e "  ${YELLOW}[!] Could not send initial menu.${NC}"
                else
                    echo -e "  ${RED}[ERR] Bot failed to start.${NC}"
                fi
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            4)
                if [ -f "$PIDFILE" ]; then
                    local KILL_PID; KILL_PID=$(cat "$PIDFILE" 2>/dev/null)
                    kill "$KILL_PID" 2>/dev/null && \
                        echo -e "\n  ${GREEN}[OK] Bot stopped.${NC}" || \
                        echo -e "\n  ${YELLOW}[!] Was not running.${NC}"
                    rm -f "$PIDFILE"
                else
                    echo -e "\n  ${YELLOW}[!] Bot not running.${NC}"
                fi
                sleep 2 ;;
            5)
                if [ -z "$TG_BOT_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then
                    echo -e "\n  ${RED}[ERR] Configure bot first.${NC}"
                    sleep 2; continue
                fi
                echo -e "\n  ${CYAN}[*] Sending glass menu to Telegram...${NC}"
                _tgb_send_glass_menu "$TG_CHAT_ID" "new" && \
                    echo -e "  ${GREEN}[OK] Menu sent!${NC}" || \
                    echo -e "  ${RED}[ERR] Failed. Check connection.${NC}"
                echo -ne "\n  ${DIM}Press any key...${NC}"; read -n 1 ;;
            6)
                clear
                sep_top; row "             Bot Log"; sep_mid; echo ""
                if [ -f "/tmp/.tgbot_panel.log" ]; then
                    tail -30 /tmp/.tgbot_panel.log | while IFS= read -r l; do echo "  $l"; done
                else
                    echo -e "  ${DIM}No log yet.${NC}"
                fi
                echo ""; sep_bot; echo ""
                echo -ne "  ${DIM}Press any key...${NC}"; read -n 1 ;;
            0) return ;;
            *) echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
        _tgb_load
    done
}

# ── Main Loop ────────────────────────────────────────────────────
while true; do
    show_menu
    read -r CHOICE; echo ""
    case $CHOICE in
        1)  menu_system ;;
        2)  menu_monitoring ;;
        3)  menu_network ;;
        4)  menu_security ;;
        5)  user_manager ;;
        6)  menu_panel ;;
        7)  menu_telegram_bot ;;
        0)  clear; echo -e "  ${DIM}Goodbye.${NC}"; echo ""; exit 0 ;;
        *)  echo -e "  ${RED}Invalid option.${NC}"; sleep 1 ;;
    esac
done
