#!/usr/bin/env bash
#
# boretube - Make TV boring. Parental control for Sony Bravia Google TV.
#
# Interactive menu (run without args) or CLI mode (run with args).
# Whitelist-based: only allowed apps can run, everything else gets killed + muted.
#

set -uo pipefail

TV_IP="192.168.1.3"
DIAL_PORT=8008
CAST_PORT=8009
LOCK_INTERVAL=10  # seconds between checks in lock mode
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_PYTHON="$SCRIPT_DIR/.venv/bin/python3"
WHITELIST_FILE="$SCRIPT_DIR/whitelist.conf"
LOG_FILE="$SCRIPT_DIR/boretube.log"

# ── Colors ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Initialize whitelist ────────────────────────────────
if [[ ! -f "$WHITELIST_FILE" ]]; then
    cat > "$WHITELIST_FILE" << 'EOF'
# boretube whitelist - one app per line: APP_ID|Friendly Name
# Only these apps are allowed to run. Everything else gets killed.
E8C28D3C|Backdrop (Home Screen)
EOF
fi

# ── Whitelist helpers ───────────────────────────────────
get_whitelist_ids() {
    grep -v '^#' "$WHITELIST_FILE" 2>/dev/null | grep -v '^$' | cut -d'|' -f1
}

get_whitelist_count() {
    get_whitelist_ids | wc -l | tr -d ' '
}

is_whitelisted() {
    local id="$1"
    local wid
    while IFS= read -r wid; do
        [[ "$wid" == "$id" ]] && return 0
    done < <(get_whitelist_ids)
    return 1
}

last_log_entry() {
    if [[ -f "$LOG_FILE" ]] && [[ -s "$LOG_FILE" ]]; then
        tail -1 "$LOG_FILE"
    fi
}

# ── CastV2 protocol engine ─────────────────────────────
# Supports multiple actions in one connection for performance.
# Usage: cast_command "action" ["extra"]
#   action: status, mute, unmute, stop_app, bore (stop+mute combo), volume
# Returns JSON on stdout.
cast_command() {
    local action="$1"
    local extra="${2:-}"
    "$VENV_PYTHON" - "$TV_IP" "$CAST_PORT" "$action" "$extra" << 'PYEOF'
import socket, ssl, struct, json, sys
from google.protobuf.internal.encoder import _VarintBytes
from google.protobuf.internal.decoder import _DecodeVarint32

TV_IP, CAST_PORT, action, extra = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]

CONNECT_TIMEOUT = 5
RECV_TIMEOUT = 3

def encode_string(fn, v):
    tag = (fn << 3) | 2
    e = v.encode('utf-8')
    return _VarintBytes(tag) + _VarintBytes(len(e)) + e

def encode_varint(fn, v):
    return _VarintBytes((fn << 3) | 0) + _VarintBytes(v)

def build_msg(ns, payload, src="sender-0", dst="receiver-0"):
    msg = encode_varint(1, 0) + encode_string(2, src) + encode_string(3, dst)
    msg += encode_string(4, ns) + encode_varint(5, 0) + encode_string(6, payload)
    return struct.pack('>I', len(msg)) + msg

def read_msg(ssock):
    try:
        length_bytes = ssock.recv(4)
    except (socket.timeout, ssl.SSLError):
        return None
    if len(length_bytes) < 4: return None
    msg_length = struct.unpack('>I', length_bytes)[0]
    if msg_length > 65536: return None  # sanity check
    data = b''
    while len(data) < msg_length:
        try:
            chunk = ssock.recv(msg_length - len(data))
        except (socket.timeout, ssl.SSLError):
            break
        if not chunk: break
        data += chunk
    # Extract JSON payload - find ALL string fields, return the one that's valid JSON with expected keys
    candidates = []
    i = 0
    while i < len(data):
        try:
            wire_type = data[i] & 0x07
            if wire_type == 2:
                val, new_pos = _DecodeVarint32(data, i + 1)
                content = data[new_pos:new_pos + val]
                try:
                    s = content.decode('utf-8')
                    if '{' in s:
                        parsed = json.loads(s)
                        if isinstance(parsed, dict):
                            candidates.append(parsed)
                except: pass
                i = new_pos + val
            elif wire_type == 0:
                _, i = _DecodeVarint32(data, i + 1)
            else: i += 1
        except: i += 1
    # Prefer the response with 'status' or 'type' key (actual Cast responses)
    for c in candidates:
        if 'status' in c or 'type' in c:
            return c
    return candidates[0] if candidates else None

def send_cmd(ssock, payload, req_id=1):
    NS_RECV = "urn:x-cast:com.google.cast.receiver"
    payload["requestId"] = req_id
    ssock.send(build_msg(NS_RECV, json.dumps(payload)))

NS_CONN = "urn:x-cast:com.google.cast.tp.connection"
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

try:
    sock = socket.create_connection((TV_IP, CAST_PORT), timeout=CONNECT_TIMEOUT)
    ssock = ctx.wrap_socket(sock, server_hostname=TV_IP)
except Exception as e:
    json.dump({"_error": str(e)}, sys.stdout)
    sys.exit(1)

ssock.send(build_msg(NS_CONN, '{"type":"CONNECT"}'))
ssock.settimeout(RECV_TIMEOUT)

try:
    if action == "status":
        send_cmd(ssock, {"type": "GET_STATUS"})
        # Read until we get a RECEIVER_STATUS response (skip CONNECT ack etc)
        for _ in range(5):
            resp = read_msg(ssock)
            if resp and resp.get('type') == 'RECEIVER_STATUS':
                break
        if resp and 'status' in resp:
            vol = resp['status'].get('volume', {})
            apps = resp['status'].get('applications', [])
            result = {"volume": round(vol.get('level', 0) * 100), "muted": vol.get('muted', False),
                      "app_id": "", "app_name": "", "idle": True}
            if apps:
                app = apps[0]
                result["app_id"] = app.get("appId", "")
                result["app_name"] = app.get("displayName", "")
                result["idle"] = app.get("isIdleScreen", False)
            json.dump(result, sys.stdout)
        else:
            json.dump({"_error": "no status response"}, sys.stdout)

    elif action == "mute":
        send_cmd(ssock, {"type": "SET_VOLUME", "volume": {"muted": True}})
        json.dump({"ok": True}, sys.stdout)

    elif action == "unmute":
        send_cmd(ssock, {"type": "SET_VOLUME", "volume": {"muted": False}})
        json.dump({"ok": True}, sys.stdout)

    elif action == "stop_app":
        send_cmd(ssock, {"type": "STOP"})
        json.dump({"ok": True}, sys.stdout)

    elif action == "bore":
        # STOP + MUTE in one connection (avoids second TLS handshake)
        send_cmd(ssock, {"type": "STOP"}, req_id=1)
        import time; time.sleep(0.3)  # brief pause so TV processes STOP before MUTE
        send_cmd(ssock, {"type": "SET_VOLUME", "volume": {"muted": True}}, req_id=2)
        json.dump({"ok": True}, sys.stdout)

    elif action == "volume":
        level = max(0, min(100, int(extra))) / 100.0
        send_cmd(ssock, {"type": "SET_VOLUME", "volume": {"level": level}})
        json.dump({"ok": True, "level": int(level*100)}, sys.stdout)

except Exception as e:
    json.dump({"_error": str(e)}, sys.stdout)
finally:
    try: ssock.close()
    except: pass
PYEOF
}

# ── JSON helpers (no extra python spawn) ────────────────
has_error() {
    [[ "$1" == *'"_error"'* ]]
}

# Parse multiple fields in one python call. Prints one field per line.
json_fields() {
    local json_str="$1"
    shift
    local fields_arg=""
    local f
    for f in "$@"; do fields_arg+="\"$f\","; done
    "$VENV_PYTHON" -c "
import sys, json
d = json.loads(sys.argv[1])
for k in [${fields_arg}]:
    print(d.get(k, ''))
" "$json_str"
}

# ── TV reachability ─────────────────────────────────────
check_tv() {
    if ! timeout 2 bash -c "echo >/dev/tcp/$TV_IP/$DIAL_PORT" 2>/dev/null; then
        echo -e "${RED}  TV at $TV_IP is not reachable (is it turned on?)${RESET}"
        return 1
    fi
}

# ── Log ─────────────────────────────────────────────────
log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# ── Restore TV to normal state ──────────────────────────
do_restore() {
    cast_command "unmute" > /dev/null 2>&1 || true
}

# ── Kill app + mute (optimized: single CastV2 connection) ─
do_bore() {
    # Single CastV2 connection: STOP + MUTE
    cast_command "bore" > /dev/null 2>&1 || true
    # Also kill via DIAL (more reliable for specific apps)
    timeout 2 curl -s -o /dev/null -X DELETE "http://$TV_IP:$DIAL_PORT/apps/YouTube/run" 2>/dev/null &
    timeout 2 curl -s -o /dev/null -X DELETE "http://$TV_IP:$DIAL_PORT/apps/Netflix/run" 2>/dev/null &
    wait  # parallel DIAL kills
}

# ── Ctrl+C / exit trap ─────────────────────────────────
LOCK_ACTIVE=false
VOLLLOCK_ACTIVE=false

cleanup() {
    if [[ "$LOCK_ACTIVE" == true ]]; then
        echo ""
        echo -e "  ${YELLOW}Lock stopped. Unmuting TV...${RESET}"
        do_restore
        log_action "LOCK stopped by user, TV unmuted"
        echo -e "  ${GREEN}Done — TV unmuted.${RESET}"
    fi
    if [[ "$VOLLLOCK_ACTIVE" == true ]]; then
        echo ""
        echo -e "  ${YELLOW}Volume lock stopped.${RESET}"
        log_action "VOLLOCK stopped by user"
    fi
    LOCK_ACTIVE=false
    VOLLLOCK_ACTIVE=false
}

trap cleanup INT TERM

# ── Draw banner ─────────────────────────────────────────
draw_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════╗"
    echo "  ║       BORETUBE - Parental Control         ║"
    echo "  ║        Sony Bravia Google TV (VU3)        ║"
    echo "  ╚═══════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# ── Show TV status panel (rich, replaces old one-liner) ─
show_status_panel() {
    local sj
    sj=$(cast_command "status" 2>/dev/null) || sj='{"_error":"unreachable"}'

    if has_error "$sj"; then
        echo -e "  ${BOLD}Status:${RESET}  ${RED}● OFF or unreachable${RESET}"
        echo -e "  ${DIM}Waiting for TV to come online...${RESET}"
        echo ""
        echo -e "  ${DIM}───────────────────────────────────────────${RESET}"
        echo ""
        return 1
    fi

    local parsed
    parsed=$(json_fields "$sj" volume muted app_name app_id idle)

    local vol muted app_name app_id is_idle
    { read -r vol; read -r muted; read -r app_name; read -r app_id; read -r is_idle; } <<< "$parsed"

    # Connection
    echo -e "  ${BOLD}Status:${RESET}  ${GREEN}● Connected${RESET}"

    # Running app
    if [[ "$is_idle" == "True" ]]; then
        echo -e "  ${BOLD}Running:${RESET} ${DIM}Home Screen (idle)${RESET}"
    elif is_whitelisted "$app_id"; then
        echo -e "  ${BOLD}Running:${RESET} ${BOLD}${app_name}${RESET} ${DIM}(whitelisted)${RESET}"
    else
        echo -e "  ${BOLD}Running:${RESET} ${BOLD}${app_name}${RESET} ${DIM}(${RED}not whitelisted${RESET}${DIM})${RESET}"
    fi

    # Volume bar
    local vol_int="${vol:-0}"
    local bar_filled=$((vol_int / 10))
    local bar_empty=$((10 - bar_filled))
    local bar=""
    local i
    for ((i=0; i<bar_filled; i++)); do bar+="█"; done
    for ((i=0; i<bar_empty; i++)); do bar+="░"; done

    if [[ "$muted" == "True" ]]; then
        echo -e "  ${BOLD}Volume:${RESET}  ${RED}${bar} ${vol_int}% MUTED${RESET}"
    else
        echo -e "  ${BOLD}Volume:${RESET}  ${GREEN}${bar}${RESET} ${vol_int}%"
    fi

    echo ""

    # Info line: whitelist count + last log
    local wl_count
    wl_count=$(get_whitelist_count)
    echo -e "  ${DIM}Allowed: ${wl_count} app(s) | Lock checks every ${LOCK_INTERVAL}s${RESET}"

    local last_log
    last_log=$(last_log_entry)
    if [[ -n "$last_log" ]]; then
        local trimmed="${last_log:0:60}"
        if echo "$last_log" | grep -qE "STOPPED|KILLED"; then
            echo -e "  ${DIM}Last:${RESET} ${RED}${trimmed}${RESET}"
        else
            echo -e "  ${DIM}Last: ${trimmed}${RESET}"
        fi
    fi

    echo ""
    echo -e "  ${DIM}───────────────────────────────────────────${RESET}"
    echo ""
}

# ── Press Enter helper ──────────────────────────────────
pause() {
    echo ""
    echo -e "  ${DIM}Press Enter to continue...${RESET}"
    read -r
}

# ── Action: Lock mode ───────────────────────────────────
action_lock() {
    echo -e "  ${BOLD}${CYAN}Lock Mode${RESET}"
    echo -e "  ${DIM}Only whitelisted apps can run. Everything else gets stopped and TV muted.${RESET}"
    echo -e "  ${DIM}Checks every ${LOCK_INTERVAL}s. Kid has at most ~${LOCK_INTERVAL}s before app is stopped.${RESET}"
    echo ""
    read -rp "  Duration in minutes [60]: " lock_mins
    lock_mins="${lock_mins:-60}"

    if ! [[ "$lock_mins" =~ ^[0-9]+$ ]] || [[ "$lock_mins" -eq 0 ]]; then
        echo -e "  ${RED}Invalid duration.${RESET}"
        pause; return
    fi

    local end_time=$(($(date +%s) + lock_mins * 60))
    local total_checks=$(( (lock_mins * 60) / LOCK_INTERVAL ))

    echo ""
    echo -e "  ${RED}${BOLD}  Enforcing whitelist for ${lock_mins} minutes${RESET}"
    echo -e "  ${DIM}  Checking every ${LOCK_INTERVAL}s (~${total_checks} checks). Press Ctrl+C to stop.${RESET}"
    echo ""

    log_action "LOCK started for $lock_mins min (interval=${LOCK_INTERVAL}s)"
    LOCK_ACTIVE=true

    while [[ "$LOCK_ACTIVE" == true ]] && [[ $(date +%s) -lt $end_time ]]; do
        local now
        now=$(date +%s)
        local remaining_s=$((end_time - now))
        local remaining_m=$((remaining_s / 60))
        local remaining_display
        if [[ $remaining_s -lt 60 ]]; then
            remaining_display="${remaining_s}s"
        else
            remaining_display="${remaining_m}m"
        fi

        local sj
        sj=$(cast_command "status" 2>/dev/null) || sj='{"_error":"connect"}'

        if has_error "$sj"; then
            echo -e "  ${DIM}[$(date '+%H:%M:%S')]${RESET} TV is off or in standby ${DIM}(${remaining_display} left)${RESET}"
            sleep "$LOCK_INTERVAL" || break
            continue
        fi

        local parsed
        parsed=$(json_fields "$sj" app_id app_name idle)

        local app_id app_name is_idle
        { read -r app_id; read -r app_name; read -r is_idle; } <<< "$parsed"

        if [[ "$is_idle" == "True" ]]; then
            echo -e "  ${GREEN}[$(date '+%H:%M:%S')]${RESET} Home screen (idle) ${DIM}(${remaining_display} left)${RESET}"
        elif is_whitelisted "$app_id"; then
            echo -e "  ${GREEN}[$(date '+%H:%M:%S')]${RESET} ${app_name} ${DIM}(whitelisted) (${remaining_display} left)${RESET}"
        else
            echo -e "  ${RED}[$(date '+%H:%M:%S')] Stopped: ${app_name}${RESET} ${DIM}(not whitelisted) (${remaining_display} left)${RESET}"
            log_action "STOPPED: $app_name ($app_id)"
            do_bore
        fi

        sleep "$LOCK_INTERVAL" || break
    done

    if [[ "$LOCK_ACTIVE" == true ]]; then
        LOCK_ACTIVE=false
        log_action "LOCK ended (timer expired)"
        echo ""
        echo -e "  ${YELLOW}Timer expired. TV is still muted.${RESET}"
        echo -e "  ${DIM}Use option 3 (Restore TV) to unmute.${RESET}"
    fi
    pause
}

# ── Action: Volume Lock mode ───────────────────────────
action_volume_lock() {
    echo -e "  ${BOLD}${CYAN}Volume Lock${RESET}"
    echo -e "  ${DIM}Kid can watch TV, but volume is capped at a max you set.${RESET}"
    echo -e "  ${DIM}If they turn it up, it gets pushed back down within ~${LOCK_INTERVAL}s.${RESET}"
    echo ""
    read -rp "  Max volume % [15]: " max_vol
    max_vol="${max_vol:-15}"

    if ! [[ "$max_vol" =~ ^[0-9]+$ ]] || [[ "$max_vol" -eq 0 ]] || [[ "$max_vol" -gt 100 ]]; then
        echo -e "  ${RED}Invalid volume (1-100).${RESET}"
        pause; return
    fi

    echo ""
    read -rp "  Duration in minutes [60]: " lock_mins
    lock_mins="${lock_mins:-60}"

    if ! [[ "$lock_mins" =~ ^[0-9]+$ ]] || [[ "$lock_mins" -eq 0 ]]; then
        echo -e "  ${RED}Invalid duration.${RESET}"
        pause; return
    fi

    local end_time=$(($(date +%s) + lock_mins * 60))

    echo ""
    echo -e "  ${YELLOW}${BOLD}  Volume capped at ${max_vol}% for ${lock_mins} minutes${RESET}"
    echo -e "  ${DIM}  Checking every ${LOCK_INTERVAL}s. Press Ctrl+C to stop.${RESET}"
    echo ""

    log_action "VOLLOCK started: max=${max_vol}% for ${lock_mins}min"
    VOLLLOCK_ACTIVE=true

    while [[ "$VOLLLOCK_ACTIVE" == true ]] && [[ $(date +%s) -lt $end_time ]]; do
        local now
        now=$(date +%s)
        local remaining_s=$((end_time - now))
        local remaining_m=$((remaining_s / 60))
        local remaining_display
        if [[ $remaining_s -lt 60 ]]; then
            remaining_display="${remaining_s}s"
        else
            remaining_display="${remaining_m}m"
        fi

        local sj
        sj=$(cast_command "status" 2>/dev/null) || sj='{"_error":"connect"}'

        if has_error "$sj"; then
            echo -e "  ${DIM}[$(date '+%H:%M:%S')]${RESET} TV is off or in standby ${DIM}(${remaining_display} left)${RESET}"
            sleep "$LOCK_INTERVAL" || break
            continue
        fi

        local parsed
        parsed=$(json_fields "$sj" volume muted app_name)

        local vol muted app_name
        { read -r vol; read -r muted; read -r app_name; } <<< "$parsed"

        local vol_int="${vol:-0}"

        if [[ "$muted" == "True" ]]; then
            echo -e "  ${GREEN}[$(date '+%H:%M:%S')]${RESET} ${app_name:-idle} ${DIM}vol=${vol_int}% MUTED (${remaining_display} left)${RESET}"
        elif [[ "$vol_int" -gt "$max_vol" ]]; then
            cast_command "volume" "$max_vol" > /dev/null 2>&1 || true
            echo -e "  ${YELLOW}[$(date '+%H:%M:%S')] ${app_name:-idle} vol=${vol_int}% → capped to ${max_vol}%${RESET} ${DIM}(${remaining_display} left)${RESET}"
            log_action "VOLLOCK: ${app_name} vol ${vol_int}% → ${max_vol}%"
        else
            echo -e "  ${GREEN}[$(date '+%H:%M:%S')]${RESET} ${app_name:-idle} ${DIM}vol=${vol_int}% ok (${remaining_display} left)${RESET}"
        fi

        sleep "$LOCK_INTERVAL" || break
    done

    if [[ "$VOLLLOCK_ACTIVE" == true ]]; then
        VOLLLOCK_ACTIVE=false
        log_action "VOLLOCK ended (timer expired)"
        echo ""
        echo -e "  ${YELLOW}Timer expired. Volume cap removed.${RESET}"
    fi
    pause
}

# ── Action: Whitelist management ────────────────────────
action_whitelist() {
    while true; do
        clear
        echo -e "  ${BOLD}${CYAN}Whitelist Management${RESET}"
        echo ""
        echo -e "  ${BOLD}Allowed apps:${RESET}"
        echo ""
        local count=0
        while IFS= read -r line; do
            [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
            local wl_id="${line%%|*}"
            local wl_name="${line#*|}"
            echo -e "    ${GREEN}${wl_id}${RESET}  ${wl_name}"
            count=$((count + 1))
        done < "$WHITELIST_FILE"
        [[ "$count" -eq 0 ]] && echo -e "    ${DIM}(none — all apps will be stopped in lock mode)${RESET}"
        echo ""
        echo -e "  ${DIM}Apps not listed here will be stopped and muted during lock mode.${RESET}"
        echo -e "  ${DIM}───────────────────────────────────────────${RESET}"
        echo ""
        echo -e "  ${BOLD}a)${RESET} Add an app to whitelist"
        echo -e "  ${BOLD}d)${RESET} Remove an app from whitelist"
        echo -e "  ${BOLD}i)${RESET} What app is running on TV now?"
        echo -e "  ${BOLD}b)${RESET} Back"
        echo ""
        read -rp "  Choice: " wl_choice

        case "$wl_choice" in
            a|A)
                echo ""
                read -rp "  App ID: " new_id
                if [[ -z "$new_id" ]]; then
                    echo -e "  ${RED}No ID entered.${RESET}"; sleep 1; continue
                fi
                if grep -q "^${new_id}|" "$WHITELIST_FILE" 2>/dev/null; then
                    echo -e "  ${YELLOW}This app is already in the whitelist.${RESET}"; sleep 1; continue
                fi
                read -rp "  App name: " new_name
                echo "${new_id}|${new_name:-Unknown}" >> "$WHITELIST_FILE"
                echo -e "  ${GREEN}Added: ${new_id} (${new_name:-Unknown})${RESET}"
                sleep 1
                ;;
            d|D)
                echo ""
                read -rp "  App ID to remove: " rm_id
                if [[ -z "$rm_id" ]]; then
                    echo -e "  ${RED}No ID entered.${RESET}"; sleep 1; continue
                fi
                if [[ "$rm_id" == "E8C28D3C" ]]; then
                    echo -e "  ${RED}Backdrop (Home Screen) cannot be removed — it's the default idle screen.${RESET}"; sleep 1; continue
                fi
                if grep -q "^${rm_id}|" "$WHITELIST_FILE"; then
                    grep -v "^${rm_id}|" "$WHITELIST_FILE" > "$WHITELIST_FILE.tmp"
                    mv "$WHITELIST_FILE.tmp" "$WHITELIST_FILE"
                    echo -e "  ${YELLOW}Removed: ${rm_id}${RESET}"
                else
                    echo -e "  ${RED}Not found in whitelist.${RESET}"
                fi
                sleep 1
                ;;
            i|I)
                echo ""
                echo -e "  ${DIM}Reading current app from TV...${RESET}"
                if ! check_tv 2>/dev/null; then
                    echo -e "  ${RED}TV not reachable.${RESET}"
                    pause; continue
                fi
                local sj
                sj=$(cast_command "status" 2>/dev/null) || sj='{"_error":"err"}'
                if has_error "$sj"; then
                    echo -e "  ${RED}Could not read TV status.${RESET}"
                else
                    local id_parsed
                    id_parsed=$(json_fields "$sj" app_name app_id idle)
                    local ci_name ci_id ci_idle
                    { read -r ci_name; read -r ci_id; read -r ci_idle; } <<< "$id_parsed"
                    echo ""
                    echo -e "  ${BOLD}Running now:${RESET} ${ci_name}"
                    echo -e "  ${BOLD}App ID:${RESET}      ${ci_id}"
                    if [[ "$ci_idle" == "True" ]]; then
                        echo -e "  ${DIM}Home screen (idle) — always allowed.${RESET}"
                    elif is_whitelisted "$ci_id"; then
                        echo -e "  ${GREEN}This app is in the whitelist.${RESET}"
                    else
                        echo -e "  ${YELLOW}Not in whitelist — will be stopped during lock mode.${RESET}"
                        echo -e "  ${DIM}Tip: Use (a) and enter ${ci_id} to allow it.${RESET}"
                    fi
                fi
                pause
                ;;
            b|B) return ;;
            *) ;;
        esac
    done
}


# ── Action: View log ────────────────────────────────────
action_log() {
    echo -e "  ${BOLD}${CYAN}Enforcement Log${RESET} ${DIM}(last 20 entries)${RESET}"
    echo ""
    if [[ -f "$LOG_FILE" ]] && [[ -s "$LOG_FILE" ]]; then
        tail -20 "$LOG_FILE" | while IFS= read -r logline; do
            if echo "$logline" | grep -qE "KILLED|STOPPED"; then
                echo -e "  ${RED}${logline}${RESET}"
            else
                echo -e "  ${DIM}${logline}${RESET}"
            fi
        done
    else
        echo -e "  ${DIM}No logs yet.${RESET}"
    fi
    pause
}


# ── Quit with restore prompt ───────────────────────────
do_quit() {
    echo ""
    local should_ask=false
    if check_tv 2>/dev/null; then
        local sj
        sj=$(cast_command "status" 2>/dev/null) || sj='{"_error":"x"}'
        if ! has_error "$sj"; then
            local muted
            muted=$(json_fields "$sj" muted)
            [[ "$muted" == "True" ]] && should_ask=true
        fi
    fi

    if [[ "$should_ask" == true ]]; then
        echo -e "  ${YELLOW}TV is still muted from a previous action.${RESET}"
        read -rp "  Unmute TV before quitting? (Y/n): " restore_choice
        if [[ "$restore_choice" != "n" && "$restore_choice" != "N" ]]; then
            do_restore
            echo -e "  ${GREEN}TV unmuted.${RESET}"
            log_action "RESTORE on quit"
        fi
    fi
    echo -e "\n  ${DIM}Bye!${RESET}\n"
    exit 0
}

# ── Main interactive menu ───────────────────────────────
main_menu() {
    while true; do
        draw_banner
        show_status_panel 2>/dev/null

        echo -e "  ${BOLD}1)${RESET}  ${RED}Lock${RESET}          ${DIM}Auto-enforce whitelist for X min${RESET}"
        echo -e "  ${BOLD}2)${RESET}  ${YELLOW}Volume Lock${RESET}   ${DIM}Cap volume at max % for X min${RESET}"
        echo -e "  ${BOLD}3)${RESET}  ${GREEN}Restore TV${RESET}    ${DIM}Unmute TV, let all apps run${RESET}"
        echo -e "  ${BOLD}4)${RESET}  Whitelist     ${DIM}Manage which apps are allowed${RESET}"
        echo -e "  ${BOLD}5)${RESET}  ${DIM}Log${RESET}           ${DIM}View activity log${RESET}"
        echo ""
        echo -e "  ${BOLD}q)${RESET}  Quit"
        echo ""
        # Auto-refresh status every 10s while waiting for input
        if ! read -rp "  Choose [1-5, q]: " -t 10 choice; then
            continue  # timeout — redraw menu with fresh status
        fi

        case "$choice" in
            1) check_tv && action_lock || pause ;;
            2) check_tv && action_volume_lock || pause ;;
            3)
                if check_tv; then
                    do_restore
                    echo -e "  ${GREEN}TV unmuted. All apps can run freely.${RESET}"
                    log_action "RESTORE: manual unmute"
                    pause
                else
                    pause
                fi
                ;;
            4) action_whitelist ;;
            5) action_log ;;
            q|Q) do_quit ;;
            *) ;;
        esac
    done
}

# ── CLI mode ────────────────────────────────────────────
cli_mode() {
    case "$1" in
        status)     check_tv && cast_command "status" ;;
        kill)       check_tv && { cast_command "stop_app" > /dev/null; echo "App stopped"; } ;;
        mute)       check_tv && { cast_command "mute" > /dev/null; echo "TV muted"; } ;;
        unmute)     check_tv && { cast_command "unmute" > /dev/null; echo "TV unmuted"; } ;;
        volume)     check_tv && { cast_command "volume" "${2:-50}" > /dev/null; echo "Volume set to ${2:-50}%"; } ;;
        bore)       check_tv && { do_bore; echo "App stopped, TV muted"; } ;;
        restore)    check_tv && { do_restore; echo "TV unmuted"; } ;;
        lock)
            check_tv || exit 1
            local lock_mins="${2:-60}"
            local end_time=$(($(date +%s) + lock_mins * 60))
            echo "Enforcing whitelist for ${lock_mins}m, checking every ${LOCK_INTERVAL}s. Ctrl+C to stop."
            log_action "LOCK started for $lock_mins min (interval=${LOCK_INTERVAL}s)"
            LOCK_ACTIVE=true
            while [[ "$LOCK_ACTIVE" == true ]] && [[ $(date +%s) -lt $end_time ]]; do
                local remaining=$(( (end_time - $(date +%s)) / 60 ))
                local sj
                sj=$(cast_command "status" 2>/dev/null) || sj='{"_error":"x"}'
                if has_error "$sj"; then
                    echo "[$(date '+%H:%M:%S')] TV off/standby (${remaining}m left)"
                    sleep "$LOCK_INTERVAL" || break; continue
                fi
                local parsed
                parsed=$(json_fields "$sj" app_id app_name idle)
                local app_id app_name is_idle
                { read -r app_id; read -r app_name; read -r is_idle; } <<< "$parsed"
                if [[ "$is_idle" == "True" ]]; then
                    echo "[$(date '+%H:%M:%S')] Home (idle) (${remaining}m)"
                elif is_whitelisted "$app_id"; then
                    echo "[$(date '+%H:%M:%S')] $app_name (whitelisted) (${remaining}m)"
                else
                    echo "[$(date '+%H:%M:%S')] Stopped: $app_name (not whitelisted) (${remaining}m)"
                    log_action "STOPPED: $app_name ($app_id)"; do_bore
                fi
                sleep "$LOCK_INTERVAL" || break
            done
            if [[ "$LOCK_ACTIVE" == true ]]; then
                LOCK_ACTIVE=false; log_action "LOCK ended"; echo "Lock ended."
            fi
            ;;
        whitelist)
            while IFS= read -r line; do
                [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
                echo "${line%%|*}  ${line#*|}"
            done < "$WHITELIST_FILE"
            ;;
        allow)
            [[ -z "${2:-}" ]] && echo "Usage: $0 allow <ID> [name]" && exit 1
            if grep -q "^${2}|" "$WHITELIST_FILE" 2>/dev/null; then
                echo "Already whitelisted: ${2}"; exit 0
            fi
            echo "${2}|${3:-Unknown}" >> "$WHITELIST_FILE"
            echo "Added: ${2}|${3:-Unknown}"
            ;;
        deny)
            [[ -z "${2:-}" ]] && echo "Usage: $0 deny <ID>" && exit 1
            if [[ "$2" == "E8C28D3C" ]]; then
                echo "Cannot remove Backdrop (Home Screen)"; exit 1
            fi
            if grep -q "^${2}|" "$WHITELIST_FILE"; then
                grep -v "^${2}|" "$WHITELIST_FILE" > "$WHITELIST_FILE.tmp"
                mv "$WHITELIST_FILE.tmp" "$WHITELIST_FILE"
                echo "Removed: ${2}"
            else
                echo "Not in whitelist: ${2}"; exit 1
            fi
            ;;
        log)
            [[ -f "$LOG_FILE" ]] && [[ -s "$LOG_FILE" ]] && tail -30 "$LOG_FILE" || echo "No logs"
            ;;
        *)
            echo "Usage: $0 [status|kill|mute|unmute|volume|bore|restore|lock|whitelist|allow|deny|log]"
            echo "Or run without arguments for interactive menu."
            ;;
    esac
}

# ── Entry point ─────────────────────────────────────────
if [[ $# -eq 0 ]]; then
    main_menu
else
    cli_mode "$@"
fi
