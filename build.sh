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
WASM=0
LIB=0
EMSDK_IMAGE=docker.io/emscripten/emsdk:4.0.10
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
  --wasm             build WebAssembly for browsers instead (see wasm/README.md),
                     in the $EMSDK_IMAGE container
  --lib              build native shared libraries for this machine instead, for
                     programs that aren't SuperCollider (see native/README.md):
                     Linux, macOS (universal) or Windows (Visual Studio with its
                     clang-cl, from Git Bash); needs cmake and a C++17 compiler
  --jobs N           parallel build jobs (default: all cores)
  --engine NAME      container engine: podman or docker (default: auto)
  --work DIR         scratch dir for sources and build tree (default: ./work)
  --dist DIR         output dir for the tarball (default: ./dist)
  -h, --help         show this help

Output: \$DIST/mi-UGens-norns-<version>.tar.gz containing a mi-UGens/ folder to
copy into ~/.local/share/SuperCollider/Extensions/ on norns (see deploy.sh).
With --wasm: \$DIST/mi-UGens-wasm-<version>.tar.gz, a mi-UGens-wasm/ folder of
.wasm files and the JavaScript that runs them (demo.html plays them).
With --lib: \$DIST/mi-UGens-native-<os>-<arch>-<version>.tar.gz, a mi-UGens-native/
folder with lib/ (one library per UGen) and mi_ugens.hpp, the header that loads them.
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
    --wasm) WASM=1 ;;
    --lib) LIB=1 ;;
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
cores() { nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4; }

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

if [[ ! -d $SC_SRC ]] && ((!LIB)); then  # --lib uses the stand-in headers only
  log "Fetching SuperCollider headers ($SC_VERSION)"
  git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$SC_VERSION" \
    https://github.com/supercollider/supercollider "$SC_SRC"
fi

VERSION=$(git -C "$SRC" describe --tags --always)
((${#PRS[@]})) && VERSION+=$(printf -- '-pr%s' "${PRS[@]}")

# --- build -------------------------------------------------------------------

pick_engine() {
  if [[ -z $ENGINE ]]; then
    if command -v podman >/dev/null; then ENGINE=podman
    elif command -v docker >/dev/null; then ENGINE=docker
    else echo "need podman or docker (or use --native)" >&2; exit 1
    fi
  fi
  # Keep output files owned by the calling user.
  if [[ $ENGINE == podman ]]; then user_args=(--userns=keep-id)
  else user_args=(--user "$(id -u):$(id -g)")
  fi
}

if ((WASM)); then
  pick_engine
  OUT=$WORK/out-wasm
  log "Building WebAssembly ($EMSDK_IMAGE)"
  "$ENGINE" run --rm "${user_args[@]}" -v "$WORK:/work" -v "$HERE/wasm:/wasm:ro" "$EMSDK_IMAGE" \
    /wasm/compile.sh /work/mi-UGens /wasm /work/build-wasm /work/out-wasm "${JOBS:-$(cores)}"
  log "Testing (node)"
  node "$HERE/wasm/test.mjs" "$OUT"
  rm -rf "$OUT/wav"
  cat > "$OUT/BUILDINFO" <<EOF
repo:       $REPO
ref:        $REF
commit:     $(git -C "$SRC" rev-parse HEAD)
prs:        ${PRS[*]:-none}
wrapper:    norns-mi-UGens $(git -C "$HERE" describe --tags --always --dirty) (wasm/)
built:      $(date -u +%Y-%m-%dT%H:%M:%SZ) (wasm, $EMSDK_IMAGE)
EOF
  TARBALL=$DIST/mi-UGens-wasm-$VERSION.tar.gz
  rm -rf "$WORK/pkg-wasm" && mkdir -p "$WORK/pkg-wasm" && cp -r "$OUT" "$WORK/pkg-wasm/mi-UGens-wasm"
  tar -C "$WORK/pkg-wasm" -czf "$TARBALL" mi-UGens-wasm
  log "Done"
  echo "Files:   $OUT"
  echo "Package: $TARBALL"
  echo "Try it:  (cd $OUT && python3 -m http.server 8000), then open http://localhost:8000/demo.html"
  exit 0
fi

if ((LIB)); then
  case $(uname -s) in
    Linux) OS=linux; ARCH=$(uname -m) ;;
    Darwin) OS=macos; ARCH=universal ;;
    MINGW*|MSYS*|CYGWIN*) OS=windows; ARCH=x86_64 ;;
    *) echo "--lib: unknown system $(uname -s)" >&2; exit 1 ;;
  esac
  BUILD=$WORK/build-native
  PKG=$WORK/out-native
  OUT=$PKG/mi-UGens-native
  log "Building native libraries ($OS-$ARCH)"
  rm -rf "$BUILD" "$PKG"
  gen=()
  [[ $OS == windows ]] && gen=(-T ClangCL)  # clang-cl: MiRipples' VCV Rack code is GCC/clang only
  cmake -S "$HERE/native" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release -DMI_SRC="$SRC" ${gen[@]+"${gen[@]}"} >/dev/null
  cmake --build "$BUILD" --config Release -j "${JOBS:-$(cores)}"
  log "Testing"
  "$BUILD/mi-test" "$BUILD/lib"
  mkdir -p "$OUT/lib"
  for f in "$BUILD"/lib/Mi*; do
    case $f in *.so|*.dylib|*.dll) cp "$f" "$OUT/lib/" ;; esac
  done
  cp "$HERE/native/mi_ugens.hpp" "$HERE/native/README.md" "$OUT/"
  cat > "$OUT/BUILDINFO" <<EOF
repo:       $REPO
ref:        $REF
commit:     $(git -C "$SRC" rev-parse HEAD)
prs:        ${PRS[*]:-none}
wrapper:    norns-mi-UGens $(git -C "$HERE" describe --tags --always --dirty) (native/)
built:      $(date -u +%Y-%m-%dT%H:%M:%SZ) ($OS-$ARCH)
EOF
  TARBALL=$DIST/mi-UGens-native-$OS-$ARCH-$VERSION.tar.gz
  tar -C "$PKG" -czf "$TARBALL" mi-UGens-native
  log "Done"
  echo "Libraries: $(cd "$OUT/lib" && ls | tr '\n' ' ')"
  echo "Package:   $TARBALL"
  exit 0
fi

rm -rf "$WORK/out"

if ((NATIVE)); then
  log "Building natively ($(uname -m))"
  "$HERE/scripts/compile.sh" "$SRC" "$SC_SRC" "$WORK/build" "$WORK/out" "" "${JOBS:-$(cores)}"
  "$HERE/scripts/verify.sh" "$WORK/out/mi-UGens"
else
  pick_engine
  log "Preparing build image ($ENGINE)"
  "$ENGINE" build --quiet -t "$IMAGE" -f "$HERE/Containerfile" "$HERE" >/dev/null

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
