local landmineEntityRef = data.raw["land-mine"]["land-mine"]
data:extend(
    {
        {
            type = "land-mine",
            name = "stasis-land-mine",
            icon = "__base__/graphics/icons/land-mine.png",
            icon_size = 64,
            icon_mipmaps = 4,
            flags = {
                "placeable-player",
                "placeable-enemy",
                "player-creation",
                "placeable-off-grid",
                "not-on-map"
            },
            minable = {mining_time = 0.5, result = "land-mine"},
            mined_sound = {filename = "__core__/sound/deconstruct-small.ogg"},
            max_health = 15,
            corpse = "land-mine-remnants",
            --dying_explosion = "land-mine-explosion",
            collision_box = {{-0.4, -0.4}, {0.4, 0.4}},
            selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
            damaged_trigger_effect = landmineEntityRef.damaged_trigger_effect,
            open_sound = landmineEntityRef.open_sound,
            close_sound = landmineEntityRef.close_sound,
            picture_safe = {
                filename = "__base__/graphics/entity/land-mine/hr-land-mine.png",
                priority = "medium",
                width = 64,
                height = 64,
                scale = 0.5
            },
            picture_set = {
                filename = "__base__/graphics/entity/land-mine/hr-land-mine-set.png",
                priority = "medium",
                width = 64,
                height = 64,
                scale = 0.5
            },
            picture_set_enemy = {
                filename = "__base__/graphics/entity/land-mine/land-mine-set-enemy.png",
                priority = "medium",
                width = 32,
                height = 32
            },
            trigger_radius = 2.5,
            ammo_category = "landmine",
            action = {
                type = "direct",
                action_delivery = {
                    type = "instant",
                    source_effects = {
                        {
                            type = "nested-result",
                            affects_target = true,
                            action = {
                                type = "area",
                                radius = 6,
                                --force = "enemy",
                                action_delivery = {
                                    type = "instant",
                                    target_effects = {
                                        {
                                            type = "script",
                                            effect_id = "stasis-land-mine"
                                        }
                                    }
                                }
                            }
                        }
                        --[[{
                            type = "create-entity",
                            entity_name = "explosion"
                        },
                        {
                            type = "damage",
                            damage = {amount = 1000, type = "explosion"}
                        }--]]
                    }
                }
            }
        }
    }
)
