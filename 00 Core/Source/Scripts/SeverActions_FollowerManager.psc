Scriptname SeverActions_FollowerManager extends Quest

{
    SkyrimNet-Native Follower Framework for SeverActions

    Central manager for the follower roster, relationship tracking,
    home assignments, combat style preferences, and relationship decay.

    Replaces traditional follower menus with SkyrimNet's LLM-driven
    conversation - followers are recruited, dismissed, and managed
    through natural dialogue instead of static menu options.

    Follower framework integration (priority order):
    1. Nether's Follower Framework (NFF) - if nwsFollowerFramework.esp is loaded,
       recruitment/dismissal routes through NFF's controller for proper alias
       slots, faction tracking, and compatibility with NFF's systems.
    2. Extensible Follower Framework (EFF) - if EFFCore.esm is loaded,
       recruitment/dismissal routes through EFF's XFL_AddFollower/XFL_RemoveFollower
       for proper alias slots, faction tracking, and EFF plugin compatibility.
    3. Vanilla - if neither framework is installed, uses vanilla Skyrim follower
       mechanics (SetPlayerTeammate + CurrentFollowerFaction).

    Data is stored per-follower via StorageUtil:
    - SeverFollower_IsFollower (1 = active follower)
    - SeverFollower_Rapport (-100 to 100, how they feel about the player)
    - SeverFollower_Trust (0 to 100, willingness to obey dangerous orders)
    - SeverFollower_Loyalty (0 to 100, commitment to staying)
    - SeverFollower_Mood (-100 to 100, current temperament)
    - SeverFollower_CombatStyle (aggressive/defensive/ranged/healer/balanced)
    - SeverFollower_HomeLocation (named location for dismissal)
}

; =============================================================================
; PROPERTIES - Settings (Can be modified via MCM)
; =============================================================================

Int Property MaxFollowers = 20 Auto
{Maximum number of followers allowed at once}

Float Property RapportDecayRate = 1.0 Auto
{How fast rapport decays from neglect (points per 6 game hours without conversation)}

Bool Property AllowAutonomousLeaving = true Auto
{Can followers leave on their own if rapport is too low?}

Float Property LeavingThreshold = -60.0 Auto
{Rapport level at which followers may decide to leave}

Bool Property ShowNotifications = true Auto
{Show notifications for recruitment, dismissal, relationship changes}

Bool Property DebugMode = false Auto
{Enable debug tracing for troubleshooting}

Float Property RelationshipCooldown = 120.0 Auto
{Real-time seconds between allowed AdjustRelationship calls per actor. Default 120 (2 minutes).
Prevents the LLM from spamming relationship changes every dialogue line.}

Bool Property AutoRelAssessment = true Auto
{Enable automatic LLM-based relationship assessment. When true, the OnUpdate loop
periodically sends recent events to the LLM for background relationship evaluation,
replacing the need for the AdjustRelationship action to compete for action slots.}

Float Property AssessmentCooldownHours = 5.0 Auto
{Game hours between automatic relationship assessments per follower.
Default 5.0 (5 game hours). Lower values mean more frequent LLM calls.}

Bool Property AutoInterFollowerAssessment = true Auto
{Enable automatic inter-follower relationship assessment. When true, followers
periodically evaluate how they feel about each other based on shared events.}

Float Property InterFollowerCooldownHours = 8.0 Auto
{Game hours between inter-follower relationship assessments per follower.
Default 8.0 (8 game hours). Each follower is assessed in rotation.}

Float Property DeathGracePeriodHours = 4.0 Auto
{Game hours to wait after a follower's death before auto-removing them from the roster.
Set to 0 to disable auto-removal (manual only via PrismaUI force-remove).}

Int Property FrameworkMode = 0 Auto
{Recruitment mode: 0 = Auto (use NFF/EFF when installed, respect ignore tokens),
 1 = SeverActions Only (bypass NFF/EFF, use our alias-based follow for all).
 Changed via MCM. Takes effect on next recruit, not live.}

; =============================================================================
; SCRIPT REFERENCES
; =============================================================================

SeverActions_Follow Property FollowScript Auto
{Reference to the Follow system for starting/stopping follow packages}

SeverActions_Travel Property TravelScript Auto
{Reference to the Travel system for send-home functionality}

SeverActions_Outfit Property OutfitScript Auto
{Reference to the Outfit system for outfit persistence across cell transitions}

ReferenceAlias[] Property OutfitSlots Auto
{Array of 20 ReferenceAlias slots for per-follower outfit persistence.
 Each slot has SeverActions_OutfitAlias attached, which handles OnLoad/OnCellLoad
 events to re-equip locked outfits instantly. Fill in CK.}

Faction Property SeverActions_FollowerFaction Auto
{Our own follower faction — dedicated to SeverActions.
 Added on recruit, removed on dismiss. Provides fast, unambiguous
 "is this our follower?" checks without StorageUtil lookups.
 Does not conflict with NFF/EFF/vanilla faction systems.
 Create in CK — just a new faction, no special setup needed.}

ReferenceAlias[] Property HomeSlots Auto
{Array of 40 ReferenceAlias slots for home sandboxing.
 Each alias has its own per-slot sandbox package that directly references
 its XMarker (MHiYH pattern). ForceRef assigns the NPC to a slot —
 the alias package then drives sandbox behavior at the marker.
 Persists across save/load (no reapply needed). Fill in CK.}

FormList Property HomeMarkerList Auto
{FormList of 40 XMarkers (one per HomeSlot). Index matches slot index.
 Markers start disabled in SeverActions_HoldingCell. When a home is assigned,
 the marker is moved to the destination and enabled.}

; Per-slot home sandbox packages — fill these in CK, one per HomeSlot alias
Package Property HomeSandboxPackage_00 Auto
Package Property HomeSandboxPackage_01 Auto
Package Property HomeSandboxPackage_02 Auto
Package Property HomeSandboxPackage_03 Auto
Package Property HomeSandboxPackage_04 Auto
Package Property HomeSandboxPackage_05 Auto
Package Property HomeSandboxPackage_06 Auto
Package Property HomeSandboxPackage_07 Auto
Package Property HomeSandboxPackage_08 Auto
Package Property HomeSandboxPackage_09 Auto
Package Property HomeSandboxPackage_10 Auto
Package Property HomeSandboxPackage_11 Auto
Package Property HomeSandboxPackage_12 Auto
Package Property HomeSandboxPackage_13 Auto
Package Property HomeSandboxPackage_14 Auto
Package Property HomeSandboxPackage_15 Auto
Package Property HomeSandboxPackage_16 Auto
Package Property HomeSandboxPackage_17 Auto
Package Property HomeSandboxPackage_18 Auto
Package Property HomeSandboxPackage_19 Auto
Package Property HomeSandboxPackage_20 Auto
Package Property HomeSandboxPackage_21 Auto
Package Property HomeSandboxPackage_22 Auto
Package Property HomeSandboxPackage_23 Auto
Package Property HomeSandboxPackage_24 Auto
Package Property HomeSandboxPackage_25 Auto
Package Property HomeSandboxPackage_26 Auto
Package Property HomeSandboxPackage_27 Auto
Package Property HomeSandboxPackage_28 Auto
Package Property HomeSandboxPackage_29 Auto
Package Property HomeSandboxPackage_30 Auto
Package Property HomeSandboxPackage_31 Auto
Package Property HomeSandboxPackage_32 Auto
Package Property HomeSandboxPackage_33 Auto
Package Property HomeSandboxPackage_34 Auto
Package Property HomeSandboxPackage_35 Auto
Package Property HomeSandboxPackage_36 Auto
Package Property HomeSandboxPackage_37 Auto
Package Property HomeSandboxPackage_38 Auto
Package Property HomeSandboxPackage_39 Auto

SeverActions_Debt Property DebtScript Auto
{Reference to the Debt tracking system for tick-based processing}

SeverActions_Furniture Property FurnitureScript Auto
{Reference to the Furniture system for orphan package cleanup}

; =============================================================================
; CONSTANTS
; =============================================================================

Float Property DEFAULT_RAPPORT = 0.0 AutoReadOnly
Float Property DEFAULT_TRUST = 25.0 AutoReadOnly
Float Property DEFAULT_LOYALTY = 50.0 AutoReadOnly
Float Property DEFAULT_MOOD = 50.0 AutoReadOnly

Float Property RAPPORT_MIN = -100.0 AutoReadOnly
Float Property RAPPORT_MAX = 100.0 AutoReadOnly
Float Property TRUST_MIN = 0.0 AutoReadOnly
Float Property TRUST_MAX = 100.0 AutoReadOnly
Float Property LOYALTY_MIN = 0.0 AutoReadOnly
Float Property LOYALTY_MAX = 100.0 AutoReadOnly
Float Property MOOD_MIN = -100.0 AutoReadOnly
Float Property MOOD_MAX = 100.0 AutoReadOnly

Float Property MOOD_DECAY_RATE = 1.0 AutoReadOnly
{Mood points per game hour drifting toward baseline}

; Time conversion constant: 3631 seconds per game hour at default 20:1 timescale
Float Property SECONDS_PER_GAME_HOUR = 3631.0 AutoReadOnly

Float Property NEGLECT_HOURS = 6.0 AutoReadOnly
{Game hours without conversation before rapport starts decaying}

; StorageUtil key names
String Property KEY_IS_FOLLOWER = "SeverFollower_IsFollower" AutoReadOnly
String Property KEY_RECRUIT_TIME = "SeverFollower_RecruitTime" AutoReadOnly
String Property KEY_RAPPORT = "SeverFollower_Rapport" AutoReadOnly
String Property KEY_TRUST = "SeverFollower_Trust" AutoReadOnly
String Property KEY_LOYALTY = "SeverFollower_Loyalty" AutoReadOnly
String Property KEY_MOOD = "SeverFollower_Mood" AutoReadOnly
String Property KEY_HOME_LOCATION = "SeverFollower_HomeLocation" AutoReadOnly
String Property KEY_HOME_MARKER = "SeverFollower_HomeMarker" AutoReadOnly
String Property KEY_COMBAT_STYLE = "SeverFollower_CombatStyle" AutoReadOnly
String Property KEY_LAST_INTERACTION = "SeverFollower_LastInteraction" AutoReadOnly
String Property KEY_TIMES_RECRUITED = "SeverFollower_TimesRecruited" AutoReadOnly
String Property KEY_ORDERS_REFUSED = "SeverFollower_OrdersRefused" AutoReadOnly
String Property KEY_ORDERS_OBEYED = "SeverFollower_OrdersObeyed" AutoReadOnly

; Morality key (snapshot of vanilla Morality AV for prompt context)
String Property KEY_MORALITY = "SeverFollower_Morality" AutoReadOnly

; Keys for saving/restoring original AI values (vanilla path only)
String Property KEY_ORIG_AGGRESSION = "SeverFollower_OrigAggression" AutoReadOnly
String Property KEY_ORIG_CONFIDENCE = "SeverFollower_OrigConfidence" AutoReadOnly
String Property KEY_ORIG_RELRANK = "SeverFollower_OrigRelRank" AutoReadOnly

; Key for tracking custom-framework followers (Serana, Inigo, Lucien, etc.)
; Set to 1 on recruit if the actor was already IsPlayerTeammate() before we touched them.
; On dismiss, if this is 1, we skip SetPlayerTeammate(false) to avoid breaking their mod's AI.
String Property KEY_WAS_ALREADY_TEAMMATE = "SeverFollower_WasAlreadyTeammate" AutoReadOnly

; Cooldown tracking for AdjustRelationship (real-time seconds via Utility.GetCurrentRealTime)
String Property KEY_LAST_REL_ADJUST = "SeverFollower_LastRelAdjust" AutoReadOnly

; Cooldown tracking for automatic LLM relationship assessment (game hours)
String Property KEY_LAST_ASSESS_GT = "SeverFollower_LastAssessGT" AutoReadOnly

; Cooldown tracking for inter-follower relationship assessment (game hours)
String Property KEY_LAST_INTER_ASSESS_GT = "SeverFollower_LastInterAssessGT" AutoReadOnly

; Global tracking key for all NPCs with custom home assignments (stored on None form)
String Property KEY_HOMED_NPCS = "SeverActions_HomedNPCs" AutoReadOnly

; =============================================================================
; INTERNAL STATE
; =============================================================================

Float LastTickTime
Bool IsUpdating = false

; Relationship assessment tracking — only one assessment in flight at a time
Int PendingAssessmentFormId = 0
Bool AssessmentInProgress = false

; Inter-follower assessment tracking — separate from player-centric assessment
Int PendingInterAssessFormId = 0
Bool InterFollowerAssessmentInProgress = false

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    Debug.Trace("[SeverActions_FollowerManager] Initialized")
    Maintenance()
EndEvent

Function Maintenance()
    {Called on init and game load to set up the update loop}
    LastTickTime = GetGameTimeInSeconds()
    RegisterForSingleUpdate(30.0)

    ; Register for native teammate detection events (instant onboarding)
    RegisterForModEvent("SeverActions_NewTeammateDetected", "OnNativeTeammateDetected")
    RegisterForModEvent("SeverActions_TeammateRemoved", "OnNativeTeammateRemoved")

    ; Register for native orphan package cleanup events
    RegisterForModEvent("SeverActions_OrphanCleanup", "OnOrphanCleanup")

    ; Register for PrismaUI actions
    ; Uses ModEvents because DispatchMethodCall silently fails (returns true but never executes)
    RegisterForModEvent("SeverActions_PrismaAssignHome", "OnPrismaAssignHome")
    RegisterForModEvent("SeverActions_PrismaClearHome", "OnPrismaClearHome")
    RegisterForModEvent("SeverActions_PrismaForceRemove", "OnPrismaForceRemove")
    RegisterForModEvent("SeverActions_PrismaDismiss", "OnPrismaDismiss")
    RegisterForModEvent("SeverActions_PrismaResetAll", "OnPrismaResetAll")

    ; Initialize the native orphan scanner with our LinkedRef keywords
    Keyword travelKW = None
    Keyword furnitureKW = None
    Keyword followKW = None
    If TravelScript
        travelKW = TravelScript.TravelTargetKeyword
    EndIf
    If FurnitureScript
        furnitureKW = FurnitureScript.SeverActions_FurnitureTargetKeyword
    EndIf
    If FollowScript
        followKW = FollowScript.SeverActions_FollowerFollowKW
    EndIf
    SeverActionsNative.OrphanCleanup_Initialize(travelKW, furnitureKW, followKW)

    ; Clear any stuck assessment flags from previous session (callback may not have fired if pex was stale)
    AssessmentInProgress = false
    InterFollowerAssessmentInProgress = false

    ; Auto-detect followers recruited outside our system (vanilla dialogue, NFF, other mods)
    DetectExistingFollowers()

    ; Sync all relationship values from StorageUtil to native FollowerDataStore.
    ; PrismaUI reads from native store (C++ fast path), but values live in StorageUtil.
    ; This ensures PrismaUI shows correct values after every game load.
    SyncAllRelationshipsOnLoad()

    ; Re-assign outfit alias slots after load (ForceRefTo doesn't survive save/load)
    ReassignOutfitSlots()

    ; Re-apply combat style actor values after load
    ; NFF/EFF or the dismiss/recruit cycle can revert Confidence/Aggression to defaults.
    ; The StorageUtil string persists, but the actor value effects may not.
    ReapplyCombatStyles()

    ; Patch-up: ensure all vanilla-path followers have CurrentFollowerFaction + Ally rank
    ; (retroactively applies to followers recruited before this code existed)
    PatchUpVanillaFollowerStatus()

    ; Sync inter-follower pair relationships from StorageUtil to native store
    SyncAllPairRelationshipsOnLoad()

    ; Rebuild pre-formatted companion opinions strings from float values.
    ; StorageUtil strings are unreliable across save/load, but the individual
    ; Affinity/Respect float values persist fine. Rebuild on every load.
    RebuildAllCompanionOpinions()

    ; Update the roster string for prompt template access
    SyncFollowerRoster()

    ; Re-apply follow tracking after load (LinkedRef is runtime-only)
    ; The CK alias packages persist natively, but LinkedRef must be re-set
    ; Run if: SeverActions Only mode, OR no framework installed (Auto mode without NFF/EFF)
    ; Skip if: Auto mode with NFF/EFF managing packages
    ; Skip if: Tracking Only mode — we don't manage follow packages at all
    If FrameworkMode != 2 && (FrameworkMode == 1 || (!HasNFF() && !HasEFF()))
        SeverActions_Follow followSys = GetFollowScript()
        If followSys
            Actor[] followers = GetAllFollowers()
            followSys.ReapplyFollowTracking(followers)
        EndIf
    EndIf

    ; Re-apply home sandbox packages for dismissed NPCs with home markers
    ; Package overrides don't persist across save/load, so reapply on every load
    ReapplyHomeSandboxing()

    ; Register for sleep events — clear sandbox packages when player sleeps
    RegisterForSleep()

    If HasNFF()
        Debug.Trace("[SeverActions_FollowerManager] Maintenance complete - NFF detected, using NFF integration")
    ElseIf HasEFF()
        Debug.Trace("[SeverActions_FollowerManager] Maintenance complete - EFF detected, using EFF integration")
    Else
        Debug.Trace("[SeverActions_FollowerManager] Maintenance complete - no follower framework found, using vanilla follower system")
    EndIf
EndFunction

; =============================================================================
; SLEEP EVENT — CLEAR SANDBOX PACKAGES
; =============================================================================

Event OnSleepStart(Float afSleepStartTime, Float afDesiredSleepEndTime)
    {When the player goes to bed, clear any active sandbox packages (relax/wait)
     on followers IN THE SAME CELL. Sleep time-skips can produce orphaned FF
     runtime packages, so we nuke all overrides preemptively and let the follow
     package re-assert on wake. Followers in other cells are unaffected.}
    SeverActions_Follow followSys = GetFollowScript()
    If !followSys
        Return
    EndIf

    Cell playerCell = Game.GetPlayer().GetParentCell()
    If !playerCell
        Return
    EndIf

    Actor[] followers = GetAllFollowers()
    Int i = 0
    While i < followers.Length
        If followers[i] && followers[i].GetParentCell() == playerCell
            ; Stop sandbox tracking if active
            ; Note: SkyrimNetApi.HasPackage("Sandbox") always returns false because
            ; Sandbox isn't in SkyrimNet's PackageFormCache. Use StorageUtil flag instead.
            If StorageUtil.GetIntValue(followers[i], "SeverActions_IsSandboxing") == 1
                followSys.StopSandbox(followers[i])
                Debug.Trace("[SeverActions_FollowerManager] Cleared sandbox for " + followers[i].GetDisplayName() + " on sleep (same cell)")
            Else
                ; Even non-sandboxing followers: clear any lingering FF orphans
                ActorUtil.ClearPackageOverride(followers[i])
                SkyrimNetApi.ReinforcePackages(followers[i])
                followers[i].EvaluatePackage()
                Debug.Trace("[SeverActions_FollowerManager] Cleared package overrides for " + followers[i].GetDisplayName() + " on sleep (same cell)")
            EndIf
        EndIf
        i += 1
    EndWhile
EndEvent

; =============================================================================
; AUTO-DETECTION OF EXISTING FOLLOWERS
; =============================================================================

Function DetectExistingFollowers()
    {Scan the player's cell for actors who are already followers (in
     CurrentFollowerFaction or IsPlayerTeammate) but don't have our
     SeverFollower_IsFollower tracking flag. Sets up our StorageUtil
     keys so the MCM and relationship system recognize them.
     Does NOT touch faction/teammate status - they're already followers.

     NFF quirk: NFF sets CurrentFollowerFaction rank to -1 on dismiss
     instead of removing from the faction. We must check faction rank >= 0
     to avoid detecting dismissed NFF followers as active.}
    Actor player = Game.GetPlayer()
    Cell playerCell = player.GetParentCell()
    If !playerCell
        Return
    EndIf

    Faction currentFollowerFaction = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction

    ; Also check EFF's faction if EFF is installed
    Faction effFollowerFaction = None
    EFFCore effController = GetEFFController()
    If effController
        effFollowerFaction = effController.XFL_FollowerFaction
    EndIf

    ; Serana uses DLC1SeranaFaction instead of CurrentFollowerFaction
    Faction seranaFaction = Game.GetFormFromFile(0x000183A5, "Dawnguard.esm") as Faction

    Int numRefs = playerCell.GetNumRefs(43) ; 43 = kNPC
    Int detected = 0
    Int i = 0

    While i < numRefs
        ObjectReference ref = playerCell.GetNthRef(i, 43)
        Actor actorRef = ref as Actor

        If actorRef && actorRef != player && !actorRef.IsDead() && !actorRef.IsCommandedActor()
            ; Check if they're a follower but NOT in our system yet.
            ; IMPORTANT: IsPlayerTeammate() alone is NOT sufficient for detection.
            ; Many mods (Katana, Inigo, Lucien, IntelEngine, etc.) set teammate status
            ; for their own purposes without the actor being a "recruited follower."
            ; We require membership in a recognized follower FACTION to trigger auto-detection.
            Bool isGameFollower = false

            ; Check CurrentFollowerFaction — but require rank >= 0
            ; NFF sets rank to -1 on dismiss instead of removing from faction,
            ; so IsInFaction alone would false-positive on dismissed NFF followers
            If currentFollowerFaction
                If actorRef.IsInFaction(currentFollowerFaction) && actorRef.GetFactionRank(currentFollowerFaction) >= 0
                    isGameFollower = true
                EndIf
            EndIf

            If !isGameFollower && effFollowerFaction
                isGameFollower = actorRef.IsInFaction(effFollowerFaction)
            EndIf

            ; Serana uses her own DLC faction instead of CurrentFollowerFaction
            If !isGameFollower && seranaFaction
                isGameFollower = actorRef.IsInFaction(seranaFaction)
            EndIf

            ; Also check our own faction — catches followers whose StorageUtil
            ; co-save data hasn't loaded yet or got corrupted
            If !isGameFollower && SeverActions_FollowerFaction
                If actorRef.IsInFaction(SeverActions_FollowerFaction)
                    isGameFollower = true
                EndIf
            EndIf

            If isGameFollower && !IsRegisteredFollower(actorRef)
                ; Found an untracked follower - fully onboard them into our system.
                ; These are actors recruited via vanilla dialogue, another mod, or before
                ; our plugin was installed. They already have a working follow system,
                ; so we treat them like custom-framework followers: track everything
                ; but don't override their AI packages.

                ; Check if this is a returning follower vs a truly new detection.
                ; Use multiple signals to avoid false-positive resets when StorageUtil
                ; co-save loads slightly after Papyrus fires OnPlayerLoadGame.
                ; Our faction persists in the .esp save (not co-save), so it's always reliable.
                Bool isReturning = false
                If SeverActions_FollowerFaction && actorRef.IsInFaction(SeverActions_FollowerFaction)
                    isReturning = true
                EndIf
                If !isReturning && StorageUtil.HasFloatValue(actorRef, KEY_RAPPORT)
                    isReturning = true
                EndIf
                If !isReturning && StorageUtil.HasStringValue(actorRef, KEY_COMBAT_STYLE)
                    isReturning = true
                EndIf
                If !isReturning && StorageUtil.HasStringValue(actorRef, KEY_HOME_LOCATION)
                    isReturning = true
                EndIf

                ; --- StorageUtil tracking keys ---
                StorageUtil.SetIntValue(actorRef, KEY_IS_FOLLOWER, 1)
                SeverActionsNative.Native_SetIsFollower(actorRef, true)
                StorageUtil.SetFloatValue(actorRef, KEY_LAST_INTERACTION, GetGameTimeInSeconds())

                ; Only set defaults for truly new followers (never in our system before)
                If !isReturning
                    StorageUtil.SetFloatValue(actorRef, KEY_RECRUIT_TIME, GetGameTimeInSeconds())
                    StorageUtil.SetFloatValue(actorRef, KEY_RAPPORT, DEFAULT_RAPPORT)
                    StorageUtil.SetFloatValue(actorRef, KEY_TRUST, DEFAULT_TRUST)
                    StorageUtil.SetFloatValue(actorRef, KEY_LOYALTY, DEFAULT_LOYALTY)
                    StorageUtil.SetFloatValue(actorRef, KEY_MOOD, DEFAULT_MOOD)
                    SeverActionsNative.Native_SetCombatStyle(actorRef, "balanced")
                    SeverActionsNative.Native_SetRelationship(actorRef, DEFAULT_RAPPORT, DEFAULT_TRUST, DEFAULT_LOYALTY, DEFAULT_MOOD)
                    StorageUtil.SetStringValue(actorRef, KEY_COMBAT_STYLE, "balanced")
                    Debug.Trace("[SeverActions_FollowerManager] New follower detected — initialized defaults for " + actorRef.GetDisplayName())
                Else
                    ; Returning follower — sync existing StorageUtil relationship values
                    ; to native FollowerDataStore so PrismaUI shows correct values
                    SyncRelationshipToNative(actorRef)
                    Debug.Trace("[SeverActions_FollowerManager] Returning follower re-detected — preserving existing data for " + actorRef.GetDisplayName())
                EndIf

                ; Snapshot vanilla Morality AV for prompt context
                StorageUtil.SetIntValue(actorRef, KEY_MORALITY, actorRef.GetAV("Morality") as Int)

                ; Mark as already-teammate so dismiss path doesn't undo their teammate status
                StorageUtil.SetIntValue(actorRef, KEY_WAS_ALREADY_TEAMMATE, 1)

                ; --- Faction ---
                ; Add to our faction for fast detection (doesn't conflict with anything)
                If SeverActions_FollowerFaction
                    actorRef.AddToFaction(SeverActions_FollowerFaction)
                EndIf

                ; --- Outfit alias slot ---
                ; Gives them outfit persistence via OnLoad/OnCellLoad events
                AssignOutfitSlot(actorRef)

                ; --- Follow system ---
                ; Route through ShouldUseFramework for consistent routing
                ; Skip for track-only followers (NFF ignore token, DLC-managed, Tracking Only mode)
                If FrameworkMode != 2 && !ShouldUseFramework(actorRef) && !IsTrackOnlyFollower(actorRef)
                    SeverActions_Follow followSys = GetFollowScript()
                    If followSys
                        followSys.CompanionStartFollowing(actorRef)
                    EndIf
                EndIf

                detected += 1
                Debug.Trace("[SeverActions_FollowerManager] Auto-detected existing follower: " + actorRef.GetDisplayName())
            EndIf
        EndIf

        i += 1
    EndWhile

    If detected > 0
        Debug.Trace("[SeverActions_FollowerManager] Auto-detected " + detected + " existing follower(s)")
        If ShowNotifications
            Debug.Notification(detected + " existing companion(s) detected by SeverActions.")
        EndIf
    EndIf
EndFunction

; =============================================================================
; NATIVE TEAMMATE DETECTION EVENT HANDLERS
; Fired by TeammateMonitor in the DLL when SetPlayerTeammate(true/false) is detected
; =============================================================================

Event OnNativeTeammateDetected(string eventName, string strArg, float numArg, Form sender)
    {Instant follower onboarding — fired ~1 second after any mod/vanilla dialogue
     calls SetPlayerTeammate(true) on an actor we're not already tracking.}
    Actor akActor = sender as Actor
    if !akActor
        akActor = Game.GetFormEx(numArg as int) as Actor
    endif

    if !akActor || akActor.IsDead()
        return
    endif

    ; Skip summoned creatures (conjuration, Durnehviir, etc.)
    If akActor.IsCommandedActor()
        return
    EndIf

    ; Already in our system? Skip.
    If IsRegisteredFollower(akActor)
        return
    EndIf

    ; Already in our faction? Also skip (co-save data might not be loaded yet).
    If SeverActions_FollowerFaction && akActor.IsInFaction(SeverActions_FollowerFaction)
        return
    EndIf

    ; Skip actors with NFF ignore token (custom AI followers: Inigo, Lucien, Kaidan, etc.)
    If HasNFFIgnoreToken(akActor)
        Debug.Trace("[SeverActions_FollowerManager] Native teammate has NFF ignore token, skipping: " + akActor.GetDisplayName())
        return
    EndIf

    ; Require membership in a recognized follower faction before onboarding.
    ; SetPlayerTeammate(true) alone is NOT sufficient — many mods (IntelEngine,
    ; Katana, Inigo, etc.) toggle teammate status for their own mechanics.
    ; Only actors in CurrentFollowerFaction (rank >= 0), EFF's faction, or
    ; DLC1SeranaFaction are considered legitimate recruits.
    Faction currentFollowerFaction = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
    Faction seranaFaction = Game.GetFormFromFile(0x000183A5, "Dawnguard.esm") as Faction
    Bool inFollowerFaction = false

    If currentFollowerFaction && akActor.IsInFaction(currentFollowerFaction) && akActor.GetFactionRank(currentFollowerFaction) >= 0
        inFollowerFaction = true
    EndIf

    If !inFollowerFaction
        EFFCore effController = GetEFFController()
        If effController && effController.XFL_FollowerFaction
            inFollowerFaction = akActor.IsInFaction(effController.XFL_FollowerFaction)
        EndIf
    EndIf

    ; Serana uses her own DLC faction instead of CurrentFollowerFaction
    If !inFollowerFaction && seranaFaction
        inFollowerFaction = akActor.IsInFaction(seranaFaction)
    EndIf

    If !inFollowerFaction
        Debug.Trace("[SeverActions_FollowerManager] Native teammate not in any follower faction, skipping: " + akActor.GetDisplayName())
        return
    EndIf

    ; Check if this actor has been in our system before (has relationship values)
    ; If so, they're a returning follower — not a new recruit
    Bool isFirstRecruit = !StorageUtil.HasFloatValue(akActor, KEY_RAPPORT)

    If isFirstRecruit
        Debug.Trace("[SeverActions_FollowerManager] Native teammate detected (NEW): " + akActor.GetDisplayName())
    Else
        Debug.Trace("[SeverActions_FollowerManager] Native teammate detected (RETURNING): " + akActor.GetDisplayName())
    EndIf

    ; --- StorageUtil tracking keys ---
    StorageUtil.SetIntValue(akActor, KEY_IS_FOLLOWER, 1)
    StorageUtil.SetFloatValue(akActor, KEY_LAST_INTERACTION, GetGameTimeInSeconds())

    ; Only set defaults if they've never had relationship values set
    If isFirstRecruit
        StorageUtil.SetFloatValue(akActor, KEY_RECRUIT_TIME, GetGameTimeInSeconds())
        StorageUtil.SetFloatValue(akActor, KEY_RAPPORT, DEFAULT_RAPPORT)
        StorageUtil.SetFloatValue(akActor, KEY_TRUST, DEFAULT_TRUST)
        StorageUtil.SetFloatValue(akActor, KEY_LOYALTY, DEFAULT_LOYALTY)
        StorageUtil.SetFloatValue(akActor, KEY_MOOD, DEFAULT_MOOD)
        SeverActionsNative.Native_SetCombatStyle(akActor, "balanced")
        SeverActionsNative.Native_SetRelationship(akActor, DEFAULT_RAPPORT, DEFAULT_TRUST, DEFAULT_LOYALTY, DEFAULT_MOOD)
        StorageUtil.SetStringValue(akActor, KEY_COMBAT_STYLE, "balanced")
    EndIf

    ; Snapshot vanilla Morality AV for prompt context
    StorageUtil.SetIntValue(akActor, KEY_MORALITY, akActor.GetAV("Morality") as Int)

    ; Mark as already-teammate so dismiss path doesn't undo their teammate status
    StorageUtil.SetIntValue(akActor, KEY_WAS_ALREADY_TEAMMATE, 1)

    ; --- Faction ---
    If SeverActions_FollowerFaction
        akActor.AddToFaction(SeverActions_FollowerFaction)
    EndIf

    ; --- Outfit alias slot ---
    AssignOutfitSlot(akActor)

    ; --- Follow system ---
    ; Route through ShouldUseFramework for consistent routing
    ; Skip for track-only followers (NFF ignore token, DLC-managed, Tracking Only mode)
    If FrameworkMode != 2 && !ShouldUseFramework(akActor) && !IsTrackOnlyFollower(akActor)
        SeverActions_Follow followSys = GetFollowScript()
        If followSys
            followSys.CompanionStartFollowing(akActor)
        EndIf
    EndIf

    ; --- Notifications and events differ for new vs returning followers ---
    If isFirstRecruit
        If ShowNotifications
            Debug.Notification(akActor.GetDisplayName() + " detected as a follower.")
        EndIf

        SkyrimNetApi.RegisterEvent("follower_recruited", \
            akActor.GetDisplayName() + " has been detected and onboarded as a companion.", \
            akActor, Game.GetPlayer())

        DebugMsg("Native teammate detected and onboarded: " + akActor.GetDisplayName())
    Else
        If ShowNotifications
            Debug.Notification(akActor.GetDisplayName() + " has returned.")
        EndIf

        DebugMsg("Returning follower re-registered: " + akActor.GetDisplayName())
    EndIf
EndEvent

Event OnNativeTeammateRemoved(string eventName, string strArg, float numArg, Form sender)
    {Fired when SetPlayerTeammate(false) is detected on a tracked actor.
     DISABLED: Other mods (IntelEngine, etc.) may temporarily strip teammate status
     and restore it later. Reacting here causes followers to be fully unregistered,
     then re-detected as brand new — losing relationship history.
     Our own DismissFollower path handles cleanup when WE dismiss followers.}
    Actor akActor = sender as Actor
    if !akActor
        akActor = Game.GetFormEx(numArg as int) as Actor
    endif

    if akActor
        Debug.Trace("[SeverActions_FollowerManager] Native teammate removal detected (ignored): " + akActor.GetDisplayName())
    endif
EndEvent

Event OnOrphanCleanup(string eventName, string keywordType, float numArg, Form sender)
    {Fired by native OrphanCleanup when an actor has a SeverActions LinkedRef keyword
     but is NOT tracked by any management system. Clears the orphaned LinkedRef,
     removes package overrides, and forces AI re-evaluation so the NPC returns to
     their default routine instead of standing around with an FE runtime package.}
    Actor npc = sender as Actor
    If !npc
        npc = Game.GetFormEx(numArg as Int) as Actor
    EndIf
    If !npc
        Return
    EndIf

    If keywordType == "travel"
        If TravelScript
            SeverActionsNative.LinkedRef_Clear(npc, TravelScript.TravelTargetKeyword)
            TravelScript.RemoveAllTravelPackages(npc)
            If TravelScript.SandboxPackage
                ActorUtil.RemovePackageOverride(npc, TravelScript.SandboxPackage)
            EndIf
        EndIf
    ElseIf keywordType == "furniture"
        If FurnitureScript
            SeverActionsNative.LinkedRef_Clear(npc, FurnitureScript.SeverActions_FurnitureTargetKeyword)
            ActorUtil.RemovePackageOverride(npc, FurnitureScript.SeverActions_UseFurniturePackage)
            SeverActionsNative.UnregisterFurnitureUser(npc)
        EndIf
    ElseIf keywordType == "follow"
        If FollowScript
            SeverActionsNative.LinkedRef_Clear(npc, FollowScript.SeverActions_FollowerFollowKW)
        EndIf
    EndIf

    npc.EvaluatePackage()
    Debug.Trace("[SeverActions_FollowerManager] OrphanCleanup: cleared " + keywordType + " orphan on " + npc.GetDisplayName())
EndEvent

Event OnPrismaAssignHome(string eventName, string strArg, float numArg, Form sender)
    {Fired by PrismaUI when user clicks "Assign Home Here".
     strArg = location name, numArg = actor FormID.
     Runs the full AssignHome path (alias acquisition, XMarker placement, sandbox package).}
    Actor akActor = Game.GetFormEx(numArg as Int) as Actor
    If !akActor
        Debug.Trace("[SeverActions_FollowerManager] PrismaAssignHome: could not resolve actor FormID " + (numArg as Int))
        Return
    EndIf

    String locName = strArg
    If locName == ""
        Debug.Trace("[SeverActions_FollowerManager] PrismaAssignHome: empty location name")
        Return
    EndIf

    DebugMsg("PrismaUI AssignHome: " + akActor.GetDisplayName() + " -> " + locName)
    AssignHome(akActor, locName)
EndEvent

Event OnPrismaClearHome(string eventName, string strArg, float numArg, Form sender)
    {Fired by PrismaUI when user clicks "Clear Home".
     numArg = actor FormID.
     Runs the full ClearHome path (alias release, package removal).}
    Actor akActor = Game.GetFormEx(numArg as Int) as Actor
    If !akActor
        Debug.Trace("[SeverActions_FollowerManager] PrismaClearHome: could not resolve actor FormID " + (numArg as Int))
        Return
    EndIf

    DebugMsg("PrismaUI ClearHome: " + akActor.GetDisplayName())
    ClearHome(akActor)
EndEvent

; =============================================================================
; NFF INTEGRATION
; =============================================================================

Bool Function HasNFF()
    {Check if Nether's Follower Framework is installed}
    Return Game.GetModByName("nwsFollowerFramework.esp") != 255
EndFunction

nwsFollowerControllerScript Function GetNFFController()
    {Get the NFF controller script instance. Returns None if NFF not installed.}
    If !HasNFF()
        Return None
    EndIf
    Quest nwsFF = Game.GetFormFromFile(0x0000434F, "nwsFollowerFramework.esp") as Quest
    If !nwsFF
        Debug.Trace("[SeverActions_FollowerManager] WARNING: NFF ESP found but controller quest missing")
        Return None
    EndIf
    nwsFollowerControllerScript controller = nwsFF as nwsFollowerControllerScript
    If !controller
        Debug.Trace("[SeverActions_FollowerManager] WARNING: NFF quest found but controller script cast failed")
        Return None
    EndIf
    Return controller
EndFunction

Bool Function HasNFFIgnoreToken(Actor akActor)
    {Check if an actor has NFF's nwsIgnoreToken in their inventory.
     The token is a MISC item (FormID 0x051CFC8D in nwsFollowerFramework.esp)
     distributed by SPID to custom AI followers (Inigo, Lucien, Kaidan, etc.)
     so NFF doesn't try to manage them.}
    If !HasNFF()
        Return false
    EndIf
    Form ignoreToken = Game.GetFormFromFile(0x051CFC8D, "nwsFollowerFramework.esp")
    If !ignoreToken
        Return false
    EndIf
    Return akActor.GetItemCount(ignoreToken) > 0
EndFunction

Bool Function IsDLCManagedFollower(Actor akActor)
    {Check if an actor is a DLC-managed follower with their own quest packages.
     Currently checks for Serana (DLC1SeranaFaction from Dawnguard.esm).
     These followers should be tracked for relationships, outfits, survival, etc.
     but their AI packages and teammate status must not be touched.}
    If !akActor
        Return false
    EndIf
    Faction seranaFaction = Game.GetFormFromFile(0x000183A5, "Dawnguard.esm") as Faction
    If seranaFaction && akActor.IsInFaction(seranaFaction)
        Return true
    EndIf
    Return false
EndFunction

Bool Function IsTrackOnlyFollower(Actor akActor)
    {Returns true if this actor should be tracked but not package-managed.
     Covers: NFF ignore-token holders, DLC-managed followers (Serana), and
     Tracking Only mode (FrameworkMode == 2).}
    If FrameworkMode == 2
        Return true
    EndIf
    Return HasNFFIgnoreToken(akActor) || IsDLCManagedFollower(akActor)
EndFunction

Bool Function ShouldUseFramework(Actor akActor)
    {Centralized routing decision: should this actor go through NFF/EFF?
     Returns false if:
     - FrameworkMode == 1 (SeverActions Only)
     - FrameworkMode == 2 (Tracking Only — no package/teammate manipulation at all)
     - Actor has NFF ignore token (custom AI follower)
     - Actor is a DLC-managed follower (Serana)
     Returns true if NFF or EFF is installed and none of the above apply.}
    If FrameworkMode == 1 || FrameworkMode == 2
        Return false
    EndIf
    ; In Auto mode, check for track-only status before routing through framework
    If IsTrackOnlyFollower(akActor)
        DebugMsg(akActor.GetDisplayName() + " is track-only - skipping framework routing")
        Return false
    EndIf
    Return HasNFF() || HasEFF()
EndFunction

; =============================================================================
; EFF INTEGRATION
; =============================================================================

Bool Function HasEFF()
    {Check if Extensible Follower Framework is installed}
    Return Game.GetModByName("EFFCore.esm") != 255
EndFunction

EFFCore Function GetEFFController()
    {Get the EFF controller script instance. Returns None if EFF not installed.}
    If !HasEFF()
        Return None
    EndIf
    Quest effQuest = Game.GetFormFromFile(0x00000EFF, "EFFCore.esm") as Quest
    If !effQuest
        Debug.Trace("[SeverActions_FollowerManager] WARNING: EFFCore.esm found but controller quest missing")
        Return None
    EndIf
    EFFCore controller = effQuest as EFFCore
    If !controller
        Debug.Trace("[SeverActions_FollowerManager] WARNING: EFF quest found but controller script cast failed")
        Return None
    EndIf
    Return controller
EndFunction

; =============================================================================
; UPDATE LOOP - Relationship decay and mood drift
; =============================================================================

Event OnUpdate()
    If IsUpdating
        RegisterForSingleUpdate(30.0)
        Return
    EndIf

    IsUpdating = true

    Float currentTime = GetGameTimeInSeconds()
    Float secondsPassed = currentTime - LastTickTime
    Float hoursPassed = secondsPassed / SECONDS_PER_GAME_HOUR

    ; Only update if meaningful time has passed (at least 0.5 game hours)
    If hoursPassed >= 0.5
        TickRelationships(hoursPassed)
        If DebtScript
            DebtScript.TickDebts(hoursPassed)
        EndIf
        LastTickTime = currentTime
    EndIf

    ; Check for dead followers and auto-remove after grace period
    If DeathGracePeriodHours > 0.0
        CheckDeadFollowers()
    EndIf

    ; Automatic relationship assessments — at most one type per tick to avoid LLM flooding
    If AutoRelAssessment && !InterFollowerAssessmentInProgress
        CheckRelationshipAssessments()
    EndIf

    ; Inter-follower assessment — only fires if no player-centric assessment is in flight
    If AutoInterFollowerAssessment && !AssessmentInProgress && !InterFollowerAssessmentInProgress
        CheckInterFollowerAssessments()
    EndIf

    IsUpdating = false
    RegisterForSingleUpdate(30.0)
EndEvent

Function TickRelationships(Float hoursPassed)
    {Update mood decay and rapport neglect for all followers}
    Actor player = Game.GetPlayer()
    Actor[] followers = GetAllFollowers()

    Int i = 0
    While i < followers.Length
        Actor follower = followers[i]
        If follower && !follower.IsDead()
            TickFollowerRelationship(follower, hoursPassed)
        EndIf
        i += 1
    EndWhile
EndFunction

Function TickFollowerRelationship(Actor akFollower, Float hoursPassed)
    {Update a single follower's relationship values}

    ; --- Mood Decay ---
    ; Mood drifts toward a baseline derived from rapport
    Float rapport = GetRapport(akFollower)
    Float mood = GetMood(akFollower)
    Float baseline = rapport * 0.5  ; Baseline mood is half of rapport

    Float moodDiff = baseline - mood
    Float moodChange = MOOD_DECAY_RATE * hoursPassed

    If Math.Abs(moodDiff) <= moodChange
        SetMood(akFollower, baseline)
    Else
        If moodDiff > 0
            ModifyMood(akFollower, moodChange)
        Else
            ModifyMood(akFollower, -moodChange)
        EndIf
    EndIf

    ; --- Rapport Neglect ---
    ; If the player hasn't talked to this follower in a while, rapport decays
    Float lastInteraction = StorageUtil.GetFloatValue(akFollower, KEY_LAST_INTERACTION, 0.0)
    Float currentTime = GetGameTimeInSeconds()
    Float hoursSinceInteraction = (currentTime - lastInteraction) / SECONDS_PER_GAME_HOUR

    If hoursSinceInteraction > NEGLECT_HOURS
        Float neglectPeriods = (hoursSinceInteraction - NEGLECT_HOURS) / NEGLECT_HOURS
        Float rapportLoss = RapportDecayRate * (hoursPassed / NEGLECT_HOURS)
        If rapportLoss > 0.0
            ModifyRapport(akFollower, -rapportLoss)
        EndIf
    EndIf

    ; --- Autonomous Leaving Check ---
    If AllowAutonomousLeaving
        rapport = GetRapport(akFollower) ; Re-read after potential decay
        If rapport <= LeavingThreshold
            ; Only fire the persistent event once per unhappy episode
            ; Prevents spamming SkyrimNet's event buffer every 30-second tick
            If StorageUtil.GetIntValue(akFollower, "SeverFollower_LeaveWarned", 0) == 0
                StorageUtil.SetIntValue(akFollower, "SeverFollower_LeaveWarned", 1)
                SkyrimNetApi.RegisterPersistentEvent( \
                    akFollower.GetDisplayName() + " is deeply unhappy and considering leaving " + Game.GetPlayer().GetDisplayName() + "'s service.", \
                    akFollower, Game.GetPlayer())
            EndIf
        Else
            ; Rapport recovered above threshold — reset the warning flag
            If StorageUtil.GetIntValue(akFollower, "SeverFollower_LeaveWarned", 0) == 1
                StorageUtil.SetIntValue(akFollower, "SeverFollower_LeaveWarned", 0)
            EndIf
        EndIf
    EndIf

    ; Sync relationship values to native FollowerDataStore after decay/neglect updates
    SyncRelationshipToNative(akFollower)

    If DebugMode
        Debug.Trace("[SeverActions_FollowerManager] Tick: " + akFollower.GetDisplayName() + \
            " rapport=" + GetRapport(akFollower) + \
            " trust=" + GetTrust(akFollower) + \
            " mood=" + GetMood(akFollower))
    EndIf
EndFunction

; =============================================================================
; OUTFIT SLOT MANAGEMENT - ReferenceAlias-based outfit persistence
; =============================================================================

Function AssignOutfitSlot(Actor akActor)
    {Find an empty ReferenceAlias outfit slot and assign the actor to it.
     The alias script (SeverActions_OutfitAlias) handles OnLoad/OnCellLoad
     events to re-equip locked outfits with zero flicker.}
    If !OutfitSlots
        DebugMsg("WARNING: OutfitSlots array not set - outfit persistence disabled")
        Return
    EndIf

    ; Guard against duplicate assignment — if already in a slot, skip
    Int check = 0
    While check < OutfitSlots.Length
        If OutfitSlots[check] && OutfitSlots[check].GetActorRef() == akActor
            DebugMsg("Outfit slot " + check + " already assigned to " + akActor.GetDisplayName() + " — skipping")
            Return
        EndIf
        check += 1
    EndWhile

    Int i = 0
    While i < OutfitSlots.Length
        If OutfitSlots[i] && !OutfitSlots[i].GetActorRef()
            OutfitSlots[i].ForceRefTo(akActor)
            DebugMsg("Outfit slot " + i + " assigned to " + akActor.GetDisplayName())

            ; If the actor's 3D is already loaded (e.g. reassignment after save/load),
            ; OnLoad won't fire again, so immediately reapply the locked outfit now.
            If akActor.Is3DLoaded()
                SeverActions_Outfit outfitSys = GetOutfitScript()
                If outfitSys
                    outfitSys.ReapplyLockedOutfit(akActor)
                EndIf
            EndIf
            Return
        EndIf
        i += 1
    EndWhile

    DebugMsg("WARNING: No free outfit slots for " + akActor.GetDisplayName())
EndFunction

Function ClearOutfitSlot(Actor akActor)
    {Find and clear the ReferenceAlias outfit slot for this actor.}
    If !OutfitSlots
        Return
    EndIf

    Int i = 0
    While i < OutfitSlots.Length
        If OutfitSlots[i] && OutfitSlots[i].GetActorRef() == akActor
            OutfitSlots[i].Clear()
            DebugMsg("Outfit slot " + i + " cleared for " + akActor.GetDisplayName())
            Return
        EndIf
        i += 1
    EndWhile
EndFunction

Function ReassignOutfitSlots()
    {Re-assign outfit alias slots after a game load.
     ForceRefTo is runtime-only and doesn't survive save/load, so we need to
     repopulate the alias slots every time Maintenance() runs.
     Covers both active followers AND dismissed actors with outfit locks.}
    If !OutfitSlots
        Return
    EndIf

    ; Clear any stale alias data first
    Int i = 0
    While i < OutfitSlots.Length
        If OutfitSlots[i]
            OutfitSlots[i].Clear()
        EndIf
        i += 1
    EndWhile

    Int totalAssigned = 0

    ; Re-assign slots for all current followers
    Actor[] followers = GetAllFollowers()
    i = 0
    While i < followers.Length
        If followers[i]
            AssignOutfitSlot(followers[i])
            totalAssigned += 1
        EndIf
        i += 1
    EndWhile

    ; Also assign slots for dismissed actors who still have active outfit locks.
    ; Without this, dismissed followers lose alias events on save/load and go naked.
    SeverActions_Outfit outfitSys = GetOutfitScript()
    If outfitSys
        Actor[] lockedActors = outfitSys.GetOutfitLockedActors()
        i = 0
        While i < lockedActors.Length
            If lockedActors[i]
                ; Skip actors already assigned (they're still active followers)
                Bool alreadyAssigned = false
                Int j = 0
                While j < followers.Length
                    If followers[j] == lockedActors[i]
                        alreadyAssigned = true
                        j = followers.Length ; break
                    EndIf
                    j += 1
                EndWhile

                If !alreadyAssigned
                    AssignOutfitSlot(lockedActors[i])
                    totalAssigned += 1
                    DebugMsg("Outfit slot assigned for dismissed actor: " + lockedActors[i].GetDisplayName())
                EndIf
            EndIf
            i += 1
        EndWhile
    EndIf

    If totalAssigned > 0
        DebugMsg("Reassigned outfit slots for " + totalAssigned + " actor(s) after load (" + followers.Length + " followers + " + (totalAssigned - followers.Length) + " dismissed with outfits)")
    EndIf
EndFunction

; =============================================================================
; DEATH CLEANUP & FORCE-REMOVE
; =============================================================================

Function CheckDeadFollowers()
    {Scan registered followers for deaths and auto-remove after grace period.
     Called from OnUpdate when DeathGracePeriodHours > 0.}
    Float currentTime = GetGameTimeInSeconds()

    ; Scan all actors in FollowerDataStore by iterating OutfitSlots + FollowerDataStore
    ; We iterate OutfitSlots because those are the alias-tracked followers.
    ; Any that are dead get timestamped, then removed after the grace period.
    If !OutfitSlots
        Return
    EndIf

    Int i = 0
    While i < OutfitSlots.Length
        If OutfitSlots[i]
            Actor slotActor = OutfitSlots[i].GetActorRef()
            If slotActor && slotActor.IsDead()
                ; Check if we've already recorded the death time
                Float deathTime = StorageUtil.GetFloatValue(slotActor, "SeverFollower_DeathTime", 0.0)
                If deathTime == 0.0
                    ; First detection — record death time
                    StorageUtil.SetFloatValue(slotActor, "SeverFollower_DeathTime", currentTime)
                    DebugMsg("Death detected: " + slotActor.GetDisplayName() + " — grace period started (" + DeathGracePeriodHours + " hours)")
                    If ShowNotifications
                        Debug.Notification(slotActor.GetDisplayName() + " has fallen...")
                    EndIf
                Else
                    ; Check if grace period has elapsed
                    Float hoursSinceDeath = (currentTime - deathTime) / SECONDS_PER_GAME_HOUR
                    If hoursSinceDeath >= DeathGracePeriodHours
                        String deadName = slotActor.GetDisplayName()
                        DebugMsg("Death cleanup: removing " + deadName + " after " + hoursSinceDeath + " hours")
                        PurgeFollower(slotActor)
                        SeverActionsNative.Native_RemoveFollowerData(slotActor)
                        If ShowNotifications
                            Debug.Notification(deadName + " has been removed from your companions (deceased)")
                        EndIf
                    EndIf
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile
EndFunction

Function PurgeFollower(Actor akActor)
    {Unconditionally remove ALL data for a follower — StorageUtil, factions, aliases, roster.
     Works for force-remove (PrismaUI) and death cleanup. None-safe where possible.}
    If !akActor
        Return
    EndIf

    String actorName = akActor.GetDisplayName()
    DebugMsg("PurgeFollower: " + actorName)

    ; --- Clear all StorageUtil keys ---
    StorageUtil.UnsetIntValue(akActor, KEY_IS_FOLLOWER)
    StorageUtil.UnsetFloatValue(akActor, KEY_RECRUIT_TIME)
    StorageUtil.UnsetFloatValue(akActor, KEY_RAPPORT)
    StorageUtil.UnsetFloatValue(akActor, KEY_TRUST)
    StorageUtil.UnsetFloatValue(akActor, KEY_LOYALTY)
    StorageUtil.UnsetFloatValue(akActor, KEY_MOOD)
    StorageUtil.UnsetStringValue(akActor, KEY_HOME_LOCATION)
    StorageUtil.UnsetStringValue(akActor, KEY_HOME_MARKER)
    StorageUtil.UnsetStringValue(akActor, KEY_COMBAT_STYLE)
    StorageUtil.UnsetFloatValue(akActor, KEY_LAST_INTERACTION)
    StorageUtil.UnsetIntValue(akActor, KEY_TIMES_RECRUITED)
    StorageUtil.UnsetIntValue(akActor, KEY_ORDERS_REFUSED)
    StorageUtil.UnsetIntValue(akActor, KEY_ORDERS_OBEYED)
    StorageUtil.UnsetIntValue(akActor, KEY_MORALITY)
    StorageUtil.UnsetFloatValue(akActor, KEY_ORIG_AGGRESSION)
    StorageUtil.UnsetFloatValue(akActor, KEY_ORIG_CONFIDENCE)
    StorageUtil.UnsetIntValue(akActor, KEY_ORIG_RELRANK)
    StorageUtil.UnsetIntValue(akActor, KEY_WAS_ALREADY_TEAMMATE)
    StorageUtil.UnsetFloatValue(akActor, KEY_LAST_REL_ADJUST)
    StorageUtil.UnsetFloatValue(akActor, KEY_LAST_ASSESS_GT)
    StorageUtil.UnsetFloatValue(akActor, KEY_LAST_INTER_ASSESS_GT)

    ; Assessment dedup watermarks
    StorageUtil.UnsetIntValue(akActor, "SeverFollower_LastAssessEventId")
    StorageUtil.UnsetIntValue(akActor, "SeverFollower_LastAssessMemoryId")
    StorageUtil.UnsetIntValue(akActor, "SeverFollower_LastAssessDiaryId")
    StorageUtil.UnsetIntValue(akActor, "SeverFollower_LeaveWarned")
    StorageUtil.UnsetFloatValue(akActor, "SeverFollower_DeathTime")

    ; --- Remove from factions ---
    If SeverActions_FollowerFaction
        akActor.RemoveFromFaction(SeverActions_FollowerFaction)
    EndIf

    Faction currentFollowerFaction = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
    If currentFollowerFaction
        akActor.RemoveFromFaction(currentFollowerFaction)
    EndIf

    Faction playerFollowerFaction = Game.GetFormFromFile(0x084D1B, "Skyrim.esm") as Faction
    If playerFollowerFaction
        akActor.RemoveFromFaction(playerFollowerFaction)
    EndIf

    akActor.SetPlayerTeammate(false)

    ; --- Clear outfit slot ---
    ClearOutfitSlot(akActor)

    ; --- Clear home assignment ---
    ClearHome(akActor)

    ; --- Stop following if active ---
    SeverActions_Follow followSys = GetFollowScript()
    If followSys
        followSys.CompanionStopFollowing(akActor)
    EndIf

    ; --- Sync roster ---
    SyncFollowerRoster()

    DebugMsg("PurgeFollower complete: " + actorName)
EndFunction

Event OnPrismaForceRemove(string eventName, string strArg, float numArg, Form sender)
    {Handle force-remove from PrismaUI. The C++ side already clears native stores;
     this handles Papyrus-side cleanup (StorageUtil, factions, aliases).}
    Int formID = numArg as Int
    If formID == 0
        Return
    EndIf

    Actor akActor = Game.GetForm(formID) as Actor
    If akActor
        DebugMsg("PrismaUI force-remove: " + akActor.GetDisplayName())
        PurgeFollower(akActor)
    Else
        Debug.Trace("[SeverActions_FollowerManager] PrismaUI force-remove: actor " + formID + " not resolvable (orphan) — native stores already cleared")
    EndIf
EndEvent

Event OnPrismaDismiss(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: Dismiss a specific follower. numArg = actor FormID.}
    Int formID = numArg as Int
    If formID == 0
        Return
    EndIf
    Actor akActor = Game.GetForm(formID) as Actor
    If akActor
        DebugMsg("PrismaUI dismiss: " + akActor.GetDisplayName())
        DismissCompanion(akActor)
    EndIf
EndEvent

Event OnPrismaResetAll(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: Dismiss all companions.}
    Debug.Trace("[SeverActions_FollowerManager] PrismaUI reset all companions")
    Actor[] allComp = GetAllFollowers()
    If allComp
        Int ci = 0
        While ci < allComp.Length
            If allComp[ci]
                DismissCompanion(allComp[ci])
            EndIf
            ci += 1
        EndWhile
    EndIf
EndEvent

; =============================================================================
; ROSTER MANAGEMENT
; =============================================================================

Function RegisterFollower(Actor akActor)
    {Add an actor to the follower roster and start them following.
     Routes through NFF/EFF when available, otherwise uses vanilla mechanics.}
    If !akActor || akActor.IsDead()
        Return
    EndIf

    If !CanRecruitMore()
        Debug.Notification("You have too many followers already.")
        SkyrimNetApi.RegisterEvent("follower_recruit_failed", \
            akActor.GetDisplayName() + " cannot join because " + Game.GetPlayer().GetDisplayName() + " already has too many companions.", \
            akActor, Game.GetPlayer())
        Return
    EndIf

    ; Check if this is a returning follower (has relationship values from before)
    Bool isFirstRecruit = !StorageUtil.HasFloatValue(akActor, KEY_RAPPORT)

    ; --- Our own tracking (always, regardless of framework) ---
    StorageUtil.SetIntValue(akActor, KEY_IS_FOLLOWER, 1)
    SeverActionsNative.Native_SetIsFollower(akActor, true)
    StorageUtil.SetFloatValue(akActor, KEY_LAST_INTERACTION, GetGameTimeInSeconds())

    ; Add to our own faction for fast, unambiguous detection
    If SeverActions_FollowerFaction
        akActor.AddToFaction(SeverActions_FollowerFaction)
    EndIf

    ; Set default relationship values and recruit time only on first recruit
    If isFirstRecruit
        StorageUtil.SetFloatValue(akActor, KEY_RECRUIT_TIME, GetGameTimeInSeconds())
        StorageUtil.SetFloatValue(akActor, KEY_RAPPORT, DEFAULT_RAPPORT)
        StorageUtil.SetFloatValue(akActor, KEY_TRUST, DEFAULT_TRUST)
        StorageUtil.SetFloatValue(akActor, KEY_LOYALTY, DEFAULT_LOYALTY)
        StorageUtil.SetFloatValue(akActor, KEY_MOOD, DEFAULT_MOOD)
        SeverActionsNative.Native_SetCombatStyle(akActor, "balanced")
        SeverActionsNative.Native_SetRelationship(akActor, DEFAULT_RAPPORT, DEFAULT_TRUST, DEFAULT_LOYALTY, DEFAULT_MOOD)
        StorageUtil.SetStringValue(akActor, KEY_COMBAT_STYLE, "balanced")
    EndIf

    ; Snapshot vanilla Morality AV for prompt context (0=Any Crime, 1=Violence, 2=Property, 3=None)
    StorageUtil.SetIntValue(akActor, KEY_MORALITY, akActor.GetAV("Morality") as Int)

    ; Recruitment rapport bonus (only on first recruit — don't stack on re-recruit)
    If isFirstRecruit
        ModifyRapport(akActor, 5.0)
        ModifyTrust(akActor, 5.0)
    EndIf

    ; --- Make them a proper follower ---
    ; Check if this actor is already a teammate BEFORE we touch anything.
    Bool wasAlreadyTeammate = akActor.IsPlayerTeammate()

    ; Tracking Only mode: treat ALL followers as track-only.
    ; We still register them for relationships, outfits, survival, debt, etc.
    ; but we don't touch their teammate status, AI values, or follow packages.
    ; Their existing mod (NFF, EFF, custom framework, etc.) handles all of that.
    If FrameworkMode == 2
        wasAlreadyTeammate = true
    EndIf

    ; Determine routing: framework vs our system vs track-only
    Bool useFramework = ShouldUseFramework(akActor)
    Bool isTrackOnly = IsTrackOnlyFollower(akActor)

    nwsFollowerControllerScript nffController = None
    EFFCore effController = None

    If useFramework
        nffController = GetNFFController()
        If !nffController
            effController = GetEFFController()
        EndIf
    EndIf

    If nffController
        ; NFF path: let NFF handle SetPlayerTeammate, factions, alias slots, packages
        DebugMsg("NFF routing: " + akActor.GetDisplayName())
        nffController.RecruitFollower(akActor)
    ElseIf effController
        ; EFF path: let EFF handle SetPlayerTeammate, factions, alias slots, relationship ranks
        DebugMsg("EFF routing: " + akActor.GetDisplayName())
        effController.XFL_AddFollower(akActor as Form)
    ElseIf wasAlreadyTeammate || isTrackOnly
        ; Track-only: custom framework follower, NFF-ignore-token holder, or DLC-managed (Serana)
        ; They keep their own follow system. We just track for relationships/outfit/survival.
        StorageUtil.SetIntValue(akActor, KEY_WAS_ALREADY_TEAMMATE, 1)
        DebugMsg("Track-only: " + akActor.GetDisplayName() + " (wasTeammate=" + wasAlreadyTeammate + ", trackOnly=" + isTrackOnly + ")")
    Else
        ; Vanilla/SeverActions path: handle follower mechanics ourselves
        DebugMsg("SeverActions routing: " + akActor.GetDisplayName())

        ; Clear any stale custom-follower flag
        StorageUtil.UnsetIntValue(akActor, KEY_WAS_ALREADY_TEAMMATE)

        ; Save original AI values so we can restore on dismissal
        StorageUtil.SetFloatValue(akActor, KEY_ORIG_AGGRESSION, akActor.GetAV("Aggression"))
        StorageUtil.SetFloatValue(akActor, KEY_ORIG_CONFIDENCE, akActor.GetAV("Confidence"))
        StorageUtil.SetIntValue(akActor, KEY_ORIG_RELRANK, akActor.GetRelationshipRank(Game.GetPlayer()))

        ; SetPlayerTeammate handles combat alliance, sneak sync, weapon draw sync, crime sharing.
        akActor.SetPlayerTeammate(true)
        akActor.IgnoreFriendlyHits(true)

        ; Add to CurrentFollowerFaction so vanilla dialogue recognizes them as a follower
        ; (removes "Follow me" option, enables inventory access via dialogue, etc.)
        Faction currentFollowerFaction = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
        If currentFollowerFaction
            akActor.AddToFaction(currentFollowerFaction)
            akActor.SetFactionRank(currentFollowerFaction, 0)
        EndIf

        ; Set relationship rank to Ally (3) so vanilla systems treat them as a real companion
        akActor.SetRelationshipRank(Game.GetPlayer(), 3)
    EndIf

    ; Ensure ALL registered followers are in CurrentFollowerFaction regardless of routing.
    ; DLC followers like Serana use their own follow systems and skip the vanilla path above,
    ; but SkyrimNet's is_follower() decorator checks CurrentFollowerFaction. Without this,
    ; prompt templates break with decnpc/is_in_faction errors for DLC followers.
    ; NFF manages this faction itself on dismiss (sets rank -1), so no conflict.
    Faction ensureCFF = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
    If ensureCFF && akActor.GetFactionRank(ensureCFF) < 0
        akActor.AddToFaction(ensureCFF)
        akActor.SetFactionRank(ensureCFF, 0)
        DebugMsg("Ensured CurrentFollowerFaction for " + akActor.GetDisplayName() + " (was rank " + akActor.GetFactionRank(ensureCFF) + ")")
    EndIf

    ; Remove home sandbox package if it was active (NPC was dismissed at home)
    ; Must happen before follow packages are applied so priority 50 > 40 isn't contested
    RemoveHomeSandbox(akActor)

    ; Start companion following via our CK alias-based package
    ; Skip for NFF/EFF (they manage their own packages), custom followers,
    ; DLC-managed followers (Serana), and ignore-token holders
    If !nffController && !effController && !wasAlreadyTeammate && !isTrackOnly
        SeverActions_Follow followSys = GetFollowScript()
        If followSys
            followSys.CompanionStartFollowing(akActor)
        EndIf
    EndIf

    ; Assign an outfit alias slot for zero-flicker outfit persistence
    AssignOutfitSlot(akActor)

    ; Re-apply combat style actor values for returning followers
    ; The dismiss path restores original AI values, so we need to re-set them
    If !isFirstRecruit
        String style = GetCombatStyle(akActor)
        If style != "balanced"
            ApplyCombatStyleValues(akActor, style)
            DebugMsg("Reapplied combat style '" + style + "' on re-recruit for " + akActor.GetDisplayName())
        EndIf
    EndIf

    If isFirstRecruit
        If ShowNotifications
            Debug.Notification(akActor.GetDisplayName() + " has joined you as a companion.")
        EndIf

        SkyrimNetApi.RegisterEvent("follower_recruited", \
            akActor.GetDisplayName() + " has been recruited as a companion by " + Game.GetPlayer().GetDisplayName() + ".", \
            akActor, Game.GetPlayer())

        DebugMsg("Registered follower (NEW): " + akActor.GetDisplayName())
    Else
        If ShowNotifications
            Debug.Notification(akActor.GetDisplayName() + " has returned.")
        EndIf

        DebugMsg("Registered follower (RETURNING): " + akActor.GetDisplayName())
    EndIf

    ; Update the roster string for prompt template access
    SyncFollowerRoster()
EndFunction

Function UnregisterFollower(Actor akActor, Bool sendHome = true)
    {Remove an actor from the follower roster.
     Routes through NFF when available, otherwise uses vanilla mechanics.}
    If !akActor
        Return
    EndIf

    ; --- Keep outfit alias slot active so outfit lock persists after dismiss ---
    ; ClearOutfitSlot is NOT called here. The alias stays linked so OnCellLoad
    ; can re-apply the locked outfit when the NPC loads at their home location.
    ; The slot is only freed when the outfit lock is explicitly cleared (Dress action).

    ; --- Our own tracking cleanup (always, regardless of framework) ---
    StorageUtil.SetIntValue(akActor, KEY_IS_FOLLOWER, 0)
    SeverActionsNative.Native_ClearFollowerData(akActor)

    ; Remove from our faction
    If SeverActions_FollowerFaction
        akActor.RemoveFromFaction(SeverActions_FollowerFaction)
    EndIf

    ; --- Remove proper follower status ---
    ; Determine routing (mirrors RegisterFollower logic)
    Bool useFramework = ShouldUseFramework(akActor)

    nwsFollowerControllerScript nffController = None
    EFFCore effController = None

    If useFramework
        nffController = GetNFFController()
        If !nffController
            effController = GetEFFController()
        EndIf
    EndIf

    Bool wasAlreadyTeammate = StorageUtil.GetIntValue(akActor, KEY_WAS_ALREADY_TEAMMATE, 0) == 1

    Bool frameworkHandledAI = false

    If nffController
        ; NFF path: let NFF handle SetPlayerTeammate, factions, alias cleanup, and AI.
        ; Do NOT touch packages or send home — NFF owns the NPC's AI after RemoveFollower.
        DebugMsg("NFF dismiss: " + akActor.GetDisplayName())
        nffController.RemoveFollower(akActor, -1, 0)
        StorageUtil.UnsetIntValue(akActor, KEY_WAS_ALREADY_TEAMMATE)
        frameworkHandledAI = true
    ElseIf effController
        ; EFF path: let EFF handle SetPlayerTeammate, factions, alias cleanup, and AI.
        ; Do NOT touch packages or send home — EFF owns the NPC's AI after RemoveFollower.
        DebugMsg("EFF dismiss: " + akActor.GetDisplayName())
        effController.XFL_RemoveFollower(akActor as Form, 0, 0)
        StorageUtil.UnsetIntValue(akActor, KEY_WAS_ALREADY_TEAMMATE)
        frameworkHandledAI = true
    ElseIf wasAlreadyTeammate && IsTrackOnlyFollower(akActor)
        ; Track-only cleanup: NFF-ignore-token holder, DLC-managed (Serana), or Tracking Only mode
        ; Still need to remove teammate/faction status so their follow packages deactivate.
        ; Most mod follow packages condition on IsPlayerTeammate or GetInFaction checks.
        DebugMsg("Track-only dismiss: " + akActor.GetDisplayName())
        akActor.SetPlayerTeammate(false)
        Faction currentFollowerFaction = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
        If currentFollowerFaction
            akActor.RemoveFromFaction(currentFollowerFaction)
        EndIf
        Faction playerFollowerFaction = Game.GetFormFromFile(0x084D1B, "Skyrim.esm") as Faction
        If playerFollowerFaction
            akActor.RemoveFromFaction(playerFollowerFaction)
        EndIf
        StorageUtil.UnsetIntValue(akActor, KEY_WAS_ALREADY_TEAMMATE)
        frameworkHandledAI = true
    Else
        ; Vanilla/SeverActions path: clean up follower mechanics ourselves
        DebugMsg("SeverActions dismiss: " + akActor.GetDisplayName())

        akActor.SetPlayerTeammate(false)
        akActor.IgnoreFriendlyHits(false)

        ; Remove from BOTH follower factions so all follow packages deactivate.
        ; CurrentFollowerFaction (0x0005C84E) — controls dialogue options
        ; PlayerFollowerFaction (0x084D1B) — used by AI packages as conditions
        Faction currentFollowerFaction = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
        If currentFollowerFaction
            akActor.RemoveFromFaction(currentFollowerFaction)
        EndIf
        Faction playerFollowerFaction = Game.GetFormFromFile(0x084D1B, "Skyrim.esm") as Faction
        If playerFollowerFaction
            akActor.RemoveFromFaction(playerFollowerFaction)
        EndIf

        ; Restore original relationship rank (default to 0 = Acquaintance if not saved)
        Int origRelRank = StorageUtil.GetIntValue(akActor, KEY_ORIG_RELRANK, 0)
        akActor.SetRelationshipRank(Game.GetPlayer(), origRelRank)

        ; Restore original AI values
        Float origAggression = StorageUtil.GetFloatValue(akActor, KEY_ORIG_AGGRESSION, -1.0)
        Float origConfidence = StorageUtil.GetFloatValue(akActor, KEY_ORIG_CONFIDENCE, -1.0)
        If origAggression >= 0.0
            akActor.SetAV("Aggression", origAggression)
        EndIf
        If origConfidence >= 0.0
            akActor.SetAV("Confidence", origConfidence)
        EndIf
    EndIf

    ; Clear waiting state if set
    akActor.SetAV("WaitingForPlayer", 0)

    ; NOTE: We intentionally do NOT clear the outfit lock on dismiss.
    ; If the player told them to wear something, they should keep it
    ; even after being sent home.

    If !frameworkHandledAI
        DebugMsg("Dismiss: vanilla path for " + akActor.GetDisplayName())
        ; Stop companion following via our alias system
        ; CompanionStopFollowing clears alias slot, LinkedRef, sandbox overrides,
        ; and calls EvaluatePackage — NPC returns to default AI.
        SeverActions_Follow followSys = GetFollowScript()
        If followSys
            followSys.CompanionStopFollowing(akActor)
        EndIf

        ; Send home if they have a home assigned
        If sendHome
            DebugMsg("Calling SendHome for " + akActor.GetDisplayName())
            SendHome(akActor)
        EndIf
    Else
        DebugMsg("Dismiss: framework path for " + akActor.GetDisplayName())
        ; Framework owns AI — only clean up our own sandbox/follow overrides
        ; so they don't interfere with the framework's packages.
        SeverActions_Follow followSys = GetFollowScript()
        If followSys
            followSys.CompanionStopFollowing(akActor)
        EndIf
        ; Framework handles AI, but still apply our home sandbox if they have a home marker.
        ; The sandbox at priority 40 won't interfere with framework packages (higher priority).
        ; It acts as a safety net: if the framework doesn't send them somewhere, they go home.
        If sendHome
            DebugMsg("Calling ApplyHomeSandboxIfHomed for " + akActor.GetDisplayName())
            ApplyHomeSandboxIfHomed(akActor)
        EndIf
    EndIf

    If ShowNotifications
        Debug.Notification(akActor.GetDisplayName() + " is no longer your companion.")
    EndIf

    SkyrimNetApi.RegisterEvent("follower_dismissed", \
        akActor.GetDisplayName() + " is no longer traveling with " + Game.GetPlayer().GetDisplayName() + ".", \
        akActor, Game.GetPlayer())

    DebugMsg("Unregistered follower: " + akActor.GetDisplayName())

    ; Update the roster string for prompt template access
    SyncFollowerRoster()
EndFunction

Bool Function IsRegisteredFollower(Actor akActor)
    If !akActor
        Return false
    EndIf
    Return StorageUtil.GetIntValue(akActor, KEY_IS_FOLLOWER, 0) == 1
EndFunction

Int Function GetFollowerCount()
    Actor[] followers = GetAllFollowers()
    Return followers.Length
EndFunction

Bool Function CanRecruitMore()
    Return GetFollowerCount() < MaxFollowers
EndFunction

Actor[] Function GetAllFollowers()
    {Get all currently registered followers.
     Scans three sources:
     1. Native cosave (FollowerDataStore) — cell-independent, survives save/load
     2. Current cell — finds followers physically nearby (catches new detections)
     3. Follower alias slots — finds followers in other cells (aliases persist across save/load)
     All sources are deduplicated. Source 1 is the primary source since it works
     regardless of cell, which fixes NFF/EFF followers disappearing after reload.}
    Actor player = Game.GetPlayer()
    Actor[] result = PapyrusUtil.ActorArray(0)

    ; Source 1: Native cosave — all tracked followers regardless of cell
    Actor[] nativeFollowers = SeverActionsNative.Native_GetAllTrackedFollowers()
    If nativeFollowers
        Int i = 0
        While i < nativeFollowers.Length
            If nativeFollowers[i] && nativeFollowers[i] != player
                result = PapyrusUtil.PushActor(result, nativeFollowers[i])
            EndIf
            i += 1
        EndWhile
    EndIf

    ; Source 2: Scan current cell for registered followers (catches newly detected ones
    ; not yet in the cosave, e.g. first session after recruiting via vanilla dialogue)
    Cell playerCell = player.GetParentCell()
    If playerCell
        Int numRefs = playerCell.GetNumRefs(43) ; 43 = kNPC
        Int i = 0
        While i < numRefs
            ObjectReference ref = playerCell.GetNthRef(i, 43)
            Actor actorRef = ref as Actor
            If actorRef && actorRef != player && IsRegisteredFollower(actorRef)
                If !ActorInArray(result, actorRef)
                    result = PapyrusUtil.PushActor(result, actorRef)
                EndIf
            EndIf
            i += 1
        EndWhile
    EndIf

    ; Source 3: Check follower alias slots (catches followers in other cells
    ; that may not be in the cosave yet)
    SeverActions_Follow followSys = GetFollowScript()
    If followSys && followSys.FollowerSlots
        Int i = 0
        While i < followSys.FollowerSlots.Length
            If followSys.FollowerSlots[i]
                Actor slotActor = followSys.FollowerSlots[i].GetActorRef()
                If slotActor && slotActor != player && !slotActor.IsDead() && IsRegisteredFollower(slotActor)
                    If !ActorInArray(result, slotActor)
                        result = PapyrusUtil.PushActor(result, slotActor)
                    EndIf
                EndIf
            EndIf
            i += 1
        EndWhile
    EndIf

    Return result
EndFunction

Bool Function ActorInArray(Actor[] arr, Actor target)
    Int i = 0
    While i < arr.Length
        If arr[i] == target
            Return true
        EndIf
        i += 1
    EndWhile
    Return false
EndFunction

; =============================================================================
; RELATIONSHIP SYSTEM
; =============================================================================

Function ModifyRapport(Actor akActor, Float amount)
    Float current = StorageUtil.GetFloatValue(akActor, KEY_RAPPORT, DEFAULT_RAPPORT)
    Float newVal = ClampFloat(current + amount, RAPPORT_MIN, RAPPORT_MAX)
    StorageUtil.SetFloatValue(akActor, KEY_RAPPORT, newVal)
    SyncRelationshipToNative(akActor)
    DebugMsg(akActor.GetDisplayName() + " rapport: " + current + " -> " + newVal + " (" + amount + ")")
EndFunction

Function ModifyTrust(Actor akActor, Float amount)
    Float current = StorageUtil.GetFloatValue(akActor, KEY_TRUST, DEFAULT_TRUST)
    Float newVal = ClampFloat(current + amount, TRUST_MIN, TRUST_MAX)
    StorageUtil.SetFloatValue(akActor, KEY_TRUST, newVal)
    SyncRelationshipToNative(akActor)
EndFunction

Function ModifyLoyalty(Actor akActor, Float amount)
    Float current = StorageUtil.GetFloatValue(akActor, KEY_LOYALTY, DEFAULT_LOYALTY)
    Float newVal = ClampFloat(current + amount, LOYALTY_MIN, LOYALTY_MAX)
    StorageUtil.SetFloatValue(akActor, KEY_LOYALTY, newVal)
    SyncRelationshipToNative(akActor)
EndFunction

Function ModifyMood(Actor akActor, Float amount)
    Float current = StorageUtil.GetFloatValue(akActor, KEY_MOOD, DEFAULT_MOOD)
    Float newVal = ClampFloat(current + amount, MOOD_MIN, MOOD_MAX)
    StorageUtil.SetFloatValue(akActor, KEY_MOOD, newVal)
    SyncRelationshipToNative(akActor)
EndFunction

Function SetRapport(Actor akActor, Float value)
    StorageUtil.SetFloatValue(akActor, KEY_RAPPORT, ClampFloat(value, RAPPORT_MIN, RAPPORT_MAX))
    SyncRelationshipToNative(akActor)
EndFunction

Function SetTrust(Actor akActor, Float value)
    StorageUtil.SetFloatValue(akActor, KEY_TRUST, ClampFloat(value, TRUST_MIN, TRUST_MAX))
    SyncRelationshipToNative(akActor)
EndFunction

Function SetLoyalty(Actor akActor, Float value)
    StorageUtil.SetFloatValue(akActor, KEY_LOYALTY, ClampFloat(value, LOYALTY_MIN, LOYALTY_MAX))
    SyncRelationshipToNative(akActor)
EndFunction

Function SetMood(Actor akActor, Float value)
    StorageUtil.SetFloatValue(akActor, KEY_MOOD, ClampFloat(value, MOOD_MIN, MOOD_MAX))
    SyncRelationshipToNative(akActor)
EndFunction

Function SyncRelationshipToNative(Actor akActor)
    {Sync all 4 relationship values from StorageUtil to FollowerDataStore.
     Call after modifying relationship values.}
    SeverActionsNative.Native_SetRelationship(akActor, \
        StorageUtil.GetFloatValue(akActor, KEY_RAPPORT, DEFAULT_RAPPORT), \
        StorageUtil.GetFloatValue(akActor, KEY_TRUST, DEFAULT_TRUST), \
        StorageUtil.GetFloatValue(akActor, KEY_LOYALTY, DEFAULT_LOYALTY), \
        StorageUtil.GetFloatValue(akActor, KEY_MOOD, DEFAULT_MOOD))
EndFunction

Function SyncAllRelationshipsOnLoad()
    {On game load, push all registered followers' StorageUtil relationship
     values into the native FollowerDataStore so PrismaUI shows correct data.
     Must run AFTER DetectExistingFollowers so all followers are registered.}
    Actor[] followers = GetAllFollowers()
    Int i = 0
    While i < followers.Length
        If followers[i]
            SyncRelationshipToNative(followers[i])
        EndIf
        i += 1
    EndWhile
    If DebugMode && followers.Length > 0
        Debug.Trace("[SeverActions_FollowerManager] Synced " + followers.Length + " followers' relationships to native store")
    EndIf
EndFunction

Float Function GetRapport(Actor akActor)
    Return StorageUtil.GetFloatValue(akActor, KEY_RAPPORT, DEFAULT_RAPPORT)
EndFunction

Float Function GetTrust(Actor akActor)
    Return StorageUtil.GetFloatValue(akActor, KEY_TRUST, DEFAULT_TRUST)
EndFunction

Float Function GetLoyalty(Actor akActor)
    Return StorageUtil.GetFloatValue(akActor, KEY_LOYALTY, DEFAULT_LOYALTY)
EndFunction

Float Function GetMood(Actor akActor)
    Return StorageUtil.GetFloatValue(akActor, KEY_MOOD, DEFAULT_MOOD)
EndFunction

; Called when the follower has a conversation with the player
Function OnFollowerInteraction(Actor akActor)
    StorageUtil.SetFloatValue(akActor, KEY_LAST_INTERACTION, GetGameTimeInSeconds())
EndFunction

; =============================================================================
; AUTOMATIC RELATIONSHIP ASSESSMENT (LLM-based)
; =============================================================================

Function CheckRelationshipAssessments()
    {Check if any follower is due for an automatic relationship assessment.
     Fires at most ONE assessment per tick to avoid flooding the LLM queue.
     Each follower is assessed on a game-time cooldown (AssessmentCooldownHours).
     Only followers in the same cell as the player are assessed.
     Picks the most overdue follower if multiple are past their cooldown.}
    If AssessmentInProgress
        Return
    EndIf

    Actor player = Game.GetPlayer()
    Cell playerCell = player.GetParentCell()
    If !playerCell
        Return
    EndIf

    Actor[] followers = GetAllFollowers()
    Float now = GetGameTimeInSeconds()
    Float baseCooldownSeconds = AssessmentCooldownHours * SECONDS_PER_GAME_HOUR

    ; Track the best candidate: the follower most overdue for assessment
    Actor bestCandidate = None
    Float bestOverdue = 0.0  ; How far past their cooldown (higher = more overdue)

    Int i = 0
    While i < followers.Length
        Actor follower = followers[i]
        If follower && !follower.IsDead() && follower.GetParentCell() == playerCell
            Float lastAssess = StorageUtil.GetFloatValue(follower, KEY_LAST_ASSESS_GT, 0.0)
            Float elapsed = now - lastAssess

            If elapsed >= baseCooldownSeconds
                ; This follower is past their cooldown — score by how overdue they are
                Float overdue = elapsed - baseCooldownSeconds
                If !bestCandidate || overdue > bestOverdue
                    bestCandidate = follower
                    bestOverdue = overdue
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile

    ; Fire assessment for the most overdue follower (if any)
    If bestCandidate
        FireRelationshipAssessment(bestCandidate)
    EndIf
EndFunction

Function FireRelationshipAssessment(Actor akActor)
    {Send the relationship assessment prompt to the LLM for a specific follower.
     Passes the follower's FormID in contextJson so the prompt template can
     resolve it to a UUID via formid_to_uuid() and access all NPC data.

     When PublicAPI is available, enriches the context with:
     - socialGraph: who this NPC interacts with besides the player
     - relevantMemories: semantic search for relationship-relevant memories}
    AssessmentInProgress = true
    PendingAssessmentFormId = akActor.GetFormID()
    StorageUtil.SetFloatValue(akActor, KEY_LAST_ASSESS_GT, GetGameTimeInSeconds())

    ; Build context JSON — start with the base
    String contextJson = "{\"npcFormId\":" + PendingAssessmentFormId

    ; Enrich with PublicAPI data if available
    If SeverActionsNative.IsPublicAPIReady()
        ; Social graph: who does this NPC interact with?
        String social = SeverActionsNative.GetFollowerSocialGraph(akActor)
        If social != "[]"
            contextJson += ",\"socialGraph\":" + social
        EndIf

        ; Semantic memory search: find memories relevant to the player relationship
        String relMemories = SeverActionsNative.SearchActorMemories(akActor, \
            "relationship with player trust loyalty feelings")
        If relMemories != "[]"
            contextJson += ",\"relevantMemories\":" + relMemories
        EndIf
    EndIf

    contextJson += "}"

    Int result = SkyrimNetApi.SendCustomPromptToLLM("sever_relationship_assess", "", contextJson, \
        Self as Quest, "SeverActions_FollowerManager", "OnRelationshipAssessment")

    If result < 0
        AssessmentInProgress = false
        DebugMsg("Relationship assessment LLM call failed for " + akActor.GetDisplayName() + ", code " + result)
    Else
        DebugMsg("Relationship assessment queued for " + akActor.GetDisplayName() + " (enriched=" + SeverActionsNative.IsPublicAPIReady() + ")")
    EndIf
EndFunction

Function OnRelationshipAssessment(String response, Int success)
    {Callback from SendCustomPromptToLLM. Parses the JSON response and applies
     relationship changes to the pending follower.
     Expected response: JSON with rapport, trust, loyalty, mood integer values.}
    AssessmentInProgress = false

    If success != 1
        DebugMsg("Relationship assessment LLM failed: " + response)
        Return
    EndIf

    ; Resolve the follower from the stored FormID
    Actor akActor = Game.GetForm(PendingAssessmentFormId) as Actor
    If !akActor || !IsRegisteredFollower(akActor)
        DebugMsg("Relationship assessment: actor not found or no longer a follower (FormID " + PendingAssessmentFormId + ")")
        Return
    EndIf

    ; Parse the JSON response
    Int rapportChange = ExtractJsonInt(response, "rapport")
    Int trustChange = ExtractJsonInt(response, "trust")
    Int loyaltyChange = ExtractJsonInt(response, "loyalty")
    Int moodChange = ExtractJsonInt(response, "mood")
    Int lastEventId = ExtractJsonInt(response, "eid")
    Int lastMemoryId = ExtractJsonInt(response, "mid")
    Int lastDiaryId = ExtractJsonInt(response, "did")

    ; Store the highest assessed event/memory/diary IDs so the next assessment only sees new ones
    If lastEventId > 0
        StorageUtil.SetIntValue(akActor, "SeverFollower_LastAssessEventId", lastEventId)
    EndIf
    If lastMemoryId > 0
        StorageUtil.SetIntValue(akActor, "SeverFollower_LastAssessMemoryId", lastMemoryId)
    EndIf
    If lastDiaryId > 0
        StorageUtil.SetIntValue(akActor, "SeverFollower_LastAssessDiaryId", lastDiaryId)
    EndIf

    ; Skip if all zeros (no meaningful change)
    If rapportChange == 0 && trustChange == 0 && loyaltyChange == 0 && moodChange == 0
        DebugMsg(akActor.GetDisplayName() + " assessment: no change (eid " + lastEventId + ", mid " + lastMemoryId + ", did " + lastDiaryId + ")")
        Return
    EndIf

    ; Apply adjustments (Modify* functions handle clamping to valid ranges)
    If rapportChange != 0
        ModifyRapport(akActor, rapportChange as Float)
    EndIf
    If trustChange != 0
        ModifyTrust(akActor, trustChange as Float)
    EndIf
    If loyaltyChange != 0
        ModifyLoyalty(akActor, loyaltyChange as Float)
    EndIf
    If moodChange != 0
        ModifyMood(akActor, moodChange as Float)
    EndIf

    ; Sync all relationship values to native FollowerDataStore for PrismaUI C++ fast path
    SyncRelationshipToNative(akActor)

    ; Refresh the last interaction timestamp so neglect decay resets
    StorageUtil.SetFloatValue(akActor, KEY_LAST_INTERACTION, GetGameTimeInSeconds())

    ; Build summary for the event system
    String summary = akActor.GetDisplayName() + " relationship assessed:"
    If rapportChange != 0
        summary += " rapport " + rapportChange
    EndIf
    If trustChange != 0
        summary += " trust " + trustChange
    EndIf
    If loyaltyChange != 0
        summary += " loyalty " + loyaltyChange
    EndIf
    If moodChange != 0
        summary += " mood " + moodChange
    EndIf

    SkyrimNetApi.RegisterEvent("relationship_assessed", summary, akActor, Game.GetPlayer())
    DebugMsg(summary)
EndFunction

Int Function ExtractJsonInt(String json, String jsonKey)
    {Extract an integer value from a flat JSON object.
     Handles compact and spaced colon formats.
     Returns 0 if the key is not found or parsing fails.}

    ; Look for "jsonKey": in the JSON string
    String marker = "\"" + jsonKey + "\":"
    Int keyPos = StringUtil.Find(json, marker)
    If keyPos < 0
        ; Try with space after colon: "jsonKey": value
        marker = "\"" + jsonKey + "\": "
        keyPos = StringUtil.Find(json, marker)
        If keyPos < 0
            Return 0
        EndIf
    EndIf

    Int valStart = keyPos + StringUtil.GetLength(marker)
    Int jsonLen = StringUtil.GetLength(json)

    If valStart >= jsonLen
        Return 0
    EndIf

    ; Find the end of this value (next comma or closing brace)
    Int endComma = StringUtil.Find(json, ",", valStart)
    Int endBrace = StringUtil.Find(json, "}", valStart)

    Int valEnd = jsonLen
    If endComma >= 0 && endComma < valEnd
        valEnd = endComma
    EndIf
    If endBrace >= 0 && endBrace < valEnd
        valEnd = endBrace
    EndIf

    If valEnd <= valStart
        Return 0
    EndIf

    String rawVal = StringUtil.Substring(json, valStart, valEnd - valStart)

    ; rawVal should be something like "5" or "-2" (possibly with spaces)
    ; Papyrus string-to-int cast handles simple integer strings
    Return rawVal as Int
EndFunction

; =============================================================================
; INTER-FOLLOWER RELATIONSHIP ASSESSMENT
; =============================================================================

Function CheckInterFollowerAssessments()
    {Check if any follower is due for an inter-follower relationship assessment.
     Fires at most ONE assessment per tick. No same-cell requirement — followers
     form opinions based on shared events and memories regardless of proximity.
     Requires at least 2 followers to have pairs to assess.}
    If InterFollowerAssessmentInProgress
        Return
    EndIf

    Actor[] followers = GetAllFollowers()
    If followers.Length < 2
        Return
    EndIf

    Float now = GetGameTimeInSeconds()
    Float baseCooldownSeconds = InterFollowerCooldownHours * SECONDS_PER_GAME_HOUR

    ; Track the best candidate: the follower most overdue for inter-assessment
    Actor bestCandidate = None
    Float bestOverdue = 0.0

    Int i = 0
    While i < followers.Length
        Actor follower = followers[i]
        If follower && !follower.IsDead()
            Float lastAssess = StorageUtil.GetFloatValue(follower, KEY_LAST_INTER_ASSESS_GT, 0.0)
            Float elapsed = now - lastAssess

            If elapsed >= baseCooldownSeconds
                Float overdue = elapsed - baseCooldownSeconds
                If !bestCandidate || overdue > bestOverdue
                    bestCandidate = follower
                    bestOverdue = overdue
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile

    If bestCandidate
        FireInterFollowerAssessment(bestCandidate)
    EndIf
EndFunction

Function FireInterFollowerAssessment(Actor akActor)
    {Send the inter-follower relationship assessment prompt to the LLM.
     Builds a context JSON with the assessor's FormID and all other party members'
     FormIDs along with current affinity/respect values.}
    InterFollowerAssessmentInProgress = true
    PendingInterAssessFormId = akActor.GetFormID()
    StorageUtil.SetFloatValue(akActor, KEY_LAST_INTER_ASSESS_GT, GetGameTimeInSeconds())

    ; Build context JSON with party member list
    ; Include npcName for name-based resolution in callback (avoids light-plugin FormID issues)
    String npcName = akActor.GetDisplayName()
    String contextJson = "{\"npcFormId\":" + PendingInterAssessFormId + ",\"npcName\":\"" + npcName + "\""

    ; Add party members array with current pair values
    Actor[] followers = GetAllFollowers()
    String membersJson = ",\"partyMembers\":["
    Bool first = true
    Int i = 0
    While i < followers.Length
        Actor member = followers[i]
        If member && member != akActor && !member.IsDead()
            Int memberFormId = member.GetFormID()
            Float affinity = SeverActionsNative.Native_GetPairAffinity(akActor, member)
            Float respect = SeverActionsNative.Native_GetPairRespect(akActor, member)

            If !first
                membersJson += ","
            EndIf
            membersJson += "{\"formId\":" + memberFormId
            membersJson += ",\"affinity\":" + (affinity as Int)
            membersJson += ",\"respect\":" + (respect as Int) + "}"
            first = false
        EndIf
        i += 1
    EndWhile
    membersJson += "]"

    contextJson += membersJson + "}"

    Int result = SkyrimNetApi.SendCustomPromptToLLM("sever_relationship_interfollower", "", contextJson, \
        Self as Quest, "SeverActions_FollowerManager", "OnInterFollowerAssessment")

    If result < 0
        InterFollowerAssessmentInProgress = false
        DebugMsg("Inter-follower assessment LLM call failed for " + akActor.GetDisplayName() + ", code " + result)
    Else
        DebugMsg("Inter-follower assessment queued for " + akActor.GetDisplayName())
    EndIf
EndFunction

Function OnInterFollowerAssessment(String response, Int success)
    {Callback from SendCustomPromptToLLM for inter-follower assessment.
     Parses the JSON response containing an array of pair changes.}
    InterFollowerAssessmentInProgress = false

    If success != 1
        DebugMsg("Inter-follower assessment LLM failed: " + response)
        Return
    EndIf

    ; Resolve the assessor by name first (avoids light-plugin FormID issues)
    Actor[] followers = GetAllFollowers()
    String assessorName = ExtractJsonString(response, "assessor")
    Actor akActor = None
    If assessorName != ""
        akActor = ResolveFollowerByName(assessorName, followers)
    EndIf

    ; Fallback 1: Try FormID from response
    If !akActor
        Int srcFormId = ExtractJsonInt(response, "src")
        If srcFormId != 0
            akActor = Game.GetForm(srcFormId) as Actor
        EndIf
    EndIf

    ; Fallback 2: Try stored PendingInterAssessFormId
    If !akActor
        akActor = Game.GetForm(PendingInterAssessFormId) as Actor
    EndIf

    If !akActor || !IsRegisteredFollower(akActor)
        DebugMsg("Inter-follower assessment: assessor not found (name=" + assessorName + ", pending=" + PendingInterAssessFormId + ")")
        Return
    EndIf

    ; Store dedup watermarks
    Int lastEventId = ExtractJsonInt(response, "eid")
    Int lastMemoryId = ExtractJsonInt(response, "mid")
    Int lastDiaryId = ExtractJsonInt(response, "did")
    If lastEventId > 0
        StorageUtil.SetIntValue(akActor, "SeverFollower_LastInterAssessEventId", lastEventId)
    EndIf
    If lastMemoryId > 0
        StorageUtil.SetIntValue(akActor, "SeverFollower_LastInterAssessMemoryId", lastMemoryId)
    EndIf
    If lastDiaryId > 0
        StorageUtil.SetIntValue(akActor, "SeverFollower_LastInterAssessDiaryId", lastDiaryId)
    EndIf

    ; Parse pairs array — iterate by finding each {"target": marker
    ; LLM returns target as a name string, so we resolve it against the follower roster
    String searchFrom = response
    String summary = akActor.GetDisplayName() + " inter-follower assessment:"
    Bool anyChange = false

    Int pairStart = StringUtil.Find(searchFrom, "\"target\":")
    While pairStart >= 0
        ; Extract target name (string) and resolve to Actor
        String targetName = ExtractJsonStringAt(searchFrom, "target", pairStart)
        Int affinityDelta = ExtractJsonIntAt(searchFrom, "affinity", pairStart)
        Int respectDelta = ExtractJsonIntAt(searchFrom, "respect", pairStart)

        Actor targetActor = ResolveFollowerByName(targetName, followers)
        If targetActor && targetActor != akActor && (affinityDelta != 0 || respectDelta != 0)
            ; Read current values from native store
            Float curAffinity = SeverActionsNative.Native_GetPairAffinity(akActor, targetActor)
            Float curRespect = SeverActionsNative.Native_GetPairRespect(akActor, targetActor)

            ; Apply deltas and clamp
            Float newAffinity = curAffinity + affinityDelta
            If newAffinity > 100.0
                newAffinity = 100.0
            ElseIf newAffinity < -100.0
                newAffinity = -100.0
            EndIf

            Float newRespect = curRespect + respectDelta
            If newRespect > 100.0
                newRespect = 100.0
            ElseIf newRespect < 0.0
                newRespect = 0.0
            EndIf

            ; Extract blurb for this pair
            String blurb = ExtractJsonStringAt(searchFrom, "blurb", pairStart)

            ; Dual-write: native cosave + StorageUtil
            Int targetFormId = targetActor.GetFormID()
            SeverActionsNative.Native_SetPairRelationship(akActor, targetActor, newAffinity, newRespect, blurb)
            StorageUtil.SetFloatValue(akActor, "SeverFollower_Affinity_" + targetFormId, newAffinity)
            StorageUtil.SetFloatValue(akActor, "SeverFollower_Respect_" + targetFormId, newRespect)
            If blurb != ""
                StorageUtil.SetStringValue(akActor, "SeverFollower_Blurb_" + targetFormId, blurb)
            EndIf

            summary += " " + targetActor.GetDisplayName() + "(aff" + affinityDelta + " res" + respectDelta + ")"
            anyChange = true
        EndIf

        ; Move past this pair to find the next one
        Int nextSearch = pairStart + 10
        If nextSearch < StringUtil.GetLength(searchFrom)
            pairStart = StringUtil.Find(searchFrom, "\"target\":", nextSearch)
        Else
            pairStart = -1
        EndIf
    EndWhile

    If anyChange
        ; Rebuild the pre-formatted opinions string for the bio prompt
        RebuildCompanionOpinionsString(akActor)

        SkyrimNetApi.RegisterEvent("interfollower_assessed", summary, akActor, None)
        DebugMsg(summary)
    Else
        DebugMsg(akActor.GetDisplayName() + " inter-follower assessment: no changes")
    EndIf
EndFunction

Int Function ExtractJsonIntAt(String json, String jsonKey, Int searchStart)
    {Extract an integer value from a JSON string, searching from a specific position.
     Used for parsing array elements where the same key appears multiple times.}
    String marker = "\"" + jsonKey + "\":"
    Int keyPos = StringUtil.Find(json, marker, searchStart)
    If keyPos < 0
        marker = "\"" + jsonKey + "\": "
        keyPos = StringUtil.Find(json, marker, searchStart)
        If keyPos < 0
            Return 0
        EndIf
    EndIf

    Int valStart = keyPos + StringUtil.GetLength(marker)
    Int jsonLen = StringUtil.GetLength(json)
    If valStart >= jsonLen
        Return 0
    EndIf

    Int endComma = StringUtil.Find(json, ",", valStart)
    Int endBrace = StringUtil.Find(json, "}", valStart)

    Int valEnd = jsonLen
    If endComma >= 0 && endComma < valEnd
        valEnd = endComma
    EndIf
    If endBrace >= 0 && endBrace < valEnd
        valEnd = endBrace
    EndIf

    If valEnd <= valStart
        Return 0
    EndIf

    String rawVal = StringUtil.Substring(json, valStart, valEnd - valStart)
    Return rawVal as Int
EndFunction

String Function ExtractJsonString(String json, String jsonKey)
    {Extract a string value from a flat JSON object. Searches from the beginning.}
    Return ExtractJsonStringAt(json, jsonKey, 0)
EndFunction

String Function ExtractJsonStringAt(String json, String jsonKey, Int searchStart)
    {Extract a string value from a JSON string, searching from a specific position.
     Looks for "key":"value" pattern and returns the value between quotes.}
    String marker = "\"" + jsonKey + "\":\""
    Int keyPos = StringUtil.Find(json, marker, searchStart)
    If keyPos < 0
        ; Try with space after colon
        marker = "\"" + jsonKey + "\": \""
        keyPos = StringUtil.Find(json, marker, searchStart)
        If keyPos < 0
            Return ""
        EndIf
    EndIf

    Int valStart = keyPos + StringUtil.GetLength(marker)
    Int jsonLen = StringUtil.GetLength(json)
    If valStart >= jsonLen
        Return ""
    EndIf

    Int endQuote = StringUtil.Find(json, "\"", valStart)
    If endQuote < 0 || endQuote <= valStart
        Return ""
    EndIf

    Return StringUtil.Substring(json, valStart, endQuote - valStart)
EndFunction

Actor Function ResolveFollowerByName(String targetName, Actor[] followers)
    {Resolve a follower Actor from a name string. Case-insensitive comparison.
     Returns None if no match found.}
    If targetName == ""
        Return None
    EndIf

    Int i = 0
    While i < followers.Length
        If followers[i] && followers[i].GetDisplayName() == targetName
            Return followers[i]
        EndIf
        i += 1
    EndWhile

    ; Fallback: try case-insensitive via lowercase comparison
    ; Papyrus doesn't have toLower, so just try the base name
    i = 0
    While i < followers.Length
        If followers[i]
            String dName = followers[i].GetDisplayName()
            If StringUtil.Find(dName, targetName) >= 0 || StringUtil.Find(targetName, dName) >= 0
                Return followers[i]
            EndIf
        EndIf
        i += 1
    EndWhile

    Return None
EndFunction

Function RebuildCompanionOpinionsString(Actor akActor)
    {Rebuild the pre-formatted companion opinions string for prompt template access.
     Stored in StorageUtil as a human-readable summary that the bio prompt reads directly.
     Prefers the LLM-generated blurb (unique per pair) when available, falling back to
     generic band-based descriptions only for pairs that haven't been assessed yet.
     Called after inter-follower assessment results are applied and on game load.}
    If !akActor
        Return
    EndIf

    Actor[] followers = GetAllFollowers()
    String opinions = ""
    Int i = 0
    While i < followers.Length
        Actor target = followers[i]
        If target && target != akActor && !target.IsDead()
            Int targetFormId = target.GetFormID()
            Float aff = StorageUtil.GetFloatValue(akActor, "SeverFollower_Affinity_" + targetFormId, 0.0)
            Float resp = StorageUtil.GetFloatValue(akActor, "SeverFollower_Respect_" + targetFormId, 0.0)

            ; Only include if non-default values exist
            If aff != 0.0 || resp != 0.0
                String targetName = target.GetDisplayName()

                ; Prefer the LLM-generated blurb — it's unique and contextual
                String blurb = StorageUtil.GetStringValue(akActor, "SeverFollower_Blurb_" + targetFormId, "")

                If blurb != ""
                    ; Use the LLM-generated blurb directly — it's already in second person
                    ; and unique to this pair's shared experiences
                    If opinions != ""
                        opinions += "\n"
                    EndIf
                    opinions += "**" + targetName + "**: " + blurb
                Else
                    ; No blurb yet — use varied fallback descriptions based on affinity + respect bands
                    String affDesc = ""
                    If aff >= 60.0
                        affDesc = "You consider " + targetName + " a true friend — someone you'd fight beside without hesitation and trust to watch your back."
                    ElseIf aff >= 30.0
                        affDesc = "You genuinely enjoy " + targetName + "'s company. Traveling together feels natural, and you find yourself looking forward to conversations with them."
                    ElseIf aff >= 10.0
                        affDesc = "You're warming up to " + targetName + ". You don't know them well yet, but what you've seen so far is promising."
                    ElseIf aff >= -10.0
                        affDesc = "You don't have strong feelings about " + targetName + " one way or another. They're just another member of the group for now."
                    ElseIf aff >= -30.0
                        affDesc = "Something about " + targetName + " rubs you the wrong way. Small things they do get under your skin more than they probably should."
                    ElseIf aff >= -60.0
                        affDesc = "You genuinely dislike " + targetName + ". Being around them puts you in a worse mood, and you'd rather keep your distance."
                    Else
                        affDesc = "You can barely tolerate " + targetName + "'s presence. Every interaction with them is an exercise in restraint."
                    EndIf

                    String respDesc = ""
                    If resp >= 80.0
                        respDesc = " You hold their abilities in the highest regard — they're one of the most capable people you've met."
                    ElseIf resp >= 60.0
                        respDesc = " You respect what they bring to the group. They've proven themselves when it counted."
                    ElseIf resp >= 40.0
                        respDesc = " They seem competent enough, though you haven't seen them truly tested yet."
                    ElseIf resp >= 20.0
                        respDesc = " You're not entirely convinced they can handle themselves when things get serious."
                    Else
                        respDesc = " Frankly, you question whether they're cut out for this life."
                    EndIf

                    If opinions != ""
                        opinions += "\n"
                    EndIf
                    opinions += "**" + targetName + "**: " + affDesc + respDesc
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile

    StorageUtil.SetStringValue(akActor, "SeverFollower_CompanionOpinions", opinions)
EndFunction

Function RebuildAllCompanionOpinions()
    {Rebuild the companion opinions string for every active follower on game load.
     StorageUtil strings don't persist reliably across save/load, but the individual
     Affinity/Respect float values do. This ensures the prompt template always has
     current data without waiting for the next inter-follower assessment cycle.}
    Actor[] followers = GetAllFollowers()
    Int i = 0
    While i < followers.Length
        If followers[i]
            RebuildCompanionOpinionsString(followers[i])
        EndIf
        i += 1
    EndWhile
    DebugMsg("Rebuilt companion opinions strings for " + followers.Length + " followers")
EndFunction

Function SyncFollowerRoster()
    {Update the comma-separated roster string in StorageUtil for prompt template access.
     Called on recruit, dismiss, and game load.}
    Actor[] followers = GetAllFollowers()
    String roster = ""
    Int i = 0
    While i < followers.Length
        If followers[i]
            If roster != ""
                roster += ","
            EndIf
            roster += followers[i].GetFormID()
        EndIf
        i += 1
    EndWhile
    StorageUtil.SetStringValue(None, "SeverActions_FollowerRoster", roster)
    DebugMsg("Updated follower roster string: " + roster)
EndFunction

Function SyncAllPairRelationshipsOnLoad()
    {Called from Maintenance on game load. Syncs inter-follower pair data from
     StorageUtil to native FollowerDataStore for PrismaUI display.}
    Actor[] followers = GetAllFollowers()
    Int i = 0
    While i < followers.Length
        Actor source = followers[i]
        If source
            Int j = 0
            While j < followers.Length
                Actor target = followers[j]
                If target && target != source
                    Int targetFormId = target.GetFormID()
                    Float affinity = StorageUtil.GetFloatValue(source, "SeverFollower_Affinity_" + targetFormId, 0.0)
                    Float respect = StorageUtil.GetFloatValue(source, "SeverFollower_Respect_" + targetFormId, 50.0)
                    ; Only sync if non-default values exist
                    If affinity != 0.0 || respect != 50.0
                        SeverActionsNative.Native_SetPairRelationship(source, target, affinity, respect)
                    EndIf
                EndIf
                j += 1
            EndWhile
        EndIf
        i += 1
    EndWhile
    DebugMsg("Synced inter-follower pair relationships to native store")
EndFunction

; =============================================================================
; HOME ASSIGNMENT
; =============================================================================

Function AssignHome(Actor akActor, String locationName)
    {Assign a named location as this NPC's home.
     Uses alias-based marker system (MHiYH pattern): acquires a HomeSlot alias and XMarker
     from the pool, moves the marker to the player's current position.
     Each alias has its own per-slot sandbox package that directly references its XMarker.
     Works for both followers (applied on dismiss) and non-followers (applied immediately).}
    If !akActor || locationName == ""
        Return
    EndIf

    ; If reassigning, clear the old alias first (but keep the slot if possible)
    Int existingSlot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)
    If existingSlot >= 0 && HomeSlots && existingSlot < HomeSlots.Length
        HomeSlots[existingSlot].Clear()
    EndIf

    ; Store the home location name — dual-write: native cosave (reliable) + StorageUtil (legacy)
    SeverActionsNative.Native_SetHome(akActor, locationName)
    StorageUtil.SetStringValue(akActor, KEY_HOME_LOCATION, locationName)

    ; Acquire a home marker slot (or reuse existing) and move the XMarker
    ; Move to the PLAYER's position — the player is standing where they want the NPC to sandbox.
    ; ResolveDestination returns door refs, which place the marker outside the cell.
    Actor PlayerRef = Game.GetPlayer()
    If HomeMarkerList && PlayerRef
        Int slot = existingSlot
        If slot < 0
            slot = SeverActionsNative.Native_AcquireHomeMarkerSlot(akActor)
        EndIf
        If slot >= 0
            ObjectReference homeMarker = HomeMarkerList.GetAt(slot) as ObjectReference
            If homeMarker
                ; Markers are always enabled (MHiYH pattern) — just move to player position
                homeMarker.MoveTo(PlayerRef)
                DebugMsg("Home marker slot " + slot + " moved to player position at " + locationName + " for " + akActor.GetDisplayName())
            EndIf
        Else
            DebugMsg("WARNING: All 40 home marker slots in use — " + akActor.GetDisplayName() + " will use travel fallback")
        EndIf
    EndIf

    ; Track in global homed NPCs list for MCM visibility
    If !StorageUtil.FormListHas(None, KEY_HOMED_NPCS, akActor as Form)
        StorageUtil.FormListAdd(None, KEY_HOMED_NPCS, akActor as Form, false)
    EndIf

    If ShowNotifications
        Debug.Notification(akActor.GetDisplayName() + " will now call " + locationName + " home.")
    EndIf

    SkyrimNetApi.RegisterPersistentEvent( \
        akActor.GetDisplayName() + " now considers " + locationName + " their home.", \
        akActor, Game.GetPlayer())

    ; For non-followers, immediately send them home so the sandbox package activates.
    ; For active followers, the sandbox gets applied on dismiss via SendHome().
    If !IsRegisteredFollower(akActor)
        SendHome(akActor)
    EndIf

    DebugMsg("Home assigned for " + akActor.GetDisplayName() + ": " + locationName)
EndFunction

Function SendHome(Actor akActor)
    {Send an NPC to their assigned home using the marker-based sandbox system.
     Applies the sandbox package pointing at the home marker — the NPC pathfinds
     there if in the same cell, or the engine teleports them on cell unload.
     No explicit MoveTo needed — this mirrors how vanilla Skyrim handles dismissal.
     Falls back to the Travel system if no marker slot is available.
     If no home is assigned at all, does nothing — NPC returns to default AI.}
    If !akActor
        Return
    EndIf

    String homeLoc = GetAssignedHome(akActor)
    If homeLoc == ""
        DebugMsg("SendHome: no home assigned for " + akActor.GetDisplayName())
        Return
    EndIf

    DebugMsg("SendHome: " + akActor.GetDisplayName() + " home=" + homeLoc)

    ; Try marker-based home system first
    Int slot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)

    ; Migration: has a home string but no marker slot yet — acquire one now
    ; NOTE: Migration places marker at door ref (best we can do without stored position).
    ; User can re-assign home while standing inside to fix placement.
    If slot < 0 && HomeMarkerList
        ObjectReference destRef = SeverActionsNative.ResolveDestination(akActor, homeLoc)
        If destRef
            slot = SeverActionsNative.Native_AcquireHomeMarkerSlot(akActor)
            If slot >= 0
                ObjectReference marker = HomeMarkerList.GetAt(slot) as ObjectReference
                If marker
                    marker.MoveTo(destRef)
                    DebugMsg("SendHome migrated " + akActor.GetDisplayName() + " to marker slot " + slot + " (door position — re-assign to fix)")
                EndIf
            EndIf
        EndIf
    EndIf

    DebugMsg("SendHome: marker slot=" + slot)

    If slot >= 0 && HomeMarkerList
        ObjectReference homeMarker = HomeMarkerList.GetAt(slot) as ObjectReference
        If homeMarker
            ; Force into alias — NPC gets per-slot sandbox package automatically.
            ; Each alias has its own package pointing directly at its XMarker.
            ; NPC pathfinds to marker if nearby, or engine snaps them on cell unload.
            ApplyHomeSandbox(akActor, homeMarker, slot)
            akActor.EvaluatePackage()
            DebugMsg("SendHome: forced into alias slot " + slot + " SUCCESS")
            Return
        Else
            DebugMsg("SendHome: marker at slot " + slot + " is None!")
        EndIf
    Else
        DebugMsg("SendHome: slot=" + slot + " HomeMarkerList=" + HomeMarkerList)
    EndIf

    ; Fallback: only if marker system completely unavailable (no FormList/Keyword configured)
    DebugMsg("SendHome: FALLBACK — no marker system")
EndFunction

Package Function GetHomeSandboxPackage(Int slot)
    {Return the per-slot sandbox package for the given slot index.}
    If slot == 0
        Return HomeSandboxPackage_00
    ElseIf slot == 1
        Return HomeSandboxPackage_01
    ElseIf slot == 2
        Return HomeSandboxPackage_02
    ElseIf slot == 3
        Return HomeSandboxPackage_03
    ElseIf slot == 4
        Return HomeSandboxPackage_04
    ElseIf slot == 5
        Return HomeSandboxPackage_05
    ElseIf slot == 6
        Return HomeSandboxPackage_06
    ElseIf slot == 7
        Return HomeSandboxPackage_07
    ElseIf slot == 8
        Return HomeSandboxPackage_08
    ElseIf slot == 9
        Return HomeSandboxPackage_09
    ElseIf slot == 10
        Return HomeSandboxPackage_10
    ElseIf slot == 11
        Return HomeSandboxPackage_11
    ElseIf slot == 12
        Return HomeSandboxPackage_12
    ElseIf slot == 13
        Return HomeSandboxPackage_13
    ElseIf slot == 14
        Return HomeSandboxPackage_14
    ElseIf slot == 15
        Return HomeSandboxPackage_15
    ElseIf slot == 16
        Return HomeSandboxPackage_16
    ElseIf slot == 17
        Return HomeSandboxPackage_17
    ElseIf slot == 18
        Return HomeSandboxPackage_18
    ElseIf slot == 19
        Return HomeSandboxPackage_19
    ElseIf slot == 20
        Return HomeSandboxPackage_20
    ElseIf slot == 21
        Return HomeSandboxPackage_21
    ElseIf slot == 22
        Return HomeSandboxPackage_22
    ElseIf slot == 23
        Return HomeSandboxPackage_23
    ElseIf slot == 24
        Return HomeSandboxPackage_24
    ElseIf slot == 25
        Return HomeSandboxPackage_25
    ElseIf slot == 26
        Return HomeSandboxPackage_26
    ElseIf slot == 27
        Return HomeSandboxPackage_27
    ElseIf slot == 28
        Return HomeSandboxPackage_28
    ElseIf slot == 29
        Return HomeSandboxPackage_29
    ElseIf slot == 30
        Return HomeSandboxPackage_30
    ElseIf slot == 31
        Return HomeSandboxPackage_31
    ElseIf slot == 32
        Return HomeSandboxPackage_32
    ElseIf slot == 33
        Return HomeSandboxPackage_33
    ElseIf slot == 34
        Return HomeSandboxPackage_34
    ElseIf slot == 35
        Return HomeSandboxPackage_35
    ElseIf slot == 36
        Return HomeSandboxPackage_36
    ElseIf slot == 37
        Return HomeSandboxPackage_37
    ElseIf slot == 38
        Return HomeSandboxPackage_38
    ElseIf slot == 39
        Return HomeSandboxPackage_39
    EndIf
    Return None
EndFunction

Function ApplyHomeSandbox(Actor akActor, ObjectReference homeMarker, Int slot)
    {Force the NPC into their HomeSlot alias. Each alias has its own per-slot
     sandbox package that directly references its XMarker (MHiYH pattern).
     Once ForceRef'd, the NPC gets the package automatically.
     Persists across save/load (no reapply needed).}
    If !akActor || !homeMarker
        Return
    EndIf
    If !HomeSlots || slot < 0 || slot >= HomeSlots.Length
        DebugMsg("Invalid home slot " + slot + " for " + akActor.GetDisplayName())
        Return
    EndIf

    ; Force the NPC into the alias — this applies the per-slot sandbox package.
    ; No LinkedRef needed — each package directly references its XMarker.
    HomeSlots[slot].ForceRefTo(akActor)

    akActor.EvaluatePackage()
    DebugMsg("ApplyHomeSandbox: " + akActor.GetDisplayName() + " -> HomeSlot_" + slot)
EndFunction

Function ApplyHomeSandboxIfHomed(Actor akActor)
    {Apply home sandbox if this NPC has a valid home marker slot.
     Used by framework dismiss paths.}
    If !akActor || !HomeMarkerList
        Return
    EndIf
    Int slot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)
    If slot >= 0
        ObjectReference homeMarker = HomeMarkerList.GetAt(slot) as ObjectReference
        If homeMarker
            ApplyHomeSandbox(akActor, homeMarker, slot)
            DebugMsg("Applied home sandbox for framework-dismissed " + akActor.GetDisplayName() + " (slot " + slot + ")")
        EndIf
    EndIf
EndFunction

Function RemoveHomeSandbox(Actor akActor)
    {Clear the NPC from their HomeSlot alias.
     Called on re-recruitment so follow packages take over cleanly.}
    If !akActor
        Return
    EndIf

    ; Find and clear the alias slot — NPC loses the per-slot sandbox package automatically
    Int slot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)
    If slot >= 0 && HomeSlots && slot < HomeSlots.Length
        HomeSlots[slot].Clear()
        DebugMsg("Cleared " + akActor.GetDisplayName() + " from HomeSlot_" + slot)
    EndIf

    akActor.EvaluatePackage()
EndFunction

String Function GetAssignedHome(Actor akActor)
    If !akActor
        Return ""
    EndIf
    ; Prefer native cosave (reliable), fallback to StorageUtil (legacy)
    String nativeHome = SeverActionsNative.Native_GetHome(akActor)
    If nativeHome != ""
        Return nativeHome
    EndIf
    Return StorageUtil.GetStringValue(akActor, KEY_HOME_LOCATION, "")
EndFunction

Function ClearHome(Actor akActor)
    {Remove home assignment. Releases the marker slot and moves the XMarker
     back to the holding cell (MHiYH pattern).}
    If !akActor
        Return
    EndIf

    ; Remove sandbox package if active
    RemoveHomeSandbox(akActor)

    ; Release marker slot (marker stays enabled in holding cell — MHiYH pattern)
    Int slot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)
    If slot >= 0 && HomeMarkerList
        SeverActionsNative.Native_ReleaseHomeMarkerSlot(akActor)
        DebugMsg("Home marker slot " + slot + " released for " + akActor.GetDisplayName())
    EndIf

    SeverActionsNative.Native_ClearHome(akActor)
    StorageUtil.UnsetStringValue(akActor, KEY_HOME_LOCATION)
    StorageUtil.UnsetFormValue(akActor, KEY_HOME_MARKER)

    ; Remove from global tracking list
    StorageUtil.FormListRemove(None, KEY_HOMED_NPCS, akActor as Form, true)

    DebugMsg("Home cleared for " + akActor.GetDisplayName())
EndFunction

Actor[] Function GetAllHomedNPCs()
    {Get all NPCs that have a custom home assigned via the global tracking list.
     Filters out invalid/deleted actors and cleans up stale entries.}
    Int count = StorageUtil.FormListCount(None, KEY_HOMED_NPCS)
    Actor[] result = PapyrusUtil.ActorArray(0)

    Int i = 0
    While i < count
        Form entry = StorageUtil.FormListGet(None, KEY_HOMED_NPCS, i)
        Actor actorRef = entry as Actor
        If actorRef && !actorRef.IsDeleted()
            ; Verify they still have a home assigned (defensive)
            String home = GetAssignedHome(actorRef)
            If home != ""
                result = PapyrusUtil.PushActor(result, actorRef)
            Else
                ; Stale entry — home was cleared without list cleanup
                StorageUtil.FormListRemove(None, KEY_HOMED_NPCS, entry, true)
                count -= 1
                i -= 1
            EndIf
        Else
            ; Invalid/deleted actor — remove stale entry
            StorageUtil.FormListRemove(None, KEY_HOMED_NPCS, entry, true)
            count -= 1
            i -= 1
        EndIf
        i += 1
    EndWhile

    Return result
EndFunction

Int Function GetHomedNPCCount()
    Return StorageUtil.FormListCount(None, KEY_HOMED_NPCS)
EndFunction

; =============================================================================
; COMBAT STYLE
; =============================================================================

Function SetCombatStyle(Actor akActor, String style)
    {Set follower's preferred combat approach}
    If !akActor
        Return
    EndIf

    ; Normalize the style string
    String normalized = SeverActionsNative.StringToLower(style)

    If normalized == "aggressive" || normalized == "defensive" || normalized == "ranged" || normalized == "healer" || normalized == "balanced"
        SeverActionsNative.Native_SetCombatStyle(akActor, normalized)
        StorageUtil.SetStringValue(akActor, KEY_COMBAT_STYLE, normalized)

        ; Apply actor value adjustments
        ApplyCombatStyleValues(akActor, normalized)

        If ShowNotifications
            Debug.Notification(akActor.GetDisplayName() + " will now fight " + normalized + "ly.")
        EndIf

        SkyrimNetApi.RegisterPersistentEvent( \
            akActor.GetDisplayName() + " will now approach combat in a " + normalized + " style.", \
            akActor, Game.GetPlayer())

        DebugMsg("Combat style set for " + akActor.GetDisplayName() + ": " + normalized)
    Else
        Debug.Notification("Unknown combat style: " + style)
    EndIf
EndFunction

Function ApplyCombatStyleValues(Actor akActor, String style)
    {Apply Confidence/Aggression actor values for a combat style.
     Extracted so it can be called from SetCombatStyle and ReapplyCombatStyles.}
    If !akActor
        Return
    EndIf

    If style == "aggressive"
        akActor.SetAV("Confidence", 4) ; Foolhardy
        akActor.SetAV("Aggression", 1) ; Aggressive
    ElseIf style == "defensive" || style == "healer"
        akActor.SetAV("Confidence", 2) ; Average
        akActor.SetAV("Aggression", 0) ; Unaggressive
    Else ; balanced or ranged
        akActor.SetAV("Confidence", 3) ; Brave
        akActor.SetAV("Aggression", 1) ; Aggressive
    EndIf
EndFunction

Function ReapplyCombatStyles()
    {Re-apply combat style actor values for all registered followers.
     StorageUtil strings persist across save/load, but the actor value
     effects (Confidence, Aggression) may be reverted by NFF/EFF restoring
     their own saved values, or by the dismiss/recruit cycle.
     Called from Maintenance() on every game load.}
    Actor[] followers = GetAllFollowers()
    Int i = 0
    While i < followers.Length
        If followers[i]
            String style = GetCombatStyle(followers[i])
            If style != "balanced"
                ApplyCombatStyleValues(followers[i], style)
                DebugMsg("Reapplied combat style '" + style + "' for " + followers[i].GetDisplayName())
            EndIf
        EndIf
        i += 1
    EndWhile
EndFunction

Function ReapplyHomeSandboxing()
    {Migration function for saves upgrading from AddPackageOverride to alias system.
     If a homed NPC has a marker slot but isn't in an alias, force them in.
     Once all users have upgraded, this function does nothing (aliases persist natively).
     Called from Maintenance() on every game load.}
    If !HomeMarkerList || !HomeSlots
        DebugMsg("Home marker system not configured — skipping home sandbox check")
        Return
    EndIf

    Actor[] homedNPCs = GetAllHomedNPCs()
    Int migrated = 0
    Int i = 0
    While i < homedNPCs.Length
        Actor akActor = homedNPCs[i]
        If akActor && !IsRegisteredFollower(akActor)
            Int slot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)

            ; Migration: homed NPC without a marker slot — acquire one
            ; NOTE: Places marker at door ref — user can re-assign while inside to fix
            If slot < 0
                String homeLoc = GetAssignedHome(akActor)
                If homeLoc != ""
                    ObjectReference destRef = SeverActionsNative.ResolveDestination(akActor, homeLoc)
                    If destRef
                        slot = SeverActionsNative.Native_AcquireHomeMarkerSlot(akActor)
                        If slot >= 0
                            ObjectReference marker = HomeMarkerList.GetAt(slot) as ObjectReference
                            If marker
                                marker.MoveTo(destRef)
                                DebugMsg("Migrated home marker for " + akActor.GetDisplayName() + " to slot " + slot + " (door position)")
                            EndIf
                        EndIf
                    EndIf
                EndIf
            EndIf

            ; Migration: NPC has a slot but isn't in an alias — force them in
            If slot >= 0 && slot < HomeSlots.Length
                ObjectReference homeMarker = HomeMarkerList.GetAt(slot) as ObjectReference
                If homeMarker
                    Actor aliasActor = HomeSlots[slot].GetActorReference()
                    If aliasActor != akActor
                        ; Not in the alias (or wrong actor) — re-force
                        ApplyHomeSandbox(akActor, homeMarker, slot)
                        migrated += 1
                        DebugMsg("Migrated " + akActor.GetDisplayName() + " into HomeSlot_" + slot)
                    EndIf
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile

    If migrated > 0
        DebugMsg("Home sandbox migration: " + migrated + " NPC(s) forced into aliases")
    EndIf
EndFunction

Function PatchUpVanillaFollowerStatus()
    {Ensure ALL registered followers have CurrentFollowerFaction membership on every game load.
     SkyrimNet's is_follower() decorator checks this faction — without it, DLC followers
     like Serana cause decnpc/is_in_faction errors in prompt templates.
     Also ensures Ally relationship rank for vanilla/SeverActions-managed followers.
     Called from Maintenance() on every game load.}
    Faction currentFollowerFaction = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
    If !currentFollowerFaction
        Return
    EndIf

    Actor player = Game.GetPlayer()
    Actor[] followers = GetAllFollowers()
    Int i = 0
    While i < followers.Length
        Actor follower = followers[i]
        If follower
            ; Ensure CurrentFollowerFaction for ALL followers (including track-only/DLC)
            ; This is critical for is_follower() decorator in SkyrimNet prompts
            If !follower.IsInFaction(currentFollowerFaction) || follower.GetFactionRank(currentFollowerFaction) < 0
                follower.AddToFaction(currentFollowerFaction)
                follower.SetFactionRank(currentFollowerFaction, 0)
                DebugMsg("Patched CurrentFollowerFaction for " + follower.GetDisplayName())
            EndIf

            ; Only patch relationship rank for vanilla/SeverActions-managed followers
            ; Track-only followers (NFF/EFF/DLC) manage their own relationship ranks
            Bool wasAlreadyTeammate = StorageUtil.GetIntValue(follower, KEY_WAS_ALREADY_TEAMMATE, 0) == 1
            If !wasAlreadyTeammate
                If follower.GetRelationshipRank(player) < 3
                    ; Save original rank if not already saved
                    If StorageUtil.GetIntValue(follower, KEY_ORIG_RELRANK, -99) == -99
                        StorageUtil.SetIntValue(follower, KEY_ORIG_RELRANK, follower.GetRelationshipRank(player))
                    EndIf
                    follower.SetRelationshipRank(player, 3)
                    DebugMsg("Patched RelationshipRank to Ally for " + follower.GetDisplayName())
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile
EndFunction

String Function GetCombatStyle(Actor akActor)
    If !akActor
        Return "balanced"
    EndIf
    ; Prefer native cosave (reliable), fallback to StorageUtil (legacy)
    String nativeStyle = SeverActionsNative.Native_GetCombatStyle(akActor)
    If nativeStyle != ""
        Return nativeStyle
    EndIf
    Return StorageUtil.GetStringValue(akActor, KEY_COMBAT_STYLE, "balanced")
EndFunction

; =============================================================================
; MEMBER ACTION FUNCTIONS (Called by SkyrimNet YAML action configs)
;
; SkyrimNet calls executionFunctionName as a MEMBER function on the quest
; script instance - NOT as a Global. These must be non-Global with parameter
; signatures matching the YAML parameterMapping exactly.
; =============================================================================

Function AdjustRelationship(Actor akActor, Int rapportChange, Int trustChange, Int loyaltyChange, Int moodChange)
    {LLM-driven relationship adjustment. Called by SkyrimNet via adjustrelationship.yaml.
     The LLM decides how each interaction should affect the relationship based on
     conversation tone and content. Values are clamped by the Modify* functions.}
    If !akActor || !IsRegisteredFollower(akActor)
        Return
    EndIf

    ; Rate-limit: skip if cooldown hasn't elapsed since the last adjustment for this actor
    Float now = Utility.GetCurrentRealTime()
    Float lastAdjust = StorageUtil.GetFloatValue(akActor, KEY_LAST_REL_ADJUST, 0.0)
    If RelationshipCooldown > 0.0 && (now - lastAdjust) < RelationshipCooldown
        DebugMsg(akActor.GetDisplayName() + " relationship adjustment skipped (cooldown: " + ((RelationshipCooldown - (now - lastAdjust)) as Int) + "s remaining)")
        Return
    EndIf
    StorageUtil.SetFloatValue(akActor, KEY_LAST_REL_ADJUST, now)

    ; Apply adjustments (Modify* functions handle clamping to valid ranges)
    If rapportChange != 0
        ModifyRapport(akActor, rapportChange as Float)
    EndIf
    If trustChange != 0
        ModifyTrust(akActor, trustChange as Float)
    EndIf
    If loyaltyChange != 0
        ModifyLoyalty(akActor, loyaltyChange as Float)
    EndIf
    If moodChange != 0
        ModifyMood(akActor, moodChange as Float)
    EndIf

    ; Sync all relationship values to native FollowerDataStore for PrismaUI C++ fast path
    SyncRelationshipToNative(akActor)

    ; Also refresh the last interaction timestamp so neglect decay resets
    StorageUtil.SetFloatValue(akActor, KEY_LAST_INTERACTION, GetGameTimeInSeconds())

    ; Build a summary for the event system
    String summary = akActor.GetDisplayName() + " relationship shift:"
    If rapportChange != 0
        summary += " rapport " + rapportChange
    EndIf
    If trustChange != 0
        summary += " trust " + trustChange
    EndIf
    If loyaltyChange != 0
        summary += " loyalty " + loyaltyChange
    EndIf
    If moodChange != 0
        summary += " mood " + moodChange
    EndIf

    SkyrimNetApi.RegisterEvent("relationship_adjusted", summary, akActor, Game.GetPlayer())

    DebugMsg(summary)
EndFunction

Function DismissCompanion(Actor akActor)
    {Dismiss a companion. Called by SkyrimNet via dismissfollower.yaml.
     Always sends home (uses default sendHome=true).}
    UnregisterFollower(akActor)
EndFunction

Function CompanionWait(Actor akActor)
    {Tell any NPC to wait and sandbox at the current location.
     Called by SkyrimNet via companionwait.yaml. Works for both companions and non-companions.
     Delegates to SeverActions_Follow.Sandbox() which handles all package management:
     removing FollowPlayer, applying sandbox override, SandboxManager registration, etc.}
    If !akActor
        Return
    EndIf

    SeverActions_Follow followSys = GetFollowScript()
    If followSys
        followSys.Sandbox(akActor)
    Else
        ; Fallback: just set waiting flag if Follow system unavailable
        akActor.SetAV("WaitingForPlayer", 1)
        akActor.EvaluatePackage()
    EndIf

    If ShowNotifications
        Debug.Notification(akActor.GetDisplayName() + " is waiting here for you.")
    EndIf

    SkyrimNetApi.RegisterEvent("companion_waiting", \
        akActor.GetDisplayName() + " is waiting for " + Game.GetPlayer().GetDisplayName() + " at the current location.", \
        akActor, Game.GetPlayer())
EndFunction

Function CompanionFollow(Actor akActor)
    {Tell a waiting NPC to resume following. Called by SkyrimNet via companionfollow.yaml.
     Routes to the companion alias path for registered followers, or restarts the casual
     FollowPlayer package for non-companions who were following via StartFollowing.}
    If !akActor
        Return
    EndIf

    SeverActions_Follow followSys = GetFollowScript()
    If followSys
        If IsRegisteredFollower(akActor)
            ; Companion path: CompanionStartFollowing handles alias + LinkedRef + cleanup
            followSys.CompanionStartFollowing(akActor)
        Else
            ; Non-companion path: clean up sandbox and restart casual follow package
            followSys.StopSandbox(akActor)
            followSys.StartFollowing(akActor)
        EndIf
    Else
        ; Fallback: just clear waiting flag
        akActor.SetAV("WaitingForPlayer", 0)
        akActor.EvaluatePackage()
    EndIf

    If ShowNotifications
        Debug.Notification(akActor.GetDisplayName() + " is following you again.")
    EndIf

    SkyrimNetApi.RegisterEvent("companion_resumed_following", \
        akActor.GetDisplayName() + " stopped waiting and is following " + Game.GetPlayer().GetDisplayName() + " again.", \
        akActor, Game.GetPlayer())
EndFunction

Function FollowerLeaves(Actor akActor)
    {A companion decides to leave on their own. Called by SkyrimNet via followerleaves.yaml.
     This is a dramatic, rare moment after sustained mistreatment.}
    If !akActor
        Return
    EndIf

    ; This is a dramatic moment - the follower is choosing to leave
    SkyrimNetApi.RegisterEvent("follower_left_voluntarily", \
        akActor.GetDisplayName() + " has decided to leave " + Game.GetPlayer().GetDisplayName() + "'s service.", \
        akActor, Game.GetPlayer())

    UnregisterFollower(akActor)
EndFunction

; =============================================================================
; GLOBAL WRAPPER FUNCTIONS (Legacy - kept for external script calls)
; =============================================================================

Function SetCompanion_Execute(Actor akActor) Global
    SeverActions_FollowerManager instance = GetInstance()
    If instance
        instance.RegisterFollower(akActor)
    EndIf
EndFunction

Function DismissFollower_Execute(Actor akActor) Global
    SeverActions_FollowerManager instance = GetInstance()
    If instance
        instance.UnregisterFollower(akActor)
    EndIf
EndFunction

Function AssignHome_Execute(Actor akActor, String locationName) Global
    SeverActions_FollowerManager instance = GetInstance()
    If instance
        instance.AssignHome(akActor, locationName)
    EndIf
EndFunction

Function SetCombatStyle_Execute(Actor akActor, String style) Global
    SeverActions_FollowerManager instance = GetInstance()
    If instance
        instance.SetCombatStyle(akActor, style)
    EndIf
EndFunction

Function CompanionWait_Execute(Actor akActor) Global
    SeverActions_FollowerManager instance = GetInstance()
    If !instance || !akActor
        Return
    EndIf
    instance.CompanionWait(akActor)
EndFunction

Function FollowerLeaves_Execute(Actor akActor) Global
    SeverActions_FollowerManager instance = GetInstance()
    If instance
        instance.FollowerLeaves(akActor)
    EndIf
EndFunction

; =============================================================================
; GLOBAL ELIGIBILITY FUNCTIONS (Called by YAML eligibility rules)
; =============================================================================

Bool Function RecruitFollower_IsEligible(Actor akActor) Global
    If !akActor || akActor.IsDead() || akActor.IsInCombat()
        Return false
    EndIf

    SeverActions_FollowerManager instance = GetInstance()
    If !instance
        Return false
    EndIf

    ; Already a follower?
    If instance.IsRegisteredFollower(akActor)
        Return false
    EndIf

    ; At max capacity?
    If !instance.CanRecruitMore()
        Return false
    EndIf

    Return true
EndFunction

Bool Function DismissFollower_IsEligible(Actor akActor) Global
    If !akActor
        Return false
    EndIf

    SeverActions_FollowerManager instance = GetInstance()
    If !instance
        Return false
    EndIf

    Return instance.IsRegisteredFollower(akActor)
EndFunction

; =============================================================================
; HELPER FUNCTIONS
; =============================================================================

Float Function GetGameTimeInSeconds()
    {Convert current game time to seconds for precise tracking}
    ; GetCurrentGameTime() returns days as float
    ; Multiply by 24 to get hours, then by 3631 to get game seconds
    Return Utility.GetCurrentGameTime() * 24.0 * SECONDS_PER_GAME_HOUR
EndFunction

SeverActions_FollowerManager Function GetInstance() Global
    Return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_FollowerManager
EndFunction

SeverActions_Follow Function GetFollowScript()
    If FollowScript
        Return FollowScript
    EndIf
    ; Fallback: try to find via FormID
    Return Game.GetFormFromFile(0x000800, "SeverActions.esp") as SeverActions_Follow
EndFunction

SeverActions_Travel Function GetTravelScript()
    If TravelScript
        Return TravelScript
    EndIf
    ; Fallback: try to find on the quest
    Quest myQuest = Self as Quest
    If myQuest
        Return myQuest as SeverActions_Travel
    EndIf
    Return None
EndFunction

SeverActions_Outfit Function GetOutfitScript()
    If OutfitScript
        Return OutfitScript
    EndIf
    ; Fallback: try to find on the quest
    Return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Outfit
EndFunction

Float Function ClampFloat(Float value, Float minVal, Float maxVal)
    If value < minVal
        Return minVal
    ElseIf value > maxVal
        Return maxVal
    Else
        Return value
    EndIf
EndFunction

Function DebugMsg(String msg)
    If DebugMode
        Debug.Trace("[SeverActions_FollowerManager] " + msg)
    EndIf
EndFunction
