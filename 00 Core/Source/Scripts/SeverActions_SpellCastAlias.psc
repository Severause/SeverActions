Scriptname SeverActions_SpellCastAlias extends ReferenceAlias
{Per-slot cast controller. Filled with the caster, holds the pair's TargetAlias
and SlotPackage, and runs a polling state machine that detects cast start,
cast end, stuck-charge animations, heal-to-full repetition, and magicka debit.}

; =============================================================================
; ESP-FILLED PROPERTIES
; =============================================================================

ReferenceAlias Property TargetAlias Auto
{The paired target alias for this slot — filled with the spell's target.}

Package Property SlotPackage Auto
{The usemagic package attached to this alias. Handed to Native_InjectSpellIntoPackage.}

; =============================================================================
; RUNTIME STATE (per-cast)
; =============================================================================

Spell spellToCast
Int spellCost
Bool useMagicka
Bool dualCasting
Bool healToFull
Bool targetIsMarker         ; aim marker we placed — must be Disable+Delete'd on cleanup
Int castPhase               ; 0=waiting for anim start, 1=cast in flight, 2=done
Int pollsWaitingForStart    ; watchdog: abort if cast never starts
Int pollsInFlight           ; watchdog: force-release if charging too long
Bool forceFired             ; whether we've already used the ForceFireSpell fallback

Float Property PollInterval = 0.5 AutoReadOnly
Int Property MaxPollsWaitingForStart = 10 AutoReadOnly   ; 5s cap on package fire
Int Property PollsBeforeForceFire = 2 AutoReadOnly       ; if state=0 after 2 polls (~1s), force the cast
Int Property MaxPollsInFlight = 30 AutoReadOnly          ; 15s cap on charge+release

; =============================================================================
; ENTRY POINT (dispatcher calls this after ForceRefTo)
; =============================================================================

; Initialize per-cast tracking state and arm the polling watchdog. The
; dispatcher (_DispatchOneCast) has already done the heavy lifting:
;   - resolved live SlotPackage
;   - injected the spell into the package
;   - filled the target alias
;   - filled the caster alias (which triggered engine package eval)
;
; By the time we get here the engine should already be evaluating the
; cast package with the correct spell and target in place. We do NOT call
; EvaluatePackage here — bosn's reference plugin doesn't either; the alias
; fill in the dispatcher is what triggers re-eval.
Bool Function StartCastTracking(Spell akSpell, ObjectReference akTarget, Bool bDualCasting, Bool bUseMagicka, Bool bHealToFull, Bool bMarkerIsTarget)
    Actor caster = GetActorRef()
    SeverActionsNative.Native_OutfitSlot_Log("[SpellCastAlias] StartCastTracking caster=" + caster + " spell=" + akSpell + " target=" + akTarget)
    If !caster || !akSpell || !akTarget
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCastAlias] precondition failed")
        CleanupCast()
        return false
    EndIf

    ; Save runtime state for OnCastComplete / heal-to-full
    spellToCast = akSpell
    dualCasting = bDualCasting
    useMagicka = bUseMagicka
    healToFull = bHealToFull
    targetIsMarker = bMarkerIsTarget
    spellCost = 0
    If useMagicka
        spellCost = SeverActionsNative.Native_GetEffectiveMagickaCost(caster, akSpell, dualCasting)
    EndIf

    ; One-shot diagnostic dump — what the engine sees right after our
    ; alias fills. Polling will dump again each tick so we get a timeline.
    SeverActionsNative.Native_DiagnoseCastSetup(caster, spellToCast)

    ; Arm the polling state machine (handles cast-start detection, stuck-
    ; charge watchdog, completion).
    castPhase = 0
    pollsWaitingForStart = 0
    pollsInFlight = 0
    forceFired = false
    RegisterForSingleUpdate(PollInterval)
    return true
EndFunction

; =============================================================================
; POLLING STATE MACHINE
; =============================================================================

Event OnUpdate()
    Actor caster = GetActorRef()
    If !caster
        CleanupCast()
        return
    EndIf

    Bool stillCasting = SeverActionsNative.Native_IsCasterStillCasting(caster)

    ; Periodic diagnostic dump while polling — shows whether the engine is
    ; actually progressing the cast or just spinning. Each tick gives us a
    ; new snapshot of caster states / equipped slots / current package.
    SeverActionsNative.Native_DiagnoseCastSetup(caster, spellToCast)

    If castPhase == 0
        ; Waiting for the cast animation to start
        If stillCasting
            castPhase = 1
            pollsInFlight = 0
            RegisterForSingleUpdate(PollInterval)
        Else
            pollsWaitingForStart += 1
            If pollsWaitingForStart >= MaxPollsWaitingForStart
                Debug.Trace("[SeverActions_SpellCast] Package never fired — abort")
                CleanupCast()
            Else
                RegisterForSingleUpdate(PollInterval)
            EndIf
        EndIf
    ElseIf castPhase == 1
        ; Cast in flight — wait for release
        If !stillCasting
            castPhase = 2
            OnCastComplete(caster)
        Else
            pollsInFlight += 1
            If pollsInFlight >= MaxPollsInFlight
                Debug.Trace("[SeverActions_SpellCast] Stuck charge detected — force release")
                SeverActionsNative.Native_ForceReleaseCast(caster)
                CleanupCast()
            Else
                RegisterForSingleUpdate(PollInterval)
            EndIf
        EndIf
    EndIf
EndEvent

; =============================================================================
; CAST COMPLETION
; =============================================================================

Function OnCastComplete(Actor caster)
    If useMagicka && spellCost > 0
        caster.DamageActorValue("Magicka", spellCost)
    EndIf

    ; Decide whether to loop another cast (heal-to-full) or cleanup.
    Bool continueHealing = false
    Actor targetActor = None
    ObjectReference savedTargetRef = None
    If TargetAlias
        savedTargetRef = TargetAlias.GetRef()
        targetActor = TargetAlias.GetActorRef()
    EndIf

    If healToFull && targetActor && SeverActionsNative.Native_IsHealingSpell(spellToCast)
        Float currentHP = targetActor.GetActorValue("Health")
        ; Use GetActorValueMax (SKSE) so Fortify Health and other +Max-HP buffs
        ; are respected. GetBaseActorValue would return only the unbuffed base
        ; (e.g. 100 for an actor at 120/150) and the loop would stop early —
        ; under-healing exactly the buffed targets that need repeat heals.
        Float maxHP = targetActor.GetActorValueMax("Health")
        ; Heal-to-full threshold: close enough to full that one more cast would be wasted.
        If currentHP < maxHP - 1.0
            Float magickaLeft = caster.GetActorValue("Magicka")
            If !useMagicka || spellCost <= magickaLeft
                continueHealing = true
            EndIf
        EndIf
    EndIf

    ; Snapshot the state we need for the re-dispatch, then cleanup the slot.
    Spell savedSpell = spellToCast
    Bool savedDualCast = dualCasting
    Bool savedUseMagicka = useMagicka
    Bool savedHealToFull = healToFull
    Actor savedCaster = caster

    CleanupCast()

    If continueHealing && savedCaster && savedSpell && savedTargetRef
        ; Brief gap so the engine fully releases the previous cast's animation
        ; state before the next package evaluation starts.
        Utility.Wait(0.4)
        SeverActions_SpellCast.GetInstance().RecastSameSlot(savedCaster, savedSpell, savedTargetRef, savedDualCast, savedUseMagicka, savedHealToFull)
    EndIf
EndFunction

; =============================================================================
; CLEANUP
; =============================================================================

Function CleanupCast()
    Actor caster = GetActorRef()

    If caster && SeverActionsNative.Native_IsCasterStillCasting(caster)
        SeverActionsNative.Native_ForceReleaseCast(caster)
    EndIf

    ; Disable + delete the aim marker if we placed one
    If targetIsMarker && TargetAlias
        ObjectReference markerRef = TargetAlias.GetRef()
        If markerRef
            markerRef.Disable()
            markerRef.Delete()
        EndIf
    EndIf

    If TargetAlias
        TargetAlias.Clear()
    EndIf

    UnregisterForUpdate()

    If caster
        ; Removing the caster from the alias pulls the package override off them.
        ; A package re-eval returns them to their normal AI (idle/sandbox/etc).
        Clear()
        caster.EvaluatePackage()
    Else
        Clear()
    EndIf
EndFunction

Event OnPackageEnd(Package akOldPackage)
    ; If the package reports end naturally, short-circuit the watchdog and
    ; run completion immediately instead of waiting for the anim graph to clear.
    If akOldPackage == SlotPackage && castPhase == 1
        Actor caster = GetActorRef()
        If caster
            castPhase = 2
            OnCastComplete(caster)
        EndIf
    EndIf
EndEvent
