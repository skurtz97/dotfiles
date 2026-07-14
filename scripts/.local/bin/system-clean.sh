#!/usr/bin/env bash
# shellcheck shell=bash
# system-clean.sh: Maintenance script for Sean's Fedora workstation.
# Managed via GNU Stow in ~/src/dotfiles/scripts/.local/bin/

set -euo pipefail

# Text colors for clean visibility
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 1. Automatically self-elevate via 'sudo -E' if not root
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}[!] Root required. Relaunching with sudo -E...${NC}"
    # "$0" points to this script, "$@" passes along any arguments seamlessly
    exec sudo -E "$0" "$@"
fi

echo -e "${BLUE}=== Starting System Maintenance & Cleanup ===${NC}\n"

# 2. Clean DNF Cache and Unused Dependencies
echo -e "${GREEN}[*] Cleaning DNF package cache...${NC}"
dnf clean all

echo -e "${GREEN}[*] Removing orphaned packages (autoremove)...${NC}"
dnf autoremove -y

# 3. Prune Old Kernels (ShellCheck-compliant Array Implementation)
echo -e "${GREEN}[*] Checking for old kernels to remove...${NC}"

mapfile -t old_kernels < <(
    dnf repoquery \
        --installonly \
        --latest-limit=-2 \
        -q
)

if [ ${#old_kernels[@]} -gt 0 ]; then
    echo -e "${YELLOW}[!] Removing older kernels: ${old_kernels[*]}${NC}"
    dnf remove "${old_kernels[@]}" -y
else
    echo -e "${GREEN}[*] No old kernels to remove.${NC}"
fi

# 4. Vacuum Systemd Journal Logs
echo -e "${GREEN}[*] Vacuuming systemd logs to the last 7 days...${NC}"
journalctl --vacuum-time=7d

# 5. Clean Unused Flatpak Runtimes
if command -v flatpak &> /dev/null; then
    echo -e "${GREEN}[*] Pruning unused Flatpak runtimes...${NC}"
    flatpak uninstall --unused -y
fi

# 6. User-level Cache Pruning (Files unaccessed in 30 days)
TARGET_HOME=$(eval echo "~${SUDO_USER}")
echo -e "${GREEN}[*] Trimming user cache older than 30 days...${NC}"
find "${TARGET_HOME}/.cache" \
    -type f \
    -atime +30 \
    -delete 2>/dev/null || true

# 7. Purge Broken Symlinks
echo -e "${GREEN}[*] Sweeping home directory for dead symlinks...${NC}"
find "${TARGET_HOME}" \
    -maxdepth 3 \
    -xtype l \
    -delete 2>/dev/null || true

# 8. BTRFS / SSD Optimization
echo -e "${GREEN}[*] Issuing fstrim across BTRFS storage pools...${NC}"
fstrim -av

echo -e "\n${BLUE}=== System Cleaned Successfully! ===${NC}"