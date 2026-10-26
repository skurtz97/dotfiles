# Makefile — install bin/* into ~/.local/bin as extensionless symlinks.
# Quiet by default; pass V=1 for per-file output. Errors go to stderr.

SHELL       := /bin/bash
.SHELLFLAGS := -euo pipefail -c

PREFIX  ?= $(HOME)/.local
BINDIR  := $(PREFIX)/bin
SRCDIR  := $(CURDIR)/bin
SCRIPTS := $(sort $(wildcard $(SRCDIR)/*.sh $(SRCDIR)/*.py))
SAY     := $(if $(filter 1,$(V)),printf '%s\n',:)

.DEFAULT_GOAL := help
.PHONY: help install uninstall list check

help:
	@printf '%s\n' \
	  'make install    link bin/* -> $(BINDIR) (extensions stripped), prune stale links' \
	  'make uninstall  remove every link in $(BINDIR) pointing into this repo' \
	  'make list       show state of each script (installed/missing/conflict)' \
	  'make check      shellcheck *.sh, py_compile *.py' \
	  '' \
	  'V=1 for verbose output'

install:
	@mkdir -p "$(BINDIR)"
	@dups=$$(for s in $(SCRIPTS); do n=$${s##*/}; echo "$${n%.*}"; done | sort | uniq -d); \
	if [[ -n "$$dups" ]]; then printf 'error: duplicate command names: %s\n' $$dups >&2; exit 1; fi
	@for dst in "$(BINDIR)"/*; do \
	    [[ -L "$$dst" && ! -e "$$dst" ]] || continue; \
	    case "$$(readlink "$$dst")" in "$(SRCDIR)"/*) rm -- "$$dst"; $(SAY) "prune: $${dst##*/}";; esac; \
	done
	@rc=0; \
	for src in $(SCRIPTS); do \
	    n=$${src##*/}; name=$${n%.*}; dst="$(BINDIR)/$$name"; \
	    chmod +x "$$src"; \
	    if [[ -L "$$dst" && "$$(readlink "$$dst")" == "$$src" ]]; then continue; fi; \
	    if [[ -e "$$dst" || -L "$$dst" ]]; then \
	        printf 'error: %s exists and is not managed by this repo\n' "$$dst" >&2; rc=1; continue; \
	    fi; \
	    ln -s "$$src" "$$dst"; $(SAY) "link: $$name"; \
	done; \
	exit $$rc

uninstall:
	@for dst in "$(BINDIR)"/*; do \
	    [[ -L "$$dst" ]] || continue; \
	    case "$$(readlink "$$dst")" in "$(SRCDIR)"/*) rm -- "$$dst"; $(SAY) "unlink: $${dst##*/}";; esac; \
	done

list:
	@for src in $(SCRIPTS); do \
	    n=$${src##*/}; name=$${n%.*}; dst="$(BINDIR)/$$name"; \
	    if [[ "$$(readlink "$$dst" 2>/dev/null)" == "$$src" ]]; then s=installed; \
	    elif [[ -e "$$dst" || -L "$$dst" ]]; then s=conflict; \
	    else s=missing; fi; \
	    printf '%-10s %s\n' "$$s" "$$name"; \
	done

check:
	@sh=( $(filter %.sh,$(SCRIPTS)) ); py=( $(filter %.py,$(SCRIPTS)) ); \
	(( $${#sh[@]} == 0 )) || shellcheck -x "$${sh[@]}"; \
	(( $${#py[@]} == 0 )) || python3 -m py_compile "$${py[@]}"