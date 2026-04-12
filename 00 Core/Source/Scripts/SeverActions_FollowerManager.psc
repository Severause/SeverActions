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

Float Property FollowerTeleportDistance = 2000.0 Auto
{Distance at which actively-following companions are teleported to the player.
Set to 0 to disable. Only when following — not waiting, sandboxing, or traveling.}

Bool Property ShowFollowerContext = true Auto
{When true, the follower relationship/behavior prompt (0175) is included in NPC bios.
When false, the section is skipped — useful for users who prefer vanilla-style companions.}

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

Float Property AssessmentCooldownMinHours = 4.0 Auto
{Minimum game hours between automatic relationship assessments per follower.
Each follower gets a random cooldown between min and max after each assessment.}

Float Property AssessmentCooldownMaxHours = 10.0 Auto
{Maximum game hours between automatic relationship assessments per follower.}

Bool Property AutoInterFollowerAssessment = true Auto
{Enable automatic inter-follower relationship assessment. When true, followers
periodically evaluate how they feel about each other based on shared events.}

Float Property InterFollowerCooldownMinHours = 6.0 Auto
{Minimum game hours between inter-follower relationship assessments per follower.}

Float Property InterFollowerCooldownMaxHours = 14.0 Auto
{Maximum game hours between inter-follower relationship assessments per follower.}

Bool Property AutoFollowerBanter = true Auto
{Enable spontaneous companion-to-companion conversations while traveling.
When true, a banter director periodically evaluates whether any two followers
should start talking to each other, then triggers SkyrimNet's dialogue pipeline.}

Float Property BanterCooldownMinHours = 2.0 Auto
{Minimum game hours between follower banter opportunities.}

Float Property BanterCooldownMaxHours = 5.0 Auto
{Maximum game hours between follower banter opportunities.}

Bool Property AutoOffScreenLife = true Auto
{Enable off-screen life event generation for dismissed followers with homes.
When true, dismissed followers generate believable daily events that become
memories and gossip. They'll naturally mention what happened when you return.}

Float Property OffScreenLifeCooldownMinHours = 10.0 Auto
{Minimum game hours between off-screen life event generation per dismissed follower.}

Float Property OffScreenLifeCooldownMaxHours = 40.0 Auto
{Maximum game hours between off-screen life event generation per dismissed follower.}

Bool Property OffScreenConsequences = true Auto
{Enable off-screen life consequences (arrest/bounty, gold changes, debt).
When false, only narrative events and gossip are generated.}

Float Property ConsequenceCooldownHours = 36.0 Auto
{Game hours between consequential off-screen events per follower.
Separate from event cooldown — consequences are rarer. Default 36 hours.}

Int Property MaxOffScreenBounty = 1000 Auto
{Maximum cumulative bounty a follower can accumulate from off-screen events.
Prevents runaway bounties from LLM overgeneration. Default 1000.}

Int Property MaxOffScreenGoldChange = 500 Auto
{Maximum gold gained or lost per off-screen event. Default 500.}

Float Property DeathGracePeriodHours = 4.0 Auto
{Game hours to wait after a follower's death before auto-removing them from the roster.
Set to 0 to disable auto-removal (manual only via PrismaUI force-remove).}

Int Property FrameworkMode = 0 Auto
{Recruitment mode: 0 = SeverActions (full control — teammate, packages, outfits, relationships),
 1 = Tracking (observe only — outfits and relationships, no teammate/package management).
 SPID keyword holders and NFF token holders auto-route to Tracking regardless of this setting.
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

SeverActions_Arrest Property ArrestScript Auto
{Reference to the Arrest system for off-screen crime consequences}

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

; Cooldown tracking for automatic LLM relationship assessment (game time seconds)
String Property KEY_LAST_ASSESS_GT = "SeverFollower_LastAssessGT" AutoReadOnly
; Per-NPC randomized next-eligible time (game time seconds) — set after each assessment
String Property KEY_NEXT_ASSESS_GT = "SeverFollower_NextAssessGT" AutoReadOnly

; Cooldown tracking for inter-follower relationship assessment (game time seconds)
String Property KEY_LAST_INTER_ASSESS_GT = "SeverFollower_LastInterAssessGT" AutoReadOnly
String Property KEY_NEXT_INTER_ASSESS_GT = "SeverFollower_NextInterAssessGT" AutoReadOnly

; Cooldown tracking for follower banter (global, stored on quest form via None)
String Property KEY_LAST_BANTER_GT = "SeverActions_LastBanterGT" AutoReadOnly
String Property KEY_NEXT_BANTER_GT = "SeverActions_NextBanterGT" AutoReadOnly

; Cooldown tracking for off-screen life event generation (game time seconds)
String Property KEY_LAST_LIFE_EVENT_GT = "SeverFollower_LastLifeEventGT" AutoReadOnly
String Property KEY_NEXT_LIFE_EVENT_GT = "SeverFollower_NextLifeEventGT" AutoReadOnly

; Life summary for dismissed followers (what happened while away)
String Property KEY_LIFE_SUMMARY = "SeverFollower_LifeSummary" AutoReadOnly

; Per-follower exclusion from off-screen life events
String Property KEY_OFFSCREEN_EXCLUDED = "SeverFollower_OffScreenExcluded" AutoReadOnly

; Game-time stamp of when follower was dismissed (used as grace period for off-screen life)
String Property KEY_DISMISS_GT = "SeverFollower_DismissGT" AutoReadOnly

; Flag set on explicit dismiss — prevents RecoverCustomAIFollowers from re-registering
; custom AI followers (Inigo, Lucien, etc.) whose mods keep IsPlayerTeammate() true permanently
String Property KEY_DISMISSED = "SeverFollower_Dismissed" AutoReadOnly

; Minimum game hours after dismiss before off-screen life events can fire
Float Property OffScreenGracePeriodHours = 6.0 Auto
{Dismissed followers wont generate off-screen events for this many game hours.
 Prevents immersion-breaking events while player is still nearby. Default 6 hours.}

; Cooldown tracking for off-screen consequences (separate from events)
String Property KEY_LAST_CONSEQUENCE_GT = "SeverFollower_LastConsequenceGT" AutoReadOnly

; Cumulative bounty from off-screen crime events
String Property KEY_OFFSCREEN_BOUNTY_TOTAL = "SeverFollower_OffScreenBountyTotal" AutoReadOnly

; Simple debt accumulator for off-screen debt events
String Property KEY_OFFSCREEN_DEBT = "SeverFollower_OffScreenDebt" AutoReadOnly

; Global tracking key for all NPCs with custom home assignments (stored on None form)
String Property KEY_HOMED_NPCS = "SeverActions_HomedNPCs" AutoReadOnly

; =============================================================================
; INTERNAL STATE
; =============================================================================

Float LastTickTime
Bool IsUpdating = false

; Vanilla dismiss detection — delayed confirmation to filter temporary mod toggles
Actor PendingDismissActor = None

; Relationship assessment tracking — only one assessment in flight at a time
; Store Actor references directly to avoid ESL FormID sign issues with Game.GetForm()
Actor PendingAssessmentActor = None
Bool AssessmentInProgress = false

; Inter-follower assessment tracking — separate from player-centric assessment
Actor PendingInterAssessActor = None
Bool InterFollowerAssessmentInProgress = false

; Follower banter tracking — lowest priority LLM system
Bool BanterInProgress = false

; Off-screen life event tracking — separate from both assessment types
Actor PendingOffScreenLifeActor = None
Bool OffScreenLifeInProgress = false

; Quest awareness tracking — queue-based LLM summary generation
; C++ stashes all metadata (actor, editorID, tier) — Papyrus only tracks in-flight state
Bool QuestAwarenessInProgress = false

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

    ; Register for cell load events — re-apply PO3 home sandbox overrides
    ; for track-only followers (PO3 overrides don't persist across cell transitions)
    RegisterForModEvent("SeverActions_CellLoaded", "OnCellLoadedReapplyHome")

    ; Register for PrismaUI actions
    ; Uses ModEvents because DispatchMethodCall silently fails (returns true but never executes)
    RegisterForModEvent("SeverActions_PrismaAssignHome", "OnPrismaAssignHome")
    RegisterForModEvent("SeverActions_PrismaClearHome", "OnPrismaClearHome")
    RegisterForModEvent("SeverActions_PrismaForceRemove", "OnPrismaForceRemove")
    RegisterForModEvent("SeverActions_PrismaSoftReset", "OnPrismaSoftReset")
    RegisterForModEvent("SeverActions_PrismaDismiss", "OnPrismaDismiss")
    RegisterForModEvent("SeverActions_PrismaResetAll", "OnPrismaResetAll")
    RegisterForModEvent("SeverActions_SetCombatStyle", "OnPrismaSetCombatStyle")
    RegisterForModEvent("SeverActions_SetEssential", "OnPrismaSetEssential")

    ; Off-screen life exclusion toggles from PrismaUI
    RegisterForModEvent("SeverActions_OffScreenExclude", "OnOffScreenExclude")
    RegisterForModEvent("SeverActions_OffScreenInclude", "OnOffScreenInclude")

    ; Quest awareness — C++ QuestAwarenessStore fires these when summary/completion queues have data
    RegisterForModEvent("SeverActions_QuestSummaryReady", "OnQuestSummaryReady")
    RegisterForModEvent("SeverActions_QuestCompleted", "OnQuestCompletedEvent")


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
    OffScreenLifeInProgress = false

    ; Auto-detect followers recruited outside our system (vanilla dialogue, NFF, other mods)
    DetectExistingFollowers()

    ; Recover custom AI followers who were in the party before SPID distributed
    ; the keyword. These actors exist in the cosave but have isFollower=false
    ; because OnNativeTeammateDetected skipped them (no faction). Now that SPID
    ; has given them the keyword, re-flag them as active followers.
    RecoverCustomAIFollowers()

    ; === CACHED FOLLOWER ARRAY ===
    ; GetAllFollowers() does a full Papyrus cell scan (GetNthRef on every NPC).
    ; Cache once and pass to all sub-functions to avoid 8+ redundant cell scans.
    Actor[] cachedFollowers = GetAllFollowers()

    ; Sync all relationship values from StorageUtil to native FollowerDataStore.
    ; PrismaUI reads from native store (C++ fast path), but values live in StorageUtil.
    ; This ensures PrismaUI shows correct values after every game load.
    SyncAllRelationshipsOnLoad(cachedFollowers)

    ; Re-assign outfit alias slots after load (ForceRefTo doesn't survive save/load)
    ReassignOutfitSlots(cachedFollowers)

    ; Re-apply combat style actor values after load
    ; NFF/EFF or the dismiss/recruit cycle can revert Confidence/Aggression to defaults.
    ; The StorageUtil string persists, but the actor value effects may not.
    ReapplyCombatStyles(cachedFollowers)

    ; Patch-up: ensure all vanilla-path followers have CurrentFollowerFaction + Ally rank
    ; (retroactively applies to followers recruited before this code existed)
    PatchUpVanillaFollowerStatus(cachedFollowers)

    ; Sync inter-follower pair relationships from StorageUtil to native store
    SyncAllPairRelationshipsOnLoad(cachedFollowers)

    ; Rebuild pre-formatted companion opinions strings from float values.
    ; StorageUtil strings are unreliable across save/load, but the individual
    ; Affinity/Respect float values persist fine. Rebuild on every load.
    RebuildAllCompanionOpinions(cachedFollowers)

    ; Update the roster string for prompt template access
    SyncFollowerRoster(cachedFollowers)

    ; Re-apply follow tracking after load (LinkedRef is runtime-only)
    ; The CK alias packages persist natively, but LinkedRef must be re-set
    ; Only reapply for SeverActions Mode followers (Tracking Mode doesn't use our packages)
    If FrameworkMode == 0
        SeverActions_Follow followSys = GetFollowScript()
        If followSys
            followSys.ReapplyFollowTracking(cachedFollowers)
        EndIf
    EndIf

    ; Re-apply home sandbox packages for dismissed NPCs with home markers
    ; Package overrides don't persist across save/load, so reapply on every load
    ReapplyHomeSandboxing()

    ; Register for sleep events — clear sandbox packages when player sleeps
    RegisterForSleep()

    ; One-time migration: old 3-value FrameworkMode to new 2-value system
    ; Old: 0=Auto, 1=SeverActions Only, 2=Tracking Only
    ; New: 0=SeverActions, 1=Tracking
    ; Only runs once — flag prevents re-migrating newly-set values on subsequent loads
    If StorageUtil.GetIntValue(None, "SeverActions_FrameworkModeMigrated", 0) == 0
        If FrameworkMode == 1
            FrameworkMode = 0  ; old "SeverActions Only" → new "SeverActions"
            Debug.Trace("[SeverActions_FollowerManager] Migrated FrameworkMode 1 → 0 (SeverActions)")
        ElseIf FrameworkMode >= 2
            FrameworkMode = 1  ; old "Tracking Only" → new "Tracking"
            Debug.Trace("[SeverActions_FollowerManager] Migrated FrameworkMode 2 → 1 (Tracking)")
        EndIf
        StorageUtil.SetIntValue(None, "SeverActions_FrameworkModeMigrated", 1)
    EndIf

    BanterInProgress = false

    Debug.Trace("[SeverActions_FollowerManager] Maintenance complete - Mode: " + FrameworkMode)
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
            ; Skip followers in a home sandbox alias — their PO3 override must persist
            Int homeSlot = SeverActionsNative.Native_GetHomeMarkerSlot(followers[i])
            Bool isHomeSandboxing = homeSlot >= 0 && !IsRegisteredFollower(followers[i])

            If isHomeSandboxing
                Debug.Trace("[SeverActions_FollowerManager] Skipping home-sandboxing " + followers[i].GetDisplayName() + " on sleep")
            ElseIf StorageUtil.GetIntValue(followers[i], "SeverActions_IsSandboxing") == 1
                followSys.StopSandbox(followers[i])
                Debug.Trace("[SeverActions_FollowerManager] Cleared sandbox for " + followers[i].GetDisplayName() + " on sleep (same cell)")
            Else
                ; Non-sandboxing, non-home followers: clear any lingering FF orphans
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

     PERF: If the native cosave already has tracked followers, skip the
     expensive cell scan — those followers are already in our system.
     Only fall back to cell scanning when the cosave is empty (first
     install, or all followers were dismissed).

     NFF quirk: NFF sets CurrentFollowerFaction rank to -1 on dismiss
     instead of removing from the faction. We must check faction rank >= 0
     to avoid detecting dismissed NFF followers as active.}
    Actor player = Game.GetPlayer()
    Cell playerCell = player.GetParentCell()
    If !playerCell
        Return
    EndIf

    ; Fast path: if native cosave already has tracked followers, skip the
    ; full cell scan. The cosave is the authoritative source after first load.
    ; This saves ~300ms in a 60-NPC city cell on every reload.
    Actor[] nativeTracked = SeverActionsNative.Native_GetAllTrackedFollowers()
    Bool hasNativeData = nativeTracked && nativeTracked.Length > 0

    Faction currentFollowerFaction = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction

    ; Serana uses DLC1SeranaFaction instead of CurrentFollowerFaction
    Faction seranaFaction = Game.GetFormFromFile(0x000183A5, "Dawnguard.esm") as Faction

    Int numRefs = playerCell.GetNumRefs(43) ; 43 = kNPC
    Int detected = 0
    Int i = 0

    While i < numRefs
        ObjectReference ref = playerCell.GetNthRef(i, 43)
        Actor actorRef = ref as Actor

        If actorRef && actorRef != player && !actorRef.IsDead() && !actorRef.IsCommandedActor()
            ; Fast skip: if actor is already in our faction, they're tracked.
            ; Faction check is an engine call (fast), avoids StorageUtil per NPC.
            If SeverActions_FollowerFaction && actorRef.IsInFaction(SeverActions_FollowerFaction)
                ; Already in our system — nothing to detect
            Else
                ; If native cosave has data, skip expensive faction checks for non-followers.
                ; New followers recruited via vanilla dialogue while our plugin was active
                ; are caught by TeammateMonitor (native event). This cell scan is only
                ; needed when the cosave is empty (first install / fresh start).
                If hasNativeData
                    ; Cosave covers most followers, but custom AI followers
                    ; may exist with isFollower=false if they were in the party
                    ; before the SPID keyword was distributed. Check them here.
                    If HasCustomAIKeyword(actorRef) && actorRef.IsPlayerTeammate() && !IsRegisteredFollower(actorRef) \
                        && StorageUtil.GetIntValue(actorRef, KEY_DISMISSED, 0) == 0
                        StorageUtil.SetIntValue(actorRef, KEY_IS_FOLLOWER, 1)
                        SeverActionsNative.Native_SetIsFollower(actorRef, true)
                        StorageUtil.SetFloatValue(actorRef, KEY_LAST_INTERACTION, GetGameTimeInSeconds())
                        If SeverActions_FollowerFaction
                            actorRef.AddToFaction(SeverActions_FollowerFaction)
                        EndIf
                        AssignOutfitSlot(actorRef)
                        detected += 1
                        Debug.Trace("[SeverActions_FollowerManager] DetectExisting: Recovered custom AI follower " + actorRef.GetDisplayName())
                    EndIf
                Else
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

                    ; Serana uses her own DLC faction instead of CurrentFollowerFaction
                    If !isGameFollower && seranaFaction
                        isGameFollower = actorRef.IsInFaction(seranaFaction)
                    EndIf

                    ; Custom AI followers (SPID keyword) count as game followers
                    ; even if they're not in vanilla follower factions — but not if
                    ; explicitly dismissed (their mods keep IsPlayerTeammate() true)
                    If !isGameFollower && HasCustomAIKeyword(actorRef) && actorRef.IsPlayerTeammate() \
                        && StorageUtil.GetIntValue(actorRef, KEY_DISMISSED, 0) == 0
                        isGameFollower = true
                    EndIf

                    If isGameFollower && !IsRegisteredFollower(actorRef)
                        ; Found an untracked follower - fully onboard them into our system.
                ; These are actors recruited via vanilla dialogue, another mod, or before
                ; our plugin was installed. They already have a working follow system,
                        ; so we treat them like custom-framework followers: track everything
                        ; but don't override their AI packages.

                        ; Check if this is a returning follower vs a truly new detection.
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
                            SeverActionsNative.Native_SetCombatStyle(actorRef, "no combat style")
                            SeverActionsNative.Native_SetRelationship(actorRef, DEFAULT_RAPPORT, DEFAULT_TRUST, DEFAULT_LOYALTY, DEFAULT_MOOD)
                            StorageUtil.SetStringValue(actorRef, KEY_COMBAT_STYLE, "no combat style")
                            Debug.Trace("[SeverActions_FollowerManager] New follower detected — initialized defaults for " + actorRef.GetDisplayName())
                        Else
                            SyncRelationshipToNative(actorRef)
                            Debug.Trace("[SeverActions_FollowerManager] Returning follower re-detected — preserving existing data for " + actorRef.GetDisplayName())
                        EndIf

                        StorageUtil.SetIntValue(actorRef, KEY_MORALITY, actorRef.GetAV("Morality") as Int)

                        If SeverActions_FollowerFaction
                            actorRef.AddToFaction(SeverActions_FollowerFaction)
                        EndIf

                        AssignOutfitSlot(actorRef)

                        ; Detected followers are always Tracking Mode (recruited externally)

                        detected += 1
                        Debug.Trace("[SeverActions_FollowerManager] Auto-detected existing follower: " + actorRef.GetDisplayName())
                    EndIf
                EndIf ; hasNativeData else
            EndIf ; faction fast-skip
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

Function RecoverCustomAIFollowers()
    {Recover followers who have SeverActions_FollowerFaction (added on any registration)
     but lost their StorageUtil/cosave tracking (e.g. after update, save/load quirks).
     The faction persists in the save regardless of SPID keyword status.
     Also catches any teammate with the custom AI keyword who was never registered.}
    Actor player = Game.GetPlayer()
    Cell playerCell = player.GetParentCell()
    If !playerCell
        Return
    EndIf

    Int numRefs = playerCell.GetNumRefs(43)
    Int recovered = 0
    Int i = 0

    While i < numRefs
        ObjectReference ref = playerCell.GetNthRef(i, 43)
        Actor actorRef = ref as Actor

        If actorRef && actorRef != player && !actorRef.IsDead()
            If !IsRegisteredFollower(actorRef)
                ; Check if they have our faction (proves they were previously registered)
                ; OR if they have the custom AI keyword and are a teammate
                Bool shouldRecover = false

                If SeverActions_FollowerFaction && actorRef.IsInFaction(SeverActions_FollowerFaction) \
                    && StorageUtil.GetIntValue(actorRef, KEY_DISMISSED, 0) == 0
                    shouldRecover = true
                ElseIf HasCustomAIKeyword(actorRef) && actorRef.IsPlayerTeammate()
                    ; Only recover if not explicitly dismissed — custom follower mods
                    ; keep IsPlayerTeammate() true permanently (Inigo, Lucien, etc.)
                    If StorageUtil.GetIntValue(actorRef, KEY_DISMISSED, 0) == 0
                        shouldRecover = true
                    EndIf
                EndIf

                If shouldRecover
                    StorageUtil.SetIntValue(actorRef, KEY_IS_FOLLOWER, 1)
                    SeverActionsNative.Native_SetIsFollower(actorRef, true)
                    StorageUtil.SetFloatValue(actorRef, KEY_LAST_INTERACTION, GetGameTimeInSeconds())

                    If !StorageUtil.HasFloatValue(actorRef, KEY_RAPPORT)
                        StorageUtil.SetFloatValue(actorRef, KEY_RECRUIT_TIME, GetGameTimeInSeconds())
                        StorageUtil.SetFloatValue(actorRef, KEY_RAPPORT, DEFAULT_RAPPORT)
                        StorageUtil.SetFloatValue(actorRef, KEY_TRUST, DEFAULT_TRUST)
                        StorageUtil.SetFloatValue(actorRef, KEY_LOYALTY, DEFAULT_LOYALTY)
                        StorageUtil.SetFloatValue(actorRef, KEY_MOOD, DEFAULT_MOOD)
                        SeverActionsNative.Native_SetCombatStyle(actorRef, "no combat style")
                        SeverActionsNative.Native_SetRelationship(actorRef, DEFAULT_RAPPORT, DEFAULT_TRUST, DEFAULT_LOYALTY, DEFAULT_MOOD)
                        StorageUtil.SetStringValue(actorRef, KEY_COMBAT_STYLE, "no combat style")
                    EndIf

                    StorageUtil.SetIntValue(actorRef, KEY_MORALITY, actorRef.GetAV("Morality") as Int)

                    If SeverActions_FollowerFaction && !actorRef.IsInFaction(SeverActions_FollowerFaction)
                        actorRef.AddToFaction(SeverActions_FollowerFaction)
                    EndIf

                    AssignOutfitSlot(actorRef)
                    recovered += 1
                    Debug.Trace("[SeverActions_FollowerManager] RecoverCustomAI: Recovered " + actorRef.GetDisplayName())
                EndIf
            EndIf
        EndIf

        i += 1
    EndWhile

    If recovered > 0
        Debug.Trace("[SeverActions_FollowerManager] RecoverCustomAI: Recovered " + recovered + " custom AI follower(s)")
        If ShowNotifications
            Debug.Notification(recovered + " custom companion(s) recovered by SeverActions.")
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

    ; Explicitly dismissed? Skip — prevents re-registration loop for custom followers
    ; (Inigo, Lucien, etc.) whose mods keep IsPlayerTeammate() true permanently.
    ; Exception: if WaitingForPlayer == 0 (follow mode), they've been genuinely
    ; re-recruited via their own dialogue — clear the dismissed flag and proceed.
    If StorageUtil.GetIntValue(akActor, KEY_DISMISSED, 0) == 1
        If akActor.GetAV("WaitingForPlayer") == 0.0
            StorageUtil.UnsetIntValue(akActor, KEY_DISMISSED)
            DebugMsg("Dismissed flag cleared — re-recruited via custom dialogue: " + akActor.GetDisplayName())
        Else
            return
        EndIf
    EndIf

    ; Custom AI followers (Inigo, Lucien, Kaidan, etc.) with NFF ignore tokens
    ; are onboarded into Tracking Mode — they get outfit/relationship tracking
    ; but their AI is managed by their own mod.

    ; Require membership in a recognized follower faction before onboarding.
    ; SetPlayerTeammate(true) alone is NOT sufficient — many mods (IntelEngine,
    ; Katana, etc.) toggle teammate status for their own mechanics.
    ; Only actors in CurrentFollowerFaction (rank >= 0) or DLC1SeranaFaction
    ; are considered legitimate recruits. Custom AI keyword holders bypass this.
    Faction currentFollowerFaction = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
    Faction seranaFaction = Game.GetFormFromFile(0x000183A5, "Dawnguard.esm") as Faction
    Bool inFollowerFaction = false

    If currentFollowerFaction && akActor.IsInFaction(currentFollowerFaction) && akActor.GetFactionRank(currentFollowerFaction) >= 0
        inFollowerFaction = true
    EndIf

    If !inFollowerFaction && seranaFaction
        inFollowerFaction = akActor.IsInFaction(seranaFaction)
    EndIf

    If !inFollowerFaction && !HasCustomAIKeyword(akActor)
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

    ; --- StorageUtil + native tracking keys ---
    StorageUtil.SetIntValue(akActor, KEY_IS_FOLLOWER, 1)
    SeverActionsNative.Native_SetIsFollower(akActor, true)
    StorageUtil.SetFloatValue(akActor, KEY_LAST_INTERACTION, GetGameTimeInSeconds())

    ; Only set defaults if they've never had relationship values set
    If isFirstRecruit
        StorageUtil.SetFloatValue(akActor, KEY_RECRUIT_TIME, GetGameTimeInSeconds())
        StorageUtil.SetFloatValue(akActor, KEY_RAPPORT, DEFAULT_RAPPORT)
        StorageUtil.SetFloatValue(akActor, KEY_TRUST, DEFAULT_TRUST)
        StorageUtil.SetFloatValue(akActor, KEY_LOYALTY, DEFAULT_LOYALTY)
        StorageUtil.SetFloatValue(akActor, KEY_MOOD, DEFAULT_MOOD)
        SeverActionsNative.Native_SetCombatStyle(akActor, "no combat style")
        SeverActionsNative.Native_SetRelationship(akActor, DEFAULT_RAPPORT, DEFAULT_TRUST, DEFAULT_LOYALTY, DEFAULT_MOOD)
        StorageUtil.SetStringValue(akActor, KEY_COMBAT_STYLE, "no combat style")
    EndIf

    ; Snapshot vanilla Morality AV for prompt context
    StorageUtil.SetIntValue(akActor, KEY_MORALITY, akActor.GetAV("Morality") as Int)

    ; --- Faction ---
    If SeverActions_FollowerFaction
        akActor.AddToFaction(SeverActions_FollowerFaction)
    EndIf

    ; --- Outfit alias slot ---
    AssignOutfitSlot(akActor)

    ; Native teammates are always Tracking Mode — they were recruited externally.
    ; We don't start our follow packages for them.

    ; --- Notifications and events differ for new vs returning followers ---
    If isFirstRecruit
        If ShowNotifications
            Debug.Notification(akActor.GetDisplayName() + " is now being tracked.")
        EndIf

        SkyrimNetApi.RegisterEvent("follower_recruited", \
            akActor.GetDisplayName() + " has been detected and onboarded as a companion.", \
            akActor, Game.GetPlayer())

        DebugMsg("Native teammate detected (tracking only): " + akActor.GetDisplayName())
    Else
        If ShowNotifications
            Debug.Notification(akActor.GetDisplayName() + " has returned.")
        EndIf

        DebugMsg("Returning follower re-registered: " + akActor.GetDisplayName())
    EndIf
EndEvent

Event OnNativeTeammateRemoved(string eventName, string strArg, float numArg, Form sender)
    {Fired when SetPlayerTeammate(false) is detected on a tracked actor.
     Uses delayed confirmation (2.5s) to filter temporary mod toggles (IntelEngine, etc.)
     before treating it as a real vanilla dismiss.}
    Actor akActor = sender as Actor
    If !akActor
        akActor = Game.GetFormEx(numArg as int) as Actor
    EndIf

    If !akActor || !IsRegisteredFollower(akActor)
        Return
    EndIf

    ; Store for delayed confirmation — OnUpdate will verify and act
    PendingDismissActor = akActor
    DebugMsg("Vanilla dismiss candidate: " + akActor.GetDisplayName() + " — confirming in 2.5s")
    RegisterForSingleUpdate(2.5)
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

Event OnCellLoadedReapplyHome(string eventName, string strArg, float numArg, Form sender)
    {Fired by native OutfitDataStore on TESCellFullyLoadedEvent.
     Rescues stranded auto-sandboxing followers, then re-applies PO3 home sandbox
     overrides for track-only followers in the loaded cell.}

    ; Rescue any followers stranded in auto-sandbox from the previous cell.
    ; Uses the isFollower + isSandboxing combo to detect auto-sandbox (not manual wait).
    SeverActionsNative.SituationMonitor_RescueSandboxers()

    If !HomeSlots || !HomeMarkerList
        Return
    EndIf

    Actor[] homedNPCs = GetAllHomedNPCs()
    Int i = 0
    While i < homedNPCs.Length
        Actor akActor = homedNPCs[i]
        If akActor && akActor.Is3DLoaded() && IsTrackOnlyFollower(akActor) \
            && !IsRegisteredFollower(akActor)
            ; Only re-apply for dismissed followers — active followers should keep following,
            ; not get forced into home sandbox when entering their home cell
            Int slot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)
            If slot >= 0 && slot < HomeSlots.Length
                Package homePkg = GetHomeSandboxPackage(slot)
                If homePkg
                    ActorUtil.AddPackageOverride(akActor, homePkg, 100, 1)
                    akActor.SetAV("WaitingForPlayer", 2)
                    akActor.EvaluatePackage()
                    DebugMsg("CellLoad: Re-applied home sandbox override for " + akActor.GetDisplayName())
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile
EndEvent

Event OnPrismaAssignHome(string eventName, string strArg, float numArg, Form sender)
    {Fired by PrismaUI when user clicks "Assign Home Here".
     strArg = "actorName|locationName" — name-based to avoid ESL FormID sign issues.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    String locName = StringUtil.Substring(strArg, pipePos + 1)

    Actor akActor = SeverActionsNative.FindActorByName(actorName)
    If !akActor
        Debug.Trace("[SeverActions_FollowerManager] PrismaAssignHome: could not resolve actor '" + actorName + "'")
        Return
    EndIf

    If locName == ""
        Debug.Trace("[SeverActions_FollowerManager] PrismaAssignHome: empty location name")
        Return
    EndIf

    DebugMsg("PrismaUI AssignHome: " + akActor.GetDisplayName() + " -> " + locName)
    AssignHome(akActor, locName)
EndEvent

Event OnPrismaClearHome(string eventName, string strArg, float numArg, Form sender)
    {Fired by PrismaUI when user clicks "Clear Home".
     strArg = "actorName|" — name-based to avoid ESL FormID sign issues.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)

    Actor akActor = SeverActionsNative.FindActorByName(actorName)
    If !akActor
        Debug.Trace("[SeverActions_FollowerManager] PrismaClearHome: could not resolve actor '" + actorName + "'")
        Return
    EndIf

    DebugMsg("PrismaUI ClearHome: " + akActor.GetDisplayName())
    ClearHome(akActor)
EndEvent

Event OnPrismaSetCombatStyle(string eventName, string strArg, float numArg, Form sender)
    {Fired by PrismaUI when user changes combat style dropdown.
     strArg = "formID|styleName" — formID as signed int, style as string.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String formIdStr = StringUtil.Substring(strArg, 0, pipePos)
    String styleName = StringUtil.Substring(strArg, pipePos + 1)

    Int formId = formIdStr as Int
    Actor akActor = Game.GetFormEx(formId) as Actor
    If !akActor
        Debug.Trace("[SeverActions_FollowerManager] PrismaSetCombatStyle: could not resolve formID " + formIdStr)
        Return
    EndIf

    DebugMsg("PrismaUI SetCombatStyle: " + akActor.GetDisplayName() + " -> " + styleName)
    SetCombatStyle(akActor, styleName)
EndEvent

Event OnPrismaSetEssential(string eventName, string strArg, float numArg, Form sender)
    {Fired by PrismaUI when user toggles essential status per follower.
     strArg = "formID|1" (enable) or "formID|0" (disable).}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String formIdStr = StringUtil.Substring(strArg, 0, pipePos)
    String valStr = StringUtil.Substring(strArg, pipePos + 1)

    Int formId = formIdStr as Int
    Actor akActor = Game.GetFormEx(formId) as Actor
    If !akActor
        Return
    EndIf

    If valStr == "1"
        StorageUtil.UnsetIntValue(akActor, "SeverActions_EssentialOff")
        DebugMsg("PrismaUI Essential ON: " + akActor.GetDisplayName())
    Else
        StorageUtil.SetIntValue(akActor, "SeverActions_EssentialOff", 1)
        DebugMsg("PrismaUI Essential OFF: " + akActor.GetDisplayName())
    EndIf
EndEvent

Event OnOffScreenExclude(string eventName, string strArg, float numArg, Form sender)
    {Fired by PrismaUI when user excludes a follower from off-screen life events.}
    Actor akActor = Game.GetFormEx(numArg as Int) as Actor
    If akActor
        StorageUtil.SetIntValue(akActor, KEY_OFFSCREEN_EXCLUDED, 1)
        DebugMsg("Off-screen excluded: " + akActor.GetDisplayName())
    EndIf
EndEvent

Event OnOffScreenInclude(string eventName, string strArg, float numArg, Form sender)
    {Fired by PrismaUI when user re-includes a follower in off-screen life events.}
    Actor akActor = Game.GetFormEx(numArg as Int) as Actor
    If akActor
        StorageUtil.UnsetIntValue(akActor, KEY_OFFSCREEN_EXCLUDED)
        DebugMsg("Off-screen included: " + akActor.GetDisplayName())
    EndIf
EndEvent

; =============================================================================
; NFF INTEGRATION
; =============================================================================

Bool Function HasNFF()
    {Check if Nether's Follower Framework is installed}
    Return Game.GetModByName("nwsFollowerFramework.esp") != 255
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

; =============================================================================
; NATIVE ROUTING — Vanilla DialogueFollower + Serana Mental Model
; Routes recruitment/dismissal through the NPC's native quest system so hotkey
; recruitment behaves identically to vanilla dialogue.
; =============================================================================

Bool Function IsSerana(Actor akActor)
    {Check if this actor is Serana via DLC1SeranaFaction.}
    If !akActor
        Return false
    EndIf
    Faction seranaFaction = Game.GetFormFromFile(0x000183A5, "Dawnguard.esm") as Faction
    Return seranaFaction && akActor.IsInFaction(seranaFaction)
EndFunction

Bool Function RecruitViaVanillaDialogue(Actor akActor)
    {Route recruitment through vanilla DialogueFollowerScript.SetFollower().
     Replicates the exact "Follow me" dialogue behavior: removes from DismissedFollower
     faction, sets relationship rank >= 3, calls SetPlayerTeammate(), forces into
     pFollowerAlias, sets PlayerFollowerCount to 1.}
    Quest dfQuest = Game.GetFormFromFile(0x000750BA, "Skyrim.esm") as Quest
    If !dfQuest
        DebugMsg("RecruitViaVanillaDialogue: DialogueFollower quest not found")
        Return false
    EndIf
    DialogueFollowerScript dfScript = dfQuest as DialogueFollowerScript
    If !dfScript
        DebugMsg("RecruitViaVanillaDialogue: Cast to DialogueFollowerScript failed")
        Return false
    EndIf
    ; Check if actor already has a bow before vanilla recruitment (SetFollower adds one)
    Bool hadBow = akActor.GetEquippedWeapon(true) != None || \
        SeverActionsNative.FindItemByName(akActor, "bow") != None

    dfScript.SetFollower(akActor as ObjectReference)

    ; Remove the hunting bow + iron arrows that vanilla SetFollower forcefully adds
    ; — only if they didn't already have a bow (don't strip archers)
    If !hadBow
        Form huntingBow = Game.GetFormFromFile(0x00013985, "Skyrim.esm")
        Form ironArrow = Game.GetFormFromFile(0x0001397D, "Skyrim.esm")
        If huntingBow && akActor.GetItemCount(huntingBow) > 0
            akActor.RemoveItem(huntingBow, akActor.GetItemCount(huntingBow), true)
            DebugMsg("RecruitViaVanillaDialogue: Removed vanilla hunting bow from " + akActor.GetDisplayName())
        EndIf
        If ironArrow && akActor.GetItemCount(ironArrow) > 0
            akActor.RemoveItem(ironArrow, akActor.GetItemCount(ironArrow), true)
        EndIf
    EndIf

    DebugMsg("RecruitViaVanillaDialogue: Called SetFollower for " + akActor.GetDisplayName())
    Return true
EndFunction

Bool Function DismissViaVanillaDialogue(Actor akActor)
    {Route dismissal through vanilla DialogueFollowerScript.DismissFollower().
     Adds to DismissedFollower faction, calls SetPlayerTeammate(false), clears alias,
     sets PlayerFollowerCount to 0. Only works if this actor is in the vanilla alias.}
    Quest dfQuest = Game.GetFormFromFile(0x000750BA, "Skyrim.esm") as Quest
    If !dfQuest
        Return false
    EndIf
    DialogueFollowerScript dfScript = dfQuest as DialogueFollowerScript
    If !dfScript
        Return false
    EndIf
    ; Only dismiss if this actor is actually in the vanilla follower alias
    ReferenceAlias followerAlias = dfQuest.GetAlias(0) as ReferenceAlias
    If followerAlias && followerAlias.GetReference() == akActor as ObjectReference
        dfScript.DismissFollower(0, 0)  ; iMessage=0 (standard), iSayLine=0 (skip line)
        DebugMsg("DismissViaVanillaDialogue: Called DismissFollower for " + akActor.GetDisplayName())
        Return true
    EndIf
    DebugMsg("DismissViaVanillaDialogue: " + akActor.GetDisplayName() + " not in vanilla alias — skipping")
    Return false
EndFunction

Bool Function RecruitSerana(Actor akActor)
    {Route Serana's recruitment through her DLC1_NPCMentalModel quest.
     Calls EngageFollowBehavior() which sets her custom flags, calls
     SetPlayerTeammate(), adds to WIFollowerCommentFaction, starts monitoring.}
    Quest mmQuest = Game.GetFormFromFile(0x002B6E, "Dawnguard.esm") as Quest
    If !mmQuest
        DebugMsg("RecruitSerana: Mental model quest (0x002B6E) not found in Dawnguard.esm")
        Return false
    EndIf
    DLC1_NPCMentalModelScript mm = mmQuest as DLC1_NPCMentalModelScript
    If !mm
        DebugMsg("RecruitSerana: Cast to DLC1_NPCMentalModelScript failed")
        Return false
    EndIf
    mm.EngageFollowBehavior(true)  ; allowDismiss=true so player can dismiss via dialogue
    DebugMsg("RecruitSerana: Called EngageFollowBehavior for Serana")
    Return true
EndFunction

Bool Function DismissSerana(Actor akActor)
    {Route Serana's dismissal through her DLC1_NPCMentalModel quest.
     Calls DisengageFollowBehavior() which clears flags, calls
     SetPlayerTeammate(false), removes from WIFollowerCommentFaction, stops monitoring.}
    Quest mmQuest = Game.GetFormFromFile(0x002B6E, "Dawnguard.esm") as Quest
    If !mmQuest
        Return false
    EndIf
    DLC1_NPCMentalModelScript mm = mmQuest as DLC1_NPCMentalModelScript
    If !mm
        Return false
    EndIf
    mm.DisengageFollowBehavior()
    DebugMsg("DismissSerana: Called DisengageFollowBehavior for Serana")
    Return true
EndFunction

Bool Function IsTrackOnlyFollower(Actor akActor)
    {Returns true if this actor has their own follow system and should not get our packages.
     Covers: Custom AI keyword holders (SPID-distributed), NFF ignore-token holders,
     and DLC-managed followers (Serana). Vanilla NPCs always get full SeverActions setup.}
    Return HasCustomAIKeyword(akActor) || HasNFFIgnoreToken(akActor) || IsDLCManagedFollower(akActor)
EndFunction

Bool Function HasCustomAIKeyword(Actor akActor)
    {Check if an actor has the SeverActions_CustomAIFollower keyword.
     Distributed via SPID to modded followers with custom AI systems
     (Inigo, Lucien, Kaidan, etc.) so SeverActions tracks them for
     relationships and gossip without overriding their AI packages.
     Works independently of NFF — covers users without any follower framework.}
    Keyword customAIKW = Game.GetFormFromFile(0x13C78B, "SeverActions.esp") as Keyword
    If !customAIKW
        Return false
    EndIf
    Return akActor.HasKeyword(customAIKW)
EndFunction

; (ShouldUseFramework, HasEFF, GetNFFController, GetEFFController removed —
;  framework routing replaced by SeverActions/Tracking mode split)

; =============================================================================
; UPDATE LOOP - Relationship decay and mood drift
; =============================================================================

Event OnUpdate()
    ; --- Vanilla dismiss delayed confirmation ---
    ; If TeammateMonitor flagged a removal, verify it's still real (not a mod toggle)
    If PendingDismissActor != None
        Actor checkActor = PendingDismissActor
        PendingDismissActor = None
        If IsRegisteredFollower(checkActor)
            Bool confirmed = false
            If !checkActor.IsPlayerTeammate()
                ; Clear-cut: teammate status removed → vanilla dismiss confirmed
                confirmed = true
            ElseIf IsTrackOnlyFollower(checkActor)
                ; Track-only followers (Inigo, Lucien, etc.) may keep IsPlayerTeammate()
                ; true even after their mod's dismiss. Check WaitingForPlayer == -1 as
                ; a secondary signal — custom followers set this on dismiss.
                If checkActor.GetAV("WaitingForPlayer") == -1.0
                    ; Apply home sandbox before unregistering if they have a home
                    Int homeSlot = SeverActionsNative.Native_GetHomeMarkerSlot(checkActor)
                    If homeSlot >= 0 && HomeMarkerList
                        ObjectReference homeMarker = HomeMarkerList.GetAt(homeSlot) as ObjectReference
                        If homeMarker
                            ApplyHomeSandbox(checkActor, homeMarker, homeSlot)
                            DebugMsg("Track-only dismiss: redirected to home before unregister: " + checkActor.GetDisplayName())
                        EndIf
                    EndIf
                    confirmed = true
                    DebugMsg("Track-only dismiss confirmed via WFP=-1: " + checkActor.GetDisplayName())
                Else
                    DebugMsg("Track-only still teammate + WFP != -1, skipping: " + checkActor.GetDisplayName())
                EndIf
            EndIf

            If confirmed
                DebugMsg("Vanilla dismiss confirmed: " + checkActor.GetDisplayName())
                UnregisterFollower(checkActor)
            Else
                DebugMsg("Dismiss cancelled (teammate restored): " + checkActor.GetDisplayName())
            EndIf
        EndIf
        ; Re-register for normal update cycle and return — don't fall through this tick
        RegisterForSingleUpdate(30.0)
        Return
    EndIf

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

    ; Auto-untrack custom AI followers who lost teammate status (vanilla dismiss).
    ; TeammateMonitor handles real-time detection, but this catches edge cases
    ; where the actor unloaded before the monitor could scan, or the removal
    ; event was missed. Runs every 30s, lightweight — only checks loaded actors.
    CheckTrackOnlyFollowerStatus()

    ; Automatic relationship assessments — at most one type per tick to avoid LLM flooding
    If AutoRelAssessment && !InterFollowerAssessmentInProgress
        CheckRelationshipAssessments()
    EndIf

    ; Inter-follower assessment — only fires if no player-centric assessment is in flight
    If AutoInterFollowerAssessment && !AssessmentInProgress && !InterFollowerAssessmentInProgress
        CheckInterFollowerAssessments()
    EndIf

    ; Off-screen life events — only fires if no other LLM assessments are in flight
    If AutoOffScreenLife && !AssessmentInProgress && !InterFollowerAssessmentInProgress && !OffScreenLifeInProgress
        CheckOffScreenLifeEvents()
    EndIf

    ; Follower banter — independent of other LLM systems, only gated by its own cooldown + flag
    If AutoFollowerBanter && !BanterInProgress
        CheckFollowerBanter()
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

Function ReassignOutfitSlots(Actor[] followers)
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

Function CheckTrackOnlyFollowerStatus()
    {Periodic sweep (every 30s from OnUpdate) for track-only followers who lost
     teammate status via vanilla dismiss. TeammateMonitor handles real-time detection,
     but this catches cases where the actor unloaded before the monitor could scan,
     or the event was missed. Only checks loaded actors — unloaded ones are checked
     when they next load via DetectExistingFollowers/RecoverCustomAIFollowers guards.}
    Actor[] followers = GetAllFollowers()
    Int i = 0
    While i < followers.Length
        Actor follower = followers[i]
        If follower && IsTrackOnlyFollower(follower)
            ; Only check loaded actors — can't read state on unloaded ones reliably
            If follower.Is3DLoaded()
                Bool shouldUntrack = false

                If !follower.IsPlayerTeammate()
                    ; Teammate status cleared — standard vanilla dismiss signal
                    shouldUntrack = true
                    DebugMsg("Track-only auto-untrack: " + follower.GetDisplayName() + " lost teammate status")
                ElseIf follower.GetAV("WaitingForPlayer") == -1.0
                    ; WaitingForPlayer = -1 means "dismissed" for custom followers
                    ; (Inigo, etc.) that never clear IsPlayerTeammate on dismiss.
                    ; If they have a SeverActions home, redirect them there instead
                    ; of letting them return to their default cell (e.g. Inigo's jail).
                    Int homeSlot = SeverActionsNative.Native_GetHomeMarkerSlot(follower)
                    If homeSlot >= 0 && HomeMarkerList
                        ObjectReference homeMarker = HomeMarkerList.GetAt(homeSlot) as ObjectReference
                        If homeMarker
                            ApplyHomeSandbox(follower, homeMarker, homeSlot)
                            DebugMsg("Track-only auto-untrack: " + follower.GetDisplayName() + " — redirected to home (WFP=-1 → sandbox)")
                        EndIf
                    EndIf
                    shouldUntrack = true
                    DebugMsg("Track-only auto-untrack: " + follower.GetDisplayName() + " has WaitingForPlayer=-1 (custom dismiss)")
                EndIf

                If shouldUntrack
                    UnregisterFollower(follower)
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
    StorageUtil.UnsetFormValue(akActor, "SeverFollower_OrigCombatStyleForm")
    StorageUtil.UnsetFloatValue(akActor, KEY_LAST_REL_ADJUST)
    StorageUtil.UnsetFloatValue(akActor, KEY_LAST_ASSESS_GT)
    StorageUtil.UnsetFloatValue(akActor, KEY_LAST_INTER_ASSESS_GT)
    StorageUtil.UnsetFloatValue(akActor, KEY_LAST_LIFE_EVENT_GT)
    StorageUtil.UnsetStringValue(akActor, KEY_LIFE_SUMMARY)
    StorageUtil.UnsetIntValue(akActor, KEY_OFFSCREEN_EXCLUDED)
    StorageUtil.UnsetFloatValue(akActor, KEY_LAST_CONSEQUENCE_GT)
    StorageUtil.UnsetIntValue(akActor, KEY_OFFSCREEN_BOUNTY_TOTAL)
    StorageUtil.UnsetIntValue(akActor, KEY_OFFSCREEN_DEBT)

    ; Clear native off-screen life data
    SeverActionsNative.Native_OffScreen_ClearActor(akActor)

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

    ; --- Restore DefaultOutfit before clearing outfit slot ---
    SeverActionsNative.Native_Outfit_ClearLock(akActor)

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

Function SoftResetFollower(Actor akActor)
    {Clear factions, packages, aliases, and teammate status — but KEEP all relationship
     data (rapport, trust, loyalty, mood, home, combat style, assessment history).
     Used to unstick followers without losing their history.}
    If !akActor
        Return
    EndIf

    String actorName = akActor.GetDisplayName()
    DebugMsg("SoftResetFollower: " + actorName)

    ; Mark as not currently following (but keep SeverFollower_IsFollower for re-recruit detection)
    StorageUtil.SetIntValue(akActor, KEY_IS_FOLLOWER, 0)
    StorageUtil.UnsetIntValue(akActor, KEY_DISMISSED)

    ; Remove from factions
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

    ; Clear outfit alias slot (but don't purge outfit data — presets survive)
    ClearOutfitSlot(akActor)

    ; Stop following if active + remove waiting faction
    SeverActions_Follow followSys = GetFollowScript()
    If followSys
        followSys.CompanionStopFollowing(akActor)
        If followSys.SeverActions_WaitingFaction
            akActor.RemoveFromFaction(followSys.SeverActions_WaitingFaction)
        EndIf
    EndIf

    ; Sync roster
    SyncFollowerRoster()

    If ShowNotifications
        Debug.Notification(actorName + " has been soft-reset. Recruit again to continue.")
    EndIf

    DebugMsg("SoftResetFollower complete: " + actorName)
EndFunction

Event OnPrismaSoftReset(string eventName, string strArg, float numArg, Form sender)
    {Handle soft-reset from PrismaUI. strArg = "actorName|". Clears factions/packages but keeps relationship data.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = SeverActionsNative.FindActorByName(actorName)
    If akActor
        DebugMsg("PrismaUI soft-reset: " + akActor.GetDisplayName())
        SoftResetFollower(akActor)
    Else
        DebugMsg("PrismaUI soft-reset: actor '" + actorName + "' not found")
    EndIf
EndEvent

Event OnPrismaForceRemove(string eventName, string strArg, float numArg, Form sender)
    {Handle force-remove from PrismaUI. The C++ side already clears native stores;
     this handles Papyrus-side cleanup (StorageUtil, factions, aliases).
     strArg = "actorName|" — actor display name encoded for ESL compatibility.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = SeverActionsNative.FindActorByName(actorName)
    If akActor
        DebugMsg("PrismaUI force-remove: " + akActor.GetDisplayName())
        PurgeFollower(akActor)
    Else
        Debug.Trace("[SeverActions_FollowerManager] PrismaUI force-remove: actor '" + actorName + "' not resolvable (orphan) — native stores already cleared")
    EndIf
EndEvent

Event OnPrismaDismiss(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: Dismiss a specific follower.
     strArg = "actorName|" — actor display name encoded for ESL compatibility.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = SeverActionsNative.FindActorByName(actorName)
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
    StorageUtil.UnsetIntValue(akActor, KEY_DISMISSED)
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
        SeverActionsNative.Native_SetCombatStyle(akActor, "no combat style")
        SeverActionsNative.Native_SetRelationship(akActor, DEFAULT_RAPPORT, DEFAULT_TRUST, DEFAULT_LOYALTY, DEFAULT_MOOD)
        StorageUtil.SetStringValue(akActor, KEY_COMBAT_STYLE, "no combat style")
    EndIf

    ; Snapshot vanilla Morality AV for prompt context (0=Any Crime, 1=Violence, 2=Property, 3=None)
    StorageUtil.SetIntValue(akActor, KEY_MORALITY, akActor.GetAV("Morality") as Int)

    ; Recruitment rapport bonus (only on first recruit — don't stack on re-recruit)
    If isFirstRecruit
        ModifyRapport(akActor, 5.0)
        ModifyTrust(akActor, 5.0)
    EndIf

    ; --- Route to the appropriate recruitment mode ---

    ; =========================================================================
    ; SERANA — always routes through her DLC mental model quest
    ; =========================================================================
    If IsSerana(akActor) && !akActor.IsPlayerTeammate()
        If RecruitSerana(akActor)
            StorageUtil.SetIntValue(akActor, "SeverActions_RecruitedViaSerana", 1)
            DebugMsg("Serana DLC routing: " + akActor.GetDisplayName())
        Else
            DebugMsg("Serana DLC routing FAILED — quest not ready, using manual setup")
            akActor.SetPlayerTeammate(true)
            akActor.IgnoreFriendlyHits(true)
        EndIf

    ; =========================================================================
    ; TRACKING MODE — observe only, no teammate/package management
    ; Auto-assigned to: SPID keyword holders, NFF token holders, DLC-managed
    ; Also used when user sets FrameworkMode = 1 (Tracking)
    ; =========================================================================
    ElseIf IsTrackOnlyFollower(akActor) || FrameworkMode == 1
        DebugMsg("Tracking mode: " + akActor.GetDisplayName())
        ; Still remove our home sandbox if active — don't leave stale packages
        RemoveHomeSandbox(akActor)

    ; =========================================================================
    ; SEVERACTIONS MODE — full control
    ; =========================================================================
    Else
        DebugMsg("SeverActions mode: " + akActor.GetDisplayName())

        ; Save original AI values for restoration on dismiss
        StorageUtil.SetFloatValue(akActor, KEY_ORIG_AGGRESSION, akActor.GetAV("Aggression"))
        StorageUtil.SetFloatValue(akActor, KEY_ORIG_CONFIDENCE, akActor.GetAV("Confidence"))
        StorageUtil.SetIntValue(akActor, KEY_ORIG_RELRANK, akActor.GetRelationshipRank(Game.GetPlayer()))

        ; Boost AI so cowardly/passive NPCs will fight as companions.
        ; Only sets actor values — does NOT override combat style form.
        ; Users can pick a specific combat style in PrismaUI if they want.
        If akActor.GetAV("Confidence") < 3
            akActor.SetAV("Confidence", 3)  ; Brave
        EndIf
        If akActor.GetAV("Aggression") < 1
            akActor.SetAV("Aggression", 1)  ; Aggressive
        EndIf
        If akActor.GetAV("Assistance") < 2
            akActor.SetAV("Assistance", 2)  ; Helps Allies
        EndIf


        ; Set teammate status and factions
        akActor.SetPlayerTeammate(true)
        akActor.IgnoreFriendlyHits(true)
        Faction cff = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
        If cff
            akActor.AddToFaction(cff)
            akActor.SetFactionRank(cff, 0)
        EndIf
        If akActor.GetRelationshipRank(Game.GetPlayer()) < 3
            akActor.SetRelationshipRank(Game.GetPlayer(), 3)
        EndIf

        ; Vanilla DialogueFollower routing for idle lines (skip when NFF installed —
        ; NFF hooks OnLoad on those aliases and grabs the actor regardless)
        If !HasNFF()
            RecruitViaVanillaDialogue(akActor)
            Quest dfQuest = Game.GetFormFromFile(0x000750BA, "Skyrim.esm") as Quest
            If dfQuest
                ReferenceAlias dfAlias = dfQuest.GetAlias(0) as ReferenceAlias
                If dfAlias && dfAlias.GetReference() == None
                    dfAlias.ForceRefTo(akActor)
                    DebugMsg("Filled DialogueFollower alias: " + akActor.GetDisplayName())
                EndIf
            EndIf
        EndIf

        ; Remove home sandbox and start our follow package
        RemoveHomeSandbox(akActor)
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
        If style != "no combat style" && style != "balanced"
            ApplyCombatStyleValues(akActor, style)
            DebugMsg("Reapplied combat style '" + style + "' on re-recruit for " + akActor.GetDisplayName())
        EndIf
    EndIf

    Bool isTrackOnly = IsTrackOnlyFollower(akActor) || FrameworkMode == 1

    If isFirstRecruit
        If ShowNotifications
            If isTrackOnly
                Debug.Notification(akActor.GetDisplayName() + " is now being tracked.")
            Else
                Debug.Notification(akActor.GetDisplayName() + " has joined you as a companion.")
            EndIf
        EndIf

        SkyrimNetApi.RegisterEvent("follower_recruited", \
            akActor.GetDisplayName() + " has been recruited as a companion by " + Game.GetPlayer().GetDisplayName() + ".", \
            akActor, Game.GetPlayer())

        DebugMsg("Registered follower (NEW, " + (isTrackOnly as String) + "): " + akActor.GetDisplayName())
    Else
        If ShowNotifications
            If isTrackOnly
                Debug.Notification(akActor.GetDisplayName() + " is now being tracked.")
            Else
                Debug.Notification(akActor.GetDisplayName() + " has returned.")
            EndIf
        EndIf

        DebugMsg("Registered follower (RETURNING): " + akActor.GetDisplayName())
    EndIf

    ; Set essential if enabled (default on) and they aren't already essential
    Bool essentialEnabled = StorageUtil.GetIntValue(akActor, "SeverActions_EssentialOff", 0) == 0
    If essentialEnabled && !SeverActionsNative.Native_IsEssential(akActor)
        StorageUtil.SetIntValue(akActor, "SeverActions_WasEssential", 0)
        SeverActionsNative.Native_SetEssential(akActor)
        DebugMsg("Set essential for " + akActor.GetDisplayName())
    ElseIf SeverActionsNative.Native_IsEssential(akActor)
        StorageUtil.SetIntValue(akActor, "SeverActions_WasEssential", 1)
    EndIf

    ; Notify quest awareness store — seeds SECONDHAND awareness of active quests
    SeverActionsNative.Native_OnFollowerRecruited(akActor)

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
    StorageUtil.SetIntValue(akActor, KEY_DISMISSED, 1)
    StorageUtil.SetFloatValue(akActor, KEY_DISMISS_GT, GetGameTimeInSeconds())
    SeverActionsNative.Native_ClearFollowerData(akActor)

    ; Remove from our faction
    If SeverActions_FollowerFaction
        akActor.RemoveFromFaction(SeverActions_FollowerFaction)
    EndIf

    ; Clear the vanilla DialogueFollower alias if it holds this actor.
    ; Frees the slot for the next follower and stops vanilla follower dialogue.
    Quest dialogueFollowerQuest = Game.GetFormFromFile(0x000750BA, "Skyrim.esm") as Quest
    If dialogueFollowerQuest
        ReferenceAlias followerAlias = dialogueFollowerQuest.GetAlias(0) as ReferenceAlias
        If followerAlias && followerAlias.GetReference() == akActor as ObjectReference
            followerAlias.Clear()
            DebugMsg("Cleared DialogueFollower alias for " + akActor.GetDisplayName())
        EndIf
    EndIf

    ; --- Remove proper follower status ---

    ; =========================================================================
    ; SERANA — DLC mental model dismissal
    ; =========================================================================
    If StorageUtil.GetIntValue(akActor, "SeverActions_RecruitedViaSerana", 0) == 1
        DebugMsg("Serana DLC dismiss: " + akActor.GetDisplayName())
        DismissSerana(akActor)
        StorageUtil.UnsetIntValue(akActor, "SeverActions_RecruitedViaSerana")

    ; =========================================================================
    ; TRACKING MODE — ONLY remove our bookkeeping, touch NOTHING on the actor.
    ; Custom followers (Inigo, Lucien, etc.) manage their own AI, factions,
    ; packages, outfit, and essential status. Touching any actor state here
    ; (WaitingForPlayer, outfit lock, essential, home sandbox) can reactivate
    ; their follow packages or interfere with their mod's dismiss flow.
    ; =========================================================================
    ElseIf IsTrackOnlyFollower(akActor) || FrameworkMode == 1
        DebugMsg("Tracking mode dismiss (bookkeeping only): " + akActor.GetDisplayName())
        ; Keep outfit alias slot active so outfit lock persists after dismiss —
        ; same as SeverActions-mode. The alias stays linked so OnCellLoad can
        ; re-apply the locked outfit when the NPC loads at their home location.
        ; ClearOutfitSlot and ClearLock are NOT called here.
        If sendHome
            ApplyHomeSandboxIfHomed(akActor)
        EndIf

        If ShowNotifications
            Debug.Notification(akActor.GetDisplayName() + " is no longer being tracked.")
        EndIf

        SkyrimNetApi.RegisterShortLivedEvent("follower_dismissed_" + akActor.GetFormID(), \
            "follower_dismissed", \
            akActor.GetDisplayName() + " is no longer being tracked by " + Game.GetPlayer().GetDisplayName() + ".", \
            "", 120000, akActor, Game.GetPlayer())

        SyncFollowerRoster()
        DebugMsg("Unregistered track-only follower: " + akActor.GetDisplayName())
        Return

    ; =========================================================================
    ; SEVERACTIONS MODE — full cleanup
    ; =========================================================================
    Else
        DebugMsg("SeverActions dismiss: " + akActor.GetDisplayName())

        ; Try vanilla DialogueFollower dismiss first
        DismissViaVanillaDialogue(akActor)

        ; Manual cleanup (always — vanilla dismiss may not have run or may have failed)
        akActor.SetPlayerTeammate(false)
        akActor.IgnoreFriendlyHits(false)

        Faction currentFollowerFaction = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
        If currentFollowerFaction
            akActor.RemoveFromFaction(currentFollowerFaction)
        EndIf
        Faction playerFollowerFaction = Game.GetFormFromFile(0x084D1B, "Skyrim.esm") as Faction
        If playerFollowerFaction
            akActor.RemoveFromFaction(playerFollowerFaction)
        EndIf

        ; Restore original AI values
        Int origRelRank = StorageUtil.GetIntValue(akActor, KEY_ORIG_RELRANK, 0)
        akActor.SetRelationshipRank(Game.GetPlayer(), origRelRank)
        Float origAggression = StorageUtil.GetFloatValue(akActor, KEY_ORIG_AGGRESSION, -1.0)
        Float origConfidence = StorageUtil.GetFloatValue(akActor, KEY_ORIG_CONFIDENCE, -1.0)
        If origAggression >= 0.0
            akActor.SetAV("Aggression", origAggression)
        EndIf
        If origConfidence >= 0.0
            akActor.SetAV("Confidence", origConfidence)
        EndIf

        ; Restore original combat style form if we overrode it
        Form origCSForm = StorageUtil.GetFormValue(akActor, "SeverFollower_OrigCombatStyleForm")
        If origCSForm
            CombatStyle origCS = origCSForm as CombatStyle
            ActorBase dismissBase = akActor.GetActorBase()
            If origCS && dismissBase
                dismissBase.SetCombatStyle(origCS)
            EndIf
            StorageUtil.UnsetFormValue(akActor, "SeverFollower_OrigCombatStyleForm")
        EndIf

        ; Stop our follow package and send home
        SeverActions_Follow followSys = GetFollowScript()
        If followSys
            followSys.CompanionStopFollowing(akActor)
        EndIf
        If sendHome
            SendHome(akActor)
        EndIf
    EndIf

    ; Clear waiting state if set
    akActor.SetAV("WaitingForPlayer", 0)

    ; Restore the NPC's DefaultOutfit so they dress normally at home.
    ; The outfit lock DATA (presets, locked items) is preserved in the cosave
    ; so it can be reapplied if they're re-recruited, but the DefaultOutfit
    ; suppression must be undone or they'll appear naked on cell load.
    SeverActionsNative.Native_Outfit_ClearLock(akActor)

    If ShowNotifications
        Debug.Notification(akActor.GetDisplayName() + " is no longer your companion.")
    EndIf

    SkyrimNetApi.RegisterShortLivedEvent("follower_dismissed_" + akActor.GetFormID(), \
        "follower_dismissed", \
        akActor.GetDisplayName() + " is no longer traveling with " + Game.GetPlayer().GetDisplayName() + ".", \
        "", 120000, akActor, Game.GetPlayer())

    ; Restore essential status if we set it
    If StorageUtil.GetIntValue(akActor, "SeverActions_WasEssential", 0) == 0
        SeverActionsNative.Native_ClearEssential(akActor)
        DebugMsg("Restored non-essential for " + akActor.GetDisplayName())
    EndIf
    StorageUtil.UnsetIntValue(akActor, "SeverActions_WasEssential")
    StorageUtil.UnsetIntValue(akActor, "SeverActions_EssentialOff")

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
    ; Filter to only active followers (isFollower=true). Dismissed NPCs with homes
    ; are returned by GetDismissedWithHomes() instead.
    Actor[] nativeFollowers = SeverActionsNative.Native_GetAllTrackedFollowers()
    If nativeFollowers
        Int i = 0
        While i < nativeFollowers.Length
            If nativeFollowers[i] && nativeFollowers[i] != player && IsRegisteredFollower(nativeFollowers[i])
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

Actor[] Function GetDismissedWithHomes()
    {Get all dismissed NPCs that have an assigned home but are not active followers.
     Used by MCM to show a separate "Assigned NPCs" section.}
    Actor player = Game.GetPlayer()
    Actor[] result = PapyrusUtil.ActorArray(0)

    Actor[] tracked = SeverActionsNative.Native_GetAllTrackedFollowers()
    If tracked
        Int i = 0
        While i < tracked.Length
            If tracked[i] && tracked[i] != player && !IsRegisteredFollower(tracked[i])
                ; Dismissed but tracked — they have a home (native filter ensures this)
                result = PapyrusUtil.PushActor(result, tracked[i])
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

Function SyncAllRelationshipsOnLoad(Actor[] followers)
    {On game load, push all registered followers' StorageUtil relationship
     values into the native FollowerDataStore so PrismaUI shows correct data.
     Must run AFTER DetectExistingFollowers so all followers are registered.}
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
     Each follower has a per-NPC randomized next-eligible time (min/max range).
     Only followers in the same cell as the player are assessed.
     Picks the most overdue follower if multiple are past their threshold.}
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

    ; Track the best candidate: the follower most overdue for assessment
    Actor bestCandidate = None
    Float bestOverdue = 0.0  ; How far past their threshold (higher = more overdue)

    Int i = 0
    While i < followers.Length
        Actor follower = followers[i]
        If follower && !follower.IsDead() && follower.GetParentCell() == playerCell
            Float nextEligible = StorageUtil.GetFloatValue(follower, KEY_NEXT_ASSESS_GT, 0.0)
            ; If no next-eligible set yet, use last assess time + min cooldown as fallback
            If nextEligible == 0.0
                Float lastAssess = StorageUtil.GetFloatValue(follower, KEY_LAST_ASSESS_GT, 0.0)
                nextEligible = lastAssess + (AssessmentCooldownMinHours * SECONDS_PER_GAME_HOUR)
            EndIf

            If now >= nextEligible
                Float overdue = now - nextEligible
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
    PendingAssessmentActor = akActor
    Float nowTime = GetGameTimeInSeconds()
    StorageUtil.SetFloatValue(akActor, KEY_LAST_ASSESS_GT, nowTime)
    ; Set randomized next-eligible time for this NPC
    Float nextCooldown = Utility.RandomFloat(AssessmentCooldownMinHours, AssessmentCooldownMaxHours) * SECONDS_PER_GAME_HOUR
    StorageUtil.SetFloatValue(akActor, KEY_NEXT_ASSESS_GT, nowTime + nextCooldown)

    ; Build context JSON — start with the base
    String contextJson = "{\"npcFormId\":" + akActor.GetFormID()

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

    ; Use the stored Actor reference directly (avoids ESL FormID sign issues with Game.GetForm)
    Actor akActor = PendingAssessmentActor
    If !akActor || !IsRegisteredFollower(akActor)
        DebugMsg("Relationship assessment: actor not found or no longer a follower")
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
    String blurb = ExtractJsonString(response, "blurb")

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

    ; Store the LLM-generated relationship blurb (even if changes are 0)
    If blurb != ""
        StorageUtil.SetStringValue(akActor, "SeverFollower_PlayerBlurb", blurb)
    EndIf

    ; Skip stat changes if all zeros (no meaningful change)
    If rapportChange == 0 && trustChange == 0 && loyaltyChange == 0 && moodChange == 0
        DebugMsg(akActor.GetDisplayName() + " assessment: no change (eid " + lastEventId + ", mid " + lastMemoryId + ", did " + lastDiaryId + ")" + ", blurb=" + (blurb != ""))
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

    ; Track the best candidate: the follower most overdue for inter-assessment
    Actor bestCandidate = None
    Float bestOverdue = 0.0

    Int i = 0
    While i < followers.Length
        Actor follower = followers[i]
        If follower && !follower.IsDead()
            Float nextEligible = StorageUtil.GetFloatValue(follower, KEY_NEXT_INTER_ASSESS_GT, 0.0)
            If nextEligible == 0.0
                Float lastAssess = StorageUtil.GetFloatValue(follower, KEY_LAST_INTER_ASSESS_GT, 0.0)
                nextEligible = lastAssess + (InterFollowerCooldownMinHours * SECONDS_PER_GAME_HOUR)
            EndIf

            If now >= nextEligible
                Float overdue = now - nextEligible
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
    PendingInterAssessActor = akActor
    Float nowTime = GetGameTimeInSeconds()
    StorageUtil.SetFloatValue(akActor, KEY_LAST_INTER_ASSESS_GT, nowTime)
    ; Set randomized next-eligible time for this NPC
    Float nextCooldown = Utility.RandomFloat(InterFollowerCooldownMinHours, InterFollowerCooldownMaxHours) * SECONDS_PER_GAME_HOUR
    StorageUtil.SetFloatValue(akActor, KEY_NEXT_INTER_ASSESS_GT, nowTime + nextCooldown)

    ; Build context JSON with party member list
    ; Include npcName for name-based resolution in callback (avoids light-plugin FormID issues)
    String npcName = akActor.GetDisplayName()
    String contextJson = "{\"npcFormId\":" + akActor.GetFormID() + ",\"npcName\":\"" + npcName + "\""

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
            akActor = Game.GetFormEx(srcFormId) as Actor
        EndIf
    EndIf

    ; Fallback 2: Try stored Actor reference directly (avoids ESL FormID sign issues)
    If !akActor
        akActor = PendingInterAssessActor
    EndIf

    If !akActor || !IsRegisteredFollower(akActor)
        DebugMsg("Inter-follower assessment: assessor not found (name=" + assessorName + ")")
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

String Function WrapPersistentEvent(String line)
    {Wrap a plain string into JSON for SkyrimNet persistent_generic event schema.
     persistent_generic is persistent (custom has 60s TTL) and does not trigger
     NPC reactions (custom does). Schema field is line:String.}
    Return "{\"line\":\"" + line + "\"}"
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

Function RebuildCompanionOpinionsStringCached(Actor akActor, Actor[] followers)
    {Same as RebuildCompanionOpinionsString but accepts a pre-built followers array
     to avoid redundant GetAllFollowers() cell scans during bulk init.}
    If !akActor
        Return
    EndIf

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

Function RebuildAllCompanionOpinions(Actor[] followers)
    {Rebuild the companion opinions string for every active follower on game load.
     StorageUtil strings don't persist reliably across save/load, but the individual
     Affinity/Respect float values do. This ensures the prompt template always has
     current data without waiting for the next inter-follower assessment cycle.}
    Int i = 0
    While i < followers.Length
        If followers[i]
            RebuildCompanionOpinionsStringCached(followers[i], followers)
        EndIf
        i += 1
    EndWhile
    DebugMsg("Rebuilt companion opinions strings for " + followers.Length + " followers")
EndFunction

Function SyncFollowerRoster(Actor[] followers = None)
    {Update the comma-separated roster string in StorageUtil for prompt template access.
     Called on recruit, dismiss, and game load. Pass cached array to avoid redundant cell scan.}
    If !followers
        followers = GetAllFollowers()
    EndIf
    If !followers
        Return
    EndIf
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

Function SyncAllPairRelationshipsOnLoad(Actor[] followers)
    {Called from Maintenance on game load. Syncs inter-follower pair data from
     StorageUtil to native FollowerDataStore for PrismaUI display.}
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
; FOLLOWER BANTER
; =============================================================================

Function CheckFollowerBanter()
    {Game-time based banter check. Called from OnUpdate every 30s.
     Only gated by its own BanterInProgress flag and game-time cooldown —
     NOT blocked by assessment or off-screen life flags.}

    ; Check game-time cooldown
    Float now = GetGameTimeInSeconds()
    Float nextEligible = StorageUtil.GetFloatValue(None, KEY_NEXT_BANTER_GT, 0.0)
    If nextEligible > 0.0 && now < nextEligible
        Return
    EndIf

    ; Skip if in combat
    Actor player = Game.GetPlayer()
    If player.IsInCombat()
        Return
    EndIf

    ; Collect followers in player's cell
    Actor[] followers = GetAllFollowers()
    Cell playerCell = player.GetParentCell()
    Actor[] eligible = new Actor[10]
    Int eligibleCount = 0

    Int i = 0
    While i < followers.Length && eligibleCount < 10
        Actor fol = followers[i]
        If fol && !fol.IsDead() && !fol.IsInCombat() && fol.GetParentCell() == playerCell
            eligible[eligibleCount] = fol
            eligibleCount += 1
        EndIf
        i += 1
    EndWhile

    If eligibleCount < 2
        Return
    EndIf

    Debug.Notification("[Banter] Checking " + eligibleCount + " followers...")
    FireFollowerBanter(eligible, eligibleCount)
EndFunction

Function FireFollowerBanter(Actor[] eligible, Int count)
    {Send the banter director prompt to the LLM with all eligible follower pairs.
     Builds context JSON with follower data and pair relationship data.}
    BanterInProgress = true

    ; Set cooldown immediately so we don't re-fire
    Float now = GetGameTimeInSeconds()
    StorageUtil.SetFloatValue(None, KEY_LAST_BANTER_GT, now)
    Float nextCooldown = Utility.RandomFloat(BanterCooldownMinHours, BanterCooldownMaxHours) * SECONDS_PER_GAME_HOUR
    StorageUtil.SetFloatValue(None, KEY_NEXT_BANTER_GT, now + nextCooldown)

    ; Build followers array in context JSON
    String contextJson = "{\"followers\":["
    Int i = 0
    While i < count
        Actor fol = eligible[i]
        If i > 0
            contextJson += ","
        EndIf
        Float folMood = StorageUtil.GetFloatValue(fol, "SeverFollower_Mood", 50.0)
        String folStyle = StorageUtil.GetStringValue(fol, "SeverFollower_CombatStyle", "no combat style")
        contextJson += "{\"formId\":" + fol.GetFormID()
        contextJson += ",\"name\":\"" + fol.GetDisplayName() + "\""
        contextJson += ",\"mood\":" + (folMood as Int)
        contextJson += ",\"combatStyle\":\"" + folStyle + "\"}"
        i += 1
    EndWhile
    contextJson += "]"

    ; Build pairs array — all combinations of eligible followers
    contextJson += ",\"pairs\":["
    Bool firstPair = true
    i = 0
    While i < count
        Int j = i + 1
        While j < count
            Actor a = eligible[i]
            Actor b = eligible[j]
            If a && b
                Float affinityAB = SeverActionsNative.Native_GetPairAffinity(a, b)
                Float respectAB = SeverActionsNative.Native_GetPairRespect(a, b)
                Float affinityBA = SeverActionsNative.Native_GetPairAffinity(b, a)
                Float respectBA = SeverActionsNative.Native_GetPairRespect(b, a)
                String blurbAB = StorageUtil.GetStringValue(a, "SeverFollower_Blurb_" + b.GetFormID(), "")
                String blurbBA = StorageUtil.GetStringValue(b, "SeverFollower_Blurb_" + a.GetFormID(), "")

                If !firstPair
                    contextJson += ","
                EndIf
                contextJson += "{\"nameA\":\"" + a.GetDisplayName() + "\""
                contextJson += ",\"nameB\":\"" + b.GetDisplayName() + "\""
                contextJson += ",\"affinityAB\":" + (affinityAB as Int)
                contextJson += ",\"respectAB\":" + (respectAB as Int)
                contextJson += ",\"affinityBA\":" + (affinityBA as Int)
                contextJson += ",\"respectBA\":" + (respectBA as Int)
                contextJson += ",\"blurbAB\":\"" + blurbAB + "\""
                contextJson += ",\"blurbBA\":\"" + blurbBA + "\"}"
                firstPair = false
            EndIf
            j += 1
        EndWhile
        i += 1
    EndWhile
    contextJson += "]}"

    Int result = SkyrimNetApi.SendCustomPromptToLLM("sever_follower_banter", "", contextJson, \
        Self as Quest, "SeverActions_FollowerManager", "OnFollowerBanter")

    If result < 0
        BanterInProgress = false
        Debug.Notification("[Banter] LLM call failed (code " + result + ")")
    EndIf
EndFunction

Function OnFollowerBanter(String response, Int success)
    {Callback from SendCustomPromptToLLM for banter director.
     If the LLM selected a pair, fires a gamemaster_dialogue event to trigger
     SkyrimNet's dialogue pipeline between the two companions.
     Always reschedules the banter loop at the end.}
    BanterInProgress = false

    If success != 1
        Debug.Notification("[Banter] LLM call failed")
        Return
    EndIf

    ; Check if LLM chose no banter (the ~60% case)
    If StringUtil.Find(response, "\"banter\":null") >= 0 || StringUtil.Find(response, "\"banter\": null") >= 0
        Debug.Notification("[Banter] LLM chose silence this cycle")
        Return
    EndIf

    ; Extract speaker, target, topic from nested banter object
    String speakerName = ExtractJsonString(response, "speaker")
    String targetName = ExtractJsonString(response, "target")
    String banterTopic = ExtractJsonString(response, "topic")

    If speakerName == "" || targetName == ""
        Debug.Notification("[Banter] Bad LLM response — missing names")
        Return
    EndIf

    ; Resolve names to Actors
    Actor[] followers = GetAllFollowers()
    Actor speakerActor = ResolveFollowerByName(speakerName, followers)
    Actor targetActor = ResolveFollowerByName(targetName, followers)

    If !speakerActor || !targetActor
        Debug.Notification("[Banter] Can't find " + speakerName + " or " + targetName)
        Return
    EndIf

    ; Fire as gamemaster_dialogue — SkyrimNet routes this to DialogueManager which
    ; generates a response from the speaker to the target. The topic is embedded in
    ; the dialogue field so it appears in the event context the NPC sees.
    String topicDirection = banterTopic
    If topicDirection == ""
        topicDirection = "casual conversation"
    EndIf
    ; Use ContinueConversation format with isContinuation + topic fields.
    ; SkyrimNet's DialogueManager processes these and the topic becomes visible
    ; in the NPC's event context for dialogue generation.
    String eventJson = "{\"speaker\":\"" + speakerName + "\",\"target\":\"" + targetName + "\",\"topic\":\"" + topicDirection + "\",\"isContinuation\":true,\"dialogue\":\"" + speakerName + " turns to " + targetName + " — " + topicDirection + "\"}"

    SkyrimNetApi.RegisterEvent("gamemaster_dialogue", eventJson, speakerActor, targetActor)

    Debug.Notification("[Banter] " + speakerName + " -> " + targetName + ": " + banterTopic)

EndFunction

; =============================================================================
; OFF-SCREEN LIFE EVENTS
; =============================================================================

Function CheckOffScreenLifeEvents()
    {Check if any dismissed follower with a home is due for an off-screen life event.
     Fires at most ONE event per tick to avoid flooding the LLM queue.
     Targets dismissed followers (not active) who have an assigned home.
     Each follower has a per-NPC randomized next-eligible time (min/max range).}
    If OffScreenLifeInProgress
        Return
    EndIf

    ; Get all tracked followers from native cosave (includes dismissed with homes)
    Actor[] allTracked = SeverActionsNative.Native_GetAllTrackedFollowers()
    If !allTracked || allTracked.Length == 0
        Return
    EndIf

    Float now = GetGameTimeInSeconds()
    Float gracePeriodSeconds = OffScreenGracePeriodHours * SECONDS_PER_GAME_HOUR
    Cell playerCell = Game.GetPlayer().GetParentCell()

    ; Track the best candidate: the dismissed follower most overdue for a life event
    Actor bestCandidate = None
    Float bestOverdue = 0.0

    Int i = 0
    While i < allTracked.Length
        Actor follower = allTracked[i]
        If follower && !follower.IsDead() && !IsRegisteredFollower(follower)
            ; Skip if player is in the same cell — immersion-breaking to generate
            ; off-screen life events for NPCs the player can literally see
            Bool skipFollower = false
            If playerCell && follower.GetParentCell() == playerCell
                skipFollower = true
            EndIf

            ; Grace period: skip if dismissed too recently
            If !skipFollower
                Float dismissTime = StorageUtil.GetFloatValue(follower, KEY_DISMISS_GT, 0.0)
                If dismissTime > 0.0 && (now - dismissTime) < gracePeriodSeconds
                    skipFollower = true
                EndIf
            EndIf

            If !skipFollower
                String home = SeverActionsNative.Native_GetHome(follower)
                If home != ""
                    If StorageUtil.GetIntValue(follower, KEY_OFFSCREEN_EXCLUDED, 0) == 0
                        Float nextEligible = StorageUtil.GetFloatValue(follower, KEY_NEXT_LIFE_EVENT_GT, 0.0)
                        ; If no next-eligible set yet, use last event time + min cooldown as fallback
                        If nextEligible == 0.0
                            Float lastEvent = StorageUtil.GetFloatValue(follower, KEY_LAST_LIFE_EVENT_GT, 0.0)
                            nextEligible = lastEvent + (OffScreenLifeCooldownMinHours * SECONDS_PER_GAME_HOUR)
                        EndIf

                        If now >= nextEligible
                            Float overdue = now - nextEligible
                            If !bestCandidate || overdue > bestOverdue
                                bestCandidate = follower
                                bestOverdue = overdue
                            EndIf
                        EndIf
                    EndIf
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile

    ; Fire off-screen life event for the most overdue follower (if any)
    If bestCandidate
        FireOffScreenLifeEvent(bestCandidate)
    EndIf
EndFunction

Function FireOffScreenLifeEvent(Actor akActor)
    {Send the off-screen life prompt to the LLM for a dismissed follower.
     Generates 1-2 believable daily events based on personality, home, and history.
     Context JSON is built natively in C++ for proper JSON serialization and performance.}
    OffScreenLifeInProgress = true
    PendingOffScreenLifeActor = akActor
    Float nowTime = GetGameTimeInSeconds()
    StorageUtil.SetFloatValue(akActor, KEY_LAST_LIFE_EVENT_GT, nowTime)
    ; Set randomized next-eligible time for this NPC
    Float nextCooldown = Utility.RandomFloat(OffScreenLifeCooldownMinHours, OffScreenLifeCooldownMaxHours) * SECONDS_PER_GAME_HOUR
    StorageUtil.SetFloatValue(akActor, KEY_NEXT_LIFE_EVENT_GT, nowTime + nextCooldown)

    ; Build context JSON natively — reads home from FollowerDataStore, queries
    ; social graph from PublicAPI, finds nearby dismissed followers, checks consequences
    Float lastConsequence = StorageUtil.GetFloatValue(akActor, KEY_LAST_CONSEQUENCE_GT, 0.0)
    Float consequenceCooldown = ConsequenceCooldownHours * SECONDS_PER_GAME_HOUR

    String contextJson = SeverActionsNative.Native_OffScreen_BuildContext(akActor, \
        OffScreenConsequences, consequenceCooldown, lastConsequence, nowTime)

    If contextJson == ""
        OffScreenLifeInProgress = false
        DebugMsg("Off-screen life: native context build failed for " + akActor.GetDisplayName())
        Return
    EndIf

    Int result = SkyrimNetApi.SendCustomPromptToLLM("sever_offscreen_life", "", contextJson, \
        Self as Quest, "SeverActions_FollowerManager", "OnOffScreenLifeEvent")

    If result < 0
        OffScreenLifeInProgress = false
        DebugMsg("Off-screen life LLM call failed for " + akActor.GetDisplayName() + ", code " + result)
    Else
        String home = SeverActionsNative.Native_GetHome(akActor)
        DebugMsg("Off-screen life event queued for " + akActor.GetDisplayName() + " at " + home)
    EndIf
EndFunction

Function OnOffScreenLifeEvent(String response, Int success)
    {Callback from SendCustomPromptToLLM. Uses native C++ JSON parser to extract events,
     then handles persistent event registration, gossip, consequences, and diary.
     Native parser stores events directly in OffScreenLifeDataStore (cosave-persisted).}
    OffScreenLifeInProgress = false

    If success != 1
        DebugMsg("Off-screen life LLM failed: " + response)
        Return
    EndIf

    ; Use the stored Actor reference directly (avoids ESL FormID sign issues with Game.GetForm)
    Actor akActor = PendingOffScreenLifeActor
    If !akActor
        DebugMsg("Off-screen life: actor reference is None")
        Return
    EndIf

    ; If they were re-recruited while the LLM was processing, skip
    If IsRegisteredFollower(akActor)
        DebugMsg("Off-screen life: " + akActor.GetDisplayName() + " was re-recruited, skipping")
        Return
    EndIf

    String actorName = akActor.GetDisplayName()
    String home = SeverActionsNative.Native_GetHome(akActor)
    Float currentGameTime = GetGameTimeInSeconds()

    ; === Native JSON parsing — replaces fragile Papyrus string parsing ===
    ; C++ parses with nlohmann::json, stores events in native data store, returns
    ; pipe-delimited: summary1|type1|gossip1|summary2|type2|gossip2|
    ;   conseqAction|conseqAmount|conseqReason|conseqCrime|
    ;   conseqItem|conseqCategory|conseqCount|involved|diary
    String parsed = SeverActionsNative.Native_OffScreen_ParseLLMResponse(akActor, response, currentGameTime)
    If parsed == ""
        DebugMsg("Off-screen life: native parser returned empty for " + actorName)
        Return
    EndIf

    ; Extract fields by pipe position (15 fields, indices 0-14)
    String summary1 = PipeField(parsed, 0)
    String type1    = PipeField(parsed, 1)
    Bool gossip1    = PipeField(parsed, 2) == "1"
    String summary2 = PipeField(parsed, 3)
    String type2    = PipeField(parsed, 4)
    Bool gossip2    = PipeField(parsed, 5) == "1"

    If summary1 == ""
        DebugMsg("Off-screen life: no events parsed from response for " + actorName)
        Return
    EndIf

    ; Build the life summary (stored on the actor for the dialogue submodule prompt)
    String lifeSummary = summary1
    If summary2 != ""
        lifeSummary += " " + summary2
    EndIf
    StorageUtil.SetStringValue(akActor, KEY_LIFE_SUMMARY, lifeSummary)

    ; Randomize survival needs for dismissed followers after each off-screen event.
    ; Simulates eating, resting, and exposure while the player was away.
    ; Values drift randomly — sometimes they ate well, sometimes they didn't.
    If !SeverActionsNative.Native_Survival_IsExcluded(akActor)
        Int newHunger = Utility.RandomInt(5, 45)
        Int newFatigue = Utility.RandomInt(5, 50)
        Int newCold = Utility.RandomInt(0, 20)
        SeverActionsNative.Native_Survival_SetNeeds(akActor, newHunger as Float, newFatigue as Float, newCold as Float)
        DebugMsg("Off-screen life: randomized survival for " + actorName + " H=" + newHunger + " F=" + newFatigue + " C=" + newCold)
    EndIf

    ; Build full event history from native cosave store for prompt injection
    ; This gives dismissed followers a rich memory of what they've been doing
    String eventHistory = SeverActionsNative.Native_OffScreen_GetRecentLifeEvents(akActor, 10, currentGameTime)
    If eventHistory != ""
        StorageUtil.SetStringValue(akActor, "SeverFollower_LifeEventHistory", eventHistory)
    EndIf

    ; Register as persistent events so the follower "remembers" them
    SkyrimNetApi.RegisterEvent("persistent_generic", WrapPersistentEvent(actorName + ": " + summary1), akActor, None)
    If summary2 != ""
        SkyrimNetApi.RegisterEvent("persistent_generic", WrapPersistentEvent(actorName + ": " + summary2), akActor, None)
    EndIf

    ; Note: SkyrimNet memories for the primary actor are now created directly in C++
    ; (inside Native_OffScreen_ParseLLMResponse) to bypass BSFixedString garbling
    ; that occurred when long summaries were routed through Papyrus pipe parsing.

    ; Store gossip for the home location (ring buffer of last 3)
    If gossip1 && home != ""
        AppendGossip(home, actorName + " " + summary1)
        SeverActionsNative.Native_OffScreen_AddGossip(home, actorName + " " + summary1, currentGameTime)
    EndIf
    If gossip2 && summary2 != "" && home != ""
        AppendGossip(home, actorName + " " + summary2)
        SeverActionsNative.Native_OffScreen_AddGossip(home, actorName + " " + summary2, currentGameTime)
    EndIf

    ; --- Process consequences ---
    If OffScreenConsequences
        String conseqAction = PipeField(parsed, 6)
        If conseqAction != ""
            Int conseqAmount    = PipeField(parsed, 7) as Int
            String conseqReason = PipeField(parsed, 8)
            String conseqCrime  = PipeField(parsed, 9)

            If conseqAction == "item_acquired"
                String itemName = PipeField(parsed, 10)
                String itemCat  = PipeField(parsed, 11)
                Int itemCount   = PipeField(parsed, 12) as Int
                If itemCount <= 0
                    itemCount = 1
                EndIf
                ProcessOffScreenConsequence(akActor, home, conseqAction, itemCount, itemName, itemCat)
            Else
                ProcessOffScreenConsequence(akActor, home, conseqAction, conseqAmount, conseqReason, conseqCrime)
            EndIf
        EndIf
    EndIf

    ; --- Process involved NPCs for shared events ---
    ; Extract involved field and validate it's a clean name (no pipe remnants)
    String involvedStr = PipeField(parsed, 13)
    ; Strip any leading/trailing whitespace
    involvedStr = SeverActionsNative.TrimString(involvedStr)
    If involvedStr != "" && StringUtil.GetLength(involvedStr) >= 3 && StringUtil.Find(involvedStr, "|") < 0 && StringUtil.Find(involvedStr, "0") != 0 && StringUtil.Find(involvedStr, "{") < 0
        ; involvedStr is comma-separated names
        Int commaPos = StringUtil.Find(involvedStr, ",")
        Int searchFrom = 0
        While searchFrom < StringUtil.GetLength(involvedStr)
            String involvedName = ""
            If commaPos >= 0
                involvedName = SeverActionsNative.TrimString(StringUtil.Substring(involvedStr, searchFrom, commaPos - searchFrom))
                searchFrom = commaPos + 1
                commaPos = StringUtil.Find(involvedStr, ",", searchFrom)
            Else
                involvedName = SeverActionsNative.TrimString(StringUtil.Substring(involvedStr, searchFrom))
                searchFrom = StringUtil.GetLength(involvedStr) ; exit loop
            EndIf

            ; Extra validation: name must be 3+ chars, no pipes, no leading zeros, no brackets
            If involvedName != "" && StringUtil.GetLength(involvedName) >= 3 && StringUtil.Find(involvedName, "|") < 0 && StringUtil.Find(involvedName, "0") != 0 && StringUtil.Find(involvedName, "[") < 0
                Actor involvedActor = SeverActionsNative.FindActorByName(involvedName)
                If involvedActor && involvedActor != akActor
                    SkyrimNetApi.RegisterEvent("persistent_generic", WrapPersistentEvent(involvedName + ": " + summary1), involvedActor, akActor)
                    If summary2 != ""
                        SkyrimNetApi.RegisterEvent("persistent_generic", WrapPersistentEvent(involvedName + ": " + summary2), involvedActor, akActor)
                    EndIf
                    ; Note: SkyrimNet memories for involved actors are now created in C++
                    ; (inside Native_OffScreen_ParseLLMResponse) to bypass BSFixedString issues.
                    If gossip1 && home != ""
                        AppendGossip(home, actorName + " and " + involvedName + " were seen together in " + home)
                    EndIf
                    DebugMsg("Off-screen life: shared event + memory registered for " + involvedName)
                EndIf
            EndIf
        EndWhile
    EndIf

    ; Check if diary generation was requested
    If PipeField(parsed, 14) == "1"
        SkyrimNetApi.GenerateDiaryEntry(akActor)
        DebugMsg("Off-screen life: diary entry requested for " + actorName)
    EndIf

    If ShowNotifications
        Debug.Notification(actorName + " has been busy at " + home + ".")
    EndIf

    DebugMsg("Off-screen life: " + actorName + " → " + lifeSummary)
EndFunction

String Function PipeField(String data, Int fieldIndex)
    {Extract a field from a pipe-delimited string by index (0-based).
     Returns empty string if index is out of range.}
    Int pos = 0
    Int fieldNum = 0
    Int dataLen = StringUtil.GetLength(data)

    While fieldNum < fieldIndex && pos < dataLen
        Int pipePos = StringUtil.Find(data, "|", pos)
        If pipePos < 0
            Return "" ; not enough fields
        EndIf
        pos = pipePos + 1
        fieldNum += 1
    EndWhile

    If pos >= dataLen
        Return ""
    EndIf

    Int nextPipe = StringUtil.Find(data, "|", pos)
    If nextPipe < 0
        Return StringUtil.Substring(data, pos)
    EndIf
    Return StringUtil.Substring(data, pos, nextPipe - pos)
EndFunction

Function AppendGossip(String locationName, String gossipText)
    {Append a gossip item to a location's gossip ring buffer (max 3 items).
     Stored in StorageUtil as pipe-delimited strings keyed by location name.
     Old items are dropped when new ones are added beyond the limit.}
    String gossipKey = "SeverGossip_" + locationName
    String existing = StorageUtil.GetStringValue(None, gossipKey, "")

    If existing == ""
        StorageUtil.SetStringValue(None, gossipKey, gossipText)
        Return
    EndIf

    ; Count existing items (pipe-delimited)
    Int count = 1
    Int searchPos = 0
    Int pipePos = StringUtil.Find(existing, "|", searchPos)
    While pipePos >= 0
        count += 1
        searchPos = pipePos + 1
        pipePos = StringUtil.Find(existing, "|", searchPos)
    EndWhile

    If count >= 3
        ; Drop the oldest (first) item
        Int firstPipe = StringUtil.Find(existing, "|")
        If firstPipe >= 0
            existing = StringUtil.Substring(existing, firstPipe + 1)
        Else
            existing = ""
        EndIf
    EndIf

    If existing != ""
        StorageUtil.SetStringValue(None, gossipKey, existing + "|" + gossipText)
    Else
        StorageUtil.SetStringValue(None, gossipKey, gossipText)
    EndIf
EndFunction

Bool Function IsOffScreenExcluded(Actor akActor)
    {Check if a follower is excluded from off-screen life events.}
    Return StorageUtil.GetIntValue(akActor, KEY_OFFSCREEN_EXCLUDED, 0) == 1
EndFunction

Function SetOffScreenExcluded(Actor akActor, Bool excluded)
    {Set or clear the off-screen life exclusion flag for a follower.}
    If excluded
        StorageUtil.SetIntValue(akActor, KEY_OFFSCREEN_EXCLUDED, 1)
    Else
        StorageUtil.UnsetIntValue(akActor, KEY_OFFSCREEN_EXCLUDED)
    EndIf
EndFunction

Function ToggleOffScreenExcluded(Actor akActor)
    {Toggle the off-screen life exclusion flag for a follower.}
    If IsOffScreenExcluded(akActor)
        SetOffScreenExcluded(akActor, false)
    Else
        SetOffScreenExcluded(akActor, true)
    EndIf
EndFunction

; =============================================================================
; OFF-SCREEN CONSEQUENCES (Phase 2a)
; =============================================================================

Actor[] Function GetDismissedFollowersInHold(String holdName)
    {Find all dismissed followers whose home location matches a given hold/location.
     Used to populate nearby follower context for shared events.
     Returns actors whose home contains the holdName as a substring.}
    Actor[] result = new Actor[10]
    Int resultCount = 0

    If holdName == ""
        Return result
    EndIf

    Actor[] allTracked = SeverActionsNative.Native_GetAllTrackedFollowers()
    If !allTracked || allTracked.Length == 0
        Return result
    EndIf

    Int i = 0
    While i < allTracked.Length && resultCount < 10
        Actor follower = allTracked[i]
        If follower && !follower.IsDead() && !IsRegisteredFollower(follower)
            String followerHome = SeverActionsNative.Native_GetHome(follower)
            If followerHome != ""
                ; Substring match — e.g., "Whiterun" matches "Whiterun Breezehome"
                If StringUtil.Find(followerHome, holdName) >= 0 || StringUtil.Find(holdName, followerHome) >= 0
                    If StorageUtil.GetIntValue(follower, KEY_OFFSCREEN_EXCLUDED, 0) == 0
                        result[resultCount] = follower
                        resultCount += 1
                    EndIf
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile

    ; Trim to actual count
    If resultCount == 0
        Return new Actor[1]
    EndIf
    Return result
EndFunction

Actor Function FindFollowerByName(String targetName)
    {Find any tracked follower by display name. Searches all tracked followers
     (active and dismissed). Uses ResolveFollowerByName with substring fallback.}
    If targetName == ""
        Return None
    EndIf
    Actor[] allTracked = SeverActionsNative.Native_GetAllTrackedFollowers()
    If !allTracked || allTracked.Length == 0
        Return None
    EndIf
    Return ResolveFollowerByName(targetName, allTracked)
EndFunction

Faction Function GetCrimeFactionForHoldName(String holdName)
    {Map a location/hold name string to its crime faction for bounty assignment.
     Uses substring matching to handle variations like "Riften", "The Rift", etc.}
    If !ArrestScript || holdName == ""
        Return None
    EndIf

    If StringUtil.Find(holdName, "Whiterun") >= 0
        Return ArrestScript.CrimeFactionWhiterun
    ElseIf StringUtil.Find(holdName, "Riften") >= 0 || StringUtil.Find(holdName, "Rift") >= 0
        Return ArrestScript.CrimeFactionRift
    ElseIf StringUtil.Find(holdName, "Solitude") >= 0 || StringUtil.Find(holdName, "Haafingar") >= 0
        Return ArrestScript.CrimeFactionHaafingar
    ElseIf StringUtil.Find(holdName, "Windhelm") >= 0 || StringUtil.Find(holdName, "Eastmarch") >= 0
        Return ArrestScript.CrimeFactionEastmarch
    ElseIf StringUtil.Find(holdName, "Markarth") >= 0 || StringUtil.Find(holdName, "Reach") >= 0
        Return ArrestScript.CrimeFactionReach
    ElseIf StringUtil.Find(holdName, "Falkreath") >= 0
        Return ArrestScript.CrimeFactionFalkreath
    ElseIf StringUtil.Find(holdName, "Dawnstar") >= 0 || StringUtil.Find(holdName, "Pale") >= 0
        Return ArrestScript.CrimeFactionPale
    ElseIf StringUtil.Find(holdName, "Morthal") >= 0 || StringUtil.Find(holdName, "Hjaalmarch") >= 0
        Return ArrestScript.CrimeFactionHjaalmarch
    ElseIf StringUtil.Find(holdName, "Winterhold") >= 0
        Return ArrestScript.CrimeFactionWinterhold
    EndIf

    Return None
EndFunction

Function ProcessOffScreenConsequence(Actor akActor, String home, String conseqType, Int amount, String reason, String crime)
    {Dispatch an off-screen consequence to the appropriate system.
     Routes arrest, gold_change, and debt actions. Fails silently if systems unavailable.}
    String actorName = akActor.GetDisplayName()

    If conseqType == "arrest"
        ProcessOffScreenArrest(akActor, home, crime, amount)
    ElseIf conseqType == "gold_change"
        ProcessOffScreenGoldChange(akActor, amount, reason)
    ElseIf conseqType == "debt"
        ProcessOffScreenDebt(akActor, amount, reason)
    ElseIf conseqType == "bounty"
        ; Bounty without arrest — wanted but not caught
        ProcessOffScreenBounty(akActor, home, crime, amount)
    ElseIf conseqType == "item_acquired"
        ; Item acquisition — uses native fuzzy resolver
        ProcessOffScreenItemAcquired(akActor, reason, crime, amount)
    Else
        DebugMsg("Off-screen consequence: unknown type '" + conseqType + "' for " + actorName)
        Return
    EndIf

    ; Stamp consequence cooldown
    StorageUtil.SetFloatValue(akActor, KEY_LAST_CONSEQUENCE_GT, GetGameTimeInSeconds())
EndFunction

Function ProcessOffScreenArrest(Actor akActor, String home, String crime, Int bounty)
    {Apply arrest consequence to a dismissed follower.
     Stores bounty, registers event, and physically places the NPC in jail
     using the ArrestScript's jail infrastructure (marker, outfit, faction, tracking).}
    String actorName = akActor.GetDisplayName()

    If bounty <= 0
        bounty = 100
    EndIf

    ; Cap against cumulative maximum
    Int currentTotal = StorageUtil.GetIntValue(akActor, KEY_OFFSCREEN_BOUNTY_TOTAL, 0)
    If currentTotal + bounty > MaxOffScreenBounty
        bounty = MaxOffScreenBounty - currentTotal
        If bounty <= 0
            DebugMsg("Off-screen arrest: " + actorName + " at bounty cap (" + MaxOffScreenBounty + "), skipping")
            Return
        EndIf
    EndIf

    ; Update cumulative bounty
    StorageUtil.SetIntValue(akActor, KEY_OFFSCREEN_BOUNTY_TOTAL, currentTotal + bounty)

    String crimeStr = crime
    If crimeStr == ""
        crimeStr = "a minor offense"
    EndIf

    DebugMsg("Off-screen arrest: " + actorName + " +" + bounty + " bounty for " + crimeStr + " in " + home)

    ; Register as memorable event
    SkyrimNetApi.RegisterEvent("persistent_generic", WrapPersistentEvent(actorName + " was arrested for " + crimeStr + " in " + home + " and has a " + (currentTotal + bounty) + " gold bounty."), akActor, None)

    ; Add to gossip
    AppendGossip(home, actorName + " was arrested for " + crimeStr + "!")

    ; Write to native store for PrismaUI
    SeverActionsNative.Native_OffScreen_IncrementBounty(akActor, bounty)
    SeverActionsNative.Native_OffScreen_IncrementArrestCount(akActor)
    SeverActionsNative.Native_OffScreen_AddEvent(akActor, actorName + " was arrested for " + crimeStr + " in " + home, "significant", GetGameTimeInSeconds(), true, "arrest", bounty, crimeStr, "")

    ; ── Physical jail placement ──
    ; Uses ArrestScript's infrastructure: jail marker, outfit, faction, sandbox package.
    ; Simplified from OnArrivedAtJail() — no guard escort needed for off-screen arrest.
    If ArrestScript
        ; Check if already jailed
        If ArrestScript.IsNPCJailed(akActor)
            DebugMsg("Off-screen arrest: " + actorName + " is already jailed, skipping placement")
        Else
            ; Resolve crime faction from home location → jail marker
            Faction crimeFaction = GetCrimeFactionForHoldName(home)
            If crimeFaction
                ObjectReference jailMarker = SeverActionsNative.GetFactionJailMarker(crimeFaction)
                If jailMarker
                    ; Add to Jailed faction
                    akActor.AddToFaction(ArrestScript.SeverActions_Jailed)

                    ; Teleport to jail — use Disable/Enable for cross-cell reliability
                    akActor.Disable()
                    Utility.Wait(0.1)
                    akActor.MoveTo(jailMarker, 0.0, 0.0, 0.0)
                    Utility.Wait(0.1)
                    akActor.Enable()

                    ; Change to jail clothes (faction outfit or fallback)
                    ArrestScript.ChangeToJailClothes(akActor, crimeFaction)

                    ; Track via ArrestScript's jailed NPC list
                    ArrestScript.AddJailedNPC(akActor)
                    StorageUtil.SetFormValue(akActor, "SeverActions_JailMarker", jailMarker)

                    ; Apply sandbox package so they pace around the cell
                    If ArrestScript.SeverActions_PrisonerSandBox && jailMarker
                        SeverActionsNative.LinkedRef_Set(akActor, jailMarker, ArrestScript.SeverActions_SandboxAnchorKW)
                        ActorUtil.AddPackageOverride(akActor, ArrestScript.SeverActions_PrisonerSandBox, 110, 1)
                        akActor.EvaluatePackage()
                    EndIf

                    ; Register persistent event for SkyrimNet
                    SkyrimNetApi.RegisterPersistentEvent(actorName + " has been jailed in " + home + ".", akActor, None)

                    DebugMsg("Off-screen arrest: " + actorName + " placed in jail at " + home)
                Else
                    DebugMsg("Off-screen arrest: no jail marker found for " + home + " — arrest recorded but NPC not moved")
                EndIf
            Else
                DebugMsg("Off-screen arrest: no crime faction found for '" + home + "' — arrest recorded but NPC not moved")
            EndIf
        EndIf
    Else
        DebugMsg("Off-screen arrest: ArrestScript not available — arrest recorded but NPC not moved")
    EndIf

    If ShowNotifications
        Debug.Notification(actorName + " was arrested in " + home + "! (" + bounty + " bounty)")
    EndIf
EndFunction

Function ProcessOffScreenBounty(Actor akActor, String home, String crime, Int bounty)
    {Apply bounty without arrest — wanted but not yet caught.}
    String actorName = akActor.GetDisplayName()

    If bounty <= 0
        bounty = 50
    EndIf

    ; Cap against cumulative maximum
    Int currentTotal = StorageUtil.GetIntValue(akActor, KEY_OFFSCREEN_BOUNTY_TOTAL, 0)
    If currentTotal + bounty > MaxOffScreenBounty
        bounty = MaxOffScreenBounty - currentTotal
        If bounty <= 0
            Return
        EndIf
    EndIf

    StorageUtil.SetIntValue(akActor, KEY_OFFSCREEN_BOUNTY_TOTAL, currentTotal + bounty)

    String crimeStr = crime
    If crimeStr == ""
        crimeStr = "suspicious activity"
    EndIf
    SkyrimNetApi.RegisterEvent("persistent_generic", WrapPersistentEvent(actorName + " is wanted for " + crimeStr + " in " + home + "."), akActor, None)

    ; Write to native store
    SeverActionsNative.Native_OffScreen_IncrementBounty(akActor, bounty)
    SeverActionsNative.Native_OffScreen_AddEvent(akActor, actorName + " is wanted for " + crimeStr + " in " + home, "notable", GetGameTimeInSeconds(), true, "bounty", bounty, crimeStr, "")

    DebugMsg("Off-screen bounty: " + actorName + " +" + bounty + " for " + crimeStr + " in " + home)
EndFunction

Function ProcessOffScreenGoldChange(Actor akActor, Int amount, String reason)
    {Apply gold gain or loss to a dismissed follower's inventory.
     Caps at MaxOffScreenGoldChange. Cannot reduce below 0 gold.}
    String actorName = akActor.GetDisplayName()

    ; Cap magnitude
    If amount > MaxOffScreenGoldChange
        amount = MaxOffScreenGoldChange
    ElseIf amount < 0 && (0 - amount) > MaxOffScreenGoldChange
        amount = 0 - MaxOffScreenGoldChange
    EndIf

    Form goldForm = Game.GetFormFromFile(0x0000000F, "Skyrim.esm")
    If !goldForm
        Return
    EndIf

    If amount > 0
        akActor.AddItem(goldForm, amount, true)
        SkyrimNetApi.RegisterEvent("persistent_generic", WrapPersistentEvent(actorName + " earned " + amount + " gold from " + reason + "."), akActor, None)
        SeverActionsNative.Native_OffScreen_IncrementGoldEarned(akActor, amount)
        SeverActionsNative.Native_OffScreen_AddEvent(akActor, actorName + " earned " + amount + " gold from " + reason, "notable", GetGameTimeInSeconds(), true, "gold_change", amount, "", "")
        DebugMsg("Off-screen gold: " + actorName + " +" + amount + "g (" + reason + ")")
    ElseIf amount < 0
        Int toRemove = 0 - amount
        Int currentGold = akActor.GetItemCount(goldForm)
        If toRemove > currentGold
            toRemove = currentGold
        EndIf
        If toRemove > 0
            akActor.RemoveItem(goldForm, toRemove, true)
            SkyrimNetApi.RegisterEvent("persistent_generic", WrapPersistentEvent(actorName + " lost " + toRemove + " gold due to " + reason + "."), akActor, None)
            SeverActionsNative.Native_OffScreen_IncrementGoldLost(akActor, toRemove)
            SeverActionsNative.Native_OffScreen_AddEvent(akActor, actorName + " lost " + toRemove + " gold due to " + reason, "notable", GetGameTimeInSeconds(), true, "gold_change", 0 - toRemove, "", "")
            DebugMsg("Off-screen gold: " + actorName + " -" + toRemove + "g (" + reason + ")")
        EndIf
    EndIf
EndFunction

Function ProcessOffScreenDebt(Actor akActor, Int amount, String reason)
    {Track debt from off-screen events. Simple StorageUtil accumulator.
     Proper Debt system integration (with creditor actors) is Phase 2b.}
    String actorName = akActor.GetDisplayName()

    If amount <= 0
        Return
    EndIf

    ; Cap
    If amount > MaxOffScreenGoldChange
        amount = MaxOffScreenGoldChange
    EndIf

    Int currentDebt = StorageUtil.GetIntValue(akActor, KEY_OFFSCREEN_DEBT, 0)
    StorageUtil.SetIntValue(akActor, KEY_OFFSCREEN_DEBT, currentDebt + amount)

    SkyrimNetApi.RegisterEvent("persistent_generic", WrapPersistentEvent(actorName + " incurred a debt of " + amount + " gold for " + reason + "."), akActor, None)

    ; Write to native store
    SeverActionsNative.Native_OffScreen_IncrementDebt(akActor, amount)
    SeverActionsNative.Native_OffScreen_AddEvent(akActor, actorName + " incurred " + amount + " gold debt for " + reason, "notable", GetGameTimeInSeconds(), true, "debt", amount, "", "")

    If ShowNotifications
        Debug.Notification(actorName + " took on " + amount + " gold in debt.")
    EndIf

    DebugMsg("Off-screen debt: " + actorName + " +" + amount + "g (" + reason + ")")
EndFunction

Function ProcessOffScreenItemAcquired(Actor akActor, String itemName, String category, Int count)
    {Give an item to a dismissed follower via native fuzzy name resolver.
     Called from off-screen consequence parsing. item_acquired consequence uses:
     reason=item name, crime=category, amount=count (repurposed in dispatch).}
    String actorName = akActor.GetDisplayName()

    If itemName == "" || count <= 0
        DebugMsg("Off-screen item: invalid params for " + actorName + " (item='" + itemName + "', count=" + count + ")")
        Return
    EndIf

    ; Cap count to prevent abuse
    If count > 5
        count = 5
    EndIf

    ; Default category to "any" if not specified
    If category == ""
        category = "any"
    EndIf

    ; Resolve and give via native item resolver (fuzzy 4-stage lookup)
    String resolvedName = SeverActionsNative.Native_ResolveItemName(itemName, category)
    If resolvedName == ""
        DebugMsg("Off-screen item: could not resolve '" + itemName + "' (category: " + category + ") for " + actorName)
        Return
    EndIf

    Bool success = SeverActionsNative.Native_GiveItemByName(akActor, itemName, category, count)
    If !success
        DebugMsg("Off-screen item: failed to give '" + itemName + "' to " + actorName)
        Return
    EndIf

    ; Register event
    String eventDesc = actorName + " acquired " + count + "x " + resolvedName
    SkyrimNetApi.RegisterEvent("persistent_generic", WrapPersistentEvent(eventDesc + "."), akActor, None)

    ; Write to native store for PrismaUI
    SeverActionsNative.Native_OffScreen_AddEvent(akActor, eventDesc, "notable", GetGameTimeInSeconds(), true, "item_acquired", count, itemName, category)

    If ShowNotifications
        Debug.Notification(actorName + " acquired " + count + "x " + resolvedName)
    EndIf

    DebugMsg("Off-screen item: " + actorName + " +" + count + "x " + resolvedName + " (searched: '" + itemName + "', cat: " + category + ")")
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

                ; Re-assign alias immediately — but only apply sandbox if not actively following.
                ; Active followers keep following; the sandbox activates on dismiss via
                ; SendHome/ApplyHomeSandboxIfHomed. For already-dismissed NPCs, apply now
                ; to prevent FF package gap.
                If !IsRegisteredFollower(akActor)
                    ApplyHomeSandbox(akActor, homeMarker, slot)
                Else
                    ; Just assign the alias (for OnCellLoad events) without activating sandbox
                    HomeSlots[slot].ForceRefTo(akActor)
                EndIf

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

    ; For track-only followers (Inigo, Lucien, etc.), the alias package alone
    ; can't beat their own NPC-record packages. Add a high-priority PO3 override
    ; to force our sandbox above their entire package stack.
    If IsTrackOnlyFollower(akActor)
        Package homePkg = GetHomeSandboxPackage(slot)
        If homePkg
            ActorUtil.AddPackageOverride(akActor, homePkg, 100, 1)
            DebugMsg("ApplyHomeSandbox: Added PO3 override (priority 100) for track-only " + akActor.GetDisplayName())
        EndIf
    EndIf

    ; Set WaitingForPlayer=2 (relax/sandbox) so custom follower package systems
    ; don't fight our sandbox with their "return to home cell" packages.
    akActor.SetAV("WaitingForPlayer", 2)

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
        ; Remove PO3 override if one was added for track-only followers
        Package homePkg = GetHomeSandboxPackage(slot)
        If homePkg
            ActorUtil.RemovePackageOverride(akActor, homePkg)
        EndIf
        HomeSlots[slot].Clear()
        DebugMsg("Cleared " + akActor.GetDisplayName() + " from HomeSlot_" + slot)
    EndIf

    ; Reset WaitingForPlayer to 0 (follow) so custom follower packages resume
    ; their normal follow behavior after home sandbox is removed
    akActor.SetAV("WaitingForPlayer", 0)

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
    {Set follower's combat style. Maps style names to actual CombatStyle forms.
     "no combat style" restores the original. All others override the ActorBase record.}
    If !akActor
        Return
    EndIf

    String normalized = SeverActionsNative.StringToLower(style)
    SeverActionsNative.Native_SetCombatStyle(akActor, normalized)
    StorageUtil.SetStringValue(akActor, KEY_COMBAT_STYLE, normalized)

    ApplyCombatStyleValues(akActor, normalized)

    If ShowNotifications
        If normalized == "no combat style"
            Debug.Notification(akActor.GetDisplayName() + " reverted to their natural combat style.")
        Else
            Debug.Notification(akActor.GetDisplayName() + " will now fight as a " + style + ".")
        EndIf
    EndIf

    DebugMsg("Combat style set for " + akActor.GetDisplayName() + ": " + normalized)
EndFunction

Function ApplyCombatStyleValues(Actor akActor, String style)
    {Override the ActorBase CombatStyle form and set appropriate actor values.
     Maps our named styles to vanilla CombatStyle FormIDs from Skyrim.esm.}
    If !akActor
        Return
    EndIf

    ActorBase npcBase = akActor.GetActorBase()
    If !npcBase
        Return
    EndIf

    ; Save original combat style form on first call (for restoration on dismiss)
    If !StorageUtil.HasFormValue(akActor, "SeverFollower_OrigCombatStyleForm")
        CombatStyle origCS = npcBase.GetCombatStyle()
        If origCS
            StorageUtil.SetFormValue(akActor, "SeverFollower_OrigCombatStyleForm", origCS)
        EndIf
    EndIf

    ; "no combat style" = restore original, don't override
    If style == "no combat style" || style == ""
        Form origForm = StorageUtil.GetFormValue(akActor, "SeverFollower_OrigCombatStyleForm")
        If origForm
            CombatStyle origCS = origForm as CombatStyle
            If origCS
                npcBase.SetCombatStyle(origCS)
            EndIf
        EndIf
        Return
    EndIf

    ; Map style name to vanilla CombatStyle FormID
    Int csFormID = 0
    If style == "melee"
        csFormID = 0x000F1EB5       ; csHumanMelee1H
    ElseIf style == "berserker"
        csFormID = 0x00016E25       ; csAlikrBerserker (dual-wield capable)
    ElseIf style == "tank"
        csFormID = 0x0003CF5A       ; csHumanTankLvl1
    ElseIf style == "archer"
        csFormID = 0x0003BE1D       ; csHumanMissile
    ElseIf style == "mage"
        csFormID = 0x0003BE1C       ; csHumanMagic
    ElseIf style == "spellsword"
        csFormID = 0x00107812       ; csSpellsword
    ElseIf style == "battlemage"
        csFormID = 0x001034F0       ; csWEBattlemage
    ElseIf style == "champion"
        csFormID = 0x0003DECE       ; csHumanBoss1H
    ElseIf style == "brawler"
        csFormID = 0x0010555D       ; csWEBrawler
    ElseIf style == "companion"
        csFormID = 0x00103508       ; csWECompanion
    ; Legacy support for old style names
    ElseIf style == "aggressive"
        csFormID = 0x00016E25       ; csAlikrBerserker (dual-wield capable)
    ElseIf style == "defensive" || style == "healer"
        csFormID = 0x0003CF5A       ; csHumanTankLvl1
    ElseIf style == "balanced"
        csFormID = 0x00103508       ; csWECompanion
    ElseIf style == "ranged"
        csFormID = 0x0003BE1D       ; csHumanMissile
    EndIf

    If csFormID > 0
        CombatStyle newCS = Game.GetFormFromFile(csFormID, "Skyrim.esm") as CombatStyle
        If newCS
            npcBase.SetCombatStyle(newCS)
        EndIf
    EndIf

    ; Set actor values based on style archetype
    If style == "berserker" || style == "champion" || style == "aggressive"
        akActor.SetAV("Confidence", 4) ; Foolhardy
        akActor.SetAV("Aggression", 1) ; Aggressive
    ElseIf style == "tank" || style == "defensive" || style == "healer"
        akActor.SetAV("Confidence", 3) ; Brave
        akActor.SetAV("Aggression", 1) ; Aggressive
    ElseIf style == "mage" || style == "battlemage"
        akActor.SetAV("Confidence", 3) ; Brave
        akActor.SetAV("Aggression", 1) ; Aggressive
    Else ; melee, archer, spellsword, brawler, companion, balanced, ranged
        akActor.SetAV("Confidence", 3) ; Brave
        akActor.SetAV("Aggression", 1) ; Aggressive
    EndIf
EndFunction

Function ReapplyCombatStyles(Actor[] followers)
    {Re-apply combat style actor values for all registered followers.
     StorageUtil strings persist across save/load, but the actor value
     effects (Confidence, Aggression) may be reverted by NFF/EFF restoring
     their own saved values, or by the dismiss/recruit cycle.
     Called from Maintenance() on every game load.}
    Int i = 0
    While i < followers.Length
        If followers[i]
            String style = GetCombatStyle(followers[i])
            If style != "no combat style" && style != "balanced"
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
                    Else
                        ; Already in alias — re-set WaitingForPlayer=2 in case the
                        ; follower's own OnInit reset it (Inigo forces -1 on load
                        ; if !IsPlayerTeammate, overriding our sandbox state)
                        akActor.SetAV("WaitingForPlayer", 2)

                        ; Re-apply PO3 override for track-only followers — PO3
                        ; overrides don't persist across save/load
                        If IsTrackOnlyFollower(akActor)
                            Package homePkg = GetHomeSandboxPackage(slot)
                            If homePkg
                                ActorUtil.AddPackageOverride(akActor, homePkg, 100, 1)
                                akActor.EvaluatePackage()
                            EndIf
                        EndIf
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

Function PatchUpVanillaFollowerStatus(Actor[] followers)
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
    Int i = 0
    While i < followers.Length
        Actor follower = followers[i]
        If follower
            ; Only force CurrentFollowerFaction for SeverActions-managed followers.
            ; Track-only followers (Inigo, Lucien, etc.) have their own CFF management
            ; — some mods keep CFF rank -1 at all times. Don't touch it.
            ; The is_sever_follower() decorator handles prompt template detection.
            If !IsTrackOnlyFollower(follower)
                If !follower.IsInFaction(currentFollowerFaction) || follower.GetFactionRank(currentFollowerFaction) < 0
                    follower.AddToFaction(currentFollowerFaction)
                    follower.SetFactionRank(currentFollowerFaction, 0)
                    DebugMsg("Patched CurrentFollowerFaction for " + follower.GetDisplayName())
                EndIf
            EndIf

            ; Only patch relationship rank for SeverActions Mode followers
            ; Tracking Mode followers manage their own relationship ranks
            If !IsTrackOnlyFollower(follower) && FrameworkMode == 0
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
        Return "no combat style"
    EndIf
    ; Prefer native cosave (reliable), fallback to StorageUtil (legacy)
    String nativeStyle = SeverActionsNative.Native_GetCombatStyle(akActor)
    If nativeStyle != ""
        ; Migrate old "balanced" to new default
        If nativeStyle == "balanced"
            Return "no combat style"
        EndIf
        Return nativeStyle
    EndIf
    String stored = StorageUtil.GetStringValue(akActor, KEY_COMBAT_STYLE, "no combat style")
    If stored == "balanced"
        Return "no combat style"
    EndIf
    Return stored
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

; =============================================================================
; QUEST AWARENESS — LLM Summary Generation (Queue-Based)
; C++ QuestAwarenessStore detects quest stage changes via TESQuestStageEvent,
; builds JSON context with proper escaping, and queues requests.
; Papyrus pops one item at a time — no busy-wait, no JSON building.
; =============================================================================

Event OnQuestSummaryReady(String eventName, String strArg, Float numArg, Form sender)
    {Fired by C++ when the summary request queue has new items.
     Drains the queue one at a time via callback chaining.}
    If QuestAwarenessInProgress
        Return  ; Already processing — callback will drain the queue
    EndIf
    ProcessNextSummaryRequest()
EndEvent

Function ProcessNextSummaryRequest()
    {Pop the next request from C++ queue and send to LLM.
     C++ stashes the actor/quest/tier metadata — no JSON parsing needed here.}
    String contextJson = SeverActionsNative.Native_PopSummaryRequest()
    If contextJson == ""
        DebugMsg("Quest awareness: summary queue drained")
        Return  ; Queue empty
    EndIf

    QuestAwarenessInProgress = true

    Int result = SkyrimNetApi.SendCustomPromptToLLM("sever_quest_awareness", "", contextJson, \
        Self as Quest, "SeverActions_FollowerManager", "OnQuestSummaryGenerated")

    If result < 0
        QuestAwarenessInProgress = false
        DebugMsg("Quest awareness: LLM call failed, continuing queue")
        ProcessNextSummaryRequest()
    EndIf
EndFunction

Function OnQuestSummaryGenerated(String response, Int success)
    {Callback from SendCustomPromptToLLM. C++ handles all storage via stashed metadata.}
    QuestAwarenessInProgress = false

    If success == 1
        ; Pass response to C++ for storage in QuestAwarenessStore
        SeverActionsNative.Native_StorePendingSummary(response)
        DebugMsg("Quest awareness: summary stored (" + response + ")")
    Else
        DebugMsg("Quest awareness: LLM summary failed: " + response)
    EndIf

    ; Process next item in queue (callback chaining)
    ProcessNextSummaryRequest()
EndFunction

Event OnQuestCompletedEvent(String eventName, String strArg, Float numArg, Form sender)
    {Fired by C++ when a tracked quest is completed. strArg = quest editorID.
     C++ already collected completion entries before marking completed.
     We drain the completion queue and create memories for each follower.}

    DebugMsg("Quest awareness: quest completed — " + strArg)

    ; Drain the completion queue
    String entryJson = SeverActionsNative.Native_PopCompletionEntry()
    While entryJson != ""
        ; Parse the JSON: {"actorFormID":N,"editorID":"...","summary":"...","isFirsthand":bool}
        Int fidStart = StringUtil.Find(entryJson, "\"actorFormID\":")
        Int fidVal = 0
        If fidStart >= 0
            String sub = StringUtil.Substring(entryJson, fidStart + 14)
            Int commaPos = StringUtil.Find(sub, ",")
            If commaPos > 0
                fidVal = StringUtil.Substring(sub, 0, commaPos) as Int
            EndIf
        EndIf

        Int sumStart = StringUtil.Find(entryJson, "\"summary\":\"")
        String summary = ""
        If sumStart >= 0
            String sub = StringUtil.Substring(entryJson, sumStart + 11)
            Int quotePos = StringUtil.Find(sub, "\"")
            If quotePos > 0
                summary = StringUtil.Substring(sub, 0, quotePos)
            EndIf
        EndIf

        Bool isFirsthand = StringUtil.Find(entryJson, "\"isFirsthand\":true") >= 0

        Actor akFollower = Game.GetForm(fidVal) as Actor
        If akFollower && summary != ""
            Float importance = 0.4
            String memType = "KNOWLEDGE"
            If isFirsthand
                importance = 0.7
                memType = "EXPERIENCE"
            EndIf

            SeverActionsNative.Native_AddMemory(akFollower, summary, importance, \
                memType, "", "", "[\"quest\"]", "[]")

            DebugMsg("Quest awareness: created " + memType + " memory for " + akFollower.GetDisplayName())
        EndIf

        entryJson = SeverActionsNative.Native_PopCompletionEntry()
    EndWhile
EndEvent

; =============================================================================
; UTILITY FUNCTIONS
; =============================================================================

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
