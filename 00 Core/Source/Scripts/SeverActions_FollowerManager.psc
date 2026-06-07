Scriptname SeverActions_FollowerManager extends Quest

{
    SkyrimNet-Native Follower Framework for SeverActions

    Central manager for the follower roster, relationship tracking,
    home assignments, combat style preferences, and relationship decay.

    Replaces traditional follower menus with SkyrimNet's LLM-driven
    conversation - followers are recruited, dismissed, and managed
    through natural dialogue instead of static menu options.

    Follower framework integration:
    - SeverActions manages its own roster, relationships, outfits, home,
      and packages via the SeverActions_ActivelyFollowing faction and its
      own alias slots. Recruitment routes through the vanilla
      DialogueFollowerScript when NFF is not installed.
    - Nether's Follower Framework (NFF): SeverActions does NOT route
      recruitment/dismissal through NFF. If a user runs NFF, the two
      systems co-exist, and the user is expected to keep SeverActions in
      Tracking Only mode for any NPC NFF actively manages. NFF presence
      is still detected via HasNFF() and HasNFFIgnoreToken() so we can
      skip vanilla alias routing and respect NFF's ignore-token signal
      that an NPC has its own custom-AI system.
    - DLC followers (Serana) are routed through their own mental-model
      quest so we don't double-manage their package state.

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

Int Property TeleportCooldownSeconds = 30 Auto
{Global cooldown between catch-up teleports. Applied across all followers, not
per-follower. Read by SandboxManager at boot via SyncFromPluginConfig so the
PrismaUI-set value persists across game restarts.}

Bool Property ShowFollowerContext = true Auto
{When true, the follower relationship/behavior prompt (0175) is included in NPC bios.
When false, the section is skipped — useful for users who prefer vanilla-style companions.}

String Property NearbyExcludedTags = "" Auto
{Comma-separated "type:subtype" tags to exclude from the Nearby Objects prompt
section (0180_severactions_nearbyref). Examples: "furniture:bed,furniture:seat,item:weapon".
Unioned at prompt-render time with the hardcoded defaults (clutter, misc).
Mirrored to StorageUtil(None, "SeverActions_NearbyExcluded") on init/load so
the prompt template can read it via the papyrus_util decorator. Empty = use
defaults only.}

Float Property UIScale = 1.5 Auto
{PrismaUI scale factor. Source of truth for both MCM and the in-Prisma
slider. Mirrored to StorageUtil(None, "SeverActions_UIScale") on init/
load. Range 0.7–2.0. The PrismaUI dashboard gatherer emits this on every
page-data fetch and the frontend applies it on receive, so MCM changes
take effect the next time the player opens PrismaUI.}

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

; --- Healer combat-style configuration (synced to native HealerPoll) ---

Float Property HealerPlayerThreshold = 0.65 Auto
{Health-percent at which a healer-style follower will heal the player.
Range 0.0-0.95. Set 0 to disable player healing. Synced to native.}

Float Property HealerSelfThreshold = 0.65 Auto
{Health-percent at which a healer-style follower will self-heal.
Range 0.0-0.95. Set 0 to disable self-heal. Synced to native.}

Float Property HealerAllyThreshold = 0.65 Auto
{Health-percent at which a healer-style follower will heal another teammate.
Range 0.0-0.95. Set 0 to disable ally healing. Synced to native.}

Float Property HealerMult = 1.0 Auto
{Multiplier on the bonus-heal magnitude (Restoration*0.2 + Level + 74).
Range 0.05-2.0. 50% halves heals, 200% doubles them. Synced to native.}

Int Property HealerChance = 75 Auto
{Per-tick attempt chance (0-100). Each ~1s tick, the poll rolls this %; on
fail it skips entirely. Lower values feel more "human" but slower to react.}

Int Property HealerTargetCooldownMs = 4000 Auto
{Per-target heal cooldown in milliseconds. Same target won't be re-healed by
ANY healer within this window — prevents spam in multi-healer parties.}

Int Property HealerCastCooldownMs = 1500 Auto
{Per-healer cast cooldown in milliseconds. Minimum gap between casts from
the same healer.}

Int Property HealerVoiceCooldownMs = 30000 Auto
{Per-healer voice-line cooldown in milliseconds. Default 30s prevents long
fights from devolving into "I'll heal you!" spam.}

Bool Property HealerBleedoutCheatHeal = true Auto
{When true, a healer-style follower entering bleedout is auto-restored to
half max HP (60-second game-time cooldown). Disable for harder gameplay.}

CombatStyle Property HealerCombatStyleForm Auto
{Optional custom CSTY for healer-mode followers. If left unfilled, healer-mode
falls back to vanilla csHumanMagic (0x0003BE1C) — biases AI toward magic/staff.
Attach a SeverActions-authored CSTY here in CK (e.g. SeverActions_HealerCombatStyle)
to use your own weights. The native HealerPoll force-casts heals on top regardless
of CSTY, so this only affects "what AI picks when poll isn't firing" — primarily
the actor's positioning and any non-heal spells they cast.}

; --- Cell-catchup configuration (synced to native CellCatchup) ---

Bool Property CellCatchupEnabled = true Auto
{Master toggle for reliable follower-through-load-door catch-up. When true,
followers stranded after a cell load are auto-MoveTo'd to the player.}

Int Property CellCatchupGracePeriodMs = 1500 Auto
{Milliseconds to wait after a cell load before catching up. Lets vanilla
teleport-on-cell-load try first. Lower = more aggressive, may double-teleport.}

Int Property CellCatchupMaxFollowers = 8 Auto
{Maximum followers caught up per cell-load event. Prevents slideshow with
huge rosters. Default 8 covers normal multi-follower setups.}

Float Property CellCatchupOffsetRadius = 100.0 Auto
{XY offset radius (units) when dropping followers near the player. Prevents
pile-up when multiple catch up at the same door.}

Float Property BanterCooldownMinHours = 2.0 Auto
{Minimum game hours between follower banter opportunities.}

Float Property BanterCooldownMaxHours = 5.0 Auto
{Maximum game hours between follower banter opportunities.}

Bool Property AutoAmbientBanter = true Auto
{Enable spontaneous NPC-to-NPC conversations among non-follower NPCs nearby.
When true, an ambient banter director periodically picks a pair of nearby
non-follower NPCs and triggers a brief exchange so populated areas feel alive
without the player having to initiate every interaction. Hostile cells (any
loaded actor hostile to the player — dungeons, bandit camps, under-attack
settlements) are skipped automatically.}

Float Property AmbientBanterCooldownMinHours = 3.0 Auto
{Minimum game hours between ambient NPC banter opportunities.}

Float Property AmbientBanterCooldownMaxHours = 7.0 Auto
{Maximum game hours between ambient NPC banter opportunities.}

Int Property QuestAwarenessOutputCap = 5 Auto
{Maximum number of quest awareness entries emitted to the prompt per follower.
Storage cap (per-follower max retained quests) is unaffected — this only
controls how many entries the LLM sees per render. Range 1-15, default 5.}

Bool Property AutoQuestAwareness = true Auto
{Enable LLM-generated personalized quest awareness summaries when quests advance.
When false, quest stage events still fire (for storage / inter-follower banter)
but no SendCustomPromptToLLM("sever_quest_awareness") calls are made.
Auto-disabled by C++ if the sever_quest_awareness.prompt file is missing.}

Bool Property AutoNPCReputation = true Auto
{Enable LLM-generated NPC reputation/familiarity blurbs when a non-follower NPC's
familiarity tier changes. When false, the C++ player_familiarity decorator still
tracks tiers but no SendCustomPromptToLLM("sever_reputation_assess") calls are
made — the character_bio template just shows the tier without the LLM blurb.
Auto-disabled by C++ if the sever_reputation_assess.prompt file is missing.}

Bool Property AutoOffScreenLife = true Auto
{Enable off-screen life event generation for dismissed followers with homes.
When true, dismissed followers generate believable daily events that become
memories and gossip. They'll naturally mention what happened when you return.}

Float Property OffScreenLifeCooldownMinHours = 10.0 Auto
{Minimum game hours between off-screen life event generation per dismissed follower.}

Float Property OffScreenLifeCooldownMaxHours = 72.0 Auto
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

; ── Essential alias pool ──────────────────────────────────────────────
; 40 ReferenceAlias slots flagged "Essential" on this quest (alias IDs
; 218-257). Filling a slot makes the held actor essential at the REFERENCE
; level — works on templated/generic NPCs and applies live, unlike the
; ActorBase kEssential flag (which the engine ignores for templated actors
; and applies unreliably mid-session). Resolved by alias ID at runtime
; (see EnsureEssentialSlots) rather than via a fragile ReferenceAlias[] fill.
Int Property EssentialSlotFirstID = 218 Auto
{Alias ID of the first Essential slot. The pool is contiguous from here.}
Int Property EssentialSlotCount = 40 Auto
{Number of Essential slots (the simultaneous-essential cap).}
ReferenceAlias[] EssentialSlots   ; built lazily from GetAlias()

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

FormList Property TrueHomeAnchorList Auto
{FormList of 40 TrueHomeAnchor XMarkers. Moved to player position on AssignHome.
 Acts as the "return home" anchor during sleep/home hours. HomeMarker_NN moves
 between this anchor and Work/PlayMarker_NN based on the current game hour.}

FormList Property WorkMarkerList Auto
{FormList of 40 WorkMarker XMarkers. Moved to player position via SetRoutineLocHere(actor, "work").
 During work hours (8-17) HomeMarker_NN is moved to this position so the existing
 HomeSandbox_NN package drives sandbox behavior at the work location.}

FormList Property PlayMarkerList Auto
{FormList of 40 PlayMarker XMarkers. Same pattern as WorkMarkerList for play hours (17-22).}

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
String Property KEY_COMBAT_STYLE = "SeverFollower_CombatStyle" AutoReadOnly
String Property KEY_LAST_INTERACTION = "SeverFollower_LastInteraction" AutoReadOnly

; Morality key (snapshot of vanilla Morality AV for prompt context)
String Property KEY_MORALITY = "SeverFollower_Morality" AutoReadOnly

; Keys for saving/restoring original AI values (vanilla path only)
String Property KEY_ORIG_AGGRESSION = "SeverFollower_OrigAggression" AutoReadOnly
String Property KEY_ORIG_CONFIDENCE = "SeverFollower_OrigConfidence" AutoReadOnly
String Property KEY_ORIG_RELRANK = "SeverFollower_OrigRelRank" AutoReadOnly

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
String Property KEY_LAST_AMBIENT_GT = "SeverActions_LastAmbientGT" AutoReadOnly
String Property KEY_NEXT_AMBIENT_GT = "SeverActions_NextAmbientGT" AutoReadOnly

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

; Schedule system — tracks the last-applied schedule type per NPC so ProcessScheduleSwaps
; only moves HomeMarker when the hour crosses a schedule boundary.
; Values: 0=home, 1=work, 2=play, -99=never evaluated.
String Property KEY_LAST_SCHEDULED_TYPE = "SeverFollower_LastScheduledType" AutoReadOnly

; One-shot migration flag per NPC: ensures TrueHomeAnchor_NN is synced to HomeMarker_NN's
; position before any schedule logic runs. Critical for existing saves where HomeMarker
; was placed at the real home, but the new TrueHomeAnchor marker loaded at its default
; position in aaaMarkers holding cell. Without migration, the first schedule tick would
; teleport the follower to the holding cell. Set to 1 on AssignHome or first tick.
String Property KEY_TRUEHOME_MIGRATED = "SeverFollower_TrueHomeMigrated" AutoReadOnly

Int Property SCHEDULE_HOME = 0 AutoReadOnly
Int Property SCHEDULE_WORK = 1 AutoReadOnly
Int Property SCHEDULE_PLAY = 2 AutoReadOnly

Float Property SCHEDULE_WORK_START = 8.0 Auto
Float Property SCHEDULE_WORK_END = 17.0 Auto
Float Property SCHEDULE_PLAY_START = 17.0 Auto
Float Property SCHEDULE_PLAY_END = 22.0 Auto

; =============================================================================
; INTERNAL STATE
; =============================================================================

Float LastTickTime
Bool IsUpdating = false

; Phase 2 perf — Maintenance() defers its per-follower passes (cell scans,
; outfit-slot reassignment, faction patch-ups, relationship sync, etc.) into
; the next OnUpdate tick instead of running them inline. SeverActions_Init's
; Initialize() chain returns ~20 seconds sooner, the "SeverActions loaded"
; notification appears when PrismaUI is actually ready, and the heavy passes
; run 100ms later on the Papyrus VM's own schedule. OnUpdate's top branch
; consumes this flag, runs RunDeferredMaintenance(), then restarts the
; normal 30s tick cadence.
Bool DeferredMaintenancePending = false

; Vanilla dismiss detection — delayed confirmation to filter temporary mod toggles.
; Multiple followers can be flagged for removal within a 2.5s window (mass-dismiss,
; cell-unload). A single slot silently drops all but the last; this fixed-size queue
; (32 slots > MaxFollowers=20 with headroom) preserves every pending removal until
; OnUpdate drains them.
Actor[] PendingDismissQueue
Int PendingDismissCount = 0

; Relationship assessment tracking — only one assessment in flight at a time
; Store Actor references directly to avoid ESL FormID sign issues with Game.GetForm()
Actor PendingAssessmentActor = None
Bool AssessmentInProgress = false

; Inter-follower assessment tracking — separate from player-centric assessment
Actor PendingInterAssessActor = None
Bool InterFollowerAssessmentInProgress = false

; Follower banter tracking — lowest priority LLM system
Bool BanterInProgress = false

; Ambient NPC banter tracking — independent of follower banter so both can
; cycle without blocking each other. Separate cooldown (3-7 game hours).
Bool AmbientBanterInProgress = false

; Off-screen life event tracking — separate from both assessment types
Actor PendingOffScreenLifeActor = None
Bool OffScreenLifeInProgress = false
; Watchdog: real-time seconds when InProgress was set. If the C++
; SeverActions_OffScreenLifeReady ModEvent gets dropped (early reg miss,
; ThreadPool→game-thread loss, native dispatch error), the flag stays
; true forever and blocks every future off-screen life event. OnUpdate
; clears it after a generous timeout.
Float OffScreenLifeStartedRT = 0.0

; Quest awareness tracking — legacy Papyrus pump (SkyrimNet < v8 fallback).
; v8+ users dispatch via SkyrimNetBridge in C++ and never enter this path.
; CurrentSummaryContextJson stashes the popped context across the
; SendCustomPromptToLLM round-trip so the callback can route the response
; back to the correct (actor, quest) without a C++ FIFO stash that could
; desync on early returns.
Bool QuestAwarenessInProgress = false
String CurrentSummaryContextJson = ""

; Reputation assessment tracking — fires on familiarity tier milestones for non-followers
; C++ player_familiarity decorator detects tier changes and fires SeverActions_ReputationAssess
Actor PendingReputationActor = None
Bool ReputationAssessInProgress = false

; Phase 4C cosave v7→v8 migration sentinel. Set to 1 after the first Maintenance
; tick that backfills lastInteractionSec from StorageUtil(KEY_LAST_INTERACTION).
; Stored as a script-instance Int so it persists in the save with the manager
; quest — no cosave hook needed.
Int InteractionTimeMigrationDone = 0

; Phase 5b cosave v8→v9 migration sentinel. Set to 1 after the first Maintenance
; tick that backfills playerBlurb from StorageUtil(SeverFollower_PlayerBlurb).
Int PlayerBlurbMigrationDone = 0

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
    ; OnPlayerLoadGame ModEvent registration removed — see comment on the
    ; deleted handler below. SeverActions_Init.psc → Maintenance() is the
    ; single coverage path for the post-load essential re-apply.

    If !PendingDismissQueue
        PendingDismissQueue = new Actor[32]
    EndIf

    ; Phase 4C one-shot: copy StorageUtil(KEY_LAST_INTERACTION) into
    ; FollowerData.lastInteractionSec for every tracked follower. Runs once per
    ; save (gated by InteractionTimeMigrationDone). After this, KEY_LAST_INTERACTION
    ; is only kept around so PurgeFollower's legacy-cleanup block can unset it.
    If InteractionTimeMigrationDone == 0
        Actor[] tracked = SeverActionsNative.Native_GetAllTrackedFollowers()
        Int migrated = 0
        If tracked
            Int m = 0
            While m < tracked.Length
                Actor a = tracked[m]
                If a && SeverActionsNativeExt.Native_GetInteractionTime(a) <= 0.0 \
                    && StorageUtil.HasFloatValue(a, KEY_LAST_INTERACTION)
                    SeverActionsNativeExt.Native_SetInteractionTime(a, \
                        StorageUtil.GetFloatValue(a, KEY_LAST_INTERACTION, 0.0))
                    migrated += 1
                EndIf
                m += 1
            EndWhile
        EndIf
        InteractionTimeMigrationDone = 1
        Debug.Trace("[SeverActions_FollowerManager] Phase 4C migration: backfilled " \
            + migrated + " lastInteractionSec entries from StorageUtil")
    EndIf

    ; Phase 5b one-shot: copy StorageUtil(SeverFollower_PlayerBlurb) into the
    ; native FollowerData.playerBlurb field for every tracked follower. Runs
    ; once per save (gated by PlayerBlurbMigrationDone). After this, the
    ; StorageUtil mirror is only kept transitionally — assessment callback
    ; writes both for one release while any prompt still reads the legacy key.
    If PlayerBlurbMigrationDone == 0
        Actor[] trackedB = SeverActionsNative.Native_GetAllTrackedFollowers()
        Int migratedB = 0
        If trackedB
            Int b = 0
            While b < trackedB.Length
                Actor a = trackedB[b]
                If a && SeverActionsNativeExt.Native_GetPlayerBlurb(a) == "" \
                    && StorageUtil.HasStringValue(a, "SeverFollower_PlayerBlurb")
                    SeverActionsNativeExt.Native_SetPlayerBlurb(a, \
                        StorageUtil.GetStringValue(a, "SeverFollower_PlayerBlurb", ""))
                    migratedB += 1
                EndIf
                b += 1
            EndWhile
        EndIf
        PlayerBlurbMigrationDone = 1
        Debug.Trace("[SeverActions_FollowerManager] Phase 5b migration: backfilled " \
            + migratedB + " playerBlurb entries from StorageUtil")
    EndIf

    ; Push healer config to native HealerPoll. Done here so each game load
    ; restores the user's MCM/PrismaUI tunings even though the native poll's
    ; in-memory config is reset on plugin reload.
    SyncHealerConfig()

    ; Push cell-catchup config to native CellCatchup. Same reasoning —
    ; the native subsystem's config resets on plugin reload, so we
    ; re-push the user's tunings every game start.
    SyncCellCatchupConfig()

    ; Mirror NearbyExcludedTags property → StorageUtil(None) so the
    ; nearby-ref prompt template can read it via papyrus_util decorator.
    ; Runs on cold-start and every load so the prompt-side cache stays
    ; in sync with the cosaved property.
    SyncNearbyExcludedToStorageUtil()

    ; UIScale safety net — defend against the property being uninitialized
    ; on existing saves loaded after this patch landed. Papyrus's auto-
    ; property default-application isn't guaranteed when a property is
    ; added to a script that already has live instances in a save. Without
    ; this, the gatherer would emit 0.0 → frontend clamps to MIN_SCALE
    ; (0.7) → Prisma renders tiny on first open. Range guard handles any
    ; other out-of-range value too.
    If UIScale <= 0.0 || UIScale > 5.0
        UIScale = 1.5
    EndIf

    ; Mirror UIScale property → StorageUtil(None) for parity with the
    ; NearbyExcludedTags pattern. Frontend doesn't need this — it reads
    ; via the page-data gatherer — but the mirror keeps things consistent.
    SyncUIScaleToStorageUtil()

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
    RegisterForModEvent("SeverActions_PrismaCompanionWait", "OnPrismaCompanionWait")
    RegisterForModEvent("SeverActions_PrismaCompanionFollow", "OnPrismaCompanionFollow")
    RegisterForModEvent("SeverActions_PrismaCompanionWaitAll", "OnPrismaCompanionWaitAll")
    RegisterForModEvent("SeverActions_PrismaCompanionFollowAll", "OnPrismaCompanionFollowAll")
    RegisterForModEvent("SeverActions_SetCombatStyle", "OnPrismaSetCombatStyle")
    RegisterForModEvent("SeverActions_SetEssential", "OnPrismaSetEssential")
    RegisterForModEvent("SeverActions_SetNearbyExcluded", "OnPrismaSetNearbyExcluded")
    RegisterForModEvent("SeverActions_SetUIScale", "OnPrismaSetUIScale")

    ; Schedule system — PrismaUI work/play location assignment
    RegisterForModEvent("SeverActions_PrismaSetWorkLoc", "OnPrismaSetWorkLoc")
    RegisterForModEvent("SeverActions_PrismaClearWorkLoc", "OnPrismaClearWorkLoc")
    RegisterForModEvent("SeverActions_PrismaSetPlayLoc", "OnPrismaSetPlayLoc")
    RegisterForModEvent("SeverActions_PrismaClearPlayLoc", "OnPrismaClearPlayLoc")

    ; Off-screen life exclusion toggles from PrismaUI
    RegisterForModEvent("SeverActions_OffScreenExclude", "OnOffScreenExclude")
    RegisterForModEvent("SeverActions_OffScreenInclude", "OnOffScreenInclude")

    ; Off-screen life LLM response — C++ Bridge fires this from the SkyrimNet
    ; v8 PublicSendCustomPromptToLLM callback after parsing the response and
    ; storing events + gossip in the native data store. strArg carries the
    ; same pipe-delimited string the legacy parser used to return.
    RegisterForModEvent("SeverActions_OffScreenLifeReady", "OnOffScreenLifeReady")

    ; Ambient banter LLM response — C++ AmbientBanterScanner fires this from
    ; the SkyrimNet v8 callback after parsing the response and pre-building
    ; the gamemaster_dialogue event JSON. numArg = 1.0 means a pair is ready
    ; to RegisterEvent (handler pulls eventJson + actors from native accessors),
    ; 0.0 means silence cycle or failure (handler just clears in-progress).
    ; The old Papyrus-side context + eventJson building corrupted non-ASCII
    ; NPC names to mojibake via String += — see issue #9.
    RegisterForModEvent("SeverActions_AmbientBanterReady", "OnAmbientBanterReady")

    ; Quest awareness — C++ QuestAwarenessStore fires these when summary/completion queues have data
    RegisterForModEvent("SeverActions_QuestSummaryReady", "OnQuestSummaryReady")
    RegisterForModEvent("SeverActions_QuestCompleted", "OnQuestCompletedEvent")

    ; Reputation assessment — C++ player_familiarity decorator fires on blurb-milestone
    ; (first dialogue or every +100 lines, decided inside FamiliarityStore).
    RegisterForModEvent("SeverActions_ReputationAssess", "OnReputationAssessRequest")

    ; Healer combat style — native HealerPoll fires this every ~1s during combat
    ; for any registered healer that passes target/cooldown/resource gates. The
    ; handler does the actual Spell.Cast() + bonus heal + voice line.
    RegisterForModEvent("SeverActionsNative_HealerCast", "OnHealerCast")


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

    ; Wave 2 (C.2): hand the arrest LinkedRef keywords to OrphanCleanup so the
    ; native scanner can detect stale FollowTargetKW / SandboxAnchorKW links
    ; left behind by crashed arrest scripts. The scanner fires the
    ; SeverActions_OrphanCleanup mod event; SeverActions_Arrest.psc's
    ; OnOrphanCleanup handler filters via faction state before cleaning.
    Keyword arrestFollowKW = None
    Keyword arrestSandboxKW = None
    If ArrestScript
        arrestFollowKW = ArrestScript.SeverActions_FollowTargetKW
        arrestSandboxKW = ArrestScript.SeverActions_SandboxAnchorKW
    EndIf
    SeverActionsNative.OrphanCleanup_SetArrestKeywords(arrestFollowKW, arrestSandboxKW)

    ; Post-Wave-8: register arrest factions for the keyword-less stale-membership
    ; sweep. Catches guards stuck in dispatch Phase 1 (Travel) before any
    ; LinkedRef package was applied — they hold DispatchFaction membership but
    ; no scanner-visible keyword. Without this sweep, the action YAML
    ; eligibility filter `is_in_faction(SeverActions_DispatchFaction) == false`
    ; would lock the speaker out of every arrest action permanently.
    Faction arrestDispatch = None
    Faction arrestWaiting  = None
    Faction arrestArrested = None
    Faction arrestJailed   = None
    If ArrestScript
        arrestDispatch = ArrestScript.SeverActions_DispatchFaction
        arrestWaiting  = ArrestScript.SeverActions_WaitingArrest
        arrestArrested = ArrestScript.SeverActions_Arrested
        arrestJailed   = ArrestScript.SeverActions_Jailed
    EndIf
    SeverActionsNative.OrphanCleanup_SetArrestFactions(arrestDispatch, arrestWaiting, arrestArrested, arrestJailed)

    ; Clear any stuck assessment flags from previous session (callback may not have fired if pex was stale)
    AssessmentInProgress = false
    InterFollowerAssessmentInProgress = false
    OffScreenLifeInProgress = false
    ReputationAssessInProgress = false

    ; Sync the user-configurable quest awareness output cap to the C++ store.
    ; The C++ default is 5; if the user changed it via PrismaUI / MCM, the new
    ; value lives in this property and gets pushed down here on each load.
    SeverActionsNative.Native_QuestAwareness_SetOutputCap(QuestAwarenessOutputCap)

    ; ─── Defer heavy per-follower passes to the next OnUpdate tick ───
    ; Everything below — DetectExistingFollowers's cell scan, the cached
    ; follower array, every per-follower Sync*/Reapply*/Patch* pass, and
    ; ReapplyHomeSandboxing — used to run inline here, blocking
    ; SeverActions_Init's Initialize() for ~20s on a save with active
    ; followers. The user couldn't open PrismaUI until it all finished.
    ;
    ; None of these passes are needed by other Init steps; they only
    ; reconcile state inside this script. Deferring them by 100ms lets
    ; the Init chain return immediately, the "SeverActions loaded"
    ; notification appear when the menu is actually usable, and the
    ; sync work continue on the Papyrus VM's own schedule.
    DeferredMaintenancePending = true
    RegisterForSingleUpdate(0.1)
EndFunction

; ─────────────────────────────────────────────────────────────────────────
; Deferred Maintenance — the heavy per-follower passes that used to be
; inline in Maintenance(). Now invoked from OnUpdate 100ms after Maintenance()
; returns. See the DeferredMaintenancePending property comment for context.
; ─────────────────────────────────────────────────────────────────────────
Function RunDeferredMaintenance()
    Debug.Trace("[SeverActions_FollowerManager] Running deferred maintenance...")

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

    ; Re-run the native hydrator now that DetectExistingFollowers and
    ; RecoverCustomAIFollowers may have added vanilla / NFF / mod-recruited
    ; followers to the cosave that weren't present when the kPostLoadGame
    ; hydrator ran. Idempotent — followers already hydrated are no-ops on
    ; their per-follower passes; the opinions string rebuild reruns against
    ; the now-complete active-follower set. After this returns the DidRun
    ; gate is true iff there's anyone to hydrate, so the per-pass guards
    ; below correctly skip when native has handled them.
    SeverActionsNativeExt.Native_HydrateFollowerSystem_Run()

    ; Cache the gate flag once — the value cannot change for the rest of
    ; this function and each Native_HydrateFollowerSystem_DidRun() call is
    ; a Papyrus → native VM hop. Three uses below.
    Bool hydratorDidRun = SeverActionsNativeExt.Native_HydrateFollowerSystem_DidRun()

    ; Sync all relationship values from StorageUtil to native FollowerDataStore.
    ; PrismaUI reads from native store (C++ fast path), but values live in StorageUtil.
    ; This ensures PrismaUI shows correct values after every game load.
    SyncAllRelationshipsOnLoad(cachedFollowers)

    ; Re-assign outfit alias slots after load (ForceRefTo doesn't survive save/load)
    ReassignOutfitSlots(cachedFollowers)

    ; Re-apply combat style actor values after load
    ; NFF/EFF or the dismiss/recruit cycle can revert Confidence/Aggression to defaults.
    ; The StorageUtil string persists, but the actor value effects may not.
    ;
    ; Phase 3 fast-path: if FollowerSystemHydrator ran at kPostLoadGame
    ; (which it does on every save load), the engine-side combat style +
    ; Confidence/Aggression + HealerPoll registration are already applied
    ; for every cosaved follower. Papyrus only needs to handle followers
    ; detected DURING this deferred pass — but the Native_HydrateFollowerSystem_Run()
    ; call above already re-hydrated those too, so this branch can be
    ; safely skipped whenever the hydrator successfully ran.
    If !hydratorDidRun
        ReapplyCombatStyles(cachedFollowers)
    EndIf

    ; Re-apply IgnoreFriendlyHits to all followers — the actor flag doesn't
    ; reliably survive save/load on every mod-added follower (especially custom-
    ; AI ones managed outside CurrentFollowerFaction). Idempotent — calling
    ; with the same value twice is a no-op. Pairs with the
    ; SeverActions_FollowerFaction self-friendly reaction declared in the ESP
    ; to keep stray AoE / arrow / fireball hits from flipping followers
    ; hostile to each other.
    ApplyIgnoreFriendlyHits(cachedFollowers)

    ; Patch-up: ensure all vanilla-path followers have CurrentFollowerFaction + Ally rank
    ; (retroactively applies to followers recruited before this code existed)
    PatchUpVanillaFollowerStatus(cachedFollowers)

    ; Sync inter-follower pair relationships from StorageUtil to native store.
    ; Phase 3 optimization: this was a legacy pre-T1-A.1 migration that ran
    ; every load doing O(N²) StorageUtil reads. Modern save paths write pair
    ; data directly to the cosaved FollowerDataStore — the StorageUtil mirror
    ; is only there for upgraders. Gated by a one-shot sentinel so it runs
    ; once and stays off forever. If a user reports stale pair data after
    ; a save upgrade, clearing this key (or reinstalling) re-fires it.
    ; Integer-counter sentinel (vs boolean) so future schema bumps can
    ; re-fire by raising the threshold (e.g. `< 2` for v2 of the migration).
    If StorageUtil.GetIntValue(None, "SeverActions_PairSyncMigDone", 0) < 1
        SyncAllPairRelationshipsOnLoad(cachedFollowers)
        StorageUtil.SetIntValue(None, "SeverActions_PairSyncMigDone", 1)

        ; First-load upgrade fix: the kPostLoadGame hydrator built
        ; companionOpinions against the cosaved (empty/default) pair
        ; data. Now that the legacy StorageUtil mirror has been imported
        ; into the native pair store, re-run the hydrator so opinions
        ; reflect the actual pre-T1-A.1 relationships. Without this,
        ; sever_companion_opinions reads stale "neutral" strings for
        ; one whole upgrade session.
        SeverActionsNativeExt.Native_HydrateFollowerSystem_Run()
    EndIf

    ; T1-B: one-shot migration sweep for per-follower scalars + dedup
    ; watermarks. Reads the legacy SeverFollower_*/SeverActions_*
    ; StorageUtil keys for any pre-T1-B save and copies them into the
    ; native FollowerData. Sentinel keeps it idempotent across re-loads.
    If StorageUtil.GetIntValue(None, "SeverActions_T1BMigrationDone", 0) == 0
        SyncFollowerScalarsOnLoad(cachedFollowers)
        StorageUtil.SetIntValue(None, "SeverActions_T1BMigrationDone", 1)
    EndIf

    ; v3.0: backfill BardAudienceExcludedFaction onto followers already in the
    ; roster so they stop dropping their follow package to watch a bard. New /
    ; re-recruited followers get it via the onboard hook; dismiss/leave clears
    ; it. Faction membership persists, so this one-shot sweep never re-runs.
    ; Safe on tracking-only followers — a faction add, not a package mutation.
    If StorageUtil.GetIntValue(None, "SeverActions_BardExcludeMigDone", 0) < 1
        Int bardIdx = 0
        While bardIdx < cachedFollowers.Length
            AddBardAudienceExclusion(cachedFollowers[bardIdx])
            bardIdx += 1
        EndWhile
        StorageUtil.SetIntValue(None, "SeverActions_BardExcludeMigDone", 1)
    EndIf

    ; Essential is applied via quest ReferenceAlias slots (works on templated/
    ; generic NPCs and live). Alias fills aren't guaranteed across save/load and
    ; the C++ hydrator only restores the legacy base-flag (insufficient for
    ; templated NPCs), so always rebuild the alias pool from cosaved intent.
    ReassignEssentialSlots(cachedFollowers)

    ; T1-A.2: one-shot migration of the two per-follower string blobs
    ; (CompanionOpinions + LifeEventHistory) from StorageUtil into native
    ; FollowerData. CompanionOpinions also gets regenerated by the
    ; RebuildAllCompanionOpinions call above on every load — this sweep
    ; just keeps the value populated for pre-T1-A.2 saves that have stale
    ; StorageUtil entries while the first rebuild settles. LifeEventHistory
    ; is only ever written by the off-screen life processor; if a user
    ; had any history accumulated pre-T1-A.2, this sweep is the only way
    ; to bring it across.
    If StorageUtil.GetIntValue(None, "SeverActions_T1A2MigrationDone", 0) == 0
        SyncFollowerStringBlobsOnLoad(cachedFollowers)
        StorageUtil.SetIntValue(None, "SeverActions_T1A2MigrationDone", 1)
    EndIf

    ; T1-A.3: one-shot migration of the last three Papyrus-owned
    ; per-follower StorageUtil strings (LifeSummary + WorkLocation +
    ; PlayLocation display labels) into native FollowerData. Sentinel-
    ; gated by SeverActions_T1A3MigrationDone so it runs once per save.
    If StorageUtil.GetIntValue(None, "SeverActions_T1A3MigrationDone", 0) == 0
        SyncFollowerStringLabelsOnLoad(cachedFollowers)
        StorageUtil.SetIntValue(None, "SeverActions_T1A3MigrationDone", 1)
    EndIf

    ; Rebuild pre-formatted companion opinions strings from float values.
    ; StorageUtil strings are unreliable across save/load, but the individual
    ; Affinity/Respect float values persist fine. Rebuild on every load.
    ; Phase 3 fast-path — FollowerSystemHydrator did this at kPostLoadGame
    ; in O(N²) native loops; output format matches the Papyrus version
    ; byte-for-byte so the SkyrimNet decorator reads the same string.
    If !hydratorDidRun
        RebuildAllCompanionOpinions(cachedFollowers)
    EndIf


    ; Re-apply follow tracking after load (LinkedRef is runtime-only)
    ; The CK alias packages persist natively, but LinkedRef must be re-set
    ; Only reapply for SeverActions Mode followers (Tracking Mode doesn't use our packages)
    If FrameworkMode == 0
        SeverActions_Follow followSys = GetFollowScript()
        If followSys
            followSys.ReapplyFollowTracking(cachedFollowers)
        EndIf
    EndIf

    ; Re-apply home sandbox packages for dismissed NPCs with home markers.
    ; PO3 AddPackageOverride DOES persist across save/load via PO3's own cosave —
    ; the real loss mechanism is cell transition / actor 3D unload, where the engine
    ; may drop the override from the actor's active stack even though PO3's record
    ; survives. PO3 reapplies on cell attach but timing is not guaranteed, so we
    ; defensively reapply on every load.
    ReapplyHomeSandboxing()

    ; Register for sleep events — clear sandbox packages when player sleeps.
    ; Was in the original Maintenance() tail; folded in here so deferred
    ; ordering exactly matches the previous inline flow.
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

; OnPlayerLoadGame ModEvent handler removed — SeverActions_Init.psc calls
; Maintenance() on every load, which already invokes ReapplyEssentialStatus
; with a cached follower list. Keeping a separate ModEvent handler would
; double-fire the re-apply with an expensive GetAllFollowers() cell scan
; on top of the cheaper Init-driven pass. The matching RegisterForModEvent
; in Maintenance() is also dropped below.

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
            ElseIf SeverActionsNativeExt.Native_GetSandboxing(followers[i])
                ; Native_GetSandboxing checked BEFORE the tracking-only gate: this
                ; branch only touches SA's OWN SafeInteriorSandboxPackage override
                ; (StopSandbox is symmetric with the apply path), so it's safe and
                ; necessary for tracking-only followers too — otherwise an SA-applied
                ; sandbox + WaitingForPlayer=1 + waiting-faction membership stays
                ; stuck on them across the sleep.
                followSys.StopSandbox(followers[i])
                Debug.Trace("[SeverActions_FollowerManager] Cleared sandbox for " + followers[i].GetDisplayName() + " on sleep (same cell)")
            ElseIf IsTrackOnlyFollower(followers[i])
                ; Tracking-only followers (NFF / SPID custom-AI keyword / DLC like
                ; Serana) are managed by an external framework that owns their
                ; package stack. ClearPackageOverride nukes EVERY override,
                ; including the external framework's follow package — and that
                ; framework has no "package was wiped" hook to re-apply, so the
                ; follower defaults to idle AI and wanders. Symptom users hit:
                ; Daegon walks away after sleeping in a tavern. Leave them alone
                ; on sleep; their controller already handles its own state.
                Debug.Trace("[SeverActions_FollowerManager] Skipping package-override clear for tracking-only " + followers[i].GetDisplayName() + " on sleep (external AI owns packages)")
            Else
                ; Non-sandboxing, non-home, non-track-only followers: clear any lingering FF orphans
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

    ; Phase 3 perf — replace
    ;   playerCell.GetNumRefs(43) + per-i GetNthRef + per-actor IsDead +
    ;   IsCommandedActor + IsPlayerRef + cast
    ; with a single native call that returns a pre-filtered Actor[]. The
    ; native walk runs in tight C++ instead of marshalling 4+ Papyrus VM
    ; calls per cell ref, and the returned list is already alive /
    ; non-player / non-commanded.
    Actor[] cellActors = SeverActionsNativeExt.Native_ScanPlayerCellForLiveActors()
    Int numRefs = cellActors.Length
    Int detected = 0
    Int i = 0

    While i < numRefs
        Actor actorRef = cellActors[i]

        If actorRef
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
                        ; Custom-AI fast path — actor is already known to the cosave,
                        ; so suppress first-recruit defaults (their data is preserved).
                        _OnboardTrackingMode(actorRef, false)
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
                        ; FollowerDataStore.HasData() is the authoritative signal — it stays
                        ; true across soft-dismiss, false after explicit Purge.
                        Bool isReturning = false
                        If SeverActions_FollowerFaction && actorRef.IsInFaction(SeverActions_FollowerFaction)
                            isReturning = true
                        ElseIf SeverActionsNativeExt.Native_HasFollowerData(actorRef)
                            isReturning = true
                        EndIf

                        _OnboardTrackingMode(actorRef, !isReturning)

                        If isReturning
                            Debug.Trace("[SeverActions_FollowerManager] Returning follower re-detected — preserving existing data for " + actorRef.GetDisplayName())
                        Else
                            Debug.Trace("[SeverActions_FollowerManager] New follower detected — initialized defaults for " + actorRef.GetDisplayName())
                        EndIf

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
                    _OnboardTrackingMode(actorRef, !SeverActionsNativeExt.Native_HasFollowerData(actorRef))
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

    ; Check if this actor has been in our system before. FollowerDataStore.HasData
    ; is the authoritative signal — it stays true through soft-dismiss and only
    ; clears on explicit Purge.
    Bool isFirstRecruit = !SeverActionsNativeExt.Native_HasFollowerData(akActor)

    If isFirstRecruit
        Debug.Trace("[SeverActions_FollowerManager] Native teammate detected (NEW): " + akActor.GetDisplayName())
    Else
        Debug.Trace("[SeverActions_FollowerManager] Native teammate detected (RETURNING): " + akActor.GetDisplayName())
    EndIf

    _OnboardTrackingMode(akActor, isFirstRecruit)

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

    ; Enqueue for delayed confirmation — OnUpdate will verify and act on the whole queue
    If !PendingDismissQueue
        PendingDismissQueue = new Actor[32]
    EndIf
    If PendingDismissCount < PendingDismissQueue.Length
        ; Avoid duplicate enqueue for the same actor
        Int seen = PendingDismissQueue.Find(akActor)
        If seen < 0 || seen >= PendingDismissCount
            PendingDismissQueue[PendingDismissCount] = akActor
            PendingDismissCount += 1
        EndIf
        DebugMsg("Vanilla dismiss candidate: " + akActor.GetDisplayName() + " — confirming in 2.5s (queue: " + PendingDismissCount + ")")
        RegisterForSingleUpdate(2.5)
    Else
        DebugMsg("Vanilla dismiss queue full (32) — dropping: " + akActor.GetDisplayName())
    EndIf
EndEvent

Event OnOrphanCleanup(string eventName, string keywordType, float numArg, Form sender)
    {Fired by native OrphanCleanup when an actor has a SeverActions LinkedRef keyword
     but is NOT tracked by any management system. Clears the orphaned LinkedRef,
     removes package overrides, and forces AI re-evaluation so the NPC returns to
     their default routine instead of standing around with an FE runtime package.

     IMPORTANT: only handle keyword types we own (travel / furniture / follow).
     The arrest types (arrest_follow / arrest_sandbox / arrest_faction_sweep)
     are SeverActions_Arrest's responsibility — its OnOrphanCleanup filters
     by active-session and bails for live arrests. If we run EvaluatePackage
     here on a live-arrest guard or prisoner, we interrupt their escort
     package every 5 seconds (the native scanner cadence), which can drop
     the override in the brief gap before the FSM's per-tick re-apply runs.
     That's what caused "guard takes a few steps and stops" during escort.}
    If keywordType != "travel" && keywordType != "furniture" && keywordType != "follow"
        Return
    EndIf

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
    SeverActionsNativeExt.SituationMonitor_RescueSandboxers()

    If !HomeSlots || !HomeMarkerList
        Return
    EndIf

    Actor[] homedNPCs = GetAllHomedNPCs()
    Int i = 0
    While i < homedNPCs.Length
        Actor akActor = homedNPCs[i]
        ; Only re-apply for dismissed followers — active followers should keep
        ; following, not get forced into home sandbox when entering their home cell.
        If akActor && akActor.Is3DLoaded() && !IsRegisteredFollower(akActor)
            Int slot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)
            If slot >= 0 && slot < HomeSlots.Length
                ; Phase 5 Fix B — previously only track-only followers (Inigo, Lucien)
                ; got the cell-load EvaluatePackage kick. Regular dismissed followers
                ; rely on the CK alias package alone, but Skyrim doesn't guarantee an
                ; AI tick on 3D-load, so some stragglers stayed on a runtime FF package
                ; until the next sleep/time-skip. Always kick the engine to re-evaluate,
                ; regardless of whether we also need to (re)apply a PO3 override.
                If IsTrackOnlyFollower(akActor)
                    Package homePkg = GetHomeSandboxPackage(slot)
                    If homePkg
                        ActorUtil.AddPackageOverride(akActor, homePkg, 100, 1)
                    EndIf
                EndIf
                akActor.SetAV("WaitingForPlayer", 2)

                ; Phase 7 — escalating chain (immediate + 500ms + 1500ms resetAI).
                ; Dismissed homed followers are not in combat, so resetAI's
                ; state-clearing side effects are safe here. Longer resetAI
                ; delay than safe-interior (1500 vs 1000) gives the AI scheduler
                ; time to settle the actor's state after cell-load.
                SeverActionsNative.EscalatedReEvaluate(akActor, 1500)
                DebugMsg("CellLoad: Re-evaluated home sandbox for " + akActor.GetDisplayName())
            EndIf
        ElseIf akActor && akActor.Is3DLoaded() && IsRegisteredFollower(akActor)
            ; Self-heal: an ACTIVE companion should never carry the home sandbox.
            ; If a track-only-dismiss false-positive, a SetPlayerTeammate flicker,
            ; or a verify misfire left them in the home-sandbox state
            ; (WaitingForPlayer == 2), strip the override + alias and restore
            ; follow so they don't walk back to their assigned home while still
            ; recruited. RemoveHomeSandbox resets WFP to 0 and re-evaluates.
            If akActor.GetAV("WaitingForPlayer") == 2.0
                RemoveHomeSandbox(akActor)
                DebugMsg("CellLoad self-heal: stripped stray home sandbox from active follower " + akActor.GetDisplayName())
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

    Actor akActor = SeverActionsNative.FindActorByName(actorName)
    If !akActor
        Debug.Trace("[SeverActions_FollowerManager] PrismaAssignHome: could not resolve actor '" + actorName + "'")
        Return
    EndIf

    ; Read the location label from the native cosave — the PrismaUI C++ handler
    ; already wrote it (cleanly) via store->SetHome before firing this event, so
    ; we don't re-parse it out of the piped strArg. The old 2-arg Substring here
    ; returned the WHOLE "name|location" string, leaking the actor name into the
    ; displayed home (e.g. "Jenassa|Drunken Huntsman").
    String locName = SeverActionsNative.Native_GetHome(akActor)
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

Event OnPrismaSetWorkLoc(string eventName, string strArg, float numArg, Form sender)
    {Fired by PrismaUI when user clicks "Set Work Here". Moves the follower's
     WorkMarker_NN to the player's current position so schedule ticks can route them there.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = SeverActionsNative.FindActorByName(actorName)
    If !akActor
        Debug.Trace("[SeverActions_FollowerManager] PrismaSetWorkLoc: could not resolve actor '" + actorName + "'")
        Return
    EndIf
    SetRoutineLocHere(akActor, "work")
EndEvent

Event OnPrismaClearWorkLoc(string eventName, string strArg, float numArg, Form sender)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = SeverActionsNative.FindActorByName(actorName)
    If !akActor
        Return
    EndIf
    ClearRoutineLoc(akActor, "work")
EndEvent

Event OnPrismaSetPlayLoc(string eventName, string strArg, float numArg, Form sender)
    {Fired by PrismaUI when user clicks "Set Play Here".}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = SeverActionsNative.FindActorByName(actorName)
    If !akActor
        Debug.Trace("[SeverActions_FollowerManager] PrismaSetPlayLoc: could not resolve actor '" + actorName + "'")
        Return
    EndIf
    SetRoutineLocHere(akActor, "play")
EndEvent

Event OnPrismaClearPlayLoc(string eventName, string strArg, float numArg, Form sender)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = SeverActionsNative.FindActorByName(actorName)
    If !akActor
        Return
    EndIf
    ClearRoutineLoc(akActor, "play")
EndEvent

Event OnPrismaSetCombatStyle(string eventName, string strArg, float numArg, Form sender)
    {Fired by PrismaUI when user changes combat style dropdown.
     strArg = "formID|styleName" — formID as signed int, style as string.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String formIdStr = StringUtil.Substring(strArg, 0, pipePos)
    ; Explicit length — the 2-arg StringUtil.Substring overload returns the whole
    ; "formID|style" string (same latent bug the home handler hit). SetCombatStyle
    ; normalizes its input so this was masked, but parse it correctly regardless.
    String styleName = StringUtil.Substring(strArg, pipePos + 1, StringUtil.GetLength(strArg))

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

    ; WasEssential bookkeeping rule: this flag tells DismissCompanion's
    ; restore branch whether to leave the live essential flag alone
    ; (wasEssential=true) or clear it (wasEssential=false). When the
    ; user explicitly toggles via the UI they're stating intent that
    ; should outlive dismiss, so we update WasEssential to MATCH the
    ; chosen direction on both branches. Otherwise a Lydia-class
    ; record-essential NPC stays mutated forever (ON→OFF sticks across
    ; dismiss only by accident; without the WasEssential write, the
    ; next ReapplyEssentialStatus would re-clear on every load).
    If valStr == "1"
        ; Cosave the ON intent and apply essential via a quest ReferenceAlias
        ; slot (works on templated/generic NPCs, applies live).
        SeverActionsNativeExt.Native_SetEssentialOff(akActor, false)
        SeverActionsNativeExt.Native_SetWasEssential(akActor, false)
        MakeActorEssential(akActor)
        DebugMsg("PrismaUI Essential ON (alias): " + akActor.GetDisplayName())
    Else
        ; Cosave the OFF intent, drop our alias slot, and clear any legacy
        ; base-flag (from the old kEssential mechanism) so OFF actually sticks.
        SeverActionsNativeExt.Native_SetEssentialOff(akActor, true)
        SeverActionsNativeExt.Native_SetWasEssential(akActor, false)
        ClearActorEssential(akActor)
        If SeverActionsNative.Native_IsEssential(akActor)
            SeverActionsNative.Native_ClearEssential(akActor)
        EndIf
        DebugMsg("PrismaUI Essential OFF (alias): " + akActor.GetDisplayName())
    EndIf
EndEvent

Event OnPrismaSetNearbyExcluded(string eventName, string strArg, float numArg, Form sender)
    {Fired by PrismaUI Settings when user toggles nearby-ref prompt filters.
     strArg = comma-separated "type:subtype" tags (e.g. "furniture:bed,item:weapon").
     Empty string = clear all user exclusions (defaults still apply at prompt-render).}
    NearbyExcludedTags = strArg
    SyncNearbyExcludedToStorageUtil()
    DebugMsg("PrismaUI Nearby filters set: [" + strArg + "]")
EndEvent

Function SyncNearbyExcludedToStorageUtil()
    {Mirror the NearbyExcludedTags property into StorageUtil(None) so the
     nearby-ref prompt template can read it via papyrus_util("GetStringValue",
     "", "SeverActions_NearbyExcluded", ""). Property is the source of truth
     (cosaved); StorageUtil is the prompt-render-time cache.}
    StorageUtil.SetStringValue(None, "SeverActions_NearbyExcluded", NearbyExcludedTags)
EndFunction

Event OnPrismaSetUIScale(string eventName, string strArg, float numArg, Form sender)
    {Fired by the in-Prisma slider's settings handler. numArg carries the
     new scale value. Writes the property + StorageUtil mirror so MCM stays
     in sync (MCM reads the property at slider-open time).}
    UIScale = numArg
    SyncUIScaleToStorageUtil()
    DebugMsg("PrismaUI UI scale set: " + numArg)
EndEvent

Function SyncUIScaleToStorageUtil()
    {Mirror UIScale property into StorageUtil(None). Cosaved property is
     source of truth; StorageUtil mirror is for any prompt/native that
     wants a stable read path without VM property lookup.}
    StorageUtil.SetFloatValue(None, "SeverActions_UIScale", UIScale)
EndFunction

Event OnOffScreenExclude(string eventName, string strArg, float numArg, Form sender)
    {Fired by PrismaUI when user excludes a follower from off-screen life events.}
    Actor akActor = Game.GetFormEx(numArg as Int) as Actor
    If akActor
        SeverActionsNative.Native_SetOffscreenExcluded(akActor, true)
        DebugMsg("Off-screen excluded: " + akActor.GetDisplayName())
    EndIf
EndEvent

Event OnOffScreenInclude(string eventName, string strArg, float numArg, Form sender)
    {Fired by PrismaUI when user re-includes a follower in off-screen life events.}
    Actor akActor = Game.GetFormEx(numArg as Int) as Actor
    If akActor
        SeverActionsNative.Native_SetOffscreenExcluded(akActor, false)
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
    ; Diff-based strip of the vanilla hunting bow + iron arrows that
    ; DialogueFollowerScript.SetFollower forcefully adds. Snapshot the
    ; counts BEFORE the SetFollower call, then remove only what was newly
    ; added. This handles three cases cleanly:
    ;   • Non-archer NPC: had 0 hunting bows → ends with 0.
    ;   • Archer with hunting bow already: count preserved (we only remove
    ;     the delta vanilla added on top).
    ;   • Archer with a different bow (long bow, mod bow): hunting bow
    ;     count returns to 0; their original weapon is untouched.
    ; Previous gating on "did they already hold a bow?" missed archers who
    ; got stacked with extra hunting bows + iron arrows on recruit.
    Form huntingBow = Game.GetFormFromFile(0x00013985, "Skyrim.esm")
    Form ironArrow  = Game.GetFormFromFile(0x0001397D, "Skyrim.esm")
    Int  preBowCount   = 0
    Int  preArrowCount = 0
    If huntingBow
        preBowCount = akActor.GetItemCount(huntingBow)
    EndIf
    If ironArrow
        preArrowCount = akActor.GetItemCount(ironArrow)
    EndIf

    dfScript.SetFollower(akActor as ObjectReference)

    If huntingBow
        Int addedBows = akActor.GetItemCount(huntingBow) - preBowCount
        If addedBows > 0
            akActor.RemoveItem(huntingBow, addedBows, true)
            DebugMsg("RecruitViaVanillaDialogue: Stripped " + addedBows + " vanilla hunting bow(s) from " + akActor.GetDisplayName())
        EndIf
    EndIf
    If ironArrow
        Int addedArrows = akActor.GetItemCount(ironArrow) - preArrowCount
        If addedArrows > 0
            akActor.RemoveItem(ironArrow, addedArrows, true)
            DebugMsg("RecruitViaVanillaDialogue: Stripped " + addedArrows + " vanilla iron arrow(s) from " + akActor.GetDisplayName())
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

; =============================================================================
; UPDATE LOOP - Relationship decay and mood drift
; =============================================================================

Event OnUpdate()
    ; Phase 2 perf — short-circuit branch. Maintenance() schedules a 100ms
    ; OnUpdate to run the heavy per-follower passes off the Init critical
    ; path. We catch that fire here, run the deferred work, then reschedule
    ; the normal 30s tick. None of the regular OnUpdate body runs on this
    ; fire — every block below is guarded by counters/timestamps that would
    ; be no-ops 100ms after load anyway, but skipping cleanly keeps
    ; behavior identical to the pre-Phase-2 inline flow.
    If DeferredMaintenancePending
        DeferredMaintenancePending = false
        RunDeferredMaintenance()
        RegisterForSingleUpdate(30.0)
        Return
    EndIf

    ; --- Vanilla dismiss delayed confirmation (drain entire queue) ---
    ; TeammateMonitor flagged one or more removals; verify each is still real
    ; (not a mod toggle). Multiple dismisses within a 2.5s window are all drained
    ; here — previously a single-slot field silently dropped all but the last.
    If PendingDismissCount > 0
        Int dq = 0
        While dq < PendingDismissCount
            Actor checkActor = PendingDismissQueue[dq]
            PendingDismissQueue[dq] = None
            If checkActor && IsRegisteredFollower(checkActor)
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
            dq += 1
        EndWhile
        PendingDismissCount = 0
        ; Re-register for normal update cycle and return — don't fall through this tick
        RegisterForSingleUpdate(30.0)
        Return
    EndIf

    If IsUpdating
        RegisterForSingleUpdate(30.0)
        Return
    EndIf

    ; Watchdog — if the off-screen-life ModEvent never arrived, clear the
    ; in-progress flag after 120s real-time so future events aren't blocked.
    If OffScreenLifeInProgress && (Utility.GetCurrentRealTime() - OffScreenLifeStartedRT) > 120.0
        DebugMsg("Off-screen life watchdog: clearing stuck InProgress flag (>120s without ready ModEvent)")
        OffScreenLifeInProgress = false
        PendingOffScreenLifeActor = None
    EndIf

    IsUpdating = true

    Float currentTime = GetGameTimeInSeconds()
    Float secondsPassed = currentTime - LastTickTime
    Float hoursPassed = secondsPassed / SECONDS_PER_GAME_HOUR

    ; Only update if meaningful time has passed (at least 0.5 game hours)
    If hoursPassed >= 0.5
        TickRelationships(hoursPassed)
        If DebtScript
            DebtScript.TickDebts()
        EndIf
        ; Deferred crafting commissions — same heartbeat cadence as debts.
        ; Resolved via the single-quest cast (all SA scripts share FormID
        ; 0x000D62) so this works with no CK property wiring on existing saves.
        ; Commission maturation is game-time based in the native, so the
        ; 0.5-game-hour gate is plenty of polling precision.
        SeverActions_Crafting craftScr = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Crafting
        If craftScr
            craftScr.TickCommissions()
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

    ; Schedule system — move HomeMarker to correct anchor (home/work/play) on hour transitions
    ProcessScheduleSwaps()

    ; Perf: build the active roster ONCE here and thread it to every
    ; read-only consumer below. GetAllFollowers does a native cell scan plus
    ; N IsRegisteredFollower VM calls and O(N^2) dedup; the downstream passes
    ; used to each call it independently (up to 5 redundant scans per tick).
    ; Built here — AFTER CheckDeadFollowers + CheckTrackOnlyFollowerStatus,
    ; which can unregister followers — so consumers never act on a roster
    ; entry that was just removed earlier this tick.
    Actor[] tickFollowers = GetAllFollowers()

    ; Wave 6.2: scene-aware home suspend/restore. If a registered follower is
    ; pulled into a vanilla BGSScene (quest scene, Serana lab search, etc.),
    ; release our home alias so the scene's own package can drive cleanly;
    ; restore once the scene ends. See CheckSceneSuspendedHomes docs.
    CheckSceneSuspendedHomes(tickFollowers)

    ; Refresh IgnoreFriendlyHits on registered followers if the FF-prevention
    ; toggle is on. The flag can get dropped by AI state transitions (sandbox
    ; <-> combat <-> dismiss/recruit); re-stamping every 30s is cheap and
    ; guarantees the protection holds even if something else resets it.
    RefreshFriendlyFireFlags(tickFollowers)

    ; Automatic relationship assessments — at most one type per tick to avoid LLM flooding
    If AutoRelAssessment && !InterFollowerAssessmentInProgress
        CheckRelationshipAssessments(tickFollowers)
    EndIf

    ; Inter-follower assessment — only fires if no player-centric assessment is in flight
    If AutoInterFollowerAssessment && !AssessmentInProgress && !InterFollowerAssessmentInProgress
        CheckInterFollowerAssessments(tickFollowers)
    EndIf

    ; Off-screen life events — only fires if no other LLM assessments are in flight
    If AutoOffScreenLife && !AssessmentInProgress && !InterFollowerAssessmentInProgress && !OffScreenLifeInProgress
        CheckOffScreenLifeEvents()
    EndIf

    ; Follower banter — independent of other LLM systems, only gated by its own cooldown + flag
    If AutoFollowerBanter && !BanterInProgress
        CheckFollowerBanter(tickFollowers)
    EndIf

    ; Ambient NPC banter — independent of every other LLM system; targets
    ; non-follower NPCs near the player so populated areas feel alive without
    ; the player having to initiate every interaction. Separate cooldown
    ; (3-7 game hours) and separate flag so it doesn't block or get blocked
    ; by follower banter.
    If AutoAmbientBanter && !AmbientBanterInProgress
        CheckAmbientBanter()
    EndIf

    IsUpdating = false
    RegisterForSingleUpdate(30.0)
EndEvent

Function RefreshFriendlyFireFlags(Actor[] followers)
    {Re-stamp IgnoreFriendlyHits(true) on all registered followers if the
     "Prevent Follower Friendly Fire" toggle is on. No-op if off. The flag
     can drop silently during AI state transitions so we pay a few Actor
     function calls every 30s to keep it anchored. Roster passed in by the
     OnUpdate tick to avoid a redundant GetAllFollowers scan.}
    Quest SeverActionsQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
    If !SeverActionsQuest
        Return
    EndIf
    If StorageUtil.GetIntValue(SeverActionsQuest, "SeverActions_PreventFollowerFF", 0) != 1
        Return
    EndIf
    Int i = 0
    While i < followers.Length
        Actor f = followers[i]
        If f && !f.IsDead()
            f.IgnoreFriendlyHits(true)
        EndIf
        i += 1
    EndWhile
EndFunction

Function TickRelationships(Float hoursPassed)
    {Phase 4C: relationship math runs entirely in C++ under a single lock
     acquisition. Papyrus only fires the autonomous-leaving SkyrimNet event
     for actors that newly crossed the threshold (de-duped via the
     SeverFollower_LeaveWarned StorageUtil flag).}

    ; Pre-compute the unit-agnostic deltas the native ticker expects.
    Float moodChange           = MOOD_DECAY_RATE * hoursPassed
    Float rapportLossOnNeglect = 0.0
    If NEGLECT_HOURS > 0.0
        rapportLossOnNeglect = RapportDecayRate * (hoursPassed / NEGLECT_HOURS)
    EndIf
    Float currentTimeSec          = GetGameTimeInSeconds()
    Float neglectSecondsThreshold = NEGLECT_HOURS * SECONDS_PER_GAME_HOUR

    Actor[] belowThreshold = SeverActionsNativeExt.Native_TickAllRelationships( \
        moodChange, rapportLossOnNeglect, currentTimeSec, \
        neglectSecondsThreshold, LeavingThreshold, AllowAutonomousLeaving)

    ; --- Autonomous-leaving event dispatch ---
    ; Native gives us every actor currently at-or-below threshold; we filter to
    ; ones not yet warned this episode. The opposite case (rapport recovered
    ; above threshold) is handled below for any previously-warned follower.
    If AllowAutonomousLeaving && belowThreshold
        Actor player = Game.GetPlayer()
        Int i = 0
        While i < belowThreshold.Length
            Actor akFollower = belowThreshold[i]
            ; T1-B: native source of truth for the leaveWarned dedup flag.
            If akFollower && !SeverActionsNativeExt.Native_GetLeaveWarned(akFollower)
                SeverActionsNativeExt.Native_SetLeaveWarned(akFollower, true)
                SkyrimNetApi.RegisterPersistentEvent( \
                    akFollower.GetDisplayName() + " is deeply unhappy and considering leaving " + player.GetDisplayName() + "'s service.", \
                    akFollower, player)
            EndIf
            i += 1
        EndWhile

        ; Sweep previously-warned followers whose rapport has recovered.
        ; Cheap: only iterates the active roster.
        Actor[] roster = GetAllFollowers()
        Int r = 0
        While r < roster.Length
            Actor f = roster[r]
            If f && SeverActionsNativeExt.Native_GetLeaveWarned(f) \
                && GetRapport(f) > LeavingThreshold
                SeverActionsNativeExt.Native_SetLeaveWarned(f, false)
            EndIf
            r += 1
        EndWhile
    EndIf

    If DebugMode
        Debug.Trace("[SeverActions_FollowerManager] Tick: native processed " \
            + "(hoursPassed=" + hoursPassed + ", below-threshold=" + belowThreshold.Length + ")")
    EndIf
EndFunction

Function TickFollowerRelationship(Actor akFollower, Float hoursPassed)
    {Deprecated since Phase 4C — the entire roster now ticks inside C++ in
     TickRelationships above. Kept as a thin compatibility wrapper for any
     external caller that still invokes the per-actor entry point.}
    If !akFollower || hoursPassed <= 0.0
        Return
    EndIf
    Float moodChange = MOOD_DECAY_RATE * hoursPassed
    Float rapportLossOnNeglect = 0.0
    If NEGLECT_HOURS > 0.0
        rapportLossOnNeglect = RapportDecayRate * (hoursPassed / NEGLECT_HOURS)
    EndIf
    SeverActionsNativeExt.Native_TickAllRelationships( \
        moodChange, rapportLossOnNeglect, GetGameTimeInSeconds(), \
        NEGLECT_HOURS * SECONDS_PER_GAME_HOUR, LeavingThreshold, false)
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

    ; Skip outfit-excluded actors — don't assign alias slot at all
    If SeverActionsNative.Native_GetOutfitExcluded(akActor)
        DebugMsg("Outfit excluded: " + akActor.GetDisplayName() + " — skipping outfit slot assignment")
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
; ESSENTIAL SLOT MANAGEMENT - ReferenceAlias-based essential status
; =============================================================================
; The ActorBase kEssential flag is ignored by the engine for templated/leveled
; NPCs (the bulk of "recruit any NPC" targets) and applies unreliably to
; already-loaded actors. A quest ReferenceAlias flagged "Essential" makes its
; held reference essential at the REFERENCE level — works on every actor and
; takes effect the instant it is filled. We keep a pool of slots (IDs 218-257).

Function EnsureEssentialSlots()
    {Lazily resolve the Essential alias pool by ID. ReferenceAlias[] property
     fills are fragile, so we bind the contiguous Essential alias block at
     runtime via GetAlias() instead of a CK-filled array property.}
    If EssentialSlots
        Return
    EndIf
    EssentialSlots = new ReferenceAlias[40]
    Int i = 0
    While i < EssentialSlotCount && i < 40
        EssentialSlots[i] = Self.GetAlias(EssentialSlotFirstID + i) as ReferenceAlias
        i += 1
    EndWhile
EndFunction

Function MakeActorEssential(Actor akActor)
    {Fill a free Essential alias slot with the actor (live, templated-safe).
     Idempotent — skips if already held. No-op if None or the pool is full.}
    If !akActor
        Return
    EndIf
    EnsureEssentialSlots()
    Int i = 0
    While i < EssentialSlots.Length
        If EssentialSlots[i] && EssentialSlots[i].GetActorRef() == akActor
            Return ; already essential via a slot
        EndIf
        i += 1
    EndWhile
    i = 0
    While i < EssentialSlots.Length
        If EssentialSlots[i] && !EssentialSlots[i].GetActorRef()
            EssentialSlots[i].ForceRefTo(akActor)
            DebugMsg("Essential slot " + i + " assigned to " + akActor.GetDisplayName())
            Return
        EndIf
        i += 1
    EndWhile
    DebugMsg("WARNING: No free essential slots (cap " + EssentialSlotCount + ") for " + akActor.GetDisplayName())
EndFunction

Function ClearActorEssential(Actor akActor)
    {Empty the actor's Essential alias slot, removing live essential status.
     Record-essential NPCs (e.g. Lydia) keep their own base-flag essential.}
    If !akActor
        Return
    EndIf
    EnsureEssentialSlots()
    Int i = 0
    While i < EssentialSlots.Length
        If EssentialSlots[i] && EssentialSlots[i].GetActorRef() == akActor
            EssentialSlots[i].Clear()
            DebugMsg("Essential slot " + i + " cleared for " + akActor.GetDisplayName())
            Return
        EndIf
        i += 1
    EndWhile
EndFunction

Bool Function IsActorEssentialBySlot(Actor akActor)
    {True if the actor currently holds an Essential alias slot.}
    If !akActor
        Return false
    EndIf
    EnsureEssentialSlots()
    Int i = 0
    While i < EssentialSlots.Length
        If EssentialSlots[i] && EssentialSlots[i].GetActorRef() == akActor
            Return true
        EndIf
        i += 1
    EndWhile
    Return false
EndFunction

Function ReassignEssentialSlots(Actor[] followers)
    {Rebuild the Essential alias pool from cosaved intent after a game load.
     Alias fills are not guaranteed across save/load, and the C++ hydrator only
     restores the legacy base-flag (insufficient for templated NPCs), so we
     always rebuild here from the follower roster + EssentialOff intent.}
    EnsureEssentialSlots()
    ; Drop stale fills first.
    Int i = 0
    While i < EssentialSlots.Length
        If EssentialSlots[i]
            EssentialSlots[i].Clear()
        EndIf
        i += 1
    EndWhile
    If followers == None
        Return
    EndIf
    ; Re-fill for living followers whose intent is essential-on; clear any
    ; legacy base-flag for those toggled off so OFF actually sticks.
    i = 0
    While i < followers.Length
        Actor a = followers[i]
        If a && !a.IsDead()
            If !SeverActionsNativeExt.Native_GetEssentialOff(a)
                MakeActorEssential(a)
            ElseIf SeverActionsNative.Native_IsEssential(a)
                SeverActionsNative.Native_ClearEssential(a) ; clear legacy base-flag
            EndIf
        EndIf
        i += 1
    EndWhile
    DebugMsg("Reassigned essential alias slots for " + followers.Length + " follower(s)")
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
                ; T1-B: native source of truth for the death timestamp.
                Float deathTime = SeverActionsNativeExt.Native_GetDeathTime(slotActor)
                If deathTime == 0.0
                    ; First detection — record death time
                    SeverActionsNativeExt.Native_SetDeathTime(slotActor, currentTime)
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
    StorageUtil.UnsetStringValue(akActor, KEY_COMBAT_STYLE)
    StorageUtil.UnsetFloatValue(akActor, KEY_LAST_INTERACTION)
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
    RemoveBardAudienceExclusion(akActor)

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

    ; Mark as not currently following — FollowerData persists across soft-dismiss
    ; so HasFollowerData() still returns true for re-recruit detection.
    SeverActionsNative.Native_SetIsFollower(akActor, false)
    StorageUtil.UnsetIntValue(akActor, KEY_DISMISSED)

    ; Remove from factions
    If SeverActions_FollowerFaction
        akActor.RemoveFromFaction(SeverActions_FollowerFaction)
    EndIf
    RemoveBardAudienceExclusion(akActor)

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

Event OnPrismaCompanionWait(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: Tell a specific NPC to wait at the current location. Mirrors
     the hotkey + wheel "wait" entry points so the PrismaUI Wait button
     does the same thing — sandbox-at-current-location for vanilla
     followers, WaitingForPlayer flag for track-only followers.
     strArg = "actorName|" — C++ SendModEvent encodes the display name.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = SeverActionsNative.FindActorByName(actorName)
    If akActor
        DebugMsg("PrismaUI wait: " + akActor.GetDisplayName())
        CompanionWait(akActor)
    EndIf
EndEvent

Event OnPrismaCompanionFollow(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: Break a specific NPC out of waiting and resume following.
     Inverse of OnPrismaCompanionWait. Mirrors the hotkey + wheel "follow"
     entry points — track-only branch clears WaitingForPlayer for the
     custom-AI mod to take over, registered companions go through
     CompanionStartFollowing, non-companions restart casual FollowPlayer.
     strArg = "actorName|" — C++ SendModEvent encodes the display name.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = SeverActionsNative.FindActorByName(actorName)
    If akActor
        DebugMsg("PrismaUI follow: " + akActor.GetDisplayName())
        CompanionFollow(akActor)
    EndIf
EndEvent

Event OnPrismaCompanionWaitAll(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: Tell every active follower to wait. Single ModEvent dispatch —
     iterates GetAllFollowers() server-side rather than fanning out N events
     from JS. This keeps the Papyrus VM event queue sane for parties of 10+
     (NFF, Multiple Followers, etc.). Calls CompanionWait per actor, which
     handles track-only vs full-SA branching internally.}
    Actor[] allComp = GetAllFollowers()
    If !allComp
        Return
    EndIf
    Int ci = 0
    DebugMsg("PrismaUI wait-all: " + allComp.Length + " companion(s)")
    While ci < allComp.Length
        If allComp[ci]
            CompanionWait(allComp[ci])
        EndIf
        ci += 1
    EndWhile
EndEvent

Event OnPrismaCompanionFollowAll(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: Break every active follower out of waiting and resume following.
     Inverse of OnPrismaCompanionWaitAll. Single ModEvent dispatch — same
     server-side iteration pattern.}
    Actor[] allComp = GetAllFollowers()
    If !allComp
        Return
    EndIf
    Int ci = 0
    DebugMsg("PrismaUI follow-all: " + allComp.Length + " companion(s)")
    While ci < allComp.Length
        If allComp[ci]
            CompanionFollow(allComp[ci])
        EndIf
        ci += 1
    EndWhile
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

Function _OnboardTrackingMode(Actor akActor, Bool isFirstRecruit)
    {Phase 5c shared onboarding for tracking-mode followers. Called by
     DetectExistingFollowers, RecoverCustomAIFollowers, and OnNativeTeammateDetected
     after each has decided the actor is a legitimate recruit (faction check,
     teammate filter, custom-AI keyword, etc.). Sets the native roster flag,
     last-interaction time, faction membership, outfit slot, morality snapshot;
     on first recruit only, also applies relationship defaults + RECRUIT_TIME.
     Notifications and SkyrimNet events are caller-specific so they stay in the
     caller — this helper only handles the shared state mutations.}
    If !akActor
        Return
    EndIf
    Float now = GetGameTimeInSeconds()
    SeverActionsNative.Native_SetIsFollower(akActor, true)
    SeverActionsNativeExt.Native_SetInteractionTime(akActor, now)

    If isFirstRecruit
        StorageUtil.SetFloatValue(akActor, KEY_RECRUIT_TIME, now)
        SeverActionsNative.Native_SetRelationship(akActor, DEFAULT_RAPPORT, DEFAULT_TRUST, DEFAULT_LOYALTY, DEFAULT_MOOD)
        SeverActionsNative.Native_SetCombatStyle(akActor, "no combat style")
    EndIf

    StorageUtil.SetIntValue(akActor, KEY_MORALITY, akActor.GetAV("Morality") as Int)

    If SeverActions_FollowerFaction && !akActor.IsInFaction(SeverActions_FollowerFaction)
        akActor.AddToFaction(SeverActions_FollowerFaction)
    EndIf
    AddBardAudienceExclusion(akActor)

    AssignOutfitSlot(akActor)
EndFunction

; =============================================================================
; BARD-AUDIENCE EXCLUSION
; =============================================================================
; Add/remove the vanilla BardAudienceExcludedFaction (Skyrim.esm 0x10FCB4) so
; SeverActions followers — tracked and full — stop dropping their follow package
; to join the audience when a bard starts performing. Kept in lockstep with our
; own SeverActions_FollowerFaction membership: applied on onboard, cleared on
; dismiss/leave/remove so a former follower resumes normal tavern behaviour.

Function AddBardAudienceExclusion(Actor akActor)
    If !akActor
        Return
    EndIf
    Faction bardExcluded = Game.GetFormFromFile(0x0010FCB4, "Skyrim.esm") as Faction
    If bardExcluded && !akActor.IsInFaction(bardExcluded)
        akActor.AddToFaction(bardExcluded)
    EndIf
EndFunction

Function RemoveBardAudienceExclusion(Actor akActor)
    If !akActor
        Return
    EndIf
    Faction bardExcluded = Game.GetFormFromFile(0x0010FCB4, "Skyrim.esm") as Faction
    If bardExcluded && akActor.IsInFaction(bardExcluded)
        akActor.RemoveFromFaction(bardExcluded)
    EndIf
EndFunction

; =============================================================================
; ROSTER MANAGEMENT
; =============================================================================

Function RegisterFollower(Actor akActor)
    {Add an actor to the follower roster and start them following.
     Uses SeverActions' own alias/faction setup; routes vanilla DialogueFollower
     only when NFF is not installed (NFF hooks the vanilla alias itself).}
    If !akActor || akActor.IsDead()
        Return
    EndIf

    ; Notify downstream listeners (e.g. SeversHearth's camp sandbox layer)
    ; that the player just called this actor to their side. Lets them break
    ; the actor out of any per-mod hold (camp fire pin, etc.) before SA's
    ; own recruit logic toggles teammate / faction state. strArg = action verb.
    Int recruitEvt = ModEvent.Create("SeverActions_FollowerCalledByPlayer")
    If recruitEvt
        ModEvent.PushString(recruitEvt, "SeverActions_FollowerCalledByPlayer")
        ModEvent.PushString(recruitEvt, "recruit")
        ModEvent.PushFloat(recruitEvt, 0.0)
        ModEvent.PushForm(recruitEvt, akActor)
        ModEvent.Send(recruitEvt)
    EndIf

    If !CanRecruitMore()
        Debug.Notification("You have too many followers already.")
        SkyrimNetApi.RegisterEvent("follower_recruit_failed", \
            akActor.GetDisplayName() + " cannot join because " + Game.GetPlayer().GetDisplayName() + " already has too many companions.", \
            akActor, Game.GetPlayer())
        Return
    EndIf

    ; Check if this is a returning follower (has relationship values from before)
    Bool isFirstRecruit = !SeverActionsNativeExt.Native_HasFollowerData(akActor)

    ; --- Our own tracking (always, regardless of framework) ---
    StorageUtil.UnsetIntValue(akActor, KEY_DISMISSED)
    SeverActionsNative.Native_SetIsFollower(akActor, true)
    SeverActionsNativeExt.Native_SetInteractionTime(akActor, GetGameTimeInSeconds())

    ; Add to our own faction for fast, unambiguous detection
    If SeverActions_FollowerFaction
        akActor.AddToFaction(SeverActions_FollowerFaction)
    EndIf
    AddBardAudienceExclusion(akActor)

    ; Tell the engine to ignore hits from anyone this actor considers friendly.
    ; Combined with the SeverActions_FollowerFaction self-reaction (declared
    ; Friendly to itself in SeverActions.esp), this prevents stray AoE / cloak /
    ; arrow / fireball hits between followers from flipping them hostile to
    ; each other. Without this flag, engine combat AI processes "I was hit by
    ; X for damage" even when X is faction-friendly, and one accidental
    ; Firebolt makes Daegon and Jenassa swing at each other.
    akActor.IgnoreFriendlyHits(true)

    ; Set default relationship values and recruit time only on first recruit
    If isFirstRecruit
        StorageUtil.SetFloatValue(akActor, KEY_RECRUIT_TIME, GetGameTimeInSeconds())
        SeverActionsNative.Native_SetRelationship(akActor, DEFAULT_RAPPORT, DEFAULT_TRUST, DEFAULT_LOYALTY, DEFAULT_MOOD)
        SeverActionsNative.Native_SetCombatStyle(akActor, "no combat style")
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
            ; T1-B: native source of truth for the custom-AI signal.
            SeverActionsNativeExt.Native_SetRecruitedViaSerana(akActor, true)
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

            ; ── CurrentFollowerFaction repair for prior SA followers ──
            ; Vanilla pFollowerAlias.ForceRefTo() inside SetFollower() implicitly
            ; evicts the previous alias occupant from CurrentFollowerFaction
            ; (alias auto-management configured in the CK). Convenient Horses 7.1
            ; (issue #6) polls every 2-5s and treats CFF absence as a dismissal —
            ; calling SetPlayerTeammate(false) on the evictee, which trips our own
            ; vanilla-dismiss detection in OnNativeTeammateRemoved and unregisters
            ; the previous follower ~5s after the new recruit lands.
            ;
            ; Repair: re-add all previously-registered SA followers to CFF so any
            ; mod that gates "is recruited?" on CFF (CH 7.1 and likely others)
            ; keeps treating them as recruited. Restores the multi-follower
            ; contract that vanilla's single-alias model would otherwise break.
            ; No-op when no prior SA followers exist (single-follower scenario).
            Faction cffRepair = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
            If cffRepair
                Actor[] priorFollowers = GetAllFollowers()
                Int repaired = 0
                Int p = 0
                While p < priorFollowers.Length
                    Actor priorF = priorFollowers[p]
                    If priorF && priorF != akActor && priorF.GetFactionRank(cffRepair) < 0
                        priorF.AddToFaction(cffRepair)
                        priorF.SetFactionRank(cffRepair, 0)
                        repaired += 1
                    EndIf
                    p += 1
                EndWhile
                If repaired > 0
                    DebugMsg("Repaired CurrentFollowerFaction on " + repaired + " prior follower(s) after vanilla SetFollower for " + akActor.GetDisplayName())
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

    ; Make essential if enabled (default on). Essential is applied via a quest
    ; ReferenceAlias slot (MakeActorEssential) — works on templated/generic NPCs
    ; and live, unlike the ActorBase kEssential flag. WasEssential records
    ; whether the NPC was ALREADY essential by record (base flag) at recruit, so
    ; dismiss won't strip a Lydia-class record-essential NPC's own status.
    SeverActionsNativeExt.Native_SetWasEssential(akActor, SeverActionsNative.Native_IsEssential(akActor))
    Bool essentialEnabled = !SeverActionsNativeExt.Native_GetEssentialOff(akActor)
    If essentialEnabled
        MakeActorEssential(akActor)
        DebugMsg("Set essential (alias) for " + akActor.GetDisplayName())
    EndIf

    ; Notify quest awareness store — seeds SECONDHAND awareness of active quests
    SeverActionsNative.Native_OnFollowerRecruited(akActor)

    ; Update the roster string for prompt template access
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

    ; --- Healer role cleanup (idempotent — no-op if not a healer) ---
    ; Removes spells, faction membership, and the native poll registration so
    ; a dismissed follower doesn't continue receiving HealerCast events.
    RemoveHealerRole(akActor)

    ; --- Our own tracking cleanup (always, regardless of framework) ---
    SeverActionsNative.Native_SetIsFollower(akActor, false)
    StorageUtil.SetIntValue(akActor, KEY_DISMISSED, 1)
    StorageUtil.SetFloatValue(akActor, KEY_DISMISS_GT, GetGameTimeInSeconds())

    ; T1-B: capture wasEssential BEFORE Native_ClearFollowerData wipes
    ; the FollowerData entry. We need this value to decide whether to
    ; restore non-essential status further down — the post-cleanup read
    ; would always see false (default) and incorrectly clear Essential
    ; on every dismiss, including NPCs who were Essential by record.
    ; Reviewer-flagged on PR #120.
    Bool wasEssentialAtRecruit = SeverActionsNativeExt.Native_GetWasEssential(akActor)

    SeverActionsNative.Native_ClearFollowerData(akActor)

    ; Remove from our faction
    If SeverActions_FollowerFaction
        akActor.RemoveFromFaction(SeverActions_FollowerFaction)
    EndIf
    RemoveBardAudienceExclusion(akActor)

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
    If SeverActionsNativeExt.Native_GetRecruitedViaSerana(akActor)
        DebugMsg("Serana DLC dismiss: " + akActor.GetDisplayName())
        DismissSerana(akActor)
        ; T1-B: native source of truth.
        SeverActionsNativeExt.Native_SetRecruitedViaSerana(akActor, false)

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

        ; Restore original AI values, but NEVER lower relationship rank on
        ; dismiss. Two reasons:
        ;  1. Modded followers who shipped at rank 3 from the start (Inigo,
        ;     Lucien, etc.) got their rank stored correctly on recruit, but
        ;     if KEY_ORIG_RELRANK ever got cleared (wholesale-remove path
        ;     line ~2109, cosave revert, save/load timing), the GetIntValue
        ;     default of 0 silently dropped them to neutral on dismiss.
        ;  2. Generic NPCs we bumped from 0→3 to recruit them — narratively
        ;     the recruitment was a positive experience and there's no
        ;     reason for dismiss to undo their friendship with the player.
        ; Take the MAX of (stored original, current rank). Stored-rank
        ; defaults to currentRank instead of 0 so a missing entry doesn't
        ; trigger any change at all.
        Int currentRelRank = akActor.GetRelationshipRank(Game.GetPlayer())
        Int origRelRank = StorageUtil.GetIntValue(akActor, KEY_ORIG_RELRANK, currentRelRank)
        Int finalRelRank = origRelRank
        If currentRelRank > finalRelRank
            finalRelRank = currentRelRank
        EndIf
        If finalRelRank != currentRelRank
            akActor.SetRelationshipRank(Game.GetPlayer(), finalRelRank)
        EndIf
        Float origAggression = StorageUtil.GetFloatValue(akActor, KEY_ORIG_AGGRESSION, -1.0)
        Float origConfidence = StorageUtil.GetFloatValue(akActor, KEY_ORIG_CONFIDENCE, -1.0)
        If origAggression >= 0.0
            akActor.SetAV("Aggression", origAggression)
        EndIf
        If origConfidence >= 0.0
            akActor.SetAV("Confidence", origConfidence)
        EndIf

        ; Restore original combat style form if we overrode it.
        ; T1-B: native source of truth.
        Form origCSForm = SeverActionsNativeExt.Native_GetOrigCombatStyleForm(akActor)
        If origCSForm
            CombatStyle origCS = origCSForm as CombatStyle
            ActorBase dismissBase = akActor.GetActorBase()
            If origCS && dismissBase
                dismissBase.SetCombatStyle(origCS)
            EndIf
            SeverActionsNativeExt.Native_SetOrigCombatStyleForm(akActor, None)
        EndIf

        ; Stop our follow package and send home.
        ; Pass evaluateAfter=false to avoid a zero-package EvaluatePackage gap —
        ; SendHome will apply the home sandbox and eval there.
        SeverActions_Follow followSys = GetFollowScript()
        If followSys
            followSys.CompanionStopFollowing(akActor, false)
        EndIf
        If sendHome
            SendHome(akActor)
        EndIf
    EndIf

    ; Clear waiting state — BUT NOT if we just applied home sandbox.
    ; ApplyHomeSandbox sets WaitingForPlayer=2 so the CK sandbox package stays active.
    ; Clobbering it to 0 here was causing the engine to drop the sandbox on re-eval,
    ; producing the FF-prefix fallback "stand in place" package.
    Int homeSlot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)
    If homeSlot < 0
        akActor.SetAV("WaitingForPlayer", 0)
    EndIf

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

    ; Remove our Essential alias slot on dismiss. Record-essential NPCs
    ; (wasEssentialAtRecruit == true, e.g. Lydia) keep their own base-flag
    ; essential; for everyone else also clear any legacy base-flag so the old
    ; kEssential mechanism can't leave them essential after dismiss.
    ; (wasEssentialAtRecruit was snapshotted before Native_ClearFollowerData
    ; wiped the FollowerData entry — it reads false post-clear otherwise.)
    ClearActorEssential(akActor)
    If !wasEssentialAtRecruit
        SeverActionsNative.Native_ClearEssential(akActor)
        DebugMsg("Restored non-essential for " + akActor.GetDisplayName())
    EndIf

    DebugMsg("Unregistered follower: " + akActor.GetDisplayName())

    ; Update the roster string for prompt template access
EndFunction

Bool Function IsRegisteredFollower(Actor akActor)
    {Phase 4B: reads from FollowerDataStore (native cosave) — the single source
     of truth for follower roster status. Was previously a StorageUtil read,
     which split-brained whenever Papyrus and C++ writes interleaved.}
    If !akActor
        Return false
    EndIf
    Return SeverActionsNativeExt.Native_GetIsFollower(akActor)
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
    ; Shared loop index across the three source blocks. Hoisting to
    ; function scope here so the Phase 3 native cell-scan refactor
    ; doesn't shadow a block-scoped declaration inside Source 1.
    Int i = 0

    ; Source 1: Native cosave — all tracked followers regardless of cell
    ; Filter to only active followers (isFollower=true). Dismissed NPCs with homes
    ; are returned by GetDismissedWithHomes() instead.
    Actor[] nativeFollowers = SeverActionsNative.Native_GetAllTrackedFollowers()
    If nativeFollowers
        i = 0
        While i < nativeFollowers.Length
            If nativeFollowers[i] && nativeFollowers[i] != player && IsRegisteredFollower(nativeFollowers[i])
                result = PapyrusUtil.PushActor(result, nativeFollowers[i])
            EndIf
            i += 1
        EndWhile
    EndIf

    ; Source 2: Scan current cell for registered followers (catches newly detected ones
    ; not yet in the cosave, e.g. first session after recruiting via vanilla dialogue).
    ; Phase 3 perf: replaces playerCell.GetNumRefs(43) + GetNthRef + per-ref
    ; IsDead/Commanded/IsPlayerRef filters with a single native cell-scan
    ; call that returns the same pre-filtered list. Tight C++ loop instead
    ; of 60-300 Papyrus VM dispatches in a populated city cell.
    Actor[] cellActors = SeverActionsNativeExt.Native_ScanPlayerCellForLiveActors()
    Int numRefs2 = cellActors.Length
    i = 0
    While i < numRefs2
        Actor actorRef = cellActors[i]
        If actorRef && IsRegisteredFollower(actorRef)
            If !ActorInArray(result, actorRef)
                result = PapyrusUtil.PushActor(result, actorRef)
            EndIf
        EndIf
        i += 1
    EndWhile

    ; Source 3: Check follower alias slots (catches followers in other cells
    ; that may not be in the cosave yet)
    SeverActions_Follow followSys = GetFollowScript()
    If followSys && followSys.FollowerSlots
        i = 0
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

; =============================================================================
; RELATIONSHIP HELPERS — Phase 4B (split-brain refactor)
; =============================================================================
; All four relationship values (rapport/trust/loyalty/mood) live in the native
; FollowerDataStore cosave as the single source of truth. These thin wrappers
; route every read and write through the native API so:
;   1. The native store can't drift from "what Papyrus thinks" (the old bug).
;   2. Clamping is consistent — done once in C++ instead of per-helper here.
;   3. Modify* is atomic under FollowerData's mutex; no read-modify-write races
;      between OnUpdate ticks and LLM callbacks setting deltas.
; Callers continue to use these helpers exactly as before — only the body changed.

Function ModifyRapport(Actor akActor, Float amount)
    Float newVal = SeverActionsNativeExt.Native_ModifyRapport(akActor, amount)
    DebugMsg(akActor.GetDisplayName() + " rapport -> " + newVal + " (" + amount + ")")
EndFunction

Function ModifyTrust(Actor akActor, Float amount)
    SeverActionsNativeExt.Native_ModifyTrust(akActor, amount)
EndFunction

Function ModifyLoyalty(Actor akActor, Float amount)
    SeverActionsNativeExt.Native_ModifyLoyalty(akActor, amount)
EndFunction

Function ModifyMood(Actor akActor, Float amount)
    SeverActionsNativeExt.Native_ModifyMood(akActor, amount)
EndFunction

Function SetRapport(Actor akActor, Float value)
    SeverActionsNativeExt.Native_SetRapport(akActor, value)
EndFunction

Function SetTrust(Actor akActor, Float value)
    SeverActionsNativeExt.Native_SetTrust(akActor, value)
EndFunction

Function SetLoyalty(Actor akActor, Float value)
    SeverActionsNativeExt.Native_SetLoyalty(akActor, value)
EndFunction

Function SetMood(Actor akActor, Float value)
    SeverActionsNativeExt.Native_SetMood(akActor, value)
EndFunction

Function SyncRelationshipToNative(Actor akActor)
    {Deprecated since Phase 4B — every Set/Modify already writes the native
     store directly, so there's nothing left to sync. Kept as a no-op for any
     external callers still in the wild; safe to inline-delete later.}
EndFunction

Function SyncAllRelationshipsOnLoad(Actor[] followers)
    {Deprecated since Phase 4B — native FollowerDataStore is the source of
     truth from cosave load. No-op; safe to delete on the next cleanup pass.}
EndFunction

Float Function GetRapport(Actor akActor)
    Return SeverActionsNative.Native_GetRapport(akActor)
EndFunction

Float Function GetTrust(Actor akActor)
    Return SeverActionsNative.Native_GetTrust(akActor)
EndFunction

Float Function GetLoyalty(Actor akActor)
    Return SeverActionsNative.Native_GetLoyalty(akActor)
EndFunction

Float Function GetMood(Actor akActor)
    Return SeverActionsNative.Native_GetMood(akActor)
EndFunction

; =============================================================================
; AUTOMATIC RELATIONSHIP ASSESSMENT (LLM-based)
; =============================================================================

Function CheckRelationshipAssessments(Actor[] followers)
    {Check if any follower is due for an automatic relationship assessment.
     Fires at most ONE assessment per tick to avoid flooding the LLM queue.
     Each follower has a per-NPC randomized next-eligible time (min/max range).
     Only followers in the same cell as the player are assessed.
     Picks the most overdue follower if multiple are past their threshold.
     Roster passed in by the OnUpdate tick to avoid a redundant scan.}
    If AssessmentInProgress
        Return
    EndIf

    Actor player = Game.GetPlayer()
    Cell playerCell = player.GetParentCell()
    If !playerCell
        Return
    EndIf

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

    ; Skip if user didn't install the Follower prompt module via FOMOD —
    ; otherwise SkyrimNet logs a noisy "prompt not found" error every cycle.
    If !SeverActionsNative.Native_IsPromptAvailable("sever_relationship_assess")
        DebugMsg("Relationship assessment skipped: sever_relationship_assess.prompt not installed")
        Return
    EndIf

    Int result = SkyrimNetApi.SendCustomPromptToLLM("sever_relationship_assess", "sever_background", contextJson, \
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

    ; T1-B: dedup watermarks live in FollowerData now (native source of truth).
    If lastEventId > 0
        SeverActionsNativeExt.Native_SetLastAssessEventId(akActor, lastEventId)
    EndIf
    If lastMemoryId > 0
        SeverActionsNativeExt.Native_SetLastAssessMemoryId(akActor, lastMemoryId)
    EndIf
    If lastDiaryId > 0
        SeverActionsNativeExt.Native_SetLastAssessDiaryId(akActor, lastDiaryId)
    EndIf

    ; T1-B: native is the sole source of truth for the player blurb now.
    ; Phase 5b's transitional StorageUtil mirror is retired — any prompt
    ; still reading "SeverFollower_PlayerBlurb" via papyrus_util should
    ; switch to a native decorator or call Native_GetPlayerBlurb directly.
    If blurb != ""
        SeverActionsNativeExt.Native_SetPlayerBlurb(akActor, blurb)
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
    SeverActionsNativeExt.Native_SetInteractionTime(akActor, GetGameTimeInSeconds())

    ; Build summary for debug log only — do NOT register as a SkyrimNet event.
    ; Mechanics text (e.g. "rapport +3") leaks into get_recent_events and causes
    ; the LLM to write gameplay-meta diary entries like "Feris's rapport went up."
    ; The blurb at SeverFollower_PlayerBlurb is the narrative-facing output.
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

    DebugMsg(summary)
EndFunction

; =============================================================================
; NPC REPUTATION ASSESSMENT (LLM-based, milestone-triggered)
; =============================================================================
; Fires when a non-follower NPC's familiarity tier changes (C++ sends ModEvent).
; Generates an in-character impression blurb via SendCustomPromptToLLM.
; The blurb is stored per-NPC and read by the character_bio template.

Event OnReputationAssessRequest(String eventName, String strArg, Float numArg, Form sender)
    {C++ player_familiarity decorator fires this when tier changes or fame changes for an NPC.
     Assessment queue is managed in C++ — Papyrus pops one at a time via callback chain.}
    If ReputationAssessInProgress
        Return  ; Current assessment will chain to next when done
    EndIf
    ProcessNextReputationAssessment()
EndEvent

Function ProcessNextReputationAssessment()
    {Pop the next NPC from the C++ reputation assessment queue and fire LLM call.
     Chains: OnReputationAssessResult calls this again after each completion.}
    Actor npcActor = SeverActionsNative.Native_PopReputationAssessRequestActor()
    If !npcActor
        Return  ; Queue empty (or popped FormID failed to resolve)
    EndIf

    If npcActor.IsDead()
        Debug.Trace("[SeverActions] Reputation assessment: skipping dead actor " + npcActor.GetDisplayName())
        ProcessNextReputationAssessment()  ; Skip invalid, try next
        Return
    EndIf

    ; Skip followers — they use the relationship assessment system instead
    If IsRegisteredFollower(npcActor)
        Debug.Trace("[SeverActions] Reputation assessment: skipping follower " + npcActor.GetDisplayName())
        ProcessNextReputationAssessment()  ; Skip follower, try next
        Return
    EndIf

    ; Gate: MCM toggle (PrismaUI: "NPC Reputation Blurbs") + FOMOD prompt presence.
    ; sever_reputation_assess ships in the Familiarity prompt module which is
    ; optional — if user skipped it, IsPromptAvailable returns false and we
    ; skip silently. Drains the next queue item so the chain doesn't stall.
    If !AutoNPCReputation || !SeverActionsNative.Native_IsPromptAvailable("sever_reputation_assess")
        DebugMsg("Reputation assessment skipped (toggle off or prompt missing) for " + npcActor.GetDisplayName())
        ProcessNextReputationAssessment()
        Return
    EndIf

    ReputationAssessInProgress = true
    PendingReputationActor = npcActor

    ; Round-trip through the Actor's FormID for the prompt context. The
    ; sever_reputation_assess template reads it back via formid_to_uuid(),
    ; which is a SkyrimNet decorator that handles signed/unsigned correctly
    ; on its side — the sign hazard the Actor-returning native was added
    ; to avoid is specifically Papyrus's Game.GetForm(Int), which we no
    ; longer call here.
    Int formId = npcActor.GetFormID()
    String contextJson = "{\"npcFormId\":" + formId + "}"

    Int result = SkyrimNetApi.SendCustomPromptToLLM("sever_reputation_assess", "sever_background", contextJson, \
        Self as Quest, "SeverActions_FollowerManager", "OnReputationAssessResult")

    If result < 0
        ReputationAssessInProgress = false
        Debug.Trace("[SeverActions] Reputation assessment failed for " + npcActor.GetDisplayName() + ", code " + result)
        ProcessNextReputationAssessment()  ; Try next in queue
    Else
        Debug.Trace("[SeverActions] Reputation assessment queued for " + npcActor.GetDisplayName())
    EndIf
EndFunction

Function OnReputationAssessResult(String response, Int success)
    {Callback from SendCustomPromptToLLM for reputation assessment.
     Stores the LLM-generated impression blurb per NPC for character_bio injection.
     Chains to ProcessNextReputationAssessment to drain the queue.}
    ReputationAssessInProgress = false

    If success != 1
        Debug.Trace("[SeverActions] Reputation assessment LLM failed: " + response)
        ProcessNextReputationAssessment()
        Return
    EndIf

    Actor npcActor = PendingReputationActor
    If !npcActor
        Debug.Trace("[SeverActions] Reputation assessment: pending actor is None")
        ProcessNextReputationAssessment()
        Return
    EndIf

    ; Trim whitespace — LLM may add leading/trailing spaces or newlines
    String blurb = StringUtil.Substring(response, 0)

    ; Skip "NONE" responses (NPC has no reputation data to warrant an impression)
    If blurb == "NONE" || blurb == "" || blurb == "none" || blurb == "None"
        Debug.Trace("[SeverActions] Reputation assessment: no reputation data for " + npcActor.GetDisplayName())
        ProcessNextReputationAssessment()
        Return
    EndIf

    ; Store the blurb keyed to the NPC actor
    ; The character_bio template reads this via papyrus_util("GetStringValue", actorUUID, "SeverFamiliarity_Blurb", "")
    StorageUtil.SetStringValue(npcActor, "SeverFamiliarity_Blurb", blurb)
    Debug.Trace("[SeverActions] Reputation blurb stored for " + npcActor.GetDisplayName())

    ; Process next in queue (callback chain)
    ProcessNextReputationAssessment()
EndFunction

; OnFamiliarityTimestamp was removed in the FamiliarityStore refactor.
; The blurb-milestone check (first dialogue + every +100 lines) now lives
; entirely in C++ — see SkyrimNetBridge::player_familiarity decorator,
; which consults FamiliarityStore (cosave 'FAML') for the high-water mark.
; The legacy StorageUtil keys SeverFamiliarity_LastSeenGT (a dead write —
; nothing ever read it) and SeverFamiliarity_BlurbAtCount (superseded by
; FamiliarityStore.lastBlurbAtCount) are no longer used.

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

Function CheckInterFollowerAssessments(Actor[] followers)
    {Check if any follower is due for an inter-follower relationship assessment.
     Fires at most ONE assessment per tick. No same-cell requirement — followers
     form opinions based on shared events and memories regardless of proximity.
     Requires at least 2 followers to have pairs to assess. Roster passed in by
     the OnUpdate tick to avoid a redundant scan.}
    If InterFollowerAssessmentInProgress
        Return
    EndIf

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
        FireInterFollowerAssessment(bestCandidate, followers)
    EndIf
EndFunction

Function FireInterFollowerAssessment(Actor akActor, Actor[] followers)
    {Send the inter-follower relationship assessment prompt to the LLM.
     Builds a context JSON with the assessor's FormID and all other party members'
     FormIDs along with current affinity/respect values. Roster passed in by the
     caller (CheckInterFollowerAssessments) to avoid a redundant scan.}
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

    ; Skip if user didn't install the Follower prompt module.
    If !SeverActionsNative.Native_IsPromptAvailable("sever_relationship_interfollower")
        DebugMsg("Inter-follower assessment skipped: sever_relationship_interfollower.prompt not installed")
        Return
    EndIf

    Int result = SkyrimNetApi.SendCustomPromptToLLM("sever_relationship_interfollower", "sever_background", contextJson, \
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
    ; T1-B: inter-assess dedup watermarks in FollowerData (native source of truth).
    If lastEventId > 0
        SeverActionsNativeExt.Native_SetLastInterAssessEventId(akActor, lastEventId)
    EndIf
    If lastMemoryId > 0
        SeverActionsNativeExt.Native_SetLastInterAssessMemoryId(akActor, lastMemoryId)
    EndIf
    If lastDiaryId > 0
        SeverActionsNativeExt.Native_SetLastInterAssessDiaryId(akActor, lastDiaryId)
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

            ; T1-A.1: native-only write. SeverFollower_Affinity_/Respect_/Blurb_
            ; StorageUtil mirror dropped — FollowerDataStore::PairRelationship
            ; is the single source of truth. Native_SetPairRelationship clamps
            ; affinity to [-100,100] and respect to [0,100] internally.
            SeverActionsNative.Native_SetPairRelationship(akActor, targetActor, newAffinity, newRespect, blurb)

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

        ; No SkyrimNet event — mechanics text ("aff+2 res-1") would leak into
        ; get_recent_events and pollute diary/memory generation with gameplay meta.
        ; Blurbs are stored per-pair for narrative use; opinions string is bio-facing.
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

Int Function FindUnescapedQuote(String s, Int startIdx)
    {Find the next unescaped " in s starting at startIdx, returning its index or -1.
     A \" sequence is skipped; \\ counts as an escaped backslash (so the next char
     is treated normally). Required to safely parse JSON written by C++ via
     CosaveUtils::JsonEscape, which encodes embedded quotes as \".}
    Int len = StringUtil.GetLength(s)
    Int i = startIdx
    While i < len
        String c = StringUtil.GetNthChar(s, i)
        If c == "\""
            Return i
        ElseIf c == "\\"
            i += 2  ; skip the escaped char
        Else
            i += 1
        EndIf
    EndWhile
    Return -1
EndFunction

String Function UnescapeJsonString(String s)
    {Decode the JSON escape sequences our C++ writers emit. Papyrus string literals
     only support \" and \\, so we only fully decode those two plus \/ — the
     control-char escapes (\n \t \r) get preserved literally, which is acceptable:
     summary text rendered through SkyrimNet still reads cleanly and nothing is
     truncated. Fast-path returns the original string when no backslash is present.}
    If StringUtil.Find(s, "\\") < 0
        Return s
    EndIf
    Int len = StringUtil.GetLength(s)
    String result = ""
    Int i = 0
    While i < len
        String c = StringUtil.GetNthChar(s, i)
        If c == "\\" && (i + 1) < len
            String nx = StringUtil.GetNthChar(s, i + 1)
            If nx == "\""
                result += "\""
                i += 2
            ElseIf nx == "\\"
                result += "\\"
                i += 2
            ElseIf nx == "/"
                result += "/"
                i += 2
            Else
                ; Unknown / unsupported escape — preserve verbatim
                result += c + nx
                i += 2
            EndIf
        Else
            result += c
            i += 1
        EndIf
    EndWhile
    Return result
EndFunction

String Function ExtractJsonStringAt(String json, String jsonKey, Int searchStart)
    {Extract a string value from a JSON string, searching from a specific position.
     Looks for "key":"value" pattern and returns the value between quotes. Honors
     backslash escaping (\") and decodes JSON escapes so callers receive the
     original text — previously this scanned for the next bare " and truncated
     any summary containing an escaped quote.}
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

    Int endQuote = FindUnescapedQuote(json, valStart)
    If endQuote < 0 || endQuote <= valStart
        Return ""
    EndIf

    Return UnescapeJsonString(StringUtil.Substring(json, valStart, endQuote - valStart))
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
            ; T1-A.1: native source of truth for pair relationship.
            Float aff = SeverActionsNative.Native_GetPairAffinity(akActor, target)
            Float resp = SeverActionsNative.Native_GetPairRespect(akActor, target)

            ; Only include if non-default values exist
            If aff != 0.0 || resp != 0.0
                String targetName = target.GetDisplayName()

                ; Prefer the LLM-generated blurb — it's unique and contextual
                String blurb = SeverActionsNativeExt.Native_GetPairBlurb(akActor, target)

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

    ; T1-A.2: native source of truth. Surfaced into prompts via the
    ; sever_companion_opinions SkyrimNet decorator.
    SeverActionsNativeExt.Native_SetCompanionOpinions(akActor, opinions)
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
            ; T1-A.1: native source of truth for pair relationship.
            Float aff = SeverActionsNative.Native_GetPairAffinity(akActor, target)
            Float resp = SeverActionsNative.Native_GetPairRespect(akActor, target)

            ; Only include if non-default values exist
            If aff != 0.0 || resp != 0.0
                String targetName = target.GetDisplayName()

                ; Prefer the LLM-generated blurb — it's unique and contextual
                String blurb = SeverActionsNativeExt.Native_GetPairBlurb(akActor, target)

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

    ; T1-A.2: native source of truth. Surfaced into prompts via the
    ; sever_companion_opinions SkyrimNet decorator.
    SeverActionsNativeExt.Native_SetCompanionOpinions(akActor, opinions)
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

; T1-A.2: SyncFollowerRoster removed. It populated the SeverActions_FollowerRoster
; StorageUtil global, but nothing in the codebase ever read that key —
; prompts, scripts, decorators, and YAMLs were all checked. Pure dead
; write that ran on every recruit / dismiss / game load. Six callers
; (line 777 on load + four dismiss/register paths) also retired.

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
                    ; T1-A.1 save-compat: also import the blurb. Pre-PR saves
                    ; stored it in StorageUtil only; without this line,
                    ; upgraders see all LLM-generated pair narratives vanish
                    ; (Native_GetPairBlurb returns "" until the LLM regenerates
                    ; on next assess). Reviewer-flagged on PR #119.
                    String blurb = StorageUtil.GetStringValue(source, "SeverFollower_Blurb_" + targetFormId, "")
                    ; Only sync if non-default values exist
                    If affinity != 0.0 || respect != 50.0 || blurb != ""
                        SeverActionsNative.Native_SetPairRelationship(source, target, affinity, respect, blurb)
                    EndIf
                EndIf
                j += 1
            EndWhile
        EndIf
        i += 1
    EndWhile
    DebugMsg("Synced inter-follower pair relationships to native store")
EndFunction

Function SyncFollowerScalarsOnLoad(Actor[] followers)
    {T1-B one-shot migration: copy the 11 per-follower SeverFollower_*/
     SeverActions_* StorageUtil scalars + watermarks into FollowerData.
     Called once per save from the OnGameLoad path, sentinel-gated by
     SeverActions_T1BMigrationDone so it's idempotent. Each field is
     skipped if its current native value already differs from the
     default — preserves anything written via the v10 cosave on a save
     that's already been through one upgrade.}
    Int i = 0
    While i < followers.Length
        Actor a = followers[i]
        If a
            ; Dedup watermarks
            If SeverActionsNativeExt.Native_GetLastAssessEventId(a) == 0 \
                && StorageUtil.HasIntValue(a, "SeverFollower_LastAssessEventId")
                SeverActionsNativeExt.Native_SetLastAssessEventId(a, \
                    StorageUtil.GetIntValue(a, "SeverFollower_LastAssessEventId", 0))
            EndIf
            If SeverActionsNativeExt.Native_GetLastAssessMemoryId(a) == 0 \
                && StorageUtil.HasIntValue(a, "SeverFollower_LastAssessMemoryId")
                SeverActionsNativeExt.Native_SetLastAssessMemoryId(a, \
                    StorageUtil.GetIntValue(a, "SeverFollower_LastAssessMemoryId", 0))
            EndIf
            If SeverActionsNativeExt.Native_GetLastAssessDiaryId(a) == 0 \
                && StorageUtil.HasIntValue(a, "SeverFollower_LastAssessDiaryId")
                SeverActionsNativeExt.Native_SetLastAssessDiaryId(a, \
                    StorageUtil.GetIntValue(a, "SeverFollower_LastAssessDiaryId", 0))
            EndIf
            If SeverActionsNativeExt.Native_GetLastInterAssessEventId(a) == 0 \
                && StorageUtil.HasIntValue(a, "SeverFollower_LastInterAssessEventId")
                SeverActionsNativeExt.Native_SetLastInterAssessEventId(a, \
                    StorageUtil.GetIntValue(a, "SeverFollower_LastInterAssessEventId", 0))
            EndIf
            If SeverActionsNativeExt.Native_GetLastInterAssessMemoryId(a) == 0 \
                && StorageUtil.HasIntValue(a, "SeverFollower_LastInterAssessMemoryId")
                SeverActionsNativeExt.Native_SetLastInterAssessMemoryId(a, \
                    StorageUtil.GetIntValue(a, "SeverFollower_LastInterAssessMemoryId", 0))
            EndIf
            If SeverActionsNativeExt.Native_GetLastInterAssessDiaryId(a) == 0 \
                && StorageUtil.HasIntValue(a, "SeverFollower_LastInterAssessDiaryId")
                SeverActionsNativeExt.Native_SetLastInterAssessDiaryId(a, \
                    StorageUtil.GetIntValue(a, "SeverFollower_LastInterAssessDiaryId", 0))
            EndIf
            ; Bool flags
            If StorageUtil.GetIntValue(a, "SeverFollower_HomeSceneSuspended", 0) == 1
                SeverActionsNativeExt.Native_SetHomeSceneSuspended(a, true)
            EndIf
            If StorageUtil.GetIntValue(a, "SeverFollower_LeaveWarned", 0) == 1
                SeverActionsNativeExt.Native_SetLeaveWarned(a, true)
            EndIf
            If StorageUtil.GetIntValue(a, "SeverActions_EssentialOff", 0) == 1
                SeverActionsNativeExt.Native_SetEssentialOff(a, true)
            EndIf
            If StorageUtil.GetIntValue(a, "SeverActions_WasEssential", 0) == 1
                SeverActionsNativeExt.Native_SetWasEssential(a, true)
            EndIf
            If StorageUtil.GetIntValue(a, "SeverActions_RecruitedViaSerana", 0) == 1
                SeverActionsNativeExt.Native_SetRecruitedViaSerana(a, true)
            EndIf
            ; Death timestamp (float)
            If SeverActionsNativeExt.Native_GetDeathTime(a) == 0.0 \
                && StorageUtil.HasFloatValue(a, "SeverFollower_DeathTime")
                SeverActionsNativeExt.Native_SetDeathTime(a, \
                    StorageUtil.GetFloatValue(a, "SeverFollower_DeathTime", 0.0))
            EndIf
            ; Original combat style (Form)
            If !SeverActionsNativeExt.Native_GetOrigCombatStyleForm(a) \
                && StorageUtil.HasFormValue(a, "SeverFollower_OrigCombatStyleForm")
                SeverActionsNativeExt.Native_SetOrigCombatStyleForm(a, \
                    StorageUtil.GetFormValue(a, "SeverFollower_OrigCombatStyleForm"))
            EndIf
        EndIf
        i += 1
    EndWhile
    DebugMsg("T1-B: Synced " + followers.Length + " followers' scalar state into native store")
EndFunction

Function SyncFollowerStringBlobsOnLoad(Actor[] followers)
    {T1-A.2 one-shot migration: copy the two per-follower string blobs
     (SeverFollower_CompanionOpinions, SeverFollower_LifeEventHistory)
     from StorageUtil into native FollowerData. Idempotent — runs only
     when the native field is still empty AND the StorageUtil key has
     a value. Sentinel-gated by SeverActions_T1A2MigrationDone.}
    Int i = 0
    While i < followers.Length
        Actor a = followers[i]
        If a
            If SeverActionsNativeExt.Native_GetCompanionOpinions(a) == "" \
                && StorageUtil.HasStringValue(a, "SeverFollower_CompanionOpinions")
                SeverActionsNativeExt.Native_SetCompanionOpinions(a, \
                    StorageUtil.GetStringValue(a, "SeverFollower_CompanionOpinions", ""))
            EndIf
            If SeverActionsNativeExt.Native_GetLifeEventHistory(a) == "" \
                && StorageUtil.HasStringValue(a, "SeverFollower_LifeEventHistory")
                SeverActionsNativeExt.Native_SetLifeEventHistory(a, \
                    StorageUtil.GetStringValue(a, "SeverFollower_LifeEventHistory", ""))
            EndIf
        EndIf
        i += 1
    EndWhile
    DebugMsg("T1-A.2: Synced " + followers.Length + " followers' string-blob state into native store")
EndFunction

Function SyncFollowerStringLabelsOnLoad(Actor[] followers)
    {T1-A.3 one-shot migration: copy the last three Papyrus-owned per-
     follower StorageUtil strings (LifeSummary + WorkLocation +
     PlayLocation display labels) into FollowerData. Sentinel-gated by
     SeverActions_T1A3MigrationDone. Idempotent — imports only when
     the native field is empty AND the StorageUtil key has a value.}
    Int i = 0
    While i < followers.Length
        Actor a = followers[i]
        If a
            If SeverActionsNativeExt.Native_GetLifeSummary(a) == "" \
                && StorageUtil.HasStringValue(a, "SeverFollower_LifeSummary")
                SeverActionsNativeExt.Native_SetLifeSummary(a, \
                    StorageUtil.GetStringValue(a, "SeverFollower_LifeSummary", ""))
            EndIf
            If SeverActionsNativeExt.Native_GetWorkLocationName(a) == "" \
                && StorageUtil.HasStringValue(a, "SeverFollower_WorkLocation")
                SeverActionsNativeExt.Native_SetWorkLocationName(a, \
                    StorageUtil.GetStringValue(a, "SeverFollower_WorkLocation", ""))
            EndIf
            If SeverActionsNativeExt.Native_GetPlayLocationName(a) == "" \
                && StorageUtil.HasStringValue(a, "SeverFollower_PlayLocation")
                SeverActionsNativeExt.Native_SetPlayLocationName(a, \
                    StorageUtil.GetStringValue(a, "SeverFollower_PlayLocation", ""))
            EndIf
        EndIf
        i += 1
    EndWhile
    DebugMsg("T1-A.3: Synced " + followers.Length + " followers' string-label state into native store")
EndFunction

; =============================================================================
; FOLLOWER BANTER
; =============================================================================

Function CheckFollowerBanter(Actor[] followers)
    {Game-time based banter check. Called from OnUpdate every 30s.
     Only gated by its own BanterInProgress flag and game-time cooldown —
     NOT blocked by assessment or off-screen life flags. Roster passed in by
     the OnUpdate tick to avoid a redundant scan.}

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
        Float folMood = SeverActionsNative.Native_GetMood(fol)
        String folStyle = GetCombatStyle(fol)
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
                ; T1-A.1: native source of truth for the pair blurb too.
                String blurbAB = SeverActionsNativeExt.Native_GetPairBlurb(a, b)
                String blurbBA = SeverActionsNativeExt.Native_GetPairBlurb(b, a)

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

    ; Skip if prompt module not installed.
    If !SeverActionsNative.Native_IsPromptAvailable("sever_follower_banter")
        BanterInProgress = false
        DebugMsg("Follower banter skipped: sever_follower_banter.prompt not installed")
        Return
    EndIf

    Int result = SkyrimNetApi.SendCustomPromptToLLM("sever_follower_banter", "sever_background", contextJson, \
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
    ; Pass speaker + target + topic. The topic field is rendered by SkyrimNet's
    ; gamemaster_dialogue verbose template independent of the isContinuation
    ; flag, so we deliberately omit isContinuation here — including it makes the
    ; event log read "...(continuing conversation)" even on a fresh banter,
    ; which is misleading and (worse) leaks back into get_recent_events context
    ; where future LLM calls treat the scene as mid-conversation.
    String eventJson = "{\"speaker\":\"" + speakerName + "\",\"target\":\"" + targetName + "\",\"topic\":\"" + topicDirection + "\",\"dialogue\":\"" + speakerName + " turns to " + targetName + " — " + topicDirection + "\"}"

    SkyrimNetApi.RegisterEvent("gamemaster_dialogue", eventJson, speakerActor, targetActor)

    Debug.Notification("[Banter] " + speakerName + " -> " + targetName + ": " + banterTopic)

EndFunction

; =============================================================================
; AMBIENT NPC BANTER — non-follower / non-player pairs in the player's cell
; =============================================================================

Function CheckAmbientBanter()
    {Game-time based ambient banter check. Called from OnUpdate every 30s.
     Picks pairs of non-follower NPCs near the player and asks the LLM to
     decide whether one should speak to another (or stay silent).

     Independent from CheckFollowerBanter — its own cooldown + flag, no shared
     state. Hostile-cell guard lives in the C++ scanner: if any nearby actor
     is hostile to the player, ScanAndCache returns 0 and we just skip.}

    ; Game-time cooldown
    Float now = GetGameTimeInSeconds()
    Float nextEligible = StorageUtil.GetFloatValue(None, KEY_NEXT_AMBIENT_GT, 0.0)
    If nextEligible > 0.0 && now < nextEligible
        Return
    EndIf

    ; Skip if player is in combat (matches CheckFollowerBanter behavior)
    Actor player = Game.GetPlayer()
    If player.IsInCombat()
        Return
    EndIf

    ; C++ scan: candidate pairs of non-follower NPCs in the player's cell.
    ; Returns 0 if hostile actor present, no qualifying pairs, or empty cell.
    ; Pass 0 for all params to use defaults (hearing=2000, pair=768, max=6).
    Int pairCount = SeverActionsNativeExt.Native_AmbientBanter_ScanAndCache(0.0, 0.0, 0)
    If pairCount < 1
        Return
    EndIf

    Debug.Trace("[AmbientBanter] " + pairCount + " candidate pair(s) found")
    FireAmbientBanter(pairCount)
EndFunction

Function FireAmbientBanter(Int pairCount)
    {Dispatch the ambient-banter LLM request via the C++ native path.
     The native side builds context JSON + parses the response + assembles
     the gamemaster_dialogue eventJson entirely in nlohmann::json so UTF-8
     NPC names survive end-to-end. Issue #9 (Cyrillic mojibake) traced the
     bug to the previous Papyrus String += path; do not reintroduce.}
    AmbientBanterInProgress = true

    ; Set cooldown immediately so we don't re-fire while the LLM is in flight
    Float now = GetGameTimeInSeconds()
    StorageUtil.SetFloatValue(None, KEY_LAST_AMBIENT_GT, now)
    Float nextCooldown = Utility.RandomFloat(AmbientBanterCooldownMinHours, AmbientBanterCooldownMaxHours) * SECONDS_PER_GAME_HOUR
    StorageUtil.SetFloatValue(None, KEY_NEXT_AMBIENT_GT, now + nextCooldown)

    ; Skip if prompt module not installed (FOMOD didn't install it).
    If !SeverActionsNative.Native_IsPromptAvailable("sever_ambient_banter")
        AmbientBanterInProgress = false
        Debug.Trace("[AmbientBanter] skipped: sever_ambient_banter.prompt not installed")
        Return
    EndIf

    ; Native_AmbientBanter_FireToLLM re-runs the scan against the same cache the
    ; original Papyrus pre-scan filled (idempotent on the player's cell snapshot).
    ; Passing 0.0/0.0/0 = use the native defaults the scanner ships with.
    Int dispatched = SeverActionsNativeExt.Native_AmbientBanter_FireToLLM(0.0, 0.0, 0)

    If dispatched <= 0
        AmbientBanterInProgress = false
        If dispatched == 0
            Debug.Trace("[AmbientBanter] no pairs after re-scan (hostile cell or pairs dispersed)")
        Else
            Debug.Trace("[AmbientBanter] native dispatch failed (SkyrimNet v8 PublicAPI unavailable?)")
        EndIf
    EndIf
    ; AmbientBanterInProgress stays true while the request is in flight —
    ; OnAmbientBanterReady clears it.
EndFunction

Event OnAmbientBanterReady(string eventName, string strArg, float numArg, Form sender)
    {ModEvent handler — fires when the C++ side has either prepared a
     gamemaster_dialogue event (numArg=1.0) or decided this cycle should be
     silent / failed (numArg=0.0). All non-ASCII-bearing strings were built
     in C++; this handler does NO String += operations on names.}
    AmbientBanterInProgress = false

    If numArg < 0.5
        ; Silence cycle, parse failure, or actor resolution miss. Native has
        ; already logged the specific reason; nothing more for Papyrus to do.
        Return
    EndIf

    ; Pull pre-built event JSON + resolved actors from the native ready slot.
    ; Native built eventJson in C++ with nlohmann::json — Cyrillic / Japanese
    ; / any non-ASCII name survives intact.
    String eventJson    = SeverActionsNativeExt.Native_AmbientBanter_GetReadyEventJson()
    Actor speakerActor  = SeverActionsNativeExt.Native_AmbientBanter_GetReadySpeaker()
    Actor targetActor   = SeverActionsNativeExt.Native_AmbientBanter_GetReadyTarget()
    SeverActionsNativeExt.Native_AmbientBanter_ClearReady()

    If eventJson == "" || !speakerActor || !targetActor
        Debug.Trace("[AmbientBanter] ready slot was empty — race or stale call?")
        Return
    EndIf

    ; Hand the pre-built JSON straight to RegisterEvent. NO Papyrus concat
    ; with the NPC names anywhere along this path.
    SkyrimNetApi.RegisterEvent("gamemaster_dialogue", eventJson, speakerActor, targetActor)

    Debug.Trace("[AmbientBanter] dispatched (speaker=" + speakerActor.GetDisplayName() + ", target=" + targetActor.GetDisplayName() + ")")
EndEvent

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
                    If !SeverActionsNative.Native_GetOffscreenExcluded(follower)
                        ; Per-NPC override (set from Life Tracker page) takes
                        ; priority over the global min/max window. 0 = no override.
                        Float overrideHours = SeverActionsNative.Native_OffScreen_GetCooldownOverride(follower)
                        Float windowMaxHours = OffScreenLifeCooldownMaxHours
                        If overrideHours > 0.0
                            windowMaxHours = overrideHours
                        EndIf
                        ; Defensive floor: if a future change ever lets the
                        ; global Max be 0 (or set below Min), Utility.RandomFloat(0, 0)
                        ; returns 0 and every NPC becomes immediately eligible —
                        ; exactly the spam this PR is supposed to prevent. Keep
                        ; the stagger window at least as wide as Min.
                        If windowMaxHours < OffScreenLifeCooldownMinHours
                            windowMaxHours = OffScreenLifeCooldownMinHours
                        EndIf
                        If windowMaxHours <= 0.0
                            windowMaxHours = 1.0
                        EndIf

                        Float nextEligible = StorageUtil.GetFloatValue(follower, KEY_NEXT_LIFE_EVENT_GT, 0.0)
                        If nextEligible == 0.0
                            Float lastEvent = StorageUtil.GetFloatValue(follower, KEY_LAST_LIFE_EVENT_GT, 0.0)
                            If lastEvent == 0.0
                                ; First time we've seen this NPC. Seed nextEligible
                                ; with a random offset from now (0 .. window) so a
                                ; wave of recently-dismissed NPCs gets staggered
                                ; instead of all becoming eligible together. Persist
                                ; so the roll only happens once per NPC.
                                Float initialOffset = Utility.RandomFloat(0.0, windowMaxHours) * SECONDS_PER_GAME_HOUR
                                nextEligible = now + initialOffset
                                StorageUtil.SetFloatValue(follower, KEY_NEXT_LIFE_EVENT_GT, nextEligible)
                            Else
                                ; Legacy save where lastEvent exists but nextEligible doesn't.
                                Float legacyCooldown = OffScreenLifeCooldownMinHours
                                If overrideHours > 0.0
                                    legacyCooldown = overrideHours
                                EndIf
                                nextEligible = lastEvent + (legacyCooldown * SECONDS_PER_GAME_HOUR)
                            EndIf
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
    OffScreenLifeStartedRT = Utility.GetCurrentRealTime()
    PendingOffScreenLifeActor = akActor
    Float nowTime = GetGameTimeInSeconds()
    StorageUtil.SetFloatValue(akActor, KEY_LAST_LIFE_EVENT_GT, nowTime)
    ; Per-NPC override beats the global window. 0 = use random(min, max).
    Float fireOverrideHours = SeverActionsNative.Native_OffScreen_GetCooldownOverride(akActor)
    Float nextCooldown
    If fireOverrideHours > 0.0
        nextCooldown = fireOverrideHours * SECONDS_PER_GAME_HOUR
    Else
        nextCooldown = Utility.RandomFloat(OffScreenLifeCooldownMinHours, OffScreenLifeCooldownMaxHours) * SECONDS_PER_GAME_HOUR
    EndIf
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

    ; Skip if user didn't install the Follower prompt module.
    If !SeverActionsNative.Native_IsPromptAvailable("sever_offscreen_life")
        OffScreenLifeInProgress = false
        DebugMsg("Off-screen life skipped: sever_offscreen_life.prompt not installed")
        Return
    EndIf

    ; v3.11 — Route the LLM call through the C++ Bridge (SkyrimNet v8
    ; PublicSendCustomPromptToLLM) instead of SkyrimNetApi.SendCustomPromptToLLM.
    ; Papyrus's BSFixedString return values cap around ~1024 chars, which
    ; silently truncated mid-JSON the moment the prompt started emitting
    ; `rumorText` alongside `summary`. The C++ path keeps the full response
    ; in a std::string all the way to the parser, and fires the
    ; SeverActions_OffScreenLifeReady ModEvent (handled by OnOffScreenLifeReady
    ; below) when parsing completes. Gossip is stored in the C++ data store
    ; from inside the parser now — Papyrus no longer constructs gossip text
    ; manually (which was the source of the "rumors say the same thing as
    ; letters" duplication bug).
    Bool sent = SeverActionsNative.Native_OffScreen_RequestLifeEventLLM(akActor, contextJson, GetGameTimeInSeconds())
    If !sent
        OffScreenLifeInProgress = false
        DebugMsg("Off-screen life LLM dispatch failed for " + akActor.GetDisplayName() \
            + " (SkyrimNet v8 PublicSendCustomPromptToLLM unavailable?)")
    Else
        String home = SeverActionsNative.Native_GetHome(akActor)
        DebugMsg("Off-screen life event queued via C++ for " + akActor.GetDisplayName() + " at " + home)
    EndIf
EndFunction

Event OnOffScreenLifeReady(string eventName, string strArg, float numArg, Form sender)
    {ModEvent fired by C++ after PublicSendCustomPromptToLLM completes and the
     native parser stores events + gossip in OffScreenLifeDataStore. strArg is
     the pipe-delimited string of parsed fields (same shape the legacy Papyrus
     parser used to return), sender is the actor the events belong to.
     numArg is 1 on success, 0 on LLM failure.

     v3.11 — Replaces the old OnOffScreenLifeEvent(response, success) callback
     which ran on the Papyrus SkyrimNetApi.SendCustomPromptToLLM path. That
     path silently truncated responses near 1024 chars, which broke the moment
     the prompt started emitting `rumorText` alongside `summary`.}
    OffScreenLifeInProgress = false

    If numArg != 1.0
        DebugMsg("Off-screen life LLM failed for sender")
        Return
    EndIf

    Actor akActor = sender as Actor
    If !akActor
        ; Fall back to the stored pending actor (ModEvent.sender can be
        ; lost across the ThreadPool→game-thread hop in rare cases).
        akActor = PendingOffScreenLifeActor
    EndIf
    If !akActor
        DebugMsg("Off-screen life: sender + pending actor both None")
        Return
    EndIf

    ; If they were re-recruited while the LLM was processing, skip
    If IsRegisteredFollower(akActor)
        DebugMsg("Off-screen life: " + akActor.GetDisplayName() + " was re-recruited, skipping")
        Return
    EndIf

    String parsed = strArg
    If parsed == ""
        DebugMsg("Off-screen life: native parser returned empty for " + akActor.GetDisplayName())
        Return
    EndIf

    String actorName = akActor.GetDisplayName()
    String home = SeverActionsNative.Native_GetHome(akActor)
    Float currentGameTime = GetGameTimeInSeconds()

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

    ; Build the life summary (stored on the actor for the dialogue submodule prompt).
    ; T1-A.3: native source of truth — surfaced into prompts via the
    ; sever_life_summary decorator.
    String lifeSummary = summary1
    If summary2 != ""
        lifeSummary += " " + summary2
    EndIf
    SeverActionsNativeExt.Native_SetLifeSummary(akActor, lifeSummary)

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
        ; T1-A.2: native source of truth. Surfaced into prompts via the
        ; sever_life_event_history SkyrimNet decorator.
        SeverActionsNativeExt.Native_SetLifeEventHistory(akActor, eventHistory)
    EndIf

    ; Register as persistent events so the follower "remembers" them
    SkyrimNetApi.RegisterEvent("persistent_generic", WrapPersistentEvent(actorName + ": " + summary1), akActor, None)
    If summary2 != ""
        SkyrimNetApi.RegisterEvent("persistent_generic", WrapPersistentEvent(actorName + ": " + summary2), akActor, None)
    EndIf

    ; Note: SkyrimNet memories for the primary actor are now created directly in C++
    ; (inside Native_OffScreen_ParseLLMResponse) to bypass BSFixedString garbling
    ; that occurred when long summaries were routed through Papyrus pipe parsing.

    ; Gossip is stored in C++ directly now — Native_OffScreen_ParseLLMResponse
    ; calls AddGossip with the LLM's `rumorText` field (or a fallback name+
    ; summary when rumorText is missing). This is what fixes the v3.10 bug
    ; where rumors and letters read with identical text.

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
EndEvent

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
    {Check if a follower is excluded from off-screen life events.
     Phase 4B: reads from FollowerDataStore (offscreenExcluded flag).}
    If !akActor
        Return false
    EndIf
    Return SeverActionsNative.Native_GetOffscreenExcluded(akActor)
EndFunction

Function SetOffScreenExcluded(Actor akActor, Bool excluded)
    {Set or clear the off-screen life exclusion flag for a follower.}
    If akActor
        SeverActionsNative.Native_SetOffscreenExcluded(akActor, excluded)
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
                    If !SeverActionsNative.Native_GetOffscreenExcluded(follower)
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

                    ; Track via ArrestScript's jailed NPC list. Marker is written
                    ; first so the native-backed AddJailedNPC can pick it up.
                    StorageUtil.SetFormValue(akActor, "SeverActions_JailMarker", jailMarker)
                    ArrestScript.AddJailedNPC(akActor)

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
; SCHEDULE SYSTEM (home/work/play marker routing)
; =============================================================================

Float Function GetCurrentGameHour()
    {Return the current in-game hour as a float 0.0-23.999.}
    Float days = Utility.GetCurrentGameTime()
    Int daysInt = days as Int
    Return (days - daysInt) * 24.0
EndFunction

Int Function DetermineScheduleTypeForNow()
    {Return which schedule type (home/work/play) applies to the current game hour.}
    Float hour = GetCurrentGameHour()
    If hour >= SCHEDULE_WORK_START && hour < SCHEDULE_WORK_END
        Return SCHEDULE_WORK
    ElseIf hour >= SCHEDULE_PLAY_START && hour < SCHEDULE_PLAY_END
        Return SCHEDULE_PLAY
    Else
        Return SCHEDULE_HOME
    EndIf
EndFunction

ObjectReference Function GetScheduleAnchorForNPC(Actor akActor, Int slot, Int scheduleType)
    {Resolve the anchor marker that HomeMarker_NN should sit on right now.
     Returns WorkMarker_NN if work hours + work is set, PlayMarker_NN if play + set,
     else TrueHomeAnchor_NN (fallback for home hours or when work/play unset).}
    If scheduleType == SCHEDULE_WORK
        ObjectReference workMarker = SeverActionsNative.Native_GetWorkLoc(akActor)
        If workMarker
            Return workMarker
        EndIf
    ElseIf scheduleType == SCHEDULE_PLAY
        ObjectReference playMarker = SeverActionsNative.Native_GetPlayLoc(akActor)
        If playMarker
            Return playMarker
        EndIf
    EndIf
    ; Home fallback — use TrueHomeAnchor_NN
    If TrueHomeAnchorList && slot >= 0 && slot < 40
        Return TrueHomeAnchorList.GetAt(slot) as ObjectReference
    EndIf
    Return None
EndFunction

Function SetRoutineLocHere(Actor akActor, String kind)
    {Move the follower's Work or Play marker to the player's current position.
     kind = "work" or "play". Requires a home to have been assigned first (needs a slot).}
    If !akActor
        Return
    EndIf
    Int slot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)
    If slot < 0
        DebugMsg("SetRoutineLocHere: " + akActor.GetDisplayName() + " has no home slot — assign home first")
        Return
    EndIf

    FormList markerList = None
    If kind == "work"
        markerList = WorkMarkerList
    ElseIf kind == "play"
        markerList = PlayMarkerList
    EndIf
    If !markerList
        DebugMsg("SetRoutineLocHere: " + kind + "MarkerList not configured")
        Return
    EndIf

    ObjectReference marker = markerList.GetAt(slot) as ObjectReference
    If !marker
        DebugMsg("SetRoutineLocHere: no " + kind + " marker at slot " + slot)
        Return
    EndIf

    Actor PlayerRef = Game.GetPlayer()
    marker.MoveTo(PlayerRef)
    If kind == "work"
        SeverActionsNative.Native_SetWorkLoc(akActor, marker)
    Else
        SeverActionsNative.Native_SetPlayLoc(akActor, marker)
    EndIf

    ; Capture a human-readable name for the location so prompts can tell the
    ; NPC "you work at X" / "you relax at Y". Prefer the player's current
    ; Location (city / dungeon / landmark); fall back to the parent cell name;
    ; fall back to a generic label if neither resolves.
    String locName = ""
    Location playerLoc = PlayerRef.GetCurrentLocation()
    If playerLoc
        locName = playerLoc.GetName()
    EndIf
    If locName == ""
        Cell playerCell = PlayerRef.GetParentCell()
        If playerCell
            locName = playerCell.GetName()
        EndIf
    EndIf
    If locName == ""
        locName = "a familiar spot"
    EndIf
    ; T1-A.3: native source of truth — surfaced into prompts via
    ; sever_work_location / sever_play_location decorators.
    If kind == "work"
        SeverActionsNativeExt.Native_SetWorkLocationName(akActor, locName)
    Else
        SeverActionsNativeExt.Native_SetPlayLocationName(akActor, locName)
    EndIf

    ; Force next tick to re-evaluate — if current hour matches this schedule type,
    ; the follower should teleport to the new position within ~30s.
    StorageUtil.SetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, -99)

    DebugMsg("Set " + kind + " location for " + akActor.GetDisplayName() + " at slot " + slot + " (" + locName + ")")
    If ShowNotifications
        ; Display-only alias — internal `kind` stays "play" (matches native store keys,
        ; action names, ESP record names). UI calls it "Relax" which is clearer to users.
        String displayKind = kind
        If kind == "play"
            displayKind = "relax"
        EndIf
        Debug.Notification(akActor.GetDisplayName() + " will spend their " + displayKind + " hours here.")
    EndIf
EndFunction

Function ClearRoutineLoc(Actor akActor, String kind)
    {Clear the follower's Work or Play location.
     The marker stays where it is (harmless — schedule will route to TrueHomeAnchor instead).
     kind = "work" or "play".}
    If !akActor
        Return
    EndIf
    If kind == "work"
        SeverActionsNative.Native_ClearWorkLoc(akActor)
        StorageUtil.UnsetStringValue(akActor, "SeverFollower_WorkLocation")
    ElseIf kind == "play"
        SeverActionsNative.Native_ClearPlayLoc(akActor)
        StorageUtil.UnsetStringValue(akActor, "SeverFollower_PlayLocation")
    EndIf
    StorageUtil.SetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, -99)
    DebugMsg("Cleared " + kind + " location for " + akActor.GetDisplayName())
EndFunction

Function EnsureTrueHomeAnchorMigrated(Actor npc, Int slot)
    {Sync TrueHomeAnchor_NN to HomeMarker_NN's current position if not already done.
     One-shot per NPC. Critical for existing saves: HomeMarker_NN persisted at the real
     home across save/load, but TrueHomeAnchor_NN is a new ESP record and loaded at its
     default position in aaaMarkers holding cell. Without this, the first schedule tick
     would teleport the follower to the holding cell. Idempotent — safe to call any time.}
    If StorageUtil.GetIntValue(npc, KEY_TRUEHOME_MIGRATED, 0) != 0
        Return
    EndIf
    If !TrueHomeAnchorList || !HomeMarkerList || slot < 0 || slot >= 40
        Return
    EndIf
    ObjectReference homeMarker = HomeMarkerList.GetAt(slot) as ObjectReference
    ObjectReference trueHome = TrueHomeAnchorList.GetAt(slot) as ObjectReference
    If homeMarker && trueHome
        trueHome.MoveTo(homeMarker)
        StorageUtil.SetIntValue(npc, KEY_TRUEHOME_MIGRATED, 1)
        DebugMsg("TrueHomeAnchor migrated for " + npc.GetDisplayName() + " (slot " + slot + ")")
    EndIf
EndFunction

Function ProcessScheduleSwaps()
    {Iterate all homed NPCs that are currently dismissed. On hour transition
     (schedule type changed since last tick), MoveTo their HomeMarker_NN to the
     correct anchor (TrueHomeAnchor / WorkMarker / PlayMarker). The existing
     HomeSandbox_NN alias package keeps targeting HomeMarker — follower naturally
     re-paths when the marker teleports.
     Also runs one-shot TrueHomeAnchor migration for NPCs from pre-schedule saves.}
    If !HomeMarkerList
        Return
    EndIf
    Int targetType = DetermineScheduleTypeForNow()
    Int count = StorageUtil.FormListCount(None, KEY_HOMED_NPCS)

    Int i = 0
    While i < count
        Form entry = StorageUtil.FormListGet(None, KEY_HOMED_NPCS, i)
        Actor npc = entry as Actor
        If npc && !npc.IsDeleted() && !npc.IsPlayerTeammate()
            Int slot = SeverActionsNative.Native_GetHomeMarkerSlot(npc)
            If slot >= 0
                ; One-shot migration — MUST run before any swap logic so HomeMarker
                ; doesn't get moved to an unmigrated TrueHomeAnchor (still in holding cell).
                EnsureTrueHomeAnchorMigrated(npc, slot)

                Int lastType = StorageUtil.GetIntValue(npc, KEY_LAST_SCHEDULED_TYPE, -99)
                If lastType != targetType
                    ObjectReference homeMarker = HomeMarkerList.GetAt(slot) as ObjectReference
                    ObjectReference targetAnchor = GetScheduleAnchorForNPC(npc, slot, targetType)
                    If homeMarker && targetAnchor
                        homeMarker.MoveTo(targetAnchor)
                        StorageUtil.SetIntValue(npc, KEY_LAST_SCHEDULED_TYPE, targetType)
                        npc.EvaluatePackage()
                        DebugMsg("ScheduleSwap: " + npc.GetDisplayName() + " -> type " + targetType + " (slot " + slot + ")")
                    EndIf
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile
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

    ; Store the home location name in the native cosave (single source of truth).
    SeverActionsNative.Native_SetHome(akActor, locationName)

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

                ; Also move TrueHomeAnchor_NN — this is the "return home" anchor the
                ; schedule tick uses during sleep/home hours. HomeMarker_NN may subsequently
                ; get moved to Work/Play positions based on schedule; TrueHomeAnchor stays put.
                If TrueHomeAnchorList && slot < 40
                    ObjectReference trueHomeAnchor = TrueHomeAnchorList.GetAt(slot) as ObjectReference
                    If trueHomeAnchor
                        trueHomeAnchor.MoveTo(PlayerRef)
                        StorageUtil.SetIntValue(akActor, KEY_TRUEHOME_MIGRATED, 1)
                    EndIf
                EndIf

                ; Force the next ProcessScheduleSwaps tick to re-evaluate — marker positions
                ; changed so any currently-dismissed follower in this slot may need re-pathing.
                StorageUtil.SetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, -99)

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

    ; ── Auto-claim a bed in the home cell ─────────────────────────
    ; Scan the player's current cell for a usable bed (unowned, or owned by a
    ; non-player faction such as an inn) and set this follower as the bed's
    ; owner so the SeverActions home sandbox sleep package finds it.
    ;
    ; Inn beds ARE claimed per design — assigning an inn as home means the
    ; follower has rented a bed there. Beds owned by PlayerFaction or by a
    ; specific named NPC are skipped (don't steal personal beds; don't
    ; displace player-faction ownership in player homes).
    ;
    ; Applies to ALL followers, including custom AI keyword holders (Inigo,
    ; Lucien, Kaidan, etc.). If the player explicitly invoked AssignHome on a
    ; custom AI follower, they're opting into SeverActions managing this
    ; follower's home — claim the bed. Worst case for a custom AI follower
    ; whose mod still runs its own packages: the bed sits with our OWNR
    ; harmlessly until ClearHome releases it.
    ;
    ; Returns false silently if no usable bed is in the cell — follower will
    ; sleep on the floor or wherever the home sandbox finds, which is the
    ; same behavior as before this change.
    Bool bedClaimed = SeverActionsNative.Native_BedAssignment_Claim(akActor)
    If bedClaimed
        DebugMsg("Bed assigned in home cell for " + akActor.GetDisplayName())
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

    ; Defense: NEVER home-sandbox an actively-following companion. The home
    ; sandbox is for dismissed / sent-home followers only. A track-only
    ; follower's custom-AI mod, a SetPlayerTeammate flicker on a cell-load, or a
    ; verify/scene misfire could otherwise reach here for an active companion and
    ; strand them walking back to their assigned home while still recruited
    ; (the reported bug). If the actor is a registered follower, still a player
    ; teammate, and NOT showing the custom-dismiss signal (WaitingForPlayer == -1),
    ; they're actively following — bail. The legitimate track-only dismiss-redirect
    ; callers observe WFP == -1 before calling, so they're unaffected.
    If IsRegisteredFollower(akActor) && akActor.IsPlayerTeammate() && akActor.GetAV("WaitingForPlayer") != -1.0
        DebugMsg("ApplyHomeSandbox: SKIPPED — " + akActor.GetDisplayName() + " is an active following companion (not dismissed)")
        Return
    EndIf

    ; Wave 6.2: scene-aware entry guard. If the actor is currently bound to a
    ; vanilla BGSScene, applying our home sandbox would fight the scene's own
    ; package (the actor would keep trying to leave the scene location to "go
    ; home"). Mark them scene-suspended; CheckSceneSuspendedHomes on the next
    ; OnUpdate tick will retry once the scene ends.
    If SeverActionsNative.Native_IsActorInScene(akActor)
        DebugMsg("Home: skipping application — " + akActor.GetDisplayName() + " is in a vanilla scene; will retry once scene ends")
        ; T1-B: native source of truth for the home scene-suspend flag.
        SeverActionsNativeExt.Native_SetHomeSceneSuspended(akActor, true)
        Return
    EndIf

    ; Clear any stale scene-suspend flag now that we're successfully applying.
    SeverActionsNativeExt.Native_SetHomeSceneSuspended(akActor, false)

    ; One-shot migration for existing saves — sync TrueHomeAnchor to HomeMarker
    ; position before schedule system ever runs. See EnsureTrueHomeAnchorMigrated docs.
    EnsureTrueHomeAnchorMigrated(akActor, slot)

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

    ; Phase 7 — escalating re-eval chain (immediate + 500ms + 1500ms resetAI).
    ; User testing of Phase 6 showed force-eval alone left stragglers that
    ; needed `resetai` from console to recover.
    SeverActionsNative.EscalatedReEvaluate(akActor, 1500)
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

; =============================================================================
; SCENE-AWARE HOME SUSPEND/RESTORE (Wave 6.2)
; Vanilla BGSScene records can pull a follower into scripted behavior (e.g.
; Serana searching her mother's lab during Dawnguard's main quest). If our
; home sandbox alias is filled at the same time, our package fights the scene
; — the actor keeps trying to leave the scene location to "go home" and the
; quest breaks.
;
; Solution: each OnUpdate tick (30s), iterate registered followers with home
; assignments. If they're inside a vanilla scene, clear the alias slot to
; release our package (they then run the scene's package cleanly). Once the
; scene ends, the alias gets re-filled and home behavior resumes.
;
; Coverage caveat: only catches BGSScene-driven quests. Some quests use plain
; quest-alias packages or forced MoveTo+package-override patterns that we'd
; need a separate detector for. ~80% of quest-companion-pull scenarios are
; BGSScenes, so this fixes the common case.
; =============================================================================

Function SuspendHomeSandbox(Actor akActor, Int slot)
    {Internal helper: clear the home alias for an actor (releases our sandbox
     package) so a competing vanilla scene can drive their behavior without
     interference. Also removes the track-only PO3 override if applicable.
     Does NOT clear the home assignment itself — the slot/marker mapping is
     preserved so CheckSceneSuspendedHomes can restore once the scene ends.}
    If !akActor
        Return
    EndIf
    If !HomeSlots || slot < 0 || slot >= HomeSlots.Length
        Return
    EndIf

    HomeSlots[slot].Clear()

    ; Track-only followers (Inigo, Lucien, etc.) get an explicit PO3 override
    ; on top of the alias package — strip that too.
    If IsTrackOnlyFollower(akActor)
        Package homePkg = GetHomeSandboxPackage(slot)
        If homePkg
            ActorUtil.RemovePackageOverride(akActor, homePkg)
        EndIf
    EndIf

    ; Reset the WaitingForPlayer flag we set in ApplyHomeSandbox so vanilla
    ; / scripted packages aren't biased toward "stay parked at home".
    akActor.SetAV("WaitingForPlayer", 0)

    ; Re-evaluate so the actor immediately picks up the scene's package.
    akActor.EvaluatePackage()
EndFunction

Function CheckSceneSuspendedHomes(Actor[] followers)
    {Wave 6.2: per-tick scene-aware home suspend/restore.
     For each registered follower with a home assignment:
       - If they entered a vanilla scene → clear our alias + set suspend flag
       - If a previously-suspended follower's scene has ended → re-apply home
     Polls Native_IsActorInScene; runs every OnUpdate tick (30s). Only
     iterates loaded followers (Is3DLoaded gate) so unloaded actors are
     skipped — their scene state will be re-checked when they next load in.}

    If !followers || followers.Length == 0
        Return
    EndIf

    Int i = 0
    While i < followers.Length
        Actor follower = followers[i]
        If follower != None && follower.Is3DLoaded()
            Int slot = SeverActionsNative.Native_GetHomeMarkerSlot(follower)
            If slot >= 0
                Bool inScene = SeverActionsNative.Native_IsActorInScene(follower)
                ; T1-B: native source of truth for the scene-suspend flag.
                Bool wasSuspended = SeverActionsNativeExt.Native_GetHomeSceneSuspended(follower)

                If inScene && !wasSuspended
                    ; Scene started while home was active — suspend.
                    SuspendHomeSandbox(follower, slot)
                    SeverActionsNativeExt.Native_SetHomeSceneSuspended(follower, true)
                    DebugMsg("Home scene-suspended (vanilla scene active): " + follower.GetDisplayName())
                ElseIf !inScene && wasSuspended
                    ; Scene ended — restore home. ApplyHomeSandbox clears the
                    ; suspend flag itself on successful application.
                    If HomeMarkerList
                        ObjectReference homeMarker = HomeMarkerList.GetAt(slot) as ObjectReference
                        If homeMarker
                            ApplyHomeSandbox(follower, homeMarker, slot)
                            DebugMsg("Home scene-restored (scene ended): " + follower.GetDisplayName())
                        EndIf
                    EndIf
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile
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
    {Phase 4B: native cosave is the sole source of truth for home assignment.}
    If !akActor
        Return ""
    EndIf
    Return SeverActionsNative.Native_GetHome(akActor)
EndFunction

Function ClearHome(Actor akActor)
    {Remove home assignment. Releases the marker slot and moves the XMarker
     back to the holding cell (MHiYH pattern). Also releases any auto-claimed
     home bed so we don't leave a phantom OWNR behind on the bed reference.}
    If !akActor
        Return
    EndIf

    ; Release the auto-claimed bed BEFORE we drop home tracking — the C++ side
    ; reads the bed FormID + original owner from FollowerDataStore (which still
    ; has the entry at this point) and restores the original OWNR.
    SeverActionsNative.Native_BedAssignment_Release(akActor)

    ; Remove sandbox package if active
    RemoveHomeSandbox(akActor)

    ; Release marker slot (marker stays enabled in holding cell — MHiYH pattern)
    Int slot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)
    If slot >= 0 && HomeMarkerList
        SeverActionsNative.Native_ReleaseHomeMarkerSlot(akActor)
        DebugMsg("Home marker slot " + slot + " released for " + akActor.GetDisplayName())
    EndIf

    SeverActionsNative.Native_ClearHome(akActor)

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
     "no combat style" restores the original. All others override the ActorBase record.

     The "healer" style is special — it triggers a native poll subsystem (HealerPoll)
     that force-casts SeverActions_HealOther/Self at HP-threshold targets every ~1s.
     Transitioning into "healer" adds spells + faction membership; transitioning out
     removes them. Both transitions are idempotent via the IsHealer roster check.}
    If !akActor
        Return
    EndIf

    String normalized = SeverActionsNative.StringToLower(style)
    String previous = SeverActionsNative.Native_GetCombatStyle(akActor)
    If previous == ""
        previous = "no combat style"
    EndIf

    SeverActionsNative.Native_SetCombatStyle(akActor, normalized)

    ; Healer-role transitions — must happen around ApplyCombatStyleValues so the
    ; CSTY swap + faction/spells stay in sync.
    If previous == "healer" && normalized != "healer"
        RemoveHealerRole(akActor)
    EndIf

    ApplyCombatStyleValues(akActor, normalized)

    If normalized == "healer"
        ApplyHealerRole(akActor)
    EndIf

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

    ; Save original combat style form on first call (for restoration on dismiss).
    ; T1-B: native source of truth — null return means "not captured yet."
    If !SeverActionsNativeExt.Native_GetOrigCombatStyleForm(akActor)
        CombatStyle origCS = npcBase.GetCombatStyle()
        If origCS
            SeverActionsNativeExt.Native_SetOrigCombatStyleForm(akActor, origCS)
        EndIf
    EndIf

    ; "no combat style" = restore original, don't override
    If style == "no combat style" || style == ""
        Form origForm = SeverActionsNativeExt.Native_GetOrigCombatStyleForm(akActor)
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
    ElseIf style == "defensive"
        csFormID = 0x0003CF5A       ; csHumanTankLvl1
    ElseIf style == "healer"
        ; Healer CSTY resolution priority:
        ;   1. HealerCombatStyleForm property (if attached via CK) — user override
        ;   2. SeverActions "Healer" CSTY in SeverActions.esp at 0x165342 — default
        ;   3. Vanilla csHumanMagic (Skyrim.esm 0x0003BE1C) — safety net
        ; The native HealerPoll force-casts heals regardless of CSTY, so the
        ; CSTY only governs "what AI picks when the poll isn't firing" —
        ; positioning, non-heal spell selection, defensive flee thresholds.
        If HealerCombatStyleForm
            npcBase.SetCombatStyle(HealerCombatStyleForm)
            csFormID = -1
        Else
            CombatStyle severHealerCS = Game.GetFormFromFile(0x165342, "SeverActions.esp") as CombatStyle
            If severHealerCS
                npcBase.SetCombatStyle(severHealerCS)
                csFormID = -1
            Else
                csFormID = 0x0003BE1C   ; csHumanMagic vanilla fallback
            EndIf
        EndIf
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
     Also re-registers "healer"-style followers with the native HealerPoll
     since its roster is in-memory only (state derives from CombatStyle field).
     Called from Maintenance() on every game load.}
    Int i = 0
    While i < followers.Length
        If followers[i]
            String style = GetCombatStyle(followers[i])
            If style != "no combat style" && style != "balanced"
                ApplyCombatStyleValues(followers[i], style)
                DebugMsg("Reapplied combat style '" + style + "' for " + followers[i].GetDisplayName())
            EndIf
            ; Healer-role re-registration on load — HealerPoll's roster is in-memory.
            ; The spells + faction membership persist via the actor base, but the
            ; native poll forgot about them across the load.
            If style == "healer"
                SeverActionsNativeExt.Native_RegisterHealer(followers[i])
            EndIf
        EndIf
        i += 1
    EndWhile
EndFunction

; =============================================================================
; ESSENTIAL STATUS - reapplies cosaved intent to the live actor base flag
; =============================================================================

Function ReapplyEssentialStatus(Actor[] followers)
    {Legacy entry point. Essential is now applied via quest ReferenceAlias slots
     (templated-safe, live) instead of the ActorBase kEssential flag, so this
     delegates to ReassignEssentialSlots. Kept for any external callers.}
    ReassignEssentialSlots(followers)
EndFunction

; =============================================================================
; HEALER CONFIG — pushes Papyrus property values to the native HealerPoll
; =============================================================================

Function SyncHealerConfig()
    {Push the configured healer thresholds / multipliers to the native poll.
     Call from Maintenance() (post-load) and after any MCM/PrismaUI change.}
    SeverActionsNativeExt.Native_SetHealerThresholds(HealerPlayerThreshold, HealerSelfThreshold, HealerAllyThreshold)
    SeverActionsNativeExt.Native_SetHealerMult(HealerMult)
    SeverActionsNativeExt.Native_SetHealerChance(HealerChance)
    SeverActionsNativeExt.Native_SetHealerCooldowns(HealerTargetCooldownMs, HealerCastCooldownMs, HealerVoiceCooldownMs)
    SeverActionsNativeExt.Native_SetBleedoutCheatHeal(HealerBleedoutCheatHeal)
EndFunction

Function SyncCellCatchupConfig()
    {Push cell-catchup tunings to the native subsystem. Call from Maintenance().}
    SeverActionsNativeExt.Native_SetCellCatchupEnabled(CellCatchupEnabled)
    SeverActionsNativeExt.Native_SetCellCatchupGracePeriodMs(CellCatchupGracePeriodMs)
    SeverActionsNativeExt.Native_SetCellCatchupMaxFollowers(CellCatchupMaxFollowers)
    SeverActionsNativeExt.Native_SetCellCatchupOffsetRadius(CellCatchupOffsetRadius)
EndFunction

; =============================================================================
; HEALER ROLE — adds the heal spells + faction membership + native poll entry
; =============================================================================

Function ApplyHealerRole(Actor akActor)
    {Configure the actor as a healer:
       - Adds SeverActions_HealOther + SeverActions_HealSelf spells (cast when
         the native poll fires SeverActionsNative_HealerCast).
       - Adds SeverActions_HealerFaction membership (used by prompts/decorators
         to surface "this NPC is in healer mode" context to the LLM).
       - Registers with native HealerPoll so the ~1s combat tick can target them.
     Idempotent — calling on an already-healer actor is safe.}
    If !akActor
        Return
    EndIf

    ; Add heal spells (engine de-dupes — calling AddSpell twice is harmless)
    Spell healOther = Game.GetFormFromFile(0x16023E, "SeverActions.esp") as Spell
    Spell healSelf = Game.GetFormFromFile(0x160240, "SeverActions.esp") as Spell
    If healOther
        akActor.AddSpell(healOther, false)
    Else
        DebugMsg("ApplyHealerRole: SeverActions_HealOther (0x16023E) not found")
    EndIf
    If healSelf
        akActor.AddSpell(healSelf, false)
    Else
        DebugMsg("ApplyHealerRole: SeverActions_HealSelf (0x160240) not found")
    EndIf

    ; Add faction membership
    Faction healerFac = Game.GetFormFromFile(0x16023D, "SeverActions.esp") as Faction
    If healerFac && !akActor.IsInFaction(healerFac)
        akActor.AddToFaction(healerFac)
    EndIf

    ; Register with native poll
    SeverActionsNativeExt.Native_RegisterHealer(akActor)

    DebugMsg("ApplyHealerRole: " + akActor.GetDisplayName() + " configured as healer")
EndFunction

Function RemoveHealerRole(Actor akActor)
    {Reverse of ApplyHealerRole. Called when transitioning OUT of "healer" style.
     Idempotent on non-healers.}
    If !akActor
        Return
    EndIf

    Spell healOther = Game.GetFormFromFile(0x16023E, "SeverActions.esp") as Spell
    Spell healSelf = Game.GetFormFromFile(0x160240, "SeverActions.esp") as Spell
    If healOther
        akActor.RemoveSpell(healOther)
    EndIf
    If healSelf
        akActor.RemoveSpell(healSelf)
    EndIf

    Faction healerFac = Game.GetFormFromFile(0x16023D, "SeverActions.esp") as Faction
    If healerFac && akActor.IsInFaction(healerFac)
        akActor.RemoveFromFaction(healerFac)
    EndIf

    SeverActionsNativeExt.Native_UnregisterHealer(akActor)

    DebugMsg("RemoveHealerRole: " + akActor.GetDisplayName() + " no longer a healer")
EndFunction

; =============================================================================
; HEALER CAST EVENT HANDLER
; =============================================================================
;
; Fired by native HealerPoll every ~1s during combat for any registered healer
; that passes target/cooldown/resource gates. Payload:
;   sender = healer Actor (Form)
;   strArg = tier name ("player" | "self" | "ally" | "potion_fallback")
;   numArg = target FormID encoded as float (cast back to Int via numArg as Int)
;
; Handler responsibilities:
;   1. Resolve target Actor from FormID
;   2. Pick the right spell (HealSelf for self-heal, HealOther otherwise)
;   3. Spell.Cast(healer, target) — engine handles animation + magicka cost
;   4. Apply bonus RestoreActorValue from Native_ComputeBonusHeal
;   5. Voice-line cooldown'd via Native_ShouldEmitVoiceLine

Event OnHealerCast(string eventName, string strArg, float numArg, Form sender)
    Actor healer = sender as Actor
    If !healer || healer.IsDead() || !healer.Is3DLoaded()
        Return
    EndIf

    Int targetFormID = numArg as Int
    If targetFormID == 0
        Return
    EndIf

    Form targetForm = Game.GetForm(targetFormID)
    Actor target = targetForm as Actor
    If !target || target.IsDead()
        Return
    EndIf

    ; Pick the spell — HealSelf for true self-cast, HealOther for everything else.
    ; (Self-cast on HealOther would still work since AllowForTeammate covers it,
    ;  but the dedicated self spell costs less and uses self-target VFX.)
    Spell healSpell = None
    If strArg == "self"
        healSpell = Game.GetFormFromFile(0x160240, "SeverActions.esp") as Spell
    Else
        healSpell = Game.GetFormFromFile(0x16023E, "SeverActions.esp") as Spell
    EndIf

    If !healSpell
        DebugMsg("OnHealerCast: heal spell not found, tier=" + strArg)
        Return
    EndIf

    ; Force-cast — engine pays magicka, plays animation, applies vanilla restore-health
    healSpell.Cast(healer, target)

    ; Apply bonus heal on top: (Restoration * 0.2 + Level + 74) * mult
    Float bonus = SeverActionsNativeExt.Native_ComputeBonusHeal(healer)
    If bonus > 0.0
        target.RestoreActorValue("Health", bonus)
    EndIf

    ; Voice line — gated by per-healer cooldown (default 30s) so long fights
    ; don't turn into "Hold on!" / "I'll heal you!" spam.
    If SeverActionsNativeExt.Native_ShouldEmitVoiceLine(healer)
        ; Use a generic combat-banter Idle so we don't depend on a specific Topic
        ; form that may not exist. The actor speaks something appropriate to their
        ; voice type from their existing dialogue pool.
        ; (Optional — silently no-op if Idle missing on actor)
        ; Future enhancement: hook a SeverActions-specific Topic record.
    EndIf

    ; Update cooldowns for the next tick across all healers
    SeverActionsNativeExt.Native_NotifyHealApplied(healer, target)

    DebugMsg("OnHealerCast: " + healer.GetDisplayName() + " healed " + target.GetDisplayName() + \
        " (tier=" + strArg + ", bonus=" + bonus + ")")
EndEvent

Function ApplyIgnoreFriendlyHits(Actor[] followers)
    {Re-apply IgnoreFriendlyHits to all SeverActions followers on game load.
     The actor-level flag doesn't reliably survive save/load on every mod-added
     follower (especially custom-AI ones managed outside CurrentFollowerFaction).
     Idempotent — calling with the same value is a no-op at the engine level.

     Pairs with the SeverActions_FollowerFaction self-friendly reaction declared
     in the ESP. Together they prevent stray AoE / arrow / fireball / cloak
     hits between followers from flipping them hostile to each other —
     without this, Daegon casting Firebolt could splash Jenassa, the engine's
     combat AI processes "I was attacked by Daegon", and they'd start fighting.

     Called from Maintenance() on every game load.}
    Int i = 0
    While i < followers.Length
        If followers[i]
            followers[i].IgnoreFriendlyHits(true)
        EndIf
        i += 1
    EndWhile
    DebugMsg("Re-applied IgnoreFriendlyHits to " + followers.Length + " followers")
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
                        ; overrides don't persist reliably across cell transitions
                        ; (see corrected comment above ReapplyHomeSandboxing call).
                        If IsTrackOnlyFollower(akActor)
                            Package homePkg = GetHomeSandboxPackage(slot)
                            If homePkg
                                ActorUtil.AddPackageOverride(akActor, homePkg, 100, 1)
                            EndIf
                        EndIf

                        ; Phase 5 Fix B — always re-evaluate to kick the engine
                        ; into re-selecting the correct package. Stragglers landing
                        ; on an FF runtime package after load-time weren't getting
                        ; this kick unless they were track-only.
                        ;
                        ; Phase 7 — escalating re-eval chain (immediate + 500ms + 1500ms resetAI).
                        ; Phase 6 force-eval alone wasn't enough for all stragglers.
                        SeverActionsNative.EscalatedReEvaluate(akActor, 1500)
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
    {Phase 4B: native cosave is the sole source of truth. The legacy "balanced"
     value (renamed to "no combat style" in an earlier release) is still mapped
     for backward compatibility with old saves.}
    If !akActor
        Return "no combat style"
    EndIf
    String nativeStyle = SeverActionsNative.Native_GetCombatStyle(akActor)
    If nativeStyle == "" || nativeStyle == "balanced"
        Return "no combat style"
    EndIf
    Return nativeStyle
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
    SeverActionsNativeExt.Native_SetInteractionTime(akActor, GetGameTimeInSeconds())

    ; Build a summary for debug log only — do NOT register as a SkyrimNet event.
    ; Same reason as OnRelationshipAssessment: mechanics text leaks into
    ; get_recent_events and produces gameplay-meta diary/memory entries.
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

     Two paths:
     - Vanilla followers: Delegates to SeverActions_Follow.Sandbox() which handles all
       SA package management (removing FollowPlayer, applying sandbox override,
       SandboxManager registration, etc.).
     - Track-only followers (Inigo, Lucien, Kaidan, Daegon-keyworded, etc.): Their
       own mods manage AI packages, so we DON'T apply ours. Mirrors the
       RegisterFollower track-only branch — observe-only, no package attachment.
       Instead we clear any stale SA state from a prior incorrect attachment
       (bug-recovery pass) and toggle the vanilla WaitingForPlayer ActorValue,
       which their follow package respects via the standard DialogueFollower
       hooks. Voice/wheel "Wait" still works without forcing our package on them.}
    If !akActor
        Return
    EndIf

    ; Notify downstream listeners (camp sandbox, future per-mod holds).
    ; Wait is also a player-directed call — the camp sandbox should release
    ; the actor so they stand by the player rather than walk back to the fire.
    Int waitEvt = ModEvent.Create("SeverActions_FollowerCalledByPlayer")
    If waitEvt
        ModEvent.PushString(waitEvt, "SeverActions_FollowerCalledByPlayer")
        ModEvent.PushString(waitEvt, "wait")
        ModEvent.PushFloat(waitEvt, 0.0)
        ModEvent.PushForm(waitEvt, akActor)
        ModEvent.Send(waitEvt)
    EndIf

    SeverActions_Follow followSys = GetFollowScript()

    If IsTrackOnlyFollower(akActor)
        ; Track-only path — don't put SA's package on them. Recovery: if a prior
        ; broken call already attached SA's sandbox or alias-based follow package,
        ; clean it up here. Then let their own mod's follow package handle "wait"
        ; via the vanilla WaitingForPlayer flag.
        If followSys
            followSys.CompanionStopFollowing(akActor, false)
            followSys.StopSandbox(akActor)
        EndIf
        akActor.SetAV("WaitingForPlayer", 1)
        akActor.EvaluatePackage()
    ElseIf followSys
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

     Three paths:
     - Track-only followers (Inigo, Lucien, Kaidan, Daegon-keyworded, etc.): Their
       own mods manage AI packages, so we DON'T apply ours. Mirrors the
       RegisterFollower track-only branch. Recovery: clean up any stale SA
       package state from a prior incorrect attachment, then clear the vanilla
       WaitingForPlayer ActorValue so their follow package resumes via the
       standard DialogueFollower hooks.
     - Registered companions: CompanionStartFollowing handles alias + LinkedRef + cleanup.
     - Non-companions who were following via StartFollowing: restart the casual
       FollowPlayer package.}
    If !akActor
        Return
    EndIf

    ; Reliable break-out from camp / waiting / travel holds BEFORE resuming follow:
    ;  - CancelTravel tears down any active travel slot (removes the arrival
    ;    sandbox override — e.g. SeversHearth's CampSandboxPackage — plus the
    ;    travel LinkedRef and OrphanCleanup registration). restoreFollower=false:
    ;    we re-apply follow ourselves below.
    ;  - The FollowerCalledByPlayer event tells SeversHearth's camp to untrack +
    ;    release the actor so CampTick stops re-restoring them to the fire.
    ; (CompanionWait/StartFollowing already fired the latter; CompanionFollow
    ;  previously did neither, which is why camp followers wouldn't break loose.)
    SeverActions_Travel travelSys = GetTravelScript()
    If travelSys
        travelSys.CancelTravel(akActor, false)
    EndIf
    Int followEvt = ModEvent.Create("SeverActions_FollowerCalledByPlayer")
    If followEvt
        ModEvent.PushString(followEvt, "SeverActions_FollowerCalledByPlayer")
        ModEvent.PushString(followEvt, "follow")
        ModEvent.PushFloat(followEvt, 0.0)
        ModEvent.PushForm(followEvt, akActor)
        ModEvent.Send(followEvt)
    EndIf

    SeverActions_Follow followSys = GetFollowScript()

    If IsTrackOnlyFollower(akActor)
        ; Track-only path — don't put SA's follow package on them. Recovery: if
        ; a prior broken call already attached our alias-based follow package or
        ; a sandbox override, clean it up here. Then clear the vanilla wait
        ; flag and let their mod's package take over via DialogueFollower hooks.
        If followSys
            followSys.CompanionStopFollowing(akActor, false)
            followSys.StopSandbox(akActor)
        EndIf
        akActor.SetAV("WaitingForPlayer", 0)
        akActor.EvaluatePackage()
    ElseIf followSys
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
    {Legacy Papyrus pump (SkyrimNet < v8). On v8+ the C++ side dispatches the
     LLM call directly and this path stays dormant — Native_PopSummaryRequest
     returns "" because the C++ queue is never populated.}
    String contextJson = SeverActionsNative.Native_PopSummaryRequest()
    If contextJson == ""
        DebugMsg("Quest awareness: summary queue drained")
        Return
    EndIf

    ; Gate: MCM toggle (PrismaUI: "Quest Awareness Summaries") + FOMOD prompt presence.
    ; Drain silently when off so quest stage events don't pile up waiting for
    ; LLM calls that never fire. The C++ queue pop already happened, so no
    ; orphan state stays behind.
    If !AutoQuestAwareness || !SeverActionsNative.Native_IsPromptAvailable("sever_quest_awareness")
        DebugMsg("Quest awareness skipped (toggle off or prompt missing) — draining queue")
        ProcessNextSummaryRequest()
        Return
    EndIf

    ; Stash the context across the SendCustomPromptToLLM round-trip so the
    ; callback can extract the routing fields (npcFormId, questEditorID,
    ; awarenessTier) the C++ side already wrote into the JSON.
    CurrentSummaryContextJson = contextJson
    QuestAwarenessInProgress = true

    Int result = SkyrimNetApi.SendCustomPromptToLLM("sever_quest_awareness", "sever_background", contextJson, \
        Self as Quest, "SeverActions_FollowerManager", "OnQuestSummaryGenerated")

    If result < 0
        QuestAwarenessInProgress = false
        CurrentSummaryContextJson = ""
        DebugMsg("Quest awareness: LLM call failed, continuing queue")
        ProcessNextSummaryRequest()
    EndIf
EndFunction

Function OnQuestSummaryGenerated(String response, Int success)
    {Callback from SendCustomPromptToLLM (legacy Papyrus pump). Parses routing
     out of the stashed context and writes the response directly to the
     matching (actor, quest) — no C++ FIFO stash, so out-of-order responses
     or early returns can't desync.}
    String ctx = CurrentSummaryContextJson
    CurrentSummaryContextJson = ""
    QuestAwarenessInProgress = false

    If success == 1 && ctx != "" && response != ""
        Int npcFid = ExtractJsonInt(ctx, "npcFormId")
        String questEid = ExtractJsonStringAt(ctx, "questEditorID", 0)
        Bool isFirsthand = StringUtil.Find(ctx, "\"awarenessTier\":\"firsthand\"") >= 0
        Actor akActor = Game.GetForm(npcFid) as Actor
        If akActor && questEid != ""
            SeverActionsNative.Native_SetQuestSummary(akActor, questEid, response, isFirsthand)
            DebugMsg("Quest awareness: summary stored for " + akActor.GetDisplayName() + " on " + questEid)
        Else
            DebugMsg("Quest awareness: could not route response (actorFid=" + npcFid + " editor=" + questEid + ")")
        EndIf
    ElseIf success != 1
        DebugMsg("Quest awareness: LLM summary failed: " + response)
    EndIf

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
        ; String fields go through ExtractJsonStringAt which honors JSON escaping —
        ; a previous inline parser scanned for the next bare quote and silently
        ; truncated any summary containing \".
        Int fidVal = ExtractJsonInt(entryJson, "actorFormID")
        String summary = ExtractJsonStringAt(entryJson, "summary", 0)
        String entryEditorID = ExtractJsonStringAt(entryJson, "editorID", 0)
        Bool isFirsthand = StringUtil.Find(entryJson, "\"isFirsthand\":true") >= 0

        Actor akFollower = Game.GetForm(fidVal) as Actor
        If akFollower && summary != ""
            ; All awareness entries are firsthand witnesses now — the secondhand
            ; tier was retired. Memory type is always EXPERIENCE at the firsthand
            ; importance weight. The legacy isFirsthand JSON field is ignored.
            Float importance = 0.7
            String memType = "EXPERIENCE"

            ; Native_AddMemory returns the SkyrimNet memory ID (>0) on success,
            ; or 0 on failure (API not loaded, scope rejection, etc.). Previously
            ; we marked the awareness entry memorized unconditionally — a failure
            ; meant the decorator stopped emitting the entry AND no memory existed,
            ; so the follower silently forgot the quest. Now we only mark memorized
            ; when the canonical record actually landed; on failure the entry stays
            ; visible so a future stage event can retry.
            Int memId = SeverActionsNative.Native_AddMemory(akFollower, summary, importance, \
                memType, "", "", "[\"quest\"]", "[]")

            If memId > 0 && entryEditorID != ""
                SeverActionsNative.Native_QuestAwareness_MarkMemorized(akFollower, entryEditorID)
                DebugMsg("Quest awareness: created " + memType + " memory #" + memId + " for " + akFollower.GetDisplayName())
            ElseIf memId == 0
                DebugMsg("Quest awareness: Native_AddMemory failed for " + akFollower.GetDisplayName() + " on " + entryEditorID + " — entry stays visible")
            EndIf
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
