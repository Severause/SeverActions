Scriptname SeverActions_Crafting extends Quest
{Crafting entry points + native-orchestrator bridge.

Item lookup is delegated to the native RecipeDB / AlchemyDB. Workstation
finding is also native. The full orchestration (walk → animate → return →
hand off) lives in C++ as SeverActionsNative::CraftingOrchestrator;
this script is now just:

  1. The SkyrimNet-facing entry points (CraftItem_Internal, CookMeal_Internal,
     BrewPotion_Internal) — each does item+workstation detection, then calls
     SeverActionsNativeExt.Craft_Begin and exits.
  2. A ModEvent listener (OnCraftPhaseChange) that the C++ orchestrator
     fires once per phase transition. This handles the work that has no
     clean CommonLib native path: ActorUtil.AddPackageOverride,
     ReferenceAlias.ForceRefTo/Clear, EvaluatePackage, PlayIdle, SetLookAt,
     SkyrimNetApi.RegisterPersistentEvent / DirectNarration / UnregisterPackage,
     Debug.Notification.

Concurrency: the orchestrator enforces a single-active-session rule (queued
otherwise). The aliases below remain quest-scoped singletons; per-instance
aliases via CK record changes would lift the constraint but are out of scope.}

; =============================================================================
; PROPERTIES - Set in Creation Kit
; =============================================================================

Package Property CraftAtForgePackage Auto
{AI package that drives the NPC to use the workstation. Reused for forge /
cooking pot / oven / alchemy lab. Name is historical.}

ReferenceAlias Property CrafterAlias Auto
{Alias bound to the NPC for the workstation package.}

ReferenceAlias Property ForgeAlias Auto
{Alias bound to the workstation. Name is historical; holds any workstation.}

ReferenceAlias Property CrafterApproachAlias Auto
{Alias bound to the NPC for the recipient-approach package.}

ReferenceAlias Property RecipientAlias Auto
{Alias bound to the recipient of the crafted item.}

Idle Property IdleGive Auto
{Give-item animation.}

; =============================================================================
; CONFIGURATION
; =============================================================================

float Property SEARCH_RADIUS = 2000.0 Auto
{Radius to search for workstations (game units; ~28 m).}

int Property CRAFT_PACKAGE_PRIORITY = 100 Auto
{Priority for the workstation package override. Must outrank dialogue (50–80).}

; CRAFT_TIME, INTERACTION_DISTANCE, and the arrival timeouts now live as
; constants inside CraftingOrchestrator.h (kCraftTimeSeconds = 5,
; kWorkstationInteractionDistance = 150, kWorkstationArrivalTimeoutSec = 15,
; kRecipientArrivalTimeoutSec = 20). Centralized there so a tuning change
; only touches one place.

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    RegisterForModEvent("SACraft_PhaseChange", "OnCraftPhaseChange")
    Debug.Trace("SeverActions_Crafting: Initialized; registered for SACraft_PhaseChange")
EndEvent

; OnPlayerLoadGame does NOT fire on Quest scripts (it's an Actor-only event).
; OnInit only fires the very first time the script attaches — existing saves
; where SeverActions_Crafting was already attached before this update never
; re-run OnInit, so the ModEvent registration would be missed entirely.
; Defense: the three entry-point functions below all call EnsureRegistered()
; first. RegisterForModEvent is idempotent, so this is cheap on every call
; and guaranteed-correct on every code path.

Function EnsureRegistered()
    RegisterForModEvent("SACraft_PhaseChange", "OnCraftPhaseChange")
    ; Commission deposit/balance PrismaUI confirm callback. Idempotent; bound
    ; here so the handler is live no matter which entry point fires first.
    RegisterForModEvent("SeverActions_CommissionPromptChoice", "OnCommissionPromptChoice")
EndFunction

; =============================================================================
; WORKSTATION FINDERS (thin native wrappers)
; =============================================================================

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

; =============================================================================
; SKYRIMNET ENTRY POINTS — called from action YAMLs
; Each one does item + workstation detection, then hands off to the C++
; orchestrator via Craft_Begin. Papyrus returns immediately; the C++ side
; drives the phases and fires SACraft_PhaseChange events that this script
; listens for below.
; =============================================================================

Function CraftItem_Internal(Actor akActor, string itemName, Actor akRecipient, int itemCount = 1)
    {Generic crafting entry point. Auto-detects item type and routes to the
    matching workstation: smithing → forge, cooking → cooking pot,
    potion/poison → alchemy lab.}

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
    {Shared tail for the three entry points. Handles the cases the
    orchestrator won't see — null item / null workstation — and dispatches
    successful starts. Failure paths fire DirectNarration for the LLM and a
    player Debug.Notification.}

    Actor recipient = akRecipient
    if !recipient
        recipient = Game.GetPlayer()
    endif
    bool recipientIsPlayer = (recipient == Game.GetPlayer())

    if !itemForm
        if recipientIsPlayer
            Debug.Notification("Cannot craft: " + originalName)
        endif
        SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " doesn't know how to make " + originalName + ".", akActor, recipient)
        return
    endif

    if !workstation
        if recipientIsPlayer
            Debug.Notification("No " + workstationType + " nearby!")
        endif
        SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " can't find a " + workstationType + " nearby.", akActor, recipient)
        return
    endif

    int handle = SeverActionsNativeExt.Craft_Begin(akActor, itemForm, workstation, akRecipient, itemCount, workstationType, actionVerb)

    if handle == 0
        ; Rejection from the orchestrator. Only happens on null arg failure
        ; (we already null-checked above, so this is defensive).
        if recipientIsPlayer
            Debug.Notification(akActor.GetDisplayName() + " can't start the task right now.")
        endif
        SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " is unable to begin " + actionVerb + " " + itemForm.GetName() + " right now.", akActor, recipient)
        return
    endif

    Debug.Trace("SeverActions_Crafting: dispatched handle=" + handle + " for " + itemForm.GetName() + " on " + akActor.GetDisplayName())
EndFunction

; =============================================================================
; DEFERRED COMMISSIONS — CommissionItem / CollectCommission entry points
; =============================================================================
; The instant-craft path above (CraftItem_Internal → CraftingOrchestrator) is
; untouched. This is the *deferred* path: the smith agrees to make something
; and have it ready in a few days. State lives in the native CommissionStore
; (cosave record 'CMSN'); see the SeverActionsNativeExt.psc 'CMSN' block.
;
; Economy (locked v1 — "Simple"): priceTotal = item gold value × count; take a
; 50% deposit at order time; the balance is due at pickup via a Yes/No confirm.
; If the player can't/won't pay the balance, the smith keeps holding the item
; (the commission stays Ready). No DebtStore involvement.
;
; No workstation is required — the smith works off-screen on their own time.

Form Function ResolveCraftableForm(string itemName)
    {Resolve a craftable item name to its output Form using the same DB
    priority as CraftItem_Internal (smithing → cooking → potion → poison).
    Guarantees "if CraftItem could make it, CommissionItem can too." None if
    no recipe matches.}
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
    {Human phrasing for the smith's narration. Mirrors the buckets the native
    ParseEtaDays produces.}
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

; =============================================================================
; COMMISSION CONFIRM — pending state + shared helpers
; -----------------------------------------------------------------------------
; The deposit (order) and balance (pickup) confirms run through a non-pausing
; PrismaUI overlay (PrismaUICommissionPromptBridge), falling back to a modal
; SkyMessage when PrismaUI isn't available. Because the overlay is async, the
; order context is stashed here between OpenPrompt and the
; SeverActions_CommissionPromptChoice callback. The bridge enforces ONE prompt
; in flight at a time, so a single slot is safe.
; =============================================================================

String  m_commMode             ; "deposit" | "balance" | "" (idle)
Actor   m_commSmith
Form    m_commItem
Int     m_commCount
Int     m_commPrice            ; full price (value × count)
Int     m_commDeposit          ; deposit (taken at order; shown at pickup)
Int     m_commBalance          ; balance due (taken now in balance mode)
Float   m_commEtaDays
Int     m_commId               ; balance mode: the Ready commission id
String  m_commItemName         ; cached display name for narration

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

; Take the stashed deposit, record the order, narrate. Shared by the PrismaUI
; accept and the SkyMessage fallback (deposit mode).
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

    ; Re-check affordability at confirm time — gold may have changed while the
    ; non-pausing overlay was open.
    Form goldForm = Game.GetForm(0xF)
    if player.GetGoldAmount() < deposit
        Debug.Notification("You can't afford the " + deposit + " gold deposit.")
        SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " won't start the work without the " + deposit + " gold deposit, which the player can't cover.", akActor, player)
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
    Debug.Notification("Commissioned " + itemLabel + " — " + deposit + " gold deposit paid, " + balanceDue + " gold due on pickup.")
    SkyrimNetApi.RegisterPersistentEvent(akActor.GetDisplayName() + " agreed to craft " + itemLabel + " for the player, ready " + etaPhrase + ". Took a " + deposit + " gold deposit; " + balanceDue + " gold is due when the player collects it.", akActor, player)
    _ClearCommPending()
EndFunction

; Take the stashed balance (if any), hand over the item, clear the record.
; Shared by the PrismaUI accept, the SkyMessage fallback, and the fully-paid
; fast path (balance mode).
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

    ; The commission must still exist (the player could have collected it via a
    ; second smith conversation while this overlay was open).
    if !SeverActionsNativeExt.Native_Commission_Exists(id)
        _ClearCommPending()
        return
    endif

    if balanceDue > 0
        if player.GetGoldAmount() < balanceDue
            Debug.Notification("You can't afford the " + balanceDue + " gold balance.")
            SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " holds onto " + itemLabel + " — the player can't cover the " + balanceDue + " gold balance.", akActor, player)
            _ClearCommPending()
            return
        endif
        Form goldForm = Game.GetForm(0xF)
        player.RemoveItem(goldForm, balanceDue, true)
        SeverActionsNativeExt.Native_Ledger_RecordEvent(balanceDue, true, "commission", akActor, "", "balance: " + itemLabel, 0)
    endif

    ; abSilent = FALSE so the player actually SEES the finished piece arrive
    ; ("Ebony Dagger Added") — the commission item is conjured straight into the
    ; player's inventory here (the smith never physically holds it; the forge is
    ; virtual), so without the vanilla add message the handover felt invisible
    ; next to the payment popup.
    player.AddItem(itemForm, itemCount, false)
    ; Log to the completed-commission history (World → Ledger) BEFORE removing,
    ; while the row's data is still present for the native to snapshot.
    SeverActionsNativeExt.Native_Commission_RecordCompleted(id)
    SeverActionsNativeExt.Native_Commission_Remove(id)
    Debug.Notification("Collected " + itemLabel + " from " + akActor.GetDisplayName() + ".")
    SkyrimNetApi.RegisterPersistentEvent(akActor.GetDisplayName() + " handed over the finished " + itemLabel + " to the player.", akActor, player)
    _ClearCommPending()
EndFunction

; ModEvent from PrismaUICommissionPromptBridge — fires on button click, the
; auto-deny timer, or an Escape-driven silent close. The mode + order context
; live in m_comm* (single in-flight). strArg = "accept"/"deny"; sender = smith.
Event OnCommissionPromptChoice(String asEventName, String asChoice, Float afAmount, Form akSender)
    Actor smith = akSender as Actor
    if !smith
        return
    endif
    ; Guard a stale callback for a different in-flight smith.
    if m_commSmith && smith != m_commSmith
        Debug.Trace("[SeverActions_Crafting] OnCommissionPromptChoice: sender mismatch — ignoring")
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
            SkyrimNetApi.DirectNarration("The player decided not to commission " + _CommLabel(m_commItemName, m_commCount) + " from " + smith.GetDisplayName() + " after all.", smith, player)
        elseif m_commMode == "balance"
            SkyrimNetApi.DirectNarration("The player decided not to collect " + _CommLabel(m_commItemName, m_commCount) + " from " + smith.GetDisplayName() + " just yet.", smith, player)
        endif
        _ClearCommPending()
    endif
EndEvent

Function CommissionItem_Internal(Actor akActor, string itemName, string etaText, int itemCount = 1, int quotedTotal = 0)
    {Deferred-craft entry point (CommissionItem action). The smith agrees to
    forge `itemName` and have it ready later. A 50% deposit is confirmed via a
    PrismaUI overlay (or SkyMessage fallback) before any gold is taken; the
    balance is due at pickup. `etaText` is the smith's own prose estimate ("a
    couple days") — the native NL parser converts it to game days. `quotedTotal`
    is the smith's own in-character price for the whole order (the LLM decides);
    it drives the charge directly so the popup matches the spoken quote. Falls
    back to the item's market value × count only when nothing was quoted.}

    if !akActor
        return
    endif
    EnsureRegistered()
    if itemCount < 1
        itemCount = 1
    elseif itemCount > 100
        ; Upper-clamp the LLM-supplied count. Without this, a hallucinated or
        ; prompt-injected large count overflows `unitValue * itemCount` (a 32-bit
        ; Papyrus multiply) to a NEGATIVE priceTotal, which the native floors to
        ; 0 — so the player pays a 1-gold deposit and collects a free giant stack.
        ; 100 is well clear of any legitimate craft order.
        itemCount = 100
    endif

    Actor player = Game.GetPlayer()

    ; Item must be something the smith could actually craft.
    Form itemForm = ResolveCraftableForm(itemName)
    if !itemForm
        Debug.Notification("Cannot commission: " + itemName)
        SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " doesn't know how to make " + itemName + ".", akActor, player)
        return
    endif

    ; Global cap guard — the native enforces it too, but this gives a clean
    ; in-character decline instead of a silent 0 return.
    if SeverActionsNativeExt.Native_Commission_GetCount() >= 10
        SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " has too many orders backed up to take another commission right now.", akActor, player)
        return
    endif

    ; Price: the smith's own quoted total (LLM-decided) drives the charge so the
    ; popup matches the spoken quote. The item's market value × count is only a
    ; fallback when no figure was quoted. Either way the deposit is 50% up front.
    int priceTotal = quotedTotal
    if priceTotal <= 0
        int unitValue = itemForm.GetGoldValue()
        if unitValue < 1
            unitValue = 1
        endif
        priceTotal = unitValue * itemCount
    endif
    ; Clamp to a sane range — guards a hallucinated/garbage quote from charging
    ; an absurd sum or overflowing the deposit math.
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

    ; Deposit required — smith declines if the player can't cover it (checked
    ; up front so we never raise the confirm for an order they can't place).
    int playerGold = player.GetGoldAmount()
    if playerGold < deposit
        Debug.Notification("You can't afford the " + deposit + " gold deposit.")
        SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " won't start the work without a " + deposit + " gold deposit, which the player can't cover right now.", akActor, player)
        return
    endif

    ; ETA from the smith's own words. Native NL parse → relative game days.
    Float etaDays = SeverActionsNativeExt.Native_Commission_ParseEtaDays(etaText)

    ; Stash the order so the async confirm (or fallback) can place it.
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

    ; Prefer the non-pausing PrismaUI deposit confirm; the choice returns via
    ; OnCommissionPromptChoice. Fall back to a modal SkyMessage when PrismaUI
    ; isn't available or another prompt is already open.
    if SeverActionsNativeExt.PrismaUI_IsCommissionPromptAvailable() && !SeverActionsNativeExt.PrismaUI_IsCommissionPromptOpen()
        if SeverActionsNativeExt.PrismaUI_OpenCommissionPrompt(akActor, deposit, akActor.GetDisplayName(), m_commItemName, priceTotal, deposit, balanceDue, "deposit", 30000)
            return
        endif
    endif

    String itemLabel = _CommLabel(m_commItemName, itemCount)
    String choice = SkyMessage.Show(akActor.GetDisplayName() + " will forge " + itemLabel + " for " + priceTotal + " gold. Pay the " + deposit + " gold deposit now? (" + balanceDue + " due on pickup)", "Pay " + deposit + " deposit", "Cancel", getIndex = true)
    if choice == "0"
        _PlaceCommission()
    else
        SkyrimNetApi.DirectNarration("The player decided not to commission " + itemLabel + " from " + akActor.GetDisplayName() + " after all.", akActor, player)
        _ClearCommPending()
    endif
EndFunction

Function CollectCommission_Internal(Actor akActor)
    {Pickup entry point (CollectCommission action; gated by the
    has_ready_commission decorator). Finds the smith's finished order, takes
    the balance via a Yes/No confirm, hands over the item, and clears the
    record. If the player declines or can't pay, the smith keeps holding it.}

    if !akActor
        return
    endif
    EnsureRegistered()
    Actor player = Game.GetPlayer()

    int id = SeverActionsNativeExt.Native_Commission_FindReadyForCrafter(akActor)
    if id == 0
        ; Nothing ready — distinguish "still working" from "no order at all".
        if SeverActionsNativeExt.Native_Commission_CountForCrafter(akActor) > 0
            SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " isn't finished with the player's commission yet.", akActor, player)
        else
            SkyrimNetApi.DirectNarration("The player has nothing to collect from " + akActor.GetDisplayName() + ".", akActor, player)
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

    ; Item form vanished (mod uninstalled between order and pickup) — clear the
    ; dangling record so the smith stops claiming it's ready. Checked BEFORE the
    ; balance is taken so the player is never charged for a piece that can't be
    ; handed over. The deposit is kept (it paid for labor already done).
    if !itemForm
        SeverActionsNativeExt.Native_Commission_Remove(id)
        SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " can't seem to find the finished piece.", akActor, player)
        return
    endif

    ; Stash the balance-mode context so the async confirm (or fallback) can
    ; take payment and hand over.
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

    ; Fully-paid orders (balanceDue <= 0) need no confirm — hand over now.
    if balanceDue <= 0
        _CollectBalanceAndHandover()
        return
    endif

    ; Prefer the non-pausing PrismaUI balance confirm; choice returns via
    ; OnCommissionPromptChoice. Fall back to a modal SkyMessage otherwise.
    if SeverActionsNativeExt.PrismaUI_IsCommissionPromptAvailable() && !SeverActionsNativeExt.PrismaUI_IsCommissionPromptOpen()
        if SeverActionsNativeExt.PrismaUI_OpenCommissionPrompt(akActor, balanceDue, akActor.GetDisplayName(), itemName, m_commPrice, m_commDeposit, balanceDue, "balance", 30000)
            return
        endif
    endif

    String choice = SkyMessage.Show(akActor.GetDisplayName() + "'s work is done — your " + itemName + " is ready. Pay the remaining " + balanceDue + " gold?", "Pay " + balanceDue + " gold", "Not now", getIndex = true)
    if choice == "0"
        _CollectBalanceAndHandover()
    else
        ; Declined — smith keeps holding it (commission stays Ready).
        SkyrimNetApi.DirectNarration("The player decided not to collect " + itemLabel + " from " + akActor.GetDisplayName() + " just yet.", akActor, player)
        _ClearCommPending()
    endif
EndFunction

Function TickCommissions()
    {Drain the native CommissionStore tick queue. Mirrors SeverActions_Debt's
    TickDebts — the maturation walk (Ordered → Ready) lives in
    CommissionStore::Tick (C++); Papyrus only registers the SkyrimNet events
    because PublicAPI exposes no native event-register surface.

    Kinds:  0 = Regular, 1 = ShortLived, 2 = Persistent.
    commission_ready events are ShortLived (kind 1).}
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

; =============================================================================
; MODEVENT LISTENER — driven by SeverActionsNative::CraftingOrchestrator
; =============================================================================
; Event args:
;   strArg = phase label (see switch below)
;   numArg = craft handle (Int cast to Float)
;   sender = the crafting actor
;
; The handler queries the orchestrator for whatever refs it needs by handle
; and performs the work that has no clean CommonLib native path.

Event OnCraftPhaseChange(string eventName, string strArg, float numArg, Form sender)
    int handle = numArg as Int
    Actor akActor = sender as Actor
    if !akActor
        Debug.Trace("SeverActions_Crafting: PhaseChange handle=" + handle + " phase='" + strArg + "' — null sender, skipping")
        return
    endif

    Debug.Trace("SeverActions_Crafting: PhaseChange handle=" + handle + " phase='" + strArg + "' actor=" + akActor.GetDisplayName())

    if strArg == "Phase1Apply"
        ; Bind workstation + crafter aliases, apply package override, fire
        ; "begins" persistent event, unregister TalkToPlayer.
        ObjectReference ws = SeverActionsNativeExt.Craft_GetWorkstation(handle)
        Actor recipient = SeverActionsNativeExt.Craft_GetRecipient(handle)
        string wsType = SeverActionsNativeExt.Craft_GetWorkstationType(handle)
        if ws
            ForgeAlias.ForceRefTo(ws)
            CrafterAlias.ForceRefTo(akActor)
            ActorUtil.AddPackageOverride(akActor, CraftAtForgePackage, CRAFT_PACKAGE_PRIORITY, 1)
            akActor.EvaluatePackage()
            SkyrimNetApi.RegisterPersistentEvent(akActor.GetDisplayName() + " begins working at the " + wsType + ".", akActor, recipient)
            SkyrimNetApi.UnregisterPackage(akActor, "TalkToPlayer")
        endif

    elseif strArg == "Phase2Cleanup"
        ; Remove package override + clear workstation aliases. Fire "finishes".
        Actor recipient = SeverActionsNativeExt.Craft_GetRecipient(handle)
        string wsType = SeverActionsNativeExt.Craft_GetWorkstationType(handle)
        ActorUtil.RemovePackageOverride(akActor, CraftAtForgePackage)
        ForgeAlias.Clear()
        akActor.EvaluatePackage()
        Utility.Wait(2.0)
        CrafterAlias.Clear()
        SkyrimNetApi.RegisterPersistentEvent(akActor.GetDisplayName() + " finishes at the " + wsType + ".", akActor, recipient)

    elseif strArg == "Phase3Approach"
        ; Bind recipient + approach aliases. EvaluatePackage to start the walk.
        Actor recipient = SeverActionsNativeExt.Craft_GetRecipient(handle)
        if recipient
            RecipientAlias.ForceRefTo(recipient)
            CrafterApproachAlias.ForceRefTo(akActor)
            akActor.EvaluatePackage()
        endif

    elseif strArg == "Phase4HandOff:anim"
        ; Arrived at recipient. Clear approach aliases, face, play give-idle.
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
        ; Soft-fail timeout. Just clear aliases; engine still teleports the
        ; item transfer in C++ Terminate.
        CrafterApproachAlias.Clear()
        RecipientAlias.Clear()
        akActor.EvaluatePackage()

    elseif strArg == "TermComplete"
        ; Item already transferred by C++. Narrate + notify player.
        Actor recipient = SeverActionsNativeExt.Craft_GetRecipient(handle)
        bool recipientIsPlayer = (recipient == Game.GetPlayer())
        string narration = recipient.GetDisplayName() + " has received an item from " + akActor.GetDisplayName() + "."
        SkyrimNetApi.DirectNarration(narration, akActor, recipient)
        if recipientIsPlayer
            Debug.Notification("Received item from " + akActor.GetDisplayName())
        endif

    elseif strArg == "TermAbortNoArrival"
        ; Couldn't reach the workstation. Defensive cleanup + narrate failure.
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
        SkyrimNetApi.RegisterPersistentEvent(msg, akActor, recipient)
        SkyrimNetApi.DirectNarration(msg, akActor, recipient)
        if recipientIsPlayer
            Debug.Notification(akActor.GetDisplayName() + " couldn't reach the " + wsType + ".")
        endif

    elseif strArg == "TermCancelled"
        ; Cancelled mid-flight. Full alias + override cleanup.
        Actor recipient = SeverActionsNativeExt.Craft_GetRecipient(handle)
        ActorUtil.RemovePackageOverride(akActor, CraftAtForgePackage)
        ForgeAlias.Clear()
        CrafterAlias.Clear()
        CrafterApproachAlias.Clear()
        RecipientAlias.Clear()
        akActor.EvaluatePackage()
        SkyrimNetApi.RegisterPersistentEvent(akActor.GetDisplayName() + " stopped what they were doing.", akActor, recipient)

    elseif strArg == "TermAbortNoWS"
        ; Defensive — DispatchToOrchestrator already filters this case.
        string wsType = SeverActionsNativeExt.Craft_GetWorkstationType(handle)
        Actor recipient = SeverActionsNativeExt.Craft_GetRecipient(handle)
        bool recipientIsPlayer = (recipient == Game.GetPlayer())
        if recipientIsPlayer
            Debug.Notification("No " + wsType + " nearby!")
        endif

    endif
EndEvent

; =============================================================================
; UTILITY
; =============================================================================

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
