Scriptname SeverActions_Currency extends Quest
{Currency/gold action handlers for SkyrimNet integration - by Severause}

; =============================================================================
; PROPERTIES
; =============================================================================

MiscObject Property Gold001 Auto
{Gold coin - set to Gold001 (0x0000000F) in CK, or leave empty for auto-lookup}

Idle Property IdleGive Auto
{Animation for giving gold}

Idle Property IdleTake Auto
{Animation for taking/receiving gold}

Idle Property IdleThreaten Auto
{Animation for threatening/demanding (optional)}

Sound Property GoldSound Auto
{Sound effect for gold transactions}

Bool Property UseGiveAnimation = True Auto
Bool Property UseTakeAnimation = True Auto
Bool Property UseThreatenAnimation = True Auto
Bool Property UseGoldSound = True Auto
Float Property AnimDelay = 0.6 Auto

; Conjured Gold - allows NPCs to give gold they don't have
Bool Property AllowConjuredGold = True Auto

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    Debug.Trace("[SeverActions_Currency] Initialized")
    Maintenance()
EndEvent

Function Maintenance()
    if Gold001 == None
        Gold001 = Game.GetFormFromFile(0x0000000F, "Skyrim.esm") as MiscObject
        if Gold001 == None
            Debug.Trace("[SeverActions_Currency] ERROR: Could not find Gold001!")
        else
            Debug.Trace("[SeverActions_Currency] Gold001 found via auto-lookup")
        endif
    endif

    ; CollectPayment now prefers a non-pausing PrismaUI overlay over
    ; SkyMessage when PrismaUI is available; the bridge posts the player's
    ; choice back via SeverActions_CollectPaymentChoice. Register on every
    ; Maintenance pass — RegisterForModEvent is idempotent and the script
    ; instance can lose its registration across save/load on edge cases.
    RegisterForModEvent("SeverActions_CollectPaymentChoice", "OnCollectPaymentChoice")
EndFunction

; =============================================================================
; HELPER FUNCTIONS
; =============================================================================

Function PlayGiveAnimation(Actor akActor)
    if akActor && UseGiveAnimation && IdleGive
        akActor.PlayIdle(IdleGive)
        Utility.Wait(AnimDelay)
    endif
EndFunction

Function PlayTakeAnimation(Actor akActor)
    if akActor && UseTakeAnimation && IdleTake
        akActor.PlayIdle(IdleTake)
        Utility.Wait(AnimDelay)
    endif
EndFunction

Function PlayThreatenAnimation(Actor akActor)
    if akActor && UseThreatenAnimation && IdleThreaten
        akActor.PlayIdle(IdleThreaten)
        Utility.Wait(AnimDelay)
    endif
EndFunction

Function PlayGoldSound(Actor akActor)
    if akActor && UseGoldSound && GoldSound
        GoldSound.Play(akActor)
    endif
EndFunction

; =============================================================================
; HELPER: _LogToLedger — Ledger expansion Phase 2 (gold-flow ingest)
; =============================================================================
; Invoked from each currency action's success path. Only logs when the
; player is one of the two parties — NPC↔NPC transactions are atmospheric
; and don't belong in the player's ledger. Direction follows the player's
; gold flow (True = gold flowed away from player). Native_Ledger_RecordEvent
; itself drops empty source / non-positive amount, so the inner guards
; there protect against malformed calls.

Function _LogToLedger(Actor akSender, Actor akReceiver, Int aiAmount, String asSource, String asReason = "")
    If aiAmount <= 0 || !akSender || !akReceiver
        Return
    EndIf
    Actor player = Game.GetPlayer()
    If akSender == player
        SeverActionsNativeExt.Native_Ledger_RecordEvent(aiAmount, True,  asSource, akReceiver, "", asReason, 0)
    ElseIf akReceiver == player
        SeverActionsNativeExt.Native_Ledger_RecordEvent(aiAmount, False, asSource, akSender,   "", asReason, 0)
    EndIf
EndFunction

Int Function TransferGold(Actor akFrom, Actor akTo, Int aiAmount, Bool abAllowConjure = False)
    if !akFrom || !akTo || aiAmount <= 0 || !Gold001
        return 0
    endif
    if akFrom.IsDead() || akTo.IsDead()
        return 0
    endif

    Int available = akFrom.GetItemCount(Gold001)
    Int moved = aiAmount
    
    if abAllowConjure && AllowConjuredGold
        akTo.AddItem(Gold001, moved, False)
        PlayGoldSound(akTo)
        return moved
    endif
    
    if moved > available
        moved = available
    endif
    if moved <= 0
        return 0
    endif

    akFrom.RemoveItem(Gold001, moved, False, akTo)
    PlayGoldSound(akTo)
    return moved
EndFunction

; =============================================================================
; ACTION: GiveGold - NPC voluntarily gives gold to another actor
; Use for: gifts, tips, charity, rewards, generosity
; =============================================================================

Bool Function GiveGold_IsEligible(Actor akGiver, Actor akRecipient, Int aiAmount)
    if !akGiver || !akRecipient || aiAmount <= 0 || !Gold001
        return False
    endif
    if akGiver == akRecipient
        return False
    endif
    if akGiver.IsDead() || akRecipient.IsDead()
        return False
    endif
    
    if AllowConjuredGold
        return True
    endif
    
    return (akGiver.GetItemCount(Gold001) >= aiAmount)
EndFunction

Function GiveGold_Execute(Actor akGiver, Actor akRecipient, Int aiAmount)
    if !akGiver || !akRecipient || !Gold001
        return
    endif
    
    Debug.Trace("[SeverActions_Currency] GiveGold: " + akGiver.GetDisplayName() + " giving " + aiAmount + " gold to " + akRecipient.GetDisplayName())
    
    PlayGiveAnimation(akGiver)
    Int moved = TransferGold(akGiver, akRecipient, aiAmount, True)
    
    if moved > 0
        SkyrimNetApi.RegisterEvent("gold_given", akGiver.GetDisplayName() + " gave " + moved + " gold to " + akRecipient.GetDisplayName(), akGiver, akRecipient)
        _LogToLedger(akGiver, akRecipient, moved, "give_gold")
        ; Auto-reduce debt if giver owes recipient
        SeverActions_Debt debtScript = SeverActions_Debt.GetInstance()
        if debtScript
            debtScript.ReduceDebtByPayment(akRecipient, akGiver, moved)
        endif
    else
        SkyrimNetApi.RegisterEvent("gold_failed", akGiver.GetDisplayName() + " has no gold to give", akGiver, akRecipient)
    endif
EndFunction

; =============================================================================
; ACTION: CollectPayment - NPC receives gold owed to them
; Use for: receiving payment after sales, services, trades, settling debts
; The PAYER (target) gives gold to the COLLECTOR (actor)
; If payer is the player, shows a confirmation popup
; =============================================================================

Bool Function CollectPayment_IsEligible(Actor akCollector, Actor akPayer, Int aiAmount)
    if !akCollector || !akPayer || aiAmount <= 0 || !Gold001
        return False
    endif
    if akCollector == akPayer
        return False
    endif
    if akCollector.IsDead() || akPayer.IsDead()
        return False
    endif
    
    ; Payer needs to have gold
    return (akPayer.GetItemCount(Gold001) > 0)
EndFunction

Function CollectPayment_Execute(Actor akCollector, Actor akPayer, Int aiAmount)
    if !akCollector || !akPayer || !Gold001
        return
    endif

    ; Lazy ModEvent registration. Maintenance() only fires from OnInit on
    ; fresh install — players updating from a save that predates the
    ; CollectPaymentChoice handler would otherwise never bind it, and the
    ; bridge's ModEvent would fall on the floor (silent "Pay" click).
    ; RegisterForModEvent is deduped by SKSE so calling on every dispatch
    ; is cheap; the registration then persists across save/load.
    RegisterForModEvent("SeverActions_CollectPaymentChoice", "OnCollectPaymentChoice")

    Debug.Trace("[SeverActions_Currency] CollectPayment: " + akCollector.GetDisplayName() + " collecting " + aiAmount + " gold from " + akPayer.GetDisplayName())
    
    ; If payer is the player, prefer the non-pausing PrismaUI overlay
    ; over SkyMessage. The bridge posts the choice back via
    ; SeverActions_CollectPaymentChoice (handled by OnCollectPaymentChoice
    ; below). When PrismaUI isn't available OR another prompt is in flight,
    ; fall through to the legacy SkyMessage modal so the action still works
    ; out-of-the-box for users without PrismaUI installed.
    Actor player = Game.GetPlayer()
    if akPayer == player
        String collectorName = akCollector.GetDisplayName()

        if SeverActionsNative.PrismaUI_IsPaymentPromptAvailable() && \
           !SeverActionsNative.PrismaUI_IsPaymentPromptOpen()
            if SeverActionsNative.PrismaUI_OpenPaymentPrompt(akCollector, aiAmount, collectorName, 20000)
                ; Choice arrives asynchronously via OnCollectPaymentChoice.
                return
            endif
        endif

        ; Legacy / fallback path — modal SkyMessage. Same three-option UX.
        _CollectPaymentPlayerModal(akCollector, aiAmount, collectorName)
        return
    endif

    ; Non-player payer - proceed as normal
    PlayTakeAnimation(akCollector)
    Int moved = TransferGold(akPayer, akCollector, aiAmount, False)

    if moved > 0
        if moved < aiAmount
            SkyrimNetApi.RegisterEvent("payment_collected", akCollector.GetDisplayName() + " collected " + moved + " gold from " + akPayer.GetDisplayName() + " (partial payment)", akCollector, akPayer)
        else
            SkyrimNetApi.RegisterEvent("payment_collected", akCollector.GetDisplayName() + " collected " + moved + " gold from " + akPayer.GetDisplayName(), akCollector, akPayer)
        endif
        _LogToLedger(akPayer, akCollector, moved, "collect_payment")
        ; Auto-reduce debt if payer owes collector
        SeverActions_Debt debtScript = SeverActions_Debt.GetInstance()
        if debtScript
            debtScript.ReduceDebtByPayment(akCollector, akPayer, moved)
        endif
    else
        SkyrimNetApi.RegisterEvent("payment_failed", akPayer.GetDisplayName() + " has no gold to pay", akCollector, akPayer)
    endif
EndFunction

; =============================================================================
; CollectPayment — choice dispatch
; -----------------------------------------------------------------------------
; Shared by both prompt paths (PrismaUI overlay → OnCollectPaymentChoice;
; legacy modal → _CollectPaymentPlayerModal) so the transaction/narration/
; ledger/debt logic lives in exactly one place. The choice strings match
; the JS payload from PromptPanel ("accept" / "deny" / "denySilent").
; =============================================================================

Function _ApplyCollectPaymentChoice(Actor akCollector, Actor akPayer, Int aiAmount, String asChoice, String asCollectorName)
    if asChoice == "accept"
        PlayTakeAnimation(akCollector)
        Int moved = TransferGold(akPayer, akCollector, aiAmount, False)

        if moved > 0
            if moved < aiAmount
                SkyrimNetApi.RegisterEvent("payment_collected", asCollectorName + " collected " + moved + " gold from " + akPayer.GetDisplayName() + " (partial payment)", akCollector, akPayer)
            else
                SkyrimNetApi.RegisterEvent("payment_collected", asCollectorName + " collected " + moved + " gold from " + akPayer.GetDisplayName(), akCollector, akPayer)
            endif
            _LogToLedger(akPayer, akCollector, moved, "collect_payment")
            SeverActions_Debt debtScript = SeverActions_Debt.GetInstance()
            if debtScript
                debtScript.ReduceDebtByPayment(akCollector, akPayer, moved)
            endif
        else
            SkyrimNetApi.RegisterEvent("payment_failed", akPayer.GetDisplayName() + " has no gold to pay", akCollector, akPayer)
        endif

    elseif asChoice == "deny"
        ; Player refuses — narrate so NPC reacts.
        SkyrimNetApi.DirectNarration(akPayer.GetDisplayName() + " refused to pay " + asCollectorName, akCollector)

    elseif asChoice == "denySilent"
        ; Silent decline — no event, no narration. Matches legacy "No (Silent)".
        Debug.Trace("[SeverActions_Currency] CollectPayment: Player silently declined payment to " + asCollectorName)

    else
        Debug.Trace("[SeverActions_Currency] CollectPayment: unknown choice '" + asChoice + "'")
    endif
EndFunction

; Legacy modal path — used when PrismaUI is unavailable or another prompt
; is already open. Preserves the exact original UX so users without
; PrismaUI installed (or anyone hitting the fallback for any reason) see
; the same three-option SkyMessage they always did.
Function _CollectPaymentPlayerModal(Actor akCollector, Int aiAmount, String asCollectorName)
    String promptText = asCollectorName + " is requesting " + aiAmount + " gold. Pay them?"
    String result = SkyMessage.Show(promptText, "Yes", "No", "No (Silent)")

    String choice = "denySilent"
    if result == "Yes"
        choice = "accept"
    elseif result == "No"
        choice = "deny"
    endif

    _ApplyCollectPaymentChoice(akCollector, Game.GetPlayer(), aiAmount, choice, asCollectorName)
EndFunction

; ModEvent handler — fired by PrismaUICollectPaymentBridge when the player
; clicks a button or the auto-accept timer expires. strArg carries the
; choice ("accept" / "deny" / "denySilent"); numArg carries the original
; amount (round-tripped from the bridge so we don't depend on cached
; script state); sender is the collector actor.
Event OnCollectPaymentChoice(String asEventName, String asChoice, Float afAmount, Form akSender)
    Actor akCollector = akSender as Actor
    if !akCollector
        Debug.Trace("[SeverActions_Currency] OnCollectPaymentChoice: sender is not an Actor — ignoring")
        return
    endif

    Int aiAmount = afAmount as Int
    if aiAmount <= 0
        Debug.Trace("[SeverActions_Currency] OnCollectPaymentChoice: invalid amount " + afAmount + " — ignoring")
        return
    endif

    _ApplyCollectPaymentChoice(akCollector, Game.GetPlayer(), aiAmount, asChoice, akCollector.GetDisplayName())
EndEvent

; =============================================================================
; ACTION: ExtortGold - NPC forcibly takes gold through intimidation/threats
; Use for: robbery, mugging, demanding tribute, protection money, coercion
; =============================================================================

Bool Function ExtortGold_IsEligible(Actor akExtorter, Actor akVictim, Int aiAmount)
    if !akExtorter || !akVictim || aiAmount <= 0 || !Gold001
        return False
    endif
    if akExtorter == akVictim
        return False
    endif
    if akExtorter.IsDead() || akVictim.IsDead()
        return False
    endif
    
    ; Victim needs to have gold to extort
    return (akVictim.GetItemCount(Gold001) > 0)
EndFunction

Function ExtortGold_Execute(Actor akExtorter, Actor akVictim, Int aiAmount)
    if !akExtorter || !akVictim || !Gold001
        return
    endif
    
    Debug.Trace("[SeverActions_Currency] ExtortGold: " + akExtorter.GetDisplayName() + " extorting " + aiAmount + " gold from " + akVictim.GetDisplayName())
    
    ; Threaten first, then take
    PlayThreatenAnimation(akExtorter)
    PlayTakeAnimation(akExtorter)
    Int moved = TransferGold(akVictim, akExtorter, aiAmount, False)
    
    if moved > 0
        if moved < aiAmount
            SkyrimNetApi.RegisterEvent("gold_extorted", akExtorter.GetDisplayName() + " extorted " + moved + " gold from " + akVictim.GetDisplayName() + " (all they had)", akExtorter, akVictim)
        else
            SkyrimNetApi.RegisterEvent("gold_extorted", akExtorter.GetDisplayName() + " extorted " + moved + " gold from " + akVictim.GetDisplayName(), akExtorter, akVictim)
        endif
        _LogToLedger(akVictim, akExtorter, moved, "extort_gold")
    else
        SkyrimNetApi.RegisterEvent("extortion_failed", akVictim.GetDisplayName() + " has no gold to take", akExtorter, akVictim)
    endif
EndFunction

; =============================================================================
; ACTIONS: BuyItem / SellItem - atomic item-for-gold transactions
;
; Patches the UX gap where the LLM would fire GiveGold but then need a second
; prompt to fire GiveItem (or vice versa), leaving the player with the gold
; gone but no goods (or the reverse). BuyItem / SellItem package both halves
; into a single action call.
;
; BuyItem  — the SPEAKER is the buyer (pays gold, receives item).
; SellItem — the SPEAKER is the seller (gives item, receives gold).
;
; Both delegate to the same internal _DoItemTransaction so the actual logic
; lives in one place. Deliberately does NOT call SeverActions_Debt — a
; purchase is not the same as settling an outstanding tab, even if one
; happens to exist between these two actors. Use CollectPayment / GiveGold
; explicitly when you want to interact with the debt ledger.
; =============================================================================

SeverActions_Loot Function _GetLootScript()
    Return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Loot
EndFunction

Bool Function BuyItem_IsEligible(Actor akBuyer, Actor akSeller, String asItemName, Int aiQuantity, Int aiTotalGold)
    Return _Transaction_IsEligible(akSeller, akBuyer, asItemName, aiQuantity, aiTotalGold)
EndFunction

Function BuyItem_Execute(Actor akBuyer, Actor akSeller, String asItemName, Int aiQuantity, Int aiTotalGold)
    _DoItemTransaction(akSeller, akBuyer, asItemName, aiQuantity, aiTotalGold)
EndFunction

Bool Function SellItem_IsEligible(Actor akSeller, Actor akBuyer, String asItemName, Int aiQuantity, Int aiTotalGold)
    Return _Transaction_IsEligible(akSeller, akBuyer, asItemName, aiQuantity, aiTotalGold)
EndFunction

Function SellItem_Execute(Actor akSeller, Actor akBuyer, String asItemName, Int aiQuantity, Int aiTotalGold)
    _DoItemTransaction(akSeller, akBuyer, asItemName, aiQuantity, aiTotalGold)
EndFunction

Bool Function _Transaction_IsEligible(Actor akSeller, Actor akBuyer, String asItemName, Int aiQuantity, Int aiTotalGold)
    {Shared eligibility — same checks regardless of which side is the speaker.}
    If !akSeller || !akBuyer || asItemName == "" || aiQuantity < 1 || aiTotalGold < 0
        Return False
    EndIf
    If akSeller == akBuyer
        Return False
    EndIf
    If akSeller.IsDead() || akBuyer.IsDead()
        Return False
    EndIf
    If !Gold001
        Return False
    EndIf
    ; PR #103 review fix: buyer ALWAYS pays from real coin. AllowConjuredGold
    ; is intended for NPC realism (so a beggar can make change), but applying
    ; it to the BUYER side of a purchase means a player-buyer with 0 gold
    ; could BuyItem for free — the conjure path in TransferGold just AddItems
    ; to the seller without debiting the buyer. Hard-require real gold here.
    If akBuyer.GetItemCount(Gold001) < aiTotalGold
        Return False
    EndIf
    Return True
EndFunction

Function _DoItemTransaction(Actor akSeller, Actor akBuyer, String asItemName, Int aiQuantity, Int aiTotalGold)
    {Atomic item-for-gold transaction. Resolves the item, pre-checks stock + gold,
     walks the seller to the buyer, swaps the items + the gold, then fires a
     single item_purchased event. On any failure path, fires item_purchase_failed
     with a reason string and returns without mutating either inventory.}

    If !_Transaction_IsEligible(akSeller, akBuyer, asItemName, aiQuantity, aiTotalGold)
        ; Null-guard: when eligibility fails because an actor is None, don't
        ; build a malformed " could not buy X from " event — just log.
        If !akSeller || !akBuyer
            Debug.Trace("[SeverActions_Currency] _DoItemTransaction: missing actor — skipping")
            Return
        EndIf
        SkyrimNetApi.RegisterEvent("item_purchase_failed", \
            akBuyer.GetDisplayName() + " could not complete the purchase of " + asItemName + " from " + akSeller.GetDisplayName() + " (invalid parameters or insufficient gold)", \
            akSeller, akBuyer)
        Return
    EndIf

    SeverActions_Loot lootSys = _GetLootScript()
    If !lootSys
        Debug.Trace("[SeverActions_Currency] BuyItem/SellItem: SeverActions_Loot quest unavailable")
        Return
    EndIf

    ; Resolve the item (personal inventory or merchant chest).
    Form itemForm = SeverActions_Loot.ResolveItemForTransaction(akSeller, asItemName)
    If !itemForm
        SkyrimNetApi.RegisterEvent("item_purchase_failed", \
            akSeller.GetDisplayName() + " doesn't have any " + asItemName + " to sell to " + akBuyer.GetDisplayName(), \
            akSeller, akBuyer)
        Return
    EndIf

    ; Pre-check stock so we don't walk the seller and play the give animation
    ; just to discover they only had 1 of the 5 requested.
    Int available = SeverActions_Loot.GetTransactionAvailableQty(akSeller, itemForm)
    If available < aiQuantity
        SkyrimNetApi.RegisterEvent("item_purchase_failed", \
            akSeller.GetDisplayName() + " only has " + available + " " + itemForm.GetName() + " — not enough for " + akBuyer.GetDisplayName() + "'s " + aiQuantity, \
            akSeller, akBuyer)
        Return
    EndIf

    ; PR #103 review fix: gold-first ordering. The item transfer involves a
    ; walk + animation (up to ~15s) where a save/load/crash/cell-unload could
    ; orphan the gold half if we did it last. Move the gold first (instant);
    ; if the subsequent item transfer fails, refund the gold. Worst case is
    ; one fallible step (refund) instead of two with no rollback.
    Int paid = TransferGold(akBuyer, akSeller, aiTotalGold, False)
    If paid != aiTotalGold
        ; Eligibility already verified the buyer has the gold, so a partial
        ; transfer here means something raced us between the check and the
        ; move. Bail without firing the item half.
        SkyrimNetApi.RegisterEvent("item_purchase_failed", \
            akBuyer.GetDisplayName() + " could not finish paying " + akSeller.GetDisplayName() + " for " + asItemName + " (only " + paid + " of " + aiTotalGold + " gold moved)", \
            akSeller, akBuyer)
        Return
    EndIf

    ; Item half. TransferItemForTransaction handles the walk + animation + the
    ; personal-vs-merchant-chest source selection.
    Int transferred = lootSys.TransferItemForTransaction(akSeller, akBuyer, itemForm, aiQuantity)
    If transferred <= 0
        ; Refund the gold the buyer just paid. Seller has at least aiTotalGold
        ; right now (we just gave it to them), so this transfer is safe.
        TransferGold(akSeller, akBuyer, aiTotalGold, False)
        SkyrimNetApi.RegisterEvent("item_purchase_failed", \
            akSeller.GetDisplayName() + " could not hand over " + asItemName + " to " + akBuyer.GetDisplayName() + " — " + aiTotalGold + " gold refunded", \
            akSeller, akBuyer)
        Return
    EndIf

    ; PR #175 review fix (M3): a race between the stock pre-check and the
    ; transfer can leave `transferred` short of aiQuantity (the items already
    ; moved to the buyer, so we don't claw them back). Refund the unfilled
    ; remainder pro-rata so the buyer is charged only for what they received,
    ; never the full price for partial goods. Full transfers keep the exact
    ; agreed total (no rounding drift from the per-unit split).
    Int chargedGold = aiTotalGold
    If transferred < aiQuantity
        Int pricePerUnit = aiTotalGold / aiQuantity
        Int refund = aiTotalGold - (pricePerUnit * transferred)
        If refund > 0
            TransferGold(akSeller, akBuyer, refund, False)
            chargedGold = aiTotalGold - refund
        EndIf
    EndIf

    ; Build the unified transaction event.
    String itemLabel = itemForm.GetName()
    If transferred > 1
        itemLabel = transferred + " " + itemLabel
    EndIf
    String eventMsg = akBuyer.GetDisplayName() + " bought " + itemLabel + " from " + akSeller.GetDisplayName() + " for " + chargedGold + " gold"
    SkyrimNetApi.RegisterEvent("item_purchased", eventMsg, akSeller, akBuyer)

    ; Ledger: source key depends on which side the player is on. _LogToLedger
    ; only fires when the player is involved; for NPC↔NPC item swaps it
    ; silently no-ops. The item label rides along as the row's `reason`
    ; so the recent-transactions view can show "bought 3 Iron Ingot".
    Actor player = Game.GetPlayer()
    String src = "buy_item"   ; default when neither side is player (no-op anyway)
    If akSeller == player
        src = "sell_item"
    EndIf
    _LogToLedger(akBuyer, akSeller, chargedGold, src, itemLabel)
EndFunction