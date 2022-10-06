local Constants = require("constants")
local Sounds = require("__base__.prototypes.entity.sounds")


local StasisGrenade = {
    type = "capsule",
    name = "stasis-grenade",
    flags = {},
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
            cooldown = 30,
            projectile_creation_distance = 0.6,
            range = 15,
            ammo_type =
            {
                category = "stasis",
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

if settings.startup["stasis_mine-disable_stasis_grenade"].value then
    StasisGrenade.flags[#StasisGrenade.flags] = "hidden"
end

data:extend(
    {
        StasisGrenade
    }
)
