-- fx_beads: Mutable Instruments Beads granular processor for the norns fx mod.
-- Requires the fx mod and mi-UGens (with MiBeads) in SuperCollider Extensions.
local fx = require("fx/lib/fx")
local mod = require 'core/mods'
local hook = require 'core/hook'
local tab = require 'tabutil'
-- Begin post-init hack block (same as other fx mods, for older norns versions)
if hook.script_post_init == nil and mod.hook.patched == nil then
    mod.hook.patched = true
    local old_register = mod.hook.register
    local post_init_hooks = {}
    mod.hook.register = function(h, name, f)
        if h == "script_post_init" then
            post_init_hooks[name] = f
        else
            old_register(h, name, f)
        end
    end
    mod.hook.register('script_pre_init', '!replace init for fake post init', function()
        local old_init = init
        init = function()
            old_init()
            for i, k in ipairs(tab.sort(post_init_hooks)) do
                local cb = post_init_hooks[k]
                print('calling: ', k)
                local ok, error = pcall(cb)
                if not ok then
                    print('hook: ' .. k .. ' failed, error: ' .. error)
                end
            end
        end
    end)
end
-- end post-init hack block


local FxBeads = fx:new {
    subpath = "/fx_beads"
}

function FxBeads:add_params()
    params:add_separator("fx_beads", "fx beads")
    FxBeads:add_slot("fx_beads_slot", "slot")
    params:add_option("fx_beads_quality", "quality", {
        "hi-fi",
        "vintage digital",
        "clean tape",
        "dirty tape",
    }, 1)
    params:set_action("fx_beads_quality", function(q)
        osc.send({ "localhost", 57120 }, self.subpath .. "/set", { "quality", q - 1 })
    end)
    FxBeads:add_control("fx_beads_time", "time", "time", controlspec.new(0, 1, 'lin', 0, 0.5))
    FxBeads:add_control("fx_beads_size", "size", "size", controlspec.new(0, 1, 'lin', 0, 0.5))
    FxBeads:add_control("fx_beads_shape", "shape", "shape", controlspec.new(0, 1, 'lin', 0, 0.5))
    FxBeads:add_control("fx_beads_density", "density", "density", controlspec.new(0, 1, 'lin', 0, 0.7))
    FxBeads:add_control("fx_beads_pitch", "pitch", "pitch", controlspec.new(-24, 24, 'lin', 0, 0, 'st'))
    FxBeads:add_control("fx_beads_feedback", "feedback", "feedback", controlspec.new(0, 1, 'lin', 0, 0))
    FxBeads:add_control("fx_beads_reverb", "reverb", "reverb", controlspec.new(0, 1, 'lin', 0, 0))
    FxBeads:add_control("fx_beads_freeze", "freeze", "freeze", controlspec.new(0, 1, 'lin', 1, 0))
    FxBeads:add_taper("fx_beads_in_gain", "input gain", "inGain", 0, 4, 1, 2)
    params:add_group("fx_beads_rnd", "randomness", 4)
    for _, things in pairs {
        {"pitchRnd", "pitch_rnd", "pitch rnd"},
        {"timeRnd", "time_rnd", "time rnd"},
        {"sizeRnd", "size_rnd", "size rnd"},
        {"shapeRnd", "shape_rnd", "shape rnd"},
    } do
        local key, id, text = things[1], things[2], things[3]
        FxBeads:add_control("fx_beads_"..id, text, key, controlspec.new(-1, 1, 'lin', 0, 0))
    end
end

mod.hook.register("script_post_init", "fx beads mod post init", function()
    FxBeads:add_params()
end)

mod.hook.register("system_post_startup", "fx beads post startup", function()
    local ok = os.execute('test -n "$(find /home/we/.local/share/SuperCollider/Extensions/ -name MiBeads.sc)"')
    if not ok then
        print("fx beads: MiBeads not found in SuperCollider Extensions; install a mi-UGens build with MiBeads")
    end
end)

return FxBeads
