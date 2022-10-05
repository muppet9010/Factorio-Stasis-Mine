local StasisLandMine = {}
local Events = require("utility/events")
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")

---@alias Identifier uint|string

---@class AffectedEntityDetails
---@field unfreezeTick uint
---@field wasActive boolean
---@field wasDestructible boolean
---@field oldOperable boolean
---@field oldMinable boolean
---@field frozenVehicleDetails FreezeVehicleDetails|nil

---@class FreezeVehicleDetails
---@field entity LuaEntity
---@field unfreezeTick uint
---@field vehicleType string
---@field affectedEntityDetails AffectedEntityDetails
---@field carriageOldSpeed double|nil
---@field trainOldSpeed double|nil
---@field trainBlockerEntity LuaEntity|nil

---@class UnfreezeEntityDetails
---@field entity LuaEntity
---@field identifier Identifier

local StasisLandMineLightColor = { r = 40, g = 210, b = 210 } ---@type Color.1

StasisLandMine.CreateGlobals = function()
    global.stasisLandMine = global.stasisLandMine or {} ---@class Global_StasisLandMine # Used by the StasisLandMine for its own global data.
    global.stasisLandMine.affectedEntities = global.stasisLandMine.affectedEntities or {} ---@type table<Identifier, AffectedEntityDetails>
    global.stasisLandMine.nextSchedulerId = global.stasisLandMine.nextSchedulerId or 0 ---@type uint
    global.stasisLandMine.stasisAffectTime = global.stasisLandMine.stasisAffectTime or 0 ---@type uint
    global.stasisLandMine.frozenTrainIds = global.stasisLandMine.frozenTrainIds or {} ---@type table<uint, boolean>
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

StasisLandMine.OnSettingChanged = function(event)
    if event == nil or event.setting == "stasis_mine-trains_affected" then
        global.modSettings["trains_affected"] = settings.global["stasis_mine-trains_affected"].value --[[@as boolean]]
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
        StasisLandMine.ApplyStasisToTarget(event.target_entity, event.tick)
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
---@param tick uint
StasisLandMine.ApplyStasisToTarget = function(entity, tick)
    local entity_type = entity.type

    -- Exclude some entities from being affected.
    if entity.name == "stasis-land-mine" or entity_type == "spider-leg" then
        return
    end

    -- Exclude trains if Mod Setting dictates so.
    if not global.modSettings["trains_affected"] and (entity_type == "locomotive" or entity_type == "cargo-wagon" or entity_type == "fluid-wagon" or entity_type == "artillery-wagon") then
        return
    end

    -- Only affect units not already in a stasis.
    local identifier = StasisLandMine.MakeEntityIdentifier(entity)
    if global.stasisLandMine.affectedEntities[identifier] ~= nil then
        return
    end

    global.stasisLandMine.nextSchedulerId = global.stasisLandMine.nextSchedulerId + 1
    local unfreezeTick = tick + global.stasisLandMine.stasisAffectTime
    EventScheduler.ScheduleEvent(unfreezeTick, "StasisLandMine.RemoveStasisFromTarget", global.stasisLandMine.nextSchedulerId, { entity = entity, identifier = identifier })
    local affectedEntityDetails = { unfreezeTick = unfreezeTick, wasActive = entity.active, wasDestructible = entity.destructible, oldOperable = entity.operable, oldMinable = entity.minable }
    global.stasisLandMine.affectedEntities[identifier] = affectedEntityDetails

    entity.active = false -- Disable all vehicles despite it seeming to have intermittent results as it helps other mod recognise them as un-usable.
    entity.destructible = false
    entity.operable = false
    entity.minable = false

    -- Freeze all vehicle types specially.
    if entity_type == "locomotive" or entity_type == "cargo-wagon" or entity_type == "fluid-wagon" or entity_type == "artillery-wagon" or entity_type == "car" or entity_type == "spider-vehicle" then
        affectedEntityDetails.frozenVehicleDetails = { entity = entity, unfreezeTick = unfreezeTick, vehicleType = entity_type, affectedEntityDetails = affectedEntityDetails }
        StasisLandMine.FreezeVehicle({ tick = tick, data = affectedEntityDetails.frozenVehicleDetails })
    end

    -- Show the effect on the entity.
    entity.surface.create_trivial_smoke {
        name = "stasis_mine-stasis_target_impact_effect",
        position = Utils.ApplyOffsetToPosition(entity.position, { x = 0, y = -0.5 })
    }
end

--- Remove the stasis effect from a target.
---@param event any
StasisLandMine.RemoveStasisFromTarget = function(event)
    local UnfreezeEntityDetails = event.data ---@type UnfreezeEntityDetails
    local affectedEntityData = global.stasisLandMine.affectedEntities[UnfreezeEntityDetails.identifier]
    global.stasisLandMine.affectedEntities[UnfreezeEntityDetails.identifier] = nil

    local entity = UnfreezeEntityDetails.entity
    if entity == nil or (not entity.valid) then
        return
    end

    entity.active = affectedEntityData.wasActive
    entity.destructible = affectedEntityData.wasDestructible
    if affectedEntityData.oldOperable ~= nil then
        entity.operable = affectedEntityData.oldOperable
    end
    if affectedEntityData.oldMinable ~= nil then
        entity.minable = affectedEntityData.oldMinable
    end

    if affectedEntityData.frozenVehicleDetails ~= nil then
        StasisLandMine.UnFreezeVehicle(affectedEntityData.frozenVehicleDetails)
    end
end

--- Stop a vehicle caught in the blast and keep it frozen.
---@param event any
StasisLandMine.FreezeVehicle = function(event)
    local frozenVehicleDetails = event.data ---@type FreezeVehicleDetails
    local entity = frozenVehicleDetails.entity
    if entity == nil or (not entity.valid) then
        return
    end

    if frozenVehicleDetails.vehicleType == "locomotive" or frozenVehicleDetails.vehicleType == "cargo-wagon" or frozenVehicleDetails.vehicleType == "fluid-wagon" or frozenVehicleDetails.vehicleType == "artillery-wagon" then
        -- Train carriage handling. Needs special handling as we are manipulating every carriage in the train and not just the carriage entity directly affect by the area of effect.
        local train = entity.train ---@cast train - nil
        local train_id = train.id

        -- Only do this for one carriage in a train.
        if not global.stasisLandMine.frozenTrainIds[train_id] then

            -- Stop the train after capturing its speed.
            frozenVehicleDetails.carriageOldSpeed = entity.speed
            frozenVehicleDetails.trainOldSpeed = train.speed
            train.speed = 0

            -- Freeze every carriage in the train.
            global.stasisLandMine.frozenTrainIds[train_id] = true
            for _, carriage in pairs(train.carriages) do
                if carriage ~= entity then
                    StasisLandMine.ApplyStasisToTarget(carriage, event.tick)
                end
            end
        end

        -- Each train carriage that is frozen needs to create and record its own blocker entity.
        local blockerEntity = entity.surface.create_entity({ name = "stasis-train-blocker", position = entity.position })
        blockerEntity.destructible = false
        frozenVehicleDetails.trainBlockerEntity = blockerEntity
    else
        -- All non train vehicles return nicely to their pre-disabled speed when re-activated.
    end

    if event.tick < (frozenVehicleDetails.unfreezeTick - 1) then
        global.stasisLandMine.nextSchedulerId = global.stasisLandMine.nextSchedulerId + 1
        EventScheduler.ScheduleEvent(event.tick + 1, "StasisLandMine.FreezeVehicle", global.stasisLandMine.nextSchedulerId, data)
    end
end

--- Release a vehicle caught in the blast from being frozen.
---@param frozenVehicleDetails FreezeVehicleDetails
StasisLandMine.UnFreezeVehicle = function(frozenVehicleDetails)
    -- Is the primary frozen carriage for the train.
    if frozenVehicleDetails.trainOldSpeed ~= nil then
        local train = frozenVehicleDetails.entity.train ---@cast train - nil

        -- Set the trains speed. Check its the right direction with this primary carriages speed.
        train.speed = frozenVehicleDetails.trainOldSpeed
        if frozenVehicleDetails.entity.speed ~= frozenVehicleDetails.carriageOldSpeed then
            train.speed = -frozenVehicleDetails.trainOldSpeed
        end

        -- Remove the flag that the train is frozen as it will all be unfrozen together.
        global.stasisLandMine.frozenTrainIds[train.id] = nil
    end

    if frozenVehicleDetails.trainBlockerEntity ~= nil and frozenVehicleDetails.trainBlockerEntity.valid then
        frozenVehicleDetails.trainBlockerEntity.destroy({ raise_destroy = false })
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
