# SeverActions native API (v2)

For **SKSE plugins** that need to cooperate with SeverActions from C++: leave alone the NPCs SeverActions is holding,
read an NPC's intimacy stance, report the outcome of an intimate scene, send background SkyrimNet prompts under
SeverActions' Background AI switch, and show the same picture of a character that SeverActions' pages show. Papyrus mods use the Papyrus APIs instead (see `BIO_BLOCKS_API.md` and `DUEL_API.md`).

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
| `SAAPI_GetVersion()` | any | `2` (`1` before the portrait functions). |
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
