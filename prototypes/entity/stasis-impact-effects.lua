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
sourceEffect.animation.scale = 6
sourceEffect.duration = 30
sourceEffect.start_scale = 0.5
sourceEffect.fade_in_duration = 10
sourceEffect.fade_away_duration = 10

local dyingEffect = Utils.DeepCopy(targetEffect)
dyingEffect.name = "stasis_mine-stasis_dying_effect"
dyingEffect.duration = 30
dyingEffect.start_scale = 0.5
dyingEffect.fade_in_duration = 10
dyingEffect.fade_away_duration = 10

local dyingExplosion = Utils.DeepCopy(data.raw.explosion.explosion)
dyingExplosion.name = "stasis_min-stasis_dying_explosion"
dyingExplosion.animations = dyingExplosion.animations[1]
dyingExplosion.animations.shift = {0, 1}
dyingExplosion.animations.hr_version.shift = {0, 1}

data:extend(
    {
        targetEffect,
        sourceEffect,
        dyingEffect,
        dyingExplosion
    }
)
