local Constants = require("constants")

local StasisRocket = {
    type = "ammo",
    name = "stasis-rocket",
    flags = { "hide-from-bonus-gui" },
    icon = Constants.AssetModName .. "/graphics/item/stasis_rocket.png",
    icon_size = 64,
    icon_mipmaps = 0,
    ammo_type =
    {
        category = "rocket",
        action =
        {
            type = "direct",
            action_delivery =
            {
                type = "projectile",
                projectile = "stasis-rocket",
                starting_speed = 0.1,
                source_effects =
                {
                    type = "create-entity",
                    entity_name = "explosion-hit"
                }
            }
        }
    },
    subgroup = "ammo",
    order = "d[rocket-launcher]-c[stasis]",
    stack_size = 200
}

if settings.startup["stasis_mine-disable_stasis_rocket"].value then
    StasisRocket.flags[#StasisRocket.flags] = "hidden"
end

data:extend(
    {
        StasisRocket
    }
)
