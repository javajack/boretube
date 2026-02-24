#!/usr/bin/env bash
#
# detect.sh - Find Google Cast / Smart TV devices on your network.
#
# Scans local and upstream subnets for devices with Cast ports open (8008/8009),
# verifies them via DIAL protocol, and saves the result to tv.conf for boretube.
#
# Works across subnets (e.g., laptop on 192.168.31.x, TV on 192.168.1.x).
# No dependencies beyond bash and curl.
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_FILE="$SCRIPT_DIR/tv.conf"

# ── Colors ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── State ───────────────────────────────────────────────
FOUND_DEVICES=()    # "ip|name|model" entries
SUBNETS_SCANNED=()
METHODS_TRIED=()

# ── Helpers ─────────────────────────────────────────────
info()  { echo -e "  ${CYAN}>>>${RESET} $*"; }
ok()    { echo -e "  ${GREEN} ✓${RESET} $*"; }
warn()  { echo -e "  ${YELLOW} !${RESET} $*"; }
fail()  { echo -e "  ${RED} ✗${RESET} $*"; }
dim()   { echo -e "  ${DIM}   $*${RESET}"; }

# Check if a TCP port is open (timeout in seconds)
port_open() {
    local host="$1" port="$2" tout="${3:-2}"
    timeout "$tout" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null
}

# Check if a host responds to ping (1 packet, 1s timeout)
host_alive() {
    ping -c 1 -W 1 "$1" &>/dev/null
}

# Query DIAL device description and extract friendly name + manufacturer
dial_identify() {
    local ip="$1"
    local xml
    xml=$(timeout 3 curl -s "http://$ip:8008/ssdp/device-desc.xml" 2>/dev/null) || return 1

    local name
    name=$(echo "$xml" | grep -oP '(?<=<friendlyName>)[^<]+' 2>/dev/null)
    [[ -z "$name" ]] && return 1

    local manufacturer
    manufacturer=$(echo "$xml" | grep -oP '(?<=<manufacturer>)[^<]+' 2>/dev/null)

    local model
    model=$(echo "$xml" | grep -oP '(?<=<modelName>)[^<]+' 2>/dev/null)

    echo "${name}|${manufacturer:-Unknown}|${model:-Unknown}"
}

# Extract the /24 subnet base from an IP (e.g., 192.168.1.5 → 192.168.1)
subnet_base() {
    echo "${1%.*}"
}

# ── Phase 1: Discover local subnets ────────────────────
discover_subnets() {
    info "Finding local network interfaces..."
    METHODS_TRIED+=("Local interface detection via ip/ifconfig")

    local subnets=()

    # Method 1: ip route (Linux)
    if command -v ip &>/dev/null; then
        local gw
        gw=$(ip route | grep '^default' | head -1 | awk '{print $3}')
        if [[ -n "$gw" ]]; then
            local base
            base=$(subnet_base "$gw")
            subnets+=("$base")
            ok "Local gateway: ${gw} (subnet ${base}.0/24)"
        fi

        # Also check all local IPs for additional subnets
        while IFS= read -r line; do
            local ip
            ip=$(echo "$line" | awk '{print $2}' | cut -d/ -f1)
            [[ "$ip" == 127.* ]] && continue
            local base
            base=$(subnet_base "$ip")
            local already=false
            local s
            for s in ${subnets[@]+"${subnets[@]}"}; do
                [[ "$s" == "$base" ]] && already=true
            done
            if [[ "$already" == false ]]; then
                subnets+=("$base")
                dim "Additional local subnet: ${base}.0/24"
            fi
        done < <(ip -4 addr show | grep 'inet ')
    fi

    # Method 2: Probe common upstream router IPs (for multi-subnet / AP setups)
    info "Probing for upstream routers (multi-subnet detection)..."
    METHODS_TRIED+=("Upstream router probing (common gateway IPs)")

    local common_gateways=("192.168.0.1" "192.168.1.1" "192.168.2.1" "10.0.0.1" "10.0.1.1" "172.16.0.1")
    local gw_ip
    for gw_ip in "${common_gateways[@]}"; do
        local base
        base=$(subnet_base "$gw_ip")
        # Skip if already in our list
        local already=false
        local s
        for s in ${subnets[@]+"${subnets[@]}"}; do
            [[ "$s" == "$base" ]] && already=true
        done
        [[ "$already" == true ]] && continue

        if host_alive "$gw_ip"; then
            subnets+=("$base")
            ok "Upstream router found: ${gw_ip} (subnet ${base}.0/24)"
        fi
    done

    if [[ ${#subnets[@]} -eq 0 ]]; then
        fail "Could not detect any network subnets."
        return 1
    fi

    echo ""
    SUBNETS_SCANNED=("${subnets[@]}")
}

# ── Phase 2: Scan subnets for Cast devices ──────────────
scan_for_cast_devices() {
    info "Scanning ${#SUBNETS_SCANNED[@]} subnet(s) for Google Cast devices..."
    info "Looking for open ports: 8008 (DIAL) + 8009 (CastV2)"
    METHODS_TRIED+=("TCP port scan for 8008/8009 on all discovered subnets")
    echo ""

    local subnet
    for subnet in "${SUBNETS_SCANNED[@]}"; do
        dim "Scanning ${subnet}.1-254 ..."

        # Check Cast ports on all hosts (parallel, batched)
        local pids=()
        local tmpdir
        tmpdir=$(mktemp -d)

        for ip_suffix in $(seq 1 254); do
            local ip="${subnet}.${ip_suffix}"
            (
                # Quick check: is DIAL port open?
                if port_open "$ip" 8008 2; then
                    # Verify CastV2 port too
                    if port_open "$ip" 8009 2; then
                        echo "$ip" > "$tmpdir/$ip_suffix"
                    fi
                fi
            ) &
            pids+=($!)

            # Batch control: max 50 parallel probes
            if [[ ${#pids[@]} -ge 50 ]]; then
                wait "${pids[@]}" 2>/dev/null
                pids=()
            fi
        done
        wait "${pids[@]}" 2>/dev/null

        # Collect results
        local found_file
        for found_file in "$tmpdir"/*; do
            [[ -f "$found_file" ]] || continue
            local ip
            ip=$(cat "$found_file")
            # Identify via DIAL
            local device_info
            device_info=$(dial_identify "$ip") || device_info="Unknown Device|Unknown|Unknown"
            FOUND_DEVICES+=("${ip}|${device_info}")

            local name="${device_info%%|*}"
            ok "Found: ${BOLD}${name}${RESET} at ${GREEN}${ip}${RESET} (ports 8008 + 8009 open)"
        done

        rm -rf "$tmpdir"
    done

    echo ""
}

# ── Phase 3: Try mDNS discovery (bonus, link-local only) ─
try_mdns() {
    if ! command -v avahi-browse &>/dev/null; then
        dim "avahi-browse not installed, skipping mDNS discovery"
        METHODS_TRIED+=("mDNS/Zeroconf (skipped — avahi-browse not installed)")
        return
    fi

    info "Trying mDNS discovery (works on same subnet only)..."
    METHODS_TRIED+=("mDNS/Zeroconf via avahi-browse (_googlecast._tcp)")

    local mdns_output
    mdns_output=$(timeout 5 avahi-browse -rpt _googlecast._tcp.local 2>/dev/null) || true

    if [[ -z "$mdns_output" ]]; then
        dim "No Cast devices found via mDNS (expected if TV is on a different subnet)"
        return
    fi

    # Parse avahi-browse output for IPs
    while IFS=';' read -r _ _ _ _ _ _ ip _ _; do
        [[ -z "$ip" ]] && continue
        [[ "$ip" == *:* ]] && continue  # skip IPv6

        # Check if we already found this IP
        local already=false
        local d
        for d in ${FOUND_DEVICES[@]+"${FOUND_DEVICES[@]}"}; do
            [[ "$d" == "${ip}|"* ]] && already=true
        done
        [[ "$already" == true ]] && continue

        local device_info
        device_info=$(dial_identify "$ip") || device_info="Unknown Cast Device|Unknown|Unknown"
        FOUND_DEVICES+=("${ip}|${device_info}")
        local name="${device_info%%|*}"
        ok "Found via mDNS: ${BOLD}${name}${RESET} at ${GREEN}${ip}${RESET}"
    done <<< "$mdns_output"

    echo ""
}

# ── Phase 4: Try SSDP discovery (bonus, link-local only) ─
try_ssdp() {
    info "Trying SSDP/UPnP discovery (works on same subnet only)..."
    METHODS_TRIED+=("SSDP/UPnP multicast M-SEARCH")

    local ssdp_response
    ssdp_response=$(timeout 3 bash -c '
        echo -e "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 2\r\nST: urn:dial-multiscreen-org:service:dial:1\r\n\r\n" | \
        socat - UDP4-DATAGRAM:239.255.255.250:1900,reuseaddr 2>/dev/null
    ' 2>/dev/null) || true

    if [[ -z "$ssdp_response" ]]; then
        dim "No DIAL devices found via SSDP (expected if TV is on a different subnet)"
    else
        # Extract LOCATION URLs and check for new IPs
        while IFS= read -r url; do
            local ip
            ip=$(echo "$url" | grep -oP '(?<=http://)[^:]+')
            [[ -z "$ip" ]] && continue

            local already=false
            local d
            for d in "${FOUND_DEVICES[@]}"; do
                [[ "$d" == "${ip}|"* ]] && already=true
            done
            [[ "$already" == true ]] && continue

            local device_info
            device_info=$(dial_identify "$ip") || continue
            FOUND_DEVICES+=("${ip}|${device_info}")
            local name="${device_info%%|*}"
            ok "Found via SSDP: ${BOLD}${name}${RESET} at ${GREEN}${ip}${RESET}"
        done < <(echo "$ssdp_response" | grep -i 'LOCATION' | awk '{print $2}' | tr -d '\r')
    fi

    echo ""
}

# ── Phase 5: Let user pick (if multiple) and save ───────
save_result() {
    if [[ ${#FOUND_DEVICES[@]} -eq 0 ]]; then
        return 1
    fi

    local selected_ip selected_name

    if [[ ${#FOUND_DEVICES[@]} -eq 1 ]]; then
        # Single device — auto-select
        local entry="${FOUND_DEVICES[0]}"
        selected_ip="${entry%%|*}"
        local rest="${entry#*|}"
        selected_name="${rest%%|*}"
    else
        # Multiple devices — let user pick
        echo -e "  ${BOLD}Multiple Cast devices found:${RESET}"
        echo ""
        local idx=1
        local entry
        for entry in "${FOUND_DEVICES[@]}"; do
            local ip="${entry%%|*}"
            local rest="${entry#*|}"
            local name="${rest%%|*}"
            rest="${rest#*|}"
            local manufacturer="${rest%%|*}"
            local model="${rest#*|}"
            echo -e "    ${BOLD}${idx})${RESET}  ${name}  ${DIM}(${manufacturer} ${model})${RESET}  ${GREEN}${ip}${RESET}"
            idx=$((idx + 1))
        done
        echo ""
        read -rp "  Which device? [1]: " pick
        pick="${pick:-1}"

        if ! [[ "$pick" =~ ^[0-9]+$ ]] || [[ "$pick" -lt 1 ]] || [[ "$pick" -gt ${#FOUND_DEVICES[@]} ]]; then
            fail "Invalid choice."
            return 1
        fi

        local chosen="${FOUND_DEVICES[$((pick - 1))]}"
        selected_ip="${chosen%%|*}"
        local rest="${chosen#*|}"
        selected_name="${rest%%|*}"
    fi

    # Write config
    cat > "$CONF_FILE" << CONF
# boretube TV configuration
# Generated by detect.sh on $(date '+%Y-%m-%d %H:%M:%S')
# Re-run detect.sh to update if your TV's IP changes.
TV_IP=${selected_ip}
TV_NAME="${selected_name}"
DIAL_PORT=8008
CAST_PORT=8009
CONF

    echo ""
    echo -e "  ${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "  ${GREEN}${BOLD}TV found and saved!${RESET}"
    echo ""
    echo -e "  ${BOLD}Name:${RESET}    ${selected_name}"
    echo -e "  ${BOLD}IP:${RESET}      ${selected_ip}"
    echo -e "  ${BOLD}Config:${RESET}  ${CONF_FILE}"
    echo ""
    echo -e "  ${DIM}boretube.sh will automatically use this config.${RESET}"
    echo -e "  ${DIM}Run detect.sh again if the TV's IP changes.${RESET}"
    echo ""
    echo -e "  ${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    return 0
}

# ── Failure report ──────────────────────────────────────
show_failure() {
    echo ""
    echo -e "  ${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "  ${RED}${BOLD}No Cast-enabled TV found.${RESET}"
    echo ""
    echo -e "  ${BOLD}What we tried:${RESET}"
    local m
    for m in "${METHODS_TRIED[@]}"; do
        echo -e "    ${DIM}•${RESET} ${m}"
    done
    echo ""
    echo -e "  ${BOLD}Subnets scanned:${RESET}"
    if [[ ${#SUBNETS_SCANNED[@]} -gt 0 ]]; then
        local s
        for s in "${SUBNETS_SCANNED[@]}"; do
            echo -e "    ${DIM}•${RESET} ${s}.0/24 (hosts 1-254)"
        done
    else
        echo -e "    ${DIM}(none discovered)${RESET}"
    fi
    echo ""
    echo -e "  ${BOLD}Troubleshooting:${RESET}"
    echo -e "    ${DIM}1.${RESET} Is the TV powered on (not just standby)?"
    echo -e "    ${DIM}2.${RESET} Is the TV on the same network or a routable subnet?"
    echo -e "    ${DIM}3.${RESET} Try finding the TV's IP in your router admin panel"
    echo -e "       and add it manually to ${BOLD}tv.conf${RESET}:"
    echo ""
    echo -e "       ${CYAN}cat > tv.conf << EOF"
    echo -e "       TV_IP=<your-tv-ip>"
    echo -e "       TV_NAME=My TV"
    echo -e "       DIAL_PORT=8008"
    echo -e "       CAST_PORT=8009"
    echo -e "       EOF${RESET}"
    echo ""
    echo -e "    ${DIM}4.${RESET} If the TV is on a different VLAN/subnet, ensure"
    echo -e "       your router allows traffic between subnets."
    echo ""
    echo -e "  ${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

# ── Main ────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${CYAN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════╗"
    echo "  ║      BORETUBE - Smart TV Detector         ║"
    echo "  ║   Find Google Cast devices on your LAN    ║"
    echo "  ╚═══════════════════════════════════════════╝"
    echo -e "${RESET}"

    # Phase 1: Find subnets
    discover_subnets || { show_failure; exit 1; }

    # Phase 2: Port scan for Cast devices
    scan_for_cast_devices

    # Phase 3: Try mDNS (bonus — only works same subnet)
    try_mdns

    # Phase 4: Try SSDP (bonus — only works same subnet)
    try_ssdp

    # Phase 5: Save result or show failure
    if save_result; then
        exit 0
    else
        show_failure
        exit 1
    fi
}

main
