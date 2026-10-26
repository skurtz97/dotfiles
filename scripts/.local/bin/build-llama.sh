#!/usr/bin/env bash
# shellcheck shell=bash
#
# build-llama.sh - clone/update llama.cpp, build with HIP/ROCm for gfx1201
# (RX 9070 XT), and install llama-server, llama-cli, llama-bench into
# ~/.local/bin as static binaries.

set -euo pipefail

readonly REPO_URL="https://github.com/ggml-org/llama.cpp"
readonly SRC_DIR="${HOME}/src/llama.cpp"
readonly BUILD_DIR="${SRC_DIR}/build"
readonly PREFIX="${HOME}/.local"
readonly ROCM="${ROCM_PATH:-/opt/rocm}"
readonly GFX="gfx1201"
readonly TARGETS=(llama-server llama-cli llama-bench)

VERBOSE=0
CLEAN=0
FATTN=auto

usage() {
    cat <<USAGE
Usage: ${0##*/} [OPTIONS]

Build llama.cpp (HIP/ROCm, ${GFX}) from ${SRC_DIR} and install
${TARGETS[*]} into ${PREFIX}/bin.

Options:
  -c, --clean        Remove the build directory first
  -f, --fattn=MODE   rocWMMA flash-attention kernels: on, off, auto (default)
  -v, --verbose      Show git, cmake, and compiler output
  -h, --help         Show this help and exit
USAGE
}

die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
vlog() { if (( VERBOSE )); then printf '%s\n' "$*"; fi; }

# Run a command, hiding stdout unless -v; stderr always passes through.
run() {
    if (( VERBOSE )); then
        "$@"
    else
        "$@" >/dev/null
    fi
}

parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            -c|--clean)   CLEAN=1 ;;
            -f)           shift; FATTN="${1:-}" ;;
            --fattn=*)    FATTN="${1#*=}" ;;
            -v|--verbose) VERBOSE=1 ;;
            -h|--help)    usage; exit 0 ;;
            *)            usage >&2; die "unknown option: $1" ;;
        esac
        shift
    done
    case "${FATTN}" in
        on|off|auto) ;;
        *) die "invalid --fattn value: ${FATTN}" ;;
    esac
}

check_prereqs() {
    local cmd
    for cmd in git cmake ninja; do
        command -v "${cmd}" >/dev/null 2>&1 || die "missing: ${cmd}"
    done
    [[ -x "${ROCM}/llvm/bin/clang" ]] || die "ROCm clang not found at ${ROCM}/llvm/bin/clang"
}

fetch_source() {
    if [[ -d "${SRC_DIR}/.git" ]]; then
        vlog "updating ${SRC_DIR}"
        run git -C "${SRC_DIR}" pull --ff-only
    else
        vlog "cloning ${REPO_URL} -> ${SRC_DIR}"
        run git clone --depth 1 "${REPO_URL}" "${SRC_DIR}"
    fi
}

configure() {
    local fattn=OFF
    case "${FATTN}" in
        on)   fattn=ON ;;
        auto) [[ -d "${ROCM}/include/rocwmma" ]] && fattn=ON ;;
    esac
    vlog "rocWMMA flash attention: ${fattn}"

    if (( CLEAN )); then
        vlog "removing ${BUILD_DIR}"
        rm -rf -- "${BUILD_DIR}"
    fi

    HIPCXX="${ROCM}/llvm/bin/clang" HIP_PATH="${ROCM}" \
    run cmake -S "${SRC_DIR}" -B "${BUILD_DIR}" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DGGML_HIP=ON \
        -DGPU_TARGETS="${GFX}" \
        -DGGML_HIP_ROCWMMA_FATTN="${fattn}" \
        -DGGML_NATIVE=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DLLAMA_BUILD_TESTS=OFF \
        || die "cmake configure failed"
}

build() {
    vlog "building ${TARGETS[*]} with $(nproc) jobs"
    run cmake --build "${BUILD_DIR}" --parallel "$(nproc)" \
        --target "${TARGETS[@]}" \
        || die "build failed"
}

install_bins() {
    local t
    for t in "${TARGETS[@]}"; do
        install -Dm755 "${BUILD_DIR}/bin/${t}" "${PREFIX}/bin/${t}"
        vlog "installed ${PREFIX}/bin/${t}"
    done
    vlog "$("${PREFIX}/bin/llama-server" --version 2>&1 | head -n 1)"
}

main() {
    parse_args "$@"
    check_prereqs
    fetch_source
    configure
    build
    install_bins
}

main "$@"
