#!/usr/bin/env bash
# shellcheck shell=bash
#
# build-x3270.sh - Build the x3270 suite (minus tcl3270) from source and
# install it under ~/.local, including the generated desktop icons that
# upstream's install target hardcodes to /usr/share/icons.
#
# Source: ~/src/x3270 (github.com/pmattes/x3270)

set -euo pipefail

readonly REPO_URL="https://github.com/pmattes/x3270"
readonly SRC_DIR="${HOME}/src/x3270"
readonly PREFIX="${HOME}/.local"
readonly FONT_DIR="${PREFIX}/share/fonts/X11/misc"
readonly FONT_LINK="/etc/X11/fontpath.d/x3270"
readonly ICON_DIR="${PREFIX}/share/icons/hicolor"
readonly LOG_FILE="${XDG_CACHE_HOME:-${HOME}/.cache}/build-x3270.log"
readonly BINARIES=(x3270 c3270 s3270 b3270 pr3287 x3270if)

DRY_RUN=0
VERBOSE=0
CLEAN=0
UPDATE=0
STAMP=""

usage() {
    cat <<EOF
Usage: ${0##*/} [OPTIONS]

Build x3270, c3270, s3270, b3270, pr3287 and x3270if from ${SRC_DIR}
and install them under ${PREFIX}. Clones the repository if missing.

Options:
  -c, --clean      Remove all untracked files (git clean -xdf) first
  -u, --update     Fast-forward the checkout before building
  -n, --dry-run    Show what would be done without doing it
  -v, --verbose    Show commands and build output (default: log file)
  -h, --help       Show this help and exit

Log: ${LOG_FILE}
EOF
}

log() {
    printf '%s\n' "$*"
}

vlog() {
    if (( VERBOSE )); then
        printf '%s\n' "$*"
    fi
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

cleanup() {
    local rc=$?
    rm -f "${STAMP}"
    if (( rc != 0 && ! VERBOSE && ! DRY_RUN )); then
        printf 'error: build failed; see %s\n' "${LOG_FILE}" >&2
    fi
}

run() {
    if (( DRY_RUN )); then
        printf '[dry-run] %s\n' "$*"
        return 0
    fi
    vlog "+ $*"
    if (( VERBOSE )); then
        "$@"
    else
        "$@" >>"${LOG_FILE}" 2>&1
    fi
}

parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            -c|--clean)   CLEAN=1 ;;
            -u|--update)  UPDATE=1 ;;
            -n|--dry-run) DRY_RUN=1 ;;
            -v|--verbose) VERBOSE=1 ;;
            -h|--help)    usage; exit 0 ;;
            *)            usage >&2; die "unknown option: $1" ;;
        esac
        shift
    done
}

check_prereqs() {
    local tool
    for tool in git make bdftopcf mkfontdir; do
        command -v "${tool}" >/dev/null 2>&1 || die "${tool} not found"
    done
}

fetch_source() {
    if [[ ! -d "${SRC_DIR}/.git" ]]; then
        run git clone "${REPO_URL}" "${SRC_DIR}"
    elif (( UPDATE )); then
        run git -C "${SRC_DIR}" pull --ff-only
    fi
    if (( CLEAN )); then
        run git -C "${SRC_DIR}" clean -xdf
    fi
}

build() {
    local make_cmd=(make -j"$(nproc)")
    if command -v bear >/dev/null 2>&1; then
        make_cmd=(bear -- "${make_cmd[@]}")
    fi
    if [[ -d "${SRC_DIR}" ]]; then
        cd "${SRC_DIR}"
    fi
    run ./configure --prefix="${PREFIX}" \
        --disable-tcl3270 --disable-tcl3270-pkg
    run "${make_cmd[@]}"
}

install_suite() {
    # x3270's install recipe fails writing /usr/share/icons; -k lets the
    # other components install, and freshness is verified below instead.
    run make -k install || true
    run make install.man
    if (( DRY_RUN )); then
        return 0
    fi
    local bin
    for bin in "${BINARIES[@]}"; do
        [[ "${PREFIX}/bin/${bin}" -nt "${STAMP}" ]] \
            || die "${bin} was not installed"
    done
}

install_icons() {
    if (( DRY_RUN )); then
        log "[dry-run] would install generated icons into ${ICON_DIR}"
        return 0
    fi
    local icons icon res
    shopt -s nullglob
    icons=("${SRC_DIR}"/obj/*/x3270/x3270-*x*.png)
    shopt -u nullglob
    (( ${#icons[@]} > 0 )) || die "no generated icons under ${SRC_DIR}/obj"
    for icon in "${icons[@]}"; do
        res=${icon##*/x3270-}
        res=${res%.png}
        run install -Dm644 "${icon}" "${ICON_DIR}/${res}/apps/x3270.png"
    done
    run touch "${ICON_DIR}"
}

check_fonts() {
    if [[ ! -e "${FONT_LINK}" ]]; then
        printf 'warning: %s missing; register fonts with:\n' \
            "${FONT_LINK}" >&2
        printf '  sudo ln -s %s %s\n' "${FONT_DIR}" "${FONT_LINK}" >&2
    fi
    if (( ! DRY_RUN )) && [[ -n "${DISPLAY:-}" ]] \
        && command -v xset >/dev/null 2>&1; then
        xset fp rehash || true
    fi
}

main() {
    parse_args "$@"
    trap cleanup EXIT
    check_prereqs
    if (( ! DRY_RUN )); then
        mkdir -p "${LOG_FILE%/*}"
        : >"${LOG_FILE}"
        STAMP=$(mktemp)
    fi
    fetch_source
    build
    install_suite
    install_icons
    check_fonts
    log "installed x3270 suite to ${PREFIX}"
}

main "$@"