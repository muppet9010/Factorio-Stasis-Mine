local Constants = require("constants")

data:extend(
    {
        {
            type = "item",
            name = "stasis-land-mine",
            icon = Constants.AssetModName .. "/graphics/item/stasis_land_mine.png",
            icon_size = 64,
            icon_mipmaps = 0,
            subgroup = "gun",
            order = "f[land-mine]1",
            place_result = "stasis-land-mine",
            stack_size = 100
        }
    }
)
