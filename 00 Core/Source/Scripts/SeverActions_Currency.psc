Scriptname SeverActions_Currency extends Quest
{Economy module: the gold and item-trade actions, the player's payment/trade prompts, and the
 economy verb dispatcher (OnVerb_Economy) - by Severause}

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

; Conjured gold (NPCs may give gold they don't carry). Legacy host of the Settings Authority
; row allowConjuredGold, read once by its migration; every read goes through Settings_GetBool.
; The False default only seeds a fresh save; an older save may hold True and keeps it.
Bool Property AllowConjuredGold = False Auto

; ===== INITIALIZATION =====

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

    ; Maintenance is the economy load function (OnInit, and the economy provider's stage 1 on
    ; every load and new game), so both registrations are re-made on every load (DR16).
    ; The Magelight payment prompt posts the player's choice here.
    RegisterForModEvent("SeverActions_CollectPaymentChoice", "OnCollectPaymentChoice")
    ; Currency, trade, crafting and debt verbs (M-V); the enterprises verbs run natively.
    RegisterForModEvent("SeverActions_Verb_Economy", "OnVerb_Economy")
EndFunction

Function OnGameLoaded()
    {Safe-exit forwarder to Maintenance for an older provider pex. The Final Audit half moved
     to SeverActions_Enterprises.Maintenance (P9-02).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): the Final Audit half moved to SeverActions_Enterprises; forwards to Maintenance
    Maintenance()
EndFunction

Function ApplyFinalAuditCourtPackage()
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
EndFunction

Int Function FinalAuditEscortSize() Global
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return 0
EndFunction

Int Function FinalAuditGarrisonFirst() Global
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return 0
EndFunction

Int Function FinalAuditGarrisonLast() Global
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return 0
EndFunction

Function PostFinalAuditGarrisons()
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
EndFunction

Function EnsureFinalAuditEscort()
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
EndFunction

Function SetFinalAuditEscortSandbox(Bool abSandbox)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
EndFunction

Function ApplyFinalAuditApproachPackages()
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
EndFunction

Function StandDownFinalAudit()
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
EndFunction

Function DisbandFinalAudit()
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
EndFunction

; ===== HELPERS =====

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

; Records a currency action's gold in the player's ledger, only when the player is a party
; (NPC-to-NPC trades stay out). isOut follows the player's gold: True = it left the player.
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

; Moves up to aiAmount of akFrom's gold to akTo and returns what moved. With abAllowConjure and
; allowConjuredGold on, it mints the whole sum for akTo WITHOUT debiting akFrom.
Int Function TransferGold(Actor akFrom, Actor akTo, Int aiAmount, Bool abAllowConjure = False)
    if !akFrom || !akTo || aiAmount <= 0 || !Gold001
        return 0
    endif
    if akFrom.IsDead() || akTo.IsDead()
        return 0
    endif

    Int available = akFrom.GetItemCount(Gold001)
    Int moved = aiAmount
    
    if abAllowConjure && SeverActionsNativeExt2.Settings_GetBool("allowConjuredGold")
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
    
    if SeverActionsNativeExt2.Settings_GetBool("allowConjuredGold")
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
; ACTION: RepayDebt - the DEBTOR pays back what they owe (CollectPayment is the
; creditor-initiated twin). The amount is clamped to the sum owed so a
; hallucinated figure can't overpay; 0 or omitted pays everything owed.
; =============================================================================

Function RepayDebt_Execute(Actor akDebtor, Actor akCreditor, Int aiAmount)
    if !akDebtor || !akCreditor || !Gold001
        return
    endif
    if akDebtor == akCreditor
        return
    endif

    Int owed = SeverActionsNativeExt.Native_Debt_SumOwed(akCreditor, akDebtor)
    if owed <= 0
        SkyrimNetApi.RegisterEvent("repay_debt_failed", akDebtor.GetDisplayName() + " owes " + akCreditor.GetDisplayName() + " nothing", akDebtor, akCreditor)
        return
    endif

    if aiAmount <= 0 || aiAmount > owed
        aiAmount = owed
    endif

    Debug.Trace("[SeverActions_Currency] RepayDebt: " + akDebtor.GetDisplayName() + " paying " + aiAmount + " of " + owed + " gold owed to " + akCreditor.GetDisplayName())

    PlayGiveAnimation(akDebtor)
    ; Conjure allowed, as for GiveGold (with allowConjuredGold on, the sum is minted; see TransferGold).
    Int moved = TransferGold(akDebtor, akCreditor, aiAmount, True)

    if moved > 0
        SkyrimNetApi.RegisterEvent("debt_repaid", akDebtor.GetDisplayName() + " paid " + moved + " gold toward their debt to " + akCreditor.GetDisplayName(), akDebtor, akCreditor)
        _LogToLedger(akDebtor, akCreditor, moved, "repay_debt")
        SeverActions_Debt debtScript = SeverActions_Debt.GetInstance()
        if debtScript
            debtScript.ReduceDebtByPayment(akCreditor, akDebtor, moved)
        endif
    else
        SkyrimNetApi.RegisterEvent("repay_debt_failed", akDebtor.GetDisplayName() + " has no gold to pay with", akDebtor, akCreditor)
    endif
EndFunction

; =============================================================================
; ACTION: CollectPayment - the COLLECTOR (speaker) receives gold owed by the PAYER
; Use for: payment after sales, services, trades, settling debts
; A player payer gets a confirmation prompt first.
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

    return (akPayer.GetItemCount(Gold001) > 0)
EndFunction

Function CollectPayment_Execute(Actor akCollector, Actor akPayer, Int aiAmount)
    if !akCollector || !akPayer || !Gold001
        return
    endif

    ; Final Audit: the LLM uses CollectPayment for the tax collector's demand, so route it to
    ; the assessment. aiAmount is ignored: the sum (40% of the purse) was fixed when the case
    ; opened and is not negotiable. Module_IsUsable first: without Enterprises (Modular) the
    ; collector test still reads the cosaved audit refs, and an unbound CallBool would
    ; swallow the payment.
    if SeverActionsNativeExt2.Module_IsUsable("enterprises") && \
       SeverActionsNativeExt2.Venture_Audit_IsCollector(akCollector) && \
       SeverActionsNativeExt2.Venture_Audit_State() == "demanding" && \
       akPayer == Game.GetPlayer()
        Debug.Trace("[SeverActions_Currency] CollectPayment on a Final Audit collector -> routing to the assessment (LLM asked for " + aiAmount + ")")
        ; The enterprises provider's service: SeverActions_Enterprises.CollectAuthorizedTaxes.
        SeverActions_ModuleBase.CallBool("enterprises", "collectAuthorizedTaxes", akCollector)
        return
    endif

    ; Belt over Maintenance's registration (SKSE dedups it): without the handler the
    ; prompt's choice is dropped silently.
    RegisterForModEvent("SeverActions_CollectPaymentChoice", "OnCollectPaymentChoice")

    Debug.Trace("[SeverActions_Currency] CollectPayment: " + akCollector.GetDisplayName() + " collecting " + aiAmount + " gold from " + akPayer.GetDisplayName())
    
    ; A player payer gets the non-pausing Magelight prompt (its choice arrives in
    ; OnCollectPaymentChoice), or the SkyMessage modal when it is unavailable or already open.
    Actor player = Game.GetPlayer()
    if akPayer == player
        String collectorName = akCollector.GetDisplayName()

        if SeverActionsNative.Magelight_IsPaymentPromptAvailable() && \
           !SeverActionsNative.Magelight_IsPaymentPromptOpen()
            if SeverActionsNative.Magelight_OpenPaymentPrompt(akCollector, aiAmount, collectorName, 20000)
                ; Choice arrives asynchronously via OnCollectPaymentChoice.
                return
            endif
        endif

        _CollectPaymentPlayerModal(akCollector, aiAmount, collectorName)
        return
    endif

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

; The player's CollectPayment choice, from both prompt paths (Magelight -> OnCollectPaymentChoice,
; SkyMessage -> _CollectPaymentPlayerModal). asChoice: "accept" / "deny" / "denySilent", the
; strings PromptPanel posts.
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
        ; Narrate so the NPC reacts.
        SkyrimNetApi.DirectNarration(akPayer.GetDisplayName() + " refused to pay " + asCollectorName, akCollector)

    elseif asChoice == "denySilent"
        ; No event, no narration.
        Debug.Trace("[SeverActions_Currency] CollectPayment: Player silently declined payment to " + asCollectorName)

    else
        Debug.Trace("[SeverActions_Currency] CollectPayment: unknown choice '" + asChoice + "'")
    endif
EndFunction

; Fallback when the Magelight prompt is unavailable or already open: a SkyMessage modal with the
; same three options. Without SkyMessage the result is empty and the payment silently declined.
Function _CollectPaymentPlayerModal(Actor akCollector, Int aiAmount, String asCollectorName)
    String promptText = asCollectorName + " is requesting " + aiAmount + " gold. Pay them?"
    String result = ""
    If SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
        result = SeverActions_SkyMessageLib.Show(promptText, "Yes", "No", "No (Silent)")
    EndIf
    String choice = "denySilent"
    if result == "Yes"
        choice = "accept"
    elseif result == "No"
        choice = "deny"
    endif

    _ApplyCollectPaymentChoice(akCollector, Game.GetPlayer(), aiAmount, choice, asCollectorName)
EndFunction

; From MagelightCollectPaymentBridge on a click or when its timer auto-accepts. strArg = the
; choice, numArg = the amount (round-tripped, so no pending state is kept), sender = collector.
Event OnCollectPaymentChoice(String asEventName, String asChoice, Float afAmount, Form akSender)
    Actor akCollector = akSender as Actor
    if !akCollector
        Debug.Trace("[SeverActions_Currency] OnCollectPaymentChoice: sender is not an Actor - ignoring")
        return
    endif

    Int aiAmount = afAmount as Int
    if aiAmount <= 0
        Debug.Trace("[SeverActions_Currency] OnCollectPaymentChoice: invalid amount " + afAmount + " - ignoring")
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

    return (akVictim.GetItemCount(Gold001) > 0)
EndFunction

Function ExtortGold_Execute(Actor akExtorter, Actor akVictim, Int aiAmount)
    if !akExtorter || !akVictim || !Gold001
        return
    endif
    
    Debug.Trace("[SeverActions_Currency] ExtortGold: " + akExtorter.GetDisplayName() + " extorting " + aiAmount + " gold from " + akVictim.GetDisplayName())
    
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
; ACTIONS: BuyItem / SellItem - one atomic item-for-gold action, so the gold and
; the goods can't be split across two LLM calls (GiveGold + GiveItem).
; BuyItem: the SPEAKER buys. SellItem: the SPEAKER sells.
; Deliberately never touches SeverActions_Debt: a purchase is not settling a tab.
; =============================================================================

; Transaction helpers: the item half (moved from SeverActions_Loot, which keeps safe-exit
; stubs). Unlike Loot's GiveItem: no debt growth and no item_given event (the caller fires
; item_purchased). The walk is WalkLib's (walklib is in economy's requires closure).

Form Function ResolveItemForTransaction(Actor akSeller, String itemName)
    {Returns the Form for itemName in akSeller's personal inventory, else their merchant
     chest, else None. No side effects.}
    If !akSeller || itemName == ""
        Return None
    EndIf
    Form itemForm = SeverActionsNative.FindItemByName(akSeller, itemName)
    If itemForm && akSeller.GetItemCount(itemForm) > 0
        Return itemForm
    EndIf
    ; The vendor chest, or None (never the actor itself).
    ObjectReference merchantChest = SeverActionsNative.GetMerchantContainer(akSeller)
    If merchantChest
        itemForm = SeverActionsNative.FindItemInContainer(merchantChest, itemName)
        If itemForm && merchantChest.GetItemCount(itemForm) > 0
            Return itemForm
        EndIf
    EndIf
    Return None
EndFunction

Int Function GetTransactionAvailableQty(Actor akSeller, Form akItemForm)
    {How many of akItemForm akSeller can actually sell - the max of their
     personal count and (if any) the merchant chest count, so the caller can
     fail early on insufficient stock before any walk or animation.}
    If !akSeller || !akItemForm
        Return 0
    EndIf
    Int personal = akSeller.GetItemCount(akItemForm)
    Int chest = 0
    ObjectReference merchantChest = SeverActionsNative.GetMerchantContainer(akSeller)
    If merchantChest
        chest = merchantChest.GetItemCount(akItemForm)
    EndIf
    If personal >= chest
        Return personal
    EndIf
    Return chest
EndFunction

Int Function TransferItemForTransaction(Actor akSeller, Actor akBuyer, Form akItemForm, Int aiCount = 1)
    {Walks the seller to the buyer, plays IdleGive, then moves up to aiCount of akItemForm from
     the seller's personal inventory OR merchant chest to the buyer. Returns the count moved
     (0 = none); the caller owns the gold half and the event.}
    If !akSeller || !akBuyer || !akItemForm || aiCount < 1
        Return 0
    EndIf
    If !SeverActions_WalkLib.WalkToReference(akSeller, akBuyer)
        Return 0
    EndIf
    ; Skyrim.esm IdleForceDefaultState, by FormID rather than an ESP-filled property (FID-FORM).
    Idle reset = Game.GetForm(0x00086840) as Idle
    If IdleGive
        If reset
            akSeller.PlayIdle(reset)
            Utility.Wait(0.2)
        EndIf
        akSeller.PlayIdle(IdleGive)
        Utility.Wait(2.0)
    EndIf
    ; The source with the most stock, matching GetTransactionAvailableQty's MAX(personal, chest).
    Int personal = akSeller.GetItemCount(akItemForm)
    Int chest = 0
    ObjectReference merchantChest = SeverActionsNative.GetMerchantContainer(akSeller)
    If merchantChest
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
    If reset
        akSeller.PlayIdle(reset)
    EndIf
    Return transferred
EndFunction

Bool Function BuyItem_IsEligible(Actor akBuyer, Actor akSeller, String asItemName, Int aiQuantity, Int aiTotalGold)
    Return _Transaction_IsEligible(akSeller, akBuyer, asItemName, aiQuantity, aiTotalGold)
EndFunction

Function BuyItem_Execute(Actor akBuyer, Actor akSeller, String asItemName, Int aiQuantity, Int aiTotalGold)
    _BeginItemTransaction(akSeller, akBuyer, asItemName, aiQuantity, aiTotalGold)
EndFunction

Bool Function SellItem_IsEligible(Actor akSeller, Actor akBuyer, String asItemName, Int aiQuantity, Int aiTotalGold)
    Return _Transaction_IsEligible(akSeller, akBuyer, asItemName, aiQuantity, aiTotalGold)
EndFunction

Function SellItem_Execute(Actor akSeller, Actor akBuyer, String asItemName, Int aiQuantity, Int aiTotalGold)
    _BeginItemTransaction(akSeller, akBuyer, asItemName, aiQuantity, aiTotalGold)
EndFunction

; =============================================================================
; Trade confirmation: when the PLAYER is a party, a non-pausing Magelight prompt shows what
; changes hands (Accept / Refuse / Refuse silently); its timer REFUSES, never auto-moving the
; player's gold or goods. NPC-to-NPC trades commit directly. The PendingTrade* slot belongs to
; the one open card; the SkyMessage fallback resolves its own trade from locals.
; =============================================================================

Actor PendingTradeSeller
Actor PendingTradeBuyer
String PendingTradeItem
Int PendingTradeQty
Int PendingTradeGold

Function _BeginItemTransaction(Actor akSeller, Actor akBuyer, String asItemName, Int aiQuantity, Int aiTotalGold)
    ; The LLM sometimes names the speaker as both parties: fail with a correction it can act
    ; on, not the generic failure event.
    If akSeller && akBuyer && akSeller == akBuyer
        SkyrimNetApi.RegisterEvent("item_purchase_failed", \
            akBuyer.GetDisplayName() + " cannot trade with themselves - the buyer and the seller must be two different people (was the other party meant to be " + Game.GetPlayer().GetDisplayName() + "?)", \
            akSeller, akBuyer)
        Return
    EndIf

    Actor player = Game.GetPlayer()
    If akSeller != player && akBuyer != player
        _DoItemTransaction(akSeller, akBuyer, asItemName, aiQuantity, aiTotalGold)
        Return
    EndIf

    ; OnTradeChoice's only registration, made lazily here (SKSE dedups a repeat).
    RegisterForModEvent("SeverActions_TradeChoice", "OnTradeChoice")

    Bool playerBuys = (akBuyer == player)
    Actor counterparty = akSeller
    If !playerBuys
        counterparty = akBuyer
    EndIf
    String counterpartyName = counterparty.GetDisplayName()

    If SeverActionsNativeExt.Magelight_IsTradePromptAvailable() && \
       !SeverActionsNativeExt.Magelight_IsTradePromptOpen()
        ; The slot is written only for the card: a second trade while it is open takes the
        ; fallback below and never overwrites it.
        PendingTradeSeller = akSeller
        PendingTradeBuyer = akBuyer
        PendingTradeItem = asItemName
        PendingTradeQty = aiQuantity
        PendingTradeGold = aiTotalGold
        If SeverActionsNativeExt.Magelight_OpenTradePrompt(counterparty, aiTotalGold, counterpartyName, asItemName, aiQuantity, playerBuys, 20000)
            ; Choice arrives asynchronously via OnTradeChoice.
            Return
        EndIf
    EndIf

    ; Fallback: the SkyMessage modal (no SkyMessage = a silent refusal).
    String qtyStr = ""
    If aiQuantity > 1
        qtyStr = aiQuantity + "x "
    EndIf
    String promptText
    If playerBuys
        promptText = counterpartyName + " offers " + qtyStr + asItemName + " for " + aiTotalGold + " gold. Buy?"
    Else
        promptText = counterpartyName + " offers " + aiTotalGold + " gold for your " + qtyStr + asItemName + ". Sell?"
    EndIf
    String result = ""
    If SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
        result = SeverActions_SkyMessageLib.Show(promptText, "Yes", "No", "No (Silent)")
    EndIf
    String choice = "denySilent"
    If result == "Yes"
        choice = "accept"
    ElseIf result == "No"
        choice = "deny"
    EndIf
    _ResolveTrade(choice, akSeller, akBuyer, asItemName, aiQuantity, aiTotalGold)
EndFunction

Event OnTradeChoice(String asEventName, String asChoice, Float afAmount, Form akSender)
    ; The card's own counterparty and gold must match the slot, or the answer is for a trade
    ; the slot no longer holds (dropped, keeping the slot for its own card).
    Actor counterparty = PendingTradeSeller
    If PendingTradeSeller == Game.GetPlayer()
        counterparty = PendingTradeBuyer
    EndIf
    If !counterparty || (akSender as Actor) != counterparty || (afAmount as Int) != PendingTradeGold
        Debug.Trace("[SeverActions_Currency] Trade choice '" + asChoice + "' does not match the pending trade - dropped")
        Return
    EndIf
    _ApplyTradeChoice(asChoice)
EndEvent

Function _ApplyTradeChoice(String asChoice)
    {The open card's answer: takes the PendingTrade* slot and resolves it.}
    Actor tSeller = PendingTradeSeller
    Actor tBuyer = PendingTradeBuyer
    String tItem = PendingTradeItem
    Int tQty = PendingTradeQty
    Int tGold = PendingTradeGold
    ; Clear FIRST so a re-entrant prompt can't double-commit the same trade.
    PendingTradeSeller = None
    PendingTradeBuyer = None
    PendingTradeItem = ""
    PendingTradeQty = 0
    PendingTradeGold = 0
    _ResolveTrade(asChoice, tSeller, tBuyer, tItem, tQty, tGold)
EndFunction

Function _ResolveTrade(String asChoice, Actor tSeller, Actor tBuyer, String tItem, Int tQty, Int tGold)
    {Commits, refuses aloud or refuses silently one player trade.}
    If !tSeller || !tBuyer
        Return
    EndIf

    If asChoice == "accept"
        _DoItemTransaction(tSeller, tBuyer, tItem, tQty, tGold)
    ElseIf asChoice == "deny"
        ; Narrate so the NPC reacts.
        Actor player = Game.GetPlayer()
        Actor counterparty = tSeller
        If tSeller == player
            counterparty = tBuyer
        EndIf
        SkyrimNetApi.DirectNarration(player.GetDisplayName() + " declined the trade of " + tItem + " with " + counterparty.GetDisplayName(), counterparty)
    EndIf
    ; denySilent / dismiss - nothing happens, nothing is said.
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
    ; The player buyer always pays real coin (conjuring would make the purchase free). An NPC
    ; buyer may come up short when allowConjuredGold is on: _DoItemTransaction mints the shortfall.
    If akBuyer == Game.GetPlayer() || !SeverActionsNativeExt2.Settings_GetBool("allowConjuredGold")
        If akBuyer.GetItemCount(Gold001) < aiTotalGold
            Return False
        EndIf
    EndIf
    Return True
EndFunction

Function _DoItemTransaction(Actor akSeller, Actor akBuyer, String asItemName, Int aiQuantity, Int aiTotalGold)
    {Atomic item-for-gold trade: resolves the item, checks stock and gold, moves the gold, then
     the item, and fires one item_purchased event. A failure fires item_purchase_failed with a
     reason; one after the gold moved refunds it.}

    If !_Transaction_IsEligible(akSeller, akBuyer, asItemName, aiQuantity, aiTotalGold)
        ; No actor to name in an event: just log.
        If !akSeller || !akBuyer
            Debug.Trace("[SeverActions_Currency] _DoItemTransaction: missing actor - skipping")
            Return
        EndIf
        String why = " - the deal could not be struck"
        If Gold001 && (akBuyer == Game.GetPlayer() || !SeverActionsNativeExt2.Settings_GetBool("allowConjuredGold")) && akBuyer.GetItemCount(Gold001) < aiTotalGold
            why = " - " + akBuyer.GetDisplayName() + " does not have " + aiTotalGold + " gold"
        EndIf
        SkyrimNetApi.RegisterEvent("item_purchase_failed", \
            akBuyer.GetDisplayName() + " could not complete the purchase of " + asItemName + " from " + akSeller.GetDisplayName() + why, \
            akSeller, akBuyer)
        Return
    EndIf

    Form itemForm = ResolveItemForTransaction(akSeller, asItemName)
    If !itemForm
        ; On localized games the LLM often passes the English name: list the seller's closest
        ; item names so it can retry with one that resolves.
        String closeNames = SeverActionsNativeExt2.Native_ClosestInventoryNames(akSeller, asItemName, 5)
        String failText = akSeller.GetDisplayName() + " doesn't have any '" + asItemName + "' to sell to " + akBuyer.GetDisplayName()
        If closeNames != ""
            failText += " - they do carry: " + closeNames + "."
        Else
            failText += " - they carry nothing called that; it may go by another name in their pack."
        EndIf
        SkyrimNetApi.RegisterEvent("item_purchase_failed", failText, akSeller, akBuyer)
        Return
    EndIf

    ; Check stock before the walk and the animation.
    Int available = GetTransactionAvailableQty(akSeller, itemForm)
    If available < aiQuantity
        SkyrimNetApi.RegisterEvent("item_purchase_failed", \
            akSeller.GetDisplayName() + " only has " + available + " " + itemForm.GetName() + " - not enough for " + akBuyer.GetDisplayName() + "'s " + aiQuantity, \
            akSeller, akBuyer)
        Return
    EndIf

    ; Gold first: the item half walks and animates (up to ~15 s), where a save, crash or unload
    ; would orphan a gold-last payment; a failed item half refunds instead. An NPC buyer pays
    ; every real coin first and only the shortfall is minted (TransferGold's conjure path would
    ; not debit them at all); the player always pays in full.
    Bool conjureOK = (akBuyer != Game.GetPlayer()) && SeverActionsNativeExt2.Settings_GetBool("allowConjuredGold")
    Int paid = TransferGold(akBuyer, akSeller, aiTotalGold, False)
    ; The minted part never becomes the buyer's: a refund destroys it first and returns only real coin.
    Int minted = 0
    If paid < aiTotalGold && conjureOK
        minted = aiTotalGold - paid
        akSeller.AddItem(Gold001, minted, False)
        Debug.Trace("[SeverActions_Currency] Trade: conjured " + minted + "g shortfall for " + akBuyer.GetDisplayName())
        paid = aiTotalGold
    EndIf
    If paid != aiTotalGold
        ; Eligibility checked the gold, so a short transfer means a race: hand back what moved and
        ; stop before the item half.
        String shortNote = " - the gold never changed hands"
        If paid > 0
            TransferGold(akSeller, akBuyer, paid, False)
            shortNote = " - only " + paid + " of the " + aiTotalGold + " gold changed hands, and it was handed back"
        EndIf
        SkyrimNetApi.RegisterEvent("item_purchase_failed", \
            akBuyer.GetDisplayName() + " could not finish paying " + akSeller.GetDisplayName() + " for " + asItemName + shortNote, \
            akSeller, akBuyer)
        Return
    EndIf

    Int transferred = TransferItemForTransaction(akSeller, akBuyer, itemForm, aiQuantity)
    If transferred <= 0
        ; Refund; the seller holds at least aiTotalGold (just paid).
        If minted > 0
            akSeller.RemoveItem(Gold001, minted, True)
        EndIf
        TransferGold(akSeller, akBuyer, aiTotalGold - minted, False)
        SkyrimNetApi.RegisterEvent("item_purchase_failed", \
            akSeller.GetDisplayName() + " could not hand over " + asItemName + " to " + akBuyer.GetDisplayName() + " - " + (aiTotalGold - minted) + " gold refunded", \
            akSeller, akBuyer)
        Return
    EndIf

    ; A race after the stock check can leave transferred short: keep the moved items and refund
    ; the unfilled part pro-rata. A full transfer keeps the exact agreed total.
    Int chargedGold = aiTotalGold
    If transferred < aiQuantity
        Int pricePerUnit = aiTotalGold / aiQuantity
        Int refund = aiTotalGold - (pricePerUnit * transferred)
        If refund > 0
            ; Minted coin is cancelled first; the rest goes back as real coin.
            Int burn = refund
            If burn > minted
                burn = minted
            EndIf
            If burn > 0
                akSeller.RemoveItem(Gold001, burn, True)
            EndIf
            If refund > burn
                TransferGold(akSeller, akBuyer, refund - burn, False)
            EndIf
            chargedGold = aiTotalGold - refund
        EndIf
    EndIf

    String itemLabel = itemForm.GetName()
    If transferred > 1
        itemLabel = transferred + " " + itemLabel
    EndIf
    String eventMsg = akBuyer.GetDisplayName() + " bought " + itemLabel + " from " + akSeller.GetDisplayName() + " for " + chargedGold + " gold"
    SkyrimNetApi.RegisterEvent("item_purchased", eventMsg, akSeller, akBuyer)

    ; Ledger source by the player's side (NPC-to-NPC logs nothing); the item label is the
    ; row's reason, shown in the recent-transactions view.
    Actor player = Game.GetPlayer()
    String src = "buy_item"   ; the player buys (or NPC-to-NPC, which logs nothing)
    If akSeller == player
        src = "sell_item"
    EndIf
    _LogToLedger(akBuyer, akSeller, chargedGold, src, itemLabel)
EndFunction

; =============================================================================
; ENTERPRISES - safe-exit stubs: the retainer economy's 24 LLM entry points moved to
; SeverActions_Enterprises (P9-02). Each name stays (F7): a save's suspended frame
; resumes the saved bytecode and must find something here that exits.
; =============================================================================

Bool Function HireRetainer(Actor akActor, String job, String arrangement)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function SwearCampToPlayer(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function RecruitLeaderlessCamp(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function ReleaseCampFromService(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function RenounceCampOath(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function MusterCamp(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function SendCampHome(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function CollectFromRetainer(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function HireSteward(Actor akActor, Int aiWeeklyWage = 100)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function DismissSteward(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function CollectFromSteward(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function PayArrears(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function DismissRetainer(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function GrantLoan(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function RefuseLoan(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function ForgiveLoan(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function ReassureRetainer(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function GrantTaxRelief(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function RaiseHoldTaxes(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function CollectAuthorizedTaxes(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function PressTheDemand(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function BrushOffRetainer(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function NegotiateTerms(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

Bool Function GrantRetainerRaise(Actor akActor)
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-02, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-02): moved to SeverActions_Enterprises
    Return False
EndFunction

; ============================================================================
; M-V VERB DISPATCHER (DR10)
; ============================================================================
; The economy's UI verbs (Native/data/verb_table.json) arrive as SeverActions_Verb_Economy
; with the Actions page's 8 pipe fields. This is the ONE script defining OnVerb_Economy (a
; shared callback name runs on every script of the form, F4); Maintenance registers it (DR16).
Event OnVerb_Economy(String eventName, String strArg, Float numArg, Form sender)
    String actionId = SeverActions_ModuleBase.VerbField(strArg, 0)
    String targetName = SeverActions_ModuleBase.VerbField(strArg, 1)
    String target2Name = SeverActions_ModuleBase.VerbField(strArg, 2)
    String strParam = SeverActions_ModuleBase.VerbField(strArg, 3)
    Int intParam = SeverActions_ModuleBase.VerbField(strArg, 4) as Int
    String str2Param = SeverActions_ModuleBase.VerbField(strArg, 5)
    Int targetFid = SeverActions_ModuleBase.VerbField(strArg, 6) as Int
    Int target2Fid = SeverActions_ModuleBase.VerbField(strArg, 7) as Int
    Debug.Trace("[SeverActions_Currency] OnVerb_Economy: " + actionId + " target=" + targetName + " target2=" + target2Name \
        + " str=" + strParam + " int=" + intParam + " str2=" + str2Param + " fid=" + targetFid + " fid2=" + target2Fid)

    ; Exact identity first (the picker's sender, then the encoded FormID), the fuzzy name
    ; last; names are then re-canonicalized to display names.
    Actor target = SeverActions_ModuleBase.VerbActor(sender, targetFid, targetName)
    If !target
        Debug.Trace("[SeverActions_Currency] OnVerb_Economy: could not resolve target '" + targetName + "' for " + actionId)
        Return
    EndIf
    targetName = target.GetDisplayName()
    Actor target2 = SeverActions_ModuleBase.VerbActor(None, target2Fid, target2Name)
    If target2
        target2Name = target2.GetDisplayName()
    ElseIf target2Name != ""
        Debug.Trace("[SeverActions_Currency] OnVerb_Economy: target2 name '" + target2Name + "' did not resolve to an actor (action=" + actionId + ")")
    EndIf

    ; -- Currency (own code) --
    If actionId == "giveGold"
        ; The picker always supplies target2 as an Actor; there is no name fallback.
        If target2
            GiveGold_Execute(target, target2, intParam)
        EndIf

    ElseIf actionId == "collectPayment"
        ; target = Collector, target2 = Payer (matches YAML: akCollector, akPayer);
        ; no payer chosen = collect from the player
        If target2
            CollectPayment_Execute(target, target2, intParam)
        Else
            CollectPayment_Execute(target, Game.GetPlayer(), intParam)
        EndIf

    ElseIf actionId == "extortGold"
        ; target = Extorter, target2 = Victim (matches YAML: akExtorter, akVictim);
        ; no victim chosen = extort the player
        If target2
            ExtortGold_Execute(target, target2, intParam)
        Else
            ExtortGold_Execute(target, Game.GetPlayer(), intParam)
        EndIf

    ; -- Trade (buy/sell). str2Param ('detail') carries the total gold as text
    ;    (the single int slot already holds quantity). --
    ElseIf actionId == "sellItem"
        If target2
            SellItem_Execute(target, target2, strParam, intParam, str2Param as Int)
        EndIf

    ElseIf actionId == "buyItem"
        If target2
            BuyItem_Execute(target, target2, strParam, intParam, str2Param as Int)
        EndIf

    ; -- Crafting (sibling script). strParam = the thing made; target2 = optional
    ;    recipient; intParam = count (the page seeds 1). --
    ElseIf actionId == "cookMeal"
        SeverActions_Crafting craftCook = (Self as Quest) as SeverActions_Crafting
        If craftCook
            craftCook.CookMeal_Internal(target, strParam, target2, intParam)
        EndIf

    ElseIf actionId == "brewPotion"
        SeverActions_Crafting craftBrew = (Self as Quest) as SeverActions_Crafting
        If craftBrew
            craftBrew.BrewPotion_Internal(target, strParam, target2, intParam)
        EndIf

    ElseIf actionId == "craftItem"
        SeverActions_Crafting craftMake = (Self as Quest) as SeverActions_Crafting
        If craftMake
            craftMake.CraftItem_Internal(target, strParam, target2, intParam)
        EndIf

    ElseIf actionId == "commissionItem"
        ; str2Param ('detail') = ETA text; quotedTotal 0 = the smith quotes it.
        SeverActions_Crafting craftOrder = (Self as Quest) as SeverActions_Crafting
        If craftOrder
            craftOrder.CommissionItem_Internal(target, strParam, str2Param, intParam, 0)
        EndIf

    ElseIf actionId == "collectCommission"
        SeverActions_Crafting craftCollect = (Self as Quest) as SeverActions_Crafting
        If craftCollect
            craftCollect.CollectCommission_Internal(target)
        EndIf

    ; -- Debt (sibling script) --
    ElseIf actionId == "createDebt"
        ; target = creditor, target2 = debtor, intParam = amount, strParam = reason
        SeverActions_Debt debtCreate = (Self as Quest) as SeverActions_Debt
        If debtCreate && target2
            String reason = strParam
            If reason == ""
                reason = "debt"
            EndIf
            debtCreate.CreateDebt_Execute(target, target, target2, intParam, reason, 0, 0)
        EndIf

    ElseIf actionId == "addToDebt"
        ; target = creditor, target2 = debtor, intParam = amount
        SeverActions_Debt debtAdd = (Self as Quest) as SeverActions_Debt
        If debtAdd && target2
            debtAdd.AddToDebt_Execute(target, target2, intParam, "additional charges")
        EndIf

    ElseIf actionId == "forgiveDebt"
        ; target = creditor, target2 = debtor
        SeverActions_Debt debtForgive = (Self as Quest) as SeverActions_Debt
        If debtForgive && target2
            debtForgive.ForgiveDebt_Execute(target, target2)
        EndIf

    ElseIf actionId == "createRecurringDebt"
        ; target = creditor (also the speaker), target2 = debtor, intParam = amount per
        ; cycle, strParam = reason, str2Param = interval in days as text (default 7)
        SeverActions_Debt debtRecur = (Self as Quest) as SeverActions_Debt
        If debtRecur && target2
            String rdReason = strParam
            If rdReason == ""
                rdReason = "recurring debt"
            EndIf
            Int rdInterval = str2Param as Int
            If rdInterval <= 0
                rdInterval = 7
            EndIf
            debtRecur.CreateRecurringDebt_Execute(target, target, target2, intParam, rdReason, rdInterval, 0)
        EndIf

    Else
        Debug.Trace("[SeverActions_Currency] OnVerb_Economy: unknown actionId '" + actionId + "' (not a row this dispatcher carries)")
    EndIf

    ; Refresh again now the forwarded call has returned: the DLL's refresh one frame after
    ; routing runs before most verbs have changed their stores.
    SeverActionsNative.Magelight_RefreshPage("world")
    SeverActionsNative.Magelight_RefreshPage("enterprises")
EndEvent
