local Constants = require("constants")

data:extend(
    {
        {
            type = "technology",
            name = "stasis-grenade",
            icon_size = 96,
            icon = Constants.AssetModName .. "/graphics/technology/stasis_grenade.png",
            effects = {
                {
                    type = "unlock-recipe",
                    recipe = "stasis-grenade"
                }
            },
            prerequisites = { "military-2", "effect-transmission" },
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
            enabled = not settings.startup["stasis_mine-disable_stasis_grenade"].value,
            order = "e-e"
        }
    }
)
