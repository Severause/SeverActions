# SeverActions native API (v1)

For **SKSE plugins** that need to cooperate with SeverActions from C++: leave alone the NPCs SeverActions is holding,
read an NPC's intimacy stance, report the outcome of an intimate scene, and send background SkyrimNet prompts under
SeverActions' Background AI switch. Papyrus mods use the Papyrus APIs instead (see `BIO_BLOCKS_API.md` and `DUEL_API.md`).

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
| `SAAPI_GetVersion()` | any | `1`. |
| `SAAPI_GetBusyReasons(formId)` | game | The bits of what holds the actor (below). `0` = nothing SeverActions holds. |
| `SAAPI_IsKnownChild(formId)` | any | `1` when SeverActions knows the actor is a child (`0` while it does not know yet). |
| `SAAPI_IntimacyEnabled()` | any | `1` while the player has SeverActions' intimacy features on. |
| `SAAPI_GetIntimacyStance(formId, reasonOut, cap)` | any | The actor's stance toward the player (below) and the one-line reason they give for it. |
| `SAAPI_NoteSceneEnded(formId, kind)` | game | An intimate scene **with the player** ended for the actor: `0` they were willing, `1` the player forced them (their stance turns Withdrawn at once), `2` they forced themself on the player. `0` and `2` ask SeverActions to reassess. Never call it for a scene the player was not in: the stance is toward the player. |
| `SAAPI_BackgroundAIEnabled()` | any | `1` while SeverActions' Background AI switch is on. |
| `SAAPI_SendBackgroundPrompt(prompt, variant, json, cb, user)` | any | Sends a SkyrimNet custom prompt through SeverActions: refused (`0`, `cb` never runs) while Background AI is off. After a `1`, `cb` runs exactly once, on a SkyrimNet worker thread or SeverActions' timeout thread: `success` `1` with the reply, `0` no usable reply, `-1` the player loaded a save first, `-2` no reply within 30 minutes (SkyrimNet cancelled it, or a late reply is ignored); the text is empty for `-1` and `-2`. Free `user` only in `cb`, or after a `0` return. |
| `SAAPI_GetUiTheme(out, cap)` / `SAAPI_GetUiLanguage(out, cap)` | any | The colour theme id and the UI language code SeverActions' pages use, so another plugin's pages can match. |
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
