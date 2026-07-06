#!/usr/bin/env bash
set -euo pipefail

REMOTE="gdrive:Workstation_Backups"
FILTER_FILE="/home/skurtz/src/dotfiles/backup-filters.txt"

echo "Starting unified backup to $REMOTE..."

# Use sync with the filter file.
# --fast-list : pre-calculates the remote directory structure.
# --filter-from : uses the file above to include/exclude.
rclone sync /home/skurtz "$REMOTE" \
    --filter-from "$FILTER_FILE" \
    --transfers=8 \
    --checkers=16 \
    --fast-list \
    --verbose