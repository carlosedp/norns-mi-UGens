#!/usr/bin/env bash
# Install an unpacked mi-UGens build into SuperCollider Extensions on norns.
# Shipped inside the release tarball and used by deploy.sh and the on-device
# installer script, so all three install paths behave the same.
#
# Usage: install.sh <path/to/unpacked/mi-UGens>
#
# Older mi-UGens installs found in Extensions (okyeron's per-module folders,
# schollz's bundle, a previous build) are moved to ~/mi-UGens-backup-<date>,
# since duplicate class files stop sclang from compiling the class library
# and norns won't start its audio engine.
set -euo pipefail

NEW=${1:?usage: install.sh <unpacked mi-UGens dir>}
[[ -d $NEW && -n $(find "$NEW" -maxdepth 1 -name 'Mi*.so' -print -quit) ]] \
  || { echo "install: $NEW does not look like a mi-UGens build" >&2; exit 1; }

EXT=$HOME/.local/share/SuperCollider/Extensions
BACKUP=$HOME/mi-UGens-backup-$(date +%Y%m%d-%H%M%S)
mkdir -p "$EXT"

# For each mi-UGens class file, climb to the highest folder below Extensions
# that holds nothing but mi-UGens classes, so a bundle like schollz's
# supercollider-plugins only loses its mi-UGens subfolder.
MI_RE='/Mi(Beads|Braids|Clouds|Elements|Grids|Mu|Omi|Plaits|Rings|Ripples|Tides|Verb|Warps)\.sc$'
only_mi() { ! find "$1" -name '*.sc' | grep -qvE "$MI_RE"; }
{ find "$EXT" -name '*.sc' 2>/dev/null | grep -E "$MI_RE" || true; } | while read -r sc; do
  [[ -e $sc ]] || continue   # already moved with an earlier match
  dir=$(dirname "$sc")
  while [[ $(dirname "$dir") != "$EXT" ]] && only_mi "$(dirname "$dir")"; do
    dir=$(dirname "$dir")
  done
  mkdir -p "$BACKUP"
  echo "moving old install ${dir#$HOME/} -> ${BACKUP#$HOME/}/"
  mv "$dir" "$BACKUP/$(echo "${dir#$EXT/}" | tr / _)"
done

cp -r "$NEW" "$EXT/mi-UGens"
echo "installed: $(ls "$EXT/mi-UGens"/*.so | xargs -n1 basename | sed 's/\.so$//' | tr '\n' ' ')"

# Scripts in dust can bundle their own copies of the classes; warn about those.
dups=$(find "$HOME/dust" -name '*.sc' 2>/dev/null | grep -E "$MI_RE" || true)
if [[ -n $dups ]]; then
  echo "WARNING: these class files in dust duplicate mi-UGens and may break sclang:"
  echo "$dups" | sed 's/^/  /'
fi
