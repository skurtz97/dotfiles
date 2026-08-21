#!/usr/bin/env bash
#
# backup-docs.sh - Mirror ~/docs and ~/media to Google Drive via
# rclone sync. Remote mirrors local: files added/changed locally are
# uploaded; files deleted locally are deleted remotely.
#
# Remote:  gdrive:backups/<name>
# Notes:   --one-file-system keeps rclone from descending into other
#          filesystems (e.g. the Jellyfin pool at ~/media/jellyfin).
#          Symlinks are skipped, never followed (--skip-links).

