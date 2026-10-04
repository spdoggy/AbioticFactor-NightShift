--[[
    Author: SpDoggy
    Date: 2026-08-19
    Mod Name: NightShift
]]

---------- Configurations ----------
-- Enable mod from the start
ModEnabled = false

local last_weather_event = "Fog"
local hour_tick = 0

-------------- Hotkeys -------------
-- Possible keys: https://github.com/UE4SS-RE/RE-UE4SS/blob/main/docs/lua-api/table-definitions/key.md
-- See ModifierKey: https://github.com/UE4SS-RE/RE-UE4SS/blob/main/docs/lua-api/table-definitions/modifierkey.md
-- ModifierKeys can be combined. e.g.: {ModifierKey.CONTROL, ModifierKey.ALT} = CTRL + ALT + Q
-- Set to `nil` to disable hotkey.
ToggleKey = Key.F7
ToggleKeyModifiers = {ModifierKey.CONTROL}
------------------------------------

------------------------------
-- Don't change code below --
------------------------------
local AFUtils = require("AFUtils.AFUtils")
local Utils = require("utils")
local Config = require("../config")

ModName = "NightShift"
ModVersion = "1.0.0"
DebugMode = false

LogInfo("Starting NightShift mod initialization")



local function Handle_OnRep_IsNight(context)
    dn_manager = AFUtils.GetDayNightManager()
    dn_manager.IsNight = true
end

-- Called Every Hour
local function Handle_IsCurrentlyDaytime(context, IsDaytime)
    -- Set to Night
    dn_manager = AFUtils.GetDayNightManager()
    is_day = IsDaytime:get()
    IsDaytime:set(false)
    if not dn_manager.IsNight then
        dn_manager.IsNight = true
        dn_manager:OnRep_IsNight()
    end
    hour_tick = hour_tick + 1
    if hour_tick % Config.hours_per_fog_event == 0 then
        AFUtils.TriggerWeatherEvent("Fog")
    end
end

-- Handle New Player Joining Equipment
local function Handle_InitializeTraits(context, Phd, FirstTime, Amnesia)

    -- Get Context
    local prog_comp = context:get()
    local first_time = FirstTime:get()

    -- Player Lookup
    local actor = prog_comp:GetOwner()
    local pawn = actor.Instigator
    local player_state = actor.PlayerState
    local player_name = player_state.PlayerNamePrivate:ToString()

    -- Give Starting Kit
    local TheWorld = Utils.GetWorld()
    if Utils.IsValid(TheWorld) then
        
        if first_time then
            local data_table = "/Game/Blueprints/Items/ItemTable_Craftables.ItemTable_Craftables"
            local data_cat = "Craftables"
            local item_id = "battery_makeshift"
            Utils.GiveItemToTarget(pawn, player_name, item_id, data_table, data_cat, 1)

            item_id = "fieldbattery"
            Utils.GiveItemToTarget(pawn, player_name, item_id, data_table, data_cat, 3)

            item_id = "lantern"
            Utils.GiveItemToTarget(pawn, player_name, item_id, data_table, data_cat, 1)
        end
    end
end



-- Function /Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:VentWeatherFXToAllPlayers
local function Handle_VentWeatherFXToAllPlayers()           
    print("Weather Venting Hook Called")
    print("last_weather_event")
    if last_weather_event == "Fog" and Config.disable_fog_venting then
        ExecuteWithDelay(3000, function()
            AFUtils.TriggerWeatherEvent("Fog")
            local dayNightManager = FindFirstOf("DayNightManager_C")
            dayNightManager:PlayNextAnnouncementLine()
            dayNightManager:Broadcast_BeginPlayAnnouncement(0, FName("Fog"))    
        end) 
    end
end

local function Handle_ClearActiveWeatherRequests()
    -- Store Current Weather Event Name
    local dayNightManager = FindFirstOf("DayNightManager_C")
    last_weather_event = dayNightManager.CurrentWeatherEvent:ToString()
    if last_weather_event == "RadLeak" and Config.disable_fog_venting then
        AFUtils.TriggerWeatherEvent("Fog")
    end

end

ExecuteInGameThread(function()
    LogInfo("Initializing NightShift hooks")

    ExecuteWithDelay(2500, function()
    local okHook, errHook = pcall(RegisterHook,
        "/Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:OnRep_IsNight",
        Handle_OnRep_IsNight
    )
        if not okHook then
            print("NightShift Hook registration failed: %s", tostring(errHook))
        else
            print("NightShift Hook registration success: Handle_OnRep_IsNight")
        end
    end)

    ExecuteWithDelay(2500, function()
    local okHook, errHook = pcall(RegisterHook,
        "/Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:IsCurrentlyDaytime",
        Handle_IsCurrentlyDaytime
    )
        if not okHook then
            print("NightShift Hook registration failed: %s", tostring(errHook))
        else
            print("NightShift Hook registration success: Handle_IsCurrentlyDaytime")
        end
    end)


    ExecuteWithDelay(2500, function()
    local okHook, errHook = pcall(RegisterHook,
        "/Game/Blueprints/Characters/Abiotic_CharacterProgressionComponent.Abiotic_CharacterProgressionComponent_C:InitializeTraits",
        Handle_InitializeTraits
    )
        if not okHook then
            print("NightShift Hook registration failed: %s", tostring(errHook))
        else
            print("NightShift Hook registration success: Handle_IsCurrentlyDaytime")
        end
    end)

        -- Function /Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:VentWeatherFXToAllPlayers
    ExecuteWithDelay(2500, function()
    local okHook, errHook = pcall(RegisterHook,
        "/Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:VentWeatherFXToAllPlayers",
        Handle_VentWeatherFXToAllPlayers
    )
        if not okHook then
            print("NightShift Hook registration failed: %s", tostring(errHook))
        else
            print("NightShift Hook registration success: VentWeatherFXToAllPlayers")
        end
    end)

    -- Function /Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:ClearActiveWeatherRequests
    ExecuteWithDelay(2500, function()
    local okHook, errHook = pcall(RegisterHook,
        "/Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:ClearActiveWeatherRequests",
        Handle_ClearActiveWeatherRequests
    )
        if not okHook then
            print("NightShift Hook registration failed: %s", tostring(errHook))
        else
            print("NightShift Hook registration success: ClearActiveWeatherRequests")
        end
    end)

    NotifyOnNewObject("/Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C", function(dn_manager)
        ExecuteWithDelay(2500, function()
            dn_manager.IsNight = true
        end)
    end)

    LogInfo("NightShift Hooks initialized")
end)

if ToggleKey and ToggleKeyModifiers then
    local function SetModState(Enable)
        ExecuteInGameThread(function()
           
            Enable = Enable or false
            ModEnabled = Enable
            local state = "Disabled"
            local warningColor =  AFUtils.CriticalityLevels.Red
            if ModEnabled then
                state = "Enabled"
                warningColor =  AFUtils.CriticalityLevels.Green
            end
            local stateMessage = "NightShift: " .. state
            LogInfo(stateMessage)
            -- AFUtils.ModDisplayTextChatMessage(stateMessage)
            AFUtils.ClientDisplayWarningMessage(stateMessage, warningColor)

        end)
    end
    
    RegisterKeyBind(ToggleKey, ToggleKeyModifiers, function()
        SetModState(not ModEnabled)
    end)
end

LogInfo("Mod loaded successfully")
