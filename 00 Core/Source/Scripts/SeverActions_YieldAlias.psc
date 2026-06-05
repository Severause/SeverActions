Scriptname SeverActions_YieldAlias extends ReferenceAlias

{
    Per-yielded-NPC persistence anchor via ReferenceAlias.

    When a generic hostile NPC (bandit, necromancer, etc.) surrenders via the
    Yield action, they're ForceRefTo'd into an empty YieldSlot. The alias
    makes them persistent — the engine won't recycle or despawn them when
    the player crosses cells.

    Phase 7 (Option B): the old OnLoad re-apply (re-zero Aggression + re-add
    SeverSurrenderedFaction on every 3D-load) moved to native YieldMonitor,
    which sinks TESObjectLoadedEvent and covers ALL tracked actors via the
    cosave-backed entry map. This script keeps only the OnDeath slot-cleanup
    + monitor-unregister so the slot can be reused by another yielded NPC.

    CK Setup is unchanged:
    - 5 ReferenceAlias slots on the SeverActions quest (YieldSlot00-04)
    - Optional, Allow Reuse, Initially Cleared
    - This script attached to each
}

Event OnDeath(Actor akKiller)
    {When the yielded NPC dies, free the alias slot and clean up tracking.
     The 3D-load re-apply that used to be in OnLoad now lives in native
     YieldMonitor::ProcessEvent(TESObjectLoadedEvent).}
    Actor npc = self.GetActorRef()
    If npc
        StorageUtil.FormListRemove(None, "SeverCombat_YieldedGenericActors", npc)
        SeverActionsNative.UnregisterYieldedActor(npc)
        Debug.Trace("[SeverActions] YieldAlias: " + npc.GetDisplayName() + " died, clearing yield slot")
    EndIf
    self.Clear()
EndEvent
