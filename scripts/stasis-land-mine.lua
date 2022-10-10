--[[
    Some of the slightly odd data structures are to avoid needing to do a migration script for old saves.

    This isn't the most efficient with scheduling, however the API calls have been cached where possible. Very few vehicles are expected to be affected at one time and so optimising of this area hasn't been a focus.
--]]

local StasisLandMine = {}
local Events = require("utility.manager-libraries.events")
local PositionUtils = require("utility.helper-utils.position-utils")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local LoggingUtils = require("utility.helper-utils.logging-utils")

---@alias Identifier uint|string

---@class AffectedEntityDetails
---@field unfreezeTick uint
---@field freezeDuration uint # Will be 300 or greater.
---@field entity LuaEntity
---@field initialSurface LuaSurface # The surface of the entity when the effect started. Not updated if the entity is teleported.
---@field initialPosition MapPosition # The position of the entity when the effect started. Not updated if the entity is teleported.
---@field wasActive boolean
---@field wasDestructible boolean
---@field oldOperable boolean
---@field oldMinable boolean
---@field frozenVehicleDetails FreezeVehicleDetails|nil
---@field affectedGraphic LuaEntity
---@field affectedLightId uint64|nil # Rendered light Id if there's a light. We don't make one if there's not enough time left.

---@class FreezeVehicleDetails
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

local StasisLandMineLightColor = { r = 40, g = 210, b = 210 } ---@type Color.1

StasisLandMine.CreateGlobals = function()
    global.stasisLandMine = global.stasisLandMine or {} ---@class Global_StasisLandMine # Used by the StasisLandMine for its own global data.
    global.stasisLandMine.affectedEntities = global.stasisLandMine.affectedEntities or {} ---@type table<Identifier, AffectedEntityDetails>
    global.stasisLandMine.nextSchedulerId = global.stasisLandMine.nextSchedulerId or 0 ---@type uint
    global.stasisLandMine.frozenTrainIds = global.stasisLandMine.frozenTrainIds or {} ---@type table<uint, boolean>
end

StasisLandMine.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_script_trigger_effect, "StasisLandMine.OnScriptTriggerEffect", StasisLandMine.OnScriptTriggerEffect)
    EventScheduler.RegisterScheduler()
    EventScheduler.RegisterScheduledEventType("StasisLandMine.RemoveStasisFromTarget", StasisLandMine.RemoveStasisFromTarget)
    EventScheduler.RegisterScheduledEventType("StasisLandMine.FreezeVehicle", StasisLandMine.FreezeVehicle)
end

StasisLandMine.OnStartup = function()
    global.modSettings["stasis_ticks"] = tonumber(settings.startup["stasis_mine-stasis_time"].value) --[[@as uint]] * 60
    global.modSettings["stasis_effect_area"] = tonumber(settings.startup["stasis_mine-stasis_effect_area"].value) --[[@as uint]]
    global.modSettings["stasis_force_effected"] = settings.startup["stasis_mine-stasis_force_effected"].value --[[@as "all"|"enemy"]]

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

--- Called when any Lua Script Trigger effect occurs. Find if it's one of ours and call the handler if so. This function is also called by internal remote interface handlers.
---@param event EventData.on_script_trigger_effect
---@param stasisTicks uint|nil # Only passed in when the event is called internally as part of a remote call.
---@param effectArea uint|nil # Only passed in when the event is called internally as part of a remote call.
StasisLandMine.OnScriptTriggerEffect = function(event, stasisTicks, effectArea)
    if event.effect_id == "stasis_affected_target" and event.target_entity ~= nil then
        -- Is a potential target to be frozen.
        StasisLandMine.ApplyStasisToTarget(event.target_entity, event.tick, stasisTicks or global.modSettings["stasis_ticks"])
    elseif event.effect_id == "stasis_land_mine_source" or event.effect_id == "stasis_rocket_source" or event.effect_id == "stasis_grenade_source" then
        -- Is the detonation itself.
        local position
        if event.effect_id == "stasis_land_mine_source" then
            position = event.source_position
        else
            -- CODE NOTE: for `event.effect_id == "stasis_rocket_source"` then `event.source_entity` is only populated if the target is still alive at the time of rocket detonation. `event.target_position` is always populated where the rocket explodes.
            position = event.target_position
        end ---@cast position - nil
        -- TTL on lights is based on when the effect visually significantly fades away.
        rendering.draw_light({ sprite = "utility/light_medium", target = position, surface = event.surface_index, time_to_live = 25, color = StasisLandMineLightColor, scale = 2.0, intensity = 0.5 })
        rendering.draw_light({ sprite = "utility/light_medium", target = position, surface = event.surface_index, time_to_live = 25, color = StasisLandMineLightColor, scale = ((effectArea or global.modSettings["stasis_effect_area"]) / 2) --[[@as float]] , intensity = 0.5 })
    end
end

--- Apply the stasis effect to an entity caught in the blast.
---@param entity LuaEntity
---@param currentTick uint
---@param freezeDuration uint # Will be 300 ticks or greater.
StasisLandMine.ApplyStasisToTarget = function(entity, currentTick, freezeDuration)
    local entity_type, entity_name, entity_position, entity_surface = entity.type, entity.name, entity.position, entity.surface

    -- Exclude some entities from being affected.
    if entity_name == "stasis-land-mine" then
        return
    end

    -- Handle spider legs specially, but we always finish their processing as they themselves aren't frozen.
    if entity_type == "spider-leg" then
        if global.modSettings.spidertrons_affected then
            StasisLandMine.SpiderLegAffected(entity, currentTick, freezeDuration, entity_surface, entity_position)
        end
        return
    end

    -- Exclude trains if Mod Setting dictates so.
    if not global.modSettings["trains_affected"] and (entity_type == "locomotive" or entity_type == "cargo-wagon" or entity_type == "fluid-wagon" or entity_type == "artillery-wagon") then
        return
    end

    -- Only affect units not already in a stasis.
    local identifier = StasisLandMine.MakeEntityIdentifier(entity, entity_name, entity_surface.index, entity_position)
    if global.stasisLandMine.affectedEntities[identifier] ~= nil then
        return
    end

    global.stasisLandMine.nextSchedulerId = global.stasisLandMine.nextSchedulerId + 1
    local unfreezeTick = currentTick + freezeDuration
    EventScheduler.ScheduleEventOnce(unfreezeTick, "StasisLandMine.RemoveStasisFromTarget", global.stasisLandMine.nextSchedulerId, { entity = entity, identifier = identifier })
    local wasActive, wasDestructible, oldOperable, oldMinable = entity.active, entity.destructible, entity.operable, entity.minable
    local affectedEntityDetails = { unfreezeTick = unfreezeTick, freezeDuration = freezeDuration, entity = entity, initialSurface = entity_surface, initialPosition = entity_position }
    global.stasisLandMine.affectedEntities[identifier] = affectedEntityDetails

    if wasActive then
        entity.active = false -- Disable all vehicles despite it seeming to have intermittent results as it helps other mod recognise them as un-usable.
        affectedEntityDetails.wasActive = true
    end
    if wasDestructible then
        entity.destructible = false
        affectedEntityDetails.wasDestructible = true
    end
    if oldOperable then
        entity.operable = false
        affectedEntityDetails.oldOperable = true
    end
    if oldMinable then
        entity.minable = false
        affectedEntityDetails.oldMinable = true
    end

    -- Freeze all vehicle types specially.
    if entity_type == "locomotive" or entity_type == "cargo-wagon" or entity_type == "fluid-wagon" or entity_type == "artillery-wagon" or entity_type == "car" or entity_type == "spider-vehicle" then
        affectedEntityDetails.frozenVehicleDetails = { entity = entity, vehicleType = entity_type, affectedEntityDetails = affectedEntityDetails }
        StasisLandMine.FreezeVehicleInitial(affectedEntityDetails.frozenVehicleDetails, currentTick)
    end

    -- TODO: if its a player character then track them and move any stasis effect if they are teleported.

    -- Show the effect on the entity.
    affectedEntityDetails.affectedGraphic, affectedEntityDetails.affectedLightId = StasisLandMine.CreateAffectedEntityEffects(entity, entity_position, entity_surface, freezeDuration)
end

--- Create the affected entity light.
---@param entity LuaEntity
---@param entityPosition MapPosition
---@param entitySurface LuaSurface
---@param freezeDuration uint
---@return LuaEntity affectedGraphic
---@return uint64|nil renderedLightId
StasisLandMine.CreateAffectedEntityEffects = function(entity, entityPosition, entitySurface, freezeDuration)
    local entity_selectionBox = entity.selection_box
    local affectedGraphic = entitySurface.create_entity {
        name = "stasis_mine-stasis_target_impact_effect",
        position = {
            x = entity_selectionBox.left_top.x + ((entity_selectionBox.right_bottom.x - entity_selectionBox.left_top.x) / 2),
            y = entity_selectionBox.left_top.y + ((entity_selectionBox.right_bottom.y - entity_selectionBox.left_top.y) / 2) + 1
        }
    } ---@cast affectedGraphic - nil
    if freezeDuration ~= global.modSettings["stasis_ticks"] then
        -- Only update the TTL if it isn't the mod setting one, as the mod setting is part of the prototype already.
        affectedGraphic.time_to_live = freezeDuration
    end

    local lightRenderId
    local lightDuration = freezeDuration - 25
    if lightDuration > 0 then
        lightRenderId = rendering.draw_light({ sprite = "utility/light_medium", target = entityPosition, surface = entitySurface, time_to_live = freezeDuration - 25, color = StasisLandMineLightColor, scale = 0.5, intensity = 0.25 }) -- TTL on light is based on when the effect visually significantly fades away.
    end

    return affectedGraphic, lightRenderId
end

--- Remove the stasis effect from a target.
---@param event UtilityScheduledEvent_CallbackObject
StasisLandMine.RemoveStasisFromTarget = function(event)
    local UnfreezeEntityDetails = event.data ---@type UnfreezeEntityDetails
    local affectedEntityData = global.stasisLandMine.affectedEntities[UnfreezeEntityDetails.identifier]
    global.stasisLandMine.affectedEntities[UnfreezeEntityDetails.identifier] = nil

    local entity = UnfreezeEntityDetails.entity
    if entity == nil or (not entity.valid) then
        return
    end

    -- CODE NOTE: set these all back to their "old" value as older mod versions always captured these values. This has the same impact on newer versions that only capture them if they are changed.
    if affectedEntityData.wasActive ~= nil then
        entity.active = affectedEntityData.wasActive
    end
    if affectedEntityData.wasDestructible ~= nil then
        entity.destructible = affectedEntityData.wasDestructible
    end
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

--- The initial stopping of a vehicle caught in a stasis effect.
---@param frozenVehicleDetails FreezeVehicleDetails
---@param currentTick uint
StasisLandMine.FreezeVehicleInitial = function(frozenVehicleDetails, currentTick)
    local vehicleEntity = frozenVehicleDetails.affectedEntityDetails.entity

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
                    StasisLandMine.ApplyStasisToTarget(carriage, currentTick, frozenVehicleDetails.affectedEntityDetails.freezeDuration)
                end
            end
        end

        -- Each train carriage that is frozen needs to create and record its own blocker entity.
        frozenVehicleDetails.trainBlockerEntity = StasisLandMine.CreateFrozenTrainCarriageBlocker(frozenVehicleDetails.affectedEntityDetails)

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

    -- Schedule the vehicle check each tick.
    global.stasisLandMine.nextSchedulerId = global.stasisLandMine.nextSchedulerId + 1
    EventScheduler.ScheduleEventOnce(currentTick + 1, "StasisLandMine.FreezeVehicle", global.stasisLandMine.nextSchedulerId, frozenVehicleDetails)
end

--- Keep a vehicle frozen every tick.
---@param event UtilityScheduledEvent_CallbackObject
StasisLandMine.FreezeVehicle = function(event)
    local frozenVehicleDetails = event.data ---@type FreezeVehicleDetails
    local vehicleEntity = frozenVehicleDetails.affectedEntityDetails.entity
    if vehicleEntity == nil or (not vehicleEntity.valid) then
        return
    end

    -- Check that any players in the vehicles are as they were at the start (not got in/out).
    -- Some disabled vehicles will prevent players from getting out, but it's patchy so just check all.
    StasisLandMine.CheckVehicleSeat(frozenVehicleDetails, "driver", event.tick)
    if frozenVehicleDetails.vehicleType == "car" or frozenVehicleDetails.vehicleType == "spider-vehicle" then
        -- Only these vehicle types can have passengers.
        StasisLandMine.CheckVehicleSeat(frozenVehicleDetails, "passenger", event.tick)
    end

    if event.tick < (frozenVehicleDetails.affectedEntityDetails.unfreezeTick - 1) then
        global.stasisLandMine.nextSchedulerId = global.stasisLandMine.nextSchedulerId + 1
        EventScheduler.ScheduleEventOnce(event.tick + 1, "StasisLandMine.FreezeVehicle", global.stasisLandMine.nextSchedulerId, frozenVehicleDetails)
    end
end

--- Create the blocker entity for a frozen train carriage.
---@param affectedEntityDetails AffectedEntityDetails
---@return LuaEntity|nil blockerEntity
StasisLandMine.CreateFrozenTrainCarriageBlocker = function(affectedEntityDetails)
    local blockerEntity = affectedEntityDetails.initialSurface.create_entity({ name = "stasis-train-blocker", position = affectedEntityDetails.initialPosition })
    if blockerEntity == nil then
        LoggingUtils.LogPrintError("ERROR - Stasis Mine - Failed to create blocking entity under train carriage at: " .. LoggingUtils.PositionToString(affectedEntityDetails.initialPosition))
        return nil
    end
    blockerEntity.destructible = false
    return blockerEntity
end

--- Check a vehicles seats are as expected.
---@param frozenVehicleDetails FreezeVehicleDetails
---@param seat "driver"|"passenger"
---@param currentTick uint
StasisLandMine.CheckVehicleSeat = function(frozenVehicleDetails, seat, currentTick)
    --- CODE NOTE: While this is called every tick a teleported vehicle will only have it's surface and position data obtained in the case something is wrong. So hopefully very rarely. For this reason we don;t use the cache of these or track/update the cache.
    local affectedEntityDetails = frozenVehicleDetails.affectedEntityDetails
    local vehicleEntity = affectedEntityDetails.entity
    local seatName, currentSeatOccupant
    if seat == "driver" then
        seatName = "driver"
        currentSeatOccupant = vehicleEntity.get_driver()
    else
        seatName = "passenger"
        currentSeatOccupant = vehicleEntity.get_passenger()
    end
    if frozenVehicleDetails[seatName] ~= nil then
        -- There should still be a player in the vehicle.

        -- Check if the vehicle moved.
        local vehicleMoved = false
        local newPosition, newSurface = vehicleEntity.position, vehicleEntity.surface
        if newPosition.x ~= affectedEntityDetails.initialPosition.x or newPosition.y ~= affectedEntityDetails.initialPosition.y or newSurface ~= affectedEntityDetails.initialSurface then
            -- Vehicle has been teleported, so remove the old graphic and light, and then make new ones.
            local freezeDuration = affectedEntityDetails.unfreezeTick - currentTick
            affectedEntityDetails.affectedGraphic.destroy()
            if affectedEntityDetails.affectedLightId ~= nil then
                -- Destroy the old light if there was one.
                rendering.destroy(affectedEntityDetails.affectedLightId)
            end
            affectedEntityDetails.affectedGraphic, affectedEntityDetails.affectedLightId = StasisLandMine.CreateAffectedEntityEffects(vehicleEntity, newPosition, newSurface, freezeDuration)

            -- Update the cached details of this vehicle for the moved graphic.
            affectedEntityDetails.initialPosition = newPosition
            affectedEntityDetails.initialSurface = newSurface

            vehicleMoved = true
        end

        -- Check if there's currently a player in the vehicle and handle.
        if currentSeatOccupant == nil then
            -- No player in vehicle.

            -- Assuming the expected player has a character then set them back to the vehicle if they're close. If they don't have a character they are dead or something weird and we shouldn't set them back in to the vehicle. We check if close as this avoids us undoing any long distance teleport, so should just limit us to if the player got out of the vehicle as the vehicle will be stationary.
            local expectedCharacter = frozenVehicleDetails[seatName]--[[@as LuaPlayer]] .character
            if expectedCharacter ~= nil then
                if PositionUtils.GetDistance(newPosition, expectedCharacter.position) < 5 then
                    -- Player is near by so put them back in to the seat.
                    if seat == "driver" then
                        vehicleEntity.set_driver(expectedCharacter)
                    else
                        vehicleEntity.set_passenger(expectedCharacter)
                    end
                    newSurface.create_entity({ name = "flying-text", position = newPosition, text = { "message.stasis_mine-player_can_not_leave_vehicle" }, render_player_index = frozenVehicleDetails[seatName].index })
                else
                    -- Player is too far away, so forget they where in the seat. Otherwise if they walk near the vehicle they will be snapped back in to it.
                    frozenVehicleDetails[seatName] = nil ---@diagnostic disable-line:no-unknown # no nicer work around for this as its inherently not typed to set an unknown field in an object: https://github.com/sumneko/lua-language-server/discussions/1616

                    -- Freeze the player as they were in the vehicle. Se their time as the remaining stasis time.
                    StasisLandMine.ApplyStasisToTarget(expectedCharacter, currentTick, affectedEntityDetails.unfreezeTick - currentTick)
                end
            end
        else
            -- The player is still in the vehicle.

            if vehicleMoved then
                -- The vehicles moved, but the players view will have been left behind. This will move the players view next to the vehicle, rather than directly on top of it.
                local expectedCharacter = frozenVehicleDetails[seatName]--[[@as LuaPlayer]] .character
                if expectedCharacter ~= nil then
                    if seat == "driver" then
                        vehicleEntity.set_driver(nil)
                        vehicleEntity.set_driver(expectedCharacter)
                    else
                        vehicleEntity.set_passenger(nil)
                        vehicleEntity.set_passenger(expectedCharacter)
                    end
                end
            end
        end
    else
        -- There shouldn't be a player in the vehicle.

        if currentSeatOccupant ~= nil then
            -- There is a player in the vehicle, this isn't right.
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
                local vehicleEntity_surface, vehicleEntity_position = vehicleEntity.surface, vehicleEntity.position
                if frozenVehicleDetails.trainBlockerEntity ~= nil then
                    -- Update the surface and position cache in case the train has been teleported.
                    frozenVehicleDetails.affectedEntityDetails.initialSurface = vehicleEntity_surface
                    frozenVehicleDetails.affectedEntityDetails.initialPosition = vehicleEntity_position
                    frozenVehicleDetails.trainBlockerEntity = StasisLandMine.CreateFrozenTrainCarriageBlocker(frozenVehicleDetails.affectedEntityDetails)
                end
                vehicleEntity_surface.create_entity({ name = "flying-text", position = vehicleEntity_position, text = { "message.stasis_mine-player_can_not_enter_vehicle" }, render_player_index = currentSeatOccupant.index })

                -- Check if the character was disabled when trying to get it.
                -- TODO - not entirely sure this is needed once we track affected characters on their own. As we will need to handle them getting in to non stasis affected vehicles as well.
                local character_affectedEntityDetails = global.stasisLandMine.affectedEntities[currentSeatCharacter.unit_number--[[@as Identifier]] ]
                if character_affectedEntityDetails ~= nil then
                    -- As they went in and out of the vehicle we need to update their affected graphics as they will have moved locations, despite being frozen the whole time.
                    local freezeDuration = character_affectedEntityDetails.unfreezeTick - currentTick
                    local character_newPosition, character_newSurface = currentSeatCharacter.position, currentSeatCharacter.surface
                    character_affectedEntityDetails.affectedGraphic.destroy()
                    if character_affectedEntityDetails.affectedLightId ~= nil then
                        -- Destroy the old light if there was one.
                        rendering.destroy(character_affectedEntityDetails.affectedLightId)
                    end
                    character_affectedEntityDetails.affectedGraphic, character_affectedEntityDetails.affectedLightId = StasisLandMine.CreateAffectedEntityEffects(currentSeatCharacter, character_newPosition, character_newSurface, freezeDuration)

                    -- Update the cached details of this vehicle for the moved graphic.
                    character_affectedEntityDetails.initialPosition = character_newPosition
                    character_affectedEntityDetails.initialSurface = character_newSurface
                end
            end
        end
    end
end

--- Release a vehicle caught in the blast from being frozen.
---@param frozenVehicleDetails FreezeVehicleDetails
StasisLandMine.UnFreezeVehicle = function(frozenVehicleDetails)
    local entity = frozenVehicleDetails.affectedEntityDetails.entity

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
---@param currentTick uint
---@param freezeDuration uint # Will be 300 ticks or greater.
---@param frozenSpiderLegEntity_surface LuaSurface
---@param frozenSpiderLegEntity_position MapPosition
StasisLandMine.SpiderLegAffected = function(frozenSpiderLegEntity, currentTick, freezeDuration, frozenSpiderLegEntity_surface, frozenSpiderLegEntity_position)
    -- Radius of 20 should be enough to find any real sized spider from its leg.
    local nearBySpiders = frozenSpiderLegEntity_surface.find_entities_filtered({ type = "spider-vehicle", position = frozenSpiderLegEntity_position, radius = 20 })
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
        LoggingUtils.LogPrintError("ERROR - Stasis Mine - Failed to find parent spider of affected spider leg at: " .. LoggingUtils.LogPrintError.PositionToString(frozenSpiderLegEntity_position))
        return
    end

    -- Call to freeze the spider. If its already been frozen this function will handle this cleanly.
    StasisLandMine.ApplyStasisToTarget(parentSpider, currentTick, freezeDuration)
end


--- Get a unique ID for an entity. Either its unit_number or a string with unique details.
---@param entity LuaEntity
---@param entity_name string
---@param surface_index uint
---@param entity_position MapPosition
---@return Identifier
StasisLandMine.MakeEntityIdentifier = function(entity, entity_name, surface_index, entity_position)
    if entity.unit_number ~= nil then
        return entity.unit_number
    else
        return surface_index .. "_" .. entity_name .. "_" .. LoggingUtils.PositionToString(entity_position)
    end
end

--- Remote interface call to freeze a given entity.
---@param entityToFreeze LuaEntity
---@param timeSeconds uint
StasisLandMine.PlaceEntityInStasis_Remote = function(entityToFreeze, timeSeconds)
    local errorPrefix = "ERROR - Stasis Mine - 'stasis_entity' remote interface: "

    -- Check the `entityToFreeze` argument.
    if entityToFreeze == nil then
        LoggingUtils.LogPrintError(errorPrefix .. "No `entity` to freeze provided")
        return
    elseif type(entityToFreeze) ~= "table" then
        LoggingUtils.LogPrintError(errorPrefix .. "Non LuaEntity provided for `entity`, got type: " .. type(entityToFreeze))
        return
    elseif entityToFreeze.object_name ~= "LuaEntity" then
        LoggingUtils.LogPrintError(errorPrefix .. "Non LuaEntity provided for `entity`, got type: " .. entityToFreeze.object_name)
        return
    elseif not entityToFreeze.valid then
        LoggingUtils.LogPrintError(errorPrefix .. "Invalid (dead) LuaEntity provided for `entity`")
        return
    end ---@cast entityToFreeze LuaEntity

    -- Check the `timeSeconds` argument.
    if timeSeconds == nil then
        LoggingUtils.LogPrintError(errorPrefix .. "No `time` to freeze for provided")
        return
    end
    local timeSeconds_number = tonumber(timeSeconds)
    if timeSeconds_number == nil then
        LoggingUtils.LogPrintError(errorPrefix .. "Non number provided for `time`, got: " .. tostring(timeSeconds))
        return
    end
    timeSeconds_number = math.floor(timeSeconds_number)
    if timeSeconds_number < 5 then
        LoggingUtils.LogPrintError(errorPrefix .. "Stasis `time` must be 5 seconds or greater, got: " .. tostring(timeSeconds_number))
        return
    end ---@cast timeSeconds_number uint
    local timeTicks = timeSeconds_number * 60 ---@type uint

    -- Freeze the entity for the time.
    StasisLandMine.ApplyStasisToTarget(entityToFreeze, game.tick, timeTicks)
end

--- Remote interface call to create a custom stasis effect at a given location.
---@param surface LuaSurface
---@param position MapPosition
---@param ourForce_raw LuaForce|string
---@param affected_raw "all"|"enemy"
---@param effectRadius_raw uint|nil
---@param timeSeconds_raw uint|nil
StasisLandMine.CreateStasisEffect_Remote = function(surface, position, ourForce_raw, affected_raw, effectRadius_raw, timeSeconds_raw)
    local errorPrefix = "ERROR - Stasis Mine - 'stasis_effect' remote interface: "

    -- Check the `surface` argument.
    if surface == nil then
        LoggingUtils.LogPrintError(errorPrefix .. "No `surface` provided")
        return
    elseif type(surface) ~= "table" then
        LoggingUtils.LogPrintError(errorPrefix .. "Non LuaSurface provided for `surface`, got type: " .. type(surface))
        return
    elseif surface.object_name ~= "LuaSurface" then
        LoggingUtils.LogPrintError(errorPrefix .. "Non LuaSurface provided for `surface`, got type: " .. surface.object_name)
        return
    elseif not surface.valid then
        LoggingUtils.LogPrintError(errorPrefix .. "Invalid (dead) LuaSurface provided for `surface`")
        return
    end ---@cast surface LuaSurface

    -- Check the `position` argument.
    if position == nil then
        LoggingUtils.LogPrintError(errorPrefix .. "No `position` provided")
        return
    elseif type(position) ~= "table" then
        LoggingUtils.LogPrintError(errorPrefix .. "Non MapPosition provided for `position`, got type: " .. type(position))
        return
    elseif position.object_name ~= nil then
        LoggingUtils.LogPrintError(errorPrefix .. "Factorio Lua Object provided for `position`, got type: " .. surface.object_name)
        return
    elseif not PositionUtils.IsTableValidPosition(position) then
        LoggingUtils.LogPrintError(errorPrefix .. "Invalid MapPosition object received for `position`: " .. LoggingUtils.PrintThingsDetails(position))
        return
    end ---@cast position MapPosition

    -- Check the `ourForce` argument.
    local ourForce ---@type LuaForce
    if ourForce_raw == nil then
        LoggingUtils.LogPrintError(errorPrefix .. "No `ourForce` provided")
        return
    elseif type(ourForce_raw) == "string" then
        -- Special type that we need to process separately to the standard checks if we receive a LuaForce.
        ourForce = game.forces[ourForce_raw]
        if ourForce == nil then
            LoggingUtils.LogPrintError(errorPrefix .. "Invalid LuaForce provided for `ourForce` by its name, got force name: " .. ourForce_raw)
            return
        end
    elseif type(ourForce_raw) ~= "table" then
        LoggingUtils.LogPrintError(errorPrefix .. "Non LuaForce provided for `ourForce`, got type: " .. type(ourForce_raw))
        return
    elseif ourForce_raw.object_name ~= "LuaForce" then
        LoggingUtils.LogPrintError(errorPrefix .. "Non LuaForce provided for `ourForce`, got type: " .. ourForce_raw.object_name)
        return
    elseif not ourForce_raw.valid then
        LoggingUtils.LogPrintError(errorPrefix .. "Invalid (dead) LuaForce provided for `ourForce`")
        return
    else
        ourForce = ourForce_raw
    end

    -- Check the `affected` argument.
    local affected ---@type "all"|"enemy"
    if affected_raw == nil then
        affected = global.modSettings["stasis_force_effected"]
    elseif type(affected_raw) ~= "string" then
        LoggingUtils.LogPrintError(errorPrefix .. "Non string provided for `affected`, got type: " .. type(affected_raw))
        return
    elseif affected_raw ~= "all" and affected_raw ~= "enemy" then
        LoggingUtils.LogPrintError(errorPrefix .. "Non valid string provided for `affected`, accepts either `all` or `enemy`, got: " .. affected_raw)
        return
    else
        affected = affected_raw
    end

    -- Check the `effectRadius` argument.
    local effectRadius ---@type uint
    if effectRadius_raw == nil then
        effectRadius = global.modSettings["stasis_effect_area"]
    else
        effectRadius = tonumber(effectRadius_raw) --[[@as uint]]
        if effectRadius == nil then
            LoggingUtils.LogPrintError(errorPrefix .. "Non number provided for `effectRadius`, got: " .. tostring(effectRadius_raw))
            return
        end
        effectRadius = math.floor(effectRadius) --[[@as uint]]
        if effectRadius < 1 then
            LoggingUtils.LogPrintError(errorPrefix .. "`effectRadius` must be 1 tile or greater, got: " .. tostring(effectRadius_raw))
            return
        end
    end

    -- Check the `timeSeconds` argument.
    local timeTicks ---@type uint
    if timeSeconds_raw == nil then
        timeTicks = global.modSettings["stasis_ticks"]
    else
        local timeSeconds = tonumber(timeSeconds_raw)
        if timeSeconds == nil then
            LoggingUtils.LogPrintError(errorPrefix .. "Non number provided for `time`, got: " .. tostring(timeSeconds_raw))
            return
        end
        timeSeconds = math.floor(timeSeconds)
        if timeSeconds < 5 then
            LoggingUtils.LogPrintError(errorPrefix .. "Stasis `time` must be 5 seconds or greater, got: " .. tostring(timeSeconds_raw))
            return
        end
        timeTicks = timeSeconds * 60 --[[@as uint]]
    end

    -- Work out the forces list based on the settings.
    local forcesAffected
    if affected == "all" then
        forcesAffected = nil -- Means all forces entities are returned.
    else
        -- Get all of the enemy forces to ourForce.
        forcesAffected = {} ---@type table<int, LuaForce>
        for _, force in pairs(game.forces) do
            if ourForce.is_enemy(force) then
                forcesAffected[#forcesAffected + 1] = force
            end
        end
    end

    -- Do the stasis effect at the given location.
    local currentTick = game.tick

    -- Do the area targetting just like the real weapon does.
    -- CODE NOTE: As this API search is to the entities center, not its collision box, we add 1 range on to try and balance it. Documented in the readme as such. We could modify the weapons to measure to entity center, but this can have some odd visual affects and is different to all other Factorio measuring. https://wiki.factorio.com/Types/AreaTriggerItem#collision_mode . Alternative is to create detonations of the right area size on all forces and then do lots of script filtering by force, etc.
    -- CODE NOTE: the collision_mask filter is to stop it including a lot of un-intended entity types, like projectiles, smoke. Otherwise in testing 2 stasis effects would actually freeze each others graphics.
    for _, entity in pairs(surface.find_entities_filtered({ position = position, radius = effectRadius + 2, force = forcesAffected, collision_mask = { "object-layer", "player-layer", "train-layer" } })) do
        -- Call in to our event handler function as if we were the event itself.
        StasisLandMine.OnScriptTriggerEffect({ effect_id = "stasis_affected_target", target_entity = entity, tick = currentTick }, timeTicks, nil)
    end

    -- Do the detonation effects like the weapons do. But we need to do a dynamically scaled graphic.
    --surface.create_entity({ name = "stasis_mine-stasis_source_impact_effect", position = position })
    local animationScale = effectRadius / 2.5
    rendering.draw_animation({ animation = "stasis_source_impact_animation", x_scale = animationScale, y_scale = animationScale, target = position, surface = surface, time_to_live = 30 })

    -- Do the detonation effect like the weapons does. Call in to our event handler function as if we were the event itself.
    StasisLandMine.OnScriptTriggerEffect({ effect_id = "stasis_land_mine_source", source_position = position, surface_index = surface.index }, nil, effectRadius)
end

return StasisLandMine
