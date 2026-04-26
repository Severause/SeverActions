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
    {Fires when the NPC unequips any item. Debounces: record the unequip in C++
     for burst detection, bump a generation counter, start a short timer. When
     the timer fires and no new unequips arrived, THEN OnUpdate decides whether
     to re-equip or yield.

     Slot-preset path: with the wardrobe pattern (DirectEquip + SetOutfit blank),
     the engine does NOT self-enforce — we MUST run the debounce and reapply via
     DirectEquipPreset. Without this, an external mod strip or an engine
     auto-equip swap (e.g. NPC equips a higher-AR item the user just gave them)
     leaves the preset broken.}
    If akBaseObject as Armor
        Actor follower = self.GetActorRef()
        If !follower
            Return
        EndIf

        ; Skip outfit-excluded actors entirely
        If SeverActionsNative.Native_GetOutfitExcluded(follower)
            Return
        EndIf
        ; Don't fight our own outfit changes mid-apply
        If StorageUtil.GetIntValue(follower, "SeverOutfit_Suspended", 0) == 1
            Return
        EndIf
        If SeverActionsNative.Native_Outfit_IsNativeSuspended(follower)
            Return
        EndIf

        ; Slot-preset OR legacy lock — both want debounced reapply.
        ; OnUpdate will choose the right path (DirectEquip vs ReapplyLockedOutfit).
        If IsSlotPresetActive(follower) || StorageUtil.GetIntValue(follower, "SeverOutfit_LockActive", 0) == 1
            ; Record unequip for burst detection (C++ timestamps it)
            SeverActionsNative.Native_Outfit_RecordExternalUnequip(follower)

            ; Start/reset debounce timer — if more unequips arrive before it fires,
            ; RegisterForSingleUpdate resets the countdown automatically.
            RegisterForSingleUpdate(ReequipDebounceSeconds)
        EndIf
    EndIf
EndEvent

Event OnObjectEquipped(Form akBaseObject, ObjectReference akReference)
    {Fires when the NPC equips any item. The wardrobe pattern requires us to
     react: NPCs have a built-in "wear best armor" auto-equip. If the user
     gives Jenassa a high-AR item while she's wearing a preset, the engine
     can swap her cuirass for the new item silently.

     We debounce-reapply the preset just like OnObjectUnequipped — same
     0.5s window catches both events from a single auto-swap. The reapply
     in OnUpdate strips ALL worn armor and re-equips only preset items, so
     intruders get cleaned up.

     Only fires for slot presets — legacy outfit lock didn't have this
     problem because it didn't make a distinction between "owned items"
     and "preset items".}
    If !(akBaseObject as Armor)
        Return
    EndIf

    Actor follower = self.GetActorRef()
    If !follower
        Return
    EndIf

    ; Only react when a slot preset is active
    If !IsSlotPresetActive(follower)
        Return
    EndIf

    ; Skip outfit-excluded actors
    If SeverActionsNative.Native_GetOutfitExcluded(follower)
        Return
    EndIf
    ; Don't fight our own equip during apply
    If StorageUtil.GetIntValue(follower, "SeverOutfit_Suspended", 0) == 1
        Return
    EndIf
    If SeverActionsNative.Native_Outfit_IsNativeSuspended(follower)
        Return
    EndIf

    ; Was this a preset item? If yes, no action needed (we equipped it).
    Int activeIdx = SeverActionsNative.Native_OutfitSlot_GetActivePreset(follower)
    If activeIdx < 0
        Return
    EndIf
    Int slotIdx = SeverActionsNative.Native_OutfitSlot_GetSlot(follower)
    If slotIdx < 0
        Return
    EndIf
    ObjectReference chest = SeverActionsNative.Native_OutfitSlot_GetContainer(slotIdx, activeIdx)
    If chest
        ; If the chest contains this exact form, the equip is one of OUR items
        ; (e.g. fired during DirectEquip's own equip loop) — ignore.
        If chest.GetItemCount(akBaseObject) > 0
            Return
        EndIf
    EndIf

    ; Non-preset armor entered the worn set — debounce-reapply the preset.
    SeverActionsNative.Native_Outfit_RecordExternalUnequip(follower)
    RegisterForSingleUpdate(ReequipDebounceSeconds)
EndEvent

Event OnUpdate()
    {Debounce timer fired — no new unequips for 0.5s. Now decide: re-equip or yield.}
    Actor follower = self.GetActorRef()
    If !follower || follower.IsDead()
        Return
    EndIf

    ; Skip outfit-excluded actors (cheap check first)
    If SeverActionsNative.Native_GetOutfitExcluded(follower)
        Return
    EndIf

    ; Skip if our outfit system is mid-operation
    If StorageUtil.GetIntValue(follower, "SeverOutfit_Suspended", 0) == 1
        Return
    EndIf
    If SeverActionsNative.Native_Outfit_IsNativeSuspended(follower)
        Return
    EndIf

    SeverActions_Outfit outfitSys = GetOutfitScript()

    ; Check global animation scene flag (set by SexLab/OStim ModEvent hooks in Outfit script)
    If outfitSys && outfitSys.AnimationSceneActive
        Debug.Trace("[SeverActions_OutfitAlias] Animation scene active — yielding for " + follower.GetDisplayName())
        Return
    EndIf

    ; Check if burst-suppressed (3+ rapid unequips detected by C++)
    If SeverActionsNative.Native_Outfit_IsBurstSuppressed(follower)
        Debug.Trace("[SeverActions_OutfitAlias] Burst suppression active — yielding for " + follower.GetDisplayName())
        Return
    EndIf

    ; SLOT PRESET path: re-apply via DirectEquip if a slot preset is active.
    ; (Used to short-circuit here on the assumption that SetOutfit self-enforces;
    ; that's no longer true with the wardrobe/blank-outfit pattern.)
    If IsSlotPresetActive(follower)
        Int activeIdx = SeverActionsNative.Native_OutfitSlot_GetActivePreset(follower)
        If activeIdx >= 0
            Int verifiedEquipped = SeverActionsNative.Native_OutfitSlot_DirectEquipPreset(follower, activeIdx)
            Debug.Trace("[SeverActions_OutfitAlias] OnUpdate reapply slot preset " + activeIdx + " for " + follower.GetDisplayName() + " (verified=" + verifiedEquipped + ")")
        EndIf
        Return
    EndIf

    If StorageUtil.GetIntValue(follower, "SeverOutfit_LockActive", 0) != 1
        Return
    EndIf

    ; Not in a scene, not burst-stripped — re-equip the locked outfit (legacy path)
    If outfitSys
        outfitSys.ReapplyLockedOutfit(follower)
    EndIf
EndEvent

; =============================================================================
; RE-EQUIP LOGIC (for cell load / OnLoad — immediate, no debounce)
; =============================================================================

Function ReequipIfLocked()
    {Direct re-equip for cell transitions — no debounce needed here since
     cell loads aren't caused by external mods stripping actors.

     Slot-preset path: We used to short-circuit on the assumption that
     SetOutfit(presetOutfit) would let the engine self-enforce. That changed
     when the apply path moved to DirectEquipPreset (atomic C++ equip with
     SetOutfit(blank)). So now: if a slot preset is active, RE-RUN the
     atomic equip on cell load. The chest is the persistent wardrobe and
     still has the items.}
    Actor follower = self.GetActorRef()
    If !follower || follower.IsDead()
        Return
    EndIf

    ; Skip outfit-excluded actors (cheap check first)
    If SeverActionsNative.Native_GetOutfitExcluded(follower)
        Return
    EndIf

    ; Don't fight in-progress outfit operations (builder, preset apply, etc.)
    If StorageUtil.GetIntValue(follower, "SeverOutfit_Suspended", 0) == 1
        Return
    EndIf
    If SeverActionsNative.Native_Outfit_IsNativeSuspended(follower)
        Return
    EndIf

    ; SLOT PRESET path: re-apply the active preset via DirectEquip.
    ; The chest still has the source items; we just need to re-strip + re-equip
    ; on the actor since cell unload may have wiped equipped state.
    If IsSlotPresetActive(follower)
        Int activeIdx = SeverActionsNative.Native_OutfitSlot_GetActivePreset(follower)
        If activeIdx >= 0
            SeverActions_OutfitSlot slotSys = GetSlotScript()
            If slotSys
                Int verifiedEquipped = SeverActionsNative.Native_OutfitSlot_DirectEquipPreset(follower, activeIdx)
                Debug.Trace("[SeverActions_OutfitAlias] Cell-load reapply slot preset " + activeIdx + " for " + follower.GetDisplayName() + " (verified=" + verifiedEquipped + ")")
            EndIf
        EndIf
        ; Don't fall through to legacy lock path — slot preset takes priority.
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

SeverActions_OutfitSlot Function GetSlotScript()
    Return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_OutfitSlot
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

Bool Function IsSlotPresetActive(Actor follower)
    {Fast short-circuit check: does this actor have an NFF-style slot preset
     currently active? If so, the engine re-equips the outfit automatically on
     every cell load via the DefaultOutfit mechanism. This alias becomes a
     no-op to avoid fighting the engine or guardian aliases on custom followers.}
    If !follower
        Return False
    EndIf
    Return StorageUtil.GetIntValue(follower, "SeverOutfit_PresetActive", 0) == 1
EndFunction

