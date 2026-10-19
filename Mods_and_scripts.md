# Norns: Mods & Scripts to Explore

A curated starting list for a new norns, with a focus on the Mutable Instruments
ecosystem built by this repo. Descriptions and links checked October 2026.

- [Getting started](#getting-started)
- [Day-one plan](#day-one-plan)
- [Mutable Instruments on norns](#mutable-instruments-on-norns)
- [Mods](#mods)
- [Scripts](#scripts)
- [monome iii (scripts that run on the grid itself)](#monome-iii-scripts-that-run-on-the-grid-itself)
- [Beyond norns](#beyond-norns)
- [Resources](#resources)
- [To look into](#to-look-into)

---

## Getting started

| Task | How |
| --- | --- |
| Connect | Join WiFi in SYSTEM > WIFI, then open **maiden** at <http://norns.local> (ssh: `we@norns.local`, password `sleep`) |
| Install a script or mod | In the maiden REPL (matron tab): `;install https://github.com/<user>/<repo>`, or browse the **Project Manager** in maiden |
| Enable a mod | SYSTEM > MODS, select it, E3 to mark it `+`, then SYSTEM > RESTART. Mods run *alongside* any script |
| Run a script | SELECT on the norns menu |
| Update everything | maiden Project Manager > "update all" |

**Mods vs scripts:** a *script* is the app you're running; only one runs at a time.
A *mod* is a system extension that stays loaded under every script: extra voices,
effects, MIDI routing, controller support. Many entries below are mods because they
add capabilities to *all* your scripts.

---

## Day-one plan

A suggested install order, with each step building on the last:

1. **mi-UGens**: `./build.sh --pr 24 && ./deploy.sh dist/*.tar.gz` from this repo (see [README](README.md)).
   Do this *before* installing the mods below. Several of them auto-download an
   older mi-UGens copy if they don't find one.
2. **nb** ecosystem: [Emplaitress](#nb-voices--routing) (Plaits as a voice), [monami.e](#nb-voices--routing) (Just Friends-style voice), [nbout](#nb-voices--routing) (play nb from MIDI-out scripts).
3. **fx mod** + [fx_grains](#mutable-instruments-on-norns) (Clouds) + [fx_beads](examples/fx_beads) (Beads, from this repo).
4. A sequencer that speaks nb: [Dreamsequence](#sequencers--generative) or [Stratum](#mutable-instruments-on-norns).
5. Classics to learn norns with: [mlr](#samplers-loopers--delays), [Flora](#sequencers--generative), [Compass](#samplers-loopers--delays).

---

## Mutable Instruments on norns

Everything here uses the UGens this repo builds (or ports of the same modules).

| Name | Kind | What it is | Uses | Install / link |
| --- | --- | --- | --- | --- |
| **mi-UGens** (this repo) | SC plugins | Plaits, Rings, Clouds, Elements, Braids, Beads, Warps, … for SuperCollider | – | [README](README.md) · [lines thread](https://llllllll.co/t/mi-ugens-for-norns/31781) |
| **Emplaitress** | mod (nb voice) | Four Plaits voices playable from any nb-enabled script; supports fx sends | Plaits | `;install https://github.com/sixolet/emplaitress` |
| **fx_grains** | mod (fx) | Clouds as a send/insert effect, with LFO + random modulation | Clouds | `;install https://github.com/sixolet/fx_grains` |
| **fx_resonator** | mod (fx + nb voice) | Rings as an effect *and* as an nb voice | Rings | `;install https://github.com/sixolet/fx_resonator` |
| **fx_beads** (this repo) | mod (fx) | Beads as a send/insert effect | Beads | [examples/fx_beads](examples/fx_beads) |
| **Stratum** | script | Marbles-style generative sequencer (t rhythms, X pitches, DEJA VU) driving Rings → Clouds, plus MIDI/crow | Rings, Clouds | [lines](https://llllllll.co/t/stratum/74645) · [github](https://github.com/mrmattallison/stratum) |
| **krill** | script | Lorenz-attractor sequencer + mod matrix playing Rings | Rings | [lines](https://llllllll.co/t/krill/54975) · `;install https://github.com/jaseknighter/krill` |
| **Pedalboard** | script | Chainable stereo pedals for audio input; includes Rings and Clouds pedals | Rings, Clouds | [lines](https://llllllll.co/t/pedalboard-chainable-fx-for-norns/31119) · [github](https://github.com/21echoes/pedalboard) |
| **oomph** | script | Acid synth + sample looper + chord sequencer + Plaits + tape emulation | Plaits | [lines](https://llllllll.co/t/oomph/56151) · [github](https://github.com/schollz/oomph) |
| **mi-engines** | scripts/engines | Okyeron's original Clouds/Rings/Elements/Plaits engines + demos (last updated 2021) | several | [lines](https://llllllll.co/t/mi-engines/32338) · [github](https://github.com/okyeron/mi-eng) |
| **Cyrene** | script | Drum sequencer using Mutable **Grids** patterns + per-track euclidean generator (Ack engine, not mi-UGens) | – | [norns.community](https://norns.community/cyrene/) · [github](https://github.com/21echoes/cyrene) |

> **⚠️ Avoid duplicate installs.** Emplaitress, fx_grains and oomph download
> schollz's prebuilt mi-UGens if `MiPlaits.sc` isn't already in Extensions.
> Pedalboard and krill offer to install Okyeron's 2020 build (v0.3).
> [schollz/supercollider-plugins](https://github.com/schollz/supercollider-plugins) also bundles
> mi-UGens. Two copies of the same class makes sclang fail ("SUPERCOLLIDER FAIL"
> on boot). Install this repo's build first and **decline** those installers
> (pedalboard: K2 to cancel). If it happens anyway, re-run `deploy.sh`; it moves
> the extra copies to `~/mi-UGens-backup-*`.

---

## Mods

### The sixolet "trilogy": matrix → nb → fx

These three are the backbone of modern norns modularity. Many newer scripts
support them, and they combine: nb voices can send to fx, and matrix modulates both.

| Name | What it is | Install / link |
| --- | --- | --- |
| **nb** (n.b. et al.) | Voice library: scripts that support it can play *any* installed voice (internal synths, MIDI, crow, Just Friends, …). Voices are installed as mods | [lines](https://llllllll.co/t/n-b-et-al-v0-1/60374) · [github](https://github.com/sixolet/nb) |
| **matrix** | Modulation matrix + API: route LFOs/sequencers to any param with depth | [lines](https://llllllll.co/t/mod-matrix-for-the-matrix-mod/57231) · `;install https://github.com/sixolet/matrix` |
| **fx** | Send A/B + insert effects framework for SuperCollider scripts and nb voices. **Required** by every `fx_*` mod; without it they cause a SuperCollider fail | [lines](https://llllllll.co/t/fx-mod/62726) · `;install https://github.com/sixolet/fx` |

### nb voices & routing

| Name | What it is | Install / link |
| --- | --- | --- |
| **Emplaitress** | 4× Plaits nb voice (see above) | `;install https://github.com/sixolet/emplaitress` |
| **monami.e** | Six-voice nb player with the same controls as Just Friends in synth mode, for when the modular stays home | [lines](https://llllllll.co/t/monami-e/75626) · `;install https://github.com/sonocircuit/nb_monamie` |
| **Doubledecker** | Two-layer CS-80-style polysynth (via Deckard's Dream) with velocity and poly-pressure modulation; supports fx sends | [lines](https://llllllll.co/t/doubledecker/61525) · `;install https://github.com/sixolet/doubledecker` |
| **Oilcan** | FM + wavefolder digital percussion voice for nb (made with n.Kria in mind) | [lines](https://llllllll.co/t/oilcan-percussion-co/60754) · `;install https://github.com/zjb-s/oilcan` |
| **nbin** | External MIDI in → nb voices (play nb synths from a controller while any script runs; MPE bend/pressure) | `;install https://github.com/sixolet/nbin` |
| **nbout** | Virtual MIDI device `nb`: any script that sends MIDI can play nb voices | `;install https://github.com/sixolet/nbout` |
| **sidvagn** | "Sidecar" grid: isometric keyboard to play your nb voice alongside almost any script | [lines](https://llllllll.co/t/sidvagn/72514) · `;install https://github.com/sonocircuit/sidvagn` |
| **Seeker** | Lightweight two-lane nb arpeggiator mod | [lines](https://llllllll.co/t/seeker-a-lightweight-n-b-arpeggiation-mod/67955) |

### Controllers & MIDI

| Name | What it is | Install / link |
| --- | --- | --- |
| **gridkeys** | Use grid as a MIDI keyboard in any script (chromatic/in-scale layouts, crow & Just Friends out) | [lines](https://llllllll.co/t/gridkeys-mod-now-w-q7-layout-crow-jf-outs/49431) · `;install https://github.com/p3r7/gridkeys` |
| **midigrid** | Use Launchpads and other MIDI grid controllers as a monome grid, no script edits needed | [lines](https://llllllll.co/t/midigrid-use-launchpads-midi-grid-controllers-with-norns/42336) · `;install https://github.com/jaggednz/midigrid` |
| **passthrough** | MIDI routing/thru between all connected ports, with extras | [lines](https://llllllll.co/t/passthrough-v2/49397) · `;install https://github.com/nattog/passthrough` |
| **toga** | TouchOSC grid + arc emulator, to try grid scripts from a phone or tablet before you own a grid | `;install https://github.com/wangpy/toga` |

---

## Scripts

### Sequencers & generative

| Name | What it is | Needs | Link |
| --- | --- | --- | --- |
| **Flora** | L-systems sequencer with bandpass-filtered saw engine; v2.1 adds live-coding screen and nb (Oilcan drums) | – | [lines](https://llllllll.co/t/flora/40261) · [github](https://github.com/jaseknighter/flora) |
| **Fall** | Generative synth/sequencer: falling leaves play notes when they land | MIDI optional | [lines](https://llllllll.co/t/fall-generative-synth-sequencer/48991) · [github](https://github.com/ambalek/fall) |
| **NEVE** | Generative ambient sequencer (snow = bass, tears = melody, plus a live grid voice) → PolyPerc/mx.samples, MIDI, Just Friends | grid/arc optional | [lines](https://llllllll.co/t/neve-generative-ambient-sequencer/75615) · [github](https://github.com/vrcvs/NEVE) |
| **Stratum** | Marbles-inspired, into Rings → Clouds (see [MI section](#mutable-instruments-on-norns)) | mi-UGens | [lines](https://llllllll.co/t/stratum/74645) |
| **Dreamsequence** | Chord-based sequencer, arpeggiator and harmonizer; nb, MIDI, crow | grid | [lines](https://llllllll.co/t/dreamsequence/62607) · [norns.community](https://norns.community/dreamsequence/) |
| **n.Kria** | Full norns-native rewrite of Kria with on-screen hints; plays nb voices | grid | [lines](https://llllllll.co/t/n-kria-native-norns-kria/60403) · [github](https://github.com/zjb-s/n.kria) |
| **zxcvbn** | Tracker driven by an esoteric text language; internal engines, MIDI, crow | USB keyboard | [lines](https://llllllll.co/t/zxcvbn/59289) · [docs](https://zxcvbn.norns.online) |
| **_awed** | "Harmonic series aggregator": slow, timbre-from-harmonics instrument | – | [lines](https://llllllll.co/t/awed/72603) · [github](https://github.com/melocoi/_awed) |
| **FAKE** | Generative harmonic arpeggiator built around "scale presence" | – | [github](https://github.com/EchoesFromTheShield/FAKE) |
| **nexus** | Generative chord sequencer (15-chord diatonic palette, probabilistic triggers), MIDI + crow | grid optional | [github](https://github.com/lesjamusic/nexus) |
| **Mosaic** | Elektron-style rhythm/harmony sequencer for a whole studio | grid | [lines](https://llllllll.co/t/mosaic/69304) |
| **spre** (mine) | Generative synthesizer | – | [github](https://github.com/carlosedp/spre) |

### Samplers, loopers & delays

| Name | What it is | Needs | Link |
| --- | --- | --- | --- |
| **mlr** | The classic live sample-cutting platform | grid | [norns.community](https://norns.community/mlr/) · [github](https://github.com/tehn/mlr) |
| **ndls** | 4-track gesture tape looper/delay/sampler on softcut, modeless and performance-minded | grid (or midigrid) | [lines](https://llllllll.co/t/ndls-beta-v0-4-0-vari-filter-modulation-system/62310) · [norns.community](https://norns.community/ndls/) |
| **Compass** | Asynchronous looper driven by a command sequencer | – | [lines](https://llllllll.co/t/compass/25192) · [github](https://github.com/oliviercreurer/compass) |
| **Eterna** | 6-voice sampler/sequencer slicing one (multichannel) audio file into rhythmic textures | – | [lines](https://llllllll.co/t/eterna/73584) · [norns.community](https://norns.community/eterna/) |
| **Messiaen** | Delay/looper simulating birdsong and bird calls | audio input | [lines](https://llllllll.co/t/messiaen-a-bird-script/68021) · [github](https://github.com/2roundrobins/messiaen) |
| **bounds** | Stereo delay/looper with probabilistic kinetic sequencing (Rebound × Otis). **Requires [otis](https://github.com/notjustmat/otis) installed too** | audio input | [norns.community](https://norns.community/bounds/) |
| **graintopia** | Three "lands" of six physics-driven grains each | – | [lines](https://llllllll.co/t/graintopia/62343) |

### Effects for audio input

| Name | What it is | Link |
| --- | --- | --- |
| **Pedalboard** | Chainable pedals (delay, reverb, chorus, …, Rings, Clouds) | [lines](https://llllllll.co/t/pedalboard-chainable-fx-for-norns/31119) |
| **tapedeck** | 11-stage tape emulation (saturation, wow/flutter, chew, loss) | [lines](https://llllllll.co/t/tapedeck/51919) |

### Libraries (for scripting)

| Name | What it is | Link |
| --- | --- | --- |
| **lfo** | General-purpose LFO library, **built into norns** since update 220802 (`require 'lfo'`), nothing to install | [lines](https://llllllll.co/t/lfo-lib/60274) · [source](https://github.com/monome/norns/blob/main/lua/lib/lfo.lua) |

---

## monome iii (scripts that run on the grid itself)

These are **not norns scripts.** They run on an iii-enabled grid using monome's
[iii](https://github.com/monome/iii) Lua environment and send MIDI directly, with no
computer needed. Useful for driving norns (via nbin) or other gear.

| Name | What it is | Link |
| --- | --- | --- |
| **many-roads** | Script switcher / menu for iii grids. Install this first | [lines](https://llllllll.co/t/many-roads/74758) · [github](https://github.com/boreal-ground/many-roads-grid) |
| **kria iii** | 4-track MIDI step sequencer, a "kria lite" | [lines](https://llllllll.co/t/kria-iii/74390) · [github](https://github.com/aktsom/kria_iii) · [manual](https://aktsom.github.io/kria_iii/kria_iii_manual.html) |
| **loopiii** | 6-track MIDI looper/recorder | [github](https://github.com/nolliegray/loopiii) |
| **stepiii** | Performance step sequencer | [github](https://github.com/nolliegray/stepiii) |
| **arpiii** | Arpeggiator + sequencer | [github](https://github.com/nolliegray/arpiii) |
| **sluiiice** | Generative "waterfall" | [lines](https://llllllll.co/t/sluiiice-a-waterfall-for-iii-grids/74393) · [github](https://github.com/duncangeere/sluiiice) |
| **fell** | 16 tracks at independent speeds; sequencer/kalimba | [lines](https://llllllll.co/t/fell/72593) · [github](https://github.com/liamelliot/fell) |

---

## Beyond norns

| Name | What it is | Link |
| --- | --- | --- |
| **seamstress** | norns-like Lua "art engine" for desktop computers (grid/arc/MIDI/OSC) | [github](https://github.com/robbielyman/seamstress-v1) |
| **flora_seamstress** | Flora ported to seamstress | [github](https://github.com/jaseknighter/flora_seamstress) |
| **Open Grid Controller** | Open-source DIY 8×16 monome-grid-compatible controller (RP2040-Zero, 16-level LEDs, 3D-printed case) | [github](https://github.com/FreepoetOfficial/Open-Grid-Controller) · [site](https://freepoet.co.uk/) |
| **FREEPOET Keypad** | The 8×8 I2C key/LED boards the Open Grid is built from | [github](https://github.com/FreepoetOfficial/FREEPOET_Keypad) |
| **sc-plugins-arm64** | 64-bit ARM builds of community SC plugins, for 64-bit norns ports (Pi 5, Ableton Move). Stock norns is 32-bit and uses this repo's armhf build | [lines](https://llllllll.co/t/supercollider-64-bit-ugen-plugins/74292) · [github](https://github.com/seajaysec/sc-plugins-arm64) |

---

## Resources

- **[norns.community](https://norns.community/)**: the community script index (searchable, tagged)
- **[norns.online](https://norns.online/)**: stream your norns screen + audio to the web, share tapes and saves (by infinite digits)
- **[monome norns docs](https://monome.org/docs/norns/)**: official docs; start with *play* and *maiden*
- **[lines forum](https://llllllll.co/c/library/)**: the Library category has one thread per script
- **[Mi-UGens for norns thread](https://llllllll.co/t/mi-ugens-for-norns/31781)**: history and Q&A for the MI plugins
- **[norns mods development](https://llllllll.co/t/norns-mods-development/51013)**: if you want to write your own mods (e.g. more `fx_*` wrappers)

---

## To look into

- [ ] **TG**: listed under mods in my original notes, no link. Couldn't identify it; fill in when I remember.
