Scriptname SeverActions_OutfitAlias extends ReferenceAlias

{
    Per-follower outfit persistence via ReferenceAlias events.

    Attached to alias slots on the SeverActions quest. When a follower is
    recruited, they're ForceRefTo'd into an empty slot. The alias then
    receives native OnLoad/OnCellLoad/OnEnable events directly on the NPC,
    firing the instant their 3D loads — the earliest possible moment to
    re-equip the locked outfit.

    OnObjectUnequipped blocks the engine's "equip best armor" behavior by
    immediately re-equipping the locked outfit whenever armor is removed.

    Uses the same StorageUtil keys as the Outfit system:
    - SeverOutfit_LockActive (Int, 1 = locked)
    - SeverOutfit_Locked_<formID> (FormList of locked items)
}

SeverActions_Outfit Property OutfitScript Auto
{Optional: direct reference to the Outfit script. Falls back to GetFormFromFile.}

; =============================================================================
; EVENTS - Trigger re-equip on NPC load/cell/enable
; =============================================================================

Event OnLoad()
    {Fires when the NPC's 3D model loads into the scene.}
    ReequipIfLocked()
EndEvent

Event OnCellLoad()
    {Fires when the NPC's cell is loaded.}
    ReequipIfLocked()
EndEvent

Event OnEnable()
    {Fires when the NPC is enabled (e.g. after being disabled).}
    ReequipIfLocked()
EndEvent

Event OnObjectUnequipped(Form akBaseObject, ObjectReference akReference)
    {Fires when the NPC unequips any item. If the outfit is locked and
     armor was unequipped (engine swapping to "best"), immediately re-equip
     the locked outfit to override the engine's choice.}
    If akBaseObject as Armor
        Actor follower = self.GetActorRef()
        If follower && StorageUtil.GetIntValue(follower, "SeverOutfit_LockActive", 0) == 1
            ReequipIfLocked()
        EndIf
    EndIf
EndEvent

; =============================================================================
; RE-EQUIP LOGIC
; =============================================================================

Function ReequipIfLocked()
    {Check if the outfit lock is active and re-equip if so.}
    Actor follower = self.GetActorRef()
    If !follower || follower.IsDead()
        Return
    EndIf

    If StorageUtil.GetIntValue(follower, "SeverOutfit_LockActive", 0) != 1
        Return
    EndIf

    SeverActions_Outfit outfitSys = GetOutfitScript()
    If outfitSys
        outfitSys.ReapplyLockedOutfit(follower)
    EndIf
EndFunction

; =============================================================================
; HELPER
; =============================================================================

SeverActions_Outfit Function GetOutfitScript()
    If OutfitScript
        Return OutfitScript
    EndIf
    Return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Outfit
EndFunction
