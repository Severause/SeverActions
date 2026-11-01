# Employment public API (v1)

For **mods that write about NPCs** (a bio generator, a dialogue pack): what an NPC does for a living under SeverActions.
Such a job is usually invisible in the game's data, because a retainer the player hired or an NPC-to-NPC job carries no
Job keyword or vendor faction.

## The decorator

`sever_employment(actorUUID)` is a SkyrimNet decorator. It is frozen: a field is never renamed or given a new meaning, and
a later capability is a new field. It returns an empty string for an NPC with no job, and for a retainer who deserted,
turned hostile or is held in slavery. Otherwise it returns JSON, which a prompt reads by field:

```
{% set job = sever_employment(actorUUID) %}
{% if job != "" %}- Works as {{ job.role }}{% if job.place != "" %} at {{ job.place }}{% endif %}
{% endif %}
```

| Field | When | Meaning |
|---|---|---|
| `kind` | always | `retainer` (the player hired them through Enterprises) or `labor` (they work for another NPC). |
| `role` | always | The trade or title, as the player gave it. Plain English for a built-in trade; `worker` when a custom job has no title. |
| `place` | always | Where they work: a place, a hold, or an empty string. |
| `forPlayer` | always | `true` for a retainer. The player's name is never included, so a text meant to stand apart from the player can leave this relationship out. |
| `employer` | `labor` | The NPC they work for. |
| `protects` | a retainer on guard duty | The person they guard. `place` is empty then. |
| `stewardOf` | a retainer who is a hold steward | The hold. |

Wages, mood, stock and other week-to-week state are left out on purpose, so the facts stay true in a text that is kept. A
job can still change later: a stored text does not follow it.

## Checking that it is there

A prompt that calls a decorator nobody registered prints raw template text. Decorators load with the DLL, so a mod that also
runs without SeverActions has to check first: from an SKSE plugin call SkyrimNet's `PublicHasDecorator("sever_employment")`
and pass the answer to your prompt as a variable, then put the lines above behind it. Check when you build the prompt, not
at kDataLoaded, when SeverActions may not have registered yet. On a SeverActions older than this API the check answers false.

The decorator runs on SkyrimNet's render workers and is safe there. It answers an empty string while the Enterprises module
is not installed.
