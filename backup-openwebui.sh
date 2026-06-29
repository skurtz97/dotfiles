#!/bin/bash
BACKUP_DIR="/home/skurtz/.archives/openwebui"
mkdir -p "$BACKUP_DIR"
tar -czf "$BACKUP_DIR/openwebui_backup_$(date +%F).tar.gz" -C /home/skurtz .open-webui
find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +7 -delete
