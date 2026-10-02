Scriptname SeverActions_ArrestJudgment Extends Quest
{Phase-6 judgment hold: after a guard brings a prisoner back to the NPC who
 ordered the arrest, that sender orders release (OrderRelease_Execute) or jail
 (OrderJailed_Execute); no decision within JudgmentTimeLimit means jail.
 All dispatch state, packages, aliases and cleanup helpers live on
 SeverActions_Arrest (ArrestScript), which drives StartJudgment, ResetState
 and CheckJudgmentProgress. Attached to quest 0x000D62.}

SeverActions_Arrest Property ArrestScript Auto
{The main arrest script; every function here goes through it. Resolved in
 Maintenance() when the CK leaves it unfilled.}

Float JudgmentStartTime           ; real time the hold began
Float JudgmentTimeLimit = 90.0    ; seconds before defaulting to jail

; --- Lifecycle ---

Function Maintenance()
    {Resolves ArrestScript if the CK left it unfilled. Called from
     SeverActions_Arrest.Maintenance.}
    If !ArrestScript
        Quest q = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
        If q
            ArrestScript = q as SeverActions_Arrest
        EndIf
    EndIf
EndFunction

Function StartJudgment()
    {Starts the judgment timer (from CheckDispatchPhase5_Return on entering
     phase 6, and from RecoverActiveDispatch on load) and marks the order
     actions' LLM speaker busy with "judgment" (see ResolveBusyTarget).}
    JudgmentStartTime = Utility.GetCurrentRealTime()

    Actor target = ResolveBusyTarget()
    If target != None
        SeverActionsNative.Native_SkyrimNet_SetActorBusy(target, "judgment")
    EndIf
EndFunction

Function ResetState()
    {Clears the timer and the "judgment" busy flag (this is what clears it on
     CancelDispatch, which bypasses EndJudgment). Called from
     ClearDispatchState, which must call it BEFORE nulling DispatchSender /
     DispatchGuard or ResolveBusyTarget finds nobody and the flag leaks.}
    JudgmentStartTime = 0.0

    Actor target = ResolveBusyTarget()
    If target != None
        SeverActionsNative.Native_SkyrimNet_ClearActorBusy(target)
    EndIf
EndFunction

Actor Function ResolveBusyTarget()
    {Returns the actor the order actions' eligibility runs against: the
     dispatch guard when the player sent the dispatch (the player does not
     drive SkyrimNet's action selection, so the guard speaks for them), else
     the sender. None without ArrestScript.}
    If !ArrestScript
        Return None
    EndIf
    Actor sender = ArrestScript.GetDispatchSender()
    If sender == Game.GetPlayer()
        Return ArrestScript.GetDispatchGuard()
    EndIf
    Return sender
EndFunction

; --- Per-tick router (SeverActions_Arrest.CheckDispatchProgress, phase 6) ---

Function CheckJudgmentProgress()
    {Ends the hold when a participant is gone or the time limit has passed.}
    If !ArrestScript
        Return
    EndIf

    Actor guard    = ArrestScript.GetDispatchGuard()
    Actor prisoner = ArrestScript.GetDispatchTarget()
    Actor sender   = ArrestScript.GetDispatchSender()

    If guard == None || guard.IsDead()
        ArrestScript.DebugMsg("Judgment: Guard died or invalid, releasing prisoner")
        EndJudgment(true)
        Return
    EndIf

    If prisoner == None || prisoner.IsDead()
        ; The release path tears everything down; the jail path would cuff and escort a corpse.
        ArrestScript.DebugMsg("Judgment: Prisoner died or invalid, ending judgment (released)")
        EndJudgment(true)
        Return
    EndIf

    If sender == None || sender.IsDead()
        ArrestScript.DebugMsg("Judgment: Sender died or invalid, defaulting to jail")
        EndJudgment(false)
        Return
    EndIf

    Float elapsed = Utility.GetCurrentRealTime() - JudgmentStartTime
    If elapsed >= JudgmentTimeLimit
        ArrestScript.DebugMsg("Judgment timed out after " + elapsed + "s - defaulting to jail")

        String senderName = sender.GetDisplayName()
        String prisonerName = prisoner.GetDisplayName()
        String guardName = guard.GetDisplayName()

        String narration = "*" + senderName + " grows tired of deliberating. " + guardName + " takes hold of " + prisonerName + " and begins leading them away to jail.*"
        SkyrimNetApi.DirectNarration(narration, prisoner, sender)

        String eventMsg = senderName + " never gave a ruling, so " + guardName + " is taking " + prisonerName + " to jail."
        SkyrimNetApi.RegisterPersistentEvent(eventMsg, prisoner, sender)

        Debug.Notification(senderName + " lost patience - " + prisonerName + " sent to jail")

        EndJudgment(false)
        Return
    EndIf

    ; Re-applied every tick: the engine can drop package overrides.
    If prisoner != None && guard != None && ArrestScript.SeverActions_FollowGuard_Prisoner
        ActorUtil.AddPackageOverride(prisoner, ArrestScript.SeverActions_FollowGuard_Prisoner, ArrestScript.PackagePriority, 1)
        prisoner.EvaluatePackage()
    EndIf

    ; No tick armed here: the parent's OnChronoTick_Arrest drives this cadence.
EndFunction

; --- SkyrimNet actions (orderrelease.yaml / orderjailed.yaml) ---

Bool Function OrderRelease_Execute(Actor akSender)
    {The sender frees the prisoner. akSender must be the dispatch sender, or
     the guard when the player sent the dispatch. Returns true when released.}

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

    ; On a player-sent dispatch the guard speaks for the player.
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

    String narration = "*" + senderName + " raises a hand, halting " + guardName + ". " + prisonerName + " is released from restraints.*"
    SkyrimNetApi.DirectNarration(narration, prisoner, sender)

    String eventMsg = senderName + " ordered " + prisonerName + " released."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, prisoner, sender)

    Debug.Notification(prisonerName + " has been released")

    EndJudgment(true)
    Return true
EndFunction

Bool Function OrderJailed_Execute(Actor akSender)
    {The sender sends the prisoner to jail. akSender as for
     OrderRelease_Execute. Returns true when the order was accepted.}

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

    ; On a player-sent dispatch the guard speaks for the player.
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

    String narration = "*" + senderName + " shakes their head. " + guardName + " tightens their grip on " + prisonerName + " and begins leading them away.*"
    SkyrimNetApi.DirectNarration(narration, prisoner, sender)

    String eventMsg = senderName + " ordered " + prisonerName + " taken to jail."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, prisoner, sender)

    Debug.Notification(prisonerName + " will be taken to jail")

    EndJudgment(false)
    Return true
EndFunction

; --- Terminal cleanup ---

Function EndJudgment(Bool released)
    {Ends the hold: released = true frees the prisoner, false hands them to
     the jail escort (jails them at once while a same-cell arrest holds the
     escort slots; releases them when neither can start). Clears the dispatch
     state, persisted and script-side, either way.}

    If !ArrestScript
        Return
    EndIf

    Actor prisoner = ArrestScript.GetDispatchTarget()
    Actor guard    = ArrestScript.GetDispatchGuard()
    Actor sender   = ArrestScript.GetDispatchSender()
    String prisonerName = ""
    If prisoner
        prisonerName = prisoner.GetDisplayName()
    EndIf

    ; Clear the busy flag StartJudgment set. ClearDispatchState's ResetState
    ; clears it again; ClearActorBusy is idempotent.
    Actor busyTarget = ResolveBusyTarget()
    If busyTarget != None
        SeverActionsNative.Native_SkyrimNet_ClearActorBusy(busyTarget)
    EndIf

    If released
        ArrestScript.DebugMsg("Judgment ended: releasing " + prisonerName)

        If guard != None
            ArrestScript.RemoveAllArrestPackages(guard)
            ArrestScript.ClearAllDispatchLinkedRefs(guard)
            guard.AllowPCDialogue(true)
            guard.EvaluatePackage()
        EndIf

        If prisoner != None
            ArrestScript.ReleasePrisoner(prisoner)
        EndIf

        ArrestScript.ClearDispatchExitAliases()

        ; ClearDispatchState resets only the script variables; the cosaved
        ; dispatch context (ARDC: per-guard entry + active-guard singleton) is
        ; cleared only by ClearPersistedDispatchState. Skipping it leaves
        ; active=<guard> in every later cosave, and each load rebuilds phase 6
        ; and re-runs a phantom judgment.
        ; Must run BEFORE ClearDispatchState, which nulls the DispatchGuard it needs.
        ArrestScript.ClearPersistedDispatchState()
        ArrestScript.ClearDispatchState()
    Else
        ; Jail: hand off to the standard escort.
        ArrestScript.DebugMsg("Judgment ended: sending " + prisonerName + " to jail")

        ; StartEscortPhase re-applies the escort package the guard needs.
        If guard != None
            ArrestScript.RemoveAllArrestPackages(guard)
            SeverActionsNative.LinkedRef_Clear(guard, ArrestScript.SeverActions_FollowTargetKW)
        EndIf

        ObjectReference jailMarker = ArrestScript.GetJailMarkerForGuard(guard)
        String jailName = ArrestScript.GetJailNameForGuard(guard)

        If jailMarker != None && guard != None && prisoner != None && ArrestScript.IsSameCellArrestActive()
            ; The escort would take a running same-cell arrest's slots: jail straight away instead.
            ArrestScript.JailDispatchPrisonerNow(guard, prisoner, jailMarker, jailName)
        ElseIf jailMarker != None && guard != None && prisoner != None
            ; Persisted context first (see the release branch).
            ArrestScript.ClearPersistedDispatchState()
            ArrestScript.ClearDispatchState()

            ; The escort re-fills the aliases.
            ArrestScript.ClearAllArrestAliases()

            If prisoner != None
                If ArrestScript.SeverActions_PrisonerCuffs
                    If !prisoner.GetItemCount(ArrestScript.SeverActions_PrisonerCuffs)
                        prisoner.AddItem(ArrestScript.SeverActions_PrisonerCuffs, 1, true)
                    EndIf
                    prisoner.EquipItem(ArrestScript.SeverActions_PrisonerCuffs, true, true)
                EndIf

                If ArrestScript.OffsetBoundStandingStart
                    prisoner.PlayIdle(ArrestScript.OffsetBoundStandingStart)
                EndIf

                ; Break the animation lock so the follow package can run.
                Debug.SendAnimationEvent(prisoner, "IdleForceDefaultState")
                Utility.Wait(0.1)

                SeverActionsNative.LinkedRef_Set(prisoner, guard, ArrestScript.SeverActions_FollowTargetKW)
                Utility.Wait(0.2)
                If ArrestScript.SeverActions_FollowGuard_Prisoner
                    ActorUtil.AddPackageOverride(prisoner, ArrestScript.SeverActions_FollowGuard_Prisoner, ArrestScript.PackagePriority, 1)
                    prisoner.EvaluatePackage()
                EndIf
            EndIf

            ; The slots are claimed only now: the waits above let a same-cell arrest start, and
            ; its slots are then not ours to take.
            If ArrestScript.IsSameCellArrestActive()
                ArrestScript.JailPrisonerAt(guard, prisoner, jailMarker, jailName, false)
            Else
                ArrestScript.SetCurrentArrestSlots(guard, prisoner, jailMarker, jailName)
                ArrestScript.StartEscortPhase()
            EndIf
        Else
            ; No jail marker, or the guard or prisoner is gone: release instead.
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

            ArrestScript.ClearDispatchExitAliases()

            ; Persisted context first (see the release branch).
            ArrestScript.ClearPersistedDispatchState()
            ArrestScript.ClearDispatchState()
        EndIf
    EndIf
EndFunction
