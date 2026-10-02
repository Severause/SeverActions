Scriptname SeverActions_Loot extends Quest
{The items module's actions (pickup, give/take, loot, use, book reading) and its verb
dispatcher OnVerb_Items - by Severause. GiveItem/UseItem also draw on a merchant's chest.}

; =============================================================================
; CONSTANTS
; =============================================================================

float Property INTERACTION_DISTANCE = 150.0 AutoReadOnly

; =============================================================================
; BOOK READING STATE - the title and text live in per-actor StorageUtil (read by
; the prompt via papyrus_util), never quest properties: book text runs to tens of
; KB and a property would ride every save.
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

; No SurvivalScript property (DR2): a meal or a drink goes to Survival as the
; survival.ateFood / drank verbs (UseItem_Execute).

; =============================================================================
; LOAD-TIME SETUP
; =============================================================================

Function InitializeDiaryEvents()
{Register this script's ModEvents and re-arm the reading tick. Run on every
load and new game by SeverActions_Mod_Items stage 0.}
    ; BookReader is saved but a pending tick is not: re-arm or a reading
    ; session spanning a save goes silent.
    If BookReader != None
        ChronoArm(BookReadingUpdateInterval)
    EndIf
    RegisterForModEvent("SeverActions_DiaryEntrySelected", "OnDiaryEntrySelected")
    RegisterForModEvent("SeverActions_DiaryCancelled", "OnDiaryCancelled")
    ; Sent by the native CombatSpoilsScanner; no other script on the quest may register this name.
    RegisterForModEvent("SeverActions_CombatSpoils", "OnCombatSpoils")
    ; The items module's verb event (M-V, DR16): see OnVerb_Items.
    RegisterForModEvent("SeverActions_Verb_Items", "OnVerb_Items")
    Debug.Trace("[SeverActions_Loot] Registered for diary selection events")
EndFunction

Event OnCombatSpoils(String eventName, String strArg, Float numArg, Form sender)
    {CombatSpoilsScanner: the player's combat ended with notable spoils on the
     fallen (strArg). One event so nearby NPCs can react or loot on their own.}
    If strArg == ""
        Return
    EndIf
    SkyrimNetApi.RegisterEvent("combat_spoils", \
        "The fighting is over. Worthwhile spoils lie on the fallen — " + strArg + ".", \
        Game.GetPlayer(), None)
EndEvent

Event OnDiaryCancelled(String eventName, String strArg, Float numArg, Form sender)
    {The diary viewer closed without a pick: release the reader slot, which
     otherwise blocks ReadBook for every NPC until the timeout.}
    ; Only a viewer claim (no reading keys yet): a normal read started since is left alone.
    If BookReader != None && StorageUtil.GetIntValue(BookReader, "SeverActions_ReadingBook", 0) == 0
        Debug.Trace("[SeverActions_Loot] Diary viewer cancelled - releasing BookReader")
        BookReader = None
        BookReadingStartTime = 0.0
    EndIf
EndEvent

; =============================================================================
; AI PACKAGE PROPERTIES
; =============================================================================

Package Property GoToRefPackage Auto
ReferenceAlias Property TargetRefAlias Auto

; =============================================================================
; MOVEMENT HELPER FUNCTIONS
; =============================================================================

Bool Function WalkToReference(Actor akActor, ObjectReference akTarget, float maxWaitTime = 15.0)
    {Forwarder to SeverActions_WalkLib, which resolves the go-to package and the
     TargetRef alias itself; the two properties above stay for their VMAD fills.}
    ; M-I-STUB 3.9.14-beta25 (P3-06): forwards to SeverActions_WalkLib.WalkToReference
    return SeverActions_WalkLib.WalkToReference(akActor, akTarget, maxWaitTime)
EndFunction

; =============================================================================
; STRING HELPERS
; =============================================================================

String Function EscapeJsonString(String text) Global
    return SeverActionsNative.EscapeJsonString(text)
EndFunction

String Function ToLowerCase(String text) Global
    return SeverActionsNative.StringToLower(text)
EndFunction

String Function _StripLeadingArticle(String text) Global
{text less one leading "the ", "a " or "an " (any case: Papyrus String == folds case), so an item name
the LLM passed with its article splices cleanly after "any"; text itself when nothing would be left.}
    Int len = StringUtil.GetLength(text)
    If len > 4 && StringUtil.Substring(text, 0, 4) == "the "
        return StringUtil.Substring(text, 4)
    ElseIf len > 3 && StringUtil.Substring(text, 0, 3) == "an "
        return StringUtil.Substring(text, 3)
    ElseIf len > 2 && StringUtil.Substring(text, 0, 2) == "a "
        return StringUtil.Substring(text, 2)
    EndIf
    return text
EndFunction

; =============================================================================
; CONTAINER LOOKUP BY REFID
; =============================================================================

ObjectReference Function GetContainerByRefID(String refIdStr)
{Convert a RefID string to an ObjectReference. Decimal format only.}
    if refIdStr == ""
        return None
    endif

    int refId = refIdStr as int
    if refId == 0 && refIdStr != "0"
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
            ; Owned: silent native pickup plus the SA tracked bounty if witnessed.
            ; Never Activate an owned ref: the vanilla theft alarm bounties the
            ; PLAYER, even for a follower's pickup. Unowned: Activate, which keeps
            ; enchant/temper extras and has no crime to raise.
            if SeverActionsNativeExt.IsRefOwnedByNonPlayer(nearbyItem)
                SeverActionsNativeExt.PickUpItemSilent(akActor, nearbyItem)
                ApplyTheftBounty(akActor, "the " + itemName)
            else
                nearbyItem.Activate(akActor)
            endif
            ResetToDefaultIdle(akActor)
            SkyrimNetApi.RegisterEvent("item_picked_up", akActor.GetDisplayName() + " picked up " + itemName, akActor, None)
        else
            SkyrimNetApi.RegisterEvent("item_unreachable", akActor.GetDisplayName() + " couldn't reach " + itemName, akActor, None)
        endif
    else
        SkyrimNetApi.RegisterEvent("item_not_found", akActor.GetDisplayName() + " couldn't find any " + _StripLeadingArticle(itemType) + " nearby", akActor, None)
    endif
EndFunction

; =============================================================================
; ACTION: LootContainer - loot a nearby container by name
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

    ; A locked container gets one pick attempt; a key-only lock or a failed pick ends the action.
    if akContainer.IsLocked()
        if !WalkToReference(akActor, akContainer)
            SkyrimNetApi.RegisterEvent("container_unreachable", akActor.GetDisplayName() + " couldn't reach " + displayName, akActor, None)
            return
        endif
        if !TryPickLock(akActor, akContainer, displayName)
            return
        endif
    endif

    Debug.Trace("[SeverActions_Loot] " + akActor.GetDisplayName() + " looting container: " + displayName)
    LootRef_Helper(akActor, akContainer, IdleSearchingChest, 2.5, displayName, "container", "took", itemsToTake)
EndFunction

Bool Function TryPickLock(Actor akActor, ObjectReference akContainer, String displayName)
    {One lockpicking attempt; true when the lock is open. Key-only locks (level
     255) never yield. Chance = 30 + Lockpicking - lock level, clamped 5..95;
     success unlocks the ref for good. Raises no vanilla crime either way.}
    Int lockLevel = akContainer.GetLockLevel()
    if lockLevel >= 255
        SkyrimNetApi.RegisterEvent("container_locked", \
            akActor.GetDisplayName() + " tried " + displayName + ", but it needs its key — no pick will turn that lock.", akActor, None)
        return false
    endif
    ; Vanilla IdleLockPick, by FormID so no ESP fill is needed; plays whatever the roll's outcome.
    Idle lockIdle = Game.GetFormFromFile(0x000BB051, "Skyrim.esm") as Idle
    if lockIdle
        PlayAnimationAndWait(akActor, lockIdle, 3.0)
        ResetToDefaultIdle(akActor)
        Utility.Wait(0.2)
    endif
    Int skill = akActor.GetAV("Lockpicking") as Int
    Int chance = 30 + skill - lockLevel
    if chance < 5
        chance = 5
    elseif chance > 95
        chance = 95
    endif
    if Utility.RandomInt(0, 99) < chance
        akContainer.Lock(false)
        SkyrimNetApi.RegisterEvent("lock_picked", \
            akActor.GetDisplayName() + " worked the lock on " + displayName + " open.", akActor, None)
        return true
    endif
    SkyrimNetApi.RegisterEvent("lockpick_failed", \
        akActor.GetDisplayName() + " tried to pick the lock on " + displayName + " and couldn't turn it.", akActor, None)
    return false
EndFunction

; =============================================================================
; ACTIONS: SearchContainer / SearchCorpse - reveal the contents, take nothing
; =============================================================================

Function SearchContainer_Execute(Actor akActor, String containerName)
    {Walk over, rummage, and describe what is inside as an event, so the LLM can
     pick what to take with a follow-up loot call.}
    if !akActor || containerName == ""
        return
    endif
    ObjectReference akContainer = SeverActionsNative.FindNearbyContainer(akActor, containerName, 1000.0)
    if !akContainer
        SkyrimNetApi.RegisterEvent("container_not_found", akActor.GetDisplayName() + " couldn't find a " + containerName + " nearby", akActor, None)
        return
    endif
    String displayName = akContainer.GetBaseObject().GetName()
    if !WalkToReference(akActor, akContainer)
        SkyrimNetApi.RegisterEvent("container_unreachable", akActor.GetDisplayName() + " couldn't reach " + displayName, akActor, None)
        return
    endif
    if akContainer.IsLocked()
        if !TryPickLock(akActor, akContainer, displayName)
            return
        endif
    endif
    if IdleSearchingChest
        PlayAnimationAndWait(akActor, IdleSearchingChest, 2.5)
    endif
    ResetToDefaultIdle(akActor)
    _FireSearchEvent(akActor, akContainer, displayName, "container_searched", "searches")
EndFunction

Function SearchCorpse_Execute(Actor akActor, String corpseName)
    {Pat down a corpse and describe what it carries as an event.}
    if !akActor || corpseName == ""
        return
    endif
    Actor akCorpse = SeverActionsNativeExt.FindNearestDeadByName(akActor, corpseName, 4096.0)
    if !akCorpse || !akCorpse.IsDead()
        SkyrimNetApi.RegisterEvent("corpse_not_found", akActor.GetDisplayName() + " couldn't find " + corpseName, akActor, None)
        return
    endif
    String displayName = akCorpse.GetDisplayName()
    if !WalkToReference(akActor, akCorpse)
        SkyrimNetApi.RegisterEvent("corpse_unreachable", akActor.GetDisplayName() + " couldn't reach " + displayName, akActor, None)
        return
    endif
    if IdleLootBody
        PlayAnimationAndWait(akActor, IdleLootBody, 3.0)
    endif
    ResetToDefaultIdle(akActor)
    _FireSearchEvent(akActor, akCorpse, displayName, "corpse_searched", "searches the body of")
EndFunction

Function _FireSearchEvent(Actor akActor, ObjectReference akSource, String displayName, String eventKind, String verb)
    {Shared tail of the Search actions: the contents event.}
    String contents = SeverActionsNativeExt.Native_Loot_DescribeContents(akSource, 10)
    if contents == ""
        SkyrimNetApi.RegisterEvent(eventKind, akActor.GetDisplayName() + " " + verb + " " + displayName + " — nothing there worth taking.", akActor, None)
    else
        SkyrimNetApi.RegisterEvent(eventKind, \
            akActor.GetDisplayName() + " " + verb + " " + displayName + ". Inside: " + contents + ".", \
            akActor, None)
    endif
EndFunction

; =============================================================================
; ACTION: LootCorpse - Loot a dead actor by name
; =============================================================================

Bool Function LootCorpse_IsEligible(Actor akActor, String corpseName) Global
    if !akActor || akActor.IsDead() || akActor.IsInCombat() || corpseName == ""
        return false
    endif

    ; Nearest DEAD match, so a live same-named actor cannot shadow the corpse.
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
        SkyrimNetApi.RegisterEvent("corpse_not_found", akActor.GetDisplayName() + " won't loot " + corpseName + ", who is still alive", akActor, None)
        return
    endif

    if akActor.GetDistance(akCorpse) > 4096.0
        SkyrimNetApi.RegisterEvent("corpse_unreachable", akActor.GetDisplayName() + " is too far from " + corpseName, akActor, None)
        return
    endif

    String displayName = akCorpse.GetDisplayName()
    LootRef_Helper(akActor, akCorpse, IdleLootBody, 3.0, displayName, "corpse", "looted", itemsToTake)
EndFunction

; Tracked bounty for the theft the last ProcessLoot / PickUpItemSilent recorded -
; the only consequence, as those raise no vanilla crime. No-op unless something
; was stolen, a witness saw it (1500u) and there is a crime faction.
; asWhat completes "was seen stealing ...": "the <item>" or "from <container>".
Function ApplyTheftBounty(Actor akActor, String asWhat)
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
    ; The doer carries the bounty: a follower's theft is theirs, not the player's.
    SeverActionsNativeExt.Native_Bounty_ModFor(akActor, crimeFaction, stolenValue)
    SeverActionsNativeExt.Native_Bounty_AddEventFor(akActor, crimeFaction, stolenValue, "theft", "")
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("loot.bountyGold", ("" + stolenValue), ("" + akActor.GetDisplayName())))
    SkyrimNetApi.RegisterPersistentEvent(akActor.GetDisplayName() + " was seen stealing " + asWhat + ", and now carries a " + stolenValue + " gold bounty for it.", akActor, Game.GetPlayer())
EndFunction

; Shared body of LootContainer_Execute / LootCorpse_Execute: walk, animate, native
; ProcessLoot, then a "<kind>_looted" or "<kind>_unreachable" event.
Function LootRef_Helper(Actor akActor, ObjectReference akTarget, Idle anim, Float animDuration, String displayName, String kind, String verb, String itemsToTake)
    if !akActor || !akTarget
        return
    endif

    if WalkToReference(akActor, akTarget)
        if anim
            PlayAnimationAndWait(akActor, anim, animDuration)
        endif
        ; End the idle first: ProcessLoot can take a while on a big pile.
        ResetToDefaultIdle(akActor)
        Utility.Wait(0.2)

        int itemsTaken = ProcessLootList(akActor, akTarget, itemsToTake)
        String desc = SeverActionsNative.GetLastLootDescription()

        if itemsTaken > 0 && desc != ""
            String suffix = ""
            if itemsTaken >= 30
                ; The description stops at 30 stacks. "all"/"everything" move every stack; the other
                ; modes take at most 30 stacks per call, so more may remain.
                if itemsToTake == "all" || itemsToTake == "everything"
                    suffix = " (and more besides)"
                else
                    suffix = " (as much as they could grab in one go)"
                endif
            endif
            SkyrimNetApi.RegisterEvent(kind + "_looted", akActor.GetDisplayName() + " " + verb + " " + desc + " from " + displayName + suffix, akActor, None)
            ApplyTheftBounty(akActor, "from " + displayName)
        else
            ; A named-item request gets a specific miss message.
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
; ACTION: GiveItem - hand item(s) to another actor, from the pack or the merchant chest
; =============================================================================

Bool Function GiveItem_IsEligible(Actor akActor, Actor akTarget, String itemName, Int aiCount = 1) Global
    if !akActor || !akTarget || akActor.IsDead() || akActor.IsInCombat()
        return false
    endif
    ; Own pack or merchant stock
    return MerchantHasItem(akActor, itemName)
EndFunction

Function GiveItem_Execute(Actor akActor, Actor akTarget, String itemName, Int aiCount = 1)
    if !akActor || !akTarget || itemName == ""
        return
    endif

    if aiCount < 1
        aiCount = 1
    endif

    if WalkToReference(akActor, akTarget)
        if IdleGive
            PlayAnimationAndWait(akActor, IdleGive, 2.0)
        endif

        ; Own pack first, then the merchant chest
        Form itemForm = GetItemFormByName(akActor, itemName)
        Int transferred = 0
        String actualName = itemName

        if itemForm && akActor.GetItemCount(itemForm) > 0
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

        ; Auto-debt: a gift from a creditor adds its value to the receiver's debt, through
        ; the economy provider (DR2: items may not name its types); no module, no ledger.
        if transferred > 0 && itemForm
            int goldValue = GetFormValue(itemForm) * transferred
            if goldValue > 0
                SeverActions_ModuleBase.CallBool("economy", "autoAddToDebt", akActor, akTarget, "", goldValue)
            endif
        endif

        if transferred > 1
            SkyrimNetApi.RegisterEvent("item_given", akActor.GetDisplayName() + " gave " + transferred + " " + actualName + " to " + akTarget.GetDisplayName(), akActor, akTarget)
        elseif transferred == 1
            SkyrimNetApi.RegisterEvent("item_given", akActor.GetDisplayName() + " gave " + actualName + " to " + akTarget.GetDisplayName(), akActor, akTarget)
        else
            SkyrimNetApi.RegisterEvent("item_give_failed", akActor.GetDisplayName() + " doesn't have " + itemName + " to give", akActor, akTarget)
        endif
    else
        SkyrimNetApi.RegisterEvent("item_give_failed", akActor.GetDisplayName() + " couldn't reach " + akTarget.GetDisplayName() + " to give " + itemName, akActor, akTarget)
    endif
EndFunction

Function GiveItemForm_Execute(Actor akActor, Actor akTarget, Form akItem, Int aiCount = 1)
{Hand a specific item form to akTarget with the give animation, for an item a
 name lookup cannot find (a courier letter retitled at delivery). No walk-up
 (the caller positions the giver) and no auto-debt (a letter or gift must not
 grow a tab).}
    if !akActor || !akTarget || !akItem
        return
    endif
    if aiCount < 1
        aiCount = 1
    endif
    if IdleGive
        PlayAnimationAndWait(akActor, IdleGive, 2.0)
    endif
    Int available = akActor.GetItemCount(akItem)
    Int transferred = aiCount
    if transferred > available
        transferred = available
    endif
    if transferred > 0
        akActor.RemoveItem(akItem, transferred, false, akTarget)
    endif
    ResetToDefaultIdle(akActor)
EndFunction

; =============================================================================
; TRANSACTION HELPERS - moved to SeverActions_Currency (P5b). Safe-exit stubs
; (M-I, check 20): a save can hold a frame suspended in the old bodies (F7).
; =============================================================================

Form Function ResolveItemForTransaction(Actor akSeller, String itemName) Global
    {Safe-exit stub: moved to SeverActions_Currency.ResolveItemForTransaction (P5b).}
    ; M-I-STUB 3.9.14-beta25 (P5b): moved to SeverActions_Currency, plan B19
    Return None
EndFunction

Int Function GetTransactionAvailableQty(Actor akSeller, Form akItemForm) Global
    {Safe-exit stub: moved to SeverActions_Currency.GetTransactionAvailableQty (P5b).}
    ; M-I-STUB 3.9.14-beta25 (P5b): moved to SeverActions_Currency, plan B19
    Return 0
EndFunction

Int Function TransferItemForTransaction(Actor akSeller, Actor akBuyer, Form akItemForm, Int aiCount = 1)
    {Safe-exit stub: moved to SeverActions_Currency.TransferItemForTransaction (P5b).
     A frame resumed inside the old body reports nothing moved; Currency refunds.}
    ; M-I-STUB 3.9.14-beta25 (P5b): moved to SeverActions_Currency, plan B19
    Return 0
EndFunction

; =============================================================================
; ACTION: TakeItem - the speaker takes an item from the player or any NPC
; =============================================================================

Function TakeItem_Execute(Actor akSpeaker, Actor akTarget, String itemName, Int aiCount = 1)
{The speaker walks to the target and takes an item from their inventory with
 the take animation. Gold goes through TakeGoldFrom (the LLM often picks this
 action where CollectPayment was meant).}
    if !akSpeaker || !akTarget || itemName == ""
        return
    endif
    if akSpeaker == akTarget
        return
    endif

    if aiCount < 1
        aiCount = 1
    endif

    Actor playerRef = Game.GetPlayer()
    Bool targetIsPlayer = (akTarget == playerRef)

    ; Gold by any common name
    if SeverActionsNative.IsGoldName(itemName)
        TakeGoldFrom(akSpeaker, akTarget, aiCount)
        return
    endif

    Form itemForm = GetItemFormByName(akTarget, itemName)
    if !itemForm || akTarget.GetItemCount(itemForm) <= 0
        SkyrimNetApi.RegisterEvent("take_item_failed", akSpeaker.GetDisplayName() + " couldn't find " + itemName + " in " + akTarget.GetDisplayName() + "'s inventory", akSpeaker, akTarget)
        return
    endif

    String actualName = itemForm.GetName()

    ; A name that still resolved to gold
    MiscObject goldForm = Game.GetFormFromFile(0x0000000F, "Skyrim.esm") as MiscObject
    if goldForm && itemForm == goldForm as Form
        TakeGoldFrom(akSpeaker, akTarget, aiCount)
        return
    endif

    if WalkToReference(akSpeaker, akTarget)
        if IdleTake
            PlayAnimationAndWait(akSpeaker, IdleTake, 2.0)
        endif

        Int available = akTarget.GetItemCount(itemForm)
        Int transferred = aiCount
        if transferred > available
            transferred = available
        endif

        if transferred > 0
            ; Silent for the player: our own notification below replaces the engine's.
            akTarget.RemoveItem(itemForm, transferred, targetIsPlayer, akSpeaker)
        endif

        ResetToDefaultIdle(akSpeaker)

        ; The player-target path keeps its older event name, item_taken_from_player.
        String speakerName = akSpeaker.GetDisplayName()
        String targetName = akTarget.GetDisplayName()
        if transferred > 1
            if targetIsPlayer
                Debug.Notification(speakerName + " took " + actualName + " (" + transferred + ")")
                SkyrimNetApi.RegisterEvent("item_taken_from_player", speakerName + " took " + transferred + " " + actualName + " from " + targetName, akSpeaker, akTarget)
            else
                SkyrimNetApi.RegisterEvent("item_taken", speakerName + " took " + transferred + " " + actualName + " from " + targetName, akSpeaker, akTarget)
            endif
        elseif transferred == 1
            if targetIsPlayer
                Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("loot.tookItem", ("" + speakerName), ("" + actualName)))
                SkyrimNetApi.RegisterEvent("item_taken_from_player", speakerName + " took " + actualName + " from " + targetName, akSpeaker, akTarget)
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
{TakeItem_Execute with the player as the target: the takeItemFromPlayer verb,
 and user actions still naming this old executionFunctionName.}
    TakeItem_Execute(akActor, Game.GetPlayer(), itemName, aiCount)
EndFunction

Function TakeGoldFrom(Actor akSpeaker, Actor akTarget, Int aiAmount)
{The speaker takes gold from any actor with the take animation. Booked like the
 Currency actions: a ledger row when the player is a party, and the gold pays
 down anything the target owes the speaker.}
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
            ; The attributed row, right after the move (else it books as an
            ; unattributed "Other"). No double entry: GoldDeltaMonitor's deferred
            ; generic delta is dropped when a RecordEvent of the same amount and
            ; direction lands within LedgerStore's 1.5 s window.
            if targetIsPlayer
                SeverActionsNativeExt.Native_Ledger_RecordEvent(transferred, True, "take_gold", akSpeaker, "", "", 0)
            elseif akSpeaker == Game.GetPlayer()
                SeverActionsNativeExt.Native_Ledger_RecordEvent(transferred, False, "take_gold", akTarget, "", "", 0)
            endif
        endif

        ResetToDefaultIdle(akSpeaker)

        String speakerName = akSpeaker.GetDisplayName()
        if targetIsPlayer
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("loot.tookGold", ("" + speakerName), ("" + transferred)))
            SkyrimNetApi.RegisterEvent("gold_taken_from_player", speakerName + " took " + transferred + " gold from " + akTarget.GetDisplayName(), akSpeaker, akTarget)
        else
            SkyrimNetApi.RegisterEvent("gold_taken", speakerName + " took " + transferred + " gold from " + akTarget.GetDisplayName(), akSpeaker, akTarget)
        endif

        if transferred > 0
            ; Pay down what the target owes the speaker, as CollectPayment does
            ; (economy provider; no module, no debt).
            SeverActions_ModuleBase.CallBool("economy", "reduceDebtByPayment", akSpeaker, akTarget, "", transferred)
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
            ; Owned-item contract: see PickUpItem_Execute. Never AddItem + Disable +
            ; Delete here: it skips the ownership check and strips enchant/temper extras.
            if SeverActionsNativeExt.IsRefOwnedByNonPlayer(nearbyItem)
                SeverActionsNativeExt.PickUpItemSilent(akActor, nearbyItem)
                ApplyTheftBounty(akActor, "the " + itemName)
            else
                nearbyItem.Activate(akActor)
            endif

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
        SkyrimNetApi.RegisterEvent("item_not_found", akActor.GetDisplayName() + " couldn't find any " + _StripLeadingArticle(itemType) + " nearby", akActor, None)
    endif
EndFunction

; =============================================================================
; LOOT PROCESSING - native ProcessLoot; read GetLastLootDescription() right after
; for the event text.
; =============================================================================

int Function ProcessLootList(Actor akActor, ObjectReference akSource, String itemsToTake)
    if !akActor || !akSource
        return 0
    endif

    return SeverActionsNative.ProcessLoot(akActor, akSource, itemsToTake, 30)
EndFunction

; =============================================================================
; VALUE HELPERS
; =============================================================================

int Function GetFormValue(Form akForm) Global
    return SeverActionsNative.GetFormGoldValue(akForm)
EndFunction

; =============================================================================
; INVENTORY HELPERS
; =============================================================================

Bool Function ActorHasItemByName(Actor akActor, String itemName) Global
    Form f = GetItemFormByName(akActor, itemName)
    return f != None && akActor.GetItemCount(f) > 0
EndFunction

Form Function GetItemFormByName(Actor akActor, String itemName) Global
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
{The actor's merchant chest, or the actor itself when no vendor faction has one
(callers read that as "personal inventory"). Cached 5 s per actor in native.}
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
    return SeverActionsNative.FindItemInContainer(akContainer, itemName)
EndFunction

Form Function FindItemInMerchantStock(Actor akMerchant, String itemName) Global
{Find an item in merchant's personal inventory OR their merchant chest.}
    if !akMerchant || itemName == ""
        return None
    endif

    Form personalItem = GetItemFormByName(akMerchant, itemName)
    if personalItem && akMerchant.GetItemCount(personalItem) > 0
        return personalItem
    endif

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
; ACTION: UseItem - eat, drink or use a consumable from the pack or merchant chest
; =============================================================================

Bool Function UseItem_IsEligible(Actor akActor, String itemName) Global
    if !akActor || akActor.IsDead() || itemName == ""
        return false
    endif

    Form itemForm = FindItemInMerchantStock(akActor, itemName)
    if !itemForm
        return false
    endif

    if !IsConsumable(itemForm)
        return false
    endif
    
    return true
EndFunction

Function UseItem_Execute(Actor akActor, String itemName)
    if !akActor || itemName == ""
        return
    endif

    ; Own pack first, then the merchant chest
    Form itemForm = GetItemFormByName(akActor, itemName)

    if !itemForm || akActor.GetItemCount(itemForm) <= 0
        ObjectReference merchantChest = GetMerchantContainer(akActor)
        if merchantChest && merchantChest != akActor
            itemForm = FindItemInContainer(merchantChest, itemName)
            if itemForm && merchantChest.GetItemCount(itemForm) > 0
                ; Into their pack, where EquipItem can consume it
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

    if akActor.GetItemCount(itemForm) <= 0
        Debug.Trace("[SeverActions_Loot] UseItem: " + akActor.GetDisplayName() + " doesn't have " + itemName)
        return
    endif
    
    String actualItemName = itemForm.GetName()
    Debug.Trace("[SeverActions_Loot] UseItem: " + akActor.GetDisplayName() + " consuming " + actualItemName)

    Potion potionForm = itemForm as Potion
    Ingredient ingredientForm = itemForm as Ingredient

    if potionForm
        if potionForm.IsFood()
            PlayConsumeAnimation(akActor, true, itemForm)  ; true = food
        else
            PlayConsumeAnimation(akActor, false, itemForm) ; false = potion/drink
        endif

        ; EquipItem consumes it: effects applied, item removed
        akActor.EquipItem(potionForm, false, true)

        if potionForm.IsFood()
            ; Survival owns hunger; it hears the meal through its verb
            SeverActionsNativeExt2.Verb_Send("survival", "ateFood", "||" + itemForm.GetFormID(), akActor)
            SkyrimNetApi.RegisterEvent("item_consumed", akActor.GetDisplayName() + " ate " + actualItemName, akActor, None)
        elseif potionForm.IsPoison()
            SkyrimNetApi.RegisterEvent("item_consumed", akActor.GetDisplayName() + " drank " + actualItemName + " - and it was poison", akActor, None)
        else
            ; Other potions and drinks still sate hunger slightly
            SeverActionsNativeExt2.Verb_Send("survival", "drank", "||" + itemForm.GetFormID(), akActor)
            SkyrimNetApi.RegisterEvent("item_consumed", akActor.GetDisplayName() + " drank " + actualItemName, akActor, None)
        endif
        
    elseif ingredientForm
        PlayConsumeAnimation(akActor, true, itemForm) ; food animation

        ; EquipItem on an ingredient eats it (learns its first effect)
        akActor.EquipItem(ingredientForm, false, true)

        ; A raw ingredient counts as food (Survival picks the amount)
        SeverActionsNativeExt2.Verb_Send("survival", "ateFood", "||" + itemForm.GetFormID(), akActor)
        SkyrimNetApi.RegisterEvent("item_consumed", akActor.GetDisplayName() + " ate raw " + actualItemName, akActor, None)
    else
        Debug.Trace("[SeverActions_Loot] UseItem: Unknown consumable type for " + actualItemName + ", attempting EquipItem")
        akActor.EquipItem(itemForm, false, true)
        SkyrimNetApi.RegisterEvent("item_consumed", akActor.GetDisplayName() + " used " + actualItemName, akActor, None)
    endif
    
    ResetToDefaultIdle(akActor)
EndFunction

Bool Function IsConsumable(Form akForm) Global
    return SeverActionsNative.IsConsumable(akForm)
EndFunction

; TaberuAnimation (Eating Animations and Sounds) when installed, else the basic idles.
Function PlayConsumeAnimation(Actor akActor, Bool isFood, Form itemForm = None)
    if !akActor
        return
    endif

    if IdleForceDefaultState
        akActor.PlayIdle(IdleForceDefaultState)
        Utility.Wait(0.2)
    endif

    if itemForm && SeverActions_EatingAnimations.IsInstalled()
        if SeverActions_EatingAnimations.PlayEatingAnimation(akActor, itemForm)
            ; The spell cleans up in its OnEffectFinish; just wait out its duration
            float duration = SeverActions_EatingAnimations.GetAnimationDuration(itemForm)
            Utility.Wait(duration)
            return
        endif
    endif

    if isFood && IdleEatSoup
        akActor.PlayIdle(IdleEatSoup)
        Utility.Wait(2.0)
    elseif !isFood && IdleDrinkPotion
        akActor.PlayIdle(IdleDrinkPotion)
        Utility.Wait(1.5)
    else
        Utility.Wait(0.5)
    endif
EndFunction

; =============================================================================
; ACTION: ReadBook - read a book from the NPC's pack or the player's
; =============================================================================

Bool Function ReadBook_IsEligible(Actor akActor, String bookName)
{True when the actor can read the named book (any book when empty). False
while someone is already reading, unless that session has timed out. No
caller: ReadBook_Execute does the same reclaim.}
    if !akActor || akActor.IsDead() || akActor.IsInCombat()
        return false
    endif

    if BookReader != None
        ; Reclaim a stale session past its timeout
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
        return SeverActionsNative.HasBooks(akActor) || SeverActionsNative.HasBooks(Game.GetPlayer())
    endif

    ; Their pack first, then the player's (borrowed in place, see ReadBook_Execute)
    Form bookForm = SeverActionsNative.FindBookInInventory(akActor, bookName)
    if !bookForm
        bookForm = SeverActionsNative.FindBookInInventory(Game.GetPlayer(), bookName)
    endif
    return bookForm != None
EndFunction

Function ReadBook_Execute(Actor akActor, String bookName)
{Enter reading mode: the book text goes to StorageUtil for the reading prompt,
which shapes the NPC's next lines, and OnChronoTick_Loot nudges them to keep
going. A diary opens the diary viewer instead when the interface is available.}
    if !akActor || akActor.IsDead()
        return
    endif

    ; Already reading: the prompt is driving it, unless that session is stale. A viewer
    ; claim (no reading key yet) is live while the player still has its viewer open.
    if BookReader != None
        Bool liveViewer = StorageUtil.GetIntValue(BookReader, "SeverActions_ReadingBook", 0) == 0 && SeverActionsNative.Magelight_IsDiaryViewerOpen()
        if !liveViewer && BookReadingStartTime > 0.0 && (Utility.GetCurrentRealTime() - BookReadingStartTime) > BookReadingTimeout
            Debug.Trace("[SeverActions_Loot] ReadBook: clearing a stale reading session")
            ClearBookReadingState()
        else
            Debug.Trace("[SeverActions_Loot] ReadBook: Already in reading mode, ignoring duplicate execute")
            return
        endif
    endif

    ; Their pack first, then the player's. Reading is non-destructive, so a
    ; player's book is read in place, no transfer: GetBookText needs only the base form.
    Form bookForm = None
    Bool borrowed = false
    if bookName != ""
        bookForm = SeverActionsNative.FindBookInInventory(akActor, bookName)
        if !bookForm
            bookForm = SeverActionsNative.FindBookInInventory(Game.GetPlayer(), bookName)
            borrowed = bookForm != None
        endif
    endif

    if !bookForm
        String npcName = akActor.GetDisplayName()
        if bookName != ""
            SkyrimNetApi.RegisterEvent("book_not_found", npcName + " looked for '" + bookName + "' but neither they nor " + Game.GetPlayer().GetDisplayName() + " is carrying it", akActor, None)
        else
            SkyrimNetApi.RegisterEvent("book_not_found", npcName + " has no books to read", akActor, None)
        endif
        return
    endif

    String actualBookName = bookForm.GetName()
    String npcName = akActor.GetDisplayName()

    ; A "'s Diary" title opens the diary viewer instead: the player picks one
    ; entry from SkyrimNet's diary DB to be read aloud (OnDiaryEntrySelected).
    if StringUtil.Find(actualBookName, "'s Diary") >= 0
        if SeverActionsNative.Magelight_IsAvailable() && !SeverActionsNative.Magelight_IsDiaryViewerOpen()
            Debug.Trace("[SeverActions_Loot] ReadBook: Diary detected - opening diary viewer for '" + actualBookName + "'")
            SeverActionsNative.Magelight_OpenDiaryViewerForBook(bookForm, akActor)
            ; The open reports nothing: the viewer being open now is the success test
            ; (it opens synchronously, or not at all: no entries, focus held, view not ready).
            if SeverActionsNative.Magelight_IsDiaryViewerOpen()
                ; Claim the reader slot for the selection handler; StartTime lets the
                ; stale-slot reclaim above release it.
                BookReader = akActor
                BookReadingStartTime = Utility.GetCurrentRealTime()
                return
            endif
            Debug.Trace("[SeverActions_Loot] ReadBook: the diary viewer did not open - falling back to normal read")
        else
            Debug.Trace("[SeverActions_Loot] ReadBook: Diary detected but the diary viewer is unavailable - falling back to normal read")
        endif
    endif

    String bookText = SeverActionsNative.GetBookText(bookForm)

    if bookText == ""
        SkyrimNetApi.RegisterEvent("book_empty", npcName + " opened " + actualBookName + " but found it blank or unreadable", akActor, None)
        return
    endif

    Debug.Trace("[SeverActions_Loot] ReadBook: " + npcName + " reading '" + actualBookName + "' (" + StringUtil.GetLength(bookText) + " chars, borrowed=" + borrowed + ")")

    ; A scene beat so both characters know whose book it is
    if borrowed
        SkyrimNetApi.RegisterEvent("book_borrowed", \
            npcName + " borrows '" + actualBookName + "' from " + Game.GetPlayer().GetDisplayName() + "'s pack.", \
            akActor, Game.GetPlayer())
    endif

    BookReader = akActor
    BookReadingStartTime = Utility.GetCurrentRealTime()

    ; Read by the prompt on the NPC's next line. SeverActions_ReadingBook:
    ; 1 = verbatim (BookReadMode 0), 2 = summary (BookReadMode 1).
    Int readingModeValue = 1
    if BookReadMode == 1
        readingModeValue = 2
    endif
    StorageUtil.SetIntValue(akActor, "SeverActions_ReadingBook", readingModeValue)
    StorageUtil.SetStringValue(akActor, "SeverActions_ReadingBookTitle", actualBookName)
    StorageUtil.SetStringValue(akActor, "SeverActions_ReadingBookText", bookText)

    ; The note idle for a note, else the book idle (seated or standing)
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

    String openNarration
    if BookReadMode == 1
        openNarration = "*" + npcName + " opens '" + actualBookName + "' and begins reading through it quietly.*"
    else
        ; Worded so the LLM recites nothing before the text is in its prompt
        openNarration = "*" + npcName + " pulls out '" + actualBookName + "' and leafs through it for the right page - they have not found it yet, so not a word of it can be read or quoted until they do.*"
    endif
    SkyrimNetApi.DirectNarration(openNarration, akActor, None)

    SkyrimNetApi.RegisterPersistentEvent(npcName + " is reading '" + actualBookName + "' aloud.", akActor, None)

    ; Start the auto-continue loop (OnChronoTick_Loot)
    BookReadingLastNarrationTime = Utility.GetCurrentRealTime()
    ChronoArm(BookReadingUpdateInterval)
EndFunction

Function ClearBookReadingState()
{Clear all book reading state. Call when reading finishes or times out.}
    ; The slot is freed before the idle reset, which waits: a new reading started in that wait keeps its own state.
    Actor reader = BookReader
    BookReader = None
    BookReadingStartTime = 0.0
    BookReadingLastNarrationTime = 0.0
    if reader != None
        Debug.Trace("[SeverActions_Loot] ReadBook: Clearing reading state for " + reader.GetDisplayName())
        StorageUtil.UnsetIntValue(reader, "SeverActions_ReadingBook")
        StorageUtil.UnsetStringValue(reader, "SeverActions_ReadingBookTitle")
        StorageUtil.UnsetStringValue(reader, "SeverActions_ReadingBookText")
        ResetToDefaultIdle(reader)
    endif
EndFunction

; =============================================================================
; DIARY VIEWER - ENTRY SELECTION
; =============================================================================

Event OnDiaryEntrySelected(string eventName, string strArg, float numArg, Form sender)
{The player picked a diary entry (MagelightDiaryBridge buffers its text natively).
 strArg = NPC name, sender = the reader.}
    Debug.Trace("[SeverActions_Loot] Diary entry selected for '" + strArg + "'")

    String content = SeverActionsNative.Magelight_GetSelectedDiaryContent()
    String title = SeverActionsNative.Magelight_GetSelectedDiaryTitle()

    if content == ""
        Debug.Trace("[SeverActions_Loot] Diary: Empty content - aborting")
        BookReader = None
        return
    endif

    ; BookReader (set at diary detection) first; the sender if it was cleared since.
    Actor reader = BookReader
    if !reader
        reader = sender as Actor
    endif
    if !reader
        Debug.Trace("[SeverActions_Loot] Diary: Could not resolve reader actor")
        return
    endif

    String npcName = reader.GetDisplayName()
    Debug.Trace("[SeverActions_Loot] Diary: Starting reading - '" + title + "' by " + npcName)

    BookReader = reader
    BookReadingStartTime = Utility.GetCurrentRealTime()

    ; Always verbatim (1): the player picked this entry
    StorageUtil.SetIntValue(reader, "SeverActions_ReadingBook", 1)
    StorageUtil.SetStringValue(reader, "SeverActions_ReadingBookTitle", title)
    StorageUtil.SetStringValue(reader, "SeverActions_ReadingBookText", content)

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

    String openNarration = "*" + npcName + " opens their diary to a specific entry and begins reading it aloud.*"
    SkyrimNetApi.DirectNarration(openNarration, reader, None)

    SkyrimNetApi.RegisterPersistentEvent(npcName + " is reading a diary entry aloud.", reader, None)

    BookReadingLastNarrationTime = Utility.GetCurrentRealTime()
    ChronoArm(BookReadingUpdateInterval)
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

Function ChronoArm(Float afSeconds)
    {Arm this script's one-shot chronometer tick (see the Chronometer block in
     SeverActionsNativeExt2.psc): event and callback names unique to this script,
     a re-arm replaces the pending tick, no tick survives a load, and one in-flight
     tick can still land after a clear, so the handler is state-guarded.}
    RegisterForModEvent("SeverActions_Tick_Loot", "OnChronoTick_Loot")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_Loot", afSeconds)
EndFunction

Event OnChronoTick_Loot(String eventName, String strArg, Float numArg, Form sender)
    ; The reading monitor: nudges the reader on whenever the speech queue goes idle
    if BookReader == None
        return
    endif

    ; Summary mode: 2 min timeout, 30 s of silence before a nudge. The session's own
    ; mode (a diary entry is always verbatim, and the setting can change mid-read).
    Bool isSummaryMode = StorageUtil.GetIntValue(BookReader, "SeverActions_ReadingBook", 0) == 2
    Float activeTimeout = BookReadingTimeout
    Float activeContinueDelay = BookReadingContinueDelay
    if isSummaryMode
        activeTimeout = 120.0
        activeContinueDelay = 30.0
    endif

    Float totalElapsed = Utility.GetCurrentRealTime() - BookReadingStartTime
    if totalElapsed > activeTimeout
        Debug.Trace("[SeverActions_Loot] ReadBook: Auto-continue timeout reached, stopping")
        Actor reader = BookReader
        String npcName = reader.GetDisplayName()
        ClearBookReadingState()
        SkyrimNetApi.RegisterEvent("book_reading_stopped", npcName + " finished reading", reader, None)
        return
    endif

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

    ChronoArm(BookReadingUpdateInterval)
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
    {End an idle and hand the actor back to their package. A PlayIdle the graph is not ready for is
     dropped silently, which left looters kneeling, so a standing actor also gets the animation event,
     again once the first has had a moment to land. Not one seated, in bed, mounted or fighting: the
     event stands them up or drops their combat stance.}
    if !akActor
        return
    endif
    if IdleForceDefaultState
        akActor.PlayIdle(IdleForceDefaultState)
    endif
    if akActor.GetSitState() == 0 && akActor.GetSleepState() == 0 && !akActor.IsOnMount() && !akActor.IsInCombat()
        Debug.SendAnimationEvent(akActor, "IdleForceDefaultState")
        Utility.Wait(0.3)
        Debug.SendAnimationEvent(akActor, "IdleForceDefaultState")
    endif
    akActor.EvaluatePackage()
EndFunction

; -----------------------------------------------------------------------------
; Safe-exit stubs (M-I, check 20): removed functions a suspended frame in a save
; may still call (F7). Never remove one; registry fomod/safe_exit_stubs.json.
; -----------------------------------------------------------------------------

Function SetLastLootedItem(Actor akActor, Form akItem, int count)
    {Safe-exit stub for a removed dead function.}
    ; M-I-STUB 3.9.14-beta25 (P3-08): dead code removed by the modular-install audit fix (89ed67cb, 2026-09-13)
EndFunction

; ============================================================================
; M-V VERB DISPATCHER (plan 3.0 M-V, DR10)
; ============================================================================
; Every verb_table.json row dispatched to items arrives as SeverActions_Verb_Items
; with the 8 pipe fields. The ONE script defining OnVerb_Items (F4: a shared
; callback name runs on every script of the form); InitializeDiaryEvents registers it.
Event OnVerb_Items(String eventName, String strArg, Float numArg, Form sender)
    String actionId = SeverActions_ModuleBase.VerbField(strArg, 0)
    String targetName = SeverActions_ModuleBase.VerbField(strArg, 1)
    String target2Name = SeverActions_ModuleBase.VerbField(strArg, 2)
    String strParam = SeverActions_ModuleBase.VerbField(strArg, 3)
    Int intParam = SeverActions_ModuleBase.VerbField(strArg, 4) as Int
    String str2Param = SeverActions_ModuleBase.VerbField(strArg, 5)
    Int targetFid = SeverActions_ModuleBase.VerbField(strArg, 6) as Int
    Int target2Fid = SeverActions_ModuleBase.VerbField(strArg, 7) as Int
    Debug.Trace("[SeverActions_Loot] OnVerb_Items: " + actionId + " target=" + targetName + " target2=" + target2Name \
        + " str=" + strParam + " int=" + intParam + " str2=" + str2Param + " fid=" + targetFid + " fid2=" + target2Fid)

    ; The sender, then the encoded FormID, then the fuzzy name; names are
    ; re-canonicalized to display names for the branches that pass one on.
    Actor target = SeverActions_ModuleBase.VerbActor(sender, targetFid, targetName)
    If !target
        Debug.Trace("[SeverActions_Loot] OnVerb_Items: could not resolve target '" + targetName + "' for " + actionId)
        Return
    EndIf
    targetName = target.GetDisplayName()
    Actor target2 = SeverActions_ModuleBase.VerbActor(None, target2Fid, target2Name)
    If target2
        target2Name = target2.GetDisplayName()
    ElseIf target2Name != ""
        Debug.Trace("[SeverActions_Loot] OnVerb_Items: target2 name '" + target2Name + "' did not resolve to an actor (action=" + actionId + ")")
    EndIf

    ; -- Plunder: the Execute functions apply the owned-item theft contract themselves --
    If actionId == "searchCorpse"
        ; strParam = corpse name - reveal-only, no take.
        SearchCorpse_Execute(target, strParam)

    ElseIf actionId == "searchContainer"
        ; strParam = container name - reveal-only, no take.
        SearchContainer_Execute(target, strParam)

    ElseIf actionId == "lootCorpse"
        ; strParam = corpse name; str2Param ('detail') = items to take.
        String corpseTake = str2Param
        If corpseTake == ""
            corpseTake = "everything"
        EndIf
        LootCorpse_Execute(target, strParam, corpseTake)

    ElseIf actionId == "lootContainer"
        String contTake = str2Param
        If contTake == ""
            contTake = "everything"
        EndIf
        LootContainer_Execute(target, strParam, contTake)

    ElseIf actionId == "pickUpItem"
        PickUpItem_Execute(target, strParam)

    ElseIf actionId == "bringItem"
        ; target2 = the recipient (required by the page).
        If target2
            BringItem_Execute(target, target2, strParam)
        EndIf

    ElseIf actionId == "giveItem"
        ; target = giver, target2 = receiver, strParam = item name, intParam =
        ; count (the Actions page's Count field; 0 = field left blank = 1).
        If target2
            Int giveCount = intParam
            If giveCount < 1
                giveCount = 1
            EndIf
            GiveItem_Execute(target, target2, strParam, giveCount)
        EndIf

    ElseIf actionId == "takeItemFromPlayer"
        ; target = NPC taking, strParam = item name, intParam = count
        Int takeCount = intParam
        If takeCount < 1
            takeCount = 1
        EndIf
        TakeItemFromPlayer_Execute(target, strParam, takeCount)

    ElseIf actionId == "readAloud"
        ReadBook_Execute(target, strParam)

    ElseIf actionId == "stopReading"
        StopReading_Execute(target)

    ; -- Magic and property (the items module's sibling scripts, A7) --
    ElseIf actionId == "teachSpell"
        SeverActions_SpellTeach teachSys = (Self as Quest) as SeverActions_SpellTeach
        If teachSys
            teachSys.TeachSpell(target, strParam)
        EndIf

    ElseIf actionId == "learnSpell"
        SeverActions_SpellTeach learnSys = (Self as Quest) as SeverActions_SpellTeach
        If learnSys
            learnSys.LearnSpell(target, strParam)
        EndIf

    ElseIf actionId == "castSpell"
        ; target = caster (Subject), strParam = spell name, target2 = optional
        ; target NPC (empty/"0" = aimed cast in front of caster)
        SeverActions_SpellCast castSys = (Self as Quest) as SeverActions_SpellCast
        If castSys
            String castTargetName = target2Name
            If castTargetName == ""
                castTargetName = "0"
            EndIf
            castSys.CastSpell_Execute(target, strParam, castTargetName, false, true, true)
        EndIf

    ElseIf actionId == "transferOwnership"
        ; target = NPC giving away ownership (speaker); strParam = property
        ; name (blank = use actor's current location)
        SeverActions_Property propSys = (Self as Quest) as SeverActions_Property
        If propSys
            propSys.TransferOwnership(target, strParam)
        EndIf

    ; -- The ambient director's two item actions (SeverActions_Ambient) --
    ElseIf actionId == "takeItem"
        ; target = the taker, target2 = who holds the item, strParam = item name,
        ; intParam = count (0 = 1).
        If target2
            Int takeAmbientCount = intParam
            If takeAmbientCount < 1
                takeAmbientCount = 1
            EndIf
            TakeItem_Execute(target, target2, strParam, takeAmbientCount)
        EndIf

    ElseIf actionId == "useItem"
        ; target = the user, strParam = the item in their own pack.
        UseItem_Execute(target, strParam)

    Else
        Debug.Trace("[SeverActions_Loot] OnVerb_Items: unknown actionId '" + actionId + "' (not a row this dispatcher carries)")
    EndIf

    ; Refresh once the verb has run: the DLL's own refresh fires one frame after
    ; routing, before this stack has changed the stores.
    SeverActionsNative.Magelight_RefreshPage("world")
    SeverActionsNative.Magelight_RefreshPage("enterprises")
EndEvent
