local StasisLandMine = {}
local Events = require("utility/events")
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")

---@alias Identifier uint|string

---@class AffectedEntityDetails
---@field unfreezeTick uint
---@field wasActive boolean
---@field wasDestructible boolean
---@field oldSpeed float
---@field oldOperable boolean
---@field oldMinable boolean

---@class FreezeVehicleDetails
---@field entity LuaEntity
---@field unfreezeTick uint
---@field vehicleType string

---@class UnfreezeEntityDetails
---@field entity LuaEntity
---@field identifier Identifier

local StasisLandMineLightColor = { r = 40, g = 210, b = 210 } ---@type Color.1

StasisLandMine.CreateGlobals = function()
    global.stasisLandMine = global.stasisLandMine or {} ---@class Global_StasisLandMine # Used by the StasisLandMine for its own global data.
    global.stasisLandMine.affectedEntities = global.stasisLandMine.affectedEntities or {} ---@type table<Identifier ,AffectedEntityDetails>
    global.stasisLandMine.nextSchedulerId = global.stasisLandMine.nextSchedulerId or 0 ---@type uint
    global.stasisLandMine.stasisAffectTime = global.stasisLandMine.stasisAffectTime or 0 ---@type uint
end

StasisLandMine.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_script_trigger_effect, "StasisLandMine.OnScriptTriggerEffect", StasisLandMine.OnScriptTriggerEffect)
    EventScheduler.RegisterScheduler()
    EventScheduler.RegisterScheduledEventType("StasisLandMine.RemoveStasisFromTarget", StasisLandMine.RemoveStasisFromTarget)
    EventScheduler.RegisterScheduledEventType("StasisLandMine.FreezeVehicle", StasisLandMine.FreezeVehicle)
end

StasisLandMine.OnStartup = function()
    global.stasisLandMine.stasisAffectTime = tonumber(settings.startup["stasis_mine-stasis_time"].value) --[[@as uint]] * 60

    -- Ensure any disabled stasis weapon types are applied to forces. They might have been enabled before and are now disabled.
    if settings.startup["stasis_mine-disable_stasis_mine"].value --[[@as boolean]] then
        StasisLandMine.DisableStasisWeaponType("stasis-land-mine")
    end
    if settings.startup["stasis_mine-disable_stasis_rocket"].value --[[@as boolean]] then
        StasisLandMine.DisableStasisWeaponType("stasis-rocket")
    end
    if settings.startup["stasis_mine-disable_stasis_grenade"].value --[[@as boolean]] then
        StasisLandMine.DisableStasisWeaponType("stasis-grenade")
    end
end

---  Disable the technology and recipe of the stasis weapon name.
---@param name string # The same name for both the technology and recipe.
StasisLandMine.DisableStasisWeaponType = function(name)
    for _, force in pairs(game.forces) do
        -- Disable the technology if it exists.
        local technology = force.technologies[name]
        if technology ~= nil then
            technology.researched = false -- Un-researches it if already done.
            technology.enabled = false -- Stops it being researched again.
        end
    end
end

--- Called when any Lua Script Trigger effect occurs. Find if it's one of ours and call the handler if so.
---@param event EventData.on_script_trigger_effect
StasisLandMine.OnScriptTriggerEffect = function(event)
    if event.effect_id == "stasis_affected_target" and event.target_entity ~= nil then
        StasisLandMine.ApplyStasisToTarget(event.target_entity)
    elseif event.effect_id == "stasis_land_mine_source" then
        rendering.draw_light({ sprite = "utility/light_medium", target = event.source_entity.position, surface = event.surface_index, time_to_live = 5, color = StasisLandMineLightColor, scale = 2.0 })
        rendering.draw_light({ sprite = "utility/light_medium", target = event.source_entity.position, surface = event.surface_index, time_to_live = 45, color = StasisLandMineLightColor, scale = 3.0, intensity = 0.5 })
    elseif event.effect_id == "stasis_rocket_source" then
        -- CODE NOTE: `event.source_entity` is only populated if the target is still alive at the time of rocket detonation. `event.target_position` is always populated where the rocket explodes.
        rendering.draw_light({ sprite = "utility/light_medium", target = event.target_position, surface = event.surface_index, time_to_live = 5, color = StasisLandMineLightColor, scale = 2.0 })
        rendering.draw_light({ sprite = "utility/light_medium", target = event.target_position, surface = event.surface_index, time_to_live = 45, color = StasisLandMineLightColor, scale = 3.0, intensity = 0.5 })
    elseif event.effect_id == "stasis_grenade_source" then
        rendering.draw_light({ sprite = "utility/light_medium", target = event.target_position, surface = event.surface_index, time_to_live = 5, color = StasisLandMineLightColor, scale = 2.0 })
        rendering.draw_light({ sprite = "utility/light_medium", target = event.target_position, surface = event.surface_index, time_to_live = 45, color = StasisLandMineLightColor, scale = 3.0, intensity = 0.5 })
    end
end

--- Apply the stasis effect to an entity caught in the blast.
---@param entity LuaEntity
StasisLandMine.ApplyStasisToTarget = function(entity)
    local entity_type = entity.type

    -- Exclude some entities from being affected.
    if entity.name == "stasis-land-mine" or entity_type == "spider-leg" then
        return
    end

    -- Only affect units not already in a stasis.
    local identifier = StasisLandMine.MakeEntityIdentifier(entity)
    if global.stasisLandMine.affectedEntities[identifier] ~= nil then
        return
    end

    local tick = game.tick
    global.stasisLandMine.nextSchedulerId = global.stasisLandMine.nextSchedulerId + 1
    local unfreezeTick = tick + global.stasisLandMine.stasisAffectTime
    EventScheduler.ScheduleEvent(unfreezeTick, "StasisLandMine.RemoveStasisFromTarget", global.stasisLandMine.nextSchedulerId, { entity = entity, identifier = identifier })
    global.stasisLandMine.affectedEntities[identifier] = { unfreezeTick = unfreezeTick, wasActive = entity.active, wasDestructible = entity.destructible, oldSpeed = entity.speed, oldOperable = entity.operable, oldMinable = entity.minable }

    -- Disable everything other than train carriages. As when train carriages become active again they have weird effects on the overall trains speed and direction.
    if entity_type ~= "locomotive" or entity_type == "cargo-wagon" or entity_type == "fluid-wagon" or entity_type == "artillery-wagon" then
        entity.active = false
    end
    entity.destructible = false
    entity.operable = false
    entity.minable = false

    -- Freeze all vehicle types specially.
    if entity_type == "locomotive" or entity_type == "cargo-wagon" or entity_type == "fluid-wagon" or entity_type == "artillery-wagon" or entity_type == "car" or entity_type == "spider-vehicle" then
        StasisLandMine.FreezeVehicle({ tick = tick, data = { entity = entity, unfreezeTick = unfreezeTick, vehicleType = entity_type } })
    end

    -- Show the effect on the entity.
    entity.surface.create_trivial_smoke {
        name = "stasis_mine-stasis_target_impact_effect",
        position = Utils.ApplyOffsetToPosition(entity.position, { x = 0, y = -0.5 })
    }
end

--- Stop a vehicle caught in the blast and keep it frozen.
---@param event any
StasisLandMine.FreezeVehicle = function(event)
    local data = event.data ---@type FreezeVehicleDetails
    local entity = data.entity
    if entity == nil or (not entity.valid) then
        return
    end

    -- Trains need their speed controlling every tick. Other vehicle types are prevented from speed by being disabled.
    -- All vehicles return to their pre-disabled speed when re-activated. For trains this can be a bit odd.
    if data.vehicleType == "locomotive" or data.vehicleType == "cargo-wagon" or data.vehicleType == "fluid-wagon" or data.vehicleType == "artillery-wagon" then
        entity.train.speed = 0
    end

    if event.tick < (data.unfreezeTick - 1) then
        global.stasisLandMine.nextSchedulerId = global.stasisLandMine.nextSchedulerId + 1
        EventScheduler.ScheduleEvent(event.tick + 1, "StasisLandMine.FreezeVehicle", global.stasisLandMine.nextSchedulerId, data)
    end
end

--- Remove the stasis effect from a target.
---@param event any
StasisLandMine.RemoveStasisFromTarget = function(event)
    local data = event.data ---@type UnfreezeEntityDetails
    local affectedEntityData = global.stasisLandMine.affectedEntities[data.identifier]
    global.stasisLandMine.affectedEntities[data.identifier] = nil

    local entity = data.entity
    if entity == nil or (not entity.valid) then
        return
    end

    entity.active = affectedEntityData.wasActive
    entity.destructible = affectedEntityData.wasDestructible
    if affectedEntityData.oldSpeed ~= nil then
        if entity.train ~= nil then
            entity.train.speed = affectedEntityData.oldSpeed
        else
            entity.speed = affectedEntityData.oldSpeed
        end
    end
    if affectedEntityData.oldOperable ~= nil then
        entity.operable = affectedEntityData.oldOperable
    end
    if affectedEntityData.oldMinable ~= nil then
        entity.minable = affectedEntityData.oldMinable
    end
end

--- Get a unique ID for an entity. Either its unit_number or a string with unique details.
---@param entity LuaEntity
---@return Identifier
StasisLandMine.MakeEntityIdentifier = function(entity)
    if entity.unit_number ~= nil then
        return entity.unit_number
    else
        return entity.surface.index .. "_" .. entity.name .. "_" .. Utils.FormatPositionTableToString(entity.position)
    end
end

return StasisLandMine
