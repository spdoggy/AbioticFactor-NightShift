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

MOD_PREFIX = "[NIGHT]"
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

    if temp_power_meter > 0 or next_day_has_power then
        return
    end

    if not Utils.IsValid(dn_manager) then
        return
    end

    -- Exit if feature is disabled
    if not Config.facility_power_off_always_night then
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


local function Handle_IsCurrentlyDaytime(context, IsDaytime)

    is_daytime = IsDaytime:get()
    msg = string.format("[Handle_IsCurrentlyDaytime]IsDaytime: %s", is_daytime)
    Utils.log(msg)
    if next_day_has_power or temp_power_meter > 0 then
        Utils.log("[Handle_IsCurrentlyDaytime] Temp Power, Force IsDaytime True")
        IsDaytime:set(true)
    end

end

local function Handle_OnRep_IsNight(context)
    local dn_manager = context:Get()
    if Utils.IsValid(dn_manager) then
        Utils.CacheDayNightManager()
    else
        return
    end

    if temp_power_meter > 0 then
        Utils.log("Handle_OnRep_IsNight: Temp Power Meter > 0")
        dn_manager.IsNight = false
    end

end

local function DebugLogDayNightManager(dn_manager)
    if not Utils.IsValid(dn_manager) then
        return
    end

    msg = string.format("LastKnownHour: %d", dn_manager.LastKnownHour)
    Utils.log(msg)

    msg = string.format("temp_power_meter: %d", temp_power_meter)
    Utils.log(msg)

    msg = string.format("next_day_has_power: %s", next_day_has_power)
    Utils.log(msg)

    msg = string.format("IsNight: %s", dn_manager.IsNight)
    Utils.log(msg)

    msg = string.format("MorningStartHour: %s", dn_manager.MorningStartHour)
    Utils.log(msg)

    msg = string.format("NightfallStartHour: %s", dn_manager.NightfallStartHour)
    Utils.log(msg)
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

    DebugLogDayNightManager(dn_manager)

    hour_tick = hour_tick + 1

    -- Setup the Night Time Tick Rate to Match Day Rate        
    dn_manager.SecondsPerRealSecond_Night = dn_manager.SecondsPerRealSecond_Day

    -- Debug Only
    if Config.transition_debug then
        if (dn_manager.LastKnownHour+0) < 4 then
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

    -- If Power Event
    if next_day_has_power then

        -- Prepare for Power Restore Next Hour
        if dn_manager.LastKnownHour == 4 then
            Utils.log("Next Day has Power: Now=5am")
            Utils.log("[Handle_OnRep_LastKnownHour]next_day_has_power: True")
            dn_manager.MorningStartHour = 6
            temp_power_meter = Config.temp_power_meter_max_hours
            dn_manager.NightfallStartHour = dn_manager.MorningStartHour + temp_power_meter
            if dn_manager.NightfallStartHour > 21 then
                dn_manager.NightfallStartHour = 21
            end
            Utils.log("[Handle_OnRep_LastKnownHour]dn_manager.NightfallStartHour: ")
            Utils.log(dn_manager.NightfallStartHour)
        end
        -- Trigger Morning Now at 6am
        if dn_manager.LastKnownHour == 6 and (Config.facility_power_off_always_night or Config.foggy_weather_enabled) then

            -- Msg 1
            Utils.AllClientDisplayWarningMessage("Something rumbles deep below...", Enums.ClientWarnMessageColors.Purple, false)

            -- Msg 2
            if Config.facility_power_off_always_night then
                local msg = string.format(".. Facility Power Temporarily Roars Back to Life! (%d hours)", temp_power_meter)
                Utils.AllClientDisplayWarningMessage(msg, Enums.ClientWarnMessageColors.Green, false)
            elseif Config.foggy_weather_enabled then
                local msg = string.format(".. The Facility Power Ventilation System Roars Back to Life! (%d hours)", temp_power_meter)
                Utils.AllClientDisplayWarningMessage(msg, Enums.ClientWarnMessageColors.Green, false)
            end

            next_day_has_power = false

            -- Attempt to Force Daytime
            local is_daytime = {}
            dn_manager.IsNight = false
            dn_manager:IsCurrentlyDaytime(is_daytime)

            -- Vent Weather
            if Config.foggy_weather_enabled then
                ExecuteWithDelay(3000, function()
                    ExecuteInGameThread(function()
                        Utils.TriggerWeatherEvent("None")
                    end)
                end)
            end
        end

    elseif Config.facility_power_off_always_night and temp_power_meter <= 0 then
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

            -- [TODO]: A player could get chopped by the Cafeteria Ventilation
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
        if Config.facility_power_off_always_night then
            Utils.log("temp_power_meter > 0, Set IsNight = false")
            dn_manager.MorningStartHour = 6
            dn_manager.NightfallStartHour = 21
            dn_manager.IsNight = false
            dn_manager.OnRep_IsNight()
            Utils.log("dn_manager.IsNight")
            Utils.log(dn_manager.IsNight)
        end
    elseif Config.facility_power_off_always_night then
        set_night(dn_manager)
    end

    -- Process the Weather Events Next
    if hour_tick % (Config.hours_per_weather_event) == 0 and temp_power_meter <= 0 then

        local power_dice_roll = math.random()
        Utils.log(string.format("Temp Emergency Power Roll: %.2f < %.2f", power_dice_roll*100, Config.temp_power_restore_chance))
        if power_dice_roll < (Config.temp_power_restore_chance/100) and Config.facility_power_off_always_night then
            next_day_has_power = true
            dn_manager.MorningStartHour = 6
            dn_manager.NightfallStartHour = 21
        else
            Utils.log("[Handle_OnRep_LastKnownHour]next_day_has_power: False")
        end

        if temp_power_meter <= 0 and not next_day_has_power then
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

    -- Simple Portal Reset Warning
    if Config.warn_on_portal_reset then
        if Utils.IsPortalResetEve() then
            if Utils.GetCurrentGameHour() == 20 then
                Utils.AllClientDisplayWarningMessage("Portal Reset ETA: 4 Hours", Enums.ClientWarnMessageColors.Yellow, true)
            end
            if Utils.GetCurrentGameHour() == 23 then
                Utils.AllClientDisplayWarningMessage("Portal Reset ETA: 1 Hour!", Enums.ClientWarnMessageColors.Red, true)
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

    if temp_power_meter > 0 or next_day_has_power then
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

    if temp_power_meter > 0 or next_day_has_power then
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


-- Server Side Supported
local function Handle_Request_SendTextChatMessage(Context, MessageToSend)
    Utils.log(">>>> Handle_Request_SendTextChatMessage Fired! <<< ")
    if not Context then return end
    local player_controller = Context:get() -- AAbioticPlayerController

    local steam_display_name = player_controller.MyPlayerCharacter.MyPlayerState:GetPlayerName():ToString()
    local message = MessageToSend:get():ToString()
    local msg_fmt = Utils.split_str(message, " ")

    local max_key = 0
    for k in pairs(msg_fmt) do
        if k ~= nil then
            max_key = k
        end
    end


    -- Get/Set Leyak Cooldown
    if (msg_fmt[1] == "/night") and max_key == 1 then
        dn_manager = Utils.GetDayNightManager()
        if Utils.IsValid(dn_manager) then
            set_night(dn_manager)
            local msg = "Attempting to Set Night..."
            Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
        end
    end

    if (msg_fmt[1] == "/day") and max_key == 1 then
        dn_manager = Utils.GetDayNightManager()
        if Utils.IsValid(dn_manager) then

            dn_manager.MorningStartHour = -1
            dn_manager.NightfallStartHour = -1
            dn_manager.IsNight = false
            dn_manager:OnRep_IsNight()


            ExecuteInGameThread(function()
                --dn_manager:InitDayNightTimer()
                dn_manager.IsNight = false
                temp_power_meter = 12
                dn_manager.MorningStartHour = 6
                dn_manager.NightfallStartHour = 21
                local msg = "Attempting to Set Day..."
                dn_manager:OnRep_IsNight()
                --OnRep_CurrentDay()
                --dn_manager:InitDayNightTimer()
                next_day_has_power = true
                Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
            end)
        end
    end

    if (msg_fmt[1] == "/debug") and max_key == 1 then
        local delay = 1000
        local delay_inc = 1000
        local msg = "Attempting to print Debugging..."
        Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)

        delay = delay + delay_inc
        ExecuteWithDelay(delay, function()
            local msg = string.format("LastKnownHour: %d", dn_manager.LastKnownHour)
            Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
        end)

        ExecuteWithDelay(delay, function()
            local msg = string.format("temp_power_meter: %d", temp_power_meter)
            Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
        end)

        ExecuteWithDelay(delay, function()
            local msg = string.format("next_day_has_power: %s", next_day_has_power)
            Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
        end)

        ExecuteWithDelay(delay, function()
            local msg = string.format("IsNight: %s", dn_manager.IsNight)
            Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
        end)

        ExecuteWithDelay(delay, function()
            local msg = string.format("MorningStartHour: %s", dn_manager.MorningStartHour)
            Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
        end)

        ExecuteWithDelay(delay, function()
            local msg = string.format("NightfallStartHour: %s", dn_manager.NightfallStartHour)
            Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
        end)
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
        local dn_manager = Utils.GetDayNightManager()
        if Config.facility_power_off_always_night then
            dn_manager.IsNight = true
            dn_manager:OnRep_IsNight()
        end
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

    -- /Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:OnRep_IsNight
    ExecuteWithDelay(2500, function()
    local okHook, errHook = pcall(RegisterHook,
        "/Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:OnRep_IsNight",
        Handle_OnRep_IsNight
    )
        if not okHook then
            print("NightShift Hook registration failed: %s", tostring(errHook))
        else
            print("NightShift Hook registration success: OnRep_IsNight")
        end
    end)

    -- /Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:IsCurrentlyDaytime
    ExecuteWithDelay(2500, function()
    local okHook, errHook = pcall(RegisterHook,
        "/Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:IsCurrentlyDaytime",
        Handle_IsCurrentlyDaytime
    )
        if not okHook then
            print("NightShift Hook registration failed: %s", tostring(errHook))
        else
            print("NightShift Hook registration success: IsCurrentlyDaytime")
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

    ExecuteWithDelay(2500, function()
        local okHook, errHook = pcall(RegisterHook,
            "/Game/Blueprints/Meta/Abiotic_PlayerController.Abiotic_PlayerController_C:Request_SendTextChatMessage",
            Handle_Request_SendTextChatMessage
        )
        if not okHook then
            Utils.error(string.format("Hook registration failed: %s", tostring(errHook)))
        else
            Utils.log("Hook registration success: Handle_Request_SendTextChatMessage")
        end
    end)

    NotifyOnNewObject("/Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C", function(dn_manager)
        Utils.log("NotifyOnNewObject: DayNightManager_C")
        Utils.CacheDayNightManager(dn_manager)

        -- Important: Overriding the start hours here is the magic combination that will make
        -- even the local clients think power is off at the very start for a dedicated server
        -- i.e Visual FX like the Cafeteria Ventilation Fan will be powered off and not moving even
        -- if this mod is not installed on the local player's instance / coming from CrossPlay
        if Config.facility_power_off_always_night then
            dn_manager.MorningStartHour = -1
            dn_manager.NightfallStartHour = -1
            dn_manager.IsNight = true
            dn_manager:OnRep_IsNight()
        end

        -- There will be some initial hiccups, so re-enforce night-time a bit after startup
        -- Don't try to set the first weather event here though, handle that during ReceiveBeginPlay
        -- instead to prevent Cleanup/GarbageCollection issues.
        if Config.facility_power_off_always_night then
            ExecuteWithDelay(2500, function()
                set_night(dn_manager)
                dn_manager.IsNight = true
                dn_manager:OnRep_IsNight()
            end)
        end

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
                Utils.TriggerWeatherEvent("Fog")
            else
                Config.disable_fog_venting = false
                Utils.TriggerWeatherEvent("None")
            end
            local stateMessage = "NightShift: Fog:" .. state
            Utils.log(stateMessage)
            Utils.AllClientDisplayWarningMessage(stateMessage, warningColor)

        end)
    end

    RegisterKeyBind(ToggleKey, ToggleKeyModifiers, function()
        SetModState(not ModEnabled)
    end)
end

Utils.log("Mod loaded successfully")
