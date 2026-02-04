Scriptname SeverActions_Travel extends Quest

{
    NPC Travel & Errand System v4 - Alias-Based
    
    Uses quest aliases for reliable cross-cell travel and interior sandboxing.
    NPCs are held in aliases for the entire journey (travel -> arrive -> sandbox -> complete).
    
    Features:
    - Alias-based persistence (NPCs don't get lost in unloaded cells)
    - Marker-based navigation from JSON database
    - Reliable interior sandboxing via alias packages
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

String Property DATABASE_FOLDER = "Data/SKSE/Plugins/SeverActions/TravelDB/" AutoReadOnly
{Folder containing travel marker JSON databases.}

; Timing defaults (in game hours)
Float Property DefaultWaitTime = 48.0 Auto
{Default time NPC will wait for player (game hours). 48 = 2 days.}

Float Property MinWaitTime = 6.0 Auto
{Minimum wait time (game hours).}

Float Property MaxWaitTime = 168.0 Auto
{Maximum wait time (game hours). 168 = 1 week.}

Bool Property EnableDebugMessages = true Auto
{Show debug notifications in-game. Disable for release.}

; =============================================================================
; CONSTANTS
; =============================================================================

Int Property MAX_SLOTS = 5 AutoReadOnly
{Maximum concurrent travelers. Must match number of aliases.}

; =============================================================================
; DATABASE STATE
; =============================================================================

; Native database is managed by SeverActionsNative DLL
; No JContainers handles needed anymore
Bool databaseLoaded = false

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

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    DebugMsg("OnInit called")
    InitializeSlotArrays()
    ForceReloadDatabase()
    RegisterForSingleUpdate(UpdateInterval)
EndEvent

Event OnPlayerLoadGame()
    DebugMsg("OnPlayerLoadGame called")
    
    ; Only initialize arrays if they're invalid - don't wipe existing data
    If SlotStates == None || SlotStates.Length != MAX_SLOTS
        DebugMsg("Arrays invalid on load - initializing fresh")
        InitializeSlotArrays()
    EndIf
    
    ForceReloadDatabase()
    RecoverExistingTravelers()
    RegisterForSingleUpdate(UpdateInterval)
EndEvent

Function InitializeSlotArrays()
    SlotStates = new Int[5]
    SlotPlaceNames = new String[5]
    SlotDestinations = new ObjectReference[5]
    SlotWaitDeadlines = new Float[5]
    SlotSpeeds = new Int[5]
    
    ; Initialize all to empty
    Int i = 0
    While i < MAX_SLOTS
        SlotStates[i] = 0
        SlotPlaceNames[i] = ""
        SlotDestinations[i] = None
        SlotWaitDeadlines[i] = 0.0
        SlotSpeeds[i] = 0
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
        EndIf
        i += 1
    EndWhile
EndFunction

; =============================================================================
; DATABASE LOADING
; =============================================================================

Function ForceReloadDatabase()
    DebugMsg("ForceReloadDatabase called")
    databaseLoaded = false
    LoadMarkerDatabase()
EndFunction

Function LoadMarkerDatabase()
    If databaseLoaded && SeverActionsNative.IsTravelDatabaseLoaded()
        Return
    EndIf

    String fullPath = DATABASE_FOLDER + "TravelMarkersVanilla.json"
    DebugMsg("Loading native database: " + fullPath)

    Bool loaded = SeverActionsNative.LoadTravelDatabase(fullPath)

    If !loaded
        ; Try alternate path without trailing slash issues
        fullPath = "Data/SKSE/Plugins/SeverActions/TravelDB/TravelMarkersVanilla.json"
        loaded = SeverActionsNative.LoadTravelDatabase(fullPath)
    EndIf

    If !loaded
        DebugMsg("ERROR: Failed to load travel database!")
        databaseLoaded = false
        Return
    EndIf

    Int count = SeverActionsNative.GetTravelMarkerCount()
    DebugMsg("Native database loaded: " + count + " markers")
    databaseLoaded = true
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
    
    ; Ensure database is loaded
    If !databaseLoaded
        LoadMarkerDatabase()
        If !databaseLoaded
            DebugMsg("ERROR: Database not available")
            Return false
        EndIf
    EndIf
    
    ; Cancel any existing travel for this NPC
    CancelTravel(akNPC)
    
    ; Find a free alias slot
    Int slot = FindFreeSlot()
    If slot < 0
        DebugMsg("ERROR: No free travel slots available")
        Return false
    EndIf
    
    ; Resolve place name to destination marker
    ObjectReference destMarker = ResolvePlace(placeName)
    If destMarker == None
        DebugMsg("ERROR: Unknown place '" + placeName + "'")
        Return false
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
    If TravelTargetKeyword
        PO3_SKSEFunctions.SetLinkedRef(akNPC, destMarker, TravelTargetKeyword)
        DebugMsg("Set linked ref to destination marker")
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
    
    ; Update slot tracking
    SlotStates[slot] = 1  ; traveling
    SlotPlaceNames[slot] = placeName
    SlotDestinations[slot] = destMarker
    SlotWaitDeadlines[slot] = waitUntil
    SlotSpeeds[slot] = speed
    
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

; =============================================================================
; PLACE RESOLUTION - Native Implementation
; =============================================================================

ObjectReference Function ResolvePlace(String placeName)
    {Convert a place name to a destination marker ObjectReference.
     Uses native O(1) hash lookup instead of O(n) JContainers iteration.}

    If !databaseLoaded
        DebugMsg("ERROR: ResolvePlace called but database not loaded")
        Return None
    EndIf

    ; Native function handles exact match, city aliases, and fuzzy search
    ObjectReference marker = SeverActionsNative.ResolvePlace(placeName)

    If marker == None
        DebugMsg("Could not resolve '" + placeName + "' to marker")
    Else
        DebugMsg("Resolved '" + placeName + "' to marker: " + marker)
    EndIf

    Return marker
EndFunction

String Function FindCellID(String placeName)
    {Find the cell editor ID for a given place name.
     Native implementation with O(1) hash lookup.}

    If !databaseLoaded
        Return ""
    EndIf

    Return SeverActionsNative.FindCellId(placeName)
EndFunction

ObjectReference Function GetMarkerForCell(String cellID)
    {Get the XMarker ObjectReference for a cell from the database.}

    If !databaseLoaded
        Return None
    EndIf

    Return SeverActionsNative.GetMarkerForCell(cellID)
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
    {Check if NPC in traveling slot has arrived at destination.}
    
    ReferenceAlias theAlias = GetAliasForSlot(slot)
    Actor npc
    ObjectReference dest
    Float dist
    String placeName
    
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
    
    dest = SlotDestinations[slot]
    
    ; If destination is None, try location-based check
    If dest == None
        ; Fall back to checking if NPC is in an interior cell matching destination
        DebugMsg("Slot " + slot + ": Destination is None, checking by location")
        ; For now, we can't do much without the destination reference
        ; This shouldn't happen if TravelToPlace succeeded
        Return
    EndIf
    
    ; Check distance - use 3D distance
    dist = npc.GetDistance(dest)
    
    If dist <= ArrivalDistance
        ; Arrived!
        placeName = SlotPlaceNames[slot]
        OnArrived(slot, npc, placeName)
    EndIf
EndFunction

Function OnArrived(Int slot, Actor akNPC, String placeName)
    {Handle NPC arrival at destination.}
    
    ; Remove travel package, apply sandbox
    RemoveAllTravelPackages(akNPC)
    
    ; Clear linked ref (no longer needed for travel)
    If TravelTargetKeyword
        PO3_SKSEFunctions.SetLinkedRef(akNPC, None, TravelTargetKeyword)
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
    {Check if player arrived or if NPC's patience ran out.}
    
    ReferenceAlias theAlias = GetAliasForSlot(slot)
    Actor npc
    Actor player
    Float currentTime
    Float deadline
    String placeName
    Bool playerNearby = false
    
    If theAlias == None
        ClearSlot(slot)
        Return
    EndIf
    
    npc = theAlias.GetActorReference()
    If npc == None || npc.IsDead()
        ClearSlot(slot)
        Return
    EndIf
    
    player = Game.GetPlayer()
    currentTime = Utility.GetCurrentGameTime()
    deadline = SlotWaitDeadlines[slot]
    placeName = SlotPlaceNames[slot]
    
    ; Check if player is nearby (same cell and close)
    If npc.GetParentCell() == player.GetParentCell()
        If npc.GetDistance(player) < 1000.0
            playerNearby = true
        EndIf
    EndIf
    
    If playerNearby
        ; Player arrived!
        OnPlayerArrived(slot, npc)
    ElseIf currentTime >= deadline
        ; Timeout!
        OnWaitTimeout(slot, npc)
    EndIf
EndFunction

Function OnPlayerArrived(Int slot, Actor akNPC)
    {Player arrived to meet the NPC.}
    
    StorageUtil.SetStringValue(akNPC, "SeverTravel_State", "complete")
    StorageUtil.SetStringValue(akNPC, "SeverTravel_Result", "player_arrived")
    
    NotifyPlayer(akNPC.GetDisplayName() + " is glad to see you!")
    
    ; Clear the slot - this will remove packages and restore follower status
    ClearSlot(slot, true)
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
    
    ; Explicitly zero everything
    i = 0
    While i < MAX_SLOTS
        SlotStates[i] = 0
        SlotPlaceNames[i] = ""
        SlotDestinations[i] = None
        SlotWaitDeadlines[i] = 0.0
        SlotSpeeds[i] = 0
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
    ; Native implementation: ~2000-10000x faster
    Return SeverActionsNative.StringToLower(s)
EndFunction

Bool Function StringContains(String haystack, String needle)
    ; Native implementation: ~2000x faster
    Return SeverActionsNative.StringContains(haystack, needle)
EndFunction

; =============================================================================
; DEBUG / TESTING API
; =============================================================================

Function TestMarkerResolution(String placeName)
    {Test function to verify marker resolution without starting travel.}
    
    If !databaseLoaded
        LoadMarkerDatabase()
    EndIf
    
    DebugMsg("Testing resolution for: " + placeName)
    
    String cellID = FindCellID(placeName)
    If cellID == ""
        DebugMsg("FAIL: Could not find cell ID")
        Return
    EndIf
    
    DebugMsg("Found cell ID: " + cellID)
    
    ObjectReference marker = GetMarkerForCell(cellID)
    If marker == None
        DebugMsg("FAIL: Could not get marker")
        Return
    EndIf
    
    DebugMsg("SUCCESS: Marker = " + marker + " at " + marker.GetPositionX() + ", " + marker.GetPositionY() + ", " + marker.GetPositionZ())
EndFunction

Function ShowStatus()
    {Display current travel system status.}
    
    DebugMsg("=== Travel System Status ===")
    DebugMsg("Database loaded: " + databaseLoaded)
    
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
