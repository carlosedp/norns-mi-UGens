// Renders each wasm UGen offline and checks it makes sound: finite samples,
// not silent, not blown up. Writes a WAV of each to <out-dir>/wav/ to listen to.
//
// Usage: node wasm/test.mjs <out-dir with the .wasm files> [ugens...]
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { join } from "node:path";
import { MiUnit, BLOCK } from "./mi-ugens.js";

const SR = 48000;
const dir = process.argv[2] || "work/out-wasm";
const only = process.argv.slice(3);

// A plucked test signal for the effects: decaying noise bursts, twice a second.
function burst(t) {
  const ph = t % 0.5;
  return (Math.random() * 2 - 1) * Math.exp(-ph * 30) * 0.5;
}

// name -> { spec, seconds, input (fx only), events: [[time, fn(unit)]] }
const CASES = {
  MiPlaits: { spec: { engine: 12, harm: 0.5, timbre: 0.5, morph: 0.5, trigger: { rate: "control" }, decay: 0.5 },
    events: [0, 0.5, 1, 1.5].map((t, i) => [t, u => { u.set("pitch", 48 + i * 7); u.trig("trigger"); }]) },
  MiRings: { spec: { trig: { rate: "control" }, pit: { rate: "control", value: 48 }, struct: 0.4, bright: 0.5, damp: 0.6, poly: 2 },
    events: [0, 0.5, 1, 1.5].map((t, i) => [t, u => { u.set("pit", 48 + i * 5); u.trig("trig"); }]) },
  MiRipples: { spec: { in: { rate: "audio" }, cf: 0.4, reson: 0.6 }, input: burst },
  MiClouds: { spec: { dens: 0.6, size: 0.4, tex: 0.5, drywet: 0.7 }, input: burst },
  MiBeads: { spec: { density: 0.7, drywet: 0.7, time: 0.5, size: 0.5 }, input: burst },
  MiVerb: { spec: { time: 0.8, drywet: 0.5 }, input: burst },
  MiElements: { spec: { gate: { rate: "control" }, pit: 48, bow_level: 0.6, blow_level: 0.2, strike_level: 0.3 },
    events: [[0, u => u.set("gate", 1)], [1.5, u => u.set("gate", 0)]] },
};

function wav(path, chans) {
  const n = chans[0].length, nc = chans.length, b = Buffer.alloc(44 + n * nc * 2);
  b.write("RIFF", 0); b.writeUInt32LE(36 + n * nc * 2, 4); b.write("WAVEfmt ", 8);
  b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(nc, 22); b.writeUInt32LE(SR, 24);
  b.writeUInt32LE(SR * nc * 2, 28); b.writeUInt16LE(nc * 2, 32); b.writeUInt16LE(16, 34);
  b.write("data", 36); b.writeUInt32LE(n * nc * 2, 40);
  for (let i = 0; i < n; i++) for (let c = 0; c < nc; c++)
    b.writeInt16LE(Math.round(Math.max(-1, Math.min(1, chans[c][i])) * 32767), 44 + (i * nc + c) * 2);
  writeFileSync(path, b);
}

mkdirSync(join(dir, "wav"), { recursive: true });
let fail = 0;
for (const [name, c] of Object.entries(CASES)) {
  if (only.length && !only.includes(name)) continue;
  const file = join(dir, `${name}.wasm`);
  if (!existsSync(file)) { console.log(`skip ${name}: no ${file}`); continue; }
  const t0 = performance.now();
  const unit = new MiUnit(name, new WebAssembly.Module(readFileSync(file)), SR, c.spec);
  const secs = c.seconds || 3, blocks = Math.floor(secs * SR / BLOCK);
  const nOut = unit.def.outputs, out = Array.from({ length: nOut }, () => new Float32Array(blocks * BLOCK));
  const blk = Array.from({ length: nOut }, () => new Float32Array(BLOCK));
  const inL = new Float32Array(BLOCK), inR = new Float32Array(BLOCK);
  const events = (c.events || []).slice();
  for (let b = 0; b < blocks; b++) {
    const t = b * BLOCK / SR;
    while (events.length && events[0][0] <= t) events.shift()[1](unit);
    let audio = null;
    if (c.input) {
      for (let i = 0; i < BLOCK; i++) inL[i] = inR[i] = c.input(t + i / SR);
      audio = [inL, inR];
    }
    unit.process(audio, null, blk);
    for (let ch = 0; ch < nOut; ch++) out[ch].set(blk[ch], b * BLOCK);
  }
  const ms = performance.now() - t0;
  unit.free();
  let peak = 0, sum = 0, bad = 0;
  for (const ch of out) for (const v of ch) { if (!Number.isFinite(v)) bad++; else { peak = Math.max(peak, Math.abs(v)); sum += v * v; } }
  const rms = Math.sqrt(sum / (out.length * out[0].length));
  const ok = !bad && rms > 1e-4 && peak < 20;
  if (!ok) fail = 1;
  wav(join(dir, "wav", `${name}.wav`), out);
  console.log(`${ok ? "ok  " : "FAIL"} ${name.padEnd(11)} rms ${rms.toFixed(4)} peak ${peak.toFixed(3)}${bad ? ` ${bad} non-finite` : ""}` +
    `  ${(ms / (secs * 1000) * 100).toFixed(1)}% of real time`);
}
process.exit(fail);
