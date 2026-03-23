# One Button Hunter

One Button Hunter (OBH) is a Turtle WoW Hunter addon that allows you to run your rotation through a single button while maintaining proper shot timing and avoiding Auto Shot clipping.

Updated for Nightmares of Ursol and current Hunter changes.

## Features

* One-button Hunter rotation helper
* Prioritises Aimed Shot when off cooldown
* Automatically detects special Aimed Shot ammo and uses the correct follow-up ability (Multi-Shot, Arcane Shot, or Serpent Sting)
* Uses Steady Shot as filler
* Weaves Arcane Shot and Multi-Shot based on timing windows
* Prevents Auto Shot clipping
* Supports Rapid Fire through macro
* Automatic Feign Death when aggro is confirmed (requires SuperWoW)
* Two modes:

  * Normal Mode (with Multi-Shot)
  * Single Target Mode (no Multi-Shot)

## Requirements

* Turtle WoW
* SuperWoW

## Installation

Place the addon folder in:

TurtleWoW/Interface/Addons

Alternatively, install using the launcher via `.git` link if supported.

## Setup

Make sure the following abilities exist on your action bar:

* Aimed Shot
* Auto Shot
* Steady Shot
* Arcane Shot
* Multi-Shot
* Feign Death

The addon scans your action bar to find these abilities.

## Macro Usage

Create a macro and use one of the following:

### Normal Mode

```
#showtooltip Aimed Shot
/cast Rapid Fire
/run local c,f=CastSpellByName,function(k)for i=1,16 do local t=UnitDebuff("player",i)if t and strfind(strlower(t),k)then return 1 end end end if f("searing")then c("Multi-Shot")elseif f("black")then c("Arcane Shot")elseif f("poison")then c("Serpent Sting")end
/run OBH:Run(true)
```

Optional:

```
/petattack
```

### Single Target Mode

```
#showtooltip Aimed Shot
/cast Rapid Fire
/run local c,f=CastSpellByName,function(k)for i=1,16 do local t=UnitDebuff("player",i)if t and strfind(strlower(t),k)then return 1 end end end if f("black")then c("Arcane Shot")elseif f("poison")then c("Serpent Sting")end
/run OBH:Run(false)
```

## Notes

* Designed specifically for Turtle WoW
* Requires SuperWoW for automatic Feign Death functionality
* Depends on action bar scanning to locate abilities

## Load Message

On login or reload:

```
OBH V4.4 (Chat Spam Protection) Loaded.
```
