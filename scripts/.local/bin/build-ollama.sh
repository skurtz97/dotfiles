#!/usr/bin/env bash
# build-ollama: Fresh-clone, native build script for Ollama (ROCm)
# Managed by GNU Stow

set -euo pipefail

# --- Configuration ---
REPO_URL="https://github.com/ollama/ollama"
OLLAMA_ROOT="$HOME/src/ollama"
THREADS=$(nproc)

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Error Handling ---
error_exit() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    exit 1
}

cleanup_on_exit() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}[!] Build process failed. Check output for errors.${NC}"
    fi
}
trap cleanup_on_exit EXIT SIGINT SIGTERM

echo -e "${BLUE}=== Starting Full Rebuild: Ollama ROCm v7.2 ===${NC}"

# 1. Total Wipe and Reclone
if [ -d "$OLLAMA_ROOT" ]; then
    echo -e "${GREEN}[*] Wiping existing directory at $OLLAMA_ROOT...${NC}"
    rm -rf "$OLLAMA_ROOT"
fi

echo -e "${GREEN}[*] Cloning fresh repository...${NC}"
git clone "$REPO_URL" "$OLLAMA_ROOT"
cd "$OLLAMA_ROOT" || error_exit "Could not enter $OLLAMA_ROOT"

# 2. Configure Build
# Using your verified flags for ROCm v7.2 and gfx1201
echo -e "${GREEN}[*] Configuring CMake (ROCm v7.2)...${NC}"
cmake -B build . \
    -DOLLAMA_LLAMA_BACKENDS="rocm_v7_2" \
    -DCMAKE_HIP_ARCHITECTURES=gfx1201 \
    -DAMDGPU_TARGETS=gfx1201 \
    -DCMAKE_BUILD_TYPE=Release \
    || error_exit "CMake configuration failed."

# 3. Build Backend
echo -e "${GREEN}[*] Compiling backend with $THREADS threads...${NC}"
cmake --build build --parallel "$THREADS" \
    || error_exit "C++ compilation failed."

# 4. Build Go Wrapper
echo -e "${GREEN}[*] Compiling Go binary...${NC}"
go build -tags rocm . || error_exit "Go build failed."

echo -e "${BLUE}=== Build Successful! Binary is at $OLLAMA_ROOT/ollama ===${NC}"