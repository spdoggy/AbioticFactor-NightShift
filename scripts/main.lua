--[[
    Author: SpDoggy
    Date: 2026-08-19
    Mod Name: NightShift
]]

---------- Configurations ----------
-- Enable mod from the start
ModEnabled = false


-------------- Hotkeys -------------
-- Possible keys: https://github.com/UE4SS-RE/RE-UE4SS/blob/main/docs/lua-api/table-definitions/key.md
-- See ModifierKey: https://github.com/UE4SS-RE/RE-UE4SS/blob/main/docs/lua-api/table-definitions/modifierkey.md
-- ModifierKeys can be combined. e.g.: {ModifierKey.CONTROL, ModifierKey.ALT} = CTRL + ALT + Q
-- Set to `nil` to disable hotkey.
ToggleKey = Key.F7
ToggleKeyModifiers = {ModifierKey.CONTROL}
------------------------------------

------------------------------
local AFUtils = require("AFUtils.AFUtils")
local Utils = require("utils")
local Config = require("../config")

ModName = "NightShift"
ModVersion = "1.0.0"
DebugMode = false
local last_weather_event =  Config.fog_type
local clock_tick = 0


LogInfo("Starting NightShift mod initialization")


local function LastWeatherInConfig()
    for _, f in pairs(Config.weather_event_selection) do
        if f == last_weather_event then
            return true
        end
    end
    return false
end

local function Handle_OnRep_IsNight(context)
    dn_manager = AFUtils.GetDayNightManager()
    dn_manager.IsNight = true
    dn_manager = nil
end

-- Called Every Hour (Sometimes)
local function Handle_IsCurrentlyDaytime(context, IsDaytime)
    -- Set to Night
    dn_manager = AFUtils.GetDayNightManager()
    is_day = IsDaytime:get()
    IsDaytime:set(false)
    if not dn_manager.IsNight then
        ExecuteWithDelay(1000, function()
            dn_manager.IsNight = true
        end)
        ExecuteWithDelay(1500, function()
            dn_manager:OnRep_IsNight()
            dn_manager = nil
        end)
    end
end

-- Called Frequently
local function Handle_ProgressClock()
    clock_tick = clock_tick + 1
    if clock_tick % (20 * Config.hours_per_weather_event) == 0 then
        print("Selecting New Weather...")
        ExecuteWithDelay(1000, function()
            AFUtils.TriggerWeatherEvent("None")
        end)
        ExecuteWithDelay(4000, function()
            local selected = math.random(1, #Config.weather_event_selection)
            print(Config.weather_event_selection[selected])
            AFUtils.TriggerWeatherEvent(Config.weather_event_selection[selected])
        end)
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
            Utils.GiveItemToTarget(pawn, player_name, item_id, data_table, data_cat, 1)

            if Config.player_starts_with_lantern then
                item_id = "lantern"
                Utils.GiveItemToTarget(pawn, player_name, item_id, data_table, data_cat, 1)
            end

            if Config.player_starts_with_lantern then
                data_table = "/Game/Blueprints/Items/ItemTable_Gear.ItemTable_Gear"
                data_cat = "Gear"
                item_id = "trinket_light_yellow"
                Utils.GiveItemToTarget(pawn, player_name, item_id, data_table, data_cat, 1)
            end
        end
    end
end

-- Function /Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:VentWeatherFXToAllPlayers
local function Handle_VentWeatherFXToAllPlayers()    
    if LastWeatherInConfig() and Config.disable_fog_venting then
        ExecuteWithDelay(3000, function()
            local selected = math.random(1, #Config.weather_event_selection)
            print(selected)
            AFUtils.TriggerWeatherEvent(Config.weather_event_selection[selected])
            -- TODO: Don't think these are needed
            -- local dayNightManager = FindFirstOf("DayNightManager_C")
            -- dayNightManager:PlayNextAnnouncementLine()
            -- dayNightManager:Broadcast_BeginPlayAnnouncement(0, FName(Config.fog_type))
            dayNightManager = nil
        end)
    end
end

local function Handle_ClearActiveWeatherRequests()
    -- Store Current Weather Event Name
    local dayNightManager = FindFirstOf("DayNightManager_C")
    last_weather_event = dayNightManager.CurrentWeatherEvent:ToString()
    if last_weather_event == "RadLeak" and Config.disable_fog_venting then
        ExecuteWithDelay(2000, function()
            local selected = math.random(1, #Config.weather_event_selection)
            AFUtils.TriggerWeatherEvent(Config.weather_event_selection[selected])
            dayNightManager = nil
        end)
    end
end

-- Hook Setup
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
            "/Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:ProgressClock",
            Handle_ProgressClock
        )
        if not okHook then
            Utils.error(string.format("Hook registration failed: %s", tostring(errHook)))
        else
            Utils.log("Hook registration success: Handle_ProgressClock")
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

            
            for _, f in pairs(Config.weather_event_selection) do
                --local ok2, name = pcall(function() return f:get():ToString() end)
                print(f)
                --if ok2 and name and name ~= "" then out[name] = true end
            end

        end)
    end
    
    RegisterKeyBind(ToggleKey, ToggleKeyModifiers, function()
        SetModState(not ModEnabled)
    end)
end

LogInfo("Mod loaded successfully")
