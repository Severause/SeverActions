Scriptname SeverActions_TravelCore extends Quest
{The travel core (support bundle "travelcore", plan M-T): BeginJourney starts an NPC's walk on the native
 TravelOrchestrator and arms its arrival wait (state kWaiting; a TravelAlias wait pin keeps the waiting NPC
 persistent). This script owns every package touch of the wait, since ActorUtil is Papyrus-only. Attached
 with no properties, so records are resolved by FormID. Setup runs from the travelcore provider's stage 1 (Maintenance), never OnInit (DR20).
 Requires only furniturelib and names no module type; Travel, Kidnap, Arrest, Courier, Enterprises and
 Sever's Hearth call the Globals below.}

; ── Records (SeverActions.esp, by FormID) ─────────────────────────────────────
Int Property FID_TRAVEL_TARGET_KW  = 0x076F5F AutoReadOnly   ; SeverTravelKeyword: the LinkedRef the travel packages chase
Int Property FID_SANDBOX_PKG       = 0x0BDDFF AutoReadOnly   ; SeverActions_LeisureSandbox: default arrival sandbox (also Follow's manual wait)
; Travel package overrides, stripped together by _RemoveTravelOverrides. The native speed
; registry (Travel_GetSpeedPackage) serves WALK, JOG and DEFAULT, which is its run.
Int Property FID_PKG_WALK          = 0x07C068 AutoReadOnly
Int Property FID_PKG_JOG           = 0x07C069 AutoReadOnly
Int Property FID_PKG_RUN           = 0x07C06A AutoReadOnly
Int Property FID_PKG_DEFAULT       = 0x076F60 AutoReadOnly
Int Property FID_PKG_LEGACY_WALK   = 0x02B051 AutoReadOnly
Int Property FID_PKG_LEGACY_RUN    = 0x02B053 AutoReadOnly

; ── Constants ─────────────────────────────────────────────────────────────────
Int Property TRAVEL_PACKAGE_PRIORITY = 85 AutoReadOnly
{The walk's override and the arrival sandbox. SkyrimNet ranks ActorUtil overrides against its own dialogue
 package (30), so a traveler spoken to keeps walking; SA's 100 / 110 overrides stay out of a journey by
 their own journey checks.}
Float Property ARRIVAL_DISTANCE = 300.0 AutoReadOnly
Float Property DEFAULT_WAIT_HOURS = 48.0 AutoReadOnly
Float Property MIN_WAIT_HOURS = 6.0 AutoReadOnly
Float Property MAX_WAIT_HOURS = 168.0 AutoReadOnly
Int Property TRAVEL_OPTIONS_LONGRANGE = 12 AutoReadOnly
{4 = abort on a degraded actor, 8 = skip the pre-flight (CanNavigateToPosition
 false-rejects an unloaded destination cell).}
Int Property SPEED_WALK = 0 AutoReadOnly
Int Property SPEED_JOG = 1 AutoReadOnly
Int Property SPEED_RUN = 2 AutoReadOnly
Int Property WAIT_PIN_FIRST_ALIAS = 13 AutoReadOnly
{TravelAlias00..04 are ALST 13..17 of the quest: the wait pins the DLL claims at arrival.}
Int Property WAIT_PIN_COUNT = 5 AutoReadOnly
Float Property GREET_LINE_SECONDS = 12.0 AutoReadOnly
{After the greet narration, the wait completes once this long has passed and
 SkyrimNet's speech queue is empty.}
String Property JOURNEY_TAG = "tc" AutoReadOnly
{The callbackTag of every journey this script starts. The DLL hardcodes the same
 literal (Travel_ArmWait's retag, TravelGateCore, the data gatherer).}
String Property GREET_PENDING_KEY = "SeverTravelCore_GreetPending" AutoReadOnly


; ── The static API (N2): Globals that forward to the instance's Do* members ────

SeverActions_TravelCore Function Instance() Global
    {This script's instance on quest 0x000D62.}
    Return (Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest) as SeverActions_TravelCore
EndFunction

Bool Function BeginJourney(Actor akNPC, ObjectReference akDest, String asPlaceLabel, Float afWaitHours, Bool abStopFollowing, Int aiSpeed, Bool abWaitForPlayer, Package akSandboxOverride) Global
    {See DoBeginJourney. False when refused or the core is not bound.}
    SeverActions_TravelCore core = Instance()
    If !core
        Debug.Trace("[SeverActions_TravelCore] BeginJourney: the core is not bound")
        Return false
    EndIf
    Return core.DoBeginJourney(akNPC, akDest, asPlaceLabel, afWaitHours, abStopFollowing, aiSpeed, abWaitForPlayer, akSandboxOverride)
EndFunction

Function CancelJourney(Actor akNPC, Bool abRestoreFollower = true) Global
    {See DoCancelJourney. Without the core, only the native cancel runs.}
    SeverActions_TravelCore core = Instance()
    If core
        core.DoCancelJourney(akNPC, abRestoreFollower)
    ElseIf akNPC
        SeverActionsNativeExt.Travel_CancelByActor(akNPC)
    EndIf
EndFunction

Function CancelAllJourneys(Bool abRestoreFollowers = true) Global
    SeverActions_TravelCore core = Instance()
    If core
        core.DoCancelAllJourneys(abRestoreFollowers)
    EndIf
EndFunction

Bool Function SetSpeed(Actor akNPC, Int aiSpeed) Global
    SeverActions_TravelCore core = Instance()
    If !core
        Return SeverActionsNativeExt2.Travel_SetSpeedByActor(akNPC, aiSpeed)
    EndIf
    Return core.DoSetSpeed(akNPC, aiSpeed)
EndFunction

Int Function GetSpeed(Actor akNPC) Global
    SeverActions_TravelCore core = Instance()
    If !core
        Return -1
    EndIf
    Return core.DoGetSpeed(akNPC)
EndFunction

Function NotifySpokenTo(Actor akNPC) Global
    If akNPC
        SeverActionsNativeExt2.Travel_NotifySpokenTo(akNPC)
    EndIf
EndFunction

Int Function JourneyCount() Global
    SeverActions_TravelCore core = Instance()
    If !core
        Return 0
    EndIf
    Return core.DoJourneyCount()
EndFunction

Actor Function JourneyActor(Int aiIndex) Global
    SeverActions_TravelCore core = Instance()
    If !core
        Return None
    EndIf
    Return core.DoJourneyActor(aiIndex)
EndFunction

String Function JourneyLine(Int aiIndex) Global
    SeverActions_TravelCore core = Instance()
    If !core
        Return ""
    EndIf
    Return core.DoJourneyLine(aiIndex)
EndFunction

Function StripTravelOverrides(Actor akNPC) Global
    {Remove every travel package override (_RemoveTravelOverrides), e.g. the courier's
     jog before its talk package.}
    SeverActions_TravelCore core = Instance()
    If core && akNPC
        core._RemoveTravelOverrides(akNPC)
    EndIf
EndFunction

; ── Load recovery (the travelcore provider's stage 1) ─────────────────────────

Function Maintenance()
    {Every load and new game, from the travelcore provider's stage 1 before Travel's
     recovery: the ModEvent registrations (DR16), the one-shot slot migration, the
     package overrides re-applied (they do not always survive a load) and the wait-pin sweep.}
    RegisterForModEvent("SeverActions_TravelComplete", "OnTravelComplete")
    RegisterForModEvent("SeverActions_TravelGreet", "OnTravelGreet")
    RegisterForModEvent("SeverActions_TravelWaitPinClear", "OnTravelWaitPinClear")
    RegisterForModEvent("SeverActions_TravelSpeedChanged", "OnTravelSpeedChanged")
    RegisterForModEvent("SeverActions_Tick_TravelCore", "OnChronoTick_TravelCore")
    StorageUtil.FormListClear(None, GREET_PENDING_KEY)   ; a greet in progress does not survive a load
    MigrateLegacySlots()
    Actor[] waiting = SeverActionsNativeExt2.Travel_GetWaitingActors()
    Int i = 0
    While i < waiting.Length
        Actor w = waiting[i]
        If w && !w.IsDead()
            _ApplyArrivalSandbox(w)
            ; Waiting NPCs still hold the travel LinkedRef and OrphanCleanup's registry is
            ; cleared at load: re-register (the DLL does too; idempotent).
            SeverActionsNative.OrphanCleanup_RegisterTraveler(w)
            StorageUtil.UnsetFloatValue(w, "SeverTravel_GreetTime")
        EndIf
        i += 1
    EndWhile
    ; Every walker's override again: SkyrimNet's ranking learns an override only when ActorUtil adds it.
    Actor[] ordered = SeverActionsNativeExt2.Travel_GetOrderedJourneyActors()
    Int reapplied = 0
    i = 0
    While i < ordered.Length
        Actor o = ordered[i]
        If o && !o.IsDead() && SeverActionsNativeExt2.Travel_GetPhaseByActor(o) == 1
            Package pkg = SeverActionsNativeExt.Travel_GetSpeedPackage(StorageUtil.GetIntValue(o, "SeverTravel_Speed", 0))
            If pkg
                ActorUtil.AddPackageOverride(o, pkg, TRAVEL_PACKAGE_PRIORITY, 1)
                o.EvaluatePackage()
                reapplied += 1
            EndIf
        EndIf
        i += 1
    EndWhile
    SweepWaitPins()
    Debug.Trace("[SeverActions_TravelCore] Maintenance: " + waiting.Length + " waiting NPC(s) re-sandboxed, " + reapplied + " walk override(s) re-applied")
EndFunction

Function SweepWaitPins()
    {Free any actor in a wait pin with no live wait. The DLL's sweep asks for the same
     Clear() by ModEvent, which can arrive before this script registers on load; this
     direct sweep has no ordering dependency.}
    Quest q = Self as Quest
    Int i = 0
    While i < WAIT_PIN_COUNT
        ReferenceAlias pin = q.GetAlias(WAIT_PIN_FIRST_ALIAS + i) as ReferenceAlias
        If pin
            Actor held = pin.GetActorReference()
            If held && SeverActionsNativeExt2.Travel_GetPhaseByActor(held) != 2
                pin.Clear()
                held.EvaluatePackage()
                Debug.Trace("[SeverActions_TravelCore] Load sweep freed stale wait pin " + (WAIT_PIN_FIRST_ALIAS + i) + " (" + held.GetDisplayName() + ")")
            EndIf
        EndIf
        i += 1
    EndWhile
EndFunction

Function MigrateLegacySlots()
    {One-shot 'MIGR' migration (DR14): the five StorageUtil slots of the old
     SeverActions_Travel become orchestrator state. A travelling slot gets its wait
     armed (Travel_ArmWait retags it "tc") and its legacy alias emptied; a waiting slot
     has no orchestrator entry (F18), so Travel_AdoptWaiting creates one and keeps the
     legacy alias as its pin. Every slot key is cleared, so a re-run finds nothing.}
    String mig = "TravelSlotsToNative"
    Int migVersion = 1
    If SeverActionsNativeExt2.Migration_IsDone(mig, migVersion)
        Return
    EndIf
    If !SeverActionsNativeExt2.Migration_TryClaim(mig, migVersion)
        Return
    EndIf
    Quest q = Self as Quest
    Keyword kw = Game.GetFormFromFile(FID_TRAVEL_TARGET_KW, "SeverActions.esp") as Keyword
    Int armed = 0
    Int adopted = 0
    Int s = 0
    While s < WAIT_PIN_COUNT
        Int slotState = StorageUtil.GetIntValue(None, "SeverTravel_SlotState_" + s, 0)
        ReferenceAlias pin = q.GetAlias(WAIT_PIN_FIRST_ALIAS + s) as ReferenceAlias
        Actor npc = None
        If pin
            npc = pin.GetActorReference()
        EndIf
        If slotState != 0 && npc && !npc.IsDead()
            String place = StorageUtil.GetStringValue(None, "SeverTravel_SlotPlace_" + s, "")
            Float deadline = StorageUtil.GetFloatValue(None, "SeverTravel_SlotWait_" + s, 0.0)
            Bool waitForPlayer = StorageUtil.GetIntValue(npc, "SeverTravel_WaitForPlayer", 1) == 1
            If slotState == 1
                Int handle = StorageUtil.GetIntValue(None, "SeverTravel_SlotHandle_" + s, 0)
                If handle > 0 && SeverActionsNativeExt.Travel_IsActive(handle)
                    If SeverActionsNativeExt2.Travel_ArmWait(handle, deadline, waitForPlayer, place)
                        armed += 1
                        StorageUtil.SetIntValue(npc, "SeverTravel_Handle", handle)
                    EndIf
                    StorageUtil.SetIntValue(npc, "SeverTravel_Speed", StorageUtil.GetIntValue(None, "SeverTravel_SlotSpeed_" + s, 0))
                Else
                    ; The walk did not survive the load: tear down, no restore.
                    _Teardown(npc, false)
                EndIf
                ; The pool alias drives the walk; the DLL claims a pin at arrival.
                pin.Clear()
            ElseIf slotState == 2
                ObjectReference dest = StorageUtil.GetFormValue(None, "SeverTravel_SlotDest_" + s) as ObjectReference
                Package sbx = StorageUtil.GetFormValue(None, "SeverTravel_SlotSandbox_" + s) as Package
                If sbx && !StorageUtil.GetFormValue(npc, "SeverTravel_SandboxOverride")
                    StorageUtil.SetFormValue(npc, "SeverTravel_SandboxOverride", sbx)
                EndIf
                ; Shared-sandbox ownership moves from the slot to the actor key the
                ; teardown reads (-1 = no record, treated as owned).
                Int slotSbxOwned = StorageUtil.GetIntValue(None, "SeverTravel_SlotSbxOwned_" + s, -1)
                If slotSbxOwned != 0
                    StorageUtil.SetIntValue(npc, "SeverTravel_SbxOwned", 1)
                EndIf
                Int adoptedHandle = SeverActionsNativeExt2.Travel_AdoptWaiting(npc, dest, kw, deadline, waitForPlayer, place, WAIT_PIN_FIRST_ALIAS + s)
                If adoptedHandle > 0
                    adopted += 1
                    StorageUtil.SetIntValue(npc, "SeverTravel_Handle", adoptedHandle)
                Else
                    _Teardown(npc, false)
                    pin.Clear()
                EndIf
            EndIf
        ElseIf pin && npc
            pin.Clear()   ; an empty slot's stale fill, or a dead traveler
        EndIf
        StorageUtil.UnsetIntValue(None, "SeverTravel_SlotState_" + s)
        StorageUtil.UnsetStringValue(None, "SeverTravel_SlotPlace_" + s)
        StorageUtil.UnsetFormValue(None, "SeverTravel_SlotDest_" + s)
        StorageUtil.UnsetFloatValue(None, "SeverTravel_SlotWait_" + s)
        StorageUtil.UnsetIntValue(None, "SeverTravel_SlotSpeed_" + s)
        StorageUtil.UnsetIntValue(None, "SeverTravel_SlotHandle_" + s)
        StorageUtil.UnsetFormValue(None, "SeverTravel_SlotSandbox_" + s)
        StorageUtil.UnsetIntValue(None, "SeverTravel_SlotSbxOwned_" + s)
        s += 1
    EndWhile
    StorageUtil.IntListClear(None, "SeverTravel_CallerCancelledHandles")
    SeverActionsNativeExt2.Migration_MarkDone(mig, migVersion)
    Debug.Trace("[SeverActions_TravelCore] Legacy travel slots migrated: " + armed + " walk(s) armed, " + adopted + " wait(s) adopted")
EndFunction

; ── The journey primitive ─────────────────────────────────────────────────────

Bool Function DoBeginJourney(Actor akNPC, ObjectReference akDest, String asPlaceLabel, Float afWaitHours, Bool abStopFollowing, Int aiSpeed, Bool abWaitForPlayer, Package akSandboxOverride)
    {Start akNPC's journey to akDest with an arrival wait; true when it started. The
     caller has resolved the destination (a door to its interior marker) and disengaged
     furniture and crafting. asPlaceLabel is the name narrated and shown to the player.
     afWaitHours <= 0 = 48 h, clamped to 6..168; abStopFollowing drops a follower for
     the trip (reinstated when the wait ends well); aiSpeed 0 walk / 1 jog / 2 run;
     abWaitForPlayer false = a self-errand ending at the deadline instead of meeting
     the player; akSandboxOverride replaces the default arrival sandbox.}
    If !akNPC || akNPC.IsDead() || !akDest
        Return false
    EndIf
    If aiSpeed < 0
        aiSpeed = 0
    ElseIf aiSpeed > 2
        aiSpeed = 2
    EndIf
    Package travelPkg = SeverActionsNativeExt.Travel_GetSpeedPackage(aiSpeed)
    If !travelPkg
        Debug.Trace("[SeverActions_TravelCore] BeginJourney: no package for speed " + aiSpeed + " (the native registry is empty?)")
        Return false
    EndIf
    Keyword kw = Game.GetFormFromFile(FID_TRAVEL_TARGET_KW, "SeverActions.esp") as Keyword

    ; End any journey already under way (follower restored).
    DoCancelJourney(akNPC, true)

    If afWaitHours <= 0.0
        afWaitHours = DEFAULT_WAIT_HOURS
    EndIf
    If afWaitHours < MIN_WAIT_HOURS
        afWaitHours = MIN_WAIT_HOURS
    ElseIf afWaitHours > MAX_WAIT_HOURS
        afWaitHours = MAX_WAIT_HOURS
    EndIf
    Float waitUntil = Utility.GetCurrentGameTime() + (afWaitHours / 24.0)

    If abStopFollowing
        _DismissForTrip(akNPC)
    EndIf

    ; The orchestrator sets the LinkedRef and claims a Traveler_NN pool alias whose
    ; package drives both the loaded and the unloaded leg (the pool quest's priority 106).
    Int handle = SeverActionsNativeExt.Travel_Begin(akNPC, akDest, kw, ARRIVAL_DISTANCE, JOURNEY_TAG, TRAVEL_OPTIONS_LONGRANGE, 0, aiSpeed)
    If handle <= 0
        Debug.Trace("[SeverActions_TravelCore] BeginJourney: orchestrator rejected " + akNPC.GetDisplayName() + " -> '" + asPlaceLabel + "'")
        ; Undo the trip's dismissal.
        If StorageUtil.GetIntValue(akNPC, "SeverTravel_WasFollower", 0) != 0
            _ReinstateAfterTrip(akNPC)
        EndIf
        StorageUtil.UnsetIntValue(akNPC, "SeverTravel_WasFollower")
        Return false
    EndIf
    SeverActionsNativeExt2.Travel_ArmWait(handle, waitUntil, abWaitForPlayer, asPlaceLabel)
    ; OnTravelComplete checks the event's handle against this, so the late "cancelled"
    ; of the journey just ended (queued to next frame) cannot tear this one down.
    StorageUtil.SetIntValue(akNPC, "SeverTravel_Handle", handle)
    ; The same walk as an override: it keeps SkyrimNet's dialogue package from turning the
    ; traveler toward a speaker, and it drives the trip alone when the pool is exhausted.
    ActorUtil.AddPackageOverride(akNPC, travelPkg, TRAVEL_PACKAGE_PRIORITY, 1)
    akNPC.EvaluatePackage()

    StorageUtil.SetFormValue(akNPC, "SeverTravel_SandboxOverride", akSandboxOverride)
    StorageUtil.SetIntValue(akNPC, "SeverTravel_Speed", aiSpeed)
    ; Keep OrphanCleanup's keyword scan off the travel LinkedRef (unregistered at teardown).
    SeverActionsNative.OrphanCleanup_RegisterTraveler(akNPC)
    ; SeverTravel_State doubles as this script's "journey keys exist" marker; other
    ; code reads the native travel state (M-T).
    StorageUtil.SetStringValue(akNPC, "SeverTravel_State", "traveling")
    StorageUtil.SetStringValue(akNPC, "SeverTravel_Destination", asPlaceLabel)
    SeverActionsNative.Native_SetTravelState(akNPC, "traveling", asPlaceLabel)
    Debug.Trace("[SeverActions_TravelCore] " + akNPC.GetDisplayName() + " sets out for '" + asPlaceLabel + "' (handle " + handle + ", speed " + aiSpeed + ", wait " + afWaitHours + " h, " + (abWaitForPlayer as String) + ")")
    Return true
EndFunction

Function DoCancelJourney(Actor akNPC, Bool abRestoreFollower = true)
    {End akNPC's journey or wait now, tearing down synchronously with the caller's
     abRestoreFollower; the "cancelled" event that follows finds no keys and is ignored.}
    If !akNPC
        Return
    EndIf
    If SeverActionsNativeExt2.Travel_GetPhaseByActor(akNPC) == 0
        ; No live entry but keys left: the journey ended and its terminal event is
        ; still queued. Tear down now with the caller's choice, so that event finds
        ; no keys and cannot restore a follower the caller just parked.
        If StorageUtil.HasStringValue(akNPC, "SeverTravel_State")
            _Teardown(akNPC, abRestoreFollower)
        EndIf
        Return
    EndIf
    _Teardown(akNPC, abRestoreFollower)
    SeverActionsNativeExt.Travel_CancelByActor(akNPC)
EndFunction

Function DoCancelAllJourneys(Bool abRestoreFollowers = true)
    {Every player-ordered journey, on the road or waiting (the MCM's reset).}
    Actor[] all = SeverActionsNativeExt2.Travel_GetOrderedJourneyActors()
    Int i = 0
    While i < all.Length
        DoCancelJourney(all[i], abRestoreFollowers)
        i += 1
    EndWhile
EndFunction

Bool Function DoSetSpeed(Actor akNPC, Int aiSpeed)
    {Change a walking journey's pace: the native re-bands the pool alias and the walk
     override is swapped for the new pace's (see the rule in the body).}
    If !akNPC
        Return false
    EndIf
    If aiSpeed < 0
        aiSpeed = 0
    ElseIf aiSpeed > 2
        aiSpeed = 2
    EndIf
    Bool applied = SeverActionsNativeExt2.Travel_SetSpeedByActor(akNPC, aiSpeed)
    If SeverActionsNativeExt2.Travel_GetPhaseByActor(akNPC) == 1
        ; This script's walk always carries the override; another system's journey (a kidnap
        ; leg, a courier) only when it holds no pool alias, and its own teardown strips it.
        If StorageUtil.GetIntValue(akNPC, "SeverTravel_Handle", 0) > 0 || !SeverActionsNativeExt2.Travel_HasAliasByActor(akNPC)
            _SwapWalkOverride(akNPC, aiSpeed)
        EndIf
        StorageUtil.SetIntValue(akNPC, "SeverTravel_Speed", aiSpeed)
        applied = true
    EndIf
    Return applied
EndFunction

Function _SwapWalkOverride(Actor akNPC, Int aiSpeed)
    Package newPkg = SeverActionsNativeExt.Travel_GetSpeedPackage(aiSpeed)
    If newPkg
        _RemoveTravelOverrides(akNPC)
        ActorUtil.AddPackageOverride(akNPC, newPkg, TRAVEL_PACKAGE_PRIORITY, 1)
        akNPC.EvaluatePackage()
    EndIf
EndFunction

Event OnTravelSpeedChanged(String eventName, String strArg, Float numArg, Form sender)
    {The web travel map re-banded a journey natively (numArg = the pace): this script's walk
     swaps its override and records the pace the load re-applies.}
    Actor npc = sender as Actor
    If !npc || StorageUtil.GetIntValue(npc, "SeverTravel_Handle", 0) <= 0 || SeverActionsNativeExt2.Travel_GetPhaseByActor(npc) != 1
        Return
    EndIf
    _SwapWalkOverride(npc, numArg as Int)
    StorageUtil.SetIntValue(npc, "SeverTravel_Speed", numArg as Int)
EndEvent

Int Function DoGetSpeed(Actor akNPC)
    {The pace of the actor's live journey, -1 when none.}
    If !akNPC || SeverActionsNativeExt2.Travel_GetPhaseByActor(akNPC) == 0
        Return -1
    EndIf
    Return StorageUtil.GetIntValue(akNPC, "SeverTravel_Speed", 0)
EndFunction

Function DoNotifySpokenTo(Actor akNPC)
    {The player came to a waiting traveler: the wait ends on the next native tick.}
    If akNPC
        SeverActionsNativeExt2.Travel_NotifySpokenTo(akNPC)
    EndIf
EndFunction

; ── The journey list (the MCM's Travel page) ──

Int Function DoJourneyCount()
    Actor[] all = SeverActionsNativeExt2.Travel_GetOrderedJourneyActors()
    Return all.Length
EndFunction

Actor Function DoJourneyActor(Int aiIndex)
    Actor[] all = SeverActionsNativeExt2.Travel_GetOrderedJourneyActors()
    If aiIndex < 0 || aiIndex >= all.Length
        Return None
    EndIf
    Return all[aiIndex]
EndFunction

String Function DoJourneyLine(Int aiIndex)
    {"<name>: Traveling to <place>" / "<name>: Waiting at <place>", "" past the end.}
    Actor a = DoJourneyActor(aiIndex)
    If !a
        Return ""
    EndIf
    String place = SeverActionsNativeExt2.Travel_GetPlaceLabelByActor(a)
    If place == ""
        place = "?"
    EndIf
    If SeverActionsNativeExt2.Travel_GetPhaseByActor(a) == 2
        Return a.GetDisplayName() + ": Waiting at " + place
    EndIf
    Return a.GetDisplayName() + ": Traveling to " + place
EndFunction

; ── The completion event (M-E canonical callback; this script answers "tc") ──

Event OnTravelComplete(String eventName, String strArg, Float numArg, Form sender)
    {strArg = "<callbackTag>|<status>", numArg = the journey handle. "waiting" is the
     arrival into the wait (the entry lives on); every other status ends the journey.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String tag = StringUtil.Substring(strArg, 0, pipePos)
    If tag != JOURNEY_TAG
        Return   ; a courier, a steward, the audit, a kidnap leg: their own scripts answer
    EndIf
    String status = StringUtil.Substring(strArg, pipePos + 1, 0)
    Actor npc = sender as Actor
    If !npc
        Return
    EndIf
    ; Already torn down (DoCancelJourney): not a second teardown.
    If !StorageUtil.HasStringValue(npc, "SeverTravel_State")
        Debug.Trace("[SeverActions_TravelCore] " + npc.GetDisplayName() + " " + status + " - no journey keys, ignored")
        Return
    EndIf
    ; A late event of an older journey: the actor has a newer one (see DoBeginJourney).
    Int evHandle = numArg as Int
    Int ownHandle = StorageUtil.GetIntValue(npc, "SeverTravel_Handle", 0)
    If evHandle > 0 && ownHandle > 0 && evHandle != ownHandle
        Debug.Trace("[SeverActions_TravelCore] " + npc.GetDisplayName() + " " + status + " handle " + evHandle + " - the actor's journey is " + ownHandle + " now, ignored")
        Return
    EndIf
    String place = SeverActionsNativeExt2.Travel_GetPlaceLabelByActor(npc)
    If place == ""
        place = StorageUtil.GetStringValue(npc, "SeverTravel_Destination", "")
    EndIf
    Debug.Trace("[SeverActions_TravelCore] " + npc.GetDisplayName() + " " + status + " ('" + place + "')")

    If status == "waiting"
        _OnArrivedWaiting(npc, place)
    ElseIf status == "arrived"
        ; The player was with them on arrival: skip the wait and greet.
        StorageUtil.SetStringValue(npc, "SeverTravel_State", "complete")
        SeverActionsNative.Native_SetTravelState(npc, "complete", "")
        StorageUtil.SetStringValue(npc, "SeverTravel_Result", "arrived_together")
        Actor player = Game.GetPlayer()
        SkyrimNetApi.DirectNarration("*" + npc.GetDisplayName() + " arrives at " + place + " with " + player.GetDisplayName() + " at their side*", npc, player)
        Debug.Notification(npc.GetDisplayName() + " arrived at " + place)
        _Teardown(npc, true)
    ElseIf status == "waitdone"
        StorageUtil.SetStringValue(npc, "SeverTravel_State", "complete")
        SeverActionsNative.Native_SetTravelState(npc, "complete", "")
        StorageUtil.SetStringValue(npc, "SeverTravel_Result", "player_arrived")
        ; No HUD line: the greet narration already played when they spotted the player.
        _Teardown(npc, true)
    ElseIf status == "waittimeout"
        StorageUtil.SetStringValue(npc, "SeverTravel_State", "timeout")
        SeverActionsNative.Native_SetTravelState(npc, "timeout", "")
        StorageUtil.SetStringValue(npc, "SeverTravel_Result", "timeout")
        Debug.Notification(npc.GetDisplayName() + "'s patience ran out!")
        _Teardown(npc, false)   ; whoever wants them back re-summons
    ElseIf status == "stayended"
        StorageUtil.SetStringValue(npc, "SeverTravel_State", "complete")
        SeverActionsNative.Native_SetTravelState(npc, "complete", "")
        StorageUtil.SetStringValue(npc, "SeverTravel_Result", "stay_ended")
        Debug.Notification(npc.GetDisplayName() + " has finished their business at " + place)
        _Teardown(npc, false)
    ElseIf status == "cancelled"
        ; A cancel no Papyrus caller tore down (the UI's "Turn back", Hearth's
        ; Travel_CancelByActor): restore, as CancelJourney's default does.
        _Teardown(npc, true)
    Else
        ; aborted | gaveup | timedout - a terminal failure of the walk; restore.
        Debug.Notification(npc.GetDisplayName() + " gave up traveling.")
        _Teardown(npc, true)
    EndIf
EndEvent

Function _OnArrivedWaiting(Actor akNPC, String asPlace)
    {Arrival into the wait: the walk's overrides give way to the arrival sandbox.}
    _RemoveTravelOverrides(akNPC)
    _ApplyArrivalSandbox(akNPC)
    StorageUtil.SetStringValue(akNPC, "SeverTravel_State", "waiting")
    SeverActionsNative.Native_SetTravelState(akNPC, "waiting", asPlace)
    Debug.Notification(akNPC.GetDisplayName() + " arrived at " + asPlace)
EndFunction

Function _ApplyArrivalSandbox(Actor akNPC)
    Package sandbox = StorageUtil.GetFormValue(akNPC, "SeverTravel_SandboxOverride") as Package
    Package defaultSandbox = Game.GetFormFromFile(FID_SANDBOX_PKG, "SeverActions.esp") as Package
    If !sandbox
        sandbox = defaultSandbox
    EndIf
    If sandbox
        ActorUtil.AddPackageOverride(akNPC, sandbox, TRAVEL_PACKAGE_PRIORITY, 1)
        ; The teardown strips the shared default only if this journey applied it
        ; (it is also Follow's manual-wait package).
        StorageUtil.SetIntValue(akNPC, "SeverTravel_SbxOwned", (sandbox == defaultSandbox) as Int)
    EndIf
    akNPC.EvaluatePackage()
EndFunction

Function _Teardown(Actor akNPC, Bool abRestoreFollower)
    {Undo everything a journey set. The shared default sandbox comes off only if this
     journey applied it and the actor is not in an SA wait hold (whose own teardown
     removes it).}
    If !akNPC
        Return
    EndIf
    _RemoveTravelOverrides(akNPC)
    Package defaultSandbox = Game.GetFormFromFile(FID_SANDBOX_PKG, "SeverActions.esp") as Package
    If defaultSandbox && StorageUtil.GetIntValue(akNPC, "SeverTravel_SbxOwned", 0) != 0
        If SeverActionsNativeExt.Native_GetSandboxing(akNPC)
            Debug.Trace("[SeverActions_TravelCore] " + akNPC.GetDisplayName() + " is in a wait hold - leaving the shared sandbox package to it")
        Else
            ActorUtil.RemovePackageOverride(akNPC, defaultSandbox)
        EndIf
    EndIf
    Package overridePkg = StorageUtil.GetFormValue(akNPC, "SeverTravel_SandboxOverride") as Package
    If overridePkg && overridePkg != defaultSandbox
        ActorUtil.RemovePackageOverride(akNPC, overridePkg)
    EndIf
    Keyword kw = Game.GetFormFromFile(FID_TRAVEL_TARGET_KW, "SeverActions.esp") as Keyword
    If kw
        SeverActionsNative.LinkedRef_Clear(akNPC, kw)
    EndIf
    SeverActionsNative.OrphanCleanup_UnregisterTraveler(akNPC)
    If abRestoreFollower && StorageUtil.GetIntValue(akNPC, "SeverTravel_WasFollower", 0) != 0
        _ReinstateAfterTrip(akNPC)
    EndIf
    _ClearJourneyKeys(akNPC)
    akNPC.EvaluatePackage()
EndFunction

Function _ClearJourneyKeys(Actor akNPC)
    StorageUtil.UnsetStringValue(akNPC, "SeverTravel_State")
    StorageUtil.UnsetStringValue(akNPC, "SeverTravel_Destination")
    SeverActionsNative.Native_SetTravelState(akNPC, "", "")
    StorageUtil.UnsetStringValue(akNPC, "SeverTravel_Result")
    StorageUtil.UnsetFormValue(akNPC, "SeverTravel_SandboxOverride")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_SbxOwned")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_WasFollower")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_Speed")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_Handle")
    StorageUtil.UnsetFloatValue(akNPC, "SeverTravel_GreetTime")
    StorageUtil.FormListRemove(None, GREET_PENDING_KEY, akNPC, true)
    ; Legacy slot keys an old save may still carry.
    StorageUtil.UnsetFloatValue(akNPC, "SeverTravel_WaitUntil")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_Slot")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_SpokenTo")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_Greeted")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_WaitForPlayer")
    StorageUtil.UnsetFloatValue(akNPC, "SeverTravel_ArrivedRT")
EndFunction

Function _RemoveTravelOverrides(Actor akNPC)
    {Remove every travel package override a journey may have added: the walk at any
     speed and the legacy CK pair an old save may carry.}
    Package p = Game.GetFormFromFile(FID_PKG_WALK, "SeverActions.esp") as Package
    If p
        ActorUtil.RemovePackageOverride(akNPC, p)
    EndIf
    p = Game.GetFormFromFile(FID_PKG_JOG, "SeverActions.esp") as Package
    If p
        ActorUtil.RemovePackageOverride(akNPC, p)
    EndIf
    p = Game.GetFormFromFile(FID_PKG_RUN, "SeverActions.esp") as Package
    If p
        ActorUtil.RemovePackageOverride(akNPC, p)
    EndIf
    p = Game.GetFormFromFile(FID_PKG_DEFAULT, "SeverActions.esp") as Package
    If p
        ActorUtil.RemovePackageOverride(akNPC, p)
    EndIf
    p = Game.GetFormFromFile(FID_PKG_LEGACY_WALK, "SeverActions.esp") as Package
    If p
        ActorUtil.RemovePackageOverride(akNPC, p)
    EndIf
    p = Game.GetFormFromFile(FID_PKG_LEGACY_RUN, "SeverActions.esp") as Package
    If p
        ActorUtil.RemovePackageOverride(akNPC, p)
    EndIf
EndFunction

; ── The follower for the trip ────────────────────────────────────────────────

Function _DismissForTrip(Actor akNPC)
    {Drop a follower for the trip and remember it. A follower SA does not lead
     (IsFollowHandsOff, D45) keeps the teammate flag - toggling it reads as a dismissal
     to their framework and TeammateMonitor - and is recorded as not-a-follower so the
     reinstatement leaves them alone.}
    Bool isFollower = akNPC.IsPlayerTeammate()
    Bool handsOff = SeverActions_ModuleBase.IsFollowHandsOff(akNPC)
    If handsOff
        StorageUtil.SetIntValue(akNPC, "SeverTravel_WasFollower", 0)
    Else
        StorageUtil.SetIntValue(akNPC, "SeverTravel_WasFollower", isFollower as Int)
    EndIf
    If isFollower
        If !handsOff
            akNPC.SetPlayerTeammate(false)
        EndIf
        ; SA's follow LinkedRef is left alone: no package reads it (see
        ; SeverActions_Follow.SeverActions_FollowerFollowKW).
        akNPC.EvaluatePackage()
    EndIf
EndFunction

Function _ReinstateAfterTrip(Actor akNPC)
    {Restore the teammate flag the trip dropped.}
    akNPC.SetPlayerTeammate(true)
    akNPC.EvaluatePackage()
EndFunction

; ── Greet-on-approach (the DLL detects, this script narrates) ──

Event OnTravelGreet(String eventName, String strArg, Float numArg, Form sender)
    {A waiting traveler spotted the player. strArg "caughtup" = within a minute of
     their arrival (the player was a few steps behind), else "waited". The chrono tick
     completes the wait once the line has played (GREET_LINE_SECONDS).}
    Actor npc = sender as Actor
    If !npc
        Return
    EndIf
    Actor player = Game.GetPlayer()
    String place = SeverActionsNativeExt2.Travel_GetPlaceLabelByActor(npc)
    String narration
    If strArg == "caughtup"
        narration = "*" + npc.GetDisplayName() + " reaches " + place + " just ahead of " + player.GetDisplayName() + ", and turns as they catch up*"
    Else
        narration = "*" + npc.GetDisplayName() + " spots " + player.GetDisplayName() + " coming into " + place + " and moves to meet them*"
    EndIf
    SkyrimNetApi.DirectNarration(narration, npc, player)
    StorageUtil.SetFloatValue(npc, "SeverTravel_GreetTime", Utility.GetCurrentRealTime())
    StorageUtil.FormListAdd(None, GREET_PENDING_KEY, npc, false)
    ChronoArm(3.0)
EndEvent

Function ChronoArm(Float afSeconds)
    {One-shot chronometer tick (never RegisterForSingleUpdate on the shared quest form),
     armed only while a greet plays out. Neither the tick nor a greet survives a load.}
    RegisterForModEvent("SeverActions_Tick_TravelCore", "OnChronoTick_TravelCore")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_TravelCore", afSeconds)
EndFunction

Event OnChronoTick_TravelCore(String eventName, String strArg, Float numArg, Form sender)
    Int n = StorageUtil.FormListCount(None, GREET_PENDING_KEY)
    Int i = n - 1
    While i >= 0
        Actor npc = StorageUtil.FormListGet(None, GREET_PENDING_KEY, i) as Actor
        Bool done = true
        If npc && SeverActionsNativeExt2.Travel_GetPhaseByActor(npc) == 2
            Float elapsed = Utility.GetCurrentRealTime() - StorageUtil.GetFloatValue(npc, "SeverTravel_GreetTime", 0.0)
            If elapsed < 0.0 || elapsed > 600.0
                ; Real time reset under us (a load between greet and now): re-seed.
                StorageUtil.SetFloatValue(npc, "SeverTravel_GreetTime", Utility.GetCurrentRealTime())
                done = false
            ElseIf Game.GetPlayer().GetParentCell() != npc.GetParentCell()
                ; The player left the cell: drop it; the DLL greets again on return.
                Debug.Trace("[SeverActions_TravelCore] " + npc.GetDisplayName() + "'s greet lapsed - the player left")
            ElseIf elapsed >= GREET_LINE_SECONDS && SkyrimNetApi.GetSpeechQueueSize() == 0
                SeverActionsNativeExt2.Travel_NotifySpokenTo(npc)
            Else
                done = false
            EndIf
        EndIf
        If done
            StorageUtil.FormListRemoveAt(None, GREET_PENDING_KEY, i)
            If npc
                StorageUtil.UnsetFloatValue(npc, "SeverTravel_GreetTime")
            EndIf
        EndIf
        i -= 1
    EndWhile
    If StorageUtil.FormListCount(None, GREET_PENDING_KEY) > 0
        ChronoArm(3.0)
    EndIf
EndEvent

; ── Wait pin Clear(): the DLL asks, the VM does it (a native null fill does not clear, F19) ──

Event OnTravelWaitPinClear(String eventName, String strArg, Float numArg, Form sender)
    {The DLL released wait pin numArg (alias ID 13..17). sender is the actor it
     expects there; anyone else holding it took the pin since and is left alone.}
    Int aliasId = numArg as Int
    If aliasId < WAIT_PIN_FIRST_ALIAS || aliasId >= WAIT_PIN_FIRST_ALIAS + WAIT_PIN_COUNT
        Return
    EndIf
    ReferenceAlias pin = (Self as Quest).GetAlias(aliasId) as ReferenceAlias
    If !pin
        Return
    EndIf
    Actor held = pin.GetActorReference()
    If !held
        Return
    EndIf
    Actor expected = sender as Actor
    If expected && held != expected
        Return
    EndIf
    ; Same actor, waiting again (a new wait re-claimed the pin, or the migration
    ; adopted it after the DLL's load sweep asked): keep it. A genuinely released
    ; wait is phase 0 by the time the ask lands.
    If SeverActionsNativeExt2.Travel_GetPhaseByActor(held) == 2
        Debug.Trace("[SeverActions_TravelCore] Wait pin " + aliasId + " clear skipped - " + held.GetDisplayName() + " waits there now")
        Return
    EndIf
    pin.Clear()
    held.EvaluatePackage()
    Debug.Trace("[SeverActions_TravelCore] Wait pin " + aliasId + " cleared (" + held.GetDisplayName() + ")")
EndEvent

Event OnInit()
    ; No setup here: existing saves never re-run OnInit (F6, DR20).
    Debug.Trace("[SeverActions] SeverActions_TravelCore: bound (the travel core, P8-01)")
EndEvent
