#!/bin/sh
# shellcheck shell=sh
# block-dot.sh - Reject LAN->WAN DNS over TLS/QUIC (port 853) on the
# Flint 2 (GL.iNet 4.x / OpenWrt fw4). Idempotent: uses a named section.
# Runs on the router (BusyBox ash), not the workstation.

set -eu

DRY_RUN=0
VERBOSE=0
SECTION=firewall.block_dot

usage() {
    cat <<USAGE
Usage: ${0##*/} [OPTIONS]

Add/replace uci rule ${SECTION} rejecting tcp/udp 853 from lan to wan.

Options:
  -n, --dry-run    Print uci commands without running them
  -v, --verbose    Print commands as they run
  -h, --help       Show this help and exit
USAGE
}

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] %s\n' "$*"
        return 0
    fi
    if [ "$VERBOSE" -eq 1 ]; then
        printf '%s\n' "$*"
    fi
    "$@"
}

while [ $# -gt 0 ]; do
    case "$1" in
        -n|--dry-run) DRY_RUN=1 ;;
        -v|--verbose) VERBOSE=1 ;;
        -h|--help)    usage; exit 0 ;;
        *)            usage >&2; printf 'error: unknown option: %s\n' \
                          "$1" >&2; exit 1 ;;
    esac
    shift
done

command -v uci >/dev/null 2>&1 || {
    printf 'error: uci not found (run this on the router)\n' >&2
    exit 1
}

uci -q get "$SECTION" >/dev/null && run uci delete "$SECTION"
run uci set "${SECTION}=rule"
run uci set "${SECTION}.name=Block-DoT-DoQ"
run uci set "${SECTION}.src=lan"
run uci set "${SECTION}.dest=wan"
run uci set "${SECTION}.proto=tcp udp"
run uci set "${SECTION}.dest_port=853"
run uci set "${SECTION}.target=REJECT"
run uci commit firewall
run /etc/init.d/firewall reload
