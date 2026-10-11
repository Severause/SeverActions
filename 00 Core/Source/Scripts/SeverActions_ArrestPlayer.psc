Scriptname SeverActions_ArrestPlayer Extends Quest
{Player-arrest FSM: a guard confronts the PLAYER about their tracked bounty (arrestplayer.yaml),
 the Magelight prompt (SkyMessage fallback) offers pay / submit / resist / bribe / persuade, and
 the AI ends a persuasion (accept/rejectpersuasion.yaml). The native PersuasionMonitor and
 ResistArrestMonitor own the persuasion timer and the post-resist cleanup and report by ModEvent.
 The six tunables (ArrestPlayerCooldown, PersuasionTimeLimit, ...) stay on SeverActions_Arrest,
 read through ArrestScript: moving them would drop the values existing saves hold.}

SeverActions_Arrest Property ArrestScript Auto
{The main arrest script (resolved in Maintenance when unfilled). Every function here needs it:
 packages, keywords, tunables, BountyScript and the DebugMsg / crime-faction / hold helpers.}

; ===== FSM STATE =====

Actor ConfrontingGuard          ; None = no confrontation
Faction ConfrontingFaction      ; the guard's crime faction
Int ConfrontingBounty           ; tracked bounty when the confrontation started (the quoted fine)
Bool PersuadeAttempted          ; persuade is offered once per confrontation
Bool PaymentFailed              ; a pay or bribe fell short: no more payment options
Bool InPersuasionMode
Float PersuasionStartTime       ; Unused (the native PersuasionMonitor owns the clock); kept declared for existing saves.

Float LastArrestTime            ; real time the last confrontation started (ArrestPlayerCooldown)
Faction ResistArrestFaction     ; hold whose vanilla crime gold goes back to tracked when the resist fight ends
Float ResistArrestStartTime     ; Never read (the native ResistArrestMonitor owns the clock); kept declared for existing saves.
; ===== PARLEY STATE =====
; A guard questioning one of the player's people over a bounty before any arrest (ArrestNPC on a
; protected suspect). One at a time; ParleyDriver.h keeps the two talking and reports by
; SeverActions_Parley. The state-7 arrest session is the native mirror.

Actor ParleyGuard               ; None = no parley
Actor ParleySuspect
Faction ParleyFaction           ; the hold whose bounty is in question
ObjectReference ParleyJail      ; that hold's jail marker, for custody
Int ParleyQuote                 ; the bounty when the parley opened (what paying clears)
Int ParleyCost                  ; the fine, or the bribe at or above ArrestBountyThreshold
Bool ParleyBribe
Bool ParleyPleaRefused          ; the guard pressed the charge: no verdict on the plea any more
Bool ParleyNoCoin               ; the suspect came up short: payment is not offered again
Bool ParleyDemand               ; the guard demands an answer now
Bool ParleyResisting            ; the suspect refused: the fight is on
Bool ParleyIntervened           ; the player joined that fight on the suspect's side: EndParley leaves the fight alone
Int ParleyEpoch                 ; bumped whenever the slot clears: a stack that yielded reads it to see a close
Float Property PARLEY_COOLDOWN = 300.0 AutoReadOnly
{Real seconds after a parley ends before a guard can question the same suspect again.}

Float Property ResistMaxWaitSeconds = 600.0 Auto
{Real seconds the native ResistArrestMonitor waits for the player to leave combat before it fires
 "timeout" and the post-resist cleanup runs anyway (a combat lock-out).}

; ===== LIFECYCLE =====

Function Maintenance()
    {Resolve ArrestScript and register this script's ModEvents. Idempotent; called from
     SeverActions_Arrest.Maintenance.}
    If !ArrestScript
        Quest q = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
        If q
            ArrestScript = q as SeverActions_Arrest
        EndIf
    EndIf

    ; Shared native event, canonical callback (M-E): Ambush registers it too, and the one monitor
    ; slot also serves the ambush parley and the camp challenge.
    RegisterForModEvent("SeverActions_PersuasionFailed", "OnPersuasionFailedEvent")

    RegisterForModEvent("SeverActions_ResistCombatEnded", "OnResistCombatEndedEvent")

    ; The Magelight prompt's choice: strArg = pay_fine|submit|resist|bribe|persuade,
    ; sender = guard, numArg = bounty.
    RegisterForModEvent("SeverActions_ArrestPromptChoice", "OnArrestPromptChoiceEvent")

    ; The parley's driver (ParleyDriver.h): strArg = what happened, sender = who to prod or the suspect.
    RegisterForModEvent("SeverActions_Parley", "OnParleyEvent")
EndFunction

Function OnGameLoaded()
    {Load recovery, from the arrest provider's stage 1 (a Quest script never gets OnPlayerLoadGame).
     Script vars survive a save; the native monitors and chronometer ticks do not, so re-arm
     whichever the FSM state still needs.}

    ; A reloaded persuasion gets a fresh full time budget.
    If InPersuasionMode && ConfrontingGuard != None
        If ArrestScript
            ArrestScript.DebugMsg("PlayerScript OnPlayerLoadGame: re-arming native PersuasionMonitor")
        EndIf
        SeverActionsNative.Native_Persuasion_Begin(ConfrontingGuard, Game.GetPlayer(), ArrestScript.PersuasionTimeLimit, ArrestScript.PersuasionFollowDistance)
    EndIf

    ; Mid-resist save: the vanilla bounty still needs re-absorbing when combat ends.
    If ResistArrestFaction != None
        If ArrestScript
            ArrestScript.DebugMsg("PlayerScript OnPlayerLoadGame: re-arming native ResistArrestMonitor")
        EndIf
        SeverActionsNative.Native_Resist_Begin(ResistMaxWaitSeconds)
    EndIf

    ; Mid-confrontation save: without the prompt watchdog nothing re-shows the prompt and the
    ; FSM wedges. The tick handler is state-guarded.
    If ConfrontingGuard != None && !InPersuasionMode
        ChronoArm(2.0)
    EndIf

    ; A parley saved mid-talk resumes with a fresh time budget; the driver is not saved.
    If ParleySuspect != None
        _ResumeParley()
    EndIf
EndFunction

Function ChronoArm(Float afSeconds)
    {Arm this script's one-shot chronometer tick (see the Chronometer block in
     SeverActionsNativeExt2.psc). Re-arm replaces the pending tick; ticks do not survive a load,
     and one in-flight wake can land after Chrono_Cancel, so the handler stays state-guarded.}
    RegisterForModEvent("SeverActions_Tick_ArrestPlayer", "OnChronoTick_ArrestPlayer")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_ArrestPlayer", afSeconds)
EndFunction

Event OnChronoTick_ArrestPlayer(String eventName, String strArg, Float numArg, Form sender)
    {The script's only tick: the Magelight prompt's re-open watchdog, every 2s from the prompt's
     open until a choice. An Esc-dismissed prompt is re-shown so the FSM cannot strand; an open one
     is left to its own 60s timeout.}

    If ConfrontingGuard == None
        Return
    EndIf
    If InPersuasionMode
        Return
    EndIf

    If !SeverActionsNative.Magelight_IsArrestPromptAvailable()
        ; Magelight gone: ShowPlayerArrestMenu falls back to SkyMessage.
        ShowPlayerArrestMenu()
        Return
    EndIf

    If SeverActionsNative.Magelight_IsArrestPromptOpen()
        ChronoArm(2.0)
        Return
    EndIf

    ; Esc-dismissed with the confrontation still live: reopen. Esc means "give me a moment",
    ; not "I give up"; the timeout restarts on the new open.
    If ArrestScript
        ArrestScript.DebugMsg("Arrest prompt dismissed but FSM is live - reopening")
    EndIf
    ShowPlayerArrestMenu()
EndEvent

Event OnArrestPromptChoiceEvent(String asEventName, String asChoice, Float afBounty, Form akSender)
    {The Magelight prompt's choice (a click, or "submit" when its 60s timeout runs out), routed to
     the same Handle*() functions as the SkyMessage path. akSender is the prompt's guard: a click
     for a confrontation that has since cleared or changed guard is stale and dropped.}

    If ConfrontingGuard == None || ConfrontingFaction == None
        If ArrestScript
            ArrestScript.DebugMsg("ArrestPromptChoice arrived but state is clean - ignoring")
        EndIf
        Return
    EndIf

    If akSender != ConfrontingGuard
        If ArrestScript
            ArrestScript.DebugMsg("ArrestPromptChoice for wrong guard - ignoring stale event")
        EndIf
        Return
    EndIf

    ; Stop the re-open watchdog; each handler clears the state or sets up its own follow-up
    ; (a menu re-show, the persuasion).
    SeverActionsNativeExt2.Chrono_Cancel("SeverActions_Tick_ArrestPlayer")

    If ArrestScript
        ArrestScript.DebugMsg("ArrestPromptChoice: " + asChoice)
    EndIf

    If asChoice == "pay_fine"
        HandlePayFine()
    ElseIf asChoice == "submit"
        HandleSubmitToArrest()
    ElseIf asChoice == "resist"
        HandleResistArrest()
    ElseIf asChoice == "bribe"
        HandleBribe()
    ElseIf asChoice == "persuade"
        HandlePersuade()
    Else
        If ArrestScript
            ArrestScript.DebugMsg("WARNING: unknown ArrestPromptChoice '" + asChoice + "'")
        EndIf
    EndIf
EndEvent

Event OnPersuasionFailedEvent(String asEventName, String asReason, Float afUnused, Form akSender)
    {Native PersuasionMonitor failure: asReason "timeout" | "distance" | "died", akSender = the
     window's actor (afUnused is 0: a float cannot carry a FormID). Shared with the ambush and
     the camp parley, so another actor's event is ignored. "died" releases the guard's follow and
     clears the state (no menu for a dead guard); the others go to OnPersuasionFailed.}
    If ConfrontingGuard == None
        Return
    EndIf
    ; Exact match: a None sender is a window whose actor no longer resolves, which is never
    ; this guard (ConfrontingGuard would read None too).
    If akSender != ConfrontingGuard
        Return
    EndIf
    If asReason == "died"
        If ArrestScript
            ArrestScript.DebugMsg("Persuasion ended - guard died (native monitor)")
        EndIf
        StopPersuasionFollow()
        ClearPlayerConfrontationState()
    Else
        OnPersuasionFailed(asReason)
    EndIf
EndEvent


Function ResetCooldowns()
    {Zero LastArrestTime: real time restarts at 0 each launch, so a saved value would read as a
     phantom cooldown. Called from SeverActions_Arrest.ResetSessionCooldowns (OnInit, OnGameLoaded).}
    LastArrestTime = 0.0
EndFunction

; ===== POST-RESIST CLEANUP =====

Event OnResistCombatEndedEvent(String asEventName, String asReason, Float afUnused, Form akSender)
    {Native ResistArrestMonitor: asReason "combatEnd" (the player left combat) or "timeout" (still
     in combat after ResistMaxWaitSeconds). Either way, move the resisted hold's vanilla crime gold
     back into the tracked bounty and clear the resist state.}

    If ResistArrestFaction == None
        ; Stale or duplicate event.
        Return
    EndIf

    Int vanillaBounty = ResistArrestFaction.GetCrimeGold()
    Bool watchdog = (asReason == "timeout")

    If vanillaBounty > 0
        If ArrestScript && ArrestScript.BountyScript
            ; Mod, not Set: the tracked bounty may have grown during the fight.
            ArrestScript.BountyScript.ModTrackedBounty(ResistArrestFaction, vanillaBounty)
        EndIf
        ResistArrestFaction.SetCrimeGold(0)
        ResistArrestFaction.SetCrimeGoldViolent(0)
        If ArrestScript
            If watchdog
                ArrestScript.DebugMsg("Post-resist cleanup: WATCHDOG fired - re-absorbing " + vanillaBounty + " vanilla bounty (native monitor reports combat-lockout)")
            Else
                ArrestScript.DebugMsg("Post-resist cleanup: re-absorbed " + vanillaBounty + " vanilla bounty back to tracked system (native combat-end signal)")
            EndIf
        EndIf
    ElseIf watchdog && ArrestScript
        ArrestScript.DebugMsg("Post-resist cleanup: WATCHDOG fired (vanilla bounty already 0; clearing state)")
    EndIf

    ResistArrestFaction = None
    ResistArrestStartTime = 0.0
EndEvent

; ===== ARRESTPLAYER (arrestplayer.yaml) =====

Bool Function ArrestPlayer_Internal(Actor akGuard)
    {akGuard confronts the player about their tracked bounty in the guard's hold and opens the
     arrest menu. False when refused (no or dead guard, no crime faction, a live confrontation,
     the cooldown). Also called by SeverActions_Arrest (OrderArrest, the turnMeIn verb).}

    If !ArrestScript
        Return false
    EndIf

    If akGuard == None
        ArrestScript.DebugMsg("ERROR: ArrestPlayer called with None guard")
        Return false
    EndIf

    If akGuard.IsDead()
        ArrestScript.DebugMsg("ERROR: Guard is dead")
        Return false
    EndIf

    If ConfrontingGuard != None
        ArrestScript.DebugMsg("Already in confrontation with " + ConfrontingGuard.GetDisplayName() + ", ignoring new arrest request")
        Return false
    EndIf

    ; Cooldown: no re-arrest during or right after a confrontation.
    Float currentTime = Utility.GetCurrentRealTime()
    If LastArrestTime > 0.0 && (currentTime - LastArrestTime) < ArrestScript.ArrestPlayerCooldown
        Float remaining = ArrestScript.ArrestPlayerCooldown - (currentTime - LastArrestTime)
        ArrestScript.DebugMsg("ArrestPlayer on cooldown, " + remaining + " seconds remaining")
        Return false
    EndIf

    Faction crimeFaction = ArrestScript.GetCrimeFactionForGuard(akGuard)
    If crimeFaction == None
        ArrestScript.DebugMsg("ERROR: Could not determine guard's crime faction")
        Return false
    EndIf

    ; The tracked bounty: SeverActions writes vanilla crime gold only for the jail and a resist.
    Int bounty = 0
    If ArrestScript.BountyScript
        bounty = ArrestScript.BountyScript.GetTrackedBounty(crimeFaction)
    EndIf
    If bounty <= 0
        ; No bounty yet (ReportCrime was never called): charge 300.
        bounty = 300
        If ArrestScript.BountyScript
            ArrestScript.BountyScript.SetTrackedBounty(crimeFaction, bounty)
        EndIf
        String holdName = ArrestScript.GetHoldNameForGuard(akGuard)
        ArrestScript.DebugMsg("Auto-added " + bounty + " bounty for arrest in " + holdName)
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrestplayer.bountyAddedGoldIn", ("" + bounty), ("" + holdName)))

        String eventMsg = akGuard.GetDisplayName() + " is arresting " + Game.GetPlayer().GetDisplayName() + " and has put a " + bounty + " gold bounty on them in " + holdName + "."
        SkyrimNetApi.RegisterPersistentEvent(eventMsg, akGuard, Game.GetPlayer())
    EndIf

    ; Re-check: the external calls above can yield to another ArrestPlayer call.
    If ConfrontingGuard != None
        ArrestScript.DebugMsg("WARNING: Already in a confrontation, canceling previous")
        CancelPlayerConfrontation()
    EndIf

    ConfrontingGuard = akGuard
    ConfrontingFaction = crimeFaction
    ConfrontingBounty = bounty
    LastArrestTime = Utility.GetCurrentRealTime() ; Start cooldown

    String holdName2 = ArrestScript.GetHoldNameForGuard(akGuard)
    ArrestScript.DebugMsg("Guard confronting player - Tracked Bounty: " + bounty + " in " + holdName2)

    ShowPlayerArrestMenu()

    Return true
EndFunction

Function ShowPlayerArrestMenu()
    {Show the arrest choice: the Magelight overlay (non-pausing) when available, else SkyMessage.
     Pay and bribe drop out after PaymentFailed, persuade after PersuadeAttempted; a bounty under
     ArrestBountyThreshold offers only pay (submit once payment failed) or refuse. The prompt's JS
     picks its buttons from the same three flags and must mirror these branches.}

    If !ArrestScript
        Return
    EndIf

    If ConfrontingGuard == None || ConfrontingFaction == None
        ArrestScript.DebugMsg("ERROR: ShowPlayerArrestMenu - invalid state")
        Return
    EndIf

    Int bounty = ConfrontingBounty
    Int bribeCost = (bounty as Float * ArrestScript.BribeMultiplier) as Int

    String holdName = ArrestScript.GetHoldNameForGuard(ConfrontingGuard)
    Bool lowBounty = (bounty < ArrestScript.ArrestBountyThreshold)
    String resultStr

    ; A failed open (host not ready, a prompt already open, another view focused) falls through
    ; to SkyMessage.
    If SeverActionsNative.Magelight_IsArrestPromptAvailable()
        String guardName = ConfrontingGuard.GetDisplayName()
        Bool opened = SeverActionsNative.Magelight_OpenArrestPrompt( \
            ConfrontingGuard, guardName, holdName, bounty, bribeCost, \
            PaymentFailed, PersuadeAttempted, lowBounty, 60000)
        If opened
            ; The choice arrives in OnArrestPromptChoiceEvent; the watchdog re-opens an Esc-dismissed prompt.
            ChronoArm(2.0)
            Return
        EndIf
    EndIf

    If lowBounty
        ; Low bounty: pay or refuse; submit replaces pay once payment failed.
        If PaymentFailed
            String bodyText = "You have a bounty of " + bounty + " gold in " + holdName + ". The guard won't accept payment attempts anymore."
            resultStr = ""
            If SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
                resultStr = SeverActions_SkyMessageLib.Show(bodyText, "Submit to Arrest", "Refuse", getIndex = true)
            EndIf
            ; "" = no selection (see HandleNoSelection): never let it reach the resist Else.
            If resultStr == ""
                HandleNoSelection()
            ElseIf resultStr == "0"
                HandleSubmitToArrest()
            Else
                HandleResistArrest()
            EndIf
        Else
            String bodyText = "You have a bounty of " + bounty + " gold in " + holdName + ". Pay your fine or face the consequences."
            resultStr = ""
            If SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
                resultStr = SeverActions_SkyMessageLib.Show(bodyText, "Pay Fine (" + bounty + " gold)", "Refuse", getIndex = true)
            EndIf
            ; "" = no selection: see HandleNoSelection.
            If resultStr == ""
                HandleNoSelection()
            ElseIf resultStr == "0"
                HandlePayFine()
            Else
                HandleResistArrest()
            EndIf
        EndIf
    Else
        ; High bounty: submit or resist, plus bribe and persuade while still offered.
        String bodyText = "You have a bounty of " + bounty + " gold in " + holdName + "."

        If PaymentFailed && PersuadeAttempted
            bodyText += " The guard has lost all patience. Submit or resist."
            resultStr = ""
            If SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
                resultStr = SeverActions_SkyMessageLib.Show(bodyText, "Submit to Arrest", "Resist Arrest", getIndex = true)
            EndIf
            ; "" = no selection: see HandleNoSelection.
            If resultStr == ""
                HandleNoSelection()
            ElseIf resultStr == "0"
                HandleSubmitToArrest()
            Else
                HandleResistArrest()
            EndIf

        ElseIf PaymentFailed && !PersuadeAttempted
            bodyText += " The guard won't accept payment anymore."
            resultStr = ""
            If SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
                resultStr = SeverActions_SkyMessageLib.Show(bodyText, "Submit to Arrest", "Resist Arrest", "Persuade", getIndex = true)
            EndIf
            ; "" = no selection: see HandleNoSelection.
            If resultStr == ""
                HandleNoSelection()
            ElseIf resultStr == "0"
                HandleSubmitToArrest()
            ElseIf resultStr == "1"
                HandleResistArrest()
            Else
                HandlePersuade()
            EndIf

        ElseIf !PaymentFailed && PersuadeAttempted
            bodyText += " The guard has lost patience. Make your choice now."
            resultStr = ""
            If SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
                resultStr = SeverActions_SkyMessageLib.Show(bodyText, "Submit to Arrest", "Resist Arrest", "Bribe (" + bribeCost + " gold)", getIndex = true)
            EndIf
            ; "" = no selection: see HandleNoSelection.
            If resultStr == ""
                HandleNoSelection()
            ElseIf resultStr == "0"
                HandleSubmitToArrest()
            ElseIf resultStr == "1"
                HandleResistArrest()
            Else
                HandleBribe()
            EndIf

        Else
            bodyText += " Submit to arrest or face the consequences."
            resultStr = ""
            If SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
                resultStr = SeverActions_SkyMessageLib.Show(bodyText, "Submit to Arrest", "Resist Arrest", "Bribe (" + bribeCost + " gold)", "Persuade", getIndex = true)
            EndIf
            ; "" = no selection: see HandleNoSelection.
            If resultStr == ""
                HandleNoSelection()
            ElseIf resultStr == "0"
                HandleSubmitToArrest()
            ElseIf resultStr == "1"
                HandleResistArrest()
            ElseIf resultStr == "2"
                HandleBribe()
            Else
                HandlePersuade()
            EndIf
        EndIf
    EndIf
EndFunction

; ===== MENU CHOICES =====

Function HandlePayFine()
    {Pay the quoted fine, or, short of gold, set PaymentFailed and re-show the menu.}

    If !ArrestScript
        Return
    EndIf

    If ConfrontingGuard == None || ConfrontingFaction == None
        Return
    EndIf

    Actor player = Game.GetPlayer()
    Int bounty = ConfrontingBounty
    Int playerGold = player.GetGoldAmount()

    ArrestScript.Maintenance() ; Ensure Gold001 is available

    If playerGold >= bounty && ArrestScript.Gold001
        player.RemoveItem(ArrestScript.Gold001, bounty, true)
        If ArrestScript.BountyScript
            ; Only the quoted amount: the prompt does not pause, so bounty added while it was open stays owed.
            ArrestScript.BountyScript.ModTrackedBounty(ConfrontingFaction, -bounty)
        EndIf
        ConfrontingFaction.SetCrimeGold(0) ; vanilla crime gold too, as a safety net

        String narration = "*" + ConfrontingGuard.GetDisplayName() + " accepts the " + bounty + " gold fine and pockets it.*"
        SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, player)

        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrestplayer.paidGoldFine", ("" + bounty)))
        ArrestScript.DebugMsg("Player paid fine: " + bounty)

        ClearPlayerConfrontationState()
    Else
        ; Short of gold: no more payment options.
        PaymentFailed = true

        String narration = "*" + ConfrontingGuard.GetDisplayName() + " scowls as " + player.GetDisplayName() + " fumbles through a coin purse that cannot cover the " + bounty + " gold fine, plainly in no mood for a second try.*"
        SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, player)

        Debug.Notification(SeverActionsNativeExt2.Native_L10n("arrestplayer.guardWontAcceptPayment"))
        ArrestScript.DebugMsg("Player couldn't afford fine, payment options removed")

        ShowPlayerArrestMenu()
    EndIf
EndFunction

Function HandleSubmitToArrest()
    {Player submits to arrest - send to jail}

    If !ArrestScript
        Return
    EndIf

    If ConfrontingGuard == None || ConfrontingFaction == None
        Return
    EndIf

    ArrestScript.DebugMsg("Player submitted to arrest")

    ; The vanilla jail reads crime gold: move the tracked bounty there first.
    If ArrestScript.BountyScript
        ArrestScript.BountyScript.ApplyTrackedBountyToVanilla(ConfrontingFaction)
    EndIf

    ConfrontingFaction.SendPlayerToJail(true, true) ; removeInventory, realJail

    ClearPlayerConfrontationState()
EndFunction

Function HandleResistArrest()
    {Player resists arrest - guard becomes hostile, bounty increases}

    If !ArrestScript
        Return
    EndIf

    If ConfrontingGuard == None || ConfrontingFaction == None
        Return
    EndIf

    ArrestScript.DebugMsg("Player resisting arrest")

    If ArrestScript.BountyScript
        ArrestScript.BountyScript.ModTrackedBounty(ConfrontingFaction, ArrestScript.ResistBountyIncrease)
        ; Vanilla crime gold is what turns the hold's guards hostile.
        ArrestScript.BountyScript.ApplyTrackedBountyToVanilla(ConfrontingFaction)
    EndIf

    ; OnResistCombatEndedEvent moves this hold's vanilla crime gold back into the tracked bounty
    ; when the fight ends. One slot: settle a pending resist in another hold first, or its
    ; vanilla bounty is stranded.
    If ResistArrestFaction != None && ResistArrestFaction != ConfrontingFaction
        Int pendingVanilla = ResistArrestFaction.GetCrimeGold()
        If pendingVanilla > 0 && ArrestScript && ArrestScript.BountyScript
            ArrestScript.BountyScript.ModTrackedBounty(ResistArrestFaction, pendingVanilla)
            ResistArrestFaction.SetCrimeGold(0)
            ResistArrestFaction.SetCrimeGoldViolent(0)
        EndIf
    EndIf
    ResistArrestFaction = ConfrontingFaction
    ResistArrestStartTime = Utility.GetCurrentRealTime()
    SeverActionsNative.Native_Resist_Begin(ResistMaxWaitSeconds)

    ; No Aggression bump: guards are already Aggressive, and nothing here would restore it if
    ; combat ended abnormally. The vanilla bounty above plus StartCombat starts the fight.
    ConfrontingGuard.StartCombat(Game.GetPlayer())

    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrestplayer.bountyIncreasedByGold", ("" + ArrestScript.ResistBountyIncrease)))

    ClearPlayerConfrontationState()
EndFunction

Function HandleBribe()
    {Pay ConfrontingBounty x BribeMultiplier to clear the quoted bounty, or, short of gold,
     set PaymentFailed and re-show the menu.}

    If !ArrestScript
        Return
    EndIf

    If ConfrontingGuard == None || ConfrontingFaction == None
        Return
    EndIf

    Actor player = Game.GetPlayer()
    Int bribeCost = (ConfrontingBounty as Float * ArrestScript.BribeMultiplier) as Int
    Int playerGold = player.GetGoldAmount()

    ArrestScript.Maintenance() ; Ensure Gold001 is available

    If playerGold >= bribeCost && ArrestScript.Gold001
        player.RemoveItem(ArrestScript.Gold001, bribeCost, true)
        If ArrestScript.BountyScript
            ; Only the quoted bounty (see HandlePayFine).
            ArrestScript.BountyScript.ModTrackedBounty(ConfrontingFaction, -ConfrontingBounty)
        EndIf
        ConfrontingFaction.SetCrimeGold(0) ; vanilla crime gold too, as a safety net

        String narration = "*" + ConfrontingGuard.GetDisplayName() + " glances around, then quietly takes the " + bribeCost + " gold bribe, looking the other way.*"
        SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, player)

        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrestplayer.bribedGuardWithGold", ("" + bribeCost)))
        ArrestScript.DebugMsg("Player bribed guard: " + bribeCost)

        ClearPlayerConfrontationState()
    Else
        ; Short of gold: no more payment options.
        PaymentFailed = true

        String narration = "*" + ConfrontingGuard.GetDisplayName() + " eyes the few coins " + player.GetDisplayName() + " can scrape together - nowhere near the " + bribeCost + " gold it would take - with open contempt, insulted by the attempt.*"
        SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, player)

        Debug.Notification(SeverActionsNativeExt2.Native_L10n("arrestplayer.guardWontAcceptPayment"))
        ArrestScript.DebugMsg("Player couldn't afford bribe, payment options removed")

        ShowPlayerArrestMenu()
    EndIf
EndFunction

Function HandlePersuade()
    {Player attempts to persuade guard - start conversation mode}

    If !ArrestScript
        Return
    EndIf

    If ConfrontingGuard == None || ConfrontingFaction == None
        Return
    EndIf

    ArrestScript.DebugMsg("Player starting persuasion attempt")

    PersuadeAttempted = true
    InPersuasionMode = true

    ; The follow package targets FollowTargetKW's linked ref.
    SeverActionsNative.LinkedRef_Set(ConfrontingGuard, Game.GetPlayer(), ArrestScript.SeverActions_FollowTargetKW)

    If ArrestScript.SeverActions_GuardFollowPlayer
        ActorUtil.AddPackageOverride(ConfrontingGuard, ArrestScript.SeverActions_GuardFollowPlayer, ArrestScript.PackagePriority, 1)
        ConfrontingGuard.EvaluatePackage()
        ArrestScript.DebugMsg("Guard following player for persuasion")
    EndIf

    String holdName = ArrestScript.GetHoldNameForGuard(ConfrontingGuard)
    String narration = "*" + ConfrontingGuard.GetDisplayName() + " pauses, willing to hear what " + Game.GetPlayer().GetDisplayName() + " has to say about their " + ConfrontingBounty + " gold bounty in " + holdName + ".*"
    SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, Game.GetPlayer())

    String eventMsg = Game.GetPlayer().GetDisplayName() + " set about talking " + ConfrontingGuard.GetDisplayName() + " into overlooking their own " + ConfrontingBounty + " gold bounty in " + holdName + "."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, ConfrontingGuard, Game.GetPlayer())

    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrestplayer.youHaveSecondsToConvince", ("" + (ArrestScript.PersuasionTimeLimit as Int))))

    ; Timeout, distance and death come back as SeverActions_PersuasionFailed.
    SeverActionsNative.Native_Persuasion_Begin(ConfrontingGuard, Game.GetPlayer(), ArrestScript.PersuasionTimeLimit, ArrestScript.PersuasionFollowDistance)
EndFunction

Function HandleNoSelection()
    {SkyMessage.Show returned "": nothing was chosen (SkyMessage is optional and only used when
     Magelight is also unavailable). Never resist here: notify the player and stand the
     confrontation down; the guard can re-confront after ArrestPlayerCooldown.}

    If ArrestScript
        ArrestScript.DebugMsg("Arrest menu returned no selection (SkyMessage missing or aborted) - deferring confrontation")
    EndIf

    If ConfrontingGuard != None
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrestplayer.demandsYouPayYour", ("" + ConfrontingGuard.GetDisplayName())))
    EndIf

    ClearPlayerConfrontationState()
EndFunction

; ===== PERSUASION (acceptpersuasion.yaml, rejectpersuasion.yaml) =====

Bool Function CanUsePersuasionAction(Actor akGuard)
    {True only while akGuard is the guard in a running persuasion.}

    If !InPersuasionMode
        Return false
    EndIf

    If akGuard == None
        Return false
    EndIf

    If akGuard != ConfrontingGuard
        Return false
    EndIf

    Return true
EndFunction

Bool Function AcceptPersuasion_Internal(Actor akGuard)
    {acceptpersuasion.yaml: the guard is convinced. Clears the bounty and ends the confrontation;
     false when no persuasion runs or akGuard is not its guard.}

    If !ArrestScript
        Return false
    EndIf

    If !InPersuasionMode
        ArrestScript.DebugMsg("ERROR: AcceptPersuasion called but not in persuasion mode")
        Return false
    EndIf

    If akGuard != ConfrontingGuard
        ArrestScript.DebugMsg("ERROR: AcceptPersuasion called with wrong guard")
        Return false
    EndIf

    ArrestScript.DebugMsg("Guard accepted persuasion!")

    If ArrestScript.BountyScript
        ArrestScript.BountyScript.ClearTrackedBounty(ConfrontingFaction)
    EndIf
    ConfrontingFaction.SetCrimeGold(0) ; vanilla crime gold too, as a safety net

    StopPersuasionFollow()

    String narration = "*" + ConfrontingGuard.GetDisplayName() + " sighs and nods reluctantly, waving " + Game.GetPlayer().GetDisplayName() + " off with a look that says to go now, before the offer is withdrawn.*"
    SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, Game.GetPlayer())

    String holdName = ArrestScript.GetHoldNameForGuard(ConfrontingGuard)
    String eventMsg = Game.GetPlayer().GetDisplayName() + " convinced " + ConfrontingGuard.GetDisplayName() + " to overlook their " + ConfrontingBounty + " gold bounty in " + holdName + "."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, Game.GetPlayer(), ConfrontingGuard)

    Debug.Notification(SeverActionsNativeExt2.Native_L10n("arrestplayer.guardLetsYouGo"))

    ClearPlayerConfrontationState()
    Return true
EndFunction

Bool Function RejectPersuasion_Internal(Actor akGuard)
    {rejectpersuasion.yaml: the guard is not convinced. Ends the persuasion and re-shows the menu
     without Persuade; false when no persuasion runs or akGuard is not its guard.}

    If !ArrestScript
        Return false
    EndIf

    If !InPersuasionMode
        ArrestScript.DebugMsg("ERROR: RejectPersuasion called but not in persuasion mode")
        Return false
    EndIf

    If akGuard != ConfrontingGuard
        ArrestScript.DebugMsg("ERROR: RejectPersuasion called with wrong guard")
        Return false
    EndIf

    ArrestScript.DebugMsg("Guard rejected persuasion attempt")

    StopPersuasionFollow()
    ; The window ends with the persuasion, or it would fire a timeout into the menu.
    SeverActionsNativeExt2.Native_Persuasion_EndFor(ConfrontingGuard)

    InPersuasionMode = false

    ; No narration: the guard answers in their own SkyrimNet dialogue.
    String holdName = ArrestScript.GetHoldNameForGuard(ConfrontingGuard)
    String eventMsg = ConfrontingGuard.GetDisplayName() + " was not convinced by " + Game.GetPlayer().GetDisplayName() + "'s arguments and demanded they face justice for their " + ConfrontingBounty + " gold bounty in " + holdName + "."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, ConfrontingGuard, Game.GetPlayer())

    Debug.Notification(SeverActionsNativeExt2.Native_L10n("arrestplayer.guardIsNotConvinced"))

    ShowPlayerArrestMenu()
    Return true
EndFunction

Function OnPersuasionFailed(String reason)
    {Persuasion timed out or the player left the guard behind: narrate, then re-show the menu
     without Persuade.}

    If !ArrestScript
        Return
    EndIf

    If !InPersuasionMode || ConfrontingGuard == None
        Return
    EndIf

    ArrestScript.DebugMsg("Persuasion failed: " + reason)

    StopPersuasionFollow()

    InPersuasionMode = false

    String narration
    If reason == "timeout"
        narration = "*" + ConfrontingGuard.GetDisplayName() + " has run out of patience for talk and demands an answer now.*"
    Else
        narration = "*" + ConfrontingGuard.GetDisplayName() + " catches up with " + Game.GetPlayer().GetDisplayName() + ", clearly annoyed at the attempt to slip away - there will be no more games.*"
    EndIf
    SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, Game.GetPlayer())

    String holdName = ArrestScript.GetHoldNameForGuard(ConfrontingGuard)
    String eventMsg = ConfrontingGuard.GetDisplayName() + " grew tired of " + Game.GetPlayer().GetDisplayName() + "'s excuses and demanded they submit to arrest."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, ConfrontingGuard, Game.GetPlayer())

    Debug.Notification(SeverActionsNativeExt2.Native_L10n("arrestplayer.guardHasLostPatience"))

    ShowPlayerArrestMenu()
EndFunction

; ===== CLEANUP =====

Function StopPersuasionFollow()
    {Remove the guard's follow-player package and FollowTargetKW link. Called on accept, reject,
     fail, died and cancel.}
    If !ArrestScript || ConfrontingGuard == None
        Return
    EndIf
    If ArrestScript.SeverActions_GuardFollowPlayer
        ActorUtil.RemovePackageOverride(ConfrontingGuard, ArrestScript.SeverActions_GuardFollowPlayer)
    EndIf
    SeverActionsNative.LinkedRef_Clear(ConfrontingGuard, ArrestScript.SeverActions_FollowTargetKW)
    ConfrontingGuard.EvaluatePackage()
EndFunction

Function CancelPlayerConfrontation()
    {End the current confrontation, releasing the persuasion follow first if one runs. Public.}

    If ArrestScript
        ArrestScript.DebugMsg("Canceling player confrontation")
    EndIf

    If InPersuasionMode && ConfrontingGuard
        StopPersuasionFollow()
    EndIf

    ClearPlayerConfrontationState()
EndFunction

Function ClearPlayerConfrontationState()
    {Reset the FSM, end the persuasion monitor, close the prompt and cancel the watchdog tick.
     Keeps LastArrestTime (the cooldown) and the resist slot, which outlive the confrontation.}

    ; Idempotent; every persuasion exit ends here. This guard's window only.
    SeverActionsNativeExt2.Native_Persuasion_EndFor(ConfrontingGuard)

    ConfrontingGuard = None
    ConfrontingFaction = None
    ConfrontingBounty = 0
    PersuadeAttempted = false
    PaymentFailed = false
    InPersuasionMode = false

    ; A clear can land while the prompt is still showing.
    If SeverActionsNative.Magelight_IsArrestPromptOpen()
        SeverActionsNative.Magelight_CloseArrestPrompt()
    EndIf

    SeverActionsNativeExt2.Chrono_Cancel("SeverActions_Tick_ArrestPlayer")
EndFunction

; ===== PUBLIC QUERIES =====

Bool Function IsPlayerInConfrontation()
    {Check if player is currently being confronted by a guard.}
    Return ConfrontingGuard != None
EndFunction

Bool Function IsPlayerInPersuasion()
    {Check if player is currently in persuasion mode.}
    Return InPersuasionMode
EndFunction

Actor Function GetConfrontingGuard()
    {The confronting guard, or None. SeverActions_Arrest.ClearStaleArrestState exempts it:
     during persuasion it holds FollowTargetKW on the player.}
    Return ConfrontingGuard
EndFunction

; ===== PARLEY =====

Bool Function BeginParley(Actor akGuard, Actor akSuspect, Faction akJurisdiction, ObjectReference akJailMarker)
    {Open a parley: akGuard questions akSuspect, one of the player's people, over their bounty
     instead of cuffing them, and ParleyDriver keeps the two talking until one of them settles it
     (the parley actions) or the driver ends it. Called by SeverActions_Arrest.ArrestNPC_Internal.
     False when refused; the guard then hears why through an arrest_failed event.}
    If !ArrestScript || akGuard == None || akSuspect == None || akSuspect == Game.GetPlayer()
        Return false
    EndIf
    If akGuard.IsDead() || akSuspect.IsDead() || !akSuspect.Is3DLoaded()
        Return false
    EndIf

    String guardName = akGuard.GetDisplayName()
    String suspectName = akSuspect.GetDisplayName()
    String refusal = ""
    If ParleySuspect != None
        refusal = guardName + " cannot question " + suspectName + " now - a guard is already questioning someone."
    ElseIf akGuard == ConfrontingGuard
        refusal = guardName + " is already dealing with " + Game.GetPlayer().GetDisplayName() + "."
    ElseIf ArrestScript.GetArrestState() != 0 || ArrestScript.GetDispatchPhase() > 0
        refusal = guardName + " cannot question " + suspectName + " while another arrest is under way."
    ElseIf akGuard.IsInCombat() || akSuspect.IsInCombat()
        refusal = guardName + " cannot question " + suspectName + " in the middle of a fight."
    ElseIf SeverActionsNative.Native_IsActorInScene(akGuard) || SeverActionsNative.Native_IsActorInScene(akSuspect)
        refusal = guardName + " cannot question " + suspectName + " right now."
    ElseIf SeverActionsNative.Native_ArrestSession_HasSession(akSuspect) || ArrestScript.IsNPCJailed(akSuspect)
        refusal = suspectName + " is already in the guards' hands."
    EndIf
    Float now = SeverActionsNativeExt2.Kernel_RealTime()
    Float last = StorageUtil.GetFloatValue(akSuspect, "SeverActions_ParleyAt", -1000.0)
    If refusal == "" && now >= last && now - last < PARLEY_COOLDOWN
        refusal = guardName + " questioned " + suspectName + " moments ago and lets it rest for now."
    EndIf

    ; The hold whose bounty is in question: the arrest's own, else the guard's (where AddBountyToNPC charges).
    Faction crime = None
    ObjectReference jail = None
    If akJurisdiction != None && SeverActionsNativeExt.Native_Bounty_GetFor(akSuspect, akJurisdiction) > 0
        crime = akJurisdiction
        jail = akJailMarker
    Else
        Faction own = SeverActionsNativeExt.Hold_GetCrimeFaction(akGuard)
        If own == None
            own = SeverActionsNativeExt2.Hold_GetCrimeFactionForRef(akGuard)
        EndIf
        If own != None && SeverActionsNativeExt.Native_Bounty_GetFor(akSuspect, own) > 0
            crime = own
            jail = SeverActionsNativeExt.Hold_GetJailMarkerForCrime(own)
        EndIf
    EndIf
    If refusal == "" && crime == None
        refusal = suspectName + " owes nothing here: " + guardName + " must charge them first (select the Arrest action category, then AddBountyToNPC)."
    ElseIf refusal == "" && jail == None
        refusal = guardName + " has no jail to take " + suspectName + " to."
    EndIf
    If refusal != ""
        ArrestScript.DebugMsg("Parley refused: " + refusal)
        SkyrimNetApi.RegisterEvent("arrest_failed", refusal, akGuard, None)
        Return false
    EndIf

    Int quote = SeverActionsNativeExt.Native_Bounty_GetFor(akSuspect, crime)
    _ClearParleySlot()
    ParleyGuard = akGuard
    ParleySuspect = akSuspect
    ParleyFaction = crime
    ParleyJail = jail
    ParleyQuote = quote
    ; The player's card rule: a fine below the threshold, a bribe of quote x BribeMultiplier at or above it.
    ParleyBribe = quote >= ArrestScript.ArrestBountyThreshold
    ParleyCost = quote
    If ParleyBribe
        ParleyCost = Math.Floor(quote * ArrestScript.BribeMultiplier + 0.5)
    EndIf

    SeverActionsNative.Native_ArrestSession_Begin(akSuspect, akGuard, jail, crime, 7, 0, 0)
    _HoldParleyGuard()
    If !SeverActionsNativeExt2.Parley_Arm(akSuspect, akGuard, crime, ParleyQuote, ParleyCost, ParleyBribe, 0)
        ArrestScript.DebugMsg("Parley: the driver would not arm - standing down")
        _ReleaseParleyGuard(akGuard)
        SeverActionsNative.Native_ArrestSession_End(akSuspect)
        _ClearParleySlot()
        Return false
    EndIf

    String holdName = SeverActionsNativeExt2.Hold_GetHoldNameForCrime(crime)
    ; The guard just spoke the line that chose the arrest: the suspect answers first.
    _ParleyNarrate("*" + guardName + " stops " + suspectName + " over the " + quote + " gold they owe in " + holdName + " and waits for an answer.*", akSuspect, akGuard)
    SkyrimNetApi.RegisterPersistentEvent(guardName + " stopped " + suspectName + ", a companion of " + Game.GetPlayer().GetDisplayName() + ", over a " + quote + " gold bounty in " + holdName + ".", akGuard, akSuspect)
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("parley.opened", guardName, suspectName))
    ArrestScript.DebugMsg("Parley opened: " + guardName + " questions " + suspectName + " over " + quote + " gold in " + holdName + " (terms " + ParleyCost + ", bribe " + ParleyBribe + ")")
    Return true
EndFunction

Function EndParley(String asWhy)
    {Close the parley with no arrest: the driver stops, the guard lets go of the suspect and the
     session ends; the bounty stands unless the caller cleared it. A suspect who resisted stops
     fighting and gets their follow back (the followers custodyRelease). Idempotent.}
    If ParleySuspect == None
        Return
    EndIf
    Actor guard = ParleyGuard
    Actor suspect = ParleySuspect
    Bool resisted = ParleyResisting
    ; The player stepped in: the fight is theirs now, so nothing stops it.
    Bool intervened = ParleyIntervened
    _ClearParleySlot()
    SeverActionsNativeExt2.Parley_Disarm(suspect)
    If resisted && !intervened
        _StopParleyFight(guard, suspect)
    EndIf
    _ReleaseParleyGuard(guard)
    If SeverActionsNative.Native_ArrestSession_GetState(suspect) == 7
        SeverActionsNative.Native_ArrestSession_End(suspect)
    EndIf
    StorageUtil.SetFloatValue(suspect, "SeverActions_ParleyAt", SeverActionsNativeExt2.Kernel_RealTime())
    If resisted
        SeverActions_ModuleBase.CallBool("followers", "custodyRelease", suspect)
    EndIf
    ; Last, once nothing of the parley is fighting them.
    ReleaseParleyProtection(suspect)
    If ArrestScript
        ArrestScript.DebugMsg("Parley over " + suspect.GetDisplayName() + " ended (" + asWhy + ")")
    EndIf
EndFunction

Function _ParleyToCustody(String asWhy, String asNarration)
    {The parley ends in custody: the same-cell arrest takes over the state-7 session (PerformArrest
     moves it on in place), then the escort and the jail. Stands down when the arrest cannot start.}
    If ParleySuspect == None
        Return
    EndIf
    Actor guard = ParleyGuard
    Actor suspect = ParleySuspect
    Faction crime = ParleyFaction
    ObjectReference jail = ParleyJail
    Bool resisted = ParleyResisting
    _ClearParleySlot()
    SeverActionsNativeExt2.Parley_Disarm(suspect)
    If resisted
        _StopParleyFight(guard, suspect)
        ; The resist's hold and protection go on into the arrest (guards who joined the fight may still be
        ; at it): PerformArrest takes the hold over at the cuffing (TakeParleySuspect), and an arrest that
        ; never takes them gives both back (ReturnParleySuspect).
        StorageUtil.SetIntValue(suspect, "SeverActions_ParleyHandover", 1)
    EndIf
    _ReleaseParleyGuard(guard)
    StorageUtil.SetFloatValue(suspect, "SeverActions_ParleyAt", SeverActionsNativeExt2.Kernel_RealTime())
    If asNarration != ""
        _ParleyNarrate(asNarration, guard, suspect)
    EndIf
    If ArrestScript.StartArrestFromParley(guard, suspect, crime, jail)
        String holdName = SeverActionsNativeExt2.Hold_GetHoldNameForCrime(crime)
        SkyrimNetApi.RegisterPersistentEvent(guard.GetDisplayName() + " took " + suspect.GetDisplayName() + " into custody over their bounty in " + holdName + ".", guard, suspect)
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("parley.custody", suspect.GetDisplayName()))
        ArrestScript.DebugMsg("Parley over " + suspect.GetDisplayName() + " ended in custody (" + asWhy + ")")
    Else
        ArrestScript.DebugMsg("Parley custody: the arrest of " + suspect.GetDisplayName() + " could not start (" + asWhy + ") - standing down")
        If SeverActionsNative.Native_ArrestSession_GetState(suspect) == 7
            SeverActionsNative.Native_ArrestSession_End(suspect)
        EndIf
        ReturnParleySuspect(suspect)
    EndIf
EndFunction

Function _StopParleyFight(Actor akGuard, Actor akSuspect)
    If akGuard != None && !akGuard.IsDead()
        akGuard.StopCombat()
    EndIf
    If akSuspect != None && !akSuspect.IsDead()
        akSuspect.StopCombat()
        akSuspect.StopCombatAlarm()
    EndIf
EndFunction

Bool Function _ParleyPay()
    {The suspect pays the parley's terms from their own purse to the guard: true when paid (the
     parley ends), false when short (payment is not offered again). Only the quote comes off the
     bounty: a charge added during the parley stays owed. The slot is read once, before any call
     that can yield, and claimed (EndParley) before the gold moves.}
    Actor guard = ParleyGuard
    Actor suspect = ParleySuspect
    Faction crime = ParleyFaction
    Int quote = ParleyQuote
    Int cost = ParleyCost
    Bool bribe = ParleyBribe
    If suspect == None
        Return false
    EndIf
    If !ArrestScript.Gold001
        ArrestScript.Maintenance()
    EndIf
    MiscObject gold = ArrestScript.Gold001
    Bool canPay = gold && suspect.GetItemCount(gold) >= cost
    If ParleySuspect != suspect || ParleyResisting
        Return true ; another stack settled the parley meanwhile, or the suspect refused
    EndIf
    If canPay
        EndParley("paid")
        suspect.RemoveItem(gold, cost, true, guard)
        SeverActionsNativeExt.Native_Bounty_ModFor(suspect, crime, -quote)
        String text = "*" + guard.GetDisplayName() + " takes " + suspect.GetDisplayName() + "'s " + cost + " gold fine. The matter is settled.*"
        If bribe
            text = "*" + guard.GetDisplayName() + " glances around, pockets " + suspect.GetDisplayName() + "'s " + cost + " gold and looks the other way.*"
        EndIf
        _ParleyNarrate(text, guard, suspect)
        SkyrimNetApi.RegisterPersistentEvent(suspect.GetDisplayName() + " paid " + guard.GetDisplayName() + " " + cost + " gold to settle their bounty.", guard, suspect)
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("parley.paid", suspect.GetDisplayName(), ("" + cost)))
        Return true
    EndIf
    ParleyNoCoin = true
    _SyncParleyFlags()
    _ParleyNarrate("*" + suspect.GetDisplayName() + " cannot cover the " + cost + " gold, and " + guard.GetDisplayName() + " is not amused.*", guard, suspect)
    Return false
EndFunction

Function _ParleyWaive()
    {The guard lets the charge drop: the suspect's whole bounty in that hold is cleared (as
     AcceptPersuasion does for the player) and the parley ends. Claimed (EndParley) first.}
    Actor guard = ParleyGuard
    Actor suspect = ParleySuspect
    Faction crime = ParleyFaction
    If suspect == None || ParleyResisting
        Return
    EndIf
    EndParley("waived")
    Int owed = SeverActionsNativeExt.Native_Bounty_GetFor(suspect, crime)
    If owed > 0
        SeverActionsNativeExt.Native_Bounty_ModFor(suspect, crime, -owed)
    EndIf
    SkyrimNetApi.RegisterPersistentEvent(guard.GetDisplayName() + " heard " + suspect.GetDisplayName() + " out and let the charge drop.", guard, suspect)
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("parley.waived", guard.GetDisplayName(), suspect.GetDisplayName()))
EndFunction

Function _ParleyResist(String asWhy)
    {The suspect refuses: the bounty grows by ResistBountyIncrease, the guard fights them, and
     ParleyDriver ends it - subdued (bleedout or low health) is custody, out of reach is an escape.
     The suspect leaves the player's party for the fight (custodyHold), so the other companions
     stay out of it, and cannot be killed by the guard (_ParleyProtect).}
    If ParleyResisting || ParleySuspect == None
        Return
    EndIf
    ; Claimed before any call that can yield: from here OnParleyEvent drops every talk-phase event it has
    ; not acted on yet. A close that still runs meanwhile (a death, the cancel, the watchdog, the setting)
    ; may release before the hold goes on, so each epoch check below gives back what this took.
    ParleyResisting = true
    ParleyDemand = false
    Int epoch = ParleyEpoch
    Int flags = _ParleyFlags()
    Actor guard = ParleyGuard
    Actor suspect = ParleySuspect
    Faction crime = ParleyFaction
    Int quote = ParleyQuote
    Int cost = ParleyCost
    Bool bribe = ParleyBribe
    ; The talk is over: no prod, deadline or verdict while the fight is set up.
    SeverActionsNativeExt2.Parley_Disarm(suspect)
    ; Protected and out of the party first: after a pairfight the blows are already landing.
    _ParleyProtect(suspect)
    SeverActions_ModuleBase.CallBool("followers", "custodyHold", suspect)
    If ParleyEpoch != epoch
        _UndoParleyResist(suspect)
        Return
    EndIf
    Int increase = ArrestScript.ResistBountyIncrease
    String holdName = SeverActionsNativeExt2.Hold_GetHoldNameForCrime(crime)
    If increase > 0
        SeverActionsNativeExt.Native_Bounty_ModFor(suspect, crime, increase)
        SeverActionsNativeExt.Native_Bounty_AddEventFor(suspect, crime, increase, SeverActionsNativeExt2.Bounty_CleanCrime("resisting arrest"), holdName)
    EndIf
    _ReleaseParleyGuard(guard)
    ; Armed beside the fight, so the driver's calm clock starts with it.
    Bool armed = SeverActionsNativeExt2.Parley_Arm(suspect, guard, crime, quote, cost, bribe, flags)
    If ParleyEpoch != epoch
        If armed
            SeverActionsNativeExt2.Parley_Disarm(suspect)
        EndIf
        _UndoParleyResist(suspect)
        Return
    EndIf
    If !armed
        EndParley(asWhy)
        Return
    EndIf
    guard.StartCombat(suspect)
    suspect.StartCombat(guard)
    If ParleyEpoch != epoch
        ; Closed as the fight began, and that close's StopCombat may have come first. A custody (the
        ; session goes on) keeps the hold and the protection.
        _StopParleyFight(guard, suspect)
        If !SeverActionsNative.Native_ArrestSession_HasSession(suspect)
            _UndoParleyResist(suspect)
        EndIf
        Return
    EndIf
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("parley.resisted", suspect.GetDisplayName()))
    If increase > 0
        SkyrimNetApi.RegisterPersistentEvent(suspect.GetDisplayName() + " refused to go with " + guard.GetDisplayName() + " and resisted arrest; their bounty in " + holdName + " grew by " + increase + " gold.", guard, suspect)
    Else
        SkyrimNetApi.RegisterPersistentEvent(suspect.GetDisplayName() + " refused to go with " + guard.GetDisplayName() + " and resisted arrest.", guard, suspect)
    EndIf
    ArrestScript.DebugMsg("Parley: " + suspect.GetDisplayName() + " resists (" + asWhy + ")")
EndFunction

Function _ParleyIntervened(Actor akGuard, Actor akSuspect)
    {The player joined the resist fight on the suspect's side: the parley ends there as an escape, the
     suspect rejoins the party at once, the fight goes on as the player's, and SkyrimNet remembers who
     stood by whom.}
    ParleyIntervened = true
    EndParley("intervened")
    Actor player = Game.GetPlayer()
    SkyrimNetApi.RegisterPersistentEvent(player.GetDisplayName() + " stepped in and fought " + akGuard.GetDisplayName() + " to keep " + akSuspect.GetDisplayName() + " from being arrested.", player, akSuspect)
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("parley.intervened", akSuspect.GetDisplayName()))
    ArrestScript.DebugMsg("Parley: the player intervened for " + akSuspect.GetDisplayName())
EndFunction

Function _UndoParleyResist(Actor akSuspect)
    {A resist whose parley another stack closed meanwhile: that close may have released before the hold
     went on, so this gives back what the resist took, unless a custody handover carries it on.}
    If StorageUtil.GetIntValue(akSuspect, "SeverActions_ParleyHandover", 0) == 1
        Return
    EndIf
    SeverActions_ModuleBase.CallBool("followers", "custodyRelease", akSuspect)
    ReleaseParleyProtection(akSuspect)
EndFunction

Function _ParleyProtect(Actor akSuspect)
    {For the resist fight: the suspect is made protected, on the reference and never the base record,
     so the guard drops them into bleedout (the driver's "subdued") instead of killing them. One already
     essential or protected is left as it is; the StorageUtil mark says this script set the flag.}
    If akSuspect && SeverActionsNativeExt2.Parley_Protect(akSuspect, true)
        StorageUtil.SetIntValue(akSuspect, "SeverActions_ParleyProtected", 1)
    EndIf
EndFunction

Function ReleaseParleyProtection(Actor akSuspect) Global
    {Take off the resist fight's protection (_ParleyProtect) once the suspect is out of combat (the native
     waits, since guards who joined the fight may still be at it): the parley's exits, and the arrest's
     release of a suspect it took in after a resist. Only acts on the mark.}
    If akSuspect && StorageUtil.GetIntValue(akSuspect, "SeverActions_ParleyProtected", 0) == 1
        StorageUtil.UnsetIntValue(akSuspect, "SeverActions_ParleyProtected")
        SeverActionsNativeExt2.Parley_Protect(akSuspect, false)
    EndIf
EndFunction

Function TakeParleySuspect(Actor akPrisoner) Global
    {The arrest has cuffed a suspect a resisted parley handed over: its own hold and release take over
     from the handover (SeverActions_Arrest.PerformArrest).}
    If akPrisoner
        StorageUtil.UnsetIntValue(akPrisoner, "SeverActions_ParleyHandover")
    EndIf
EndFunction

Function ReturnParleySuspect(Actor akSuspect) Global
    {A suspect a resisted parley handed to an arrest that never took them (it could not start, or its
     approach was cancelled before the cuffing) goes back to the player: the resist's hold and
     protection come off. Only acts on the handover mark.}
    If akSuspect && StorageUtil.GetIntValue(akSuspect, "SeverActions_ParleyHandover", 0) == 1
        StorageUtil.UnsetIntValue(akSuspect, "SeverActions_ParleyHandover")
        SeverActions_ModuleBase.CallBool("followers", "custodyRelease", akSuspect)
        ReleaseParleyProtection(akSuspect)
    EndIf
EndFunction

Function _ResumeParley()
    {Load: a parley saved mid-talk goes on with a fresh time budget; one whose actors or session
     are gone stands down. A resist fight keeps its protection (the flag may not ride the save).}
    Actor guard = ParleyGuard
    Actor suspect = ParleySuspect
    If guard == None || guard.IsDead() || suspect.IsDead() || ParleyFaction == None || SeverActionsNative.Native_ArrestSession_GetState(suspect) != 7
        EndParley("load")
        Return
    EndIf
    ; Restamp the session's watchdog; the session itself was saved.
    SeverActionsNative.Native_ArrestSession_EnsureBegin(suspect, guard, ParleyJail, ParleyFaction, 7, 0, 0)
    If !ParleyResisting
        _HoldParleyGuard()
    ElseIf StorageUtil.GetIntValue(suspect, "SeverActions_ParleyProtected", 0) == 1
        ; Off then on: the off keeps a flag that rode the save, and the on takes it back as this session's.
        SeverActionsNativeExt2.Parley_Protect(suspect, false)
        SeverActionsNativeExt2.Parley_Protect(suspect, true)
    EndIf
    If !SeverActionsNativeExt2.Parley_Arm(suspect, guard, ParleyFaction, ParleyQuote, ParleyCost, ParleyBribe, _ParleyFlags())
        EndParley("load")
    EndIf
EndFunction

Function _HoldParleyGuard()
    {The guard trails the suspect: GuardFollowPlayer follows whatever FollowTargetKW points at (the
     escort plea's trick). The weapon stays sheathed and the suspect keeps their own packages.}
    If ParleyGuard == None || ParleySuspect == None
        Return
    EndIf
    SeverActionsNative.LinkedRef_Set(ParleyGuard, ParleySuspect, ArrestScript.SeverActions_FollowTargetKW)
    If ArrestScript.SeverActions_GuardFollowPlayer
        ActorUtil.AddPackageOverride(ParleyGuard, ArrestScript.SeverActions_GuardFollowPlayer, ArrestScript.PackagePriority, 1)
        ParleyGuard.EvaluatePackage()
    EndIf
EndFunction

Function _ReleaseParleyGuard(Actor akGuard)
    If akGuard == None
        Return
    EndIf
    If ArrestScript.SeverActions_GuardFollowPlayer
        ActorUtil.RemovePackageOverride(akGuard, ArrestScript.SeverActions_GuardFollowPlayer)
    EndIf
    SeverActionsNative.LinkedRef_Clear(akGuard, ArrestScript.SeverActions_FollowTargetKW)
    akGuard.EvaluatePackage()
EndFunction

Function _ParleyNarrate(String asText, Actor akSpeaker, Actor akTarget)
    {DirectNarration from akSpeaker to akTarget ("" = a prod that leaves no history). A named speaker
     skips SkyrimNet's scene filter, so a scene on either side skips it.}
    If akSpeaker == None || akTarget == None
        Return
    EndIf
    If SeverActionsNative.Native_IsActorInScene(akSpeaker) || SeverActionsNative.Native_IsActorInScene(akTarget)
        Return
    EndIf
    SkyrimNetApi.DirectNarration(asText, akSpeaker, akTarget)
EndFunction

Int Function _ParleyFlags()
    {The flag set ParleyDriver reads (ParleyCore.h).}
    Int flags = 0
    If ParleyPleaRefused
        flags += 1
    EndIf
    If ParleyNoCoin
        flags += 2
    EndIf
    If ParleyDemand
        flags += 4
    EndIf
    If ParleyResisting
        flags += 8
    EndIf
    Return flags
EndFunction

Function _SyncParleyFlags()
    SeverActionsNativeExt2.Parley_SetFlags(ParleySuspect, _ParleyFlags())
EndFunction

Function _ClearParleySlot()
    ParleyGuard = None
    ParleySuspect = None
    ParleyFaction = None
    ParleyJail = None
    ParleyQuote = 0
    ParleyCost = 0
    ParleyBribe = false
    ParleyPleaRefused = false
    ParleyNoCoin = false
    ParleyDemand = false
    ParleyResisting = false
    ParleyIntervened = false
    ParleyEpoch += 1
EndFunction

Bool Function _IsParleyParty(Actor akSpeaker, Bool abGuard)
    If ParleySuspect == None || akSpeaker == None
        Return false
    EndIf
    If abGuard
        Return akSpeaker == ParleyGuard
    EndIf
    Return akSpeaker == ParleySuspect
EndFunction

; ----- The parley actions (Arrest category); each refuses unless the speaker holds that side -----

Bool Function PayOffCharge_Internal(Actor akSuspect)
    {PayOffCharge: the suspect settles from their own coin - the fine below ArrestBountyThreshold, a
     bribe at or above it. Short of coin, payment is not offered again.}
    If !_IsParleyParty(akSuspect, false) || ParleyResisting || ParleyNoCoin
        Return false
    EndIf
    _ParleyPay()
    Return true
EndFunction

Bool Function GoQuietly_Internal(Actor akSuspect)
    {GoQuietly: the suspect gives themselves up; the guard takes them to jail.}
    If !_IsParleyParty(akSuspect, false) || ParleyResisting
        Return false
    EndIf
    _ParleyToCustody("quiet", "")
    Return true
EndFunction

Bool Function RefuseArrest_Internal(Actor akSuspect)
    {RefuseArrest: the suspect resists; the bounty grows and the guard fights them.}
    If !_IsParleyParty(akSuspect, false) || ParleyResisting
        Return false
    EndIf
    _ParleyResist("refused")
    Return true
EndFunction

Bool Function DropTheCharge_Internal(Actor akGuard)
    {DropTheCharge: the guard is moved by the suspect's case and lets the charge drop.}
    If !_IsParleyParty(akGuard, true) || ParleyPleaRefused || ParleyResisting
        Return false
    EndIf
    _ParleyWaive()
    Return true
EndFunction

Bool Function PressTheCharge_Internal(Actor akGuard)
    {PressTheCharge: the guard rejects the plea; the suspect must pay, come quietly or refuse.}
    If !_IsParleyParty(akGuard, true) || ParleyPleaRefused || ParleyResisting
        Return false
    EndIf
    ParleyPleaRefused = true
    _SyncParleyFlags()
    Return true
EndFunction

Bool Function TakeThemIn_Internal(Actor akGuard)
    {TakeThemIn: the guard ends the talk and demands an answer now; ParleyDriver gives the suspect a
     few seconds, then the guard takes them in.}
    If !_IsParleyParty(akGuard, true) || ParleyDemand || ParleyResisting
        Return false
    EndIf
    Actor suspect = ParleySuspect
    ParleyPleaRefused = true
    ParleyDemand = true
    _SyncParleyFlags()
    If ParleySuspect != suspect || ParleyResisting
        Return true
    EndIf
    _ParleyNarrate("*" + akGuard.GetDisplayName() + " has had enough talk: " + suspect.GetDisplayName() + " must pay, come quietly or refuse - now.*", suspect, akGuard)
    Return true
EndFunction

Event OnParleyEvent(String asEventName, String asKind, Float afUnused, Form akSender)
    {ParleyDriver's report (the kinds are listed in ParleyDriver.h). sender: the actor a nudge
     names, else the suspect.}
    If ParleySuspect == None || !ArrestScript
        Return
    EndIf
    Actor guard = ParleyGuard
    Actor suspect = ParleySuspect
    If akSender != None && akSender != guard && akSender != suspect
        Return ; another parley's late event
    EndIf
    String guardName = guard.GetDisplayName()
    String suspectName = suspect.GetDisplayName()
    If ParleySuspect != suspect
        Return ; closed while the names were read
    EndIf
    ; A refusal replaces the talk: only the fight's own ends and an outside close still count.
    If ParleyResisting && asKind != "subdued" && asKind != "escaped" && asKind != "gone" && asKind != "interrupted" && asKind != "cancelled" && asKind != "intervened"
        Return
    EndIf

    If asKind == "nudge"
        Actor speaker = akSender as Actor
        If speaker == None || SkyrimNetApi.GetSpeechQueueSize() > 0
            Return ; the driver prods again once it is quiet
        EndIf
        Actor other = guard
        If speaker == guard
            other = suspect
        EndIf
        _ParleyNarrate("", speaker, other)
    ElseIf asKind == "press"
        _ParleyNarrate("*" + guardName + " grows impatient and presses " + suspectName + " to settle the matter.*", guard, suspect)
    ElseIf asKind == "final"
        _ParleyNarrate("*" + guardName + " has heard enough and wants an answer now: pay, come quietly, or refuse.*", guard, suspect)
    ElseIf asKind == "timeout:custody" || asKind == "demandup" || asKind == "verdict:custody"
        _ParleyToCustody(asKind, "*" + guardName + " has heard enough and takes " + suspectName + " by the arm.*")
    ElseIf asKind == "intervened"
        If ParleyResisting
            _ParleyIntervened(guard, suspect)
        EndIf
    ElseIf asKind == "subdued"
        _ParleyToCustody(asKind, "*" + suspectName + " is beaten, and " + guardName + " takes them in.*")
    ElseIf asKind == "verdict:waived"
        _ParleyWaive()
    ElseIf asKind == "verdict:paid"
        If ParleyNoCoin || !_ParleyPay()
            ; _ParleyPay yields: a refusal may have claimed the parley meanwhile.
            If ParleySuspect == suspect && !ParleyResisting
                _ParleyToCustody(asKind, "*" + guardName + " has heard enough and takes " + suspectName + " by the arm.*")
            EndIf
        EndIf
    ElseIf asKind == "verdict:refused" || asKind == "pairfight"
        _ParleyResist(asKind)
    ElseIf asKind == "settled"
        _ParleyNarrate("*With the bounty paid, " + guardName + " lets " + suspectName + " go.*", guard, suspect)
        EndParley(asKind)
    ElseIf asKind == "away"
        _ParleyNarrate("*" + guardName + " calls after " + suspectName + ": this is not over.*", guard, suspect)
        EndParley(asKind)
    Else
        ; timeout:standdown, escaped, gone, interrupted, cancelled
        EndParley(asKind)
    EndIf
EndEvent

Bool Function IsParleyLive()
    {True while a guard questions one of the player's people (one parley at a time).}
    Return ParleySuspect != None
EndFunction

Bool Function IsParleyGuard(Actor akActor)
    Return akActor != None && ParleySuspect != None && akActor == ParleyGuard
EndFunction

Bool Function IsParleySuspect(Actor akActor)
    Return akActor != None && akActor == ParleySuspect
EndFunction
