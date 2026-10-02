# Bio Blocks public API (v1)

SeverActions' Bio Blocks are bio snippets the player keeps in a library and applies to NPCs; each NPC's blocks render
into their SkyrimNet character bio. This API lets **another mod** add its own blocks to that library and apply them
to NPCs from its own scripts.

**Do you need it?** A mod that only wants fixed bio text for its OWN NPCs needs nothing from SeverActions: ship a
`character_bio` submodule in your own SkyrimNet external layer (`SKSE/Plugins/SkyrimNet/external/<author>.<mod>/`).
Use this API when the player should see and manage your blocks in SeverActions' Bio Blocks page, or when your quest
logic decides who gets which block.

## The functions

All six are `Global Native` on `SeverActionsNativeExt2`. They are frozen: the signatures never change and the
functions are never removed. A later capability is a new function and a higher `BioApi_Version()`.

| Function | Does |
|---|---|
| `Int BioApi_Version()` | `1`. On a SeverActions older than the API the call fails and returns `0`. |
| `Bool BioApi_Define(String asKey, String asTitle, String asContent, String asTab)` | Creates the block, or updates its title and content. `asTab` is used only when the block is created (`""` = the first tab); after that the player decides where it lives. `False` when refused - a malformed or reserved key, an empty title, a `{` in the title or content (see below) - or when the player deleted this block. |
| `Bool BioApi_Exists(String asKey)` | `True` while the block is in the library. |
| `Bool BioApi_Apply(Actor akActor, String asKey)` | Applies the block to the NPC. Already applied counts as `True`; a key not defined (or deleted by the player) is `False`. |
| `Bool BioApi_Unapply(Actor akActor, String asKey)` | Removes it from the NPC. `False` when the key is unknown or the block was not applied to them. |
| `Bool BioApi_IsApplied(Actor akActor, String asKey)` | `True` when it is applied to the NPC. A faction rule the player set up does not count. |

## Keys

A block is named by a **key** you choose: `<author>.<mod>:<local>`, for example `jdoe.grumpyguards:grumpy`.

- `author` and `mod`: 1 to 32 characters of `a-z 0-9 _ -`.
- `local`: 1 to 64 characters of `a-z 0-9 _ - .` (dots let you group: `jdoe.grumpyguards:guards.captain`).
- Upper-case letters are folded to lower case; anything else outside the grammar is refused, never repaired.
- `severause.severactions:*` is SeverActions' own and is refused.

Nothing checks that a key's provider is really you: use your own `author.mod`, and never another mod's.

## Recipe

**1. Keep every call in one small bridge script, and check for SeverActions before calling it.** Where SeverActions
is not installed, a script that names `SeverActionsNativeExt2` cannot load, and on the stock Papyrus VM every
function in it is dead, its own guards included. So the bridge holds only the calls, and your other scripts check
for SeverActions before each call into it. Reach the bridge only by static calls (`JDoe_SABioBridge.DefineBlocks()`),
never through a variable, property, parameter or return of its type: those would make the calling script fail to
load too.

```papyrus
Scriptname JDoe_SABioBridge Hidden
{Every SeverActions call of this mod. Callers check Game.GetModByName("SeverActions.esp") != 255 first.}

Function DefineBlocks() Global
    If SeverActionsNativeExt2.BioApi_Version() < 1
        Return   ; a SeverActions older than the API (the call logs one error and returns 0)
    EndIf
    SeverActionsNativeExt2.BioApi_Define("jdoe.grumpyguards:grumpy", "Grumpy Guard", \
        "Has worked the gate for twenty years and resents every traveller.", "Guards")
EndFunction

Function MarkGrumpy(Actor akGuard) Global
    SeverActionsNativeExt2.BioApi_Apply(akGuard, "jdoe.grumpyguards:grumpy")
EndFunction
```

```papyrus
; in your own quest or alias script
If Game.GetModByName("SeverActions.esp") != 255
    JDoe_SABioBridge.DefineBlocks()
EndIf
```

Compile against SeverActions' `SeverActionsNativeExt2.psc`, and do not ship its `.pex`.

**2. Define on every game load.** Call it (behind the check) from your player alias's `OnPlayerLoadGame` and once
at first start. A call that changes nothing writes nothing, so this is free. Defining every time is also how an updated
text in a new version of your mod reaches the player.

**3. Apply once, on your own event** (a quest stage, a dialogue choice), never on every load. The player can remove
a block from an NPC, and re-applying on each load would undo that forever. For "every member of a group", tell the
player to use a faction rule on the Bio Blocks page.

## What the player can do

- A block you provide shows a badge with your provider (`jdoe.grumpyguards`). Its title and text are read-only in
  the page, because the next `Define` would overwrite an edit; the player can move it to another tab, or duplicate it
  as their own block to change the words.
- **Deleting it hides it.** It leaves every NPC it was applied to, and `Define` returns `False` and brings nothing
  back. The player can restore it from the page's Hidden list; it returns unapplied in the running game (a save made
  before the deletion still has it on the NPCs that carried it then). Your mod cannot override this.

## Rules and caveats

- **No `{` in the title or content.** SkyrimNet tries to read any bio section containing `{` as JSON and logs a
  warning on every render when it cannot, so `Define` refuses it.
- **Text is UTF-8.** Save your scripts as UTF-8: any other byte (an ANSI em dash or accented letter) is stored as `�`.
- **Caps:** the title is cut to 80 bytes and the content to 2000 bytes (UTF-8 safe). Every block costs prompt tokens
  on every line the NPC speaks: keep blocks short and apply few per NPC.
- **Titles are unique** across the library. If the player already has a block with your title and different text,
  yours shows as `Title (2)`. A block of the player's with your exact title and text becomes yours (the case of a
  library an older SeverActions rewrote without keys).
- **Strings pass through Skyrim's string pool**, which ignores case: a title may come back re-cased if something else
  used the same words first. Keys are unaffected (they are folded anyway).
- **When it shows:** on the NPC's next bio render. SkyrimNet may cache a render for about a minute.
- **Intimacy tabs:** a tab counts as intimate when its name contains any of these, in any case and anywhere in the
  name: `sexual`, `kink`, `erotic`, `intimac`, `nsfw`, `lewd`, `romanc`, `sensual`, `fetish`, `bdsm`, `lover`,
  `courtesan`, `escort`, `prostitut`, `whore`, `harlot`, `brothel`, `paramour`. While SeverActions' intimacy setting is
  on (the default), every block in such a tab also feeds the NPC's intimate-persona section. Watch for accidental
  matches ("Necromancers", "Caravan Escorts", "Clover"): give your tab a neutral name unless the content is intimate.
- **Where things live:** the library, with your blocks and the player's deletions, is per install
  (`My Games/.../SKSE/SeverActions_BioBlocks.json`); who carries which block is per save. A block's identity comes
  from its key, so if the player resets the library file, your next `Define` brings the block back and the NPCs that
  carried it in their saves carry it again. A block the player deleted and restored comes back unapplied in the
  running game, while a save made before the deletion keeps what it had: check `BioApi_IsApplied` rather than
  assuming either way.
- **Every install mode:** Bio Blocks belong to SeverActions' kernel, so the API works in Legacy and Modular installs
  alike.
