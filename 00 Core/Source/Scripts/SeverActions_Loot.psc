Scriptname SeverActions_Loot extends Quest
{Item pickup, delivery, and looting action handlers for SkyrimNet integration - by Severause
Also supports merchant chest access for GiveItem/UseItem actions.}

; =============================================================================
; CONSTANTS
; =============================================================================

float Property INTERACTION_DISTANCE = 150.0 AutoReadOnly

; =============================================================================
; BOOK READING STATE - Tracks active book reading for prompt integration
; Source of truth for title/text is per-actor StorageUtil — read by prompts
; via papyrus_util. Storing them as quest properties (Auto Hidden) bloated
; the cosave on every save (book text can run tens of KB).
; =============================================================================

Actor Property BookReader Auto Hidden
{The NPC currently reading a book aloud. None if nobody is reading.}

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

Int Property BookReadMode = 0 Auto Hidden
{0 = Read Aloud (Verbatim), 1 = Summarize and React}

; =============================================================================
; ANIMATION PROPERTIES
; =============================================================================

Idle Property IdleGive Auto
Idle Property IdleTake Auto
Idle Property IdlePickUpItem Auto
Idle Property IdleSearchingChest Auto
Idle Property IdleLootBody Auto
Idle Property IdleForceDefaultState Auto

; Consume animations
Idle Property IdleDrinkPotion Auto
Idle Property IdleEatSoup Auto

; Book/note reading animations
Idle Property IdleBook_Reading Auto
Idle Property IdleBook_ReadingSitting Auto
Idle Property IdleNoteRead Auto

; =============================================================================
; SCRIPT REFERENCES
; =============================================================================

SeverActions_Survival Property SurvivalScript Auto

; =============================================================================
; DIARY VIEWER INITIALIZATION
; =============================================================================

Function InitializeDiaryEvents()
{Register for the diary entry selection ModEvent. Called by Init on each game load.}
    RegisterForModEvent("SeverActions_DiaryEntrySelected", "OnDiaryEntrySelected")
    Debug.Trace("[SeverActions_Loot] Registered for diary selection events")
EndFunction

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

    Bool usingPackage = GoToRefPackage && TargetRefAlias
    if usingPackage
        TargetRefAlias.ForceRefTo(akTarget)
        ActorUtil.AddPackageOverride(akActor, GoToRefPackage, 100)
        akActor.EvaluatePackage()
    else
        akActor.PathToReference(akTarget, 1.0)
    endif

    ; Arrival detection: prefer the native ArrivalMonitor scan loop over
    ; per-iteration Papyrus GetDistance. Polling Arrival_IsTracked is cheap
    ; (one map lookup) — the actual XY distance math runs once per ~1s native
    ; tick across ALL tracked actors, regardless of how many flows are walking
    ; concurrently. Compared to the old loop (60 GetDistance calls per walker
    ; over 15s), this scales sub-linearly with concurrent NPCs.
    ;
    ; Fallback: if the actor is already being tracked by another system
    ; (arrest approach/escort), do NOT take it over — ArrivalMonitor is
    ; one-actor-one-entry. Use the legacy GetDistance poll instead.
    Bool useArrivalMonitor = !SeverActionsNativeExt.Arrival_IsTracked(akActor)
    if useArrivalMonitor
        SeverActionsNativeExt.Arrival_Register(akActor, akTarget, INTERACTION_DISTANCE, "sever_loot_walk")
        float elapsed = 0.0
        while SeverActionsNativeExt.Arrival_IsTracked(akActor) && elapsed < maxWaitTime
            Utility.Wait(0.25)
            elapsed += 0.25
        endwhile
        ; Defensive cancel if we timed out — also handles the "actor died
        ; mid-walk, monitor auto-cancelled" case where IsTracked is false
        ; but they didn't actually arrive.
        if SeverActionsNativeExt.Arrival_IsTracked(akActor)
            SeverActionsNativeExt.Arrival_Cancel(akActor)
        endif
    else
        float elapsed = 0.0
        while akActor.GetDistance(akTarget) > INTERACTION_DISTANCE && elapsed < maxWaitTime
            Utility.Wait(0.25)
            elapsed += 0.25
        endwhile
    endif

    if usingPackage
        ActorUtil.RemovePackageOverride(akActor, GoToRefPackage)
        akActor.EvaluatePackage()
        TargetRefAlias.Clear()
    endif

    ; Final distance check is the source of truth. ArrivalMonitor removes
    ; the entry on arrival OR on actor-death auto-cancel; only the position
    ; check distinguishes those.
    return akActor.GetDistance(akTarget) <= INTERACTION_DISTANCE
EndFunction

; =============================================================================
; JSON HELPER FUNCTIONS
; =============================================================================

String Function EscapeJsonString(String text) Global
    ; Native implementation: ~2000x faster
    return SeverActionsNative.EscapeJsonString(text)
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

    return SeverActionsNative.FindNearbyItemOfType(akActor, itemType, 1000.0) != None
EndFunction

Function PickUpItem_Execute(Actor akActor, String itemType)
{Pick up a nearby item matching the given name/type.}
    if !akActor || itemType == ""
        return
    endif

    ObjectReference nearbyItem = SeverActionsNative.FindNearbyItemOfType(akActor, itemType, 1000.0)

    if nearbyItem
        Form itemBase = nearbyItem.GetBaseObject()
        String itemName = itemBase.GetName()

        if WalkToReference(akActor, nearbyItem)
            if IdlePickUpItem
                PlayAnimationAndWait(akActor, IdlePickUpItem, 1.5)
            endif
            ; Owned item → silent native pickup (NO vanilla theft alarm; this is
            ; the bug fix — Activate on owned goods was giving the player a
            ; vanilla bounty even for follower pickups). SA bounty if witnessed.
            ; Unowned → normal Activate (preserves extras, raises no crime).
            if SeverActionsNativeExt.IsRefOwnedByNonPlayer(nearbyItem)
                SeverActionsNativeExt.PickUpItemSilent(akActor, nearbyItem)
                ApplyTheftBounty(akActor, itemName)
            else
                nearbyItem.Activate(akActor)
            endif
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

    return SeverActionsNative.FindNearbyContainer(akActor, containerName, 1000.0) != None
EndFunction

Function LootContainer_Execute(Actor akActor, String containerName, String itemsToTake)
{Loot a nearby container by name. itemsToTake can be "all", "valuables", "gold", or comma-separated item names.}
    if !akActor || containerName == ""
        return
    endif

    ObjectReference akContainer = SeverActionsNative.FindNearbyContainer(akActor, containerName, 1000.0)
    if !akContainer
        SkyrimNetApi.RegisterEvent("container_not_found", akActor.GetDisplayName() + " couldn't find a " + containerName + " nearby", akActor, None)
        return
    endif

    String displayName = akContainer.GetBaseObject().GetName()

    ; Locked containers aren't free-looted — refuse and narrate so the smith/NPC
    ; reacts ("it's locked"). No lockpick mechanic; this just gates the take.
    if akContainer.IsLocked()
        SkyrimNetApi.RegisterEvent("container_locked", akActor.GetDisplayName() + " went for " + displayName + ", but it's locked.", akActor, None)
        return
    endif

    Debug.Trace("[SeverActions_Loot] " + akActor.GetDisplayName() + " looting container: " + displayName)
    LootRef_Helper(akActor, akContainer, IdleSearchingChest, 2.5, displayName, "container", "took", itemsToTake)
EndFunction

; =============================================================================
; ACTION: LootCorpse - Loot a dead actor by name
; =============================================================================

Bool Function LootCorpse_IsEligible(Actor akActor, String corpseName) Global
    if !akActor || akActor.IsDead() || akActor.IsInCombat() || corpseName == ""
        return false
    endif

    ; Prefer the nearest DEAD match so a live same-named actor doesn't shadow
    ; the corpse right beside the looter.
    Actor akCorpse = SeverActionsNativeExt.FindNearestDeadByName(akActor, corpseName, 4096.0)
    if !akCorpse || !akCorpse.IsDead()
        return false
    endif

    return akActor.GetDistance(akCorpse) < 4096.0 && akCorpse.GetNumItems() > 0
EndFunction

Function LootCorpse_Execute(Actor akActor, String corpseName, String itemsToTake)
    if !akActor || corpseName == ""
        return
    endif

    Actor akCorpse = SeverActionsNativeExt.FindNearestDeadByName(akActor, corpseName, 4096.0)
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

    String displayName = akCorpse.GetDisplayName()
    LootRef_Helper(akActor, akCorpse, IdleLootBody, 3.0, displayName, "corpse", "looted", itemsToTake)
EndFunction

; Shared body for LootContainer_Execute / LootCorpse_Execute: walk to target,
; play idle, hand off to native ProcessLoot, fire either a "<kind>_looted" or
; "<kind>_unreachable" event. The two callers only differ in animation, verb,
; and event prefix.
; Add a SeverActions TRACKED bounty for a witnessed theft recorded by the last
; ProcessLoot / PickUpItemSilent. Vanilla crime is never raised — owned-goods
; taking is silent at the engine level, so this is the only consequence, and
; only when seen. No-op if nothing was stolen, no witness, or no crime faction.
Function ApplyTheftBounty(Actor akActor, String displayName)
    if !akActor
        return
    endif
    Int stolenValue = SeverActionsNativeExt.GetLastStolenValue()
    if stolenValue <= 0
        return
    endif
    if !SeverActionsNativeExt.IsTheftWitnessed(akActor, 1500.0)
        return   ; unseen theft is free — the goods stay flagged stolen
    endif
    Faction crimeFaction = SeverActionsNativeExt.GetLastStolenCrimeFaction()
    if !crimeFaction
        return
    endif
    SeverActionsNativeExt.Native_Bounty_Mod(crimeFaction, stolenValue)
    SeverActionsNativeExt.Native_Bounty_AddEvent(crimeFaction, stolenValue, "theft", "")
    Debug.Notification("Bounty: +" + stolenValue + " gold (theft witnessed)")
    SkyrimNetApi.RegisterPersistentEvent(akActor.GetDisplayName() + " was seen taking owned goods from " + displayName + " — a " + stolenValue + " gold tracked bounty was added.", akActor, Game.GetPlayer())
EndFunction

Function LootRef_Helper(Actor akActor, ObjectReference akTarget, Idle anim, Float animDuration, String displayName, String kind, String verb, String itemsToTake)
    if !akActor || !akTarget
        return
    endif

    if WalkToReference(akActor, akTarget)
        if anim
            PlayAnimationAndWait(akActor, anim, animDuration)
        endif
        ; End the idle before processing loot (can take a while for many items).
        ResetToDefaultIdle(akActor)
        Utility.Wait(0.2)

        int itemsTaken = ProcessLootList(akActor, akTarget, itemsToTake)
        String desc = SeverActionsNative.GetLastLootDescription()

        if itemsTaken > 0 && desc != ""
            String suffix = ""
            if itemsTaken >= 30
                ; ProcessLoot caps at 30 stacks per call — flag that more may remain.
                suffix = " (as much as they could grab in one go)"
            endif
            SkyrimNetApi.RegisterEvent(kind + "_looted", akActor.GetDisplayName() + " " + verb + " " + desc + " from " + displayName + suffix, akActor, None)
            ; Witnessed theft of OWNED goods → SeverActions tracked bounty (the
            ; scripted RemoveItem above never triggered vanilla crime).
            ApplyTheftBounty(akActor, displayName)
        else
            ; Specific feedback when a named-item request wasn't in there.
            String nothingMsg = akActor.GetDisplayName() + " found nothing to take from " + displayName
            String mode = ToLowerCase(itemsToTake)
            if mode != "" && mode != "all" && mode != "everything" && mode != "valuables" && mode != "valuable" && mode != "gold" && mode != "septims" && mode != "money"
                nothingMsg = displayName + " had no " + itemsToTake + " for " + akActor.GetDisplayName() + " to take"
            endif
            SkyrimNetApi.RegisterEvent(kind + "_looted", nothingMsg, akActor, None)
        endif
    else
        SkyrimNetApi.RegisterEvent(kind + "_unreachable", akActor.GetDisplayName() + " couldn't reach " + displayName, akActor, None)
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
; TRANSACTION HELPERS (for BuyItem / SellItem in SeverActions_Currency)
;
; These mirror GiveItem_Execute but DELIBERATELY DIFFER on two counts:
;   1. No auto-debt-growth — the item is being paid for here and now, so it
;      must not silently grow any outstanding tab between the parties.
;   2. No "item_given" event — the encompassing transaction event built by
;      Currency.BuyItem_Execute / SellItem_Execute is the canonical record.
;
; Split into two so Currency can resolve the item once (for gold + event
; narration) and then issue the transfer.
; =============================================================================

Form Function ResolveItemForTransaction(Actor akSeller, String itemName) Global
    {Returns the Form for itemName in akSeller's inventory (personal first,
     then merchant chest fallback). Returns None when nothing matches.
     Pure lookup — no side effects, no actor mutation.}
    If !akSeller || itemName == ""
        Return None
    EndIf

    ; Personal inventory first.
    Form itemForm = GetItemFormByName(akSeller, itemName)
    If itemForm && akSeller.GetItemCount(itemForm) > 0
        Return itemForm
    EndIf

    ; Merchant chest fallback (mirrors GiveItem_Execute's logic).
    ObjectReference merchantChest = GetMerchantContainer(akSeller)
    If merchantChest && merchantChest != akSeller
        itemForm = FindItemInContainer(merchantChest, itemName)
        If itemForm && merchantChest.GetItemCount(itemForm) > 0
            Return itemForm
        EndIf
    EndIf

    Return None
EndFunction

Int Function GetTransactionAvailableQty(Actor akSeller, Form akItemForm) Global
    {Returns how many of akItemForm akSeller can actually sell — the max of
     their personal inventory count and (if applicable) the merchant chest
     count. Lets the caller fail early on insufficient-stock before any
     walk/animation work happens.}
    If !akSeller || !akItemForm
        Return 0
    EndIf
    Int personal = akSeller.GetItemCount(akItemForm)
    Int chest = 0
    ObjectReference merchantChest = GetMerchantContainer(akSeller)
    If merchantChest && merchantChest != akSeller
        chest = merchantChest.GetItemCount(akItemForm)
    EndIf
    If personal >= chest
        Return personal
    EndIf
    Return chest
EndFunction

Int Function TransferItemForTransaction(Actor akSeller, Actor akBuyer, Form akItemForm, Int aiCount = 1)
    {Atomic item transfer for a paid transaction. Walks the seller to the
     buyer, plays IdleGive, then moves up to aiCount of akItemForm from the
     seller's personal inventory OR merchant chest into the buyer's inventory.

     Returns the COUNT actually transferred (0 = nothing moved). Caller is
     responsible for the gold half and the transaction event.

     Does NOT call SeverActions_Debt.AutoAddToDebt — Buy/Sell transactions
     must not grow tabs (the item is paid for in the same breath). Does NOT
     fire item_given — Currency builds the unified item_purchased event.}

    If !akSeller || !akBuyer || !akItemForm || aiCount < 1
        Return 0
    EndIf

    If !WalkToReference(akSeller, akBuyer)
        Return 0
    EndIf

    If IdleGive
        PlayAnimationAndWait(akSeller, IdleGive, 2.0)
    EndIf

    ; PR #103 review fix: pick the source that has the most stock so the
    ; transfer count matches the GetTransactionAvailableQty pre-check
    ; (which returns MAX(personal, chest)). The legacy GiveItem_Execute
    ; pattern of "personal first if any" would silently undershoot when
    ; a merchant has e.g. 3 in their pocket and 5 in the chest.
    Int personal = akSeller.GetItemCount(akItemForm)
    Int chest = 0
    ObjectReference merchantChest = GetMerchantContainer(akSeller)
    If merchantChest && merchantChest != akSeller
        chest = merchantChest.GetItemCount(akItemForm)
    EndIf

    Int transferred = 0
    If personal >= chest && personal > 0
        Int toMove = aiCount
        If toMove > personal
            toMove = personal
        EndIf
        If toMove > 0
            akSeller.RemoveItem(akItemForm, toMove, false, akBuyer)
            transferred = toMove
        EndIf
    ElseIf chest > 0
        Int toMove = aiCount
        If toMove > chest
            toMove = chest
        EndIf
        If toMove > 0
            merchantChest.RemoveItem(akItemForm, toMove, false, akBuyer)
            transferred = toMove
        EndIf
    EndIf

    ResetToDefaultIdle(akSeller)
    Return transferred
EndFunction

; =============================================================================
; ACTION: TakeItem — speaker takes an item out of another actor's hands
;
; Generalised from the original TakeItemFromPlayer. The target can be the
; player OR any NPC (a quest-giver collecting payment, a merchant taking
; a turn-in, two NPCs exchanging tools). TakeItemFromPlayer_Execute lives
; on below as a thin wrapper so PrismaUI's existing call site keeps working.
; =============================================================================

Function TakeItem_Execute(Actor akSpeaker, Actor akTarget, String itemName, Int aiCount = 1)
{The speaker walks to the target, plays the take animation, and pulls an
 item out of the target's inventory. Also handles gold — LLMs often pick
 this for gold transfers when CollectPayment would be more semantically
 correct, so we route the gold path through the same Take-style animation
 + Debug.Notification when the target is the player.}
    if !akSpeaker || !akTarget || itemName == ""
        return
    endif
    if akSpeaker == akTarget
        return
    endif

    ; Ensure at least 1
    if aiCount < 1
        aiCount = 1
    endif

    Actor playerRef = Game.GetPlayer()
    Bool targetIsPlayer = (akTarget == playerRef)

    ; Check if the LLM is asking for gold (common aliases)
    if SeverActionsNative.IsGoldName(itemName)
        TakeGoldFrom(akSpeaker, akTarget, aiCount)
        return
    endif

    ; Find the item in the target's inventory
    Form itemForm = GetItemFormByName(akTarget, itemName)
    if !itemForm || akTarget.GetItemCount(itemForm) <= 0
        SkyrimNetApi.RegisterEvent("take_item_failed", akSpeaker.GetDisplayName() + " couldn't find " + itemName + " in " + akTarget.GetDisplayName() + "'s inventory", akSpeaker, akTarget)
        return
    endif

    String actualName = itemForm.GetName()

    ; Check if the resolved item is actually gold (catches any other gold name variants)
    MiscObject goldForm = Game.GetFormFromFile(0x0000000F, "Skyrim.esm") as MiscObject
    if goldForm && itemForm == goldForm as Form
        TakeGoldFrom(akSpeaker, akTarget, aiCount)
        return
    endif

    ; Walk to the target
    if WalkToReference(akSpeaker, akTarget)
        if IdleTake
            PlayAnimationAndWait(akSpeaker, IdleTake, 2.0)
        endif

        ; Transfer the item
        Int available = akTarget.GetItemCount(itemForm)
        Int transferred = aiCount
        if transferred > available
            transferred = available
        endif

        if transferred > 0
            ; abSilent — when the target is the player, the engine's normal
            ; "X was added/removed" toast is suppressed because we fire our
            ; own Debug.Notification below for clearer narration.
            akTarget.RemoveItem(itemForm, transferred, targetIsPlayer, akSpeaker)
        endif

        ResetToDefaultIdle(akSpeaker)

        ; Notify and register event. The player-target path retains the
        ; legacy "item_taken_from_player" event name + Debug.Notification
        ; so prompt templates and HUD behavior don't change for that case.
        String speakerName = akSpeaker.GetDisplayName()
        String targetName = akTarget.GetDisplayName()
        if transferred > 1
            if targetIsPlayer
                Debug.Notification(speakerName + " took " + actualName + " (" + transferred + ")")
                SkyrimNetApi.RegisterEvent("item_taken_from_player", speakerName + " took " + transferred + " " + actualName + " from the player", akSpeaker, akTarget)
            else
                SkyrimNetApi.RegisterEvent("item_taken", speakerName + " took " + transferred + " " + actualName + " from " + targetName, akSpeaker, akTarget)
            endif
        elseif transferred == 1
            if targetIsPlayer
                Debug.Notification(speakerName + " took " + actualName)
                SkyrimNetApi.RegisterEvent("item_taken_from_player", speakerName + " took " + actualName + " from the player", akSpeaker, akTarget)
            else
                SkyrimNetApi.RegisterEvent("item_taken", speakerName + " took " + actualName + " from " + targetName, akSpeaker, akTarget)
            endif
        else
            SkyrimNetApi.RegisterEvent("take_item_failed", speakerName + " couldn't take " + itemName + " from " + targetName, akSpeaker, akTarget)
        endif
    else
        SkyrimNetApi.RegisterEvent("take_item_failed", akSpeaker.GetDisplayName() + " couldn't reach " + akTarget.GetDisplayName() + " to take " + itemName, akSpeaker, akTarget)
    endif
EndFunction

Function TakeItemFromPlayer_Execute(Actor akActor, String itemName, Int aiCount = 1)
{Back-compat wrapper. The original action only took from the player; PR
 generalised it to TakeItem_Execute(speaker, target, ...). PrismaUI's
 existing call site (and any user-side prompts that still reference the
 old executionFunctionName) keep working via this passthrough.}
    TakeItem_Execute(akActor, Game.GetPlayer(), itemName, aiCount)
EndFunction

Function TakeGoldFrom(Actor akSpeaker, Actor akTarget, Int aiAmount)
{Helper: speaker takes gold from a target (any actor) with the take
 animation. The Debug.Notification + dedicated event name are kept on the
 player-target path for HUD/prompt parity with the legacy behavior.}
    MiscObject goldForm = Game.GetFormFromFile(0x0000000F, "Skyrim.esm") as MiscObject
    if !goldForm
        SkyrimNetApi.RegisterEvent("take_item_failed", akSpeaker.GetDisplayName() + " couldn't take gold from " + akTarget.GetDisplayName(), akSpeaker, akTarget)
        return
    endif

    Bool targetIsPlayer = (akTarget == Game.GetPlayer())

    Int targetGold = akTarget.GetItemCount(goldForm)
    if targetGold <= 0
        SkyrimNetApi.RegisterEvent("take_item_failed", akSpeaker.GetDisplayName() + " tried to take gold but " + akTarget.GetDisplayName() + " has none", akSpeaker, akTarget)
        return
    endif

    ; Walk to the target
    if WalkToReference(akSpeaker, akTarget)
        if IdleTake
            PlayAnimationAndWait(akSpeaker, IdleTake, 2.0)
        endif

        Int transferred = aiAmount
        if transferred > targetGold
            transferred = targetGold
        endif

        if transferred > 0
            akTarget.RemoveItem(goldForm, transferred, false, akSpeaker)
        endif

        ResetToDefaultIdle(akSpeaker)

        String speakerName = akSpeaker.GetDisplayName()
        if targetIsPlayer
            Debug.Notification(speakerName + " took " + transferred + " gold")
            SkyrimNetApi.RegisterEvent("gold_taken_from_player", speakerName + " took " + transferred + " gold from the player", akSpeaker, akTarget)
        else
            SkyrimNetApi.RegisterEvent("gold_taken", speakerName + " took " + transferred + " gold from " + akTarget.GetDisplayName(), akSpeaker, akTarget)
        endif
    else
        SkyrimNetApi.RegisterEvent("take_item_failed", akSpeaker.GetDisplayName() + " couldn't reach " + akTarget.GetDisplayName() + " to take gold", akSpeaker, akTarget)
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

    return SeverActionsNative.FindNearbyItemOfType(akActor, itemType, 1000.0) != None
EndFunction

Function BringItem_Execute(Actor akActor, Actor akTarget, String itemType)
{Bring a nearby item matching the given name/type to the target.}
    if !akActor || !akTarget || itemType == ""
        return
    endif

    ObjectReference nearbyItem = SeverActionsNative.FindNearbyItemOfType(akActor, itemType, 1000.0)

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
; LOOT PROCESSING
; ProcessLoot lives in native (SeverActionsNative.ProcessLoot).
; Callers that need the human-readable description query
; SeverActionsNative.GetLastLootDescription() directly after this returns.
; =============================================================================

int Function ProcessLootList(Actor akActor, ObjectReference akSource, String itemsToTake)
    if !akActor || !akSource
        return 0
    endif

    int totalTaken = SeverActionsNative.ProcessLoot(akActor, akSource, itemsToTake, 30)

    Form lastForm = SeverActionsNative.GetLastLootedForm()
    if lastForm
        SetLastLootedItem(akActor, lastForm, SeverActionsNative.GetLastLootedCount())
    endif

    return totalTaken
EndFunction

; Store the most recent looted form on the actor for prompt reference.
; Single-slot — last loot wins.
Function SetLastLootedItem(Actor akActor, Form akItem, int count)
    if !akActor || !akItem
        return
    endif
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
; FindNearbyItemOfType / FindNearbyContainer are provided natively by
; SeverActionsNative — call sites use those directly. Native does a single
; ForEachReferenceInRange pass; the prior Papyrus version cascaded 12 PO3
; FindAllReferencesOfFormType calls per check.
; =============================================================================

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
{Resolve the merchant chest for an actor. Returns the actor itself when no
vendor faction is found — callers treat that as the "personal inventory"
sentinel. Cached for 5 seconds per actor in native.}
    if !akMerchant
        return None
    endif
    ObjectReference vendorChest = SeverActionsNative.GetMerchantContainer(akMerchant)
    if vendorChest
        return vendorChest
    endif
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

    if !itemForm || akActor.GetItemCount(itemForm) <= 0
        ; Check merchant chest
        ObjectReference merchantChest = GetMerchantContainer(akActor)
        if merchantChest && merchantChest != akActor
            itemForm = FindItemInContainer(merchantChest, itemName)
            if itemForm && merchantChest.GetItemCount(itemForm) > 0
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

    ; ── Diary Detection ─────────────────────────────────────────────
    ; If the book title contains "'s Diary" and PrismaUI is available,
    ; open the diary viewer popup instead of the normal read-all flow.
    ; The viewer queries SkyrimNet's diary DB and lets the player pick
    ; a specific entry to read aloud.
    if StringUtil.Find(actualBookName, "'s Diary") >= 0
        if SeverActionsNative.PrismaUI_IsAvailable()
            Debug.Trace("[SeverActions_Loot] ReadBook: Diary detected — opening diary viewer for '" + actualBookName + "'")
            SeverActionsNative.PrismaUI_OpenDiaryViewerForBook(bookForm, akActor)
            ; Store reader reference so the ModEvent handler can use it
            BookReader = akActor
            return
        endif
        Debug.Trace("[SeverActions_Loot] ReadBook: Diary detected but PrismaUI not available — falling back to normal read")
    endif

    ; Extract the full text from the book
    String bookText = SeverActionsNative.GetBookText(bookForm)

    if bookText == ""
        SkyrimNetApi.RegisterEvent("book_empty", npcName + " opened " + actualBookName + " but found it blank or unreadable", akActor, None)
        return
    endif

    Debug.Trace("[SeverActions_Loot] ReadBook: " + npcName + " reading '" + actualBookName + "' (" + StringUtil.GetLength(bookText) + " chars)")

    ; Set book reading state — Papyrus only tracks the reader and start time;
    ; title/text live in StorageUtil (below) so prompts can read them via
    ; papyrus_util without bloating the cosave.
    BookReader = akActor
    BookReadingStartTime = Utility.GetCurrentRealTime()

    ; Store in StorageUtil — papyrus_util reads these natively, available immediately
    ; The prompt will detect this on the NPC's next dialogue response
    ; BookReadMode: 0 = Verbatim (StorageUtil value 1), 1 = Summary (StorageUtil value 2)
    Int readingModeValue = 1
    if BookReadMode == 1
        readingModeValue = 2
    endif
    StorageUtil.SetIntValue(akActor, "SeverActions_ReadingBook", readingModeValue)
    StorageUtil.SetStringValue(akActor, "SeverActions_ReadingBookTitle", actualBookName)
    StorageUtil.SetStringValue(akActor, "SeverActions_ReadingBookText", bookText)

    ; Play reading animation — use note animation for notes/scrolls, book animation for books
    Bool isNote = SeverActionsNative.IsNote(bookForm)
    Bool isSitting = akActor.GetSitState() >= 2  ; 2 = wanting to sit, 3 = sitting
    if isNote && IdleNoteRead
        if IdleForceDefaultState
            akActor.PlayIdle(IdleForceDefaultState)
            Utility.Wait(0.2)
        endif
        akActor.PlayIdle(IdleNoteRead)
    elseif isSitting && IdleBook_ReadingSitting
        akActor.PlayIdle(IdleBook_ReadingSitting)
    elseif IdleBook_Reading
        if IdleForceDefaultState
            akActor.PlayIdle(IdleForceDefaultState)
            Utility.Wait(0.2)
        endif
        akActor.PlayIdle(IdleBook_Reading)
    endif

    ; Initial narration depends on reading mode
    String openNarration
    if BookReadMode == 1
        ; Summary mode — NPC reads through the book silently first
        openNarration = "*" + npcName + " opens '" + actualBookName + "' and begins reading through it quietly.*"
    else
        ; Verbatim mode — NPC prepares to read aloud, worded to prevent LLM from reading ahead
        openNarration = "*" + npcName + " pulls out '" + actualBookName + "' and begins searching for the right page. They haven't started reading yet — do not read or recite any of the book's contents until the full text is available.*"
    endif
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
    BookReadingStartTime = 0.0
    BookReadingLastNarrationTime = 0.0
EndFunction

; =============================================================================
; DIARY VIEWER — ENTRY SELECTION HANDLER
; Fires when the player selects a diary entry in the PrismaUI diary viewer.
; C++ sets m_selectedDiaryContent/Title, then fires this ModEvent.
; =============================================================================

Event OnDiaryEntrySelected(string eventName, string strArg, float numArg, Form sender)
{ModEvent handler for diary entry selection. strArg = NPC name, sender = reader Actor.}
    Debug.Trace("[SeverActions_Loot] Diary entry selected for '" + strArg + "'")

    ; Retrieve content from the native buffer
    String content = SeverActionsNative.PrismaUI_GetSelectedDiaryContent()
    String title = SeverActionsNative.PrismaUI_GetSelectedDiaryTitle()

    if content == ""
        Debug.Trace("[SeverActions_Loot] Diary: Empty content — aborting")
        BookReader = None
        return
    endif

    ; Reader comes through the ModEvent sender slot — FormID is exact (no float24
    ; truncation). BookReader set during diary detection is the preferred source;
    ; sender is the canonical fallback when this fires after BookReader was cleared.
    Actor reader = BookReader
    if !reader
        reader = sender as Actor
    endif
    if !reader
        Debug.Trace("[SeverActions_Loot] Diary: Could not resolve reader actor")
        return
    endif

    String npcName = reader.GetDisplayName()
    Debug.Trace("[SeverActions_Loot] Diary: Starting reading — '" + title + "' by " + npcName)

    ; Set book reading state — title/text source-of-truth is StorageUtil (below).
    BookReader = reader
    BookReadingStartTime = Utility.GetCurrentRealTime()

    ; Store in StorageUtil for the reading prompt
    ; Use mode 1 (verbatim) for diary entries — the player picked this specific entry
    StorageUtil.SetIntValue(reader, "SeverActions_ReadingBook", 1)
    StorageUtil.SetStringValue(reader, "SeverActions_ReadingBookTitle", title)
    StorageUtil.SetStringValue(reader, "SeverActions_ReadingBookText", content)

    ; Play reading animation
    Bool isSitting = reader.GetSitState() >= 2
    if isSitting && IdleBook_ReadingSitting
        reader.PlayIdle(IdleBook_ReadingSitting)
    elseif IdleBook_Reading
        if IdleForceDefaultState
            reader.PlayIdle(IdleForceDefaultState)
            Utility.Wait(0.2)
        endif
        reader.PlayIdle(IdleBook_Reading)
    endif

    ; Narration — NPC reads the selected diary entry
    String openNarration = "*" + npcName + " opens their diary to a specific entry and begins reading it aloud.*"
    SkyrimNetApi.DirectNarration(openNarration, reader, None)

    ; Persistent event
    SkyrimNetApi.RegisterPersistentEvent(npcName + " is reading a diary entry aloud.", reader, None)

    ; Start auto-continue loop
    BookReadingLastNarrationTime = Utility.GetCurrentRealTime()
    RegisterForSingleUpdate(BookReadingUpdateInterval)
EndEvent

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

    ; Summary mode uses shorter timeout (2 min vs 5 min) and longer silence threshold
    Bool isSummaryMode = (BookReadMode == 1)
    Float activeTimeout = BookReadingTimeout
    Float activeContinueDelay = BookReadingContinueDelay
    if isSummaryMode
        activeTimeout = 120.0
        activeContinueDelay = 30.0
    endif

    ; Check timeout
    Float totalElapsed = Utility.GetCurrentRealTime() - BookReadingStartTime
    if totalElapsed > activeTimeout
        Debug.Trace("[SeverActions_Loot] ReadBook: Auto-continue timeout reached, stopping")
        String npcName = BookReader.GetDisplayName()
        ClearBookReadingState()
        SkyrimNetApi.RegisterEvent("book_reading_stopped", npcName + " finished reading", BookReader, None)
        return
    endif

    ; Check if speech queue is empty (NPC has stopped talking)
    Int queueSize = SkyrimNetApi.GetSpeechQueueSize()
    Float timeSinceLastNarration = Utility.GetCurrentRealTime() - BookReadingLastNarrationTime

    if queueSize == 0 && timeSinceLastNarration >= activeContinueDelay
        String npcName = BookReader.GetDisplayName()
        String narration
        if isSummaryMode
            narration = "*" + npcName + " shares their thoughts on what they've read.*"
        else
            narration = "*" + npcName + " continues reading aloud.*"
        endif
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
