#!/usr/bin/env bash
# shellcheck shell=bash
# claude-fw-wrapper: claudeCode.claudeProcessWrapper target -> Fireworks
set -euo pipefail

key_file="$HOME/.config/opencode/secrets/fireworks-key"
[[ -r "$key_file" ]] || { printf 'error: %s not readable\n' "$key_file" >&2; exit 1; }

export ANTHROPIC_BASE_URL="https://api.fireworks.ai/inference"
ANTHROPIC_AUTH_TOKEN="$(<"$key_file")"
export ANTHROPIC_AUTH_TOKEN
export ENABLE_TOOL_SEARCH=true

# Pin every slot to Fireworks so nothing requests a Claude model ID
export ANTHROPIC_MODEL="${FW_MODEL:-glm-latest}"
export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-latest"
export ANTHROPIC_DEFAULT_SONNET_MODEL="kimi-latest"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-flash-latest"
export ANTHROPIC_DEFAULT_FABLE_MODEL="glm-latest"
export CLAUDE_CODE_SUBAGENT_MODEL="deepseek-flash-latest"

if (( $# > 0 )); then exec "$@"; else exec claude; fi