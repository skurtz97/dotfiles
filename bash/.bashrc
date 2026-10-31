# .bashrc
# shellcheck shell=bash

# =============================================================================
# ~/.bashrc — env/PATH for every shell, then interactive config.
# .bash_profile only sources this file.
# =============================================================================

# -----------------------------------------------------------------------------
# System-wide definitions
# -----------------------------------------------------------------------------
if [ -f /etc/bashrc ]; then
  # shellcheck source=/dev/null
  . /etc/bashrc
fi

# -----------------------------------------------------------------------------
# Environment (all shells, incl. non-interactive)
# -----------------------------------------------------------------------------
: "${XDG_DATA_HOME:=$HOME/.local/share}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"

export GOPATH="$XDG_DATA_HOME/go" # module cache / sources
export GOBIN="$HOME/.local/bin"   # `go install` targets
export BUN_INSTALL="$XDG_DATA_HOME/bun"
export NPM_CONFIG_PREFIX="$HOME/.local" # `npm i -g` -> ~/.local/{bin,lib}
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"

# Prepended in order, so the LAST entry ends up first in PATH
for _dir in "$BUN_INSTALL/bin" "$HOME/.local/bin" "$HOME/bin"; do
  case ":${PATH}:" in
  *":$_dir:"*) ;;
  *) PATH="$_dir${PATH:+:$PATH}" ;;
  esac
done
unset _dir
export PATH

export EDITOR="nvim" VISUAL="nvim" SUDO_EDITOR="nvim"

# Default toolchain: LLVM (/usr/bin/cc stays GCC for rpm/akmods)
export CC="clang" CXX="clang++" LD="ld.lld" LDFLAGS="-fuse-ld=lld"

# -----------------------------------------------------------------------------
# Non-interactive shells stop here
# -----------------------------------------------------------------------------
[[ $- == *i* ]] || return

# -----------------------------------------------------------------------------
# Tool init: micromamba
# Block below (>>> / <<< markers) is written by `micromamba shell init`.
# Leave the sentinel comments and body verbatim so a future re-run of that
# command can find and replace it.
# -----------------------------------------------------------------------------
# >>> mamba initialize >>>
export MAMBA_EXE='/home/skurtz/.local/bin/micromamba'
export MAMBA_ROOT_PREFIX='/home/skurtz/.local/share/micromamba'
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

# eza (modern ls). Interactive-only, so /usr/bin/ls and /usr/bin/tree
# stay untouched for scripts. Use \ls to bypass an alias on demand.
alias ls='eza --icons --group-directories-first'
alias tree='eza --tree --icons --group-directories-first --git-ignore'

# -----------------------------------------------------------------------------
# Completion: make complete-alias work through the aliases above
# -----------------------------------------------------------------------------
if [ -f ~/.complete_alias ]; then
  # shellcheck source=/dev/null
  . ~/.complete_alias
  complete -F _complete_alias \
    vi vim vscode conda mamba \
    ls tree
fi

# -----------------------------------------------------------------------------
# PATH de-duplication
# Safety net for anything the tool-init blocks above prepend without checking
# for duplicates first.
# -----------------------------------------------------------------------------
if [ -n "$PATH" ]; then
  _new_path=""
  IFS=':' read -ra _path_dirs <<<"$PATH"
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
