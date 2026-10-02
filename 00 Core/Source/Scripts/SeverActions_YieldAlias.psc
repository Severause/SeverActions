Scriptname SeverActions_YieldAlias extends ReferenceAlias

{
    Persistence anchor for a generic hostile NPC who surrendered via the Yield action: the
    YieldSlot alias keeps them from being recycled across cells. The native YieldMonitor
    re-applies the pacification (Aggression 0, SeverSurrenderedFaction) on every 3D load; this
    script only frees the slot on death.
    Attached to each YieldSlot alias (00-04: Optional, Allow Reuse, Initially Cleared).
}

Event OnDeath(Actor akKiller)
    {Free the slot and drop the actor from the yield tracking list and the native monitor.}
    Actor npc = self.GetActorRef()
    If npc
        StorageUtil.FormListRemove(None, "SeverCombat_YieldedGenericActors", npc)
        SeverActionsNative.UnregisterYieldedActor(npc)
        Debug.Trace("[SeverActions] YieldAlias: " + npc.GetDisplayName() + " died, clearing yield slot")
    EndIf
    self.Clear()
EndEvent
