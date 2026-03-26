# One Button Hunter (OBH)

Designed for the new Marksman Hunter changes in Nightmares of Ursol (1.18.1)
One Button Hunter is a lightweight Hunter addon that lets you run both ranged and melee (Survival) rotations using simple macros while maintaining accurate shot timing and smart utility.

Updated for Nightmares of Ursol and current Hunter changes.

## Features

### Ranged Mode (Marksman-style)
- Prioritizes Aimed Shot when off cooldown
- Dynamic Steady Shot timing with haste compensation
- Smart Arcane Shot / Multi-Shot weaving
- Prevents Auto Shot clipping
- Automatic Hunter's Mark
- Concussive Shot + Feign Death on aggro (group)

### Melee Mode (Survival / Stalker)
- Full melee rotation with Lacerate priority
- Carve + Explosive Trap in AoE
- Immolation Trap in Single Target
- Raptor Strike / Mongoose Bite core loop
- Wing Clip as strict filler
- Strict melee-only targeting safety

### Smart Aspect System
- Automatic Aspect of the Hawk (Ranged)
- Automatic Aspect of the Wolf (Melee)
- Viper Aspect with hysteresis: Activates at ≤5% mana and stays active until 30% mana

- Safe and non-intrusive design (no risky full automation)

## Requirements
- Turtle WoW (Nightmares of Ursol patch)
- SuperWoW
- CleveRoid Macros (highly recommended)
- Nampower / UnitXP (optional but useful)

## Installation
1. Download or clone the addon into `TurtleWoW/Interface/AddOns/OneButtonHunter`
2. Restart WoW or type `/reload`

## Setup

Make sure the following abilities exist on your action bar:

* Aimed Shot
* Auto Shot
* Steady Shot
* Arcane Shot
* Multi-Shot
* Serpent Sting
* Feign Death
* Concussive Shot

The addon scans your action bar to find these abilities.

## Macro Usage

Create a macro and use one of the following:

### Ranged – Normal / AoE Mode

```
#showtooltip Aimed Shot
/cast !Trueshot Aura
/cast [combat] Rapid Fire
/run local c,f=CastSpellByName,function(k)for i=1,16 do local t=UnitDebuff("player",i)if t and strfind(strlower(t),k)then return 1 end end end if f("searing")then c("Multi-Shot")elseif f("black")then c("Arcane Shot")elseif f("poison")then c("Serpent Sting")end
/run OBH:Run(true)
```

Optional (Pet Attack):

```
Replace /run OBH:Run(true) with /run if UnitExists("target") then PetAttack() OBH:Run(true) end
```

### Ranged – Single Target Mode
```
#showtooltip Aimed Shot
/cast !Trueshot Aura
/cast [combat] Rapid Fire
/run local c,f=CastSpellByName,function(k)for i=1,16 do local t=UnitDebuff("player",i)if t and strfind(strlower(t),k)then return 1 end end end if f("black")then c("Arcane Shot")elseif f("poison")then c("Serpent Sting")end
/run OBH:Run(false) or [/run if UnitExists("target") then PetAttack() OBH:Run(false) end] for pet attack
```

### Melee – AoE

```
/cast !Trueshot Aura
/cast [combat] Rapid Fire
/startattack
/run OBHM:Run(true)
/run if UnitExists("target") then PetAttack() end
```

### Melee – Single Target

```
/cast !Trueshot Aura
/cast [combat] Rapid Fire
/startattack
/run OBHM:Run(false)
/run if UnitExists("target") then PetAttack() end
```

## Aspect Behavior

- **Hawk** → Used automatically in ranged mode (when mana > 10%)
- **Wolf** → Used automatically in melee mode (when mana > 10%)
- **Viper** → Automatically activates when mana ≤ 10% and stays on until mana reaches 40%

You can still manually cast aspects if needed — the addon will respect them.

## Notes

- The ranged engine (`OBH:Run`) is intentionally left untouched from the stable V6.6 version.
- The melee engine (`OBHM:Run`) follows strict ability-based targeting to avoid pet pulls.
- All aspects use simple "if missing → cast" logic to prevent flickering.
- Designed for high spam tolerance (you can mash the button safely).
- Designed specifically for Turtle WoW
- Requires SuperWoW for automatic Feign Death functionality
- Depends on action bar scanning to locate abilities

## Load Message

On login or reload:

```
OBH V7.0 (Aspects Update) Loaded.
```
