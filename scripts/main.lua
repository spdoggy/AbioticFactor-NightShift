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
local Utils = require("utils")
local Config = require("../config")

ModName = "NightShift"
ModVersion = "1.0.0"
DebugMode = false
local last_weather_event =  Config.fog_type
local clock_tick = 0
local hour_tick = 0
local temp_power_meter = 0
local next_day_has_power = false
local mod_initialization = false

Utils.log("Starting NightShift mod initialization")

local function LastWeatherInConfig()
    for _, f in pairs(Config.weather_event_selection) do
        if f == last_weather_event then
            return true
        end
    end
    return false
end

--- Set to Night Time
---@param dn_manager ADayNightManager_C
---@param night boolean
local function set_night(dn_manager)

    if temp_power_meter > 0 then
        return
    end

    if not Utils.IsValid(dn_manager) then
        return
    end

    -- Check for Night Time
    if not dn_manager.IsNight then

        -- Check for NightTime
        Utils.log("[Handle_OnRep_LastKnownHour]: Detected IsNight = %s")
        Utils.log(dn_manager.IsNight )
        ExecuteWithDelay(1000, function()
            dn_manager.IsNight = true
        end)
        ExecuteWithDelay(1500, function()
            --dn_manager:OnRep_IsNight()
        end)
    end
end

-- Called Every Hour (Usually)
local function Handle_OnRep_LastKnownHour(context)

    Utils.log("[Handle_OnRep_LastKnownHour]")

    local dn_manager = context:Get()
    if Utils.IsValid(dn_manager) then
        Utils.CacheDayNightManager()
    else
        return
    end

    Utils.log("dn_manager.LastKnownHour")
    Utils.log(dn_manager.LastKnownHour)
    hour_tick = hour_tick + 1

    -- Setup the Night Time Tick Rate to Match Day Rate        
    dn_manager.SecondsPerRealSecond_Night = dn_manager.SecondsPerRealSecond_Day

    -- Debug
    if Config.transition_debug then
        if (dn_manager.LastKnownHour+0) < 5 then
            dn_manager.SecondsPerRealSecond_Day   = 2000 -- Default: 30
            dn_manager.SecondsPerRealSecond_Night = 2000 -- Default: 120
        elseif (dn_manager.LastKnownHour+0) > 7 then
            dn_manager.SecondsPerRealSecond_Day   = 2000 -- Default: 30
            dn_manager.SecondsPerRealSecond_Night = 2000 -- Default: 120
        else
            dn_manager.SecondsPerRealSecond_Day   = 120 -- Default: 30
            dn_manager.SecondsPerRealSecond_Night = 120 -- Default: 120
        end
    end

    if next_day_has_power then

        -- Prepare for Power Restore Next Hour
        if dn_manager.LastKnownHour == 5 then
            Utils.log("Next Day has Power: Now=5am")
            dn_manager.MorningStartHour = 6
            temp_power_meter = Config.temp_power_meter_max_hours
            dn_manager.NightfallStartHour = dn_manager.MorningStartHour + temp_power_meter
            if dn_manager.NightfallStartHour > 23 then
                dn_manager.NightfallStartHour = 23
            end
            next_day_has_power = false
        end
        -- Trigger Morning Now at 6am
        if dn_manager.LastKnownHour == 6 then

            -- Msg 1
            Utils.AllClientDisplayWarningMessage("Something rumbles deep below...", Enums.ClientWarnMessageColors.Purple, false)

            -- Msg 2
            local msg = string.format(".. Facility Power Temporarily Roars Back to Life! (%d hours)", temp_power_meter)
            Utils.AllClientDisplayWarningMessage(msg, Enums.ClientWarnMessageColors.Green, false)

            -- Vent Weather
            if Config.foggy_weather_enabled then
                ExecuteWithDelay(3000, function()
                    ExecuteInGameThread(function()
                        Utils.TriggerWeatherEvent("None")
                    end)
                end)
            end
        end
    else
        -- Set back to Night After Clearing Anomalies Should be no 
        -- announcements played with this method, i.e when processed
        -- in the same within the same Handle_OnRep_LastKnownHour call
        -- Security Robots may reset from patrol, however they should
        -- resume normal cycles next day or during loading zones
        if dn_manager.LastKnownHour == 5 then
            -- Transition Required to Clear Anomalies
            dn_manager.MorningStartHour = 6
            dn_manager.NightfallStartHour = 7
        elseif dn_manager.LastKnownHour == 6 then
            dn_manager.MorningStartHour = -1
            dn_manager.NightfallStartHour = 7

            -- Note: A player could get chopped by the Cafeteria Ventilation
            -- between approx 6:40 and 7:00 am in some cases
            ExecuteWithDelay(10000, function()
                dn_manager.IsNight = true
                dn_manager.OnRep_IsNight()
            end)
        else
            dn_manager.MorningStartHour = -1
            dn_manager.NightfallStartHour = -1
            dn_manager.IsNight = true
            dn_manager.OnRep_IsNight()
        end
    end

    Utils.log("temp_power_meter: "..temp_power_meter)
    -- Check Night while here
    if temp_power_meter > 0 then
        temp_power_meter = temp_power_meter - 1
        dn_manager.IsNight = false
    else
        set_night(dn_manager)
    end

    -- Process the Weather Events Next
    if hour_tick % (Config.hours_per_weather_event) == 0 then

        local power_dice_roll = math.random()
        Utils.log(string.format("Temp Emergency Power Roll: %.2f < %.2f", power_dice_roll*100, Config.temp_power_restore_chance))
        if power_dice_roll < (Config.temp_power_restore_chance/100) then
            next_day_has_power = true
        end

        if temp_power_meter <= 0 then
            if Config.foggy_weather_enabled then
                print("Selecting New Weather...")
                ExecuteWithDelay(1000, function()
                    ExecuteInGameThread(function()
                        Utils.TriggerWeatherEvent("None")
                    end)
                end)
                ExecuteWithDelay(4000, function()
                    ExecuteInGameThread(function()
                        local selected = math.random(1, #Config.weather_event_selection)
                        print(Config.weather_event_selection[selected])
                        Utils.TriggerWeatherEvent(Config.weather_event_selection[selected])
                    end)
                end)
            end
        end
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

            if Config.custom_emergency_starter_kit then
                
                for _, item in pairs(Config.custom_emergency_starter_kit) do
                    Utils.GiveItemToTarget(pawn, player_name, item.item_id, item.table, item.cat, item.qty)
                end
            end
        end
    end
end

-- Function /Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:VentWeatherFXToAllPlayers
local function Handle_VentWeatherFXToAllPlayers(context)

    local dn_manager = context:Get()
    if Utils.IsValid(dn_manager) then
        Utils.CacheDayNightManager()
    else
        return
    end

    if temp_power_meter > 0 then
        return
    end

    if LastWeatherInConfig() and Config.disable_fog_venting then
        ExecuteWithDelay(3000, function()
            local selected = math.random(1, #Config.weather_event_selection)
            print(selected)
            Utils.TriggerWeatherEvent(Config.weather_event_selection[selected])
        end)
    end
end

local function Handle_ClearActiveWeatherRequests(context)

    local dn_manager = context:Get()
    if Utils.IsValid(dn_manager) then
        Utils.CacheDayNightManager()
    else
        return
    end

    -- Store Current Weather Event Name
    dn_manager = Utils.GetDayNightManager()

    if temp_power_meter > 0 then
        return
    end

    if Config.foggy_weather_enabled then
        if Utils.IsValid(dn_manager) then
            last_weather_event = dn_manager.CurrentWeatherEvent:ToString()
            if last_weather_event == "RadLeak" and Config.disable_fog_venting then
                print("Selecting New Weather...")
                ExecuteWithDelay(1000, function()
                    Utils.TriggerWeatherEvent("None")
                end)
                ExecuteWithDelay(4000, function()
                    local selected = math.random(1, #Config.weather_event_selection)
                    print(Config.weather_event_selection[selected])
                    Utils.TriggerWeatherEvent(Config.weather_event_selection[selected])
                end)
            end
        end
    end
end

local function Handle_ReceiveBeginPlay(context)

    local gameState = context:get()
    if not gameState:IsValid() then return end

    local world = gameState:GetWorld()
    if world and world:IsValid() then
        Utils.WorldCache(world)
        mod_initialization = true

        -- Re-Initialize to Night
        dn_manager = Utils.GetDayNightManager()
        dn_manager.IsNight = true
        dn_manager:OnRep_IsNight()
    end

end


-- Hook Setup
ExecuteInGameThread(function()
    Utils.log("Initializing NightShift hooks")

    --/Game/Blueprints/Characters/Abiotic_CharacterProgressionComponent.Abiotic_CharacterProgressionComponent_C:InitializeTraits
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

    -- /Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:OnRep_LastKnownHour
    ExecuteWithDelay(2500, function()
    local okHook, errHook = pcall(RegisterHook,
        "/Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:OnRep_LastKnownHour",
        Handle_OnRep_LastKnownHour
    )
        if not okHook then
            print("NightShift Hook registration failed: %s", tostring(errHook))
        else
            print("NightShift Hook registration success: OnRep_LastKnownHour")
        end
    end)

    -- /Game/Blueprints/Meta/Abiotic_Survival_GameState.Abiotic_Survival_GameState_C:ReceiveBeginPlay
    ExecuteWithDelay(2500, function()
    local okHook, errHook = pcall(RegisterHook,
        "/Game/Blueprints/Meta/Abiotic_Survival_GameState.Abiotic_Survival_GameState_C:ReceiveBeginPlay",
        Handle_ReceiveBeginPlay
    )
        if not okHook then
            print("NightShift Hook registration failed: %s", tostring(errHook))
        else
            print("NightShift Hook registration success: ReceiveBeginPlay")
        end
    end)

    NotifyOnNewObject("/Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C", function(dn_manager)
        Utils.log("NotifyOnNewObject: DayNightManager_C")
        Utils.CacheDayNightManager(dn_manager)

        -- Important: Overriding the start hours here is the magic combination that will make
        -- even the local clients think power is off at the very start for a dedicated server
        -- i.e Visual FX like the Cafeteria Ventilation Fan will be powered off and not moving even
        -- if this mod is not installed on the local player's instance / coming from CrossPlay
        dn_manager.MorningStartHour = -1
        dn_manager.NightfallStartHour = -1
        dn_manager.IsNight = true
        dn_manager:OnRep_IsNight()

        -- There will be some initial hiccups, so re-enforce night-time a bit after startup
        -- Don't try to set the first weather event here though, handle that during ReceiveBeginPlay
        -- instead to prevent Cleanup/GarbageCollection issues.
        ExecuteWithDelay(2500, function()
            set_night(dn_manager)
            dn_manager.IsNight = true
            dn_manager:OnRep_IsNight()
        end)

        if Config.foggy_weather_enabled then
            -- Starting Weather Event
            ExecuteWithDelay(20000, function()
                ExecuteInGameThread(function()
                    local selected = math.random(1, #Config.weather_event_selection)
                    Utils.TriggerWeatherEvent(Config.weather_event_selection[selected])
                end)
            end)
        else
            ExecuteWithDelay(20000, function()
                ExecuteInGameThread(function()
                    Utils.TriggerWeatherEvent("None")
                end)
            end)
        end
    end)

    NotifyOnNewObject("/Script/AbioticFactor.Default__WeatherEventHandleFunctionLibrary", function(w_event_lib)
        Utils.log("CacheWeatherEventLib")
        Utils.CacheWeatherEventLib(w_event_lib)
    end)

    

    Utils.log("NightShift Hooks initialized")
end)

if ToggleKey and ToggleKeyModifiers then
    local function SetModState(Enable)
        ExecuteInGameThread(function()
           
            Enable = Enable or false
            ModEnabled = Enable
            local state = "Disabled"
            local warningColor =  Enums.ClientWarnMessageColors.Red
            if ModEnabled then
                state = "Enabled"
                warningColor =  Enums.ClientWarnMessageColors.Green
                Config.disable_fog_venting = true
                --Utils.TriggerWeatherEvent("Fog")
            else
                Config.disable_fog_venting = false
                Utils.TriggerWeatherEvent("None")
            end
            local stateMessage = "NightShift: Fog:" .. state
            Utils.log(stateMessage)
            Utils.AllClientDisplayWarningMessage(stateMessage, warningColor)
            
            dn_manager = Utils.GetDayNightManager()

            Utils.log("dn_manager.LastKnownHour")
            Utils.log(dn_manager.LastKnownHour)

            
            Utils.log("dn_manager.IsNight")
            Utils.log(dn_manager.IsNight)
            -- print(dn_manager.IsNight)
            
            -- print("SecondsPerRealSecond_Day")
            -- print(dn_manager.SecondsPerRealSecond_Day)
            -- print("SecondsPerRealSecond_Night")
            -- print(dn_manager.SecondsPerRealSecond_Night)

            dn_manager.SecondsPerRealSecond_Day   = 500 -- Default: 30
            dn_manager.SecondsPerRealSecond_Night = 500 -- Default: 120

            local data_table = "/Game/Blueprints/Items/ItemTable_FoodAndGibs.ItemTable_FoodAndGibs"
            local data_cat = "FoodAndGibs"
            local item_id = "food_cosmatosalad"
            local player = Utils.GetPlayerFromName("SpDoggy")
            local player_name = "SpDoggy"
            Utils.GiveItemToTarget(player, player_name, item_id, data_table, data_cat, 3)

            local item_id = "Coffee"
            Utils.GiveItemToTarget(player, player_name, item_id, data_table, data_cat, 5)

            
            
            -- print("MorningStartHour")
            -- print(dn_manager.MorningStartHour)
            -- dn_manager.MorningStartHour = -1

            -- print("NightfallStartHour")
            -- print(dn_manager.NightfallStartHour)
            

            --temp_power_meter = 6

            --Utils.AllClientDisplayWarningMessage("Something rumbles deep below...", Enums.ClientWarnMessageColors.Green, false)
            -- Trigger Lights/Power On
            --dn_manager.IsNight = false
            --dn_manager:OnRep_IsNight()
            --dn_manager:OnRep_CurrentDay()
        end)
    end
    
    RegisterKeyBind(ToggleKey, ToggleKeyModifiers, function()
        SetModState(not ModEnabled)
    end)
end

Utils.log("Mod loaded successfully")
