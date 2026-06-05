Scriptname SeverActions_Outfit extends Quest
;{Outfit management actions - dress and undress NPCs}
;{Actions are registered via YAML files, this script just provides execution functions}
;{Compatible with Immersive Equipping Animations for dress/undress anims}

; =============================================================================
; PROPERTIES
; =============================================================================

Float Property AnimDelayHelmet = 2.2 Auto
Float Property AnimDelayBody = 2.5 Auto
Float Property AnimDelayHands = 2.2 Auto
Float Property AnimDelayFeet = 3.5 Auto
Float Property AnimDelayNeck = 3.5 Auto
Float Property AnimDelayRing = 3.5 Auto
Float Property AnimDelayCloak = 2.5 Auto
Float Property AnimDelayGeneric = 2.0 Auto

Bool Property UseAnimations = true Auto
{Set to false to disable all animations}

Bool Property OutfitLockEnabled = true Auto
{Master toggle for the outfit lock system. When disabled, outfits will not be
snapshotted or re-applied on cell transitions. Existing locks are preserved
but inactive until re-enabled.}

Bool Property AnimationSceneActive = false Auto Hidden
{Global flag — true when a SexLab/OStim scene is active. Blocks all outfit lock
re-equips system-wide. Set by ModEvent hooks, read by OutfitAlias.}

; Phase 1 ParityCheckIntervalSeconds removed in Phase 4 along with the sweep.

; =============================================================================
; ANIMATION EVENT NAMES
; These match Immersive Equipping Animations by default
; =============================================================================

String Property AnimEventEquipHelmet = "Equiphelmet" Auto
String Property AnimEventEquipHood = "Equiphood" Auto
String Property AnimEventEquipBody = "Equipcuirass" Auto
String Property AnimEventEquipHands = "Equiphands" Auto
String Property AnimEventEquipFeet = "equipboots" Auto
String Property AnimEventEquipNeck = "Equipneck" Auto
String Property AnimEventEquipRing = "equipring" Auto
String Property AnimEventEquipCloak = "Equipcuirass" Auto

String Property AnimEventUnequipHelmet = "unequiphelmet" Auto
String Property AnimEventUnequipBody = "unequipcuirass" Auto
String Property AnimEventUnequipHands = "unequiphands" Auto
String Property AnimEventUnequipFeet = "unequipboots" Auto
String Property AnimEventUnequipNeck = "unequipneck" Auto
String Property AnimEventUnequipRing = "unequipring" Auto
String Property AnimEventUnequipCloak = "unequipcuirass" Auto

String Property AnimEventStop = "OffsetStop" Auto

; =============================================================================
; SINGLETON
; =============================================================================

SeverActions_Outfit Function GetInstance() Global
    return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Outfit
EndFunction

SeverActions_OutfitSlot Function GetSlotScript() Global
    {Get the slot-system orchestration script (NFF-style preset system).
     Returns None if not yet loaded.}
    return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_OutfitSlot
EndFunction

; =============================================================================
; ANIMATION FUNCTIONS
; =============================================================================

Function PlayEquipAnimation(Actor akActor, String slotName)
    if !UseAnimations || !akActor
        return
    endif
    
    if akActor.GetSitState() != 0 || akActor.IsSwimming() || akActor.GetSleepState() != 0
        return
    endif
    
    akActor.SetHeadTracking(false)
    
    String animEvent = GetEquipAnimEvent(slotName)
    float delay = GetAnimDelay(slotName)
    
    if animEvent != ""
        Debug.SendAnimationEvent(akActor, animEvent)
        Utility.Wait(delay)
        Debug.SendAnimationEvent(akActor, AnimEventStop)
    endif
    
    akActor.SetHeadTracking(true)
EndFunction

Function PlayUnequipAnimation(Actor akActor, String slotName)
    if !UseAnimations || !akActor
        return
    endif
    
    if akActor.GetSitState() != 0 || akActor.IsSwimming() || akActor.GetSleepState() != 0
        return
    endif
    
    akActor.SetHeadTracking(false)
    
    String animEvent = GetUnequipAnimEvent(slotName)
    float delay = GetAnimDelay(slotName)
    
    if animEvent != ""
        Debug.SendAnimationEvent(akActor, animEvent)
        Utility.Wait(delay)
        Debug.SendAnimationEvent(akActor, AnimEventStop)
    endif
    
    akActor.SetHeadTracking(true)
EndFunction

String Function GetEquipAnimEvent(String slotName)
    String slot = StringToLower(slotName)
    
    if slot == "head" || slot == "helmet" || slot == "hat" || slot == "mask" || slot == "circlet"
        return AnimEventEquipHelmet
    elseif slot == "hood"
        return AnimEventEquipHood
    elseif slot == "body" || slot == "chest" || slot == "armor" || slot == "cuirass" || slot == "shirt" || slot == "robes"
        return AnimEventEquipBody
    elseif slot == "hands" || slot == "gloves" || slot == "gauntlets"
        return AnimEventEquipHands
    elseif slot == "feet" || slot == "boots" || slot == "shoes"
        return AnimEventEquipFeet
    elseif slot == "amulet" || slot == "necklace" || slot == "neck"
        return AnimEventEquipNeck
    elseif slot == "ring"
        return AnimEventEquipRing
    elseif slot == "cloak" || slot == "cape" || slot == "back"
        return AnimEventEquipCloak
    endif
    
    return AnimEventEquipBody
EndFunction

String Function GetUnequipAnimEvent(String slotName)
    String slot = StringToLower(slotName)
    
    if slot == "head" || slot == "helmet" || slot == "hat" || slot == "hood" || slot == "mask" || slot == "circlet"
        return AnimEventUnequipHelmet
    elseif slot == "body" || slot == "chest" || slot == "armor" || slot == "cuirass" || slot == "shirt" || slot == "robes"
        return AnimEventUnequipBody
    elseif slot == "hands" || slot == "gloves" || slot == "gauntlets"
        return AnimEventUnequipHands
    elseif slot == "feet" || slot == "boots" || slot == "shoes"
        return AnimEventUnequipFeet
    elseif slot == "amulet" || slot == "necklace" || slot == "neck"
        return AnimEventUnequipNeck
    elseif slot == "ring"
        return AnimEventUnequipRing
    elseif slot == "cloak" || slot == "cape" || slot == "back"
        return AnimEventUnequipCloak
    endif
    
    return AnimEventUnequipBody
EndFunction

Float Function GetAnimDelay(String slotName)
    String slot = StringToLower(slotName)
    
    if slot == "head" || slot == "helmet" || slot == "hat" || slot == "hood" || slot == "mask" || slot == "circlet"
        return AnimDelayHelmet
    elseif slot == "body" || slot == "chest" || slot == "armor" || slot == "cuirass"
        return AnimDelayBody
    elseif slot == "hands" || slot == "gloves" || slot == "gauntlets"
        return AnimDelayHands
    elseif slot == "feet" || slot == "boots" || slot == "shoes"
        return AnimDelayFeet
    elseif slot == "amulet" || slot == "necklace" || slot == "neck"
        return AnimDelayNeck
    elseif slot == "ring"
        return AnimDelayRing
    elseif slot == "cloak" || slot == "cape"
        return AnimDelayCloak
    endif
    
    return AnimDelayGeneric
EndFunction

; =============================================================================
; ACTION: Undress
; YAML parameterMapping: [speaker]
; =============================================================================

Function Undress_Execute(Actor akActor)
    if !akActor
        return
    endif

    Debug.Trace("[SeverActions_Outfit] Undress: " + akActor.GetDisplayName())

    ; Stash worn armor BEFORE BeginAdHocOutfitOp runs. The op's
    ; ClearActivePresetForAdHoc path strips preset items via
    ; RemovePresetItemsFromActor — once that runs, GetWornForm finds nothing
    ; and the slot-loop below has nothing to stash. Symptom: preset-applied
    ; outfit "comes off all at once" with no animations, then Dress reports
    ; "no stash". Pre-stash here, then the slot loop becomes the
    ; animation-and-unequip-the-rest pass for any items that survived.
    ;
    ; Mirrors the same blacklist + slot-exclusion filter the main loop
    ; applies, so stashed items match what we expect Dress to re-equip.
    SeverActionsNativeExt.Native_Outfit_DressStashClear(akActor)
    Form[] preWornArmor = SeverActionsNative.Native_Outfit_GetWornArmor(akActor)
    If preWornArmor
        Int pwi = 0
        While pwi < preWornArmor.Length
            Armor pwItem = preWornArmor[pwi] as Armor
            if pwItem && !SeverActionsNative.Native_Blacklist_IsBlacklisted(pwItem)
                SeverActionsNativeExt.Native_Outfit_DressStashAdd(akActor, pwItem)
            endif
            pwi += 1
        EndWhile
    EndIf

    BeginAdHocOutfitOp(akActor)

    ; Snapshot the actor's DefaultOutfit as a Dress fallback (e.g. Lydia's
    ; base armor where the gear comes from DefaultOutfit, not individual
    ; equips). Done AFTER BeginAdHocOutfitOp so any preset cleanup that
    ; restored the original DefaultOutfit is reflected in what we snapshot.
    ActorBase npcBase = akActor.GetActorBase()
    If npcBase
        Outfit baseOutfit = npcBase.GetOutfit(false)
        If baseOutfit
            SeverActionsNativeExt.Native_Outfit_DressStashSetDefaultOutfit(akActor, baseOutfit)
        EndIf
    EndIf

    ; All slots to check — vanilla + modded biped slots 30-60.
    ; Intentionally excluded: slot 31/Hair, 38/Calves, 41/LongHair (protect wigs),
    ; plus 50/DecapitateHead and 51/Decapitate (gore FX, not real gear).
    int[] slots = new int[26]
    slots[0]  = 0x00000001   ; Head (30)
    slots[1]  = 0x00000004   ; Body (32)
    slots[2]  = 0x00000008   ; Hands (33)
    slots[3]  = 0x00000010   ; Forearms (34)
    slots[4]  = 0x00000020   ; Amulet (35)
    slots[5]  = 0x00000040   ; Ring (36)
    slots[6]  = 0x00000080   ; Feet (37)
    slots[7]  = 0x00000200   ; Shield (39)
    slots[8]  = 0x00000400   ; Tail (40)
    slots[9]  = 0x00001000   ; Circlet (42)
    slots[10] = 0x00002000   ; Ears (43)
    slots[11] = 0x00004000   ; Mouth (44)
    slots[12] = 0x00008000   ; Neck (45)
    slots[13] = 0x00010000   ; Cloak (46)
    slots[14] = 0x00020000   ; Back (47)
    slots[15] = 0x00040000   ; Misc (48)
    slots[16] = 0x00080000   ; Pelvis (49)
    slots[17] = 0x00400000   ; Pelvis 2 / Underwear (52)
    slots[18] = 0x00800000   ; Leg (53)
    slots[19] = 0x01000000   ; Leg 2 (54)
    slots[20] = 0x02000000   ; Face (55)
    slots[21] = 0x04000000   ; Chest 2 (56)
    slots[22] = 0x08000000   ; Shoulder (57)
    slots[23] = 0x10000000   ; Arm (58)
    slots[24] = 0x20000000   ; Arm 2 (59)
    slots[25] = 0x40000000   ; FX01 (60)

    ; Slot names for animations (pick the closest unequip-anim category)
    String[] slotNames = new String[26]
    slotNames[0]  = "helmet"
    slotNames[1]  = "body"
    slotNames[2]  = "hands"
    slotNames[3]  = "hands"
    slotNames[4]  = "neck"
    slotNames[5]  = "ring"
    slotNames[6]  = "feet"
    slotNames[7]  = "body"
    slotNames[8]  = "cloak"
    slotNames[9]  = "helmet"
    slotNames[10] = "helmet"
    slotNames[11] = "helmet"   ; Mouth — face-level
    slotNames[12] = "neck"     ; Neck
    slotNames[13] = "cloak"    ; Cloak
    slotNames[14] = "cloak"    ; Back
    slotNames[15] = "body"     ; Misc
    slotNames[16] = "body"     ; Pelvis
    slotNames[17] = "body"     ; Pelvis 2
    slotNames[18] = "feet"     ; Leg
    slotNames[19] = "feet"     ; Leg 2
    slotNames[20] = "helmet"   ; Face
    slotNames[21] = "body"     ; Chest 2
    slotNames[22] = "cloak"    ; Shoulder
    slotNames[23] = "hands"    ; Arm
    slotNames[24] = "hands"    ; Arm 2
    slotNames[25] = "cloak"    ; FX01
    
    ; Slot-loop pass: animations + unequip for items still equipped after
    ; BeginAdHocOutfitOp. Stash was already populated by the pre-stash above,
    ; so no DressStashAdd here (would create duplicates for non-preset items
    ; that survived BeginAdHocOutfitOp). The 26-slot inclusion list deliberately
    ; skips wigs (slot 31/41) and decap FX — those stay equipped through
    ; Undress AND remain in the stash, so Dress's re-equip on them is a no-op
    ; (already worn).
    int i = 0
    int removedCount = 0
    while i < slots.Length
        Armor equippedItem = akActor.GetWornForm(slots[i]) as Armor
        if equippedItem
            If SeverActionsNative.Native_Blacklist_IsBlacklisted(equippedItem)
                Debug.Trace("[SeverActions_Outfit] Undress: Skipping blacklisted " + equippedItem.GetName())
            Else
                PlayUnequipAnimation(akActor, slotNames[i])
                ; preventEquip = true — stops the engine's DefaultOutfit system
                ; from re-equipping this item on the next AI tick
                akActor.UnequipItem(equippedItem, true, true)
                removedCount += 1
            EndIf
        endif
        i += 1
    endwhile
    
    ; Clear outfit lock — nothing worn means nothing to persist
    ClearLockedOutfit(akActor)

    ; Clear active preset — manual change
    SeverActionsNative.Native_Outfit_SetActivePreset(akActor, "")

    ResumeOutfitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] Removed " + removedCount + " items")
EndFunction

Bool Function Undress_IsEligible(Actor akActor)
{Check if actor can be undressed - must be alive and have something equipped}
    if !akActor
        return false
    endif
    if akActor.IsDead()
        return false
    endif
    ; Could add more checks here (e.g., has armor equipped)
    return true
EndFunction

; =============================================================================
; ACTION: Dress
; YAML parameterMapping: [speaker]
; =============================================================================

Function Dress_Execute(Actor akActor)
    if !akActor
        return
    endif

    BeginAdHocOutfitOp(akActor)
    Debug.Trace("[SeverActions_Outfit] Dress: " + akActor.GetDisplayName())

    ; Phase 5: read from native transient stash (replaces the
    ; SeverActions_RemovedArmor_* StorageUtil FormList + DefaultOutfit Form).
    Form[] stashed = SeverActionsNativeExt.Native_Outfit_DressStashGet(akActor)
    Int count = 0
    if stashed
        count = stashed.Length
    endif

    if count == 0
        ; No individual items stashed — try restoring the snapshotted DefaultOutfit.
        Outfit baseOutfit = SeverActionsNativeExt.Native_Outfit_DressStashGetDefaultOutfit(akActor)
        If baseOutfit
            ActorBase npcBase = akActor.GetActorBase()
            If npcBase
                Debug.Trace("[SeverActions_Outfit] Dress: Restoring DefaultOutfit for " + akActor.GetDisplayName())
                npcBase.SetOutfit(baseOutfit, false)
                akActor.SetOutfit(baseOutfit, false)
                SeverActionsNativeExt.Native_Outfit_DressStashSetDefaultOutfit(akActor, None)
                ; Don't SnapshotLockedOutfit here — SetOutfit is async and GetWornForm
                ; returns stale data. The restored DefaultOutfit handles equipping on
                ; the next AI tick/cell transition.
                ResumeOutfitLock(akActor)
                return
            EndIf
        EndIf
        ; No stash, no DefaultOutfit — try re-equipping locked outfit items.
        Form[] lockedItems = SeverActionsNative.Native_Outfit_GetLockedItems(akActor)
        If lockedItems && lockedItems.Length > 0
            Debug.Trace("[SeverActions_Outfit] Dress: No stash, re-equipping " + lockedItems.Length + " locked outfit items")
            Int li = 0
            While li < lockedItems.Length
                If lockedItems[li]
                    Armor armorItem = lockedItems[li] as Armor
                    If armorItem
                        String slotName = GetSlotNameFromMask(armorItem.GetSlotMask())
                        PlayEquipAnimation(akActor, slotName)
                    EndIf
                    akActor.EquipItem(lockedItems[li], false, true)
                EndIf
                li += 1
            EndWhile
            ResumeOutfitLock(akActor)
            return
        EndIf

        Debug.Trace("[SeverActions_Outfit] No stash or locked outfit to put on")
        ResumeOutfitLock(akActor)
        return
    endif

    ; Re-equip every stashed item.
    Form[] equippedForms = new Form[32]
    Int equippedCount = 0

    int i = 0
    while i < count
        Form item = stashed[i]
        if item
            Armor armorItem = item as Armor
            if armorItem
                String slotName = GetSlotNameFromMask(armorItem.GetSlotMask())
                PlayEquipAnimation(akActor, slotName)
            endif
            akActor.EquipItem(item, false, true)
            if equippedCount < 32
                equippedForms[equippedCount] = item
                equippedCount += 1
            endif
        endif
        i += 1
    endwhile

    ; Clear the transient stash now that we've consumed it.
    SeverActionsNativeExt.Native_Outfit_DressStashClear(akActor)
    SeverActionsNativeExt.Native_Outfit_DressStashSetDefaultOutfit(akActor, None)

    if equippedCount > 0
        LockEquippedOutfit(akActor, equippedForms, equippedCount)
    endif

    ; Clear active preset — dressing from stashed items is a manual action.
    SeverActionsNative.Native_Outfit_SetActivePreset(akActor, "")

    ResumeOutfitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] Re-equipped " + equippedCount + " items")
EndFunction

Bool Function Dress_IsEligible(Actor akActor)
{Check if actor can be dressed - must be alive and have stored clothing or a saved DefaultOutfit}
    if !akActor
        return false
    endif
    if akActor.IsDead()
        return false
    endif
    ; Phase 5: read from native transient stash.
    Form[] stashed = SeverActionsNativeExt.Native_Outfit_DressStashGet(akActor)
    if stashed && stashed.Length > 0
        return true
    endif
    ; Also eligible if the actor's DefaultOutfit was snapshotted.
    return SeverActionsNativeExt.Native_Outfit_DressStashGetDefaultOutfit(akActor) != None
EndFunction

; =============================================================================
; ACTION: EquipMultipleItems
; YAML parameterMapping: [speaker, itemNames]
; Equips multiple items from a comma-separated list
; C++ for search, Papyrus EquipItem for thread-safe equipping
; =============================================================================

Function EquipMultipleItems_Execute(Actor akActor, String itemNames)
    if !akActor || itemNames == ""
        return
    endif

    BeginAdHocOutfitOp(akActor)
    Debug.Trace("[SeverActions_Outfit] EquipMultipleItems: " + akActor.GetDisplayName() + " equipping '" + itemNames + "'")

    Form[] equippedForms = new Form[32]
    Int count = 0
    String[] tokens = ParseCSVTrim(itemNames)
    Int ti = 0
    while ti < tokens.Length && count < 32
        Form equipped = EquipSingleItemAndReturn(akActor, tokens[ti])
        if equipped
            equippedForms[count] = equipped
            count += 1
        endif
        ti += 1
    endwhile

    ; Lock from items we KNOW we equipped + GetWornForm for unchanged slots
    if count > 0
        LockEquippedOutfit(akActor, equippedForms, count)
    endif

    ; Clear active preset — manual equip overrides any preset
    SeverActionsNative.Native_Outfit_SetActivePreset(akActor, "")

    ResumeOutfitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] EquipMultipleItems: Equipped " + count + " items")
EndFunction

; =============================================================================
; ACTION: UnequipMultipleItems
; YAML parameterMapping: [speaker, itemNames]
; Unequips multiple worn items from a comma-separated list
; C++ for search, Papyrus UnequipItem for thread-safe unequipping
; =============================================================================

Function UnequipMultipleItems_Execute(Actor akActor, String itemNames)
    if !akActor || itemNames == ""
        return
    endif

    BeginAdHocOutfitOp(akActor)
    Debug.Trace("[SeverActions_Outfit] UnequipMultipleItems: " + akActor.GetDisplayName() + " removing '" + itemNames + "'")

    ; Collect Forms we actually unequip so we can remove them from the lock list
    Form[] removedForms = new Form[32]
    Int removedCount = 0
    String[] tokens = ParseCSVTrim(itemNames)
    Int ti = 0
    while ti < tokens.Length && removedCount < 32
        Form removed = UnequipSingleItemInternal2(akActor, tokens[ti])
        if removed
            removedForms[removedCount] = removed
            removedCount += 1
        endif
        ti += 1
    endwhile

    ; Remove unequipped items directly from the lock list instead of
    ; re-snapshotting with GetWornForm (which returns stale data because
    ; UnequipItem is async and the item is still "worn" at this point)
    if removedCount > 0
        RemoveFromLockedOutfit(akActor, removedForms, removedCount)
    endif

    ResumeOutfitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] UnequipMultipleItems: Unequipped " + removedCount + " items")
EndFunction

; =============================================================================
; ACTION: SaveOutfitPreset
; YAML parameterMapping: [speaker, presetName]
; Snapshots all currently worn items and stores them under a named preset
; =============================================================================

Function SaveOutfitPreset_Execute(Actor akActor, String presetName)
    if !akActor || presetName == ""
        return
    endif

    presetName = NormalizePresetName(presetName)

    ; ── NFF-style slot system path (preferred for eligible actors) ──
    ; New presets go into a dedicated BGSOutfit+LeveledItem+Container triple.
    ; Falls through to legacy on ineligible actors or when all 8 slots full.
    SeverActions_OutfitSlot slotSys = GetSlotScript()
    If slotSys && slotSys.IsSlotEligible(akActor)
        Int slotIdx = slotSys.AssignSlotToActor(akActor)
        If slotIdx >= 0
            Int presetIdx = slotSys.FindFreeOrReusableIndex(akActor, presetName)
            If presetIdx >= 0
                Form[] slotWorn = SeverActionsNative.Native_Outfit_GetWornArmor(akActor)
                If slotWorn && slotWorn.Length > 0
                    slotSys.BuildPreset(akActor, presetIdx, slotWorn, presetName)
                    Debug.Trace("[SeverActions_Outfit] SaveOutfitPreset(slot): '" + presetName + "' idx=" + presetIdx + " for " + akActor.GetDisplayName())
                Else
                    Debug.Trace("[SeverActions_Outfit] SaveOutfitPreset(slot): Actor not wearing armor, refusing empty preset")
                    return
                EndIf
            Else
                Debug.Trace("[SeverActions_Outfit] SaveOutfitPreset(slot): All 8 slots full for " + akActor.GetDisplayName() + " — legacy path only")
            EndIf
        EndIf
    EndIf

    ; Phase 4: native-only legacy preset write. Snapshots worn armor into
    ; OutfitDataStore.presets via Begin/Add/Commit then locks via the
    ; native single-write path.
    Debug.Trace("[SeverActions_Outfit] SaveOutfitPreset: Saving '" + presetName + "' for " + akActor.GetDisplayName())
    Form[] wornForms = SeverActionsNative.Native_Outfit_GetWornArmor(akActor)
    Int savedCount = 0
    If wornForms
        savedCount = wornForms.Length
    EndIf

    SeverActionsNative.Native_Outfit_BeginPreset(akActor, presetName)
    Int npi = 0
    While npi < savedCount && npi < 32
        if wornForms[npi]
            SeverActionsNative.Native_Outfit_AddPresetItem(akActor, wornForms[npi])
        endif
        npi += 1
    EndWhile
    SeverActionsNative.Native_Outfit_CommitPreset(akActor)

    ; Lock the outfit so it persists across cell changes (also native-only now).
    SuspendOutfitLock(akActor)
    LockEquippedOutfit(akActor, wornForms, savedCount)
    ResumeOutfitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] SaveOutfitPreset: Saved and locked " + savedCount + " items as '" + presetName + "'")
EndFunction

; =============================================================================
; ACTION: ApplyOutfitPreset
; YAML parameterMapping: [speaker, presetName]
; Removes current gear and equips all items from a saved preset
; =============================================================================

Function ApplyOutfitPreset_Execute(Actor akActor, String presetName)
    if !akActor || presetName == ""
        return
    endif

    presetName = NormalizePresetName(presetName)

    ; ── NFF-style slot system path (preferred when preset exists in slot) ──
    SeverActions_OutfitSlot slotSys = GetSlotScript()
    If slotSys
        SeverActionsNative.Native_OutfitSlot_Log("ApplyOutfitPreset_Execute: Trying slot path for " + akActor.GetDisplayName() + " preset='" + presetName + "'")
        Int presetIdx = slotSys.FindPresetIndexByName(akActor, presetName)
        SeverActionsNative.Native_OutfitSlot_Log("ApplyOutfitPreset_Execute: FindPresetIndexByName returned " + presetIdx)
        If presetIdx >= 0
            slotSys.ApplyPresetBySlot(akActor, presetIdx)
            Debug.Trace("[SeverActions_Outfit] ApplyOutfitPreset(slot): '" + presetName + "' idx=" + presetIdx + " on " + akActor.GetDisplayName())
            Return
        EndIf
    Else
        SeverActionsNative.Native_OutfitSlot_Log("ApplyOutfitPreset_Execute: WARNING slotSys is None - script not attached?")
    EndIf

    SeverActionsNative.Native_OutfitSlot_Log("ApplyOutfitPreset_Execute: Falling back to legacy path for " + akActor.GetDisplayName() + " preset='" + presetName + "'")

    ; Phase 4: native-only legacy fallback. Read preset items from
    ; OutfitDataStore; the StorageUtil presetKey mirror is gone.
    Form[] presetItems = SeverActionsNative.Native_Outfit_GetPresetItems(akActor, presetName)
    Int count = 0
    if presetItems
        count = presetItems.Length
    endif
    if count == 0
        Debug.Trace("[SeverActions_Outfit] ApplyOutfitPreset: No preset '" + presetName + "' found for " + akActor.GetDisplayName())
        return
    endif

    ; Legacy apply is an ad-hoc gear change relative to any active slot preset
    ; — the requested preset only exists in legacy storage, otherwise the slot
    ; path above would have returned. Without the BeginAdHocOutfitOp call, the
    ; slot alias's OnUpdate would re-enforce the previously-active slot preset
    ; over the legacy outfit we're about to apply.
    BeginAdHocOutfitOp(akActor)

    Debug.Trace("[SeverActions_Outfit] ApplyOutfitPreset: Applying '" + presetName + "' (" + count + " items) to " + akActor.GetDisplayName())

    ; First undress — remove all currently worn items, stashing them in
    ; the native Dress session map so a follow-up Dress could re-equip.
    SeverActionsNativeExt.Native_Outfit_DressStashClear(akActor)
    Form[] wornArmor = SeverActionsNative.Native_Outfit_GetWornArmor(akActor)
    If wornArmor
        Int wi = 0
        While wi < wornArmor.Length
            Armor equippedItem = wornArmor[wi] as Armor
            if equippedItem && !SeverActionsNative.Native_Blacklist_IsBlacklisted(equippedItem)
                SeverActionsNativeExt.Native_Outfit_DressStashAdd(akActor, equippedItem)
                akActor.UnequipItem(equippedItem, true, true)
            endif
            wi += 1
        EndWhile
    EndIf

    ; Equip every item from the preset (read from native, no StorageUtil mirror).
    Form[] presetForms = new Form[32]
    Int equippedCount = 0
    int i = 0
    while i < count
        Form item = presetItems[i]
        if item
            If akActor.GetItemCount(item) == 0
                akActor.AddItem(item, 1, true)
            EndIf
            Armor armorItem = item as Armor
            if armorItem
                String slotName = GetSlotNameFromMask(armorItem.GetSlotMask())
                PlayEquipAnimation(akActor, slotName)
            endif
            akActor.EquipItem(item, false, true)
            if equippedCount < 32
                presetForms[equippedCount] = item
                equippedCount += 1
            endif
        endif
        i += 1
    endwhile

    ; Lock-after-apply gating (post-tester-audit fix): only lock if the actor
    ; was ALREADY locked before this call. This used to be unconditional,
    ; which caused two user-facing bugs: (1) `applyoutfitpreset` LLM action
    ; locked previously-unlocked actors, breaking "sequence of dress changes"
    ; workflows; (2) Apply button in PrismaUI did the same. Now: applying
    ; preserves whatever lock state the actor was already in. If they were
    ; locked, the new preset items become the new lock list. If they were
    ; unlocked, they stay unlocked. Locking is a separate user gesture.
    ; Phase 3: read lock state from native.
    Bool wasLocked = SeverActionsNativeExt.Native_Outfit_IsLockActive(akActor)
    If wasLocked
        ; Lock from known equipped items (avoids GetWornForm race condition)
        LockEquippedOutfit(akActor, presetForms, equippedCount)
    EndIf

    ; Track active preset for prompt context and situation system
    SeverActionsNative.Native_Outfit_SetActivePreset(akActor, presetName)

    ResumeOutfitLock(akActor)

    ; Force re-evaluate situation after resume. If a situation event arrived
    ; while Suspended was set, it was correctly dropped — but SituationMonitor's
    ; C++ state already updated. Re-evaluating syncs the two sides and fires
    ; a new event if the situation actually changed during the apply.
    SeverActionsNativeExt.SituationMonitor_ForceEvaluate(akActor)

    Debug.Trace("[SeverActions_Outfit] ApplyOutfitPreset: Equipped " + equippedCount + " items from '" + presetName + "'")
EndFunction

; =============================================================================
; INTERNAL HELPERS - C++ search + Papyrus equip (thread-safe)
; =============================================================================

String Function ResolveItemName(String itemName)
{If the LLM sends an OmniSight name like 'Black Leather Gauntlets (Akasha Gloves)',
 extract the original game name from parentheses for C++ item search.
 Returns the parenthetical content if present, otherwise the original string.}
    Int parenStart = StringUtil.Find(itemName, "(")
    If parenStart >= 0
        Int parenEnd = StringUtil.Find(itemName, ")", parenStart)
        If parenEnd > parenStart + 1
            String originalName = StringUtil.Substring(itemName, parenStart + 1, parenEnd - parenStart - 1)
            originalName = TrimString(originalName)
            If originalName != ""
                Debug.Trace("[SeverActions_Outfit] ResolveItemName: '" + itemName + "' -> '" + originalName + "'")
                return originalName
            EndIf
        EndIf
    EndIf
    return itemName
EndFunction

Form Function EquipSingleItemAndReturn(Actor akActor, String itemName)
{Search inventory in C++, equip via Papyrus EquipItem. Returns the equipped Form, or None on failure.}
    String searchName = ResolveItemName(itemName)
    Form foundForm = SeverActionsNative.FindItemByName(akActor, searchName)
    if !foundForm && searchName != itemName
        foundForm = SeverActionsNative.FindItemByName(akActor, itemName)
    endif
    if !foundForm
        Debug.Trace("[SeverActions_Outfit] EquipMultiple: '" + itemName + "' not found in inventory")
        return None
    endif

    akActor.EquipItem(foundForm, false, true)
    Debug.Trace("[SeverActions_Outfit] EquipMultiple: Equipped '" + foundForm.GetName() + "'")
    return foundForm
EndFunction

Form Function UnequipSingleItemInternal2(Actor akActor, String itemName)
{Search worn items in C++, unequip via Papyrus UnequipItem. Returns the Form removed, or None on failure.}
    String searchName = ResolveItemName(itemName)
    Form foundForm = SeverActionsNative.FindWornItemByName(akActor, searchName)
    if !foundForm && searchName != itemName
        foundForm = SeverActionsNative.FindWornItemByName(akActor, itemName)
    endif
    if !foundForm
        Debug.Trace("[SeverActions_Outfit] UnequipMultiple: '" + itemName + "' not worn")
        return None
    endif

    ; Phase 5: stash unequipped armor in the native Dress session map.
    Armor armorItem = foundForm as Armor
    if armorItem
        SeverActionsNativeExt.Native_Outfit_DressStashAdd(akActor, armorItem)
    endif

    akActor.UnequipItem(foundForm, true, true)
    Debug.Trace("[SeverActions_Outfit] UnequipMultiple: Unequipped '" + foundForm.GetName() + "'")
    return foundForm
EndFunction

Function RemoveFromLockedOutfit(Actor akActor, Form[] removedForms, Int count)
{Phase 4: native-only. Drop specific items from the locked outfit without
 re-snapshotting (avoids the GetWornForm race after async UnequipItem).}
    if !akActor || count == 0
        return
    endif
    if !SeverActionsNativeExt.Native_Outfit_IsLockActive(akActor)
        return
    endif
    Int removed = 0
    Int i = 0
    while i < count
        if removedForms[i]
            SeverActionsNative.Native_Outfit_RemoveLockedItem(akActor, removedForms[i])
            removed += 1
        endif
        i += 1
    endwhile
    if removed > 0
        Debug.Trace("[SeverActions_Outfit] Removed " + removed + " items from outfit lock")
    endif
EndFunction

; =============================================================================
; OUTFIT PERSISTENCE - Lock follower outfits across cell transitions
; Only applies to registered followers (SeverFollower_IsFollower == 1)
; =============================================================================

; =============================================================================
; OUTFIT LOCK SUSPEND / RESUME
; Temporarily disables the OnObjectUnequipped re-equip guard so the outfit
; system can freely swap armor without the alias fighting back.
; Only affects OnObjectUnequipped — OnLoad/OnCellLoad/OnEnable always re-equip.
; =============================================================================

; Phase 5: SuspendWatchdogSeconds is now informational only — the actual
; watchdog (5 min auto-clear via SuspendUntil deadline) lives in
; OutfitDataStore.h. Kept here so old saves with this property don't fail
; to load; setting it from Papyrus no longer affects behaviour.
Float Property SuspendWatchdogSeconds = 300.0 Auto Hidden

Function SuspendOutfitLock(Actor akActor)
    {Phase 5: native-backed. The thread-safe SuspendUntil deadline replaces
     the StorageUtil mirror — instant (no Papyrus VM hop), survives the
     game's async lifecycle correctly, and the 5-minute watchdog now
     self-cleans without Papyrus ever having to check the timestamp.}
    if akActor
        SeverActionsNativeExt.Native_Outfit_SuspendLock(akActor)
    endif
EndFunction

Function BeginAdHocOutfitOp(Actor akActor)
    {Standard entry for any ad-hoc gear change (Undress/Dress/EquipMultiple/
     UnequipMultiple/legacy ApplyOutfitPreset/etc.). Combines the two-step
     ritual every _Execute used to inline: deactivate any active slot preset
     (so the alias's slot enforcement doesn't undo our change), then suspend
     the outfit lock for the duration of the op. Caller pairs with
     ResumeOutfitLock(akActor) on exit.}
    if !akActor
        return
    endif
    SeverActions_OutfitSlot slotSys = GetSlotScript()
    if slotSys
        slotSys.ClearActivePresetForAdHoc(akActor)
    endif
    SuspendOutfitLock(akActor)
EndFunction

Function ResumeOutfitLock(Actor akActor)
    {Phase 5: native-backed. ClearSuspend wipes both the hard flag and any
     pending deadline in a single mutex acquisition — used to be a no-op
     when SetSuspended(false) ran while a SuspendUntil deadline was live.
     Still calls ClearBurstSuppression since that's a separate native flag
     (the burst-strip detector tracks rapid external unequips).}
    if akActor
        SeverActionsNativeExt.Native_Outfit_ResumeLock(akActor)
        SeverActionsNative.Native_Outfit_ClearBurstSuppression(akActor)
    endif
EndFunction

Bool Function IsOutfitOpSuspended(Actor akActor)
    {Phase 5: native-backed. Native_Outfit_IsNativeSuspended already exposed
     the IsSuspended check; we route through it. The watchdog (5 min auto-
     clear) is enforced inside SuspendUntil's deadline, so stale suspends
     can't permanently disable an actor — IsSuspended self-cleans expired
     deadlines on read.}
    if !akActor
        return false
    endif
    return SeverActionsNative.Native_Outfit_IsNativeSuspended(akActor)
EndFunction

; =============================================================================
; OUTFIT LOCK SNAPSHOT & REAPPLY
; =============================================================================

Function SnapshotLockedOutfit(Actor akActor)
    {Snapshot all currently worn armor into a persistent FormList so it can be
     re-applied after cell transitions. Only activates for registered followers.}
    if !akActor
        return
    endif

    ; Master toggle — skip if outfit lock system is disabled
    if !OutfitLockEnabled
        return
    endif

    ; Phase 4: native-only write path. SnapshotLockedOutfit walks worn armor
    ; via Native_Outfit_GetWornArmor and pushes directly into OutfitDataStore
    ; via Begin/Add/CommitLock. No StorageUtil mirror — phase 3 readers
    ; already consume from native.
    Form[] wornArmor = SeverActionsNative.Native_Outfit_GetWornArmor(akActor)
    SeverActionsNative.Native_Outfit_BeginLock(akActor)
    Int count = 0
    If wornArmor
        Int wi = 0
        While wi < wornArmor.Length
            If wornArmor[wi]
                SeverActionsNative.Native_Outfit_AddLockedItem(akActor, wornArmor[wi])
                count += 1
            EndIf
            wi += 1
        EndWhile
    EndIf
    SeverActionsNative.Native_Outfit_CommitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] Locked outfit for " + akActor.GetDisplayName() + " (" + count + " items)")
EndFunction

Function ReapplyLockedOutfit(Actor akActor)
    {Silently re-equip all items from the locked outfit snapshot.
     Called by FollowerManager on cell transitions — no animations.
     Suspends the lock during reapply so OnObjectUnequipped doesn't
     trigger recursive calls when equipping displaces other items.
     Skips re-equip if actor is in an animation framework scene.}
    if !akActor || akActor.IsDead()
        return
    endif

    ; Master toggle — skip if outfit lock system is disabled
    if !OutfitLockEnabled
        return
    endif

    ; Phase 3: native is source of truth for lock state.
    if !SeverActionsNativeExt.Native_Outfit_IsLockActive(akActor)
        return
    endif

    ; Global animation scene flag — set by SexLab/OStim ModEvent hooks
    If AnimationSceneActive
        return
    EndIf

    ; Already mid-operation — don't re-enter. Uses the watchdog-aware check
    ; so a dropped resume ModEvent can't permanently disable reapply.
    if IsOutfitOpSuspended(akActor)
        return
    endif

    ; Phase 4: read locked items from native instead of the StorageUtil mirror.
    Form[] lockedItems = SeverActionsNative.Native_Outfit_GetLockedItems(akActor)
    Int count = 0
    if lockedItems
        count = lockedItems.Length
    endif
    if count == 0
        return
    endif

    ; Bulk strip detection: if NONE of the locked items are currently worn,
    ; another mod stripped everything at once. Yield — don't fight it.
    Int wornCount = 0
    Int checkIdx = 0
    While checkIdx < count
        If lockedItems[checkIdx] && akActor.IsEquipped(lockedItems[checkIdx])
            wornCount += 1
        EndIf
        checkIdx += 1
    EndWhile

    If wornCount == 0 && count >= 1
        Debug.Trace("[SeverActions_Outfit] Bulk strip detected for " + akActor.GetDisplayName() + " — all " + count + " locked items removed. Yielding.")
        return
    EndIf

    SuspendOutfitLock(akActor)

    Int equipped = 0
    int i = 0
    while i < count
        if lockedItems[i]
            akActor.EquipItem(lockedItems[i], false, true)
            equipped += 1
        endif
        i += 1
    endwhile

    ResumeOutfitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] Reapplied locked outfit for " + akActor.GetDisplayName() + " (" + equipped + " items)")
EndFunction

Function ClearLockedOutfit(Actor akActor)
    {Phase 4: native-only. Follower reverts to engine-default behavior.}
    if !akActor
        return
    endif
    SeverActionsNative.Native_Outfit_ClearLock(akActor)
    Debug.Trace("[SeverActions_Outfit] Cleared outfit lock for " + akActor.GetDisplayName())
EndFunction

Function LockEquippedOutfit(Actor akActor, Form[] equippedItems, Int equippedCount)
    {Phase 4: native-only. Lock outfit using ONLY the items we just equipped
     (preset/builder semantics — non-preset gear isn't locked). Writes go
     straight to OutfitDataStore via Begin/Add/CommitLock.}
    if !akActor || !OutfitLockEnabled
        return
    endif

    SeverActionsNative.Native_Outfit_BeginLock(akActor)
    Int written = 0
    Int i = 0
    While i < equippedCount
        if equippedItems[i]
            SeverActionsNative.Native_Outfit_AddLockedItem(akActor, equippedItems[i])
            written += 1
        endif
        i += 1
    EndWhile
    SeverActionsNative.Native_Outfit_CommitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] Locked outfit for " + akActor.GetDisplayName() + " (" + written + " items)")
EndFunction

; =============================================================================
; OUTFIT LOCK ELIGIBILITY
; Determines whether an actor is eligible for outfit lock.
; Covers both registered followers and non-followers with explicit lock flag.
; =============================================================================

Bool Function IsOutfitLockEligible(Actor akActor)
    {Phase 5: native is source of truth for non-follower lock state.
     Eligible if registered follower OR an actor with a non-follower lock
     active in native (isFollowerLock=false AND lockActive=true).}
    if !akActor
        return false
    endif
    if SeverActionsNativeExt.Native_GetIsFollower(akActor)
        return true
    endif
    if HasNonFollowerOutfitLock(akActor)
        return true
    endif
    return false
EndFunction

Function SetNonFollowerOutfitLock(Actor akActor, Bool enable)
    {Phase 5: native-backed. Enable snapshots the worn outfit AND marks
     the actor as non-follower-locked; disable clears the lock entirely.}
    if !akActor
        return
    endif
    if enable
        SnapshotLockedOutfit(akActor)  ; phase 4: native-only write path
        SeverActionsNativeExt.Native_Outfit_SetIsFollowerLock(akActor, false)
        Debug.Trace("[SeverActions_Outfit] Non-follower outfit lock ENABLED for " + akActor.GetDisplayName())
    else
        ClearLockedOutfit(akActor)
        ; ClearLock erases the m_data entry when no presets/situations remain,
        ; so isFollowerLock=false isn't reachable here unless re-enabled.
        Debug.Trace("[SeverActions_Outfit] Non-follower outfit lock DISABLED for " + akActor.GetDisplayName())
    endif
EndFunction

Bool Function HasNonFollowerOutfitLock(Actor akActor)
    {Phase 5: native-backed. True only if lockActive AND not follower-locked.}
    if !akActor
        return false
    endif
    if !SeverActionsNativeExt.Native_Outfit_IsLockActive(akActor)
        return false
    endif
    return !SeverActionsNativeExt.Native_Outfit_IsFollowerLock(akActor)
EndFunction

; =============================================================================
; OUTFIT-LOCKED ACTOR TRACKING
; Maintains a persistent FormList of all actors with active outfit locks.
; Used by FollowerManager.ReassignOutfitSlots() to re-assign alias slots
; after save/load, including dismissed followers who still have locked outfits.
; =============================================================================

; OUTFIT_TRACKED_KEY constant retained — used by Phase 2 importer + nuke
; handler to clear the legacy StorageUtil FormList from old saves. New
; writes go to native exclusively.
String Property OUTFIT_TRACKED_KEY = "SeverOutfit_TrackedActors" AutoReadOnly Hidden

Function TrackOutfitLockedActor(Actor akActor)
    {Phase 4: no-op. Native OutfitDataStore is the source of truth for which
     actors have active locks. Function kept callable so existing internal
     callers (LockEquippedOutfit, SnapshotLockedOutfit) compile unchanged
     while Phase 4 lands; subsequent phases delete the call sites.}
EndFunction

Function UntrackOutfitLockedActor(Actor akActor)
    {Phase 4: no-op. See TrackOutfitLockedActor.}
EndFunction

Actor[] Function GetOutfitLockedActors()
    {Phase 4: native is source of truth. Returns every actor in
     OutfitDataStore with lockActive=true. Used by FollowerManager's slot
     reassignment after save/load.}
    return SeverActionsNativeExt.Native_Outfit_GetActorsWithLocks()
EndFunction

; =============================================================================
; OUTFIT PRESET UTILITIES
; Query and manage saved outfit presets for MCM display
; =============================================================================

String[] Function GetPresetNames(Actor akActor)
    {Phase 4: native-only. Returns user-visible preset names (skips internal
     "_"-prefixed entries like "_default" that the situation system uses as
     an auto-saved baseline).}
    if !akActor
        return PapyrusUtil.StringArray(0)
    endif
    Int count = SeverActionsNative.Native_Outfit_GetPresetCount(akActor)
    if count <= 0
        return PapyrusUtil.StringArray(0)
    endif
    ; First pass: count visible names so we can size the result.
    Int visibleCount = 0
    Int i = 0
    While i < count
        String name = SeverActionsNative.Native_Outfit_GetPresetNameAt(akActor, i)
        If name != "" && StringUtil.GetNthChar(name, 0) != "_"
            visibleCount += 1
        EndIf
        i += 1
    EndWhile
    String[] result = PapyrusUtil.StringArray(visibleCount)
    Int ri = 0
    i = 0
    While i < count
        String name = SeverActionsNative.Native_Outfit_GetPresetNameAt(akActor, i)
        If name != "" && StringUtil.GetNthChar(name, 0) != "_"
            result[ri] = name
            ri += 1
        EndIf
        i += 1
    EndWhile
    return result
EndFunction

Int Function GetPresetItemCount(Actor akActor, String presetName)
    {Phase 4: native-only. Returns the number of items in a saved preset, 0
     if not found.}
    if !akActor || presetName == ""
        return 0
    endif
    Form[] items = SeverActionsNative.Native_Outfit_GetPresetItems(akActor, presetName)
    if items
        return items.Length
    endif
    return 0
EndFunction

Function DeletePreset(Actor akActor, String presetName)
    {Phase 4: native-only. Deletes from OutfitDataStore (which also sweeps
     stale activePresetName + situationPresets pointing at the deleted name —
     see Phase 1 B-NEW-7 fix) and from the slot system. Drops the legacy
     StorageUtil preset/presetActors writes.}
    if !akActor || presetName == ""
        return
    endif
    presetName = NormalizePresetName(presetName)
    if presetName == ""
        return
    endif

    SeverActionsNative.Native_Outfit_DeletePreset(akActor, presetName)

    SeverActions_OutfitSlot slotSys = GetSlotScript()
    if slotSys
        slotSys.DeletePresetFromSlot(akActor, presetName)
    endif

    ; If no presets remain natively, also drop non-follower lock if any.
    if SeverActionsNative.Native_Outfit_GetPresetCount(akActor) <= 0
        if HasNonFollowerOutfitLock(akActor)
            SetNonFollowerOutfitLock(akActor, false)
        endif
    endif

    Debug.Trace("[SeverActions_Outfit] DeletePreset: Deleted '" + presetName + "' for " + akActor.GetDisplayName())
EndFunction

; =============================================================================
; SavePresetToNativeStore — resilience mirror for slot-system BuildPreset
; Called by SeverActions_OutfitSlot.BuildPreset to dual-write into OutfitDataStore
; so that slot-built presets survive slot-cosave drops (e.g. version bumps).
; =============================================================================

Function SavePresetToNativeStore(Actor akActor, String presetName, Form[] items, Int itemCount)
    {Mirror a slot-built preset into the native OutfitDataStore (record 'OTFT').
     Uses the BeginPreset/AddPresetItem/CommitPreset pattern. Silent on errors.}
    if !akActor || presetName == ""
        return
    endif

    SeverActionsNative.Native_Outfit_BeginPreset(akActor, presetName)
    Int i = 0
    While i < itemCount
        if items[i]
            SeverActionsNative.Native_Outfit_AddPresetItem(akActor, items[i])
        endif
        i += 1
    EndWhile
    SeverActionsNative.Native_Outfit_CommitPreset(akActor)
EndFunction

; =============================================================================
; MIGRATION: StorageUtil → Native OutfitDataStore
; One-time migration for existing saves. Called from SeverActions_Init on load.
; Safe to call multiple times (idempotent — re-pushes current StorageUtil state).
; =============================================================================

Function MigrateOutfitDataToNative()
    {Phase 2 versioned importer. Reads outfit state from legacy StorageUtil and
     pushes into native OutfitDataStore where native is empty. Native always
     wins on conflict — every disagreement logs an [OutfitMigration] line so
     we have evidence of what differed before the legacy store goes away in
     Phase 6.

     Gated on the native cosave schemaVersion (NOT the old
     SeverOutfit_MigrationVersion StorageUtil flag, which couldn't survive a
     wipe of the legacy store). schemaVersion=0 → run. >=1 → skip.}

    ; Phase 5 bumps to v3 — also imports SeverOutfit_NonFollowerLock into the
    ; new native isFollowerLock field (default true; set false where the
    ; legacy flag was 1).
    Int schemaVer = SeverActionsNativeExt.Native_Outfit_GetSchemaVersion()
    if schemaVer >= 3
        Debug.Trace("[OutfitMigration] schemaVersion=" + schemaVer + " — already imported, skipping")
        return
    endif

    Debug.Trace("[OutfitMigration] schemaVersion=0 — starting native-wins import")
    Int importedLocks = 0
    Int skippedLocks = 0
    Int importedPresets = 0
    Int skippedPresets = 0
    Int importedSituations = 0
    Int skippedSituations = 0

    ; --- Locked outfits ---
    ; Phase 4: must read directly from the legacy StorageUtil FormList rather
    ; than GetOutfitLockedActors() (which now returns native). The whole point
    ; of the importer is to surface actors that exist in legacy storage but
    ; not yet in native.
    Int trackedCount = StorageUtil.FormListCount(None, OUTFIT_TRACKED_KEY)
    Actor[] lockedActors = PapyrusUtil.ActorArray(0)
    Int ti = 0
    While ti < trackedCount
        Actor trackedA = StorageUtil.FormListGet(None, OUTFIT_TRACKED_KEY, ti) as Actor
        if trackedA && !trackedA.IsDead()
            lockedActors = PapyrusUtil.PushActor(lockedActors, trackedA)
        endif
        ti += 1
    EndWhile
    Int i = 0
    While i < lockedActors.Length
        Actor akActor = lockedActors[i]
        if akActor
            if SeverActionsNativeExt.Native_Outfit_IsLockActive(akActor)
                ; Native already has a lock for this actor. Skip — native wins.
                ; Log the size delta so we have evidence of what we left behind.
                String lockKey = "SeverOutfit_Locked_" + (akActor.GetFormID() as String)
                Int storageLockCount = StorageUtil.FormListCount(None, lockKey)
                Form[] nativeLocked = SeverActionsNative.Native_Outfit_GetLockedItems(akActor)
                Int nativeLockCount = 0
                if nativeLocked
                    nativeLockCount = nativeLocked.Length
                endif
                if storageLockCount != nativeLockCount
                    Debug.Trace("[OutfitMigration] " + akActor.GetDisplayName() + " lock: native wins (storage=" + storageLockCount + " items, native=" + nativeLockCount + " items)")
                endif
                skippedLocks += 1
            else
                ; Native is empty — import from StorageUtil.
                String lockKey = "SeverOutfit_Locked_" + (akActor.GetFormID() as String)
                Int lockCount = StorageUtil.FormListCount(None, lockKey)
                if lockCount > 0
                    SeverActionsNative.Native_Outfit_BeginLock(akActor)
                    Int k = 0
                    While k < lockCount
                        Form item = StorageUtil.FormListGet(None, lockKey, k)
                        if item
                            SeverActionsNative.Native_Outfit_AddLockedItem(akActor, item)
                        endif
                        k += 1
                    EndWhile
                    SeverActionsNative.Native_Outfit_CommitLock(akActor)
                    importedLocks += 1
                    Debug.Trace("[OutfitMigration] " + akActor.GetDisplayName() + " lock imported: " + lockCount + " items")
                endif
            endif

            ; --- Presets for this actor ---
            ; Phase 4: GetPresetNames now returns native. Read legacy StorageUtil
            ; StringList directly so the importer surfaces any presets that
            ; exist ONLY in the mirror.
            String _legacyPresetsListKey = "SeverOutfit_Presets_" + (akActor.GetFormID() as String)
            Int _legacyNameCount = StorageUtil.StringListCount(None, _legacyPresetsListKey)
            String[] presetNames = PapyrusUtil.StringArray(_legacyNameCount)
            Int _lpi = 0
            While _lpi < _legacyNameCount
                presetNames[_lpi] = StorageUtil.StringListGet(None, _legacyPresetsListKey, _lpi)
                _lpi += 1
            EndWhile
            Int p = 0
            While p < presetNames.Length
                if presetNames[p] != ""
                    Form[] nativePreset = SeverActionsNative.Native_Outfit_GetPresetItems(akActor, presetNames[p])
                    Bool nativeHasIt = nativePreset && nativePreset.Length > 0
                    if nativeHasIt
                        skippedPresets += 1
                        Debug.Trace("[OutfitMigration] " + akActor.GetDisplayName() + " preset '" + presetNames[p] + "': native wins (" + nativePreset.Length + " items, storage had " + StorageUtil.FormListCount(None, "SeverOutfit_" + presetNames[p] + "_" + (akActor.GetFormID() as String)) + ")")
                    else
                        String presetKey = "SeverOutfit_" + presetNames[p] + "_" + (akActor.GetFormID() as String)
                        Int pCount = StorageUtil.FormListCount(None, presetKey)
                        if pCount > 0
                            SeverActionsNative.Native_Outfit_BeginPreset(akActor, presetNames[p])
                            Int pk = 0
                            While pk < pCount
                                Form pItem = StorageUtil.FormListGet(None, presetKey, pk)
                                if pItem
                                    SeverActionsNative.Native_Outfit_AddPresetItem(akActor, pItem)
                                endif
                                pk += 1
                            EndWhile
                            SeverActionsNative.Native_Outfit_CommitPreset(akActor)
                            importedPresets += 1
                            Debug.Trace("[OutfitMigration] " + akActor.GetDisplayName() + " preset '" + presetNames[p] + "' imported: " + pCount + " items")
                        endif
                    endif
                endif
                p += 1
            EndWhile
        endif
        i += 1
    EndWhile

    ; --- Preset-only actors (not locked but have presets) ---
    ; Phase 4: read legacy StorageUtil PresetActors directly (GetPresetActors
    ; now returns native, which would miss any actors that exist only in the
    ; legacy mirror).
    Int presetActorsCount = StorageUtil.FormListCount(None, "SeverOutfit_PresetActors")
    Actor[] presetActors = PapyrusUtil.ActorArray(0)
    Int pai = 0
    While pai < presetActorsCount
        Actor paA = StorageUtil.FormListGet(None, "SeverOutfit_PresetActors", pai) as Actor
        if paA && !paA.IsDead()
            presetActors = PapyrusUtil.PushActor(presetActors, paA)
        endif
        pai += 1
    EndWhile
    Int j = 0
    While j < presetActors.Length
        Actor pActor = presetActors[j]
        if pActor
            Bool alreadyVisited = false
            Int li = 0
            While li < lockedActors.Length && !alreadyVisited
                if lockedActors[li] == pActor
                    alreadyVisited = true
                endif
                li += 1
            EndWhile

            if !alreadyVisited
                ; Phase 4: read legacy StorageUtil StringList directly (same
                ; reasoning as the sibling loop above).
                String _legacyPresetsListKeyP = "SeverOutfit_Presets_" + (pActor.GetFormID() as String)
                Int _legacyNameCountP = StorageUtil.StringListCount(None, _legacyPresetsListKeyP)
                String[] presetNames = PapyrusUtil.StringArray(_legacyNameCountP)
                Int _lpiP = 0
                While _lpiP < _legacyNameCountP
                    presetNames[_lpiP] = StorageUtil.StringListGet(None, _legacyPresetsListKeyP, _lpiP)
                    _lpiP += 1
                EndWhile
                Int p = 0
                While p < presetNames.Length
                    if presetNames[p] != ""
                        Form[] nativePreset = SeverActionsNative.Native_Outfit_GetPresetItems(pActor, presetNames[p])
                        Bool nativeHasIt = nativePreset && nativePreset.Length > 0
                        if nativeHasIt
                            skippedPresets += 1
                        else
                            String presetKey = "SeverOutfit_" + presetNames[p] + "_" + (pActor.GetFormID() as String)
                            Int pCount = StorageUtil.FormListCount(None, presetKey)
                            if pCount > 0
                                SeverActionsNative.Native_Outfit_BeginPreset(pActor, presetNames[p])
                                Int pk = 0
                                While pk < pCount
                                    Form pItem = StorageUtil.FormListGet(None, presetKey, pk)
                                    if pItem
                                        SeverActionsNative.Native_Outfit_AddPresetItem(pActor, pItem)
                                    endif
                                    pk += 1
                                EndWhile
                                SeverActionsNative.Native_Outfit_CommitPreset(pActor)
                                importedPresets += 1
                                Debug.Trace("[OutfitMigration] " + pActor.GetDisplayName() + " preset '" + presetNames[p] + "' imported (preset-only actor): " + pCount + " items")
                            endif
                        endif
                    endif
                    p += 1
                EndWhile
            endif
        endif
        j += 1
    EndWhile

    ; --- Situation data + active preset name + auto-switch (per-actor) ---
    ; Build the union of locked + preset actors so we cover every actor with state.
    Actor[] allActors = PapyrusUtil.ActorArray(0)
    Int ai = 0
    While ai < lockedActors.Length
        if lockedActors[ai]
            allActors = PapyrusUtil.PushActor(allActors, lockedActors[ai])
        endif
        ai += 1
    EndWhile
    ai = 0
    While ai < presetActors.Length
        if presetActors[ai]
            Bool found = false
            Int ci = 0
            While ci < allActors.Length && !found
                if allActors[ci] == presetActors[ai]
                    found = true
                endif
                ci += 1
            EndWhile
            if !found
                allActors = PapyrusUtil.PushActor(allActors, presetActors[ai])
            endif
        endif
        ai += 1
    EndWhile

    ; Must match the 7 canonical keys in NormalizeSituation.
    String[] situations = new String[7]
    situations[0] = "adventure"
    situations[1] = "town"
    situations[2] = "home"
    situations[3] = "sleep"
    situations[4] = "combat"
    situations[5] = "rain"
    situations[6] = "snow"

    ai = 0
    While ai < allActors.Length
        Actor akActor = allActors[ai]
        if akActor
            ; Active preset name — only import if native is empty.
            String nativeActive = SeverActionsNative.Native_Outfit_GetActivePreset(akActor)
            String storageActive = StorageUtil.GetStringValue(akActor, "SeverOutfit_ActivePreset", "")
            if nativeActive == "" && storageActive != ""
                SeverActionsNative.Native_Outfit_SetActivePreset(akActor, storageActive)
                Debug.Trace("[OutfitMigration] " + akActor.GetDisplayName() + " activePreset imported: '" + storageActive + "'")
            elseif nativeActive != "" && storageActive != "" && nativeActive != storageActive
                Debug.Trace("[OutfitMigration] " + akActor.GetDisplayName() + " activePreset: native wins (native='" + nativeActive + "' storage='" + storageActive + "')")
            endif

            ; Current situation
            String nativeSit = SeverActionsNative.Native_Outfit_GetCurrentSituation(akActor)
            String storageSit = StorageUtil.GetStringValue(akActor, "SeverOutfit_CurrentSituation", "")
            if nativeSit == "" && storageSit != ""
                SeverActionsNative.Native_Outfit_SetCurrentSituation(akActor, storageSit)
                Debug.Trace("[OutfitMigration] " + akActor.GetDisplayName() + " currentSituation imported: '" + storageSit + "'")
            elseif nativeSit != "" && storageSit != "" && nativeSit != storageSit
                Debug.Trace("[OutfitMigration] " + akActor.GetDisplayName() + " currentSituation: native wins (native='" + nativeSit + "' storage='" + storageSit + "')")
            endif

            ; Per-situation preset mappings (all 7 canonical keys)
            Int si = 0
            While si < situations.Length
                String storageMap = StorageUtil.GetStringValue(akActor, "SeverOutfit_Sit_" + situations[si], "")
                if storageMap != ""
                    if SeverActionsNativeExt.Native_Outfit_HasSituationPreset(akActor, situations[si])
                        skippedSituations += 1
                        String nativeMap = SeverActionsNative.Native_Outfit_GetSituationPreset(akActor, situations[si])
                        if nativeMap != storageMap
                            Debug.Trace("[OutfitMigration] " + akActor.GetDisplayName() + " sit_" + situations[si] + ": native wins (native='" + nativeMap + "' storage='" + storageMap + "')")
                        endif
                    else
                        SeverActionsNative.Native_Outfit_SetSituationPreset(akActor, situations[si], storageMap)
                        importedSituations += 1
                    endif
                endif
                si += 1
            EndWhile

            ; Per-actor auto-switch. Default is true on native; only flip if
            ; StorageUtil explicitly recorded false. We can't distinguish "user
            ; turned auto-switch off" from "never set" beyond the StorageUtil
            ; presence check; this conservative path only writes when StorageUtil
            ; carries a definite 0.
            Int autoSwitchVal = StorageUtil.GetIntValue(akActor, "SeverOutfit_AutoSwitch", -1)
            if autoSwitchVal == 0
                if SeverActionsNative.Native_Outfit_GetAutoSwitchEnabled(akActor)
                    SeverActionsNative.Native_Outfit_SetAutoSwitchEnabled(akActor, false)
                    Debug.Trace("[OutfitMigration] " + akActor.GetDisplayName() + " autoSwitch imported: false")
                endif
            endif
        endif
        ai += 1
    EndWhile

    ; Phase 5: import legacy SeverOutfit_NonFollowerLock for every actor we
    ; touched above (locked + preset-owning union). Only writes where the
    ; legacy flag was set — default isFollowerLock=true otherwise.
    Int nflImported = 0
    Int nfi = 0
    While nfi < allActors.Length
        Actor nfActor = allActors[nfi]
        if nfActor
            Int legacyNFL = StorageUtil.GetIntValue(nfActor, "SeverOutfit_NonFollowerLock", 0)
            if legacyNFL == 1
                SeverActionsNativeExt.Native_Outfit_SetIsFollowerLock(nfActor, false)
                nflImported += 1
                Debug.Trace("[OutfitMigration] " + nfActor.GetDisplayName() + " isFollowerLock=false (legacy non-follower lock)")
            endif
        endif
        nfi += 1
    EndWhile

    ; Bump native schema version to 3 (Phase 5). Cosave persists this;
    ; subsequent loads short-circuit at the top.
    SeverActionsNativeExt.Native_Outfit_SetSchemaVersion(3)

    ; Don't bother clearing the old StorageUtil version key — Phase 6 nukes
    ; the entire SeverOutfit_* keyspace anyway. Leaving it in place keeps
    ; downgrade safety: an older DLL would still see the old gate and skip
    ; (though we have no intention of downgrading).

    Debug.Trace("[OutfitMigration] Done. imported=[locks:" + importedLocks + ", presets:" + importedPresets + ", situations:" + importedSituations + ", non-follower-locks:" + nflImported + "] native-wins-skipped=[locks:" + skippedLocks + ", presets:" + skippedPresets + ", situations:" + skippedSituations + "]")
EndFunction

Actor[] Function GetPresetActors()
    {Phase 4: native-only. Returns every actor with at least one user-visible
     preset in OutfitDataStore. Used by MCM Outfits page.}
    return SeverActionsNative.Native_Outfit_GetActorsWithPresets()
EndFunction


; =============================================================================
; HELPER FUNCTIONS
; =============================================================================

String Function GetSlotNameFromMask(int slotMask)
    if Math.LogicalAnd(slotMask, 0x00000001) > 0
        return "helmet"
    elseif Math.LogicalAnd(slotMask, 0x00000004) > 0
        return "body"
    elseif Math.LogicalAnd(slotMask, 0x00000008) > 0
        return "hands"
    elseif Math.LogicalAnd(slotMask, 0x00000080) > 0
        return "feet"
    elseif Math.LogicalAnd(slotMask, 0x00000020) > 0
        return "neck"
    elseif Math.LogicalAnd(slotMask, 0x00000040) > 0
        return "ring"
    elseif Math.LogicalAnd(slotMask, 0x00000400) > 0 || Math.LogicalAnd(slotMask, 0x00010000) > 0 || Math.LogicalAnd(slotMask, 0x00020000) > 0 || Math.LogicalAnd(slotMask, 0x08000000) > 0
        return "cloak"
    endif
    return "body"
EndFunction

String[] Function ParseCSVTrim(String csv)
{Split a comma-separated string into trimmed non-empty tokens. Caps at 32
 to match the storage limits used by callers (preset/lock FormLists).
 Extracted from a loop that used to be inlined identically in both
 EquipMultipleItems_Execute and UnequipMultipleItems_Execute.}
    String[] tmp = PapyrusUtil.StringArray(32)
    Int outCount = 0
    if csv == ""
        return PapyrusUtil.StringArray(0)
    endif

    Int len = StringUtil.GetLength(csv)
    Int startPos = 0
    Int commaPos = StringUtil.Find(csv, ",", startPos)
    while startPos < len && outCount < 32
        String token
        if commaPos >= 0
            token = StringUtil.Substring(csv, startPos, commaPos - startPos)
            startPos = commaPos + 1
            commaPos = StringUtil.Find(csv, ",", startPos)
        else
            token = StringUtil.Substring(csv, startPos)
            startPos = len
        endif
        token = TrimString(token)
        if token != ""
            tmp[outCount] = token
            outCount += 1
        endif
    endwhile

    if outCount == 0
        return PapyrusUtil.StringArray(0)
    endif
    String[] result = PapyrusUtil.StringArray(outCount)
    Int ci = 0
    while ci < outCount
        result[ci] = tmp[ci]
        ci += 1
    endwhile
    return result
EndFunction

String Function TrimString(String text)
{Remove leading and trailing spaces from a string}
    Int len = StringUtil.GetLength(text)
    if len == 0
        return ""
    endif
    Int startIdx = 0
    while startIdx < len && StringUtil.Substring(text, startIdx, 1) == " "
        startIdx += 1
    endwhile
    Int endIdx = len - 1
    while endIdx > startIdx && StringUtil.Substring(text, endIdx, 1) == " "
        endIdx -= 1
    endwhile
    if startIdx > endIdx
        return ""
    endif
    return StringUtil.Substring(text, startIdx, endIdx - startIdx + 1)
EndFunction

String Function StringToLower(String text)
    ; Native implementation: ~2000-10000x faster
    return SeverActionsNative.StringToLower(text)
EndFunction

String Function NormalizePresetName(String name)
{Strip common trailing words that LLMs append to preset names.
 "travel outfit" → "travel", "combat gear" → "combat", "formal clothes" → "formal"
 Already-clean names like "travel" pass through unchanged.}
    name = TrimString(StringToLower(name))
    Int len = StringUtil.GetLength(name)
    if len == 0
        return ""
    endif

    ; Suffixes to strip (longest first to avoid partial matches)
    String[] suffixes = new String[6]
    suffixes[0] = " clothes"
    suffixes[1] = " outfit"
    suffixes[2] = " attire"
    suffixes[3] = " armor"
    suffixes[4] = " gear"
    suffixes[5] = " set"

    Int i = 0
    while i < suffixes.Length
        Int suffixLen = StringUtil.GetLength(suffixes[i])
        if len > suffixLen
            String tail = StringUtil.Substring(name, len - suffixLen, suffixLen)
            if tail == suffixes[i]
                name = TrimString(StringUtil.Substring(name, 0, len - suffixLen))
                return name
            endif
        endif
        i += 1
    endwhile

    return name
EndFunction

; =============================================================================
; SITUATION-BASED OUTFIT SYSTEM
; =============================================================================

String Function NormalizeSituation(String situation)
{Normalize LLM-provided situation names to canonical values.
 "city" → "town", "dungeon" → "adventure", "sleeping" → "sleep", etc.}
    situation = TrimString(StringToLower(situation))
    if situation == "city" || situation == "village" || situation == "settlement" || situation == "urban"
        return "town"
    elseif situation == "outdoor" || situation == "outdoors" || situation == "dungeon" || situation == "exploring" \
        || situation == "adventuring" || situation == "wilderness" || situation == "wild"
        return "adventure"
    elseif situation == "sleeping" || situation == "bed" || situation == "rest" || situation == "resting" \
        || situation == "bedtime" || situation == "night"
        return "sleep"
    elseif situation == "fight" || situation == "fighting" || situation == "battle" || situation == "combat"
        return "combat"
    elseif situation == "house" || situation == "dwelling" || situation == "residence"
        return "home"
    elseif situation == "rainy" || situation == "raining" || situation == "storm" || situation == "stormy"
        return "rain"
    elseif situation == "snowy" || situation == "snowing" || situation == "blizzard" || situation == "cold"
        return "snow"
    endif
    return situation
EndFunction

Function SetSituationPreset_Execute(Actor akActor, String situation, String presetName)
{LLM action: Assign an outfit preset to a situation.}
    if !akActor || situation == "" || presetName == ""
        return
    endif
    situation = NormalizeSituation(situation)
    presetName = NormalizePresetName(presetName)

    ; ── Slot system dual-write ──
    SeverActions_OutfitSlot slotSys = GetSlotScript()
    If slotSys
        Int sitPresetIdx = slotSys.FindPresetIndexByName(akActor, presetName)
        If sitPresetIdx >= 0
            SeverActionsNative.Native_OutfitSlot_SetSituationPreset(akActor, situation, sitPresetIdx)
            Debug.Trace("[SeverActions_Outfit] SetSituationPreset(slot): " + situation + " -> idx " + sitPresetIdx + " ('" + presetName + "')")
        EndIf
    EndIf

    ; ── Legacy native preset path (OutfitDataStore situation→preset map) ──
    ; C2 fix: the legacy "preset exists" gate previously read a StorageUtil
    ; key that Phase 4 stopped writing — meaning new situation assignments
    ; for legacy-store presets silently never persisted. Switch to the
    ; native source of truth: Native_Outfit_GetPresetItems returns the
    ; preset's form list (zero-length array if absent).
    Form[] legacyItems = SeverActionsNative.Native_Outfit_GetPresetItems(akActor, presetName)
    if legacyItems.Length == 0
        ; Slot system handled it (if slotSys branch fired) or preset doesn't
        ; exist in either store. Either way, nothing for the legacy path.
        Debug.Trace("[SeverActions_Outfit] SetSituationPreset: '" + presetName + "' not in legacy native store (slot system path applies, or preset unknown)")
        return
    endif

    SeverActionsNative.Native_Outfit_SetSituationPreset(akActor, situation, presetName)
    Debug.Trace("[SeverActions_Outfit] SetSituationPreset: " + akActor.GetDisplayName() + " — " + situation + " → " + presetName)
EndFunction

Function ClearSituationPreset_Execute(Actor akActor, String situation)
{LLM action: Clear the preset assignment for a situation.}
    if !akActor || situation == ""
        return
    endif
    situation = NormalizeSituation(situation)

    ; ── Slot system ──
    SeverActionsNative.Native_OutfitSlot_SetSituationPreset(akActor, situation, -1)

    ; Phase 4: native-only.
    SeverActionsNative.Native_Outfit_ClearSituationPreset(akActor, situation)
    Debug.Trace("[SeverActions_Outfit] ClearSituationPreset: " + akActor.GetDisplayName() + " — cleared " + situation)
EndFunction

; Phase 1 parity sweep removed in Phase 4. With native as the single source
; of truth, there is no second store to compare against.

; =============================================================================
; MAINTENANCE — called from SeverActions_Init on every game load
; Registers for ModEvents that drive the situation auto-switch system.
; =============================================================================

Function Maintenance()
    RegisterForModEvent("SeverActions_SituationChanged", "OnSituationChanged")
    RegisterForModEvent("SeverActions_CatalogEquipLock", "OnCatalogEquipLock")
    ; PrismaUI outfit ModEvents — replaces DispatchMethodCall which silently fails
    RegisterForModEvent("SeverActions_PrismaSnapshot", "OnPrismaSnapshot")
    RegisterForModEvent("SeverActions_PrismaClearLock", "OnPrismaClearLock")
    RegisterForModEvent("SeverActions_PrismaClearAllPresets", "OnPrismaClearAllPresets")
    RegisterForModEvent("SeverActions_PrismaApplyPreset", "OnPrismaApplyPreset")
    ; V2 event bypasses stale cached handler in older saves
    RegisterForModEvent("SeverActions_PrismaApplyPresetV2", "OnPrismaApplyPresetV2")
    RegisterForModEvent("SeverActions_PrismaDeletePreset", "OnPrismaDeletePreset")
    RegisterForModEvent("SeverActions_PrismaSavePreset", "OnPrismaSavePreset")
    RegisterForModEvent("SeverActions_PrismaNukeOutfit", "OnPrismaNukeOutfit")
    RegisterForModEvent("SeverActions_PrismaSetSitPreset", "OnPrismaSetSitPreset")
    RegisterForModEvent("SeverActions_PrismaClearSitPreset", "OnPrismaClearSitPreset")
    ; PrismaUI auto-switch sync — fires when PrismaUI toggles global or per-actor setting
    RegisterForModEvent("SeverActions_PrismaToggleAutoSwitch", "OnPrismaToggleAutoSwitch")
    RegisterForModEvent("SeverActions_PrismaToggleActorAutoSwitch", "OnPrismaToggleActorAutoSwitch")
    ; PrismaUI inventory transfer — sync outfit lock StorageUtil after C++ transfers an equipped item
    RegisterForModEvent("SeverActions_PrismaInventorySync", "OnPrismaInventorySync")
    ; PrismaUI Builder equip — sync StorageUtil lock FormList from native store
    RegisterForModEvent("SeverActions_PrismaBuilderEquip", "OnPrismaBuilderEquip")
    ; PrismaUI Builder save-and-apply — same sync as Builder equip BUT preserves
    ; the active preset name (the auto-apply path commits to a named preset, not
    ; an ad-hoc manual outfit, so SituationMonitor's "already wearing X" check
    ; needs the name intact).
    RegisterForModEvent("SeverActions_PrismaBuilderSaveAndApply", "OnPrismaBuilderSaveAndApply")
    ; PrismaUI Builder save preset — sync preset to StorageUtil from native store
    RegisterForModEvent("SeverActions_PrismaBuilderSavePreset", "OnPrismaBuilderSavePreset")
    RegisterForModEvent("SeverActions_PrismaBuilderRenamePreset", "OnPrismaBuilderRenamePreset")
    ; PrismaUI clear lock for builder — clears Papyrus FormList when builder opens
    RegisterForModEvent("SeverActions_PrismaClearLockForBuilder", "OnPrismaClearLockForBuilder")
    ; PrismaUI resume lock — clears Papyrus suspend when builder closes
    RegisterForModEvent("SeverActions_PrismaResumeLock", "OnPrismaResumeLock")
    ; PrismaUI ad-hoc clear slot preset — fired by C++ catalog Equip & Lock /
    ; Unequip paths so the alias's slot-preset enforcement doesn't fight an
    ; ad-hoc change. Mirrors Papyrus ClearActivePresetForAdHoc.
    RegisterForModEvent("SeverActions_PrismaAdHocClearSlotPreset", "OnPrismaAdHocClearSlotPreset")
    ; Fired by PrismaUISettingsHandler when a user marks an actor outfit-excluded.
    ; C++ has already cleared the native lock; we need to clear the StorageUtil
    ; mirror so the alias short-circuit (which reads LockActive) sees consistent
    ; state. Previously this event was emitted with no handler — silent drift.
    RegisterForModEvent("SeverActions_OutfitExcluded", "OnOutfitExcluded")

    ; Animation framework hooks — suspend outfit lock during scenes
    ; SexLab: global hooks fire for ALL scenes (no local hook suffix needed)
    RegisterForModEvent("HookAnimationStart", "OnSexLabSceneStart")
    RegisterForModEvent("HookAnimationEnd", "OnSexLabSceneEnd")
    ; OStim: global scene start/end events
    RegisterForModEvent("ostim_start", "OnOStimSceneStart")
    RegisterForModEvent("ostim_end", "OnOStimSceneEnd")

    ; Restore global auto-switch from StorageUtil (persists across game loads)
    ; SituationMonitor.m_enabled is RAM-only — resets to true on DLL load.
    ; StorageUtil is our persistence layer: 1 = enabled, 0 = disabled, default = 1
    Bool savedAutoSwitch = StorageUtil.GetIntValue(None, "SeverOutfit_GlobalAutoSwitch", 1) as Bool
    SeverActionsNativeExt.SituationMonitor_SetEnabled(savedAutoSwitch)

    ; Phase 4: Parity sweep retired. With native as the sole source of truth
    ; for lock/preset/situation state and the dual-write writers gone, there's
    ; no second store to compare against. ParityCheck_Sweep + ParityCheck_Actor
    ; + ParityCheckIntervalSeconds + OnUpdate event are all gone with this
    ; phase. If post-migration drift surfaces, it now means a single-source
    ; bug — easier to localize.

    Debug.Trace("[SeverActions_Outfit] Maintenance: Registered for SituationChanged, CatalogEquipLock, PrismaUI outfit events, and global auto-switch sync. AutoSwitch restored: " + savedAutoSwitch)

    ; Phase 5: one-time cleanup of stale StorageUtil suspend keys. Old saves
    ; may have SeverOutfit_Suspended / SeverOutfit_SuspendedAt left over from
    ; the StorageUtil-mirrored era — if a player crashed mid-builder before
    ; this migration shipped, those keys are still set on whichever actor
    ; the session was for. The new native-backed Suspend/Resume doesn't read
    ; them, but they'd persist in the cosave forever otherwise. Sweep them
    ; out here. Idempotent — no-op once cleared. Gated by a one-shot per-save
    ; marker so we don't iterate the actor list on every save load.
    ;
    ; Iterates Native_Outfit_GetAllTrackedActors (NOT GetActorsWithLocks) —
    ; we want to clean stale keys even on actors whose locks have since been
    ; cleared (e.g. dismissed followers, NPCs the user explicitly unlocked).
    ; That set is a strict superset and includes every actor the outfit
    ; system has ever tracked.
    Int cleanupDone = StorageUtil.GetIntValue(None, "SeverActions_OutfitSuspendCleanupDone", 0)
    if cleanupDone == 0
        Actor[] tracked = SeverActionsNativeExt.Native_Outfit_GetAllTrackedActors()
        Int cleared = 0
        if tracked
            Int ti = 0
            While ti < tracked.Length
                if tracked[ti]
                    if StorageUtil.GetIntValue(tracked[ti], "SeverOutfit_Suspended", 0) != 0
                        StorageUtil.UnsetIntValue(tracked[ti], "SeverOutfit_Suspended")
                        cleared += 1
                    endif
                    if StorageUtil.GetFloatValue(tracked[ti], "SeverOutfit_SuspendedAt", 0.0) != 0.0
                        StorageUtil.UnsetFloatValue(tracked[ti], "SeverOutfit_SuspendedAt")
                    endif
                endif
                ti += 1
            EndWhile
        endif
        StorageUtil.SetIntValue(None, "SeverActions_OutfitSuspendCleanupDone", 1)
        Debug.Trace("[SeverActions_Outfit] Phase 5: cleaned " + cleared + " stale StorageUtil suspend key(s) — now using native SuspendUntil")
    endif
EndFunction

; =============================================================================
; EVENT: OnSituationChanged
; Fired by SituationMonitor (native C++) when a follower's detected situation
; has been stable for the configured threshold (default 5 seconds).
; Applies the mapped outfit preset if one is assigned.
; =============================================================================

Event OnSituationChanged(String eventName, String strArg, Float numArg, Form sender)
    ; strArg format: "situation|0xFormID" (packed to avoid float precision loss)
    Int pipePos = StringUtil.Find(strArg, "|")
    if pipePos < 0
        return
    endif
    String situation = StringUtil.Substring(strArg, 0, pipePos)
    String formIdStr = StringUtil.Substring(strArg, pipePos + 1)
    Int formId = SeverActionsNative.HexToInt(formIdStr)
    Actor akActor = Game.GetForm(formId) as Actor
    if !akActor
        return
    endif

    ; Don't fight builder or other outfit operations in progress
    If IsOutfitOpSuspended(akActor)
        Return
    EndIf

    ; ── Slot system path first (if actor has a slot, it owns the situation routing) ──
    SeverActions_OutfitSlot slotSys = GetSlotScript()
    If slotSys && SeverActionsNative.Native_OutfitSlot_GetSlot(akActor) >= 0
        Int sitPresetIdx = SeverActionsNative.Native_OutfitSlot_GetSituationPreset(akActor, situation)
        If sitPresetIdx >= 0 && SeverActionsNative.Native_OutfitSlot_GetAutoSwitch(akActor)
            Int currentActive = SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor)
            If currentActive != sitPresetIdx
                slotSys.OnSituationChangedForActor(akActor, situation)
            EndIf
            Return
        EndIf
        ; Slot exists but no mapping for this situation — fall through to legacy
        ; in case a legacy preset is mapped there.
    EndIf

    ; ── Legacy path ──

    ; Skip if auto-switch disabled for this actor
    if SeverActionsNative.Native_Outfit_GetAutoSwitchEnabled(akActor) == false
        return
    endif

    String presetName = SeverActionsNative.Native_Outfit_GetSituationPreset(akActor, situation)
    String activePreset = SeverActionsNative.Native_Outfit_GetActivePreset(akActor)

    If presetName == ""
        ; No mapped preset for this situation — keep current outfit.
        ; Don't restore default or switch. The follower stays in whatever
        ; they're wearing until they enter a situation that IS mapped.
        Return
    EndIf

    ; Skip if already wearing this preset
    If activePreset == presetName
        Return
    EndIf

    ; Auto-save default before the first situation switch.
    ; Captures the "normal" outfit so we can restore it when entering
    ; an unmapped situation. Only captures when activePreset is empty
    ; (manual outfit, not already in automation).
    If activePreset == ""
        Debug.Trace("[SeverActions_Outfit] Auto-saving default outfit for " + akActor.GetDisplayName() + " before situation switch")
        SaveOutfitPreset_Execute(akActor, "_default")
    EndIf

    ; Update current situation tracking (phase 4: native-only)
    SeverActionsNative.Native_Outfit_SetCurrentSituation(akActor, situation)

    ; Apply the mapped preset
    Debug.Trace("[SeverActions_Outfit] Auto-switching " + akActor.GetDisplayName() + " to '" + presetName + "' for " + situation + " situation")
    ApplyOutfitPreset_Execute(akActor, presetName)
EndEvent

; =============================================================================
; EVENT: OnCatalogEquipLock
; Fired by PrismaUI catalog "Equip & Lock" mode (native C++).
; Syncs the Papyrus FormList outfit lock with the armor piece that C++ just
; equipped and added to OutfitDataStore.
; strArg format: "actorFormIDHex|armorFormIDHex" (pipe-delimited). numArg
; is unused — both IDs ride in strArg to avoid float precision loss for
; FormIDs above 0x80000000.
; =============================================================================

Event OnCatalogEquipLock(String eventName, String strArg, Float numArg, Form sender)
    ; Parse pipe-delimited strArg: "actorFormID|armorFormID" (avoids float precision loss)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Debug.Trace("[SeverActions_Outfit] CatalogEquipLock: No pipe in strArg: " + strArg)
        Return
    EndIf

    String actorHex = StringUtil.Substring(strArg, 0, pipePos)
    String armorHex = StringUtil.Substring(strArg, pipePos + 1)

    Int actorFormID = SeverActionsNative.HexToInt(actorHex)
    Actor akActor = Game.GetForm(actorFormID) as Actor
    if !akActor
        Debug.Trace("[SeverActions_Outfit] CatalogEquipLock: Actor not found for FormID " + actorHex)
        return
    endif

    Int armorFormID = SeverActionsNative.HexToInt(armorHex)
    Form armorForm = Game.GetForm(armorFormID)
    if !armorForm
        Debug.Trace("[SeverActions_Outfit] CatalogEquipLock: Armor not found for FormID " + armorHex)
        return
    endif

    Armor newArmor = armorForm as Armor
    if !newArmor
        Debug.Trace("[SeverActions_Outfit] CatalogEquipLock: Form is not armor")
        return
    endif

    ; Suspend the lock so the alias doesn't fight our changes
    SuspendOutfitLock(akActor)

    ; Remove any existing locked items that share slots with the new armor
    ; This prevents equip flickering when replacing a piece in the same slot
    String lockKey = "SeverOutfit_Locked_" + (akActor.GetFormID() as String)
    Int newSlotMask = newArmor.GetSlotMask()
    Int listSize = StorageUtil.FormListCount(None, lockKey)
    Int i = listSize - 1
    While i >= 0
        Form existingForm = StorageUtil.FormListGet(None, lockKey, i)
        if existingForm
            Armor existingArmor = existingForm as Armor
            if existingArmor
                Int existingSlots = existingArmor.GetSlotMask()
                if Math.LogicalAnd(existingSlots, newSlotMask) > 0
                    StorageUtil.FormListRemoveAt(None, lockKey, i)
                    Debug.Trace("[SeverActions_Outfit] CatalogEquipLock: Removed conflicting " + existingArmor.GetName() + " from lock list")
                endif
            endif
        endif
        i -= 1
    EndWhile

    ; Add the new armor to the lock list
    if StorageUtil.FormListFind(None, lockKey, armorForm) < 0
        StorageUtil.FormListAdd(None, lockKey, armorForm)
        Debug.Trace("[SeverActions_Outfit] CatalogEquipLock: Added " + newArmor.GetName() + " to lock list for " + akActor.GetDisplayName())
    endif

    ; Only activate the lock if outfit lock is globally enabled.
    ; If disabled, the item is still equipped but won't be enforced on cell changes.
    If OutfitLockEnabled
        StorageUtil.SetIntValue(akActor, "SeverOutfit_LockActive", 1)
        TrackOutfitLockedActor(akActor)
        ResumeOutfitLock(akActor)
        Debug.Trace("[SeverActions_Outfit] CatalogEquipLock: Lock active for " + akActor.GetDisplayName() + " (" + StorageUtil.FormListCount(None, lockKey) + " items)")
    Else
        ResumeOutfitLock(akActor)
        Debug.Trace("[SeverActions_Outfit] CatalogEquipLock: Equipped " + newArmor.GetName() + " on " + akActor.GetDisplayName() + " (lock disabled globally)")
    EndIf
EndEvent

; =============================================================================
; PrismaUI Outfit ModEvent Handlers
; These replace DispatchMethodCall which silently fails.
; C++ does the fast path (OutfitDataStore), these sync StorageUtil + alias.
; =============================================================================

Event OnPrismaSnapshot(String eventName, String strArg, Float numArg, Form sender)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = SeverActionsNative.FindActorByName(StringUtil.Substring(strArg, 0, pipePos))
    If !akActor
        Return
    EndIf
    SnapshotLockedOutfit(akActor)
    Debug.Trace("[SeverActions_Outfit] PrismaSnapshot: Synced lock for " + akActor.GetDisplayName())
EndEvent

Event OnPrismaBuilderEquip(String eventName, String strArg, Float numArg, Form sender)
    {Fired by buildOutfitEquip C++ action. Syncs the StorageUtil FormList
     from the native OutfitDataStore lock items so the OutfitAlias re-equip
     system reads the correct items on cell load.}
    Actor akActor = Game.GetFormEx(numArg as Int) as Actor
    If !akActor
        Return
    EndIf

    ; Read lock items from native store and rebuild StorageUtil FormList
    Form[] nativeItems = SeverActionsNative.Native_Outfit_GetLockedItems(akActor)
    If nativeItems && nativeItems.Length > 0
        String lockKey = "SeverOutfit_Locked_" + (akActor.GetFormID() as String)
        StorageUtil.FormListClear(None, lockKey)
        Int i = 0
        While i < nativeItems.Length
            If nativeItems[i]
                StorageUtil.FormListAdd(None, lockKey, nativeItems[i])
            EndIf
            i += 1
        EndWhile
        StorageUtil.SetIntValue(akActor, "SeverOutfit_LockActive", 1)

        ; Track actor in outfit system if not already
        String trackedKey = "SeverOutfit_TrackedActors"
        If StorageUtil.FormListFind(None, trackedKey, akActor as Form) < 0
            StorageUtil.FormListAdd(None, trackedKey, akActor as Form)
        EndIf

        Debug.Trace("[SeverActions_Outfit] PrismaBuilderEquip: Synced " + nativeItems.Length + " lock items for " + akActor.GetDisplayName())
    EndIf

    ; Clear active preset — builder equip is a manual outfit, not a preset apply.
    ; Without this, OnSituationChanged thinks the NPC is already wearing the
    ; mapped preset and skips the auto-switch.

    ; Delete the _default preset — the manual outfit IS the new normal.
    ; Next situation switch will re-capture from this outfit.
    DeletePreset(akActor, "_default")

    ; Resume the suspend that C++ set at the start of buildOutfitEquip.
    ; This MUST happen after StorageUtil is synced — otherwise the alias
    ; re-equips old items from the stale FormList before we update it.
    ResumeOutfitLock(akActor)

    ; NOW restore conflicting items that were removed from inventory during equip.
    ; Deferred to here so the lock is fully synced and the alias can fight any
    ; engine auto-equip triggered by AddObjectToContainer.
    SeverActionsNative.Native_Outfit_RestoreStashedItems(akActor)
EndEvent

Event OnPrismaBuilderSaveAndApply(String eventName, String strArg, Float numArg, Form sender)
    {Fired by buildOutfitSavePreset C++ action AFTER ApplyPresetNative has run.
     Mirrors OnPrismaBuilderEquip's StorageUtil sync (lock FormList + tracking)
     but PRESERVES the active preset name — the save-and-apply flow commits to a
     named preset, not an ad-hoc manual outfit, so SituationMonitor's
     already-wearing-X check needs the name intact to skip redundant re-applies.
     strArg format: "actorName|presetName" (standard SendModEvent encoding).}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    String presetName = StringUtil.Substring(strArg, pipePos + 1)
    Actor akActor = SeverActionsNative.FindActorByName(actorName)
    If !akActor
        Return
    EndIf

    ; Read lock items from native store and rebuild the StorageUtil FormList.
    ; OutfitAlias reads from StorageUtil, so this sync is what makes the
    ; native lock visible to the on-cell-load re-equip pipeline.
    Form[] nativeItems = SeverActionsNative.Native_Outfit_GetLockedItems(akActor)
    If nativeItems && nativeItems.Length > 0
        String lockKey = "SeverOutfit_Locked_" + (akActor.GetFormID() as String)
        StorageUtil.FormListClear(None, lockKey)
        Int i = 0
        While i < nativeItems.Length
            If nativeItems[i]
                StorageUtil.FormListAdd(None, lockKey, nativeItems[i])
            EndIf
            i += 1
        EndWhile
        StorageUtil.SetIntValue(akActor, "SeverOutfit_LockActive", 1)

        ; Track actor in outfit system if not already
        String trackedKey = "SeverOutfit_TrackedActors"
        If StorageUtil.FormListFind(None, trackedKey, akActor as Form) < 0
            StorageUtil.FormListAdd(None, trackedKey, akActor as Form)
        EndIf

        Debug.Trace("[SeverActions_Outfit] PrismaBuilderSaveAndApply: Synced " + nativeItems.Length + " lock items for " + akActor.GetDisplayName() + " preset='" + presetName + "'")
    EndIf

    ; Set active preset to the saved preset name (NOT empty like OnPrismaBuilderEquip
    ; does). This keeps StorageUtil aligned with the native store's activePresetName
    ; that ApplyPresetNative just set, so SituationMonitor's auto-switch sees
    ; "already wearing X" correctly and the legacy MCM read sees a meaningful value.

    ; Resume the suspend that suspendOutfitLock set when the builder opened.
    ; This MUST happen after StorageUtil is synced — otherwise the alias
    ; re-equips old items from the stale FormList before we update it.
    ResumeOutfitLock(akActor)

    ; Restore conflicting items that were removed from inventory during equip.
    SeverActionsNative.Native_Outfit_RestoreStashedItems(akActor)
EndEvent

Event OnPrismaBuilderSavePreset(String eventName, String strArg, Float numArg, Form sender)
    {Fired by buildOutfitSavePreset C++ action. Syncs the preset from native
     OutfitDataStore to StorageUtil AND registers it in the slot system so
     FindPresetIndexByName can resolve it for ApplyPreset.
     strArg format: "actorName|presetName" (standard SendModEvent encoding)}
    SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: ENTRY strArg='" + strArg + "' numArg=" + numArg)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: no pipe in strArg, aborting")
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = SeverActionsNative.FindActorByName(actorName)
    String presetName = StringUtil.Substring(strArg, pipePos + 1)
    SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: parsed actorName='" + actorName + "' presetName='" + presetName + "'")
    If !akActor || presetName == ""
        SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: actor=" + akActor + " presetName='" + presetName + "' — aborting")
        Return
    EndIf

    presetName = NormalizePresetName(presetName)
    SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: after normalize presetName='" + presetName + "'")

    ; FETCH FIRST — don't mutate any store until we know the source has data.
    ; Native lookup is now case-insensitive (OutfitDataStore.h), so the
    ; BSFixedString pool case-flip can no longer cause an empty result on its own.
    ; If we still get empty here, the C++ save genuinely failed and we should
    ; abort cleanly rather than create ghost StorageUtil entries that nuke the
    ; previous backup for this key.
    Form[] presetItems = SeverActionsNative.Native_Outfit_GetPresetItems(akActor, presetName)
    Int itemsLen = 0
    If presetItems
        itemsLen = presetItems.Length
    EndIf
    SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: native fetch returned " + itemsLen + " items for '" + presetName + "'")

    If itemsLen == 0
        SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: ABORT — empty native fetch, refusing to register ghost legacy entry for '" + presetName + "'")
        Return
    EndIf

    ; Native fetch succeeded — now we can safely mutate the legacy stores.
    String presetKey = "SeverOutfit_" + presetName + "_" + (akActor.GetFormID() as String)

    ; Clear stale item FormList and repopulate from the verified native data
    StorageUtil.FormListClear(None, presetKey)
    Int pi = 0
    While pi < itemsLen
        If presetItems[pi]
            StorageUtil.FormListAdd(None, presetKey, presetItems[pi])
        EndIf
        pi += 1
    EndWhile

    ; Register the preset name in StorageUtil
    String presetsListKey = "SeverOutfit_Presets_" + (akActor.GetFormID() as String)
    if StorageUtil.StringListFind(None, presetsListKey, presetName) < 0
        StorageUtil.StringListAdd(None, presetsListKey, presetName)
    endif

    ; Track actor in global preset list
    String presetActorsKey = "SeverOutfit_PresetActors"
    if StorageUtil.FormListFind(None, presetActorsKey, akActor as Form) < 0
        StorageUtil.FormListAdd(None, presetActorsKey, akActor as Form)
    endif

    ; === SLOT SYSTEM REGISTRATION ===
    ; Call BuildPreset so the new preset shows up in the slot system's cosave.
    ; Without this, FindPresetIndexByName returns -1 and ApplyPreset falls back
    ; to the legacy path (which doesn't use the NFF-style outfit swap).
    SeverActions_OutfitSlot slotSys = GetSlotScript()
    SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: pre-slot-gate slotSys=" + slotSys + " presetItems.Length=" + itemsLen)
    If slotSys
        ; Find or allocate a preset index for this name
        Int targetIdx = slotSys.FindFreeOrReusableIndex(akActor, presetName)
        If targetIdx >= 0
            Int committed = slotSys.BuildPreset(akActor, targetIdx, presetItems, presetName)
            SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: BuildPreset for " + akActor.GetDisplayName() + " '" + presetName + "' targetIdx=" + targetIdx + " committed=" + committed)
        Else
            SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: No free slot index for " + akActor.GetDisplayName() + " '" + presetName + "' (all 8 full)")
        EndIf
    Else
        SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: SKIPPED slot registration — slotSys is None")
    EndIf

    Debug.Trace("[SeverActions_Outfit] PrismaBuilderSavePreset: Synced preset '" + presetName + "' for " + akActor.GetDisplayName())
EndEvent

Event OnPrismaBuilderRenamePreset(String eventName, String strArg, Float numArg, Form sender)
    {Fired by buildOutfitSavePreset C++ action when the frontend submits a save
     with `oldPreset` populated and different from `preset`. Both native stores
     (OutfitDataStore + OutfitSlotStore) have already been renamed. This handler
     mirrors the rename in StorageUtil so the Papyrus side stays in sync:
       - Renames the SeverOutfit_<oldName>_<actorFid> FormList key to <newName>
       - Replaces the preset name in the per-actor StringList
     strArg format: "actorName|oldName|newName" — the SendModEvent helper
     prepends actorName, then we appended oldName|newName.}
    SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderRenamePreset: ENTRY strArg='" + strArg + "'")

    Int p1 = StringUtil.Find(strArg, "|")
    If p1 < 0
        SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderRenamePreset: malformed strArg (no first pipe), aborting")
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, p1)
    String rest = StringUtil.Substring(strArg, p1 + 1)
    Int p2 = StringUtil.Find(rest, "|")
    If p2 < 0
        SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderRenamePreset: malformed strArg (no second pipe), aborting")
        Return
    EndIf
    String oldName = StringUtil.Substring(rest, 0, p2)
    String newName = StringUtil.Substring(rest, p2 + 1)

    Actor akActor = SeverActionsNative.FindActorByName(actorName)
    If !akActor || oldName == "" || newName == ""
        SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderRenamePreset: actor=" + akActor + " oldName='" + oldName + "' newName='" + newName + "' — aborting")
        Return
    EndIf

    String actorFid = akActor.GetFormID() as String

    ; Rename the per-preset item FormList key. StorageUtil has no rename API,
    ; so we copy from old → new and clear the old.
    String oldKey = "SeverOutfit_" + oldName + "_" + actorFid
    String newKey = "SeverOutfit_" + newName + "_" + actorFid
    Int itemCount = StorageUtil.FormListCount(None, oldKey)
    If itemCount > 0
        ; Don't accidentally double-up if newKey already has data from a prior partial rename.
        StorageUtil.FormListClear(None, newKey)
        Int i = 0
        While i < itemCount
            Form item = StorageUtil.FormListGet(None, oldKey, i)
            If item
                StorageUtil.FormListAdd(None, newKey, item, false)
            EndIf
            i += 1
        EndWhile
        StorageUtil.FormListClear(None, oldKey)
    EndIf

    ; Replace name in the per-actor StringList. StorageUtil has no in-place
    ; replace, so we remove old + append new (only if new isn't already there).
    String namesKey = "SeverOutfit_Presets_" + actorFid
    Int oldIdx = StorageUtil.StringListFind(None, namesKey, oldName)
    If oldIdx >= 0
        StorageUtil.StringListRemove(None, namesKey, oldName, true)
    EndIf
    If StorageUtil.StringListFind(None, namesKey, newName) < 0
        StorageUtil.StringListAdd(None, namesKey, newName, false)
    EndIf

    SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderRenamePreset: renamed '" + oldName + "' → '" + newName + "' for " + akActor.GetDisplayName() + " (items copied=" + itemCount + ")")
EndEvent

Event OnPrismaClearLockForBuilder(String eventName, String strArg, Float numArg, Form sender)
    {Fired when the Outfit Builder opens. Fully clears the Papyrus-side lock
     so the alias has nothing to enforce while the builder is active.
     C++ already cleared the native lock via ClearLockItems.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = SeverActionsNative.FindActorByName(StringUtil.Substring(strArg, 0, pipePos))
    If !akActor
        Return
    EndIf

    String lockKey = "SeverOutfit_Locked_" + (akActor.GetFormID() as String)
    StorageUtil.FormListClear(None, lockKey)
    StorageUtil.SetIntValue(akActor, "SeverOutfit_LockActive", 0)
    ; Route through SuspendOutfitLock so the watchdog timestamp is set —
    ; if the builder is closed without firing OnPrismaResumeLock (crash,
    ; alt-F4, dropped ModEvent), the alias will auto-resume after the
    ; watchdog window instead of permanently skipping the actor.
    SuspendOutfitLock(akActor)
    Debug.Trace("[SeverActions_Outfit] PrismaClearLockForBuilder: Cleared lock for " + akActor.GetDisplayName())
EndEvent

Event OnPrismaResumeLock(String eventName, String strArg, Float numArg, Form sender)
    {Fired when the Outfit Builder closes. Clears Papyrus suspend.
     If buildOutfitEquip ran, the lock was already re-created by OnPrismaBuilderEquip.
     If the user closed without equipping, the lock stays cleared.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = SeverActionsNative.FindActorByName(StringUtil.Substring(strArg, 0, pipePos))
    If !akActor
        Return
    EndIf

    SeverActionsNative.Native_Outfit_ClearBurstSuppression(akActor)
    ResumeOutfitLock(akActor)
    Debug.Trace("[SeverActions_Outfit] PrismaResumeLock: Resumed for " + akActor.GetDisplayName())
EndEvent

Event OnOutfitExcluded(String eventName, String strArg, Float numArg, Form sender)
    {Fired by PrismaUISettingsHandler when an actor is marked outfit-excluded.
     Native lock already cleared by C++; this handler clears the StorageUtil
     mirror so the legacy LockActive flag doesn't survive the exclusion.
     strArg format: "<actorFormIDDecimal>|"}
    Int pipePos = StringUtil.Find(strArg, "|")
    String actorIdStr
    if pipePos >= 0
        actorIdStr = StringUtil.Substring(strArg, 0, pipePos)
    else
        actorIdStr = strArg
    endif
    Int actorFid = actorIdStr as Int
    Actor akActor = Game.GetForm(actorFid) as Actor
    if !akActor
        return
    endif
    String lockKey = "SeverOutfit_Locked_" + (akActor.GetFormID() as String)
    StorageUtil.FormListClear(None, lockKey)
    StorageUtil.UnsetIntValue(akActor, "SeverOutfit_LockActive")
    UntrackOutfitLockedActor(akActor)
    Debug.Trace("[SeverActions_Outfit] OnOutfitExcluded: cleared StorageUtil lock for " + akActor.GetDisplayName())
EndEvent

Event OnPrismaAdHocClearSlotPreset(String eventName, String strArg, Float numArg, Form sender)
    {Fired by C++ catalog Equip & Lock / Unequip paths to mirror the
     ClearSlotPresetForAdHoc behavior into Papyrus. C++ has already cleared
     the native activePresetIdx; this handler clears the matching StorageUtil
     flag so the alias short-circuit (which reads SeverOutfit_PresetActive)
     stops treating the actor as preset-active.

     numArg = actor FormID (uint cast to Float by the SendModEvent helper).}
    Actor akActor = Game.GetFormEx(numArg as Int) as Actor
    if !akActor
        Debug.Trace("[SeverActions_Outfit] OnPrismaAdHocClearSlotPreset: actor lookup failed for FormID " + numArg)
        return
    endif
    StorageUtil.UnsetIntValue(akActor, "SeverOutfit_PresetActive")
    Debug.Trace("[SeverActions_Outfit] OnPrismaAdHocClearSlotPreset: cleared StorageUtil flag for " + akActor.GetDisplayName())
EndEvent

Event OnPrismaClearLock(String eventName, String strArg, Float numArg, Form sender)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = SeverActionsNative.FindActorByName(StringUtil.Substring(strArg, 0, pipePos))
    If !akActor
        Return
    EndIf
    ClearLockedOutfit(akActor)
    Debug.Trace("[SeverActions_Outfit] PrismaClearLock: Cleared lock for " + akActor.GetDisplayName())
EndEvent

Event OnPrismaClearAllPresets(String eventName, String strArg, Float numArg, Form sender)
    {Fired by "Clear All Presets" button in PrismaUI. Fully releases the actor's
     slot — restores original DefaultOutfit, empties all 8 preset containers,
     returns satchel items to the actor, disables the satchel.
     After this, the actor is back to their untouched baseline.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = SeverActionsNative.FindActorByName(StringUtil.Substring(strArg, 0, pipePos))
    If !akActor
        Return
    EndIf

    ; Release the slot via the slot-system orchestrator
    SeverActions_OutfitSlot slotSys = GetSlotScript()
    If slotSys
        slotSys.ReleaseSlotFromActor(akActor)
    EndIf

    ; Also clear any legacy lock + presets for thorough cleanup
    ClearLockedOutfit(akActor)

    Debug.Trace("[SeverActions_Outfit] PrismaClearAllPresets: Fully released " + akActor.GetDisplayName())
EndEvent

Event OnPrismaApplyPreset(String eventName, String strArg, Float numArg, Form sender)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = SeverActionsNative.FindActorByName(StringUtil.Substring(strArg, 0, pipePos))
    String presetName = StringUtil.Substring(strArg, pipePos + 1)
    If !akActor
        Return
    EndIf
    ApplyOutfitPreset_Execute(akActor, presetName)
    Debug.Trace("[SeverActions_Outfit] PrismaApplyPreset: Applied '" + presetName + "' to " + akActor.GetDisplayName())
EndEvent

Event OnPrismaApplyPresetV2(String eventName, String strArg, Float numArg, Form sender)
    {Versioned handler that bypasses stale-cached old OnPrismaApplyPreset bytecode.
     New saves get the parse-pipe behavior; existing saves with cached old handlers
     simply ignore this event because they never registered for V2.}
    SeverActionsNative.Native_OutfitSlot_Log("OnPrismaApplyPresetV2: strArg='" + strArg + "' numArg=" + numArg)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        SeverActionsNative.Native_OutfitSlot_Log("OnPrismaApplyPresetV2: No pipe in strArg, aborting")
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    String presetName = StringUtil.Substring(strArg, pipePos + 1)
    Actor akActor = SeverActionsNative.FindActorByName(actorName)
    If !akActor
        SeverActionsNative.Native_OutfitSlot_Log("OnPrismaApplyPresetV2: Actor lookup failed for '" + actorName + "'")
        Return
    EndIf
    SeverActionsNative.Native_OutfitSlot_Log("OnPrismaApplyPresetV2: Calling ApplyOutfitPreset_Execute('" + akActor.GetDisplayName() + "', '" + presetName + "')")
    ApplyOutfitPreset_Execute(akActor, presetName)
EndEvent

Event OnPrismaDeletePreset(String eventName, String strArg, Float numArg, Form sender)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = SeverActionsNative.FindActorByName(StringUtil.Substring(strArg, 0, pipePos))
    String presetName = StringUtil.Substring(strArg, pipePos + 1)
    If !akActor
        Return
    EndIf
    DeletePreset(akActor, presetName)
    Debug.Trace("[SeverActions_Outfit] PrismaDeletePreset: Deleted '" + presetName + "' for " + akActor.GetDisplayName())
EndEvent

Event OnPrismaSavePreset(String eventName, String strArg, Float numArg, Form sender)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = SeverActionsNative.FindActorByName(StringUtil.Substring(strArg, 0, pipePos))
    String presetName = StringUtil.Substring(strArg, pipePos + 1)
    If !akActor
        Return
    EndIf
    SaveOutfitPreset_Execute(akActor, presetName)
    Debug.Trace("[SeverActions_Outfit] PrismaSavePreset: Saved '" + presetName + "' for " + akActor.GetDisplayName())
EndEvent

Event OnPrismaNukeOutfit(String eventName, String strArg, Float numArg, Form sender)
    {Wholesale outfit-data wipe for one NPC. Fired by PrismaUI's "Reset Outfit
     Data" button. The native side (OutfitDataStore::RemoveActor +
     OutfitSlotStore::EraseActor) has already restored DefaultOutfit and
     erased the cosaved entries by the time this fires. This handler is
     responsible for the StorageUtil mirror — every SeverOutfit_* per-actor
     key, the per-preset FormLists, and the global tracker FormLists.

     numArg = actor FormID (cast to Int).
     strArg = actor display name (informational, not required for cleanup).}

    Int actorFid = numArg as Int
    If actorFid == 0
        Debug.Trace("[SeverActions_Outfit] OnPrismaNukeOutfit: actorFid=0, aborting")
        Return
    EndIf
    String actorFidStr = actorFid as String
    Form actorForm = Game.GetForm(actorFid)
    Actor akActor = actorForm as Actor

    Debug.Trace("[SeverActions_Outfit] OnPrismaNukeOutfit: wiping all StorageUtil outfit data for FormID " + actorFidStr + " ('" + strArg + "')")

    ; --- 1. Enumerate preset names + clear each per-preset FormList ---
    String presetListKey = "SeverOutfit_Presets_" + actorFidStr
    Int presetCount = StorageUtil.StringListCount(None, presetListKey)
    Int presetIdx = 0
    While presetIdx < presetCount
        String pName = StorageUtil.StringListGet(None, presetListKey, presetIdx)
        If pName != ""
            String pKey = "SeverOutfit_" + pName + "_" + actorFidStr
            StorageUtil.FormListClear(None, pKey)
        EndIf
        presetIdx += 1
    EndWhile
    StorageUtil.StringListClear(None, presetListKey)

    ; --- 2. Clear all known per-actor SeverOutfit_* keys ---
    ; Most keys are anchored on the actor form (StorageUtil first arg = actor),
    ; some are global with FormID-suffixed names (first arg = None).
    If akActor
        StorageUtil.UnsetIntValue(akActor, "SeverOutfit_LockActive")
        StorageUtil.UnsetIntValue(akActor, "SeverOutfit_Suspended")
        StorageUtil.UnsetIntValue(akActor, "SeverOutfit_PresetActive")
        StorageUtil.UnsetIntValue(akActor, "SeverOutfit_AutoSwitch")
        StorageUtil.UnsetIntValue(akActor, "SeverOutfit_NonFollowerLock")
        StorageUtil.UnsetStringValue(akActor, "SeverOutfit_ActivePreset")
        StorageUtil.UnsetStringValue(akActor, "SeverOutfit_CurrentSituation")
        ; Situation→preset mapping is per-situation; clear all 7 canonical
        ; keys defined in NormalizeSituation. Earlier this only cleared 4
        ; (home/town/adventure/sleep), so combat/rain/snow assignments
        ; survived "nuke outfit data" and resurfaced after re-save.
        StorageUtil.UnsetStringValue(akActor, "SeverOutfit_Sit_home")
        StorageUtil.UnsetStringValue(akActor, "SeverOutfit_Sit_town")
        StorageUtil.UnsetStringValue(akActor, "SeverOutfit_Sit_adventure")
        StorageUtil.UnsetStringValue(akActor, "SeverOutfit_Sit_sleep")
        StorageUtil.UnsetStringValue(akActor, "SeverOutfit_Sit_combat")
        StorageUtil.UnsetStringValue(akActor, "SeverOutfit_Sit_rain")
        StorageUtil.UnsetStringValue(akActor, "SeverOutfit_Sit_snow")
    EndIf

    ; FormID-suffixed legacy global keys (kept clearing old-save residue).
    StorageUtil.FormListClear(None, "SeverOutfit_Locked_" + actorFidStr)
    StorageUtil.FormListClear(None, "SeverActions_RemovedArmor_" + actorFidStr)

    ; --- 3. Remove from legacy global tracker FormLists ---
    If akActor
        Int trackedIdx = StorageUtil.FormListFind(None, "SeverOutfit_TrackedActors", akActor)
        If trackedIdx >= 0
            StorageUtil.FormListRemoveAt(None, "SeverOutfit_TrackedActors", trackedIdx)
        EndIf
        Int presetActorsIdx = StorageUtil.FormListFind(None, "SeverOutfit_PresetActors", akActor)
        If presetActorsIdx >= 0
            StorageUtil.FormListRemoveAt(None, "SeverOutfit_PresetActors", presetActorsIdx)
        EndIf

        ; --- 4. Phase 5: clear native dress stash + reset isFollowerLock ---
        SeverActionsNativeExt.Native_Outfit_DressStashClear(akActor)
        SeverActionsNativeExt.Native_Outfit_DressStashSetDefaultOutfit(akActor, None)
        SeverActionsNativeExt.Native_Outfit_SetIsFollowerLock(akActor, true)
    EndIf

    Debug.Trace("[SeverActions_Outfit] OnPrismaNukeOutfit: complete for " + actorFidStr + " (" + presetCount + " presets cleared)")
EndEvent

Event OnPrismaSetSitPreset(String eventName, String strArg, Float numArg, Form sender)
    ; strArg = "actorName|situation|presetName"
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = SeverActionsNative.FindActorByName(StringUtil.Substring(strArg, 0, pipePos))
    If !akActor
        Return
    EndIf
    String remainder = StringUtil.Substring(strArg, pipePos + 1)
    Int pipe2 = StringUtil.Find(remainder, "|")
    If pipe2 < 0
        Debug.Trace("[SeverActions_Outfit] PrismaSetSitPreset: Invalid format — no second pipe")
        Return
    EndIf
    String situation = StringUtil.Substring(remainder, 0, pipe2)
    String presetName = StringUtil.Substring(remainder, pipe2 + 1)
    SetSituationPreset_Execute(akActor, situation, presetName)
    Debug.Trace("[SeverActions_Outfit] PrismaSetSitPreset: " + akActor.GetDisplayName() + " — " + situation + " → " + presetName)
EndEvent

Event OnPrismaClearSitPreset(String eventName, String strArg, Float numArg, Form sender)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = SeverActionsNative.FindActorByName(StringUtil.Substring(strArg, 0, pipePos))
    String situation = StringUtil.Substring(strArg, pipePos + 1)
    If !akActor
        Return
    EndIf
    ClearSituationPreset_Execute(akActor, situation)
    Debug.Trace("[SeverActions_Outfit] PrismaClearSitPreset: " + akActor.GetDisplayName() + " — cleared " + situation)
EndEvent

; =============================================================================
; PrismaUI Global Auto-Switch Toggle Sync
; Fired when PrismaUI toggles the global auto-switch. Syncs to StorageUtil
; so MCM reads the correct value and the setting persists across game loads.
; =============================================================================

Event OnPrismaToggleAutoSwitch(String eventName, String strArg, Float numArg, Form sender)
    ; strArg = "0|0" or "0|1" (formId=0 for global, data=0/1)
    Int pipePos = StringUtil.Find(strArg, "|")
    String valStr = strArg
    If pipePos >= 0
        valStr = StringUtil.Substring(strArg, pipePos + 1)
    EndIf
    Bool enabled = (valStr == "1")
    StorageUtil.SetIntValue(None, "SeverOutfit_GlobalAutoSwitch", enabled as Int)
    Debug.Trace("[SeverActions_Outfit] PrismaToggleAutoSwitch: Global auto-switch → " + enabled)
EndEvent

Event OnPrismaToggleActorAutoSwitch(String eventName, String strArg, Float numArg, Form sender)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = SeverActionsNative.FindActorByName(StringUtil.Substring(strArg, 0, pipePos))
    If !akActor
        Return
    EndIf
    Bool enabled = (StringUtil.Substring(strArg, pipePos + 1) == "1")
    StorageUtil.SetIntValue(akActor, "SeverOutfit_AutoSwitch", enabled as Int)
    Debug.Trace("[SeverActions_Outfit] PrismaToggleActorAutoSwitch: " + akActor.GetDisplayName() + " auto-switch → " + enabled)
EndEvent

; =============================================================================
; PrismaUI Inventory Sync — Outfit Lock Update After Transfer
; Fired by C++ when an equipped armor item is transferred away from an actor
; via the Inventory page. C++ already updated OutfitDataStore; this handler
; syncs StorageUtil's FormList to match (dual-write pattern).
; strArg format: "ActorName|" (empty after pipe — no extra data needed)
; =============================================================================

Event OnPrismaInventorySync(String eventName, String strArg, Float numArg, Form sender)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = SeverActionsNative.FindActorByName(StringUtil.Substring(strArg, 0, pipePos))
    If !akActor
        Debug.Trace("[SeverActions_Outfit] PrismaInventorySync: Actor not found from strArg: " + strArg)
        Return
    EndIf

    ; C++ already removed the item from OutfitDataStore via RemoveLockedItems.
    ; Sync StorageUtil FormList to match the native store — do NOT snapshot GetWornForm
    ; because UnequipObject is async and worn state may be stale.
    String lockKey = "SeverOutfit_Locked_" + (akActor.GetFormID() as String)

    If StorageUtil.GetIntValue(akActor, "SeverOutfit_LockActive", 0) != 1
        Debug.Trace("[SeverActions_Outfit] PrismaInventorySync: Lock not active for " + akActor.GetDisplayName())
        Return
    EndIf

    ; Rebuild StorageUtil FormList from the native OutfitDataStore (source of truth)
    StorageUtil.FormListClear(None, lockKey)
    Form[] lockedItems = SeverActionsNative.Native_Outfit_GetLockedItems(akActor)
    If lockedItems
        Int li = 0
        While li < lockedItems.Length
            If lockedItems[li]
                StorageUtil.FormListAdd(None, lockKey, lockedItems[li])
            EndIf
            li += 1
        EndWhile
    EndIf

    ; Native OutfitDataStore already updated by C++ before this event fired

    Int lockCount = StorageUtil.FormListCount(None, lockKey)
    Debug.Trace("[SeverActions_Outfit] PrismaInventorySync: Rebuilt lock for " + akActor.GetDisplayName() + " — " + lockCount + " items")
EndEvent

; =============================================================================
; ANIMATION FRAMEWORK HOOKS — suspend/resume outfit locks during scenes
; =============================================================================

; SexLab global hooks — signature: (int threadID, bool hasPlayer)
Event OnSexLabSceneStart(Int threadID, Bool hasPlayer)
    AnimationSceneActive = true
    Debug.Trace("[SeverActions_Outfit] SexLab scene started (thread " + threadID + ") — outfit locks suspended")
EndEvent

Event OnSexLabSceneEnd(Int threadID, Bool hasPlayer)
    AnimationSceneActive = false
    Debug.Trace("[SeverActions_Outfit] SexLab scene ended (thread " + threadID + ") — outfit locks resumed")
EndEvent

; OStim hooks — signature: (string eventName, string strArg, float numArg, Form sender)
Event OnOStimSceneStart(String eventName, String strArg, Float numArg, Form sender)
    AnimationSceneActive = true
    Debug.Trace("[SeverActions_Outfit] OStim scene started — outfit locks suspended")
EndEvent

Event OnOStimSceneEnd(String eventName, String strArg, Float numArg, Form sender)
    AnimationSceneActive = false
    Debug.Trace("[SeverActions_Outfit] OStim scene ended — outfit locks resumed")
EndEvent