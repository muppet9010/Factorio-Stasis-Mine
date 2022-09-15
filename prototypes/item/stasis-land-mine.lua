local Constants = require("constants")

local StasisLandMine = {
    type = "item",
    name = "stasis-land-mine",
    flags = {},
    icon = Constants.AssetModName .. "/graphics/item/stasis_land_mine.png",
    icon_size = 64,
    icon_mipmaps = 0,
    subgroup = "gun",
    order = "f[land-mine]1",
    place_result = "stasis-land-mine",
    stack_size = 100
}


if settings.startup["stasis_mine-disable_stasis_mine"].value then
    StasisLandMine.flags[#StasisLandMine.flags] = "hidden"
end

data:extend(
    {
        StasisLandMine
    }
)
