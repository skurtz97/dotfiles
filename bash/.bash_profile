# .bash_profile
# shellcheck shell=bash

# Login shells: env, PATH and interactive config all live in .bashrc
# shellcheck source=.bashrc
# shellcheck disable=SC1091
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi