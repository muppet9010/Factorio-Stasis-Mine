local Utils = require("utility.utils")

local StasisRocket = Utils.DeepCopy(data.raw["projectile"]["rocket"])
StasisRocket.name = "stasis-rocket"
StasisRocket.action = {
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
                type = "create-explosion",
                entity_name = "stasis_mine-stasis_source_impact_effect"
            }
        }
    }
}

data:extend({
    StasisRocket
})
