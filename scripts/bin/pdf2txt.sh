#!/usr/bin/env bash
# shellcheck shell=bash
#
# pdf2txt - convert PDFs to text with pdftotext -layout, skipping
#           any whose .txt is already newer than the .pdf.
#
# usage: pdf2txt [-fv] [-o outdir] [srcdir]
#   -f         force reconversion of every PDF
#   -o outdir  output directory (default: srcdir/txt)
#   -v         report each file converted or skipped
#   srcdir     directory containing PDFs (default: .)

set -euo pipefail

prog=${0##*/}
outdir=
force=0
verbose=0

usage() {
    printf 'usage: %s [-fv] [-o outdir] [srcdir]\n' "$prog" >&2
    exit 2
}

log() {
    if [ "$verbose" -eq 1 ]; then
        printf '%s\n' "$*"
    fi
}

while getopts 'fo:v' opt; do
    case $opt in
        f) force=1 ;;
        o) outdir=$OPTARG ;;
        v) verbose=1 ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))
[ $# -le 1 ] || usage

srcdir=${1:-.}
outdir=${outdir:-$srcdir/txt}

if ! command -v pdftotext >/dev/null 2>&1; then
    printf '%s: pdftotext not found (dnf install poppler-utils)\n' "$prog" >&2
    exit 1
fi

mkdir -p -- "$outdir"

shopt -s nullglob
status=0

for pdf in "$srcdir"/*.pdf; do
    name=${pdf##*/}
    txt=$outdir/${name%.pdf}.txt

    if [ "$force" -eq 0 ] && [ "$txt" -nt "$pdf" ]; then
        log "skip    $name"
        continue
    fi

    log "convert $name"
    # Write to a temp file so a failed run never leaves a partial .txt
    # that looks up to date on the next pass.
    if pdftotext -layout "$pdf" "$txt.tmp"; then
        mv -f -- "$txt.tmp" "$txt"
    else
        rm -f -- "$txt.tmp"
        printf '%s: failed: %s\n' "$prog" "$pdf" >&2
        status=1
    fi
done

exit "$status"
