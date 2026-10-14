return {
    -- [Debug] ============================================
    -- Enable debug log.
    Debug = true,
    transition_debug = false,

    -- [General Config] ===================================
    foggy_weather_enabled = true,
    disable_fog_venting = true,
    warn_on_portal_reset = true,
    hours_per_weather_event = 30,
    player_starts_with_trinket = true,
    player_starts_with_lantern = true,

    -- [Facility Temporary Emergency Power]
    -- Chance for Temporary Facility Emergency Power Restoration
    temp_power_restore_chance = 10,
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

    -- Starting Event Config:
    fog_type = "Fog",

    -- Event List Config:
    -- Select One or More Weather events
    -- "None",
    -- "Fog",
    -- "RadLeak",
    -- "Spores",
	-- "ColdSnap",
	-- "Blackout",
	-- "BlackFog",
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
