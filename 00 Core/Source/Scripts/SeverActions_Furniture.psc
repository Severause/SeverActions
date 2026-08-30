Scriptname SeverActions_Furniture extends Quest
{Furniture interaction actions for SkyrimNet - sit, sleep, use workstations via sandbox package}

; =============================================================================
; PROPERTIES
; =============================================================================

Package Property SeverActions_UseFurniturePackage Auto
{Sandbox package with small radius - created in CK}

Keyword Property SeverActions_FurnitureTargetKeyword Auto
{Keyword for linked ref to furniture target}

int Property FurniturePackagePriority = 80 AutoReadOnly
{High priority so it overrides other behaviors}

float Property AutoStandDistance = 500.0 Auto
{Distance at which actors auto-stand when player moves away}

; =============================================================================
; INIT & MAINTENANCE
; =============================================================================

Event OnInit()
    Debug.Trace("[SeverActions_Furniture] Initialized")
    RegisterEvents()
EndEvent

; Called on game load to ensure event registration persists across saves
Function Maintenance()
    Debug.Trace("[SeverActions_Furniture] Maintenance - re-registering events")
    RegisterEvents()
EndFunction

Function RegisterEvents()
    ; Register for native cleanup event from FurnitureManager
    RegisterForModEvent("SeverActionsNative_FurnitureCleanup", "OnNativeFurnitureCleanup")
    Debug.Trace("[SeverActions_Furniture] Registered for SeverActionsNative_FurnitureCleanup event")
EndFunction

; =============================================================================
; NATIVE CLEANUP EVENT HANDLER
; Called by native DLL when player changes cells or moves too far away
; =============================================================================

Event OnNativeFurnitureCleanup(string eventName, string strArg, float numArg, Form sender)
    ; numArg is always 0 now (float truncates high FormIDs) — sender is authoritative.
    Actor akActor = sender as Actor

    if !akActor
        Debug.Trace("[SeverActions_Furniture] Cleanup event received but actor not found: " + numArg)
        return
    endif

    Debug.Trace("[SeverActions_Furniture] Native cleanup for: " + akActor.GetDisplayName())

    ; Remove the sandbox package
    if SeverActions_UseFurniturePackage
        ActorUtil.RemovePackageOverride(akActor, SeverActions_UseFurniturePackage)
    endif

    ; Clear linked ref
    if SeverActions_FurnitureTargetKeyword
        SeverActionsNative.LinkedRef_Clear(akActor, SeverActions_FurnitureTargetKeyword)
    endif

    ; Unregister from SkyrimNet
    SkyrimNetApi.UnregisterPackage(akActor, "SeverActions_UseFurniture")

    ; Force them out of the furniture (beds don't release on package removal alone).
    Debug.SendAnimationEvent(akActor, "IdleForceDefaultState")

    ; Evaluate to let them stand up and return to normal AI
    akActor.EvaluatePackage()

    ; Short-lived, keyed per actor - see the note on RegisterFurnitureSceneEvent.
    RegisterFurnitureSceneEvent(akActor, "furniture_stopped", akActor.GetDisplayName() + " got up (auto)", GotUpTTLMs)
EndEvent

; =============================================================================
; FURNITURE LOOKUP
; =============================================================================

ObjectReference Function GetFurnitureByFormIDForActor(String formIdStr, Actor akActor)
    {Resolve a furniture FormID to an ObjectReference via native C++ lookup.
     Handles unsigned 32-bit FormIDs (avoids Papyrus int overflow for load order > 127),
     both decimal and hex formats, and BaseID-to-RefID fallback.}
    if formIdStr == "" || !akActor
        return None
    endif
    return SeverActionsNative.FindFurnitureByFormID(formIdStr, akActor)
EndFunction

; =============================================================================
; ACTION: UseFurniture - Use furniture by formID
; =============================================================================

Bool Function UseFurniture_IsEligible(Actor akActor, String furnitureFormId) Global
    if !akActor || akActor.IsDead() || akActor.IsInCombat()
        return false
    endif

    ; Already using furniture
    if akActor.GetSitState() != 0
        return false
    endif

    ; Mid-journey: never park a traveler in furniture. The furniture override
    ; beats the travel alias package, so the traveler ping-pongs between the
    ; StuckDetector's forward leapfrog and the furniture pull (the Rin
    ; cooking-pot loop, 2026-08-09). Travel start also stands them up; this
    ; gate stops the RE-park while the journey runs.
    if SeverActionsNativeExt2.Travel_IsTravelingByActor(akActor)
        return false
    endif

    return furnitureFormId != ""
EndFunction

Function UseFurniture_Execute(Actor akActor, String furnitureFormId)
    if !akActor || furnitureFormId == ""
        return
    endif

    ObjectReference furnRef = GetFurnitureByFormIDForActor(furnitureFormId, akActor)
    if !furnRef
        SkyrimNetApi.RegisterEvent("furniture_not_found", akActor.GetDisplayName() + " couldn't find that furniture (ID: " + furnitureFormId + ")", akActor, None)
        return
    endif
    UseFurnitureRef_Execute(akActor, furnRef)
EndFunction

Function UseFurnitureRef_Execute(Actor akActor, ObjectReference furnRef)
    {Apply the use-furniture sandbox to a furniture reference we already resolved
     (e.g. the crosshair target from the hotkey) - skips the FormID lookup.}
    if !akActor || !furnRef
        return
    endif

    if furnRef.IsFurnitureInUse()
        SkyrimNetApi.RegisterEvent("furniture_in_use", akActor.GetDisplayName() + " - furniture is already in use", akActor, None)
        return
    endif

    ; Execute-side belt for the eligibility gate above: eligibility re-checks
    ; lag the action fire, and this path is also reachable via the hotkey.
    if SeverActionsNativeExt2.Travel_IsTravelingByActor(akActor)
        Debug.Trace("[SeverActions_Furniture] " + akActor.GetDisplayName() + " is mid-journey - refusing furniture use")
        return
    endif

    String furnName = furnRef.GetBaseObject().GetName()
    Debug.Trace("[SeverActions_Furniture] " + akActor.GetDisplayName() + " using: " + furnName)

    ; Set linked ref to the furniture
    if SeverActions_FurnitureTargetKeyword
        SeverActionsNative.LinkedRef_Set(akActor, furnRef, SeverActions_FurnitureTargetKeyword)
    endif

    ; Apply sandbox package - they'll walk to and use the furniture
    if SeverActions_UseFurniturePackage
        ActorUtil.AddPackageOverride(akActor, SeverActions_UseFurniturePackage, FurniturePackagePriority, 1)
        akActor.EvaluatePackage()

        ; Register with native FurnitureManager for auto-cleanup
        SeverActionsNative.RegisterFurnitureUser(akActor, SeverActions_UseFurniturePackage, furnRef, SeverActions_FurnitureTargetKeyword, AutoStandDistance)
    endif

    ; Register with SkyrimNet
    SkyrimNetApi.RegisterPackage(akActor, "SeverActions_UseFurniture", FurniturePackagePriority, 0, false)

    RegisterFurnitureSceneEvent(akActor, "furniture_used", akActor.GetDisplayName() + " is using " + furnName, InUseTTLMs)
EndFunction

; =============================================================================
; ACTION: StopUsingFurniture - Stand up and stop using furniture
; =============================================================================

Bool Function StopUsingFurniture_IsEligible(Actor akActor) Global
    if !akActor || akActor.IsDead()
        return false
    endif
    
    ; Must be using furniture or have the package
    return akActor.GetSitState() >= 2 || SkyrimNetApi.HasPackage(akActor, "SeverActions_UseFurniture")
EndFunction

Function StopUsingFurniture_Execute(Actor akActor)
    if !akActor
        return
    endif

    Debug.Trace("[SeverActions_Furniture] " + akActor.GetDisplayName() + " stopping furniture use")

    ; Unregister from native FurnitureManager first
    SeverActionsNative.UnregisterFurnitureUser(akActor)

    ; Remove the sandbox package
    if SeverActions_UseFurniturePackage
        ActorUtil.RemovePackageOverride(akActor, SeverActions_UseFurniturePackage)
    endif

    ; Clear linked ref
    if SeverActions_FurnitureTargetKeyword
        SeverActionsNative.LinkedRef_Clear(akActor, SeverActions_FurnitureTargetKeyword)
    endif

    ; Unregister from SkyrimNet
    SkyrimNetApi.UnregisterPackage(akActor, "SeverActions_UseFurniture")

    ; Force them out of the furniture FIRST. Removing the package + EvaluatePackage
    ; alone does NOT eject a SLEEPING actor from a bed (sleep state is sticky — the
    ; engine keeps them down until a wake condition), so the stop hotkey silently
    ; did nothing on beds. IdleForceDefaultState breaks the furniture/idle lock for
    ; both chairs and beds (same call the arrest flow uses to clear PlayIdle locks).
    Debug.SendAnimationEvent(akActor, "IdleForceDefaultState")

    ; Evaluate to let them stand up and return to normal AI
    akActor.EvaluatePackage()

    RegisterFurnitureSceneEvent(akActor, "furniture_stopped", akActor.GetDisplayName() + " got up", GotUpTTLMs)
EndFunction

; =============================================================================
; GLOBAL API FOR ACTIONS
; =============================================================================

SeverActions_Furniture Function GetInstance() Global
    return Game.GetFormFromFile(0x000801, "SeverActions.esp") as SeverActions_Furniture
EndFunction

; --- UseFurniture ---
Bool Function UseFurniture_Global_IsEligible(Actor akActor, String furnitureFormId) Global
    return UseFurniture_IsEligible(akActor, furnitureFormId)
EndFunction

Function UseFurniture_Global_Execute(Actor akActor, String furnitureFormId) Global
    SeverActions_Furniture instance = GetInstance()
    if instance
        instance.UseFurniture_Execute(akActor, furnitureFormId)
    endif
EndFunction

; --- StopUsingFurniture ---
Bool Function StopUsingFurniture_Global_IsEligible(Actor akActor) Global
    return StopUsingFurniture_IsEligible(akActor)
EndFunction

Function StopUsingFurniture_Global_Execute(Actor akActor) Global
    SeverActions_Furniture instance = GetInstance()
    if instance
        instance.StopUsingFurniture_Execute(akActor)
    endif
EndFunction

; ============================================================================
; SCENE EVENTS
; ============================================================================

Int Property InUseTTLMs = 300000 Auto
{How long -X is using Y- stays in scene context (ms). Long enough to matter
 during a conversation, short enough that a stale line from an actor who left
 the cell without a stop event ages out on its own.}

Int Property GotUpTTLMs = 60000 Auto
{How long -X got up- lingers (ms). Barely interesting after the moment.}

Function RegisterFurnitureSceneEvent(Actor akActor, String asType, String asText, Int aiTTLMs)
    {Furniture activity is SCENE state, not history - so it goes through
     RegisterShortLivedEvent rather than RegisterEvent.

     Two problems with the persistent version, both reported by users running
     large followings: every sit and stand appended a permanent line, and the
     auto-sandbox fires them for the whole retinue at once (five companions
     going to bed = ten lines in a breath, which is what the chat log looked
     like). Nothing here is history worth keeping - nobody needs to know an
     NPC sat down forty minutes ago.

     The eventId is the REPLACE key: SkyrimNet keeps only the newest event per
     id, so keying on the actor means each NPC occupies exactly ONE line that
     updates in place - used replaces stopped replaces used - instead of a
     growing log. Ten followers cost ten lines at worst, and those expire.}

    If akActor == None
        Return
    EndIf
    SkyrimNetApi.RegisterShortLivedEvent("furniture_" + akActor.GetFormID(),         asType, asText, "", aiTTLMs, akActor, None)
EndFunction
