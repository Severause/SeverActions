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
    
    ; All slots to check - vanilla and modded (excluding slot 31/Hair and 38/Calves to preserve wigs)
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
    
    ; Slot names for animations
    String[] slotNames = new String[18]
    slotNames[0] = "helmet"
    slotNames[1] = "body"
    slotNames[2] = "hands"
    slotNames[3] = "hands"
    slotNames[4] = "neck"
    slotNames[5] = "ring"
    slotNames[6] = "feet"
    slotNames[7] = "body"
    slotNames[8] = "cloak"
    slotNames[9] = "helmet"
    slotNames[10] = "helmet"
    slotNames[11] = "neck"
    slotNames[12] = "cloak"
    slotNames[13] = "cloak"
    slotNames[14] = "body"
    slotNames[15] = "body"
    slotNames[16] = "helmet"
    slotNames[17] = "cloak"
    
    int i = 0
    int removedCount = 0
    while i < slots.Length
        Armor equippedItem = akActor.GetWornForm(slots[i]) as Armor
        if equippedItem
            if StorageUtil.FormListFind(None, storageKey, equippedItem) < 0
                StorageUtil.FormListAdd(None, storageKey, equippedItem)
                PlayUnequipAnimation(akActor, slotNames[i])
                akActor.UnequipItem(equippedItem, false, true)
                removedCount += 1
            endif
        endif
        i += 1
    endwhile
    
    ; Clear outfit lock — nothing worn means nothing to persist
    ClearLockedOutfit(akActor)

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
        Debug.Trace("[SeverActions_Outfit] No stored clothing to put on")
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

    ; Lock from items we KNOW we equipped + GetWornForm for unchanged slots
    if equippedCount > 0
        LockEquippedOutfit(akActor, equippedForms, equippedCount)
    endif

    ResumeOutfitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] Re-equipped " + equippedCount + " items")
EndFunction

Bool Function Dress_IsEligible(Actor akActor)
{Check if actor can be dressed - must be alive and have stored clothing}
    if !akActor
        return false
    endif
    if akActor.IsDead()
        return false
    endif
    ; Check if they have stored clothing to put back on
    String storageKey = "SeverActions_RemovedArmor_" + (akActor.GetFormID() as String)
    return StorageUtil.FormListCount(None, storageKey) > 0
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

    ; Use native C++ for fast inventory search
    Form foundForm = SeverActionsNative.FindItemByName(akActor, itemName)

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

    ; Use native C++ for fast worn item search (InventoryChanges.IsWorn + name match)
    Form foundForm = SeverActionsNative.FindWornItemByName(akActor, itemName)

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
        akActor.UnequipItem(armorItem, false, true)
        SnapshotLockedOutfit(akActor)
        ResumeOutfitLock(akActor)
        Debug.Trace("[SeverActions_Outfit] Unequipped armor: " + armorItem.GetName())
        return
    endif

    ; Handle weapons - just unequip (no storage for Dress)
    akActor.UnequipItem(foundForm, false, true)
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

        itemName = TrimString(itemName)
        if itemName != ""
            count += UnequipSingleItemInternal(akActor, itemName)
        endif
    endwhile

    ; Update the outfit lock after batch unequip
    if count > 0
        SnapshotLockedOutfit(akActor)
    endif

    ResumeOutfitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] UnequipMultipleItems: Unequipped " + count + " items")
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

    presetName = StringToLower(presetName)
    String presetKey = "SeverOutfit_" + presetName + "_" + (akActor.GetFormID() as String)

    Debug.Trace("[SeverActions_Outfit] SaveOutfitPreset: Saving '" + presetName + "' for " + akActor.GetDisplayName())

    ; Clear any existing preset with this name
    StorageUtil.FormListClear(None, presetKey)

    ; Store the preset name in a list of known presets for this actor
    String presetsListKey = "SeverOutfit_Presets_" + (akActor.GetFormID() as String)
    if StorageUtil.StringListFind(None, presetsListKey, presetName) < 0
        StorageUtil.StringListAdd(None, presetsListKey, presetName)
    endif

    ; Iterate all worn slots and snapshot them
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

    Int savedCount = 0
    int i = 0
    while i < slots.Length
        Armor equippedItem = akActor.GetWornForm(slots[i]) as Armor
        if equippedItem
            ; Avoid duplicates (multi-slot items)
            if StorageUtil.FormListFind(None, presetKey, equippedItem) < 0
                StorageUtil.FormListAdd(None, presetKey, equippedItem)
                savedCount += 1
            endif
        endif
        i += 1
    endwhile

    Debug.Trace("[SeverActions_Outfit] SaveOutfitPreset: Saved " + savedCount + " items as '" + presetName + "'")
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

    presetName = StringToLower(presetName)
    String presetKey = "SeverOutfit_" + presetName + "_" + (akActor.GetFormID() as String)

    Int count = StorageUtil.FormListCount(None, presetKey)
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
            if StorageUtil.FormListFind(None, storageKey, equippedItem) < 0
                StorageUtil.FormListAdd(None, storageKey, equippedItem)
            endif
            akActor.UnequipItem(equippedItem, false, true)
        endif
        s += 1
    endwhile

    ; Now equip every item from the preset, collecting forms for lock
    Form[] presetForms = new Form[32]
    Int equippedCount = 0
    int i = 0
    while i < count
        Form item = StorageUtil.FormListGet(None, presetKey, i)
        if item
            Armor armorItem = item as Armor
            if armorItem
                String slotName = GetSlotNameFromMask(armorItem.GetSlotMask())
                PlayEquipAnimation(akActor, slotName)
            endif
            akActor.EquipItem(item, false, true)
            if equippedCount < 32
                presetForms[equippedCount] = item
            endif
            equippedCount += 1
        endif
        i += 1
    endwhile

    ; Lock from known equipped items (avoids GetWornForm race condition)
    LockEquippedOutfit(akActor, presetForms, equippedCount)

    ResumeOutfitLock(akActor)

    Debug.Trace("[SeverActions_Outfit] ApplyOutfitPreset: Equipped " + equippedCount + " items from '" + presetName + "'")
EndFunction

; =============================================================================
; INTERNAL HELPERS - C++ search + Papyrus equip (thread-safe)
; =============================================================================

Int Function EquipSingleItemInternal(Actor akActor, String itemName)
{Search inventory in C++, equip via Papyrus EquipItem. Returns 1 on success, 0 on failure.}
    Form foundForm = SeverActionsNative.FindItemByName(akActor, itemName)
    if !foundForm
        Debug.Trace("[SeverActions_Outfit] EquipMultiple: '" + itemName + "' not found in inventory")
        return 0
    endif

    akActor.EquipItem(foundForm, false, true)
    Debug.Trace("[SeverActions_Outfit] EquipMultiple: Equipped '" + foundForm.GetName() + "'")
    return 1
EndFunction

Form Function EquipSingleItemAndReturn(Actor akActor, String itemName)
{Search inventory in C++, equip via Papyrus EquipItem. Returns the equipped Form, or None on failure.}
    Form foundForm = SeverActionsNative.FindItemByName(akActor, itemName)
    if !foundForm
        Debug.Trace("[SeverActions_Outfit] EquipMultiple: '" + itemName + "' not found in inventory")
        return None
    endif

    akActor.EquipItem(foundForm, false, true)
    Debug.Trace("[SeverActions_Outfit] EquipMultiple: Equipped '" + foundForm.GetName() + "'")
    return foundForm
EndFunction

Int Function UnequipSingleItemInternal(Actor akActor, String itemName)
{Search worn items in C++, unequip via Papyrus UnequipItem. Returns 1 on success, 0 on failure.}
    Form foundForm = SeverActionsNative.FindWornItemByName(akActor, itemName)
    if !foundForm
        Debug.Trace("[SeverActions_Outfit] UnequipMultiple: '" + itemName + "' not worn")
        return 0
    endif

    ; Store armor for Dress re-equip
    Armor armorItem = foundForm as Armor
    if armorItem
        String storageKey = "SeverActions_RemovedArmor_" + (akActor.GetFormID() as String)
        if StorageUtil.FormListFind(None, storageKey, armorItem) < 0
            StorageUtil.FormListAdd(None, storageKey, armorItem)
        endif
    endif

    akActor.UnequipItem(foundForm, false, true)
    Debug.Trace("[SeverActions_Outfit] UnequipMultiple: Unequipped '" + foundForm.GetName() + "'")
    return 1
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

    ; Only lock outfits for registered followers
    if StorageUtil.GetIntValue(akActor, "SeverFollower_IsFollower", 0) != 1
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

    Debug.Trace("[SeverActions_Outfit] Locked outfit for " + akActor.GetDisplayName() + " (" + count + " items)")
EndFunction

Function ReapplyLockedOutfit(Actor akActor)
    {Silently re-equip all items from the locked outfit snapshot.
     Called by FollowerManager on cell transitions — no animations.}
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

    String lockKey = "SeverOutfit_Locked_" + (akActor.GetFormID() as String)
    Int count = StorageUtil.FormListCount(None, lockKey)

    if count == 0
        return
    endif

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

    Debug.Trace("[SeverActions_Outfit] Cleared outfit lock for " + akActor.GetDisplayName())
EndFunction

Function LockEquippedOutfit(Actor akActor, Form[] equippedItems, Int equippedCount)
    {Lock outfit using the items we KNOW we just equipped, merged with GetWornForm
     for slots that weren't changed. This avoids the race condition where GetWornForm
     returns stale data because queued OnObjectUnequipped events haven't fired yet.
     Call this instead of SnapshotLockedOutfit after equipping items.}
    if !akActor || !OutfitLockEnabled
        return
    endif

    ; Only lock outfits for registered followers
    if StorageUtil.GetIntValue(akActor, "SeverFollower_IsFollower", 0) != 1
        return
    endif

    String lockKey = "SeverOutfit_Locked_" + (akActor.GetFormID() as String)
    StorageUtil.FormListClear(None, lockKey)

    ; 1) Add all items we KNOW we just equipped (guaranteed fresh — not stale)
    Int i = 0
    While i < equippedCount
        if equippedItems[i]
            if StorageUtil.FormListFind(None, lockKey, equippedItems[i]) < 0
                StorageUtil.FormListAdd(None, lockKey, equippedItems[i])
            endif
        endif
        i += 1
    EndWhile

    ; 2) Also scan GetWornForm for items in OTHER slots (preserves unchanged gear)
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

    i = 0
    while i < slots.Length
        Armor equippedItem = akActor.GetWornForm(slots[i]) as Armor
        if equippedItem
            if StorageUtil.FormListFind(None, lockKey, equippedItem) < 0
                StorageUtil.FormListAdd(None, lockKey, equippedItem)
            endif
        endif
        i += 1
    endwhile

    Int totalCount = StorageUtil.FormListCount(None, lockKey)
    StorageUtil.SetIntValue(akActor, "SeverOutfit_LockActive", 1)
    TrackOutfitLockedActor(akActor)

    Debug.Trace("[SeverActions_Outfit] Locked outfit for " + akActor.GetDisplayName() + " (" + totalCount + " items)")
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

    Int i = 0
    While i < count
        Form entry = StorageUtil.FormListGet(None, OUTFIT_TRACKED_KEY, i)
        Actor akActor = entry as Actor
        if akActor && !akActor.IsDead()
            ; Verify the lock is still active (in case of stale entries)
            if StorageUtil.GetIntValue(akActor, "SeverOutfit_LockActive", 0) == 1
                result = PapyrusUtil.PushActor(result, akActor)
            else
                ; Stale entry — lock was cleared without going through ClearLockedOutfit
                StorageUtil.FormListRemove(None, OUTFIT_TRACKED_KEY, entry, true)
                Debug.Trace("[SeverActions_Outfit] Removed stale tracked actor: " + akActor.GetDisplayName())
            endif
        elseif !akActor
            ; Invalid form reference — remove it
            StorageUtil.FormListRemove(None, OUTFIT_TRACKED_KEY, entry, true)
        endif
        i += 1
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
    bool removedSomething = false
    bool playedAnimation = false
    
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
                
                akActor.UnequipItem(equippedItem, false, true)
                Debug.Trace("[SeverActions_Outfit] Removed: " + itemName)
                removedSomething = true
            endif
        endif
        s += 1
    endwhile
    
    if !removedSomething
        Debug.Trace("[SeverActions_Outfit] Nothing equipped in slot: " + slot)
    endif

    ; Re-snapshot after removing a piece so the lock reflects the new state
    if removedSomething
        SnapshotLockedOutfit(akActor)
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
    PlayEquipAnimation(akActor, slot)
    akActor.EquipItem(itemToEquip, false, true)
    StorageUtil.FormListRemoveAt(None, storageKey, itemIndex)
    
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