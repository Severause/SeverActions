Scriptname SeverActions_YieldAlias extends ReferenceAlias

{
    Per-yielded-NPC persistence via ReferenceAlias.

    When a generic hostile NPC (bandit, necromancer, etc.) surrenders via the
    Yield action, they're ForceRefTo'd into an empty YieldSlot. The alias
    makes them persistent — the engine won't recycle or despawn them when
    the player crosses cells.

    OnLoad re-applies the surrender state every time the NPC's 3D loads.
    This is critical because generic (leveled) NPCs can have their actor
    values reset from their template during cell transitions, save/load,
    or fast travel — Aggression would reset from 0 back to 1-2, causing
    them to attack nearby NPCs.

    OnDeath cleans up the slot so it can be reused by another yielded NPC.

    CK Setup:
    - Create 5 ReferenceAlias slots on the SeverActions quest (YieldSlot00-04)
    - Set each as: Optional, Allow Reuse, Initially Cleared
    - Attach this script to each alias
    - Fill SeverSurrenderedFaction property on each alias
    - Fill the YieldSlots array property on SeverActions_Combat
}

Faction Property SeverSurrenderedFaction Auto
{The surrendered faction — fill in CK. Same faction as on SeverActions_Combat.}

Event OnLoad()
    {Fires every time the NPC's 3D loads — cell transitions, save/load, fast travel.
     Re-applies surrender state to prevent generic NPCs from going hostile again.}
    Actor npc = self.GetActorRef()
    If !npc || npc.IsDead()
        Return
    EndIf

    ; Re-zero aggression — generic NPCs can have their actor values
    ; reset by their leveled template when 3D loads in a new cell
    npc.SetActorValue("Aggression", 0)

    ; Ensure still in surrendered faction (template can re-apply base factions)
    If SeverSurrenderedFaction && !npc.IsInFaction(SeverSurrenderedFaction)
        npc.AddToFaction(SeverSurrenderedFaction)
        npc.SetFactionRank(SeverSurrenderedFaction, 0)
    EndIf

    ; Stop any combat that started during the load before we could re-zero
    npc.StopCombat()
    npc.EvaluatePackage()

    ; Re-register with C++ yield monitor (runtime-only map, doesn't survive save/load)
    Float origAggro = StorageUtil.GetFloatValue(npc, "SeverCombat_OriginalAggression", 1.0)
    SeverActionsNative.RegisterYieldedActor(npc, origAggro, SeverSurrenderedFaction)

    Debug.Trace("[SeverActions] YieldAlias: " + npc.GetDisplayName() + " loaded, re-applied surrender state (Aggression=0)")
EndEvent

Event OnDeath(Actor akKiller)
    {Fires when the yielded NPC dies. Clean up tracking data and free the alias slot.}
    Actor npc = self.GetActorRef()
    If npc
        ; Remove from global tracking list (survives save/load)
        StorageUtil.FormListRemove(None, "SeverCombat_YieldedGenericActors", npc)

        ; Unregister from native yield hit monitor
        SeverActionsNative.UnregisterYieldedActor(npc)

        Debug.Trace("[SeverActions] YieldAlias: " + npc.GetDisplayName() + " died, clearing yield slot")
    EndIf

    ; Free the alias slot for reuse
    self.Clear()
EndEvent
