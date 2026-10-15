# AbioticFactor-NightShift
It's Abiotic Factor, but it's dark and foggy


`Here at the Gate Cascade Research facility, safety and security demand we take our Primary Power network offline at night.`

Unfortunately for the scientists in a facility with this mod, the power almost never comes back on, the lights are off, it's foggy, and the emergency venting systems are busted!

- The Fog Weather Event will be applied every 25 hours (configurable, can be changed or disabled)
- The Fog Venting Button in Silo 3 will not work, the fog will re-appear in a few seconds.
- There is a 1 in 5 chance to get the Security Sector Black Fog weather event instead of regular Fog (configurable)
- The RadLeak Weather Event will change to Fog instead
- Facility Power Outlets are disabled, players must charge batteries with the facility built-in Security Charging Stations (configurable, can be overridden in Sandboxsettings.ini)
- Overhead Lights are off in most areas
- Players will start with an emergency kit of the following: MakeshiftBattery, FieldBattery, Lantern, and a LightTrinket (configurable)
- Sleeping will (generally) pass time very quickly
- The mod now automatically updates the night-time clock speed to match the day time speed. 
- Most Night-time features will be more active
- A simple warning for Portal Resets (configurable)
- There is a 10% chance for emergency power to kick on and clear the fog (configurable)


# Installation instructions

Be sure to install UE4SS first! (UE4SS: https://www.nexusmods.com/abioticfactor/mods/35)

This mod is intended to be installed by the Host Player running UE4SS, or on a Dedicated Server install running UE4SS.
Note that I have not tested cross-play functionality, but I hope it will work for all players.

The entire NightShift mod folder should be placed into the players /ue4ss/Mods folder of your AbioticFactor installation.

i.e Windows:
`C:\Program Files (x86)\Steam\steamapps\common\AbioticFactor\AbioticFactor\Binaries\Win64\ue4ss\Mods\NightShift`

Dedicated Server:
`/AbioticFactor/Binaries/Win64/ue4ss/Mods\NightShift`

Linux example:
`/home/sp/.steam/debian-installation/steamapps/common/AbioticFactor/AbioticFactor/Binaries/Win64/ue4ss/Mods\NightShift`

See the file, 'NightShift/config.lua', for the mod's configurable options.

# Additional Notes

## Using a Field Battery
1. If you're having trouble with the field battery, try moving it around first in your inventory, then right-click/ use your secondary interact controller button on the MakeShift Battery to recharge it.


## Charging Batteries on the facility Gate Charging Stations
2. To charge a battery (MakeShift or later variants) you can use the Gate Charging Station in the lobby and those scattered around the Facility. With a packaged and depleted battery in your inventory, long-press the primary interact button to bring up a radial menu and then select the depleted battery.  Problem: 

    Sometimes the game thinks you already have an item on the charger or it doesn't want to open the menu. Usually if you are persistent in re-trying the primary interact key or try swapping items it eventually will open the radial menu and show the battery, but I'm not sure why this happens, even in non-modded gameplay. 


# Source
https://github.com/spdoggy/AbioticFactor-NightShift
