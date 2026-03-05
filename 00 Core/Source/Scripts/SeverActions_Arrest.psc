Scriptname SeverActions_Arrest extends Quest

{
    Guard Arrest System for SeverActions

    Allows guards to:
    - Add bounty to player for crimes
    - Arrest NPCs (same-cell) and escort them to jail
    - Dispatch guards cross-cell to arrest or investigate homes
    - Confront the player with persuasion options

    Self-contained travel logic - does not depend on SeverActions_Travel.

    Required CK Setup:
    - Factions: SeverActions_WaitingArrest, SeverActions_Arrested, SeverActions_Jailed,
                SeverActions_DispatchFaction
    - Keywords: SeverActions_FollowTargetKW, SeverActions_SandboxAnchorKW
    - Aliases on SeverActions quest:
        ArrestTarget, ArrestingGuard, JailDestination (same-cell arrest)
        DispatchGuardAlias, DispatchTargetAlias (cross-cell dispatch)
        DispatchPrisonerAlias, DispatchTravelDestination (dispatch support)
    - Packages:
        SeverActions_DispatchJog (Travel, Location=DispatchTargetAlias, Jog)
        SeverActions_DispatchWalk (Travel, Location=DispatchTargetAlias, Walk)
        SeverActions_GuardApproachTarget (Travel, Location=Alias ArrestTarget)
        SeverActions_GuardEscortPackage (Travel, Location=Alias JailDestination)
        SeverActions_FollowGuard_Prisoner (Follow, Target=LinkedRef w/ FollowTargetKW)
        SeverActions_PrisonerSandBox (Sandbox, Location=LinkedRef w/ SandboxAnchorKW)
        SeverActions_GuardFollowPlayer (Follow, Target=LinkedRef w/ FollowTargetKW)
    - Fill all properties in CK
}

; =============================================================================
; PROPERTIES - Factions (Create in CK)
; =============================================================================

Faction Property SeverActions_WaitingArrest Auto
{Faction for NPCs waiting to be arrested (in bleedout/subdued state)}

Faction Property SeverActions_Arrested Auto
{Faction for NPCs currently being escorted to jail}

Faction Property SeverActions_Jailed Auto
{Faction for NPCs who have been delivered to jail}

Faction Property dunPrisonerFaction Auto
{Vanilla faction - prevents guards from attacking prisoner. FormID: 0x0003B08B}

; =============================================================================
; PROPERTIES - Crime Factions (Vanilla - Fill in CK)
; =============================================================================

Faction Property CrimeFactionWhiterun Auto
Faction Property CrimeFactionRift Auto
Faction Property CrimeFactionHaafingar Auto
Faction Property CrimeFactionEastmarch Auto
Faction Property CrimeFactionReach Auto
Faction Property CrimeFactionFalkreath Auto
Faction Property CrimeFactionPale Auto
Faction Property CrimeFactionHjaalmarch Auto
Faction Property CrimeFactionWinterhold Auto

; =============================================================================
; PROPERTIES - Guard Factions (Vanilla - Fill in CK)
; =============================================================================

Faction Property GuardFactionWhiterun Auto
{Guard faction for Whiterun Hold guards}
Faction Property GuardFactionRiften Auto
{Guard faction for Riften / The Rift guards}
Faction Property GuardFactionSolitude Auto
{Guard faction for Solitude guards}
Faction Property GuardFactionHaafingar Auto
{Guard faction for Haafingar Hold guards}
Faction Property GuardFactionWindhelm Auto
{Guard faction for Windhelm / Eastmarch guards}
Faction Property GuardFactionMarkarth Auto
{Guard faction for Markarth / The Reach guards}
Faction Property GuardFactionFalkreath Auto
{Guard faction for Falkreath Hold guards}
Faction Property GuardFactionDawnstar Auto
{Guard faction for Dawnstar / The Pale guards}
Faction Property GuardFactionWinterhold Auto
{Guard faction for Winterhold Hold guards}

; =============================================================================
; PROPERTIES - Keywords & Packages (Create in CK)
; =============================================================================

Keyword Property SeverActions_EscortTargetKeyword Auto
{LEGACY — no longer used. All 31 usages replaced by purpose-specific keywords below.
 Can be deleted from ESP in future cleanup.}

Keyword Property SeverActions_FollowTargetKW Auto
{Keyword for follow packages — prisoner follows guard, guard follows sender in judgment.
 Replaces EscortTargetKeyword for all follow-type linked refs.}

Keyword Property SeverActions_SandboxAnchorKW Auto
{Keyword for sandbox packages — prisoner sandboxes near jail marker, guard sandboxes at home.
 Replaces EscortTargetKeyword for all sandbox-type linked refs.}

Package Property SeverActions_DispatchTravel Auto
{Travel package for cross-cell dispatch - guard/prisoner travels to DispatchTravelDestination alias.
Setup in CK: Type=Travel, Location=DispatchTravelDestination alias, Speed=Jog}

Package Property SeverActions_GuardApproachTarget Auto
{Travel package for guard to walk to ArrestTarget alias (approach phase).
 Used by same-cell ArrestNPC_Internal. Dispatch uses DispatchJog/DispatchWalk instead.}

Package Property SeverActions_GuardEscortPackage Auto
{Travel package for guard to walk to JailDestination alias (escort to jail phase)}

Package Property SeverActions_FollowGuard_Prisoner Auto
{Follow package for prisoner - follows their linked ref (the guard).
Setup: Type=Follow, Follow Target=Linked Ref with SeverActions_FollowTargetKW}

Package Property SeverActions_PrisonerSandBox Auto
{Sandbox package for prisoners in jail - sandboxes near their linked ref (jail marker).
Setup: Type=Sandbox, Location=Linked Ref with SeverActions_SandboxAnchorKW}

Package Property SeverActions_DispatchJog Auto
{Jog-speed travel to DispatchTargetAlias. Used for outbound dispatch (urgency).
CK: Travel package, Location=DispatchTargetAlias, Speed=Jog}

Package Property SeverActions_DispatchWalk Auto
{Walk-speed travel to DispatchTargetAlias. Used for return journey (escorting).
CK: Travel package, Location=DispatchTargetAlias, Speed=Walk}

; =============================================================================
; PROPERTIES - Items & Outfits (Vanilla or Create in CK)
; =============================================================================

Armor Property SeverActions_PrisonerCuffs Auto
{Bound hands armor item. Can use vanilla or create custom.}

Armor Property SeverActions_PrisonerRags Auto
{Prison clothing. Can use vanilla ClothesJailor or create custom.}

Outfit Property SeverActions_PrisonerOutfit Auto
{Outfit containing prison clothes. Setting this on the NPC makes it persist through cell reloads.
Create an Outfit in CK containing the prison rags.}

MiscObject Property Gold001 Auto
{Gold coin - set to Gold001 (0x0000000F) in CK, or leave empty for auto-lookup}

; =============================================================================
; PROPERTIES - Idle Animation (Vanilla)
; =============================================================================

Idle Property OffsetBoundStandingStart Auto
{Vanilla idle for bound standing pose}

Idle Property IdleGive Auto
{Vanilla idle for give/hand-over gesture - used when freeing prisoners}

; =============================================================================
; PROPERTIES - Jail Markers (Interior cell XMarkers - must set in CK)
; The faction's crimeData.factionJailMarker is an EXTERIOR marker (where player
; teleports when choosing jail), not the actual cell interior. These must be
; placed manually inside each jail cell.
; =============================================================================

ObjectReference Property JailMarker_Whiterun Auto
{XMarker inside Dragonsreach Dungeon jail cell}

ObjectReference Property JailMarker_Riften Auto
{XMarker inside Riften Jail cell}

ObjectReference Property JailMarker_Solitude Auto
{XMarker inside Castle Dour Dungeon cell}

ObjectReference Property JailMarker_Windhelm Auto
{XMarker inside Windhelm Bloodworks jail cell}

ObjectReference Property JailMarker_Markarth Auto
{XMarker inside Cidhna Mine}

ObjectReference Property JailMarker_Falkreath Auto
{XMarker inside Falkreath Jail cell}

ObjectReference Property JailMarker_Dawnstar Auto
{XMarker inside Dawnstar Barracks jail cell}

ObjectReference Property JailMarker_Morthal Auto
{XMarker inside Morthal Guardhouse jail cell}

ObjectReference Property JailMarker_Winterhold Auto
{XMarker inside The Chill}

; =============================================================================
; PROPERTIES - Task Faction (Create in CK)
; =============================================================================

Faction Property SeverActions_DispatchFaction Auto
{Faction added to guard at dispatch start, removed at Complete/Cancel.
 Checked by YAML eligibility rules to prevent SkyrimNet re-tasking a dispatched guard.}

; =============================================================================
; PROPERTIES - Reference Aliases (Create in Quest)
; =============================================================================

ReferenceAlias Property ArrestTarget Auto
{Reference alias for the NPC being approached/arrested by same-cell arrest.
 Guard approach package (GuardApproachTarget) targets this.
 NOT used by cross-cell dispatch — dispatch uses DispatchTargetAlias instead.}

ReferenceAlias Property JailDestination Auto
{Reference alias for the jail marker. Guard escort package targets this.}

ReferenceAlias Property ArrestingGuard Auto
{Reference alias for the guard performing same-cell arrest.
 NOT used by cross-cell dispatch — dispatch uses DispatchGuardAlias instead.}

ReferenceAlias Property DispatchGuardAlias Auto
{Dedicated alias for the dispatch guard. Keeps guard in high-process during
 cross-cell travel. Separated from ArrestingGuard to prevent clobbering
 if same-cell arrest runs while dispatch is active.}

ReferenceAlias Property DispatchTargetAlias Auto
{Dedicated alias for the dispatch target/destination. Holds the target NPC
 (arrest dispatch) or home marker (home investigation). DispatchJog and
 DispatchWalk packages target this alias. Separated from ArrestTarget to
 prevent clobbering during Phase 5 return (no more repurposing).}

ReferenceAlias Property DispatchPrisonerAlias Auto
{Reference alias for the prisoner during dispatch Phase 5.
Keeps the prisoner in high-process while unloaded so their AI packages
(travel/follow) continue to execute off-screen. Filled at arrest time,
cleared at dispatch completion. Create in CK as an empty reference alias.}

ReferenceAlias Property DispatchTravelDestination Auto
{Reference alias for the DispatchTravel package destination.
The DispatchTravel package targets this alias instead of a linked ref,
so the engine natively tracks the destination across cells.
Used by guard for evidence approach (Phase 3/4).
Create in CK as an empty reference alias and set DispatchTravel package
location to this alias.}

; =============================================================================
; PROPERTIES - Cross-Script References
; =============================================================================

SeverActions_Travel Property TravelSystem Auto
{Reference to the travel quest/script. Used by guard dispatch to send guards across cells.
Set in CK: point to the SeverActions quest running SeverActions_Travel.}

; =============================================================================
; PROPERTIES - Settings
; =============================================================================

Float Property ApproachDistance = 150.0 Auto
{Distance guard needs to be from target to perform arrest}

Float Property ArrivalDistance = 500.0 Auto
{Distance to consider guard arrived at jail}

Float Property DispatchArrivalDistance = 1500.0 Auto
{Distance to consider dispatch guard arrived at destination (larger than ArrivalDistance to account for cross-cell pathfinding)}

Float Property UpdateInterval = 1.0 Auto
{How often to check progress (seconds)}

Int Property PackagePriority = 100 Auto
{Priority for arrest packages}

Bool Property EnableDebugMessages = true Auto
{Show debug notifications in-game}

Bool Property DisablePrisonerOnArrival = false Auto
{If true, disable prisoner after jailing. If false, they sandbox in jail (recommended).}

; =============================================================================
; PROPERTIES - Player Arrest Settings
; =============================================================================

Int Property ArrestBountyThreshold = 300 Auto
{Minimum bounty required for arrest option. Below this, guard demands fine payment only.}

Float Property BribeMultiplier = 1.5 Auto
{Multiplier for bribe cost (bounty * multiplier)}

Float Property PersuasionTimeLimit = 90.0 Auto
{Time in seconds player has to convince guard during persuasion}

Float Property PersuasionFollowDistance = 300.0 Auto
{Max distance guard will follow player during persuasion before giving up}

Int Property ResistBountyIncrease = 500 Auto
{Additional bounty added when player resists arrest}

Float Property ArrestPlayerCooldown = 60.0 Auto
{Cooldown in seconds before ArrestPlayer can be used again after a confrontation starts}

Package Property SeverActions_GuardFollowPlayer Auto
{Follow package for guard during persuasion - follows linked ref (player).
Setup: Type=Follow, Follow Target=Linked Ref with SeverActions_FollowTargetKW}

; =============================================================================
; STATE TRACKING
; =============================================================================

; Active arrest tracking (supports one arrest at a time for simplicity)
Actor CurrentGuard
Actor CurrentPrisoner
ObjectReference CurrentJailMarker
String CurrentJailName
Int ArrestState ; 0=none, 1=approaching, 2=arresting, 3=escorting, 4=arrived

; Jailed NPC tracking (for freeing later)
Actor[] JailedNPCs

; Player arrest state tracking
Actor ConfrontingGuard          ; Guard currently confronting player
Faction ConfrontingFaction      ; Crime faction for current confrontation
Int ConfrontingBounty           ; Bounty amount at time of confrontation
Bool PersuadeAttempted          ; True if player already tried persuade (can't retry)
Bool PaymentFailed              ; True if player tried to pay/bribe but couldn't afford it
Bool InPersuasionMode           ; True if currently in persuasion conversation
Float PersuasionStartTime       ; Game time when persuasion started
Float LastArrestTime            ; Real time when last arrest confrontation started (for cooldown)
Float LastNPCArrestTime         ; Real time when last NPC arrest started (for cooldown)

; Cross-cell dispatch state (self-contained system - does NOT use TravelSystem)
; Dispatch phases:
;   0 = inactive
;   1 = traveling directly to target Actor or home (AI handles cross-cell pathfinding)
;   2 = approaching target for arrest (same cell, within range)
;   3 = sandboxing at target's home (investigating)
;   4 = collecting evidence (picking up item at home)
;   5 = returning with prisoner or evidence (escorting to jail or bringing evidence/prisoner to sender)
;   6 = judgment hold (prisoner presented to sender, awaiting OrderRelease or OrderJailed)
Int DispatchPhase
Actor DispatchTarget                    ; The NPC to arrest / investigate
Actor DispatchGuard                     ; The guard doing the arresting (separate from CurrentGuard for escort phase)
ObjectReference DispatchReturnMarker    ; Final destination marker (jail marker, Jarl, or sender)
Float DispatchOffScreenStartTime        ; Real time when guard left player's loaded area
Float DispatchGameTimeStart             ; Game time when dispatch began (for timeout)
Float DispatchInitialDistance           ; Distance (units) between guard and target at dispatch start (for time-skip calc when cross-cell)
Bool DispatchGuardOffScreen             ; True if guard is currently off-screen
String DispatchTargetLocation           ; Cached location name for the target

; Judgment hold state (Phase 6 - prisoner presented to sender for decision)
Float JudgmentStartTime                ; Real time when judgment phase started
Float JudgmentTimeLimit = 90.0         ; Seconds before defaulting to jail

; Home investigation state (DispatchGuardToHome)
Bool DispatchIsHomeInvestigation        ; True if this is a home investigation (not an arrest dispatch)
ObjectReference DispatchHomeMarker      ; The NPC's home destination (interior marker if found, exterior door fallback)
Actor DispatchSender                    ; Who sent the guard (for return destination)
String DispatchInvestigationReason      ; Why the investigation was ordered (e.g. "dibella worship", "thieving") - used for evidence generation
Float DispatchSandboxStartTime          ; Real time when sandbox investigation started
Float DispatchSandboxDuration           ; How long to sandbox at home (seconds, randomized 15-30)
ObjectReference DispatchEvidenceItem    ; The world reference picked up as evidence (consumed after AddItem)
Form DispatchEvidenceForm               ; The base form of the evidence item (persists after pickup)
String DispatchEvidenceName             ; Display name of the evidence item (cached at pickup time)

; Guard original AI values (for restoring after dispatch)
Float DispatchGuardOrigAggression = 0.0
Float DispatchGuardOrigConfidence = 0.0

; Off-screen return tracking — counts how many off-screen cycles have fired in Phase 5
Int DispatchReturnOffScreenCycle = 0
Bool DispatchReturnNarrated = false       ; True once the "guard returning with prisoner" on-screen narration has fired
Float DispatchStuckGraceUntil = 0.0      ; Real time until which stuck detection is suppressed (grace period after cell transitions)
ObjectReference DispatchUnlockedDoor = None ; Door unlocked for home investigation (re-locked on cleanup)

; Deferred narration state (narration stored on sender when player not present)
Actor DeferredNarrationSender = None


; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    Debug.Trace("[SeverActions_Arrest] Initialized")
    Maintenance()
EndEvent

Function Maintenance()
    {Auto-lookup forms if not set in CK, register for game load events}
    if Gold001 == None
        Gold001 = Game.GetFormFromFile(0x0000000F, "Skyrim.esm") as MiscObject
        if Gold001 == None
            Debug.Trace("[SeverActions_Arrest] ERROR: Could not find Gold001!")
        else
            Debug.Trace("[SeverActions_Arrest] Gold001 found via auto-lookup")
        endif
    endif

    ; Auto-lookup vanilla guard factions if not set in CK
    if GuardFactionWhiterun == None
        GuardFactionWhiterun = Game.GetFormFromFile(0x0002BE39, "Skyrim.esm") as Faction
    endif
    if GuardFactionRiften == None
        GuardFactionRiften = Game.GetFormFromFile(0x000D27F2, "Skyrim.esm") as Faction
    endif
    if GuardFactionSolitude == None
        GuardFactionSolitude = Game.GetFormFromFile(0x0002EBEE, "Skyrim.esm") as Faction
    endif
    if GuardFactionHaafingar == None
        GuardFactionHaafingar = Game.GetFormFromFile(0x000367BA, "Skyrim.esm") as Faction
    endif
    if GuardFactionWindhelm == None
        GuardFactionWindhelm = Game.GetFormFromFile(0x000D27F3, "Skyrim.esm") as Faction
    endif
    if GuardFactionMarkarth == None
        GuardFactionMarkarth = Game.GetFormFromFile(0x00018AAC, "Skyrim.esm") as Faction
    endif
    if GuardFactionFalkreath == None
        GuardFactionFalkreath = Game.GetFormFromFile(0x0002EBEC, "Skyrim.esm") as Faction
    endif
    if GuardFactionDawnstar == None
        GuardFactionDawnstar = Game.GetFormFromFile(0x0003B693, "Skyrim.esm") as Faction
    endif
    ; GuardFactionWinterhold has no vanilla faction — left None (handled by null check in FindNearestGuard)

    Int guardCount = 0
    if GuardFactionWhiterun != None
        guardCount += 1
    endif
    if GuardFactionRiften != None
        guardCount += 1
    endif
    if GuardFactionSolitude != None
        guardCount += 1
    endif
    if GuardFactionHaafingar != None
        guardCount += 1
    endif
    if GuardFactionWindhelm != None
        guardCount += 1
    endif
    if GuardFactionMarkarth != None
        guardCount += 1
    endif
    if GuardFactionFalkreath != None
        guardCount += 1
    endif
    if GuardFactionDawnstar != None
        guardCount += 1
    endif
    Debug.Trace("[SeverActions_Arrest] Guard factions resolved: " + guardCount + "/8 vanilla")

    ; Register for game load event to verify prisoner positions
    RegisterForModEvent("OnPlayerLoadGame", "OnPlayerLoadGame")

    ; Register for player cell change to verify prisoners after fast travel
    RegisterForTrackedStatsEvent()
EndFunction

Event OnPlayerLoadGame()
    {Called when player loads a saved game. Verify prisoners, recover active dispatch,
     and restore deferred narration sender if one was pending.}
    Debug.Trace("[SeverActions_Arrest] Game loaded - verifying prisoner positions and dispatch state")
    VerifyJailedNPCs()
    RecoverActiveDispatch()

    ; Recover deferred narration sender (survives save/load via StorageUtil)
    ; Recover deferred narration sender (survives save/load via StorageUtil)
    Form deferredForm = StorageUtil.GetFormValue(Self, "SeverActions_DeferredSender", None)
    If deferredForm != None
        DeferredNarrationSender = deferredForm as Actor
        If DeferredNarrationSender != None && !DeferredNarrationSender.IsDead()
            Debug.Trace("[SeverActions_Arrest] Recovered deferred narration sender: " + DeferredNarrationSender.GetDisplayName())
            RegisterForSingleUpdate(UpdateInterval)
        Else
            ; Sender invalid or dead — clean up
            ClearDeferredNarration()
        EndIf
    EndIf
EndEvent

Event OnTrackedStatsEvent(String asStat, Int aiValue)
    {Use tracked stats as proxy for game activity - verify on location discovery or fast travel count changes}
    If asStat == "Locations Discovered" || asStat == "Days Passed"
        ; Verify prisoner positions after fast travel/time passage
        VerifyJailedNPCs()
    EndIf
EndEvent

; =============================================================================
; MAIN API - ArrestNPC
; =============================================================================

Bool Function ArrestNPC_Internal(Actor akGuard, Actor akTarget)
    {Main arrest function called by SkyrimNet action.
     Guard will walk up to target, arrest them, then escort to jail.
     Returns true if arrest sequence started successfully.}

    ; Validate inputs
    If akGuard == None
        DebugMsg("ERROR: ArrestNPC called with None guard")
        Return false
    EndIf

    If akTarget == None
        DebugMsg("ERROR: ArrestNPC called with None target")
        Return false
    EndIf

    If akTarget == Game.GetPlayer()
        DebugMsg("ERROR: Cannot arrest player with this function - use ArrestPlayer")
        Return false
    EndIf

    If akGuard.IsDead() || akTarget.IsDead()
        DebugMsg("ERROR: Guard or target is dead")
        Return false
    EndIf

    ; Check cooldown (300 seconds / 5 minutes)
    Float currentTime = Utility.GetCurrentRealTime()
    If (currentTime - LastNPCArrestTime) < 300.0
        DebugMsg("ArrestNPC on cooldown, ignoring (" + (300.0 - (currentTime - LastNPCArrestTime)) + "s remaining)")
        Return false
    EndIf

    ; Check if already processing an arrest
    If ArrestState != 0
        DebugMsg("WARNING: Already processing an arrest, canceling previous")
        CancelCurrentArrest()
    EndIf

    ; Block if target is already arrested or being escorted
    If akTarget.IsInFaction(SeverActions_Arrested) || akTarget.IsInFaction(SeverActions_Jailed)
        DebugMsg("ArrestNPC rejected: target already arrested or jailed")
        Return false
    EndIf

    ; Determine jail destination based on guard's crime faction
    ObjectReference jailMarker = GetJailMarkerForGuard(akGuard)
    String jailName = GetJailNameForGuard(akGuard)

    If jailMarker == None
        DebugMsg("ERROR: Could not determine jail marker for guard - check properties!")
        Return false
    EndIf

    DebugMsg("Starting arrest: " + akGuard.GetDisplayName() + " arresting " + akTarget.GetDisplayName())
    DebugMsg("Destination: " + jailName)

    ; Store state
    CurrentGuard = akGuard
    CurrentPrisoner = akTarget
    CurrentJailMarker = jailMarker
    CurrentJailName = jailName
    ArrestState = 1 ; approaching
    LastNPCArrestTime = Utility.GetCurrentRealTime() ; Set cooldown timer

    ; Draw weapon initially (packages may override this - see CK package flags)
    akGuard.DrawWeapon()

    ; Check if already close enough
    Float dist = akGuard.GetDistance(akTarget)
    If dist <= ApproachDistance
        ; Already close, skip approach phase
        DebugMsg("Guard already close to target, proceeding to arrest")
        PerformArrest()
    Else
        ; Start approach phase
        DebugMsg("Guard approaching target (distance: " + dist + ")")
        StartApproachPhase()
    EndIf

    Return true
EndFunction

; =============================================================================
; APPROACH PHASE - Guard walks to target
; =============================================================================

Function StartApproachPhase()
    {Guard walks toward target with weapon drawn.
     Includes stuck detection for cross-cell approaches.}

    If CurrentGuard == None || CurrentPrisoner == None
        DebugMsg("ERROR: StartApproachPhase - invalid state")
        Return
    EndIf

    ; Fill reference aliases for approach
    ArrestTarget.ForceRefTo(CurrentPrisoner)
    ArrestingGuard.ForceRefTo(CurrentGuard)

    DebugMsg("Filled ArrestTarget alias with: " + CurrentPrisoner.GetDisplayName())

    ; Apply approach package to guard (targets ArrestTarget alias)
    If SeverActions_GuardApproachTarget
        ActorUtil.AddPackageOverride(CurrentGuard, SeverActions_GuardApproachTarget, PackagePriority, 1)
        CurrentGuard.EvaluatePackage()
        DebugMsg("Applied approach package to guard")
    Else
        DebugMsg("WARNING: No approach package defined!")
    EndIf

    ; Start stuck detection for long-distance approaches
    SeverActionsNative.Stuck_StartTracking(CurrentGuard)

    ; Start monitoring for arrival
    RegisterForSingleUpdate(UpdateInterval)
EndFunction

Event OnUpdate()
    ; Check current state and act accordingly
    Bool needsUpdate = false

    ; --- Deferred evidence narration (player approaches sender) ---
    If DeferredNarrationSender != None
        If DeferredNarrationSender.IsDead()
            ClearDeferredNarration()
        Else
            Actor playerRef = Game.GetPlayer()
            If playerRef.Is3DLoaded() && DeferredNarrationSender.Is3DLoaded() && playerRef.GetDistance(DeferredNarrationSender) <= 300.0
                ; Player approached sender — fire the stored narration
                String pendingNarration = StorageUtil.GetStringValue(DeferredNarrationSender, "SeverActions_PendingEvidenceNarration", "")
                If pendingNarration != ""
                    SkyrimNetApi.DirectNarration(pendingNarration, DeferredNarrationSender, playerRef)
                    DebugMsg("Fired deferred evidence narration from " + DeferredNarrationSender.GetDisplayName())
                EndIf
                ClearDeferredNarration()
            Else
                needsUpdate = true
            EndIf
        EndIf
    EndIf

    ; Cross-cell dispatch phases (1=traveling to door, 2=entering door, 3=approaching in same cell)
    If DispatchPhase > 0
        CheckDispatchProgress()
    EndIf

    ; NPC arrest states
    If ArrestState == 1
        ; Approaching target
        CheckApproachProgress()
    ElseIf ArrestState == 3
        ; Escorting to jail
        CheckEscortProgress()
    EndIf

    ; Player persuasion mode
    If InPersuasionMode
        CheckPersuasionProgress()
    EndIf

    ; Keep OnUpdate running if linger or deferred narration is still active
    ; (dispatch/arrest/persuasion handlers register their own updates)
    If needsUpdate && DispatchPhase == 0 && ArrestState == 0 && !InPersuasionMode
        RegisterForSingleUpdate(UpdateInterval)
    EndIf
EndEvent

Function CheckApproachProgress()
    {Check if guard has reached the target.
     Includes stuck detection with progressive recovery for cross-cell approaches.}

    Float dist
    Int stuckLevel
    Float teleportDist
    Float guardX
    Float guardY
    Float targetX
    Float targetY
    Float dx
    Float dy
    Float dist2d
    Float moveX
    Float moveY

    If CurrentGuard == None || CurrentPrisoner == None
        DebugMsg("ERROR: CheckApproachProgress - invalid state")
        CancelCurrentArrest()
        Return
    EndIf

    ; Check if guard or prisoner died
    If CurrentGuard.IsDead()
        DebugMsg("Guard died during approach")
        SeverActionsNative.Stuck_StopTracking(CurrentGuard)
        CancelCurrentArrest()
        Return
    EndIf

    If CurrentPrisoner.IsDead()
        DebugMsg("Target died during approach")
        SeverActionsNative.Stuck_StopTracking(CurrentGuard)
        CancelCurrentArrest()
        Return
    EndIf

    dist = CurrentGuard.GetDistance(CurrentPrisoner)

    If dist <= ApproachDistance
        ; Arrived at target - perform arrest
        DebugMsg("Guard reached target, performing arrest")
        SeverActionsNative.Stuck_StopTracking(CurrentGuard)

        ; Remove approach package
        If SeverActions_GuardApproachTarget
            ActorUtil.RemovePackageOverride(CurrentGuard, SeverActions_GuardApproachTarget)
        EndIf

        PerformArrest()
    Else
        ; Not arrived yet - check for stuck (helps with cross-cell approaches)
        stuckLevel = SeverActionsNative.Stuck_CheckStatus(CurrentGuard, UpdateInterval, 50.0)

        If stuckLevel == 1
            ; Possibly stuck - re-evaluate packages
            DebugMsg("Approach: guard may be stuck, re-evaluating packages")
            CurrentGuard.EvaluatePackage()
        ElseIf stuckLevel == 2
            ; Stuck - leapfrog toward target
            teleportDist = SeverActionsNative.Stuck_GetTeleportDistance(CurrentGuard)
            guardX = CurrentGuard.GetPositionX()
            guardY = CurrentGuard.GetPositionY()
            targetX = CurrentPrisoner.GetPositionX()
            targetY = CurrentPrisoner.GetPositionY()
            dx = targetX - guardX
            dy = targetY - guardY
            dist2d = Math.sqrt(dx * dx + dy * dy)

            If dist2d > 0.0
                moveX = (dx / dist2d) * teleportDist
                moveY = (dy / dist2d) * teleportDist
                CurrentGuard.MoveTo(CurrentGuard, moveX, moveY, 0.0)
                CurrentGuard.EvaluatePackage()
                DebugMsg("Approach: leapfrog guard " + teleportDist + " units toward target")
            EndIf

            SeverActionsNative.Stuck_ResetEscalation(CurrentGuard)
        ElseIf stuckLevel >= 3
            ; Very stuck - force teleport near target
            DebugMsg("Approach: force teleporting guard near target")
            CurrentGuard.MoveTo(CurrentPrisoner, 200.0, 0.0, 0.0)
            Utility.Wait(0.5)
            CurrentGuard.EvaluatePackage()
            SeverActionsNative.Stuck_ResetEscalation(CurrentGuard)
        EndIf

        ; Still approaching, keep checking
        RegisterForSingleUpdate(UpdateInterval)
    EndIf
EndFunction

; =============================================================================
; ARREST PHASE - Subdue and restrain target
; =============================================================================

Function PerformArrest()
    {Actually arrest the target - pacify, cuff, prepare for escort}

    If CurrentGuard == None || CurrentPrisoner == None
        DebugMsg("ERROR: PerformArrest - invalid state")
        CancelCurrentArrest()
        Return
    EndIf

    ArrestState = 2 ; arresting

    Actor prisoner = CurrentPrisoner
    Actor guard = CurrentGuard

    DebugMsg("Performing arrest on " + prisoner.GetDisplayName())

    ; Stop any combat
    prisoner.StopCombat()
    prisoner.StopCombatAlarm()

    ; Cancel any active travel errand so it doesn't fight with arrest escort
    If TravelSystem != None
        TravelSystem.CancelTravel(prisoner)
    EndIf

    ; Pacify the prisoner
    prisoner.SetAV("Aggression", 0)
    prisoner.SetAV("Confidence", 0)

    ; Add to factions
    prisoner.AddToFaction(dunPrisonerFaction)      ; Guards won't attack
    prisoner.AddToFaction(SeverActions_Arrested)   ; Triggers follow package

    ; Equip restraints
    If SeverActions_PrisonerCuffs
        prisoner.EquipItem(SeverActions_PrisonerCuffs, true, true) ; abPreventRemoval, abSilent
    EndIf

    ; Play bound idle animation
    If OffsetBoundStandingStart
        prisoner.PlayIdle(OffsetBoundStandingStart)
    EndIf

    ; Reduce healing so they stay subdued
    prisoner.SetAV("HealRate", 0.1)

    ; Link prisoner to guard so follow package works
    PO3_SKSEFunctions.SetLinkedRef(prisoner, guard, SeverActions_FollowTargetKW)
    DebugMsg("Linked prisoner to guard for follow")

    ; Break any animation lock from PlayIdle before activating follow package
    Debug.SendAnimationEvent(prisoner, "IdleForceDefaultState")
    Utility.Wait(0.1)

    ; Apply follow package to prisoner
    If SeverActions_FollowGuard_Prisoner
        ActorUtil.AddPackageOverride(prisoner, SeverActions_FollowGuard_Prisoner, PackagePriority, 1)
        prisoner.EvaluatePackage()
        DebugMsg("Applied follow package to prisoner")
    EndIf

    ; Notification
    Debug.Notification(guard.GetDisplayName() + " arrested " + prisoner.GetDisplayName())

    ; Direct narration for prisoner to react to being arrested
    String narration = "*" + guard.GetDisplayName() + " places " + prisoner.GetDisplayName() + " under arrest and binds their hands.*"
    SkyrimNetApi.DirectNarration(narration, prisoner, guard)

    ; Register persistent event for SkyrimNet - guard arrested prisoner
    String arrestMessage = guard.GetDisplayName() + " has arrested " + prisoner.GetDisplayName() + " and is escorting them to " + CurrentJailName + "."
    SkyrimNetApi.RegisterPersistentEvent(arrestMessage, guard, None)

    ; Small delay for animations/packages to settle
    Utility.Wait(1.0)

    ; Start escort phase
    StartEscortPhase()
EndFunction

; =============================================================================
; ESCORT PHASE - Guard travels to jail, prisoner follows
; =============================================================================

Function StartEscortPhase()
    {Guard travels to jail with prisoner following via separate packages}

    If CurrentGuard == None || CurrentPrisoner == None || CurrentJailMarker == None
        DebugMsg("ERROR: StartEscortPhase - invalid state")
        CancelCurrentArrest()
        Return
    EndIf

    ArrestState = 3 ; escorting

    Debug.Notification(CurrentGuard.GetDisplayName() + " is escorting " + CurrentPrisoner.GetDisplayName() + " to " + CurrentJailName)
    DebugMsg("Starting escort to " + CurrentJailName)

    ; Fill JailDestination alias with the jail marker
    JailDestination.ForceRefTo(CurrentJailMarker)
    DebugMsg("Filled JailDestination alias with: " + CurrentJailMarker)

    ; Apply travel package to guard (targets JailDestination alias)
    If SeverActions_GuardEscortPackage
        ActorUtil.AddPackageOverride(CurrentGuard, SeverActions_GuardEscortPackage, PackagePriority, 1)
        CurrentGuard.EvaluatePackage()
        DebugMsg("Applied travel package to guard")
    Else
        DebugMsg("WARNING: No guard travel package defined!")
    EndIf

    ; Start monitoring for arrival
    RegisterForSingleUpdate(UpdateInterval)
EndFunction

Function CheckEscortProgress()
    {Check if guard has arrived at jail}

    If CurrentGuard == None || CurrentPrisoner == None || CurrentJailMarker == None
        DebugMsg("ERROR: CheckEscortProgress - invalid state")
        CancelCurrentArrest()
        Return
    EndIf

    ; Check if guard or prisoner died during escort
    If CurrentGuard.IsDead()
        DebugMsg("Guard died during escort")
        ReleasePrisoner(CurrentPrisoner)
        CancelCurrentArrest()
        Return
    EndIf

    If CurrentPrisoner.IsDead()
        DebugMsg("Prisoner died during escort")
        CancelCurrentArrest()
        Return
    EndIf

    ; Re-apply prisoner follow package each tick — Skyrim's AI can drop overrides
    If SeverActions_FollowGuard_Prisoner
        ActorUtil.AddPackageOverride(CurrentPrisoner, SeverActions_FollowGuard_Prisoner, PackagePriority, 1)
        CurrentPrisoner.EvaluatePackage()
    EndIf

    ; Check distance to jail marker
    Float dist = CurrentGuard.GetDistance(CurrentJailMarker)

    If dist <= ArrivalDistance
        ; Arrived at jail
        DebugMsg("Guard arrived at jail (distance: " + dist + ")")
        OnArrivedAtJail()
    Else
        ; Still traveling
        RegisterForSingleUpdate(UpdateInterval)
    EndIf
EndFunction

; =============================================================================
; ARRIVAL - Process prisoner at jail
; =============================================================================

Function OnArrivedAtJail()
    {Guard and prisoner have arrived at jail - finalize arrest}

    If CurrentGuard == None || CurrentPrisoner == None
        DebugMsg("ERROR: OnArrivedAtJail - invalid state")
        CancelCurrentArrest()
        Return
    EndIf

    ArrestState = 4 ; arrived

    ; Store local references before clearing state
    Actor prisoner = CurrentPrisoner
    Actor guard = CurrentGuard
    ObjectReference jailMarker = CurrentJailMarker
    String jailName = CurrentJailName

    DebugMsg("Processing prisoner at jail: " + prisoner.GetDisplayName())

    ; Remove guard's travel package
    If SeverActions_GuardEscortPackage
        ActorUtil.RemovePackageOverride(guard, SeverActions_GuardEscortPackage)
    EndIf

    ; Remove prisoner's follow package
    If SeverActions_FollowGuard_Prisoner
        ActorUtil.RemovePackageOverride(prisoner, SeverActions_FollowGuard_Prisoner)
    EndIf

    ; Clear prisoner's linked ref to guard (was used for follow)
    PO3_SKSEFunctions.SetLinkedRef(prisoner, None, SeverActions_FollowTargetKW)

    ; Clear reference aliases
    ArrestTarget.Clear()
    JailDestination.Clear()
    ArrestingGuard.Clear()
    If DispatchPrisonerAlias != None
        DispatchPrisonerAlias.Clear()
    EndIf
    If DispatchTravelDestination != None
        DispatchTravelDestination.Clear()
    EndIf

    ; Update factions
    prisoner.RemoveFromFaction(SeverActions_Arrested)
    prisoner.AddToFaction(SeverActions_Jailed)

    ; Move prisoner to jail cell with verification
    ; MoveTo can fail silently when player is in a different cell
    If jailMarker
        ; First attempt
        prisoner.MoveTo(jailMarker, 0.0, 0.0, 0.0)
        Utility.Wait(0.5)

        ; Verify the move worked - check if prisoner is near the jail marker
        Float distToJail = prisoner.GetDistance(jailMarker)
        Int attempts = 1

        ; If prisoner is too far from jail marker, retry the teleport
        While distToJail > 500.0 && attempts < 5
            DebugMsg("MoveTo failed (distance: " + distToJail + "), retrying attempt " + (attempts + 1))

            ; Try disabling and re-enabling to force cell load
            prisoner.Disable()
            Utility.Wait(0.1)
            prisoner.MoveTo(jailMarker, 0.0, 0.0, 0.0)
            Utility.Wait(0.1)
            prisoner.Enable()
            Utility.Wait(0.5)

            distToJail = prisoner.GetDistance(jailMarker)
            attempts += 1
        EndWhile

        If distToJail <= 500.0
            DebugMsg("Moved prisoner to jail marker (distance: " + distToJail + ", attempts: " + attempts + ")")
        Else
            DebugMsg("WARNING: Failed to move prisoner to jail after " + attempts + " attempts (distance: " + distToJail + ")")
        EndIf
    EndIf

    ; Change to prison clothes (use faction's jail outfit if available)
    Faction crimeFaction = GetCrimeFactionForGuard(guard)
    ChangeToJailClothes(prisoner, crimeFaction)

    ; Track this jailed NPC and store their jail marker for verification later
    AddJailedNPC(prisoner)
    StorageUtil.SetFormValue(prisoner, "SeverActions_JailMarker", jailMarker)

    If DisablePrisonerOnArrival
        ; Simple approach: just disable the prisoner
        ; They're "in jail" but removed from the world
        Utility.Wait(0.5)
        prisoner.Disable()
        DebugMsg("Prisoner disabled (jailed)")
    Else
        ; Keep prisoner active with sandbox package
        If SeverActions_PrisonerSandBox && jailMarker
            ; Link prisoner to their jail marker for sandbox (per-actor, supports multiple prisoners)
            PO3_SKSEFunctions.SetLinkedRef(prisoner, jailMarker, SeverActions_SandboxAnchorKW)
            ActorUtil.AddPackageOverride(prisoner, SeverActions_PrisonerSandBox, PackagePriority + 10, 1)
            prisoner.EvaluatePackage()
            DebugMsg("Prisoner sandboxing in jail (linked to marker)")
        Else
            ; No sandbox package - prisoner may wander
            DebugMsg("WARNING: No jail sandbox package or marker - prisoner may escape!")
            prisoner.EvaluatePackage()
        EndIf
    EndIf

    ; Guard sheathes weapon and returns to normal
    guard.SheatheWeapon()
    guard.EvaluatePackage()

    ; Direct narration for prisoner to react to being put in the cell
    String cellNarration = "*" + guard.GetDisplayName() + " locks " + prisoner.GetDisplayName() + " in a jail cell.*"
    SkyrimNetApi.DirectNarration(cellNarration, prisoner, guard)

    ; Register persistent event for SkyrimNet - prisoner delivered to jail
    String jailMessage = prisoner.GetDisplayName() + " has been jailed in " + jailName + "."
    SkyrimNetApi.RegisterPersistentEvent(jailMessage, prisoner, None)

    ; Clear state (do this last since we stored local copies)
    ClearArrestState()

    Debug.Notification(prisoner.GetDisplayName() + " has been jailed")
    DebugMsg("Arrest complete - prisoner delivered to " + jailName)
EndFunction

Function ChangeToJailClothes(Actor akPrisoner, Faction akCrimeFaction)
    {Strip prisoner and give them jail clothes using SetOutfit for persistence.
     Uses the faction's jail outfit if available, falls back to property.}

    ; Remove cuffs (they're in jail now)
    If SeverActions_PrisonerCuffs
        akPrisoner.UnequipItem(SeverActions_PrisonerCuffs, false, true)
        akPrisoner.RemoveItem(SeverActions_PrisonerCuffs, 1, true)
    EndIf

    ; Try to get the faction's jail outfit first (from crime data)
    Outfit jailOutfit = None
    If akCrimeFaction
        jailOutfit = SeverActionsNative.GetFactionJailOutfit(akCrimeFaction)
        If jailOutfit
            DebugMsg("Using faction jail outfit for " + akCrimeFaction.GetName())
        EndIf
    EndIf

    ; Fall back to property if faction has no outfit
    If !jailOutfit
        jailOutfit = SeverActions_PrisonerOutfit
    EndIf

    ; Set prisoner outfit - this persists through cell reloads
    If jailOutfit
        ; Store the original outfit so we can restore it when freed
        ; Uses StorageUtil to track per-actor data
        Outfit originalOutfit = akPrisoner.GetActorBase().GetOutfit()
        If originalOutfit
            StorageUtil.SetFormValue(akPrisoner, "SeverActions_OriginalOutfit", originalOutfit)
            DebugMsg("Stored original outfit for " + akPrisoner.GetDisplayName())
        EndIf

        akPrisoner.SetOutfit(jailOutfit)
        DebugMsg("Set prisoner outfit on " + akPrisoner.GetDisplayName())
    ElseIf SeverActions_PrisonerRags
        ; Fallback: just equip the armor directly (won't persist)
        akPrisoner.UnequipAll()
        akPrisoner.EquipItem(SeverActions_PrisonerRags, false, true)
        DebugMsg("WARNING: No jail outfit available, using direct equip (won't persist)")
    EndIf
EndFunction

; =============================================================================
; JAIL LOOKUP - Determine jail from guard's crime faction
; =============================================================================

ObjectReference Function GetJailMarkerForGuard(Actor akGuard)
    {Get the interior jail cell marker based on guard's crime faction}

    Faction cf = GetCrimeFactionForGuard(akGuard)
    If cf == None
        DebugMsg("WARNING: Could not determine guard's hold, defaulting to Whiterun")
        Return JailMarker_Whiterun
    EndIf

    If cf == CrimeFactionWhiterun
        Return JailMarker_Whiterun
    ElseIf cf == CrimeFactionRift
        Return JailMarker_Riften
    ElseIf cf == CrimeFactionHaafingar
        Return JailMarker_Solitude
    ElseIf cf == CrimeFactionEastmarch
        Return JailMarker_Windhelm
    ElseIf cf == CrimeFactionReach
        Return JailMarker_Markarth
    ElseIf cf == CrimeFactionFalkreath
        Return JailMarker_Falkreath
    ElseIf cf == CrimeFactionPale
        Return JailMarker_Dawnstar
    ElseIf cf == CrimeFactionHjaalmarch
        Return JailMarker_Morthal
    ElseIf cf == CrimeFactionWinterhold
        Return JailMarker_Winterhold
    EndIf

    Return JailMarker_Whiterun
EndFunction

String Function GetJailNameForGuard(Actor akGuard)
    {Get human-readable jail name for notifications}

    Faction cf = GetCrimeFactionForGuard(akGuard)
    If cf == CrimeFactionWhiterun
        Return "Dragonsreach Dungeon"
    ElseIf cf == CrimeFactionRift
        Return "Riften Jail"
    ElseIf cf == CrimeFactionHaafingar
        Return "Castle Dour Dungeon"
    ElseIf cf == CrimeFactionEastmarch
        Return "Windhelm Jail"
    ElseIf cf == CrimeFactionReach
        Return "Cidhna Mine"
    ElseIf cf == CrimeFactionFalkreath
        Return "Falkreath Jail"
    ElseIf cf == CrimeFactionPale
        Return "Dawnstar Jail"
    ElseIf cf == CrimeFactionHjaalmarch
        Return "Morthal Jail"
    ElseIf cf == CrimeFactionWinterhold
        Return "The Chill"
    EndIf

    Return "jail"
EndFunction

; =============================================================================
; CANCEL / CLEANUP
; =============================================================================

Function CancelCurrentArrest()
    {Cancel the current arrest in progress}

    DebugMsg("Canceling current arrest")

    If CurrentGuard
        ; Stop stuck tracking
        SeverActionsNative.Stuck_StopTracking(CurrentGuard)

        ; Remove guard packages
        If SeverActions_GuardApproachTarget
            ActorUtil.RemovePackageOverride(CurrentGuard, SeverActions_GuardApproachTarget)
        EndIf
        If SeverActions_GuardEscortPackage
            ActorUtil.RemovePackageOverride(CurrentGuard, SeverActions_GuardEscortPackage)
        EndIf
        CurrentGuard.SheatheWeapon()
        CurrentGuard.EvaluatePackage()
    EndIf

    If CurrentPrisoner && ArrestState >= 2
        ; Prisoner was already arrested, release them
        ReleasePrisoner(CurrentPrisoner)
    EndIf

    ; Clear dispatch state if active
    If DispatchPhase > 0
        CancelDispatch()
    EndIf

    ; Clear reference aliases
    ArrestTarget.Clear()
    JailDestination.Clear()
    ArrestingGuard.Clear()
    If DispatchPrisonerAlias != None
        DispatchPrisonerAlias.Clear()
    EndIf
    If DispatchTravelDestination != None
        DispatchTravelDestination.Clear()
    EndIf

    ClearArrestState()
EndFunction

Function ReleasePrisoner(Actor akPrisoner)
    {Release a prisoner - remove restraints and factions}

    If akPrisoner == None
        Return
    EndIf

    DebugMsg("Releasing prisoner: " + akPrisoner.GetDisplayName())

    ; Remove factions
    akPrisoner.RemoveFromFaction(SeverActions_WaitingArrest)
    akPrisoner.RemoveFromFaction(SeverActions_Arrested)
    akPrisoner.RemoveFromFaction(SeverActions_Jailed)
    akPrisoner.RemoveFromFaction(dunPrisonerFaction)

    ; Remove restraints
    If SeverActions_PrisonerCuffs
        akPrisoner.UnequipItem(SeverActions_PrisonerCuffs, false, true)
        akPrisoner.RemoveItem(SeverActions_PrisonerCuffs, 1, true)
    EndIf

    ; Remove any packages
    If SeverActions_FollowGuard_Prisoner
        ActorUtil.RemovePackageOverride(akPrisoner, SeverActions_FollowGuard_Prisoner)
    EndIf
    If SeverActions_PrisonerSandBox
        ActorUtil.RemovePackageOverride(akPrisoner, SeverActions_PrisonerSandBox)
    EndIf

    ; Clear any linked ref (guard or jail marker)
    PO3_SKSEFunctions.SetLinkedRef(akPrisoner, None, SeverActions_FollowTargetKW)
    PO3_SKSEFunctions.SetLinkedRef(akPrisoner, None, SeverActions_SandboxAnchorKW)

    ; Restore normal behavior (they may become hostile again)
    akPrisoner.RestoreAV("HealRate", 100)
    akPrisoner.EvaluatePackage()
EndFunction

Function ReleaseFromJailCore(Actor akTarget)
    {Core jail-release cleanup shared by FreeNPC_Internal and FreePrisonerDirect.
     Removes jail factions, sandbox package, restores outfit and stats,
     and clears the stored jail marker. Does NOT handle guard approach,
     animations, narration, tracking removal, or EvaluatePackage — callers do that.}

    ; Remove from jailed faction
    akTarget.RemoveFromFaction(SeverActions_Jailed)
    akTarget.RemoveFromFaction(dunPrisonerFaction)

    ; Remove jail sandbox package and clear linked ref
    If SeverActions_PrisonerSandBox
        ActorUtil.RemovePackageOverride(akTarget, SeverActions_PrisonerSandBox)
        PO3_SKSEFunctions.SetLinkedRef(akTarget, None, SeverActions_SandboxAnchorKW)
    EndIf

    ; Restore original outfit if we stored one
    Outfit originalOutfit = StorageUtil.GetFormValue(akTarget, "SeverActions_OriginalOutfit") as Outfit
    If originalOutfit
        akTarget.SetOutfit(originalOutfit)
        StorageUtil.UnsetFormValue(akTarget, "SeverActions_OriginalOutfit")
        DebugMsg("Restored original outfit for " + akTarget.GetDisplayName())
    ElseIf SeverActions_PrisonerRags
        akTarget.UnequipItem(SeverActions_PrisonerRags, false, true)
        akTarget.RemoveItem(SeverActions_PrisonerRags, 1, true)
    EndIf

    ; Restore normal stats
    akTarget.RestoreAV("Aggression", 100)
    akTarget.RestoreAV("Confidence", 100)
    akTarget.RestoreAV("HealRate", 100)

    ; Clear stored jail marker
    StorageUtil.UnsetFormValue(akTarget, "SeverActions_JailMarker")
EndFunction

Function ClearArrestState()
    {Clear all tracking state}

    CurrentGuard = None
    CurrentPrisoner = None
    CurrentJailMarker = None
    CurrentJailName = ""
    ArrestState = 0

    UnregisterForUpdate()
EndFunction

; =============================================================================
; BOUNTY API - Add bounty to player
; =============================================================================

Function AddBountyToPlayer_Internal(Actor akGuard, Int bountyAmount, String crimeType)
    {Guard adds bounty to player for observed crime.
     Uses tracked bounty system instead of vanilla crime gold to prevent
     vanilla guard arrest dialogue from triggering.
     crimeType: "assault", "theft", "murder", "trespass", "pickpocket"}

    If akGuard == None
        DebugMsg("ERROR: AddBountyToPlayer called with None guard")
        Return
    EndIf

    If bountyAmount <= 0
        DebugMsg("ERROR: Invalid bounty amount")
        Return
    EndIf

    ; Determine which crime faction based on guard
    Faction crimeFaction = GetCrimeFactionForGuard(akGuard)

    If crimeFaction == None
        DebugMsg("WARNING: Could not determine guard's crime faction")
        Return
    EndIf

    ; Add to tracked bounty (NOT vanilla crime gold - keeps vanilla at 0)
    ModTrackedBounty(crimeFaction, bountyAmount)

    String holdName = GetHoldNameForGuard(akGuard)
    Int totalBounty = GetTrackedBounty(crimeFaction)
    DebugMsg("Added " + bountyAmount + " tracked bounty for " + crimeType + " in " + holdName + " (total: " + totalBounty + ")")
    Debug.Notification("Bounty added: " + bountyAmount + " gold in " + holdName)

    ; Register persistent event so NPCs remember this crime
    String eventMsg = akGuard.GetDisplayName() + " witnessed the player commit " + crimeType + " and added " + bountyAmount + " gold to their bounty in " + holdName + ". Total bounty is now " + totalBounty + " gold."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, akGuard, Game.GetPlayer())
EndFunction

Faction Function GetCrimeFactionForGuard(Actor akGuard)
    {Get the crime faction the guard belongs to}

    If akGuard.IsInFaction(CrimeFactionWhiterun)
        Return CrimeFactionWhiterun
    ElseIf akGuard.IsInFaction(CrimeFactionRift)
        Return CrimeFactionRift
    ElseIf akGuard.IsInFaction(CrimeFactionHaafingar)
        Return CrimeFactionHaafingar
    ElseIf akGuard.IsInFaction(CrimeFactionEastmarch)
        Return CrimeFactionEastmarch
    ElseIf akGuard.IsInFaction(CrimeFactionReach)
        Return CrimeFactionReach
    ElseIf akGuard.IsInFaction(CrimeFactionFalkreath)
        Return CrimeFactionFalkreath
    ElseIf akGuard.IsInFaction(CrimeFactionPale)
        Return CrimeFactionPale
    ElseIf akGuard.IsInFaction(CrimeFactionHjaalmarch)
        Return CrimeFactionHjaalmarch
    ElseIf akGuard.IsInFaction(CrimeFactionWinterhold)
        Return CrimeFactionWinterhold
    EndIf

    Return None
EndFunction

String Function GetHoldNameForGuard(Actor akGuard)
    {Get hold name for notifications}

    Faction cf = GetCrimeFactionForGuard(akGuard)
    If cf == CrimeFactionWhiterun
        Return "Whiterun"
    ElseIf cf == CrimeFactionRift
        Return "The Rift"
    ElseIf cf == CrimeFactionHaafingar
        Return "Haafingar"
    ElseIf cf == CrimeFactionEastmarch
        Return "Eastmarch"
    ElseIf cf == CrimeFactionReach
        Return "The Reach"
    ElseIf cf == CrimeFactionFalkreath
        Return "Falkreath"
    ElseIf cf == CrimeFactionPale
        Return "The Pale"
    ElseIf cf == CrimeFactionHjaalmarch
        Return "Hjaalmarch"
    ElseIf cf == CrimeFactionWinterhold
        Return "Winterhold"
    EndIf

    Return "unknown hold"
EndFunction

; =============================================================================
; UTILITY
; =============================================================================

Function DebugMsg(String msg)
    Debug.Trace("SeverArrest: " + msg)
    If EnableDebugMessages
        Debug.Notification("Arrest: " + msg)
    EndIf
EndFunction

Function ClearAllDispatchLinkedRefs(Actor akActor)
    {Clear linked refs for both dispatch keywords on an actor.
     Used during dispatch cleanup to ensure no stale linked refs remain.}
    If akActor != None
        PO3_SKSEFunctions.SetLinkedRef(akActor, None, SeverActions_FollowTargetKW)
        PO3_SKSEFunctions.SetLinkedRef(akActor, None, SeverActions_SandboxAnchorKW)
    EndIf
EndFunction

Function ClearDispatchState()
    {Reset all dispatch-related script variables to their defaults.
     Called by CompleteDispatch, CancelDispatch, and EndJudgment branches.}
    DispatchPhase = 0
    DispatchTarget = None
    DispatchGuard = None
    DispatchReturnMarker = None
    DispatchGuardOffScreen = false
    DispatchTargetLocation = ""
    DispatchGameTimeStart = 0.0
    DispatchInitialDistance = 0.0
    DispatchIsHomeInvestigation = false
    DispatchInvestigationReason = ""
    DispatchHomeMarker = None
    DispatchSender = None
    DispatchSandboxStartTime = 0.0
    DispatchSandboxDuration = 0.0
    DispatchEvidenceItem = None
    DispatchEvidenceForm = None
    DispatchEvidenceName = ""
    DispatchReturnOffScreenCycle = 0
    DispatchReturnNarrated = false
    DispatchStuckGraceUntil = 0.0
    JudgmentStartTime = 0.0
EndFunction

Function ClearDeferredNarration()
    {Clear deferred evidence narration stored on a sender actor.
     Called when the narration fires (player approached sender) or sender dies.}
    If DeferredNarrationSender != None
        StorageUtil.UnsetIntValue(DeferredNarrationSender, "SeverActions_PendingEvidence")
        StorageUtil.UnsetStringValue(DeferredNarrationSender, "SeverActions_PendingEvidenceNarration")
        StorageUtil.UnsetFormValue(DeferredNarrationSender, "SeverActions_PendingEvidenceGuard")
        StorageUtil.UnsetFormValue(Self, "SeverActions_DeferredSender")
        DeferredNarrationSender = None
        DebugMsg("Cleared deferred narration state")
    EndIf
EndFunction

Function InitDispatchCommon(Actor akGuard, ObjectReference akDestination)
    {Shared setup for both arrest and home dispatches.
     Call after dispatch state and aliases are fully configured.
     akGuard: the dispatched guard
     akDestination: the ObjectReference the guard is traveling to (target actor or home marker)}

    ; Mark guard as on-task (prevents SkyrimNet re-tasking via YAML eligibility)
    If SeverActions_DispatchFaction != None
        akGuard.AddToFaction(SeverActions_DispatchFaction)
        akGuard.SetFactionRank(SeverActions_DispatchFaction, 0)
    EndIf

    ; Prevent guard from stopping for idle greetings/dialogue during dispatch
    akGuard.SetDontMove(false)
    akGuard.AllowPCDialogue(false)

    ; Apply jog-speed dispatch package — targets DispatchTargetAlias (already filled by caller)
    If SeverActions_DispatchJog
        ActorUtil.AddPackageOverride(akGuard, SeverActions_DispatchJog, PackagePriority, 1)
        akGuard.EvaluatePackage()
        DebugMsg("Applied DispatchJog package for " + akGuard.GetDisplayName())
    Else
        DebugMsg("WARNING: SeverActions_DispatchJog package not set, guard may not move")
    EndIf

    ; Disable NPC-NPC collision so the guard doesn't get blocked during travel
    SeverActionsNative.SetActorBumpable(akGuard, false)

    ; Suppress guard combat during dispatch — save original values and pacify
    DispatchGuardOrigAggression = akGuard.GetAV("Aggression")
    DispatchGuardOrigConfidence = akGuard.GetAV("Confidence")
    akGuard.SetAV("Aggression", 0)
    akGuard.SetAV("Confidence", 0)

    ; Start stuck detection + departure monitoring
    SeverActionsNative.Stuck_StartTracking(akGuard)

    ; Initialize off-screen travel estimation (distance-based arrival time)
    SeverActionsNative.OffScreen_InitTracking(akGuard, akDestination, 0.5, 18.0)

    ; Persist dispatch state for save/load recovery
    PersistDispatchState()

    ; Start monitoring
    RegisterForSingleUpdate(UpdateInterval)
EndFunction

Function ApplyDispatchArrestEffects()
    {Apply arrest effects to DispatchTarget during dispatch arrest.
     Does NOT set ArrestState/CurrentGuard/CurrentPrisoner to avoid
     conflicting with the same-cell escort system in OnUpdate.
     Called by PerformOffScreenArrest and CheckDispatchPhase2_Approach.}

    DispatchTarget.StopCombat()
    DispatchTarget.StopCombatAlarm()

    ; Cancel any active travel errand so it doesn't fight with arrest escort
    If TravelSystem != None
        TravelSystem.CancelTravel(DispatchTarget)
    EndIf

    DispatchTarget.SetAV("Aggression", 0)
    DispatchTarget.SetAV("Confidence", 0)
    DispatchTarget.SetAV("HealRate", 0.1)

    If SeverActions_Arrested
        DispatchTarget.AddToFaction(SeverActions_Arrested)
    EndIf
    If dunPrisonerFaction
        DispatchTarget.AddToFaction(dunPrisonerFaction)
    EndIf
    If SeverActions_WaitingArrest
        DispatchTarget.RemoveFromFaction(SeverActions_WaitingArrest)
    EndIf

    If SeverActions_PrisonerCuffs
        DispatchTarget.AddItem(SeverActions_PrisonerCuffs, 1, true)
        DispatchTarget.EquipItem(SeverActions_PrisonerCuffs, true, true)
    EndIf

    If OffsetBoundStandingStart
        DispatchTarget.PlayIdle(OffsetBoundStandingStart)
    EndIf

    ; Link prisoner to guard for follow package
    PO3_SKSEFunctions.SetLinkedRef(DispatchTarget, DispatchGuard, SeverActions_FollowTargetKW)
    Utility.Wait(0.2)

    ; Break any animation lock from PlayIdle before activating follow package
    Debug.SendAnimationEvent(DispatchTarget, "IdleForceDefaultState")
    Utility.Wait(0.1)

    If SeverActions_FollowGuard_Prisoner
        ActorUtil.AddPackageOverride(DispatchTarget, SeverActions_FollowGuard_Prisoner, PackagePriority, 1)
        DispatchTarget.SetLookAt(DispatchGuard)
        DispatchTarget.EvaluatePackage()
    EndIf
EndFunction

Function StopPersuasionFollow()
    {Remove the guard follow-player package and clear the linked ref.
     Called at the end of every persuasion exit path (success, reject, fail, cancel).}
    If ConfrontingGuard == None
        Return
    EndIf
    If SeverActions_GuardFollowPlayer
        ActorUtil.RemovePackageOverride(ConfrontingGuard, SeverActions_GuardFollowPlayer)
    EndIf
    PO3_SKSEFunctions.SetLinkedRef(ConfrontingGuard, None, SeverActions_FollowTargetKW)
    ConfrontingGuard.EvaluatePackage()
EndFunction

; =============================================================================
; TRACKED BOUNTY SYSTEM
; Stores bounty separately from vanilla crime gold to prevent vanilla guard
; arrest dialogue from triggering. Vanilla crime gold stays at 0.
; =============================================================================

String Function GetBountyStorageKey(Faction akCrimeFaction)
    {Get the StorageUtil key for a crime faction's tracked bounty}

    If akCrimeFaction == CrimeFactionWhiterun
        Return "SeverActions_Bounty_Whiterun"
    ElseIf akCrimeFaction == CrimeFactionRift
        Return "SeverActions_Bounty_Rift"
    ElseIf akCrimeFaction == CrimeFactionHaafingar
        Return "SeverActions_Bounty_Haafingar"
    ElseIf akCrimeFaction == CrimeFactionEastmarch
        Return "SeverActions_Bounty_Eastmarch"
    ElseIf akCrimeFaction == CrimeFactionReach
        Return "SeverActions_Bounty_Reach"
    ElseIf akCrimeFaction == CrimeFactionFalkreath
        Return "SeverActions_Bounty_Falkreath"
    ElseIf akCrimeFaction == CrimeFactionPale
        Return "SeverActions_Bounty_Pale"
    ElseIf akCrimeFaction == CrimeFactionHjaalmarch
        Return "SeverActions_Bounty_Hjaalmarch"
    ElseIf akCrimeFaction == CrimeFactionWinterhold
        Return "SeverActions_Bounty_Winterhold"
    EndIf

    Return ""
EndFunction

Int Function GetTrackedBounty(Faction akCrimeFaction)
    {Get the tracked bounty for a crime faction (not vanilla crime gold)}

    String storageKey = GetBountyStorageKey(akCrimeFaction)
    If storageKey == ""
        Return 0
    EndIf

    Return StorageUtil.GetIntValue(Game.GetPlayer(), storageKey, 0)
EndFunction

Function SetTrackedBounty(Faction akCrimeFaction, Int aiAmount)
    {Set the tracked bounty for a crime faction}

    String storageKey = GetBountyStorageKey(akCrimeFaction)
    If storageKey == ""
        Return
    EndIf

    If aiAmount <= 0
        StorageUtil.UnsetIntValue(Game.GetPlayer(), storageKey)
    Else
        StorageUtil.SetIntValue(Game.GetPlayer(), storageKey, aiAmount)
    EndIf
EndFunction

Function ModTrackedBounty(Faction akCrimeFaction, Int aiAmount)
    {Add to (or subtract from) the tracked bounty for a crime faction}

    Int current = GetTrackedBounty(akCrimeFaction)
    SetTrackedBounty(akCrimeFaction, current + aiAmount)
EndFunction

Function ClearTrackedBounty(Faction akCrimeFaction)
    {Clear the tracked bounty for a crime faction}

    SetTrackedBounty(akCrimeFaction, 0)
EndFunction

Function ApplyTrackedBountyToVanilla(Faction akCrimeFaction)
    {Transfer tracked bounty to vanilla crime gold (for jail/combat)}

    Int bounty = GetTrackedBounty(akCrimeFaction)
    If bounty > 0
        akCrimeFaction.SetCrimeGold(bounty)
        ClearTrackedBounty(akCrimeFaction)
        DebugMsg("Applied " + bounty + " tracked bounty to vanilla system")
    EndIf
EndFunction

Int Function GetTrackedBountyForGuard(Actor akGuard)
    {Get the tracked bounty for the hold a guard belongs to}

    Faction crimeFaction = GetCrimeFactionForGuard(akGuard)
    If crimeFaction
        Return GetTrackedBounty(crimeFaction)
    EndIf
    Return 0
EndFunction

; =============================================================================
; FREE NPC API - Release jailed NPCs
; =============================================================================

Bool Function FreeNPC_Internal(Actor akGuard, Actor akTarget)
    {Free a jailed NPC. Guard will approach and release the prisoner.
     Called by SkyrimNet FreeNPC action.
     akGuard: The guard or authority figure doing the freeing
     akTarget: The jailed NPC to free}

    If akGuard == None
        DebugMsg("ERROR: FreeNPC called with None guard")
        Return false
    EndIf

    If akTarget == None
        DebugMsg("ERROR: FreeNPC called with None target")
        Return false
    EndIf

    ; Check if this NPC is actually jailed
    If !akTarget.IsInFaction(SeverActions_Jailed)
        DebugMsg("ERROR: " + akTarget.GetDisplayName() + " is not jailed")
        Return false
    EndIf

    DebugMsg(akGuard.GetDisplayName() + " is freeing prisoner: " + akTarget.GetDisplayName())

    ; Re-enable prisoner if disabled
    If akTarget.IsDisabled()
        akTarget.Enable()
        Utility.Wait(0.5)
    EndIf

    ; Check distance - if guard is far from prisoner, have them approach first
    Float distance = akGuard.GetDistance(akTarget)
    If distance > 200.0
        DebugMsg("Guard approaching prisoner (distance: " + distance + ")")

        ; Link guard to prisoner for approach package
        PO3_SKSEFunctions.SetLinkedRef(akGuard, akTarget, SeverActions_FollowTargetKW)

        ; Fill the ArrestTarget alias with the prisoner for the approach package
        ArrestTarget.ForceRefTo(akTarget)

        ; Apply approach package to guard
        If SeverActions_GuardApproachTarget
            ActorUtil.AddPackageOverride(akGuard, SeverActions_GuardApproachTarget, PackagePriority, 1)
            akGuard.EvaluatePackage()
        EndIf

        ; Wait for guard to approach (with timeout)
        Float timeout = 15.0
        Float elapsed = 0.0
        While akGuard.GetDistance(akTarget) > 150.0 && elapsed < timeout
            Utility.Wait(0.5)
            elapsed += 0.5
        EndWhile

        ; Remove approach package
        If SeverActions_GuardApproachTarget
            ActorUtil.RemovePackageOverride(akGuard, SeverActions_GuardApproachTarget)
        EndIf
        ArrestTarget.Clear()
        PO3_SKSEFunctions.SetLinkedRef(akGuard, None, SeverActions_FollowTargetKW)

        DebugMsg("Guard reached prisoner (elapsed: " + elapsed + "s)")
    EndIf

    ; Play give/release gesture animation
    If IdleGive
        akGuard.PlayIdle(IdleGive)
        Utility.Wait(1.5)
    EndIf

    ReleaseFromJailCore(akTarget)

    ; Force re-evaluation so prisoner returns to normal AI
    akTarget.EvaluatePackage()
    akGuard.EvaluatePackage()

    ; Remove from tracking
    RemoveJailedNPC(akTarget)

    ; Direct narration for the release
    String narration = "*" + akGuard.GetDisplayName() + " unlocks the cell door and gestures for " + akTarget.GetDisplayName() + " to leave.* \"You're free to go.\""
    SkyrimNetApi.DirectNarration(narration, akGuard, akTarget)

    Debug.Notification(akTarget.GetDisplayName() + " has been freed from jail")
    DebugMsg("Prisoner freed: " + akTarget.GetDisplayName())

    Return true
EndFunction

Function FreePrisonerDirect(Actor akTarget)
    {Free a prisoner directly without guard approach - used by FreeAllPrisoners.
     Does not play animations or approach, just releases the prisoner immediately.}

    If akTarget == None
        Return
    EndIf

    ; Re-enable prisoner if disabled
    If akTarget.IsDisabled()
        akTarget.Enable()
    EndIf

    ReleaseFromJailCore(akTarget)

    ; Force re-evaluation
    akTarget.EvaluatePackage()

    DebugMsg("Prisoner freed directly: " + akTarget.GetDisplayName())
EndFunction

Function FreeAllPrisoners()
    {Free all currently jailed NPCs (direct release, no guard approach)}

    If JailedNPCs == None || JailedNPCs.Length == 0
        DebugMsg("No prisoners to free")
        Return
    EndIf

    Int i = JailedNPCs.Length - 1
    While i >= 0
        Actor prisoner = JailedNPCs[i]
        If prisoner != None
            FreePrisonerDirect(prisoner)
        EndIf
        i -= 1
    EndWhile

    ; Clear the array
    JailedNPCs = PapyrusUtil.ActorArray(0)
    DebugMsg("All prisoners freed")
EndFunction

; =============================================================================
; JAILED NPC TRACKING
; =============================================================================

Function AddJailedNPC(Actor akNPC)
    {Add an NPC to the jailed tracking list}

    If akNPC == None
        Return
    EndIf

    ; Initialize array if needed
    If JailedNPCs == None
        JailedNPCs = PapyrusUtil.ActorArray(0)
    EndIf

    ; Check if already tracked
    Int i = 0
    While i < JailedNPCs.Length
        If JailedNPCs[i] == akNPC
            Return ; Already tracked
        EndIf
        i += 1
    EndWhile

    ; Add to array using PapyrusUtil if available, otherwise manual resize
    JailedNPCs = PapyrusUtil.PushActor(JailedNPCs, akNPC)
    DebugMsg("Tracking jailed NPC: " + akNPC.GetDisplayName() + " (total: " + JailedNPCs.Length + ")")
EndFunction

Function RemoveJailedNPC(Actor akNPC)
    {Remove an NPC from the jailed tracking list}

    If akNPC == None || JailedNPCs == None
        Return
    EndIf

    ; Find and remove
    Int i = 0
    While i < JailedNPCs.Length
        If JailedNPCs[i] == akNPC
            JailedNPCs = PapyrusUtil.RemoveActor(JailedNPCs, akNPC)
            DebugMsg("Removed from jailed tracking: " + akNPC.GetDisplayName())
            Return
        EndIf
        i += 1
    EndWhile
EndFunction

Actor[] Function GetJailedNPCs()
    {Get array of all currently jailed NPCs}

    If JailedNPCs == None
        Return PapyrusUtil.ActorArray(0)
    EndIf
    Return JailedNPCs
EndFunction

Int Function GetJailedCount()
    {Get count of jailed NPCs}

    If JailedNPCs == None
        Return 0
    EndIf
    Return JailedNPCs.Length
EndFunction

Bool Function IsNPCJailed(Actor akNPC)
    {Check if an NPC is currently jailed}

    If akNPC == None || JailedNPCs == None
        Return false
    EndIf

    Int i = 0
    While i < JailedNPCs.Length
        If JailedNPCs[i] == akNPC
            Return true
        EndIf
        i += 1
    EndWhile

    Return false
EndFunction

Function VerifyJailedNPCs()
    {Verify all jailed NPCs are actually at their jail markers.
     Called on game load to fix prisoners who got displaced during fast travel or time advancement.}

    If JailedNPCs == None || JailedNPCs.Length == 0
        Return
    EndIf

    DebugMsg("Verifying " + JailedNPCs.Length + " jailed NPCs...")
    Int fixedCount = 0

    Int i = 0
    While i < JailedNPCs.Length
        Actor prisoner = JailedNPCs[i]
        If prisoner != None && !prisoner.IsDead()
            ; Get stored jail marker
            ObjectReference jailMarker = StorageUtil.GetFormValue(prisoner, "SeverActions_JailMarker") as ObjectReference
            If jailMarker != None
                Float distance = prisoner.GetDistance(jailMarker)
                ; If prisoner is more than 500 units from jail marker, teleport them back
                If distance > 500.0
                    DebugMsg("Prisoner " + prisoner.GetDisplayName() + " is " + distance + " units from jail, fixing...")

                    ; Use Disable/Enable/MoveTo pattern for reliable cross-cell teleport
                    prisoner.Disable()
                    Utility.Wait(0.1)
                    prisoner.MoveTo(jailMarker, 0.0, 0.0, 0.0)
                    Utility.Wait(0.1)
                    prisoner.Enable()

                    ; Re-apply jail sandbox package in case it got removed
                    If SeverActions_PrisonerSandBox
                        PO3_SKSEFunctions.SetLinkedRef(prisoner, jailMarker, SeverActions_SandboxAnchorKW)
                        ActorUtil.AddPackageOverride(prisoner, SeverActions_PrisonerSandBox, PackagePriority + 10, 1)
                        prisoner.EvaluatePackage()
                    EndIf

                    fixedCount += 1
                EndIf
            Else
                ; No stored marker - try to re-derive it from their faction
                DebugMsg("WARNING: No stored jail marker for " + prisoner.GetDisplayName())
            EndIf
        EndIf
        i += 1
    EndWhile

    If fixedCount > 0
        DebugMsg("Fixed position of " + fixedCount + " prisoners")
    EndIf
EndFunction

; =============================================================================
; PLAYER ARREST API
; =============================================================================

Bool Function ArrestPlayer_Internal(Actor akGuard)
    {Guard confronts player about their bounty.
     Shows MessageBox with options based on bounty amount.
     Returns true if confrontation started successfully.}

    If akGuard == None
        DebugMsg("ERROR: ArrestPlayer called with None guard")
        Return false
    EndIf

    If akGuard.IsDead()
        DebugMsg("ERROR: Guard is dead")
        Return false
    EndIf

    ; Block if already in an active confrontation (prevents stacking messageboxes)
    If ConfrontingGuard != None
        DebugMsg("Already in confrontation with " + ConfrontingGuard.GetDisplayName() + ", ignoring new arrest request")
        Return false
    EndIf

    ; Check cooldown - prevent spamming arrest during persuasion or shortly after
    Float currentTime = Utility.GetCurrentRealTime()
    If LastArrestTime > 0.0 && (currentTime - LastArrestTime) < ArrestPlayerCooldown
        Float remaining = ArrestPlayerCooldown - (currentTime - LastArrestTime)
        DebugMsg("ArrestPlayer on cooldown, " + remaining + " seconds remaining")
        Return false
    EndIf

    ; Get the crime faction for this guard
    Faction crimeFaction = GetCrimeFactionForGuard(akGuard)
    If crimeFaction == None
        DebugMsg("ERROR: Could not determine guard's crime faction")
        Return false
    EndIf

    ; Get current tracked bounty (not vanilla crime gold which stays at 0)
    Int bounty = GetTrackedBounty(crimeFaction)
    If bounty <= 0
        ; Auto-add 300 bounty if guard is arresting with no existing bounty
        ; This handles cases where ReportCrime wasn't used first
        bounty = 300
        SetTrackedBounty(crimeFaction, bounty)
        String holdName = GetHoldNameForGuard(akGuard)
        DebugMsg("Auto-added " + bounty + " bounty for arrest in " + holdName)
        Debug.Notification("Bounty added: " + bounty + " gold in " + holdName)

        ; Register persistent event so NPCs know about this
        String eventMsg = akGuard.GetDisplayName() + " is arresting the player and added " + bounty + " gold bounty in " + holdName + "."
        SkyrimNetApi.RegisterPersistentEvent(eventMsg, akGuard, Game.GetPlayer())
    EndIf

    ; Check if already in a confrontation
    If ConfrontingGuard != None
        DebugMsg("WARNING: Already in a confrontation, canceling previous")
        CancelPlayerConfrontation()
    EndIf

    ; Store confrontation state
    ConfrontingGuard = akGuard
    ConfrontingFaction = crimeFaction
    ConfrontingBounty = bounty
    LastArrestTime = Utility.GetCurrentRealTime() ; Start cooldown

    String holdName = GetHoldNameForGuard(akGuard)
    DebugMsg("Guard confronting player - Tracked Bounty: " + bounty + " in " + holdName)

    ; Show appropriate MessageBox based on bounty
    ShowPlayerArrestMenu()

    Return true
EndFunction

Function ShowPlayerArrestMenu()
    {Display the appropriate MessageBox based on bounty and state.
     Uses SkyMessage for proper button support.
     Pay/bribe options hidden after player fails to afford them once.}

    If ConfrontingGuard == None || ConfrontingFaction == None
        DebugMsg("ERROR: ShowPlayerArrestMenu - invalid state")
        Return
    EndIf

    Int bounty = ConfrontingBounty
    Int bribeCost = (bounty as Float * BribeMultiplier) as Int

    String holdName = GetHoldNameForGuard(ConfrontingGuard)
    String resultStr

    If bounty < ArrestBountyThreshold
        ; Low bounty - fine or refuse (no jail option for minor offenses)
        If PaymentFailed
            ; Already failed to pay - only submit or refuse
            String bodyText = "You have a bounty of " + bounty + " gold in " + holdName + ". The guard won't accept payment attempts anymore."
            resultStr = SkyMessage.Show(bodyText, "Submit to Arrest", "Refuse", getIndex = true)

            If resultStr == "0"
                HandleSubmitToArrest()
            Else
                HandleResistArrest()
            EndIf
        Else
            ; Can still try to pay
            String bodyText = "You have a bounty of " + bounty + " gold in " + holdName + ". Pay your fine or face the consequences."
            resultStr = SkyMessage.Show(bodyText, "Pay Fine (" + bounty + " gold)", "Refuse", getIndex = true)

            If resultStr == "0"
                HandlePayFine()
            Else
                HandleResistArrest()
            EndIf
        EndIf
    Else
        ; High bounty - arrest options
        String bodyText = "You have a bounty of " + bounty + " gold in " + holdName + "."

        If PaymentFailed && PersuadeAttempted
            ; No payment, no persuade - only submit or resist
            bodyText += " The guard has lost all patience. Submit or resist."
            resultStr = SkyMessage.Show(bodyText, "Submit to Arrest", "Resist Arrest", getIndex = true)

            If resultStr == "0"
                HandleSubmitToArrest()
            Else
                HandleResistArrest()
            EndIf

        ElseIf PaymentFailed && !PersuadeAttempted
            ; No payment, but can persuade
            bodyText += " The guard won't accept payment anymore."
            resultStr = SkyMessage.Show(bodyText, "Submit to Arrest", "Resist Arrest", "Persuade", getIndex = true)

            If resultStr == "0"
                HandleSubmitToArrest()
            ElseIf resultStr == "1"
                HandleResistArrest()
            Else
                HandlePersuade()
            EndIf

        ElseIf !PaymentFailed && PersuadeAttempted
            ; Can bribe, but no persuade
            bodyText += " The guard has lost patience. Make your choice now."
            resultStr = SkyMessage.Show(bodyText, "Submit to Arrest", "Resist Arrest", "Bribe (" + bribeCost + " gold)", getIndex = true)

            If resultStr == "0"
                HandleSubmitToArrest()
            ElseIf resultStr == "1"
                HandleResistArrest()
            Else
                HandleBribe()
            EndIf

        Else
            ; All options available
            bodyText += " Submit to arrest or face the consequences."
            resultStr = SkyMessage.Show(bodyText, "Submit to Arrest", "Resist Arrest", "Bribe (" + bribeCost + " gold)", "Persuade", getIndex = true)

            If resultStr == "0"
                HandleSubmitToArrest()
            ElseIf resultStr == "1"
                HandleResistArrest()
            ElseIf resultStr == "2"
                HandleBribe()
            Else
                HandlePersuade()
            EndIf
        EndIf
    EndIf
EndFunction

Function HandlePayFine()
    {Player pays the fine - clear bounty, or guard gets angry if can't afford}

    If ConfrontingGuard == None || ConfrontingFaction == None
        Return
    EndIf

    Actor player = Game.GetPlayer()
    Int bounty = ConfrontingBounty
    Int playerGold = player.GetGoldAmount()

    Maintenance() ; Ensure Gold001 is available

    If playerGold >= bounty && Gold001
        ; Player can afford - pay the fine
        player.RemoveItem(Gold001, bounty, true)
        ClearTrackedBounty(ConfrontingFaction)

        ; Direct narration - guard accepts fine
        String narration = "*" + ConfrontingGuard.GetDisplayName() + " accepts the " + bounty + " gold fine and pockets it.*"
        SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, player)

        Debug.Notification("Paid " + bounty + " gold fine")
        DebugMsg("Player paid fine: " + bounty)

        ClearPlayerConfrontationState()
    Else
        ; Player can't afford - guard gets angry, no more payment options
        PaymentFailed = true

        ; Direct narration - guard is angry
        String narration = "*" + ConfrontingGuard.GetDisplayName() + " scowls as the player fumbles through their coin purse, coming up short.* \"You waste my time with empty pockets? Don't try that again!\""
        SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, player)

        Debug.Notification("The guard won't accept payment attempts anymore!")
        DebugMsg("Player couldn't afford fine, payment options removed")

        ; Show menu again without payment options
        ShowPlayerArrestMenu()
    EndIf
EndFunction

; =============================================================================
; PLAYER ARREST - Option Handlers
; =============================================================================

Function HandleSubmitToArrest()
    {Player submits to arrest - send to jail}

    If ConfrontingGuard == None || ConfrontingFaction == None
        Return
    EndIf

    DebugMsg("Player submitted to arrest")

    ; Apply tracked bounty to vanilla system so jail works correctly
    ApplyTrackedBountyToVanilla(ConfrontingFaction)

    ; Use vanilla jail system
    ConfrontingFaction.SendPlayerToJail(true, true) ; removeInventory, realJail

    ClearPlayerConfrontationState()
EndFunction

Function HandleResistArrest()
    {Player resists arrest - guard becomes hostile, bounty increases}

    If ConfrontingGuard == None || ConfrontingFaction == None
        Return
    EndIf

    DebugMsg("Player resisting arrest")

    ; Add resist bounty to tracked system
    ModTrackedBounty(ConfrontingFaction, ResistBountyIncrease)

    ; Apply all tracked bounty to vanilla so guards naturally become hostile
    ApplyTrackedBountyToVanilla(ConfrontingFaction)

    ; Make guard hostile
    ConfrontingGuard.SetAV("Aggression", 2) ; Aggressive
    ConfrontingGuard.StartCombat(Game.GetPlayer())

    Debug.Notification("Bounty increased by " + ResistBountyIncrease + " gold!")

    ClearPlayerConfrontationState()
EndFunction

Function HandleBribe()
    {Player bribes guard - pay extra to clear bounty, or guard gets angry if can't afford}

    If ConfrontingGuard == None || ConfrontingFaction == None
        Return
    EndIf

    Actor player = Game.GetPlayer()
    Int bribeCost = (ConfrontingBounty as Float * BribeMultiplier) as Int
    Int playerGold = player.GetGoldAmount()

    Maintenance() ; Ensure Gold001 is available

    If playerGold >= bribeCost && Gold001
        ; Player can afford - bribe successful
        player.RemoveItem(Gold001, bribeCost, true)
        ClearTrackedBounty(ConfrontingFaction) ; Clear our tracked bounty

        ; Direct narration - guard takes bribe
        String narration = "*" + ConfrontingGuard.GetDisplayName() + " glances around, then quietly takes the " + bribeCost + " gold bribe, looking the other way.*"
        SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, player)

        Debug.Notification("Bribed guard with " + bribeCost + " gold")
        DebugMsg("Player bribed guard: " + bribeCost)

        ClearPlayerConfrontationState()
    Else
        ; Player can't afford - guard gets angry, no more payment options
        PaymentFailed = true

        ; Direct narration - guard is insulted by pathetic bribe attempt
        String narration = "*" + ConfrontingGuard.GetDisplayName() + " looks at the player's meager coin purse with contempt.* \"You think you can bribe me with that pitiful amount? Don't insult me again!\""
        SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, player)

        Debug.Notification("The guard won't accept payment attempts anymore!")
        DebugMsg("Player couldn't afford bribe, payment options removed")

        ; Show menu again without payment options
        ShowPlayerArrestMenu()
    EndIf
EndFunction

Function HandlePersuade()
    {Player attempts to persuade guard - start conversation mode}

    If ConfrontingGuard == None || ConfrontingFaction == None
        Return
    EndIf

    DebugMsg("Player starting persuasion attempt")

    ; Mark that persuade has been attempted
    PersuadeAttempted = true
    InPersuasionMode = true
    PersuasionStartTime = Utility.GetCurrentRealTime()

    ; Link guard to player so follow package works
    PO3_SKSEFunctions.SetLinkedRef(ConfrontingGuard, Game.GetPlayer(), SeverActions_FollowTargetKW)

    ; Apply follow package to guard
    If SeverActions_GuardFollowPlayer
        ActorUtil.AddPackageOverride(ConfrontingGuard, SeverActions_GuardFollowPlayer, PackagePriority, 1)
        ConfrontingGuard.EvaluatePackage()
        DebugMsg("Guard following player for persuasion")
    EndIf

    ; Direct narration to start the conversation
    String holdName = GetHoldNameForGuard(ConfrontingGuard)
    String narration = "*" + ConfrontingGuard.GetDisplayName() + " pauses, willing to hear what the player has to say about their " + ConfrontingBounty + " gold bounty in " + holdName + ".*"
    SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, Game.GetPlayer())

    ; Register persistent event so SkyrimNet knows the context
    String eventMsg = "The player is trying to convince " + ConfrontingGuard.GetDisplayName() + " to overlook their " + ConfrontingBounty + " gold bounty in " + holdName + ". The guard is listening but skeptical."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, ConfrontingGuard, Game.GetPlayer())

    Debug.Notification("You have " + (PersuasionTimeLimit as Int) + " seconds to convince the guard...")

    ; Start timer for persuasion timeout
    RegisterForSingleUpdate(1.0)
EndFunction

; =============================================================================
; PLAYER ARREST - Persuasion System
; =============================================================================

Function CheckPersuasionProgress()
    {Check if persuasion time has expired or player moved too far}

    If !InPersuasionMode || ConfrontingGuard == None
        Return
    EndIf

    Float elapsed = Utility.GetCurrentRealTime() - PersuasionStartTime
    Float distance = ConfrontingGuard.GetDistance(Game.GetPlayer())

    ; Check timeout
    If elapsed >= PersuasionTimeLimit
        DebugMsg("Persuasion timed out")
        OnPersuasionFailed("timeout")
        Return
    EndIf

    ; Check distance
    If distance > PersuasionFollowDistance
        DebugMsg("Player moved too far during persuasion")
        OnPersuasionFailed("distance")
        Return
    EndIf

    ; Check if guard died
    If ConfrontingGuard.IsDead()
        DebugMsg("Guard died during persuasion")
        ClearPlayerConfrontationState()
        Return
    EndIf

    ; Still in progress, keep checking
    RegisterForSingleUpdate(1.0)
EndFunction

; =============================================================================
; PLAYER ARREST - Persuasion Actions (for SkyrimNet)
; =============================================================================

Bool Function CanUsePersuasionAction(Actor akGuard)
    {Eligibility function for persuasion actions (AcceptPersuasion, RejectPersuasion).
     Returns true only if this guard is the one confronting the player in persuasion mode.}

    If !InPersuasionMode
        Return false
    EndIf

    If akGuard == None
        Return false
    EndIf

    If akGuard != ConfrontingGuard
        Return false
    EndIf

    Return true
EndFunction

Bool Function AcceptPersuasion_Internal(Actor akGuard)
    {Called by SkyrimNet when the AI decides the player's argument is convincing.
     Clears bounty and ends persuasion successfully.
     Returns true if successful.}

    If !InPersuasionMode
        DebugMsg("ERROR: AcceptPersuasion called but not in persuasion mode")
        Return false
    EndIf

    If akGuard != ConfrontingGuard
        DebugMsg("ERROR: AcceptPersuasion called with wrong guard")
        Return false
    EndIf

    DebugMsg("Guard accepted persuasion!")

    ; Clear tracked bounty (vanilla is already 0)
    ClearTrackedBounty(ConfrontingFaction)

    StopPersuasionFollow()

    ; Direct narration
    String narration = "*" + ConfrontingGuard.GetDisplayName() + " sighs and nods reluctantly.* \"Fine. Get out of here before I change my mind.\""
    SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, Game.GetPlayer())

    ; Persistent event for success
    String holdName = GetHoldNameForGuard(ConfrontingGuard)
    String eventMsg = "The player convinced " + ConfrontingGuard.GetDisplayName() + " to overlook their " + ConfrontingBounty + " gold bounty in " + holdName + "."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, Game.GetPlayer(), ConfrontingGuard)

    Debug.Notification("The guard lets you go with a warning")

    ClearPlayerConfrontationState()
    Return true
EndFunction

Bool Function RejectPersuasion_Internal(Actor akGuard)
    {Called by SkyrimNet when the AI decides the player's argument is NOT convincing.
     Ends persuasion mode and forces the player to choose: submit or resist.
     Returns true if successful.}

    If !InPersuasionMode
        DebugMsg("ERROR: RejectPersuasion called but not in persuasion mode")
        Return false
    EndIf

    If akGuard != ConfrontingGuard
        DebugMsg("ERROR: RejectPersuasion called with wrong guard")
        Return false
    EndIf

    DebugMsg("Guard rejected persuasion attempt")

    StopPersuasionFollow()

    InPersuasionMode = false

    ; The guard will provide their own narration via SkyrimNet dialogue
    ; Just register the persistent event
    String holdName = GetHoldNameForGuard(ConfrontingGuard)
    String eventMsg = ConfrontingGuard.GetDisplayName() + " was not convinced by the player's arguments and demands they face justice for their " + ConfrontingBounty + " gold bounty in " + holdName + "."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, ConfrontingGuard, Game.GetPlayer())

    Debug.Notification("The guard is not convinced!")

    ; Show menu again without persuade option (since they already tried)
    ShowPlayerArrestMenu()
    Return true
EndFunction

Function OnPersuasionFailed(String reason)
    {Called when persuasion fails (timeout or distance)}

    If !InPersuasionMode || ConfrontingGuard == None
        Return
    EndIf

    DebugMsg("Persuasion failed: " + reason)

    StopPersuasionFollow()

    InPersuasionMode = false

    ; Direct narration - guard annoyed
    String narration
    If reason == "timeout"
        narration = "*" + ConfrontingGuard.GetDisplayName() + " grows impatient.* \"Enough talk! Make your choice now.\""
    Else
        narration = "*" + ConfrontingGuard.GetDisplayName() + " catches up, clearly annoyed.* \"Trying to run? That's it, no more games!\""
    EndIf
    SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, Game.GetPlayer())

    ; Persistent event for failure
    String holdName = GetHoldNameForGuard(ConfrontingGuard)
    String eventMsg = ConfrontingGuard.GetDisplayName() + " grew tired of the player's excuses and demanded they submit to arrest."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, ConfrontingGuard, Game.GetPlayer())

    Debug.Notification("The guard has lost patience!")

    ; Show menu again without persuade option
    ShowPlayerArrestMenu()
EndFunction

; =============================================================================
; PLAYER ARREST - Cleanup
; =============================================================================

Function CancelPlayerConfrontation()
    {Cancel current player confrontation}

    DebugMsg("Canceling player confrontation")

    If InPersuasionMode && ConfrontingGuard
        StopPersuasionFollow()
    EndIf

    ClearPlayerConfrontationState()
EndFunction

Function ClearPlayerConfrontationState()
    {Clear all player confrontation state}

    ConfrontingGuard = None
    ConfrontingFaction = None
    ConfrontingBounty = 0
    PersuadeAttempted = false
    PaymentFailed = false
    InPersuasionMode = false
    PersuasionStartTime = 0.0

    UnregisterForUpdate()
EndFunction

Bool Function IsPlayerInConfrontation()
    {Check if player is currently being confronted by a guard}

    Return ConfrontingGuard != None
EndFunction

Bool Function IsPlayerInPersuasion()
    {Check if player is currently in persuasion mode}

    Return InPersuasionMode
EndFunction

; =============================================================================
; GUARD DISPATCH - Find and arrest NPCs anywhere in the world
; Uses native ActorFinder for NPC lookup + Travel system for cross-cell movement
; Guard travels via the full travel system (packages, stuck detection, pathfinding)
; then arrests when within range of the target.
; =============================================================================

Bool Function DispatchGuardToArrest(Actor akGuard, String targetName, Actor akSender = None)
    {Dispatch a guard to find and arrest an NPC by name, wherever they are.
     Self-contained system - does NOT use TravelSystem.

     Travels directly to the target Actor reference (no door intermediary).
     Skyrim's AI pathfinding handles cross-cell navigation natively.
     Guard walks the entire way - no off-screen teleportation shortcuts.

     Phases:
       1: Guard travels directly to target Actor (linked ref + travel package)
       2: Guard approaches target for arrest (same cell, within range)
       5: Guard returns with prisoner to sender or jail

     Off-screen handling:
       - Same-cell interior detection: if guard reaches target's cell off-screen, transition to approach
       - Game-time timeout (24h): force-completes if dispatch takes too long

     akGuard: The guard to dispatch (if None, finds nearest guard to player)
     targetName: The name of the NPC to arrest
     akSender: Who ordered the arrest. If set, guard brings prisoner back to this actor.
               If None, guard takes prisoner to jail.
     Returns true if dispatch was initiated successfully.}

    Actor target
    String targetLocation
    String eventMsg

    If targetName == ""
        DebugMsg("ERROR: DispatchGuardToArrest called with empty name")
        Return false
    EndIf

    ; Prevent dispatch spam — reject if another dispatch is active
    If DispatchPhase > 0
        DebugMsg("Dispatch rejected: another dispatch already in progress (Phase " + DispatchPhase + ")")
        Debug.Notification("A guard is already dispatched!")
        Return false
    EndIf

    ; Cooldown: reject if last dispatch was < 15 seconds ago
    Float dispatchNow = Utility.GetCurrentRealTime()
    If LastNPCArrestTime > 0.0 && (dispatchNow - LastNPCArrestTime) < 15.0
        DebugMsg("Dispatch rejected: cooldown not elapsed (" + (dispatchNow - LastNPCArrestTime) + "s)")
        Debug.Notification("Please wait before dispatching another guard")
        Return false
    EndIf
    LastNPCArrestTime = dispatchNow

    ; Check if ActorFinder is ready
    If !SeverActionsNative.IsActorFinderReady()
        DebugMsg("ERROR: Native ActorFinder not initialized")
        Return false
    EndIf

    ; Find the target NPC by name using native lookup
    target = SeverActionsNative.FindActorByName(targetName)
    If target == None
        DebugMsg("ERROR: Could not find NPC named '" + targetName + "'")
        Debug.Notification("Cannot find NPC: " + targetName)
        Return false
    EndIf

    ; Block if target is already arrested or jailed
    If target.IsInFaction(SeverActions_Arrested) || target.IsInFaction(SeverActions_Jailed)
        DebugMsg("DispatchGuardToArrest rejected: " + targetName + " already arrested or jailed")
        Return false
    EndIf

    ; Find a guard if none provided
    If akGuard == None
        akGuard = FindNearestGuard(Game.GetPlayer())
        If akGuard == None
            DebugMsg("ERROR: No guard nearby to dispatch")
            Debug.Notification("No guard nearby to dispatch!")
            Return false
        EndIf
    EndIf

    ; If already in same cell and close enough, just arrest directly
    If akGuard.GetParentCell() == target.GetParentCell() && akGuard.GetDistance(target) <= ArrivalDistance
        DebugMsg("Guard already close to target in same cell, starting direct arrest")
        Return ArrestNPC_Internal(akGuard, target)
    EndIf

    ; Get the NPC's location name for narration
    targetLocation = SeverActionsNative.GetActorLocationName(target)
    DebugMsg("Dispatching " + akGuard.GetDisplayName() + " to arrest " + target.GetDisplayName() + " at " + targetLocation)

    ; Register persistent event so NPCs know what's happening
    eventMsg = akGuard.GetDisplayName() + " has been dispatched to arrest " + target.GetDisplayName() + " at " + targetLocation + "."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, akGuard, target)
    Debug.Notification(akGuard.GetDisplayName() + " dispatched to arrest " + target.GetDisplayName())

    ; Set up dispatch state - travel directly to target Actor (no door intermediary)
    DispatchPhase = 1
    DispatchTarget = target
    DispatchGuard = akGuard
    DispatchTargetLocation = targetLocation
    DispatchGuardOffScreen = false
    DispatchOffScreenStartTime = 0.0
    DispatchGameTimeStart = Utility.GetCurrentGameTime()

    ; Store initial distance for time-skip/off-screen calculations
    ; GetDistance returns 0 when guard and target are in different cells (3D not loaded)
    Float dispatchDist = 0.0
    If akGuard.Is3DLoaded() && target.Is3DLoaded()
        dispatchDist = akGuard.GetDistance(target)
    EndIf
    If dispatchDist < 1000.0
        dispatchDist = 5000.0  ; Conservative default (typical city traverse)
    EndIf
    DispatchInitialDistance = dispatchDist

    ; Return destination: sender (live actor) or jail (static marker)
    If akSender != None
        DispatchSender = akSender
        DispatchReturnMarker = akSender as ObjectReference
        DebugMsg("Prisoner will be brought back to " + akSender.GetDisplayName())
    Else
        DispatchSender = None
        ObjectReference jailMarker = GetJailMarkerForGuard(akGuard)
        DispatchReturnMarker = jailMarker
        DebugMsg("Prisoner will be taken to jail")
    EndIf

    ; Fill dedicated dispatch aliases so the engine keeps both actors in high-process
    ; while unloaded. Separated from ArrestingGuard/ArrestTarget to avoid clobbering
    ; if a same-cell arrest runs while dispatch is active.
    DispatchGuardAlias.ForceRefTo(akGuard)
    DispatchTargetAlias.ForceRefTo(target)

    InitDispatchCommon(akGuard, target as ObjectReference)

    Return true
EndFunction

Bool Function DispatchGuardToArrest_Execute(Actor akGuard, String targetName, String senderName = "")
    {SkyrimNet action entry point: Dispatch a guard to find and arrest an NPC by name.
     The guard will travel to the target, arrest them, and either bring them back to the
     sender for judgment or take them to jail.
     senderName: Name of the person who ordered the arrest. If provided, the guard brings
                 the prisoner back to this person for judgment. If empty, guard takes
                 prisoner directly to the nearest hold jail.}

    ; Resolve sender by name — None means take prisoner to jail
    Actor sender = None
    If senderName != "" && senderName != "None" && senderName != "none"
        ; Check player first — FindActorByName can fuzzy-match the player's name
        ; to a different NPC, so exact-match against the player name directly
        Actor playerRef = Game.GetPlayer()
        If playerRef.GetDisplayName() == senderName
            sender = playerRef
        Else
            sender = SeverActionsNative.FindActorByName(senderName)
            If sender == None
                DebugMsg("WARNING: Could not find sender '" + senderName + "', prisoner will go to jail")
            EndIf
        EndIf
    EndIf

    Return DispatchGuardToArrest(akGuard, targetName, sender)
EndFunction

Bool Function DispatchGuardToHome(Actor akGuard, String targetName, Actor akSender = None, String reason = "")
    {Dispatch a guard to an NPC's home to investigate.
     The guard travels to the NPC's home, sandboxes for a while searching through
     belongings, picks up an item as evidence, then returns to whoever sent them.

     Uses native ActorFinder to find the NPC and their home location.
     akGuard: The guard to dispatch (if None, finds nearest guard)
     targetName: The name of the NPC whose home to search
     akSender: Who sent the guard - the guard returns to this actor with evidence.
               If None, defaults to the guard's current position.
     reason: Why the investigation was ordered (e.g. "dibella worship", "thieving", "skooma").
             Used to generate thematically appropriate evidence. If empty, falls back to NPC class.
     Returns true if dispatch was initiated successfully.

     Phases:
       1: Guard travels to target's home
       3: Guard sandboxes at home (investigating)
       4: Guard collects evidence item
       5: Guard returns to sender with evidence}

    Actor target
    ObjectReference home
    String eventMsg
    String guardName

    If targetName == ""
        DebugMsg("ERROR: DispatchGuardToHome called with empty name")
        Return false
    EndIf

    ; Prevent dispatch spam — reject if another dispatch is active
    If DispatchPhase > 0
        DebugMsg("Dispatch rejected: another dispatch already in progress (Phase " + DispatchPhase + ")")
        Debug.Notification("A guard is already dispatched!")
        Return false
    EndIf

    ; Cooldown: reject if last dispatch was < 15 seconds ago
    Float dispatchNow = Utility.GetCurrentRealTime()
    If LastNPCArrestTime > 0.0 && (dispatchNow - LastNPCArrestTime) < 15.0
        DebugMsg("Dispatch rejected: cooldown not elapsed (" + (dispatchNow - LastNPCArrestTime) + "s)")
        Debug.Notification("Please wait before dispatching another guard")
        Return false
    EndIf
    LastNPCArrestTime = dispatchNow

    If !SeverActionsNative.IsActorFinderReady()
        DebugMsg("ERROR: Native ActorFinder not initialized")
        Return false
    EndIf

    ; Find the target NPC by name
    target = SeverActionsNative.FindActorByName(targetName)
    If target == None
        DebugMsg("ERROR: Could not find NPC named '" + targetName + "'")
        Debug.Notification("Cannot find NPC: " + targetName)
        Return false
    EndIf

    ; Find a guard if none provided
    If akGuard == None
        akGuard = FindNearestGuard(Game.GetPlayer())
        If akGuard == None
            DebugMsg("ERROR: No guard nearby to dispatch")
            Debug.Notification("No guard nearby to dispatch!")
            Return false
        EndIf
    EndIf

    guardName = akGuard.GetDisplayName()

    ; Find the NPC's home — interior marker preferred, exterior door as fallback
    ; If an interior marker exists, use it directly as the travel destination.
    ; The NPC's AI will pathfind through doors automatically to reach it.
    ; This avoids all cross-cell GetDistance issues from targeting exterior doors.
    ObjectReference interiorMarker = SeverActionsNative.FindHomeInteriorMarker(target)
    home = SeverActionsNative.FindDoorToActorHome(target)
    If home == None
        ; Fallback: try FindActorHome (bed ownership scan, works if NPC is loaded)
        home = SeverActionsNative.FindActorHome(target)
    EndIf
    If home == None && interiorMarker == None
        DebugMsg("ERROR: No home found for " + target.GetDisplayName() + ", cannot investigate")
        Debug.Notification("Cannot find " + target.GetDisplayName() + "'s home!")
        Return false
    EndIf

    ; Resolve to final destination: prefer interior marker over exterior door
    ObjectReference finalDest = home
    If interiorMarker != None
        finalDest = interiorMarker
        DebugMsg("Resolved home to interior marker for " + target.GetDisplayName())
    ElseIf home != None
        DebugMsg("No interior marker — using exterior door for " + target.GetDisplayName() + "'s home")
    EndIf

    DebugMsg("Dispatching " + guardName + " to investigate " + target.GetDisplayName() + "'s home")

    ; If we resolved to an interior marker, unlock the exterior door so the guard can pathfind through
    ; The homeowner will re-lock it naturally when they return home
    If finalDest == interiorMarker && home != None && home.IsLocked()
        DebugMsg("Unlocked home door for guard entry")
        home.Lock(false)
        DispatchUnlockedDoor = home  ; Track for re-lock on completion
    EndIf

    ; Set up dispatch state as home investigation
    DispatchPhase = 1
    DispatchTarget = target
    DispatchGuard = akGuard
    DispatchIsHomeInvestigation = true
    DispatchHomeMarker = finalDest
    DispatchGuardOffScreen = false
    DispatchOffScreenStartTime = 0.0
    DispatchGameTimeStart = Utility.GetCurrentGameTime()

    ; Store initial distance for time-skip/off-screen calculations
    Float homeDispatchDist = 0.0
    If akGuard.Is3DLoaded() && finalDest != None && finalDest.Is3DLoaded()
        homeDispatchDist = akGuard.GetDistance(finalDest)
    EndIf
    If homeDispatchDist < 1000.0
        homeDispatchDist = 5000.0
    EndIf
    DispatchInitialDistance = homeDispatchDist

    DispatchEvidenceItem = None
    DispatchEvidenceForm = None
    DispatchEvidenceName = ""
    DispatchInvestigationReason = reason
    DispatchSandboxStartTime = 0.0
    DispatchSandboxDuration = 0.0

    If reason != ""
        DebugMsg("Investigation reason: " + reason)
    EndIf

    ; Set sender - guard returns to this actor with evidence
    If akSender != None
        DispatchSender = akSender
        DispatchReturnMarker = akSender as ObjectReference
        DebugMsg("Guard will return evidence to " + akSender.GetDisplayName())
    Else
        DispatchSender = akGuard
        DispatchReturnMarker = akGuard as ObjectReference
        DebugMsg("No sender specified - guard will return to starting position")
    EndIf

    ; Fill dedicated dispatch aliases so the engine keeps the guard in high-process
    ; while unloaded. Separated from ArrestingGuard/ArrestTarget to avoid clobbering.
    DispatchGuardAlias.ForceRefTo(akGuard)
    DispatchTargetAlias.ForceRefTo(finalDest)

    ; Register persistent event
    eventMsg = guardName + " has been dispatched to search " + target.GetDisplayName() + "'s home for evidence."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, akGuard, target)
    Debug.Notification(guardName + " heading to " + target.GetDisplayName() + "'s home to investigate")

    InitDispatchCommon(akGuard, finalDest)

    Return true
EndFunction

Bool Function DispatchGuardToHome_Execute(Actor akGuard, String targetName, String senderName, String reason = "")
    {SkyrimNet action entry point: Dispatch a guard to search an NPC's home for evidence.
     The guard will travel to the home, search through belongings, collect an item as evidence,
     and return to whoever sent them.
     senderName: Name of the NPC who ordered the search - the guard brings evidence back to them.
     reason: Why the investigation was ordered (e.g. "dibella worship", "thieving", "skooma").
             Used to generate thematically appropriate evidence when the player isn't watching.}

    ; Resolve sender by name — default to player if not found
    Actor sender = None
    Actor playerRef = Game.GetPlayer()
    If senderName != ""
        ; Check player first — FindActorByName can fuzzy-match the player's name
        ; to a different NPC, so exact-match against the player name directly
        If playerRef.GetDisplayName() == senderName
            sender = playerRef
        Else
            sender = SeverActionsNative.FindActorByName(senderName)
            If sender == None
                DebugMsg("WARNING: Could not find sender '" + senderName + "', defaulting to player")
                sender = playerRef
            EndIf
        EndIf
    Else
        DebugMsg("No sender specified, defaulting to player")
        sender = playerRef
    EndIf

    Return DispatchGuardToHome(akGuard, targetName, sender, reason)
EndFunction

; =============================================================================
; DISPATCH PROGRESS MONITORING (Self-contained system)
; Phases:
;   1: Guard traveling to destination (target Actor or home marker)
;   2: Guard approaching target for arrest (same cell, within range)
;   3: Guard sandboxing at target's home (investigating)
;   4: Guard collecting evidence (picking up item)
;   5: Returning with prisoner or evidence to destination
;
; Off-screen handling:
;   - Guard walks the entire way - no teleportation shortcuts
;   - Same-cell interior detection (guard reached destination cell while off-screen)
;   - Game-time timeout (24h): force-complete if dispatch takes too long
; =============================================================================

Function CheckDispatchProgress()
    {Main dispatch monitor - called from OnUpdate when DispatchPhase > 0.
     Handles off-screen detection and routes to phase handlers.}

    ; Validate state - guard is always required; target required for arrest dispatches
    If DispatchGuard == None
        DebugMsg("ERROR: CheckDispatchProgress - guard is None")
        CancelDispatch()
        Return
    EndIf

    If !DispatchIsHomeInvestigation && DispatchTarget == None
        DebugMsg("ERROR: CheckDispatchProgress - target is None (arrest dispatch)")
        CancelDispatch()
        Return
    EndIf

    ; Check if guard died
    If DispatchGuard.IsDead()
        DebugMsg("Guard died during dispatch")
        CancelDispatch()
        Return
    EndIf

    ; Check if target died (only matters for arrest dispatches in phases 1-2)
    If !DispatchIsHomeInvestigation && DispatchPhase <= 2 && DispatchTarget != None && DispatchTarget.IsDead()
        DebugMsg("Target died during dispatch")
        CancelDispatch()
        Return
    EndIf

    ; Game-time timeout (24 game-hours max for entire dispatch)
    If DispatchGameTimeStart > 0.0
        Float elapsedHours = (Utility.GetCurrentGameTime() - DispatchGameTimeStart) * 24.0
        If elapsedHours > 24.0
            DebugMsg("Dispatch timeout (" + elapsedHours + "h) - force-completing")
            If DispatchIsHomeInvestigation
                ; Home investigation timeout: skip to return phase with whatever we have
                DebugMsg("Home investigation timeout - returning to sender")
                StartDispatchReturnPhase()
            Else
                PerformOffScreenArrest()
            EndIf
            Return
        EndIf
    EndIf

    ; Game-time-based arrival check for travel phases (handles T-wait / sleeping time skips)
    ; During time skips, OnUpdate doesn't fire but game time advances. When the update
    ; resumes, we check if enough game time elapsed for the guard to have arrived.
    If DispatchPhase == 1 && DispatchGameTimeStart > 0.0
        Float gameHoursElapsed = (Utility.GetCurrentGameTime() - DispatchGameTimeStart) * 24.0
        If gameHoursElapsed >= 0.25  ; At least 15 game-minutes (catches time-skips)
            ObjectReference travelDestCheck = None
            If DispatchIsHomeInvestigation && DispatchHomeMarker != None
                travelDestCheck = DispatchHomeMarker
            ElseIf DispatchTarget != None
                travelDestCheck = DispatchTarget as ObjectReference
            EndIf

            If travelDestCheck != None
                ; Use stored initial distance — GetDistance returns 0 cross-cell
                Float travelDistCheck = DispatchInitialDistance
                If travelDistCheck < 1000.0
                    travelDistCheck = 5000.0
                EndIf
                ; Guard jog speed: ~20000 units per game-hour
                Float requiredGameHours = travelDistCheck / 20000.0
                If requiredGameHours < 0.25
                    requiredGameHours = 0.25
                EndIf

                If gameHoursElapsed >= requiredGameHours
                    DebugMsg("Time-skip arrival: " + gameHoursElapsed + "h elapsed, " + requiredGameHours + "h required")
                    If DispatchIsHomeInvestigation
                        ; Move guard directly to home destination (interior marker)
                        If DispatchHomeMarker != None
                            DispatchGuard.MoveTo(DispatchHomeMarker)
                            Utility.Wait(0.3)
                            TransitionToSandboxPhase()
                        EndIf
                    Else
                        ; Arrest dispatch: perform off-screen arrest
                        PerformOffScreenArrest()
                    EndIf
                    Return
                EndIf
            EndIf
        EndIf
    ElseIf DispatchPhase == 5 && DispatchGameTimeStart > 0.0
        ; Return phase time-skip: check if guard has had enough time to return
        Float gameHoursReturn = (Utility.GetCurrentGameTime() - DispatchGameTimeStart) * 24.0
        If gameHoursReturn >= 0.5 && DispatchReturnMarker != None
            ; Use stored initial distance as proxy for return trip — GetDistance returns 0 cross-cell
            Float returnDistCheck = DispatchInitialDistance
            If returnDistCheck < 1000.0
                returnDistCheck = 5000.0
            EndIf
            Float requiredReturnHours = returnDistCheck / 20000.0
            If requiredReturnHours < 0.25
                requiredReturnHours = 0.25
            EndIf
            ; Return phase started after outbound travel, so check total time is enough for both legs
            If gameHoursReturn >= requiredReturnHours
                DebugMsg("Time-skip return arrival: " + gameHoursReturn + "h elapsed")
                DispatchGuard.MoveTo(DispatchReturnMarker, 200.0, 0.0, 0.0, false)
                If DispatchTarget != None
                    DispatchTarget.MoveTo(DispatchGuard, 50.0, 0.0, 0.0, false)
                EndIf
                Utility.Wait(0.3)
                CompleteDispatch()
                Return
            EndIf
        EndIf
    EndIf

    ; Check off-screen status (phase 1 only, not during return)
    If DispatchPhase == 1
        CheckDispatchOffScreen()
    EndIf

    ; Route to phase handler
    If DispatchPhase == 1
        CheckDispatchPhase1_Travel()
    ElseIf DispatchPhase == 2
        CheckDispatchPhase2_Approach()
    ElseIf DispatchPhase == 3
        CheckDispatchPhase3_Sandbox()
    ElseIf DispatchPhase == 4
        CheckDispatchPhase4_Evidence()
    ElseIf DispatchPhase == 5
        CheckDispatchPhase5_Return()
    ElseIf DispatchPhase == 6
        CheckJudgmentProgress()
    EndIf
EndFunction

Function CheckDispatchOffScreen()
    {Check if guard has arrived at destination while off-screen during Phase 1 travel.
     Uses a tiered approach: trust AI first, then intervene only as a last resort.

     The guard has an approach package and Skyrim's AI can pathfind through load doors.
     We give the AI generous time (minimum 120s) before teleporting, since same-cell
     detection in CheckDispatchPhase1_Travel handles natural arrival through doors.}

    Bool guardInLoadedArea = DispatchGuard.Is3DLoaded()

    If !guardInLoadedArea
        Cell guardCell = DispatchGuard.GetParentCell()

        ; --- First time going off-screen: record the timestamp ---
        If !DispatchGuardOffScreen
            DispatchGuardOffScreen = true
            DispatchOffScreenStartTime = Utility.GetCurrentRealTime()
            DebugMsg("Guard went off-screen during travel, trusting AI pathfinding")
        EndIf

        ; --- Calculate how long the guard should take to arrive ---
        Float elapsedOffScreen = Utility.GetCurrentRealTime() - DispatchOffScreenStartTime

        ; Determine destination reference
        ObjectReference travelDest = None
        If DispatchIsHomeInvestigation && DispatchHomeMarker != None
            travelDest = DispatchHomeMarker
        ElseIf DispatchTarget != None
            travelDest = DispatchTarget as ObjectReference
        EndIf

        ; Calculate required travel time from distance (300 units/sec jogging speed)
        ; Minimum 120 seconds — give AI plenty of time to pathfind through doors naturally.
        ; The same-cell check in CheckDispatchPhase1_Travel detects arrival through doors
        ; much earlier than this timer, so this is purely a fallback.
        Float requiredTime = 120.0  ; 2 minutes minimum before intervening
        If travelDest != None
            Float dist = DispatchInitialDistance
            If dist < 1000.0
                dist = 5000.0
            EndIf
            Float travelTime = dist / 300.0
            If travelTime > requiredTime
                requiredTime = travelTime
            EndIf
            ; Cap at 10 minutes real time to prevent absurdly long waits
            If requiredTime > 600.0
                requiredTime = 600.0
            EndIf
        EndIf

        ; --- Check if enough time has passed for arrival ---
        If elapsedOffScreen >= requiredTime
            DebugMsg("Off-screen travel time elapsed (" + elapsedOffScreen + "s / " + requiredTime + "s required)")

            If DispatchIsHomeInvestigation
                ; Home investigation: move guard directly to home destination (interior marker)
                If DispatchHomeMarker != None
                    DebugMsg("Off-screen: moving guard to home destination")
                    DispatchGuard.MoveTo(DispatchHomeMarker)
                    Utility.Wait(0.3)
                    TransitionToSandboxPhase()
                    Return
                EndIf
            ElseIf DispatchTarget != None
                ; Arrest dispatch: move guard near target and transition to approach
                DebugMsg("Off-screen: guard arrived at target location")
                DispatchGuard.MoveTo(DispatchTarget, 200.0, 0.0, 0.0, false)
                Utility.Wait(0.3)
                TransitionToApproachPhase()
                Return
            EndIf
        Else
            ; Still traveling — log progress periodically
            If Math.Floor(elapsedOffScreen) as Int % 30 == 0 && Math.Floor(elapsedOffScreen) as Int > 0
                DebugMsg("Off-screen travel: " + elapsedOffScreen as Int + "s / " + requiredTime as Int + "s, trusting AI")
            EndIf
        EndIf
    Else
        ; Guard is on-screen
        If DispatchGuardOffScreen
            DebugMsg("Guard back on-screen")
            DispatchGuardOffScreen = false
            DispatchOffScreenStartTime = 0.0
        EndIf
    EndIf
EndFunction

Function PerformOffScreenArrest()
    {Called when guard has been off-screen long enough or game-time timeout reached.
     Teleports guard to target, performs instant arrest, then starts return phase.
     Does NOT teleport to return destination — Phase 5 handles the return journey
     with proper time-based simulation so the guard doesn't appear out of thin air.}

    DebugMsg("Performing off-screen arrest of " + DispatchTarget.GetDisplayName())

    ; Stop stuck tracking
    SeverActionsNative.Stuck_StopTracking(DispatchGuard)

    ; Remove any active dispatch packages and clear linked ref
    If SeverActions_DispatchTravel
        ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchTravel)
    EndIf
    If SeverActions_GuardApproachTarget
        ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_GuardApproachTarget)
    EndIf
    If SeverActions_DispatchJog
        ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchJog)
    EndIf
    If DispatchTravelDestination != None
        DispatchTravelDestination.Clear()
    EndIf
    ClearAllDispatchLinkedRefs(DispatchGuard)

    ; Teleport guard to target (arrest happens at target's location, not at return destination)
    DispatchGuard.MoveTo(DispatchTarget, 100.0, 0.0, 0.0, false)
    Utility.Wait(0.2)

    ApplyDispatchArrestEffects()

    DebugMsg("Off-screen dispatch arrest effects applied to " + DispatchTarget.GetDisplayName())

    ; Narration: the arrest happened off-screen
    String guardName = DispatchGuard.GetDisplayName()
    String targetName = DispatchTarget.GetDisplayName()
    String narration = "*" + guardName + " arrests " + targetName + " and begins escorting them back.*"
    SkyrimNetApi.DirectNarration(narration, DispatchTarget, DispatchGuard)

    ; Notify the player that the arrest happened
    Debug.Notification(guardName + " has arrested " + targetName + " and is returning")

    Utility.Wait(0.3)

    ; Start return phase — guard+prisoner travel back via time-based simulation
    ; They are NOT teleported to the destination; Phase 5 handles the journey
    StartDispatchReturnPhase()
EndFunction

Function StartDispatchReturnPhase()
    {Start Phase 5: Guard returning with prisoner/evidence to sender or jail.
     Uses unified DispatchWalk package targeting DispatchTargetAlias (filled with
     DispatchReturnMarker, which is either the sender actor or the jail marker).}

    If DispatchSender != None
        DebugMsg("Starting return phase - returning to " + DispatchSender.GetDisplayName())
    Else
        DebugMsg("Starting return phase - escorting prisoner to jail")
    EndIf

    ; Put prisoner in alias to keep them high-process while unloaded.
    ; Without an alias, the engine stops evaluating the prisoner's AI packages
    ; when they're not 3D loaded, so their travel package wouldn't execute.
    If DispatchTarget != None && !DispatchIsHomeInvestigation && DispatchPrisonerAlias != None
        DispatchPrisonerAlias.ForceRefTo(DispatchTarget)
        DebugMsg("Prisoner alias filled: " + DispatchTarget.GetDisplayName())
    EndIf

    ; Fill dedicated alias with return destination (sender OR jail marker)
    ; DispatchWalk targets DispatchTargetAlias, so no sender-vs-jail branching needed.
    If DispatchReturnMarker != None
        DispatchTargetAlias.ForceRefTo(DispatchReturnMarker)
        DispatchGuardAlias.ForceRefTo(DispatchGuard)

        ; Apply walk-speed return package (targets DispatchTargetAlias)
        If SeverActions_DispatchWalk
            ActorUtil.AddPackageOverride(DispatchGuard, SeverActions_DispatchWalk, PackagePriority, 1)
            DispatchGuard.EvaluatePackage()
            If DispatchSender != None
                DebugMsg("Applied DispatchWalk for return to " + DispatchSender.GetDisplayName())
            Else
                DebugMsg("Applied DispatchWalk for return to jail")
            EndIf
        EndIf

        ; Disable NPC-NPC collision for the return journey
        SeverActionsNative.SetActorBumpable(DispatchGuard, false)
    EndIf

    ; Prisoner follows the guard for the entire return journey.
    ; DispatchPrisonerAlias keeps the prisoner high-process so Follow works across cells.
    ; Disable collision so guard and prisoner don't block each other at doors.
    If DispatchTarget != None && !DispatchIsHomeInvestigation
        SeverActionsNative.SetActorBumpable(DispatchTarget, false)
        PO3_SKSEFunctions.SetLinkedRef(DispatchTarget, DispatchGuard, SeverActions_FollowTargetKW)
        Utility.Wait(0.2)
        Debug.SendAnimationEvent(DispatchTarget, "IdleForceDefaultState")
        Utility.Wait(0.1)
        If SeverActions_FollowGuard_Prisoner
            ActorUtil.AddPackageOverride(DispatchTarget, SeverActions_FollowGuard_Prisoner, PackagePriority, 1)
            DispatchTarget.EvaluatePackage()
        EndIf
        DebugMsg("Prisoner following guard for return journey")
    EndIf

    ; Start stuck tracking for return journey
    SeverActionsNative.Stuck_StartTracking(DispatchGuard)

    ; Initialize off-screen travel estimation for the return journey
    ; Use shorter bounds (0.25-12h) since return trips are typically shorter
    If DispatchReturnMarker != None
        SeverActionsNative.OffScreen_InitTracking(DispatchGuard, DispatchReturnMarker, 0.25, 12.0)
    EndIf

    DispatchPhase = 5
    StorageUtil.SetIntValue(DispatchGuard, "SeverActions_DispatchPhase", DispatchPhase)
    DispatchGuardOffScreen = false
    DispatchOffScreenStartTime = 0.0
    DispatchReturnOffScreenCycle = 0
    DispatchReturnNarrated = false

    RegisterForSingleUpdate(UpdateInterval)
EndFunction

Function ReapplyReturnPackages()
    {Re-apply aliases and walk package after a cross-cell MoveTo.
     Simplified -- DispatchWalk always targets DispatchTargetAlias.}

    DispatchTargetAlias.ForceRefTo(DispatchReturnMarker)
    DispatchGuardAlias.ForceRefTo(DispatchGuard)
    If SeverActions_DispatchWalk
        ActorUtil.AddPackageOverride(DispatchGuard, SeverActions_DispatchWalk, PackagePriority, 1)
    EndIf

    ; Re-apply prisoner follow if applicable
    If DispatchTarget != None && !DispatchIsHomeInvestigation
        PO3_SKSEFunctions.SetLinkedRef(DispatchTarget, DispatchGuard, SeverActions_FollowTargetKW)
        Utility.Wait(0.2)
        If SeverActions_FollowGuard_Prisoner
            ActorUtil.AddPackageOverride(DispatchTarget, SeverActions_FollowGuard_Prisoner, PackagePriority, 1)
            DispatchTarget.EvaluatePackage()
        EndIf
    EndIf

    DispatchGuard.EvaluatePackage()

    ; Reset stuck tracking since position snapshot is stale after teleport
    SeverActionsNative.Stuck_StopTracking(DispatchGuard)
    SeverActionsNative.Stuck_StartTracking(DispatchGuard)

    ; Grace period: suppress stuck detection for 5 seconds to let actors settle on navmesh
    DispatchStuckGraceUntil = Utility.GetCurrentRealTime() + 5.0

    DebugMsg("Re-applied return packages after cell transition")
EndFunction

Function CheckDispatchPhase1_Travel()
    {Phase 1: Guard traveling to destination (target Actor or home interior marker).
     Skyrim AI handles cross-cell pathfinding through doors automatically. We monitor for:
     - Same cell as destination (transition to approach or sandbox)
     - Close enough to destination (transition to approach or sandbox)
     - Stuck detection with leapfrog recovery}

    Float dist
    Int stuckLevel
    ObjectReference travelDest

    ; Determine travel destination based on dispatch type
    If DispatchIsHomeInvestigation && DispatchHomeMarker != None
        travelDest = DispatchHomeMarker
    ElseIf DispatchTarget != None
        travelDest = DispatchTarget as ObjectReference
    Else
        DebugMsg("ERROR: Phase1 - no valid travel destination")
        CancelDispatch()
        Return
    EndIf

    ; Departure check — verify guard actually started moving
    ; CheckDeparture has a 15-second grace period, then returns 2 if guard hasn't moved 100+ units
    If DispatchGuard.Is3DLoaded()
        Int departureStatus = SeverActionsNative.Stuck_CheckDeparture(DispatchGuard, 100.0)
        If departureStatus == 2
            ; Guard hasn't moved in 30 seconds — soft recovery
            DebugMsg("Guard failed to depart — applying soft recovery")
            DispatchGuard.EvaluatePackage()
            ; Disable AI processing briefly and re-enable to break any animation lock
            DispatchGuard.SetDontMove(true)
            Utility.Wait(0.3)
            DispatchGuard.SetDontMove(false)
            DispatchGuard.EvaluatePackage()
            SeverActionsNative.Stuck_ResetEscalation(DispatchGuard)
        EndIf
    EndIf

    ; Check stuck detection
    stuckLevel = SeverActionsNative.Stuck_CheckStatus(DispatchGuard, UpdateInterval, 50.0)
    If stuckLevel >= 2
        DebugMsg("Guard stuck (level " + stuckLevel + "), nudging...")
        DispatchGuard.EvaluatePackage()
        If stuckLevel >= 3 && travelDest != None
            ; Severe stuck - leapfrog toward destination
            Float teleportDist = SeverActionsNative.Stuck_GetTeleportDistance(DispatchGuard)
            DispatchGuard.MoveTo(travelDest, teleportDist, 0.0, 0.0, false)
            SeverActionsNative.Stuck_ResetEscalation(DispatchGuard)

            ; If severely stuck and target is in an interior, try the door instead
            If !DispatchIsHomeInvestigation && DispatchTarget != None
                Cell targetCell = DispatchTarget.GetParentCell()
                If targetCell != None && targetCell.IsInterior()
                    ObjectReference doorRef = SeverActionsNative.FindDoorToActorCell(DispatchTarget)
                    If doorRef != None
                        DebugMsg("Severe stuck: redirecting to door of target's interior cell")
                        DispatchGuard.MoveTo(doorRef, 200.0, 0.0, 0.0, false)
                    EndIf
                EndIf
            EndIf
        EndIf
    EndIf

    ; Same cell check — dest is now the interior marker (home) or target Actor (arrest)
    ; so same cell = guard has pathfound through doors and arrived
    Cell guardCell = DispatchGuard.GetParentCell()
    Cell destCell = travelDest.GetParentCell()
    If guardCell != None && destCell != None && guardCell == destCell
        If DispatchIsHomeInvestigation
            ; Guard is in the same cell as the interior marker — they're inside the home
            dist = DispatchGuard.GetDistance(travelDest)
            If dist <= DispatchArrivalDistance
                DebugMsg("Guard arrived inside home (same cell, dist=" + dist + "), transitioning to sandbox")
                TransitionToSandboxPhase()
                Return
            EndIf
        ElseIf guardCell.IsInterior()
            ; Interior cells are small enough that same-cell = arrived
            DebugMsg("Guard is in same interior cell as target, transitioning to approach phase")
            TransitionToApproachPhase()
            Return
        Else
            ; Exterior cells can be very large — only transition if within ArrivalDistance
            If DispatchGuard.Is3DLoaded() && travelDest.Is3DLoaded()
                dist = DispatchGuard.GetDistance(travelDest)
                If dist <= DispatchArrivalDistance
                    DebugMsg("Guard near target in same exterior cell (dist=" + dist + "), transitioning to approach")
                    TransitionToApproachPhase()
                    Return
                EndIf
            EndIf
        EndIf
    EndIf

    ; Snapshot-based distance check (works off-screen via position snapshots)
    If !DispatchGuard.Is3DLoaded() || !travelDest.Is3DLoaded()
        ; Guard or destination is off-screen — try native distance
        If !DispatchIsHomeInvestigation
            ; Home marker isn't an actor, can't use GetDistanceBetweenActors
            Float snapDist = SeverActionsNative.GetDistanceBetweenActors(DispatchGuard, DispatchTarget)
            If snapDist >= 0.0 && snapDist <= DispatchArrivalDistance
                DebugMsg("Snapshot distance arrival: guard within " + snapDist + " of target (off-screen)")
                TransitionToApproachPhase()
                Return
            EndIf
        EndIf
    EndIf

    ; Off-screen travel estimation — if guard has been traveling off-screen long enough,
    ; teleport them to destination based on distance-calculated estimate
    If !DispatchGuard.Is3DLoaded()
        Int arrivalStatus = SeverActionsNative.OffScreen_CheckArrival(DispatchGuard, Utility.GetCurrentGameTime())
        If arrivalStatus == 1
            DebugMsg("Off-screen travel estimate elapsed — teleporting guard to destination")
            DispatchGuard.MoveTo(travelDest, 300.0, 0.0, 0.0, false)
            If !DispatchIsHomeInvestigation && DispatchTarget != None
                ; Place guard near target for arrest
                DispatchGuard.MoveTo(DispatchTarget, ApproachDistance, 0.0, 0.0, false)
            EndIf
            Utility.Wait(0.5)
            DispatchGuard.EvaluatePackage()
            SeverActionsNative.OffScreen_StopTracking(DispatchGuard)
            ; Let the next tick detect same-cell/proximity and transition naturally
            RegisterForSingleUpdate(UpdateInterval)
            Return
        EndIf
    EndIf

    ; Distance check (both 3D loaded — same exterior area or player cell)
    If DispatchGuard.Is3DLoaded() && travelDest.Is3DLoaded()
        dist = DispatchGuard.GetDistance(travelDest)
        If dist <= DispatchArrivalDistance
            If DispatchIsHomeInvestigation
                DebugMsg("Guard arrived at home destination (dist=" + dist + "), transitioning to sandbox")
                TransitionToSandboxPhase()
            Else
                DebugMsg("Guard near target (dist=" + dist + "), transitioning to approach")
                TransitionToApproachPhase()
            EndIf
            Return
        EndIf
    EndIf

    ; Stale snapshot redirect — if guard has been traveling 5+ game-hours without finding target,
    ; check if target's position data is very old and redirect to their home instead
    If !DispatchIsHomeInvestigation && DispatchGameTimeStart > 0.0
        Float travelHours = (Utility.GetCurrentGameTime() - DispatchGameTimeStart) * 24.0
        If travelHours >= 5.0
            ; Check how old the target's snapshot is
            Float snapshotTime = SeverActionsNative.GetActorSnapshotGameTime(DispatchTarget)
            If snapshotTime > 0.0
                Float snapshotAge = (Utility.GetCurrentGameTime() - snapshotTime) * 24.0
                If snapshotAge > 24.0
                    DebugMsg("Target snapshot is " + snapshotAge + "h old — redirecting to home")
                    ; Try to find target's home
                    ObjectReference homeMarker = SeverActionsNative.FindHomeInteriorMarker(DispatchTarget)
                    If homeMarker == None
                        ObjectReference homeDoor = SeverActionsNative.FindDoorToActorHome(DispatchTarget)
                        If homeDoor != None
                            homeMarker = homeDoor
                        EndIf
                    EndIf

                    If homeMarker != None
                        ; Redirect guard to target's home
                        DebugMsg("Redirecting guard to target's home")
                        ArrestTarget.ForceRefTo(homeMarker)
                        DispatchGuard.EvaluatePackage()
                        ; Don't change DispatchTarget — still arresting same person
                        ; Guard will arrive at home and wait for target
                    EndIf
                EndIf
            EndIf
        EndIf
    EndIf

    ; Continue monitoring
    RegisterForSingleUpdate(UpdateInterval)
EndFunction

Function RestoreGuardCombatAI()
    {Restore guard's original aggression/confidence after dispatch.}
    If DispatchGuard != None
        DispatchGuard.SetAV("Aggression", DispatchGuardOrigAggression)
        DispatchGuard.SetAV("Confidence", DispatchGuardOrigConfidence)
    EndIf
EndFunction

Function TransitionToApproachPhase()
    {Transition to Phase 2: approaching target for arrest.
     Guard is already using GuardApproachTarget package (applied at dispatch start)
     and aliases are already filled. Just stop travel tracking and draw weapon.}

    ; Stop stuck tracking for travel
    SeverActionsNative.Stuck_StopTracking(DispatchGuard)

    ; Restore normal NPC-NPC collision — guard is near target
    SeverActionsNative.SetActorBumpable(DispatchGuard, true)

    ; Restore guard combat AI — guard needs aggression to perform the arrest
    RestoreGuardCombatAI()

    ; Ensure aliases are current (they should already be filled from dispatch start)
    ArrestTarget.ForceRefTo(DispatchTarget)
    ArrestingGuard.ForceRefTo(DispatchGuard)

    ; Ensure approach package is applied and re-evaluate
    If SeverActions_GuardApproachTarget
        ActorUtil.AddPackageOverride(DispatchGuard, SeverActions_GuardApproachTarget, PackagePriority, 1)
        DispatchGuard.EvaluatePackage()
        DebugMsg("Approach phase: guard approaching target")
    EndIf

    DispatchGuard.DrawWeapon()
    DispatchPhase = 2
    StorageUtil.SetIntValue(DispatchGuard, "SeverActions_DispatchPhase", DispatchPhase)
    RegisterForSingleUpdate(UpdateInterval)
EndFunction

Function CheckDispatchPhase2_Approach()
    {Phase 2: Guard approaching target in same cell for arrest.
     GetDistance returns 0 for unloaded actors, so we must guard against false positives.
     If neither is 3D loaded, use snapshot distance instead. If both unloaded and snapshot
     confirms proximity (or is unavailable), proceed — the guard was transitioned to Phase 2
     because same-cell was already confirmed.}

    Float dist = -1.0
    Bool bothLoaded = DispatchGuard.Is3DLoaded() && DispatchTarget.Is3DLoaded()

    If bothLoaded
        dist = DispatchGuard.GetDistance(DispatchTarget)
    Else
        ; One or both actors not loaded — use snapshot distance
        dist = SeverActionsNative.GetDistanceBetweenActors(DispatchGuard, DispatchTarget)
        If dist < 0.0
            ; Snapshot unavailable — we already confirmed same-cell to reach Phase 2,
            ; so trust it and proceed with the arrest
            dist = 0.0
            DebugMsg("Phase 2: both unloaded, no snapshot — trusting same-cell arrival")
        EndIf
    EndIf

    If dist >= 0.0 && dist <= ApproachDistance
        DebugMsg("Guard reached target (dist=" + dist + ", loaded=" + bothLoaded + "), performing arrest")

        ; Remove approach/dispatch packages (will be replaced by walk package in return phase)
        If SeverActions_GuardApproachTarget
            ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_GuardApproachTarget)
        EndIf
        If SeverActions_DispatchJog
            ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchJog)
        EndIf

        ; DO NOT clear aliases here — they're needed for Phase 5 return journey
        ; ArrestingGuard keeps the guard in high-process while off-screen
        ; ArrestTarget will be repurposed in StartDispatchReturnPhase

        ApplyDispatchArrestEffects()

        DebugMsg("Dispatch arrest effects applied to " + DispatchTarget.GetDisplayName())

        ; Narrate the arrest
        String guardName = DispatchGuard.GetDisplayName()
        String targetName = DispatchTarget.GetDisplayName()
        String narration = "*" + guardName + " seizes " + targetName + " and places them under arrest.*"
        SkyrimNetApi.DirectNarration(narration, DispatchGuard, DispatchTarget)

        ; Notify player even when the arrest happens off-screen
        Debug.Notification(guardName + " has arrested " + targetName)

        ; Transition to return phase (escort prisoner back to jail or Jarl)
        StartDispatchReturnPhase()
        Return
    EndIf

    RegisterForSingleUpdate(UpdateInterval)
EndFunction

Function TransitionToSandboxPhase()
    {Transition to Phase 3: Guard sandboxes at target's home (investigating).
     Guard looks around the home, searching for evidence.}

    ; Stop stuck tracking for travel
    SeverActionsNative.Stuck_StopTracking(DispatchGuard)

    ; Restore normal NPC-NPC collision — guard is inside home
    SeverActionsNative.SetActorBumpable(DispatchGuard, true)

    ; Remove travel/approach/dispatch packages and clear linked ref
    If SeverActions_GuardApproachTarget
        ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_GuardApproachTarget)
    EndIf
    If SeverActions_DispatchTravel
        ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchTravel)
    EndIf
    If SeverActions_DispatchJog
        ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchJog)
    EndIf
    If DispatchTravelDestination != None
        DispatchTravelDestination.Clear()
    EndIf
    ClearAllDispatchLinkedRefs(DispatchGuard)

    ; Set up sandbox anchor INSIDE the home cell
    ; Priority: home destination (interior marker) > target NPC (if same cell) > guard (fallback)
    ObjectReference sandboxAnchor = DispatchGuard as ObjectReference
    If DispatchHomeMarker != None
        sandboxAnchor = DispatchHomeMarker
        DebugMsg("Sandbox anchor: home destination marker")
    ElseIf DispatchTarget != None
        Cell guardCell = DispatchGuard.GetParentCell()
        Cell targetCell = DispatchTarget.GetParentCell()
        If guardCell != None && guardCell == targetCell
            sandboxAnchor = DispatchTarget as ObjectReference
            DebugMsg("Sandbox anchor: target NPC (same cell)")
        Else
            DebugMsg("Sandbox anchor: guard position (target in different cell)")
        EndIf
    Else
        DebugMsg("Sandbox anchor: guard position (no target)")
    EndIf
    PO3_SKSEFunctions.SetLinkedRef(DispatchGuard, sandboxAnchor, SeverActions_SandboxAnchorKW)

    ; Apply sandbox package (reuses PrisonerSandBox which sandboxes near linked ref)
    If SeverActions_PrisonerSandBox
        ActorUtil.AddPackageOverride(DispatchGuard, SeverActions_PrisonerSandBox, PackagePriority, 1)
        DispatchGuard.EvaluatePackage()
        DebugMsg("Applied sandbox package - guard investigating inside home")
    EndIf

    ; Register with native sandbox manager for auto-cleanup
    If SeverActions_PrisonerSandBox
        SeverActionsNative.RegisterSandboxUser(DispatchGuard, SeverActions_PrisonerSandBox, 2000.0)
    EndIf

    ; Randomize sandbox duration (15-30 seconds real time)
    DispatchSandboxStartTime = Utility.GetCurrentRealTime()
    DispatchSandboxDuration = Utility.RandomFloat(15.0, 30.0)
    DebugMsg("Guard will investigate for " + DispatchSandboxDuration + " seconds")

    ; Narration: guard is searching the home
    String guardName = DispatchGuard.GetDisplayName()
    String targetName = ""
    If DispatchTarget != None
        targetName = DispatchTarget.GetDisplayName()
    EndIf
    String narration = "*" + guardName + " begins searching " + targetName + "'s home, looking through belongings for evidence.*"
    SkyrimNetApi.DirectNarration(narration, DispatchGuard, DispatchTarget)

    DispatchPhase = 3
    StorageUtil.SetIntValue(DispatchGuard, "SeverActions_DispatchPhase", DispatchPhase)
    RegisterForSingleUpdate(UpdateInterval)
EndFunction

Function CheckDispatchPhase3_Sandbox()
    {Phase 3: Guard sandboxing at target's home (investigating).
     After the sandbox duration expires, transition to evidence collection.}

    Float elapsed = Utility.GetCurrentRealTime() - DispatchSandboxStartTime

    If elapsed >= DispatchSandboxDuration
        DebugMsg("Sandbox investigation complete (" + elapsed + "s), collecting evidence")
        TransitionToEvidencePhase()
        Return
    EndIf

    RegisterForSingleUpdate(UpdateInterval)
EndFunction

Function TransitionToEvidencePhase()
    {Transition to Phase 4: Guard collects evidence.
     On-screen (player watching): Guard finds suspicious item, walks to it, picks it up.
     Off-screen (player away): Guard gets a contextual evidence item based on target NPC's class.}

    ; Unregister from sandbox manager
    SeverActionsNative.UnregisterSandboxUser(DispatchGuard)

    ; Remove sandbox package
    If SeverActions_PrisonerSandBox
        ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_PrisonerSandBox)
    EndIf
    PO3_SKSEFunctions.SetLinkedRef(DispatchGuard, None, SeverActions_SandboxAnchorKW)

    DispatchPhase = 4
    StorageUtil.SetIntValue(DispatchGuard, "SeverActions_DispatchPhase", DispatchPhase)

    String guardName = DispatchGuard.GetDisplayName()
    String targetName = ""
    If DispatchTarget != None
        targetName = DispatchTarget.GetDisplayName()
    EndIf

    Bool playerWatching = DispatchGuard.Is3DLoaded()

    If playerWatching
        ; === ON-SCREEN: Generate reason-appropriate evidence, play pickup animation ===
        DebugMsg("Evidence collection: player is watching")

        ; First try to generate reason-appropriate evidence (same logic as off-screen)
        Form evidenceForm = None
        If DispatchInvestigationReason != ""
            DebugMsg("On-screen evidence: using reason '" + DispatchInvestigationReason + "'")
            evidenceForm = SeverActionsNative.GenerateEvidenceForReason(DispatchInvestigationReason, DispatchTarget)
        EndIf

        ; Fallback: try to find an actual suspicious item in the world
        If evidenceForm == None
            DebugMsg("On-screen evidence: no reason match, scanning for world items")
            ObjectReference evidenceRef = SeverActionsNative.FindSuspiciousItem(DispatchGuard, 2000.0)
            If evidenceRef == None
                evidenceRef = SeverActionsNative.FindNearbyItemOfType(DispatchGuard, "", 2000.0)
            EndIf

            If evidenceRef != None
                DispatchEvidenceItem = evidenceRef
                DispatchEvidenceForm = evidenceRef.GetBaseObject()
                DispatchEvidenceName = evidenceRef.GetDisplayName()
                String itemName = DispatchEvidenceName
                DebugMsg("Found world item: " + itemName + ", guard walking to it")

                ; Point travel alias at the evidence item and apply travel package
                If DispatchTravelDestination != None
                    DispatchTravelDestination.ForceRefTo(evidenceRef)
                EndIf
                If SeverActions_DispatchTravel
                    ActorUtil.AddPackageOverride(DispatchGuard, SeverActions_DispatchTravel, PackagePriority, 1)
                    DispatchGuard.EvaluatePackage()
                EndIf

                ; Phase 4 will monitor guard walking to the item and picking it up
                RegisterForSingleUpdate(UpdateInterval)
                Return
            EndIf
        EndIf

        If evidenceForm != None
            ; We have a reason-generated item — guard "finds" it during the search
            DispatchEvidenceForm = evidenceForm
            DispatchEvidenceName = evidenceForm.GetName()
            String itemName = DispatchEvidenceName
            DebugMsg("Generated reason-based evidence on-screen: " + itemName)

            ; Find a nearby container or furniture to walk to (makes it look like guard found it there)
            ObjectReference searchTarget = SeverActionsNative.FindNearbyContainer(DispatchGuard, "", 2000.0)
            If searchTarget != None
                ; Walk guard to the container
                If DispatchTravelDestination != None
                    DispatchTravelDestination.ForceRefTo(searchTarget)
                EndIf
                If SeverActions_DispatchTravel
                    ActorUtil.AddPackageOverride(DispatchGuard, SeverActions_DispatchTravel, PackagePriority, 1)
                    DispatchGuard.EvaluatePackage()
                EndIf

                ; Wait for guard to reach the container (up to 10 seconds)
                Int waitCount = 0
                While waitCount < 20 && DispatchGuard.GetDistance(searchTarget) > 150.0
                    Utility.Wait(0.5)
                    waitCount += 1
                EndWhile

                ; Remove travel package and clear travel alias
                If SeverActions_DispatchTravel
                    ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchTravel)
                EndIf
                If DispatchTravelDestination != None
                    DispatchTravelDestination.Clear()
                EndIf
            EndIf

            ; Play pickup animation and add item to inventory
            Debug.SendAnimationEvent(DispatchGuard, "IdlePickupFromTableStart")
            Utility.Wait(1.5)
            DispatchGuard.AddItem(evidenceForm, 1, true)

            ; Narrate the find
            String narration = "*" + guardName + " rummages through " + targetName + "'s belongings and discovers " + itemName + ", tucking it away as evidence.*"
            SkyrimNetApi.DirectNarration(narration, DispatchGuard, DispatchTarget)

            String eventMsg = guardName + " found evidence (" + itemName + ") at " + targetName + "'s home."
            SkyrimNetApi.RegisterPersistentEvent(eventMsg, DispatchGuard, DispatchTarget)

            Debug.Notification(guardName + " collected evidence: " + itemName)

            ; Short pause then start return journey
            Utility.Wait(1.0)
            StartDispatchReturnPhase()
            Return
        Else
            ; No evidence at all — return empty-handed
            DebugMsg("No evidence found at home (on-screen) - guard returning empty-handed")
            String narration = "*" + guardName + " finishes searching " + targetName + "'s home but finds nothing of note.*"
            SkyrimNetApi.DirectNarration(narration, DispatchGuard, DispatchTarget)
        EndIf
    Else
        ; === OFF-SCREEN: Generate evidence based on investigation reason (or NPC class fallback) ===
        Form evidenceForm = None
        If DispatchInvestigationReason != ""
            DebugMsg("Evidence collection: using investigation reason '" + DispatchInvestigationReason + "'")
            evidenceForm = SeverActionsNative.GenerateEvidenceForReason(DispatchInvestigationReason, DispatchTarget)
        Else
            DebugMsg("Evidence collection: no reason provided, using NPC class")
            evidenceForm = SeverActionsNative.GenerateContextualEvidence(DispatchTarget)
        EndIf

        If evidenceForm != None
            DispatchEvidenceForm = evidenceForm
            DispatchEvidenceName = evidenceForm.GetName()
            String itemName = DispatchEvidenceName
            DebugMsg("Generated contextual evidence: " + itemName)

            ; Add the item directly to guard's inventory (player isn't watching)
            DispatchGuard.AddItem(evidenceForm, 1, true)

            ; Register persistent event so NPCs know about the evidence
            String eventMsg = guardName + " found evidence (" + itemName + ") at " + targetName + "'s home."
            SkyrimNetApi.RegisterPersistentEvent(eventMsg, DispatchGuard, DispatchTarget)
        Else
            DebugMsg("Could not generate contextual evidence - guard returning empty-handed")

            String narration = "*" + guardName + " finishes searching " + targetName + "'s home but finds nothing of note.*"
            SkyrimNetApi.DirectNarration(narration, DispatchGuard, DispatchTarget)
        EndIf
    EndIf

    ; Short pause then start return journey
    Utility.Wait(1.0)
    StartDispatchReturnPhase()
EndFunction

Function CheckDispatchPhase4_Evidence()
    {Phase 4: Guard walking to evidence item (on-screen) or completing pickup.
     Monitors the guard's distance to the evidence item. When close enough,
     guard picks it up and narrates, then transitions to return phase.}

    ; If no evidence item was found, this is a fallback — just return
    If DispatchEvidenceItem == None
        DebugMsg("Phase 4: no evidence item target, starting return")
        StartDispatchReturnPhase()
        Return
    EndIf

    ; Check if guard is close enough to the evidence item to pick it up
    Float dist = DispatchGuard.GetDistance(DispatchEvidenceItem)
    DebugMsg("Phase 4: guard distance to evidence = " + dist)

    If dist <= 150.0
        ; Guard is at the item — pick it up with natural animation
        String guardName = DispatchGuard.GetDisplayName()
        String targetName = ""
        If DispatchTarget != None
            targetName = DispatchTarget.GetDisplayName()
        EndIf
        String itemName = DispatchEvidenceName

        ; Remove travel package and clear travel alias
        If SeverActions_DispatchTravel
            ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchTravel)
        EndIf
        If DispatchTravelDestination != None
            DispatchTravelDestination.Clear()
        EndIf

        ; Use Activate for natural pickup animation (guard reaches down, item disappears)
        ; This plays the same animation as when any actor picks up an item in the world
        DispatchEvidenceItem.Activate(DispatchGuard)

        ; Wait for the pickup animation to play, then verify item was collected
        Utility.Wait(1.5)

        ; Fallback: if Activate failed (ownership block, etc.), force AddItem
        If !DispatchGuard.GetItemCount(DispatchEvidenceForm)
            DebugMsg("Phase 4: Activate pickup failed, falling back to AddItem")
            DispatchGuard.AddItem(DispatchEvidenceItem, 1, true)
        EndIf

        ; Narration: guard found evidence (player is watching, so narrate)
        String narration = "*" + guardName + " picks up " + itemName + " as evidence from " + targetName + "'s home.*"
        SkyrimNetApi.DirectNarration(narration, DispatchGuard, DispatchTarget)

        ; Register persistent event so NPCs know about the evidence
        String eventMsg = guardName + " found evidence (" + itemName + ") at " + targetName + "'s home."
        SkyrimNetApi.RegisterPersistentEvent(eventMsg, DispatchGuard, DispatchTarget)

        Debug.Notification(guardName + " collected evidence: " + itemName)

        ; Short pause then start return journey
        Utility.Wait(1.0)
        StartDispatchReturnPhase()
        Return
    EndIf

    ; Guard still walking — check for stuck
    Int stuckLevel = SeverActionsNative.Stuck_CheckStatus(DispatchGuard, UpdateInterval, 30.0)
    If stuckLevel >= 3
        ; Guard hopelessly stuck trying to reach item — just grab it from distance
        DebugMsg("Phase 4: guard stuck reaching evidence, force-picking up")

        If SeverActions_DispatchTravel
            ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchTravel)
        EndIf
        If DispatchTravelDestination != None
            DispatchTravelDestination.Clear()
        EndIf

        String guardName = DispatchGuard.GetDisplayName()
        String targetName = ""
        If DispatchTarget != None
            targetName = DispatchTarget.GetDisplayName()
        EndIf
        String itemName = DispatchEvidenceName

        DispatchGuard.AddItem(DispatchEvidenceItem, 1, true)

        String narration = "*" + guardName + " picks up " + itemName + " as evidence from " + targetName + "'s home.*"
        SkyrimNetApi.DirectNarration(narration, DispatchGuard, DispatchTarget)

        String eventMsg = guardName + " found evidence (" + itemName + ") at " + targetName + "'s home."
        SkyrimNetApi.RegisterPersistentEvent(eventMsg, DispatchGuard, DispatchTarget)

        Debug.Notification(guardName + " collected evidence: " + itemName)

        Utility.Wait(1.0)
        StartDispatchReturnPhase()
        Return
    EndIf

    RegisterForSingleUpdate(UpdateInterval)
EndFunction

Function CheckDispatchPhase5_Return()
    {Phase 5: Guard returning with prisoner to sender or jail.
     Tiered off-screen approach with interior-aware early exit.

     Off-screen tiers:
       Interior exit (10s): If guard is in interior, move both to exterior side of door
                            (Skyrim AI cannot pathfind in unloaded interiors)
       Tier 0 (0-90s):     Trust AI for exterior travel
       Tier 1 (90-150s):   Re-evaluate packages as a nudge
       Tier 2 (150s+):     Teleport to destination, force complete after 2 cycles}

    ; Prisoner follows the guard directly — no tether needed.

    Float dist
    Int stuckLevel
    Bool guardLoaded = DispatchGuard.Is3DLoaded()

    If guardLoaded
        ; --- On-screen: normal stuck detection and distance checks ---
        If DispatchGuardOffScreen
            DebugMsg("Guard back on-screen during return")
            DispatchGuardOffScreen = false
            DispatchOffScreenStartTime = 0.0
            DispatchReturnOffScreenCycle = 0
        EndIf

        ; First time guard is on-screen with prisoner: narrate the arrest so NPCs can speak about it.
        ; DirectNarration fires when actors are loaded, allowing SkyrimNet to generate voiced dialogue.
        If !DispatchReturnNarrated && !DispatchIsHomeInvestigation && DispatchTarget != None
            DispatchReturnNarrated = true
            String guardName = DispatchGuard.GetDisplayName()
            String targetName = DispatchTarget.GetDisplayName()
            String narration = "*" + guardName + " arrives escorting " + targetName + " in custody, hands bound.*"
            SkyrimNetApi.DirectNarration(narration, DispatchGuard, DispatchTarget)
            DebugMsg("Narrated on-screen return: " + guardName + " escorting " + targetName)
        EndIf

        ; Check stuck detection (suppressed during grace period after cell transitions)
        If Utility.GetCurrentRealTime() >= DispatchStuckGraceUntil
            stuckLevel = SeverActionsNative.Stuck_CheckStatus(DispatchGuard, UpdateInterval, 50.0)
            If stuckLevel >= 2
                DispatchGuard.EvaluatePackage()
                If DispatchTarget != None
                    DispatchTarget.EvaluatePackage()
                EndIf
                If stuckLevel >= 3 && DispatchReturnMarker != None
                    Float teleportDist = SeverActionsNative.Stuck_GetTeleportDistance(DispatchGuard)
                    DispatchGuard.MoveTo(DispatchReturnMarker, teleportDist, 0.0, 0.0, false)
                    If DispatchTarget != None
                        DispatchTarget.MoveTo(DispatchGuard, 50.0, 0.0, 0.0, false)
                    EndIf
                    SeverActionsNative.Stuck_ResetEscalation(DispatchGuard)
                    ; Grace period after this teleport too
                    DispatchStuckGraceUntil = Utility.GetCurrentRealTime() + 5.0
                EndIf
            EndIf
        EndIf

        ; Check arrival at return destination
        ; Both must be 3D loaded — GetDistance returns 0 cross-cell which falsely triggers arrival
        If DispatchReturnMarker != None && DispatchGuard.Is3DLoaded() && DispatchReturnMarker.Is3DLoaded()
            dist = DispatchGuard.GetDistance(DispatchReturnMarker)
            If dist <= DispatchArrivalDistance
                DebugMsg("Guard arrived at return destination (dist=" + dist + ")")
                CompleteDispatch()
                Return
            EndIf
        EndIf
    Else
        ; --- Off-screen: tiered escalation ---
        If !DispatchGuardOffScreen
            DispatchGuardOffScreen = true
            DispatchOffScreenStartTime = Utility.GetCurrentRealTime()
            DebugMsg("Guard went off-screen during return (cycle " + DispatchReturnOffScreenCycle + ")")
        EndIf

        ; Always check: same interior cell as destination (instant arrival detection)
        Cell guardCell = DispatchGuard.GetParentCell()
        If DispatchReturnMarker != None
            Cell destCell = DispatchReturnMarker.GetParentCell()
            If guardCell != None && guardCell == destCell && guardCell.IsInterior()
                DebugMsg("Guard reached return destination cell (off-screen interior)")
                CompleteDispatch()
                Return
            EndIf
        EndIf

        ; Always check: snapshot distance to sender (works off-screen via position snapshots)
        If DispatchSender != None
            Float snapReturnDist = SeverActionsNative.GetDistanceBetweenActors(DispatchGuard, DispatchSender)
            If snapReturnDist >= 0.0 && snapReturnDist <= DispatchArrivalDistance
                DebugMsg("Snapshot distance: guard within " + snapReturnDist + " of sender (off-screen)")
                CompleteDispatch()
                Return
            EndIf
        EndIf

        Float elapsedOffScreen = Utility.GetCurrentRealTime() - DispatchOffScreenStartTime

        ; === INTERIOR EARLY EXIT (10 seconds) ===
        ; Skyrim's AI does NOT process NPC movement in unloaded interiors. When the player
        ; is outside and the guard is inside, the guard will never pathfind to the door on
        ; their own. After a short immersion delay (simulating walking to the exit), move
        ; both guard and prisoner to the exterior side of the door.
        If guardCell != None && guardCell.IsInterior() && elapsedOffScreen >= 10.0 && DispatchReturnOffScreenCycle == 0
            DebugMsg("Return: guard still in interior after " + elapsedOffScreen as Int + "s — forcing virtual exit")

            ; FindDoorToActorCell returns the EXTERIOR door leading to the guard's interior cell
            ObjectReference exteriorDoor = SeverActionsNative.FindDoorToActorCell(DispatchGuard)
            If exteriorDoor != None
                DebugMsg("Found exterior door — moving guard+prisoner outside")
                DispatchGuard.MoveTo(exteriorDoor, 0.0, 0.0, 0.0, false)
                If DispatchTarget != None && !DispatchIsHomeInvestigation
                    DispatchTarget.MoveTo(DispatchGuard, 50.0, 0.0, 0.0, false)
                EndIf
                Utility.Wait(0.3)

                ; Re-apply linked ref + packages after cross-cell MoveTo.
                ; Skyrim's AI stack often loses overrides after a cell transition.
                ReapplyReturnPackages()
            Else
                ; Fallback: try interior exit door and nudge toward it
                ObjectReference exitDoor = SeverActionsNative.FindExitDoorFromCell(DispatchGuard)
                If exitDoor != None
                    DebugMsg("No exterior door found — nudging guard to interior exit door")
                    DispatchGuard.MoveTo(exitDoor, 0.0, 0.0, 0.0, false)
                    If DispatchTarget != None && !DispatchIsHomeInvestigation
                        DispatchTarget.MoveTo(DispatchGuard, 50.0, 0.0, 0.0, false)
                    EndIf
                    Utility.Wait(0.3)
                    ReapplyReturnPackages()
                Else
                    DebugMsg("No exit door found in guard's cell — will escalate to teleport")
                EndIf
            EndIf

            ; Mark that we've done the interior exit so we don't repeat it
            DispatchReturnOffScreenCycle = 1

        ; === OFF-SCREEN TRAVEL ESTIMATION ===
        ; Instead of hardcoded timers, use distance-based estimation from OffScreenTracker.
        ; Short trips complete faster, long trips wait proportionally longer.
        ElseIf DispatchReturnOffScreenCycle == 0
            ; First off-screen cycle: check travel estimate
            Int arrivalStatus = SeverActionsNative.OffScreen_CheckArrival(DispatchGuard, Utility.GetCurrentGameTime())
            If arrivalStatus == 1
                DebugMsg("Return: off-screen travel estimate elapsed — teleporting to destination")
                If DispatchReturnMarker != None
                    DispatchGuard.MoveTo(DispatchReturnMarker, 300.0, 0.0, 0.0, false)
                    If DispatchTarget != None && !DispatchIsHomeInvestigation
                        DispatchTarget.MoveTo(DispatchGuard, 50.0, 0.0, 0.0, false)
                    EndIf
                    Utility.Wait(0.5)
                    ReapplyReturnPackages()
                EndIf
                ; Mark cycle 2 so next off-screen check force-completes
                DispatchReturnOffScreenCycle = 2
                DispatchGuardOffScreen = false
                DispatchOffScreenStartTime = 0.0
                DebugMsg("Guard placed near return destination, checking if they load in")
            Else
                ; Still in transit — log progress every ~30s
                If Math.Floor(elapsedOffScreen) as Int % 30 == 0 && Math.Floor(elapsedOffScreen) as Int > 0
                    Float estArrival = SeverActionsNative.OffScreen_GetEstimatedArrival(DispatchGuard)
                    DebugMsg("Return: off-screen " + elapsedOffScreen as Int + "s, est. arrival=" + estArrival + ", current=" + Utility.GetCurrentGameTime())
                EndIf

                ; Safety fallback: if real-time exceeds 5 minutes with no arrival, nudge packages
                If elapsedOffScreen >= 300.0
                    DebugMsg("Return: 5 min real-time off-screen — nudging packages as safety measure")
                    ReapplyReturnPackages()
                    DispatchReturnOffScreenCycle = 1
                EndIf
            EndIf

        ; === FALLBACK: Cycle 1+ — re-check estimate or force complete ===
        Else
            Int arrivalStatus = SeverActionsNative.OffScreen_CheckArrival(DispatchGuard, Utility.GetCurrentGameTime())
            If arrivalStatus == 1 || DispatchReturnOffScreenCycle >= 2
                DebugMsg("Return: force completing dispatch (cycle " + DispatchReturnOffScreenCycle + ")")
                If DispatchReturnMarker != None && DispatchReturnOffScreenCycle < 2
                    DispatchGuard.MoveTo(DispatchReturnMarker, 300.0, 0.0, 0.0, false)
                    If DispatchTarget != None && !DispatchIsHomeInvestigation
                        DispatchTarget.MoveTo(DispatchGuard, 50.0, 0.0, 0.0, false)
                    EndIf
                    Utility.Wait(0.5)
                EndIf
                CompleteDispatch()
                Return
            ElseIf elapsedOffScreen >= 180.0
                ; Safety: if still off-screen 3 min after nudge, teleport and complete
                DebugMsg("Return: extended off-screen after nudge — teleporting and completing")
                If DispatchReturnMarker != None
                    DispatchGuard.MoveTo(DispatchReturnMarker, 300.0, 0.0, 0.0, false)
                    If DispatchTarget != None && !DispatchIsHomeInvestigation
                        DispatchTarget.MoveTo(DispatchGuard, 50.0, 0.0, 0.0, false)
                    EndIf
                    Utility.Wait(0.5)
                EndIf
                CompleteDispatch()
                Return
            EndIf
        EndIf
    EndIf

    RegisterForSingleUpdate(UpdateInterval)
EndFunction

Function CompleteDispatch()
    {Called when dispatch is fully complete - guard delivered prisoner or returned with evidence.}

    DebugMsg("Dispatch complete!")

    ; Stop stuck tracking and off-screen estimation
    SeverActionsNative.Stuck_StopTracking(DispatchGuard)
    SeverActionsNative.OffScreen_StopTracking(DispatchGuard)

    ; Remove task faction so guard can be dispatched again
    If SeverActions_DispatchFaction != None && DispatchGuard != None
        DispatchGuard.RemoveFromFaction(SeverActions_DispatchFaction)
    EndIf

    ; Restore normal NPC-NPC collision
    SeverActionsNative.SetActorBumpable(DispatchGuard, true)
    If DispatchTarget != None
        SeverActionsNative.SetActorBumpable(DispatchTarget, true)
    EndIf

    ; Restore guard combat AI
    RestoreGuardCombatAI()

    ; Restore guard's ability to talk to the player
    If DispatchGuard != None
        DispatchGuard.AllowPCDialogue(true)
    EndIf

    ; Ensure prisoner is near the guard (they should already be close from Phase 5)
    If DispatchGuard != None && DispatchTarget != None
        If DispatchTarget.Is3DLoaded() && DispatchGuard.Is3DLoaded()
            If DispatchTarget.GetDistance(DispatchGuard) > 300.0
                DispatchTarget.MoveTo(DispatchGuard, 50.0, 0.0, 0.0, false)
            EndIf
        EndIf
        Utility.Wait(0.3)
    EndIf

    ; Remove all possible travel/escort packages and clear linked ref
    If SeverActions_GuardEscortPackage
        ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_GuardEscortPackage)
    EndIf
    If SeverActions_DispatchTravel
        ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchTravel)
    EndIf
    If SeverActions_GuardApproachTarget
        ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_GuardApproachTarget)
    EndIf
    If SeverActions_DispatchJog
        ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchJog)
    EndIf
    If SeverActions_DispatchWalk
        ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchWalk)
    EndIf
    If DispatchTravelDestination != None
        DispatchTravelDestination.Clear()
    EndIf
    ClearAllDispatchLinkedRefs(DispatchGuard)

    ; Remove prisoner's follow package
    If DispatchTarget != None && !DispatchIsHomeInvestigation
        If SeverActions_FollowGuard_Prisoner
            ActorUtil.RemovePackageOverride(DispatchTarget, SeverActions_FollowGuard_Prisoner)
        EndIf
    EndIf

    ; Handle completion based on dispatch type
    If DispatchIsHomeInvestigation
        ; Home investigation complete - guard returned to sender with evidence
        String guardName = DispatchGuard.GetDisplayName()
        String senderName = ""
        If DispatchSender != None
            senderName = DispatchSender.GetDisplayName()
        EndIf
        String targetName = ""
        If DispatchTarget != None
            targetName = DispatchTarget.GetDisplayName()
        EndIf

        ; Wait for player to be close enough to witness evidence handoff (200 units)
        ; If player doesn't arrive within 30 seconds, proceed anyway
        Actor playerRef = Game.GetPlayer()
        Float waitStart = Utility.GetCurrentRealTime()
        Float maxWaitTime = 30.0
        While DispatchGuard.Is3DLoaded() && playerRef.Is3DLoaded() && playerRef.GetDistance(DispatchGuard) > 200.0 && (Utility.GetCurrentRealTime() - waitStart) < maxWaitTime
            Utility.Wait(1.0)
        EndWhile
        Bool playerWitnessed = (playerRef.Is3DLoaded() && DispatchGuard.Is3DLoaded() && playerRef.GetDistance(DispatchGuard) <= 200.0)
        Bool senderIsPlayer = (DispatchSender == playerRef)

        If DispatchEvidenceForm != None
            String itemName = DispatchEvidenceName
            DebugMsg("Guard returned to " + senderName + " with evidence: " + itemName + " (player witnessed: " + playerWitnessed + ")")

            ; Hand the evidence to the sender via GiveItem (walks to them, plays give animation, transfers)
            If DispatchSender != None
                SeverActions_Loot lootSys = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Loot
                If lootSys
                    lootSys.GiveItem_Execute(DispatchGuard, DispatchSender, itemName, 1)
                    DebugMsg("Guard gave evidence to " + senderName + " via GiveItem")
                Else
                    ; Fallback: direct transfer if Loot script unavailable
                    DispatchGuard.RemoveItem(DispatchEvidenceForm, 1, true, DispatchSender)
                    DebugMsg("Transferred evidence item to " + senderName + " (direct fallback)")
                EndIf
            EndIf

            ; Narrate the findings including investigation reason for context
            String reasonContext = ""
            If DispatchInvestigationReason != ""
                reasonContext = " regarding " + DispatchInvestigationReason
            EndIf

            String narration = "*" + guardName + " returns to " + senderName + " and presents the evidence found at " + targetName + "'s home" + reasonContext + ": " + itemName + ". The guard explains where it was found and what it suggests.*"

            ; Immediate narration if player is present, otherwise defer for non-player senders
            If playerWitnessed || senderIsPlayer
                SkyrimNetApi.DirectNarration(narration, DispatchGuard, DispatchSender)
            Else
                ; Player absent and sender is not the player — store for deferred delivery
                StorageUtil.SetIntValue(DispatchSender, "SeverActions_PendingEvidence", 1)
                StorageUtil.SetStringValue(DispatchSender, "SeverActions_PendingEvidenceNarration", narration)
                StorageUtil.SetFormValue(DispatchSender, "SeverActions_PendingEvidenceGuard", DispatchGuard as Form)
                StorageUtil.SetFormValue(Self, "SeverActions_DeferredSender", DispatchSender as Form)
                DeferredNarrationSender = DispatchSender
                DebugMsg("Stored deferred evidence narration on " + senderName)
            EndIf

            String eventMsg = guardName + " returned from searching " + targetName + "'s home" + reasonContext + " and brought back " + itemName + " as evidence."
            SkyrimNetApi.RegisterPersistentEvent(eventMsg, DispatchGuard, DispatchSender)

            Debug.Notification(guardName + " returned with evidence: " + itemName)
        Else
            DebugMsg("Guard returned to " + senderName + " without evidence")

            String reasonContext = ""
            If DispatchInvestigationReason != ""
                reasonContext = " regarding " + DispatchInvestigationReason
            EndIf

            String narration = "*" + guardName + " returns to " + senderName + " after searching " + targetName + "'s home" + reasonContext + ", reporting that nothing incriminating was found.*"

            ; Immediate narration if player is present, otherwise defer for non-player senders
            If playerWitnessed || senderIsPlayer
                SkyrimNetApi.DirectNarration(narration, DispatchGuard, DispatchSender)
            Else
                StorageUtil.SetIntValue(DispatchSender, "SeverActions_PendingEvidence", 1)
                StorageUtil.SetStringValue(DispatchSender, "SeverActions_PendingEvidenceNarration", narration)
                StorageUtil.SetFormValue(DispatchSender, "SeverActions_PendingEvidenceGuard", DispatchGuard as Form)
                StorageUtil.SetFormValue(Self, "SeverActions_DeferredSender", DispatchSender as Form)
                DeferredNarrationSender = DispatchSender
                DebugMsg("Stored deferred no-evidence narration on " + senderName)
            EndIf

            String eventMsg = guardName + " returned from searching " + targetName + "'s home but found no evidence."
            SkyrimNetApi.RegisterPersistentEvent(eventMsg, DispatchGuard, DispatchSender)

            Debug.Notification(guardName + " found no evidence at " + targetName + "'s home")
        EndIf

    ElseIf DispatchSender != None && !DispatchSender.IsDead() && !DispatchIsHomeInvestigation
        ; Returned prisoner to sender for judgment - enter judgment hold phase
        Actor sender = DispatchSender
        Actor prisoner = DispatchTarget
        Actor guard = DispatchGuard
        String senderName = sender.GetDisplayName()
        String prisonerName = ""
        If prisoner != None
            prisonerName = prisoner.GetDisplayName()
        EndIf
        String guardName = guard.GetDisplayName()

        DebugMsg("Guard returned prisoner " + prisonerName + " to " + senderName + " - entering judgment phase")

        ; Narration: guard presents prisoner before the sender
        String narration = "*" + guardName + " brings " + prisonerName + " before " + senderName + " for judgment. The prisoner stands restrained, awaiting their fate.*"
        SkyrimNetApi.DirectNarration(narration, prisoner, sender)

        ; Persistent event: sender now has the prisoner and can decide
        String eventMsg = guardName + " has brought " + prisonerName + " before " + senderName + " for judgment. " + senderName + " can order them released or sent to jail."
        SkyrimNetApi.RegisterPersistentEvent(eventMsg, prisoner, sender)

        Debug.Notification(prisonerName + " awaits judgment from " + senderName)

        ; Transition to judgment hold phase (Phase 6)
        ; Do NOT clear dispatch state - we need guard, prisoner, and sender references
        DispatchPhase = 6
        StorageUtil.SetIntValue(DispatchGuard, "SeverActions_DispatchPhase", DispatchPhase)
        JudgmentStartTime = Utility.GetCurrentRealTime()

        ; Keep guard near sender — link guard to sender and apply follow package
        PO3_SKSEFunctions.SetLinkedRef(guard, sender, SeverActions_FollowTargetKW)
        If SeverActions_GuardFollowPlayer
            ActorUtil.AddPackageOverride(guard, SeverActions_GuardFollowPlayer, PackagePriority, 1)
            guard.EvaluatePackage()
            DebugMsg("Judgment phase: guard following sender " + senderName)
        EndIf

        ; Keep prisoner following the guard during judgment.
        ; Re-apply follow package to ensure prisoner stays near guard.
        If prisoner != None
            PO3_SKSEFunctions.SetLinkedRef(prisoner, guard, SeverActions_FollowTargetKW)
            Utility.Wait(0.1)
            If SeverActions_FollowGuard_Prisoner
                ActorUtil.AddPackageOverride(prisoner, SeverActions_FollowGuard_Prisoner, PackagePriority, 1)
                prisoner.EvaluatePackage()
            EndIf
            DebugMsg("Judgment phase: prisoner following guard")
        EndIf

        ; Keep monitoring for timeout
        RegisterForSingleUpdate(UpdateInterval)
        Return
    ElseIf DispatchReturnMarker != None
        ; Deliver to jail
        CurrentGuard = DispatchGuard
        CurrentPrisoner = DispatchTarget
        CurrentJailMarker = DispatchReturnMarker
        CurrentJailName = GetJailNameForGuard(DispatchGuard)
        OnArrivedAtJail()
    EndIf

    ; Re-lock home door if we unlocked it during investigation
    If DispatchUnlockedDoor != None
        DispatchUnlockedDoor.Lock(true)
        DebugMsg("Re-locked home door after investigation")
        DispatchUnlockedDoor = None
    EndIf

    ; Clear aliases
    DispatchGuardAlias.Clear()
    DispatchTargetAlias.Clear()
    If DispatchPrisonerAlias != None
        DispatchPrisonerAlias.Clear()
    EndIf
    If DispatchTravelDestination != None
        DispatchTravelDestination.Clear()
    EndIf

    ; Clear persisted dispatch state from StorageUtil
    ClearPersistedDispatchState()

    ClearDispatchState()

    ; If guard is lingering or deferred narration is pending, keep OnUpdate running
    If DeferredNarrationSender != None
        RegisterForSingleUpdate(UpdateInterval)
    EndIf
EndFunction

Function CancelDispatch()
    {Cancel an active dispatch and clean up all state.}

    ; Stop stuck tracking, off-screen estimation, restore collision, and restore combat AI
    If DispatchGuard != None
        SeverActionsNative.Stuck_StopTracking(DispatchGuard)
        SeverActionsNative.OffScreen_StopTracking(DispatchGuard)
        SeverActionsNative.SetActorBumpable(DispatchGuard, true)
    EndIf

    ; Remove task faction so guard can be dispatched again
    If SeverActions_DispatchFaction != None && DispatchGuard != None
        DispatchGuard.RemoveFromFaction(SeverActions_DispatchFaction)
    EndIf

    If DispatchTarget != None
        SeverActionsNative.SetActorBumpable(DispatchTarget, true)
    EndIf
    RestoreGuardCombatAI()

    ; Unregister from sandbox manager if in sandbox phase
    If DispatchIsHomeInvestigation && DispatchGuard != None
        SeverActionsNative.UnregisterSandboxUser(DispatchGuard)
    EndIf

    ; Remove all possible dispatch packages and restore dialogue
    If DispatchGuard != None
        DispatchGuard.AllowPCDialogue(true)

        If SeverActions_DispatchTravel
            ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchTravel)
        EndIf
        If SeverActions_GuardApproachTarget
            ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_GuardApproachTarget)
        EndIf
        If SeverActions_GuardEscortPackage
            ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_GuardEscortPackage)
        EndIf
        If SeverActions_PrisonerSandBox
            ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_PrisonerSandBox)
        EndIf
        If SeverActions_DispatchJog
            ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchJog)
        EndIf
        If SeverActions_DispatchWalk
            ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchWalk)
        EndIf
        If DispatchTravelDestination != None
            DispatchTravelDestination.Clear()
        EndIf
        ClearAllDispatchLinkedRefs(DispatchGuard)
        DispatchGuard.EvaluatePackage()
    EndIf

    ; Clean up prisoner if they were arrested during this dispatch (Phase 5 = escorting)
    If !DispatchIsHomeInvestigation && DispatchTarget != None
        If SeverActions_FollowGuard_Prisoner
            ActorUtil.RemovePackageOverride(DispatchTarget, SeverActions_FollowGuard_Prisoner)
        EndIf
        ClearAllDispatchLinkedRefs(DispatchTarget)
        ReleasePrisoner(DispatchTarget)
        DispatchTarget.EvaluatePackage()
    EndIf

    ; Clear aliases
    ArrestTarget.Clear()
    ArrestingGuard.Clear()
    JailDestination.Clear()
    DispatchGuardAlias.Clear()
    DispatchTargetAlias.Clear()
    If DispatchPrisonerAlias != None
        DispatchPrisonerAlias.Clear()
    EndIf
    If DispatchTravelDestination != None
        DispatchTravelDestination.Clear()
    EndIf

    ; Re-lock home door if we unlocked it during investigation
    If DispatchUnlockedDoor != None
        DispatchUnlockedDoor.Lock(true)
        DebugMsg("Re-locked home door after cancelled investigation")
        DispatchUnlockedDoor = None
    EndIf

    ; Clear persisted dispatch state from StorageUtil
    ClearPersistedDispatchState()

    ClearDispatchState()

    DebugMsg("Dispatch canceled")
EndFunction

Actor Function FindNearestGuard(Actor akNearActor)
    {Find the nearest guard near the given actor.
     Searches loaded actors for NPCs in an actual guard faction (NOT crime faction).
     Crime factions include all citizens in a hold, while guard factions are specific to guards.
     Returns None if no guard is found nearby.}

    If akNearActor == None
        Return None
    EndIf

    ; Search nearby NPCs for guards
    Actor nearestGuard = None
    Float nearestDist = 3000.0  ; Max search radius

    ; Use actual guard factions (NOT crime factions which include all citizens)
    Faction[] guardFactions = new Faction[9]
    guardFactions[0] = GuardFactionWhiterun
    guardFactions[1] = GuardFactionRiften
    guardFactions[2] = GuardFactionSolitude
    guardFactions[3] = GuardFactionHaafingar
    guardFactions[4] = GuardFactionWindhelm
    guardFactions[5] = GuardFactionMarkarth
    guardFactions[6] = GuardFactionFalkreath
    guardFactions[7] = GuardFactionDawnstar
    guardFactions[8] = GuardFactionWinterhold

    ; Search the cell the given actor is in
    Cell currentCell = akNearActor.GetParentCell()

    If currentCell == None
        Return None
    EndIf

    ; Search references in the current cell for guards
    Int numRefs = currentCell.GetNumRefs(43)  ; 43 = kNPC type
    Int i = 0
    While i < numRefs
        ObjectReference ref = currentCell.GetNthRef(i, 43)
        Actor candidate = ref as Actor
        If candidate != None && candidate != akNearActor && !candidate.IsDead() && !candidate.IsInCombat()
            ; Check if this NPC is in any guard faction (actual guards only)
            Int fIdx = 0
            While fIdx < guardFactions.Length
                If guardFactions[fIdx] != None && candidate.IsInFaction(guardFactions[fIdx])
                    Float dist = akNearActor.GetDistance(candidate)
                    If dist < nearestDist
                        nearestDist = dist
                        nearestGuard = candidate
                    EndIf
                    fIdx = guardFactions.Length  ; Break inner loop
                EndIf
                fIdx += 1
            EndWhile
        EndIf
        i += 1
    EndWhile

    If nearestGuard != None
        DebugMsg("Found nearest guard: " + nearestGuard.GetDisplayName() + " at distance " + nearestDist)
    Else
        DebugMsg("No guard found near " + akNearActor.GetDisplayName())
    EndIf

    Return nearestGuard
EndFunction

String Function GetNPCLocation(String npcName)
    {Get the current location name of an NPC by name.
     Utility function for SkyrimNet prompts/decorators.}

    If !SeverActionsNative.IsActorFinderReady()
        Return "unknown"
    EndIf

    Actor npc = SeverActionsNative.FindActorByName(npcName)
    If npc == None
        Return "not found"
    EndIf

    Return SeverActionsNative.GetActorLocationName(npc)
EndFunction

; =============================================================================
; JUDGMENT HOLD - Sender decides prisoner's fate (Phase 6)
; After a guard brings a prisoner back to the sender, the sender can:
;   - OrderRelease: free the prisoner (uncuff, restore, back to normal)
;   - OrderJailed: send the prisoner to jail (guard starts standard escort)
; If neither fires within JudgmentTimeLimit, defaults to jail.
; =============================================================================

Function CheckJudgmentProgress()
    {Check if judgment hold has timed out or participants became invalid.
     Called from CheckDispatchProgress when DispatchPhase == 6.}

    ; Validate participants
    If DispatchGuard == None || DispatchGuard.IsDead()
        DebugMsg("Judgment: Guard died or invalid, releasing prisoner")
        EndJudgment(true)
        Return
    EndIf

    If DispatchTarget == None || DispatchTarget.IsDead()
        DebugMsg("Judgment: Prisoner died or invalid, ending judgment")
        EndJudgment(false)
        Return
    EndIf

    If DispatchSender == None || DispatchSender.IsDead()
        DebugMsg("Judgment: Sender died or invalid, defaulting to jail")
        EndJudgment(false)
        Return
    EndIf

    ; Check timeout
    Float elapsed = Utility.GetCurrentRealTime() - JudgmentStartTime
    If elapsed >= JudgmentTimeLimit
        DebugMsg("Judgment timed out after " + elapsed + "s - defaulting to jail")

        String senderName = DispatchSender.GetDisplayName()
        String prisonerName = DispatchTarget.GetDisplayName()
        String guardName = DispatchGuard.GetDisplayName()

        String narration = "*" + senderName + " grows tired of deliberating. " + guardName + " takes hold of " + prisonerName + " and begins leading them away to jail.*"
        SkyrimNetApi.DirectNarration(narration, DispatchTarget, DispatchSender)

        String eventMsg = senderName + " did not reach a decision. " + prisonerName + " will be taken to jail by default."
        SkyrimNetApi.RegisterPersistentEvent(eventMsg, DispatchTarget, DispatchSender)

        Debug.Notification(senderName + " lost patience - " + prisonerName + " sent to jail")

        EndJudgment(false)
        Return
    EndIf

    ; Re-apply prisoner follow package each tick — Skyrim's AI can drop overrides
    If DispatchTarget != None && DispatchGuard != None && SeverActions_FollowGuard_Prisoner
        ActorUtil.AddPackageOverride(DispatchTarget, SeverActions_FollowGuard_Prisoner, PackagePriority, 1)
        DispatchTarget.EvaluatePackage()
    EndIf

    ; Still waiting for sender's decision
    RegisterForSingleUpdate(UpdateInterval)
EndFunction

Bool Function OrderRelease_Execute(Actor akSender)
    {Sender orders the prisoner released. Called by SkyrimNet when the sender
     decides to show mercy or accepts the prisoner's plea.
     akSender: The NPC giving the release order (must be the dispatch sender, or the guard if sender is player)
     Returns true if the prisoner was released.}

    If DispatchPhase != 6
        DebugMsg("ERROR: OrderRelease called but not in judgment phase (phase " + DispatchPhase + ")")
        Return false
    EndIf

    If akSender == None
        DebugMsg("ERROR: OrderRelease called with None sender")
        Return false
    EndIf

    ; If the player is the dispatch sender, accept the guard as the caller acting on the player's behalf
    Bool validCaller = (akSender == DispatchSender)
    If !validCaller && DispatchSender == Game.GetPlayer() && akSender == DispatchGuard
        validCaller = true
        DebugMsg("OrderRelease: Guard " + akSender.GetDisplayName() + " acting on player's behalf")
    EndIf

    If !validCaller
        DebugMsg("ERROR: OrderRelease called by wrong sender (" + akSender.GetDisplayName() + " vs " + DispatchSender.GetDisplayName() + ")")
        Return false
    EndIf

    If DispatchTarget == None || DispatchGuard == None
        DebugMsg("ERROR: OrderRelease - invalid state")
        EndJudgment(true)
        Return false
    EndIf

    String senderName = DispatchSender.GetDisplayName()
    String prisonerName = DispatchTarget.GetDisplayName()
    String guardName = DispatchGuard.GetDisplayName()

    DebugMsg(senderName + " ordered release of " + prisonerName)

    ; Narration: sender orders the guard to release the prisoner
    String narration = "*" + senderName + " raises a hand, halting " + guardName + ". " + prisonerName + " is released from restraints.*"
    SkyrimNetApi.DirectNarration(narration, DispatchTarget, DispatchSender)

    ; Persistent event
    String eventMsg = senderName + " ordered " + prisonerName + " released."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, DispatchTarget, DispatchSender)

    Debug.Notification(prisonerName + " has been released")

    EndJudgment(true)
    Return true
EndFunction

Bool Function OrderJailed_Execute(Actor akSender)
    {Sender orders the prisoner taken to jail. Called by SkyrimNet when the sender
     decides the prisoner deserves imprisonment.
     akSender: The NPC giving the jail order (must be the dispatch sender, or the guard if sender is player)
     Returns true if the prisoner was sent to jail.}

    If DispatchPhase != 6
        DebugMsg("ERROR: OrderJailed called but not in judgment phase (phase " + DispatchPhase + ")")
        Return false
    EndIf

    If akSender == None
        DebugMsg("ERROR: OrderJailed called with None sender")
        Return false
    EndIf

    ; If the player is the dispatch sender, accept the guard as the caller acting on the player's behalf
    Bool validCaller = (akSender == DispatchSender)
    If !validCaller && DispatchSender == Game.GetPlayer() && akSender == DispatchGuard
        validCaller = true
        DebugMsg("OrderJailed: Guard " + akSender.GetDisplayName() + " acting on player's behalf")
    EndIf

    If !validCaller
        DebugMsg("ERROR: OrderJailed called by wrong sender (" + akSender.GetDisplayName() + " vs " + DispatchSender.GetDisplayName() + ")")
        Return false
    EndIf

    If DispatchTarget == None || DispatchGuard == None
        DebugMsg("ERROR: OrderJailed - invalid state")
        EndJudgment(false)
        Return false
    EndIf

    String senderName = DispatchSender.GetDisplayName()
    String prisonerName = DispatchTarget.GetDisplayName()
    String guardName = DispatchGuard.GetDisplayName()

    DebugMsg(senderName + " ordered " + prisonerName + " taken to jail")

    ; Narration: sender orders the guard to take the prisoner away
    String narration = "*" + senderName + " shakes their head. " + guardName + " tightens their grip on " + prisonerName + " and begins leading them away.*"
    SkyrimNetApi.DirectNarration(narration, DispatchTarget, DispatchSender)

    ; Persistent event
    String eventMsg = senderName + " ordered " + prisonerName + " taken to jail."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, DispatchTarget, DispatchSender)

    Debug.Notification(prisonerName + " will be taken to jail")

    EndJudgment(false)
    Return true
EndFunction

Function EndJudgment(Bool released)
    {End the judgment hold and either release the prisoner or escort them to jail.
     released: true = free the prisoner, false = escort to jail.
     Cleans up dispatch state either way.}

    Actor prisoner = DispatchTarget
    Actor guard = DispatchGuard

    If released
        ; --- RELEASE: Undo all restraint and clean up ---
        DebugMsg("Judgment ended: releasing " + prisoner.GetDisplayName())

        ; Remove guard packages
        If guard != None
            If SeverActions_GuardApproachTarget
                ActorUtil.RemovePackageOverride(guard, SeverActions_GuardApproachTarget)
            EndIf
            If SeverActions_GuardEscortPackage
                ActorUtil.RemovePackageOverride(guard, SeverActions_GuardEscortPackage)
            EndIf
            If SeverActions_DispatchTravel
                ActorUtil.RemovePackageOverride(guard, SeverActions_DispatchTravel)
            EndIf
            If SeverActions_GuardFollowPlayer
                ActorUtil.RemovePackageOverride(guard, SeverActions_GuardFollowPlayer)
            EndIf
            ClearAllDispatchLinkedRefs(guard)
            guard.AllowPCDialogue(true)
            guard.EvaluatePackage()
        EndIf

        ; Release the prisoner (removes factions, cuffs, linked ref, restores AVs)
        If prisoner != None
            ReleasePrisoner(prisoner)
        EndIf

        ; Clear aliases
        ArrestTarget.Clear()
        ArrestingGuard.Clear()
        JailDestination.Clear()
        If DispatchPrisonerAlias != None
            DispatchPrisonerAlias.Clear()
        EndIf
        If DispatchTravelDestination != None
            DispatchTravelDestination.Clear()
        EndIf

        ClearDispatchState()
    Else
        ; --- JAIL: Hand off to standard escort pipeline ---
        DebugMsg("Judgment ended: sending " + prisoner.GetDisplayName() + " to jail")

        ; Remove approach and follow packages (used during return to sender and judgment)
        If guard != None
            If SeverActions_GuardApproachTarget
                ActorUtil.RemovePackageOverride(guard, SeverActions_GuardApproachTarget)
            EndIf
            If SeverActions_GuardFollowPlayer
                ActorUtil.RemovePackageOverride(guard, SeverActions_GuardFollowPlayer)
            EndIf
            PO3_SKSEFunctions.SetLinkedRef(guard, None, SeverActions_FollowTargetKW)
        EndIf

        ; Determine jail destination
        ObjectReference jailMarker = GetJailMarkerForGuard(guard)
        String jailName = GetJailNameForGuard(guard)

        If jailMarker != None && guard != None && prisoner != None
            ; Set up standard arrest state for escort
            CurrentGuard = guard
            CurrentPrisoner = prisoner
            CurrentJailMarker = jailMarker
            CurrentJailName = jailName

            ClearDispatchState()

            ; Clear aliases before escort re-fills them
            ArrestTarget.Clear()
            ArrestingGuard.Clear()
            JailDestination.Clear()
            If DispatchPrisonerAlias != None
                DispatchPrisonerAlias.Clear()
            EndIf
            If DispatchTravelDestination != None
                DispatchTravelDestination.Clear()
            EndIf

            ; Apply/re-apply restraints for jail escort
            If prisoner != None
                ; Equip cuffs (add if not already in inventory)
                If SeverActions_PrisonerCuffs
                    If !prisoner.GetItemCount(SeverActions_PrisonerCuffs)
                        prisoner.AddItem(SeverActions_PrisonerCuffs, 1, true)
                    EndIf
                    prisoner.EquipItem(SeverActions_PrisonerCuffs, true, true)
                EndIf

                ; Play bound idle
                If OffsetBoundStandingStart
                    prisoner.PlayIdle(OffsetBoundStandingStart)
                EndIf

                ; Break animation lock so follow package works
                Debug.SendAnimationEvent(prisoner, "IdleForceDefaultState")
                Utility.Wait(0.1)

                ; Ensure prisoner is following the guard for escort
                PO3_SKSEFunctions.SetLinkedRef(prisoner, guard, SeverActions_FollowTargetKW)
                Utility.Wait(0.2)
                If SeverActions_FollowGuard_Prisoner
                    ActorUtil.AddPackageOverride(prisoner, SeverActions_FollowGuard_Prisoner, PackagePriority, 1)
                    prisoner.EvaluatePackage()
                EndIf
            EndIf

            ; Start standard escort phase
            StartEscortPhase()
        Else
            ; Fallback: release if we can't find jail
            DebugMsg("ERROR: Could not determine jail for guard, releasing prisoner")
            If prisoner != None
                ReleasePrisoner(prisoner)
            EndIf
            If guard != None
                guard.AllowPCDialogue(true)
                If SeverActions_GuardApproachTarget
                    ActorUtil.RemovePackageOverride(guard, SeverActions_GuardApproachTarget)
                EndIf
                guard.EvaluatePackage()
            EndIf

            ; Clear aliases
            ArrestTarget.Clear()
            ArrestingGuard.Clear()
            JailDestination.Clear()
            If DispatchPrisonerAlias != None
                DispatchPrisonerAlias.Clear()
            EndIf
            If DispatchTravelDestination != None
                DispatchTravelDestination.Clear()
            EndIf

            ClearDispatchState()
        EndIf
    EndIf
EndFunction

; =============================================================================
; SAVE/LOAD DISPATCH RECOVERY
; =============================================================================

Function PersistDispatchState()
    {Save dispatch state to StorageUtil for recovery after save/load.
     Called at dispatch start and at each phase transition.}
    If DispatchGuard == None
        Return
    EndIf
    StorageUtil.SetIntValue(DispatchGuard, "SeverActions_DispatchPhase", DispatchPhase)
    StorageUtil.SetFormValue(DispatchGuard, "SeverActions_DispatchTarget", DispatchTarget)
    StorageUtil.SetFormValue(DispatchGuard, "SeverActions_DispatchReturnMarker", DispatchReturnMarker)
    StorageUtil.SetFormValue(DispatchGuard, "SeverActions_DispatchSender", DispatchSender)
    StorageUtil.SetIntValue(DispatchGuard, "SeverActions_DispatchIsHome", DispatchIsHomeInvestigation as Int)
    StorageUtil.SetStringValue(DispatchGuard, "SeverActions_DispatchReason", DispatchInvestigationReason)
    StorageUtil.SetFormValue(DispatchGuard, "SeverActions_DispatchHomeMarker", DispatchHomeMarker)
    StorageUtil.SetFloatValue(DispatchGuard, "SeverActions_DispatchOrigAggro", DispatchGuardOrigAggression)
    StorageUtil.SetFloatValue(DispatchGuard, "SeverActions_DispatchOrigConf", DispatchGuardOrigConfidence)
    ; Store guard FormID on quest too, so OnPlayerLoadGame can find the guard
    StorageUtil.SetFormValue(Self as Form, "SeverActions_ActiveDispatchGuard", DispatchGuard)
    DebugMsg("Persisted dispatch state for save/load recovery")
EndFunction

Function ClearPersistedDispatchState()
    {Remove StorageUtil keys after dispatch ends.}
    If DispatchGuard != None
        StorageUtil.UnsetIntValue(DispatchGuard, "SeverActions_DispatchPhase")
        StorageUtil.UnsetFormValue(DispatchGuard, "SeverActions_DispatchTarget")
        StorageUtil.UnsetFormValue(DispatchGuard, "SeverActions_DispatchReturnMarker")
        StorageUtil.UnsetFormValue(DispatchGuard, "SeverActions_DispatchSender")
        StorageUtil.UnsetIntValue(DispatchGuard, "SeverActions_DispatchIsHome")
        StorageUtil.UnsetStringValue(DispatchGuard, "SeverActions_DispatchReason")
        StorageUtil.UnsetFormValue(DispatchGuard, "SeverActions_DispatchHomeMarker")
        StorageUtil.UnsetFloatValue(DispatchGuard, "SeverActions_DispatchOrigAggro")
        StorageUtil.UnsetFloatValue(DispatchGuard, "SeverActions_DispatchOrigConf")
    EndIf
    StorageUtil.UnsetFormValue(Self as Form, "SeverActions_ActiveDispatchGuard")
EndFunction

Function RecoverActiveDispatch()
    {Rebuild dispatch state from StorageUtil after a save/load.
     Script variables persist in saves, but package overrides and aliases are lost.
     This re-applies packages and aliases based on the persisted phase.}

    ; Find the active dispatch guard (stored on quest form)
    Actor guard = StorageUtil.GetFormValue(Self as Form, "SeverActions_ActiveDispatchGuard") as Actor
    If guard == None
        Return  ; No active dispatch
    EndIf

    Int phase = StorageUtil.GetIntValue(guard, "SeverActions_DispatchPhase", 0)
    If phase <= 0
        ; Stale data — clean up
        ClearPersistedDispatchState()
        Return
    EndIf

    ; Verify guard is alive
    If guard.IsDead()
        DebugMsg("Save/load recovery: dispatch guard is dead, canceling")
        ClearPersistedDispatchState()
        ClearDispatchState()
        Return
    EndIf

    DebugMsg("Save/load recovery: rebuilding dispatch Phase " + phase)

    ; Rebuild script state from StorageUtil
    DispatchGuard = guard
    DispatchTarget = StorageUtil.GetFormValue(guard, "SeverActions_DispatchTarget") as Actor
    DispatchReturnMarker = StorageUtil.GetFormValue(guard, "SeverActions_DispatchReturnMarker") as ObjectReference
    DispatchSender = StorageUtil.GetFormValue(guard, "SeverActions_DispatchSender") as Actor
    DispatchIsHomeInvestigation = StorageUtil.GetIntValue(guard, "SeverActions_DispatchIsHome", 0) as Bool
    DispatchInvestigationReason = StorageUtil.GetStringValue(guard, "SeverActions_DispatchReason", "")
    DispatchHomeMarker = StorageUtil.GetFormValue(guard, "SeverActions_DispatchHomeMarker") as ObjectReference
    DispatchGuardOrigAggression = StorageUtil.GetFloatValue(guard, "SeverActions_DispatchOrigAggro", 0.0)
    DispatchGuardOrigConfidence = StorageUtil.GetFloatValue(guard, "SeverActions_DispatchOrigConf", 0.0)
    DispatchPhase = phase

    ; Re-fill dedicated aliases
    DispatchGuardAlias.ForceRefTo(guard)

    ; Re-apply task faction
    If SeverActions_DispatchFaction != None
        guard.AddToFaction(SeverActions_DispatchFaction)
        guard.SetFactionRank(SeverActions_DispatchFaction, 0)
    EndIf

    ; Re-suppress combat AI
    guard.SetAV("Aggression", 0)
    guard.SetAV("Confidence", 0)
    guard.AllowPCDialogue(false)
    SeverActionsNative.SetActorBumpable(guard, false)

    ; Re-start stuck tracking
    SeverActionsNative.Stuck_StartTracking(guard)

    ; Phase-specific package rebuild
    If phase == 1
        ; Traveling to target/home — re-apply jog package
        If DispatchIsHomeInvestigation && DispatchHomeMarker != None
            DispatchTargetAlias.ForceRefTo(DispatchHomeMarker)
        ElseIf DispatchTarget != None
            DispatchTargetAlias.ForceRefTo(DispatchTarget)
        EndIf
        If SeverActions_DispatchJog
            ActorUtil.AddPackageOverride(guard, SeverActions_DispatchJog, PackagePriority, 1)
            guard.EvaluatePackage()
        EndIf
        ; Re-init off-screen estimation
        ObjectReference dest = DispatchTargetAlias.GetReference()
        If dest != None
            SeverActionsNative.OffScreen_InitTracking(guard, dest, 0.5, 18.0)
        EndIf

    ElseIf phase == 2
        ; Approaching target for arrest — same as Phase 1 outbound
        If DispatchTarget != None
            DispatchTargetAlias.ForceRefTo(DispatchTarget)
        EndIf
        If SeverActions_DispatchJog
            ActorUtil.AddPackageOverride(guard, SeverActions_DispatchJog, PackagePriority, 1)
            guard.EvaluatePackage()
        EndIf

    ElseIf phase == 3 || phase == 4
        ; Investigating home / collecting evidence
        ; Simplified: restart Phase 1 travel to home (guard will re-arrive and re-trigger)
        If DispatchHomeMarker != None
            DispatchTargetAlias.ForceRefTo(DispatchHomeMarker)
            If SeverActions_DispatchJog
                ActorUtil.AddPackageOverride(guard, SeverActions_DispatchJog, PackagePriority, 1)
                guard.EvaluatePackage()
            EndIf
            DispatchPhase = 1
            StorageUtil.SetIntValue(guard, "SeverActions_DispatchPhase", 1)
        EndIf

    ElseIf phase == 5
        ; Returning with prisoner/evidence — re-apply walk package + prisoner follow
        If DispatchReturnMarker != None
            DispatchTargetAlias.ForceRefTo(DispatchReturnMarker)
        EndIf
        If SeverActions_DispatchWalk
            ActorUtil.AddPackageOverride(guard, SeverActions_DispatchWalk, PackagePriority, 1)
            guard.EvaluatePackage()
        EndIf
        ; Re-apply prisoner follow if arrest dispatch
        If DispatchTarget != None && !DispatchIsHomeInvestigation
            DispatchPrisonerAlias.ForceRefTo(DispatchTarget)
            SeverActionsNative.SetActorBumpable(DispatchTarget, false)
            PO3_SKSEFunctions.SetLinkedRef(DispatchTarget, guard, SeverActions_FollowTargetKW)
            If SeverActions_FollowGuard_Prisoner
                ActorUtil.AddPackageOverride(DispatchTarget, SeverActions_FollowGuard_Prisoner, PackagePriority, 1)
                DispatchTarget.EvaluatePackage()
            EndIf
        EndIf
        ; Re-init off-screen estimation for return
        If DispatchReturnMarker != None
            SeverActionsNative.OffScreen_InitTracking(guard, DispatchReturnMarker, 0.25, 12.0)
        EndIf

    ElseIf phase == 6
        ; Judgment hold — just restart update timer, phase logic handles the rest
        JudgmentStartTime = Utility.GetCurrentRealTime()
    EndIf

    ; Resume update loop
    RegisterForSingleUpdate(UpdateInterval)
    DebugMsg("Save/load recovery complete — resumed at Phase " + DispatchPhase)
EndFunction

