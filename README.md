# Factorio-Stasis-Mine
Adds weapons that takes everything near by in to a temporary stasis, with them becoming frozen and immune from damage. Discovered as a by product of Effect Transmission (beacon) research gone wrong.

Weapon options include land mine, rocket and grenade.

![Stasis Land Mine Example](https://media.giphy.com/media/feaLga7G7lBaGcluQt/giphy.gif)



Mod Settings
------------

- Control if all or just opposing force's entities are frozen in stasis when a stasis weapon detonates.
- Control the time things are frozen for and how big the stasis blast area is.
- Mod startup settings to disable each of the stasis weapon types individually. This disables the technologies, recipes and item lists for the stasis weapon. It doesn't remove the items from the game so they can still be used via other mods in game. Each weapon defaults to not being disabled.
- Settings for if trains and spider vehicles are separately affected by stasis or not. Trains are fully affected by stasis, not per carriage. Spidertrons can never trigger landmines as this is just how Factorio works.



Notes
-----

- Things already in a stasis can not be affected by another stasis triggering. Only "free" things can enter a stasis.
- Inspired by the Protoss Stasis Trap in StarCraft 2, but adapted for Factorio.
- Stasis land mines are themselves immune from the stasis effect. So making a dense minefield is fine.
- Players are prevented from getting in and out of vehicles in stasis. This is done via script and not a Factorio permission group to maintain compatibility with other mods & scenarios. If the player gets out of the vehicle and is found to be more than a short distance away it is assumed to be intentional, i.e. via a teleport command from another script. This is try and keep it compatible with streamer integrations that teleport players and won't be aware that their vehicle was being affected by a stasis.
- When a rolling stock affected by stasis is disconnected from other carriages the effect is the same as in regular Factorio, however, this may feel odd due to the delay. Immediately the train parts will each be set to manual losing any station reservation. Once the stasis wears off if the train is moving it may crash in to the other parts of itself. A side effect of the rolling stock being is stasis is that it can not be connected back to other carriages during the stasis effect, but it can be disconnected; this is just base Factorio logic.
- Cars and spider-vehicles caught in a stasis are disabled (`active = false`), however this property can't be applied to trains. Everything in stasis can be identified as they have `destructible = false` and `openable = false`, which wouldn't normally be set on any regular Factorio entities; this can be used by other mods to exclude entities and vehicles affected by stasis as they would other weird modded entities.
- Disabled vehicles are able to fire a single shot (in the chamber) of any weapon. This is just how Factorio appears to work for disabled vehicles.



Remotely triggering an area stasis effect via Lua script
---------------------------------------------

You can remote trigger the stasis effect via a Lua script by creating a stasis grenade at the target position and it instantly will explode. While this isn't as elegant as me adding a bespoke remote interface call, it gives the same results.

#### Example Code

Example code below to create a stasis grenade at a given position. It will instantly explode causing a stasis effect.
Note: The semi colons on the end of each Lua snippet is to tell Lua where the end of each code snippet is, required by integrations that concatenate the Lua code in to a single line, and does no harm for other Lua code uses.

```
/sc
local player = game.get_player("muppet9010");
local position = player.position;
player.surface.create_entity({name="stasis-grenade", position=position, force="enemy", target=position, speed=0, max_range=0});
```


Remotely placing an entity in stasis via Lua script
---------------------------------------------

You can remote trigger the stasis effect on a single entity via a Lua script.

#### Arguments (in sequential order)

- Entity = Reference to the entity to place in stasis.
- Time = How many seconds (whole) the stasis effect will last. 5 or above.

#### Example Code

Example code below to stasis the player's vehicle/character for the set time.
Note: The semi colons on the end of each Lua snippet is to tell Lua where the end of each code snippet is, required by integrations that concatenate the Lua code in to a single line, and does no harm for other Lua code uses.

```
/sc
local player = game.get_player("muppet9010");
if player then;
    local entityToFreeze = player.vehicle or player.character;
    if entityToFreeze then;
        remote.call("stasis_weapons", "stasis_entity", entityToFreeze, 20);
    end;
end
```
