# Duel public API (v1)

SeverActions protects the player's companions: its friendly-fire guard stops a companion fighting the player or
another companion, and the follower frameworks (NFF, Serana's, custom-AI followers, the vanilla follower quest) keep a
companion from fighting the player at all. This API lets **another mod** run a sanctioned fight between two actors,
the player and a companion, two companions, or any two NPCs (two allies too, such as two guards of one hold), without
dismissing anyone: for the length of the duel SeverActions leaves the pair alone, frees a companion to fight, keeps
the player's other followers out of it, and puts everything back afterwards. A companion stays on SeverActions'
roster the whole time.

Your mod decides the fight itself: weapons, when someone has yielded, and when the duel is over. SeverActions makes
the fight possible, keeps an NPC fighter from being killed (see below), and cleans up after it.

## The functions

All four are `Global Native` on `SeverActionsNativeExt2`. They are frozen: the signatures never change and the
functions are never removed. A later capability is a new function and a higher `Duel_ApiVersion()`.

| Function | Does |
|---|---|
| `Int Duel_ApiVersion()` | `1`. `0` when duels are unavailable in this install (a modular install without SeverActions' combat module). On a SeverActions older than the API the call fails and returns `0`. |
| `Int Duel_Begin(Actor akA, Actor akB, Float afMaxSeconds)` | Starts a duel between the two and returns its handle, a number above `0`. `0` when refused (see below). `afMaxSeconds` is the longest the duel may last; there is no upper limit, but it must be a positive number. |
| `Bool Duel_End(Int aiHandle)` | Ends the duel and puts everything back. `False` when the handle names no duel in progress (it has already ended). |
| `Bool Duel_IsActive(Actor akActor)` | `True` while the actor is in a duel. |

`Duel_Begin` refuses (returns `0`) when:

- either actor is None, or both are the same actor;
- `afMaxSeconds` is `0`, negative, or not a number;
- either is dead, or an NPC fighter is not loaded or is disabled;
- either is already in a duel, or in a SeverActions brawl;
- either is in SeverActions custody (arrested, jailed, questioned by a guard), is an arrest guard on duty, or is a
  captive or a captor holding one;
- either is in a SexLab or OStim scene;
- `Duel_ApiVersion()` is `0`.

The reason is written to `SeverActionsNative.log` (`DuelManager: Duel_Begin refused ...`).

## The events

Both are ordinary SKSE ModEvents: register with `RegisterForModEvent(name, "YourCallback")` and declare the callback
as `Event YourCallback(String eventName, String strArg, Float numArg, Form sender)`.

| Event | `numArg` | `strArg` | `sender` | When |
|---|---|---|---|---|
| `SeverActions_DuelStarted` | the handle | `""` | the first fighter (`akA`) | SeverActions has freed the companion and started the fight. |
| `SeverActions_DuelEnded` | the handle | why it ended | the first fighter (`akA`); the second if `akA` no longer exists | Every end, whatever caused it. |

`SeverActions_DuelEnded` is the one event every duel sends. `SeverActions_DuelStarted` is not: a duel that ends
while the companion is still being freed never starts. Go by the handle (`numArg as Int`), never by the sender.

`SeverActions_DuelEnded`'s `strArg` is one of these words, which never change:

| `strArg` | The duel ended because |
|---|---|
| `ended` | your mod called `Duel_End`. |
| `expired` | `afMaxSeconds` of play ran out. |
| `load` | a save made during the duel was loaded: SeverActions ends every duel such a save carries. |
| `death` | a fighter died, whoever landed the blow. |
| `calledoff` | something outside the duel interfered (see below), or the fighters were parted. |

The handle is exact up to 16,777,216 duels in one playthrough; compare `numArg as Int` with the handle you got.

## What SeverActions does during a duel

When `Duel_Begin` succeeds:

1. The friendly-fire guard, the outlaw truce and the follower monitors leave the pair alone. Neither fighter is
   dismissed or untracked, no "turned on you" relationship note is written, and a SeverActions AI action cannot turn
   either fighter on the other or hand them to another fight.
2. The fight is one of SeverActions' brawls with weapons allowed, and none of the brawl's own rules end it (a
   weapon hit, a fighter going down, sheathing, walking off). As in a brawl, both fighters join the vanilla brawl
   faction (`DGIntimidateFaction`, Skyrim.esm `0x04CFA6`) unless they are in it already, and an NPC fighter gets
   Aggression 1, Confidence 3 and, unless already essential, a temporary essential flag. That keeps guards and
   bystanders out, makes the blows no crime, and turns a blow from the other fighter that would kill into a fall to
   bleedout. Everything is put back at the end, and only what SeverActions changed.
   Everyone keeps their own weapons, spells and combat style: the fight is armed from the first blow.
3. The player's other followers nearby are pacified, as they are for brawls, and pulled out of the fight if they join
   it anyway. Until the two are fighting, SeverActions asks the game to start the fight once a second, for up to ten
   seconds; a fight between two NPCs usually starts within a second or two.
4. Each companion is freed to fight: SeverActions clears their teammate flag, releases an NFF follower from NFF (the
   silent release NFF's own sparring uses) and takes a vanilla follower out of the vanilla follower slot silently, so
   the vanilla script does not dismiss them for attacking the player.
5. SeverActions starts the fight (an NFF follower takes about two seconds to be released) and sends
   `SeverActions_DuelStarted`.

A follower Simple Follower Framework manages is not taken out of its follower slot: SFF replaces the vanilla follower
quest, and SeverActions does not release its seats. Against the player, SFF's own scripts may dismiss them.

A duel is **called off** (`calledoff`) when:

- anyone outside the pair lands a real hit on a fighter: a bystander, an enemy, a follower who joined in;
- the player, while dueling, lands a real hit on anyone outside the pair;
- an NPC fighter is out of the loaded area for 10 seconds, or no longer exists.

A fighter's summons count as that fighter. Hits that cannot hurt (detection probes some mods fire) never call a duel
off. An NPC fighter's stray hit on a bystander does not call it off by itself, but the bystander hitting back does.

When the duel ends, for any reason, SeverActions stops the two fighting each other (a fight either has with someone
else goes on), releases the pacified followers, clears what the player's blows left on a companion (the assault mark,
the friendly-hit count), and gives each companion back their teammate flag; a vanilla follower is put back in the
vanilla follower slot (unless another follower has taken it meanwhile). Then `SeverActions_DuelEnded` is sent, so
your handler may start another duel with the same companion. NFF, Serana's and custom-AI followers are re-seated in
their framework about 1.5 seconds after the event. On a load the event is sent as the loaded game starts, and the
companion is given back by SeverActions' own load pass.

## Recipe

**1. Keep every call in one small bridge script, and check for SeverActions before calling it.** Where SeverActions
is not installed, a script that names `SeverActionsNativeExt2` cannot load, and on the stock Papyrus VM every
function in it is dead, its own guards included. So the bridge holds only the calls, the presence check lives
somewhere else (your own script, which names no SeverActions type), and your scripts check before each call into the
bridge. Reach the bridge only by static calls (`JDoe_SADuelBridge.Begin(...)`), never through a variable, property,
parameter or return of its type: those would make the calling script fail to load too.

```papyrus
Scriptname JDoe_SADuelBridge Hidden
{Every SeverActions call of this mod. Callers check JDoe_Duel.SeverActionsPresent() first.}

Int Function Begin(Actor akA, Actor akB, Float afMaxSeconds) Global
    If SeverActionsNativeExt2.Duel_ApiVersion() < 1
        Return 0   ; too old (the call logs one error and returns 0), or no combat module
    EndIf
    Return SeverActionsNativeExt2.Duel_Begin(akA, akB, afMaxSeconds)
EndFunction

Bool Function End(Int aiHandle) Global
    Return SeverActionsNativeExt2.Duel_End(aiHandle)
EndFunction
```

```papyrus
; in your own script (it names no SeverActions type, so it loads with or without SeverActions)
Bool Function SeverActionsPresent() Global
    ; GetPluginVersion is -1 when SeverActionsNative.dll is not loaded.
    Return SKSE.GetPluginVersion("SeverActionsNative") > 0 && Game.GetModByName("SeverActions.esp") != 255
EndFunction
```

Compile against SeverActions' `SeverActionsNativeExt2.psc`, and do not ship its `.pex`.

**2. Start the duel, then wait for `SeverActions_DuelStarted`.**

```papyrus
Int property DuelHandle = 0 auto hidden

Function StartDuel(Actor akCompanion)
    If !JDoe_Duel.SeverActionsPresent()
        Return   ; your own duel without SeverActions
    EndIf
    RegisterForModEvent("SeverActions_DuelStarted", "OnSADuelStarted")
    RegisterForModEvent("SeverActions_DuelEnded", "OnSADuelEnded")
    DuelHandle = JDoe_SADuelBridge.Begin(Game.GetPlayer(), akCompanion, 300.0)
    If DuelHandle == 0
        ; refused: see SeverActionsNative.log for why
    EndIf
EndFunction

Event OnSADuelStarted(String eventName, String strArg, Float numArg, Form sender)
    If (numArg as Int) == DuelHandle
        ; the fight is on: start watching for the yield
    EndIf
EndEvent
```

Do not start combat between the two yourself before `SeverActions_DuelStarted`: until then a companion's framework
still holds them, and a vanilla follower who targets the player that early is dismissed by the vanilla follower
script. After it you may call `StartCombat` as you like.

**3. End the duel yourself when it is decided** (someone yielded, your countdown ran out). Leaving it to
`afMaxSeconds` works, but the companion stays freed until then.

```papyrus
Function OnYield()
    If DuelHandle > 0
        JDoe_SADuelBridge.End(DuelHandle)
    EndIf
EndFunction

Event OnSADuelEnded(String eventName, String strArg, Float numArg, Form sender)
    If (numArg as Int) != DuelHandle
        Return   ; another mod's duel
    EndIf
    DuelHandle = 0
    ; strArg: ended / expired / load / death / calledoff
EndEvent
```

**4. Pass a real `afMaxSeconds`.** It is the safety net that ends a duel your mod lost track of. It counts only while
the game is not paused (menus that pause the game stop it).

## Rules and caveats

- **An NPC fighter cannot be killed during the duel; the player can.** The brawl faction and the temporary essential
  flag drop a beaten NPC into bleedout instead. The player is never made essential: protect them in your own mod. A
  death (the player's, or an NPC killed despite it, by a script or another mod) ends the duel with `death`.
- **SeverActions gets a beaten NPC back up, as after a brawl.** When the duel ends, an NPC fighter stays down a few
  seconds, then regains health until they stand, and their temporary essential flag comes off once they are up. If
  your mod heals the loser itself, that is fine too.
- **A load always ends a duel**, with `load`, and SeverActions stops the fight between the two that the save carried.
  The event is sent as the loaded game starts; your own state from that save may still say the duel is on, so clear
  it there.
- **One duel per actor.** `Duel_Begin` refuses an actor already dueling. End the old duel first.
- **The handle is only good for its duel.** Handles keep counting up across loads, so a handle you kept from before a
  load never names a later duel; `Duel_End` on an ended duel returns `False` and does nothing.
- **Followers outside the pair are pacified only if they are nearby when the duel starts.** One who arrives later is
  still kept out by the friendly-fire guard, but a hit from them calls the duel off.
- Any two actors may duel, not only companions; with no companion involved there is just nothing to free or put back.
- Each call waits for the game's next frame (about 17 ms), like most natives.
