#!/usr/bin/env bash
# shellcheck shell=bash
# Script that backs up important stuff from my home filesystem to 
# Google Drive where I have ~5TiB storage available.
set -euo pipefail

REMOTE="gdrive:Workstation_Backups"

echo "Starting unified backup to $REMOTE..."

# Filters apply to the local source paths (first match wins).
#   --fast-list : pre-calculates the remote directory structure.
#   --filter    : include/exclude rules, applied top to bottom.
rclone sync /home/skurtz "$REMOTE" \
    --filter="- **/.git/**" \
    --filter="- .~lock.*#" \
    --filter="+ docs/**" \
    --filter="+ .ssh/**" \
    --filter="+ ComfyUI/user/default/workflows/**" \
    --filter="- **" \
    --transfers=8 \
    --checkers=16 \
    --fast-list \
    --verbose
