Scriptname SeverActions_Loot extends Quest
{Item pickup, delivery, and looting action handlers for SkyrimNet integration - by Severause
Also supports merchant chest access for GiveItem/UseItem actions.}

; =============================================================================
; CONSTANTS
; =============================================================================

float Property SEARCH_RADIUS = 1000.0 AutoReadOnly
float Property INTERACTION_DISTANCE = 150.0 AutoReadOnly

; =============================================================================
; LOOT TRACKING - Stores description of last looted items
; =============================================================================

String LastLootedItems = ""

; =============================================================================
; BOOK READING STATE - Tracks active book reading for prompt integration
; =============================================================================

Actor Property BookReader Auto Hidden
{The NPC currently reading a book aloud. None if nobody is reading.}

String Property BookReadingTitle = "" Auto Hidden
{The title of the book currently being read.}

String Property BookReadingText = "" Auto Hidden
{The full text content of the book currently being read.}

Float Property BookReadingStartTime = 0.0 Auto Hidden
{Real time when reading started. Used for auto-timeout.}

Float Property BookReadingTimeout = 300.0 Auto Hidden
{Max reading duration in seconds before auto-clearing state (5 minutes).}

; Real time when the last reading narration was sent. Used for auto-continue.
Float BookReadingLastNarrationTime = 0.0

Float Property BookReadingContinueDelay = 15.0 Auto Hidden
{Seconds to wait after speech queue empties before sending a continue narration.}

Float Property BookReadingUpdateInterval = 5.0 Auto Hidden
{How often to check speech queue during book reading (seconds).}

; =============================================================================
; ANIMATION PROPERTIES
; =============================================================================

Idle Property IdleGive Auto
Idle Property IdlePickUpItem Auto
Idle Property IdleSearchingChest Auto
Idle Property IdleLootBody Auto
Idle Property IdleForceDefaultState Auto

; Consume animations
Idle Property IdleDrinkPotion Auto
Idle Property IdleEatSoup Auto

; Book reading animations
Idle Property IdleBook_Reading Auto
Idle Property IdleBook_ReadingSitting Auto

; =============================================================================
; SCRIPT REFERENCES
; =============================================================================

SeverActions_Survival Property SurvivalScript Auto

; =============================================================================
; AI PACKAGE PROPERTIES
; =============================================================================

Package Property GoToRefPackage Auto
ReferenceAlias Property TargetRefAlias Auto

; =============================================================================
; MOVEMENT HELPER FUNCTIONS
; =============================================================================

Bool Function WalkToReference(Actor akActor, ObjectReference akTarget, float maxWaitTime = 15.0)
    if !akActor || !akTarget
        return false
    endif
    
    if GoToRefPackage && TargetRefAlias
        TargetRefAlias.ForceRefTo(akTarget)
        ActorUtil.AddPackageOverride(akActor, GoToRefPackage, 100)
        akActor.EvaluatePackage()
        
        float elapsed = 0.0
        while akActor.GetDistance(akTarget) > INTERACTION_DISTANCE && elapsed < maxWaitTime
            Utility.Wait(0.25)
            elapsed += 0.25
        endwhile
        
        ActorUtil.RemovePackageOverride(akActor, GoToRefPackage)
        akActor.EvaluatePackage()
        TargetRefAlias.Clear()
        return akActor.GetDistance(akTarget) <= INTERACTION_DISTANCE
    else
        akActor.PathToReference(akTarget, 1.0)
        float elapsed = 0.0
        while akActor.GetDistance(akTarget) > INTERACTION_DISTANCE && elapsed < maxWaitTime
            Utility.Wait(0.1)
            elapsed += 0.1
        endwhile
        return akActor.GetDistance(akTarget) <= INTERACTION_DISTANCE
    endif
EndFunction

; =============================================================================
; JSON HELPER FUNCTIONS
; =============================================================================

String Function EscapeJsonString(String text) Global
    ; Native implementation: ~2000x faster
    return SeverActionsNative.EscapeJsonString(text)
EndFunction

String Function GetDirectionString(Actor akActor, ObjectReference akTarget) Global
    float headingToTarget = akActor.GetHeadingAngle(akTarget)
    if headingToTarget > -45.0 && headingToTarget < 45.0
        return "ahead"
    elseif headingToTarget >= 45.0 && headingToTarget < 135.0
        return "to the right"
    elseif headingToTarget <= -45.0 && headingToTarget > -135.0
        return "to the left"
    else
        return "behind"
    endif
EndFunction

; Convert string to lowercase
String Function ToLowerCase(String text) Global
    ; Native implementation: ~2000-10000x faster
    return SeverActionsNative.StringToLower(text)
EndFunction

; =============================================================================
; CONTAINER LOOKUP BY REFID
; =============================================================================

ObjectReference Function GetContainerByRefID(String refIdStr)
{Convert a RefID string to an ObjectReference. Accepts decimal or hex format.}
    if refIdStr == ""
        return None
    endif
    
    ; Parse the RefID - handles both decimal ("463155") and hex ("0x71193")
    int refId = refIdStr as int
    if refId == 0 && refIdStr != "0"
        ; Try parsing as hex if decimal conversion failed
        Debug.Trace("[SeverActions_Loot] Failed to parse RefID as decimal: " + refIdStr)
        return None
    endif
    
    Form foundForm = Game.GetFormEx(refId)
    if !foundForm
        Debug.Trace("[SeverActions_Loot] GetFormEx returned None for RefID: " + refIdStr)
        return None
    endif
    
    ObjectReference containerRef = foundForm as ObjectReference
    if !containerRef
        Debug.Trace("[SeverActions_Loot] Form is not an ObjectReference: " + refIdStr)
        return None
    endif
    
    return containerRef
EndFunction

; =============================================================================
; ACTION HANDLERS
; =============================================================================

; --- PickUpItem by name/type ---

Bool Function PickUpItem_IsEligible(Actor akActor, String itemType) Global
{Check if actor can pick up a nearby item matching the given name/type.}
    if !akActor || akActor.IsDead() || akActor.IsInCombat()
        return false
    endif

    return FindNearbyItemOfType(akActor, itemType) != None
EndFunction

Function PickUpItem_Execute(Actor akActor, String itemType)
{Pick up a nearby item matching the given name/type.}
    if !akActor || itemType == ""
        return
    endif

    ObjectReference nearbyItem = FindNearbyItemOfType(akActor, itemType)

    if nearbyItem
        Form itemBase = nearbyItem.GetBaseObject()
        String itemName = itemBase.GetName()

        if WalkToReference(akActor, nearbyItem)
            if IdlePickUpItem
                PlayAnimationAndWait(akActor, IdlePickUpItem, 1.5)
            endif
            nearbyItem.Activate(akActor)
            ResetToDefaultIdle(akActor)
            SkyrimNetApi.RegisterEvent("item_picked_up", akActor.GetDisplayName() + " picked up " + itemName, akActor, None)
        else
            SkyrimNetApi.RegisterEvent("item_unreachable", akActor.GetDisplayName() + " couldn't reach " + itemName, akActor, None)
        endif
    else
        SkyrimNetApi.RegisterEvent("item_not_found", akActor.GetDisplayName() + " couldn't find that item", akActor, None)
    endif
EndFunction

; =============================================================================
; ACTION: LootContainer - Loot a container by its RefID
; =============================================================================

Bool Function LootContainer_IsEligible(Actor akActor, String containerName) Global
{Check if actor can loot a nearby container matching the given name.}
    if !akActor || akActor.IsDead() || akActor.IsInCombat() || containerName == ""
        return false
    endif

    return FindNearbyContainer(akActor, containerName) != None
EndFunction

Function LootContainer_Execute(Actor akActor, String containerName, String itemsToTake)
{Loot a nearby container by name. itemsToTake can be "all", "valuables", "gold", or comma-separated item names.}
    if !akActor || containerName == ""
        return
    endif

    ObjectReference akContainer = FindNearbyContainer(akActor, containerName)
    if !akContainer
        SkyrimNetApi.RegisterEvent("container_not_found", akActor.GetDisplayName() + " couldn't find a " + containerName + " nearby", akActor, None)
        return
    endif

    String displayName = akContainer.GetBaseObject().GetName()
    Debug.Trace("[SeverActions_Loot] " + akActor.GetDisplayName() + " looting container: " + displayName)

    if WalkToReference(akActor, akContainer)
        if IdleSearchingChest
            PlayAnimationAndWait(akActor, IdleSearchingChest, 2.5)
        endif
        ; End the searching animation before processing loot (can take a while for many items)
        ResetToDefaultIdle(akActor)
        Utility.Wait(0.2)
        int itemsTaken = ProcessLootList(akActor, akContainer, itemsToTake)
        ResetToDefaultIdle(akActor)

        if itemsTaken > 0 && LastLootedItems != ""
            SkyrimNetApi.RegisterEvent("container_looted", akActor.GetDisplayName() + " took " + LastLootedItems + " from " + displayName, akActor, None)
        else
            SkyrimNetApi.RegisterEvent("container_looted", akActor.GetDisplayName() + " found nothing to take from " + displayName, akActor, None)
        endif
    else
        SkyrimNetApi.RegisterEvent("container_unreachable", akActor.GetDisplayName() + " couldn't reach " + displayName, akActor, None)
    endif
EndFunction

; =============================================================================
; ACTION: LootCorpse - Loot a dead actor by name
; =============================================================================

Bool Function LootCorpse_IsEligible(Actor akActor, String corpseName) Global
    if !akActor || akActor.IsDead() || akActor.IsInCombat() || corpseName == ""
        return false
    endif

    Actor akCorpse = SeverActionsNative.FindActorByName(corpseName)
    if !akCorpse || !akCorpse.IsDead()
        return false
    endif

    return akActor.GetDistance(akCorpse) < 4096.0 && akCorpse.GetNumItems() > 0
EndFunction

Function LootCorpse_Execute(Actor akActor, String corpseName, String itemsToTake)
    if !akActor || corpseName == ""
        return
    endif

    Actor akCorpse = SeverActionsNative.FindActorByName(corpseName)
    if !akCorpse
        SkyrimNetApi.RegisterEvent("corpse_not_found", akActor.GetDisplayName() + " couldn't find " + corpseName, akActor, None)
        return
    endif

    if !akCorpse.IsDead()
        Debug.Trace("[SeverActions_Loot] LootCorpse: " + corpseName + " is not dead, aborting")
        SkyrimNetApi.RegisterEvent("corpse_not_found", akActor.GetDisplayName() + " - " + corpseName + " is not dead", akActor, None)
        return
    endif

    if akActor.GetDistance(akCorpse) > 4096.0
        SkyrimNetApi.RegisterEvent("corpse_unreachable", akActor.GetDisplayName() + " is too far from " + corpseName, akActor, None)
        return
    endif

    if WalkToReference(akActor, akCorpse)
        if IdleLootBody
            PlayAnimationAndWait(akActor, IdleLootBody, 3.0)
        endif
        ; End the looting animation before processing loot (can take a while for many items)
        ResetToDefaultIdle(akActor)
        Utility.Wait(0.2)
        int itemsTaken = ProcessLootList(akActor, akCorpse, itemsToTake)
        ResetToDefaultIdle(akActor)

        String displayName = akCorpse.GetDisplayName()
        if itemsTaken > 0 && LastLootedItems != ""
            SkyrimNetApi.RegisterEvent("corpse_looted", akActor.GetDisplayName() + " looted " + LastLootedItems + " from " + displayName, akActor, None)
        else
            SkyrimNetApi.RegisterEvent("corpse_looted", akActor.GetDisplayName() + " found nothing to take from " + displayName, akActor, None)
        endif
    else
        SkyrimNetApi.RegisterEvent("corpse_unreachable", akActor.GetDisplayName() + " couldn't reach " + corpseName, akActor, None)
    endif
EndFunction

; =============================================================================
; ACTION: GiveItem - NPC gives item(s) from their inventory to another actor
; Also checks merchant chest if NPC is a merchant
; =============================================================================

Bool Function GiveItem_IsEligible(Actor akActor, Actor akTarget, String itemName, Int aiCount = 1) Global
    if !akActor || !akTarget || akActor.IsDead() || akActor.IsInCombat()
        return false
    endif
    ; Check personal inventory first, then merchant stock
    return MerchantHasItem(akActor, itemName)
EndFunction

Function GiveItem_Execute(Actor akActor, Actor akTarget, String itemName, Int aiCount = 1)
    if !akActor || !akTarget || itemName == ""
        return
    endif
    
    ; Ensure at least 1
    if aiCount < 1
        aiCount = 1
    endif
    
    if WalkToReference(akActor, akTarget)
        if IdleGive
            PlayAnimationAndWait(akActor, IdleGive, 2.0)
        endif
        
        ; Try personal inventory first
        Form itemForm = GetItemFormByName(akActor, itemName)
        Int transferred = 0
        String actualName = itemName
        Bool fromMerchantChest = false
        
        if itemForm && akActor.GetItemCount(itemForm) > 0
            ; Has it in personal inventory
            actualName = itemForm.GetName()
            Int available = akActor.GetItemCount(itemForm)
            transferred = aiCount
            if transferred > available
                transferred = available
            endif
            
            if transferred > 0
                akActor.RemoveItem(itemForm, transferred, false, akTarget)
            endif
        else
            ; Check merchant chest
            ObjectReference merchantChest = GetMerchantContainer(akActor)
            if merchantChest && merchantChest != akActor
                itemForm = FindItemInContainer(merchantChest, itemName)
                if itemForm && merchantChest.GetItemCount(itemForm) > 0
                    actualName = itemForm.GetName()
                    Int available = merchantChest.GetItemCount(itemForm)
                    transferred = aiCount
                    if transferred > available
                        transferred = available
                    endif
                    
                    if transferred > 0
                        merchantChest.RemoveItem(itemForm, transferred, false, akTarget)
                        fromMerchantChest = true
                    endif
                endif
            endif
        endif
        
        ResetToDefaultIdle(akActor)

        ; Auto-debt growth: if giver is creditor for a debt with receiver, add item gold value
        if transferred > 0 && itemForm
            SeverActions_Debt debtSys = SeverActions_Debt.GetInstance()
            if debtSys
                int goldValue = GetFormValue(itemForm) * transferred
                if goldValue > 0
                    debtSys.AutoAddToDebt(akActor, akTarget, goldValue)
                endif
            endif
        endif

        ; Build event string
        if transferred > 1
            SkyrimNetApi.RegisterEvent("item_given", akActor.GetDisplayName() + " gave " + transferred + " " + actualName + " to " + akTarget.GetDisplayName(), akActor, akTarget)
        elseif transferred == 1
            SkyrimNetApi.RegisterEvent("item_given", akActor.GetDisplayName() + " gave " + actualName + " to " + akTarget.GetDisplayName(), akActor, akTarget)
        else
            SkyrimNetApi.RegisterEvent("item_give_failed", akActor.GetDisplayName() + " doesn't have " + itemName + " to give", akActor, akTarget)
        endif
    endif
EndFunction

; =============================================================================
; ACTION: BringItem - NPC picks up a nearby item and brings it to target
; =============================================================================

Bool Function BringItem_IsEligible(Actor akActor, Actor akTarget, String itemType) Global
{Check if actor can bring a nearby item matching the given name/type to the target.}
    if !akActor || !akTarget || akActor.IsDead() || akActor.IsInCombat()
        return false
    endif

    return FindNearbyItemOfType(akActor, itemType) != None
EndFunction

Function BringItem_Execute(Actor akActor, Actor akTarget, String itemType)
{Bring a nearby item matching the given name/type to the target.}
    if !akActor || !akTarget || itemType == ""
        return
    endif

    ObjectReference nearbyItem = FindNearbyItemOfType(akActor, itemType)

    if nearbyItem
        Form itemBase = nearbyItem.GetBaseObject()
        String itemName = itemBase.GetName()

        if WalkToReference(akActor, nearbyItem)
            if IdlePickUpItem
                PlayAnimationAndWait(akActor, IdlePickUpItem, 1.5)
            endif
            akActor.AddItem(itemBase, 1, true)
            nearbyItem.Disable()
            nearbyItem.Delete()

            if WalkToReference(akActor, akTarget)
                if IdleGive
                    PlayAnimationAndWait(akActor, IdleGive, 2.0)
                endif
                akActor.RemoveItem(itemBase, 1, false, akTarget)
                ResetToDefaultIdle(akActor)
                SkyrimNetApi.RegisterEvent("item_brought", akActor.GetDisplayName() + " brought " + itemName + " to " + akTarget.GetDisplayName(), akActor, akTarget)
            else
                ; Couldn't reach target, but already picked up item - keep it
                ResetToDefaultIdle(akActor)
                SkyrimNetApi.RegisterEvent("target_unreachable", akActor.GetDisplayName() + " picked up " + itemName + " but couldn't reach " + akTarget.GetDisplayName(), akActor, akTarget)
            endif
        else
            SkyrimNetApi.RegisterEvent("item_unreachable", akActor.GetDisplayName() + " couldn't reach " + itemName, akActor, None)
        endif
    else
        SkyrimNetApi.RegisterEvent("item_not_found", akActor.GetDisplayName() + " couldn't find that item", akActor, None)
    endif
EndFunction

; =============================================================================
; LOOT PROCESSING - Handles "all", "valuables", or comma-separated item names
; =============================================================================

; Process a loot list string and transfer items from source to actor
; Supports: "all", "valuables", "gold", or comma-separated item names
; Returns: Number of item stacks transferred
int Function ProcessLootList(Actor akActor, ObjectReference akSource, String itemsToTake)
    if !akActor || !akSource
        return 0
    endif

    ; Reset loot tracking
    LastLootedItems = ""

    ; Cap items processed to prevent long stalls
    int MAX_ITEMS = 30

    ; Normalize the input
    String lootRequest = ToLowerCase(itemsToTake)
    int totalTaken = 0

    ; Handle "all" - take everything
    ; Uses RemoveAllItems for reliable transfer (handles leveled lists that
    ; GetNthForm can't resolve until the player opens the container)
    if lootRequest == "all" || lootRequest == "everything"
        int numItems = akSource.GetNumItems()
        Debug.Trace("[SeverActions_Loot] ProcessLootList ALL: source has " + numItems + " item stacks")

        ; Snapshot item descriptions before transfer (best-effort for event text)
        int cap = numItems
        if cap > MAX_ITEMS
            cap = MAX_ITEMS
        endif
        Form lastForm = None
        int lastCount = 0
        int i = 0
        while i < cap
            Form itemForm = akSource.GetNthForm(i)
            if itemForm
                int count = akSource.GetItemCount(itemForm)
                if count > 0
                    String itemName = itemForm.GetName()
                    if itemName != ""
                        totalTaken += 1
                        AddToLootedItemsList(itemName, count)
                        lastForm = itemForm
                        lastCount = count
                    endif
                endif
            endif
            i += 1
        endwhile

        ; Transfer everything in one native call (resolves leveled items properly)
        akSource.RemoveAllItems(akActor, false, true)

        ; Track last item for prompt reference
        if lastForm
            TrackLootedItem(akActor, lastForm, lastCount)
        endif

        ; Verify source is empty
        int remaining = akSource.GetNumItems()
        if remaining > 0
            Debug.Trace("[SeverActions_Loot] WARNING: " + remaining + " items remain after RemoveAllItems (quest items or engine lock)")
        else
            Debug.Trace("[SeverActions_Loot] ProcessLootList ALL: transfer complete, " + totalTaken + " stacks reported")
        endif
        return totalTaken
    endif

    ; Handle "valuables" - take items worth 50+ gold
    ; Iterate backwards so RemoveItem doesn't shift indices we haven't visited
    if lootRequest == "valuables" || lootRequest == "valuable"
        int numItems = akSource.GetNumItems()
        Debug.Trace("[SeverActions_Loot] ProcessLootList VALUABLES: source has " + numItems + " item stacks")
        int startIdx = numItems - 1
        if startIdx >= MAX_ITEMS
            startIdx = MAX_ITEMS - 1
        endif
        int failedRemovals = 0
        int i = startIdx
        while i >= 0
            Form itemForm = akSource.GetNthForm(i)
            if itemForm
                int value = GetFormValue(itemForm)
                if value >= 50
                    int count = akSource.GetItemCount(itemForm)
                    if count > 0
                        Debug.Trace("[SeverActions_Loot]   Removing: " + itemForm.GetName() + " x" + count + " (value " + value + ")")
                        akSource.RemoveItem(itemForm, count, true, akActor)
                        ; Verify removal actually worked
                        int remaining = akSource.GetItemCount(itemForm)
                        if remaining < count
                            totalTaken += 1
                            int actuallyMoved = count - remaining
                            TrackLootedItem(akActor, itemForm, actuallyMoved)
                            AddToLootedItemsList(itemForm.GetName(), actuallyMoved)
                        else
                            Debug.Trace("[SeverActions_Loot]   WARNING: RemoveItem failed for " + itemForm.GetName() + " (still " + remaining + " in source) - likely unresolved leveled item")
                            failedRemovals += 1
                        endif
                    endif
                endif
            endif
            i -= 1
        endwhile
        ; If all individual removals failed, fall back to RemoveAllItems then return non-valuables
        if totalTaken == 0 && failedRemovals > 0
            Debug.Trace("[SeverActions_Loot] All RemoveItem calls failed - falling back to RemoveAllItems")
            akSource.RemoveAllItems(akActor, false, true)
            totalTaken = failedRemovals
        endif
        return totalTaken
    endif
    
    ; Handle "gold" specifically
    if lootRequest == "gold" || lootRequest == "septims" || lootRequest == "money"
        Form goldForm = Game.GetFormFromFile(0x0000000F, "Skyrim.esm") as Form
        if goldForm
            int goldCount = akSource.GetItemCount(goldForm)
            if goldCount > 0
                Debug.Trace("[SeverActions_Loot] ProcessLootList GOLD: removing " + goldCount + " gold")
                akSource.RemoveItem(goldForm, goldCount, true, akActor)
                ; Verify
                int remaining = akSource.GetItemCount(goldForm)
                if remaining < goldCount
                    int actuallyMoved = goldCount - remaining
                    totalTaken += 1
                    TrackLootedItem(akActor, goldForm, actuallyMoved)
                    AddToLootedItemsList("Gold", actuallyMoved)
                else
                    Debug.Trace("[SeverActions_Loot] WARNING: Gold removal failed (still " + remaining + " in source)")
                endif
            endif
        endif
        return totalTaken
    endif

    ; Handle comma-separated list of item names
    ; Split by comma and search for each item
    Debug.Trace("[SeverActions_Loot] ProcessLootList SPECIFIC: '" + lootRequest + "'")
    int startPos = 0
    int commaPos = StringUtil.Find(lootRequest, ",", startPos)

    while startPos < StringUtil.GetLength(lootRequest)
        String itemName = ""

        if commaPos >= 0
            itemName = StringUtil.Substring(lootRequest, startPos, commaPos - startPos)
            startPos = commaPos + 1
            commaPos = StringUtil.Find(lootRequest, ",", startPos)
        else
            itemName = StringUtil.Substring(lootRequest, startPos)
            startPos = StringUtil.GetLength(lootRequest)
        endif

        ; Trim whitespace (basic)
        itemName = TrimString(itemName)

        if itemName != ""
            ; Find and take the item
            Form itemForm = FindItemInContainer(akSource, itemName)
            if itemForm
                int count = akSource.GetItemCount(itemForm)
                if count > 0
                    Debug.Trace("[SeverActions_Loot]   Removing: " + itemForm.GetName() + " x" + count)
                    akSource.RemoveItem(itemForm, count, true, akActor)
                    ; Verify removal actually worked
                    int remaining = akSource.GetItemCount(itemForm)
                    if remaining < count
                        int actuallyMoved = count - remaining
                        totalTaken += 1
                        TrackLootedItem(akActor, itemForm, actuallyMoved)
                        AddToLootedItemsList(itemForm.GetName(), actuallyMoved)
                    else
                        Debug.Trace("[SeverActions_Loot]   WARNING: RemoveItem failed for " + itemForm.GetName() + " (still " + remaining + " in source) - likely unresolved leveled item")
                    endif
                endif
            else
                Debug.Trace("[SeverActions_Loot]   Item not found in container: '" + itemName + "'")
            endif
        endif
    endwhile

    return totalTaken
EndFunction

; Trim leading/trailing spaces from a string
String Function TrimString(String text) Global
    ; Native implementation: ~2000x faster
    return SeverActionsNative.TrimString(text)
EndFunction

; Add to the human-readable list of looted items
Function AddToLootedItemsList(String itemName, int count)
    String entry = ""
    if count > 1
        entry = itemName + " x" + count
    else
        entry = itemName
    endif
    
    if LastLootedItems == ""
        LastLootedItems = entry
    else
        LastLootedItems = LastLootedItems + ", " + entry
    endif
EndFunction

; Track looted items in StorageUtil for later reference
Function TrackLootedItem(Actor akActor, Form akItem, int count)
    if !akActor || !akItem
        return
    endif
    
    ; Store recent loot for potential reference by prompts
    String storageKey = "SeverLoot_RecentItem"
    StorageUtil.SetFormValue(akActor, storageKey, akItem)
    StorageUtil.SetIntValue(akActor, storageKey + "_Count", count)
    StorageUtil.SetFloatValue(akActor, storageKey + "_Time", Utility.GetCurrentGameTime())
EndFunction

; =============================================================================
; VALUE HELPERS
; =============================================================================

int Function GetFormValue(Form akForm) Global
    ; Native implementation: handles all form types in one call, ~100x faster
    return SeverActionsNative.GetFormGoldValue(akForm)
EndFunction

; =============================================================================
; OBJECT FINDING HELPERS
; =============================================================================

ObjectReference Function FindNearbyContainer(Actor akActor, String containerType) Global
{Find a nearby container by type name. Used as fallback or for generic container searching.}
    ObjectReference[] containers = PO3_SKSEFunctions.FindAllReferencesOfFormType(akActor, 28, 1000.0)
    if !containers
        return None
    endif
    
    int i = 0
    while i < containers.Length
        ObjectReference ref = containers[i]
        if ref && !ref.IsDisabled() && ref.GetNumItems() > 0
            if containerType == "" || containerType == "any"
                return ref
            elseif StringUtil.Find(ToLowerCase(ref.GetBaseObject().GetName()), ToLowerCase(containerType)) >= 0
                return ref
            endif
        endif
        i += 1
    endwhile
    return None
EndFunction

ObjectReference Function FindNearbyItemOfType(Actor akActor, String itemType) Global
    ; Search in priority order: Weapons > Armor > Potions > Books > Ingredients > Scrolls > Ammo > Keys > SoulGems > Misc
    ObjectReference found = CheckFormType(akActor, 26, itemType) ; Weapons
    if found
        return found
    endif
    
    found = CheckFormType(akActor, 41, itemType) ; Armor
    if found
        return found
    endif
    
    found = CheckFormType(akActor, 46, itemType) ; Potions
    if found
        return found
    endif
    
    found = CheckFormType(akActor, 27, itemType) ; Books
    if found
        return found
    endif
    
    found = CheckFormType(akActor, 30, itemType) ; Ingredients
    if found
        return found
    endif
    
    found = CheckFormType(akActor, 23, itemType) ; Scrolls
    if found
        return found
    endif
    
    found = CheckFormType(akActor, 42, itemType) ; Ammo
    if found
        return found
    endif
    
    found = CheckFormType(akActor, 45, itemType) ; Keys
    if found
        return found
    endif
    
    found = CheckFormType(akActor, 52, itemType) ; SoulGems
    if found
        return found
    endif
    
    found = CheckFormType(akActor, 32, itemType) ; Misc
    if found
        return found
    endif

    found = CheckFormType(akActor, 38, itemType) ; Trees (many harvestable plants use this type)
    if found
        return found
    endif

    found = CheckFormType(akActor, 39, itemType) ; Flora (flowers, plants, etc.)
    if found
        return found
    endif

    found = CheckFormType(akActor, 24, itemType) ; Activators (some harvestable plants use this)
    return found
EndFunction

ObjectReference Function CheckFormType(Actor akActor, int typeID, String itemType) Global
    ObjectReference[] refs = PO3_SKSEFunctions.FindAllReferencesOfFormType(akActor, typeID, 1000.0)
    if !refs
        Debug.Trace("[SeverActions_Loot] CheckFormType: No refs found for type " + typeID + " searching for '" + itemType + "'")
        return None
    endif

    Debug.Trace("[SeverActions_Loot] CheckFormType: Found " + refs.Length + " refs for type " + typeID + " searching for '" + itemType + "'")

    String itemTypeLower = ToLowerCase(itemType)

    int i = 0
    while i < refs.Length
        ObjectReference ref = refs[i]
        if ref && !ref.IsDisabled() && ref.Is3DLoaded()
            String name = ref.GetBaseObject().GetName()
            if name != ""
                ; Check if item name contains the search term
                if StringUtil.Find(ToLowerCase(name), itemTypeLower) >= 0
                    Debug.Trace("[SeverActions_Loot] CheckFormType: MATCH '" + name + "' for type " + typeID)
                    return ref
                endif
            endif
        endif
        i += 1
    endwhile
    return None
EndFunction

; =============================================================================
; INVENTORY HELPERS
; =============================================================================

Bool Function ActorHasItemByName(Actor akActor, String itemName) Global
    Form f = GetItemFormByName(akActor, itemName)
    return f != None && akActor.GetItemCount(f) > 0
EndFunction

Form Function GetItemFormByName(Actor akActor, String itemName) Global
    ; Native implementation: O(1) hash lookup vs O(n) loop, ~100-200x faster
    return SeverActionsNative.FindItemByName(akActor, itemName)
EndFunction

Int Function TransferItemByName(Actor akFrom, Actor akTo, String itemName, Int aiCount = 1) Global
    Form f = GetItemFormByName(akFrom, itemName)
    if f
        Int available = akFrom.GetItemCount(f)
        Int toTransfer = aiCount
        if toTransfer > available
            toTransfer = available
        endif
        if toTransfer > 0
            akFrom.RemoveItem(f, toTransfer, true, akTo)
            return toTransfer
        endif
    endif
    return 0
EndFunction

; =============================================================================
; MERCHANT CHEST HELPERS
; =============================================================================

ObjectReference Function GetMerchantContainer(Actor akMerchant) Global
{Find the merchant chest for this actor by checking their vendor factions.
Falls back to actor's own inventory for NPCs without vendor containers.}
    
    if !akMerchant
        return None
    endif
    
    String merchantName = akMerchant.GetDisplayName()
    Debug.Trace("[SeverActions_Loot] GetMerchantContainer: Checking " + merchantName)
    
    ; Get all factions the actor belongs to
    Faction[] factions = akMerchant.GetFactions(-128, 127)
    if !factions || factions.Length == 0
        Debug.Trace("[SeverActions_Loot] GetMerchantContainer: No factions found for " + merchantName + ", using actor inventory")
        return akMerchant
    endif
    
    Debug.Trace("[SeverActions_Loot] GetMerchantContainer: Found " + factions.Length + " factions for " + merchantName)
    
    ; Check each faction for a vendor container
    Int i = 0
    ObjectReference vendorChest = None
    while i < factions.Length
        Faction f = factions[i]
        if f
            ; Try SKSE's native Faction.GetMerchantContainer() first
            vendorChest = f.GetMerchantContainer()
            if vendorChest
                Debug.Trace("[SeverActions_Loot] GetMerchantContainer: Found vendor chest via SKSE Faction.GetMerchantContainer() for " + merchantName)
                return vendorChest
            endif
            
            ; Fallback to PO3 function
            vendorChest = PO3_SKSEFunctions.GetVendorFactionContainer(f)
            if vendorChest
                Debug.Trace("[SeverActions_Loot] GetMerchantContainer: Found vendor chest via PO3 for " + merchantName)
                return vendorChest
            endif
        endif
        i += 1
    endwhile
    
    ; No vendor container found - fall back to actor's own inventory
    Debug.Trace("[SeverActions_Loot] GetMerchantContainer: No vendor chest found for " + merchantName + " after checking " + factions.Length + " factions, using actor inventory")
    return akMerchant
EndFunction

Form Function FindItemInContainer(ObjectReference akContainer, String itemName) Global
{Find an item by name in a container's inventory.}
    ; Native implementation: O(1) hash lookup vs O(n) loop, ~100-200x faster
    return SeverActionsNative.FindItemInContainer(akContainer, itemName)
EndFunction

Form Function FindItemInMerchantStock(Actor akMerchant, String itemName) Global
{Find an item in merchant's personal inventory OR their merchant chest.}
    if !akMerchant || itemName == ""
        return None
    endif
    
    ; Check personal inventory first
    Form personalItem = GetItemFormByName(akMerchant, itemName)
    if personalItem && akMerchant.GetItemCount(personalItem) > 0
        return personalItem
    endif
    
    ; Check merchant chest
    ObjectReference merchantChest = GetMerchantContainer(akMerchant)
    if merchantChest && merchantChest != akMerchant
        return FindItemInContainer(merchantChest, itemName)
    endif
    
    return None
EndFunction

Bool Function MerchantHasItem(Actor akMerchant, String itemName) Global
{Check if merchant has item in personal inventory or merchant chest.}
    return FindItemInMerchantStock(akMerchant, itemName) != None
EndFunction

; =============================================================================
; ACTION: UseItem - NPC uses/consumes an item from their inventory
; Supports: Potions, Food, Ingredients, and other consumables
; Also checks merchant chest if NPC is a merchant
; =============================================================================

Bool Function UseItem_IsEligible(Actor akActor, String itemName) Global
    if !akActor || akActor.IsDead() || itemName == ""
        return false
    endif
    
    ; Find the item in personal inventory or merchant stock
    Form itemForm = FindItemInMerchantStock(akActor, itemName)
    if !itemForm
        return false
    endif
    
    ; Check if it's a consumable type
    if !IsConsumable(itemForm)
        return false
    endif
    
    return true
EndFunction

Function UseItem_Execute(Actor akActor, String itemName)
    if !akActor || itemName == ""
        return
    endif
    
    ; Try personal inventory first
    Form itemForm = GetItemFormByName(akActor, itemName)
    Bool fromMerchantChest = false
    ObjectReference merchantChest = None
    
    if !itemForm || akActor.GetItemCount(itemForm) <= 0
        ; Check merchant chest
        merchantChest = GetMerchantContainer(akActor)
        if merchantChest && merchantChest != akActor
            itemForm = FindItemInContainer(merchantChest, itemName)
            if itemForm && merchantChest.GetItemCount(itemForm) > 0
                fromMerchantChest = true
                ; Move item to actor's inventory so they can consume it
                merchantChest.RemoveItem(itemForm, 1, true, akActor)
            else
                Debug.Trace("[SeverActions_Loot] UseItem: Could not find item '" + itemName + "' in merchant stock")
                return
            endif
        else
            Debug.Trace("[SeverActions_Loot] UseItem: Could not find item '" + itemName + "' in " + akActor.GetDisplayName() + "'s inventory")
            return
        endif
    endif
    
    ; Verify they have it now
    if akActor.GetItemCount(itemForm) <= 0
        Debug.Trace("[SeverActions_Loot] UseItem: " + akActor.GetDisplayName() + " doesn't have " + itemName)
        return
    endif
    
    String actualItemName = itemForm.GetName()
    Debug.Trace("[SeverActions_Loot] UseItem: " + akActor.GetDisplayName() + " consuming " + actualItemName)
    
    ; Determine item type and use appropriately
    Potion potionForm = itemForm as Potion
    Ingredient ingredientForm = itemForm as Ingredient
    
    if potionForm
        ; Play appropriate animation
        if potionForm.IsFood()
            PlayConsumeAnimation(akActor, true, itemForm)  ; true = food
        else
            PlayConsumeAnimation(akActor, false, itemForm) ; false = potion/drink
        endif
        
        ; Actually consume the potion (applies effects and removes from inventory)
        akActor.EquipItem(potionForm, false, true)
        
        ; Register event based on potion type
        if potionForm.IsFood()
            ; Track when this actor last ate for hunger system
            StorageUtil.SetFloatValue(akActor, "SkyrimNet_LastAteTime", Utility.GetCurrentGameTime() * 24 * 3631)
            ; Also notify the Survival system so hunger is reduced
            If SurvivalScript
                SurvivalScript.OnFollowerAteFood(akActor, itemForm)
            EndIf
            SkyrimNetApi.RegisterEvent("item_consumed", akActor.GetDisplayName() + " ate " + actualItemName, akActor, None)
        elseif potionForm.IsPoison()
            ; Poison - they drank poison (intentionally or not)
            SkyrimNetApi.RegisterEvent("item_consumed", akActor.GetDisplayName() + " drank " + actualItemName + " (poison!)", akActor, None)
        else
            ; Regular potion/drink — still sates hunger slightly (liquid is liquid)
            If SurvivalScript
                SurvivalScript.OnFollowerDrank(akActor, itemForm)
            EndIf
            SkyrimNetApi.RegisterEvent("item_consumed", akActor.GetDisplayName() + " drank " + actualItemName, akActor, None)
        endif
        
    elseif ingredientForm
        ; Eating a raw ingredient
        PlayConsumeAnimation(akActor, true, itemForm) ; food animation
        
        ; EquipItem on ingredients makes the actor eat it (learns first effect)
        akActor.EquipItem(ingredientForm, false, true)

        ; Track when this actor last ate for hunger system (raw ingredients count as food)
        StorageUtil.SetFloatValue(akActor, "SkyrimNet_LastAteTime", Utility.GetCurrentGameTime() * 24 * 3631)
        ; Also notify the Survival system so hunger is reduced (ingredients restore less)
        If SurvivalScript
            SurvivalScript.OnFollowerAteFood(akActor, itemForm)
        EndIf
        SkyrimNetApi.RegisterEvent("item_consumed", akActor.GetDisplayName() + " ate raw " + actualItemName, akActor, None)
    else
        ; Unknown consumable type - try to equip it anyway
        Debug.Trace("[SeverActions_Loot] UseItem: Unknown consumable type for " + actualItemName + ", attempting EquipItem")
        akActor.EquipItem(itemForm, false, true)
        SkyrimNetApi.RegisterEvent("item_consumed", akActor.GetDisplayName() + " used " + actualItemName, akActor, None)
    endif
    
    ResetToDefaultIdle(akActor)
EndFunction

; Check if a form is a consumable item
Bool Function IsConsumable(Form akForm) Global
    ; Native implementation: faster type checking
    return SeverActionsNative.IsConsumable(akForm)
EndFunction

; Play the appropriate consume animation
; Uses TaberuAnimation (Eating Animations and Sounds) if installed, otherwise fallback to basic idles
Function PlayConsumeAnimation(Actor akActor, Bool isFood, Form itemForm = None)
    if !akActor
        return
    endif
    
    ; Reset to default state first
    if IdleForceDefaultState
        akActor.PlayIdle(IdleForceDefaultState)
        Utility.Wait(0.2)
    endif
    
    ; Try to use TaberuAnimation (Eating Animations and Sounds) if installed and we have the item form
    if itemForm && SeverActions_EatingAnimations.IsInstalled()
        if SeverActions_EatingAnimations.PlayEatingAnimation(akActor, itemForm)
            ; Animation spell was cast, wait for it to play
            ; The spell handles its own cleanup via OnEffectFinish
            float duration = SeverActions_EatingAnimations.GetAnimationDuration(itemForm)
            Utility.Wait(duration)
            return
        endif
    endif
    
    ; Fallback to basic animations if TaberuAnimation not installed or no matching animation
    if isFood && IdleEatSoup
        akActor.PlayIdle(IdleEatSoup)
        Utility.Wait(2.0)
    elseif !isFood && IdleDrinkPotion
        akActor.PlayIdle(IdleDrinkPotion)
        Utility.Wait(1.5)
    else
        ; Fallback - just wait a moment
        Utility.Wait(0.5)
    endif
EndFunction

; =============================================================================
; ACTION: ReadBook - NPC reads a book aloud from their inventory
; Extracts full book text via native DLL and sends to LLM for reading
; =============================================================================

Bool Function ReadBook_IsEligible(Actor akActor, String bookName)
{Check if actor can read a book by name from their inventory.
Returns false if someone is already reading (prevents re-triggering).}
    if !akActor || akActor.IsDead() || akActor.IsInCombat()
        return false
    endif

    ; Block if a reading session is already active
    if BookReader != None
        ; Check for timeout — auto-clear stale state
        if BookReadingStartTime > 0.0
            Float elapsed = Utility.GetCurrentRealTime() - BookReadingStartTime
            if elapsed > BookReadingTimeout
                Debug.Trace("[SeverActions_Loot] ReadBook: Timeout reached, clearing stale reading state")
                ClearBookReadingState()
            else
                return false
            endif
        else
            return false
        endif
    endif

    if bookName == ""
        ; No specific book requested — check if they have any books
        return SeverActionsNative.HasBooks(akActor)
    endif

    ; Check if the named book is in their inventory
    Form bookForm = SeverActionsNative.FindBookInInventory(akActor, bookName)
    return bookForm != None
EndFunction

Function ReadBook_Execute(Actor akActor, String bookName)
{NPC prepares to read a book from their inventory.
Sets up book reading mode — the NPC's next dialogue responses will contain the book text,
guided by the book reading prompt. No DirectNarration is used so the NPC can respond
naturally first (e.g. "What shall I read?") and the player drives the conversation.}
    if !akActor || akActor.IsDead()
        return
    endif

    ; If already reading, ignore — the prompt is already active and driving the conversation
    if BookReader != None
        Debug.Trace("[SeverActions_Loot] ReadBook: Already in reading mode, ignoring duplicate execute")
        return
    endif

    ; Find the book in inventory
    Form bookForm = None
    if bookName != ""
        bookForm = SeverActionsNative.FindBookInInventory(akActor, bookName)
    endif

    if !bookForm
        ; No book found by that name
        String npcName = akActor.GetDisplayName()
        if bookName != ""
            SkyrimNetApi.RegisterEvent("book_not_found", npcName + " looked for '" + bookName + "' but doesn't have it", akActor, None)
        else
            SkyrimNetApi.RegisterEvent("book_not_found", npcName + " has no books to read", akActor, None)
        endif
        return
    endif

    String actualBookName = bookForm.GetName()
    String npcName = akActor.GetDisplayName()

    ; Extract the full text from the book
    String bookText = SeverActionsNative.GetBookText(bookForm)

    if bookText == ""
        SkyrimNetApi.RegisterEvent("book_empty", npcName + " opened " + actualBookName + " but found it blank or unreadable", akActor, None)
        return
    endif

    Debug.Trace("[SeverActions_Loot] ReadBook: " + npcName + " reading '" + actualBookName + "' (" + StringUtil.GetLength(bookText) + " chars)")

    ; Set book reading state — script properties for internal guards
    BookReader = akActor
    BookReadingTitle = actualBookName
    BookReadingText = bookText
    BookReadingStartTime = Utility.GetCurrentRealTime()

    ; Store in StorageUtil — papyrus_util reads these natively, available immediately
    ; The prompt will detect this on the NPC's next dialogue response
    StorageUtil.SetIntValue(akActor, "SeverActions_ReadingBook", 1)
    StorageUtil.SetStringValue(akActor, "SeverActions_ReadingBookTitle", actualBookName)
    StorageUtil.SetStringValue(akActor, "SeverActions_ReadingBookText", bookText)

    ; Play book reading animation
    Bool isSitting = akActor.GetSitState() >= 2  ; 2 = wanting to sit, 3 = sitting
    if isSitting && IdleBook_ReadingSitting
        akActor.PlayIdle(IdleBook_ReadingSitting)
    elseif IdleBook_Reading
        if IdleForceDefaultState
            akActor.PlayIdle(IdleForceDefaultState)
            Utility.Wait(0.2)
        endif
        akActor.PlayIdle(IdleBook_Reading)
    endif

    ; Single narration: NPC opens the book — worded to prevent LLM from reading ahead
    ; The auto-continue loop will nudge them to start and keep reading once the prompt has the book text
    String openNarration = "*" + npcName + " pulls out '" + actualBookName + "' and begins searching for the right page. They haven't started reading yet — do not read or recite any of the book's contents until the full text is available.*"
    SkyrimNetApi.DirectNarration(openNarration, akActor, None)

    ; Persistent event for long-term context
    SkyrimNetApi.RegisterPersistentEvent(npcName + " is reading '" + actualBookName + "' aloud.", akActor, None)

    ; Start auto-continue loop — monitors speech queue and nudges NPC to keep reading
    BookReadingLastNarrationTime = Utility.GetCurrentRealTime()
    RegisterForSingleUpdate(BookReadingUpdateInterval)
EndFunction

Function ClearBookReadingState()
{Clear all book reading state. Call when reading finishes or times out.}
    if BookReader != None
        Debug.Trace("[SeverActions_Loot] ReadBook: Clearing reading state for " + BookReader.GetDisplayName())
        ; Clear StorageUtil entries
        StorageUtil.UnsetIntValue(BookReader, "SeverActions_ReadingBook")
        StorageUtil.UnsetStringValue(BookReader, "SeverActions_ReadingBookTitle")
        StorageUtil.UnsetStringValue(BookReader, "SeverActions_ReadingBookText")
        ; Reset animation
        ResetToDefaultIdle(BookReader)
    endif
    BookReader = None
    BookReadingTitle = ""
    BookReadingText = ""
    BookReadingStartTime = 0.0
    BookReadingLastNarrationTime = 0.0
EndFunction

Function StopReading_Execute(Actor akActor)
{Stop the current book reading session. Can be called by the NPC or externally.}
    if BookReader == None
        return
    endif
    String npcName = BookReader.GetDisplayName()
    ClearBookReadingState()
    SkyrimNetApi.RegisterEvent("book_reading_stopped", npcName + " stopped reading", akActor, None)
EndFunction

; =============================================================================
; BOOK READING AUTO-CONTINUE LOOP
; =============================================================================

Event OnUpdate()
    ; Only active during book reading — monitors speech queue and nudges NPC to keep reading
    if BookReader == None
        return
    endif

    ; Check timeout
    Float totalElapsed = Utility.GetCurrentRealTime() - BookReadingStartTime
    if totalElapsed > BookReadingTimeout
        Debug.Trace("[SeverActions_Loot] ReadBook: Auto-continue timeout reached, stopping")
        String npcName = BookReader.GetDisplayName()
        ClearBookReadingState()
        SkyrimNetApi.RegisterEvent("book_reading_stopped", npcName + " finished reading", BookReader, None)
        return
    endif

    ; Check if speech queue is empty (NPC has stopped talking)
    Int queueSize = SkyrimNetApi.GetSpeechQueueSize()
    Float timeSinceLastNarration = Utility.GetCurrentRealTime() - BookReadingLastNarrationTime

    if queueSize == 0 && timeSinceLastNarration >= BookReadingContinueDelay
        ; NPC has been silent long enough — nudge them to continue reading
        String npcName = BookReader.GetDisplayName()
        String narration = "*" + npcName + " continues reading aloud.*"
        SkyrimNetApi.DirectNarration(narration, BookReader, None)
        BookReadingLastNarrationTime = Utility.GetCurrentRealTime()
        Debug.Trace("[SeverActions_Loot] ReadBook: Auto-continue triggered for " + npcName)
    endif

    ; Keep looping while reading is active
    RegisterForSingleUpdate(BookReadingUpdateInterval)
EndEvent

; =============================================================================
; ANIMATION HELPERS (Non-Global to access properties)
; =============================================================================

Function PlayAnimationAndWait(Actor akActor, Idle akIdle, float waitTime = 2.0)
    if !akActor || !akIdle
        return
    endif
    if IdleForceDefaultState
        akActor.PlayIdle(IdleForceDefaultState)
        Utility.Wait(0.2)
    endif
    akActor.PlayIdle(akIdle)
    Utility.Wait(waitTime)
EndFunction

Function ResetToDefaultIdle(Actor akActor)
    if !akActor
        return
    endif
    if IdleForceDefaultState
        akActor.PlayIdle(IdleForceDefaultState)
    endif
EndFunction
