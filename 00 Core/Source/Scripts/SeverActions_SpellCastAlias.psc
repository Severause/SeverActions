Scriptname SeverActions_SpellCastAlias extends ReferenceAlias
{Per-slot cast controller: filled with the caster, holds the slot's TargetAlias and
SlotPackage, and polls the cast (start, release, stuck charge, heal-to-full repeat,
magicka debit). An alias owns its form handle, so its update timer is its own.}

; ESP-filled properties

ReferenceAlias Property TargetAlias Auto
{This slot's target alias, filled with the spell's target.}

Package Property SlotPackage Auto
{This slot's UseMagic package; the dispatcher rebinds it from the live ESP every cast.}

; Per-cast state

Spell spellToCast
Int spellCost
Bool useMagicka
Bool dualCasting
Bool healToFull
Bool targetIsMarker         ; an aim marker we placed: Disable+Delete on cleanup
Int castPhase               ; 0=waiting for anim start, 1=cast in flight, 2=done
Int pollsWaitingForStart    ; watchdog: abort if cast never starts
Int pollsInFlight           ; watchdog: force-release if charging too long
Bool forceFired             ; unused: no force-fire fallback is wired

Float Property PollInterval = 0.5 AutoReadOnly
Int Property MaxPollsWaitingForStart = 10 AutoReadOnly   ; 5 s for the package to start the cast
Int Property PollsBeforeForceFire = 2 AutoReadOnly       ; unused (see forceFired)
Int Property MaxPollsInFlight = 30 AutoReadOnly          ; 15 s for charge and release

; Entry point: arms the polling watchdog for a cast SeverActions_SpellCast._DispatchOneCast
; has set up (package bound, spell injected, both aliases filled, EvaluatePackage forced).
; Returns false, after cleanup, when the caster, spell or target is missing.
Bool Function StartCastTracking(Spell akSpell, ObjectReference akTarget, Bool bDualCasting, Bool bUseMagicka, Bool bHealToFull, Bool bMarkerIsTarget)
    Actor caster = GetActorRef()
    SeverActionsNative.Native_OutfitSlot_Log("[SpellCastAlias] StartCastTracking caster=" + caster + " spell=" + akSpell + " target=" + akTarget)
    If !caster || !akSpell || !akTarget
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCastAlias] precondition failed")
        CleanupCast()
        return false
    EndIf

    spellToCast = akSpell
    dualCasting = bDualCasting
    useMagicka = bUseMagicka
    healToFull = bHealToFull
    targetIsMarker = bMarkerIsTarget
    spellCost = 0
    If useMagicka
        spellCost = SeverActionsNativeExt.Native_GetEffectiveMagickaCost(caster, akSpell, dualCasting)
    EndIf

    ; Hold SkyrimNet off the actor's AI for the cast: an active SkyrimNet follow package
    ; outranks the injected cast package and the cast never starts. Cleared in CleanupCast.
    SeverActionsNative.Native_SkyrimNet_SetActorBusy(caster, "SeverActions spell cast")

    ; Log the cast setup; OnUpdate logs it again every poll, for a timeline.
    SeverActionsNativeExt.Native_DiagnoseCastSetup(caster, spellToCast)

    castPhase = 0
    pollsWaitingForStart = 0
    pollsInFlight = 0
    forceFired = false
    RegisterForSingleUpdate(PollInterval)
    return true
EndFunction

; Polling state machine

Event OnUpdate()
    Actor caster = GetActorRef()
    If !caster
        CleanupCast()
        return
    EndIf

    Bool stillCasting = SeverActionsNativeExt.Native_IsCasterStillCasting(caster)

    SeverActionsNativeExt.Native_DiagnoseCastSetup(caster, spellToCast)

    If castPhase == 0
        ; Waiting for the cast animation to start
        If stillCasting
            castPhase = 1
            pollsInFlight = 0
            RegisterForSingleUpdate(PollInterval)
        Else
            pollsWaitingForStart += 1
            If pollsWaitingForStart >= MaxPollsWaitingForStart
                Debug.Trace("[SeverActions_SpellCast] Package never fired - abort")
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
                Debug.Trace("[SeverActions_SpellCast] Stuck charge detected - force release")
                SeverActionsNativeExt.Native_ForceReleaseCast(caster)
                CleanupCast()
            Else
                RegisterForSingleUpdate(PollInterval)
            EndIf
        EndIf
    EndIf
EndEvent

; Cast completion

Function OnCastComplete(Actor caster)
    If useMagicka && spellCost > 0
        caster.DamageActorValue("Magicka", spellCost)
    EndIf

    ; Heal-to-full: recast while the target is hurt and the caster can pay.
    Bool continueHealing = false
    Actor targetActor = None
    ObjectReference savedTargetRef = None
    If TargetAlias
        savedTargetRef = TargetAlias.GetRef()
        targetActor = TargetAlias.GetActorRef()
    EndIf

    If healToFull && targetActor && SeverActionsNativeExt.Native_IsHealingSpell(spellToCast)
        Float currentHP = targetActor.GetActorValue("Health")
        ; GetActorValueMax (SKSE) counts Fortify Health; the base value would stop the
        ; loop early on exactly the buffed targets.
        Float maxHP = targetActor.GetActorValueMax("Health")
        ; Within 1 HP of full counts as full.
        If currentHP < maxHP - 1.0
            Float magickaLeft = caster.GetActorValue("Magicka")
            If !useMagicka || spellCost <= magickaLeft
                continueHealing = true
            EndIf
        EndIf
    EndIf

    ; CleanupCast clears the per-cast state: copy what the recast needs first.
    Spell savedSpell = spellToCast
    Bool savedDualCast = dualCasting
    Bool savedUseMagicka = useMagicka
    Bool savedHealToFull = healToFull
    Actor savedCaster = caster

    CleanupCast()

    If continueHealing && savedCaster && savedSpell && savedTargetRef
        ; Let the engine release the previous cast's animation state first.
        Utility.Wait(0.4)
        SeverActions_SpellCast.GetInstance().RecastSameSlot(savedCaster, savedSpell, savedTargetRef, savedDualCast, savedUseMagicka, savedHealToFull)
    EndIf
EndFunction

; Cleanup

Function CleanupCast()
    Actor caster = GetActorRef()

    ; Pairs with SetActorBusy in StartCastTracking; a no-op when it was never set.
    If caster
        SeverActionsNative.Native_SkyrimNet_ClearActorBusy(caster)
    EndIf

    If caster && SeverActionsNativeExt.Native_IsCasterStillCasting(caster)
        SeverActionsNativeExt.Native_ForceReleaseCast(caster)
    EndIf

    ; Remove the runtime clone Native_CloneSpellForCast added to the actor (else every
    ; cast leaves another copy in their spell list), but ONLY when the dispatcher cast
    ; from a clone: on its fallback spellToCast is the NPC's real spell. The dispatcher
    ; sets SeverSpellCast_WasCloned per cast; unset it here.
    If caster && spellToCast
        If StorageUtil.GetIntValue(caster, "SeverSpellCast_WasCloned", 0) == 1
            caster.RemoveSpell(spellToCast)
        EndIf
        StorageUtil.UnsetIntValue(caster, "SeverSpellCast_WasCloned")
    EndIf

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

    ; So a CleanupCast before the next StartCastTracking seeds these (its precondition
    ; path) cannot act on the previous cast's spell or marker.
    spellToCast = None
    targetIsMarker = false

    UnregisterForUpdate()

    If caster
        ; Clearing the alias drops its package; the re-eval returns them to their own AI.
        Clear()
        caster.EvaluatePackage()
    Else
        Clear()
    EndIf
EndFunction

Event OnPackageEnd(Package akOldPackage)
    ; The package ended on its own: complete now instead of at the next poll.
    If akOldPackage == SlotPackage && castPhase == 1
        Actor caster = GetActorRef()
        If caster
            castPhase = 2
            OnCastComplete(caster)
        EndIf
    EndIf
EndEvent
