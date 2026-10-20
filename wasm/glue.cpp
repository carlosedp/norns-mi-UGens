// The C API a wasm build of one mi-UGen exports to JavaScript.
//
//   u = mi_new(sampleRate, bufLength, numInputs, numOutputs)
//   mi_set_rate(u, i, rate)   per input: 0 scalar, 1 control, 2 audio (as INRATE)
//   write initial values into mi_in(u, i)   (scalar inputs are read by the Ctor)
//   mi_init(u)                runs the wrapper's Ctor
//   per block: fill mi_in(u, i), mi_next(u, n), read mi_out(u, i)
//   mi_free(u)
//
// Every input and output gets a bufLength buffer, whatever its rate; control
// and scalar inputs only use element 0, as in scsynth.
#include "SC_PlugIn.h"

#define EXPORT extern "C" __attribute__((used, visibility("default")))

extern "C" void mi_log(const char* msg);  // provided by the host

static size_t g_size;
static UnitCtorFunc g_ctor;
static UnitDtorFunc g_dtor;
static InterfaceTable g_table = {ClearUnitOutputs};
static World g_world;
static bool g_loaded;

void mi_load_plugin(InterfaceTable* inTable);

void mi_register(size_t size, UnitCtorFunc ctor, UnitDtorFunc dtor) {
    g_size = size;
    g_ctor = ctor;
    g_dtor = dtor;
}

void ClearUnitOutputs(Unit* unit, int inNumSamples) {
    if (!unit) return;
    for (uint32 i = 0; i < unit->mNumOutputs; ++i)
        memset(unit->mOutBuf[i], 0, inNumSamples * sizeof(float));
}

void Print(const char* fmt, ...) {
    char buf[256];
    va_list args;
    va_start(args, fmt);
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    mi_log(buf);
}

struct Buffers {
    float** in;
    float** out;
    float** own_out;  // what to free: out[i] may be aliased to an input
};

EXPORT Unit* mi_new(double sample_rate, int buf_length, int num_inputs, int num_outputs) {
    if (!g_loaded) {
        mi_load_plugin(&g_table);
        g_loaded = true;
    }
    // Room for the Buffers record after the wrapper's struct.
    size_t base = (g_size + 15) & ~size_t(15);
    char* mem = (char*)calloc(1, base + sizeof(Buffers));
    if (!mem) return nullptr;
    Unit* unit = (Unit*)mem;
    Buffers* b = (Buffers*)(mem + base);
    unit->mWorld = &g_world;
    unit->mNumInputs = num_inputs;
    unit->mNumOutputs = num_outputs;
    unit->mBufLength = buf_length;
    unit->mSampleRate = sample_rate;
    unit->mInRate = (int*)calloc(num_inputs + 1, sizeof(int));
    // One spare input buffer: MiClouds reads input n+1 when given one channel.
    b->in = (float**)calloc(num_inputs + 1, sizeof(float*));
    for (int i = 0; i <= num_inputs; ++i) b->in[i] = (float*)calloc(buf_length, sizeof(float));
    b->out = (float**)calloc(num_outputs, sizeof(float*));
    b->own_out = (float**)calloc(num_outputs, sizeof(float*));
    for (int i = 0; i < num_outputs; ++i) b->out[i] = b->own_out[i] = (float*)calloc(buf_length, sizeof(float));
    unit->mInBuf = b->in;
    unit->mOutBuf = b->out;
    return unit;
}

EXPORT void mi_set_rate(Unit* unit, int index, int rate) { unit->mInRate[index] = rate; }

EXPORT float* mi_in(Unit* unit, int index) { return unit->mInBuf[index]; }
EXPORT float* mi_out(Unit* unit, int index) { return unit->mOutBuf[index]; }

// scsynth may give an output the same wire buffer as an input; MiVerb relies on
// that, processing its audio inputs in place.
EXPORT void mi_alias(Unit* unit, int out_index, int in_index) {
    unit->mOutBuf[out_index] = unit->mInBuf[in_index];
}

EXPORT void mi_init(Unit* unit) {
    if (g_ctor) g_ctor(unit);
}

EXPORT void mi_next(Unit* unit, int n) {
    if (unit->mCalcFunc) unit->mCalcFunc(unit, n);
    else ClearUnitOutputs(unit, n);
}

EXPORT void mi_free(Unit* unit) {
    if (!unit) return;
    if (g_dtor && unit->mCalcFunc) g_dtor(unit);
    size_t base = (g_size + 15) & ~size_t(15);
    Buffers* b = (Buffers*)((char*)unit + base);
    for (uint32 i = 0; i <= unit->mNumInputs; ++i) free(b->in[i]);
    for (uint32 i = 0; i < unit->mNumOutputs; ++i) free(b->own_out[i]);
    free(b->in);
    free(b->out);
    free(b->own_out);
    free(unit->mInRate);
    free(unit);
}
