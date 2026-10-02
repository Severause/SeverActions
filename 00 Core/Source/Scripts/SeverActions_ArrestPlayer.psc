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
    {The confronting guard, or None. SeverActions_Arrest's OnOrphanCleanup and
     ClearStaleArrestState exempt it: during persuasion it holds FollowTargetKW on the player.}
    Return ConfrontingGuard
EndFunction
