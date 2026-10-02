Scriptname SeverActions_Travel extends Quest

{
    NPC travel entry points: the TravelToPlace action and its confirm popup, place
    resolution, the furniture / crafting disengage before a journey, the traveler map
    markers, and the travel module's verb and hotkey dispatch. The journey and its
    arrival wait are SeverActions_TravelCore's (the native orchestrator, TRVL v5); the
    courier, ambush and steward-visit code moved out and left safe-exit stubs here.
    TravelAlias00..04 (ALST 13..17) are the DLL's wait pins, claimed at arrival; the
    properties stay for the VMAD fill.
}

; =============================================================================
; PROPERTIES - Aliases
; =============================================================================

ReferenceAlias Property TravelAlias00 Auto
ReferenceAlias Property TravelAlias01 Auto
ReferenceAlias Property TravelAlias02 Auto
ReferenceAlias Property TravelAlias03 Auto
ReferenceAlias Property TravelAlias04 Auto

; =============================================================================
; PROPERTIES - Packages & Keywords
; =============================================================================

Keyword Property TravelTargetKeyword Auto
{The LinkedRef keyword the travel packages chase (SeverTravelKeyword, 0x76F5F).}

Package Property TravelPackage Auto
{Default/run travel package; RegisterSpeedPackages' run fallback.}

Package Property TravelPackageWalk Auto
Package Property TravelPackageJog Auto
Package Property TravelPackageRun Auto

Package Property SandboxPackage Auto
{Unused here: the default arrival sandbox is SeverActions_TravelCore's. Kept for the ESP fill.}

; =============================================================================
; SPEED CONSTANTS — mirror TravelOrchestrator's TravelSpeed enum
; =============================================================================

Int Property SPEED_WALK = 0 AutoReadOnly
Int Property SPEED_JOG = 1 AutoReadOnly
Int Property SPEED_RUN = 2 AutoReadOnly

; =============================================================================
; PROPERTIES - Settings
; =============================================================================

Float Property ArrivalDistance = 300.0 Auto
{Arrival distance in units. Unused here: SeverActions_TravelCore.ARRIVAL_DISTANCE is live.}

Float Property UpdateInterval = 3.0 Auto
{Unused here: the courier and ambush polls are SeverActions_Courier's and
 SeverActions_Ambush's own ticks, which copy this value. Kept for the ESP fill.}

Int Property TravelPackagePriority = 85 Auto
{Travel / arrival-sandbox override priority; the VMAD fill (85) is what runs and the
 default matches it. Below the 100 wait/home/safe-interior sandboxes and the 110
 work/guard overrides. Unused here; Courier, Ambush, Kidnap and Enterprises copy it.}

Bool Property EnableDebugMessages = false Auto

Bool Property TravelMapMarkersEnabled = True Auto
{Legacy host of the travelMapMarkersEnabled settings row (the handlers read the row):
 objective map markers for travelers underway. Disabling stops new markers; releases
 always clear.}

; =============================================================================
; CONSTANTS
; =============================================================================

Int Property TravelActionCooldownSeconds = 120 Auto
{Real seconds after one TravelToPlace before the LLM may pick it again (the
 anti-spam backstop for location-mention misfires). 0 disables.}

; Orchestrator option bits (kTravelOpt_* in TravelOrchestrator.h). None is read here:
; TravelCore, Courier, Kidnap and Enterprises carry their own copies.
; 4 = abort on a degraded actor.
Int Property TRAVEL_OPTIONS_DEFAULT = 4 AutoReadOnly
; 4|8: 8 skips the CanNavigateToPosition pre-flight, which false-rejects a destination
; in an unloaded cell; the orchestrator's leapfrog/teleport recovery carries the trip.
Int Property TRAVEL_OPTIONS_LONGRANGE = 12 AutoReadOnly
; 12|32: 32 = quiet, no Traveler_NN objective or map marker.
Int Property TRAVEL_OPTIONS_QUIETLONG = 44 AutoReadOnly

; Steward-visit and Final Audit constants: unused here, kept for old frames;
; SeverActions_Enterprises carries the live copies.

Int Property StewardVisitPriority = 110 AutoReadOnly
{Unused; SeverActions_Enterprises.STEWARD_VISIT_PRIORITY is live.}

Float Property AuditFollowHandoff = 1000.0 AutoReadOnly
{Unused; SeverActions_Enterprises.AUDIT_FOLLOW_HANDOFF is live (kept in step with
 VentureMonitor::kAuditFollowHandoff).}

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    DebugMsg("OnInit")
    RegisterEvents()
    RegisterSpeedPackages()
EndEvent

Function OnGameLoaded()
    {Load recovery, every load: the travelcore provider's stage 1 runs it through the travel
     provider's loadRecovery service, first of every module (R23), after
     SeverActions_TravelCore.Maintenance and the orchestrator's cosave have recovered the
     journeys and waits. A quest script gets no OnPlayerLoadGame.}
    DebugMsg("OnGameLoaded")

    RegisterEvents()
    RegisterSpeedPackages()
    ; The native load sweep can ask for a ForceClear before RegisterEvents re-armed
    ; the listener, so sweep the pool directly too.
    SweepStalePoolSeats()
    AbandonAmbushOnLoad()
EndFunction

; The UseFurniture hotkey's two-step pick: the NPC chosen on the first press waits
; for the furniture press within the window (real seconds).
Actor HotkeyPendingFurnitureUser = None
Float HotkeyPendingFurnitureTime = 0.0
Float Property HotkeyPendingFurnitureWindow = 30.0 AutoReadOnly

Function RegisterEvents()
    ; SeverActions_TravelComplete is answered by the scripts owning each callback tag
    ; (TravelCore, Courier, Kidnap, Enterprises), not here.
    ; The popup's player-confirmed destination starts the trip.
    RegisterForModEvent("SeverActions_TravelPromptResult", "OnTravelPromptResult")
    ; This module's verb and hotkey events (M-V, M-K; DR16).
    RegisterForModEvent("SeverActions_Verb_Travel", "OnVerb_Travel")
    RegisterForModEvent("SeverActions_Hotkey_Travel", "OnHotkey_Travel")   ; StandUp / UseFurniture
    ; Per Traveler_NN pool slot. Each name must stay unique on the quest form: a
    ; second script registering it would be silently dead.
    RegisterForModEvent("SeverActions_TravelSlotClaimed", "OnTravelSlotClaimed")
    RegisterForModEvent("SeverActions_TravelSlotReleased", "OnTravelSlotReleased")
    RegisterForModEvent("SeverActions_TravelMarkersToggle", "OnTravelMarkersToggle")
    RegisterForModEvent("SeverActions_TravelAliasForceClear", "OnTravelAliasForceClear")
EndFunction

; =============================================================================
; TRAVELER POOL (Traveler_NN) — pre-flight teardown, map markers, seat sweep
; =============================================================================

Function DisengageOverridesForTravel(Actor akNPC, String asTag)
    {Free the traveler from anything that fights the travel package before the journey:
     a traveler held by furniture never yields to it (the stuck recovery leapfrogs them
     and the furniture pull walks them back, forever). Stands them up from any furniture
     (vanilla seating too) and cancels in-flight crafting; add the next override class
     that fights travel here - both entry points call this.}
    If SeverActions_FurnitureLib.CanStop(akNPC)
        DebugMsg(asTag + ": standing " + akNPC.GetDisplayName() + " up from furniture before travel")
        SeverActions_FurnitureLib.Stop(akNPC)
    EndIf
    If SeverActionsNativeExt2.Craft_CancelByActor(akNPC) > 0
        DebugMsg(asTag + ": cancelled in-flight crafting for " + akNPC.GetDisplayName() + " before travel")
    EndIf
EndFunction

Quest Function GetTravelPoolQuest()
    {The 24-alias traveler pool quest SeverActions_TravelQuest, by FormID (VR strips
     runtime EditorIDs).}
    Return Game.GetFormFromFile(0x0016AC00, "SeverActions.esp") as Quest
EndFunction

Function SweepStalePoolSeats()
    {Load-recovery belt: free any Traveler_NN seat with no live journey behind it. The
     engine-thunk empty does not clear and the ForceClear event can race this script's
     registration on load; a direct Clear() here has no ordering dependency.}
    Quest pool = GetTravelPoolQuest()
    If pool == None
        Return
    EndIf
    Int slot = 0
    While slot < 24
        ReferenceAlias ra = pool.GetAlias(slot) as ReferenceAlias
        If ra != None
            Actor held = ra.GetActorReference()
            If held != None && !SeverActionsNativeExt2.Travel_IsTravelingByActor(held)
                ra.Clear()
                held.EvaluatePackage()
                Debug.Trace("[SeverActions_Travel] Load sweep freed stale pool slot " + slot + " (" + held.GetDisplayName() + ")")
            EndIf
        EndIf
        slot += 1
    EndWhile
EndFunction

Event OnTravelSlotClaimed(String eventName, String strArg, Float numArg, Form sender)
    {A traveler took pool slot numArg (0-23): display its objective, index slot + 1
     (QOBJ 1..24). abForce re-shows the HUD line after an earlier cycle on the slot.}
    If !SeverActionsNativeExt2.Settings_GetBool("travelMapMarkersEnabled")
        Return
    EndIf
    Int slot = numArg as Int
    If slot < 0 || slot > 23
        Return
    EndIf
    Quest pool = GetTravelPoolQuest()
    If pool == None
        Return
    EndIf
    pool.SetObjectiveDisplayed(slot + 1, true, true)
EndEvent

Event OnTravelAliasForceClear(String eventName, String strArg, Float numArg, Form sender)
    {The native asks the VM to empty pool slot numArg: its engine-thunk null fill does
     not clear, ReferenceAlias.Clear() does. sender is the actor the native expects in
     the slot; anyone else there means a newer journey took it.}
    Int slot = numArg as Int
    If slot < 0 || slot > 23
        Return
    EndIf
    Quest pool = GetTravelPoolQuest()
    If pool == None
        Return
    EndIf
    ReferenceAlias ra = pool.GetAlias(slot) as ReferenceAlias
    If ra == None
        Return
    EndIf
    Actor held = ra.GetActorReference()
    If held == None
        Return ; already empty - the native retry will read that back
    EndIf
    If SeverActionsNativeExt2.Travel_SlotHasLiveOwner(slot)
        Return ; a newer journey owns the seat - maybe the same actor's after a re-route, which
               ; the actor check below cannot tell (the native drops its retry the same way)
    EndIf
    Actor expected = sender as Actor
    If expected != None && held != expected
        Return ; a newer journey's actor - not ours to clear
    EndIf
    ra.Clear()
    held.EvaluatePackage()
    Debug.Trace("[SeverActions_Travel] Force-cleared travel pool slot " + slot + " via Papyrus Clear (" + held.GetDisplayName() + ")")
EndEvent

Event OnTravelSlotReleased(String eventName, String strArg, Float numArg, Form sender)
    {Pool slot numArg's journey ended (or its alias refused to empty): take the marker
     down. Not gated on the setting, so turning it off mid-journey strands no marker.}
    Int slot = numArg as Int
    If slot < 0 || slot > 23
        Return
    EndIf
    Quest pool = GetTravelPoolQuest()
    If pool == None
        Return
    EndIf
    pool.SetObjectiveDisplayed(slot + 1, false)
EndEvent

Event OnTravelMarkersToggle(String eventName, String strArg, Float numArg, Form sender)
    {The traveler-marker setting changed: turning it off takes every displayed marker
     down now instead of waiting out the journeys.}
    ; The settings handler fed the Authority row before sending this; read the row (22c).
    If !SeverActionsNativeExt2.Settings_GetBool("travelMapMarkersEnabled")
        Quest pool = GetTravelPoolQuest()
        If pool != None
            Int i = 1
            While i <= 24
                pool.SetObjectiveDisplayed(i, false)
                i += 1
            EndWhile
        EndIf
    EndIf
    Debug.Trace("[SeverActions_Travel] traveler map markers " + SeverActionsNativeExt2.Settings_GetBool("travelMapMarkersEnabled"))
EndEvent

Function EnsureCourierEvents()
    {Safe-exit stub: the registrations are SeverActions_Courier's and SeverActions_Ambush's own.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): the registrations moved to SeverActions_Courier / SeverActions_Ambush
EndFunction

; Legacy ambush state a pre-P9 save may hold (SeverActions_Ambush keeps its own copies):
; nothing sets it; only AbandonAmbushOnLoad reads and clears it.
Actor[] AmbushThugs
Actor AmbushLead
Actor AmbushDeserter
Bool AmbushActive = False
Bool AmbushApproaching = False
ObjectReference AmbushAwayMarker   ; the stand-down walk-off waypoint
Float AmbushApproachStart = 0.0
String AmbushLetterSubj = ""
String AmbushLetterBody = ""

Actor Function GetNearestThug(Actor player)
    {Safe-exit stub: moved to SeverActions_Ambush.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Ambush
    Return None
EndFunction

Function CheckAmbushApproach()
    {Safe-exit stub: moved to SeverActions_Ambush.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Ambush
EndFunction

Function BeginAmbushStandoff()
    {Safe-exit stub: moved to SeverActions_Ambush.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Ambush
EndFunction

Faction Function GetBanditFaction()
    {Safe-exit stub: moved to SeverActions_Ambush.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Ambush
    Return None
EndFunction

Faction Function GetHiredBladeFaction()
    {Safe-exit stub: moved to SeverActions_Ambush.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Ambush
    Return None
EndFunction

Function StripThugPackages(Actor t)
    {Safe-exit stub: moved to SeverActions_Ambush.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Ambush
EndFunction

Function ThugStandDown_Execute(Actor akActor)
    {Safe-exit stub: moved to SeverActions_Ambush.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Ambush
EndFunction

Function ProcessDepartingThugs()
    {Safe-exit stub: moved to SeverActions_Ambush.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Ambush
EndFunction

Function ThugAttack_Execute(Actor akActor)
    {Safe-exit stub: moved to SeverActions_Ambush.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Ambush
EndFunction

Function ResolveAmbushCombat()
    {Safe-exit stub: moved to SeverActions_Ambush.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Ambush
EndFunction

Function MarkKidnapSteelSpent()
    {Safe-exit stub: moved to SeverActions_Ambush.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Ambush
EndFunction

Function ResetAmbushBookkeeping()
    {Safe-exit stub: moved to SeverActions_Ambush.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Ambush
EndFunction

Function ClearAmbushState()
    {Safe-exit stub: moved to SeverActions_Ambush.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Ambush
EndFunction

Function AbandonAmbushOnLoad()
    {Legacy teardown (R23) of a standoff a pre-P9 save left on this script's variables.
     The native thug set is emptied by the revert, so it can never resolve: strip the
     packages, undo the faction, despawn the thugs. No global thug clear (it could wipe
     a standoff SeverActions_Ambush opened this session); only its own lead's persuasion
     window ends. Runs at most once per save lineage.}
    If !AmbushActive && !AmbushApproaching
        Return
    EndIf
    SeverActionsNativeExt2.Native_Persuasion_EndFor(AmbushLead)
    Faction bladeFaction = Game.GetFormFromFile(0x165674, "SeverActions.esp") as Faction
    Package jog = SeverActionsNativeExt.Travel_GetSpeedPackage(SPEED_JOG)
    If AmbushThugs   ; never `!= None` on an array: it casts None at runtime
        Int i = 0
        While i < AmbushThugs.Length
            Actor t = AmbushThugs[i]
            If t != None
                If jog != None
                    ActorUtil.RemovePackageOverride(t, jog)
                EndIf
                SeverActionsNative.LinkedRef_Clear(t, TravelTargetKeyword)
                SeverActionsNative.OrphanCleanup_UnregisterTraveler(t)
                SkyrimNetApi.UnregisterPackage(t, "TalkToPlayer")
                SkyrimNetApi.UnregisterPackage(t, "FollowPlayer")
                If bladeFaction != None
                    t.RemoveFromFaction(bladeFaction)
                EndIf
                t.Disable()
                t.Delete()
            EndIf
            i += 1
        EndWhile
    EndIf
    ; A pre-P9 stand-down's walk-off waypoint: release it here, once.
    If AmbushAwayMarker
        AmbushAwayMarker.Disable()
        AmbushAwayMarker.Delete()
        AmbushAwayMarker = None
    EndIf
    AmbushActive = False
    AmbushApproaching = False
    AmbushLead = None
    AmbushDeserter = None
    AmbushLetterSubj = ""
    AmbushLetterBody = ""
    Debug.Trace("[SeverActions_Travel] abandoned a pre-P9 standoff that was live across a save/reload (legacy teardown)")
EndFunction

Function RegisterSpeedPackages()
    ; Hand the speed packages to the orchestrator (the DLL also seeds them by FormID at
    ; kDataLoaded, TravelOrchestrator::SeedSpeedPackagesAtDataLoaded; this is the belt).
    ; By FormID, the SeverTravelToAction* family: all three chase TravelTargetKeyword
    ; (0x76F5F), the only keyword the orchestrator links. The CK-filled
    ; TravelPackageWalk / TravelPackageRun are the legacy family (0x2B051/0x2B053,
    ; keyword 0x2B050): a traveler on one gets no target, stands still and is leapfrogged.
    Package walkPkg = Game.GetFormFromFile(0x07C068, "SeverActions.esp") as Package  ; SeverTravelToActionWalk
    Package jogPkg  = Game.GetFormFromFile(0x07C069, "SeverActions.esp") as Package  ; SeverTravelToActionJog
    Package runPkg  = Game.GetFormFromFile(0x076F60, "SeverActions.esp") as Package  ; SeverTravelToAction (run)
    If !walkPkg
        walkPkg = TravelPackageJog   ; the one property on the right keyword
    EndIf
    If !jogPkg
        jogPkg = TravelPackageJog
    EndIf
    If !runPkg
        runPkg = TravelPackage
    EndIf
    SeverActionsNativeExt.Travel_RegisterSpeedPackages(walkPkg, jogPkg, runPkg, runPkg)
EndFunction

Function EnsureReady()
    {Lazy-init guard for the entry points: re-register the ModEvents and the native
     speed packages in case load recovery did not run this session. Idempotent, cheap.}
    RegisterEvents()
    RegisterSpeedPackages()
EndFunction

; =============================================================================
; COURIER — SeverActions_Courier's; safe-exit stubs
; =============================================================================

Int Function DispatchCourier(Actor akSender, String asSubject, String asBody, String asReason)
    {Safe-exit stub: moved to SeverActions_Courier.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Courier
    Return 0
EndFunction

Bool Function ActiveCourierLive()
    {Safe-exit stub: moved to SeverActions_Courier.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Courier
    Return false
EndFunction

Bool Function QueueHasUrgent()
    {Safe-exit stub: moved to SeverActions_Courier.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Courier
    Return false
EndFunction

Bool Function TryDispatchQueuedCourier()
    {Safe-exit stub: moved to SeverActions_Courier.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Courier
    Return false
EndFunction

; =============================================================================
; STEWARD VISITS / FINAL AUDIT WALK — SeverActions_Enterprises'; safe-exit stubs
; =============================================================================

Function PostStewardVisit(Actor akSteward, Actor akTarget)
    {Safe-exit stub: moved to SeverActions_Enterprises.}
    ; M-I-STUB 3.9.14-beta25 (P9-03): moved to SeverActions_Enterprises
EndFunction

Function ClearTravelPackagesQuietly(Actor akNPC)
    {Drop every travel override and the travel LinkedRef, silently. No caller left (the
     steward visit and audit walk moved to SeverActions_Enterprises); kept for old frames.}
    SeverActions_TravelCore.StripTravelOverrides(akNPC)
    SeverActionsNative.LinkedRef_Clear(akNPC, TravelTargetKeyword)
EndFunction

Function EndStewardVisit(Actor akSteward)
    {Safe-exit stub: moved to SeverActions_Enterprises.}
    ; M-I-STUB 3.9.14-beta25 (P9-03): moved to SeverActions_Enterprises
EndFunction

Bool Function CourierBlockedWorldspace(Actor akPlayer)
    {Safe-exit stub: moved to SeverActions_Courier.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Courier
    Return false
EndFunction

Function QueueCourierLetter(Actor akSender, String asSubject, String asBody, String asReason)
    {Safe-exit stub: moved to SeverActions_Courier.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Courier
EndFunction

Bool Function ProcessCourierQueue()
    {Safe-exit stub: moved to SeverActions_Courier.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Courier
    Return false
EndFunction

Function DeliverCourierLetter(Actor akCourier)
    {Safe-exit stub: moved to SeverActions_Courier.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Courier
EndFunction

; =============================================================================
; PLACE RESOLUTION
; =============================================================================

ObjectReference Function ResolvePlace(Actor akNPC, String placeName)
    {Resolve a place name to a marker through the native LocationResolver (semantic
     terms, city aliases, exact/editor-ID, fuzzy, Levenshtein); None when unresolved.}
    If !SeverActionsNative.IsLocationResolverReady()
        DebugMsg("ResolvePlace: LocationResolver not initialized")
        Return None
    EndIf
    ObjectReference marker = SeverActionsNative.ResolveDestination(akNPC, placeName)
    If marker == None
        DebugMsg("Could not resolve '" + placeName + "'")
    EndIf
    Return marker
EndFunction

; =============================================================================
; MAIN API
; =============================================================================

Bool Function TravelToPlace(Actor akNPC, String placeName, Float waitHours = 0.0, Bool stopFollowing = true, Int speed = 0, Bool waitForPlayer = true)
    {Action entry (executionFunctionName). Opens a non-pausing popup so the player can
     confirm or redirect the destination (a confirm starts the trip via
     OnTravelPromptResult; cancel, timeout or Escape means no travel). With the popup off,
     followers-only for a non-follower, unavailable or busy, it travels straight to the
     LLM's pick.}
    If akNPC == None
        Return false
    EndIf
    ; An NSFW scene setup owns this NPC's movement. The YAML gate normally hides the
    ; action; this catches a stale emit. No-op without the NSFW add-on.
    If SeverActionsNativeExt.Native_SceneBound_IsBound(akNPC)
        DebugMsg("TravelToPlace: suppressed - " + akNPC.GetDisplayName() + " is mid-encounter setup")
        Return false
    EndIf
    ; Anti-spam backstop: the LLM fires this when a place is merely mentioned, so any
    ; travel (or popup) takes the action off the eligible list for a while.
    SkyrimNetApi.SetActionCooldown("TravelToPlace", TravelActionCooldownSeconds)
    ; Popup disabled: go now.
    If !SeverActionsNative.Magelight_IsTravelPopupEnabled()
        Return DoTravelToPlace(akNPC, placeName, waitHours, stopFollowing, speed, waitForPlayer)
    EndIf
    ; Followers-only popup: a stranger's errand is not the player's to redirect.
    If SeverActionsNative.Magelight_IsTravelPopupFollowersOnly() && !IsPopupWorthyTraveler(akNPC)
        Return DoTravelToPlace(akNPC, placeName, waitHours, stopFollowing, speed, waitForPlayer)
    EndIf
    ; Make sure the confirm handler is registered before the popup can fire it, in case
    ; load recovery did not run this session (idempotent).
    RegisterForModEvent("SeverActions_TravelPromptResult", "OnTravelPromptResult")
    If SeverActionsNativeExt.Magelight_IsTravelPromptAvailable() \
        && SeverActionsNativeExt.Magelight_OpenTravelPrompt(akNPC, placeName, 60000)
        ; The confirm handler starts the trip with these.
        StorageUtil.SetFloatValue(akNPC, "SeverTravel_PendingWait", waitHours)
        StorageUtil.SetIntValue(akNPC, "SeverTravel_PendingStopFollow", stopFollowing as Int)
        StorageUtil.SetIntValue(akNPC, "SeverTravel_PendingSpeed", speed)
        StorageUtil.SetIntValue(akNPC, "SeverTravel_PendingWaitForPlayer", waitForPlayer as Int)
        DebugMsg("TravelToPlace: opened travel popup for " + akNPC.GetDisplayName() + " (prefill '" + placeName + "')")
        Return true
    EndIf
    Return DoTravelToPlace(akNPC, placeName, waitHours, stopFollowing, speed, waitForPlayer)
EndFunction

Bool Function IsPopupWorthyTraveler(Actor akNPC)
    {Followers-only popup scope: teammates and SA-registered followers (track-only
     included) get the popup; anyone else travels without asking.}
    If akNPC.IsPlayerTeammate()
        Return true
    EndIf
    Return SeverActionsNativeExt.Native_GetIsFollower(akNPC)
EndFunction

Event OnTravelPromptResult(string eventName, string strArg, float numArg, Form sender)
    {The player confirmed a destination in the travel popup: strArg = the place,
     sender = the NPC. Cancel, timeout and Escape never fire this.}
    Actor npc = sender as Actor
    If !npc || strArg == ""
        Return
    EndIf
    Float waitHours = StorageUtil.GetFloatValue(npc, "SeverTravel_PendingWait", 0.0)
    Bool stopFollowing = StorageUtil.GetIntValue(npc, "SeverTravel_PendingStopFollow", 1) != 0
    Int speed = StorageUtil.GetIntValue(npc, "SeverTravel_PendingSpeed", 0)
    Bool waitForPlayer = StorageUtil.GetIntValue(npc, "SeverTravel_PendingWaitForPlayer", 1) != 0
    StorageUtil.UnsetFloatValue(npc, "SeverTravel_PendingWait")
    StorageUtil.UnsetIntValue(npc, "SeverTravel_PendingStopFollow")
    StorageUtil.UnsetIntValue(npc, "SeverTravel_PendingSpeed")
    StorageUtil.UnsetIntValue(npc, "SeverTravel_PendingWaitForPlayer")
    DoTravelToPlace(npc, strArg, waitHours, stopFollowing, speed, waitForPlayer)
EndEvent

Bool Function DoTravelToPlace(Actor akNPC, String placeName, Float waitHours = 0.0, Bool stopFollowing = true, Int speed = 0, Bool waitForPlayer = true)
    {Send an NPC to a named place; true if travel started. speed: 0=walk, 1=jog, 2=run.
     waitForPlayer: true = meeting the player there (greet on approach, patience
     timeout); false = a self-errand of waitHours, then back to their normal life.}

    If akNPC == None
        DebugMsg("TravelToPlace: None actor")
        Return false
    EndIf
    If akNPC.IsDead()
        DebugMsg("TravelToPlace: dead actor")
        Return false
    EndIf
    If placeName == ""
        DebugMsg("TravelToPlace: empty placeName")
        Return false
    EndIf

    EnsureReady()

    If speed < 0
        speed = 0
    ElseIf speed > 2
        speed = 2
    EndIf

    If !SeverActionsNative.IsLocationResolverReady()
        DebugMsg("TravelToPlace: LocationResolver not initialized")
        Return false
    EndIf

    ; Resolve before BeginJourney ends the current journey: a bad placeName must not cancel it.
    ObjectReference destMarker = ResolvePlace(akNPC, placeName)
    If destMarker == None
        ; Tell the NPC's LLM the place did not resolve, so they admit it instead of
        ; announcing a trip and standing still.
        SkyrimNetApi.RegisterShortLivedEvent("travelfail_" + akNPC.GetFormID(), \
            "travel_failed", \
            akNPC.GetDisplayName() + " meant to set out for '" + placeName + "' but realizes they do not actually know where that is, and would have to ask for the place's proper name first.", \
            "", 30000, akNPC, Game.GetPlayer())
        Return false
    EndIf

    ; "outside/beside <place>": the resolver stamped this actor with exterior intent.
    ; Consume it and keep the door as the destination, so they loiter at the entrance.
    Bool exteriorIntent = SeverActionsNativeExt.Native_TravelExteriorIntent(akNPC)

    ; A door (type 29): travel on to its interior marker.
    ObjectReference finalDest = destMarker
    If destMarker.GetBaseObject().GetType() == 29 && !exteriorIntent
        ObjectReference interiorMarker = SeverActionsNative.FindInteriorMarkerForDoor(destMarker, akNPC)
        If interiorMarker != None
            finalDest = interiorMarker
            DebugMsg("Door resolved to interior marker for '" + placeName + "'")
        EndIf
        ; Unlock it so pathfinding is not blocked.
        If destMarker.IsLocked()
            destMarker.Lock(false)
        EndIf
    ElseIf exteriorIntent
        DebugMsg("Exterior intent for '" + placeName + "' - stopping at the entrance")
    EndIf

    ; Check the speed package before BeginJourney ends the current journey, for the same reason.
    Package travelPkg = GetTravelPackageForSpeed(speed)
    If travelPkg == None
        DebugMsg("TravelToPlace: no package for speed " + speed)
        Return false
    EndIf

    ; BeginJourney ends any journey under way, drops a follower for the trip and starts
    ; the walk with its arrival wait armed.
    DisengageOverridesForTravel(akNPC, "TravelToPlace")
    If !SeverActions_TravelCore.BeginJourney(akNPC, finalDest, placeName, waitHours, stopFollowing, speed, waitForPlayer, None)
        Return false
    EndIf
    NotifyPlayer(akNPC.GetDisplayName() + " traveling to " + placeName)
    Return true
EndFunction

Bool Function TravelNPCToReference(Actor akNPC, ObjectReference akDestination, Float waitHours = 0.0, Bool stopFollowing = false, Int speed = 1, Package akSandboxOverride = None)
    {Send an NPC to an ObjectReference (door, marker, NPC, camp center), skipping name
     resolution: the module's ref-targeted entry for third-party callers (no in-tree
     caller). speed: 0=walk, 1=jog (default), 2=run. akSandboxOverride: a package
     applied on arrival instead of the default arrival sandbox (e.g. a camp's own).}

    If akNPC == None
        DebugMsg("TravelNPCToReference: None actor")
        Return false
    EndIf
    If akNPC.IsDead()
        DebugMsg("TravelNPCToReference: dead actor")
        Return false
    EndIf
    If akDestination == None
        DebugMsg("TravelNPCToReference: None destination")
        Return false
    EndIf

    EnsureReady()

    If speed < 0
        speed = 0
    ElseIf speed > 2
        speed = 2
    EndIf

    ; Door → interior marker, as in DoTravelToPlace.
    ObjectReference finalDest = akDestination
    If akDestination.GetBaseObject().GetType() == 29
        ObjectReference interiorMarker = SeverActionsNative.FindInteriorMarkerForDoor(akDestination)
        If interiorMarker != None
            finalDest = interiorMarker
        EndIf
        If akDestination.IsLocked()
            akDestination.Lock(false)
        EndIf
    EndIf

    Package travelPkg = GetTravelPackageForSpeed(speed)
    If travelPkg == None
        DebugMsg("TravelNPCToReference: no package for speed " + speed)
        Return false
    EndIf

    DisengageOverridesForTravel(akNPC, "TravelNPCToReference")
    ; Ref-targeted travel has no user-facing place name: use the base object's.
    String label = "dispatch_target"
    If finalDest != None
        Form base = finalDest.GetBaseObject()
        If base != None
            String baseName = base.GetName()
            If baseName != ""
                label = baseName
            EndIf
        EndIf
    EndIf
    Return SeverActions_TravelCore.BeginJourney(akNPC, finalDest, label, waitHours, stopFollowing, speed, true, akSandboxOverride)
EndFunction

; =============================================================================
; THE TICK — nothing arms it any more; kept for old frames
; =============================================================================

Function ChronoArm(Float afSeconds)
    {Arm this script's one-shot chronometer tick (see the Chronometer block in
     SeverActionsNativeExt2.psc). Nothing calls it any more.}
    RegisterForModEvent("SeverActions_Tick_Travel", "OnChronoTick_Travel")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_Travel", afSeconds)
EndFunction

Event OnChronoTick_Travel(String eventName, String strArg, Float numArg, Form sender)
    ; Nothing polls here. A tick an older pex armed is acknowledged and the loop ends
    ; (only a re-Request or a Cancel acknowledges a fired tick).
    SeverActionsNativeExt2.Chrono_Cancel("SeverActions_Tick_Travel")
EndEvent

Function ReassertThugStance()
    {Safe-exit stub: moved to SeverActions_Ambush.}
    ; M-I-STUB 3.9.14-beta25 (P9-01): moved to SeverActions_Ambush
EndFunction

; =============================================================================
; JOURNEYS — forwarders to SeverActions_TravelCore (in this module's closure, DR2;
; static calls only, N2)
; =============================================================================

Function CancelTravel(Actor akNPC, Bool restoreFollower = true)
    {Cancel one NPC's journey or wait; the teardown runs synchronously.}
    If akNPC == None
        Return
    EndIf
    SeverActions_TravelCore.CancelJourney(akNPC, restoreFollower)
EndFunction

Function CancelAllTravel(Bool restoreFollowers = true)
    SeverActions_TravelCore.CancelAllJourneys(restoreFollowers)
EndFunction

Function ForceResetAllSlots(Bool restoreFollowers = true)
    {The MCM's reset: cancel every player-ordered journey, on the road or waiting (the
     name is an old layout row id; there are no slots).}
    DebugMsg("=== CANCEL ALL JOURNEYS ===")
    NotifyPlayer("Cancelling all NPC journeys...")
    CancelAllTravel(restoreFollowers)
    NotifyPlayer("All NPC journeys have been cancelled.")
EndFunction

Int Function GetActiveTravelCount()
    {How many player-ordered journeys are live (on the road or waiting).}
    Return SeverActions_TravelCore.JourneyCount()
EndFunction

String Function GetJourneyLine(Int aiIndex)
    {The MCM's journey rows: "<name>: Traveling to <place>" / "<name>: Waiting at <place>".}
    Return SeverActions_TravelCore.JourneyLine(aiIndex)
EndFunction

Actor Function GetJourneyActor(Int aiIndex)
    {The actor of the journey at aiIndex, None past the end. Indices shift whenever a
     journey ends: resolve the actor at confirm time and cancel by actor. Kept for old
     frames and third-party callers (the MCM reads Travel_GetOrderedJourneyActors).}
    Return SeverActions_TravelCore.JourneyActor(aiIndex)
EndFunction

Function CancelJourneyAt(Int aiIndex, Bool restoreFollower = true)
    {Kept for old frames: cancel the journey at aiIndex (the MCM resolves the actor first).}
    Actor a = GetJourneyActor(aiIndex)
    If a
        NotifyPlayer("Cancelling travel for " + a.GetDisplayName())
        SeverActions_TravelCore.CancelJourney(a, restoreFollower)
    EndIf
EndFunction

Bool Function SetTravelSpeed(Actor akNPC, Int speed)
    {Change speed mid-journey (the pool alias is re-banded natively and the walk
     override swapped for the new pace's).}
    Return SeverActions_TravelCore.SetSpeed(akNPC, speed)
EndFunction

Int Function GetTravelSpeed(Actor akNPC)
    Return SeverActions_TravelCore.GetSpeed(akNPC)
EndFunction

Function ShowStatus()
    DebugMsg("=== Travel System Status ===")
    DebugMsg("LocationResolver ready: " + SeverActionsNative.IsLocationResolverReady())
    DebugMsg("Orchestrator active: " + SeverActionsNativeExt.Travel_GetActiveCount())
    Int n = GetActiveTravelCount()
    Int i = 0
    While i < n
        DebugMsg("Journey " + i + ": " + GetJourneyLine(i))
        i += 1
    EndWhile
    DebugMsg("Player-ordered journeys: " + n)
EndFunction

Bool Function IsNPCTraveling(Actor akNPC)
    Return SeverActionsNativeExt2.Travel_GetPhaseByActor(akNPC) != 0
EndFunction

String Function GetNPCTravelState(Actor akNPC)
    Int phase = SeverActionsNativeExt2.Travel_GetPhaseByActor(akNPC)
    If phase == 1
        Return "traveling"
    ElseIf phase == 2
        Return "waiting"
    EndIf
    Return ""
EndFunction

Function NotifyTravelSpokenTo(Actor akNPC)
    {The player came to a waiting traveler: the wait completes on the next tick.}
    SeverActions_TravelCore.NotifySpokenTo(akNPC)
EndFunction

; =============================================================================
; SPEED CONTROL
; =============================================================================

Bool Function SetTravelSpeedNatural(Actor akNPC, String speedText)
    Return SetTravelSpeed(akNPC, SeverActionsNativeExt.Travel_ParseSpeedFromText(speedText))
EndFunction

Package Function GetTravelPackageForSpeed(Int speed)
    Package pkg = SeverActionsNativeExt.Travel_GetSpeedPackage(speed)
    If pkg == None
        ; Self-heal an empty speed registry (neither the kDataLoaded seed nor load
        ; recovery filled it): re-register and retry, or travel silently no-ops.
        RegisterSpeedPackages()
        pkg = SeverActionsNativeExt.Travel_GetSpeedPackage(speed)
    EndIf
    Return pkg
EndFunction

Function RemoveAllTravelPackages(Actor akNPC)
    If TravelPackage
        ActorUtil.RemovePackageOverride(akNPC, TravelPackage)
    EndIf
    If TravelPackageWalk
        ActorUtil.RemovePackageOverride(akNPC, TravelPackageWalk)
    EndIf
    If TravelPackageJog
        ActorUtil.RemovePackageOverride(akNPC, TravelPackageJog)
    EndIf
    If TravelPackageRun
        ActorUtil.RemovePackageOverride(akNPC, TravelPackageRun)
    EndIf
    ; Plus the SeverTravelToAction* walk and run packages the speed registry holds (the
    ; walk is not among the properties above).
    Package realWalk = Game.GetFormFromFile(0x07C068, "SeverActions.esp") as Package
    If realWalk
        ActorUtil.RemovePackageOverride(akNPC, realWalk)
    EndIf
    Package realDefault = Game.GetFormFromFile(0x076F60, "SeverActions.esp") as Package
    If realDefault
        ActorUtil.RemovePackageOverride(akNPC, realDefault)
    EndIf
EndFunction

String Function GetSpeedName(Int speed)
    Return SeverActionsNativeExt.Travel_GetSpeedName(speed)
EndFunction

; Unused: the follow keyword lookup moved to SeverActions_TravelCore.
Keyword FollowerFollowKWCache

; =============================================================================
; UTILITIES
; =============================================================================

Function DebugMsg(String msg)
    Debug.Trace("SeverTravel: " + msg)
    If EnableDebugMessages
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("travel.travelDebugPrefix", ("" + msg)))
    EndIf
EndFunction

Function NotifyPlayer(String msg)
    Debug.Trace("SeverTravel: " + msg)
    Debug.Notification(msg)
EndFunction

Float Function ClampFloat(Float value, Float minVal, Float maxVal)
    If value < minVal
        Return minVal
    ElseIf value > maxVal
        Return maxVal
    EndIf
    Return value
EndFunction

; -----------------------------------------------------------------------------
; Safe-exit stubs (M-I, check 20): removed functions a saved frame may still call by
; name (F7); each answers a safe default. Never remove one (fomod/safe_exit_stubs.json).
; -----------------------------------------------------------------------------

Function StripStrayTravelPackages(Actor akNPC)
    {Safe-exit stub: removed as dead code.}
    ; M-I-STUB 3.9.14-beta25 (P3-08): dead code removed by the modular-install audit fix (89ed67cb, 2026-09-13)
EndFunction

; The five travel slots, replaced by the orchestrator's wait phase and
; SeverActions_TravelCore (P8-01).
Function SetSlotState(Int s, Int v)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

String Function GetSlotPlaceName(Int s)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
    Return ""
EndFunction

Function SetSlotPlaceName(Int s, String v)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

ObjectReference Function GetSlotDest(Int s)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
    Return None
EndFunction

Function SetSlotDest(Int s, ObjectReference v)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

Float Function GetSlotWaitDeadline(Int s)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
    Return 0.0
EndFunction

Function SetSlotWaitDeadline(Int s, Float v)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

Int Function GetSlotSpeed(Int s)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
    Return 0
EndFunction

Function SetSlotSpeed(Int s, Int v)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

Int Function GetSlotHandle(Int s)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
    Return 0
EndFunction

Function SetSlotHandle(Int s, Int v)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

Package Function GetSlotSandbox(Int s)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
    Return None
EndFunction

Function SetSlotSandbox(Int s, Package v)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

Int Function GetSlotSandboxOwned(Int s)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
    Return 0
EndFunction

Function SetSlotSandboxOwned(Int s, Bool v)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

Function ClearSlotData(Int s)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

Function NoteCallerCancelledHandle(Int aiHandle)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

Bool Function ConsumeCallerCancelledHandle(Int aiHandle)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
    Return false
EndFunction

Function InitializeSlotArrays()
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

Function RecoverExistingTravelers()
    {Safe-exit stub: moved to SeverActions_TravelCore.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): moved to SeverActions_TravelCore (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

Function OnArrived(Int slot, Actor akNPC, String placeName)
    {Safe-exit stub: moved to SeverActions_TravelCore.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): moved to SeverActions_TravelCore (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

Function CheckWaitingSlot(Int slot)
    {Safe-exit stub: moved to SeverActions_TravelCore.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): moved to SeverActions_TravelCore (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

Function OnPlayerArrived(Int slot, Actor akNPC)
    {Safe-exit stub: moved to SeverActions_TravelCore.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): moved to SeverActions_TravelCore (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

Function OnStayComplete(Int slot, Actor akNPC)
    {Safe-exit stub: moved to SeverActions_TravelCore.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): moved to SeverActions_TravelCore (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

Function OnWaitTimeout(Int slot, Actor akNPC)
    {Safe-exit stub: moved to SeverActions_TravelCore.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): moved to SeverActions_TravelCore (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

ReferenceAlias Function GetAliasForSlot(Int slot)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
    Return None
EndFunction

Int Function FindFreeSlot()
    {Safe-exit stub: -1 is the old "no slot" sentinel, so a resumed caller takes its none branch.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
    Return -1
EndFunction

Int Function FindSlotByActor(Actor akNPC)
    {Safe-exit stub: -1 is the old "no slot" sentinel, so a resumed caller takes its none branch.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
    Return -1
EndFunction

Function ClearSlot(Int slot, Bool restoreFollower = false)
    {Safe-exit stub: moved to SeverActions_TravelCore.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): moved to SeverActions_TravelCore (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

Function ClearTravelStorage(Actor akNPC)
    {Safe-exit stub: moved to SeverActions_TravelCore.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): moved to SeverActions_TravelCore (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

Int Function GetSlotState(Int slot)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
    Return 0
EndFunction

Function ClearSlotFromMCM(Int slot, Bool restoreFollower = true)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

String Function GetSlotDestination(Int slot)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
    Return ""
EndFunction

String Function GetSlotStatusText(Int slot)
    {Safe-exit stub: retired with the five travel slots.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): retired with the five slots (the orchestrator owns the wait phase, TRVL v5), plan P8
    Return ""
EndFunction

Function DismissFollower(Actor akNPC)
    {Safe-exit stub: moved to SeverActions_TravelCore.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): moved to SeverActions_TravelCore (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

Function ReinstateFollower(Actor akNPC)
    {Safe-exit stub: moved to SeverActions_TravelCore.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): moved to SeverActions_TravelCore (the orchestrator owns the wait phase, TRVL v5), plan P8
EndFunction

Keyword Function GetFollowerFollowKW()
    {Safe-exit stub: moved to SeverActions_TravelCore.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): moved to SeverActions_TravelCore (the orchestrator owns the wait phase, TRVL v5), plan P8
    Return None
EndFunction

; ============================================================================
; M-V VERB DISPATCHER (DR10)
; ============================================================================
; The DLL routes this module's UI verbs (Native/data/verb_table.json) as
; SeverActions_Verb_Travel with the Actions page's 8 pipe fields. This is the ONE
; script defining OnVerb_Travel: a callback name runs on every script of the form
; that defines it (F4). Registered in RegisterEvents (DR16).
Event OnVerb_Travel(String eventName, String strArg, Float numArg, Form sender)
    String actionId = SeverActions_ModuleBase.VerbField(strArg, 0)
    String targetName = SeverActions_ModuleBase.VerbField(strArg, 1)
    String target2Name = SeverActions_ModuleBase.VerbField(strArg, 2)
    String strParam = SeverActions_ModuleBase.VerbField(strArg, 3)
    Int intParam = SeverActions_ModuleBase.VerbField(strArg, 4) as Int
    String str2Param = SeverActions_ModuleBase.VerbField(strArg, 5)
    Int targetFid = SeverActions_ModuleBase.VerbField(strArg, 6) as Int
    Int target2Fid = SeverActions_ModuleBase.VerbField(strArg, 7) as Int
    Debug.Trace("[SeverActions_Travel] OnVerb_Travel: " + actionId + " target=" + targetName + " target2=" + target2Name \
        + " str=" + strParam + " int=" + intParam + " str2=" + str2Param + " fid=" + targetFid + " fid2=" + target2Fid)

    ; Resolve by the sender, then the FormID, then the fuzzy name; names are
    ; re-canonicalized to display names.
    Actor target = SeverActions_ModuleBase.VerbActor(sender, targetFid, targetName)
    If !target
        Debug.Trace("[SeverActions_Travel] OnVerb_Travel: could not resolve target '" + targetName + "' for " + actionId)
        Return
    EndIf
    targetName = target.GetDisplayName()
    Actor target2 = SeverActions_ModuleBase.VerbActor(None, target2Fid, target2Name)
    If target2
        target2Name = target2.GetDisplayName()
    ElseIf target2Name != ""
        Debug.Trace("[SeverActions_Travel] OnVerb_Travel: target2 name '" + target2Name + "' did not resolve to an actor (action=" + actionId + ")")
    EndIf

    If actionId == "travelToPlace"
        ; strParam = location name, str2Param = speed word (Walk/Jog/Run)
        Int speed = 1  ; Jog (default)
        If str2Param == "Walk"
            speed = 0
        ElseIf str2Param == "Run"
            speed = 2
        EndIf
        ; waitForPlayer=True: they go there and wait. Recompile this call site whenever
        ; TravelToPlace's signature changes: a stale arg count errors at the VM and the
        ; action silently dies.
        TravelToPlace(target, strParam, 0.0, True, speed, True)

    ElseIf actionId == "cancelTravel"
        CancelTravel(target)

    ElseIf actionId == "travelPace"
        ; str2Param = the pace word (walk/run/sprint); SetTravelSpeedNatural normalizes it.
        SetTravelSpeedNatural(target, str2Param)

    ElseIf actionId == "standUp"
        ; furniturelib is in travel's closure: a static call only (N2).
        SeverActions_FurnitureLib.Stop(target)

    Else
        Debug.Trace("[SeverActions_Travel] OnVerb_Travel: unknown actionId '" + actionId + "' (not a row this dispatcher carries)")
    EndIf

    ; Refresh once the verb has run: the DLL's own refresh fires one frame after routing,
    ; before this Papyrus work changes the stores. Once per click, so cheap.
    SeverActionsNative.Magelight_RefreshPage("world")
    SeverActionsNative.Magelight_RefreshPage("enterprises")
EndEvent

; ============================================================================
; M-K HOTKEY DISPATCHER (DR10)
; ============================================================================
; The DLL's input sink (Native/data/hotkey_table.json) sends this module's hotkeys as
; SeverActions_Hotkey_Travel: strArg = the hotkey id, sender = the target resolved by
; targetMode, or None. The sink already applied the global gates (menus, dialogue,
; dead, sitting); each branch keeps its own rules and notifications.
Event OnHotkey_Travel(String eventName, String strArg, Float numArg, Form sender)
    ; "wheel:<id>" is the quick wheel's pick of the same hotkey. fromWheel is unused
    ; here: neither furniture hotkey behaves differently from the wheel.
    String hotkeyId = strArg
    Bool fromWheel = false
    If StringUtil.Substring(strArg, 0, 6) == "wheel:"
        fromWheel = true
        hotkeyId = StringUtil.Substring(strArg, 6)
    EndIf
    Actor target = sender as Actor
    Actor player = Game.GetPlayer()
    Debug.Trace("[SeverActions_Travel] OnHotkey_Travel: " + hotkeyId + " target=" + target)

    ; The furniture hotkeys (furniturelib: static calls only).
    If hotkeyId == "StandUp"
        If !target
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.noValidTarget"))
        ElseIf target == player
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.cannotTargetYourself"))
        ElseIf SeverActions_FurnitureLib.CanStop(target)
            SeverActions_FurnitureLib.Stop(target)
            ; No notification: FurnitureLib.Stop registers a SkyrimNet event
        Else
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("hotkeys.isNotUsingFurniture", ("" + target.GetDisplayName())))
        EndIf

    ElseIf hotkeyId == "UseFurniture"
        ; Two-step: aim at the NPC and press, then at the furniture within the window.
        ; The sink passes the crosshair actor (None on furniture); the furniture is read here.
        ObjectReference ref = Game.GetCurrentCrosshairRef()
        Actor crosshairActor = ref as Actor
        Bool pendingLive = HotkeyPendingFurnitureUser != None && !HotkeyPendingFurnitureUser.IsDead() \
            && (Utility.GetCurrentRealTime() - HotkeyPendingFurnitureTime) < HotkeyPendingFurnitureWindow
        If pendingLive
            ; STEP 2 - aiming at furniture sends the selected NPC to use it. Per seat (the
            ; free half of a bench is usable), and no redirect: the player aimed at this piece.
            If ref && (ref.GetBaseObject() as Furniture) && crosshairActor == None
                If !SeverActionsNativeExt2.Furniture_SeatFor(HotkeyPendingFurnitureUser, ref, 0.0)
                    Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.furnitureAlreadyInUse"))
                Else
                    Actor user = HotkeyPendingFurnitureUser
                    HotkeyPendingFurnitureUser = None
                    SeverActions_FurnitureLib.UseRef(user, ref)
                    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("hotkeys.isHeadingTo", ("" + user.GetDisplayName()), ("" + ref.GetBaseObject().GetName())))
                EndIf
            ElseIf crosshairActor != None && crosshairActor != player && !crosshairActor.IsDead()
                ; Re-aimed at a different NPC - switch the selection instead.
                HotkeyPendingFurnitureUser = crosshairActor
                HotkeyPendingFurnitureTime = Utility.GetCurrentRealTime()
                Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("hotkeys.selectedAimFurniture", ("" + crosshairActor.GetDisplayName())))
            Else
                Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.aimAtFurniturePress"))
            EndIf
        ElseIf crosshairActor != None && crosshairActor != player && !crosshairActor.IsDead()
            ; STEP 1 - pick the NPC under the crosshair.
            HotkeyPendingFurnitureUser = crosshairActor
            HotkeyPendingFurnitureTime = Utility.GetCurrentRealTime()
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("hotkeys.selectedAimFurniture", ("" + crosshairActor.GetDisplayName())))
        Else
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.aimAtNpcPress"))
        EndIf

    Else
        Debug.Trace("[SeverActions_Travel] OnHotkey_Travel: unknown hotkeyId '" + hotkeyId + "' (not a row this dispatcher carries)")
    EndIf
EndEvent
