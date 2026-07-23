#!/usr/bin/env bash
#
# backup-docs.sh - Archive ~/docs with maximum xz compression and upload
# the result to Google Drive via rclone.
#
# Output: ~/archives/docs-archive.tar.xz (overwritten on each run)
# Remote: gdrive:backups

set -euo pipefail

readonly SRC_PARENT="${HOME}"
readonly SRC_NAME="docs"
readonly DEST_DIR="${HOME}/archives"
readonly ARCHIVE_PATH="${DEST_DIR}/docs-archive.tar.xz"
readonly TMP_PATH="${ARCHIVE_PATH}.tmp"
readonly REMOTE="gdrive:backups"

DRY_RUN=0
VERBOSE=0

usage() {
    cat <<EOF
Usage: ${0##*/} [OPTIONS]

Archive ${SRC_PARENT}/${SRC_NAME} to ${ARCHIVE_PATH} using xz -9e
(maximum compression), then upload it to ${REMOTE} via rclone.

Options:
  -n, --dry-run    Show what would be done without writing or uploading
  -v, --verbose    Verbose output (tar file listing, rclone progress)
  -h, --help       Show this help and exit
EOF
}

log() {
    printf '%s\n' "$*"
}

vlog() {
    if (( VERBOSE )); then
        printf '%s\n' "$*"
    fi
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

cleanup() {
    rm -f "${TMP_PATH}"
}

parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            -n|--dry-run) DRY_RUN=1 ;;
            -v|--verbose) VERBOSE=1 ;;
            -h|--help)    usage; exit 0 ;;
            *)            usage >&2; die "unknown option: $1" ;;
        esac
        shift
    done
}

check_prereqs() {
    command -v xz >/dev/null 2>&1 || die "xz not found in PATH"
    command -v rclone >/dev/null 2>&1 || die "rclone not found in PATH"
    [[ -d "${SRC_PARENT}/${SRC_NAME}" ]] \
        || die "source directory not found: ${SRC_PARENT}/${SRC_NAME}"

    local remote_name="${REMOTE%%:*}:"
    rclone listremotes | grep -qx "${remote_name}" \
        || die "rclone remote '${remote_name}' is not configured"
}

create_archive() {
    if (( DRY_RUN )); then
        log "[dry-run] would archive ${SRC_PARENT}/${SRC_NAME} -> ${ARCHIVE_PATH} (tar | xz -9e)"
        return 0
    fi

    mkdir -p "${DEST_DIR}"

    local tar_flags=(--one-file-system -C "${SRC_PARENT}" -cf -)
    if (( VERBOSE )); then
        tar_flags=(--one-file-system -C "${SRC_PARENT}" -cvf -)
    fi

    vlog "archiving ${SRC_PARENT}/${SRC_NAME} -> ${TMP_PATH}"
    tar "${tar_flags[@]}" "${SRC_NAME}" | xz -9e > "${TMP_PATH}"
    mv -f "${TMP_PATH}" "${ARCHIVE_PATH}"

    log "created ${ARCHIVE_PATH} ($(du -h "${ARCHIVE_PATH}" | cut -f1))"
}

upload_archive() {
    if (( DRY_RUN )); then
        log "[dry-run] would upload ${ARCHIVE_PATH} -> ${REMOTE}/"
        return 0
    fi

    local rclone_flags=()
    if (( VERBOSE )); then
        rclone_flags+=(--progress --verbose)
    fi

    vlog "uploading ${ARCHIVE_PATH} -> ${REMOTE}/"
    rclone copy "${rclone_flags[@]+"${rclone_flags[@]}"}" "${ARCHIVE_PATH}" "${REMOTE}"
    log "uploaded to ${REMOTE}/$(basename "${ARCHIVE_PATH}")"
}

main() {
    parse_args "$@"
    trap cleanup EXIT
    check_prereqs
    create_archive
    upload_archive
}

main "$@"