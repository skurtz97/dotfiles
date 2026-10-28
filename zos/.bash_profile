# .bash_profile (z/OS USS, zopen bash)
# shellcheck shell=bash

# Treat untagged/new files and pipes as ASCII (ISO8859-1)
export _BPXK_AUTOCVT=ON
export _CEE_RUNOPTS="FILETAG(AUTOCVT,AUTOTAG) POSIX(ON)"
export _TAG_REDIR_IN=txt
export _TAG_REDIR_OUT=txt
export _TAG_REDIR_ERR=txt

# zopen environment: PATH, MANPATH, etc. for /usr/local/zopen tools
if [ -r /usr/local/zopen/etc/zopen-config ]; then
    # shellcheck source=/dev/null
    . /usr/local/zopen/etc/zopen-config
fi

case ":${PATH}:" in
    *":$HOME/bin:"*) ;;
    *) PATH="$HOME/bin:$PATH" ;;
esac
export PATH

export TERM="${TERM:-xterm}"
if command -v vim >/dev/null 2>&1; then
    export EDITOR="vim" VISUAL="vim"
else
    export EDITOR="vi" VISUAL="vi"
fi

if [ -f ~/.bashrc ]; then
    # shellcheck source=/dev/null
    . ~/.bashrc
fi