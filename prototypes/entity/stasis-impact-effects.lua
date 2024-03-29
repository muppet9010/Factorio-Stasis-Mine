local TableUtils = require("utility.helper-utils.table-utils")
local Constants = require("constants")

-- The visual effect done on an affected entity for the duration of the effect.
-- Is the small one now. Kept as old name for backwards compatibility.
local targetEffect = {
    type = "smoke-with-trigger",
    name = "stasis_mine-stasis_target_impact_effect",
    flags = { "placeable-off-grid" },
    animation = {
        filename = Constants.AssetModName .. "/graphics/entity/stasis_impact_effect-hr.png",
        flags = { "trilinear-filtering" },
        line_length = 4,
        width = 364,
        height = 372,
        frame_count = 16,
        scale = 1 / 4
    },
    duration = tonumber(settings.startup["stasis_mine-stasis_time"].value) * 60,
    fade_in_duration = 120,
    fade_away_duration = 30,
    movement_slow_down_factor = 0,
    cyclic = true,
    affected_by_wind = false,
    show_when_smoke_off = true
}

-- The other size variations of the target effect.
local targetEffect_medium = TableUtils.DeepCopy(targetEffect)
targetEffect_medium.name = "stasis_mine-stasis_target_impact_effect-medium"
targetEffect_medium.animation.scale = 0.5

local targetEffect_large = TableUtils.DeepCopy(targetEffect)
targetEffect_large.name = "stasis_mine-stasis_target_impact_effect-large"
targetEffect_large.animation.scale = 1

local targetEffect_huge = TableUtils.DeepCopy(targetEffect)
targetEffect_huge.name = "stasis_mine-stasis_target_impact_effect-huge"
targetEffect_huge.animation.scale = 1.5

-- The initial detonation effect done where the stasis weapon goes off to cover its affected area briefly.
local sourceEffect = TableUtils.DeepCopy(targetEffect)
sourceEffect.name = "stasis_mine-stasis_source_impact_effect"
sourceEffect.animation.scale = tonumber(settings.startup["stasis_mine-stasis_effect_area"].value) / 2.5
sourceEffect.duration = 30
sourceEffect.fade_in_duration = 0 -- Effect is so quick that fade in/out isn't visible to players.
sourceEffect.fade_away_duration = 0 -- Effect is so quick that fade in/out isn't visible to players.

-- The initial detonation animation used by dynamically scaled cases. Is scaled at usage time.
-- The animation graphic is made transparent like the smoke picture is automatically.
local stasis_source_impact_animation = {
    type = "animation",
    name = "stasis_source_impact_animation",
    filename = Constants.AssetModName .. "/graphics/entity/stasis_impact_effect_animation-hr.png",
    flags = { "trilinear-filtering" },
    line_length = 4,
    width = 364,
    height = 372,
    frame_count = 16
}

-- The effect when a landmine dies. Shows a small stasis effect when a landmine is killed, like its done a mini failed stasis detonation.
local dyingEffect = TableUtils.DeepCopy(targetEffect)
dyingEffect.name = "stasis_mine-stasis_dying_effect"
dyingEffect.duration = 30
dyingEffect.fade_in_duration = 0 -- Effect is so quick that fade in/out isn't visible to players.
dyingEffect.fade_away_duration = 0 -- Effect is so quick that fade in/out isn't visible to players.

-- The small regular explosion for when the landmine detonates.
local dyingExplosion = TableUtils.DeepCopy(data.raw.explosion.explosion)
dyingExplosion.name = "stasis_min-stasis_dying_explosion"
dyingExplosion.animations = dyingExplosion.animations[1]
dyingExplosion.animations.shift = { 0, 1 }
dyingExplosion.animations.hr_version.shift = { 0, 1 }


-- Legacy effect we need for upgrades that have stasis effects still running from pre-upgrade.
local targetEffect_legacy = {
    type = "trivial-smoke",
    name = "stasis_mine-stasis_target_impact_effect",
    animation = {
        filename = Constants.AssetModName .. "/graphics/entity/stasis_impact_effect-legacy.png",
        flags = { "trilinear-filtering" },
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
    movement_slow_down_factor = 0,
    cyclic = true,
    affected_by_wind = false,
    show_when_smoke_off = true
}



data:extend(
    {
        targetEffect,
        targetEffect_medium,
        targetEffect_large,
        targetEffect_huge,
        sourceEffect,
        stasis_source_impact_animation,
        dyingEffect,
        dyingExplosion,
        targetEffect_legacy
    }
)
