#!/usr/bin/env bash
# Build mi-UGens (Mutable Instruments SuperCollider plugins) for monome norns.
#
# By default cross-compiles on any x86_64/arm64 Linux/macOS host inside a Debian
# Buster armhf toolchain container (podman or docker). With --native it builds
# with the local compiler instead, e.g. directly on a norns or Raspberry Pi.
#
# Run ./build.sh --help for options.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

REPO=https://github.com/v7b1/mi-UGens
REF=main
PR_REMOTE=https://github.com/v7b1/mi-UGens
PRS=()
SC_VERSION=Version-3.12.2
WORK=$HERE/work
DIST=$HERE/dist
NATIVE=0
JOBS=
IMAGE=norns-mi-ugens-builder
ENGINE=${CONTAINER_ENGINE:-}

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Source selection:
  --repo URL         mi-UGens git repository        (default: $REPO)
  --ref REF          branch, tag or commit to build (default: $REF)
  --pr N             merge GitHub pull request N on top of REF (repeatable)
                     e.g. --pr 24 adds MiBeads
  --pr-remote URL    repository the PR numbers refer to (default: $PR_REMOTE)
  --sc-version TAG   SuperCollider tag for plugin headers (default: $SC_VERSION)
                     check yours on norns with: scsynth -v

Build:
  --native           build with the local toolchain (on a norns / Pi) instead
                     of the cross-compile container
  --jobs N           parallel build jobs (default: all cores)
  --engine NAME      container engine: podman or docker (default: auto)
  --work DIR         scratch dir for sources and build tree (default: ./work)
  --dist DIR         output dir for the tarball (default: ./dist)
  -h, --help         show this help

Output: \$DIST/mi-UGens-norns-<version>.tar.gz containing a mi-UGens/ folder to
copy into ~/.local/share/SuperCollider/Extensions/ on norns (see deploy.sh).
EOF
}

while (($#)); do
  case $1 in
    --repo) REPO=$2; shift ;;
    --ref) REF=$2; shift ;;
    --pr) PRS+=("$2"); shift ;;
    --pr-remote) PR_REMOTE=$2; shift ;;
    --sc-version) SC_VERSION=$2; shift ;;
    --native) NATIVE=1 ;;
    --jobs) JOBS=$2; shift ;;
    --engine) ENGINE=$2; shift ;;
    --work) WORK=$(mkdir -p "$2" && cd "$2" && pwd); shift ;;
    --dist) DIST=$2; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

SRC=$WORK/mi-UGens
SC_SRC=$WORK/supercollider-$SC_VERSION
mkdir -p "$WORK" "$DIST"

# --- sources -----------------------------------------------------------------

log "Fetching mi-UGens from $REPO ($REF)"
[[ -d $SRC/.git ]] || git clone --quiet "$REPO" "$SRC"
git -C "$SRC" remote set-url origin "$REPO"
git -C "$SRC" fetch --quiet --tags origin "$REF"
git -C "$SRC" checkout --quiet --force -B norns-build FETCH_HEAD
git -C "$SRC" clean -fdxq

# Throwaway local identity for the PR merge commits; nothing is pushed.
merge_git=(git -C "$SRC" -c user.name=norns-build -c user.email=norns-build@localhost)
for pr in "${PRS[@]}"; do
  log "Merging PR #$pr from $PR_REMOTE"
  git -C "$SRC" fetch --quiet "$PR_REMOTE" "pull/$pr/head"
  "${merge_git[@]}" merge --quiet --no-edit -m "Merge PR #$pr" FETCH_HEAD
done
git -C "$SRC" submodule update --quiet --init --recursive

if [[ ! -d $SC_SRC ]]; then
  log "Fetching SuperCollider headers ($SC_VERSION)"
  git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$SC_VERSION" \
    https://github.com/supercollider/supercollider "$SC_SRC"
fi

VERSION=$(git -C "$SRC" describe --tags --always)
((${#PRS[@]})) && VERSION+=$(printf -- '-pr%s' "${PRS[@]}")

# --- build -------------------------------------------------------------------

rm -rf "$WORK/out"

if ((NATIVE)); then
  log "Building natively ($(uname -m))"
  "$HERE/scripts/compile.sh" "$SRC" "$SC_SRC" "$WORK/build" "$WORK/out" "" "${JOBS:-$(nproc)}"
  "$HERE/scripts/verify.sh" "$WORK/out/mi-UGens"
else
  if [[ -z $ENGINE ]]; then
    if command -v podman >/dev/null; then ENGINE=podman
    elif command -v docker >/dev/null; then ENGINE=docker
    else echo "need podman or docker (or use --native)" >&2; exit 1
    fi
  fi

  log "Preparing build image ($ENGINE)"
  "$ENGINE" build --quiet -t "$IMAGE" -f "$HERE/Containerfile" "$HERE" >/dev/null

  # Keep output files owned by the calling user.
  if [[ $ENGINE == podman ]]; then user_args=(--userns=keep-id)
  else user_args=(--user "$(id -u):$(id -g)")
  fi

  log "Cross-compiling for norns (armhf)"
  "$ENGINE" run --rm "${user_args[@]}" \
    -v "$WORK:/work" -v "$HERE/scripts:/scripts:ro" "$IMAGE" bash -c "
      set -e
      /scripts/compile.sh /work/mi-UGens /work/$(basename "$SC_SRC") /work/build /work/out \
        /opt/toolchain-norns.cmake ${JOBS:-\$(nproc)}
      /scripts/verify.sh /work/out/mi-UGens 2.28 arm-linux-gnueabihf-readelf"
fi

# --- package -----------------------------------------------------------------

cat > "$WORK/out/mi-UGens/BUILDINFO" <<EOF
repo:       $REPO
ref:        $REF
commit:     $(git -C "$SRC" rev-parse HEAD)
prs:        ${PRS[*]:-none}
sc headers: $SC_VERSION
built:      $(date -u +%Y-%m-%dT%H:%M:%SZ) ($([[ $NATIVE == 1 ]] && echo native || echo cross armhf))
EOF

install -m 755 "$HERE/scripts/install.sh" "$WORK/out/install.sh"
TARBALL=$DIST/mi-UGens-norns-$VERSION.tar.gz
tar -C "$WORK/out" -czf "$TARBALL" mi-UGens install.sh

log "Done"
echo "Plugins: $(cd "$WORK/out/mi-UGens" && ls *.so | sed 's/\.so$//' | tr '\n' ' ')"
echo "Package: $TARBALL"
echo "Install: ./deploy.sh $TARBALL [we@norns.local]"
