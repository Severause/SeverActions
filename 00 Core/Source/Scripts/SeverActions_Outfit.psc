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

Bool Property OutfitLockEnabled = false Auto
{Master toggle for the outfit lock, OFF by default. Off = nothing is
 snapshotted or re-applied on cell transitions; existing locks are kept but
 inactive. The lock vetoes equipment changes and so races the async unequip:
 a set captured mid-undress is then enforced as a stripped state. Presets are
 declarative and have nothing to race; the lock stays for ad-hoc outfits.}

Bool Property AnimationSceneActive = false Auto Hidden
{True while any animation scene runs (read by OutfitAlias). Derived from
 AnimationSceneCount: set right after every change to it.}
Int Property AnimationSceneCount = 0 Auto Hidden
{Refcount of overlapping animation scenes, so one scene ending does not
 re-enable enforcement while another runs. Maintenance() resets it to 0 on
 load (a live scene re-arms within a frame).}

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
    {The slot-preset script (SeverActions_OutfitSlot), or None.}
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
    ; Master switch at every entry point: the YAML gate covers only the LLM,
    ; while the Actions page, the wheel and the hotkeys call in directly.
    If !SeverActionsNativeExt2.Native_Outfit_IsSystemEnabled()
        Debug.Trace("[SeverActions_Outfit] refused - the outfit system is turned off")
        Return
    EndIf
    if !akActor
        return
    endif
    If RefuseIfOutfitExcluded(akActor, "Undress")
        Return
    EndIf

    Debug.Trace("[SeverActions_Outfit] Undress: " + akActor.GetDisplayName())

    ; A stash still pending from an earlier Undress (items or the DefaultOutfit
    ; backup) is what Dress must put back: a repeat Undress keeps it and its
    ; lock flag, and only adds pieces worn now that the stash lacks.
    Form[] pendingStash = SeverActionsNativeExt.Native_Outfit_DressStashGet(akActor)
    Bool stashPending = (pendingStash && pendingStash.Length > 0) || SeverActionsNativeExt.Native_Outfit_DressStashGetDefaultOutfit(akActor) != None
    If stashPending
        Debug.Trace("[SeverActions_Outfit] Undress: " + akActor.GetDisplayName() + " already has a pending stash - keeping it and its lock flag")
    Else
        SeverActionsNativeExt.Native_Outfit_DressStashClear(akActor)
    EndIf
    ; Whether the actor was locked BEFORE this undress, so Dress re-locks only
    ; if they were (ApplyOutfitPreset's wasLocked rule); consumed in
    ; Dress_Execute. Written whenever absent, not only for a fresh stash:
    ; UnequipArmor and the legacy preset apply feed the stash without it.
    If !stashPending || !StorageUtil.HasIntValue(akActor, "SeverActions_DressWasLocked")
        StorageUtil.SetIntValue(akActor, "SeverActions_DressWasLocked", (SeverActionsNativeExt.Native_Outfit_IsLockActive(akActor)) as Int)
    EndIf

    ; The active slot preset, read before BeginAdHocOutfitOp tears it down:
    ; its pieces are not stashed, and Dress re-applies the preset itself from
    ; the index recorded here. With a stash pending the first record stands.
    Int undressPresetIdx = SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor)
    ObjectReference undressPresetChest = None
    If undressPresetIdx >= 0
        undressPresetChest = SeverActionsNative.Native_OutfitSlot_GetContainer(SeverActionsNative.Native_OutfitSlot_GetSlot(akActor), undressPresetIdx)
        If !stashPending || !StorageUtil.HasIntValue(akActor, "SeverActions_DressPresetIdx")
            StorageUtil.SetIntValue(akActor, "SeverActions_DressPresetIdx", undressPresetIdx)
            ; The name too: a deleted preset frees its index, so Dress
            ; re-applies only while this name still sits there.
            StorageUtil.SetStringValue(akActor, "SeverActions_DressPresetName", SeverActionsNative.Native_OutfitSlot_GetPresetName(akActor, undressPresetIdx))
        EndIf
    EndIf

    ; Stash worn armor BEFORE BeginAdHocOutfitOp: its preset teardown strips
    ; the preset items, leaving GetWornForm nothing to stash. Filtered like the
    ; slot loop below (blacklist, Devious Devices) plus the active preset's
    ; pieces, which are the preset's (the chest test UnequipSingleItemInternal2
    ; makes): the teardown deletes those catalog copies, so Dress re-applies the
    ; preset instead. GetWornArmor walks every biped slot, so wigs and decap FX
    ; are stashed too; harmless, re-equipping a worn piece is a no-op.
    Form[] preWornArmor = SeverActionsNative.Native_Outfit_GetWornArmor(akActor)
    If preWornArmor
        Int pwi = 0
        While pwi < preWornArmor.Length
            Armor pwItem = preWornArmor[pwi] as Armor
            ; A stashed rendered device would be re-equipped outside the DD
            ; framework.
            if pwItem && !SeverActionsNative.Native_Blacklist_IsBlacklisted(pwItem) && !SeverActionsNativeExt.Native_IsDeviousDevice(pwItem)
                if undressPresetChest && undressPresetChest.GetItemCount(pwItem) > 0
                    Debug.Trace("[SeverActions_Outfit] Undress: " + pwItem.GetName() + " belongs to slot preset " + undressPresetIdx + " - not stashed")
                ; The native stash does not dedupe.
                elseif !stashPending || !FormArrayContains(pendingStash, pwItem)
                    SeverActionsNativeExt.Native_Outfit_DressStashAdd(akActor, pwItem)
                endif
            endif
            pwi += 1
        EndWhile
    EndIf

    BeginAdHocOutfitOp(akActor)

    ; Snapshot the DefaultOutfit as a Dress fallback, AFTER BeginAdHocOutfitOp
    ; so an original its preset cleanup restored is what gets saved. Not with a
    ; stash pending: keep the first backup (the base is nulled by then).
    If !stashPending
        ActorBase npcBase = akActor.GetActorBase()
        If npcBase
            Outfit baseOutfit = npcBase.GetOutfit(false)
            If baseOutfit
                SeverActionsNativeExt.Native_Outfit_DressStashSetDefaultOutfit(akActor, baseOutfit)
            EndIf
        EndIf
    EndIf

    ; Biped slots 30-60 except 31/Hair, 38/Calves, 41/LongHair (wigs) and
    ; 50/51 (decapitation FX, not gear).
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
    
    ; Animate and unequip what survived BeginAdHocOutfitOp. The pre-stash
    ; already filled the stash, so no DressStashAdd here (it would duplicate).
    int i = 0
    int removedCount = 0
    while i < slots.Length
        Armor equippedItem = akActor.GetWornForm(slots[i]) as Armor
        if equippedItem
            If SeverActionsNative.Native_Blacklist_IsBlacklisted(equippedItem)
                Debug.Trace("[SeverActions_Outfit] Undress: Skipping blacklisted " + equippedItem.GetName())
            ElseIf SeverActionsNativeExt.Native_IsDeviousDevice(equippedItem)
                Debug.Trace("[SeverActions_Outfit] Undress: Skipping Devious Device " + equippedItem.GetName())
            Else
                PlayUnequipAnimation(akActor, slotNames[i])
                ; preventEquip: DefaultOutfit must not re-equip it next AI tick
                akActor.UnequipItem(equippedItem, true, true)
                removedCount += 1
            EndIf
        endif
        i += 1
    endwhile
    
    ; The undress variant keeps DefaultOutfit suppressed: plain
    ; ClearLockedOutfit restores it on the base, and the engine re-dresses the
    ; NPC on the next AI evaluation.
    ClearLockedOutfitForUndress(akActor)

    ; Clear active preset — manual change
    SeverActionsNative.Native_Outfit_SetActivePreset(akActor, "")

    ResumeOutfitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] Removed " + removedCount + " items")
EndFunction

Bool Function Undress_IsEligible(Actor akActor)
{Alive, not outfit-excluded, outfit system on. The hotkey's gate: it keeps the
 hotkey from reporting an undress Undress_Execute would refuse.}
    if !akActor
        return false
    endif
    if akActor.IsDead()
        return false
    endif
    if !SeverActionsNativeExt2.Native_Outfit_IsSystemEnabled()
        return false
    endif
    if SeverActionsNative.Native_GetOutfitExcluded(akActor)
        return false
    endif
    return true
EndFunction

Bool Function RefuseIfOutfitExcluded(Actor akActor, String asOp)
    {True = refused, the caller returns. Called by every entry point right
     after its null check. Refuses an actor with the per-NPC outfit exclusion
     (FollowerData.outfitExcluded: the whole system leaves them alone) and the
     player (a target-less Actions-page verb defaults to them, and the lock
     path would strip their gear; the natives refuse 0x14 too).}
    If akActor == Game.GetPlayer()
        Debug.Trace("[SeverActions_Outfit] " + asOp + " refused - outfit actions never apply to the player")
        Return true
    EndIf
    If !akActor
        Return false
    EndIf
    If SeverActionsNative.Native_GetOutfitExcluded(akActor)
        Debug.Trace("[SeverActions_Outfit] " + asOp + " refused - " + akActor.GetDisplayName() + " is excluded from the outfit system")
        Return true
    EndIf
    Return false
EndFunction

Bool Function FormArrayContains(Form[] aArr, Form akForm)
    {True when aArr holds akForm. A None array or form is never a hit.}
    If !aArr || !akForm
        Return false
    EndIf
    Int i = 0
    While i < aArr.Length
        If aArr[i] == akForm
            Return true
        EndIf
        i += 1
    EndWhile
    Return false
EndFunction

Function _ClearDressStash(Actor akActor)
    {Forget what an Undress set aside for Dress: stashed pieces, DefaultOutfit
     backup, recorded preset index and name. Called when Dress consumes it and
     when a slot preset goes on (the preset is the dressed state). Find-only
     natives: never re-creates an erased OutfitDataStore row.}
    If !akActor
        Return
    EndIf
    SeverActionsNativeExt.Native_Outfit_DressStashClear(akActor)
    SeverActionsNativeExt.Native_Outfit_DressStashSetDefaultOutfit(akActor, None)
    StorageUtil.UnsetIntValue(akActor, "SeverActions_DressPresetIdx")
    StorageUtil.UnsetStringValue(akActor, "SeverActions_DressPresetName")
EndFunction

; =============================================================================
; ACTION: Dress
; YAML parameterMapping: [speaker]
; =============================================================================

Function Dress_Execute(Actor akActor)
    ; Master switch: see Undress_Execute.
    If !SeverActionsNativeExt2.Native_Outfit_IsSystemEnabled()
        Debug.Trace("[SeverActions_Outfit] refused - the outfit system is turned off")
        Return
    EndIf
    if !akActor
        return
    endif
    If RefuseIfOutfitExcluded(akActor, "Dress")
        Return
    EndIf

    ; A HELD slot preset (EquipArmor / UnequipArmor took over): dressed means
    ; back into that preset. ApplyPresetBySlot's same-index path puts every
    ; piece back (reusing catalog copies still in the pack) and ends the hold.
    ; Must run BEFORE BeginAdHocOutfitOp, whose teardown takes the held preset
    ; off whole and deletes its catalog copies.
    If SeverActionsNativeExt2.Native_OutfitSlot_IsActivePresetHeld(akActor)
        Int heldIdx = SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor)
        SeverActions_OutfitSlot heldSlotSys = GetSlotScript()
        If heldSlotSys && heldIdx >= 0
            StorageUtil.UnsetIntValue(akActor, "SeverActions_DressWasLocked")
            Debug.Trace("[SeverActions_Outfit] Dress: " + akActor.GetDisplayName() + " - re-applying held slot preset " + heldIdx)
            heldSlotSys.ApplyPresetBySlot(akActor, heldIdx)
            If SeverActionsNativeExt2.Native_OutfitSlot_IsActivePresetHeld(akActor)
                ; Still held = ApplyPresetBySlot refused before touching gear
                ; (no chest, empty, no stored items). Leave hold and stash.
                Debug.Trace("[SeverActions_Outfit] Dress: re-apply of held preset " + heldIdx + " refused - nothing changed")
            Else
                ; The preset is the dressed state: the stash is consumed, not
                ; re-equipped (the preset's enforcement would strip it again).
                _ClearDressStash(akActor)
            EndIf
            Return
        EndIf
    EndIf

    ; The slot preset Undress took off (the stash holds only the other
    ; pieces): re-apply it like the held branch. A refused re-apply (preset
    ; deleted or overwritten; the active index is left as it was) falls
    ; through to the stash.
    Int dressPresetIdx = StorageUtil.GetIntValue(akActor, "SeverActions_DressPresetIdx", -1)
    If dressPresetIdx >= 0 && SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor) >= 0
        ; A (non-held) preset went on since the Undress, by the auto-switch or
        ; the Outfits page, and dresses the NPC. The native apply ended the
        ; native half of the session; this ends the Papyrus half.
        Debug.Trace("[SeverActions_Outfit] Dress: " + akActor.GetDisplayName() + " - a preset went on since the undress, the undress session is over")
        _ClearDressStash(akActor)
        StorageUtil.UnsetIntValue(akActor, "SeverActions_DressWasLocked")
        Return
    EndIf
    If dressPresetIdx >= 0
        ; A deleted preset frees its index: re-apply only if the recorded name
        ; still sits there.
        String dressPresetName = StorageUtil.GetStringValue(akActor, "SeverActions_DressPresetName", "")
        If dressPresetName != "" && SeverActionsNative.Native_OutfitSlot_GetPresetName(akActor, dressPresetIdx) != dressPresetName
            Debug.Trace("[SeverActions_Outfit] Dress: preset " + dressPresetIdx + " is no longer '" + dressPresetName + "' - dressing from the stash instead")
            dressPresetIdx = -1
            StorageUtil.UnsetIntValue(akActor, "SeverActions_DressPresetIdx")
    StorageUtil.UnsetStringValue(akActor, "SeverActions_DressPresetName")
            StorageUtil.UnsetStringValue(akActor, "SeverActions_DressPresetName")
        EndIf
    EndIf
    If dressPresetIdx >= 0
        SeverActions_OutfitSlot undressSlotSys = GetSlotScript()
        If undressSlotSys && SeverActionsNative.Native_OutfitSlot_GetSlot(akActor) >= 0
            Debug.Trace("[SeverActions_Outfit] Dress: " + akActor.GetDisplayName() + " - re-applying slot preset " + dressPresetIdx + " worn before the undress")
            undressSlotSys.ApplyPresetBySlot(akActor, dressPresetIdx)
            If SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor) == dressPresetIdx
                StorageUtil.UnsetIntValue(akActor, "SeverActions_DressWasLocked")
                _ClearDressStash(akActor)
                Return
            EndIf
            Debug.Trace("[SeverActions_Outfit] Dress: re-apply of preset " + dressPresetIdx + " refused - dressing from the stash instead")
        EndIf
        StorageUtil.UnsetIntValue(akActor, "SeverActions_DressPresetIdx")
    StorageUtil.UnsetStringValue(akActor, "SeverActions_DressPresetName")
    EndIf

    BeginAdHocOutfitOp(akActor)
    Debug.Trace("[SeverActions_Outfit] Dress: " + akActor.GetDisplayName())

    ; Was the actor locked before the undress? Read and consumed here so every
    ; return below leaves it cleared. The flag is StorageUtil while the stash
    ; is cosaved (OTFT v6), so it can be missing (StorageUtil drops values on
    ; some installs, R14; or an older build fed the stash without it): then it
    ; reads as the lock's CURRENT state, so no lock is invented.
    Int dressWasLocked
    Bool lockActiveNow = SeverActionsNativeExt.Native_Outfit_IsLockActive(akActor)
    If StorageUtil.HasIntValue(akActor, "SeverActions_DressWasLocked")
        dressWasLocked = StorageUtil.GetIntValue(akActor, "SeverActions_DressWasLocked", 0)
    Else
        dressWasLocked = lockActiveNow as Int
    EndIf
    StorageUtil.UnsetIntValue(akActor, "SeverActions_DressWasLocked")

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
                ; Consume the parked suppressed-outfit entry, or the on-load
                ; re-suppression pass strips this dressed actor after a reload.
                ; ClearLock restores the same original (parked == backup).
                SeverActionsNative.Native_Outfit_ClearLock(akActor)
                ; No SnapshotLockedOutfit: SetOutfit is async and GetWornForm
                ; stale; the DefaultOutfit equips on the next AI tick.
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
                        ; The pause-safe native equips the actor's own enchanted,
                        ; tempered or renamed piece; Papyrus EquipItem on the
                        ; base form takes the plain copy.
                        SeverActionsNativeExt.Native_EquipItemNow(akActor, lockedItems[li])
                    Else
                        akActor.EquipItem(lockedItems[li], false, true)
                    EndIf
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

    ; Re-equip every stashed item the actor still holds; one they no longer
    ; carry is skipped, since EquipItem would conjure an unowned copy.
    Form[] equippedForms = new Form[32]
    Int equippedCount = 0
    Int missingCount = 0

    int i = 0
    while i < count
        Form item = stashed[i]
        if item
            if akActor.GetItemCount(item) <= 0
                missingCount += 1
                Debug.Trace("[SeverActions_Outfit] Dress: " + akActor.GetDisplayName() + " no longer holds stashed " + item.GetName() + " - skipped")
            else
                Armor armorItem = item as Armor
                if armorItem
                    String slotName = GetSlotNameFromMask(armorItem.GetSlotMask())
                    PlayEquipAnimation(akActor, slotName)
                    ; Their own piece, not the plain copy (see above).
                    SeverActionsNativeExt.Native_EquipItemNow(akActor, item)
                else
                    akActor.EquipItem(item, false, true)
                endif
                if equippedCount < 32
                    equippedForms[equippedCount] = item
                    equippedCount += 1
                endif
            endif
        endif
        i += 1
    endwhile

    _ClearDressStash(akActor)

    ; Re-lock only if the actor was locked before the undress (LockEquippedOutfit
    ; is a no-op unless OutfitLockEnabled). A lock still active took none of
    ; these pieces off (Undress clears the lock; UnequipArmor only drops pieces
    ; from it), so they merge back INTO it; a cleared one is re-created.
    if equippedCount > 0 && dressWasLocked != 0
        if lockActiveNow
            MergeIntoLockedOutfit(akActor, equippedForms, equippedCount)
        else
            LockEquippedOutfit(akActor, equippedForms, equippedCount)
        endif
    endif

    ; Release the DefaultOutfit Undress parked when no lock holds it, or the
    ; load-time pass re-nulls the base on every load. The native refuses while
    ; a lock or slot preset is active, so a re-created lock keeps its parking.
    If !SeverActionsNativeExt.Native_Outfit_IsLockActive(akActor)
        If SeverActionsNativeExt2.Native_Outfit_ReleaseDefaultOutfitSuppression(akActor)
            Debug.Trace("[SeverActions_Outfit] Dress: released the parked DefaultOutfit of " + akActor.GetDisplayName())
        EndIf
    EndIf

    ; Clear active preset — dressing from stashed items is a manual action.
    SeverActionsNative.Native_Outfit_SetActivePreset(akActor, "")

    ResumeOutfitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] Re-equipped " + equippedCount + " items (" + missingCount + " no longer held)")
EndFunction

Bool Function Dress_IsEligible(Actor akActor)
{Alive, not outfit-excluded, outfit system on (see Undress_IsEligible), and
 something to put back: stashed clothing, a held slot preset, the preset an
 Undress took off, or a saved DefaultOutfit.}
    if !akActor
        return false
    endif
    if akActor.IsDead()
        return false
    endif
    if !SeverActionsNativeExt2.Native_Outfit_IsSystemEnabled()
        return false
    endif
    if SeverActionsNative.Native_GetOutfitExcluded(akActor)
        return false
    endif
    ; A held slot preset: Dress re-applies it even with an empty stash.
    if SeverActionsNativeExt2.Native_OutfitSlot_IsActivePresetHeld(akActor)
        return true
    endif
    ; The preset Undress took off, unless one went on since (see Dress_Execute).
    if StorageUtil.GetIntValue(akActor, "SeverActions_DressPresetIdx", -1) >= 0 && SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor) < 0
        return true
    endif
    Form[] stashed = SeverActionsNativeExt.Native_Outfit_DressStashGet(akActor)
    if stashed && stashed.Length > 0
        return true
    endif
    ; Or a snapshotted DefaultOutfit.
    return SeverActionsNativeExt.Native_Outfit_DressStashGetDefaultOutfit(akActor) != None
EndFunction

; =============================================================================
; ACTION: EquipMultipleItems
; YAML parameterMapping: [speaker, itemNames] (a comma-separated list)
; =============================================================================

Function EquipMultipleItems_Execute(Actor akActor, String itemNames)
    ; Master switch: see Undress_Execute.
    If !SeverActionsNativeExt2.Native_Outfit_IsSystemEnabled()
        Debug.Trace("[SeverActions_Outfit] refused - the outfit system is turned off")
        Return
    EndIf
    if !akActor || itemNames == ""
        return
    endif
    If RefuseIfOutfitExcluded(akActor, "EquipMultipleItems")
        Return
    EndIf

    ; Per-item change: suspend only. Not BeginAdHocOutfitOp, whose teardown
    ; takes the whole active slot preset off before the item is even looked
    ; for; the preset is HELD below instead, once armor went on.
    SuspendOutfitLock(akActor)
    Debug.Trace("[SeverActions_Outfit] EquipMultipleItems: " + akActor.GetDisplayName() + " equipping '" + itemNames + "'")

    ; Read up front: the merge below runs only for an existing lock.
    Bool wasLocked = SeverActionsNativeExt.Native_Outfit_IsLockActive(akActor)

    Form[] equippedForms = new Form[32]
    Int count = 0
    ; Did worn ARMOR change? Only armor is the preset's business, so a weapon
    ; does not hold it - except a torch or two-hander (weapon types 5, 6, 7, 9:
    ; greatsword, axe/hammer, bow, crossbow) while a SHIELD is worn: it pushes
    ; the shield off, which the preset would undo.
    Bool armorChanged = false
    Bool shieldWorn = akActor.GetEquippedShield() != None
    String[] tokens = ParseCSVTrim(itemNames)
    Int ti = 0
    while ti < tokens.Length && count < 32
        Form equipped = EquipSingleItemAndReturn(akActor, tokens[ti])
        if equipped
            equippedForms[count] = equipped
            count += 1
            if equipped as Armor
                armorChanged = true
            elseif shieldWorn && equipped as Light
                armorChanged = true
            elseif shieldWorn
                Weapon handWeapon = equipped as Weapon
                if handWeapon
                    Int wType = handWeapon.GetWeaponType()
                    if wType == 5 || wType == 6 || wType == 7 || wType == 9
                        armorChanged = true
                    endif
                endif
            endif
        endif
        ti += 1
    endwhile

    ; HOLD, don't clear, an active slot preset: its other pieces stay on and it
    ; keeps its catalog copies, but the OutfitAlias and the 3D-load re-equip
    ; stop re-applying it (which would strip the new piece) until Dress or the
    ; next apply. Before the Resume, so the queued equip events see the hold.
    if armorChanged
        SeverActionsNativeExt2.Native_OutfitSlot_HoldActivePreset(akActor)
    endif

    ; An existing lock takes the new pieces in (MergeIntoLockedOutfit). No
    ; lock before = no lock after: locking is a separate gesture.
    if count > 0 && wasLocked
        MergeIntoLockedOutfit(akActor, equippedForms, count)
    endif

    ; A slot preset stays active here (held, or still enforced after a
    ; one-handed weapon), so its name stays; clear the name only without one.
    If SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor) < 0
        SeverActionsNative.Native_Outfit_SetActivePreset(akActor, "")
    EndIf

    ResumeOutfitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] EquipMultipleItems: Equipped " + count + " items")
EndFunction

; =============================================================================
; ACTION: UnequipMultipleItems
; YAML parameterMapping: [speaker, itemNames] (a comma-separated list)
; =============================================================================

Function UnequipMultipleItems_Execute(Actor akActor, String itemNames)
    ; Master switch: see Undress_Execute.
    If !SeverActionsNativeExt2.Native_Outfit_IsSystemEnabled()
        Debug.Trace("[SeverActions_Outfit] refused - the outfit system is turned off")
        Return
    EndIf
    if !akActor || itemNames == ""
        return
    endif
    If RefuseIfOutfitExcluded(akActor, "UnequipMultipleItems")
        Return
    EndIf

    ; Per-item change: suspend only (see EquipMultipleItems_Execute).
    SuspendOutfitLock(akActor)
    Debug.Trace("[SeverActions_Outfit] UnequipMultipleItems: " + akActor.GetDisplayName() + " removing '" + itemNames + "'")

    ; What came off, to drop from the lock list
    Form[] removedForms = new Form[32]
    Int removedCount = 0
    ; Only armor holds the preset (see EquipMultipleItems_Execute).
    Bool armorRemoved = false
    String[] tokens = ParseCSVTrim(itemNames)
    Int ti = 0
    while ti < tokens.Length && removedCount < 32
        Form removed = UnequipSingleItemInternal2(akActor, tokens[ti])
        if removed
            removedForms[removedCount] = removed
            removedCount += 1
            if removed as Armor
                armorRemoved = true
            endif
        endif
        ti += 1
    endwhile

    ; HOLD an active slot preset, or the OutfitAlias reads the queued unequip
    ; as a strip and puts the piece back. Before the Resume.
    if armorRemoved
        SeverActionsNativeExt2.Native_OutfitSlot_HoldActivePreset(akActor)
    endif

    ; Edit the lock list directly: UnequipItem is async, so a GetWornForm
    ; re-snapshot would still see the items as worn.
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
    ; Master switch: see Undress_Execute.
    If !SeverActionsNativeExt2.Native_Outfit_IsSystemEnabled()
        Debug.Trace("[SeverActions_Outfit] refused - the outfit system is turned off")
        Return
    EndIf
    if !akActor || presetName == ""
        return
    endif
    If RefuseIfOutfitExcluded(akActor, "SaveOutfitPreset")
        Return
    EndIf

    ; The one normalization of a typed name (the YAML and the Actions page call
    ; here; the DLL normalizes the wardrobe's names for OnPrismaBuilderSavePreset).
    presetName = NormalizePresetName(presetName)

    ; ── Slot path (eligible actors): a BGSOutfit+LeveledItem+Container triple ──
    ; On success the preset is ALSO written to the legacy store below as a
    ; mirror. Legacy only for ineligible actors or when all 8 slots are full.
    SeverActions_OutfitSlot slotSys = GetSlotScript()
    If slotSys && slotSys.IsSlotEligible(akActor)
        Int slotIdx = slotSys.AssignSlotToActor(akActor)
        If slotIdx >= 0
            Int presetIdx = slotSys.FindFreeOrReusableIndex(akActor, presetName)
            If presetIdx >= 0
                Form[] slotWorn = SeverActionsNative.Native_Outfit_GetWornArmor(akActor)
                Int slotKept = FilterDevicesInPlace(slotWorn)
                If slotWorn && slotKept > 0
                    slotSys.BuildPreset(akActor, presetIdx, slotWorn, presetName)
                    Debug.Trace("[SeverActions_Outfit] SaveOutfitPreset(slot): '" + presetName + "' idx=" + presetIdx + " for " + akActor.GetDisplayName())
                Else
                    Debug.Trace("[SeverActions_Outfit] SaveOutfitPreset(slot): Actor not wearing armor, refusing empty preset")
                    return
                EndIf
            Else
                Debug.Trace("[SeverActions_Outfit] SaveOutfitPreset(slot): All 8 slots full for " + akActor.GetDisplayName() + " - legacy path only")
            EndIf
        EndIf
    EndIf

    ; Legacy preset write (OutfitDataStore.presets via Begin/Add/Commit). An
    ; empty capture is refused like the slot branch's: it would blank a
    ; same-named preset and lock the NPC's DefaultOutfit away under nothing.
    Debug.Trace("[SeverActions_Outfit] SaveOutfitPreset: Saving '" + presetName + "' for " + akActor.GetDisplayName())
    Form[] wornForms = SeverActionsNative.Native_Outfit_GetWornArmor(akActor)
    Int savedKept = FilterDevicesInPlace(wornForms)
    If !wornForms || savedKept == 0
        Debug.Trace("[SeverActions_Outfit] SaveOutfitPreset: " + akActor.GetDisplayName() + " is not wearing armor - refusing an empty preset")
        return
    EndIf
    Int savedCount = wornForms.Length

    SeverActionsNative.Native_Outfit_BeginPreset(akActor, presetName)
    Int npi = 0
    While npi < savedCount && npi < 32
        if wornForms[npi]
            SeverActionsNative.Native_Outfit_AddPresetItem(akActor, wornForms[npi])
        endif
        npi += 1
    EndWhile
    SeverActionsNative.Native_Outfit_CommitPreset(akActor)

    ; Lock only where a lock belongs: an existing lock is rewritten to the
    ; saved pieces, a NEW one goes only on a current or former companion (a
    ; non-follower lock is never purged). LockEquippedOutfit keeps its own
    ; OutfitLockEnabled gate.
    If SeverActionsNativeExt.Native_Outfit_IsLockActive(akActor) || SeverActionsNativeExt.Native_GetIsFollower(akActor) || SeverActionsNativeExt2.Native_WasEverFollower(akActor)
        SuspendOutfitLock(akActor)
        LockEquippedOutfit(akActor, wornForms, savedCount)
        ResumeOutfitLock(akActor)
        Debug.Trace("[SeverActions_Outfit] SaveOutfitPreset: Saved and locked " + savedKept + " items as '" + presetName + "'")
    Else
        Debug.Trace("[SeverActions_Outfit] SaveOutfitPreset: Saved " + savedKept + " items as '" + presetName + "' - not locked (" + akActor.GetDisplayName() + " is not a companion and holds no lock)")
    EndIf
EndFunction

; =============================================================================
; ACTION: ApplyOutfitPreset
; YAML parameterMapping: [speaker, presetName]
; Removes current gear and equips all items from a saved preset
; =============================================================================

Function ApplyOutfitPreset_Execute(Actor akActor, String presetName)
    {The LLM's and the Actions page's entry: the one normalization of a typed
     name ("travel outfit" -> "travel"), then the shared body. The wardrobe's
     Apply (OnPrismaApplyPresetV2) calls the body directly with a name the DLL
     normalized: NormalizePresetName strips a suffix word per call, so a second
     pass breaks a stored name ("heavy armor" -> "heavy").}
    _ApplyOutfitPresetResolved(akActor, NormalizePresetName(presetName))
EndFunction

Function _ApplyOutfitPresetResolved(Actor akActor, String presetName)
    {Apply the preset named exactly presetName (no normalization). Resolution:
     an exact (case-insensitive) slot-store name, then an exact legacy name,
     and only when both miss the slot store's fuzzy tier. Every slot preset is
     mirrored into the legacy store, so an exact legacy hit after a slot miss
     is a preset only the legacy path can wear.}
    ; Master switch: see Undress_Execute.
    If !SeverActionsNativeExt2.Native_Outfit_IsSystemEnabled()
        Debug.Trace("[SeverActions_Outfit] refused - the outfit system is turned off")
        Return
    EndIf
    if !akActor || presetName == ""
        return
    endif
    If RefuseIfOutfitExcluded(akActor, "ApplyOutfitPreset")
        Return
    EndIf

    ; ── Resolve (see the docstring): exact slot, exact legacy, fuzzy slot ──
    SeverActions_OutfitSlot slotSys = GetSlotScript()
    Int presetIdx = -1
    Form[] presetItems
    If slotSys
        SeverActionsNative.Native_OutfitSlot_Log("ApplyOutfitPreset_Execute: Trying slot path for " + akActor.GetDisplayName() + " preset='" + presetName + "'")
        presetIdx = slotSys.FindPresetIndexExact(akActor, presetName)
        If presetIdx < 0
            presetItems = SeverActionsNative.Native_Outfit_GetPresetItems(akActor, presetName)
            If !presetItems || presetItems.Length == 0
                presetIdx = slotSys.FindPresetIndexByName(akActor, presetName)
            EndIf
        EndIf
        SeverActionsNative.Native_OutfitSlot_Log("ApplyOutfitPreset_Execute: slot resolution returned " + presetIdx)
    Else
        SeverActionsNative.Native_OutfitSlot_Log("ApplyOutfitPreset_Execute: WARNING slotSys is None - script not attached?")
    EndIf

    ; ── Slot path ──
    If presetIdx >= 0
        slotSys.ApplyPresetBySlot(akActor, presetIdx)
        Debug.Trace("[SeverActions_Outfit] ApplyOutfitPreset(slot): '" + presetName + "' idx=" + presetIdx + " on " + akActor.GetDisplayName())
        ; Applied (a refusal leaves the active index alone): the preset is the
        ; dressed state, so a pending Undress stash is consumed.
        If SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor) == presetIdx
            _ClearDressStash(akActor)
        EndIf
        ; A committed worn change: rebaseline any open wardrobe preview so the
        ; menu-close revert keeps it, and re-bake the mannequin. The wait lets
        ; the last DirectEquipPreset ops land in the biped before the re-scan.
        Utility.WaitMenuMode(0.2)
        SeverActionsNativeExt.Native_Preview_NotifyWornChanged(akActor)
        Return
    EndIf

    SeverActionsNative.Native_OutfitSlot_Log("ApplyOutfitPreset_Execute: Falling back to legacy path for " + akActor.GetDisplayName() + " preset='" + presetName + "'")

    ; Legacy fallback: items from OutfitDataStore (already read above when the
    ; slot script exists).
    If !presetItems
        presetItems = SeverActionsNative.Native_Outfit_GetPresetItems(akActor, presetName)
    EndIf
    Int count = 0
    if presetItems
        count = presetItems.Length
    endif
    if count == 0
        Debug.Trace("[SeverActions_Outfit] ApplyOutfitPreset: No preset '" + presetName + "' found for " + akActor.GetDisplayName())
        return
    endif

    ; An ad-hoc change relative to any active slot preset: without
    ; BeginAdHocOutfitOp the slot alias would re-enforce that preset over this.
    BeginAdHocOutfitOp(akActor)

    Debug.Trace("[SeverActions_Outfit] ApplyOutfitPreset: Applying '" + presetName + "' (" + count + " items) to " + akActor.GetDisplayName())

    ; Undress first, stashing the worn pieces for a follow-up Dress. Drop the
    ; whole earlier session and its lock flag first: an old DefaultOutfit
    ; backup would let Dress SetOutfit the base outfit over this preset.
    _ClearDressStash(akActor)
    StorageUtil.UnsetIntValue(akActor, "SeverActions_DressWasLocked")
    Form[] wornArmor = SeverActionsNative.Native_Outfit_GetWornArmor(akActor)
    If wornArmor
        Int wi = 0
        While wi < wornArmor.Length
            Armor equippedItem = wornArmor[wi] as Armor
            if equippedItem && !SeverActionsNative.Native_Blacklist_IsBlacklisted(equippedItem) && !SeverActionsNativeExt.Native_IsDeviousDevice(equippedItem)
                SeverActionsNativeExt.Native_Outfit_DressStashAdd(akActor, equippedItem)
                ; Pause-safe: Papyrus UnequipItem defers under the menu pause
                ; and fires at menu close against whatever is worn then.
                SeverActionsNativeExt.Native_UnequipItemNow(akActor, equippedItem)
            endif
            wi += 1
        EndWhile
    EndIf

    ; Equip every preset item.
    Form[] presetForms = new Form[32]
    Int equippedCount = 0
    int i = 0
    while i < count
        Form item = presetItems[i]
        ; Never mint a Devious Device (an old preset can list one; the native applies refuse too):
        ; a fresh rendered piece has no key, so nothing could take it off again.
        if item && akActor.GetItemCount(item) == 0 && SeverActionsNativeExt.Native_IsDeviousDevice(item)
            Debug.Trace("[SeverActions_Outfit] Preset apply: skipping Devious Device '" + item.GetName() + "' the actor no longer holds")
            item = None
        endif
        if item
            If akActor.GetItemCount(item) == 0
                akActor.AddItem(item, 1, true)
            EndIf
            Armor armorItem = item as Armor
            if armorItem
                String slotName = GetSlotNameFromMask(armorItem.GetSlotMask())
                PlayEquipAnimation(akActor, slotName)
                ; Pause-safe (see above); non-armor keeps EquipItem.
                SeverActionsNativeExt.Native_EquipItemNow(akActor, item)
            else
                akActor.EquipItem(item, false, true)
            endif
            if equippedCount < 32
                presetForms[equippedCount] = item
                equippedCount += 1
            endif
        endif
        i += 1
    endwhile

    ; Applying keeps the lock state: a locked actor's lock becomes the preset
    ; items, an unlocked one stays unlocked (locking is a separate gesture).
    Bool wasLocked = SeverActionsNativeExt.Native_Outfit_IsLockActive(akActor)
    If wasLocked
        ; Lock from known equipped items (avoids GetWornForm race condition)
        LockEquippedOutfit(akActor, presetForms, equippedCount)
    EndIf

    ; Track active preset for prompt context and situation system
    SeverActionsNative.Native_Outfit_SetActivePreset(akActor, presetName)

    ResumeOutfitLock(akActor)

    ; A situation apply that came due during the suspend was deferred (the
    ; native re-detects after 15 s); re-evaluating now closes that gap.
    SeverActionsNativeExt.SituationMonitor_ForceEvaluate(akActor)

    ; Committed worn change (see the slot path); give the equips a beat first.
    Utility.WaitMenuMode(0.3)
    SeverActionsNativeExt.Native_Preview_NotifyWornChanged(akActor)

    Debug.Trace("[SeverActions_Outfit] ApplyOutfitPreset: Equipped " + equippedCount + " items from '" + presetName + "'")
EndFunction

; =============================================================================
; INTERNAL HELPERS - item search and equip
; =============================================================================

String Function ResolveItemName(String itemName)
{For an OmniSight name like 'Black Leather Gauntlets (Akasha Gloves)', the
 game's own name in the parentheses; otherwise the input. Its callers search the
 whole name first: the parenthetical alone ("Blue" of "Dress (Blue)") matches
 anything in the pack that starts with it.}
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

String Function NormalizeItemSearchName(String itemName)
{Strip leading articles/possessives (the, a, an, his, her, their, your, my,
 our, its) and a trailing " please", which no item name contains and which
 defeat the native substring search. Only whole leading words go. A fallback
 after the exact phrasing, so it never widens a good match.}
    String s = TrimString(itemName)
    if s == ""
        return itemName
    endif
    ; Strip a trailing " please"
    String lowerFull = SeverActionsNative.StringToLower(s)
    Int fullLen = StringUtil.GetLength(lowerFull)
    if fullLen > 7 && StringUtil.Substring(lowerFull, fullLen - 7) == " please"
        s = TrimString(StringUtil.Substring(s, 0, fullLen - 7))
    endif
    ; Strip leading filler words one at a time (bounded)
    Int guard = 0
    Bool changed = true
    While changed && guard < 6
        changed = false
        guard += 1
        String lower = SeverActionsNative.StringToLower(s)
        Int sp = StringUtil.Find(lower, " ")
        if sp > 0
            String firstWord = StringUtil.Substring(lower, 0, sp)
            if firstWord == "the" || firstWord == "a" || firstWord == "an" || firstWord == "his" || firstWord == "her" || firstWord == "their" || firstWord == "your" || firstWord == "my" || firstWord == "our" || firstWord == "its"
                s = TrimString(StringUtil.Substring(s, sp + 1))
                changed = true
            endif
        endif
    EndWhile
    return s
EndFunction

Form Function FindWearableByName(Actor akActor, String searchName)
{FindItemByName restricted to what an outfit action may put on: Armor, a
 Weapon, a Light (torch) or Ammo. The native search is untyped (and ranks a
 prefix hit first), and EquipItem on an ingredient or potion makes the NPC
 consume it. Returns None, with a trace, when the best match is not wearable.}
    if !akActor || searchName == ""
        return None
    endif
    Form foundForm = SeverActionsNative.FindItemByName(akActor, searchName)
    if !foundForm
        return None
    endif
    if (foundForm as Armor) || (foundForm as Weapon) || (foundForm as Light) || (foundForm as Ammo)
        return foundForm
    endif
    Debug.Trace("[SeverActions_Outfit] EquipMultiple: '" + searchName + "' matched " + foundForm.GetName() + ", which is not armor, a weapon, a torch or ammo - not equipped")
    return None
EndFunction

Form Function EquipSingleItemAndReturn(Actor akActor, String itemName)
{Find a wearable by name and equip it; returns the Form or None. Name ladder:
 the whole name, the OmniSight parenthetical, then each with leading articles
 stripped. Armor goes through the pause-safe native, which equips the actor's
 own enchanted, tempered or renamed piece over a plain copy; anything else
 keeps EquipItem (the native is armor-only).}
    String parenName = ResolveItemName(itemName)
    Form foundForm = FindWearableByName(akActor, itemName)
    if !foundForm && parenName != itemName
        foundForm = FindWearableByName(akActor, parenName)
    endif
    ; Retry with leading articles stripped ("the steel gauntlets")
    if !foundForm
        String strippedName = NormalizeItemSearchName(itemName)
        if strippedName != itemName && strippedName != ""
            foundForm = FindWearableByName(akActor, strippedName)
        endif
    endif
    if !foundForm && parenName != itemName
        String strippedParen = NormalizeItemSearchName(parenName)
        if strippedParen != parenName && strippedParen != ""
            foundForm = FindWearableByName(akActor, strippedParen)
        endif
    endif
    if !foundForm
        Debug.Trace("[SeverActions_Outfit] EquipMultiple: '" + itemName + "' not found in inventory")
        return None
    endif

    if foundForm as Armor
        SeverActionsNativeExt.Native_EquipItemNow(akActor, foundForm)
    else
        akActor.EquipItem(foundForm, false, true)
    endif
    Debug.Trace("[SeverActions_Outfit] EquipMultiple: Equipped '" + foundForm.GetName() + "'")
    return foundForm
EndFunction

Form Function UnequipSingleItemInternal2(Actor akActor, String itemName)
{Search worn items in C++, unequip via Papyrus UnequipItem. Returns the Form removed, or None on failure.
 Same name ladder as EquipSingleItemAndReturn (whole name first). Searched parenthetical-first,
 "Take off Dress (Blue)" pulled off whichever worn item starts with "Blue".}
    String parenName = ResolveItemName(itemName)
    Form foundForm = SeverActionsNative.FindWornItemByName(akActor, itemName)
    if !foundForm && parenName != itemName
        foundForm = SeverActionsNative.FindWornItemByName(akActor, parenName)
    endif
    ; Retry with leading articles stripped ("her circlet")
    if !foundForm
        String strippedName = NormalizeItemSearchName(itemName)
        if strippedName != itemName && strippedName != ""
            foundForm = SeverActionsNative.FindWornItemByName(akActor, strippedName)
        endif
    endif
    if !foundForm && parenName != itemName
        String strippedParen = NormalizeItemSearchName(parenName)
        if strippedParen != parenName && strippedParen != ""
            foundForm = SeverActionsNative.FindWornItemByName(akActor, strippedParen)
        endif
    endif
    if !foundForm
        Debug.Trace("[SeverActions_Outfit] UnequipMultiple: '" + itemName + "' not worn")
        return None
    endif

    ; Never strip a Devious Device: it would pull off the rendered half while
    ; the locked token stays. Removal is DD's job (a key).
    If SeverActionsNativeExt.Native_IsDeviousDevice(foundForm)
        Debug.Trace("[SeverActions_Outfit] UnequipMultiple: '" + foundForm.GetName() + "' is a Devious Device - leaving it (remove via DD/key)")
        return None
    EndIf

    ; Stash unequipped armor for Dress, never a piece of the ACTIVE slot preset
    ; (its chest holds the form, OutfitAlias.OnObjectEquipped's test): Dress
    ; re-applies a held preset instead, and a stashed catalog piece would
    ; outlive the hold and come back as an untracked copy.
    Armor armorItem = foundForm as Armor
    if armorItem
        Bool presetPiece = false
        Int stashActiveIdx = SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor)
        if stashActiveIdx >= 0
            ObjectReference presetChest = SeverActionsNative.Native_OutfitSlot_GetContainer(SeverActionsNative.Native_OutfitSlot_GetSlot(akActor), stashActiveIdx)
            if presetChest && presetChest.GetItemCount(armorItem) > 0
                presetPiece = true
            endif
        endif
        if !presetPiece
            SeverActionsNativeExt.Native_Outfit_DressStashAdd(akActor, armorItem)
        endif
    endif

    akActor.UnequipItem(foundForm, true, true)
    Debug.Trace("[SeverActions_Outfit] UnequipMultiple: Unequipped '" + foundForm.GetName() + "'")
    return foundForm
EndFunction

Function RemoveFromLockedOutfit(Actor akActor, Form[] removedForms, Int count)
{Drop specific items from the locked outfit without re-snapshotting (avoids
 the GetWornForm race after the async UnequipItem).}
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
; OUTFIT LOCK - keeps a follower's (or an explicitly locked non-follower's)
; outfit across cell transitions. A suspend gates every OutfitAlias re-equip
; path (the OnObjectUnequipped debounce, and ReequipIfLocked on OnLoad /
; OnCellLoad / OnEnable) so the outfit system can swap armor freely.
; =============================================================================

; Unused: the 5-minute suspend watchdog lives in OutfitDataStore.h. Kept for
; old saves.
Float Property SuspendWatchdogSeconds = 300.0 Auto Hidden

Function SuspendOutfitLock(Actor akActor)
    {Suspend the actor's outfit lock (native SuspendUntil deadline; its
     5-minute watchdog self-clears).}
    if akActor
        SeverActionsNativeExt.Native_Outfit_SuspendLock(akActor)
    endif
EndFunction

Function BeginAdHocOutfitOp(Actor akActor)
    {Entry for a WHOLE-OUTFIT ad-hoc change (Undress, Dress, legacy
     ApplyOutfitPreset): deactivate any active slot preset so its enforcement
     doesn't undo the change, then suspend the lock; pair with
     ResumeOutfitLock. Not for a per-item change: the deactivation tears the
     whole preset down, so EquipMultipleItems / UnequipMultipleItems suspend
     and HOLD the preset instead (Native_OutfitSlot_HoldActivePreset).}
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
    {Clear the suspend (hard flag and any deadline) and the separate
     burst-strip suppression. After an op whose equips have JUST run (a native
     apply, a synchronous equip loop) use ResumeOutfitLockKeepGrace. Untokened:
     a long op's OWNED suspend (BuildPreset, ApplyPresetBySlot, the preset
     teardown) stays until that op ends; the burst state clears either way.}
    if akActor
        SeverActionsNativeExt.Native_Outfit_ResumeLock(akActor)
        SeverActionsNative.Native_Outfit_ClearBurstSuppression(akActor)
    endif
EndFunction

Function ResumeOutfitLockKeepGrace(Actor akActor, Int aiMs = 2000)
    {ResumeOutfitLock for an op that just ran a native apply or a synchronous
     equip loop: keeps an aiMs grace so the OutfitAlias events still queued for
     the op's own strips and equips read "suspended", not as external changes
     (3+ within 500 ms would latch burst suppression). Untokened like
     ResumeOutfitLock.}
    if akActor
        SeverActionsNativeExt2.Native_Outfit_ResumeLockKeepGrace(akActor, aiMs)
        SeverActionsNative.Native_Outfit_ClearBurstSuppression(akActor)
    endif
EndFunction

Bool Function IsOutfitOpSuspended(Actor akActor)
    {True while the actor's outfit lock is suspended. An expired watchdog
     deadline self-clears on read, so a stale suspend cannot stick.}
    if !akActor
        return false
    endif
    return SeverActionsNative.Native_Outfit_IsNativeSuspended(akActor)
EndFunction

; =============================================================================
; OUTFIT LOCK SNAPSHOT & REAPPLY
; =============================================================================

Function SnapshotLockedOutfit(Actor akActor)
    {Snapshot worn armor into the native lock, re-applied after cell
     transitions; any actor. Refused (trace, nothing written) when the outfit
     system or Outfit Lock is off, or only devices are worn. Callers:
     SetNonFollowerOutfitLock and OnPrismaSnapshot (after the DLL's own write).}
    if !akActor
        return
    endif

    ; Master switch: off locks nobody (the native snapshotOutfit already
    ; refuses a Snapshot Lock click; this is for other callers).
    if !SeverActionsNativeExt2.Native_Outfit_IsSystemEnabled()
        Debug.Trace("[SeverActions_Outfit] SnapshotLockedOutfit: the outfit system is turned off - no lock written for " + akActor.GetDisplayName())
        return
    endif

    if !OutfitLockEnabled
        Debug.Trace("[SeverActions_Outfit] SnapshotLockedOutfit: Outfit Lock is off - no lock written for " + akActor.GetDisplayName())
        return
    endif

    ; An empty capture is refused: CommitLock would activate an empty lock and
    ; park a unique NPC's DefaultOutfit under it.
    Form[] wornArmor = SeverActionsNative.Native_Outfit_GetWornArmor(akActor)
    if !wornArmor || FilterDevicesInPlace(wornArmor) == 0
        Debug.Trace("[SeverActions_Outfit] SnapshotLockedOutfit: " + akActor.GetDisplayName() + " is not wearing armor - no lock written")
        return
    endif
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
    {Silently re-equip the locked outfit (no animations). Called by the
     OutfitAlias on cell transitions and by the alias pool when it seats a
     loaded actor. Suspends the lock meanwhile so displaced items don't
     re-trigger it; skipped during an animation scene.}
    if !akActor || akActor.IsDead()
        return
    endif

    ; Master switch here, not only in the OutfitAlias callers: the pool's
    ; ReapplyLockedOutfitIfLoaded does not gate on it.
    if !SeverActionsNativeExt2.Native_Outfit_IsSystemEnabled()
        return
    endif

    ; The OutfitAlias re-equip's other gates, for the pool caller: excluded, a
    ; bondage mod's hold (DOM/PAH), an active slot preset (held or not, it owns
    ; the gear).
    if SeverActionsNative.Native_GetOutfitExcluded(akActor)
        return
    endif
    if SeverActionsNativeExt.Native_Outfit_IsExternallyControlled(akActor)
        return
    endif
    if SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor) >= 0
        return
    endif

    if !OutfitLockEnabled
        return
    endif

    if !SeverActionsNativeExt.Native_Outfit_IsLockActive(akActor)
        return
    endif

    ; Set by the SexLab/OStim scene hooks
    If AnimationSceneActive
        return
    EndIf

    ; Mid-operation: don't re-enter. The watchdog-aware check, so a dropped
    ; resume can't disable reapply for good.
    if IsOutfitOpSuspended(akActor)
        return
    endif

    Form[] lockedItems = SeverActionsNative.Native_Outfit_GetLockedItems(akActor)
    Int count = 0
    if lockedItems
        count = lockedItems.Length
    endif
    if count == 0
        return
    endif

    ; Bulk strip: none of the locked items worn means another mod stripped
    ; everything at once. Yield.
    Int wornCount = 0
    Int checkIdx = 0
    While checkIdx < count
        If lockedItems[checkIdx] && akActor.IsEquipped(lockedItems[checkIdx])
            wornCount += 1
        EndIf
        checkIdx += 1
    EndWhile

    If wornCount == 0 && count >= 1
        Debug.Trace("[SeverActions_Outfit] Bulk strip detected for " + akActor.GetDisplayName() + " - all " + count + " locked items removed. Yielding.")
        return
    EndIf

    Int protectedMask = SeverActionsNativeExt2.Native_Outfit_WornProtectedSlotMask(akActor)
    SuspendOutfitLock(akActor)

    Int equipped = 0
    int i = 0
    while i < count
        Form item = lockedItems[i]
        ; A piece already worn is left alone (no churn).
        if item && !akActor.IsEquipped(item)
            ; Pause-safe SYNCHRONOUS equip: the engine-queued EquipItem's events
            ; would land after the resume and read as an external change (a
            ; reapply thrash). Native_EquipItemNow applies inline with
            ; forceEquip, so they fire while suspended and the engine won't
            ; best-armor re-swap. Non-armor keeps EquipItem; its queued events
            ; land inside the resume's grace.
            Armor armorItem = item as Armor
            if armorItem
                ; A worn blacklisted piece or Devious Device covers this slot:
                ; leave the locked item off rather than push the protected
                ; piece off (the native re-equip's rule, same mask).
                if protectedMask != 0 && Math.LogicalAnd(armorItem.GetSlotMask(), protectedMask) != 0
                    Debug.Trace("[SeverActions_Outfit] Reapply: " + armorItem.GetName() + " left off - a protected piece covers its slot")
                else
                    SeverActionsNativeExt.Native_EquipItemNow(akActor, item)
                endif
            else
                akActor.EquipItem(item, false, true)
            endif
            equipped += 1
        endif
        i += 1
    endwhile

    ; Keep a 2 s grace over the equips that just ran (see the helper).
    ResumeOutfitLockKeepGrace(akActor, 2000)

    Debug.Trace("[SeverActions_Outfit] Reapplied locked outfit for " + akActor.GetDisplayName() + " (" + equipped + " of " + count + " items re-equipped)")
EndFunction

Function ClearLockedOutfit(Actor akActor)
    {Clear the native lock; the actor reverts to engine-default behavior.}
    if !akActor
        return
    endif
    SeverActionsNative.Native_Outfit_ClearLock(akActor)
    Debug.Trace("[SeverActions_Outfit] Cleared outfit lock for " + akActor.GetDisplayName())
EndFunction

Function ClearLockedOutfitForUndress(Actor akActor)
    {ClearLockedOutfit for Undress: releases the lock but keeps DefaultOutfit
     suppressed so the engine can't redress them on the next AI evaluation;
     the original stays parked natively for Dress or an explicit unlock.}
    if !akActor
        return
    endif
    SeverActionsNative.Native_Outfit_ClearLockForUndress(akActor)
    Debug.Trace("[SeverActions_Outfit] Cleared outfit lock (undress — DefaultOutfit stays suppressed) for " + akActor.GetDisplayName())
EndFunction

Int Function FilterDevicesInPlace(Form[] aWorn)
    {Null out Devious Devices in a worn-armor capture; returns the non-device
     count. A preset or lock must never hold a rendered device: re-applying
     would equip it outside the DD framework. Consumers (BuildPreset, the
     AddPresetItem loop, LockEquippedOutfit) skip None entries.}
    If !aWorn
        Return 0
    EndIf
    Int kept = 0
    Int i = 0
    While i < aWorn.Length
        If aWorn[i]
            If SeverActionsNativeExt.Native_IsDeviousDevice(aWorn[i])
                aWorn[i] = None
            Else
                kept += 1
            EndIf
        EndIf
        i += 1
    EndWhile
    Return kept
EndFunction

Function LockEquippedOutfit(Actor akActor, Form[] equippedItems, Int equippedCount)
    {Lock ONLY the given items (preset/builder semantics: other gear isn't
     locked), via Begin/Add/CommitLock. No-op unless OutfitLockEnabled.}
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

Function MergeIntoLockedOutfit(Actor akActor, Form[] newItems, Int newCount)
    {Take newItems into the actor's EXISTING lock: drop every locked entry a
     new item displaces (the same form, an Armor sharing a biped slot, or a
     locked shield when a two-hander or torch went on), keep the rest, append
     the new. Commits through LockEquippedOutfit (same gates). Call only when
     a lock was active before the equips: CommitLock would create one.}
    if !akActor || newCount <= 0
        return
    endif
    Form[] existing = SeverActionsNative.Native_Outfit_GetLockedItems(akActor)
    Int existingCount = 0
    If existing
        existingCount = existing.Length
    EndIf
    Form[] merged = Utility.CreateFormArray(existingCount + newCount)
    Int mergedCount = 0
    Int dropped = 0
    Int i = 0
    While i < existingCount
        If existing[i]
            If IsLockEntryDisplaced(existing[i], newItems, newCount)
                dropped += 1
            Else
                merged[mergedCount] = existing[i]
                mergedCount += 1
            EndIf
        EndIf
        i += 1
    EndWhile
    Int kept = mergedCount
    i = 0
    While i < newCount
        If newItems[i] && !FormArrayContains(merged, newItems[i])
            merged[mergedCount] = newItems[i]
            mergedCount += 1
        EndIf
        i += 1
    EndWhile
    Debug.Trace("[SeverActions_Outfit] MergeIntoLockedOutfit: " + akActor.GetDisplayName() + " - kept " + kept + ", dropped " + dropped + ", added " + (mergedCount - kept))
    LockEquippedOutfit(akActor, merged, mergedCount)
EndFunction

Bool Function IsLockEntryDisplaced(Form akLocked, Form[] newItems, Int newCount)
    {True when one of newItems takes akLocked's place on the actor - see
     MergeIntoLockedOutfit for the three cases.}
    Armor lockedArmor = akLocked as Armor
    Int lockedMask = 0
    If lockedArmor
        lockedMask = lockedArmor.GetSlotMask()
    EndIf
    Int j = 0
    While j < newCount
        Form newItem = newItems[j]
        If newItem
            If newItem == akLocked
                Return true
            EndIf
            If lockedArmor
                Armor newArmor = newItem as Armor
                If newArmor
                    If Math.LogicalAnd(lockedMask, newArmor.GetSlotMask()) != 0
                        Return true
                    EndIf
                ElseIf Math.LogicalAnd(lockedMask, 0x00000200) != 0
                    ; A locked SHIELD (slot 39) and a new left-hand taker.
                    If newItem as Light
                        Return true
                    EndIf
                    Weapon newWeapon = newItem as Weapon
                    If newWeapon
                        Int wType = newWeapon.GetWeaponType()
                        If wType == 5 || wType == 6 || wType == 7 || wType == 9
                            Return true
                        EndIf
                    EndIf
                EndIf
            EndIf
        EndIf
        j += 1
    EndWhile
    Return false
EndFunction

; =============================================================================
; OUTFIT ALIAS POOL - ReferenceAlias seats for outfit enforcement
; =============================================================================
;
; TWO POOLS SHARE THE SeverActions_OutfitAlias ALIASES - keep them disjoint.
;   * This pool: the 21 aliases of FollowerManager's OutfitSlots VMAD fill -
;     OutfitAlias10-20 (ids 69-79; 72 is spelled 'OutfiitAlias13' in the ESP)
;     and OutfitSlot00-09 (ids 30-39) - resolved by literal id (check 19; the
;     fill cannot move, DR6). Seats followers, legacy-locked actors and
;     slot-preset actors with no binding of their own.
;   * The slot-preset pool: SeverActions_OutfitSlot binds native slot N to
;     alias OutfitSlotNN (Native_OutfitSlot_GetAliasForSlot), 100 of them.
; Aliases 30-39 are native slots 0-9 (handed out lowest-first) and belong to
; the slot's OWNER: this pool never newly claims one (_outfitPoolIsNative),
; never clears an owner's, and skips actors bound through their own slot. A
; seat an older save left in a free native alias lasts until
; SeverActions_OutfitSlot claims the slot, re-binds the owner and sends
; SeverActions_OutfitAliasDisplaced to re-seat the displaced actor here. That
; leaves 11 claimable seats, so the load re-seat serves the neediest first.
;
; Driven by the provider's stage 2 (ReassignOutfitSlots, every load and new
; game), SeverActions_RosterChanged (from FollowerDataStore),
; SeverActions_OutfitAliasDisplaced and the MCM's non-follower lock toggle.

ReferenceAlias[] _outfitPool          ; the 21 aliases in the VMAD fill's order; built lazily
Bool[] _outfitPoolIsNative            ; parallel to _outfitPool; rebuilt on every load
Bool _poolBusy                        ; the pool lock (_PoolAcquire); reset by Maintenance

Function _PoolAcquire()
    {Serialise the pool's seat changes. The load re-seat, the roster and
     displaced events and the MCM toggle can interleave, and an alias call
     (GetActorRef, ForceRefTo) releases the script's lock between a duplicate
     check and the ForceRefTo, so two seatings of one actor could both pass.
     The flag's final check and set are atomic only while no external call
     sits between them. Bounded at ~10 s so a stale flag cannot wedge the
     pool (Maintenance also clears it: it rides the save).}
    Int waited = 0
    While _poolBusy && waited < 100
        Utility.WaitMenuMode(0.1)
        waited += 1
    EndWhile
    _poolBusy = true
EndFunction

Function _PoolLog(String msg)
    If SeverActionsNativeExt2.Settings_GetBool("debugMode")
        Debug.Trace("[SeverActions_Outfit] " + msg)
    EndIf
EndFunction

Function EnsureOutfitPool()
    {Resolve the pool's 21 aliases by id, in FollowerManager's OutfitSlots
     fill order. Once per instance (the array rides the save); a missing alias
     stays None and is skipped everywhere.}
    If _outfitPool && _outfitPool.Length == 21
        Return
    EndIf
    ReferenceAlias[] pool = new ReferenceAlias[21]
    pool[0] = Self.GetAlias(69) as ReferenceAlias
    pool[1] = Self.GetAlias(70) as ReferenceAlias
    pool[2] = Self.GetAlias(71) as ReferenceAlias
    pool[3] = Self.GetAlias(72) as ReferenceAlias
    pool[4] = Self.GetAlias(73) as ReferenceAlias
    pool[5] = Self.GetAlias(74) as ReferenceAlias
    pool[6] = Self.GetAlias(75) as ReferenceAlias
    pool[7] = Self.GetAlias(76) as ReferenceAlias
    pool[8] = Self.GetAlias(77) as ReferenceAlias
    pool[9] = Self.GetAlias(78) as ReferenceAlias
    pool[10] = Self.GetAlias(79) as ReferenceAlias
    pool[11] = Self.GetAlias(30) as ReferenceAlias
    pool[12] = Self.GetAlias(31) as ReferenceAlias
    pool[13] = Self.GetAlias(32) as ReferenceAlias
    pool[14] = Self.GetAlias(33) as ReferenceAlias
    pool[15] = Self.GetAlias(34) as ReferenceAlias
    pool[16] = Self.GetAlias(35) as ReferenceAlias
    pool[17] = Self.GetAlias(36) as ReferenceAlias
    pool[18] = Self.GetAlias(37) as ReferenceAlias
    pool[19] = Self.GetAlias(38) as ReferenceAlias
    pool[20] = Self.GetAlias(39) as ReferenceAlias
    _outfitPool = pool
EndFunction

Function EnsureOutfitAliasOwnership(Bool abRebuild = false)
    {Mark which pool entries are slot-preset aliases, asking the native store
     for every slot's alias so it follows the ESP rather than a hardcoded
     range. Rebuilt each load by ReassignOutfitSlots, else built lazily.}
    EnsureOutfitPool()
    If !_outfitPool
        Return
    EndIf
    If !abRebuild && _outfitPoolIsNative && _outfitPoolIsNative.Length == _outfitPool.Length
        Return
    EndIf
    Bool[] mask = Utility.CreateBoolArray(_outfitPool.Length)
    Int nativeCount = 0
    Int k = 0
    While k < 100   ; OutfitSlotStore kOutfitSlotCount
        ReferenceAlias slotAlias = SeverActionsNative.Native_OutfitSlot_GetAliasForSlot(k)
        If slotAlias
            Int i = 0
            While i < _outfitPool.Length
                If _outfitPool[i] == slotAlias
                    mask[i] = true
                    nativeCount += 1
                EndIf
                i += 1
            EndWhile
        EndIf
        k += 1
    EndWhile
    _outfitPoolIsNative = mask
    _PoolLog("Outfit alias pool: " + (_outfitPool.Length - nativeCount) + " claimable, " + nativeCount + " shared with slot presets (never newly claimed)")
EndFunction

Bool Function IsOwnNativeOutfitAlias(Actor akActor, ReferenceAlias akAlias)
    {True when akAlias is the alias of akActor's OWN native outfit slot - a
     binding SeverActions_OutfitSlot owns and releases.}
    If !akActor || !akAlias
        Return false
    EndIf
    Int slotIdx = SeverActionsNative.Native_OutfitSlot_GetSlot(akActor)
    Return slotIdx >= 0 && SeverActionsNative.Native_OutfitSlot_GetAliasForSlot(slotIdx) == akAlias
EndFunction

Bool Function IsBoundToOwnNativeOutfitAlias(Actor akActor)
    {True when akActor already receives OutfitAlias events through the alias of
     their own native outfit slot, so a seat in this pool would only double
     every event.}
    If !akActor
        Return false
    EndIf
    Int slotIdx = SeverActionsNative.Native_OutfitSlot_GetSlot(akActor)
    If slotIdx < 0
        Return false
    EndIf
    ReferenceAlias slotAlias = SeverActionsNative.Native_OutfitSlot_GetAliasForSlot(slotIdx)
    Return slotAlias && slotAlias.GetActorRef() == akActor
EndFunction

Bool Function ActorNeedsOutfitSeat(Actor akActor)
    {True while akActor's outfit still wants OutfitAlias events from this pool:
     a registered follower (a lock can land on them at any time), an active
     legacy lock, or an active slot preset with no binding of its own. Never an
     outfit-excluded or dead actor.}
    If !akActor || akActor.IsDead() || SeverActionsNative.Native_GetOutfitExcluded(akActor)
        Return false
    EndIf
    If SeverActionsNativeExt.Native_GetIsFollower(akActor)
        Return true
    EndIf
    If SeverActionsNativeExt.Native_Outfit_IsLockActive(akActor)
        Return true
    EndIf
    Return SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor) >= 0 && !IsBoundToOwnNativeOutfitAlias(akActor)
EndFunction

Function AssignOutfitSlot(Actor akActor)
    {Seat akActor in this pool (under the pool lock); see _AssignOutfitSlotLocked.}
    _PoolAcquire()
    _AssignOutfitSlotLocked(akActor)
    _poolBusy = false
EndFunction

Function _AssignOutfitSlotLocked(Actor akActor)
    {Seat akActor in a free alias of this pool (never a shared slot-preset
     alias). The caller holds the pool lock.}
    EnsureOutfitAliasOwnership()
    If !_outfitPool || !akActor
        Return
    EndIf

    If SeverActionsNative.Native_GetOutfitExcluded(akActor)
        _PoolLog("Outfit excluded: " + akActor.GetDisplayName() + " - no outfit seat")
        Return
    EndIf

    ; Guard against a duplicate seat
    Int check = 0
    While check < _outfitPool.Length
        If _outfitPool[check] && _outfitPool[check].GetActorRef() == akActor
            Return
        EndIf
        check += 1
    EndWhile

    ; Already bound through their own slot-preset alias: the events arrive
    ; there. Still re-apply now if loaded, as a fresh seat below would.
    If IsBoundToOwnNativeOutfitAlias(akActor)
        _PoolLog("Outfit events for " + akActor.GetDisplayName() + " already come from their slot-preset alias - no extra seat")
        ReapplyLockedOutfitIfLoaded(akActor)
        Return
    EndIf

    Int i = 0
    While i < _outfitPool.Length
        If _outfitPool[i] && !_outfitPoolIsNative[i] && !_outfitPool[i].GetActorRef()
            _outfitPool[i].ForceRefTo(akActor)
            _PoolLog("Outfit seat " + i + " assigned to " + akActor.GetDisplayName())
            ReapplyLockedOutfitIfLoaded(akActor)
            Return
        EndIf
        i += 1
    EndWhile

    _PoolLog("WARNING: No free outfit seat for " + akActor.GetDisplayName())
EndFunction

Function ReapplyLockedOutfitIfLoaded(Actor akActor)
    {OnLoad won't fire for an actor whose 3D is already up when they are seated,
     so re-apply the legacy locked outfit directly. ReapplyLockedOutfit makes
     every gate the alias makes.}
    If akActor && akActor.Is3DLoaded()
        ReapplyLockedOutfit(akActor)
    EndIf
EndFunction

Function ClearOutfitSlot(Actor akActor)
    {Clear akActor's seat(s) (under the pool lock); see _ClearOutfitSlotLocked.}
    _PoolAcquire()
    _ClearOutfitSlotLocked(akActor)
    _poolBusy = false
EndFunction

Function _ClearOutfitSlotLocked(Actor akActor)
    {Clear this pool's seat(s) for akActor; the caller holds the pool lock.
     Never clears the alias of the actor's own native outfit slot:
     SeverActions_OutfitSlot owns that binding (ReleaseSlotFromActor).}
    EnsureOutfitPool()
    If !_outfitPool || !akActor
        Return
    EndIf
    Int i = 0
    While i < _outfitPool.Length
        If _outfitPool[i] && _outfitPool[i].GetActorRef() == akActor
            If IsOwnNativeOutfitAlias(akActor, _outfitPool[i])
                _PoolLog("Outfit seat " + i + " is " + akActor.GetDisplayName() + "'s own slot-preset alias - left bound")
            Else
                _outfitPool[i].Clear()
                _PoolLog("Outfit seat " + i + " cleared for " + akActor.GetDisplayName())
            EndIf
        EndIf
        i += 1
    EndWhile
EndFunction

Event OnOutfitAliasDisplaced(string eventName, string strArg, float numArg, Form sender)
    {SeverActions_OutfitSlot re-bound a native slot's alias to its owner and
     pushed out a seat an older save had placed there (sender = that actor).
     Re-seat them here if they still need a seat. Keeps the callback name of
     the FollowerManager handler it replaces, so an older save's (form, event)
     registration is delivered here.}
    Actor displaced = sender as Actor
    If ActorNeedsOutfitSeat(displaced)
        AssignOutfitSlot(displaced)
    EndIf
EndEvent

Event OnRosterChanged_Outfit(String eventName, String strArg, Float numArg, Form sender)
    {The native roster event (FollowerDataStore): strArg "added" (became a
     registered follower), "removed" (dismiss or soft reset) or "purged" (row
     erased: death, force-remove); sender = the actor. Fire-and-forget (DR13):
     each case reads the actor's state NOW, so a late or repeated event settles
     to the same seat. A dismissed follower keeps a seat while a lock or preset
     needs one (the Actions-page soft reset clears a legacy lock first, so
     there only a preset keeps it), until a load's re-seat ranks them lower
     (ReassignOutfitSlots).}
    Actor akActor = sender as Actor
    If !akActor
        Return
    EndIf
    If strArg == "purged"
        ClearOutfitSlot(akActor)
        ; A DEAD purged follower also gives back their outfit slot (its
        ; wardrobe chests and the OutfitSlotNN alias that keeps the corpse
        ; persistent): ReleaseOrphanedSlots keeps any slot with presets, so the
        ; 100-slot pool would fill with the dead. A LIVING purged actor
        ; (force-remove) keeps it; the slot persists through re-recruit.
        If akActor.IsDead()
            SeverActions_OutfitSlot purgeSlotSys = GetSlotScript()
            If purgeSlotSys && SeverActionsNative.Native_OutfitSlot_GetSlot(akActor) >= 0
                Debug.Trace("[SeverActions_Outfit] Roster purge of dead " + akActor.GetDisplayName() + " - releasing their outfit slot")
                purgeSlotSys.ReleaseSlotFromActor(akActor)
            EndIf
        EndIf
    ElseIf ActorNeedsOutfitSeat(akActor)
        AssignOutfitSlot(akActor)
    Else
        ClearOutfitSlot(akActor)
    EndIf
EndEvent

Int Function _SeatEach(Actor[] actors)
    Int n = 0
    If !actors
        Return 0
    EndIf
    Int i = 0
    While i < actors.Length
        If actors[i] && ActorNeedsOutfitSeat(actors[i])
            _AssignOutfitSlotLocked(actors[i])
            n += 1
        EndIf
        i += 1
    EndWhile
    Return n
EndFunction

Int Function _SeatLockedByRoster(Actor[] actors, Bool abFollowers)
    {_SeatEach over the actors whose Native_GetIsFollower equals abFollowers,
     so ReassignOutfitSlots can seat locked current followers and other locked
     actors in separate passes. The caller holds the pool lock.}
    Int n = 0
    If !actors
        Return 0
    EndIf
    Int i = 0
    While i < actors.Length
        If actors[i] && SeverActionsNativeExt.Native_GetIsFollower(actors[i]) == abFollowers && ActorNeedsOutfitSeat(actors[i])
            _AssignOutfitSlotLocked(actors[i])
            n += 1
        EndIf
        i += 1
    EndWhile
    Return n
EndFunction

Function ReassignOutfitSlots(Actor[] followers)
    {Re-seat this pool after a load or on a new game (the provider's stage 2,
     after OutfitSlot's Maintenance re-bound the native slot owners). Only 11
     aliases can be claimed, so actors are seated in this order:
       1. CURRENT followers with an active legacy lock;
       2. slot-preset actors with no binding of their own;
       3. other actors with an active lock (dismissed followers, non-followers);
       4. the remaining followers.
     A lock or preset outranks a follower who needs no seat for one, and
     current followers' locks outrank dismissed ones, so locked ex-followers
     cannot take the pool from the live roster. An unseated actor is still
     enforced by the native 3D-load re-equip (OutfitDataStore's
     TESObjectLoadedEvent sink); a seat adds the alias's own events (instant
     re-equip when a locked piece comes off, the OnLoad / OnCellLoad
     re-apply). Between loads seats are first come first served. Holds the
     pool lock throughout, so a roster or displaced event landing meanwhile
     seats its actor after this pass.}
    _PoolAcquire()
    EnsureOutfitAliasOwnership(true)
    If !_outfitPool
        _poolBusy = false
        Return
    EndIf

    ; Clear this pool's own seats first. Shared slot-preset aliases stay as they
    ; are: a native owner's binding is not ours to drop, and an older save's
    ; seat there is settled by the sweep at the end.
    Int i = 0
    While i < _outfitPool.Length
        If _outfitPool[i] && !_outfitPoolIsNative[i]
            _outfitPool[i].Clear()
        EndIf
        i += 1
    EndWhile

    Actor[] locked = GetOutfitLockedActors()
    Int seatedLockedFollowers = _SeatLockedByRoster(locked, true)
    Int seatedPreset = _SeatEach(SeverActionsNativeExt2.Native_OutfitSlot_GetActorsWithActivePreset())
    Int seatedLockedOthers = _SeatLockedByRoster(locked, false)
    Int seatedFollowers = _SeatEach(followers)

    ; Settle seats an older save left in shared slot-preset aliases (the only
    ; kind this pass did not clear). Keep one while its actor still needs a seat
    ; and has no binding of their own; drop it otherwise.
    Int dropped = 0
    i = 0
    While i < _outfitPool.Length
        If _outfitPool[i] && _outfitPoolIsNative[i]
            Actor occupant = _outfitPool[i].GetActorRef()
            If occupant && !IsOwnNativeOutfitAlias(occupant, _outfitPool[i])
                If !ActorNeedsOutfitSeat(occupant) || IsBoundToOwnNativeOutfitAlias(occupant)
                    _outfitPool[i].Clear()
                    dropped += 1
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile

    _poolBusy = false
    _PoolLog("Outfit alias pool re-seated: " + seatedLockedFollowers + " followers with a lock, " + seatedPreset + " with a slot preset, " + seatedLockedOthers + " other actors with a lock, " + seatedFollowers + " followers asked for a seat (an actor in two lists is seated once); dropped " + dropped + " stale seat(s) in shared slot-preset aliases")
EndFunction

; =============================================================================
; NON-FOLLOWER OUTFIT LOCK
; =============================================================================

Bool Function IsOutfitLockEligible(Actor akActor)
    {Safe-exit stub; it had no caller.}
    ; M-I-STUB 3.9.14-beta25 (P10-02): dead code (no caller); answers False
    Return false
EndFunction
Function SetNonFollowerOutfitLock(Actor akActor, Bool enable)
    {Enable snapshots the worn outfit as a lock marked non-follower; disable
     clears the lock. Enable is REFUSED (a trace, nothing written) while the
     outfit system or Outfit Lock is off, or the actor wears no armor, so the
     caller must read HasNonFollowerOutfitLock afterwards for the truth.}
    if !akActor
        return
    endif
    if enable
        if !SeverActionsNativeExt2.Native_Outfit_IsSystemEnabled()
            Debug.Trace("[SeverActions_Outfit] Non-follower outfit lock refused for " + akActor.GetDisplayName() + " - the outfit system is turned off")
            return
        endif
        if !OutfitLockEnabled
            Debug.Trace("[SeverActions_Outfit] Non-follower outfit lock refused for " + akActor.GetDisplayName() + " - Outfit Lock is off")
            return
        endif
        SnapshotLockedOutfit(akActor)  ; refuses an empty capture
        if !SeverActionsNativeExt.Native_Outfit_IsLockActive(akActor)
            Debug.Trace("[SeverActions_Outfit] Non-follower outfit lock NOT written for " + akActor.GetDisplayName())
            return
        endif
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
    {True only if a lock is active AND it is not follower-locked.}
    if !akActor
        return false
    endif
    if !SeverActionsNativeExt.Native_Outfit_IsLockActive(akActor)
        return false
    endif
    return !SeverActionsNativeExt.Native_Outfit_IsFollowerLock(akActor)
EndFunction

; =============================================================================
; OUTFIT-LOCKED ACTOR TRACKING (the native OutfitDataStore is the source of truth)
; =============================================================================

; OUTFIT_TRACKED_KEY: the legacy StorageUtil FormList of locked actors. Read
; only by MigrateOutfitDataToNative (native schema below 3) and cleared by the
; nuke handler, but still WRITTEN as a mirror by OnPrismaBuilderEquip, so it
; grows on every install. Enforcement (OutfitAlias, ReapplyLockedOutfit)
; reads native only, never this or the per-actor SeverOutfit_Locked_ /
; LockActive mirrors.
String Property OUTFIT_TRACKED_KEY = "SeverOutfit_TrackedActors" AutoReadOnly Hidden

Function TrackOutfitLockedActor(Actor akActor)
    {Safe-exit stub; it was already a no-op.}
    ; M-I-STUB 3.9.14-beta25 (P10-02): dead code (a no-op; its call site is gone)
EndFunction
Function UntrackOutfitLockedActor(Actor akActor)
    {Safe-exit stub: see TrackOutfitLockedActor.}
    ; M-I-STUB 3.9.14-beta25 (P10-02): dead code (a no-op; its call site is gone)
EndFunction
Actor[] Function GetOutfitLockedActors()
    {Every actor in OutfitDataStore with an active lock (for
     ReassignOutfitSlots).}
    return SeverActionsNativeExt.Native_Outfit_GetActorsWithLocks()
EndFunction

; =============================================================================
; OUTFIT PRESET UTILITIES
; =============================================================================

String[] Function GetPresetNames(Actor akActor)
    {User-visible preset names: skips "_"-prefixed internal entries such as
     the situation system's auto-saved "_default" baseline.}
    if !akActor
        return PapyrusUtil.StringArray(0)
    endif
    Int count = SeverActionsNative.Native_Outfit_GetPresetCount(akActor)
    if count <= 0
        return PapyrusUtil.StringArray(0)
    endif
    ; First pass sizes the result.
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
    {Item count of a saved preset, 0 if not found. No caller (the MCM has its
     own PresetItemCount); kept for old saves' frames and third-party callers.}
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
    {Delete a preset from OutfitDataStore (which also clears an
     activePresetName / situationPresets entry naming it) and from the slot
     system. presetName is a STORED name, used verbatim (the MCM passes store
     names, OnPrismaDeletePreset the DLL's once-normalized name; no LLM action
     deletes presets): normalizing again would strip a second suffix word
     ("heavy armor" -> "heavy") and delete the wrong preset. Both stores match
     case-insensitively.}
    if !akActor || presetName == ""
        return
    endif

    SeverActionsNative.Native_Outfit_DeletePreset(akActor, presetName)

    SeverActions_OutfitSlot slotSys = GetSlotScript()
    if slotSys
        slotSys.DeletePresetFromSlot(akActor, presetName)
    endif

    if SeverActionsNative.Native_Outfit_GetPresetCount(akActor) <= 0
        if HasNonFollowerOutfitLock(akActor)
            SetNonFollowerOutfitLock(akActor, false)
        endif
    endif

    Debug.Trace("[SeverActions_Outfit] DeletePreset: Deleted '" + presetName + "' for " + akActor.GetDisplayName())
EndFunction

Function SavePresetToNativeStore(Actor akActor, String presetName, Form[] items, Int itemCount)
    {Mirror a slot-built preset into OutfitDataStore ('OTFT'); called by
     SeverActions_OutfitSlot.BuildPreset so the preset survives a dropped slot
     record. Silent on errors.}
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
; MIGRATION: StorageUtil -> native OutfitDataStore
; =============================================================================

Function MigrateOutfitDataToNative()
    {Import legacy StorageUtil outfit state into OutfitDataStore where native
     is empty; native wins every conflict and each disagreement logs an
     [OutfitMigration] line. Runs every load (the provider's stage 2) and on
     the Outfits page's request. Gated on the native schemaVersion (< 3 runs),
     not a StorageUtil flag, which a wipe of the legacy store would lose.}

    Int schemaVer = SeverActionsNativeExt.Native_Outfit_GetSchemaVersion()
    if schemaVer >= 3
        Debug.Trace("[OutfitMigration] schemaVersion=" + schemaVer + " - already imported, skipping")
        return
    endif

    Debug.Trace("[OutfitMigration] schemaVersion=0 - starting native-wins import")
    Int importedLocks = 0
    Int skippedLocks = 0
    Int importedPresets = 0
    Int skippedPresets = 0
    Int importedSituations = 0
    Int skippedSituations = 0

    ; --- Locked outfits ---
    ; From the legacy FormList, not GetOutfitLockedActors() (native): the
    ; import exists to find actors only legacy storage holds.
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
                ; Native wins; log the size delta as evidence.
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

            ; --- Presets for this actor (the legacy StringList; GetPresetNames reads native) ---
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

    ; --- Preset-only actors (not locked), from the legacy PresetActors list ---
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

            ; Per-actor auto-switch: native defaults true, so write only a
            ; definite legacy 0 (absent reads -1).
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

    ; Legacy SeverOutfit_NonFollowerLock -> isFollowerLock=false (native
    ; default true), over the same union of actors.
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

    ; Cosaved: later loads return at the top.
    SeverActionsNativeExt.Native_Outfit_SetSchemaVersion(3)

    Debug.Trace("[OutfitMigration] Done. imported=[locks:" + importedLocks + ", presets:" + importedPresets + ", situations:" + importedSituations + ", non-follower-locks:" + nflImported + "] native-wins-skipped=[locks:" + skippedLocks + ", presets:" + skippedPresets + ", situations:" + skippedSituations + "]")
EndFunction

Actor[] Function GetPresetActors()
    {Every actor with at least one user-visible preset in OutfitDataStore.
     Called by SeverActions_OutfitSlot.MigrateToOutfitSlotSystem.}
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
 to match the storage limits used by callers (preset/lock FormLists).}
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
    return SeverActionsNative.StringToLower(text)
EndFunction

String Function NormalizePresetName(String name)
{Lower-case, trim and strip ONE trailing word LLMs append to preset names
 ("travel outfit" -> "travel", "formal clothes" -> "formal"); a clean name
 passes unchanged.}
    name = TrimString(StringToLower(name))
    Int len = StringUtil.GetLength(name)
    if len == 0
        return ""
    endif

    ; Longest first; only the first match is stripped.
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
{Normalize an LLM-provided situation name to one of the SEVEN situations
 SituationMonitor::DetectSituation can produce - combat, sleep, rain, snow,
 home, town, adventure - after stripping leading filler ("at home", "when
 sleeping") and mapping synonyms ("city" -> "town", "dungeon" -> "adventure").
 Anything else returns "", which the callers refuse with a trace: a rule on a
 situation the monitor never detects would never fire.}
    situation = TrimString(StringToLower(situation))
    ; Strip leading filler words, one at a time (bounded).
    Int guard = 0
    Bool changed = true
    While changed && guard < 6 && situation != ""
        changed = false
        guard += 1
        Int sp = StringUtil.Find(situation, " ")
        if sp > 0
            String firstWord = StringUtil.Substring(situation, 0, sp)
            if firstWord == "at" || firstWord == "in" || firstWord == "on" || firstWord == "to" || firstWord == "into" || firstWord == "for" \
                || firstWord == "of" || firstWord == "with" || firstWord == "the" || firstWord == "a" || firstWord == "an" \
                || firstWord == "when" || firstWord == "while" || firstWord == "during" || firstWord == "my" || firstWord == "our" \
                || firstWord == "your" || firstWord == "their" || firstWord == "going" || firstWord == "out" || firstWord == "we" \
                || firstWord == "are" || firstWord == "is" || firstWord == "i" || firstWord == "am" || firstWord == "it" || firstWord == "its"
                situation = TrimString(StringUtil.Substring(situation, sp + 1))
                changed = true
            endif
        endif
    EndWhile
    if situation == "town" || situation == "city" || situation == "village" || situation == "settlement" || situation == "urban" \
        || situation == "towns" || situation == "cities"
        return "town"
    elseif situation == "adventure" || situation == "outdoor" || situation == "outdoors" || situation == "dungeon" || situation == "dungeons" \
        || situation == "exploring" || situation == "adventuring" || situation == "wilderness" || situation == "wild" \
        || situation == "travel" || situation == "traveling" || situation == "travelling" || situation == "road" || situation == "roads" \
        || situation == "journey" || situation == "journeying" || situation == "questing" || situation == "outside" || situation == "default"
        return "adventure"
    elseif situation == "sleep" || situation == "sleeping" || situation == "asleep" || situation == "bed" || situation == "rest" \
        || situation == "resting" || situation == "bedtime" || situation == "night" || situation == "nighttime"
        return "sleep"
    elseif situation == "combat" || situation == "fight" || situation == "fighting" || situation == "battle" || situation == "war" \
        || situation == "danger"
        return "combat"
    elseif situation == "home" || situation == "house" || situation == "dwelling" || situation == "residence" || situation == "homes"
        return "home"
    elseif situation == "rain" || situation == "rainy" || situation == "raining" || situation == "storm" || situation == "stormy" \
        || situation == "wet"
        return "rain"
    elseif situation == "snow" || situation == "snowy" || situation == "snowing" || situation == "blizzard" || situation == "cold" \
        || situation == "winter"
        return "snow"
    endif
    return ""
EndFunction

Function SetSituationPreset_Execute(Actor akActor, String situation, String presetName)
{LLM action (and the Actions page's setSituationOutfit): assign an outfit
 preset to a situation. Normalizes the typed preset name ONCE; the Outfits
 page (OnPrismaSetSitPreset) calls the body directly with the DLL's
 once-normalized name (see ApplyOutfitPreset_Execute).}
    _SetSituationPresetResolved(akActor, situation, NormalizePresetName(presetName))
EndFunction

Function _SetSituationPresetResolved(Actor akActor, String situation, String presetName)
    {Map situation to the preset named presetName (no name normalization
     here; the situation word is canonicalized, which is idempotent).}
    ; Master switch: see Undress_Execute.
    If !SeverActionsNativeExt2.Native_Outfit_IsSystemEnabled()
        Debug.Trace("[SeverActions_Outfit] refused - the outfit system is turned off")
        Return
    EndIf
    if !akActor || situation == "" || presetName == ""
        return
    endif
    If RefuseIfOutfitExcluded(akActor, "SetSituationPreset")
        Return
    EndIf
    String situationAsked = situation
    situation = NormalizeSituation(situation)
    If situation == ""
        Debug.Trace("[SeverActions_Outfit] SetSituationPreset: '" + situationAsked + "' is not a situation the monitor detects (combat, sleep, rain, snow, home, town, adventure) - nothing mapped for " + akActor.GetDisplayName())
        Return
    EndIf

    ; ── Slot system, and the name map the auto-switch reads ──
    ; The native SituationMonitor reads ONLY the legacy name map
    ; (OutfitDataStore.situationPresets) and applies that name through the
    ; slot store by exact (case-insensitive) match. So the preset is resolved
    ; once (exact, or the single fuzzy candidate) and BOTH maps get it, the
    ; name map with the preset's STORED name.
    SeverActions_OutfitSlot slotSys = GetSlotScript()
    If slotSys
        Int sitPresetIdx = ResolveSituationPresetIndex(slotSys, akActor, presetName)
        If sitPresetIdx >= 0
            String storedName = SeverActionsNative.Native_OutfitSlot_GetPresetName(akActor, sitPresetIdx)
            If storedName == ""
                storedName = presetName
            EndIf
            SeverActionsNative.Native_OutfitSlot_SetSituationPreset(akActor, situation, sitPresetIdx)
            SeverActionsNative.Native_Outfit_SetSituationPreset(akActor, situation, storedName)
            ; A rule for the situation they are already in applies at the next
            ; scan instead of after they leave and return.
            SeverActionsNativeExt2.SituationMonitor_ResetActorSituation(akActor)
            Debug.Trace("[SeverActions_Outfit] SetSituationPreset(slot): " + akActor.GetDisplayName() + " - " + situation + " -> idx " + sitPresetIdx + " ('" + storedName + "', asked for '" + presetName + "')")
            Return
        EndIf
    EndIf

    ; ── Legacy preset path (OutfitDataStore situation->preset map) ──
    ; The "preset exists" test reads native; GetPresetItems is empty if absent.
    Form[] legacyItems = SeverActionsNative.Native_Outfit_GetPresetItems(akActor, presetName)
    if legacyItems.Length == 0
        Debug.Trace("[SeverActions_Outfit] SetSituationPreset: '" + presetName + "' is not a preset of " + akActor.GetDisplayName() + " in either store - nothing mapped")
        return
    endif

    SeverActionsNative.Native_Outfit_SetSituationPreset(akActor, situation, presetName)
    SeverActionsNativeExt2.SituationMonitor_ResetActorSituation(akActor)
    Debug.Trace("[SeverActions_Outfit] SetSituationPreset: " + akActor.GetDisplayName() + " - " + situation + " -> " + presetName)
EndFunction

Int Function ResolveSituationPresetIndex(SeverActions_OutfitSlot slotSys, Actor akActor, String presetName)
    {The slot preset a standing situation rule names: the exact
     (case-insensitive) match, else FindPresetIndexByName's fuzzy tier ONLY
     with a single candidate. That tier picks at RANDOM among several, which
     is wrong for a rule that fires on every visit, so an ambiguous name is
     refused (-1) with a trace. Uses the slot script's own tokenizer helpers.}
    If !slotSys || !akActor || presetName == ""
        Return -1
    EndIf
    Int exact = slotSys.FindPresetIndexExact(akActor, presetName)
    If exact >= 0
        Return exact
    EndIf
    If SeverActionsNative.Native_OutfitSlot_GetSlot(akActor) < 0
        Return -1
    EndIf
    String[] queryTokens = slotSys.TokenizeAndFilter(StringToLower(presetName))
    If slotSys.CountNonEmptyTokens(queryTokens) == 0
        Return -1
    EndIf
    Int found = -1
    Int candidates = 0
    Int p = 0
    While p < 8
        String existing = SeverActionsNative.Native_OutfitSlot_GetPresetName(akActor, p)
        If existing != ""
            String[] presetTokens = slotSys.TokenizeAndFilter(StringToLower(existing))
            If slotSys.AnyTokenOverlap(queryTokens, presetTokens)
                found = p
                candidates += 1
            EndIf
        EndIf
        p += 1
    EndWhile
    If candidates == 1
        Return found
    EndIf
    If candidates > 1
        Debug.Trace("[SeverActions_Outfit] SetSituationPreset: '" + presetName + "' matches " + candidates + " of " + akActor.GetDisplayName() + "'s presets - a situation rule needs one; not mapped")
    EndIf
    Return -1
EndFunction

Function ClearSituationPreset_Execute(Actor akActor, String situation)
{LLM action: Clear the preset assignment for a situation.}
    ; Master switch: see Undress_Execute.
    If !SeverActionsNativeExt2.Native_Outfit_IsSystemEnabled()
        Debug.Trace("[SeverActions_Outfit] refused - the outfit system is turned off")
        Return
    EndIf
    if !akActor || situation == ""
        return
    endif
    If RefuseIfOutfitExcluded(akActor, "ClearSituationPreset")
        Return
    EndIf
    String situationAsked = situation
    situation = NormalizeSituation(situation)
    If situation == ""
        Debug.Trace("[SeverActions_Outfit] ClearSituationPreset: '" + situationAsked + "' is not a situation the monitor detects - nothing to clear for " + akActor.GetDisplayName())
        Return
    EndIf

    ; ── Slot system ──
    SeverActionsNative.Native_OutfitSlot_SetSituationPreset(akActor, situation, -1)

    ; ── The name map the auto-switch reads ──
    SeverActionsNative.Native_Outfit_ClearSituationPreset(akActor, situation)
    Debug.Trace("[SeverActions_Outfit] ClearSituationPreset: " + akActor.GetDisplayName() + " - cleared " + situation)
EndFunction

; =============================================================================
; MAINTENANCE - every load and new game (the provider's stage 2)
; =============================================================================

Function Maintenance()
    ; AnimationSceneActive rides the save, but a scene's end event never
    ; re-fires after a load: a save made mid-scene would leave
    ; ReapplyLockedOutfit and the alias debounce yielding forever. Reset flag
    ; and refcount; a live scene re-sets them from its start hook.
    AnimationSceneCount = 0
    AnimationSceneActive = false
    ; The pool lock rides the save too (_PoolAcquire).
    _poolBusy = false

    RegisterForModEvent("SeverActions_CatalogEquipLock", "OnCatalogEquipLock")
    ; The outfit module's verb event (M-V): the outfit verbs of the DLL's verb table.
    RegisterForModEvent("SeverActions_Verb_Outfit", "OnVerb_Outfit")
    ; The Outfits page asks, once per session per save, for the StorageUtil
    ; migration only this script can run when it finds the native store empty.
    RegisterForModEvent("SeverActions_OutfitMigrateRequest", "OnOutfitMigrateRequest")
    RegisterForModEvent("SeverActions_Hotkey_Outfit", "OnHotkey_Outfit")   ; the Undress / Dress hotkeys (M-K)
    ; Menu outfit events (ModEvents: DispatchMethodCall silently fails). Older
    ; saves may still hold registrations for four retired handlers
    ; (fomod/removed_functions.json); nothing sends those events.
    RegisterForModEvent("SeverActions_MagelightSnapshot", "OnPrismaSnapshot")
    RegisterForModEvent("SeverActions_MagelightClearLock", "OnPrismaClearLock")
    RegisterForModEvent("SeverActions_MagelightClearAllPresets", "OnPrismaClearAllPresets")
    ; V2 event bypasses stale cached handler in older saves
    RegisterForModEvent("SeverActions_MagelightApplyPresetV2", "OnPrismaApplyPresetV2")
    RegisterForModEvent("SeverActions_MagelightDeletePreset", "OnPrismaDeletePreset")
    RegisterForModEvent("SeverActions_MagelightNukeOutfit", "OnPrismaNukeOutfit")
    RegisterForModEvent("SeverActions_MagelightSetSitPreset", "OnPrismaSetSitPreset")
    RegisterForModEvent("SeverActions_MagelightClearSitPreset", "OnPrismaClearSitPreset")
    RegisterForModEvent("SeverActions_MagelightToggleAutoSwitch", "OnPrismaToggleAutoSwitch")
    RegisterForModEvent("SeverActions_MagelightToggleActorAutoSwitch", "OnPrismaToggleActorAutoSwitch")
    RegisterForModEvent("SeverActions_MagelightInventorySync", "OnPrismaInventorySync")
    RegisterForModEvent("SeverActions_MagelightBuilderEquip", "OnPrismaBuilderEquip")
    RegisterForModEvent("SeverActions_MagelightBuilderSavePreset", "OnPrismaBuilderSavePreset")
    RegisterForModEvent("SeverActions_MagelightBuilderRenamePreset", "OnPrismaBuilderRenamePreset")
    RegisterForModEvent("SeverActions_MagelightClearLockForBuilder", "OnPrismaClearLockForBuilder")
    RegisterForModEvent("SeverActions_MagelightResumeLock", "OnPrismaResumeLock")
    ; Legacy: no current DLL sends it (see the handler).
    RegisterForModEvent("SeverActions_MagelightAdHocClearSlotPreset", "OnPrismaAdHocClearSlotPreset")
    RegisterForModEvent("SeverActions_OutfitExcluded", "OnOutfitExcluded")
    ; The alias pool. The displaced event keeps FollowerManager's old callback
    ; name so an older save's registration lands here; the roster callback is
    ; module-unique (DR10).
    RegisterForModEvent("SeverActions_OutfitAliasDisplaced", "OnOutfitAliasDisplaced")
    RegisterForModEvent("SeverActions_RosterChanged", "OnRosterChanged_Outfit")

    ; Animation frameworks: suspend the outfit lock during scenes. Both hook
    ; pairs are global (every scene).
    RegisterForModEvent("HookAnimationStart", "OnSexLabSceneStart")
    RegisterForModEvent("HookAnimationEnd", "OnSexLabSceneEnd")
    RegisterForModEvent("ostim_start", "OnOStimSceneStart")
    RegisterForModEvent("ostim_end", "OnOStimSceneEnd")

    ; RAM-only SituationMonitor settings, pushed from the Authority as a
    ; backstop to its session-start replay (a native task this script cannot
    ; order itself against). The stability threshold (row in seconds, native
    ; in ms; 5 s compiled default) goes BEFORE the enable.
    SeverActionsNativeExt.SituationMonitor_SetStabilityThreshold((SeverActionsNativeExt2.Settings_GetFloat("outfitStabilityDelay") * 1000.0) as Int)
    Bool savedAutoSwitch = SeverActionsNativeExt2.Settings_GetBool("outfitAutoSwitch")   ; the Authority; Init K1 seeded it from SeverOutfit_GlobalAutoSwitch
    SeverActionsNativeExt.SituationMonitor_SetEnabled(savedAutoSwitch)

    ; Bondage-mod outfit deferral (Diary of Mine / Paradise Halls): RAM-only
    ; native (true on DLL load), re-asserted each load. True = defer to bondage
    ; mods, false = enforce outfits on captured/enslaved NPCs too.
    Bool deferBondage = SeverActionsNativeExt2.Settings_GetBool("outfitDeferBondage")   ; the Authority; Init K1 seeded it from SeverOutfit_DeferBondage
    SeverActionsNativeExt.Native_Outfit_SetDeferBondage(deferBondage)

    Debug.Trace("[SeverActions_Outfit] Maintenance: Registered for CatalogEquipLock, the roster and alias-pool events, menu outfit events, and global auto-switch sync. AutoSwitch restored: " + savedAutoSwitch)

    ; One-shot per save: remove the stale SeverOutfit_Suspended / _SuspendedAt
    ; StorageUtil keys an older build could leave behind (the native
    ; Suspend/Resume never reads them). Walks every actor the outfit system
    ; tracks, not only GetActorsWithLocks, to reach actors whose locks have
    ; since been cleared.
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
        Debug.Trace("[SeverActions_Outfit] Phase 5: cleaned " + cleared + " stale StorageUtil suspend key(s) - now using native SuspendUntil")
    endif
EndFunction

; =============================================================================
; OnCatalogEquipLock: the catalog's "Equip & Lock" (C++ has equipped the piece
; and written the native lock); mirrors it into the legacy lock FormList.
; strArg "actorFormIDHex|armorFormIDHex": FormIDs never ride the float numArg,
; which is exact only to 2^24.
; =============================================================================

Event OnCatalogEquipLock(String eventName, String strArg, Float numArg, Form sender)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Debug.Trace("[SeverActions_Outfit] CatalogEquipLock: No pipe in strArg: " + strArg)
        Return
    EndIf

    String actorHex = StringUtil.Substring(strArg, 0, pipePos)
    String armorHex = StringUtil.Substring(strArg, pipePos + 1)

    Int actorFormID = SeverActionsNative.HexToInt(actorHex)
    Actor akActor = Game.GetFormEx(actorFormID) as Actor
    if !akActor
        Debug.Trace("[SeverActions_Outfit] CatalogEquipLock: Actor not found for FormID " + actorHex)
        return
    endif

    Int armorFormID = SeverActionsNative.HexToInt(armorHex)
    Form armorForm = Game.GetFormEx(armorFormID)
    if !armorForm
        Debug.Trace("[SeverActions_Outfit] CatalogEquipLock: Armor not found for FormID " + armorHex)
        return
    endif

    Armor newArmor = armorForm as Armor
    if !newArmor
        Debug.Trace("[SeverActions_Outfit] CatalogEquipLock: Form is not armor")
        return
    endif

    ; Suspend so the alias doesn't fight the change.
    SuspendOutfitLock(akActor)

    ; Drop locked items sharing a slot with the new piece (no equip flicker).
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

    if StorageUtil.FormListFind(None, lockKey, armorForm) < 0
        StorageUtil.FormListAdd(None, lockKey, armorForm)
        Debug.Trace("[SeverActions_Outfit] CatalogEquipLock: Added " + newArmor.GetName() + " to lock list for " + akActor.GetDisplayName())
    endif

    ; The DLL sends this after writing a native lock: an update of an existing
    ; lock (whatever the toggle says) or, with Outfit Lock on, a new one for a
    ; current or former companion. The Else arm is an existing lock with the
    ; toggle off (or an older DLL): the mirror is not marked active.
    If OutfitLockEnabled
        StorageUtil.SetIntValue(akActor, "SeverOutfit_LockActive", 1)
        ; Keeps the 2 s grace EquipArmorOnActor set: its queued equip and the
        ; conflict unequips are still in flight.
        ResumeOutfitLockKeepGrace(akActor, 2000)
        Debug.Trace("[SeverActions_Outfit] CatalogEquipLock: Lock active for " + akActor.GetDisplayName() + " (" + StorageUtil.FormListCount(None, lockKey) + " items)")
    Else
        ResumeOutfitLockKeepGrace(akActor, 2000)
        Debug.Trace("[SeverActions_Outfit] CatalogEquipLock: Equipped " + newArmor.GetName() + " on " + akActor.GetDisplayName() + " (lock disabled globally)")
    EndIf
EndEvent

; =============================================================================
; MENU OUTFIT EVENT HANDLERS
; C++ has already written the native OutfitDataStore (what every enforcement
; path reads); these run the Papyrus-only legs (the slot script, the
; suspend/resume pairing, the _default preset) and keep the LEGACY StorageUtil
; mirror written (SeverOutfit_Locked_<fid>, SeverOutfit_LockActive,
; SeverOutfit_TrackedActors). Only MigrateOutfitDataToNative and
; OnPrismaInventorySync's LockActive gate read that mirror.
; =============================================================================

Actor Function ResolvePrismaActor(Form akSender, String asName)
    {Sender-first actor resolution for the handlers below: C++
     (MagelightActionHandler::SendModEvent) sets the EXACT actor as sender;
     the strArg display name is a fuzzy fallback (FindActorByName) that can
     pick the wrong one of two same-named NPCs.}
    Actor a = akSender as Actor
    If a
        Return a
    EndIf
    Return SeverActionsNative.FindActorByName(asName)
EndFunction

Event OnPrismaSnapshot(String eventName, String strArg, Float numArg, Form sender)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = ResolvePrismaActor(sender, StringUtil.Substring(strArg, 0, pipePos))
    If !akActor
        Return
    EndIf
    SnapshotLockedOutfit(akActor)
    Debug.Trace("[SeverActions_Outfit] PrismaSnapshot: Synced lock for " + akActor.GetDisplayName())
EndEvent

Event OnPrismaBuilderEquip(String eventName, String strArg, Float numArg, Form sender)
    {Fired by the unequipWornItem C++ action (Outfits page): copies the native
     lock into the legacy mirror, deletes the _default preset, and resumes
     the suspend C++ set for the edit (C++ relies on this to release it).}
    ; Sender-first: C++ sends numArg=0; numArg is only an older DLL's fallback.
    Actor akActor = sender as Actor
    If !akActor
        akActor = Game.GetFormEx(numArg as Int) as Actor
    EndIf
    If !akActor
        Debug.Trace("[SeverActions_Outfit] OnPrismaBuilderEquip: no sender and numArg lookup failed")
        Return
    EndIf

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

        String trackedKey = "SeverOutfit_TrackedActors"
        If StorageUtil.FormListFind(None, trackedKey, akActor as Form) < 0
            StorageUtil.FormListAdd(None, trackedKey, akActor as Form)
        EndIf

        Debug.Trace("[SeverActions_Outfit] PrismaBuilderEquip: Synced " + nativeItems.Length + " lock items for " + akActor.GetDisplayName())
    EndIf

    ; The manual outfit IS the new normal: the next situation switch
    ; re-captures _default from it.
    DeletePreset(akActor, "_default")

    ; Last by convention only: the alias reads the native lock, not the mirror.
    ResumeOutfitLock(akActor)
EndEvent

Event OnPrismaBuilderSavePreset(String eventName, String strArg, Float numArg, Form sender)
    {Fired by the buildOutfitSavePreset C++ action; strArg
     "actorName|presetName". Copies the preset from OutfitDataStore to the
     legacy mirror AND registers it in the slot system so FindPresetIndexByName
     resolves it. numArg 1.0 = applyAfter (the wardrobe's Equip button): wear
     the slot preset once BuildPreset has made it.}
    SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: ENTRY strArg='" + strArg + "' numArg=" + numArg)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: no pipe in strArg, aborting")
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = ResolvePrismaActor(sender, actorName)
    String presetName = StringUtil.Substring(strArg, pipePos + 1)
    SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: parsed actorName='" + actorName + "' presetName='" + presetName + "'")
    If !akActor || presetName == ""
        SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: actor=" + akActor + " presetName='" + presetName + "' - aborting")
        Return
    EndIf

    ; presetName is the DLL's stored (once-normalized) name, used verbatim: a
    ; second NormalizePresetName would strip another suffix word and fetch
    ; nothing.

    ; FETCH FIRST: an empty result means the C++ save failed, so abort before
    ; a ghost legacy entry wipes the previous backup for this key. The native
    ; lookup is case-insensitive, so a BSFixedString case flip cannot empty it.
    Form[] presetItems = SeverActionsNative.Native_Outfit_GetPresetItems(akActor, presetName)
    Int itemsLen = 0
    If presetItems
        itemsLen = presetItems.Length
    EndIf
    SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: native fetch returned " + itemsLen + " items for '" + presetName + "'")

    If itemsLen == 0
        SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: ABORT - empty native fetch, refusing to register ghost legacy entry for '" + presetName + "'")
        Return
    EndIf

    ; The legacy mirror: the item list, the name list, the preset-actor list.
    String presetKey = "SeverOutfit_" + presetName + "_" + (akActor.GetFormID() as String)

    StorageUtil.FormListClear(None, presetKey)
    Int pi = 0
    While pi < itemsLen
        If presetItems[pi]
            StorageUtil.FormListAdd(None, presetKey, presetItems[pi])
        EndIf
        pi += 1
    EndWhile

    String presetsListKey = "SeverOutfit_Presets_" + (akActor.GetFormID() as String)
    if StorageUtil.StringListFind(None, presetsListKey, presetName) < 0
        StorageUtil.StringListAdd(None, presetsListKey, presetName)
    endif

    String presetActorsKey = "SeverOutfit_PresetActors"
    if StorageUtil.FormListFind(None, presetActorsKey, akActor as Form) < 0
        StorageUtil.FormListAdd(None, presetActorsKey, akActor as Form)
    endif

    ; === SLOT SYSTEM REGISTRATION ===
    ; BuildPreset puts the preset in the slot store; without it
    ; FindPresetIndexByName misses and ApplyPreset takes the legacy path.
    ; applyAfter wears it only once BuildPreset has made it, by INDEX through
    ; the wardrobe's own apply: never by name (the fuzzy tier), never the
    ; legacy path - no slot preset, no apply.
    Bool applyAfter = numArg > 0.5
    SeverActions_OutfitSlot slotSys = GetSlotScript()
    SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: pre-slot-gate slotSys=" + slotSys + " presetItems.Length=" + itemsLen)
    If slotSys
        Int targetIdx = slotSys.FindFreeOrReusableIndex(akActor, presetName)
        If targetIdx >= 0
            ; BuildPreset re-applies by itself when it overwrites the ACTIVE
            ; preset (its wasActive branch), so Equip must not apply a second
            ; time - read that before BuildPreset changes it.
            Bool rebuildsActive = SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor) == targetIdx
            ; Decided BEFORE BuildPreset, so only its own tail runs between the
            ; end of its owned suspend and the re-suspend below. Same gates as
            ; the other applies: the master switch (ApplyOutfitPreset_Execute)
            ; and the per-NPC exclusion (OutfitDataStore::ApplyPresetNative).
            Bool applyNow = false
            If applyAfter && !rebuildsActive
                If !SeverActionsNativeExt2.Native_Outfit_IsSystemEnabled()
                    SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: applyAfter refused - the outfit system is turned off ('" + presetName + "' is saved, not worn)")
                ElseIf SeverActionsNative.Native_GetOutfitExcluded(akActor)
                    SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: applyAfter refused - " + akActor.GetDisplayName() + " is outfit-excluded ('" + presetName + "' is saved, not worn)")
                Else
                    applyNow = true
                EndIf
            EndIf
            Int committed = slotSys.BuildPreset(akActor, targetIdx, presetItems, presetName)
            If applyAfter && committed <= 0 && SeverActionsNativeExt2.Native_Outfit_IsSystemEnabled() && !SeverActionsNative.Native_GetOutfitExcluded(akActor)
                ; Nothing saved to wear: HOLD the active preset so the Equip's
                ; pieces stay on (see the no-free-index branch below). If the
                ; rebuilt preset WAS active, BuildPreset already un-marked it,
                ; so nothing enforces anyway.
                SeverActionsNativeExt2.Native_OutfitSlot_HoldActivePreset(akActor)
            EndIf
            If applyNow && committed > 0
                ; BuildPreset ended its OWNED suspend (one owner per actor)
                ; while the OLD preset is still active: re-suspend at once,
                ; untokened, so an alias event from BuildPreset's chest moves
                ; cannot re-dress the old preset before ApplyPresetBySlot's
                ; owned suspend, which replaces this one (SuspendOwned rewrites
                ; the deadline) and whose end (_EndOwnedOutfitOp) ends both. The
                ; exits that skip it are the ghost-preset checks BuildPreset has
                ; just ruled out (a dead actor's is left to the watchdog or the
                ; menu-close resume). This gap is the one window a menu-close
                ; resume can still reach.
                SuspendOutfitLock(akActor)
            EndIf
            SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: BuildPreset for " + akActor.GetDisplayName() + " '" + presetName + "' targetIdx=" + targetIdx + " committed=" + committed + " applyAfter=" + applyAfter)
            If applyAfter && committed > 0 && (applyNow || rebuildsActive)
                If applyNow
                    slotSys.ApplyPresetBySlot(akActor, targetIdx)
                EndIf
                ; The active-name tracker (SituationMonitor's "already wearing"
                ; test, outfit_context, delete). ApplyPresetBySlot keeps it in
                ; step; this covers the rebuildsActive case too: this preset
                ; active = applied (a partial apply counts); nothing active =
                ; nothing went on, so no name; another preset active = the apply
                ; never started and the old name stays true (ApplyPresetNative's
                ; Failed rule).
                Int activeNow = SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor)
                If activeNow == targetIdx
                    SeverActionsNative.Native_Outfit_SetActivePreset(akActor, presetName)
                    ; The preset is the dressed state: consume a stash an
                    ; earlier Undress left (see _ApplyOutfitPresetResolved).
                    _ClearDressStash(akActor)
                ElseIf activeNow < 0
                    SeverActionsNative.Native_Outfit_SetActivePreset(akActor, "")
                EndIf
                ; A committed worn change: rebaseline any preview session and
                ; redraw the Outfits page (BuildPreset's refresh ran before
                ; this apply and still showed the old preset active).
                Utility.WaitMenuMode(0.2)
                SeverActionsNativeExt.Native_Preview_NotifyWornChanged(akActor)
                SeverActionsNative.Magelight_RefreshPage("outfits")
            EndIf
        Else
            SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: No free slot index for " + akActor.GetDisplayName() + " '" + presetName + "' (all 8 full) applyAfter=" + applyAfter)
            If applyAfter && SeverActionsNativeExt2.Native_Outfit_IsSystemEnabled() && !SeverActionsNative.Native_GetOutfitExcluded(akActor)
                ; The Equip's pieces are on (the preview committed them) but no
                ; preset index is free. HOLD the active preset (the ad-hoc
                ; takeover EquipArmor makes) so its enforcement does not strip
                ; them at the next load door; the hold ends at the next apply,
                ; clear or GetDressed, and is a no-op with no active slot
                ; preset. Same gate as the DLL's for superseding the pre-menu
                ; lock (buildOutfitSavePreset): with the system off or the NPC
                ; excluded, that lock's stash gets the normal close-time
                ; restore (RestoreBuilderLockIfAppropriate).
                SeverActionsNativeExt2.Native_OutfitSlot_HoldActivePreset(akActor)
            EndIf
        EndIf
    Else
        SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderSavePreset: SKIPPED slot registration - slotSys is None")
    EndIf

    Debug.Trace("[SeverActions_Outfit] PrismaBuilderSavePreset: Synced preset '" + presetName + "' for " + akActor.GetDisplayName())
EndEvent

Event OnPrismaBuilderRenamePreset(String eventName, String strArg, Float numArg, Form sender)
    {Fired by buildOutfitSavePreset when a save renames a preset (`oldPreset`
     set and different from `preset`); both native stores are already
     renamed. Mirrors the rename into the legacy item FormList key and the
     per-actor name StringList. strArg "actorName|oldName|newName".}
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

    Actor akActor = ResolvePrismaActor(sender, actorName)
    If !akActor || oldName == "" || newName == ""
        SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderRenamePreset: actor=" + akActor + " oldName='" + oldName + "' newName='" + newName + "' - aborting")
        Return
    EndIf

    String actorFid = akActor.GetFormID() as String

    ; StorageUtil has no rename: copy old -> new, then clear old.
    String oldKey = "SeverOutfit_" + oldName + "_" + actorFid
    String newKey = "SeverOutfit_" + newName + "_" + actorFid
    Int itemCount = StorageUtil.FormListCount(None, oldKey)
    If itemCount > 0
        ; newKey may hold a prior partial rename.
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

    ; No in-place replace: remove old, append new if absent.
    String namesKey = "SeverOutfit_Presets_" + actorFid
    Int oldIdx = StorageUtil.StringListFind(None, namesKey, oldName)
    If oldIdx >= 0
        StorageUtil.StringListRemove(None, namesKey, oldName, true)
    EndIf
    If StorageUtil.StringListFind(None, namesKey, newName) < 0
        StorageUtil.StringListAdd(None, namesKey, newName, false)
    EndIf

    SeverActionsNative.Native_OutfitSlot_Log("OnPrismaBuilderRenamePreset: renamed '" + oldName + "' -> '" + newName + "' for " + akActor.GetDisplayName() + " (items copied=" + itemCount + ")")
EndEvent

Event OnPrismaClearLockForBuilder(String eventName, String strArg, Float numArg, Form sender)
    {Fired when the Outfit Builder opens: C++ has cleared the native lock
     (ClearLockItems); this clears the legacy mirror and suspends the lock.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = ResolvePrismaActor(sender, StringUtil.Substring(strArg, 0, pipePos))
    If !akActor
        Return
    EndIf

    String lockKey = "SeverOutfit_Locked_" + (akActor.GetFormID() as String)
    StorageUtil.FormListClear(None, lockKey)
    StorageUtil.SetIntValue(akActor, "SeverOutfit_LockActive", 0)
    ; A deadline suspend (the 5-minute watchdog; the DLL's suspendOutfitLock
    ; uses OutfitDataStore::SuspendUntil too, no hard flag), so a session that
    ; loses its OnPrismaResumeLock self-heals when it expires.
    SuspendOutfitLock(akActor)
    Debug.Trace("[SeverActions_Outfit] PrismaClearLockForBuilder: Cleared lock for " + akActor.GetDisplayName())
EndEvent

Event OnPrismaResumeLock(String eventName, String strArg, Float numArg, Form sender)
    {Fired when the Outfit Builder closes (per actor from the wardrobe pane,
     or for every suspended actor from C++ ResumeAllBuilderLocks at menu
     close). Clears the suspend (an OWNED one stays: the op still running,
     BuildPreset, ApplyPresetBySlot or the preset teardown, ends it), then
     re-syncs the legacy mirror to the NATIVE lock, which C++ may have
     restored from its stash, re-created (Equip & Lock) or left cleared.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = ResolvePrismaActor(sender, StringUtil.Substring(strArg, 0, pipePos))
    If !akActor
        Return
    EndIf

    SeverActionsNative.Native_Outfit_ClearBurstSuppression(akActor)
    ResumeOutfitLock(akActor)

    ; Mirror re-sync: native OutfitDataStore is the source of truth.
    String lockKey = "SeverOutfit_Locked_" + (akActor.GetFormID() as String)
    If SeverActionsNativeExt.Native_Outfit_IsLockActive(akActor)
        StorageUtil.FormListClear(None, lockKey)
        Form[] lockedItems = SeverActionsNative.Native_Outfit_GetLockedItems(akActor)
        Int li = 0
        While li < lockedItems.Length
            If lockedItems[li]
                StorageUtil.FormListAdd(None, lockKey, lockedItems[li])
            EndIf
            li += 1
        EndWhile
        StorageUtil.SetIntValue(akActor, "SeverOutfit_LockActive", 1)
        Debug.Trace("[SeverActions_Outfit] PrismaResumeLock: Resumed for " + akActor.GetDisplayName() + " - mirror re-synced (" + lockedItems.Length + " locked items)")
    Else
        ; Native lock inactive - keep the mirror cleared (it was wiped at
        ; suspend time by OnPrismaClearLockForBuilder).
        Debug.Trace("[SeverActions_Outfit] PrismaResumeLock: Resumed for " + akActor.GetDisplayName() + " - no active lock")
    EndIf
EndEvent

Event OnOutfitExcluded(String eventName, String strArg, Float numArg, Form sender)
    {Fired by MagelightSettingsHandler when an actor is marked outfit-excluded:
     C++ has cleared the native lock; this clears the legacy mirror to match.
     strArg "<actorFormIDDecimal>|".}
    Int pipePos = StringUtil.Find(strArg, "|")
    String actorIdStr
    if pipePos >= 0
        actorIdStr = StringUtil.Substring(strArg, 0, pipePos)
    else
        actorIdStr = strArg
    endif
    Int actorFid = actorIdStr as Int
    Actor akActor = Game.GetFormEx(actorFid) as Actor
    if !akActor
        return
    endif
    String lockKey = "SeverOutfit_Locked_" + (akActor.GetFormID() as String)
    StorageUtil.FormListClear(None, lockKey)
    StorageUtil.UnsetIntValue(akActor, "SeverOutfit_LockActive")
    ; The alias-pool seat is KEPT: the OutfitAlias gates on the exclusion flag,
    ; and un-excluding sends no event, so a cleared seat would stay empty until
    ; the next load. The next re-seat drops it if the actor is still excluded.
    Debug.Trace("[SeverActions_Outfit] OnOutfitExcluded: cleared StorageUtil lock for " + akActor.GetDisplayName())
EndEvent

Event OnPrismaAdHocClearSlotPreset(String eventName, String strArg, Float numArg, Form sender)
    {Legacy receiver: no current DLL sends this (the UI's per-item changes
     HOLD the active slot preset instead). Kept so an older DLL's send still
     clears the legacy SeverOutfit_PresetActive flag. sender = the actor;
     numArg is only a stale-DLL fallback.}
    Actor akActor = sender as Actor
    if !akActor
        akActor = Game.GetFormEx(numArg as Int) as Actor
    endif
    if !akActor
        Debug.Trace("[SeverActions_Outfit] OnPrismaAdHocClearSlotPreset: no sender and numArg lookup failed")
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
    Actor akActor = ResolvePrismaActor(sender, StringUtil.Substring(strArg, 0, pipePos))
    If !akActor
        Return
    EndIf
    ClearLockedOutfit(akActor)
    Debug.Trace("[SeverActions_Outfit] PrismaClearLock: Cleared lock for " + akActor.GetDisplayName())
EndEvent

Event OnPrismaClearAllPresets(String eventName, String strArg, Float numArg, Form sender)
    {"Clear All Presets": fully releases the actor's slot (restores the
     original DefaultOutfit, empties the 8 preset containers, returns and
     deletes the satchel), clears the legacy lock and ERASES the actor's
     OutfitDataStore row (presets, situation mappings, active preset name,
     dress stash) - ClearLock alone would leave mappings the situation monitor
     re-dresses from. The actor ends at their untouched baseline.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = ResolvePrismaActor(sender, StringUtil.Substring(strArg, 0, pipePos))
    If !akActor
        Return
    EndIf

    SeverActions_OutfitSlot slotSys = GetSlotScript()
    If slotSys
        slotSys.ReleaseSlotFromActor(akActor)
    EndIf
    ; The slot preset index an Undress recorded for GetDressed names a preset
    ; that no longer exists.
    StorageUtil.UnsetIntValue(akActor, "SeverActions_DressPresetIdx")
    StorageUtil.UnsetStringValue(akActor, "SeverActions_DressPresetName")

    ; Clear the legacy lock (restores a parked DefaultOutfit)
    ClearLockedOutfit(akActor)

    ; Erase the row - the presets, situation mappings, active preset name and
    ; dress stash ClearLock keeps. The native restores any DefaultOutfit still
    ; parked before it erases. LAST, and nothing after it: a native setter
    ; that writes through operator[] would re-create the row.
    SeverActionsNative.Native_Outfit_RemoveActor(akActor)

    Debug.Trace("[SeverActions_Outfit] PrismaClearAllPresets: Fully released " + akActor.GetDisplayName() + " (slot, lock and outfit data)")
EndEvent

Event OnPrismaApplyPresetV2(String eventName, String strArg, Float numArg, Form sender)
    {V2 of the apply event, so an older save's registration of the retired
     OnPrismaApplyPreset never receives it. The name arrives normalized once
     by the DLL (applyPreset) and goes to the resolved apply VERBATIM, not
     through ApplyOutfitPreset_Execute's second normalization.}
    SeverActionsNative.Native_OutfitSlot_Log("OnPrismaApplyPresetV2: strArg='" + strArg + "' numArg=" + numArg)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        SeverActionsNative.Native_OutfitSlot_Log("OnPrismaApplyPresetV2: No pipe in strArg, aborting")
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    String presetName = StringUtil.Substring(strArg, pipePos + 1)
    Actor akActor = ResolvePrismaActor(sender, actorName)
    If !akActor
        SeverActionsNative.Native_OutfitSlot_Log("OnPrismaApplyPresetV2: Actor lookup failed for '" + actorName + "'")
        Return
    EndIf
    SeverActionsNative.Native_OutfitSlot_Log("OnPrismaApplyPresetV2: Calling _ApplyOutfitPresetResolved('" + akActor.GetDisplayName() + "', '" + presetName + "')")
    _ApplyOutfitPresetResolved(akActor, presetName)
EndEvent

Event OnPrismaDeletePreset(String eventName, String strArg, Float numArg, Form sender)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = ResolvePrismaActor(sender, StringUtil.Substring(strArg, 0, pipePos))
    String presetName = StringUtil.Substring(strArg, pipePos + 1)
    If !akActor
        Return
    EndIf
    DeletePreset(akActor, presetName)
    Debug.Trace("[SeverActions_Outfit] PrismaDeletePreset: Deleted '" + presetName + "' for " + akActor.GetDisplayName())
EndEvent

Event OnPrismaNukeOutfit(String eventName, String strArg, Float numArg, Form sender)
    {Wipes one NPC's outfit data: the Outfits page's "Forget" / "Forget all"
     (forgetOutfitData). The native side (OutfitDataStore::RemoveActor +
     OutfitSlotStore::EraseActor) has already restored the DefaultOutfit and
     erased the cosaved entries; this clears the StorageUtil mirror (every
     per-actor SeverOutfit_* key, the per-preset FormLists, the global
     tracker lists). sender = the actor (numArg is a stale-DLL fallback).
     strArg "<name>|<slotIdx>": the slot the NPC held before the erase
     (-1 = none), so its OutfitSlotNN alias can be cleared here.}

    Actor akActor = sender as Actor
    Int actorFid = 0
    If akActor
        actorFid = akActor.GetFormID()
    Else
        actorFid = numArg as Int
        If actorFid == 0
            Debug.Trace("[SeverActions_Outfit] OnPrismaNukeOutfit: no sender and actorFid=0, aborting")
            Return
        EndIf
        akActor = Game.GetFormEx(actorFid) as Actor   ; may be None — global keys below still clean up
    EndIf
    String actorFidStr = actorFid as String

    ; The released slot's OutfitSlotNN alias: a native clear does not take,
    ; the VM's Clear does.
    Int nukePipe = StringUtil.Find(strArg, "|")
    If akActor && nukePipe >= 0
        Int nukeSlotIdx = StringUtil.Substring(strArg, nukePipe + 1) as Int
        If nukeSlotIdx >= 0
            ReferenceAlias nukeAlias = SeverActionsNative.Native_OutfitSlot_GetAliasForSlot(nukeSlotIdx)
            If nukeAlias && nukeAlias.GetActorRef() == akActor
                nukeAlias.Clear()
            EndIf
        EndIf
    EndIf

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
        StorageUtil.UnsetIntValue(akActor, "SeverActions_DressPresetIdx")
    StorageUtil.UnsetStringValue(akActor, "SeverActions_DressPresetName")
        StorageUtil.UnsetIntValue(akActor, "SeverActions_DressWasLocked")
        ; All 7 situation keys (NormalizeSituation's canonical set).
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

        ; --- 4. No native setter here: RemoveActor already erased the row AND
        ; the dress stash, and a setter writing through operator[] would
        ; re-create a ghost row. DressStashClear is find-only, kept for a DLL
        ; older than v6 whose RemoveActor left the stash. ---
        SeverActionsNativeExt.Native_Outfit_DressStashClear(akActor)
    EndIf

    Debug.Trace("[SeverActions_Outfit] OnPrismaNukeOutfit: complete for " + actorFidStr + " (" + presetCount + " presets cleared)")
EndEvent

Event OnPrismaSetSitPreset(String eventName, String strArg, Float numArg, Form sender)
    ; strArg = "actorName|situation|presetName"
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = ResolvePrismaActor(sender, StringUtil.Substring(strArg, 0, pipePos))
    If !akActor
        Return
    EndIf
    String remainder = StringUtil.Substring(strArg, pipePos + 1)
    Int pipe2 = StringUtil.Find(remainder, "|")
    If pipe2 < 0
        Debug.Trace("[SeverActions_Outfit] PrismaSetSitPreset: Invalid format - no second pipe")
        Return
    EndIf
    String situation = StringUtil.Substring(remainder, 0, pipe2)
    String presetName = StringUtil.Substring(remainder, pipe2 + 1)
    ; The DLL normalized the name once; never again here.
    _SetSituationPresetResolved(akActor, situation, presetName)
    Debug.Trace("[SeverActions_Outfit] PrismaSetSitPreset: " + akActor.GetDisplayName() + " - " + situation + " -> " + presetName)
EndEvent

Event OnPrismaClearSitPreset(String eventName, String strArg, Float numArg, Form sender)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = ResolvePrismaActor(sender, StringUtil.Substring(strArg, 0, pipePos))
    String situation = StringUtil.Substring(strArg, pipePos + 1)
    If !akActor
        Return
    EndIf
    ClearSituationPreset_Execute(akActor, situation)
    Debug.Trace("[SeverActions_Outfit] PrismaClearSitPreset: " + akActor.GetDisplayName() + " - cleared " + situation)
EndEvent

; =============================================================================
; AUTO-SWITCH TOGGLES (global and per actor)
; =============================================================================

Event OnPrismaToggleAutoSwitch(String eventName, String strArg, Float numArg, Form sender)
    ; strArg = "0|0" or "0|1" (formId=0 for global, data=0/1)
    Int pipePos = StringUtil.Find(strArg, "|")
    String valStr = strArg
    If pipePos >= 0
        valStr = StringUtil.Substring(strArg, pipePos + 1)
    EndIf
    Bool enabled = (valStr == "1")
    ; Log only: MagelightActionHandler's toggleGlobalAutoSwitch already fed the
    ; Authority row outfitAutoSwitch (a Papyrus host write would fail check 22c).
    Debug.Trace("[SeverActions_Outfit] PrismaToggleAutoSwitch: Global auto-switch -> " + enabled)
EndEvent

Event OnPrismaToggleActorAutoSwitch(String eventName, String strArg, Float numArg, Form sender)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = ResolvePrismaActor(sender, StringUtil.Substring(strArg, 0, pipePos))
    If !akActor
        Return
    EndIf
    SetActorAutoSwitch(akActor, StringUtil.Substring(strArg, pipePos + 1) == "1")
EndEvent

Function SetActorAutoSwitch(Actor akActor, Bool abEnabled)
    {Set one actor's situational auto-switch flag (the MCM reaches this
     through the outfit.setActorAutoSwitch verb). SituationMonitor reads the
     OutfitDataStore flag; the StorageUtil key is a legacy mirror nothing
     reads after the one-shot migrations. The slot store's per-slot
     autoSwitchEnabled is NOT written: only its own getter reads it.}
    If !akActor
        Return
    EndIf
    SeverActionsNative.Native_Outfit_SetAutoSwitchEnabled(akActor, abEnabled)
    StorageUtil.SetIntValue(akActor, "SeverOutfit_AutoSwitch", abEnabled as Int)
    Debug.Trace("[SeverActions_Outfit] SetActorAutoSwitch: " + akActor.GetDisplayName() + " auto-switch -> " + abEnabled)
EndFunction

; =============================================================================
; OnPrismaInventorySync: an equipped piece left the actor via the Inventory
; page; C++ has already removed it from the native lock (RemoveLockedItems).
; Rebuilds the legacy mirror. strArg "ActorName|".
; =============================================================================

Event OnPrismaInventorySync(String eventName, String strArg, Float numArg, Form sender)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = ResolvePrismaActor(sender, StringUtil.Substring(strArg, 0, pipePos))
    If !akActor
        Debug.Trace("[SeverActions_Outfit] PrismaInventorySync: Actor not found from strArg: " + strArg)
        Return
    EndIf

    ; Rebuilt from the native lock, never GetWornForm: UnequipObject is async,
    ; so worn state may be stale.
    String lockKey = "SeverOutfit_Locked_" + (akActor.GetFormID() as String)

    If StorageUtil.GetIntValue(akActor, "SeverOutfit_LockActive", 0) != 1
        Debug.Trace("[SeverActions_Outfit] PrismaInventorySync: Lock not active for " + akActor.GetDisplayName())
        Return
    EndIf

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

    Int lockCount = StorageUtil.FormListCount(None, lockKey)
    Debug.Trace("[SeverActions_Outfit] PrismaInventorySync: Rebuilt lock for " + akActor.GetDisplayName() + " - " + lockCount + " items")
EndEvent

; =============================================================================
; ANIMATION FRAMEWORK HOOKS — suspend/resume outfit locks during scenes
; =============================================================================

; SexLab global hooks — signature: (int threadID, bool hasPlayer)
Event OnSexLabSceneStart(Int threadID, Bool hasPlayer)
    AnimationSceneCount += 1
    AnimationSceneActive = true
    Debug.Trace("[SeverActions_Outfit] SexLab scene started (thread " + threadID + ") - outfit locks suspended (scenes=" + AnimationSceneCount + ")")
EndEvent

Event OnSexLabSceneEnd(Int threadID, Bool hasPlayer)
    ; Refcount, not a flat clear: lift the suspend only when the LAST
    ; overlapping scene ends, or a second concurrent scene is left enforced.
    If AnimationSceneCount > 0
        AnimationSceneCount -= 1
    EndIf
    AnimationSceneActive = AnimationSceneCount > 0
    Debug.Trace("[SeverActions_Outfit] SexLab scene ended (thread " + threadID + ") - scenes=" + AnimationSceneCount + (AnimationSceneActive as String))
EndEvent

; OStim hooks — signature: (string eventName, string strArg, float numArg, Form sender)
Event OnOStimSceneStart(String eventName, String strArg, Float numArg, Form sender)
    AnimationSceneCount += 1
    AnimationSceneActive = true
    Debug.Trace("[SeverActions_Outfit] OStim scene started - outfit locks suspended (scenes=" + AnimationSceneCount + ")")
EndEvent

Event OnOStimSceneEnd(String eventName, String strArg, Float numArg, Form sender)
    If AnimationSceneCount > 0
        AnimationSceneCount -= 1
    EndIf
    AnimationSceneActive = AnimationSceneCount > 0
    Debug.Trace("[SeverActions_Outfit] OStim scene ended - scenes=" + AnimationSceneCount)
EndEvent

; ============================================================================
; M-V VERB DISPATCHER (plan 3.0 M-V, DR10)
; ============================================================================
; The DLL routes each UI verb this module owns or hosts (verb_table.json) as
; SeverActions_Verb_Outfit with the Actions page's 8 pipe fields. This is the
; ONE script defining OnVerb_Outfit: a shared callback name is invoked on
; every script of the form that defines it (F4). Registered in Maintenance,
; keyed to the handle old saves hold (DR16).
Event OnVerb_Outfit(String eventName, String strArg, Float numArg, Form sender)
    String actionId = SeverActions_ModuleBase.VerbField(strArg, 0)
    String targetName = SeverActions_ModuleBase.VerbField(strArg, 1)
    String target2Name = SeverActions_ModuleBase.VerbField(strArg, 2)
    String strParam = SeverActions_ModuleBase.VerbField(strArg, 3)
    Int intParam = SeverActions_ModuleBase.VerbField(strArg, 4) as Int
    String str2Param = SeverActions_ModuleBase.VerbField(strArg, 5)
    Int targetFid = SeverActions_ModuleBase.VerbField(strArg, 6) as Int
    Int target2Fid = SeverActions_ModuleBase.VerbField(strArg, 7) as Int
    Debug.Trace("[SeverActions_Outfit] OnVerb_Outfit: " + actionId + " target=" + targetName + " target2=" + target2Name \
        + " str=" + strParam + " int=" + intParam + " str2=" + str2Param + " fid=" + targetFid + " fid2=" + target2Fid)

    ; VerbActor: sender, then FormID, then the fuzzy name.
    Actor target = SeverActions_ModuleBase.VerbActor(sender, targetFid, targetName)
    If !target
        Debug.Trace("[SeverActions_Outfit] OnVerb_Outfit: could not resolve target '" + targetName + "' for " + actionId)
        Return
    EndIf
    targetName = target.GetDisplayName()
    Actor target2 = SeverActions_ModuleBase.VerbActor(None, target2Fid, target2Name)
    If target2
        target2Name = target2.GetDisplayName()
    ElseIf target2Name != ""
        Debug.Trace("[SeverActions_Outfit] OnVerb_Outfit: target2 name '" + target2Name + "' did not resolve to an actor (action=" + actionId + ")")
    EndIf

    If actionId == "undress"
        Undress_Execute(target)

    ElseIf actionId == "getDressed"
        Dress_Execute(target)

    ElseIf actionId == "equipItems"
        EquipMultipleItems_Execute(target, strParam)

    ElseIf actionId == "unequipItems"
        UnequipMultipleItems_Execute(target, strParam)

    ElseIf actionId == "applyPreset"
        ApplyOutfitPreset_Execute(target, strParam)

    ElseIf actionId == "savePreset"
        SaveOutfitPreset_Execute(target, strParam)

    ElseIf actionId == "setActorAutoSwitch"
        SetActorAutoSwitch(target, strParam == "true")

    ElseIf actionId == "setSituationOutfit"
        ; target = NPC, strParam = situation, str2Param = preset name
        SetSituationPreset_Execute(target, strParam, str2Param)

    ElseIf actionId == "clearSituationOutfit"
        ; target = NPC, strParam = situation
        ClearSituationPreset_Execute(target, strParam)

    Else
        Debug.Trace("[SeverActions_Outfit] OnVerb_Outfit: unknown actionId '" + actionId + "' (not a row this dispatcher carries)")
    EndIf

    ; The authoritative refresh: the DLL's own, one frame after routing, can
    ; gather state from before this verb ran. Once per click, so cheap.
    SeverActionsNative.Magelight_RefreshPage("world")
    SeverActionsNative.Magelight_RefreshPage("enterprises")
EndEvent

; ============================================================================
; M-K HOTKEY DISPATCHER (plan 3.0 M-K, DR10)
; ============================================================================
; SeverActions_Hotkey_Outfit from the DLL's input sink (hotkey_table.json):
; strArg = the hotkey id, sender = the target resolved by targetMode (never a
; dead actor) or None; refusing the player is this dispatcher's job. The sink
; already refused a paused game, an open dialogue or SeverActions menu, a
; focused text field, and a dead or sitting player.
Event OnHotkey_Outfit(String eventName, String strArg, Float numArg, Form sender)
    ; "wheel:<id>" = the quick wheel's pick of the same hotkey; the outfit
    ; hotkeys treat both alike (fromWheel is unused here).
    String hotkeyId = strArg
    Bool fromWheel = false
    If StringUtil.Substring(strArg, 0, 6) == "wheel:"
        fromWheel = true
        hotkeyId = StringUtil.Substring(strArg, 6)
    EndIf
    Actor target = sender as Actor
    Actor player = Game.GetPlayer()
    Debug.Trace("[SeverActions_Outfit] OnHotkey_Outfit: " + hotkeyId + " target=" + target)

    ; _IsEligible also refuses what _Execute refuses silently (system off,
    ; excluded actor), so the success notice shows only when the action ran.
    If hotkeyId == "Undress"
        If !target
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.noValidTarget"))
        ElseIf target == player
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.cannotTargetYourself"))
        ElseIf Undress_IsEligible(target)
            Undress_Execute(target)
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("hotkeys.undressed", ("" + target.GetDisplayName())))
        Else
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("hotkeys.cannotBeUndressed", ("" + target.GetDisplayName())))
        EndIf

    ElseIf hotkeyId == "Dress"
        If !target
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.noValidTarget"))
        ElseIf target == player
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.cannotTargetYourself"))
        ElseIf Dress_IsEligible(target)
            Dress_Execute(target)
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("hotkeys.dressed", ("" + target.GetDisplayName())))
        Else
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("hotkeys.noStoredClothing", ("" + target.GetDisplayName())))
        EndIf

    Else
        Debug.Trace("[SeverActions_Outfit] OnHotkey_Outfit: unknown hotkeyId '" + hotkeyId + "' (not a row this dispatcher carries)")
    EndIf
EndEvent

; =============================================================================
; NATIVE MIGRATION REQUEST
; =============================================================================

Event OnOutfitMigrateRequest(String eventName, String strArg, Float numArg, Form sender)
    {Sent by the Outfits page, once per loaded save, when it finds the native OutfitDataStore
     empty: runs the StorageUtil migration only this script can run. The event name is this
     script's own (one ModEvent name per quest form, DR10).}
    Debug.Trace("[SeverActions_Outfit] Native migration request - migrating outfit data")
    MigrateOutfitDataToNative()
    Debug.Trace("[SeverActions_Outfit] Migration complete - refreshing the outfits page")
    Utility.Wait(0.5)
    SeverActionsNative.Magelight_RefreshPage("outfits")
EndEvent
