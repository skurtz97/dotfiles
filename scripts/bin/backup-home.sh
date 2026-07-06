#!/usr/bin/env bash
# allowlist-gdrive-backup.sh
# A targeted backup script using rclone to push specific directories to Google Drive.

set -euo pipefail

# The name of your rclone remote (as configured in 'rclone config')
# and the destination folder name on Google Drive.
REMOTE="gdrive:Workstation_Backups"

# ==========================================
# THE ALLOWLIST
# Define the exact absolute paths you want to back up.
# ==========================================
ALLOWLIST=(
    "/home/skurtz/docs"
    "/home/skurtz/.ssh"
    # Added your comfyui workflows/outputs based on your other scripts!
    "/home/skurtz/ComfyUI/user/default/workflows" 
)

echo "Starting targeted backup to $REMOTE..."
echo "------------------------------------------------"

for DIR in "${ALLOWLIST[@]}"; do
    if [[ -d "$DIR" ]]; then
        # Extract the base folder name so it nests correctly in Drive
        BASENAME=$(basename "$DIR")
        echo "--> Backing up: $DIR"
        
        # Using 'rclone copy' to add/update files. 
        # (Note: If you want to delete files from Drive when they are deleted locally, 
        # change 'copy' to 'sync'. Use 'sync' with caution!)
        rclone copy "$DIR" "$REMOTE/$BASENAME" \
            --transfers=8 \
            --checkers=8 \
            --fast-list \
            --update \
            --verbose
            
        echo "    Done backing up $BASENAME."
    else
        echo "--> WARNING: Directory not found, skipping: $DIR"
    fi
done

echo "------------------------------------------------"
echo "Backup complete!"