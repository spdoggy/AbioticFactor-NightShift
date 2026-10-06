return {
    -- Enable debug log.
    Debug = true,

    -- General Config
    disable_fog_venting = true,
    hours_per_weather_event = 25,
    player_starts_with_trinket = true,
    player_starts_with_lantern = true,

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
