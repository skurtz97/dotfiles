#!/usr/bin/env bash
# shellcheck shell=bash
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
