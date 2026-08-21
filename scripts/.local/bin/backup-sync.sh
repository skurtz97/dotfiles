#!/usr/bin/env bash
#
# backup-sync.sh - Mirror ~/docs and ~/media to Google Drive via
# rclone sync. Remote mirrors local: files added/changed locally are
# uploaded; files deleted locally are deleted remotely.
#
# Remote:  gdrive:backups/<name>
# Notes:   --one-file-system keeps rclone from descending into other
#          filesystems (e.g. the Jellyfin pool at ~/media/jellyfin).
#          Symlinks are skipped, never followed (--skip-links).

set -euo pipefail

readonly SRC_PARENT="${HOME}"
readonly SOURCES=(docs media)
readonly REMOTE="gdrive:"

DRY_RUN=0
VERBOSE=0

usage() {
  cat <<EOF
Usage: ${0##*/} [OPTIONS]

Mirror ${SRC_PARENT}/{$(
    IFS=,
    echo "${SOURCES[*]}"
  )} to ${REMOTE}/<name>
via rclone sync. Does not cross filesystem boundaries or follow
symlinks. WARNING: files deleted locally are deleted from the remote.

Options:
  -n, --dry-run    Show what would be transferred/deleted, change nothing
  -v, --verbose    Verbose output (rclone progress)
  -h, --help       Show this help and exit
EOF
}

log() { printf '%s\n' "$*"; }
die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
    -n | --dry-run) DRY_RUN=1 ;;
    -v | --verbose) VERBOSE=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown option: $1"
      ;;
    esac
    shift
  done
}

check_prereqs() {
  command -v rclone >/dev/null 2>&1 || die "rclone not found in PATH"

  local src
  for src in "${SOURCES[@]}"; do
    [[ -d "${SRC_PARENT}/${src}" ]] ||
      die "source directory not found: ${SRC_PARENT}/${src}"
  done

  local remote_name="${REMOTE%%:*}:"
  rclone listremotes | grep -qx "${remote_name}" ||
    die "rclone remote '${remote_name}' is not configured"
}

# sync_source NAME -> ${REMOTE}/NAME
sync_source() {
  local src="$1"

  local flags=(--one-file-system --skip-links)
  ((DRY_RUN)) && flags+=(--dry-run)
  ((VERBOSE)) && flags+=(--progress --verbose)

  log "syncing ${SRC_PARENT}/${src} -> ${REMOTE}/${src}"
  rclone sync "${flags[@]}" \
    "${SRC_PARENT}/${src}" "${REMOTE}${src}"
}

main() {
  parse_args "$@"
  check_prereqs

  local src
  for src in "${SOURCES[@]}"; do
    sync_source "${src}"
  done
}

main "$@"
