local Utils = require("utility/utils")
local Constants = require("constants")

local targetEffect = {
    type = "trivial-smoke",
    name = "stasis_mine-stasis_target_impact_effect",
    animation = {
        filename = Constants.AssetModName .. "/graphics/entity/stasis_impact_effect.png",
        flags = {"trilinear-filtering"},
        line_length = 4,
        width = 91,
        height = 93,
        frame_count = 16,
        direction_count = 1,
        tint = nil,
        scale = 1
    },
    duration = tonumber(settings.startup["stasis_mine-stasis_time"].value) * 60,
    fade_in_duration = 120,
    fade_away_duration = 30,
    movement_slow_down_factor = 1,
    cyclic = true,
    affected_by_wind = false,
    show_when_smoke_off = true
}

local sourceEffect = Utils.DeepCopy(targetEffect)
sourceEffect.name = "stasis_mine-stasis_source_impact_effect"
sourceEffect.animation.scale = 4
sourceEffect.duration = 90
sourceEffect.start_scale = 0.5
sourceEffect.fade_in_duration = 10
sourceEffect.fade_away_duration = 30

data:extend(
    {
        targetEffect,
        sourceEffect
    }
)
