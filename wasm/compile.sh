#!/usr/bin/env bash
# Build mi-UGens as WebAssembly, one standalone .wasm per UGen. Runs inside the
# emscripten/emsdk container (see build.sh --wasm).
#
# mi-UGens' own CMake files supply the source lists; SC_PATH points at the
# stand-in SC_PlugIn.h in wasm/include, so the wrappers compile unchanged.
# Emscripten has no shared libraries, so each MODULE target becomes a static
# library, which is then linked with glue.cpp.
#
# Usage: compile.sh <mi-ugens-src> <wasm-dir> <build-dir> <out-dir> [jobs] [ugens...]
set -euo pipefail

SRC=$1
SHIM=$2
BUILD=$3
OUT=$4
JOBS=${5:-$(nproc)}
shift 5 || shift $#
UGENS=("$@")
((${#UGENS[@]})) || UGENS=(MiPlaits MiRings MiRipples MiClouds MiBeads MiVerb MiElements)

rm -rf "$BUILD" "$OUT"
mkdir -p "$BUILD" "$OUT"

# Ripples includes VCV Rack's SSE vector code; emscripten maps SSE to wasm SIMD.
emcmake cmake -S "$SRC" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release -DSC_PATH="$SHIM" \
  -DCMAKE_CXX_FLAGS="-msimd128 -msse4.1" -DCMAKE_C_FLAGS="-msimd128" >/dev/null
cmake --build "$BUILD" -j "$JOBS" --target "${UGENS[@]}"

for u in "${UGENS[@]}"; do
  lib=$(find "$BUILD/projects/$u" -maxdepth 1 -name "*$u.a" | head -1)
  [[ -n $lib ]] || { echo "no static library for $u" >&2; exit 1; }
  # mi_log is left undefined on purpose: it becomes an import the host supplies.
  em++ -O3 -std=c++17 -msimd128 -I "$SHIM/include/plugin_interface" "$SHIM/glue.cpp" \
    -Wl,--whole-archive "$lib" -Wl,--no-whole-archive \
    --no-entry -sSTANDALONE_WASM -sFILESYSTEM=0 -sALLOW_MEMORY_GROWTH=1 \
    -sINITIAL_MEMORY=4194304 -sSTACK_SIZE=1048576 -sERROR_ON_UNDEFINED_SYMBOLS=0 \
    -o "$OUT/$u.wasm"
  printf 'ok   %-12s %s\n' "$u" "$(du -h "$OUT/$u.wasm" | cut -f1)"
done

# the browser side, so the out dir is a working page (demo.html) as it is
cp "$SHIM/mi-ugens.js" "$SHIM/mi-ugens-node.js" "$SHIM/demo.html" "$OUT/"
