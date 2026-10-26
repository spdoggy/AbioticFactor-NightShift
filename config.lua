return {

    -- [Debug] ============================================
    -- Enable debug log.
    Debug = true,

    -- True = Speed up time greatly, slow down between 5-8am
    transition_debug = false,

    -- [General Config] ===================================
    -- True = Facility Power is Off and it's night-time/dark
    facility_power_off_always_night = true,

    -- True = Fog Weather Events Enabled
    foggy_weather_enabled = true,

    -- True = Silo-3 Weather Fog Venting Button is Disabled
    disable_fog_venting = true,

    -- Refresh the weather events every X hours
    hours_per_weather_event = 25,

    -- True = Display a warning message to all before reset
    warn_on_portal_reset = true,

    -- True = New Players start with a light emitting trinket
    player_starts_with_trinket = true,

    -- True = New Players start with a Lantern (powered)
    player_starts_with_lantern = true,


    -- [Facility Temporary Emergency Power] ===============
    -- Chance for Temporary Facility Emergency Power Restoration
    temp_power_restore_chance = 50,
    temp_power_meter_max_hours = 14,


    -- [Player Starting Kit] ==============================
    -- Add your own custom starting items below to the kit
    -- https://docs.google.com/spreadsheets/d/1IA3mMS6LnLzyneEEeh2-52-RhgqjlTjj5Nno1RPF56c/edit?gid=908652592#gid=908652592
    -- Or use the ItemSpawner mod ( https://www.nexusmods.com/abioticfactor/mods/175 ) to search for item_ids
    -- [TODO]: Add an item_id exporter for the mod and include a text file example
    enable_custom_emergency_starter_kit = true,
    custom_emergency_starter_kit = {
        {cat = "Craftables", item_id = "net",          qty = 10, table = "/Game/Blueprints/Items/ItemTable_Craftables.ItemTable_Craftables"},
        {cat = "Weapons",    item_id = "net_launcher", qty =  1, table = "/Game/Blueprints/Items/ItemTable_Weapons.ItemTable_Weapons"},
    },

    -- [Weather Config] ===================================

    -- First/Starting Weather Event:
    fog_type = "Fog",

    -- Weather Event List:
    -- Add One or More Weather events to weather_event_selection below
    -- Valid Weather Names are:
    --   "None",
    --   "Fog",
    --   "RadLeak",
    --   "Spores",
	--   "ColdSnap",
	--   "Blackout",
	--   "BlackFog",
    -- Can repeat items in the list to (un)-balance the
    --  chance for one or more events
    weather_event_selection = {
        "Fog",
        "Fog",
        "Fog",
        "BlackFog",
        "Fog",
    }
}
