#!/usr/bin/env bash
# shellcheck shell=bash
#
# backup-home.sh — Back up /home/skurtz to Google Drive via rclone,
#                  excluding game installs and regenerable caches.
#
# Usage:
#   ./backup-home.sh                 # real run; log to file only
#   ./backup-home.sh --dry-run       # show what WOULD change; transfer nothing
#   ./backup-home.sh --verbose       # also stream the full log to the terminal
#   ./backup-home.sh -n -v           # flags combine
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Config — edit these
# ---------------------------------------------------------------------------
REMOTE="gdrive"                                   # your configured rclone remote name
SRC="/home/skurtz"
DEST_PATH="backups/$(hostname -s)/home-skurtz"    # path inside the remote
LOG_DIR="${HOME}/.local/state/home-backup"
BWLIMIT=""                                        # e.g. "20M" to cap upload; empty = unlimited

# Keep a timestamped copy of anything deleted/overwritten on the remote rather
# than permanently removing it (recoverable history). Set to "" for a pure
# mirror, which deletes remote-side anything no longer present locally.
VERSIONING=1
# ---------------------------------------------------------------------------

DEST="${REMOTE}:${DEST_PATH}"
STAMP="$(date +%Y-%m-%d_%H%M%S)"
LOG_FILE="${LOG_DIR}/backup_${STAMP}.log"
LOCK_FILE="${LOG_DIR}/.lock"
mkdir -p "${LOG_DIR}"

# --- Args -------------------------------------------------------------------
usage() {
  local ver
  if [[ -n "${VERSIONING}" ]]; then
    ver="on — changed/deleted files moved to ${DEST_PATH}-archive/<timestamp>/"
  else
    ver="off — pure mirror (remote-side deletions are permanent)"
  fi
  cat <<EOF
${0##*/} — back up ${SRC} to Google Drive via rclone.

Mirrors your home directory to the configured remote, staying on the home
filesystem (other mounts are skipped) and excluding game installs and caches.

Usage: ${0##*/} [OPTIONS]

Options:
  -n, --dry-run    Show what would change; transfer nothing.
  -v, --verbose    Stream the full log to the terminal (also saved to the log file).
  -h, --help       Show this help and exit.

Examples:
  ${0##*/} --dry-run --verbose   Preview every change, live, before committing.
  ${0##*/}                       Normal run (log written to the log dir only).

Current config (edit the block near the top of the script):
  Source     : ${SRC}
  Destination: ${DEST}
  Versioning : ${ver}
  Log dir    : ${LOG_DIR}
EOF
}

VERBOSE=0
DRYRUN=0
for arg in "$@"; do
  case "${arg}" in
    -v|--verbose) VERBOSE=1 ;;
    -n|--dry-run) DRYRUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: ${arg}" >&2
      echo "Try '${0##*/} --help'." >&2
      exit 2
      ;;
  esac
done

# --- Exclusions -------------------------------------------------------------
# Paths are relative to ${SRC}. A leading "/" anchors to the home root, so
# "/.cache/**" matches ~/.cache only (not some nested .cache). "**" spans
# path separators; "*" matches a single segment.
#
# This is a SUPERSET of common launcher locations — trim it to the ones you
# actually use. (I don't know your exact setup; see the questions in chat.)
EXCLUDES=(
  # --- Steam (native) ---
  "/.local/share/Steam/steamapps/common/**"        # installed game files
  "/.local/share/Steam/steamapps/shadercache/**"
  "/.local/share/Steam/steamapps/downloading/**"
  "/.local/share/Steam/steamapps/temp/**"
  "/.local/share/Steam/appcache/**"
  "/.local/share/Steam/ubuntu12_32/**"
  "/.local/share/Steam/ubuntu12_64/**"
  "/.steam/**"                                     # symlinks into the above
  # NOTE: ~/.local/share/Steam/steamapps/compatdata holds Proton prefixes,
  # which often contain SAVE GAMES. It is intentionally NOT excluded here.
  # Uncomment the next line only if you back saves up some other way:
  # "/.local/share/Steam/steamapps/compatdata/**"

  # --- Heroic (Epic / GOG / Amazon) ---
  "/Games/Heroic/**"                               # default Heroic install dir

  # --- Lutris ---
  # Lutris game-install dir is user-defined (often ~/Games). Add yours:
  # "/Games/**"
  "/.local/share/lutris/runners/**"                # downloaded wine/proton builds
  "/.cache/lutris/**"

  # --- Bottles ---
  "/.local/share/bottles/**"

  # --- Generic regenerable / large ---
  "/.cache/**"
  "/.local/share/Trash/**"
  "/.var/app/*/cache/**"                           # Flatpak per-app caches
)

# --- rclone invocation ------------------------------------------------------
RCLONE_ARGS=(
  sync
  "${SRC}" "${DEST}"
  --one-file-system           # stay on the home btrfs fs; skip other mounts
  --create-empty-src-dirs
  --fast-list                 # fewer API calls to Drive (uses more RAM)
  --track-renames             # detect moved files instead of re-uploading
  --transfers 4
  --checkers 8
  --drive-chunk-size 128M     # better throughput on large files
  --log-level INFO
  --stats 30s
  --stats-one-line
)

if [[ -n "${VERSIONING}" ]]; then
  # backup-dir must live OUTSIDE the destination tree, so it's a sibling.
  RCLONE_ARGS+=( --backup-dir "${REMOTE}:${DEST_PATH}-archive/${STAMP}" )
fi

for pat in "${EXCLUDES[@]}"; do
  RCLONE_ARGS+=( --exclude "${pat}" )
done

[[ -n "${BWLIMIT}" ]] && RCLONE_ARGS+=( --bwlimit "${BWLIMIT}" )

if [[ "${DRYRUN}" -eq 1 ]]; then
  RCLONE_ARGS+=( --dry-run )
  echo ">>> DRY RUN — no files will be transferred."
fi

# --- Preflight --------------------------------------------------------------
command -v rclone >/dev/null || { echo "rclone is not installed." >&2; exit 1; }
rclone listremotes | grep -qx "${REMOTE}:" \
  || { echo "Remote '${REMOTE}:' not found. Run: rclone config" >&2; exit 1; }

# Single-instance lock so scheduled runs can't overlap.
exec 9>"${LOCK_FILE}"
flock -n 9 || { echo "Another backup is already running." >&2; exit 1; }

# --- Run --------------------------------------------------------------------
echo "Backup starting: ${SRC} -> ${DEST}"
echo "Log: ${LOG_FILE}"

rc=0
if [[ "${VERBOSE}" -eq 1 ]]; then
  # Stream the full log to the terminal AND save it to the log file.
  # ${PIPESTATUS[0]} is rclone's exit code (not tee's); '|| rc=' keeps set -e
  # from aborting before we capture it.
  rclone "${RCLONE_ARGS[@]}" 2>&1 | tee "${LOG_FILE}" || rc="${PIPESTATUS[0]}"
else
  # Default: log to the file only; terminal shows status + periodic stats.
  rclone "${RCLONE_ARGS[@]}" --log-file "${LOG_FILE}" || rc=$?
fi

if [[ "${rc}" -eq 0 ]]; then
  echo "Backup completed OK."
else
  echo "Backup FAILED (rclone exit ${rc}). See ${LOG_FILE}" >&2
  exit "${rc}"
fi

# Keep the 30 most recent log files (null-safe; newest first, drop the rest).
find "${LOG_DIR}" -maxdepth 1 -type f -name 'backup_*.log' -printf '%T@\t%p\0' \
  | sort -zrn | tail -zn +31 | cut -zf2- | xargs -0r rm -f