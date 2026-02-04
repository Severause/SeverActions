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
    
    Debug.Trace("[SeverActions_Outfit] Dress: " + akActor.GetDisplayName())
    
    String storageKey = "SeverActions_RemovedArmor_" + (akActor.GetFormID() as String)
    int count = StorageUtil.FormListCount(None, storageKey)
    
    if count == 0
        Debug.Trace("[SeverActions_Outfit] No stored clothing to put on")
        return
    endif
    
    int i = 0
    while i < count
        Form item = StorageUtil.FormListGet(None, storageKey, i)
        if item
            Armor armorItem = item as Armor
            String slotName = GetSlotNameFromMask(armorItem.GetSlotMask())
            PlayEquipAnimation(akActor, slotName)
            akActor.EquipItem(armorItem, false, true)
        endif
        i += 1
    endwhile
    
    StorageUtil.FormListClear(None, storageKey)
    Debug.Trace("[SeverActions_Outfit] Re-equipped " + count + " items")
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
; ACTION: RemoveClothingPiece
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

String Function StringToLower(String text)
    ; Native implementation: ~2000-10000x faster
    return SeverActionsNative.StringToLower(text)
EndFunction