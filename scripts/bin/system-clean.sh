#!/usr/bin/env bash
# shellcheck shell=bash
# system-clean.sh: Maintenance script for my Fedora Workstation/Server hybrid.
# Managed via GNU Stow in ~/src/dotfiles/scripts/bin/

set -euo pipefail

# Text colors for clean visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Starting System Maintenance & Cleanup ===${NC}\n"

# 1. Elevate privileges up front for system tasks
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}[!] Elevating to root for system tasks...${NC}"
    sudo -v
fi

# 2. Clean DNF Cache and Unused Dependencies
echo -e "${GREEN}[*] Cleaning DNF package cache...${NC}"
sudo dnf clean all
echo -e "${GREEN}[*] Removing orphaned packages (autoremove)...${NC}"
sudo dnf autoremove -y

# 3. Prune Old Kernels
# Retains the active kernel and the immediate previous backup, freeing up /boot
echo -e "${GREEN}[*] Checking for old kernels to remove...${NC}"
mapfile -t old_kernels < <(dnf repoquery --installonly --latest-limit=-2 -q)

if [ ${#old_kernels[@]} -gt 0 ]; then
    echo -e "${YELLOW}[!] Removing older kernels: ${old_kernels[*]}${NC}"
    sudo dnf remove "${old_kernels[@]}" -y
else
    echo -e "${GREEN}[*] No old kernels to remove.${NC}"
fi

# 4. Vacuum Systemd Journal Logs
# With ComfyUI, Jellyfin, and Llama.cpp churning, logs can balloon quickly.
# This keeps only the last 7 days of logs.
echo -e "${GREEN}[*] Vacuuming systemd logs to the last 7 days...${NC}"
sudo journalctl --vacuum-time=7d

# 5. Clean Unused Flatpak Runtimes
if command -v flatpak &> /dev/null; then
    echo -e "${GREEN}[*] Pruning unused Flatpak runtimes...${NC}"
    flatpak uninstall --unused -y
fi

# 6. User-level Cache Pruning (Safe cleanup of files unaccessed in 30 days)
echo -e "${GREEN}[*] Trimming user ~/.cache (older than 30 days)...${NC}"
find "$HOME/.cache" -type f -atime +30 -delete 2>/dev/null || true

# 7. Purge Broken Symlinks
# Crucial for dotfile management. If you remove or rename files in your repo, 
# Stow can leave behind dead links. This cleans up dead links up to 3 levels 
# deep.
echo -e "${GREEN}[*] Sweeping home directory for dead Stow symlinks...${NC}"
find "$HOME" -maxdepth 3 -xtype l -delete 2>/dev/null || true

# 8. BTRFS / SSD Optimization
# Triggers a TRIM command across NVMe and SATA SSD arrays to keep IO speeds
# optimal.
echo -e "${GREEN}[*] Issuing fstrim across BTRFS storage pools...${NC}"
sudo fstrim -av
