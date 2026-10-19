#!/usr/bin/env bash
# Install a mi-UGens norns build onto a norns over ssh.
#
# Usage: deploy.sh <mi-UGens-norns-*.tar.gz> [user@host]   (default host: we@norns.local)
#
# The tarball carries install.sh (scripts/install.sh), which moves older
# mi-UGens installs aside and copies the new one into Extensions.
set -euo pipefail

TARBALL=${1:?usage: deploy.sh <tarball> [user@host]}
HOST=${2:-we@norns.local}
[[ -f $TARBALL ]] || { echo "no such file: $TARBALL" >&2; exit 1; }

echo "Installing $(basename "$TARBALL") to $HOST"

# One ssh connection: the tarball goes over stdin, unpacks to a temp dir and
# its own install.sh does the rest.
# shellcheck disable=SC2016  # expanded on the norns side
ssh "$HOST" 'set -e; d=$(mktemp -d); trap "rm -rf $d" EXIT
  tar -C "$d" -xzf -; bash "$d/install.sh" "$d/mi-UGens"' <"$TARBALL"

echo "Done. Restart norns (SYSTEM > RESTART) to load the new UGens."
