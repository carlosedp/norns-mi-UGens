#!/usr/bin/env bash
# Sanity-check built plugins: must be 32-bit ARM hard-float ELF and must not
# require symbol versions newer than what the norns image provides.
#
# Usage: verify.sh <plugin-dir> [max-glibc] [readelf]
set -euo pipefail

DIR=$1
MAX_GLIBC=${2:-2.28}   # Raspbian Buster
READELF=${3:-readelf}

ver_gt() { [[ $1 != "$2" && $(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1) == "$1" ]]; }

shopt -s nullglob
plugins=("$DIR"/*.so)
(( ${#plugins[@]} )) || { echo "verify: no .so files in $DIR" >&2; exit 1; }

fail=0
for so in "${plugins[@]}"; do
  name=$(basename "$so")
  if ! "$READELF" -h "$so" | grep -q 'Machine:.*ARM$'; then
    echo "FAIL $name: not a 32-bit ARM binary" >&2; fail=1; continue
  fi
  if ! "$READELF" -A "$so" | grep -q 'Tag_ABI_VFP_args: VFP registers'; then
    echo "FAIL $name: not hard-float ABI" >&2; fail=1; continue
  fi
  need=$("$READELF" -V "$so" | grep -o 'GLIBC_[0-9.]*' | sed 's/GLIBC_//' | sort -Vu | tail -1)
  if [[ -n $need ]] && ver_gt "$need" "$MAX_GLIBC"; then
    echo "FAIL $name: needs GLIBC_$need (norns has $MAX_GLIBC)" >&2; fail=1; continue
  fi
  printf 'ok   %-18s glibc>=%s  %s\n' "$name" "${need:-?}" "$(du -h "$so" | cut -f1)"
done
exit $fail
