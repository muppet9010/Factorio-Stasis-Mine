local TableUtils = require("utility.helper-utils.table-utils")

local StasisGrenade = TableUtils.DeepCopy(data.raw["projectile"]["grenade"])
StasisGrenade.name = "stasis-grenade"
StasisGrenade.action = {
    type = "direct",
    action_delivery = {
        type = "instant",
        target_effects = {
            {
                type = "nested-result",
                affects_target = true,
                action = {
                    type = "area",
                    radius = settings.startup["stasis_mine-stasis_effect_area"].value,
                    force = settings.startup["stasis_mine-stasis_force_effected"].value,
                    action_delivery = {
                        type = "instant",
                        target_effects = {
                            {
                                type = "script",
                                effect_id = "stasis_affected_target"
                            }
                        }
                    }
                }
            },
            {
                type = "create-smoke",
                entity_name = "stasis_mine-stasis_source_impact_effect",
                starting_frame_deviation = 16
            },
            {
                type = "script",
                effect_id = "stasis_grenade_source"
            }
        }
    }
}

data:extend({
    StasisGrenade
})
