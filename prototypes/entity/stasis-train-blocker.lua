local Constants = require("constants")

data:extend(
    {
        {
            type = "simple-entity",
            name = "stasis-train-blocker",
            flags = { "not-repairable", "not-on-map", "not-blueprintable", "not-deconstructable", "not-flammable", "placeable-off-grid" },
            collision_box = { { -0.1, -0.1 }, { 0.1, 0.1 } },
            collision_mask = { "train-layer" },
            picture = {
                filename = "__core__/graphics/empty.png",
                width = 1,
                height = 1
            }
        }
    }
)
