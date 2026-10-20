# mi-UGens in the browser

Seven of Volker Böhm's [mi-UGens](https://github.com/v7b1/mi-UGens), built as WebAssembly so a web
page can play Émilie Gillet's Mutable Instruments code: the same code a norns or any SuperCollider
plays, not an imitation. Each one runs in an AudioWorklet the way scsynth runs it.

| UGen       | Module                                     |
| ---------- | ------------------------------------------ |
| MiPlaits   | Plaits: macro oscillator                   |
| MiRings    | Rings: resonator                           |
| MiElements | Elements: bowed, blown and struck modeling |
| MiClouds   | Clouds: granular processor                 |
| MiBeads    | Beads: granular processor and reverb       |
| MiRipples  | Ripples: 4-pole filter                     |
| MiVerb     | the reverb from Clouds and Rings           |

It's plain JavaScript with no dependencies and no bundler: two script files and one `.wasm` per
UGen (12 KB to 412 KB, about 1.1 MB for all seven). It works in any page, with or without a
framework, and in node for offline rendering and tests.

[terrarium](https://github.com/carlosedp/terrarium) uses it to play its norns engine in the
browser ([try it](https://carlosedp.github.io/terrarium/)); its
[`lib/Engine_Terrarium.js`](https://github.com/carlosedp/terrarium/blob/main/lib/Engine_Terrarium.js)
is a complete example of SynthDefs rebuilt from these nodes.

- [Get it](#get-it)
- [Play one in a page](#play-one-in-a-page)
- [Inputs: scalar, control, audio](#inputs-scalar-control-audio)
- [The node](#the-node)
- [From a SynthDef to nodes](#from-a-synthdef-to-nodes)
- [Inputs of each UGen](#inputs-of-each-ugen)
- [Offline, in node](#offline-in-node)
- [How it works](#how-it-works)
- [Limits](#limits)
- [License](#license)

## Get it

**Download:** every [release](https://github.com/carlosedp/norns-mi-UGens/releases) carries
`mi-UGens-wasm.tar.gz` (and the same under the tag's name). It unpacks to `mi-UGens-wasm/`:

```
MiPlaits.wasm  MiRings.wasm  MiElements.wasm  MiClouds.wasm  MiBeads.wasm  MiRipples.wasm  MiVerb.wasm
mi-ugens.js        the AudioWorklet processor (also an ES module, for node)
mi-ugens-node.js   the main-thread side: loads the wasm, makes nodes (defines window.MiUGens)
demo.html          a page that plays them
BUILDINFO          the exact mi-UGens source it was built from
```

To try it, serve the folder and open the demo:

```bash
cd mi-UGens-wasm && python3 -m http.server 8000     # then open http://localhost:8000/demo.html
```

**Build it yourself** (podman or docker, and node for the test):

```bash
./build.sh --wasm --pr 24          # PR 24 adds MiBeads; without it, Beads isn't built
```

The build runs in the `emscripten/emsdk` container, then renders each UGen offline in node
(`test.mjs`) to check that it makes sound. The output is `work/out-wasm/` and
`dist/mi-UGens-wasm-<version>.tar.gz`.

## Play one in a page

Copy the folder next to your page; here it's `mi-ugens/`. The page has to be served over http
(`file://` can't load an AudioWorklet), from `https://` or `localhost`. Browsers only start
audio after a click, so create the AudioContext in one.

```html
<button id="play">Play</button>
<script src="mi-ugens/mi-ugens-node.js"></script>
<script>
  document.getElementById("play").onclick = async () => {
    const ctx = new AudioContext();
    const mi = await MiUGens.load(ctx, "mi-ugens/", ["MiPlaits", "MiVerb"]);

    const plaits = mi.node("MiPlaits", {
      engine: 12,                                         // scalar: fixed for the node's life
      harm: { rate: "control", value: 0.4, lag: 0.05 },   // control, smoothed like .lag(0.05)
      timbre: { rate: "control", value: 0.5 },
      trigger: { rate: "control" },                       // patched: Plaits waits for triggers
    });
    const verb = mi.node("MiVerb", { time: 0.8, drywet: { rate: "control", value: 0.4 } });

    plaits.connect(verb);                // Plaits' two outputs into the reverb's two audio inputs
    verb.connect(ctx.destination);

    let step = 0;
    setInterval(() => {
      plaits.set({ pitch: 48 + [0, 3, 7, 10][step++ % 4] });
      plaits.trig({ trigger: 1 });       // high for one block, like a t_trig
    }, 400);
  };
</script>
```

`MiUGens.load(ctx, base, names)` loads the worklet and compiles each named `.wasm` once; load
only the UGens you use. `mi.node(name, spec)` makes an `AudioWorkletNode` running one unit, and
you can make as many as the CPU allows.

## Inputs: scalar, control, audio

The spec gives each input a rate, as a SynthDef would. **It matters:** the wrappers check how an
input is fed, and some behave differently when it's "patched".

| Spec                                    | Rate    | In a SynthDef                       |
| --------------------------------------- | ------- | ----------------------------------- |
| `harm: 0.4` (a number), or left out     | scalar  | a literal: `MiPlaits.ar(harm: 0.4)` |
| `harm: { rate: "control", value: 0.4 }` | control | an argument: `harm: harm`           |
| `harm: { ..., lag: 0.1 }`               | control | `harm.lag(0.1)`                     |
| `harm: { ..., mod: 0 }`                 | control | plus a `.kr` signal (see below)     |
| `in: { rate: "audio" }`                 | audio   | `MiRings.ar(in: sig)`               |

- A **scalar** is read when the unit starts, and the UGen may never look at it again. Use a
  control for anything you change.
- **Patched inputs:** MiPlaits' `trigger` and `level` (unpatched, the LPG stays open and it
  drones), MiRings' `trig` and `pit` (unpatched, Rings tracks its input's pitch), MiBeads' `seed`
  (**any** value there stops `density` from making grains: leave it out).
- Inputs left out of the spec are scalars at the sclang class's default (listed below).
- `audio: n` in the spec sets how many audio inputs MiClouds, MiBeads and MiVerb take (default 2).

## The node

- **Outputs:** one channel per UGen output: two for all but MiRipples (one). Split them with a
  `ChannelSplitterNode`.
- **Input 0, audio:** one channel per audio input, in order: named audio-rate inputs first, then
  the input array of MiClouds, MiBeads and MiVerb. A stereo node connected to MiVerb fills both.
- **Input 1, modulation:** a channel per modulator. An input with `mod: k` adds channel `k`, read
  once per 64-sample block, like a `.kr` signal. Feed several through a `ChannelMergerNode`:
  `lfo.connect(merge, 0, k); merge.connect(node, 0, 1)`.
- `node.set({ name: value, ... })`: change controls (gliding if they have a lag).
- `node.trig({ name: value })`: the value for one block, then 0 (a `t_trig`).
- `node.lag({ name: seconds })`: change a control's lag.
- `node.free()`: stop and disconnect it.
- Errors and the UGens' own `Print` messages go to the console, prefixed with the UGen's name.

## From a SynthDef to nodes

The rest of a SynthDef has a direct Web Audio counterpart; the mi-UGens are the only part that
needs this package.

| SuperCollider                        | Web Audio                                                                |
| ------------------------------------ | ------------------------------------------------------------------------ |
| `MiPlaits.ar(...)`                   | `mi.node("MiPlaits", spec)`                                              |
| `sig[0]`                             | a `ChannelSplitterNode`, output 0                                        |
| `Pan2.ar(sig, pan, amp)`             | a `GainNode` into a `StereoPannerNode`                                   |
| `In.ar(bus, 2)`, `Out.ar(bus, sig)`  | `connect()`                                                              |
| an argument (`arg harm`)             | `{ rate: "control", value }`, changed with `set()`                       |
| a `t_trig` argument                  | `trig()`                                                                 |
| `harm.lag(0.2)`                      | `lag: 0.2`                                                               |
| `LFTri.kr(0.05) * depth + harm`      | an `OscillatorNode` ("triangle") and a `GainNode` into input 1, `mod: k` |
| `EnvGen`, `Line`, `XFade2`           | `AudioParam` ramps on `GainNode`s                                        |

For example, a voice that pans Plaits' main output:

```js
// SynthDef(\voice, { |pitch = 60, harm = 0.5, t_trig = 0, pan = 0, amp = 0.3|
//   var sig = MiPlaits.ar(pitch, 12, harm.lag(0.05), trigger: t_trig, level: 0.8);
//   Out.ar(0, Pan2.ar(sig[0], pan, amp)) })
const u = mi.node("MiPlaits", { pitch: { rate: "control", value: 60 }, engine: 12,
  harm: { rate: "control", value: 0.5, lag: 0.05 }, trigger: { rate: "control" }, level: 0.8 });
const split = ctx.createChannelSplitter(2), amp = new GainNode(ctx, { gain: 0.3 });
const pan = new StereoPannerNode(ctx, { pan: 0 });
u.connect(split); split.connect(amp, 0); amp.connect(pan); pan.connect(ctx.destination);
// then: u.set({ pitch: 64 }); u.trig({ trigger: 1 });
```

Here `level: 0.8` is a literal in the SynthDef, so it's a scalar here too; `trigger` is an
argument, so it's a control.

## Inputs of each UGen

In order, with the sclang classes' defaults; the names are the spec's keys.

| UGen       | Outputs | Inputs (default)                                                                                                                                                                                                  |
| ---------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| MiPlaits   | 2       | pitch 60, engine 0, harm 0.1, timbre 0.5, morph 0.5, trigger 0, level 0, fm_mod 0, timb_mod 0, morph_mod 0, decay 0.5, lpg_colour 0.5                                                                             |
| MiRings    | 2       | in 0, trig 0, pit 60, struct 0.25, bright 0.5, damp 0.7, pos 0.25, model 0, poly 1, intern_exciter 0, easteregg 0, bypass 0                                                                                       |
| MiRipples  | 1       | in 0, cf 0.3, reson 0.2, drive 1                                                                                                                                                                                  |
| MiClouds   | 2       | pit 0, pos 0.5, size 0.25, dens 0.4, tex 0.5, drywet 0.5, in_gain 1, spread 0.5, rvb 0, fb 0, freeze 0, mode 0, lofi 0, trig 0, then 2 audio inputs                                                              |
| MiBeads    | 2       | pitch 0, pitch_rnd 0, time 0.5, time_rnd 0, size 0.5, size_rnd 0, shape 0.5, shape_rnd 0, density 0.7, fb 0, drywet 0.5, rvb 0, freeze 0, seed 0, seed_btn 2, quality 0, in_gain 1, synth 0, then 2 audio inputs |
| MiVerb     | 2       | time 0.7, drywet 0.5, damp 0.5, hp 0.05, freeze 0, diff 0.625, then 2 audio inputs                                                                                                                                |
| MiElements | 2       | blow_in 0, strike_in 0, gate 0, pit 48, strength 0.5, contour 0.2, bow_level 0, blow_level 0, strike_level 0, flow 0.5, mallet 0.5, bow_timb 0.5, blow_timb 0.5, strike_timb 0.5, geom 0.25, bright 0.5, damp 0.7, pos 0.2, space 0.3, model 0, easteregg 0 |

What each input does is in mi-UGens' help files ([v7b1/mi-UGens](https://github.com/v7b1/mi-UGens),
`sc/HelpSource`) and in the Mutable Instruments manuals.

## Offline, in node

`mi-ugens.js` is also an ES module. `MiUnit` runs a unit without a browser, block by block, to
render or to test (node 18+):

```js
import { readFileSync } from "node:fs";
import { MiUnit, BLOCK } from "./mi-ugens.js";

const u = new MiUnit("MiPlaits", readFileSync("MiPlaits.wasm"), 48000,
  { engine: 12, trigger: { rate: "control" } });
const out = [new Float32Array(BLOCK), new Float32Array(BLOCK)];
u.trig("trigger");
for (let i = 0; i < 750; i++) {        // one second at 48 kHz
  u.process(null, null, out);          // audio inputs, modulation channels, outputs
  // out[0] now holds the next 64 samples
}
u.free();
```

`set(name, value)`, `trig(name)` and `setLag(name, seconds)` work as on the node. `test.mjs`
renders all seven this way and writes a WAV of each.

## How it works

The mi-UGens wrappers (`projects/Mi*/Mi*.cpp`) compile **unchanged**. They only use a small part
of SuperCollider's plugin API (`IN`, `OUT`, `INRATE`, `BUFLENGTH`, `SAMPLERATE`, `SETCALC`,
`RTAlloc`, `Print` and a few more), so `include/plugin_interface/SC_PlugIn.h` here stands in for
the real header, and `glue.cpp` exports a C API to drive one unit: create it, set each input's
rate, run its constructor, then per block fill the inputs, call next and read the outputs.
mi-UGens' own CMake files supply the source lists; each UGen is linked into its own standalone
`.wasm` (no emscripten JavaScript), so their globals never clash.

`mi-ugens.js` runs a unit the way scsynth does:

- 64-sample blocks (an AudioWorklet's 128 are two of them)
- each input at scalar, control or audio rate, because the wrappers check
- triggers high for one block (like `t_trig`), control lags like `.lag()`
- MiVerb's outputs share its inputs' buffers, as scsynth's wire buffers do (it works in place)

Each node runs its own wasm instance (cheap: the module is compiled once). In node, all seven
together take about 10% of one core of a desktop CPU.

## Limits

- Only the seven UGens above; the others (Braids, Tides, Warps, Omi, Mu, Grids) would need their
  wrappers checked against the stand-in header first.
- It needs AudioWorklet and WebAssembly SIMD (Ripples uses VCV Rack's SSE code): Chrome and
  Firefox since 2021, Safari since 16.4. Without them, `load()` throws.
- The wrappers can't tell an audio-rate control from a control-rate one coming from a node:
  `rate` says which, as in the SynthDef.
- The sample rate is the AudioContext's. At 44.1 kHz some UGens sound slightly different from
  a norns at 48 kHz, as they would in SuperCollider.

## License

The `.wasm` files are built from mi-UGens, which is GPL-3.0 (and includes Mutable Instruments'
code, MIT). A page that serves them distributes GPL-3.0 code: link to the source they were built
from (`BUILDINFO` names the exact repository, commit and pull requests) and keep the license
notices.
