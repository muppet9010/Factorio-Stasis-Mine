local StasisLandMine = {}
local Events = require("utility/events")
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")
local Logging = require("utility.logging")

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
---@field initialFreeze boolean
---@field unfreezeTick uint
---@field vehicleType string
---@field affectedEntityDetails AffectedEntityDetails
---@field carriageOldSpeed double|nil
---@field trainOldSpeed double|nil
---@field trainBlockerEntity LuaEntity|nil
---@field driver LuaPlayer|nil
---@field passenger LuaPlayer|nil

---@class UnfreezeEntityDetails
---@field entity LuaEntity
---@field identifier Identifier

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
    if event == nil or event.setting == "stasis_mine-spidertrons_affected" then
        global.modSettings["spidertrons_affected"] = settings.global["stasis_mine-spidertrons_affected"].value --[[@as boolean]]
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
    end
end

--- Apply the stasis effect to an entity caught in the blast.
---@param entity LuaEntity
---@param tick uint
StasisLandMine.ApplyStasisToTarget = function(entity, tick)
    local entity_type = entity.type

    -- Exclude some entities from being affected.
    if entity.name == "stasis-land-mine" then
        return
    end

    -- Handle spider legs specially, but we always finish their processing as they themselves aren't frozen.
    if entity_type == "spider-leg" then
        if global.modSettings.spidertrons_affected then
            StasisLandMine.SpiderLegAffected(entity, tick)
        end
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
        affectedEntityDetails.frozenVehicleDetails = { entity = entity, unfreezeTick = unfreezeTick, vehicleType = entity_type, affectedEntityDetails = affectedEntityDetails, initialFreeze = true }
        StasisLandMine.FreezeVehicle({ tick = tick, data = affectedEntityDetails.frozenVehicleDetails })
    end

    -- Show the effect on the entity.
    entity.surface.create_entity {
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

--- Stop a vehicle caught in the blast and keep it frozen every tick.
---@param event any
StasisLandMine.FreezeVehicle = function(event)
    local frozenVehicleDetails = event.data ---@type FreezeVehicleDetails
    local vehicleEntity = frozenVehicleDetails.entity
    if vehicleEntity == nil or (not vehicleEntity.valid) then
        return
    end

    -- Do some initial things only when this is the initial freeze of the vehicle.
    if frozenVehicleDetails.initialFreeze then
        frozenVehicleDetails.initialFreeze = false
        if frozenVehicleDetails.vehicleType == "locomotive" or frozenVehicleDetails.vehicleType == "cargo-wagon" or frozenVehicleDetails.vehicleType == "fluid-wagon" or frozenVehicleDetails.vehicleType == "artillery-wagon" then
            -- Train carriage handling. Needs special handling as we are manipulating every carriage in the train and not just the carriage entity directly affect by the area of effect.
            local train = vehicleEntity.train ---@cast train - nil
            local train_id = train.id

            -- Only do this for one carriage in a train.
            if not global.stasisLandMine.frozenTrainIds[train_id] then

                -- Stop the train after capturing its speed.
                frozenVehicleDetails.carriageOldSpeed = vehicleEntity.speed
                frozenVehicleDetails.trainOldSpeed = train.speed
                train.speed = 0

                -- Freeze every carriage in the train.
                global.stasisLandMine.frozenTrainIds[train_id] = true
                for _, carriage in pairs(train.carriages) do
                    if carriage ~= vehicleEntity then
                        StasisLandMine.ApplyStasisToTarget(carriage, event.tick)
                    end
                end
            end

            -- Each train carriage that is frozen needs to create and record its own blocker entity.
            frozenVehicleDetails.trainBlockerEntity = StasisLandMine.CreateFrozenTrainCarriageBlocker(vehicleEntity)

            -- Capture if there's a driver in the vehicle. Trains only have 1 player slot.
            local driver = vehicleEntity.get_driver()
            if driver ~= nil then
                if driver.is_player() then
                    ---@cast driver LuaPlayer
                    frozenVehicleDetails.driver = driver
                else
                    ---@cast driver LuaEntity
                    frozenVehicleDetails.driver = driver.player
                end
            end
        else
            -- All non train vehicles return nicely to their pre-disabled speed when re-activated.

            -- Capture if there's a driver and passenger in the vehicle. Cars and spiders always have 2 player slots.
            local driver = vehicleEntity.get_driver()
            if driver ~= nil then
                if driver.is_player() then
                    ---@cast driver LuaPlayer
                    frozenVehicleDetails.driver = driver
                else
                    ---@cast driver LuaEntity
                    frozenVehicleDetails.driver = driver.player
                end
            end
            local passenger = vehicleEntity.get_passenger()
            if passenger ~= nil then
                if passenger.is_player() then
                    ---@cast passenger LuaPlayer
                    frozenVehicleDetails.passenger = passenger
                else
                    ---@cast passenger LuaEntity
                    frozenVehicleDetails.passenger = passenger.player
                end
            end
        end
    end

    -- Check that any players in the vehicles are as they were at the start (not got in/out).
    -- Some disabled vehicles will prevent players from getting out, but it's patchy so just check all.
    StasisLandMine.CheckVehicleSeat(frozenVehicleDetails, "driver")
    if frozenVehicleDetails.vehicleType == "car" or frozenVehicleDetails.vehicleType == "spider-vehicle" then
        -- Only these vehicle types can have passengers.
        StasisLandMine.CheckVehicleSeat(frozenVehicleDetails, "passenger")
    end

    if event.tick < (frozenVehicleDetails.unfreezeTick - 1) then
        global.stasisLandMine.nextSchedulerId = global.stasisLandMine.nextSchedulerId + 1
        EventScheduler.ScheduleEvent(event.tick + 1, "StasisLandMine.FreezeVehicle", global.stasisLandMine.nextSchedulerId, frozenVehicleDetails)
    end
end

--- Create the blocker entity for a frozen train carriage.
---@param vehicleEntity LuaEntity
---@return LuaEntity|nil blockerEntity
StasisLandMine.CreateFrozenTrainCarriageBlocker = function(vehicleEntity)
    local blockerEntity = vehicleEntity.surface.create_entity({ name = "stasis-train-blocker", position = vehicleEntity.position })
    if blockerEntity == nil then
        game.print("ERROR - Stasis Mine - Failed to create blocking entity under train carriage at: " .. Logging.PositionToString(vehicleEntity.position), { r = 1.0, g = 0.0, b = 0.0, a = 1.0 })
        return nil
    end
    blockerEntity.destructible = false
    return blockerEntity
end

--- Check a vehicles seats are as expected.
---@param frozenVehicleDetails FreezeVehicleDetails
---@param seat "driver"|"passenger"
StasisLandMine.CheckVehicleSeat = function(frozenVehicleDetails, seat)
    local vehicleEntity = frozenVehicleDetails.entity
    local seatName, currentSeatOccupant, setSeatOccupantFunction
    if seat == "driver" then
        seatName = "driver"
        currentSeatOccupant = vehicleEntity.get_driver()
        setSeatOccupantFunction = vehicleEntity.set_driver
    else
        seatName = "passenger"
        currentSeatOccupant = vehicleEntity.get_passenger()
        setSeatOccupantFunction = vehicleEntity.set_passenger
    end
    if frozenVehicleDetails[seatName] ~= nil then
        -- There should still be a player in the vehicle, if there isn't return them.
        if currentSeatOccupant == nil then
            -- No player in vehicle, assuming the expected player has a character then set them back to the vehicle if they're close. If they don't have a character they are dead or something weird and we shouldn't set them back in to the vehicle. We check if close as this avoids us undoing any long distance teleport, so should just limit us to if the player got out of the vehicle as the vehicle will be stationary.
            local expectedCharacter = frozenVehicleDetails[seatName]--[[@as LuaPlayer]] .character
            if expectedCharacter ~= nil then
                if Utils.GetDistance(vehicleEntity.position, expectedCharacter.position) < 5 then
                    -- Player is near by so put them back in to the seat.
                    setSeatOccupantFunction(expectedCharacter)
                    vehicleEntity.surface.create_entity({ name = "flying-text", position = vehicleEntity.position, text = { "message.stasis_mine-player_can_not_leave_vehicle" }, render_player_index = frozenVehicleDetails[seatName].index })
                else
                    -- Player is too far away, so forget they where in the seat. Otherwise if they walk near the vehicle they will be snapped back in to it.
                    -- CODE NOTE: this disable isn't ideal, but asked as question: https://github.com/sumneko/lua-language-server/discussions/1616
                    frozenVehicleDetails[seatName] = nil ---@diagnostic disable-line:no-unknown
                end
            end
        end
    else
        -- There shouldn't be a player in the vehicle, if there is eject them.
        if currentSeatOccupant ~= nil then
            local currentSeatCharacter
            if not currentSeatOccupant.is_player() then
                ---@cast currentSeatOccupant LuaEntity
                currentSeatCharacter = currentSeatOccupant
                currentSeatOccupant = currentSeatOccupant.player
            else
                ---@cast currentSeatOccupant LuaPlayer
                currentSeatCharacter = currentSeatOccupant.character
            end ---@cast currentSeatOccupant - nil
            if currentSeatCharacter ~= nil then
                -- For a player to be ejected from a train carriage the train carriage can't have a blocker directly under its center. So we remove the blocker and then return it after ejecting the player.
                if frozenVehicleDetails.trainBlockerEntity ~= nil then
                    frozenVehicleDetails.trainBlockerEntity.destroy({ raise_destroy = false })
                end
                currentSeatOccupant.driving = false
                if frozenVehicleDetails.trainBlockerEntity ~= nil then
                    frozenVehicleDetails.trainBlockerEntity = StasisLandMine.CreateFrozenTrainCarriageBlocker(vehicleEntity)
                end
                vehicleEntity.surface.create_entity({ name = "flying-text", position = vehicleEntity.position, text = { "message.stasis_mine-player_can_not_enter_vehicle" }, render_player_index = currentSeatOccupant.index })
            end
        end
    end
end

--- Release a vehicle caught in the blast from being frozen.
---@param frozenVehicleDetails FreezeVehicleDetails
StasisLandMine.UnFreezeVehicle = function(frozenVehicleDetails)
    local entity = frozenVehicleDetails.entity

    -- Is the primary frozen carriage for the train.
    if frozenVehicleDetails.trainOldSpeed ~= nil then
        local train = entity.train ---@cast train - nil

        -- Set the trains speed. Check its the right direction with this primary carriages speed.
        train.speed = frozenVehicleDetails.trainOldSpeed
        if entity.speed ~= frozenVehicleDetails.carriageOldSpeed then
            train.speed = -frozenVehicleDetails.trainOldSpeed
        end

        -- Remove the flag that the train is frozen as it will all be unfrozen together.
        global.stasisLandMine.frozenTrainIds[train.id] = nil
    end

    -- Remove any train blocker if there was one.
    if frozenVehicleDetails.trainBlockerEntity ~= nil and frozenVehicleDetails.trainBlockerEntity.valid then
        frozenVehicleDetails.trainBlockerEntity.destroy({ raise_destroy = false })
    end
end

--- Handle when a spider leg is affected by a stasis effect and freeze the parent spider.
---@param frozenSpiderLegEntity LuaEntity
---@param tick uint
StasisLandMine.SpiderLegAffected = function(frozenSpiderLegEntity, tick)
    -- Radius of 20 should be enough to find any real sized spider from its leg.
    local nearBySpiders = frozenSpiderLegEntity.surface.find_entities_filtered({ type = "spider-vehicle", position = frozenSpiderLegEntity.position, radius = 20 })
    local parentSpider
    for _, spider in pairs(nearBySpiders) do
        for _, leg in pairs(spider.get_spider_legs()) do
            if leg == frozenSpiderLegEntity then
                parentSpider = spider
                break
            end
        end
        if parentSpider ~= nil then
            break
        end
    end

    if parentSpider == nil then
        game.print("ERROR - Stasis Mine - Failed to find parent spider of affected spider leg at: " .. Logging.PositionToString(frozenSpiderLegEntity.position), { r = 1.0, g = 0.0, b = 0.0, a = 1.0 })
        return
    end

    -- Call to freeze the spider. If its already been frozen this function will handle this cleanly.
    StasisLandMine.ApplyStasisToTarget(parentSpider, tick)
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
