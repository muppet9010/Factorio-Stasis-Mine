# Factorio-Stasis-Mine
Adds weapons that when triggered takes everything near by in to a temporary stasis, with them becoming frozen and immune from damage.
Discovered as a by product of Effect Transmission (beacon) research gone wrong.
Weapon options include land mine, rocket and grenade.

![Stasis Land Mine Example](https://media.giphy.com/media/feaLga7G7lBaGcluQt/giphy.gif)

Spidertrons have been hardened against the stasis effect and so is unaffected. They also don't detonate enemy mines of any type as default in Factorio.



Mod Settings
------------

- Control if all or just opposing force's entities are frozen in stasis when a stasis weapon detonates.
- Control the time things are frozen for. Defaults to 20 seconds
- Mod startup settings to disable each of the stasis weapon types individually. This disables the technologies, recipes and item lists for the stasis weapon. It doesn't remove the items so they can still be used via other mods in game. Defaults to not being disabled.



Notes
-----

- Things already in a stasis can not be affected by another stasis triggering. Only "free" things can enter a stasis.
- Inspired by the Protoss Stasis Trap in StarCraft 2, but adapted for Factorio.
- Stasis land mines are themselves immune from the stasis effect.



Remotely triggering the effect via Lua script
---------------------------------------------

You can remote trigger the stasis effect via a Lua script by creating a stasis grenade at the target position and it instantly will explode. While this isn't as elegant as me adding a bespoke remote interface call, it gives the same results.

Example code below.
Note: The semi colons on the end of each Lua snippet is to tell Lua where the end of each code snippet is, required by integrations that concatenate the Lua code in to a single line, and does no harm for other Lua code uses.

```
/sc
local player = game.get_player("muppet9010");
local position = player.position;
player.surface.create_entity({name="stasis-grenade", position=position, force="enemy", target=position, speed=0, max_range=0});
```