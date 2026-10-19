// Mutable Instruments Beads as an fx mod effect (send A/B or insert).
// Requires the fx mod (https://github.com/sixolet/fx) and mi-UGens with MiBeads.
FxBeads : FxBase {

    *new {
        var ret = super.newCopyArgs(nil, \none, (
            pitch: 0,
            pitchRnd: 0,
            time: 0.5,
            timeRnd: 0,
            size: 0.5,
            sizeRnd: 0,
            shape: 0.5,
            shapeRnd: 0,
            density: 0.7,
            feedback: 0,
            reverb: 0,
            freeze: 0,
            quality: 0,
            inGain: 1,
            drywet: 1,
        ), nil, 1);
        ^ret;
    }

    *initClass {
        FxSetup.register(this.new);
    }

    subPath {
        ^"/fx_beads";
    }

    symbol {
        ^\fxBeads;
    }

    addSynthdefs {
        SynthDef(\fxBeads, {|inBus, outBus|
            var input = In.ar(inBus, 2);
            // seed is deliberately not passed: any UGen there counts as "patched"
            // and stops density from generating grains on its own.
            // drywet stays at 1; the fx framework mixes dry/wet for insert slots.
            Out.ar(outBus, MiBeads.ar(
                input,
                pitch: \pitch.kr(0),
                pitch_rnd: \pitchRnd.kr(0),
                time: \time.kr(0.5),
                time_rnd: \timeRnd.kr(0),
                size: \size.kr(0.5),
                size_rnd: \sizeRnd.kr(0),
                shape: \shape.kr(0.5),
                shape_rnd: \shapeRnd.kr(0),
                density: \density.kr(0.7),
                fb: \feedback.kr(0),
                drywet: 1,
                rvb: \reverb.kr(0),
                freeze: \freeze.kr(0),
                seed_btn: 2,
                quality: \quality.kr(0),
                in_gain: \inGain.kr(1),
            ));
        }).add;
    }
}
