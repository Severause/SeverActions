Scriptname SeverActions_Travel extends Quest

{
    NPC Travel & Errand System v5 - Native Location Resolution

    Uses quest aliases for reliable cross-cell travel and interior sandboxing.
    NPCs are held in aliases for the entire journey (travel -> arrive -> sandbox -> complete).

    Features:
    - Alias-based persistence (NPCs don't get lost in unloaded cells)
    - Native location resolution via DLL (scans all cells/locations at game load)
    - Semantic terms: "outside", "inside", "upstairs", "downstairs"
    - Fuzzy matching with Levenshtein distance for typo tolerance
    - Stuck detection with progressive recovery (nudge -> leapfrog -> teleport)
    - Follower temporary dismissal for errands
    - Wait timers with consequences for player being late

    Required CK Setup:
    - Create 5 ReferenceAliases named TravelAlias00 through TravelAlias04
    - Each alias should be Optional, Allow Reuse, Initially Cleared
    - Attach TravelPackage to each alias (Travel to LinkedRef with TravelTargetKeyword)
    - Attach SandboxPackage to each alias (Sandbox at current location, shorter radius)
    - Create TravelTargetKeyword for linked ref targeting
}

; =============================================================================
; PROPERTIES - Aliases (Fill these in CK)
; =============================================================================

ReferenceAlias Property TravelAlias00 Auto
ReferenceAlias Property TravelAlias01 Auto
ReferenceAlias Property TravelAlias02 Auto
ReferenceAlias Property TravelAlias03 Auto
ReferenceAlias Property TravelAlias04 Auto

; =============================================================================
; PROPERTIES - Packages & Keywords (Create in CK)
; =============================================================================

Keyword Property TravelTargetKeyword Auto
{Keyword used to link NPC to their travel destination via SetLinkedRef}

Package Property TravelPackage Auto
{Default travel package (walk speed) - also used as fallback}

Package Property TravelPackageWalk Auto
{Travel package - walking speed}

Package Property TravelPackageJog Auto
{Travel package - jogging speed}

Package Property TravelPackageRun Auto
{Travel package - running speed}

Package Property SandboxPackage Auto
{Sandbox package - applied when NPC arrives at destination}

; =============================================================================
; SPEED CONSTANTS
; =============================================================================

Int Property SPEED_WALK = 0 AutoReadOnly
Int Property SPEED_JOG = 1 AutoReadOnly
Int Property SPEED_RUN = 2 AutoReadOnly

; =============================================================================
; PROPERTIES - Settings
; =============================================================================

Float Property ArrivalDistance = 300.0 Auto
{Distance in units to consider NPC "arrived" at destination. Interior cells need larger values.}

Float Property UpdateInterval = 3.0 Auto
{How often to check for arrivals (seconds). Lower = more responsive, higher = better performance.}

Int Property TravelPackagePriority = 100 Auto
{Priority for travel/sandbox packages. Higher overrides lower.}

; Timing defaults (in game hours)
Float Property DefaultWaitTime = 48.0 Auto
{Default time NPC will wait for player (game hours). 48 = 2 days.}

Float Property MinWaitTime = 6.0 Auto
{Minimum wait time (game hours).}

Float Property MaxWaitTime = 168.0 Auto
{Maximum wait time (game hours). 168 = 1 week.}

Bool Property EnableDebugMessages = false Auto
{Show debug notifications in-game. Disable for release.}

; =============================================================================
; CONSTANTS
; =============================================================================

Int Property MAX_SLOTS = 5 AutoReadOnly
{Maximum concurrent travelers. Must match number of aliases.}

; =============================================================================
; DATABASE STATE
; =============================================================================

; Native LocationResolver auto-initializes on kDataLoaded in the DLL
; No JSON loading needed - scans all TESObjectCELL and BGSLocation records

; =============================================================================
; TRACKING STATE
; Each index corresponds to an alias slot (0-4)
; =============================================================================

; Slot state: 0 = empty, 1 = traveling, 2 = arrived/sandboxing
Int[] SlotStates
String[] SlotPlaceNames
ObjectReference[] SlotDestinations
Float[] SlotWaitDeadlines
Int[] SlotSpeeds  ; Current speed: 0 = walk, 1 = jog, 2 = run
Bool[] SlotExternalManaged  ; If true, skip arrival detection - caller handles it via CancelTravel
Float[] SlotTravelStartTimes  ; Game time when travel started (for time-skip detection)
Float[] SlotInitialDistances  ; Distance (units) between NPC and dest at travel start (for time-skip calc when cross-cell)

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    DebugMsg("OnInit called")
    InitializeSlotArrays()
    ; Native LocationResolver auto-initializes on kDataLoaded
    RegisterForSingleUpdate(UpdateInterval)
EndEvent

Event OnPlayerLoadGame()
    DebugMsg("OnPlayerLoadGame called")

    ; Only initialize arrays if they're invalid - don't wipe existing data
    If SlotStates == None || SlotStates.Length != MAX_SLOTS
        DebugMsg("Arrays invalid on load - initializing fresh")
        InitializeSlotArrays()
    EndIf

    ; Handle upgrade from saves that don't have the new arrays
    If SlotExternalManaged == None || SlotExternalManaged.Length != MAX_SLOTS
        SlotExternalManaged = new Bool[5]
        Int emIdx = 0
        While emIdx < MAX_SLOTS
            SlotExternalManaged[emIdx] = false
            emIdx += 1
        EndWhile
        DebugMsg("Initialized SlotExternalManaged array (upgrade from older save)")
    EndIf

    If SlotTravelStartTimes == None || SlotTravelStartTimes.Length != MAX_SLOTS
        SlotTravelStartTimes = new Float[5]
        Int stIdx = 0
        While stIdx < MAX_SLOTS
            SlotTravelStartTimes[stIdx] = 0.0
            stIdx += 1
        EndWhile
        DebugMsg("Initialized SlotTravelStartTimes array (upgrade from older save)")
    EndIf

    If SlotInitialDistances == None || SlotInitialDistances.Length != MAX_SLOTS
        SlotInitialDistances = new Float[5]
        Int sdIdx = 0
        While sdIdx < MAX_SLOTS
            SlotInitialDistances[sdIdx] = 0.0
            sdIdx += 1
        EndWhile
        DebugMsg("Initialized SlotInitialDistances array (upgrade from older save)")
    EndIf

    RecoverExistingTravelers()
    RegisterForSingleUpdate(UpdateInterval)
EndEvent

Function InitializeSlotArrays()
    SlotStates = new Int[5]
    SlotPlaceNames = new String[5]
    SlotDestinations = new ObjectReference[5]
    SlotWaitDeadlines = new Float[5]
    SlotSpeeds = new Int[5]
    SlotExternalManaged = new Bool[5]
    SlotTravelStartTimes = new Float[5]
    SlotInitialDistances = new Float[5]

    ; Initialize all to empty
    Int i = 0
    While i < MAX_SLOTS
        SlotStates[i] = 0
        SlotPlaceNames[i] = ""
        SlotDestinations[i] = None
        SlotWaitDeadlines[i] = 0.0
        SlotSpeeds[i] = 0
        SlotExternalManaged[i] = false
        SlotTravelStartTimes[i] = 0.0
        SlotInitialDistances[i] = 0.0
        i += 1
    EndWhile
EndFunction

Function RecoverExistingTravelers()
    ; On game load, check if any aliases still have actors and recover their state
    Int i = 0
    ReferenceAlias theAlias
    Actor npc
    String npcState
    
    While i < MAX_SLOTS
        theAlias = GetAliasForSlot(i)
        If theAlias
            npc = theAlias.GetActorReference()
            If npc && !npc.IsDead()
                ; Recover state from StorageUtil
                npcState = StorageUtil.GetStringValue(npc, "SeverTravel_State")
                If npcState == "traveling"
                    SlotStates[i] = 1
                    SlotPlaceNames[i] = StorageUtil.GetStringValue(npc, "SeverTravel_Destination")
                    ; Destination marker can't be recovered easily, but we can get location
                    DebugMsg("Recovered traveling NPC in slot " + i + ": " + npc.GetDisplayName())
                ElseIf npcState == "waiting"
                    SlotStates[i] = 2
                    SlotPlaceNames[i] = StorageUtil.GetStringValue(npc, "SeverTravel_Destination")
                    SlotWaitDeadlines[i] = StorageUtil.GetFloatValue(npc, "SeverTravel_WaitUntil")
                    DebugMsg("Recovered waiting NPC in slot " + i + ": " + npc.GetDisplayName())
                Else
                    ; Unknown state, clear the slot
                    DebugMsg("Unknown state '" + npcState + "' for slot " + i + ", clearing")
                    ClearSlot(i)
                EndIf
            Else
                ; Empty or dead, clear slot
                DebugMsg("Slot " + i + " has empty or dead NPC, clearing")
                ClearSlot(i)
            EndIf
        Else
            ; Alias itself is None - ensure slot state is cleared
            DebugMsg("Slot " + i + " alias is None, ensuring clean state")
            SlotStates[i] = 0
            SlotPlaceNames[i] = ""
            SlotDestinations[i] = None
            SlotWaitDeadlines[i] = 0.0
            SlotSpeeds[i] = 0
            SlotExternalManaged[i] = false
        EndIf
        i += 1
    EndWhile
EndFunction

; =============================================================================
; DATABASE - Native LocationResolver (auto-initialized by DLL)
; =============================================================================

Function ForceReloadDatabase()
    {Legacy compatibility stub - database is now auto-initialized by native DLL on kDataLoaded.
    Scans all TESObjectCELL and BGSLocation records for O(1) lookup.}

    If SeverActionsNative.IsLocationResolverReady()
        Int count = SeverActionsNative.GetLocationCount()
        DebugMsg("Native LocationResolver ready: " + count + " locations indexed")
    Else
        DebugMsg("WARNING: Native LocationResolver not yet initialized")
    EndIf
EndFunction

; =============================================================================
; MAIN API - TravelToPlace
; =============================================================================

Bool Function TravelToPlace(Actor akNPC, String placeName, Float waitHours = 0.0, Bool stopFollowing = true, Int speed = 0)
    {Send an NPC to a named place. Returns true if travel started successfully.
     speed: 0 = walk (default), 1 = jog, 2 = run}
    
    ; Validate inputs
    If akNPC == None
        DebugMsg("ERROR: TravelToPlace called with None actor")
        Return false
    EndIf
    
    If akNPC.IsDead()
        DebugMsg("ERROR: Cannot send dead NPC to travel")
        Return false
    EndIf
    
    If placeName == ""
        DebugMsg("ERROR: Empty place name")
        Return false
    EndIf
    
    ; Clamp speed to valid range
    If speed < 0
        speed = 0
    ElseIf speed > 2
        speed = 2
    EndIf
    
    ; Check native LocationResolver is ready
    If !SeverActionsNative.IsLocationResolverReady()
        DebugMsg("ERROR: Native LocationResolver not initialized")
        Return false
    EndIf

    ; Cancel any existing travel for this NPC
    CancelTravel(akNPC)

    ; Find a free alias slot
    Int slot = FindFreeSlot()
    If slot < 0
        DebugMsg("ERROR: No free travel slots available")
        Return false
    EndIf

    ; Resolve place name to destination using native LocationResolver
    ; Supports exact names, city aliases, fuzzy matching, and semantic terms
    ObjectReference destMarker = ResolvePlace(akNPC, placeName)
    If destMarker == None
        DebugMsg("ERROR: Unknown place '" + placeName + "'")
        Return false
    EndIf

    ; If destination is a door to an interior, resolve to the interior marker directly.
    ; The NPC's AI will pathfind through doors automatically to reach the interior marker.
    ; This avoids all cross-cell GetDistance issues that occur when targeting an exterior door.
    ObjectReference finalDest = destMarker
    If destMarker.GetBaseObject().GetType() == 29
        ObjectReference interiorMarker = SeverActionsNative.FindInteriorMarkerForDoor(destMarker)
        If interiorMarker != None
            finalDest = interiorMarker
            DebugMsg("Resolved door to interior marker for '" + placeName + "'")
        Else
            DebugMsg("Door destination '" + placeName + "' has no interior marker, using door directly")
        EndIf
        ; Unlock the door so AI pathfinding isn't blocked by locked doors
        If destMarker.IsLocked()
            destMarker.Lock(false)
            DebugMsg("Unlocked door for travel to '" + placeName + "'")
        EndIf
    EndIf

    NotifyPlayer(akNPC.GetDisplayName() + " traveling to " + placeName)

    ; Stop following if requested
    If stopFollowing
        DismissFollower(akNPC)
    EndIf

    ; Calculate wait deadline
    If waitHours <= 0.0
        waitHours = DefaultWaitTime
    EndIf
    waitHours = ClampFloat(waitHours, MinWaitTime, MaxWaitTime)
    Float waitUntil = Utility.GetCurrentGameTime() + (waitHours / 24.0)

    ; Store state on the NPC for recovery after reload
    StorageUtil.SetStringValue(akNPC, "SeverTravel_State", "traveling")
    StorageUtil.SetStringValue(akNPC, "SeverTravel_Destination", placeName)
    StorageUtil.SetFloatValue(akNPC, "SeverTravel_WaitUntil", waitUntil)
    StorageUtil.SetIntValue(akNPC, "SeverTravel_Slot", slot)
    StorageUtil.SetIntValue(akNPC, "SeverTravel_Speed", speed)

    ; Force the alias to this NPC FIRST (before setting linked ref)
    ReferenceAlias theAlias = GetAliasForSlot(slot)
    If theAlias == None
        DebugMsg("ERROR: Could not get alias for slot " + slot)
        Return false
    EndIf

    theAlias.ForceRefTo(akNPC)
    DebugMsg("Forced alias slot " + slot + " to " + akNPC.GetDisplayName())

    ; Set up linked ref for travel package AFTER alias is assigned
    ; Points to interior marker (if resolved) or exterior ref — NPC AI pathfinds through doors
    If TravelTargetKeyword
        PO3_SKSEFunctions.SetLinkedRef(akNPC, finalDest, TravelTargetKeyword)
        DebugMsg("Set linked ref to destination")
    Else
        DebugMsg("WARNING: TravelTargetKeyword not set!")
    EndIf

    ; Apply travel package based on speed
    Package travelPkg = GetTravelPackageForSpeed(speed)
    If travelPkg == None
        DebugMsg("ERROR: Could not get travel package for speed " + speed)
        Return false
    EndIf

    DebugMsg("Applying travel package with priority " + TravelPackagePriority)
    ActorUtil.AddPackageOverride(akNPC, travelPkg, TravelPackagePriority, 1)

    ; Small delay to ensure linked ref is processed before package evaluation
    Utility.Wait(0.1)

    ; Force package evaluation
    akNPC.EvaluatePackage()
    DebugMsg("Package evaluated for " + akNPC.GetDisplayName())

    ; Disable NPC-NPC collision so the traveler doesn't get blocked by other NPCs
    SeverActionsNative.SetActorBumpable(akNPC, false)

    ; Update slot tracking
    SlotStates[slot] = 1  ; traveling
    SlotPlaceNames[slot] = placeName
    SlotDestinations[slot] = finalDest
    SlotWaitDeadlines[slot] = waitUntil
    SlotSpeeds[slot] = speed
    SlotTravelStartTimes[slot] = Utility.GetCurrentGameTime()

    ; Store initial distance for time-skip calculations
    ; GetDistance returns 0 when NPC and dest are in different cells, so use a reasonable default
    Float initDist = 0.0
    If akNPC.Is3DLoaded() && finalDest.Is3DLoaded()
        initDist = akNPC.GetDistance(finalDest)
    EndIf
    If initDist < 1000.0
        ; Cross-cell or very close — use a conservative default (typical city traverse)
        initDist = 5000.0
    EndIf
    SlotInitialDistances[slot] = initDist

    ; Ensure update loop is running
    RegisterForSingleUpdate(UpdateInterval)

    Return true
EndFunction

Bool Function TravelToPlaceWithConfirmation(Actor akNPC, String placeName, Float waitHours = 0.0, Bool stopFollowing = true, Int speed = 0)
    {Send an NPC to a named place with player confirmation popup.
     Returns true if travel started, false if denied or cancelled.
     speed: 0 = walk (default), 1 = jog, 2 = run}
    
    If akNPC == None
        DebugMsg("ERROR: TravelToPlaceWithConfirmation called with None actor")
        Return false
    EndIf
    
    String npcName = akNPC.GetDisplayName()
    String promptText = npcName + " wants to travel to " + placeName + "."
    
    ; Show confirmation dialog
    String result = SkyMessage.Show(promptText, "Allow", "Deny", "Deny (Silent)")
    
    If result == "Allow"
        ; Player approved - start travel
        Return TravelToPlace(akNPC, placeName, waitHours, stopFollowing, speed)
        
    ElseIf result == "Deny"
        ; Player denied - send direct narration so NPC knows
        Int handle = ModEvent.Create("DirectNarration")
        If handle
            ModEvent.PushForm(handle, akNPC)
            ModEvent.PushString(handle, "The player told " + npcName + " they cannot go to " + placeName + ".")
            ModEvent.Send(handle)
        EndIf
        DebugMsg(npcName + " denied travel to " + placeName + " (with narration)")
        Return false
        
    Else
        ; "Deny (Silent)" or timeout - just cancel quietly
        DebugMsg(npcName + " denied travel to " + placeName + " (silent)")
        Return false
    EndIf
EndFunction

Bool Function TravelToReference(Actor akNPC, ObjectReference akDestination, Float waitHours = 0.0, Bool stopFollowing = false, Int speed = 1, Bool externalManaged = false)
    {Send an NPC directly to an ObjectReference destination (door, marker, NPC, etc).
     Unlike TravelToPlace, this skips name resolution and uses the reference directly.
     Useful for dispatching NPCs to specific doors, actors, or markers.
     speed: 0 = walk, 1 = jog (default), 2 = run
     externalManaged: If true, travel system won't do arrival detection or sandbox on arrive.
                      Caller must call CancelTravel() when done. Used by guard dispatch etc.
     Returns true if travel started successfully.}

    Int slot
    ReferenceAlias theAlias
    Float waitUntil
    Package travelPkg

    ; Validate inputs
    If akNPC == None
        DebugMsg("ERROR: TravelToReference called with None actor")
        Return false
    EndIf

    If akNPC.IsDead()
        DebugMsg("ERROR: Cannot send dead NPC to travel")
        Return false
    EndIf

    If akDestination == None
        DebugMsg("ERROR: TravelToReference called with None destination")
        Return false
    EndIf

    ; Clamp speed to valid range
    If speed < 0
        speed = 0
    ElseIf speed > 2
        speed = 2
    EndIf

    ; Cancel any existing travel for this NPC
    CancelTravel(akNPC)

    ; Find a free alias slot
    slot = FindFreeSlot()
    If slot < 0
        DebugMsg("ERROR: No free travel slots available")
        Return false
    EndIf

    ; Stop following if requested
    If stopFollowing
        DismissFollower(akNPC)
    EndIf

    ; Calculate wait deadline
    If waitHours <= 0.0
        waitHours = DefaultWaitTime
    EndIf
    waitHours = ClampFloat(waitHours, MinWaitTime, MaxWaitTime)
    waitUntil = Utility.GetCurrentGameTime() + (waitHours / 24.0)

    ; Store state on the NPC for recovery after reload
    StorageUtil.SetStringValue(akNPC, "SeverTravel_State", "traveling")
    StorageUtil.SetStringValue(akNPC, "SeverTravel_Destination", "dispatch_target")
    StorageUtil.SetFloatValue(akNPC, "SeverTravel_WaitUntil", waitUntil)
    StorageUtil.SetIntValue(akNPC, "SeverTravel_Slot", slot)
    StorageUtil.SetIntValue(akNPC, "SeverTravel_Speed", speed)

    ; Force the alias to this NPC FIRST (before setting linked ref)
    theAlias = GetAliasForSlot(slot)
    If theAlias == None
        DebugMsg("ERROR: Could not get alias for slot " + slot)
        Return false
    EndIf

    theAlias.ForceRefTo(akNPC)
    DebugMsg("TravelToReference: Forced alias slot " + slot + " to " + akNPC.GetDisplayName())

    ; If destination is a door to an interior, resolve to the interior marker directly
    ObjectReference finalDest = akDestination
    If akDestination.GetBaseObject().GetType() == 29
        ObjectReference iMarkerRef = SeverActionsNative.FindInteriorMarkerForDoor(akDestination)
        If iMarkerRef != None
            finalDest = iMarkerRef
            DebugMsg("TravelToReference: Resolved door to interior marker")
        Else
            DebugMsg("TravelToReference: Door has no interior marker, using door directly")
        EndIf
        ; Unlock the door so AI pathfinding isn't blocked by locked doors
        If akDestination.IsLocked()
            akDestination.Lock(false)
            DebugMsg("TravelToReference: Unlocked door for NPC travel")
        EndIf
    EndIf

    ; Set up linked ref — NPC AI pathfinds through doors to reach interior markers
    If TravelTargetKeyword
        PO3_SKSEFunctions.SetLinkedRef(akNPC, finalDest, TravelTargetKeyword)
        DebugMsg("TravelToReference: Set linked ref to destination")
    Else
        DebugMsg("WARNING: TravelTargetKeyword not set!")
    EndIf

    ; Apply travel package based on speed
    travelPkg = GetTravelPackageForSpeed(speed)
    If travelPkg == None
        DebugMsg("ERROR: Could not get travel package for speed " + speed)
        Return false
    EndIf

    DebugMsg("TravelToReference: Applying travel package with priority " + TravelPackagePriority)
    ActorUtil.AddPackageOverride(akNPC, travelPkg, TravelPackagePriority, 1)

    ; Small delay to ensure linked ref is processed before package evaluation
    Utility.Wait(0.1)

    ; Force package evaluation
    akNPC.EvaluatePackage()

    ; Disable NPC-NPC collision so the traveler doesn't get blocked by other NPCs
    SeverActionsNative.SetActorBumpable(akNPC, false)

    ; Update slot tracking
    SlotStates[slot] = 1  ; traveling
    SlotPlaceNames[slot] = "dispatch_target"
    SlotDestinations[slot] = finalDest
    SlotWaitDeadlines[slot] = waitUntil
    SlotSpeeds[slot] = speed
    SlotExternalManaged[slot] = externalManaged
    SlotTravelStartTimes[slot] = Utility.GetCurrentGameTime()

    ; Store initial distance for time-skip calculations
    Float initDistRef = 0.0
    If akNPC.Is3DLoaded() && finalDest.Is3DLoaded()
        initDistRef = akNPC.GetDistance(finalDest)
    EndIf
    If initDistRef < 1000.0
        initDistRef = 5000.0
    EndIf
    SlotInitialDistances[slot] = initDistRef

    If externalManaged
        DebugMsg("TravelToReference: Slot " + slot + " is externally managed - no arrival detection")
    EndIf

    ; Ensure update loop is running
    RegisterForSingleUpdate(UpdateInterval)

    Return true
EndFunction

; =============================================================================
; PLACE RESOLUTION - Native LocationResolver
; =============================================================================

ObjectReference Function ResolvePlace(Actor akNPC, String placeName)
    {Convert a place name to a destination ObjectReference using native LocationResolver.
     Supports: exact names, city aliases, editor IDs, fuzzy prefix/contains, Levenshtein,
     and semantic terms (outside, inside, upstairs, downstairs) relative to the NPC.}

    If !SeverActionsNative.IsLocationResolverReady()
        DebugMsg("ERROR: ResolvePlace called but LocationResolver not initialized")
        Return None
    EndIf

    ; Native function handles the full resolution chain:
    ; 1. Semantic terms (outside/inside/upstairs/downstairs) - relative to NPC position
    ; 2. Exact cell/location name match
    ; 3. City alias match (e.g. "whiterun" -> WhiterunOrigin)
    ; 4. Editor ID match
    ; 5. Fuzzy prefix/contains search
    ; 6. Levenshtein distance (typo tolerance <= 2)
    ObjectReference marker = SeverActionsNative.ResolveDestination(akNPC, placeName)

    If marker == None
        DebugMsg("Could not resolve '" + placeName + "' to destination")
    Else
        DebugMsg("Resolved '" + placeName + "' -> " + marker)
    EndIf

    Return marker
EndFunction

; Legacy compatibility wrappers (may be called by external scripts)
ObjectReference Function ResolvePlaceLegacy(String placeName)
    {Legacy wrapper - resolves without actor context (no semantic terms).
     Prefer ResolvePlace(actor, name) for full functionality.}
    Return ResolvePlace(Game.GetPlayer(), placeName)
EndFunction

; =============================================================================
; UPDATE LOOP
; =============================================================================

Event OnUpdate()
    Bool hasActiveSlots = false
    
    Int i = 0
    While i < MAX_SLOTS
        If SlotStates[i] == 1
            ; Traveling - check for arrival
            CheckTravelingSlot(i)
            hasActiveSlots = true
        ElseIf SlotStates[i] == 2
            ; Waiting/sandboxing - check for player arrival or timeout
            CheckWaitingSlot(i)
            hasActiveSlots = true
        EndIf
        i += 1
    EndWhile
    
    ; Continue updating if there are active travelers
    If hasActiveSlots
        RegisterForSingleUpdate(UpdateInterval)
    EndIf
EndEvent

Function CheckTravelingSlot(Int slot)
    {Check if NPC in traveling slot has arrived at destination.
     Also monitors for stuck NPCs and applies progressive recovery.}

    ReferenceAlias theAlias
    Actor npc
    ObjectReference dest
    Float dist
    String placeName
    Int stuckLevel
    Float teleportDist
    Float npcX
    Float npcY
    Float npcZ
    Float destX
    Float destY
    Float dx
    Float dy
    Float dist2d
    Float moveX
    Float moveY

    theAlias = GetAliasForSlot(slot)

    If theAlias == None
        ClearSlot(slot)
        Return
    EndIf

    npc = theAlias.GetActorReference()
    If npc == None || npc.IsDead()
        DebugMsg("Slot " + slot + ": NPC is None or dead, clearing")
        ClearSlot(slot)
        Return
    EndIf

    ; Externally managed slots: skip arrival detection entirely
    ; The caller (e.g. arrest dispatch) handles monitoring and calls CancelTravel when done
    If SlotExternalManaged[slot]
        Return
    EndIf

    dest = SlotDestinations[slot]

    ; If destination is None, we can't check arrival
    If dest == None
        DebugMsg("Slot " + slot + ": Destination is None, checking by location")
        Return
    EndIf

    ; --- Time-skip detection (T-wait, sleeping, fast travel) ---
    ; If enough game time has elapsed since travel started, the NPC should have arrived
    ; even though their AI was frozen during the time skip.
    ; Uses the stored initial distance (captured at travel start) instead of live GetDistance.
    ; Walk: ~10000 u/game-hr, Jog: ~20000, Run: ~33000
    If SlotTravelStartTimes[slot] > 0.0
        Float gameTimeElapsed = (Utility.GetCurrentGameTime() - SlotTravelStartTimes[slot]) * 24.0  ; in game hours
        If gameTimeElapsed >= 0.25  ; At least 15 game-minutes have passed (catches time-skips)
            Float travelDist = SlotInitialDistances[slot]
            If travelDist < 1000.0
                travelDist = 5000.0  ; Safety fallback
            EndIf
            Float speedFactor = 10000.0  ; walk: 10000 units per game-hour
            Int currentSpeed = SlotSpeeds[slot]
            If currentSpeed == 1
                speedFactor = 20000.0  ; jog
            ElseIf currentSpeed >= 2
                speedFactor = 33000.0  ; run
            EndIf
            Float requiredHours = travelDist / speedFactor
            If requiredHours < 0.25
                requiredHours = 0.25  ; Minimum 15 game-minutes travel time
            EndIf

            If gameTimeElapsed >= requiredHours
                ; Enough game time has passed — teleport NPC to destination and arrive
                DebugMsg("Slot " + slot + ": Time-skip detected (" + gameTimeElapsed + "h elapsed, " + requiredHours + "h required, dist=" + travelDist + "). Completing travel.")
                npc.MoveTo(dest)
                Utility.Wait(0.3)
                SeverActionsNative.Stuck_StopTracking(npc)
                placeName = SlotPlaceNames[slot]
                OnArrived(slot, npc, placeName)
                Return
            EndIf
        EndIf
    EndIf

    ; --- Check if NPC is in the destination cell ---
    ; When dest is an interior marker, this detects the NPC entering the correct interior.
    ; When dest is an exterior ref, npcCell.IsInterior() prevents false matches.
    Cell npcCell = npc.GetParentCell()
    Cell destCell = dest.GetParentCell()
    If npcCell != None && destCell != None && npcCell == destCell
        ; NPC is in the same cell as destination — check distance for arrival
        ; (Both are guaranteed to be 3D loaded since they're in the same cell)
        dist = npc.GetDistance(dest)
        If dist <= ArrivalDistance
            DebugMsg("Slot " + slot + ": NPC arrived at destination (same cell, dist=" + dist + ")")
            SeverActionsNative.Stuck_StopTracking(npc)
            placeName = SlotPlaceNames[slot]
            OnArrived(slot, npc, placeName)
            Return
        EndIf
    EndIf

    ; --- Distance check for same-worldspace exterior travel ---
    ; Only trust GetDistance when both refs are 3D loaded (same worldspace, loaded cells)
    If npc.Is3DLoaded() && dest.Is3DLoaded()
        dist = npc.GetDistance(dest)
        If dist <= ArrivalDistance
            DebugMsg("Slot " + slot + ": NPC arrived at destination (dist=" + dist + ")")
            SeverActionsNative.Stuck_StopTracking(npc)
            placeName = SlotPlaceNames[slot]
            OnArrived(slot, npc, placeName)
            Return
        EndIf
    EndIf

    ; =========================================================================
    ; STUCK DETECTION - Progressive recovery for NPCs that get stuck on terrain
    ; =========================================================================

    ; Start tracking if not already tracked
    If !SeverActionsNative.Stuck_IsTracked(npc)
        SeverActionsNative.Stuck_StartTracking(npc)
    EndIf

    ; Check stuck status (returns escalation level 0-3)
    stuckLevel = SeverActionsNative.Stuck_CheckStatus(npc, UpdateInterval, 50.0)

    If stuckLevel == 1
        ; Level 1: Re-link destination and re-evaluate packages
        ; Just calling EvaluatePackage() often recalculates the same failed path.
        ; Re-setting the linked ref forces the AI to treat this as a fresh travel instruction,
        ; giving the pathfinding engine a clean slate.
        DebugMsg("Slot " + slot + ": NPC possibly stuck, re-linking destination and re-evaluating")
        If TravelTargetKeyword
            PO3_SKSEFunctions.SetLinkedRef(npc, dest, TravelTargetKeyword)
        EndIf
        npc.EvaluatePackage()

    ElseIf stuckLevel == 2
        ; Level 2: Leapfrog - teleport partway toward destination, then re-link
        teleportDist = SeverActionsNative.Stuck_GetTeleportDistance(npc)
        DebugMsg("Slot " + slot + ": NPC stuck, leapfrogging " + teleportDist + " units toward destination")

        ; Calculate direction vector from NPC to destination and move partway
        npcX = npc.GetPositionX()
        npcY = npc.GetPositionY()
        npcZ = npc.GetPositionZ()
        destX = dest.GetPositionX()
        destY = dest.GetPositionY()

        ; Normalize direction and move partway
        dx = destX - npcX
        dy = destY - npcY
        dist2d = Math.sqrt(dx * dx + dy * dy)
        If dist2d > 0.0
            moveX = (dx / dist2d) * teleportDist
            moveY = (dy / dist2d) * teleportDist
            npc.MoveTo(npc, moveX, moveY, 0.0)
            ; Re-link after teleport — NPC is in a new position, needs fresh pathfinding
            If TravelTargetKeyword
                PO3_SKSEFunctions.SetLinkedRef(npc, dest, TravelTargetKeyword)
            EndIf
            npc.EvaluatePackage()
        EndIf
        SeverActionsNative.Stuck_ResetEscalation(npc)

    ElseIf stuckLevel >= 3
        ; Level 3: Force teleport directly to destination (interior marker or exterior ref)
        DebugMsg("Slot " + slot + ": NPC very stuck, force teleporting to destination")
        npc.MoveTo(dest)
        Utility.Wait(0.5)
        SeverActionsNative.Stuck_StopTracking(npc)
        SeverActionsNative.Stuck_ResetEscalation(npc)
        placeName = SlotPlaceNames[slot]
        OnArrived(slot, npc, placeName)
        Return
    EndIf
EndFunction

Function OnArrived(Int slot, Actor akNPC, String placeName)
    {Handle NPC arrival at destination.}

    ; Restore normal NPC-NPC collision now that travel is complete
    SeverActionsNative.SetActorBumpable(akNPC, true)

    ; Remove travel package, apply sandbox
    RemoveAllTravelPackages(akNPC)

    ; Linked ref already points to the destination (interior marker or exterior ref).
    ; Re-set it explicitly for the sandbox package to anchor around.
    If TravelTargetKeyword
        ObjectReference sandboxAnchor = SlotDestinations[slot]
        If sandboxAnchor != None
            PO3_SKSEFunctions.SetLinkedRef(akNPC, sandboxAnchor, TravelTargetKeyword)
            DebugMsg("Slot " + slot + ": Set linked ref to destination for sandbox")
        Else
            PO3_SKSEFunctions.SetLinkedRef(akNPC, None, TravelTargetKeyword)
        EndIf
    EndIf

    ; Apply sandbox package
    ActorUtil.AddPackageOverride(akNPC, SandboxPackage, TravelPackagePriority, 1)
    akNPC.EvaluatePackage()

    ; Update state
    SlotStates[slot] = 2  ; waiting/sandboxing
    StorageUtil.SetStringValue(akNPC, "SeverTravel_State", "waiting")

    NotifyPlayer(akNPC.GetDisplayName() + " arrived at " + placeName)
EndFunction

Function CheckWaitingSlot(Int slot)
    {Check if NPC has been spoken to via SkyrimNet or if patience ran out.
     NPC keeps sandboxing until:
     1. Player enters same cell, is close, and has LOS -> triggers DirectNarration greeting
     2. After greeting, NPC finishes speaking -> travel complete
     3. External caller sets SeverTravel_SpokenTo flag (backup)
     4. Wait deadline expires (timeout safety net)}

    ReferenceAlias theAlias = GetAliasForSlot(slot)
    Actor npc
    Float currentTime
    Float deadline
    String placeName

    If theAlias == None
        ClearSlot(slot)
        Return
    EndIf

    npc = theAlias.GetActorReference()
    If npc == None || npc.IsDead()
        ClearSlot(slot)
        Return
    EndIf

    currentTime = Utility.GetCurrentGameTime()
    deadline = SlotWaitDeadlines[slot]
    placeName = SlotPlaceNames[slot]

    ; --- Check 1: External SpokenTo flag (from NotifyTravelSpokenTo or other callers) ---
    Bool spokenTo = StorageUtil.GetIntValue(npc, "SeverTravel_SpokenTo") as Bool
    If spokenTo
        StorageUtil.UnsetIntValue(npc, "SeverTravel_SpokenTo")
        StorageUtil.UnsetIntValue(npc, "SeverTravel_Greeted")
        OnPlayerArrived(slot, npc)
        Return
    EndIf

    ; --- Check 2: Detect player proximity and trigger SkyrimNet dialogue ---
    ; When the player is close enough and visible, we fire a DirectNarration to make
    ; the NPC greet/acknowledge the player via SkyrimNet. After enough time passes for
    ; the NPC to speak (LLM generation + TTS), we consider dialogue complete and end travel.
    ; This means: NO changes to SkyrimNet required — we use its public API only.
    Actor player = Game.GetPlayer()
    If player != None
        Cell playerCell = player.GetParentCell()
        Cell npcCell = npc.GetParentCell()

        If playerCell != None && npcCell != None && playerCell == npcCell
            Float dist = npc.GetDistance(player as ObjectReference)
            Int greetedState = StorageUtil.GetIntValue(npc, "SeverTravel_Greeted")

            If greetedState == 0 && dist <= 300.0 && npc.HasLOS(player as ObjectReference)
                ; Player is close and visible — trigger SkyrimNet greeting
                ; State 1 = greeting sent, waiting for dialogue to complete
                StorageUtil.SetIntValue(npc, "SeverTravel_Greeted", 1)
                StorageUtil.SetFloatValue(npc, "SeverTravel_GreetTime", Utility.GetCurrentRealTime())
                DebugMsg("Player detected near waiting NPC " + npc.GetDisplayName() + " at " + placeName + " — triggering SkyrimNet greeting")
                String narration = "*" + npc.GetDisplayName() + " notices the player approaching and turns to greet them, having been waiting here in " + placeName + "*"
                SkyrimNetApi.DirectNarration(narration, npc, player)
                Return
            EndIf

            If greetedState == 1
                ; NPC has greeted — wait for dialogue to finish
                ; Give SkyrimNet time: LLM generation (~3-5s) + TTS (~2-5s) + playback (~3-10s)
                ; We wait a minimum of 12 seconds after greeting was sent
                Float greetTime = StorageUtil.GetFloatValue(npc, "SeverTravel_GreetTime")
                Float elapsed = Utility.GetCurrentRealTime() - greetTime

                If elapsed >= 12.0
                    ; Enough time for SkyrimNet to generate and play the greeting
                    ; Check speech queue is empty (no pending speech for this interaction)
                    Int queueSize = SkyrimNetApi.GetSpeechQueueSize()
                    If queueSize == 0
                        ; No more speech queued — dialogue is done
                        StorageUtil.UnsetIntValue(npc, "SeverTravel_Greeted")
                        StorageUtil.UnsetFloatValue(npc, "SeverTravel_GreetTime")
                        DebugMsg("SkyrimNet dialogue completed for " + npc.GetDisplayName() + " — completing travel")
                        OnPlayerArrived(slot, npc)
                        Return
                    Else
                        DebugMsg("Waiting for speech queue to empty (size=" + queueSize + ") for " + npc.GetDisplayName())
                    EndIf
                EndIf
            EndIf
        Else
            ; Player left the cell — reset greeted flag so NPC greets again when player returns
            If StorageUtil.GetIntValue(npc, "SeverTravel_Greeted") > 0
                StorageUtil.UnsetIntValue(npc, "SeverTravel_Greeted")
                StorageUtil.UnsetFloatValue(npc, "SeverTravel_GreetTime")
            EndIf
        EndIf
    EndIf

    ; --- Check 3: Timeout ---
    If currentTime >= deadline
        StorageUtil.UnsetIntValue(npc, "SeverTravel_Greeted")
        StorageUtil.UnsetFloatValue(npc, "SeverTravel_GreetTime")
        OnWaitTimeout(slot, npc)
    EndIf
EndFunction

Function OnPlayerArrived(Int slot, Actor akNPC)
    {Player spoke to the NPC at their destination via SkyrimNet.}

    StorageUtil.SetStringValue(akNPC, "SeverTravel_State", "complete")
    StorageUtil.SetStringValue(akNPC, "SeverTravel_Result", "player_arrived")

    NotifyPlayer(akNPC.GetDisplayName() + " is glad to see you!")

    ; Clear the slot - this will remove packages and restore follower status
    ClearSlot(slot, true)
EndFunction

Function NotifyTravelSpokenTo(Actor akNPC)
    {Called externally (e.g. by SkyrimNet dialogue handler) when the player speaks
     to a traveling NPC who has arrived and is sandboxing. Sets the flag that
     CheckWaitingSlot checks to complete the travel.}

    If akNPC == None
        Return
    EndIf

    Int slot = FindSlotByActor(akNPC)
    If slot >= 0 && SlotStates[slot] == 2
        StorageUtil.SetIntValue(akNPC, "SeverTravel_SpokenTo", 1)
        DebugMsg("NotifyTravelSpokenTo: " + akNPC.GetDisplayName() + " (slot " + slot + ")")
    EndIf
EndFunction

Function OnWaitTimeout(Int slot, Actor akNPC)
    {NPC waited too long and is leaving.}
    
    StorageUtil.SetStringValue(akNPC, "SeverTravel_State", "timeout")
    StorageUtil.SetStringValue(akNPC, "SeverTravel_Result", "timeout")
    
    NotifyPlayer(akNPC.GetDisplayName() + "'s patience ran out!")
    
    ; Clear the slot - don't restore follower since they gave up waiting
    ClearSlot(slot, false)
EndFunction

; =============================================================================
; ALIAS SLOT MANAGEMENT
; =============================================================================

ReferenceAlias Function GetAliasForSlot(Int slot)
    {Get the ReferenceAlias for a given slot index.}
    
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
    {Find an empty alias slot. Returns -1 if all slots are in use.}
    
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
    {Find the slot containing a specific actor. Returns -1 if not found.}
    
    If akNPC == None
        Return -1
    EndIf
    
    Int i = 0
    ReferenceAlias theAlias
    Actor slotActor
    
    While i < MAX_SLOTS
        If SlotStates[i] != 0
            theAlias = GetAliasForSlot(i)
            If theAlias
                slotActor = theAlias.GetActorReference()
                If slotActor == akNPC
                    Return i
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile
    
    Return -1
EndFunction

Function ClearSlot(Int slot, Bool restoreFollower = false)
    {Clear a slot and release the alias. Properly cleans up NPC packages and state.
     restoreFollower: If true, restore follower status if they were a follower before travel.}
    
    If slot < 0 || slot >= MAX_SLOTS
        Return
    EndIf
    
    ReferenceAlias theAlias = GetAliasForSlot(slot)
    Actor npc
    
    If theAlias
        npc = theAlias.GetActorReference()
        If npc
            DebugMsg("ClearSlot " + slot + ": Cleaning up " + npc.GetDisplayName())

            ; Stop stuck tracking if active
            SeverActionsNative.Stuck_StopTracking(npc)

            ; Restore normal NPC-NPC collision
            SeverActionsNative.SetActorBumpable(npc, true)

            ; CRITICAL: Remove all travel/sandbox packages so NPC doesn't get stuck
            RemoveAllTravelPackages(npc)
            If SandboxPackage
                ActorUtil.RemovePackageOverride(npc, SandboxPackage)
            EndIf
            
            ; Clear linked ref
            If TravelTargetKeyword
                PO3_SKSEFunctions.SetLinkedRef(npc, None, TravelTargetKeyword)
            EndIf
            
            ; Check if should restore follower status
            If restoreFollower
                Bool wasFollower = StorageUtil.GetIntValue(npc, "SeverTravel_WasFollower") as Bool
                If wasFollower
                    ReinstateFollower(npc)
                EndIf
            EndIf
            
            ; Clear StorageUtil data
            StorageUtil.UnsetStringValue(npc, "SeverTravel_State")
            StorageUtil.UnsetStringValue(npc, "SeverTravel_Destination")
            StorageUtil.UnsetStringValue(npc, "SeverTravel_Result")
            StorageUtil.UnsetFloatValue(npc, "SeverTravel_WaitUntil")
            StorageUtil.UnsetIntValue(npc, "SeverTravel_Slot")
            StorageUtil.UnsetIntValue(npc, "SeverTravel_WasFollower")
            StorageUtil.UnsetIntValue(npc, "SeverTravel_Speed")
            StorageUtil.UnsetIntValue(npc, "SeverTravel_SpokenTo")
            StorageUtil.UnsetIntValue(npc, "SeverTravel_Greeted")
            StorageUtil.UnsetFloatValue(npc, "SeverTravel_GreetTime")

            ; Force AI to re-evaluate and return to normal behavior
            npc.EvaluatePackage()
        EndIf

        theAlias.Clear()
    EndIf

    ; Reset slot arrays
    SlotStates[slot] = 0
    SlotPlaceNames[slot] = ""
    SlotDestinations[slot] = None
    SlotWaitDeadlines[slot] = 0.0
    SlotSpeeds[slot] = 0
    SlotExternalManaged[slot] = false
    SlotTravelStartTimes[slot] = 0.0
    SlotInitialDistances[slot] = 0.0
EndFunction

Function ForceResetAllSlots(Bool restoreFollowers = true)
    {Emergency reset - clears ALL travel slots unconditionally. Use when slots get stuck.
     restoreFollowers: If true, restore follower status for all NPCs that were followers.}
    
    DebugMsg("=== FORCE RESET ALL SLOTS ===")
    NotifyPlayer("Resetting all travel slots...")
    
    Int i = 0
    ReferenceAlias theAlias
    Actor npc
    Bool wasFollower
    
    ; First pass: Clean up all NPCs properly
    While i < MAX_SLOTS
        theAlias = GetAliasForSlot(i)
        If theAlias
            npc = theAlias.GetActorReference()
            If npc
                DebugMsg("Force clearing slot " + i + ": " + npc.GetDisplayName())

                ; Stop stuck tracking
                SeverActionsNative.Stuck_StopTracking(npc)

                ; Restore normal NPC-NPC collision
                SeverActionsNative.SetActorBumpable(npc, true)

                ; Remove all packages
                RemoveAllTravelPackages(npc)
                If SandboxPackage
                    ActorUtil.RemovePackageOverride(npc, SandboxPackage)
                EndIf
                
                ; Clear linked ref
                If TravelTargetKeyword
                    PO3_SKSEFunctions.SetLinkedRef(npc, None, TravelTargetKeyword)
                EndIf
                
                ; Check if should restore follower status
                If restoreFollowers
                    wasFollower = StorageUtil.GetIntValue(npc, "SeverTravel_WasFollower") as Bool
                    If wasFollower
                        ReinstateFollower(npc)
                    EndIf
                EndIf
                
                ; Clear all StorageUtil data
                StorageUtil.UnsetStringValue(npc, "SeverTravel_State")
                StorageUtil.UnsetStringValue(npc, "SeverTravel_Destination")
                StorageUtil.UnsetStringValue(npc, "SeverTravel_Result")
                StorageUtil.UnsetFloatValue(npc, "SeverTravel_WaitUntil")
                StorageUtil.UnsetIntValue(npc, "SeverTravel_Slot")
                StorageUtil.UnsetIntValue(npc, "SeverTravel_WasFollower")
                StorageUtil.UnsetIntValue(npc, "SeverTravel_Speed")
                StorageUtil.UnsetIntValue(npc, "SeverTravel_SpokenTo")
                StorageUtil.UnsetIntValue(npc, "SeverTravel_Greeted")
                StorageUtil.UnsetFloatValue(npc, "SeverTravel_GreetTime")

                npc.EvaluatePackage()
            EndIf
            theAlias.Clear()
        EndIf
        i += 1
    EndWhile
    
    ; Re-initialize arrays (in case they were corrupted)
    SlotStates = new Int[5]
    SlotPlaceNames = new String[5]
    SlotDestinations = new ObjectReference[5]
    SlotWaitDeadlines = new Float[5]
    SlotSpeeds = new Int[5]
    SlotExternalManaged = new Bool[5]
    SlotTravelStartTimes = new Float[5]
    SlotInitialDistances = new Float[5]

    ; Explicitly zero everything
    i = 0
    While i < MAX_SLOTS
        SlotStates[i] = 0
        SlotPlaceNames[i] = ""
        SlotDestinations[i] = None
        SlotWaitDeadlines[i] = 0.0
        SlotSpeeds[i] = 0
        SlotExternalManaged[i] = false
        SlotTravelStartTimes[i] = 0.0
        SlotInitialDistances[i] = 0.0
        i += 1
    EndWhile
    
    ; Stop the update poll if running
    UnregisterForUpdateGameTime()
    
    DebugMsg("=== FORCE RESET COMPLETE - All " + MAX_SLOTS + " slots cleared ===")
    NotifyPlayer("All travel slots have been reset.")
EndFunction

Int Function GetActiveTravelCount()
    {Returns count of currently active travel slots. Useful for MCM display.}
    
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
    {Get state of a specific slot. 0=empty, 1=traveling, 2=waiting}
    If slot < 0 || slot >= MAX_SLOTS
        Return 0
    EndIf
    Return SlotStates[slot]
EndFunction

Function ClearSlotFromMCM(Int slot, Bool restoreFollower = true)
    {Clear a specific slot from MCM. Properly cleans up the NPC.
     restoreFollower: If true, restore follower status if they were a follower.}
    
    If slot < 0 || slot >= MAX_SLOTS
        DebugMsg("ClearSlotFromMCM: Invalid slot " + slot)
        Return
    EndIf
    
    If SlotStates[slot] == 0
        DebugMsg("ClearSlotFromMCM: Slot " + slot + " is already empty")
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
    DebugMsg("ClearSlotFromMCM: Slot " + slot + " cleared")
EndFunction

String Function GetSlotDestination(Int slot)
    {Get destination name for a specific slot}
    If slot < 0 || slot >= MAX_SLOTS
        Return ""
    EndIf
    Return SlotPlaceNames[slot]
EndFunction

String Function GetSlotStatusText(Int slot)
    {Get human-readable status text for MCM display}
    If slot < 0 || slot >= MAX_SLOTS
        Return "Invalid"
    EndIf
    
    ; Safety check - if arrays are uninitialized, return error
    If SlotStates == None || SlotStates.Length == 0
        Return "NOT INITIALIZED"
    EndIf
    
    String result = "Empty"
    
    If SlotStates[slot] == 1
        If SlotPlaceNames[slot] != ""
            result = "Traveling: " + SlotPlaceNames[slot]
        Else
            result = "Traveling (unknown)"
        EndIf
    ElseIf SlotStates[slot] == 2
        If SlotPlaceNames[slot] != ""
            result = "Waiting: " + SlotPlaceNames[slot]
        Else
            result = "Waiting (unknown)"
        EndIf
    ElseIf SlotStates[slot] != 0
        result = "UNKNOWN: " + SlotStates[slot]
    EndIf
    
    Return result
EndFunction

; =============================================================================
; CANCEL / CLEANUP
; =============================================================================

Function CancelTravel(Actor akNPC, Bool restoreFollower = true)
    {Cancel any active travel for an NPC. Optionally restore follower status.}
    
    If akNPC == None
        Return
    EndIf
    
    Int slot = FindSlotByActor(akNPC)
    If slot >= 0
        DebugMsg("Canceling travel for " + akNPC.GetDisplayName() + " in slot " + slot)
        ClearSlot(slot, restoreFollower)
    EndIf
EndFunction

Function CancelAllTravel(Bool restoreFollowers = true)
    {Cancel all active travel. Useful for cleanup.
     restoreFollowers: If true, restore follower status for all NPCs that were followers.}
    
    Int i = 0
    
    While i < MAX_SLOTS
        If SlotStates[i] != 0
            ClearSlot(i, restoreFollowers)
        EndIf
        i += 1
    EndWhile
    
    DebugMsg("All travel canceled")
EndFunction

; =============================================================================
; SPEED CONTROL
; =============================================================================

Bool Function SetTravelSpeed(Actor akNPC, Int speed)
    {Change the travel speed of an NPC mid-journey.
     speed: 0 = walk, 1 = jog, 2 = run
     Returns true if speed was changed successfully.}
    
    If akNPC == None
        DebugMsg("ERROR: SetTravelSpeed called with None actor")
        Return false
    EndIf
    
    Int slot = FindSlotByActor(akNPC)
    If slot < 0
        DebugMsg("ERROR: NPC is not currently traveling")
        Return false
    EndIf
    
    ; Only change speed if actually traveling (not sandboxing)
    If SlotStates[slot] != 1
        DebugMsg("ERROR: NPC is not in traveling state")
        Return false
    EndIf
    
    ; Clamp speed to valid range
    If speed < 0
        speed = 0
    ElseIf speed > 2
        speed = 2
    EndIf
    
    Int currentSpeed = SlotSpeeds[slot]
    If currentSpeed == speed
        DebugMsg("NPC already at speed " + speed)
        Return true
    EndIf
    
    ; Remove current travel package
    Package oldPkg = GetTravelPackageForSpeed(currentSpeed)
    ActorUtil.RemovePackageOverride(akNPC, oldPkg)
    
    ; Apply new travel package
    Package newPkg = GetTravelPackageForSpeed(speed)
    ActorUtil.AddPackageOverride(akNPC, newPkg, TravelPackagePriority, 1)
    akNPC.EvaluatePackage()
    
    ; Update tracking
    SlotSpeeds[slot] = speed
    StorageUtil.SetIntValue(akNPC, "SeverTravel_Speed", speed)
    
    Return true
EndFunction

Bool Function SetTravelSpeedNatural(Actor akNPC, String speedText)
    {Change travel speed using natural language.
     speedText: Natural language like "hurry up", "slow down", "run", etc.
     Returns true if speed was changed successfully.}
    
    Int speed = ParseSpeedForChange(speedText)
    Return SetTravelSpeed(akNPC, speed)
EndFunction

Int Function ParseSpeedForChange(String text)
    {Parse natural language to determine travel speed.
     Returns: 0 = walk, 1 = jog, 2 = run}
    
    String lower = StringToLower(text)
    
    ; Check for run/urgent keywords first (highest priority)
    If StringContains(lower, "urgent") || StringContains(lower, "hurry") || \
       StringContains(lower, "run") || StringContains(lower, "rush") || \
       StringContains(lower, "quick") || StringContains(lower, "fast") || \
       StringContains(lower, "emergency") || StringContains(lower, "immediate") || \
       StringContains(lower, "asap") || StringContains(lower, "sprint")
        Return 2
    EndIf
    
    ; Check for jog keywords
    If StringContains(lower, "jog") || StringContains(lower, "brisk") || \
       StringContains(lower, "steady") || StringContains(lower, "pace")
        Return 1
    EndIf
    
    ; Default to walk (also matches: walk, slow, stroll, leisurely, casual)
    Return 0
EndFunction

Package Function GetTravelPackageForSpeed(Int speed)
    {Get the appropriate travel package for a given speed.}
    
    If speed == 2 && TravelPackageRun
        Return TravelPackageRun
    ElseIf speed == 1 && TravelPackageJog
        Return TravelPackageJog
    ElseIf speed == 0 && TravelPackageWalk
        Return TravelPackageWalk
    EndIf
    
    ; Fallback to default TravelPackage
    Return TravelPackage
EndFunction

Function RemoveAllTravelPackages(Actor akNPC)
    {Remove all travel packages from an NPC.}
    
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
    {Get a human-readable name for a speed value.}
    
    If speed == 0
        Return "walking"
    ElseIf speed == 1
        Return "jogging"
    ElseIf speed == 2
        Return "running"
    EndIf
    Return "moving"
EndFunction

Int Function GetTravelSpeed(Actor akNPC)
    {Get the current travel speed of an NPC. Returns -1 if not traveling.}
    
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
; FOLLOWER HANDLING
; =============================================================================

Function DismissFollower(Actor akNPC)
    {Temporarily dismiss a follower for travel.}
    
    Bool isFollower = akNPC.IsPlayerTeammate()
    StorageUtil.SetIntValue(akNPC, "SeverTravel_WasFollower", isFollower as Int)
    
    If isFollower
        akNPC.SetPlayerTeammate(false)
        akNPC.EvaluatePackage()
        DebugMsg("Dismissed follower: " + akNPC.GetDisplayName())
    EndIf
EndFunction

Function ReinstateFollower(Actor akNPC)
    {Restore follower status after travel.}
    
    akNPC.SetPlayerTeammate(true)
    akNPC.EvaluatePackage()
    DebugMsg("Reinstated follower: " + akNPC.GetDisplayName())
EndFunction

; =============================================================================
; UTILITY FUNCTIONS
; =============================================================================

Function DebugMsg(String msg)
    {Log a debug message to Papyrus log. Only shows notification if EnableDebugMessages is true.}
    
    Debug.Trace("SeverTravel: " + msg)
    If EnableDebugMessages
        Debug.Notification("Travel: " + msg)
    EndIf
EndFunction

Function NotifyPlayer(String msg)
    {Show an important notification to the player (always shown regardless of debug setting).}
    
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

String Function StringToLower(String s)
    Return SeverActionsNative.StringToLower(s)
EndFunction

Bool Function StringContains(String haystack, String needle)
    Return SeverActionsNative.StringContains(haystack, needle)
EndFunction

; =============================================================================
; DEBUG / TESTING API
; =============================================================================

Function TestMarkerResolution(String placeName)
    {Test function to verify location resolution without starting travel.}

    DebugMsg("Testing resolution for: " + placeName)

    If !SeverActionsNative.IsLocationResolverReady()
        DebugMsg("FAIL: LocationResolver not initialized")
        Return
    EndIf

    ; Test resolution using player as the actor context
    ObjectReference marker = SeverActionsNative.ResolveDestination(Game.GetPlayer(), placeName)
    If marker == None
        DebugMsg("FAIL: Could not resolve '" + placeName + "'")
        Return
    EndIf

    DebugMsg("SUCCESS: Resolved to " + marker + " at " + marker.GetPositionX() + ", " + marker.GetPositionY() + ", " + marker.GetPositionZ())
EndFunction

Function ShowStatus()
    {Display current travel system status.}
    
    DebugMsg("=== Travel System Status ===")
    DebugMsg("LocationResolver ready: " + SeverActionsNative.IsLocationResolverReady())
    
    Int i = 0
    Int activeCount = 0
    ReferenceAlias theAlias
    Actor npc
    String npcName
    String stateStr
    
    While i < MAX_SLOTS
        If SlotStates[i] != 0
            activeCount += 1
            theAlias = GetAliasForSlot(i)
            If theAlias
                npc = theAlias.GetActorReference()
                npcName = "None"
                If npc
                    npcName = npc.GetDisplayName()
                EndIf
                stateStr = "unknown"
                If SlotStates[i] == 1
                    stateStr = "traveling"
                ElseIf SlotStates[i] == 2
                    stateStr = "waiting"
                EndIf
                DebugMsg("Slot " + i + ": " + npcName + " - " + stateStr + " @ " + SlotPlaceNames[i])
            EndIf
        EndIf
        i += 1
    EndWhile
    
    DebugMsg("Active slots: " + activeCount + "/" + MAX_SLOTS)
EndFunction

Int Function GetActiveCount()
    {Get the number of active travel slots.}
    
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

Bool Function IsNPCTraveling(Actor akNPC)
    {Check if an NPC is currently traveling or waiting.}
    
    Return FindSlotByActor(akNPC) >= 0
EndFunction

String Function GetNPCTravelState(Actor akNPC)
    {Get the travel state of an NPC: "", "traveling", or "waiting".}
    
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
