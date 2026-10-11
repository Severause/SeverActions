# Bio Blocks public API (v4)

SeverActions' Bio Blocks are bio snippets the player keeps in a library and applies to NPCs; each NPC's blocks render
into their SkyrimNet character bio. This API lets **another mod** add its own blocks to that library and apply them
to NPCs from its own scripts, and (v4) list and apply the blocks SeverActions ships and other mods provide.

**Do you need it?** A mod that only wants fixed bio text for its OWN NPCs needs nothing from SeverActions: ship a
`character_bio` submodule in your own SkyrimNet external layer (`SKSE/Plugins/SkyrimNet/external/<author>.<mod>/`).
Use this API when the player should see and manage your blocks in SeverActions' Bio Blocks page, or when your quest
logic decides who gets which block.

## The functions

All eleven are `Global Native` on `SeverActionsNativeExt2`. They are frozen: the signatures never change and the
functions are never removed. A later capability is a new function and a higher `BioApi_Version()`: check it before
calling a function a later version added (`BioApi_ListApplied` needs `2`, the tab functions `3`, `BioApi_ListBlocks`
and `BioApi_GetContent` `4`).

| Function | Does |
|---|---|
| `Int BioApi_Version()` | `4` (`1` had the first six functions, `2` added `BioApi_ListApplied` and the change event, `3` the tab functions). On a SeverActions older than the API the call fails and returns `0`. |
| `Bool BioApi_Define(String asKey, String asTitle, String asContent, String asTab)` | Creates the block, or updates its title and content. `asTab` is used only when the block is created (`""` = the first tab); after that the player decides where it lives. `False` when refused - a malformed or reserved key, an empty title, a `{` in the title or content (see below) - or when the player deleted this block. |
| `Bool BioApi_Exists(String asKey)` | `True` while the block is in the library. |
| `Bool BioApi_Apply(Actor akActor, String asKey)` | Applies the block to the NPC. Already applied counts as `True`; a key not defined (or deleted by the player) is `False`. In a one-block tab (v3) it replaces the NPC's other blocks of that tab, and applying one they already hold keeps it and removes the others. |
| `Bool BioApi_Unapply(Actor akActor, String asKey)` | Removes it from the NPC. `False` when the key is unknown or the block was not applied to them. |
| `Bool BioApi_IsApplied(Actor akActor, String asKey)` | `True` when it is applied to the NPC. A faction rule the player set up does not count. |
| `String[] BioApi_ListApplied(Actor akActor)` | v2. Every block the NPC's bio shows, the player's own included, one record each (see "What an NPC carries"). |
| `Bool BioApi_SetTabExclusive(String asTab, Bool abExclusive)` | v3. Marks a tab one-block, or unmarks it (see "One block per NPC"). `False` when the tab does not exist, or when the player set it by hand. |
| `Bool BioApi_IsTabExclusive(String asTab)` | v3. `True` when the tab is one-block. |
| `String[] BioApi_ListBlocks(Bool abIncludeIntimate)` | v4. Every block a mod can apply, one record each (see "Listing blocks"). `False` leaves out the intimate ones. |
| `String BioApi_GetContent(String asKey)` | v4. The block's text as the bio shows it under its title, `""` when the key names no block. |

## Keys

A block is named by a **key** you choose: `<author>.<mod>:<local>`, for example `jdoe.grumpyguards:grumpy`.

- `author` and `mod`: 1 to 32 characters of `a-z 0-9 _ -`.
- `local`: 1 to 64 characters of `a-z 0-9 _ - .` (dots let you group: `jdoe.grumpyguards:guards.captain`).
- Upper-case letters are folded to lower case; anything else outside the grammar is refused, never repaired.
- `severause.severactions:*` is SeverActions' own: `Define` refuses it, but you can apply SeverActions' shipped blocks
  by it (see "Listing blocks").

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

## What an NPC carries (v2)

`BioApi_ListApplied(akNpc)` returns one record per block the NPC's bio shows, in that order: the ones applied to the
NPC, then the ones a faction rule grants (from a one-block tab, only the one shown: see "One block per NPC"). Blocks of
an intimate tab are listed even while the bio leaves them out (see "Intimacy tabs"). A record is four fields separated
by a TAB:

1. `direct` (applied to this NPC, by the player or a mod) or `faction` (a faction rule the player set up grants it to
   every member; matched against the NPC's factions when you call, so a living NPC answers the same loaded or
   unloaded, and the answer follows them joining or leaving the faction. A dead NPC loses their faction grants only
   while their body is loaded: Skyrim's death flag cannot be trusted on an unloaded NPC).
2. The tab.
3. The title.
4. The key, or nothing for the player's own block. Since v4 SeverActions' shipped blocks carry keys too
   (`severause.severactions:*`, see "Listing blocks"), so a key alone does not mean another mod provides the block.

```papyrus
String[] records = SeverActionsNativeExt2.BioApi_ListApplied(akNpc)
Int i = 0
While i < records.Length
    String[] f = StringUtil.Split(records[i], "\t")
    ; f[0] direct or faction, f[1] the tab, f[2] the title; no f[3] = the player's own block
    i += 1
EndWhile
```

- `StringUtil.Split` drops an empty field, which is why the key comes last. No field contains a TAB: one in a title or
  a tab name comes back as a space. The words and the field order are frozen like the functions.
- Compare keys, not titles, to find your own blocks: your title is stored as `Title (2)` when the player already has a
  block with it (see "Rules and caveats").
- Each call waits for the game's next frame (about 17 ms in play, longer while a save loads), so a sweep over many NPCs
  at load takes a moment. That is fine in a script that is not holding anything up.

## Listing blocks (v4)

`BioApi_ListBlocks(abIncludeIntimate)` returns one record per block that has a key, in library order: the blocks other
mods provide and the ones SeverActions ships. The player's own blocks have no key, so they are not listed and no mod
can apply them. A record is four fields separated by a TAB, read like a `BioApi_ListApplied` record:

1. `intimate` or `general`: `intimate` when the block's tab name contains one of the intimate words (see "Intimacy
   tabs" below). It follows the tab, so a block the player moves to another tab changes kind.
2. The tab.
3. The title.
4. The key, to pass to `BioApi_Apply`, `BioApi_IsApplied`, `BioApi_GetContent` and the rest.

`BioApi_ListBlocks(False)` leaves out every `intimate` record.

```papyrus
If SeverActionsNativeExt2.BioApi_Version() >= 4
    String[] records = SeverActionsNativeExt2.BioApi_ListBlocks(False)
    Int i = 0
    While i < records.Length
        String[] f = StringUtil.Split(records[i], "\t")
        ; f[0] general here, f[1] the tab, f[2] the title, f[3] the key
        String text = SeverActionsNativeExt2.BioApi_GetContent(f[3])
        i += 1
    EndWhile
EndIf
```

**SeverActions' shipped blocks** carry keys of the form `severause.severactions:<tab>.<trait>`, for example
`severause.severactions:cognitive.uneducated` or `severause.severactions:adventuring.scout`. The keys never change,
but the blocks are the player's: they may have edited the text or the title, moved them to another tab, or deleted
them, so list them rather than assuming a key exists, and read the text with `BioApi_GetContent` if your mod decides
by it. A shipped block the player had renamed before v4 takes its key only while its text is still a shipped wording
(it keeps the player's title); one whose text they also edited has no key and is not listed. A shipped block the player
deletes is not hidden and restorable like another mod's: it stays out of later updates of its pack until the player
adds that pack again.

The shipped blocks come in two starter packs, which the player adds or removes on the Bio Blocks page: **General**
(cognitive level, adventuring behaviour, religion, dislikes, phobias, vices and addictions; every library has it
until the player removes it) and **Adult** (the intimate tabs Sexual Behavior, Sexual Kinks and Sexual Dislikes;
every library has it too, out of sight on the page until the player opens the Adult heading). The player can remove
either, so never assume a shipped block exists:
`BioApi_ListBlocks(True)` lists what this player has.

## Hearing changes (v2)

SeverActions sends the ModEvent `SeverActions_BioBlockChanged` when a block is applied to or removed from an NPC, when
the player deletes a block, and when the player changes a faction rule. `strArg` is six fields separated by a TAB:

1. What happened: `applied`, `removed`, `deleted` (the block left the library, and with it every NPC that carried it:
   one event, not one per NPC) or `rules` (the player granted or revoked the block for a faction, or removed a rule
   that granted it).
2. Who did it: `player` (the Bio Blocks page or the MCM) or `api` (a `BioApi_*` call, yours or another mod's).
3. The NPC's FormID as a signed number; `0` for `deleted` and `rules`. Read it with SKSE's `Game.GetFormEx`: the
   vanilla `Game.GetForm` returns `None` for the negative ones (NPCs from light plugins, spawned NPCs, and plugins
   late in the load order).
4. The tab.
5. The title.
6. The key, or nothing for the player's own block (a shipped block has SeverActions' key since v4).

The event's sender is the NPC. It is `None` for `deleted` and `rules`, and for an NPC not in memory (the player can
remove a block from someone far away on the Bio Blocks page). Field 3 still names them then: compare it with the
FormIDs you keep. The NPC itself cannot be fetched until they are loaded again.

The words and the field order are frozen like the functions.

```papyrus
; in your own quest or alias script, on every game load and at first start
RegisterForModEvent("SeverActions_BioBlockChanged", "OnBioBlockChanged")

Event OnBioBlockChanged(String asEventName, String asArgs, Float afNumArg, Form akSender)
    String[] f = StringUtil.Split(asArgs, "\t")
    If f.Length < 5
        Return
    EndIf
    ; f[0] what happened, f[1] player or api, f[2] the FormID, f[3] the tab, f[4] the title, f[5] the key if any
    Actor npc = akSender as Actor
    If !npc && f[2] != "0"
        npc = Game.GetFormEx(f[2] as Int) as Actor   ; still None when the NPC is not in memory
    EndIf
EndEvent
```

Registering needs nothing from SeverActions, so this script can stay out of your bridge; calls back into the API from
the handler go through the bridge as usual.

- **It reports changes, not state.** It fires only when something changed (an `Apply` of a block already applied sends
  nothing, unless a one-block tab takes the NPC's other blocks off), after the change, and asynchronously: when your handler runs, read the state again (`BioApi_IsApplied` or
  `BioApi_ListApplied`) before acting on it.
- **Nothing fires for what a load does:** loading a save, a faction rule matching an NPC as they come into view, or a
  save naming a block the library no longer has. Read the state with `BioApi_ListApplied` when your mod loads, and use
  the event for changes during play.
- **Faction grants move without an event.** A `faction` record follows the NPC's membership: nothing fires when they
  join or leave the faction, or die. Call `BioApi_ListApplied` when you need the answer rather than keeping it. A
  `rules` event names the block, not the faction or any NPC: re-read `BioApi_ListApplied` for the NPCs you track
  (`BioApi_IsApplied` never counts a faction grant).
- **Never answer an `api` change with another `BioApi_*` call.** The event does not say which mod made a call: every
  mod's call reads `api`, and the key names the block's provider, not the caller. React to `player` changes, and
  make your reactions settle (apply only what is missing, remove only what is there), or two mods reacting to each
  other can trade blocks back and forth forever.
- **A replacement sends one event per block:** applying a block in a one-block tab sends `removed` for each block it
  takes off, then `applied`; applying one the NPC already holds sends only the `removed` events. Granting a block of
  such a tab to a faction sends a `rules` event for each block the rule lost, then one for the block granted.
- **Marking a tab sends nothing.** Neither `BioApi_SetTabExclusive` nor the player's switch in Manage Tabs fires the
  event: what the bios show changes, but nothing is applied or removed. Read `BioApi_IsTabExclusive` when it matters.

## One block per NPC (v3)

A tab can be one-block: an NPC's bio shows at most one block of it, and applying one replaces the other, like radio
buttons. Use it for a tab whose blocks
contradict each other (a set of attitudes, of which a character holds one).

```papyrus
; in your bridge, on every load, after the Define that creates the tab
If SeverActionsNativeExt2.BioApi_Version() >= 3
    SeverActionsNativeExt2.BioApi_SetTabExclusive("Relationships: Attachment", True)
EndIf
```

- **Applying replaces.** `BioApi_Apply`, the Bio Blocks page and the MCM take the NPC's other blocks of that tab off
  as they apply the new one. Applying a block the NPC already holds keeps it and takes the others off. The change
  event reports each one.
- **A faction rule grants one too.** When the player grants a block of the tab to a faction, the rule's other blocks
  of that tab come off it. A rule made before the tab was marked can still grant two until the player grants one of
  them again; the bio shows one.
- **The bio shows one, whatever is stored.** An NPC can still hold two blocks of the tab from before it was marked, from
  an import, or from a block moved between tabs; nothing is deleted. The bio, the intimacy section and
  `BioApi_ListApplied` show one: the newest one applied to the NPC, or, with none applied, the first a faction rule
  grants. `BioApi_IsApplied` still answers for each block.
- **The player's choice stands.** The player switches a tab in Manage Tabs on the Bio Blocks page. After that,
  `BioApi_SetTabExclusive` on that tab returns `False` and changes nothing, so calling it on every load is safe.
- **Mark only your own tab, and name it after your mod.** Tabs are shared by name, so a plain name like `Attachment`
  could be a tab the player made for something else; `Relationships: Attachment` cannot. The tab must exist (a
  `Define` with it creates it) and is matched in any case; a name is cut to 40 bytes, as `Define` cuts it. If the
  player renames it, your next `Define` puts new blocks in a new tab of the old name; re-check with
  `BioApi_IsTabExclusive` if it matters.
- **Unmarking changes no NPC:** everything they hold shows again.
- **Where it lives:** the library file, per install, like the tabs. A library export carries the one-block tabs; an
  import keeps them unless the player already decided that tab, and an imported mark is not the player's choice, so
  `BioApi_SetTabExclusive` can still change it. An older SeverActions ignores the setting and drops it the next time
  it saves the library.

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
- **Caps:** the title is cut to 80 bytes, the content to 2000 and a tab name to 40 (UTF-8 safe). Every block costs prompt tokens
  on every line the NPC speaks: keep blocks short and apply few per NPC.
- **Titles are unique** across the library. If the player already has a block with your title and different text,
  yours shows as `Title (2)`. A block of the player's with your exact title and text becomes yours (the case of a
  library an older SeverActions rewrote without keys).
- **Strings pass through Skyrim's string pool**, which ignores case: a title may come back re-cased if something else
  used the same words first. A key you pass in is folded anyway; any string handed back (a title, a tab, a key) may
  come back re-cased, which Papyrus `==` ignores.
- **When it shows:** on the NPC's next bio render. SkyrimNet may cache a render for about a minute.
- **Intimacy tabs:** a tab counts as intimate when its name contains any of these, in any case and anywhere in the
  name: `sexual`, `kink`, `erotic`, `intimac`, `nsfw`, `lewd`, `romanc`, `sensual`, `fetish`, `bdsm`, `lover`,
  `courtesan`, `escort`, `prostitut`, `whore`, `harlot`, `brothel`, `paramour`. While SeverActions' intimacy setting
  (the Intimacy & Consent Section, on by default) is on, every block in such a tab also feeds the NPC's
  intimate-persona section; while it is off, and always for a child, the bio leaves such blocks out.
  `BioApi_ListBlocks` marks them `intimate` and `BioApi_ListApplied` lists them whatever the setting. Watch for accidental
  matches ("Necromancers", "Caravan Escorts", "Clover"): give your tab a neutral name unless the content is intimate.
- **Where things live:** the library, with your blocks and the player's deletions, is per install
  (`My Games/.../SKSE/SeverActions_BioBlocks.json`); who carries which block is per save. A block's identity comes
  from its key, so if the player resets the library file, your next `Define` brings the block back and the NPCs that
  carried it in their saves carry it again. A block the player deleted and restored comes back unapplied in the
  running game, while a save made before the deletion keeps what it had: check `BioApi_IsApplied` rather than
  assuming either way.
- **Every install mode:** Bio Blocks belong to SeverActions' kernel, so the API works in Legacy and Modular installs
  alike.
