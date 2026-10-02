Scriptname SeverActions_Arrest extends Quest

{
    Guard arrest system: same-cell NPC arrest and escort to jail, cross-cell guard dispatch (arrest or
    home investigation), and the jail roster. Bounties, judgment and the player confrontation live in
    SeverActions_ArrestBounty / _ArrestJudgment / _ArrestPlayer.
    Cancels a travel errand on anyone it arrests so the two systems do not fight over the actor's packages.
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

; Guard factions are resolved natively (Native/src/GuardFinder.h).

; =============================================================================
; PROPERTIES - Keywords & Packages (Create in CK)
; =============================================================================

Keyword Property SeverActions_FollowTargetKW Auto
{Keyword for follow packages — prisoner follows guard, guard follows sender in judgment.}

Keyword Property SeverActions_SandboxAnchorKW Auto
{Keyword for sandbox packages — prisoner sandboxes near jail marker, guard sandboxes at home.}

Package Property SeverActions_DispatchTravel Auto
{Jog-speed travel to the DispatchTravelDestination alias: the dispatch guard's walk to each
container in a home search.}

Package Property SeverActions_GuardApproachTarget Auto
{Travel to the ArrestTarget alias: the guard's approach in a same-cell arrest, or
 FreeNPC_Internal's walk to the prisoner.}

Package Property SeverActions_GuardEscortPackage Auto
{Travel package for guard to walk to JailDestination alias (escort to jail phase)}

Package Property SeverActions_FollowGuard_Prisoner Auto
{Follow the FollowTargetKW linked ref: the prisoner trails their guard.}

Package Property SeverActions_PrisonerSandBox Auto
{Sandbox near the SandboxAnchorKW linked ref: a jailed prisoner at their jail marker, and the
 dispatch guard's FallbackSandboxSearch at a home.}

Package Property SeverActions_DispatchJog Auto
{Jog-speed travel to DispatchTargetAlias: the dispatch guard's outbound leg.}

Package Property SeverActions_DispatchWalk Auto
{Walk-speed travel to DispatchTargetAlias: the return leg with the prisoner or evidence.}

; =============================================================================
; PROPERTIES - Items & Outfits (Vanilla or Create in CK)
; =============================================================================

Armor Property SeverActions_PrisonerCuffs Auto
{Bound-hands armor worn by prisoners.}

Armor Property SeverActions_PrisonerRags Auto
{Prison clothing.}

Outfit Property SeverActions_PrisonerOutfit Auto
{Outfit holding the prison rags; set as the NPC's outfit so it survives cell reloads.}

MiscObject Property Gold001 Auto
{Gold001 (Skyrim.esm 0x0000000F); Maintenance looks it up when unfilled.}

; =============================================================================
; PROPERTIES - Idle Animation (Vanilla)
; =============================================================================

Idle Property OffsetBoundStandingStart Auto
{Vanilla idle for bound standing pose}

Idle Property IdleGive Auto
{Vanilla idle for give/hand-over gesture - used when freeing prisoners}

; =============================================================================
; PROPERTIES - Jail Markers
; XMarkers inside each jail cell: the crime faction's factionJailMarker is the
; exterior spot the player lands on, not the cell.
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
{The on-task mark: rank 0 on the guard of a same-cell arrest or a dispatch from start to end
 (_BeginGuardTask / _LeaveTaskFaction), read by the stale sweeps. The action gate is
 sever_is_dispatched, which reads the native arrest claim: this faction's span plus the judgment
 hold and the escort after it.}

; =============================================================================
; PROPERTIES - Reference Aliases (Create in Quest)
; =============================================================================

ReferenceAlias Property ArrestTarget Auto
{The actor the guard approaches (GuardApproachTarget targets it): the suspect in a same-cell
 arrest, the prisoner in FreeNPC_Internal.}

ReferenceAlias Property JailDestination Auto
{The jail marker; GuardEscortPackage targets it.}

ReferenceAlias Property ArrestingGuard Auto
{The arresting guard of a same-cell arrest.}

ReferenceAlias Property DispatchGuardAlias Auto
{The dispatch guard, held in high process during cross-cell travel. Separate from
 ArrestingGuard, which a same-cell arrest refills.}

ReferenceAlias Property DispatchTargetAlias Auto
{The dispatch destination, targeted by DispatchJog/DispatchWalk: the target NPC or home
 marker outbound, the return marker in phase 5.}

ReferenceAlias Property DispatchPrisonerAlias Auto
{The dispatch prisoner during the phase-5 return, held in high process so their follow
package keeps running off-screen. Cleared when the dispatch completes.}

ReferenceAlias Property DispatchTravelDestination Auto
{SeverActions_DispatchTravel's destination (the container in a home search). An alias rather
than a linked ref so the engine tracks the destination across cells.}

; =============================================================================
; PROPERTIES - Cross-Script References
; =============================================================================

SeverActions_ArrestBounty Property BountyScript Auto
{The tracked-bounty subsystem (bounty CRUD, AddBountyToPlayer). Resolved by cast in
 Maintenance when unfilled.}

SeverActions_ArrestJudgment Property JudgmentScript Auto
{The phase-6 judgment subsystem (OrderRelease/OrderJailed, EndJudgment,
 CheckJudgmentProgress). Resolved in Maintenance when unfilled.}

SeverActions_ArrestPlayer Property PlayerScript Auto
{The player confrontation + persuasion FSM, on its own chronometer tick. Resolved in
 Maintenance when unfilled.}

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
{Real-time seconds the guard gets to walk in after the prisoner freezes (ApproachFreezeDistance)
 before being teleported in; 0 = teleport at once.}

Float Property EscortPleaTimeLimit = 60.0 Auto
{Real-time seconds an NPC prisoner's mid-escort plea runs before the guard silently resumes
 the escort (the NPC twin of PersuasionTimeLimit).}

Float Property EscortPleaFollowDistance = 300.0 Auto
{A prisoner who strays farther than this from the guard during a plea ends it: the escort
 resumes, with no extra penalty.}

Int Property ResistBountyIncrease = 500 Auto
{Additional bounty added when player resists arrest}

Float Property ArrestPlayerCooldown = 60.0 Auto
{Cooldown in seconds before ArrestPlayer can be used again after a confrontation starts}

Float Property ApproachTimeout = 30.0 Auto
{Real-time seconds the dispatch phase-2 approach gets before the guard is teleported in. Read only by
 CheckDispatchPhase2_Approach; the same-cell approach timeout is the native kApproach watchdog's.}

Float Property EscortTimeout = 600.0 Auto
{Not read; kept declared for its VMAD fill. The escort timeout is the kEscort session
 watchdog's (6 game hours, ArrestSessionStore.h TimeoutForState).}

Float Property ApproachFreezeDistance = 350.0 Auto
{Within this distance the guard's target is frozen (SetDontMove) so the gap can close below
 ApproachDistance; released when the arrest performs.}

Package Property SeverActions_GuardFollowPlayer Auto
{Follow the FollowTargetKW linked ref: the guard trails the player during persuasion.}

; =============================================================================
; PROPERTIES - Tunables
; =============================================================================

Float Property NarrationProximityRange = 300.0 Auto
{Radius at which the player triggers a deferred-narration sender's stored line (the
 narration_witness arrival watch).}

Float Property GuardArrivalThreshold = 200.0 Auto
{Not read by any code.}

Float Property JailMarkerVerifyDistance = 500.0 Auto
{How far from the jail marker a prisoner may stand before OnArrivedAtJail retries the placement
 or VerifyJailedNPCs treats them as out of jail.}

Float Property DispatchSpamCooldown = 15.0 Auto
{Not read: the two dispatch entry points hard-code the 15 s anti-spam window.}

Float Property OffScreenMinimumTravelTime = 120.0 Auto
{Not read: CheckDispatchOffScreen hard-codes its 120 s minimum.}

Float Property GuardJogSpeed = 300.0 Auto
{Units per real second a jogging guard covers (CheckDispatchOffScreen's travel-time estimate).}

Float Property GuardJogPerGameHour = 20000.0 Auto
{Units per game hour a jogging guard covers (CheckDispatchProgress's time-skip teleport).}

; =============================================================================
; STATE TRACKING
; =============================================================================

; The same-cell arrest FSM: one arrest at a time.
Actor CurrentGuard
Actor CurrentPrisoner
ObjectReference CurrentJailMarker
String CurrentJailName
Int ArrestState ; 0=none, 1=approaching, 2=arresting, 3=escorting, 4=escort plea (NPC pleading mid-march), 5=arrived (transient, OnArrivedAtJail in progress)

; Escort plea (ArrestState 4): its start time, and the one-plea-per-arrest gate
; (the NPC twin of ArrestPlayer's PersuadeAttempted).
Float EscortPleaStartTime
Bool EscortPleaAttempted

; Legacy jailed-NPC list: MigrateJailedNPCsToNative moves it into the native
; JailedNPCStore ('JAIL') once and empties it. Nothing else adds to it.
Actor[] JailedNPCs

Float LastDispatchSpamTime      ; Real time of the last dispatch (15 s anti-spam window)

; Timers and movement freezes
Float ApproachStartTime         ; Real time the same-cell approach began; persisted only (the kApproach watchdog owns the timeout)
Float EscortStartTime           ; Real time the escort began; persisted in 'AARS' only (the kEscort watchdog owns the timeout)
Float DispatchPhase2StartTime   ; Real time when dispatch transitioned to Phase 2 (post-travel approach)
Bool PrisonerMovementFrozen     ; Track whether SetDontMove is currently held on CurrentPrisoner
Float PrisonerFrozenAt          ; Real time when SetDontMove fired (drives the post-freeze grace period before fallback teleport snap)
Bool DispatchTargetMovementFrozen ; Track whether SetDontMove is currently held on DispatchTarget during Phase 2

; Cross-cell dispatch state (self-contained - dispatch movement never goes through the travel module)
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
Float DispatchReturnTimeStart           ; Game time when the return leg (phase 5) began
Float DispatchInitialDistance           ; Distance (units) between guard and target at dispatch start (for time-skip calc when cross-cell)
Bool DispatchGuardOffScreen             ; True if guard is currently off-screen
String DispatchTargetLocation           ; Cached location name for the target

; Phase-6 judgment state lives in SeverActions_ArrestJudgment (StartJudgment / ResetState /
; CheckJudgmentProgress).

; Home investigation state (DispatchGuardToHome)
Bool DispatchIsHomeInvestigation        ; True if this is a home investigation (not an arrest dispatch)
ObjectReference DispatchHomeMarker      ; The NPC's home destination (interior marker if found, exterior door fallback)
Actor DispatchSender                    ; Who sent the guard (for return destination)
String DispatchInvestigationReason      ; Why the investigation was ordered (e.g. "dibella worship", "thieving") - used for evidence generation
Float DispatchSandboxStartTime          ; Real time when sandbox investigation started
Float DispatchSandboxDuration           ; Per-mode search timer, seconds (5s on-screen entry scan / 15-30s no-containers fallback / 20-45s off-screen simulation)
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

; Home search (phase 3): containers are searched one after another
Int DispatchContainerCount = 0             ; Number of containers to search
Int DispatchCurrentContainer = 0           ; Index of container currently being searched
ObjectReference DispatchCurrentContainerRef = None  ; Current container ref the guard is walking to / searching
Float DispatchContainerSearchStart = 0.0   ; Real time when current container search started
Float DispatchContainerSearchDuration = 0.0 ; How long to search current container (8-12s)
Int DispatchSearchSubPhase = 0             ; 0=start walk to next container, 1=walking (arrival check), 2=searching (wait for duration)
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
    {Zero the real-time cooldowns: GetCurrentRealTime restarts at 0 each launch, so saved values
     would read as phantom cooldowns. Called only from OnInit and OnGameLoaded, never from
     Maintenance, which ArrestPlayer's payment handlers call mid-session.}
    If PlayerScript
        PlayerScript.ResetCooldowns()
    EndIf
    LastDispatchSpamTime = 0.0
EndFunction

Function Maintenance()
    {Idempotent setup, run on every load and mid-session by ArrestPlayer's payment handlers:
     form lookups, ModEvent registrations, the sub-scripts, hold registration, the bounty migration.}
    if Gold001 == None
        Gold001 = Game.GetFormFromFile(0x0000000F, "Skyrim.esm") as MiscObject
        if Gold001 == None
            Debug.Trace("[SeverActions_Arrest] ERROR: Could not find Gold001!")
        else
            Debug.Trace("[SeverActions_Arrest] Gold001 found via auto-lookup")
        endif
    endif

    ; No cooldown reset here: see ResetSessionCooldowns.

    ; Re-verify prisoners after fast travel or waiting (OnTrackedStatsEvent).
    RegisterForTrackedStatsEvent()

    ; SandboxManager's cell-change cleanup (see OnNativeSandboxCleanup).
    RegisterForModEvent("SeverActionsNative_SandboxCleanup", "OnNativeSandboxCleanup")

    ; The native OrphanCleanup scanner's arrest events (off by default; see OnOrphanCleanup).
    RegisterForModEvent("SeverActions_OrphanCleanup", "OnOrphanCleanup")
    ; The arrest module's verb event (M-V): arrest, bounty, surrender and the eight kidnap
    ; verbs (OnVerb_Arrest forwards those to SeverActions_Kidnap).
    RegisterForModEvent("SeverActions_Verb_Arrest", "OnVerb_Arrest")
    ; ... and its hotkey event (M-K): the TieUntie key.
    RegisterForModEvent("SeverActions_Hotkey_Arrest", "OnHotkey_Arrest")
    ; The UI's two bounty buttons (the tracked-bounty rows are this module's state).
    RegisterForModEvent("SeverActions_MagelightClearBounty", "OnPrismaClearBounty")
    RegisterForModEvent("SeverActions_MagelightClearAllBounties", "OnPrismaClearAllBounties")
    RegisterForModEvent("SeverActions_TrespassNoticed", "OnTrespassNoticed")
    RegisterForModEvent("SeverActions_TrespassWake", "OnTrespassWake")
    RegisterForModEvent("SeverActions_TrespassWakeEnd", "OnTrespassWakeEnd")

    ; The ArrestSessionStore watchdog's per-state timeouts (see OnArrestSessionTimeout).
    RegisterForModEvent("SeverActions_ArrestSessionTimeout", "OnArrestSessionTimeout")

    ; ArrivalMonitor's one-shot arrivals, routed by callback tag (see OnArrival).
    RegisterForModEvent("SeverActionsNative_OnArrival", "OnArrival")

    ; The escort rope's framework events: shared with the kidnap side (canonical callbacks,
    ; M-E), so they fire for every rope and answer only for our own prisoners.
    RegisterForModEvent("LeashFramework_OnUnleash", "OnLeashFrameworkUnleash")
    RegisterForModEvent("LeashFramework_OnActorPulled", "OnLeashFrameworkPulled")
    RegisterForModEvent("LeashFramework_OnActorRagdollPulled", "OnLeashFrameworkRagdollPulled")

    ; EscortPackageReapplier: re-assert the escort packages after a cell transition or combat end.
    RegisterForModEvent("SeverActions_EscortReapplyPackages", "OnEscortReapplyPackages")

    ; Magelight arrests page: the jail roster's Release button and the Cancel-arrest button
    ; (payload and routing in each handler's doc).
    RegisterForModEvent("SeverActions_MagelightReleasePrisoner", "OnPrismaReleasePrisoner")
    RegisterForModEvent("SeverActions_MagelightCancelArrest", "OnPrismaCancelArrest")

    ; Enterprises: a fence retainer's arrest, and their release after the term or bail.
    RegisterForModEvent("SeverActions_FenceArrest", "OnFenceArrest")
    RegisterForModEvent("SeverActions_FenceRelease", "OnFenceRelease")

    ; Resolve each sub-script when unfilled and run its Maintenance (which sets its
    ; ArrestScript back-pointer).
    If !BountyScript
        Quest sevQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
        If sevQuest
            BountyScript = sevQuest as SeverActions_ArrestBounty
        EndIf
    EndIf
    If BountyScript
        BountyScript.Maintenance()
    Else
        Debug.Trace("[SeverActions_Arrest] WARNING: BountyScript not resolved - bounty subsystem unavailable")
    EndIf

    If !JudgmentScript
        Quest sevQuest2 = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
        If sevQuest2
            JudgmentScript = sevQuest2 as SeverActions_ArrestJudgment
        EndIf
    EndIf
    If JudgmentScript
        JudgmentScript.Maintenance()
    Else
        Debug.Trace("[SeverActions_Arrest] WARNING: JudgmentScript not resolved - judgment subsystem unavailable")
    EndIf

    If !PlayerScript
        Quest sevQuest3 = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
        If sevQuest3
            PlayerScript = sevQuest3 as SeverActions_ArrestPlayer
        EndIf
    EndIf
    If PlayerScript
        PlayerScript.Maintenance()
    Else
        Debug.Trace("[SeverActions_Arrest] WARNING: PlayerScript not resolved - player-arrest subsystem unavailable")
    EndIf

    ; The native HoldResolver seeds these nine holds by FormID at kDataLoaded (P2-10);
    ; this re-registers them as a belt (Hold_Register overwrites by crime faction).
    ; Never clear the table first: that only opens a window where lookups find nothing.
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

    ; Drain the legacy "SeverActions_Bounty_<Hold>" StorageUtil keys into the native BountyStore
    ; (its bounty keys come from the kernel's HoldResolver seed, not the belt above). BountyScript's
    ; sentinel makes re-runs no-ops.
    If BountyScript
        BountyScript.MigrateLegacyStorage()
    EndIf
EndFunction

Function OnGameLoaded()
    {Load recovery, run on every load and new game by the arrest provider's stage 1 (a Quest
     script never gets OnPlayerLoadGame).}
    ; Chronometer ticks do not survive a load: one wake re-primes a mid-flight FSM (a clean
    ; FSM no-ops it).
    ChronoArm(UpdateInterval)
    Debug.Trace("[SeverActions_Arrest] Game loaded - verifying prisoner positions and dispatch state")
    Maintenance()
    ResetSessionCooldowns()
    MigrateJailedNPCsToNative()
    VerifyJailedNPCs()
    RecoverActiveArrest()
    RecoverActiveDispatch()
    ; Sweep a crashed arrest's residue off the four slot actors. The helper refuses a live
    ; slot (a failed recovery leaves ArrestState / DispatchPhase set, for the FSM tick or the
    ; next arrest's CancelCurrentArrest), so this reaches only slots whose state is back at 0.
    ClearStaleArrestState(CurrentGuard, "load")
    ClearStaleArrestState(CurrentPrisoner, "load")
    ClearStaleArrestState(DispatchGuard, "load")
    ClearStaleArrestState(DispatchTarget, "load")

    ; The deferred narration sender is cosaved ('ARPE'); ArrivalMonitor's watches are not, so
    ; re-arm the player watch.
    Actor deferred = SeverActionsNativeExt.Native_Arrest_GetDeferredSender()
    If deferred != None
        DeferredNarrationSender = deferred
        If DeferredNarrationSender != None && !DeferredNarrationSender.IsDead()
            Debug.Trace("[SeverActions_Arrest] Recovered deferred narration sender: " + DeferredNarrationSender.GetDisplayName())
            SeverActionsNativeExt.Arrival_Register(Game.GetPlayer(), DeferredNarrationSender, NarrationProximityRange, "narration_witness")
        Else
            ClearDeferredNarration()
        EndIf
    EndIf

    HealOrphanedCaptivitySandboxes()
EndFunction

Function HealOrphanedCaptivitySandboxes()
    {Strip the captivity holds (PrisonerSandBox, the kidnap guard sandbox, the SandboxAnchorKW link)
     from anyone in the player's cell with no live claim on them.
     Must run after MigrateJailedNPCsToNative / VerifyJailedNPCs, which repair the jail record the
     Native_Jailed_IsJailed probe reads; before them it would strip a real prisoner's hold. Every
     probe is a kernel native, so no other module's recovery need run first.
     SeverKidnap_OnGuard is deliberately not probed: it is only set on the kidnapper of a live
     entry, which FindVictimOf already covers, so a flag without an entry is the orphan to strip.}
    Package guardPkgHeal = Game.GetFormFromFile(0x00165679, "SeverActions.esp") as Package   ; SeverActions_KidnapGuardSandbox
    Actor playerHeal = Game.GetPlayer()
    Actor[] cellActors = SeverActionsNativeExt.Native_ScanPlayerCellForLiveActors()
    Int healN = 0
    String healNames = ""
    Int i = 0
    While i < cellActors.Length
        Actor a = cellActors[i]
        If a && !a.IsDead() && a != playerHeal
            Bool legit = SeverActionsNativeExt.Native_Kidnap_GetPhase(a) != 0
            If !legit
                legit = SeverActionsNativeExt.Native_Kidnap_FindVictimOf(a) != None
            EndIf
            If !legit
                legit = SeverActionsNativeExt.Native_Jailed_IsJailed(a)
            EndIf
            If !legit
                legit = SeverActionsNative.Native_ArrestSession_HasSession(a)
            EndIf
            If !legit
                If SeverActions_PrisonerSandBox
                    ActorUtil.RemovePackageOverride(a, SeverActions_PrisonerSandBox)
                EndIf
                If guardPkgHeal
                    ActorUtil.RemovePackageOverride(a, guardPkgHeal)
                EndIf
                If SeverActions_SandboxAnchorKW
                    SeverActionsNative.LinkedRef_Clear(a, SeverActions_SandboxAnchorKW)
                EndIf
                a.EvaluatePackage()
                healN += 1
                If healNames != ""
                    healNames += ", "
                EndIf
                healNames += a.GetDisplayName()
            EndIf
        EndIf
        i += 1
    EndWhile
    ; The names are the evidence: a live captive or prisoner in this list means a probe failed.
    Debug.Trace("[SeverActions_Arrest] Load recovery: captivity-sandbox sweep checked " + cellActors.Length + " cell actors (" + healN + " without live captivity claims - overrides stripped defensively: " + healNames + ")")
EndFunction

Event OnTrackedStatsEvent(String asStat, Int aiValue)
    {Re-verify prisoner positions when a location is discovered or a day passes (a proxy for
     fast travel and waiting).}
    If asStat == "Locations Discovered" || asStat == "Days Passed"
        VerifyJailedNPCs()
    EndIf
EndEvent

Event OnNativeSandboxCleanup(string eventName, string strArg, float numArg, Form sender)
    {SandboxManager's cell-change cleanup. Handles only the DispatchGuard, the one actor Arrest
     registers (FallbackSandboxSearch); Follow's handler of this shared callback ignores actors
     it is not sandboxing.}

    Actor akActor = sender as Actor
    If !akActor
        akActor = Game.GetFormEx(numArg as Int) as Actor
    EndIf

    If !akActor || akActor != DispatchGuard
        Return
    EndIf

    DebugMsg("Native cell-change cleanup for DispatchGuard: " + akActor.GetDisplayName())

    ; Drop the sandbox now so the guard does not idle on a stale override; the FSM moves on
    ; at its next tick.
    SeverActionsNative.UnregisterSandboxUser(akActor)
    If SeverActions_PrisonerSandBox != None
        ActorUtil.RemovePackageOverride(akActor, SeverActions_PrisonerSandBox)
    EndIf
    If SeverActions_SandboxAnchorKW != None
        SeverActionsNative.LinkedRef_Clear(akActor, SeverActions_SandboxAnchorKW)
    EndIf
EndEvent

Event OnArrestSessionTimeout(string eventName, string strArg, float numArg, Form sender)
    {The ArrestSessionStore watchdog's timeout: strArg = the state (1..8; 9 kJailed has no budget),
     sender = the prisoner. An approach or escort timeout of the same-cell arrest pushes the arrest
     through; any other live arrest or dispatch is cancelled; with no live slot only the native
     session is closed.}

    Actor akPrisoner = sender as Actor
    ; numArg is 0 by design (a float FormID corrupts above 2^24).
    DebugMsg("ArrestSessionTimeout: prisoner=" + akPrisoner.GetFormID() + " state=" + strArg)

    If !akPrisoner
        ; The native side ends a session whose actor is gone.
        Return
    EndIf

    ; Same-cell arrest (CancelCurrentArrest ends the native session itself).
    If CurrentPrisoner == akPrisoner && ArrestState > 0
        ; An escort timeout pushes the jailing through: the arrest is committed, the engine
        ; only failed to walk them there. State 3 only - in state 5 OnArrivedAtJail is already
        ; running and re-entering it would jail twice.
        If ArrestState == 3 && CurrentJailMarker != None
            ; The watchdog does not End() the session, so it re-fires ~1 s later while
            ; OnArrivedAtJail is mid-Wait in state 5; that re-fire would fall to
            ; CancelCurrentArrest and strip the session before RestorePrisonerStats reads it.
            ; kJailed (9) has no budget, so moving there first stops it; OnArrivedAtJail's own
            ; UpdateState(9) becomes a no-op.
            SeverActionsNative.Native_ArrestSession_UpdateState(akPrisoner, 9, 0)

            If CurrentGuard != None && CurrentGuard.GetDistance(CurrentJailMarker) <= ArrivalDistance
                ; Guard already at the marker: OnArrivedAtJail places the prisoner itself.
                DebugMsg("ArrestSessionTimeout: kEscort - guard already at jail, fast-finalize")
            Else
                DebugMsg("ArrestSessionTimeout: kEscort - force-teleporting the prisoner to jail; the guard stays put")
                CurrentPrisoner.MoveTo(CurrentJailMarker, 0.0, 0.0, 0.0)
                SeverActionsNative.Native_MoveToNearestNavmesh(CurrentPrisoner, 0.0)
                Utility.Wait(0.2)
                ; Never move the guard: a spot beside the cell marker is inside the cell, behind a
                ; locked door they may hold no key to. OnArrivedAtJail needs the guard only for
                ; the crime faction and the narration.
            EndIf
            OnArrivedAtJail()
            Return
        EndIf

        ; An approach timeout finalizes too: teleport the guard in and PerformArrest.
        ; UnfreezePrisonerMovement gives a prisoner frozen mid-approach their movement back
        ; for the follow package. kArresting (2) first stops the re-fire, as above;
        ; StartEscortPhase moves the session on to kEscort.
        If ArrestState == 1 && CurrentGuard != None && CurrentPrisoner != None
            DebugMsg("ArrestSessionTimeout: kApproach - force-teleporting guard + PerformArrest (legacy ApproachTimeout behavior)")
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

    ; Dispatch (CancelDispatch ends the native session itself).
    If DispatchTarget == akPrisoner && DispatchPhase > 0
        DebugMsg("ArrestSessionTimeout: cancelling dispatch for " + akPrisoner.GetDisplayName())
        CancelDispatch()
        Return
    EndIf

    ; No live slot: a native session a teardown failed to End(). Close it.
    DebugMsg("ArrestSessionTimeout: stale session for " + akPrisoner.GetDisplayName() + " - closing")
    SeverActionsNative.Native_ArrestSession_End(akPrisoner)
EndEvent

Event OnPrismaCancelArrest(string eventName, string strArg, float numArg, Form sender)
    {Magelight arrests page "Cancel arrest" button. Payload (MagelightActionHandler's SendModEvent;
     read the helper, not a comment, before changing the parse): sender = the prisoner, strArg =
     "<name or signed-decimal FormID>|" (the FormID is the fallback when sender is None), numArg = 0.
     Cancels the same-cell arrest or the dispatch whose prisoner it is (both end the native
     session); otherwise the request is stale and only the native session is closed.}

    Actor akPrisoner = sender as Actor
    If !akPrisoner
        Int pipePos = StringUtil.Find(strArg, "|")
        If pipePos > 0
            Int fallbackFid = StringUtil.Substring(strArg, 0, pipePos) as Int
            If fallbackFid != 0
                akPrisoner = Game.GetFormEx(fallbackFid) as Actor
            EndIf
        EndIf
    EndIf
    If !akPrisoner
        DebugMsg("Magelight cancel: could not resolve prisoner (sender=None, strArg='" + strArg + "')")
        Return
    EndIf

    If CurrentPrisoner == akPrisoner && ArrestState > 0
        DebugMsg("Magelight cancel: same-cell arrest for " + akPrisoner.GetDisplayName())
        CancelCurrentArrest()
        Return
    EndIf

    If DispatchTarget == akPrisoner && DispatchPhase > 0
        DebugMsg("Magelight cancel: dispatch for " + akPrisoner.GetDisplayName())
        CancelDispatch()
        Return
    EndIf

    ; Stale request: close any native session so the watchdog table stays clean.
    DebugMsg("Magelight cancel: stale request for " + akPrisoner.GetDisplayName() + " - closing native session if any")
    SeverActionsNative.Native_ArrestSession_End(akPrisoner)
EndEvent

Event OnPrismaReleasePrisoner(string eventName, string strArg, float numArg, Form sender)
    {Magelight Jail Roster "Release" button; same payload as OnPrismaCancelArrest (sender first,
     the strArg FormID via GetFormEx as the fallback). Frees through FreePrisonerDirect ->
     ReleaseFromJailCore, which also drops the native roster row.}

    Actor akPrisoner = sender as Actor
    If !akPrisoner
        Int pipePos = StringUtil.Find(strArg, "|")
        If pipePos > 0
            Int fallbackFid = StringUtil.Substring(strArg, 0, pipePos) as Int
            If fallbackFid != 0
                akPrisoner = Game.GetFormEx(fallbackFid) as Actor
            EndIf
        EndIf
    EndIf
    If !akPrisoner
        DebugMsg("Magelight release: could not resolve prisoner (sender=None, strArg='" + strArg + "')")
        Return
    EndIf
    DebugMsg("Magelight release: " + akPrisoner.GetDisplayName())
    FreePrisonerDirect(akPrisoner)
EndEvent

Event OnFenceArrest(string eventName, string strArg, float numArg, Form sender)
    {Enterprises (VentureMonitor): a fence retainer's bounty triggered an arrest. sender = the
     fence; strArg = their hold's crime faction FormID as signed decimal (numArg is a float copy,
     fallback only). Loaded in the player's cell with a guard nearby: a normal NPC arrest;
     otherwise straight to jail.}

    Actor fence = sender as Actor
    If !fence
        Return
    EndIf
    ; Already in our arrest pipeline — don't double-arrest.
    If fence.IsInFaction(SeverActions_Arrested) || fence.IsInFaction(SeverActions_Jailed)
        Return
    EndIf

    ; Signed decimal is exact at any load-order slot; the float numArg only below 2^24.
    Faction crimeFac = None
    If strArg != ""
        crimeFac = Game.GetFormEx(strArg as Int) as Faction
    EndIf
    If !crimeFac && numArg > 0.0
        crimeFac = Game.GetForm(numArg as Int) as Faction
    EndIf
    Actor pc = Game.GetPlayer()
    Bool onScreen = fence.Is3DLoaded() && pc && fence.GetParentCell() == pc.GetParentCell()

    If onScreen
        Actor guard = SeverActionsNative.FindNearestGuard(fence, 4000.0)
        If guard
            DebugMsg("FenceArrest (on-screen): " + guard.GetDisplayName() + " arresting " + fence.GetDisplayName())
            ArrestNPC_Internal(guard, fence)
            Return
        EndIf
        ; Loaded but no guard nearby — fall through to a direct teleport-to-jail.
    EndIf
    DebugMsg("FenceArrest (off-screen): jailing " + fence.GetDisplayName())
    JailFenceDirect(fence, crimeFac)
EndEvent

Event OnFenceRelease(string eventName, string strArg, float numArg, Form sender)
    {Enterprises: a jailed fence served their term or was bailed out. Frees through
     FreePrisonerDirect, like the Magelight release button.}

    Actor fence = sender as Actor
    If !fence
        Return
    EndIf
    If fence.IsInFaction(SeverActions_Jailed) || fence.IsInFaction(SeverActions_Arrested)
        DebugMsg("FenceRelease: freeing " + fence.GetDisplayName())
        FreePrisonerDirect(fence)
    EndIf
EndEvent

Function JailFenceDirect(Actor akFence, Faction akCrime)
    {Jail the fence without the guard FSM: MoveTo + navmesh snap + Jailed faction + JailedNPCStore,
     like OnArrivedAtJail's tail. FreePrisonerDirect releases them (it needs no arrest session).}

    If akFence == None
        Return
    EndIf
    Faction crime = akCrime
    If !crime
        crime = akFence.GetCrimeFaction()
    EndIf
    ObjectReference jail = None
    If crime
        jail = SeverActionsNativeExt.Hold_GetJailMarkerForCrime(crime)
    EndIf
    If !jail
        jail = JailMarker_Whiterun   ; last-resort fallback (same as GetJailMarkerForGuard)
    EndIf
    If !jail
        DebugMsg("JailFenceDirect: no jail marker for " + akFence.GetDisplayName())
        Return
    EndIf

    akFence.MoveTo(jail)
    SeverActionsNative.Native_MoveToNearestNavmesh(akFence, 0.0)
    akFence.AddToFaction(SeverActions_Jailed)
    SeverActionsNativeExt.Native_Jailed_Add(akFence, jail, crime, 0)

    ; No live narration off-screen, so seed a memory of the arrest (a no-op without
    ; SkyrimNet's memory API).
    String fenceName = akFence.GetDisplayName()
    String memText = fenceName + " was caught by the guards and arrested for running an illicit fencing operation - moving and laundering stolen goods through the black market. " + fenceName + " was thrown in jail, and stays imprisoned until the sentence is served or someone pays the bounty."
    SeverActionsNative.Native_AddMemory(akFence, memText, 0.75, "EXPERIENCE", "fearful", "", "[\"arrest\",\"jail\",\"fencing\"]", "[]")

    DebugMsg("JailFenceDirect: " + akFence.GetDisplayName() + " moved to jail + memory seeded")
EndFunction

Bool Function ClearStaleArrestState(Actor akActor, String asWhy)
    {Clear a crashed arrest's residue from an actor: the four arrest factions (a stale Arrested /
     Jailed tag makes ArrestNPC_Internal refuse them), both keyword links, every arrest package
     override and the SkyrimNet busy lock. Called at arrest and dispatch start for guard and
     suspect and at load for the FSM's slot actors. Refuses (false) while any live claim exists
     (OnOrphanCleanup's exemptions, which it explains). True when it cleared something.}
    If akActor == None || akActor == Game.GetPlayer()
        Return false
    EndIf
    If IsNPCJailed(akActor)
        Return false
    EndIf
    If SeverActionsNativeExt2.Camp_ChallengeIsPending(akActor)
        Return false
    EndIf
    If SeverActionsNativeExt2.Venture_Audit_IsCollector(akActor)
        Return false
    EndIf
    If SeverActionsNative.Native_GetWorkLoc(akActor) as Actor
        Return false
    EndIf
    If SeverActionsNativeExt.Native_Kidnap_GetPhase(akActor) != 0 || SeverActionsNativeExt.Native_Kidnap_FindVictimOf(akActor) != None
        Return false
    EndIf
    If SeverActionsNative.Native_BrawlChallenge_IsActive(akActor)
        Return false
    EndIf
    If PlayerScript != None && akActor == PlayerScript.GetConfrontingGuard()
        Return false ; the confrontation holds FollowTargetKW on the player whatever ArrestState says
    EndIf
    Bool isActiveSlot = (akActor == CurrentGuard || akActor == CurrentPrisoner \
        || akActor == DispatchTarget || akActor == DispatchGuard)
    If ArrestState != 0 && isActiveSlot
        Return false
    EndIf
    If DispatchPhase > 0 && (akActor == DispatchTarget || akActor == DispatchGuard)
        Return false
    EndIf
    If SeverActionsNative.Native_ArrestSession_HasSession(akActor)
        Return false
    EndIf
    Bool inStale = (akActor.IsInFaction(SeverActions_WaitingArrest) \
        || akActor.IsInFaction(SeverActions_Arrested) \
        || akActor.IsInFaction(SeverActions_Jailed) \
        || (SeverActions_DispatchFaction != None && akActor.IsInFaction(SeverActions_DispatchFaction)))
    Bool hasLink = false
    If SeverActions_FollowTargetKW && akActor.GetLinkedRef(SeverActions_FollowTargetKW) != None
        hasLink = true
    EndIf
    If SeverActions_SandboxAnchorKW && akActor.GetLinkedRef(SeverActions_SandboxAnchorKW) != None
        hasLink = true
    EndIf
    If !inStale && !hasLink
        Return false
    EndIf
    DebugMsg("Stale arrest state cleared from " + akActor.GetDisplayName() + " (" + asWhy + "; faction=" + inStale + ", link=" + hasLink + ")")
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
    If SeverActions_PrisonerSandBox
        ActorUtil.RemovePackageOverride(akActor, SeverActions_PrisonerSandBox)
    EndIf
    If SeverActions_FollowTargetKW
        SeverActionsNative.LinkedRef_Clear(akActor, SeverActions_FollowTargetKW)
    EndIf
    If SeverActions_SandboxAnchorKW
        SeverActionsNative.LinkedRef_Clear(akActor, SeverActions_SandboxAnchorKW)
    EndIf
    If akActor.IsInFaction(SeverActions_WaitingArrest)
        akActor.RemoveFromFaction(SeverActions_WaitingArrest)
    EndIf
    If akActor.IsInFaction(SeverActions_Arrested)
        akActor.RemoveFromFaction(SeverActions_Arrested)
    EndIf
    If akActor.IsInFaction(SeverActions_Jailed)
        akActor.RemoveFromFaction(SeverActions_Jailed)
    EndIf
    _LeaveTaskFaction(akActor)
    SeverActionsNative.Native_SkyrimNet_ClearActorBusy(akActor)
    akActor.EvaluatePackage()
    Return true
EndFunction

Function _BeginGuardTask(Actor akGuard)
    {Puts akGuard on an arrest or dispatch: the on-task faction at rank 0. _GuardOffSchedule
     follows once the native claim exists, which is also what keeps SkyrimNet from re-tasking
     them (sever_is_dispatched).}
    If akGuard == None || SeverActions_DispatchFaction == None
        Return
    EndIf
    ; Erase a rank -1 residue an older build left first, so this rank-0 entry is the only one
    ; a rank read can find.
    SeverActionsNativeExt2.Faction_RemoveClean(akGuard, SeverActions_DispatchFaction)
    akGuard.AddToFaction(SeverActions_DispatchFaction)
    akGuard.SetFactionRank(SeverActions_DispatchFaction, 0)
EndFunction

Function _GuardOffSchedule(Actor akGuard)
    {Takes a retainer guard off their schedule: a work shift outranks the arrest packages (100),
     the guard pool by its quest priority 105 and the work overrides at 110. Call it only once
     the arrest's native claim exists (PersistArrestState / ArrestSession_Begin,
     PersistDispatchState): FollowerManager's schedule gates (_IsMakingArrest) read that claim to
     keep the schedule off them until their part ends, and a schedule tick between an earlier
     strip and the claim would seat them again.}
    If akGuard && SeverActionsNative.Native_GetWorkLoc(akGuard)
        SeverActions_ModuleBase.CallBool("followers", "jailStrip", akGuard)
    EndIf
EndFunction

Function _LeaveTaskFaction(Actor akActor)
    {Takes akActor off the on-task faction without the rank -1 residue RemoveFromFaction leaves,
     which the stale sweeps' rank-blind IsInFaction reads as membership. A no-op for a non-member.}
    If akActor == None || SeverActions_DispatchFaction == None
        Return
    EndIf
    SeverActionsNativeExt2.Faction_RemoveClean(akActor, SeverActions_DispatchFaction)
    ; A membership that survives the erase falls back to RemoveFromFaction. Its -1 residue cannot
    ; block the guard's actions: sever_is_dispatched reads the native claim, not this faction.
    If akActor.GetFactionRank(SeverActions_DispatchFaction) >= 0
        DebugMsg("WARNING: DispatchFaction survived Faction_RemoveClean on " + akActor.GetDisplayName() + " - RemoveFromFaction fallback applied")
        akActor.RemoveFromFaction(SeverActions_DispatchFaction)
    EndIf
EndFunction

Event OnOrphanCleanup(string eventName, string strArg, float numArg, Form sender)
    {The native OrphanCleanup scanner's report (off by default; ClearStaleArrestState is the primary
     sweep). strArg arrest_follow / arrest_sandbox = a holder of FollowTargetKW / SandboxAnchorKW,
     arrest_faction_sweep = a member of an arrest faction; every one is reported, live arrests
     included. Other strArgs are other scripts'. With no live claim on the actor, strips the link,
     its packages and the stale factions.}

    Actor akActor = sender as Actor
    If !akActor
        Return
    EndIf

    If strArg != "arrest_follow" && strArg != "arrest_sandbox" && strArg != "arrest_faction_sweep"
        Return
    EndIf

    ; A jailed prisoner keeps the SandboxAnchorKW link, the PrisonerSandBox override and the
    ; Jailed faction on purpose; test FIRST, or the sweep walks them out of jail.
    If IsNPCJailed(akActor)
        Return
    EndIf

    ; Exemptions: actors that reuse the arrest apparatus and tear it down themselves.
    ; Camp challenger: FollowTargetKW on the player for the walk and the parley.
    If SeverActionsNativeExt2.Camp_ChallengeIsPending(akActor)
        Return
    EndIf

    ; Final Audit: the battlemages follow the Legate on FollowTargetKW; the Legate holds
    ; his own anchor link.
    If SeverActionsNativeExt2.Venture_Audit_IsCollector(akActor)
        Return
    EndIf

    ; Bodyguard (Native_GetWorkLoc is an Actor): FollowTargetKW to their charge, with
    ; FollowGuard_Prisoner as the follow.
    If SeverActionsNative.Native_GetWorkLoc(akActor) as Actor
        Return
    EndIf

    ; Kidnap: the victim trails the kidnapper on FollowTargetKW and is held on SandboxAnchorKW;
    ; the kidnapper keeps SandboxAnchorKW while on guard (FindVictimOf, below).
    If SeverActionsNativeExt.Native_Kidnap_GetPhase(akActor) != 0
        Return
    EndIf

    ; Brawl challenger: trails their target on FollowTargetKW + GuardFollowPlayer.
    If SeverActionsNative.Native_BrawlChallenge_IsActive(akActor)
        Return
    EndIf
    If SeverActionsNativeExt.Native_Kidnap_FindVictimOf(akActor) != None
        Return
    EndIf

    ; A live FSM slot or native session means an arrest in flight. A faction is no proof:
    ; a crashed arrest's faction tag survives save/load.
    Bool isActiveSlot = (akActor == CurrentGuard || akActor == CurrentPrisoner \
        || akActor == DispatchTarget || akActor == DispatchGuard \
        || (PlayerScript != None && akActor == PlayerScript.GetConfrontingGuard()))
    Bool hasNativeSession = SeverActionsNative.Native_ArrestSession_HasSession(akActor)

    If isActiveSlot || hasNativeSession
        ; In flight: the FSM clears the link when it completes.
        Return
    EndIf

    ; An orphan: clean up.
    Bool inStaleArrestFaction = (akActor.IsInFaction(SeverActions_WaitingArrest) \
        || akActor.IsInFaction(SeverActions_Arrested) \
        || akActor.IsInFaction(SeverActions_Jailed) \
        || (SeverActions_DispatchFaction != None && akActor.IsInFaction(SeverActions_DispatchFaction)))

    ; A faction sweep that finds no stale faction lost a race with the arrest's own teardown:
    ; nothing to do (and no EvaluatePackage on a healthy actor every scan).
    If strArg == "arrest_faction_sweep" && !inStaleArrestFaction
        Return
    EndIf

    DebugMsg("Orphan cleanup for " + akActor.GetDisplayName() + " (type=" + strArg \
        + ", staleFaction=" + inStaleArrestFaction + ")")

    If strArg == "arrest_follow"
        ; The link's two follow packages and the guard's two alias-targeted travel packages.
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

    ; The stale factions go too (ClearStaleArrestState also clears them at arrest and dispatch start).
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
        _LeaveTaskFaction(akActor)
        DebugMsg("Orphan cleanup removed stale arrest factions from " + akActor.GetDisplayName())
    EndIf

    ; Release the SkyrimNet busy lock a crashed arrest left, which would otherwise block other
    ; plugins' multi-step actions on the actor for good (idempotent).
    SeverActionsNative.Native_SkyrimNet_ClearActorBusy(akActor)

    akActor.EvaluatePackage()
EndEvent

Event OnEscortReapplyPackages(string eventName, string strArg, float numArg, Form sender)
    {EscortPackageReapplier's signal after a cell transition (strArg "cellAttach") or combat end
     ("combatEnd"; either way the work is the same): re-assert the escort packages. No-ops when
     the escort has ended.}

    If CurrentGuard == None || CurrentPrisoner == None || ArrestState != 3
        ; Stale: no End() here. ClearArrestState is the teardown, and a stale event between a
        ; cancel and a fresh StartEscortPhase on the same pair would tear down the new tracker.
        Return
    EndIf

    If CurrentGuard.IsDead() || CurrentPrisoner.IsDead()
        ; Death is the per-tick check's and the kEscort watchdog's.
        Return
    EndIf

    DebugMsg("EscortReapply: " + strArg + " - reasserting guard + prisoner packages")
    If SeverActions_GuardEscortPackage
        ActorUtil.AddPackageOverride(CurrentGuard, SeverActions_GuardEscortPackage, PackagePriority, 1)
        CurrentGuard.EvaluatePackage()
    EndIf
    If SeverActions_FollowGuard_Prisoner
        ActorUtil.AddPackageOverride(CurrentPrisoner, SeverActions_FollowGuard_Prisoner, PackagePriority, 1)
        CurrentPrisoner.EvaluatePackage()
    EndIf

    ; A cell transition resets the behaviour graph and drops the bound-hands offset too; replay
    ; it after EvaluatePackage, which would drop it again (PerformArrest's ordering rule).
    If OffsetBoundStandingStart
        CurrentPrisoner.PlayIdle(OffsetBoundStandingStart)
    EndIf
EndEvent

Event OnArrival(string eventName, string strArg, float numArg, Form sender)
    {ArrivalMonitor's one-shot arrival: strArg = the tag given to Arrival_Register, numArg = the
     final distance. A SHARED event (M-E): the canonical OnArrival runs on every script of the
     quest (Combat and Kidnap answer their own tags); only arrest tags are handled here. The FSM
     may have moved on since detection, so each branch re-validates and drops a stale event.}

    Actor arrivedActor = sender as Actor
    If arrivedActor == None
        Return
    EndIf

    If strArg == "arrest_approach_arrived"
        ; Guard reached the prisoner — fire arrest if state is still consistent.
        If CurrentGuard != arrivedActor || CurrentPrisoner == None || ArrestState != 1
            DebugMsg("OnArrival(approach): stale event (state moved on) - ignoring")
            Return
        EndIf
        DebugMsg("OnArrival(approach): guard reached prisoner (final dist " + numArg + ") - performing arrest")
        SeverActionsNativeExt.Stuck_StopTracking(CurrentGuard)
        If SeverActions_GuardApproachTarget
            ActorUtil.RemovePackageOverride(CurrentGuard, SeverActions_GuardApproachTarget)
        EndIf
        PerformArrest()

    ElseIf strArg == "arrest_escort_arrived"
        ; Guard reached the jail marker — finalize.
        If CurrentGuard != arrivedActor || CurrentPrisoner == None || CurrentJailMarker == None || ArrestState != 3
            DebugMsg("OnArrival(escort): stale event (state moved on) - ignoring")
            Return
        EndIf
        DebugMsg("OnArrival(escort): guard arrived at jail (final dist " + numArg + ")")
        OnArrivedAtJail()

    ElseIf strArg == "narration_witness"
        ; The player reached the deferred-narration sender (arrivedActor is the player): fire
        ; the stored line once.
        If DeferredNarrationSender == None
            ; Already cleared by another path — discard.
            Return
        EndIf
        If DeferredNarrationSender.IsDead()
            ClearDeferredNarration()
            Return
        EndIf
        String pendingNarration = SeverActionsNativeExt.Native_Arrest_GetPendingNarration(DeferredNarrationSender)
        If pendingNarration != ""
            SkyrimNetApi.DirectNarration(pendingNarration, DeferredNarrationSender, arrivedActor)
            DebugMsg("Fired deferred evidence narration from " + DeferredNarrationSender.GetDisplayName() + " via OnArrival")
        EndIf
        ClearDeferredNarration()

    ElseIf strArg == "dispatch_p1_arrived"
        ; Dispatch guard reached the travel destination (the target, or the home marker).
        If DispatchGuard != arrivedActor || DispatchPhase != 1
            DebugMsg("OnArrival(dispatch_p1): stale event (state moved on) - ignoring")
            Return
        EndIf
        DebugMsg("OnArrival(dispatch_p1): guard reached travel destination (final dist " + numArg + ")")
        If DispatchIsHomeInvestigation
            TransitionToSandboxPhase()
        Else
            TransitionToApproachPhase()
        EndIf

    ElseIf strArg == "dispatch_p2_arrived"
        ; Dispatch guard reached arrest range. Mirrors CheckDispatchPhase2_Approach's arrest
        ; block; kept inline because that function's timeout path teleports first.
        If DispatchGuard != arrivedActor || DispatchTarget == None || DispatchPhase != 2
            DebugMsg("OnArrival(dispatch_p2): stale event (state moved on) - ignoring")
            Return
        EndIf
        DebugMsg("OnArrival(dispatch_p2): guard reached prisoner (final dist " + numArg + ") - performing dispatch arrest")
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
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrest.hasArrested", ("" + p2GuardName), ("" + p2TargetName)))

        StartDispatchReturnPhase()

    ElseIf strArg == "dispatch_p5_arrived"
        ; Dispatch guard reached the return destination (sender or jail).
        If DispatchGuard != arrivedActor || DispatchPhase != 5
            DebugMsg("OnArrival(dispatch_p5): stale event (state moved on) - ignoring")
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
    {Same-cell arrest (SkyrimNet action): the guard walks up, arrests, escorts to jail.
     Returns true if the sequence started.}

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

    ; Arrest and kidnap are mutually exclusive: both hold the actor with packages and factions and
    ; their teardowns would fight. The kidnap side mirrors this (_RejectInvalidCaptiveTarget).
    If SeverActionsNativeExt.Native_Kidnap_GetPhase(akTarget) != 0
        DebugMsg("ArrestNPC rejected: target is an active kidnap/restraint victim")
        SkyrimNetApi.RegisterEvent("arrest_failed",             akGuard.GetDisplayName() + " cannot arrest " + akTarget.GetDisplayName() + " - someone else already holds them.",             akGuard, None)
        Return false
    EndIf

    ; Reject only a not-loaded target (process level -1): kLow (0) still runs packages. Off-screen
    ; targets go through the dispatch path, which brings them in itself.
    Int targetProcessLevel = SeverActionsNative.Native_GetActorProcessLevel(akTarget)
    If targetProcessLevel < 0
        DebugMsg("ArrestNPC rejected: target process level " + targetProcessLevel + " (not loaded - use DispatchGuardToArrest for off-screen targets)")
        Return false
    EndIf

    ; No scene preflight: most town NPCs are in some BGSScene at any moment, so rejecting on
    ; GetCurrentScene() blocks nearly every arrest.

    If ArrestState != 0
        DebugMsg("WARNING: Already processing an arrest, canceling previous")
        CancelCurrentArrest()
    EndIf

    ; A crashed prior arrest's residue on these two actors must not block this one.
    ClearStaleArrestState(akTarget, "arrest start")
    ClearStaleArrestState(akGuard, "arrest start")

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

    CurrentGuard = akGuard
    CurrentPrisoner = akTarget
    CurrentJailMarker = jailMarker
    CurrentJailName = jailName
    ArrestState = 1 ; approaching

    ; On task (_BeginGuardTask); every exit of the arrest takes them off (_LeaveTaskFaction).
    _BeginGuardTask(akGuard)

    ; SkyrimNet busy lock (is_busy / busy_reason) on both: the faction above only excludes our own
    ; actions, this keeps other plugins' multi-step actions off them too. Both clear when the arrest
    ; ends, except a jailed prisoner's, which stays until a release path clears it.
    SeverActionsNative.Native_SkyrimNet_SetActorBusy(akGuard, "arrest")
    SeverActionsNative.Native_SkyrimNet_SetActorBusy(akTarget, "arrest")

    ; The packages' CK flags may sheathe it again.
    akGuard.DrawWeapon()

    Float dist = akGuard.GetDistance(akTarget)
    If dist <= ApproachDistance
        DebugMsg("Guard already close to target, proceeding to arrest")
        PerformArrest()
    Else
        DebugMsg("Guard approaching target (distance: " + dist + ")")
        StartApproachPhase()
    EndIf

    Return true
EndFunction

; =============================================================================
; APPROACH PHASE - Guard walks to target
; =============================================================================

Function StartApproachPhase()
    {Guard walks toward the target, weapon drawn, with stuck detection for cross-cell approaches.}

    If CurrentGuard == None || CurrentPrisoner == None
        DebugMsg("ERROR: StartApproachPhase - invalid state")
        Return
    EndIf

    ArrestTarget.ForceRefTo(CurrentPrisoner)
    ArrestingGuard.ForceRefTo(CurrentGuard)

    DebugMsg("Filled ArrestTarget alias with: " + CurrentPrisoner.GetDisplayName())

    ; The approach package targets the ArrestTarget alias.
    If SeverActions_GuardApproachTarget
        ActorUtil.AddPackageOverride(CurrentGuard, SeverActions_GuardApproachTarget, PackagePriority, 1)
        CurrentGuard.EvaluatePackage()
        DebugMsg("Applied approach package to guard")
    Else
        DebugMsg("WARNING: No approach package defined!")
    EndIf

    SeverActionsNativeExt.Stuck_StartTracking(CurrentGuard)

    ApproachStartTime = Utility.GetCurrentRealTime()
    PrisonerMovementFrozen = false
    PrisonerFrozenAt = 0.0

    ; For OnGameLoaded's recovery.
    PersistArrestState()

    ; Native session in kApproach (1): its watchdog times the approach out after 1 game hour.
    Faction approachCrimeFaction = GetCrimeFactionForGuard(CurrentGuard)
    SeverActionsNative.Native_ArrestSession_Begin(CurrentPrisoner, CurrentGuard, CurrentJailMarker, approachCrimeFaction, 1, 0, 0)
    _GuardOffSchedule(CurrentGuard)

    ; ArrivalMonitor fires OnArrival -> PerformArrest at ApproachDistance; the tick below handles
    ; the freeze, the fallback snap and stuck escalation.
    SeverActionsNativeExt.Arrival_Register(CurrentGuard, CurrentPrisoner, ApproachDistance, "arrest_approach_arrived")

    ; Never SetActorArrested (here or later): the engine's IsArrested flag makes vanilla guards stop
    ; pursuing and changes the target's combat AI.

    ChronoArm(UpdateInterval)
EndFunction

Function ChronoArm(Float afSeconds)
    {Arm this script's one-shot chronometer tick (see the Chronometer block in SeverActionsNativeExt2.psc);
     the event AND callback names must stay unique to this script. Re-arm replaces the pending tick; ticks
     don't survive a load; one in-flight tick can land after a cancel, so the handler stays state-guarded.}
    RegisterForModEvent("SeverActions_Tick_Arrest", "OnChronoTick_Arrest")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_Arrest", afSeconds)
EndFunction

Event OnChronoTick_Arrest(String eventName, String strArg, Float numArg, Form sender)
    ; Deferred narration is ArrivalMonitor's (narration_witness on the player); it can't see the
    ; sender die before the player arrives, so sweep that here.
    If DeferredNarrationSender != None && DeferredNarrationSender.IsDead()
        ClearDeferredNarration()
    EndIf

    ; Cross-cell dispatch phases (see the DispatchPhase declaration: 1=traveling,
    ; 2=approaching, 3=sandboxing, 4=collecting evidence, 5=returning, 6=judgment hold)
    If DispatchPhase > 0
        CheckDispatchProgress()
    EndIf

    ; Same-cell arrest states
    If ArrestState == 1
        ; Approaching target
        CheckApproachProgress()
    ElseIf ArrestState == 3
        ; Escorting to jail
        CheckEscortProgress()
    ElseIf ArrestState == 4
        ; Prisoner pleading mid-escort
        CheckEscortPleaProgress()
    EndIf

    ; Nothing in flight: cancel to acknowledge the wake. The chronometer re-sends an unacknowledged
    ; tick every 60 s, so OnGameLoaded's idempotent resume tick would otherwise repeat all session.
    If DispatchPhase == 0 && ArrestState != 1 && ArrestState != 3 && ArrestState != 4
        SeverActionsNativeExt2.Chrono_Cancel("SeverActions_Tick_Arrest")
    EndIf

    ; The player-arrest persuasion and post-resist cleanup tick on SeverActions_ArrestPlayer's own chronometer.
EndEvent

Function CheckApproachProgress()
    {Per-tick approach watchdog. Arrival itself is OnArrival's; this freezes the prisoner inside
     ApproachFreezeDistance (their own AI would keep the distance oscillating around ApproachDistance),
     snaps the guard in after the grace period, and escalates stuck recovery. The hard timeout is
     the kApproach session watchdog (1 game hour; OnArrestSessionTimeout snaps and arrests).}

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

    If CurrentGuard.IsDead()
        DebugMsg("Guard died during approach")
        SeverActionsNativeExt.Stuck_StopTracking(CurrentGuard)
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

        ; Freeze the prisoner once the guard is in freeze range so they can't drift out of arrest
        ; range, but let the guard walk in naturally for ApproachPostFreezeGracePeriod seconds before
        ; the fallback snap below (snapping on freeze is reliable but jarring).
        If !PrisonerMovementFrozen && dist <= ApproachFreezeDistance
            CurrentPrisoner.SetDontMove(true)
            PrisonerMovementFrozen = true
            PrisonerFrozenAt = Utility.GetCurrentRealTime()
            DebugMsg("Approach: prisoner inside " + ApproachFreezeDistance + "u (dist=" + dist + "), frozen - guard walking in naturally (grace=" + ApproachPostFreezeGracePeriod + "s)")
        EndIf

        ; Fallback snap: still out of arrest range after the grace period means the walk has stalled
        ; near the prisoner (path stutter, the package's distance setting).
        If PrisonerMovementFrozen && PrisonerFrozenAt > 0.0
            Float frozenElapsed = Utility.GetCurrentRealTime() - PrisonerFrozenAt
            If frozenElapsed >= ApproachPostFreezeGracePeriod && dist > ApproachDistance
                DebugMsg("Approach: post-freeze grace expired (" + frozenElapsed + "s, dist=" + dist + "u still > " + ApproachDistance + "u) - fallback snap")
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

        ; Distance trace: tells a lying GetDistance (cell mismatch, Z inflation, stale handle) from a
        ; guard that is really parked beside the prisoner.
        DebugMsg("Approach tick: dist=" + dist + " (freeze=" + ApproachFreezeDistance + " arrest=" + ApproachDistance + ")")

        ; Stuck escalation (cross-cell approaches)
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
                SeverActionsNative.Native_MoveToNearestNavmesh(CurrentGuard, 0.0)
                CurrentGuard.EvaluatePackage()
                DebugMsg("Approach: leapfrog guard " + teleportDist + " units toward target")
            EndIf

            SeverActionsNativeExt.Stuck_ResetEscalation(CurrentGuard)
        ElseIf stuckLevel >= 3
            ; Very stuck - force teleport near target
            DebugMsg("Approach: force teleporting guard near target")
            CurrentGuard.MoveTo(CurrentPrisoner, 200.0, 0.0, 0.0)
            SeverActionsNative.Native_MoveToNearestNavmesh(CurrentGuard, 0.0)
            Utility.Wait(0.5)
            CurrentGuard.EvaluatePackage()
            SeverActionsNativeExt.Stuck_ResetEscalation(CurrentGuard)
        EndIf

        ChronoArm(UpdateInterval)
EndFunction

Function UnfreezePrisonerMovement()
    {Release the approach's SetDontMove freeze. Idempotent; every exit from the approach calls it so
     no NPC is left stuck in place.}
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

    ; The snap and timeout paths arrive here without OnArrival (which auto-removes the registration).
    SeverActionsNativeExt.Arrival_Cancel(CurrentGuard)

    ArrestState = 2 ; arresting

    Actor prisoner = CurrentPrisoner
    Actor guard = CurrentGuard

    ; EnsureBegin, not UpdateState: a guard already in range skipped StartApproachPhase, which opens the
    ; session; without an entry CaptureAVs below is a no-op and release falls back to vanilla defaults.
    SeverActionsNative.Native_ArrestSession_EnsureBegin(prisoner, guard, CurrentJailMarker, GetCrimeFactionForGuard(guard), 2, 0, 0)
    ; A guard already in range skipped StartApproachPhase's strip (it is idempotent).
    _GuardOffSchedule(guard)

    DebugMsg("Performing arrest on " + prisoner.GetDisplayName())

    ; Unfreeze before the follow package: SetDontMove blocks its pathing.
    UnfreezePrisonerMovement()

    prisoner.StopCombat()
    prisoner.StopCombatAlarm()

    ; So a travel errand doesn't fight the escort.
    CancelTravelFor(prisoner)

    ; Capture the originals on the session BEFORE zeroing, or the prisoner leaves jail permanently
    ; pacified. CaptureAVs only fills fields still at the -1 sentinel, so a second PerformArrest
    ; cannot capture the zeros.
    SeverActionsNative.Native_ArrestSession_CaptureAVs(prisoner, prisoner.GetAV("Aggression"), prisoner.GetAV("Confidence"))
    prisoner.SetAV("Aggression", 0)
    prisoner.SetAV("Confidence", 0)

    prisoner.AddToFaction(dunPrisonerFaction)      ; Guards won't attack
    prisoner.AddToFaction(SeverActions_Arrested)   ; Triggers follow package

    If SeverActions_PrisonerCuffs
        prisoner.EquipItem(SeverActions_PrisonerCuffs, true, true) ; abPreventRemoval, abSilent
    EndIf

    ; Link prisoner to guard so follow package works
    SeverActionsNative.LinkedRef_Set(prisoner, guard, SeverActions_FollowTargetKW)
    DebugMsg("Linked prisoner to guard for follow")

    ; Break any animation lock from PlayIdle before activating follow package
    Debug.SendAnimationEvent(prisoner, "IdleForceDefaultState")
    Utility.Wait(0.1)

    If SeverActions_FollowGuard_Prisoner
        ActorUtil.AddPackageOverride(prisoner, SeverActions_FollowGuard_Prisoner, PackagePriority, 1)
        prisoner.EvaluatePackage()
        DebugMsg("Applied follow package to prisoner")
    EndIf

    ; The bound-hands pose goes LAST, after the package's EvaluatePackage: the IdleForceDefaultState
    ; above cancels any earlier idle. The cuffs item does not pose the hands; this offset idle does,
    ; and it survives the walk. The kidnap march follows the same order.
    If OffsetBoundStandingStart
        prisoner.PlayIdle(OffsetBoundStandingStart)
    EndIf

    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrest.arrested", ("" + guard.GetDisplayName()), ("" + prisoner.GetDisplayName())))

    ; Direct narration for prisoner to react to being arrested
    String narration = "*" + guard.GetDisplayName() + " places " + prisoner.GetDisplayName() + " under arrest and binds their hands.*"
    SkyrimNetApi.DirectNarration(narration, prisoner, guard)

    ; Register persistent event for SkyrimNet - guard arrested prisoner
    String arrestMessage = guard.GetDisplayName() + " has arrested " + prisoner.GetDisplayName() + " and is escorting them to " + CurrentJailName + "."
    SkyrimNetApi.RegisterPersistentEvent(arrestMessage, guard, None)

    ; Small delay for animations/packages to settle
    Utility.Wait(1.0)

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

    JailDestination.ForceRefTo(CurrentJailMarker)
    DebugMsg("Filled JailDestination alias with: " + CurrentJailMarker)

    ; The guard's travel package targets the JailDestination alias.
    If SeverActions_GuardEscortPackage
        ActorUtil.AddPackageOverride(CurrentGuard, SeverActions_GuardEscortPackage, PackagePriority, 1)
        CurrentGuard.EvaluatePackage()
        DebugMsg("Applied travel package to guard")
    Else
        DebugMsg("WARNING: No guard travel package defined!")
    EndIf

    EscortStartTime = Utility.GetCurrentRealTime()

    ; For OnGameLoaded's recovery.
    PersistArrestState()

    ; kEscort (3), a 6-game-hour watchdog. EnsureBegin, not UpdateState: the judgment -> jail
    ; handoff (EndJudgment -> ClearDispatchState) has already ended the session, and UpdateState
    ; would no-op, leaving the escort with no watchdog and no Magelight row.
    Faction escortCrimeFaction = GetCrimeFactionForGuard(CurrentGuard)
    SeverActionsNative.Native_ArrestSession_EnsureBegin(CurrentPrisoner, CurrentGuard, CurrentJailMarker, escortCrimeFaction, 3, 0, 0)

    ; The native EscortPackageReapplier re-applies our overrides (OnEscortReapplyPackages) when a
    ; cell attach or combat end drops them.
    SeverActionsNative.Native_EscortReapply_Begin(CurrentGuard, CurrentPrisoner)

    ; ArrivalMonitor fires OnArrival -> OnArrivedAtJail at ArrivalDistance of the marker.
    SeverActionsNativeExt.Arrival_Register(CurrentGuard, CurrentJailMarker, ArrivalDistance, "arrest_escort_arrived")

    ; Physical leash for the walk to jail, when the player has the framework.
    _ArrestLeash(CurrentPrisoner, CurrentGuard, true)

    ; Ticks for CheckEscortProgress's death checks.
    ChronoArm(UpdateInterval)
EndFunction

Bool Function _IsOurLeashSubject(Actor akActor)
    {True for a rope THIS module owns: a live arrest session and no kidnap entry. The kidnap side uses
     the same library and SeverKidnap_PhysLeash mark, so excluding any kidnap phase keeps the two
     handler sets disjoint.}
    Return akActor && SeverActionsNative.Native_ArrestSession_HasSession(akActor) \
        && SeverActionsNativeExt.Native_Kidnap_GetPhase(akActor) == 0
EndFunction

Event OnLeashFrameworkPulled(String eventName, String strArg, Float numArg, Form sender)
    {The framework started hauling someone on a rope. numArg = holder-to-collar distance.}
    Actor pulled = sender as Actor
    If SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled() && _IsOurLeashSubject(pulled)
        SeverActions_LeashLib.NarratePull(pulled, False, numArg, CurrentGuard, "the guard")
    EndIf
EndEvent

Event OnLeashFrameworkRagdollPulled(String eventName, String strArg, Float numArg, Form sender)
    {A forced ragdoll pull - the prisoner dug in past the threshold and is being dragged.}
    Actor ragdolled = sender as Actor
    If !_IsOurLeashSubject(ragdolled)
        Return
    EndIf
    If SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled()
        SeverActions_LeashLib.NarratePull(ragdolled, True, numArg, CurrentGuard, "the guard")
    EndIf
    ; Restore the bound-hands pose the ragdoll cost them. The idle is passed in: the library never
    ; reaches into a script.
    If SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled()
        SeverActions_LeashLib.RestoreBoundPose(ragdolled, OffsetBoundStandingStart)
    EndIf
EndEvent

Event OnLeashFrameworkUnleash(String eventName, String strArg, Float numArg, Form sender)
    {The framework dropped a rope (strArg: disconnected / unleashAll / replaced): clear our live-rope
     mark so the escort re-attaches once the guard is loaded. Our own detach unsets the mark before
     calling the framework, so it returns early here.}
    Actor v = sender as Actor
    If !_IsOurLeashSubject(v) || StorageUtil.GetIntValue(v, "SeverKidnap_PhysLeash", 0) != 1
        Return
    EndIf
    StorageUtil.UnsetIntValue(v, "SeverKidnap_PhysLeash")
    DebugMsg("LeashFramework: escort rope on " + v.GetDisplayName() + " dropped by the framework (" + strArg + ") - it re-attaches when the guard is loaded")
EndEvent

Function _ArrestLeash(Actor akPrisoner, Actor akGuard, Bool abOn)
    {Rope from the guard's hand to the prisoner's bound wrists for the escort (SeverActions_LeashLib),
     layered over the escort-follow package as for a led captive; a silent no-op with the setting off.
     Safe with no kidnap entry: the flag mirroring (KidnapStore::SetFlag) no-ops, so no captive record
     is fabricated. Without the framework, abOn=false only clears rope marks a save recorded before it
     was removed, through SeverActions_Kidnap (this module's own script, so a cast).}
    If !akPrisoner
        Return
    EndIf
    If abOn
        If akGuard
            If SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled()
                SeverActions_LeashLib.Attach(akPrisoner, akGuard)
            EndIf
        EndIf
    Else
        If SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled()
            SeverActions_LeashLib.Detach(akPrisoner)
        Else
            ; No framework: clear the stale rope marks (kidnap state, see the doc).
            SeverActions_Kidnap kidnapMarks = (Self as Quest) as SeverActions_Kidnap
            If kidnapMarks
                kidnapMarks._ClearLeashMarks(akPrisoner)
            EndIf
        EndIf
    EndIf
EndFunction

Function CheckEscortProgress()
    {Per-tick escort check: deaths only. Arrival is OnArrival's (ArrivalMonitor), package re-apply
     is the native EscortPackageReapplier's, and the timeout is the kEscort session watchdog's
     (6 game hours, TimeoutForState in ArrestSessionStore.h).}

    If CurrentGuard == None || CurrentPrisoner == None || CurrentJailMarker == None
        DebugMsg("ERROR: CheckEscortProgress - invalid state")
        CancelCurrentArrest()
        Return
    EndIf

    If CurrentGuard.IsDead()
        DebugMsg("Guard died during escort")
        ; ReleasePrisoner already clears LinkedRefs on the prisoner.
        ReleasePrisoner(CurrentPrisoner)
        CancelCurrentArrest()
        Return
    EndIf

    If CurrentPrisoner.IsDead()
        DebugMsg("Prisoner died during escort")
        ; Clear the dead prisoner's LinkedRefs now: the native TESDeathEvent cleanup is async and
        ; CancelCurrentArrest doesn't wait for it.
        SeverActionsNative.LinkedRef_Clear(CurrentPrisoner, SeverActions_FollowTargetKW)
        SeverActionsNative.LinkedRef_Clear(CurrentPrisoner, SeverActions_SandboxAnchorKW)
        CancelCurrentArrest()
        Return
    EndIf

    ChronoArm(UpdateInterval)
EndFunction

; =============================================================================
; ESCORT PLEA - the NPC prisoner's one mid-march appeal (ArrestState 3 -> 4).
; The guard stops, follows the prisoner with weapon drawn and listens. Accept
; releases them; Reject, a timeout or walking off resumes the escort.
; EscortPleaAttempted allows one per arrest. The NPC twin of PlayerScript's
; HandlePersuade flow.
; =============================================================================

Bool Function AppealDuringEscort_Internal(Actor akPrisoner)
    {The prisoner pleads to the escorting guard mid-march (appealduringescort.yaml, speaker = prisoner).
     False when not escorting, not the current prisoner, or already pleaded this arrest.}

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

    ; No jail arrival during the plea (the guard could pass the marker while following the prisoner).
    SeverActionsNativeExt.Arrival_Cancel(CurrentGuard)

    If SeverActions_GuardEscortPackage
        ActorUtil.RemovePackageOverride(CurrentGuard, SeverActions_GuardEscortPackage)
    EndIf

    ; SeverActions_GuardFollowPlayer follows whatever FollowTargetKW points at, so pointing it at the
    ; prisoner makes the guard track them (HandlePersuade's trick for the player).
    SeverActionsNative.LinkedRef_Set(CurrentGuard, akPrisoner, SeverActions_FollowTargetKW)

    If SeverActions_GuardFollowPlayer
        ActorUtil.AddPackageOverride(CurrentGuard, SeverActions_GuardFollowPlayer, PackagePriority, 1)
        CurrentGuard.EvaluatePackage()
    EndIf

    ; Keep weapon drawn — the threat persists during the plea
    CurrentGuard.DrawWeapon()

    ; Drop the prisoner's follow-guard package, or the two follow each other in a loop.
    If SeverActions_FollowGuard_Prisoner
        ActorUtil.RemovePackageOverride(akPrisoner, SeverActions_FollowGuard_Prisoner)
    EndIf
    akPrisoner.EvaluatePackage()

    ; --- Update FSM state ---
    ArrestState = 4
    EscortPleaStartTime = Utility.GetCurrentRealTime()
    EscortPleaAttempted = true

    ; kEscortPlea (8): a 15-game-minute watchdog, shown as Escort Plea on the Magelight arrests page.
    ; It also latches the plea for the session: sever_is_escorted_prisoner stops offering the appeal.
    SeverActionsNative.Native_ArrestSession_UpdateState(CurrentPrisoner, 8, 0)

    ; --- Set context for SkyrimNet so the LLM has the full picture ---
    String holdName = GetHoldNameForGuard(CurrentGuard)
    Int bounty = 0
    If BountyScript
        bounty = BountyScript.GetTrackedBountyForGuard(CurrentGuard)
    EndIf

    String narration = "*" + CurrentGuard.GetDisplayName() + " halts the march, weapon still in hand, willing to hear what " + akPrisoner.GetDisplayName() + " has to say.*"
    SkyrimNetApi.DirectNarration(narration, akPrisoner, CurrentGuard)

    String eventMsg = akPrisoner.GetDisplayName() + " stopped the march to plead with " + CurrentGuard.GetDisplayName() + " over a " + bounty + " gold bounty in " + holdName + "."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, CurrentGuard, akPrisoner)

    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrest.theEscortPauses", ("" + CurrentGuard.GetDisplayName())))

    ; Make sure the tick is armed for the per-tick check
    ChronoArm(UpdateInterval)

    Return true
EndFunction

Function CheckEscortPleaProgress()
    {Tick while ArrestState == 4: ends the plea on a timeout, the prisoner walking off, or a death.}

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
        DebugMsg("Escort plea timed out after " + elapsed + "s - resuming escort")
        String narration = "*" + CurrentGuard.GetDisplayName() + " grows tired of " + CurrentPrisoner.GetDisplayName() + "'s excuses, cuts the plea short and orders them to keep moving.*"
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
        DebugMsg("Escort plea: prisoner moved " + distance + "u from guard - resuming escort")
        String narration = "*" + CurrentGuard.GetDisplayName() + " catches up, gripping " + CurrentPrisoner.GetDisplayName() + " firmly - no more slipping away; the march goes on.*"
        SkyrimNetApi.DirectNarration(narration, CurrentPrisoner, CurrentGuard)

        String eventMsg = CurrentPrisoner.GetDisplayName() + " tried to walk away during their plea. " + CurrentGuard.GetDisplayName() + " resumed the escort to jail."
        SkyrimNetApi.RegisterPersistentEvent(eventMsg, CurrentGuard, CurrentPrisoner)

        ResumeEscortFromPlea()
        Return
    EndIf

    ; Still in plea — keep ticking
    ChronoArm(UpdateInterval)
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

    ; Rope off (one of the four escort exits, with arrival, cancel and jail release). BELOW the
    ; rejections: a rejected call leaves the escort live, and nothing would re-attach the rope.
    _ArrestLeash(CurrentPrisoner, CurrentGuard, false)

    DebugMsg(akGuard.GetDisplayName() + " accepted " + CurrentPrisoner.GetDisplayName() + "'s plea - releasing")

    ; Capture refs before clearing state
    Actor releasedPrisoner = CurrentPrisoner
    Actor escortingGuard = CurrentGuard

    String narration = "*" + escortingGuard.GetDisplayName() + " sighs, lowers their weapon and waves " + releasedPrisoner.GetDisplayName() + " off - free to go, and warned not to be seen again.*"
    SkyrimNetApi.DirectNarration(narration, releasedPrisoner, escortingGuard)

    String eventMsg = escortingGuard.GetDisplayName() + " was convinced by " + releasedPrisoner.GetDisplayName() + " and released them mid-escort instead of taking them to jail."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, escortingGuard, releasedPrisoner)

    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrest.hasBeenReleased", ("" + releasedPrisoner.GetDisplayName())))

    ; --- Clean up packages on guard ---
    SeverActionsNativeExt.Stuck_StopTracking(escortingGuard)
    If SeverActions_GuardFollowPlayer
        ActorUtil.RemovePackageOverride(escortingGuard, SeverActions_GuardFollowPlayer)
    EndIf
    SeverActionsNative.LinkedRef_Clear(escortingGuard, SeverActions_FollowTargetKW)
    escortingGuard.SheatheWeapon()

    ; Release the SkyrimNet on-task lock + busy lock
    _LeaveTaskFaction(escortingGuard)
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

    DebugMsg(akGuard.GetDisplayName() + " rejected " + CurrentPrisoner.GetDisplayName() + "'s plea - resuming escort")

    ; Guard's own dialogue follows via SkyrimNet — just register the event for context
    String eventMsg = akGuard.GetDisplayName() + " was not convinced by " + CurrentPrisoner.GetDisplayName() + "'s pleading and resumed the escort to jail."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, akGuard, CurrentPrisoner)

    Debug.Notification(SeverActionsNativeExt2.Native_L10n("arrest.thePleaWasRejected"))

    ResumeEscortFromPlea()
    Return true
EndFunction

Function ResumeEscortFromPlea()
    {Back to the escort (ArrestState 3) after a rejected, timed-out or abandoned plea. The native
     EscortPackageReapplier stays armed across the plea (same actor pair), so it is not re-begun here.}

    If CurrentGuard == None || CurrentPrisoner == None || CurrentJailMarker == None
        DebugMsg("ERROR: ResumeEscortFromPlea - invalid state, canceling")
        CancelCurrentArrest()
        Return
    EndIf

    ; Remove the listen-to-prisoner package
    If SeverActions_GuardFollowPlayer
        ActorUtil.RemovePackageOverride(CurrentGuard, SeverActions_GuardFollowPlayer)
    EndIf

    ; The guard's link to the prisoner; ReapplyEscortPackages re-links the prisoner to the guard.
    SeverActionsNative.LinkedRef_Clear(CurrentGuard, SeverActions_FollowTargetKW)

    ; In case something cleared the aliases during the plea.
    ArrestTarget.ForceRefTo(CurrentPrisoner)
    ArrestingGuard.ForceRefTo(CurrentGuard)
    If CurrentJailMarker != None
        JailDestination.ForceRefTo(CurrentJailMarker)
    EndIf

    ; Re-apply escort package + prisoner follow package (mirrors StartEscortPhase)
    ReapplyEscortPackages(CurrentGuard, CurrentPrisoner, CurrentJailMarker)

    ; Re-arm stuck tracking — the guard is moving toward jail again
    SeverActionsNativeExt.Stuck_StartTracking(CurrentGuard)

    ArrestState = 3
    EscortStartTime = Utility.GetCurrentRealTime()
    EscortPleaStartTime = 0.0

    ; Reset the watchdog timer to the escort budget
    SeverActionsNative.Native_ArrestSession_UpdateState(CurrentPrisoner, 3, 0)

    ; Re-register the jail arrival the plea cancelled.
    SeverActionsNativeExt.Arrival_Register(CurrentGuard, CurrentJailMarker, ArrivalDistance, "arrest_escort_arrived")

    DebugMsg("Resumed escort from plea - " + CurrentGuard.GetDisplayName() + " escorting " + CurrentPrisoner.GetDisplayName() + " to " + CurrentJailName)

    ChronoArm(UpdateInterval)
EndFunction

; =============================================================================
; ARRIVAL - Process prisoner at jail
; =============================================================================

Function OnArrivedAtJail()
    {Guard and prisoner have arrived at jail - finalize arrest}

    ; Rope off first, even ahead of the invalid-state bail: a half-torn-down arrest can still leave
    ; a real rope on a real prisoner.
    _ArrestLeash(CurrentPrisoner, CurrentGuard, false)

    If CurrentGuard == None || CurrentPrisoner == None
        DebugMsg("ERROR: OnArrivedAtJail - invalid state")
        CancelCurrentArrest()
        Return
    EndIf

    ; The watchdog's finalize arrives here without OnArrival (which auto-removes the registration).
    SeverActionsNativeExt.Arrival_Cancel(CurrentGuard)

    ArrestState = 5 ; arrived (transient; 4 is the escort plea, which the tick routes)
    JailPrisonerAt(CurrentGuard, CurrentPrisoner, CurrentJailMarker, CurrentJailName, true)
EndFunction

Function JailPrisonerAt(Actor guard, Actor prisoner, ObjectReference jailMarker, String jailName, Bool abSameCell)
    {Put prisoner in the cell at jailMarker and finish the arrest. abSameCell: the same-cell arrest's
     (OnArrivedAtJail), whose aliases and slots this clears; false for a dispatch's delivery, which
     leaves both to a same-cell arrest that may be running.}

    DebugMsg("Processing prisoner at jail: " + prisoner.GetDisplayName())

    ; Every arrest package (idempotent); PrisonerSandBox is re-applied below unless the prisoner is disabled.
    RemoveAllArrestPackages(guard)
    RemoveAllArrestPackages(prisoner)

    ; Only the follow link, not ClearAllDispatchLinkedRefs: SandboxAnchorKW is re-set below.
    SeverActionsNative.LinkedRef_Clear(prisoner, SeverActions_FollowTargetKW)

    ; Keep the dispatch aliases if a cross-cell dispatch is still running - this is the same-cell arrest ending.
    If abSameCell
        ClearAllArrestAliases(DispatchPhase > 0)
    EndIf

    prisoner.RemoveFromFaction(SeverActions_Arrested)
    prisoner.AddToFaction(SeverActions_Jailed)

    ; MoveTo, then a navmesh snap. Never Disable/Enable to re-place an actor: it breaks alias
    ; attachment and package overrides.
    If jailMarker
        prisoner.MoveTo(jailMarker, 0.0, 0.0, 0.0)
        Utility.Wait(0.3)
        SeverActionsNative.Native_MoveToNearestNavmesh(prisoner, 0.0)
        Utility.Wait(0.2)

        Float distToJail = prisoner.GetDistance(jailMarker)
        ; One retry if the snap landed farther than JailMarkerVerifyDistance.
        If distToJail > JailMarkerVerifyDistance
            DebugMsg("Initial MoveTo+navmesh placed prisoner " + distToJail + "u from marker - retrying")
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

    ; JailedNPCStore is the only record. The marker is passed in: the store has no entry for a new
    ; prisoner yet, so reading it back would store 0 and leave the load-time reposition no target.
    ; The faction of the local guard: CurrentGuard may be another arrest's by now.
    AddJailedNPCAt(prisoner, jailMarker, crimeFaction)

    If DisablePrisonerOnArrival
        ; "In jail" means removed from the world.
        Utility.Wait(0.5)
        prisoner.Disable()
        DebugMsg("Prisoner disabled (jailed)")
    Else
        ; Keep prisoner active with sandbox package
        If SeverActions_PrisonerSandBox && jailMarker
            ; Per-actor sandbox anchor. Permanent (LREF v3): a sentence can outlast the 30-day
            ; staleness prune, which would leave the prisoner on default AI.
            SeverActionsNativeExt.LinkedRef_SetPermanent(prisoner, jailMarker, SeverActions_SandboxAnchorKW)
            ActorUtil.AddPackageOverride(prisoner, SeverActions_PrisonerSandBox, PackagePriority + 10, 1)
            prisoner.EvaluatePackage()
            DebugMsg("Prisoner sandboxing in jail (linked to marker)")
        Else
            DebugMsg("WARNING: No jail sandbox package or marker - prisoner may escape!")
            prisoner.EvaluatePackage()
        EndIf
    EndIf

    guard.SheatheWeapon()

    ; Pair of ArrestNPC_Internal's on-task faction.
    _LeaveTaskFaction(guard)

    ; The guard's busy lock only: the prisoner's stays while jailed (it survives save/load) so other
    ; plugins leave them alone; the release paths clear it.
    SeverActionsNative.Native_SkyrimNet_ClearActorBusy(guard)

    guard.EvaluatePackage()

    ; Direct narration for prisoner to react to being put in the cell
    String cellNarration = "*" + guard.GetDisplayName() + " locks " + prisoner.GetDisplayName() + " in a jail cell.*"
    SkyrimNetApi.DirectNarration(cellNarration, prisoner, guard)

    ; Register persistent event for SkyrimNet - prisoner delivered to jail
    String jailMessage = prisoner.GetDisplayName() + " has been jailed in " + jailName + "."
    SkyrimNetApi.RegisterPersistentEvent(jailMessage, prisoner, None)

    ; The waits above let a cancel or a new arrest run: clear only the slots this jailing still owns.
    Bool ownsSlots = abSameCell && (CurrentPrisoner == prisoner || CurrentPrisoner == None)

    ; Arrest complete: drop the save/load recovery state.
    If ownsSlots
        ClearPersistedArrestState()
        ApproachStartTime = 0.0
        EscortStartTime = 0.0
    EndIf

    ; kJailed (9, no watchdog) instead of ending the session: RestorePrisonerStats reads the
    ; pre-arrest Aggression/Confidence off it at release, and ClearPrisonerCommonArtifacts ends it.
    SeverActionsNative.Native_ArrestSession_UpdateState(prisoner, 9, 0)

    ; Clear state (do this last since we stored local copies)
    If ownsSlots
        ClearArrestState()
    EndIf

    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrest.hasBeenJailed", ("" + prisoner.GetDisplayName())))
    DebugMsg("Arrest complete - prisoner delivered to " + jailName)
EndFunction

Function CancelTravelFor(Actor akActor)
    {Cancel akActor's journey or wait (restoring a follower) before the arrest takes their packages.
     A direct call: travelcore is in arrest's requires closure.}
    If akActor == None
        Return
    EndIf
    SeverActions_TravelCore.CancelJourney(akActor, true)
EndFunction

Function ChangeToJailClothes(Actor akPrisoner, Faction akCrimeFaction)
    {Cuffs off and SetOutfit the faction's jail outfit (else the property), which persists through
     cell loads. The outfit lock is suspended around it so a follower's OutfitAlias doesn't fight the
     SetOutfit; the lock is the kernel's, so this holds without the Outfit module.}

    SeverActionsNativeExt.Native_Outfit_SuspendLock(akPrisoner)

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

    If jailOutfit
        ; The original outfit goes on the ArrestSession (v3) for the release.
        Outfit originalOutfit = akPrisoner.GetActorBase().GetOutfit()
        If originalOutfit
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

    SeverActionsNativeExt.Native_Outfit_ResumeLock(akPrisoner)
    SeverActionsNative.Native_Outfit_ClearBurstSuppression(akPrisoner)
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

    ; Rope off first - a cancelled arrest must not leave the guard holding one.
    _ArrestLeash(CurrentPrisoner, CurrentGuard, false)

    ; Unfreeze first so a cancel mid-approach never leaves the prisoner frozen.
    UnfreezePrisonerMovement()

    ; Any pending arrival registration (idempotent).
    If CurrentGuard
        SeverActionsNativeExt.Arrival_Cancel(CurrentGuard)
    EndIf

    If CurrentGuard
        SeverActionsNativeExt.Stuck_StopTracking(CurrentGuard)

        ; Every arrest package (approach, escort, plea follow, any dispatch ones). Idempotent.
        RemoveAllArrestPackages(CurrentGuard)
        ; The plea's FollowTargetKW link; harmless in any other state.
        SeverActionsNative.LinkedRef_Clear(CurrentGuard, SeverActions_FollowTargetKW)

        ; Pair of ArrestNPC_Internal's on-task faction.
        _LeaveTaskFaction(CurrentGuard)

        SeverActionsNative.Native_SkyrimNet_ClearActorBusy(CurrentGuard)

        CurrentGuard.SheatheWeapon()
        CurrentGuard.EvaluatePackage()
    EndIf

    If CurrentPrisoner && ArrestState >= 2 && ArrestState != 5
        ; Arrested: release them (ReleasePrisoner clears the busy lock). Never in state 5, OnArrivedAtJail's
        ; finalize window: a release there strips Jailed from a prisoner who is logically jailed;
        ; OrderRelease / FreeNPC_Internal are the exits from state 5.
        ReleasePrisoner(CurrentPrisoner)
    ElseIf CurrentPrisoner && ArrestState != 5
        ; Approach (1): no ReleasePrisoner here, so clear the busy lock ArrestNPC_Internal set. In state 5
        ; the jailed prisoner keeps it (OnArrivedAtJail).
        SeverActionsNative.Native_SkyrimNet_ClearActorBusy(CurrentPrisoner)
    EndIf

    ; Drop the save/load recovery state.
    ClearPersistedArrestState()
    ApproachStartTime = 0.0
    EscortStartTime = 0.0

    ; Not in state 5: OnArrivedAtJail is finishing the jailing, which keeps the session (kJailed)
    ; for the pre-arrest AVs and outfit the release restores.
    If CurrentPrisoner != None && ArrestState != 5
        SeverActionsNative.Native_ArrestSession_End(CurrentPrisoner)
    EndIf

    ; Only a dispatch about THIS arrest: the two FSMs run concurrently. Not in state 5: the jailing
    ; is finishing on its own.
    If DispatchPhase > 0 && ArrestState != 5 && (DispatchTarget == CurrentPrisoner || DispatchGuard == CurrentGuard)
        CancelDispatch()
    EndIf

    ClearAllArrestAliases(DispatchPhase > 0)

    ClearArrestState()
EndFunction

Function ClearPrisonerCommonArtifacts(Actor akActor)
    {Idempotent teardown shared by ReleasePrisoner (mid-arrest) and ReleaseFromJailCore (post-jail):
     drops Jailed and dunPrisonerFaction, the sandbox package and anchor, the SkyrimNet busy lock and
     the JailedNPCStore row, restores Aggression/Confidence, then ends the session. Phase-specific work
     (cuffs, mid-arrest factions, follow link; the outfit restore) stays in the callers.}

    akActor.RemoveFromFaction(SeverActions_Jailed)
    akActor.RemoveFromFaction(dunPrisonerFaction)

    If SeverActions_PrisonerSandBox
        ActorUtil.RemovePackageOverride(akActor, SeverActions_PrisonerSandBox)
    EndIf
    SeverActionsNative.LinkedRef_Clear(akActor, SeverActions_SandboxAnchorKW)

    SeverActionsNative.Native_SkyrimNet_ClearActorBusy(akActor)
    SeverActionsNativeExt.Native_Jailed_Remove(akActor)

    ; The arrest leaves HealRate alone: lowering it needs its original stored on the session, since
    ; RestoreAV only heals damage up to the base and cannot undo a SetAV.
    RestorePrisonerStats(akActor)

    ; Only after RestorePrisonerStats has read the session. Idempotent (a mid-arrest path may have ended it).
    SeverActionsNative.Native_ArrestSession_End(akActor)
EndFunction

Function ReleasePrisoner(Actor akPrisoner)
    {Release a prisoner mid-arrest: cuffs, mid-arrest factions and the follow-guard package, then
     ClearPrisonerCommonArtifacts.}

    If akPrisoner == None
        Return
    EndIf

    DebugMsg("Releasing prisoner: " + akPrisoner.GetDisplayName())

    ; Mid-arrest factions — only on this path.
    akPrisoner.RemoveFromFaction(SeverActions_WaitingArrest)
    akPrisoner.RemoveFromFaction(SeverActions_Arrested)

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
    {Jail-release core for FreeNPC_Internal and FreePrisonerDirect: ClearPrisonerCommonArtifacts plus
     restoring the original outfit (outfit lock suspended). Callers handle the guard, animations,
     narration, tracking removal and EvaluatePackage.}
    ; Belt: a rope survives to here only if the escort teardown was skipped (a reload mid-escort,
    ; another exit). Idempotent.
    _ArrestLeash(akTarget, None, false)

    ; Read the original outfit BEFORE ClearPrisonerCommonArtifacts ends the session that holds it.
    Outfit originalOutfit = SeverActionsNativeExt.Native_ArrestSession_GetOriginalOutfit(akTarget) as Outfit

    ClearPrisonerCommonArtifacts(akTarget)

    ; Suspend the outfit lock so a follower's OutfitAlias doesn't fight the restore.
    SeverActionsNativeExt.Native_Outfit_SuspendLock(akTarget)
    If originalOutfit
        akTarget.SetOutfit(originalOutfit)
        DebugMsg("Restored original outfit for " + akTarget.GetDisplayName())
    ElseIf SeverActions_PrisonerRags
        akTarget.UnequipItem(SeverActions_PrisonerRags, false, true)
        akTarget.RemoveItem(SeverActions_PrisonerRags, 1, true)
    EndIf

    SeverActionsNativeExt.Native_Outfit_ResumeLock(akTarget)
    SeverActionsNative.Native_Outfit_ClearBurstSuppression(akTarget)
EndFunction

Function RestorePrisonerStats(Actor akActor)
    {Restore Aggression and Confidence from the pre-arrest originals captured on the ArrestSession
     (PerformArrest / ApplyDispatchArrestEffects). They are base attributes (0-3 Unaggressive..Frenzied,
     0-4 Cowardly..Foolhardy), so only SetAV with the original works; RestoreAV does nothing.}
    If !akActor
        Return
    EndIf

    ; Fallbacks: the legacy SeverArrest_Orig* StorageUtil keys (a save mid-arrest across the v1->v2
    ; cosave bump lost its session entry), then vanilla defaults Aggression 1 / Confidence 2.
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
; CROSS-SCRIPT ACCESSORS for the sub-scripts (JudgmentScript, PlayerScript).
; The dispatch and same-cell state is script-local and persisted in the native
; 'AARS'/'ARDC' records, not as Auto properties. Keep this list to what the
; sub-scripts need.
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
    {Set the four same-cell arrest slots: JudgmentScript's judgment (dispatch phase 6) -> escort handoff.}
    CurrentGuard = akGuard
    CurrentPrisoner = akPrisoner
    CurrentJailMarker = akJailMarker
    CurrentJailName = asJailName
EndFunction

Function ClearArrestState()
    {Clear all tracking state}

    CurrentGuard = None
    CurrentPrisoner = None
    CurrentJailMarker = None
    CurrentJailName = ""
    ArrestState = 0
    ; The next arrest gets a fresh plea.
    EscortPleaStartTime = 0.0
    EscortPleaAttempted = false

    ; The EscortPackageReapplier (idempotent).
    SeverActionsNative.Native_EscortReapply_End()

    ; The dispatch FSM shares this script's one chronometer slot: keep it armed while a dispatch
    ; runs, or its ticks stop until the native watchdog notices.
    If DispatchPhase > 0
        ChronoArm(UpdateInterval)
    Else
        SeverActionsNativeExt2.Chrono_Cancel("SeverActions_Tick_Arrest")
    EndIf
EndFunction

; =============================================================================
; CLEANUP HELPERS - the package strip and alias clear every exit path shares,
; so a new package needs one edit.
; =============================================================================

Function RemoveAllArrestPackages(Actor akActor)
    {Strip every arrest-related package override from akActor. Idempotent (RemovePackageOverride
     no-ops on a package the actor doesn't hold).}

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

Bool Function _DispatchAliasesBorrowed()
    {TRUE while a kidnap leg borrows the dispatch aliases for its high-process legs (the guard alias
     holds an active kidnapper; see SeverActions_Kidnap._LaunchGrabLeg). Arrest dispatch must not
     ForceRefTo over it: the kidnapper would chase the arrest target and the victim drop to low process.}
    If DispatchGuardAlias == None
        Return false
    EndIf
    Actor dgRef = DispatchGuardAlias.GetReference() as Actor
    If dgRef && SeverActionsNativeExt.Native_Kidnap_FindVictimOf(dgRef) != None
        Return true
    EndIf
    Return false
EndFunction

Bool Function IsSameCellArrestActive()
    {True while a same-cell arrest runs: its slots and ArrestTarget / ArrestingGuard / JailDestination are in use.}
    Return ArrestState != 0
EndFunction

Function ClearDispatchExitAliases()
    {A dispatch exit's alias clear: the dispatch aliases always, the same-cell arrest's only while none
     is running (they drive its guard's packages).}
    If !IsSameCellArrestActive()
        ArrestTarget.Clear()
        ArrestingGuard.Clear()
        JailDestination.Clear()
    EndIf
    _ClearDispatchAliases()
EndFunction

Function JailDispatchPrisonerNow(Actor akGuard, Actor akPrisoner, ObjectReference akJailMarker, String asJailName)
    {The judgment's jail order while a same-cell arrest holds the escort slots: the dispatch state is
     cleared, then the prisoner goes straight to the cell.}
    ; Cleared first: the judgment's tick would otherwise run during the jailing's waits and re-apply
    ; the prisoner's follow package or jail them again. The session must survive (release reads it),
    ; so ClearDispatchState must not end it.
    DispatchTarget = None
    ClearDispatchExitAliases()
    ClearPersistedDispatchState()
    ClearDispatchState()
    JailPrisonerAt(akGuard, akPrisoner, akJailMarker, asJailName, false)
EndFunction

Function ClearAllArrestAliases(Bool abKeepDispatch = false)
    {Clear every arrest / dispatch alias; safe from any cleanup path. abKeepDispatch keeps the dispatch
     aliases for a caller ending the SAME-CELL arrest while a dispatch runs: its packages resolve their
     destination through them and nothing refills them per tick.}

    ArrestTarget.Clear()
    ArrestingGuard.Clear()
    JailDestination.Clear()
    If abKeepDispatch
        If DispatchTravelDestination != None
            DispatchTravelDestination.Clear()
        EndIf
    Else
        _ClearDispatchAliases()
    EndIf
EndFunction

Function _ClearDispatchAliases()
    {The dispatch aliases and DispatchTravelDestination, leaving any a live kidnap leg borrowed (its
     _EndDispatchAliases hands them back).}
    If !_DispatchAliasesBorrowed()
        DispatchGuardAlias.Clear()
        DispatchTargetAlias.Clear()
        If DispatchPrisonerAlias != None
            DispatchPrisonerAlias.Clear()
        EndIf
    EndIf
    If DispatchTravelDestination != None
        DispatchTravelDestination.Clear()
    EndIf
EndFunction

Function ReapplyEscortPackages(Actor akGuard, Actor akPrisoner, ObjectReference akJailMarker)
    {(Re)apply the escort packages: the guard's GuardEscortPackage to JailDestination, the prisoner's
     FollowGuard_Prisoner to the guard through FollowTargetKW. ResumeEscortFromPlea and
     RecoverActiveArrest use it; StartEscortPhase keeps an inline copy.}

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
; HOLD HELPERS (AddBountyToPlayer_Internal lives in SeverActions_ArrestBounty.psc)
; =============================================================================

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
    ; Also to SeverActionsNative.log ([Arrest]) for users without bPapyrusLog.
    SeverActionsNative.Native_Arrest_Log(msg)
    If EnableDebugMessages
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrest.arrest", ("" + msg)))
    EndIf
EndFunction

Function ClearAllDispatchLinkedRefs(Actor akActor)
    {Clear both dispatch keywords' linked refs on an actor (dispatch cleanup).}
    If akActor != None
        SeverActionsNative.LinkedRef_Clear(akActor, SeverActions_FollowTargetKW)
        SeverActionsNative.LinkedRef_Clear(akActor, SeverActions_SandboxAnchorKW)
    EndIf
EndFunction

Function ClearDispatchState()
    {Reset all dispatch-related script variables to their defaults.
     Called by CompleteDispatch, CancelDispatch, and EndJudgment branches.}
    ; BEFORE the fields are nulled: ResetState clears the "judgment" busy flag on the actor
    ; GetDispatchSender/Guard resolve (the sender, or the guard for a player sender), which would
    ; otherwise block is_busy-gated actions on them for good.
    If JudgmentScript
        JudgmentScript.ResetState()
    EndIf

    ; End the target's session while DispatchTarget still resolves. Idempotent.
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
    DispatchReturnTimeStart = 0.0
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
    {Clear the deferred evidence narration on the sender, once it fires (the player reached the
     sender) or the sender dies.}
    If DeferredNarrationSender != None
        ; Clears the sender's entry and, when it matches, the deferred-sender singleton.
        SeverActionsNativeExt.Native_Arrest_ClearPendingEvidence(DeferredNarrationSender)
        DeferredNarrationSender = None
        DebugMsg("Cleared deferred narration state")
    EndIf
    ; The player's narration-witness arrival registration (idempotent).
    SeverActionsNativeExt.Arrival_Cancel(Game.GetPlayer())
EndFunction

Function InitDispatchCommon(Actor akGuard, ObjectReference akDestination)
    {Shared setup for arrest and home dispatches, called once the dispatch state and aliases are set.
     akDestination: where the guard travels (the target actor or the home marker).}

    ; On task: YAML eligibility keeps SkyrimNet from re-tasking the guard.
    _BeginGuardTask(akGuard)

    ; SkyrimNet busy lock for other mods' actions; cleared in CompleteDispatch / CancelDispatch.
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

    ; The loaded phase-1 arrival (DispatchArrivalDistance of akDestination) is OnArrival's;
    ; CheckDispatchPhase1_Travel still ticks for the off-screen path and stuck escalation.
    SeverActionsNativeExt.Arrival_Register(akGuard, akDestination, DispatchArrivalDistance, "dispatch_p1_arrived")

    ; Persist dispatch state for save/load recovery
    PersistDispatchState()
    _GuardOffSchedule(akGuard)

    ; Start monitoring
    ChronoArm(UpdateInterval)
EndFunction

Function ApplyDispatchArrestEffects()
    {Arrest DispatchTarget for a dispatch (PerformOffScreenArrest, CheckDispatchPhase2_Approach,
     OnArrival dispatch_p2_arrived). Leaves ArrestState / CurrentGuard / CurrentPrisoner alone:
     they belong to the same-cell arrest on the shared tick.}

    DispatchTarget.StopCombat()
    DispatchTarget.StopCombatAlarm()

    ; A travel errand would fight the escort for the actor's packages.
    CancelTravelFor(DispatchTarget)

    ; Capture the originals on the ArrestSession before pacifying, as PerformArrest does: release
    ; restores them from there.
    SeverActionsNative.Native_ArrestSession_CaptureAVs(DispatchTarget, DispatchTarget.GetAV("Aggression"), DispatchTarget.GetAV("Confidence"))
    DispatchTarget.SetAV("Aggression", 0)
    DispatchTarget.SetAV("Confidence", 0)

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

    ; (Bound pose played after the package below - see PerformArrest.)

    SeverActionsNative.LinkedRef_Set(DispatchTarget, DispatchGuard, SeverActions_FollowTargetKW)
    Utility.Wait(0.2)

    ; Break any PlayIdle animation lock before the follow package.
    Debug.SendAnimationEvent(DispatchTarget, "IdleForceDefaultState")
    Utility.Wait(0.1)

    If SeverActions_FollowGuard_Prisoner
        ActorUtil.AddPackageOverride(DispatchTarget, SeverActions_FollowGuard_Prisoner, PackagePriority, 1)
        DispatchTarget.SetLookAt(DispatchGuard)
        DispatchTarget.EvaluatePackage()
    EndIf

    ; Bound-hands march look, last so nothing cancels it (see PerformArrest).
    If OffsetBoundStandingStart
        DispatchTarget.PlayIdle(OffsetBoundStandingStart)
    EndIf
EndFunction

; Tracked bounty (Get/Set/Mod/ClearTrackedBounty and friends): SeverActions_ArrestBounty.psc,
; called through BountyScript.

; =============================================================================
; FREE NPC API - Release jailed NPCs
; =============================================================================

Bool Function FreeNPC_Internal(Actor akGuard, Actor akTarget)
    {SkyrimNet FreeNPC action: akGuard (a guard or authority) walks to the jailed akTarget
     (up to 15 s), gestures and releases them. False when akTarget is not jailed.}

    If akGuard == None
        DebugMsg("ERROR: FreeNPC called with None guard")
        Return false
    EndIf

    If akTarget == None
        DebugMsg("ERROR: FreeNPC called with None target")
        Return false
    EndIf

    If !akTarget.IsInFaction(SeverActions_Jailed)
        DebugMsg("ERROR: " + akTarget.GetDisplayName() + " is not jailed")
        Return false
    EndIf

    DebugMsg(akGuard.GetDisplayName() + " is freeing prisoner: " + akTarget.GetDisplayName())

    If akTarget.IsDisabled()
        akTarget.Enable()
        Utility.Wait(0.5)
    EndIf

    ; A guard farther than 200 units walks to the prisoner first, through the ArrestTarget alias: not
    ; while a same-cell arrest uses it (the release then happens from where the guard stands).
    Float distance = akGuard.GetDistance(akTarget)
    If distance > 200.0 && !IsSameCellArrestActive()
        DebugMsg("Guard approaching prisoner (distance: " + distance + ")")

        SeverActionsNative.LinkedRef_Set(akGuard, akTarget, SeverActions_FollowTargetKW)

        ; GuardApproachTarget targets the ArrestTarget alias.
        ArrestTarget.ForceRefTo(akTarget)

        If SeverActions_GuardApproachTarget
            ActorUtil.AddPackageOverride(akGuard, SeverActions_GuardApproachTarget, PackagePriority, 1)
            akGuard.EvaluatePackage()
        EndIf

        Float timeout = 15.0
        Float elapsed = 0.0
        While akGuard.GetDistance(akTarget) > 150.0 && elapsed < timeout
            Utility.Wait(0.5)
            elapsed += 0.5
        EndWhile

        If SeverActions_GuardApproachTarget
            ActorUtil.RemovePackageOverride(akGuard, SeverActions_GuardApproachTarget)
        EndIf
        ArrestTarget.Clear()
        SeverActionsNative.LinkedRef_Clear(akGuard, SeverActions_FollowTargetKW)

        DebugMsg("Guard reached prisoner (elapsed: " + elapsed + "s)")
    EndIf

    If IdleGive
        akGuard.PlayIdle(IdleGive)
        Utility.Wait(1.5)
    EndIf

    ReleaseFromJailCore(akTarget)

    akTarget.EvaluatePackage()
    akGuard.EvaluatePackage()

    RemoveJailedNPC(akTarget)

    String narration = "*" + akGuard.GetDisplayName() + " unlocks the cell door and gestures for " + akTarget.GetDisplayName() + " to leave - they are free to go.*"
    SkyrimNetApi.DirectNarration(narration, akGuard, akTarget)

    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrest.hasBeenFreedFromJail", ("" + akTarget.GetDisplayName())))
    DebugMsg("Prisoner freed: " + akTarget.GetDisplayName())

    Return true
EndFunction

Function FreePrisonerDirect(Actor akTarget)
    {Release a prisoner at once, with no guard walk or animation (FreeAllPrisoners, the
     Magelight Jail Roster button). Works on unloaded prisoners too: ReleaseFromJailCore is
     form-level and needs no 3D.}

    If akTarget == None
        Return
    EndIf

    If akTarget.IsDisabled()
        akTarget.Enable()
    EndIf

    ReleaseFromJailCore(akTarget)

    ; Outside the player's cell, send them to their editor placement: jail doors are locked, so
    ; their own packages could leave them stuck in the cell for days. MoveToMyEditorLocation
    ; needs no 3D, no-ops on an actor with no placement, and may wait for a paused menu to close.
    Actor releasePC = Game.GetPlayer()
    Bool sameCell = akTarget.Is3DLoaded() && releasePC && akTarget.GetParentCell() == releasePC.GetParentCell()
    If !sameCell
        akTarget.MoveToMyEditorLocation()
        DebugMsg("Off-screen release: sent " + akTarget.GetDisplayName() + " to editor location")
    EndIf

    akTarget.EvaluatePackage()

    DebugMsg("Prisoner freed directly: " + akTarget.GetDisplayName())
EndFunction

Function FreeAllPrisoners()
    {Release every jailed NPC with FreePrisonerDirect. Iterates a snapshot of the native
     roster, since each release removes its own entry.}

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

    ; Clear any entry the loop left (a prisoner ref that no longer resolves) and the legacy array.
    SeverActionsNativeExt.Native_Jailed_RemoveAll()
    JailedNPCs = PapyrusUtil.ActorArray(0)
    DebugMsg("All prisoners freed")
EndFunction

; =============================================================================
; JAILED NPC TRACKING
; =============================================================================

Function MigrateJailedNPCsToNative()
    {Seed the native JailedNPCStore from the legacy JailedNPCs array when the array has entries
     and the store is empty, then empty the array. A populated store just drops the array.}

    ; !arr, not arr == None: the None cast logs an error on every evaluation.
    If !JailedNPCs || JailedNPCs.Length == 0
        Return
    EndIf
    If SeverActionsNativeExt.Native_Jailed_GetCount() > 0
        JailedNPCs = PapyrusUtil.ActorArray(0)
        Return
    EndIf

    DebugMsg("Migrating " + JailedNPCs.Length + " jailed NPCs from Papyrus array to native store")
    Int i = 0
    Int migrated = 0
    While i < JailedNPCs.Length
        Actor prisoner = JailedNPCs[i]
        If prisoner != None && !prisoner.IsDead()
            ; The marker: native first, then the legacy StorageUtil key.
            ObjectReference marker = SeverActionsNativeExt.Native_Jailed_GetMarker(prisoner)
            If marker == None
                marker = StorageUtil.GetFormValue(prisoner, "SeverActions_JailMarker") as ObjectReference
            EndIf
            ; The legacy data has no crime faction and no "was disabled" flag.
            SeverActionsNativeExt.Native_Jailed_Add(prisoner, marker, None, 0)
            migrated += 1
        EndIf
        i += 1
    EndWhile
    JailedNPCs = PapyrusUtil.ActorArray(0)
    DebugMsg("Migration complete: " + migrated + " prisoners now tracked natively")
EndFunction

Function AddJailedNPC(Actor akNPC)
    {AddJailedNPCAt with no marker, keeping the one-argument signature for older callers.}
    AddJailedNPCAt(akNPC, None)
EndFunction

Function AddJailedNPCAt(Actor akNPC, ObjectReference akJailMarker, Faction akCrimeFaction = None)
    {Add an NPC to the native jailed roster (re-adding overwrites), with the jail marker and crime
     faction that VerifyJailedNPCs and the release paths read back. Marker: akJailMarker, else the
     store's, else the legacy SeverActions_JailMarker StorageUtil key.}

    If akNPC == None
        Return
    EndIf

    ObjectReference marker = akJailMarker
    If marker == None
        marker = SeverActionsNativeExt.Native_Jailed_GetMarker(akNPC)
    EndIf
    If marker == None
        marker = StorageUtil.GetFormValue(akNPC, "SeverActions_JailMarker") as ObjectReference
    EndIf
    ; The caller's faction first: off-screen sentencing has no CurrentGuard, and with no crime faction the
    ; bounty is never discharged and the prisoner is missing from the hold's jail roster.
    Faction crime = akCrimeFaction
    If crime == None && CurrentGuard != None
        crime = GetCrimeFactionForGuard(CurrentGuard)
    EndIf
    Int flags = 0
    If DisablePrisonerOnArrival
        flags = 1
    EndIf
    SeverActionsNativeExt.Native_Jailed_Add(akNPC, marker, crime, flags)
    ; Strip the schedule: the work package's priority 110 ties the PrisonerSandBox hold and the last
    ; override applied wins, so the schedule tick would walk a prisoner out to work. Every jailing path
    ; comes through here; the schedule's own jail gates keep them off it until RemoveJailedNPC.
    SeverActions_ModuleBase.CallBool("followers", "jailStrip", akNPC)
    DebugMsg("Tracking jailed NPC: " + akNPC.GetDisplayName() + " (total: " + SeverActionsNativeExt.Native_Jailed_GetCount() + ")")
EndFunction

Function RemoveJailedNPC(Actor akNPC)
    {Remove an NPC from the native jailed roster.}

    If akNPC == None
        Return
    EndIf
    If SeverActionsNativeExt.Native_Jailed_Remove(akNPC)
        DebugMsg("Removed from jailed tracking: " + akNPC.GetDisplayName())
    EndIf
EndFunction

Actor[] Function GetJailedNPCs()
    {All jailed NPCs (native roster, capped at 128).}

    Return SeverActionsNativeExt.Native_Jailed_GetAll()
EndFunction

Int Function GetJailedCount()
    {Number of jailed NPCs.}

    Return SeverActionsNativeExt.Native_Jailed_GetCount()
EndFunction

Bool Function IsNPCJailed(Actor akNPC)
    {True when akNPC is on the native jailed roster.}

    If akNPC == None
        Return false
    EndIf
    Return SeverActionsNativeExt.Native_Jailed_IsJailed(akNPC)
EndFunction

Function VerifyJailedNPCs()
    {Move any jailed NPC farther than JailMarkerVerifyDistance from their jail marker back to it
     (fast travel and waiting can displace them). Runs on load and from OnTrackedStatsEvent. The
     native roster is pruned of the dead by TESDeathEvent.}

    Actor[] roster = SeverActionsNativeExt.Native_Jailed_GetAll()
    Int count = roster.Length
    If count == 0
        Return
    EndIf

    DebugMsg("Verifying " + count + " jailed NPCs...")
    Int fixedCount = 0
    Int prunedCount = 0

    ; Prune None/dead entries from the legacy array (empty once migrated). The loop below walks
    ; the native roster and skips the dead itself.
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
            Bool fromAnchor = false
            If jailMarker == None
                ; Older saves may hold the marker only in the legacy StorageUtil key.
                jailMarker = StorageUtil.GetFormValue(prisoner, "SeverActions_JailMarker") as ObjectReference
            EndIf
            If jailMarker == None && SeverActions_SandboxAnchorKW
                ; A prisoner jailed with no stored marker still has the sandbox anchor to it
                ; (unless an old, non-permanent anchor was pruned).
                jailMarker = prisoner.GetLinkedRef(SeverActions_SandboxAnchorKW)
                fromAnchor = jailMarker != None
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
                        ; Permanent (LREF v3), as at the jailing site.
                        SeverActionsNativeExt.LinkedRef_SetPermanent(prisoner, jailMarker, SeverActions_SandboxAnchorKW)
                        ActorUtil.AddPackageOverride(prisoner, SeverActions_PrisonerSandBox, PackagePriority + 10, 1)
                        prisoner.EvaluatePackage()
                    EndIf

                    fixedCount += 1
                ElseIf fromAnchor
                    ; The anchor is the only record of the jail: make it permanent so the prune
                    ; cannot drop it (idempotent).
                    SeverActionsNativeExt.LinkedRef_SetPermanent(prisoner, jailMarker, SeverActions_SandboxAnchorKW)
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

; Player confrontation and persuasion FSM: SeverActions_ArrestPlayer.psc (PlayerScript, with its
; own chronometer tick). Outside code uses its public queries: IsPlayerInConfrontation,
; IsPlayerInPersuasion, CancelPlayerConfrontation.

; =============================================================================
; GUARD DISPATCH - find and arrest an NPC anywhere, or search their home
; Self-contained travel: own packages (DispatchJog/DispatchWalk) and the native
; stuck/off-screen trackers, never SeverActions_Travel.
; =============================================================================

Bool Function DispatchGuardToArrest(Actor akGuard, String targetName, Actor akSender = None)
    {Send akGuard (None: the guard nearest the player) to find and arrest the NPC named targetName,
     wherever they are. Phases 1 (travel straight to the target actor; the AI paths across cells),
     2 (approach) and 5 (return to akSender for judgment, or to jail when None). Returns true when
     the dispatch started.}

    Actor target
    String targetLocation
    String eventMsg

    If targetName == ""
        DebugMsg("ERROR: DispatchGuardToArrest called with empty name")
        Return false
    EndIf

    ; One dispatch at a time.
    If DispatchPhase > 0
        DebugMsg("Dispatch rejected: another dispatch already in progress (Phase " + DispatchPhase + ")")
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("arrest.aGuardIsAlreadyDispatched"))
        Return false
    EndIf
    ; A live kidnap leg may have borrowed the dispatch aliases: kidnap checks before borrowing, so
    ; arrest checks back.
    If _DispatchAliasesBorrowed()
        DebugMsg("Dispatch rejected: dispatch aliases borrowed by a kidnap leg")
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("arrest.noGuardIsAvailable"))
        Return false
    EndIf

    ; 15 s real-time cooldown between dispatches.
    Float dispatchNow = Utility.GetCurrentRealTime()
    If LastDispatchSpamTime > 0.0 && (dispatchNow - LastDispatchSpamTime) < 15.0
        DebugMsg("Dispatch rejected: cooldown not elapsed (" + (dispatchNow - LastDispatchSpamTime) + "s)")
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("arrest.pleaseWaitBeforeDispatching"))
        Return false
    EndIf
    LastDispatchSpamTime = dispatchNow

    If !SeverActionsNative.IsActorFinderReady()
        DebugMsg("ERROR: Native ActorFinder not initialized")
        Return false
    EndIf

    target = SeverActionsNative.FindActorByName(targetName)
    If target == None
        DebugMsg("ERROR: Could not find NPC named '" + targetName + "'")
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrest.cannotFindNpc", ("" + targetName)))
        Return false
    EndIf

    ; A crashed earlier arrest's residue on the suspect must not block this dispatch for good. The
    ; helper refuses a genuinely held prisoner, so the rejection below still fires for them.
    ClearStaleArrestState(target, "dispatch start")

    If target.IsInFaction(SeverActions_Arrested) || target.IsInFaction(SeverActions_Jailed)
        DebugMsg("DispatchGuardToArrest rejected: " + targetName + " already arrested or jailed")
        Return false
    EndIf

    If akGuard == None
        akGuard = FindNearestGuard(Game.GetPlayer())
        If akGuard == None
            DebugMsg("ERROR: No guard nearby to dispatch")
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("arrest.noGuardNearbyToDispatch"))
            Return false
        EndIf
    EndIf
    ; The guard too: a crashed phase-1 dispatch can leave its faction, links and packages on them.
    ClearStaleArrestState(akGuard, "dispatch start")

    ; Already close in the same cell: a plain arrest.
    If akGuard.GetParentCell() == target.GetParentCell() && akGuard.GetDistance(target) <= ArrivalDistance
        DebugMsg("Guard already close to target in same cell, starting direct arrest")
        Return ArrestNPC_Internal(akGuard, target)
    EndIf

    targetLocation = SeverActionsNative.GetActorLocationName(target)
    DebugMsg("Dispatching " + akGuard.GetDisplayName() + " to arrest " + target.GetDisplayName() + " at " + targetLocation)

    eventMsg = akGuard.GetDisplayName() + " has been dispatched to arrest " + target.GetDisplayName() + " at " + targetLocation + "."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, akGuard, target)
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrest.dispatchedToArrest", ("" + akGuard.GetDisplayName()), ("" + target.GetDisplayName())))

    ; Travel straight to the target actor (no door intermediary).
    DispatchPhase = 1
    DispatchTarget = target
    DispatchGuard = akGuard
    DispatchTargetLocation = targetLocation
    DispatchGuardOffScreen = false
    DispatchOffScreenStartTime = 0.0
    DispatchGameTimeStart = Utility.GetCurrentGameTime()

    ; Trip distance for the time-skip and off-screen estimates. GetDistance is 0 across cells, so
    ; anything under 1000 becomes 5000 (a typical city traverse).
    Float dispatchDist = 0.0
    If akGuard.Is3DLoaded() && target.Is3DLoaded()
        dispatchDist = akGuard.GetDistance(target)
    EndIf
    If dispatchDist < 1000.0
        dispatchDist = 5000.0
    EndIf
    DispatchInitialDistance = dispatchDist

    ; Return destination: the sender (a live actor) or the jail marker.
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

    ; The dispatch aliases hold both actors in high process off-screen (see DispatchGuardAlias).
    DispatchGuardAlias.ForceRefTo(akGuard)
    DispatchTargetAlias.ForceRefTo(target)

    InitDispatchCommon(akGuard, target as ObjectReference)

    ; ArrestSession entry for the Magelight arrests page: state 5 = kDispatch (ArrestSessionStore.h),
    ; dispatch phase 1, flag 0 = arrest (1 = home investigation, DispatchGuardToHome).
    ObjectReference cosaveJailMarker = GetJailMarkerForGuard(akGuard)
    Faction cosaveCrimeFaction = GetCrimeFactionForGuard(akGuard)
    SeverActionsNative.Native_ArrestSession_Begin(target, akGuard, cosaveJailMarker, cosaveCrimeFaction, 5, 1, 0)

    Return true
EndFunction

Bool Function OrderArrest_Execute(Actor akAuthority, String targetName)
    {SkyrimNet action for a jarl or housecarl (gated on is_hold_noble; the arrest actions
     themselves gate on is_guard): a noble orders an arrest rather than making it. The guard
     nearest the speaker arrests the player (ArrestPlayer_Internal), a loaded NPC
     (ArrestNPC_Internal), or anyone else by DispatchGuardToArrest with the speaker as sender,
     so the prisoner is brought back for judgment.}
    If akAuthority == None || targetName == "" || targetName == "None"
        Return false
    EndIf
    String targetLabel = targetName
    If targetName == "Player" || targetName == "player"
        targetLabel = Game.GetPlayer().GetDisplayName()
    EndIf
    Actor guard = FindNearestGuard(akAuthority)
    If guard == None || guard == akAuthority
        SkyrimNetApi.RegisterEvent("order_arrest_failed", akAuthority.GetDisplayName() + " calls for a guard to arrest " + targetLabel + ", but none is within earshot", akAuthority, None)
        Return false
    EndIf
    Actor player = Game.GetPlayer()
    Actor target = None
    If targetName == "Player" || targetName == "player" || player.GetDisplayName() == targetName
        target = player
    Else
        target = SeverActionsNative.FindActorByName(targetName)
    EndIf
    String order = akAuthority.GetDisplayName() + " orders " + guard.GetDisplayName() + " to arrest " + targetLabel
    If target == player
        SkyrimNetApi.RegisterEvent("arrest_ordered", order, akAuthority, guard)
        If PlayerScript
            Return PlayerScript.ArrestPlayer_Internal(guard)
        EndIf
        Return false
    EndIf
    If target != None && SeverActionsNative.Native_GetActorProcessLevel(target) >= 0
        SkyrimNetApi.RegisterEvent("arrest_ordered", order, akAuthority, guard)
        Return ArrestNPC_Internal(guard, target)
    EndIf
    SkyrimNetApi.RegisterEvent("arrest_ordered", order + " and bring them back for judgment", akAuthority, guard)
    Return DispatchGuardToArrest(guard, targetName, akAuthority)
EndFunction

Bool Function DispatchGuardToArrest_Execute(Actor akGuard, String targetName, String senderName = "")
    {SkyrimNet action: DispatchGuardToArrest by name. senderName: who ordered it; the prisoner is
     brought back to them for judgment, or taken to the hold jail when empty or not found.}

    Actor sender = None
    If senderName != "" && senderName != "None" && senderName != "none"
        ; The player first: FindActorByName fuzzy-matches, so the literal "Player" sentinel
        ; (Magelight's authority picker) would match an NPC named like "Player Friend".
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
    {Send akGuard (None: the guard nearest the player) to search the home of the NPC named
     targetName and bring evidence back to akSender (None: the guard themselves, a moving
     reference, not a captured position). reason (e.g. "skooma") picks thematic evidence; empty
     falls back to the NPC's class. Phases 1 (travel), 3 (search), 4 (evidence), 5 (return).
     Returns true when the dispatch started.}

    Actor target
    ObjectReference home
    String eventMsg
    String guardName

    If targetName == ""
        DebugMsg("ERROR: DispatchGuardToHome called with empty name")
        Return false
    EndIf

    ; One dispatch at a time, aliases not borrowed by a kidnap leg, 15 s cooldown (as in
    ; DispatchGuardToArrest).
    If DispatchPhase > 0
        DebugMsg("Dispatch rejected: another dispatch already in progress (Phase " + DispatchPhase + ")")
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("arrest.aGuardIsAlreadyDispatched"))
        Return false
    EndIf
    If _DispatchAliasesBorrowed()
        DebugMsg("Home dispatch rejected: dispatch aliases borrowed by a kidnap leg")
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("arrest.noGuardIsAvailable"))
        Return false
    EndIf

    Float dispatchNow = Utility.GetCurrentRealTime()
    If LastDispatchSpamTime > 0.0 && (dispatchNow - LastDispatchSpamTime) < 15.0
        DebugMsg("Dispatch rejected: cooldown not elapsed (" + (dispatchNow - LastDispatchSpamTime) + "s)")
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("arrest.pleaseWaitBeforeDispatching"))
        Return false
    EndIf
    LastDispatchSpamTime = dispatchNow

    If !SeverActionsNative.IsActorFinderReady()
        DebugMsg("ERROR: Native ActorFinder not initialized")
        Return false
    EndIf

    target = SeverActionsNative.FindActorByName(targetName)
    If target == None
        DebugMsg("ERROR: Could not find NPC named '" + targetName + "'")
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrest.cannotFindNpc", ("" + targetName)))
        Return false
    EndIf

    If akGuard == None
        akGuard = FindNearestGuard(Game.GetPlayer())
        If akGuard == None
            DebugMsg("ERROR: No guard nearby to dispatch")
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("arrest.noGuardNearbyToDispatch"))
            Return false
        EndIf
    EndIf

    guardName = akGuard.GetDisplayName()

    ; Destination: the home's interior marker when there is one (the AI paths through the doors,
    ; and it avoids cross-cell GetDistance on an exterior door), else the exterior door.
    ObjectReference interiorMarker = SeverActionsNative.FindHomeInteriorMarker(target)
    home = SeverActionsNative.FindDoorToActorHome(target)
    If home == None
        ; FindActorHome scans bed ownership; it needs the NPC loaded.
        home = SeverActionsNative.FindActorHome(target)
    EndIf
    If home == None && interiorMarker == None
        DebugMsg("ERROR: No home found for " + target.GetDisplayName() + ", cannot investigate")
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrest.cannotFindHome", ("" + target.GetDisplayName())))
        Return false
    EndIf

    ObjectReference finalDest = home
    If interiorMarker != None
        finalDest = interiorMarker
        DebugMsg("Resolved home to interior marker for " + target.GetDisplayName())
    ElseIf home != None
        DebugMsg("No interior marker - using exterior door for " + target.GetDisplayName() + "'s home")
    EndIf

    DebugMsg("Dispatching " + guardName + " to investigate " + target.GetDisplayName() + "'s home")

    ; Heading for the interior marker: unlock the exterior door so the guard can path through.
    ; CompleteDispatch / CancelDispatch re-lock it.
    If finalDest == interiorMarker && home != None && home.IsLocked()
        DebugMsg("Unlocked home door for guard entry")
        home.Lock(false)
        DispatchUnlockedDoor = home
    EndIf

    DispatchPhase = 1
    DispatchTarget = target
    DispatchGuard = akGuard
    DispatchIsHomeInvestigation = true
    DispatchHomeMarker = finalDest
    DispatchGuardOffScreen = false
    DispatchOffScreenStartTime = 0.0
    DispatchGameTimeStart = Utility.GetCurrentGameTime()

    ; Trip distance, as in DispatchGuardToArrest.
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

    If akSender != None
        DispatchSender = akSender
        DispatchReturnMarker = akSender as ObjectReference
        DebugMsg("Guard will return evidence to " + akSender.GetDisplayName())
    Else
        DispatchSender = akGuard
        DispatchReturnMarker = akGuard as ObjectReference
        DebugMsg("No sender specified - guard will return to starting position")
    EndIf

    ; The guard in high process off-screen; the target alias holds the destination.
    DispatchGuardAlias.ForceRefTo(akGuard)
    DispatchTargetAlias.ForceRefTo(finalDest)

    eventMsg = guardName + " has been dispatched to search " + target.GetDisplayName() + "'s home for evidence."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, akGuard, target)
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrest.headingToHomeToInvestigate", ("" + guardName), ("" + target.GetDisplayName())))

    InitDispatchCommon(akGuard, finalDest)

    ; ArrestSession entry as in DispatchGuardToArrest, flag 1 = home investigation.
    ObjectReference cosaveHomeJailMarker = GetJailMarkerForGuard(akGuard)
    Faction cosaveHomeCrimeFaction = GetCrimeFactionForGuard(akGuard)
    SeverActionsNative.Native_ArrestSession_Begin(target, akGuard, cosaveHomeJailMarker, cosaveHomeCrimeFaction, 5, 1, 1)

    Return true
EndFunction

Bool Function DispatchGuardToHome_Execute(Actor akGuard, String targetName, String senderName, String reason = "")
    {SkyrimNet action: DispatchGuardToHome by name. senderName: who ordered the search and gets
     the evidence (the player when empty or not found). reason picks thematic evidence.}

    Actor sender = None
    Actor playerRef = Game.GetPlayer()
    If senderName != ""
        ; The player first (see DispatchGuardToArrest_Execute).
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
; DISPATCH PROGRESS MONITORING
; Phases: 1 travel (to the target actor or home marker), 2 approach for the arrest,
; 3 home search, 4 evidence collected, 5 return to the sender or jail, 6 judgment hold.
; Off-screen the AI walks; arrival is a shared interior cell, the snapshot distance, or
; an elapsed travel-time estimate that teleports the guard. A 24 game-hour timeout
; force-completes the dispatch.
; =============================================================================

Function CheckDispatchProgress()
    {The dispatch monitor, run from the chronometer tick (OnChronoTick_Arrest) while
     DispatchPhase > 0: validity checks, time-skip arrivals, then the phase handler.}

    ; The guard is always required, the target for an arrest dispatch.
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

    If DispatchGuard.IsDead()
        DebugMsg("Guard died during dispatch")
        CancelDispatch()
        Return
    EndIf

    ; An arrest dispatch's target dying before the arrest, or on the way back (a corpse is not brought
    ; before anyone); a judgment hold (6) ends itself (ArrestJudgment).
    If !DispatchIsHomeInvestigation && (DispatchPhase <= 2 || DispatchPhase == 5) && DispatchTarget != None && DispatchTarget.IsDead()
        DebugMsg("Target died during dispatch")
        CancelDispatch()
        Return
    EndIf

    ; 24 game-hour timeout for the outbound phases (1-4); the return and the judgment have their own.
    If DispatchGameTimeStart > 0.0 && DispatchPhase < 5
        Float elapsedHours = (Utility.GetCurrentGameTime() - DispatchGameTimeStart) * 24.0
        If elapsedHours > 24.0
            DebugMsg("Dispatch timeout (" + elapsedHours + "h) - force-completing")
            ; Stop the clock first: this branch returns before the phase routing, so a running clock would
            ; re-run the force-complete on every tick.
            DispatchGameTimeStart = 0.0
            If DispatchIsHomeInvestigation
                ; Return with whatever was found.
                DebugMsg("Home investigation timeout - returning to sender")
                StartDispatchReturnPhase()
            Else
                PerformOffScreenArrest()
            EndIf
            Return
        EndIf
    EndIf

    ; Time skips (waiting, sleeping) advance game time without ticks: once the trip's game time at
    ; GuardJogPerGameHour has passed, the guard has arrived.
    If DispatchPhase == 1 && DispatchGameTimeStart > 0.0
        Float gameHoursElapsed = (Utility.GetCurrentGameTime() - DispatchGameTimeStart) * 24.0
        If gameHoursElapsed >= 0.25
            ObjectReference travelDestCheck = None
            If DispatchIsHomeInvestigation && DispatchHomeMarker != None
                travelDestCheck = DispatchHomeMarker
            ElseIf DispatchTarget != None
                travelDestCheck = DispatchTarget as ObjectReference
            EndIf

            If travelDestCheck != None
                ; The stored trip distance: GetDistance is 0 across cells.
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
                        If DispatchHomeMarker != None
                            DispatchGuard.MoveTo(DispatchHomeMarker)
                            Utility.Wait(0.3)
                            TransitionToSandboxPhase()
                        EndIf
                    Else
                        PerformOffScreenArrest()
                    EndIf
                    Return
                EndIf
            EndIf
        EndIf
    ElseIf DispatchPhase == 5 && DispatchReturnTimeStart > 0.0
        ; The return leg's time skip, measured from the return start: the dispatch start would count the
        ; outbound leg too and teleport the escort on its first phase-5 tick, in front of the player.
        Float gameHoursReturn = (Utility.GetCurrentGameTime() - DispatchReturnTimeStart) * 24.0
        If gameHoursReturn >= 0.5 && DispatchReturnMarker != None
            ; The outbound trip distance stands in for the return trip.
            Float returnDistCheck = DispatchInitialDistance
            If returnDistCheck < 1000.0
                returnDistCheck = 5000.0
            EndIf
            Float requiredReturnHours = returnDistCheck / GuardJogPerGameHour
            If requiredReturnHours < 0.25
                requiredReturnHours = 0.25
            EndIf
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

    If DispatchPhase == 1
        CheckDispatchOffScreen()
    EndIf

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
        ; The judgment hold lives in SeverActions_ArrestJudgment.
        If JudgmentScript
            JudgmentScript.CheckJudgmentProgress()
        EndIf
    EndIf
EndFunction

Function CheckDispatchOffScreen()
    {Phase 1 with the guard off-screen: trust the AI's own pathing (it crosses load doors, and
     CheckDispatchPhase1_Travel's same-cell check usually sees the arrival first). Only after the
     trip's real time (distance / GuardJogSpeed, clamped to 120-600 s) move the guard there.}

    Bool guardInLoadedArea = DispatchGuard.Is3DLoaded()

    If !guardInLoadedArea
        Cell guardCell = DispatchGuard.GetParentCell()

        If !DispatchGuardOffScreen
            DispatchGuardOffScreen = true
            DispatchOffScreenStartTime = Utility.GetCurrentRealTime()
            DebugMsg("Guard went off-screen during travel, trusting AI pathfinding")
        EndIf

        Float elapsedOffScreen = Utility.GetCurrentRealTime() - DispatchOffScreenStartTime

        ObjectReference travelDest = None
        If DispatchIsHomeInvestigation && DispatchHomeMarker != None
            travelDest = DispatchHomeMarker
        ElseIf DispatchTarget != None
            travelDest = DispatchTarget as ObjectReference
        EndIf

        Float requiredTime = 120.0
        If travelDest != None
            Float dist = DispatchInitialDistance
            If dist < 1000.0
                dist = 5000.0
            EndIf
            Float travelTime = dist / GuardJogSpeed
            If travelTime > requiredTime
                requiredTime = travelTime
            EndIf
            If requiredTime > 600.0
                requiredTime = 600.0
            EndIf
        EndIf

        If elapsedOffScreen >= requiredTime
            DebugMsg("Off-screen travel time elapsed (" + elapsedOffScreen + "s / " + requiredTime + "s required)")

            If DispatchIsHomeInvestigation
                If DispatchHomeMarker != None
                    DebugMsg("Off-screen: moving guard to home destination")
                    DispatchGuard.MoveTo(DispatchHomeMarker)
                    Utility.Wait(0.3)
                    TransitionToSandboxPhase()
                    Return
                EndIf
            ElseIf DispatchTarget != None
                DebugMsg("Off-screen: guard arrived at target location")
                DispatchGuard.MoveTo(DispatchTarget, 200.0, 0.0, 0.0, false)
                Utility.Wait(0.3)
                TransitionToApproachPhase()
                Return
            EndIf
        Else
            ; Progress log every 30 s.
            If Math.Floor(elapsedOffScreen) as Int % 30 == 0 && Math.Floor(elapsedOffScreen) as Int > 0
                DebugMsg("Off-screen travel: " + elapsedOffScreen as Int + "s / " + requiredTime as Int + "s, trusting AI")
            EndIf
        EndIf
    Else
        If DispatchGuardOffScreen
            DebugMsg("Guard back on-screen")
            DispatchGuardOffScreen = false
            DispatchOffScreenStartTime = 0.0
        EndIf
    EndIf
EndFunction

Function PerformOffScreenArrest()
    {The off-screen travel time or the 24h timeout ran out: teleport the guard to the target,
     arrest there, and start phase 5. The return is walked and estimated, not teleported, so the
     pair does not appear out of thin air at the destination.}

    DebugMsg("Performing off-screen arrest of " + DispatchTarget.GetDisplayName())

    SeverActionsNativeExt.Stuck_StopTracking(DispatchGuard)

    RemoveAllArrestPackages(DispatchGuard)
    If DispatchTravelDestination != None
        DispatchTravelDestination.Clear()
    EndIf
    ClearAllDispatchLinkedRefs(DispatchGuard)

    DispatchGuard.MoveTo(DispatchTarget, 100.0, 0.0, 0.0, false)
    Utility.Wait(0.2)

    ApplyDispatchArrestEffects()

    DebugMsg("Off-screen dispatch arrest effects applied to " + DispatchTarget.GetDisplayName())

    String guardName = DispatchGuard.GetDisplayName()
    String targetName = DispatchTarget.GetDisplayName()
    String narration = "*" + guardName + " arrests " + targetName + " and begins escorting them back.*"
    SkyrimNetApi.DirectNarration(narration, DispatchTarget, DispatchGuard)

    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrest.hasArrestedAndIsReturning", ("" + guardName), ("" + targetName)))

    Utility.Wait(0.3)

    StartDispatchReturnPhase()
EndFunction

Function StartDispatchReturnPhase()
    {Enter phase 5: the guard walks the prisoner or evidence back to DispatchReturnMarker (the
     sender or the jail marker) with DispatchWalk, which targets DispatchTargetAlias.}

    DispatchReturnTimeStart = Utility.GetCurrentGameTime()

    If DispatchSender != None
        DebugMsg("Starting return phase - returning to " + DispatchSender.GetDisplayName())
    Else
        DebugMsg("Starting return phase - escorting prisoner to jail")
    EndIf

    ; The alias keeps the prisoner in high process off-screen, so their follow package runs.
    If DispatchTarget != None && !DispatchIsHomeInvestigation && DispatchPrisonerAlias != None
        DispatchPrisonerAlias.ForceRefTo(DispatchTarget)
        DebugMsg("Prisoner alias filled: " + DispatchTarget.GetDisplayName())
    EndIf

    If DispatchReturnMarker != None
        DispatchTargetAlias.ForceRefTo(DispatchReturnMarker)
        DispatchGuardAlias.ForceRefTo(DispatchGuard)

        If SeverActions_DispatchWalk
            ActorUtil.AddPackageOverride(DispatchGuard, SeverActions_DispatchWalk, PackagePriority, 1)
            DispatchGuard.EvaluatePackage()
            If DispatchSender != None
                DebugMsg("Applied DispatchWalk for return to " + DispatchSender.GetDisplayName())
            Else
                DebugMsg("Applied DispatchWalk for return to jail")
            EndIf
        EndIf

        ; No NPC-NPC collision on the return.
        SeverActionsNative.SetActorBumpable(DispatchGuard, false)
    EndIf

    ; The prisoner follows the guard, with no collision so the two do not block each other at doors.
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

    SeverActionsNativeExt.Stuck_StartTracking(DispatchGuard)

    ; Off-screen arrival estimate, bounded to 0.25-12 game hours.
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

    ; Loaded arrival (within DispatchArrivalDistance) is OnArrival(dispatch_p5_arrived);
    ; CheckDispatchPhase5_Return keeps the off-screen tiers and the stuck escalation.
    If DispatchReturnMarker != None
        SeverActionsNativeExt.Arrival_Register(DispatchGuard, DispatchReturnMarker, DispatchArrivalDistance, "dispatch_p5_arrived")
    EndIf

    ChronoArm(UpdateInterval)
EndFunction

Function ReapplyReturnPackages()
    {Re-apply the return aliases, packages and prisoner link after a cross-cell MoveTo (a cell
     transition often drops the overrides), and restart stuck tracking with a 5 s grace.}

    DispatchTargetAlias.ForceRefTo(DispatchReturnMarker)
    DispatchGuardAlias.ForceRefTo(DispatchGuard)
    If SeverActions_DispatchWalk
        ActorUtil.AddPackageOverride(DispatchGuard, SeverActions_DispatchWalk, PackagePriority, 1)
    EndIf

    If DispatchTarget != None && !DispatchIsHomeInvestigation
        SeverActionsNative.LinkedRef_Set(DispatchTarget, DispatchGuard, SeverActions_FollowTargetKW)
        Utility.Wait(0.2)
        If SeverActions_FollowGuard_Prisoner
            ActorUtil.AddPackageOverride(DispatchTarget, SeverActions_FollowGuard_Prisoner, PackagePriority, 1)
            DispatchTarget.EvaluatePackage()
        EndIf
    EndIf

    DispatchGuard.EvaluatePackage()

    ; The stuck baseline is stale after the teleport.
    SeverActionsNativeExt.Stuck_StopTracking(DispatchGuard)
    SeverActionsNativeExt.Stuck_StartTracking(DispatchGuard)

    ; No stuck checks for 5 s while the actors settle on the navmesh.
    DispatchStuckGraceUntil = Utility.GetCurrentRealTime() + 5.0

    DebugMsg("Re-applied return packages after cell transition")
EndFunction

Function CheckDispatchPhase1_Travel()
    {Phase 1: the guard travels to the target actor or home marker; the AI paths across cells.
     This tick handles a failed departure, stuck escalation, same-interior-cell and off-screen
     arrivals, and a stale-snapshot redirect to the target's home. Loaded arrival is
     OnArrival(dispatch_p1_arrived).}

    Float dist
    Int stuckLevel
    ObjectReference travelDest

    If DispatchIsHomeInvestigation && DispatchHomeMarker != None
        travelDest = DispatchHomeMarker
    ElseIf DispatchTarget != None
        travelDest = DispatchTarget as ObjectReference
    Else
        DebugMsg("ERROR: Phase1 - no valid travel destination")
        CancelDispatch()
        Return
    EndIf

    ; Stuck_CheckDeparture returns 2 when the guard is still within 100 units of the start after
    ; its grace ticks: a soft recovery.
    If DispatchGuard.Is3DLoaded()
        Int departureStatus = SeverActionsNativeExt.Stuck_CheckDeparture(DispatchGuard, 100.0)
        If departureStatus == 2
            DebugMsg("Guard failed to depart - applying soft recovery")
            DispatchGuard.EvaluatePackage()
            ; A brief SetDontMove toggle breaks an animation lock.
            DispatchGuard.SetDontMove(true)
            Utility.Wait(0.3)
            DispatchGuard.SetDontMove(false)
            DispatchGuard.EvaluatePackage()
            SeverActionsNativeExt.Stuck_ResetEscalation(DispatchGuard)
        EndIf
    EndIf

    ; Stuck escalation: 2 nudge, 3 leapfrog toward the destination.
    stuckLevel = SeverActionsNativeExt.Stuck_CheckStatus(DispatchGuard, UpdateInterval, 50.0)
    If stuckLevel >= 2
        DebugMsg("Guard stuck (level " + stuckLevel + "), nudging...")
        DispatchGuard.EvaluatePackage()
        If stuckLevel >= 3 && travelDest != None
            Float teleportDist = SeverActionsNativeExt.Stuck_GetTeleportDistance(DispatchGuard)
            DispatchGuard.MoveTo(travelDest, teleportDist, 0.0, 0.0, false)
            SeverActionsNativeExt.Stuck_ResetEscalation(DispatchGuard)

            ; A target in an interior: go to the door of their cell instead.
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

    ; Same INTERIOR cell = arrived: interiors are small, and ArrivalMonitor's distance test is
    ; unreliable in cramped ones.
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

    ; Either one off-screen: the native position-snapshot distance (actors only, so not for the
    ; home marker).
    If !DispatchGuard.Is3DLoaded() || !travelDest.Is3DLoaded()
        If !DispatchIsHomeInvestigation
            Float snapDist = SeverActionsNative.GetDistanceBetweenActors(DispatchGuard, DispatchTarget)
            If snapDist >= 0.0 && snapDist <= DispatchArrivalDistance
                DebugMsg("Snapshot distance arrival: guard within " + snapDist + " of target (off-screen)")
                TransitionToApproachPhase()
                Return
            EndIf
        EndIf
    EndIf

    ; Guard off-screen and OffScreenTracker's distance estimate elapsed: teleport them there
    ; (beside the target for an arrest).
    If !DispatchGuard.Is3DLoaded()
        Int arrivalStatus = SeverActionsNative.OffScreen_CheckArrival(DispatchGuard, Utility.GetCurrentGameTime())
        If arrivalStatus == 1
            DebugMsg("Off-screen travel estimate elapsed - teleporting guard to destination")
            DispatchGuard.MoveTo(travelDest, 300.0, 0.0, 0.0, false)
            If !DispatchIsHomeInvestigation && DispatchTarget != None
                DispatchGuard.MoveTo(DispatchTarget, ApproachDistance, 0.0, 0.0, false)
            EndIf
            Utility.Wait(0.5)
            DispatchGuard.EvaluatePackage()
            SeverActionsNative.OffScreen_StopTracking(DispatchGuard)
            ; The next tick sees the arrival and moves on.
            ChronoArm(UpdateInterval)
            Return
        EndIf
    EndIf

    ; After 5+ game hours of travel, a target snapshot older than 24 game hours means the guard is
    ; chasing a stale position: redirect them to the target's home.
    If !DispatchIsHomeInvestigation && DispatchGameTimeStart > 0.0
        Float travelHours = (Utility.GetCurrentGameTime() - DispatchGameTimeStart) * 24.0
        If travelHours >= 5.0
            Float snapshotTime = SeverActionsNative.GetActorSnapshotGameTime(DispatchTarget)
            If snapshotTime > 0.0
                Float snapshotAge = (Utility.GetCurrentGameTime() - snapshotTime) * 24.0
                If snapshotAge > 24.0
                    DebugMsg("Target snapshot is " + snapshotAge + "h old - redirecting to home")
                    ObjectReference homeMarker = SeverActionsNative.FindHomeInteriorMarker(DispatchTarget)
                    If homeMarker == None
                        ObjectReference homeDoor = SeverActionsNative.FindDoorToActorHome(DispatchTarget)
                        If homeDoor != None
                            homeMarker = homeDoor
                        EndIf
                    EndIf

                    If homeMarker != None
                        ; The dispatch package follows DispatchTargetAlias, not ArrestTarget
                        ; (the same-cell alias); the wrong one makes this a silent no-op.
                        DebugMsg("Redirecting guard to target's home")
                        DispatchTargetAlias.ForceRefTo(homeMarker)
                        DispatchGuard.EvaluatePackage()
                        ; DispatchTarget is unchanged: the guard waits at the home for them.
                    EndIf
                EndIf
            EndIf
        EndIf
    EndIf

    ChronoArm(UpdateInterval)
EndFunction

Function RestoreGuardCombatAI()
    {Restore guard's original aggression/confidence after dispatch.}
    If DispatchGuard != None
        DispatchGuard.SetAV("Aggression", DispatchGuardOrigAggression)
        DispatchGuard.SetAV("Confidence", DispatchGuardOrigConfidence)
    EndIf
EndFunction

Function TransitionToApproachPhase()
    {Enter phase 2 (approach for the arrest): aim DispatchJog at the target, restore collision, restart
     stuck tracking and the phase-2 timeout, watch for arrival at ApproachDistance, draw the weapon.
     RestoreGuardCombatAI is deliberately NOT called here: with their aggression back before the
     target is pacified, the guard fights a still-hostile target instead of arresting them. It runs
     after ApplyDispatchArrestEffects instead.}

    SeverActionsNativeExt.Stuck_StopTracking(DispatchGuard)

    SeverActionsNative.SetActorBumpable(DispatchGuard, true)

    ; The dispatch's own alias and package, never ArrestTarget / GuardApproachTarget: a same-cell
    ; arrest running at the same time refills those. Phase 1 may have aimed the alias at a home marker.
    DispatchTargetAlias.ForceRefTo(DispatchTarget)
    If SeverActions_DispatchJog
        ; Phase 1 ran the same package: remove it first so the travel restarts toward the new target.
        ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchJog)
        ActorUtil.AddPackageOverride(DispatchGuard, SeverActions_DispatchJog, PackagePriority, 1)
        DispatchGuard.EvaluatePackage()
        DebugMsg("Approach phase: guard approaching target")
    EndIf

    DispatchGuard.DrawWeapon()
    DispatchPhase = 2
    SeverActionsNativeExt.Native_Arrest_SetDispatchPhase(DispatchGuard, DispatchPhase)
    SeverActionsNative.Native_ArrestSession_UpdateState(DispatchTarget, 5, 2)

    ; Baseline for the phase-2 timeout, and no freeze yet.
    DispatchPhase2StartTime = Utility.GetCurrentRealTime()
    DispatchTargetMovementFrozen = false

    ; Stopped above; phase 2 needs it for its own stuck recovery.
    SeverActionsNativeExt.Stuck_StartTracking(DispatchGuard)

    ; Replaces the phase-1 arrival watch (one entry per actor); OnArrival(dispatch_p2_arrived) makes
    ; the arrest.
    If DispatchTarget != None
        SeverActionsNativeExt.Arrival_Register(DispatchGuard, DispatchTarget, ApproachDistance, "dispatch_p2_arrived")
    EndIf

    ChronoArm(UpdateInterval)
EndFunction

Function CheckDispatchPhase2_Approach()
    {Phase 2: the guard closes on the target. Loaded arrival is OnArrival(dispatch_p2_arrived);
     this tick handles the unloaded arrival (snapshot distance, since GetDistance reads 0 for an
     unloaded actor; with no snapshot it trusts the arrival that led here), freezes the target
     inside ApproachFreezeDistance, arrests in place after ApproachTimeout (a target on a sandbox
     package could otherwise be chased forever) and escalates a stuck guard. RestoreGuardCombatAI
     follows ApplyDispatchArrestEffects (see TransitionToApproachPhase).}

    Float dist = -1.0
    Bool bothLoaded = DispatchGuard.Is3DLoaded() && DispatchTarget.Is3DLoaded()

    If bothLoaded
        dist = DispatchGuard.GetDistance(DispatchTarget)
    Else
        dist = SeverActionsNative.GetDistanceBetweenActors(DispatchGuard, DispatchTarget)
        If dist < 0.0
            dist = 0.0
            DebugMsg("Phase 2: both unloaded, no snapshot - trusting same-cell arrival")
        EndIf
    EndIf

    ; ArrivalMonitor needs 3D, so an unloaded arrival makes the arrest here.
    If !bothLoaded && dist >= 0.0 && dist <= ApproachDistance
        DebugMsg("Phase 2: off-screen snapshot arrival (dist=" + dist + ") - performing arrest")
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
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrest.hasArrested", ("" + snapGuardName), ("" + snapTargetName)))
        StartDispatchReturnPhase()
        Return
    EndIf

    ; Freeze the target once close, or their own AI keeps walking them out of arrest range (as in
    ; the same-cell approach).
    If !DispatchTargetMovementFrozen && DispatchTarget != None && bothLoaded && dist > 0.0 && dist <= ApproachFreezeDistance
        DispatchTarget.SetDontMove(true)
        DispatchTargetMovementFrozen = true
        DebugMsg("Phase 2: target inside " + ApproachFreezeDistance + "u, freezing movement")
    EndIf

    ; Hard timeout (ApproachTimeout, real seconds): the guard is already close by, so teleport
    ; them in and arrest in place.
    Float phase2Elapsed = Utility.GetCurrentRealTime() - DispatchPhase2StartTime
    If DispatchPhase2StartTime > 0.0 && phase2Elapsed >= ApproachTimeout
        DebugMsg("Phase 2 timeout (" + phase2Elapsed + "s) - force-teleporting guard for in-place arrest")
        SeverActionsNativeExt.Stuck_StopTracking(DispatchGuard)
        If DispatchTarget != None
            DispatchGuard.MoveTo(DispatchTarget, 100.0, 0.0, 0.0)
            ; An offset teleport can land off the navmesh.
            SeverActionsNative.Native_MoveToNearestNavmesh(DispatchGuard, 0.0)
            Utility.Wait(0.3)
        EndIf
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
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrest.hasArrested", ("" + gName), ("" + tgName)))

        StartDispatchReturnPhase()
        Return
    EndIf

    ; Stuck escalation: 1 nudge, 2 leapfrog toward the target, 3 teleport beside them.
    If bothLoaded
        Int stuckLevel = SeverActionsNativeExt.Stuck_CheckStatus(DispatchGuard, UpdateInterval, 50.0)
        If stuckLevel == 1
            DispatchGuard.EvaluatePackage()
        ElseIf stuckLevel == 2
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
                SeverActionsNative.Native_MoveToNearestNavmesh(DispatchGuard, 0.0)
                DispatchGuard.EvaluatePackage()
                DebugMsg("Phase 2: leapfrog guard " + teleportDist + " units toward target")
            EndIf
            SeverActionsNativeExt.Stuck_ResetEscalation(DispatchGuard)
        ElseIf stuckLevel >= 3
            DebugMsg("Phase 2: force teleporting guard near target")
            DispatchGuard.MoveTo(DispatchTarget, 200.0, 0.0, 0.0)
            SeverActionsNative.Native_MoveToNearestNavmesh(DispatchGuard, 0.0)
            Utility.Wait(0.3)
            DispatchGuard.EvaluatePackage()
            SeverActionsNativeExt.Stuck_ResetEscalation(DispatchGuard)
        EndIf
    EndIf

    ChronoArm(UpdateInterval)
EndFunction

Function TransitionToSandboxPhase()
    {Enter phase 3, the home search. On-screen the guard walks to each container, opens and
     searches it; evidence is a suspicious item already in the home, else items from the pool.
     Off-screen the evidence is picked and handed over at once and a timer stands in for the search.}

    SeverActionsNativeExt.Stuck_StopTracking(DispatchGuard)

    SeverActionsNative.SetActorBumpable(DispatchGuard, true)

    ; Drop the travel packages and linked refs.
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
        ; On-screen: container by container.
        DebugMsg("Phase 3: On-screen container search beginning")

        DispatchContainerCount = SeverActionsNative.FindSearchContainers(DispatchGuard, 3000.0)
        DebugMsg("Found " + DispatchContainerCount + " searchable containers in cell")

        If DispatchContainerCount == 0
            DebugMsg("No containers found, falling back to sandbox + evidence generation")
            FallbackSandboxSearch(guardName, targetName)
            Return
        EndIf

        ; Pass 1: the first container already holding something suspicious. It counts as player-planted
        ; (ScanContainerForEvidence cannot tell who put it there).
        DispatchPlayerPlantedFound = false
        DispatchEvidenceContainerIndex = -1
        Int i = 0
        While i < DispatchContainerCount
            ObjectReference containerRef = SeverActionsNative.GetSearchContainer(i)
            If containerRef != None
                Form plantedEvidence = SeverActionsNative.ScanContainerForEvidence(containerRef, DispatchInvestigationReason)
                If plantedEvidence != None && !DispatchPlayerPlantedFound
                    DispatchPlayerPlantedFound = true
                    DispatchEvidenceContainerIndex = i
                    DispatchEvidenceForm = plantedEvidence
                    DispatchEvidenceName = plantedEvidence.GetName()
                    DebugMsg("Pass 1: Found player-planted evidence '" + DispatchEvidenceName + "' in container " + i)
                EndIf
            EndIf
            i += 1
        EndWhile

        ; Pass 2, nothing planted: up to three pool items (SelectEvidenceFromPool: one common, maybe a
        ; rare and a damning one), all planted in the LAST container to build tension.
        If !DispatchPlayerPlantedFound
            String evidencePoolResult = SeverActionsNative.SelectEvidenceFromPool(DispatchInvestigationReason, DispatchTarget)
            Int evidenceCount = SeverActionsNative.GetEvidenceCount()
            DebugMsg("Pass 2: Selected " + evidenceCount + " evidence items from pool")

            If evidenceCount >= 1
                DispatchEvidenceForm = SeverActionsNative.GetEvidenceAtIndex(0) as Form
                If DispatchEvidenceForm != None
                    DispatchEvidenceName = DispatchEvidenceForm.GetName()
                EndIf
            EndIf

            If evidenceCount >= 2
                DispatchEvidenceForm2 = SeverActionsNative.GetEvidenceAtIndex(1) as Form
                If DispatchEvidenceForm2 != None
                    DispatchEvidenceName2 = DispatchEvidenceForm2.GetName()
                EndIf
            EndIf

            If evidenceCount >= 3
                DispatchEvidenceForm3 = SeverActionsNative.GetEvidenceAtIndex(2) as Form
                If DispatchEvidenceForm3 != None
                    DispatchEvidenceName3 = DispatchEvidenceForm3.GetName()
                EndIf
            EndIf

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

        String narration = "*" + guardName + " enters " + targetName + "'s home and begins a methodical search, eyes scanning the room.*"
        SkyrimNetApi.DirectNarration(narration, DispatchGuard, DispatchTarget)

        ; A 5 s look around the room before the first container.
        DispatchCurrentContainer = 0
        DispatchSearchSubPhase = 0
        DispatchSandboxStartTime = Utility.GetCurrentRealTime()
        DispatchSandboxDuration = 5.0

        ChronoArm(UpdateInterval)

    Else
        ; Off-screen: the evidence goes straight to the guard; a 20-45 s timer stands in for the search.
        DebugMsg("Phase 3: Off-screen search - simulating with timer")

        String evidencePoolResult = SeverActionsNative.SelectEvidenceFromPool(DispatchInvestigationReason, DispatchTarget)
        Int evidenceCount = SeverActionsNative.GetEvidenceCount()
        DebugMsg("Off-screen: Selected " + evidenceCount + " evidence items from pool")

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

        BuildEvidenceSummary(targetName)

        If DispatchEvidenceForm != None
            String eventMsg = guardName + " found evidence at " + targetName + "'s home: " + DispatchEvidenceSummary
            SkyrimNetApi.RegisterPersistentEvent(eventMsg, DispatchGuard, DispatchTarget)
        Else
            DebugMsg("Off-screen: No evidence generated - guard returning empty-handed")
        EndIf

        DispatchSandboxStartTime = Utility.GetCurrentRealTime()
        DispatchSandboxDuration = Utility.RandomFloat(20.0, 45.0)
        DebugMsg("Off-screen search simulated for " + DispatchSandboxDuration + " seconds")

        ChronoArm(UpdateInterval)
    EndIf
EndFunction

Function FallbackSandboxSearch(String guardName, String targetName)
    {No searchable containers: the guard sandboxes at the home for 15-30 s, and
     CheckDispatchPhase3_Sandbox then hands over one item picked from the pool.}

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

    String evidencePoolResult = SeverActionsNative.SelectEvidenceFromPool(DispatchInvestigationReason, DispatchTarget)
    Int evidenceCount = SeverActionsNative.GetEvidenceCount()
    If evidenceCount >= 1
        DispatchEvidenceForm = SeverActionsNative.GetEvidenceAtIndex(0) as Form
        If DispatchEvidenceForm != None
            DispatchEvidenceName = DispatchEvidenceForm.GetName()
        EndIf
    EndIf

    DispatchSandboxStartTime = Utility.GetCurrentRealTime()
    DispatchSandboxDuration = Utility.RandomFloat(15.0, 30.0)
    DispatchContainerCount = 0  ; Signal fallback mode

    String narration = "*" + guardName + " begins searching " + targetName + "'s home, looking through belongings for evidence.*"
    SkyrimNetApi.DirectNarration(narration, DispatchGuard, DispatchTarget)

    ChronoArm(UpdateInterval)
EndFunction

Function CheckDispatchPhase3_Sandbox()
    {Phase 3, the home search: on-screen one container at a time (walk, open, search), off-screen
     a timer, and with no containers the fallback sandbox timer.}

    Bool playerWatching = DispatchGuard.Is3DLoaded()

    ; Container count 0: the no-container fallback. An off-screen search (which never sets the count)
    ; lands here too.
    If DispatchContainerCount == 0
        Float elapsed = Utility.GetCurrentRealTime() - DispatchSandboxStartTime
        If elapsed >= DispatchSandboxDuration
            DebugMsg("Fallback sandbox complete, collecting evidence")

            SeverActionsNative.UnregisterSandboxUser(DispatchGuard)
            If SeverActions_PrisonerSandBox
                ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_PrisonerSandBox)
            EndIf
            SeverActionsNative.LinkedRef_Clear(DispatchGuard, SeverActions_SandboxAnchorKW)

            If DispatchEvidenceForm != None
                DispatchGuard.AddItem(DispatchEvidenceForm, 1, true)
                BuildEvidenceSummary(DispatchTarget.GetDisplayName())
                Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrest.collectedEvidence", ("" + DispatchGuard.GetDisplayName()), ("" + DispatchEvidenceName)))
            EndIf

            TransitionToEvidenceComplete()
            Return
        EndIf
        ChronoArm(UpdateInterval)
        Return
    EndIf

    ; Only an on-screen search gets here (an off-screen one keeps the count at 0): the guard went
    ; off-screen mid-search, so finish the rest at once, collecting the evidence.
    If !playerWatching
        DebugMsg("Guard went off-screen mid-search, completing remaining containers instantly")
        CompleteRemainingContainersInstantly()
        TransitionToEvidenceComplete()
        Return
    EndIf

    ; On-screen: the 5 s entry pause first.
    Float elapsed = Utility.GetCurrentRealTime() - DispatchSandboxStartTime
    If DispatchCurrentContainer == 0 && DispatchSearchSubPhase == 0 && elapsed < 5.0
        ChronoArm(UpdateInterval)
        Return
    EndIf

    ; Sub-phases: 0 pick the next container, 1 walk to it, 2 search it.
    If DispatchSearchSubPhase == 0
        If DispatchCurrentContainer >= DispatchContainerCount
            DebugMsg("All " + DispatchContainerCount + " containers searched, finalizing")
            TransitionToEvidenceComplete()
            Return
        EndIf

        ObjectReference containerRef = SeverActionsNative.GetSearchContainer(DispatchCurrentContainer)
        If containerRef == None
            DebugMsg("Container " + DispatchCurrentContainer + " is None, skipping")
            DispatchCurrentContainer += 1
            ChronoArm(UpdateInterval)
            Return
        EndIf

        DispatchCurrentContainerRef = containerRef
        DebugMsg("Walking guard to container " + DispatchCurrentContainer + " of " + DispatchContainerCount)

        If DispatchTravelDestination != None
            DispatchTravelDestination.ForceRefTo(containerRef)
        EndIf
        If SeverActions_DispatchTravel
            ActorUtil.AddPackageOverride(DispatchGuard, SeverActions_DispatchTravel, PackagePriority, 1)
            DispatchGuard.EvaluatePackage()
        EndIf

        DispatchSearchSubPhase = 1
        DispatchContainerSearchStart = Utility.GetCurrentRealTime()
        ChronoArm(UpdateInterval)

    ElseIf DispatchSearchSubPhase == 1
        If DispatchCurrentContainerRef == None
            DispatchSearchSubPhase = 0
            DispatchCurrentContainer += 1
            ChronoArm(UpdateInterval)
            Return
        EndIf

        Float dist = DispatchGuard.GetDistance(DispatchCurrentContainerRef)

        If dist <= 200.0
            DebugMsg("Guard arrived at container " + DispatchCurrentContainer + " (dist=" + dist + ")")

            If SeverActions_DispatchTravel
                ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchTravel)
            EndIf
            If DispatchTravelDestination != None
                DispatchTravelDestination.Clear()
            EndIf

            ; Activate opens the container visually.
            DispatchCurrentContainerRef.Activate(DispatchGuard)
            Debug.SendAnimationEvent(DispatchGuard, "IdlePickupFromTableStart")

            DispatchContainerSearchDuration = Utility.RandomFloat(8.0, 12.0)
            DispatchContainerSearchStart = Utility.GetCurrentRealTime()
            DispatchSearchSubPhase = 2
            DispatchContainersSearched += 1

            ChronoArm(UpdateInterval)

        Else
            ; Skip a container the guard cannot reach in 15 s.
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
            ChronoArm(UpdateInterval)
        EndIf

    ElseIf DispatchSearchSubPhase == 2
        Float searchElapsed = Utility.GetCurrentRealTime() - DispatchContainerSearchStart

        If searchElapsed >= DispatchContainerSearchDuration
            String guardName = DispatchGuard.GetDisplayName()
            String targetName = ""
            If DispatchTarget != None
                targetName = DispatchTarget.GetDisplayName()
            EndIf
            String containerDesc = SeverActionsNative.GetContainerDescription(DispatchCurrentContainerRef)

            If DispatchCurrentContainer == DispatchEvidenceContainerIndex
                DebugMsg("EVIDENCE FOUND in container " + DispatchCurrentContainer + "!")

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

                Debug.SendAnimationEvent(DispatchGuard, "IdlePickupFromTableStart")

                BuildEvidenceSummary(targetName)

                String narration = "*" + guardName + " searches " + containerDesc + " and discovers " + DispatchEvidenceSummary + ", tucking the evidence away.*"
                SkyrimNetApi.DirectNarration(narration, DispatchGuard, DispatchTarget)

                String eventMsg = guardName + " found evidence at " + targetName + "'s home: " + DispatchEvidenceSummary
                SkyrimNetApi.RegisterPersistentEvent(eventMsg, DispatchGuard, DispatchTarget)

                Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrest.foundEvidence", ("" + guardName), ("" + DispatchEvidenceName)))

            Else
                DebugMsg("Nothing found in container " + DispatchCurrentContainer)

                String narration = "*" + guardName + " searches " + containerDesc + " but finds nothing suspicious.*"
                SkyrimNetApi.DirectNarration(narration, DispatchGuard, DispatchTarget)
            EndIf

            DispatchSearchSubPhase = 0
            DispatchCurrentContainer += 1
            ChronoArm(UpdateInterval + 1.0)  ; Brief pause between containers
        Else
            ChronoArm(UpdateInterval)
        EndIf
    EndIf
EndFunction

Function CompleteRemainingContainersInstantly()
    {Finish the remaining containers at once, without walking or animation, when the guard goes
     off-screen mid-search. The evidence is still collected.}

    If DispatchEvidenceForm != None && DispatchCurrentContainer <= DispatchEvidenceContainerIndex
        ; The evidence container was not reached: move the evidence to the guard, as the on-screen
        ; search does, so none is left behind for a later search to find.
        ObjectReference evidenceRef = SeverActionsNative.GetSearchContainer(DispatchEvidenceContainerIndex)
        _TakeEvidence(evidenceRef, DispatchEvidenceForm)
        If DispatchEvidenceForm2 != None
            _TakeEvidence(evidenceRef, DispatchEvidenceForm2)
        EndIf
        If DispatchEvidenceForm3 != None
            _TakeEvidence(evidenceRef, DispatchEvidenceForm3)
        EndIf

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

Function _TakeEvidence(ObjectReference akContainer, Form akEvidence)
    {Move one evidence item from its container to the dispatch guard and score it; with no container,
     give the guard a copy scored without container context.}
    If akContainer != None
        SeverActionsNative.RemoveEvidenceFromContainer(akContainer, DispatchGuard, akEvidence, 1)
    Else
        DispatchGuard.AddItem(akEvidence, 1, true)
    EndIf
    DispatchEvidenceQualityScore += SeverActionsNative.ScoreEvidenceQuality(akEvidence, akContainer, DispatchInvestigationReason)
EndFunction

Function TransitionToEvidenceComplete()
    {End the phase-3 search (the evidence is already collected): clean up, restore trespass, pass
     through phase 4 and start the return.}

    If SeverActions_DispatchTravel
        ActorUtil.RemovePackageOverride(DispatchGuard, SeverActions_DispatchTravel)
    EndIf
    If DispatchTravelDestination != None
        DispatchTravelDestination.Clear()
    EndIf

    RestoreTrespass()

    DispatchPhase = 4
    SeverActionsNativeExt.Native_Arrest_SetDispatchPhase(DispatchGuard, DispatchPhase)
    SeverActionsNative.Native_ArrestSession_UpdateState(DispatchTarget, 5, 4)

    Utility.Wait(1.0)
    StartDispatchReturnPhase()
EndFunction

Function CheckDispatchPhase4_Evidence()
    {Phase 4 lasts only until StartDispatchReturnPhase; a tick that finds it (a save loaded
     mid-phase-4) starts the return.}

    DebugMsg("Phase 4: Evidence collection complete (handled in Phase 3), starting return")
    StartDispatchReturnPhase()
EndFunction

Function BuildEvidenceSummary(String targetName)
    {Set DispatchEvidenceSummary ("A and B and C", or "nothing of note") for narration and events.}

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
    {Make the guard (and a loaded player) allies of the homeowner for the search: allies do not
     trigger trespass. RestoreTrespass undoes it.}

    DispatchHomeOwner = DispatchTarget
    If DispatchHomeOwner == None
        Return
    EndIf

    DispatchOrigRelRankGuard = DispatchGuard.GetRelationshipRank(DispatchHomeOwner)
    DispatchGuard.SetRelationshipRank(DispatchHomeOwner, 3)

    ; Flag the player only when their rank was captured, or RestoreTrespass would set it to 0.
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
    {Restore the relationship ranks SuppressTrespass changed.}

    If !DispatchRelRankModified || DispatchHomeOwner == None
        Return
    EndIf

    If DispatchGuard != None
        DispatchGuard.SetRelationshipRank(DispatchHomeOwner, DispatchOrigRelRankGuard)
    EndIf

    ; Only a captured player rank (see SuppressTrespass).
    If DispatchPlayerRelRankModified
        Actor playerRef = Game.GetPlayer()
        playerRef.SetRelationshipRank(DispatchHomeOwner, DispatchOrigRelRankPlayer)
        DispatchPlayerRelRankModified = false
    EndIf

    DispatchRelRankModified = false
    DebugMsg("Trespass restored: relationship ranks returned to original values")
EndFunction

Function CheckDispatchPhase5_Return()
    {Phase 5: the guard returns with the prisoner or evidence to the sender or jail. Loaded arrival
     is OnArrival(dispatch_p5_arrived); on-screen this tick narrates and escalates a stuck guard.
     Off-screen, arrival is the same interior cell or the snapshot distance to the sender, and
     otherwise: a guard in an interior is moved out its door after 10 s (the AI does not path in
     unloaded interiors); else OffScreen_CheckArrival's estimate places them at the destination,
     with a package nudge at 300 s. After the exit or the nudge the dispatch completes on the
     estimate or once the off-screen stretch reaches 180 s.}

    Float dist
    Int stuckLevel
    Bool guardLoaded = DispatchGuard.Is3DLoaded()

    If guardLoaded
        If DispatchGuardOffScreen
            DebugMsg("Guard back on-screen during return")
            DispatchGuardOffScreen = false
            DispatchOffScreenStartTime = 0.0
            DispatchReturnOffScreenCycle = 0
        EndIf

        ; Narrate the escort once, while the pair is loaded, so nearby NPCs can react to it.
        If !DispatchReturnNarrated && !DispatchIsHomeInvestigation && DispatchTarget != None
            DispatchReturnNarrated = true
            String guardName = DispatchGuard.GetDisplayName()
            String targetName = DispatchTarget.GetDisplayName()
            String narration = "*" + guardName + " arrives escorting " + targetName + " in custody, hands bound.*"
            SkyrimNetApi.DirectNarration(narration, DispatchGuard, DispatchTarget)
            DebugMsg("Narrated on-screen return: " + guardName + " escorting " + targetName)
        EndIf

        ; Stuck escalation, outside the grace after a teleport.
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
                    DispatchStuckGraceUntil = Utility.GetCurrentRealTime() + 5.0
                EndIf
            EndIf
        EndIf
    Else
        If !DispatchGuardOffScreen
            DispatchGuardOffScreen = true
            DispatchOffScreenStartTime = Utility.GetCurrentRealTime()
            DebugMsg("Guard went off-screen during return (cycle " + DispatchReturnOffScreenCycle + ")")
        EndIf

        ; Same interior cell as the destination = arrived.
        Cell guardCell = DispatchGuard.GetParentCell()
        If DispatchReturnMarker != None
            Cell destCell = DispatchReturnMarker.GetParentCell()
            If guardCell != None && guardCell == destCell && guardCell.IsInterior()
                DebugMsg("Guard reached return destination cell (off-screen interior)")
                CompleteDispatch()
                Return
            EndIf
        EndIf

        ; Position-snapshot distance to the sender.
        If DispatchSender != None
            Float snapReturnDist = SeverActionsNative.GetDistanceBetweenActors(DispatchGuard, DispatchSender)
            If snapReturnDist >= 0.0 && snapReturnDist <= DispatchArrivalDistance
                DebugMsg("Snapshot distance: guard within " + snapReturnDist + " of sender (off-screen)")
                CompleteDispatch()
                Return
            EndIf
        EndIf

        Float elapsedOffScreen = Utility.GetCurrentRealTime() - DispatchOffScreenStartTime

        ; Interior exit after 10 s: the AI does not move NPCs in an unloaded interior, so the guard
        ; would never reach the door. The delay stands in for the walk out.
        If guardCell != None && guardCell.IsInterior() && elapsedOffScreen >= 10.0 && DispatchReturnOffScreenCycle == 0
            DebugMsg("Return: guard still in interior after " + elapsedOffScreen as Int + "s - forcing virtual exit")

            ; FindDoorToActorCell returns the EXTERIOR door into the guard's cell.
            ObjectReference exteriorDoor = SeverActionsNative.FindDoorToActorCell(DispatchGuard)
            If exteriorDoor != None
                DebugMsg("Found exterior door - moving guard+prisoner outside")
                DispatchGuard.MoveTo(exteriorDoor, 0.0, 0.0, 0.0, false)
                If DispatchTarget != None && !DispatchIsHomeInvestigation
                    DispatchTarget.MoveTo(DispatchGuard, 50.0, 0.0, 0.0, false)
                EndIf
                Utility.Wait(0.3)

                ReapplyReturnPackages()
            Else
                ; No exterior door: move to the interior exit door instead.
                ObjectReference exitDoor = SeverActionsNative.FindExitDoorFromCell(DispatchGuard)
                If exitDoor != None
                    DebugMsg("No exterior door found - nudging guard to interior exit door")
                    DispatchGuard.MoveTo(exitDoor, 0.0, 0.0, 0.0, false)
                    If DispatchTarget != None && !DispatchIsHomeInvestigation
                        DispatchTarget.MoveTo(DispatchGuard, 50.0, 0.0, 0.0, false)
                    EndIf
                    Utility.Wait(0.3)
                    ReapplyReturnPackages()
                Else
                    DebugMsg("No exit door found in guard's cell - will escalate to teleport")
                EndIf
            EndIf

            ; Once only.
            DispatchReturnOffScreenCycle = 1

        ; Cycle 0: OffScreenTracker's distance-based arrival estimate.
        ElseIf DispatchReturnOffScreenCycle == 0
            Int arrivalStatus = SeverActionsNative.OffScreen_CheckArrival(DispatchGuard, Utility.GetCurrentGameTime())
            If arrivalStatus == 1
                DebugMsg("Return: off-screen travel estimate elapsed - teleporting to destination")
                If DispatchReturnMarker != None
                    DispatchGuard.MoveTo(DispatchReturnMarker, 300.0, 0.0, 0.0, false)
                    If DispatchTarget != None && !DispatchIsHomeInvestigation
                        DispatchTarget.MoveTo(DispatchGuard, 50.0, 0.0, 0.0, false)
                    EndIf
                    Utility.Wait(0.5)
                    ReapplyReturnPackages()
                EndIf
                ; Cycle 2: the next off-screen tick force-completes.
                DispatchReturnOffScreenCycle = 2
                DispatchGuardOffScreen = false
                DispatchOffScreenStartTime = 0.0
                DebugMsg("Guard placed near return destination, checking if they load in")
            Else
                ; Progress log every 30 s.
                If Math.Floor(elapsedOffScreen) as Int % 30 == 0 && Math.Floor(elapsedOffScreen) as Int > 0
                    Float estArrival = SeverActionsNative.OffScreen_GetEstimatedArrival(DispatchGuard)
                    DebugMsg("Return: off-screen " + elapsedOffScreen as Int + "s, est. arrival=" + estArrival + ", current=" + Utility.GetCurrentGameTime())
                EndIf

                ; 300 s real time with no arrival: nudge the packages.
                If elapsedOffScreen >= 300.0
                    DebugMsg("Return: 5 min real-time off-screen - nudging packages as safety measure")
                    ReapplyReturnPackages()
                    DispatchReturnOffScreenCycle = 1
                EndIf
            EndIf

        ; Cycle 1+: complete at cycle 2 (already placed), on the estimate (teleport first), or at 180 s.
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
                ; 180 s since this off-screen stretch began, NOT since the nudge: after the 300 s nudge
                ; this fires on the next tick.
                DebugMsg("Return: extended off-screen after nudge - teleporting and completing")
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

    ChronoArm(UpdateInterval)
EndFunction

Function CompleteDispatch()
    {The dispatch is done: the prisoner delivered (judgment hold or jail) or the evidence brought
     back. Tears down the guard's dispatch state and reports.}

    DebugMsg("Dispatch complete!")

    ; ArrivalMonitor drops an entry when it fires; this covers completions that came without the
    ; event (time skip, teleport, snapshot).
    If DispatchGuard != None
        SeverActionsNativeExt.Arrival_Cancel(DispatchGuard)
    EndIf

    SeverActionsNativeExt.Stuck_StopTracking(DispatchGuard)
    SeverActionsNative.OffScreen_StopTracking(DispatchGuard)

    ; Out of the task faction, so the guard can be dispatched (and re-tasked by SkyrimNet) again.
    _LeaveTaskFaction(DispatchGuard)

    ; The SkyrimNet (API v6+) busy lock on the guard.
    If DispatchGuard != None
        SeverActionsNative.Native_SkyrimNet_ClearActorBusy(DispatchGuard)
    EndIf

    SeverActionsNative.SetActorBumpable(DispatchGuard, true)
    If DispatchTarget != None
        SeverActionsNative.SetActorBumpable(DispatchTarget, true)
    EndIf

    RestoreGuardCombatAI()

    If DispatchGuard != None
        DispatchGuard.AllowPCDialogue(true)
    EndIf

    ; Keep the prisoner beside the guard.
    If DispatchGuard != None && DispatchTarget != None
        If DispatchTarget.Is3DLoaded() && DispatchGuard.Is3DLoaded()
            If DispatchTarget.GetDistance(DispatchGuard) > 300.0
                DispatchTarget.MoveTo(DispatchGuard, 50.0, 0.0, 0.0, false)
            EndIf
        EndIf
        Utility.Wait(0.3)
    EndIf

    RemoveAllArrestPackages(DispatchGuard)
    If DispatchTravelDestination != None
        DispatchTravelDestination.Clear()
    EndIf
    ClearAllDispatchLinkedRefs(DispatchGuard)

    If DispatchTarget != None && !DispatchIsHomeInvestigation
        If SeverActions_FollowGuard_Prisoner
            ActorUtil.RemovePackageOverride(DispatchTarget, SeverActions_FollowGuard_Prisoner)
        EndIf
    EndIf

    If DispatchIsHomeInvestigation
        ; Home investigation: report the findings to the sender.
        String guardName = DispatchGuard.GetDisplayName()
        String senderName = ""
        If DispatchSender != None
            senderName = DispatchSender.GetDisplayName()
        EndIf
        String targetName = ""
        If DispatchTarget != None
            targetName = DispatchTarget.GetDisplayName()
        EndIf

        ; Give a loaded player up to 30 s to come within 200 units and witness the hand-off.
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

            ; The items module's giveItem walks over, plays the give animation and transfers it.
            If DispatchSender != None
                If SeverActions_ModuleBase.CallBool("items", "giveItem", DispatchGuard, DispatchSender, itemName, 1.0)
                    DebugMsg("Guard gave evidence to " + senderName + " via GiveItem")
                Else
                    ; No items module (or the hand-off refused): transfer it outright.
                    DispatchGuard.RemoveItem(DispatchEvidenceForm, 1, true, DispatchSender)
                    DebugMsg("Transferred evidence item to " + senderName + " (direct fallback)")
                EndIf
            EndIf

            String reasonContext = ""
            If DispatchInvestigationReason != ""
                reasonContext = " regarding " + DispatchInvestigationReason
            EndIf

            String narration = "*" + guardName + " returns to " + senderName + " and presents the evidence found at " + targetName + "'s home" + reasonContext + ": " + itemName + ". The guard explains where it was found and what it suggests.*"

            ; Narrate now when the player is there (or is the sender), else defer it.
            If playerWitnessed || senderIsPlayer
                SkyrimNetApi.DirectNarration(narration, DispatchGuard, DispatchSender)
            Else
                ; The native pending entry IS the "pending" flag; the arrival watch fires the
                ; narration when the player comes within NarrationProximityRange of the sender.
                SeverActionsNativeExt.Native_Arrest_SetPendingEvidence(DispatchSender, narration, DispatchGuard)
                SeverActionsNativeExt.Native_Arrest_SetDeferredSender(DispatchSender)
                DeferredNarrationSender = DispatchSender
                SeverActionsNativeExt.Arrival_Register(Game.GetPlayer(), DispatchSender, NarrationProximityRange, "narration_witness")
                DebugMsg("Stored deferred evidence narration on " + senderName)
            EndIf

            String eventMsg = guardName + " returned from searching " + targetName + "'s home" + reasonContext + " and brought back " + itemName + " as evidence."
            SkyrimNetApi.RegisterPersistentEvent(eventMsg, DispatchGuard, DispatchSender)

            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrest.returnedWithEvidence", ("" + guardName), ("" + itemName)))
        Else
            DebugMsg("Guard returned to " + senderName + " without evidence")

            String reasonContext = ""
            If DispatchInvestigationReason != ""
                reasonContext = " regarding " + DispatchInvestigationReason
            EndIf

            String narration = "*" + guardName + " returns to " + senderName + " after searching " + targetName + "'s home" + reasonContext + ", reporting that nothing incriminating was found.*"

            ; Now or deferred, as above.
            If playerWitnessed || senderIsPlayer
                SkyrimNetApi.DirectNarration(narration, DispatchGuard, DispatchSender)
            Else
                SeverActionsNativeExt.Native_Arrest_SetPendingEvidence(DispatchSender, narration, DispatchGuard)
                SeverActionsNativeExt.Native_Arrest_SetDeferredSender(DispatchSender)
                DeferredNarrationSender = DispatchSender
                SeverActionsNativeExt.Arrival_Register(Game.GetPlayer(), DispatchSender, NarrationProximityRange, "narration_witness")
                DebugMsg("Stored deferred no-evidence narration on " + senderName)
            EndIf

            String eventMsg = guardName + " returned from searching " + targetName + "'s home but found no evidence."
            SkyrimNetApi.RegisterPersistentEvent(eventMsg, DispatchGuard, DispatchSender)

            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrest.foundNoEvidenceAt", ("" + guardName), ("" + targetName)))
        EndIf

    ElseIf DispatchSender != None && !DispatchSender.IsDead() && !DispatchIsHomeInvestigation
        ; Prisoner delivered to the sender: the phase-6 judgment hold.
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

        String narration = "*" + guardName + " brings " + prisonerName + " before " + senderName + " for judgment. The prisoner stands restrained, awaiting their fate.*"
        SkyrimNetApi.DirectNarration(narration, prisoner, sender)

        String eventMsg = guardName + " has brought " + prisonerName + " before " + senderName + " for judgment."
        SkyrimNetApi.RegisterPersistentEvent(eventMsg, prisoner, sender)

        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrest.awaitsJudgmentFrom", ("" + prisonerName), ("" + senderName)))

        ; Phase 6 keeps the dispatch state: the judgment needs the guard, prisoner and sender.
        DispatchPhase = 6
        SeverActionsNativeExt.Native_Arrest_SetDispatchPhase(DispatchGuard, DispatchPhase)
        SeverActionsNative.Native_ArrestSession_UpdateState(prisoner, 6, 6)
        If JudgmentScript
            JudgmentScript.StartJudgment()
        EndIf

        ; The guard stays with the sender, the prisoner with the guard.
        SeverActionsNative.LinkedRef_Set(guard, sender, SeverActions_FollowTargetKW)
        If SeverActions_GuardFollowPlayer
            ActorUtil.AddPackageOverride(guard, SeverActions_GuardFollowPlayer, PackagePriority, 1)
            guard.EvaluatePackage()
            DebugMsg("Judgment phase: guard following sender " + senderName)
        EndIf

        If prisoner != None
            SeverActionsNative.LinkedRef_Set(prisoner, guard, SeverActions_FollowTargetKW)
            Utility.Wait(0.1)
            If SeverActions_FollowGuard_Prisoner
                ActorUtil.AddPackageOverride(prisoner, SeverActions_FollowGuard_Prisoner, PackagePriority, 1)
                prisoner.EvaluatePackage()
            EndIf
            DebugMsg("Judgment phase: prisoner following guard")
        EndIf

        ; The tick runs the judgment timeout.
        ChronoArm(UpdateInterval)
        Return
    ElseIf DispatchReturnMarker != None
        ; Delivered to jail, with the dispatch's own actors: the Current* slots may be a running
        ; same-cell arrest's.
        If DispatchGuard != None && DispatchTarget != None
            _ArrestLeash(DispatchTarget, DispatchGuard, false)
            JailPrisonerAt(DispatchGuard, DispatchTarget, DispatchReturnMarker, GetJailNameForGuard(DispatchGuard), false)
        EndIf
        ; JailPrisonerAt moved the ArrestSession to kJailed, and that entry must survive: release reads
        ; the captured AVs and OriginalOutfit from it (without it the prisoner keeps the prison outfit for
        ; good). ClearDispatchState ends DispatchTarget's session, so null the target first; the rest of
        ; it needs only DispatchGuard. (The judgment -> jail paths keep it too: the escort through
        ; EnsureBegin, JailDispatchPrisonerNow the same way as here.)
        DispatchTarget = None
    EndIf

    If DispatchUnlockedDoor != None
        DispatchUnlockedDoor.Lock(true)
        DebugMsg("Re-locked home door after investigation")
        DispatchUnlockedDoor = None
    EndIf

    ClearDispatchExitAliases()

    ClearPersistedDispatchState()

    ClearDispatchState()

    ; A pending deferred narration keeps the tick running
    If DeferredNarrationSender != None
        ChronoArm(UpdateInterval)
    EndIf
EndFunction

Function CancelDispatch()
    {Abort the active dispatch: undo everything it did to the guard and target (a target arrested
     on the way back is released) and clear the state.}

    ; A no-op when nothing is registered.
    If DispatchGuard != None
        SeverActionsNativeExt.Arrival_Cancel(DispatchGuard)
    EndIf

    If DispatchGuard != None
        SeverActionsNativeExt.Stuck_StopTracking(DispatchGuard)
        SeverActionsNative.OffScreen_StopTracking(DispatchGuard)
        SeverActionsNative.SetActorBumpable(DispatchGuard, true)
    EndIf

    _LeaveTaskFaction(DispatchGuard)

    If DispatchGuard != None
        SeverActionsNative.Native_SkyrimNet_ClearActorBusy(DispatchGuard)
    EndIf

    If DispatchTarget != None
        SeverActionsNative.SetActorBumpable(DispatchTarget, true)
        ; Phase 2 may have frozen the target; release them, or a guard who dies mid-approach leaves
        ; them unable to move.
        If DispatchTargetMovementFrozen
            DispatchTarget.SetDontMove(false)
            DispatchTargetMovementFrozen = false
        EndIf
    EndIf
    RestoreGuardCombatAI()

    If DispatchIsHomeInvestigation && DispatchGuard != None
        SeverActionsNative.UnregisterSandboxUser(DispatchGuard)
    EndIf

    If DispatchGuard != None
        DispatchGuard.AllowPCDialogue(true)
        RemoveAllArrestPackages(DispatchGuard)
        If DispatchTravelDestination != None
            DispatchTravelDestination.Clear()
        EndIf
        ClearAllDispatchLinkedRefs(DispatchGuard)
        DispatchGuard.EvaluatePackage()
    EndIf

    ; An arrest dispatch's target, arrested or not yet: release them.
    If !DispatchIsHomeInvestigation && DispatchTarget != None
        If SeverActions_FollowGuard_Prisoner
            ActorUtil.RemovePackageOverride(DispatchTarget, SeverActions_FollowGuard_Prisoner)
        EndIf
        ClearAllDispatchLinkedRefs(DispatchTarget)
        ReleasePrisoner(DispatchTarget)
        DispatchTarget.EvaluatePackage()
    EndIf

    ClearDispatchExitAliases()

    If DispatchUnlockedDoor != None
        DispatchUnlockedDoor.Lock(true)
        DebugMsg("Re-locked home door after cancelled investigation")
        DispatchUnlockedDoor = None
    EndIf

    ; End the target's ArrestSession here, as CancelCurrentArrest does on the same-cell path, so no
    ; caller (the session timeout, dead-actor cleanup, an abort) leaks it until the watchdog.
    If DispatchTarget != None
        SeverActionsNative.Native_ArrestSession_End(DispatchTarget)
    EndIf

    ClearPersistedDispatchState()

    ClearDispatchState()

    DebugMsg("Dispatch canceled")
EndFunction

Actor Function FindNearestGuard(Actor akNearActor)
    {The nearest guard to akNearActor within 3000 units, or None (native GuardFinder).}

    If akNearActor == None
        Return None
    EndIf
    Return SeverActionsNative.FindNearestGuard(akNearActor, 3000.0)
EndFunction

String Function GetNPCLocation(String npcName)
    {Location name of the NPC named npcName: "unknown" before ActorFinder is ready, "not found"
     when no NPC matches.}

    If !SeverActionsNative.IsActorFinderReady()
        Return "unknown"
    EndIf

    Actor npc = SeverActionsNative.FindActorByName(npcName)
    If npc == None
        Return "not found"
    EndIf

    Return SeverActionsNative.GetActorLocationName(npc)
EndFunction

; Judgment hold (phase 6): SeverActions_ArrestJudgment.psc (JudgmentScript); CheckDispatchProgress
; routes the tick to it, and the OrderRelease / OrderJailed actions call it directly.

; =============================================================================
; SAVE/LOAD ARREST RECOVERY (same-cell)
; A save mid-approach, mid-arrest or mid-escort must not leave the packages
; orphaned with no tick running: the state is persisted natively and load
; recovery rebuilds the FSM.
; =============================================================================

Function PersistArrestState()
    {Persist the same-cell arrest into the native 'AARS' singleton (separate from the 'ARST'
     session map) whenever ArrestState becomes non-zero, for RecoverActiveArrest.}
    If CurrentGuard == None
        Return
    EndIf

    SeverActionsNativeExt.Native_Arrest_SetActiveArrest(ArrestState, CurrentGuard, CurrentPrisoner, CurrentJailMarker, CurrentJailName, ApproachStartTime, EscortStartTime)
EndFunction

Function ClearPersistedArrestState()
    {Clear the persisted active arrest ('AARS') when the arrest completes or is cancelled.}
    SeverActionsNativeExt.Native_Arrest_ClearActiveArrest()
EndFunction

Function RecoverActiveArrest()
    {Load recovery: rebuild the same-cell arrest from the native active-arrest singleton,
     re-apply the aliases and packages for its ArrestState, and re-arm the tick.}
    Int savedState = SeverActionsNativeExt.Native_Arrest_GetActiveArrestState()
    If savedState <= 0
        Return  ; No active arrest
    EndIf

    Actor guard = SeverActionsNativeExt.Native_Arrest_GetActiveArrestGuard()
    Actor prisoner = SeverActionsNativeExt.Native_Arrest_GetActiveArrestPrisoner()

    If guard == None || prisoner == None
        DebugMsg("Save/load recovery: stale arrest data (guard or prisoner None) - clearing")
        ClearPersistedArrestState()
        Return
    EndIf

    If guard.IsDead() || prisoner.IsDead()
        DebugMsg("Save/load recovery: arrest participant is dead - canceling")
        ClearPersistedArrestState()
        ; Best-effort cleanup on the survivor
        If !prisoner.IsDead()
            ReleasePrisoner(prisoner)
        EndIf
        Return
    EndIf

    DebugMsg("Save/load recovery: rebuilding arrest at state " + savedState)

    CurrentGuard = guard
    CurrentPrisoner = prisoner
    CurrentJailMarker = SeverActionsNativeExt.Native_Arrest_GetActiveArrestJailMarker()
    CurrentJailName = SeverActionsNativeExt.Native_Arrest_GetActiveArrestJailName()
    If CurrentJailName == ""
        CurrentJailName = "jail"
    EndIf
    ArrestState = savedState
    ; Real time is session-relative, so the saved timers are stale: restart the windows from now.
    ApproachStartTime = Utility.GetCurrentRealTime()
    EscortStartTime = Utility.GetCurrentRealTime()
    PrisonerMovementFrozen = false  ; SetDontMove doesn't survive save/load anyway
    PrisonerFrozenAt = 0.0

    ; The aliases the packages target.
    ArrestTarget.ForceRefTo(CurrentPrisoner)
    ArrestingGuard.ForceRefTo(CurrentGuard)
    If CurrentJailMarker != None
        JailDestination.ForceRefTo(CurrentJailMarker)
    EndIf

    If ArrestState == 1
        ; Approaching.
        If SeverActions_GuardApproachTarget
            ActorUtil.AddPackageOverride(CurrentGuard, SeverActions_GuardApproachTarget, PackagePriority, 1)
            CurrentGuard.EvaluatePackage()
        EndIf
        SeverActionsNativeExt.Stuck_StartTracking(CurrentGuard)
        ; ArrivalMonitor registrations are in memory only: re-arm.
        SeverActionsNativeExt.Arrival_Register(CurrentGuard, CurrentPrisoner, ApproachDistance, "arrest_approach_arrived")
    ElseIf ArrestState == 3
        ; Escorting.
        ReapplyEscortPackages(CurrentGuard, CurrentPrisoner, CurrentJailMarker)
        If CurrentJailMarker != None
            SeverActionsNativeExt.Arrival_Register(CurrentGuard, CurrentJailMarker, ArrivalDistance, "arrest_escort_arrived")
        EndIf
        ; The native escort reapplier is in memory only too. Without it an override dropped by a
        ; post-load cell transition or combat stays dropped and the guard freezes mid-escort.
        ; (ArrestState 2 arms it through StartEscortPhase.)
        SeverActionsNative.Native_EscortReapply_Begin(CurrentGuard, CurrentPrisoner)
    EndIf
    ; ArrestState 2 is transient inside PerformArrest: fast-forward to the escort.
    If ArrestState == 2
        ; A jail marker that no longer resolves (its plugin removed) would be dereferenced by
        ; StartEscortPhase: cancel and release instead.
        If CurrentJailMarker == None
            DebugMsg("Save/load recovery: ArrestState==2 with missing jail marker - canceling arrest")
            ClearPersistedArrestState()
            ReleasePrisoner(CurrentPrisoner)
            Return
        EndIf
        DebugMsg("Save/load recovery: ArrestState==2 (transient) - fast-forwarding to escort phase")
        ArrestState = 3
        StartEscortPhase()
        Return
    EndIf

    ChronoArm(UpdateInterval)
    DebugMsg("Save/load recovery complete - resumed at ArrestState " + ArrestState)
EndFunction

; =============================================================================
; SAVE/LOAD DISPATCH RECOVERY
; =============================================================================

Function PersistDispatchState()
    {Save dispatch state to the native cosave for recovery after save/load.
     Called at dispatch start and at each phase transition.}
    If DispatchGuard == None
        Return
    EndIf
    ; The nine context fields go into the 'ARDC' cosave map (keyed by guard FormID); the
    ; active-dispatch-guard singleton rides the same record.
    SeverActionsNativeExt.Native_Arrest_SetDispatchContext(DispatchGuard, DispatchPhase, DispatchTarget, DispatchReturnMarker, DispatchSender, DispatchHomeMarker, DispatchInvestigationReason, DispatchIsHomeInvestigation, DispatchGuardOrigAggression, DispatchGuardOrigConfidence)
    SeverActionsNativeExt.Native_Arrest_SetActiveDispatchGuard(DispatchGuard)
    DebugMsg("Persisted dispatch state for save/load recovery")
EndFunction

Function ClearPersistedDispatchState()
    {Remove dispatch state after dispatch ends.}
    If DispatchGuard != None
        SeverActionsNativeExt.Native_Arrest_ClearDispatchContext(DispatchGuard)
    EndIf
    SeverActionsNativeExt.Native_Arrest_SetActiveDispatchGuard(None)
EndFunction

Function RecoverActiveDispatch()
    {Rebuild dispatch state from the native cosave after a save/load and re-apply the
     aliases, packages and in-memory native registrations of the persisted phase.}

    ; The singleton names the guard the dispatch was managing; the per-guard map has the rest.
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

    If guard.IsDead()
        DebugMsg("Save/load recovery: dispatch guard is dead, canceling")
        ClearPersistedDispatchState()
        ClearDispatchState()
        Return
    EndIf

    DebugMsg("Save/load recovery: rebuilding dispatch Phase " + phase)

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

    ; Real time is session-relative, so the saved timers would fire the timeout / stuck / freeze
    ; fallbacks on the first tick: restart the phase windows from now (as RecoverActiveArrest does).
    Float realNow = Utility.GetCurrentRealTime()
    DispatchPhase2StartTime = realNow
    DispatchSandboxStartTime = realNow
    DispatchContainerSearchStart = realNow
    DispatchOffScreenStartTime = realNow
    DispatchStuckGraceUntil = 0.0
    EscortPleaStartTime = 0.0
    DispatchTargetMovementFrozen = false

    DispatchGuardAlias.ForceRefTo(guard)

    ; The cosaved dispatch context is the claim, so the strip can run at once.
    _BeginGuardTask(guard)
    _GuardOffSchedule(guard)

    ; Re-suppress combat AI
    guard.SetAV("Aggression", 0)
    guard.SetAV("Confidence", 0)
    guard.AllowPCDialogue(false)
    SeverActionsNative.SetActorBumpable(guard, false)

    SeverActionsNativeExt.Stuck_StartTracking(guard)

    If phase == 1
        ; Travelling to the target or their home.
        If DispatchIsHomeInvestigation && DispatchHomeMarker != None
            DispatchTargetAlias.ForceRefTo(DispatchHomeMarker)
        ElseIf DispatchTarget != None
            DispatchTargetAlias.ForceRefTo(DispatchTarget)
        EndIf
        If SeverActions_DispatchJog
            ActorUtil.AddPackageOverride(guard, SeverActions_DispatchJog, PackagePriority, 1)
            guard.EvaluatePackage()
        EndIf
        ObjectReference dest = DispatchTargetAlias.GetReference()
        If dest != None
            SeverActionsNative.OffScreen_InitTracking(guard, dest, 0.5, 18.0)
            ; ArrivalMonitor registrations are in memory only: re-arm (phases 2 and 5 too).
            SeverActionsNativeExt.Arrival_Register(guard, dest, DispatchArrivalDistance, "dispatch_p1_arrived")
        EndIf

    ElseIf phase == 2
        ; Approaching the target for the arrest.
        If DispatchTarget != None
            DispatchTargetAlias.ForceRefTo(DispatchTarget)
            SeverActionsNativeExt.Arrival_Register(guard, DispatchTarget, ApproachDistance, "dispatch_p2_arrived")
        EndIf
        If SeverActions_DispatchJog
            ActorUtil.AddPackageOverride(guard, SeverActions_DispatchJog, PackagePriority, 1)
            guard.EvaluatePackage()
        EndIf

    ElseIf phase == 3 || phase == 4
        ; Investigating the home / collecting evidence: restart as phase 1 travel to the home;
        ; the guard re-arrives and re-triggers the search.
        If DispatchHomeMarker != None
            DispatchTargetAlias.ForceRefTo(DispatchHomeMarker)
            If SeverActions_DispatchJog
                ActorUtil.AddPackageOverride(guard, SeverActions_DispatchJog, PackagePriority, 1)
                guard.EvaluatePackage()
            EndIf
            ; Re-set the sandbox anchor: the cosave restores it at kPostLoadGame, but Papyrus can
            ; run before that and read a null GetLinkedRef.
            If SeverActions_SandboxAnchorKW != None
                ObjectReference anchor = DispatchHomeMarker
                SeverActionsNative.LinkedRef_Set(guard, anchor, SeverActions_SandboxAnchorKW)
            EndIf
            DispatchPhase = 1
            SeverActionsNativeExt.Native_Arrest_SetDispatchPhase(guard, 1)
            ; Push the reset phase into the cosaved ArrestSessionStore entry for the Magelight page.
            If DispatchTarget != None
                SeverActionsNative.Native_ArrestSession_UpdateState(DispatchTarget, 5, 1)
            EndIf
        EndIf

    ElseIf phase == 5
        ; Returning with the prisoner or evidence.
        If DispatchReturnMarker != None
            DispatchTargetAlias.ForceRefTo(DispatchReturnMarker)
        EndIf
        If SeverActions_DispatchWalk
            ActorUtil.AddPackageOverride(guard, SeverActions_DispatchWalk, PackagePriority, 1)
            guard.EvaluatePackage()
        EndIf
        ; An arrest dispatch's prisoner follows the guard.
        If DispatchTarget != None && !DispatchIsHomeInvestigation
            DispatchPrisonerAlias.ForceRefTo(DispatchTarget)
            SeverActionsNative.SetActorBumpable(DispatchTarget, false)
            SeverActionsNative.LinkedRef_Set(DispatchTarget, guard, SeverActions_FollowTargetKW)
            If SeverActions_FollowGuard_Prisoner
                ActorUtil.AddPackageOverride(DispatchTarget, SeverActions_FollowGuard_Prisoner, PackagePriority, 1)
                DispatchTarget.EvaluatePackage()
            EndIf
        EndIf
        If DispatchReturnMarker != None
            SeverActionsNative.OffScreen_InitTracking(guard, DispatchReturnMarker, 0.25, 12.0)
            SeverActionsNativeExt.Arrival_Register(guard, DispatchReturnMarker, DispatchArrivalDistance, "dispatch_p5_arrived")
        EndIf

    ElseIf phase == 6
        ; Judgment hold: restart the judgment timer; the phase tick does the rest.
        If JudgmentScript
            JudgmentScript.StartJudgment()
        EndIf
    EndIf

    ChronoArm(UpdateInterval)
    DebugMsg("Save/load recovery complete - resumed at Phase " + DispatchPhase)
EndFunction

Event OnTrespassNoticed(String eventName, String strArg, Float numArg, Form sender)
    {TrespassMonitor suppressed the vanilla warn-follow for this NPC: file the event so they
     confront the player in dialogue. sender = the NPC, strArg = location name. Once per
     episode (the native side dedupes).}
    Actor npc = sender as Actor
    If !npc
        Return
    EndIf
    ; A sleeper must get up: vanilla's wake came from the trespass package we suppress.
    ; MoveTo(self) interrupts the sleep package.
    If npc.GetSleepState() != 0
        npc.MoveTo(npc)
        npc.EvaluatePackage()
    EndIf
    ; Hold them up and moving toward the intruder, or the sleep/schedule package wins and they go
    ; back to bed. SkyrimNet's FollowPlayer (prio 50) doubles as investigate; OnTrespassWakeEnd
    ; releases it. NOT persistent: the DLL finds whom to release in an in-memory set the revert
    ; hook clears, so a load mid-trespass would leave a persistent package on the NPC for good.
    If !npc.IsPlayerTeammate()
        SkyrimNetApi.RegisterPackage(npc, "FollowPlayer", 50, 0, false)
    EndIf
    Actor player = Game.GetPlayer()
    String place = strArg
    If place == ""
        place = "their home"
    EndIf
    SkyrimNetApi.RegisterShortLivedEvent("trespass_" + npc.GetFormID(), \
        "trespass_noticed", \
        npc.GetDisplayName() + " has just noticed " + player.GetDisplayName() + " inside " + place + " uninvited - an intruder in a place they have no right to be. " + npc.GetDisplayName() + " was not expecting anyone and did not let them in.", \
        "", 120000, npc, player)
    DebugMsg("LLM trespass: " + npc.GetDisplayName() + " noticed the player in " + place)
EndEvent

Event OnTrespassWake(String eventName, String strArg, Float numArg, Form sender)
    {TrespassMonitor's noise scan heard the player near this sleeper: wake them. Waking is
     not noticing - engine detection decides whether they spot the player (then
     OnTrespassNoticed fires), so the event text only says they heard something.}
    Actor npc = sender as Actor
    If !npc || npc.IsDead()
        Return
    EndIf
    If npc.GetSleepState() != 0
        npc.MoveTo(npc)
        npc.EvaluatePackage()
    EndIf
    ; Hold them up and send them looking (see OnTrespassNoticed).
    If !npc.IsPlayerTeammate()
        SkyrimNetApi.RegisterPackage(npc, "FollowPlayer", 50, 0, false)
    EndIf
    SkyrimNetApi.DirectNarration(npc.GetDisplayName() + " stirs awake at the sound of footsteps that should not be there, and rises from bed to see what made them.", npc, Game.GetPlayer())
    SkyrimNetApi.RegisterShortLivedEvent("trespasswake_" + npc.GetFormID(), \
        "woken_by_noise", \
        npc.GetDisplayName() + " is stirred awake by noise inside their home - footsteps that should not be there. They do not yet know what or who made the sound.", \
        "", 60000, npc, npc)
    DebugMsg("LLM trespass: " + npc.GetDisplayName() + " woken by intruder noise")
EndEvent

Event OnTrespassWakeEnd(String eventName, String strArg, Float numArg, Form sender)
    {Trespass ended (player left or gained legitimate access): release the FollowPlayer
     hold so the NPC's normal schedule resumes.}
    Actor npc = sender as Actor
    If !npc
        Return
    EndIf
    SkyrimNetApi.UnregisterPackage(npc, "FollowPlayer")
    npc.EvaluatePackage()
    DebugMsg("LLM trespass: released woken investigator " + npc.GetDisplayName())
EndEvent

; ============================================================================
; M-V VERB DISPATCHER (DR10)
; ============================================================================
; The DLL routes this module's UI verbs (Native/data/verb_table.json) as the ModEvent
; SeverActions_Verb_Arrest with the Actions page's 8 pipe fields. This is the ONE script that
; defines OnVerb_Arrest (a shared callback name runs on every script of the form, F4);
; Maintenance registers it (DR16).
Event OnVerb_Arrest(String eventName, String strArg, Float numArg, Form sender)
    String actionId = SeverActions_ModuleBase.VerbField(strArg, 0)
    String targetName = SeverActions_ModuleBase.VerbField(strArg, 1)
    String target2Name = SeverActions_ModuleBase.VerbField(strArg, 2)
    String strParam = SeverActions_ModuleBase.VerbField(strArg, 3)
    Int intParam = SeverActions_ModuleBase.VerbField(strArg, 4) as Int
    String str2Param = SeverActions_ModuleBase.VerbField(strArg, 5)
    Int targetFid = SeverActions_ModuleBase.VerbField(strArg, 6) as Int
    Int target2Fid = SeverActions_ModuleBase.VerbField(strArg, 7) as Int
    Debug.Trace("[SeverActions_Arrest] OnVerb_Arrest: " + actionId + " target=" + targetName + " target2=" + target2Name \
        + " str=" + strParam + " int=" + intParam + " str2=" + str2Param + " fid=" + targetFid + " fid2=" + target2Fid)

    ; Resolve by the picker's sender, then the encoded FormID, then the fuzzy name; names are
    ; re-canonicalized to display names for the branches that pass a name on.
    Actor target = SeverActions_ModuleBase.VerbActor(sender, targetFid, targetName)
    If !target
        Debug.Trace("[SeverActions_Arrest] OnVerb_Arrest: could not resolve target '" + targetName + "' for " + actionId)
        Return
    EndIf
    targetName = target.GetDisplayName()
    Actor target2 = SeverActions_ModuleBase.VerbActor(None, target2Fid, target2Name)
    If target2
        target2Name = target2.GetDisplayName()
    ElseIf target2Name != ""
        Debug.Trace("[SeverActions_Arrest] OnVerb_Arrest: target2 name '" + target2Name + "' did not resolve to an actor (action=" + actionId + ")")
        SeverActionsNative.Native_Arrest_Log("verb dispatch: target2 name '" + target2Name + "' did not resolve to an actor (action=" + actionId + ")")
    EndIf

    ; This module's captivity script on the same quest: the eight kidnap verbs forward to it.
    SeverActions_Kidnap kidnap = (Self as Quest) as SeverActions_Kidnap

    ; -- Arrest (own code) --
    If actionId == "arrestNPC"
        If !target2
            SeverActionsNative.Native_Arrest_Log("verb arrestNPC skipped - target2 (suspect) is None. target='" + targetName + "' target2Name='" + target2Name + "'")
        Else
            SeverActionsNative.Native_Arrest_Log("verb arrestNPC dispatching: guard='" + targetName + "' suspect='" + target2Name + "'")
            Bool arrestStarted = ArrestNPC_Internal(target, target2)
            SeverActionsNative.Native_Arrest_Log("verb arrestNPC result: " + arrestStarted)
        EndIf

    ElseIf actionId == "freeFromJail"
        If !target2
            SeverActionsNative.Native_Arrest_Log("verb freeFromJail skipped - target2 (jailed NPC) is None. target='" + targetName + "' target2Name='" + target2Name + "'")
        Else
            FreeNPC_Internal(target, target2)
        EndIf

    ElseIf actionId == "dispatchGuardArrest"
        ; target = the guard; target2Name = the NPC to arrest; str2Param = the ordering
        ; authority, the player when unspecified. "Player" becomes the player's display name:
        ; the Execute path's FindActorByName would fuzzy-match it to any NPC containing it.
        String senderName = str2Param
        If senderName == "" || senderName == "Player" || senderName == "player"
            senderName = Game.GetPlayer().GetDisplayName()
        EndIf
        DispatchGuardToArrest_Execute(target, target2Name, senderName)

    ElseIf actionId == "dispatchGuardHome"
        ; target = the guard; target2Name = whose home to search; strParam = the reason;
        ; str2Param = the authority (same normalization).
        String homeSender = str2Param
        If homeSender == "" || homeSender == "Player" || homeSender == "player"
            homeSender = Game.GetPlayer().GetDisplayName()
        EndIf
        DispatchGuardToHome_Execute(target, target2Name, homeSender, strParam)

    ; -- Bounty and the player's own surrender (sibling scripts) --
    ElseIf actionId == "payNpcBounty"
        ; target = the authority taking payment; target2Name = the wanted person, who need not
        ; be present (the authority reads their own hold's wanted list).
        SeverActions_ArrestBounty bountySys = (Self as Quest) as SeverActions_ArrestBounty
        If bountySys
            bountySys.PayNpcBountyToGuard_Internal(target, target2Name)
        EndIf

    ElseIf actionId == "turnMeIn"
        ; The guard (target) arrests the PLAYER: surrender to clear a bounty.
        SeverActions_ArrestPlayer surrenderSys = (Self as Quest) as SeverActions_ArrestPlayer
        If surrenderSys
            surrenderSys.ArrestPlayer_Internal(target)
        EndIf

    ; -- Kidnap (forwarded to SeverActions_Kidnap) --
    ElseIf actionId == "kidnapNPC"
        ; target = the abducting companion; strParam = the victim's name (resolved globally
        ; inside KidnapNPC); str2Param = the destination. KidnapNPC notifies if the toggle is off.
        If kidnap
            kidnap.KidnapNPC(target, strParam, str2Param)
        EndIf

    ElseIf actionId == "releaseCaptive"
        ; target = whoever unties them; strParam = captive name (optional -
        ; matched against active captives only, single captive needs no name).
        If kidnap
            kidnap.ReleaseCaptive(target, strParam)
        EndIf

    ElseIf actionId == "moveCaptive"
        ; target = escorting companion; strParam = captive name (optional);
        ; str2Param = the new hold destination.
        If kidnap
            kidnap.MoveCaptive(target, strParam, str2Param)
        EndIf

    ElseIf actionId == "moveCaptiveHere"
        ; target = the row's kidnapper (hint only - the entry's CURRENT
        ; kidnapper is authoritative inside); strParam = captive name.
        If kidnap
            kidnap.MoveCaptiveHere(target, strParam)
        EndIf

    ElseIf actionId == "demandRansom"
        ; target = the companion sending the demand; strParam = captive name
        ; (optional); intParam = gold demanded (0 = ask a fair price).
        If kidnap
            kidnap.DemandRansom(target, strParam, intParam)
        EndIf

    ElseIf actionId == "untieCaptive"
        If kidnap
            kidnap.UntieCaptive(target, strParam)
        EndIf

    ElseIf actionId == "interrogateCaptive"
        ; target = the interrogator; strParam = captive name (optional).
        If kidnap
            kidnap.InterrogateCaptive(target, strParam)
        EndIf

    ElseIf actionId == "restrainNPC"
        ; RestrainNPC takes the victim by NAME (not an Actor) - target2Name is
        ; the resolved display name from the frontend's actor picker.
        If kidnap
            kidnap.RestrainNPC(target, target2Name)
        EndIf

    ; -- Off-screen jailing (sent by SeverActions_CompanionLife) --
    ElseIf actionId == "offscreenJail"
        ; target = the dismissed companion an off-screen event arrested; strParam = the hold /
        ; home it named. An async verb so the companions module never names this type (B05).
        OffScreenJail(target, strParam)

    Else
        Debug.Trace("[SeverActions_Arrest] OnVerb_Arrest: unknown actionId '" + actionId + "' (not a row this dispatcher carries)")
    EndIf

    ; The DLL's refresh one frame after routing runs before most verbs have written their
    ; stores; by here the forwarded call has returned, so refresh again.
    SeverActionsNative.Magelight_RefreshPage("world")
    SeverActionsNative.Magelight_RefreshPage("enterprises")
EndEvent

Event OnHotkey_Arrest(String eventName, String strArg, Float numArg, Form sender)
    {The arrest module's hotkeys from the DLL's input sink (M-K): TieUntie, also as "wheel:TieUntie"
     when a quick-wheel slot holds it (fromWheel changes nothing here; the wheel lets it through with
     no NPC target, for the furniture tie). TieUntie on furniture while
     the player leads a bound captive: tie them to it (PlayerTieLedCaptive). On the crosshair NPC:
     BOUND -> ReleaseCaptive (any captor); UNBOUND -> restrain with the player as captor and lead
     them (LeashCaptive).}
    String hotkeyId = strArg
    If StringUtil.Substring(strArg, 0, 6) == "wheel:"
        hotkeyId = StringUtil.Substring(strArg, 6)
    EndIf
    Actor target = sender as Actor
    Actor player = Game.GetPlayer()
    Debug.Trace("[SeverActions_Arrest] OnHotkey_Arrest: " + hotkeyId + " target=" + target)
    SeverActions_Kidnap kidnap = (Self as Quest) as SeverActions_Kidnap
    If !kidnap
        Debug.Trace("[SeverActions_Arrest] OnHotkey_Arrest: SeverActions_Kidnap is not bound - ignoring " + hotkeyId)
        Return
    EndIf

    If hotkeyId == "TieUntie"
        ; Before the NPC target: "nearest NPC" target mode would otherwise hand over the led captive.
        ObjectReference aimed = Game.GetCurrentCrosshairRef()
        If aimed && aimed.GetBaseObject() as Furniture && kidnap.PlayerTieLedCaptive(aimed)
            Return
        EndIf
        If !target
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.aimAtSomeoneTie"))
        ElseIf target == player
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.cannotTieYourself"))
        ElseIf target.IsDead()
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("hotkeys.isBeyondTying", ("" + target.GetDisplayName())))
        Else
            ; Phase 3 = held/bound (the only state with something to untie);
            ; phases 1-2 are an in-flight approach/grab a hotkey must not race.
            Int phase = SeverActionsNativeExt.Native_Kidnap_GetPhase(target)
            If phase == 3
                String capName = target.GetDisplayName()
                kidnap.ReleaseCaptive(player, capName)
                ; ReleaseCaptive clears the entry on success; re-read before
                ; narrating a freeing that a refusal may have blocked.
                If SeverActionsNativeExt.Native_Kidnap_GetPhase(target) == 0
                    SkyrimNetApi.RegisterEvent("captive_untied", \
                        player.GetDisplayName() + " unties " + capName + "'s hands and lets them go free.", \
                        player, target)
                    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("hotkeys.youUntie", ("" + capName)))
                EndIf
            ElseIf phase == 1 || phase == 2
                Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("hotkeys.isBeingTaken", ("" + target.GetDisplayName())))
            ElseIf !SeverActionsNativeExt2.Settings_GetBool("restrainEnabled")
                Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.restrainingDisabled"))
            ElseIf SeverActionsNativeExt.Native_GetIsFollower(target)
                Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.willNotBindCompanion"))
            Else
                ; Bind narration deferred: LeashCaptive narrates bind and lead as one event, and
                ; NarrateRestrainedInPlace covers a refused lead.
                If kidnap.PlayerRestrainOnSpot(target, true)
                    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("hotkeys.youBindHands", ("" + target.GetDisplayName())))
                    If !kidnap.LeashCaptive(target, player, true)
                        kidnap.NarrateRestrainedInPlace(target, player)
                    EndIf
                EndIf
            EndIf
        EndIf

    Else
        Debug.Trace("[SeverActions_Arrest] OnHotkey_Arrest: unknown hotkeyId '" + hotkeyId + "' (not a row this dispatcher carries)")
    EndIf
EndEvent

Function OffScreenJail(Actor akNPC, String asHome)
    {Jail a dismissed companion an off-screen life event arrested in the hold it named
     (asHome): jailed faction, cell, jail clothes, tracking row and sandbox pin. Reached by
     the verb arrest.offscreenJail from SeverActions_CompanionLife, which already recorded
     the bounty. No-op when already jailed or the hold has no crime faction or jail marker.}
    If !akNPC || akNPC.IsDead()
        Return
    EndIf
    String actorName = akNPC.GetDisplayName()
    If IsNPCJailed(akNPC)
        DebugMsg("OffScreenJail: " + actorName + " is already jailed, skipping placement")
        Return
    EndIf
    Faction crimeFaction = GetCrimeFactionForHoldName(asHome)
    If !crimeFaction
        DebugMsg("OffScreenJail: no crime faction found for '" + asHome + "' - arrest recorded but " + actorName + " not moved")
        Return
    EndIf
    ObjectReference jailMarker = SeverActionsNative.GetFactionJailMarker(crimeFaction)
    If !jailMarker
        DebugMsg("OffScreenJail: no jail marker found for " + asHome + " - arrest recorded but " + actorName + " not moved")
        Return
    EndIf
    akNPC.AddToFaction(SeverActions_Jailed)

    akNPC.Disable()
    Utility.Wait(0.1)
    akNPC.MoveTo(jailMarker, 0.0, 0.0, 0.0)
    Utility.Wait(0.1)
    akNPC.Enable()

    ChangeToJailClothes(akNPC, crimeFaction)

    StorageUtil.SetFormValue(akNPC, "SeverActions_JailMarker", jailMarker)
    AddJailedNPCAt(akNPC, jailMarker, crimeFaction)

    If SeverActions_PrisonerSandBox
        SeverActionsNativeExt.LinkedRef_SetPermanent(akNPC, jailMarker, SeverActions_SandboxAnchorKW)
        ActorUtil.AddPackageOverride(akNPC, SeverActions_PrisonerSandBox, 110, 1)
        akNPC.EvaluatePackage()
    EndIf

    SkyrimNetApi.RegisterPersistentEvent(actorName + " has been jailed in " + asHome + ".", akNPC, None)
    DebugMsg("OffScreenJail: " + actorName + " placed in jail at " + asHome)
EndFunction


; =============================================================================
; UI BOUNTY BUTTONS
; =============================================================================

Event OnPrismaClearBounty(String eventName, String strArg, Float numArg, Form sender)
    {The UI's Clear Bounty button. strArg = "0|<hold>" - the native helper packs
     "actorName|payload" and a hold-level clear has no actor, so the name half is "0".}
    Int pipePos = StringUtil.Find(strArg, "|")
    String hold = strArg
    If pipePos >= 0
        hold = StringUtil.Substring(strArg, pipePos + 1)
    EndIf
    If hold != ""
        ClearBountyForHold(hold)
    EndIf
EndEvent

Event OnPrismaClearAllBounties(String eventName, String strArg, Float numArg, Form sender)
    {The UI's Clear All Bounties button. See OnPrismaClearBounty.}
    ClearAllBounties()
EndEvent

Function ClearBountyForHold(String hold)
    {Clear the tracked bounty of a hold by its UI display name (Maintenance fills BountyScript).}
    If !BountyScript
        Return
    EndIf
    Faction f = GetCrimeFactionForHold(hold)
    If f
        BountyScript.ClearTrackedBounty(f)
    EndIf
EndFunction

Function ClearAllBounties()
    If !BountyScript
        Return
    EndIf
    BountyScript.ClearTrackedBounty(CrimeFactionEastmarch)
    BountyScript.ClearTrackedBounty(CrimeFactionFalkreath)
    BountyScript.ClearTrackedBounty(CrimeFactionHaafingar)
    BountyScript.ClearTrackedBounty(CrimeFactionHjaalmarch)
    BountyScript.ClearTrackedBounty(CrimeFactionPale)
    BountyScript.ClearTrackedBounty(CrimeFactionReach)
    BountyScript.ClearTrackedBounty(CrimeFactionRift)
    BountyScript.ClearTrackedBounty(CrimeFactionWhiterun)
    BountyScript.ClearTrackedBounty(CrimeFactionWinterhold)
EndFunction

Faction Function GetCrimeFactionForHold(String hold)
    {Hold display name (as the UI sends it, not an EditorID) -> crime faction, or None.}
    If hold == "Eastmarch"
        Return CrimeFactionEastmarch
    ElseIf hold == "Falkreath"
        Return CrimeFactionFalkreath
    ElseIf hold == "Haafingar"
        Return CrimeFactionHaafingar
    ElseIf hold == "Hjaalmarch"
        Return CrimeFactionHjaalmarch
    ElseIf hold == "The Pale"
        Return CrimeFactionPale
    ElseIf hold == "The Reach"
        Return CrimeFactionReach
    ElseIf hold == "The Rift"
        Return CrimeFactionRift
    ElseIf hold == "Whiterun"
        Return CrimeFactionWhiterun
    ElseIf hold == "Winterhold"
        Return CrimeFactionWinterhold
    EndIf
    Return None
EndFunction

Faction Function GetCrimeFactionForHoldName(String asPlace)
    {Forgiving resolver for an off-screen event's "home", which is whatever AssignHome stored
     (a city, a house such as "Breezehome in Whiterun", a hold). Exact hold name first, then
     substrings of each hold and its city; None when nothing matches.}
    If asPlace == ""
        Return None
    EndIf
    Faction exact = GetCrimeFactionForHold(asPlace)
    If exact
        Return exact
    EndIf
    If StringUtil.Find(asPlace, "Whiterun") >= 0
        Return CrimeFactionWhiterun
    ElseIf StringUtil.Find(asPlace, "Riften") >= 0 || StringUtil.Find(asPlace, "Rift") >= 0
        Return CrimeFactionRift
    ElseIf StringUtil.Find(asPlace, "Solitude") >= 0 || StringUtil.Find(asPlace, "Haafingar") >= 0
        Return CrimeFactionHaafingar
    ElseIf StringUtil.Find(asPlace, "Windhelm") >= 0 || StringUtil.Find(asPlace, "Eastmarch") >= 0
        Return CrimeFactionEastmarch
    ElseIf StringUtil.Find(asPlace, "Markarth") >= 0 || StringUtil.Find(asPlace, "Reach") >= 0
        Return CrimeFactionReach
    ElseIf StringUtil.Find(asPlace, "Falkreath") >= 0
        Return CrimeFactionFalkreath
    ElseIf StringUtil.Find(asPlace, "Dawnstar") >= 0 || StringUtil.Find(asPlace, "Pale") >= 0
        Return CrimeFactionPale
    ElseIf StringUtil.Find(asPlace, "Morthal") >= 0 || StringUtil.Find(asPlace, "Hjaalmarch") >= 0
        Return CrimeFactionHjaalmarch
    ElseIf StringUtil.Find(asPlace, "Winterhold") >= 0
        Return CrimeFactionWinterhold
    EndIf
    Return None
EndFunction
