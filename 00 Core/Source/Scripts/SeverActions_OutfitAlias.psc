Scriptname SeverActions_OutfitAlias extends ReferenceAlias

{
    Per-follower outfit persistence via ReferenceAlias events.

    Attached to alias slots on the SeverActions quest. When a follower is
    recruited, they're ForceRefTo'd into an empty slot. The alias then
    receives native OnLoad/OnCellLoad/OnEnable events directly on the NPC,
    firing the instant their 3D loads — the earliest possible moment to
    re-equip the locked outfit.

    OnObjectUnequipped uses a DEBOUNCE approach: instead of re-equipping
    instantly (which fights mods that strip actors), it records the unequip
    in C++ and starts a 0.5s timer. If more unequips arrive during the window,
    the timer resets. When the timer fires (no new unequips for 0.5s), we check
    if the actor is in an animation scene or was bulk-stripped. Only then do
    we re-equip if appropriate.
}

SeverActions_Outfit Property OutfitScript Auto
{Optional: direct reference to the Outfit script. Falls back to GetFormFromFile.}

Float Property ReequipDebounceSeconds = 0.5 Auto
{Delay before re-equipping after an unequip event. Allows burst detection to work.}


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
    {Fires when the NPC unequips any item. Instead of re-equipping immediately
     (which fights external mod strips), we debounce: record the unequip in C++
     for burst detection, bump a generation counter, and start a short timer.
     When the timer fires and no new unequips arrived, THEN we decide whether
     to re-equip or yield.}
    If akBaseObject as Armor
        Actor follower = self.GetActorRef()
        If follower && StorageUtil.GetIntValue(follower, "SeverOutfit_LockActive", 0) == 1
            ; Don't fight our own outfit changes
            If StorageUtil.GetIntValue(follower, "SeverOutfit_Suspended", 0) == 1
                Return
            EndIf
            If SeverActionsNative.Native_Outfit_IsNativeSuspended(follower)
                Return
            EndIf

            ; Record unequip for burst detection (C++ timestamps it)
            SeverActionsNative.Native_Outfit_RecordExternalUnequip(follower)

            ; Start/reset debounce timer — if more unequips arrive before it fires,
            ; RegisterForSingleUpdate resets the countdown automatically.
            RegisterForSingleUpdate(ReequipDebounceSeconds)
        EndIf
    EndIf
EndEvent

Event OnUpdate()
    {Debounce timer fired — no new unequips for 0.5s. Now decide: re-equip or yield.}
    Actor follower = self.GetActorRef()
    If !follower || follower.IsDead()
        Return
    EndIf

    If StorageUtil.GetIntValue(follower, "SeverOutfit_LockActive", 0) != 1
        Return
    EndIf

    ; Skip if our outfit system is mid-operation
    If StorageUtil.GetIntValue(follower, "SeverOutfit_Suspended", 0) == 1
        Return
    EndIf

    ; Check global animation scene flag (set by SexLab/OStim ModEvent hooks in Outfit script)
    SeverActions_Outfit outfitCheck = GetOutfitScript()
    If outfitCheck && outfitCheck.AnimationSceneActive
        Debug.Trace("[SeverActions_OutfitAlias] Animation scene active — yielding for " + follower.GetDisplayName())
        Return
    EndIf

    ; Check if burst-suppressed (3+ rapid unequips detected by C++)
    If SeverActionsNative.Native_Outfit_IsBurstSuppressed(follower)
        Debug.Trace("[SeverActions_OutfitAlias] Burst suppression active — yielding for " + follower.GetDisplayName())
        Return
    EndIf

    ; Not in a scene, not burst-stripped — re-equip the locked outfit
    SeverActions_Outfit outfitSys = GetOutfitScript()
    If outfitSys
        outfitSys.ReapplyLockedOutfit(follower)
    EndIf
EndEvent

; =============================================================================
; RE-EQUIP LOGIC (for cell load / OnLoad — immediate, no debounce)
; =============================================================================

Function ReequipIfLocked()
    {Direct re-equip for cell transitions — no debounce needed here since
     cell loads aren't caused by external mods stripping actors.}
    Actor follower = self.GetActorRef()
    If !follower || follower.IsDead()
        Return
    EndIf

    If StorageUtil.GetIntValue(follower, "SeverOutfit_LockActive", 0) != 1
        Return
    EndIf

    ; Clear burst suppression — cell change means external mod scene is over
    SeverActionsNative.Native_Outfit_ClearBurstSuppression(follower)

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

