local Utils = require("utility/utils")
local Constants = require("constants")

local StasisLandMineLightColor = { r = 40, g = 210, b = 210 } ---@type Color.1

-- The visual effect done on an affected entity for the duration of the effect.
local targetEffect = {
    type = "explosion",
    name = "stasis_mine-stasis_target_impact_effect",
    animations = {
        filename = Constants.AssetModName .. "/graphics/entity/stasis_entity_affected-hr.png",
        flags = { "trilinear-filtering" },
        line_length = 4,
        width = 364,
        height = 372,
        frame_count = 16,
        tint = nil,
        scale = 0.5,
        animation_speed = 240 / (tonumber(settings.startup["stasis_mine-stasis_time"].value) * 60),
        repeat_count = 15 -- TODO: must be below 255. But can only make time by making animation slower and slower.
    },
    fade_in_duration = 120,
    fade_away_duration = 30,
    light = {
        -- The lights need to be a much bigger size than the area due to how they fade.
        { intensity = 0.5, size = 8, color = StasisLandMineLightColor },
    }
}

-- The initial detonation effect done where the stasis weapon goes off to cover its affected area briefly.
local sourceEffect = {
    type = "explosion",
    name = "stasis_mine-stasis_source_impact_effect",
    animations = {
        filename = Constants.AssetModName .. "/graphics/entity/stasis_detonation_effect-hr.png",
        flags = { "trilinear-filtering" },
        line_length = 4,
        width = 364,
        height = 372,
        frame_count = 16,
        tint = nil,
        scale = tonumber(settings.startup["stasis_mine-stasis_effect_area"].value) / 2,
        repeat_count = 2 --32 ticks
    },
    fade_in_duration = 10,
    fade_away_duration = 10,
    scale_initial = 0.5 / 4,
    scale_in_duration = 20,
    light = {
        -- The lights need to be a much bigger size than the area due to how they fade.
        { intensity = 0.5, size = (settings.startup["stasis_mine-stasis_effect_area"].value) * 10, color = StasisLandMineLightColor }
    },
    light_size_factor_initial = 0.5,
    light_size_factor_final = 1
}

-- The effect when a landmine dies. Shows a small stasis effect when a landmine is killed, like its done a mini failed stasis detonation.
local dyingEffect = Utils.DeepCopy(targetEffect)
dyingEffect.name = "stasis_mine-stasis_dying_effect"
dyingEffect.animations.repeat_count = 2 -- 32 ticks
dyingEffect.fade_in_duration = 10
dyingEffect.fade_away_duration = 10

-- The small regular explosion for when the landmine detonates.
local dyingExplosion = Utils.DeepCopy(data.raw.explosion.explosion)
dyingExplosion.name = "stasis_min-stasis_dying_explosion"
dyingExplosion.animations = dyingExplosion.animations[1]
dyingExplosion.animations.shift = { 0, 1 }
dyingExplosion.animations.hr_version.shift = { 0, 1 }

data:extend(
    {
        targetEffect,
        sourceEffect,
        dyingEffect,
        dyingExplosion
    }
)
