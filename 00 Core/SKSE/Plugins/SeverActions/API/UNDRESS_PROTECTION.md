# Undress protection list files (v1)

For **mods whose items must stay on** (a collar, a piercing, a body or hair add-on, a cursed item): SeverActions'
undress and outfit actions never take off an item a list file protects, on any NPC, in any save. A player's own list is
behind the Blacklist button on the Outfits page; a list file adds to it and does not need the player to do anything.
Devious Devices items are already protected without a list.

## Where

Put an `.ini` file in `Data/SKSE/Plugins/SeverActions/UndressProtection/`, named after your mod so it does not collide
with another's (`MyCollarMod.ini`). Every `.ini` in that folder is read once when the game starts; a change takes effect
after a restart.

## Format

One entry a line, `Key = value`. The keys are `Plugin`, `Item` and `Keyword`, in any case.

```ini
; My Collar Mod: these never come off during undress.
[UndressProtection]

; Every item the plugin defines.
Plugin = My Collar Mod.esp

; One item: the plugin, a bar, and the FormID without its load-order byte.
Item = My Collar Mod.esp|0x000801
; SPID's order works too.
Item = 0x000802~My Collar Mod.esp

; Any item whose record carries the keyword: an EditorID, or Plugin|FormID.
Keyword = SexLabNoStrip
Keyword = My Collar Mod.esp|0x000810, My Collar Mod.esp|0x000811
```

- `;` starts a comment anywhere on a line, `#` at the start of one. Blank lines and `[Section]` lines are skipped.
- An `Item` or `Keyword` line may list several values separated by commas. A `Plugin` line names one plugin.
- A FormID is hexadecimal, with or without `0x`, and never includes the load-order byte: write `0x000801`, not
  `0x2A000801`. For an `.esl`, write the FormID as the plugin defines it.
- A keyword named by EditorID is found without an EditorID plugin such as powerofthree's Tweaks: keywords keep their
  EditorIDs.
- An entry for a plugin that is not in the load order is kept but does nothing. A value that cannot be read is skipped
  (the other values on its line still count) and written to `SeverActionsNative.log` with its line number.

The player sees every list file's entries behind the Blacklist button on the Outfits page, on its From files tab, and
cannot remove them there.

## What protection means

A protected item is never unequipped, stored or taken back by an undress or outfit change, and its body slots are kept
from the pieces of an outfit SeverActions puts on.

With Keyword Item Distributor (KID) a list can protect items another mod adds: give them a keyword of your own with KID,
and list that keyword.
