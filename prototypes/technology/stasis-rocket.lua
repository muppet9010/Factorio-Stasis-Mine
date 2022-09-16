local Constants = require("constants")

data:extend(
    {
        {
            type = "technology",
            name = "stasis-rocket",
            icon_size = 96,
            icon = Constants.AssetModName .. "/graphics/technology/stasis_rocket.png",
            effects = {
                {
                    type = "unlock-recipe",
                    recipe = "stasis-rocket"
                }
            },
            prerequisites = { "rocketry", "effect-transmission" },
            unit = {
                count = 100,
                ingredients = {
                    { "automation-science-pack", 1 },
                    { "logistic-science-pack", 1 },
                    { "chemical-science-pack", 1 },
                    { "production-science-pack", 1 },
                    { "military-science-pack", 1 }
                },
                time = 30
            },
            enabled = not settings.startup["stasis_mine-disable_stasis_rocket"].value,
            order = "e-e"
        }
    }
)
