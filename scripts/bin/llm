#!/usr/bin/env bash
# shellcheck shell=bash
#
# llm.sh - manage local GGUF models for llama.cpp: download or requantize,
# keep a preset per model, benchmark, and serve (foreground or via the
# llama-server systemd user unit).
#
# Layout:
#   ~/.models/<files>.gguf          model files (LLM_MODELS overrides)
#   ~/.models/presets/<name>.conf   per-model settings (key=value)
#   ~/.config/llm/current           symlink to the preset the unit serves
#   ~/.models/bench.tsv             benchmark log

set -euo pipefail

readonly MODELS_DIR="${LLM_MODELS:-${HOME}/.models}"
readonly PRESETS="${MODELS_DIR}/presets"
readonly CONF_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/llm"
readonly CURRENT="${CONF_DIR}/current"
readonly BENCH_LOG="${MODELS_DIR}/bench.tsv"
readonly UNIT="llama-server.service"
readonly PRESET_KEYS="model mmproj ctx kv ngl temp top_p top_k min_p
presence_penalty reasoning host port extra"

VERBOSE=0
DRY_RUN=0
SERVER_PID=""

usage() {
    cat <<USAGE
Usage: ${0##*/} [-v] [-n] COMMAND [ARGS]

Commands:
  get [-q QUANT] [--from-bf16] [--keep] [--mmproj] REPO
        Download a GGUF quant from Hugging Face (REPO = OWNER/NAME) into
        ${MODELS_DIR} and create its preset. With --from-bf16, build QUANT
        from the repo's BF16 GGUF + imatrix when it isn't published.
  list                List presets (* = served by ${UNIT})
  show NAME           Print a preset
  edit NAME           Open a preset in \$EDITOR
  bench [-c CTX] [-r GIB] NAME|FILE...
                      Throughput (llama-bench) + VRAM loaded at CTX
  serve [NAME]        Run llama-server in the foreground (default: current)
  use NAME            Make NAME current and restart ${UNIT} if active
  status | logs       ${UNIT} status / follow journal
  rm [-y] NAME        Delete a preset and its model files

Options:
  -v, --verbose       Show progress and tool output
  -n, --dry-run       Show what would be done
  -h, --help          Show this help
USAGE
}

die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
warn() { printf 'warning: %s\n' "$*" >&2; }
vlog() { if (( VERBOSE )); then printf '%s\n' "$*" >&2; fi; }

# Run a command; its output goes to stderr with -v, else is discarded.
quiet() {
    if (( VERBOSE )); then "$@" >&2; else "$@" >/dev/null 2>&1; fi
}

# With -n, print the command instead of running it.
act() {
    if (( DRY_RUN )); then
        printf '[dry-run] %s\n' "$*"
    else
        quiet "$@"
    fi
}

need() {
    local c
    for c in "$@"; do
        command -v "${c}" >/dev/null 2>&1 || die "missing: ${c}"
    done
}

gib() { awk -v b="$1" 'BEGIN { printf "%.2f", b / 1073741824 }'; }

# --- presets ---------------------------------------------------------------

preset_path() {
    local name="$1"
    [[ "${name}" =~ ^[A-Za-z0-9._-]+$ ]] || die "bad preset name: ${name}"
    printf '%s/%s.conf\n' "${PRESETS}" "${name}"
}

# Load a preset into P_<key> variables. Parsed, never sourced.
load_preset() {
    local file="$1" key val
    [[ -f "${file}" ]] || die "no preset: ${file##*/}"
    P_model="" P_mmproj="" P_ctx=32768 P_kv=q8_0 P_ngl=99
    P_temp=0.6 P_top_p=0.95 P_top_k=20 P_min_p=0 P_presence_penalty=0
    P_reasoning="" P_host=127.0.0.1 P_port=8080 P_extra=""
    while IFS='=' read -r key val || [[ -n "${key}" ]]; do
        key="${key//[[:space:]]/}"
        [[ -z "${key}" || "${key}" == \#* ]] && continue
        [[ " ${PRESET_KEYS//$'\n'/ } " == *" ${key} "* ]] \
            || die "${file##*/}: unknown key '${key}'"
        val="${val#"${val%%[![:space:]]*}"}"
        val="${val%"${val##*[![:space:]]}"}"
        printf -v "P_${key}" '%s' "${val}"
    done < "${file}"
    [[ -n "${P_model}" ]] || die "${file##*/}: model= is required"
}

write_preset() {
    local name="$1" model="$2" mmproj="${3:-}" file
    file="$(preset_path "${name}")"
    if [[ -f "${file}" ]]; then
        vlog "keeping existing preset ${file}"
        return
    fi
    if (( DRY_RUN )); then
        printf '[dry-run] write preset %s\n' "${file}"
        return
    fi
    mkdir -p "${PRESETS}"
    cat > "${file}" <<PRESET
# ${name} - edit with: llm edit ${name}
model=${model}
mmproj=${mmproj}
# Context and KV cache; K and V types must match on HIP to keep fused FA
ctx=32768
kv=q8_0
ngl=99
# Sampling (Qwen thinking-mode coding defaults)
temp=0.6
top_p=0.95
top_k=20
min_p=0
presence_penalty=0
# reasoning: empty (template default), low, medium, xhigh, or off
reasoning=
host=127.0.0.1
port=8080
# Extra llama-server arguments, whitespace-separated
extra=
PRESET
    printf 'preset: %s\n' "${file}"
}

# Build llama-server argv from the loaded preset into SERVER_ARGS.
server_args() {
    SERVER_ARGS=(-m "${P_model}" -ngl "${P_ngl}" -fa on -c "${P_ctx}"
        -ctk "${P_kv}" -ctv "${P_kv}" --jinja
        --temp "${P_temp}" --top-p "${P_top_p}" --top-k "${P_top_k}"
        --min-p "${P_min_p}" --presence-penalty "${P_presence_penalty}"
        --host "${P_host}" --port "${P_port}")
    [[ -n "${P_mmproj}" ]] && SERVER_ARGS+=(--mmproj "${P_mmproj}")
    case "${P_reasoning}" in
        "") ;;
        off)
            SERVER_ARGS+=(--chat-template-kwargs '{"enable_thinking":false}')
            ;;
        low|medium|xhigh)
            SERVER_ARGS+=(--chat-template-kwargs
                "{\"reasoning_effort\":\"${P_reasoning}\"}") ;;
        *) die "reasoning must be empty, low, medium, xhigh, or off" ;;
    esac
    if [[ -n "${P_extra}" ]]; then
        local -a extra
        read -ra extra <<<"${P_extra}"
        SERVER_ARGS+=("${extra[@]}")
    fi
}

# Print every file of a model: the file itself, or all parts of a split.
model_files() {
    local m="$1"
    if [[ "${m}" =~ ^(.*)-00001-of-([0-9]{5})\.gguf$ ]]; then
        local prefix="${BASH_REMATCH[1]}" n="${BASH_REMATCH[2]}" i
        for (( i = 1; i <= 10#${n}; i++ )); do
            printf '%s-%05d-of-%s.gguf\n' "${prefix}" "${i}" "${n}"
        done
    else
        printf '%s\n' "${m}"
    fi
}

# --- get -------------------------------------------------------------------

# Print repo files, one per line, via the huggingface_hub Python API.
# Runs from / so a stray module in the cwd can't shadow imports.
repo_files() {
    (cd / && python3 -c '
import sys
from huggingface_hub import list_repo_files
print("\n".join(list_repo_files(sys.argv[1])))' "$1") \
        || die "cannot list ${1} (repo name? network? hf auth?)"
}

cmd_get() {
    local quant="" from_bf16=0 keep=0 want_mmproj=0 repo=""
    while (( $# > 0 )); do
        case "$1" in
            -q)          [[ -n "${2:-}" ]] || die "-q needs a value"
                         quant="$2"; shift ;;
            --quant=*)   quant="${1#*=}" ;;
            --from-bf16) from_bf16=1 ;;
            --keep)      keep=1 ;;
            --mmproj)    want_mmproj=1 ;;
            -*)          die "get: unknown option: $1" ;;
            *)           repo="$1" ;;
        esac
        shift
    done
    [[ "${repo}" == */* ]] || die "get: expected REPO as OWNER/NAME"
    [[ -n "${quant}" ]] || die "get: -q QUANT is required (e.g. IQ4_XS)"
    need hf python3

    local -a files ggufs matches
    mapfile -t files < <(repo_files "${repo}")
    mapfile -t ggufs < <(printf '%s\n' "${files[@]}" | grep -E '\.gguf$' \
        | grep -viE '(^|/)(mmproj|imatrix|mtp)' || true)
    # Match the quant as a whole token: IQ3_S must not match IQ3_S_M
    mapfile -t matches < <(printf '%s\n' "${ggufs[@]}" \
        | grep -iE "[-_.]${quant}([-.]|$)" || true)

    local mmproj=""
    if (( want_mmproj )); then
        mmproj="$(printf '%s\n' "${files[@]}" | grep -iE '(^|/)mmproj-F16' \
            | head -n1 || true)"
        [[ -n "${mmproj}" ]] || warn "no mmproj-F16 in ${repo}"
    fi

    mkdir -p "${MODELS_DIR}"
    local first name
    if (( ${#matches[@]} > 0 )); then
        vlog "downloading ${matches[*]}"
        act hf download "${repo}" "${matches[@]}" ${mmproj:+"${mmproj}"} \
            --local-dir "${MODELS_DIR}" || die "download failed"
        first="$(printf '%s\n' "${matches[@]}" | sort | head -n1)"
        name="${first##*/}"
        name="${name%.gguf}"
        name="${name%-00001-of-*}"
        write_preset "${name}" "${MODELS_DIR}/${first}" \
            "${mmproj:+${MODELS_DIR}/${mmproj}}"
        return
    fi

    if (( ! from_bf16 )); then
        printf 'available quants in %s:\n' "${repo}" >&2
        printf '%s\n' "${ggufs[@]}" | sed 's/^/  /' >&2
        die "no ${quant} published (retry with --from-bf16 to build it)"
    fi

    # Requantize from BF16 with the repo's own imatrix
    need llama-quantize
    local -a bf16
    mapfile -t bf16 < <(printf '%s\n' "${ggufs[@]}" | grep -iE 'bf16' \
        | sort || true)
    (( ${#bf16[@]} > 0 )) || die "${repo} has no BF16 GGUF to quantize from"
    local imatrix
    imatrix="$(printf '%s\n' "${files[@]}" | grep -iE 'imatrix.*\.gguf$' \
        | head -n1 || true)"
    [[ -n "${imatrix}" ]] \
        || warn "no imatrix in ${repo}; low-bit quants will be worse"

    vlog "downloading BF16 source: ${bf16[*]}"
    act hf download "${repo}" "${bf16[@]}" ${imatrix:+"${imatrix}"} \
        ${mmproj:+"${mmproj}"} --local-dir "${MODELS_DIR}" \
        || die "download failed"

    local src="${MODELS_DIR}/${bf16[0]}"
    name="${bf16[0]##*/}"
    name="${name%.gguf}"
    name="${name%-00001-of-*}"
    name="${name/[Bb][Ff]16/${quant}}"
    local out="${MODELS_DIR}/${name}.gguf"

    vlog "quantizing -> ${out}"
    act llama-quantize ${imatrix:+--imatrix "${MODELS_DIR}/${imatrix}"} \
        "${src}" "${out}" "${quant}" "$(nproc)" || die "llama-quantize failed"

    if (( ! keep )); then
        local f
        for f in "${bf16[@]}"; do act rm -f -- "${MODELS_DIR}/${f}"; done
        act rmdir --ignore-fail-on-non-empty -- \
            "$(dirname "${MODELS_DIR}/${bf16[0]}")"
    fi
    write_preset "${name}" "${out}" "${mmproj:+${MODELS_DIR}/${mmproj}}"
}

# --- list / show / edit / rm -----------------------------------------------

current_name() {
    local t
    t="$(readlink "${CURRENT}" 2>/dev/null || true)"
    t="${t##*/}"
    printf '%s\n' "${t%.conf}"
}

cmd_list() {
    local cur f name size
    cur="$(current_name)"
    shopt -s nullglob
    local -a confs=("${PRESETS}"/*.conf)
    shopt -u nullglob
    if (( ${#confs[@]} == 0 )); then
        printf 'no presets in %s\n' "${PRESETS}"
        return
    fi
    for f in "${confs[@]}"; do
        name="${f##*/}"
        name="${name%.conf}"
        load_preset "${f}"
        if [[ -f "${P_model}" ]]; then
            size="$(gib "$(model_files "${P_model}" | xargs -d '\n' \
                du -bc 2>/dev/null | tail -n1 | cut -f1)")G"
        else
            size="missing"
        fi
        printf '%1s %-48s %8s  ctx %s\n' \
            "$([[ "${name}" == "${cur}" ]] && echo '*')" \
            "${name}" "${size}" "${P_ctx}"
    done
}

cmd_show() {
    [[ -n "${1:-}" ]] || die "show: NAME required"
    cat "$(preset_path "$1")"
}

cmd_edit() {
    [[ -n "${1:-}" ]] || die "edit: NAME required"
    local f
    f="$(preset_path "$1")"
    [[ -f "${f}" ]] || die "no preset: $1"
    "${VISUAL:-${EDITOR:-vi}}" "${f}"
    load_preset "${f}"   # validate after editing
}

cmd_rm() {
    local yes=0 name=""
    while (( $# > 0 )); do
        case "$1" in
            -y) yes=1 ;;
            *)  name="$1" ;;
        esac
        shift
    done
    [[ -n "${name}" ]] || die "rm: NAME required"
    local f
    f="$(preset_path "${name}")"
    load_preset "${f}"
    [[ "${name}" == "$(current_name)" ]] \
        && die "${name} is current; 'llm use' another model first"

    local -a victims=("${f}") parts
    local p
    mapfile -t parts < <(model_files "${P_model}")
    for p in "${parts[@]}"; do [[ -e "${p}" ]] && victims+=("${p}"); done
    printf 'remove:\n'
    printf '  %s\n' "${victims[@]}"
    if (( ! yes && ! DRY_RUN )); then
        local ans
        read -rp 'proceed? [y/N] ' ans
        [[ "${ans}" == [yY] ]] || die "aborted"
    fi
    act rm -f -- "${victims[@]}"
}

# --- serve / use / status --------------------------------------------------

resolve_preset_file() {
    if [[ -n "${1:-}" ]]; then
        preset_path "$1"
    elif [[ -e "${CURRENT}" ]]; then
        readlink -f "${CURRENT}"
    else
        die "no current model; run 'llm use NAME' or pass NAME"
    fi
}

cmd_serve() {
    need llama-server
    local f
    f="$(resolve_preset_file "${1:-}")"
    load_preset "${f}"
    [[ -f "${P_model}" ]] || die "model file missing: ${P_model}"
    server_args
    vlog "llama-server ${SERVER_ARGS[*]}"
    if (( DRY_RUN )); then
        printf '[dry-run] llama-server %s\n' "${SERVER_ARGS[*]}"
        return
    fi
    exec llama-server "${SERVER_ARGS[@]}"
}

cmd_use() {
    [[ -n "${1:-}" ]] || die "use: NAME required"
    local f
    f="$(preset_path "$1")"
    load_preset "${f}"
    [[ -f "${P_model}" ]] || die "model file missing: ${P_model}"
    act mkdir -p "${CONF_DIR}"
    act ln -sfn "${f}" "${CURRENT}"
    if systemctl --user is-active --quiet "${UNIT}"; then
        act systemctl --user restart "${UNIT}"
        printf 'serving %s (restarted %s)\n' "$1" "${UNIT}"
    else
        printf 'current: %s (%s not running)\n' "$1" "${UNIT}"
    fi
}

# --- bench -----------------------------------------------------------------

vram_file() {
    local f
    for f in /sys/class/drm/card*/device/mem_info_vram_used; do
        [[ -r "${f}" ]] && { printf '%s\n' "${f}"; return; }
    done
    die "no amdgpu VRAM counters in /sys/class/drm"
}

bench_cleanup() {
    if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" 2>/dev/null; then
        kill "${SERVER_PID}" 2>/dev/null || true
        wait "${SERVER_PID}" 2>/dev/null || true
    fi
}

# llama-bench -> "pp_ts tg_ts"
bench_tps() {
    local json
    json="$(llama-bench -m "$1" -ngl 99 -fa 1 -ctk "$2" -ctv "$2" \
        -p 512 -n 128 -o json 2>/dev/null)" || die "llama-bench failed: $1"
    (cd / && python3 -I -c '
import json, sys
pp = tg = 0.0
for r in json.load(sys.stdin):
    if r.get("n_gen", 0) == 0:
        pp = r["avg_ts"]
    elif r.get("n_prompt", 0) == 0:
        tg = r["avg_ts"]
print(f"{pp:.1f} {tg:.1f}")') <<<"${json}"
}

# Load llama-server at ctx; print VRAM bytes used once healthy.
bench_vram() {
    local model="$1" ctx="$2" kv="$3" vram="$4" port=8099 waited=0 used
    curl -sf "localhost:${port}/health" >/dev/null 2>&1 \
        && die "port ${port} busy"
    llama-server -m "${model}" -ngl 99 -fa on -c "${ctx}" -ctk "${kv}" \
        -ctv "${kv}" --jinja --host 127.0.0.1 --port "${port}" \
        >/dev/null 2>&1 &
    SERVER_PID=$!
    until curl -sf "localhost:${port}/health" >/dev/null 2>&1; do
        kill -0 "${SERVER_PID}" 2>/dev/null \
            || die "llama-server exited loading ${model##*/} (OOM?)"
        (( waited++ < 300 )) || die "llama-server timed out"
        sleep 1
    done
    sleep 2
    used="$(cat "${vram}")"
    bench_cleanup
    SERVER_PID=""
    sleep 2
    printf '%s\n' "${used}"
}

cmd_bench() {
    local ctx="" reserve=1.5
    local -a targets=()
    while (( $# > 0 )); do
        case "$1" in
            -c) ctx="${2:-}"; shift ;;
            -r) reserve="${2:-}"; shift ;;
            -*) die "bench: unknown option: $1" ;;
            *)  targets+=("$1") ;;
        esac
        shift
    done
    (( ${#targets[@]} > 0 )) || die "bench: NAME or FILE required"
    [[ -z "${ctx}" || "${ctx}" =~ ^[0-9]+$ ]] || die "bad ctx: ${ctx}"
    [[ "${reserve}" =~ ^[0-9]+(\.[0-9]+)?$ ]] || die "bad reserve: ${reserve}"
    need llama-bench llama-server curl python3

    local vram total build
    vram="$(vram_file)"
    total="$(cat "${vram%_used}_total")"
    vlog "VRAM total $(gib "${total}") GiB, baseline $(gib "$(cat "${vram}")")"
    if systemctl --user is-active --quiet "${UNIT}"; then
        warn "${UNIT} is running; its VRAM will skew results"
    fi
    build="$(llama-server --version 2>&1 | grep -oE 'commit [0-9a-f]+' \
        | head -n1 | cut -d' ' -f2 || true)"

    if (( DRY_RUN )); then
        printf '[dry-run] bench %s\n' "${targets[*]}"
        return
    fi
    if [[ ! -s "${BENCH_LOG}" ]]; then
        mkdir -p "${MODELS_DIR}"
        printf 'date\tbuild\tmodel\tsize_gib\tctx\tkv\tpp_ts\ttg_ts\t%s\n' \
            vram_gib > "${BENCH_LOG}"
    fi

    trap bench_cleanup EXIT INT TERM
    local fmt='%-44s %7s %6s %8s %6s %8s %7s\n'
    # shellcheck disable=SC2059
    printf "${fmt}" MODEL SIZE CTX PP/s TG/s VRAM FREE
    local t model name c kv size pp tg used free
    for t in "${targets[@]}"; do
        if [[ -f "${t}" ]]; then
            model="${t}" c="${ctx:-32768}" kv=q8_0
        else
            load_preset "$(preset_path "${t}")"
            model="${P_model}" c="${ctx:-${P_ctx}}" kv="${P_kv}"
        fi
        [[ -f "${model}" ]] || die "model file missing: ${model}"
        name="${model##*/}"
        name="${name%.gguf}"
        size="$(gib "$(model_files "${model}" | xargs -d '\n' du -bc \
            | tail -n1 | cut -f1)")"
        vlog "bench ${name}"
        read -r pp tg < <(bench_tps "${model}" "${kv}")
        used="$(bench_vram "${model}" "${c}" "${kv}" "${vram}")"
        free="$(gib "$(( total - used ))")"
        # shellcheck disable=SC2059
        printf "${fmt}" "${name:0:44}" "${size}G" "${c}" "${pp}" "${tg}" \
            "$(gib "${used}")G" "${free}G"
        if awk -v f="${free}" -v r="${reserve}" 'BEGIN { exit !(f < r) }'
        then
            warn "${name}: ${free} GiB free at ${c} ctx (< ${reserve})"
        fi
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -Iseconds)" \
            "${build:-unknown}" "${name}" "${size}" "${c}" "${kv}" \
            "${pp}" "${tg}" "$(gib "${used}")" >> "${BENCH_LOG}"
    done
}

# --- main ------------------------------------------------------------------

main() {
    while (( $# > 0 )); do
        case "$1" in
            -v|--verbose) VERBOSE=1 ;;
            -n|--dry-run) DRY_RUN=1 ;;
            -h|--help)    usage; exit 0 ;;
            -*)           usage >&2; die "unknown option: $1" ;;
            *)            break ;;
        esac
        shift
    done
    (( $# > 0 )) || { usage >&2; exit 1; }
    local cmd="$1"
    shift
    case "${cmd}" in
        get)    cmd_get "$@" ;;
        list)   cmd_list ;;
        show)   cmd_show "$@" ;;
        edit)   cmd_edit "$@" ;;
        bench)  cmd_bench "$@" ;;
        serve)  cmd_serve "$@" ;;
        use)    cmd_use "$@" ;;
        status) systemctl --user status "${UNIT}" ;;
        logs)   journalctl --user -u "${UNIT}" -f ;;
        rm)     cmd_rm "$@" ;;
        help)   usage ;;
        *)      usage >&2; die "unknown command: ${cmd}" ;;
    esac
}

main "$@"
