// Renders each native mi-UGen library offline and checks it makes sound: finite
// samples, not silent, not blown up. Writes a WAV of each to <lib-dir>/wav/ to
// listen to. The native twin of wasm/test.mjs, with the same cases.
//
// Usage: mi-test <dir with the libraries> [ugens...]
#include <algorithm>
#include <chrono>
#include <cstdio>
#include <fstream>
#include <functional>
#include <random>

#include "mi_ugens.hpp"

#if defined(_WIN32)
#include <direct.h>
static void make_dir(const std::string& d) { _mkdir(d.c_str()); }
#else
#include <sys/stat.h>
static void make_dir(const std::string& d) { mkdir(d.c_str(), 0755); }
#endif

// plain strings, not std::filesystem: that needs macOS 10.15, the libraries don't
static bool exists(const std::string& path) {
    std::ifstream f(path);
    return f.good();
}
using mi::Rate;

static const double SR = 48000;
static std::mt19937 rng(1);

// A plucked test signal for the effects: decaying noise bursts, twice a second.
static float burst(double t) {
    double ph = std::fmod(t, 0.5);
    std::uniform_real_distribution<float> d(-1, 1);
    return d(rng) * (float)std::exp(-ph * 30) * 0.5f;
}

struct Event {
    double t;
    std::function<void(mi::Unit&)> fn;
};
struct Case {
    std::string name;
    std::vector<mi::Spec> spec;
    bool input = false;  // fed the burst
    std::vector<Event> events;
};

static std::vector<Event> every(int n, double step, std::function<void(mi::Unit&, int)> fn) {
    std::vector<Event> ev;
    for (int i = 0; i < n; ++i) ev.push_back({i * step, [fn, i](mi::Unit& u) { fn(u, i); }});
    return ev;
}

static void wav(const std::string& path, const std::vector<std::vector<float>>& ch) {
    uint32_t n = (uint32_t)ch[0].size(), nc = (uint32_t)ch.size(), bytes = n * nc * 2;
    std::ofstream f(path, std::ios::binary);
    auto u32 = [&](uint32_t v) { f.write((const char*)&v, 4); };
    auto u16 = [&](uint16_t v) { f.write((const char*)&v, 2); };
    f.write("RIFF", 4); u32(36 + bytes); f.write("WAVEfmt ", 8);
    u32(16); u16(1); u16((uint16_t)nc); u32((uint32_t)SR); u32((uint32_t)SR * nc * 2); u16((uint16_t)(nc * 2)); u16(16);
    f.write("data", 4); u32(bytes);
    for (uint32_t i = 0; i < n; ++i)
        for (uint32_t c = 0; c < nc; ++c) {
            float v = std::max(-1.0f, std::min(1.0f, ch[c][i]));
            u16((uint16_t)(int16_t)std::lround(v * 32767));
        }
}

int main(int argc, char** argv) {
    std::string dir = argc > 1 ? argv[1] : "build/lib";
    std::vector<std::string> only(argv + std::min(argc, 2), argv + argc);

    std::vector<Case> cases = {
        {"MiPlaits", {{"engine", 12}, {"harm", 0.5f}, {"timbre", 0.5f}, {"morph", 0.5f}, {"trigger", 0, Rate::Control}, {"decay", 0.5f}}, false,
         every(4, 0.5, [](mi::Unit& u, int i) { u.set("pitch", 48.0f + i * 7); u.trig("trigger"); })},
        {"MiRings", {{"trig", 0, Rate::Control}, {"pit", 48, Rate::Control}, {"struct", 0.4f}, {"bright", 0.5f}, {"damp", 0.6f}, {"poly", 2}}, false,
         every(4, 0.5, [](mi::Unit& u, int i) { u.set("pit", 48.0f + i * 5); u.trig("trig"); })},
        {"MiRipples", {{"in", 0, Rate::Audio}, {"cf", 0.4f}, {"reson", 0.6f}}, true, {}},
        {"MiClouds", {{"dens", 0.6f}, {"size", 0.4f}, {"tex", 0.5f}, {"drywet", 0.7f}}, true, {}},
        {"MiBeads", {{"density", 0.7f}, {"drywet", 0.7f}, {"time", 0.5f}, {"size", 0.5f}}, true, {}},
        {"MiVerb", {{"time", 0.8f}, {"drywet", 0.5f}}, true, {}},
        {"MiElements", {{"gate", 0, Rate::Control}, {"pit", 48}, {"bow_level", 0.6f}, {"blow_level", 0.2f}, {"strike_level", 0.3f}}, false,
         {{0, [](mi::Unit& u) { u.set("gate", 1); }}, {1.5, [](mi::Unit& u) { u.set("gate", 0); }}}},
    };

    make_dir(dir + "/wav");
    int fail = 0, tested = 0;
    for (auto& c : cases) {
        if (!only.empty() && std::find(only.begin(), only.end(), c.name) == only.end()) continue;
        std::string file = dir + "/" + mi::libraryFile(c.name);
        if (!exists(file)) {
            printf("skip %s: no %s\n", c.name.c_str(), file.c_str());
            continue;
        }
        mi::Library lib;
        if (!lib.open(file, c.name)) {
            printf("FAIL %s: %s\n", c.name.c_str(), lib.error.c_str());
            fail = 1;
            continue;
        }
        ++tested;
        auto t0 = std::chrono::steady_clock::now();
        double secs = 3;
        int blocks = (int)(secs * SR / mi::BLOCK), nOut;
        std::vector<std::vector<float>> out;
        {
            mi::Unit unit(lib, SR, c.spec);
            nOut = unit.outputs();
            out.assign(nOut, std::vector<float>((size_t)blocks * mi::BLOCK));
            std::vector<std::vector<float>> blk(nOut, std::vector<float>(mi::BLOCK));
            std::vector<float*> blkp;
            for (auto& b : blk) blkp.push_back(b.data());
            std::vector<float> in(mi::BLOCK);
            std::vector<const float*> audio(unit.audioInputs(), in.data());
            size_t next = 0;
            for (int b = 0; b < blocks; ++b) {
                double t = (double)b * mi::BLOCK / SR;
                while (next < c.events.size() && c.events[next].t <= t) c.events[next++].fn(unit);
                if (c.input)
                    for (int i = 0; i < mi::BLOCK; ++i) in[i] = burst(t + i / SR);
                unit.process(c.input ? audio.data() : nullptr, nullptr, blkp.data());
                for (int ch = 0; ch < nOut; ++ch)
                    std::copy(blk[ch].begin(), blk[ch].end(), out[ch].begin() + (size_t)b * mi::BLOCK);
            }
        }
        double ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t0).count();
        double peak = 0, sum = 0;
        long bad = 0;
        for (auto& ch : out)
            for (float v : ch) {
                if (!std::isfinite(v)) ++bad;
                else { peak = std::max(peak, (double)std::fabs(v)); sum += (double)v * v; }
            }
        double rms = std::sqrt(sum / (out.size() * out[0].size()));
        bool ok = !bad && rms > 1e-4 && peak < 20;
        if (!ok) fail = 1;
        wav(dir + "/wav/" + c.name + ".wav", out);
        printf("%s %-11s rms %.4f peak %.3f%s  %.1f%% of real time\n", ok ? "ok  " : "FAIL", c.name.c_str(), rms, peak,
               bad ? (" " + std::to_string(bad) + " non-finite").c_str() : "", ms / (secs * 1000) * 100);
    }
    if (!tested) {
        printf("no libraries found in %s\n", dir.c_str());
        return 1;
    }
    return fail;
}
