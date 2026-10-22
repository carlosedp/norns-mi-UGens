// A stand-in for SuperCollider's SC_PlugIn.h, just big enough for the mi-UGens
// wrappers to compile unchanged into WebAssembly (see wasm/README.md) or into
// native shared libraries (see native/README.md).
//
// The real header describes scsynth's world; here a "unit" is driven by
// glue.cpp from its host (JavaScript, or a native program): the host fills the
// input buffers, calls next, and reads the outputs. Only what the wrappers
// touch is defined.
#pragma once

#include <algorithm>
#include <cmath>
#include <cstdarg>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <new>

typedef int32_t int32;
typedef uint32_t uint32;
typedef int16_t int16;
typedef uint16_t uint16;
typedef int8_t int8;
typedef uint8_t uint8;
typedef int64_t int64;
typedef uint64_t uint64;
typedef float float32;
typedef double float64;

// Same values as SC: wrappers compare INRATE() against these, and MiClouds
// switches on the plain numbers 1 and 2.
enum { calc_ScalarRate = 0, calc_BufRate = 1, calc_FullRate = 2, calc_DemandRate = 3 };

struct World {};

struct Unit;
typedef void (*UnitCalcFunc)(Unit* unit, int inNumSamples);
typedef void (*UnitCtorFunc)(Unit* unit);
typedef void (*UnitDtorFunc)(Unit* unit);

// A wrapper's struct derives from this, so its own fields follow these.
struct Unit {
    World* mWorld;
    uint32 mNumInputs, mNumOutputs;
    float** mInBuf;
    float** mOutBuf;
    int* mInRate;
    int mBufLength;
    double mSampleRate;
    UnitCalcFunc mCalcFunc;
};

void ClearUnitOutputs(Unit* unit, int inNumSamples);

struct InterfaceTable {
    void (*fClearUnitOutputs)(Unit* unit, int inNumSamples);
};

#define IN(index) (unit->mInBuf[index])
#define IN0(index) (unit->mInBuf[index][0])
#define OUT(index) (unit->mOutBuf[index])
#define OUT0(index) (unit->mOutBuf[index][0])
#define INRATE(index) (unit->mInRate[index])
#define BUFLENGTH (unit->mBufLength)
#define FULLBUFLENGTH (unit->mBufLength)
#define SAMPLERATE (unit->mSampleRate)
#define FULLRATE (unit->mSampleRate)
#define SAMPLEDUR (1.0 / unit->mSampleRate)
#define SETCALC(func) (unit->mCalcFunc = (UnitCalcFunc)(func))

inline void* RTAlloc(World*, size_t size) { return malloc(size); }
inline void RTFree(World*, void* ptr) { free(ptr); }

void Print(const char* fmt, ...);

inline void Copy(int n, float* dst, const float* src) {
    if (dst != src) memmove(dst, src, n * sizeof(float));
}
inline void Accum(int n, float* dst, const float* src) {
    for (int i = 0; i < n; ++i) dst[i] += src[i];
}

// Each wrapper is built into its own wasm module, so these name one unit.
void mi_register(size_t size, UnitCtorFunc ctor, UnitDtorFunc dtor);

#define PluginLoad(name) void mi_load_plugin(InterfaceTable* inTable)
#define DefineDtorUnit(name) \
    mi_register(sizeof(name), (UnitCtorFunc)&name##_Ctor, (UnitDtorFunc)&name##_Dtor)
#define DefineSimpleUnit(name) mi_register(sizeof(name), (UnitCtorFunc)&name##_Ctor, nullptr)
