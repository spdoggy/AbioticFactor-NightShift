--[[
    Author: SpDoggy
    Date: 2026-08-19
    Mod Name: NightShift
]]

---------- Configurations ----------
-- Enable mod from the start
ModEnabled = true


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
local hour_tick = 0
local temp_power_meter = 0
local next_day_has_power = false
local PowerOnEventStates = {
    Inactive = "Inactive",
    WaitForDay = "WaitingForDayMorningHour",
    PowerOn = "PowerOn",
    PowerOff = "PowerOff"
}
local power_on_event_state = PowerOnEventStates.Inactive
local next_morning_hour = -1
local next_nightfall_hour = -1

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

--- Setup Day or Night Transition in an offset from current time
---@param dn_manager ADayNightManager_C
---@param day_or_night string
---@param trigger_in_x_hours number
---@return number trigger_hour
local function setup_day_night_trigger(dn_manager, day_or_night, trigger_in_x_hours)

    if not Utils.IsValid(dn_manager) then
        dn_manager = Utils.GetDayNightManager()
        if not Utils.IsValid(dn_manager) then
            Utils.error("[]: Could not get valid DayNightManager")
            return
        end
    end

    trigger_in_x_hours = trigger_in_x_hours or 1
    day_or_night = day_or_night or "night"
    local trigger_hour = (Utils.GetCurrentGameHour() + trigger_in_x_hours) % 24
    if day_or_night == "day" then
        dn_manager.MorningStartHour = trigger_hour
    else
        dn_manager.NightfallStartHour = trigger_hour
    end
    local msg = string.format("[setup_day_night_trigger]: %s, Hour = %d", day_or_night, trigger_hour)
    Utils.log(msg)

    return trigger_hour
end

local function Handle_IsCurrentlyDaytime(context, IsDaytime)
    if not ModEnabled then
        return
    end
    is_daytime = IsDaytime:get()
    msg = string.format("[Handle_IsCurrentlyDaytime]IsDaytime: %s", is_daytime)
    Utils.log(msg)
    if next_day_has_power or temp_power_meter > 0 then
        Utils.log("[Handle_IsCurrentlyDaytime] Temp Power, Force IsDaytime True")
        IsDaytime:set(true)
    end

end

local function Handle_OnRep_IsNight(context)

    if not ModEnabled then
        return
    end
    local dn_manager = context:get()
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

--- Print DayNightManager debugging to UE4SS log
---@param dn_manager ADayNightManager_C
local function DebugLogDayNightManager(dn_manager)
    if not Utils.IsValid(dn_manager) then
        return
    end

    local msg = ""

    msg = string.format("power_on_event_state: %s", power_on_event_state)
    Utils.log(msg)

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
-- Main handler for Fog, Night, and Power State machine
local function Handle_OnRep_LastKnownHour(context)

    if not ModEnabled then
        return
    end

    Utils.log("[Handle_OnRep_LastKnownHour]")

    local dn_manager = context:get()
    if Utils.IsValid(dn_manager) then
        Utils.CacheDayNightManager()
    else
        return
    end

    -- Hourly Debug 
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

    -- State: WaitForDay -> PowerOn
    if power_on_event_state == PowerOnEventStates.WaitForDay then
        -- If Time for Power On Event, Broadcast Text Message
        if next_morning_hour == dn_manager.LastKnownHour then

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

            -- Record that Power On Event is kicked-off
            next_day_has_power = false
            power_on_event_state = PowerOnEventStates.PowerOn
        end

    -- State: PowerOn -> PowerOff
    elseif power_on_event_state == PowerOnEventStates.PowerOn then
        if next_nightfall_hour == dn_manager.LastKnownHour then
            power_on_event_state = PowerOnEventStates.PowerOff
        end

    -- State: PowerOff -> Inactive
    elseif power_on_event_state == PowerOnEventStates.PowerOff then
        if next_nightfall_hour ~= dn_manager.LastKnownHour then
            power_on_event_state = PowerOnEventStates.Inactive
            dn_manager.MorningStartHour = -1
            dn_manager.NightfallStartHour = -1
            next_nightfall_hour = -1
            next_morning_hour = -1
        end
    end

    -- Process the Power/Weather Events Next, State: Inactive -> WaitForDay
    if hour_tick % (Config.hours_per_weather_event) == 0 and temp_power_meter <= 0 then

        local power_dice_roll = math.random()
        local msg = string.format("Temp Emergency Power Roll: %.2f < %.2f", power_dice_roll*100, Config.temp_power_restore_chance)
        Utils.log(msg)

        -- TODO: Remove Debug
        Utils.AllClientDisplayWarningMessage(msg, Enums.ClientWarnMessageColors.Green, false)

        if power_dice_roll < (Config.temp_power_restore_chance/100) and Config.facility_power_off_always_night then
            -- Setup Next Transitions
            next_morning_hour = setup_day_night_trigger(dn_manager, "day", 1)
            next_nightfall_hour = setup_day_night_trigger(dn_manager, "night", Config.temp_power_meter_max_hours)
            -- Record Start of Power On Event
            power_on_event_state = PowerOnEventStates.WaitForDay
            next_day_has_power = true
            temp_power_meter = Config.temp_power_meter_max_hours
        else
            Utils.log("[Handle_OnRep_LastKnownHour]next_day_has_power: False")
        end

        -- Set Next Weather Event if Fog config is on, and not blocked by PowerOn Event
        if temp_power_meter <= 0 and not next_day_has_power then
            if Config.foggy_weather_enabled then
                Utils.log("Selecting New Weather...")
                ExecuteWithDelay(1000, function()
                    ExecuteInGameThread(function()
                        Utils.TriggerWeatherEvent("None")
                    end)
                end)
                ExecuteWithDelay(4000, function()
                    ExecuteInGameThread(function()
                        local selected = math.random(1, #Config.weather_event_selection)
                        Utils.log(Config.weather_event_selection[selected])
                        Utils.TriggerWeatherEvent(Config.weather_event_selection[selected])
                    end)
                end)
            end
        end
    end

    -- Decrement temp_power_meter counter
    Utils.log("temp_power_meter: "..temp_power_meter)
    if temp_power_meter > 0 then
        temp_power_meter = temp_power_meter - 1
    end

    -- -- If Power Event
    -- if next_day_has_power then

    --     -- Prepare for Power Restore Next Hour

    --     if dn_manager.LastKnownHour == 4 then
    --         Utils.log("Next Day has Power: Now=5am")
    --         Utils.log("[Handle_OnRep_LastKnownHour]next_day_has_power: True")
    --         dn_manager.MorningStartHour = 6
    --         temp_power_meter = Config.temp_power_meter_max_hours
    --         dn_manager.NightfallStartHour = 5
    --         -- dn_manager.NightfallStartHour = dn_manager.MorningStartHour + temp_power_meter
    --         -- if dn_manager.NightfallStartHour > 21 then
    --         --     dn_manager.NightfallStartHour = 21
    --         -- end
    --         Utils.log("[Handle_OnRep_LastKnownHour]dn_manager.NightfallStartHour: ")
    --         Utils.log(dn_manager.NightfallStartHour)
    --     end
    --     -- Trigger Morning Now at 6am
    --     if dn_manager.LastKnownHour == 6 and (Config.facility_power_off_always_night or Config.foggy_weather_enabled) then

    --         -- Msg 1
    --         Utils.AllClientDisplayWarningMessage("Something rumbles deep below...", Enums.ClientWarnMessageColors.Purple, false)

    --         -- Msg 2
    --         if Config.facility_power_off_always_night then
    --             local msg = string.format(".. Facility Power Temporarily Roars Back to Life! (%d hours)", temp_power_meter)
    --             Utils.AllClientDisplayWarningMessage(msg, Enums.ClientWarnMessageColors.Green, false)
    --         elseif Config.foggy_weather_enabled then
    --             local msg = string.format(".. The Facility Power Ventilation System Roars Back to Life! (%d hours)", temp_power_meter)
    --             Utils.AllClientDisplayWarningMessage(msg, Enums.ClientWarnMessageColors.Green, false)
    --         end

    --         next_day_has_power = false

    --         -- Attempt to Force Daytime
    --         local is_daytime = {}
    --         dn_manager.IsNight = false
    --         dn_manager:IsCurrentlyDaytime(is_daytime)

    --         -- Vent Weather
    --         if Config.foggy_weather_enabled then
    --             ExecuteWithDelay(3000, function()
    --                 ExecuteInGameThread(function()
    --                     Utils.TriggerWeatherEvent("None")
    --                 end)
    --             end)
    --         end
    --     end

    -- elseif Config.facility_power_off_always_night and temp_power_meter <= 0 then
    --     -- Set back to Night After Clearing Anomalies Should be no 
    --     -- announcements played with this method, i.e when processed
    --     -- in the same within the same Handle_OnRep_LastKnownHour call
    --     -- Security Robots may reset from patrol, however they should
    --     -- resume normal cycles next day or during loading zones
    --     if dn_manager.LastKnownHour == 5 then
    --         -- Transition Required to Clear Anomalies
    --         dn_manager.MorningStartHour = 6
    --         dn_manager.NightfallStartHour = 7
    --     elseif dn_manager.LastKnownHour == 6 then
    --         dn_manager.MorningStartHour = -1
    --         dn_manager.NightfallStartHour = 7

    --         -- [TODO]: A player could get chopped by the Cafeteria Ventilation
    --         -- between approx 6:40 and 7:00 am in some cases
    --         ExecuteWithDelay(10000, function()
    --             dn_manager.IsNight = true
    --             dn_manager.OnRep_IsNight()
    --         end)
    --     else
    --         dn_manager.MorningStartHour = -1
    --         dn_manager.NightfallStartHour = -1
    --         dn_manager.IsNight = true
    --         dn_manager.OnRep_IsNight()
    --     end
    -- end

    -- Utils.log("temp_power_meter: "..temp_power_meter)
    -- -- Check Night while here
    -- if temp_power_meter > 0 then
    --     temp_power_meter = temp_power_meter - 1
    --     if Config.facility_power_off_always_night then
    --         Utils.log("temp_power_meter > 0, Set IsNight = false")
    --         dn_manager.MorningStartHour = 6
    --         dn_manager.NightfallStartHour = -1
    --         dn_manager.IsNight = false
    --         dn_manager.OnRep_IsNight()
    --         Utils.log("dn_manager.IsNight")
    --         Utils.log(dn_manager.IsNight)
    --     end
    -- elseif Config.facility_power_off_always_night then
    --     set_night(dn_manager)
    -- end

    -- -- Process the Weather Events Next
    -- if hour_tick % (Config.hours_per_weather_event) == 0 and temp_power_meter <= 0 then

    --     local power_dice_roll = math.random()
    --     Utils.log(string.format("Temp Emergency Power Roll: %.2f < %.2f", power_dice_roll*100, Config.temp_power_restore_chance))
    --     if power_dice_roll < (Config.temp_power_restore_chance/100) and Config.facility_power_off_always_night then
    --         next_day_has_power = true
    --         dn_manager.MorningStartHour = 6
    --         dn_manager.NightfallStartHour = -1
    --     else
    --         Utils.log("[Handle_OnRep_LastKnownHour]next_day_has_power: False")
    --     end

    --     if temp_power_meter <= 0 and not next_day_has_power then
    --         if Config.foggy_weather_enabled then
    --             Utils.log("Selecting New Weather...")
    --             ExecuteWithDelay(1000, function()
    --                 ExecuteInGameThread(function()
    --                     Utils.TriggerWeatherEvent("None")
    --                 end)
    --             end)
    --             ExecuteWithDelay(4000, function()
    --                 ExecuteInGameThread(function()
    --                     local selected = math.random(1, #Config.weather_event_selection)
    --                     Utils.log(Config.weather_event_selection[selected])
    --                     Utils.TriggerWeatherEvent(Config.weather_event_selection[selected])
    --                 end)
    --             end)
    --         end
    --     end
    -- end

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

    if not ModEnabled then
        return
    end

    local dn_manager = context:get()
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
            Utils.log(string.format("[Handle_VentWeatherFXToAllPlayers]: %s", Config.weather_event_selection[selected]))
            Utils.TriggerWeatherEvent(Config.weather_event_selection[selected])
        end)
    end
end

local function Handle_ClearActiveWeatherRequests(context)

    if not ModEnabled then
        return
    end

    local dn_manager = context:get()
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
                ExecuteWithDelay(1000, function()
                    Utils.TriggerWeatherEvent("None")
                end)
                ExecuteWithDelay(4000, function()
                    local selected = math.random(1, #Config.weather_event_selection)
                    Utils.log(string.format("[Handle_ClearActiveWeatherRequests]: %s", Config.weather_event_selection[selected]))
                    Utils.TriggerWeatherEvent(Config.weather_event_selection[selected])
                end)
            end
        end
    end
end


local function Handle_IsPowered(context, PowerOn)

    if not ModEnabled then
        return
    end

    if not context then
        return
    end

    local socket = context:get()
    local power_on = PowerOn:get()
    if temp_power_meter > 0 then
        --context:Broadcast_PowerInterruptContinued()
        --PowerOn:set(true)
        socket.PowerInterrupted = false
        socket.CachedPowerState = true
        --context:OnRep_PowerInterrupted()
        PowerOn:set(true)
        socket:TogglePowerFX()
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

    if (msg_fmt[1] == "/night_shift") and max_key == 1 then
        ModEnabled = not ModEnabled
        if ModEnabled then
            local msg = "Night Shift Enabled!"
            Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
        else
            local msg = "Night Shift Disabled!"
            Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.red)
        end
    end

    local dn_manager = Utils.GetDayNightManager()

    if (msg_fmt[1] == "/morning") and max_key == 2 then
        dn_manager = Utils.GetDayNightManager()
        if Utils.IsValid(dn_manager) then
            local msg = string.format("Attempting to Set MorningStartHour to %d", msg_fmt[2])
            Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
            dn_manager.MorningStartHour = msg_fmt[2]
        end
    end

    if (msg_fmt[1] == "/nightfall") and max_key == 2 then
        dn_manager = Utils.GetDayNightManager()
        if Utils.IsValid(dn_manager) then
            local msg = string.format("Attempting to Set NightfallStartHour to %d", msg_fmt[2])
            Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
            dn_manager.NightfallStartHour = msg_fmt[2]
        end
    end

    if (msg_fmt[1] == "/night") and max_key == 1 then
        dn_manager = Utils.GetDayNightManager()
        if Utils.IsValid(dn_manager) then
            dn_manager.MorningStartHour = -1
            dn_manager.NightfallStartHour = Utils.GetCurrentGameHour() + 1
            -- dn_manager:OnRep_IsNight()
            -- dn_manager:Nightfall__DelegateSignature()
            local msg = "Attempting to Set Night..."
            Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
        end
    end

    if (msg_fmt[1] == "/blackout") and max_key == 1 then
        dn_manager = Utils.GetDayNightManager()
        if Utils.IsValid(dn_manager) then
            local msg = "Attempting to Set OnRep_BlackoutActive..."
            dn_manager:OnRep_BlackoutActive()
            dn_manager:OnRep_CurrentWeatherEvent()
            dn_manager:CheckForVignetteResets()
            dn_manager.DayNightManuallyPaused = true
            dn_manager.DayNightManuallyPaused = false
            --dn_manager:Toggle_Day_NightCycle()
            Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
        end
    end

    if (msg_fmt[1] == "/power") and max_key == 1 then
        local msg = "Set Next Day Power..."
        temp_power_meter = 12
        next_day_has_power = true
        Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
    end

    if (msg_fmt[1] == "/day") and max_key == 1 then
        dn_manager = Utils.GetDayNightManager()
        if Utils.IsValid(dn_manager) then
            -- dn_manager.MorningStartHour = 6
            -- dn_manager.NightfallStartHour = 21
            -- dn_manager.IsNight = false
            -- dn_manager:OnRep_IsNight()
            -- dn_manager:Morning__DelegateSignature()
            -- dn_manager:InitDayNightTimer()

            local msg = "Attempting to Set Day..."
            -- dn_manager:OnRep_CurrentDay()
            Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
            dn_manager.MorningStartHour = Utils.GetCurrentGameHour() + 1
            dn_manager.NightfallStartHour = -1
        end
    end

    if (msg_fmt[1] == "/debug") and max_key == 1 then
        dn_manager = Utils.GetDayNightManager()
        if Utils.IsValid(dn_manager) then
            local delay = 1000
            local delay_inc = 500
            local msg = "Attempting to print Debugging..."
            Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)

            delay = delay + delay_inc

            ExecuteWithDelay(delay, function()
                local msg = string.format("power_on_event_state: %s", power_on_event_state)
                Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
                Utils.log(msg)
            end)

            ExecuteWithDelay(delay, function()
                local msg = string.format("LastKnownHour: %d", dn_manager.LastKnownHour)
                Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
                Utils.log(msg)
            end)

            ExecuteWithDelay(delay, function()
                local msg = string.format("temp_power_meter: %d", temp_power_meter)
                Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
                Utils.log(msg)
            end)

            ExecuteWithDelay(delay, function()
                local msg = string.format("next_day_has_power: %s", next_day_has_power)
                Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
                Utils.log(msg)
            end)

            ExecuteWithDelay(delay, function()
                local msg = string.format("IsNight: %s", dn_manager.IsNight)
                Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
                Utils.log(msg)
            end)

            ExecuteWithDelay(delay, function()
                local msg = string.format("MorningStartHour: %s", dn_manager.MorningStartHour)
                Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
                Utils.log(msg)
            end)

            ExecuteWithDelay(delay, function()
                local msg = string.format("NightfallStartHour: %s", dn_manager.NightfallStartHour)
                Utils.PlayCtrlTextChatMessage(player_controller, msg, MOD_PREFIX, Enums.MsgColors.bg, Enums.MsgColors.green)
                Utils.log(msg)
            end)
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
            Utils.log("NightShift Hook registration failed: %s", tostring(errHook))
        else
            Utils.log("NightShift Hook registration success: Handle_IsCurrentlyDaytime")
        end
    end)

    -- Function /Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:VentWeatherFXToAllPlayers
    ExecuteWithDelay(2500, function()
    local okHook, errHook = pcall(RegisterHook,
        "/Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:VentWeatherFXToAllPlayers",
        Handle_VentWeatherFXToAllPlayers
    )
        if not okHook then
            Utils.log("NightShift Hook registration failed: %s", tostring(errHook))
        else
            Utils.log("NightShift Hook registration success: VentWeatherFXToAllPlayers")
        end
    end)

    -- Function /Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:ClearActiveWeatherRequests
    ExecuteWithDelay(2500, function()
    local okHook, errHook = pcall(RegisterHook,
        "/Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:ClearActiveWeatherRequests",
        Handle_ClearActiveWeatherRequests
    )
        if not okHook then
            Utils.log("NightShift Hook registration failed: %s", tostring(errHook))
        else
            Utils.log("NightShift Hook registration success: ClearActiveWeatherRequests")
        end
    end)

    -- /Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:OnRep_LastKnownHour
    ExecuteWithDelay(2500, function()
    local okHook, errHook = pcall(RegisterHook,
        "/Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:OnRep_LastKnownHour",
        Handle_OnRep_LastKnownHour
    )
        if not okHook then
            Utils.log("NightShift Hook registration failed: %s", tostring(errHook))
        else
            Utils.log("NightShift Hook registration success: OnRep_LastKnownHour")
        end
    end)

    -- -- /Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:OnRep_IsNight
    -- ExecuteWithDelay(2500, function()
    -- local okHook, errHook = pcall(RegisterHook,
    --     "/Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:OnRep_IsNight",
    --     Handle_OnRep_IsNight
    -- )
    --     if not okHook then
    --         Utils.log("NightShift Hook registration failed: %s", tostring(errHook))
    --     else
    --         Utils.log("NightShift Hook registration success: OnRep_IsNight")
    --     end
    -- end)

    -- -- /Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:IsCurrentlyDaytime
    -- ExecuteWithDelay(2500, function()
    -- local okHook, errHook = pcall(RegisterHook,
    --     "/Game/Blueprints/Environment/Systems/DayNightManager.DayNightManager_C:IsCurrentlyDaytime",
    --     Handle_IsCurrentlyDaytime
    -- )
    --     if not okHook then
    --         Utils.log("NightShift Hook registration failed: %s", tostring(errHook))
    --     else
    --         Utils.log("NightShift Hook registration success: IsCurrentlyDaytime")
    --     end
    -- end)

    -- /Game/Blueprints/Meta/Abiotic_Survival_GameState.Abiotic_Survival_GameState_C:ReceiveBeginPlay
    ExecuteWithDelay(2500, function()
    local okHook, errHook = pcall(RegisterHook,
        "/Game/Blueprints/Meta/Abiotic_Survival_GameState.Abiotic_Survival_GameState_C:ReceiveBeginPlay",
        Handle_ReceiveBeginPlay
    )
        if not okHook then
            Utils.log("NightShift Hook registration failed: %s", tostring(errHook))
        else
            Utils.log("NightShift Hook registration success: ReceiveBeginPlay")
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
            Utils.log("Hook registration success: Request_SendTextChatMessage")
        end
    end)

    -- ExecuteWithDelay(2500, function()
    --     local okHook, errHook = pcall(RegisterHook,
    --         "/Game/Blueprints/Environment/Electrical/PowerSocket_ParentBP.PowerSocket_ParentBP_C:IsPowered",
    --         Handle_IsPowered
    --     )
    --     if not okHook then
    --         Utils.error(string.format("Hook registration failed: %s", tostring(errHook)))
    --     else
    --         Utils.log("Hook registration success: IsPowered")
    --     end
    -- end)

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
