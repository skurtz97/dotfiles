#!/usr/bin/env bash
# shellcheck shell=bash
# build-llama.sh - rebuild llama.cpp from the latest upstream, tuned for:
#   GPU     : AMD Radeon RX 9070 XT (gfx1201 / RDNA4)
#   Stack   : ROCm 7.2, Fedora 44
#   Runtime : llama-server with --flash-attn on and q8_0/q8_0 KV cache. I'm aware that q8_0/q4_0 would be
#             better on different hardware, but for my specific hardware, --flash-attn only fires with
#             symmetric quantization.
#  
#   Flags   :
#    --restart              restart the llama-server user service when the build succeeds
#    --branch=<name>        build a branch other than master
#    --no-fa-all-quants     skip the all-KV quant FA kernels (faster compile; see note below)
#    -h | --help            show this help
#
set -euo pipefail


# ----------------------------------------------------------------------------
# Config (override via env or the flags above)
# ----------------------------------------------------------------------------
LLAMA_DIR="${LLAMA_DIR:-$HOME/src/llama.cpp}"       # matches systemd WorkingDirectory
GPU_TARGET="gfx1201"                                # RX 9070 XT / RDNA4
BUILD_DIR="build"                                   # matches ExecStart
BRANCH="master"
JOBS="$(nproc)"
SERVICE_NAME="llama-server"
RESTART_SERVICE=0
FA_ALL_QUANTS="ON"

# ----------------------------------------------------------------------------
# Arg parsing
# ----------------------------------------------------------------------------
for arg in "$@"; do
    case "$arg" in
        --restart)              RESTART_SERVICE=1 ;;
        --no-fa-all-quants)     FA_ALL_QUANTS="OFF" ;;
        --branch=*)             BRANCH="${arg=#*=}" ;;
        -h|--help)
            sed -n '2,16p' "$0"; exit 0 ;;
        *)
            echo "Unknown argument: $arg (try --help)" >&2; exit 2 ;;
    esac
done

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

# ----------------------------------------------------------------------------
# Prerequisite checks (fail loud and early instead of mid-compile)
# ----------------------------------------------------------------------------
log "Checking prerequisites"
for tool in git cmake hipconfig; do
    command -v "$tool" >/dev/null 2>&1 || die "'$tool' not found in PATH."
done
[ -d "$LLAMA_DIR/.git" ] || die "$LLAMA_DIR is not a git checkout of llama.cpp"
# Resolve ROCm paths the distro-agnostic way (Fedora packages ROCm under /usr,
# not /opt/rocm, so let hipconfig tell us where things actually live).
HIPCXX="$(hipconfig -l)/clang"
HIP_PATH="$(hipconfig -R)"
export HIPCXX HIP_PATH
[ -x "$HIPCXX" ] || die "HIP clang not found at '$HIPCXX'. Is rocm-hip-devel installed?"
log "Using HIPCXX=$HIPCXX"
log "Using HIP_PATH=$HIP_PATH"

# rocWMMA headers are required for GGML_HIP_ROCWMMA_FATTN. They ship with the
# ROCm meta package, but warn clearly if they're missing rather than dying
# 30 seconds into cmake with a cryptic include error.
if ! { [ -f "$HIP_PATH/include/rocwmma/rocwmma.hpp" ] || [ -f /usr/include/rocwmma/rocwmma.hpp ]; }; then
  warn "rocWMMA headers not found. Flash-attention acceleration needs them."
  warn "Install with:  sudo dnf install rocwmma-devel"
fi

# ----------------------------------------------------------------------------
# Update source to the latest upstream
# ----------------------------------------------------------------------------
cd "$LLAMA_DIR"
 
if [ -n "$(git status --porcelain)" ]; then
  die "Working tree at $LLAMA_DIR has local changes. Commit/stash them first
       (refusing to touch your tree so nothing gets lost)."
fi
 
log "Fetching latest from origin"
git fetch --prune origin
 
log "Checking out '$BRANCH' and fast-forwarding"
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH" \
  || die "Fast-forward pull failed (branch diverged?). Resolve manually, then re-run."
 
DESCRIBE="$(git describe --tags --always 2>/dev/null || git rev-parse --short HEAD)"
log "Now building llama.cpp @ $DESCRIBE"

# ----------------------------------------------------------------------------
# Configure
# ----------------------------------------------------------------------------
# A clean build dir avoids stale CMake cache after flag/target changes.
log "Wiping previous build dir: $LLAMA_DIR/$BUILD_DIR"
rm -rf "$LLAMA_DIR/${BUILD_DIR:?}"
 
# Flag rationale:
#   GGML_HIP=ON                 -> ROCm/HIP backend
#   GPU_TARGETS=gfx1201         -> native RDNA4 codegen, no HSA_OVERRIDE hacks
#   GGML_HIP_ROCWMMA_FATTN=ON   -> WMMA-accelerated flash attention (RDNA3+/RDNA4).
#                                  This is the payoff for your --flash-attn on.
#   GGML_CUDA_FA_ALL_QUANTS=ON  -> compiles every KV-cache quant combo for the FA
#                                  kernels, guaranteeing your q8_0/q8_0 cache hits
#                                  the fast fused path. Adds notable compile time;
#                                  pass --no-fa-all-quants to skip it.
#   CMAKE_BUILD_TYPE=Release    -> -O3 + native CPU opts (GGML_NATIVE is on by default)
#   LLAMA_CURL=ON               -> keeps `-hf` model downloads working (needs
#                                  libcurl-devel). Harmless for your local models-dir.
log "Configuring (FA_ALL_QUANTS=$FA_ALL_QUANTS)"
cmake -S . -B "$BUILD_DIR" \
  -DGGML_HIP=ON \
  -DGPU_TARGETS="$GPU_TARGET" \
  -DGGML_HIP_ROCWMMA_FATTN=ON \
  -DGGML_CUDA_FA_ALL_QUANTS="$FA_ALL_QUANTS" \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_CURL=ON

# ----------------------------------------------------------------------------
# Build
# ----------------------------------------------------------------------------
log "Compiling with -j$JOBS (this is the long part)"
cmake --build "$BUILD_DIR" --config Release -j "$JOBS"

# ----------------------------------------------------------------------------
# Verify
# ----------------------------------------------------------------------------
SERVER_BIN="$LLAMA_DIR/$BUILD_DIR/bin/llama-server"
[ -x "$SERVER_BIN" ] || die "Build finished but $SERVER_BIN is missing."
 
log "Build OK. Binary matches your service ExecStart: $SERVER_BIN"
"$SERVER_BIN" --version || true
echo
log "Detected devices:"
"$LLAMA_DIR/$BUILD_DIR/bin/llama-cli" --list-devices || true

# ----------------------------------------------------------------------------
# Optional: restart the user service
# ----------------------------------------------------------------------------
if [ "$RESTART_SERVICE" -eq 1 ]; then
  log "Restarting user service: $SERVICE_NAME"
  systemctl --user restart "$SERVICE_NAME"
  systemctl --user --no-pager status "$SERVICE_NAME" || true
else
  echo
  log "Done. To load the new binary:  systemctl --user restart $SERVICE_NAME"
  log "     (or re-run this script with --restart)"
fi
