# .bashrc
# shellcheck shell=bash

# =============================================================================
# ~/.bashrc — interactive shell config (PATH/env setup lives in .bash_profile)
# =============================================================================

# -----------------------------------------------------------------------------
# System-wide definitions
# -----------------------------------------------------------------------------
if [ -f /etc/bashrc ]; then
    # shellcheck source=/dev/null
    . /etc/bashrc
fi

# -----------------------------------------------------------------------------
# Stop here for non-interactive shells. Keep this guard immediately below the
# system-wide source above — everything after it forks processes or defines
# interactive-only conveniences, and shouldn't run for non-interactive
# invocations of this file.
# -----------------------------------------------------------------------------
[[ $- == *i* ]] || return

# -----------------------------------------------------------------------------
# Tool init: micromamba
# Block below (>>> / <<< markers) is written by `micromamba shell init`.
# Leave the sentinel comments and body verbatim so a future re-run of that
# command can find and replace it — only its position in the file changed.
# -----------------------------------------------------------------------------
# >>> mamba initialize >>>
export MAMBA_EXE='/home/skurtz/.local/bin/micromamba'
export MAMBA_ROOT_PREFIX='/home/skurtz/.micromamba'
if __mamba_setup="$("$MAMBA_EXE" shell hook --shell bash \
    --root-prefix "$MAMBA_ROOT_PREFIX" 2>/dev/null)"; then
    eval "$__mamba_setup"
else
    # shellcheck disable=SC2139
    alias micromamba="$MAMBA_EXE"
fi
unset __mamba_setup
# <<< mamba initialize <

# -----------------------------------------------------------------------------
# Tool init: pnpm
# `# pnpm` / `# pnpm end` are the markers the pnpm installer looks for to
# update this block idempotently on reinstall — leave them as-is.
# -----------------------------------------------------------------------------
# pnpm
export PNPM_HOME="/home/skurtz/.local/share/pnpm"
case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# -----------------------------------------------------------------------------
# Aliases
# -----------------------------------------------------------------------------
alias vi='nvim'
alias vim='nvim'
alias vscode='code'
alias conda='micromamba'
alias mamba='micromamba'
alias systemctlu='systemctl --user'
alias sctl='sudo systemctl'
alias sctlu='systemctl --user'

# eza (modern ls). Interactive-only, so /usr/bin/ls and /usr/bin/tree
# stay untouched for scripts. Use \ls to bypass an alias on demand.
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --git --icons --group-directories-first'
alias la='eza -la --git --icons --group-directories-first'
alias lt='eza --tree --level=2 --icons --group-directories-first'
alias tree='eza --tree --icons --group-directories-first --git-ignore'

# -----------------------------------------------------------------------------
# Completion: make complete-alias work through the aliases above
# -----------------------------------------------------------------------------
if [ -f ~/.complete_alias ]; then
    # shellcheck source=/dev/null
    . ~/.complete_alias
    complete -F _complete_alias \
        vi vim vscode conda mamba systemctlu sctl sctlu \
        ls ll la lt tree
fi

# -----------------------------------------------------------------------------
# PATH de-duplication
# Safety net for anything the tool-init blocks above prepend without checking
# for duplicates first (mamba's hook and pnpm's case-guard each dedupe their
# own entry, but this catches everything else, e.g. future eval'd hooks).
# -----------------------------------------------------------------------------
if [ -n "$PATH" ]; then
    _new_path=""
    IFS=':' read -ra _path_dirs <<< "$PATH"
    for _dir in "${_path_dirs[@]}"; do
        [ -z "$_dir" ] && continue
        case ":$_new_path:" in
            *":$_dir:"*) ;;
            *) _new_path="${_new_path:+$_new_path:}$_dir" ;;
        esac
    done
    export PATH="$_new_path"
    unset _new_path _path_dirs _dir
fi