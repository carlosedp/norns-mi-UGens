# norns-mi-UGens

Build [mi-UGens](https://github.com/v7b1/mi-UGens) (Volker Böhm's SuperCollider ports of
Mutable Instruments modules) for [monome norns](https://monome.org/docs/norns/) and norns shield.

This picks up where [okyeron/mi-UGens](https://github.com/okyeron/mi-UGens) left off. Instead of
maintaining a fork of the sources, it builds any mi-UGens repo/branch (upstream or your own fork),
optionally with GitHub PRs merged on top, and produces a tarball ready to drop into norns.

Current upstream + [PR #24](https://github.com/v7b1/mi-UGens/pull/24) builds 13 UGens:
MiBeads, MiBraids, MiClouds, MiElements, MiGrids, MiMu, MiOmi, MiPlaits, MiRings, MiRipples,
MiTides, MiVerb, MiWarps.

## Quick start

Requirements: `git`, `bash` and `podman` or `docker`. Works on x86_64 Linux, WSL2 and macOS.

```bash
./build.sh --pr 24                                    # upstream main + MiBeads PR
./deploy.sh dist/mi-UGens-norns-*.tar.gz we@norns.local
```

Then restart norns (SYSTEM > RESTART). The default ssh password on norns is `sleep`.

### Building your fork

```bash
./build.sh --repo https://github.com/<you>/mi-UGens --ref my-branch
./build.sh --ref v0.0.9                               # a specific upstream tag
./build.sh --pr 24 --pr 25                            # several upstream PRs
```

`./build.sh --help` lists all options. The build is reproducible from the `BUILDINFO` file inside
the tarball, which records repo, commit, merged PRs and SC header version.

### Building on GitHub

The [workflow](.github/workflows/build.yml) runs the same script. Trigger it from the Actions tab
(Run workflow) with repo/ref/PRs as inputs and download the tarball from the run's artifacts.
Pushing a `v*` tag to this repo attaches the tarball to a release.

## How it works

- **Cross-compiled in a Debian Buster container** with the `arm-linux-gnueabihf` toolchain. The
  norns image is Raspbian Buster (32-bit armhf), and matching its glibc (2.28) and GCC 8
  libstdc++ is what makes the plugins load. A build from a newer distro links against e.g.
  `GLIBC_2.29` `exp`/`log`/`pow`, and scsynth on norns then refuses to load it.
- Tuned for the Cortex-A53 in CM3/Pi 3 (`-mcpu=cortex-a53 -mfpu=neon-fp-armv8`), which also
  runs on the Pi 4 (Cortex-A72) in a shield. Override in [toolchain-norns.cmake](toolchain-norns.cmake).
- Only SuperCollider's plugin *headers* are needed (`--sc-version`, default `Version-3.12.2`).
  The plugin API is stable across 3.10–3.13. Check your device with `scsynth -v` if in doubt.
- [scripts/verify.sh](scripts/verify.sh) fails the build if a plugin isn't ARM hard-float or
  needs a glibc newer than 2.28.

### Building on the norns itself

`./build.sh --native` skips the container and uses the local compiler, like Okyeron's original
`linux-build.sh`. mi-UGens needs CMake ≥ 3.19, but Buster ships 3.13, so first run
`pip3 install --user cmake`. The cross build is much faster.

## Other ways to install

All three run the same [scripts/install.sh](scripts/install.sh), which ships inside the tarball.

**From the norns itself.** Copy [mi-ugens-install.lua](mi-ugens-install.lua) to
`dust/code/mi-ugens-install/` (maiden upload or SMB) and run it from SELECT:

- **K3** downloads `mi-UGens-norns.tar.gz` from the latest GitHub release of `REPO`
  (set at the top of the script) and installs it.
- **K2** installs the newest `mi-UGens-norns*.tar.gz` you've copied into `dust/`. No network needed.

The screen shows the installed build (from `BUILDINFO`). Restart afterwards.

**Manually over ssh:**

```bash
scp dist/mi-UGens-norns-*.tar.gz we@norns.local:
ssh we@norns.local
mkdir /tmp/mi && tar -C /tmp/mi -xzf mi-UGens-norns-*.tar.gz && /tmp/mi/install.sh /tmp/mi/mi-UGens
```

### Releases

Push a `v*` tag to publish a GitHub release with the tarball, under both its versioned name and the
fixed name `mi-UGens-norns.tar.gz` that the installer script fetches. Tag builds use the
`DEFAULT_*` values in the [workflow](.github/workflows/build.yml) (currently upstream + PR 24).

**Remove older mi-UGens installs first.** Okyeron's tarball, or a copy auto-installed by a script
such as fx_grains, puts a second `MiPlaits.sc` etc. on the class path. sclang fails on duplicate
classes and norns comes up with no audio engine. `deploy.sh` moves any older install in Extensions
to `~/mi-UGens-backup-<date>/` and warns about mi-UGens class files bundled inside `~/dust`.
Inside a bundle such as `supercollider-plugins/`, only the mi-UGens subfolder is moved.

Install this build *before* emplaitress, fx_grains or oomph. They download an older mi-UGens
copy only when `MiPlaits.sc` is missing from Extensions. If pedalboard, krill or schollz's
supercollider-plugins offer to install mi-UGens, decline.

## Using the UGens

Quick test from the maiden SuperCollider REPL after a restart:

```supercollider
x = { MiPlaits.ar(48, engine: 0, harm: 0.3, timbre: 0.5, morph: 0.5) * 0.2 }.play;
x.free;
```

### As sound sources (engines)

Write a normal norns engine (`Engine_Foo.sc` in your script's `lib/`) and use `MiPlaits`,
`MiElements`, `MiRings`, `MiBraids`, … in its SynthDefs. They are ordinary UGens once installed.

### As effects with the fx mod

The [fx mod](https://llllllll.co/t/fx-mod/62726) runs SuperCollider effects as send A/B or insert
slots under *any* norns script. Each effect is its own small mod:

- **Clouds**: [sixolet/fx_grains](https://github.com/sixolet/fx_grains) already wraps MiClouds.
- **Beads**: [examples/fx_beads](examples/fx_beads) is a ready-to-use fx mod for MiBeads, with
  quality mode, time/size/shape/density/pitch, feedback, reverb, freeze, input gain and the four
  randomness controls. Install it as a mod:

  ```bash
  scp -r examples/fx_beads we@norns.local:dust/code/
  ```

  Then enable both `fx` and `fx_beads` in SYSTEM > MODS and restart. The params show up under
  "fx beads" in every script. Pick a slot and send audio to it.

The same ~80 lines (one `FxBase` subclass in SC and one Lua params file) work for other
processors, e.g. MiRings or MiWarps fed by the send bus, or MiVerb.

## Caveats

- **CPU.** The CM3 in norns is a 1.2 GHz quad-core A53. Elements, Rings and Beads are heavy, so
  a script plus one or two of them is a realistic budget. Watch the CPU meter in the norns menu.
- **Memory.** MiBeads allocates ~1 MB of real-time memory per instance and MiClouds also uses
  RT memory. If a synth fails with "alloc failed", the scsynth `memSize` on your norns is the limit.
- **Sample rate.** norns runs at 48 kHz, so Beads in quality 0 (hi-fi) and 2 (clean tape) runs
  without resampling, which is the cheapest setting.
- Not yet tested on hardware by this repo: the binaries pass the ABI/glibc checks, but please
  report anything that fails to load (`journalctl -u norns-sclang` / maiden output).

## Credits

All DSP is Émilie Gillet's [Mutable Instruments code](https://github.com/pichenettes/eurorack).
SuperCollider ports by [Volker Böhm](https://github.com/v7b1/mi-UGens), MiBeads by Caleb
Crittenden, original norns builds by [Okyeron](https://github.com/okyeron/mi-UGens), fx mod by
[sixolet](https://github.com/sixolet/fx). Licensed GPL-3.0 (mi-UGens) / MIT (Mutable sources).
