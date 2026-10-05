Scriptname SeverActions_OutfitAlias extends ReferenceAlias

{
    Per-follower outfit enforcement on a ReferenceAlias of the SeverActions quest.
    A slot preset is applied with no SetOutfit (see SeverActions_OutfitSlot's
    header), so the engine never re-applies it: this alias does, beside the
    native 3D-load pass and the native settle re-check (OutfitSettle.h). Loads
    re-equip at once; unequips and intrusion equips are debounced so strip mods
    are not fought, and OnUpdate yields to scenes, bulk strips and
    helm/shield-only removals, else re-applies (a bulk re-dress included).
}

SeverActions_Outfit Property OutfitScript Auto
{Optional: direct reference to the Outfit script. Falls back to GetFormFromFile.}

Float Property ReequipDebounceSeconds = 0.5 Auto
{Debounce window before re-equipping after an unequip or intrusion equip; lets burst detection work.}

Bool IntrusionEquipPending = false
; True while the open debounce window holds an INTRUSION equip (non-preset
; armor put on, OnObjectEquipped). OnUpdate consumes it to veto the combat-gear
; yield: such a burst is an auto-equip swap, not a bare helm/shield removal.
; Equips stay out of the native burst counter, the bulk-strip detector (3+
; calls in 500 ms, blind to equip vs unequip): a two-piece swap would latch
; it. They are noted beside it instead (Native_Outfit_RecordIntrusionEquip),
; so Native_Outfit_ResolveBurst can tell a full re-dress from a strip.



; ---- Events ----

Event OnLoad()
    ReequipIfLocked()
EndEvent

Event OnCellLoad()
    ReequipIfLocked()
EndEvent

Event OnEnable()
    ReequipIfLocked()
EndEvent

; The healer bleedout fail-safe is HealerPoll's TESEnterBleedoutEvent sink, not
; an alias event here: outfit-excluded healers hold no seat.

Event OnObjectUnequipped(Form akBaseObject, ObjectReference akReference)
    {Records the unequip natively for burst detection and (re-)arms the debounce
     timer; OnUpdate decides once the burst settles. Acts for a slot preset or a legacy lock.}
    If akBaseObject as Armor
        Actor follower = self.GetActorRef()
        If !follower
            Return
        EndIf

        If SeverActionsNative.Native_GetOutfitExcluded(follower)
            Return
        EndIf
        ; Don't fight our own outfit changes mid-apply
        If SeverActionsNative.Native_Outfit_IsNativeSuspended(follower)
            Return
        EndIf
        ; Defer to bondage mods (DOM/PAH) — a captured/tied NPC's gear is theirs
        If SeverActionsNativeExt.Native_Outfit_IsExternallyControlled(follower)
            Return
        EndIf

        ; A HELD preset enforces nothing (IsSlotPresetHeld). Return before
        ; RecordExternalChange so the per-item action's own unequips do not
        ; feed burst suppression.
        If IsSlotPresetHeld(follower)
            Return
        EndIf

        ; Slot preset or legacy lock (read natively): OnUpdate picks the path.
        If IsSlotPresetActive(follower) || SeverActionsNativeExt.Native_Outfit_IsLockActive(follower)
            ; Form-aware: C++ also classifies whether the burst is only
            ; helm/shield removals (OnUpdate's combat-gear yield).
            SeverActionsNativeExt2.Native_Outfit_RecordExternalChange(follower, akBaseObject, true)

            ; Each event restarts the window (RegisterForSingleUpdate replaces the
            ; pending timer; an alias owns its form handle, unlike 0D62 scripts).
            RegisterForSingleUpdate(ReequipDebounceSeconds)
        EndIf
    EndIf
EndEvent

Event OnObjectEquipped(Form akBaseObject, ObjectReference akReference)
    {Slot presets only (the legacy lock re-equips its items and strips nothing).
     An NPC's "wear best armor" auto-equip can swap a preset piece for a better
     item it was given; the same debounce window catches both halves of the
     swap, and OnUpdate's re-apply strips the intruder. The equip is marked in
     IntrusionEquipPending, not the native burst counter.}
    If !(akBaseObject as Armor)
        Return
    EndIf

    Actor follower = self.GetActorRef()
    If !follower
        Return
    EndIf

    ; Only while a slot preset is active and not HELD: a held preset's
    ; intruders were put on deliberately by a per-item change.
    If !IsSlotPresetActive(follower) || IsSlotPresetHeld(follower)
        Return
    EndIf

    If SeverActionsNative.Native_GetOutfitExcluded(follower)
        Return
    EndIf
    ; Don't fight our own equip during apply
    If SeverActionsNative.Native_Outfit_IsNativeSuspended(follower)
        Return
    EndIf
    ; Defer to bondage mods (DOM/PAH) — a captured/tied NPC's gear is theirs
    If SeverActionsNativeExt.Native_Outfit_IsExternallyControlled(follower)
        Return
    EndIf

    ; An item in the active preset's chest is ours (e.g. DirectEquip's own
    ; equip loop): ignore it.
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
        If chest.GetItemCount(akBaseObject) > 0
            Return
        EndIf
    EndIf

    ; Non-preset armor put on: mark the burst (see IntrusionEquipPending),
    ; then debounce-reapply the preset.
    IntrusionEquipPending = true
    SeverActionsNativeExt2.Native_Outfit_RecordIntrusionEquip(follower, akBaseObject)
    RegisterForSingleUpdate(ReequipDebounceSeconds)
EndEvent

Event OnUpdate()
    {The debounce window settled: re-apply the slot preset or legacy lock, or yield.}
    ; Consume the intrusion mark on EVERY exit: one left by an early Return
    ; would veto the yield of an unrelated later burst.
    Bool intruderInBurst = IntrusionEquipPending
    IntrusionEquipPending = false

    Actor follower = self.GetActorRef()
    If !follower || follower.IsDead()
        Return
    EndIf

    ; Master switch off: SeverActions dresses nobody, enforcement included.
    If !SeverActionsNativeExt2.Native_Outfit_IsSystemEnabled()
        Return
    EndIf

    If SeverActionsNative.Native_GetOutfitExcluded(follower)
        Return
    EndIf

    ; Skip if our outfit system is mid-operation
    If SeverActionsNative.Native_Outfit_IsNativeSuspended(follower)
        Return
    EndIf

    ; Defer to bondage mods (DOM/PAH) — don't re-equip over restraints / a strip
    If SeverActionsNativeExt.Native_Outfit_IsExternallyControlled(follower)
        Return
    EndIf

    SeverActions_Outfit outfitSys = GetOutfitScript()

    ; Animation scene flag, set by the Outfit script's SexLab/OStim ModEvent hooks
    If outfitSys && outfitSys.AnimationSceneActive
        Debug.Trace("[SeverActions_OutfitAlias] Animation scene active - yielding for " + follower.GetDisplayName())
        Return
    EndIf

    ; Bulk change (3+ unequips in 500 ms): a strip stays latched until a cell
    ; load or our own outfit change clears it; a re-dress (non-preset armor put
    ; on in their place) is re-applied over, up to twice a minute. 0 = an older
    ; DLL without the native: the latch alone decides.
    Int burst = SeverActionsNativeExt2.Native_Outfit_ResolveBurst(follower)
    If burst == 0
        If SeverActionsNative.Native_Outfit_IsBurstSuppressed(follower)
            Debug.Trace("[SeverActions_OutfitAlias] Burst suppression active - yielding for " + follower.GetDisplayName())
            Return
        EndIf
    ElseIf burst == 1
        Debug.Trace("[SeverActions_OutfitAlias] Burst suppression active - yielding for " + follower.GetDisplayName())
        Return
    ElseIf burst == 2
        intruderInBurst = True
    EndIf

    ; Combat-gear yield (both paths below): an out-of-combat removal of ONLY
    ; helm/shield (e.g. FollowerLivePackage, which re-equips for combat) is a
    ; choice, not a strip, so leave it off. Not asked when the burst held an
    ; intrusion equip: the native never saw it, and a helm swapped for a
    ; better one would read as a helm-only removal.
    If !intruderInBurst && SeverActionsNativeExt2.Native_Outfit_ShouldYieldCombatGear(follower)
        Debug.Trace("[SeverActions_OutfitAlias] Combat-gear yield - leaving helm/shield off for " + follower.GetDisplayName())
        Return
    EndIf

    ; HELD preset: enforce nothing, not even a legacy lock (IsSlotPresetHeld).
    ; A hold keeps the active index, so the slot branch below would otherwise
    ; undo the per-item change.
    If IsSlotPresetHeld(follower)
        Return
    EndIf

    ; Slot preset: re-apply. DirectEquipPreset leaves a preset already worn in
    ; full alone (a piece taken off and put back).
    If IsSlotPresetActive(follower)
        Int activeIdx = SeverActionsNative.Native_OutfitSlot_GetActivePreset(follower)
        If activeIdx >= 0
            Int verifiedEquipped = SeverActionsNative.Native_OutfitSlot_DirectEquipPreset(follower, activeIdx)
            Debug.Trace("[SeverActions_OutfitAlias] OnUpdate reapply slot preset " + activeIdx + " for " + follower.GetDisplayName() + " (verified=" + verifiedEquipped + ")")
        EndIf
        Return
    EndIf

    If !SeverActionsNativeExt.Native_Outfit_IsLockActive(follower)
        Return
    EndIf

    ; Legacy lock
    If outfitSys
        outfitSys.ReapplyLockedOutfit(follower)
    EndIf
EndEvent

; ---- Re-equip on load (immediate, no debounce) ----

Function ReequipIfLocked()
    {Immediate re-equip on load (a load is not an external strip, so no
     debounce). A slot preset is re-run from its chest; DirectEquipPreset
     leaves an actor already wearing it in full alone (e.g. the native 3D-load
     pass got there first), so nothing flickers.}
    ; A cell change ends any open burst, and its intrusion mark with it.
    IntrusionEquipPending = false

    Actor follower = self.GetActorRef()
    If !follower || follower.IsDead()
        Return
    EndIf

    ; Master switch off: SeverActions dresses nobody, enforcement included.
    If !SeverActionsNativeExt2.Native_Outfit_IsSystemEnabled()
        Return
    EndIf

    If SeverActionsNative.Native_GetOutfitExcluded(follower)
        Return
    EndIf

    ; Defer to bondage mods (DOM/PAH) — a captured/tied NPC stays as they are
    If SeverActionsNativeExt.Native_Outfit_IsExternallyControlled(follower)
        Return
    EndIf

    ; A cell change ends the external scene (bathing strip, animation framework):
    ; clear burst suppression for EVERY enforced actor, before the slot branch
    ; and the suspend test (the native 3D-load apply's grace is often live here),
    ; or a preset wearer stays suppressed and OnUpdate yields to every later swap.
    SeverActionsNative.Native_Outfit_ClearBurstSuppression(follower)

    ; Don't fight in-progress outfit operations (builder, preset apply, etc.)
    If SeverActionsNative.Native_Outfit_IsNativeSuspended(follower)
        Return
    EndIf

    ; HELD preset: no re-apply and no legacy-lock re-equip, mirroring
    ; OutfitDataStore::ReequipLockedItemsOnActor (IsSlotPresetHeld).
    If IsSlotPresetHeld(follower)
        Return
    EndIf

    ; Slot preset: re-equipped from the chest only if no longer worn in full
    ; (a cell unload can wipe equipped state).
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

    If !SeverActionsNativeExt.Native_Outfit_IsLockActive(follower)
        Return
    EndIf

    SeverActions_Outfit outfitSys = GetOutfitScript()
    If outfitSys
        outfitSys.ReapplyLockedOutfit(follower)
    EndIf
EndFunction

SeverActions_OutfitSlot Function GetSlotScript()
    Return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_OutfitSlot
EndFunction

; ---- Helpers ----

SeverActions_Outfit Function GetOutfitScript()
    If OutfitScript
        Return OutfitScript
    EndIf
    Return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Outfit
EndFunction

Bool Function IsSlotPresetActive(Actor follower)
    {True if the actor has an active slot preset: the handlers then re-apply
     through DirectEquipPreset instead of the legacy lock list.}
    If !follower
        Return False
    EndIf
    ; The native slot store is the source of truth, never a StorageUtil mirror
    ; (C++ apply paths bypass one).
    Return SeverActionsNative.Native_OutfitSlot_GetActivePreset(follower) >= 0
EndFunction

Bool Function IsSlotPresetHeld(Actor follower)
    {True while the active slot preset is HELD: a per-item change
     (EquipMultipleItems / UnequipMultipleItems) took over. It stays the active
     index, so teardowns still reclaim its catalog copies, but this alias
     enforces nothing - neither the preset nor a legacy lock, mirroring
     OutfitDataStore::ReequipLockedItemsOnActor - until the next apply, clear
     or GetDressed. Asks the native only when a preset is active, so on an
     older DLL without it (an error per call, reads False) only preset wearers
     log.}
    If !follower
        Return False
    EndIf
    If SeverActionsNative.Native_OutfitSlot_GetActivePreset(follower) < 0
        Return False
    EndIf
    Return SeverActionsNativeExt2.Native_OutfitSlot_IsActivePresetHeld(follower)
EndFunction

