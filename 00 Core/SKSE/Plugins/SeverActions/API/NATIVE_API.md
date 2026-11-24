# SeverActions native API (v4)

For **SKSE plugins** that need to cooperate with SeverActions from C++: leave alone the NPCs SeverActions is holding,
read an NPC's intimacy stance, report the outcome of an intimate scene, send background SkyrimNet prompts under
SeverActions' Background AI switch, show the same picture of a character that SeverActions' pages show, report a
crime someone saw to SeverActions' bounty ledger, ask for a companion's bond to be reassessed after something
happened in front of them, and show which retainers are waiting on the player. Papyrus mods use the Papyrus APIs instead (see `BIO_BLOCKS_API.md` and `DUEL_API.md`).
happened in front of them, and send an NPC on an errand across the map (to a hold's guards, say). Papyrus mods use the Papyrus APIs instead (see `BIO_BLOCKS_API.md` and `DUEL_API.md`).
happened in front of them, and hold an NPC your plugin drives so SeverActions leaves their AI alone. Papyrus mods use
the Papyrus APIs instead (see `BIO_BLOCKS_API.md` and `DUEL_API.md`); a Papyrus mod holds an NPC with two ModEvents
(Holding an NPC, below).

## Getting the functions

Copy `SeverActionsAPI.h` (in the SeverActions source, `Native/src/SeverActionsAPI.h`) into your plugin unchanged. It
declares each function's name and type; resolve them after `kDataLoaded`:

```cpp
#include "SeverActionsAPI.h"

HMODULE sa = GetModuleHandleW(L"SeverActionsNative.dll");
auto getVersion = sa ? reinterpret_cast<SeverActionsAPI::GetVersionFn>(
                           GetProcAddress(sa, SeverActionsAPI::kGetVersion)) : nullptr;
if (getVersion && getVersion() >= 1) {
    auto busy = reinterpret_cast<SeverActionsAPI::GetBusyReasonsFn>(
        GetProcAddress(sa, SeverActionsAPI::kGetBusyReasons));
    // ...
}
```

A function missing from the DLL means an older SeverActions: skip the feature. The functions are frozen: a
signature never changes and a function is never removed. A later capability is a new function and a higher version.

## The functions

| Function | Thread | Does |
|---|---|---|
| `SAAPI_GetVersion()` | any | `4` (`3` before the retainer attention functions, the errands and the hold, `2` before the crime report and the bond request, `1` before the portrait functions). |
| `SAAPI_GetBusyReasons(formId)` | game | The bits of what holds the actor (below). `0` = nothing SeverActions holds. |
| `SAAPI_IsKnownChild(formId)` | any | `1` when SeverActions knows the actor is a child (`0` while it does not know yet). |
| `SAAPI_IntimacyEnabled()` | any | `1` while the player has SeverActions' intimacy features on. |
| `SAAPI_GetIntimacyStance(formId, reasonOut, cap)` | any | The actor's stance toward the player (below) and the one-line reason they give for it. |
| `SAAPI_NoteSceneEnded(formId, kind)` | game | An intimate scene **with the player** ended for the actor: `0` they were willing, `1` the player forced them (their stance turns Withdrawn at once), `2` they forced themself on the player. `0` and `2` ask SeverActions to reassess. Never call it for a scene the player was not in: the stance is toward the player. |
| `SAAPI_BackgroundAIEnabled()` | any | `1` while SeverActions' Background AI switch is on. |
| `SAAPI_SendBackgroundPrompt(prompt, variant, json, cb, user)` | any | Sends a SkyrimNet custom prompt through SeverActions: refused (`0`, `cb` never runs) while Background AI is off. After a `1`, `cb` runs exactly once, on a SkyrimNet worker thread or SeverActions' timeout thread: `success` `1` with the reply, `0` no usable reply, `-1` the player loaded a save first, `-2` no reply within 30 minutes (SkyrimNet cancelled it, or a late reply is ignored); the text is empty for `-1` and `-2`. Free `user` only in `cb`, or after a `0` return. |
| `SAAPI_GetUiTheme(out, cap)` / `SAAPI_GetUiLanguage(out, cap)` | any | The colour theme id and the UI language code SeverActions' pages use, so another plugin's pages can match. Theme ids: ledger, tallow, windhelm, dwemer, soulcairn, vellum, contrast (High Contrast); more may be added, so treat an unknown id as your default. |
| `SAAPI_GetPortraitPath(formId, out, cap, kindOut)` | any | Version 2. The full path of the picture SeverActions' pages show for the actor (below). |
| `SAAPI_GetPortraitStamp(formId)` | any | Version 2. A number that changes whenever that picture does; `0` for none. |
| `SAAPI_ReportCrime(offender, at, gold, crime, holdOut, cap)` | game | Version 3. A crime that was seen: adds `gold` to the offender's bounty in the hold where `at` stands (below). Returns the gold added, `0` when nothing was charged. |
| `SAAPI_RequestBondAssessment(formId, what)` | game | Version 3. Something happened in front of a companion: `what` is weighed in their bond with the player (below). `1` asked now, `2` kept for their next assessment, `0` no companion. |
| `SAAPI_GetRetainerAttention(formId)` | any | Version 4. The bits of what about the actor's work for the player waits on the player (below). `0` = nothing. |
| `SAAPI_ListRetainerAttention(out, cap)` | any | Version 4. Everyone whose attention bits are not `0`: their FormIDs into `out` (at most `cap`), and how many there are. |
| `SAAPI_GetHoldSeat(at, holdOut, cap)` | game | Version 4. Where the guards of the hold whose law covers the place of `at` are found (below): a reference's FormID, `0` for none. |
| `SAAPI_BeginErrand(actor, dest, speed)` | game | Version 4. Sends an NPC on a journey to a reference, walked on off screen (below). The journey's handle, `0` when refused. |
| `SAAPI_CancelErrand(handle)` | game | Version 4. Ends an errand before they get there. |
| `SAAPI_ErrandLive(handle, actor)` | any | Version 4. `1` while that errand is under way for that actor. |
| `SAAPI_SetErrandListener(listener)` | any | Version 4. Installs the function that hears how each errand ended (`nullptr` removes it; the last call wins). |
| `SAAPI_HoldActor(formId, owner, reason)` | any | Version 4. Your plugin drives the NPC: SeverActions leaves their AI alone until you release them (below). `1` held, `0` refused. |
| `SAAPI_ReleaseActor(formId, owner)` | any | Version 4. Ends your hold: `1` when you held them, `0` otherwise. |
| `SAAPI_GetActorHoldCount(formId)` | any | Version 4. How many plugins hold the NPC, `0` for none. |
| `SAAPI_SetIntimacyHistoryProvider(provider)` | any | Installs your account of an NPC's intimate history with the player (`nullptr` removes it; the last call wins). SeverActions calls `provider(formId, out, cap)` on the game thread whenever it assesses that NPC's intimacy stance and gives the text to the assessment; return its length, `0` for nothing. Return quickly and never call back into SeverActions from it. |

### Busy reasons

| Bit | Meaning |
|---|---|
| `1` follower led | An NPC SeverActions leads with its follow package, companion or casual follower. |
| `2` waiting | Parked by SeverActions: told to wait, or relaxing in a safe interior. |
| `4` traveling | On a SeverActions journey, or waiting at its end. |
| `8` custody | A suspect, prisoner or jailed NPC of a SeverActions arrest. |
| `16` captive | A captive: bound, marched or tied. |
| `32` captor | Took a captive, or leads one on a leash. |
| `64` guard on task | An arrest or dispatch guard. |
| `128` brawl | In a SeverActions brawl. |
| `256` schedule hold | Held at home, work or relax by SeverActions' schedule. |
| `512` child | A child. Never a participant in or the target of adult content. |
| `1024` companion | On SeverActions' roster, whichever framework leads them. Informational. |

A plugin that moves NPCs (a package override, a walk, a scene) should leave any actor with bits other than
`companion` set, or ask the player first.

### Intimacy stances

`0` none (never assessed), `1` unwilling, `2` uncertain, `3` receptive, `4` willing, `5` withdrawn. Withdrawn is
sticky: only repair over time, or the player's own edit, lifts it.

### Crimes

`SAAPI_ReportCrime` puts a charge in SeverActions' own bounty ledger, the one its guards, jarls and prompts read
(what the offender is wanted for, the hold's wanted list, an arrest). It is not the game's own crime gold.

- `offender` is an actor reference; `0x14` is the player. An NPC gets a bounty of their own in that hold.
- `at` is any reference standing where it happened: the offender, the victim or the witness. The hold is the one whose
  law covers that place. Where no hold does (the wilds beyond any hold, a place another mod never assigned), nothing
  is charged.
- `gold` is 1 to 5000 (`kMaxCrimeGold`) for one charge.
- `crime` labels the charge: `assault`, `theft`, `murder`, `trespass`, `pickpocket`, `contempt`, `abuse_of_power`, or
  a short label of your own (lower-cased, cut to 64 bytes). Null, empty or a label with nothing left once cleaned
  reads as `assault`. Guards read the label back as written ("wanted for ..."), so use a plain word for the crime.
- `holdOut` receives the hold's name (may be null).
- It returns `0`, with an empty name, when nothing was charged: no hold there, an offender that does not resolve or
  is dead, gold out of range, or an install without SeverActions' arrest module.
- You decide who saw it, and you charge once for one crime: SeverActions adds whatever it is given. It shows the player
  its usual bounty notice when the charge is on them or on one of their people.
- It records no SkyrimNet event. The charge is in the ledger at once, so guards and the offender know of it through
  SeverActions' prompts; register an event of your own if the people nearby should hear how it came about.

### Bonds

`SAAPI_RequestBondAssessment(formId, what)` (version 3, game thread): something happened in front of a companion that
their bond with the player (rapport, trust, loyalty and mood) should weigh.

- `what` says it in a sentence or two, as plain fact ("Lydia saw ..."). At most 400 bytes are kept for one companion;
  null or empty adds nothing.
- **This text is how the assessment learns of it.** The assessment reads only the dialogue between the two and the
  companion's diary, so an event you register with SkyrimNet never reaches it. The text is shown as something new
  they saw, and the model decides what it changes, if anything. It stays until an assessment that was shown it has
  its reply applied, so a failed model call does not use it up.
- It returns `1` (`kBondAsked`) when an assessment was asked for now, the one the Companions page's refresh runs.
- It returns `2` (`kBondKept`) when none was asked for: an assessment is already under way, for this companion or
  another; another request was made in the last ten seconds; or the player turned Track Relationships off. The text
  is kept and weighed at this companion's next assessment. Call again later with no text if it should not wait.
- **Ask for one companion at a time.** An assessment asked for takes the place of whichever is in flight, so several
  companions who saw the same thing are asked for in turn, each once the one before has come back.
- It returns `0` (`kBondNotACompanion`), keeping nothing, when the actor is not a living companion on SeverActions'
  roster or the install has no companions module.
- SeverActions' Background AI switch still decides whether an assessment runs. Each one is a model call, so do not
  ask for one companion more often than something new has happened. What is kept does not survive a load, and the
  player's Start over on the Companions page drops it.

### Errands

An errand is a SeverActions journey you start for an NPC: SeverActions walks them there with its own travel packages,
and while they are off screen it moves them on at their pace, so they arrive when they would have. It shows the player
no map marker and no quest objective.

- `SAAPI_GetHoldSeat(at, holdOut, cap)` answers where to send someone who has to find a hold's guards: the hold is the
  one whose law covers the place `at` stands. For seven of the nine holds of the base game it is the location marker
  of the hold's city (Whiterun, Windhelm, Riften, Markarth, Dawnstar, Morthal, Winterhold); for Haafingar and
  Falkreath, whose cities carry none, and for any other hold, it is the spot where its jail lets prisoners out, else
  its jail. `holdOut` receives the hold's name. `0` where
  no hold answers or it has none of these.
- `SAAPI_BeginErrand(actor, dest, speed)` starts it: `speed` `0` walk, `1` jog, `2` run. It returns the journey's
  handle, `0` when refused: the player, the player's teammate, a child, the dead, anyone SeverActions holds (any busy
  reason but the schedule hold, which steps aside for a journey), a destination that does not resolve, no traveller's
  place free (SeverActions keeps 24, shared with its own journeys), or an install without SeverActions' travel core.
- While it is under way the NPC reads as busy (`kBusyTraveling`), and SeverActions' other systems leave them alone.
  Another journey given to them (by the player or the model) ends yours.
- `SAAPI_SetErrandListener(listener)`: `listener(handle, actor, end)` runs once for each errand, on the game thread,
  when it ends: `1` arrived (loaded, they stand within reach of the destination; off screen, once the walk had them
  there; one stuck for good is placed there and arrives too), `2` failed (they died or are gone), `3` cancelled (`SAAPI_CancelErrand`, or another
  journey given to them). Ignore a handle you do not know: a start SeverActions refused after it began, for want of a
  traveller's place, ends as cancelled. Return quickly and never call SeverActions' errand functions from it.
- Errands are saved with the game: one under way at a save goes on after a load, and its end reaches the listener
  installed then. An end that came just before a load is never reported after it. Keep the handle and the actor in your own save, and after a load check each with
  `SAAPI_ErrandLive(handle, actor)`: a `0` means it is gone (a save made by an older SeverActions, say), and nothing
  will be heard of it.
- Arrival is where it stands, not what they do there: anything after, such as walking up to one guard, is your next
  errand or your own code.
### Holding an NPC

`SAAPI_HoldActor(formId, owner, reason)` (version 4, any thread) is for a plugin that moves an NPC with packages of its
own, its own overrides or SkyrimNet's package API (a wedding sending its guests to their marks). Without it
SeverActions keeps doing its own upkeep on the NPCs it looks after, and some of that outranks or resets your packages.
While at least one owner holds the NPC:

- SeverActions never resets their AI and never re-asserts their home (its stuck-NPC check skips them).
- Its home, work and relax schedule steps aside, as it does for a SexLab or OStim scene.
- Every sandbox override SeverActions holds on them comes off, a waiting companion's wait among them, and an
  override SeverActions would add (a wait ordered meanwhile) is not added.
- A companion keeps SeverActions' follow seat, a quest alias at priority 95, which any package override outranks
  (SkyrimNet's package API is one). If you hold through quest aliases of your own, give your quest a priority above
  95.
- Its follower upkeep skips them: no re-assert of the follow package, no adoption or release of a wait, no teleport
  to catch up with the player, no safe-interior relax, no sitting down with the player.

Nothing SeverActions recorded changes. When the last owner releases the NPC, the overrides go back about 1.5 s
later, so a companion who was waiting is waiting again, and the schedule and the upkeep take them back on their next
pass. A wait the player orders meanwhile is recorded and takes hold at the release; a follow seats the follow alias
at once (see above). SeverActions' own jobs
still run on a held NPC (a journey, an arrest, a kidnap), with packages that can outrank yours: leave such an NPC
alone (`SAAPI_GetBusyReasons`), or ask the player.

- `owner` names your plugin (at most 64 bytes, compared without case). Each plugin's hold is its own: releasing ends
  only yours, and the NPC stays held while another plugin holds them. Null or empty is refused.
- `reason` says what you are doing with them (at most 160 bytes; may be null). Holding again replaces it. The owner
  (in lower case) and the reason are shown to the player on the Companions page's AI view, and in SeverActions' log:
  write them for the player to read.
- `0` (`kHoldRefused`) for an `owner` that is empty, a FormID that is not an NPC reference in memory, the player, an
  NPC 8 plugins hold already, or when 1024 NPCs are held for all plugins together.
- A hold is kept in the save. It ends when you release it or the NPC dies; a hold on an NPC whose plugin left the
  load order, or on an NPC created during play who is gone, is dropped at the next load. Release every hold you
  placed once your scene ends.

A Papyrus mod sends the same as a ModEvent from the NPC (so the NPC is the event's sender), with no compile-time
dependency on SeverActions:

```papyrus
akNpc.SendModEvent("SeverActions_HoldActor", "MyMod|walking to the altar")   ; strArg = owner|reason
akNpc.SendModEvent("SeverActions_ReleaseActor", "MyMod")                    ; strArg = owner (an owner|reason also works)
```

An older SeverActions ignores both events.

### Portraits

`formId` is the actor's reference FormID, `0x14` for the player. `SAAPI_GetPortraitPath` returns the length of the
UTF-8 path, `0` when SeverActions shows no picture of them. When the length is `cap` or more, `out` is left empty:
call again with a buffer one byte longer than the length. `kindOut` (may be null) says which picture it is:

| Kind | Picture |
|---|---|
| `1` picked | One the player picked: a 512 px square JPEG, already cut to the player's framing. |
| `2` cutout | One SeverActions took: a PNG of the character from the chest up on a transparent ground, 4:5 (384 x 480 when new; an older one can be smaller, so read the size from the PNG). The file is the whole figure; SeverActions' pages frame it as they draw it. |

- The player and characters created during play have no picture until a save is loaded: theirs are kept per
  playthrough.
- Open the file, read it and close it. Never write, move or delete anything in SeverActions' folder. SeverActions
  replaces a picture by renaming a new file over it, which fails while another program holds the old one open, so do
  not keep it open (or open it with `FILE_SHARE_DELETE`).
- A picture can go away or move: the player clears it, SeverActions drops old pictures it took of characters
  outside the party, or it gives a file a new name. A path that will not open: ask for it again; a length of `0` means
  there is none.
- `SAAPI_GetPortraitStamp` is a number that changes when the picture is replaced, when a picked picture replaces a
  taken one and when it is cleared: read the file again then. Compare it only with a stamp you had before; it is not a
  date.
- Both functions read the last listing SeverActions made of its folder and never read the disk themselves: a listing
  more than 2 seconds old, or one made before SeverActions stored a picture, is made again on SeverActions' own
  thread, so an answer can lag a change by a moment. They are cheap enough to call for every card. Neither asks
  SeverActions to take a picture.
- The file's name is SeverActions' own business and may change: always ask for the path.

### Retainers waiting on the player

`SAAPI_GetRetainerAttention(formId)` (version 4, any thread) answers, for an actor reference, what about their work
for the player waits on the player. A party frame or a HUD can put a letter or a coin icon on a retainer's card with
it.

| Bit | Meaning |
|---|---|
| `1` letter | Sent the player a letter about a private matter they want to raise in person. |
| `2` payout | Has gold or goods waiting for the player to collect. |
| `4` raise ask | Asked for better pay or terms and awaits an answer. |
| `8` loan ask | Asked the player for a loan and awaits an answer. |
| `16` hearing | Expects the player to come and hear them out. |
| `32` arrears | Is owed wages the player has not paid. |
| `64` notice | Has given notice: quits at the next weekly settlement unless things change. |
| `128` jailed | Is in jail. |
| `256` applicant | Not working for the player: sent a letter asking for work. |
| `512` defiance | Pays the player tribute and now withholds it until the player comes to collect in person. |

- `0` for an actor who neither works for the player nor sent one of these letters, for a retainer who quit or turned
  on the player, and when the player's install has no Enterprises module.
- A letter counts from when it is sent, so the bit can show while the courier is still on the way. It lasts ten game
  days: a private matter ends sooner once the player has been to see its sender and left again, a request for work
  once the player hires them. The other bits last until the player deals with the matter on the Enterprises page or
  in conversation.
- More bits may come later: test the ones you show, never the whole value against a number.
- `SAAPI_ListRetainerAttention(out, cap)` gives everyone with a bit set, retainers and applicants, in no particular
  order. It returns how many there are, which can be more than `cap`: call with `out` null and `cap` 0 to size the
  buffer. A party frame usually wants it for a "someone needs you" badge, since most retainers are not in the party.
- Both read SeverActions' own records under their locks and touch no game state, so they are cheap enough to call
  every frame, from any thread.
