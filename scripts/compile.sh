#!/usr/bin/env bash
# Configure, build and install mi-UGens. Runs inside the cross container, or
# natively on a norns / Raspberry Pi (pass an empty toolchain argument).
#
# Usage: compile.sh <mi-ugens-src> <sc-src> <build-dir> <install-dir> [toolchain-file] [jobs]
set -euo pipefail

SRC=$1
SC_SRC=$2
BUILD=$3
PREFIX=$4
TOOLCHAIN=${5:-}
JOBS=${6:-$(nproc)}

# The libsamplerate submodule is configured with an in-source binary dir
# (projects/MiBraids/libsamplerate/build) and MiBraids links the .a by path.
# Wipe it so a stale host-arch build can never get linked into the ARM plugin.
rm -rf "$SRC/projects/MiBraids/libsamplerate/build" "$BUILD"
mkdir -p "$BUILD"

cmake_args=(
  -S "$SRC" -B "$BUILD"
  -DCMAKE_BUILD_TYPE=Release
  -DSC_PATH="$SC_SRC"
  -DCMAKE_INSTALL_PREFIX="$PREFIX"
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
)
[[ -n $TOOLCHAIN ]] && cmake_args+=(-DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN")

cmake "${cmake_args[@]}"

# MiBraids links libsamplerate.a by file path rather than by target, so there is
# no dependency edge; build it first so parallel builds don't race.
cmake --build "$BUILD" --target samplerate -j "$JOBS"
cmake --build "$BUILD" -j "$JOBS"
cmake --install "$BUILD" --strip
