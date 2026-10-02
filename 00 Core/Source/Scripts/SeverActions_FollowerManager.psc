Scriptname SeverActions_FollowerManager extends Quest

{
    SkyrimNet-native follower framework: the roster, relationships, homes and
    schedules, and combat styles, all driven through dialogue.

    Framework routing (this script names no framework type): an actor NFF has
    seated is recruited / dismissed / parked through NFF's controller
    (SeverActions_NFFLib; the same-named functions here are forwarders), then SA
    does its own bookkeeping but never touches that actor's package stack. The
    vanilla DialogueFollower and Serana routes live in
    SeverActions_FollowerFrameworkLib. Tracking mode (frameworkMode 1, D45)
    registers every teammate but leads nobody (IsFollowHandsOff); home and
    schedule orders stay live in either mode.

    Follower data lives in the native FollowerDataStore cosave; the
    SeverFollower_* StorageUtil keys are legacy mirrors read only by the
    one-shot T1 migrations.
}

; =============================================================================
; PROPERTIES - Settings. Most are legacy hosts of Settings Authority rows (read
; them with Settings_Get*); settings_table.json marks the few tier-P ones.
; =============================================================================

Int Property MaxFollowers = 100 Auto
{Roster recruitment cap (0 = unlimited); a user preference, not an alias-pool
 limit. Maintenance() moves saves still on the old default (20) to 100 once.}

Float Property FollowerTeleportDistance = 2000.0 Auto
{Distance at which actively-following companions are teleported to the player.
Set to 0 to disable. Only when following — not waiting, sandboxing, or traveling.}

Int Property TeleportCooldownSeconds = 30 Auto
{Global (not per-follower) cooldown between catch-up teleports. SandboxManager
reads it at boot (SyncFromPluginConfig).}

Bool Property ShowFollowerContext = true Auto
{When false, the follower relationship prompt (0175) is left out of NPC bios.}

String Property NearbyExcludedTags = "" Auto
{Comma-separated "type:subtype" tags left out of the Nearby Objects prompt
(0180_severactions_nearbyref), e.g. "furniture:bed,item:weapon", on top of the
hardcoded defaults. Legacy host of the nearbyExcluded row, which is mirrored to
StorageUtil(None, "SeverActions_NearbyExcluded") for the prompt.}

Float Property UIScale = 1.0 Auto
{UI density factor, range 0.8-2.0. Legacy host of the uiScale row (the Settings
Authority holds the value); mirrored to StorageUtil(None, "SeverActions_UIScale").}

Float Property RapportDecayRate = 1.0 Auto
{How fast rapport decays from neglect (points per 6 game hours without conversation)}

Bool Property AllowAutonomousLeaving = true Auto
{Can followers leave on their own if rapport is too low?}

Bool Property EnableRestrainAction = true Auto
{Toggle for the RestrainNPC action (an NPC binds a named target and holds them
 standing bound: no hood, no abduction legs, no crime consequences). Default ON:
 an ordered restraint is a milder ask than abduction, so it skips the kidnap opt-in.}

Bool Property UseLeashFramework = true Auto
{Use Leash Framework (soft dependency: Leash.esm + LeashFramework.dll) when
 installed: a leashed captive gets a real rope the framework tugs, ragdolls and
 pulls through load doors, layered over our escort-follow package
 (SeverActions_LeashLib). Off or absent = the package-only leash. Setting key
 leashFrameworkEnabled.}

Int Property LeashAttachment = 0 Auto
{Where the rope ties: 0 wrists (default), 1 neck collar (LeashStyle picks which).
 Setting key leashAttachment. Wrists need Leash Framework 1.1.1+ (its
 Leash_hand_chain armor, LeashWristAvailable); on 1.1.0 the neck collar is used
 regardless, and SeverActions_LeashLib.WarnIfOutdated says so once per playthrough
 (from the arrest provider's load stage).}

Int Property LeashStyle = 0 Auto
{Which Leash.esm collar the captive wears: 0 rope (0x000804), 1 chain
 (0x000806), 2 runes (0x0002CE) - all slot 45. Setting key leashStyle.}

Float Property LeashMinLength = 120.0 Auto Hidden
{Framework min length (units): below this the rope goes slack, no pull.}

Float Property LeashMaxLength = 350.0 Auto Hidden
{Framework max holder-to-collar distance: past it the captive is pulled. Just
 outside FollowGuard_Prisoner's 200/256 follow radii, so the rope only bites
 when the captive lags.}

Bool Property EnableKidnapActions = false Auto
{Opt-in toggle for the kidnap actions (KidnapNPC / ReleaseCaptive). Default OFF:
 holding an essential or quest NPC captive can break their later quests.}

Float Property LeavingThreshold = -60.0 Auto
{Rapport level at which followers may decide to leave}

Bool Property ShowNotifications = true Auto
{Show notifications for recruitment, dismissal, relationship changes}

Bool Property DebugMode = false Auto
{Enable debug tracing for troubleshooting}

Float Property RelationshipCooldown = 120.0 Auto
{Real-time seconds between allowed AdjustRelationship calls per actor, so the
LLM cannot move a relationship on every line.}

Bool Property AutoRelAssessment = true Auto
{Enable the background LLM relationship assessment (SeverActions_CompanionMind's tick).}

Float Property AssessmentCooldownMinHours = 4.0 Auto
{Minimum game hours between relationship assessments per follower (each follower
rolls a cooldown between min and max after each one).}

Float Property AssessmentCooldownMaxHours = 10.0 Auto
{Maximum game hours between automatic relationship assessments per follower.}

Bool Property AutoInterFollowerAssessment = true Auto
{Enable the background LLM assessment of how followers feel about each other.}

Float Property InterFollowerCooldownMinHours = 6.0 Auto
{Minimum game hours between inter-follower relationship assessments per follower.}

Float Property InterFollowerCooldownMaxHours = 14.0 Auto
{Maximum game hours between inter-follower relationship assessments per follower.}

Bool Property AutoFollowerBanter = true Auto
{Enable spontaneous companion-to-companion conversations while traveling.}

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
Range 0.05-2.0. Synced to native.}

Int Property HealerChance = 75 Auto
{Chance (0-100) the ~1s poll tries a heal at all on a given tick.}

Int Property HealerTargetCooldownMs = 4000 Auto
{Per-target heal cooldown (ms), across ALL healers, so a multi-healer party
does not stack heals on one target.}

Int Property HealerCastCooldownMs = 1500 Auto
{Per-healer minimum gap between casts (ms).}

Int Property HealerVoiceCooldownMs = 30000 Auto
{Per-healer voice-line cooldown (ms).}

Bool Property HealerBleedoutCheatHeal = true Auto
{When true, a healer-style follower entering bleedout is restored to half max
HP (60-second game-time cooldown).}

CombatStyle Property HealerCombatStyleForm Auto
{Optional CSTY for healer-mode followers; unfilled = vanilla csHumanMagic
(0x0003BE1C). HealerPoll force-casts heals regardless, so this only shapes
positioning and non-heal spells.}

; --- Cell-catchup configuration (synced to native CellCatchup) ---

Bool Property CellCatchupEnabled = true Auto
{Master toggle: followers stranded after a cell load are MoveTo'd to the player.}

Int Property CellCatchupGracePeriodMs = 1500 Auto
{Milliseconds to wait after a cell load before catching up, so vanilla's own
teleport goes first (lower may double-teleport).}

Int Property CellCatchupMaxFollowers = 8 Auto
{Maximum followers caught up per cell load (bounds the cost on huge rosters).}

Float Property CellCatchupOffsetRadius = 100.0 Auto
{XY scatter radius (units) around the player, so followers do not pile up.}

Float Property BanterCooldownMinHours = 2.0 Auto
{Minimum game hours between follower banter opportunities.}

Float Property BanterCooldownMaxHours = 5.0 Auto
{Maximum game hours between follower banter opportunities.}

Bool Property AutoAmbientBanter = true Auto
{Enable spontaneous conversations between nearby non-follower NPCs. Skipped
while any loaded actor is hostile to the player.}

Float Property AmbientBanterCooldownMinHours = 3.0 Auto
{Minimum game hours between ambient NPC banter opportunities.}

Float Property AmbientBanterCooldownMaxHours = 7.0 Auto
{Maximum game hours between ambient NPC banter opportunities.}

Bool Property AutoAmbientActions = false Auto
{Let nearby non-follower NPCs take an action on their own (head off somewhere,
optionally telling a nearby NPC first). See ai_docs/AMBIENT_ACTIONS.md.}

Float Property AmbientActionCooldownMinHours = 4.0 Auto
{Minimum game hours between ambient-action opportunities.}

Float Property AmbientActionCooldownMaxHours = 9.0 Auto
{Maximum game hours between ambient-action opportunities.}

Bool Property RoomRotationEnabled = true Auto
{Home room rotation: a homed NPC's sandbox anchor hops between the named markers
 in their home every 1-3 game hours. Only on the HOME schedule, outside the sleep
 window, and while loaded.}

Int Property QuestAwarenessOutputCap = 5 Auto
{Quest awareness entries the prompt shows per follower (1-15); storage is unaffected.}

Int Property EnterpriseStoryCap = -1 Auto
{Max weekly retainer work-life vignettes (LLM calls) per settle batch.
-1 = Auto (~40% of the active roster, min 1, cap 12); 0 = off; 1-12 = fixed.}

Int Property EnterpriseOutputPct = 100 Auto
{Scaler on every venture's weekly production, percent (25-300; 100 = baseline).
The board's projection uses it too.}

Bool Property EnterpriseLoansEnabled = True Auto
{Allow retainers to ask the player for a loan (separate from raise requests).}

Bool Property EnterpriseRaisesEnabled = True Auto
{Master toggle for retainer raise requests; off = no raise asks and no skimming.}

Bool Property EnterpriseRenownCapEnabled = True Auto
{Master toggle for the Renown roster cap (VSTR v2); off = score and tier still
track, hiring is never gated. Its one-shot migration is
SeverActions_Enterprises._MigrateRenownCap.}

Bool Property EnterpriseAmbushesEnabled = True Auto
{Master toggle for retainer grudges; off = a wronged desertion arms no ambush.}

Bool Property EnterpriseTemperEnabled = True Auto
{Master toggle for the Temper consequence ladder; off = morale still tracks, but
no letters, pilfering, notices, defiance, betrayal or escapes.}

Bool Property SandboxMultiFloorEnabled = True Auto
{Multi-floor sandboxing: widen the engine's sandbox search cylinder
(fSandboxCylinderTop/Bottom GMSTs) so sandboxing NPCs use other floors.
Widen-only against whatever the load order shipped.}

Int Property SandboxCylinderHeight = 576 Auto
{Vertical half-height (units) of the sandbox cylinder when multi-floor is on
(a floor is ~256-384u; 576 is the Multiple Floors Sandboxing mod's value).}

Bool Property WaitInPlace = False Auto
{Manual wait only: OFF applies SeverActions_LeisureSandbox (1200-unit wander),
ON the radius-0 hold SeverActions_WaitPackage. Read by
SeverActions_Follow.GetWaitSandboxPackage; home/work/relax sandboxes ignore it.}

Bool Property HomeSleepEnabled = True Auto
{During the sleep window a dismissed homed NPC lies down in the bed
BedAssignment claimed at AssignHome (the engine's Sandbox procedure almost never
picks sleep on its own). Read live each tick.}

Float Property HomeSleepStart = 22.0 Auto
{Sleep window start, game hours 0-24; wraps midnight via HourInWindow.}

Float Property HomeSleepEnd = 6.0 Auto
{Sleep window end, game hours 0-24.}

Bool Property AutoQuestAwareness = true Auto
{Enable the LLM quest awareness summaries when quests advance. Off = stage
tracking still runs, only the sever_quest_awareness calls stop (C++ also skips
them when that prompt is missing).}

Bool Property AutoNPCReputation = true Auto
{Enable the LLM reputation blurb when a non-follower NPC's familiarity tier
changes. Off = the tier still tracks, the bio shows it without a blurb (C++ also
skips the call when sever_reputation_assess is missing).}

Bool Property AutoOffScreenLife = true Auto
{Enable off-screen life events (memories, gossip) for dismissed followers with homes.}

Float Property OffScreenLifeCooldownMinHours = 10.0 Auto
{Minimum game hours between off-screen life event generation per dismissed follower.}

Float Property OffScreenLifeCooldownMaxHours = 72.0 Auto
{Maximum game hours between off-screen life event generation per dismissed follower.}

Bool Property OffScreenConsequences = true Auto
{Enable off-screen life consequences (arrest/bounty, gold changes, debt).
When false, only narrative events and gossip are generated.}

Float Property ConsequenceCooldownHours = 36.0 Auto
{Game hours between consequential off-screen events per follower (separate
from, and rarer than, the event cooldown).}

Int Property MaxOffScreenBounty = 1000 Auto
{Maximum cumulative bounty a follower can accumulate from off-screen events.}

Int Property MaxOffScreenGoldChange = 500 Auto
{Maximum gold gained or lost per off-screen event.}

Float Property DeathGracePeriodHours = 4.0 Auto
{Game hours after a follower's death before they leave the roster; 0 = never
(manual removal only).}

Int Property FrameworkMode = 0 Auto
{Legacy host of the frameworkMode Authority row (nothing reads this property).
 0 = SeverActions (full control), 1 = Tracking (D45: registers every teammate,
 leads nobody; homes and schedules stay live). Read live by IsFollowHandsOff.
 Track-only actors (NFF, DLC such as Serana, SPID custom-AI keyword) are
 hands-off in either mode.}

; No script-reference properties: this script casts the quest to its own module's
; types (GetFollowScript), reaches travel through the travelcore provider and
; resolves records by FormID (DR2/DR3).

ReferenceAlias[] Property OutfitSlots Auto
{Unused: SeverActions_Outfit resolves the same 21 aliases by id. Kept declared
 so the ESP's fill (which cannot move, DR6) binds quietly.}

; Essential alias pool: 40 "Essential"-flagged ReferenceAliases on this quest
; (ids 218-257). A filled slot makes the actor essential at the REFERENCE level,
; which works live on templated NPCs, unlike the base kEssential flag. Resolved
; by alias id at runtime (EnsureEssentialSlots).
Int Property EssentialSlotFirstID = 218 Auto
{Alias ID of the first Essential slot. The pool is contiguous from here.}
Int Property EssentialSlotCount = 40 Auto
{Number of Essential slots (the simultaneous-essential cap).}
ReferenceAlias[] EssentialSlots   ; built lazily from GetAlias()

Faction Property SeverActions_FollowerFaction Auto
{SeverActions' own follower faction: added on recruit, removed on dismiss, for a
 fast "is this our follower?" test. Independent of NFF/EFF/vanilla factions.}

ReferenceAlias[] Property HomeSlots Auto
{40 home-sandbox aliases; each alias's own package sandboxes at its XMarker
 (HomeMarkerList, same index). ForceRef seats the NPC; the fill persists in the save.}

FormList Property HomeMarkerList Auto
{40 XMarkers, one per HomeSlot (same index). They start disabled in
 SeverActions_HoldingCell; a home assignment moves and enables one.}

FormList Property TrueHomeAnchorList Auto
{40 TrueHomeAnchor XMarkers, placed at AssignHome: the "home" position that
 HomeMarker_NN returns to outside work/play hours.}

FormList Property WorkMarkerList Auto
{40 WorkMarker XMarkers, placed by SetRoutineLocHere(actor, "work"); HomeMarker_NN
 moves here during work hours (8-17).}

FormList Property PlayMarkerList Auto
{40 PlayMarker XMarkers; the same pattern for play hours (17-22).}

; Route B work pool: a working NPC gets a runtime-spawned, force-persistent
; XMarker linked via WorkAnchorKeyword (LinkedRef_SetPermanent, cosaved). The
; marker is still the work anchor; applying WorkSandboxPackage (r1200) as a
; work-hours override is only the pre-migration enforcement (after it, the
; SchedWork alias pool). Both records are resolved by FormID
; (GetWorkSandboxPackage / GetWorkAnchorKeyword), never as Auto properties: a
; Mutagen/CK write to this script-heavy quest's VMAD has corrupted it (a hang
; before the main menu).

; Per-actor StorageUtil key holding the spawned work XMarker (reused on reassign).
String Property KEY_WORK_MARKER = "SeverActions_WorkMarkerRef" AutoReadOnly
; One-shot migration counter: borrow-a-home-slot workers onto the Route B pool.
String Property KEY_WORKPOOL_MIG = "SeverActions_WorkPoolMigDone" AutoReadOnly

; Per-slot home sandbox packages, one per HomeSlot alias
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

; =============================================================================
; CONSTANTS
; =============================================================================

; SeverActions.esp records resolved by FormID (DR2).
Int Property FID_TRAVEL_TARGET_KW = 0x076F5F AutoReadOnly   ; SeverTravelKeyword: the LinkedRef the travel packages chase
Int Property FID_FOLLOW_KW        = 0x0EB706 AutoReadOnly   ; SeverActions_FollowerFollowKW: SA's follow LinkedRef (see SeverActions_Follow)
Int Property FID_SANDBOX_PKG      = 0x0BDDFF AutoReadOnly   ; SeverActions_LeisureSandbox: the arrival sandbox

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

; Game seconds per game hour (~3600). Only ratios use it (every use multiplies
; and divides by it), so the odd 3631 is harmless.
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

String Property KEY_NEXT_ROOM_HOP_GT = "SeverActions_NextRoomHopGT" AutoReadOnly

; Cooldown tracking for off-screen life event generation (game time seconds)
String Property KEY_LAST_LIFE_EVENT_GT = "SeverFollower_LastLifeEventGT" AutoReadOnly
String Property KEY_NEXT_LIFE_EVENT_GT = "SeverFollower_NextLifeEventGT" AutoReadOnly

; Life summary for dismissed followers (what happened while away)
String Property KEY_LIFE_SUMMARY = "SeverFollower_LifeSummary" AutoReadOnly

; Per-follower exclusion from off-screen life events
String Property KEY_OFFSCREEN_EXCLUDED = "SeverFollower_OffScreenExcluded" AutoReadOnly

; Game-time stamp of when follower was dismissed (used as grace period for off-screen life)
String Property KEY_DISMISS_GT = "SeverFollower_DismissGT" AutoReadOnly

; Set on explicit dismiss so RecoverCustomAIFollowers does not re-register a custom-AI
; follower whose mod keeps IsPlayerTeammate() true
String Property KEY_DISMISSED = "SeverFollower_Dismissed" AutoReadOnly

; Cooldown tracking for off-screen consequences (separate from events)
String Property KEY_LAST_CONSEQUENCE_GT = "SeverFollower_LastConsequenceGT" AutoReadOnly

; Cumulative bounty from off-screen crime events
String Property KEY_OFFSCREEN_BOUNTY_TOTAL = "SeverFollower_OffScreenBountyTotal" AutoReadOnly

; Simple debt accumulator for off-screen debt events
String Property KEY_OFFSCREEN_DEBT = "SeverFollower_OffScreenDebt" AutoReadOnly

; Global tracking key for all NPCs with custom home assignments (stored on None form)
String Property KEY_HOMED_NPCS = "SeverActions_HomedNPCs" AutoReadOnly

; Global list of NPCs with a work or relax spot but no home: held only in their work
; and relax hours, native AI otherwise. AssignHome moves them to KEY_HOMED_NPCS.
String Property KEY_WORK_ONLY_NPCS = "SeverActions_WorkOnlyNPCs" AutoReadOnly

; Last-applied schedule type per NPC, so the marker moves only on a boundary.
; 0=home, 1=work, 2=play, -99=never evaluated (forces a full re-resolve).
String Property KEY_LAST_SCHEDULED_TYPE = "SeverFollower_LastScheduledType" AutoReadOnly

; Per-NPC one-shot: copy HomeMarker_NN's position to TrueHomeAnchor_NN before any
; schedule logic runs, or an older save's first tick sends the NPC to the anchor's
; holding-cell default. Set on AssignHome or the first tick.
String Property KEY_TRUEHOME_MIGRATED = "SeverFollower_TrueHomeMigrated" AutoReadOnly

Int Property SCHEDULE_HOME = 0 AutoReadOnly
Int Property SCHEDULE_WORK = 1 AutoReadOnly
Int Property SCHEDULE_PLAY = 2 AutoReadOnly

Float Property SCHEDULE_WORK_START = 8.0 Auto
Float Property SCHEDULE_WORK_END = 17.0 Auto
Float Property SCHEDULE_PLAY_START = 17.0 Auto
Float Property SCHEDULE_PLAY_END = 22.0 Auto

; Per-NPC schedule alias pools (used once Native_GetAliasesMigrated() is true).
; MUST match the alias count GenerateSchedPoolExtend.pas made on all three sched
; quests (SchedHome/Work/RelaxQuest, aliases 000..299).
Int Property SCHED_ALIAS_POOL_SIZE = 300 AutoReadOnly

; Lazy quest/package caches (resolved via Game.GetFormFromFile; never ESP properties)
Quest _schedHomeQuest = None
Quest _schedWorkQuest = None
Quest _schedRelaxQuest = None
Bool _schedQuestsResolved = False
Package _schedHomePackageV2 = None
Package _schedWorkPackageV2 = None
Package _schedRelaxPackageV2 = None

; Per-type scan cursors for free-alias lookup (0..SCHED_ALIAS_POOL_SIZE-1)
Int _schedCursorHome = 0
Int _schedCursorWork = 0
Int _schedCursorRelax = 0

; True while the one-way Route B -> alias migration drains in 0.5s batches
Bool SchedMigrationPending = False

; =============================================================================
; INTERNAL STATE
; =============================================================================

Float LastTickTime
Bool IsUpdating = false
Float IsUpdatingSetRT = 0.0  ; real-time stamp for the stuck-guard watchdog
; Outer tick re-entrancy guard (see OnChronoTick_FollowerManager): one pass at a
; time; a 120s real-time ceiling frees it if a pass's stack died mid-body.
Bool _OnUpdateInFlight = false
Float _OnUpdateStartRT = 0.0

; Set by Maintenance() so the next chrono tick (0.1s later) runs
; RunDeferredMaintenance() off SeverActions_Init's critical path.
Bool DeferredMaintenancePending = false

; Dismisses awaiting delayed confirmation (filters a mod's temporary teammate
; toggle). A queue, not one slot, so a burst (mass dismiss, cell unload) inside
; the 2.5s window loses nobody; 32 is sized for bursts, not the roster cap.
Actor[] PendingDismissQueue
Int PendingDismissCount = 0
; Parallel to PendingDismissQueue: FriendlyFire_TakeForgiven's answer when the removal arrived.
Bool[] PendingDismissForgiven
; OnNativeTeammateResumed continuation (see PollTeammateResume): the actor whose
; enlistment we are waiting on, the native gap (diagnostic), and the remaining
; 1 s tick budget. Tick-counted so a save/load mid-poll cannot strand it.
Actor ResumePendingActor
Int ResumePendingGap = 0
Int ResumePendingTicksLeft = 0

; One-shot migration sentinels (script variables, so they ride the save):
; lastInteractionSec (cosave v8) and playerBlurb (v9) backfilled from StorageUtil.
Int InteractionTimeMigrationDone = 0
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
    ; Clear a stale engine update registration an old save may carry. The slot is
    ; form-keyed, so this clears it for the whole quest; nothing on this form
    ; defines OnUpdate, and the game-time slot is separate and untouched.
    UnregisterForUpdate()
    ChronoArm(30.0)
    ; No OnPlayerLoadGame registration: the followers provider's load stage 1
    ; calls Maintenance() on every load, which covers the essential re-apply.

    ; One-shot: move saves still on the old MaxFollowers default (20) to 100; a
    ; different custom value is kept.
    If StorageUtil.GetIntValue(None, "SeverActions_MaxFollowersMigDone", 0) < 1
        If MaxFollowers == 20
            MaxFollowers = 100
        EndIf
        StorageUtil.SetIntValue(None, "SeverActions_MaxFollowersMigDone", 1)
    EndIf

    If !PendingDismissQueue
        PendingDismissQueue = new Actor[32]
    EndIf

    ; One-shot: backfill FollowerData.lastInteractionSec from
    ; StorageUtil(KEY_LAST_INTERACTION) (kept afterwards only for PurgeFollower to unset).
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

    ; One-shot: backfill FollowerData.playerBlurb from StorageUtil(SeverFollower_PlayerBlurb).
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

    ; The native HealerPoll and CellCatchup configs reset on plugin reload; push
    ; the user's tunings on every load.
    SyncHealerConfig()
    SyncCellCatchupConfig()

    ; Prompt cache: the nearby-ref prompt reads the excluded tags from StorageUtil.
    SyncNearbyExcludedToStorageUtil()

    ; Clamp an out-of-range uiScale (a 0 renders the UI at its 0.8 minimum) back
    ; to 1.0. The bounds match the in-app slider; the frontend migrates an old 1.5.
    If SeverActionsNativeExt2.Settings_GetFloat("uiScale") < 0.8 || SeverActionsNativeExt2.Settings_GetFloat("uiScale") > 2.0
        SeverActionsNativeExt2.Settings_Set("uiScale", "1.0")
    EndIf

    ; One-shot: reset uiScale to the 1.0 "unset" sentinel so the frontend's
    ; auto density applies until the user moves a slider (the twin of the
    ; frontend's prismaui-scale-mig-135 one-shot; without it a stored explicit
    ; value would re-mark the user explicit).
    If StorageUtil.GetIntValue(None, "SeverActions_UIScale135Mig", 0) < 1
        SeverActionsNativeExt2.Settings_Set("uiScale", "1.0")
        StorageUtil.SetIntValue(None, "SeverActions_UIScale135Mig", 1)
    EndIf

    SyncUIScaleToStorageUtil()

    ; Native teammate detection (instant onboarding)
    RegisterForModEvent("SeverActions_NewTeammateDetected", "OnNativeTeammateDetected")
    RegisterForModEvent("SeverActions_TeammateRemoved", "OnNativeTeammateRemoved")
    RegisterForModEvent("SeverActions_TeammateResumed", "OnNativeTeammateResumed")

    RegisterForModEvent("SeverActions_OrphanCleanup", "OnOrphanCleanup")
    ; The shared native furniture cleanup, under its canonical callback (M-E),
    ; filtered to the bed sleepers ProcessHomeSleep registers and, without the travel
    ; module, every furniture user (only this module registers them then).
    RegisterForModEvent("SeverActionsNative_FurnitureCleanup", "OnNativeFurnitureCleanup")
    ; The DLL's CompanionSeating: sit a companion down when the player sits.
    RegisterForModEvent("SeverActions_CompanionSeat", "OnCompanionSeat")

    ; The followers module's verb event (M-V): the Actions page's follower and follow verbs.
    RegisterForModEvent("SeverActions_Verb_Followers", "OnVerb_Followers")
    ; The UI's package-management buttons.
    RegisterForModEvent("SeverActions_MagelightClearPkgs", "OnPrismaClearPkgs")
    RegisterForModEvent("SeverActions_MagelightRemovePkg", "OnPrismaRemovePkg")
    ; The module's hotkey event (M-K): the follow, companion and home hotkeys.
    RegisterForModEvent("SeverActions_Hotkey_Followers", "OnHotkey_Followers")

    ; Vanilla follower dialogue routing (native VanillaFollowTopicMonitor)
    RegisterForModEvent("SeverActions_VanillaFollowTopic", "OnVanillaFollowTopic")

    ; Re-apply home sandbox overrides for track-only followers on cell load
    ; (a cell transition can drop a PO3 override from the active stack)
    RegisterForModEvent("SeverActions_CellLoaded", "OnCellLoadedReapplyHome")

    ; HomeSandboxVerifier found a dismissed homed NPC on no package or an engine
    ; fallback one (resetAI cannot recover it): re-assert her hold.
    RegisterForModEvent("SeverActions_HomeFallbackReassert", "OnHomeFallbackReassert")
    ; The DLL: an NPC the schedule holds entered a SexLab or OStim scene (OnSchedYield).
    RegisterForModEvent("SeverActions_SchedYield", "OnSchedYield")

    ; UI actions. ModEvents, because DispatchMethodCall returns true and never runs.
    RegisterForModEvent("SeverActions_MagelightAssignHome", "OnPrismaAssignHome")
    RegisterForModEvent("SeverActions_MagelightClearHome", "OnPrismaClearHome")
    RegisterForModEvent("SeverActions_MagelightForceRemove", "OnPrismaForceRemove")
    RegisterForModEvent("SeverActions_MagelightSoftReset", "OnPrismaSoftReset")
    RegisterForModEvent("SeverActions_MagelightDismiss", "OnPrismaDismiss")
    RegisterForModEvent("SeverActions_MagelightResetAll", "OnPrismaResetAll")
    RegisterForModEvent("SeverActions_MagelightCompanionWait", "OnPrismaCompanionWait")
    RegisterForModEvent("SeverActions_MagelightCustomAIOverride", "OnPrismaCustomAIOverride")
    RegisterForModEvent("SeverActions_MagelightCompanionFollow", "OnPrismaCompanionFollow")
    RegisterForModEvent("SeverActions_MagelightCompanionWaitAll", "OnPrismaCompanionWaitAll")
    RegisterForModEvent("SeverActions_MagelightCompanionFollowAll", "OnPrismaCompanionFollowAll")
    RegisterForModEvent("SeverActions_SetCombatStyle", "OnPrismaSetCombatStyle")
    RegisterForModEvent("SeverActions_SetEssential", "OnPrismaSetEssential")
    RegisterForModEvent("SeverActions_SetNearbyExcluded", "OnPrismaSetNearbyExcluded")
    RegisterForModEvent("SeverActions_SetUIScale", "OnPrismaSetUIScale")

    ; Schedule system: UI work/play location assignment
    RegisterForModEvent("SeverActions_MagelightSetWorkLoc", "OnPrismaSetWorkLoc")
    RegisterForModEvent("SeverActions_MagelightClearWorkLoc", "OnPrismaClearWorkLoc")
    RegisterForModEvent("SeverActions_MagelightSetPlayLoc", "OnPrismaSetPlayLoc")
    RegisterForModEvent("SeverActions_MagelightClearPlayLoc", "OnPrismaClearPlayLoc")

    ; Registered by other scripts on this quest, so NEVER here too (one ModEvent
    ; name per quest form, check 18 (b)): SeverActions_OutfitAliasDisplaced
    ; (Outfit), SeverActions_RetainerWorkLoc (Enterprises), SeverActions_OffScreenLifeReady
    ; / _AssessRelNow (CompanionLife / CompanionMind), SeverActions_AmbientBanterReady
    ; / _AmbientActionReady (Ambient), SeverActions_ReputationAssess (Familiarity).

    ; The DLL dispatches quest-awareness summaries and completion memories itself
    ; (P2-10); drop the old pump registrations a save may still carry.
    UnregisterForModEvent("SeverActions_QuestSummaryReady")
    UnregisterForModEvent("SeverActions_QuestCompleted")

    ; Native HealerPoll fires this (~1s in combat) for a healer that passes its
    ; gates; the handler casts, adds the bonus heal and plays the voice line.
    RegisterForModEvent("SeverActionsNative_HealerCast", "OnHealerCast")

    ; The native orphan scanner arms itself by FormID (M-O) and is off by default
    ; (issue #561 step 1).

    ; The tick guard is save-persisted; clear it so a save made mid-tick cannot
    ; stall the 30s loop. (Each LLM module's Maintenance clears its own flags.)
    IsUpdating = false

    ; Push the settings rows the native stores hold only in memory.
    SeverActionsNative.Native_QuestAwareness_SetOutputCap(SeverActionsNativeExt2.Settings_GetInt("questAwarenessOutputCap"))

    ; The quest-awareness master toggle (the prompt-presence guard is C++'s own).
    SeverActionsNativeExt.Native_QuestAwareness_SetEnabled(SeverActionsNativeExt2.Settings_GetBool("questAwarenessEnabled"))

    ; Enterprises: weekly story budget, output scaler, and the raise / loan /
    ; ambush / Temper / renown-cap switches.
    SeverActionsNativeExt2.Venture_SetStoryCap(SeverActionsNativeExt2.Settings_GetInt("enterpriseStoryCap"))

    SeverActionsNativeExt2.Venture_SetProductionMult(SeverActionsNativeExt2.Settings_GetInt("enterpriseOutputPct"))

    SeverActionsNativeExt2.Venture_SetRaisesEnabled(SeverActionsNativeExt2.Settings_GetBool("enterpriseRaisesEnabled"))
    SeverActionsNativeExt2.Venture_SetLoansEnabled(SeverActionsNativeExt2.Settings_GetBool("enterpriseLoansEnabled"))

    SeverActionsNativeExt2.Venture_SetAmbushesEnabled(SeverActionsNativeExt2.Settings_GetBool("enterpriseAmbushesEnabled"))

    SeverActionsNativeExt2.Venture_SetTemperEnabled(SeverActionsNativeExt2.Settings_GetBool("enterpriseTemperEnabled"))

    ; SeverActions_Enterprises._MigrateRenownCap runs after this (a later stage)
    ; and pushes its migrated value itself.
    SeverActionsNativeExt2.Venture_SetRenownCapEnabled(SeverActionsNativeExt2.Settings_GetBool("enterpriseRenownCapEnabled"))

    ; Multi-floor sandboxing: C++ records the load order's cylinder bounds on the
    ; first call and only ever widens them.
    SeverActionsNativeExt2.Sandbox_SetCylinder(SeverActionsNativeExt2.Settings_GetBool("sandboxMultiFloorEnabled"), SeverActionsNativeExt2.Settings_GetInt("sandboxCylinderHeight") as Float)

    ; The heavy per-follower passes run from the next tick (RunDeferredMaintenance),
    ; so SeverActions_Init's Initialize() returns at once; no other Init step needs them.
    DeferredMaintenancePending = true
    ChronoArm(0.1)
EndFunction

; Deferred maintenance: the heavy per-follower load passes, run from the chrono
; tick 0.1s after Maintenance().
Function RunDeferredMaintenance()
    Debug.Trace("[SeverActions_FollowerManager] Running deferred maintenance...")

    ; Auto-detect followers recruited outside our system (vanilla dialogue, NFF, other mods)
    DetectExistingFollowers()

    ; Re-flag custom-AI followers who joined before SPID gave them the keyword
    ; (cosaved with isFollower=false because onboarding skipped them).
    RecoverCustomAIFollowers()

    ; hasFollowPkg ("SA drives this follow package") is sticky in the cosave:
    ; release SA's follow claim on anyone who now classifies hands-off, or SA
    ; packages fight their framework (FollowDriftMonitor cancels the player's
    ; Wait, CellCatchup drags them).
    ReconcileTrackOnlyOwnership()

    ; The reverse: adopt NFF followers SA never rostered (recruited off-cell, or a
    ; save made mid-recruit).
    AdoptUnrosteredNFFFollowers()

    ; The legacy FrameworkMode migration stays at the tail of this function and
    ; never maps 1 -> 0, so it cannot undo the NFF default below. Do not add a
    ; second copy of it here.

    ; NFF present: default to Tracking mode once (the supported way to coexist).
    ; One-shot, so a player who switches back to SeverActions mode keeps it.
    If SeverActionsNativeExt2.Native_IsNFFInstalled() && StorageUtil.GetIntValue(None, "SeverActions_NFFModeDefaulted", 0) < 1
        StorageUtil.SetIntValue(None, "SeverActions_NFFModeDefaulted", 1)
        If SeverActionsNativeExt2.Settings_GetInt("frameworkMode") != 1
            SeverActionsNativeExt2.Settings_Set("frameworkMode", "1")
            ; Settings_Set writes this save's Authority row only, not the global
            ; settings file (a script write there fails check 22c). A player who
            ; set the mode in the UI has a global-file entry, and it rightly wins
            ; at the next load.
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("followermanager.nethersFollowerFrameworkDetected"))
            Debug.Trace("[SeverActions_FollowerManager] NFF detected - FrameworkMode defaulted to Tracking (1)")
        EndIf
    EndIf

    ; GetAllFollowers() is a full cell scan; do it once and pass the array down.
    Actor[] cachedFollowers = GetAllFollowers()

    ; Orphan-scanner re-registration FIRST, before anything slow: the native side
    ; holds every scan until MarkRosterSynced (120 s cap). Only matters with the
    ; scanner on (orphanCleanupEnabled).
    Int orphRi = 0
    While orphRi < cachedFollowers.Length
        If cachedFollowers[orphRi]
            SeverActionsNative.OrphanCleanup_RegisterFollower(cachedFollowers[orphRi])
        EndIf
        orphRi += 1
    EndWhile
    SeverActionsNative.OrphanCleanup_MarkRosterSynced()
    Debug.Trace("[SeverActions_FollowerManager] Orphan-scanner roster synced (" + cachedFollowers.Length + " followers) - scans released")

    ; Re-run the native hydrator for followers the two passes above added after
    ; the kPostLoadGame run (idempotent). DidRun is then true iff anyone was
    ; hydrated, and the Papyrus fallbacks below skip on it.
    SeverActionsNativeExt.Native_HydrateFollowerSystem_Run()

    Bool hydratorDidRun = SeverActionsNativeExt.Native_HydrateFollowerSystem_DidRun()

    ; A no-op now: the native FollowerDataStore is authoritative.
    SyncAllRelationshipsOnLoad(cachedFollowers)

    ; (The outfit alias re-seat is the outfit provider's stage 2.)

    ; Combat style AVs can be reverted by NFF/EFF or a dismiss/recruit cycle; the
    ; hydrator re-applies them (including followers found this pass, via the Run
    ; above), so Papyrus does it only when the hydrator did not run.
    If !hydratorDidRun
        ReapplyCombatStyles(cachedFollowers)
    EndIf

    ; IgnoreFriendlyHits does not reliably survive save/load on mod-added followers;
    ; with the faction's Ally reactions it keeps stray AoE from turning followers on
    ; each other or the player. Idempotent.
    ApplyIgnoreFriendlyHits(cachedFollowers)
    RefreshTrapImmunity(cachedFollowers)

    ; Ensure vanilla-path followers hold CurrentFollowerFaction + Ally rank
    PatchUpVanillaFollowerStatus(cachedFollowers)

    ; One-shot: import the legacy StorageUtil pair relationships into the native
    ; pair store (current saves write the cosave directly).
    If StorageUtil.GetIntValue(None, "SeverActions_PairSyncMigDone", 0) < 1
        SyncAllPairRelationshipsOnLoad(cachedFollowers)
        StorageUtil.SetIntValue(None, "SeverActions_PairSyncMigDone", 1)

        ; The kPostLoadGame hydrator built companionOpinions from the empty pair
        ; store; rebuild it from the imported pairs.
        SeverActionsNativeExt.Native_HydrateFollowerSystem_Run()
    EndIf

    ; T1-B one-shot: copy the legacy per-follower scalars and dedup watermarks
    ; from StorageUtil into native FollowerData.
    If StorageUtil.GetIntValue(None, "SeverActions_T1BMigrationDone", 0) == 0
        SyncFollowerScalarsOnLoad(cachedFollowers)
        StorageUtil.SetIntValue(None, "SeverActions_T1BMigrationDone", 1)
    EndIf

    ; One-shot: add BardAudienceExcludedFaction to the existing roster so they do
    ; not drop their follow package to watch a bard (onboarding adds it, dismiss
    ; clears it). A faction add, so safe on track-only followers.
    If StorageUtil.GetIntValue(None, "SeverActions_BardExcludeMigDone", 0) < 1
        Int bardIdx = 0
        While bardIdx < cachedFollowers.Length
            AddBardAudienceExclusion(cachedFollowers[bardIdx])
            bardIdx += 1
        EndWhile
        StorageUtil.SetIntValue(None, "SeverActions_BardExcludeMigDone", 1)
    EndIf

    ; Essential comes from the quest's alias slots (works live on templated NPCs).
    ; Fills are not guaranteed across a load and the hydrator restores only the
    ; base flag, so rebuild the pool from cosaved intent every load.
    ReassignEssentialSlots(cachedFollowers)

    ; T1-A.2 one-shot: CompanionOpinions + LifeEventHistory from StorageUtil into
    ; native FollowerData (for LifeEventHistory the only way across).
    If StorageUtil.GetIntValue(None, "SeverActions_T1A2MigrationDone", 0) == 0
        SyncFollowerStringBlobsOnLoad(cachedFollowers)
        StorageUtil.SetIntValue(None, "SeverActions_T1A2MigrationDone", 1)
    EndIf

    ; T1-A.3 one-shot: the LifeSummary / WorkLocation / PlayLocation labels.
    If StorageUtil.GetIntValue(None, "SeverActions_T1A3MigrationDone", 0) == 0
        SyncFollowerStringLabelsOnLoad(cachedFollowers)
        StorageUtil.SetIntValue(None, "SeverActions_T1A3MigrationDone", 1)
    EndIf

    ; One-shot: borrow-a-home-slot workers onto the Route B pool, once its records
    ; resolve.
    If GetWorkAnchorKeyword() && StorageUtil.GetIntValue(None, KEY_WORKPOOL_MIG, 0) < 1
        MigrateWorkPoolOnLoad()
        StorageUtil.SetIntValue(None, KEY_WORKPOOL_MIG, 1)
    EndIf

    ; Before the migration snapshot and the load sweep read the rosters (the sweep clears a holder on neither list).
    _ClearRelaxRelics()
    _RelistAssignedRows()

    ; First load with a capable ESP starts the one-way Route B -> alias migration
    ; (drained in 0.5s ticks); afterwards only the drift sweep runs.
    If EnsureSchedQuests() && !SeverActionsNativeExt.Native_GetAliasesMigrated()
        BeginSchedAliasMigration()
    EndIf
    SweepSchedAliasesOnLoad()
    ; Guard pool (FLWD v19): override-era adoption + pool reconciliation.
    SweepGuardAliasesOnLoad()

    ; The native hydrator is the one writer of companionOpinions; when its load
    ; pass did not run, run its opinions pass here.
    If !hydratorDidRun
        SeverActionsNativeExt2.Native_HydrateFollowerSystem_RebuildOpinions()
    EndIf

    ; Follow pool sweep + follow tracking, in every mode: ReapplyFollowTracking
    ; skips hands-off actors itself, and the pool sweep is needed in Tracking mode
    ; too (do not gate this on mode 0). ReconcileTrackOnlyOwnership ran above, so
    ; seats SA must not hold are already gone.
    SeverActions_Follow followSys = GetFollowScript()
    If followSys
        ; Pool sweep (FLWD v18) BEFORE the re-apply, so it sees pool state.
        followSys.SweepFollowAliasesOnLoad(cachedFollowers)
        followSys.ReapplyFollowTracking(cachedFollowers)
    EndIf

    ; PO3's override survives in its cosave, but a cell transition or 3D unload
    ; can drop it from the active stack and PO3's re-apply timing is not
    ; guaranteed, so re-apply the home sandboxes on every load.
    ReapplyHomeSandboxing()

    ; KEY_LAST_SCHEDULED_TYPE rides the save, so after a load the swap logic would
    ; see no transition and leave markers and overrides stale until the next
    ; boundary. Stamp -99 so the first tick re-resolves everyone. Pre-migration
    ; only: the alias pools persist and ReconcileSchedAliasesFor handles their drift.
    If !SchedSystemActive()
        Actor[] stampHomed = GetAllHomedNPCs()
        Int stampI = 0
        While stampI < stampHomed.Length
            If stampHomed[stampI]
                StorageUtil.SetIntValue(stampHomed[stampI], KEY_LAST_SCHEDULED_TYPE, -99)
            EndIf
            stampI += 1
        EndWhile
        Int stampWorkCount = StorageUtil.FormListCount(None, KEY_WORK_ONLY_NPCS)
        stampI = 0
        While stampI < stampWorkCount
            Actor stampNpc = StorageUtil.FormListGet(None, KEY_WORK_ONLY_NPCS, stampI) as Actor
            If stampNpc
                StorageUtil.SetIntValue(stampNpc, KEY_LAST_SCHEDULED_TYPE, -99)
            EndIf
            stampI += 1
        EndWhile
    EndIf

    ; OnSleepStart clears orphaned packages when the player sleeps.
    RegisterForSleep()

    ; One-shot fold of the old 3-value FrameworkMode (0 Auto, 1 SeverActions Only,
    ; 2 Tracking Only) into 0 SeverActions / 1 Tracking. An old 1 cannot be told
    ; from today's Tracking, so only 2 is folded: never map 1 -> 0, which
    ; silently reverted a Tracking choice on load. Sentinel 2 re-runs the
    ; corrected pass once for saves that took the old one.
    If StorageUtil.GetIntValue(None, "SeverActions_FrameworkModeMigrated", 0) < 2
        If SeverActionsNativeExt2.Settings_GetInt("frameworkMode") >= 2
            SeverActionsNativeExt2.Settings_Set("frameworkMode", "1")  ; old "Tracking Only" -> new "Tracking"
            Debug.Trace("[SeverActions_FollowerManager] Migrated FrameworkMode 2 -> 1 (Tracking)")
        EndIf
        StorageUtil.SetIntValue(None, "SeverActions_FrameworkModeMigrated", 2)
    EndIf

    Debug.Trace("[SeverActions_FollowerManager] Maintenance complete - Mode: " + SeverActionsNativeExt2.Settings_GetInt("frameworkMode"))
EndFunction

; =============================================================================
; SLEEP EVENT — CLEAR SANDBOX PACKAGES
; =============================================================================

Event OnSleepStart(Float afSleepStartTime, Float afDesiredSleepEndTime)
    {On sleep, clear the orphaned FF runtime package a time-skip can leave on an
     actively-following same-cell follower, so follow re-asserts on wake. Waiters,
     sandboxers, track-only followers and other-cell followers are left alone.}
    Cell playerCell = Game.GetPlayer().GetParentCell()
    If !playerCell
        Return
    EndIf

    Actor[] followers = GetAllFollowers()
    Int i = 0
    While i < followers.Length
        Actor f = followers[i]
        If f && f.GetParentCell() == playerCell
            If f.GetAV("WaitingForPlayer") > 0 || SeverActionsNativeExt.Native_GetSandboxing(f)
                ; Home/work sandbox (WFP 2), relax (WFP 1 or the native flag alone for
                ; track-only relaxers) or manual Wait: sleeping never ends them.
                Debug.Trace("[SeverActions_FollowerManager] Leaving waiting/sandboxing " + f.GetDisplayName() + " alone on sleep")
            ElseIf _OnJourney(f)
                ; The clear would strip the journey's walk override.
                Debug.Trace("[SeverActions_FollowerManager] Leaving traveling " + f.GetDisplayName() + " alone on sleep")
            ElseIf SeverActionsNativeExt2.Native_IsTrackOnlyFollower(f)
                ; Their framework owns the package stack: ClearPackageOverride would wipe
                ; its follow package with no re-apply hook.
                Debug.Trace("[SeverActions_FollowerManager] Skipping track-only " + f.GetDisplayName() + " on sleep (external AI owns packages)")
            Else
                ActorUtil.ClearPackageOverride(f)
                SkyrimNetApi.ReinforcePackages(f)
                ; Overflow companions follow via a PO3 override the clear just wiped,
                ; which ReinforcePackages cannot restore (not SkyrimNet-registered).
                If StorageUtil.GetIntValue(f, "SeverFollow_Overflow", 0) == 1
                    SeverActions_Follow fSleep = (Self as Quest) as SeverActions_Follow
                    If fSleep
                        fSleep.ApplyOverflowFollow(f)
                    EndIf
                EndIf
                f.EvaluatePackage()
                Debug.Trace("[SeverActions_FollowerManager] Cleared FF orphan for actively-following " + f.GetDisplayName() + " on sleep")
            EndIf
        EndIf
        i += 1
    EndWhile
EndEvent

; =============================================================================
; AUTO-DETECTION OF EXISTING FOLLOWERS
; =============================================================================

Function DetectExistingFollowers()
    {Onboard (Tracking Mode) followers in the player's cell that SA does not track
     yet. With followers already in the cosave only custom-AI teammates are checked
     (TeammateMonitor catches new recruits); otherwise any follower-faction member.}
    Actor player = Game.GetPlayer()
    Cell playerCell = player.GetParentCell()
    If !playerCell
        Return
    EndIf

    ; The cosave is authoritative once it has followers (see the hasNativeData arm).
    Actor[] nativeTracked = SeverActionsNative.Native_GetAllTrackedFollowers()
    Bool hasNativeData = nativeTracked && nativeTracked.Length > 0

    Faction currentFollowerFaction = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction

    ; Serana uses DLC1SeranaFaction instead of CurrentFollowerFaction
    Faction seranaFaction = Game.GetFormFromFile(0x000183A5, "Dawnguard.esm") as Faction

    ; Already filtered natively to live, non-player, non-commanded actors.
    Actor[] cellActors = SeverActionsNativeExt.Native_ScanPlayerCellForLiveActors()
    Int numRefs = cellActors.Length
    Int detected = 0
    Int i = 0

    While i < numRefs
        Actor actorRef = cellActors[i]

        If actorRef
            If SeverActions_FollowerFaction && actorRef.IsInFaction(SeverActions_FollowerFaction)
                ; Already tracked.
            Else
                If hasNativeData
                    ; TeammateMonitor catches new recruits; only a custom-AI follower who
                    ; joined before its SPID keyword arrived can be untracked here.
                    If HasCustomAIKeyword(actorRef) && actorRef.IsPlayerTeammate() && !IsRegisteredFollower(actorRef) \
                        && StorageUtil.GetIntValue(actorRef, KEY_DISMISSED, 0) == 0
                        ; Known to the cosave: keep their data (no first-recruit defaults).
                        _OnboardTrackingMode(actorRef, false)
                        detected += 1
                        Debug.Trace("[SeverActions_FollowerManager] DetectExisting: Recovered custom AI follower " + actorRef.GetDisplayName())
                    EndIf
                Else
                    ; IsPlayerTeammate alone is not enough (many mods set it for their own
                    ; mechanics): require a recognized follower faction.
                    Bool isGameFollower = false

                    ; Rank >= 0: NFF leaves dismissed followers in the faction at rank -1.
                    If currentFollowerFaction
                        If actorRef.IsInFaction(currentFollowerFaction) && actorRef.GetFactionRank(currentFollowerFaction) >= 0
                            isGameFollower = true
                        EndIf
                    EndIf

                    If !isGameFollower && seranaFaction
                        isGameFollower = actorRef.IsInFaction(seranaFaction)
                    EndIf

                    ; A custom-AI (SPID keyword) teammate counts unless explicitly dismissed
                    ; (their mods keep IsPlayerTeammate() true).
                    If !isGameFollower && HasCustomAIKeyword(actorRef) && actorRef.IsPlayerTeammate() \
                        && StorageUtil.GetIntValue(actorRef, KEY_DISMISSED, 0) == 0
                        isGameFollower = true
                    EndIf

                    If isGameFollower && !IsRegisteredFollower(actorRef)
                        ; Recruited elsewhere (vanilla dialogue, another mod, before install):
                        ; track everything, leave their AI packages alone.

                        ; Native_WasEverFollower survives soft-dismiss until Purge. HasData is
                        ; not a follower test (travel, forced combat and casual follow make rows).
                        Bool isReturning = false
                        If SeverActions_FollowerFaction && actorRef.IsInFaction(SeverActions_FollowerFaction)
                            isReturning = true
                        ElseIf SeverActionsNativeExt2.Native_WasEverFollower(actorRef)
                            isReturning = true
                        EndIf

                        _OnboardTrackingMode(actorRef, !isReturning)

                        If isReturning
                            Debug.Trace("[SeverActions_FollowerManager] Returning follower re-detected - preserving existing data for " + actorRef.GetDisplayName())
                        Else
                            Debug.Trace("[SeverActions_FollowerManager] New follower detected - initialized defaults for " + actorRef.GetDisplayName())
                        EndIf

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
        If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.existingCompanionsDetected", ("" + detected)))
        EndIf
    EndIf
EndFunction

Function RecoverCustomAIFollowers()
    {Re-onboard actors in the player's cell who hold SeverActions_FollowerFaction
     (added on every registration, persists in the save) or are custom-AI teammates,
     but have lost their tracking. Explicitly dismissed actors are skipped.}
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
                Bool shouldRecover = false

                If SeverActions_FollowerFaction && actorRef.IsInFaction(SeverActions_FollowerFaction) \
                    && StorageUtil.GetIntValue(actorRef, KEY_DISMISSED, 0) == 0
                    shouldRecover = true
                ElseIf HasCustomAIKeyword(actorRef) && actorRef.IsPlayerTeammate()
                    ; Custom follower mods keep IsPlayerTeammate() true after a dismiss.
                    If StorageUtil.GetIntValue(actorRef, KEY_DISMISSED, 0) == 0
                        shouldRecover = true
                    EndIf
                EndIf

                If shouldRecover
                    _OnboardTrackingMode(actorRef, !SeverActionsNativeExt2.Native_WasEverFollower(actorRef))
                    recovered += 1
                    Debug.Trace("[SeverActions_FollowerManager] RecoverCustomAI: Recovered " + actorRef.GetDisplayName())
                EndIf
            EndIf
        EndIf

        i += 1
    EndWhile

    If recovered > 0
        Debug.Trace("[SeverActions_FollowerManager] RecoverCustomAI: Recovered " + recovered + " custom AI follower(s)")
        If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.customCompanionsRecovered", ("" + recovered)))
        EndIf
    EndIf
EndFunction

; =============================================================================
; NATIVE TEAMMATE EVENTS (TeammateMonitor)
; =============================================================================

Event OnNativeTeammateDetected(string eventName, string strArg, float numArg, Form sender)
    {Debounced onboarding: TeammateMonitor fires this once SetPlayerTeammate(true)
     has held for CONFIRM_SCANS (5) one-second scans, or on the follower/hireling
     rank's confirmed false->true edge (kEnlistConfirmScans), so transient flips never arrive.}
    Actor akActor = sender as Actor
    if !akActor
        akActor = Game.GetFormEx(numArg as int) as Actor
    endif
    OnboardExternalTeammate(akActor)
EndEvent

Function OnboardExternalTeammate(Actor akActor, Bool abSkipOpinionRebuild = false)
    {External-recruit onboarding, from OnNativeTeammateDetected, the load-time NFF
     adopt, and the resume path for an ex-follower SA unregistered and the player
     re-recruited through the framework inside the removal window (the monitor never
     re-fires Detected for them). abSkipOpinionRebuild: a batch caller rebuilds
     opinions once itself.}
    if !akActor || akActor.IsDead()
        return
    endif

    ; Skip summoned creatures (conjuration, Durnehviir, etc.)
    If akActor.IsCommandedActor()
        return
    EndIf

    ; RegisterFollower's refusals: a Final-Audit collector, and a bound captive
    ; (kidnap phase >= 2) who would fight the hold pin. The native pre-filter
    ; excludes them too; this is the authoritative gate for every entry point.
    If SeverActionsNativeExt2.Venture_Audit_IsCollector(akActor)
        Debug.Trace("[SeverActions_FollowerManager] OnboardExternalTeammate: refusing Final-Audit collector " + akActor.GetDisplayName())
        return
    EndIf
    If SeverActionsNativeExt.Native_Kidnap_GetPhase(akActor) >= 2
        Debug.Trace("[SeverActions_FollowerManager] OnboardExternalTeammate: refusing bound captive " + akActor.GetDisplayName())
        return
    EndIf

    ; The ownership classification here and in _OnboardTrackingMode reads the DLL
    ; live (no memo), so an NFF seat made at the enlistment edge is already seen.

    If IsRegisteredFollower(akActor)
        If SeverActionsNativeExt2.Native_IsTrackOnlyFollower(akActor)
            ; Their framework flips the teammate flag during its own behaviors:
            ; never re-onboard (no notification, strip or recruit event).
            Debug.Trace("[SeverActions_FollowerManager] Teammate re-flip on registered track-only follower - no-op: " + akActor.GetDisplayName())
        EndIf
        return
    EndIf

    ; In our faction: skip (the cosave data may not be loaded yet).
    If SeverActions_FollowerFaction && akActor.IsInFaction(SeverActions_FollowerFaction)
        return
    EndIf

    ; Explicitly dismissed: skip, or custom followers (whose mods keep the teammate
    ; flag) would re-register forever. A debounced sustained teammate at WFP 0
    ; (following) or WFP 2 (parked in our home/work/relax sandbox, where a dismissed
    ; homed NPC sits permanently) is a genuine re-recruit: clear the flag and fall
    ; through to the onboard and strips below. WFP 1 (Wait) and -1 (custom dismiss) bail.
    If StorageUtil.GetIntValue(akActor, KEY_DISMISSED, 0) == 1
        Float wfpDismiss = akActor.GetAV("WaitingForPlayer")
        If wfpDismiss == 0.0 || wfpDismiss == 2.0
            StorageUtil.UnsetIntValue(akActor, KEY_DISMISSED)
            DebugMsg("Dismissed flag cleared - re-recruited (WFP=" + wfpDismiss + "): " + akActor.GetDisplayName())
        Else
            return
        EndIf
    EndIf

    ; Require CurrentFollowerFaction (rank >= 0) or Serana's faction, as in
    ; DetectExistingFollowers; custom-AI keyword holders bypass it.
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

    Bool isFirstRecruit = !SeverActionsNativeExt2.Native_WasEverFollower(akActor)

    If isFirstRecruit
        Debug.Trace("[SeverActions_FollowerManager] Native teammate detected (NEW): " + akActor.GetDisplayName())
    Else
        Debug.Trace("[SeverActions_FollowerManager] Native teammate detected (RETURNING): " + akActor.GetDisplayName())
    EndIf

    _OnboardTrackingMode(akActor, isFirstRecruit)

    ; Opinions of and from the roster at once, as RegisterFollower does. The batch
    ; adopt pass (AdoptUnrosteredNFFFollowers) runs this O(N^2) rebuild once itself.
    If !abSkipOpinionRebuild
        SeverActionsNativeExt2.Native_HydrateFollowerSystem_RebuildOpinions()
    EndIf

    ; Their framework drives follow now: drop every SA sandbox that would outrank
    ; it, and the schedule pool aliases too (StripSandboxesForFollow leaves those).
    StripSandboxesForFollow(akActor)
    ClearWorkSandboxForFollow(akActor)
    EmptySchedAliasesForFollow(akActor)
    Int calledEvt = ModEvent.Create("SeverActions_FollowerCalledByPlayer")
    If calledEvt
        ModEvent.PushString(calledEvt, "SeverActions_FollowerCalledByPlayer")
        ModEvent.PushString(calledEvt, "recruit")
        ModEvent.PushFloat(calledEvt, 0.0)
        ModEvent.PushForm(calledEvt, akActor)
        ModEvent.Send(calledEvt)
    EndIf

    If isFirstRecruit
        If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.isNowBeingTracked", ("" + akActor.GetDisplayName())))
        EndIf

        SkyrimNetApi.RegisterEvent("follower_recruited", \
            akActor.GetDisplayName() + " is now traveling with " + Game.GetPlayer().GetDisplayName() + " as a companion.", \
            akActor, Game.GetPlayer())

        DebugMsg("Native teammate detected (tracking only): " + akActor.GetDisplayName())
    Else
        If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.hasReturned", ("" + akActor.GetDisplayName())))
        EndIf

        DebugMsg("Returning follower re-registered: " + akActor.GetDisplayName())
    EndIf
EndFunction

Event OnNativeTeammateResumed(string eventName, string strArg, float numArg, Form sender)
    {A known teammate's flag or enlistment came back after a real gap
     (kResumeMinScans) but before the ~5 s dismiss confirmation: dismissed and
     re-recruited through the framework's dialogue inside the window. No recruit strips ran, so SA's sandbox
     (priority 100) or schedule alias (quest priority 101) would outrank the framework's follow
     package. numArg: the gap in scans, diagnostic only.}
    Actor akActor = sender as Actor
    If !akActor || akActor.IsDead()
        Return
    EndIf
    ; For a hireling this fires on CurrentHireling (0xBD738), a beat before the
    ; teammate flag and follower faction land, so wait for enlistment. Never block
    ; here (a parked ModEvent handler stalls every sibling event on the quest):
    ; stash the actor and poll from the chrono tick, 1 s x 10 (PollTeammateResume).
    If _TeammateResumeEnlisted(akActor)
        _RunTeammateResumeStrips(akActor, numArg as Int, 0)
        Return
    EndIf
    ResumePendingActor = akActor
    ResumePendingGap = numArg as Int
    ResumePendingTicksLeft = 10
    ChronoArm(1.0)
EndEvent

Bool Function _TeammateResumeEnlisted(Actor akActor)
    {Teammate flag OR a live CurrentFollowerFaction rank - what the onboarding gate needs.}
    Faction cff = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
    Return akActor.IsPlayerTeammate() || (cff && akActor.GetFactionRank(cff) >= 0)
EndFunction

Function PollTeammateResume()
    {Chrono-tick continuation of OnNativeTeammateResumed: run the strips once the
     stashed actor is enlisted, give up after 10 ticks. Tick-counted, so a
     save/load mid-poll cannot strand a stale deadline.}
    Actor a = ResumePendingActor
    If !a
        Return
    EndIf
    If a.IsDead()
        ResumePendingActor = None
        Return
    EndIf
    If _TeammateResumeEnlisted(a)
        Int gap = ResumePendingGap
        Int waitedSec = 10 - ResumePendingTicksLeft
        ResumePendingActor = None
        _RunTeammateResumeStrips(a, gap, waitedSec)
        Return
    EndIf
    ResumePendingTicksLeft -= 1
    If ResumePendingTicksLeft <= 0
        Debug.Trace("[SeverActions_FollowerManager] Teammate resumed (" + ResumePendingGap + "s gap) but " + a.GetDisplayName() + " never became teammate / follower-faction within 10s - leaving them alone")
        ResumePendingActor = None
    EndIf
EndFunction

Function _RunTeammateResumeStrips(Actor akActor, Int aiGap, Int aiWaitedSec)
    {The resume body: onboard an unregistered ex-follower, or strip SA's own holds
     from a registered one. Each strip is a safe no-op when inactive and touches
     only SA's own overrides / aliases.}
    If !IsRegisteredFollower(akActor)
        ; SA's own dismiss unregistered them: this is their only onboarding path.
        Debug.Trace("[SeverActions_FollowerManager] Teammate resumed on an unregistered ex-follower (" + aiGap + "s gap, enlisted after " + aiWaitedSec + "s) - onboarding: " + akActor.GetDisplayName())
        OnboardExternalTeammate(akActor)
        Return
    EndIf
    StripSandboxesForFollow(akActor)
    ClearWorkSandboxForFollow(akActor)
    EmptySchedAliasesForFollow(akActor)
    akActor.EvaluatePackage()
    ; Unconditional trace: the evidence line for this path.
    Debug.Trace("[SeverActions_FollowerManager] Teammate resumed inside the dismiss window (" + aiGap + "s gap) - SA holds stripped: " + akActor.GetDisplayName())
EndFunction

Event OnNativeTeammateRemoved(string eventName, string strArg, float numArg, Form sender)
    {TeammateMonitor confirmed a removal: kRemoveConfirmScans (~5 s) for a normal
     follower, one scan for a custom-AI follower showing a dismiss marker. Queues a
     final re-check on the chrono tick before treating it as a dismiss.}
    Actor akActor = sender as Actor
    If !akActor
        akActor = Game.GetFormEx(numArg as int) as Actor
    EndIf

    If !akActor || !IsRegisteredFollower(akActor)
        Return
    EndIf

    If SeverActionsNativeExt2.Native_IsTrackOnlyFollower(akActor)
        ; Queue it like any other: this is the only automatic path that untracks a
        ; genuine framework dismissal. Trace only.
        Debug.Trace("[SeverActions_FollowerManager] TeammateRemoved on track-only follower " + akActor.GetDisplayName() + " - passed native long confirmation, treating as genuine dismissal candidate")
    EndIf

    ; The chrono tick verifies and drains the whole queue.
    If !PendingDismissQueue
        PendingDismissQueue = new Actor[32]
    EndIf
    If !PendingDismissForgiven
        PendingDismissForgiven = new Bool[32]
    EndIf
    ; Asked on arrival, while the guard's mark is fresh (the drain can run a 30 s tick later),
    ; and before the append: the native call yields, and nothing may run between a slot
    ; write and the count. A re-fire's answer is lost harmlessly; the first arrival took the mark.
    Bool forgivenNow = SeverActionsNativeExt2.FriendlyFire_TakeForgiven(akActor, 20.0)
    If PendingDismissCount < PendingDismissQueue.Length
        Int seen = PendingDismissQueue.Find(akActor)
        If seen < 0 || seen >= PendingDismissCount
            PendingDismissQueue[PendingDismissCount] = akActor
            PendingDismissForgiven[PendingDismissCount] = forgivenNow
            PendingDismissCount += 1
            ; Arm only on a NEW entry: one dismiss can emit several TeammateRemoved as
            ; the package settles, and re-arming each time would delay the drain.
            ; Hands-off followers get 0.75 s so the home redirect lands before their
            ; framework walks them off (the drain's IsStillFollowingByEvidence still
            ; vetoes a re-recruit); SA-managed ones 2.5 s.
            Float confirmDelay = 2.5
            If WasHandsOffAtRecruit(akActor)
                confirmDelay = 0.75
            EndIf
            DebugMsg("Vanilla dismiss candidate: " + akActor.GetDisplayName() + " - confirming in " + confirmDelay + "s (queue: " + PendingDismissCount + ")")
            ChronoArm(confirmDelay)
        Else
            DebugMsg("Vanilla dismiss re-fire ignored (already queued): " + akActor.GetDisplayName())
        EndIf
    Else
        DebugMsg("Vanilla dismiss queue full (32) - dropping: " + akActor.GetDisplayName())
    EndIf
EndEvent

Event OnVanillaFollowTopic(string eventName, string strArg, float numArg, Form sender)
    {VanillaFollowTopicMonitor: the player used the vanilla Wait here / Follow me
     topic on an SA follower. SA seats at most its newest recruit in the vanilla
     DialogueFollower alias, so for the rest the vanilla fragment no-ops; route the
     verb through SA's own wait/follow.}
    Actor npc = sender as Actor
    If !npc || !IsRegisteredFollower(npc)
        Return
    EndIf
    If strArg == "wait"
        CompanionWait(npc)
    ElseIf strArg == "follow"
        CompanionFollow(npc)
    EndIf
EndEvent

Event OnOrphanCleanup(string eventName, string keywordType, float numArg, Form sender)
    {Native OrphanCleanup found an untracked actor holding one of our LinkedRef
     keywords: clear it, strip our overrides and re-evaluate. Only our types
     (travel / furniture / follow): the arrest_* types are SeverActions_Arrest's, and
     re-evaluating a live escort every 5 s scan here would break its package.}
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

    ; Kidnap participants legitimately hold our keywords (the held victim's
    ; BoundCaptiveMarker link is deliberately not a FurnitureManager user); the
    ; kidnap system owns their teardown. Mirrors SeverActions_Arrest.
    If SeverActionsNativeExt.Native_Kidnap_GetPhase(npc) != 0 \
        || SeverActionsNativeExt.Native_Kidnap_FindVictimOf(npc) != None
        Return
    EndIf

    If keywordType == "travel"
        ; The travel LinkedRef, every travel package override (the travelcore
        ; provider's stripTravelOverrides, run fallback 0x07C06A included) and the
        ; arrival sandbox, all by FormID.
        Keyword travelKW = Game.GetFormFromFile(FID_TRAVEL_TARGET_KW, "SeverActions.esp") as Keyword
        If travelKW
            SeverActionsNative.LinkedRef_Clear(npc, travelKW)
        EndIf
        SeverActions_ModuleBase.CallBool("travelcore", "stripTravelOverrides", npc)
        Package arrivalSandbox = Game.GetFormFromFile(FID_SANDBOX_PKG, "SeverActions.esp") as Package
        If arrivalSandbox
            ActorUtil.RemovePackageOverride(npc, arrivalSandbox)
        EndIf
    ElseIf keywordType == "furniture"
        SeverActionsNative.LinkedRef_Clear(npc, SeverActions_FurnitureLib.TargetKeyword())
        ActorUtil.RemovePackageOverride(npc, SeverActions_FurnitureLib.UsePackage())
        SeverActionsNative.UnregisterFurnitureUser(npc)
    ElseIf keywordType == "follow"
        Keyword followKW = Game.GetFormFromFile(FID_FOLLOW_KW, "SeverActions.esp") as Keyword
        If followKW
            SeverActionsNative.LinkedRef_Clear(npc, followKW)
        EndIf
    EndIf

    npc.EvaluatePackage()
    Debug.Trace("[SeverActions_FollowerManager] OrphanCleanup: cleared " + keywordType + " orphan on " + npc.GetDisplayName())
EndEvent

Function ReposeBoundCaptivesOnCellLoad()
    {Safe-exit stub: moved to SeverActions_Kidnap.ReposeBoundCaptivesOnCellLoad (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Event OnNativeFurnitureCleanup(string eventName, string strArg, float numArg, Form sender)
    {Canonical handler of the shared native furniture-cleanup event (M-E): stand up a bed
     sleeper this module put to bed (SeverActions_HomeSleeping) and, when the travel module
     is not usable, every furniture user (only this module registers them then, a dismissed
     companion included) - SeverActions_Furniture (travel) stands up every user, so with
     travel present a follower gets one stand-up, not two. The flag is ProcessHomeSleep's
     to drop on its next tick (dropping it here halves the re-bed cadence).}
    Actor akActor = sender as Actor
    If !akActor
        Return
    EndIf
    If StorageUtil.GetIntValue(akActor, "SeverActions_HomeSleeping", 0) != 1 \
        && SeverActionsNativeExt2.Module_IsUsable("travel")
        Return
    EndIf
    SeverActions_FurnitureLib.CleanupFor(akActor)
EndEvent

Event OnCompanionSeat(String eventName, String strArg, Float numArg, Form sender)
    {SeverActions_CompanionSeat, from the DLL's CompanionSeating when the player sits:
     sender = the companion, strArg = the seat's FormID as signed decimal. The DLL stands
     them up again through the furniture cleanup event.}
    Actor npc = sender as Actor
    ObjectReference seat = Game.GetFormEx(strArg as Int) as ObjectReference
    If !npc || !seat || npc.IsDead() || npc.IsInCombat() || npc.GetSitState() != 0
        Return
    EndIf
    ; The world moved since the DLL chose: the player got up, or the companion was told
    ; to wait, passed to another framework or the player switched to Tracking mode. Another
    ; framework's follower is seated only under followersSitWithPlayerOthers.
    Actor player = Game.GetPlayer()
    If player.GetSitState() != 3 || npc.GetAV("WaitingForPlayer") != 0
        Return
    EndIf
    If IsFollowHandsOff(npc)
        If SeverActionsNativeExt2.Settings_GetInt("frameworkMode") == 1 || !SeverActionsNativeExt2.Settings_GetBool("followersSitWithPlayerOthers")
            Return
        EndIf
    EndIf
    ; Taken since: return silently - UseRef would put a refusal in the history of a
    ; companion the player never asked to sit.
    If !SeverActionsNativeExt2.Furniture_SeatFor(npc, seat, 0.0)
        Return
    EndIf
    SeverActions_FurnitureLib.UseRef(npc, seat)
    ; UseRef spans frames: a player who stood meanwhile ended the DLL's episode before
    ; this registration landed. A belt beside the DLL's release of in-flight orders.
    If player.GetSitState() != 3
        SeverActions_FurnitureLib.Stop(npc)
    EndIf
EndEvent

Event OnCellLoadedReapplyHome(string eventName, string strArg, float numArg, Form sender)
    {OutfitDataStore's TESCellFullyLoadedEvent: rescue stranded auto-sandboxers, then
     re-assert home holds for dismissed homed NPCs and self-heal active followers.}

    ; Auto-sandboxers (isFollower + isSandboxing, not a manual wait) left behind.
    SeverActionsNativeExt.SituationMonitor_RescueSandboxers()

    If SchedSystemActive()
        ; Aliases re-apply themselves on 3D load. Re-assert the runtime assist
        ; overrides (track-only V2, guard-mode follow) cell transitions drop, and
        ; self-heal active followers as the legacy path does.
        Actor[] homedA = GetAllHomedNPCs()
        Int j = 0
        While j < homedA.Length
            Actor npcA = homedA[j]
            If npcA && npcA.Is3DLoaded()
                If IsRegisteredFollower(npcA)
                    If HoldsAnySchedAlias(npcA) || npcA.GetAV("WaitingForPlayer") == 2.0
                        EmptyAllSchedAliases(npcA)
                        If npcA.GetAV("WaitingForPlayer") == 2.0
                            npcA.SetAV("WaitingForPlayer", 0)
                        EndIf
                        npcA.EvaluatePackage()
                        DebugMsg("CellLoad self-heal: stripped stray schedule aliases from active follower " + npcA.GetDisplayName())
                    EndIf
                ElseIf HoldsAnySchedAlias(npcA) && !_OnJourney(npcA)
                    _ReassertSchedAssistsFor(npcA)
                    _EnsureHeldSchedAnchors(npcA)
                    npcA.SetAV("WaitingForPlayer", 2)
                    SeverActionsNative.EscalatedReEvaluate(npcA, 1500)
                EndIf
            EndIf
            j += 1
        EndWhile
        Return
    EndIf

    If !HomeSlots || !HomeMarkerList
        Return
    EndIf

    Actor[] homedNPCs = GetAllHomedNPCs()
    Int i = 0
    While i < homedNPCs.Length
        Actor akActor = homedNPCs[i]
        ; Dismissed followers only: an active one entering their home cell keeps following,
        ; and a traveler passing through keeps walking.
        If akActor && akActor.Is3DLoaded() && !IsRegisteredFollower(akActor) && !_OnJourney(akActor)
            Int slot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)
            If slot >= 0 && slot < HomeSlots.Length
                ; Only track-only NPCs need the PO3 override back (the rest ride the home
                ; alias package), but everyone gets the re-evaluate: the engine does not
                ; guarantee an AI tick on 3D load.
                If SeverActionsNativeExt2.Native_IsTrackOnlyFollower(akActor)
                    Package homePkg = GetHomeSandboxPackage(slot)
                    If homePkg
                        ActorUtil.AddPackageOverride(akActor, homePkg, 100, 1)
                    EndIf
                EndIf
                akActor.SetAV("WaitingForPlayer", 2)

                ; Escalating re-evaluate ending in resetAI at 1500 ms (safe: not in
                ; combat; longer than safe-interior's 1000 so cell load settles first).
                SeverActionsNative.EscalatedReEvaluate(akActor, 1500)
                DebugMsg("CellLoad: Re-evaluated home sandbox for " + akActor.GetDisplayName())
            EndIf
        ElseIf akActor && akActor.Is3DLoaded() && IsRegisteredFollower(akActor)
            ; Self-heal: an active companion left in the home sandbox (WFP 2) by a
            ; teammate flicker or a verify misfire. RemoveHomeSandbox resets WFP to 0.
            If akActor.GetAV("WaitingForPlayer") == 2.0
                RemoveHomeSandbox(akActor)
                DebugMsg("CellLoad self-heal: stripped stray home sandbox from active follower " + akActor.GetDisplayName())
            EndIf
        EndIf
        i += 1
    EndWhile
EndEvent

Event OnHomeFallbackReassert(string eventName, string strArg, float numArg, Form sender)
    {HomeSandboxVerifier found a dismissed homed NPC on no package or a dynamic (FF) one: nothing of SA's is running. A
     track-only NPC's assist override dropped, an anchor link was lost (re-made), or the alias itself was lost
     (re-seated through the reconcile, which picks the hour's type). A re-evaluate cannot select an override that is
     gone.}
    Actor akActor = sender as Actor
    If !akActor
        Return
    EndIf
    ; Re-recruited since the verifier's scan: leave them alone.
    If IsRegisteredFollower(akActor)
        Return
    EndIf
    If SchedSystemActive()
        If HoldsAnySchedAlias(akActor)
            _ReassertSchedAssistsFor(akActor)
            _EnsureHeldSchedAnchors(akActor)
            akActor.SetAV("WaitingForPlayer", 2)
            SeverActionsNative.EscalatedReEvaluate(akActor, 1500)
            DebugMsg("HomeFallback: re-asserted dropped home override for " + akActor.GetDisplayName())
        Else
            ; Alias itself was lost (not just the override) — re-seat it fresh.
            StorageUtil.SetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, -99)
            ReconcileSchedAliasesFor(akActor)
            SeverActionsNative.EscalatedReEvaluate(akActor, 1500)
            DebugMsg("HomeFallback: re-seated lost home schedule alias for " + akActor.GetDisplayName())
        EndIf
    Else
        ; Legacy (pre-schedule) path — re-apply via the marker slot.
        ApplyHomeSandboxIfHomed(akActor)
        DebugMsg("HomeFallback: re-applied legacy home sandbox for " + akActor.GetDisplayName())
    EndIf
EndEvent

Event OnSchedYield(String eventName, String strArg, Float numArg, Form sender)
    {The DLL saw an NPC the schedule holds enter a hold it yields to (strArg names it): let go now, not at the next
     tick.}
    Actor akActor = sender as Actor
    If !akActor || IsRegisteredFollower(akActor)
        Return
    EndIf
    YieldSchedule(akActor)
EndEvent

; The target of a PrismaUI per-actor ModEvent: the exact sender ref (set from the
; UI's FormID, so same-named followers resolve), else a lookup by name.
Actor Function ResolvePrismaTarget(Form akSender, String asActorName)
    Actor target = akSender as Actor
    If target
        Return target
    EndIf
    Return SeverActionsNative.FindActorByName(asActorName)
EndFunction

Event OnPrismaAssignHome(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI "Assign Home Here". strArg = "actorName|locationName"; the name is
     the fallback when sender is None.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)

    Actor akActor = ResolvePrismaTarget(sender, actorName)
    If !akActor
        Debug.Trace("[SeverActions_FollowerManager] PrismaAssignHome: could not resolve actor '" + actorName + "'")
        Return
    EndIf

    ; The C++ handler stored the label (SetHome) before firing: read it back from
    ; the cosave rather than parse strArg.
    String locName = SeverActionsNative.Native_GetHome(akActor)
    If locName == ""
        Debug.Trace("[SeverActions_FollowerManager] PrismaAssignHome: empty location name")
        Return
    EndIf

    DebugMsg("PrismaUI AssignHome: " + akActor.GetDisplayName() + " -> " + locName)
    AssignHome(akActor, locName)
EndEvent

Event OnPrismaClearHome(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI "Clear Home". strArg = "actorName|".}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)

    Actor akActor = ResolvePrismaTarget(sender, actorName)
    If !akActor
        Debug.Trace("[SeverActions_FollowerManager] PrismaClearHome: could not resolve actor '" + actorName + "'")
        Return
    EndIf

    DebugMsg("PrismaUI ClearHome: " + akActor.GetDisplayName())
    ClearHome(akActor)
EndEvent

Event OnPrismaSetWorkLoc(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI "Set Work Here": mark the work location at the player's position.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = ResolvePrismaTarget(sender, actorName)
    If !akActor
        Debug.Trace("[SeverActions_FollowerManager] PrismaSetWorkLoc: could not resolve actor '" + actorName + "'")
        Return
    EndIf
    ; A plain spatial mark, no retainer popup (that lives in the AssignWork flow).
    SetRoutineLocHere(akActor, "work")
EndEvent

Event OnPrismaClearWorkLoc(string eventName, string strArg, float numArg, Form sender)
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = ResolvePrismaTarget(sender, actorName)
    If !akActor
        Return
    EndIf
    ClearRoutineLoc(akActor, "work")
EndEvent

Event OnPrismaSetPlayLoc(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI "Set Play Here".}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = ResolvePrismaTarget(sender, actorName)
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
    Actor akActor = ResolvePrismaTarget(sender, actorName)
    If !akActor
        Return
    EndIf
    ClearRoutineLoc(akActor, "play")
EndEvent

Event OnPrismaSetCombatStyle(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI combat style dropdown. strArg = "formID|styleName", formID as a signed int.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String formIdStr = StringUtil.Substring(strArg, 0, pipePos)
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
    {PrismaUI essential toggle. strArg = "formID|1" (on) or "formID|0" (off).}
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

    ; Only OFF writes WasEssential (false) and clears the base flag, so an explicit
    ; OFF sticks even on a record-essential NPC, through a later ON too. ON leaves
    ; WasEssential alone: MagelightSettingsHandler has already set the base flag,
    ; so it cannot be re-read here, and a false would make dismiss strip a
    ; record-essential NPC's own flag.
    If valStr == "1"
        ; ON: cosave the intent; essential comes from a quest alias slot (works on
        ; templated NPCs, applies live).
        SeverActionsNativeExt.Native_SetEssentialOff(akActor, false)
        MakeActorEssential(akActor)
        DebugMsg("PrismaUI Essential ON (alias): " + akActor.GetDisplayName())
    Else
        ; OFF: cosave the intent, drop our alias slot and clear any legacy base flag.
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
    {PrismaUI nearby-ref prompt filters changed. The settings handler already fed the
     nearbyExcluded row; refresh the prompt cache. strArg = the comma-separated
     "type:subtype" tags, "" = no user exclusions.}
    SyncNearbyExcludedToStorageUtil()
    ; Inline, not DebugMsg (a followers-module helper): this handler is kernel-owned.
    If SeverActionsNativeExt2.Settings_GetBool("debugMode")
        Debug.Trace("[SeverActions_FollowerManager] PrismaUI Nearby filters set: [" + strArg + "]")
    EndIf
EndEvent

Function SyncNearbyExcludedToStorageUtil()
    {Mirror the nearbyExcluded row into StorageUtil(None, "SeverActions_NearbyExcluded")
     for the nearby-ref prompt (papyrus_util). Init's prompt-mirror service (M-X)
     also writes it on every feed of the row.}
    StorageUtil.SetStringValue(None, "SeverActions_NearbyExcluded", SeverActionsNativeExt2.Settings_GetString("nearbyExcluded"))
EndFunction

Event OnPrismaSetUIScale(string eventName, string strArg, float numArg, Form sender)
    {UI-scale slider changed. The settings handler already fed the uiScale row;
     refresh the StorageUtil mirror. numArg: the new scale.}
    SyncUIScaleToStorageUtil()
    ; Inline, not DebugMsg: see OnPrismaSetNearbyExcluded.
    If SeverActionsNativeExt2.Settings_GetBool("debugMode")
        Debug.Trace("[SeverActions_FollowerManager] PrismaUI UI scale set: " + numArg)
    EndIf
EndEvent

Function SyncUIScaleToStorageUtil()
    {Mirror the uiScale row into StorageUtil(None, "SeverActions_UIScale"); Init's
     prompt-mirror service (M-X) also writes it on every feed of the row.}
    StorageUtil.SetFloatValue(None, "SeverActions_UIScale", SeverActionsNativeExt2.Settings_GetFloat("uiScale"))
EndFunction

; =============================================================================
; FOLLOWER FRAMEWORK ROUTING - forwarders to the fwlib support bundle (P3-05)
; =============================================================================
; The routes live in SeverActions_NFFLib (the only script naming
; nwsFollowerControllerScript) and SeverActions_FollowerFrameworkLib (vanilla
; DialogueFollower, Serana, ReseatExternal). Every NFFLib call sits behind
; Native_IsNFFInstalled() on the same line or the If above (check 6). The
; functions below are forwarders kept for saved frames (F7) and third-party
; callers (check 20). GetNFFController is gone (it named the NFF type, DR2); an
; old frame calling it gets None and takes its !nff exit.

Bool Function HasNFF()
    {Check if Nether's Follower Framework is installed (the native presence test).}
    ; M-I-STUB 3.9.14-beta25 (P3-05): kept for old frames and third-party callers
    Return SeverActionsNativeExt2.Native_IsNFFInstalled()
EndFunction

Bool Function HasSFF()
    {Forwarder; the body lives in SeverActions_FollowerFrameworkLib.}
    ; M-I-STUB 3.9.14-beta25 (P3-05): forwards to SeverActions_FollowerFrameworkLib.HasSFF
    Return SeverActions_FollowerFrameworkLib.HasSFF()
EndFunction

Function InvalidateTrackOnlyCache(Actor akActor)
    {Safe-exit stub: the track-only memo is gone (IsTrackOnlyFollower reads the DLL live).}
    ; M-I-STUB 3.9.14-beta25 (P12-02): the memo is gone; nothing to do
EndFunction

Bool Function NFFWait(Actor akActor)
    {Forwarder; the body lives in SeverActions_NFFLib.}
    ; M-I-STUB 3.9.14-beta25 (P3-05): forwards to SeverActions_NFFLib.NFFWait
    Return SeverActionsNativeExt2.Native_IsNFFInstalled() && SeverActions_NFFLib.NFFWait(akActor)
EndFunction

Bool Function NFFResume(Actor akActor)
    {Forwarder; the body lives in SeverActions_NFFLib.}
    ; M-I-STUB 3.9.14-beta25 (P3-05): forwards to SeverActions_NFFLib.NFFResume
    Return SeverActionsNativeExt2.Native_IsNFFInstalled() && SeverActions_NFFLib.NFFResume(akActor)
EndFunction

Faction Function NFFSparFaction()
    {Forwarder; the body lives in SeverActions_NFFLib.}
    ; M-I-STUB 3.9.14-beta25 (P3-05): forwards to SeverActions_NFFLib.NFFSparFaction
    Faction sparFac
    If SeverActionsNativeExt2.Native_IsNFFInstalled()
        sparFac = SeverActions_NFFLib.NFFSparFaction()
    EndIf
    Return sparFac
EndFunction

Bool Function NFFDismiss(Actor akActor, Bool abSilent = false)
    {Forwarder; the body lives in SeverActions_NFFLib.}
    ; M-I-STUB 3.9.14-beta25 (P3-05): forwards to SeverActions_NFFLib.NFFDismiss
    Return SeverActionsNativeExt2.Native_IsNFFInstalled() && SeverActions_NFFLib.NFFDismiss(akActor, abSilent)
EndFunction

Bool Function NFFRecruit(Actor akActor)
    {Forwarder; the body lives in SeverActions_NFFLib.}
    ; M-I-STUB 3.9.14-beta25 (P3-05): forwards to SeverActions_NFFLib.NFFRecruit
    Return SeverActionsNativeExt2.Native_IsNFFInstalled() && SeverActions_NFFLib.NFFRecruit(akActor)
EndFunction

Bool Function IsSerana(Actor akActor)
    {Forwarder; the body lives in SeverActions_FollowerFrameworkLib.}
    ; M-I-STUB 3.9.14-beta25 (P3-05): forwards to SeverActions_FollowerFrameworkLib.IsSerana
    Return SeverActions_FollowerFrameworkLib.IsSerana(akActor)
EndFunction

Bool Function RecruitViaVanillaDialogue(Actor akActor)
    {Forwarder; the body lives in SeverActions_FollowerFrameworkLib.}
    ; M-I-STUB 3.9.14-beta25 (P3-05): forwards to SeverActions_FollowerFrameworkLib.RecruitViaVanillaDialogue
    Return SeverActions_FollowerFrameworkLib.RecruitViaVanillaDialogue(akActor)
EndFunction

Bool Function DismissViaVanillaDialogue(Actor akActor)
    {Forwarder; the body lives in SeverActions_FollowerFrameworkLib.}
    ; M-I-STUB 3.9.14-beta25 (P3-05): forwards to SeverActions_FollowerFrameworkLib.DismissViaVanillaDialogue
    Return SeverActions_FollowerFrameworkLib.DismissViaVanillaDialogue(akActor)
EndFunction

Bool Function RecruitSerana(Actor akActor)
    {Forwarder; the body lives in SeverActions_FollowerFrameworkLib.}
    ; M-I-STUB 3.9.14-beta25 (P3-05): forwards to SeverActions_FollowerFrameworkLib.RecruitSerana
    Return SeverActions_FollowerFrameworkLib.RecruitSerana(akActor)
EndFunction

Bool Function DismissSerana(Actor akActor)
    {Forwarder; the body lives in SeverActions_FollowerFrameworkLib.}
    ; M-I-STUB 3.9.14-beta25 (P3-05): forwards to SeverActions_FollowerFrameworkLib.DismissSerana
    Return SeverActions_FollowerFrameworkLib.DismissSerana(akActor)
EndFunction

Function ReconcileTrackOnlyOwnership()
    {Load-time self-heal (RunDeferredMaintenance): a follower hands-off NOW (owned
     elsewhere, or anyone in Tracking mode, D45) who still carries SA's follow flag
     or a pool seat has the claim released: flags, seat, wait sandbox and the
     actively-following faction (ApplyHomeSandbox refuses an actor wearing it).
     Also records a keyless follower's SeverActions_HandsOffAtRecruit from that
     claim before releasing it. Acts only on the mismatch, so no sentinel.}
    Actor[] roster = GetAllFollowers()
    If !roster
        Return
    EndIf
    SeverActions_Follow followSys = GetFollowScript()
    Int i = 0
    Int healed = 0
    While i < roster.Length
        Actor a = roster[i]
        Bool aliasHeld = false
        If a
            SeverActions_Follow fsProbe = GetFollowScript()
            If fsProbe
                aliasHeld = fsProbe.IsInFollowerSlot(a)
            EndIf
        EndIf
        ; A follower onboarded before the record existed: SA led them if it holds
        ; their follow flag or seat and no framework owns them (see WasSALedRecruit).
        If a && !StorageUtil.HasIntValue(a, "SeverActions_HandsOffAtRecruit")
            Bool followPkg = SeverActionsNative.Native_GetHasFollowPkg(a)
            Bool saLed = !SeverActionsNativeExt2.Native_IsTrackOnlyFollower(a) && (followPkg || aliasHeld)
            StorageUtil.SetIntValue(a, "SeverActions_HandsOffAtRecruit", (!saLed) as Int)
        EndIf
        ; The mismatch is SA's flag or seat, never a leftover follow LinkedRef: the
        ; release's StopSandbox zeroes WaitingForPlayer, ending a wait the owning
        ; framework set. Follow.ReapplyFollowTracking clears the LinkedRef.
        If a && IsFollowHandsOff(a) && (SeverActionsNative.Native_GetHasFollowPkg(a) || aliasHeld)
            ; Release the claim FIRST: StopSandbox reads hasFollowPkg and, for an
            ; actor with no follower slot, re-registers SkyrimNet's FollowPlayer
            ; package. (Removing only SA's own override is safe on a track-only actor.)
            SeverActionsNativeExt2.Native_ClearSAFollowOwnership(a)
            If followSys
                ; The seat too: a pool alias's follow package re-applies natively on
                ; cell load. ClearFollowerSlot evicts pool + legacy slot + overflow.
                followSys.ClearFollowerSlot(a)
                followSys.StopSandbox(a)
                followSys.SetActivelyFollowing(a, false)
            EndIf
            If SeverActionsNativeExt2.Native_IsTrackOnlyFollower(a)
                Debug.Trace("[SeverActions_FollowerManager] ReconcileTrackOnlyOwnership: " + a.GetDisplayName() + " is owned by " + SeverActionsNativeExt2.Native_GetFollowerOwnerName(a) + " - released SA's claim")
            Else
                Debug.Trace("[SeverActions_FollowerManager] ReconcileTrackOnlyOwnership: Tracking mode - released SA's lead on " + a.GetDisplayName() + " (D45)")
            EndIf
            healed += 1
        EndIf
        i += 1
    EndWhile
    If healed > 0
        Debug.Trace("[SeverActions_FollowerManager] ReconcileTrackOnlyOwnership: released SA follow ownership on " + healed + " hands-off follower(s)")
    EndIf
EndFunction

Function AdoptUnrosteredNFFFollowers()
    {Load-time adopt: onboard any enlisted, unrostered occupant of NFF's
     DialogueFollower alias pool (quest 0x0750BA), e.g. one recruited off-cell or
     saved mid-recruit. Alias refs are persistent, so this reaches off-cell
     followers the cell-scoped DetectExistingFollowers cannot. No-op without NFF.}
    If !SeverActionsNativeExt2.Native_IsNFFInstalled()
        Return
    EndIf
    Quest dfQuest = Game.GetFormFromFile(0x000750BA, "Skyrim.esm") as Quest
    If !dfQuest
        Return
    EndIf
    Int adopted = 0
    Int i = 0
    ; Bounded scan of the alias pool: vanilla has 2 aliases, NFF adds
    ; FollowerExtra1-10; GetNthAlias past the end returns None.
    While i < 32
        ReferenceAlias al = dfQuest.GetNthAlias(i) as ReferenceAlias
        If al
            Actor a = al.GetReference() as Actor
            ; The seat is the signal; Native_IsNFFManaged confirms it is a RUNNING
            ; alias (GetNthAlias also returns a stopped quest's). The collector /
            ; captive refusals live in OnboardExternalTeammate.
            If a && !a.IsDead() && !IsRegisteredFollower(a) && SeverActionsNativeExt2.Native_IsNFFManaged(a)
                ; A bulk adopt must respect the MaxFollowers cap.
                If CanRecruitMore()
                    Debug.Trace("[SeverActions_FollowerManager] AdoptUnrosteredNFFFollowers: adopting NFF-seated " + a.GetDisplayName())
                    OnboardExternalTeammate(a, true)   ; skip the per-actor opinion rebuild
                    adopted += 1
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile
    If adopted > 0
        ; One opinion rebuild for the whole batch.
        SeverActionsNativeExt2.Native_HydrateFollowerSystem_RebuildOpinions()
        Debug.Trace("[SeverActions_FollowerManager] AdoptUnrosteredNFFFollowers: adopted " + adopted + " unrostered NFF follower(s)")
    EndIf
EndFunction

Bool Function IsTrackOnlyFollower(Actor akActor)
    {True when someone else owns this actor's follow system (custom-AI keyword, NFF
     ignore token or seat, DLC such as Serana), so SA must not put its packages on
     them. Forwards to SeverActionsNativeExt2.Native_IsTrackOnlyFollower, which every
     reader calls directly; kept for old frames and third-party callers.}
    ; M-I-STUB 3.9.14-beta25 (P12-02): forwards to SeverActionsNativeExt2.Native_IsTrackOnlyFollower
    If !akActor
        Return false
    EndIf
    Return SeverActionsNativeExt2.Native_IsTrackOnlyFollower(akActor)
EndFunction

Bool Function IsFollowHandsOff(Actor akActor)
    {The follow gate (D45): SA leads nobody it does not own, and nobody at all in
     Tracking mode (frameworkMode 1). Not used by CheckTrackOnlyFollowerStatus (its
     signals only mean "dismissed" for a framework-led actor) or by home and
     schedule sites, which stay live in Tracking mode and ask
     Native_IsTrackOnlyFollower alone. Other scripts: SeverActions_ModuleBase.IsFollowHandsOff.
     Exception: _CompanionWaitCore parks an NPC no framework leads in SA's wait sandbox in Tracking mode too
     (_UnledInTracking).}
    If !akActor
        Return false
    EndIf
    If SeverActionsNativeExt2.Settings_GetInt("frameworkMode") == 1
        Return true
    EndIf
    Return SeverActionsNativeExt2.Native_IsTrackOnlyFollower(akActor)
EndFunction

Bool Function _UnledInTracking(Actor akActor)
    {Tracking mode (D45) and no framework leads akActor: not rostered, not a player teammate, not track-only. Her wait
     parks her in SA's wait sandbox, since WaitingForPlayer alone only empties her schedule holds and her own AI walks
     her off.}
    Return akActor && SeverActionsNativeExt2.Settings_GetInt("frameworkMode") == 1 \
        && !IsRegisteredFollower(akActor) && !akActor.IsPlayerTeammate() \
        && !SeverActionsNativeExt2.Native_IsTrackOnlyFollower(akActor)
EndFunction

Function _ReleaseSAWait(Actor akActor)
    {Ends SA's own manual wait on an NPC a framework now leads: its override would outrank the framework's follow.
     Only SA's: without the sandbox flag, a WaitingForPlayer 1 is the framework's.}
    SeverActions_Follow followSys = GetFollowScript()
    If !akActor || !followSys || !followSys.IsSandboxing(akActor)
        Return
    EndIf
    If akActor.GetAV("WaitingForPlayer") == 1.0
        akActor.SetAV("WaitingForPlayer", 0)
    EndIf
    followSys.RemoveWaitSandboxPackages(akActor)
    followSys.SetSandboxFlag(akActor, false)
    followSys.ClearWaitingFaction(akActor)
    SeverActionsNative.UnregisterSandboxUser(akActor)
EndFunction

Bool Function WasHandsOffAtRecruit(Actor akActor)
    {Dismiss-time test: hands-off now, or at onboarding (SeverActions_HandsOffAtRecruit,
     set at onboarding, cleared at dismiss). The live verdict alone misses an
     NFF-dialogue dismiss: NFF empties its seat first, so the native then says SA's
     and SA's own teardown would run on an NPC NFF just released.}
    If !akActor
        Return false
    EndIf
    Return IsFollowHandsOff(akActor) || StorageUtil.GetIntValue(akActor, "SeverActions_HandsOffAtRecruit", 0) == 1
EndFunction

Bool Function WasSALedRecruit(Actor akActor)
    {True when SA's SeverActions-mode onboarding set this follower's flags (the recorded 0;
     with no record yet, before the load-time backfill in ReconcileTrackOnlyOwnership, the AI
     snapshot only that onboarding takes) and no framework owns them now: their dismiss
     undoes SA's flags in every mode.}
    If !akActor || SeverActionsNativeExt2.Native_IsTrackOnlyFollower(akActor)
        Return false
    EndIf
    Int recorded = StorageUtil.GetIntValue(akActor, "SeverActions_HandsOffAtRecruit", -1)
    If recorded == -1
        Return StorageUtil.HasFloatValue(akActor, KEY_ORIG_AGGRESSION)
    EndIf
    Return recorded == 0
EndFunction

Bool Function ComputeIsTrackOnly(Actor akActor)
    {The kernel's track-only verdict (Native_IsTrackOnlyFollower). No caller here;
     kept for old frames and third-party callers.}
    ; One verdict for every script: Native_GetFollowerOwner weighs every signal with a
    ; fixed precedence (NFF seat, DLC1SeranaFaction, SPID keyword / NFF ignore token /
    ; curated list, our store flags, CurrentFollowerFaction): 0 None | 1 SeverActions |
    ; 2 NFF | 3 DLC | 4 CustomAI | 5 Vanilla. Track-only = owner NFF, DLC or CustomAI.
    Return SeverActionsNativeExt2.Native_IsTrackOnlyFollower(akActor)
EndFunction

Function SetCustomAIOverride(Actor akActor, Bool abForceNormal)
    {Escape hatch for the custom-AI classifier: force this NPC to classify as a
     normal follower whatever the curated list says. The native set is cosaved
     ('CAIO'); the StorageUtil form list is mirrored as the seed source for a save
     without the record (Init K1 SeedCustomAIOverrides) and for
     ReconcileCustomAIOverrides. Takes effect at once.}
    If !akActor
        Return
    EndIf
    If abForceNormal
        StorageUtil.FormListAdd(None, "SeverActions_CustomAIOverrideList", akActor, false)
    Else
        StorageUtil.FormListRemove(None, "SeverActions_CustomAIOverrideList", akActor, true)
    EndIf
    SeverActionsNativeExt2.Native_SetCustomAIOverride(akActor, abForceNormal)
    If abForceNormal
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.willBeTreatedAsNormal", ("" + akActor.GetDisplayName())))
    Else
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.followsTheirOwnAi", ("" + akActor.GetDisplayName())))
    EndIf
EndFunction

Bool Function HasCustomAIKeyword(Actor akActor)
    {True if the actor has SeverActions_CustomAIFollower (0x13C78B), SPID-distributed
     to modded followers with their own AI (Inigo, Lucien, ...): SA tracks them but
     leaves their packages alone. Independent of NFF.}
    Keyword customAIKW = Game.GetFormFromFile(0x13C78B, "SeverActions.esp") as Keyword
    If !customAIKW
        Return false
    EndIf
    Return akActor.HasKeyword(customAIKW)
EndFunction

; =============================================================================
; UPDATE LOOP (the 30 s chronometer tick)
; =============================================================================

Function ChronoArm(Float afSeconds)
    {Arm this script's one-shot chronometer tick (never the form-keyed
     RegisterForSingleUpdate; see the Chronometer block in SeverActionsNativeExt2.psc).
     Event and callback names are unique per script. Re-arm replaces the pending
     tick; ticks do not survive save/load; one in-flight tick can land after a
     cancel, so the handler stays state-guarded.}
    RegisterForModEvent("SeverActions_Tick_FollowerManager", "OnChronoTick_FollowerManager")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_FollowerManager", afSeconds)
EndFunction

Event OnChronoTick_FollowerManager(String eventName, String strArg, Float numArg, Form sender)
    ; Re-arm FIRST so a stack dying below cannot end the loop (later ChronoArm
    ; calls replace it). It is also the liveness ack Init's watchdog counts.
    ChronoArm(30.0)

    ; One pass at a time: with a huge roster a pass can outlive its tick, and
    ; stacked passes compound the load. The 120 s ceiling keeps a pass whose
    ; stack died from wedging the loop shut.
    If _OnUpdateInFlight && (Utility.GetCurrentRealTime() - _OnUpdateStartRT) < 120.0
        Return
    EndIf
    _OnUpdateInFlight = true
    _OnUpdateStartRT = Utility.GetCurrentRealTime()
    ; Its own function, so every early Return in it lands back here to release the guard.
    _OnUpdatePass()
    _OnUpdateInFlight = false
EndEvent

Function _OnUpdatePass()
    ; Maintenance() arms a short tick to run the heavy load passes off Init's
    ; critical path; that fire runs only them.
    If DeferredMaintenancePending
        DeferredMaintenancePending = false
        RunDeferredMaintenance()
        ; It may have armed the 0.5 s schedule-migration drain: keep that timer.
        If !SchedMigrationPending
            ChronoArm(30.0)
        EndIf
        Return
    EndIf

    ; Schedule-alias migration (BeginSchedAliasMigration): a small batch per 0.5 s
    ; fire until the pending list is empty.
    If SchedMigrationPending
        ProcessSchedMigrationBatch()
        Return
    EndIf

    ; Teammate-resume poll: owns the tick (1 s) only while still waiting.
    If ResumePendingActor
        PollTeammateResume()
        If ResumePendingActor
            ChronoArm(1.0)
            Return
        EndIf
    EndIf

    ; Dismiss confirmation: drain the whole queue, checking each removal is still real.
    If PendingDismissCount > 0
        Int dq = 0
        While dq < PendingDismissCount
            Actor checkActor = PendingDismissQueue[dq]
            PendingDismissQueue[dq] = None
            Bool forgiven = False
            If PendingDismissForgiven
                forgiven = PendingDismissForgiven[dq]
                PendingDismissForgiven[dq] = False
            EndIf
            If checkActor && IsRegisteredFollower(checkActor)
                Bool confirmed = false
                String travelState = SeverActionsNativeExt2.Native_GetTravelState(checkActor)
                If travelState == "traveling" || travelState == "waiting"
                    ; SA travel suspends the teammate flag for the trip; not a dismissal
                    ; (ReinstateFollower restores it on return, and a real mid-trip
                    ; dismiss goes through DismissCompanion, never this queue).
                    DebugMsg("Dismiss skipped (SA travel in progress): " + checkActor.GetDisplayName())
                ElseIf !checkActor.IsPlayerTeammate()
                    ; Usually a plain dismiss, but a custom follower's framework can keep
                    ; them following without the teammate flag: for a hands-off follower,
                    ; live follow evidence (vanilla follow faction or PlayerFollowerPackage)
                    ; vetoes the untrack.
                    Bool stillFollowing = IsFollowHandsOff(checkActor) && IsStillFollowingByEvidence(checkActor)
                    If stillFollowing
                        DebugMsg("Hands-off follower still following (faction/package evidence) - keeping tracked: " + checkActor.GetDisplayName())
                    Else
                        confirmed = true
                    EndIf
                ElseIf IsFollowHandsOff(checkActor)
                    ; Custom followers can keep the teammate flag after their mod's
                    ; dismiss; WaitingForPlayer == -1 is their dismiss signal.
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

                If confirmed && forgiven && _KeepAfterFriendlyFire(checkActor)
                    DebugMsg("Friendly-fire dismissal undone: " + checkActor.GetDisplayName())
                ElseIf confirmed
                    DebugMsg("Vanilla dismiss confirmed: " + checkActor.GetDisplayName())
                    UnregisterFollower(checkActor)
                Else
                    DebugMsg("Dismiss cancelled (teammate restored): " + checkActor.GetDisplayName())
                EndIf
            EndIf
            dq += 1
        EndWhile
        PendingDismissCount = 0
        ; The regular body waits for the next 30 s tick.
        ChronoArm(30.0)
        Return
    EndIf

    If IsUpdating
        ; A tick whose stack died with the flag set would starve the body forever:
        ; trust the flag for 45 s real time only.
        If (Utility.GetCurrentRealTime() - IsUpdatingSetRT) > 45.0
            Debug.Trace("[SeverActions_FollowerManager] OnUpdate: IsUpdating STUCK - previous tick died mid-body, clearing")
            IsUpdating = false
        Else
            ChronoArm(30.0)
            Return
        EndIf
    EndIf

    IsUpdating = true
    IsUpdatingSetRT = Utility.GetCurrentRealTime()

    Float currentTime = GetGameTimeInSeconds()
    Float secondsPassed = currentTime - LastTickTime
    Float hoursPassed = secondsPassed / SECONDS_PER_GAME_HOUR

    If hoursPassed >= 0.5
        TickRelationships(hoursPassed)
        ; (Debt and commission ticks run on SeverActions_Debt / _Crafting's own chains.)
        LastTickTime = currentTime
    EndIf

    If DeathGracePeriodHours > 0.0
        CheckDeadFollowers()
    EndIf

    ; Backstop for TeammateMonitor: untrack track-only followers who lost teammate
    ; status while the event was missed (loaded actors only).
    CheckTrackOnlyFollowerStatus()
    Float tPrologue = Utility.GetCurrentRealTime()

    ; The schedule-era gate, read once per tick (it is not free).
    Bool tickSchedActive = SchedSystemActive()

    ; The validated homed roster (GetAllHomedNPCs prunes rows whose home was
    ; cleared), built once, after the sweeps above, for ProcessHomeSleep,
    ; ProcessHomeMarkerHops and CheckSceneSuspendedHomes' Route B tail. The schedule
    ; passes keep their raw KEY_HOMED_NPCS walk: their slow lane must prune rows
    ; this filtered copy has already dropped.
    Actor[] tickHomed = GetAllHomedNPCs()
    ; One sleep-window test, shared by the bed conductor and room rotation.
    Bool tickSleepOpen = SeverActionsNativeExt2.Settings_GetBool("homeSleepEnabled") && HourInWindow(GetCurrentGameHour(), SeverActionsNativeExt2.Settings_GetFloat("homeSleepStart"), SeverActionsNativeExt2.Settings_GetFloat("homeSleepEnd"))
    Float tHomedRoster = Utility.GetCurrentRealTime()

    ; Schedule passes (homed and work-only): pre-migration, move HomeMarker to the
    ; hour's anchor (home/work/play); post-migration, reconcile the schedule alias
    ; pools. A large alias-era roster gets the native due set plus a chunked slow lane.
    ProcessSchedulePasses(tickSchedActive)
    Float tSchedPasses = Utility.GetCurrentRealTime()
    ; Homed NPCs find their claimed bed during the sleep window.
    ProcessHomeSleep(tickHomed, tickSleepOpen)
    Float tHomeSleep = Utility.GetCurrentRealTime()
    ; Room rotation: homed NPCs hop their sandbox anchor between the home's named
    ; markers. After ProcessHomeSleep on purpose: it owns the bed window.
    If SeverActionsNativeExt2.Settings_GetBool("roomRotationEnabled")
        ProcessHomeMarkerHops(tickHomed, tickSleepOpen)
    EndIf
    Float tRoomHops = Utility.GetCurrentRealTime()

    ; The active roster, built once for every read-only consumer below, and after
    ; the sweeps that can unregister followers so no pass acts on a removed entry.
    Actor[] tickFollowers = GetAllFollowers()
    Float tFollowerRoster = Utility.GetCurrentRealTime()

    ; Release the home alias while a follower is in a vanilla scene so the scene's
    ; package drives; restore it after (see CheckSceneSuspendedHomes).
    CheckSceneSuspendedHomes(tickFollowers, tickHomed, tickSchedActive)
    Float tSceneSuspend = Utility.GetCurrentRealTime()

    ; IgnoreFriendlyHits drops in AI state transitions: re-stamp it every tick.
    RefreshFriendlyFireFlags(tickFollowers)
    Float tFFFlags = Utility.GetCurrentRealTime()

    ; (Assessment, off-screen life and banter run on SeverActions_CompanionMind's and
    ; _CompanionLife's own ticks; ambient banter and actions on SeverActions_Ambient's.)
    Float tEnd = Utility.GetCurrentRealTime()

    TraceTickTimings(tickFollowers.Length, tickHomed.Length, \
        tPrologue, tHomedRoster, tSchedPasses, tHomeSleep, \
        tRoomHops, tFollowerRoster, tSceneSuspend, tFFFlags, tEnd)

    IsUpdating = false
    ChronoArm(30.0)
EndFunction

Float Property TICK_TRACE_BUDGET_SEC = 0.25 AutoReadOnly
{A tick slower than this logs one breakdown line even without debugMode, so any
 player's log shows which pass ate the time and how big the roster was.}

Function TraceTickTimings(Int followerCount, Int homedCount, \
    Float tPrologue, Float tHomedRoster, Float tSchedPasses, \
    Float tHomeSleep, Float tRoomHops, Float tFollowerRoster, Float tSceneSuspend, \
    Float tFFFlags, Float tEnd)
    {Log one tick's per-pass real-time breakdown when it exceeds
     TICK_TRACE_BUDGET_SEC, or always under debugMode. The stamps are absolute
     GetCurrentRealTime readings in _OnUpdatePass order; the span starts after the
     relationship, death and track-only sweeps, measuring the roster-scaling passes.}
    Float total = tEnd - tPrologue
    If total < TICK_TRACE_BUDGET_SEC && !SeverActionsNativeExt2.Settings_GetBool("debugMode")
        Return
    EndIf
    ; llmScans spans no pass now: the LLM scans run on the companions and social
    ; modules' own ticks.
    Debug.Trace("[SeverActions_FollowerManager] tick " + total + "s" \
        + " (followers=" + followerCount + " homed=" + homedCount + ")" \
        + " homedRoster=" + (tHomedRoster - tPrologue) \
        + " schedPasses=" + (tSchedPasses - tHomedRoster) \
        + " homeSleep=" + (tHomeSleep - tSchedPasses) \
        + " roomHops=" + (tRoomHops - tHomeSleep) \
        + " followerRoster=" + (tFollowerRoster - tRoomHops) \
        + " sceneSuspend=" + (tSceneSuspend - tFollowerRoster) \
        + " ffFlags=" + (tFFFlags - tSceneSuspend) \
        + " llmScans=" + (tEnd - tFFFlags))
EndFunction

Function RefreshFriendlyFireFlags(Actor[] followers)
    {Re-stamp IgnoreFriendlyHits(true) on the followers while "Prevent Follower
     Friendly Fire" is on: the flag drops silently during AI state transitions.
     The tick passes its roster in.}
    Quest SeverActionsQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
    If !SeverActionsQuest
        Return
    EndIf
    ; Read from the Settings Authority; its default must stay ON to agree with
    ; SeverActions_Follow's load-time restore of the same key.
    If !SeverActionsNativeExt2.Settings_GetBool("preventFollowerFF")
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
    {Relationship math runs in C++; Papyrus only fires the autonomous-leaving
     event for followers newly at or below the threshold (deduped by the native
     leaveWarned flag).}

    ; Passive drift is off by design: both deltas are 0, so the native ticker's
    ; mood-drift and neglect blocks no-op. The call stays for the leaving pass.
    Float moodChange           = 0.0
    Float rapportLossOnNeglect = 0.0
    Float currentTimeSec          = GetGameTimeInSeconds()
    Float neglectSecondsThreshold = NEGLECT_HOURS * SECONDS_PER_GAME_HOUR

    Actor[] belowThreshold = SeverActionsNativeExt.Native_TickAllRelationships( \
        moodChange, rapportLossOnNeglect, currentTimeSec, \
        neglectSecondsThreshold, LeavingThreshold, AllowAutonomousLeaving)

    ; Warn each follower at or below the threshold once per episode; the sweep
    ; below re-arms one whose rapport recovered.
    If AllowAutonomousLeaving && belowThreshold
        Actor player = Game.GetPlayer()
        Int i = 0
        While i < belowThreshold.Length
            Actor akFollower = belowThreshold[i]
            If akFollower && !SeverActionsNativeExt.Native_GetLeaveWarned(akFollower)
                SeverActionsNativeExt.Native_SetLeaveWarned(akFollower, true)
                SkyrimNetApi.RegisterPersistentEvent( \
                    akFollower.GetDisplayName() + " is deeply unhappy and considering leaving " + player.GetDisplayName() + "'s service.", \
                    akFollower, player)
            EndIf
            i += 1
        EndWhile

        ; Clear the warning on followers whose rapport has recovered.
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

    If SeverActionsNativeExt2.Settings_GetBool("debugMode")
        Debug.Trace("[SeverActions_FollowerManager] Tick: native processed " \
            + "(hoursPassed=" + hoursPassed + ", below-threshold=" + belowThreshold.Length + ")")
    EndIf
EndFunction

Function TickFollowerRelationship(Actor akFollower, Float hoursPassed)
    {Compatibility wrapper for external callers; the whole roster ticks natively
     (see TickRelationships).}
    If !akFollower || hoursPassed <= 0.0
        Return
    EndIf
    ; Deltas are 0: no passive drift (see TickRelationships).
    Float moodChange = 0.0
    Float rapportLossOnNeglect = 0.0
    SeverActionsNativeExt.Native_TickAllRelationships( \
        moodChange, rapportLossOnNeglect, GetGameTimeInSeconds(), \
        NEGLECT_HOURS * SECONDS_PER_GAME_HOUR, LeavingThreshold, false)
EndFunction

; =============================================================================
; OUTFIT SLOTS - moved to SeverActions_Outfit (P10-02)
; =============================================================================
; The outfit alias pool is the outfit module's. What remains are safe-exit stubs
; for an older save's resumed frames (F7); Assign/ClearOutfitSlot forward
; through the outfit provider.

Bool[] _outfitAliasIsNative   ; unused; kept declared so an older save's value loads without a skip warning

Function EnsureOutfitAliasOwnership(Bool abRebuild = false)
    {Safe-exit stub: the alias pool moved to SeverActions_Outfit (P10-02).}
    ; M-I-STUB 3.9.14-beta25 (P10-02): moved to SeverActions_Outfit
EndFunction

Bool Function IsOwnNativeOutfitAlias(Actor akActor, ReferenceAlias akAlias)
    {Safe-exit stub: the alias pool moved to SeverActions_Outfit (P10-02).}
    ; M-I-STUB 3.9.14-beta25 (P10-02): moved to SeverActions_Outfit
    Return false
EndFunction

Bool Function IsBoundToOwnNativeOutfitAlias(Actor akActor)
    {Safe-exit stub: the alias pool moved to SeverActions_Outfit (P10-02).}
    ; M-I-STUB 3.9.14-beta25 (P10-02): moved to SeverActions_Outfit
    Return false
EndFunction

Function AssignOutfitSlot(Actor akActor)
    {Safe-exit stub: the alias pool moved to SeverActions_Outfit (P10-02).
     Forwards through the outfit provider (a no-op without the module).}
    ; M-I-STUB 3.9.14-beta25 (P10-02): moved to SeverActions_Outfit; forwards through the outfit provider
    SeverActions_ModuleBase.CallBool("outfit", "assignOutfitSlot", akActor)
EndFunction

Function ReapplyLockedOutfitIfLoaded(Actor akActor)
    {Safe-exit stub: the alias pool moved to SeverActions_Outfit (P10-02).}
    ; M-I-STUB 3.9.14-beta25 (P10-02): moved to SeverActions_Outfit
EndFunction

Function ClearOutfitSlot(Actor akActor)
    {Safe-exit stub: the alias pool moved to SeverActions_Outfit (P10-02).
     Forwards through the outfit provider (a no-op without the module).}
    ; M-I-STUB 3.9.14-beta25 (P10-02): moved to SeverActions_Outfit; forwards through the outfit provider
    SeverActions_ModuleBase.CallBool("outfit", "clearOutfitSlot", akActor)
EndFunction

Function ReassignOutfitSlots(Actor[] followers)
    {Safe-exit stub: the load re-seat is the outfit provider's stage 2 (P10-02).}
    ; M-I-STUB 3.9.14-beta25 (P10-02): moved to SeverActions_Outfit (run by the outfit provider's stage 2)
EndFunction

; =============================================================================
; ESSENTIAL SLOTS - ReferenceAlias-based essential status
; =============================================================================
; The ActorBase essential flag is ignored for templated/leveled NPCs and applies
; unreliably to loaded actors; an alias flagged Essential works on any actor the
; moment it is filled. Pool: alias IDs 218-257.

Function EnsureEssentialSlots()
    {Lazily bind the Essential alias pool by ID with GetAlias() (array property
     fills are fragile).}
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
    {Seat the actor in a free Essential alias slot. Idempotent; no-op if the
     pool is full.}
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
    {Empty the actor's Essential alias slot. A base-record essential flag stays.}
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
    {Rebuild the Essential alias pool from the roster and EssentialOff intent on
     load: alias fills are not guaranteed across save/load, and the hydrator only
     restores the base flag (useless on templated NPCs).}
    EnsureEssentialSlots()
    If !EssentialSlots
        Debug.Trace("[SeverActions_FollowerManager] ReassignEssentialSlots: slots array is NONE after Ensure - bailing")
        Return
    EndIf
    ; Drop stale fills first.
    Int i = 0
    While i < EssentialSlots.Length
        If EssentialSlots[i]
            EssentialSlots[i].Clear()
        EndIf
        i += 1
    EndWhile
    If !followers  ; not '== None' - the None-compare logs a cosmetic cast error
        Return
    EndIf
    ; Re-fill for followers whose intent is essential-on. For OFF, clear only a
    ; base flag SA set: essential is opt-in (EssentialOff defaults true), so a
    ; vanilla-essential follower reads "off" by default and must keep their own
    ; flag. WasEssential is captured from the record at recruit; the Companions
    ; page OFF path sets it false so an explicit OFF sticks.
    i = 0
    While i < followers.Length
        Actor a = followers[i]
        If a && !a.IsDead()
            If !SeverActionsNativeExt.Native_GetEssentialOff(a)
                MakeActorEssential(a)
            ElseIf SeverActionsNative.Native_IsEssential(a) && !SeverActionsNativeExt.Native_GetWasEssential(a)
                SeverActionsNative.Native_ClearEssential(a) ; clear legacy base-flag SA set
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
    {Force-remove followers dead longer than DeathGracePeriodHours. Called from
     the tick when the grace period is > 0; the dead set comes from the native
     follower store.}
    Actor[] dead = SeverActionsNativeExt.Native_GetDeadTrackedFollowers()
    If !dead || dead.Length == 0
        Return
    EndIf
    Float currentTime = GetGameTimeInSeconds()

    Int i = 0
    While i < dead.Length
        Actor slotActor = dead[i]
        ; Native already filtered to tracked + dead.
        If slotActor
            Float deathTime = SeverActionsNativeExt.Native_GetDeathTime(slotActor)
            If deathTime == 0.0
                ; First detection — record death time
                SeverActionsNativeExt.Native_SetDeathTime(slotActor, currentTime)
                DebugMsg("Death detected: " + slotActor.GetDisplayName() + " - grace period started (" + DeathGracePeriodHours + " hours)")
                If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
                    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.hasFallen", ("" + slotActor.GetDisplayName())))
                EndIf
            Else
                Float hoursSinceDeath = (currentTime - deathTime) / SECONDS_PER_GAME_HOUR
                If hoursSinceDeath >= DeathGracePeriodHours
                    String deadName = slotActor.GetDisplayName()
                    DebugMsg("Death cleanup: removing " + deadName + " after " + hoursSinceDeath + " hours")
                    ; The full force removal, so the outfit row goes too.
                    ForceRemoveFollower(slotActor)
                    If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
                        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.hasBeenRemovedDeceased", ("" + deadName)))
                    EndIf
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile
EndFunction

Bool Function IsStillFollowingByEvidence(Actor akActor)
    {Live evidence the actor still follows the player, independent of the
     teammate flag (a custom follower's framework may never set it): in
     CurrentFollowerFaction or PlayerFollowerFaction (rank >= 0), or running the
     vanilla PlayerFollowerPackage. A custom-AI follower counts as following
     unless Native_IsCustomFollowerDismissed. Vetoes the track-only auto-untrack
     in both the tick sweep and the dismiss queue.}
    If !akActor
        Return false
    EndIf
    Faction cffEv = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
    If cffEv && akActor.GetFactionRank(cffEv) >= 0
        Return true
    EndIf
    ; PlayerFollowerFaction: some custom followers sit here without
    ; CurrentFollowerFaction. Accept either.
    Faction pffEv = Game.GetFormFromFile(0x00084D1B, "Skyrim.esm") as Faction
    If pffEv && akActor.GetFactionRank(pffEv) >= 0
        Return true
    EndIf
    Package pfpEv = Game.GetFormFromFile(0x0005C84B, "Skyrim.esm") as Package
    If pfpEv && akActor.GetCurrentPackage() == pfpEv
        Return true
    EndIf
    ; A custom-AI follower (Sofia/Inigo) runs its own follow package and its
    ; framework flips the follower faction during its behaviors, so the checks
    ; above miss it. It is still following unless the framework shows a real
    ; dismiss marker: Native_IsCustomFollowerDismissed (vanilla
    ; DismissedFollowerFaction, WFP == -1, or any *dismiss*-named faction), the
    ; same discriminator TeammateMonitor's custom-AI hold uses. NFF/DLC stay on
    ; the evidence above: they do not flip the faction, so a drop is a dismiss. The user
    ; override (Take Full Control) counts too: their framework still flips (CustomAIList::IsCustomAI).
    If HasCustomAIKeyword(akActor) || SeverActionsNativeExt.Native_IsListedCustomAI(akActor) \
        || SeverActionsNativeExt2.Native_HasCustomAIOverride(akActor)
        If !SeverActionsNativeExt2.Native_IsCustomFollowerDismissed(akActor)
            Return true
        EndIf
    EndIf
    Return false
EndFunction

Function CheckTrackOnlyFollowerStatus()
    {Tick backstop to TeammateMonitor: untrack loaded track-only followers who
     were dismissed through their own framework while the monitor missed it.}
    Actor[] followers = GetAllFollowers()
    Int i = 0
    While i < followers.Length
        Actor follower = followers[i]
        ; Gate on OWNERSHIP, not the follow gate: a lost teammate flag or WFP == -1
        ; only means "dismissed" for an actor some framework leads. A Tracking-mode
        ; recruit through SA's own action is a rostered non-teammate nobody leads,
        ; which the follow gate would untrack on the next pass.
        If follower && SeverActionsNativeExt2.Native_IsTrackOnlyFollower(follower)
            ; Unloaded actors' state is unreliable.
            If follower.Is3DLoaded()
                Bool shouldUntrack = false

                If !follower.IsPlayerTeammate()
                    If SeverActionsNativeExt.Brawl_IsActive(follower)
                        ; Mid-brawl, not a dismiss: the brawl strips the teammate
                        ; flag from both fighters and restores it at the end
                        ; (TeammateMonitor and CellCatchup carry the same gate).
                        DebugMsg("Track-only untrack SKIPPED: " + follower.GetDisplayName() + " is mid-brawl")
                    ElseIf IsStillFollowingByEvidence(follower)
                        ; Not a teammate but still following through their own
                        ; framework (see IsStillFollowingByEvidence).
                        DebugMsg("Track-only untrack SKIPPED: " + follower.GetDisplayName() + " still following (faction/package evidence)")
                    Else
                        ; No teammate flag and no follow evidence: a dismiss.
                        shouldUntrack = true
                        DebugMsg("Track-only auto-untrack: " + follower.GetDisplayName() + " lost teammate status")
                    EndIf
                ElseIf follower.GetAV("WaitingForPlayer") == -1.0
                    ; WFP == -1 is the dismiss for custom followers (Inigo) that
                    ; keep the teammate flag. Send one with an SA home there
                    ; rather than to their default cell.
                    Int homeSlot = SeverActionsNative.Native_GetHomeMarkerSlot(follower)
                    If homeSlot >= 0 && HomeMarkerList
                        ObjectReference homeMarker = HomeMarkerList.GetAt(homeSlot) as ObjectReference
                        If homeMarker
                            ApplyHomeSandbox(follower, homeMarker, homeSlot)
                            DebugMsg("Track-only auto-untrack: " + follower.GetDisplayName() + " - redirected to home (WFP=-1 -> sandbox)")
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
    {Remove a follower's Papyrus-side data (StorageUtil, factions, aliases, home,
     work/play markers, the outfit lock). The native follower and outfit rows
     stay: call ForceRemoveFollower, which runs this and then erases them.}
    If !akActor
        Return
    EndIf

    String actorName = akActor.GetDisplayName()
    DebugMsg("PurgeFollower: " + actorName)

    ; StorageUtil keys
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
    StorageUtil.UnsetFloatValue(akActor, KEY_NEXT_ASSESS_GT)
    StorageUtil.UnsetFloatValue(akActor, KEY_NEXT_INTER_ASSESS_GT)
    StorageUtil.UnsetFloatValue(akActor, KEY_NEXT_LIFE_EVENT_GT)
    StorageUtil.UnsetFloatValue(akActor, KEY_DISMISS_GT)
    StorageUtil.UnsetIntValue(akActor, KEY_DISMISSED)
    StorageUtil.UnsetIntValue(akActor, KEY_TRUEHOME_MIGRATED)
    ; Legacy key an older save may carry (the healer cooldown is native now).
    StorageUtil.UnsetFloatValue(akActor, "SeverFollower_HealerBleedoutLast")

    SeverActionsNative.Native_OffScreen_ClearActor(akActor)

    ; Assessment dedup watermarks
    StorageUtil.UnsetIntValue(akActor, "SeverFollower_LastAssessEventId")
    StorageUtil.UnsetIntValue(akActor, "SeverFollower_LastAssessMemoryId")
    StorageUtil.UnsetIntValue(akActor, "SeverFollower_LastAssessDiaryId")
    StorageUtil.UnsetIntValue(akActor, "SeverFollower_LeaveWarned")
    StorageUtil.UnsetFloatValue(akActor, "SeverFollower_DeathTime")

    ; Factions
    If SeverActions_FollowerFaction
        akActor.RemoveFromFaction(SeverActions_FollowerFaction)
    EndIf
    RemoveBardAudienceExclusion(akActor)

    ; A living NFF follower leaves through NFF, which empties its alias seat and clears its own
    ; follower state: stripped behind its back, NFF kept the seat and its trade topic went dead.
    Bool nffDismissed = false
    If SeverActionsNativeExt2.Native_IsNFFInstalled() && !akActor.IsDead()
        nffDismissed = SeverActions_NFFLib.NFFDismiss(akActor)   ; false for an actor NFF does not seat
    EndIf
    If !nffDismissed
        Faction currentFollowerFaction = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
        If currentFollowerFaction
            akActor.RemoveFromFaction(currentFollowerFaction)
        EndIf

        Faction playerFollowerFaction = Game.GetFormFromFile(0x084D1B, "Skyrim.esm") as Faction
        If playerFollowerFaction
            akActor.RemoveFromFaction(playerFollowerFaction)
        EndIf

        akActor.SetPlayerTeammate(false)
    EndIf

    ; Clear the outfit lock (restores DefaultOutfit). SeverActions_Outfit
    ; releases the seat when the native row is erased after this.
    SeverActionsNative.Native_Outfit_ClearLock(akActor)

    ClearHome(akActor)

    ; Drops the work-package override and LinkedRefs and deletes the
    ; force-persisted work marker, which would otherwise leak into the save.
    ClearRoutineLoc(akActor, "work")
    ClearRoutineLoc(akActor, "play")
    ; ClearRoutineLoc re-stamps KEY_LAST_SCHEDULED_TYPE (-99); unset it after.
    StorageUtil.UnsetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE)

    SeverActions_Follow followSys = GetFollowScript()
    If followSys
        followSys.CompanionStopFollowing(akActor)
    EndIf

    DebugMsg("PurgeFollower complete: " + actorName)
EndFunction

Function ForceRemoveFollower(Actor akActor)
    {The full force removal, and the one place its order lives:
     1. restore the pre-recruit combat style if SA overrode it, and drop the
        healer role (a no-op on a non-healer);
     2. PurgeFollower, while the native row still holds the bed claim, home slot,
        schedule alias indices, relax marker and guarded person it releases;
     3. Native_RemoveFollowerData, then Native_Outfit_RemoveActor (restores a
        parked DefaultOutfit, drops the outfit row);
     4. the opinions rebuild, so the other followers stop naming them.
     Callers: the followers provider's "purge" service (MCM Force Remove),
     OnPrismaForceRemove and CheckDeadFollowers. PurgeFollower stays separate for
     a saved frame's old bytecode.}
    If !akActor
        Return
    EndIf
    Form origCSForm = SeverActionsNativeExt.Native_GetOrigCombatStyleForm(akActor)
    If origCSForm
        CombatStyle origCS = origCSForm as CombatStyle
        ActorBase removeBase = akActor.GetActorBase()
        If origCS && removeBase
            removeBase.SetCombatStyle(origCS)
        EndIf
        SeverActionsNativeExt.Native_SetOrigCombatStyleForm(akActor, None)
    EndIf
    RemoveHealerRole(akActor)
    PurgeFollower(akActor)
    SeverActionsNative.Native_RemoveFollowerData(akActor)
    SeverActionsNative.Native_Outfit_RemoveActor(akActor)
    ; As in UnregisterFollower.
    SeverActionsNativeExt2.Native_HydrateFollowerSystem_RebuildOpinions()
EndFunction

Function SoftResetFollower(Actor akActor)
    {Unstick a follower: clear factions, packages, aliases and teammate status
     (a framework-led follower keeps its framework's faction and teammate flag)
     but keep relationship data, home, combat style and assessment history.}
    If !akActor
        Return
    EndIf

    String actorName = akActor.GetDisplayName()
    DebugMsg("SoftResetFollower: " + actorName)

    ; The native row stays, so re-recruit detection still sees it.
    SeverActionsNative.Native_SetIsFollower(akActor, false)
    StorageUtil.UnsetIntValue(akActor, KEY_DISMISSED)

    If SeverActions_FollowerFaction
        akActor.RemoveFromFaction(SeverActions_FollowerFaction)
    EndIf
    RemoveBardAudienceExclusion(akActor)

    ; A follower another framework leads (NFF, a DLC, custom AI, or recruited through one in Tracking
    ; mode) keeps its follower faction and teammate flag: the framework restores them only when it
    ; recruits, and its trade topic needs both. Mode alone does not count: a follower SA recruited
    ; itself has SA's flags, which the reset must clear.
    Bool frameworkLed = SeverActionsNativeExt2.Native_IsTrackOnlyFollower(akActor) \
        || StorageUtil.GetIntValue(akActor, "SeverActions_HandsOffAtRecruit", 0) == 1
    If !frameworkLed
        Faction currentFollowerFaction = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
        If currentFollowerFaction
            akActor.RemoveFromFaction(currentFollowerFaction)
        EndIf

        Faction playerFollowerFaction = Game.GetFormFromFile(0x084D1B, "Skyrim.esm") as Faction
        If playerFollowerFaction
            akActor.RemoveFromFaction(playerFollowerFaction)
        EndIf

        akActor.SetPlayerTeammate(false)
    EndIf

    ; The outfit seat is SeverActions_Outfit's, kept while a lock or preset needs
    ; it. On the Actions-page soft reset the native handler has already run
    ; ClearData on the follower row and cleared the lock before this runs.

    ; Stop following and clear the waiting faction.
    SeverActions_Follow followSys = GetFollowScript()
    If followSys
        followSys.CompanionStopFollowing(akActor)
        If followSys.SeverActions_WaitingFaction
            followSys.ClearWaitingFaction(akActor)
        EndIf
    EndIf

    If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.hasBeenSoftReset", ("" + actorName)))
    EndIf

    ; Still their framework's teammate, so TeammateMonitor sees no change to re-detect: onboard now.
    If frameworkLed && akActor.IsPlayerTeammate()
        OnboardExternalTeammate(akActor)
    EndIf

    DebugMsg("SoftResetFollower complete: " + actorName)
EndFunction

Event OnPrismaSoftReset(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI soft reset (SoftResetFollower). strArg = "actorName|".}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = ResolvePrismaTarget(sender, actorName)
    If akActor
        DebugMsg("PrismaUI soft-reset: " + akActor.GetDisplayName())
        SoftResetFollower(akActor)
    Else
        DebugMsg("PrismaUI soft-reset: actor '" + actorName + "' not found")
    EndIf
EndEvent

Event OnPrismaForceRemove(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI force remove (the Companions page's Force Remove and each fallen
     entry of Clear Fallen & Orphaned): ForceRemoveFollower, then the repaint.
     The DLL must not erase the rows first. A ghost with no resolvable form is
     erased by the DLL and never arrives here. numArg 1 = a batch member that is
     not the last (skip the refresh). strArg = "actorName|".}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = ResolvePrismaTarget(sender, actorName)
    If akActor
        DebugMsg("PrismaUI force-remove: " + akActor.GetDisplayName())
        ForceRemoveFollower(akActor)
    Else
        Debug.Trace("[SeverActions_FollowerManager] Menu force-remove: actor '" + actorName + "' not resolvable - nothing purged, its native rows stay")
    EndIf
    If numArg < 0.5
        SeverActionsNative.Magelight_RefreshPage("companions")
        SeverActionsNative.Magelight_RefreshPage("outfits")
    EndIf
EndEvent

Event OnPrismaDismiss(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI dismiss. The dismissal is entirely ours: UnregisterFollower reads
     what it restores (essential, the Serana route, the combat style) from the
     native row before clearing it, so the DLL must not wipe it first. Repaints
     the Companions page after. strArg = "actorName|".}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = ResolvePrismaTarget(sender, actorName)
    If akActor
        DebugMsg("PrismaUI dismiss: " + akActor.GetDisplayName())
        DismissCompanion(akActor)
    EndIf
    SeverActionsNative.Magelight_RefreshPage("companions")
EndEvent

Event OnPrismaCustomAIOverride(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: toggle the custom-AI classification override.
     strArg = "actorName|1" (force normal) or "actorName|0" (restore own AI).}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Bool forceNormal = StringUtil.Substring(strArg, pipePos + 1) == "1"
    Actor akActor = ResolvePrismaTarget(sender, actorName)
    If akActor
        SetCustomAIOverride(akActor, forceNormal)
    EndIf
EndEvent

Event OnPrismaCompanionWait(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI Wait: CompanionWait, as the hotkey and wheel do. strArg = "actorName|".}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = ResolvePrismaTarget(sender, actorName)
    If akActor
        DebugMsg("PrismaUI wait: " + akActor.GetDisplayName())
        CompanionWait(akActor)
    EndIf
EndEvent

Event OnPrismaCompanionFollow(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI Follow: CompanionFollow, as the hotkey and wheel do. strArg = "actorName|".}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = ResolvePrismaTarget(sender, actorName)
    If akActor
        DebugMsg("PrismaUI follow: " + akActor.GetDisplayName())
        CompanionFollow(akActor)
    EndIf
EndEvent

Event OnPrismaCompanionWaitAll(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI Wait All: one event for the whole roster (not one per follower,
     which floods the VM queue on large parties), one summary notification.}
    Actor[] allComp = GetAllFollowers()
    If !allComp
        Return
    EndIf
    Float waStart = Utility.GetCurrentRealTime()
    Int ci = 0
    DebugMsg("PrismaUI wait-all: " + allComp.Length + " companion(s)")
    While ci < allComp.Length
        If allComp[ci]
            ; Quiet: no per-follower notification.
            _CompanionWaitCore(allComp[ci], true)
        EndIf
        ci += 1
    EndWhile
    If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
        If allComp.Length == 1
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.isWaitingHereFor", ("" + allComp[0].GetDisplayName())))
        Else
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.companionsAreWaitingHere", ("" + allComp.Length)))
        EndIf
    EndIf
    ; Proves the event fired and times the per-follower work on large rosters.
    DebugMsg("PrismaUI wait-all: done in " + (Utility.GetCurrentRealTime() - waStart) + "s")
EndEvent

Event OnPrismaCompanionFollowAll(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI Follow All: the inverse of OnPrismaCompanionWaitAll.}
    Actor[] allComp = GetAllFollowers()
    If !allComp
        Return
    EndIf
    Float faStart = Utility.GetCurrentRealTime()
    Int ci = 0
    DebugMsg("PrismaUI follow-all: " + allComp.Length + " companion(s)")
    While ci < allComp.Length
        If allComp[ci]
            _CompanionFollowCore(allComp[ci], true)
        EndIf
        ci += 1
    EndWhile
    If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
        If allComp.Length == 1
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.isFollowingYouAgain", ("" + allComp[0].GetDisplayName())))
        Else
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.companionsAreFollowingAgain", ("" + allComp.Length)))
        EndIf
    EndIf
    DebugMsg("PrismaUI follow-all: done in " + (Utility.GetCurrentRealTime() - faStart) + "s")
EndEvent

Event OnPrismaResetAll(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI Dismiss All. The roster is read ONCE before the loop: each
     dismissal clears that actor's isFollower flag, so re-reading mid-loop would
     shrink the list. The DLL must not wipe the store first; dismissal and the
     refresh are ours.}
    Debug.Trace("[SeverActions_FollowerManager] Menu reset all companions")
    Actor[] allComp = GetAllFollowers()
    Int dismissed = 0
    If allComp
        Int ci = 0
        While ci < allComp.Length
            If allComp[ci]
                DismissCompanion(allComp[ci])
                dismissed += 1
            EndIf
            ci += 1
        EndWhile
    EndIf
    Debug.Trace("[SeverActions_FollowerManager] Menu reset all: dismissed " + dismissed)
    If dismissed > 0
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.dismissedCompanions", ("" + dismissed)))
    EndIf
    ; The authoritative repaint (a large roster can outlast the frontend's timer).
    SeverActionsNative.Magelight_RefreshPage("companions")
    SeverActionsNative.Magelight_RefreshPage("outfits")
EndEvent

Function _OnboardTrackingMode(Actor akActor, Bool isFirstRecruit)
    {Shared onboarding for a tracking-mode follower (recorded hands-off, see
     WasHandsOffAtRecruit), called by DetectExistingFollowers,
     RecoverCustomAIFollowers and OnNativeTeammateDetected once each has
     accepted the recruit. State mutations only; notifications and SkyrimNet
     events stay with the caller.}
    If !akActor
        Return
    EndIf
    _ReleaseSAWait(akActor)
    StorageUtil.SetIntValue(akActor, "SeverActions_HandsOffAtRecruit", 1)
    Float now = GetGameTimeInSeconds()
    Bool wasRegistered = IsRegisteredFollower(akActor)
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

    ; The outfit seat follows from SetIsFollower(true) via SeverActions_Outfit.

    ; Parity with RegisterFollower: actor-level mutations only (no package
    ; overrides, so the track-only rule holds). All idempotent, so the load-time
    ; callers re-apply them harmlessly.
    akActor.IgnoreFriendlyHits(true)
    ApplyTrapImmunity(akActor)

    ; Essential via the alias slot. WasEssential records whether the NPC's own
    ; record is essential, so a dismiss won't strip it; read only on joining the
    ; roster (see RegisterFollower). Honors EssentialOff.
    If !wasRegistered
        SeverActionsNativeExt.Native_SetWasEssential(akActor, SeverActionsNative.Native_IsEssential(akActor))
    EndIf
    If !SeverActionsNativeExt.Native_GetEssentialOff(akActor)
        MakeActorEssential(akActor)
    EndIf

    If isFirstRecruit
        ; RegisterFollower's recruit bonus.
        ModifyRapport(akActor, 5.0)
        ModifyTrust(akActor, 5.0)
    Else
        ; Returning follower: dismiss restored the original AI values and
        ; dropped the healer role, so re-apply a saved combat style and role.
        String style = GetCombatStyle(akActor)
        If style != "no combat style" && style != "balanced"
            ApplyCombatStyleValues(akActor, style)
            If style == "healer"
                ApplyHealerRole(akActor)
            EndIf
        EndIf
    EndIf
EndFunction

; =============================================================================
; BARD-AUDIENCE EXCLUSION
; =============================================================================
; Vanilla BardAudienceExcludedFaction (0x10FCB4) keeps followers from leaving
; their follow package to watch a bard. Kept in step with
; SeverActions_FollowerFaction membership (added on onboard, removed on leave).

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
    {Add an actor to the follower roster and start them following. With NFF
     installed, NFF recruits them first (see below).}
    If !akActor || akActor.IsDead()
        Return
    EndIf
    ; The Final Audit is unrecruitable by design; eligibility already hides the
    ; action, this guards direct calls.
    If SeverActionsNativeExt2.Venture_Audit_IsCollector(akActor)
        SkyrimNetApi.RegisterEvent("follower_recruit_failed",             akActor.GetDisplayName() + " serves the Imperial Treasury alone - the Final Audit follows no one. Whatever business " + Game.GetPlayer().GetDisplayName() + " has with them can be conducted right where they stand.",             akActor, None)
        Return
    EndIf
    ; A bound captive (phase >= 2) cannot be recruited: follow packages fight the
    ; hold pin, cell catchup teleports them, and follower status defeats the
    ; is_sever_follower eligibility gates.
    If SeverActionsNativeExt.Native_Kidnap_GetPhase(akActor) >= 2
        SkyrimNetApi.RegisterEvent("follower_recruit_failed",             akActor.GetDisplayName() + " is bound and held captive - they are in no position to follow anyone.",             akActor, None)
        Return
    EndIf

    ; Someone already on the roster is re-registered even at the cap (the hotkey,
    ; the Actions page, a brawler's re-recruit).
    Bool wasRegistered = IsRegisteredFollower(akActor)
    If !wasRegistered && !CanRecruitMore()
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("followermanager.tooManyFollowersAlready"))
        SkyrimNetApi.RegisterEvent("follower_recruit_failed", \
            akActor.GetDisplayName() + " cannot join because " + Game.GetPlayer().GetDisplayName() + " already has too many companions.", \
            akActor, Game.GetPlayer())
        Return
    EndIf

    ; Lets listeners (e.g. Hearth's camp layer, a kidnapper's guard duty) release
    ; their own hold on the actor before the recruit changes teammate/faction
    ; state. After every guard that can abort: a refused recruit releases nothing.
    ; strArg = verb.
    Int recruitEvt = ModEvent.Create("SeverActions_FollowerCalledByPlayer")
    If recruitEvt
        ModEvent.PushString(recruitEvt, "SeverActions_FollowerCalledByPlayer")
        ModEvent.PushString(recruitEvt, "recruit")
        ModEvent.PushFloat(recruitEvt, 0.0)
        ModEvent.PushForm(recruitEvt, akActor)
        ModEvent.Send(recruitEvt)
    EndIf

    ; A recruit is a follow order: it ends a journey or wait the way CompanionFollow does
    ; (afArg 0.0 = no follower restore, the recruit below sets them following).
    SeverActions_ModuleBase.CallBool("travelcore", "cancelJourney", akActor, None, "", 0.0)
    If SeverActionsNativeExt2.Travel_ReleaseStaleAliasFor(akActor)
        Debug.Trace("[SeverActions] RegisterFollower: released stale travel alias for " + akActor.GetDisplayName())
    EndIf

    ; With NFF installed, NFF recruits them into a seat of its own. Must stay
    ; AFTER every guard that can abort this recruit, or NFF seats an NPC that SA
    ; never registers. NFFRecruit refuses actors another framework owns.
    If SeverActionsNativeExt2.Native_IsNFFInstalled()
        SeverActions_NFFLib.NFFRecruit(akActor)
    EndIf

    ; If NFF owns this actor, evict SA's own follow machinery (the pool seat,
    ; legacy slot or overflow a companion recruited before NFF still holds), or
    ; our package keeps them following through NFF's dismiss. One framework
    ; drives an actor.
    If SeverActionsNativeExt2.Native_IsNFFManaged(akActor)
        SeverActionsNativeExt2.Native_ClearSAFollowOwnership(akActor)
        SeverActions_Follow fsGuard = GetFollowScript()
        If fsGuard
            fsGuard.ClearFollowerSlot(akActor)
        EndIf
        Debug.Trace("[SeverActions_FollowerManager] RegisterFollower: NFF owns " + akActor.GetDisplayName() + " - evicted SA follow machinery (alias/legacy/overflow)")
    EndIf

    Bool isFirstRecruit = !SeverActionsNativeExt2.Native_WasEverFollower(akActor)

    ; SA's own tracking, whatever the framework.
    StorageUtil.UnsetIntValue(akActor, KEY_DISMISSED)
    SeverActionsNative.Native_SetIsFollower(akActor, true)
    SeverActionsNativeExt.Native_SetInteractionTime(akActor, GetGameTimeInSeconds())

    If SeverActions_FollowerFaction
        akActor.AddToFaction(SeverActions_FollowerFaction)
    EndIf
    AddBardAudienceExclusion(akActor)

    ; Together with SeverActions_FollowerFaction's Ally reactions (ESP: to itself,
    ; CurrentFollowerFaction and the player), stray AoE and arrow hits no longer turn
    ; followers on each other or the player.
    akActor.IgnoreFriendlyHits(true)

    ; See the TRAP IMMUNITY block.
    ApplyTrapImmunity(akActor)

    If isFirstRecruit
        StorageUtil.SetFloatValue(akActor, KEY_RECRUIT_TIME, GetGameTimeInSeconds())
        SeverActionsNative.Native_SetRelationship(akActor, DEFAULT_RAPPORT, DEFAULT_TRUST, DEFAULT_LOYALTY, DEFAULT_MOOD)
        SeverActionsNative.Native_SetCombatStyle(akActor, "no combat style")
    EndIf

    ; Morality AV snapshot for prompts (0 any crime, 1 violence, 2 property, 3 none)
    StorageUtil.SetIntValue(akActor, KEY_MORALITY, akActor.GetAV("Morality") as Int)

    ; Recruit bonus, first recruit only.
    If isFirstRecruit
        ModifyRapport(akActor, 5.0)
        ModifyTrust(akActor, 5.0)
    EndIf

    ; Serana: always through her DLC quest.
    If SeverActions_FollowerFrameworkLib.IsSerana(akActor) && !akActor.IsPlayerTeammate()
        If SeverActions_FollowerFrameworkLib.RecruitSerana(akActor)
            SeverActionsNativeExt.Native_SetRecruitedViaSerana(akActor, true)
            DebugMsg("Serana DLC routing: " + akActor.GetDisplayName())
        Else
            DebugMsg("Serana DLC routing FAILED - quest not ready, using manual setup")
            akActor.SetPlayerTeammate(true)
            akActor.IgnoreFriendlyHits(true)
        EndIf

    ; Tracking mode: observe only, no teammate/package management. IsFollowHandsOff
    ; is the ownership verdict (custom AI, NFF, DLC) OR FrameworkMode 1 (D45).
    ElseIf IsFollowHandsOff(akActor)
        DebugMsg("Tracking mode: " + akActor.GetDisplayName())
        ; Still drop our home/work sandboxes and schedule alias, and SA's own wait.
        StripSandboxesForFollow(akActor)
        ClearWorkSandboxForFollow(akActor)
        EmptySchedAliasesForFollow(akActor)
        _ReleaseSAWait(akActor)

    ; SeverActions mode: full control.
    Else
        DebugMsg("SeverActions mode: " + akActor.GetDisplayName())

        ; Snapshot the original AI values for dismiss, only if none exists: a
        ; repeat RegisterFollower (hotkey/wheel) would snapshot boosted values.
        If !StorageUtil.HasFloatValue(akActor, KEY_ORIG_AGGRESSION)
            StorageUtil.SetFloatValue(akActor, KEY_ORIG_AGGRESSION, akActor.GetAV("Aggression"))
            StorageUtil.SetFloatValue(akActor, KEY_ORIG_CONFIDENCE, akActor.GetAV("Confidence"))
            StorageUtil.SetIntValue(akActor, KEY_ORIG_RELRANK, akActor.GetRelationshipRank(Game.GetPlayer()))
        EndIf

        ; Raise the AVs so passive NPCs fight (actor values only, not the
        ; combat style form). Skipped for the "coward" style: the player chose a
        ; pacifist, and the style survives dismiss, so a re-recruit must not
        ; re-arm them.
        If GetCombatStyle(akActor) != "coward"
            If akActor.GetAV("Confidence") < 3
                akActor.SetAV("Confidence", 3)  ; Brave
            EndIf
            If akActor.GetAV("Aggression") < 1
                akActor.SetAV("Aggression", 1)  ; Aggressive
            EndIf
            If akActor.GetAV("Assistance") < 2
                akActor.SetAV("Assistance", 2)  ; Helps Allies
            EndIf
        Else
            DebugMsg("RegisterFollower: " + akActor.GetDisplayName() + " is set to the coward style — leaving Confidence/Aggression/Assistance alone")
        EndIf

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

        ; Start the follow before the bookkeeping below, which can take seconds
        ; on a large roster.
        StripSandboxesForFollow(akActor)
        ClearWorkSandboxForFollow(akActor)
        SeverActions_Follow followSysEarly = GetFollowScript()
        If followSysEarly
            followSysEarly.CompanionStartFollowing(akActor)
        EndIf

        ; Vanilla DialogueFollower routing for idle lines. Skipped with NFF (it
        ; hooks those aliases itself) or SFF (it overrides the quest into extra
        ; aliases SA cannot clear on dismiss; see HasSFF).
        If !SeverActionsNativeExt2.Native_IsNFFInstalled() && !SeverActions_FollowerFrameworkLib.HasSFF()
            SeverActions_FollowerFrameworkLib.RecruitViaVanillaDialogue(akActor)
            Quest dfQuest = Game.GetFormFromFile(0x000750BA, "Skyrim.esm") as Quest
            If dfQuest
                ReferenceAlias dfAlias = dfQuest.GetAlias(0) as ReferenceAlias
                If dfAlias && dfAlias.GetReference() == None
                    dfAlias.ForceRefTo(akActor)
                    DebugMsg("Filled DialogueFollower alias: " + akActor.GetDisplayName())
                EndIf
            EndIf

            ; Vanilla SetFollower's alias fill evicts the previous occupant from
            ; CurrentFollowerFaction, and mods such as Convenient Horses treat a
            ; missing CFF as a dismiss (clearing the teammate flag, which then
            ; unregisters them here). Re-add every prior SA follower to CFF.
            Faction cffRepair = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
            If cffRepair
                ; The native tracked list, not GetAllFollowers (seconds on a
                ; large roster).
                Actor[] priorFollowers = SeverActionsNative.Native_GetAllTrackedFollowers()
                Int repaired = 0
                Int p = 0
                While p < priorFollowers.Length
                    Actor priorF = priorFollowers[p]
                    If priorF && priorF != akActor && IsRegisteredFollower(priorF) && priorF.GetFactionRank(cffRepair) < 0
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
    EndIf

    ; The outfit seat follows from SetIsFollower(true) via SeverActions_Outfit.

    ; Returning follower: dismiss restored the original AI values, so re-apply
    ; the combat style.
    If !isFirstRecruit
        String style = GetCombatStyle(akActor)
        If style != "no combat style" && style != "balanced"
            ApplyCombatStyleValues(akActor, style)
            ; Dismiss dropped the healer role too.
            If style == "healer"
                ApplyHealerRole(akActor)
            EndIf
            DebugMsg("Reapplied combat style '" + style + "' on re-recruit for " + akActor.GetDisplayName())
        EndIf
    EndIf

    Bool isTrackOnly = IsFollowHandsOff(akActor)
    ; The verdict the onboarding ran under, for the dismiss (see WasHandsOffAtRecruit). A
    ; re-register of a follower SA led records 0: the Tracking branch strips none of the
    ; flags SA set, so the dismiss must still undo them.
    If wasRegistered && WasSALedRecruit(akActor)
        StorageUtil.SetIntValue(akActor, "SeverActions_HandsOffAtRecruit", 0)
    Else
        StorageUtil.SetIntValue(akActor, "SeverActions_HandsOffAtRecruit", isTrackOnly as Int)
    EndIf

    If isFirstRecruit
        If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
            If isTrackOnly
                Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.isNowBeingTracked", ("" + akActor.GetDisplayName())))
            Else
                Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.hasJoinedYouAsCompanion", ("" + akActor.GetDisplayName())))
            EndIf
        EndIf

        SkyrimNetApi.RegisterEvent("follower_recruited", \
            akActor.GetDisplayName() + " has been recruited as a companion by " + Game.GetPlayer().GetDisplayName() + ".", \
            akActor, Game.GetPlayer())

        DebugMsg("Registered follower (NEW, " + (isTrackOnly as String) + "): " + akActor.GetDisplayName())
    Else
        If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
            If isTrackOnly
                Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.isNowBeingTracked", ("" + akActor.GetDisplayName())))
            Else
                Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.hasReturned", ("" + akActor.GetDisplayName())))
            EndIf
        EndIf

        DebugMsg("Registered follower (RETURNING): " + akActor.GetDisplayName())
    EndIf

    ; Essential is opt-in (EssentialOff defaults true, cosaved) and applied via
    ; an alias slot. WasEssential records whether the NPC's own record is
    ; essential, so a dismiss won't strip it. Read only on joining the roster: on
    ; a re-register the base flag may be one SA set (Essential ON sets it live).
    If !wasRegistered
        SeverActionsNativeExt.Native_SetWasEssential(akActor, SeverActionsNative.Native_IsEssential(akActor))
    EndIf
    Bool essentialEnabled = !SeverActionsNativeExt.Native_GetEssentialOff(akActor)
    If essentialEnabled
        MakeActorEssential(akActor)
        DebugMsg("Set essential (alias) for " + akActor.GetDisplayName())
    EndIf

    SeverActionsNative.Native_OnFollowerRecruited(akActor)

    ; Rebuild the roster's companion opinions so the newcomer has theirs now.
    ; The opinions pass only: a full hydrate would stomp a brawl's or yield's
    ; temporary Confidence/Aggression.
    SeverActionsNativeExt2.Native_HydrateFollowerSystem_RebuildOpinions()
EndFunction

Function UnregisterFollower(Actor akActor, Bool sendHome = true, Bool abDeliberateExit = false)
    {Remove an actor from the follower roster. A deliberate exit of an NFF-owned
     actor is dismissed through NFF first; SA's own teardown always runs.}
    If !akActor
        Return
    EndIf

    ; Only NFF can empty its own alias seat, so a deliberate exit (the player's
    ; DismissCompanion, or FollowerLeaves) goes through NFFDismiss. Never for the
    ; heuristic sweeps (CheckTrackOnlyFollowerStatus, the pending-dismiss queue):
    ; a false positive there would really dismiss an NFF follower.
    Bool nffOwnsDismissal = false
    ; Read before NFFDismiss starts NFF's teardown, which changes the ownership verdict.
    Bool saOwnRecruit = WasSALedRecruit(akActor)
    If abDeliberateExit
        nffOwnsDismissal = SeverActionsNativeExt2.Native_IsNFFInstalled() && SeverActions_NFFLib.NFFDismiss(akActor)
    EndIf

    ; Before the mode branches, so both modes undo the LightFoot perk.
    RemoveTrapImmunity(akActor)

    ; Cancel any live journey first, without restoring follower status
    ; (afArg 0.0): its completion would otherwise re-teammate the dismissed NPC
    ; and TeammateMonitor would re-onboard them. The WasFollower unset is a belt.
    ; The event frees a Hearth camp claim, as follow/wait do.
    SeverActions_ModuleBase.CallBool("travelcore", "cancelJourney", akActor, None, "", 0.0)
    StorageUtil.UnsetIntValue(akActor, "SeverTravel_WasFollower")
    Int dismissEvt = ModEvent.Create("SeverActions_FollowerCalledByPlayer")
    If dismissEvt
        ModEvent.PushString(dismissEvt, "SeverActions_FollowerCalledByPlayer")
        ModEvent.PushString(dismissEvt, "dismiss")
        ModEvent.PushFloat(dismissEvt, 0.0)
        ModEvent.PushForm(dismissEvt, akActor)
        ModEvent.Send(dismissEvt)
    EndIf

    ; The outfit lock stays (see the end of this function); SeverActions_Outfit
    ; decides the seat, and the native 3D-load re-equip enforces a lock without one.

    ; Idempotent; stops HealerCast events for a dismissed healer.
    RemoveHealerRole(akActor)

    ; SA's own tracking, whatever the framework.
    SeverActionsNative.Native_SetIsFollower(akActor, false)
    StorageUtil.SetIntValue(akActor, KEY_DISMISSED, 1)
    StorageUtil.SetFloatValue(akActor, KEY_DISMISS_GT, GetGameTimeInSeconds())

    ; Read what the branches below restore BEFORE Native_ClearFollowerData, which
    ; resets wasEssential, the Serana route and SA's wait flag (a later read sees
    ; defaults). The combat style is read here too, so its restore does not depend
    ; on what ClearData keeps.
    Bool wasEssentialAtRecruit = SeverActionsNativeExt.Native_GetWasEssential(akActor)
    Bool saWaitAtDismiss = SeverActionsNativeExt.Native_GetSandboxing(akActor)
    Bool viaSeranaAtRecruit = SeverActionsNativeExt.Native_GetRecruitedViaSerana(akActor)
    Form origCSFormAtRecruit = SeverActionsNativeExt.Native_GetOrigCombatStyleForm(akActor)

    SeverActionsNative.Native_ClearFollowerData(akActor)
    ; Every other follower's companion opinions still name them until rebuilt.
    SeverActionsNativeExt2.Native_HydrateFollowerSystem_RebuildOpinions()

    If SeverActions_FollowerFaction
        akActor.RemoveFromFaction(SeverActions_FollowerFaction)
    EndIf
    RemoveBardAudienceExclusion(akActor)

    ; Clear the actor from EVERY DialogueFollower alias, not just alias 0: SFF
    ; overrides the quest and parks followers in extra aliases carrying the
    ; vanilla follow package. Never for an NFF actor (routed or not): NFF empties
    ; its own seat during an async teardown, and clearing it mid-flight desyncs
    ; NFF so the NPC keeps following.
    If !nffOwnsDismissal && !SeverActionsNativeExt2.Native_IsNFFManaged(akActor)
        Quest dialogueFollowerQuest = Game.GetFormFromFile(0x000750BA, "Skyrim.esm") as Quest
        If dialogueFollowerQuest
            Int aliasCount = dialogueFollowerQuest.GetNumAliases()
            Int ai = 0
            While ai < aliasCount
                ReferenceAlias dfa = dialogueFollowerQuest.GetNthAlias(ai) as ReferenceAlias
                If dfa && dfa.GetReference() == akActor as ObjectReference
                    dfa.Clear()
                    DebugMsg("Cleared DialogueFollower alias #" + ai + " for " + akActor.GetDisplayName())
                EndIf
                ai += 1
            EndWhile
        EndIf
    EndIf

    ; Strip the safe-interior leisure sandbox (priority 100, re-asserted) before
    ; any branch applies home, or the home sandbox (also 100) cannot win.
    ; No teleport; a no-op when not relaxing. Only when sending home.
    If sendHome
        SeverActions_Follow followSafeStrip = GetFollowScript()
        If followSafeStrip
            followSafeStrip.StripSafeInteriorForFollow(akActor)
        EndIf
    EndIf

    ; Serana: dismiss through her DLC quest.
    If viaSeranaAtRecruit
        DebugMsg("Serana DLC dismiss: " + akActor.GetDisplayName())
        SeverActions_FollowerFrameworkLib.DismissSerana(akActor)
        SeverActionsNativeExt.Native_SetRecruitedViaSerana(akActor, false)

    ; Hands-off (owned elsewhere, or recruited while SA led nobody: through a
    ; framework or in Tracking mode): only SA's own state is undone. The owning
    ; framework manages AI, factions, packages, outfit and essential status;
    ; touching them can re-activate its follow packages or break its dismiss flow.
    ElseIf WasHandsOffAtRecruit(akActor) && !saOwnRecruit
        DebugMsg("Tracking mode dismiss (bookkeeping only): " + akActor.GetDisplayName())
        StorageUtil.UnsetIntValue(akActor, "SeverActions_HandsOffAtRecruit")
        ; RegisterFollower set this plain actor flag in every mode; undo it.
        akActor.IgnoreFriendlyHits(False)
        ; SA's own follow LinkedRef, left on a follower SA led before they turned
        ; hands-off (off the roster now, so ReapplyFollowTracking never sees them).
        Keyword dismissFollowKW = Game.GetFormFromFile(FID_FOLLOW_KW, "SeverActions.esp") as Keyword
        If dismissFollowKW
            SeverActionsNative.LinkedRef_Clear(akActor, dismissFollowKW)
        EndIf
        ; SA's own follow seat, faction and wait, likewise: the pool package would keep them
        ; following until the next load, and the faction or a wait (WaitingForPlayer 1) would
        ; keep the home order below off them. Only with SA's seat: without one the faction
        ; may mark a follow their framework still leads, and dropping it would send them home.
        ; No EvaluatePackage: the home order or their framework re-picks.
        SeverActions_Follow dismissFollow = GetFollowScript()
        If dismissFollow && dismissFollow.IsInFollowerSlot(akActor)
            dismissFollow.ClearFollowerSlot(akActor)
            dismissFollow.SetActivelyFollowing(akActor, false)
            ; Only SA's own wait: vanilla, SFF and custom-AI waits also write 1.
            If saWaitAtDismiss && akActor.GetAV("WaitingForPlayer") == 1.0
                akActor.SetAV("WaitingForPlayer", 0)
            EndIf
            dismissFollow.RemoveWaitSandboxPackages(akActor)
            dismissFollow.ClearWaitingFaction(akActor)
            SeverActionsNative.UnregisterSandboxUser(akActor)
        EndIf
        ; The outfit lock is kept here too.
        If sendHome
            ApplyHomeSandboxIfHomed(akActor)
        EndIf

        If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.isNoLongerBeingTracked", ("" + akActor.GetDisplayName())))
        EndIf

        SkyrimNetApi.RegisterShortLivedEvent("follower_dismissed_" + akActor.GetFormID(), \
            "follower_dismissed", \
            akActor.GetDisplayName() + " is no longer traveling with " + Game.GetPlayer().GetDisplayName() + ".", \
            "", 120000, akActor, Game.GetPlayer())

        ; Free our Essential alias slot (SA bookkeeping). The base flag is left
        ; to the owning framework.
        ClearActorEssential(akActor)

        DebugMsg("Unregistered hands-off follower (owned elsewhere, or Tracking mode): " + akActor.GetDisplayName())
        Return

    ; SA's own recruit, in any mode: full cleanup.
    Else
        DebugMsg("SeverActions dismiss: " + akActor.GetDisplayName())

        ; SA's own wait (WaitingForPlayer 1) would make SendHome's schedule alias refuse them.
        If saWaitAtDismiss && akActor.GetAV("WaitingForPlayer") == 1.0
            akActor.SetAV("WaitingForPlayer", 0)
        EndIf

        ; Vanilla DialogueFollower dismiss first, except under SFF: its
        ; DismissFollower ignores akActor and dismisses its inferred target.
        If !SeverActions_FollowerFrameworkLib.HasSFF()
            SeverActions_FollowerFrameworkLib.DismissViaVanillaDialogue(akActor)
        EndIf

        ; Manual cleanup always; the vanilla dismiss may not have run.
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

        ; Restore the original AI values, but never lower the relationship rank
        ; (a lost stored rank must not drop a rank-3 follower to neutral, and
        ; recruiting was a friendly act): max(stored original, current), with a
        ; missing stored value defaulting to the current rank.
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

        ; Restore the original combat style form if we overrode it.
        Form origCSForm = origCSFormAtRecruit
        If origCSForm
            CombatStyle origCS = origCSForm as CombatStyle
            ActorBase dismissBase = akActor.GetActorBase()
            If origCS && dismissBase
                dismissBase.SetCombatStyle(origCS)
            EndIf
            SeverActionsNativeExt.Native_SetOrigCombatStyleForm(akActor, None)
        EndIf

        ; evaluateAfter=false avoids a no-package gap; SendHome evaluates.
        SeverActions_Follow followSys = GetFollowScript()
        If followSys
            followSys.CompanionStopFollowing(akActor, false)
        EndIf
        If sendHome
            SendHome(akActor)
        EndIf
    EndIf

    ; Reset WaitingForPlayer unless a home hold (legacy slot, Route B marker or
    ; schedule alias) is active: ApplyHomeSandbox sets WFP 2, and 0 makes the
    ; engine drop the sandbox on re-evaluation.
    Int homeSlot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)
    If homeSlot < 0 && !GetHomeMarkerB(akActor) && !(SchedSystemActive() && HoldsAnySchedAlias(akActor))
        akActor.SetAV("WaitingForPlayer", 0)
    EndIf

    ; Do NOT clear the outfit lock on a dismiss: the dismissed follower keeps
    ; their row and so their lock (the OTFT orphan purge drops it only once the
    ; row is gone), and the outfit is re-applied at home. Native_Outfit_ClearLock
    ; would wipe the locked items and hand a preset wearer's DefaultOutfit back.
    ; The lock goes in PurgeFollower and the Actions-page soft reset.

    If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.isNoLongerYourCompanion", ("" + akActor.GetDisplayName())))
    EndIf

    SkyrimNetApi.RegisterShortLivedEvent("follower_dismissed_" + akActor.GetFormID(), \
        "follower_dismissed", \
        akActor.GetDisplayName() + " is no longer traveling with " + Game.GetPlayer().GetDisplayName() + ".", \
        "", 120000, akActor, Game.GetPlayer())

    ; Free the Essential alias slot. Unless the NPC's own record is essential,
    ; also clear any legacy base flag SA set.
    ClearActorEssential(akActor)
    If !wasEssentialAtRecruit
        SeverActionsNative.Native_ClearEssential(akActor)
        DebugMsg("Restored non-essential for " + akActor.GetDisplayName())
    EndIf

    DebugMsg("Unregistered follower: " + akActor.GetDisplayName())

    StorageUtil.UnsetIntValue(akActor, "SeverActions_HandsOffAtRecruit")
EndFunction

Bool Function IsRegisteredFollower(Actor akActor)
    {True if the native follower store marks the actor a follower (the single
     source of truth for roster status).}
    If !akActor
        Return false
    EndIf
    Return SeverActionsNativeExt.Native_GetIsFollower(akActor)
EndFunction

Int Function GetFollowerCount()
    {Registered-follower count from the native tracked list (cheap enough for
     the recruit-time cap check).}
    Actor[] tracked = SeverActionsNative.Native_GetAllTrackedFollowers()
    If !tracked
        Return 0
    EndIf
    Int n = 0
    Int i = 0
    While i < tracked.Length
        If tracked[i] && IsRegisteredFollower(tracked[i])
            n += 1
        EndIf
        i += 1
    EndWhile
    Return n
EndFunction

Bool Function CanRecruitMore()
    {True while under the user's MaxFollowers cap; 0 or negative = unlimited.}
    If MaxFollowers <= 0
        Return true
    EndIf
    Return GetFollowerCount() < MaxFollowers
EndFunction

Actor[] Function GetAllFollowers()
    {All registered followers in one native call: isFollower in the native
     store, resolvable, alive, not the player; no duplicates.}
    Return SeverActionsNativeExt.Native_GetActiveFollowerRoster()
EndFunction

Actor[] Function GetDismissedWithHomes()
    {Dismissed NPCs with an assigned home. No internal caller (the MCM's Homes page
     filters itself); kept for old save frames and third-party callers.}
    Actor player = Game.GetPlayer()
    Actor[] result = PapyrusUtil.ActorArray(0)

    Actor[] tracked = SeverActionsNative.Native_GetAllTrackedFollowers()
    If tracked
        Int i = 0
        While i < tracked.Length
            If tracked[i] && tracked[i] != player && !IsRegisteredFollower(tracked[i])
                ; The native tracked list only holds actors with a home.
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
; Rapport/trust/loyalty/mood live only in the native FollowerDataStore. These
; wrappers go straight to it: C++ clamps, and Modify* is atomic under the store's
; mutex, so ticks and LLM callbacks can't race a read-modify-write.

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
    {No-op: Set/Modify write the native store directly. Kept for external callers.}
EndFunction

Function SyncAllRelationshipsOnLoad(Actor[] followers)
    {No-op: native FollowerDataStore is the source of truth from cosave load.}
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
    {Safe-exit stub: moved to SeverActions_CompanionMind.CheckRelationshipAssessments (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionMind, plan P7
EndFunction

Function FireRelationshipAssessment(Actor akActor)
    {Safe-exit stub: moved to SeverActions_CompanionMind.FireRelationshipAssessment (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionMind, plan P7
EndFunction

Function OnRelationshipAssessment(String response, Int success)
    {Safe-exit stub: moved to SeverActions_CompanionMind.OnRelationshipAssessment (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionMind, plan P7
EndFunction

; =============================================================================
; NPC REPUTATION ASSESSMENT (LLM-based, milestone-triggered)
; =============================================================================

Function ProcessNextReputationAssessment()
    {Safe-exit stub: moved to SeverActions_Familiarity.ProcessNextReputationAssessment (P7-02).}
    ; M-I-STUB 3.9.14-beta25 (P7-02): moved to SeverActions_Familiarity, plan P7
EndFunction

Function OnReputationAssessResult(String response, Int success)
    {Safe-exit stub: moved to SeverActions_Familiarity.OnReputationAssessResult (P7-02).}
    ; M-I-STUB 3.9.14-beta25 (P7-02): moved to SeverActions_Familiarity, plan P7
EndFunction

; =============================================================================
; INTER-FOLLOWER RELATIONSHIP ASSESSMENT
; =============================================================================

Function CheckInterFollowerAssessments(Actor[] followers)
    {Safe-exit stub: moved to SeverActions_CompanionMind.CheckInterFollowerAssessments (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionMind, plan P7
EndFunction

Function FireInterFollowerAssessment(Actor akActor, Actor[] followers)
    {Safe-exit stub: moved to SeverActions_CompanionMind.FireInterFollowerAssessment (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionMind, plan P7
EndFunction

Function OnInterFollowerAssessment(String response, Int success)
    {Safe-exit stub: moved to SeverActions_CompanionMind.OnInterFollowerAssessment (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionMind, plan P7
EndFunction

String Function WrapPersistentEvent(String line)
    {Wraps a line as the JSON payload of SkyrimNet's persistent_generic event
     (persistent and reaction-free, unlike custom's 60s TTL), escaped.}
    Return "{\"line\":\"" + SeverActionsNative.EscapeJsonString(line) + "\"}"
EndFunction

Actor Function ResolveFollowerByName(String targetName, Actor[] followers)
    {Safe-exit stub: moved to SeverActions_CompanionMind.ResolveFollowerByName (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionMind, plan P7
    Return None
EndFunction

Function SyncAllPairRelationshipsOnLoad(Actor[] followers)
    {Load-time copy of legacy StorageUtil inter-follower pair data into the
     native store.}
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
                    ; Older saves hold the pair blurb only in StorageUtil.
                    String blurb = StorageUtil.GetStringValue(source, "SeverFollower_Blurb_" + targetFormId, "")
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
    {One-shot migration (sentinel SeverActions_T1BMigrationDone): copies the legacy
     StorageUtil scalars and assess watermarks into FollowerData. A field the
     native store already holds off-default is left alone.}
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
    {One-shot migration (sentinel SeverActions_T1A2MigrationDone): copies the
     CompanionOpinions and LifeEventHistory blobs into FollowerData where the
     native field is still empty.}
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
    {One-shot migration (sentinel SeverActions_T1A3MigrationDone): copies the
     LifeSummary, WorkLocation and PlayLocation labels into FollowerData where the
     native field is still empty.}
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
    {Safe-exit stub: moved to SeverActions_CompanionLife.CheckFollowerBanter (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionLife, plan P7
EndFunction

Function FireFollowerBanter(Actor[] eligible, Int count)
    {Safe-exit stub: moved to SeverActions_CompanionLife.FireFollowerBanter (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionLife, plan P7
EndFunction

Bool Function SpeakingWouldInterruptScene(Actor akSpeaker, Actor akTarget)
    {True when either party is in a running scene. Every gamemaster_dialogue
     emitter that names its own speaker must ask this: a named speaker skips
     SkyrimNet's scene and ActorFilter checks (see CLAUDE.md, speaker filters).}
    If akSpeaker && SeverActionsNative.Native_IsActorInScene(akSpeaker)
        Return true
    EndIf
    If akTarget && SeverActionsNative.Native_IsActorInScene(akTarget)
        Return true
    EndIf
    Return false
EndFunction

Function OnFollowerBanter(String response, Int success)
    {Safe-exit stub: moved to SeverActions_CompanionLife.OnFollowerBanter (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionLife, plan P7
EndFunction

Function RecordBanterTopic(String speakerName, String targetName, String topicText)
    {Safe-exit stub: moved to SeverActions_CompanionLife.RecordBanterTopic (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionLife, plan P7
EndFunction

; =============================================================================
; AMBIENT NPC BANTER — non-follower / non-player pairs in the player's cell
; =============================================================================

Function CheckAmbientBanter()
    {Safe-exit stub: moved to SeverActions_Ambient.CheckAmbientBanter (P7-02).}
    ; M-I-STUB 3.9.14-beta25 (P7-02): moved to SeverActions_Ambient, plan P7
EndFunction

Function FireAmbientBanter(Int pairCount)
    {Safe-exit stub: moved to SeverActions_Ambient.FireAmbientBanter (P7-02).}
    ; M-I-STUB 3.9.14-beta25 (P7-02): moved to SeverActions_Ambient, plan P7
EndFunction

; AMBIENT ACTIONS - moved to SeverActions_Ambient (P7-02); safe-exit stubs below.

Function CheckAmbientAction()
    {Safe-exit stub: moved to SeverActions_Ambient.CheckAmbientAction (P7-02).}
    ; M-I-STUB 3.9.14-beta25 (P7-02): moved to SeverActions_Ambient, plan P7
EndFunction

Function PollAmbientGate()
    {Safe-exit stub: moved to SeverActions_Ambient.PollAmbientGate (P7-02).}
    ; M-I-STUB 3.9.14-beta25 (P7-02): moved to SeverActions_Ambient, plan P7
EndFunction

Function _FinishAmbientGate()
    {Safe-exit stub: moved to SeverActions_Ambient._FinishAmbientGate (P7-02).}
    ; M-I-STUB 3.9.14-beta25 (P7-02): moved to SeverActions_Ambient, plan P7
EndFunction

Function DispatchAmbientAction(Actor akActor, String actionName, String destination, Actor akTarget, \
        String itemName, Int aiQty, Int aiGold, Bool waitForPlayer)
    {Safe-exit stub: moved to SeverActions_Ambient.DispatchAmbientAction (P7-02).}
    ; M-I-STUB 3.9.14-beta25 (P7-02): moved to SeverActions_Ambient, plan P7
EndFunction

; =============================================================================
; OFF-SCREEN LIFE EVENTS
; =============================================================================

Function CheckOffScreenLifeEvents()
    {Safe-exit stub: moved to SeverActions_CompanionLife.CheckOffScreenLifeEvents (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionLife, plan P7
EndFunction

Function FireOffScreenLifeEvent(Actor akActor)
    {Safe-exit stub: moved to SeverActions_CompanionLife.FireOffScreenLifeEvent (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionLife, plan P7
EndFunction

String Function PipeField(String data, Int fieldIndex)
    {Safe-exit stub: moved to SeverActions_CompanionLife.PipeField (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionLife, plan P7
    Return ""
EndFunction

Function AppendGossip(String locationName, String gossipText)
    {Safe-exit stub: moved to SeverActions_CompanionLife.AppendGossip (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionLife, plan P7
EndFunction

Bool Function IsOffScreenExcluded(Actor akActor)
    {Safe-exit stub: moved to SeverActions_CompanionLife.IsOffScreenExcluded (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionLife, plan P7
    Return False
EndFunction

Function SetOffScreenExcluded(Actor akActor, Bool excluded)
    {Safe-exit stub: moved to SeverActions_CompanionLife.SetOffScreenExcluded (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionLife, plan P7
EndFunction

Function ToggleOffScreenExcluded(Actor akActor)
    {Safe-exit stub: moved to SeverActions_CompanionLife.ToggleOffScreenExcluded (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionLife, plan P7
EndFunction

; =============================================================================
; OFF-SCREEN CONSEQUENCES
; =============================================================================

Actor[] Function GetDismissedFollowersInHold(String holdName)
    {Safe-exit stub: moved to SeverActions_CompanionLife.GetDismissedFollowersInHold (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionLife, plan P7
    Return new Actor[1]
EndFunction

Actor Function FindFollowerByName(String targetName)
    {Safe-exit stub: moved to SeverActions_CompanionLife.FindFollowerByName (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionLife, plan P7
    Return None
EndFunction

Faction Function GetCrimeFactionForHoldName(String holdName)
    {Maps a hold or city name (substring match) to its crime faction, resolved from
     Skyrim.esm FormID literals (DR3: never another module's ESP-filled property).
     No internal caller (SeverActions_Arrest has its own); kept for old frames.}
    If holdName == ""
        Return None
    EndIf

    Int fid = 0
    If StringUtil.Find(holdName, "Whiterun") >= 0
        fid = 0x000267EA   ; CrimeFactionWhiterun
    ElseIf StringUtil.Find(holdName, "Riften") >= 0 || StringUtil.Find(holdName, "Rift") >= 0
        fid = 0x0002816B   ; CrimeFactionRift
    ElseIf StringUtil.Find(holdName, "Solitude") >= 0 || StringUtil.Find(holdName, "Haafingar") >= 0
        fid = 0x00029DB0   ; CrimeFactionHaafingar
    ElseIf StringUtil.Find(holdName, "Windhelm") >= 0 || StringUtil.Find(holdName, "Eastmarch") >= 0
        fid = 0x000267E3   ; CrimeFactionEastmarch
    ElseIf StringUtil.Find(holdName, "Markarth") >= 0 || StringUtil.Find(holdName, "Reach") >= 0
        fid = 0x0002816C   ; CrimeFactionReach
    ElseIf StringUtil.Find(holdName, "Falkreath") >= 0
        fid = 0x00028170   ; CrimeFactionFalkreath
    ElseIf StringUtil.Find(holdName, "Dawnstar") >= 0 || StringUtil.Find(holdName, "Pale") >= 0
        fid = 0x0002816E   ; CrimeFactionPale
    ElseIf StringUtil.Find(holdName, "Morthal") >= 0 || StringUtil.Find(holdName, "Hjaalmarch") >= 0
        fid = 0x0002816D   ; CrimeFactionHjaalmarch
    ElseIf StringUtil.Find(holdName, "Winterhold") >= 0
        fid = 0x0002816F   ; CrimeFactionWinterhold
    Else
        Return None
    EndIf
    Return Game.GetFormFromFile(fid, "Skyrim.esm") as Faction
EndFunction

Function ProcessOffScreenConsequence(Actor akActor, String home, String conseqType, Int amount, String reason, String crime)
    {Safe-exit stub: moved to SeverActions_CompanionLife.ProcessOffScreenConsequence (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionLife, plan P7
EndFunction

Function ProcessOffScreenArrest(Actor akActor, String home, String crime, Int bounty)
    {Safe-exit stub: moved to SeverActions_CompanionLife.ProcessOffScreenArrest (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionLife, plan P7
EndFunction

Function ProcessOffScreenBounty(Actor akActor, String home, String crime, Int bounty)
    {Safe-exit stub: moved to SeverActions_CompanionLife.ProcessOffScreenBounty (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionLife, plan P7
EndFunction

Function ProcessOffScreenGoldChange(Actor akActor, Int amount, String reason)
    {Safe-exit stub: moved to SeverActions_CompanionLife.ProcessOffScreenGoldChange (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionLife, plan P7
EndFunction

Function ProcessOffScreenDebt(Actor akActor, Int amount, String reason)
    {Safe-exit stub: moved to SeverActions_CompanionLife.ProcessOffScreenDebt (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionLife, plan P7
EndFunction

Function ProcessOffScreenPurchase(Actor akActor, Int cost, String reason, String itemName, String category, Int count)
    {Safe-exit stub: moved to SeverActions_CompanionLife.ProcessOffScreenPurchase (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionLife, plan P7
EndFunction

Function ProcessOffScreenItemAcquired(Actor akActor, String itemName, String category, Int count)
    {Safe-exit stub: moved to SeverActions_CompanionLife.ProcessOffScreenItemAcquired (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionLife, plan P7
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
    If hour >= SeverActionsNativeExt2.Settings_GetFloat("scheduleWorkStart") && hour < SeverActionsNativeExt2.Settings_GetFloat("scheduleWorkEnd")
        Return SCHEDULE_WORK
    ElseIf hour >= SeverActionsNativeExt2.Settings_GetFloat("schedulePlayStart") && hour < SeverActionsNativeExt2.Settings_GetFloat("schedulePlayEnd")
        Return SCHEDULE_PLAY
    Else
        Return SCHEDULE_HOME
    EndIf
EndFunction

Bool Function HourInWindow(Float h, Float s, Float e)
    {True when game hour h falls inside the [s, e) window. 0-24 covers the
     whole day; s > e wraps midnight (night shift, e.g. 22 -> 6). s == e is
     an empty window unless it is the 0/24 full-day form.}
    If s <= 0.0 && e >= 24.0
        Return true
    EndIf
    If s < e
        Return h >= s && h < e
    ElseIf s > e
        Return h >= s || h < e
    EndIf
    Return false
EndFunction

Int Function DetermineScheduleTypeFor(Actor akActor)
    {Per-actor schedule type. A work-hours override (FLWD v17) replaces only the
     global work window; work is tested before play, so an overlap means work.
     No override = DetermineScheduleTypeForNow().}
    If akActor
        Float oStart = SeverActionsNativeExt.Native_GetWorkHoursOverrideStart(akActor)
        Float oEnd   = SeverActionsNativeExt.Native_GetWorkHoursOverrideEnd(akActor)
        If oStart >= 0.0 && oEnd >= 0.0
            Float hour = GetCurrentGameHour()
            If HourInWindow(hour, oStart, oEnd)
                Return SCHEDULE_WORK
            ElseIf hour >= SeverActionsNativeExt2.Settings_GetFloat("schedulePlayStart") && hour < SeverActionsNativeExt2.Settings_GetFloat("schedulePlayEnd")
                Return SCHEDULE_PLAY
            EndIf
            Return SCHEDULE_HOME
        EndIf
    EndIf
    Return DetermineScheduleTypeForNow()
EndFunction

ObjectReference Function GetScheduleAnchorForNPC(Actor akActor, Int slot, Int scheduleType)
    {The anchor HomeMarker_NN should sit on now: the work or play loc in those
     hours (None when it is unset, so the swap is skipped), else TrueHomeAnchor_NN.}
    If scheduleType == SCHEDULE_WORK
        ObjectReference workMarker = SeverActionsNative.Native_GetWorkLoc(akActor)
        If workMarker
            Return workMarker
        EndIf
        ; No home fallback: the caller would log a work swap while the marker
        ; went home. None skips the swap (retried next tick). Usual cause: the
        ; workLoc failed to resolve on load.
        DebugMsg("ScheduleAnchor: WORK swap skipped for " + akActor.GetDisplayName() + " — no work loc (resolve failed on load?)")
        Return None
    ElseIf scheduleType == SCHEDULE_PLAY
        ObjectReference playMarker = SeverActionsNative.Native_GetPlayLoc(akActor)
        If playMarker
            Return playMarker
        EndIf
        DebugMsg("ScheduleAnchor: PLAY swap skipped for " + akActor.GetDisplayName() + " — no play loc (resolve failed on load?)")
        Return None
    EndIf
    ; Home fallback — use TrueHomeAnchor_NN
    If TrueHomeAnchorList && slot >= 0 && slot < 40
        Return TrueHomeAnchorList.GetAt(slot) as ObjectReference
    EndIf
    Return None
EndFunction

; Route B work-pool helpers
Form WorkMarkerBaseCache   ; XMarkerHeading STAT, resolved lazily

Form Function GetWorkMarkerBase()
    If !WorkMarkerBaseCache
        WorkMarkerBaseCache = Game.GetFormFromFile(0x00000034, "Skyrim.esm")  ; XMarkerHeading
    EndIf
    Return WorkMarkerBaseCache
EndFunction

Package WorkSandboxPackageCache
Keyword WorkAnchorKeywordCache

Package Function GetWorkSandboxPackage()
    {The r1200 work sandbox package (0x165676, GenerateWorkSandbox.pas); None if
     the ESP lacks it.}
    If !WorkSandboxPackageCache
        WorkSandboxPackageCache = Game.GetFormFromFile(0x00165676, "SeverActions.esp") as Package
    EndIf
    Return WorkSandboxPackageCache
EndFunction

Keyword Function GetWorkAnchorKeyword()
    {The work-marker linked-ref keyword (0x165675); None if the ESP lacks it.}
    If !WorkAnchorKeywordCache
        WorkAnchorKeywordCache = Game.GetFormFromFile(0x00165675, "SeverActions.esp") as Keyword
    EndIf
    Return WorkAnchorKeywordCache
EndFunction

Package WorkGuardPackageCache

Package Function GetWorkGuardPackage()
    {SeverActions_GuardBodyguard (0x165677, GenerateGuardFollow.pas): a clone of
     FollowGuard_Prisoner that follows the GetGuardAnchorKeyword link (the protectee),
     sheathed, radius 300/400, through load doors. Its gait is the engine's default
     follow speed (the .pas could not set Preferred Speed). The arrest scrub
     (SeverActions_Arrest.ClearStaleArrestState) spares bodyguards.}
    If !WorkGuardPackageCache
        WorkGuardPackageCache = Game.GetFormFromFile(0x00165677, "SeverActions.esp") as Package
    EndIf
    Return WorkGuardPackageCache
EndFunction

Keyword GuardAnchorKeywordCache

Keyword Function GetGuardAnchorKeyword()
    {FollowTargetKW (0x030155), the arrest follow keyword; the bodyguard package
     follows whatever it links to. Separate from WorkAnchorKW so the modes never collide.}
    If !GuardAnchorKeywordCache
        GuardAnchorKeywordCache = Game.GetFormFromFile(0x00030155, "SeverActions.esp") as Keyword
    EndIf
    Return GuardAnchorKeywordCache
EndFunction

Package Function GetActiveWorkPackage(Actor akActor)
    {Pick the work package for this retainer: the tight bodyguard package when the
     work target is an Actor (protect-a-person), else the roam-the-workplace sandbox.}
    If (SeverActionsNative.Native_GetWorkLoc(akActor) as Actor)
        Return GetWorkGuardPackage()
    EndIf
    Return GetWorkSandboxPackage()
EndFunction

Function GuardNPC(Actor akActor, Actor akProtectee)
    {Protect-a-person work assignment: links the retainer to the protectee, sets Ally
     rank so they defend them, and applies the guard package in work hours. The
     protectee IS the work loc; guard mode = Native_GetWorkLoc returns an Actor.}
    If !akActor || !akProtectee
        Return
    EndIf
    _EndGuardAssignment(akActor)
    Keyword followKw = GetGuardAnchorKeyword()
    If followKw
        ; Permanent, so the 30-day staleness prune never cuts the protectee link.
        SeverActionsNativeExt.LinkedRef_SetPermanent(akActor, akProtectee, followKw)
    Else
        DebugMsg("GuardNPC: guard follow keyword not found. Guard inactive for " + akActor.GetDisplayName())
    EndIf
    SeverActionsNative.Native_SetWorkLoc(akActor, akProtectee)
    SeverActionsNativeExt.Native_SetWorkLocationName(akActor, "protecting " + akProtectee.GetDisplayName())
    ; Ally rank (3) → a helps-allies combat NPC (guards/mercs) defends their charge.
    akActor.SetRelationshipRank(akProtectee, 3)
    ; Stray hits from the player and the party pass over them while on duty (FollowerProtection).
    akActor.IgnoreFriendlyHits(true)

    If GetAssignedHome(akActor) == ""
        If !StorageUtil.FormListHas(None, KEY_WORK_ONLY_NPCS, akActor as Form)
            StorageUtil.FormListAdd(None, KEY_WORK_ONLY_NPCS, akActor as Form, false)
        EndIf
        StorageUtil.SetIntValue(akActor, KEY_TRUEHOME_MIGRATED, 1)
    EndIf

    StorageUtil.SetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, -99)
    If DetermineScheduleTypeFor(akActor) == SCHEDULE_WORK
        If SchedSystemActive()
            ReconcileSchedAliasesFor(akActor)   ; fills WORK alias + guard assist
        Else
            ApplyWorkSandbox(akActor)   ; picks WorkGuard via GetActiveWorkPackage
        EndIf
        StorageUtil.SetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, SCHEDULE_WORK)
    EndIf

    DebugMsg("GuardNPC: " + akActor.GetDisplayName() + " now protects " + akProtectee.GetDisplayName())
    If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.willProtectDuringWork", ("" + akActor.GetDisplayName()), ("" + akProtectee.GetDisplayName())))
    EndIf
EndFunction

ObjectReference Function EnsureWorkMarker(Actor akActor, ObjectReference akTarget)
    {Returns the actor's work marker: the stored one moved to akTarget, or a new
     force-persistent XMarkerHeading placed there and stored per actor.}
    If !akActor || !akTarget
        Return None
    EndIf
    ObjectReference marker = StorageUtil.GetFormValue(akActor, KEY_WORK_MARKER) as ObjectReference
    If marker
        marker.MoveTo(akTarget)
        ; A retainer's premises follow the work marker (the owned cell holding it,
        ; else none). Every placement comes through here: the one sync point.
        SeverActionsNativeExt2.Venture_SyncPremisesFromWork(akActor, marker)
        Return marker
    EndIf
    Form base = GetWorkMarkerBase()
    If !base
        Return None
    EndIf
    marker = akTarget.PlaceAtMe(base, 1, true, false)   ; abForcePersist = true
    If marker
        StorageUtil.SetFormValue(akActor, KEY_WORK_MARKER, marker)
        SeverActionsNativeExt2.Venture_SyncPremisesFromWork(akActor, marker)
    EndIf
    Return marker
EndFunction

Function ApplyWorkSandbox(Actor akActor)
    {Applies the work package override (or, with the schedule system active, fills
     the WORK alias). Touches only our own override, so it is safe on track-only
     workers; never applied over an active follower. Undone by RemoveWorkSandbox.}
    ; Jail gate: the work package ties PrisonerSandBox's priority 110, so a jailed
    ; worker would walk out to work. Work resumes after RemoveJailedNPC. The same for
    ; a guard making an arrest (_IsMakingArrest), whose packages the work hold outranks,
    ; and for a traveler (_OnJourney).
    If akActor && (SeverActionsNativeExt.Native_Jailed_IsJailed(akActor) || _IsMakingArrest(akActor) || _OnJourney(akActor))
        Return
    EndIf
    If SchedSystemActive()
        FillSchedAlias(akActor, SCHEDULE_WORK)
        Return
    EndIf
    Package workPkg = GetActiveWorkPackage(akActor)
    If !akActor || !workPkg
        Return
    EndIf
    ; Covers casual followers, who are not teammates, so the check below misses them.
    If IsActorActivelyFollowing(akActor)
        DebugMsg("ApplyWorkSandbox: SKIPPED - " + akActor.GetDisplayName() + " is actively following (corroborated)")
        Return
    EndIf
    If IsRegisteredFollower(akActor) && akActor.IsPlayerTeammate() && akActor.GetAV("WaitingForPlayer") != -1.0
        Return
    EndIf
    ; A player 'wait here' (WFP 1) is never turned into a work shift.
    If akActor.GetAV("WaitingForPlayer") == 1.0
        Return
    EndIf
    ; 110 outranks stubborn vanilla schedule packages; WFP 2 marks a work shift.
    ActorUtil.AddPackageOverride(akActor, workPkg, 110, 1)
    akActor.SetAV("WaitingForPlayer", 2)
    akActor.EvaluatePackage()
EndFunction

Function RemoveWorkSandbox(Actor akActor)
    {Removes the work overrides and the WORK alias so the NPC falls back to their
     home schedule or native AI.}
    If !akActor
        Return
    EndIf
    ; Both: the mode (sandbox or guard) may have changed since the apply.
    Package sandboxPkg = GetWorkSandboxPackage()
    Package guardPkg = GetWorkGuardPackage()
    If sandboxPkg
        ActorUtil.RemovePackageOverride(akActor, sandboxPkg)
    EndIf
    If guardPkg
        ActorUtil.RemovePackageOverride(akActor, guardPkg)
    EndIf
    ; Clear our WFP 2 stamp or WFP-conditioned packages read a phantom wait
    ; forever; left alone while a home or a relax alias holds the actor.
    If akActor.GetAV("WaitingForPlayer") == 2.0
        If SeverActionsNative.Native_GetHomeMarkerSlot(akActor) < 0 && !GetHomeMarkerB(akActor) \
            && !(SchedSystemActive() && SeverActionsNativeExt.Native_GetSchedAliasIndex(akActor, SCHEDULE_PLAY) >= 0)
            akActor.SetAV("WaitingForPlayer", 0)
        EndIf
    EndIf
    If SchedSystemActive()
        EmptySchedAlias(akActor, SCHEDULE_WORK)
    EndIf
    akActor.EvaluatePackage()
EndFunction

Function StripScheduleForJail(Actor akActor)
    {Takes a just-jailed worker, or a retainer going on an arrest or dispatch as its
     guard, off the schedule (the "jailStrip" service: Arrest's AddJailedNPCAt and
     _GuardOffSchedule; SchedAliasStepFor's jail gate): empties their schedule aliases,
     drops the work overrides that tie PrisonerSandBox's 110 (an override outranks
     every alias), and resets the schedule cursor. The work
     assignment is kept; work resumes after RemoveJailedNPC, or once the guard's part
     in the arrest ends (_IsMakingArrest). Idempotent.}
    If !akActor
        Return
    EndIf
    If SchedSystemActive()
        EmptyAllSchedAliases(akActor)
    EndIf
    ; Its closing EvaluatePackage re-selects the jail hold.
    RemoveWorkSandbox(akActor)
    StorageUtil.SetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, -99)
EndFunction

Bool Function _IsMakingArrest(Actor akActor)
    {True while akActor is the guard of a live arrest or dispatch, until their part ends
     (the jailing, a release, a cancel). The schedule holds nothing then, since a
     work shift outranks the arrest packages; the prisoner and a dispatch target keep
     theirs (jail strips it).}
    Return SeverActionsNativeExt2.Native_ArrestSession_IsGuardOnTask(akActor)
EndFunction

Bool Function _OnJourney(Actor akActor)
    {True while akActor has a live journey, on the road or waiting at its destination. The
     schedule, home and work holds stay off it: they outrank the walk, and the trip is a
     deliberate order that only a cancel or a follow order ends.}
    Return akActor && SeverActionsNativeExt2.Travel_GetPhaseByActor(akActor) > 0
EndFunction

Function ClearWorkSandboxForFollow(Actor akActor)
    {On any follow start: drops the work package (110 outranks follow) and resets
     the schedule cursor so a later dismiss re-applies work in work hours. The work
     assignment is kept. Safe on any actor.}
    If !akActor
        Return
    EndIf
    ; Our follow package needs WFP 0; clear only our work-shift 2, never another
    ; path's follow/wait value.
    If akActor.GetAV("WaitingForPlayer") == 2.0
        akActor.SetAV("WaitingForPlayer", 0.0)
    EndIf
    RemoveWorkSandbox(akActor)
    StorageUtil.SetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, -99)
EndFunction

Function StripSandboxesForFollow(Actor akActor)
    {On any follow start: drops every SA sandbox override that outranks the follow
     package (~50): home (100), Route B play (105), safe-interior (100), furniture
     (80). The work sandbox is ClearWorkSandboxForFollow's and the schedule aliases
     EmptySchedAliasesForFollow's. No-op when inactive; assignments are kept and
     re-apply once follow ends.}
    If !akActor
        Return
    EndIf
    RemoveHomeSandbox(akActor)
    RemovePlaySandboxB(akActor)
    ; The light strip: no teleport or follow re-registration (the caller starts follow).
    SeverActions_Follow followSys = GetFollowScript()
    If followSys
        followSys.StripSafeInteriorForFollow(akActor)
    EndIf
    ; Only when using furniture (seated or on the way), or every follow start fires a
    ; spurious furniture_stopped.
    If SeverActions_FurnitureLib.IsUsing(akActor)
        SeverActions_FurnitureLib.Stop(akActor)
    EndIf
EndFunction

; Cached SeverActions_ActivelyFollowing (0x0F0809); the schedule tick asks per NPC.
Faction _afFaction = None

Faction Function GetActivelyFollowingFaction()
    {Resolve-once accessor for the cached ActivelyFollowing faction. Retried
     while null so an outdated ESP can't cache a permanent failure.}
    If !_afFaction
        _afFaction = Game.GetFormFromFile(0x0F0809, "SeverActions.esp") as Faction
    EndIf
    Return _afFaction
EndFunction

Bool Function IsActorActivelyFollowing(Actor akActor)
    {True if the actor follows the player now, casual or companion. The schedule
     apply/reinforce paths gate on it (a casual follower is not a teammate). The
     ActivelyFollowing faction alone is not trusted: a stale membership survives a
     dismiss and would freeze a homed NPC's work schedule, so it needs live
     corroboration (teammate, roster, follow-pool slot or FollowPlayer package).}
    If !akActor
        Return false
    EndIf
    Faction af = GetActivelyFollowingFaction()
    If !af || !akActor.IsInFaction(af)
        Return false
    EndIf
    If akActor.IsPlayerTeammate() || IsRegisteredFollower(akActor)
        Return true
    EndIf
    ; Casual follow sits in a pool slot; the FollowPlayer package is only the
    ; pool-exhaustion fallback (mirrors Follow.HasFollowPackage).
    SeverActions_Follow fs = GetFollowScript()
    If fs && fs.IsInFollowerSlot(akActor)
        Return true
    EndIf
    Return SkyrimNetApi.HasPackage(akActor, "FollowPlayer")
EndFunction

Function ReinforceWorkPackage(Actor akActor)
    {Re-applies the work package each work tick for an NPC on shift: a greeting or
     scene can pull them off it and the engine never returns on its own. No-op when
     already on it or in combat; an active greeting still finishes first.}
    If !akActor || akActor.IsInCombat()
        Return
    EndIf
    ; Jail gate: see ApplyWorkSandbox.
    If SeverActionsNativeExt.Native_Jailed_IsJailed(akActor) || _IsMakingArrest(akActor) || _OnJourney(akActor)
        Return
    EndIf
    Package workPkg = GetActiveWorkPackage(akActor)
    If !workPkg || akActor.GetCurrentPackage() == workPkg
        Return
    EndIf
    ; Don't disturb anyone actively following the player — casual OR companion.
    If IsActorActivelyFollowing(akActor)
        DebugMsg("ReinforceWorkPackage: SKIPPED - " + akActor.GetDisplayName() + " is actively following (corroborated)")
        Return
    EndIf
    ; Don't disturb a registered companion the player is actively running.
    If IsRegisteredFollower(akActor) && akActor.IsPlayerTeammate() && akActor.GetAV("WaitingForPlayer") != -1.0
        Return
    EndIf
    ; A player 'wait here' (WFP 1) is never turned into a work shift.
    If akActor.GetAV("WaitingForPlayer") == 1.0
        Return
    EndIf
    ActorUtil.AddPackageOverride(akActor, workPkg, 110, 1)
    akActor.EvaluatePackage()
EndFunction

String Function ResolveRoutineLocName(ObjectReference target, String asNameOverride)
    {Human-readable place name for a routine marker: caller override wins, else the
     target's Location (city/landmark), else parent cell, else a generic label.}
    String locName = asNameOverride
    If locName == "" && target
        Location tgtLoc = target.GetCurrentLocation()
        If tgtLoc
            locName = tgtLoc.GetName()
        EndIf
        If locName == ""
            Cell tgtCell = target.GetParentCell()
            If tgtCell
                locName = tgtCell.GetName()
            EndIf
        EndIf
    EndIf
    If locName == ""
        locName = "a familiar spot"
    EndIf
    Return locName
EndFunction

Function SetRoutineLocHere(Actor akActor, String kind, ObjectReference akDest = None, String asNameOverride = "")
    {Places the Work or Play marker (kind "work"/"play") at akDest, else at the
     player. asNameOverride sets the location name (blank = target's location/cell).
     WORK needs no home: a force-persistent marker linked by WorkAnchorKeyword; the
     SchedWork alias pool enforces the hours (the work override when the schedule
     system is off). A home-less NPC with a work or relax spot goes in
     KEY_WORK_ONLY_NPCS. PLAY: the same pattern with PlayAnchorKW and the SchedRelax
     pool. No home is needed once the schedule pools run (a home-less NPC relaxes in
     the relax window and is her own AI otherwise); Route B still needs one.}
    If !akActor
        Return
    EndIf

    ; WORK
    If kind == "work"
        Bool hadHome = (GetAssignedHome(akActor) != "")
        ObjectReference target = akDest
        If target
            ; A named interior resolves to its exterior door (the interior is not
            ; loaded); follow the door inside. None for anything but a door.
            ObjectReference inside = SeverActionsNative.FindInteriorMarkerForDoor(target)
            If inside
                target = inside
            EndIf
        Else
            target = Game.GetPlayer()
        EndIf
        ObjectReference workMarker = EnsureWorkMarker(akActor, target)
        If !workMarker
            DebugMsg("SetRoutineLocHere: failed to spawn work marker for " + akActor.GetDisplayName())
            Return
        EndIf
        _EndGuardAssignment(akActor)
        ; The link is cosaved in LREF. Without the ESP keyword only the link is
        ; skipped; the work loc and its name still register for prompts.
        Keyword workKw = GetWorkAnchorKeyword()
        If workKw
            ; Permanent: must survive the LREF 30-day staleness prune.
            SeverActionsNativeExt.LinkedRef_SetPermanent(akActor, workMarker, workKw)
        Else
            DebugMsg("SetRoutineLocHere(work): work keyword not found - run GenerateWorkSandbox.pas. Work sandbox inactive for " + akActor.GetDisplayName())
        EndIf
        SeverActionsNative.Native_SetWorkLoc(akActor, workMarker)
        String workName = ResolveRoutineLocName(target, asNameOverride)
        SeverActionsNativeExt.Native_SetWorkLocationName(akActor, workName)

        _RelistRoutine(akActor)
        If !hadHome
            ; No off-hours path may teleport a home-less NPC anywhere.
            StorageUtil.SetIntValue(akActor, KEY_TRUEHOME_MIGRATED, 1)
        EndIf

        ; Re-evaluate on the next tick, and apply now if it is already work hours.
        StorageUtil.SetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, -99)
        If DetermineScheduleTypeFor(akActor) == SCHEDULE_WORK
            If SchedSystemActive()
                ReconcileSchedAliasesFor(akActor)
            Else
                ApplyWorkSandbox(akActor)
            EndIf
            StorageUtil.SetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, SCHEDULE_WORK)
        EndIf

        DebugMsg("Set work location for " + akActor.GetDisplayName() + " (" + workName + ")")
        If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.willSpendWorkHoursHere", ("" + akActor.GetDisplayName())))
        EndIf
        Return
    EndIf

    ; PLAY
    If kind != "play"
        Return
    EndIf
    ; Route B's play override needs a home (a legacy slot or an anchor marker); the relax pool does not.
    If GetAssignedHome(akActor) == "" && !SchedSystemActive()
        DebugMsg("SetRoutineLocHere: " + akActor.GetDisplayName() + " has no home - assign home first")
        Return
    EndIf

    ObjectReference playTarget = akDest
    If playTarget
        ; Follow a door destination inside, as for work.
        ObjectReference insideP = SeverActionsNative.FindInteriorMarkerForDoor(playTarget)
        If insideP
            playTarget = insideP
        EndIf
    Else
        playTarget = Game.GetPlayer()
    EndIf

    ; Move the existing play marker (runtime-placed or a legacy PlayMarkerList
    ; one), else place one.
    ObjectReference playMarker = SeverActionsNative.Native_GetPlayLoc(akActor)
    If playMarker
        playMarker.MoveTo(playTarget)
    Else
        Static xmPlay = Game.GetFormFromFile(0x00003B, "Skyrim.esm") as Static
        If xmPlay
            playMarker = playTarget.PlaceAtMe(xmPlay, 1, true, false)
        EndIf
        If playMarker
            StorageUtil.SetIntValue(akActor, KEY_PLAYB_RUNTIME, 1)
        EndIf
    EndIf
    If !playMarker
        DebugMsg("SetRoutineLocHere: failed to place play marker for " + akActor.GetDisplayName())
        Return
    EndIf

    Keyword playKwSet = GetPlayBAnchorKeyword()
    If playKwSet
        SeverActionsNativeExt.LinkedRef_SetPermanent(akActor, playMarker, playKwSet)
    Else
        DebugMsg("SetRoutineLocHere(play): PlayAnchorKW missing (old ESP?) - play sandbox inactive")
    EndIf
    SeverActionsNative.Native_SetPlayLoc(akActor, playMarker)
    String locName = ResolveRoutineLocName(playTarget, asNameOverride)
    ; Read by the sever_play_location decorator.
    SeverActionsNativeExt.Native_SetPlayLocationName(akActor, locName)
    _RelistRoutine(akActor)
    If GetAssignedHome(akActor) == ""
        StorageUtil.SetIntValue(akActor, KEY_TRUEHOME_MIGRATED, 1)
    EndIf

    ; Re-evaluate on the next tick, and apply now if it is already play hours.
    StorageUtil.SetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, -99)
    If DetermineScheduleTypeFor(akActor) == SCHEDULE_PLAY && !IsRegisteredFollower(akActor)
        If SchedSystemActive()
            ReconcileSchedAliasesFor(akActor)
        Else
            ApplyPlaySandboxB(akActor)
        EndIf
        StorageUtil.SetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, SCHEDULE_PLAY)
    EndIf

    DebugMsg("Set play location for " + akActor.GetDisplayName() + " (" + locName + ")")
    If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
        ; UI calls it "Relax" which is clearer to users; internal kind stays "play".
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.willSpendRelaxHoursHere", ("" + akActor.GetDisplayName())))
    EndIf
EndFunction

Function _EndGuardAssignment(Actor akActor)
    {Undoes GuardNPC while the work target still names the protectee: the Ally bond, the
     protectee link and the friendly-hit flag (kept for a rostered follower or a teammate).
     Call before the work target is replaced or cleared.}
    Actor exProtectee = SeverActionsNative.Native_GetWorkLoc(akActor) as Actor
    If !exProtectee
        Return
    EndIf
    akActor.SetRelationshipRank(exProtectee, 0)
    If !IsRegisteredFollower(akActor) && !akActor.IsPlayerTeammate()
        akActor.IgnoreFriendlyHits(false)
    EndIf
    Keyword guardKw = GetGuardAnchorKeyword()
    If guardKw
        SeverActionsNative.LinkedRef_Clear(akActor, guardKw)
    EndIf
EndFunction

Function ClearRoutineLoc(Actor akActor, String kind)
    {Clears the Work or Play location (kind "work"/"play"): the override, the link,
     and any marker we placed (a legacy PlayMarkerList marker stays).}
    If !akActor
        Return
    EndIf
    If kind == "work"
        _EndGuardAssignment(akActor)
        SeverActionsNative.Native_ClearWorkLoc(akActor)
        StorageUtil.UnsetStringValue(akActor, "SeverFollower_WorkLocation")
        ; Teardown: override, link, then the placed marker (deleted, or it leaks as
        ; a persistent ref).
        RemoveWorkSandbox(akActor)
        Keyword workKwClear = GetWorkAnchorKeyword()
        If workKwClear
            SeverActionsNative.LinkedRef_Clear(akActor, workKwClear)
        EndIf
        ; Guard mode links via the follow keyword instead — clear that too.
        Keyword followKwClear = GetGuardAnchorKeyword()
        If followKwClear
            SeverActionsNative.LinkedRef_Clear(akActor, followKwClear)
        EndIf
        ObjectReference workMarker = StorageUtil.GetFormValue(akActor, KEY_WORK_MARKER) as ObjectReference
        If workMarker
            workMarker.Delete()
            StorageUtil.UnsetFormValue(akActor, KEY_WORK_MARKER)
        EndIf
        ; No work site, no premises.
        SeverActionsNativeExt2.Venture_SyncPremisesFromWork(akActor, None)
        _RelistRoutine(akActor)   ; a remaining relax spot keeps her listed
    ElseIf kind == "play"
        ; Delete the marker only if we placed it (legacy ones belong to PlayMarkerList).
        RemovePlaySandboxB(akActor)
        Keyword playKwClear = GetPlayBAnchorKeyword()
        If playKwClear
            SeverActionsNative.LinkedRef_Clear(akActor, playKwClear)
        EndIf
        If StorageUtil.GetIntValue(akActor, KEY_PLAYB_RUNTIME, 0) == 1
            ObjectReference playMarkerClr = SeverActionsNative.Native_GetPlayLoc(akActor)
            If playMarkerClr
                playMarkerClr.Disable()
                playMarkerClr.Delete()
            EndIf
            StorageUtil.UnsetIntValue(akActor, KEY_PLAYB_RUNTIME)
        EndIf
        SeverActionsNative.Native_ClearPlayLoc(akActor)
        _RelistRoutine(akActor)
        StorageUtil.UnsetStringValue(akActor, "SeverFollower_PlayLocation")
    EndIf
    StorageUtil.SetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, -99)
    DebugMsg("Cleared " + kind + " location for " + akActor.GetDisplayName())
EndFunction

Function EnsureTrueHomeAnchorMigrated(Actor npc, Int slot)
    {One-shot per NPC: moves TrueHomeAnchor_NN onto HomeMarker_NN. On older saves
     the anchor still sits in the aaaMarkers holding cell, and the first schedule tick
     would teleport the follower there. Idempotent.}
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

Function ProcessScheduleSwapsRouteB()
    {Pre-migration path only (the alias era uses ProcessScheduleSwapsAliases). On a
     schedule-type change, moves each dismissed homed NPC's HomeMarker_NN onto the
     right anchor; their HomeSandbox_NN alias package follows the marker. Also runs
     the one-shot TrueHomeAnchor migration.}
    If !HomeMarkerList
        Return
    EndIf
    Int targetType = DetermineScheduleTypeForNow()
    Int count = StorageUtil.FormListCount(None, KEY_HOMED_NPCS)

    Int i = 0
    While i < count
        Form entry = StorageUtil.FormListGet(None, KEY_HOMED_NPCS, i)
        Actor npc = entry as Actor
        ; Dismissed = not registered, not just not a teammate: a track-only
        ; follower can follow without the teammate flag and would be dragged
        ; home mid-follow.
        If npc && !npc.IsDeleted() && !npc.IsPlayerTeammate() && !IsRegisteredFollower(npc)
            ; Self-heal: on a dismissed NPC the ActivelyFollowing faction is a stale
            ; leftover that blocks the work guards. A live casual follower keeps it:
            ; FollowPlayer package, or a follow-pool slot (which has no package).
            Faction afFact = GetActivelyFollowingFaction()
            SeverActions_Follow fsHeal = GetFollowScript()
            If afFact && npc.IsInFaction(afFact) && !SkyrimNetApi.HasPackage(npc, "FollowPlayer") && !(fsHeal && fsHeal.IsInFollowerSlot(npc))
                npc.RemoveFromFaction(afFact)
                DebugMsg("ScheduleSwap: cleared stale ActivelyFollowing faction from dismissed " + npc.GetDisplayName())
            EndIf
            Int slot = SeverActionsNative.Native_GetHomeMarkerSlot(npc)
            If slot >= 0
                ; Before any swap, or HomeMarker moves to an anchor still in the holding cell.
                EnsureTrueHomeAnchorMigrated(npc, slot)

                Int lastType = StorageUtil.GetIntValue(npc, KEY_LAST_SCHEDULED_TYPE, -99)
                If lastType != targetType
                    ObjectReference homeMarker = HomeMarkerList.GetAt(slot) as ObjectReference
                    ObjectReference targetAnchor = GetScheduleAnchorForNPC(npc, slot, targetType)
                    If homeMarker && targetAnchor
                        homeMarker.MoveTo(targetAnchor)
                        ; A homed worker gets the work override (it outranks the home
                        ; sandbox) in work hours only.
                        If SeverActionsNative.Native_GetWorkLoc(npc)
                            If targetType == SCHEDULE_WORK
                                ApplyWorkSandbox(npc)
                            Else
                                RemoveWorkSandbox(npc)
                            EndIf
                        EndIf
                        ; Play layers the same way in play hours.
                        If SeverActionsNative.Native_GetPlayLoc(npc)
                            If targetType == SCHEDULE_PLAY
                                ApplyPlaySandboxB(npc)
                            Else
                                RemovePlaySandboxB(npc)
                            EndIf
                        EndIf
                        StorageUtil.SetIntValue(npc, KEY_LAST_SCHEDULED_TYPE, targetType)
                        npc.EvaluatePackage()
                        DebugMsg("ScheduleSwap: " + npc.GetDisplayName() + " -> type " + targetType + " (slot " + slot + ")")
                    EndIf
                ElseIf targetType == SCHEDULE_WORK && SeverActionsNative.Native_GetWorkLoc(npc)
                    ; On shift: keep them on the package through greetings and scenes.
                    ReinforceWorkPackage(npc)
                EndIf
            ElseIf GetHomeMarkerB(npc)
                ; Route B home: the marker never moves; work (110) and play (105)
                ; overrides outrank the constant home override (100) in their hours.
                Int lastTypeB = StorageUtil.GetIntValue(npc, KEY_LAST_SCHEDULED_TYPE, -99)
                If lastTypeB != targetType
                    If SeverActionsNative.Native_GetWorkLoc(npc)
                        If targetType == SCHEDULE_WORK
                            ApplyWorkSandbox(npc)
                        Else
                            RemoveWorkSandbox(npc)
                        EndIf
                    EndIf
                    If SeverActionsNative.Native_GetPlayLoc(npc)
                        If targetType == SCHEDULE_PLAY
                            ApplyPlaySandboxB(npc)
                        Else
                            RemovePlaySandboxB(npc)
                        EndIf
                    EndIf
                    StorageUtil.SetIntValue(npc, KEY_LAST_SCHEDULED_TYPE, targetType)
                    npc.EvaluatePackage()
                    DebugMsg("ScheduleSwap(B): " + npc.GetDisplayName() + " -> type " + targetType)
                ElseIf targetType == SCHEDULE_WORK && SeverActionsNative.Native_GetWorkLoc(npc)
                    ReinforceWorkPackage(npc)
                EndIf
            EndIf
        ElseIf npc && !npc.IsDeleted() && IsRegisteredFollower(npc)
            ; A registered follower never carries a schedule sandbox; strip one an
            ; older build left. A cursor other than -99 means a swap was applied;
            ; resetting it to -99 keeps this one-shot per NPC.
            If StorageUtil.GetIntValue(npc, KEY_LAST_SCHEDULED_TYPE, -99) != -99
                RemoveHomeSandbox(npc)
                RemovePlaySandboxB(npc)
                RemoveWorkSandbox(npc)
                StorageUtil.SetIntValue(npc, KEY_LAST_SCHEDULED_TYPE, -99)
                npc.EvaluatePackage()
                DebugMsg("ScheduleSwap: stripped stale home/play/work sandbox from registered follower " + npc.GetDisplayName())
            EndIf
        EndIf
        i += 1
    EndWhile
EndFunction

Function ProcessWorkOnlySwapsRouteB()
    {Pre-migration path only (the alias era uses ProcessWorkOnlySwapsAliases).
     Work-only NPCs (a work marker, no home) get the work override in work hours and
     native AI otherwise, keyed on KEY_LAST_SCHEDULED_TYPE. They are not in
     KEY_HOMED_NPCS, so ProcessScheduleSwapsRouteB never touches them.}
    Bool isWorkHours = (DetermineScheduleTypeForNow() == SCHEDULE_WORK)
    Int desired = SCHEDULE_HOME
    If isWorkHours
        desired = SCHEDULE_WORK
    EndIf

    Int count = StorageUtil.FormListCount(None, KEY_WORK_ONLY_NPCS)
    Int i = 0
    While i < count
        Form entry = StorageUtil.FormListGet(None, KEY_WORK_ONLY_NPCS, i)
        Actor npc = entry as Actor
        Bool pruned = false
        ; Same track-only guard as ProcessScheduleSwapsRouteB.
        If npc && !npc.IsDeleted() && !npc.IsPlayerTeammate() && !IsRegisteredFollower(npc)
            ; The global list can outlive a load of another save in the same
            ; session; the cosaved work loc is the truth. None here = stale entry.
            If SeverActionsNative.Native_GetWorkLoc(npc) == None
                RemoveWorkSandbox(npc)
                StorageUtil.FormListRemove(None, KEY_WORK_ONLY_NPCS, npc as Form, true)
                StorageUtil.UnsetIntValue(npc, KEY_LAST_SCHEDULED_TYPE)
                count -= 1
                pruned = true
                DebugMsg("WorkOnlySwap: pruned " + npc.GetDisplayName() + " - no native work assignment this save (stale global-list entry)")
            Else
                Int lastType = StorageUtil.GetIntValue(npc, KEY_LAST_SCHEDULED_TYPE, -99)
                If lastType != desired
                    If isWorkHours
                        ApplyWorkSandbox(npc)
                        DebugMsg("WorkOnlySwap: " + npc.GetDisplayName() + " -> WORK")
                    Else
                        RemoveWorkSandbox(npc)
                        DebugMsg("WorkOnlySwap: " + npc.GetDisplayName() + " -> released (off hours)")
                    EndIf
                    StorageUtil.SetIntValue(npc, KEY_LAST_SCHEDULED_TYPE, desired)
                ElseIf isWorkHours
                    ; Already on shift — keep them on the work package through greetings/scenes.
                    ReinforceWorkPackage(npc)
                EndIf
            EndIf
        EndIf
        ; A pruned entry shifted the list down — the next element is now at i,
        ; so only advance when we didn't remove.
        If !pruned
            i += 1
        EndIf
    EndWhile
EndFunction

Function MigrateWorkPoolOnLoad()
    {One-shot: links each legacy worker to their existing work marker
     (Native_GetWorkLoc) under WorkAnchorKeyword. Home-less workers also drop the old
     home override and release the home slot they borrowed. No-op without the keyword.}
    Keyword workKw = GetWorkAnchorKeyword()
    If !workKw
        Return
    EndIf
    Actor npc = None
    ObjectReference wm = None

    ; Home-less workers (KEY_WORK_ONLY_NPCS).
    Int wc = StorageUtil.FormListCount(None, KEY_WORK_ONLY_NPCS)
    Int i = 0
    While i < wc
        npc = StorageUtil.FormListGet(None, KEY_WORK_ONLY_NPCS, i) as Actor
        If npc
            wm = SeverActionsNative.Native_GetWorkLoc(npc)
            If wm
                SeverActionsNative.LinkedRef_Set(npc, wm, workKw)
            EndIf
            RemoveHomeSandbox(npc)
            If GetAssignedHome(npc) == "" && SeverActionsNative.Native_GetHomeMarkerSlot(npc) >= 0
                SeverActionsNative.Native_ReleaseHomeMarkerSlot(npc)
            EndIf
            StorageUtil.SetIntValue(npc, KEY_LAST_SCHEDULED_TYPE, -99)
        EndIf
        i += 1
    EndWhile

    ; Homed workers: just the link, for the work-hours override to anchor on.
    Int hc = StorageUtil.FormListCount(None, KEY_HOMED_NPCS)
    i = 0
    While i < hc
        npc = StorageUtil.FormListGet(None, KEY_HOMED_NPCS, i) as Actor
        If npc
            wm = SeverActionsNative.Native_GetWorkLoc(npc)
            If wm
                SeverActionsNative.LinkedRef_Set(npc, wm, workKw)
                StorageUtil.SetIntValue(npc, KEY_LAST_SCHEDULED_TYPE, -99)
            EndIf
        EndIf
        i += 1
    EndWhile

    DebugMsg("MigrateWorkPoolOnLoad: linked " + wc + " work-only + scanned " + hc + " homed for Route B")
EndFunction

; =============================================================================
; ROUTE B HOME / PLAY - the fallback when SchedSystemActive() is false
; A per-NPC force-persistent marker linked by an anchor keyword plus one shared
; sandbox override. The SchedHome/Work/Relax alias pools replaced this enforcement
; but sandbox around the SAME markers, which stay load-bearing. Also migration sources.
; =============================================================================

Int Property ROUTEB_HOME_KW_FORMID  = 0x0016567D AutoReadOnly
Int Property ROUTEB_PLAY_KW_FORMID  = 0x0016567E AutoReadOnly
Int Property ROUTEB_HOME_PKG_FORMID = 0x0016567F AutoReadOnly
{SeverActions_HomeSandboxB: sandbox r=4096 (the legacy home radius) at
 LinkedRef(HomeAnchorKW).}
Int Property ROUTEB_PLAY_PKG_FORMID = 0x00165680 AutoReadOnly
{SeverActions_PlaySandboxB — sandbox r=1500 at LinkedRef(PlayAnchorKW).}
String Property KEY_HOMEB_MARKER    = "SeverHomeB_Marker" AutoReadOnly
String Property KEY_PLAYB_RUNTIME   = "SeverPlayB_Runtime" AutoReadOnly
{1 = the play marker was runtime-spawned by Route B (delete on clear);
 absent = a legacy PlayMarkerList pool marker (never delete those).}

Keyword _homeAnchorKwCache
Keyword _playAnchorKwCache

Keyword Function GetHomeBAnchorKeyword()
    If !_homeAnchorKwCache
        _homeAnchorKwCache = Game.GetFormFromFile(ROUTEB_HOME_KW_FORMID, "SeverActions.esp") as Keyword
    EndIf
    Return _homeAnchorKwCache
EndFunction

Keyword Function GetPlayBAnchorKeyword()
    If !_playAnchorKwCache
        _playAnchorKwCache = Game.GetFormFromFile(ROUTEB_PLAY_KW_FORMID, "SeverActions.esp") as Keyword
    EndIf
    Return _playAnchorKwCache
EndFunction

Package Function GetHomeSandboxBPackage()
    Return Game.GetFormFromFile(ROUTEB_HOME_PKG_FORMID, "SeverActions.esp") as Package
EndFunction

Package Function GetPlaySandboxBPackage()
    Return Game.GetFormFromFile(ROUTEB_PLAY_PKG_FORMID, "SeverActions.esp") as Package
EndFunction

ObjectReference Function GetHomeMarkerB(Actor akActor)
    {The NPC's Route B home marker (None for legacy-slot or homeless NPCs).}
    Return StorageUtil.GetFormValue(akActor, KEY_HOMEB_MARKER) as ObjectReference
EndFunction

Function ApplyPlaySandboxB(Actor akActor)
    {Play-hours override: PlaySandboxB (r=1500) at the PlayAnchorKW-linked marker,
     priority 105 (above home 100, below work 110). Re-links the marker each time,
     so legacy play assignments self-migrate. With the schedule system active it
     fills the play alias instead.}
    If _OnJourney(akActor)
        Return
    EndIf
    If SchedSystemActive()
        FillSchedAlias(akActor, SCHEDULE_PLAY)
        Return
    EndIf
    ObjectReference playMarker = SeverActionsNative.Native_GetPlayLoc(akActor)
    Package playPkg = GetPlaySandboxBPackage()
    Keyword playKw = GetPlayBAnchorKeyword()
    If !playMarker || !playPkg || !playKw
        Return
    EndIf
    ; ApplyWorkSandbox's follow guards: play (105) outranks follow (~50), and the
    ; tick would re-stamp it right after a follow start. WFP 1 = a player wait or
    ; camp pin.
    If IsActorActivelyFollowing(akActor)
        Return
    EndIf
    If IsRegisteredFollower(akActor) && akActor.IsPlayerTeammate() && akActor.GetAV("WaitingForPlayer") != -1.0
        Return
    EndIf
    If akActor.GetAV("WaitingForPlayer") == 1.0
        Return
    EndIf
    SeverActionsNativeExt.LinkedRef_SetPermanent(akActor, playMarker, playKw)
    ActorUtil.AddPackageOverride(akActor, playPkg, 105, 1)
    akActor.EvaluatePackage()
EndFunction

Function RemovePlaySandboxB(Actor akActor)
    {No-op when the play override isn't applied; with the schedule system active it
     also empties the play alias.}
    Package playPkg = GetPlaySandboxBPackage()
    If playPkg
        ActorUtil.RemovePackageOverride(akActor, playPkg)
    EndIf
    If SchedSystemActive()
        EmptySchedAlias(akActor, SCHEDULE_PLAY)
    EndIf
    akActor.EvaluatePackage()
EndFunction

; =============================================================================
; SCHEDULE ALIAS POOLS (post-migration scheduling)
; SchedHome/Work/Relax quests (0x16A785-87), 300 ReferenceAliases each. Each alias
; carries one V2 sandbox package anchored through the NPC's anchor-keyword link, so
; ForceRefTo is the whole enforcement (no per-NPC overrides on the hot path).
; One-way: once BeginSchedAliasMigration() sets the cosaved Native_GetAliasesMigrated()
; flag, SchedSystemActive() stays true and the legacy paths route here; before that
; everything here is inert. Each NPC's alias index per type is cosaved
; (Native_Get/SetSchedAliasIndex) and drives the per-load drift sweep.
; =============================================================================

Int Property SCHEDALIAS_HOME_QUEST_FORMID  = 0x0016A785 AutoReadOnly
Int Property SCHEDALIAS_WORK_QUEST_FORMID  = 0x0016A786 AutoReadOnly
Int Property SCHEDALIAS_RELAX_QUEST_FORMID = 0x0016A787 AutoReadOnly
Int Property SCHEDALIAS_HOME_PKG_FORMID    = 0x0016A788 AutoReadOnly
{SeverActions_HomeSandbox_V2 — on every SchedHomeQuest alias.}
Int Property SCHEDALIAS_RELAX_PKG_FORMID   = 0x0016A789 AutoReadOnly
{SeverActions_RelaxSandbox_V2 — on every SchedRelaxQuest alias.}
Int Property SCHEDALIAS_WORK_PKG_FORMID    = 0x0016A78A AutoReadOnly
{SeverActions_WorkPackage_V2 — on every SchedWorkQuest alias.}
String Property KEY_SCHED_POOL_EXHAUSTED   = "SeverActions_SchedPoolExhausted_" AutoReadOnly
{None-keyed StorageUtil sticky, suffixed by type name: 1 = the last fill
 attempt found no free alias of that type (MCM warning + one notification).}

; Why the schedule holds nothing on an NPC (Sched_NoteHold; 0 = held, or released unblocked). HomeHoldCore::HoldNote is the native twin the
; Assigned NPCs card reads: keep both in step.
Int Property SCHED_HOLD_JAILED           = 1  AutoReadOnly
Int Property SCHED_HOLD_JOURNEY          = 2  AutoReadOnly
Int Property SCHED_HOLD_ARREST           = 3  AutoReadOnly
Int Property SCHED_HOLD_FOLLOWING        = 4  AutoReadOnly
Int Property SCHED_HOLD_REGISTERED       = 5  AutoReadOnly
Int Property SCHED_HOLD_SA_WAIT          = 6  AutoReadOnly
Int Property SCHED_HOLD_WAITING          = 7  AutoReadOnly
Int Property SCHED_HOLD_TEAMMATE         = 8  AutoReadOnly
Int Property SCHED_HOLD_NFF              = 9  AutoReadOnly
Int Property SCHED_HOLD_CRAFTING         = 10 AutoReadOnly   ; 9 + Sched_HoldYield (1..5) through ANIMSCENE 14
Int Property SCHED_HOLD_SCENE            = 15 AutoReadOnly
Int Property SCHED_HOLD_POOL_FULL        = 16 AutoReadOnly
Int Property SCHED_HOLD_TEAMMATE_NO_HOME = 17 AutoReadOnly
Int Property SCHED_HOLD_ANCHOR_MISSING   = 18 AutoReadOnly

; Guard-duty alias pool (FLWD v19): a guard-mode retainer (work target is an Actor)
; holds a SeverActions_GuardQuest alias in work hours, because an alias package
; re-applies on cell load where an override drops on 3D unload. The priority-110
; override stays as the exhaustion fallback and the Route B path; work-hours gating
; is the reconcile's, not the package's.
Int Property GUARD_QUEST_FORMID    = 0x0016A78E AutoReadOnly
{SeverActions_GuardQuest: aliases Guard_00..99 (GenerateGuardQuest.pas), each
 carrying SeverActions_GuardBodyguardPool, the QNAM-retargeted clone of
 GuardBodyguard 0x165677 (FixPoolPackageQNAM.pas). Quest priority 105 outranks
 the sched quests (101).}
Int Property GUARD_ALIAS_POOL_SIZE = 100 AutoReadOnly
{MUST match the alias count GenerateGuardQuest.pas makes (Guard_00..99).}
Quest _guardQuest = None
Bool _guardQuestResolved = false
Int _guardCursor = 0

; Migration batch state: script vars persist in the save, so a mid-migration save
; resumes the drain where it stopped. Arrays are cleared by assignment from
; _migNoActors, never None (B-36/B-37, see CLAUDE.md Papyrus gotchas).
Actor[] _migHomed
Actor[] _migNoActors   ; never assigned: the typed None used to clear _migHomed
Int _migHomedIdx = 0
Int _migWorkIdx = 0

Bool Function EnsureSchedQuests()
    {Lazily resolves the three schedule quests and V2 packages by FormID (never ESP
     properties). Logs and returns false while any is missing; retried each call.}
    If _schedQuestsResolved
        Return true
    EndIf
    If !_schedHomeQuest
        _schedHomeQuest = Game.GetFormFromFile(SCHEDALIAS_HOME_QUEST_FORMID, "SeverActions.esp") as Quest
    EndIf
    If !_schedWorkQuest
        _schedWorkQuest = Game.GetFormFromFile(SCHEDALIAS_WORK_QUEST_FORMID, "SeverActions.esp") as Quest
    EndIf
    If !_schedRelaxQuest
        _schedRelaxQuest = Game.GetFormFromFile(SCHEDALIAS_RELAX_QUEST_FORMID, "SeverActions.esp") as Quest
    EndIf
    If !_schedHomePackageV2
        _schedHomePackageV2 = Game.GetFormFromFile(SCHEDALIAS_HOME_PKG_FORMID, "SeverActions.esp") as Package
    EndIf
    If !_schedWorkPackageV2
        _schedWorkPackageV2 = Game.GetFormFromFile(SCHEDALIAS_WORK_PKG_FORMID, "SeverActions.esp") as Package
    EndIf
    If !_schedRelaxPackageV2
        _schedRelaxPackageV2 = Game.GetFormFromFile(SCHEDALIAS_RELAX_PKG_FORMID, "SeverActions.esp") as Package
    EndIf
    If !_schedHomeQuest || !_schedWorkQuest || !_schedRelaxQuest \
        || !_schedHomePackageV2 || !_schedWorkPackageV2 || !_schedRelaxPackageV2
        Debug.Trace("[SeverActions] SCHEDULE ALIAS POOLS UNAVAILABLE — SchedHome/Work/Relax quests or V2 packages failed to resolve from SeverActions.esp (outdated ESP?). Alias scheduling disabled; legacy Route B scheduling remains active.")
        Return false
    EndIf
    _schedQuestsResolved = true
    Return true
EndFunction

Bool Function SchedSystemActive()
    {The one post-migration gate: the quests resolve and the cosaved migration flag is set.}
    Return EnsureSchedQuests() && SeverActionsNativeExt.Native_GetAliasesMigrated()
EndFunction

Quest Function GetSchedQuestForType(Int aiType)
    If aiType == SCHEDULE_HOME
        Return _schedHomeQuest
    ElseIf aiType == SCHEDULE_WORK
        Return _schedWorkQuest
    ElseIf aiType == SCHEDULE_PLAY
        Return _schedRelaxQuest
    EndIf
    Return None
EndFunction

Package Function GetSchedPackageForType(Int aiType)
    If aiType == SCHEDULE_HOME
        Return _schedHomePackageV2
    ElseIf aiType == SCHEDULE_WORK
        Return _schedWorkPackageV2
    ElseIf aiType == SCHEDULE_PLAY
        Return _schedRelaxPackageV2
    EndIf
    Return None
EndFunction

String Function GetSchedTypeName(Int aiType)
    If aiType == SCHEDULE_HOME
        Return "home"
    ElseIf aiType == SCHEDULE_WORK
        Return "work"
    ElseIf aiType == SCHEDULE_PLAY
        Return "relax"
    EndIf
    Return "unknown"
EndFunction

ReferenceAlias Function GetSchedAlias(Int aiType, Int aiIndex)
    Quest q = GetSchedQuestForType(aiType)
    If !q || aiIndex < 0 || aiIndex >= SCHED_ALIAS_POOL_SIZE
        Return None
    EndIf
    Return q.GetNthAlias(aiIndex) as ReferenceAlias
EndFunction

Int Function _GetSchedCursor(Int aiType)
    If aiType == SCHEDULE_HOME
        Return _schedCursorHome
    ElseIf aiType == SCHEDULE_WORK
        Return _schedCursorWork
    EndIf
    Return _schedCursorRelax
EndFunction

Function _SetSchedCursor(Int aiType, Int aiValue)
    If aiType == SCHEDULE_HOME
        _schedCursorHome = aiValue
    ElseIf aiType == SCHEDULE_WORK
        _schedCursorWork = aiValue
    Else
        _schedCursorRelax = aiValue
    EndIf
EndFunction

Function _NoteSchedPoolExhausted(Int aiType)
    {Logs and notifies once per type until a slot frees.}
    String exKey = KEY_SCHED_POOL_EXHAUSTED + GetSchedTypeName(aiType)
    If StorageUtil.GetIntValue(None, exKey, 0) == 0
        StorageUtil.SetIntValue(None, exKey, 1)
        Debug.Trace("[SeverActions] SCHEDULE ALIAS POOL EXHAUSTED (" + GetSchedTypeName(aiType) + "): all " + SCHED_ALIAS_POOL_SIZE + " aliases are occupied. The NPC keeps their previous schedule behavior until a slot frees.")
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.schedulePoolFull", ("" + GetSchedTypeName(aiType))))
    EndIf
EndFunction

Function _ClearSchedPoolExhausted(Int aiType)
    String exKey = KEY_SCHED_POOL_EXHAUSTED + GetSchedTypeName(aiType)
    If StorageUtil.GetIntValue(None, exKey, 0) != 0
        StorageUtil.UnsetIntValue(None, exKey)
    EndIf
EndFunction

Int Function FindFreeSchedAlias(Int aiType)
    {Rotating-cursor scan for an unoccupied alias. O(pool) worst case, but the
     cursor makes the steady-state case O(1). -1 = pool exhausted.}
    Quest q = GetSchedQuestForType(aiType)
    If !q
        Return -1
    EndIf
    Int start = _GetSchedCursor(aiType)
    Int n = 0
    While n < SCHED_ALIAS_POOL_SIZE
        Int idx = start + n
        If idx >= SCHED_ALIAS_POOL_SIZE
            idx -= SCHED_ALIAS_POOL_SIZE
        EndIf
        ReferenceAlias al = q.GetNthAlias(idx) as ReferenceAlias
        If al && al.GetReference() == None
            Int next = idx + 1
            If next >= SCHED_ALIAS_POOL_SIZE
                next = 0
            EndIf
            _SetSchedCursor(aiType, next)
            Return idx
        EndIf
        n += 1
    EndWhile
    Return -1
EndFunction

Bool Function HoldsAnySchedAlias(Actor akActor)
    If !akActor
        Return false
    EndIf
    Return SeverActionsNativeExt.Native_GetSchedAliasIndex(akActor, SCHEDULE_HOME) >= 0 \
        || SeverActionsNativeExt.Native_GetSchedAliasIndex(akActor, SCHEDULE_WORK) >= 0 \
        || SeverActionsNativeExt.Native_GetSchedAliasIndex(akActor, SCHEDULE_PLAY) >= 0
EndFunction

Bool Function IsSchedAliasContentValid(Actor akActor, Int aiType)
    {True if the alias at the recorded index still holds this actor. No pool scan
     (ticks call it per NPC); outside drift is SweepSchedAliasesOnLoad's to repair.}
    Int idx = SeverActionsNativeExt.Native_GetSchedAliasIndex(akActor, aiType)
    If idx < 0
        Return false
    EndIf
    ReferenceAlias al = GetSchedAlias(aiType, idx)
    Return al && al.GetReference() == akActor
EndFunction

; Guard-duty alias pool

Quest Function GetGuardQuest()
    {Lazily resolves SeverActions_GuardQuest by FormID. None on an ESP without the
     pool (the priority-110 override then does guard duty); retried each call.}
    If _guardQuestResolved
        Return _guardQuest
    EndIf
    _guardQuest = Game.GetFormFromFile(GUARD_QUEST_FORMID, "SeverActions.esp") as Quest
    If !_guardQuest
        Debug.Trace("[SeverActions] GUARD ALIAS POOL UNAVAILABLE — SeverActions_GuardQuest failed to resolve from SeverActions.esp (outdated ESP?). Alias guard duty disabled; the prio-110 override assist remains active.")
        Return None
    EndIf
    _guardQuestResolved = true
    Return _guardQuest
EndFunction

ReferenceAlias Function GetGuardAlias(Int aiIndex)
    If aiIndex < 0 || aiIndex >= GUARD_ALIAS_POOL_SIZE
        Return None
    EndIf
    Quest gq = GetGuardQuest()
    If !gq
        Return None
    EndIf
    Return gq.GetNthAlias(aiIndex) as ReferenceAlias
EndFunction

Int Function FindFreeGuardAlias()
    {Rotating-cursor scan for a free guard alias; -1 = full or unavailable.}
    Quest gq = GetGuardQuest()
    If !gq
        Return -1
    EndIf
    Int n = 0
    While n < GUARD_ALIAS_POOL_SIZE
        Int idx = _guardCursor + n
        If idx >= GUARD_ALIAS_POOL_SIZE
            idx -= GUARD_ALIAS_POOL_SIZE
        EndIf
        ReferenceAlias al = gq.GetNthAlias(idx) as ReferenceAlias
        If al && al.GetReference() == None
            _guardCursor = idx + 1
            If _guardCursor >= GUARD_ALIAS_POOL_SIZE
                _guardCursor = 0
            EndIf
            Return idx
        EndIf
        n += 1
    EndWhile
    Return -1
EndFunction

Bool Function FillGuardAlias(Actor akActor)
    {Seats a guard-mode retainer in the guard pool; the alias package applies on
     ForceRefTo and re-applies on cell load. False when the pool is unavailable or
     full (the caller falls back to the priority-110 override). Idempotent.}
    If !akActor
        Return false
    EndIf
    If SeverActionsNativeExt.Native_GetGuardAliasIndex(akActor) >= 0
        Return true   ; already seated
    EndIf
    Int freeIdx = FindFreeGuardAlias()
    If freeIdx < 0
        Return false
    EndIf
    ReferenceAlias al = GetGuardAlias(freeIdx)
    If !al
        Debug.Trace("[SeverActions] GuardAlias: GetNthAlias(" + freeIdx + ") on SeverActions_GuardQuest returned a non-ReferenceAlias — ESP corrupt?")
        Return false
    EndIf
    al.ForceRefTo(akActor)
    SeverActionsNativeExt.Native_SetGuardAliasIndex(akActor, freeIdx)
    DebugMsg("GuardAlias: " + akActor.GetDisplayName() + " -> guard alias " + freeIdx)
    Return true
EndFunction

Function _FreeGuardAlias(Actor akActor)
    {Releases the guard alias, if any, and clears the cosaved index. Idempotent; no
     EvaluatePackage (the caller batches it).}
    If !akActor
        Return
    EndIf
    Int idx = SeverActionsNativeExt.Native_GetGuardAliasIndex(akActor)
    If idx >= 0
        ReferenceAlias al = GetGuardAlias(idx)
        If al && al.GetReference() == akActor
            al.Clear()
        EndIf
        ; Drop the index even if stale; SweepGuardAliasesOnLoad cross-checks the pool.
        SeverActionsNativeExt.Native_SetGuardAliasIndex(akActor, -1)
        Return
    EndIf
    ; No index (e.g. ClearFollowerData ran first on a dismiss): scan the pool so a
    ; filled alias can't keep the retainer shadowing their charge.
    Int scan = 0
    While scan < GUARD_ALIAS_POOL_SIZE
        ReferenceAlias scanAl = GetGuardAlias(scan)
        If scanAl && scanAl.GetReference() == akActor
            scanAl.Clear()
        EndIf
        scan += 1
    EndWhile
EndFunction

Int Function _SchedHoldBlock(Actor akActor, Bool abParkTeammate = false)
    {Why the schedule must hold nothing on akActor now (a SCHED_HOLD_* code), or 0. ReconcileSchedAliasesFor releases
     and FillSchedAlias refuses on this one verdict. abParkTeammate skips the unregistered-teammate arm (a hands-off
     dismiss's park).}
    If SeverActionsNativeExt.Native_Jailed_IsJailed(akActor)
        Return SCHED_HOLD_JAILED
    EndIf
    If _OnJourney(akActor)
        Return SCHED_HOLD_JOURNEY
    EndIf
    If _IsMakingArrest(akActor)
        Return SCHED_HOLD_ARREST
    EndIf
    If IsActorActivelyFollowing(akActor)
        Return SCHED_HOLD_FOLLOWING
    EndIf
    Float wfp = akActor.GetAV("WaitingForPlayer")
    Bool teammate = akActor.IsPlayerTeammate()
    If teammate && wfp != -1.0 && IsRegisteredFollower(akActor)
        Return SCHED_HOLD_REGISTERED
    EndIf
    If wfp == 1.0
        If SeverActionsNativeExt.Native_GetSandboxing(akActor)
            Return SCHED_HOLD_SA_WAIT
        EndIf
        Return SCHED_HOLD_WAITING
    EndIf
    ; WFP 2 is SA's own hold: a hands-off dismiss parks a follower whose framework keeps the teammate flag
    ; (abParkTeammate, ApplyHomeSandboxIfHomed: the fill stamps the 2), and the reconcile then leaves her there.
    If teammate && wfp != -1.0 && wfp != 2.0 && !abParkTeammate
        Return SCHED_HOLD_TEAMMATE
    EndIf
    If SeverActionsNativeExt2.Native_IsNFFManaged(akActor)
        Return SCHED_HOLD_NFF
    EndIf
    ; The schedule quests (101) outrank these holds' packages, so the schedule steps aside while they last.
    Int yieldTo = SeverActionsNativeExt2.Sched_HoldYield(akActor)
    If yieldTo > 0
        Return 9 + yieldTo
    EndIf
    Return 0
EndFunction

Bool Function _HasRoutineSpot(Actor akActor)
    {A home, a work spot or a relax spot: the NPCs the schedule holds.}
    Return GetAssignedHome(akActor) != "" || SeverActionsNative.Native_GetWorkLoc(akActor) || SeverActionsNative.Native_GetPlayLoc(akActor)
EndFunction

Function _NoteSchedHold(Actor akActor, Int aiWhy)
    {Records why the schedule holds nothing on akActor (0 = held, or released with nothing blocking her) for the Assigned NPCs card. In debug mode, logs
     a reason once, when it changes: the 30 s tick reaches the same verdict again.}
    If !akActor
        Return
    EndIf
    Int prev = SeverActionsNativeExt2.Sched_NoteHold(akActor, aiWhy)
    If aiWhy != 0 && prev != aiWhy
        DebugMsg("SchedHold: " + akActor.GetDisplayName() + " - " + _SchedHoldText(aiWhy))
    EndIf
EndFunction

String Function _SchedHoldText(Int aiWhy)
    {The debug-log wording of a SCHED_HOLD_* code.}
    If aiWhy == SCHED_HOLD_JAILED
        Return "not held: jailed"
    ElseIf aiWhy == SCHED_HOLD_JOURNEY
        Return "not held: on a journey"
    ElseIf aiWhy == SCHED_HOLD_ARREST
        Return "not held: guarding an arrest"
    ElseIf aiWhy == SCHED_HOLD_FOLLOWING
        Return "not held: following the player"
    ElseIf aiWhy == SCHED_HOLD_REGISTERED
        Return "not held: a registered follower"
    ElseIf aiWhy == SCHED_HOLD_SA_WAIT
        Return "not held: told to wait (SeverActions wait sandbox)"
    ElseIf aiWhy == SCHED_HOLD_WAITING
        Return "not held: WaitingForPlayer 1 set outside SeverActions"
    ElseIf aiWhy == SCHED_HOLD_TEAMMATE
        Return "not held: a player teammate"
    ElseIf aiWhy == SCHED_HOLD_NFF
        Return "not held: seated by NFF"
    ElseIf aiWhy == SCHED_HOLD_CRAFTING
        Return "not held: crafting (this quest's crafter alias)"
    ElseIf aiWhy == 11
        Return "not held: casting a spell (this quest's caster alias)"
    ElseIf aiWhy == 12
        Return "not held: on a Levy patrol"
    ElseIf aiWhy == 13
        Return "not held: Walk With Me leads them"
    ElseIf aiWhy == 14
        Return "not held: in a SexLab or OStim scene"
    ElseIf aiWhy == SCHED_HOLD_SCENE
        Return "not held: in a scene, home deferred"
    ElseIf aiWhy == SCHED_HOLD_POOL_FULL
        Return "not held: that schedule alias pool is full"
    ElseIf aiWhy == SCHED_HOLD_TEAMMATE_NO_HOME
        Return "not held: a player teammate with no home (skipped)"
    ElseIf aiWhy == SCHED_HOLD_ANCHOR_MISSING
        Return "held, but the spot's anchor link is missing (no marker to re-link)"
    EndIf
    Return "reason " + aiWhy
EndFunction

Int Function _EnsureSchedAnchor(Actor akActor, Int aiType)
    {Re-links the anchor aiType's package needs when akActor has none (a load dropped it, or an older build set it
     non-permanent). Never over a live link: a steward visit points WorkAnchorKW at the retainer it visits, and
     FollowTargetKW is also an arrest escort's. 0 linked already (or no keyword on this ESP), 1 re-linked, -1 missing.}
    ObjectReference marker = None
    Keyword kw = None
    If aiType == SCHEDULE_HOME
        marker = GetHomeMarkerB(akActor)
        kw = GetHomeBAnchorKeyword()
    ElseIf aiType == SCHEDULE_WORK
        marker = SeverActionsNative.Native_GetWorkLoc(akActor)
        If marker as Actor
            kw = GetGuardAnchorKeyword()   ; guard mode: the protectee link the guard package follows
        Else
            kw = GetWorkAnchorKeyword()
        EndIf
    ElseIf aiType == SCHEDULE_PLAY
        marker = SeverActionsNative.Native_GetPlayLoc(akActor)
        kw = GetPlayBAnchorKeyword()
    EndIf
    If !kw || akActor.GetLinkedRef(kw)
        Return 0
    EndIf
    If !marker
        Return -1
    EndIf
    SeverActionsNativeExt.LinkedRef_SetPermanent(akActor, marker, kw)
    DebugMsg("SchedAlias: re-linked " + akActor.GetDisplayName() + "'s " + GetSchedTypeName(aiType) + " anchor")
    Return 1
EndFunction

Function _EnsureHeldSchedAnchors(Actor akActor)
    {_EnsureSchedAnchor for each type akActor holds. Notes ANCHOR_MISSING, or clears the note, for the card.}
    Bool held = false
    Bool missing = false
    Int t = 0
    While t < 3
        If SeverActionsNativeExt.Native_GetSchedAliasIndex(akActor, t) >= 0
            held = true
            If _EnsureSchedAnchor(akActor, t) < 0
                missing = true
            EndIf
        EndIf
        t += 1
    EndWhile
    If held
        If missing
            _NoteSchedHold(akActor, SCHED_HOLD_ANCHOR_MISSING)
        Else
            _NoteSchedHold(akActor, 0)
        EndIf
    EndIf
EndFunction

Function _EmptyExtraSchedAliases(Actor akActor, Int aiKeep)
    {The steady state's half of a transition: empties any schedule alias akActor holds of a type other than aiKeep (-1
     empties all). SendHome, the Apply*Home paths and a scene restore can fill HOME at any hour. By recorded index
     only, so the guard seat goes only with a WORK alias that is held while WORK is not the type kept.}
    Bool emptied = false
    Int t = 0
    While t < 3
        If t != aiKeep && SeverActionsNativeExt.Native_GetSchedAliasIndex(akActor, t) >= 0
            EmptySchedAlias(akActor, t)
            emptied = true
        EndIf
        t += 1
    EndWhile
    If emptied
        akActor.EvaluatePackage()
        DebugMsg("SchedAlias: " + akActor.GetDisplayName() + " held another schedule alias - kept " + GetSchedTypeName(aiKeep))
    EndIf
EndFunction

Function YieldSchedule(Actor akActor)
    {Empties akActor's schedule aliases now, for a hold whose packages the schedule (quest priority 101) would override:
     this quest's crafter or caster alias, a SexLab or OStim scene. The followers "leaveSchedule" service and
     OnSchedYield call it. The reconcile keeps her off while _SchedHoldBlock says so, and re-seats her after.}
    If !akActor || !HoldsAnySchedAlias(akActor)
        Return
    EndIf
    EmptyAllSchedAliases(akActor)
    akActor.EvaluatePackage()
    Int why = _SchedHoldBlock(akActor)
    If why > 0
        _NoteSchedHold(akActor, why)
    EndIf
EndFunction

Bool Function FillSchedAlias(Actor akActor, Int aiType, Bool abParkTeammate = false)
    {Seats the NPC in a free schedule alias of aiType; its V2 package applies on ForceRefTo. A missing anchor link is
     re-made first (_EnsureSchedAnchor). Idempotent. Guard mode also takes a guard alias (the priority-110 override
     when that pool is full). Refuses, noting why, under _SchedHoldBlock, for HOME during a vanilla scene, and when the
     pool is full. A track-only follower also gets the V2 package as an override: her framework may drive her by
     overrides, which outrank any quest alias. abParkTeammate: a dismiss's park of a teammate whose framework keeps the
     flag (the WaitingForPlayer 2 stamp then exempts her from the reconcile's teammate arm).}
    If !akActor
        Return false
    EndIf
    If SeverActionsNativeExt.Native_GetSchedAliasIndex(akActor, aiType) >= 0
        _EnsureSchedAnchor(akActor, aiType)
        ; Guard mode layers on the WORK alias: a worker switched to guarding a
        ; person later already holds one and still needs the guard seat.
        If aiType == SCHEDULE_WORK && (SeverActionsNative.Native_GetWorkLoc(akActor) as Actor)             && SeverActionsNativeExt.Native_GetGuardAliasIndex(akActor) < 0
            If !FillGuardAlias(akActor)
                Package guardPkgFast = GetWorkGuardPackage()
                If guardPkgFast
                    ActorUtil.AddPackageOverride(akActor, guardPkgFast, 110, 1)
                    akActor.EvaluatePackage()
                EndIf
            EndIf
        EndIf
        Return true   ; already seated
    EndIf
    Int why = _SchedHoldBlock(akActor, abParkTeammate)
    If why > 0
        _NoteSchedHold(akActor, why)
        Return false
    EndIf
    ; HOME never pulls an actor out of a vanilla scene: mark suspended and retry
    ; later (CheckSceneSuspendedHomes / the tick).
    If aiType == SCHEDULE_HOME && SeverActionsNative.Native_IsActorInScene(akActor)
        SeverActionsNativeExt.Native_SetHomeSceneSuspended(akActor, true)
        _NoteSchedHold(akActor, SCHED_HOLD_SCENE)
        Return false
    EndIf
    Int freeIdx = FindFreeSchedAlias(aiType)
    If freeIdx < 0
        _NoteSchedPoolExhausted(aiType)
        _NoteSchedHold(akActor, SCHED_HOLD_POOL_FULL)
        Return false
    EndIf
    ReferenceAlias al = GetSchedAlias(aiType, freeIdx)
    If !al
        Debug.Trace("[SeverActions] SchedAlias: GetNthAlias(" + freeIdx + ") on " + GetSchedTypeName(aiType) + " quest returned a non-ReferenceAlias — ESP corrupt?")
        Return false
    EndIf
    Int anchorState = _EnsureSchedAnchor(akActor, aiType)
    al.ForceRefTo(akActor)
    SeverActionsNativeExt.Native_SetSchedAliasIndex(akActor, aiType, freeIdx)
    Bool addedAssist = false
    If aiType == SCHEDULE_WORK && (SeverActionsNative.Native_GetWorkLoc(akActor) as Actor)
        ; Guard mode: the guard alias; the priority-110 override only when that
        ; pool is full.
        If !FillGuardAlias(akActor)
            Package guardPkg = GetWorkGuardPackage()
            If guardPkg
                ActorUtil.AddPackageOverride(akActor, guardPkg, 110, 1)
                addedAssist = true
            EndIf
        EndIf
    EndIf
    If SeverActionsNativeExt2.Native_IsTrackOnlyFollower(akActor)
        Package v2 = GetSchedPackageForType(aiType)
        If v2
            Int prio = 100
            If aiType == SCHEDULE_WORK
                prio = 110
            ElseIf aiType == SCHEDULE_PLAY
                prio = 105
            EndIf
            ActorUtil.AddPackageOverride(akActor, v2, prio, 1)
            addedAssist = true
        EndIf
    EndIf
    akActor.SetAV("WaitingForPlayer", 2)
    If aiType == SCHEDULE_HOME
        SeverActionsNativeExt.Native_SetHomeSceneSuspended(akActor, false)
    EndIf
    If addedAssist
        akActor.EvaluatePackage()
    EndIf
    _ClearSchedPoolExhausted(aiType)
    If anchorState < 0
        _NoteSchedHold(akActor, SCHED_HOLD_ANCHOR_MISSING)
    Else
        _NoteSchedHold(akActor, 0)
    EndIf
    DebugMsg("SchedAlias: " + akActor.GetDisplayName() + " -> " + GetSchedTypeName(aiType) + " alias " + freeIdx)
    Return true
EndFunction

Function EmptySchedAlias(Actor akActor, Int aiType)
    {Releases the NPC's alias of this type (index check only, no pool scan) and
     strips the fill-time assists. No EvaluatePackage (the caller batches it).
     Without an alias only the V2 assist (and, for WORK, the guard alias) comes off.}
    If !akActor
        Return
    EndIf
    If aiType == SCHEDULE_WORK
        ; Independent of the sched index, so a stale index never strands a guard alias.
        _FreeGuardAlias(akActor)
    EndIf
    ; The track-only V2 assist comes off unconditionally, before the index check:
    ; ReclaimSchedAliasesByEngine resets the index first on the per-tick path, and
    ; ownership can change between fill and release (an NFF dismiss then re-recruit).
    ; A no-op when it was never added.
    Package v2 = GetSchedPackageForType(aiType)
    If v2
        ActorUtil.RemovePackageOverride(akActor, v2)
    EndIf
    Int idx = SeverActionsNativeExt.Native_GetSchedAliasIndex(akActor, aiType)
    If idx < 0
        Return
    EndIf
    ReferenceAlias al = GetSchedAlias(aiType, idx)
    If al && al.GetReference() == akActor
        al.Clear()
    EndIf
    ; Drop the index even if stale; SweepSchedAliasesOnLoad cross-checks the pool.
    SeverActionsNativeExt.Native_SetSchedAliasIndex(akActor, aiType, -1)
    If aiType == SCHEDULE_WORK
        Package guardPkg = GetWorkGuardPackage()
        If guardPkg
            ActorUtil.RemovePackageOverride(akActor, guardPkg)
        EndIf
    EndIf
    ; A home-less NPC left holding no schedule alias drops SA's WaitingForPlayer 2 stamp; a home or another held alias
    ; keeps it.
    If aiType != SCHEDULE_HOME && GetAssignedHome(akActor) == "" && !HoldsAnySchedAlias(akActor)
        If akActor.GetAV("WaitingForPlayer") == 2.0
            akActor.SetAV("WaitingForPlayer", 0)
        EndIf
    EndIf
    _ClearSchedPoolExhausted(aiType)
    DebugMsg("SchedAlias: emptied " + GetSchedTypeName(aiType) + " alias " + idx + " for " + akActor.GetDisplayName())
EndFunction

Function EmptyAllSchedAliases(Actor akActor)
    EmptySchedAlias(akActor, SCHEDULE_HOME)
    EmptySchedAlias(akActor, SCHEDULE_WORK)
    EmptySchedAlias(akActor, SCHEDULE_PLAY)
EndFunction

Int Function ReconcileSchedAliasesFor(Actor akActor)
    {The per-NPC schedule function (post-migration). Picks the one desired alias type from the hour and the
     assignments, empties every other type, fills it, and records the transition in KEY_LAST_SCHEDULED_TYPE. Returns
     that type: SCHEDULE_HOME/WORK/PLAY; -1 released to her own AI (a home-less NPC outside her work and relax hours);
     -99 while _SchedHoldBlock says SA must hold nothing (every alias emptied, the reason noted).}
    If !akActor || akActor.IsDeleted()
        Return -99
    EndIf
    Int why = _SchedHoldBlock(akActor)
    If why > 0
        If HoldsAnySchedAlias(akActor)
            EmptyAllSchedAliases(akActor)
            akActor.EvaluatePackage()
        EndIf
        If _HasRoutineSpot(akActor)
            _NoteSchedHold(akActor, why)
        EndIf
        Return -99
    EndIf
    Int nowType = DetermineScheduleTypeFor(akActor)
    Int desired = -1
    ; HomeHoldCore::DesiredType (the native schedule filter) is this resolution's twin: keep the two identical.
    If nowType == SCHEDULE_WORK && SeverActionsNative.Native_GetWorkLoc(akActor)
        desired = SCHEDULE_WORK
    ElseIf nowType == SCHEDULE_PLAY && SeverActionsNative.Native_GetPlayLoc(akActor)
        desired = SCHEDULE_PLAY
    ElseIf GetAssignedHome(akActor) != ""
        desired = SCHEDULE_HOME
    EndIf
    If desired < 0
        ; Released and unblocked: a reason noted while a hold lasted is stale (the card derives "off schedule").
        _NoteSchedHold(akActor, 0)
    EndIf
    Int lastType = StorageUtil.GetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, -99)
    If lastType == desired
        If desired >= 0 && !IsSchedAliasContentValid(akActor, desired)
            SeverActionsNativeExt.Native_SetSchedAliasIndex(akActor, desired, -1)
            FillSchedAlias(akActor, desired)
        EndIf
        _EmptyExtraSchedAliases(akActor, desired)
        Return desired
    EndIf
    ; Transition: empty everything that isn't desired, fill what is.
    If desired != SCHEDULE_HOME
        EmptySchedAlias(akActor, SCHEDULE_HOME)
    EndIf
    If desired != SCHEDULE_WORK
        EmptySchedAlias(akActor, SCHEDULE_WORK)
    EndIf
    If desired != SCHEDULE_PLAY
        EmptySchedAlias(akActor, SCHEDULE_PLAY)
    EndIf
    If desired >= 0
        FillSchedAlias(akActor, desired)
    EndIf
    StorageUtil.SetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, desired)
    akActor.EvaluatePackage()
    DebugMsg("SchedAlias: " + akActor.GetDisplayName() + " schedule -> " + GetSchedTypeName(desired))
    Return desired
EndFunction

Function ReinforceSchedWorkGuard(Actor akActor)
    {ReinforceWorkPackage for a bodyguard on the override fallback: a greeting can
     pull them off it. Alias packages need nothing; the engine re-selects them.}
    If !akActor || akActor.IsInCombat()
        Return
    EndIf
    ; Jail gate: see ApplyWorkSandbox.
    If SeverActionsNativeExt.Native_Jailed_IsJailed(akActor) || _IsMakingArrest(akActor) || _OnJourney(akActor)
        Return
    EndIf
    If SeverActionsNativeExt.Native_GetGuardAliasIndex(akActor) >= 0
        Return   ; alias-held: no override to re-assert
    EndIf
    If !(SeverActionsNative.Native_GetWorkLoc(akActor) as Actor)
        Return   ; not guard mode
    EndIf
    If akActor.GetAV("WaitingForPlayer") == 1.0
        Return
    EndIf
    Package guardPkg = GetWorkGuardPackage()
    If !guardPkg || akActor.GetCurrentPackage() == guardPkg
        Return
    EndIf
    ActorUtil.AddPackageOverride(akActor, guardPkg, 110, 1)
    akActor.EvaluatePackage()
EndFunction

; Guard pool: load-time adoption and reconciliation sweep

Function _AdoptOverrideGuardsFromList(String listKey)
    {One-shot migration: seats on-shift override-era guard retainers (Actor
     workLoc, prio-110 override) in the pool and strips the override. Off-shift
     ones fill through FillSchedAlias on their next WORK transition.}
    Int count = StorageUtil.FormListCount(None, listKey)
    Int i = 0
    While i < count
        Actor npc = StorageUtil.FormListGet(None, listKey, i) as Actor
        If npc && !npc.IsDeleted() && (SeverActionsNative.Native_GetWorkLoc(npc) as Actor)
            If SeverActionsNativeExt.Native_GetGuardAliasIndex(npc) < 0 \
                && StorageUtil.GetIntValue(npc, KEY_LAST_SCHEDULED_TYPE, -99) == SCHEDULE_WORK
                If FillGuardAlias(npc)
                    Package guardPkg = GetWorkGuardPackage()
                    If guardPkg
                        ActorUtil.RemovePackageOverride(npc, guardPkg)
                    EndIf
                    Debug.Trace("[SeverActions] GuardPool migration: " + npc.GetDisplayName() + " adopted into the guard alias pool")
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile
EndFunction

Function _DropStaleGuardIndicesFromList(String listKey)
    {Drops recorded indices whose alias no longer holds the retainer (the next
     FillSchedAlias re-seats them).}
    Int count = StorageUtil.FormListCount(None, listKey)
    Int i = 0
    While i < count
        Actor npc = StorageUtil.FormListGet(None, listKey, i) as Actor
        If npc
            Int idx = SeverActionsNativeExt.Native_GetGuardAliasIndex(npc)
            If idx >= 0
                ReferenceAlias al = GetGuardAlias(idx)
                If !al || al.GetReference() != npc
                    SeverActionsNativeExt.Native_SetGuardAliasIndex(npc, -1)
                    Debug.Trace("[SeverActions] GuardPool sweep: dropped stale index " + idx + " for " + npc.GetDisplayName())
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile
EndFunction

Function SweepGuardAliasesOnLoad()
    {Load-time guard-pool sweep (the SweepSchedAliasesOnLoad pattern). Once
     (sentinel SeverActions_GuardPoolMigDone): adopt override-era guards. Every
     load: empty aliases holding deleted/disabled or non-guard actors, resolve
     duplicates to the recorded index, adopt mismatches, drop stale indices.}
    Quest gq = GetGuardQuest()
    If !gq
        Return
    EndIf
    If StorageUtil.GetIntValue(None, "SeverActions_GuardPoolMigDone", 0) == 0
        _AdoptOverrideGuardsFromList(KEY_HOMED_NPCS)
        _AdoptOverrideGuardsFromList(KEY_WORK_ONLY_NPCS)
        StorageUtil.SetIntValue(None, "SeverActions_GuardPoolMigDone", 1)
        Debug.Trace("[SeverActions] GuardPool migration pass complete (sentinel set)")
    EndIf
    ; Pool side.
    Int i = 0
    While i < GUARD_ALIAS_POOL_SIZE
        ReferenceAlias al = gq.GetNthAlias(i) as ReferenceAlias
        If al
            Actor a = al.GetReference() as Actor
            If a
                If a.IsDeleted() || a.IsDisabled()
                    al.Clear()
                    Debug.Trace("[SeverActions] GuardPool sweep: emptied alias " + i + " (deleted/disabled holder)")
                ElseIf !(SeverActionsNative.Native_GetWorkLoc(a) as Actor)
                    al.Clear()   ; holder is no longer guard-mode
                    If SeverActionsNativeExt.Native_GetGuardAliasIndex(a) == i
                        SeverActionsNativeExt.Native_SetGuardAliasIndex(a, -1)
                    EndIf
                    Debug.Trace("[SeverActions] GuardPool sweep: emptied alias " + i + " (holder no longer guard-mode)")
                Else
                    Int claimed = SeverActionsNativeExt.Native_GetGuardAliasIndex(a)
                    If claimed != i
                        If claimed >= 0
                            ReferenceAlias other = GetGuardAlias(claimed)
                            If other && other.GetReference() == a
                                al.Clear()   ; duplicate fill — the recorded one wins
                                Debug.Trace("[SeverActions] GuardPool sweep: emptied duplicate alias " + i + " for " + a.GetDisplayName())
                            Else
                                SeverActionsNativeExt.Native_SetGuardAliasIndex(a, i)   ; recorded index was stale — adopt
                            EndIf
                        Else
                            SeverActionsNativeExt.Native_SetGuardAliasIndex(a, i)   ; adopt
                        EndIf
                    EndIf
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile
    ; Roster side.
    _DropStaleGuardIndicesFromList(KEY_HOMED_NPCS)
    _DropStaleGuardIndicesFromList(KEY_WORK_ONLY_NPCS)
    DebugMsg("GuardAlias: load sweep complete")
EndFunction

; Tick dispatchers

; Chunking state. Persists in the save, but both cursors are wrapped against a
; fresh length on every use, so a stale value is harmless.
Int _tickCounter = 0
Int _schedCursor = 0
Int _slowCursor  = 0

Int Property SCHED_CHUNK_THRESHOLD = 16 AutoReadOnly
{At or below this many scheduled NPCs the full walk runs every tick. Chunking
 engages only above it: it trades stack depth for schedule latency (an NPC can
 reach work a chunk-cycle late), which a normal party should not pay.}

Int Property SCHED_CHUNK_BUDGET = 8 AutoReadOnly
{Per-NPC schedule steps per tick once chunking engages; a due set of N is
 covered within ceil(N / this) ticks.}

Int Property SCHED_SLOW_LANE_TICKS = 8 AutoReadOnly
{Once chunking engages, the slow lane runs every Nth tick (~4 min), and its
 homed walk is itself chunked to SCHED_CHUNK_BUDGET, so a full pass takes
 ceil(roster / budget) runs (~28 min at 50). It carries what the native filter
 cannot see (stale KEY_LAST_SCHEDULED_TYPE, stale ActivelyFollowing faction, the
 KEY_WORK_ONLY_NPCS prune, an on-shift work-only NPC's alias re-fill): do not
 move a time-sensitive check onto it.}

Function ProcessSchedulePasses(Bool schedActive)
    {Routes this tick's schedule and work-only passes. Small roster or Route B:
     the full walks every tick. Large alias-era roster: the native due set every
     tick (fast lane) plus the slow lane every SCHED_SLOW_LANE_TICKS. The native
     filter only proves "nothing to do" (ScheduleTickFilter.h).}
    _tickCounter += 1
    Int scheduledCount = StorageUtil.FormListCount(None, KEY_HOMED_NPCS) \
        + StorageUtil.FormListCount(None, KEY_WORK_ONLY_NPCS)
    If !schedActive || scheduledCount <= SCHED_CHUNK_THRESHOLD
        ProcessScheduleSwapsDispatch(schedActive)
        ProcessWorkOnlySwapsDispatch(schedActive)
        Return
    EndIf
    ProcessScheduleDueAliases()
    If (_tickCounter % SCHED_SLOW_LANE_TICKS) == 0
        ProcessSchedSlowLane()
    EndIf
EndFunction

Function ProcessSchedSlowLane()
    {Slow lane: SchedAliasStepFor over the next slice of the homed roster (its
     own cursor; carries the stale-type and stale-faction heals), then the full
     work-only walk (the list prune).}
    Int hc = StorageUtil.FormListCount(None, KEY_HOMED_NPCS)
    If hc > 0
        ; Stack-local index: _slowCursor is shared by every live stack (see
        ; ProcessScheduleDueAliases).
        Int cur = _slowCursor
        If cur >= hc
            cur = 0
        EndIf
        Int done = 0
        While done < SCHED_CHUNK_BUDGET && done < hc
            SchedAliasStepFor(StorageUtil.FormListGet(None, KEY_HOMED_NPCS, cur) as Actor)
            cur += 1
            If cur >= hc
                cur = 0
            EndIf
            done += 1
        EndWhile
        _slowCursor = cur
    EndIf
    ; A full reconcile, not prune-only: the fast lane filters out an on-shift
    ; work-only NPC (desired == held), so this is the only place its
    ; steady-state IsSchedAliasContentValid re-fill runs.
    ProcessWorkOnlySwapsAliases()
EndFunction

; The caller passes the era gate (SchedSystemActive) so it is read once per tick.

Function ProcessScheduleSwapsDispatch(Bool schedActive)
    If schedActive
        ProcessScheduleSwapsAliases()
    Else
        ProcessScheduleSwapsRouteB()
    EndIf
EndFunction

Function ProcessWorkOnlySwapsDispatch(Bool schedActive)
    If schedActive
        ProcessWorkOnlySwapsAliases()
    Else
        ProcessWorkOnlySwapsRouteB()
    EndIf
EndFunction

Function ProcessHomeMarkerHops(Actor[] homed, Bool sleepOpen)
    {Room rotation (ai_docs/NAMED_MARKERS.md 5.5): every 1-3 game hours per NPC,
     moves a homed NPC's home anchor (KEY_HOMEB_MARKER, shared by Route B and the
     alias world) onto another named marker in their home; the sandbox walks
     them there. Only in the HOME slot, outside the sleep window (ProcessHomeSleep
     owns it), 3D-loaded (an unseen hop is churn), and out of combat and
     dialogue. No track-only gate: homes are SA-owned post-dismissal state.}
    Float now = GetGameTimeInSeconds()
    Int i = 0
    While i < homed.Length
        Actor npc = homed[i]
        If npc && !npc.IsDeleted() && npc.Is3DLoaded() && !npc.IsDead()
            Float nextHop = StorageUtil.GetFloatValue(npc, KEY_NEXT_ROOM_HOP_GT, 0.0)
            If now >= nextHop
                ; Re-arm first, even when a gate fails or no marker exists, so
                ; a markerless home is not rescanned every tick.
                StorageUtil.SetFloatValue(npc, KEY_NEXT_ROOM_HOP_GT, now + Utility.RandomFloat(1.0, 3.0) * SECONDS_PER_GAME_HOUR)
                If !sleepOpen && !IsRegisteredFollower(npc) && !npc.IsPlayerTeammate()                     && !npc.IsInCombat() && !npc.IsInDialogueWithPlayer()                     && DetermineScheduleTypeFor(npc) == SCHEDULE_HOME
                    ObjectReference anchor = GetHomeMarkerB(npc)
                    If anchor
                        ObjectReference target = SeverActionsNativeExt2.Marker_PickRotationTarget(npc, anchor)
                        If target
                            anchor.MoveTo(target)
                            npc.EvaluatePackage()
                            DebugMsg("RoomRotation: " + npc.GetDisplayName() + " drifts to another room (anchor moved)")
                        EndIf
                    EndIf
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile
EndFunction

Function ProcessHomeSleep(Actor[] homed, Bool windowOpen)
    {Homed-NPC sleep window. Inside it, a loaded, dismissed, non-combat homed NPC
     whose schedule slot is HOME (work/relax win) is seated in the bed
     BedAssignment claimed, through the furniture pipeline the UseFurniture
     action uses; outside it, or on re-recruit or death, they are stood up.
     Touches only the furniture override, so it works on Route B and alias saves
     alike. The SeverActions_HomeSleeping flag marks our sleepers, so the wake
     path never stands up an NPC the player seated. _OnUpdatePass computes the
     roster and window once per tick.}
    Int i = 0
    While i < homed.Length
        Actor npc = homed[i]
        If npc && !npc.IsDeleted()
            Bool asleep = StorageUtil.GetIntValue(npc, "SeverActions_HomeSleeping", 0) == 1
            If asleep
                If !windowOpen || npc.IsDead() || IsRegisteredFollower(npc) || npc.IsPlayerTeammate()
                    ; Morning, death, or re-recruitment - stand them up.
                    SeverActions_FurnitureLib.Stop(npc)
                    StorageUtil.UnsetIntValue(npc, "SeverActions_HomeSleeping")
                ElseIf !SkyrimNetApi.HasPackage(npc, "SeverActions_UseFurniture")
                    ; Something else ended the furniture use; drop our flag so a
                    ; later tick can put them back to bed.
                    StorageUtil.UnsetIntValue(npc, "SeverActions_HomeSleeping")
                EndIf
            ElseIf windowOpen && npc.Is3DLoaded() && !npc.IsDead() && !npc.IsInCombat() \
                && !IsRegisteredFollower(npc) && !npc.IsPlayerTeammate() \
                && !SkyrimNetApi.HasPackage(npc, "SeverActions_UseFurniture") \
                && DetermineScheduleTypeFor(npc) == SCHEDULE_HOME
                Int bedId = SeverActionsNative.Native_BedAssignment_GetBedFormID(npc)
                ObjectReference homeMk = None
                If bedId == 0
                    homeMk = GetHomeMarkerB(npc)
                EndIf
                If homeMk && npc.GetParentCell() == homeMk.GetParentCell()
                    ; No claim on record (a home assigned before BedAssignment,
                    ; a first claim that found nothing, or a dismissal on an
                    ; older build that wiped it). The NPC stands in their home
                    ; cell, so claim there, at most once per game day per NPC.
                    If Utility.GetCurrentGameTime() >= StorageUtil.GetFloatValue(npc, "SeverActions_BedClaimRetry", 0.0)
                        StorageUtil.SetFloatValue(npc, "SeverActions_BedClaimRetry", Utility.GetCurrentGameTime() + 1.0)
                        If SeverActionsNative.Native_BedAssignment_Claim(npc)
                            bedId = SeverActionsNative.Native_BedAssignment_GetBedFormID(npc)
                            DebugMsg("HomeSleep: late bed claim for " + npc.GetDisplayName() + " -> " + bedId)
                        Else
                            DebugMsg("HomeSleep: no claimable bed for " + npc.GetDisplayName() + " in their current cell")
                        EndIf
                    EndIf
                EndIf
                ObjectReference bed = Game.GetFormEx(bedId) as ObjectReference
                If bed && bed.Is3DLoaded() && !bed.IsFurnitureInUse()
                    ; IsFurnitureInUse is checked here so the executor's
                    ; "already in use" event cannot fire every tick.
                    SeverActions_FurnitureLib.UseRef(npc, bed)
                    StorageUtil.SetIntValue(npc, "SeverActions_HomeSleeping", 1)
                    DebugMsg("HomeSleep: " + npc.GetDisplayName() + " heads to bed")
                ElseIf bed
                    DebugMsg("HomeSleep: bed unavailable for " + npc.GetDisplayName() + " (loaded=" + bed.Is3DLoaded() + " inUse=" + bed.IsFurnitureInUse() + ")")
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile
EndFunction

Function SchedAliasStepFor(Actor npc)
    {Per-NPC schedule step shared by the full walk and the fast lane. Reconciles
     a dismissed NPC's schedule aliases; strips any a registered follower holds.}
    If !npc || npc.IsDeleted()
        Return
    EndIf
    ; Jail gate: seating work at the tied priority 110 walks a jailed NPC out of
    ; jail. Strip any stale hold once, then leave them to the PrisonerSandBox.
    If SeverActionsNativeExt.Native_Jailed_IsJailed(npc)
        If HoldsAnySchedAlias(npc) || StorageUtil.GetIntValue(npc, KEY_LAST_SCHEDULED_TYPE, -99) != -99
            StripScheduleForJail(npc)
            DebugMsg("SchedAlias: stripped schedule hold from jailed " + npc.GetDisplayName())
        EndIf
        _NoteSchedHold(npc, SCHED_HOLD_JAILED)
        Return
    EndIf
    If IsRegisteredFollower(npc)
        ; A registered follower holds no schedule aliases. The engine reclaim
        ; runs first so an orphaned seat (index lost, actor still seated) is
        ; released too.
        If ReclaimSchedAliasesByEngine(npc) > 0 || HoldsAnySchedAlias(npc) || StorageUtil.GetIntValue(npc, KEY_LAST_SCHEDULED_TYPE, -99) != -99
            EmptyAllSchedAliases(npc)
            If npc.GetAV("WaitingForPlayer") == 2.0
                npc.SetAV("WaitingForPlayer", 0)
            EndIf
            StorageUtil.SetIntValue(npc, KEY_LAST_SCHEDULED_TYPE, -99)
            npc.EvaluatePackage()
            DebugMsg("SchedAlias: stripped stale schedule aliases from registered follower " + npc.GetDisplayName())
        EndIf
    Else
        ; A home-less teammate (a work or relax spot only) is skipped, or an alias could
        ; be filled mid-follow. Homed NPCs rely on ReconcileSchedAliasesFor's own
        ; follow/wait guards.
        If npc.IsPlayerTeammate() && GetAssignedHome(npc) == ""
            _NoteSchedHold(npc, SCHED_HOLD_TEAMMATE_NO_HOME)
            Return
        EndIf
        ; Same stale-ActivelyFollowing heal as ProcessScheduleSwapsRouteB.
        If !npc.IsPlayerTeammate()
            Faction afFact = GetActivelyFollowingFaction()
            ; A pool-seated casual follower keeps it.
            SeverActions_Follow fsHeal = GetFollowScript()
            If afFact && npc.IsInFaction(afFact) && !SkyrimNetApi.HasPackage(npc, "FollowPlayer") && !(fsHeal && fsHeal.IsInFollowerSlot(npc))
                npc.RemoveFromFaction(afFact)
                DebugMsg("SchedAlias: cleared stale ActivelyFollowing faction from dismissed " + npc.GetDisplayName())
            EndIf
        EndIf
        ; The reconcile returns the desired type (and has just recorded it).
        If ReconcileSchedAliasesFor(npc) == SCHEDULE_WORK
            ReinforceSchedWorkGuard(npc)
        EndIf
    EndIf
EndFunction

Function ProcessScheduleSwapsAliases()
    {Post-migration homed-NPC tick, full roster walk, for alias-era rosters at
     or below SCHED_CHUNK_THRESHOLD. Above it this is not called: the slow lane
     drives SchedAliasStepFor over a slice directly.}
    Int count = StorageUtil.FormListCount(None, KEY_HOMED_NPCS)
    Int i = 0
    While i < count
        SchedAliasStepFor(StorageUtil.FormListGet(None, KEY_HOMED_NPCS, i) as Actor)
        i += 1
    EndWhile
EndFunction

Function ProcessScheduleDueAliases()
    {Fast lane: Sched_GetTransitionDue returns only the NPCs with work this tick
     (a transition, a registered follower holding an alias, an on-shift guard
     due a reinforce, an orphaned hold, a held NPC in a hold the schedule yields
     to). It reads FollowerDataStore, so it covers
     the homed and work-only rosters in one pass. Sorted by FormID, which keeps
     the chunk cursor stable across ticks.}
    Actor[] due = SeverActionsNativeExt2.Sched_GetTransitionDue( \
        GetCurrentGameHour(), SeverActionsNativeExt2.Settings_GetFloat("scheduleWorkStart"), SeverActionsNativeExt2.Settings_GetFloat("scheduleWorkEnd"), \
        SeverActionsNativeExt2.Settings_GetFloat("schedulePlayStart"), SeverActionsNativeExt2.Settings_GetFloat("schedulePlayEnd"))
    If !due || due.Length == 0
        Return
    EndIf

    ; A small due set is processed whole; deferring it would make NPCs visibly
    ; late for work.
    If due.Length <= SCHED_CHUNK_THRESHOLD
        Int i = 0
        While i < due.Length
            SchedAliasStepFor(due[i])
            i += 1
        EndWhile
        Return
    EndIf

    ; Rotating cursor. Index through a stack-local, never _schedCursor: the var
    ; is shared by every stack, and two _OnUpdatePass stacks can be live (the
    ; re-entrancy guard admits a second after its 120s ceiling), so across
    ; SchedAliasStepFor's yields another stack could push it past this stack's
    ; due.Length and abort the pass. The write-back is the only shared mutation.
    Int cur = _schedCursor
    If cur >= due.Length
        cur = 0
    EndIf
    Int done = 0
    While done < SCHED_CHUNK_BUDGET && done < due.Length
        SchedAliasStepFor(due[cur])
        cur += 1
        If cur >= due.Length
            cur = 0
        EndIf
        done += 1
    EndWhile
    _schedCursor = cur
    DebugMsg("SchedAlias: chunked pass - " + done + " of " + due.Length + " due (cursor now " + _schedCursor + ")")
EndFunction

Function ProcessWorkOnlySwapsAliases()
    {Post-migration home-less tick: prunes rows with no work or relax spot in this
     save (KEY_WORK_ONLY_NPCS is a StorageUtil global and can bleed across
     same-session loads) and reconciles the rest. Always a full walk: the fast
     lane sees neither the prune nor the steady-state re-fill.}
    Int count = StorageUtil.FormListCount(None, KEY_WORK_ONLY_NPCS)
    Int i = 0
    While i < count
        Actor npc = StorageUtil.FormListGet(None, KEY_WORK_ONLY_NPCS, i) as Actor
        Bool pruned = false
        If npc && !npc.IsDeleted() && !npc.IsPlayerTeammate() && !IsRegisteredFollower(npc)
            If !SeverActionsNative.Native_GetWorkLoc(npc) && !SeverActionsNative.Native_GetPlayLoc(npc)
                ; No native work or relax spot in THIS save: strip + prune.
                EmptyAllSchedAliases(npc)
                If npc.GetAV("WaitingForPlayer") == 2.0
                    npc.SetAV("WaitingForPlayer", 0)
                EndIf
                npc.EvaluatePackage()
                StorageUtil.FormListRemove(None, KEY_WORK_ONLY_NPCS, npc as Form, true)
                SeverActionsNativeExt2.Sched_NoteHold(npc, 0)
                StorageUtil.UnsetIntValue(npc, KEY_LAST_SCHEDULED_TYPE)
                count -= 1
                pruned = true
                DebugMsg("SchedAlias: pruned home-less " + npc.GetDisplayName() + " - no work or relax spot this save")
            Else
                If ReconcileSchedAliasesFor(npc) == SCHEDULE_WORK
                    ReinforceSchedWorkGuard(npc)
                EndIf
            EndIf
        ElseIf npc && !npc.IsDeleted() && npc.IsPlayerTeammate() && !IsRegisteredFollower(npc)
            _NoteSchedHold(npc, SCHED_HOLD_TEAMMATE_NO_HOME)
        EndIf
        If !pruned
            i += 1
        EndIf
    EndWhile
EndFunction

; Follow-system hooks

Int Function ReclaimSchedAliasesByEngine(Actor akActor)
    {Releases every schedule alias the ENGINE says holds this actor, whatever the
     recorded index says (EmptySchedAlias releases by recorded index only and only
     the load sweep scans the pools, so a lost index orphans the seat), resetting
     that type's recorded index, and strips (and counts) a V2 override still holding them.
     One native read per pool, cheap enough for the per-tick self-heal. Returns
     the count; each hit is traced.}
    If !akActor
        Return 0
    EndIf
    Int released = 0
    Int t = 0
    While t < 3
        Quest q = GetSchedQuestForType(t)
        If q
            Int idx = SeverActionsNativeExt2.Sched_AliasIndexIn(akActor, q)
            If idx >= 0
                ReferenceAlias al = GetSchedAlias(t, idx)
                If al && al.GetReference() == akActor
                    al.Clear()
                    released += 1
                    Debug.Trace("[SeverActions_FollowerManager] SchedAlias: reclaimed " + GetSchedTypeName(t) + " alias " + idx + " for " + akActor.GetDisplayName() + " (engine seat; recorded index was " + SeverActionsNativeExt.Native_GetSchedAliasIndex(akActor, t) + ")")
                EndIf
                SeverActionsNativeExt.Native_SetSchedAliasIndex(akActor, t, -1)
            EndIf
        EndIf
        ; The V2 override (FillSchedAlias's track-only assist) holds an actor
        ; outside any alias, so the seat check above cannot see it.
        Package v2 = GetSchedPackageForType(t)
        If v2
            ; Stripped here, not only detected, and whether or not it is the running
            ; package: with no index recorded, EmptySchedAliasesForFollow's HoldsAny
            ; guard skips EmptyAll, so nothing else removes it. Counting what came off
            ; makes the return mean "something orphaned was still holding them".
            ; RemovePackageOverride's bool reads true for a waiting follower who holds
            ; no V2 at all, so a drop in the override count is the test.
            Int overridesBefore = ActorUtil.CountPackageOverride(akActor)
            ActorUtil.RemovePackageOverride(akActor, v2)
            If ActorUtil.CountPackageOverride(akActor) < overridesBefore
                released += 1
                Debug.Trace("[SeverActions_FollowerManager] SchedAlias: reclaimed orphaned " + GetSchedTypeName(t) + " V2 override for " + akActor.GetDisplayName())
            EndIf
        EndIf
        t += 1
    EndWhile
    Return released
EndFunction

Function EmptySchedAliasesForFollow(Actor akActor)
    {Called by Follow.psc when an NPC comes under direct player or framework
     control (follow, wait, sandbox, track-only wait). Releases every schedule
     alias and the relax WaitingForPlayer bias; safe to call in any era.}
    If !akActor
        Return
    EndIf
    Bool had = HoldsAnySchedAlias(akActor)
    If had
        EmptyAllSchedAliases(akActor)
    EndIf
    ; Also release any seat the engine still shows (see ReclaimSchedAliasesByEngine).
    If ReclaimSchedAliasesByEngine(akActor) > 0
        had = true
    EndIf
    If akActor.GetAV("WaitingForPlayer") == 2.0
        akActor.SetAV("WaitingForPlayer", 0)
        had = true
    EndIf
    If had
        akActor.EvaluatePackage()
    EndIf
EndFunction

Function RefillSchedAliasesAfterStop(Actor akActor)
    {Called by Follow.psc when follow or sandbox control ends. Reconcile's own
     guards make it a no-op when the NPC re-followed or was told to wait. Not
     called from ExitSafeInteriorSandbox (that path resumes follow).}
    If !akActor
        Return
    EndIf
    If SchedSystemActive()
        ReconcileSchedAliasesFor(akActor)
    EndIf
EndFunction

; Route B -> alias migration

Function BeginSchedAliasMigration()
    {One-way Route B -> alias migration. Sets the cosaved flag before touching
     any NPC, so a crash mid-batch leaves flag and enforcement consistent (the
     next tick's Reconcile picks up the rest), then drains the rosters 5 NPCs
     per 0.5s chrono tick.}
    If SeverActionsNativeExt.Native_GetAliasesMigrated()
        Return
    EndIf
    If !EnsureSchedQuests()
        Return   ; ESP too old — stay on legacy scheduling, retry next load
    EndIf
    SeverActionsNativeExt.Native_SetAliasesMigrated(true)
    Debug.Trace("[SeverActions] Schedule alias migration: flag set — draining rosters onto the alias pools in 0.5s batches...")
    _migHomed = GetAllHomedNPCs()
    _migHomedIdx = 0
    _migWorkIdx = 0
    SchedMigrationPending = true
    ChronoArm(0.5)
EndFunction

Function ProcessSchedMigrationBatch()
    {Migration drain: 5 NPCs per tick, re-arming at 0.5s until both rosters are
     done, then back to the 30s cadence.}
    Int budget = 5
    While budget > 0 && _migHomed && _migHomedIdx < _migHomed.Length
        Actor npc = _migHomed[_migHomedIdx]
        _migHomedIdx += 1
        If npc && !npc.IsDeleted()
            MigrateOneNpcToAliases(npc)
            budget -= 1
        EndIf
    EndWhile
    While budget > 0
        Int wc = StorageUtil.FormListCount(None, KEY_WORK_ONLY_NPCS)
        If _migWorkIdx >= wc
            SchedMigrationPending = false
            _migHomed = _migNoActors
            Debug.Trace("[SeverActions] Schedule alias migration complete.")
            ChronoArm(30.0)
            Return
        EndIf
        Actor wnpc = StorageUtil.FormListGet(None, KEY_WORK_ONLY_NPCS, _migWorkIdx) as Actor
        _migWorkIdx += 1
        If wnpc && !wnpc.IsDeleted()
            MigrateOneNpcToAliases(wnpc)
            budget -= 1
        EndIf
    EndWhile
    ChronoArm(0.5)
EndFunction

Function MigrateOneNpcToAliases(Actor npc)
    {Per-NPC migration: strip all legacy enforcement (legacy home-slot alias,
     Route B overrides incl. the guard's); give a homed NPC a force-persistent
     KEY_HOMEB_MARKER at its true home with a permanent HomeAnchorKW link (the
     legacy cosave slot value is kept for the native verifier); re-assert the
     work/play anchor links the V2 packages read; reconcile onto the pools.}
    If !npc || npc.IsDeleted()
        Return
    EndIf
    ; An actively-following NPC has no legacy sandboxes and must not be
    ; package-touched mid-follow; dismiss/SendHome fills their aliases later.
    If IsActorActivelyFollowing(npc) \
        || (IsRegisteredFollower(npc) && npc.IsPlayerTeammate() && npc.GetAV("WaitingForPlayer") != -1.0)
        Return
    EndIf

    RemoveHomeSandbox(npc)
    RemoveWorkSandbox(npc)
    RemovePlaySandboxB(npc)

    If GetAssignedHome(npc) != "" && !GetHomeMarkerB(npc)
        Int slot = SeverActionsNative.Native_GetHomeMarkerSlot(npc)
        If slot >= 0
            ; Position the true-home anchor before reading it (one-shot).
            EnsureTrueHomeAnchorMigrated(npc, slot)
        EndIf
        ObjectReference anchor = None
        If slot >= 0 && TrueHomeAnchorList
            anchor = TrueHomeAnchorList.GetAt(slot) as ObjectReference
        EndIf
        Static xmBase = Game.GetFormFromFile(0x00003B, "Skyrim.esm") as Static
        ObjectReference homeMarker = None
        If xmBase && anchor
            homeMarker = anchor.PlaceAtMe(xmBase, 1, true, false)
        ElseIf xmBase
            ; No anchor: use the NPC's position so the model stays uniform.
            homeMarker = npc.PlaceAtMe(xmBase, 1, true, false)
        EndIf
        If homeMarker
            StorageUtil.SetFormValue(npc, KEY_HOMEB_MARKER, homeMarker)
            Keyword homeKw = GetHomeBAnchorKeyword()
            If homeKw
                SeverActionsNativeExt.LinkedRef_SetPermanent(npc, homeMarker, homeKw)
            EndIf
            StorageUtil.SetIntValue(npc, KEY_TRUEHOME_MIGRATED, 1)
        Else
            Debug.Trace("[SeverActions] Schedule migration: could not spawn home marker for " + npc.GetDisplayName() + " — HOME fills will no-op until a marker exists")
        EndIf
    EndIf

    ; Re-assert the anchor links the V2 packages read. Guard mode (an Actor
    ; work target) keeps its GuardAnchorKW link.
    ObjectReference workLoc = SeverActionsNative.Native_GetWorkLoc(npc)
    If workLoc && !(workLoc as Actor)
        Keyword workKw = GetWorkAnchorKeyword()
        If workKw
            SeverActionsNativeExt.LinkedRef_SetPermanent(npc, workLoc, workKw)
        EndIf
    EndIf
    ObjectReference playLoc = SeverActionsNative.Native_GetPlayLoc(npc)
    If playLoc
        Keyword playKw = GetPlayBAnchorKeyword()
        If playKw
            SeverActionsNativeExt.LinkedRef_SetPermanent(npc, playLoc, playKw)
        EndIf
    EndIf

    ; Force transition bookkeeping, then reconcile onto the pools.
    StorageUtil.SetIntValue(npc, KEY_LAST_SCHEDULED_TYPE, -99)
    ReconcileSchedAliasesFor(npc)
    DebugMsg("SchedAlias migration: " + npc.GetDisplayName() + " migrated")
EndFunction

; Per-load maintenance

Function SweepSchedAliasesOnLoad()
    {Post-migration load sweep, the only full-pool scan (900 GetReference
     calls): clears aliases holding deleted/disabled actors or actors in no
     schedule roster, resolves duplicates to the recorded index, adopts
     mismatches, and drops stale FLWD indices (the next tick refills them).}
    If !SchedSystemActive() || SchedMigrationPending
        Return
    EndIf
    Int t = 0
    While t < 3
        Quest q = GetSchedQuestForType(t)
        Int i = 0
        While i < SCHED_ALIAS_POOL_SIZE
            ReferenceAlias al = q.GetNthAlias(i) as ReferenceAlias
            If al
                Actor a = al.GetReference() as Actor
                If a
                    If a.IsDeleted() || a.IsDisabled()
                        al.Clear()
                    ElseIf !StorageUtil.FormListHas(None, KEY_HOMED_NPCS, a as Form) \
                        && !StorageUtil.FormListHas(None, KEY_WORK_ONLY_NPCS, a as Form)
                        al.Clear()   ; orphaned — holder left every roster
                    Else
                        Int claimed = SeverActionsNativeExt.Native_GetSchedAliasIndex(a, t)
                        If claimed != i
                            If claimed >= 0
                                ReferenceAlias other = GetSchedAlias(t, claimed)
                                If other && other.GetReference() == a
                                    al.Clear()   ; duplicate fill — the recorded one wins
                                Else
                                    SeverActionsNativeExt.Native_SetSchedAliasIndex(a, t, i)   ; recorded index was stale — adopt
                                EndIf
                            Else
                                SeverActionsNativeExt.Native_SetSchedAliasIndex(a, t, i)   ; adopt
                            EndIf
                        EndIf
                    EndIf
                EndIf
            EndIf
            i += 1
        EndWhile
        t += 1
    EndWhile
    ; Pass 2: drop FLWD indices whose alias no longer points at the actor.
    Actor[] homed = GetAllHomedNPCs()
    Int h = 0
    While h < homed.Length
        _DropStaleSchedIndices(homed[h])
        h += 1
    EndWhile
    Int wc = StorageUtil.FormListCount(None, KEY_WORK_ONLY_NPCS)
    Int w = 0
    While w < wc
        _DropStaleSchedIndices(StorageUtil.FormListGet(None, KEY_WORK_ONLY_NPCS, w) as Actor)
        w += 1
    EndWhile
    DebugMsg("SchedAlias: load sweep complete")
EndFunction

Function _DropStaleSchedIndices(Actor npc)
    If !npc
        Return
    EndIf
    Int t = 0
    While t < 3
        Int idx = SeverActionsNativeExt.Native_GetSchedAliasIndex(npc, t)
        If idx >= 0
            ReferenceAlias al = GetSchedAlias(t, idx)
            If !al || al.GetReference() != npc
                SeverActionsNativeExt.Native_SetSchedAliasIndex(npc, t, -1)
            EndIf
        EndIf
        t += 1
    EndWhile
EndFunction

Function ReapplyTrackOnlySchedAssists()
    {Per-load re-assert of the fill-time assist overrides, which do not survive
     a load, for every alias-holding track-only follower and guard-mode worker
     (the one exception to "aliases persist", design doc 2.5-A).}
    Actor[] homed = GetAllHomedNPCs()
    Int i = 0
    While i < homed.Length
        _ReassertSchedAssistsFor(homed[i])
        i += 1
    EndWhile
    Int wc = StorageUtil.FormListCount(None, KEY_WORK_ONLY_NPCS)
    i = 0
    While i < wc
        _ReassertSchedAssistsFor(StorageUtil.FormListGet(None, KEY_WORK_ONLY_NPCS, i) as Actor)
        i += 1
    EndWhile
EndFunction

Function _ReassertSchedAssistsFor(Actor npc)
    If !npc || npc.IsDeleted() || _OnJourney(npc)
        Return
    EndIf
    Int workIdx = SeverActionsNativeExt.Native_GetSchedAliasIndex(npc, SCHEDULE_WORK)
    If workIdx >= 0 && (SeverActionsNative.Native_GetWorkLoc(npc) as Actor)
        Package guardPkg = GetWorkGuardPackage()
        If guardPkg
            ActorUtil.AddPackageOverride(npc, guardPkg, 110, 1)
        EndIf
    EndIf
    If SeverActionsNativeExt2.Native_IsTrackOnlyFollower(npc)
        Int t = 0
        While t < 3
            If SeverActionsNativeExt.Native_GetSchedAliasIndex(npc, t) >= 0
                Package v2 = GetSchedPackageForType(t)
                If v2
                    Int prio = 100
                    If t == SCHEDULE_WORK
                        prio = 110
                    ElseIf t == SCHEDULE_PLAY
                        prio = 105
                    EndIf
                    ActorUtil.AddPackageOverride(npc, v2, prio, 1)
                EndIf
            EndIf
            t += 1
        EndWhile
    EndIf
EndFunction

; Status helpers

Int Function GetSchedPoolUsed(Int aiType)
    {Seats used, 0..300, for a valid type (0 home, 1 work, 2 relax); -1 otherwise.
     No SA caller (the MCM reads Native_GetSchedPoolUsage itself); kept for old
     frames and third-party callers.}
    If aiType < 0 || aiType > 2
        Return -1
    EndIf
    Int[] usage = SeverActionsNativeExt.Native_GetSchedPoolUsage()
    If !usage || usage.Length < 3
        Return -1
    EndIf
    Return usage[aiType]
EndFunction

Bool Function GetSchedPoolExhausted(Int aiType)
    {True while that alias pool (0 home, 1 work, 2 relax) has run out; cleared when a slot
     frees. The MCM reads it through the followers provider's "schedPoolExhausted" service.}
    Return StorageUtil.GetIntValue(None, KEY_SCHED_POOL_EXHAUSTED + GetSchedTypeName(aiType), 0) == 1
EndFunction

Bool Function GetSchedMigrationDone()
    {No SA caller (the MCM's schedMigrated gate reads Native_GetAliasesMigrated
     itself); kept for old frames and third-party callers.}
    Return SeverActionsNativeExt.Native_GetAliasesMigrated()
EndFunction

; =============================================================================
; HOME ASSIGNMENT
; =============================================================================

Function AssignHome(Actor akActor, String locationName)
    {Assigns a named location as this NPC's home: stores it natively, places a
     per-NPC force-persistent anchor marker at the player's position, and seats
     the NPC in the SchedHome pool (300 concurrent; when full they keep prior
     behavior until a slot frees), or pre-migration applies the Route B override
     sandbox. Home storage has no cap. Followers get it on dismiss.}
    If !akActor || locationName == ""
        Return
    EndIf

    ; A holder of a legacy home slot (the retired 40-slot pool) releases it
    ; fully: RemoveHomeSandbox clears the alias, the per-slot override and the
    ; WaitingForPlayer bias.
    Int existingSlot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)
    If existingSlot >= 0
        RemoveHomeSandbox(akActor)
        SeverActionsNative.Native_ReleaseHomeMarkerSlot(akActor)
    EndIf

    ; The native cosave is the source of truth for the home name.
    SeverActionsNative.Native_SetHome(akActor, locationName)

    ; Home anchor (all eras): a per-NPC force-persistent marker at the player's
    ; position plus a permanent HomeAnchorKW link. The SchedHome alias package
    ; (or the pre-migration Route B override) sandboxes around it; room rotation
    ; may move it within the home.
    Actor PlayerRef = Game.GetPlayer()
    ObjectReference homeMarker = GetHomeMarkerB(akActor)
    If homeMarker
        homeMarker.MoveTo(PlayerRef)
    Else
        Static xmBase = Game.GetFormFromFile(0x00003B, "Skyrim.esm") as Static
        If xmBase
            homeMarker = PlayerRef.PlaceAtMe(xmBase, 1, true, false)
        EndIf
        If homeMarker
            StorageUtil.SetFormValue(akActor, KEY_HOMEB_MARKER, homeMarker)
        EndIf
    EndIf
    Keyword homeKw = GetHomeBAnchorKeyword()
    If homeMarker && homeKw
        ; Permanent, so the LREF staleness prune never drops it.
        SeverActionsNativeExt.LinkedRef_SetPermanent(akActor, homeMarker, homeKw)
    ElseIf !homeKw
        DebugMsg("AssignHome: HomeAnchorKW missing (old ESP?) - Route B home sandbox inactive for " + akActor.GetDisplayName())
    EndIf
    ; No TrueHomeAnchor migration needed — the Route B marker is the anchor.
    StorageUtil.SetIntValue(akActor, KEY_TRUEHOME_MIGRATED, 1)
    StorageUtil.SetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, -99)

    ; Registered followers get the sandbox on dismiss (SendHome /
    ; ApplyHomeSandboxIfHomed).
    If homeMarker && !IsRegisteredFollower(akActor)
        If SchedSystemActive()
            ReconcileSchedAliasesFor(akActor)
        Else
            ApplyHomeSandboxB(akActor)
        EndIf
    EndIf
    DebugMsg("Route B home marker placed at " + locationName + " for " + akActor.GetDisplayName())

    ; Claim a bed in the player's cell for the home sleep: unowned or owned by a
    ; non-player faction (an inn bed is rented), never a PlayerFaction or
    ; named-NPC bed. Custom-AI followers too: AssignHome opts them in, and
    ; ClearHome releases the bed. No usable bed is a silent false.
    Bool bedClaimed = SeverActionsNative.Native_BedAssignment_Claim(akActor)
    If bedClaimed
        DebugMsg("Bed assigned in home cell for " + akActor.GetDisplayName())
    EndIf

    ; The global homed roster (the schedule tick and the MCM read it).
    If !StorageUtil.FormListHas(None, KEY_HOMED_NPCS, akActor as Form)
        StorageUtil.FormListAdd(None, KEY_HOMED_NPCS, akActor as Form, false)
    EndIf

    ; A work-only NPC now has a home: the home schedule owns them (work during
    ; work hours, home otherwise).
    If StorageUtil.FormListHas(None, KEY_WORK_ONLY_NPCS, akActor as Form)
        StorageUtil.FormListRemove(None, KEY_WORK_ONLY_NPCS, akActor as Form, true)
        StorageUtil.SetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, -99)
    EndIf

    If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.willNowCallHome", ("" + akActor.GetDisplayName()), ("" + locationName)))
    EndIf

    SkyrimNetApi.RegisterPersistentEvent( \
        akActor.GetDisplayName() + " now considers " + locationName + " their home.", \
        akActor, Game.GetPlayer())

    DebugMsg("Home assigned for " + akActor.GetDisplayName() + ": " + locationName)
EndFunction

Function AssignWork(Actor akActor, String locationName)
    {Marks where this NPC works (no home needed: a work-only NPC gets a
     work-hours sandbox, see SetRoutineLocHere). Not a SkyrimNet action; the
     Actions page's Assign Work button calls it. Anyone not a retainer in service
     (a deserter included) gets a 90s non-pausing popup that places the marker and
     hires on confirm; otherwise the marker is placed directly.}
    If !akActor
        Return
    EndIf

    ; The resolved named workplace: the popup's named-place option and the
    ; direct path's placement target.
    ObjectReference dest = None
    If locationName != "" && SeverActionsNative.IsLocationResolverReady()
        dest = SeverActionsNative.ResolveDestination(akActor, locationName)
    EndIf
    String namedPlace = ""
    If dest
        namedPlace = locationName
    EndIf

    ; Anyone not in service (a deserter included, whom the hire re-hires) gets the
    ; assign-retainer popup (workplace and terms). On confirm,
    ; SeverActions_Enterprises.OnRetainerWorkLoc places the marker and the hire is
    ; native; Not now, timeout and Escape cancel fully. A Hostile ex-retainer gets
    ; no card (the open refuses) and takes the direct path below. The open call refuses while a UI
    ; view has focus or the UI is unavailable.
    If !SeverActionsNativeExt2.Venture_IsActiveRetainer(akActor) \
        && SeverActionsNativeExt.Magelight_IsRetainerAssignPromptAvailable() \
        && SeverActionsNativeExt.Magelight_OpenRetainerAssignPrompt(akActor, namedPlace, "", "", 90000)
        DebugMsg("AssignWork: opened assign-retainer popup for " + akActor.GetDisplayName())
        Return
    EndIf

    ; Otherwise place the work marker directly: at the resolved destination,
    ; else the player's position.
    SetRoutineLocHere(akActor, "work", dest, locationName)
    FireWorkAssignedEvent(akActor)
    DebugMsg("AssignWork (direct): " + akActor.GetDisplayName() + " -> " + locationName)
EndFunction

Function FireWorkAssignedEvent(Actor akActor)
    {Announce the work assignment to SkyrimNet using the stored work-location name.}
    If !akActor
        Return
    EndIf
    String wp = SeverActionsNativeExt.Native_GetWorkLocationName(akActor)
    If wp == ""
        wp = "their new workplace"
    EndIf
    SkyrimNetApi.RegisterPersistentEvent( \
        akActor.GetDisplayName() + " now works at " + wp + ".", \
        akActor, Game.GetPlayer())
EndFunction

Function SendHome(Actor akActor)
    {Sends an NPC to their assigned home: the home sandbox anchored on the marker
     walks them there, or the engine moves them on cell unload (no MoveTo, as in
     vanilla dismissal). A missing marker is spawned at the resolved home first;
     does nothing without a home.}
    If !akActor
        Return
    EndIf

    String homeLoc = GetAssignedHome(akActor)
    If homeLoc == ""
        DebugMsg("SendHome: no home assigned for " + akActor.GetDisplayName())
        Return
    EndIf

    DebugMsg("SendHome: " + akActor.GetDisplayName() + " home=" + homeLoc)

    ; Post-migration the home alias is the enforcement. Spawn the marker if
    ; missing (the migration skips actively-following NPCs), then fill it.
    If SchedSystemActive()
        If !GetHomeMarkerB(akActor)
            ObjectReference destRefA = SeverActionsNative.ResolveDestination(akActor, homeLoc)
            If destRefA
                ObjectReference insideRefA = SeverActionsNative.FindInteriorMarkerForDoor(destRefA)
                If insideRefA
                    destRefA = insideRefA
                EndIf
                Static xmHomeA = Game.GetFormFromFile(0x00003B, "Skyrim.esm") as Static
                If xmHomeA
                    ObjectReference newMarkerA = destRefA.PlaceAtMe(xmHomeA, 1, true, false)
                    If newMarkerA
                        StorageUtil.SetFormValue(akActor, KEY_HOMEB_MARKER, newMarkerA)
                        Keyword homeKwA = GetHomeBAnchorKeyword()
                        If homeKwA
                            SeverActionsNativeExt.LinkedRef_SetPermanent(akActor, newMarkerA, homeKwA)
                        EndIf
                        StorageUtil.SetIntValue(akActor, KEY_TRUEHOME_MIGRATED, 1)
                        DebugMsg("SendHome: spawned per-NPC home marker for " + akActor.GetDisplayName())
                    EndIf
                EndIf
            EndIf
        EndIf
        If FillSchedAlias(akActor, SCHEDULE_HOME)
            SeverActionsNative.EscalatedReEvaluate(akActor, 1500)
            DebugMsg("SendHome: home schedule alias filled SUCCESS")
        Else
            DebugMsg("SendHome: home alias fill deferred/failed for " + akActor.GetDisplayName() + " (scene guard, follow state, or pool full)")
        EndIf
        Return
    EndIf

    ; Legacy alias slot holders keep their per-slot system.
    Int slot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)
    If slot >= 0 && HomeMarkerList
        ObjectReference homeMarker = HomeMarkerList.GetAt(slot) as ObjectReference
        If homeMarker
            ApplyHomeSandbox(akActor, homeMarker, slot)
            akActor.EvaluatePackage()
            DebugMsg("SendHome: forced into alias slot " + slot + " SUCCESS")
            Return
        Else
            DebugMsg("SendHome: marker at slot " + slot + " is None!")
        EndIf
    EndIf

    ; Route B (or a home name with no marker yet): spawn the marker at the
    ; resolved home, following an exterior door inside so the NPC lives in the
    ; building, not on the doorstep.
    If !GetHomeMarkerB(akActor)
        ObjectReference destRef = SeverActionsNative.ResolveDestination(akActor, homeLoc)
        If destRef
            ObjectReference insideRef = SeverActionsNative.FindInteriorMarkerForDoor(destRef)
            If insideRef
                destRef = insideRef
            EndIf
            Static xmHome = Game.GetFormFromFile(0x00003B, "Skyrim.esm") as Static
            If xmHome
                ObjectReference newMarker = destRef.PlaceAtMe(xmHome, 1, true, false)
                If newMarker
                    StorageUtil.SetFormValue(akActor, KEY_HOMEB_MARKER, newMarker)
                    Keyword homeKwMig = GetHomeBAnchorKeyword()
                    If homeKwMig
                        SeverActionsNativeExt.LinkedRef_SetPermanent(akActor, newMarker, homeKwMig)
                    EndIf
                    StorageUtil.SetIntValue(akActor, KEY_TRUEHOME_MIGRATED, 1)
                    DebugMsg("SendHome migrated " + akActor.GetDisplayName() + " onto a Route B home marker")
                EndIf
            EndIf
        EndIf
    EndIf

    If GetHomeMarkerB(akActor)
        ApplyHomeSandboxB(akActor)
        akActor.EvaluatePackage()
        DebugMsg("SendHome: Route B sandbox applied")
        Return
    EndIf

    DebugMsg("SendHome: FALLBACK - no marker system")
EndFunction

Package Function GetHomeSandboxPackage(Int slot)
    {The legacy per-slot home sandbox package (slots 0-39), or None.}
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
    {Legacy path: forces the NPC into their HomeSlot alias, whose per-slot
     sandbox package targets its own XMarker; persists across loads.
     Post-migration it fills the home schedule alias instead.}
    If _OnJourney(akActor)
        Return
    EndIf
    If SchedSystemActive()
        If FillSchedAlias(akActor, SCHEDULE_HOME)
            SeverActionsNative.EscalatedReEvaluate(akActor, 1500)
        EndIf
        Return
    EndIf
    If !akActor || !homeMarker
        Return
    EndIf
    If !HomeSlots || slot < 0 || slot >= HomeSlots.Length
        DebugMsg("Invalid home slot " + slot + " for " + akActor.GetDisplayName())
        Return
    EndIf

    ; Casual followers (StartFollowing) are not teammates, so the check below
    ; misses them; the priority-100 home pull would beat their priority-50
    ; follow package.
    If IsActorActivelyFollowing(akActor)
        DebugMsg("ApplyHomeSandbox: SKIPPED - " + akActor.GetDisplayName() + " is actively following")
        Return
    EndIf

    ; Never home-sandbox an active companion: a registered follower who is still
    ; a teammate without the custom-dismiss signal (WaitingForPlayer == -1). A
    ; custom-AI framework, a teammate flicker on cell load or a verify misfire
    ; could otherwise send them walking home while recruited. The track-only
    ; dismiss-redirect callers see WFP == -1 first.
    If IsRegisteredFollower(akActor) && akActor.IsPlayerTeammate() && akActor.GetAV("WaitingForPlayer") != -1.0
        DebugMsg("ApplyHomeSandbox: SKIPPED - " + akActor.GetDisplayName() + " is an active following companion (not dismissed)")
        Return
    EndIf

    ; In a vanilla scene the home sandbox would fight the scene's package: mark
    ; them scene-suspended; CheckSceneSuspendedHomes retries once it ends.
    If SeverActionsNative.Native_IsActorInScene(akActor)
        DebugMsg("Home: skipping application - " + akActor.GetDisplayName() + " is in a vanilla scene; will retry once scene ends")
        SeverActionsNativeExt.Native_SetHomeSceneSuspended(akActor, true)
        Return
    EndIf

    SeverActionsNativeExt.Native_SetHomeSceneSuspended(akActor, false)

    ; One-shot: sync TrueHomeAnchor to the HomeMarker (see EnsureTrueHomeAnchorMigrated).
    EnsureTrueHomeAnchorMigrated(akActor, slot)

    ; The alias applies the per-slot package, which targets its own XMarker.
    HomeSlots[slot].ForceRefTo(akActor)

    ; A track-only follower's own record packages beat the alias package, so
    ; add a priority-100 override.
    If SeverActionsNativeExt2.Native_IsTrackOnlyFollower(akActor)
        Package homePkg = GetHomeSandboxPackage(slot)
        If homePkg
            ActorUtil.AddPackageOverride(akActor, homePkg, 100, 1)
            DebugMsg("ApplyHomeSandbox: Added PO3 override (priority 100) for track-only " + akActor.GetDisplayName())
        EndIf
    EndIf

    ; WaitingForPlayer 2 (relax) keeps custom follower frameworks' return-home
    ; packages from fighting the sandbox.
    akActor.SetAV("WaitingForPlayer", 2)

    ; Escalating re-evaluate (immediate, 500ms, 1500ms resetAI): a single
    ; evaluate left stragglers.
    SeverActionsNative.EscalatedReEvaluate(akActor, 1500)
    DebugMsg("ApplyHomeSandbox: " + akActor.GetDisplayName() + " -> HomeSlot_" + slot)
EndFunction

Function ApplyHomeSandboxB(Actor akActor)
    {Route B twin of ApplyHomeSandbox: one shared sandbox override (priority
     100) anchored on the HomeAnchorKW-linked marker, with the same guards.
     Post-migration it fills the home schedule alias instead.}
    If _OnJourney(akActor)
        Return
    EndIf
    If SchedSystemActive()
        If !akActor
            Return
        EndIf
        ; The follow guards (FillSchedAlias repeats them).
        If IsActorActivelyFollowing(akActor)
            Return
        EndIf
        If IsRegisteredFollower(akActor) && akActor.IsPlayerTeammate() && akActor.GetAV("WaitingForPlayer") != -1.0
            Return
        EndIf
        If FillSchedAlias(akActor, SCHEDULE_HOME)
            SeverActionsNative.EscalatedReEvaluate(akActor, 1500)
        EndIf
        Return
    EndIf
    If !akActor || !GetHomeMarkerB(akActor)
        Return
    EndIf
    ; Casual-follower guard, as in ApplyHomeSandbox.
    If IsActorActivelyFollowing(akActor)
        DebugMsg("ApplyHomeSandboxB: SKIPPED - " + akActor.GetDisplayName() + " is actively following")
        Return
    EndIf
    If IsRegisteredFollower(akActor) && akActor.IsPlayerTeammate() && akActor.GetAV("WaitingForPlayer") != -1.0
        DebugMsg("ApplyHomeSandboxB: SKIPPED - " + akActor.GetDisplayName() + " is an active following companion (not dismissed)")
        Return
    EndIf
    If SeverActionsNative.Native_IsActorInScene(akActor)
        DebugMsg("Home(B): skipping application - " + akActor.GetDisplayName() + " is in a vanilla scene; will retry once scene ends")
        SeverActionsNativeExt.Native_SetHomeSceneSuspended(akActor, true)
        Return
    EndIf
    SeverActionsNativeExt.Native_SetHomeSceneSuspended(akActor, false)

    Package homePkg = GetHomeSandboxBPackage()
    If !homePkg
        DebugMsg("ApplyHomeSandboxB: HomeSandboxB package missing (old ESP?)")
        Return
    EndIf

    ; Route B wins over a leftover legacy slot: strip it so exactly one home
    ; pull exists, or the constant prio-100 legacy pull beats the prio-110 work
    ; override whenever it lapses and the NPC walks home mid-shift.
    Int legacySlot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)
    If legacySlot >= 0
        Package legacyPkg = GetHomeSandboxPackage(legacySlot)
        If legacyPkg
            ActorUtil.RemovePackageOverride(akActor, legacyPkg)
        EndIf
        If HomeSlots && legacySlot < HomeSlots.Length
            HomeSlots[legacySlot].Clear()
        EndIf
        SeverActionsNative.Native_ReleaseHomeMarkerSlot(akActor)
        DebugMsg("ApplyHomeSandboxB: stripped legacy home slot " + legacySlot + " from " + akActor.GetDisplayName() + " (split-brain repair)")
    EndIf

    ActorUtil.AddPackageOverride(akActor, homePkg, 100, 1)
    akActor.SetAV("WaitingForPlayer", 2)
    SeverActionsNative.EscalatedReEvaluate(akActor, 1500)
    DebugMsg("ApplyHomeSandboxB: " + akActor.GetDisplayName())
EndFunction

Function ApplyHomeSandboxIfHomed(Actor akActor)
    {Framework dismiss paths: applies the home sandbox (legacy slot or Route B
     marker) if the NPC has a home; post-migration, fills the home alias.}
    If !akActor
        Return
    EndIf
    If SchedSystemActive()
        ; The hands-off dismiss leaves the teammate flag to her framework.
        If GetAssignedHome(akActor) != "" && FillSchedAlias(akActor, SCHEDULE_HOME, true)
            SeverActionsNative.EscalatedReEvaluate(akActor, 1500)
            DebugMsg("Filled home schedule alias for framework-dismissed " + akActor.GetDisplayName())
        EndIf
        Return
    EndIf
    Int slot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)
    If slot >= 0 && HomeMarkerList
        ObjectReference homeMarker = HomeMarkerList.GetAt(slot) as ObjectReference
        If homeMarker
            ApplyHomeSandbox(akActor, homeMarker, slot)
            DebugMsg("Applied home sandbox for framework-dismissed " + akActor.GetDisplayName() + " (slot " + slot + ")")
        EndIf
    ElseIf GetHomeMarkerB(akActor)
        ApplyHomeSandboxB(akActor)
        DebugMsg("Applied Route B home sandbox for framework-dismissed " + akActor.GetDisplayName())
    EndIf
EndFunction

; =============================================================================
; SCENE-AWARE HOME SUSPEND/RESTORE
; A vanilla BGSScene can pull an NPC into scripted behavior (Serana in her
; mother's lab); a home hold at the same time fights the scene and can break
; the quest. Each tick the hold is released for a homed NPC inside a scene and
; restored when it ends. Only BGSScene pulls are caught, not plain quest-alias
; packages or forced MoveTo overrides.
; =============================================================================

Function SuspendHomeSandbox(Actor akActor, Int slot)
    {Releases the home hold (alias or Route B override, and the track-only
     override) so a vanilla scene can drive the actor. The home assignment stays
     for CheckSceneSuspendedHomes to restore. Post-migration it empties the home
     schedule alias (slot ignored).}
    If !akActor
        Return
    EndIf
    If SchedSystemActive()
        EmptySchedAlias(akActor, SCHEDULE_HOME)
        If akActor.GetAV("WaitingForPlayer") == 2.0
            akActor.SetAV("WaitingForPlayer", 0)
        EndIf
        akActor.EvaluatePackage()
        Return
    EndIf
    If slot < 0
        ; Route B homed — the sandbox is a single shared override, not an alias.
        Package homePkgB = GetHomeSandboxBPackage()
        If homePkgB
            ActorUtil.RemovePackageOverride(akActor, homePkgB)
        EndIf
        akActor.SetAV("WaitingForPlayer", 0)
        akActor.EvaluatePackage()
        Return
    EndIf
    If !HomeSlots || slot >= HomeSlots.Length
        Return
    EndIf

    HomeSlots[slot].Clear()

    ; And the track-only override.
    If SeverActionsNativeExt2.Native_IsTrackOnlyFollower(akActor)
        Package homePkg = GetHomeSandboxPackage(slot)
        If homePkg
            ActorUtil.RemovePackageOverride(akActor, homePkg)
        EndIf
    EndIf

    ; Drop ApplyHomeSandbox's relax bias so the scene's package is not biased
    ; toward staying home.
    akActor.SetAV("WaitingForPlayer", 0)

    akActor.EvaluatePackage()
EndFunction

Function CheckSceneSuspendedHomes(Actor[] followers, Actor[] homed, Bool schedActive)
    {Per-tick scene-aware home suspend/restore: an NPC who entered a vanilla
     scene has the home hold released and the flag set; a suspended NPC whose
     scene ended gets the hour's hold back. Idempotent per actor.
     Alias era: Sched_GetSceneSuspendMismatched returns exactly the actors whose
     live scene state disagrees with the cosaved flag (home and 3D gates
     applied natively); followers and homed are unused. Route B: walks
     followers then homed, since eligibility reads GetHomeMarkerB (StorageUtil),
     which the native cannot see. Both lists matter: SendHome,
     ApplyHomeSandboxIfHomed and the load reapply can suspend any homed NPC.}

    If schedActive
        Actor[] mismatched = SeverActionsNativeExt2.Sched_GetSceneSuspendMismatched()
        If mismatched
            Int m = 0
            While m < mismatched.Length
                Actor npc = mismatched[m]
                ; The native includes suspended actors with no home so a
                ; suspend can always be undone; only the restore applies to them.
                Bool hasHome = (GetAssignedHome(npc) != "")
                If SeverActionsNativeExt.Native_GetHomeSceneSuspended(npc)
                    ; Scene ended: the reconcile picks the hour's type (a HOME fill here would sit beside work or relax).
                    SeverActionsNativeExt.Native_SetHomeSceneSuspended(npc, false)
                    If !IsRegisteredFollower(npc)
                        StorageUtil.SetIntValue(npc, KEY_LAST_SCHEDULED_TYPE, -99)
                        ReconcileSchedAliasesFor(npc)
                    EndIf
                    DebugMsg("Home scene-restored (scene ended): " + npc.GetDisplayName())
                ElseIf hasHome
                    ; Scene started: only a held HOME is released (a scene's packages outrank work and relax anyway).
                    If SeverActionsNativeExt.Native_GetSchedAliasIndex(npc, SCHEDULE_HOME) >= 0
                        SuspendHomeSandbox(npc, -1)
                        _NoteSchedHold(npc, SCHED_HOLD_SCENE)
                    EndIf
                    SeverActionsNativeExt.Native_SetHomeSceneSuspended(npc, true)
                    DebugMsg("Home scene-suspended (vanilla scene active): " + npc.GetDisplayName())
                EndIf
                m += 1
            EndWhile
        EndIf
        Return
    EndIf

    ; Route B only from here (pre-migration).
    Int pass = 0
    While pass < 2
        Actor[] list = followers
        If pass == 1
            list = homed
        EndIf
        Int i = 0
        While i < list.Length
            Actor follower = list[i]
            If follower != None && follower.Is3DLoaded()
                Int slot = SeverActionsNative.Native_GetHomeMarkerSlot(follower)
                Bool routeBHomed = (slot < 0 && GetHomeMarkerB(follower))
                If slot >= 0 || routeBHomed
                    Bool inScene = SeverActionsNative.Native_IsActorInScene(follower)
                    Bool wasSuspended = SeverActionsNativeExt.Native_GetHomeSceneSuspended(follower)

                    If inScene && !wasSuspended
                        ; Scene started: suspend (slot < 0 is the Route B variant).
                        SuspendHomeSandbox(follower, slot)
                        SeverActionsNativeExt.Native_SetHomeSceneSuspended(follower, true)
                        DebugMsg("Home scene-suspended (vanilla scene active): " + follower.GetDisplayName())
                    ElseIf !inScene && wasSuspended
                        ; Scene ended: restore (the apply clears the flag).
                        If routeBHomed
                            ApplyHomeSandboxB(follower)
                            DebugMsg("Home scene-restored (scene ended, Route B): " + follower.GetDisplayName())
                        ElseIf HomeMarkerList
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
        pass += 1
    EndWhile
EndFunction

Function RemoveHomeSandbox(Actor akActor)
    {Releases every home hold (legacy slot alias and override, Route B override,
     the schedule pool's home override and alias) and resets WaitingForPlayer,
     so follow packages take over (e.g. on re-recruitment).}
    If !akActor
        Return
    EndIf

    ; Legacy slot: the alias and a track-only override.
    Int slot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)
    If slot >= 0 && HomeSlots && slot < HomeSlots.Length
        Package homePkg = GetHomeSandboxPackage(slot)
        If homePkg
            ActorUtil.RemovePackageOverride(akActor, homePkg)
        EndIf
        HomeSlots[slot].Clear()
        DebugMsg("Cleared " + akActor.GetDisplayName() + " from HomeSlot_" + slot)
    EndIf

    ; Route B home override (shared package) — safe no-op when absent.
    Package homePkgB = GetHomeSandboxBPackage()
    If homePkgB
        ActorUtil.RemovePackageOverride(akActor, homePkgB)
    EndIf
    ; ...and the schedule pool's home V2 override (see EmptySchedAlias), which
    ; ClearHome would otherwise leave with no marker to anchor to.
    Package homeV2 = GetSchedPackageForType(SCHEDULE_HOME)
    If homeV2
        ActorUtil.RemovePackageOverride(akActor, homeV2)
    EndIf

    If SchedSystemActive()
        EmptySchedAlias(akActor, SCHEDULE_HOME)
    EndIf

    ; WaitingForPlayer 0 lets custom follower packages resume following.
    akActor.SetAV("WaitingForPlayer", 0)

    akActor.EvaluatePackage()
EndFunction

String Function GetAssignedHome(Actor akActor)
    {The assigned home name from the native cosave (the sole source); "" if none.}
    If !akActor
        Return ""
    EndIf
    Return SeverActionsNative.Native_GetHome(akActor)
EndFunction

Function ClearHome(Actor akActor)
    {Removes the home assignment: stands up a home sleeper, releases the claimed
     bed (restoring its owner), every home hold, the legacy marker slot and the
     Route B marker; a home-less NPC who keeps a work or relax spot goes to
     KEY_WORK_ONLY_NPCS.}
    If !akActor
        Return
    EndIf

    ; Stand a home sleeper up before the claim is released, or the furniture
    ; override keeps steering them at a bed that went back to its owner.
    If StorageUtil.GetIntValue(akActor, "SeverActions_HomeSleeping", 0) == 1
        SeverActions_FurnitureLib.Stop(akActor)
        StorageUtil.UnsetIntValue(akActor, "SeverActions_HomeSleeping")
    EndIf

    ; Release the bed before dropping home tracking: the native reads the bed
    ; and its original owner from FollowerDataStore.
    SeverActionsNative.Native_BedAssignment_Release(akActor)

    RemoveHomeSandbox(akActor)

    If SchedSystemActive() && !SeverActionsNative.Native_GetPlayLoc(akActor)
        ; A relax spot outlives the home; only a relax alias with no spot goes now.
        EmptySchedAlias(akActor, SCHEDULE_PLAY)
    EndIf

    ; Release the legacy marker slot (the marker stays in the holding cell).
    Int slot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)
    If slot >= 0 && HomeMarkerList
        SeverActionsNative.Native_ReleaseHomeMarkerSlot(akActor)
        DebugMsg("Home marker slot " + slot + " released for " + akActor.GetDisplayName())
    EndIf

    ; Route B: unlink + delete the per-NPC home marker.
    Keyword homeKwClr = GetHomeBAnchorKeyword()
    If homeKwClr
        SeverActionsNative.LinkedRef_Clear(akActor, homeKwClr)
    EndIf
    ObjectReference homeMarkerB = GetHomeMarkerB(akActor)
    If homeMarkerB
        homeMarkerB.Disable()
        homeMarkerB.Delete()
        StorageUtil.UnsetFormValue(akActor, KEY_HOMEB_MARKER)
    EndIf

    SeverActionsNative.Native_ClearHome(akActor)

    _RelistRoutine(akActor)
    StorageUtil.UnsetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE)

    DebugMsg("Home cleared for " + akActor.GetDisplayName())
EndFunction

Actor[] Function GetAllHomedNPCs()
    {The homed NPCs of the global list. Prunes a deleted actor, a form that is no actor and an entry whose home was
     cleared. Keeps an entry that does not resolve now: a non-persistent NPC in an unloaded cell resolves when it loads.}
    Int count = StorageUtil.FormListCount(None, KEY_HOMED_NPCS)
    Actor[] result = PapyrusUtil.ActorArray(0)
    Int i = 0
    While i < count
        Form entry = StorageUtil.FormListGet(None, KEY_HOMED_NPCS, i)
        Actor actorRef = entry as Actor
        If !entry
            i += 1
        ElseIf actorRef && !actorRef.IsDeleted() && GetAssignedHome(actorRef) != ""
            result = PapyrusUtil.PushActor(result, actorRef)
            i += 1
        Else
            ; By value, first instance only: the calls above can yield, so another stack may have shifted slot i (a
            ; stale form is stale in every slot).
            StorageUtil.FormListRemove(None, KEY_HOMED_NPCS, entry, false)
            count = StorageUtil.FormListCount(None, KEY_HOMED_NPCS)
        EndIf
    EndWhile
    Return result
EndFunction

Bool Function _RelistRoutine(Actor akActor)
    {Puts akActor on the roster her assignments call for: KEY_HOMED_NPCS with a home, KEY_WORK_ONLY_NPCS with only a
     work or relax spot, neither with none. True when a list changed.}
    If !akActor
        Return false
    EndIf
    Form f = akActor as Form
    Bool hasHome = GetAssignedHome(akActor) != ""
    Bool spotOnly = !hasHome && (SeverActionsNative.Native_GetWorkLoc(akActor) || SeverActionsNative.Native_GetPlayLoc(akActor))
    Bool changed = false
    If hasHome != StorageUtil.FormListHas(None, KEY_HOMED_NPCS, f)
        If hasHome
            StorageUtil.FormListAdd(None, KEY_HOMED_NPCS, f, false)
        Else
            StorageUtil.FormListRemove(None, KEY_HOMED_NPCS, f, true)
        EndIf
        changed = true
    EndIf
    If spotOnly != StorageUtil.FormListHas(None, KEY_WORK_ONLY_NPCS, f)
        If spotOnly
            StorageUtil.FormListAdd(None, KEY_WORK_ONLY_NPCS, f, false)
        Else
            StorageUtil.FormListRemove(None, KEY_WORK_ONLY_NPCS, f, true)
        EndIf
        changed = true
    EndIf
    If !hasHome && !spotOnly
        SeverActionsNativeExt2.Sched_NoteHold(akActor, 0)
    EndIf
    Return changed
EndFunction

Function _RelistAssignedRows()
    {Load-time heal of both schedule rosters from the native store: StorageUtil can drop values, and the native fast
     lane walks the store, so both lanes must see the same NPCs.}
    Actor[] rows = SeverActionsNativeExt2.Sched_GetAssignedRows()
    If !rows
        Return
    EndIf
    Int changed = 0
    Int i = 0
    While i < rows.Length
        If _RelistRoutine(rows[i])
            changed += 1
        EndIf
        i += 1
    EndWhile
    If changed > 0
        Debug.Trace("[SeverActions_FollowerManager] Schedule rosters: re-listed " + changed + " NPC(s) from the native store")
    EndIf
EndFunction

Function _ClearRelaxRelics()
    {One-shot per save (MIGR RelaxRelicClear v1), before the load relist: clears the relax spot of every NPC with no
     home who resolves at this load (one out of memory keeps hers). Until this has run, such a spot can only be an older ClearHome's leftover, which the relist would turn into
     a nightly relax. A home-less relax spot set after it is the player's and stays.}
    String kClaim = "RelaxRelicClear"
    If !SeverActionsNativeExt2.Migration_TryClaim(kClaim, 1)
        Return
    EndIf
    Actor[] rows = SeverActionsNativeExt2.Sched_GetAssignedRows()
    Int cleared = 0
    If rows
        Int i = 0
        While i < rows.Length
            Actor a = rows[i]
            If a && GetAssignedHome(a) == "" && SeverActionsNative.Native_GetPlayLoc(a)
                ClearRoutineLoc(a, "play")   ; its relist keeps a remaining work spot listed
                cleared += 1
            EndIf
            i += 1
        EndWhile
    EndIf
    SeverActionsNativeExt2.Migration_MarkDone(kClaim, 1)
    Debug.Trace("[SeverActions_FollowerManager] Relax relics: cleared the relax spot of " + cleared + " NPC(s) with no home")
EndFunction

Int Function GetHomedNPCCount()
    Return StorageUtil.FormListCount(None, KEY_HOMED_NPCS)
EndFunction

; =============================================================================
; COMBAT STYLE
; =============================================================================

String Function NormalizeCombatStyleName(String style)
    {Lower-cases a combat style name, maps coward synonyms to "coward" and strips
     the words LLMs append ("berserker combat style" -> "berserker"). The restore
     keyword "no combat style" passes unchanged. Mirrors NormalizePresetName in
     SeverActions_Outfit.psc.}
    String name = SeverActionsNative.StringToLower(style)

    ; The restore keyword contains both suffix words -- exact match wins.
    If name == "no combat style"
        Return name
    EndIf

    ; Coward synonyms: an unmapped name falls through to the Brave/Aggressive
    ; catch-all.
    If name == "cowardly" || name == "pacifist" || name == "pacifistic" || \
       name == "noncombatant" || name == "non-combatant" || name == "civilian" || \
       name == "passive" || name == "timid"
        Return "coward"
    EndIf

    String[] suffixes = new String[3]
    suffixes[0] = " style"
    suffixes[1] = " combat"
    suffixes[2] = " fighter"

    ; Loop so stacked suffixes shed one per pass ("berserker combat style"
    ; -> "berserker combat" -> "berserker").
    Bool stripped = true
    While stripped
        stripped = false
        Int len = StringUtil.GetLength(name)
        Int i = 0
        While i < suffixes.Length
            Int suffixLen = StringUtil.GetLength(suffixes[i])
            If len > suffixLen
                String tail = StringUtil.Substring(name, len - suffixLen, suffixLen)
                If tail == suffixes[i]
                    name = StringUtil.Substring(name, 0, len - suffixLen)
                    stripped = true
                    len = StringUtil.GetLength(name)
                EndIf
            EndIf
            i += 1
        EndWhile
    EndWhile

    Return name
EndFunction

Function SetCombatStyle(Actor akActor, String style)
    {Sets a follower's combat style: stores the normalized name natively and
     swaps the base CombatStyle ("no combat style" restores the original).
     Entering "healer" adds the heal spells, the healer faction and a native
     HealerPoll entry (which casts heals at HP-threshold targets every ~1s);
     leaving removes them.}
    If !akActor
        Return
    EndIf

    ; "healer style" must hit the style map and the healer transition too.
    String normalized = NormalizeCombatStyleName(style)
    String previous = SeverActionsNative.Native_GetCombatStyle(akActor)
    If previous == ""
        previous = "no combat style"
    EndIf

    SeverActionsNative.Native_SetCombatStyle(akActor, normalized)

    ; Healer-role changes bracket ApplyCombatStyleValues so the CSTY swap and the
    ; spells/faction stay in step.
    If previous == "healer" && normalized != "healer"
        RemoveHealerRole(akActor)
    EndIf

    ApplyCombatStyleValues(akActor, normalized)

    If normalized == "healer"
        ApplyHealerRole(akActor)
    EndIf

    If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
        If normalized == "no combat style"
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.revertedToNaturalCombat", ("" + akActor.GetDisplayName())))
        Else
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.willNowFightAsA", ("" + akActor.GetDisplayName()), ("" + style)))
        EndIf
    EndIf

    DebugMsg("Combat style set for " + akActor.GetDisplayName() + ": " + normalized)
EndFunction

Function ApplyCombatStyleValues(Actor akActor, String style)
    {Swaps the base CombatStyle to the style's CSTY (vanilla, or SeverActions'
     healer) and sets the matching actor values. Captures the original once.}
    If !akActor
        Return
    EndIf

    ActorBase npcBase = akActor.GetActorBase()
    If !npcBase
        Return
    EndIf

    ; Capture the original CSTY once, for restoring (None = not captured yet).
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

    ; "coward": a companion not there to fight. Restore their original CSTY and
    ; let the actor values below do the work (they are the values
    ; RegisterFollower boosts at recruit, so setting them by hand never sticks).
    If style == "coward"
        Form cowardOrig = SeverActionsNativeExt.Native_GetOrigCombatStyleForm(akActor)
        If cowardOrig
            CombatStyle cowardCS = cowardOrig as CombatStyle
            If cowardCS
                npcBase.SetCombatStyle(cowardCS)
            EndIf
        EndIf
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
    ; Old style-name aliases, still mapped
    ElseIf style == "aggressive"
        csFormID = 0x00016E25       ; csAlikrBerserker (dual-wield capable)
    ElseIf style == "defensive"
        csFormID = 0x0003CF5A       ; csHumanTankLvl1
    ElseIf style == "healer"
        ; The HealerCombatStyleForm property if set, else SeverActions' Healer
        ; CSTY (0x165342), else vanilla csHumanMagic. HealerPoll casts heals
        ; regardless; the CSTY governs positioning, other spells and fleeing.
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

    ; Actor values. "coward" is tested before the catch-all Else, which would
    ; make them Brave/Aggressive.
    If style == "coward"
        akActor.SetAV("Confidence", 0)  ; Cowardly    — flees rather than fights
        akActor.SetAV("Aggression", 0)  ; Unaggressive — never starts anything
        akActor.SetAV("Assistance", 0)  ; Helps Nobody — will not join your fights
    ElseIf style == "berserker" || style == "champion" || style == "aggressive"
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
    {Load fallback when the FollowerSystemHydrator did not run: re-applies each
     follower's combat-style values (NFF/EFF or a dismiss/recruit cycle can
     revert them) and re-registers healers with HealerPoll, whose roster is
     in memory only.}
    Int i = 0
    While i < followers.Length
        If followers[i]
            String style = GetCombatStyle(followers[i])
            If style != "no combat style" && style != "balanced"
                ApplyCombatStyleValues(followers[i], style)
                DebugMsg("Reapplied combat style '" + style + "' for " + followers[i].GetDisplayName())
            EndIf
            ; The spells and faction persist; the poll's roster does not.
            If style == "healer"
                SeverActionsNativeExt.Native_RegisterHealer(followers[i])
            EndIf
        EndIf
        i += 1
    EndWhile
EndFunction

; =============================================================================
; ESSENTIAL STATUS
; =============================================================================

Function ReapplyEssentialStatus(Actor[] followers)
    {Kept for external callers. Essential comes from quest alias slots
     (templated-safe) rather than the ActorBase flag: delegates to
     ReassignEssentialSlots.}
    ReassignEssentialSlots(followers)
EndFunction

; =============================================================================
; NATIVE CONFIG PUSH (healer, cell catch-up)
; =============================================================================

Function SyncHealerConfig()
    {Pushes the healer thresholds, multiplier, chance and cooldowns to the native
     poll (RAM-only there) on every load.}
    SeverActionsNativeExt.Native_SetHealerThresholds(HealerPlayerThreshold, HealerSelfThreshold, HealerAllyThreshold)
    SeverActionsNativeExt.Native_SetHealerMult(HealerMult)
    SeverActionsNativeExt.Native_SetHealerChance(HealerChance)
    SeverActionsNativeExt.Native_SetHealerCooldowns(HealerTargetCooldownMs, HealerCastCooldownMs, HealerVoiceCooldownMs)
    SeverActionsNativeExt.Native_SetBleedoutCheatHeal(HealerBleedoutCheatHeal)
EndFunction

Function SyncCellCatchupConfig()
    {Pushes the cell-catchup tunings to the native subsystem (RAM-only there) on
     every load.}
    SeverActionsNativeExt.Native_SetCellCatchupEnabled(CellCatchupEnabled)
    SeverActionsNativeExt.Native_SetCellCatchupGracePeriodMs(CellCatchupGracePeriodMs)
    SeverActionsNativeExt.Native_SetCellCatchupMaxFollowers(CellCatchupMaxFollowers)
    SeverActionsNativeExt.Native_SetCellCatchupOffsetRadius(CellCatchupOffsetRadius)
EndFunction

; =============================================================================
; HEALER ROLE
; =============================================================================

Function ApplyHealerRole(Actor akActor)
    {Makes the actor a healer: the HealOther/HealSelf spells (cast on the poll's
     SeverActionsNative_HealerCast event), SeverActions_HealerFaction (prompts
     read it) and a native HealerPoll entry. Idempotent.}
    If !akActor
        Return
    EndIf

    ; AddSpell twice is harmless.
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

    Faction healerFac = Game.GetFormFromFile(0x16023D, "SeverActions.esp") as Faction
    If healerFac && !akActor.IsInFaction(healerFac)
        akActor.AddToFaction(healerFac)
    EndIf

    SeverActionsNativeExt.Native_RegisterHealer(akActor)

    DebugMsg("ApplyHealerRole: " + akActor.GetDisplayName() + " configured as healer")
EndFunction

Function RemoveHealerRole(Actor akActor)
    {Reverse of ApplyHealerRole, on leaving the "healer" style. Idempotent.}
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
; Sent by the native HealerPoll (~1s in combat) for a healer that passed the
; target, cooldown and resource gates. sender = the healer; strArg =
; "<tier>|<target FormID as signed decimal>", tier player|self|ally|potion_fallback;
; numArg = the target FormID from an older DLL (a float, exact only to 2^24).

Event OnHealerCast(string eventName, string strArg, float numArg, Form sender)
    Actor healer = sender as Actor
    If !healer || healer.IsDead() || !healer.Is3DLoaded()
        Return
    EndIf

    String tier = strArg
    Actor target = None
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos >= 0
        tier = StringUtil.Substring(strArg, 0, pipePos)
        Int targetFid = StringUtil.Substring(strArg, pipePos + 1) as Int
        If targetFid != 0
            target = Game.GetFormEx(targetFid) as Actor
        EndIf
    EndIf
    If target == None && (numArg as Int) != 0
        ; Fallback: an older DLL still float-encodes the id in numArg.
        target = Game.GetFormEx(numArg as Int) as Actor
    EndIf
    If !target || target.IsDead()
        Return
    EndIf

    ; HealSelf for a self-cast (cheaper, self-target VFX), HealOther otherwise.
    Spell healSpell = None
    If tier == "self"
        healSpell = Game.GetFormFromFile(0x160240, "SeverActions.esp") as Spell
    Else
        healSpell = Game.GetFormFromFile(0x16023E, "SeverActions.esp") as Spell
    EndIf

    If !healSpell
        DebugMsg("OnHealerCast: heal spell not found, tier=" + tier)
        Return
    EndIf

    healSpell.Cast(healer, target)

    ; Bonus heal on top: (Restoration * 0.2 + Level + 74) * mult.
    Float bonus = SeverActionsNativeExt.Native_ComputeBonusHeal(healer)
    If bonus > 0.0
        target.RestoreActorValue("Health", bonus)
    EndIf

    ; Voice-line hook, cooldown-gated per healer (default 30s). Empty: nothing is
    ; spoken yet.
    If SeverActionsNativeExt.Native_ShouldEmitVoiceLine(healer)
    EndIf

    ; Stamp the target and healer cooldowns for the next poll.
    SeverActionsNativeExt.Native_NotifyHealApplied(healer, target)

    DebugMsg("OnHealerCast: " + healer.GetDisplayName() + " healed " + target.GetDisplayName() + \
        " (tier=" + tier + ", bonus=" + bonus + ")")
EndEvent

Function ApplyIgnoreFriendlyHits(Actor[] followers)
    {Re-apply IgnoreFriendlyHits on every load (Maintenance): the flag does not
     reliably survive save/load on mod-added followers. With the ESP's Ally reactions
     of SeverActions_FollowerFaction it keeps stray AoE / arrow / cloak hits from
     turning followers on each other or the player. Idempotent.}
    Int i = 0
    While i < followers.Length
        If followers[i]
            followers[i].IgnoreFriendlyHits(true)
        EndIf
        i += 1
    EndWhile
    DebugMsg("Re-applied IgnoreFriendlyHits to " + followers.Length + " followers")
EndFunction

; =============================================================================
; TRAP IMMUNITY — the vanilla LightFoot perk, granted to followers
;
; Vanilla's TrapTriggerBase / TrapBear checkPerks() test hasPerk(LightFoot) on
; whatever tripped the trap and skip it; LightFootTriggerPercent (0x00067194)
; ships at 100, so the roll always passes. Chosen over NFF's replacement trap
; scripts: no override of vanilla scripts, no conflict. Coverage: TrapBear checks
; the perk by default; TrapTriggerBase and DLC2TrapApoTentacle only where the level
; designer enabled it; tripwires and mod traps on their own scripts not at all.
; =============================================================================

Perk Function GetLightFootPerk() Global
    {Vanilla LightFoot (Skyrim.esm 0x0005820C), by FormID: runtime EditorIDs need
     po3 Tweaks, which has no VR build.}
    Return Game.GetFormFromFile(0x0005820C, "Skyrim.esm") as Perk
EndFunction

Function ApplyTrapImmunity(Actor akActor)
    {Grant LightFoot to one follower. Idempotent. Always on, no player setting: if
     one is ever added, gate this, RefreshTrapImmunity and a roster removal pass on
     ONE read of it, so they cannot disagree about its default.}
    If !akActor
        Return
    EndIf
    Perk lightFoot = GetLightFootPerk()
    If lightFoot && !akActor.HasPerk(lightFoot)
        akActor.AddPerk(lightFoot)
    EndIf
EndFunction

Function RemoveTrapImmunity(Actor akActor)
    {Take LightFoot back on dismissal; ungated, a dismissed follower never keeps it.
     Only ever called on a follower, so the player's own LightFoot is untouched.}
    If !akActor
        Return
    EndIf
    Perk lightFoot = GetLightFootPerk()
    If lightFoot && akActor.HasPerk(lightFoot)
        akActor.RemovePerk(lightFoot)
    EndIf
EndFunction

Function RefreshTrapImmunity(Actor[] followers)
    {Per-load re-apply from Maintenance(). AddPerk persists in the save; this covers
     followers recruited before the feature existed.}
    Perk lightFoot = GetLightFootPerk()
    If !lightFoot
        Return
    EndIf
    Int i = 0
    Int changed = 0
    While i < followers.Length
        Actor f = followers[i]
        If f && !f.HasPerk(lightFoot)
            f.AddPerk(lightFoot)
            changed += 1
        EndIf
        i += 1
    EndWhile
    DebugMsg("Trap immunity (LightFoot) — granted to " + changed + " of " + followers.Length + " followers")
EndFunction

Function ReapplyHomeSandboxing()
    {Per-load home reapply (Maintenance). With the schedule alias pools active only
     the runtime-only assist overrides (track-only V2 assists, guard-mode follow)
     need re-asserting (design doc §2.5-A); aliases persist natively. The legacy
     path below moves homed NPCs from AddPackageOverride into their HomeSlot alias.}
    If SchedSystemActive()
        ReapplyTrackOnlySchedAssists()
        Return
    EndIf
    If !HomeMarkerList || !HomeSlots
        DebugMsg("Home marker system not configured - skipping home sandbox check")
        Return
    EndIf

    Actor[] homedNPCs = GetAllHomedNPCs()
    Int migrated = 0
    Int i = 0
    While i < homedNPCs.Length
        Actor akActor = homedNPCs[i]
        ; A traveler is left to the journey (_OnJourney).
        If akActor && !IsRegisteredFollower(akActor) && !_OnJourney(akActor)
            Int slot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)

            If GetHomeMarkerB(akActor)
                ; Route B homed NPC: slot -1 is by design (AssignHome releases the
                ; legacy slot). Never migrate them: both home systems would be live
                ; and the prio-100 legacy home pull beats a lapsed prio-110 work
                ; override. ApplyHomeSandboxB re-applies Route B and strips any
                ; legacy slot.
                ApplyHomeSandboxB(akActor)
            Else
                ; No marker slot: acquire one, placed at the door ref (re-assigning
                ; the home while inside fixes the spot).
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
                                ; A fresh slot's TrueHomeAnchor still sits in the holding
                                ; cell (KEY_TRUEHOME_MIGRATED is pre-stamped, so
                                ; EnsureTrueHomeAnchorMigrated won't move it), and the next
                                ; home-hours swap would send the marker there. Anchor it here.
                                If TrueHomeAnchorList && slot < 40
                                    ObjectReference trueAnchor = TrueHomeAnchorList.GetAt(slot) as ObjectReference
                                    If trueAnchor
                                        trueAnchor.MoveTo(destRef)
                                    EndIf
                                EndIf
                            EndIf
                        EndIf
                    EndIf
                EndIf

                ; Has a slot but not the alias: force them in.
                If slot >= 0 && slot < HomeSlots.Length
                ObjectReference homeMarker = HomeMarkerList.GetAt(slot) as ObjectReference
                If homeMarker
                    Actor aliasActor = HomeSlots[slot].GetActorReference()
                    If aliasActor != akActor
                        ApplyHomeSandbox(akActor, homeMarker, slot)
                        migrated += 1
                        DebugMsg("Migrated " + akActor.GetDisplayName() + " into HomeSlot_" + slot)
                    Else
                        ; Already seated: re-set WaitingForPlayer=2, which a follower's
                        ; own OnInit can reset (Inigo forces -1 when not a teammate).
                        akActor.SetAV("WaitingForPlayer", 2)

                        ; Track-only: re-apply the PO3 override, which a cell transition
                        ; can drop (see Maintenance's ReapplyHomeSandboxing call).
                        If SeverActionsNativeExt2.Native_IsTrackOnlyFollower(akActor)
                            Package homePkg = GetHomeSandboxPackage(slot)
                            If homePkg
                                ActorUtil.AddPackageOverride(akActor, homePkg, 100, 1)
                            EndIf
                        EndIf

                        ; Always re-evaluate: an actor can land on a follower-framework
                        ; runtime package after load, and one force-eval is not enough.
                        SeverActionsNative.EscalatedReEvaluate(akActor, 1500)
                    EndIf
                EndIf
            EndIf
            ; closes the Route B If/Else
            EndIf
        EndIf
        i += 1
    EndWhile

    If migrated > 0
        DebugMsg("Home sandbox migration: " + migrated + " NPC(s) forced into aliases")
    EndIf
EndFunction

Function PatchUpVanillaFollowerStatus(Actor[] followers)
    {Every load (Maintenance): give each follower SA leads CurrentFollowerFaction rank 0
     and Ally relationship rank; hands-off followers keep their own. Vanilla follower
     checks and faction-gated YAMLs read the faction (SkyrimNet's is_follower does not:
     it reads IsPlayerTeammate).}
    Faction currentFollowerFaction = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
    If !currentFollowerFaction
        Return
    EndIf

    Actor player = Game.GetPlayer()
    Int i = 0
    While i < followers.Length
        Actor follower = followers[i]
        If follower
            ; Track-only followers manage CFF themselves (some keep rank -1 at all
            ; times), and in Tracking mode (D45) the vanilla follow AI does.
            If !IsFollowHandsOff(follower)
                If !follower.IsInFaction(currentFollowerFaction) || follower.GetFactionRank(currentFollowerFaction) < 0
                    follower.AddToFaction(currentFollowerFaction)
                    follower.SetFactionRank(currentFollowerFaction, 0)
                    DebugMsg("Patched CurrentFollowerFaction for " + follower.GetDisplayName())
                EndIf
            EndIf

            ; Same gate for the relationship rank.
            If !IsFollowHandsOff(follower)
                If follower.GetRelationshipRank(player) < 3
                    ; Remember the original rank once (-99 = not saved yet).
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
    {The combat style from the native cosave; empty or the legacy "balanced" value
     reads as "no combat style".}
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
; MEMBER ACTION FUNCTIONS (SkyrimNet YAML actions and UI verbs)
;
; SkyrimNet member-calls executionFunctionName on the quest script: never Global,
; and the parameter count must match the YAML parameterMapping exactly.
; =============================================================================

Function AdjustRelationship(Actor akActor, Int rapportChange, Int trustChange, Int loyaltyChange, Int moodChange)
    {Shift the four relationship axes (the Modify* functions clamp), rate-limited per
     actor by RelationshipCooldown. Called by the Actions page's adjustRelationship
     verb; no SkyrimNet action maps to it.}
    If !akActor || !IsRegisteredFollower(akActor)
        Return
    EndIf

    Float now = Utility.GetCurrentRealTime()
    Float lastAdjust = StorageUtil.GetFloatValue(akActor, KEY_LAST_REL_ADJUST, 0.0)
    If RelationshipCooldown > 0.0 && (now - lastAdjust) < RelationshipCooldown
        DebugMsg(akActor.GetDisplayName() + " relationship adjustment skipped (cooldown: " + ((RelationshipCooldown - (now - lastAdjust)) as Int) + "s remaining)")
        Return
    EndIf
    StorageUtil.SetFloatValue(akActor, KEY_LAST_REL_ADJUST, now)

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

    SyncRelationshipToNative(akActor)

    SeverActionsNativeExt.Native_SetInteractionTime(akActor, GetGameTimeInSeconds())

    ; Debug log only, never a SkyrimNet event: mechanics text would leak into
    ; get_recent_events and gameplay-meta diary/memory entries.
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
    {Dismiss and send home (dismissfollower.yaml). Player intent, so an NFF-owned
     follower is dismissed through NFF too.}
    UnregisterFollower(akActor, true, true)
EndFunction

Function CompanionWait(Actor akActor)
    {Wait and sandbox at the current location (waitforplayerhere.yaml). The YAML's first
     eligibility rule limits the LLM to the player's own followers, so a quest NPC is
     never parked under a priority-100 override; the wheel / UI paths are ungated.
     SIGNATURE IS A YAML CONTRACT (parameterMapping count): batch options go on
     _CompanionWaitCore.}
    _CompanionWaitCore(akActor, false)
EndFunction

Function _CompanionWaitCore(Actor akActor, Bool abQuiet)
    {The wait. abQuiet (Wait All) skips only the per-follower notification; the
     follow-state event stays per actor (each bio reads its own).
     - NFF-owned: NFF's own wait.
     - Hands-off (another framework, or Tracking mode): no SA package; strip stale SA
       state, then set WaitingForPlayer (Serana: through her own brain).
     - An NPC no framework leads in Tracking mode (_UnledInTracking): Sandbox(), as in SeverActions mode.
     - Otherwise SeverActions_Follow.Sandbox() does the package work.
     Stays in Papyrus: Sandbox() writes PapyrusUtil's override store, SkyrimNet's
     package registry and StorageUtil flags, none reachable from C++.}
    If !akActor
        Return
    EndIf

    ; A live journey would countermand this wait on arrival: cancel it first
    ; (afArg 0.0 = do not restore follow).
    SeverActions_ModuleBase.CallBool("travelcore", "cancelJourney", akActor, None, "", 0.0)
    ; Stale travel seat: see _CompanionFollowCore. A pinned pool package would
    ; outrank the wait.
    If SeverActionsNativeExt2.Travel_ReleaseStaleAliasFor(akActor)
        Debug.Trace("[SeverActions] CompanionWait: released stale travel alias for " + akActor.GetDisplayName())
    EndIf

    ; NFF-owned: NFF's own wait (its packages ignore the WaitingForPlayer AV).
    If SeverActionsNativeExt2.Native_IsNFFInstalled() && SeverActions_NFFLib.NFFWait(akActor)
        ; A safe-interior relax under NFF's wait is lifted, or its exit would move the
        ; waiter. A hands-off relax never wrote WaitingForPlayer.
        SeverActions_Follow followNff = GetFollowScript()
        If followNff && followNff.YieldSafeInteriorToWait(akActor, None)
            followNff.SetSandboxFlag(akActor, false)
            followNff.ClearWaitingFaction(akActor)
            akActor.EvaluatePackage()
        EndIf
        If SeverActionsNativeExt2.Settings_GetBool("showNotifications") && !abQuiet
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.isWaitingHereFor", ("" + akActor.GetDisplayName())))
        EndIf
        RegisterFollowStateEvent(akActor, "companion_waiting",             akActor.GetDisplayName() + " is waiting for " + Game.GetPlayer().GetDisplayName() + " at the current location.")
        Return
    EndIf

    ; Player-directed: Hearth's camp releases the actor instead of walking them
    ; back to the fire.
    Int waitEvt = ModEvent.Create("SeverActions_FollowerCalledByPlayer")
    If waitEvt
        ModEvent.PushString(waitEvt, "SeverActions_FollowerCalledByPlayer")
        ModEvent.PushString(waitEvt, "wait")
        ModEvent.PushFloat(waitEvt, 0.0)
        ModEvent.PushForm(waitEvt, akActor)
        ModEvent.Send(waitEvt)
    EndIf

    SeverActions_Follow followSys = GetFollowScript()

    If IsFollowHandsOff(akActor) && !_UnledInTracking(akActor)
        ; Hands-off (another framework, or Tracking mode - D45): strip any SA
        ; package a past call attached; their own package honours WaitingForPlayer.
        If followSys
            followSys.CompanionStopFollowing(akActor, false)
            followSys.StopSandbox(akActor)
        EndIf
        ; DLC-owned (Serana): wait through her own brain - Dawnguard zeroes a
        ; WaitingForPlayer it did not order (see FollowerFrameworkLib.WaitSerana).
        Bool dlcWaitRouted = false
        If SeverActionsNativeExt2.Native_GetFollowerOwner(akActor) == 3
            dlcWaitRouted = SeverActions_FollowerFrameworkLib.WaitSerana(akActor)
        EndIf
        If !dlcWaitRouted
            akActor.SetAV("WaitingForPlayer", 1)
        EndIf
        ; StopSandbox took a relax's package and sandbox flag but not its relax flag
        ; or the monitor's claim, whose exit would move the waiter.
        If followSys
            followSys.YieldSafeInteriorToWait(akActor, None)
        EndIf
        ; Release the schedule aliases (and the track-only assist override) so the
        ; schedule can't pull them to work/home mid-wait.
        EmptySchedAliasesForFollow(akActor)
        akActor.EvaluatePackage()
    ElseIf followSys
        followSys.Sandbox(akActor)
    Else
        ; No Follow script: the flag alone.
        akActor.SetAV("WaitingForPlayer", 1)
        akActor.EvaluatePackage()
    EndIf

    If SeverActionsNativeExt2.Settings_GetBool("showNotifications") && !abQuiet
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.isWaitingHereFor", ("" + akActor.GetDisplayName())))
    EndIf

    RegisterFollowStateEvent(akActor, "companion_waiting", \
        akActor.GetDisplayName() + " is waiting for " + Game.GetPlayer().GetDisplayName() + " at the current location.")
EndFunction

Function CompanionFollow(Actor akActor)
    {Resume following (resumefollowing.yaml). SIGNATURE IS A YAML CONTRACT
     (parameterMapping count): batch options go on _CompanionFollowCore.}
    _CompanionFollowCore(akActor, false)
EndFunction

Function _CompanionFollowCore(Actor akActor, Bool abQuiet)
    {The resume. abQuiet (Follow All) skips only the per-follower notification.
     - Hands-off: NFF / Serana resume through their own framework, SA state is
       stripped, WaitingForPlayer cleared.
     - Registered companions: CompanionStartFollowing (alias + LinkedRef).
     - Casual followers: StopSandbox + StartFollowing.
     For an NPC no framework leads in Tracking mode this only ends SA's wait; her schedule takes her back.}
    If !akActor
        Return
    EndIf
    Bool stopsWaitingOnly = _UnledInTracking(akActor)

    ; Drop the work package and every SA sandbox that outranks follow (~50); the
    ; assignments are kept for after dismissal.
    ClearWorkSandboxForFollow(akActor)
    StripSandboxesForFollow(akActor)

    ; Break out of camp / wait / travel holds before resuming:
    ;  - cancelJourney tears down any journey or wait (the arrival sandbox, the
    ;    travel LinkedRef, the OrphanCleanup entry); afArg 0.0 = do not restore
    ;    follow, it is re-applied below.
    ;  - FollowerCalledByPlayer makes Hearth's camp untrack and release the actor,
    ;    so CampTick stops returning them to the fire.
    SeverActions_ModuleBase.CallBool("travelcore", "cancelJourney", akActor, None, "", 0.0)
    ; cancelJourney only reaches live journeys; a completed one whose pool alias
    ; never emptied leaves the priority-106 pool package outranking follow.
    If SeverActionsNativeExt2.Travel_ReleaseStaleAliasFor(akActor)
        Debug.Trace("[SeverActions] CompanionFollow: released stale travel alias for " + akActor.GetDisplayName())
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

    If IsFollowHandsOff(akActor)
        ; Hands-off (D45): strip any SA package a past call attached, clear the
        ; wait flag and let their own package take over.
        ; WAIT AND RESUME MUST STAY SYMMETRIC: NFFWait is NFF's own wait state,
        ; which the WaitingForPlayer AV does not reach - only NFFResume un-parks.
        If SeverActionsNativeExt2.Native_IsNFFInstalled()
            SeverActions_NFFLib.NFFResume(akActor)
        EndIf
        If followSys
            followSys.CompanionStopFollowing(akActor, false)
            followSys.StopSandbox(akActor)
        EndIf
        ; Serana's wait went through her brain, so resume through StopWaiting():
        ; the raw AV alone leaves her IsWaiting set and her 72h release timer armed.
        If SeverActionsNativeExt2.Native_GetFollowerOwner(akActor) == 3
            SeverActions_FollowerFrameworkLib.ResumeSerana(akActor)
        EndIf
        ; CompanionStopFollowing's refill re-seated an unled NPC's schedule (WaitingForPlayer 2), which StopSandbox then
        ; zeroed: a holder gets SA's 2 back.
        If stopsWaitingOnly && HoldsAnySchedAlias(akActor)
            akActor.SetAV("WaitingForPlayer", 2)
        Else
            akActor.SetAV("WaitingForPlayer", 0)
        EndIf
        akActor.EvaluatePackage()
    ElseIf followSys
        If IsRegisteredFollower(akActor)
            followSys.CompanionStartFollowing(akActor)
        Else
            followSys.StopSandbox(akActor)
            followSys.StartFollowing(akActor)
        EndIf
    Else
        ; No Follow script: the flag alone.
        akActor.SetAV("WaitingForPlayer", 0)
        akActor.EvaluatePackage()
    EndIf

    If SeverActionsNativeExt2.Settings_GetBool("showNotifications") && !abQuiet
        If stopsWaitingOnly
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.stopsWaiting", ("" + akActor.GetDisplayName())))
        Else
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.isFollowingYouAgain", ("" + akActor.GetDisplayName())))
        EndIf
    EndIf

    If stopsWaitingOnly
        RegisterFollowStateEvent(akActor, "companion_stopped_waiting", \
            akActor.GetDisplayName() + " stopped waiting for " + Game.GetPlayer().GetDisplayName() + ".")
    Else
        RegisterFollowStateEvent(akActor, "companion_resumed_following", \
            akActor.GetDisplayName() + " stopped waiting and is following " + Game.GetPlayer().GetDisplayName() + " again.")
    EndIf
EndFunction

Function FollowerLeaves(Actor akActor)
    {A companion leaves on their own after sustained mistreatment (followerleaves.yaml).}
    If !akActor
        Return
    EndIf

    ; Hard gate: the YAML's "extremely rare" only steers the stock LLM; a
    ; story-hungry action selector fires this on well-treated companions. Above
    ; the leaving threshold they refuse, narrated so the chosen beat still lands.
    If GetRapport(akActor) > LeavingThreshold
        SkyrimNetApi.RegisterEvent("follower_stays",             akActor.GetDisplayName() + " grumbles, but has no real cause to walk out on " + Game.GetPlayer().GetDisplayName() + " - things between them are nowhere near that bad.",             akActor, Game.GetPlayer())
        Debug.Trace("[SeverActions_FollowerManager] FollowerLeaves refused - rapport above leaving threshold for " + akActor.GetDisplayName())
        Return
    EndIf

    SkyrimNetApi.RegisterEvent("follower_left_voluntarily", \
        akActor.GetDisplayName() + " has decided to leave " + Game.GetPlayer().GetDisplayName() + "'s service.", \
        akActor, Game.GetPlayer())

    ; A real departure, so NFF's claim comes down with ours.
    UnregisterFollower(akActor, true, true)
EndFunction

Bool Function LeaveToAttack(Actor akActor, Actor akTarget)
    {A companion turning on the player or another companion (this module's "leaveToAttack"
     service: Combat's AttackTarget, Enterprises' RenounceCampOath): they leave the player's
     service first, NFF's seat included, so the friendly-fire guard lets the fight happen. No
     send-home: they are about to fight. Against the player, the Ally rank the recruit gave
     goes too. True when they were on the roster.}
    If !akActor || !akTarget || !IsRegisteredFollower(akActor)
        Return False
    EndIf
    Actor player = Game.GetPlayer()
    SkyrimNetApi.RegisterEvent("follower_turned", \
        akActor.GetDisplayName() + " turned on " + akTarget.GetDisplayName() + " and left " + player.GetDisplayName() + "'s service.", \
        akActor, akTarget)
    UnregisterFollower(akActor, false, true)
    ; UnregisterFollower keeps the higher of the recruit's rank and the original; a companion
    ; who turned on the player keeps neither.
    If akTarget == player && akActor.GetRelationshipRank(player) > 0
        akActor.SetRelationshipRank(player, 0)
    EndIf
    Return True
EndFunction

Bool Function _KeepAfterFriendlyFire(Actor akActor)
    {Vanilla FollowerAliasScript dismisses its alias's follower the moment they target the
     player. The drain calls this when the friendly-fire guard caught that turn as the removal
     arrived (FriendlyFire_TakeForgiven): seat them in the vanilla alias again instead of
     losing them, with the bow and arrows a "Follow me" recruit keeps. Only the vanilla alias
     dismisses this way: NFF and SFF replace the quest, and DLC and custom-AI followers answer
     to their own AI. True when they were re-seated.}
    If !akActor || akActor.IsDead()
        Return False
    EndIf
    If SeverActionsNativeExt2.Native_IsNFFInstalled() || SeverActions_FollowerFrameworkLib.HasSFF()
        Return False
    EndIf
    Int owner = SeverActionsNativeExt2.Native_GetFollowerOwner(akActor)
    If owner == 2 || owner == 3 || owner == 4 || SeverActions_FollowerFrameworkLib.IsSerana(akActor)
        Return False
    EndIf
    If !SeverActions_FollowerFrameworkLib.SeatViaVanillaDialogue(akActor, WasSALedRecruit(akActor))
        Return False
    EndIf
    akActor.IgnoreFriendlyHits(true)
    If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.staysWithYou", ("" + akActor.GetDisplayName())))
    EndIf
    Return True
EndFunction

; =============================================================================
; KIDNAP SYSTEM - moved to SeverActions_Kidnap (the arrest module, P6-01). Each
; moved function stays below as a safe-exit stub for a frame an old save resumes
; (F7). The live ReconcileCustomAIOverrides / OnGameLoaded and the leash forwarders
; sit among them. GetArrestScript has no stub (R6; fomod/removed_functions.json).
; =============================================================================

Function KidnapMaintenance()
    {Safe-exit stub: moved to SeverActions_Kidnap.KidnapMaintenance (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Quest Function GetCaptiveQuest()
    {Safe-exit stub: moved to SeverActions_Kidnap.GetCaptiveQuest (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
    Return None
EndFunction

ReferenceAlias Function GetCaptiveAlias(Int aiIndex)
    {Safe-exit stub: moved to SeverActions_Kidnap.GetCaptiveAlias (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
    Return None
EndFunction

Int Function FindFreeCaptiveAlias()
    {Safe-exit stub: moved to SeverActions_Kidnap.FindFreeCaptiveAlias (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
    Return 0
EndFunction

Function _FreeCaptiveAlias(Actor akVictim)
    {Safe-exit stub: moved to SeverActions_Kidnap._FreeCaptiveAlias (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function SweepCaptiveAliasesOnLoad()
    {Safe-exit stub: moved to SeverActions_Kidnap.SweepCaptiveAliasesOnLoad (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function KidnapTick(Bool abFromLoad = false)
    {Safe-exit stub: moved to SeverActions_Kidnap.KidnapTick (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function KidnapNPC(Actor akKidnapper, String targetName, String destination)
    {Safe-exit stub: moved to SeverActions_Kidnap.KidnapNPC (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

; _LaunchGrabLeg has no stub (fomod/removed_functions.json): its signature named
; SeverActions_Travel, which this script may not name (DR2).

Function NarrateRestrainedInPlace(Actor akVictim, Actor akCaptor)
    {Safe-exit stub: moved to SeverActions_Kidnap.NarrateRestrainedInPlace (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Bool Function PlayerRestrainOnSpot(Actor akVictim, Bool abDeferNarration = false)
    {Safe-exit stub: moved to SeverActions_Kidnap.PlayerRestrainOnSpot (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
    Return False
EndFunction

Function RestrainNPC(Actor akRestrainer, String targetName)
    {Safe-exit stub: moved to SeverActions_Kidnap.RestrainNPC (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function HandleRestrainArrived(Actor akRestrainer)
    {Safe-exit stub: moved to SeverActions_Kidnap.HandleRestrainArrived (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function HandleKidnapGrabArrived(Actor akKidnapper)
    {Safe-exit stub: moved to SeverActions_Kidnap.HandleKidnapGrabArrived (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function _EndRestrainApproach(Actor akRestrainer)
    {Safe-exit stub: moved to SeverActions_Kidnap._EndRestrainApproach (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function _AbortRestrainApproach(Actor akVictim)
    {Safe-exit stub: moved to SeverActions_Kidnap._AbortRestrainApproach (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function MoveCaptive(Actor akEscort, String targetName, String destination)
    {Safe-exit stub: moved to SeverActions_Kidnap.MoveCaptive (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function MoveCaptiveHere(Actor akEscort, String captiveName)
    {Safe-exit stub: moved to SeverActions_Kidnap.MoveCaptiveHere (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function DemandRansom(Actor akSpeaker, String targetName, Int aiAmount = 0)
    {Safe-exit stub: moved to SeverActions_Kidnap.DemandRansom (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function _ResolveRansom(Actor akVictim)
    {Safe-exit stub: moved to SeverActions_Kidnap._ResolveRansom (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Actor Function _GetHoldSteward(Faction akCrimeFac)
    {Safe-exit stub: moved to SeverActions_Kidnap._GetHoldSteward (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
    Return None
EndFunction

Function _TearDownHold(Actor akVictim)
    {Safe-exit stub: moved to SeverActions_Kidnap._TearDownHold (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function HandleKidnapTravelComplete(Actor npc, String tag, String status)
    {Safe-exit stub: moved to SeverActions_Kidnap.HandleKidnapTravelComplete (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function _KidnapLegWatchdog(Actor akKidnapper, Actor akVictim, ObjectReference akGoal, Bool abTimeJumped = false)
    {Safe-exit stub: moved to SeverActions_Kidnap._KidnapLegWatchdog (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function _EndDispatchAliases(Actor akKidnapper, Actor akVictim)
    {Safe-exit stub: moved to SeverActions_Kidnap._EndDispatchAliases (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function SyncAllPremisesFromWork()
    {Safe-exit stub: the body moved to SeverActions_Enterprises (P9-03, plan B21).}
    ; M-I-STUB 3.9.14-beta25 (P9-03): moved to SeverActions_Enterprises
EndFunction

Function ReconcileCustomAIOverrides()
    {Every load (OnGameLoaded): push any actor on the StorageUtil custom-AI override
     list that the native 'CAIO' set lacks back into it (a belt, plan R2). Init K1
     seeds CAIO once per save and SetCustomAIOverride writes both copies; this covers
     a save whose CAIO record was lost while the migration ledger survived. Pushing
     only adds, so a cleared override never returns.}
    Int n = StorageUtil.FormListCount(None, "SeverActions_CustomAIOverrideList")
    Int pushed = 0
    Int i = 0
    While i < n
        Actor ovA = StorageUtil.FormListGet(None, "SeverActions_CustomAIOverrideList", i) as Actor
        If ovA && !SeverActionsNativeExt2.Native_HasCustomAIOverride(ovA)
            SeverActionsNativeExt2.Native_SetCustomAIOverride(ovA, true)
            pushed += 1
        EndIf
        i += 1
    EndWhile
    If pushed > 0
        Debug.Trace("[SeverActions_FollowerManager] Custom-AI overrides missing from the native record pushed back (" + pushed + " of " + n + ")")
    EndIf
EndFunction

Function OnGameLoaded()
    {Load recovery, run by the followers provider's stage 2 (SeverActions_Mod_Followers;
     an OnPlayerLoadGame here would be dead code on a Quest script). Only the custom-AI
     belt is left: the leash-version notice is SeverActions_Mod_Arrest's, the premises
     re-derivation SeverActions_Enterprises.Maintenance's, the captivity-sandbox sweep
     SeverActions_Arrest.OnGameLoaded's.}
    ReconcileCustomAIOverrides()
EndFunction

Function _EndGuardDuty(Actor akKidnapper)
    {Safe-exit stub: moved to SeverActions_Kidnap._EndGuardDuty (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function _EndKidnapTravel(Actor akKidnapper)
    {Safe-exit stub: moved to SeverActions_Kidnap._EndKidnapTravel (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function _OnKidnapGrabResolved(Actor akKidnapper)
    {Safe-exit stub: moved to SeverActions_Kidnap._OnKidnapGrabResolved (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function _OnKidnapTransportResolved(Actor akKidnapper, String status)
    {Safe-exit stub: moved to SeverActions_Kidnap._OnKidnapTransportResolved (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function _BindCaptive(Actor akVictim, Actor akKidnapper, Bool abGuard = true, Bool abSilent = false)
    {Safe-exit stub: moved to SeverActions_Kidnap._BindCaptive (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function _FireKidnapReleaseConsequences(Actor akVictim)
    {Safe-exit stub: moved to SeverActions_Kidnap._FireKidnapReleaseConsequences (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Bool Function _IsCaptiveGuarded(Actor akVictim)
    {Safe-exit stub: moved to SeverActions_Kidnap._IsCaptiveGuarded (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
    Return False
EndFunction

Function _DeleteKidnapHomeMarker(Actor akVictim)
    {Safe-exit stub: moved to SeverActions_Kidnap._DeleteKidnapHomeMarker (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function _EscapeCaptive(Actor akVictim)
    {Safe-exit stub: moved to SeverActions_Kidnap._EscapeCaptive (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function _OnCaptiveDied(Actor akVictim)
    {Safe-exit stub: moved to SeverActions_Kidnap._OnCaptiveDied (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function InterrogateCaptive(Actor akInterrogator, String targetName)
    {Safe-exit stub: moved to SeverActions_Kidnap.InterrogateCaptive (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function TieCaptiveToFurniture(Actor akSpeaker, String targetName, String furnitureFormId)
    {Safe-exit stub: moved to SeverActions_Kidnap.TieCaptiveToFurniture (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function HandleTieArrived(Actor akSpeaker)
    {Safe-exit stub: moved to SeverActions_Kidnap.HandleTieArrived (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function _EndTieApproach(Actor akSpeaker, Actor akVictim)
    {Safe-exit stub: moved to SeverActions_Kidnap._EndTieApproach (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function _ExpireStaleTie(Actor akVictim)
    {Safe-exit stub: moved to SeverActions_Kidnap._ExpireStaleTie (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function _CompleteFurnitureTie(Actor akSpeaker, Actor akVictim, ObjectReference akFurn)
    {Safe-exit stub: moved to SeverActions_Kidnap._CompleteFurnitureTie (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Actor Function _ResolveCaptiveByName(String targetName)
    {Safe-exit stub: moved to SeverActions_Kidnap._ResolveCaptiveByName (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
    Return None
EndFunction

String Function _NameClause(String targetName)
    {Safe-exit stub: moved to SeverActions_Kidnap._NameClause (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
    Return ""
EndFunction

Bool Function LeashCaptive(Actor akVictim, Actor akLeader, Bool abJustBound = false)
    {Safe-exit stub: moved to SeverActions_Kidnap.LeashCaptive (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
    Return False
EndFunction

ObjectReference Function _GetFurnitureTie(Actor akVictim)
    {Safe-exit stub: moved to SeverActions_Kidnap._GetFurnitureTie (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
    Return None
EndFunction

Bool Function _PlayBoundPose(Actor akVictim)
    {Safe-exit stub: moved to SeverActions_Kidnap._PlayBoundPose (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
    Return False
EndFunction

Function _ClearFurnitureTie(Actor akVictim)
    {Safe-exit stub: moved to SeverActions_Kidnap._ClearFurnitureTie (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

; -- The rope helpers live in SeverActions_LeashLib (P3-06), the only script naming
; LeashFramework. These forwarders keep the old names for old frames (F7), each behind
; Native_IsLeashFrameworkInstalled (check 6, trap leashlib-ungated). The library's
; KIDNAP_FLAG_* / rope-length / hand-chain literals mirror SeverActions_Kidnap's
; constants - keep them equal.

Function WarnIfLeashFrameworkOutdated()
    {Forwarder; the body lives in SeverActions_LeashLib.WarnIfOutdated.}
    ; M-I-STUB 3.9.14-beta25 (P3-06): forwards to SeverActions_LeashLib.WarnIfOutdated
    If SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled()
        SeverActions_LeashLib.WarnIfOutdated()
    EndIf
EndFunction

Bool Function LeashFrameworkActive()
    {Setting on AND the framework present (DLL loaded + Leash.esm).}
    ; M-I-STUB 3.9.14-beta25 (P3-06): forwards to SeverActions_LeashLib.Active
    Return SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled() && SeverActions_LeashLib.Active()
EndFunction

Bool Function LeashWristAvailable()
    {The 1.1.1 hand leash is installed (lead by the wrists, not the neck).}
    ; M-I-STUB 3.9.14-beta25 (P3-06): forwards to SeverActions_LeashLib.WristAvailable
    Return SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled() && SeverActions_LeashLib.WristAvailable()
EndFunction

Armor Function _LeashArmorForStyle(Int aiStyle)
    {The Leash.esm collar for a style index (0 rope / 1 chain / 2 runes).}
    ; M-I-STUB 3.9.14-beta25 (P3-06): forwards to SeverActions_LeashLib.ArmorForStyle
    Armor collar
    If SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled()
        collar = SeverActions_LeashLib.ArmorForStyle(aiStyle)
    EndIf
    Return collar
EndFunction

Function _RemoveHandLeashFrom(Actor akHolder)
    {Take the hand chain off a holder who is no longer leading anyone.}
    ; M-I-STUB 3.9.14-beta25 (P3-06): forwards to SeverActions_LeashLib.RemoveHandLeashFrom
    If SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled()
        SeverActions_LeashLib.RemoveHandLeashFrom(akHolder)
    EndIf
EndFunction

Function _RemoveLeashArmor(Actor akVictim)
    {Strip every collar variant (the style may have changed mid-leash).}
    ; M-I-STUB 3.9.14-beta25 (P3-06): forwards to SeverActions_LeashLib.RemoveLeashArmor
    If SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled()
        SeverActions_LeashLib.RemoveLeashArmor(akVictim)
    EndIf
EndFunction

Bool Function _AttachPhysicalLeash(Actor akVictim, Actor akHolder)
    {Rope from a HOLDER to a captive, by whichever of the two attachments the
     installed framework supports (the why is on SeverActions_LeashLib.Attach).}
    ; M-I-STUB 3.9.14-beta25 (P3-06): forwards to SeverActions_LeashLib.Attach
    Return SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled() && SeverActions_LeashLib.Attach(akVictim, akHolder)
EndFunction

Function _DetachPhysicalLeash(Actor akVictim)
    {Rope off, collar out of the inventory; the library clears the marks and the store
     mirror. Without the framework this does nothing: SeverActions_Kidnap's own detach
     paths clear the marks (its _ClearLeashMarks).}
    ; M-I-STUB 3.9.14-beta25 (P3-06): forwards to SeverActions_LeashLib.Detach
    If SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled()
        SeverActions_LeashLib.Detach(akVictim)
    EndIf
EndFunction

Function _ClearLeashMarks(Actor akVictim)
    {Safe-exit stub: moved to SeverActions_Kidnap._ClearLeashMarks (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Bool Function _IsOurLeashSubject(Actor akActor)
    {Safe-exit stub: moved to SeverActions_Kidnap._IsOurLeashSubject (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
    Return False
EndFunction

Function _RecoverBoundPoseAfterRagdoll(Actor akVictim)
    {Safe-exit stub: moved to SeverActions_Kidnap._RecoverBoundPoseAfterRagdoll (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function _NarrateLeashPull(Actor akVictim, Bool abRagdoll, Float afDistance)
    {Safe-exit stub: moved to SeverActions_Kidnap._NarrateLeashPull (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function UnleashCaptive(Actor akVictim)
    {Safe-exit stub: moved to SeverActions_Kidnap.UnleashCaptive (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function UntieCaptive(Actor akSpeaker, String targetName)
    {Safe-exit stub: moved to SeverActions_Kidnap.UntieCaptive (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function _AbortKidnapForVictim(Actor akVictim, Actor akKidnapper)
    {Safe-exit stub: moved to SeverActions_Kidnap._AbortKidnapForVictim (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function _AbortKidnap(Actor akKidnapper)
    {Safe-exit stub: moved to SeverActions_Kidnap._AbortKidnap (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Bool Function _RejectInvalidCaptiveTarget(Actor akActor, Actor akTarget, String verbPhrase)
    {Safe-exit stub: moved to SeverActions_Kidnap._RejectInvalidCaptiveTarget (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
    Return False
EndFunction

Bool Function _RejectIfActorOccupied(Actor akActor, String verbPhrase)
    {Safe-exit stub: moved to SeverActions_Kidnap._RejectIfActorOccupied (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
    Return False
EndFunction

Function _PacifyCaptive(Actor akVictim)
    {Safe-exit stub: moved to SeverActions_Kidnap._PacifyCaptive (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Bool Function _RejectIfBoundActor(Actor akActor, String verbPhrase)
    {Safe-exit stub: moved to SeverActions_Kidnap._RejectIfBoundActor (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
    Return False
EndFunction

Function ReleaseCaptive(Actor akActor, String targetName)
    {Safe-exit stub: moved to SeverActions_Kidnap.ReleaseCaptive (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

Function _UnbindCaptive(Actor akVictim)
    {Safe-exit stub: moved to SeverActions_Kidnap._UnbindCaptive (P6-01).}
    ; M-I-STUB 3.9.14-beta25 (P6-01): moved to SeverActions_Kidnap, plan P6
EndFunction

; =============================================================================
; HELPER FUNCTIONS
; =============================================================================

Float Function GetGameTimeInSeconds()
    {Current game time in game seconds (days * 24 * SECONDS_PER_GAME_HOUR).}
    Return Utility.GetCurrentGameTime() * 24.0 * SECONDS_PER_GAME_HOUR
EndFunction

SeverActions_FollowerManager Function GetInstance() Global
    Return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_FollowerManager
EndFunction

SeverActions_Follow Function GetFollowScript()
    {The Follow script on this same quest (0x000D62); the same module, so the cast
     is DR2-clean.}
    Return (Self as Quest) as SeverActions_Follow
EndFunction

; GetTravelScript has no stub (fomod/removed_functions.json): SeverActions_Travel is
; outside the followers closure (DR2). Cancel a journey through the travelcore
; provider: SeverActions_ModuleBase.CallBool("travelcore", "cancelJourney", ...).

; =============================================================================
; QUEST AWARENESS - the DLL dispatches the summaries and completion memories
; itself (QuestAwarenessStore, SkyrimNet API v8+; P2-10). Two safe-exit stubs remain.
; =============================================================================

Function ProcessNextSummaryRequest()
    ; M-I-STUB 3.9.14-beta25 (P2-10): the queue this drained is gone; nothing to do.
EndFunction

Function OnQuestSummaryGenerated(String response, Int success)
    ; M-I-STUB 3.9.14-beta25 (P2-10): the callback of a SendCustomPromptToLLM the pump sent; nothing to route.
EndFunction

; =============================================================================
; UTILITY FUNCTIONS
; =============================================================================

Int Function ClampAssessDelta(Int value, Int limit)
    {Safe-exit stub: moved to SeverActions_CompanionMind.ClampAssessDelta (P7-01).}
    ; M-I-STUB 3.9.14-beta25 (P7-01): moved to SeverActions_CompanionMind, plan P7
    Return 0
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
    If SeverActionsNativeExt2.Settings_GetBool("debugMode")
        Debug.Trace("[SeverActions_FollowerManager] " + msg)
    EndIf
EndFunction

Int Property FollowStateTTLMs = 300000 Auto
{How long a wait/resume line stays in scene context (ms).}

Function RegisterFollowStateEvent(Actor akActor, String asType, String asText)
    {Twin of SeverActions_Follow.RegisterFollowStateEvent (same follow_state_<fid>
     replace key; keep the two in step): the newest wait/follow line replaces the last.}

    If akActor == None
        Return
    EndIf
    SkyrimNetApi.RegisterShortLivedEvent("follow_state_" + akActor.GetFormID(), \
        asType, asText, "", FollowStateTTLMs, akActor, Game.GetPlayer())
EndFunction

; ============================================================================
; INTIMACY GATES (surfacing only; intimate history is tracked only on the NSFW
; sibling's SexualHistoryStore). Both properties are legacy hosts of settings rows:
; the Authority and the native IntimacyGate hold the live values.
; ============================================================================

Bool Property IntimateHistoryEnabled = true Auto
{Master toggle for the intimacy prompt sections (0046 consent posture, the
 persona/trade decorators). Setting key intimacyEnabled.}

Int Property IntimacyGenderGate = 1 Auto
{Whose bio renders the intimacy sections: 0 everyone, 1 women only, 2 men only.
 Setting key intimacyGenderGate.}

; -----------------------------------------------------------------------------
; Safe-exit stubs (M-I, check 20): functions v3.9.14-beta25 shipped and the tree
; dropped. A saved frame can still call them (F7); each answers a safe default.
; Never remove one (R17; registry fomod/safe_exit_stubs.json).
; -----------------------------------------------------------------------------

Int Function ExtractJsonInt(String json, String jsonKey)
    {Safe-exit stub: the hand-rolled JSON parser; Json_GetInt (kernel, P2-09) replaced it.}
    ; M-I-STUB 3.9.14-beta25 (P3-08): the hand-rolled JSON parser
    Return 0
EndFunction

Int Function ExtractJsonIntAt(String json, String jsonKey, Int searchStart)
    {Safe-exit stub: the hand-rolled JSON parser; Json_GetInt replaced it.}
    ; M-I-STUB 3.9.14-beta25 (P3-08): the hand-rolled JSON parser
    Return 0
EndFunction

String Function ExtractJsonString(String json, String jsonKey)
    {Safe-exit stub: the hand-rolled JSON parser; Json_GetString replaced it.}
    ; M-I-STUB 3.9.14-beta25 (P3-08): the hand-rolled JSON parser
    Return ""
EndFunction

String Function ExtractJsonStringAt(String json, String jsonKey, Int searchStart)
    {Safe-exit stub: the hand-rolled JSON parser; Json_GetString replaced it.}
    ; M-I-STUB 3.9.14-beta25 (P3-08): the hand-rolled JSON parser
    Return ""
EndFunction

Int Function FindUnescapedQuote(String s, Int startIdx)
    {Safe-exit stub: the hand-rolled JSON parser's helper.}
    ; M-I-STUB 3.9.14-beta25 (P3-08): the hand-rolled JSON parser's helper
    Return -1
EndFunction

String Function UnescapeJsonString(String s)
    {Safe-exit stub: the hand-rolled JSON parser's unescape; Json_GetString replaced it.}
    ; M-I-STUB 3.9.14-beta25 (P3-08): the hand-rolled JSON parser's unescape
    Return s
EndFunction

Bool Function IsTrapImmunityEnabled()
    {Safe-exit stub. TRUE, as beta25's body always answered (its StorageUtil key had no
     writer), so a resumed RefreshTrapImmunity or RegisterFollower frame keeps granting
     the perk instead of stripping it.}
    ; M-I-STUB 3.9.14-beta25 (P3-08): dead code removed by the modular-install audit fix (89ed67cb, 2026-09-13)
    Return true
EndFunction

Function LeashCaptiveByName(Actor akLeader, String targetName)
    {Safe-exit stub: the LeashCaptive action was retired (RestrainNPC picks a captive back up).}
    ; M-I-STUB 3.9.14-beta25 (P3-08): the LeashCaptive action was retired (b41f8d3f)
EndFunction

Function UnleashCaptiveByName(Actor akSpeaker, String targetName)
    {Safe-exit stub: retired with LeashCaptive.}
    ; M-I-STUB 3.9.14-beta25 (P3-08): retired with LeashCaptive (b41f8d3f)
EndFunction

; ============================================================================
; M-V VERB DISPATCHER (plan 3.0 M-V, DR10)
; ============================================================================
; The DLL routes this module's UI verbs (Native/data/verb_table.json) as
; SeverActions_Verb_Followers with the Actions page's 8 pipe fields. This is the
; ONE script defining OnVerb_Followers (a shared callback name runs on every script
; of the form, F4); Maintenance registers it (DR16).
Event OnVerb_Followers(String eventName, String strArg, Float numArg, Form sender)
    String actionId = SeverActions_ModuleBase.VerbField(strArg, 0)
    String targetName = SeverActions_ModuleBase.VerbField(strArg, 1)
    String target2Name = SeverActions_ModuleBase.VerbField(strArg, 2)
    String strParam = SeverActions_ModuleBase.VerbField(strArg, 3)
    Int intParam = SeverActions_ModuleBase.VerbField(strArg, 4) as Int
    String str2Param = SeverActions_ModuleBase.VerbField(strArg, 5)
    Int targetFid = SeverActions_ModuleBase.VerbField(strArg, 6) as Int
    Int target2Fid = SeverActions_ModuleBase.VerbField(strArg, 7) as Int
    Debug.Trace("[SeverActions_FollowerManager] OnVerb_Followers: " + actionId + " target=" + targetName + " target2=" + target2Name \
        + " str=" + strParam + " int=" + intParam + " str2=" + str2Param + " fid=" + targetFid + " fid2=" + target2Fid)

    ; Sender, then the encoded FormID, then the fuzzy name; names are
    ; re-canonicalized to display names for the branches that pass one on.
    Actor target = SeverActions_ModuleBase.VerbActor(sender, targetFid, targetName)
    If !target
        Debug.Trace("[SeverActions_FollowerManager] OnVerb_Followers: could not resolve target '" + targetName + "' for " + actionId)
        Return
    EndIf
    targetName = target.GetDisplayName()
    Actor target2 = SeverActions_ModuleBase.VerbActor(None, target2Fid, target2Name)
    If target2
        target2Name = target2.GetDisplayName()
    ElseIf target2Name != ""
        Debug.Trace("[SeverActions_FollowerManager] OnVerb_Followers: target2 name '" + target2Name + "' did not resolve to an actor (action=" + actionId + ")")
    EndIf

    ; -- Followers (own code) --
    If actionId == "registerFollower"
        RegisterFollower(target)

    ElseIf actionId == "companionFollow"
        CompanionFollow(target)

    ElseIf actionId == "companionWait"
        CompanionWait(target)

    ElseIf actionId == "dismissCompanion"
        DismissCompanion(target)

    ElseIf actionId == "followerLeaves"
        FollowerLeaves(target)

    ElseIf actionId == "assignHome"
        String locName = strParam
        If locName == ""
            Location here = Game.GetPlayer().GetCurrentLocation()
            If here
                locName = here.GetName()
            EndIf
            If locName == ""
                locName = "Unknown Location"
            EndIf
        EndIf
        AssignHome(target, locName)

    ElseIf actionId == "assignWork"
        ; Any NPC; opens the retainer popup so the player picks workplace and job
        ; (the frontend closes the dashboard first so the non-pausing popup shows).
        AssignWork(target, "")

    ElseIf actionId == "setCombatStyle"
        SetCombatStyle(target, strParam)

    ElseIf actionId == "adjustRelationship"
        ; The frontend sends one axis + a signed amount; route it into that slot.
        If strParam == "rapport"
            AdjustRelationship(target, intParam, 0, 0, 0)
        ElseIf strParam == "trust"
            AdjustRelationship(target, 0, intParam, 0, 0)
        ElseIf strParam == "loyalty"
            AdjustRelationship(target, 0, 0, intParam, 0)
        ElseIf strParam == "mood"
            AdjustRelationship(target, 0, 0, 0, intParam)
        EndIf

    ; -- Follow (the followers module's sibling script) --
    ElseIf actionId == "setFollowDistance"
        ; target = companion; strParam ('name') = 'close' or 'normal'.
        SeverActions_Follow followDist = (Self as Quest) as SeverActions_Follow
        If followDist
            followDist.SetFollowDistance(target, strParam)
        EndIf

    ElseIf actionId == "startFollowing"
        ; Temporary follow for ANY NPC - distinct from Recruit (no roster).
        SeverActions_Follow followStart = (Self as Quest) as SeverActions_Follow
        If followStart
            followStart.StartFollowing(target)
        EndIf

    ElseIf actionId == "stopFollowing"
        SeverActions_Follow followStop = (Self as Quest) as SeverActions_Follow
        If followStop
            followStop.StopFollowing(target)
        EndIf

    Else
        Debug.Trace("[SeverActions_FollowerManager] OnVerb_Followers: unknown actionId '" + actionId + "' (not a row this dispatcher carries)")
    EndIf

    ; Refresh now that the verb has run: the DLL's own refresh fires one frame
    ; after routing, before most verbs have changed anything.
    SeverActionsNative.Magelight_RefreshPage("world")
    SeverActionsNative.Magelight_RefreshPage("enterprises")
EndEvent

; ============================================================================
; M-K HOTKEY DISPATCHER (plan 3.0 M-K, DR10)
; ============================================================================
; The DLL's input sink (Native/data/hotkey_table.json) sends this module's hotkeys
; as SeverActions_Hotkey_Followers: strArg = the hotkey id, sender = the target
; resolved by targetMode (crosshair / nearest NPC / last talked-to) or None. The
; sink already applied the global gates (menus, dialogue, dead, sitting); each
; branch keeps its hotkey's own rules and notifications.
Event OnHotkey_Followers(String eventName, String strArg, Float numArg, Form sender)
    ; "wheel:<id>" = the quick wheel's pick of the same hotkey; fromWheel keeps
    ; the wheel's two rule differences.
    String hotkeyId = strArg
    Bool fromWheel = false
    If StringUtil.Substring(strArg, 0, 6) == "wheel:"
        fromWheel = true
        hotkeyId = StringUtil.Substring(strArg, 6)
    EndIf
    Actor target = sender as Actor
    Actor player = Game.GetPlayer()
    Debug.Trace("[SeverActions_FollowerManager] OnHotkey_Followers: " + hotkeyId + " target=" + target)

    ; -- Follow toggle: registered companions go through the companion verbs (the
    ;    casual path would layer a FollowPlayer package over the alias system and,
    ;    on track-only companions, poison the native monitors); a casual NPC
    ;    toggles the Follow script's own follow.
    If hotkeyId == "FollowToggle"
        If !target
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.noValidTarget"))
        ElseIf target == player
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.cannotTargetYourself"))
        Else
            SeverActions_Follow followToggle = (Self as Quest) as SeverActions_Follow
            If IsRegisteredFollower(target)
                Bool isHeld = (target.GetAV("WaitingForPlayer") > 0) || (followToggle && followToggle.IsSandboxing(target))
                If isHeld
                    CompanionFollow(target)
                Else
                    CompanionWait(target)
                EndIf
            ElseIf !followToggle
                Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.followScriptNotConfigured"))
            ElseIf followToggle.HasFollowPackage(target) || (!fromWheel && followToggle.IsSandboxing(target))
                ; Following (or, for the key, sandboxing = paused follow): stop;
                ; StopFollowing also clears the sandbox. The wheel instead reads a
                ; sandboxing casual NPC as held and starts them following.
                followToggle.StopFollowing(target)
            ElseIf SeverActions_Follow.StartFollowing_IsEligible(target)
                followToggle.StartFollowing(target)
            EndIf
        EndIf

    ElseIf hotkeyId == "Dismiss"
        If !target
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.noValidTarget"))
        ElseIf target == player
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.cannotTargetYourself"))
        ElseIf !SeverActionsNativeExt.Native_GetIsFollower(target)
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("hotkeys.isNotYourCompanion", ("" + target.GetDisplayName())))
        Else
            DismissCompanion(target)
        EndIf

    ElseIf hotkeyId == "SetCompanion"
        If !target
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.noValidTarget"))
        ElseIf target == player
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.cannotTargetYourself"))
        Else
            RegisterFollower(target)
        EndIf

    ElseIf hotkeyId == "CompanionWait"
        If !target
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.noValidTarget"))
        ElseIf target == player
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.cannotTargetYourself"))
        ElseIf IsFollowHandsOff(target)
            ; Hands-off (another framework, or Tracking mode - D45): toggle through the companion verbs. An NPC no
            ; framework leads waits in SA's sandbox (_UnledInTracking); for her only WaitingForPlayer 1 is a wait (2 is
            ; the schedule's own hold), and the wheel refuses her as it refuses a stranger in SeverActions mode.
            Float wfpKey = target.GetAV("WaitingForPlayer")
            Bool unled = _UnledInTracking(target)
            If wfpKey == 1.0 || (wfpKey > 0 && !unled)
                CompanionFollow(target)
            ElseIf unled && fromWheel
                Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("wheelmenu.notFollowingYou", ("" + target.GetDisplayName())))
            Else
                CompanionWait(target)
            EndIf
        Else
            ; Casual followers go through the Follow script, companions through the verbs.
            SeverActions_Follow followWait = (Self as Quest) as SeverActions_Follow
            Bool isCasual = followWait && followWait.HasFollowPackage(target) && !IsRegisteredFollower(target)
            Bool isSandboxing = followWait && followWait.IsSandboxing(target)
            If isSandboxing
                If isCasual || !IsRegisteredFollower(target)
                    followWait.StopSandbox(target)
                Else
                    CompanionFollow(target)
                EndIf
            ElseIf target.GetAV("WaitingForPlayer") == 1.0
                ; Only 1 is a wait: 2 is the schedule's own hold, and resuming that would make her a casual follower.
                CompanionFollow(target)
            ElseIf isCasual
                followWait.Sandbox(target)
            ElseIf !fromWheel || IsRegisteredFollower(target)
                CompanionWait(target)
            Else
                ; The wheel refuses a stranger; the key sends anyone through CompanionWait.
                Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("wheelmenu.notFollowingYou", ("" + target.GetDisplayName())))
            EndIf
        EndIf

    ; -- Homes (merged into followers, A7) --
    ElseIf hotkeyId == "AssignHome"
        If !target
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.noValidTarget"))
        ElseIf target == player
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.cannotTargetYourself"))
        Else
            Location currentLoc = player.GetCurrentLocation()
            If !currentLoc
                Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.noLocationDetected"))
            ElseIf currentLoc.GetName() == ""
                Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.currentLocationNoName"))
            Else
                AssignHome(target, currentLoc.GetName())
            EndIf
        EndIf

    ElseIf hotkeyId == "ClearHome"
        ; Any NPC with a home, on the roster or not (e.g. a townsperson the LLM
        ; homed by mistake); ClearHome releases the sandbox, marker and bed.
        If !target
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.noValidTarget"))
        ElseIf target == player
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.cannotTargetYourself"))
        ElseIf GetAssignedHome(target) == ""
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("hotkeys.noHomeAssigned", ("" + target.GetDisplayName())))
        Else
            ClearHome(target)
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("hotkeys.clearedHome", ("" + target.GetDisplayName())))
        EndIf

    Else
        Debug.Trace("[SeverActions_FollowerManager] OnHotkey_Followers: unknown hotkeyId '" + hotkeyId + "' (not a row this dispatcher carries)")
    EndIf
EndEvent

; =============================================================================
; UI PACKAGE BUTTONS (P4-08)
; =============================================================================

Event OnPrismaClearPkgs(string eventName, string strArg, float numArg, Form sender)
    {The UI's Clear All Packages button. strArg = "actorName|". The sender is the exact
     actor; the name lookup is only an older-DLL fallback (it can pick a namesake).}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = sender as Actor
    If !akActor
        akActor = SeverActionsNative.FindActorByName(actorName)
    EndIf
    If akActor
        Debug.Trace("[SeverActions_FollowerManager] ClearAllPackages: " + akActor.GetDisplayName())
        SkyrimNetApi.ClearAllPackages(akActor)
        SeverActionsNative.Native_SetSandboxing(akActor, false)
    EndIf
EndEvent

Event OnPrismaRemovePkg(string eventName, string strArg, float numArg, Form sender)
    {The UI's Remove Package button. strArg = "actorName|packageName".
     Sender-first - see OnPrismaClearPkgs.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    String packageName = StringUtil.Substring(strArg, pipePos + 1)
    Actor akActor = sender as Actor
    If !akActor
        akActor = SeverActionsNative.FindActorByName(actorName)
    EndIf
    If akActor
        Debug.Trace("[SeverActions_FollowerManager] RemovePackage: " + packageName + " from " + akActor.GetDisplayName())
        SkyrimNetApi.UnregisterPackage(akActor, packageName)
        If packageName == "FollowPlayer"
            SeverActionsNative.Native_SetSandboxing(akActor, false)
        EndIf
    EndIf
EndEvent
