local Constants = require("constants")
local Sounds = require("__base__.prototypes.entity.sounds")

data:extend(
    {
        {
            type = "capsule",
            name = "stasis-grenade",
            icon = Constants.AssetModName .. "/graphics/item/stasis_grenade.png",
            icon_size = 64,
            icon_mipmaps = 0,
            capsule_action =
            {
                type = "throw",
                attack_parameters =
                {
                    type = "projectile",
                    activation_type = "throw",
                    ammo_category = "stasis-grenade",
                    cooldown = 30,
                    projectile_creation_distance = 0.6,
                    range = 15,
                    ammo_type =
                    {
                        category = "grenade",
                        target_type = "position",
                        action =
                        {
                            {
                                type = "direct",
                                action_delivery =
                                {
                                    type = "projectile",
                                    projectile = "stasis-grenade",
                                    starting_speed = 0.3
                                }
                            },
                            {
                                type = "direct",
                                action_delivery =
                                {
                                    type = "instant",
                                    target_effects =
                                    {
                                        {
                                            type = "play-sound",
                                            sound = Sounds.throw_projectile
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            subgroup = "capsule",
            order = "a[grenade]-c[stasis]",
            stack_size = 100
        }
    }
)
