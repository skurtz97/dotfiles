#!/usr/bin/env bash
# shellcheck shell=bash
#
# build-llama.sh - clone/update llama.cpp, build with HIP/ROCm for gfx1201
# (RX 9070 XT) and install llama-server, llama-cli, llama-bench into
# ~/.local/bin as static binaries.
#
# Compilers: system Clang for host (CC/CXX) and device (HIPCXX) code by
# default; set HIPCXX=/usr/lib64/rocm/llvm/bin/clang to use ROCm's Clang for
# the HIP kernels instead. ROCm headers/libs are located in this order:
# $ROCM_PATH, /opt/rocm, then Fedora's packaged ROCm under /usr.

set -euo pipefail

readonly REPO_URL="https://github.com/ggml-org/llama.cpp"
readonly SRC_DIR="${HOME}/src/llama.cpp"
readonly BUILD_DIR="${SRC_DIR}/build"
readonly PREFIX="${HOME}/.local"
readonly GFX="gfx1201"
readonly TARGETS=(llama-server llama-cli llama-bench llama-quantize
    llama-gguf-split)

# Set by find_rocm
HIP_ROOT=""
HIP_CLANG=""
DEVICE_LIBS=""
ROCWMMA_INC=""
HOST_CC=""
HOST_CXX=""

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

find_rocm() {
    local root
    for root in "${ROCM_PATH:-}" /opt/rocm; do
        [[ -n "${root}" && -d "${root}/include/hip" ]] || continue
        HIP_ROOT="${root}"
        break
    done
    if [[ -z "${HIP_ROOT}" && -d /usr/include/hip ]]; then
        HIP_ROOT=/usr
    fi
    [[ -n "${HIP_ROOT}" ]] || die "ROCm/HIP headers not found (set ROCM_PATH)"
    ROCWMMA_INC="${HIP_ROOT}/include/rocwmma"

    # ocml.bc etc.; location differs between AMD's and Fedora's layouts
    local bc
    bc="$(find "${HIP_ROOT}/amdgcn" "${HIP_ROOT}/lib64/rocm" \
        "${HIP_ROOT}/lib/llvm" -name ocml.bc -print -quit 2>/dev/null || true)"
    [[ -n "${bc}" ]] \
        || die "ROCm device libraries (ocml.bc) not found under ${HIP_ROOT}"
    DEVICE_LIBS="${bc%/*}"

    HOST_CC="${CC:-clang}"
    HOST_CXX="${CXX:-clang++}"
    HIP_CLANG="${HIPCXX:-${HOST_CC}}"
    local c
    for c in "${HOST_CC}" "${HOST_CXX}" "${HIP_CLANG}"; do
        command -v "${c}" >/dev/null 2>&1 || die "compiler not found: ${c}"
    done

    vlog "HIP root:    ${HIP_ROOT}"
    vlog "device libs: ${DEVICE_LIBS}"
    vlog "host CC:     $("${HOST_CC}" --version | head -n 1)"
    vlog "host CXX:    $("${HOST_CXX}" --version | head -n 1)"
    vlog "HIP clang:   $("${HIP_CLANG}" --version | head -n 1)"
}

check_prereqs() {
    local cmd
    for cmd in git cmake ninja; do
        command -v "${cmd}" >/dev/null 2>&1 || die "missing: ${cmd}"
    done
    find_rocm
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
        auto) [[ -d "${ROCWMMA_INC}" ]] && fattn=ON ;;
    esac
    vlog "rocWMMA flash attention: ${fattn}"

    if (( CLEAN )); then
        vlog "removing ${BUILD_DIR}"
        rm -rf -- "${BUILD_DIR}"
    fi

    local hip_flags="--rocm-path=${HIP_ROOT}"
    hip_flags+=" --rocm-device-lib-path=${DEVICE_LIBS}"

    HIPCXX="${HIP_CLANG}" HIP_PATH="${HIP_ROOT}" \
    run cmake -S "${SRC_DIR}" -B "${BUILD_DIR}" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER="${HOST_CC}" \
        -DCMAKE_CXX_COMPILER="${HOST_CXX}" \
        -DCMAKE_HIP_FLAGS="${hip_flags}" \
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
