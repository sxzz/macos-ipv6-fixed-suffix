#!/bin/bash

# IPv6 Prefix Monitoring Script - macOS Version
# Function: Monitor IPv6 prefix changes and automatically add IPv6 addresses with fixed suffixes

# ========== Configuration Section ==========
# IPv6 suffix (default: last segment of IPv4 address)
IPV6_SUFFIX=""

# Prefix length (default: 64)
PREFIX_LENGTH=64

# Network interface to monitor (default: primary interface, leave empty for auto-detect)
INTERFACE=""

# Check interval (seconds)
CHECK_INTERVAL=10

# IPv6 address label
IPV6_LABEL="ipv6monitor"

# ========== Function Definitions ==========

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

get_primary_interface() {
    route get default 2>/dev/null | grep interface | awk '{print $2}' | head -1
}

get_default_ipv6_suffix() {
    local interface="$1"
    local ipv4_addr=$(ifconfig "$interface" 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -1)
    if [[ -n "$ipv4_addr" ]]; then
        local last_octet=$(echo "$ipv4_addr" | awk -F. '{print $4}')
        echo "::$last_octet"
    else
        echo "::100"
    fi
}

get_ipv6_prefixes() {
    local interface="$1"
    ifconfig "$interface" 2>/dev/null | grep 'inet6' | grep -v 'fe80:' | grep -v '::1' | grep -v 'deprecated' | awk '{print $2}' | cut -d'/' -f1 | while read addr; do
        if [[ "$addr" =~ ^[23][0-9a-f]{3}: ]]; then
            echo "$addr" | awk -F: '{printf "%s:%s:%s:%s\n", $1, $2, $3, $4}'
        fi
    done | sort -u
}

construct_ipv6_address() {
    local prefix="$1"
    local suffix="$2"
    echo "${prefix}${suffix}"
}

ipv6_address_exists() {
    local interface="$1"
    local address="$2"
    ifconfig "$interface" 2>/dev/null | grep -q "inet6 $address"
}

get_labeled_ipv6_addresses() {
    local interface="$1"
    # On macOS, we identify managed addresses by matching the specific suffix pattern
    ifconfig "$interface" 2>/dev/null | grep "inet6.*$IPV6_SUFFIX" | awk '{print $2}' | cut -d'/' -f1
}

remove_labeled_ipv6_addresses() {
    local interface="$1"
    local addresses=$(get_labeled_ipv6_addresses "$interface")
    if [[ -n "$addresses" ]]; then
        echo "$addresses" | while IFS= read -r address; do
            if [[ -n "$address" ]]; then
                log "Removing old IPv6 address: $address"
                sudo ifconfig "$interface" inet6 "$address" delete 2>/dev/null || true
            fi
        done
    fi
}

add_ipv6_address() {
    local interface="$1"
    local address="$2"
    if ipv6_address_exists "$interface" "$address"; then
        log "IPv6 address $address already exists on interface $interface"
        return 0
    fi
    log "Adding IPv6 address on interface $interface: $address/$PREFIX_LENGTH"
    if sudo ifconfig "$interface" inet6 "$address" prefixlen "$PREFIX_LENGTH" alias; then
        log "Successfully added IPv6 address: $address"
        return 0
    else
        log "Error: Failed to add IPv6 address: $address"
        return 1
    fi
}

handle_prefix_change() {
    local interface="$1"
    local new_prefixes="$2"
    local is_initial="$3"
    if [[ "$is_initial" == "true" ]]; then
        log "First run, detected current prefix: $new_prefixes"
    else
        log "Prefix change detected, current prefix: $new_prefixes"
        remove_labeled_ipv6_addresses "$interface"
    fi
    local prefixes_array=()
    while IFS= read -r prefix; do
        if [[ -n "$prefix" ]]; then
            prefixes_array+=("$prefix")
        fi
    done <<<"$new_prefixes"
    for prefix in "${prefixes_array[@]}"; do
        local new_address=$(construct_ipv6_address "$prefix" "$IPV6_SUFFIX")
        add_ipv6_address "$interface" "$new_address"
    done
}

monitor_ipv6_changes() {
    local interface="$1"
    local last_prefixes=""
    local is_first_run=true
    log "Start monitoring IPv6 prefix changes on interface $interface..."
    log "Config - Suffix: $IPV6_SUFFIX, Prefix length: $PREFIX_LENGTH, Check interval: ${CHECK_INTERVAL}s"
    while true; do
        local current_prefixes=$(get_ipv6_prefixes "$interface")
        if [[ "$current_prefixes" != "$last_prefixes" ]]; then
            if [[ -n "$current_prefixes" ]]; then
                handle_prefix_change "$interface" "$current_prefixes" "$is_first_run"
            else
                log "No valid IPv6 prefix currently"
                if [[ "$is_first_run" == "false" ]]; then
                    remove_labeled_ipv6_addresses "$interface"
                fi
            fi
            last_prefixes="$current_prefixes"
            is_first_run=false
        fi
        sleep "$CHECK_INTERVAL"
    done
}

show_help() {
    cat <<EOF
IPv6 Prefix Monitoring Script

Usage: $0 [options]

Options:
    -i, --interface INTERFACE    Specify the network interface to monitor
    -s, --suffix SUFFIX          Set IPv6 suffix (default: $IPV6_SUFFIX)
    -p, --prefix-length LENGTH   Set prefix length (default: $PREFIX_LENGTH)
    -t, --interval SECONDS       Set check interval (default: $CHECK_INTERVAL)
    -h, --help                   Show this help message

Examples:
    $0                           Use default settings
    $0 -i en0 -s ::200           Monitor interface en0, use ::200 as suffix
    $0 -p 56 -t 5                Use 56-bit prefix, 5 seconds check interval

Notes:
    - Script requires sudo privileges to modify network interface configuration
    - Press Ctrl+C to stop monitoring
EOF
}

# ========== Main Program ==========

while [[ $# -gt 0 ]]; do
    case $1 in
    -i | --interface)
        INTERFACE="$2"
        shift 2
        ;;
    -s | --suffix)
        IPV6_SUFFIX="$2"
        shift 2
        ;;
    -p | --prefix-length)
        PREFIX_LENGTH="$2"
        shift 2
        ;;
    -t | --interval)
        CHECK_INTERVAL="$2"
        shift 2
        ;;
    -h | --help)
        show_help
        exit 0
        ;;
    *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
done

if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root"
    echo "Please use: sudo $0"
    exit 1
fi

if [[ -z "$INTERFACE" ]]; then
    INTERFACE=$(get_primary_interface)
    if [[ -z "$INTERFACE" ]]; then
        echo "Error: Unable to auto-detect primary network interface"
        echo "Please specify interface manually with -i option"
        exit 1
    fi
fi

if ! ifconfig "$INTERFACE" >/dev/null 2>&1; then
    echo "Error: Network interface '$INTERFACE' does not exist"
    exit 1
fi

if [[ -z "$IPV6_SUFFIX" ]]; then
    IPV6_SUFFIX=$(get_default_ipv6_suffix "$INTERFACE")
fi

cleanup_on_exit() {
    log "Received stop signal, cleaning up IPv6 addresses and exiting..."
    remove_labeled_ipv6_addresses "$INTERFACE"
    exit 0
}
trap 'cleanup_on_exit' INT TERM

log "========== IPv6 Prefix Monitoring Script Started =========="
log "Monitoring interface: $INTERFACE"
log "IPv6 suffix: $IPV6_SUFFIX"
log "Prefix length: $PREFIX_LENGTH"
log "Check interval: ${CHECK_INTERVAL} seconds"

monitor_ipv6_changes "$INTERFACE"
