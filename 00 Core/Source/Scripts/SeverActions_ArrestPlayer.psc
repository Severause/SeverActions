Scriptname SeverActions_ArrestPlayer Extends Quest
{Player-arrest + persuasion subsystem (Wave 5b extraction).

 Owns the entire player-confrontation FSM (the path that fires when a guard
 confronts the PLAYER about their bounty, separate from the same-cell or
 dispatch flows that arrest NPCs):

   Idle
    └─ ArrestPlayer_Internal(guard) ──┐
                                       ▼
                              ShowPlayerArrestMenu()
                                       │
                ┌──────────┬───────────┼───────────┬──────────┐
                ▼          ▼           ▼           ▼          ▼
         Pay Fine    Submit Arrest  Resist     Bribe      Persuade
              │            │          │          │           │
              └─clear──────┤          ▼          └─clear─    ▼
                           ▼      Combat                  HandlePersuade
                        Vanilla   ResistArrestFaction      (timer + follow)
                          Jail    set; OnUpdate watches      │
                                  for combat end →           │
                                  re-absorb bounty           ▼
                                                  CheckPersuasionProgress
                                                  (timeout / distance)
                                                          │
                                                  ┌───────┴───────┐
                                                  ▼               ▼
                                          Accept(by AI)   Reject/Fail
                                              │                │
                                              ▼                ▼
                                          Clear bounty   Show menu w/o
                                          + release      Persuade option

 This script runs its OWN OnUpdate so the persuasion timer and post-resist
 combat cleanup are independent of the arrest.psc update loop. arrest.psc's
 OnUpdate no longer carries InPersuasionMode / ResistArrestFaction branches.

 Wired YAML actions (scriptName: SeverActions_ArrestPlayer):
   - arrestplayer.yaml         → ArrestPlayer_Internal
   - acceptpersuasion.yaml     → AcceptPersuasion_Internal
   - rejectpersuasion.yaml     → RejectPersuasion_Internal

 The 6 tunable Auto properties (ArrestPlayerCooldown, PersuasionTimeLimit,
 PersuasionFollowDistance, BribeMultiplier, ArrestBountyThreshold,
 ResistBountyIncrease) intentionally STAY on the parent SeverActions_Arrest
 script — moving them would invalidate VMAD on existing saves and silently
 reset users' MCM tunings. PlayerScript reads them via the back-reference.}

; =============================================================================
; SCRIPT REFERENCES
; =============================================================================

SeverActions_Arrest Property ArrestScript Auto
{Back-reference to the main arrest script. Filled at runtime via Maintenance().
 Required — every function on this script reaches into ArrestScript for
 properties (packages, keywords, item refs, tunables), the Bounty/MCM
 references for bounty CRUD, and DebugMsg / GetCrimeFactionForGuard /
 GetHoldNameForGuard helpers.}

; =============================================================================
; STATE — Confrontation + persuasion FSM
; =============================================================================

Actor ConfrontingGuard          ; Guard currently confronting player
Faction ConfrontingFaction      ; Crime faction for current confrontation
Int ConfrontingBounty           ; Bounty amount at time of confrontation
Bool PersuadeAttempted          ; True if player already tried persuade (can't retry)
Bool PaymentFailed              ; True if player tried to pay/bribe but couldn't afford it
Bool InPersuasionMode           ; True if currently in persuasion conversation
Float PersuasionStartTime       ; DEPRECATED in Phase 2.2 — left declared so existing saves don't trip a missing-var lookup. Native PersuasionMonitor owns the start time now.

Float LastArrestTime            ; Real time when last arrest confrontation started (for cooldown)
Faction ResistArrestFaction     ; Tracks which faction's vanilla crime gold needs cleanup after resist combat
Float ResistArrestStartTime     ; DEPRECATED post-Phase 2.1 — native ResistArrestMonitor owns the watchdog clock now. Field kept declared so existing saves' VMAD lookups don't fail, and still cleared to 0 in OnResistCombatEndedEvent for tidiness. No live consumer.
Float Property ResistMaxWaitSeconds = 600.0 Auto
{Hard upper bound on the post-resist combat-end poll. After 10 minutes of
 real-time still showing IsInCombat()==true, we assume the player has hit a
 combat lock-out (hostile script, stuck NPC, ESS bug) and force-clear the
 ResistArrestFaction state so the OnUpdate loop stops ticking. Configurable
 via MCM if a user has a particularly long combat scenario.}

; =============================================================================
; LIFECYCLE
; =============================================================================

Function Maintenance()
    {Resolve the ArrestScript back-reference at runtime if CK didn't fill it.
     Called from the parent SeverActions_Arrest.Maintenance after that script
     finishes its own setup so we know the parent is alive.}
    If !ArrestScript
        Quest q = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
        If q
            ArrestScript = q as SeverActions_Arrest
        EndIf
    EndIf

    ; Register for game-load so we can re-arm OnUpdate / native trackers if a
    ; save was made while persuasion or post-resist-combat tracking was active.
    ; Script vars survive saves; the OnUpdate registration and the native
    ; PersuasionMonitor entry do not.
    RegisterForModEvent("OnPlayerLoadGame", "OnPlayerLoadGame")

    ; Phase 2.2 — native persuasion monitor signals timeout/distance/death
    ; via ModEvent instead of the Papyrus OnUpdate poll.
    RegisterForModEvent("SeverActions_PersuasionFailed", "OnPersuasionFailedEvent")

    ; Phase 2.1 — native resist-arrest monitor signals combat-end via ModEvent.
    RegisterForModEvent("SeverActions_ResistCombatEnded", "OnResistCombatEndedEvent")

    ; PrismaUI arrest prompt — player's choice is posted back via this
    ; ModEvent (strArg = "pay_fine"|"submit"|"resist"|"bribe"|"persuade",
    ; sender = guard, numArg = bounty). Routes to the Handle*() funcs below.
    RegisterForModEvent("SeverActions_ArrestPromptChoice", "OnArrestPromptChoiceEvent")
EndFunction

Event OnPlayerLoadGame()
    {Re-arm this script's tracking if its FSM state is non-clean on load.
     Without this, a save+load during persuasion silently freezes the
     timer, and a save+load during post-resist combat leaves the vanilla
     crime gold un-reabsorbed (ResistArrestFaction never gets cleared).}

    ; Persuasion: re-seed the native monitor. PersuasionStartTime is no longer
    ; tracked in Papyrus — the simplest correct behavior on load is to grant
    ; a fresh full time budget (matches the legacy real-time behavior across
    ; process restart, where Utility.GetCurrentRealTime zeroed and elapsed
    ; went negative anyway).
    If InPersuasionMode && ConfrontingGuard != None
        If ArrestScript
            ArrestScript.DebugMsg("PlayerScript OnPlayerLoadGame: re-arming native PersuasionMonitor")
        EndIf
        SeverActionsNative.Native_Persuasion_Begin(ConfrontingGuard, Game.GetPlayer(), ArrestScript.PersuasionTimeLimit, ArrestScript.PersuasionFollowDistance)
    EndIf

    ; Phase 2.1: post-resist cleanup is now event-driven via the native
    ; ResistArrestMonitor (TESCombatEvent sink + watchdog). Re-seed it on
    ; load so a save taken mid-resist still gets the bounty re-absorbed
    ; the next time combat ends (or after the watchdog budget).
    If ResistArrestFaction != None
        If ArrestScript
            ArrestScript.DebugMsg("PlayerScript OnPlayerLoadGame: re-arming native ResistArrestMonitor")
        EndIf
        SeverActionsNative.Native_Resist_Begin(ResistMaxWaitSeconds)
    EndIf
EndEvent

Event OnUpdate()
    {Re-open watchdog for the PrismaUI arrest prompt. Fired ~2s after the
     prompt was opened. If the player Esc-dismissed the overlay but hasn't
     made a choice yet (ConfrontingGuard still set, no persuasion in flight),
     re-show the prompt so the FSM can't get stranded. Otherwise keep
     polling — the 60s JS drain bar is the hard upper bound either way.

     This is the only consumer of OnUpdate on this script — Phase 2.1/2.2
     migrated persuasion + resist polling to native event-driven monitors,
     so we own the OnUpdate channel exclusively here.}

    If ConfrontingGuard == None
        ; FSM cleared — nothing to watch.
        Return
    EndIf
    If InPersuasionMode
        ; Persuasion mini-flow owns the player now; don't re-open the menu.
        Return
    EndIf

    If !SeverActionsNative.PrismaUI_IsArrestPromptAvailable()
        ; PrismaUI vanished mid-confrontation (shouldn't happen, but defensive).
        ; Fall through to the SkyMessage path by re-firing the menu.
        ShowPlayerArrestMenu()
        Return
    EndIf

    If SeverActionsNative.PrismaUI_IsArrestPromptOpen()
        ; Player still has the prompt visible — keep watching.
        RegisterForSingleUpdate(2.0)
        Return
    EndIf

    ; Prompt was dismissed (Escape) but the confrontation is still alive —
    ; reopen so the player can't permanently escape the choice. Esc acts as
    ; "give me a moment to look around," not "I give up." The drain bar
    ; runs fresh on the new open.
    If ArrestScript
        ArrestScript.DebugMsg("Arrest prompt dismissed but FSM is live — reopening")
    EndIf
    ShowPlayerArrestMenu()
EndEvent

Event OnArrestPromptChoiceEvent(String asEventName, String asChoice, Float afBounty, Form akSender)
    {Async result from PrismaUIArrestPromptBridge. The C++ side fires this
     ModEvent when the player clicks a button (or the 60s drain bar auto-
     fires "submit"). asChoice is one of pay_fine/submit/resist/bribe/
     persuade — route to the same Handle*() funcs the SkyMessage path uses.

     akSender is the guard the prompt was opened for. If the confrontation
     has cleared OR moved to a different guard since the prompt opened,
     drop the event — the click is stale.}

    If ConfrontingGuard == None || ConfrontingFaction == None
        If ArrestScript
            ArrestScript.DebugMsg("ArrestPromptChoice arrived but state is clean — ignoring")
        EndIf
        Return
    EndIf

    If akSender != ConfrontingGuard
        If ArrestScript
            ArrestScript.DebugMsg("ArrestPromptChoice for wrong guard — ignoring stale event")
        EndIf
        Return
    EndIf

    ; Player engaged with the prompt — stop the re-open watchdog. Handlers
    ; below will either fully clear state or set up their own follow-ups.
    UnregisterForUpdate()

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
    {Native PersuasionMonitor fired a failure. asReason is "timeout", "distance",
     or "died". afUnused is a reserved zero — the FormID lives implicitly in
     akSender (the guard); float32 can't round-trip FormIDs ≥ 0x01000000
     without precision loss, so the C++ side passes 0.0 there. Dispatch into
     the existing OnPersuasionFailed logic (which owns narration +
     persistent-event + menu-reshow side effects). For "died" we short-circuit
     and just clear state — matches the legacy CheckPersuasionProgress branch
     that called ClearPlayerConfrontationState directly for dead guards (no
     menu reshow when the confronter is dead).}
    If asReason == "died"
        If ArrestScript
            ArrestScript.DebugMsg("Persuasion ended — guard died (native monitor)")
        EndIf
        ClearPlayerConfrontationState()
    Else
        OnPersuasionFailed(asReason)
    EndIf
EndEvent

Function ResetCooldowns()
    {Zero LastArrestTime so a stale value from a prior session doesn't gate
     the first ArrestPlayer attempt of a new session. Called from
     SeverActions_Arrest.ResetSessionCooldowns on OnInit + OnPlayerLoadGame.}
    LastArrestTime = 0.0
EndFunction

; =============================================================================
; POST-RESIST COMBAT-END HANDLER — wired via ModEvent from ResistArrestMonitor
; =============================================================================
; Phase 2.1 migration: the legacy OnUpdate poll on this script polled
; Game.GetPlayer().IsInCombat() once per real second to detect combat-end
; and re-absorb vanilla crime gold into the tracked bounty system. The
; native ResistArrestMonitor now sinks TESCombatEvent directly and fires
; SeverActions_ResistCombatEnded the instant the player transitions to
; ACTOR_COMBAT_STATE::kNone — or, as a fallback, after ResistMaxWaitSeconds
; of real time elapse (B16 combat-lockout safety net). OnUpdate is no
; longer used on this script.

Event OnResistCombatEndedEvent(String asEventName, String asReason, Float afUnused, Form akSender)
    {Native ResistArrestMonitor fired. asReason is "combatEnd" (player
     transitioned out of combat) or "timeout" (watchdog tripped after
     ResistMaxWaitSeconds because the engine combat flag never cleared —
     suspected combat-lockout). Both paths run the same vanilla-bounty
     re-absorption pass and clear the resist tracking state.}

    If ResistArrestFaction == None
        ; Stale event — already cleared (e.g. release path beat the
        ; combat-end signal). Idempotent no-op.
        Return
    EndIf

    Int vanillaBounty = ResistArrestFaction.GetCrimeGold()
    Bool watchdog = (asReason == "timeout")

    If vanillaBounty > 0
        If ArrestScript && ArrestScript.BountyScript
            ArrestScript.BountyScript.SetTrackedBounty(ResistArrestFaction, vanillaBounty)
        EndIf
        ResistArrestFaction.SetCrimeGold(0)
        ResistArrestFaction.SetCrimeGoldViolent(0)
        If ArrestScript
            If watchdog
                ArrestScript.DebugMsg("Post-resist cleanup: WATCHDOG fired — re-absorbing " + vanillaBounty + " vanilla bounty (native monitor reports combat-lockout)")
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

; =============================================================================
; ARRESTPLAYER ACTION ENTRY POINT — wired via arrestplayer.yaml
; =============================================================================

Bool Function ArrestPlayer_Internal(Actor akGuard)
    {Guard confronts player about their bounty.
     Shows MessageBox with options based on bounty amount.
     Returns true if confrontation started successfully.}

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

    ; Block if already in an active confrontation (prevents stacking messageboxes)
    If ConfrontingGuard != None
        ArrestScript.DebugMsg("Already in confrontation with " + ConfrontingGuard.GetDisplayName() + ", ignoring new arrest request")
        Return false
    EndIf

    ; Check cooldown - prevent spamming arrest during persuasion or shortly after
    Float currentTime = Utility.GetCurrentRealTime()
    If LastArrestTime > 0.0 && (currentTime - LastArrestTime) < ArrestScript.ArrestPlayerCooldown
        Float remaining = ArrestScript.ArrestPlayerCooldown - (currentTime - LastArrestTime)
        ArrestScript.DebugMsg("ArrestPlayer on cooldown, " + remaining + " seconds remaining")
        Return false
    EndIf

    ; Get the crime faction for this guard
    Faction crimeFaction = ArrestScript.GetCrimeFactionForGuard(akGuard)
    If crimeFaction == None
        ArrestScript.DebugMsg("ERROR: Could not determine guard's crime faction")
        Return false
    EndIf

    ; Get current tracked bounty (not vanilla crime gold which stays at 0)
    Int bounty = 0
    If ArrestScript.BountyScript
        bounty = ArrestScript.BountyScript.GetTrackedBounty(crimeFaction)
    EndIf
    If bounty <= 0
        ; Auto-add 300 bounty if guard is arresting with no existing bounty
        ; This handles cases where ReportCrime wasn't used first
        bounty = 300
        If ArrestScript.BountyScript
            ArrestScript.BountyScript.SetTrackedBounty(crimeFaction, bounty)
        EndIf
        String holdName = ArrestScript.GetHoldNameForGuard(akGuard)
        ArrestScript.DebugMsg("Auto-added " + bounty + " bounty for arrest in " + holdName)
        Debug.Notification("Bounty added: " + bounty + " gold in " + holdName)

        ; Register persistent event so NPCs know about this
        String eventMsg = akGuard.GetDisplayName() + " is arresting the player and added " + bounty + " gold bounty in " + holdName + "."
        SkyrimNetApi.RegisterPersistentEvent(eventMsg, akGuard, Game.GetPlayer())
    EndIf

    ; Check if already in a confrontation (defensive — covered above too)
    If ConfrontingGuard != None
        ArrestScript.DebugMsg("WARNING: Already in a confrontation, canceling previous")
        CancelPlayerConfrontation()
    EndIf

    ; Store confrontation state
    ConfrontingGuard = akGuard
    ConfrontingFaction = crimeFaction
    ConfrontingBounty = bounty
    LastArrestTime = Utility.GetCurrentRealTime() ; Start cooldown

    String holdName2 = ArrestScript.GetHoldNameForGuard(akGuard)
    ArrestScript.DebugMsg("Guard confronting player - Tracked Bounty: " + bounty + " in " + holdName2)

    ; Show appropriate MessageBox based on bounty
    ShowPlayerArrestMenu()

    Return true
EndFunction

Function ShowPlayerArrestMenu()
    {Display the appropriate arrest menu based on bounty and state.
     Tries PrismaUI overlay first (non-pausing HUD card), falls back to
     SkyMessage for proper button support when PrismaUI isn't available.
     Pay/bribe options hidden after player fails to afford them once.}

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

    ; PrismaUI overlay — non-pausing HUD card. Returns false if the bridge
    ; isn't ready, another prompt is already open, or another view has
    ; focus; in that case we drop through to SkyMessage.
    If SeverActionsNative.PrismaUI_IsArrestPromptAvailable()
        String guardName = ConfrontingGuard.GetDisplayName()
        Bool opened = SeverActionsNative.PrismaUI_OpenArrestPrompt( \
            ConfrontingGuard, guardName, holdName, bounty, bribeCost, \
            PaymentFailed, PersuadeAttempted, lowBounty, 60000)
        If opened
            ; Choice will arrive asynchronously via OnArrestPromptChoiceEvent.
            ; Arm the re-open watchdog (see OnUpdate below) so an Escape-
            ; dismissed prompt comes back instead of leaving the FSM wedged.
            RegisterForSingleUpdate(2.0)
            Return
        EndIf
    EndIf

    If lowBounty
        ; Low bounty - fine or refuse (no jail option for minor offenses)
        If PaymentFailed
            ; Already failed to pay - only submit or refuse
            String bodyText = "You have a bounty of " + bounty + " gold in " + holdName + ". The guard won't accept payment attempts anymore."
            resultStr = SkyMessage.Show(bodyText, "Submit to Arrest", "Refuse", getIndex = true)

            If resultStr == "0"
                HandleSubmitToArrest()
            Else
                HandleResistArrest()
            EndIf
        Else
            ; Can still try to pay
            String bodyText = "You have a bounty of " + bounty + " gold in " + holdName + ". Pay your fine or face the consequences."
            resultStr = SkyMessage.Show(bodyText, "Pay Fine (" + bounty + " gold)", "Refuse", getIndex = true)

            If resultStr == "0"
                HandlePayFine()
            Else
                HandleResistArrest()
            EndIf
        EndIf
    Else
        ; High bounty - arrest options
        String bodyText = "You have a bounty of " + bounty + " gold in " + holdName + "."

        If PaymentFailed && PersuadeAttempted
            ; No payment, no persuade - only submit or resist
            bodyText += " The guard has lost all patience. Submit or resist."
            resultStr = SkyMessage.Show(bodyText, "Submit to Arrest", "Resist Arrest", getIndex = true)

            If resultStr == "0"
                HandleSubmitToArrest()
            Else
                HandleResistArrest()
            EndIf

        ElseIf PaymentFailed && !PersuadeAttempted
            ; No payment, but can persuade
            bodyText += " The guard won't accept payment anymore."
            resultStr = SkyMessage.Show(bodyText, "Submit to Arrest", "Resist Arrest", "Persuade", getIndex = true)

            If resultStr == "0"
                HandleSubmitToArrest()
            ElseIf resultStr == "1"
                HandleResistArrest()
            Else
                HandlePersuade()
            EndIf

        ElseIf !PaymentFailed && PersuadeAttempted
            ; Can bribe, but no persuade
            bodyText += " The guard has lost patience. Make your choice now."
            resultStr = SkyMessage.Show(bodyText, "Submit to Arrest", "Resist Arrest", "Bribe (" + bribeCost + " gold)", getIndex = true)

            If resultStr == "0"
                HandleSubmitToArrest()
            ElseIf resultStr == "1"
                HandleResistArrest()
            Else
                HandleBribe()
            EndIf

        Else
            ; All options available
            bodyText += " Submit to arrest or face the consequences."
            resultStr = SkyMessage.Show(bodyText, "Submit to Arrest", "Resist Arrest", "Bribe (" + bribeCost + " gold)", "Persuade", getIndex = true)

            If resultStr == "0"
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

; =============================================================================
; OPTION HANDLERS — wire from ShowPlayerArrestMenu
; =============================================================================

Function HandlePayFine()
    {Player pays the fine - clear bounty, or guard gets angry if can't afford}

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
        ; Player can afford - pay the fine
        player.RemoveItem(ArrestScript.Gold001, bounty, true)
        If ArrestScript.BountyScript
            ArrestScript.BountyScript.ClearTrackedBounty(ConfrontingFaction)
        EndIf
        ConfrontingFaction.SetCrimeGold(0) ; Also clear vanilla crime gold as safety net

        ; Direct narration - guard accepts fine
        String narration = "*" + ConfrontingGuard.GetDisplayName() + " accepts the " + bounty + " gold fine and pockets it.*"
        SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, player)

        Debug.Notification("Paid " + bounty + " gold fine")
        ArrestScript.DebugMsg("Player paid fine: " + bounty)

        ClearPlayerConfrontationState()
    Else
        ; Player can't afford - guard gets angry, no more payment options
        PaymentFailed = true

        ; Direct narration - guard is angry
        String narration = "*" + ConfrontingGuard.GetDisplayName() + " scowls as the player fumbles through their coin purse, coming up short.* \"You waste my time with empty pockets? Don't try that again!\""
        SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, player)

        Debug.Notification("The guard won't accept payment attempts anymore!")
        ArrestScript.DebugMsg("Player couldn't afford fine, payment options removed")

        ; Show menu again without payment options
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

    ; Apply tracked bounty to vanilla system so jail works correctly
    If ArrestScript.BountyScript
        ArrestScript.BountyScript.ApplyTrackedBountyToVanilla(ConfrontingFaction)
    EndIf

    ; Use vanilla jail system
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

    ; Add resist bounty to tracked system
    If ArrestScript.BountyScript
        ArrestScript.BountyScript.ModTrackedBounty(ConfrontingFaction, ArrestScript.ResistBountyIncrease)
        ; Apply all tracked bounty to vanilla so guards naturally become hostile
        ArrestScript.BountyScript.ApplyTrackedBountyToVanilla(ConfrontingFaction)
    EndIf

    ; Store resist faction so we can clean up vanilla crime gold after combat ends.
    ; We'll re-absorb it back into tracked bounty once combat settles. The
    ; native ResistArrestMonitor (Phase 2.1) sinks TESCombatEvent and fires
    ; SeverActions_ResistCombatEnded the instant the player exits combat —
    ; or after ResistMaxWaitSeconds for combat-lockout fallback. The
    ; ResistArrestStartTime field is left written for save-recovery state
    ; (OnPlayerLoadGame re-arms the native monitor when it's non-zero).
    ResistArrestFaction = ConfrontingFaction
    ResistArrestStartTime = Utility.GetCurrentRealTime()
    SeverActionsNative.Native_Resist_Begin(ResistMaxWaitSeconds)

    ; Make guard hostile. We deliberately do NOT bump Aggression — guards
    ; baseline at 1 (Aggressive) which is enough; ApplyTrackedBountyToVanilla
    ; above + StartCombat is what actually triggers the engagement.
    ; Setting Aggression=2 used to risk persistence if combat ended abnormally
    ; (no auto-restore on this path), so we just removed it.
    ConfrontingGuard.StartCombat(Game.GetPlayer())

    Debug.Notification("Bounty increased by " + ArrestScript.ResistBountyIncrease + " gold!")

    ClearPlayerConfrontationState()
    ; Phase 2.1: no RegisterForSingleUpdate here any more — the native
    ; ResistArrestMonitor (begun above via Native_Resist_Begin) drives
    ; the cleanup via SeverActions_ResistCombatEnded ModEvent.
EndFunction

Function HandleBribe()
    {Player bribes guard - pay extra to clear bounty, or guard gets angry if can't afford}

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
        ; Player can afford - bribe successful
        player.RemoveItem(ArrestScript.Gold001, bribeCost, true)
        If ArrestScript.BountyScript
            ArrestScript.BountyScript.ClearTrackedBounty(ConfrontingFaction) ; Clear our tracked bounty
        EndIf
        ConfrontingFaction.SetCrimeGold(0) ; Also clear vanilla crime gold as safety net

        ; Direct narration - guard takes bribe
        String narration = "*" + ConfrontingGuard.GetDisplayName() + " glances around, then quietly takes the " + bribeCost + " gold bribe, looking the other way.*"
        SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, player)

        Debug.Notification("Bribed guard with " + bribeCost + " gold")
        ArrestScript.DebugMsg("Player bribed guard: " + bribeCost)

        ClearPlayerConfrontationState()
    Else
        ; Player can't afford - guard gets angry, no more payment options
        PaymentFailed = true

        ; Direct narration - guard is insulted by pathetic bribe attempt
        String narration = "*" + ConfrontingGuard.GetDisplayName() + " looks at the player's meager coin purse with contempt.* \"You think you can bribe me with that pitiful amount? Don't insult me again!\""
        SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, player)

        Debug.Notification("The guard won't accept payment attempts anymore!")
        ArrestScript.DebugMsg("Player couldn't afford bribe, payment options removed")

        ; Show menu again without payment options
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

    ; Mark that persuade has been attempted
    PersuadeAttempted = true
    InPersuasionMode = true
    ; PersuasionStartTime is no longer tracked in Papyrus — the native
    ; PersuasionMonitor owns the steady_clock-based start time and fires
    ; SeverActions_PersuasionFailed on timeout / distance / death.

    ; Link guard to player so follow package works
    SeverActionsNative.LinkedRef_Set(ConfrontingGuard, Game.GetPlayer(), ArrestScript.SeverActions_FollowTargetKW)

    ; Apply follow package to guard
    If ArrestScript.SeverActions_GuardFollowPlayer
        ActorUtil.AddPackageOverride(ConfrontingGuard, ArrestScript.SeverActions_GuardFollowPlayer, ArrestScript.PackagePriority, 1)
        ConfrontingGuard.EvaluatePackage()
        ArrestScript.DebugMsg("Guard following player for persuasion")
    EndIf

    ; Direct narration to start the conversation
    String holdName = ArrestScript.GetHoldNameForGuard(ConfrontingGuard)
    String narration = "*" + ConfrontingGuard.GetDisplayName() + " pauses, willing to hear what the player has to say about their " + ConfrontingBounty + " gold bounty in " + holdName + ".*"
    SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, Game.GetPlayer())

    ; Register persistent event so SkyrimNet knows the context
    String eventMsg = "The player is trying to convince " + ConfrontingGuard.GetDisplayName() + " to overlook their " + ConfrontingBounty + " gold bounty in " + holdName + ". The guard is listening but skeptical."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, ConfrontingGuard, Game.GetPlayer())

    Debug.Notification("You have " + (ArrestScript.PersuasionTimeLimit as Int) + " seconds to convince the guard...")

    ; Phase 2.2: native PersuasionMonitor owns the timeout / distance / death
    ; tick. Fires SeverActions_PersuasionFailed ModEvent on any trip.
    SeverActionsNative.Native_Persuasion_Begin(ConfrontingGuard, Game.GetPlayer(), ArrestScript.PersuasionTimeLimit, ArrestScript.PersuasionFollowDistance)
EndFunction

; =============================================================================
; PERSUASION SYSTEM
; =============================================================================

; Phase 2.2: CheckPersuasionProgress (38 LOC) deleted — replaced by
; Native/src/PersuasionMonitor.h. The native monitor checks
; timeout / distance / death once per real second and fires the
; SeverActions_PersuasionFailed ModEvent. OnPersuasionFailedEvent (above)
; routes the failure reason into the existing OnPersuasionFailed body.

; =============================================================================
; PERSUASION ACTIONS — wired via acceptpersuasion.yaml + rejectpersuasion.yaml
; =============================================================================

Bool Function CanUsePersuasionAction(Actor akGuard)
    {Eligibility helper for persuasion actions (AcceptPersuasion, RejectPersuasion).
     Returns true only if this guard is the one confronting the player in
     persuasion mode.}

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
    {Called by SkyrimNet when the AI decides the player's argument is convincing.
     Clears bounty and ends persuasion successfully.
     Returns true if successful.}

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

    ; Clear tracked bounty and vanilla crime gold
    If ArrestScript.BountyScript
        ArrestScript.BountyScript.ClearTrackedBounty(ConfrontingFaction)
    EndIf
    ConfrontingFaction.SetCrimeGold(0) ; Safety net — clear vanilla crime gold too

    StopPersuasionFollow()

    ; Direct narration
    String narration = "*" + ConfrontingGuard.GetDisplayName() + " sighs and nods reluctantly.* \"Fine. Get out of here before I change my mind.\""
    SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, Game.GetPlayer())

    ; Persistent event for success
    String holdName = ArrestScript.GetHoldNameForGuard(ConfrontingGuard)
    String eventMsg = "The player convinced " + ConfrontingGuard.GetDisplayName() + " to overlook their " + ConfrontingBounty + " gold bounty in " + holdName + "."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, Game.GetPlayer(), ConfrontingGuard)

    Debug.Notification("The guard lets you go with a warning")

    ClearPlayerConfrontationState()
    Return true
EndFunction

Bool Function RejectPersuasion_Internal(Actor akGuard)
    {Called by SkyrimNet when the AI decides the player's argument is NOT convincing.
     Ends persuasion mode and forces the player to choose: submit or resist.
     Returns true if successful.}

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

    InPersuasionMode = false

    ; The guard will provide their own narration via SkyrimNet dialogue
    ; Just register the persistent event
    String holdName = ArrestScript.GetHoldNameForGuard(ConfrontingGuard)
    String eventMsg = ConfrontingGuard.GetDisplayName() + " was not convinced by the player's arguments and demands they face justice for their " + ConfrontingBounty + " gold bounty in " + holdName + "."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, ConfrontingGuard, Game.GetPlayer())

    Debug.Notification("The guard is not convinced!")

    ; Show menu again without persuade option (since they already tried)
    ShowPlayerArrestMenu()
    Return true
EndFunction

Function OnPersuasionFailed(String reason)
    {Called when persuasion fails (timeout or distance)}

    If !ArrestScript
        Return
    EndIf

    If !InPersuasionMode || ConfrontingGuard == None
        Return
    EndIf

    ArrestScript.DebugMsg("Persuasion failed: " + reason)

    StopPersuasionFollow()

    InPersuasionMode = false

    ; Direct narration - guard annoyed
    String narration
    If reason == "timeout"
        narration = "*" + ConfrontingGuard.GetDisplayName() + " grows impatient.* \"Enough talk! Make your choice now.\""
    Else
        narration = "*" + ConfrontingGuard.GetDisplayName() + " catches up, clearly annoyed.* \"Trying to run? That's it, no more games!\""
    EndIf
    SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, Game.GetPlayer())

    ; Persistent event for failure
    String holdName = ArrestScript.GetHoldNameForGuard(ConfrontingGuard)
    String eventMsg = ConfrontingGuard.GetDisplayName() + " grew tired of the player's excuses and demanded they submit to arrest."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, ConfrontingGuard, Game.GetPlayer())

    Debug.Notification("The guard has lost patience!")

    ; Show menu again without persuade option
    ShowPlayerArrestMenu()
EndFunction

; =============================================================================
; CLEANUP
; =============================================================================

Function StopPersuasionFollow()
    {Remove the guard follow-player package and clear the linked ref.
     Called at the end of every persuasion exit path (success, reject, fail, cancel).}
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
    {Cancel current player confrontation. Public — used by external paths
     (e.g. ArrestPlayer_Internal's defensive re-entry guard).}

    If ArrestScript
        ArrestScript.DebugMsg("Canceling player confrontation")
    EndIf

    If InPersuasionMode && ConfrontingGuard
        StopPersuasionFollow()
    EndIf

    ClearPlayerConfrontationState()
EndFunction

Function ClearPlayerConfrontationState()
    {Clear all player confrontation state.
     Note: also unregisters this script's OnUpdate. The HandleResistArrest path
     re-registers immediately afterward because it needs the post-resist tick
     loop alive even after the confrontation state is cleared.}

    ConfrontingGuard = None
    ConfrontingFaction = None
    ConfrontingBounty = 0
    PersuadeAttempted = false
    PaymentFailed = false
    InPersuasionMode = false

    ; Phase 2.2: tear down the native persuasion tracker. Idempotent — no-op
    ; if no entry is active. Covers every persuasion exit path because
    ; ClearPlayerConfrontationState is called by all of them.
    SeverActionsNative.Native_Persuasion_End()

    ; Close the PrismaUI arrest prompt if it happened to be open — covers the
    ; cancel-while-prompt-showing case (guard died, player fled, etc.). No-op
    ; when the prompt isn't open or PrismaUI isn't available.
    If SeverActionsNative.PrismaUI_IsArrestPromptOpen()
        SeverActionsNative.PrismaUI_CloseArrestPrompt()
    EndIf

    UnregisterForUpdate()
EndFunction

; =============================================================================
; PUBLIC QUERIES
; =============================================================================

Bool Function IsPlayerInConfrontation()
    {Check if player is currently being confronted by a guard.}
    Return ConfrontingGuard != None
EndFunction

Bool Function IsPlayerInPersuasion()
    {Check if player is currently in persuasion mode.}
    Return InPersuasionMode
EndFunction

Actor Function GetConfrontingGuard()
    {Return the guard currently confronting the player (or None). Used by
     SeverActions_Arrest.OnOrphanCleanup to exempt this guard from the
     stale-keyword sweep — during persuasion the guard legitimately holds
     SeverActions_FollowTargetKW pointing at the player.}
    Return ConfrontingGuard
EndFunction
