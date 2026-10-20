# norns-mi-UGens

_Mutable Instruments modules for monome norns_

Émilie Gillet's Mutable Instruments modules (Plaits, Rings, Clouds, Beads, Elements and more)
became [mi-UGens](https://github.com/v7b1/mi-UGens), Volker Böhm's SuperCollider versions of
them. This repository builds them for [monome norns](https://monome.org/docs/norns/) and norns
shield, so scripts and mods can use them, and publishes ready-to-install releases.

It picks up where [okyeron/mi-UGens](https://github.com/okyeron/mi-UGens) left off, with
newer modules (Beads, through [PR #24](https://github.com/v7b1/mi-UGens/pull/24)) and an
installer that cleans up older copies for you.

## What you get

| Module | What it is |
| --- | --- |
| **MiPlaits** | Plaits: a macro oscillator, 24 kinds of synthesis behind three knobs |
| **MiBraids** | Braids: Plaits' ancestor, a macro oscillator full of character |
| **MiRings** | Rings: a resonator of strings, bells and plates |
| **MiElements** | Elements: a bowed, blown and struck physical model |
| **MiClouds** | Clouds: a granular texture processor (and pitch shifter, looping delay, spectral) |
| **MiBeads** | Beads: Clouds' successor, smoother grains and a reverb |
| **MiWarps** | Warps: a meta-modulator, cross-modulation and vocoding |
| **MiRipples** | Ripples: an analog-style 4-pole filter |
| **MiVerb** | the reverb from Clouds and Rings |
| **MiTides** | Tides: a tidal modulator (LFO, envelope, oscillator) |
| **MiOmi** | Omi: an FM voice from the Shruthi heritage |
| **MiMu** | Mu: µ-law companding, crunchy lo-fi |
| **MiGrids** | Grids: a topographic drum sequencer |

## Install

You need a norns or norns shield with Wi-Fi. Pick one of these; each one moves older mi-UGens
installs aside first, so you never end up with two copies (that stops norns' audio engine from
starting).

**1. Let a script do it.** Scripts that need these modules, like
[terrarium](https://github.com/carlosedp/terrarium), offer to install them the first time you
run them: press K3 when asked.

**2. With the installer script.** Copy [mi-ugens-install.lua](mi-ugens-install.lua) onto your
norns into `dust/code/mi-ugens-install/` (with maiden's file browser, or over SMB), then run
**mi-ugens-install** from SELECT:

- **K3** downloads the latest release and installs it.
- **K2** installs a `mi-UGens-norns*.tar.gz` you copied into `dust/` yourself (no Wi-Fi needed).

The screen shows what's installed now.

**3. Over ssh**, with a tarball from the [releases](https://github.com/carlosedp/norns-mi-UGens/releases)
(`ssh we@norns.local`, the password is `sleep`):

```bash
mkdir /tmp/mi && tar -C /tmp/mi -xzf mi-UGens-norns.tar.gz && /tmp/mi/install.sh /tmp/mi/mi-UGens
```

**Then restart norns:** SYSTEM > RESTART.

### Good to know when installing

- Install this **before** emplaitress, fx_grains or oomph: they download an older mi-UGens copy
  only when they don't find one.
- If pedalboard, krill or schollz's supercollider-plugins offer to install mi-UGens, decline.
- If something already put mi-UGens class files inside `dust/`, the installer warns you about
  them in maiden: remove those, or norns' audio engine may not start.

## Using them

A quick test, from the SuperCollider tab of maiden's REPL after the restart:

```supercollider
x = { MiPlaits.ar(48, engine: 0, harm: 0.3, timbre: 0.5, morph: 0.5) * 0.2 }.play;
x.free;
```

**In a script:** write a normal norns engine (`Engine_Foo.sc` in your script's `lib/`) and use
`MiPlaits`, `MiRings`, `MiElements`… in its SynthDefs, like any other UGen.

**As effects under any script, with the [fx mod](https://llllllll.co/t/fx-mod/62726):**

- **Clouds:** [sixolet/fx_grains](https://github.com/sixolet/fx_grains) already wraps MiClouds.
- **Beads:** [examples/fx_beads](examples/fx_beads) is a ready-to-use fx mod for MiBeads (quality
  modes, time, size, shape, density, pitch, feedback, reverb, freeze and the randomness controls).
  Copy it to `dust/code/fx_beads/`, enable `fx` and `fx_beads` in SYSTEM > MODS, and restart. Its
  params appear under "fx beads" in every script.

The same small pattern (one SuperCollider class and one Lua params file) works for other modules,
like Rings or Warps fed by a send, or MiVerb.

For a tour of norns scripts and mods around these modules, see
[Mods_and_scripts.md](Mods_and_scripts.md).

**In a web page:** each release also carries `mi-UGens-wasm.tar.gz`, seven of them (Plaits,
Rings, Elements, Clouds, Beads, Ripples, Verb) built as WebAssembly: the same code, playing in
any modern browser in an AudioWorklet, with no dependencies. Handy for a demo of a norns script,
a web instrument, or tuning a SynthDef without the device.
[wasm/README.md](wasm/README.md) shows how to use them.

## Things to keep in mind

- **CPU.** The CM3 in norns is a 1.2 GHz quad-core. Elements, Rings and Beads are heavy: a script
  plus one or two of them is a realistic budget. Watch the CPU meter in the norns menu.
- **Memory.** Beads uses about 1 MB of real-time memory per instance, and Clouds uses some too. If
  a synth fails with "alloc failed", that's the limit on your norns.
- **Sample rate.** norns runs at 48 kHz, so Beads in its hi-fi and clean-tape modes runs without
  resampling, its cheapest setting.
- **Something doesn't load?** Please open an issue with what maiden shows, or
  `journalctl -u norns-sclang` over ssh.

---

## Building it yourself

For developers, or to build another mi-UGens fork or branch.

Requirements: `git`, `bash` and `podman` or `docker`. Works on x86_64 Linux, WSL2 and macOS.

```bash
./build.sh --pr 24                                    # upstream main + MiBeads
./deploy.sh dist/mi-UGens-norns-*.tar.gz we@norns.local
```

```bash
./build.sh --repo https://github.com/<you>/mi-UGens --ref my-branch
./build.sh --ref v0.0.9                               # a specific upstream tag
./build.sh --pr 24 --pr 25                            # several upstream PRs
```

`./build.sh --help` lists all options. Each tarball carries a `BUILDINFO` file recording the repo,
commit, merged PRs and SuperCollider header version, so any build can be reproduced.

### On GitHub

The [workflow](.github/workflows/build.yml) runs the same script. Run it from the Actions tab with
a repo, ref and PRs, and download the tarball from the run's artifacts. Pushing a `v*` tag builds
the defaults in the workflow (currently upstream + PR 24) and publishes a release, with the
tarball under the tag's name (`mi-UGens-norns-v1.0.0.tar.gz`) and under the fixed name
`mi-UGens-norns.tar.gz` that installers fetch from the latest release. The WebAssembly build
goes alongside, as `mi-UGens-wasm-v1.0.0.tar.gz` and `mi-UGens-wasm.tar.gz`.

### How it works

- **Cross-compiled in a Debian Buster container** with the `arm-linux-gnueabihf` toolchain. The
  norns image is Raspbian Buster (32-bit armhf), and matching its glibc (2.28) and GCC 8 libstdc++
  is what makes the plugins load. A build from a newer distro links against e.g. `GLIBC_2.29`
  `exp`/`log`/`pow`, and scsynth on norns then refuses to load it.
- Tuned for the Cortex-A53 in CM3/Pi 3 (`-mcpu=cortex-a53 -mfpu=neon-fp-armv8`), which also runs
  on the Pi 4 (Cortex-A72) in a shield. Override in [toolchain-norns.cmake](toolchain-norns.cmake).
- Only SuperCollider's plugin _headers_ are needed (`--sc-version`, default `Version-3.12.2`). The
  plugin API is stable across 3.10–3.13. Check your device with `scsynth -v` if in doubt.
- [scripts/verify.sh](scripts/verify.sh) fails the build if a plugin isn't ARM hard-float or needs
  a glibc newer than 2.28.
- All three install paths run the same [scripts/install.sh](scripts/install.sh), which ships
  inside the tarball. Inside a bundle such as `supercollider-plugins/`, only its mi-UGens
  subfolder is moved aside.

### On the norns itself

`./build.sh --native` skips the container and uses the local compiler, like okyeron's original
`linux-build.sh`. mi-UGens needs CMake ≥ 3.19 and Buster ships 3.13, so first run
`pip3 install --user cmake`. The cross build is much faster.

### In a web browser

`./build.sh --wasm --pr 24` builds seven of them (Plaits, Rings, Ripples, Clouds, Beads, Verb,
Elements) as WebAssembly instead, to play in a web page, in an AudioWorklet: the same code a
norns runs, not an imitation. `work/out-wasm/demo.html` plays them, and
[wasm/README.md](wasm/README.md) has the details: how it's built, the JavaScript API, and how
to turn a SynthDef into nodes.

## Credits and license

All the sound is Émilie Gillet's [Mutable Instruments code](https://github.com/pichenettes/eurorack)
(MIT). SuperCollider versions by [Volker Böhm](https://github.com/v7b1/mi-UGens) (GPL-3.0),
MiBeads by Caleb Crittenden, the original norns builds by
[okyeron](https://github.com/okyeron/mi-UGens), the fx mod by [sixolet](https://github.com/sixolet/fx).

These builds are maintained by Carlos de Paula ([Voltage Foundry Modular](https://vfmod.com)).
Mutable Instruments, monome and norns are trademarks of their respective owners, named here only
to say what these builds are for; no affiliation or endorsement is implied.
