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
end

StasisLandMine.OnStartup = function()
    global.stasisLandMine.stasisAffectTime = tonumber(settings.startup["stasis_mine-stasis_time"].value) * 60
end

StasisLandMine.OnScriptTriggerEffect = function(event)
    StasisLandMine.ApplyStasisToTarget(event.target_entity)
end

StasisLandMine.ApplyStasisToTarget = function(entity)
    -- Exclude some entities from being affected
    if entity.destructible ~= true or entity.name == "stasis-land-mine" then
        return
    end

    -- Only affect units not already in a stasis.
    local identifier = StasisLandMine.MakeEntityIdentifier(entity)
    if global.stasisLandMine.affectedEntities[identifier] ~= nil then
        return
    end

    global.stasisLandMine.nextSchedulerId = global.stasisLandMine.nextSchedulerId + 1
    EventScheduler.ScheduleEvent(game.tick + global.stasisLandMine.stasisAffectTime, "StasisLandMine.RemoveStasisFromTarget", global.stasisLandMine.nextSchedulerId, {entity = entity, identifier = identifier})
    global.stasisLandMine.affectedEntities[identifier] = {wasActive = entity.active, wasDestructible = entity.destructible, oldHealth = entity.health}

    entity.active = false
    entity.destructible = false
    entity.health = 0
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
end

StasisLandMine.MakeEntityIdentifier = function(entity)
    if entity.unit_number ~= nil then
        return entity.unit_number
    else
        return entity.surface.index .. "_" .. entity.name .. "_" .. Utils.FormatPositionTableToString(entity.position)
    end
end

return StasisLandMine
