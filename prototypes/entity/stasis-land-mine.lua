local Constants = require("constants")

local landmineEntityRef = data.raw["land-mine"]["land-mine"]
data:extend(
    {
        {
            type = "land-mine",
            name = "stasis-land-mine",
            icon = Constants.AssetModName .. "/graphics/item/stasis_land_mine.png",
            icon_size = 64,
            icon_mipmaps = 0,
            flags = {
                "placeable-player",
                "placeable-enemy",
                "player-creation",
                "placeable-off-grid",
                "not-on-map",
                "hidden"
            },
            minable = { mining_time = 0.5, result = "stasis-land-mine" },
            mined_sound = { filename = "__core__/sound/deconstruct-small.ogg" },
            max_health = 15,
            corpse = "stasis-land-mine-remnants",
            random_corpse_variation = true,
            dying_explosion = "stasis_min-stasis_dying_explosion",
            dying_trigger_effect = {
                type = "create-entity",
                entity_name = "stasis_mine-stasis_dying_effect"
            },
            collision_box = { { -0.4, -0.4 }, { 0.4, 0.4 } },
            selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
            damaged_trigger_effect = landmineEntityRef.damaged_trigger_effect,
            open_sound = landmineEntityRef.open_sound,
            close_sound = landmineEntityRef.close_sound,
            picture_safe = {
                filename = Constants.AssetModName .. "/graphics/entity/stasis_land_mine.png",
                priority = "medium",
                width = 64,
                height = 85,
                scale = 0.5,
                shift = { 0, -0.175 }
            },
            picture_set = {
                filename = Constants.AssetModName .. "/graphics/entity/stasis_land_mine_set.png",
                priority = "medium",
                width = 64,
                height = 85,
                scale = 0.5,
                shift = { 0, -0.175 }
            },
            picture_set_enemy = {
                filename = "__base__/graphics/entity/land-mine/land-mine-set-enemy.png",
                priority = "medium",
                width = 32,
                height = 32
            },
            trigger_radius = 2.5,
            timeout = 600,
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
                                radius = settings.startup["stasis_mine-stasis_effect_area"].value,
                                force = settings.startup["stasis_mine-stasis_force_effected"].value,
                                action_delivery = {
                                    type = "instant",
                                    target_effects = {
                                        {
                                            type = "script",
                                            effect_id = "stasis_affected_target"
                                        }
                                    }
                                }
                            }
                        },
                        {
                            type = "create-explosion",
                            entity_name = "stasis_mine-stasis_source_impact_effect"
                        }
                    }
                }
            }
        },
        {
            type = "corpse",
            name = "stasis-land-mine-remnants",
            icon = Constants.AssetModName .. "/graphics/item/stasis_land_mine.png",
            icon_size = 64,
            icon_mipmaps = 0,
            flags = { "placeable-neutral", "not-on-map" },
            subgroup = "defensive-structure-remnants",
            order = "a-i-a2",
            selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
            tile_width = 1,
            tile_height = 1,
            selectable_in_game = false,
            time_before_removed = 60 * 60 * 15, -- 15 minutes
            final_render_layer = "remnants",
            remove_on_tile_placement = false,
            animation = {
                {
                    filename = Constants.AssetModName .. "/graphics/entity/stasis_land_mine_remnants.png",
                    x = 0,
                    y = 0,
                    width = 134,
                    height = 130,
                    frame_count = 1,
                    axially_symmetrical = false,
                    direction_count = 1,
                    shift = util.by_pixel(1.5, 5),
                    scale = 0.5
                },
                {
                    filename = Constants.AssetModName .. "/graphics/entity/stasis_land_mine_remnants.png",
                    x = 0,
                    y = 130,
                    width = 134,
                    height = 130,
                    frame_count = 1,
                    axially_symmetrical = false,
                    direction_count = 1,
                    shift = util.by_pixel(1.5, 5),
                    scale = 0.5
                },
                {
                    filename = Constants.AssetModName .. "/graphics/entity/stasis_land_mine_remnants.png",
                    x = 0,
                    y = 260,
                    width = 134,
                    height = 130,
                    frame_count = 1,
                    axially_symmetrical = false,
                    direction_count = 1,
                    shift = util.by_pixel(1.5, 5),
                    scale = 0.5
                }
            }
        }
    }
)
