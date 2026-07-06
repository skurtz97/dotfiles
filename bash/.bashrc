# .bashrc
# shellcheck shell=bash

# Source global definitions
if [ -f /etc/bashrc ]; then
    # shellcheck source=/dev/null
    . /etc/bashrc
fi

# >>> mamba initialize >>>
# (managed by `micromamba shell init` — leave verbatim)
if [ -n "$MAMBA_EXE" ]; then
    eval "$("$MAMBA_EXE" shell completion bash 2>/dev/null)"
fi
export MAMBA_EXE='/home/skurtz/.local/bin/micromamba'
export MAMBA_ROOT_PREFIX='/home/skurtz/.micromamba'
__mamba_setup="$("$MAMBA_EXE" shell hook --shell bash --root-prefix "$MAMBA_ROOT_PREFIX" 2>/dev/null)"
# shellcheck disable=SC2181
if [ $? -eq 0 ]; then
    eval "$__mamba_setup"
else
    # shellcheck disable=SC2139
    alias micromamba="$MAMBA_EXE"
fi
unset __mamba_setup
# <<< mamba initialize <<<

# pnpm (managed — already idempotent)
export PNPM_HOME="/home/skurtz/.local/share/pnpm"
case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# --- Interactive shells only below ---
[[ $- == *i* ]] || return

alias vi='nvim'
alias vim='nvim'
alias vscode='code'
alias conda='micromamba'
alias mamba='micromamba'
alias systemctlu='systemctl --user'
alias sctl='sudo systemctl'
alias sctlu='systemctl --user'

# complete-alias: make completion work through the aliases above
# shellcheck source=/dev/null
if [ -f ~/.complete_alias ]; then
    . ~/.complete_alias
    complete -F _complete_alias vi vim vscode conda mamba systemctlu sctl sctlu
fi

# --- Pure Bash PATH Deduplication ---
if [ -n "$PATH" ]; then
    _new_path=""
    # Temporarily set the internal field separator to colon
    IFS=':' read -ra _path_dirs <<< "$PATH"
    for _dir in "${_path_dirs[@]}"; do
        # Ignore empty directories
        [ -z "$_dir" ] && continue
        
        # If the directory isn't already in the clean path, add it
        case ":$_new_path:" in
            *":$_dir:"*) ;;
            *) _new_path="${_new_path:+$_new_path:}$_dir" ;;
        esac
    done
    export PATH="$_new_path"
    unset _new_path _path_dirs _dir
fi

