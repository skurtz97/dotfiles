#!/usr/bin/env bash
# shellcheck shell=bash
#
# cline-config.sh - install Cline provider config (OpenRouter, Fireworks,
# DeepInfra) from the dotfiles seeds into ~/.cline/data/settings/.
#
# Cline rewrites providers.json/models.json via rename(2), which would
# replace stow symlinks, so the files are rendered and copied instead.
# Seed entries are merged over existing ones; other providers are kept.
#
# Keys come from OPENROUTER_API_KEY, FIREWORKS_API_KEY, DEEPINFRA_API_KEY,
# or are prompted for (no echo). They are passed to jq via the
# environment, never argv, and written with mode 0600.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
readonly SEED_DIR="${SCRIPT_DIR}/../../cline"
readonly DATA_DIR="${CLINE_DATA_DIR:-${CLINE_DIR:-${HOME}/.cline}/data}"
readonly SETTINGS_DIR="${DATA_DIR}/settings"
readonly PROVIDERS="${SETTINGS_DIR}/providers.json"
readonly MODELS="${SETTINGS_DIR}/models.json"

DRY_RUN=0
VERBOSE=0

usage() {
    cat <<EOF
Usage: ${0##*/} [OPTIONS]

Merge ${SEED_DIR}/{providers.seed,models}.json into
${SETTINGS_DIR}/. Close VS Code / Cline first.

Options:
  -n, --dry-run    Print the resulting files with keys redacted
  -v, --verbose    Verbose output
  -h, --help       Show this help and exit
EOF
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

# Prompt for each key env var the seed names but the environment lacks
read_keys() {
    local var key
    while read -r var; do
        if [[ -n "${!var:-}" ]]; then
            vlog "using ${var} from environment"
            continue
        fi
        (( DRY_RUN )) && { export "${var}=<unset>"; continue; }
        read -rsp "${var}: " key </dev/tty
        printf '\n' >&2
        [[ -n "${key}" ]] || die "${var} is empty"
        export "${var}=${key}"
    done < <(jq -r '.providers[].keyEnv' "${SEED_DIR}/providers.seed.json")
}

# Existing files are read by jq directly so old keys never hit argv
existing_or_null() {
    if [[ -f "$1" ]]; then printf '%s' "$1"; else printf '/dev/null'; fi
}

render_providers() {
    jq --slurpfile prev "$(existing_or_null "${PROVIDERS}")" \
        --arg now "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" '
        ($prev[0] // {}) as $old
        | {
            version: 1,
            lastUsedProvider: .lastUsedProvider,
            modes: ($old.modes // {}),
            providers: (($old.providers // {}) + (.providers | map_values({
                settings: (del(.keyEnv) + {apiKey: $ENV[.keyEnv]}),
                updatedAt: $now,
                tokenSource: "manual"
            })))
        } + (if $old.repairs then {repairs: $old.repairs} else {} end)
    ' "${SEED_DIR}/providers.seed.json"
}

render_models() {
    jq --slurpfile prev "$(existing_or_null "${MODELS}")" '
        ($prev[0] // {}) as $old
        | {version: 1, providers: (($old.providers // {}) + .providers)}
    ' "${SEED_DIR}/models.json"
}

# Atomic write: temp file in the same dir, mode 0600, then rename
install_file() {
    local dest="$1" content="$2" tmp
    if [[ -f "${dest}" ]]; then
        install -m 600 "${dest}" "${dest}.bak"
        vlog "backup ${dest}.bak"
    fi
    tmp="$(mktemp "${dest}.XXXXXX")"
    chmod 600 "${tmp}"
    printf '%s\n' "${content}" > "${tmp}"
    mv -f "${tmp}" "${dest}"
    printf 'wrote %s\n' "${dest}"
}

main() {
    parse_args "$@"
    command -v jq >/dev/null 2>&1 || die "jq not found (dnf install jq)"
    [[ -f "${SEED_DIR}/providers.seed.json" ]] \
        || die "seed not found: ${SEED_DIR}/providers.seed.json"

    read_keys
    local providers models
    providers="$(render_providers)"
    models="$(render_models)"

    if (( DRY_RUN )); then
        jq '.providers[].settings.apiKey |= if . then "<redacted>" else . end' \
            <<<"${providers}"
        printf '%s\n' "${models}"
        return 0
    fi

    mkdir -p "${SETTINGS_DIR}"
    chmod 700 "${SETTINGS_DIR}"
    install_file "${PROVIDERS}" "${providers}"
    install_file "${MODELS}" "${models}"
}

main "$@"
