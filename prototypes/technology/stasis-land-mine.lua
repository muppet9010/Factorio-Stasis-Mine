local Constants = require("constants")

data:extend(
    {
        {
            type = "technology",
            name = "stasis-land-mine",
            icon_size = 96,
            icon = Constants.AssetModName .. "/graphics/technology/stasis_land_mine.png",
            effects = {
                {
                    type = "unlock-recipe",
                    recipe = "stasis-land-mine"
                }
            },
            prerequisites = {"land-mine", "effect-transmission"},
            unit = {
                count = 100,
                ingredients = {
                    {"automation-science-pack", 1},
                    {"logistic-science-pack", 1},
                    {"chemical-science-pack", 1},
                    {"production-science-pack", 1},
                    {"military-science-pack", 1}
                },
                time = 30
            },
            order = "e-e"
        }
    }
)
