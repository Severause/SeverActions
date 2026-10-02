Scriptname SeverActions_Crafting extends Quest
{Crafting entry points and the Papyrus half of the native CraftingOrchestrator
(walk -> animate -> return -> hand off). The entry points resolve item and
workstation natively and call Craft_Begin; OnCraftPhaseChange does each phase's
work that has no clean native path (package overrides, aliases, idles, SkyrimNet
events). One craft runs at a time because the aliases are quest singletons; the
orchestrator queues the rest. Also hosts deferred commissions ('CMSN').}

; PROPERTIES (ESP-filled)

Package Property CraftAtForgePackage Auto
{Workstation-use package for every station type (forge, pot, oven, lab).}

ReferenceAlias Property CrafterAlias Auto
{Alias bound to the NPC for the workstation package.}

ReferenceAlias Property ForgeAlias Auto
{Alias bound to the workstation (any type).}

ReferenceAlias Property CrafterApproachAlias Auto
{Alias bound to the NPC for the recipient-approach package.}

ReferenceAlias Property RecipientAlias Auto
{Alias bound to the recipient of the crafted item.}

Idle Property IdleGive Auto
{Give-item animation.}

; CONFIGURATION

float Property SEARCH_RADIUS = 4000.0 Auto
{Workstation search radius (game units, ~57 m). The native search covers the
 loaded grid, so a station across a cell border is found too.}

int Property CRAFT_PACKAGE_PRIORITY = 100 Auto
{Unused: an Auto value is saved per game, so the priority lives in CRAFT_OVERRIDE_PRIORITY.}

int Property CRAFT_OVERRIDE_PRIORITY = 101 AutoReadOnly
{Priority for the workstation package override. Outranks dialogue (50-80) and the
 priority-100 wait and safe-interior sandboxes, so a waiting follower still walks
 to the station; the guard duty and captive holds (105+) still win.}

; Craft time, interaction distance and arrival timeouts are constants in
; CraftingOrchestrator.h.

; INITIALIZATION

Event OnInit()
    RegisterForModEvent("SACraft_PhaseChange", "OnCraftPhaseChange")
    Debug.Trace("SeverActions_Crafting: Initialized; registered for SACraft_PhaseChange")
EndEvent

Function Maintenance()
    {Load-time entry (Mod_Economy stage 1): the registrations and the commission tick
     chain. The first wake is short so the chain acknowledges inside Init's ~90 s K4
     window; the steady interval is two minutes (CommissionStore::Tick is game-time based).}
    EnsureRegistered()
    ChronoArm(20.0)
EndFunction

Function ChronoArm(Float afSeconds)
    {Arm this script's one-shot chronometer tick (Chronometer block in
     SeverActionsNativeExt2.psc). Event and callback names stay unique per script;
     re-arm replaces the pending tick; ticks do not survive save/load (Maintenance
     re-arms; Mod_Economy.OnChronoDead re-arms a dead chain).}
    RegisterForModEvent("SeverActions_Tick_Crafting", "OnChronoTick_Crafting")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_Crafting", afSeconds)
EndFunction

Bool _commissionTickInFlight = False
Float _commissionTickInFlightSince = 0.0

Event OnChronoTick_Crafting(String eventName, String strArg, Float numArg, Form sender)
    ; Re-arm first (the acknowledgement), then a guarded drain - see OnChronoTick_Debt.
    ChronoArm(120.0)
    Float now = Utility.GetCurrentRealTime()
    If _commissionTickInFlight && (now - _commissionTickInFlightSince) < 120.0
        Return
    EndIf
    _commissionTickInFlight = True
    _commissionTickInFlightSince = now
    TickCommissions()
    _commissionTickInFlight = False
EndEvent

; Called by Maintenance and by the five entry points (for a frame that runs before
; Maintenance); RegisterForModEvent is idempotent.

Function EnsureRegistered()
    RegisterForModEvent("SACraft_PhaseChange", "OnCraftPhaseChange")
    ; Commission deposit/balance confirm callback.
    RegisterForModEvent("SeverActions_CommissionPromptChoice", "OnCommissionPromptChoice")
EndFunction

; WORKSTATION FINDERS (native wrappers)

ObjectReference Function FindNearbyForge(Actor akActor)
    return SeverActionsNative.FindNearbyForge(akActor, SEARCH_RADIUS)
EndFunction

ObjectReference Function FindNearbyCookingPot(Actor akActor)
    return SeverActionsNative.FindNearbyCookingPot(akActor, SEARCH_RADIUS)
EndFunction

ObjectReference Function FindNearbyOven(Actor akActor)
    return SeverActionsNative.FindNearbyOven(akActor, SEARCH_RADIUS)
EndFunction

ObjectReference Function FindNearbyAlchemyLab(Actor akActor)
    return SeverActionsNative.FindNearbyAlchemyLab(akActor, SEARCH_RADIUS)
EndFunction

; SKYRIMNET ENTRY POINTS (action YAMLs): resolve item + workstation, then Craft_Begin
; and return; the orchestrator drives the phases through SACraft_PhaseChange.

Function CraftItem_Internal(Actor akActor, string itemName, Actor akRecipient, int itemCount = 1)
    {Generic craft: routes by item type (smithing → forge, cooking → cooking pot,
    potion/poison → alchemy lab).}

    EnsureRegistered()

    Form itemForm = None
    ObjectReference workstation = None
    string workstationType = ""
    string actionVerb = "crafting"

    bool recipeDBLoaded = SeverActionsNative.IsRecipeDBLoaded()
    bool alchemyDBLoaded = SeverActionsNative.IsAlchemyDBLoaded()

    if recipeDBLoaded
        itemForm = SeverActionsNative.FindSmithingRecipe(itemName)
        if itemForm
            workstation = FindNearbyForge(akActor)
            workstationType = "forge"
            actionVerb = "crafting"
        endif
    endif

    if !itemForm && recipeDBLoaded
        itemForm = SeverActionsNative.FindCookingRecipe(itemName)
        if itemForm
            workstation = FindNearbyCookingPot(akActor)
            workstationType = "cooking pot"
            actionVerb = "cooking"
        endif
    endif

    if !itemForm && alchemyDBLoaded
        itemForm = SeverActionsNative.FindPotion(itemName)
        if itemForm
            workstation = FindNearbyAlchemyLab(akActor)
            workstationType = "alchemy lab"
            actionVerb = "brewing"
        endif
    endif

    if !itemForm && alchemyDBLoaded
        itemForm = SeverActionsNative.FindPoison(itemName)
        if itemForm
            workstation = FindNearbyAlchemyLab(akActor)
            workstationType = "alchemy lab"
            actionVerb = "concocting"
        endif
    endif

    DispatchToOrchestrator(akActor, itemForm, workstation, workstationType, actionVerb, akRecipient, itemCount, itemName)
EndFunction

Function CookMeal_Internal(Actor akActor, string recipeName, Actor akRecipient, int itemCount = 1)
    {Cook a meal at a cooking pot or oven (auto-detected).}

    EnsureRegistered()

    Form itemForm = None
    if SeverActionsNative.IsRecipeDBLoaded()
        itemForm = SeverActionsNative.FindCookingRecipe(recipeName)
    endif

    bool needsOven = false
    if itemForm
        needsOven = SeverActionsNative.IsOvenRecipe(recipeName)
    endif

    ObjectReference workstation = None
    string workstationType = "cooking pot"
    if needsOven
        workstation = FindNearbyOven(akActor)
        if workstation
            workstationType = "oven"
        else
            workstation = FindNearbyCookingPot(akActor)
        endif
    elseif itemForm
        workstation = FindNearbyCookingPot(akActor)
    endif

    DispatchToOrchestrator(akActor, itemForm, workstation, workstationType, "cooking", akRecipient, itemCount, recipeName)
EndFunction

Function BrewPotion_Internal(Actor akActor, string potionName, Actor akRecipient, int itemCount = 1)
    {Brew a potion at an alchemy lab.}

    EnsureRegistered()

    Potion itemForm = None
    if SeverActionsNative.IsAlchemyDBLoaded()
        itemForm = SeverActionsNative.FindPotion(potionName)
    endif

    ObjectReference workstation = None
    if itemForm
        workstation = FindNearbyAlchemyLab(akActor)
    endif

    DispatchToOrchestrator(akActor, itemForm, workstation, "alchemy lab", "brewing", akRecipient, itemCount, potionName)
EndFunction

Function DispatchToOrchestrator(Actor akActor, Form itemForm, ObjectReference workstation, string workstationType, string actionVerb, Actor akRecipient, int itemCount, string originalName)
    {Shared tail of the three entry points: reports a traveler, a missing item or
    a missing workstation, else starts the craft. Failures use RegisterEvent, NOT
    DirectNarration: a forced response re-enters action selection and the NPC
    retries the same failed craft in a loop.}

    Actor recipient = akRecipient
    if !recipient
        recipient = Game.GetPlayer()
    endif
    bool recipientIsPlayer = (recipient == Game.GetPlayer())

    ; Never park a traveler at a workstation: the craft override beats the travel
    ; alias package. (Travel start cancels an in-flight craft; this is the reverse.)
    if SeverActionsNativeExt2.Travel_IsTravelingByActor(akActor)
        SkyrimNetApi.RegisterEvent("craft_failed", akActor.GetDisplayName() + " is traveling and cannot stop to work right now.", akActor, recipient)
        return
    endif

    if !itemForm
        if recipientIsPlayer
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("crafting.cannotCraft", ("" + originalName)))
        endif
        SkyrimNetApi.RegisterEvent("craft_failed", akActor.GetDisplayName() + " doesn't know how to make " + originalName + ".", akActor, recipient)
        return
    endif

    if !workstation
        if recipientIsPlayer
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("crafting.noWorkstationNearby", ("" + workstationType)))
        endif
        SkyrimNetApi.RegisterEvent("craft_failed", akActor.GetDisplayName() + " can't find a " + workstationType + " nearby.", akActor, recipient)
        return
    endif

    int handle = SeverActionsNativeExt.Craft_Begin(akActor, itemForm, workstation, akRecipient, itemCount, workstationType, actionVerb)

    if handle == 0
        ; Begin rejects only null arguments, checked above; defensive.
        if recipientIsPlayer
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("crafting.cantStartTask", ("" + akActor.GetDisplayName())))
        endif
        SkyrimNetApi.RegisterEvent("craft_failed", akActor.GetDisplayName() + " is unable to begin " + actionVerb + " " + itemForm.GetName() + " right now.", akActor, recipient)
        return
    endif

    Debug.Trace("SeverActions_Crafting: dispatched handle=" + handle + " for " + itemForm.GetName() + " on " + akActor.GetDisplayName())
EndFunction

; DEFERRED COMMISSIONS (CommissionItem / CollectCommission)
; The smith works off-screen, no workstation. State lives in the native
; CommissionStore ('CMSN' block in SeverActionsNativeExt.psc). Price = the smith's
; quoted total, else item value × count; 50% deposit at order, the balance at
; pickup through a confirm. Unpaid, the smith keeps the item (it stays Ready).

Form Function ResolveCraftableForm(string itemName)
    {Output Form for an item name, in CraftItem_Internal's DB order (smithing →
    cooking → potion → poison), so anything craftable can be commissioned. None
    if no recipe matches.}
    Form itemForm = None
    bool recipeDBLoaded = SeverActionsNative.IsRecipeDBLoaded()
    bool alchemyDBLoaded = SeverActionsNative.IsAlchemyDBLoaded()

    if recipeDBLoaded
        itemForm = SeverActionsNative.FindSmithingRecipe(itemName)
    endif
    if !itemForm && recipeDBLoaded
        itemForm = SeverActionsNative.FindCookingRecipe(itemName)
    endif
    if !itemForm && alchemyDBLoaded
        itemForm = SeverActionsNative.FindPotion(itemName)
    endif
    if !itemForm && alchemyDBLoaded
        itemForm = SeverActionsNative.FindPoison(itemName)
    endif
    return itemForm
EndFunction

string Function DescribeEta(Float etaDays)
    {Narration phrasing for an ETA in game days.}
    if etaDays <= 0.75
        return "later today"
    elseif etaDays <= 1.5
        return "tomorrow"
    elseif etaDays <= 6.5
        return "in about " + (etaDays as Int) + " days"
    elseif etaDays <= 8.5
        return "in about a week"
    else
        return "in about " + ((etaDays / 7.0) as Int) + " weeks"
    endif
EndFunction

; COMMISSION CONFIRM: pending state + shared helpers
; The deposit and balance confirms use the non-pausing overlay
; (MagelightCommissionPromptBridge), else a modal SkyMessage. The overlay is async,
; so the order waits in m_comm* until SeverActions_CommissionPromptChoice. One slot:
; while an overlay is open (_CommConfirmBusy) no new order or pickup touches it.

String  m_commMode             ; "deposit" | "balance" | "" (idle)
Actor   m_commSmith
Form    m_commItem
Int     m_commCount
Int     m_commPrice            ; full order price
Int     m_commDeposit          ; deposit (taken at order; shown at pickup)
Int     m_commBalance          ; balance due (taken in balance mode)
Float   m_commEtaDays
Int     m_commId               ; balance mode: the Ready commission id
String  m_commItemName         ; cached display name for narration

Bool Function _CommConfirmBusy(Actor akActor, String asMode, Form akItem)
    {True while an overlay holds the pending slot, so the caller must not write it: a
     repeat of the pending order is left to that overlay, anything else is refused in
     character.}
    if !SeverActionsNativeExt.Magelight_IsCommissionPromptOpen()
        return false
    endif
    if m_commSmith == akActor && m_commMode == asMode && m_commItem == akItem
        Debug.Trace("[SeverActions_Crafting] " + asMode + " confirm already open for this order - leaving it to the overlay")
        return true
    endif
    SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " waits: " + Game.GetPlayer().GetDisplayName() + " is still deciding about another order.", akActor, Game.GetPlayer())
    return true
EndFunction

String Function _CommLabel(String asName, Int aiCount)
    if aiCount > 1
        return aiCount + " " + asName
    endif
    return asName
EndFunction

Function _ClearCommPending()
    m_commMode     = ""
    m_commSmith    = None
    m_commItem     = None
    m_commCount    = 0
    m_commPrice    = 0
    m_commDeposit  = 0
    m_commBalance  = 0
    m_commEtaDays  = 0.0
    m_commId       = 0
    m_commItemName = ""
EndFunction

; Deposit mode: take the deposit, record the order, narrate (overlay accept or
; SkyMessage fallback).
Function _PlaceCommission()
    Actor akActor = m_commSmith
    Form itemForm = m_commItem
    if !akActor || !itemForm
        _ClearCommPending()
        return
    endif
    Actor player = Game.GetPlayer()
    int itemCount   = m_commCount
    int priceTotal  = m_commPrice
    int deposit     = m_commDeposit
    int balanceDue  = m_commBalance
    Float etaDays   = m_commEtaDays
    string itemName = m_commItemName
    string itemLabel = _CommLabel(itemName, itemCount)

    ; Re-check: gold may have changed while the non-pausing overlay was open.
    Form goldForm = Game.GetForm(0xF)
    if player.GetGoldAmount() < deposit
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("crafting.cantAffordDeposit", ("" + deposit)))
        SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " won't start the work without the " + deposit + " gold deposit, which " + player.GetDisplayName() + " can't cover.", akActor, player)
        _ClearCommPending()
        return
    endif

    player.RemoveItem(goldForm, deposit, true)

    int id = SeverActionsNativeExt.Native_Commission_Add(akActor, player, itemForm, itemCount, itemName, akActor.GetDisplayName(), player.GetDisplayName(), priceTotal, deposit, etaDays)
    if id == 0
        ; Native rejected after we took the deposit — refund and bail.
        player.AddItem(goldForm, deposit, true)
        SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " couldn't take the commission after all.", akActor, player)
        _ClearCommPending()
        return
    endif

    string etaPhrase = DescribeEta(etaDays)
    SeverActionsNativeExt.Native_Ledger_RecordEvent(deposit, true, "commission", akActor, "", "deposit: " + itemLabel, 0)
    Debug.Notification("Commissioned " + itemLabel + " - " + deposit + " gold deposit paid, " + balanceDue + " gold due on pickup.")
    SkyrimNetApi.RegisterPersistentEvent(akActor.GetDisplayName() + " agreed to craft " + itemLabel + " for " + player.GetDisplayName() + ", ready " + etaPhrase + ". Took a " + deposit + " gold deposit; " + balanceDue + " gold is due when " + player.GetDisplayName() + " collects it.", akActor, player)
    _ClearCommPending()
EndFunction

; Balance mode: take the balance (if any), hand over the item, clear the record
; (overlay accept, SkyMessage fallback, or the fully-paid path).
Function _CollectBalanceAndHandover()
    Actor akActor = m_commSmith
    Form itemForm = m_commItem
    if !akActor || !itemForm
        _ClearCommPending()
        return
    endif
    Actor player = Game.GetPlayer()
    int id          = m_commId
    int itemCount   = m_commCount
    int balanceDue  = m_commBalance
    string itemName = m_commItemName
    string itemLabel = _CommLabel(itemName, itemCount)

    ; It may have been collected in another conversation while the overlay was open.
    if !SeverActionsNativeExt.Native_Commission_Exists(id)
        _ClearCommPending()
        return
    endif

    if balanceDue > 0
        if player.GetGoldAmount() < balanceDue
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("crafting.cantAffordBalance", ("" + balanceDue)))
            SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " holds onto " + itemLabel + " - " + player.GetDisplayName() + " can't cover the " + balanceDue + " gold balance.", akActor, player)
            _ClearCommPending()
            return
        endif
        Form goldForm = Game.GetForm(0xF)
        player.RemoveItem(goldForm, balanceDue, true)
        SeverActionsNativeExt.Native_Ledger_RecordEvent(balanceDue, true, "commission", akActor, "", "balance: " + itemLabel, 0)
    endif

    ; Not silent: the item is created straight into the player's inventory (the
    ; smith never holds it), so the vanilla add message is the visible handover.
    player.AddItem(itemForm, itemCount, false)
    ; Record the history row BEFORE Remove: the native snapshots the live row.
    SeverActionsNativeExt.Native_Commission_RecordCompleted(id)
    SeverActionsNativeExt.Native_Commission_Remove(id)
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("crafting.collected", ("" + itemLabel), ("" + akActor.GetDisplayName())))
    SkyrimNetApi.RegisterPersistentEvent(akActor.GetDisplayName() + " handed over the finished " + itemLabel + " to " + player.GetDisplayName() + ".", akActor, player)
    _ClearCommPending()
EndFunction

; From MagelightCommissionPromptBridge on a click, the auto-deny timer or Escape.
; strArg = "accept" | "deny"; sender = the smith; the order is in m_comm*.
Event OnCommissionPromptChoice(String asEventName, String asChoice, Float afAmount, Form akSender)
    Actor smith = akSender as Actor
    if !smith
        return
    endif
    ; Only an answer to the pending order: its smith and the amount the overlay showed.
    Int shown = afAmount as Int
    if !m_commSmith || smith != m_commSmith \
        || (m_commMode == "deposit" && shown != m_commDeposit) || (m_commMode == "balance" && shown != m_commBalance)
        Debug.Trace("[SeverActions_Crafting] OnCommissionPromptChoice: not the pending order (sender or amount) - ignoring")
        return
    endif

    if asChoice == "accept"
        if m_commMode == "deposit"
            _PlaceCommission()
        elseif m_commMode == "balance"
            _CollectBalanceAndHandover()
        else
            _ClearCommPending()
        endif
    else
        ; Declined / cancelled / timed out — narrate so the smith reacts.
        Actor player = Game.GetPlayer()
        if m_commMode == "deposit"
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " decided not to commission " + _CommLabel(m_commItemName, m_commCount) + " from " + smith.GetDisplayName() + " after all.", smith, player)
        elseif m_commMode == "balance"
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " decided not to collect " + _CommLabel(m_commItemName, m_commCount) + " from " + smith.GetDisplayName() + " just yet.", smith, player)
        endif
        _ClearCommPending()
    endif
EndEvent

Function CommissionItem_Internal(Actor akActor, string itemName, string etaText, int itemCount = 1, int quotedTotal = 0)
    {Deferred-craft entry point (CommissionItem action). `etaText` is the smith's
    prose estimate, parsed natively to game days; `quotedTotal` is the smith's
    spoken price for the whole order (else item value × count), so the confirm
    matches the quote. The 50% deposit is confirmed before any gold is taken.}

    if !akActor
        return
    endif
    EnsureRegistered()
    if itemCount < 1
        itemCount = 1
    elseif itemCount > 100
        ; Clamp the LLM count: a huge one overflows the 32-bit
        ; `unitValue * itemCount` to a negative price, i.e. a nearly free order.
        itemCount = 100
    endif

    Actor player = Game.GetPlayer()

    Form itemForm = ResolveCraftableForm(itemName)
    if !itemForm
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("crafting.cannotCommission", ("" + itemName)))
        SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " doesn't know how to make " + itemName + ".", akActor, player)
        return
    endif

    ; CommissionStore caps at 10 too (kMaxCommissions); this gives an in-character
    ; decline instead of a silent 0.
    if SeverActionsNativeExt.Native_Commission_GetCount() >= 10
        SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " has too many orders backed up to take another commission right now.", akActor, player)
        return
    endif

    int priceTotal = quotedTotal
    if priceTotal <= 0
        int unitValue = itemForm.GetGoldValue()
        if unitValue < 1
            unitValue = 1
        endif
        priceTotal = unitValue * itemCount
    endif
    ; Clamp a garbage quote.
    if priceTotal > 100000
        priceTotal = 100000
    elseif priceTotal < 1
        priceTotal = 1
    endif
    int deposit = priceTotal / 2
    if deposit < 1
        deposit = 1
    endif
    int balanceDue = priceTotal - deposit

    ; Checked before the confirm, so it never opens for an order they can't place.
    int playerGold = player.GetGoldAmount()
    if playerGold < deposit
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("crafting.cantAffordDeposit", ("" + deposit)))
        SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " won't start the work without a " + deposit + " gold deposit, which " + player.GetDisplayName() + " can't cover right now.", akActor, player)
        return
    endif

    Float etaDays = SeverActionsNativeExt.Native_Commission_ParseEtaDays(etaText)

    if _CommConfirmBusy(akActor, "deposit", itemForm)
        return
    endif
    ; Stash the order for the async confirm (or fallback).
    m_commMode     = "deposit"
    m_commSmith    = akActor
    m_commItem     = itemForm
    m_commCount    = itemCount
    m_commPrice    = priceTotal
    m_commDeposit  = deposit
    m_commBalance  = balanceDue
    m_commEtaDays  = etaDays
    m_commId       = 0
    m_commItemName = itemForm.GetName()

    ; Overlay confirm (the answer arrives in OnCommissionPromptChoice), else a
    ; modal SkyMessage.
    if SeverActionsNativeExt.Magelight_IsCommissionPromptAvailable() && !SeverActionsNativeExt.Magelight_IsCommissionPromptOpen()
        if SeverActionsNativeExt.Magelight_OpenCommissionPrompt(akActor, deposit, akActor.GetDisplayName(), m_commItemName, priceTotal, deposit, balanceDue, "deposit", 30000)
            return
        endif
    endif

    String itemLabel = _CommLabel(m_commItemName, itemCount)
    String choice = ""
    If SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
        choice = SeverActions_SkyMessageLib.Show(akActor.GetDisplayName() + " will forge " + itemLabel + " for " + priceTotal + " gold. Pay the " + deposit + " gold deposit now? (" + balanceDue + " due on pickup)", "Pay " + deposit + " deposit", "Cancel", getIndex = true)
    EndIf
    if choice == "0"
        _PlaceCommission()
    elseif SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
        SkyrimNetApi.DirectNarration(player.GetDisplayName() + " decided not to commission " + itemLabel + " from " + akActor.GetDisplayName() + " after all.", akActor, player)
        _ClearCommPending()
    else
        ; No confirm could be shown: never spend gold unasked, and do not claim a refusal.
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("crafting.commissionConfirmUnavailable", ("" + akActor.GetDisplayName())))
        _ClearCommPending()
    endif
EndFunction

Function CollectCommission_Internal(Actor akActor)
    {Pickup entry point (CollectCommission action, gated by has_ready_commission).
    Takes the balance through a confirm and hands over the item; if the player
    declines or can't pay, the smith keeps it.}

    if !akActor
        return
    endif
    EnsureRegistered()
    Actor player = Game.GetPlayer()

    int id = SeverActionsNativeExt.Native_Commission_FindReadyForCrafter(akActor)
    if id == 0
        ; Nothing ready — distinguish "still working" from "no order at all".
        if SeverActionsNativeExt.Native_Commission_CountForCrafter(akActor) > 0
            SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " isn't finished with " + player.GetDisplayName() + "'s commission yet.", akActor, player)
        else
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " has nothing to collect from " + akActor.GetDisplayName() + ".", akActor, player)
        endif
        return
    endif

    Form itemForm   = SeverActionsNativeExt.Native_Commission_GetItem(id)
    int itemCount   = SeverActionsNativeExt.Native_Commission_GetItemCount(id)
    int balanceDue  = SeverActionsNativeExt.Native_Commission_GetBalanceDue(id)
    string itemName = SeverActionsNativeExt.Native_Commission_GetItemName(id)
    if itemCount < 1
        itemCount = 1
    endif
    string itemLabel = _CommLabel(itemName, itemCount)

    ; Item form gone (its mod was removed): drop the record before any balance is
    ; taken. The deposit is kept.
    if !itemForm
        SeverActionsNativeExt.Native_Commission_Remove(id)
        SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " can't seem to find the finished piece.", akActor, player)
        return
    endif

    if _CommConfirmBusy(akActor, "balance", itemForm)
        return
    endif
    ; Stash for the async confirm (or fallback).
    m_commMode     = "balance"
    m_commSmith    = akActor
    m_commItem     = itemForm
    m_commCount    = itemCount
    m_commPrice    = SeverActionsNativeExt.Native_Commission_GetPriceTotal(id)
    m_commDeposit  = SeverActionsNativeExt.Native_Commission_GetDepositPaid(id)
    m_commBalance  = balanceDue
    m_commEtaDays  = 0.0
    m_commId       = id
    m_commItemName = itemName

    ; Fully paid: no confirm.
    if balanceDue <= 0
        _CollectBalanceAndHandover()
        return
    endif

    ; Overlay confirm, else a modal SkyMessage (as in CommissionItem_Internal).
    if SeverActionsNativeExt.Magelight_IsCommissionPromptAvailable() && !SeverActionsNativeExt.Magelight_IsCommissionPromptOpen()
        if SeverActionsNativeExt.Magelight_OpenCommissionPrompt(akActor, balanceDue, akActor.GetDisplayName(), itemName, m_commPrice, m_commDeposit, balanceDue, "balance", 30000)
            return
        endif
    endif

    String choice = ""
    If SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
        choice = SeverActions_SkyMessageLib.Show(akActor.GetDisplayName() + "'s work is done - your " + itemName + " is ready. Pay the remaining " + balanceDue + " gold?", "Pay " + balanceDue + " gold", "Not now", getIndex = true)
    EndIf
    if choice == "0"
        _CollectBalanceAndHandover()
    elseif SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
        ; Declined — smith keeps holding it (commission stays Ready).
        SkyrimNetApi.DirectNarration(player.GetDisplayName() + " decided not to collect " + itemLabel + " from " + akActor.GetDisplayName() + " just yet.", akActor, player)
        _ClearCommPending()
    else
        ; No confirm could be shown: the smith keeps it, and no refusal is claimed.
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("crafting.pickupConfirmUnavailable", ("" + akActor.GetDisplayName())))
        _ClearCommPending()
    endif
EndFunction

Function TickCommissions()
    {Drain CommissionStore's pending events. The Ordered → Ready walk is native;
    Papyrus only registers the SkyrimNet events (no native API for that).
    Kind: 0 Regular, 1 ShortLived (commission_ready), 2 Persistent.}
    Int pending = SeverActionsNativeExt.Native_Commission_Tick()
    If pending <= 0
        Return
    EndIf

    Int i = 0
    While i < pending
        Int kind         = SeverActionsNativeExt.Native_Commission_PendingEvent_Kind(i)
        String eventName = SeverActionsNativeExt.Native_Commission_PendingEvent_Name(i)
        String content   = SeverActionsNativeExt.Native_Commission_PendingEvent_Content(i)
        String dedupKey  = SeverActionsNativeExt.Native_Commission_PendingEvent_Key(i)
        Int ttlMs        = SeverActionsNativeExt.Native_Commission_PendingEvent_TTL(i)
        Actor crafter    = SeverActionsNativeExt.Native_Commission_PendingEvent_Crafter(i)
        Actor customer   = SeverActionsNativeExt.Native_Commission_PendingEvent_Customer(i)

        If kind == 1
            SkyrimNetApi.RegisterShortLivedEvent(dedupKey, eventName, content, "", ttlMs, crafter, customer)
        ElseIf kind == 2
            SkyrimNetApi.RegisterPersistentEvent(content, crafter, customer)
        Else
            SkyrimNetApi.RegisterEvent(eventName, content, crafter, customer)
        EndIf

        i += 1
    EndWhile

    SeverActionsNativeExt.Native_Commission_ClearPendingEvents()
EndFunction

; PHASE LISTENER: SACraft_PhaseChange from CraftingOrchestrator.
; strArg = phase label, numArg = craft handle, sender = the crafter; refs are
; queried by handle.

Event OnCraftPhaseChange(string eventName, string strArg, float numArg, Form sender)
    int handle = numArg as Int
    Actor akActor = sender as Actor
    if !akActor
        Debug.Trace("SeverActions_Crafting: PhaseChange handle=" + handle + " phase='" + strArg + "' - null sender, skipping")
        return
    endif

    Debug.Trace("SeverActions_Crafting: PhaseChange handle=" + handle + " phase='" + strArg + "' actor=" + akActor.GetDisplayName())

    if strArg == "Phase1Apply"
        ObjectReference ws = SeverActionsNativeExt.Craft_GetWorkstation(handle)
        Actor recipient = SeverActionsNativeExt.Craft_GetRecipient(handle)
        string wsType = SeverActionsNativeExt.Craft_GetWorkstationType(handle)
        if ws
            ForgeAlias.ForceRefTo(ws)
            CrafterAlias.ForceRefTo(akActor)
            ; The schedule quests (priority 101) outrank the crafter aliases: a crafter the schedule holds comes off
            ; it, and the reconcile keeps her off while she holds either alias.
            SeverActions_ModuleBase.CallBool("followers", "leaveSchedule", akActor)
            ActorUtil.AddPackageOverride(akActor, CraftAtForgePackage, CRAFT_OVERRIDE_PRIORITY, 1)
            akActor.EvaluatePackage()
            SkyrimNetApi.RegisterPersistentEvent(akActor.GetDisplayName() + " begins working at the " + wsType + ".", akActor, recipient)
            SkyrimNetApi.UnregisterPackage(akActor, "TalkToPlayer")
        endif

    elseif strArg == "Phase2Cleanup"
        Actor recipient = SeverActionsNativeExt.Craft_GetRecipient(handle)
        string wsType = SeverActionsNativeExt.Craft_GetWorkstationType(handle)
        ActorUtil.RemovePackageOverride(akActor, CraftAtForgePackage)
        ForgeAlias.Clear()
        akActor.EvaluatePackage()
        Utility.Wait(2.0)
        CrafterAlias.Clear()
        SkyrimNetApi.RegisterPersistentEvent(akActor.GetDisplayName() + " finishes at the " + wsType + ".", akActor, recipient)

    elseif strArg == "Phase3Approach"
        Actor recipient = SeverActionsNativeExt.Craft_GetRecipient(handle)
        if recipient
            RecipientAlias.ForceRefTo(recipient)
            CrafterApproachAlias.ForceRefTo(akActor)
            ; Again: the schedule (priority 101) outranks the crafter aliases, and a tick since the forge can have
            ; re-seated her.
            SeverActions_ModuleBase.CallBool("followers", "leaveSchedule", akActor)
            akActor.EvaluatePackage()
        endif

    elseif strArg == "Phase4HandOff:anim"
        Actor recipient = SeverActionsNativeExt.Craft_GetRecipient(handle)
        CrafterApproachAlias.Clear()
        RecipientAlias.Clear()
        akActor.EvaluatePackage()
        if recipient
            Utility.Wait(0.3)
            akActor.SetLookAt(recipient)
            Utility.Wait(0.5)
            akActor.ClearLookAt()
            if IdleGive
                akActor.PlayIdle(IdleGive)
            endif
        endif

    elseif strArg == "Phase4HandOff:noanim"
        ; Recipient arrival timed out; the item still transfers in native Terminate.
        CrafterApproachAlias.Clear()
        RecipientAlias.Clear()
        akActor.EvaluatePackage()

    elseif strArg == "TermComplete"
        ; The item was already transferred natively.
        Actor recipient = SeverActionsNativeExt.Craft_GetRecipient(handle)
        bool recipientIsPlayer = (recipient == Game.GetPlayer())
        string recipientName = "Someone"
        if recipient
            recipientName = recipient.GetDisplayName()
        endif
        ; RegisterEvent, not DirectNarration (see DispatchToOrchestrator).
        string narration = recipientName + " has received an item from " + akActor.GetDisplayName() + "."
        SkyrimNetApi.RegisterEvent("craft_complete", narration, akActor, recipient)
        if recipientIsPlayer
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("crafting.receivedItemFrom", ("" + akActor.GetDisplayName())))
        endif

    elseif strArg == "TermAbortNoArrival"
        ; Couldn't reach the workstation.
        Actor recipient = SeverActionsNativeExt.Craft_GetRecipient(handle)
        bool recipientIsPlayer = (recipient == Game.GetPlayer())
        string wsType = SeverActionsNativeExt.Craft_GetWorkstationType(handle)
        ActorUtil.RemovePackageOverride(akActor, CraftAtForgePackage)
        ForgeAlias.Clear()
        CrafterAlias.Clear()
        CrafterApproachAlias.Clear()
        RecipientAlias.Clear()
        akActor.EvaluatePackage()
        string msg = akActor.GetDisplayName() + " was unable to reach the " + wsType + " and abandoned the task."
        ; No DirectNarration (see DispatchToOrchestrator).
        SkyrimNetApi.RegisterPersistentEvent(msg, akActor, recipient)
        if recipientIsPlayer
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("crafting.couldntReach", ("" + akActor.GetDisplayName()), ("" + wsType)))
        endif

    elseif strArg == "TermCancelled"
        ; Also sent for a QUEUED craft that never started, while another actor's craft
        ; holds the aliases: clear only what this actor holds.
        Actor recipient = SeverActionsNativeExt.Craft_GetRecipient(handle)
        ActorUtil.RemovePackageOverride(akActor, CraftAtForgePackage)
        bool held = false
        if CrafterAlias.GetReference() == akActor
            ForgeAlias.Clear()
            CrafterAlias.Clear()
            held = true
        endif
        if CrafterApproachAlias.GetReference() == akActor
            CrafterApproachAlias.Clear()
            RecipientAlias.Clear()
            held = true
        endif
        akActor.EvaluatePackage()
        if held
            SkyrimNetApi.RegisterPersistentEvent(akActor.GetDisplayName() + " stopped what they were doing.", akActor, recipient)
        endif

    elseif strArg == "TermAbortNoWS"
        ; Defensive: no native path enters this state (Begin rejects a null workstation).
        string wsType = SeverActionsNativeExt.Craft_GetWorkstationType(handle)
        Actor recipient = SeverActionsNativeExt.Craft_GetRecipient(handle)
        bool recipientIsPlayer = (recipient == Game.GetPlayer())
        if recipientIsPlayer
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("crafting.noWorkstationNearby", ("" + wsType)))
        endif

    endif
EndEvent

; UTILITY

string Function GetDatabaseStats()
    string result = ""
    if SeverActionsNative.IsRecipeDBLoaded()
        result += "RecipeDB: loaded"
    else
        result += "RecipeDB: NOT loaded"
    endif
    if SeverActionsNative.IsAlchemyDBLoaded()
        result += ", AlchemyDB: loaded"
    else
        result += ", AlchemyDB: NOT loaded"
    endif
    return result
EndFunction
