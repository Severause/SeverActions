Scriptname SeverActions_ArrestJudgment Extends Quest
{Phase-6 judgment hold subsystem (Wave 5b extraction).

 After a guard brings a prisoner back to the sender (the original NPC who
 ordered the arrest), the sender can:
   - OrderRelease: free the prisoner (uncuff, restore, back to normal)
   - OrderJailed: send the prisoner to jail (guard starts standard escort)
 If neither fires within JudgmentTimeLimit, defaults to jail.

 This subsystem is small but heavily coupled to the dispatch FSM in the
 parent SeverActions_Arrest script — DispatchGuard / DispatchTarget /
 DispatchSender / DispatchPhase / package properties / ReferenceAliases /
 cleanup helpers all live there. The back-reference ArrestScript property
 below is the bridge.

 Public API (also wired via orderrelease.yaml + orderjailed.yaml):
   - StartJudgment()       — called from CheckDispatchPhase5_Return to begin
   - ResetState()          — called from ClearDispatchState to wipe timer
   - CheckJudgmentProgress() — per-tick router target, called from arrest's
                               CheckDispatchProgress when DispatchPhase == 6
   - OrderRelease_Execute(akSender)
   - OrderJailed_Execute(akSender)
   - EndJudgment(released) — terminal cleanup; routes to release or jail-escort

 Attached to the same SeverActions quest (FormID 0x000D62) as every other
 sub-script. Resolve via `quest as SeverActions_ArrestJudgment` from any
 caller.}

; =============================================================================
; SCRIPT REFERENCES
; =============================================================================

SeverActions_Arrest Property ArrestScript Auto
{Back-reference to the main arrest script. Filled at runtime via Maintenance().
 Required — every function on this script reaches into ArrestScript for
 dispatch state, packages, aliases, cleanup helpers, and the same-cell
 escort hand-off. CK fill optional; runtime fallback always works.}

; =============================================================================
; STATE
; =============================================================================

Float JudgmentStartTime           ; Real time when judgment phase started
Float JudgmentTimeLimit = 90.0    ; Seconds before defaulting to jail

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
EndFunction

Function StartJudgment()
    {Begin the judgment timer. Called from CheckDispatchPhase5_Return when
     DispatchPhase transitions to 6, and from RecoverActiveDispatch on
     save/load recovery so the timer restarts cleanly.

     Marks the actor whose LLM eligibility gates OrderJailed/OrderRelease
     busy with reason "judgment". Which actor that is depends on who
     initiated the dispatch:
       - NPC sender (jarl, housecarl, witness): mark the SENDER. The LLM
         considers the sender as currentActor when offering the order
         actions, so the busy flag must sit on them.
       - Player sender: mark the GUARD. The _Execute functions accept the
         guard as a valid caller "acting on the player's behalf" (see
         OrderRelease_Execute:173 / OrderJailed_Execute:237), but since
         the player doesn't drive SkyrimNet's action selection, eligibility
         runs against the guard as the actual LLM speaker — so the busy
         flag must sit on the guard for that case.}
    JudgmentStartTime = Utility.GetCurrentRealTime()

    Actor target = ResolveBusyTarget()
    If target != None
        SeverActionsNative.Native_SkyrimNet_SetActorBusy(target, "judgment")
    EndIf
EndFunction

Function ResetState()
    {Clear the judgment timer. Called from ClearDispatchState so a stale
     timer doesn't bleed into the next dispatch cycle.

     Also clears any "judgment" busy flag still set on the dispatch's busy
     target — covers the CancelDispatch path that bypasses EndJudgment
     entirely. Idempotent: ClearActorBusy is safe to call on an actor
     that isn't busy.

     CRITICAL: callers must invoke this BEFORE nulling DispatchSender /
     DispatchGuard on ArrestScript, otherwise ResolveBusyTarget can't
     find the actor to clear and the busy flag leaks. See the reorder in
     SeverActions_Arrest.psc::ClearDispatchState.}
    JudgmentStartTime = 0.0

    Actor target = ResolveBusyTarget()
    If target != None
        SeverActionsNative.Native_SkyrimNet_ClearActorBusy(target)
    EndIf
EndFunction

Actor Function ResolveBusyTarget()
    {Returns the actor whose busy flag gates OrderJailed/OrderRelease
     eligibility for the current dispatch:
       - If sender is the player, returns the dispatch guard (the actual
         LLM speaker for the order actions in the player-initiated path).
       - Otherwise returns the sender (the LLM speaker in the standard
         NPC-initiated path).
     Returns None if ArrestScript is None or the resolved actor is None.}
    If !ArrestScript
        Return None
    EndIf
    Actor sender = ArrestScript.GetDispatchSender()
    If sender == Game.GetPlayer()
        Return ArrestScript.GetDispatchGuard()
    EndIf
    Return sender
EndFunction

; =============================================================================
; ROUTER — called from SeverActions_Arrest.CheckDispatchProgress (DispatchPhase == 6)
; =============================================================================

Function CheckJudgmentProgress()
    {Check if judgment hold has timed out or participants became invalid.}
    If !ArrestScript
        Return
    EndIf

    ; Cache references so we don't dereference ArrestScript repeatedly per tick.
    Actor guard    = ArrestScript.GetDispatchGuard()
    Actor prisoner = ArrestScript.GetDispatchTarget()
    Actor sender   = ArrestScript.GetDispatchSender()

    ; Validate participants
    If guard == None || guard.IsDead()
        ArrestScript.DebugMsg("Judgment: Guard died or invalid, releasing prisoner")
        EndJudgment(true)
        Return
    EndIf

    If prisoner == None || prisoner.IsDead()
        ArrestScript.DebugMsg("Judgment: Prisoner died or invalid, ending judgment")
        EndJudgment(false)
        Return
    EndIf

    If sender == None || sender.IsDead()
        ArrestScript.DebugMsg("Judgment: Sender died or invalid, defaulting to jail")
        EndJudgment(false)
        Return
    EndIf

    ; Check timeout
    Float elapsed = Utility.GetCurrentRealTime() - JudgmentStartTime
    If elapsed >= JudgmentTimeLimit
        ArrestScript.DebugMsg("Judgment timed out after " + elapsed + "s - defaulting to jail")

        String senderName = sender.GetDisplayName()
        String prisonerName = prisoner.GetDisplayName()
        String guardName = guard.GetDisplayName()

        String narration = "*" + senderName + " grows tired of deliberating. " + guardName + " takes hold of " + prisonerName + " and begins leading them away to jail.*"
        SkyrimNetApi.DirectNarration(narration, prisoner, sender)

        String eventMsg = senderName + " did not reach a decision. " + prisonerName + " will be taken to jail by default."
        SkyrimNetApi.RegisterPersistentEvent(eventMsg, prisoner, sender)

        Debug.Notification(senderName + " lost patience - " + prisonerName + " sent to jail")

        EndJudgment(false)
        Return
    EndIf

    ; Re-apply prisoner follow package each tick — Skyrim's AI can drop overrides
    If prisoner != None && guard != None && ArrestScript.SeverActions_FollowGuard_Prisoner
        ActorUtil.AddPackageOverride(prisoner, ArrestScript.SeverActions_FollowGuard_Prisoner, ArrestScript.PackagePriority, 1)
        prisoner.EvaluatePackage()
    EndIf

    ; Still waiting for sender's decision — re-arm OnUpdate via parent's loop.
    ; The parent's OnUpdate is the actual update tick; we don't register here
    ; because that would conflict with the parent's per-state cadence.
EndFunction

; =============================================================================
; ACTION ENTRY POINTS — wired via orderrelease.yaml / orderjailed.yaml
; =============================================================================

Bool Function OrderRelease_Execute(Actor akSender)
    {Sender orders the prisoner released. Called by SkyrimNet when the sender
     decides to show mercy or accepts the prisoner's plea.
     akSender: The NPC giving the release order (must be the dispatch sender,
               or the guard if sender is player).
     Returns true if the prisoner was released.}

    If !ArrestScript
        Return false
    EndIf

    Int phase = ArrestScript.GetDispatchPhase()
    If phase != 6
        ArrestScript.DebugMsg("ERROR: OrderRelease called but not in judgment phase (phase " + phase + ")")
        Return false
    EndIf

    If akSender == None
        ArrestScript.DebugMsg("ERROR: OrderRelease called with None sender")
        Return false
    EndIf

    Actor sender   = ArrestScript.GetDispatchSender()
    Actor prisoner = ArrestScript.GetDispatchTarget()
    Actor guard    = ArrestScript.GetDispatchGuard()

    ; If the player is the dispatch sender, accept the guard as the caller acting on the player's behalf
    Bool validCaller = (akSender == sender)
    If !validCaller && sender == Game.GetPlayer() && akSender == guard
        validCaller = true
        ArrestScript.DebugMsg("OrderRelease: Guard " + akSender.GetDisplayName() + " acting on player's behalf")
    EndIf

    If !validCaller
        ArrestScript.DebugMsg("ERROR: OrderRelease called by wrong sender (" + akSender.GetDisplayName() + " vs " + sender.GetDisplayName() + ")")
        Return false
    EndIf

    If prisoner == None || guard == None
        ArrestScript.DebugMsg("ERROR: OrderRelease - invalid state")
        EndJudgment(true)
        Return false
    EndIf

    String senderName = sender.GetDisplayName()
    String prisonerName = prisoner.GetDisplayName()
    String guardName = guard.GetDisplayName()

    ArrestScript.DebugMsg(senderName + " ordered release of " + prisonerName)

    ; Narration: sender orders the guard to release the prisoner
    String narration = "*" + senderName + " raises a hand, halting " + guardName + ". " + prisonerName + " is released from restraints.*"
    SkyrimNetApi.DirectNarration(narration, prisoner, sender)

    ; Persistent event
    String eventMsg = senderName + " ordered " + prisonerName + " released."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, prisoner, sender)

    Debug.Notification(prisonerName + " has been released")

    EndJudgment(true)
    Return true
EndFunction

Bool Function OrderJailed_Execute(Actor akSender)
    {Sender orders the prisoner taken to jail. Called by SkyrimNet when the
     sender decides the prisoner deserves imprisonment.
     akSender: The NPC giving the jail order (must be the dispatch sender,
               or the guard if sender is player).
     Returns true if the prisoner was sent to jail.}

    If !ArrestScript
        Return false
    EndIf

    Int phase = ArrestScript.GetDispatchPhase()
    If phase != 6
        ArrestScript.DebugMsg("ERROR: OrderJailed called but not in judgment phase (phase " + phase + ")")
        Return false
    EndIf

    If akSender == None
        ArrestScript.DebugMsg("ERROR: OrderJailed called with None sender")
        Return false
    EndIf

    Actor sender   = ArrestScript.GetDispatchSender()
    Actor prisoner = ArrestScript.GetDispatchTarget()
    Actor guard    = ArrestScript.GetDispatchGuard()

    ; If the player is the dispatch sender, accept the guard as the caller acting on the player's behalf
    Bool validCaller = (akSender == sender)
    If !validCaller && sender == Game.GetPlayer() && akSender == guard
        validCaller = true
        ArrestScript.DebugMsg("OrderJailed: Guard " + akSender.GetDisplayName() + " acting on player's behalf")
    EndIf

    If !validCaller
        ArrestScript.DebugMsg("ERROR: OrderJailed called by wrong sender (" + akSender.GetDisplayName() + " vs " + sender.GetDisplayName() + ")")
        Return false
    EndIf

    If prisoner == None || guard == None
        ArrestScript.DebugMsg("ERROR: OrderJailed - invalid state")
        EndJudgment(false)
        Return false
    EndIf

    String senderName = sender.GetDisplayName()
    String prisonerName = prisoner.GetDisplayName()
    String guardName = guard.GetDisplayName()

    ArrestScript.DebugMsg(senderName + " ordered " + prisonerName + " taken to jail")

    ; Narration: sender orders the guard to take the prisoner away
    String narration = "*" + senderName + " shakes their head. " + guardName + " tightens their grip on " + prisonerName + " and begins leading them away.*"
    SkyrimNetApi.DirectNarration(narration, prisoner, sender)

    ; Persistent event
    String eventMsg = senderName + " ordered " + prisonerName + " taken to jail."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, prisoner, sender)

    Debug.Notification(prisonerName + " will be taken to jail")

    EndJudgment(false)
    Return true
EndFunction

; =============================================================================
; TERMINAL CLEANUP — release path or jail-escort hand-off
; =============================================================================

Function EndJudgment(Bool released)
    {End the judgment hold and either release the prisoner or escort them to jail.
     released: true = free the prisoner, false = escort to jail.
     Cleans up dispatch state either way.}

    If !ArrestScript
        Return
    EndIf

    Actor prisoner = ArrestScript.GetDispatchTarget()
    Actor guard    = ArrestScript.GetDispatchGuard()
    Actor sender   = ArrestScript.GetDispatchSender()

    ; Clear the "judgment" busy flag set in StartJudgment so the busy target
    ; is eligible for normal SkyrimNet behaviour again. ResolveBusyTarget
    ; returns the sender for NPC-initiated dispatches and the guard for
    ; player-initiated dispatches — both must be cleared symmetrically.
    ;
    ; Belt-and-suspenders: ClearDispatchState below also calls ResetState
    ; (which clears via ResolveBusyTarget) before nulling sender/guard, so
    ; the same flag gets cleared twice. ClearActorBusy is idempotent.
    Actor busyTarget = ResolveBusyTarget()
    If busyTarget != None
        SeverActionsNative.Native_SkyrimNet_ClearActorBusy(busyTarget)
    EndIf

    If released
        ; --- RELEASE: Undo all restraint and clean up ---
        ArrestScript.DebugMsg("Judgment ended: releasing " + prisoner.GetDisplayName())

        ; Strip every arrest package, clear linked refs, restore dialogue.
        If guard != None
            ArrestScript.RemoveAllArrestPackages(guard)
            ArrestScript.ClearAllDispatchLinkedRefs(guard)
            guard.AllowPCDialogue(true)
            guard.EvaluatePackage()
        EndIf

        ; Release the prisoner (removes factions, cuffs, linked ref, restores AVs)
        If prisoner != None
            ArrestScript.ReleasePrisoner(prisoner)
        EndIf

        ; Clear every reference alias the arrest / dispatch FSM uses.
        ArrestScript.ClearAllArrestAliases()

        ArrestScript.ClearDispatchState()
    Else
        ; --- JAIL: Hand off to standard escort pipeline ---
        ArrestScript.DebugMsg("Judgment ended: sending " + prisoner.GetDisplayName() + " to jail")

        ; Strip every arrest package and clear the follow LinkedRef. StartEscortPhase
        ; below will re-apply the escort package the guard actually needs next.
        If guard != None
            ArrestScript.RemoveAllArrestPackages(guard)
            SeverActionsNative.LinkedRef_Clear(guard, ArrestScript.SeverActions_FollowTargetKW)
        EndIf

        ; Determine jail destination
        ObjectReference jailMarker = ArrestScript.GetJailMarkerForGuard(guard)
        String jailName = ArrestScript.GetJailNameForGuard(guard)

        If jailMarker != None && guard != None && prisoner != None
            ; Set up standard arrest state for escort via the cross-script accessor
            ArrestScript.SetCurrentArrestSlots(guard, prisoner, jailMarker, jailName)

            ArrestScript.ClearDispatchState()

            ; Clear every reference alias before escort re-fills them.
            ArrestScript.ClearAllArrestAliases()

            ; Apply/re-apply restraints for jail escort
            If prisoner != None
                ; Equip cuffs (add if not already in inventory)
                If ArrestScript.SeverActions_PrisonerCuffs
                    If !prisoner.GetItemCount(ArrestScript.SeverActions_PrisonerCuffs)
                        prisoner.AddItem(ArrestScript.SeverActions_PrisonerCuffs, 1, true)
                    EndIf
                    prisoner.EquipItem(ArrestScript.SeverActions_PrisonerCuffs, true, true)
                EndIf

                ; Play bound idle
                If ArrestScript.OffsetBoundStandingStart
                    prisoner.PlayIdle(ArrestScript.OffsetBoundStandingStart)
                EndIf

                ; Break animation lock so follow package works
                Debug.SendAnimationEvent(prisoner, "IdleForceDefaultState")
                Utility.Wait(0.1)

                ; Ensure prisoner is following the guard for escort
                SeverActionsNative.LinkedRef_Set(prisoner, guard, ArrestScript.SeverActions_FollowTargetKW)
                Utility.Wait(0.2)
                If ArrestScript.SeverActions_FollowGuard_Prisoner
                    ActorUtil.AddPackageOverride(prisoner, ArrestScript.SeverActions_FollowGuard_Prisoner, ArrestScript.PackagePriority, 1)
                    prisoner.EvaluatePackage()
                EndIf
            EndIf

            ; Start standard escort phase
            ArrestScript.StartEscortPhase()
        Else
            ; Fallback: release if we can't find jail
            ArrestScript.DebugMsg("ERROR: Could not determine jail for guard, releasing prisoner")
            If prisoner != None
                ArrestScript.ReleasePrisoner(prisoner)
            EndIf
            If guard != None
                guard.AllowPCDialogue(true)
                If ArrestScript.SeverActions_GuardApproachTarget
                    ActorUtil.RemovePackageOverride(guard, ArrestScript.SeverActions_GuardApproachTarget)
                EndIf
                guard.EvaluatePackage()
            EndIf

            ; Clear every reference alias the arrest / dispatch FSM uses.
            ArrestScript.ClearAllArrestAliases()

            ArrestScript.ClearDispatchState()
        EndIf
    EndIf
EndFunction
