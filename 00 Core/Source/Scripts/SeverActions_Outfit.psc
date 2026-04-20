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

    SuspendOutfitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] Undress: " + akActor.GetDisplayName())

    String storageKey = "SeverActions_RemovedArmor_" + (akActor.GetFormID() as String)
    StorageUtil.FormListClear(None, storageKey)

    ; Store the NPC's DefaultOutfit as a fallback for Dress.
    ; If individual item re-equip fails (engine manages defaults differently),
    ; we can restore via SetOutfit instead.
    String outfitKey = "SeverActions_DefaultOutfit_" + (akActor.GetFormID() as String)
    ActorBase npcBase = akActor.GetActorBase()
    If npcBase
        Outfit baseOutfit = npcBase.GetOutfit(false)
        If baseOutfit
            StorageUtil.SetFormValue(None, outfitKey, baseOutfit)
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
    
    int i = 0
    int removedCount = 0
    while i < slots.Length
        Armor equippedItem = akActor.GetWornForm(slots[i]) as Armor
        if equippedItem
            if StorageUtil.FormListFind(None, storageKey, equippedItem) < 0
                ; Check blacklist — skip items the user wants to keep
                If SeverActionsNative.Native_Blacklist_IsBlacklisted(equippedItem)
                    Debug.Trace("[SeverActions_Outfit] Undress: Skipping blacklisted " + equippedItem.GetName())
                Else
                    StorageUtil.FormListAdd(None, storageKey, equippedItem)
                    PlayUnequipAnimation(akActor, slotNames[i])
                    ; preventEquip = true — stops the engine's DefaultOutfit system
                    ; from re-equipping this item on the next AI tick
                    akActor.UnequipItem(equippedItem, true, true)
                    removedCount += 1
                EndIf
            endif
        endif
        i += 1
    endwhile
    
    ; Clear outfit lock — nothing worn means nothing to persist
    ClearLockedOutfit(akActor)

    ; Clear active preset — manual change
    SeverActionsNative.Native_Outfit_SetActivePreset(akActor, "")
    StorageUtil.SetStringValue(akActor, "SeverOutfit_ActivePreset", "")

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

    SuspendOutfitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] Dress: " + akActor.GetDisplayName())

    String storageKey = "SeverActions_RemovedArmor_" + (akActor.GetFormID() as String)
    int count = StorageUtil.FormListCount(None, storageKey)

    if count == 0
        ; No individual items stored — try restoring via DefaultOutfit fallback.
        ; This handles NPCs whose gear came entirely from the engine's DefaultOutfit
        ; system (e.g. Lydia's base armor), where individual items aren't tracked.
        String outfitKey = "SeverActions_DefaultOutfit_" + (akActor.GetFormID() as String)
        Form storedOutfit = StorageUtil.GetFormValue(None, outfitKey, None)
        Outfit baseOutfit = storedOutfit as Outfit
        If baseOutfit
            ActorBase npcBase = akActor.GetActorBase()
            If npcBase
                Debug.Trace("[SeverActions_Outfit] Dress: Restoring DefaultOutfit for " + akActor.GetDisplayName())
                npcBase.SetOutfit(baseOutfit, false)
                akActor.SetOutfit(baseOutfit, false)
                StorageUtil.UnsetFormValue(None, outfitKey)
                ; Don't SnapshotLockedOutfit here — SetOutfit is async and GetWornForm
                ; returns stale data. The restored DefaultOutfit handles equipping on
                ; the next AI tick/cell transition. Undress already cleared the lock,
                ; so there's nothing to snapshot or clear.
                ResumeOutfitLock(akActor)
                return
            EndIf
        EndIf
        ; No stored clothing and no DefaultOutfit — try re-equipping locked outfit items
        Form[] lockedItems = SeverActionsNative.Native_Outfit_GetLockedItems(akActor)
        If lockedItems && lockedItems.Length > 0
            Debug.Trace("[SeverActions_Outfit] Dress: No stored items, re-equipping " + lockedItems.Length + " locked outfit items")
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

        Debug.Trace("[SeverActions_Outfit] No stored clothing or locked outfit to put on")
        ResumeOutfitLock(akActor)
        return
    endif

    ; Collect forms as we equip them
    Form[] equippedForms = new Form[32]
    Int equippedCount = 0

    int i = 0
    while i < count
        Form item = StorageUtil.FormListGet(None, storageKey, i)
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

    StorageUtil.FormListClear(None, storageKey)

    ; Clean up DefaultOutfit key since individual items were used
    String outfitKey = "SeverActions_DefaultOutfit_" + (akActor.GetFormID() as String)
    StorageUtil.UnsetFormValue(None, outfitKey)

    ; Lock from items we KNOW we equipped + GetWornForm for unchanged slots
    if equippedCount > 0
        LockEquippedOutfit(akActor, equippedForms, equippedCount)
    endif

    ; Clear active preset — dressing from stored items is a manual action
    SeverActionsNative.Native_Outfit_SetActivePreset(akActor, "")
    StorageUtil.SetStringValue(akActor, "SeverOutfit_ActivePreset", "")

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
    ; Check if they have stored individual items to put back on
    String storageKey = "SeverActions_RemovedArmor_" + (akActor.GetFormID() as String)
    if StorageUtil.FormListCount(None, storageKey) > 0
        return true
    endif
    ; Also eligible if we stored their DefaultOutfit (NPCs with only base gear)
    String outfitKey = "SeverActions_DefaultOutfit_" + (akActor.GetFormID() as String)
    Form storedOutfit = StorageUtil.GetFormValue(None, outfitKey, None)
    return storedOutfit as Outfit != None
EndFunction

; =============================================================================
; ACTION: EquipItemByName
; YAML parameterMapping: [speaker, itemName]
; Equips any item from actor's inventory by name (case-insensitive substring)
; =============================================================================

Function EquipItemByName_Execute(Actor akActor, String itemName)
    if !akActor
        return
    endif

    if itemName == ""
        Debug.Trace("[SeverActions_Outfit] EquipItemByName: No item name specified")
        return
    endif

    SuspendOutfitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] EquipItemByName: " + akActor.GetDisplayName() + " equipping '" + itemName + "'")

    ; Use native C++ for fast inventory search (resolve OmniSight names)
    String searchName = ResolveItemName(itemName)
    Form foundForm = SeverActionsNative.FindItemByName(akActor, searchName)
    if !foundForm && searchName != itemName
        foundForm = SeverActionsNative.FindItemByName(akActor, itemName)
    endif

    if !foundForm
        Debug.Trace("[SeverActions_Outfit] EquipItemByName: Item '" + itemName + "' not found in inventory")
        ResumeOutfitLock(akActor)
        return
    endif

    ; Handle armor
    Armor armorItem = foundForm as Armor
    if armorItem
        String slotName = GetSlotNameFromMask(armorItem.GetSlotMask())
        PlayEquipAnimation(akActor, slotName)
        akActor.EquipItem(armorItem, false, true)
        Form[] items = new Form[1]
        items[0] = armorItem as Form
        LockEquippedOutfit(akActor, items, 1)
        ResumeOutfitLock(akActor)
        Debug.Trace("[SeverActions_Outfit] Equipped armor: " + armorItem.GetName())
        return
    endif

    ; Handle weapons
    Weapon weaponItem = foundForm as Weapon
    if weaponItem
        akActor.EquipItem(weaponItem, false, true)
        ResumeOutfitLock(akActor)
        Debug.Trace("[SeverActions_Outfit] Equipped weapon: " + weaponItem.GetName())
        return
    endif

    ; Generic fallback for other equippable items (ammo, etc.)
    akActor.EquipItem(foundForm, false, true)
    ResumeOutfitLock(akActor)
    Debug.Trace("[SeverActions_Outfit] Equipped item: " + foundForm.GetName())
EndFunction

; =============================================================================
; ACTION: UnequipItemByName
; YAML parameterMapping: [speaker, itemName]
; Unequips a currently worn/equipped item by name (case-insensitive substring)
; =============================================================================

Function UnequipItemByName_Execute(Actor akActor, String itemName)
    if !akActor
        return
    endif

    if itemName == ""
        Debug.Trace("[SeverActions_Outfit] UnequipItemByName: No item name specified")
        return
    endif

    SuspendOutfitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] UnequipItemByName: " + akActor.GetDisplayName() + " removing '" + itemName + "'")

    ; Use native C++ for fast worn item search (resolve OmniSight names)
    String searchName = ResolveItemName(itemName)
    Form foundForm = SeverActionsNative.FindWornItemByName(akActor, searchName)
    if !foundForm && searchName != itemName
        foundForm = SeverActionsNative.FindWornItemByName(akActor, itemName)
    endif

    if !foundForm
        Debug.Trace("[SeverActions_Outfit] UnequipItemByName: '" + itemName + "' not found on " + akActor.GetDisplayName())
        ResumeOutfitLock(akActor)
        return
    endif

    ; Handle armor - store for Dress re-equip, play animation
    Armor armorItem = foundForm as Armor
    if armorItem
        String storageKey = "SeverActions_RemovedArmor_" + (akActor.GetFormID() as String)
        if StorageUtil.FormListFind(None, storageKey, armorItem) < 0
            StorageUtil.FormListAdd(None, storageKey, armorItem)
        endif

        String slotName = GetSlotNameFromMask(armorItem.GetSlotMask())
        PlayUnequipAnimation(akActor, slotName)
        akActor.UnequipItem(armorItem, true, true)
        ; Remove directly from lock list instead of re-snapshotting (GetWornForm is stale)
        Form[] removedForms = new Form[1]
        removedForms[0] = armorItem
        RemoveFromLockedOutfit(akActor, removedForms, 1)
        ResumeOutfitLock(akActor)
        Debug.Trace("[SeverActions_Outfit] Unequipped armor: " + armorItem.GetName())
        return
    endif

    ; Handle weapons - just unequip (no storage for Dress)
    akActor.UnequipItem(foundForm, true, true)
    ResumeOutfitLock(akActor)
    Debug.Trace("[SeverActions_Outfit] Unequipped item: " + foundForm.GetName())
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

    SuspendOutfitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] EquipMultipleItems: " + akActor.GetDisplayName() + " equipping '" + itemNames + "'")

    Form[] equippedForms = new Form[32]
    Int count = 0
    Int startPos = 0
    Int commaPos = StringUtil.Find(itemNames, ",", startPos)

    while startPos < StringUtil.GetLength(itemNames)
        String itemName
        if commaPos >= 0
            itemName = StringUtil.Substring(itemNames, startPos, commaPos - startPos)
            startPos = commaPos + 1
            commaPos = StringUtil.Find(itemNames, ",", startPos)
        else
            itemName = StringUtil.Substring(itemNames, startPos)
            startPos = StringUtil.GetLength(itemNames)
        endif

        ; Trim leading/trailing spaces
        itemName = TrimString(itemName)
        if itemName != "" && count < 32
            Form equipped = EquipSingleItemAndReturn(akActor, itemName)
            if equipped
                equippedForms[count] = equipped
                count += 1
            endif
        endif
    endwhile

    ; Lock from items we KNOW we equipped + GetWornForm for unchanged slots
    if count > 0
        LockEquippedOutfit(akActor, equippedForms, count)
    endif

    ; Clear active preset — manual equip overrides any preset
    SeverActionsNative.Native_Outfit_SetActivePreset(akActor, "")
    StorageUtil.SetStringValue(akActor, "SeverOutfit_ActivePreset", "")

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

    SuspendOutfitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] UnequipMultipleItems: " + akActor.GetDisplayName() + " removing '" + itemNames + "'")

    ; Collect Forms we actually unequip so we can remove them from the lock list
    Form[] removedForms = new Form[32]
    Int removedCount = 0

    Int startPos = 0
    Int commaPos = StringUtil.Find(itemNames, ",", startPos)

    while startPos < StringUtil.GetLength(itemNames)
        String itemName
        if commaPos >= 0
            itemName = StringUtil.Substring(itemNames, startPos, commaPos - startPos)
            startPos = commaPos + 1
            commaPos = StringUtil.Find(itemNames, ",", startPos)
        else
            itemName = StringUtil.Substring(itemNames, startPos)
            startPos = StringUtil.GetLength(itemNames)
        endif

        itemName = TrimString(itemName)
        if itemName != ""
            Form removed = UnequipSingleItemInternal2(akActor, itemName)
            if removed && removedCount < 32
                removedForms[removedCount] = removed
                removedCount += 1
            endif
        endif
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
    String presetKey = "SeverOutfit_" + presetName + "_" + (akActor.GetFormID() as String)

    Debug.Trace("[SeverActions_Outfit] SaveOutfitPreset: Saving '" + presetName + "' for " + akActor.GetDisplayName())

    ; Clear any existing preset with this name
    StorageUtil.FormListClear(None, presetKey)

    ; Store the preset name in a list of known presets for this actor
    String presetsListKey = "SeverOutfit_Presets_" + (akActor.GetFormID() as String)
    if StorageUtil.StringListFind(None, presetsListKey, presetName) < 0
        StorageUtil.StringListAdd(None, presetsListKey, presetName)
    endif

    ; Track this actor in the global preset actors list (for MCM Outfits page)
    String presetActorsKey = "SeverOutfit_PresetActors"
    if StorageUtil.FormListFind(None, presetActorsKey, akActor as Form) < 0
        StorageUtil.FormListAdd(None, presetActorsKey, akActor as Form)
    endif

    ; Get all worn armor via native C++ call (replaces 18-slot GetWornForm loop)
    Form[] wornForms = SeverActionsNative.Native_Outfit_GetWornArmor(akActor)
    Int savedCount = 0
    If wornForms
        savedCount = wornForms.Length
        Int i = 0
        While i < savedCount
            If wornForms[i]
                StorageUtil.FormListAdd(None, presetKey, wornForms[i])
            EndIf
            i += 1
        EndWhile
    EndIf

    ; Lock the outfit so it persists across cell changes
    SuspendOutfitLock(akActor)
    LockEquippedOutfit(akActor, wornForms, savedCount)
    ResumeOutfitLock(akActor)

    ; Dual-write preset to native OutfitDataStore for PrismaUI
    SeverActionsNative.Native_Outfit_BeginPreset(akActor, presetName)
    Int npi = 0
    While npi < savedCount && npi < 32
        if wornForms[npi]
            SeverActionsNative.Native_Outfit_AddPresetItem(akActor, wornForms[npi])
        endif
        npi += 1
    EndWhile
    SeverActionsNative.Native_Outfit_CommitPreset(akActor)

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
    String presetKey = "SeverOutfit_" + presetName + "_" + (akActor.GetFormID() as String)

    Int count = StorageUtil.FormListCount(None, presetKey)

    ; If StorageUtil is empty, try native store as fallback and sync
    ; (handles cases where the ModEvent sync hasn't processed yet)
    If count == 0
        Form[] nativeItems = SeverActionsNative.Native_Outfit_GetPresetItems(akActor, presetName)
        If nativeItems && nativeItems.Length > 0
            Int ni = 0
            While ni < nativeItems.Length
                If nativeItems[ni]
                    StorageUtil.FormListAdd(None, presetKey, nativeItems[ni])
                EndIf
                ni += 1
            EndWhile
            count = StorageUtil.FormListCount(None, presetKey)
            Debug.Trace("[SeverActions_Outfit] ApplyOutfitPreset: Synced " + count + " items from native store for '" + presetName + "'")
        EndIf
    EndIf

    if count == 0
        Debug.Trace("[SeverActions_Outfit] ApplyOutfitPreset: No preset '" + presetName + "' found for " + akActor.GetDisplayName())
        return
    endif

    SuspendOutfitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] ApplyOutfitPreset: Applying '" + presetName + "' (" + count + " items) to " + akActor.GetDisplayName())

    ; First undress — remove all currently worn items
    ; We use the RemovedArmor storage so Dress can still work as a fallback
    String storageKey = "SeverActions_RemovedArmor_" + (akActor.GetFormID() as String)
    StorageUtil.FormListClear(None, storageKey)

    int[] slots = new int[18]
    slots[0] = 0x00000001
    slots[1] = 0x00000004
    slots[2] = 0x00000008
    slots[3] = 0x00000010
    slots[4] = 0x00000020
    slots[5] = 0x00000040
    slots[6] = 0x00000080
    slots[7] = 0x00000200
    slots[8] = 0x00000400
    slots[9] = 0x00001000
    slots[10] = 0x00002000
    slots[11] = 0x00008000
    slots[12] = 0x00010000
    slots[13] = 0x00020000
    slots[14] = 0x00080000
    slots[15] = 0x00400000
    slots[16] = 0x02000000
    slots[17] = 0x08000000

    int s = 0
    while s < slots.Length
        Armor equippedItem = akActor.GetWornForm(slots[s]) as Armor
        if equippedItem
            ; Skip blacklisted items the user wants to always keep
            If !SeverActionsNative.Native_Blacklist_IsBlacklisted(equippedItem)
                if StorageUtil.FormListFind(None, storageKey, equippedItem) < 0
                    StorageUtil.FormListAdd(None, storageKey, equippedItem)
                endif
                akActor.UnequipItem(equippedItem, true, true)
            EndIf
        endif
        s += 1
    endwhile

    ; Now equip every item from the preset, collecting forms for lock.
    ; Add to inventory first if not present — preset items may have been
    ; from the catalog and not originally in the NPC's inventory.
    Form[] presetForms = new Form[32]
    Int equippedCount = 0
    int i = 0
    while i < count
        Form item = StorageUtil.FormListGet(None, presetKey, i)
        if item
            ; Ensure item is in inventory before equipping
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

    ; Lock from known equipped items (avoids GetWornForm race condition)
    LockEquippedOutfit(akActor, presetForms, equippedCount)

    ; Track active preset for prompt context and situation system
    SeverActionsNative.Native_Outfit_SetActivePreset(akActor, presetName)
    StorageUtil.SetStringValue(akActor, "SeverOutfit_ActivePreset", presetName)

    ResumeOutfitLock(akActor)

    ; Force re-evaluate situation after resume. If a situation event arrived
    ; while Suspended was set, it was correctly dropped — but SituationMonitor's
    ; C++ state already updated. Re-evaluating syncs the two sides and fires
    ; a new event if the situation actually changed during the apply.
    SeverActionsNative.SituationMonitor_ForceEvaluate(akActor)

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

    ; Store armor for Dress re-equip
    Armor armorItem = foundForm as Armor
    if armorItem
        String storageKey = "SeverActions_RemovedArmor_" + (akActor.GetFormID() as String)
        if StorageUtil.FormListFind(None, storageKey, armorItem) < 0
            StorageUtil.FormListAdd(None, storageKey, armorItem)
        endif
    endif

    akActor.UnequipItem(foundForm, true, true)
    Debug.Trace("[SeverActions_Outfit] UnequipMultiple: Unequipped '" + foundForm.GetName() + "'")
    return foundForm
EndFunction

Function RemoveFromLockedOutfit(Actor akActor, Form[] removedForms, Int count)
{Remove specific items from the locked outfit FormList instead of re-snapshotting.
 This avoids the GetWornForm race condition where UnequipItem is async and the
 item still appears worn when SnapshotLockedOutfit scans slots.}
    if !akActor || count == 0
        return
    endif

    if StorageUtil.GetIntValue(akActor, "SeverOutfit_LockActive", 0) != 1
        return
    endif

    String lockKey = "SeverOutfit_Locked_" + (akActor.GetFormID() as String)
    Int removed = 0
    Int i = 0
    while i < count
        if removedForms[i]
            Int idx = StorageUtil.FormListFind(None, lockKey, removedForms[i])
            if idx >= 0
                StorageUtil.FormListRemoveAt(None, lockKey, idx)
                ; Dual-write to native OutfitDataStore
                SeverActionsNative.Native_Outfit_RemoveLockedItem(akActor, removedForms[i])
                removed += 1
            endif
        endif
        i += 1
    endwhile

    if removed > 0
        Int remaining = StorageUtil.FormListCount(None, lockKey)
        Debug.Trace("[SeverActions_Outfit] Removed " + removed + " items from outfit lock (" + remaining + " remaining)")
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

Function SuspendOutfitLock(Actor akActor)
    if akActor
        StorageUtil.SetIntValue(akActor, "SeverOutfit_Suspended", 1)
    endif
EndFunction

Function ResumeOutfitLock(Actor akActor)
    if akActor
        StorageUtil.UnsetIntValue(akActor, "SeverOutfit_Suspended")
        ; Clear any burst suppression — our outfit system is back in control
        SeverActionsNative.Native_Outfit_ClearBurstSuppression(akActor)
    endif
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

    String lockKey = "SeverOutfit_Locked_" + (akActor.GetFormID() as String)
    StorageUtil.FormListClear(None, lockKey)

    ; Snapshot all 18 armor slots
    int[] slots = new int[18]
    slots[0] = 0x00000001   ; Head (30)
    slots[1] = 0x00000004   ; Body (32)
    slots[2] = 0x00000008   ; Hands (33)
    slots[3] = 0x00000010   ; Forearms (34)
    slots[4] = 0x00000020   ; Amulet (35)
    slots[5] = 0x00000040   ; Ring (36)
    slots[6] = 0x00000080   ; Feet (37)
    slots[7] = 0x00000200   ; Shield (39)
    slots[8] = 0x00000400   ; Tail/Cloak (40)
    slots[9] = 0x00001000   ; Circlet (42)
    slots[10] = 0x00002000  ; Ears (43)
    slots[11] = 0x00008000  ; Neck/Scarf (45)
    slots[12] = 0x00010000  ; Cloak (46)
    slots[13] = 0x00020000  ; Back/Cloak (47)
    slots[14] = 0x00080000  ; Pelvis outer (49)
    slots[15] = 0x00400000  ; Underwear (52)
    slots[16] = 0x02000000  ; Face (55)
    slots[17] = 0x08000000  ; Cloak (57)

    Int count = 0
    int i = 0
    while i < slots.Length
        Armor equippedItem = akActor.GetWornForm(slots[i]) as Armor
        if equippedItem
            if StorageUtil.FormListFind(None, lockKey, equippedItem) < 0
                StorageUtil.FormListAdd(None, lockKey, equippedItem)
                count += 1
            endif
        endif
        i += 1
    endwhile

    StorageUtil.SetIntValue(akActor, "SeverOutfit_LockActive", 1)

    ; Track this actor in the global outfit-locked list for alias reassignment after load
    TrackOutfitLockedActor(akActor)

    ; Dual-write to native OutfitDataStore for PrismaUI
    SeverActionsNative.Native_Outfit_BeginLock(akActor)
    Int nlCount = StorageUtil.FormListCount(None, lockKey)
    Int nli = 0
    While nli < nlCount
        Form nlItem = StorageUtil.FormListGet(None, lockKey, nli)
        if nlItem
            SeverActionsNative.Native_Outfit_AddLockedItem(akActor, nlItem)
        endif
        nli += 1
    EndWhile
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

    if StorageUtil.GetIntValue(akActor, "SeverOutfit_LockActive", 0) != 1
        return
    endif

    ; Global animation scene flag — set by SexLab/OStim ModEvent hooks
    If AnimationSceneActive
        return
    EndIf

    ; Already mid-operation — don't re-enter
    if StorageUtil.GetIntValue(akActor, "SeverOutfit_Suspended", 0) == 1
        return
    endif

    String lockKey = "SeverOutfit_Locked_" + (akActor.GetFormID() as String)
    Int count = StorageUtil.FormListCount(None, lockKey)

    if count == 0
        return
    endif

    ; Bulk strip detection: if NONE of the locked items are currently worn,
    ; another mod stripped everything at once (native DLL, bathing mod, etc.).
    ; Don't fight it — yield until the next cell transition re-asserts the lock.
    ; Single-item unequips (engine "equip best") will have most items still worn.
    Int wornCount = 0
    Int checkIdx = 0
    While checkIdx < count
        Form checkItem = StorageUtil.FormListGet(None, lockKey, checkIdx)
        If checkItem && akActor.IsEquipped(checkItem)
            wornCount += 1
        EndIf
        checkIdx += 1
    EndWhile

    If wornCount == 0 && count >= 2
        Debug.Trace("[SeverActions_Outfit] Bulk strip detected for " + akActor.GetDisplayName() + " — all " + count + " locked items removed. Yielding.")
        return
    EndIf

    SuspendOutfitLock(akActor)

    Int equipped = 0
    int i = 0
    while i < count
        Form item = StorageUtil.FormListGet(None, lockKey, i)
        if item
            akActor.EquipItem(item, false, true)
            equipped += 1
        endif
        i += 1
    endwhile

    ResumeOutfitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] Reapplied locked outfit for " + akActor.GetDisplayName() + " (" + equipped + " items)")
EndFunction

Function ClearLockedOutfit(Actor akActor)
    {Remove the outfit lock — follower will revert to engine-default behavior.}
    if !akActor
        return
    endif

    String lockKey = "SeverOutfit_Locked_" + (akActor.GetFormID() as String)
    StorageUtil.FormListClear(None, lockKey)
    StorageUtil.SetIntValue(akActor, "SeverOutfit_LockActive", 0)

    ; Remove from the global outfit-locked tracking list
    UntrackOutfitLockedActor(akActor)

    ; Dual-write to native OutfitDataStore
    SeverActionsNative.Native_Outfit_ClearLock(akActor)

    Debug.Trace("[SeverActions_Outfit] Cleared outfit lock for " + akActor.GetDisplayName())
EndFunction

Function LockEquippedOutfit(Actor akActor, Form[] equippedItems, Int equippedCount)
    {Lock outfit using ONLY the items we just equipped. No scanning GetWornForm
     for other slots — presets and builder outfits are exclusive (only preset items
     are worn, everything else stays off).}
    if !akActor || !OutfitLockEnabled
        return
    endif

    String lockKey = "SeverOutfit_Locked_" + (akActor.GetFormID() as String)
    StorageUtil.FormListClear(None, lockKey)

    ; Add only the items we explicitly equipped
    Int i = 0
    While i < equippedCount
        if equippedItems[i]
            if StorageUtil.FormListFind(None, lockKey, equippedItems[i]) < 0
                StorageUtil.FormListAdd(None, lockKey, equippedItems[i])
            endif
        endif
        i += 1
    EndWhile

    Int totalCount = StorageUtil.FormListCount(None, lockKey)
    StorageUtil.SetIntValue(akActor, "SeverOutfit_LockActive", 1)
    TrackOutfitLockedActor(akActor)

    ; Dual-write to native OutfitDataStore for PrismaUI
    SeverActionsNative.Native_Outfit_BeginLock(akActor)
    Int nli = 0
    While nli < totalCount
        Form nlItem = StorageUtil.FormListGet(None, lockKey, nli)
        if nlItem
            SeverActionsNative.Native_Outfit_AddLockedItem(akActor, nlItem)
        endif
        nli += 1
    EndWhile
    SeverActionsNative.Native_Outfit_CommitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] Locked outfit for " + akActor.GetDisplayName() + " (" + totalCount + " items)")
EndFunction

; =============================================================================
; OUTFIT LOCK ELIGIBILITY
; Determines whether an actor is eligible for outfit lock.
; Covers both registered followers and non-followers with explicit lock flag.
; =============================================================================

Bool Function IsOutfitLockEligible(Actor akActor)
    {Returns true if this actor can have outfit lock applied.
     Either a registered follower (SeverFollower_IsFollower == 1) or
     a non-follower with explicit lock enabled (SeverOutfit_NonFollowerLock == 1).}
    if !akActor
        return false
    endif
    if StorageUtil.GetIntValue(akActor, "SeverFollower_IsFollower", 0) == 1
        return true
    endif
    if StorageUtil.GetIntValue(akActor, "SeverOutfit_NonFollowerLock", 0) == 1
        return true
    endif
    return false
EndFunction

Function SetNonFollowerOutfitLock(Actor akActor, Bool enable)
    {Enable or disable outfit lock for a non-follower NPC.
     When enabling: sets the flag and snapshots current outfit.
     When disabling: clears the flag and removes the lock.}
    if !akActor
        return
    endif
    if enable
        StorageUtil.SetIntValue(akActor, "SeverOutfit_NonFollowerLock", 1)
        SnapshotLockedOutfit(akActor)
        Debug.Trace("[SeverActions_Outfit] Non-follower outfit lock ENABLED for " + akActor.GetDisplayName())
    else
        StorageUtil.UnsetIntValue(akActor, "SeverOutfit_NonFollowerLock")
        ClearLockedOutfit(akActor)
        Debug.Trace("[SeverActions_Outfit] Non-follower outfit lock DISABLED for " + akActor.GetDisplayName())
    endif
EndFunction

Bool Function HasNonFollowerOutfitLock(Actor akActor)
    {Check if a non-follower NPC has outfit lock explicitly enabled.}
    if !akActor
        return false
    endif
    return StorageUtil.GetIntValue(akActor, "SeverOutfit_NonFollowerLock", 0) == 1
EndFunction

; =============================================================================
; OUTFIT-LOCKED ACTOR TRACKING
; Maintains a persistent FormList of all actors with active outfit locks.
; Used by FollowerManager.ReassignOutfitSlots() to re-assign alias slots
; after save/load, including dismissed followers who still have locked outfits.
; =============================================================================

String Property OUTFIT_TRACKED_KEY = "SeverOutfit_TrackedActors" AutoReadOnly Hidden

Function TrackOutfitLockedActor(Actor akActor)
    {Add actor to the tracked outfit-locked list if not already present.}
    if !akActor
        return
    endif
    if StorageUtil.FormListFind(None, OUTFIT_TRACKED_KEY, akActor as Form) < 0
        StorageUtil.FormListAdd(None, OUTFIT_TRACKED_KEY, akActor as Form)
        Debug.Trace("[SeverActions_Outfit] Tracking outfit-locked actor: " + akActor.GetDisplayName())
    endif
EndFunction

Function UntrackOutfitLockedActor(Actor akActor)
    {Remove actor from the tracked outfit-locked list.}
    if !akActor
        return
    endif
    StorageUtil.FormListRemove(None, OUTFIT_TRACKED_KEY, akActor as Form, true)
    Debug.Trace("[SeverActions_Outfit] Untracked outfit-locked actor: " + akActor.GetDisplayName())
EndFunction

Actor[] Function GetOutfitLockedActors()
    {Return all actors with active outfit locks. Used by FollowerManager
     to reassign alias slots after save/load.}
    Int count = StorageUtil.FormListCount(None, OUTFIT_TRACKED_KEY)
    Actor[] result = PapyrusUtil.ActorArray(0)

    ; Iterate in reverse so removals don't skip entries
    Int i = count - 1
    While i >= 0
        Form entry = StorageUtil.FormListGet(None, OUTFIT_TRACKED_KEY, i)
        Actor akActor = entry as Actor
        if akActor && !akActor.IsDead()
            ; Verify the lock is still active (in case of stale entries)
            if StorageUtil.GetIntValue(akActor, "SeverOutfit_LockActive", 0) == 1
                result = PapyrusUtil.PushActor(result, akActor)
            else
                ; Stale entry — lock was cleared without going through ClearLockedOutfit
                StorageUtil.FormListRemoveAt(None, OUTFIT_TRACKED_KEY, i)
                Debug.Trace("[SeverActions_Outfit] Removed stale tracked actor: " + akActor.GetDisplayName())
            endif
        elseif !akActor
            ; Invalid form reference — remove it
            StorageUtil.FormListRemoveAt(None, OUTFIT_TRACKED_KEY, i)
        endif
        i -= 1
    EndWhile

    return result
EndFunction

; =============================================================================
; OUTFIT PRESET UTILITIES
; Query and manage saved outfit presets for MCM display
; =============================================================================

String[] Function GetPresetNames(Actor akActor)
    {Returns all saved outfit preset names for the given actor.
     Filters out internal presets (names starting with _).}
    if !akActor
        return PapyrusUtil.StringArray(0)
    endif
    String presetsListKey = "SeverOutfit_Presets_" + (akActor.GetFormID() as String)
    Int count = StorageUtil.StringListCount(None, presetsListKey)
    if count <= 0
        return PapyrusUtil.StringArray(0)
    endif
    ; First pass: count visible presets (skip internal _default etc.)
    Int visibleCount = 0
    Int i = 0
    While i < count
        String name = StorageUtil.StringListGet(None, presetsListKey, i)
        If StringUtil.GetNthChar(name, 0) != "_"
            visibleCount += 1
        EndIf
        i += 1
    EndWhile
    ; Second pass: collect visible presets
    String[] result = PapyrusUtil.StringArray(visibleCount)
    Int ri = 0
    i = 0
    While i < count
        String name = StorageUtil.StringListGet(None, presetsListKey, i)
        If StringUtil.GetNthChar(name, 0) != "_"
            result[ri] = name
            ri += 1
        EndIf
        i += 1
    EndWhile
    return result
EndFunction

Int Function GetPresetItemCount(Actor akActor, String presetName)
    {Returns the number of items in a saved preset, or 0 if not found.}
    if !akActor || presetName == ""
        return 0
    endif
    String presetKey = "SeverOutfit_" + presetName + "_" + (akActor.GetFormID() as String)
    return StorageUtil.FormListCount(None, presetKey)
EndFunction

Function DeletePreset(Actor akActor, String presetName)
    {Deletes a saved outfit preset by name. If no presets remain, removes
     actor from the global preset tracking list.}
    if !akActor || presetName == ""
        return
    endif
    String formID = akActor.GetFormID() as String
    String presetKey = "SeverOutfit_" + presetName + "_" + formID
    String presetsListKey = "SeverOutfit_Presets_" + formID

    ; Clear the item FormList
    StorageUtil.FormListClear(None, presetKey)

    ; Remove from the names list
    StorageUtil.StringListRemove(None, presetsListKey, presetName, true)

    ; If no presets remain, remove from global tracking list
    if StorageUtil.StringListCount(None, presetsListKey) <= 0
        StorageUtil.FormListRemove(None, "SeverOutfit_PresetActors", akActor as Form, true)
        ; Also clear non-follower lock if they have one and no presets remain
        if HasNonFollowerOutfitLock(akActor)
            SetNonFollowerOutfitLock(akActor, false)
        endif
    endif

    ; Dual-write to native OutfitDataStore
    SeverActionsNative.Native_Outfit_DeletePreset(akActor, presetName)

    Debug.Trace("[SeverActions_Outfit] DeletePreset: Deleted '" + presetName + "' for " + akActor.GetDisplayName())
EndFunction

; =============================================================================
; MIGRATION: StorageUtil → Native OutfitDataStore
; One-time migration for existing saves. Called from SeverActions_Init on load.
; Safe to call multiple times (idempotent — re-pushes current StorageUtil state).
; =============================================================================

Function MigrateOutfitDataToNative()
    {Reads existing outfit data from StorageUtil and pushes to native OutfitDataStore.
     Covers both locked outfits and saved presets for all tracked actors.
     One-time migration — skips if already done (native cosave persists across loads).}

    ; Fix #2: Skip if already migrated. Native OutfitDataStore persists via cosave,
    ; so re-pushing every load is redundant. Version 1 = initial migration done.
    Int migrationVersion = StorageUtil.GetIntValue(None, "SeverOutfit_MigrationVersion", 0)
    if migrationVersion >= 1
        Debug.Trace("[SeverActions_Outfit] MigrateOutfitDataToNative: Already migrated (v" + migrationVersion + "), skipping")
        return
    endif

    Debug.Trace("[SeverActions_Outfit] MigrateOutfitDataToNative: Starting migration...")
    Int migratedLocks = 0
    Int migratedPresets = 0

    ; Migrate locked outfit actors
    Actor[] lockedActors = GetOutfitLockedActors()
    Int i = 0
    While i < lockedActors.Length
        Actor akActor = lockedActors[i]
        if akActor
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
                migratedLocks += 1
            endif

            ; Migrate presets for this actor
            String[] presetNames = GetPresetNames(akActor)
            Int p = 0
            While p < presetNames.Length
                if presetNames[p] != ""
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
                        migratedPresets += 1
                    endif
                endif
                p += 1
            EndWhile
        endif
        i += 1
    EndWhile

    ; Also migrate preset-only actors (not locked, but have presets)
    Actor[] presetActors = GetPresetActors()
    Int j = 0
    While j < presetActors.Length
        Actor pActor = presetActors[j]
        if pActor
            ; Skip if already migrated above (they have locks too)
            Bool alreadyMigrated = false
            Int li = 0
            While li < lockedActors.Length && !alreadyMigrated
                if lockedActors[li] == pActor
                    alreadyMigrated = true
                endif
                li += 1
            EndWhile

            if !alreadyMigrated
                String[] presetNames = GetPresetNames(pActor)
                Int p = 0
                While p < presetNames.Length
                    if presetNames[p] != ""
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
                            migratedPresets += 1
                        endif
                    endif
                    p += 1
                EndWhile
            endif
        endif
        j += 1
    EndWhile

    ; Migrate situation data for all known actors (locked + preset actors)
    ; Combine both lists into one pass
    Int migratedSituations = 0
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
            ; Avoid duplicates
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

    String[] situations = new String[4]
    situations[0] = "adventure"
    situations[1] = "town"
    situations[2] = "home"
    situations[3] = "sleep"

    ai = 0
    While ai < allActors.Length
        Actor akActor = allActors[ai]
        if akActor
            ; Migrate active preset name
            String activePreset = StorageUtil.GetStringValue(akActor, "SeverOutfit_ActivePreset", "")
            if activePreset != ""
                SeverActionsNative.Native_Outfit_SetActivePreset(akActor, activePreset)
            endif

            ; Migrate current situation
            String curSit = StorageUtil.GetStringValue(akActor, "SeverOutfit_CurrentSituation", "")
            if curSit != ""
                SeverActionsNative.Native_Outfit_SetCurrentSituation(akActor, curSit)
            endif

            ; Migrate situation preset assignments
            Int si = 0
            While si < situations.Length
                String sitPreset = StorageUtil.GetStringValue(akActor, "SeverOutfit_Sit_" + situations[si], "")
                if sitPreset != ""
                    SeverActionsNative.Native_Outfit_SetSituationPreset(akActor, situations[si], sitPreset)
                    migratedSituations += 1
                endif
                si += 1
            EndWhile

            ; Migrate auto-switch per-actor setting (default true, so only migrate if explicitly disabled)
            Int autoSwitchVal = StorageUtil.GetIntValue(akActor, "SeverOutfit_AutoSwitch", 1)
            if autoSwitchVal == 0
                SeverActionsNative.Native_Outfit_SetAutoSwitchEnabled(akActor, false)
            endif
        endif
        ai += 1
    EndWhile

    ; Mark migration as complete so we skip on future loads
    StorageUtil.SetIntValue(None, "SeverOutfit_MigrationVersion", 1)

    Debug.Trace("[SeverActions_Outfit] MigrateOutfitDataToNative: Done — " + migratedLocks + " locks, " + migratedPresets + " presets, " + migratedSituations + " situation mappings migrated")
EndFunction

Actor[] Function GetPresetActors()
    {Return all actors with saved outfit presets. Used by MCM Outfits page.
     Cleans up stale entries (dead or invalid actors) as it iterates.}
    Int count = StorageUtil.FormListCount(None, "SeverOutfit_PresetActors")
    Actor[] result = PapyrusUtil.ActorArray(0)

    ; Iterate in reverse so removals don't skip entries
    Int i = count - 1
    While i >= 0
        Form entry = StorageUtil.FormListGet(None, "SeverOutfit_PresetActors", i)
        Actor akActor = entry as Actor
        if akActor && !akActor.IsDead()
            ; Verify they still have presets
            String presetsListKey = "SeverOutfit_Presets_" + (akActor.GetFormID() as String)
            if StorageUtil.StringListCount(None, presetsListKey) > 0
                result = PapyrusUtil.PushActor(result, akActor)
            else
                ; No presets left — remove stale entry
                StorageUtil.FormListRemoveAt(None, "SeverOutfit_PresetActors", i)
            endif
        elseif !akActor
            ; Invalid form reference — remove
            StorageUtil.FormListRemoveAt(None, "SeverOutfit_PresetActors", i)
        endif
        i -= 1
    EndWhile

    return result
EndFunction

; =============================================================================
; ACTION: RemoveClothingPiece (LEGACY - kept for compatibility)
; YAML parameterMapping: [speaker, slot]
; =============================================================================

Function RemoveClothingPiece_Execute(Actor akActor, String slot)
    if !akActor
        return
    endif

    if slot == ""
        Debug.Trace("[SeverActions_Outfit] RemoveClothingPiece: No slot specified")
        return
    endif

    SuspendOutfitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] RemoveClothingPiece: " + akActor.GetDisplayName() + " removing " + slot)
    
    ; Get all slots that match this slot name (e.g., helmet returns slots 30 and 31)
    int[] slotsToCheck = GetSlotsFromName(slot)
    String storageKey = "SeverActions_RemovedArmor_" + (akActor.GetFormID() as String)
    bool playedAnimation = false
    Form[] removedForms = new Form[10]
    Int removedCount = 0

    ; Try to remove items from all matching slots
    int s = 0
    while s < slotsToCheck.Length
        if slotsToCheck[s] != 0
            Armor equippedItem = akActor.GetWornForm(slotsToCheck[s]) as Armor
            if equippedItem
                String itemName = equippedItem.GetName()

                ; Store for later re-equipping
                if StorageUtil.FormListFind(None, storageKey, equippedItem) < 0
                    StorageUtil.FormListAdd(None, storageKey, equippedItem)
                endif

                ; Only play animation once
                if !playedAnimation
                    PlayUnequipAnimation(akActor, slot)
                    playedAnimation = true
                endif

                akActor.UnequipItem(equippedItem, true, true)
                ; Track for lock list removal
                if removedCount < 10
                    removedForms[removedCount] = equippedItem
                    removedCount += 1
                endif
                Debug.Trace("[SeverActions_Outfit] Removed: " + itemName)
            endif
        endif
        s += 1
    endwhile

    if removedCount == 0
        Debug.Trace("[SeverActions_Outfit] Nothing equipped in slot: " + slot)
    endif

    ; Remove unequipped items directly from the lock list instead of re-snapshotting.
    ; SnapshotLockedOutfit after UnequipItem is the documented anti-pattern — UnequipItem
    ; is async and GetWornForm returns stale data including the item just removed.
    if removedCount > 0
        RemoveFromLockedOutfit(akActor, removedForms, removedCount)
    endif

    ResumeOutfitLock(akActor)
EndFunction

; =============================================================================
; ACTION: EquipClothingPiece
; YAML parameterMapping: [speaker, slot]
; =============================================================================

Function EquipClothingPiece_Execute(Actor akActor, String slot)
    if !akActor
        return
    endif
    
    if slot == ""
        Debug.Trace("[SeverActions_Outfit] EquipClothingPiece: No slot specified")
        return
    endif
    
    Debug.Trace("[SeverActions_Outfit] EquipClothingPiece: " + akActor.GetDisplayName() + " putting on " + slot)
    
    String storageKey = "SeverActions_RemovedArmor_" + (akActor.GetFormID() as String)
    int count = StorageUtil.FormListCount(None, storageKey)
    
    int[] slotsToCheck = GetSlotsFromName(slot)
    
    ; Find stored item matching slot - check each slot in order of priority
    Armor itemToEquip = None
    int itemIndex = -1
    
    ; Go through each slot we should check for this slot name
    int s = 0
    while s < slotsToCheck.Length && !itemToEquip
        if slotsToCheck[s] != 0
            ; Search stored items for one matching this specific slot
            int i = 0
            while i < count && !itemToEquip
                Armor storedItem = StorageUtil.FormListGet(None, storageKey, i) as Armor
                if storedItem
                    int itemSlotMask = storedItem.GetSlotMask()
                    if Math.LogicalAnd(itemSlotMask, slotsToCheck[s]) > 0
                        itemToEquip = storedItem
                        itemIndex = i
                    endif
                endif
                i += 1
            endwhile
        endif
        s += 1
    endwhile
    
    if !itemToEquip
        Debug.Trace("[SeverActions_Outfit] No stored item for slot: " + slot)
        return
    endif
    
    String itemName = itemToEquip.GetName()

    SuspendOutfitLock(akActor)
    PlayEquipAnimation(akActor, slot)
    akActor.EquipItem(itemToEquip, false, true)
    StorageUtil.FormListRemoveAt(None, storageKey, itemIndex)

    ; Add to outfit lock so the item persists on cell load
    if StorageUtil.GetIntValue(akActor, "SeverOutfit_LockActive", 0) == 1
        String lockKey = "SeverOutfit_Locked_" + (akActor.GetFormID() as String)
        if StorageUtil.FormListFind(None, lockKey, itemToEquip) < 0
            StorageUtil.FormListAdd(None, lockKey, itemToEquip)
            SeverActionsNative.Native_Outfit_AddLockedItem(akActor, itemToEquip)
        endif
    endif

    ResumeOutfitLock(akActor)
    Debug.Trace("[SeverActions_Outfit] Equipped: " + itemName)
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

int Function GetSlotFromName(String slotName)
    String slot = StringToLower(slotName)
    
    if slot == "head" || slot == "helmet" || slot == "hat" || slot == "hood" || slot == "mask"
        return 0x00000001
    elseif slot == "body" || slot == "chest" || slot == "armor" || slot == "cuirass" || slot == "shirt" || slot == "robes" || slot == "dress"
        return 0x00000004
    elseif slot == "hands" || slot == "gloves" || slot == "gauntlets"
        return 0x00000008
    elseif slot == "forearms" || slot == "bracers"
        return 0x00000010
    elseif slot == "amulet" || slot == "necklace" || slot == "pendant"
        return 0x00000020
    elseif slot == "ring" || slot == "rings"
        return 0x00000040
    elseif slot == "feet" || slot == "boots" || slot == "shoes"
        return 0x00000080
    elseif slot == "calves" || slot == "greaves" || slot == "legs"
        return 0x00000100
    elseif slot == "shield"
        return 0x00000200
    elseif slot == "circlet" || slot == "crown"
        return 0x00001000
    elseif slot == "neck" || slot == "scarf"
        return 0x00008000
    elseif slot == "cloak" || slot == "cape" || slot == "mantle"
        return 0x00010000
    elseif slot == "back" || slot == "backpack"
        return 0x00020000
    elseif slot == "underwear" || slot == "smallclothes"
        return 0x00400000
    endif
    
    return 0
EndFunction

int[] Function GetSlotsFromName(String slotName)
    String slot = StringToLower(slotName)
    int[] results
    
    ; For head items, return both slots but ordered by priority based on what was requested
    if slot == "wig" || slot == "hair"
        ; Wig/hair requested - check slot 31 (Hair) first, then slot 30 (Head)
        results = new int[2]
        results[0] = 0x00000002  ; Slot 31 (Hair) - priority for wigs
        results[1] = 0x00000001  ; Slot 30 (Head) - fallback
        return results
    elseif slot == "head" || slot == "helmet" || slot == "hat" || slot == "hood" || slot == "mask"
        ; Helmet/hood requested - check slot 30 (Head) first, then slot 31 (Hair)
        results = new int[2]
        results[0] = 0x00000001  ; Slot 30 (Head) - priority for helmets
        results[1] = 0x00000002  ; Slot 31 (Hair) - fallback for some hoods
        return results
    elseif slot == "cloak" || slot == "cape" || slot == "mantle"
        results = new int[4]
        results[0] = 0x00000400  ; Slot 40 (Tail/Cloak)
        results[1] = 0x00010000  ; Slot 46
        results[2] = 0x00020000  ; Slot 47
        results[3] = 0x08000000  ; Slot 57
        return results
    endif
    
    results = new int[1]
    results[0] = GetSlotFromName(slotName)
    return results
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

    ; Verify the preset exists
    String presetKey = "SeverOutfit_" + presetName + "_" + (akActor.GetFormID() as String)
    if StorageUtil.FormListCount(None, presetKey) == 0
        Debug.Trace("[SeverActions_Outfit] SetSituationPreset: Preset '" + presetName + "' not found for " + akActor.GetDisplayName())
        return
    endif

    ; Dual-write to native + StorageUtil
    SeverActionsNative.Native_Outfit_SetSituationPreset(akActor, situation, presetName)
    StorageUtil.SetStringValue(akActor, "SeverOutfit_Sit_" + situation, presetName)

    Debug.Trace("[SeverActions_Outfit] SetSituationPreset: " + akActor.GetDisplayName() + " — " + situation + " → " + presetName)
EndFunction

Function ClearSituationPreset_Execute(Actor akActor, String situation)
{LLM action: Clear the preset assignment for a situation.}
    if !akActor || situation == ""
        return
    endif
    situation = NormalizeSituation(situation)

    SeverActionsNative.Native_Outfit_ClearSituationPreset(akActor, situation)
    StorageUtil.UnsetStringValue(akActor, "SeverOutfit_Sit_" + situation)

    Debug.Trace("[SeverActions_Outfit] ClearSituationPreset: " + akActor.GetDisplayName() + " — cleared " + situation)
EndFunction

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
    RegisterForModEvent("SeverActions_PrismaApplyPreset", "OnPrismaApplyPreset")
    RegisterForModEvent("SeverActions_PrismaDeletePreset", "OnPrismaDeletePreset")
    RegisterForModEvent("SeverActions_PrismaSavePreset", "OnPrismaSavePreset")
    RegisterForModEvent("SeverActions_PrismaSetSitPreset", "OnPrismaSetSitPreset")
    RegisterForModEvent("SeverActions_PrismaClearSitPreset", "OnPrismaClearSitPreset")
    ; PrismaUI auto-switch sync — fires when PrismaUI toggles global or per-actor setting
    RegisterForModEvent("SeverActions_PrismaToggleAutoSwitch", "OnPrismaToggleAutoSwitch")
    RegisterForModEvent("SeverActions_PrismaToggleActorAutoSwitch", "OnPrismaToggleActorAutoSwitch")
    ; PrismaUI inventory transfer — sync outfit lock StorageUtil after C++ transfers an equipped item
    RegisterForModEvent("SeverActions_PrismaInventorySync", "OnPrismaInventorySync")
    ; PrismaUI Builder equip — sync StorageUtil lock FormList from native store
    RegisterForModEvent("SeverActions_PrismaBuilderEquip", "OnPrismaBuilderEquip")
    ; PrismaUI Builder save preset — sync preset to StorageUtil from native store
    RegisterForModEvent("SeverActions_PrismaBuilderSavePreset", "OnPrismaBuilderSavePreset")
    ; PrismaUI clear lock for builder — clears Papyrus FormList when builder opens
    RegisterForModEvent("SeverActions_PrismaClearLockForBuilder", "OnPrismaClearLockForBuilder")
    ; PrismaUI resume lock — clears Papyrus suspend when builder closes
    RegisterForModEvent("SeverActions_PrismaResumeLock", "OnPrismaResumeLock")

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
    SeverActionsNative.SituationMonitor_SetEnabled(savedAutoSwitch)

    Debug.Trace("[SeverActions_Outfit] Maintenance: Registered for SituationChanged, CatalogEquipLock, 7 PrismaUI outfit events, and global auto-switch sync. AutoSwitch restored: " + savedAutoSwitch)
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
    If StorageUtil.GetIntValue(akActor, "SeverOutfit_Suspended", 0) == 1
        Return
    EndIf

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

    ; Update current situation tracking
    SeverActionsNative.Native_Outfit_SetCurrentSituation(akActor, situation)
    StorageUtil.SetStringValue(akActor, "SeverOutfit_CurrentSituation", situation)

    ; Apply the mapped preset
    Debug.Trace("[SeverActions_Outfit] Auto-switching " + akActor.GetDisplayName() + " to '" + presetName + "' for " + situation + " situation")
    ApplyOutfitPreset_Execute(akActor, presetName)
EndEvent

; =============================================================================
; EVENT: OnCatalogEquipLock
; Fired by PrismaUI catalog "Equip & Lock" mode (native C++).
; Syncs the Papyrus FormList outfit lock with the armor piece that C++ just
; equipped and added to OutfitDataStore.
; numArg = actor FormID, strArg = armor FormID as string
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
    StorageUtil.SetStringValue(akActor, "SeverOutfit_ActivePreset", "")

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

Event OnPrismaBuilderSavePreset(String eventName, String strArg, Float numArg, Form sender)
    {Fired by buildOutfitSavePreset C++ action. Syncs the preset from native
     OutfitDataStore to StorageUtil so MCM and Papyrus actions can see it.
     strArg format: "actorName|presetName" (standard SendModEvent encoding)}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    Actor akActor = SeverActionsNative.FindActorByName(StringUtil.Substring(strArg, 0, pipePos))
    String presetName = StringUtil.Substring(strArg, pipePos + 1)
    If !akActor || presetName == ""
        Return
    EndIf

    presetName = NormalizePresetName(presetName)
    String presetKey = "SeverOutfit_" + presetName + "_" + (akActor.GetFormID() as String)

    ; Clear any existing preset data and rebuild from native store
    StorageUtil.FormListClear(None, presetKey)
    Form[] presetItems = SeverActionsNative.Native_Outfit_GetPresetItems(akActor, presetName)
    If presetItems
        Int pi = 0
        While pi < presetItems.Length
            If presetItems[pi]
                StorageUtil.FormListAdd(None, presetKey, presetItems[pi])
            EndIf
            pi += 1
        EndWhile
    EndIf

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

    Debug.Trace("[SeverActions_Outfit] PrismaBuilderSavePreset: Synced preset '" + presetName + "' for " + akActor.GetDisplayName())
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
    StorageUtil.SetIntValue(akActor, "SeverOutfit_Suspended", 1)
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