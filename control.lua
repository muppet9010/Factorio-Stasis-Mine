local StasisLandMine = require("scripts/stasis-land-mine")

local function CreateGlobals()
    global.modSettings = global.modSettings or {} ---@class ModSettings

    StasisLandMine.CreateGlobals()
end

local function OnLoad()
    remote.remove_interface("stasis_weapons")
    remote.add_interface("stasis_weapons", {
        stasis_entity = StasisLandMine.PlaceEntityInStasis_Remote
    })

    StasisLandMine.OnLoad()
end

local function OnSettingChanged(event)
    StasisLandMine.OnSettingChanged(event)
end

local function OnStartup()
    CreateGlobals()
    OnLoad()
    OnSettingChanged(nil)

    StasisLandMine.OnStartup()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_event(defines.events.on_runtime_mod_setting_changed, OnSettingChanged)
script.on_load(OnLoad)
