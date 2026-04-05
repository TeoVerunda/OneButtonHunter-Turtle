# One Button Hunter (OBH)

Designed for Turtle WoW – Nightmares of Ursol (1.18.1+)

One Button Hunter is a lightweight Hunter addon that lets you run both ranged (Marksman & Beast Mastery) and melee (Survival) rotations using simple macros while maintaining accurate shot timing and smart utility.

## Features

### Ranged Mode (Marksman-style - Advanced Engine)
- Prioritizes Aimed Shot when off cooldown
- Dynamic Steady Shot timing with haste compensation
- Smart Arcane Shot / Multi-Shot weaving
- Prevents Auto Shot clipping
- Automatic Hunter's Mark
- Concussive Shot + Feign Death on aggro (in group)

### Beast Mastery Mode (Simplified Engine)
- Clean Auto Shot + Steady Shot rotation
- Multi-Shot as AoE filler
- Kill Command included in Macro
- Same smart utilities as Marksman (Mark, Feign, aspects)

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
- Viper Aspect with hysteresis: Activates at ≤10% mana and stays active until 40% mana
- Toggleable with `/obh aspect on | off`

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

**(Marksman & Beast Mastery)**
- Aimed Shot (for MM)
- Auto Shot
- Steady Shot
- Arcane Shot (for MM)
- Multi-Shot
- Feign Death
- Concussive Shot
- Kill Command (optional – macro it yourself for BM)

**(Survival)**
- Lacerate
- Carve
- Explosive Trap
- Immolation Trap
- Raptor Strike
- Mongoose Bite
- Wing Clip

The addon scans your action bar to locate these abilities.

## Macro Usage

### Ranged – Marksman Normal / AoE Mode

```
#showtooltip Aimed Shot
/cast !Trueshot Aura
/cast [combat] Rapid Fire
/run local c,f=CastSpellByName,function(k)for i=1,16 do local t=UnitDebuff("player",i)if t and strfind(strlower(t),k)then return 1 end end end if f("poison")then c("Serpent Sting")end
/run if UnitExists("target") then PetAttack() OBH:RunAdvanced(true) end
```

Optional (Pet Attack):

```
Replace /run OBH:Run(true) with /run if UnitExists("target") then PetAttack() OBH:RunAdvanced((true) end
```

### Ranged – Single Target Mode
```
#showtooltip Aimed Shot
/cast !Trueshot Aura
/cast [combat] Rapid Fire
/run local c,f=CastSpellByName,function(k)for i=1,16 do local t=UnitDebuff("player",i)if t and strfind(strlower(t),k)then return 1 end end end if f("poison")then c("Serpent Sting")end
/run OBH:RunAdvanced((false) or [/run if UnitExists("target") then PetAttack() OBH:RunAdvanced((false) end] for pet attack
```

### Beast Mastery – Normal
```
#showtooltip Aimed Shot
/cast !Trueshot Aura
/cast [combat] Rapid Fire
/run if UnitExists("target") then PetAttack() OBHBeast:Run(true) end
/cast Kill Command
```

### Beast Mastery – Single Target
```
#showtooltip Aimed Shot
/cast !Trueshot Aura
/cast [combat] Rapid Fire
/run if UnitExists("target") then PetAttack() OBHBeast:Run(false) end
/cast Kill Command

```

### Melee – AoE

```
/cast !Trueshot Aura
/cast [combat] Rapid Fire
/run OBHM:Run(true)
/run if UnitExists("target") then PetAttack() if (MyAttacking ~= UnitName("target")) then AttackTarget() MyAttacking = UnitName("target") end end
```

### Melee – Single Target

```
/cast !Trueshot Aura
/cast [combat] Rapid Fire
/run OBHM:Run(false)
/run if UnitExists("target") then PetAttack() if (MyAttacking ~= UnitName("target")) then AttackTarget() MyAttacking = UnitName("target") end end
```



## Aspect Behavior
- **Hawk** → Used automatically in ranged mode (when mana > 10%)
- **Wolf** → Used automatically in melee mode (when mana > 10%)
- **Viper** → Automatically activates when mana ≤ 10% and stays on until mana reaches 40%

You can toggle the Aspect Manager with:
- `/obh aspect on`
- `/obh aspect off`
- `/obh aspect` (shows status)

## Notes
- The advanced ranged engine (`OBH:RunAdvanced`) is the recommended Marksman rotation.
- Beast Mastery uses a simplified engine (`OBHBeast:Run`) focused on Auto Shot + Steady Shot (Kill Command can be macroed separately).
- Melee targeting is strict to avoid accidental pet pulls.
- All aspects use simple "if missing → cast" logic to prevent flickering.
- Designed for high spam tolerance (you can mash the button safely).
- Requires SuperWoW for best Feign Death functionality.

## Load Message
On login or reload:

```
OBH V9.0 (BM Simplified) Loaded. Aspect Manager: ENABLED
Use /obh aspect on | off | status
```
