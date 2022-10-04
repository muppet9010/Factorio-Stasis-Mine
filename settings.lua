data:extend(
    {
        {
            name = "stasis_mine-stasis_force_effected",
            type = "string-setting",
            default_value = "all",
            allowed_values = { "all", "enemy" },
            setting_type = "startup",
            order = "1001"
        },
        {
            name = "stasis_mine-stasis_time",
            type = "int-setting",
            default_value = 20,
            minimum_value = 5,
            setting_type = "startup",
            order = "1002"
        },
        {
            name = "stasis_mine-disable_stasis_mine",
            type = "bool-setting",
            default_value = false,
            setting_type = "startup",
            order = "2000"
        },
        {
            name = "stasis_mine-disable_stasis_rocket",
            type = "bool-setting",
            default_value = false,
            setting_type = "startup",
            order = "2000"
        },
        {
            name = "stasis_mine-disable_stasis_grenade",
            type = "bool-setting",
            default_value = false,
            setting_type = "startup",
            order = "2000"
        }
    }
)

data:extend(
    {
        {
            name = "stasis_mine-trains_affected",
            type = "bool-setting",
            default_value = true,
            setting_type = "runtime-global",
            order = "1001"
        }
    }
)
