Scriptname SeverActions_Travel extends Quest

{
    NPC Travel & Errand System — v6 (orchestrator-driven)

    Travel-to-arrival is owned by the native TravelOrchestrator. This script
    handles the action entry points, the post-arrival sandbox/waiting/greet
    phase, follower bookkeeping, and MCM/PrismaUI introspection.

    Required CK Setup:
    - Create 5 ReferenceAliases named TravelAlias00 through TravelAlias04
    - Each alias should be Optional, Allow Reuse, Initially Cleared
    - Attach TravelPackage to each alias (Travel to LinkedRef with TravelTargetKeyword)
    - Attach SandboxPackage to each alias (Sandbox at current location)
    - Create TravelTargetKeyword for linked ref targeting
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
{Keyword used to link NPC to their travel destination via SetLinkedRef.}

Package Property TravelPackage Auto
{Default travel package (walk speed) - also used as fallback.}

Package Property TravelPackageWalk Auto
Package Property TravelPackageJog Auto
Package Property TravelPackageRun Auto

Package Property SandboxPackage Auto
{Sandbox package - applied when NPC arrives at destination.}

; =============================================================================
; SPEED CONSTANTS — mirror SeverActionsNative TravelSpeed enum
; =============================================================================

Int Property SPEED_WALK = 0 AutoReadOnly
Int Property SPEED_JOG = 1 AutoReadOnly
Int Property SPEED_RUN = 2 AutoReadOnly

; =============================================================================
; PROPERTIES - Settings
; =============================================================================

Float Property ArrivalDistance = 300.0 Auto
{Distance in units to consider NPC "arrived". Interior cells need larger values.}

Float Property UpdateInterval = 3.0 Auto
{How often to check waiting slots (seconds).}

Int Property TravelPackagePriority = 100 Auto
{Priority for travel/sandbox package overrides.}

Float Property DefaultWaitTime = 48.0 Auto
Float Property MinWaitTime = 6.0 Auto
Float Property MaxWaitTime = 168.0 Auto

Bool Property EnableDebugMessages = false Auto

; =============================================================================
; CONSTANTS
; =============================================================================

Int Property MAX_SLOTS = 5 AutoReadOnly

; Orchestrator option bitfield (see SeverActionsNative.psc TRAVEL ORCHESTRATOR
; comment block). 4 = kTravelOpt_AbortOnDegraded (recommended on).
Int Property TRAVEL_OPTIONS_DEFAULT = 4 AutoReadOnly

; =============================================================================
; TRACKING STATE
;
; Slots only track the *waiting* phase from the script's perspective — the
; orchestrator owns the *traveling* phase. SlotStates: 0=empty, 1=traveling
; (orchestrator handle in flight), 2=waiting (post-arrival sandbox).
; =============================================================================

Int[] SlotStates
String[] SlotPlaceNames
ObjectReference[] SlotDestinations
Float[] SlotWaitDeadlines
Int[] SlotSpeeds
Int[] SlotHandles  ; Orchestrator handle for slot's traveling phase (0 when not traveling)
; Per-slot post-arrival sandbox override (e.g. SeversHearth's CampSandboxPackage).
; None = OnArrived uses the default SandboxPackage property. Caller of
; TravelNPCToReference provides this when they want a destination-specific
; sandbox (camp, jail, festival, etc.) instead of the generic one.
Package[] SlotSandboxOverrides

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    DebugMsg("OnInit")
    InitializeSlotArrays()
    RegisterEvents()
    RegisterSpeedPackages()
    RegisterForSingleUpdate(UpdateInterval)
EndEvent

Event OnPlayerLoadGame()
    DebugMsg("OnPlayerLoadGame")

    If SlotStates == None || SlotStates.Length != MAX_SLOTS
        InitializeSlotArrays()
    EndIf

    ; Older saves predate SlotHandles — initialize the array if missing.
    If SlotHandles == None || SlotHandles.Length != MAX_SLOTS
        SlotHandles = new Int[5]
    EndIf
    ; Same for the per-slot sandbox override array (added with the SeversHearth
    ; integration so camp-bound followers get the camp sandbox, not SA's).
    If SlotSandboxOverrides == None || SlotSandboxOverrides.Length != MAX_SLOTS
        SlotSandboxOverrides = new Package[5]
    EndIf

    RegisterEvents()
    RegisterSpeedPackages()
    RecoverExistingTravelers()
    RegisterForSingleUpdate(UpdateInterval)
EndEvent

Function RegisterEvents()
    ; Orchestrator completion + PrismaUI controls. All ModEvent-based —
    ; DispatchMethodCall silently fails for cross-script signaling.
    RegisterForModEvent("SeverActions_TravelComplete", "OnTravelComplete")
    RegisterForModEvent("SeverActions_PrismaClearTravel", "OnPrismaClearTravel")
    RegisterForModEvent("SeverActions_PrismaResetTravel", "OnPrismaResetTravel")
EndFunction

Function RegisterSpeedPackages()
    ; Hand the speed packages to the orchestrator so other callers (PrismaUI,
    ; MCM, future natives) can resolve walk/jog/run without re-implementing
    ; the lookup. Idempotent — safe to call on every load.
    SeverActionsNativeExt.Travel_RegisterSpeedPackages(TravelPackageWalk, TravelPackageJog, TravelPackageRun, TravelPackage)
EndFunction

Function InitializeSlotArrays()
    SlotStates = new Int[5]
    SlotPlaceNames = new String[5]
    SlotDestinations = new ObjectReference[5]
    SlotWaitDeadlines = new Float[5]
    SlotSpeeds = new Int[5]
    SlotHandles = new Int[5]
    SlotSandboxOverrides = new Package[5]
    Int i = 0
    While i < MAX_SLOTS
        SlotPlaceNames[i] = ""
        i += 1
    EndWhile
EndFunction

Function RecoverExistingTravelers()
    ; On load: aliases still hold the actors, orchestrator cosave restored its
    ; TRVL records and re-applied LinkedRefs in plugin.cpp.
    ;
    ;  - Traveling slots: verify the orchestrator still has a live handle. If
    ;    yes, re-apply the speed package (PO3 overrides don't always survive
    ;    save/load cleanly). If no, clean the slot.
    ;  - Waiting slots: re-apply the sandbox package so the actor keeps sandboxing
    ;    after load. Wait deadline is already in StorageUtil.
    Int i = 0
    While i < MAX_SLOTS
        ReferenceAlias theAlias = GetAliasForSlot(i)
        If theAlias
            Actor npc = theAlias.GetActorReference()
            If npc && !npc.IsDead()
                If SlotStates[i] == 1
                    Int handle = SlotHandles[i]
                    If handle > 0 && SeverActionsNativeExt.Travel_IsActive(handle)
                        Package pkg = SeverActionsNativeExt.Travel_GetSpeedPackage(SlotSpeeds[i])
                        If pkg != None
                            ActorUtil.AddPackageOverride(npc, pkg, TravelPackagePriority, 1)
                            npc.EvaluatePackage()
                            DebugMsg("Recovered traveling slot " + i + " (handle=" + handle + ")")
                        EndIf
                    Else
                        DebugMsg("Slot " + i + " orchestrator handle lost — clearing")
                        ClearSlot(i, false)
                    EndIf
                ElseIf SlotStates[i] == 2
                    If SandboxPackage
                        ActorUtil.AddPackageOverride(npc, SandboxPackage, TravelPackagePriority, 1)
                        npc.EvaluatePackage()
                    EndIf
                    ; Clear any stale real-time greet baseline — see bug #2.
                    StorageUtil.UnsetIntValue(npc, "SeverTravel_Greeted")
                    StorageUtil.UnsetFloatValue(npc, "SeverTravel_GreetTime")
                    DebugMsg("Recovered waiting slot " + i)
                Else
                    ClearSlot(i, false)
                EndIf
            Else
                ; Empty/dead — zero out array entries without invoking ClearSlot
                ; (alias may already be empty; nothing to remove).
                SlotStates[i] = 0
                SlotPlaceNames[i] = ""
                SlotDestinations[i] = None
                SlotWaitDeadlines[i] = 0.0
                SlotSpeeds[i] = 0
                SlotHandles[i] = 0
            EndIf
        EndIf
        i += 1
    EndWhile
EndFunction

; =============================================================================
; ModEvent HANDLERS
; =============================================================================

Event OnTravelComplete(string eventName, string strArg, float numArg, Form sender)
    {Orchestrator completion. strArg = "<callbackTag>|<status>".
     Our callback tag is "slot_<n>" so we can route back to slot bookkeeping.}

    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String tag = StringUtil.Substring(strArg, 0, pipePos)
    String status = StringUtil.Substring(strArg, pipePos + 1, 0)

    If StringUtil.GetLength(tag) < 6 || StringUtil.Substring(tag, 0, 5) != "slot_"
        Return  ; Not one of ours — Arrest or future callers use different tags.
    EndIf
    Int slot = (StringUtil.Substring(tag, 5, 0)) as Int
    If slot < 0 || slot >= MAX_SLOTS
        Return
    EndIf

    Actor npc = sender as Actor
    DebugMsg("OnTravelComplete slot=" + slot + " status=" + status)

    ; Free the handle slot regardless — orchestrator is done with it.
    SlotHandles[slot] = 0

    If status == "arrived"
        If npc != None
            OnArrived(slot, npc, SlotPlaceNames[slot])
        Else
            ClearSlot(slot, true)
        EndIf
    ElseIf status == "cancelled"
        ; CancelTravel/CancelAllTravel path already cleared the slot — nothing to do.
    Else
        ; aborted | gaveup | timedout — terminal failure, restore follower.
        String npcName = "Traveler"
        If npc != None
            npcName = npc.GetDisplayName()
        EndIf
        NotifyPlayer(npcName + " gave up traveling.")
        ClearSlot(slot, true)
    EndIf
EndEvent

Event OnPrismaClearTravel(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: Clear a specific travel slot. strArg = "slotIndex|".}
    Int pipePos = StringUtil.Find(strArg, "|")
    Int slot = 0
    If pipePos >= 0
        slot = StringUtil.Substring(strArg, 0, pipePos) as Int
    EndIf
    ClearSlotFromMCM(slot)
EndEvent

Event OnPrismaResetTravel(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: Cancel all active travel.}
    CancelAllTravel()
EndEvent

; =============================================================================
; PLACE RESOLUTION
; =============================================================================

ObjectReference Function ResolvePlace(Actor akNPC, String placeName)
    {Native LocationResolver handles the full chain: semantic terms,
     city aliases, exact/editor-ID match, fuzzy, Levenshtein.}
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

ObjectReference Function ResolvePlaceLegacy(String placeName)
    {Legacy wrapper kept for any external script — prefer the actor-aware form.}
    Return ResolvePlace(Game.GetPlayer(), placeName)
EndFunction

; =============================================================================
; MAIN API
; =============================================================================

Bool Function TravelToPlace(Actor akNPC, String placeName, Float waitHours = 0.0, Bool stopFollowing = true, Int speed = 0)
    {Send an NPC to a named place. Returns true if travel started.
     speed: 0=walk, 1=jog, 2=run.}

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

    ; Clamp speed
    If speed < 0
        speed = 0
    ElseIf speed > 2
        speed = 2
    EndIf

    If !SeverActionsNative.IsLocationResolverReady()
        DebugMsg("TravelToPlace: LocationResolver not initialized")
        Return false
    EndIf

    ; Resolve BEFORE cancelling — a bad placeName must not nuke active travel.
    ObjectReference destMarker = ResolvePlace(akNPC, placeName)
    If destMarker == None
        Return false
    EndIf

    ; If destination is a door to an interior, follow through to the interior marker.
    ObjectReference finalDest = destMarker
    If destMarker.GetBaseObject().GetType() == 29
        ObjectReference interiorMarker = SeverActionsNative.FindInteriorMarkerForDoor(destMarker)
        If interiorMarker != None
            finalDest = interiorMarker
            DebugMsg("Door resolved to interior marker for '" + placeName + "'")
        EndIf
        ; Unlock the door so AI pathfinding isn't blocked.
        If destMarker.IsLocked()
            destMarker.Lock(false)
        EndIf
    EndIf

    ; Resolve the speed package BEFORE cancelling — if the package is missing
    ; (CK property not filled) we don't want to lose the current travel as a
    ; side effect of misconfiguration.
    Package travelPkg = SeverActionsNativeExt.Travel_GetSpeedPackage(speed)
    If travelPkg == None
        DebugMsg("TravelToPlace: no package for speed " + speed)
        Return false
    EndIf

    ; Now safe to cancel any existing travel for this NPC.
    CancelTravel(akNPC)

    Int slot = FindFreeSlot()
    If slot < 0
        DebugMsg("TravelToPlace: no free slots")
        Return false
    EndIf

    ReferenceAlias theAlias = GetAliasForSlot(slot)
    If theAlias == None
        DebugMsg("TravelToPlace: no alias for slot " + slot)
        Return false
    EndIf

    ; Wait deadline (uses default if 0)
    If waitHours <= 0.0
        waitHours = DefaultWaitTime
    EndIf
    waitHours = ClampFloat(waitHours, MinWaitTime, MaxWaitTime)
    Float waitUntil = Utility.GetCurrentGameTime() + (waitHours / 24.0)

    theAlias.ForceRefTo(akNPC)

    If stopFollowing
        DismissFollower(akNPC)
    EndIf

    ActorUtil.AddPackageOverride(akNPC, travelPkg, TravelPackagePriority, 1)

    ; Hand off to the orchestrator. callbackTag carries the slot index so
    ; OnTravelComplete can route back here. options=4 enables degraded-state abort.
    Int handle = SeverActionsNativeExt.Travel_Begin(akNPC, finalDest, TravelTargetKeyword, ArrivalDistance, "slot_" + slot, TRAVEL_OPTIONS_DEFAULT, 0, speed)
    If handle <= 0
        DebugMsg("TravelToPlace: orchestrator rejected (handle=0)")
        ActorUtil.RemovePackageOverride(akNPC, travelPkg)
        theAlias.Clear()
        Return false
    EndIf

    ; Record state
    SlotStates[slot] = 1
    SlotPlaceNames[slot] = placeName
    SlotDestinations[slot] = finalDest
    SlotWaitDeadlines[slot] = waitUntil
    SlotSpeeds[slot] = speed
    SlotHandles[slot] = handle

    StorageUtil.SetStringValue(akNPC, "SeverTravel_State", "traveling")
    StorageUtil.SetStringValue(akNPC, "SeverTravel_Destination", placeName)
    SeverActionsNative.Native_SetTravelState(akNPC, "traveling", placeName)
    StorageUtil.SetFloatValue(akNPC, "SeverTravel_WaitUntil", waitUntil)
    StorageUtil.SetIntValue(akNPC, "SeverTravel_Slot", slot)
    StorageUtil.SetIntValue(akNPC, "SeverTravel_Speed", speed)

    NotifyPlayer(akNPC.GetDisplayName() + " traveling to " + placeName)
    RegisterForSingleUpdate(UpdateInterval)
    Return true
EndFunction

Bool Function TravelNPCToReference(Actor akNPC, ObjectReference akDestination, Float waitHours = 0.0, Bool stopFollowing = false, Int speed = 1, Package akSandboxOverride = None)
    {Send an NPC directly to an ObjectReference destination (door, marker, NPC,
     follower's camp center, etc.). Skips name resolution. Orchestrator-driven
     equivalent of the old TravelToReference. Used by SeversHearth's GoToCamp
     and any other external caller routing by ref.
     speed: 0=walk, 1=jog (default), 2=run.
     akSandboxOverride: optional Package applied on arrival instead of the
     default SandboxPackage property. Lets the caller swap in a destination-
     specific sandbox (e.g. SeversHearth's CampSandboxPackage so the NPC
     joins the campfire crowd rather than sandboxing generically).}

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

    If speed < 0
        speed = 0
    ElseIf speed > 2
        speed = 2
    EndIf

    ; Door → interior marker (same handling as TravelToPlace).
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

    Package travelPkg = SeverActionsNativeExt.Travel_GetSpeedPackage(speed)
    If travelPkg == None
        DebugMsg("TravelNPCToReference: no package for speed " + speed)
        Return false
    EndIf

    CancelTravel(akNPC)

    Int slot = FindFreeSlot()
    If slot < 0
        DebugMsg("TravelNPCToReference: no free slots")
        Return false
    EndIf

    ReferenceAlias theAlias = GetAliasForSlot(slot)
    If theAlias == None
        Return false
    EndIf

    If waitHours <= 0.0
        waitHours = DefaultWaitTime
    EndIf
    waitHours = ClampFloat(waitHours, MinWaitTime, MaxWaitTime)
    Float waitUntil = Utility.GetCurrentGameTime() + (waitHours / 24.0)

    theAlias.ForceRefTo(akNPC)

    If stopFollowing
        DismissFollower(akNPC)
    EndIf

    ActorUtil.AddPackageOverride(akNPC, travelPkg, TravelPackagePriority, 1)

    Int handle = SeverActionsNativeExt.Travel_Begin(akNPC, finalDest, TravelTargetKeyword, ArrivalDistance, "slot_" + slot, TRAVEL_OPTIONS_DEFAULT, 0, speed)
    If handle <= 0
        DebugMsg("TravelNPCToReference: orchestrator rejected")
        ActorUtil.RemovePackageOverride(akNPC, travelPkg)
        theAlias.Clear()
        Return false
    EndIf

    SlotStates[slot] = 1
    SlotSandboxOverrides[slot] = akSandboxOverride
    ; Use a synthetic place label since ref-targeted travel has no user-facing name.
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
    SlotPlaceNames[slot] = label
    SlotDestinations[slot] = finalDest
    SlotWaitDeadlines[slot] = waitUntil
    SlotSpeeds[slot] = speed
    SlotHandles[slot] = handle

    StorageUtil.SetStringValue(akNPC, "SeverTravel_State", "traveling")
    StorageUtil.SetStringValue(akNPC, "SeverTravel_Destination", label)
    SeverActionsNative.Native_SetTravelState(akNPC, "traveling", label)
    StorageUtil.SetFloatValue(akNPC, "SeverTravel_WaitUntil", waitUntil)
    StorageUtil.SetIntValue(akNPC, "SeverTravel_Slot", slot)
    StorageUtil.SetIntValue(akNPC, "SeverTravel_Speed", speed)

    RegisterForSingleUpdate(UpdateInterval)
    Return true
EndFunction

; =============================================================================
; ARRIVAL / WAITING
; =============================================================================

Function OnArrived(Int slot, Actor akNPC, String placeName)
    {Called from OnTravelComplete with status "arrived". Apply sandbox and
     transition the slot to waiting state.}

    RemoveAllTravelPackages(akNPC)

    If TravelTargetKeyword
        ObjectReference dest = SlotDestinations[slot]
        If dest != None
            SeverActionsNative.LinkedRef_Set(akNPC, dest, TravelTargetKeyword)
        EndIf
    EndIf

    ; Sandbox override (per-slot) wins over the default SandboxPackage so a
    ; camp-bound follower joins the campfire crowd rather than picking SA's
    ; generic sandbox. Falls through to SandboxPackage when no override set.
    Package sandboxToApply = SlotSandboxOverrides[slot]
    If sandboxToApply == None
        sandboxToApply = SandboxPackage
    EndIf
    If sandboxToApply
        ActorUtil.AddPackageOverride(akNPC, sandboxToApply, TravelPackagePriority, 1)
    EndIf
    akNPC.EvaluatePackage()

    SlotStates[slot] = 2
    SlotHandles[slot] = 0
    StorageUtil.SetStringValue(akNPC, "SeverTravel_State", "waiting")
    SeverActionsNative.Native_SetTravelState(akNPC, "waiting", placeName)

    NotifyPlayer(akNPC.GetDisplayName() + " arrived at " + placeName)
    RegisterForSingleUpdate(UpdateInterval)
EndFunction

Function CheckWaitingSlot(Int slot)
    {Polls a waiting slot for player arrival or timeout. The greet-on-approach
     flow uses real-time elapsed for the SkyrimNet dialogue gap; we sanity-
     check it against save/load resets.}

    ReferenceAlias theAlias = GetAliasForSlot(slot)
    If theAlias == None
        ClearSlot(slot)
        Return
    EndIf

    Actor npc = theAlias.GetActorReference()
    If npc == None || npc.IsDead()
        ClearSlot(slot)
        Return
    EndIf

    Float currentTime = Utility.GetCurrentGameTime()
    Float deadline = SlotWaitDeadlines[slot]
    String placeName = SlotPlaceNames[slot]

    ; --- Check 1: external SpokenTo flag ---
    Bool spokenTo = StorageUtil.GetIntValue(npc, "SeverTravel_SpokenTo") as Bool
    If spokenTo
        StorageUtil.UnsetIntValue(npc, "SeverTravel_SpokenTo")
        StorageUtil.UnsetIntValue(npc, "SeverTravel_Greeted")
        OnPlayerArrived(slot, npc)
        Return
    EndIf

    ; --- Check 2: detect player proximity, trigger SkyrimNet greeting ---
    Actor player = Game.GetPlayer()
    If player != None
        Cell playerCell = player.GetParentCell()
        Cell npcCell = npc.GetParentCell()

        If playerCell != None && npcCell != None && playerCell == npcCell
            Float dist = npc.GetDistance(player as ObjectReference)
            Int greetedState = StorageUtil.GetIntValue(npc, "SeverTravel_Greeted")

            If greetedState == 0 && dist <= 300.0 && npc.HasLOS(player as ObjectReference)
                StorageUtil.SetIntValue(npc, "SeverTravel_Greeted", 1)
                StorageUtil.SetFloatValue(npc, "SeverTravel_GreetTime", Utility.GetCurrentRealTime())
                String narration = "*" + npc.GetDisplayName() + " notices the player approaching and turns to greet them, having been waiting here in " + placeName + "*"
                SkyrimNetApi.DirectNarration(narration, npc, player)
                Return
            EndIf

            If greetedState == 1
                Float greetTime = StorageUtil.GetFloatValue(npc, "SeverTravel_GreetTime")
                Float elapsed = Utility.GetCurrentRealTime() - greetTime

                ; GetCurrentRealTime is process-uptime — it resets on game load.
                ; A save/load between greet and arrival makes elapsed negative or
                ; bogus-large; re-seed and try again next tick.
                If elapsed < 0.0 || elapsed > 600.0
                    StorageUtil.SetFloatValue(npc, "SeverTravel_GreetTime", Utility.GetCurrentRealTime())
                    Return
                EndIf

                If elapsed >= 12.0
                    Int queueSize = SkyrimNetApi.GetSpeechQueueSize()
                    If queueSize == 0
                        StorageUtil.UnsetIntValue(npc, "SeverTravel_Greeted")
                        StorageUtil.UnsetFloatValue(npc, "SeverTravel_GreetTime")
                        OnPlayerArrived(slot, npc)
                        Return
                    EndIf
                EndIf
            EndIf
        Else
            ; Player left the cell — reset greet state so it fires again on return.
            If StorageUtil.GetIntValue(npc, "SeverTravel_Greeted") > 0
                StorageUtil.UnsetIntValue(npc, "SeverTravel_Greeted")
                StorageUtil.UnsetFloatValue(npc, "SeverTravel_GreetTime")
            EndIf
        EndIf
    EndIf

    ; --- Check 3: timeout ---
    If currentTime >= deadline
        StorageUtil.UnsetIntValue(npc, "SeverTravel_Greeted")
        StorageUtil.UnsetFloatValue(npc, "SeverTravel_GreetTime")
        OnWaitTimeout(slot, npc)
    EndIf
EndFunction

Function OnPlayerArrived(Int slot, Actor akNPC)
    StorageUtil.SetStringValue(akNPC, "SeverTravel_State", "complete")
    SeverActionsNative.Native_SetTravelState(akNPC, "complete", "")
    StorageUtil.SetStringValue(akNPC, "SeverTravel_Result", "player_arrived")
    NotifyPlayer(akNPC.GetDisplayName() + " is glad to see you!")
    ClearSlot(slot, true)
EndFunction

Function NotifyTravelSpokenTo(Actor akNPC)
    {External-facing: tag a traveling NPC as having been spoken to. The next
     CheckWaitingSlot tick will complete the travel.}
    If akNPC == None
        Return
    EndIf
    Int slot = FindSlotByActor(akNPC)
    If slot >= 0 && SlotStates[slot] == 2
        StorageUtil.SetIntValue(akNPC, "SeverTravel_SpokenTo", 1)
    EndIf
EndFunction

Function OnWaitTimeout(Int slot, Actor akNPC)
    StorageUtil.SetStringValue(akNPC, "SeverTravel_State", "timeout")
    SeverActionsNative.Native_SetTravelState(akNPC, "timeout", "")
    StorageUtil.SetStringValue(akNPC, "SeverTravel_Result", "timeout")
    NotifyPlayer(akNPC.GetDisplayName() + "'s patience ran out!")
    ClearSlot(slot, false)
EndFunction

; =============================================================================
; UPDATE LOOP — waiting slots only
; =============================================================================

Event OnUpdate()
    Bool hasWaiting = false
    Int i = 0
    While i < MAX_SLOTS
        If SlotStates[i] == 2
            CheckWaitingSlot(i)
            hasWaiting = true
        EndIf
        i += 1
    EndWhile
    If hasWaiting
        RegisterForSingleUpdate(UpdateInterval)
    EndIf
EndEvent

; =============================================================================
; SLOT MANAGEMENT
; =============================================================================

ReferenceAlias Function GetAliasForSlot(Int slot)
    If slot == 0
        Return TravelAlias00
    ElseIf slot == 1
        Return TravelAlias01
    ElseIf slot == 2
        Return TravelAlias02
    ElseIf slot == 3
        Return TravelAlias03
    ElseIf slot == 4
        Return TravelAlias04
    EndIf
    Return None
EndFunction

Int Function FindFreeSlot()
    Int i = 0
    While i < MAX_SLOTS
        If SlotStates[i] == 0
            Return i
        EndIf
        i += 1
    EndWhile
    Return -1
EndFunction

Int Function FindSlotByActor(Actor akNPC)
    If akNPC == None
        Return -1
    EndIf
    Int i = 0
    While i < MAX_SLOTS
        If SlotStates[i] != 0
            ReferenceAlias theAlias = GetAliasForSlot(i)
            If theAlias && theAlias.GetActorReference() == akNPC
                Return i
            EndIf
        EndIf
        i += 1
    EndWhile
    Return -1
EndFunction

Function ClearSlot(Int slot, Bool restoreFollower = false)
    {Tear down a slot. Cancels any active orchestrator handle, removes packages,
     restores follower if requested, clears all SeverTravel_* StorageUtil keys,
     and releases the alias.}

    If slot < 0 || slot >= MAX_SLOTS
        Return
    EndIf

    Int handle = SlotHandles[slot]
    If handle > 0
        SeverActionsNativeExt.Travel_Cancel(handle)
    EndIf

    ReferenceAlias theAlias = GetAliasForSlot(slot)
    If theAlias
        Actor npc = theAlias.GetActorReference()
        If npc
            RemoveAllTravelPackages(npc)
            If SandboxPackage
                ActorUtil.RemovePackageOverride(npc, SandboxPackage)
            EndIf
            ; Also remove any per-slot sandbox override (set by
            ; TravelNPCToReference callers like SeversHearth's GoToCamp).
            ; Safe-call — RemovePackageOverride no-ops if the actor never had it.
            Package overridePkg = SlotSandboxOverrides[slot]
            If overridePkg
                ActorUtil.RemovePackageOverride(npc, overridePkg)
            EndIf
            If TravelTargetKeyword
                SeverActionsNative.LinkedRef_Clear(npc, TravelTargetKeyword)
            EndIf

            If restoreFollower
                Bool wasFollower = StorageUtil.GetIntValue(npc, "SeverTravel_WasFollower") as Bool
                If wasFollower
                    ReinstateFollower(npc)
                EndIf
            EndIf

            ClearTravelStorage(npc)
            npc.EvaluatePackage()
        EndIf
        theAlias.Clear()
    EndIf

    SlotStates[slot] = 0
    SlotPlaceNames[slot] = ""
    SlotDestinations[slot] = None
    SlotWaitDeadlines[slot] = 0.0
    SlotSpeeds[slot] = 0
    SlotHandles[slot] = 0
    SlotSandboxOverrides[slot] = None
EndFunction

Function ClearTravelStorage(Actor akNPC)
    {Single source of truth for tearing down the SeverTravel_* StorageUtil keys.
     ClearSlot and any cleanup paths route through here so we don't drift.}
    StorageUtil.UnsetStringValue(akNPC, "SeverTravel_State")
    StorageUtil.UnsetStringValue(akNPC, "SeverTravel_Destination")
    SeverActionsNative.Native_SetTravelState(akNPC, "", "")
    StorageUtil.UnsetStringValue(akNPC, "SeverTravel_Result")
    StorageUtil.UnsetFloatValue(akNPC, "SeverTravel_WaitUntil")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_Slot")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_WasFollower")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_Speed")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_SpokenTo")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_Greeted")
    StorageUtil.UnsetFloatValue(akNPC, "SeverTravel_GreetTime")
EndFunction

Function ForceResetAllSlots(Bool restoreFollowers = true)
    {Emergency reset — cancel every orchestrator handle and tear down every slot.}
    DebugMsg("=== FORCE RESET ALL SLOTS ===")
    NotifyPlayer("Resetting all travel slots...")
    Int i = 0
    While i < MAX_SLOTS
        ClearSlot(i, restoreFollowers)
        i += 1
    EndWhile
    DebugMsg("=== FORCE RESET COMPLETE ===")
    NotifyPlayer("All travel slots have been reset.")
EndFunction

Int Function GetActiveTravelCount()
    Int count = 0
    Int i = 0
    While i < MAX_SLOTS
        If SlotStates[i] != 0
            count += 1
        EndIf
        i += 1
    EndWhile
    Return count
EndFunction

Int Function GetSlotState(Int slot)
    If slot < 0 || slot >= MAX_SLOTS
        Return 0
    EndIf
    Return SlotStates[slot]
EndFunction

Function ClearSlotFromMCM(Int slot, Bool restoreFollower = true)
    If slot < 0 || slot >= MAX_SLOTS
        Return
    EndIf
    If SlotStates[slot] == 0
        Return
    EndIf
    ReferenceAlias theAlias = GetAliasForSlot(slot)
    If theAlias
        Actor npc = theAlias.GetActorReference()
        If npc
            NotifyPlayer("Clearing travel for " + npc.GetDisplayName())
        EndIf
    EndIf
    ClearSlot(slot, restoreFollower)
EndFunction

String Function GetSlotDestination(Int slot)
    If slot < 0 || slot >= MAX_SLOTS
        Return ""
    EndIf
    Return SlotPlaceNames[slot]
EndFunction

String Function GetSlotStatusText(Int slot)
    If slot < 0 || slot >= MAX_SLOTS
        Return "Invalid"
    EndIf
    If SlotStates == None || SlotStates.Length == 0
        Return "NOT INITIALIZED"
    EndIf
    If SlotStates[slot] == 1
        If SlotPlaceNames[slot] != ""
            Return "Traveling: " + SlotPlaceNames[slot]
        EndIf
        Return "Traveling (unknown)"
    ElseIf SlotStates[slot] == 2
        If SlotPlaceNames[slot] != ""
            Return "Waiting: " + SlotPlaceNames[slot]
        EndIf
        Return "Waiting (unknown)"
    ElseIf SlotStates[slot] != 0
        Return "UNKNOWN: " + SlotStates[slot]
    EndIf
    Return "Empty"
EndFunction

; =============================================================================
; CANCEL
; =============================================================================

Function CancelTravel(Actor akNPC, Bool restoreFollower = true)
    {Cancel travel for one NPC. Routes through the slot if found; falls back to
     orchestrator-by-actor to catch any non-slot session.}
    If akNPC == None
        Return
    EndIf
    Int slot = FindSlotByActor(akNPC)
    If slot >= 0
        ClearSlot(slot, restoreFollower)
    Else
        ; Defensive — catch any stray orchestrator session not tracked locally.
        SeverActionsNativeExt.Travel_CancelByActor(akNPC)
    EndIf
EndFunction

Function CancelAllTravel(Bool restoreFollowers = true)
    Int i = 0
    While i < MAX_SLOTS
        If SlotStates[i] != 0
            ClearSlot(i, restoreFollowers)
        EndIf
        i += 1
    EndWhile
EndFunction

; =============================================================================
; SPEED CONTROL
; =============================================================================

Bool Function SetTravelSpeed(Actor akNPC, Int speed)
    {Change speed mid-journey. Updates both the package override and the
     orchestrator's catch-up estimator.}
    If akNPC == None
        Return false
    EndIf
    Int slot = FindSlotByActor(akNPC)
    If slot < 0
        Return false
    EndIf
    If SlotStates[slot] != 1
        Return false
    EndIf
    If speed < 0
        speed = 0
    ElseIf speed > 2
        speed = 2
    EndIf
    If SlotSpeeds[slot] == speed
        Return true
    EndIf

    Package newPkg = SeverActionsNativeExt.Travel_GetSpeedPackage(speed)
    If newPkg == None
        DebugMsg("SetTravelSpeed: no package for speed " + speed)
        Return false
    EndIf

    Package oldPkg = SeverActionsNativeExt.Travel_GetSpeedPackage(SlotSpeeds[slot])
    If oldPkg != None
        ActorUtil.RemovePackageOverride(akNPC, oldPkg)
    EndIf
    ActorUtil.AddPackageOverride(akNPC, newPkg, TravelPackagePriority, 1)
    akNPC.EvaluatePackage()

    SlotSpeeds[slot] = speed
    StorageUtil.SetIntValue(akNPC, "SeverTravel_Speed", speed)
    If SlotHandles[slot] > 0
        SeverActionsNativeExt.Travel_SetSpeed(SlotHandles[slot], speed)
    EndIf
    Return true
EndFunction

Bool Function SetTravelSpeedNatural(Actor akNPC, String speedText)
    Return SetTravelSpeed(akNPC, SeverActionsNativeExt.Travel_ParseSpeedFromText(speedText))
EndFunction

Package Function GetTravelPackageForSpeed(Int speed)
    Return SeverActionsNativeExt.Travel_GetSpeedPackage(speed)
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
EndFunction

String Function GetSpeedName(Int speed)
    Return SeverActionsNativeExt.Travel_GetSpeedName(speed)
EndFunction

Int Function GetTravelSpeed(Actor akNPC)
    If akNPC == None
        Return -1
    EndIf
    Int slot = FindSlotByActor(akNPC)
    If slot < 0
        Return -1
    EndIf
    Return SlotSpeeds[slot]
EndFunction

; =============================================================================
; FOLLOWERS
; =============================================================================

Function DismissFollower(Actor akNPC)
    Bool isFollower = akNPC.IsPlayerTeammate()
    StorageUtil.SetIntValue(akNPC, "SeverTravel_WasFollower", isFollower as Int)
    If isFollower
        akNPC.SetPlayerTeammate(false)
        akNPC.EvaluatePackage()
    EndIf
EndFunction

Function ReinstateFollower(Actor akNPC)
    akNPC.SetPlayerTeammate(true)
    akNPC.EvaluatePackage()
EndFunction

; =============================================================================
; UTILITIES
; =============================================================================

Function DebugMsg(String msg)
    Debug.Trace("SeverTravel: " + msg)
    If EnableDebugMessages
        Debug.Notification("Travel: " + msg)
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

; =============================================================================
; DEBUG / TESTING
; =============================================================================

Function TestMarkerResolution(String placeName)
    DebugMsg("Testing resolution for: " + placeName)
    If !SeverActionsNative.IsLocationResolverReady()
        DebugMsg("FAIL: LocationResolver not initialized")
        Return
    EndIf
    ObjectReference marker = SeverActionsNative.ResolveDestination(Game.GetPlayer(), placeName)
    If marker == None
        DebugMsg("FAIL: Could not resolve '" + placeName + "'")
        Return
    EndIf
    DebugMsg("SUCCESS: " + marker)
EndFunction

Function ShowStatus()
    DebugMsg("=== Travel System Status ===")
    DebugMsg("LocationResolver ready: " + SeverActionsNative.IsLocationResolverReady())
    DebugMsg("Orchestrator active: " + SeverActionsNativeExt.Travel_GetActiveCount())
    Int i = 0
    Int activeCount = 0
    While i < MAX_SLOTS
        If SlotStates[i] != 0
            activeCount += 1
            ReferenceAlias theAlias = GetAliasForSlot(i)
            String npcName = "None"
            If theAlias
                Actor npc = theAlias.GetActorReference()
                If npc
                    npcName = npc.GetDisplayName()
                EndIf
            EndIf
            String stateStr = "unknown"
            If SlotStates[i] == 1
                stateStr = "traveling"
            ElseIf SlotStates[i] == 2
                stateStr = "waiting"
            EndIf
            DebugMsg("Slot " + i + ": " + npcName + " - " + stateStr + " @ " + SlotPlaceNames[i] + " (handle=" + SlotHandles[i] + ")")
        EndIf
        i += 1
    EndWhile
    DebugMsg("Active slots: " + activeCount + "/" + MAX_SLOTS)
EndFunction

Bool Function IsNPCTraveling(Actor akNPC)
    Return FindSlotByActor(akNPC) >= 0
EndFunction

String Function GetNPCTravelState(Actor akNPC)
    Int slot = FindSlotByActor(akNPC)
    If slot < 0
        Return ""
    EndIf
    If SlotStates[slot] == 1
        Return "traveling"
    ElseIf SlotStates[slot] == 2
        Return "waiting"
    EndIf
    Return ""
EndFunction
