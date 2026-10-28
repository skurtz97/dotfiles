# .bash_profile (z/OS USS) - /etc/profile already sets encoding,
# PATH and zopen; login bash just defers to .bashrc
# shellcheck shell=bash
if [ -f ~/.bashrc ]; then
    # shellcheck source=/dev/null
    . ~/.bashrc
fi