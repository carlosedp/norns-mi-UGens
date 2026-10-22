// mi-UGens in native programs: loads the shared libraries native/ builds (one
// per UGen) and runs units the way wasm/mi-ugens.js does in the browser. Header
// only, no dependencies; C++17.
//
//   mi::Library lib;                        // a loaded MiPlaits.so / .dylib / .dll
//   lib.open("lib/MiPlaits.so", "MiPlaits")  // false, with lib.error, if it can't
//   mi::Unit u(lib, 48000, {{"engine", 12}, {"trigger", 0, mi::Rate::Control}});
//   u.set("pitch", 55); u.trig("trigger");
//   per 64 samples: u.process(audioIns, mods, outs)
//
// The unit runs as scsynth would run it: 64-sample blocks, inputs at scalar,
// control or audio rate (the wrappers check which), control inputs held for a
// block, triggers high for one block, and lag on control inputs like .lag().
// Not thread-safe: set/trig/process from the audio thread, or guard them.
#pragma once

#include <cmath>
#include <cstring>
#include <string>
#include <utility>
#include <vector>

#if defined(_WIN32)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#else
#include <dlfcn.h>
#endif

namespace mi {

constexpr int BLOCK = 64;
enum class Rate { Scalar = 0, Control = 1, Audio = 2 };

// Inputs in UGen order, with the defaults of the sclang classes (sc/Classes);
// the same table as UGENS in wasm/mi-ugens.js. audio: how many trailing audio
// inputs (the input array); alias: outputs share the audio inputs' buffers.
struct Def {
    const char* name;
    int outputs, audio;
    bool alias;
    std::vector<std::pair<const char*, float>> inputs;
};

inline const std::vector<Def>& ugens() {
    static const std::vector<Def> defs = {
        {"MiPlaits", 2, 0, false,
         {{"pitch", 60}, {"engine", 0}, {"harm", 0.1f}, {"timbre", 0.5f}, {"morph", 0.5f}, {"trigger", 0},
          {"level", 0}, {"fm_mod", 0}, {"timb_mod", 0}, {"morph_mod", 0}, {"decay", 0.5f}, {"lpg_colour", 0.5f}}},
        {"MiRings", 2, 0, false,
         {{"in", 0}, {"trig", 0}, {"pit", 60}, {"struct", 0.25f}, {"bright", 0.5f}, {"damp", 0.7f}, {"pos", 0.25f},
          {"model", 0}, {"poly", 1}, {"intern_exciter", 0}, {"easteregg", 0}, {"bypass", 0}}},
        {"MiRipples", 1, 0, false, {{"in", 0}, {"cf", 0.3f}, {"reson", 0.2f}, {"drive", 1}}},
        {"MiClouds", 2, 2, false,
         {{"pit", 0}, {"pos", 0.5f}, {"size", 0.25f}, {"dens", 0.4f}, {"tex", 0.5f}, {"drywet", 0.5f},
          {"in_gain", 1}, {"spread", 0.5f}, {"rvb", 0}, {"fb", 0}, {"freeze", 0}, {"mode", 0}, {"lofi", 0},
          {"trig", 0}}},
        {"MiBeads", 2, 2, false,
         {{"pitch", 0}, {"pitch_rnd", 0}, {"time", 0.5f}, {"time_rnd", 0}, {"size", 0.5f}, {"size_rnd", 0},
          {"shape", 0.5f}, {"shape_rnd", 0}, {"density", 0.7f}, {"fb", 0}, {"drywet", 0.5f}, {"rvb", 0},
          {"freeze", 0}, {"seed", 0}, {"seed_btn", 2}, {"quality", 0}, {"in_gain", 1}, {"synth", 0}}},
        {"MiVerb", 2, 2, true,
         {{"time", 0.7f}, {"drywet", 0.5f}, {"damp", 0.5f}, {"hp", 0.05f}, {"freeze", 0}, {"diff", 0.625f}}},
        {"MiElements", 2, 0, false,
         {{"blow_in", 0}, {"strike_in", 0}, {"gate", 0}, {"pit", 48}, {"strength", 0.5f}, {"contour", 0.2f},
          {"bow_level", 0}, {"blow_level", 0}, {"strike_level", 0}, {"flow", 0.5f}, {"mallet", 0.5f},
          {"bow_timb", 0.5f}, {"blow_timb", 0.5f}, {"strike_timb", 0.5f}, {"geom", 0.25f}, {"bright", 0.5f},
          {"damp", 0.7f}, {"pos", 0.2f}, {"space", 0.3f}, {"model", 0}, {"easteregg", 0}}},
    };
    return defs;
}

inline const Def* findDef(const std::string& name) {
    for (auto& d : ugens())
        if (name == d.name) return &d;
    return nullptr;
}

// The file name a UGen's library has on this platform: MiPlaits.so, .dylib or .dll
inline std::string libraryFile(const std::string& ugen) {
#if defined(_WIN32)
    return ugen + ".dll";
#elif defined(__APPLE__)
    return ugen + ".dylib";
#else
    return ugen + ".so";
#endif
}

// One UGen's library and its C API (wasm/glue.cpp). Units keep a pointer to it,
// so it must outlive them.
class Library {
public:
    using LogFunc = void (*)(const char*);
    std::string name, error;
    const Def* def = nullptr;

    void* (*mi_new)(double, int, int, int) = nullptr;
    void (*mi_set_rate)(void*, int, int) = nullptr;
    float* (*mi_in)(void*, int) = nullptr;
    float* (*mi_out)(void*, int) = nullptr;
    void (*mi_alias)(void*, int, int) = nullptr;
    void (*mi_init)(void*) = nullptr;
    void (*mi_next)(void*, int) = nullptr;
    void (*mi_free)(void*) = nullptr;
    void (*mi_set_log)(LogFunc) = nullptr;

    Library() = default;
    Library(const Library&) = delete;
    Library& operator=(const Library&) = delete;
    ~Library() { close(); }

    bool open(const std::string& path, const std::string& ugen) {
        close();
        name = ugen;
        def = findDef(ugen);
        if (!def) return fail("unknown UGen " + ugen);
#if defined(_WIN32)
        handle_ = (void*)LoadLibraryA(path.c_str());
        if (!handle_) return fail("can't load " + path);
#else
        handle_ = dlopen(path.c_str(), RTLD_NOW | RTLD_LOCAL);
        if (!handle_) return fail(dlerror());
#endif
        bool ok = sym(mi_new, "mi_new") && sym(mi_set_rate, "mi_set_rate") && sym(mi_in, "mi_in") &&
                  sym(mi_out, "mi_out") && sym(mi_alias, "mi_alias") && sym(mi_init, "mi_init") &&
                  sym(mi_next, "mi_next") && sym(mi_free, "mi_free") && sym(mi_set_log, "mi_set_log");
        if (!ok) {
            close();
            return fail(path + " is not a mi-UGens native library");
        }
        return true;
    }

    bool loaded() const { return handle_ != nullptr; }

    void close() {
        if (!handle_) return;
#if defined(_WIN32)
        FreeLibrary((HMODULE)handle_);
#else
        dlclose(handle_);
#endif
        handle_ = nullptr;
    }

private:
    void* handle_ = nullptr;

    bool fail(std::string msg) {
        error = std::move(msg);
        return false;
    }

    template <typename F>
    bool sym(F& f, const char* s) {
#if defined(_WIN32)
        f = reinterpret_cast<F>(GetProcAddress((HMODULE)handle_, s));
#else
        f = reinterpret_cast<F>(dlsym(handle_, s));
#endif
        return f != nullptr;
    }
};

// How one input is fed: its value, its rate (scalar unless the SynthDef feeds
// it a control or a signal: some UGens treat "patched" inputs differently), a
// lag in seconds, and a modulation channel added to it (-1 for none).
struct Spec {
    std::string name;
    float value = 0;
    Rate rate = Rate::Scalar;
    float lag = 0;
    int mod = -1;
    Spec(std::string n, float v, Rate r = Rate::Scalar, float l = 0, int m = -1)
        : name(std::move(n)), value(v), rate(r), lag(l), mod(m) {}
};

class Unit {
public:
    // nAudio: how many trailing audio inputs (-1: the UGen's own count)
    Unit(Library& lib, double sampleRate, const std::vector<Spec>& spec = {}, int nAudio = -1)
        : lib_(lib), ctrlRate_(sampleRate / BLOCK) {
        const Def& def = *lib.def;
        int na = def.audio ? (nAudio < 0 ? def.audio : nAudio) : 0;
        nIn_ = (int)def.inputs.size() + na;
        u_ = lib.mi_new(sampleRate, BLOCK, nIn_, def.outputs);
        for (int i = 0; i < (int)def.inputs.size(); ++i) {
            Input in;
            in.name = def.inputs[i].first;
            in.index = i;
            in.value = in.target = def.inputs[i].second;
            float lag = 0;
            for (auto& s : spec)
                if (s.name == in.name) {
                    in.value = in.target = s.value;
                    in.rate = s.rate;
                    in.mod = s.mod;
                    lag = s.lag;
                }
            inputs_.push_back(in);
            setLag(in.name, lag);
            lib.mi_set_rate(u_, i, (int)in.rate);
            if (in.rate == Rate::Audio) audioIns_.push_back(i);
        }
        for (int k = 0; k < na; ++k) {
            int index = (int)def.inputs.size() + k;
            lib.mi_set_rate(u_, index, (int)Rate::Audio);
            audioIns_.push_back(index);
            if (def.alias && k < def.outputs) lib.mi_alias(u_, k, index);
        }
        // scalar inputs are read by the Ctor, so they must be in place before it
        for (auto& in : inputs_) lib.mi_in(u_, in.index)[0] = in.value;
        lib.mi_init(u_);
    }

    Unit(const Unit&) = delete;
    Unit& operator=(const Unit&) = delete;
    ~Unit() {
        if (u_) lib_.mi_free(u_);
    }

    int outputs() const { return lib_.def->outputs; }
    int audioInputs() const { return (int)audioIns_.size(); }

    void set(const std::string& name, float value) {
        if (Input* in = find(name)) {
            in->target = value;
            if (in->coef == 0 || in->rate == Rate::Scalar) in->value = value;
        }
    }

    // a t_trig control: the value for one block, then 0
    void trig(const std::string& name, float value = 1) {
        if (Input* in = find(name)) {
            in->value = in->target = value;
            in->trig = true;
        }
    }

    void setLag(const std::string& name, float seconds) {
        if (Input* in = find(name))
            in->coef = seconds > 0 ? (float)std::exp(std::log(0.001) / (seconds * ctrlRate_)) : 0.0f;
    }

    // One block. audio: BLOCK samples per audio input (or null, or a null
    // entry: silence); mods: the modulation channels (or null); out: one
    // BLOCK buffer per output.
    void process(const float* const* audio, const float* const* mods, float* const* out) {
        for (auto& in : inputs_) {
            if (in.rate == Rate::Audio) continue;
            if (in.coef != 0) in.value = in.target + in.coef * (in.value - in.target);
            float v = in.value;
            if (in.mod >= 0 && mods && mods[in.mod]) v += mods[in.mod][0];
            lib_.mi_in(u_, in.index)[0] = v;
            if (in.trig) {
                in.trig = false;
                in.value = in.target = 0;
            }
        }
        for (size_t k = 0; k < audioIns_.size(); ++k) {
            float* dst = lib_.mi_in(u_, audioIns_[k]);
            if (audio && audio[k]) std::memcpy(dst, audio[k], BLOCK * sizeof(float));
            else std::memset(dst, 0, BLOCK * sizeof(float));
        }
        lib_.mi_next(u_, BLOCK);
        for (int i = 0; i < outputs(); ++i)
            if (out[i]) std::memcpy(out[i], lib_.mi_out(u_, i), BLOCK * sizeof(float));
    }

private:
    struct Input {
        std::string name;
        int index = 0;
        Rate rate = Rate::Scalar;
        float value = 0, target = 0, coef = 0;
        int mod = -1;
        bool trig = false;
    };

    Library& lib_;
    double ctrlRate_;
    void* u_ = nullptr;
    int nIn_ = 0;
    std::vector<Input> inputs_;
    std::vector<int> audioIns_;

    Input* find(const std::string& name) {
        for (auto& in : inputs_)
            if (in.name == name) return &in;
        return nullptr;
    }
};

}  // namespace mi
