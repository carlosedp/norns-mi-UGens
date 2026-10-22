# mi-UGens as native libraries

Seven of Volker Böhm's [mi-UGens](https://github.com/v7b1/mi-UGens), built as plain shared
libraries for programs that aren't SuperCollider: an audio plugin, a standalone app, a test
harness. It's the same Mutable Instruments code a norns or any SuperCollider plays, and the same
code the [WebAssembly build](../wasm/README.md) runs in browsers, driven the same way.

| UGen       | Module                                     |
| ---------- | ------------------------------------------ |
| MiPlaits   | Plaits: macro oscillator                   |
| MiRings    | Rings: resonator                           |
| MiElements | Elements: bowed, blown and struck modeling |
| MiClouds   | Clouds: granular processor                 |
| MiBeads    | Beads: granular processor and reverb       |
| MiRipples  | Ripples: 4-pole filter                     |
| MiVerb     | the reverb from Clouds and Rings           |

One library per UGen (`MiPlaits.so`, `.dylib` or `.dll`, 20 KB to 600 KB), each exporting only a
small C API. No dependencies beyond the C library: libstdc++ and the MSVC runtime are linked in.

## Get it

Every [release](https://github.com/carlosedp/norns-mi-UGens/releases) carries one package per
platform: `mi-UGens-native-linux-x86_64.tar.gz`, `mi-UGens-native-macos-universal.tar.gz`
(x86_64 + arm64) and `mi-UGens-native-windows-x86_64.tar.gz`. Each unpacks to
`mi-UGens-native/`: `lib/` with the libraries, `mi_ugens.hpp` to load and run them, this README
and `BUILDINFO` (the mi-UGens commit it was built from).

Or build it for your machine (cmake and a C++17 compiler; on Windows, MSVC from Git Bash):

```
./build.sh --lib --pr 24     # PR 24 adds MiBeads
```

That fetches mi-UGens, builds, renders each UGen as a test (`mi-test`, WAVs in
`work/build-native/lib/wav/`) and packages `dist/mi-UGens-native-<os>-<arch>-<version>.tar.gz`.
To build into your own project instead, point CMake at this folder and a mi-UGens checkout:

```
cmake -S native -B build -DMI_SRC=work/mi-UGens -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release      # -> build/lib/
```

## Play one, in C++

`mi_ugens.hpp` is header-only (C++17, no dependencies). It loads a library and runs a unit the way
`mi-ugens.js` does in the browser, and scsynth on a norns: 64-sample blocks; inputs at scalar,
control or audio rate; control inputs held for a block; triggers high for one block; and lag on
control inputs like `.lag()`.

```cpp
#include "mi_ugens.hpp"

mi::Library plaits;
if (!plaits.open("lib/" + mi::libraryFile("MiPlaits"), "MiPlaits")) fail(plaits.error);

// inputs by name, with the defaults of the sclang class for the rest
mi::Unit voice(plaits, 48000, {
    {"engine", 12},                           // scalar: a constant, read when the unit starts
    {"trigger", 0, mi::Rate::Control},        // control: changes, read every block
    {"pitch", 60, mi::Rate::Control, 0.05f},  // with a 50 ms lag
});

voice.set("pitch", 55);
voice.trig("trigger");

float left[mi::BLOCK], right[mi::BLOCK];
float* out[] = {left, right};
voice.process(nullptr, nullptr, out);         // one block: audio ins, modulation, outs
```

The same rule as in a SynthDef matters here: a scalar input is a constant to the UGen, and some
treat a "patched" input differently (MiPlaits' `trigger` and `level`, MiRings' `trig` and `pit`,
MiBeads' `seed`). Only make an input control or audio rate if your graph really feeds it.

Effects take audio: MiRipples as an audio-rate `in` input, MiClouds, MiBeads and MiVerb as a
trailing pair of audio inputs, passed to `process` as an array of `BLOCK`-sample buffers (a null
entry is silence). `mi::Unit` isn't thread-safe: call `set`, `trig` and `process` from the audio
thread, or guard them. A `Library` must outlive its units.

Logs from a UGen go to stderr; `lib.mi_set_log(fn)` sends them elsewhere.

## The C API

For other languages, or to drive a unit by hand. It's [`wasm/glue.cpp`](../wasm/glue.cpp), the
same file the WebAssembly builds use:

```
void*  mi_new(double sampleRate, int bufLength, int numInputs, int numOutputs)
void   mi_set_rate(void* u, int input, int rate)     0 scalar, 1 control, 2 audio
float* mi_in(void* u, int input)                    write the initial values, then each block's
void   mi_init(void* u)                             runs the UGen's constructor
void   mi_next(void* u, int n)                      one block
float* mi_out(void* u, int output)
void   mi_alias(void* u, int output, int input)     MiVerb processes its inputs in place
void   mi_free(void* u)
void   mi_set_log(void (*log)(const char* msg))
```

Inputs come in the order of the sclang class (the table in `mi_ugens.hpp`, or `UGENS` in
`wasm/mi-ugens.js`). Control and scalar inputs only use element 0 of their buffer.

## How it's built

`native/CMakeLists.txt` adds mi-UGens' own CMake project with `SC_PATH` pointing at the stand-in
`SC_PlugIn.h` in `wasm/include`, so the wrappers compile unchanged, as for wasm. Each UGen's
target also gets `wasm/glue.cpp`, and everything but its C API is hidden. The UGens stay
separate libraries because their wrappers, and the Mutable Instruments code under them, would
clash if linked into one.

## License

The libraries are built from mi-UGens, which is GPL-3.0 (and includes Mutable Instruments' code,
MIT). A program that ships them distributes GPL-3.0 code: link to the source they were built from
(`BUILDINFO` names the exact repository, commit and pull requests) and keep the license notices.
