Scriptname SeverActions_FurnitureLib Hidden
{The furniture support library (plan M-L): the use-furniture package as Global
 functions every furniture user calls STATICALLY, so no caller holds a
 SeverActions_Furniture variable (DR1). Unattached; the package and LinkedRef keyword
 are resolved by FormID. SeverActions_Furniture keeps the action entry points (MEMBER
 functions: SkyrimNet calls them by name) and forwards here. Each module that registers furniture users handles
 the shared SeverActionsNative_FurnitureCleanup event (OnNativeFurnitureCleanup, M-E)
 with CleanupFor: SeverActions_Furniture for every user, FollowerManager for its bed
 sleepers and, without the travel module, for every user. Whether a ref has a place
 for an actor is the native's per-seat answer (SeverActionsNativeExt2.Furniture_SeatFor),
 never IsFurnitureInUse. The auto-stand distance is the furnitureAutoStandDistance settings row
 (owned here, DR19), the native FurnitureManager's default for every user.}

; Literals: package priority 80, scene-event TTLs 300000 ms (using) and 60000 ms (got
; up) - the runtime values of the quest-script properties they replaced (DR18) - and
; 60000 ms for a refusal.

Package Function UsePackage() Global
    {SeverAction_UseFurniture (EditorID without the s): an Activate package on the target
     LinkedRef, MustComplete - it walks the actor to the furniture and enters a free marker.
     Not a sandbox, and not in SkyrimNet's package registry: test use with IsUsing.}
    Return Game.GetFormFromFile(0x062B5A, "SeverActions.esp") as Package
EndFunction

Keyword Function TargetKeyword() Global
    {SeverActions_FurnitureTargetKeyword - the LinkedRef keyword to the furniture target.}
    Return Game.GetFormFromFile(0x062B5B, "SeverActions.esp") as Keyword
EndFunction

ObjectReference Function GetFurnitureByFormIDForActor(String formIdStr, Actor akActor) Global
    {Resolves a furniture FormID string (unsigned decimal or 0x hex, so no Papyrus Int
     overflow) natively; a base form resolves to its nearest reference within 500 units
     in akActor's cell.}
    if formIdStr == "" || !akActor
        return None
    endif
    return SeverActionsNative.FindFurnitureByFormID(formIdStr, akActor)
EndFunction

Bool Function CanUse(Actor akActor, String furnitureFormId) Global
    {UseFurniture eligibility (the quest script's UseFurniture_IsEligible).}
    if !akActor || akActor.IsDead() || akActor.IsInCombat()
        return false
    endif

    ; Already using furniture
    if akActor.GetSitState() != 0
        return false
    endif

    ; Never park a traveler: the furniture override beats the travel alias package, so
    ; they ping-pong between the StuckDetector's leapfrog and the furniture. Travel start
    ; stands them up; this stops the re-park mid-journey.
    if SeverActionsNativeExt2.Travel_IsTravelingByActor(akActor)
        return false
    endif

    return furnitureFormId != ""
EndFunction

Function UseRef(Actor akActor, ObjectReference furnRef) Global
    {Send akActor to use a furniture reference we already resolved (e.g. the crosshair
     target from the hotkey) - skips the FormID lookup. Refuses, with a short-lived line,
     a ref with no free place for them; the free half of a bench is a place.}
    if !akActor || !furnRef
        return
    endif

    ; Per seat: IsFurnitureInUse means ANY marker, so one sitter would refuse a whole
    ; bench. The refusal is scene state like the rest (see RegisterSceneEvent).
    if !SeverActionsNativeExt2.Furniture_SeatFor(akActor, furnRef, 0.0)
        String takenName = "that spot"
        if furnRef.GetBaseObject().GetName() != ""
            takenName = "the " + furnRef.GetBaseObject().GetName()
        endif
        RegisterSceneEvent(akActor, "furniture_in_use", akActor.GetDisplayName() + " found " + takenName + " already taken", 60000)
        return
    endif

    ; CanUse's traveler gate again: eligibility lags the action, and the hotkey skips it.
    if SeverActionsNativeExt2.Travel_IsTravelingByActor(akActor)
        Debug.Trace("[SeverActions_FurnitureLib] " + akActor.GetDisplayName() + " is mid-journey - refusing furniture use")
        return
    endif

    String furnName = furnRef.GetBaseObject().GetName()
    Debug.Trace("[SeverActions_FurnitureLib] " + akActor.GetDisplayName() + " using: " + furnName)

    Package usePkg = UsePackage()
    Keyword targetKW = TargetKeyword()

    if targetKW
        SeverActionsNative.LinkedRef_Set(akActor, furnRef, targetKW)
    endif

    ; The Activate package walks them to the furniture (linked ref) and uses it.
    if usePkg
        ActorUtil.AddPackageOverride(akActor, usePkg, 80, 1)
        akActor.EvaluatePackage()

        ; Native auto-cleanup. 0 = the manager's default distance, i.e. the
        ; furnitureAutoStandDistance row; the manager ignores a per-user value.
        SeverActionsNative.RegisterFurnitureUser(akActor, usePkg, furnRef, targetKW, 0.0)
    endif

    RegisterSceneEvent(akActor, "furniture_used", akActor.GetDisplayName() + " is using " + furnName, 300000)
EndFunction

Function UseNearest(Actor akActor, ObjectReference furnRef) Global
    {SitOrLayDown's body: furnRef when it has a place for akActor, else the nearest free
     furniture of the same kind within 400 units of it, else a short-lived refusal line.}
    if !akActor || !furnRef
        return
    endif

    ; 400 units keeps the NPC beside the spot they named; the prompt's list can be ~55 s
    ; stale (SkyrimNet's decorator cache), so a taken piece is routine here.
    ObjectReference seat = SeverActionsNativeExt2.Furniture_SeatFor(akActor, furnRef, 400.0)
    if !seat
        RegisterSceneEvent(akActor, "furniture_in_use", akActor.GetDisplayName() + " found no free place nearby", 60000)
        return
    endif
    if seat != furnRef
        Debug.Trace("[SeverActions_FurnitureLib] " + akActor.GetDisplayName() + ": " + furnRef + " is taken, redirected to " + seat)
    endif
    UseRef(akActor, seat)
EndFunction

Bool Function IsUsing(Actor akActor) Global
    {True while akActor uses furniture through this library, seated or on the way:
     registered with the native FurnitureManager, or linked to a furniture ref under
     TargetKeyword (a belt for a link the session-start restore,
     FurnitureManager::RestoreUsersFromLinkedRefs, could not re-register, e.g. an actor
     that did not resolve then; keep the filter in step with it: keyword 062B5B, a
     Furniture base, no kidnap entry).}
    if !akActor
        return false
    endif
    if SeverActionsNative.IsFurnitureUserRegistered(akActor)
        return true
    endif
    Keyword targetKW = TargetKeyword()
    ; GetLinkedRef(None) would read the unkeyworded link.
    if !targetKW
        return false
    endif
    ObjectReference target = akActor.GetLinkedRef(targetKW)
    if !target || !(target.GetBaseObject() as Furniture)
        return false
    endif
    ; A kidnap hold links a victim under the same keyword to a BoundCaptiveMarker, which
    ; is furniture; its teardown is the kidnap system's.
    return SeverActionsNativeExt.Native_Kidnap_GetPhase(akActor) == 0
EndFunction

Bool Function CanStop(Actor akActor) Global
    {StopUsingFurniture eligibility (the quest script's StopUsingFurniture_IsEligible).}
    if !akActor || akActor.IsDead()
        return false
    endif

    return akActor.GetSitState() >= 2 || IsUsing(akActor)
EndFunction

Function Stop(Actor akActor) Global
    {Stand up and stop using furniture (the quest script's StopUsingFurniture_Execute).}
    if !akActor
        return
    endif

    Debug.Trace("[SeverActions_FurnitureLib] " + akActor.GetDisplayName() + " stopping furniture use")

    ; Unregister from native FurnitureManager first
    SeverActionsNative.UnregisterFurnitureUser(akActor)

    Package usePkg = UsePackage()
    Keyword targetKW = TargetKeyword()

    if usePkg
        ActorUtil.RemovePackageOverride(akActor, usePkg)
    endif

    if targetKW
        SeverActionsNative.LinkedRef_Clear(akActor, targetKW)
    endif

    ; Removing the package does not get a SLEEPING actor out of a bed (sleep state is
    ; sticky until a wake condition); IdleForceDefaultState breaks the furniture lock
    ; for chairs and beds alike.
    Debug.SendAnimationEvent(akActor, "IdleForceDefaultState")

    akActor.EvaluatePackage()

    RegisterSceneEvent(akActor, "furniture_stopped", akActor.GetDisplayName() + " got up", 60000)
EndFunction

Function CleanupFor(Actor akActor) Global
    {The native FurnitureManager's cleanup (the player changed cells or moved too far
     away, or CompanionSeating released a companion it seated): drop the package override
     and LinkedRef, stand them up. Every registering module's OnNativeFurnitureCleanup
     handler calls this, so two may land for one actor: every step is a no-op the
     second time.}
    if !akActor
        return
    endif

    Debug.Trace("[SeverActions_FurnitureLib] Native cleanup for: " + akActor.GetDisplayName())

    Package usePkg = UsePackage()
    Keyword targetKW = TargetKeyword()

    if usePkg
        ActorUtil.RemovePackageOverride(akActor, usePkg)
    endif

    if targetKW
        SeverActionsNative.LinkedRef_Clear(akActor, targetKW)
    endif

    ; Beds do not release on package removal alone (see Stop).
    Debug.SendAnimationEvent(akActor, "IdleForceDefaultState")

    akActor.EvaluatePackage()

    RegisterSceneEvent(akActor, "furniture_stopped", akActor.GetDisplayName() + " got up", 60000)
EndFunction

Function RegisterSceneEvent(Actor akActor, String asType, String asText, Int aiTTLMs) Global
    {Furniture activity is scene state, not history, so it is a short-lived event
     rather than a permanent line per sit and stand (a retinue going to bed at once
     would flood the log). The eventId is the replace key: SkyrimNet keeps only the
     newest event per id, so each NPC holds ONE line that updates in place and expires.}

    If akActor == None
        Return
    EndIf
    SkyrimNetApi.RegisterShortLivedEvent("furniture_" + akActor.GetFormID(),         asType, asText, "", aiTTLMs, akActor, None)
EndFunction
