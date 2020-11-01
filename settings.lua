data:extend(
    {
        {
            name = "stasis_mine-stasis_force_effected",
            type = "string-setting",
            default_value = "all",
            allowed_values = {"all", "enemy"},
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
        }
    }
)
