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

; Guard factions now owned by native GuardFinder — see Native/src/GuardFinder.h.

; =============================================================================
; PROPERTIES - Keywords & Packages (Create in CK)
; =============================================================================

Keyword Property SeverActions_FollowTargetKW Auto
{Keyword for follow packages — prisoner follows guard, guard follows sender in judgment.}

Keyword Property SeverActions_SandboxAnchorKW Auto
{Keyword for sandbox packages — prisoner sandboxes near jail marker, guard sandboxes at home.}

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

SeverActions_ArrestBounty Property BountyScript Auto
{Reference to the tracked-bounty subsystem (Wave 5b extraction). Holds the
 9 bounty CRUD functions plus the AddBountyToPlayer action entry point.
 Filled at runtime in Maintenance() via `quest as SeverActions_ArrestBounty`
 if CK didn't fill it. Same quest as the rest of the SeverActions sub-scripts.}

SeverActions_ArrestJudgment Property JudgmentScript Auto
{Reference to the Phase-6 judgment subsystem (Wave 5b extraction). Holds the
 OrderRelease/OrderJailed action entry points, EndJudgment cleanup, and the
 per-tick CheckJudgmentProgress router target. Filled at runtime in
 Maintenance() if CK didn't fill it.}

SeverActions_ArrestPlayer Property PlayerScript Auto
{Reference to the player-confrontation + persuasion FSM (Wave 5b extraction).
 Holds ArrestPlayer_Internal / AcceptPersuasion_Internal / RejectPersuasion_Internal
 action entry points, the full HandlePayFine/Submit/Resist/Bribe/Persuade
 menu router, the per-tick persuasion timer, and post-resist combat cleanup.
 Drives its own OnUpdate independently of arrest.psc's update loop. Filled at
 runtime in Maintenance() if CK didn't fill it.}

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

Float Property ApproachPostFreezeGracePeriod = 5.0 Auto
{Wave 6 polish: Real-time seconds the guard gets to walk in naturally AFTER the
 prisoner-freeze threshold triggers, before the script falls back to a teleport
 snap. If the guard reaches ApproachDistance within this window the arrest
 fires on the natural walk-in (no teleport, smooth visual). If the engine
 stalls (path stutter, package distance setting, slope), the snap kicks in as
 a guarantee. Set to 0.0 to keep the old "snap immediately on freeze" behavior.}

Float Property EscortPleaTimeLimit = 60.0 Auto
{Wave 6.1: Real-time seconds an NPC prisoner has to make their case during a
 mid-escort plea before the guard runs out of patience and silently resumes
 the escort to jail. Mirrors PersuasionTimeLimit for the player FSM.}

Float Property EscortPleaFollowDistance = 300.0 Auto
{Wave 6.1: Distance threshold for escort plea — if the prisoner walks more
 than this far from the guard during the plea, escort resumes (treated as
 escape attempt; no extra penalty, just the silent resume narration).}

Int Property ResistBountyIncrease = 500 Auto
{Additional bounty added when player resists arrest}

Float Property ArrestPlayerCooldown = 60.0 Auto
{Cooldown in seconds before ArrestPlayer can be used again after a confrontation starts}

Float Property ApproachTimeout = 30.0 Auto
{Real-time seconds the guard has to reach the prisoner before we force-teleport
 and proceed with the arrest. Without this, an NPC running their own AI package
 can keep distance oscillating around ApproachDistance forever.}

Float Property EscortTimeout = 600.0 Auto
{DEPRECATED in Phase 2.3b. Real-time seconds the escort could take before we
 used to force-teleport the pair to jail. Superseded by the kEscort
 ArrestSessionStore watchdog (6 game-hours, defined in ArrestSessionStore.h
 TimeoutForState). Property kept declared so existing MCM saves don't lose
 their VMAD binding, but the value is no longer read.}

Float Property ApproachFreezeDistance = 350.0 Auto
{Once the guard is within this distance, freeze the prisoner's movement
 (SetDontMove) so the closing distance can actually drop below ApproachDistance.
 Released when the arrest performs.}

Package Property SeverActions_GuardFollowPlayer Auto
{Follow package for guard during persuasion - follows linked ref (player).
Setup: Type=Follow, Follow Target=Linked Ref with SeverActions_FollowTargetKW}

; =============================================================================
; PROPERTIES - Tunables (Wave 5)
; Named replacements for the magic numbers that were sprinkled throughout the
; FSM. Each was previously hardcoded at multiple sites; centralizing them
; here means a single edit reaches every callsite, and an MCM slider could
; eventually expose them to the user. Defaults match the prior hardcoded
; values, so behavior is preserved unchanged.
; =============================================================================

Float Property NarrationProximityRange = 300.0 Auto
{Range within which the player will trigger a deferred narration sender's
 stored line. Used by OnUpdate's deferred-narration loop and several Phase 5
 return-arrival proximity checks.}

Float Property GuardArrivalThreshold = 200.0 Auto
{Distance below which a Phase 5 return is considered "guard arrived at sender"
 for narration / re-application purposes. Smaller than ArrivalDistance because
 the return marker is a person/NPC, not a stationary jail marker.}

Float Property JailMarkerVerifyDistance = 500.0 Auto
{Tolerance for "did the prisoner actually land at the jail marker?" check
 in OnArrivedAtJail and VerifyJailedNPCs. Above this distance we trigger the
 retry path or detect the prisoner has wandered out of jail.}

Float Property DispatchSpamCooldown = 15.0 Auto
{Real-time seconds between consecutive dispatch issues. Prevents the LLM
 from spam-issuing dispatches in rapid succession.}

Float Property OffScreenMinimumTravelTime = 120.0 Auto
{Minimum real-time seconds an off-screen dispatch must "appear to travel"
 before we let it complete via time-skip / snapshot arrival. Prevents
 instant cross-map arrests that feel jarring.}

Float Property GuardJogSpeed = 300.0 Auto
{Approximate units-per-second a jogging guard covers. Used by off-screen ETA
 calculations in CheckDispatchPhase1_Travel and CheckDispatchPhase5_Return.}

Float Property GuardJogPerGameHour = 20000.0 Auto
{Approximate units a jogging guard covers per in-game hour. Used by the
 cross-cell time-skip teleport calculation when both actors are off-screen.}

; =============================================================================
; STATE TRACKING
; =============================================================================

; Active arrest tracking (supports one arrest at a time for simplicity)
Actor CurrentGuard
Actor CurrentPrisoner
ObjectReference CurrentJailMarker
String CurrentJailName
Int ArrestState ; 0=none, 1=approaching, 2=arresting, 3=escorting, 4=escort plea (NPC pleading mid-march), 5=arrived (transient, OnArrivedAtJail in progress)

; Wave 6.1: Escort-plea state. Set when an NPC prisoner triggers
; AppealDuringEscort_Internal during ArrestState 3. Cleared when state
; transitions back to 3 (resume) or arrest ends. EscortPleaAttempted is the
; per-arrest single-attempt gate (mirrors PersuadeAttempted on PlayerScript).
Float EscortPleaStartTime
Bool EscortPleaAttempted

; Jailed NPC tracking — kept as a Papyrus array ONLY for one-shot migration of
; pre-PR-B saves. New writes go straight to the native JailedNPCStore cosave
; singleton ('JAIL' record). On the first OnPlayerLoadGame after update, any
; pre-existing entries here get migrated to native and this array is emptied.
Actor[] JailedNPCs

; Player arrest state tracking
; Wave 5b: ConfrontingGuard / ConfrontingFaction / ConfrontingBounty /
; PersuadeAttempted / PaymentFailed / InPersuasionMode / PersuasionStartTime
; moved to SeverActions_ArrestPlayer.psc.
; Wave 5b: LastArrestTime + ResistArrestFaction moved to SeverActions_ArrestPlayer.psc.
Float LastDispatchSpamTime      ; Real time when last dispatch was issued (15s anti-spam guard)

; Wave 1 timeout / freeze tracking
Float ApproachStartTime         ; Real time when current same-cell approach phase started (for timeout)
Float EscortStartTime           ; DEPRECATED in Phase 2.3b — escort timeout owned by kEscort ArrestSessionStore watchdog now. Still written by StartEscortPhase + PersistArrestState (and read by RestoreArrestState) for VMAD save stability, but no live consumer reads it for elapsed-time math.
Float DispatchPhase2StartTime   ; Real time when dispatch transitioned to Phase 2 (post-travel approach)
Bool PrisonerMovementFrozen     ; Track whether SetDontMove is currently held on CurrentPrisoner
Float PrisonerFrozenAt          ; Real time when SetDontMove fired (drives the post-freeze grace period before fallback teleport snap)
Bool DispatchTargetMovementFrozen ; Track whether SetDontMove is currently held on DispatchTarget during Phase 2

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

; Wave 5b: Phase-6 judgment state (JudgmentStartTime + JudgmentTimeLimit) moved
; to SeverActions_ArrestJudgment.psc. Lifecycle is driven through
; JudgmentScript.StartJudgment / ResetState / CheckJudgmentProgress.

; Home investigation state (DispatchGuardToHome)
Bool DispatchIsHomeInvestigation        ; True if this is a home investigation (not an arrest dispatch)
ObjectReference DispatchHomeMarker      ; The NPC's home destination (interior marker if found, exterior door fallback)
Actor DispatchSender                    ; Who sent the guard (for return destination)
String DispatchInvestigationReason      ; Why the investigation was ordered (e.g. "dibella worship", "thieving") - used for evidence generation
Float DispatchSandboxStartTime          ; Real time when sandbox investigation started
Float DispatchSandboxDuration           ; How long to sandbox at home (seconds, randomized 15-30)
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

; Container search state (Phase 3 rewrite — sequential container search)
Int DispatchContainerCount = 0             ; Number of containers to search
Int DispatchCurrentContainer = 0           ; Index of container currently being searched
ObjectReference DispatchCurrentContainerRef = None  ; Current container ref the guard is walking to / searching
Float DispatchContainerSearchStart = 0.0   ; Real time when current container search started
Float DispatchContainerSearchDuration = 0.0 ; How long to search current container (8-12s)
Int DispatchSearchSubPhase = 0             ; 0=walking to container, 1=searching, 2=stepping back
Int DispatchEvidenceContainerIndex = -1    ; Which container has the evidence (-1 = not yet determined)
Bool DispatchPlayerPlantedFound = false    ; True if Pass 1 detected player-planted evidence

; Multi-evidence tracking
Form DispatchEvidenceForm2 = None          ; Second evidence item (rare tier)
String DispatchEvidenceName2 = ""          ; Display name of second evidence
Form DispatchEvidenceForm3 = None          ; Third evidence item (damning tier)
String DispatchEvidenceName3 = ""          ; Display name of third evidence
Int DispatchEvidenceQualityScore = 0       ; Total quality score
Int DispatchContainersSearched = 0         ; Total containers actually searched
String Property DispatchEvidenceSummary = "" Auto  ; Human-readable summary for prompt templates

; Trespass suppression state
Actor DispatchHomeOwner = None             ; The NPC who lives here (= DispatchTarget)
Int DispatchOrigRelRankGuard = 0           ; Original relationship rank guard->owner
Int DispatchOrigRelRankPlayer = 0          ; Original relationship rank player->owner
Bool DispatchRelRankModified = false       ; Whether we modified relationship ranks (guard branch — gates RestoreTrespass entry)
Bool DispatchPlayerRelRankModified = false ; Whether we modified the PLAYER's relationship rank (only true if player was 3D-loaded at SuppressTrespass time)

; Deferred narration state (narration stored on sender when player not present)
Actor DeferredNarrationSender = None


; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    Debug.Trace("[SeverActions_Arrest] Initialized")
    Maintenance()
    ResetSessionCooldowns()
EndEvent

Function ResetSessionCooldowns()
    {Reset real-time cooldowns. Utility.GetCurrentRealTime() resets to 0 on
     fresh game launch, but the saved values persist across sessions and would
     otherwise produce phantom cooldowns (e.g. "5 minutes remaining" right after
     loading a save). Called only from OnInit and OnPlayerLoadGame so that
     Maintenance() — invoked mid-session by payment handlers — can't bypass them.}
    ; Wave 5b: LastArrestTime moved to PlayerScript along with the player FSM.
    If PlayerScript
        PlayerScript.ResetCooldowns()
    EndIf
    LastDispatchSpamTime = 0.0
EndFunction

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

    ; Guard factions are resolved natively by GuardFinder at kDataLoaded
    ; (see Native/src/GuardFinder.h). No Papyrus property fills required.

    ; Cooldowns are reset only at OnInit + OnPlayerLoadGame via ResetSessionCooldowns(),
    ; not here — Maintenance() is also called mid-session by payment handlers to
    ; refresh Gold001, and we don't want those calls to wipe the dispatch-spam window.

    ; Register for game load event to verify prisoner positions
    RegisterForModEvent("OnPlayerLoadGame", "OnPlayerLoadGame")

    ; Register for player cell change to verify prisoners after fast travel
    RegisterForTrackedStatsEvent()

    ; Register for native SandboxManager cell-change cleanup. Arrest's DispatchGuard
    ; is the only actor registered with SandboxManager (via RegisterSandboxUser in
    ; FallbackSandboxSearch). Follow.psc also listens for this event but gates on
    ; its own IsSandboxing flag and returns early for non-follower actors, so
    ; dual-listener doesn't conflict.
    RegisterForModEvent("SeverActionsNative_SandboxCleanup", "OnNativeSandboxCleanup")

    ; Wave 2 (C.2): listen for OrphanCleanup events. The native scanner fires
    ; this for any actor holding our arrest LinkedRef keywords; we filter by
    ; faction here so legitimately-arrested or in-judgment actors are skipped
    ; while genuinely orphaned ones get their packages and LinkedRefs cleared.
    RegisterForModEvent("SeverActions_OrphanCleanup", "OnOrphanCleanup")

    ; Wave 4: listen for ArrestSessionStore watchdog timeouts. The native side
    ; tracks every active arrest in a cosave-backed singleton and fires this
    ; event when a session has exceeded its per-state in-game-hour threshold.
    ; Our handler force-cancels the matching in-flight arrest so no stuck
    ; package or LinkedRef survives past the budget.
    RegisterForModEvent("SeverActions_ArrestSessionTimeout", "OnArrestSessionTimeout")

    ; PR-C: listen for ArrivalMonitor one-shot arrivals. The native side fires
    ; this when an actor we registered crosses its destination threshold. strArg
    ; is the callbackTag we passed at register time; OnArrival routes on it.
    RegisterForModEvent("SeverActionsNative_OnArrival", "OnArrival")

    ; Phase 2.3a: native EscortPackageReapplier fires this when the engine
    ; signals a cell-transition or combat-end on the active guard/prisoner.
    ; Replaces the 1Hz AddPackageOverride re-apply in CheckEscortProgress.
    RegisterForModEvent("SeverActions_EscortReapplyPackages", "OnEscortReapplyPackages")

    ; PrismaUI arrests page: jail-roster "Release" button. C++ ActionHandler
    ; fires this with the prisoner FormID in numArg. We re-resolve the actor
    ; and route through ReleasePrisoner so the full teardown path (factions,
    ; packages, outfit restore, Native_Jailed_Remove) runs identically to
    ; FreeNPC_Internal — no separate code path for UI-initiated releases.
    RegisterForModEvent("SeverActions_PrismaReleasePrisoner", "OnPrismaReleasePrisoner")

    ; PrismaUI arrests page: per-session "Cancel arrest" button (on the
    ; PrimaryArrestCard + compact rows). C++ encodes the prisoner as
    ; "<name>|" in strArg. We route to the matching cancel path based on
    ; which singleton slot the prisoner currently occupies — CancelCurrentArrest
    ; for same-cell, CancelDispatch for cross-cell. Both close the native
    ; session as part of their teardown, so no double-End() needed here.
    RegisterForModEvent("SeverActions_PrismaCancelArrest", "OnPrismaCancelArrest")

    ; Wave 5b: resolve the bounty sub-script reference if CK didn't fill it,
    ; then run its own Maintenance to set up its ArrestScript back-pointer.
    If !BountyScript
        Quest sevQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
        If sevQuest
            BountyScript = sevQuest as SeverActions_ArrestBounty
        EndIf
    EndIf
    If BountyScript
        BountyScript.Maintenance()
    Else
        Debug.Trace("[SeverActions_Arrest] WARNING: BountyScript not resolved — bounty subsystem unavailable")
    EndIf

    ; Wave 5b: same wiring for the Phase-6 judgment subsystem.
    If !JudgmentScript
        Quest sevQuest2 = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
        If sevQuest2
            JudgmentScript = sevQuest2 as SeverActions_ArrestJudgment
        EndIf
    EndIf
    If JudgmentScript
        JudgmentScript.Maintenance()
    Else
        Debug.Trace("[SeverActions_Arrest] WARNING: JudgmentScript not resolved — judgment subsystem unavailable")
    EndIf

    ; Wave 5b: player-confrontation + persuasion subsystem.
    If !PlayerScript
        Quest sevQuest3 = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
        If sevQuest3
            PlayerScript = sevQuest3 as SeverActions_ArrestPlayer
        EndIf
    EndIf
    If PlayerScript
        PlayerScript.Maintenance()
    Else
        Debug.Trace("[SeverActions_Arrest] WARNING: PlayerScript not resolved — player-arrest subsystem unavailable")
    EndIf

    ; Register every hold's metadata with the native HoldResolver. Idempotent —
    ; re-registering on every Maintenance() overwrites prior entries instead of
    ; growing the table, so subsequent calls are safe. Crime faction is the
    ; lookup key (vanilla guards are members of their hold's crime faction).
    SeverActionsNativeExt.Hold_Clear()
    If CrimeFactionWhiterun
        SeverActionsNativeExt.Hold_Register(CrimeFactionWhiterun, JailMarker_Whiterun, "Whiterun",   "SeverActions_Bounty_Whiterun",   "Dragonsreach Dungeon")
    EndIf
    If CrimeFactionRift
        SeverActionsNativeExt.Hold_Register(CrimeFactionRift,       JailMarker_Riften,    "The Rift",   "SeverActions_Bounty_Rift",       "Riften Jail")
    EndIf
    If CrimeFactionHaafingar
        SeverActionsNativeExt.Hold_Register(CrimeFactionHaafingar,  JailMarker_Solitude,  "Haafingar",  "SeverActions_Bounty_Haafingar",  "Castle Dour Dungeon")
    EndIf
    If CrimeFactionEastmarch
        SeverActionsNativeExt.Hold_Register(CrimeFactionEastmarch,  JailMarker_Windhelm,  "Eastmarch",  "SeverActions_Bounty_Eastmarch",  "Windhelm Jail")
    EndIf
    If CrimeFactionReach
        SeverActionsNativeExt.Hold_Register(CrimeFactionReach,      JailMarker_Markarth,  "The Reach",  "SeverActions_Bounty_Reach",      "Cidhna Mine")
    EndIf
    If CrimeFactionFalkreath
        SeverActionsNativeExt.Hold_Register(CrimeFactionFalkreath,  JailMarker_Falkreath, "Falkreath",  "SeverActions_Bounty_Falkreath",  "Falkreath Jail")
    EndIf
    If CrimeFactionPale
        SeverActionsNativeExt.Hold_Register(CrimeFactionPale,       JailMarker_Dawnstar,  "The Pale",   "SeverActions_Bounty_Pale",       "Dawnstar Jail")
    EndIf
    If CrimeFactionHjaalmarch
        SeverActionsNativeExt.Hold_Register(CrimeFactionHjaalmarch, JailMarker_Morthal,   "Hjaalmarch", "SeverActions_Bounty_Hjaalmarch", "Morthal Jail")
    EndIf
    If CrimeFactionWinterhold
        SeverActionsNativeExt.Hold_Register(CrimeFactionWinterhold, JailMarker_Winterhold,"Winterhold", "SeverActions_Bounty_Winterhold", "The Chill")
    EndIf
    Debug.Trace("[SeverActions_Arrest] HoldResolver registered " + SeverActionsNativeExt.Hold_Count() + " holds")

    ; BountyStore migration — drains the legacy "SeverActions_Bounty_<Hold>"
    ; StorageUtil keys on the player into the native BountyStore. MUST run
    ; AFTER Hold_Register above, because the drain resolves each hold's
    ; legacy key via Hold_GetBountyKeyForCrime() which is empty until the
    ; register chain has populated HoldResolver. Calling it earlier silently
    ; no-ops the drain and still commits the sentinel — permanent data loss.
    ; Idempotent: BountyScript's own sentinel makes re-runs cheap no-ops.
    If BountyScript
        BountyScript.MigrateLegacyStorage()
    EndIf
EndFunction

Event OnPlayerLoadGame()
    {Called when player loads a saved game. Verify prisoners, recover active dispatch,
     and restore deferred narration sender if one was pending.}
    Debug.Trace("[SeverActions_Arrest] Game loaded - verifying prisoner positions and dispatch state")
    ; PR-A: native HoldResolver table is in-memory only (no cosave), so the
    ; lookup is empty after every save+load. Re-run Maintenance() to rebuild
    ; it via Hold_Register. Without this every GetCrimeFactionForGuard returns
    ; None and every arrest action bails with "Could not determine guard's
    ; crime faction". Maintenance is idempotent — RegisterForModEvent dedups,
    ; back-refs already filled, Hold_Clear runs at the top of the re-register
    ; block, so calling it on every load is safe.
    Maintenance()
    ResetSessionCooldowns()
    MigrateJailedNPCsToNative()
    VerifyJailedNPCs()
    RecoverActiveArrest()
    RecoverActiveDispatch()

    ; Recover deferred narration sender. T1-D.3 routes through the 'ARPE'
    ; cosave record now (was: SeverActions_DeferredSender on quest form).
    ; PR-C: native ArrivalMonitor map is in-memory, doesn't survive save/load,
    ; so re-register the player watcher here if a sender was pending.
    Actor deferred = SeverActionsNativeExt.Native_Arrest_GetDeferredSender()
    If deferred != None
        DeferredNarrationSender = deferred
        If DeferredNarrationSender != None && !DeferredNarrationSender.IsDead()
            Debug.Trace("[SeverActions_Arrest] Recovered deferred narration sender: " + DeferredNarrationSender.GetDisplayName())
            SeverActionsNativeExt.Arrival_Register(Game.GetPlayer(), DeferredNarrationSender, NarrationProximityRange, "narration_witness")
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

Event OnNativeSandboxCleanup(string eventName, string strArg, float numArg, Form sender)
    {Fired by native SandboxManager on player cell change. Arrest's DispatchGuard is
     the only actor registered with SandboxManager (via FallbackSandboxSearch), so
     this handler unwinds the prisoner-sandbox state for that guard only.

     Follow.psc also listens for this event; its handler gates on IsSandboxing (a
     StorageUtil flag set only by Follow's own sandbox paths) and returns early for
     the DispatchGuard, so dual-listener is safe.}

    Actor akActor = sender as Actor
    If !akActor
        akActor = Game.GetFormEx(numArg as Int) as Actor
    EndIf

    ; Only handle the active DispatchGuard — if the cleanup event isn't for our
    ; guard, ignore it (it's either for Follow's sandbox flows or a stale event).
    If !akActor || akActor != DispatchGuard
        Return
    EndIf

    DebugMsg("Native cell-change cleanup for DispatchGuard: " + akActor.GetDisplayName())

    ; Abort the prisoner sandbox — the FSM will detect the missing state and
    ; transition forward on its next UpdateInterval tick. Clear the package +
    ; linked ref here directly so the guard doesn't stand around with a stale
    ; override waiting for the next phase check.
    SeverActionsNative.UnregisterSandboxUser(akActor)
    If SeverActions_PrisonerSandBox != None
        ActorUtil.RemovePackageOverride(akActor, SeverActions_PrisonerSandBox)
    EndIf
    If SeverActions_SandboxAnchorKW != None
        SeverActionsNative.LinkedRef_Clear(akActor, SeverActions_SandboxAnchorKW)
    EndIf
EndEvent

Event OnArrestSessionTimeout(string eventName, string strArg, float numArg, Form sender)
    {Wave 4: ArrestSessionStore watchdog hit a per-state in-game-hour threshold.
     strArg = decimal state enum (1..7). sender = the prisoner actor.

     Strategy: if the timed-out prisoner matches an active state (CurrentPrisoner
     for same-cell, DispatchTarget for dispatch), force-cancel via the matching
     existing path. Otherwise, just close the native session — no Papyrus state
     to recover from.}

    Actor akPrisoner = sender as Actor
    DebugMsg("ArrestSessionTimeout: prisoner=" + numArg + " state=" + strArg)

    If !akPrisoner
        ; Actor evaporated — native side already cleared on its end, nothing else to do.
        Return
    EndIf

    ; Same-cell arrest path. CancelCurrentArrest already ends the native session;
    ; no second End() call here.
    If CurrentPrisoner == akPrisoner && ArrestState > 0
        ; Phase 2.3b: kEscort timeout always finalizes the jailing (force-
        ; teleport guard + prisoner to the jail marker, then OnArrivedAtJail).
        ; This matches the legacy CheckEscortProgress force-teleport timeout
        ; behavior — the prisoner committed a crime worth arresting, the
        ; engine just failed to actually walk them to jail, so the right UX
        ; is to PUSH THE ARREST THROUGH, not abandon it. The legacy
        ; "guard already at jail" sub-case (time-skip arrival rescue) is now
        ; just a fast path under the same finalize policy.
        ;
        ; Scoped to ArrestState == 3 (escort). State 5 ("arrived") means
        ; OnArrivedAtJail is already mid-flight via the Utility.Wait calls
        ; for the MoveTo + navmesh snap, and re-entering it would double-
        ; process the jailing.
        If ArrestState == 3 && CurrentJailMarker != None
            ; CRITICAL re-fire fix (PR #81 review): FireTimeoutEvent on the
            ; native side does NOT End() the session entry — it just sends
            ; the ModEvent. The entry stays in state=3 with the budget still
            ; exceeded, so the 1Hz watchdog will re-fire SeverActions_ArrestSessionTimeout
            ; ~1s from now. By then OnArrivedAtJail is mid-flight (Utility.Wait
            ; calls during the MoveTo + navmesh snap), ArrestState has moved
            ; to 5 ("arrived"), and the second timeout would fall through the
            ; ArrestState==3 gate, hit CancelCurrentArrest, and race the
            ; in-progress finalize — corrupting state and stripping the
            ; session before RestorePrisonerStats can read the captured AVs.
            ;
            ; Pre-transition the session to kJailed=9 (no watchdog budget;
            ; TimeoutForState returns 0 in the default branch and CheckTimeouts
            ; skips threshold<=0). OnArrivedAtJail's own UpdateState(9) at the
            ; end of its body becomes a no-op transition.
            SeverActionsNative.Native_ArrestSession_UpdateState(akPrisoner, 9, 0)

            If CurrentGuard != None && CurrentGuard.GetDistance(CurrentJailMarker) <= ArrivalDistance
                ; Fast-finalize path — guard already at the marker. Prisoner
                ; placement happens inside OnArrivedAtJail (it MoveTos the
                ; prisoner relative to CurrentJailMarker), so the asymmetry
                ; with the slow path below is intentional.
                DebugMsg("ArrestSessionTimeout: kEscort — guard already at jail, fast-finalize")
            Else
                DebugMsg("ArrestSessionTimeout: kEscort — force-teleporting pair to jail (legacy EscortTimeout behavior)")
                CurrentPrisoner.MoveTo(CurrentJailMarker, 0.0, 0.0, 0.0)
                SeverActionsNative.Native_MoveToNearestNavmesh(CurrentPrisoner, 0.0)
                Utility.Wait(0.2)
                If CurrentGuard != None
                    CurrentGuard.MoveTo(CurrentJailMarker, 100.0, 0.0, 0.0)
                    SeverActionsNative.Native_MoveToNearestNavmesh(CurrentGuard, 0.0)
                    Utility.Wait(0.3)
                EndIf
            EndIf
            OnArrivedAtJail()
            Return
        EndIf

        ; Phase 2.3c: kApproach timeout — force-teleport guard to prisoner
        ; and call PerformArrest, matching the legacy CheckApproachProgress
        ; hard-timeout branch. Same finalize-don't-cancel policy as kEscort:
        ; the arrest is committed once it gets this far, so a stuck approach
        ; means the engine failed to walk the guard, not that the arrest
        ; should be abandoned. UnfreezePrisonerMovement covers the BUG-A6
        ; corner where the prisoner was frozen mid-approach and we now
        ; need movement back for the follow-package phase.
        ;
        ; Re-fire prevention (same as kEscort fix in PR #81): pre-transition
        ; the session to state=2 (kArresting) so the kApproach budget no
        ; longer applies. PerformArrest itself transitions to kEscort=3
        ; via StartEscortPhase a moment later.
        If ArrestState == 1 && CurrentGuard != None && CurrentPrisoner != None
            DebugMsg("ArrestSessionTimeout: kApproach — force-teleporting guard + PerformArrest (legacy ApproachTimeout behavior)")
            SeverActionsNative.Native_ArrestSession_UpdateState(akPrisoner, 2, 0)
            SeverActionsNativeExt.Stuck_StopTracking(CurrentGuard)
            CurrentGuard.MoveTo(CurrentPrisoner, 100.0, 0.0, 0.0)
            SeverActionsNative.Native_MoveToNearestNavmesh(CurrentGuard, 0.0)
            Utility.Wait(0.3)
            If SeverActions_GuardApproachTarget
                ActorUtil.RemovePackageOverride(CurrentGuard, SeverActions_GuardApproachTarget)
            EndIf
            UnfreezePrisonerMovement()
            PerformArrest()
            Return
        EndIf

        DebugMsg("ArrestSessionTimeout: cancelling same-cell arrest for " + akPrisoner.GetDisplayName())
        CancelCurrentArrest()
        Return
    EndIf

    ; Cross-cell dispatch path. CancelDispatch now ends the native session itself
    ; (see CancelDispatch — added for symmetry with CancelCurrentArrest), so we
    ; don't double-call End() here.
    If DispatchTarget == akPrisoner && DispatchPhase > 0
        DebugMsg("ArrestSessionTimeout: cancelling dispatch for " + akPrisoner.GetDisplayName())
        CancelDispatch()
        Return
    EndIf

    ; Stale session — Papyrus already cleaned up but the native record didn't get
    ; the End() call (most likely a script crash or a code path we missed wiring).
    ; Just close the native side and trust the watchdog to log it.
    DebugMsg("ArrestSessionTimeout: stale session for " + akPrisoner.GetDisplayName() + " — closing")
    SeverActionsNative.Native_ArrestSession_End(akPrisoner)
EndEvent

Event OnPrismaCancelArrest(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI arrests page → "Cancel arrest" button (PrimaryArrestCard or
     compact session row). C++ passes the prisoner FormID in numArg
     (PrismaUIActionHandler.h:cancelArrest dispatches via
     SendModEvent("SeverActions_PrismaCancelArrest", "", FormID)).
     The strArg field is intentionally empty — the prior name-based
     contract was a code-review casualty (PR #73 review) where a
     stale comment had us pipe-parsing strArg while C++ was sending
     the FormID instead. Every cancel button click was a no-op.

     Routing rule:
       - If the prisoner matches CurrentPrisoner → CancelCurrentArrest()
         (same-cell flow — states 1/2/3/4 + side states 7/8).
       - Else if the prisoner matches DispatchTarget → CancelDispatch()
         (cross-cell flow — state 5 + state 6 judgment).
       - Else: stale UI request (the session ended between the page render
         and the click). Log and no-op; PrismaUI will re-fetch on its
         next refresh.

     Both cancel paths close the native ArrestSessionStore entry as part
     of teardown (CancelCurrentArrest at the End() call site we audited,
     CancelDispatch via ClearDispatchState). So we don't double-end here.}

    Int prisonerFormId = numArg as Int
    If prisonerFormId == 0
        DebugMsg("PrismaUI cancel: empty FormID payload, ignoring")
        Return
    EndIf
    Form rawForm = Game.GetForm(prisonerFormId)
    Actor akPrisoner = rawForm as Actor
    If !akPrisoner
        DebugMsg("PrismaUI cancel: could not resolve prisoner FormID " + prisonerFormId)
        Return
    EndIf

    If CurrentPrisoner == akPrisoner && ArrestState > 0
        DebugMsg("PrismaUI cancel: same-cell arrest for " + akPrisoner.GetDisplayName())
        CancelCurrentArrest()
        Return
    EndIf

    If DispatchTarget == akPrisoner && DispatchPhase > 0
        DebugMsg("PrismaUI cancel: dispatch for " + akPrisoner.GetDisplayName())
        CancelDispatch()
        Return
    EndIf

    ; Neither slot matches — most likely a stale request. Close the native
    ; session if one still exists, so the watchdog table stays clean.
    DebugMsg("PrismaUI cancel: stale request for " + akPrisoner.GetDisplayName() + " — closing native session if any")
    SeverActionsNative.Native_ArrestSession_End(akPrisoner)
EndEvent

Event OnPrismaReleasePrisoner(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI arrests page → Jail Roster → "Release" button.
     C++ passes the prisoner FormID in numArg (see
     PrismaUIActionHandler.h:releasePrisoner). The strArg is empty —
     resolving via numArg is unambiguous (no duplicate-display-name
     fragility that name-based resolution had) and matches the
     ArrestSessionStore::FireTimeoutEvent convention of passing
     FormID-via-numArg.

     We resolve to the actor via Game.GetForm and route through
     FreePrisonerDirect → ReleaseFromJailCore, which is the same path
     FreeAllPrisoners uses. ReleaseFromJailCore now calls Native_Jailed_Remove
     internally (B5 fix), so the native roster stays in sync regardless of
     which entry point dropped the prisoner.}

    Int prisonerFormId = numArg as Int
    If prisonerFormId == 0
        DebugMsg("PrismaUI release: empty FormID payload, ignoring")
        Return
    EndIf
    Form rawForm = Game.GetForm(prisonerFormId)
    Actor akPrisoner = rawForm as Actor
    If !akPrisoner
        DebugMsg("PrismaUI release: could not resolve prisoner FormID " + prisonerFormId)
        Return
    EndIf
    DebugMsg("PrismaUI release: " + akPrisoner.GetDisplayName())
    FreePrisonerDirect(akPrisoner)
EndEvent

Event OnOrphanCleanup(string eventName, string strArg, float numArg, Form sender)
    {Wave 2 (C.2) + post-Wave 8 hotfix: handle orphaned arrest LinkedRefs detected
     by the native OrphanCleanup scanner. Fires for ANY actor holding our arrest
     keywords. We treat the arrest as "active" only when a corresponding live
     state exists somewhere (FSM slot OR native ArrestSessionStore entry). If
     none of those match, the keyword is stale even if an arrest faction tag
     lingers — and we MUST clean both the keyword and the stale faction tags,
     otherwise ArrestNPC_Internal's "already arrested or jailed" guard at the
     top of the function blocks every future arrest of that actor forever.

     Note: this script also has 'follow' / 'travel' / 'furniture' strArg variants
     for other systems' orphans — we ignore those here, the relevant subsystem's
     OnOrphanCleanup handler will pick them up.}

    Actor akActor = sender as Actor
    If !akActor
        Return
    EndIf

    ; Only handle arrest-related orphan strArgs.
    ; arrest_follow / arrest_sandbox  → keyword-driven (LinkedRef package leak)
    ; arrest_faction_sweep            → keyword-less stale faction membership
    ;                                   (catches guards stuck in dispatch Phase 1
    ;                                   before any keyword package was applied)
    If strArg != "arrest_follow" && strArg != "arrest_sandbox" && strArg != "arrest_faction_sweep"
        Return
    EndIf

    ; --- Tracked jailed prisoner check (FIRST — must come before stale-faction logic) ---
    ; Once OnArrivedAtJail completes it CALLS Native_ArrestSession_End and clears
    ; CurrentPrisoner, but the prisoner legitimately retains:
    ;   - SandboxAnchorKW LinkedRef → their jail marker
    ;   - PrisonerSandBox package override
    ;   - SeverActions_Jailed faction membership
    ; Without this guard, the next orphan scan tick (5 seconds after jailing) would
    ; fire arrest_sandbox + arrest_faction_sweep events, both reach the cleanup
    ; path because the active-state filter sees no FSM slot / no native session,
    ; and rip out the sandbox package + Jailed faction. Result: prisoner walks
    ; straight out of jail. JailedNPCs tracking is the source of truth — if the
    ; actor is in that array, every arrest-related signal on them is intentional.
    If IsNPCJailed(akActor)
        Return
    EndIf

    ; --- Active-state detection ---
    ; The actor is genuinely participating in a live arrest if any of these match.
    ; Pre-Wave 8 the filter was faction-membership-only; that turned out to be a
    ; trap, because if a previous arrest crashed before clearing SeverActions_Arrested
    ; / SeverActions_Jailed, the faction tag survived save/load and locked the actor
    ; out of the orphan cleanup pipeline AND out of new arrests indefinitely.
    Bool isActiveSlot = (akActor == CurrentGuard || akActor == CurrentPrisoner \
        || akActor == DispatchTarget || akActor == DispatchGuard \
        || (PlayerScript != None && akActor == PlayerScript.GetConfrontingGuard()))
    Bool hasNativeSession = SeverActionsNative.Native_ArrestSession_HasSession(akActor)

    If isActiveSlot || hasNativeSession
        ; Genuine in-flight arrest — leave the LinkedRef alone, the arrest FSM
        ; will end the session and clear the keyword on its normal completion path.
        Return
    EndIf

    ; --- Genuine orphan or stale-state survivor — clean up ---
    Bool inStaleArrestFaction = (akActor.IsInFaction(SeverActions_WaitingArrest) \
        || akActor.IsInFaction(SeverActions_Arrested) \
        || akActor.IsInFaction(SeverActions_Jailed) \
        || (SeverActions_DispatchFaction != None && akActor.IsInFaction(SeverActions_DispatchFaction)))

    ; If the sweep fired without any actual stale faction tag (e.g. faction-clear
    ; race between scan tick and arrest end), there's nothing to do — silently bail
    ; rather than spam EvaluatePackage on a healthy actor every 5 seconds.
    If strArg == "arrest_faction_sweep" && !inStaleArrestFaction
        Return
    EndIf

    DebugMsg("Orphan cleanup for " + akActor.GetDisplayName() + " (type=" + strArg \
        + ", staleFaction=" + inStaleArrestFaction + ")")

    If strArg == "arrest_follow"
        ; Strip every package that targets a FollowTargetKW LinkedRef.
        If SeverActions_GuardEscortPackage
            ActorUtil.RemovePackageOverride(akActor, SeverActions_GuardEscortPackage)
        EndIf
        If SeverActions_GuardApproachTarget
            ActorUtil.RemovePackageOverride(akActor, SeverActions_GuardApproachTarget)
        EndIf
        If SeverActions_FollowGuard_Prisoner
            ActorUtil.RemovePackageOverride(akActor, SeverActions_FollowGuard_Prisoner)
        EndIf
        If SeverActions_GuardFollowPlayer
            ActorUtil.RemovePackageOverride(akActor, SeverActions_GuardFollowPlayer)
        EndIf
        SeverActionsNative.LinkedRef_Clear(akActor, SeverActions_FollowTargetKW)
    ElseIf strArg == "arrest_sandbox"
        If SeverActions_PrisonerSandBox
            ActorUtil.RemovePackageOverride(akActor, SeverActions_PrisonerSandBox)
        EndIf
        SeverActionsNative.LinkedRef_Clear(akActor, SeverActions_SandboxAnchorKW)
    EndIf

    ; Remove stale arrest factions so the actor isn't permanently locked out of
    ; future arrests by ArrestNPC_Internal's "already arrested or jailed" guard.
    ; We only do this in the orphan path — confirmed-no-live-session — so we
    ; don't accidentally rip a legitimately-arrested actor out of their faction.
    If inStaleArrestFaction
        If akActor.IsInFaction(SeverActions_WaitingArrest)
            akActor.RemoveFromFaction(SeverActions_WaitingArrest)
        EndIf
        If akActor.IsInFaction(SeverActions_Arrested)
            akActor.RemoveFromFaction(SeverActions_Arrested)
        EndIf
        If akActor.IsInFaction(SeverActions_Jailed)
            akActor.RemoveFromFaction(SeverActions_Jailed)
        EndIf
        If SeverActions_DispatchFaction != None && akActor.IsInFaction(SeverActions_DispatchFaction)
            akActor.RemoveFromFaction(SeverActions_DispatchFaction)
        EndIf
        DebugMsg("Orphan cleanup removed stale arrest factions from " + akActor.GetDisplayName())
    EndIf

    ; Release the SkyrimNet v6+ busy lock if it was set during the arrest.
    ; Without this, an actor whose arrest crashed (faction/keyword swept here)
    ; carries is_busy="arrest" forever, blocking every third-party plugin's
    ; multi-step actions on them. Idempotent — no-op if not set.
    SeverActionsNative.Native_SkyrimNet_ClearActorBusy(akActor)

    akActor.EvaluatePackage()
EndEvent

Event OnEscortReapplyPackages(string eventName, string strArg, float numArg, Form sender)
    {Phase 2.3a: native EscortPackageReapplier fired a re-apply signal.
     strArg is "cellAttach" or "combatEnd" (diagnostic only — the
     re-apply work is the same either way). The handler runs the
     AddPackageOverride + EvaluatePackage pair that used to live
     in CheckEscortProgress as a per-tick guard.

     Defensive: re-validate the FSM slot before acting. If the world
     moved on (cancel path, death, another arrest), silently no-op.}

    If CurrentGuard == None || CurrentPrisoner == None || ArrestState != 3
        ; Stale event — escort not active. Don't call End() here:
        ; ClearArrestState is the canonical teardown path, and a stale
        ; event arriving in the transient gap between cancel + a fresh
        ; StartEscortPhase on the same pair could otherwise tear down
        ; the new tracker. Just silently drop.
        Return
    EndIf

    If CurrentGuard.IsDead() || CurrentPrisoner.IsDead()
        ; Death is handled by the per-tick check + the kEscort watchdog;
        ; just bail here.
        Return
    EndIf

    DebugMsg("EscortReapply: " + strArg + " — reasserting guard + prisoner packages")
    If SeverActions_GuardEscortPackage
        ActorUtil.AddPackageOverride(CurrentGuard, SeverActions_GuardEscortPackage, PackagePriority, 1)
        CurrentGuard.EvaluatePackage()
    EndIf
    If SeverActions_FollowGuard_Prisoner
        ActorUtil.AddPackageOverride(CurrentPrisoner, SeverActions_FollowGuard_Prisoner, PackagePriority, 1)
        CurrentPrisoner.EvaluatePackage()
    EndIf
EndEvent

Event OnArrival(string eventName, string strArg, float numArg, Form sender)
    {PR-C: native ArrivalMonitor fired a one-shot arrival event. strArg is the
     callbackTag passed at Arrival_Register time; routes by tag.

     Async safety: between the native detection and this Papyrus handler running,
     the FSM state may have changed (cancel path, death, another arrest). Each
     branch defensively re-validates the relevant slot/state before acting; if
     the world moved on, the handler silently no-ops and the stale event is
     discarded.}

    Actor arrivedActor = sender as Actor
    If arrivedActor == None
        Return
    EndIf

    If strArg == "arrest_approach_arrived"
        ; Guard reached the prisoner — fire arrest if state is still consistent.
        If CurrentGuard != arrivedActor || CurrentPrisoner == None || ArrestState != 1
            DebugMsg("OnArrival(approach): stale event (state moved on) — ignoring")
            Return
        EndIf
        DebugMsg("OnArrival(approach): guard reached prisoner (final dist " + numArg + ") — performing arrest")
        SeverActionsNativeExt.Stuck_StopTracking(CurrentGuard)
        If SeverActions_GuardApproachTarget
            ActorUtil.RemovePackageOverride(CurrentGuard, SeverActions_GuardApproachTarget)
        EndIf
        PerformArrest()

    ElseIf strArg == "arrest_escort_arrived"
        ; Guard reached the jail marker — finalize.
        If CurrentGuard != arrivedActor || CurrentPrisoner == None || CurrentJailMarker == None || ArrestState != 3
            DebugMsg("OnArrival(escort): stale event (state moved on) — ignoring")
            Return
        EndIf
        DebugMsg("OnArrival(escort): guard arrived at jail (final dist " + numArg + ")")
        OnArrivedAtJail()

    ElseIf strArg == "narration_witness"
        ; Player approached the deferred-narration sender. Fire the stored
        ; narration once and clear state. arrivedActor here is the player.
        If DeferredNarrationSender == None
            ; Already cleared by another path — discard.
            Return
        EndIf
        If DeferredNarrationSender.IsDead()
            ClearDeferredNarration()
            Return
        EndIf
        ; T1-D.3: native source of truth.
        String pendingNarration = SeverActionsNativeExt.Native_Arrest_GetPendingNarration(DeferredNarrationSender)
        If pendingNarration != ""
            SkyrimNetApi.DirectNarration(pendingNarration, DeferredNarrationSender, arrivedActor)
            DebugMsg("Fired deferred evidence narration from " + DeferredNarrationSender.GetDisplayName() + " via OnArrival")
        EndIf
        ClearDeferredNarration()

    ElseIf strArg == "dispatch_p1_arrived"
        ; PR-D: dispatch guard arrived at travel destination (target actor for
        ; arrest dispatch, home interior marker for home investigation).
        ; Defensively re-validate FSM state — the async event may fire after
        ; the FSM moved on (off-screen path teleported, cancelled, etc.).
        If DispatchGuard != arrivedActor || DispatchPhase != 1
            DebugMsg("OnArrival(dispatch_p1): stale event (state moved on) — ignoring")
            Return
        EndIf
        DebugMsg("OnArrival(dispatch_p1): guard reached travel destination (final dist " + numArg + ")")
        If DispatchIsHomeInvestigation
            TransitionToSandboxPhase()
        Else
            TransitionToApproachPhase()
        EndIf

    ElseIf strArg == "dispatch_p2_arrived"
        ; PR-D: dispatch guard reached arrest threshold. Mirrors the arrest
        ; finalization block in CheckDispatchPhase2_Approach (which the per-tick
        ; poll used to fire). Kept inline rather than extracted so the per-tick
        ; timeout path can keep its slightly different sequence (MoveTo first).
        If DispatchGuard != arrivedActor || DispatchTarget == None || DispatchPhase != 2
            DebugMsg("OnArrival(dispatch_p2): stale event (state moved on) — ignoring")
            Return
        EndIf
        DebugMsg("OnArrival(dispatch_p2): guard reached prisoner (final dist " + numArg + ") — performing dispatch arrest")
        SeverActionsNativeExt.Stuck_StopTracking(DispatchGuard)

        ; Release any Phase-2 movement freeze on the target.
        If DispatchTargetMovementFrozen && DispatchTarget != None
            DispatchTarget.SetDontMove(false)
            DispatchTargetMovementFrozen = false
        EndIf

        ; Remove approach/dispatch packages (replaced by walk in return phase).
        If SeverActions_GuardApproachTarget
            ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_GuardApproachTarget)
        EndIf
        If SeverActions_DispatchJog
            ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchJog)
        EndIf

        ApplyDispatchArrestEffects()
        RestoreGuardCombatAI()
        DebugMsg("Dispatch arrest effects applied to " + DispatchTarget.GetDisplayName())

        String p2GuardName = DispatchGuard.GetDisplayName()
        String p2TargetName = DispatchTarget.GetDisplayName()
        String p2Narration = "*" + p2GuardName + " seizes " + p2TargetName + " and places them under arrest.*"
        SkyrimNetApi.DirectNarration(p2Narration, DispatchGuard, DispatchTarget)
        Debug.Notification(p2GuardName + " has arrested " + p2TargetName)

        StartDispatchReturnPhase()

    ElseIf strArg == "dispatch_p5_arrived"
        ; PR-D: dispatch guard reached return destination (sender or jail).
        If DispatchGuard != arrivedActor || DispatchPhase != 5
            DebugMsg("OnArrival(dispatch_p5): stale event (state moved on) — ignoring")
            Return
        EndIf
        DebugMsg("OnArrival(dispatch_p5): guard reached return destination (final dist " + numArg + ")")
        CompleteDispatch()
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

    ; Wave 3 (loosened in Wave 8 hotfix): process level preflight. Reject only
    ; kNone (-1) — not-loaded actors. kLow (0) is still in the process list and
    ; can execute packages, just at the lowest priority tier. The original
    ; <= 0 check was rejecting too aggressively and blocking valid arrests
    ; against far-but-loaded NPCs. The dispatch path supports off-screen
    ; targets via its own MoveTo bring-in, so this guard is only on the
    ; same-cell ArrestNPC entry.
    ; Note: DLL registers this on the main SeverActionsNative type (via
    ; GuardFinder::RegisterFunctions), even though it was historically
    ; declared in SeverActionsNativeExt.psc. The declaration moved to
    ; SeverActionsNative.psc to match — caller updated accordingly so the
    ; Papyrus linker finds the function at runtime.
    Int targetProcessLevel = SeverActionsNative.Native_GetActorProcessLevel(akTarget)
    If targetProcessLevel < 0
        DebugMsg("ArrestNPC rejected: target process level " + targetProcessLevel + " (not loaded — use DispatchGuardToArrest for off-screen targets)")
        Return false
    EndIf

    ; Wave 8 hotfix: scene preflight removed. GetCurrentScene() returns non-null
    ; for any actor with an active BGSScene, and in Skyrim most town NPCs are
    ; in SOME scene at any given time (innkeepers running tavern routines,
    ; vendors at stalls, citizens on daily walks). The audit's recommendation
    ; was a defer in ArrivalMonitor (not a hard reject), and only for heavy
    ; scripted scenes. The hard reject here was killing virtually every arrest.
    ; Native_IsActorInScene remains exposed for future selective use.

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

    ; Mark guard as on-task so SkyrimNet's eligibility filter
    ; `is_in_faction(SeverActions_DispatchFaction) == false` excludes this guard
    ; from every SeverActions arrest-category action for the duration. Mirrors
    ; the InitDispatchCommon pattern used by the dispatch (off-screen) path.
    ; Removed on OnArrivedAtJail and CancelCurrentArrest.
    If SeverActions_DispatchFaction != None
        akGuard.AddToFaction(SeverActions_DispatchFaction)
        akGuard.SetFactionRank(SeverActions_DispatchFaction, 0)
    EndIf

    ; Mark BOTH guard and prisoner as busy via SkyrimNet's PublicAPI v6+ —
    ; this gates the global is_busy / busy_reason decorators that other
    ; plugins also use to filter eligibility. Our DispatchFaction guard above
    ; only excludes our own actions; this excludes any third-party plugin's
    ; multi-step actions (escort, follow, travel, etc.) from latching onto
    ; the guard or prisoner mid-arrest. Cleared in OnArrivedAtJail,
    ; CancelCurrentArrest, ReleasePrisoner, and the timeout/orphan paths.
    SeverActionsNative.Native_SkyrimNet_SetActorBusy(akGuard, "arrest")
    SeverActionsNative.Native_SkyrimNet_SetActorBusy(akTarget, "arrest")

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
    SeverActionsNativeExt.Stuck_StartTracking(CurrentGuard)

    ; BUG-A1: timeout window + prisoner movement freeze are timer-driven, so
    ; record the start point and clear the freeze flag now.
    ApproachStartTime = Utility.GetCurrentRealTime()
    PrisonerMovementFrozen = false
    PrisonerFrozenAt = 0.0

    ; BUG-A5: persist state so OnPlayerLoadGame can rebuild this on reload.
    PersistArrestState()

    ; Wave 4: open native arrest session — state=1 (kApproach) so the watchdog
    ; can fire a timeout if the approach phase exceeds its in-game-hour budget.
    Faction approachCrimeFaction = GetCrimeFactionForGuard(CurrentGuard)
    SeverActionsNative.Native_ArrestSession_Begin(CurrentPrisoner, CurrentGuard, CurrentJailMarker, approachCrimeFaction, 1, 0, 0)

    ; PR-C: register the guard with ArrivalMonitor for proximity-driven arrival.
    ; When the guard closes to ApproachDistance, OnArrival fires and routes to
    ; PerformArrest. CheckApproachProgress still runs per-tick for freeze /
    ; post-freeze-snap / stuck escalation / timeout — none of which are pure
    ; proximity events.
    SeverActionsNativeExt.Arrival_Register(CurrentGuard, CurrentPrisoner, ApproachDistance, "arrest_approach_arrived")

    ; Wave 8 hotfix: SetActorArrested moved out of the approach phase. Setting
    ; the engine's IsArrested flag during approach (before cuffs are on) had
    ; vanilla AI side effects — guards stopped pursuing (engine thought someone
    ; else got them), target combat behavior changed mid-approach, etc.
    ; The native is still exposed for selective use but not auto-set here.

    ; Start monitoring for arrival
    RegisterForSingleUpdate(UpdateInterval)
EndFunction

Event OnUpdate()
    ; PR-C: deferred-narration proximity polling moved to ArrivalMonitor.
    ; CompleteDispatch arms `narration_witness` on the player; OnArrival fires
    ; ClearDeferredNarration once the player closes to NarrationProximityRange.
    ; Defensive guard: if the sender died after registration but before fire,
    ; the native side won't notice — sweep that here.
    If DeferredNarrationSender != None && DeferredNarrationSender.IsDead()
        ClearDeferredNarration()
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
    ElseIf ArrestState == 4
        ; Wave 6.1: NPC prisoner is pleading their case mid-escort.
        ; Escort packages are temporarily replaced with a follow-prisoner
        ; package on the guard so they can hear the plea out.
        CheckEscortPleaProgress()
    EndIf

    ; Wave 5b: persuasion mode + post-resist combat cleanup moved to
    ; SeverActions_ArrestPlayer.psc, which drives its own OnUpdate independently.
    ; This script's OnUpdate now only handles dispatch / same-cell approach /
    ; same-cell escort. Deferred-narration proximity is native (PR-C).
EndEvent

Function CheckApproachProgress()
    {Check if guard has reached the target.
     Includes stuck detection with progressive recovery for cross-cell approaches.
     BUG-A1: now also enforces ApproachTimeout (30s default) and freezes the prisoner
     once within ApproachFreezeDistance, so an NPC running their own AI package can't
     keep distance oscillating around ApproachDistance forever.}

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
        SeverActionsNativeExt.Stuck_StopTracking(CurrentGuard)
        ; BUG-A6: release prisoner freeze if held before bailing
        UnfreezePrisonerMovement()
        CancelCurrentArrest()
        Return
    EndIf

    If CurrentPrisoner.IsDead()
        DebugMsg("Target died during approach")
        SeverActionsNativeExt.Stuck_StopTracking(CurrentGuard)
        UnfreezePrisonerMovement()
        CancelCurrentArrest()
        Return
    EndIf

    dist = CurrentGuard.GetDistance(CurrentPrisoner)

    ; PR-C: the "dist <= ApproachDistance → PerformArrest" branch lives in
    ; OnArrival now (native ArrivalMonitor, registered at StartApproachPhase).
    ; This per-tick function still runs as a watchdog for freeze, post-freeze
    ; teleport-snap, hard timeout, and stuck escalation — none of which are
    ; pure proximity events, all of which need to outlive the one-shot arrival.

    ; UX hotfix (Wave 6 polish): freeze the prisoner the moment the guard
        ; enters freeze range so they can't drift out of arrest range, but
        ; let the guard walk in NATURALLY for ApproachPostFreezeGracePeriod
        ; seconds (default 5s) before falling back to a teleport snap. The
        ; original snap-on-freeze fix was reliable but visually jarring —
        ; this preserves the reliability (guard always reaches arrest range
        ; within bounded time) without the abrupt teleport on normal walks.
        ;
        ; Sequence after freeze:
        ;   t=0   freeze fires, no teleport, guard keeps walking
        ;   t<5   if dist <= ApproachDistance — natural walk-in arrest (smooth)
        ;   t>=5  if still dist > ApproachDistance — fallback teleport snap
        ;   t=30  hard ApproachTimeout safety net (rarely reached)
        If !PrisonerMovementFrozen && dist <= ApproachFreezeDistance
            CurrentPrisoner.SetDontMove(true)
            PrisonerMovementFrozen = true
            PrisonerFrozenAt = Utility.GetCurrentRealTime()
            DebugMsg("Approach: prisoner inside " + ApproachFreezeDistance + "u (dist=" + dist + "), frozen — guard walking in naturally (grace=" + ApproachPostFreezeGracePeriod + "s)")
        EndIf

        ; Post-freeze fallback snap: if we've been frozen for the grace period
        ; and the guard still hasn't closed to ApproachDistance, the engine is
        ; failing us (slow walk, path stutter, package distance setting). Snap
        ; the guard in and arrest. Without this fallback the user would just
        ; sit there watching the guard "stuck" near but not at the prisoner.
        If PrisonerMovementFrozen && PrisonerFrozenAt > 0.0
            Float frozenElapsed = Utility.GetCurrentRealTime() - PrisonerFrozenAt
            If frozenElapsed >= ApproachPostFreezeGracePeriod && dist > ApproachDistance
                DebugMsg("Approach: post-freeze grace expired (" + frozenElapsed + "s, dist=" + dist + "u still > " + ApproachDistance + "u) — fallback snap")
                SeverActionsNativeExt.Stuck_StopTracking(CurrentGuard)

                Float snapOffset = ApproachDistance * 0.5
                If snapOffset < 50.0
                    snapOffset = 50.0
                EndIf
                CurrentGuard.MoveTo(CurrentPrisoner, snapOffset, 0.0, 0.0)
                SeverActionsNative.Native_MoveToNearestNavmesh(CurrentGuard, 0.0)

                If SeverActions_GuardApproachTarget
                    ActorUtil.RemovePackageOverride(CurrentGuard, SeverActions_GuardApproachTarget)
                EndIf
                PerformArrest()
                Return
            EndIf
        EndIf

        ; Tick-by-tick distance trace so a future "guard parked next to prisoner
        ; but arrest never fires" report tells us whether GetDistance is lying
        ; vs. visual position (cell mismatch / Z-axis inflation / stale handle).
        DebugMsg("Approach tick: dist=" + dist + " (freeze=" + ApproachFreezeDistance + " arrest=" + ApproachDistance + ")")

        ; Phase 2.3c: hard ApproachTimeout moved to the kApproach
        ; ArrestSessionStore watchdog. OnArrestSessionTimeout's kApproach
        ; branch now performs the same force-teleport + PerformArrest
        ; finalize this block used to do. Budget is 1 game-hour (vs the
        ; legacy 30s real-time default — looser, but game-time-scaled,
        ; so a wait/sleep skip still trips it).

        ; Not arrived yet - check for stuck (helps with cross-cell approaches)
        stuckLevel = SeverActionsNativeExt.Stuck_CheckStatus(CurrentGuard, UpdateInterval, 50.0)

        If stuckLevel == 1
            ; Possibly stuck - re-evaluate packages
            DebugMsg("Approach: guard may be stuck, re-evaluating packages")
            CurrentGuard.EvaluatePackage()
        ElseIf stuckLevel == 2
            ; Stuck - leapfrog toward target
            teleportDist = SeverActionsNativeExt.Stuck_GetTeleportDistance(CurrentGuard)
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
                ; Wave 3: navmesh snap after relative leapfrog
                SeverActionsNative.Native_MoveToNearestNavmesh(CurrentGuard, 0.0)
                CurrentGuard.EvaluatePackage()
                DebugMsg("Approach: leapfrog guard " + teleportDist + " units toward target")
            EndIf

            SeverActionsNativeExt.Stuck_ResetEscalation(CurrentGuard)
        ElseIf stuckLevel >= 3
            ; Very stuck - force teleport near target
            DebugMsg("Approach: force teleporting guard near target")
            CurrentGuard.MoveTo(CurrentPrisoner, 200.0, 0.0, 0.0)
            ; Wave 3: navmesh snap after offset teleport
            SeverActionsNative.Native_MoveToNearestNavmesh(CurrentGuard, 0.0)
            Utility.Wait(0.5)
            CurrentGuard.EvaluatePackage()
            SeverActionsNativeExt.Stuck_ResetEscalation(CurrentGuard)
        EndIf

        ; Watchdog re-arm — proximity arrival is event-driven (OnArrival) now,
        ; but freeze/timeout/stuck still need per-tick evaluation.
        RegisterForSingleUpdate(UpdateInterval)
EndFunction

Function UnfreezePrisonerMovement()
    {Release the SetDontMove freeze applied during approach. Idempotent.
     Called on PerformArrest, CancelCurrentArrest, and on prisoner-death paths
     so we never leave a future-arrested NPC permanently stuck in place.}
    If PrisonerMovementFrozen && CurrentPrisoner != None
        CurrentPrisoner.SetDontMove(false)
    EndIf
    PrisonerMovementFrozen = false
    PrisonerFrozenAt = 0.0
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

    ; PR-C: cancel the approach-phase ArrivalMonitor registration. ArrivalMonitor
    ; auto-removes on fire, so a natural-walk-in arrival already cleared the entry;
    ; this cancel covers the teleport-snap / timeout paths where PerformArrest is
    ; called WITHOUT the event firing.
    SeverActionsNativeExt.Arrival_Cancel(CurrentGuard)

    ArrestState = 2 ; arresting

    Actor prisoner = CurrentPrisoner
    Actor guard = CurrentGuard

    ; Wave 4: state=2 is transient (sub-second), but tell the watchdog so the
    ; timer baseline resets — otherwise a sluggish PerformArrest could trip
    ; the kApproach budget before the escort starts.
    SeverActionsNative.Native_ArrestSession_UpdateState(prisoner, 2, 0)

    DebugMsg("Performing arrest on " + prisoner.GetDisplayName())

    ; BUG-A1: release any movement freeze applied during approach BEFORE we
    ; equip cuffs / start follow package, otherwise SetDontMove blocks the
    ; follow path-finding and the prisoner just stands there.
    UnfreezePrisonerMovement()

    ; Stop any combat
    prisoner.StopCombat()
    prisoner.StopCombatAlarm()

    ; Cancel any active travel errand so it doesn't fight with arrest escort
    If TravelSystem != None
        TravelSystem.CancelTravel(prisoner)
    EndIf

    ; Pacify the prisoner. Capture originals on the native ArrestSession entry
    ; BEFORE zeroing so RestorePrisonerStats can put them back on release.
    ; Without the capture/restore pair, prisoners would walk out of jail
    ; permanently pacified (Aggression=0, Confidence=0) — bandits become
    ; docile, hostile NPCs become friendly. CaptureAVs is idempotent —
    ; only sets fields holding the sentinel -1.0, so a double-PerformArrest
    ; doesn't clobber the captured originals with the about-to-be-zeroed
    ; values. (Phase 1.4 migration: replaces the legacy StorageUtil
    ; "SeverArrest_OrigAggression" / "_OrigConfidence" keys with cosave-
    ; backed fields on the ArrestSession entry.)
    SeverActionsNative.Native_ArrestSession_CaptureAVs(prisoner, prisoner.GetAV("Aggression"), prisoner.GetAV("Confidence"))
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
    SeverActionsNative.LinkedRef_Set(prisoner, guard, SeverActions_FollowTargetKW)
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

    ; BUG-A2: timer for force-teleport fallback if escort runs longer than EscortTimeout
    EscortStartTime = Utility.GetCurrentRealTime()

    ; BUG-A5: persist state so OnPlayerLoadGame can rebuild this on reload.
    PersistArrestState()

    ; Wave 4: state=3 (kEscort) — watchdog gets a 6-game-hour budget for this
    ; phase. Use EnsureBegin instead of UpdateState because EndJudgment →
    ; ClearDispatchState calls Native_ArrestSession_End before reaching here
    ; for the judgment→jail handoff. A plain UpdateState would silently no-op
    ; on that path, leaving the escort with no watchdog and no PrismaUI
    ; visibility. EnsureBegin is begin-or-update, idempotent, and refreshes
    ; guard/marker/faction fields if they rotated between legs.
    Faction escortCrimeFaction = GetCrimeFactionForGuard(CurrentGuard)
    SeverActionsNative.Native_ArrestSession_EnsureBegin(CurrentPrisoner, CurrentGuard, CurrentJailMarker, escortCrimeFaction, 3, 0, 0)

    ; Phase 2.3a: arm the native EscortPackageReapplier on the active pair.
    ; The monitor sinks TESCellAttachDetachEvent + TESCombatEvent and fires
    ; SeverActions_EscortReapplyPackages → OnEscortReapplyPackages when the
    ; engine drops one of our overrides, replacing the 1Hz CheckEscortProgress
    ; re-apply that used to paper over those drops.
    SeverActionsNative.Native_EscortReapply_Begin(CurrentGuard, CurrentPrisoner)

    ; PR-C: register the guard with ArrivalMonitor for jail-marker arrival.
    ; When the guard reaches ArrivalDistance of CurrentJailMarker, OnArrival
    ; fires and routes to OnArrivedAtJail. CheckEscortProgress still runs
    ; per-tick for package re-apply and the EscortTimeout safety teleport.
    SeverActionsNativeExt.Arrival_Register(CurrentGuard, CurrentJailMarker, ArrivalDistance, "arrest_escort_arrived")

    ; Start monitoring for arrival
    RegisterForSingleUpdate(UpdateInterval)
EndFunction

Function CheckEscortProgress()
    {Check if guard has arrived at jail.
     BUG-A2: also re-applies the guard's escort package each tick (mirrors the
     prisoner's follow re-apply below) so the engine can't silently drop it.
     Adds a real-time timeout — without it, a guard whose package gets clobbered
     by combat / mod conflict / cell unload runs the escort package indefinitely
     with no hope of arrival, leaving the package permanently stuck on them.
     BUG-A6: clears the prisoner's LinkedRef on death so the cosave entry doesn't
     dangle past the prisoner's lifetime.}

    If CurrentGuard == None || CurrentPrisoner == None || CurrentJailMarker == None
        DebugMsg("ERROR: CheckEscortProgress - invalid state")
        CancelCurrentArrest()
        Return
    EndIf

    ; Check if guard or prisoner died during escort
    If CurrentGuard.IsDead()
        DebugMsg("Guard died during escort")
        ; ReleasePrisoner already clears LinkedRefs on the prisoner.
        ReleasePrisoner(CurrentPrisoner)
        CancelCurrentArrest()
        Return
    EndIf

    If CurrentPrisoner.IsDead()
        DebugMsg("Prisoner died during escort")
        ; BUG-A6: explicit LinkedRef cleanup on the dead prisoner. The native
        ; PackageManager TESDeathEvent handler will normally do this, but the
        ; event fires asynchronously and CancelCurrentArrest doesn't wait, so
        ; clear here defensively to keep the cosave clean.
        SeverActionsNative.LinkedRef_Clear(CurrentPrisoner, SeverActions_FollowTargetKW)
        SeverActionsNative.LinkedRef_Clear(CurrentPrisoner, SeverActions_SandboxAnchorKW)
        CancelCurrentArrest()
        Return
    EndIf

    ; Phase 2.3a: per-tick package re-apply moved to the native
    ; EscortPackageReapplier monitor. It sinks TESCellAttachDetachEvent +
    ; TESCombatEvent and fires SeverActions_EscortReapplyPackages →
    ; OnEscortReapplyPackages exactly when one of the two drop scenarios
    ; the legacy code papered over (cell transition / combat-end) happens.
    ; This loop still runs per-tick for the timeout + death checks
    ; below, but the AddPackageOverride 1Hz spam is gone.

    ; Phase 2.3b: escort timeout moved to the ArrestSessionStore kEscort
    ; watchdog. OnArrestSessionTimeout's kEscort branch now performs the
    ; force-teleport-to-jail + OnArrivedAtJail finalize that used to live
    ; here. Budget is 6 game-hours (TimeoutForState(kEscort) in
    ; ArrestSessionStore.h) — at the default timescale 20 that's ~18 real
    ; minutes, a longer budget than the legacy 10 real-min EscortTimeout
    ; but tracks game-time so a sleep-skip still trips it.
    ;
    ; PR-C: arrival at jail is event-driven now (OnArrival fires from
    ; native ArrivalMonitor). This function still ticks for death checks;
    ; pending 2.3c those move to TESDeathEvent and the OnUpdate goes away
    ; entirely for the kEscort branch.
    RegisterForSingleUpdate(UpdateInterval)
EndFunction

; =============================================================================
; ESCORT PLEA - Mid-march negotiation (Wave 6.1)
; The NPC prisoner can call AppealDuringEscort once during ArrestState == 3.
; Guard pauses the escort, switches from GuardEscortPackage to a follow-prisoner
; package (weapon stays drawn), and listens. Outcomes:
;   - AcceptEscortPlea_Internal → release prisoner (full faction/cuff cleanup)
;   - RejectEscortPlea_Internal → resume escort to jail (back to State 3)
;   - timeout / distance         → silent resume escort with annoyed narration
; Single attempt per arrest — EscortPleaAttempted gates re-entry.
; Mirrors PlayerScript's HandlePersuade / Accept / Reject flow but for an NPC
; mid-escort instead of the player at the start of an arrest.
; =============================================================================

Bool Function AppealDuringEscort_Internal(Actor akPrisoner)
    {NPC prisoner pleads their case to the escorting guard mid-march.
     Guard pauses the escort and listens. Returns true if the plea state was
     successfully entered, false on rejection (wrong state, wrong actor, or
     plea already attempted this arrest).
     Wired via appealduringescort.yaml (speaker = prisoner).}

    If akPrisoner == None
        DebugMsg("ERROR: AppealDuringEscort called with None prisoner")
        Return false
    EndIf

    ; Validate we're mid-escort and this IS the active prisoner
    If ArrestState != 3
        DebugMsg("AppealDuringEscort rejected: ArrestState=" + ArrestState + " (need 3=escort)")
        Return false
    EndIf

    If akPrisoner != CurrentPrisoner
        DebugMsg("AppealDuringEscort rejected: " + akPrisoner.GetDisplayName() + " is not the current prisoner")
        Return false
    EndIf

    ; Single attempt per arrest
    If EscortPleaAttempted
        DebugMsg("AppealDuringEscort rejected: prisoner already attempted plea this arrest")
        Return false
    EndIf

    If CurrentGuard == None || CurrentGuard.IsDead()
        DebugMsg("AppealDuringEscort rejected: guard invalid or dead")
        Return false
    EndIf

    DebugMsg(akPrisoner.GetDisplayName() + " is pleading their case to " + CurrentGuard.GetDisplayName() + " mid-escort")

    ; --- Switch guard from escort mode to listen-to-prisoner mode ---

    ; Stop stuck tracking — the guard is intentionally not moving toward jail now
    SeverActionsNativeExt.Stuck_StopTracking(CurrentGuard)

    ; PR-C: cancel the escort-phase ArrivalMonitor registration. The guard now
    ; tracks the prisoner instead, and would otherwise drift "arrived at jail"
    ; over the rest of the plea if any path brought them close to the marker.
    SeverActionsNativeExt.Arrival_Cancel(CurrentGuard)

    ; Remove the escort package
    If SeverActions_GuardEscortPackage
        ActorUtil.RemovePackageOverride(CurrentGuard, SeverActions_GuardEscortPackage)
    EndIf

    ; Relink guard's FollowTargetKW from the jail marker → prisoner. The
    ; SeverActions_GuardFollowPlayer package follows whatever FollowTargetKW
    ; LinkedRef points at, so this swap is what makes the guard track the
    ; prisoner instead of continuing toward the jail marker. Same trick
    ; HandlePersuade uses for the player FSM.
    SeverActionsNative.LinkedRef_Set(CurrentGuard, akPrisoner, SeverActions_FollowTargetKW)

    If SeverActions_GuardFollowPlayer
        ActorUtil.AddPackageOverride(CurrentGuard, SeverActions_GuardFollowPlayer, PackagePriority, 1)
        CurrentGuard.EvaluatePackage()
    EndIf

    ; Keep weapon drawn — the threat persists during the plea
    CurrentGuard.DrawWeapon()

    ; Also remove the prisoner's follow-guard package so the two actors don't
    ; oscillate (guard following prisoner who's following guard...). Prisoner
    ; stands still / can gesture; guard tracks them.
    If SeverActions_FollowGuard_Prisoner
        ActorUtil.RemovePackageOverride(akPrisoner, SeverActions_FollowGuard_Prisoner)
    EndIf
    akPrisoner.EvaluatePackage()

    ; --- Update FSM state ---
    ArrestState = 4
    EscortPleaStartTime = Utility.GetCurrentRealTime()
    EscortPleaAttempted = true

    ; Update the native watchdog to kEscortPlea (8). Previously this wrote 7
    ; (kPersuasion) and intentionally overloaded the persuasion semantic to
    ; reuse the 15-minute timeout budget. After the cosave enum split
    ; (kEscortPlea now distinct from kPersuasion) the PrismaUI arrests page
    ; can show the accurate "Escort Plea" label instead of mislabeling
    ; everyone as "Persuasion." Budget is unchanged at 15 in-game minutes.
    SeverActionsNative.Native_ArrestSession_UpdateState(CurrentPrisoner, 8, 0)

    ; --- Set context for SkyrimNet so the LLM has the full picture ---
    String holdName = GetHoldNameForGuard(CurrentGuard)
    Int bounty = 0
    If BountyScript
        bounty = BountyScript.GetTrackedBountyForGuard(CurrentGuard)
    EndIf

    String narration = "*" + CurrentGuard.GetDisplayName() + " halts the march, weapon still in hand, willing to hear what " + akPrisoner.GetDisplayName() + " has to say.*"
    SkyrimNetApi.DirectNarration(narration, akPrisoner, CurrentGuard)

    String eventMsg = akPrisoner.GetDisplayName() + " is pleading their case to " + CurrentGuard.GetDisplayName() + " mid-escort to jail. They have a tracked bounty of " + bounty + " gold in " + holdName + ". The guard is listening but skeptical — they may accept the plea and release the prisoner, or reject it and continue the escort to jail."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, CurrentGuard, akPrisoner)

    Debug.Notification("The escort pauses — " + CurrentGuard.GetDisplayName() + " is listening")

    ; Make sure OnUpdate is armed for the per-tick check
    RegisterForSingleUpdate(UpdateInterval)

    Return true
EndFunction

Function CheckEscortPleaProgress()
    {Per-tick check — called from OnUpdate when ArrestState == 4.
     Handles timeout, distance, and dead-actor failures.}

    If ArrestState != 4
        Return
    EndIf

    If CurrentGuard == None || CurrentGuard.IsDead()
        DebugMsg("Escort plea: guard died, ending arrest")
        CancelCurrentArrest()
        Return
    EndIf

    If CurrentPrisoner == None || CurrentPrisoner.IsDead()
        DebugMsg("Escort plea: prisoner died, ending arrest")
        CancelCurrentArrest()
        Return
    EndIf

    Float elapsed = Utility.GetCurrentRealTime() - EscortPleaStartTime

    ; Timeout — guard runs out of patience, silent resume with annoyed narration
    If elapsed >= EscortPleaTimeLimit
        DebugMsg("Escort plea timed out after " + elapsed + "s — resuming escort")
        String narration = "*" + CurrentGuard.GetDisplayName() + " grows tired of " + CurrentPrisoner.GetDisplayName() + "'s excuses.* \"Enough. Move.\""
        SkyrimNetApi.DirectNarration(narration, CurrentPrisoner, CurrentGuard)

        String eventMsg = CurrentGuard.GetDisplayName() + " grew tired of " + CurrentPrisoner.GetDisplayName() + "'s pleading and resumed the march to jail."
        SkyrimNetApi.RegisterPersistentEvent(eventMsg, CurrentGuard, CurrentPrisoner)

        ResumeEscortFromPlea()
        Return
    EndIf

    ; Distance — prisoner moved too far. Treated as escape attempt; guard
    ; resumes escort with a "trying to slip away" narration.
    Float distance = CurrentGuard.GetDistance(CurrentPrisoner)
    If distance > EscortPleaFollowDistance
        DebugMsg("Escort plea: prisoner moved " + distance + "u from guard — resuming escort")
        String narration = "*" + CurrentGuard.GetDisplayName() + " catches up, gripping " + CurrentPrisoner.GetDisplayName() + " firmly.* \"Trying to slip away? Walk.\""
        SkyrimNetApi.DirectNarration(narration, CurrentPrisoner, CurrentGuard)

        String eventMsg = CurrentPrisoner.GetDisplayName() + " tried to walk away during their plea. " + CurrentGuard.GetDisplayName() + " resumed the escort to jail."
        SkyrimNetApi.RegisterPersistentEvent(eventMsg, CurrentGuard, CurrentPrisoner)

        ResumeEscortFromPlea()
        Return
    EndIf

    ; Still in plea — keep ticking
    RegisterForSingleUpdate(UpdateInterval)
EndFunction

Bool Function AcceptEscortPlea_Internal(Actor akGuard)
    {Guard accepts the prisoner's plea — release them mid-escort.
     Wired via acceptescortplea.yaml (speaker = guard).}

    If akGuard == None
        DebugMsg("ERROR: AcceptEscortPlea called with None guard")
        Return false
    EndIf

    If ArrestState != 4
        DebugMsg("AcceptEscortPlea rejected: ArrestState=" + ArrestState + " (need 4=escort plea)")
        Return false
    EndIf

    If akGuard != CurrentGuard
        DebugMsg("AcceptEscortPlea rejected: " + akGuard.GetDisplayName() + " is not the active escorting guard")
        Return false
    EndIf

    If CurrentPrisoner == None
        DebugMsg("AcceptEscortPlea rejected: no current prisoner")
        Return false
    EndIf

    DebugMsg(akGuard.GetDisplayName() + " accepted " + CurrentPrisoner.GetDisplayName() + "'s plea — releasing")

    ; Capture refs before clearing state
    Actor releasedPrisoner = CurrentPrisoner
    Actor escortingGuard = CurrentGuard

    ; Narration + persistent event
    String narration = "*" + escortingGuard.GetDisplayName() + " sighs and lowers their weapon.* \"Get out of here. Don't let me see your face again.\""
    SkyrimNetApi.DirectNarration(narration, releasedPrisoner, escortingGuard)

    String eventMsg = escortingGuard.GetDisplayName() + " was convinced by " + releasedPrisoner.GetDisplayName() + " and released them mid-escort instead of taking them to jail."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, escortingGuard, releasedPrisoner)

    Debug.Notification(releasedPrisoner.GetDisplayName() + " has been released")

    ; --- Clean up packages on guard ---
    SeverActionsNativeExt.Stuck_StopTracking(escortingGuard)
    If SeverActions_GuardFollowPlayer
        ActorUtil.RemovePackageOverride(escortingGuard, SeverActions_GuardFollowPlayer)
    EndIf
    SeverActionsNative.LinkedRef_Clear(escortingGuard, SeverActions_FollowTargetKW)
    escortingGuard.SheatheWeapon()

    ; Release the SkyrimNet on-task lock + busy lock
    If SeverActions_DispatchFaction != None && escortingGuard.IsInFaction(SeverActions_DispatchFaction)
        escortingGuard.RemoveFromFaction(SeverActions_DispatchFaction)
    EndIf
    SeverActionsNative.Native_SkyrimNet_ClearActorBusy(escortingGuard)
    escortingGuard.EvaluatePackage()

    ; --- Release the prisoner (faction cleanup, cuffs off, restore stats, etc.) ---
    ReleasePrisoner(releasedPrisoner)

    ; Clear arrest aliases + native session
    ArrestTarget.Clear()
    ArrestingGuard.Clear()
    JailDestination.Clear()
    SeverActionsNative.Native_ArrestSession_End(releasedPrisoner)

    ; Persisted state cleanup
    ClearPersistedArrestState()
    ApproachStartTime = 0.0
    EscortStartTime = 0.0

    ClearArrestState()

    Return true
EndFunction

Bool Function RejectEscortPlea_Internal(Actor akGuard)
    {Guard rejects the prisoner's plea — resume escort to jail.
     Wired via rejectescortplea.yaml (speaker = guard).}

    If akGuard == None
        DebugMsg("ERROR: RejectEscortPlea called with None guard")
        Return false
    EndIf

    If ArrestState != 4
        DebugMsg("RejectEscortPlea rejected: ArrestState=" + ArrestState + " (need 4=escort plea)")
        Return false
    EndIf

    If akGuard != CurrentGuard
        DebugMsg("RejectEscortPlea rejected: " + akGuard.GetDisplayName() + " is not the active escorting guard")
        Return false
    EndIf

    DebugMsg(akGuard.GetDisplayName() + " rejected " + CurrentPrisoner.GetDisplayName() + "'s plea — resuming escort")

    ; Guard's own dialogue follows via SkyrimNet — just register the event for context
    String eventMsg = akGuard.GetDisplayName() + " was not convinced by " + CurrentPrisoner.GetDisplayName() + "'s pleading and resumed the escort to jail."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, akGuard, CurrentPrisoner)

    Debug.Notification("The plea was rejected")

    ResumeEscortFromPlea()
    Return true
EndFunction

Function ResumeEscortFromPlea()
    {Internal helper: re-arm escort packages + LinkedRef back to jail marker
     and transition ArrestState back to 3. Called by Reject + timeout +
     distance-fail paths.

     Phase 2.3a invariant: the native EscortPackageReapplier tracker stays
     ARMED across the plea pause — plea-entry doesn't call
     Native_EscortReapply_End and plea-resume doesn't re-Begin. The plea
     swap (GuardEscortPackage → GuardFollowPlayer) doesn't change the
     tracked actor pair, so the existing tracker is still valid; tearing
     it down and re-arming would just open a transient window where a
     cell-attach or combat-end during the plea wouldn't fire a re-apply.}

    If CurrentGuard == None || CurrentPrisoner == None || CurrentJailMarker == None
        DebugMsg("ERROR: ResumeEscortFromPlea — invalid state, canceling")
        CancelCurrentArrest()
        Return
    EndIf

    ; Remove the listen-to-prisoner package
    If SeverActions_GuardFollowPlayer
        ActorUtil.RemovePackageOverride(CurrentGuard, SeverActions_GuardFollowPlayer)
    EndIf

    ; Clear the prisoner-pointing LinkedRef. ReapplyEscortPackages below will
    ; re-set the LinkedRef pattern that escort needs (prisoner→guard via
    ; FollowGuard_Prisoner).
    SeverActionsNative.LinkedRef_Clear(CurrentGuard, SeverActions_FollowTargetKW)

    ; Re-fill aliases (defensive — they should still be filled but in case
    ; something cleared them during the plea state)
    ArrestTarget.ForceRefTo(CurrentPrisoner)
    ArrestingGuard.ForceRefTo(CurrentGuard)
    If CurrentJailMarker != None
        JailDestination.ForceRefTo(CurrentJailMarker)
    EndIf

    ; Re-apply escort package + prisoner follow package (mirrors StartEscortPhase)
    ReapplyEscortPackages(CurrentGuard, CurrentPrisoner, CurrentJailMarker)

    ; Re-arm stuck tracking — the guard is moving toward jail again
    SeverActionsNativeExt.Stuck_StartTracking(CurrentGuard)

    ; Reset state to escort
    ArrestState = 3
    EscortStartTime = Utility.GetCurrentRealTime()
    EscortPleaStartTime = 0.0

    ; Reset the watchdog timer to the escort budget
    SeverActionsNative.Native_ArrestSession_UpdateState(CurrentPrisoner, 3, 0)

    ; PR-C: re-arm ArrivalMonitor for the jail marker — the plea cancelled
    ; the prior registration; without this re-register the guard would walk
    ; the full distance with no proximity-event safety net (only the slower
    ; per-tick safety teleport via EscortTimeout would catch a "arrived but
    ; never noticed" stall).
    SeverActionsNativeExt.Arrival_Register(CurrentGuard, CurrentJailMarker, ArrivalDistance, "arrest_escort_arrived")

    DebugMsg("Resumed escort from plea — " + CurrentGuard.GetDisplayName() + " escorting " + CurrentPrisoner.GetDisplayName() + " to " + CurrentJailName)

    RegisterForSingleUpdate(UpdateInterval)
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

    ; PR-C: cancel the escort-phase ArrivalMonitor registration. ArrivalMonitor
    ; auto-removes on fire, so a natural arrival already cleared the entry; this
    ; cancel covers the EscortTimeout teleport path where OnArrivedAtJail is
    ; called without the event firing.
    SeverActionsNativeExt.Arrival_Cancel(CurrentGuard)

    ArrestState = 5 ; arrived (transient — distinct from state 4 "escort plea" to avoid OnUpdate routing collision)

    ; Store local references before clearing state
    Actor prisoner = CurrentPrisoner
    Actor guard = CurrentGuard
    ObjectReference jailMarker = CurrentJailMarker
    String jailName = CurrentJailName

    DebugMsg("Processing prisoner at jail: " + prisoner.GetDisplayName())

    ; Strip every SeverActions arrest package from both actors. Idempotent —
    ; safely no-ops any packages they don't currently hold (e.g. the dispatch
    ; packages on a guard who only ran same-cell flow). PrisonerSandBox is
    ; re-applied below if DisablePrisonerOnArrival is false.
    RemoveAllArrestPackages(guard)
    RemoveAllArrestPackages(prisoner)

    ; Clear prisoner's linked ref to guard (was used for follow). Don't blanket-
    ; clear via ClearAllDispatchLinkedRefs since SandboxAnchorKW is about to be
    ; re-set on the prisoner immediately below.
    SeverActionsNative.LinkedRef_Clear(prisoner, SeverActions_FollowTargetKW)

    ; Clear every reference alias the arrest / dispatch FSM uses.
    ClearAllArrestAliases()

    ; Update factions
    prisoner.RemoveFromFaction(SeverActions_Arrested)
    prisoner.AddToFaction(SeverActions_Jailed)

    ; Move prisoner to jail cell with verification
    ; Wave 3: replaced the Disable/Enable retry hack with MoveToNearestNavmesh.
    ; The previous loop disabled the prisoner, MoveTo'd, then re-enabled — heavy
    ; hammer that disrupts alias attachments and active package overrides. The
    ; navmesh snap (CommonLib v4.4+) reliably places the prisoner on a valid
    ; pathfinding tile in one engine call, eliminating the retry need.
    If jailMarker
        prisoner.MoveTo(jailMarker, 0.0, 0.0, 0.0)
        Utility.Wait(0.3)
        SeverActionsNative.Native_MoveToNearestNavmesh(prisoner, 0.0)
        Utility.Wait(0.2)

        Float distToJail = prisoner.GetDistance(jailMarker)
        ; Single retry only as defense-in-depth — if the navmesh snap landed us
        ; somewhere unexpected, redo the MoveTo + snap once.
        ; Wave 5: tolerance is now JailMarkerVerifyDistance (named property,
        ; default 500u) instead of a magic 500.0 sprinkled across the script.
        If distToJail > JailMarkerVerifyDistance
            DebugMsg("Initial MoveTo+navmesh placed prisoner " + distToJail + "u from marker — retrying")
            prisoner.MoveTo(jailMarker, 0.0, 0.0, 0.0)
            Utility.Wait(0.2)
            SeverActionsNative.Native_MoveToNearestNavmesh(prisoner, 0.0)
            Utility.Wait(0.3)
            distToJail = prisoner.GetDistance(jailMarker)
        EndIf

        If distToJail <= JailMarkerVerifyDistance
            DebugMsg("Moved prisoner to jail marker (distance: " + distToJail + ")")
        Else
            DebugMsg("WARNING: Failed to move prisoner to jail (distance: " + distToJail + ")")
        EndIf
    EndIf

    ; Change to prison clothes (use faction's jail outfit if available)
    Faction crimeFaction = GetCrimeFactionForGuard(guard)
    ChangeToJailClothes(prisoner, crimeFaction)

    ; Track this jailed NPC. T3-B: dropped the StorageUtil "backward-
    ; compat shim" — JailedNPCStore (set inside AddJailedNPC) is the
    ; sole source of truth, and all readers were migrated to
    ; Native_Jailed_GetMarker.
    AddJailedNPC(prisoner)

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
            SeverActionsNative.LinkedRef_Set(prisoner, jailMarker, SeverActions_SandboxAnchorKW)
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

    ; Release the SkyrimNet on-task lock so the guard becomes eligible for new
    ; arrest actions again. Pair to the AddToFaction in ArrestNPC_Internal.
    If SeverActions_DispatchFaction != None && guard.IsInFaction(SeverActions_DispatchFaction)
        guard.RemoveFromFaction(SeverActions_DispatchFaction)
    EndIf

    ; Clear the SkyrimNet busy lock on the guard. The prisoner's busy lock is
    ; intentionally LEFT in place — they're now in jail, and we don't want
    ; third-party plugins picking actions for them while they're behind bars.
    ; (The lock survives save/load via SkyrimNet's persistence; ReleasePrisoner
    ; and the free-from-jail paths clear it when the prisoner is released.)
    SeverActionsNative.Native_SkyrimNet_ClearActorBusy(guard)

    guard.EvaluatePackage()

    ; Direct narration for prisoner to react to being put in the cell
    String cellNarration = "*" + guard.GetDisplayName() + " locks " + prisoner.GetDisplayName() + " in a jail cell.*"
    SkyrimNetApi.DirectNarration(cellNarration, prisoner, guard)

    ; Register persistent event for SkyrimNet - prisoner delivered to jail
    String jailMessage = prisoner.GetDisplayName() + " has been jailed in " + jailName + "."
    SkyrimNetApi.RegisterPersistentEvent(jailMessage, prisoner, None)

    ; BUG-A5: clear persisted save/load recovery state — arrest is complete.
    ClearPersistedArrestState()
    ApproachStartTime = 0.0
    EscortStartTime = 0.0

    ; Wave 4 / Phase 1.4: transition the native session to kJailed=9 instead
    ; of ending it. The session must outlive jail arrival so that
    ; RestorePrisonerStats (called from ClearPrisonerCommonArtifacts at
    ; release time, well after this function returns) can still read the
    ; pre-arrest Aggression/Confidence stored on the session entry.
    ; kJailed has no watchdog timeout — release timing is driven by the
    ; jail-time scripts, not by session age. The session is finally ended
    ; in ClearPrisonerCommonArtifacts (post-RestorePrisonerStats).
    SeverActionsNative.Native_ArrestSession_UpdateState(prisoner, 9, 0)

    ; Wave 8 hotfix: SetActorArrested(false) here was the matched-pair to the
    ; SetArrested(true) in StartApproachPhase. Both calls are removed in the
    ; hotfix because the approach-phase set was triggering unwanted vanilla
    ; AI side effects (guards stopped pursuing, etc.). The native is still
    ; available but not auto-managed by the FSM.

    ; Clear state (do this last since we stored local copies)
    ClearArrestState()

    Debug.Notification(prisoner.GetDisplayName() + " has been jailed")
    DebugMsg("Arrest complete - prisoner delivered to " + jailName)
EndFunction

Function ChangeToJailClothes(Actor akPrisoner, Faction akCrimeFaction)
    {Strip prisoner and give them jail clothes using SetOutfit for persistence.
     Uses the faction's jail outfit if available, falls back to property.

     Suspends the outfit lock for the duration of the op so that if the
     prisoner is a registered follower (player committed a crime, was
     witnessed by a guard, got dispatched-arrested), the OutfitAlias
     enforcement loop doesn't fight our SetOutfit. SuspendOutfitLock is a
     cheap StorageUtil write — no-op for non-followers.}

    SeverActions_Outfit outfitSys = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Outfit
    If outfitSys
        outfitSys.SuspendOutfitLock(akPrisoner)
    EndIf

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
            ; T3-B: native source of truth on ArrestSession (v3).
            SeverActionsNativeExt.Native_ArrestSession_SetOriginalOutfit(akPrisoner, originalOutfit)
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

    If outfitSys
        outfitSys.ResumeOutfitLock(akPrisoner)
    EndIf
EndFunction

; =============================================================================
; JAIL LOOKUP - Determine jail from guard's crime faction
; =============================================================================

ObjectReference Function GetJailMarkerForGuard(Actor akGuard)
    {Get the interior jail cell marker based on guard's crime faction.
     Resolved natively via HoldResolver; falls back to Whiterun if no hold matches.}

    ObjectReference marker = SeverActionsNativeExt.Hold_GetJailMarker(akGuard)
    If marker != None
        Return marker
    EndIf
    DebugMsg("WARNING: Could not determine guard's hold, defaulting to Whiterun")
    Return JailMarker_Whiterun
EndFunction

String Function GetJailNameForGuard(Actor akGuard)
    {Get human-readable jail name for notifications. Native HoldResolver.}

    String name = SeverActionsNativeExt.Hold_GetJailName(akGuard)
    If name != ""
        Return name
    EndIf
    Return "jail"
EndFunction

; =============================================================================
; CANCEL / CLEANUP
; =============================================================================

Function CancelCurrentArrest()
    {Cancel the current arrest in progress}

    DebugMsg("Canceling current arrest")

    ; BUG-A1: always release any movement freeze first so the prisoner isn't
    ; left frozen if cancellation happens mid-approach.
    UnfreezePrisonerMovement()

    ; PR-C: cancel any pending ArrivalMonitor registration on the guard.
    ; Idempotent — no-op if we never registered or it already fired/auto-removed.
    If CurrentGuard
        SeverActionsNativeExt.Arrival_Cancel(CurrentGuard)
    EndIf

    If CurrentGuard
        ; Stop stuck tracking
        SeverActionsNativeExt.Stuck_StopTracking(CurrentGuard)

        ; Strip every SeverActions arrest package — covers the approach package,
        ; escort package, follow-player (state-4 plea), and any dispatch packages
        ; this same guard might also be carrying. Idempotent.
        RemoveAllArrestPackages(CurrentGuard)
        ; Wave 6.1: Clear any FollowTargetKW LinkedRef the guard may be carrying
        ; (set during state 4 plea; harmless to clear in any other state).
        SeverActionsNative.LinkedRef_Clear(CurrentGuard, SeverActions_FollowTargetKW)

        ; Release the SkyrimNet on-task lock — pair to the AddToFaction in
        ; ArrestNPC_Internal so the guard becomes eligible for new arrest
        ; actions after a cancel.
        If SeverActions_DispatchFaction != None && CurrentGuard.IsInFaction(SeverActions_DispatchFaction)
            CurrentGuard.RemoveFromFaction(SeverActions_DispatchFaction)
        EndIf

        ; Clear the SkyrimNet v6+ busy lock on the guard.
        SeverActionsNative.Native_SkyrimNet_ClearActorBusy(CurrentGuard)

        CurrentGuard.SheatheWeapon()
        CurrentGuard.EvaluatePackage()
    EndIf

    If CurrentPrisoner && ArrestState >= 2 && ArrestState != 5
        ; Prisoner was already arrested but is not in the transient "just
        ; arrived at jail" window — release them (ReleasePrisoner clears
        ; the SkyrimNet busy lock as part of its teardown).
        ;
        ; ArrestState 5 is the brief window between OnArrivedAtJail kicking
        ; off and full jail-faction setup completing. A cancel firing here
        ; would race ReleasePrisoner against OnArrivedAtJail, stripping
        ; SeverActions_Jailed from a prisoner who is logically already
        ; jailed. Leave the jail-finalize path to complete; OrderRelease
        ; / FreeNPC_Internal are the correct exits from state 5.
        ReleasePrisoner(CurrentPrisoner)
    ElseIf CurrentPrisoner
        ; Prisoner was inside the approach window (ArrestState 1), or is in
        ; the transient post-arrival window (state 5) where the jail-finalize
        ; path owns teardown. Either way ReleasePrisoner won't be called from
        ; here — clear the busy lock we set in ArrestNPC_Internal directly so
        ; third-party plugins regain action eligibility.
        SeverActionsNative.Native_SkyrimNet_ClearActorBusy(CurrentPrisoner)
    EndIf

    ; BUG-A5: clear persisted save/load recovery state.
    ClearPersistedArrestState()
    ApproachStartTime = 0.0
    EscortStartTime = 0.0

    ; Wave 4: close the native arrest session.
    If CurrentPrisoner != None
        SeverActionsNative.Native_ArrestSession_End(CurrentPrisoner)
    EndIf

    ; Clear dispatch state if active
    If DispatchPhase > 0
        CancelDispatch()
    EndIf

    ; Clear every reference alias the arrest / dispatch FSM uses.
    ClearAllArrestAliases()

    ClearArrestState()
EndFunction

Function ClearPrisonerCommonArtifacts(Actor akActor)
    {Cleanup work shared by ReleasePrisoner (mid-arrest release) and
     ReleaseFromJailCore (post-jail release). Everything here is safe to
     run idempotently regardless of which phase the prisoner is in:

       - Drops the two factions every arrest path puts the prisoner into
         (SeverActions_Jailed, dunPrisonerFaction).
       - Strips the sandbox package + clears the sandbox anchor LinkedRef.
       - Releases the SkyrimNet v6+ busy lock so third-party actions can
         target the actor again.
       - Removes the native JailedNPCStore record (idempotent — no-op if
         the prisoner wasn't yet in the roster). Plugs the leak that
         FreeNPC_Internal / FreePrisonerDirect used to have (B5 fix).
       - Restores Aggression / Confidence via the existing helper, plus
         depletable HealRate via RestoreAV.

     Does NOT handle the phase-specific work — that stays in each caller:
       - ReleasePrisoner: mid-arrest factions (WaitingArrest, Arrested),
         cuffs, follow-guard package, FollowTargetKW LinkedRef,
         post-release EvaluatePackage.
       - ReleaseFromJailCore: outfit restore, jail-marker StorageUtil
         clear.}

    akActor.RemoveFromFaction(SeverActions_Jailed)
    akActor.RemoveFromFaction(dunPrisonerFaction)

    If SeverActions_PrisonerSandBox
        ActorUtil.RemovePackageOverride(akActor, SeverActions_PrisonerSandBox)
    EndIf
    SeverActionsNative.LinkedRef_Clear(akActor, SeverActions_SandboxAnchorKW)

    SeverActionsNative.Native_SkyrimNet_ClearActorBusy(akActor)
    SeverActionsNativeExt.Native_Jailed_Remove(akActor)

    ; Restore normal stats. Aggression/Confidence are base attributes (not
    ; depletable resources), so RestoreAV doesn't work — we have to read the
    ; pre-arrest originals back from StorageUtil and SetAV via the helper.
    ; HealRate IS depletable, so RestoreAV is correct for it.
    RestorePrisonerStats(akActor)
    akActor.RestoreAV("HealRate", 100)

    ; Phase 1.4: end the native arrest session AFTER RestorePrisonerStats has
    ; read the pre-arrest Aggression/Confidence off the session entry.
    ; OnArrivedAtJail transitions to kJailed=9 (no watchdog) instead of
    ; ending the session, so jail-release paths reach here with the session
    ; still alive. Idempotent — no-op when there's no session (mid-arrest
    ; release paths that already ended it).
    SeverActionsNative.Native_ArrestSession_End(akActor)
EndFunction

Function ReleasePrisoner(Actor akPrisoner)
    {Release a prisoner mid-arrest — remove restraints, mid-arrest factions,
     and the follow-guard package. The common artifact cleanup (jailed
     faction, sandbox, busy lock, native jailed, stats) is shared with
     ReleaseFromJailCore via ClearPrisonerCommonArtifacts.}

    If akPrisoner == None
        Return
    EndIf

    DebugMsg("Releasing prisoner: " + akPrisoner.GetDisplayName())

    ; Mid-arrest factions — only on this path.
    akPrisoner.RemoveFromFaction(SeverActions_WaitingArrest)
    akPrisoner.RemoveFromFaction(SeverActions_Arrested)

    ; Remove restraints
    If SeverActions_PrisonerCuffs
        akPrisoner.UnequipItem(SeverActions_PrisonerCuffs, false, true)
        akPrisoner.RemoveItem(SeverActions_PrisonerCuffs, 1, true)
    EndIf

    ; Follow-guard package + linked ref are arrest-only artifacts.
    If SeverActions_FollowGuard_Prisoner
        ActorUtil.RemovePackageOverride(akPrisoner, SeverActions_FollowGuard_Prisoner)
    EndIf
    SeverActionsNative.LinkedRef_Clear(akPrisoner, SeverActions_FollowTargetKW)

    ClearPrisonerCommonArtifacts(akPrisoner)
    akPrisoner.EvaluatePackage()
EndFunction

Function ReleaseFromJailCore(Actor akTarget)
    {Core jail-release cleanup shared by FreeNPC_Internal and FreePrisonerDirect.
     The shared artifact teardown (factions, sandbox, busy lock, native
     jailed, stats) lives in ClearPrisonerCommonArtifacts; this function
     only adds the jail-specific work: restore the original outfit (with
     OutfitAlias suspended) and clear the jail-marker StorageUtil entry.
     Does NOT handle guard approach, animations, narration, tracking
     removal, or EvaluatePackage — callers do that.}

    ; T3-B critical fix: capture OriginalOutfit BEFORE ClearPrisoner-
    ; CommonArtifacts runs. That function calls Native_ArrestSession_End
    ; which erases the ArrestSession entry — reading the outfit after
    ; would always return None and the prisoner would never get their
    ; outfit restored. Same pre-clear capture pattern that the existing
    ; RestorePrisonerStats path uses for Aggression/Confidence.
    Outfit originalOutfit = SeverActionsNativeExt.Native_ArrestSession_GetOriginalOutfit(akTarget) as Outfit

    ClearPrisonerCommonArtifacts(akTarget)

    ; Restore original outfit if we stored one. Suspend/Resume the outfit
    ; lock around the op so OutfitAlias enforcement won't fight us if the
    ; released NPC is a registered follower.
    SeverActions_Outfit outfitSys = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Outfit
    If outfitSys
        outfitSys.SuspendOutfitLock(akTarget)
    EndIf
    If originalOutfit
        akTarget.SetOutfit(originalOutfit)
        DebugMsg("Restored original outfit for " + akTarget.GetDisplayName())
    ElseIf SeverActions_PrisonerRags
        akTarget.UnequipItem(SeverActions_PrisonerRags, false, true)
        akTarget.RemoveItem(SeverActions_PrisonerRags, 1, true)
    EndIf

    If outfitSys
        outfitSys.ResumeOutfitLock(akTarget)
    EndIf

    ; T3-B: jail marker lives in JailedNPCStore (cleared by the session-
    ; end flow elsewhere) and on ArrestSession (erased when the session
    ; ends). No manual unset needed.
EndFunction

Function RestorePrisonerStats(Actor akActor)
    {Restore Aggression and Confidence from the pre-arrest originals stored
     in StorageUtil during PerformArrest / ApplyDispatchArrestEffects.

     Aggression and Confidence are base actor attributes (0=Unaggressive
     ... 3=Frenzied / 0=Cowardly ... 4=Foolhardy) — they don't get
     "damaged" the way HealRate or stamina do, so RestoreAV does nothing
     useful for them. Only SetAV with the captured original value puts
     them back correctly. This bug used to leave released prisoners with
     Aggression=0 / Confidence=0 forever — bandits walked out docile,
     hostile NPCs walked out friendly to everyone.

     If no original was stored (legacy save before the fix, or NPC was
     never properly arrested via our flow), we fall back to sane vanilla
     defaults: Aggression=1 (Aggressive) and Confidence=2 (Average).}
    If !akActor
        Return
    EndIf

    ; Phase 1.4: prefer the native ArrestSession capture (cosave-backed,
    ; persists across save/load). Fall back to the legacy StorageUtil keys
    ; for saves that were mid-arrest at the v1→v2 cosave version bump —
    ; their session entry was dropped by the version-mismatch path so the
    ; native capture is empty, but the StorageUtil keys from the previous
    ; mod version may still be on the actor. Final fallback: vanilla
    ; defaults so a freshly-arrested actor without a capture still
    ; recovers to sensible AVs.
    Float origAggression = SeverActionsNative.Native_ArrestSession_GetOrigAggression(akActor)
    If origAggression < 0.0
        origAggression = StorageUtil.GetFloatValue(akActor, "SeverArrest_OrigAggression", -1.0)
        If origAggression >= 0.0
            StorageUtil.UnsetFloatValue(akActor, "SeverArrest_OrigAggression")
        EndIf
    EndIf
    If origAggression >= 0.0
        akActor.SetAV("Aggression", origAggression)
    Else
        akActor.SetAV("Aggression", 1)
    EndIf

    Float origConfidence = SeverActionsNative.Native_ArrestSession_GetOrigConfidence(akActor)
    If origConfidence < 0.0
        origConfidence = StorageUtil.GetFloatValue(akActor, "SeverArrest_OrigConfidence", -1.0)
        If origConfidence >= 0.0
            StorageUtil.UnsetFloatValue(akActor, "SeverArrest_OrigConfidence")
        EndIf
    EndIf
    If origConfidence >= 0.0
        akActor.SetAV("Confidence", origConfidence)
    Else
        akActor.SetAV("Confidence", 2)
    EndIf
EndFunction

; =============================================================================
; CROSS-SCRIPT ACCESSORS (Wave 5b)
; The dispatch + same-cell state vars below are script-local (not Auto
; properties) by design — they're runtime-only state, persisted via
; StorageUtil rather than VMAD. To let extracted sub-scripts (JudgmentScript,
; future Player extraction) read/mutate them without exposing them as Auto
; properties (which would balloon the save VMAD), we provide explicit
; getter/setter functions here. Keep this list narrow — only what
; sub-scripts actually need.
; =============================================================================

Actor Function GetDispatchGuard()
    Return DispatchGuard
EndFunction

Actor Function GetDispatchTarget()
    Return DispatchTarget
EndFunction

Actor Function GetDispatchSender()
    Return DispatchSender
EndFunction

Int Function GetDispatchPhase()
    Return DispatchPhase
EndFunction

Function SetCurrentArrestSlots(Actor akGuard, Actor akPrisoner, ObjectReference akJailMarker, String asJailName)
    {Set the four same-cell arrest slots in one call. Used by JudgmentScript
     when handing off from Phase 6 (judgment) to the same-cell escort pipeline.}
    CurrentGuard = akGuard
    CurrentPrisoner = akPrisoner
    CurrentJailMarker = akJailMarker
    CurrentJailName = asJailName
EndFunction

; =============================================================================

Function ClearArrestState()
    {Clear all tracking state}

    CurrentGuard = None
    CurrentPrisoner = None
    CurrentJailMarker = None
    CurrentJailName = ""
    ArrestState = 0
    ; Wave 6.1: clear plea-phase tracking so the next arrest gets a fresh
    ; single-attempt budget for AppealDuringEscort.
    EscortPleaStartTime = 0.0
    EscortPleaAttempted = false

    ; Phase 2.3a: tear down the native EscortPackageReapplier tracker
    ; alongside the rest of the FSM. Idempotent — no-op if not armed.
    SeverActionsNative.Native_EscortReapply_End()

    UnregisterForUpdate()
EndFunction

; =============================================================================
; CLEANUP HELPERS (Wave 5)
; Centralizes the package-strip and alias-clear patterns that were duplicated
; 5+ times each across CancelCurrentArrest / OnArrivedAtJail / CompleteDispatch
; / CancelDispatch / EndJudgment. Behavior is unchanged from the inline forms
; — these just consolidate the same RemovePackageOverride sequences into a
; single function so a future package addition only needs one edit.
; =============================================================================

Function RemoveAllArrestPackages(Actor akActor)
    {Strip every SeverActions arrest-related package from akActor. Idempotent:
     RemovePackageOverride is a no-op when the actor doesn't currently have
     the package, so we can call this on any actor without checking which
     packages they actually had.}

    If akActor == None
        Return
    EndIf

    If SeverActions_GuardApproachTarget
        ActorUtil.RemovePackageOverride(akActor, SeverActions_GuardApproachTarget)
    EndIf
    If SeverActions_GuardEscortPackage
        ActorUtil.RemovePackageOverride(akActor, SeverActions_GuardEscortPackage)
    EndIf
    If SeverActions_FollowGuard_Prisoner
        ActorUtil.RemovePackageOverride(akActor, SeverActions_FollowGuard_Prisoner)
    EndIf
    If SeverActions_PrisonerSandBox
        ActorUtil.RemovePackageOverride(akActor, SeverActions_PrisonerSandBox)
    EndIf
    If SeverActions_GuardFollowPlayer
        ActorUtil.RemovePackageOverride(akActor, SeverActions_GuardFollowPlayer)
    EndIf
    If SeverActions_DispatchTravel
        ActorUtil.RemovePackageOverride(akActor, SeverActions_DispatchTravel)
    EndIf
    If SeverActions_DispatchJog
        ActorUtil.RemovePackageOverride(akActor, SeverActions_DispatchJog)
    EndIf
    If SeverActions_DispatchWalk
        ActorUtil.RemovePackageOverride(akActor, SeverActions_DispatchWalk)
    EndIf
EndFunction

Function ClearAllArrestAliases()
    {Clear every reference alias used by the arrest / dispatch FSM. Safe to
     call from any cleanup path — ForceRefTo None on a quest alias is a
     no-op when nothing is currently filled.}

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
EndFunction

Function ReapplyEscortPackages(Actor akGuard, Actor akPrisoner, ObjectReference akJailMarker)
    {Atomically (re)apply the escort-phase packages: guard's GuardEscortPackage
     targeting JailDestination, prisoner's FollowGuard_Prisoner targeting the
     LinkedRef-managed guard. Used by StartEscortPhase, CheckEscortProgress
     per-tick re-apply, and RecoverActiveArrest after save/load.}

    If akGuard == None || akPrisoner == None || akJailMarker == None
        Return
    EndIf

    JailDestination.ForceRefTo(akJailMarker)

    If SeverActions_GuardEscortPackage
        ActorUtil.AddPackageOverride(akGuard, SeverActions_GuardEscortPackage, PackagePriority, 1)
        akGuard.EvaluatePackage()
    EndIf

    SeverActionsNative.LinkedRef_Set(akPrisoner, akGuard, SeverActions_FollowTargetKW)
    If SeverActions_FollowGuard_Prisoner
        ActorUtil.AddPackageOverride(akPrisoner, SeverActions_FollowGuard_Prisoner, PackagePriority, 1)
        akPrisoner.EvaluatePackage()
    EndIf
EndFunction

; =============================================================================
; BOUNTY API
; =============================================================================
;
; Wave 5b: AddBountyToPlayer_Internal moved to SeverActions_ArrestBounty.psc.
; The action YAML (addbountytoplayer.yaml) now points scriptName at that
; sub-script directly, so no thin-wrapper is needed here.
;
; The 9 tracked-bounty CRUD functions also moved. Internal callsites in this
; file delegate via BountyScript.GetTrackedBounty(...) etc. — see the
; BountyScript property declaration near the top.

Faction Function GetCrimeFactionForGuard(Actor akGuard)
    {Get the crime faction the guard belongs to. Native HoldResolver.}

    Return SeverActionsNativeExt.Hold_GetCrimeFaction(akGuard)
EndFunction

String Function GetHoldNameForGuard(Actor akGuard)
    {Get hold name for notifications. Native HoldResolver.}

    String name = SeverActionsNativeExt.Hold_GetHoldName(akGuard)
    If name != ""
        Return name
    EndIf
    Return "unknown hold"
EndFunction

; =============================================================================
; UTILITY
; =============================================================================

Function DebugMsg(String msg)
    Debug.Trace("SeverArrest: " + msg)
    ; Mirror to SeverActionsNative.log so the arrest FSM is observable for users
    ; who haven't enabled bPapyrusLog. The native side prefixes with [Arrest].
    SeverActionsNative.Native_Arrest_Log(msg)
    If EnableDebugMessages
        Debug.Notification("Arrest: " + msg)
    EndIf
EndFunction

Function ClearAllDispatchLinkedRefs(Actor akActor)
    {Clear linked refs for both dispatch keywords on an actor.
     Used during dispatch cleanup to ensure no stale linked refs remain.}
    If akActor != None
        SeverActionsNative.LinkedRef_Clear(akActor, SeverActions_FollowTargetKW)
        SeverActionsNative.LinkedRef_Clear(akActor, SeverActions_SandboxAnchorKW)
    EndIf
EndFunction

Function ClearDispatchState()
    {Reset all dispatch-related script variables to their defaults.
     Called by CompleteDispatch, CancelDispatch, and EndJudgment branches.}
    ; Wave 5b: judgment timer lives on JudgmentScript. Call BEFORE nulling
    ; DispatchSender/DispatchGuard so ResetState's busy-flag clear can still
    ; resolve the actor it needs to clear via GetDispatchSender/Guard. The
    ; field-null block below would otherwise leak the "judgment" busy flag
    ; on the sender (or guard, for player-sender dispatches) through the
    ; CancelDispatch path, permanently blocking is_busy-gated actions on
    ; that NPC until game restart.
    If JudgmentScript
        JudgmentScript.ResetState()
    EndIf

    ; Close the cosave ArrestSession entry for the dispatch target. Must
    ; happen BEFORE the DispatchTarget = None line below so we can still
    ; resolve the actor. Native_ArrestSession_End is idempotent (no-op when
    ; the entry doesn't exist), so it's safe to call on every cleanup path
    ; — including same-cell paths that close their own entry via a
    ; different code site.
    If DispatchTarget != None
        SeverActionsNative.Native_ArrestSession_End(DispatchTarget)
    EndIf

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
    DispatchEvidenceForm = None
    DispatchEvidenceName = ""
    DispatchReturnOffScreenCycle = 0
    DispatchReturnNarrated = false
    DispatchStuckGraceUntil = 0.0

    ; Container search state
    DispatchContainerCount = 0
    DispatchCurrentContainer = 0
    DispatchCurrentContainerRef = None
    DispatchContainerSearchStart = 0.0
    DispatchContainerSearchDuration = 0.0
    DispatchSearchSubPhase = 0
    DispatchEvidenceContainerIndex = -1
    DispatchPlayerPlantedFound = false

    ; Multi-evidence
    DispatchEvidenceForm2 = None
    DispatchEvidenceName2 = ""
    DispatchEvidenceForm3 = None
    DispatchEvidenceName3 = ""
    DispatchEvidenceQualityScore = 0
    DispatchContainersSearched = 0
    DispatchEvidenceSummary = ""

    ; Trespass suppression
    RestoreTrespass()
    DispatchHomeOwner = None
    DispatchOrigRelRankGuard = 0
    DispatchOrigRelRankPlayer = 0
    DispatchRelRankModified = false
EndFunction

Function ClearDeferredNarration()
    {Clear deferred evidence narration stored on a sender actor.
     Called when the narration fires (player approached sender) or sender dies.}
    If DeferredNarrationSender != None
        ; T1-D.3: single native call clears the per-sender entry AND
        ; auto-clears the deferred-sender singleton when it matches.
        SeverActionsNativeExt.Native_Arrest_ClearPendingEvidence(DeferredNarrationSender)
        DeferredNarrationSender = None
        DebugMsg("Cleared deferred narration state")
    EndIf
    ; PR-C: drop the player's ArrivalMonitor narration-witness registration.
    ; Idempotent — Arrival_Cancel is a no-op when nothing is registered.
    SeverActionsNativeExt.Arrival_Cancel(Game.GetPlayer())
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

    ; Mark guard busy via SkyrimNet's PublicAPI v6+ so cross-plugin actions
    ; (escort, follow, travel from any other mod) also exclude this guard for
    ; the duration of the dispatch. Cleared in CompleteDispatch / CancelDispatch.
    SeverActionsNative.Native_SkyrimNet_SetActorBusy(akGuard, "arrest")

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
    SeverActionsNativeExt.Stuck_StartTracking(akGuard)

    ; Initialize off-screen travel estimation (distance-based arrival time)
    SeverActionsNative.OffScreen_InitTracking(akGuard, akDestination, 0.5, 18.0)

    ; PR-D: register the guard with ArrivalMonitor for Phase-1 travel arrival.
    ; Fires when the guard closes to DispatchArrivalDistance of akDestination
    ; (target actor for arrest dispatch, home interior marker for home
    ; investigation). CheckDispatchPhase1_Travel still runs per-tick for the
    ; off-screen path (snapshot distance, OffScreen_CheckArrival, stale-snapshot
    ; redirect) and stuck escalation; only the loaded-same-area proximity
    ; transition is event-driven now.
    SeverActionsNativeExt.Arrival_Register(akGuard, akDestination, DispatchArrivalDistance, "dispatch_p1_arrived")

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

    ; Capture originals on the native ArrestSession entry before pacifying —
    ; same store/restore pattern as PerformArrest. Without this, dispatch-
    ; arrested NPCs would never recover their Aggression / Confidence on
    ; release. (Phase 1.4 migration: replaces the legacy StorageUtil keys.)
    SeverActionsNative.Native_ArrestSession_CaptureAVs(DispatchTarget, DispatchTarget.GetAV("Aggression"), DispatchTarget.GetAV("Confidence"))
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
    SeverActionsNative.LinkedRef_Set(DispatchTarget, DispatchGuard, SeverActions_FollowTargetKW)
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

; Wave 5b: StopPersuasionFollow moved to SeverActions_ArrestPlayer.psc
; alongside the rest of the persuasion FSM.

; =============================================================================
; TRACKED BOUNTY SYSTEM
; =============================================================================
;
; Wave 5b: the 8 tracked-bounty CRUD functions (GetBountyStorageKey,
; GetTrackedBounty, SetTrackedBounty, ModTrackedBounty, ClearTrackedBounty,
; ApplyTrackedBountyToVanilla, GetTrackedBountyForGuard) moved to
; SeverActions_ArrestBounty.psc. Internal callers in this file delegate via
; BountyScript.X — see the BountyScript property declaration at the top of
; the file. PrismaUI / MCM / external callers go straight to BountyScript.

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
        SeverActionsNative.LinkedRef_Set(akGuard, akTarget, SeverActions_FollowTargetKW)

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
        SeverActionsNative.LinkedRef_Clear(akGuard, SeverActions_FollowTargetKW)

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
    {Free all currently jailed NPCs (direct release, no guard approach).
     Snapshots the native roster before iterating so each FreePrisonerDirect
     call (which internally Native_Jailed_Removes through ReleasePrisoner) can
     mutate the store safely.}

    Actor[] roster = SeverActionsNativeExt.Native_Jailed_GetAll()
    Int count = roster.Length
    If count == 0
        DebugMsg("No prisoners to free")
        Return
    EndIf

    Int i = count - 1
    While i >= 0
        Actor prisoner = roster[i]
        If prisoner != None
            FreePrisonerDirect(prisoner)
        EndIf
        i -= 1
    EndWhile

    ; Belt-and-suspenders: defensively clear anything FreePrisonerDirect missed
    ; (e.g. an entry with a stale prisoner ref that ReleasePrisoner couldn't
    ; resolve). The pre-PR-B Papyrus array is also wiped here for migrated saves.
    SeverActionsNativeExt.Native_Jailed_RemoveAll()
    JailedNPCs = PapyrusUtil.ActorArray(0)
    DebugMsg("All prisoners freed")
EndFunction

; =============================================================================
; JAILED NPC TRACKING
; =============================================================================

Function MigrateJailedNPCsToNative()
    {One-shot migration of pre-PR-B saves: the Papyrus-side Actor[] JailedNPCs
     array was the source of truth before the native JailedNPCStore cosave existed.
     On the first OnPlayerLoadGame after the upgrade, if the array still has
     entries AND the native store is empty, seed native from the array and then
     wipe the array. Subsequent loads see Native_GetCount > 0 and skip the migration.}

    If JailedNPCs == None || JailedNPCs.Length == 0
        Return
    EndIf
    If SeverActionsNativeExt.Native_Jailed_GetCount() > 0
        ; Native already populated by an earlier post-PR-B save — drop the legacy array.
        JailedNPCs = PapyrusUtil.ActorArray(0)
        Return
    EndIf

    DebugMsg("Migrating " + JailedNPCs.Length + " jailed NPCs from Papyrus array to native store")
    Int i = 0
    Int migrated = 0
    While i < JailedNPCs.Length
        Actor prisoner = JailedNPCs[i]
        If prisoner != None && !prisoner.IsDead()
            ; T3-B fix: this is the legacy-save migration path. Native
            ; map may not yet have an entry for this prisoner, so check
            ; native FIRST then fall back to the StorageUtil key the
            ; old code wrote. Without the fallback, every pre-T3-B save
            ; loses its jail-marker data on migration.
            ObjectReference marker = SeverActionsNativeExt.Native_Jailed_GetMarker(prisoner)
            If marker == None
                marker = StorageUtil.GetFormValue(prisoner, "SeverActions_JailMarker") as ObjectReference
            EndIf
            ; Crime faction not stored in the legacy data — left as None on migration.
            ; The flag bit for "was Disabled" is also unrecoverable; default to 0.
            SeverActionsNativeExt.Native_Jailed_Add(prisoner, marker, None, 0)
            migrated += 1
        EndIf
        i += 1
    EndWhile
    JailedNPCs = PapyrusUtil.ActorArray(0)
    DebugMsg("Migration complete: " + migrated + " prisoners now tracked natively")
EndFunction

Function AddJailedNPC(Actor akNPC)
    {Add an NPC to the jailed roster. Native JailedNPCStore. Idempotent — re-
     adding overwrites the prior entry. Stores the jail marker and crime faction
     alongside so VerifyJailedNPCs and release paths can read them back.}

    If akNPC == None
        Return
    EndIf

    ObjectReference marker = SeverActionsNativeExt.Native_Jailed_GetMarker(akNPC)
    Faction crime = None
    Actor guardForCrime = CurrentGuard
    If guardForCrime
        crime = GetCrimeFactionForGuard(guardForCrime)
    EndIf
    Int flags = 0
    If DisablePrisonerOnArrival
        flags = 1
    EndIf
    SeverActionsNativeExt.Native_Jailed_Add(akNPC, marker, crime, flags)
    DebugMsg("Tracking jailed NPC: " + akNPC.GetDisplayName() + " (total: " + SeverActionsNativeExt.Native_Jailed_GetCount() + ")")
EndFunction

Function RemoveJailedNPC(Actor akNPC)
    {Remove an NPC from the jailed roster. Native JailedNPCStore.}

    If akNPC == None
        Return
    EndIf
    If SeverActionsNativeExt.Native_Jailed_Remove(akNPC)
        DebugMsg("Removed from jailed tracking: " + akNPC.GetDisplayName())
    EndIf
EndFunction

Actor[] Function GetJailedNPCs()
    {Get array of all currently jailed NPCs (native — capped at 128).}

    Return SeverActionsNativeExt.Native_Jailed_GetAll()
EndFunction

Int Function GetJailedCount()
    {Get count of jailed NPCs (native).}

    Return SeverActionsNativeExt.Native_Jailed_GetCount()
EndFunction

Bool Function IsNPCJailed(Actor akNPC)
    {O(1) check via native JailedNPCStore.}

    If akNPC == None
        Return false
    EndIf
    Return SeverActionsNativeExt.Native_Jailed_IsJailed(akNPC)
EndFunction

Function VerifyJailedNPCs()
    {Verify all jailed NPCs are actually at their jail markers.
     Called on game load to fix prisoners who got displaced during fast travel or time advancement.
     Reads from native JailedNPCStore — TESDeathEvent already pruned dead actors there,
     so no None/dead checks are needed beyond a defensive guard.}

    Actor[] roster = SeverActionsNativeExt.Native_Jailed_GetAll()
    Int count = roster.Length
    If count == 0
        Return
    EndIf

    DebugMsg("Verifying " + count + " jailed NPCs...")
    Int fixedCount = 0
    Int prunedCount = 0

    ; Two-pass: first prune None/dead entries (PapyrusUtil.RemoveActor returns
    ; a new array, so mutation-during-iteration is safe via re-fetch). Then
    ; verify positions on the survivors.
    Int p = JailedNPCs.Length - 1
    While p >= 0
        Actor pCandidate = JailedNPCs[p]
        If pCandidate == None || pCandidate.IsDead()
            JailedNPCs = PapyrusUtil.RemoveActor(JailedNPCs, pCandidate)
            prunedCount += 1
        EndIf
        p -= 1
    EndWhile

    If prunedCount > 0
        DebugMsg("Pruned " + prunedCount + " dead / invalid jailed NPCs from tracking")
    EndIf

    Int i = 0
    While i < count
        Actor prisoner = roster[i]
        If prisoner != None && !prisoner.IsDead()
            ObjectReference jailMarker = SeverActionsNativeExt.Native_Jailed_GetMarker(prisoner)
            If jailMarker == None
                ; Backward-compat: pre-T3-B saves may have only stored the
                ; marker in the SeverActions_JailMarker StorageUtil key
                ; (the dual-write shim retired in T3-B). Read it directly
                ; here as the last fallback so legacy saves can still
                ; verify and reposition stuck prisoners.
                jailMarker = StorageUtil.GetFormValue(prisoner, "SeverActions_JailMarker") as ObjectReference
            EndIf
            If jailMarker != None
                Float distance = prisoner.GetDistance(jailMarker)
                If distance > JailMarkerVerifyDistance
                    DebugMsg("Prisoner " + prisoner.GetDisplayName() + " is " + distance + " units from jail, fixing...")

                    prisoner.Disable()
                    Utility.Wait(0.1)
                    prisoner.MoveTo(jailMarker, 0.0, 0.0, 0.0)
                    Utility.Wait(0.1)
                    prisoner.Enable()

                    If SeverActions_PrisonerSandBox
                        SeverActionsNative.LinkedRef_Set(prisoner, jailMarker, SeverActions_SandboxAnchorKW)
                        ActorUtil.AddPackageOverride(prisoner, SeverActions_PrisonerSandBox, PackagePriority + 10, 1)
                        prisoner.EvaluatePackage()
                    EndIf

                    fixedCount += 1
                EndIf
            Else
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
;
; Wave 5b: the entire player-confrontation + persuasion FSM (~580 lines, 16
; functions, 9 state vars) moved to SeverActions_ArrestPlayer.psc. The action
; YAMLs (arrestplayer / acceptpersuasion / rejectpersuasion) point their
; scriptName at the new sub-script directly. PlayerScript drives its own
; OnUpdate so the persuasion timer + post-resist combat cleanup tick
; independently of this script's update loop.
;
; If you need a property/state from the player FSM externally, prefer the
; small public-query API on PlayerScript (IsPlayerInConfrontation /
; IsPlayerInPersuasion / CancelPlayerConfrontation). All other state is
; private to PlayerScript by design — same encapsulation that BountyScript
; and JudgmentScript follow.


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

    ; Anti-spam guard: reject if last dispatch was < 15 seconds ago.
    Float dispatchNow = Utility.GetCurrentRealTime()
    If LastDispatchSpamTime > 0.0 && (dispatchNow - LastDispatchSpamTime) < 15.0
        DebugMsg("Dispatch rejected: cooldown not elapsed (" + (dispatchNow - LastDispatchSpamTime) + "s)")
        Debug.Notification("Please wait before dispatching another guard")
        Return false
    EndIf
    LastDispatchSpamTime = dispatchNow

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

    ; Open a cosave ArrestSession entry so the PrismaUI arrests page can
    ; surface cross-cell dispatches alongside same-cell arrests. State 5 =
    ; kDispatch (per ArrestSessionStore.h); dispatchPhase=1 matches the
    ; FSM scalar set above. Flag 0 means "arrest dispatch" (not home
    ; investigation — see DispatchToInvestigateHome for the flag=1 variant).
    ObjectReference cosaveJailMarker = GetJailMarkerForGuard(akGuard)
    Faction cosaveCrimeFaction = GetCrimeFactionForGuard(akGuard)
    SeverActionsNative.Native_ArrestSession_Begin(target, akGuard, cosaveJailMarker, cosaveCrimeFaction, 5, 1, 0)

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
        ; Check player first — FindActorByName fuzzy-matches via Levenshtein,
        ; so a literal "Player" sentinel (sent by PrismaUI's authority picker)
        ; would otherwise match any NPC whose name contains "Player" (e.g.
        ; "Player Friend"). Match against either the actual player name OR
        ; the literal sentinel.
        Actor playerRef = Game.GetPlayer()
        If playerRef.GetDisplayName() == senderName || senderName == "Player" || senderName == "player"
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

    ; Anti-spam guard: reject if last dispatch was < 15 seconds ago.
    Float dispatchNow = Utility.GetCurrentRealTime()
    If LastDispatchSpamTime > 0.0 && (dispatchNow - LastDispatchSpamTime) < 15.0
        DebugMsg("Dispatch rejected: cooldown not elapsed (" + (dispatchNow - LastDispatchSpamTime) + "s)")
        Debug.Notification("Please wait before dispatching another guard")
        Return false
    EndIf
    LastDispatchSpamTime = dispatchNow

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

    ; Open a cosave ArrestSession entry — same shape as the arrest-dispatch
    ; site above. Flag bit 0 = home investigation, so the PrismaUI page can
    ; differentiate the row label / icon.
    ObjectReference cosaveHomeJailMarker = GetJailMarkerForGuard(akGuard)
    Faction cosaveHomeCrimeFaction = GetCrimeFactionForGuard(akGuard)
    SeverActionsNative.Native_ArrestSession_Begin(target, akGuard, cosaveHomeJailMarker, cosaveHomeCrimeFaction, 5, 1, 1)

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
        ; Check player first — FindActorByName fuzzy-matches via Levenshtein,
        ; so a literal "Player" sentinel would otherwise match any NPC whose
        ; name contains "Player" (e.g. "Player Friend"). Match against either
        ; the actual player name OR the literal sentinel.
        If playerRef.GetDisplayName() == senderName || senderName == "Player" || senderName == "player"
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
                Float requiredGameHours = travelDistCheck / GuardJogPerGameHour
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
            Float requiredReturnHours = returnDistCheck / GuardJogPerGameHour
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
        ; Wave 5b: Phase-6 routed to extracted JudgmentScript.
        If JudgmentScript
            JudgmentScript.CheckJudgmentProgress()
        EndIf
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
            Float travelTime = dist / GuardJogSpeed
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
    SeverActionsNativeExt.Stuck_StopTracking(DispatchGuard)

    ; Strip every active arrest package on the guard and clear linked refs.
    RemoveAllArrestPackages(DispatchGuard)
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
        SeverActionsNative.LinkedRef_Set(DispatchTarget, DispatchGuard, SeverActions_FollowTargetKW)
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
    SeverActionsNativeExt.Stuck_StartTracking(DispatchGuard)

    ; Initialize off-screen travel estimation for the return journey
    ; Use shorter bounds (0.25-12h) since return trips are typically shorter
    If DispatchReturnMarker != None
        SeverActionsNative.OffScreen_InitTracking(DispatchGuard, DispatchReturnMarker, 0.25, 12.0)
    EndIf

    DispatchPhase = 5
    SeverActionsNativeExt.Native_Arrest_SetDispatchPhase(DispatchGuard, DispatchPhase)
    SeverActionsNative.Native_ArrestSession_UpdateState(DispatchTarget, 5, 5)
    DispatchGuardOffScreen = false
    DispatchOffScreenStartTime = 0.0
    DispatchReturnOffScreenCycle = 0
    DispatchReturnNarrated = false

    ; PR-D: register ArrivalMonitor at the return destination. Fires when the
    ; loaded guard closes to DispatchArrivalDistance of DispatchReturnMarker.
    ; CheckDispatchPhase5_Return still runs per-tick for the off-screen tiered
    ; logic (interior-exit virtual door, OffScreen_CheckArrival, snapshot
    ; distance, tier-2 safety teleport) and on-screen stuck escalation; only
    ; the loaded-area proximity arrival is event-driven now.
    If DispatchReturnMarker != None
        SeverActionsNativeExt.Arrival_Register(DispatchGuard, DispatchReturnMarker, DispatchArrivalDistance, "dispatch_p5_arrived")
    EndIf

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
        SeverActionsNative.LinkedRef_Set(DispatchTarget, DispatchGuard, SeverActions_FollowTargetKW)
        Utility.Wait(0.2)
        If SeverActions_FollowGuard_Prisoner
            ActorUtil.AddPackageOverride(DispatchTarget, SeverActions_FollowGuard_Prisoner, PackagePriority, 1)
            DispatchTarget.EvaluatePackage()
        EndIf
    EndIf

    DispatchGuard.EvaluatePackage()

    ; Reset stuck tracking since position snapshot is stale after teleport
    SeverActionsNativeExt.Stuck_StopTracking(DispatchGuard)
    SeverActionsNativeExt.Stuck_StartTracking(DispatchGuard)

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
        Int departureStatus = SeverActionsNativeExt.Stuck_CheckDeparture(DispatchGuard, 100.0)
        If departureStatus == 2
            ; Guard hasn't moved in 30 seconds — soft recovery
            DebugMsg("Guard failed to depart — applying soft recovery")
            DispatchGuard.EvaluatePackage()
            ; Disable AI processing briefly and re-enable to break any animation lock
            DispatchGuard.SetDontMove(true)
            Utility.Wait(0.3)
            DispatchGuard.SetDontMove(false)
            DispatchGuard.EvaluatePackage()
            SeverActionsNativeExt.Stuck_ResetEscalation(DispatchGuard)
        EndIf
    EndIf

    ; Check stuck detection
    stuckLevel = SeverActionsNativeExt.Stuck_CheckStatus(DispatchGuard, UpdateInterval, 50.0)
    If stuckLevel >= 2
        DebugMsg("Guard stuck (level " + stuckLevel + "), nudging...")
        DispatchGuard.EvaluatePackage()
        If stuckLevel >= 3 && travelDest != None
            ; Severe stuck - leapfrog toward destination
            Float teleportDist = SeverActionsNativeExt.Stuck_GetTeleportDistance(DispatchGuard)
            DispatchGuard.MoveTo(travelDest, teleportDist, 0.0, 0.0, false)
            SeverActionsNativeExt.Stuck_ResetEscalation(DispatchGuard)

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

    ; Same cell check — for INTERIOR cells only. Interior cells are small enough
    ; that same-cell = arrived; ArrivalMonitor's distance threshold doesn't fire
    ; reliably inside cramped interiors so this fast-path stays.
    ; Loaded-area exterior arrivals (same/adjacent cells, both 3D loaded) are
    ; event-driven now via OnArrival(dispatch_p1_arrived) registered at
    ; InitDispatchCommon.
    Cell guardCell = DispatchGuard.GetParentCell()
    Cell destCell = travelDest.GetParentCell()
    If guardCell != None && destCell != None && guardCell == destCell && guardCell.IsInterior()
        If DispatchIsHomeInvestigation
            DebugMsg("Guard arrived inside home (same interior cell), transitioning to sandbox")
            TransitionToSandboxPhase()
            Return
        Else
            DebugMsg("Guard is in same interior cell as target, transitioning to approach phase")
            TransitionToApproachPhase()
            Return
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

    ; PR-D: loaded-area arrival is event-driven now — OnArrival(dispatch_p1_arrived)
    ; fires from native ArrivalMonitor registered in InitDispatchCommon. The
    ; per-tick path retains the off-screen logic above (snapshot distance,
    ; OffScreen_CheckArrival) since those operate on unloaded actors where
    ; ArrivalMonitor can't get reliable distance.

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
     and aliases are already filled. Just stop travel tracking and draw weapon.

     BUG-A4: RestoreGuardCombatAI is intentionally NOT called here. Restoring
     the guard's aggression before the prisoner is pacified can cause the guard
     to start combat with a still-hostile target instead of arresting them.
     RestoreGuardCombatAI now runs inside CheckDispatchPhase2_Approach AFTER
     ApplyDispatchArrestEffects has zeroed the target's aggression.

     BUG-A3: kicks off DispatchPhase2StartTime / DispatchTargetMovementFrozen
     so the new stuck-recovery logic in CheckDispatchPhase2_Approach has its
     timing baseline.}

    ; Stop stuck tracking for travel
    SeverActionsNativeExt.Stuck_StopTracking(DispatchGuard)

    ; Restore normal NPC-NPC collision — guard is near target
    SeverActionsNative.SetActorBumpable(DispatchGuard, true)

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
    SeverActionsNativeExt.Native_Arrest_SetDispatchPhase(DispatchGuard, DispatchPhase)
    SeverActionsNative.Native_ArrestSession_UpdateState(DispatchTarget, 5, 2)

    ; BUG-A3: timing + freeze flags for Phase 2 stuck/timeout recovery.
    DispatchPhase2StartTime = Utility.GetCurrentRealTime()
    DispatchTargetMovementFrozen = false

    ; BUG-A3: re-enable stuck tracking on the dispatch guard for the approach
    ; window. Phase 1 stopped it; without re-enabling, Phase 2 has no recovery.
    SeverActionsNativeExt.Stuck_StartTracking(DispatchGuard)

    ; PR-D: re-register the guard with ArrivalMonitor at the tighter Phase-2
    ; arrest threshold (ApproachDistance ~150u). Overwrites the Phase-1
    ; registration (one-actor-one-entry semantics). When the guard closes to
    ; ApproachDistance of the target, OnArrival fires the dispatch_p2_arrived
    ; branch and the arrest finalization runs.
    If DispatchTarget != None
        SeverActionsNativeExt.Arrival_Register(DispatchGuard, DispatchTarget, ApproachDistance, "dispatch_p2_arrived")
    EndIf

    RegisterForSingleUpdate(UpdateInterval)
EndFunction

Function CheckDispatchPhase2_Approach()
    {Phase 2: Guard approaching target in same cell for arrest.
     GetDistance returns 0 for unloaded actors, so we must guard against false positives.
     If neither is 3D loaded, use snapshot distance instead. If both unloaded and snapshot
     confirms proximity (or is unavailable), proceed — the guard was transitioned to Phase 2
     because same-cell was already confirmed.

     BUG-A3: previously had no stuck detection or timeout. If the target was running
     a sandbox / sweep package, the guard would chase forever. Now mirrors Phase 1's
     escalation (Stuck_CheckStatus → leapfrog → force teleport) and adds a hard
     timeout that fires ApplyDispatchArrestEffects in place after the timer elapses.

     BUG-A4: RestoreGuardCombatAI is now called here, after ApplyDispatchArrestEffects
     has zeroed the target's aggression. Restoring it earlier (in TransitionToApproachPhase)
     caused guards to enter combat with hostile targets instead of arresting them.}

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

    ; PR-D: loaded arrival is event-driven now via OnArrival(dispatch_p2_arrived)
    ; registered at TransitionToApproachPhase. For off-screen / unloaded cases
    ; where the snapshot distance confirmed proximity, fall through to the
    ; same arrest sequence (snapshot proximity won't trip ArrivalMonitor
    ; since it requires 3D-loaded distance).
    If !bothLoaded && dist >= 0.0 && dist <= ApproachDistance
        DebugMsg("Phase 2: off-screen snapshot arrival (dist=" + dist + ") — performing arrest")
        SeverActionsNativeExt.Stuck_StopTracking(DispatchGuard)
        If DispatchTargetMovementFrozen && DispatchTarget != None
            DispatchTarget.SetDontMove(false)
            DispatchTargetMovementFrozen = false
        EndIf
        If SeverActions_GuardApproachTarget
            ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_GuardApproachTarget)
        EndIf
        If SeverActions_DispatchJog
            ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchJog)
        EndIf
        ApplyDispatchArrestEffects()
        RestoreGuardCombatAI()
        DebugMsg("Dispatch arrest effects applied to " + DispatchTarget.GetDisplayName())
        String snapGuardName = DispatchGuard.GetDisplayName()
        String snapTargetName = DispatchTarget.GetDisplayName()
        String snapNarration = "*" + snapGuardName + " seizes " + snapTargetName + " and places them under arrest.*"
        SkyrimNetApi.DirectNarration(snapNarration, DispatchGuard, DispatchTarget)
        Debug.Notification(snapGuardName + " has arrested " + snapTargetName)
        StartDispatchReturnPhase()
        Return
    EndIf

    ; BUG-A3: freeze the target once close enough so their AI package doesn't
    ; oscillate them out of arrest range. Mirrors the same-cell A1 fix.
    If !DispatchTargetMovementFrozen && DispatchTarget != None && bothLoaded && dist > 0.0 && dist <= ApproachFreezeDistance
        DispatchTarget.SetDontMove(true)
        DispatchTargetMovementFrozen = true
        DebugMsg("Phase 2: target inside " + ApproachFreezeDistance + "u, freezing movement")
    EndIf

    ; BUG-A3: hard timeout. ApproachTimeout (30s default) is enough — guard is
    ; already in the same cell at this point; if they can't close the gap in
    ; that window, we force-teleport and proceed with the arrest in place.
    Float phase2Elapsed = Utility.GetCurrentRealTime() - DispatchPhase2StartTime
    If DispatchPhase2StartTime > 0.0 && phase2Elapsed >= ApproachTimeout
        DebugMsg("Phase 2 timeout (" + phase2Elapsed + "s) — force-teleporting guard for in-place arrest")
        SeverActionsNativeExt.Stuck_StopTracking(DispatchGuard)
        If DispatchTarget != None
            DispatchGuard.MoveTo(DispatchTarget, 100.0, 0.0, 0.0)
            ; Wave 3: navmesh snap after offset teleport
            SeverActionsNative.Native_MoveToNearestNavmesh(DispatchGuard, 0.0)
            Utility.Wait(0.3)
        EndIf
        ; Release movement freeze and proceed with the arrest path.
        If DispatchTargetMovementFrozen && DispatchTarget != None
            DispatchTarget.SetDontMove(false)
            DispatchTargetMovementFrozen = false
        EndIf

        If SeverActions_GuardApproachTarget
            ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_GuardApproachTarget)
        EndIf
        If SeverActions_DispatchJog
            ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchJog)
        EndIf

        ApplyDispatchArrestEffects()
        RestoreGuardCombatAI()

        String tgName = DispatchTarget.GetDisplayName()
        String gName = DispatchGuard.GetDisplayName()
        String forcedNarration = "*" + gName + " seizes " + tgName + " and places them under arrest.*"
        SkyrimNetApi.DirectNarration(forcedNarration, DispatchGuard, DispatchTarget)
        Debug.Notification(gName + " has arrested " + tgName)

        StartDispatchReturnPhase()
        Return
    EndIf

    ; BUG-A3: stuck escalation mirroring Phase 1.
    If bothLoaded
        Int stuckLevel = SeverActionsNativeExt.Stuck_CheckStatus(DispatchGuard, UpdateInterval, 50.0)
        If stuckLevel == 1
            DispatchGuard.EvaluatePackage()
        ElseIf stuckLevel == 2
            ; Leapfrog toward target
            Float teleportDist = SeverActionsNativeExt.Stuck_GetTeleportDistance(DispatchGuard)
            Float gx = DispatchGuard.GetPositionX()
            Float gy = DispatchGuard.GetPositionY()
            Float tx = DispatchTarget.GetPositionX()
            Float ty = DispatchTarget.GetPositionY()
            Float ddx = tx - gx
            Float ddy = ty - gy
            Float ddist2d = Math.sqrt(ddx * ddx + ddy * ddy)
            If ddist2d > 0.0
                Float mx = (ddx / ddist2d) * teleportDist
                Float my = (ddy / ddist2d) * teleportDist
                DispatchGuard.MoveTo(DispatchGuard, mx, my, 0.0)
                ; Wave 3: navmesh snap after relative leapfrog
                SeverActionsNative.Native_MoveToNearestNavmesh(DispatchGuard, 0.0)
                DispatchGuard.EvaluatePackage()
                DebugMsg("Phase 2: leapfrog guard " + teleportDist + " units toward target")
            EndIf
            SeverActionsNativeExt.Stuck_ResetEscalation(DispatchGuard)
        ElseIf stuckLevel >= 3
            DebugMsg("Phase 2: force teleporting guard near target")
            DispatchGuard.MoveTo(DispatchTarget, 200.0, 0.0, 0.0)
            ; Wave 3: navmesh snap after offset teleport
            SeverActionsNative.Native_MoveToNearestNavmesh(DispatchGuard, 0.0)
            Utility.Wait(0.3)
            DispatchGuard.EvaluatePackage()
            SeverActionsNativeExt.Stuck_ResetEscalation(DispatchGuard)
        EndIf
    EndIf

    RegisterForSingleUpdate(UpdateInterval)
EndFunction

Function TransitionToSandboxPhase()
    {Transition to Phase 3: Guard searches target's home container-by-container.
     On-screen: Guard walks to each container, activates it, searches, then moves to next.
     Off-screen: Evidence selected from pool, search simulated with timer.
     Two-pass system: First checks for player-planted evidence, then falls back to spawning.}

    ; Stop stuck tracking for travel
    SeverActionsNativeExt.Stuck_StopTracking(DispatchGuard)

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

    ; Suppress trespass reactions from homeowner
    SuppressTrespass()

    String guardName = DispatchGuard.GetDisplayName()
    String targetName = ""
    If DispatchTarget != None
        targetName = DispatchTarget.GetDisplayName()
    EndIf

    DispatchPhase = 3
    SeverActionsNativeExt.Native_Arrest_SetDispatchPhase(DispatchGuard, DispatchPhase)
    SeverActionsNative.Native_ArrestSession_UpdateState(DispatchTarget, 5, 3)

    Bool playerWatching = DispatchGuard.Is3DLoaded()

    If playerWatching
        ; === ON-SCREEN: Container-by-container search ===
        DebugMsg("Phase 3: On-screen container search beginning")

        ; Scan cell for searchable containers
        DispatchContainerCount = SeverActionsNative.FindSearchContainers(DispatchGuard, 3000.0)
        DebugMsg("Found " + DispatchContainerCount + " searchable containers in cell")

        If DispatchContainerCount == 0
            ; No containers found — fall back to old sandbox behavior
            DebugMsg("No containers found, falling back to sandbox + evidence generation")
            FallbackSandboxSearch(guardName, targetName)
            Return
        EndIf

        ; === PASS 1: Pre-scan all containers for player-planted evidence ===
        DispatchPlayerPlantedFound = false
        DispatchEvidenceContainerIndex = -1
        Int i = 0
        While i < DispatchContainerCount
            ObjectReference containerRef = SeverActionsNative.GetSearchContainer(i)
            If containerRef != None
                Form plantedEvidence = SeverActionsNative.ScanContainerForEvidence(containerRef, DispatchInvestigationReason)
                If plantedEvidence != None && !DispatchPlayerPlantedFound
                    ; Found player-planted evidence!
                    DispatchPlayerPlantedFound = true
                    DispatchEvidenceContainerIndex = i
                    DispatchEvidenceForm = plantedEvidence
                    DispatchEvidenceName = plantedEvidence.GetName()
                    DebugMsg("Pass 1: Found player-planted evidence '" + DispatchEvidenceName + "' in container " + i)
                EndIf
            EndIf
            i += 1
        EndWhile

        ; === PASS 2: If no player evidence, select from pool and plant in last container ===
        If !DispatchPlayerPlantedFound
            String evidencePoolResult = SeverActionsNative.SelectEvidenceFromPool(DispatchInvestigationReason, DispatchTarget)
            Int evidenceCount = SeverActionsNative.GetEvidenceCount()
            DebugMsg("Pass 2: Selected " + evidenceCount + " evidence items from pool")

            ; Primary evidence (always present)
            If evidenceCount >= 1
                DispatchEvidenceForm = SeverActionsNative.GetEvidenceAtIndex(0) as Form
                If DispatchEvidenceForm != None
                    DispatchEvidenceName = DispatchEvidenceForm.GetName()
                EndIf
            EndIf

            ; Secondary evidence (rare tier, 30% chance)
            If evidenceCount >= 2
                DispatchEvidenceForm2 = SeverActionsNative.GetEvidenceAtIndex(1) as Form
                If DispatchEvidenceForm2 != None
                    DispatchEvidenceName2 = DispatchEvidenceForm2.GetName()
                EndIf
            EndIf

            ; Tertiary evidence (damning tier, 10% chance)
            If evidenceCount >= 3
                DispatchEvidenceForm3 = SeverActionsNative.GetEvidenceAtIndex(2) as Form
                If DispatchEvidenceForm3 != None
                    DispatchEvidenceName3 = DispatchEvidenceForm3.GetName()
                EndIf
            EndIf

            ; Plant evidence in the LAST container (builds tension)
            DispatchEvidenceContainerIndex = DispatchContainerCount - 1
            ObjectReference plantTarget = SeverActionsNative.GetSearchContainer(DispatchEvidenceContainerIndex)
            If plantTarget != None && DispatchEvidenceForm != None
                SeverActionsNative.PlantEvidenceInContainer(plantTarget, DispatchEvidenceForm, 1)
                If DispatchEvidenceForm2 != None
                    SeverActionsNative.PlantEvidenceInContainer(plantTarget, DispatchEvidenceForm2, 1)
                EndIf
                If DispatchEvidenceForm3 != None
                    SeverActionsNative.PlantEvidenceInContainer(plantTarget, DispatchEvidenceForm3, 1)
                EndIf
                DebugMsg("Planted evidence in container " + DispatchEvidenceContainerIndex)
            EndIf
        EndIf

        ; Narration: guard enters and looks around
        String narration = "*" + guardName + " enters " + targetName + "'s home and begins a methodical search, eyes scanning the room.*"
        SkyrimNetApi.DirectNarration(narration, DispatchGuard, DispatchTarget)

        ; Brief entry scan pause (5 seconds) then start searching containers
        DispatchCurrentContainer = 0
        DispatchSearchSubPhase = 0
        DispatchSandboxStartTime = Utility.GetCurrentRealTime()
        DispatchSandboxDuration = 5.0  ; Entry scan duration

        RegisterForSingleUpdate(UpdateInterval)

    Else
        ; === OFF-SCREEN: Simulate search with expanded evidence pool ===
        DebugMsg("Phase 3: Off-screen search — simulating with timer")

        ; Select evidence from expanded pool
        String evidencePoolResult = SeverActionsNative.SelectEvidenceFromPool(DispatchInvestigationReason, DispatchTarget)
        Int evidenceCount = SeverActionsNative.GetEvidenceCount()
        DebugMsg("Off-screen: Selected " + evidenceCount + " evidence items from pool")

        ; Store evidence
        If evidenceCount >= 1
            DispatchEvidenceForm = SeverActionsNative.GetEvidenceAtIndex(0) as Form
            If DispatchEvidenceForm != None
                DispatchEvidenceName = DispatchEvidenceForm.GetName()
                DispatchGuard.AddItem(DispatchEvidenceForm, 1, true)
            EndIf
        EndIf
        If evidenceCount >= 2
            DispatchEvidenceForm2 = SeverActionsNative.GetEvidenceAtIndex(1) as Form
            If DispatchEvidenceForm2 != None
                DispatchEvidenceName2 = DispatchEvidenceForm2.GetName()
                DispatchGuard.AddItem(DispatchEvidenceForm2, 1, true)
            EndIf
        EndIf
        If evidenceCount >= 3
            DispatchEvidenceForm3 = SeverActionsNative.GetEvidenceAtIndex(2) as Form
            If DispatchEvidenceForm3 != None
                DispatchEvidenceName3 = DispatchEvidenceForm3.GetName()
                DispatchGuard.AddItem(DispatchEvidenceForm3, 1, true)
            EndIf
        EndIf

        ; Build evidence summary and register event
        BuildEvidenceSummary(targetName)

        If DispatchEvidenceForm != None
            String eventMsg = guardName + " found evidence at " + targetName + "'s home: " + DispatchEvidenceSummary
            SkyrimNetApi.RegisterPersistentEvent(eventMsg, DispatchGuard, DispatchTarget)
        Else
            DebugMsg("Off-screen: No evidence generated - guard returning empty-handed")
        EndIf

        ; Simulate search duration (20-45 seconds)
        DispatchSandboxStartTime = Utility.GetCurrentRealTime()
        DispatchSandboxDuration = Utility.RandomFloat(20.0, 45.0)
        DebugMsg("Off-screen search simulated for " + DispatchSandboxDuration + " seconds")

        RegisterForSingleUpdate(UpdateInterval)
    EndIf
EndFunction

Function FallbackSandboxSearch(String guardName, String targetName)
    {Fallback when no containers are found in cell. Uses old sandbox + evidence generation.}

    ; Set up sandbox anchor
    ObjectReference sandboxAnchor = DispatchGuard as ObjectReference
    If DispatchHomeMarker != None
        sandboxAnchor = DispatchHomeMarker
    EndIf
    SeverActionsNative.LinkedRef_Set(DispatchGuard, sandboxAnchor, SeverActions_SandboxAnchorKW)

    If SeverActions_PrisonerSandBox
        ActorUtil.AddPackageOverride(DispatchGuard, SeverActions_PrisonerSandBox, PackagePriority, 1)
        DispatchGuard.EvaluatePackage()
    EndIf
    If SeverActions_PrisonerSandBox
        SeverActionsNative.RegisterSandboxUser(DispatchGuard, SeverActions_PrisonerSandBox, 2000.0)
    EndIf

    ; Generate evidence from pool (no containers to search)
    String evidencePoolResult = SeverActionsNative.SelectEvidenceFromPool(DispatchInvestigationReason, DispatchTarget)
    Int evidenceCount = SeverActionsNative.GetEvidenceCount()
    If evidenceCount >= 1
        DispatchEvidenceForm = SeverActionsNative.GetEvidenceAtIndex(0) as Form
        If DispatchEvidenceForm != None
            DispatchEvidenceName = DispatchEvidenceForm.GetName()
        EndIf
    EndIf

    ; Use sandbox timer, then collect evidence at end
    DispatchSandboxStartTime = Utility.GetCurrentRealTime()
    DispatchSandboxDuration = Utility.RandomFloat(15.0, 30.0)
    DispatchContainerCount = 0  ; Signal fallback mode

    String narration = "*" + guardName + " begins searching " + targetName + "'s home, looking through belongings for evidence.*"
    SkyrimNetApi.DirectNarration(narration, DispatchGuard, DispatchTarget)

    RegisterForSingleUpdate(UpdateInterval)
EndFunction

Function CheckDispatchPhase3_Sandbox()
    {Phase 3: Guard searching target's home.
     On-screen: Sequential container search with walking, activation, and evidence discovery.
     Off-screen: Timer-based simulation.
     Fallback (no containers): Simple sandbox timer.}

    Bool playerWatching = DispatchGuard.Is3DLoaded()

    ; === FALLBACK MODE: No containers, using old sandbox timer ===
    If DispatchContainerCount == 0
        Float elapsed = Utility.GetCurrentRealTime() - DispatchSandboxStartTime
        If elapsed >= DispatchSandboxDuration
            DebugMsg("Fallback sandbox complete, collecting evidence")

            ; Cleanup sandbox
            SeverActionsNative.UnregisterSandboxUser(DispatchGuard)
            If SeverActions_PrisonerSandBox
                ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_PrisonerSandBox)
            EndIf
            SeverActionsNative.LinkedRef_Clear(DispatchGuard, SeverActions_SandboxAnchorKW)

            ; Add evidence to guard
            If DispatchEvidenceForm != None
                DispatchGuard.AddItem(DispatchEvidenceForm, 1, true)
                BuildEvidenceSummary(DispatchTarget.GetDisplayName())
                Debug.Notification(DispatchGuard.GetDisplayName() + " collected evidence: " + DispatchEvidenceName)
            EndIf

            TransitionToEvidenceComplete()
            Return
        EndIf
        RegisterForSingleUpdate(UpdateInterval)
        Return
    EndIf

    ; === OFF-SCREEN MODE: Timer simulation ===
    If !playerWatching
        Float elapsed = Utility.GetCurrentRealTime() - DispatchSandboxStartTime
        If elapsed >= DispatchSandboxDuration
            DebugMsg("Off-screen search timer complete")
            TransitionToEvidenceComplete()
            Return
        EndIf
        RegisterForSingleUpdate(UpdateInterval)
        Return
    EndIf

    ; === ON-SCREEN: Container-by-container search ===

    ; Entry scan pause (first 5 seconds — guard looks around)
    Float elapsed = Utility.GetCurrentRealTime() - DispatchSandboxStartTime
    If DispatchCurrentContainer == 0 && DispatchSearchSubPhase == 0 && elapsed < 5.0
        RegisterForSingleUpdate(UpdateInterval)
        Return
    EndIf

    ; Handle current container search sub-phases
    If DispatchSearchSubPhase == 0
        ; Sub-phase 0: Start walking to next container
        If DispatchCurrentContainer >= DispatchContainerCount
            ; All containers searched — finalize
            DebugMsg("All " + DispatchContainerCount + " containers searched, finalizing")
            TransitionToEvidenceComplete()
            Return
        EndIf

        ; GRACEFUL FALLBACK: If player left mid-search, complete remaining instantly
        If !DispatchGuard.Is3DLoaded()
            DebugMsg("Guard went off-screen mid-search, completing remaining containers instantly")
            CompleteRemainingContainersInstantly()
            TransitionToEvidenceComplete()
            Return
        EndIf

        ObjectReference containerRef = SeverActionsNative.GetSearchContainer(DispatchCurrentContainer)
        If containerRef == None
            DebugMsg("Container " + DispatchCurrentContainer + " is None, skipping")
            DispatchCurrentContainer += 1
            RegisterForSingleUpdate(UpdateInterval)
            Return
        EndIf

        DispatchCurrentContainerRef = containerRef
        DebugMsg("Walking guard to container " + DispatchCurrentContainer + " of " + DispatchContainerCount)

        ; Point travel alias at the container and apply travel package
        If DispatchTravelDestination != None
            DispatchTravelDestination.ForceRefTo(containerRef)
        EndIf
        If SeverActions_DispatchTravel
            ActorUtil.AddPackageOverride(DispatchGuard, SeverActions_DispatchTravel, PackagePriority, 1)
            DispatchGuard.EvaluatePackage()
        EndIf

        DispatchSearchSubPhase = 1
        DispatchContainerSearchStart = Utility.GetCurrentRealTime()
        RegisterForSingleUpdate(UpdateInterval)

    ElseIf DispatchSearchSubPhase == 1
        ; Sub-phase 1: Guard walking to container — check arrival
        If DispatchCurrentContainerRef == None
            DispatchSearchSubPhase = 0
            DispatchCurrentContainer += 1
            RegisterForSingleUpdate(UpdateInterval)
            Return
        EndIf

        Float dist = DispatchGuard.GetDistance(DispatchCurrentContainerRef)

        If dist <= 200.0
            ; Guard arrived at container — start searching
            DebugMsg("Guard arrived at container " + DispatchCurrentContainer + " (dist=" + dist + ")")

            ; Remove travel package
            If SeverActions_DispatchTravel
                ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchTravel)
            EndIf
            If DispatchTravelDestination != None
                DispatchTravelDestination.Clear()
            EndIf

            ; Play search animation — activate container (opens it visually)
            DispatchCurrentContainerRef.Activate(DispatchGuard)
            Debug.SendAnimationEvent(DispatchGuard, "IdlePickupFromTableStart")

            ; Set random search duration for this container
            DispatchContainerSearchDuration = Utility.RandomFloat(8.0, 12.0)
            DispatchContainerSearchStart = Utility.GetCurrentRealTime()
            DispatchSearchSubPhase = 2
            DispatchContainersSearched += 1

            RegisterForSingleUpdate(UpdateInterval)

        Else
            ; Still walking — check for stuck (timeout after 15 seconds)
            Float walkElapsed = Utility.GetCurrentRealTime() - DispatchContainerSearchStart
            If walkElapsed > 15.0
                DebugMsg("Guard stuck walking to container " + DispatchCurrentContainer + ", skipping")
                If SeverActions_DispatchTravel
                    ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchTravel)
                EndIf
                If DispatchTravelDestination != None
                    DispatchTravelDestination.Clear()
                EndIf
                DispatchSearchSubPhase = 0
                DispatchCurrentContainer += 1
            EndIf
            RegisterForSingleUpdate(UpdateInterval)
        EndIf

    ElseIf DispatchSearchSubPhase == 2
        ; Sub-phase 2: Guard searching container — wait for duration
        Float searchElapsed = Utility.GetCurrentRealTime() - DispatchContainerSearchStart

        If searchElapsed >= DispatchContainerSearchDuration
            ; Search duration elapsed — check for evidence
            String guardName = DispatchGuard.GetDisplayName()
            String targetName = ""
            If DispatchTarget != None
                targetName = DispatchTarget.GetDisplayName()
            EndIf
            String containerDesc = SeverActionsNative.GetContainerDescription(DispatchCurrentContainerRef)

            If DispatchCurrentContainer == DispatchEvidenceContainerIndex
                ; === THIS IS THE EVIDENCE CONTAINER ===
                DebugMsg("EVIDENCE FOUND in container " + DispatchCurrentContainer + "!")

                ; Remove evidence from container and add to guard
                If DispatchEvidenceForm != None
                    SeverActionsNative.RemoveEvidenceFromContainer(DispatchCurrentContainerRef, DispatchGuard, DispatchEvidenceForm, 1)
                    DispatchEvidenceQualityScore += SeverActionsNative.ScoreEvidenceQuality(DispatchEvidenceForm, DispatchCurrentContainerRef, DispatchInvestigationReason)
                EndIf
                If DispatchEvidenceForm2 != None
                    SeverActionsNative.RemoveEvidenceFromContainer(DispatchCurrentContainerRef, DispatchGuard, DispatchEvidenceForm2, 1)
                    DispatchEvidenceQualityScore += SeverActionsNative.ScoreEvidenceQuality(DispatchEvidenceForm2, DispatchCurrentContainerRef, DispatchInvestigationReason)
                EndIf
                If DispatchEvidenceForm3 != None
                    SeverActionsNative.RemoveEvidenceFromContainer(DispatchCurrentContainerRef, DispatchGuard, DispatchEvidenceForm3, 1)
                    DispatchEvidenceQualityScore += SeverActionsNative.ScoreEvidenceQuality(DispatchEvidenceForm3, DispatchCurrentContainerRef, DispatchInvestigationReason)
                EndIf

                ; Play discovery animation
                Debug.SendAnimationEvent(DispatchGuard, "IdlePickupFromTableStart")

                ; Build evidence summary with container context
                BuildEvidenceSummary(targetName)

                ; Narrate the discovery
                String narration = "*" + guardName + " searches " + containerDesc + " and discovers " + DispatchEvidenceSummary + ", tucking the evidence away.*"
                SkyrimNetApi.DirectNarration(narration, DispatchGuard, DispatchTarget)

                String eventMsg = guardName + " found evidence at " + targetName + "'s home: " + DispatchEvidenceSummary
                SkyrimNetApi.RegisterPersistentEvent(eventMsg, DispatchGuard, DispatchTarget)

                Debug.Notification(guardName + " found evidence: " + DispatchEvidenceName)

            Else
                ; === NOTHING FOUND — tension building ===
                DebugMsg("Nothing found in container " + DispatchCurrentContainer)

                String narration = "*" + guardName + " searches " + containerDesc + " but finds nothing suspicious.*"
                SkyrimNetApi.DirectNarration(narration, DispatchGuard, DispatchTarget)
            EndIf

            ; Move to next container
            DispatchSearchSubPhase = 0
            DispatchCurrentContainer += 1
            RegisterForSingleUpdate(UpdateInterval + 1.0)  ; Brief pause between containers
        Else
            RegisterForSingleUpdate(UpdateInterval)
        EndIf
    EndIf
EndFunction

Function CompleteRemainingContainersInstantly()
    {Complete remaining container searches instantly when player leaves mid-search.
     Evidence is still collected but no walking/animation occurs.}

    If DispatchEvidenceForm != None && DispatchCurrentContainer <= DispatchEvidenceContainerIndex
        ; Evidence container hasn't been reached yet — add evidence to guard directly
        DispatchGuard.AddItem(DispatchEvidenceForm, 1, true)
        If DispatchEvidenceForm2 != None
            DispatchGuard.AddItem(DispatchEvidenceForm2, 1, true)
        EndIf
        If DispatchEvidenceForm3 != None
            DispatchGuard.AddItem(DispatchEvidenceForm3, 1, true)
        EndIf

        ; Score evidence generically (no container context since off-screen)
        DispatchEvidenceQualityScore += SeverActionsNative.ScoreEvidenceQuality(DispatchEvidenceForm, None, DispatchInvestigationReason)

        String targetName = ""
        If DispatchTarget != None
            targetName = DispatchTarget.GetDisplayName()
        EndIf
        BuildEvidenceSummary(targetName)

        String guardName = DispatchGuard.GetDisplayName()
        String eventMsg = guardName + " found evidence at " + targetName + "'s home: " + DispatchEvidenceSummary
        SkyrimNetApi.RegisterPersistentEvent(eventMsg, DispatchGuard, DispatchTarget)
    EndIf

    DispatchContainersSearched = DispatchContainerCount
    DebugMsg("Completed remaining containers instantly (off-screen fallback)")
EndFunction

Function TransitionToEvidenceComplete()
    {Transition from Phase 3 search to Phase 4 (simplified).
     Evidence was already collected during the container search.
     This now handles cleanup and starts the return phase.}

    ; Cleanup any remaining packages
    If SeverActions_DispatchTravel
        ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchTravel)
    EndIf
    If DispatchTravelDestination != None
        DispatchTravelDestination.Clear()
    EndIf

    ; Restore trespass
    RestoreTrespass()

    DispatchPhase = 4
    SeverActionsNativeExt.Native_Arrest_SetDispatchPhase(DispatchGuard, DispatchPhase)
    SeverActionsNative.Native_ArrestSession_UpdateState(DispatchTarget, 5, 4)

    ; Short pause then start return
    Utility.Wait(1.0)
    StartDispatchReturnPhase()
EndFunction

Function CheckDispatchPhase4_Evidence()
    {Phase 4: Evidence already collected during Phase 3 search.
     This phase now just ensures the return starts.
     Kept for save/load recovery — if player loads mid-Phase4, just start return.}

    DebugMsg("Phase 4: Evidence collection complete (handled in Phase 3), starting return")
    StartDispatchReturnPhase()
EndFunction

Function BuildEvidenceSummary(String targetName)
    {Build a human-readable evidence summary string from the collected evidence.
     Stored in DispatchEvidenceSummary for use in prompts and narration.}

    DispatchEvidenceSummary = ""

    If DispatchEvidenceName != ""
        DispatchEvidenceSummary = DispatchEvidenceName
    EndIf

    If DispatchEvidenceName2 != ""
        If DispatchEvidenceSummary != ""
            DispatchEvidenceSummary += " and " + DispatchEvidenceName2
        Else
            DispatchEvidenceSummary = DispatchEvidenceName2
        EndIf
    EndIf

    If DispatchEvidenceName3 != ""
        If DispatchEvidenceSummary != ""
            DispatchEvidenceSummary += " and " + DispatchEvidenceName3
        Else
            DispatchEvidenceSummary = DispatchEvidenceName3
        EndIf
    EndIf

    If DispatchEvidenceSummary == ""
        DispatchEvidenceSummary = "nothing of note"
    EndIf

    DebugMsg("Evidence summary: " + DispatchEvidenceSummary + " (quality: " + DispatchEvidenceQualityScore + ")")
EndFunction

Function SuppressTrespass()
    {Temporarily make the guard (and player if present) an ally of the homeowner
     to prevent trespass reactions during the home search.}

    DispatchHomeOwner = DispatchTarget
    If DispatchHomeOwner == None
        Return
    EndIf

    ; Make guard an ally of homeowner — allies don't trigger trespass
    DispatchOrigRelRankGuard = DispatchGuard.GetRelationshipRank(DispatchHomeOwner)
    DispatchGuard.SetRelationshipRank(DispatchHomeOwner, 3)

    ; If player is present, make them an ally too. Only set the player flag
    ; if we ACTUALLY captured a value — otherwise RestoreTrespass would clobber
    ; the player's relationship-to-homeowner to the default 0 on the restore
    ; path, since DispatchOrigRelRankPlayer starts at 0.
    Actor playerRef = Game.GetPlayer()
    If playerRef.Is3DLoaded()
        DispatchOrigRelRankPlayer = playerRef.GetRelationshipRank(DispatchHomeOwner)
        playerRef.SetRelationshipRank(DispatchHomeOwner, 3)
        DispatchPlayerRelRankModified = true
    EndIf

    DispatchRelRankModified = true
    DebugMsg("Trespass suppressed: guard and player set as allies of " + DispatchHomeOwner.GetDisplayName())
EndFunction

Function RestoreTrespass()
    {Restore original relationship ranks after the home search is complete.}

    If !DispatchRelRankModified || DispatchHomeOwner == None
        Return
    EndIf

    If DispatchGuard != None
        DispatchGuard.SetRelationshipRank(DispatchHomeOwner, DispatchOrigRelRankGuard)
    EndIf

    ; Only restore the player rank if SuppressTrespass actually captured one
    ; (i.e. player was 3D-loaded at the time). Otherwise the captured value is
    ; the script default 0 and we'd clobber whatever the player's actual
    ; relationship was.
    If DispatchPlayerRelRankModified
        Actor playerRef = Game.GetPlayer()
        playerRef.SetRelationshipRank(DispatchHomeOwner, DispatchOrigRelRankPlayer)
        DispatchPlayerRelRankModified = false
    EndIf

    DispatchRelRankModified = false
    DebugMsg("Trespass restored: relationship ranks returned to original values")
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
            stuckLevel = SeverActionsNativeExt.Stuck_CheckStatus(DispatchGuard, UpdateInterval, 50.0)
            If stuckLevel >= 2
                DispatchGuard.EvaluatePackage()
                If DispatchTarget != None
                    DispatchTarget.EvaluatePackage()
                EndIf
                If stuckLevel >= 3 && DispatchReturnMarker != None
                    Float teleportDist = SeverActionsNativeExt.Stuck_GetTeleportDistance(DispatchGuard)
                    DispatchGuard.MoveTo(DispatchReturnMarker, teleportDist, 0.0, 0.0, false)
                    If DispatchTarget != None
                        DispatchTarget.MoveTo(DispatchGuard, 50.0, 0.0, 0.0, false)
                    EndIf
                    SeverActionsNativeExt.Stuck_ResetEscalation(DispatchGuard)
                    ; Grace period after this teleport too
                    DispatchStuckGraceUntil = Utility.GetCurrentRealTime() + 5.0
                EndIf
            EndIf
        EndIf

        ; PR-D: on-screen arrival at the return destination is event-driven now —
        ; OnArrival(dispatch_p5_arrived) fires from native ArrivalMonitor registered
        ; in StartDispatchReturnPhase. The off-screen tiered paths below (interior
        ; exit, snapshot distance, OffScreen_CheckArrival, tier-2 force complete)
        ; remain per-tick because ArrivalMonitor can't measure cross-cell distance.
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

    ; PR-D: cancel any pending dispatch-phase ArrivalMonitor registration on
    ; the guard. ArrivalMonitor auto-removes on fire, so a natural Phase-5
    ; arrival already cleared the entry; this cancel covers the time-skip /
    ; tier-2 teleport / snapshot paths where CompleteDispatch is called
    ; without the event firing.
    If DispatchGuard != None
        SeverActionsNativeExt.Arrival_Cancel(DispatchGuard)
    EndIf

    ; Stop stuck tracking and off-screen estimation
    SeverActionsNativeExt.Stuck_StopTracking(DispatchGuard)
    SeverActionsNative.OffScreen_StopTracking(DispatchGuard)

    ; Remove task faction so guard can be dispatched again
    If SeverActions_DispatchFaction != None && DispatchGuard != None
        DispatchGuard.RemoveFromFaction(SeverActions_DispatchFaction)
    EndIf

    ; Clear the SkyrimNet v6+ busy lock on the dispatched guard
    If DispatchGuard != None
        SeverActionsNative.Native_SkyrimNet_ClearActorBusy(DispatchGuard)
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

    ; Strip every SeverActions arrest package from the guard and clear linked refs.
    RemoveAllArrestPackages(DispatchGuard)
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
                ; T1-D.3: native source of truth. Map entry's existence
                ; IS the "is pending" flag — no separate boolean stored.
                SeverActionsNativeExt.Native_Arrest_SetPendingEvidence(DispatchSender, narration, DispatchGuard)
                SeverActionsNativeExt.Native_Arrest_SetDeferredSender(DispatchSender)
                DeferredNarrationSender = DispatchSender
                ; PR-C: arm ArrivalMonitor so the narration fires natively when the
                ; player closes within NarrationProximityRange of the sender, with
                ; no per-tick OnUpdate polling required.
                SeverActionsNativeExt.Arrival_Register(Game.GetPlayer(), DispatchSender, NarrationProximityRange, "narration_witness")
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
                ; T1-D.3: native source of truth. Map entry's existence
                ; IS the "is pending" flag — no separate boolean stored.
                SeverActionsNativeExt.Native_Arrest_SetPendingEvidence(DispatchSender, narration, DispatchGuard)
                SeverActionsNativeExt.Native_Arrest_SetDeferredSender(DispatchSender)
                DeferredNarrationSender = DispatchSender
                ; PR-C: arm ArrivalMonitor for the player-witness threshold.
                SeverActionsNativeExt.Arrival_Register(Game.GetPlayer(), DispatchSender, NarrationProximityRange, "narration_witness")
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
        SeverActionsNativeExt.Native_Arrest_SetDispatchPhase(DispatchGuard, DispatchPhase)
        SeverActionsNative.Native_ArrestSession_UpdateState(prisoner, 6, 6)
        ; Wave 5b: judgment timer now lives on JudgmentScript.
        If JudgmentScript
            JudgmentScript.StartJudgment()
        EndIf

        ; Keep guard near sender — link guard to sender and apply follow package
        SeverActionsNative.LinkedRef_Set(guard, sender, SeverActions_FollowTargetKW)
        If SeverActions_GuardFollowPlayer
            ActorUtil.AddPackageOverride(guard, SeverActions_GuardFollowPlayer, PackagePriority, 1)
            guard.EvaluatePackage()
            DebugMsg("Judgment phase: guard following sender " + senderName)
        EndIf

        ; Keep prisoner following the guard during judgment.
        ; Re-apply follow package to ensure prisoner stays near guard.
        If prisoner != None
            SeverActionsNative.LinkedRef_Set(prisoner, guard, SeverActions_FollowTargetKW)
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

    ; Clear every reference alias the arrest / dispatch FSM uses.
    ClearAllArrestAliases()

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

    ; PR-D: cancel any pending dispatch-phase ArrivalMonitor registration on
    ; the guard. Idempotent — no-op if nothing is registered.
    If DispatchGuard != None
        SeverActionsNativeExt.Arrival_Cancel(DispatchGuard)
    EndIf

    ; Stop stuck tracking, off-screen estimation, restore collision, and restore combat AI
    If DispatchGuard != None
        SeverActionsNativeExt.Stuck_StopTracking(DispatchGuard)
        SeverActionsNative.OffScreen_StopTracking(DispatchGuard)
        SeverActionsNative.SetActorBumpable(DispatchGuard, true)
    EndIf

    ; Remove task faction so guard can be dispatched again
    If SeverActions_DispatchFaction != None && DispatchGuard != None
        DispatchGuard.RemoveFromFaction(SeverActions_DispatchFaction)
    EndIf

    ; Clear the SkyrimNet v6+ busy lock on the dispatched guard
    If DispatchGuard != None
        SeverActionsNative.Native_SkyrimNet_ClearActorBusy(DispatchGuard)
    EndIf

    If DispatchTarget != None
        SeverActionsNative.SetActorBumpable(DispatchTarget, true)
    EndIf
    RestoreGuardCombatAI()

    ; Unregister from sandbox manager if in sandbox phase
    If DispatchIsHomeInvestigation && DispatchGuard != None
        SeverActionsNative.UnregisterSandboxUser(DispatchGuard)
    EndIf

    ; Restore dialogue, strip every arrest package, and clear linked refs.
    If DispatchGuard != None
        DispatchGuard.AllowPCDialogue(true)
        RemoveAllArrestPackages(DispatchGuard)
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

    ; Clear every reference alias the arrest / dispatch FSM uses.
    ClearAllArrestAliases()

    ; Re-lock home door if we unlocked it during investigation
    If DispatchUnlockedDoor != None
        DispatchUnlockedDoor.Lock(true)
        DebugMsg("Re-locked home door after cancelled investigation")
        DispatchUnlockedDoor = None
    EndIf

    ; End the native arrest session for the target prisoner. CancelCurrentArrest
    ; does this on the same-cell path; we mirror it here so OnArrestSessionTimeout
    ; doesn't need a separate End() call and so any direct CancelDispatch caller
    ; (dead-actor cleanup, user-triggered abort) doesn't leak a native session
    ; until the watchdog times out hours later.
    If DispatchTarget != None
        SeverActionsNative.Native_ArrestSession_End(DispatchTarget)
    EndIf

    ; Clear persisted dispatch state from StorageUtil
    ClearPersistedDispatchState()

    ClearDispatchState()

    DebugMsg("Dispatch canceled")
EndFunction

Actor Function FindNearestGuard(Actor akNearActor)
    {Returns the nearest guard to akNearActor within 3000 units, or None.
     Delegates to native GuardFinder (logs distance + hit/miss natively).}

    If akNearActor == None
        Return None
    EndIf
    Return SeverActionsNative.FindNearestGuard(akNearActor, 3000.0)
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
; JUDGMENT HOLD (Phase 6)
; =============================================================================
;
; Wave 5b: the 4 judgment functions (CheckJudgmentProgress, OrderRelease_Execute,
; OrderJailed_Execute, EndJudgment) plus the JudgmentStartTime / JudgmentTimeLimit
; state moved to SeverActions_ArrestJudgment.psc. Per-tick routing happens in
; CheckDispatchProgress; YAML actions (orderrelease.yaml + orderjailed.yaml) point
; their scriptName at the new sub-script directly.

; =============================================================================
; SAVE/LOAD ARREST RECOVERY (same-cell — Wave 1, BUG-A5)
; Mirrors the dispatch system's persistence so that saving mid-approach,
; mid-arrest, or mid-escort doesn't orphan packages on the guard. Without
; this, the prisoner's follow package keeps its per-tick re-apply but the
; OnUpdate loop doesn't restart and the guard's escort package is never
; re-evaluated — symptom: prisoner trailing a guard that's idle.
; =============================================================================

Function PersistArrestState()
    {Mirror dispatch persistence for same-cell arrest. Called whenever
     ArrestState transitions to a non-zero value so that OnPlayerLoadGame
     can rebuild the FSM and resume the OnUpdate loop.}
    If CurrentGuard == None
        Return
    EndIf

    ; T1-D.1: native source of truth — single call carries all 7 fields
    ; into the 'AARS' cosave record (singleton, separate from the 'ARST'
    ; session map). No more StorageUtil keys-on-quest-form pattern.
    SeverActionsNativeExt.Native_Arrest_SetActiveArrest(ArrestState, CurrentGuard, CurrentPrisoner, CurrentJailMarker, CurrentJailName, ApproachStartTime, EscortStartTime)
EndFunction

Function ClearPersistedArrestState()
    {Wipe the persisted active-arrest state after arrest completes / cancels.}
    ; T1-D.1: single native call clears the 'AARS' singleton.
    SeverActionsNativeExt.Native_Arrest_ClearActiveArrest()
EndFunction

Function RecoverActiveArrest()
    {Rebuild same-cell arrest state from StorageUtil after save/load.
     Re-applies packages and aliases based on the persisted ArrestState,
     then re-registers OnUpdate so the FSM resumes.}
    ; T1-D.1: native source of truth for the active-arrest singleton.
    Int savedState = SeverActionsNativeExt.Native_Arrest_GetActiveArrestState()
    If savedState <= 0
        Return  ; No active arrest
    EndIf

    Actor guard = SeverActionsNativeExt.Native_Arrest_GetActiveArrestGuard()
    Actor prisoner = SeverActionsNativeExt.Native_Arrest_GetActiveArrestPrisoner()

    If guard == None || prisoner == None
        DebugMsg("Save/load recovery: stale arrest data (guard or prisoner None) — clearing")
        ClearPersistedArrestState()
        Return
    EndIf

    If guard.IsDead() || prisoner.IsDead()
        DebugMsg("Save/load recovery: arrest participant is dead — canceling")
        ClearPersistedArrestState()
        ; Best-effort cleanup on the survivor
        If !prisoner.IsDead()
            ReleasePrisoner(prisoner)
        EndIf
        Return
    EndIf

    DebugMsg("Save/load recovery: rebuilding arrest at state " + savedState)

    ; Rebuild script properties
    CurrentGuard = guard
    CurrentPrisoner = prisoner
    CurrentJailMarker = SeverActionsNativeExt.Native_Arrest_GetActiveArrestJailMarker()
    CurrentJailName = SeverActionsNativeExt.Native_Arrest_GetActiveArrestJailName()
    If CurrentJailName == ""
        CurrentJailName = "jail"
    EndIf
    ArrestState = savedState
    ; Reset phase timers — Utility.GetCurrentRealTime() is session-relative,
    ; so the saved values are stale; restart the timeout window from now.
    ApproachStartTime = Utility.GetCurrentRealTime()
    EscortStartTime = Utility.GetCurrentRealTime()
    PrisonerMovementFrozen = false  ; SetDontMove doesn't survive save/load anyway
    PrisonerFrozenAt = 0.0

    ; Re-fill aliases that the packages target
    ArrestTarget.ForceRefTo(CurrentPrisoner)
    ArrestingGuard.ForceRefTo(CurrentGuard)
    If CurrentJailMarker != None
        JailDestination.ForceRefTo(CurrentJailMarker)
    EndIf

    ; Re-apply packages based on state
    If ArrestState == 1
        ; Approaching — guard needs the approach package back
        If SeverActions_GuardApproachTarget
            ActorUtil.AddPackageOverride(CurrentGuard, SeverActions_GuardApproachTarget, PackagePriority, 1)
            CurrentGuard.EvaluatePackage()
        EndIf
        SeverActionsNativeExt.Stuck_StartTracking(CurrentGuard)
        ; PR-C: re-arm ArrivalMonitor for the approach threshold. The native
        ; registration does NOT survive save/load (one-shot in-memory map).
        SeverActionsNativeExt.Arrival_Register(CurrentGuard, CurrentPrisoner, ApproachDistance, "arrest_approach_arrived")
    ElseIf ArrestState == 3
        ; Escorting — guard escort package + prisoner follow package + LinkedRef.
        ; Wave 5: ReapplyEscortPackages helper consolidates the (previously
        ; inline-three-times) sequence of forceRefTo + addPkgOverride pairs
        ; that was identical here, in StartEscortPhase, and in the per-tick
        ; CheckEscortProgress re-apply.
        ReapplyEscortPackages(CurrentGuard, CurrentPrisoner, CurrentJailMarker)
        ; PR-C: re-arm ArrivalMonitor for the jail marker.
        If CurrentJailMarker != None
            SeverActionsNativeExt.Arrival_Register(CurrentGuard, CurrentJailMarker, ArrivalDistance, "arrest_escort_arrived")
        EndIf
    EndIf
    ; ArrestState 2 (arresting) is a transient sub-state inside PerformArrest; if we
    ; load while in it, the safest move is to fast-forward to escort:
    If ArrestState == 2
        ; T1-D.1 review fix: if the jail marker FormID failed to resolve
        ; on load (mod removed from load order), StartEscortPhase would
        ; dereference None. Treat missing marker as "cancel and release"
        ; the same way dead-participant handling does above.
        If CurrentJailMarker == None
            DebugMsg("Save/load recovery: ArrestState==2 with missing jail marker — canceling arrest")
            ClearPersistedArrestState()
            ReleasePrisoner(CurrentPrisoner)
            Return
        EndIf
        DebugMsg("Save/load recovery: ArrestState==2 (transient) — fast-forwarding to escort phase")
        ArrestState = 3
        StartEscortPhase()
        Return
    EndIf

    ; Resume the OnUpdate loop
    RegisterForSingleUpdate(UpdateInterval)
    DebugMsg("Save/load recovery complete — resumed at ArrestState " + ArrestState)
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
    ; T1-D.2: single native call carries all 9 context fields into the
    ; 'ARDC' cosave map (keyed by guard FormID), plus the active-dispatch-
    ; guard singleton in the same record.
    SeverActionsNativeExt.Native_Arrest_SetDispatchContext(DispatchGuard, DispatchPhase, DispatchTarget, DispatchReturnMarker, DispatchSender, DispatchHomeMarker, DispatchInvestigationReason, DispatchIsHomeInvestigation, DispatchGuardOrigAggression, DispatchGuardOrigConfidence)
    SeverActionsNativeExt.Native_Arrest_SetActiveDispatchGuard(DispatchGuard)
    DebugMsg("Persisted dispatch state for save/load recovery")
EndFunction

Function ClearPersistedDispatchState()
    {Remove dispatch state after dispatch ends.}
    ; T1-D.2: native source of truth.
    If DispatchGuard != None
        SeverActionsNativeExt.Native_Arrest_ClearDispatchContext(DispatchGuard)
    EndIf
    SeverActionsNativeExt.Native_Arrest_SetActiveDispatchGuard(None)
EndFunction

Function RecoverActiveDispatch()
    {Rebuild dispatch state from StorageUtil after a save/load.
     Script variables persist in saves, but package overrides and aliases are lost.
     This re-applies packages and aliases based on the persisted phase.}

    ; T1-D.2: native source of truth. Singleton tracks which guard the
    ; player quest's dispatch FSM was managing; per-guard map carries
    ; the rest.
    Actor guard = SeverActionsNativeExt.Native_Arrest_GetActiveDispatchGuard()
    If guard == None
        Return  ; No active dispatch
    EndIf

    Int phase = SeverActionsNativeExt.Native_Arrest_GetDispatchPhase(guard)
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

    ; Rebuild script state from native
    DispatchGuard = guard
    DispatchTarget = SeverActionsNativeExt.Native_Arrest_GetDispatchTarget(guard)
    DispatchReturnMarker = SeverActionsNativeExt.Native_Arrest_GetDispatchReturnMarker(guard)
    DispatchSender = SeverActionsNativeExt.Native_Arrest_GetDispatchSender(guard)
    DispatchIsHomeInvestigation = SeverActionsNativeExt.Native_Arrest_GetDispatchIsHome(guard)
    DispatchInvestigationReason = SeverActionsNativeExt.Native_Arrest_GetDispatchReason(guard)
    DispatchHomeMarker = SeverActionsNativeExt.Native_Arrest_GetDispatchHomeMarker(guard)
    DispatchGuardOrigAggression = SeverActionsNativeExt.Native_Arrest_GetDispatchOrigAggro(guard)
    DispatchGuardOrigConfidence = SeverActionsNativeExt.Native_Arrest_GetDispatchOrigConf(guard)
    DispatchPhase = phase

    ; Reset real-time clocks: Utility.GetCurrentRealTime() resets to ~0 on
    ; session restart, so saved values would trigger instant timeout / stuck
    ; / freeze fallbacks on the very first OnUpdate tick after load.
    ; Restart the per-phase windows from now. Same fix as RecoverActiveArrest
    ; does for ApproachStartTime / EscortStartTime.
    Float realNow = Utility.GetCurrentRealTime()
    DispatchPhase2StartTime = realNow
    DispatchSandboxStartTime = realNow
    DispatchContainerSearchStart = realNow
    DispatchOffScreenStartTime = realNow
    DispatchStuckGraceUntil = 0.0
    EscortPleaStartTime = 0.0
    DispatchTargetMovementFrozen = false

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
    SeverActionsNativeExt.Stuck_StartTracking(guard)

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
            ; PR-D: re-register ArrivalMonitor at the Phase-1 destination. The
            ; native map is in-memory only and doesn't survive save/load.
            SeverActionsNativeExt.Arrival_Register(guard, dest, DispatchArrivalDistance, "dispatch_p1_arrived")
        EndIf

    ElseIf phase == 2
        ; Approaching target for arrest — same as Phase 1 outbound
        If DispatchTarget != None
            DispatchTargetAlias.ForceRefTo(DispatchTarget)
            ; PR-D: re-register ArrivalMonitor at the Phase-2 arrest threshold.
            SeverActionsNativeExt.Arrival_Register(guard, DispatchTarget, ApproachDistance, "dispatch_p2_arrived")
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
            ; Defensive LinkedRef re-assertion. The native cosave SHOULD have restored
            ; the sandbox anchor LinkedRef on kPostLoadGame, but Papyrus can run before
            ; that (quest OnInit / alias OnLoad between SKSE's kLoad and kPostLoadGame)
            ; and cache a null GetLinkedRef result. Re-setting here guarantees the
            ; anchor is present by the time we re-enter Phase 3/4 logic.
            If SeverActions_SandboxAnchorKW != None
                ObjectReference anchor = DispatchHomeMarker
                SeverActionsNative.LinkedRef_Set(guard, anchor, SeverActions_SandboxAnchorKW)
            EndIf
            DispatchPhase = 1
            SeverActionsNativeExt.Native_Arrest_SetDispatchPhase(guard, 1)
            ; Re-sync the cosave session entry with the recovery-reset phase.
            ; The entry already persists from before save/load (ArrestSessionStore
            ; is cosave-backed); we just push the new phase value through so the
            ; PrismaUI page reflects the restart-at-Phase-1 decision.
            If DispatchTarget != None
                SeverActionsNative.Native_ArrestSession_UpdateState(DispatchTarget, 5, 1)
            EndIf
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
            SeverActionsNative.LinkedRef_Set(DispatchTarget, guard, SeverActions_FollowTargetKW)
            If SeverActions_FollowGuard_Prisoner
                ActorUtil.AddPackageOverride(DispatchTarget, SeverActions_FollowGuard_Prisoner, PackagePriority, 1)
                DispatchTarget.EvaluatePackage()
            EndIf
        EndIf
        ; Re-init off-screen estimation for return
        If DispatchReturnMarker != None
            SeverActionsNative.OffScreen_InitTracking(guard, DispatchReturnMarker, 0.25, 12.0)
            ; PR-D: re-register ArrivalMonitor at the Phase-5 return destination.
            SeverActionsNativeExt.Arrival_Register(guard, DispatchReturnMarker, DispatchArrivalDistance, "dispatch_p5_arrived")
        EndIf

    ElseIf phase == 6
        ; Judgment hold — just restart update timer, phase logic handles the rest
        If JudgmentScript
            JudgmentScript.StartJudgment()
        EndIf
    EndIf

    ; Resume update loop
    RegisterForSingleUpdate(UpdateInterval)
    DebugMsg("Save/load recovery complete — resumed at Phase " + DispatchPhase)
EndFunction

