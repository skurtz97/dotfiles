# .bashrc (z/OS USS, zopen bash; exec'd by /etc/zopen-bash)
# shellcheck shell=bash

[[ $- == *i* ]] || return

if command -v vim >/dev/null 2>&1; then
    export EDITOR="vim" VISUAL="vim"
    alias vi='vim'
fi

# --- Prompt: user@host:dir (git status)$, as on the workstation ---
GIT_PS1_SHOWDIRTYSTATE=1
GIT_PS1_SHOWUNTRACKEDFILES=1
GIT_PS1_SHOWUPSTREAM=auto

_git_prompt=""
if command -v git >/dev/null 2>&1; then
    for _f in \
        "$(git --exec-path 2>/dev/null)/../../share/git-core/contrib/completion/git-prompt.sh" \
        /usr/local/zopen/usr/local/zopen/git/git/share/git-core/contrib/completion/git-prompt.sh; do
        if [ -r "$_f" ]; then
            # shellcheck source=/dev/null
            . "$_f" && _git_prompt='$(__git_ps1 " (%s)")'
            break
        fi
    done
    unset _f
fi

PS1='\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]'"${_git_prompt}"'\$ '
unset _git_prompt

alias ll='ls -l'
alias la='ls -la'