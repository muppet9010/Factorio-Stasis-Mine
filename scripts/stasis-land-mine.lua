local StasisLandMine = {}
local Events = require("utility/events")
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")

StasisLandMine.CreateGlobals = function()
    global.stasisLandMine = global.stasisLandMine or {}
    global.stasisLandMine.affectedEntities = global.stasisLandMine.affectedEntities or {}
    global.stasisLandMine.nextSchedulerId = global.stasisLandMine.nextSchedulerId or 0
    global.stasisLandMine.stasisAffectTime = global.stasisLandMine.stasisAffectTime or 0
end

StasisLandMine.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_script_trigger_effect, "StasisLandMine.OnScriptTriggerEffect", StasisLandMine.OnScriptTriggerEffect)
    EventScheduler.RegisterScheduler()
    EventScheduler.RegisterScheduledEventType("StasisLandMine.RemoveStasisFromTarget", StasisLandMine.RemoveStasisFromTarget)
    EventScheduler.RegisterScheduledEventType("StasisLandMine.FreezeVehicle", StasisLandMine.FreezeVehicle)
end

StasisLandMine.OnStartup = function()
    global.stasisLandMine.stasisAffectTime = tonumber(settings.startup["stasis_mine-stasis_time"].value) * 60
end

StasisLandMine.OnScriptTriggerEffect = function(event)
    if event.effect_id == "stasis_land_mine_affected_target" and event.target_entity ~= nil and event.target_entity.valid then
        StasisLandMine.ApplyStasisToTarget(event.target_entity)
    elseif event.effect_id == "stasis_land_mine_source" then
        rendering.draw_light {sprite = "utility/light_medium", target = event.source_entity.position, surface = event.surface_index, time_to_live = 5, color = {r = 40, g = 210, b = 210}, scale = 2}
        rendering.draw_light {sprite = "utility/light_medium", target = event.source_entity.position, surface = event.surface_index, time_to_live = 45, color = {r = 40, g = 210, b = 210}, scale = 3, intensity = 0.5}
    end
end

StasisLandMine.ApplyStasisToTarget = function(entity)
    -- Exclude some entities from being affected.
    if entity.name == "stasis-land-mine" or entity.type == "spider-leg" then
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
    EventScheduler.ScheduleEvent(unfreezeTick, "StasisLandMine.RemoveStasisFromTarget", global.stasisLandMine.nextSchedulerId, {entity = entity, identifier = identifier})
    global.stasisLandMine.affectedEntities[identifier] = {unfreezeTick = unfreezeTick, wasActive = entity.active, wasDestructible = entity.destructible, oldHealth = entity.health, oldSpeed = entity.speed, oldOperable = entity.operable, oldMinable = entity.minable}

    entity.active = false
    entity.destructible = false
    if entity.type ~= "tree" then
        -- Tree's regain health so show a hitbox. Is annoying so exclude them from health change.
        entity.health = 0
    end
    if entity.operable ~= nil then
        entity.operable = false
    end
    if entity.minable ~= nil then
        entity.minable = false
    end
    if entity.speed ~= nil and entity.type ~= "unit" then
        StasisLandMine.FreezeVehicle({tick = tick, data = {entity = entity, unfreezeTick = unfreezeTick}})
    end

    -- Do here once the bug with moving smoke has been fixed. As at present things show the graphics of being affected that aren't.
    --[[entity.surface.create_trivial_smoke {
        name = "stasis_mine-stasis_target_impact_effect",
        position = Utils.ApplyOffsetToPosition(entity.position, {x = 0, y = -0.5})
    }--]]
end

StasisLandMine.FreezeVehicle = function(event)
    local data, entity = event.data, event.data.entity
    if entity == nil or (not entity.valid) then
        return
    end

    if entity.train ~= nil then
        entity.train.speed = 0
    else
        entity.speed = 0
    end
    if event.tick < (data.unfreezeTick - 1) then
        global.stasisLandMine.nextSchedulerId = global.stasisLandMine.nextSchedulerId + 1
        EventScheduler.ScheduleEvent(event.tick + 1, "StasisLandMine.FreezeVehicle", global.stasisLandMine.nextSchedulerId, data)
    end
end

StasisLandMine.RemoveStasisFromTarget = function(event)
    local affectedEntityData = global.stasisLandMine.affectedEntities[event.data.identifier]
    global.stasisLandMine.affectedEntities[event.data.identifier] = nil

    local entity = event.data.entity
    if entity == nil or (not entity.valid) then
        return
    end

    entity.active = affectedEntityData.wasActive
    entity.destructible = affectedEntityData.wasDestructible
    entity.health = affectedEntityData.oldHealth
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

StasisLandMine.MakeEntityIdentifier = function(entity)
    if entity.unit_number ~= nil then
        return entity.unit_number
    else
        return entity.surface.index .. "_" .. entity.name .. "_" .. Utils.FormatPositionTableToString(entity.position)
    end
end

return StasisLandMine
