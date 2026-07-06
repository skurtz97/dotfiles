# .bash_profile
# shellcheck shell=bash

# --- Idempotent PATH helpers: never add a dir that's already present ---
path_prepend() {
    case ":${PATH}:" in
        *":$1:"*) ;;
        *) PATH="$1${PATH:+:$PATH}" ;;
    esac
}
path_append() {
    case ":${PATH}:" in
        *":$1:"*) ;;
        *) PATH="${PATH:+$PATH:}$1" ;;
    esac
}

# Personal bin dirs, highest priority at the front
path_prepend "$HOME/.npm-global/bin"
path_prepend "$HOME/.opencode/bin"
path_prepend "$HOME/.local/bin"
path_prepend "$HOME/bin"

# Go toolchain (tools installed via `go install`)
export GOPATH="$HOME/.go"
path_append "$GOPATH/bin"

# Bun
export BUN_INSTALL="$HOME/.bun"
path_append "$BUN_INSTALL/bin"

# LM Studio CLI
path_append "$HOME/.lmstudio/bin"

export PATH

# Preferred editor
export EDITOR="nvim"
export VISUAL="nvim"
export SUDO_EDITOR="nvim"

# Load interactive settings (aliases, completion, vendor hooks)
# shellcheck source-path=SCRIPTDIR
# shellcheck source=.bashrc
# shellcheck disable=SC1091
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi