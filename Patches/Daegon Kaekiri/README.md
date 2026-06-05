# Daegon Kaekiri — SeverActions Compatibility Patch

## What this fixes

Daegon Kaekiri ships with a **custom outfit enforcement system** (three Papyrus
scripts) that forcibly re-equips her default outfit every time the game loads
and blocks any attempt to remove/unequip outfit pieces. Without this patch,
SeverActions' outfit lock / undress / dress / preset actions silently fail
for Daegon — her default clothes always come back on save load.

## Root cause

Three re-equip enforcement hooks in the base mod:

| Script | Hook | Behavior |
|--------|------|----------|
| `k101PlayerAliasLoaderScript::Initialize()` | `OnPlayerLoadGame` + `OnInit` | Calls `EquipCustomOutfit()` on every load — this is what re-applies default clothes |
| `k101DaegonQuestAliasScript::OnItemRemoved` | When a piece is removed | Adds it back to Daegon and re-equips with `preventRemoval=True` + shows a notification |
| `k101DaegonQuestAliasScript::OnObjectUnequipped` | When a piece is unequipped | Re-equips immediately with `preventRemoval=True` |

The `preventRemoval=True` flag on the re-equip calls is what silently defeats
SeverActions' `UnequipItem` calls — the engine holds the lock.

## Fix

Both scripts now call a helper `IsSeverActionsFollower()` that resolves the
`SeverActions_FollowerFaction` (FormID `0x000EB708` in `SeverActions.esp`) at
runtime via `Game.GetFormFromFile(...)`:

- **If SeverActions isn't installed** — the lookup returns `None` and the
  original Daegon behavior runs unchanged.
- **If Daegon is not a SeverActions follower** — same as above. Standalone
  Daegon keeps her custom outfit system.
- **If Daegon is a tracked SeverActions follower** — the three enforcement
  hooks back off and let SeverActions manage her outfit.

No new master is required. The patch is pure script override — no ESP.

## Files shipped

- `Scripts/k101PlayerAliasLoaderScript.pex`
- `Scripts/k101DaegonQuestAliasScript.pex`

Source in `Source/Scripts/`. Only the two scripts above are modified — the
other `.psc` files in that folder are decompiled dependencies included to
satisfy the compiler.

## Installation

1. Drop `Scripts/` into your Daegon Kaekiri mod folder (or a new MO2 mod
   that loads **after** Daegon Kaekiri).
2. Load order doesn't matter — this is a Papyrus script override, resolved
   by file priority, not plugin load order.

## Uninstall

Delete the two `.pex` files. The originals from the base Daegon mod take over
again on next load.

## Verifying it's active (in-game)

After installing, with Daegon recruited as a SeverActions follower:

1. Open SeverActions Outfit Actions → Undress — should strip all armor.
2. Save, reload — Daegon should stay undressed instead of reverting to the
   default outfit.
3. No "This item is a part of Dae's custom outfit..." notifications should
   appear when SeverActions manipulates her equipment.
