Scriptname SeverActions_WalkLib Hidden
{The walk support library (M-L): WalkToReference over a travel package (0x02B051, Travel to the
 walker's own LinkedRef under keyword 0x02B050, radius 150), with the native ArrivalMonitor polling
 for arrival. The items and economy modules call it statically; SeverActions_Loot keeps a forwarder
 under the old name. The 150-unit arrival distance is Loot's INTERACTION_DISTANCE runtime value (DR18).}

Bool Function WalkToReference(Actor akActor, ObjectReference akTarget, float maxWaitTime = 15.0) Global
    {Walk akActor to akTarget, waiting up to maxWaitTime seconds; true when within 150 units at
     the end. A traveler on the road never detours: true only when akTarget is already in reach.
     The package and keyword are resolved by FormID.}
    ; Each walker's target is their own LinkedRef, so two walkers never retarget each other as they
    ; would through one shared quest alias. 0x02B051 is the retired travel walk (TravelCore still
    ; strips it when a journey starts), nothing else links 0x02B050, and its radius is the arrival distance.
    Package walkPkg = Game.GetFormFromFile(0x02B051, "SeverActions.esp") as Package
    Keyword walkKW = Game.GetFormFromFile(0x02B050, "SeverActions.esp") as Keyword
    if !akActor || !akTarget
        return false
    endif
    ; Someone walking beside a traveler can still be handed something; nothing pulls them off the road.
    if SeverActionsNativeExt2.Travel_GetPhaseByActor(akActor) == 1
        return _FlatDistance(akActor, akTarget) <= 150.0
    endif

    Bool usingPackage = walkPkg && walkKW
    if usingPackage
        SeverActionsNative.LinkedRef_Set(akActor, akTarget, walkKW)
        ActorUtil.AddPackageOverride(akActor, walkPkg, 100)
        akActor.EvaluatePackage()
    else
        akActor.PathToReference(akTarget, 1.0)
    endif

    ; The native ArrivalMonitor does the distance math for all walkers in one ~1 s tick, and
    ; Arrival_IsTracked is a map lookup. It holds one entry per actor, so an actor another
    ; system already tracks (arrest approach/escort) is not taken over: poll the distance instead.
    Bool useArrivalMonitor = !SeverActionsNativeExt.Arrival_IsTracked(akActor)
    if useArrivalMonitor
        SeverActionsNativeExt.Arrival_Register(akActor, akTarget, 150.0, "sever_loot_walk")
        float elapsed = 0.0
        while SeverActionsNativeExt.Arrival_IsTracked(akActor) && elapsed < maxWaitTime
            Utility.Wait(0.25)
            elapsed += 0.25
        endwhile
        ; Timed out: drop the entry.
        if SeverActionsNativeExt.Arrival_IsTracked(akActor)
            SeverActionsNativeExt.Arrival_Cancel(akActor)
        endif
    else
        float elapsed = 0.0
        while _FlatDistance(akActor, akTarget) > 150.0 && elapsed < maxWaitTime
            Utility.Wait(0.25)
            elapsed += 0.25
        endwhile
    endif

    if usingPackage
        ActorUtil.RemovePackageOverride(akActor, walkPkg)
        SeverActionsNative.LinkedRef_Clear(akActor, walkKW)
        akActor.EvaluatePackage()
    endif

    ; The position decides: the monitor drops its entry both on arrival and when it
    ; auto-cancels for a dead actor. Flat, as the monitor measures: the package parks the walker at
    ; its 150 radius, so a target up a step or on a table would fail a 3D test.
    return _FlatDistance(akActor, akTarget) <= 150.0
EndFunction

Float Function _FlatDistance(ObjectReference a, ObjectReference b) Global
    Float dx = a.GetPositionX() - b.GetPositionX()
    Float dy = a.GetPositionY() - b.GetPositionY()
    return Math.sqrt(dx * dx + dy * dy)
EndFunction
