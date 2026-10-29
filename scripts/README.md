# scripts

Personal utility scripts for `seans-workstation` (Fedora 44).

Scripts live in `bin/` and are symlinked into `~/.local/bin` with the extension
stripped (`bin/system-clean.sh` → `~/.local/bin/system-clean`). Edits take
effect immediately; re-run `make install` only after adding, renaming, or
removing a script.

## Usage

| Command          | Action                                                         |
| ---------------- | -------------------------------------------------------------- |
| `make install`   | Link `bin/*.sh` and `bin/*.py`; prune links to deleted scripts |
| `make uninstall` | Remove every link in `~/.local/bin` that points into this repo |
| `make list`      | Show `installed` / `missing` / `conflict` per script           |
| `make check`     | `shellcheck -x` all `.sh`, `py_compile` all `.py`              |

Add `V=1` for per-file output. `PREFIX=` overrides `~/.local`.

`install` refuses to overwrite anything in `~/.local/bin` it doesn't own, and
fails if two scripts would map to the same command name.

## Conventions

- Bash: `#!/usr/bin/env bash`, `# shellcheck shell=bash`, `set -euo pipefail`,
  must pass `make check`
- Quiet by default; verbose output behind `-v`; errors to stderr
- Every script supports `-h`/`--help`