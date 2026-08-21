#!/usr/bin/env bash
#
# build-ollama.sh - Build Ollama from source with ROCm/HIP support for
# gfx1201 (RDNA 4 / Radeon RX 9070 XT).
#
# Defaults to a pinned release tag and reuses the existing clone. Use
# --reclone only when a fresh tree is actually wanted; the old behaviour
# of always wiping ~/src/ollama destroys a known-good build.
#
# Managed by GNU Stow in ~/src/dotfiles/scripts/.local/bin/

set -euo pipefail

readonly REPO_URL="https://github.com/ollama/ollama"
readonly OLLAMA_ROOT="${HOME}/src/ollama"
readonly DEFAULT_REF="v0.32.15"
readonly ROCM_BACKEND="rocm_v7_2"
readonly GPU_ARCH="gfx1201"
readonly VERSION_PKG="github.com/ollama/ollama/version.Version"
readonly SERVICE="ollama.service"

REF="${DEFAULT_REF}"
CLEAN=0
RECLONE=0
DRY_RUN=0
VERBOSE=0
NO_RESTART=0

usage() {
    cat <<EOF
Usage: ${0##*/} [OPTIONS] [REF]

Build Ollama at ${OLLAMA_ROOT} with the ${ROCM_BACKEND} backend
targeting ${GPU_ARCH}, stamp the version, and restart ${SERVICE}.

REF is a git tag, branch, or commit (default: ${DEFAULT_REF}).

Options:
  -c, --clean       Remove build/ before configuring
  -C, --reclone     Delete and re-clone the repo (destructive)
  -n, --dry-run     Print commands without running them
  -N, --no-restart  Skip restarting ${SERVICE}
  -v, --verbose     Verbose output
  -h, --help        Show this help and exit

Examples:
  ${0##*/}                 # build ${DEFAULT_REF}
  ${0##*/} main            # build current main
  ${0##*/} -c v0.32.14     # clean build of an older tag
EOF
}

log() {
    printf '%s\n' "$*"
}

vlog() {
    if ((VERBOSE)); then
        printf '%s\n' "$*"
    fi
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

# Echo a command in dry-run mode, otherwise execute it.
run() {
    if ((DRY_RUN)); then
        printf '[dry-run] %s\n' "$*"
        return 0
    fi
    vlog "+ $*"
    "$@"
}

parse_args() {
    while (($# > 0)); do
        case "$1" in
            -c | --clean) CLEAN=1 ;;
            -C | --reclone) RECLONE=1 ;;
            -n | --dry-run) DRY_RUN=1 ;;
            -N | --no-restart) NO_RESTART=1 ;;
            -v | --verbose) VERBOSE=1 ;;
            -h | --help)
                usage
                exit 0
                ;;
            -*)
                usage >&2
                die "unknown option: $1"
                ;;
            *) REF="$1" ;;
        esac
        shift
    done
}

check_prereqs() {
    local tool
    for tool in git cmake go; do
        command -v "${tool}" > /dev/null 2>&1 \
            || die "${tool} not found in PATH"
    done

    [[ -d /opt/rocm ]] || die "/opt/rocm not found; is ROCm installed?"
}

# Clone if absent, or re-clone when explicitly asked.
prepare_tree() {
    if ((RECLONE)) && [[ -d "${OLLAMA_ROOT}" ]]; then
        log "removing ${OLLAMA_ROOT} (--reclone)"
        run rm -rf "${OLLAMA_ROOT}"
    fi

    if [[ ! -d "${OLLAMA_ROOT}" ]]; then
        log "cloning ${REPO_URL}"
        run git clone "${REPO_URL}" "${OLLAMA_ROOT}"
    fi
}

checkout_ref() {
    log "checking out ${REF}"
    run git -C "${OLLAMA_ROOT}" fetch --tags --prune origin
    run git -C "${OLLAMA_ROOT}" checkout --force "${REF}"

    # Fast-forward only when REF is a branch; tags are already detached.
    if git -C "${OLLAMA_ROOT}" symbolic-ref -q HEAD > /dev/null 2>&1; then
        run git -C "${OLLAMA_ROOT}" pull --ff-only
    fi
}

configure_build() {
    if ((CLEAN)) && [[ -d "${OLLAMA_ROOT}/build" ]]; then
        log "removing stale build directory"
        run rm -rf "${OLLAMA_ROOT}/build"
    fi

    log "configuring cmake (${ROCM_BACKEND}, ${GPU_ARCH})"
    run cmake -B "${OLLAMA_ROOT}/build" -S "${OLLAMA_ROOT}" \
        -DOLLAMA_LLAMA_BACKENDS="${ROCM_BACKEND}" \
        -DCMAKE_HIP_ARCHITECTURES="${GPU_ARCH}" \
        -DAMDGPU_TARGETS="${GPU_ARCH}" \
        -DCMAKE_BUILD_TYPE=Release
}

compile_backend() {
    local threads
    threads="$(nproc)"

    log "building HIP backend with ${threads} threads"
    run cmake --build "${OLLAMA_ROOT}/build" --parallel "${threads}"
}

# `go build` alone leaves version.Version empty, so `ollama --version`
# reports 0.0.0. Derive it from the checked-out ref instead.
compile_binary() {
    local version

    if ((DRY_RUN)); then
        version="${REF#v}"
    else
        version="$(git -C "${OLLAMA_ROOT}" describe --tags --always)"
        version="${version#v}"
    fi

    log "building go binary (version ${version})"
    run env -C "${OLLAMA_ROOT}" \
        go build -tags rocm \
        -ldflags "-X=${VERSION_PKG}=${version}" .
}

restart_service() {
    if ((NO_RESTART)); then
        vlog "skipping service restart (--no-restart)"
        return 0
    fi

    # A running process keeps the old inode after `go build` replaces
    # the file, so a restart is required to pick up the new binary.
    log "restarting ${SERVICE}"
    run systemctl --user restart "${SERVICE}"
}

# Confirm the GPU path survived; a silent CPU fallback is the failure
# mode that matters most here.
verify_gpu() {
    if ((DRY_RUN)) || ((NO_RESTART)); then
        return 0
    fi

    sleep 3

    if journalctl --user -u "${SERVICE}" -b --no-pager \
        | grep -q "inference compute.*library=ROCm"; then
        log "verified: ROCm inference compute active"
    else
        log "WARNING: no ROCm 'inference compute' line found."
        log "Check: journalctl --user -u ${SERVICE} -b | grep -i compute"
    fi
}

main() {
    parse_args "$@"
    check_prereqs
    prepare_tree
    checkout_ref
    configure_build
    compile_backend
    compile_binary
    restart_service
    verify_gpu
    log "done: ${OLLAMA_ROOT}/ollama"
}

main "$@"