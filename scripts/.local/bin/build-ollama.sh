#!/usr/bin/env bash
#shellcheck shell=bash
# build-ollama: Native build script for Ollama (ROCm/Native)

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

OLLAMA_ROOT="$HOME/src/ollama"
BUILD_DIR="$OLLAMA_ROOT/build"
HIP_CMAKE_DIR="/usr/lib64/cmake/hip-lang"

error_exit() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    exit 1
}

cleanup() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}[!] Build failed. Cleaning up...${NC}"
        rm -rf "$BUILD_DIR"
    fi
}
trap cleanup EXIT SIGINT SIGTERM

echo -e "${BLUE}=== Starting Native Ollama ROCm Build ===${NC}"

# Pre-flight check
[ -d "$HIP_CMAKE_DIR" ] || error_exit "HIP headers not found."

# Use CMAKE_ARGS to force variables into FetchContent
export CMAKE_ARGS="-DGGML_HIP=ON -DAMDGPU_TARGETS=gfx1201 \
    -DCMAKE_HIP_ARCHITECTURES=gfx1201 \
    -DCMAKE_PREFIX_PATH=$HIP_CMAKE_DIR -DGGML_NATIVE=ON"

cd "$OLLAMA_ROOT"
echo -e "${GREEN}[*] Cleaning build directory...${NC}"
rm -rf "$BUILD_DIR"

echo -e "${GREEN}[*] Configuring CMake...${NC}"
cmake -B "$BUILD_DIR" . -DCMAKE_BUILD_TYPE=Release

echo -e "${GREEN}[*] Inspecting Cache for HIP settings...${NC}"
grep "GGML_HIP" "$BUILD_DIR/CMakeCache.txt" || echo "Warning: GGML_HIP not found in cache"

echo -e "${GREEN}[*] Compiling with $(nproc) cores...${NC}"
cmake --build "$BUILD_DIR" --parallel "$(nproc)"

echo -e "${BLUE}=== Verification ===${NC}"
if ldd "$OLLAMA_ROOT/ollama" 2>/dev/null | grep -q "hip"; then
    echo -e "${GREEN}[SUCCESS] Binary is GPU-aware.${NC}"
else
    echo -e "${RED}[!] Failure: Binary not linked to HIP.${NC}"
fi