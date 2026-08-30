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
    - Nether's Follower Framework (NFF): SeverActions ROUTES recruit /
   dismiss / wait / resume through NFF's own controller when NFF owns the
   actor (NFFRecruit / NFFDismiss / NFFWait / NFFResume below, via the
   nwsFollowerControllerScript BuildStub), then runs its own bookkeeping.
   Acting behind NFF's back is what left NPCs owned by both mods and
   rostered by neither - NFF claims a follower by seating them in one of
   its quest aliases, which nothing on our side can empty. SA still never
   mutates an NFF follower's package stack. FrameworkMode auto-defaults to
   Tracking once when NFF is detected.
    - DLC followers (Serana) are routed through their own mental-model
      quest so we don't double-manage their package state.

    Data lives in the native FollowerDataStore cosave (Native_* accessors) as
    the single source of truth after the Phase-4B/T1 refactor. The legacy
    SeverFollower_* StorageUtil keys are transitional mirrors drained by
    one-shot T1-A/T1-B migrations - what each once held:
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

Int Property MaxFollowers = 100 Auto
{Roster recruitment cap (0 = unlimited). The 21 CK alias slots stopped
 being the real limit when follower overflow shipped (package-override
 follow past the alias pool), so this is purely a user preference now.
 Old default was 20 — Maintenance() migrates saves still on that value.}

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

Float Property UIScale = 1.0 Auto
{PrismaUI density factor. Source of truth for both MCM and the in-Prisma
slider. Mirrored to StorageUtil(None, "SeverActions_UIScale") on init/
load. Range 0.8–2.0. The PrismaUI dashboard gatherer emits this on every
page-data fetch and the frontend applies it on receive, so MCM changes
take effect the next time the player opens PrismaUI.}

Float Property RapportDecayRate = 1.0 Auto
{How fast rapport decays from neglect (points per 6 game hours without conversation)}

Bool Property AllowAutonomousLeaving = true Auto
{Can followers leave on their own if rapport is too low?}

Bool Property EnableRestrainAction = true Auto
{Toggle for the RestrainNPC action — an NPC walks to a named target, binds
 their hands, and holds them standing bound (the kidnap hold WITHOUT the hood, the
 abduction legs, or any crime consequences). Default ON: an open, ordered
 restraint (a jarl's command, helping a guard) is a far milder ask than
 abduction, so it does not share the kidnap opt-in.}

Bool Property EnableKidnapActions = false Auto
{Opt-in toggle for the kidnap actions (KidnapNPC / ReleaseCaptive). Default OFF —
 villain-playthrough content. WARNING shown in MCM/UI: holding an essential or
 quest-relevant NPC captive can break their later quest content.}

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

Float Property AssessmentMinRealGapSeconds = 90.0 Auto
{Global pacing floor (large-roster buffer): minimum REAL seconds between
 successive relationship/inter-follower assessment fires, regardless of how
 many followers are overdue. Auto-scales up with party size (+10% per
 follower past 10). The per-NPC game-time cooldowns below stagger WHO is
 due; this floor paces HOW OFTEN the LLM is actually hit — without it a
 large roster whose cooldowns all expire (long sleep, fresh load) fires an
 assessment on every single 30s tick indefinitely.}

Float Property OffScreenLifeMinRealGapSeconds = 180.0 Auto
{Global pacing floor for off-screen life stories: minimum REAL seconds
 between successive fires, auto-scaled up with the tracked-roster size
 (+2% per NPC past 50). Buffers big homed rosters (home STORAGE is
 uncapped; only alias enforcement caps at 300 concurrent) from
 turning the background story generator into continuous LLM traffic.}

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

Bool Property AutoAmbientActions = false Auto
{Ambient Actions (Action Orchestrator, promote half) — let nearby non-follower
NPCs autonomously TAKE an action when it makes sense (MVP: head off somewhere,
optionally telling a nearby NPC first). Default OFF while the feature is proven.
See ai_docs/AMBIENT_ACTIONS.md.}

Float Property AmbientActionCooldownMinHours = 4.0 Auto
{Minimum game hours between ambient-action opportunities.}

Float Property AmbientActionCooldownMaxHours = 9.0 Auto
{Maximum game hours between ambient-action opportunities.}

Bool Property RoomRotationEnabled = true Auto
{Home room rotation (named markers): a homed NPC's sandbox anchor hops between
 the named markers dropped in their home every 1-3 game hours, so they LIVE in
 the house instead of orbiting one spot. Only while their schedule says HOME,
 never inside the sleep window, and only while loaded (a presentation feature).}

Float Property AmbientSceneSeparationHours = 1.0 Auto
{Minimum game hours between ambient scenes of EITHER kind (banter or action).
 Whichever system fires last pushes the other back by this much, so the room
 never gets two staged scenes within seconds of each other.}

Int Property QuestAwarenessOutputCap = 5 Auto
{Maximum number of quest awareness entries emitted to the prompt per follower.
Storage cap (per-follower max retained quests) is unaffected — this only
controls how many entries the LLM sees per render. Range 1-15, default 5.}

Int Property EnterpriseStoryCap = -1 Auto
{Max weekly retainer work-life vignettes (LLM calls) generated per settle batch.
-1 = Auto (~40% of the active roster, min 1, cap 12); 0 = off; 1-12 = fixed.
Set from PrismaUI Settings; boot-synced to the native each load.}

Int Property EnterpriseOutputPct = 100 Auto
{Global scaler on every venture's weekly production, as a percentage. 25-300;
100 = the tuned baseline. Set from PrismaUI Settings; boot-synced to the native
each load. Applies to the board's projection too, so the banner never overstates.}

Bool Property EnterpriseLoansEnabled = True Auto
{Allow retainers to ask the player for a coin loan. Separate from raise
requests: a raise is about what the work is worth, a loan is a personal
favour, and some players would rather never be asked for money.}

Bool Property EnterpriseRaisesEnabled = True Auto
{Master toggle for retainer raise requests (Living payroll). When off, retainers
never ask for a raise and never skim. Set from PrismaUI Settings; boot-synced.}

Bool Property EnterpriseRenownCapEnabled = True Auto
{Master toggle for the Renown roster cap (VSTR v2). When off, the renown score
and tier still track, but hiring is never gated by the cap. Set from PrismaUI
Settings; boot-synced. Default flipped to OFF for the 3.8 test round — a
one-time migration forces it off once on existing saves too; players can
re-enable in Settings.}

Bool Property EnterpriseAmbushesEnabled = True Auto
{Master toggle for retainer grudges (desertion consequences). When off, a wronged
desertion arms no grudge and no thugs will come. Set from PrismaUI Settings; boot-synced.}

Bool Property EnterpriseTemperEnabled = True Auto
{Master toggle for retainer temperament consequences (the Temper ladder). When off,
morale still tracks and displays, but no complaint letters, pilfering, notices,
defiance, betrayal, or escapes. Set from PrismaUI Settings; boot-synced.}

Bool Property SandboxMultiFloorEnabled = True Auto
{Multi-floor sandboxing: widen the engine's sandbox search cylinder
(fSandboxCylinderTop/Bottom GMSTs) so sandboxing NPCs use stairs and other
floors - the Multiple Floors Sandboxing tweak, applied at runtime (widen-only
vs whatever the load order shipped). Set from PrismaUI Settings; boot-synced.}

Int Property SandboxCylinderHeight = 576 Auto
{Vertical half-height (game units) of the sandbox search cylinder when the
multi-floor toggle is on. 576 matches the classic mod; a floor is ~256-384u.}

Bool Property HomeSleepEnabled = True Auto
{Homed NPCs sleep at night (dev145): during the sleep window a dismissed homed
NPC lies down in the bed BedAssignment claimed for them at AssignHome, instead
of sandboxing around the house forever. The home sandbox nominally allows
sleeping, but the engine's Sandbox procedure almost never chooses it - vanilla
citizens sleep through dedicated packages, and this window is ours. Set from
PrismaUI Settings / MCM; read live each tick.}

Float Property HomeSleepStart = 22.0 Auto
{Sleep window start, game hours 0-24. The 22->6 default wraps midnight via
HourInWindow, same math as the per-retainer work windows.}

Float Property HomeSleepEnd = 6.0 Auto
{Sleep window end, game hours 0-24.}

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

; ── Route B work pool (decoupled from home slots, no static markers).
; The runtime anchor MARKERS are current-era; the override ENFORCEMENT below
; is the pre-migration fallback (alias era: SchedWork pool, 300) ──
; A working NPC gets a runtime-spawned, force-persistent XMarker at their work
; spot, linked to them via WorkAnchorKeyword. The single WorkSandboxPackage
; sandboxes around that linked ref (radius 1200) and is applied during work hours
; via AddPackageOverride / removed off-hours. LinkedRef_Set cosaves + restores the
; link, so the marker survives saves. Filled by the esp-CLI auto-fill pass after
; GenerateWorkSandbox.pas creates the records.
; The work package + anchor keyword are resolved by FormID at runtime (NOT Auto
; properties) — filling Auto props requires a Mutagen/CK write to the script-heavy
; quest VMAD, which corrupts it (infinite hang before main menu). GetFormFromFile by
; FormID is the safe pattern (same as the quest 0x000D62). FormIDs are deterministic:
; GenerateWorkSandbox.pas creates the keyword first (0x165675) then the package
; (0x165676) on a clean ESP. See GetWorkSandboxPackage / GetWorkAnchorKeyword.

; Per-actor StorageUtil key holding the spawned work XMarker (so it stays a live,
; persistent reference and can be cleaned up / reused on reassign).
String Property KEY_WORK_MARKER = "SeverActions_WorkMarkerRef" AutoReadOnly
; One-shot migration: move legacy borrow-a-home-slot work-only NPCs onto the
; decoupled linked-ref work pool. Raise N to re-fire on a future schema change.
String Property KEY_WORKPOOL_MIG = "SeverActions_WorkPoolMigDone" AutoReadOnly

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

; Game-time rescale factor (~3600 game-seconds per game hour). Only ratios of
; game-time matter here (timescale-independent) — every use both multiplies and
; divides by this constant, so the odd 3631 value is behaviorally harmless.
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
; Rolling history of recent banter topics (pre-built JSON objects), injected
; into the sever_follower_banter prompt as "recentBanter" so its anti-repetition
; + rotation sections actually have data — get_recent_events never surfaced our
; gamemaster_dialogue topics (wrong event type + "target" vs "listener").
String Property KEY_BANTER_HISTORY = "SeverActions_BanterHistory" AutoReadOnly
Int Property BanterHistoryMax = 12 AutoReadOnly
String Property KEY_LAST_AMBIENT_GT = "SeverActions_LastAmbientGT" AutoReadOnly
String Property KEY_NEXT_AMBIENT_GT = "SeverActions_NextAmbientGT" AutoReadOnly
String Property KEY_NEXT_AMBIENT_ACTION_GT = "SeverActions_NextAmbientActionGT" AutoReadOnly
; Shared across ambient BANTER and ambient ACTIONS: game-time of the last
; ambient scene EITHER system actually dispatched (silence cycles don't count).
; Both checks require this + AmbientSceneSeparationHours to have passed, so the
; two systems can never stage separate scenes in the same room within seconds
; of each other (field 2026-08-08: both fired back-to-back, same NPCs).
String Property KEY_LAST_AMBIENT_SCENE_GT = "SeverActions_LastAmbientSceneGT" AutoReadOnly
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

; Global tracking key for NPCs given a WORK marker but NO home (work-only).
; These borrow a marker slot; ProcessWorkOnlySwaps applies their sandbox ONLY
; during work hours (8-17) and releases it (back to native AI) otherwise.
; When such an NPC is later given a home, AssignHome promotes them off this list
; into KEY_HOMED_NPCS (always-on sandbox with hourly anchor routing).
String Property KEY_WORK_ONLY_NPCS = "SeverActions_WorkOnlyNPCs" AutoReadOnly

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

; Per-NPC schedule alias pools (ESP quests; alias-backed scheduling replaces
; per-NPC package overrides once Native_GetAliasesMigrated() is true)
; Raised 200->300 alongside the 500 retainer roster cap. MUST match the alias
; count generated by GenerateSchedPoolExtend.pas across all three sched quests
; (SchedHome/Work/RelaxQuest, aliases 000..299).
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

; Migration state (design doc section 4)
Bool SchedMigrationPending = False

; =============================================================================
; INTERNAL STATE
; =============================================================================

Float LastTickTime
Bool IsUpdating = false
Float IsUpdatingSetRT = 0.0  ; real-time stamp for the stuck-guard watchdog
; Outer OnUpdate re-entrancy guard (maxed-roster stack-dump fix): one pass at
; a time; queued extra fires bail in three instructions. 120s ceiling frees
; the guard if a pass's stack was dumped mid-body.
Bool _OnUpdateInFlight = false
Float _OnUpdateStartRT = 0.0

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
; (32 slots, sized for burst dismiss events such as mass-dismiss / cell-unload,
; not the roster cap) preserves every pending removal until the tick drains them.
Actor[] PendingDismissQueue
Int PendingDismissCount = 0

; Relationship assessment tracking — only one assessment in flight at a time
; Store Actor references directly to avoid ESL FormID sign issues with Game.GetForm()
Actor PendingAssessmentActor = None
Bool AssessmentInProgress = false
; Per-dispatch unique reply channel so a watchdog-abandoned request's late
; callback can never be applied to the wrong follower (see FireRelationshipAssessment,
; OnLLMRelAssessReady and the CheckRelationshipAssessments watchdog).
Int AssessSeq = 0
String AssessEventNameCur = ""

; Inter-follower assessment tracking — separate from player-centric assessment
Actor PendingInterAssessActor = None
Bool InterFollowerAssessmentInProgress = false

; Follower banter tracking — lowest priority LLM system
Bool BanterInProgress = false

; Ambient NPC banter tracking — independent of follower banter so both can
; cycle without blocking each other. Separate cooldown (3-7 game hours).
Bool AmbientBanterInProgress = false

; Ambient action tracking — the Action Orchestrator's promote half. Its own
; in-flight flag so it neither blocks nor is blocked by banter/assessments.
; Stays true while a social gate is being adjudicated (see OnAmbientActionReady).
Bool AmbientActionInProgress = false

; Non-blocking social-gate poll state. While AmbientGatePolling is true, OnUpdate
; runs at a fast 2s cadence and drives PollAmbientGate instead of the 30s body —
; this replaces the old blocking Utility.Wait loop that tied up the ModEvent
; handler's VM stack for ~40s and serialized sibling events. The native gate owns
; settle detection + adjudication + the busy lock; we only commit on a GO verdict.
Bool AmbientGatePolling = false
Actor _AmbientGateInitiator = None
String _AmbientGateAction = ""
String _AmbientGateDest = ""
Actor _AmbientGateTarget = None
String _AmbientGateItem = ""
Int _AmbientGateQty = 1
Int _AmbientGateGold = 0
Bool _AmbientGateWait = false
Int _AmbientGatePollCount = 0

; Off-screen life event tracking — separate from both assessment types
Actor PendingOffScreenLifeActor = None
Bool OffScreenLifeInProgress = false

; Real-time stamps of the last fire per LLM system class (pacing floors).
; Script vars persist in saves, but GetCurrentRealTime restarts per game
; SESSION — a stale stamp from a previous session reads as a NEGATIVE
; delta, which the gates treat as "gap satisfied" (self-healing).
Float LastAssessClassFireRT = 0.0
Float LastOffScreenLifeFireRT = 0.0
; Watchdog: real-time seconds when InProgress was set. If the C++
; SeverActions_OffScreenLifeReady ModEvent gets dropped (early reg miss,
; ThreadPool→game-thread loss, native dispatch error), the flag stays
; true forever and blocks every future off-screen life event. OnUpdate
; clears it after a generous timeout.
Float OffScreenLifeStartedRT = 0.0

; Quest awareness tracking — Papyrus pump (SkyrimNet < v8 fallback).
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
    ; Tier 1 perf: bump the track-only classification epoch once per load so
    ; IsTrackOnlyFollower's per-actor memo cache re-validates this session. The
    ; signals it caches are session-static, so this per-load invalidation is the
    ; only thing needed to stay correct across a load-order change.
    StorageUtil.SetIntValue(None, "SeverActions_TOEpoch", StorageUtil.GetIntValue(None, "SeverActions_TOEpoch", 0) + 1)
    ; Kill any stale ENGINE update registration a pre-chronometer save still
    ; carries: the slot is FORM-keyed (the whole shared-timer trap), so one
    ; call from any quest script clears it for the entire form. No script
    ; on THIS form defines Event OnUpdate() any more (alias scripts keep
    ; theirs on their own handles), so this is pure hygiene - and the
    ; game-time pool (Follow's muster pump) is a separate slot, untouched.
    UnregisterForUpdate()
    ChronoArm(30.0)
    ; No OnPlayerLoadGame ModEvent registration here: SeverActions_Init.psc →
    ; Maintenance() is the single coverage path for the post-load essential
    ; re-apply.

    ; Kidnap system load recovery: push the cosaved toggle to the native
    ; flag (backs the sever_kidnap_enabled decorator). Travel-leg completions
    ; arrive via SeverActions_Travel's forwarding, not a listener here.
    KidnapMaintenance()

    ; One-shot: saves from before the follower uncap carry the old
    ; MaxFollowers default (20) baked into the cosaved property — bump them
    ; to the new default so the lifted cap actually lifts. Users who set a
    ; DIFFERENT custom value keep it; anyone who wants exactly 20 can re-set
    ; it in the MCM (the sentinel keeps this from re-firing).
    If StorageUtil.GetIntValue(None, "SeverActions_MaxFollowersMigDone", 0) < 1
        If MaxFollowers == 20
            MaxFollowers = 100
        EndIf
        StorageUtil.SetIntValue(None, "SeverActions_MaxFollowersMigDone", 1)
    EndIf

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
    ; (0.8) → Prisma renders tiny on first open. Range guard handles any
    ; other out-of-range value too. Upper bound 2.0 matches the in-app
    ; slider and the auto-density ceiling (4K ≈ 2.0); a cosaved 1.5 (the
    ; pre-fullscreen default) stays in range — the frontend migrates it.
    If UIScale < 0.8 || UIScale > 2.0
        UIScale = 1.0
    EndIf

    ; One-shot 135% auto-density migration (2026-07): the auto default moved
    ; 1.55 → 1.35 at 1440p (155 read too zoomed). Reset the property to the
    ; 1.0 "unset" sentinel ONCE so the frontend's auto default takes over
    ; until the user moves a slider — mirrors the localStorage-side
    ; prismaui-scale-mig-135 one-shot (without it, a cosaved explicit value
    ; would re-mark the user explicit on the first gather).
    If StorageUtil.GetIntValue(None, "SeverActions_UIScale135Mig", 0) < 1
        UIScale = 1.0
        StorageUtil.SetIntValue(None, "SeverActions_UIScale135Mig", 1)
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

    ; Vanilla follower dialogue routing (native VanillaFollowTopicMonitor)
    RegisterForModEvent("SeverActions_VanillaFollowTopic", "OnVanillaFollowTopic")

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

    ; Assign-retainer popup -> place the work marker at the chosen location
    ; (fired ONLY on confirm/Hire; Not now / timeout / Escape are full cancels
    ; and fire nothing. The hire itself is native).
    RegisterForModEvent("SeverActions_RetainerWorkLoc", "OnRetainerWorkLoc")

    ; Off-screen life LLM response — C++ Bridge fires this from the SkyrimNet
    ; v8 PublicSendCustomPromptToLLM callback after parsing the response and
    ; storing events + gossip in the native data store. strArg carries the
    ; same pipe-delimited string the legacy parser used to return.
    RegisterForModEvent("SeverActions_OffScreenLifeReady", "OnOffScreenLifeReady")

    ; Manual "How They See You" update — the Companions page button lets a user
    ; refresh a follower's relationship blurb on demand instead of waiting for the
    ; autonomous cooldown. Sender = the follower.
    RegisterForModEvent("SeverActions_AssessRelNow", "OnAssessRelNow")

    ; Ambient banter LLM response — C++ AmbientBanterScanner fires this from
    ; the SkyrimNet v8 callback after parsing the response and pre-building
    ; the gamemaster_dialogue event JSON. numArg = 1.0 means a pair is ready
    ; to RegisterEvent (handler pulls eventJson + actors from native accessors),
    ; 0.0 means silence cycle or failure (handler just clears in-progress).
    ; The old Papyrus-side context + eventJson building corrupted non-ASCII
    ; NPC names to mojibake via String += — see issue #9.
    RegisterForModEvent("SeverActions_AmbientBanterReady", "OnAmbientBanterReady")

    ; Ambient action director response — C++ AmbientActionScanner fires this after
    ; the director LLM picks an intent (or declines). numArg = the IntentKind:
    ; 0 = none/silence, 1 = solo (execute now), 2 = social (announce + gate).
    RegisterForModEvent("SeverActions_AmbientActionReady", "OnAmbientActionReady")

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
    ; Same for the OnUpdate re-entrancy guard -- it's save-persisted, so a save
    ; made mid-tick would otherwise stall the 30s loop forever.
    IsUpdating = false
    ; Ambient banter's in-flight flag is save-persisted too: a save made while
    ; a banter LLM call was in flight permanently disabled ambient banter for
    ; that playthrough (audit).
    AmbientBanterInProgress = false
    ; Same save-persisted-flag hazard for ambient actions: a save taken while a
    ; director call / social gate was in flight would otherwise wedge it forever.
    ; The native gate is reset in ResetTransientState (revert), so drop the
    ; Papyrus-side poll state to match — otherwise a resumed poll spins to its
    ; ceiling against an Inactive gate.
    AmbientActionInProgress = false
    AmbientGatePolling      = false
    _AmbientGateInitiator   = None
    _AmbientGatePollCount   = 0

    ; Sync the user-configurable quest awareness output cap to the C++ store.
    ; The C++ default is 5; if the user changed it via PrismaUI / MCM, the new
    ; value lives in this property and gets pushed down here on each load.
    SeverActionsNative.Native_QuestAwareness_SetOutputCap(QuestAwarenessOutputCap)

    ; Push the AutoQuestAwareness master toggle to the C++ store so the v8+
    ; fast-path dispatch honors it (the legacy pump reads the property directly;
    ; the fast path can't, so without this the toggle did nothing on modern
    ; SkyrimNet). The prompt-presence guard is automatic in C++.
    SeverActionsNativeExt.Native_QuestAwareness_SetEnabled(AutoQuestAwareness)

    ; Same pattern for the Enterprises weekly-story budget (the LLM vignette
    ; rate-limit). C++ defaults to Auto (-1); push the user's saved choice down.
    SeverActionsNativeExt2.Venture_SetStoryCap(EnterpriseStoryCap)

    ; And the global venture-output scaler. C++ defaults to 100%; push the
    ; saved choice so a retuned economy survives the reload.
    SeverActionsNativeExt2.Venture_SetProductionMult(EnterpriseOutputPct)

    ; And the retainer raise-request master toggle (Living payroll). C++ defaults
    ; on; push the saved choice so the v9 negotiation loop honours it.
    SeverActionsNativeExt2.Venture_SetRaisesEnabled(EnterpriseRaisesEnabled)
    SeverActionsNativeExt2.Venture_SetLoansEnabled(EnterpriseLoansEnabled)

    ; And the retainer grudge/ambush master toggle (desertion consequences).
    SeverActionsNativeExt2.Venture_SetAmbushesEnabled(EnterpriseAmbushesEnabled)

    ; And the Temper consequence-ladder master toggle (morale keeps tracking
    ; either way; only the teeth stand down when off).
    SeverActionsNativeExt2.Venture_SetTemperEnabled(EnterpriseTemperEnabled)

    ; And the Renown roster-cap master toggle (the score/tier track either way;
    ; only the hiring gate stands down when off).
    ; Migration history (integer counter — bump N to re-fire a future change):
    ;   1 = the 3.8.0 test round forced the cap OFF, because an over-cap roster
    ;       was gated with no way to earn its way out.
    ;   2 = that reason is gone. GrandfatherRenownToRoster now promotes any
    ;       over-cap roster to the lowest tier that holds it on every load, so
    ;       enforcing the gate can no longer lock anyone out of a roster they
    ;       already built. Turn it back ON once; the player's own Settings
    ;       choice from then on is respected (the property is cosaved).
    If StorageUtil.GetIntValue(None, "SeverActions_RenownCapOffMig", 0) < 2
        EnterpriseRenownCapEnabled = True
        StorageUtil.SetIntValue(None, "SeverActions_RenownCapOffMig", 2)
    EndIf
    SeverActionsNativeExt2.Venture_SetRenownCapEnabled(EnterpriseRenownCapEnabled)

    ; Multi-floor sandboxing (engine GMST widen - the Multiple Floors
    ; Sandboxing tweak done natively + toggleable). C++ captures the load
    ; order's shipped cylinder bounds on first call and applies widen-only,
    ; so a user's own wider ESP tune is never narrowed.
    SeverActionsNativeExt2.Sandbox_SetCylinder(SandboxMultiFloorEnabled, SandboxCylinderHeight as Float)

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
    ChronoArm(0.1)
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

    ; Heal followers SA wrongly believes it owns. hasFollowPkg is "we drive this
    ; one's follow package" and must be FALSE for track-only followers, but it is
    ; sticky in the cosave and nothing re-checked it against their CURRENT
    ; classification - so a follower recruited before they classified track-only
    ; (older build, or SPID hadn't distributed the keyword yet) stayed mis-owned
    ; forever. Symptom chain, field-reported on Serana: SA packages fight their
    ; framework, the framework zeroes WaitingForPlayer, FollowDriftMonitor reads
    ; that as an external resume and CANCELS the player's Wait, then re-asserts
    ; follow - and CellCatchup drags them on fast travel for the same reason.
    ReconcileTrackOnlyOwnership()

    ; NOTE: the legacy FrameworkMode migration does NOT belong here. It lives
    ; at the tail of this function and, since the Tracking-reverts fix, no
    ; longer maps 1 -> 0 at all - so it cannot undo the NFF default below and
    ; needs no ordering guarantee against it. An earlier version of this branch
    ; moved a COPY of the old destructive migration up here to fix that same
    ; bug by ordering; the tail version fixes it properly by deleting the
    ; branch. Do not reintroduce a second copy.

    ; NFF present? Default to Tracking mode ONCE. SA driving follow packages
    ; while NFF drives its own is the root of the long-standing conflict
    ; reports, and Tracking is the supported way to coexist (CLAUDE.md).
    ; One-shot so a user who deliberately switches back to SeverActions mode
    ; is not overridden on every load; counter sentinel per project convention.
    If SeverActionsNativeExt2.Native_IsNFFInstalled() && StorageUtil.GetIntValue(None, "SeverActions_NFFModeDefaulted", 0) < 1
        StorageUtil.SetIntValue(None, "SeverActions_NFFModeDefaulted", 1)
        If FrameworkMode != 1
            FrameworkMode = 1
            ; NOTE: no global-settings write-through here - Native_SettingsRecord
            ; lives on the Enterprises stack (claude/hold-taxes), not dev. The
            ; one-shot sentinel is enough for the common case (a user who never
            ; touched the PrismaUI mode selector has no entry in the global file,
            ; so nothing replays over this). A user who DID set the mode there
            ; has made an explicit choice, and letting it win is correct. Add the
            ; record call once the two branches meet.
            Debug.Notification("SeverActions: Nether's Follower Framework detected - switched to Tracking mode")
            Debug.Trace("[SeverActions_FollowerManager] NFF detected - FrameworkMode defaulted to Tracking (1)")
        EndIf
    EndIf

    ; === CACHED FOLLOWER ARRAY ===
    ; GetAllFollowers() does a full Papyrus cell scan (GetNthRef on every NPC).
    ; Cache once and pass to all sub-functions to avoid 8+ redundant cell scans.
    Actor[] cachedFollowers = GetAllFollowers()

    ; ── Orphan-scanner re-registration FIRST, before anything slow ──
    ; Field bug (3.5.0, heavy load orders): this maintenance pass can take
    ; 25+ seconds under a starved VM, and the 5s native orphan scanner won
    ; the race - every real companion was flagged a "Follow orphan" and had
    ; their follow package stripped seconds after load ("followers walk off
    ; on every reload", "recruit one and another leaves"). The native side
    ; now HOLDS all orphan scans from load until MarkRosterSynced; this
    ; tight loop re-registers the whole roster in milliseconds and releases
    ; the hold before the heavy passes below run.
    Int orphRi = 0
    While orphRi < cachedFollowers.Length
        If cachedFollowers[orphRi]
            SeverActionsNative.OrphanCleanup_RegisterFollower(cachedFollowers[orphRi])
        EndIf
        orphRi += 1
    EndWhile
    SeverActionsNative.OrphanCleanup_MarkRosterSynced()
    Debug.Trace("[SeverActions_FollowerManager] Orphan-scanner roster synced (" + cachedFollowers.Length + " followers) - scans released")

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
    ; a Papyrus → native VM hop. Two uses below.
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
    RefreshTrapImmunity(cachedFollowers)

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

    ; Route B: migrate legacy borrow-a-home-slot workers onto the decoupled
    ; linked-ref work pool. Gated on the WorkAnchorKeyword being filled (so it
    ; waits for the ESP records + auto-fill) AND a one-shot sentinel.
    If GetWorkAnchorKeyword() && StorageUtil.GetIntValue(None, KEY_WORKPOOL_MIG, 0) < 1
        MigrateWorkPoolOnLoad()
        StorageUtil.SetIntValue(None, KEY_WORKPOOL_MIG, 1)
    EndIf

    ; Schedule alias pools (design doc §4): first load with a capable ESP kicks
    ; the one-way Route B -> alias migration (flag flips atomically first, then
    ; a 0.5s batch drain runs off OnUpdate). On later loads the flag is already
    ; set, so this no-ops and the drift sweep below runs instead.
    If EnsureSchedQuests() && !SeverActionsNativeExt.Native_GetAliasesMigrated()
        BeginSchedAliasMigration()
    EndIf
    SweepSchedAliasesOnLoad()
    ; Guard pool (FLWD v19): one-shot override-era adoption + pool
    ; reconciliation — same load-path slot as the other alias sweeps.
    SweepGuardAliasesOnLoad()

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
            ; Follow pool (FLWD v18): one-shot legacy-slot/overflow adoption
            ; + pool reconciliation — BEFORE the re-apply pass so it sees
            ; pool state, not legacy state.
            followSys.SweepFollowAliasesOnLoad(cachedFollowers)
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

    ; Issue #14 Layer A: KEY_LAST_SCHEDULED_TYPE persists in the cosave, so
    ; after a load the swap logic saw "no transition" and left pool markers and
    ; work/play overrides wherever they were (door position, stale overrides)
    ; until the next 8/17/22 boundary. Stamp -99 for every scheduled NPC so the
    ; first tick after load fully re-resolves anchors and re-applies overrides.
    ; PRE-MIGRATION ONLY: post-migration the alias pools persist natively and
    ; the steady-state verify in ReconcileSchedAliasesFor handles drift —
    ; stamping -99 here would needlessly re-run the transition path (and its
    ; EvaluatePackage) for every scheduled NPC after every load.
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

    ; Register for sleep events — clear sandbox packages when player sleeps.
    ; Was in the original Maintenance() tail; folded in here so deferred
    ; ordering exactly matches the previous inline flow.
    RegisterForSleep()

    ; One-time migration: old 3-value FrameworkMode to new 2-value system
    ; Old: 0=Auto, 1=SeverActions Only, 2=Tracking Only
    ; New: 0=SeverActions, 1=Tracking
    ; Only runs once — flag prevents re-migrating newly-set values on subsequent loads
    ; The 1 -> 0 branch this carried was a LANDMINE and is gone. In the CURRENT
    ; two-value scheme 1 IS Tracking, and an old 1 ("SeverActions Only") is
    ; indistinguishable from it - so on any save whose sentinel was not yet
    ; stamped, Maintenance silently converted a deliberate Tracking choice back
    ; to SeverActions on load. That is the reported "Tracking reverts after a
    ; reload" bug. Leaving 1 alone is the only safe reading; only the genuinely
    ; out-of-range legacy value still needs folding down.
    ;
    ; Counter sentinel, not a boolean (CLAUDE.md): raising the number re-runs
    ; the corrected pass exactly once for saves that took the destructive one.
    If StorageUtil.GetIntValue(None, "SeverActions_FrameworkModeMigrated", 0) < 2
        If FrameworkMode >= 2
            FrameworkMode = 1  ; old "Tracking Only" → new "Tracking"
            Debug.Trace("[SeverActions_FollowerManager] Migrated FrameworkMode 2 -> 1 (Tracking)")
        EndIf
        StorageUtil.SetIntValue(None, "SeverActions_FrameworkModeMigrated", 2)
    EndIf

    BanterInProgress = false

    Debug.Trace("[SeverActions_FollowerManager] Maintenance complete - Mode: " + FrameworkMode)
EndFunction

; No OnPlayerLoadGame ModEvent handler here: SeverActions_Init.psc calls
; Maintenance() on every load, which already re-applies essential status
; with a cached follower list. A separate handler would double-fire the
; re-apply with an expensive GetAllFollowers() cell scan on top of the
; cheaper Init-driven pass — which is why the matching RegisterForModEvent
; is absent.

; =============================================================================
; SLEEP EVENT — CLEAR SANDBOX PACKAGES
; =============================================================================

Event OnSleepStart(Float afSleepStartTime, Float afDesiredSleepEndTime)
    {When the player sleeps, clear any orphaned FF runtime package a sleep
     time-skip can leave on a follower who is ACTIVELY FOLLOWING and in the same
     cell, so the follow package re-asserts cleanly on wake.

     A companion who is intentionally WAITING or SANDBOXING (relaxing) is left
     completely alone: sleeping no longer cancels a wait or a relax and pulls the
     follower back into following (user request 2026-08-30). Home / safe-interior
     / work sandboxers, manual waiters, track-only followers, and followers in
     other cells are all untouched.}
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
                ; Intentionally waiting or sandboxing: leave it intact. Covers home
                ; and work sandbox (WaitingForPlayer == 2), safe-interior relax
                ; (WaitingForPlayer == 1 and/or the native sandbox flag - track-only
                ; relaxers carry only the flag since their WaitingForPlayer=1 write
                ; is skipped), and manual Wait. The sandbox/wait is torn down the
                ; normal way (leaving the interior, Resume, etc.), never by sleeping.
                Debug.Trace("[SeverActions_FollowerManager] Leaving waiting/sandboxing " + f.GetDisplayName() + " alone on sleep")
            ElseIf IsTrackOnlyFollower(f)
                ; External framework (NFF / SPID custom-AI keyword / DLC like Serana)
                ; owns their package stack; ClearPackageOverride would wipe the
                ; framework's own follow package with no re-apply hook, so never
                ; touch them (the Daegon-walks-off-after-a-tavern-sleep bug).
                Debug.Trace("[SeverActions_FollowerManager] Skipping track-only " + f.GetDisplayName() + " on sleep (external AI owns packages)")
            Else
                ; Actively-following, same cell: clear any lingering FF orphan the
                ; sleep time-skip may have produced and re-assert follow.
                ActorUtil.ClearPackageOverride(f)
                SkyrimNetApi.ReinforcePackages(f)
                ; Overflow (past-alias-cap) companions follow via a PO3 override the
                ; blanket clear just wiped, and ReinforcePackages can't restore it
                ; (not SkyrimNet-registered) - re-apply now or they silently stop
                ; following after a same-cell sleep.
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
                            Debug.Trace("[SeverActions_FollowerManager] Returning follower re-detected - preserving existing data for " + actorRef.GetDisplayName())
                        Else
                            Debug.Trace("[SeverActions_FollowerManager] New follower detected - initialized defaults for " + actorRef.GetDisplayName())
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
    {Debounced follower onboarding — fired once TeammateMonitor has seen
     SetPlayerTeammate(true) HOLD across CONFIRM_SCANS (5) consecutive 1s
     scans (~5s minimum; see m_pendingTeammates in TeammateMonitor.h).
     Transient teammate flips from external frameworks (DOM/PAHE-class)
     never fire this event.}
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
        If IsTrackOnlyFollower(akActor)
            ; Sticky membership: a track-only follower's own framework
            ; (Sofia, Inigo, ...) may flip SetPlayerTeammate as part of its
            ; own behaviors. They are already on the roster - a teammate
            ; re-flip must never re-onboard them (no "has returned"
            ; notification, no sandbox strip, no follower_recruited event).
            Debug.Trace("[SeverActions_FollowerManager] Teammate re-flip on registered track-only follower - no-op: " + akActor.GetDisplayName())
        EndIf
        return
    EndIf

    ; Already in our faction? Also skip (co-save data might not be loaded yet).
    If SeverActions_FollowerFaction && akActor.IsInFaction(SeverActions_FollowerFaction)
        return
    EndIf

    ; Explicitly dismissed? Skip — prevents re-registration loop for custom followers
    ; (Inigo, Lucien, etc.) whose mods keep IsPlayerTeammate() true permanently.
    ; Exceptions (genuine re-recruit — clear the flag and fall through to the
    ; onboard + sandbox strip below):
    ;   WFP == 0  follow mode — re-recruited via vanilla / NFF / their own dialogue.
    ;   WFP == 2  parked in ONE OF OUR sandboxes (home / work / relax). A dismissed
    ;     HOMED NPC sits at WFP == 2 PERMANENTLY — their home sandbox never lapses —
    ;     so the WFP == 0 hatch alone could NEVER re-recruit them through NFF: the
    ;     reported bug, where NFF re-recruit bailed here, our prio-100 home override
    ;     survived, and the NPC just stayed put. A home-LESS work NPC already
    ;     re-recruited fine ONLY because their off-shift WFP resets to 0
    ;     (RemoveWorkSandbox); this brings homed NPCs (and homed work/relax) to the
    ;     same parity. Reaching this DEBOUNCED sustained-teammate event IS a real
    ;     re-recruit — onboard runs, and StripSandboxesForFollow /
    ;     ClearWorkSandboxForFollow below drop whichever sandbox was holding them.
    ; WFP == 1 (player 'wait here') and WFP == -1 (custom-dismiss signal) still bail.
    If StorageUtil.GetIntValue(akActor, KEY_DISMISSED, 0) == 1
        Float wfpDismiss = akActor.GetAV("WaitingForPlayer")
        If wfpDismiss == 0.0 || wfpDismiss == 2.0
            StorageUtil.UnsetIntValue(akActor, KEY_DISMISSED)
            DebugMsg("Dismissed flag cleared - re-recruited (WFP=" + wfpDismiss + "): " + akActor.GetDisplayName())
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

    ; Rebuild companion opinions so this externally-recruited member immediately has
    ; opinions of the roster (and vice versa) — same recruit-time gap fix as
    ; RegisterFollower, for the NFF / vanilla-dialogue / custom-AI detection path.
    RebuildAllCompanionOpinions(GetAllFollowers())

    ; External recruit — their own framework is about to drive follow. Drop any
    ; SA sandbox that would outrank it (same treatment as RegisterFollower's
    ; track-only branch) and release any camp pin so they actually walk over
    ; instead of staying at the fire.
    StripSandboxesForFollow(akActor)
    ClearWorkSandboxForFollow(akActor)
    Int calledEvt = ModEvent.Create("SeverActions_FollowerCalledByPlayer")
    If calledEvt
        ModEvent.PushString(calledEvt, "SeverActions_FollowerCalledByPlayer")
        ModEvent.PushString(calledEvt, "recruit")
        ModEvent.PushFloat(calledEvt, 0.0)
        ModEvent.PushForm(calledEvt, akActor)
        ModEvent.Send(calledEvt)
    EndIf

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
     The native side already held the removal for kRemoveConfirmScans (~3 min
     of continuous non-teammate; TeammateMonitor.h) or saw an explicit WFP=-1
     custom dismiss, so framework flag flips (Sofia-class, seconds-to-minutes)
     never reach this handler. The 2.5s Papyrus confirmation below stays as a
     final re-check before treating it as a real dismiss.}
    Actor akActor = sender as Actor
    If !akActor
        akActor = Game.GetFormEx(numArg as int) as Actor
    EndIf

    If !akActor || !IsRegisteredFollower(akActor)
        Return
    EndIf

    If IsTrackOnlyFollower(akActor)
        ; Track-only membership is sticky - their own framework owns their
        ; lifecycle, and TeammateRemoved is the ONLY automatic path that
        ; eventually untracks a genuine framework dismissal (the confirm
        ; queue's !IsPlayerTeammate() / WFP=-1 branches -> UnregisterFollower).
        ; Reaching here means the native long confirmation fired, so proceed
        ; into the confirmation queue rather than no-op - just make the
        ; decision visible.
        Debug.Trace("[SeverActions_FollowerManager] TeammateRemoved on track-only follower " + akActor.GetDisplayName() + " - passed native long confirmation, treating as genuine dismissal candidate")
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
        DebugMsg("Vanilla dismiss candidate: " + akActor.GetDisplayName() + " - confirming in 2.5s (queue: " + PendingDismissCount + ")")
        ChronoArm(2.5)
    Else
        DebugMsg("Vanilla dismiss queue full (32) - dropping: " + akActor.GetDisplayName())
    EndIf
EndEvent

Event OnVanillaFollowTopic(string eventName, string strArg, float numArg, Form sender)
    {Native VanillaFollowTopicMonitor: the player used the VANILLA follower
     dialogue (Wait here / Follow me) on an SA-registered follower. SA does
     not fill the vanilla DialogueFollower alias (NFF coexistence), so the
     vanilla fragment fires against an empty alias and silently no-ops -
     route the verb through SA's own wait/follow machinery instead.}
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

    ; Kidnap exemption (mirrors the one in SeverActions_Arrest): a kidnap
    ; participant legitimately holds our keywords — the HELD victim sits on
    ; a runtime BoundCaptiveMarker via FurnitureTargetKW (deliberately NOT
    ; registered with FurnitureManager, whose distance auto-cleanup would
    ; free them), and mid-job actors carry travel state. The kidnap system
    ; owns their teardown.
    If SeverActionsNativeExt.Native_Kidnap_GetPhase(npc) != 0 \
        || SeverActionsNativeExt.Native_Kidnap_FindVictimOf(npc) != None
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

    If SchedSystemActive()
        ; Post-migration: quest aliases persist and re-apply themselves on 3D
        ; load — no marker-slot work here. What still needs a cell-load pass:
        ;  - re-assert the runtime-only ASSIST overrides (track-only V2,
        ;    guard-mode follow), which cell transitions drop like any PO3
        ;    override;
        ;  - the same registered-follower self-heal as the legacy path.
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
                ElseIf HoldsAnySchedAlias(npcA)
                    _ReassertSchedAssistsFor(npcA)
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

; Resolve the target actor for a PrismaUI per-actor ModEvent. Prefers the EXACT
; reference passed as the ModEvent sender (PrismaUIActionHandler::SendModEvent
; sets it from the FormID the UI sent) — this disambiguates followers that share
; a generic display name (e.g. several "Vampire Fledgling"), which the strArg
; name encoding cannot. Falls back to name lookup when sender is None (older
; callers, or an orphan the C++ side couldn't resolve).
Actor Function ResolvePrismaTarget(Form akSender, String asActorName)
    Actor target = akSender as Actor
    If target
        Return target
    EndIf
    Return SeverActionsNative.FindActorByName(asActorName)
EndFunction

Event OnPrismaAssignHome(string eventName, string strArg, float numArg, Form sender)
    {Fired by PrismaUI when user clicks "Assign Home Here".
     strArg = "actorName|locationName" — name-based to avoid ESL FormID sign issues.}
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

    Actor akActor = ResolvePrismaTarget(sender, actorName)
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
    Actor akActor = ResolvePrismaTarget(sender, actorName)
    If !akActor
        Debug.Trace("[SeverActions_FollowerManager] PrismaSetWorkLoc: could not resolve actor '" + actorName + "'")
        Return
    EndIf
    ; "Set Work Here" is a quick spatial mark (parity with "Set Home Here") —
    ; drops the marker at the player, no retainer popup. The retainer offer
    ; lives in the AssignWork action flow.
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
    {Fired by PrismaUI when user clicks "Set Play Here".}
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

; =============================================================================
; NFF INTEGRATION
; =============================================================================

Bool Function HasNFF()
    {Check if Nether's Follower Framework is installed}
    Return Game.GetModByName("nwsFollowerFramework.esp") != 255
EndFunction

Bool Function HasSFF()
    {Check if Simple Follower Framework is installed. SFF OVERRIDES the vanilla
     DialogueFollower quest (0x000750BA) and re-implements DialogueFollowerScript
     with a primary alias PLUS an SFFExtraAliases[] pool for followers 2-8, each
     carrying the vanilla follow package. If SA routes recruit through the
     (now SFF) SetFollower, a 2nd+ follower lands in an SFF EXTRA alias that
     SA's GetAlias(0)-only cleanup can never clear on dismiss - the NPC keeps an
     unremovable vanilla PlayerFollowerPackage (forces a save revert). Detecting
     SFF lets us skip the vanilla routing entirely, exactly like the NFF gate:
     SA already owns the follow package / teammate / CFF, so the only thing lost
     is vanilla follower IDLE dialogue, and nothing spreads into SFF's aliases.}
    Return Game.GetModByName("Simple Follower Framework.esp") != 255
EndFunction


nwsFollowerControllerScript Function GetNFFController()
    {NFF's controller quest (nwsFollowerController, 0x0000434F) cast to its
     script, or None when NFF is not installed. Cached per session - the quest
     form cannot change mid-session, and every call site null-checks anyway.

     Routing THROUGH NFF instead of around it is the whole point: NFF marks its
     followers by filling them into its own aliases, so anything we do to their
     packages behind its back leaves the two frameworks disagreeing about who
     owns the NPC - the "in neither roster, cannot be dismissed" reports.}
    ; Resolved LOCALLY, never held in a script variable: a script-scope handle
    ; typed to a soft-dependency script would be serialized into every save,
    ; including the ~99% of users with no NFF in their load order. Every other
    ; soft dep here (Serana's mental model, SeversHearth camp) casts on demand
    ; for the same reason. The lookup is one native bool plus one
    ; GetFormFromFile, and these paths run on player actions, not per frame.
    If !SeverActionsNativeExt2.Native_IsNFFInstalled()
        Return None
    EndIf
    nwsFollowerControllerScript nff = Game.GetFormFromFile(0x0000434F, "nwsFollowerFramework.esp") as nwsFollowerControllerScript
    If !nff
        Debug.Trace("[SeverActions_FollowerManager] NFF is installed but its controller quest did not resolve - falling back to SA handling")
    EndIf
    Return nff
EndFunction

Function InvalidateTrackOnlyCache(Actor akActor)
    {Drop the memoized track-only verdict for one actor. REQUIRED whenever
     ownership is deliberately changed: the memo's docstring assumes its inputs
     are session-static, and that stopped being true when the top-precedence
     signal became NFF's alias seat - which NFFRecruit/NFFDismiss mutate
     mid-session. Without this, RegisterFollower hands an NPC to NFF and then
     reads a cached "not track-only" a few lines later, so SA takes full package
     ownership of the actor it just handed away.}
    If akActor
        StorageUtil.UnsetIntValue(akActor, "SeverActions_TOCacheEpoch")
        StorageUtil.UnsetIntValue(akActor, "SeverActions_TOCacheVal")
    EndIf
EndFunction

Bool Function NFFWait(Actor akActor)
    {Ask NFF to park one of ITS followers. TRUE when NFF handled it.}
    If !akActor || !SeverActionsNativeExt2.Native_IsNFFManaged(akActor)
        Return false
    EndIf
    nwsFollowerControllerScript nff = GetNFFController()
    If !nff
        Return false
    EndIf
    nff.FollowerWaitHere(akActor, 0, 0)
    Debug.Trace("[SeverActions_FollowerManager] NFFWait: routed wait for " + akActor.GetDisplayName() + " through NFF")
    Return true
EndFunction

Bool Function NFFResume(Actor akActor)
    {Release one of NFF's followers from NFF's wait - the counterpart to
     NFFWait. Without it we could park an NFF follower in NFF's own wait state
     and never get them out, because clearing the vanilla WaitingForPlayer AV
     does not reach NFF's packages (which is the whole reason the wait routes
     through NFF in the first place). Wait and resume must stay symmetric.}
    If !akActor || !SeverActionsNativeExt2.Native_IsNFFManaged(akActor)
        Return false
    EndIf
    nwsFollowerControllerScript nff = GetNFFController()
    If !nff
        Return false
    EndIf
    nff.FollowerFollowMe(akActor, 0)
    Debug.Trace("[SeverActions_FollowerManager] NFFResume: released " + akActor.GetDisplayName() + " from NFF's wait")
    Return true
EndFunction

Faction Function NFFSparFaction()
    {NFF's own spar-exemption faction (nwsFF_SparFac) - membership is how NFF
     lets a follower fight while its protection logic runs. None when NFF is
     absent or an older build lacks the property; callers fall back to the
     dismiss route in that case.}
    nwsFollowerControllerScript nff = GetNFFController()
    If !nff
        Return None
    EndIf
    Return nff.nwsFF_SparFac
EndFunction

Bool Function NFFDismiss(Actor akActor, Bool abSilent = false)
    {Ask NFF to dismiss one of ITS followers. TRUE when NFF handled it.
     abSilent passes the (-1, 0) argument pair NFF's OWN spar flow uses when
     it dismisses a follower for a spar (decompile-verified,
     nwsFollower_Sparring.SparPrep -> RemoveAction(actor, -1, 0)): no
     dismissal message, no goodbye line. Use for transient releases the
     player should not perceive as a dismissal - the brawl strip.}
    If !akActor || !SeverActionsNativeExt2.Native_IsNFFManaged(akActor)
        Return false
    EndIf
    nwsFollowerControllerScript nff = GetNFFController()
    If !nff
        Return false
    EndIf
    If abSilent
        nff.RemoveFollower(akActor, -1, 0)
    Else
        nff.RemoveFollower(akActor, 0, 1)
    EndIf
    InvalidateTrackOnlyCache(akActor)
    Debug.Trace("[SeverActions_FollowerManager] NFFDismiss: routed dismissal for " + akActor.GetDisplayName() + " through NFF")
    Return true
EndFunction

Bool Function NFFRecruit(Actor akActor)
    {Hand recruitment to NFF so it registers them as a REAL follower instead of
     us quietly taking them (the "NFF doesn't pick them up" complaint). Only
     when NFF is installed and has not already claimed them. TRUE when NFF
     handled it.}
    If !akActor || !SeverActionsNativeExt2.Native_IsNFFInstalled()
        Return false
    EndIf
    If SeverActionsNativeExt2.Native_IsNFFManaged(akActor)
        ; Seat-detected as NFF's. But the widened detector (DialogueFollower)
        ; also matches a VANILLA-recruited follower NFF has not actually
        ; imported (review finding) - short-circuiting for them meant
        ; RecruitFollower never ran while the eviction guard still stripped
        ; SA's machinery: the neither-roster bug from the opposite direction.
        ; So fall through and let NFF's own RecruitFollower run; NFF's spar
        ; flow calls RecruitAction on actors of varying membership state
        ; (decompile-verified), so the call is tolerated when already
        ; imported, and it is exactly what a vanilla-seated actor needs.
        Debug.Trace("[SeverActions_FollowerManager] NFFRecruit: " + akActor.GetDisplayName() + " already seated - importing through NFF anyway (vanilla-seat case)")
    EndIf
    ; NEVER force NFF to take an actor another framework owns. The ignore token
    ; is NFF's OWN opt-out, and calling RecruitFollower directly walks straight
    ; past it - we would be making NFF claim the exact NPCs both mods agree it
    ; must not manage (Serana, Inigo, Lucien, Kaidan...). Read the markers
    ; DIRECTLY rather than via IsTrackOnlyFollower, because owner==NFF now also
    ; reports track-only and would refuse every legitimate hand-off.
    Int owner = SeverActionsNativeExt2.Native_GetFollowerOwner(akActor)
    If owner == 3 || owner == 4   ; DLC-managed or custom-AI
        Return false
    EndIf
    nwsFollowerControllerScript nff = GetNFFController()
    If !nff
        Return false
    EndIf
    nff.RecruitFollower(akActor)
    InvalidateTrackOnlyCache(akActor)
    Debug.Trace("[SeverActions_FollowerManager] NFFRecruit: routed recruitment for " + akActor.GetDisplayName() + " through NFF")
    Return true
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
    DebugMsg("DismissViaVanillaDialogue: " + akActor.GetDisplayName() + " not in vanilla alias - skipping")
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

Function ReconcileTrackOnlyOwnership()
    {Self-healing pass: any follower who classifies track-only NOW but still
     carries SA's follow-ownership flag gets it released, plus any SA sandbox
     override stripped. Runs on every load (RunDeferredMaintenance) and is a
     no-op once the roster is clean - the mismatch is what it acts on, so no
     migration sentinel is needed and a follower who LATER gains the keyword
     is healed on the next load too.}
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
        If a && IsTrackOnlyFollower(a) && (SeverActionsNative.Native_GetHasFollowPkg(a) || aliasHeld)
            ; Strip our package before releasing the claim - StopSandbox only
            ; removes SA's OWN override, which is safe on a track-only actor
            ; (the blanket rule bans mass package-stack mutation, not removing
            ; the override we should never have applied).
            ; ORDER MATTERS. StopSandbox is not the narrow override-removal it
            ; looks like: it reads hasFollowPkg and, for an actor with no
            ; follower slot, RE-REGISTERS SkyrimNet's FollowPlayer package -
            ; the exact stray-package bug its own comment documents. Release
            ; our claim FIRST so that branch sees false, then let it clean up.
            SeverActionsNativeExt2.Native_ClearSAFollowOwnership(a)
            If followSys
                ; THE ALIAS SEAT TOO (pre-NFF-companion field report): clearing
                ; the flags is not enough - a follower recruited before NFF was
                ; installed still holds a 200-pool alias whose follow package
                ; re-applies NATIVELY on cell load. That seat is why they kept
                ; following through NFF recruit AND dismiss: NFF emptied its own
                ; alias, ours kept driving them. ClearFollowerSlot evicts pool +
                ; legacy slot + overflow, with a pool-scan fallback.
                followSys.ClearFollowerSlot(a)
                followSys.StopSandbox(a)
            EndIf
            InvalidateTrackOnlyCache(a)
            Debug.Trace("[SeverActions_FollowerManager] ReconcileTrackOnlyOwnership: " + a.GetDisplayName() + " is owned by " + SeverActionsNativeExt2.Native_GetFollowerOwnerName(a) + " - released SA's claim")
            healed += 1
        EndIf
        i += 1
    EndWhile
    If healed > 0
        Debug.Trace("[SeverActions_FollowerManager] ReconcileTrackOnlyOwnership: released SA follow ownership on " + healed + " track-only follower(s)")
    EndIf
EndFunction

Bool Function IsTrackOnlyFollower(Actor akActor)
    {Returns true if this actor has their own follow system and should not get our packages.
     Covers: Custom AI keyword holders (SPID-distributed), NFF ignore-token holders,
     and DLC-managed followers (Serana). Vanilla NPCs always get full SeverActions setup.

     Memoized per session (delegates to ComputeIsTrackOnly): the underlying
     signals - a SPID keyword, an NFF MISC token, a DLC faction - are all
     session-static, so the 4 sub-checks (3 of them a GetFormFromFile) run once
     per actor per session instead of on every 30s sweep across all 15 call
     sites. The per-actor cache is stamped with a session epoch that Maintenance
     bumps each load, so a load-order change that alters the signals re-validates
     cleanly. The classification LOGIC is unchanged - this only caches its result,
     so the safety-critical track-only gate can never drift from the source.}
    If !akActor
        Return false
    EndIf
    Int epoch = StorageUtil.GetIntValue(None, "SeverActions_TOEpoch", 0)
    If StorageUtil.GetIntValue(akActor, "SeverActions_TOCacheEpoch", -1) == epoch
        ; Cached this session: 1 = track-only, 2 = not (0/unset never stored).
        Return StorageUtil.GetIntValue(akActor, "SeverActions_TOCacheVal", 2) == 1
    EndIf
    Bool result = ComputeIsTrackOnly(akActor)
    StorageUtil.SetIntValue(akActor, "SeverActions_TOCacheEpoch", epoch)
    If result
        StorageUtil.SetIntValue(akActor, "SeverActions_TOCacheVal", 1)
    Else
        StorageUtil.SetIntValue(akActor, "SeverActions_TOCacheVal", 2)
    EndIf
    Return result
EndFunction

Bool Function ComputeIsTrackOnly(Actor akActor)
    {Authoritative (uncached) track-only classification - the OR of the four
     signals. IsTrackOnlyFollower memoizes this; call it directly only to force a
     bypass of the per-session cache (no current caller needs to).}
    ; Native_IsListedCustomAI reads the same DISTR ini natively - coverage
    ; without SPID installed, and by NAME (so forks that renamed the EditorID,
    ; which the SPID line's name+editorID AND-filter misses, still classify).
    ; ONE SOURCE OF TRUTH (2026-08-11). This used to be the OR of four
    ; separately-read marker checks here in Papyrus, while other consumers
    ; inferred ownership from their own mix of flags and factions - and when
    ; those disagreed the symptom always surfaced somewhere far away (a stale
    ; hasFollowPkg had SA fighting Serana's DLC AI and cancelling the player's
    ; Wait; no NFF signal at all had us claiming NFF's own followers).
    ;
    ; Native_GetFollowerOwner computes the verdict from every signal at once -
    ; NFF alias seat, DLC1SeranaFaction, SPID keyword / NFF ignore token /
    ; curated list, our store flags, vanilla CurrentFollowerFaction - with a
    ; deliberate precedence. Track-only means simply: SOMEONE ELSE owns them.
    ; 0 None | 1 SeverActions | 2 NFF | 3 DLC | 4 CustomAI | 5 Vanilla
    Int owner = SeverActionsNativeExt2.Native_GetFollowerOwner(akActor)
    Return owner == 2 || owner == 3 || owner == 4
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

Function ChronoArm(Float afSeconds)
    {Arm this script's one-shot chronometer tick - replaces the FORM-keyed
     RegisterForSingleUpdate (canonical explanation: the Chronometer block in
     SeverActionsNativeExt2.psc + the CLAUDE.md lesson). Event name AND
     callback name are unique per script - both, always. Re-arm replaces the
     pending tick; ticks do NOT survive save/load (load paths re-arm); at
     most one already-in-flight wake can land after Cancel/Clear, so keep
     the handler state-guarded.}
    RegisterForModEvent("SeverActions_Tick_FollowerManager", "OnChronoTick_FollowerManager")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_FollowerManager", afSeconds)
EndFunction

Event OnChronoTick_FollowerManager(String eventName, String strArg, Float numArg, Form sender)
    ; LOOP RESILIENCE (kidnap regression debug): re-arm the 30s tick FIRST,
    ; unconditionally. Every later ChronoArm simply replaces
    ; this one, but a silent stack death anywhere below can no longer kill
    ; the update loop for the rest of the session.
    ChronoArm(30.0)

    ; Chronometer-liveness stamp for Init's post-load watchdog (a stale DLL
    ; means no ticks at all - see RunLoadRecovery's tail).
    StorageUtil.SetFloatValue(None, "SeverActions_ChronoTickRT", Utility.GetCurrentRealTime())

    ; RE-ENTRANCY GUARD (maxed-roster field report: 4 concurrent OnUpdate
    ; stacks in one VM dump). With a huge roster the pass below can outlive
    ; its own 30s tick under heavy VM load, and each re-fire stacked another
    ; full pass on top - compounding the very congestion that slowed the
    ; first one. One pass at a time; a skipped tick re-arms and catches up.
    ; The 120s real-time ceiling means a stack that DIED mid-pass (dumped by
    ; the VM) can never wedge the loop shut.
    If _OnUpdateInFlight && (Utility.GetCurrentRealTime() - _OnUpdateStartRT) < 120.0
        Return
    EndIf
    _OnUpdateInFlight = true
    _OnUpdateStartRT = Utility.GetCurrentRealTime()
    ; The pass lives in its own function so every early Return inside it
    ; still lands back here and releases the guard.
    _OnUpdatePass()
    _OnUpdateInFlight = false
EndEvent

Function _OnUpdatePass()
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
        ; BeginSchedAliasMigration (inside RunDeferredMaintenance) may have
        ; armed a 0.5s batch drain — don't clobber its timer with the 30s one.
        If !SchedMigrationPending
            ChronoArm(30.0)
        EndIf
        Return
    EndIf

    ; Schedule-alias migration batch drain (design doc section 4): kicked off by
    ; BeginSchedAliasMigration() during deferred maintenance; processes a small
    ; batch of NPCs per 0.5s fire until the pending list is exhausted.
    If SchedMigrationPending
        ProcessSchedMigrationBatch()
        Return
    EndIf

    ; Ambient-action SOCIAL gate — non-blocking poll while a gate is armed
    ; (replaces the old ~40s Utility.Wait loop). The native gate owns settle
    ; detection + adjudication + the busy lock; we poll every ~2s and commit only
    ; on a GO verdict. Skips the heavy 30s body during the gate — a social scene
    ; is seconds-scale, and AmbientActionInProgress blocks any new cycle anyway.
    If AmbientGatePolling
        PollAmbientGate()
        If AmbientGatePolling
            ChronoArm(2.0)
        EndIf
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
                String travelState = StorageUtil.GetStringValue(checkActor, "SeverTravel_State", "")
                If travelState == "traveling" || travelState == "waiting"
                    ; SA travel suspends the teammate flag for the trip
                    ; (Travel.psc DismissFollower) — that is NOT a dismissal.
                    ; Without this gate the errand chain was: travel clears the
                    ; flag → TeammateMonitor flags a removal → this confirm
                    ; fully unregisters the traveler mid-journey (linked-ref
                    ; wipe, SendHome fighting the trip, "no longer your
                    ; companion"). ReinstateFollower restores the flag on
                    ; return; a real mid-trip dismissal goes through
                    ; DismissCompanion directly and never lands in this queue.
                    DebugMsg("Dismiss skipped (SA travel in progress): " + checkActor.GetDisplayName())
                ElseIf !checkActor.IsPlayerTeammate()
                    ; Teammate flag dropped — usually a clear-cut vanilla dismiss.
                    ; BUT a custom follower's own framework may not keep the
                    ; player-teammate flag set while still following (Rin field
                    ; 2026-08-28: her own PlayerFollowerPackage keeps her following
                    ; with no persistent teammate flag, so a bare !IsPlayerTeammate()
                    ; kept untracking her on every sweep). For a TRACK-ONLY
                    ; follower, veto the untrack when there is LIVE follow
                    ; evidence: still in the vanilla follow faction, or currently
                    ; running the vanilla PlayerFollowerPackage. Their own mod
                    ; owns their lifecycle, so keep tracking them until that
                    ; evidence is actually gone (or a WFP=-1 custom dismiss below).
                    Bool stillFollowing = IsTrackOnlyFollower(checkActor) && IsStillFollowingByEvidence(checkActor)
                    If stillFollowing
                        DebugMsg("Track-only still following (faction/package evidence) - keeping tracked: " + checkActor.GetDisplayName())
                    Else
                        confirmed = true
                    EndIf
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
        ChronoArm(30.0)
        Return
    EndIf

    If IsUpdating
        ; Stuck-guard watchdog: if a previous tick's stack died between
        ; setting and clearing this flag, every subsequent tick would
        ; early-return here forever (silently starving KidnapTick and the
        ; rest of the body). Real-time window instead of trusting the flag.
        If (Utility.GetCurrentRealTime() - IsUpdatingSetRT) > 45.0
            Debug.Trace("[SeverActions_FollowerManager] OnUpdate: IsUpdating STUCK - previous tick died mid-body, clearing")
            IsUpdating = false
        Else
            ChronoArm(30.0)
            Return
        EndIf
    EndIf

    ; Watchdog — if the off-screen-life ModEvent never arrived, clear the
    ; in-progress flag after 120s real-time so future events aren't blocked.
    If OffScreenLifeInProgress && (Utility.GetCurrentRealTime() - OffScreenLifeStartedRT) > 120.0
        DebugMsg("Off-screen life watchdog: clearing stuck InProgress flag (>120s without ready ModEvent)")
        OffScreenLifeInProgress = false
        PendingOffScreenLifeActor = None
    EndIf

    IsUpdating = true
    IsUpdatingSetRT = Utility.GetCurrentRealTime()

    ; Every-30s pass (real time, no game-hour gate): re-assert held kidnap
    ; captives' bound pose + heal legacy furniture-bound captives. No-op
    ; with no active kidnaps.
    KidnapTick()

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
    Float tPrologue = Utility.GetCurrentRealTime()

    ; Issue #402: one read of the era gate for the whole tick. SchedSystemActive()
    ; is EnsureSchedQuests() plus a native cosave read, and it used to be asked
    ; once per NPC per pass inside CheckSceneSuspendedHomes.
    Bool tickSchedActive = SchedSystemActive()

    ; Issue #402: build the HOMED roster once here, exactly as tickFollowers is
    ; built below and for the same reason. Four passes used to walk
    ; KEY_HOMED_NPCS per tick — the schedule swaps, ProcessHomeSleep,
    ; ProcessHomeMarkerHops, and CheckSceneSuspendedHomes via its own
    ; GetAllHomedNPCs() call. (ProcessWorkOnlySwaps* is a fifth walk but over
    ; the SEPARATE KEY_WORK_ONLY_NPCS list, so it is not consolidated here.)
    ; Built AFTER CheckDeadFollowers + CheckTrackOnlyFollowerStatus for the same
    ; freshness reason tickFollowers is.
    ;
    ; GetAllHomedNPCs is the VALIDATING build — it prunes stale rows whose home
    ; was cleared without list cleanup.
    ;
    ; CONSUMERS: ProcessHomeSleep, ProcessHomeMarkerHops, and
    ; CheckSceneSuspendedHomes' Route B tail. The schedule passes deliberately
    ; do NOT take this array and keep their raw KEY_HOMED_NPCS walk — the slow
    ; lane has to be able to prune list rows that this validated array has
    ; already dropped, which it could not do from a filtered copy.
    Actor[] tickHomed = GetAllHomedNPCs()
    ; The sleep window is one game-hour test shared by the bed conductor and the
    ; room-rotation pass (which must defer to it). Derived once.
    Bool tickSleepOpen = HomeSleepEnabled && HourInWindow(GetCurrentGameHour(), HomeSleepStart, HomeSleepEnd)
    Float tHomedRoster = Utility.GetCurrentRealTime()

    ; Schedule system — pre-migration: move HomeMarker to correct anchor
    ; (home/work/play) on hour transitions. Post-migration: reconcile the
    ; per-NPC schedule alias pools instead (design doc section 2).
    ; Issue #402: both the homed and work-only passes route through here now.
    ; Ordinary rosters get the unchanged full walks; a large alias-era roster
    ; gets the native due set plus a chunked slow lane.
    ProcessSchedulePasses(tickSchedActive)
    Float tSchedPasses = Utility.GetCurrentRealTime()
    ; Homed NPCs find their claimed bed during the sleep window (dev145).
    ProcessHomeSleep(tickHomed, tickSleepOpen)
    Float tHomeSleep = Utility.GetCurrentRealTime()
    ; Room rotation (named markers 5.5): homed NPCs hop their sandbox anchor
    ; between the home's named markers. After ProcessHomeSleep on purpose -
    ; the sleep conductor owns the bed window and this pass defers to it.
    If RoomRotationEnabled
        ProcessHomeMarkerHops(tickHomed, tickSleepOpen)
    EndIf
    Float tRoomHops = Utility.GetCurrentRealTime()

    ; Perf: build the active roster ONCE here and thread it to every
    ; read-only consumer below. GetAllFollowers does a native cell scan plus
    ; N IsRegisteredFollower VM calls and O(N^2) dedup; the downstream passes
    ; used to each call it independently (up to 5 redundant scans per tick).
    ; Built here — AFTER CheckDeadFollowers + CheckTrackOnlyFollowerStatus,
    ; which can unregister followers — so consumers never act on a roster
    ; entry that was just removed earlier this tick.
    Actor[] tickFollowers = GetAllFollowers()
    Float tFollowerRoster = Utility.GetCurrentRealTime()

    ; Wave 6.2: scene-aware home suspend/restore. If a registered follower is
    ; pulled into a vanilla BGSScene (quest scene, Serana lab search, etc.),
    ; release our home alias so the scene's own package can drive cleanly;
    ; restore once the scene ends. See CheckSceneSuspendedHomes docs.
    CheckSceneSuspendedHomes(tickFollowers, tickHomed, tickSchedActive)
    Float tSceneSuspend = Utility.GetCurrentRealTime()

    ; Refresh IgnoreFriendlyHits on registered followers if the FF-prevention
    ; toggle is on. The flag can get dropped by AI state transitions (sandbox
    ; <-> combat <-> dismiss/recruit); re-stamping every 30s is cheap and
    ; guarantees the protection holds even if something else resets it.
    RefreshFriendlyFireFlags(tickFollowers)
    Float tFFFlags = Utility.GetCurrentRealTime()

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
    ; MUTUAL EXCLUSION with ambient actions: the two systems draw from the
    ; same nearby-NPC pool, so neither may even START a cycle while the other
    ; is in flight — same-tick double dispatch once staged two scenes on the
    ; same NPCs seconds apart. The shared separation stamp inside the Check
    ; functions handles the after-completion spacing.
    If AutoAmbientBanter && !AmbientBanterInProgress && !AmbientActionInProgress
        CheckAmbientBanter()
    EndIf

    ; Ambient actions — the "promote" half of the Action Orchestrator. Its own
    ; cooldown + flag; independent of the assessment systems but mutually
    ; exclusive with ambient banter (see above). Default OFF (AutoAmbientActions)
    ; while the feature is proven.
    If AutoAmbientActions && !AmbientActionInProgress && !AmbientBanterInProgress
        CheckAmbientAction()
    EndIf
    Float tEnd = Utility.GetCurrentRealTime()

    TraceTickTimings(tickFollowers.Length, tickHomed.Length, \
        tPrologue, tHomedRoster, tSchedPasses, tHomeSleep, \
        tRoomHops, tFollowerRoster, tSceneSuspend, tFFFlags, tEnd)

    IsUpdating = false
    ChronoArm(30.0)
EndFunction

Float Property TICK_TRACE_BUDGET_SEC = 0.25 AutoReadOnly
{Issue #402: a tick slower than this emits ONE always-on breakdown line. The
 30s heartbeat has 30s of headroom, so 250ms is nowhere near a deadline — it is
 the "this is no longer trivial, watch it" mark. Deliberately always-on rather
 than DebugMode-gated: a field report from a player who never enabled DebugMode
 has to be able to answer "which pass ate the time, and how big was the
 roster", the way CosaveAudit answers it for co-save sizes.}

Function TraceTickTimings(Int followerCount, Int homedCount, \
    Float tPrologue, Float tHomedRoster, Float tSchedPasses, \
    Float tHomeSleep, Float tRoomHops, Float tFollowerRoster, Float tSceneSuspend, \
    Float tFFFlags, Float tEnd)
    {Emit the per-pass real-time breakdown for one OnUpdate pass.

     The stamps arrive as absolute GetCurrentRealTime() readings taken between
     passes; this function does the subtraction so the hot path only pays a
     native read per boundary. Ordering matches _OnUpdatePass top-to-bottom.

     Emits when the measured span exceeds TICK_TRACE_BUDGET_SEC, or always under
     DebugMode. Note the span starts at tPrologue (after KidnapTick /
     TickRelationships / the death + track-only sweeps) because those are
     single-native-call passes that issue #402 explicitly left alone — the
     roster-scaling work is what this measures.}
    Float total = tEnd - tPrologue
    If total < TICK_TRACE_BUDGET_SEC && !DebugMode
        Return
    EndIf
    ; llmScans is the five LLM selection scans as one block — at most one of
    ; them fires per tick and they share the follower roster, so a per-scan
    ; breakdown would cost more stamps than it would ever explain.
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
    {Re-stamp IgnoreFriendlyHits(true) on all registered followers if the
     "Prevent Follower Friendly Fire" toggle is on. No-op if off. The flag
     can drop silently during AI state transitions so we pay a few Actor
     function calls every 30s to keep it anchored. Roster passed in by the
     OnUpdate tick to avoid a redundant GetAllFollowers scan.}
    Quest SeverActionsQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
    If !SeverActionsQuest
        Return
    EndIf
    ; DEFAULT 1, and it must STAY 1. SeverActions_Follow.psc's load-time restore
    ; reads this same key with a default of 1 and says so in its comment ("everyone
    ; else gets protection on by default"). This read defaulted to 0, so for every
    ; player who never explicitly touched the toggle the two disagreed: the monitor
    ; and the iAllyHit* game settings came up enabled while THIS re-stamp — the one
    ; the docstring above calls load-bearing, because the flag drops during AI state
    ; transitions — silently never ran. Protection still applied at recruit and at
    ; load, so it did not fail outright; it decayed over a long session, which reads
    ; as "AoE hurts my followers, but only sometimes". Two reads of one key, two
    ; defaults. If you add a third, match it.
    If StorageUtil.GetIntValue(SeverActionsQuest, "SeverActions_PreventFollowerFF", 1) != 1
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

    ; Rapport/mood decay REMOVED (user request 2026-08-23): mood no longer drifts
    ; toward a rapport-derived baseline and rapport no longer bleeds from neglect.
    ; Pass 0 for both deltas so the native ticker's mood-drift and rapport-neglect
    ; blocks no-op (moodChange 0 -> mood frozen; rapportLossOnNeglect 0 -> neglect
    ; branch skipped). The call stays for the autonomous-leaving threshold pass,
    ; which now depends purely on event/assessment-driven rapport.
    Float moodChange           = 0.0
    Float rapportLossOnNeglect = 0.0
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
    {Thin compatibility wrapper for any external caller that still invokes the
     per-actor entry point. The entire roster now ticks inside C++ in
     TickRelationships above.}
    If !akFollower || hoursPassed <= 0.0
        Return
    EndIf
    ; Rapport/mood decay REMOVED (2026-08-23) - deltas forced to 0 (see TickRelationships).
    Float moodChange = 0.0
    Float rapportLossOnNeglect = 0.0
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
        DebugMsg("Outfit excluded: " + akActor.GetDisplayName() + " - skipping outfit slot assignment")
        Return
    EndIf

    ; Guard against duplicate assignment — if already in a slot, skip
    Int check = 0
    While check < OutfitSlots.Length
        If OutfitSlots[check] && OutfitSlots[check].GetActorRef() == akActor
            DebugMsg("Outfit slot " + check + " already assigned to " + akActor.GetDisplayName() + " - skipping")
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

    ; Also re-bind actors wearing a SLOT preset — the registry that replaces the
    ; legacy lock as it retires. A dismissed follower / dressed non-follower whose
    ; outfit is a slot preset (not a legacy lock) must keep its alias binding or it
    ; goes naked on the next load. AssignOutfitSlot is idempotent for an already-
    ; assigned actor, so overlap with the lists above is harmless.
    Actor[] presetActors = SeverActionsNativeExt2.Native_OutfitSlot_GetActorsWithActivePreset()
    i = 0
    While i < presetActors.Length
        If presetActors[i]
            Bool alreadyBound = false
            Int k = 0
            While k < followers.Length
                If followers[k] == presetActors[i]
                    alreadyBound = true
                    k = followers.Length ; break
                EndIf
                k += 1
            EndWhile
            If !alreadyBound
                AssignOutfitSlot(presetActors[i])
                totalAssigned += 1
                DebugMsg("Outfit slot re-bound for preset actor: " + presetActors[i].GetDisplayName())
            EndIf
        EndIf
        i += 1
    EndWhile

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
    If !EssentialSlots
        ; Belt: lazy init failed (should be impossible - EnsureEssentialSlots
        ; unconditionally allocates). Bail instead of erroring on .Length.
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
     Called from OnUpdate when DeathGracePeriodHours > 0.

     Tier 1 perf: the death set comes from Native_GetDeadTrackedFollowers - ONE
     native call returning only the (almost always empty) dead followers - instead
     of walking all ~21 OutfitSlots with a GetActorRef + IsDead round-trip on each,
     every 30s. It walks the same FollowerDataStore the roster does, so it also
     catches a dead follower who overflowed past the alias-slot cap (invisible to
     the old OutfitSlots-only scan). The death-time / grace / purge logic below is
     unchanged.}
    Actor[] dead = SeverActionsNativeExt.Native_GetDeadTrackedFollowers()
    If !dead || dead.Length == 0
        Return
    EndIf
    Float currentTime = GetGameTimeInSeconds()

    Int i = 0
    While i < dead.Length
        Actor slotActor = dead[i]
        ; Native already filtered to tracked + dead; no per-actor IsDead re-check.
        If slotActor
            ; T1-B: native source of truth for the death timestamp.
            Float deathTime = SeverActionsNativeExt.Native_GetDeathTime(slotActor)
            If deathTime == 0.0
                ; First detection — record death time
                SeverActionsNativeExt.Native_SetDeathTime(slotActor, currentTime)
                DebugMsg("Death detected: " + slotActor.GetDisplayName() + " - grace period started (" + DeathGracePeriodHours + " hours)")
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
        i += 1
    EndWhile
EndFunction

Bool Function IsStillFollowingByEvidence(Actor akActor)
    {Live evidence that a follower is STILL following the player, INDEPENDENT of
     the player-teammate flag — which a custom follower's own framework may not
     keep set. Rin (2026-08-28) follows via her own PlayerFollowerPackage with no
     persistent teammate flag, so a bare !IsPlayerTeammate() test read her as
     dismissed and untracked her every sweep. True when she is still in the
     vanilla follow faction (CurrentFollowerFaction 0x5C84E, rank >= 0) — the
     robust signal, set regardless of WHICH follow package holds them — or is
     currently running the vanilla PlayerFollowerPackage (0x5C84B). Used to veto
     the track-only auto-untrack in BOTH the 30s sweep and the dismiss queue.}
    If !akActor
        Return false
    EndIf
    Faction cffEv = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
    If cffEv && akActor.GetFactionRank(cffEv) >= 0
        Return true
    EndIf
    ; PlayerFollowerFaction — the faction SkyrimNet's own is_follower reads, so a
    ; custom follower flagged "in the companion faction" sits here even if not in
    ; CurrentFollowerFaction. Accept either.
    Faction pffEv = Game.GetFormFromFile(0x00084D1B, "Skyrim.esm") as Faction
    If pffEv && akActor.GetFactionRank(pffEv) >= 0
        Return true
    EndIf
    Package pfpEv = Game.GetFormFromFile(0x0005C84B, "Skyrim.esm") as Package
    If pfpEv && akActor.GetCurrentPackage() == pfpEv
        Return true
    EndIf
    Return false
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
                    If SeverActionsNativeExt.Brawl_IsActive(follower)
                        ; MID-BRAWL, NOT A DISMISS (issue #412 S1). The brawl
                        ; deliberately strips IsPlayerTeammate on both fighters
                        ; so the player's other followers don't pile in, and it
                        ; restores + re-recruits at brawl end. This was the ONE
                        ; consumer of that cleared flag without a brawl gate -
                        ; TeammateMonitor and CellCatchup both carry it and
                        ; cross-reference each other. Without this, sparring a
                        ; track-only follower (with NFF installed, that is EVERY
                        ; SA companion) dismissed them mid-fight: home package,
                        ; "no longer being tracked", LLM narrating the
                        ; departure, dismissed-key blocking re-onboarding.
                        DebugMsg("Track-only untrack SKIPPED: " + follower.GetDisplayName() + " is mid-brawl")
                    ElseIf IsStillFollowingByEvidence(follower)
                        ; Not a teammate, but STILL FOLLOWING via their own
                        ; framework (in the vanilla follow faction, or on the
                        ; vanilla PlayerFollowerPackage). A custom follower whose
                        ; mod never sets the player-teammate flag (Rin, 2026-08-28)
                        ; would otherwise be untracked by this 30s sweep on every
                        ; pass. The WFP=-1 branch below still catches a real
                        ; custom dismiss.
                        DebugMsg("Track-only untrack SKIPPED: " + follower.GetDisplayName() + " still following (faction/package evidence)")
                    Else
                        ; Teammate status cleared and no live follow evidence —
                        ; standard vanilla dismiss signal.
                        shouldUntrack = true
                        DebugMsg("Track-only auto-untrack: " + follower.GetDisplayName() + " lost teammate status")
                    EndIf
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
    StorageUtil.UnsetFloatValue(akActor, KEY_NEXT_ASSESS_GT)
    StorageUtil.UnsetFloatValue(akActor, KEY_NEXT_INTER_ASSESS_GT)
    StorageUtil.UnsetFloatValue(akActor, KEY_NEXT_LIFE_EVENT_GT)
    StorageUtil.UnsetFloatValue(akActor, KEY_DISMISS_GT)
    StorageUtil.UnsetIntValue(akActor, KEY_DISMISSED)
    StorageUtil.UnsetIntValue(akActor, KEY_TRUEHOME_MIGRATED)
    StorageUtil.UnsetFloatValue(akActor, "SeverFollower_HealerBleedoutLast")

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

    ; --- Clear work/play routine locations ---
    ; Tears down the work-package override + LinkedRefs and deletes the
    ; force-persisted work XMarker. Without this the marker leaked into the
    ; save and ProcessWorkOnlySwaps kept stamping packages onto the purged actor.
    ClearRoutineLoc(akActor, "work")
    ClearRoutineLoc(akActor, "play")
    ; ClearRoutineLoc re-stamps KEY_LAST_SCHEDULED_TYPE (-99) as a side effect;
    ; unset it after so the purged actor keeps no schedule bookkeeping at all.
    StorageUtil.UnsetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE)

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
            followSys.ClearWaitingFaction(akActor)
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
    Actor akActor = ResolvePrismaTarget(sender, actorName)
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
    Actor akActor = ResolvePrismaTarget(sender, actorName)
    If akActor
        DebugMsg("PrismaUI force-remove: " + akActor.GetDisplayName())
        PurgeFollower(akActor)
    Else
        Debug.Trace("[SeverActions_FollowerManager] PrismaUI force-remove: actor '" + actorName + "' not resolvable (orphan) - native stores already cleared")
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
    Actor akActor = ResolvePrismaTarget(sender, actorName)
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
    Actor akActor = ResolvePrismaTarget(sender, actorName)
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
    Actor akActor = ResolvePrismaTarget(sender, actorName)
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
    Float waStart = Utility.GetCurrentRealTime()
    Int ci = 0
    DebugMsg("PrismaUI wait-all: " + allComp.Length + " companion(s)")
    While ci < allComp.Length
        If allComp[ci]
            ; Quiet core: per-follower package work + per-actor state event, but
            ; no per-follower popup — one summary below instead of N stacked.
            _CompanionWaitCore(allComp[ci], true)
        EndIf
        ci += 1
    EndWhile
    If ShowNotifications
        If allComp.Length == 1
            Debug.Notification(allComp[0].GetDisplayName() + " is waiting here for you.")
        Else
            Debug.Notification(allComp.Length + " companions are waiting here for you.")
        EndIf
    EndIf
    ; Elapsed real seconds — the field diagnostic for -the button did nothing-
    ; reports on large rosters: this line proves the event FIRED and names the
    ; true cost of the per-follower package work.
    DebugMsg("PrismaUI wait-all: done in " + (Utility.GetCurrentRealTime() - waStart) + "s")
EndEvent

Event OnPrismaCompanionFollowAll(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: Break every active follower out of waiting and resume following.
     Inverse of OnPrismaCompanionWaitAll. Single ModEvent dispatch — same
     server-side iteration pattern.}
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
    If ShowNotifications
        If allComp.Length == 1
            Debug.Notification(allComp[0].GetDisplayName() + " is following you again.")
        Else
            Debug.Notification(allComp.Length + " companions are following you again.")
        EndIf
    EndIf
    DebugMsg("PrismaUI follow-all: done in " + (Utility.GetCurrentRealTime() - faStart) + "s")
EndEvent

Event OnPrismaResetAll(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: Dismiss all companions (the Companions page's Dismiss All).

     The roster MUST be snapshotted before the first dismissal: GetAllFollowers
     reads the live native store, and DismissCompanion -> UnregisterFollower
     clears each actor's isFollower flag as it goes. Re-reading mid-loop would
     shrink the array under us. Papyrus arrays are by-value copies, so the local
     is already a snapshot - this comment exists so nobody "optimizes" it into a
     re-read.

     The C++ side used to ALSO wipe the whole FollowerDataStore from an AddTask
     immediately after firing this event, which beat the VM to it: the wipe
     cleared every isFollower flag, GetAllFollowers below returned an empty
     array, and this loop dismissed nobody while the page went empty anyway.
     That wipe is gone - dismissal is entirely ours now, and so is the refresh.}
    Debug.Trace("[SeverActions_FollowerManager] PrismaUI reset all companions")
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
    Debug.Trace("[SeverActions_FollowerManager] PrismaUI reset all: dismissed " + dismissed)
    If dismissed > 0
        Debug.Notification("Dismissed " + dismissed + " companions")
    EndIf
    ; Refresh once the roster is ACTUALLY dismissed. The frontend also refreshes
    ; on a timer, but a large roster can outlast that; this is the authoritative
    ; repaint.
    SeverActionsNative.PrismaUI_RefreshPage("companions")
    SeverActionsNative.PrismaUI_RefreshPage("outfits")
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
    ; The Imperial Final Audit is unrecruitable BY DESIGN (Taxes P2): loyal
    ; to the Empire alone. Eligibility already hides SetCompanion for them -
    ; this is defense-in-depth against direct or scripted calls.
    If SeverActionsNativeExt2.Venture_Audit_IsCollector(akActor)
        SkyrimNetApi.RegisterEvent("follower_recruit_failed",             akActor.GetDisplayName() + " serves the Imperial Treasury alone - the Final Audit follows no one. Whatever business you have with them can be conducted right where they stand.",             akActor, None)
        Return
    EndIf
    ; Audit: a bound captive (seized or held, phase >= 2) cannot be recruited
    ; - follow packages and teammate state fight the hold pin every tick,
    ; cell-catchup teleports the "bound" NPC to the player, and follower
    ; status defeats the is_sever_follower eligibility protections.
    If SeverActionsNativeExt.Native_Kidnap_GetPhase(akActor) >= 2
        SkyrimNetApi.RegisterEvent("follower_recruit_failed",             akActor.GetDisplayName() + " is bound and held captive - they are in no position to follow anyone.",             akActor, None)
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

    ; NFF installed? Let NFF do the recruiting, so it registers them as a REAL
    ; follower with an alias seat of its own - "sever makes npcs follow you, so
    ; NFF doesn't pick them up as actual followers". Deliberately placed AFTER
    ; every guard that can abort this recruit (bound captive, roster cap):
    ; telling NFF first and then returning would seat the NPC in NFF while SA
    ; registers nothing - the "neither roster" split, inverted. No-op without
    ; NFF, and it refuses actors another framework owns.
    NFFRecruit(akActor)

    ; GUARD (pre-NFF-companion field report): if NFF now owns this actor, evict
    ; SA's OWN follow machinery for them - a companion recruited before NFF was
    ; installed still holds our 200-pool alias seat (its package re-applies on
    ; cell load) and possibly the legacy/overflow pair, so without this they
    ; kept OUR follow package while seated in NFF, and NFF's dismiss could
    ; never actually stop them. Exactly one framework drives an actor.
    InvalidateTrackOnlyCache(akActor)
    If SeverActionsNativeExt2.Native_IsNFFManaged(akActor)
        SeverActionsNativeExt2.Native_ClearSAFollowOwnership(akActor)
        SeverActions_Follow fsGuard = GetFollowScript()
        If fsGuard
            fsGuard.ClearFollowerSlot(akActor)
        EndIf
        Debug.Trace("[SeverActions_FollowerManager] RegisterFollower: NFF owns " + akActor.GetDisplayName() + " - evicted SA follow machinery (alias/legacy/overflow)")
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

    ; Vanilla LightFoot, so pressure plates and bear traps decline to fire on
    ; them. See the TRAP IMMUNITY block for why this beats overriding the
    ; vanilla trap scripts the way NFF does.
    ApplyTrapImmunity(akActor)

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
            DebugMsg("Serana DLC routing FAILED - quest not ready, using manual setup")
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
        ; Still remove our home/work sandbox if active — don't leave stale packages
        StripSandboxesForFollow(akActor)
        ClearWorkSandboxForFollow(akActor)

    ; =========================================================================
    ; SEVERACTIONS MODE — full control
    ; =========================================================================
    Else
        DebugMsg("SeverActions mode: " + akActor.GetDisplayName())

        ; Save original AI values for restoration on dismiss - only when no
        ; snapshot exists yet. A second RegisterFollower on an already-active
        ; companion (hotkey / wheel, neither guards) would otherwise snapshot
        ; the BOOSTED values, and dismiss would restore those forever (audit).
        If !StorageUtil.HasFloatValue(akActor, KEY_ORIG_AGGRESSION)
            StorageUtil.SetFloatValue(akActor, KEY_ORIG_AGGRESSION, akActor.GetAV("Aggression"))
            StorageUtil.SetFloatValue(akActor, KEY_ORIG_CONFIDENCE, akActor.GetAV("Confidence"))
            StorageUtil.SetIntValue(akActor, KEY_ORIG_RELRANK, akActor.GetRelationshipRank(Game.GetPlayer()))
        EndIf

        ; Boost AI so cowardly/passive NPCs will fight as companions.
        ; Only sets actor values — does NOT override combat style form.
        ; Users can pick a specific combat style in PrismaUI if they want.
        ;
        ; SKIPPED for the "coward" style. This boost is exactly what a user
        ; reported fighting: they set an NPC Unaggressive / Cowardly / Helps
        ; Nobody by hand for a companion who travels for company rather than
        ; combat, and recruiting overwrote all three. The style survives a
        ; dismiss (ClearData preserves combatStyle), so a re-recruit must not
        ; silently re-arm someone the player deliberately made a pacifist.
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

        ; Start the follow FIRST — this is the visible outcome the player is
        ; waiting on after the hotkey. The vanilla-dialogue routing + the CFF
        ; repair sweep below are bookkeeping that used to run ahead of this
        ; and, at large rosters, delayed the actual follow by seconds.
        StripSandboxesForFollow(akActor)
        ClearWorkSandboxForFollow(akActor)
        SeverActions_Follow followSysEarly = GetFollowScript()
        If followSysEarly
            followSysEarly.CompanionStartFollowing(akActor)
        EndIf

        ; Vanilla DialogueFollower routing for idle lines (skip when NFF or SFF
        ; installed — NFF hooks OnLoad on those aliases and grabs the actor
        ; regardless; SFF OVERRIDES this quest and would spread 2nd+ followers
        ; into extra aliases SA can't clear on dismiss — see HasSFF).
        If !HasNFF() && !HasSFF()
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
                ; Native tracked list + registered filter — NOT GetAllFollowers
                ; (its cell scan + alias sweep + dedup cost seconds at large
                ; rosters, and this sweep only cares about REGISTERED followers).
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
        ; (Home/work sandbox removal + CompanionStartFollowing moved ABOVE the
        ; vanilla routing — the follow now starts before the bookkeeping.)
    EndIf

    ; Assign an outfit alias slot for zero-flicker outfit persistence
    AssignOutfitSlot(akActor)

    ; Re-apply combat style actor values for returning followers
    ; The dismiss path restores original AI values, so we need to re-set them
    If !isFirstRecruit
        String style = GetCombatStyle(akActor)
        If style != "no combat style" && style != "balanced"
            ApplyCombatStyleValues(akActor, style)
            ; Dismiss strips the healer role (spells, faction, native poll
            ; registration) but re-recruit only restored the AVs - a returning
            ; healer had the style label yet never healed until the player
            ; manually re-set it (audit).
            If style == "healer"
                ApplyHealerRole(akActor)
            EndIf
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

    ; Build companion-opinion strings for the whole roster now that a new member
    ; joined: the newcomer gets their opinions of the existing followers (default-
    ; text bands until assessed), symmetric with how the roster forms opinions of
    ; them. Without this a mid-session recruit sits with an empty companionOpinions
    ; until a reload or until they win an inter-follower assessment slot. Idempotent
    ; and blurb-preserving (the builder prefers Native_GetPairBlurb).
    RebuildAllCompanionOpinions(GetAllFollowers())
EndFunction

Function UnregisterFollower(Actor akActor, Bool sendHome = true, Bool abDeliberateExit = false)
    {Remove an actor from the follower roster.

     Routes the DISMISSAL ITSELF through NFF when NFF owns the actor, then still
     runs our own teardown below so SA's roster/state does not go stale.}
    If !akActor
        Return
    EndIf

    ; NFF owns them -> NFF dismisses them. Ours alone cannot: NFF holds the
    ; actor in one of its aliases, and nothing we do to packages or factions
    ; empties that seat, so the NPC stays NFF's forever while leaving our
    ; roster - in neither list, undismissable.
    ;
    ; DELIBERATE EXITS ONLY - the player dismissing them (DismissCompanion)
    ; or the companion themselves quitting (FollowerLeaves, itself hard-gated
    ; on rapport). Both are real, permanent departures, so NFF's claim must
    ; come down with ours - otherwise a companion who 'left' is still seated
    ; in NFF's alias and still following, which is the very split-ownership
    ; state this routing exists to prevent.
    ;
    ; NOT for the heuristic callers. UnregisterFollower is also called from
    ; sweeps (CheckTrackOnlyFollowerStatus's 30s pass, the pending-dismiss
    ; queue) that exist to catch bookkeeping drift - and every NFF follower now
    ; classifies track-only, so they enter those sweeps for the first time. A
    ; false positive there previously cost a stale SA flag; routed to NFF it
    ; would irreversibly dismiss a real follower, out loud. Bookkeeping sweeps
    ; keep doing bookkeeping.
    Bool nffOwnsDismissal = false
    If abDeliberateExit
        nffOwnsDismissal = NFFDismiss(akActor)
    EndIf

    ; Strip the granted LightFoot perk on the way out. Common path, before the
    ; mode branches, so a SeverActions-mode and a Tracking-mode dismissal both
    ; undo it - the IgnoreFriendlyHits teardown lives in only ONE branch and is
    ; the cautionary example.
    RemoveTrapImmunity(akActor)

    ; Dissolve external claims FIRST (audit H1) - a dismissal must not leave a
    ; live travel slot behind: on arrival/abort the slot's restoreFollower path
    ; would ReinstateFollower (re-teammate) the already-dismissed NPC, and for
    ; a home-less one TeammateMonitor then fully re-onboards them - the
    ; "dismissed follower resurrects" class. Clearing WasFollower covers the
    ; window where CancelTravel resolves asynchronously. The camp-release event
    ; frees a SeversHearth camp claim the same way follow/wait already do.
    SeverActions_Travel travelDis = GetTravelScript()
    If travelDis
        travelDis.CancelTravel(akActor, False)
    EndIf
    StorageUtil.UnsetIntValue(akActor, "SeverTravel_WasFollower")
    Int dismissEvt = ModEvent.Create("SeverActions_FollowerCalledByPlayer")
    If dismissEvt
        ModEvent.PushString(dismissEvt, "SeverActions_FollowerCalledByPlayer")
        ModEvent.PushString(dismissEvt, "dismiss")
        ModEvent.PushFloat(dismissEvt, 0.0)
        ModEvent.PushForm(dismissEvt, akActor)
        ModEvent.Send(dismissEvt)
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
    ; Same capture-before-clear class (PR #120 / audit): ClearData wipes
    ; recruitedViaSerana too - the read further down always saw false and the
    ; Serana DLC dismissal branch never ran.
    Bool viaSeranaAtRecruit = SeverActionsNativeExt.Native_GetRecruitedViaSerana(akActor)

    SeverActionsNative.Native_ClearFollowerData(akActor)

    ; Remove from our faction
    If SeverActions_FollowerFaction
        akActor.RemoveFromFaction(SeverActions_FollowerFaction)
    EndIf
    RemoveBardAudienceExclusion(akActor)

    ; Clear this actor out of the DialogueFollower quest's aliases so no
    ; lingering follow package survives the dismiss. Enumerate ALL aliases
    ; generically (GetNumAliases/GetNthAlias) rather than just GetAlias(0):
    ; Simple Follower Framework OVERRIDES this quest and parks followers 2-8 in
    ; extra aliases, each with the vanilla follow package. The old
    ; alias-0-only clear left an SFF extra-alias follower with an unremovable
    ; PlayerFollowerPackage (save-revert bug). This also RECOVERS actors
    ; already stuck from before the SFF gate, and is a no-op on vanilla (only
    ; alias 0/1 exist and we only touch aliases that hold this actor).
    ; NFF EXCEPTION (the SetCompanion-then-Dismiss report, 2026-08-24): NFF
    ; OVERRIDES the DialogueFollower quest, and RemoveFollower empties this
    ; alias ITSELF as part of its ASYNC teardown (goodbye line first). Clearing
    ; it here, milliseconds after routing the dismissal, ripped the seat out
    ; mid-flight: NFF's flow bailed half-done, its own controller alias stayed
    ; filled (NPC kept following), and its desynced bookkeeping then refused
    ; the vanilla-dialogue dismissal too. NFF's seat is NFF's to empty - the
    ; sweep stays only for vanilla/SFF actors, its original purpose. Checked
    ; live too (not just the routed flag): bookkeeping-sweep callers reach here
    ; without routing, and their clear would desync NFF exactly the same way.
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

    ; --- Remove proper follower status ---

    ; =========================================================================
    ; SERANA — DLC mental model dismissal
    ; =========================================================================
    If viaSeranaAtRecruit
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
        ; RegisterFollower set this engine flag for ALL modes; the tracking
        ; dismiss must undo it or the NPC keeps it forever (it is a plain
        ; actor flag, not a package mutation, so hands-off doesn't apply).
        akActor.IgnoreFriendlyHits(False)
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

        ; Free our Essential alias slot -- SA bookkeeping, not actor state, so
        ; it's safe to clear in tracking mode. Without this the NPC stayed
        ; reference-essential and held one of the 40 slots until next load.
        ; (Base-flag essential is NOT touched here -- the owning framework may
        ; manage it; see the normal-path wasEssentialAtRecruit handling below.)
        ClearActorEssential(akActor)

        DebugMsg("Unregistered track-only follower: " + akActor.GetDisplayName())
        Return

    ; =========================================================================
    ; SEVERACTIONS MODE — full cleanup
    ; =========================================================================
    Else
        DebugMsg("SeverActions dismiss: " + akActor.GetDisplayName())

        ; Try vanilla DialogueFollower dismiss first. Skip under SFF: SFF's
        ; DismissFollower ignores akActor and dismisses its INFERRED target
        ; (falls back to the primary), so it would dismiss the wrong follower
        ; and still never clear akActor's SFF extra alias. SA's own manual
        ; cleanup below (teammate/faction/package) is authoritative anyway.
        If !HasSFF()
            DismissViaVanillaDialogue(akActor)
        EndIf

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
    ; Route B homes migrated everyone OFF legacy slots (slot = -1), so the
    ; legacy-only check was clobbering every Route B home's WFP=2 hold on
    ; dismiss - the exact engine-drops-the-sandbox failure this guard was
    ; added to prevent (audit H5).
    Int homeSlot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)
    If homeSlot < 0 && !GetHomeMarkerB(akActor) && !(SchedSystemActive() && HoldsAnySchedAlias(akActor))
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
    {Registered-follower count from the native store only. The cap check and
     UI counters don't need GetAllFollowers' cell scan + alias sweep + dedup —
     at large rosters that full scan costs SECONDS of frame-budgeted Papyrus
     time, and it ran inside RegisterFollower before the follow ever started
     (the reported recruit lag).}
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
    {0 (or negative) = unlimited — the alias pool stopped being the real
     bound when follower overflow shipped; this is a user preference cap.}
    If MaxFollowers <= 0
        Return true
    EndIf
    Return GetFollowerCount() < MaxFollowers
EndFunction

Actor[] Function GetAllFollowers()
    {Get all currently registered followers - ONE native call.

     Phase 5 perf: this used to scan three sources (cosave walk, player-cell scan,
     alias-slot sweep), Papyrus-looping each with a per-entry IsRegisteredFollower
     VM call and merging them with an O(N^2) ActorInArray + PushActor dedup. In a
     populated city cell the cell scan alone fed 60-300 actors through that filter
     EVERY tick, to rediscover people source 1 already had.

     Sources 2 and 3 were provably redundant: all three filtered through
     IsRegisteredFollower -> Native_GetIsFollower -> FollowerDataStore.isFollower,
     the same store source 1 enumerates, so they could only ever return a SUBSET of
     source 1. (Source 2's comment claimed it caught followers not yet in the cosave.
     That stopped being true at Phase 4B, when IsRegisteredFollower moved off
     StorageUtil onto the cosave - the comment outlived the design. isFollower has
     exactly one writer natively, so the store is the only source of truth.)

     The native applies the identical filters - isFollower, resolvable, alive, not
     the player - and map keys are unique, so the result needs no dedup.}
    Return SeverActionsNativeExt.Native_GetActiveFollowerRoster()
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
    {No-op: every Set/Modify already writes the native store directly, so
     there's nothing left to sync. Kept for any external callers still in the wild.}
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
    {Check if any follower is due for an automatic relationship assessment.
     Fires at most ONE assessment per tick to avoid flooding the LLM queue.
     Each follower has a per-NPC randomized next-eligible time (min/max range).
     Only followers in the same cell as the player are assessed.
     Picks the most overdue follower if multiple are past their threshold.
     Roster passed in by the OnUpdate tick to avoid a redundant scan.}
    If AssessmentInProgress
        ; Watchdog: a dropped LLM callback would latch AssessmentInProgress and
        ; freeze ALL blurb updates until reload (nothing else clears it). Mirror the
        ; IsUpdating / _OnUpdateInFlight watchdogs - if the in-flight assessment has
        ; been outstanding too long in real time, assume the callback was lost and
        ; release the gate so the roster can resume. While this flag is set the
        ; inter-follower path is blocked, so LastAssessClassFireRT is this fire time.
        Float inFlightRT = Utility.GetCurrentRealTime() - LastAssessClassFireRT
        If LastAssessClassFireRT > 0.0 && inFlightRT >= 0.0 && inFlightRT < 120.0
            Return
        EndIf
        AssessmentInProgress = false
        PendingAssessmentActor = None
        If AssessEventNameCur != ""
            UnregisterForModEvent(AssessEventNameCur)
            AssessEventNameCur = ""
        EndIf
        DebugMsg("Relationship assessment watchdog: released a stuck in-flight flag after " + inFlightRT + "s")
    EndIf

    ; Global pacing floor — even with many overdue, space the LLM calls out
    ; instead of firing one on every tick. Scales with party size.
    Float gapA = AssessmentMinRealGapSeconds
    If followers.Length > 10
        gapA = gapA * (1.0 + (followers.Length - 10) / 10.0)
    EndIf
    Float dtA = Utility.GetCurrentRealTime() - LastAssessClassFireRT
    If LastAssessClassFireRT > 0.0 && dtA >= 0.0 && dtA < gapA
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
        ; Candidate if loaded (near the player), not just in the player's EXACT
        ; parent cell - each exterior cell is 4096u, so a companion a few metres
        ; away in the wild, waiting nearby, or parked at a home/work spot used to be
        ; permanently excluded and never got a blurb refresh while same-cell ones did.
        If follower && !follower.IsDead() && follower.Is3DLoaded()
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

Event OnAssessRelNow(String eventName, String strArg, Float numArg, Form sender)
    {Manual "How They See You" refresh from the Companions page button. Sender is
     the follower. Fires an assessment immediately, bypassing the autonomous
     game-time cooldown (the picker's job, not FireRelationshipAssessment's) — a
     click is an explicit user request. The per-dispatch AssessEventNameCur
     channel + the AssessmentInProgress guard keep it consistent with any in-flight
     assessment, and the dispatch still passes through the global LLM kill-switch.}
    Actor akActor = sender as Actor
    If !akActor
        Return
    EndIf
    DebugMsg("Manual relationship assessment requested for " + akActor.GetDisplayName())
    FireRelationshipAssessment(akActor)
EndEvent

Function FireRelationshipAssessment(Actor akActor)
    {Send the relationship assessment prompt to the LLM for a specific follower.
     Passes the follower's FormID in contextJson so the prompt template can
     resolve it to a UUID via formid_to_uuid() and access all NPC data.

     When PublicAPI is available, enriches the context with:
     - socialGraph: who this NPC interacts with besides the player
     - relevantMemories: semantic search for relationship-relevant memories}
    AssessmentInProgress = true
    PendingAssessmentActor = akActor
    LastAssessClassFireRT = Utility.GetCurrentRealTime()
    Float nowTime = GetGameTimeInSeconds()
    StorageUtil.SetFloatValue(akActor, KEY_LAST_ASSESS_GT, nowTime)
    ; Provisional SHORT retry window only. The full randomized 4-10 game-hr cooldown
    ; is committed in OnRelationshipAssessment after a successful reply, so a dropped
    ; callback or a refused dispatch re-tries this follower in ~0.5 game-hr instead of
    ; shelving them for hours while the rest of the roster refreshes (the reported bug
    ; where some followers' blurbs stayed stale after one transient LLM hiccup).
    StorageUtil.SetFloatValue(akActor, KEY_NEXT_ASSESS_GT, nowTime + (0.5 * SECONDS_PER_GAME_HOUR))

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
        ; Clear the in-flight state set above — without this the flag latches for
        ; the whole session (and gates off off-screen life events) on any install
        ; missing this FOMOD prompt module.
        AssessmentInProgress = false
        PendingAssessmentActor = None
        Return
    EndIf

    ; dev132 — route through the C++ bridge relay instead of SkyrimNetApi:
    ; SkyrimNet's Papyrus callback marshalling truncates responses ~1024
    ; chars (the v3.11 off-screen-life lesson); the ModEvent path carries
    ; the full response. Also puts this call under the Background AI master
    ; toggle. Registration on the trigger path per the ModEvent rule.
    ; Unique per-dispatch reply channel (mis-attribution guard): if the watchdog
    ; later abandons this request, a very-late callback arrives on THIS stale channel
    ; name and is rejected in OnLLMRelAssessReady instead of being applied to whatever
    ; follower is pending by then. Retire any prior lingering channel (e.g. a refused
    ; dispatch that never got a callback) before opening a new one.
    If AssessEventNameCur != ""
        UnregisterForModEvent(AssessEventNameCur)
    EndIf
    AssessSeq += 1
    AssessEventNameCur = "SeverActions_LLM_RelAssess_" + AssessSeq
    RegisterForModEvent(AssessEventNameCur, "OnLLMRelAssessReady")
    Bool sent = SeverActionsNativeExt.Native_LLM_Dispatch("sever_relationship_assess", contextJson, \
        AssessEventNameCur)

    If !sent
        AssessmentInProgress = false
        DebugMsg("Relationship assessment LLM dispatch refused for " + akActor.GetDisplayName() \
            + " (bridge down, master toggle off, or prompt missing)")
    Else
        DebugMsg("Relationship assessment queued for " + akActor.GetDisplayName() + " (enriched=" + SeverActionsNative.IsPublicAPIReady() + ")")
    EndIf
EndFunction

Event OnLLMRelAssessReady(string eventName, string strArg, float numArg, Form sender)
    {Bridge relay hand-off (dev132) — same payload the old SkyrimNetApi
     callback received, minus its ~1024-char truncation.}
    ; Mis-attribution guard: reject any reply not on the CURRENT in-flight channel.
    ; After a watchdog release + re-fire, a stalled prior request's very-late callback
    ; arrives on an old unique channel and must not touch the new follower.
    UnregisterForModEvent(eventName)
    If eventName != AssessEventNameCur
        Return
    EndIf
    AssessEventNameCur = ""
    OnRelationshipAssessment(strArg, numArg as Int)
EndEvent

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

    ; Commit the full randomized cooldown now that the assessment returned
    ; successfully (success == 1 checked above, actor still a follower). Fire-
    ; RelationshipAssessment set only a short provisional retry, so this is where a
    ; genuine success shelves the follower for the full 4-10 game-hr window.
    Float assessCooldownSec = Utility.RandomFloat(AssessmentCooldownMinHours, AssessmentCooldownMaxHours) * SECONDS_PER_GAME_HOUR
    StorageUtil.SetFloatValue(akActor, KEY_NEXT_ASSESS_GT, GetGameTimeInSeconds() + assessCooldownSec)

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
        ; Push the new blurb to the Companions page if it's open (covers both the
        ; autonomous refresh and the manual "How They See You" button).
        SeverActionsNative.PrismaUI_RefreshPage("companions")
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
    ; The blurb (native FollowerData.playerBlurb) is the narrative-facing output.
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

    ; dev132 — bridge relay (see the relationship-assess dispatch above).
    ; The reputation response is FREE PROSE, exactly the shape the old
    ; ~1024-char callback truncation bit hardest.
    RegisterForModEvent("SeverActions_LLM_RepAssess", "OnLLMRepAssessReady")
    Bool sent = SeverActionsNativeExt.Native_LLM_Dispatch("sever_reputation_assess", contextJson, \
        "SeverActions_LLM_RepAssess")

    If !sent
        ReputationAssessInProgress = false
        Debug.Trace("[SeverActions] Reputation assessment dispatch refused for " + npcActor.GetDisplayName() \
            + " (bridge down, master toggle off, or prompt missing)")
        ProcessNextReputationAssessment()  ; Try next in queue
    Else
        Debug.Trace("[SeverActions] Reputation assessment queued for " + npcActor.GetDisplayName())
    EndIf
EndFunction

Event OnLLMRepAssessReady(string eventName, string strArg, float numArg, Form sender)
    {Bridge relay hand-off (dev132).}
    OnReputationAssessResult(strArg, numArg as Int)
EndEvent

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

    ; Shared pacing floor with the player-relationship assessments (same
    ; class of background LLM call — one stamp paces them both).
    Float gapI = AssessmentMinRealGapSeconds
    If followers.Length > 10
        gapI = gapI * (1.0 + (followers.Length - 10) / 10.0)
    EndIf
    Float dtI = Utility.GetCurrentRealTime() - LastAssessClassFireRT
    If LastAssessClassFireRT > 0.0 && dtI >= 0.0 && dtI < gapI
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
    LastAssessClassFireRT = Utility.GetCurrentRealTime()
    Float nowTime = GetGameTimeInSeconds()
    StorageUtil.SetFloatValue(akActor, KEY_LAST_INTER_ASSESS_GT, nowTime)
    ; Provisional SHORT retry window only. The full randomized cooldown is committed
    ; in OnInterFollowerAssessment after a successful reply, so a dropped callback or
    ; refused dispatch re-tries this follower in ~0.5 game-hr instead of shelving them
    ; for the full 6-14 game-hr window (mirrors FireRelationshipAssessment; a new
    ; follower's first inter-assess used to be shelved for hours on any transient hiccup).
    StorageUtil.SetFloatValue(akActor, KEY_NEXT_INTER_ASSESS_GT, nowTime + (0.5 * SECONDS_PER_GAME_HOUR))

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
        ; Clear the in-flight state set above — without this the flag latches for
        ; the whole session (and gates off off-screen life events) on any install
        ; missing this FOMOD prompt module.
        InterFollowerAssessmentInProgress = false
        PendingInterAssessActor = None
        Return
    EndIf

    ; dev132 — bridge relay (see the relationship-assess dispatch above).
    ; The inter-follower response is a variable-length PAIR ARRAY — the
    ; larger the party, the closer the old path sat to its truncation cliff.
    RegisterForModEvent("SeverActions_LLM_InterAssess", "OnLLMInterAssessReady")
    Bool sent = SeverActionsNativeExt.Native_LLM_Dispatch("sever_relationship_interfollower", contextJson, \
        "SeverActions_LLM_InterAssess")

    If !sent
        InterFollowerAssessmentInProgress = false
        DebugMsg("Inter-follower assessment dispatch refused for " + akActor.GetDisplayName() \
            + " (bridge down, master toggle off, or prompt missing)")
    Else
        DebugMsg("Inter-follower assessment queued for " + akActor.GetDisplayName())
    EndIf
EndFunction

Event OnLLMInterAssessReady(string eventName, string strArg, float numArg, Form sender)
    {Bridge relay hand-off (dev132).}
    OnInterFollowerAssessment(strArg, numArg as Int)
EndEvent

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

    ; Commit the full randomized inter-follower cooldown now that the assessment
    ; returned successfully (success == 1 checked above, assessor still a follower).
    ; FireInterFollowerAssessment set only a short provisional retry, so this is where
    ; a genuine success shelves the assessor for the full 6-14 game-hr window.
    Float interCooldownSec = Utility.RandomFloat(InterFollowerCooldownMinHours, InterFollowerCooldownMaxHours) * SECONDS_PER_GAME_HOUR
    StorageUtil.SetFloatValue(akActor, KEY_NEXT_INTER_ASSESS_GT, GetGameTimeInSeconds() + interCooldownSec)

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
        ; Rebuild the pre-formatted opinions strings for the WHOLE roster (not just
        ; the assessor) so any follower whose string is stale/empty — e.g. a mid-
        ; session recruit that never won an assessment slot — self-heals here.
        ; Cheap (N is small, assessments are rate-limited) and blurb-preserving.
        RebuildAllCompanionOpinions(followers)

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

Function RebuildCompanionOpinionsStringCached(Actor akActor, Actor[] followers)
    {Build a follower's companion-opinions string from a pre-built followers array,
     avoiding a redundant GetAllFollowers() cell scan during bulk rebuilds.}
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

            ; Only include if non-default values exist. The native twin also
            ; skips unnamed actors BEFORE emitting - match it, or a
            ; stripped-name follower produces a blank '****:' row on this
            ; side only (byte-identical invariant, audit).
            If (aff != 0.0 || resp != 0.0) && target.GetDisplayName() != ""
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
                        affDesc = "You consider " + targetName + " a true friend - someone you'd fight beside without hesitation and trust to watch your back."
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
                        respDesc = " You hold their abilities in the highest regard - they're one of the most capable people you've met."
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

    Debug.Trace("[SeverActions][Banter] Checking " + eligibleCount + " followers...")
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
    contextJson += "]"

    ; Inject the persistent banter-topic history so the prompt's anti-repetition
    ; + rotation sections actually have data. (The get_recent_events topic-mining
    ; never surfaced our gamemaster_dialogue topics — wrong event type + "target"
    ; vs "listener" — so those sections were always empty for a fixed party,
    ; which is why followers kept circling the same talking points.)
    contextJson += ",\"recentBanter\":["
    Int hcount = StorageUtil.StringListCount(None, KEY_BANTER_HISTORY)
    Int h = 0
    While h < hcount
        If h > 0
            contextJson += ","
        EndIf
        contextJson += StorageUtil.StringListGet(None, KEY_BANTER_HISTORY, h)
        h += 1
    EndWhile
    contextJson += "]}"

    ; Skip if prompt module not installed.
    If !SeverActionsNative.Native_IsPromptAvailable("sever_follower_banter")
        BanterInProgress = false
        DebugMsg("Follower banter skipped: sever_follower_banter.prompt not installed")
        Return
    EndIf

    ; dev132 — bridge relay (see the relationship-assess dispatch above).
    ; This was the LAST direct SkyrimNetApi.SendCustomPromptToLLM call:
    ; every SeverActions background LLM request now flows through the C++
    ; bridge and its Background AI master toggle.
    RegisterForModEvent("SeverActions_LLM_Banter", "OnLLMBanterReady")
    Bool sent = SeverActionsNativeExt.Native_LLM_Dispatch("sever_follower_banter", contextJson, \
        "SeverActions_LLM_Banter")

    If !sent
        BanterInProgress = false
        Debug.Trace("[SeverActions][Banter] dispatch refused (bridge down, master toggle off, or prompt missing)")
    EndIf
EndFunction

Event OnLLMBanterReady(string eventName, string strArg, float numArg, Form sender)
    {Bridge relay hand-off (dev132).}
    OnFollowerBanter(strArg, numArg as Int)
EndEvent

Function OnFollowerBanter(String response, Int success)
    {Callback from SendCustomPromptToLLM for banter director.
     If the LLM selected a pair, fires a gamemaster_dialogue event to trigger
     SkyrimNet's dialogue pipeline between the two companions.
     Always reschedules the banter loop at the end.}
    BanterInProgress = false

    If success != 1
        Debug.Trace("[SeverActions][Banter] LLM call failed")
        Return
    EndIf

    ; Check if LLM chose no banter (the ~60% case)
    If StringUtil.Find(response, "\"banter\":null") >= 0 || StringUtil.Find(response, "\"banter\": null") >= 0
        Debug.Trace("[SeverActions][Banter] LLM chose silence this cycle")
        Return
    EndIf

    ; Extract speaker, target, topic from nested banter object
    String speakerName = ExtractJsonString(response, "speaker")
    String targetName = ExtractJsonString(response, "target")
    String banterTopic = ExtractJsonString(response, "topic")

    If speakerName == "" || targetName == ""
        Debug.Trace("[SeverActions][Banter] Bad LLM response - missing names")
        Return
    EndIf

    ; Resolve names to Actors
    Actor[] followers = GetAllFollowers()
    Actor speakerActor = ResolveFollowerByName(speakerName, followers)
    Actor targetActor = ResolveFollowerByName(targetName, followers)

    If !speakerActor || !targetActor
        Debug.Trace("[SeverActions][Banter] Can't find " + speakerName + " or " + targetName)
        Return
    EndIf

    ; Fire as gamemaster_dialogue — SkyrimNet routes this to DialogueManager which
    ; generates a response from the speaker to the target.
    ;
    ; FIELD-VERIFIED CONTRACT (2026-08-08, EventSchemaRegistry.cpp): SkyrimNet's
    ; gamemaster_dialogue format templates render ONLY speaker + topic. The
    ; "dialogue" field is NEVER shown to the generating LLM (a previous comment
    ; here claimed otherwise — it was wrong). Everything that should steer the
    ; line MUST ride in topic; the native builder appends the optional
    ; one-sentence direction there for exactly that reason.
    ;
    ; The event JSON is built NATIVELY: Papyrus String concat corrupts
    ; non-ASCII names (issue #9, the 2.9.9 Cyrillic lesson that already moved
    ; ambient banter's build to C++ — this path kept the hazard until now).
    ; isContinuation is deliberately omitted — it makes the event log read
    ; "...(continuing conversation)" on fresh banters and leaks into
    ; get_recent_events context.
    String banterDirection = ExtractJsonString(response, "direction")
    String eventJson = SeverActionsNativeExt2.Native_BuildGMDialogueEventJson(speakerName, targetName, banterTopic, banterDirection)

    SkyrimNetApi.RegisterEvent("gamemaster_dialogue", eventJson, speakerActor, targetActor)

    Debug.Trace("[SeverActions][Banter] " + speakerName + " -> " + targetName + ": " + banterTopic)

    ; Persist to the rolling banter history that drives the NEXT cycle's
    ; anti-repetition + rotation (reliable, unlike mining get_recent_events).
    ; History records the TOPIC only (not the appended direction) — the
    ; anti-repetition ledger compares themes, and the direction is per-scene.
    String topicForHistory = banterTopic
    If topicForHistory == ""
        topicForHistory = "casual conversation"
    EndIf
    RecordBanterTopic(speakerName, targetName, topicForHistory)
EndFunction

Function RecordBanterTopic(String speakerName, String targetName, String topicText)
    {Append a banter beat to the persistent rolling history (StorageUtil
     StringList on None, capped at BanterHistoryMax) as a pre-escaped JSON
     object. FireFollowerBanter joins these into the prompt's "recentBanter"
     field, which drives the "Topics Already Covered" + "Rotation Pressure"
     sections. Replaces the old reliance on get_recent_events topic-mining,
     which never surfaced our gamemaster_dialogue topics (wrong event type +
     "target" vs "listener"), leaving the director with no memory of what it
     just used.}
    String obj = "{\"speaker\":\"" + SeverActionsNative.EscapeJsonString(speakerName) + "\","
    obj += "\"target\":\"" + SeverActionsNative.EscapeJsonString(targetName) + "\","
    obj += "\"topic\":\"" + SeverActionsNative.EscapeJsonString(topicText) + "\"}"
    StorageUtil.StringListAdd(None, KEY_BANTER_HISTORY, obj, true)
    While StorageUtil.StringListCount(None, KEY_BANTER_HISTORY) > BanterHistoryMax
        StorageUtil.StringListRemoveAt(None, KEY_BANTER_HISTORY, 0)
    EndWhile
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

    ; Cross-system separation: if the ambient ACTION system staged a scene
    ; recently, hold off — two staged scenes seconds apart reads as a play.
    Float lastScene = StorageUtil.GetFloatValue(None, KEY_LAST_AMBIENT_SCENE_GT, 0.0)
    If lastScene > 0.0 && now < lastScene + (AmbientSceneSeparationHours * SECONDS_PER_GAME_HOUR)
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
        Debug.Trace("[AmbientBanter] ready slot was empty - race or stale call?")
        Return
    EndIf

    ; Hand the pre-built JSON straight to RegisterEvent. NO Papyrus concat
    ; with the NPC names anywhere along this path.
    SkyrimNetApi.RegisterEvent("gamemaster_dialogue", eventJson, speakerActor, targetActor)

    ; A scene was actually staged — push the ambient ACTION system back by the
    ; shared separation window (silence cycles above never reach this line).
    StorageUtil.SetFloatValue(None, KEY_LAST_AMBIENT_SCENE_GT, GetGameTimeInSeconds())

    Debug.Trace("[AmbientBanter] dispatched (speaker=" + speakerActor.GetDisplayName() + ", target=" + targetActor.GetDisplayName() + ")")
EndEvent

; ═══════════════════════════════════════════════════════════════════════
;  Ambient Actions — the Action Orchestrator's "promote" half.
;  See ai_docs/AMBIENT_ACTIONS.md. The action whitelist is enforced in
;  DispatchAmbientAction.
; ═══════════════════════════════════════════════════════════════════════

Function CheckAmbientAction()
    {Game-time ambient-action check. Called from OnUpdate every 30s. Asks the
     native AmbientActionScanner to pick a nearby non-follower NPC + an action
     (MVP: travel somewhere) via the sever_ambient_action_director LLM, which
     usually declines. Solo intents execute immediately; social intents run the
     announce-then-adjudicate gate — both handled in OnAmbientActionReady.}

    Float now = GetGameTimeInSeconds()
    Float nextEligible = StorageUtil.GetFloatValue(None, KEY_NEXT_AMBIENT_ACTION_GT, 0.0)
    If nextEligible > 0.0 && now < nextEligible
        Return
    EndIf

    ; Cross-system separation: if ambient BANTER staged a scene recently,
    ; hold off (mirror of the check in CheckAmbientBanter).
    Float lastScene = StorageUtil.GetFloatValue(None, KEY_LAST_AMBIENT_SCENE_GT, 0.0)
    If lastScene > 0.0 && now < lastScene + (AmbientSceneSeparationHours * SECONDS_PER_GAME_HOUR)
        Return
    EndIf

    Actor player = Game.GetPlayer()
    If player.IsInCombat()
        Return
    EndIf

    ; Prompt module gate — FOMOD may not have installed the director prompt.
    If !SeverActionsNative.Native_IsPromptAvailable("sever_ambient_action_director")
        ; Push the cooldown out so we don't re-check every 30s.
        StorageUtil.SetFloatValue(None, KEY_NEXT_AMBIENT_ACTION_GT, now + 3600.0)
        Return
    EndIf

    AmbientActionInProgress = true

    ; Set the cooldown up front so we don't re-fire while the LLM is in flight.
    Float nextCooldown = Utility.RandomFloat(AmbientActionCooldownMinHours, AmbientActionCooldownMaxHours) * SECONDS_PER_GAME_HOUR
    StorageUtil.SetFloatValue(None, KEY_NEXT_AMBIENT_ACTION_GT, now + nextCooldown)

    ; 0.0/0.0/0 = use the native scanner's defaults (2000 hearing, 768 pair, 6 max).
    Int dispatched = SeverActionsNativeExt2.Native_AmbientAction_FireToLLM(0.0, 0.0, 0)
    If dispatched <= 0
        AmbientActionInProgress = false
        If dispatched == 0
            Debug.Trace("[AmbientAction] no candidates (hostile cell or empty)")
        Else
            Debug.Trace("[AmbientAction] native dispatch failed (SkyrimNet v8 PublicAPI unavailable?)")
        EndIf
    EndIf
    ; Stays true while the request is in flight — OnAmbientActionReady clears it.
EndFunction

Event OnAmbientActionReady(string eventName, string strArg, float numArg, Form sender)
    {The native director produced an intent (or declined). numArg = IntentKind:
     0 = none/silence, 1 = solo (execute now), 2 = social (announce + gate).}
    Int kind = numArg as Int

    If kind == 0
        AmbientActionInProgress = false
        Return
    EndIf

    ; An intent was actually produced (solo or social) — push ambient BANTER
    ; back by the shared separation window. Stamped here rather than at commit
    ; so a social gate in progress also holds banter off the same pair.
    StorageUtil.SetFloatValue(None, KEY_LAST_AMBIENT_SCENE_GT, GetGameTimeInSeconds())

    Actor initiator     = SeverActionsNativeExt2.Native_AmbientAction_GetInitiator()
    String actionName   = SeverActionsNativeExt2.Native_AmbientAction_GetActionName()
    String destination  = SeverActionsNativeExt2.Native_AmbientAction_GetDestination()
    Actor targetActor   = SeverActionsNativeExt2.Native_AmbientAction_GetTarget()
    String itemName     = SeverActionsNativeExt2.Native_AmbientAction_GetItemName()
    Int qty             = SeverActionsNativeExt2.Native_AmbientAction_GetQuantity()
    Int goldAmt         = SeverActionsNativeExt2.Native_AmbientAction_GetGold()
    ; MUST be read before ClearReady — the accessor reads the pending slot,
    ; which ClearReady wipes. Solo brawls carry a challenge line here too.
    String soloAnnounceJson = SeverActionsNativeExt2.Native_AmbientAction_GetAnnounceEventJson()
    Bool waitForPlayer  = SeverActionsNativeExt2.Native_AmbientAction_GetWaitForPlayer()

    If !initiator || actionName == ""
        Debug.Trace("[AmbientAction] ready slot unusable - clearing")
        SeverActionsNativeExt2.Native_AmbientAction_ClearReady()
        AmbientActionInProgress = false
        Return
    EndIf

    If kind == 1
        ; SOLO — execute immediately (travel-unannounced, brawl; the native side
        ; already validated per-action params).
        SeverActionsNativeExt2.Native_AmbientAction_ClearReady()
        DispatchAmbientAction(initiator, actionName, destination, targetActor, itemName, qty, goldAmt, waitForPlayer)
        ; Brawl: the challenge is now REGISTERED (pending state set) — speak the
        ; line so the target's LLM gets a reply turn and genuinely accepts or
        ; declines. Without this the first field test timed out into a silent
        ; auto-decline (Uthgerd/Sinmir, 2026-08-08).
        If actionName == "ChallengeBrawl" && targetActor && soloAnnounceJson != ""
            SkyrimNetApi.RegisterEvent("gamemaster_dialogue", soloAnnounceJson, initiator, targetActor)
        EndIf
        AmbientActionInProgress = false
        Debug.Trace("[AmbientAction] SOLO dispatched: " + initiator.GetDisplayName() + " " + actionName)
        Return
    EndIf

    ; ── kind == 2 : SOCIAL ──────────────────────────────────────────────
    ; Announce the intent, let SkyrimNet's dialogue rounds finish, then let the
    ; native gate adjudicate. The gate owns the busy lock + settle detection +
    ; the refusal memory; we only commit the travel on a "go" verdict.
    Actor addressee     = SeverActionsNativeExt2.Native_AmbientAction_GetAddressee()
    String announceJson = SeverActionsNativeExt2.Native_AmbientAction_GetAnnounceEventJson()
    SeverActionsNativeExt2.Native_AmbientAction_ClearReady()

    If !addressee || announceJson == ""
        Debug.Trace("[AmbientAction] social intent missing addressee/announce - aborting gate")
        SeverActionsNativeExt2.Native_AmbientAction_AbortGate(initiator)
        AmbientActionInProgress = false
        Return
    EndIf

    ; Make the NPC speak their plan (routes through SkyrimNet's DialogueManager).
    SkyrimNetApi.RegisterEvent("gamemaster_dialogue", announceJson, initiator, addressee)
    Debug.Trace("[AmbientAction] SOCIAL announced: " + initiator.GetDisplayName() + " -> " + addressee.GetDisplayName() + " (dest " + destination + ")")

    ; Hand off to the NON-BLOCKING gate poller (OnUpdate at 2s). No Utility.Wait
    ; loop — this handler returns immediately so it never ties up the VM stack or
    ; serializes sibling ModEvents. AmbientActionInProgress stays true until the
    ; gate resolves in PollAmbientGate/_FinishAmbientGate.
    _AmbientGateInitiator = initiator
    _AmbientGateAction    = actionName
    _AmbientGateDest      = destination
    _AmbientGateTarget    = targetActor
    _AmbientGateItem      = itemName
    _AmbientGateQty       = qty
    _AmbientGateGold      = goldAmt
    _AmbientGateWait      = waitForPlayer
    _AmbientGatePollCount = 0
    AmbientGatePolling    = true
    ChronoArm(2.0)
EndEvent

Function PollAmbientGate()
    {Non-blocking social-gate poll, driven from OnUpdate at ~2s cadence while
     AmbientGatePolling. The native gate owns settle detection, adjudication, the
     busy lock, and the refusal memory; we only commit the travel on a GO verdict.
     Poll codes mirror AmbientActionScanner::PollResult: 0 pending, 1 go,
     2 blocked, 3 done (deferred/aborted/no gate).}
    Actor initiator = _AmbientGateInitiator
    If !initiator
        _FinishAmbientGate()
        Return
    EndIf

    _AmbientGatePollCount += 1
    Int verdict = SeverActionsNativeExt2.Native_AmbientAction_PollGate(initiator)

    If verdict == 1
        DispatchAmbientAction(initiator, _AmbientGateAction, _AmbientGateDest, _AmbientGateTarget, \
            _AmbientGateItem, _AmbientGateQty, _AmbientGateGold, _AmbientGateWait)
        Debug.Trace("[AmbientAction] gate GO: " + initiator.GetDisplayName() + " " + _AmbientGateAction)
        _FinishAmbientGate()
    ElseIf verdict == 2
        Debug.Trace("[AmbientAction] gate BLOCKED (addressee refused): " + initiator.GetDisplayName())
        _FinishAmbientGate()
    ElseIf verdict == 3
        Debug.Trace("[AmbientAction] gate deferred/aborted: " + initiator.GetDisplayName())
        _FinishAmbientGate()
    Else
        ; Still pending — defensive ceiling in case native never resolves.
        ; Native hard cap is 90s (LLM+TTS round-trips are slow); 75 polls at
        ; ~2s ≈ 150s covers it plus the adjudicator's own LLM call.
        If _AmbientGatePollCount >= 75
            SeverActionsNativeExt2.Native_AmbientAction_AbortGate(initiator)
            Debug.Trace("[AmbientAction] gate poll ceiling hit - aborted")
            _FinishAmbientGate()
        EndIf
        ; else OnUpdate re-registers 2.0 and calls PollAmbientGate again
    EndIf
EndFunction

Function _FinishAmbientGate()
    {Single exit point for the social gate. ClearReady resets the native gate slot
     once Resolved; native has already cleared the busy lock on every verdict path.}
    SeverActionsNativeExt2.Native_AmbientAction_ClearReady()
    AmbientGatePolling      = false
    _AmbientGateInitiator   = None
    _AmbientGateAction      = ""
    _AmbientGateDest        = ""
    _AmbientGateTarget      = None
    _AmbientGateItem        = ""
    _AmbientGateQty         = 1
    _AmbientGateGold        = 0
    _AmbientGateWait        = false
    _AmbientGatePollCount   = 0
    AmbientActionInProgress = false
EndFunction

Function DispatchAmbientAction(Actor akActor, String actionName, String destination, Actor akTarget, \
        String itemName, Int aiQty, Int aiGold, Bool waitForPlayer)
    {Ambient whitelist dispatch table — the ONE place the ambient action set is
     enforced in Papyrus. Eight actions; the native parser already validated
     per-action params and clamped quantities (1..10) and gold (1..500).
     Tier-0 guards here are the last line: every case re-checks its own
     preconditions cheaply before touching an actor.}
    Quest saQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest

    If actionName == "TravelToPlace"
        If TravelScript
            TravelScript.TravelToPlace(akActor, destination, 24.0, true, 0, waitForPlayer)
        Else
            Debug.Trace("[AmbientAction] TravelScript missing - cannot dispatch travel")
        EndIf

    ElseIf actionName == "ChallengeBrawl"
        SeverActions_Brawl brawlScript = saQuest as SeverActions_Brawl
        ; The brawl system runs its own challenge/accept/decline social flow —
        ; the target's LLM decides, which is a better adjudicator than ours.
        If brawlScript && akTarget && akTarget != akActor && !akTarget.IsDead()
            brawlScript.ChallengeBrawl_Execute(akActor, akTarget)
        EndIf

    ElseIf actionName == "GiveItem"
        SeverActions_Loot lootScript = saQuest as SeverActions_Loot
        If lootScript && akTarget && itemName != ""
            lootScript.GiveItem_Execute(akActor, akTarget, itemName, aiQty)
        EndIf

    ElseIf actionName == "GiveGold"
        SeverActions_Currency curScript = saQuest as SeverActions_Currency
        If curScript && akTarget && aiGold > 0
            curScript.GiveGold_Execute(akActor, akTarget, aiGold)
        EndIf

    ElseIf actionName == "BuyItem"
        SeverActions_Currency buyScript = saQuest as SeverActions_Currency
        ; Initiator is the BUYER, target the seller. NPC-to-NPC commits directly
        ; (no player popup) per _BeginItemTransaction's own branch.
        If buyScript && akTarget && itemName != "" && aiGold > 0
            buyScript.BuyItem_Execute(akActor, akTarget, itemName, aiQty, aiGold)
        EndIf

    ElseIf actionName == "SellItem"
        SeverActions_Currency sellScript = saQuest as SeverActions_Currency
        ; Initiator is the SELLER, target the buyer. Mirrors BuyItem — an
        ; NPC-to-NPC deal commits directly (no player popup).
        If sellScript && akTarget && akTarget != akActor && itemName != "" && aiGold > 0
            sellScript.SellItem_Execute(akActor, akTarget, itemName, aiQty, aiGold)
        EndIf

    ElseIf actionName == "TakeItem"
        SeverActions_Loot takeScript = saQuest as SeverActions_Loot
        ; Initiator receives the item; target hands it over.
        If takeScript && akTarget && akTarget != akActor && itemName != ""
            takeScript.TakeItem_Execute(akActor, akTarget, itemName, aiQty)
        EndIf

    ElseIf actionName == "UseItem"
        SeverActions_Loot useScript = saQuest as SeverActions_Loot
        ; Solo: initiator consumes an item from their own pack (no counterparty).
        If useScript && itemName != ""
            useScript.UseItem_Execute(akActor, itemName)
        EndIf

    ElseIf actionName == "CookMeal" || actionName == "BrewPotion" || actionName == "CraftItem"
        SeverActions_Crafting craftScript = saQuest as SeverActions_Crafting
        ; Initiator is the CRAFTER, target the recipient. The crafting system
        ; finds the workstation, walks them to it, animates, and delivers —
        ; and no-ops with its own event if no station is nearby.
        If craftScript && akTarget && itemName != ""
            If actionName == "CookMeal"
                craftScript.CookMeal_Internal(akActor, itemName, akTarget, aiQty)
            ElseIf actionName == "BrewPotion"
                craftScript.BrewPotion_Internal(akActor, itemName, akTarget, aiQty)
            Else
                craftScript.CraftItem_Internal(akActor, itemName, akTarget, aiQty)
            EndIf
        EndIf
    EndIf
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

    ; Global pacing floor — home STORAGE is uncapped (only the sched-alias
    ; enforcement caps at 300 concurrent), so a big
    ; roster whose story windows have all expired must NOT turn this into
    ; a fire-every-tick background generator. Scales with roster size.
    Float gapO = OffScreenLifeMinRealGapSeconds
    If allTracked.Length > 50
        gapO = gapO * (1.0 + (allTracked.Length - 50) / 50.0)
    EndIf
    Float dtO = Utility.GetCurrentRealTime() - LastOffScreenLifeFireRT
    If LastOffScreenLifeFireRT > 0.0 && dtO >= 0.0 && dtO < gapO
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
    LastOffScreenLifeFireRT = OffScreenLifeStartedRT
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
            ElseIf conseqAction == "purchase"
                ; Bought something with their own coin (user request): gold
                ; actually leaves the purse AND the item lands in their pack.
                ; Needs both the amount (field 7) and the item fields (10-12),
                ; which is why it can't ride the 6-arg dispatch below.
                String itemNameP = PipeField(parsed, 10)
                String itemCatP  = PipeField(parsed, 11)
                Int itemCountP   = PipeField(parsed, 12) as Int
                If itemCountP <= 0
                    itemCountP = 1
                EndIf
                ProcessOffScreenPurchase(akActor, conseqAmount, conseqReason, itemNameP, itemCatP, itemCountP)
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

    DebugMsg("Off-screen life: " + actorName + " -> " + lifeSummary)
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

    ; Yield-on-collision (v18): this NPC's Enterprises venture may have ALREADY
    ; arrested them this settlement week (the fence heat -> bounty -> arrest
    ; roll, or an external jailing synced onto the venture). Two independent
    ; pipelines each assigning a bounty for one week's trouble is the
    ; double-bounty bug; the venture owns the beat, so stand down.
    If SeverActionsNativeExt2.Venture_ClaimsJailThisWeek(akActor)
        DebugMsg("Off-screen arrest SKIPPED for " + actorName + " - their venture already put them in custody this week")
        Return
    EndIf

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
                        ; Permanent: a jail sentence can easily outlast the
                        ; LREF 30-day prune (prisoners were reverting to
                        ; default AI and walking out).
                        SeverActionsNativeExt.LinkedRef_SetPermanent(akActor, jailMarker, ArrestScript.SeverActions_SandboxAnchorKW)
                        ActorUtil.AddPackageOverride(akActor, ArrestScript.SeverActions_PrisonerSandBox, 110, 1)
                        akActor.EvaluatePackage()
                    EndIf

                    ; Register persistent event for SkyrimNet
                    SkyrimNetApi.RegisterPersistentEvent(actorName + " has been jailed in " + home + ".", akActor, None)

                    DebugMsg("Off-screen arrest: " + actorName + " placed in jail at " + home)
                Else
                    DebugMsg("Off-screen arrest: no jail marker found for " + home + " - arrest recorded but NPC not moved")
                EndIf
            Else
                DebugMsg("Off-screen arrest: no crime faction found for '" + home + "' - arrest recorded but NPC not moved")
            EndIf
        EndIf
    Else
        DebugMsg("Off-screen arrest: ArrestScript not available - arrest recorded but NPC not moved")
    EndIf

    If ShowNotifications
        Debug.Notification(actorName + " was arrested in " + home + "! (" + bounty + " bounty)")
    EndIf
EndFunction

Function ProcessOffScreenBounty(Actor akActor, String home, String crime, Int bounty)
    {Apply bounty without arrest — wanted but not yet caught.}
    String actorName = akActor.GetDisplayName()

    ; Yield-on-collision (v18): same rule as ProcessOffScreenArrest. Being
    ; wanted for a fresh crime while their venture already has them sitting in
    ; a cell for the week reads as nonsense, and stacks a second bounty.
    If SeverActionsNativeExt2.Venture_ClaimsJailThisWeek(akActor)
        DebugMsg("Off-screen bounty SKIPPED for " + actorName + " - their venture already put them in custody this week")
        Return
    EndIf

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

Function ProcessOffScreenPurchase(Actor akActor, Int cost, String reason, String itemName, String category, Int count)
    {A purchase consequence (user request): the NPC BOUGHT something, so the
     gold genuinely leaves their inventory and the item genuinely lands in it.
     Cost is clamped to the usual per-event cap and to what they actually
     carry (the prompt knows the purse, but an LLM number is never trusted).
     If the purse can't cover even a clamped cost, the whole purchase is
     skipped — no free items. The item side reuses the same fuzzy resolver
     as item_acquired; an unresolvable item name degrades to a pure spend
     (the coin went somewhere — the summary already told the story).}
    String actorName = akActor.GetDisplayName()
    If cost <= 0
        DebugMsg("Off-screen purchase: no cost given for " + actorName + ", ignoring")
        Return
    EndIf
    If cost > MaxOffScreenGoldChange
        cost = MaxOffScreenGoldChange
    EndIf

    Form goldFormP = Game.GetFormFromFile(0x0000000F, "Skyrim.esm")
    If !goldFormP
        Return
    EndIf
    Int carried = akActor.GetItemCount(goldFormP)
    If carried <= 0
        DebugMsg("Off-screen purchase: " + actorName + " has no gold, skipping")
        Return
    EndIf
    If cost > carried
        cost = carried
    EndIf

    akActor.RemoveItem(goldFormP, cost, true)
    SeverActionsNative.Native_OffScreen_IncrementGoldLost(akActor, cost)

    ; Item side — capped and category-defaulted like item_acquired.
    If count > 5
        count = 5
    EndIf
    If count <= 0
        count = 1
    EndIf
    If category == ""
        category = "any"
    EndIf
    Bool gotItem = false
    If itemName != ""
        gotItem = SeverActionsNative.Native_GiveItemByName(akActor, itemName, category, count)
    EndIf

    String eventText
    If gotItem
        eventText = actorName + " spent " + cost + " gold on " + itemName + " — " + reason
    Else
        eventText = actorName + " spent " + cost + " gold — " + reason
    EndIf
    SkyrimNetApi.RegisterEvent("persistent_generic", WrapPersistentEvent(eventText + "."), akActor, None)
    SeverActionsNative.Native_OffScreen_AddEvent(akActor, eventText, "notable", GetGameTimeInSeconds(), true, "gold_change", 0 - cost, "", "")
    DebugMsg("Off-screen purchase: " + actorName + " -" + cost + "g for '" + itemName + "' (resolved=" + gotItem + ", " + reason + ")")

    ; Same consequence-cooldown stamp the dispatch applies to the other kinds.
    StorageUtil.SetFloatValue(akActor, KEY_LAST_CONSEQUENCE_GT, GetGameTimeInSeconds())
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
    {Per-actor schedule type (FLWD v17). A work-hours override REPLACES the
     global work window for this NPC — Relax and Home stay on the global
     windows. Work is still evaluated before Relax, so wherever the custom
     window overlaps Relax the NPC works. No override (or no actor) = the
     global DetermineScheduleTypeForNow() result.}
    If akActor
        Float oStart = SeverActionsNativeExt.Native_GetWorkHoursOverrideStart(akActor)
        Float oEnd   = SeverActionsNativeExt.Native_GetWorkHoursOverrideEnd(akActor)
        If oStart >= 0.0 && oEnd >= 0.0
            Float hour = GetCurrentGameHour()
            If HourInWindow(hour, oStart, oEnd)
                Return SCHEDULE_WORK
            ElseIf hour >= SCHEDULE_PLAY_START && hour < SCHEDULE_PLAY_END
                Return SCHEDULE_PLAY
            EndIf
            Return SCHEDULE_HOME
        EndIf
    EndIf
    Return DetermineScheduleTypeForNow()
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
        ; Issue #14: do NOT silently fall back to the home anchor on a work
        ; swap — the caller logs "-> type 1" while the pool marker moves HOME.
        ; Return None instead: the swap is skipped (retried next tick) and the
        ; breadcrumb is loud. Usual cause: workLoc failed ResolveFormID on
        ; load (see the FollowerDataStore load error).
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

; ── Route B work-pool helpers ────────────────────────────────────────────────
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
    {The tight-radius (1200) work sandbox package, resolved by FormID (created by
     GenerateWorkSandbox.pas). Returns None until the .pas has been run.}
    If !WorkSandboxPackageCache
        WorkSandboxPackageCache = Game.GetFormFromFile(0x00165676, "SeverActions.esp") as Package
    EndIf
    Return WorkSandboxPackageCache
EndFunction

Keyword Function GetWorkAnchorKeyword()
    {The work-marker linked-ref keyword, resolved by FormID. Returns None until the
     .pas has been run.}
    If !WorkAnchorKeywordCache
        WorkAnchorKeywordCache = Game.GetFormFromFile(0x00165675, "SeverActions.esp") as Keyword
    EndIf
    Return WorkAnchorKeywordCache
EndFunction

Package WorkGuardPackageCache

Package Function GetWorkGuardPackage()
    {Bodyguard package — the dedicated SeverActions_GuardBodyguard (0x165677), a
     purpose-built clone of FollowGuard_Prisoner: a Follow targeting a LinkedRef, NO
     WeaponDrawn flag (sheathed), radius 300/400 (comfortable spacing — not the 128/256
     combat crowding), crosses load doors. Made via GenerateGuardFollow.pas so we don't
     repurpose the arrest packages. (The .pas couldn't set Preferred Speed to Run by
     element name, so the follow gait is whatever the engine's default follow AI uses —
     verify in-game it sprints to catch up; if not, fix the .pas speed field + re-run.)
     The protectee is linked via GetGuardAnchorKeyword (FollowTargetKW), which this
     package follows. OrphanCleanup's arrest scrub spares bodyguards (see
     OnOrphanCleanup in SeverActions_Arrest.psc).}
    If !WorkGuardPackageCache
        WorkGuardPackageCache = Game.GetFormFromFile(0x00165677, "SeverActions.esp") as Package
    EndIf
    Return WorkGuardPackageCache
EndFunction

Keyword GuardAnchorKeywordCache

Keyword Function GetGuardAnchorKeyword()
    {The arrest system's follow linked-ref keyword (FollowTargetKW, 0x030155). The
     bodyguard reuses it because FollowGuard_Prisoner follows whatever it points at —
     here, the protectee. Separate from WorkAnchorKW (location work) so the two modes
     never collide.}
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

; Hex FormID parsing uses the native SeverActionsNative.HexToInt (StringUtils.h) —
; handles the "0x"/"..." formats, far faster than a Papyrus char loop, and already
; used by Follow/Outfit.

Function GuardNPC(Actor akActor, Actor akProtectee)
    {Protect-a-person work assignment (Guard/Mercenary). Links the retainer to a
     MOVING actor (so the tight WorkGuard package shadows them), sets an Ally
     relationship so the retainer engages threats to their charge, and applies the
     guard package during work hours. The protectee actor IS the work "loc" — guard
     mode is detected by Native_GetWorkLoc returning an Actor.}
    If !akActor || !akProtectee
        Return
    EndIf
    ; Link via the arrest follow keyword — FollowGuard_Prisoner follows whatever this
    ; points at (sheathed, crosses doors), so the retainer shadows their charge.
    Keyword followKw = GetGuardAnchorKeyword()
    If followKw
        ; Permanent: guard duty lasts until reassigned/cleared — the 30-day
        ; staleness prune must not sever the protectee link.
        SeverActionsNativeExt.LinkedRef_SetPermanent(akActor, akProtectee, followKw)
    Else
        DebugMsg("GuardNPC: guard follow keyword not found. Guard inactive for " + akActor.GetDisplayName())
    EndIf
    SeverActionsNative.Native_SetWorkLoc(akActor, akProtectee)
    SeverActionsNativeExt.Native_SetWorkLocationName(akActor, "protecting " + akProtectee.GetDisplayName())
    ; Ally rank (3) → a helps-allies combat NPC (guards/mercs) defends their charge.
    akActor.SetRelationshipRank(akProtectee, 3)

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
    If ShowNotifications
        Debug.Notification(akActor.GetDisplayName() + " will protect " + akProtectee.GetDisplayName() + " during work hours.")
    EndIf
EndFunction

ObjectReference Function EnsureWorkMarker(Actor akActor, ObjectReference akTarget)
    {Return this actor's work marker — reposition the existing one (reassign to a new
     spot) or spawn a force-persistent XMarkerHeading at akTarget. Stored per-actor so
     it stays a live, persistent reference and can be reused / cleaned up.}
    If !akActor || !akTarget
        Return None
    EndIf
    ObjectReference marker = StorageUtil.GetFormValue(akActor, KEY_WORK_MARKER) as ObjectReference
    If marker
        marker.MoveTo(akTarget)
        ; Derive-mode premises: the premises FOLLOW the work marker - the
        ; owned-property cell containing it is the premises, anywhere else is
        ; none. Every marker placement path funnels through here, so this is
        ; the one sync point (no-op for non-retainers).
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
    {Apply the tight-radius (1200) work package, anchored to the NPC's linked work
     marker. Symmetric with RemoveWorkSandbox — touches ONLY our own
     WorkSandboxPackage override, never the actor's wider stack, so it's safe on any
     SA-owned worker (incl. track-only). Never overrides an active following companion.
     POST-MIGRATION: routes to the schedule alias pool instead.}
    ; Jail gate (meli field report): the work package is applied at priority
    ; 110 — the SAME priority as the jail's PrisonerSandBox hold — so seating
    ; it on a jailed worker is a coin-flip the prisoner usually wins: they
    ; walk out to their job while JailedNPCStore (and the UI) still say
    ; jailed. Jail owns the actor until release; work resumes on the first
    ; schedule tick after RemoveJailedNPC.
    If akActor && SeverActionsNativeExt.Native_Jailed_IsJailed(akActor)
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
    ; Never stamp work over an actively-following NPC (casual OR companion). The
    ; teammate check below only catches companions; casual SkyrimNet followers
    ; aren't teammates, so this is what keeps the schedule from re-applying the
    ; priority-110 work package over their follow package.
    If IsActorActivelyFollowing(akActor)
        DebugMsg("ApplyWorkSandbox: SKIPPED - " + akActor.GetDisplayName() + " is actively following (corroborated)")
        Return
    EndIf
    If IsRegisteredFollower(akActor) && akActor.IsPlayerTeammate() && akActor.GetAV("WaitingForPlayer") != -1.0
        Return
    EndIf
    ; An explicit player 'wait here' (WFP==1, wait sandbox at prio 100) must
    ; not be silently converted into a work shift (prio 110 + WFP=2) by the
    ; schedule tick (audit). Work resumes after the player releases the wait.
    If akActor.GetAV("WaitingForPlayer") == 1.0
        Return
    EndIf
    ; Priority 110 (matches the proven PrisonerSandBox) so the work package wins
    ; over stubborn vanilla schedule packages on full NPCs (bards, citizens, etc.).
    ActorUtil.AddPackageOverride(akActor, workPkg, 110, 1)
    akActor.SetAV("WaitingForPlayer", 2)
    akActor.EvaluatePackage()
EndFunction

Function RemoveWorkSandbox(Actor akActor)
    {Remove the work package override so the NPC reverts to their home schedule
     (homed) or native AI (home-less). Symmetric with ApplyWorkSandbox.}
    If !akActor
        Return
    EndIf
    ; Remove BOTH work packages — the active one may have switched between the
    ; sandbox (location) and guard (protect-a-person) modes since it was applied.
    Package sandboxPkg = GetWorkSandboxPackage()
    Package guardPkg = GetWorkGuardPackage()
    If sandboxPkg
        ActorUtil.RemovePackageOverride(akActor, sandboxPkg)
    EndIf
    If guardPkg
        ActorUtil.RemovePackageOverride(akActor, guardPkg)
    EndIf
    ; ApplyWorkSandbox set WaitingForPlayer=2; leaving it stamped makes SA and
    ; DialogueFollower-conditioned packages read a phantom wait forever on
    ; work-only NPCs (audit). Guarded: only clear OUR value, and never when a
    ; live home sandbox owns the hold.
    If akActor.GetAV("WaitingForPlayer") == 2.0
        If SeverActionsNative.Native_GetHomeMarkerSlot(akActor) < 0 && !GetHomeMarkerB(akActor)
            akActor.SetAV("WaitingForPlayer", 0)
        EndIf
    EndIf
    If SchedSystemActive()
        EmptySchedAlias(akActor, SCHEDULE_WORK)
    EndIf
    akActor.EvaluatePackage()
EndFunction

Function StripScheduleForJail(Actor akActor)
    {Pull a just-jailed worker off the schedule (meli field report). Called by
     ArrestScript.AddJailedNPC — the single choke point both the escorted and
     the off-screen jailing paths flow through — and by SchedAliasStepFor's
     jail gate as a one-shot heal for saves jailed before the gates landed.

     Empties any schedule alias (its quest-95 package would otherwise fight
     the jail sandbox), removes the prio-110 work/guard overrides that TIE
     the PrisonerSandBox's priority (the actual escape route), and resets the
     schedule cursor so the post-release tick re-evaluates from scratch. The
     work ASSIGNMENT itself is preserved — jail suspends the job, it doesn't
     fire them; work resumes on the first schedule tick after RemoveJailedNPC.
     Idempotent, cheap no-op for a non-worker.}
    If !akActor
        Return
    EndIf
    If SchedSystemActive()
        EmptyAllSchedAliases(akActor)
    EndIf
    ; RemoveWorkSandbox drops both work-mode packages (sandbox + guard),
    ; clears our WFP=2 stamp where safe, and no-ops cleanly if nothing is
    ; applied. It ends with EvaluatePackage, which re-selects the jail hold.
    RemoveWorkSandbox(akActor)
    StorageUtil.SetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, -99)
EndFunction

Function ClearWorkSandboxForFollow(Actor akActor)
    {Called when an NPC becomes (or resumes being) an active companion. Drops any
     live work-sandbox package override so the priority-110 work package can't
     outrank the follow package, and resets the schedule state so a later DISMISS
     re-evaluates and re-applies work if it's work hours. The work ASSIGNMENT
     itself (Native_GetWorkLoc / KEY_WORK_ONLY_NPCS membership) is preserved —
     companion status only suspends the work package, it doesn't fire them.
     Idempotent: RemoveWorkSandbox is a no-op when no work package is applied,
     so this is safe to call on any follow-start (worker or not).}
    If !akActor
        Return
    EndIf
    ; ApplyWorkSandbox parks them at WaitingForPlayer == 2 (the work-shift marker);
    ; our follow package only engages at WaitingForPlayer == 0, so clear the marker
    ; before EvaluatePackage. Guarded on == 2 so we never stomp a real follow/wait
    ; state (0 follow, 1 wait, -1 not-a-follower) set by another path.
    If akActor.GetAV("WaitingForPlayer") == 2.0
        akActor.SetAV("WaitingForPlayer", 0.0)
    EndIf
    RemoveWorkSandbox(akActor)
    StorageUtil.SetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, -99)
EndFunction

Function StripSandboxesForFollow(Actor akActor)
    {Called when an NPC starts (or resumes) following — recruit, companion-follow,
     casual StartFollowing, external-framework teammate onboarding. Drops every
     SA sandbox that outranks the follow package (priority ~50): home (legacy
     alias + Route B, 100), Route B play (105), safe-interior (100), and
     furniture (80). Companion to ClearWorkSandboxForFollow, which owns the work
     sandbox (110) — kept separate because the work strip also resets schedule
     state (KEY_LAST_SCHEDULED_TYPE) for dismiss-resume. Every removal here is a
     documented safe no-op when the sandbox isn't active, so call speculatively
     on any follow start. Assignments are preserved: home re-applies via the
     cell-load/verifier paths and play via the schedule tick once follow ends.}
    If !akActor
        Return
    EndIf
    RemoveHomeSandbox(akActor)
    RemovePlaySandboxB(akActor)
    ; The safe-interior auto-sandbox lives on the Follow quest — its light strip
    ; clears the flag + overrides without teleporting or re-registering follow
    ; (the caller is about to start follow itself).
    SeverActions_Follow followSys = GetFollowScript()
    If followSys
        followSys.StripSafeInteriorForFollow(akActor)
    EndIf
    ; Furniture pin (priority 80) — only tear down when actually using furniture,
    ; so we don't fire spurious 'furniture_stopped' events on every follow start.
    SeverActions_Furniture furnSys = GetFurnitureScript()
    If furnSys && SkyrimNetApi.HasPackage(akActor, "SeverActions_UseFurniture")
        furnSys.StopUsingFurniture_Execute(akActor)
    EndIf
EndFunction

; Cached SeverActions_ActivelyFollowing (0x0F0809). Issue #402: this lookup used
; to run PER NPC inside IsActorActivelyFollowing (itself called per NPC from
; ReconcileSchedAliasesFor) and again inline in both schedule-swap loops - four
; GetFormFromFile calls per homed NPC per 30s tick to fetch one constant form.
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
    {True if the actor is actively following the player right now — casual
     (StartFollowing) AND companion (CompanionStartFollowing) follow both add the
     SeverActions_ActivelyFollowing faction (0x0F0809), and it's removed on wait /
     sandbox / stop / dismiss. The work-sandbox apply + reinforce paths gate on this
     so an actively-following NPC never gets the priority-110 work package stamped
     over their follow package. The teammate check those paths already do only
     catches COMPANION followers; a casual SkyrimNet follower isn't a teammate, so
     without this the schedule re-applied work over their (priority-50) casual
     follow package every tick.

     Issue #14 regression screen: the faction persists in the save and several
     "resume follow" paths set it without ownership checks, so a DISMISSED homed
     NPC can carry a stale membership across sessions — silently freezing their
     work schedule (swaps fire, home applies, work never does; field report
     3.7.4-dev3). Require corroborating live follow state beyond the faction:
     player-teammate (companions), roster membership (registered/track-only),
     or SkyrimNet's FollowPlayer package (casual). A dismissed NPC has none of
     these, so a stale flag alone can no longer block the schedule guards.}
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
    ; Casual follow = the 200-alias POOL SLOT since the pool migration; the
    ; SkyrimNet "FollowPlayer" package is now only the pool-exhaustion
    ; fallback, so a slot-seated casual follower has no package. Check the
    ; slot first, package second (mirrors Follow.HasFollowPackage).
    SeverActions_Follow fs = GetFollowScript()
    If fs && fs.IsInFollowerSlot(akActor)
        Return true
    EndIf
    Return SkyrimNetApi.HasPackage(akActor, "FollowPlayer")
EndFunction

Function ReinforceWorkPackage(Actor akActor)
    {Re-assert the work package mid-shift. A vanilla NPC-to-NPC greeting / scene can
     pull a working NPC (especially a bodyguard following their charge) off our
     override; the override persists but the engine won't snap back to it on its own,
     so they'd stay idle for the rest of the shift. Re-apply + EvaluatePackage so they
     resume after the interruption — mirrors how companions reacquire their follow
     package after a greeting. Called every work tick for NPCs already on shift.
     Cheap no-op when they're already on the work package; skips combat so we never
     yank them out of a fight. EvaluatePackage respects a still-active higher-priority
     greeting (it won't cut one short), then re-selects ours once it ends.}
    If !akActor || akActor.IsInCombat()
        Return
    EndIf
    ; Jail gate — see ApplyWorkSandbox. Re-asserting work over a prisoner
    ; is the same escape at the same tied priority.
    If SeverActionsNativeExt.Native_Jailed_IsJailed(akActor)
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
    ; An explicit player 'wait here' (WFP==1, wait sandbox at prio 100) must
    ; not be silently converted into a work shift (prio 110 + WFP=2) by the
    ; schedule tick (audit). Work resumes after the player releases the wait.
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
    {Move the follower's Work or Play marker into position.
     kind = "work" or "play". By default the marker drops at the PLAYER's current
     position (akDest = None). Pass akDest to place it at a resolved destination
     instead (e.g. a named workplace the player isn't standing at). asNameOverride
     forces the display/prompt location name; blank = derive it from the target's
     own location/cell.
     WORK: no home or marker slot needed. A force-persistent XMarker is
     spawned at the spot and linked to the NPC via WorkAnchorKeyword. In the
     alias era the SchedWork pool (300 concurrent) enforces work hours; the
     tight WorkSandboxPackage override is the pre-migration
     fallback. Home-less workers are tracked in KEY_WORK_ONLY_NPCS; homed
     workers are detected by Native_GetWorkLoc.
     PLAY: same runtime-marker + PlayAnchorKW pattern - SchedRelax pool (300
     concurrent) in the alias era, shared PlaySandboxB override pre-migration.
     Still requires a home (a leisure routine only makes sense alongside
     one) — legacy-slot or anchor-marker homes both qualify.}
    If !akActor
        Return
    EndIf

    ; ── WORK (Route B decoupled pool) ──
    If kind == "work"
        Bool hadHome = (GetAssignedHome(akActor) != "")
        ObjectReference target = akDest
        If target
            ; A NAMED interior destination resolves to the EXTERIOR entrance door
            ; (the interior cell is unloaded at resolve time, so the resolver can't
            ; reach its interior marker). For a work SPOT we want a point INSIDE —
            ; follow the door's teleport to the interior marker so they work in the
            ; building, not loitering on the doorstep. Returns None for non-doors /
            ; exterior targets, so the original target is kept.
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
        ; Link the NPC to the marker (cosaved + restored by PackageManager LREF) and
        ; record the work loc for prompts / decorators. The link/override are skipped
        ; (with a warning) until the ESP records exist + properties are auto-filled —
        ; the marker + work-loc name still register so prompts read correctly.
        Keyword workKw = GetWorkAnchorKeyword()
        If workKw
            ; Permanent: the work anchor is set ONCE at assignment and must
            ; survive the LREF 30-day staleness prune (it used to silently
            ; die, leaving the retainer's work sandbox with no target).
            SeverActionsNativeExt.LinkedRef_SetPermanent(akActor, workMarker, workKw)
        Else
            DebugMsg("SetRoutineLocHere(work): work keyword not found - run GenerateWorkSandbox.pas. Work sandbox inactive for " + akActor.GetDisplayName())
        EndIf
        SeverActionsNative.Native_SetWorkLoc(akActor, workMarker)
        String workName = ResolveRoutineLocName(target, asNameOverride)
        SeverActionsNativeExt.Native_SetWorkLocationName(akActor, workName)

        ; Home-less worker: track for ProcessWorkOnlySwaps' work-hours-only toggle,
        ; and mark TrueHome migrated so no off-hours path teleports them anywhere.
        If !hadHome
            If !StorageUtil.FormListHas(None, KEY_WORK_ONLY_NPCS, akActor as Form)
                StorageUtil.FormListAdd(None, KEY_WORK_ONLY_NPCS, akActor as Form, false)
            EndIf
            StorageUtil.SetIntValue(akActor, KEY_TRUEHOME_MIGRATED, 1)
        EndIf

        ; Force the next swap tick to re-evaluate, and apply immediately if it's
        ; already work hours so the NPC heads to the spot without a 30s wait.
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
        If ShowNotifications
            Debug.Notification(akActor.GetDisplayName() + " will spend their work hours here.")
        EndIf
        Return
    EndIf

    ; ── PLAY (still requires a home: a leisure routine only makes sense
    ; alongside one; legacy-slot and anchor-marker homes both qualify).
    ; Alias era seats the SchedRelax pool (300 concurrent); the Route B
    ; override is the pre-migration fallback ──
    If kind != "play"
        Return
    EndIf
    If GetAssignedHome(akActor) == ""
        DebugMsg("SetRoutineLocHere: " + akActor.GetDisplayName() + " has no home - assign home first")
        Return
    EndIf

    ObjectReference playTarget = akDest
    If playTarget
        ; Follow a door destination inside (the work-marker lesson).
        ObjectReference insideP = SeverActionsNative.FindInteriorMarkerForDoor(playTarget)
        If insideP
            playTarget = insideP
        EndIf
    Else
        playTarget = Game.GetPlayer()
    EndIf

    ; Reuse the NPC's existing play marker (runtime-spawned OR a legacy
    ; PlayMarkerList pool marker — both just move); spawn fresh otherwise.
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
    ; T1-A.3: native source of truth — surfaced into prompts via the
    ; sever_play_location decorator.
    SeverActionsNativeExt.Native_SetPlayLocationName(akActor, locName)

    ; Force next tick to re-evaluate; apply immediately if it's already
    ; play hours so the NPC heads over without the 30s wait.
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
    If ShowNotifications
        ; UI calls it "Relax" which is clearer to users; internal kind stays "play".
        Debug.Notification(akActor.GetDisplayName() + " will spend their relax hours here.")
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
        ; Guard mode? Undo the Ally bond with the protectee before we wipe the work
        ; target (so we still know who it was).
        Actor exProtectee = SeverActionsNative.Native_GetWorkLoc(akActor) as Actor
        If exProtectee
            akActor.SetRelationshipRank(exProtectee, 0)
        EndIf
        SeverActionsNative.Native_ClearWorkLoc(akActor)
        StorageUtil.UnsetStringValue(akActor, "SeverFollower_WorkLocation")
        ; Route B teardown: drop the work-package override, unlink the marker, and
        ; delete the spawned marker so it doesn't leak as a persistent ref.
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
        ; Derive-mode premises: no work site, no premises.
        SeverActionsNativeExt2.Venture_SyncPremisesFromWork(akActor, None)
        ; Home-less worker reverts fully to native AI.
        If StorageUtil.FormListHas(None, KEY_WORK_ONLY_NPCS, akActor as Form)
            StorageUtil.FormListRemove(None, KEY_WORK_ONLY_NPCS, akActor as Form, true)
        EndIf
    ElseIf kind == "play"
        ; Route B teardown: drop the play override, unlink the anchor, and
        ; delete the marker ONLY if we runtime-spawned it (legacy pool
        ; markers belong to PlayMarkerList).
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

Function ProcessScheduleSwapsRouteB()
    {Iterate all homed NPCs that are currently dismissed. On hour transition
     (schedule type changed since last tick), MoveTo their HomeMarker_NN to the
     correct anchor (TrueHomeAnchor / WorkMarker / PlayMarker). The existing
     HomeSandbox_NN alias package keeps targeting HomeMarker — follower naturally
     re-paths when the marker teleports.
     Also runs one-shot TrueHomeAnchor migration for NPCs from pre-schedule saves.
     PRE-MIGRATION PATH ONLY — post-migration ticks use ProcessScheduleSwapsAliases.}
    If !HomeMarkerList
        Return
    EndIf
    Int targetType = DetermineScheduleTypeForNow()
    Int count = StorageUtil.FormListCount(None, KEY_HOMED_NPCS)

    Int i = 0
    While i < count
        Form entry = StorageUtil.FormListGet(None, KEY_HOMED_NPCS, i)
        Actor npc = entry as Actor
        ; "Dismissed" must be judged by IsRegisteredFollower, NOT the teammate
        ; flag alone. Track-only / custom-AI followers (their own framework owns
        ; the teammate flag, which SA deliberately never sets) are ACTIVELY
        ; following while IsPlayerTeammate() stays false forever - so the
        ; teammate-only gate dragged them to their home/play spot mid-follow,
        ; while FollowDriftMonitor re-asserted the follow link every 5s. The
        ; engine gave up and ran an FF runtime fallback package, and no amount
        ; of Clear Packages stuck because the next tick re-applied the sandbox
        ; (field report: Joraca Blue-Shoal stuck on the play package). The
        ; SetRoutineLocHere call site already gates on IsRegisteredFollower;
        ; this loop is what missed it.
        If npc && !npc.IsDeleted() && !npc.IsPlayerTeammate() && !IsRegisteredFollower(npc)
            ; Self-heal stale ActivelyFollowing membership (issue #14 regression):
            ; this NPC is dismissed — not registered, not a teammate — so the
            ; follow faction can only be a leftover from a prior session, and it
            ; silently blocks the work guards below (home applies, work never
            ; does). Casual followers with a LIVE FollowPlayer package keep it.
            Faction afFact = GetActivelyFollowingFaction()
            ; Pool-slot guard (post-migration): a LIVE casual follower carries
            ; the faction with NO FollowPlayer package (they ride the pool), so
            ; the package check alone would misread one as stale and strip it.
            ; Only heal when NOT following by EITHER mechanism. (Reachable here
            ; via a dismissed former companion who is now casually followed.)
            SeverActions_Follow fsHeal = GetFollowScript()
            If afFact && npc.IsInFaction(afFact) && !SkyrimNetApi.HasPackage(npc, "FollowPlayer") && !(fsHeal && fsHeal.IsInFollowerSlot(npc))
                npc.RemoveFromFaction(afFact)
                DebugMsg("ScheduleSwap: cleared stale ActivelyFollowing faction from dismissed " + npc.GetDisplayName())
            EndIf
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
                        ; Route B: a homed NPC that ALSO has a work assignment gets the
                        ; tight 1200-radius work package during work hours (overrides the
                        ; large home sandbox), and reverts to the home schedule otherwise.
                        If SeverActionsNative.Native_GetWorkLoc(npc)
                            If targetType == SCHEDULE_WORK
                                ApplyWorkSandbox(npc)
                            Else
                                RemoveWorkSandbox(npc)
                            EndIf
                        EndIf
                        ; Route B play: same layering during play hours (the legacy
                        ; marker-move above still points home at the same spot — the
                        ; tighter play override simply wins while it's applied).
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
                    ; Homed NPC already on a work shift — reinforce so a greeting/scene
                    ; doesn't strand them off their work/guard package mid-shift.
                    ReinforceWorkPackage(npc)
                EndIf
            ElseIf GetHomeMarkerB(npc)
                ; Route B homed — overrides layer on the fixed home anchor; no
                ; marker moves. Base home override is constant; work (110) and
                ; play (105) outrank it during their hours.
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
            ; Self-heal for NPCs stuck by the old teammate-only gate: a
            ; REGISTERED follower must never carry a home/play/work sandbox
            ; (RegisterFollower strips them on recruit; only the pre-fix swap
            ; could re-apply one afterwards). Skipping alone would leave an
            ; already-stuck NPC wearing the sandbox forever, so strip it once
            ; here. KEY_LAST_SCHEDULED_TYPE != -99 means a swap had been
            ; applied; setting it back to -99 makes this a one-shot per NPC
            ; instead of a per-tick churn.
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
    {Iterate work-only NPCs (Route B: a linked work marker, NO home). During work
     hours apply the tight 1200-radius WorkSandboxPackage (anchored to their linked
     marker); outside work hours remove it so they fully revert to native / vanilla
     AI (the "work-hours sandbox only" contract). Binary applied(work)/released(non-
     work) keyed off KEY_LAST_SCHEDULED_TYPE — these NPCs are NOT in KEY_HOMED_NPCS
     so ProcessScheduleSwapsRouteB never touches them; the key is unshared per actor.
     PRE-MIGRATION PATH ONLY — post-migration ticks use ProcessWorkOnlySwapsAliases.}
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
        ; Same track-only guard as ProcessScheduleSwaps: an actively-following
        ; custom-AI follower never carries the teammate flag, so the work
        ; sandbox would fight their follow package the same way.
        If npc && !npc.IsDeleted() && !npc.IsPlayerTeammate() && !IsRegisteredFollower(npc)
            ; Authority check (save-bleed guard). KEY_WORK_ONLY_NPCS is a
            ; StorageUtil GLOBAL (None-keyed) list, which can carry an entry
            ; across a same-session save-to-save load: load an earlier save
            ; where she was a retainer with a work spot, then jump to the
            ; current save where she is NOT — the list keeps her, but her
            ; native work assignment reverted with the cosave. Native_GetWorkLoc
            ; is cosaved and reverts per-save, so it is the truth. No work loc
            ; in THIS save = no assignment: strip any lingering package and
            ; prune the stale entry so she stops walking to a job she no
            ; longer has (field report: Irileth resumed her old work spot).
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
    {One-shot: move legacy work assignments onto the Route B linked-ref pool. Reuses
     each NPC's already-positioned work marker (Native_GetWorkLoc) as the linked-ref
     target — no re-placement. Home-less workers also drop their old large-radius
     home override and release the home slot they borrowed under the old system.
     No-op until WorkAnchorKeyword is filled (guarded by the caller).}
    Keyword workKw = GetWorkAnchorKeyword()
    If !workKw
        Return   ; records not present yet — nothing to migrate onto
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

    ; Homed workers (KEY_HOMED_NPCS with a work loc) — just establish the linked
    ; ref so the schedule's work-hours override can anchor to it.
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
; ROUTE B HOME / PLAY — pre-migration fallback only
; Middle era between the 40-slot MHiYH aliases and today's sched-alias
; pools: per-NPC force-persistent XMarker linked via an anchor keyword +
; ONE shared sandbox package (override). Superseded by the
; SchedHome/Work/Relax alias pools (SCHED_ALIAS_POOL_SIZE = 300 each; the
; one-way Native_GetAliasesMigrated flag flips on first load of a current
; ESP), which sandbox around the SAME anchor markers — the markers remain
; load-bearing in all eras, only this override-based ENFORCEMENT is the older path.
; These functions still run when SchedSystemActive() is false (outdated ESP)
; and as migration sources; do not describe them as the current system.
; =============================================================================

Int Property ROUTEB_HOME_KW_FORMID  = 0x0016567D AutoReadOnly
Int Property ROUTEB_PLAY_KW_FORMID  = 0x0016567E AutoReadOnly
Int Property ROUTEB_HOME_PKG_FORMID = 0x0016567F AutoReadOnly
{SeverActions_HomeSandboxB — sandbox r=4096 at LinkedRef(HomeAnchorKW);
 import-package copy of WorkSandbox, radius matching the legacy per-slot
 home packages.}
Int Property ROUTEB_PLAY_PKG_FORMID = 0x00165680 AutoReadOnly
{SeverActions_PlaySandboxB — sandbox r=1500 at LinkedRef(PlayAnchorKW).}
String Property KEY_HOMEB_MARKER    = "SeverHomeB_Marker" AutoReadOnly
String Property KEY_PLAYB_RUNTIME   = "SeverPlayB_Runtime" AutoReadOnly
{1 = the play marker was runtime-spawned by Route B (delete on clear);
 absent = a legacy PlayMarkerList pool marker (never delete those).}

Keyword Function GetHomeBAnchorKeyword()
    Return Game.GetFormFromFile(ROUTEB_HOME_KW_FORMID, "SeverActions.esp") as Keyword
EndFunction

Keyword Function GetPlayBAnchorKeyword()
    Return Game.GetFormFromFile(ROUTEB_PLAY_KW_FORMID, "SeverActions.esp") as Keyword
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
    {Route B play: the shared PlaySandboxB (r=1500) anchored to the NPC's
     PlayAnchorKW linked marker, applied during play hours only (priority
     105 — above the home base 100, below work's 110). Lazily (re)links the
     marker so legacy play assignments self-migrate on first application.
     POST-MIGRATION: routes to the schedule alias pool instead.}
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
    ; Follow guards — copied from ApplyWorkSandbox. Play (105) outranks follow
    ; (~50), and the schedule tick would otherwise re-stamp it right after a
    ; follow start stripped it (the "won't follow during play hours" bug).
    ; IsActorActivelyFollowing covers casual SkyrimNet followers; the teammate
    ; check covers companions; WFP==1 is an explicit player 'wait here' (or
    ; camp pin) that must not be converted into play time.
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
    {Safe no-op when the play override isn't applied. Post-migration also
     releases the relax schedule alias.}
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
; SCHEDULE ALIAS POOLS (post-migration scheduling — design doc v3)
; Three ESP quests (SeverActions_SchedHomeQuest / SchedWorkQuest /
; SchedRelaxQuest, 0x16A785-87) carry 300 ReferenceAliases each; every alias
; holds ONE sandbox V2 package that anchors through the NPC's anchor-keyword
; linked ref. Filling an alias with ForceRefTo is the entire enforcement —
; no per-NPC ActorUtil overrides on the hot path (the override spam of the
; Route B tick is what this replaces).
;
; Activation is one-way: once BeginSchedAliasMigration() flips the cosaved
; Native_GetAliasesMigrated() flag, SchedSystemActive() is true forever and
; every legacy apply/tick path routes here instead. Pre-flag, all functions
; here are inert (native indices are -1, so empties no-op and nothing fills).
;
; Per-NPC bookkeeping (which alias index of each type the NPC holds) lives in
; the native FollowerDataStore cosave (Native_Get/SetSchedAliasIndex) so it
; survives save/load and drives the per-load drift sweep.
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

; ── Guard-duty alias pool (FLWD v19) ──
; Guard-mode retainers (work target is an Actor) ride a dedicated alias in
; SeverActions_GuardQuest during work hours instead of the prio-110
; AddPackageOverride assist: an alias's package re-applies NATIVELY on cell
; load, where the override drops on 3D unload (the same gap the follower
; pool closed). The override stays as the pool-exhaustion fallback and the
; Route B path; work-hours gating stays in the reconcile, not the package.
Int Property GUARD_QUEST_FORMID    = 0x0016A78E AutoReadOnly
{SeverActions_GuardQuest — 100-slot ReferenceAlias pool (Guard_00..99), each
 carrying SeverActions_GuardBodyguard (0x00165677 — Follow @ FollowTargetKW,
 sheathed, crosses doors; generated by xEdit Scripts/GenerateGuardQuest.pas).
 Quest DNAM priority 105 — above the sched quests (95) so an on-shift guard
 hold outranks schedule packages.}
Int Property GUARD_ALIAS_POOL_SIZE = 100 AutoReadOnly
{Raised 50->100 alongside the 500 retainer roster cap. MUST match the alias
 count generated by GenerateGuardQuest.pas (Guard_00..99).}
Quest _guardQuest = None
Bool _guardQuestResolved = false
Int _guardCursor = 0

; Migration batch state (script vars — persist in the save, so a save/load
; mid-migration resumes the drain exactly where it stopped).
Actor[] _migHomed = None
Int _migHomedIdx = 0
Int _migWorkIdx = 0

Bool Function EnsureSchedQuests()
    {Lazy-resolve the three schedule quests + V2 packages (override #1: never
     ESP properties, always GetFormFromFile). Loud + false on failure so every
     consumer can no-op safely; retried on each call until all resolve.}
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
    {The single gate for the post-migration world. Quests resolvable AND the
     cosaved migration flag flipped.}
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
    {Loud exactly once per type until a slot frees (override #3).}
    String exKey = KEY_SCHED_POOL_EXHAUSTED + GetSchedTypeName(aiType)
    If StorageUtil.GetIntValue(None, exKey, 0) == 0
        StorageUtil.SetIntValue(None, exKey, 1)
        Debug.Trace("[SeverActions] SCHEDULE ALIAS POOL EXHAUSTED (" + GetSchedTypeName(aiType) + "): all " + SCHED_ALIAS_POOL_SIZE + " aliases are occupied. The NPC keeps their previous schedule behavior until a slot frees.")
        Debug.Notification("SeverActions: schedule pool full (" + GetSchedTypeName(aiType) + ") — see MCM")
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
    {Fast bookkeeping check: the alias our recorded index names still points
     at this actor. NO full-pool scan here — tick paths call this per NPC
     (drift from outside sources is repaired by SweepSchedAliasesOnLoad).}
    Int idx = SeverActionsNativeExt.Native_GetSchedAliasIndex(akActor, aiType)
    If idx < 0
        Return false
    EndIf
    ReferenceAlias al = GetSchedAlias(aiType, idx)
    Return al && al.GetReference() == akActor
EndFunction

; ── Guard-duty alias pool (FLWD v19) ────────────────────────────────────────

Quest Function GetGuardQuest()
    {Lazy-resolve the guard-duty alias quest (the EnsureSchedQuests pattern:
     never ESP properties, always GetFormFromFile). None while the ESP
     predates the pool — the prio-110 override assist remains the guard
     mechanism exactly as before. Retried on each call until it resolves.}
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
    {Rotating-cursor scan for an unoccupied guard alias (the
     FindFreeSchedAlias pattern). -1 = pool exhausted (or pool unavailable).}
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
    {Seat a guard-mode retainer (work target is an Actor) in the guard pool —
     the alias's GuardBodyguard package (FollowTargetKW-driven) applies
     itself on ForceRefTo and re-applies natively on cell load. Returns
     false when the pool is unavailable/exhausted so the caller can fall
     back to the prio-110 override assist. Idempotent.}
    If !akActor
        Return false
    EndIf
    If SeverActionsNativeExt.Native_GetGuardAliasIndex(akActor) >= 0
        Return true   ; already holding one — idempotent fast path
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
    {Release the guard alias (if any) and drop the cosaved index. Idempotent
     — safe no-op when the retainer holds no guard alias. Does NOT call
     EvaluatePackage; the caller's reconcile batches that.}
    If !akActor
        Return
    EndIf
    Int idx = SeverActionsNativeExt.Native_GetGuardAliasIndex(akActor)
    If idx >= 0
        ReferenceAlias al = GetGuardAlias(idx)
        If al && al.GetReference() == akActor
            al.Clear()
        EndIf
        ; Index was stale (alias repurposed under us) — drop the bookkeeping
        ; either way; SweepGuardAliasesOnLoad owns cross-checking the pool.
        SeverActionsNativeExt.Native_SetGuardAliasIndex(akActor, -1)
        Return
    EndIf
    ; Index already -1 (e.g. ClearFollowerData ran first on a dismiss — v19
    ; wiped it pre-preserve) — pool scan so a guard alias can't leak filled
    ; and leave the retainer shadowing their charge post-dismiss.
    Int scan = 0
    While scan < GUARD_ALIAS_POOL_SIZE
        ReferenceAlias scanAl = GetGuardAlias(scan)
        If scanAl && scanAl.GetReference() == akActor
            scanAl.Clear()
        EndIf
        scan += 1
    EndWhile
EndFunction

Bool Function FillSchedAlias(Actor akActor, Int aiType)
    {Put the NPC into a free schedule alias of the given type. Idempotent.
     The alias's V2 package applies itself on ForceRefTo; guard mode (work
     target is an Actor) ADDITIONALLY seats the retainer in the guard-alias
     pool (FillGuardAlias — self-healing on cell load), with the prio-110
     override only as the pool-exhaustion fallback. The other override added
     here is the documented assist:
       - track-only followers (Inigo/Lucien class): their NPC-record packages
         outrank quest-alias packages, so the V2 package is ALSO asserted as
         an override at the type's priority (Q6 option A).}
    If !akActor
        Return false
    EndIf
    If SeverActionsNativeExt.Native_GetSchedAliasIndex(akActor, aiType) >= 0
        Return true   ; already holding one — idempotent fast path
    EndIf
    ; Jail gate — see ApplyWorkSandbox. The alias V2 assist for WORK is also
    ; asserted at the tied priority 110, so the alias route escapes jail
    ; exactly like the override route.
    If SeverActionsNativeExt.Native_Jailed_IsJailed(akActor)
        Return false
    EndIf
    ; Follow/wait guards — mirrors the legacy apply functions. Reconcile
    ; checks these too; repeating them here protects every DIRECT caller
    ; (SendHome, the Apply* routing gates, scene-restore) as well.
    If IsActorActivelyFollowing(akActor)
        Return false
    EndIf
    If IsRegisteredFollower(akActor) && akActor.IsPlayerTeammate() && akActor.GetAV("WaitingForPlayer") != -1.0
        Return false
    EndIf
    If akActor.GetAV("WaitingForPlayer") == 1.0
        Return false
    EndIf
    ; Scene guard (HOME only): never yank an actor out of a vanilla scene —
    ; mark suspended; CheckSceneSuspendedHomes / the tick retries later.
    If aiType == SCHEDULE_HOME && SeverActionsNative.Native_IsActorInScene(akActor)
        SeverActionsNativeExt.Native_SetHomeSceneSuspended(akActor, true)
        DebugMsg("SchedAlias: deferring HOME fill - " + akActor.GetDisplayName() + " is in a vanilla scene")
        Return false
    EndIf
    Int freeIdx = FindFreeSchedAlias(aiType)
    If freeIdx < 0
        _NoteSchedPoolExhausted(aiType)
        Return false
    EndIf
    ReferenceAlias al = GetSchedAlias(aiType, freeIdx)
    If !al
        Debug.Trace("[SeverActions] SchedAlias: GetNthAlias(" + freeIdx + ") on " + GetSchedTypeName(aiType) + " quest returned a non-ReferenceAlias — ESP corrupt?")
        Return false
    EndIf
    al.ForceRefTo(akActor)
    SeverActionsNativeExt.Native_SetSchedAliasIndex(akActor, aiType, freeIdx)
    Bool addedAssist = false
    If aiType == SCHEDULE_WORK && (SeverActionsNative.Native_GetWorkLoc(akActor) as Actor)
        ; Guard mode: the follow rides a dedicated guard alias now (self-heals
        ; on cell load) INSTEAD of the prio-110 override assist (drops on 3D
        ; unload). The override stays as the pool-exhaustion fallback.
        If !FillGuardAlias(akActor)
            Package guardPkg = GetWorkGuardPackage()
            If guardPkg
                ActorUtil.AddPackageOverride(akActor, guardPkg, 110, 1)
                addedAssist = true
            EndIf
        EndIf
    EndIf
    If IsTrackOnlyFollower(akActor)
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
    DebugMsg("SchedAlias: " + akActor.GetDisplayName() + " -> " + GetSchedTypeName(aiType) + " alias " + freeIdx)
    Return true
EndFunction

Function EmptySchedAlias(Actor akActor, Int aiType)
    {Release the NPC's alias of this type (fast path: index verify only, no
     pool scan). Also strips the two fill-time assists. Does NOT call
     EvaluatePackage — the caller batches that. Safe no-op when the NPC
     holds no alias of this type (always the case pre-migration).}
    If !akActor
        Return
    EndIf
    If aiType == SCHEDULE_WORK
        ; Pool release first — independent of the sched index (a stale sched
        ; index must never strand a held guard alias). The override strip
        ; below stays for migration-era/override-fallback holders.
        _FreeGuardAlias(akActor)
    EndIf
    Int idx = SeverActionsNativeExt.Native_GetSchedAliasIndex(akActor, aiType)
    If idx < 0
        Return
    EndIf
    ReferenceAlias al = GetSchedAlias(aiType, idx)
    If al && al.GetReference() == akActor
        al.Clear()
    EndIf
    ; Index was stale (alias cleared/ repurposed under us) — drop bookkeeping
    ; either way; SweepSchedAliasesOnLoad owns cross-checking the pool side.
    SeverActionsNativeExt.Native_SetSchedAliasIndex(akActor, aiType, -1)
    If aiType == SCHEDULE_WORK
        Package guardPkg = GetWorkGuardPackage()
        If guardPkg
            ActorUtil.RemovePackageOverride(akActor, guardPkg)
        EndIf
    EndIf
    If IsTrackOnlyFollower(akActor)
        Package v2 = GetSchedPackageForType(aiType)
        If v2
            ActorUtil.RemovePackageOverride(akActor, v2)
        EndIf
    EndIf
    ; Work-empty on a HOME-LESS NPC releases the sandbox WFP hold (mirrors
    ; RemoveWorkSandbox's guard: never stomp a live home hold).
    If aiType == SCHEDULE_WORK && GetAssignedHome(akActor) == ""
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
    {THE per-NPC schedule function (post-migration world). Computes the one
     desired alias type from the current hour + assignments, empties the other
     two, fills the desired one, and keeps KEY_LAST_SCHEDULED_TYPE as pure
     transition bookkeeping (prompt override #7). All follow/wait guards
     resolve to "holds nothing".

     Issue #402: returns the desired type it computed, using the same sentinels
     KEY_LAST_SCHEDULED_TYPE uses — SCHEDULE_HOME/WORK/PLAY, -1 for "released
     to native AI" (work-only NPC off shift), -99 for "under direct
     player/framework control, holds nothing". Callers that need the type no
     longer re-derive it with a second DetermineScheduleTypeFor round-trip.
     Papyrus lets callers discard the return, so existing call sites are
     unaffected.}
    If !akActor || akActor.IsDeleted()
        Return -99
    EndIf
    ; Follow/wait guards — an NPC under direct player/framework control holds
    ; no schedule aliases at all.
    If IsActorActivelyFollowing(akActor) \
        || (IsRegisteredFollower(akActor) && akActor.IsPlayerTeammate() && akActor.GetAV("WaitingForPlayer") != -1.0) \
        || akActor.GetAV("WaitingForPlayer") == 1.0
        If HoldsAnySchedAlias(akActor)
            EmptyAllSchedAliases(akActor)
            akActor.EvaluatePackage()
        EndIf
        Return -99
    EndIf

    Bool hasHome = (GetAssignedHome(akActor) != "")
    Int nowType = DetermineScheduleTypeFor(akActor)
    Int desired = -1
    If nowType == SCHEDULE_WORK && SeverActionsNative.Native_GetWorkLoc(akActor)
        desired = SCHEDULE_WORK
    ElseIf nowType == SCHEDULE_PLAY && SeverActionsNative.Native_GetPlayLoc(akActor) && hasHome
        desired = SCHEDULE_PLAY
    ElseIf hasHome
        desired = SCHEDULE_HOME
    EndIf
    ; desired == -1: work-only NPC outside work hours — released to native AI.

    Int lastType = StorageUtil.GetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, -99)
    If lastType == desired
        ; Steady state — verify the desired alias is still really held (fast
        ; index check) so a pool-side clear can't strand them forever.
        If desired >= 0 && !IsSchedAliasContentValid(akActor, desired)
            SeverActionsNativeExt.Native_SetSchedAliasIndex(akActor, desired, -1)
            FillSchedAlias(akActor, desired)
        EndIf
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
    {Mid-shift guard-mode reinforce (alias-world mirror of ReinforceWorkPackage):
     a greeting/scene can pull a bodyguard off the follow override; re-assert it.
     Only guard mode needs this — plain work/home/relax alias packages are
     quest packages the engine re-selects on its own after an interruption.}
    If !akActor || akActor.IsInCombat()
        Return
    EndIf
    ; Jail gate — see ApplyWorkSandbox. The guard package re-assert is a
    ; prio-110 override too.
    If SeverActionsNativeExt.Native_Jailed_IsJailed(akActor)
        Return
    EndIf
    If SeverActionsNativeExt.Native_GetGuardAliasIndex(akActor) >= 0
        Return   ; alias-held — the package self-heals on cell load; no override to re-assert
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

; ── Guard pool — load-time adoption + reconciliation sweep ──────────────────

Function _AdoptOverrideGuardsFromList(String listKey)
    {One-shot migration half: override-era guard retainers (workLoc is an
     Actor, on-shift, riding the prio-110 override) are seated in the pool
     and the override stripped. Off-shift guard retainers are left alone —
     their next WORK transition fills the alias through FillSchedAlias.}
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
    {Roster side of the verify half: drop recorded indices whose alias no
     longer points at the retainer (the next FillSchedAlias re-seats them).}
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
    {Load-time guard-pool reconciliation + one-shot override-era adoption
     (the SweepSchedAliasesOnLoad pattern, for the guard pool).
     MIGRATION half (one-shot, sentinel SeverActions_GuardPoolMigDone):
     override-era guard retainers are seated and their prio-110 override
     stripped. VERIFY half (every load — 100 GetReference calls): pool
     aliases holding deleted/disabled or no-longer-guard-mode actors are
     emptied; duplicate fills resolve to the recorded index; mismatches
     re-adopt; stale roster indices drop.}
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

; ── Tick dispatchers (flag-routed) ─────────────────────────────────────────

; Issue #402 chunking state. Plain script vars — they DO persist in the save,
; but nothing depends on their value surviving: both cursors are modulo-wrapped
; against a freshly measured length every use, so a stale index is corrected on
; the spot rather than being trusted.
Int _tickCounter = 0
Int _schedCursor = 0
Int _slowCursor  = 0

Int Property SCHED_CHUNK_THRESHOLD = 16 AutoReadOnly
{Below this many scheduled NPCs, behaviour is UNCHANGED — the full walk runs
 every tick exactly as it always did. The chunking machinery only engages for
 the rosters that actually produce the stack dumps, so the overwhelming majority
 of players are not exposed to it at all. Chunking trades stack size for
 schedule LATENCY (an NPC can arrive at work a chunk-cycle late), and a normal
 party must not pay that to fix a 50-follower problem.}

Int Property SCHED_CHUNK_BUDGET = 8 AutoReadOnly
{NPCs of real per-NPC schedule work per tick once chunking engages. Starvation
 is bounded at ceil(N / this) ticks — at 50 due that is 7 ticks (~3.5 min real,
 and only in the pathological case of 50 NPCs transitioning simultaneously).}

Int Property SCHED_SLOW_LANE_TICKS = 8 AutoReadOnly
{Once chunking engages, the full-roster walk drops to every Nth tick (~4 min)
 AND is itself chunked to SCHED_CHUNK_BUDGET entries per run — so read the real
 coverage latency as ceil(roster / budget) runs, not the cadence alone: a
 50-entry roster comes all the way round in ~28 minutes, not 4.

 Its only remaining unique job is the three heals the native pre-filter cannot
 see, because they live in StorageUtil: a stale KEY_LAST_SCHEDULED_TYPE on an
 alias-free NPC, a stale ActivelyFollowing faction on a dismissed NPC, and
 pruning KEY_WORK_ONLY_NPCS rows with no work assignment in this save. All
 three are cross-session drift, not per-tick state, so tens of minutes is an
 appropriate latency for them. Nothing silently stops being healed — but do
 NOT move a time-sensitive check onto this lane on the strength of the cadence
 number; check it against the sweep time above.}

Function ProcessSchedulePasses(Bool schedActive)
    {Route the schedule + work-only passes for this tick (issue #402).

     Small roster, or Route B (pre-migration): the original full walks, every
     tick, byte-for-byte the old behaviour.

     Large alias-era roster: the native due set every tick (fast lane) plus a
     chunked full walk every SCHED_SLOW_LANE_TICKS (slow lane) for the
     StorageUtil-only heals. See ScheduleTickFilter.h for why the split is safe
     — the filter can only ever prove "nothing to do", never decide anything.}
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
    {The chunked full-roster walk (issue #402). Carries the two in-step heals —
     stale KEY_LAST_SCHEDULED_TYPE, stale ActivelyFollowing faction — through
     SchedAliasStepFor, plus the work-only list prune, which is the third heal
     the native filter cannot express.

     Its own cursor, independent of the fast lane's: this walks the WHOLE roster
     a slice at a time, while the fast lane walks a due set that is rebuilt from
     scratch every tick.}
    Int hc = StorageUtil.FormListCount(None, KEY_HOMED_NPCS)
    If hc > 0
        ; Stack-local index, same reason as ProcessScheduleDueAliases: _slowCursor
        ; is shared persistent state and two live stacks are reachable. Milder
        ; here (an out-of-range FormListGet returns None and SchedAliasStepFor
        ; early-returns on it, so the failure is a skipped NPC rather than an
        ; aborted stack) but the fix costs one local, so it gets the same shape.
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
    ; FULL walk, deliberately not prune-only. An earlier revision passed
    ; abPruneOnly here on the reasoning that the fast lane had already
    ; reconciled anything that needed it — which was wrong and opened a real
    ; coverage hole: ReconcileSchedAliasesFor's STEADY-STATE branch re-checks
    ; IsSchedAliasContentValid and re-fills when the recorded index no longer
    ; points at this actor, and an on-shift work-only NPC has desired == held so
    ; the fast lane filters them out and that check never runs. Homed NPCs still
    ; got it through the chunked walk above; work-only NPCs are not in
    ; KEY_HOMED_NPCS, so for them the heal vanished until the next game load.
    ; The work-only list is the smaller of the two and this runs every
    ; SCHED_SLOW_LANE_TICKS ticks, so paying the full reconcile is the right
    ; trade against stranding an NPC on a dead alias index for a session.
    ProcessWorkOnlySwapsAliases()
EndFunction

; Both dispatchers take the era gate as a parameter (issue #402). They used to
; call SchedSystemActive() themselves — EnsureSchedQuests() plus a native cosave
; read — so the common small-roster path answered the same per-tick constant
; three times: once in _OnUpdatePass and once in each dispatcher.

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
    {Room rotation (ai_docs/NAMED_MARKERS.md 5.5): every 1-3 game hours (per-
     NPC, randomized) move a homed NPC's home anchor marker onto one of the
     named markers dropped in their home and re-evaluate - the sandbox
     travel-to-center walks them there on their own legs, doors included
     (the ProcessScheduleSwaps mechanism at room granularity; both Route B
     and the alias world anchor to the same KEY_HOMEB_MARKER object).

     Gates (spec 5.5): schedule slot HOME only (work/play win exactly as
     today), never inside the sleep window (the bed conductor owns it),
     3D-loaded only (presentation feature - hops nobody sees are churn),
     skip combat/dialogue/busy. NO track-only exclusion - homes are
     post-dismissal, SA-owned state (the follow-phase-only rule).}
    Float now = GetGameTimeInSeconds()
    Int i = 0
    While i < homed.Length
        Actor npc = homed[i]
        If npc && !npc.IsDeleted() && npc.Is3DLoaded() && !npc.IsDead()
            Float nextHop = StorageUtil.GetFloatValue(npc, KEY_NEXT_ROOM_HOP_GT, 0.0)
            If now >= nextHop
                ; Due - re-arm FIRST (even when gates fail or no marker
                ; exists) so a markerless home is not rescanned every 30s.
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
    {Homed-NPC sleep window (dev145). Walks the homed roster each tick: inside
     the window, a loaded, dismissed, non-combat homed NPC whose schedule says
     HOME right now (work/relax windows win - a night-shift worker keeps
     working) is seated in the bed BedAssignment claimed at AssignHome, via
     the furniture pipeline (override + native auto-cleanup + SkyrimNet
     registration - the same path the UseFurniture action takes). Outside the
     window - or if they got re-recruited, died, or the toggle went off -
     they are stood back up (StopUsingFurniture handles the sticky-sleep
     eject). Era-agnostic: touches no schedule aliases, only the furniture
     override, so it works on Route B and alias saves alike. The
     SeverActions_HomeSleeping StorageUtil flag marks OUR sleepers so the
     wake path never yanks an NPC the player sent to furniture manually.

     Issue #402: the roster and the window state are computed ONCE per tick by
     _OnUpdatePass and passed in. This pass, ProcessHomeMarkerHops and
     CheckSceneSuspendedHomes each used to rebuild the homed roster and re-derive
     the same sleep window independently.}
    SeverActions_Furniture furnScr = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Furniture
    If !furnScr
        Return
    EndIf
    Int i = 0
    While i < homed.Length
        Actor npc = homed[i]
        If npc && !npc.IsDeleted()
            Bool asleep = StorageUtil.GetIntValue(npc, "SeverActions_HomeSleeping", 0) == 1
            If asleep
                If !windowOpen || npc.IsDead() || IsRegisteredFollower(npc) || npc.IsPlayerTeammate()
                    ; Morning, death, or re-recruitment - stand them up.
                    furnScr.StopUsingFurniture_Execute(npc)
                    StorageUtil.UnsetIntValue(npc, "SeverActions_HomeSleeping")
                ElseIf !SkyrimNetApi.HasPackage(npc, "SeverActions_UseFurniture")
                    ; Something else already ended the furniture use (auto-stand,
                    ; a StopUsingFurniture action, combat). Drop our flag so the
                    ; next tick can put them back to bed if the night is young.
                    StorageUtil.UnsetIntValue(npc, "SeverActions_HomeSleeping")
                EndIf
            ElseIf windowOpen && npc.Is3DLoaded() && !npc.IsDead() && !npc.IsInCombat() \
                && !IsRegisteredFollower(npc) && !npc.IsPlayerTeammate() \
                && !SkyrimNetApi.HasPackage(npc, "SeverActions_UseFurniture") \
                && DetermineScheduleTypeFor(npc) == SCHEDULE_HOME
                Int bedId = SeverActionsNative.Native_BedAssignment_GetBedFormID(npc)
                If bedId == 0
                    ; No claim on record — homes assigned before BedAssignment
                    ; shipped never claimed one (Svana, dev145 field report),
                    ; and a first claim can also legitimately find nothing.
                    ; The NPC is standing IN their home right now (the sandbox
                    ; holds them there through the night), so a lazy claim in
                    ; their current parent cell scans exactly the right place.
                    ; Throttled to one attempt per game day per NPC so a home
                    ; with genuinely no free bed doesn't rescan every 30s.
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
                    ; IsFurnitureInUse checked HERE so the executor's polite
                    ; "furniture is already in use" event can't fire every 30s
                    ; while someone naps in their bed.
                    furnScr.UseFurnitureRef_Execute(npc, bed)
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
    {The per-NPC body of the post-migration schedule tick, extracted (issue #402)
     so the full-roster walk and the native-prefiltered fast lane run IDENTICAL
     logic rather than two copies that can drift.

     Reconcile alias holdings for a dismissed homed NPC; self-heal a registered
     follower found holding aliases (they must hold none while registered).}
    If !npc || npc.IsDeleted()
        Return
    EndIf
    ; Jail gate (meli field report): the schedule must never touch a jailed
    ; NPC — seating work at the tied priority 110 walks them out of jail
    ; while the UI still says jailed. Mirror of the registered-follower
    ; self-heal below: strip any stale hold once (covers saves jailed before
    ; this fix landed), then leave them to the PrisonerSandBox until release.
    If SeverActionsNativeExt.Native_Jailed_IsJailed(npc)
        If HoldsAnySchedAlias(npc) || StorageUtil.GetIntValue(npc, KEY_LAST_SCHEDULED_TYPE, -99) != -99
            StripScheduleForJail(npc)
            DebugMsg("SchedAlias: stripped schedule hold from jailed " + npc.GetDisplayName())
        EndIf
        Return
    EndIf
    If IsRegisteredFollower(npc)
        ; Self-heal (alias-world mirror of the Route B strip): a
        ; registered follower must never hold schedule aliases.
        If HoldsAnySchedAlias(npc) || StorageUtil.GetIntValue(npc, KEY_LAST_SCHEDULED_TYPE, -99) != -99
            EmptyAllSchedAliases(npc)
            If npc.GetAV("WaitingForPlayer") == 2.0
                npc.SetAV("WaitingForPlayer", 0)
            EndIf
            StorageUtil.SetIntValue(npc, KEY_LAST_SCHEDULED_TYPE, -99)
            npc.EvaluatePackage()
            DebugMsg("SchedAlias: stripped stale schedule aliases from registered follower " + npc.GetDisplayName())
        EndIf
    Else
        ; Work-only NPCs keep their explicit teammate gate (issue #402). The old
        ; ProcessWorkOnlySwapsAliases loop refused to touch a player teammate at
        ; all, and the fast lane routes homed AND work-only NPCs through this one
        ; body — so without this an NFF/vanilla follower with a work marker and
        ; no home could have a work alias filled mid-follow, which is the
        ; "dragged off their follow package" class of bug. Homed NPCs are
        ; deliberately NOT gated here: that path never had this check and relies
        ; on ReconcileSchedAliasesFor's own follow/wait guards, as it always has.
        ; GetAssignedHome is only paid for actual teammates, which are rare in
        ; this roster.
        If npc.IsPlayerTeammate() && GetAssignedHome(npc) == ""
            Return
        EndIf
        ; Same stale-follow-faction heal as the Route B tick: a
        ; dismissed NPC must not keep a leftover ActivelyFollowing
        ; membership (it blocks every follow guard above).
        If !npc.IsPlayerTeammate()
            Faction afFact = GetActivelyFollowingFaction()
            ; Pool-slot guard — see the matching ScheduleSwap heal: never strip
            ; the faction off a live pool-seated casual follower (package-only
            ; check would misread one as stale post-migration).
            SeverActions_Follow fsHeal = GetFollowScript()
            If afFact && npc.IsInFaction(afFact) && !SkyrimNetApi.HasPackage(npc, "FollowPlayer") && !(fsHeal && fsHeal.IsInFollowerSlot(npc))
                npc.RemoveFromFaction(afFact)
                DebugMsg("SchedAlias: cleared stale ActivelyFollowing faction from dismissed " + npc.GetDisplayName())
            EndIf
        EndIf
        ; Issue #402: the reconcile already resolved the desired type —
        ; take its return instead of a second DetermineScheduleTypeFor
        ; (two native override reads + GetCurrentGameHour) plus a
        ; StorageUtil read. desired == WORK subsumes the old
        ; "lastScheduledType == WORK" half: the reconcile has just
        ; written lastScheduledType = desired.
        If ReconcileSchedAliasesFor(npc) == SCHEDULE_WORK
            ReinforceSchedWorkGuard(npc)
        EndIf
    EndIf
EndFunction

Function ProcessScheduleSwapsAliases()
    {Post-migration homed-NPC tick, FULL roster walk. The every-tick path for
     ordinary rosters and for Route B (see ProcessSchedulePasses).

     Above the chunk threshold this function is NOT called at all — the fast
     lane carries each tick and ProcessSchedSlowLane drives SchedAliasStepFor
     over a chunked slice directly. (An earlier draft of this docstring said it
     "becomes the slow lane", which was wrong: the slow lane bypasses it.)}
    Int count = StorageUtil.FormListCount(None, KEY_HOMED_NPCS)
    Int i = 0
    While i < count
        SchedAliasStepFor(StorageUtil.FormListGet(None, KEY_HOMED_NPCS, i) as Actor)
        i += 1
    EndWhile
EndFunction

Function ProcessScheduleDueAliases()
    {FAST LANE (issue #402). One native call replaces the two full roster walks:
     Sched_GetTransitionDue returns only the NPCs with something actually to do
     this tick — a real home/work/relax transition, a registered follower still
     holding an alias, an on-shift guard needing the mid-shift reinforce, or an
     orphaned hold. Steady-state ticks return an empty or near-empty list, so
     the per-NPC cost that used to scale with the roster now scales with the
     number of NPCs whose schedule is genuinely changing.

     Covers the homed AND work-only rosters in one pass: the native enumerates
     FollowerDataStore, which is the source of truth for both (home != "" and
     workLoc != 0 respectively), so ProcessWorkOnlySwapsAliases is not needed
     on this lane. Its StorageUtil list pruning rides the slow lane.

     The result is sorted by FormID, which is what makes the rotating chunk
     cursor below stable across ticks.}
    Actor[] due = SeverActionsNativeExt2.Sched_GetTransitionDue( \
        GetCurrentGameHour(), SCHEDULE_WORK_START, SCHEDULE_WORK_END, \
        SCHEDULE_PLAY_START, SCHEDULE_PLAY_END)
    If !due || due.Length == 0
        Return
    EndIf

    ; Adaptive chunking. A due set this small is processed whole — an hour
    ; boundary that moves a dozen NPCs at once is not a stack problem, and
    ; deferring it would make NPCs visibly late for work. Only a genuinely
    ; large simultaneous transition gets spread across ticks.
    If due.Length <= SCHED_CHUNK_THRESHOLD
        Int i = 0
        While i < due.Length
            SchedAliasStepFor(due[i])
            i += 1
        EndWhile
        Return
    EndIf

    ; Rotating cursor, modulo-wrapped so a shrinking due set can never index
    ; out of range. Starvation is bounded at ceil(N / SCHED_CHUNK_BUDGET) ticks.
    ;
    ; INDEX THROUGH A STACK-LOCAL, never through _schedCursor directly. The var
    ; PERSISTS in the save and is shared by every stack, while `due` is local and
    ; freshly built per stack — and two live _OnUpdatePass stacks are reachable:
    ; the re-entrancy guard admits a second one once the first passes its 120s
    ; ceiling, which it cannot distinguish from a stack that died. That is the
    ; maxed-roster case, i.e. exactly when chunking is engaged. Indexing the
    ; shared var across SchedAliasStepFor's many yield points let a stack whose
    ; due set had shrunk read an index another stack had advanced past the end
    ; of its own array — an out-of-range abort that kills the pass.
    ; The local is bounded by THIS stack's due.Length at every use; the single
    ; write-back at the end is the only shared mutation.
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
    {Post-migration work-only tick: same roster, same stale-entry prune as the
     Route B version (KEY_WORK_ONLY_NPCS is a StorageUtil GLOBAL and can bleed
     across same-session save loads), but enforcement is alias reconciliation.

     Issue #402: this stays a FULL walk on both the small-roster path and the
     slow lane. It carries two things the native fast lane cannot: the prune
     (KEY_WORK_ONLY_NPCS is StorageUtil) and, via the reconcile's steady-state
     branch, the IsSchedAliasContentValid re-fill for an on-shift work-only NPC
     — who is filtered OUT of the fast lane precisely because desired == held.}
    Int count = StorageUtil.FormListCount(None, KEY_WORK_ONLY_NPCS)
    Int i = 0
    While i < count
        Actor npc = StorageUtil.FormListGet(None, KEY_WORK_ONLY_NPCS, i) as Actor
        Bool pruned = false
        If npc && !npc.IsDeleted() && !npc.IsPlayerTeammate() && !IsRegisteredFollower(npc)
            If SeverActionsNative.Native_GetWorkLoc(npc) == None
                ; No native work assignment in THIS save — strip + prune.
                EmptyAllSchedAliases(npc)
                If npc.GetAV("WaitingForPlayer") == 2.0
                    npc.SetAV("WaitingForPlayer", 0)
                EndIf
                npc.EvaluatePackage()
                StorageUtil.FormListRemove(None, KEY_WORK_ONLY_NPCS, npc as Form, true)
                StorageUtil.UnsetIntValue(npc, KEY_LAST_SCHEDULED_TYPE)
                count -= 1
                pruned = true
                DebugMsg("SchedAlias: pruned work-only " + npc.GetDisplayName() + " - no native work assignment this save")
            Else
                ; Issue #402: same one-call form as ProcessScheduleSwapsAliases.
                If ReconcileSchedAliasesFor(npc) == SCHEDULE_WORK
                    ReinforceSchedWorkGuard(npc)
                EndIf
            EndIf
        EndIf
        If !pruned
            i += 1
        EndIf
    EndWhile
EndFunction

; ── Follow-system hooks (prompt override #4) ───────────────────────────────

Function EmptySchedAliasesForFollow(Actor akActor)
    {Called by Follow.psc whenever an NPC comes under direct player/framework
     control (companion follow start, wait here, sandbox, track-only wait).
     Pre-migration this is a no-op (all indices are -1 and WFP is owned by the
     legacy strip paths), so the hooks are safe to call unconditionally.}
    If !akActor
        Return
    EndIf
    Bool had = HoldsAnySchedAlias(akActor)
    If had
        EmptyAllSchedAliases(akActor)
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
    {Called by Follow.psc when follow/sandbox control ends (stop following,
     companion stop, stop sandbox, native sandbox cleanup). Reconcile's
     internal guards make this a no-op when the NPC immediately re-followed
     or was told to wait, so callers never need their own checks.
     NOT called from ExitSafeInteriorSandbox (that path resumes follow).}
    If !akActor
        Return
    EndIf
    If SchedSystemActive()
        ReconcileSchedAliasesFor(akActor)
    EndIf
EndFunction

; ── Migration (design doc §4, prompt override #5) ──────────────────────────

Function BeginSchedAliasMigration()
    {One-way Route B -> alias migration. Flips the cosaved flag FIRST —
     atomically, before any NPC is touched — so a crash mid-batch still
     leaves flag and enforcement model consistent (unreconciled NPCs are
     simply picked up by the next tick's Reconcile). Then drains the roster
     through OnUpdate at 5 NPCs per 0.5s. Fresh install: both lists are
     empty, the flag flips, and the first batch completes immediately.}
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
    {OnUpdate-driven drain: 5 NPCs per fire, re-arms at 0.5s until both
     rosters are exhausted, then hands the tick back to the 30s cadence.}
    Int budget = 5
    While budget > 0 && _migHomed != None && _migHomedIdx < _migHomed.Length
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
            _migHomed = None
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
    {Per-NPC migration step:
       1. strip ALL legacy enforcement (legacy home-slot alias, Route B
          home/work/play overrides incl. the guard override);
       2. guarantee the uniform per-NPC marker model: a KEY_HOMEB_MARKER
          force-persistent XMarker at the NPC's true-home position +
          permanent HomeAnchorKW link (legacy-slot NPCs get a fresh marker
          at their TrueHomeAnchor; the legacy cosave slot VALUE is kept so
          the native verifier keeps its read-only coverage);
       3. re-assert the work/play anchor-keyword links the V2 packages
          target;
       4. reconcile onto the alias pools.}
    If !npc || npc.IsDeleted()
        Return
    EndIf
    ; An actively-following NPC carries no legacy sandboxes (follow start
    ; stripped them) and must not be package-touched mid-follow — their
    ; aliases get filled by the normal dismiss/SendHome path instead.
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
            ; Make sure the fixed true-home anchor is positioned before we
            ; read its location (one-shot for pre-schedule saves).
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
            ; No anchor available (shouldn't happen for homed NPCs) — fall
            ; back to the NPC's current position so the model stays uniform.
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

    ; Re-assert the anchor links the V2 alias packages read. Guard mode
    ; (work target is an Actor) keeps its GuardAnchorKW link untouched.
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

; ── Per-load maintenance (prompt override #6) ──────────────────────────────

Function SweepSchedAliasesOnLoad()
    {Post-migration load sweep (the ONLY full-pool scan anywhere): repairs
     drift between the alias pools and the FLWD bookkeeping. 900 GetReference
     calls once per load — clears aliases holding deleted/disabled actors,
     clears orphans (holder no longer in any schedule roster), and adopts
     index mismatches back into the cosave. Stale FLWD indices pointing at
     aliases that no longer hold the actor are dropped; the next tick's
     steady-state check refills them.}
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
    {Post-migration replacement for ReapplyHomeSandboxing's per-load re-assert
     (design doc §2.5-A — the single bounded exception to "aliases persist,
     no reapply needed"): the two fill-time ASSIST overrides are runtime-only
     and do not survive a load, so re-assert them for every alias-holding
     track-only follower and every guard-mode worker.}
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
    If !npc || npc.IsDeleted()
        Return
    EndIf
    Int workIdx = SeverActionsNativeExt.Native_GetSchedAliasIndex(npc, SCHEDULE_WORK)
    If workIdx >= 0 && (SeverActionsNative.Native_GetWorkLoc(npc) as Actor)
        Package guardPkg = GetWorkGuardPackage()
        If guardPkg
            ActorUtil.AddPackageOverride(npc, guardPkg, 110, 1)
        EndIf
    EndIf
    If IsTrackOnlyFollower(npc)
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

; ── MCM / status helpers ───────────────────────────────────────────────────

Int Function GetSchedPoolUsed(Int aiType)
    {0..300 for a valid type (0=home, 1=work, 2=relax), -1 otherwise.}
    If aiType < 0 || aiType > 2
        Return -1
    EndIf
    Int[] usage = SeverActionsNativeExt.Native_GetSchedPoolUsage()
    If usage == None || usage.Length < 3
        Return -1
    EndIf
    Return usage[aiType]
EndFunction

Bool Function GetSchedPoolExhausted(Int aiType)
    Return StorageUtil.GetIntValue(None, KEY_SCHED_POOL_EXHAUSTED + GetSchedTypeName(aiType), 0) == 1
EndFunction

Bool Function GetSchedMigrationDone()
    Return SeverActionsNativeExt.Native_GetAliasesMigrated()
EndFunction

; =============================================================================
; HOME ASSIGNMENT
; =============================================================================

Function AssignHome(Actor akActor, String locationName)
    {Assign a named location as this NPC's home.
     CURRENT (alias era - any up-to-date ESP; SchedSystemActive() true): stores
     the home in the native cosave, places/keeps a per-NPC force-persistent
     anchor marker at the player's position, and seats the NPC in the SchedHome
     alias pool (SCHED_ALIAS_POOL_SIZE = 300 concurrent; exhaustion is logged
     and the NPC keeps prior behavior until a slot frees). The alias package
     sandboxes around the anchor marker. Home STORAGE has no cap - only
     concurrent schedule enforcement does.
     Fallback (pre-migration / outdated ESP only): the same marker
     drives the Route B package-override sandbox instead.
     Works for both followers (applied on dismiss) and non-followers
     (applied immediately).}
    If !akActor || locationName == ""
        Return
    EndIf

    ; If they held a LEGACY alias slot (the retired 40-slot MHiYH pool),
    ; release it fully — this reassignment moves them onto the current
    ; anchor-marker + sched-alias path. RemoveHomeSandbox clears the
    ; alias, the per-slot override, and the WaitingForPlayer bias.
    Int existingSlot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)
    If existingSlot >= 0
        RemoveHomeSandbox(akActor)
        SeverActionsNative.Native_ReleaseHomeMarkerSlot(akActor)
    EndIf

    ; Store the home location name in the native cosave (single source of truth).
    SeverActionsNative.Native_SetHome(akActor, locationName)

    ; ── Home anchor marker (all eras): per-NPC force-persistent marker at the
    ; PLAYER's position (the player stands where they want the NPC to live) + a
    ; permanent HomeAnchorKW link. The marker IS the true-home anchor and never
    ; moves — the SchedHome alias package sandboxes around it (300 concurrent);
    ; only the pre-migration Route B override still drives it
    ; directly. Work/play layer their own hours on top.
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
        ; Permanent: survives the LREF 30-day staleness prune (work-anchor lesson).
        SeverActionsNativeExt.LinkedRef_SetPermanent(akActor, homeMarker, homeKw)
    ElseIf !homeKw
        DebugMsg("AssignHome: HomeAnchorKW missing (old ESP?) - Route B home sandbox inactive for " + akActor.GetDisplayName())
    EndIf
    ; No TrueHomeAnchor migration needed — the Route B marker is the anchor.
    StorageUtil.SetIntValue(akActor, KEY_TRUEHOME_MIGRATED, 1)
    StorageUtil.SetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, -99)

    ; Apply the sandbox now only if they're not actively following — active
    ; followers get it on dismiss via SendHome/ApplyHomeSandboxIfHomed.
    If homeMarker && !IsRegisteredFollower(akActor)
        If SchedSystemActive()
            ReconcileSchedAliasesFor(akActor)
        Else
            ApplyHomeSandboxB(akActor)
        EndIf
    EndIf
    DebugMsg("Route B home marker placed at " + locationName + " for " + akActor.GetDisplayName())

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

    ; Promote: if this NPC was work-only, they now have a real home — drop them
    ; from the work-only list so the always-on home schedule (ProcessScheduleSwaps)
    ; owns them, routing to the work marker during work hours and home otherwise.
    If StorageUtil.FormListHas(None, KEY_WORK_ONLY_NPCS, akActor as Form)
        StorageUtil.FormListRemove(None, KEY_WORK_ONLY_NPCS, akActor as Form, true)
        StorageUtil.SetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE, -99)
    EndIf

    If ShowNotifications
        Debug.Notification(akActor.GetDisplayName() + " will now call " + locationName + " home.")
    EndIf

    SkyrimNetApi.RegisterPersistentEvent( \
        akActor.GetDisplayName() + " now considers " + locationName + " their home.", \
        akActor, Game.GetPlayer())

    DebugMsg("Home assigned for " + akActor.GetDisplayName() + ": " + locationName)
EndFunction

Function AssignWork(Actor akActor, String locationName)
    {SkyrimNet action: mark the player's current position as where this NPC works.
     Parallel to AssignHome, but for the WORK routine — and NO prior home is
     required (a borrowed marker slot drives a work-hours-only sandbox; see
     SetRoutineLocHere / ProcessWorkOnlySwaps). If the NPC isn't already one of
     the player's retainers, a 90s non-pausing popup offers to put them on the
     books (optional — the work marker stands regardless).}
    If !akActor
        Return
    EndIf

    ; Resolve the named workplace once (if given + resolvable) — used both as
    ; the popup's "named place" button and as the fallback placement target.
    ObjectReference dest = None
    If locationName != "" && SeverActionsNative.IsLocationResolverReady()
        dest = SeverActionsNative.ResolveDestination(akActor, locationName)
    EndIf
    String namedPlace = ""
    If dest
        namedPlace = locationName
    EndIf

    ; Preferred path: open the unified assign-retainer popup. It lets the player
    ; choose the workplace (Here / the named place) + terms; on confirm/Hire the
    ; marker is placed by OnRetainerWorkLoc and the hire is done natively. Not
    ; now / timeout / Escape are full cancels (nothing placed or hired). Only for
    ; non-retainers; the open call self-suppresses if a PrismaUI view has focus
    ; or PrismaUI isn't available.
    If !SeverActionsNativeExt2.Venture_IsRetainer(akActor) \
        && SeverActionsNativeExt.PrismaUI_IsRetainerAssignPromptAvailable() \
        && SeverActionsNativeExt.PrismaUI_OpenRetainerAssignPrompt(akActor, namedPlace, "", "", 90000)
        DebugMsg("AssignWork: opened assign-retainer popup for " + akActor.GetDisplayName())
        Return
    EndIf

    ; Fallback (already a retainer, PrismaUI down, or popup suppressed): place
    ; the work marker directly — at the resolved destination if we have one,
    ; else the player's position.
    SetRoutineLocHere(akActor, "work", dest, locationName)
    FireWorkAssignedEvent(akActor)
    DebugMsg("AssignWork (direct): " + akActor.GetDisplayName() + " -> " + locationName)
EndFunction

Event OnRetainerWorkLoc(string eventName, string strArg, float numArg, Form sender)
    {Fired by the assign-retainer popup ONLY on Hire (confirm). Places the work
     marker at the chosen location (the hire itself is done natively by the
     bridge). Not now / timeout / Escape are full cancels and never fire this.
     strArg = "here" or "named|<placeName>".}
    Actor npc = sender as Actor
    If !npc
        Return
    EndIf
    ; "clear" = manage modal's "Leave them be" — tear down the work marker/override
    ; so the retainer reverts to their own AI.
    If strArg == "clear"
        ClearRoutineLoc(npc, "work")
        Return
    EndIf
    ; "guard|<hexFormId>[|<displayName>]" — protect a specific NPC (Guard/Mercenary
    ; bodyguard, or any job attending someone) rather than a place. The protectee
    ; actor becomes the work target. FormID first; if it doesn't resolve (stale
    ; cosaved/mod-derived ID after a load-order shuffle — the Daegon 0xBC case),
    ; fall back to the display name via ActorFinder.
    If StringUtil.Find(strArg, "guard|") == 0
        String rest = StringUtil.Substring(strArg, 6)
        String hexId = rest
        String targetName = ""
        Int nameBar = StringUtil.Find(rest, "|")
        If nameBar >= 0
            hexId = StringUtil.Substring(rest, 0, nameBar)
            targetName = StringUtil.Substring(rest, nameBar + 1)
        EndIf
        Actor protectee = Game.GetFormEx(SeverActionsNative.HexToInt(hexId)) as Actor
        If !protectee && targetName != ""
            protectee = SeverActionsNative.FindActorByName(targetName)
            If protectee
                DebugMsg("OnRetainerWorkLoc: guard FormID '" + hexId + "' stale — resolved '" + targetName + "' by name instead")
            EndIf
        EndIf
        If protectee
            GuardNPC(npc, protectee)
        Else
            DebugMsg("OnRetainerWorkLoc: guard target did not resolve from '" + strArg + "'")
        EndIf
        Return
    EndIf
    ObjectReference dest = None
    String placeLabel = ""
    Int bar = StringUtil.Find(strArg, "|")
    If bar >= 0
        placeLabel = StringUtil.Substring(strArg, bar + 1)
        If placeLabel != "" && SeverActionsNative.IsLocationResolverReady()
            dest = SeverActionsNative.ResolveDestination(npc, placeLabel)
        EndIf
    EndIf
    SetRoutineLocHere(npc, "work", dest, placeLabel)
    FireWorkAssignedEvent(npc)
    DebugMsg("OnRetainerWorkLoc: placed work marker for " + npc.GetDisplayName() + " (" + strArg + ")")
EndEvent

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

    ; Post-migration: the alias pool IS the home enforcement. Keep the
    ; spawn-if-missing marker block (NPCs skipped by the migration because
    ; they were actively following still need their per-NPC marker), then
    ; fill the home alias directly — never the legacy slot branch.
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
            ; Force into alias — NPC gets per-slot sandbox package automatically.
            ApplyHomeSandbox(akActor, homeMarker, slot)
            akActor.EvaluatePackage()
            DebugMsg("SendHome: forced into alias slot " + slot + " SUCCESS")
            Return
        Else
            DebugMsg("SendHome: marker at slot " + slot + " is None!")
        EndIf
    EndIf

    ; Route B (and legacy-save migration: home name but no slot/marker yet) —
    ; spawn the per-NPC marker at the resolved home. Interior destinations
    ; resolve to the exterior door; follow it inside so the NPC lives in the
    ; building, not on the doorstep (the work-marker lesson).
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

    ; Fallback: only if marker system completely unavailable
    DebugMsg("SendHome: FALLBACK - no marker system")
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
     Persists across save/load (no reapply needed).
     POST-MIGRATION: routes to the schedule alias pool instead.}
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

    ; Casual SkyrimNet followers (StartFollowing) aren't teammates, so the
    ; teammate check below misses them — without this, a homed NPC told to
    ; "come with me" gets the priority-100 home pull re-applied over their
    ; priority-50 follow package on the next cell load / verify pass.
    If IsActorActivelyFollowing(akActor)
        DebugMsg("ApplyHomeSandbox: SKIPPED - " + akActor.GetDisplayName() + " is actively following")
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
        DebugMsg("ApplyHomeSandbox: SKIPPED - " + akActor.GetDisplayName() + " is an active following companion (not dismissed)")
        Return
    EndIf

    ; Wave 6.2: scene-aware entry guard. If the actor is currently bound to a
    ; vanilla BGSScene, applying our home sandbox would fight the scene's own
    ; package (the actor would keep trying to leave the scene location to "go
    ; home"). Mark them scene-suspended; CheckSceneSuspendedHomes on the next
    ; OnUpdate tick will retry once the scene ends.
    If SeverActionsNative.Native_IsActorInScene(akActor)
        DebugMsg("Home: skipping application - " + akActor.GetDisplayName() + " is in a vanilla scene; will retry once scene ends")
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

Function ApplyHomeSandboxB(Actor akActor)
    {Route B twin of ApplyHomeSandbox: ONE shared sandbox package (override,
     priority 100) anchored to the NPC's HomeAnchorKW linked marker. Same
     guards as the legacy path — never on an actively-following companion,
     scene-suspend aware.
     POST-MIGRATION: routes to the schedule alias pool instead.}
    If SchedSystemActive()
        If !akActor
            Return
        EndIf
        ; Preserve the follow guards — FillSchedAlias itself intentionally
        ; has none (ReconcileSchedAliasesFor owns those).
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
    ; Casual-follower guard — mirrors ApplyHomeSandbox; the teammate check
    ; below can't see StartFollowing-driven NPCs.
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

    ; Issue #14: the two home systems are mutually exclusive and Route B wins
    ; (it is the only system new assignments create). If this NPC still holds
    ; a legacy pool slot — e.g. converted by the pre-fix per-load migration —
    ; strip the legacy side so exactly ONE home pull exists. Otherwise the
    ; constant prio-100 legacy pull beats the prio-110 work override whenever
    ; it lapses and the NPC keeps walking home mid-shift.
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
    {Apply home sandbox if this NPC has a home — legacy alias slot or
     Route B marker. Used by framework dismiss paths.
     POST-MIGRATION: fills the home schedule alias instead.}
    If !akActor
        Return
    EndIf
    If SchedSystemActive()
        If GetAssignedHome(akActor) != "" && FillSchedAlias(akActor, SCHEDULE_HOME)
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
     preserved so CheckSceneSuspendedHomes can restore once the scene ends.
     POST-MIGRATION: empties the home schedule alias instead (slot ignored).}
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

Function CheckSceneSuspendedHomes(Actor[] followers, Actor[] homed, Bool schedActive)
    {Wave 6.2: per-tick scene-aware home suspend/restore. Runs every OnUpdate
     tick (30s). Either way the rule is the same:
       - NPC entered a vanilla scene  -> release our home pull + set the flag
       - a suspended NPC's scene ended -> re-apply home
     Per-actor work is idempotent, so any overlap between the input lists is
     harmless.

     TWO ERAS, and they share no code (issue #402):

     ALIAS ERA (schedActive - the live path for any migrated save): one native
     call, Sched_GetSceneSuspendMismatched, returns exactly the actors whose
     live scene state disagrees with the cosaved flag. Both the home-assignment
     and 3D-loaded gates are applied natively, and the scene test is
     GetCurrentScene() inside the filter rather than a per-actor
     Native_IsActorInScene round-trip. **`followers` and `homed` are UNUSED on
     this path** - it returns before touching them.

     ROUTE B (pre-migration only): the legacy two-roster walk over `followers`
     then `homed`, gating on Is3DLoaded and polling Native_IsActorInScene per
     actor. Eligibility is a legacy home-marker slot or a Route B marker, and
     GetHomeMarkerB reads a StorageUtil-keyed object the native cannot see -
     which is why this era keeps the full walk. Sweeping BOTH lists matters
     here (issue #14 root D): the scene-suspend skip can hit any dismissed
     homed NPC via SendHome / ApplyHomeSandboxIfHomed / the per-load reapply,
     and roster-only sweeps left those suspended forever - "will retry" never
     fired.}

    ; Issue #402: the homed roster and the era gate are both computed ONCE per
    ; tick by _OnUpdatePass and passed in. This pass used to call
    ; GetAllHomedNPCs() itself — a full walk that re-validates every entry with a
    ; native GetAssignedHome — on top of the three other passes that each walked
    ; KEY_HOMED_NPCS raw, and it asked SchedSystemActive() (EnsureSchedQuests
    ; PLUS a native cosave read) once per NPC across BOTH passes.

    ; FAST PATH (issue #402): in the alias era, both halves of the only
    ; comparison this pass can act on — live scene state vs the cosaved
    ; home-scene-suspend flag — are native, so one call returns exactly the
    ; mismatched actors and the roster walk disappears. Almost always empty.
    ; Route B keeps the full walk: its eligibility test reads GetHomeMarkerB,
    ; a StorageUtil-keyed marker the native cannot see.
    If schedActive
        Actor[] mismatched = SeverActionsNativeExt2.Sched_GetSceneSuspendMismatched()
        If mismatched
            Int m = 0
            While m < mismatched.Length
                Actor npc = mismatched[m]
                ; Re-check the assignment in Papyrus: the native included
                ; suspended-but-homeless actors so a suspend can always be
                ; undone, and only the restore half applies to them.
                Bool hasHome = (GetAssignedHome(npc) != "")
                If SeverActionsNativeExt.Native_GetHomeSceneSuspended(npc)
                    ; Scene ended — restore. FillSchedAlias clears the flag on
                    ; success; a homeless ex-suspend has nothing to refill, so
                    ; clear the flag directly rather than leaving it stuck.
                    If hasHome && FillSchedAlias(npc, SCHEDULE_HOME)
                        DebugMsg("Home scene-restored (scene ended, alias refilled): " + npc.GetDisplayName())
                    ElseIf !hasHome
                        SeverActionsNativeExt.Native_SetHomeSceneSuspended(npc, false)
                        DebugMsg("Home scene-suspend flag cleared (home no longer assigned): " + npc.GetDisplayName())
                    EndIf
                ElseIf hasHome
                    ; Scene started while home was active — suspend.
                    SuspendHomeSandbox(npc, -1)
                    SeverActionsNativeExt.Native_SetHomeSceneSuspended(npc, true)
                    DebugMsg("Home scene-suspended (vanilla scene active): " + npc.GetDisplayName())
                EndIf
                m += 1
            EndWhile
        EndIf
        Return
    EndIf

    ; ROUTE B ONLY from here down (the alias era returned above). Eligibility
    ; here is a legacy home-marker slot OR a Route B marker, and GetHomeMarkerB
    ; reads a StorageUtil-keyed object the native filter cannot see — so the
    ; legacy path keeps its full walk. Migration is one-way and automatic, so
    ; this is the pre-migration tail, not a live hot path.
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
                    ; T1-B: native source of truth for the scene-suspend flag.
                    Bool wasSuspended = SeverActionsNativeExt.Native_GetHomeSceneSuspended(follower)

                    If inScene && !wasSuspended
                        ; Scene started while home was active — suspend.
                        ; (SuspendHomeSandbox handles both variants via slot < 0.)
                        SuspendHomeSandbox(follower, slot)
                        SeverActionsNativeExt.Native_SetHomeSceneSuspended(follower, true)
                        DebugMsg("Home scene-suspended (vanilla scene active): " + follower.GetDisplayName())
                    ElseIf !inScene && wasSuspended
                        ; Scene ended — restore home. The apply functions clear the
                        ; suspend flag themselves on successful application.
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

    ; Route B home override (shared package) — safe no-op when absent.
    Package homePkgB = GetHomeSandboxBPackage()
    If homePkgB
        ActorUtil.RemovePackageOverride(akActor, homePkgB)
    EndIf

    If SchedSystemActive()
        EmptySchedAlias(akActor, SCHEDULE_HOME)
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

    ; If the sleep window put them in that bed, stand them up BEFORE the claim
    ; is released — otherwise the furniture override keeps steering a homeless
    ; NPC at a bed that just went back to its original owner (dev145).
    If StorageUtil.GetIntValue(akActor, "SeverActions_HomeSleeping", 0) == 1
        SeverActions_Furniture furnClr = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Furniture
        If furnClr
            furnClr.StopUsingFurniture_Execute(akActor)
        EndIf
        StorageUtil.UnsetIntValue(akActor, "SeverActions_HomeSleeping")
    EndIf

    ; Release the auto-claimed bed BEFORE we drop home tracking — the C++ side
    ; reads the bed FormID + original owner from FollowerDataStore (which still
    ; has the entry at this point) and restores the original OWNR.
    SeverActionsNative.Native_BedAssignment_Release(akActor)

    ; Remove sandbox package if active
    RemoveHomeSandbox(akActor)

    If SchedSystemActive()
        ; Home is gone, so a held play alias has no anchor context either —
        ; the next reconcile would drop it, but release the pool slot now.
        ; (RemoveHomeSandbox already released the HOME alias.)
        EmptySchedAlias(akActor, SCHEDULE_PLAY)
    EndIf

    ; Release marker slot (marker stays enabled in holding cell — MHiYH pattern)
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

    ; Remove from global tracking list
    StorageUtil.FormListRemove(None, KEY_HOMED_NPCS, akActor as Form, true)

    ; A still-working NPC must return to the WORK-ONLY schedule list -
    ; AssignHome removed them from it when the home was granted, and without
    ; this they end up in NEITHER list: the work override never re-evaluates
    ; (stuck at work if cleared mid-shift, dead assignment otherwise) (audit).
    If SeverActionsNative.Native_GetWorkLoc(akActor)
        If !StorageUtil.FormListHas(None, KEY_WORK_ONLY_NPCS, akActor as Form)
            StorageUtil.FormListAdd(None, KEY_WORK_ONLY_NPCS, akActor as Form, false)
        EndIf
        StorageUtil.UnsetIntValue(akActor, KEY_LAST_SCHEDULED_TYPE)
    EndIf

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

String Function NormalizeCombatStyleName(String style)
    {Strip common trailing words that LLMs append to combat style names.
     "healer style" -> "healer", "berserker combat style" -> "berserker",
     "melee fighter" -> "melee". Already-clean names pass through unchanged;
     the literal "no combat style" restore keyword is never stripped.
     Mirrors NormalizePresetName in SeverActions_Outfit.psc.}
    String name = SeverActionsNative.StringToLower(style)

    ; The restore keyword contains both suffix words -- exact match wins.
    If name == "no combat style"
        Return name
    EndIf

    ; "Coward" synonyms. The LLM (and the player) will reach for the word
    ; that fits the fiction — "she's a pacifist", "he's a non-combatant" —
    ; long before they reach for our internal token, and an unmapped name
    ; silently falls through to the Brave/Aggressive catch-all.
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
    {Set follower's combat style. Maps style names to actual CombatStyle forms.
     "no combat style" restores the original. All others override the ActorBase record.

     The "healer" style is special — it triggers a native poll subsystem (HealerPoll)
     that force-casts SeverActions_HealOther/Self at HP-threshold targets every ~1s.
     Transitioning into "healer" adds spells + faction membership; transitioning out
     removes them. Both transitions are idempotent via the IsHealer roster check.}
    If !akActor
        Return
    EndIf

    ; Normalize LLM phrasing -- "healer style" / "berserker combat style" must
    ; hit the style map (and the healer-role transition) like the clean name.
    String normalized = NormalizeCombatStyleName(style)
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

    ; "coward" = a companion who is NOT here to fight. Restore whatever
    ; combat style form they came with (a pacifist needs no fighting
    ; archetype) and let the actor values below do the work.
    ; User request: "followers who are there for company rather than for
    ; fighting" — and the three values they named are exactly the three
    ; RegisterFollower force-boosts at recruit, which is why setting them
    ; by hand never stuck.
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
    ; NOTE: "coward" must be tested BEFORE the catch-all Else below, which
    ; would otherwise hand a pacifist Brave/Aggressive like everyone else.
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
    {Entry point kept for any external callers. Essential is applied via quest
     ReferenceAlias slots (templated-safe, live) instead of the ActorBase
     kEssential flag, so this delegates to ReassignEssentialSlots.}
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
;   strArg = "<tier>|<target FormID as signed decimal>" where tier is
;            ("player" | "self" | "ally" | "potion_fallback")
;   numArg = legacy fallback only — an older DLL still float-encodes the
;            target FormID here (exact only to 2^24, so ESL/mod targets round)
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

    ; strArg = "<tier>|<target FormID as signed decimal>". The old contract
    ; carried the FormID in numArg, which is a float32 — exact only to 2^24,
    ; so mod-added/ESL targets rounded and resolved None here.
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

    ; Pick the spell — HealSelf for true self-cast, HealOther for everything else.
    ; (Self-cast on HealOther would still work since AllowForTeammate covers it,
    ;  but the dedicated self spell costs less and uses self-target VFX.)
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
        " (tier=" + tier + ", bonus=" + bonus + ")")
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

; =============================================================================
; TRAP IMMUNITY — the vanilla LightFoot perk, granted to followers
;
; Followers walking onto pressure plates and into bear traps is solved WITHOUT
; overriding anything. Vanilla's own trap scripts already do the work:
; TrapTriggerBase.checkPerks() and TrapBear.checkPerks() call
; hasPerk(LightFoot) on WHATEVER tripped the trap — not on the player
; specifically — and skip the trap when it comes back true. Followers simply
; never had the perk. Grant it and vanilla declines to fire the trap on its own.
;
; It is not a dice roll in practice: the roll is
; "randomFloat(0,100) <= LightFootTriggerPercent", and that global (0x00067194)
; ships at 100, so the check always passes.
;
; Deliberately NOT the way Nether's Follower Framework does it. NFF ships
; replacement TrapTriggerBase.pex / TrapBear.pex carrying its own follower
; faction check — a hard override of two vanilla scripts, which loses to (or
; breaks) any other mod that touches them, last one loaded winning. The perk
; costs us no override and no conflict.
;
; Known coverage limit, and the reason NFF's heavier approach still catches
; more: only three vanilla scripts consult the perk at all. TrapBear defaults
; checkForLightFootPerk to TRUE, so every bear trap is covered for free;
; TrapTriggerBase and DLC2TrapApoTentacle default it to FALSE, so plates are
; covered only where the level designer enabled the check. Tripwires and
; mod-added traps on their own scripts are not covered by any of this.
; =============================================================================

Perk Function GetLightFootPerk() Global
    {Vanilla LightFoot, 0x0005820C in Skyrim.esm. Resolved by FormID rather than
     EditorID — runtime EditorIDs need po3 Tweaks, which has no VR build.}
    Return Game.GetFormFromFile(0x0005820C, "Skyrim.esm") as Perk
EndFunction

Bool Function IsTrapImmunityEnabled()
    {SINGLE source of truth for this setting's default. Read it through here and
     nowhere else — the PreventFollowerFF bug directly above was two reads of one
     key disagreeing about its default, and it hid for a long time because the
     feature still half-worked.}
    Quest SeverActionsQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
    If !SeverActionsQuest
        Return False
    EndIf
    Return StorageUtil.GetIntValue(SeverActionsQuest, "SeverActions_FollowerTrapImmunity", 1) == 1
EndFunction

Function ApplyTrapImmunity(Actor akActor)
    {Grant LightFoot to one follower. Safe to call repeatedly — AddPerk on an
     actor that already has the perk is a no-op, and the HasPerk guard keeps the
     common re-apply path down to a single cheap check.}
    If !akActor || !IsTrapImmunityEnabled()
        Return
    EndIf
    Perk lightFoot = GetLightFootPerk()
    If lightFoot && !akActor.HasPerk(lightFoot)
        akActor.AddPerk(lightFoot)
    EndIf
EndFunction

Function RemoveTrapImmunity(Actor akActor)
    {Take LightFoot back on dismissal. NOT gated on IsTrapImmunityEnabled — a
     player who turns the setting off still needs the perk stripped from everyone
     who already has it, and a dismissed follower must not keep it. Only removes
     what we could have granted, so a player character build that legitimately
     took LightFoot is unaffected (they are never a follower).}
    If !akActor
        Return
    EndIf
    Perk lightFoot = GetLightFootPerk()
    If lightFoot && akActor.HasPerk(lightFoot)
        akActor.RemovePerk(lightFoot)
    EndIf
EndFunction

Function RefreshTrapImmunity(Actor[] followers)
    {Per-load re-apply, called from Maintenance() beside ApplyIgnoreFriendlyHits.
     Perks added via AddPerk do persist in the save, so this is belt-and-braces
     for followers recruited before the feature existed — and it is what makes
     toggling the setting off actually take effect on the existing roster.}
    Bool wantPerk = IsTrapImmunityEnabled()
    Perk lightFoot = GetLightFootPerk()
    If !lightFoot
        Return
    EndIf
    Int i = 0
    Int changed = 0
    While i < followers.Length
        Actor f = followers[i]
        If f
            If wantPerk && !f.HasPerk(lightFoot)
                f.AddPerk(lightFoot)
                changed += 1
            ElseIf !wantPerk && f.HasPerk(lightFoot)
                f.RemovePerk(lightFoot)
                changed += 1
            EndIf
        EndIf
        i += 1
    EndWhile
    DebugMsg("Trap immunity (LightFoot) " + wantPerk + " — updated " + changed + " of " + followers.Length + " followers")
EndFunction

Function ReapplyHomeSandboxing()
    {Migration function for saves upgrading from AddPackageOverride to alias system.
     If a homed NPC has a marker slot but isn't in an alias, force them in.
     Once all users have upgraded, this function does nothing (aliases persist natively).
     Called from Maintenance() on every game load.
     POST-MIGRATION (schedule alias pools): the whole per-load reapply below is
     legacy — quest aliases persist across load natively. The ONLY thing still
     needed per load is re-asserting the runtime-only ASSIST overrides
     (track-only V2 assists + guard-mode follow) — design doc §2.5-A.}
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
        If akActor && !IsRegisteredFollower(akActor)
            Int slot = SeverActionsNative.Native_GetHomeMarkerSlot(akActor)

            If GetHomeMarkerB(akActor)
                ; ── Route B homed NPC — slot -1 is BY DESIGN (AssignHome releases
                ; the legacy pool slot and never acquires one). The legacy
                ; migration must NOT convert them: door-pinning a shared pool
                ; marker + force-filling the legacy alias leaves BOTH home
                ; systems live, and the constant prio-100 legacy home pull beats
                ; the prio-110 work override whenever it lapses (issue #14
                ; Layer B). ApplyHomeSandboxB re-applies the Route B override
                ; and itself strips any legacy slot the pre-fix migration
                ; wrongly acquired on earlier loads.
                ApplyHomeSandboxB(akActor)
            Else
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
                                ; A freshly-acquired slot's TrueHomeAnchor still sits in
                                ; the aaaMarkers holding cell (KEY_TRUEHOME_MIGRATED is
                                ; pre-stamped at assign time, so EnsureTrueHomeAnchorMigrated
                                ; won't move it) — the next home-hours swap would MoveTo
                                ; the pool marker into the void. Anchor it at the same
                                ; destination instead.
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
            ; Close the Route B If/Else split (issue #14 fix)
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
     Always sends home (uses default sendHome=true). Player intent, so an
     NFF-owned follower is dismissed through NFF as well.}
    UnregisterFollower(akActor, true, true)
EndFunction

Function CompanionWait(Actor akActor)
    {Tell any NPC to wait and sandbox at the current location.
     Called by SkyrimNet via companionwait.yaml. Works for both companions and non-companions.
     SIGNATURE IS A YAML CONTRACT (parameterMapping count) — do not add params here;
     batch behavior lives in _CompanionWaitCore.}
    _CompanionWaitCore(akActor, false)
EndFunction

Function _CompanionWaitCore(Actor akActor, Bool abQuiet)
    {The real wait implementation. abQuiet=true is the Wait All batch path: it
     skips ONLY the per-follower Debug.Notification (the ALL loop shows one
     summary instead — N popups stacked for large rosters). Everything else
     stays per-follower on purpose: the follow-state event is KEYED per actor
     (each companion's bio reads their own waiting state — see
     RegisterFollowStateEvent), and the package work is per-actor by nature.

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
       hooks. Voice/wheel "Wait" still works without forcing our package on them.

     NOTE (wait-all latency, field 2026-08-08): this function cannot go native —
     Sandbox() writes PapyrusUtil's package-override store, SkyrimNet's package
     registry, and StorageUtil flags, none of which C++ can reach. The batch
     win is capped at removing per-follower UI spam; the EvaluatePackage /
     override frame costs are inherent until wait moves onto SA's own alias
     machinery.}
    If !akActor
        Return
    EndIf

    ; A live travel slot would countermand this wait on arrival (ClearSlot's
    ; restoreFollower strips the wait sandbox and re-links follow) - dissolve
    ; it first, exactly like CompanionFollow does (audit).
    SeverActions_Travel travelWait = GetTravelScript()
    If travelWait
        travelWait.CancelTravel(akActor, False)
    EndIf
    ; Same stale-seat belt as _CompanionFollowCore - a wait against a pinned
    ; pool package would "take" in our bookkeeping and do nothing on screen.
    If SeverActionsNativeExt2.Travel_ReleaseStaleAliasFor(akActor)
        Debug.Trace("[SeverActions] CompanionWait: released stale travel alias for " + akActor.GetDisplayName())
    EndIf

    ; NFF owns them? Use NFF's OWN wait. Setting the vanilla WaitingForPlayer
    ; AV is advisory for an NFF follower - NFF's packages and bookkeeping do
    ; not consult it - which is why an SA wait on one looked cosmetic.
    If NFFWait(akActor)
        If !abQuiet
            Debug.Notification(akActor.GetDisplayName() + " is waiting here for you.")
        EndIf
        RegisterFollowStateEvent(akActor, "companion_waiting",             akActor.GetDisplayName() + " is waiting for " + Game.GetPlayer().GetDisplayName() + " at the current location.")
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
        ; DLC-owned (Serana): route the wait through HER OWN brain instead of
        ; the raw AV. Dawnguard's monitoring script actively ZEROES a
        ; WaitingForPlayer it didn't order (DLC1NPCMonitoringPlayerScript:
        ; "she's not willing to wait... let's kick her out of this" - the
        ; Serana wait audit, 2026-08-18), so a bare SetAV is cosmetic for her.
        ; DLC1_NPCMentalModelScript.Wait() is what her own wait dialogue
        ; calls: it sets IsWaiting, and when IsWillingToWait it sets the AV
        ; itself and arms her 72h auto-release. SDA's script fork keeps this
        ; surface (every compiled Dawnguard fragment calls into it), so the
        ; routing works for vanilla AND SDA Serana. If she is mid-questline
        ; and NOT willing to wait, refusing is canon - we don't bulldoze it.
        Bool dlcWaitRouted = false
        If SeverActionsNativeExt2.Native_GetFollowerOwner(akActor) == 3
            DLC1_NPCMentalModelScript seranaMM = Game.GetFormFromFile(0x002B6E, "Dawnguard.esm") as DLC1_NPCMentalModelScript
            If seranaMM
                seranaMM.Wait()
                dlcWaitRouted = true
                Debug.Trace("[SeverActions] CompanionWait: routed wait through the DLC mental model for " + akActor.GetDisplayName())
            EndIf
        EndIf
        If !dlcWaitRouted
            akActor.SetAV("WaitingForPlayer", 1)
        EndIf
        ; Schedule alias pools: an explicit wait must also release any schedule
        ; aliases (incl. the track-only assist override) so the schedule can't
        ; pull them back to work/home mid-wait.
        EmptySchedAliasesForFollow(akActor)
        akActor.EvaluatePackage()
    ElseIf followSys
        followSys.Sandbox(akActor)
    Else
        ; Fallback: just set waiting flag if Follow system unavailable
        akActor.SetAV("WaitingForPlayer", 1)
        akActor.EvaluatePackage()
    EndIf

    If ShowNotifications && !abQuiet
        Debug.Notification(akActor.GetDisplayName() + " is waiting here for you.")
    EndIf

    RegisterFollowStateEvent(akActor, "companion_waiting", \
        akActor.GetDisplayName() + " is waiting for " + Game.GetPlayer().GetDisplayName() + " at the current location.")
EndFunction

Function CompanionFollow(Actor akActor)
    {Tell a waiting NPC to resume following. Called by SkyrimNet via companionfollow.yaml.
     SIGNATURE IS A YAML CONTRACT (parameterMapping count) — do not add params here;
     batch behavior lives in _CompanionFollowCore.}
    _CompanionFollowCore(akActor, false)
EndFunction

Function _CompanionFollowCore(Actor akActor, Bool abQuiet)
    {The real resume-follow implementation. abQuiet=true is the Follow All batch
     path: skips ONLY the per-follower Debug.Notification (one summary instead).
     Per-follower follow-state event stays — it is keyed per actor for bios.

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

    ; Companion status suspends any work assignment — drop the live work package
    ; now so it can't outrank the follow package (recruit does the same). The
    ; assignment itself is preserved and resumes when they're dismissed.
    ClearWorkSandboxForFollow(akActor)
    ; Home (100) / play (105) / safe-interior (100) / furniture (80) all
    ; outrank follow (~50) too — drop them so the resume actually shows.
    StripSandboxesForFollow(akActor)

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
    ; CancelTravel only reaches LIVE journeys. A COMPLETED journey whose pool
    ; alias refused to empty (the arrived-but-pinned field case, 2026-08-09)
    ; leaves the priority-106 pool package outranking the follow we are about
    ; to apply - release the stale seat first or this verb silently loses.
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

    If IsTrackOnlyFollower(akActor)
        ; Track-only path — don't put SA's follow package on them. Recovery: if
        ; a prior broken call already attached our alias-based follow package or
        ; a sandbox override, clean it up here. Then clear the vanilla wait
        ; flag and let their mod's package take over via DialogueFollower hooks.
        ;
        ; WAIT AND RESUME MUST STAY SYMMETRIC. _CompanionWaitCore parks an
        ; NFF-owned companion through NFFWait, which puts them in NFF's OWN wait
        ; state - and clearing the vanilla WaitingForPlayer AV below does not
        ; reach NFF's packages, so without this they could never be un-parked.
        ; NFFResume was added for exactly this and was only ever wired into the
        ; casual StartFollowing path, which a REGISTERED follower never reaches
        ; (IsRegisteredFollower is true, so every resume routes here instead).
        NFFResume(akActor)
        If followSys
            followSys.CompanionStopFollowing(akActor, false)
            followSys.StopSandbox(akActor)
        EndIf
        ; Symmetric with the wait routing above: a DLC-owned (Serana) wait was
        ; placed through her mental model, so the resume must go through
        ; StopWaiting() - clearing the raw AV alone leaves her IsWaiting state
        ; set and her 72h auto-release timer armed.
        If SeverActionsNativeExt2.Native_GetFollowerOwner(akActor) == 3
            DLC1_NPCMentalModelScript seranaMMR = Game.GetFormFromFile(0x002B6E, "Dawnguard.esm") as DLC1_NPCMentalModelScript
            If seranaMMR
                seranaMMR.StopWaiting()
                Debug.Trace("[SeverActions] CompanionFollow: routed resume through the DLC mental model for " + akActor.GetDisplayName())
            EndIf
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

    If ShowNotifications && !abQuiet
        Debug.Notification(akActor.GetDisplayName() + " is following you again.")
    EndIf

    RegisterFollowStateEvent(akActor, "companion_resumed_following", \
        akActor.GetDisplayName() + " stopped waiting and is following " + Game.GetPlayer().GetDisplayName() + " again.")
EndFunction

Function FollowerLeaves(Actor akActor)
    {A companion decides to leave on their own. Called by SkyrimNet via followerleaves.yaml.
     This is a dramatic, rare moment after sustained mistreatment.}
    If !akActor
        Return
    EndIf

    ; HARD GATE (field report): the yaml description says EXTREMELY RARE
    ; after severe mistreatment, but prose only steers the stock dialogue
    ; LLM - a story-hungry action selector (e.g. Playwright's gamemaster
    ; override: "shape the world actively - make things happen") fired
    ; this as a dramatic beat on well-treated companions. Enforce the
    ; fiction in code: rapport above the leaving threshold = they refuse
    ; to walk, with a narrated refusal so the chosen beat doesn't ghost.
    If GetRapport(akActor) > LeavingThreshold
        SkyrimNetApi.RegisterEvent("follower_stays",             akActor.GetDisplayName() + " grumbles, but has no real cause to walk out on " + Game.GetPlayer().GetDisplayName() + " - things between them are nowhere near that bad.",             akActor, Game.GetPlayer())
        Debug.Trace("[SeverActions_FollowerManager] FollowerLeaves refused - rapport above leaving threshold for " + akActor.GetDisplayName())
        Return
    EndIf

    ; This is a dramatic moment - the follower is choosing to leave
    SkyrimNetApi.RegisterEvent("follower_left_voluntarily", \
        akActor.GetDisplayName() + " has decided to leave " + Game.GetPlayer().GetDisplayName() + "'s service.", \
        akActor, Game.GetPlayer())

    ; A real departure, so NFF's claim comes down with ours.
    UnregisterFollower(akActor, true, true)
EndFunction

; =============================================================================
; KIDNAP SYSTEM — KidnapNPC / ReleaseCaptive (opt-in, default OFF)
; A follower abducts a named NPC (off-screen resolvable via the global-form
; scan) and delivers them, bound + hooded on a vanilla BoundCaptiveMarker
; (the With Friends Like These shack treatment), to a destination resolved
; through the travel system. Reuses: TravelOrchestrator (both legs), the
; arrest system's prisoner-follow package + dunPrisonerFaction (the trailing
; walk + pacify), and the furniture system's use-this-furniture package (the
; kneeling bound pose — furniture-driven, so it self-restores on cell load).
; State lives in the native KidnapStore ('KDNP'); the kidnap_context /
; sever_kidnap_enabled decorators read it for prompts + eligibility.
; =============================================================================

; Vanilla Skyrim.esm records (verified via HouseCARL 2026-07-05):
;   0x05A9E3 ExecutionHoodDB          (ARMO — the shack captives' black hood)
;   0x0A19E4 IdleBoundKneesStart      (IDLE — animated entry into the shack
;   0x0A19E3 IdleBoundKneesEnterInstant  kneeling hands-bound pose)
;   0x0A19E2 IdleBoundKneesExit       (IDLE — getting up)
; NOTE: the BoundCaptiveMarker FURN (0x0A19DF) is deliberately NOT used.
; v1 parked the victim on a PlaceAtMe'd marker via the furniture SANDBOX
; package — the sandbox tree's Activate procedure CTD'd on cell attach
; (BGSProcedureActivate, crash-2026-07-05-22-45-09). Vanilla only ever
; drives that marker with a SitTarget package we can't author yet, so the
; hold is now furniture-free: SetRestrained + the marker's own idles.
Int Property KIDNAP_HOOD_FORMID        = 0x0005A9E3 AutoReadOnly
Int Property KIDNAP_IDLE_KNEEL_EXIT    = 0x000A19E2 AutoReadOnly
Int Property KIDNAP_MARKER_FORMID      = 0x000A19DF AutoReadOnly
{BoundCaptiveMarker FURN — the shack captives' kneeling hands-bound
 furniture. Driven by SeverActions_BoundCaptiveSit (a pure SitTarget-shape
 package targeting the FurnitureTargetKW linked ref) — NEVER by a sandbox
 package: a sandbox tree's Activate procedure against a runtime-placed
 IsMarker furniture is the crash-2026-07-05-22-45-09 CTD.}
Int Property KIDNAP_SIT_PKG_FORMID     = 0x0016567A AutoReadOnly
{SeverActions_BoundCaptiveSit v2 — vanilla SitTarget TEMPLATE (0x0A9277) with
 Data[16]=Target LinkedRef(FurnitureTargetKW) / [3]=WaitTime / [4]=StopMove,
 byte-matching the DB02 shack captive packages. v1 (0x165678, removed) built a
 raw procedure tree the engine never treated as valid — the captive's default
 AI simply won and she walked home.}
Int Property KIDNAP_GUARD_PKG_FORMID   = 0x00165679 AutoReadOnly
{SeverActions_KidnapGuardSandbox — sandbox r=180 at LinkedRef(SandboxAnchorKW);
 PrisonerSandBox's r=350 reached through small-shop doors and let the guard
 wander outside.}

; ── Captive-hold alias pool (KDNP v6) ──
; The kneel hold ALSO seats the sit package through SeverActions_CaptiveQuest
; aliases (cloned SeverActions_CaptiveSit, priority 105): an alias package
; re-applies natively on cell load, where the priority-95 ActorUtil override
; drops on 3D unload (the captive-heals' whole reason to exist). The override
; and the tick heals stay as backstops (belt and suspenders; a foreign eval
; hook can still drag a captive off). Restraint hold untouched — it is not
; package-driven.
Int Property CAPTIVE_QUEST_FORMID    = 0x0016A78B AutoReadOnly
{SeverActions_CaptiveQuest — 16-slot ReferenceAlias pool (Captive_00..15),
 each carrying SeverActions_CaptiveSit (0x0016A78C, cloned from
 SeverActions_BoundCaptiveSit by GenerateCaptiveAliases.pas). Quest DNAM
 priority 105 — TES5 PACKs have no priority field, so the quest's priority
 is the alias-package precedence knob (> 100 so foreign overrides can't
 preempt; SkyrimNet's eval hook still outranks).}
Int Property CAPTIVE_ALIAS_POOL_SIZE = 16 AutoReadOnly
Quest _captiveQuest = None
Bool _captiveQuestResolved = false
Int _captiveCursor = 0

; ── V2 Slice 1: consequences ──
Int Property KIDNAP_BOUNTY             = 1000 AutoReadOnly
{Vanilla kidnapping bounty. Charged ONCE per captivity: at the grab when
 witnessed, otherwise on release (the freed victim reports it).}
Float Property KIDNAP_GOSSIP_DAYS      = 2.0 AutoReadOnly
{Game days held before the victim's home hold starts talking.}
Float Property KIDNAP_SEARCH_DAYS      = 4.0 AutoReadOnly
{Game days held before hired searchers can track the captive to the hold
 site (prominent victims only — those with a home-hold crime faction).}
; Native_Kidnap_SetFlag/GetFlag bit values — keep in sync with KidnapStore::Flag.
Int Property KIDNAP_FLAG_WITNESSED     = 1 AutoReadOnly
Int Property KIDNAP_FLAG_GOSSIP        = 2 AutoReadOnly
Int Property KIDNAP_FLAG_SEARCH        = 4 AutoReadOnly
Int Property KIDNAP_FLAG_RESTRAINT     = 8 AutoReadOnly
Int Property KIDNAP_FLAG_INTERROGATED  = 16 AutoReadOnly
Int Property KIDNAP_FLAG_UNBOUND       = 32 AutoReadOnly
Int Property KIDNAP_FLAG_LEASHED       = 64 AutoReadOnly
{Hands bound, but walking behind a leader on the escort-follow package instead
 of pinned to the hold marker (LeashCaptive / UnleashCaptive, 2026-08-23).}
; Road-encounter window: the off-screen fast-forward teleport is skipped
; while the player is within this range of the marching pair, so a player
; chasing the road can actually intercept the kidnap mid-transit.
Float Property KIDNAP_ROADSIDE_RADIUS  = 12000.0 AutoReadOnly
{RESTRAIN action, not an abduction: an open, ordered hold. No hood, no
 bounty on release, no gossip/search/ransom — grabTime stays 0 so the
 consequence timer block never arms; this flag gates the hood equip and
 the narrative texts. Keep in sync with KidnapStore::kFlagRestraint.}

; Last KidnapTick game time - a jump of >= 1 game hour between ticks means
; the player waited/slept/fast-traveled, and an in-flight leg should treat
; that as elapsed march time (user expectation: wait an hour, the abduction
; proceeds off-screen; the 12h deadline alone made short waits do nothing).
Float KidnapLastTickGT = 0.0

; ── V2 Slice 2: ransom ──
; Ransom states — keep in sync with KidnapStore::RansomState.
Int Property KIDNAP_RANSOM_PENDING     = 1 AutoReadOnly
Int Property KIDNAP_RANSOM_PAID       = 2 AutoReadOnly
Int Property KIDNAP_RANSOM_REFUSED    = 3 AutoReadOnly
Float Property KIDNAP_RANSOM_RESOLVE_DAYS = 1.5 AutoReadOnly
{Game days between the demand going out and the steward's answer.}
Float Property KIDNAP_RANSOM_GRACE_DAYS   = 1.0 AutoReadOnly
{After a PAID ransom: game days the payers wait for the release before
 hiring searchers anyway (paid-and-kept = worst faith).}
Float Property KIDNAP_RANSOM_REOPEN_DAYS  = 2.0 AutoReadOnly
{After a refused ransom whose hired steel is SPENT (searchers dead or
 talked down): game days before the court swallows its pride and reopens
 negotiation - the ransom slate resets so a fresh demand can go out.}

; ── V2 Slice 3: captivity life ──
Float Property KIDNAP_GUARD_RADIUS     = 1000.0 AutoReadOnly
{A guard within this distance (same cell) keeps the captive from working
 their bonds. Guards: the player, the kidnapper, any registered follower,
 any Enterprises retainer (a hired jailer via Assign Work at the hold).}
Float Property KIDNAP_ESCAPE_ROLL_HOURS = 6.0 AutoReadOnly
{Unguarded game hours between escape rolls. Each time the accumulated
 unguarded clock advances this far past the last roll, one 5% roll fires.}
Int Property KIDNAP_ESCAPE_CHANCE      = 5 AutoReadOnly
{Escape chance (%) per KIDNAP_ESCAPE_ROLL_HOURS of unguarded time.}

SeverActions_Arrest Function GetArrestScript()
    Return (Self as Quest) as SeverActions_Arrest
EndFunction

SeverActions_Furniture Function GetFurnitureScript()
    Return (Self as Quest) as SeverActions_Furniture
EndFunction

Function KidnapMaintenance()
    {Load recovery: push the cosaved toggle into the native flag (the
     sever_kidnap_enabled decorator reads it; default false pre-push) and
     re-assert held captives' bound state immediately.
     No ModEvent registration here — SKSE keeps ONE callback per (form,
     event) and SeverActions_Travel owns SeverActions_TravelComplete for
     this quest; it forwards kidnap_* tags to HandleKidnapTravelComplete
     below. (A second RegisterForModEvent from this script was silently
     dead — the original shipped bug: kidnappers announced the job and
     never left, because leg-1 completion had no listener.)}
    SeverActionsNativeExt.Native_Kidnap_SetEnabled(EnableKidnapActions)
    SeverActionsNativeExt.Native_Restrain_SetEnabled(EnableRestrainAction)
    ; Guard-recall listener — needed whenever a kidnap (and so possibly a
    ; guarding kidnapper) is live. Same-pair re-registration is idempotent.
    Actor[] activeVictims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    If activeVictims && activeVictims.Length > 0
        RegisterForModEvent("SeverActions_FollowerCalledByPlayer", "OnKidnapGuardRecall")
        ; A restrain WALK-UP cannot survive a save boundary: the ArrivalMonitor
        ; registration is transient native state (never cosaved, so
        ; restrain_arrived can never fire post-load) and OrphanCleanup strips
        ; the un-re-registered approach LinkedRef ~5s after load. Nothing has
        ; happened to the target yet, so the clean answer is a quiet abort.
        Int avi = 0
        While avi < activeVictims.Length
            Actor av = activeVictims[avi]
            If av && SeverActionsNativeExt.Native_Kidnap_GetPhase(av) == 1 \
                && SeverActionsNativeExt.Native_Kidnap_GetFlag(av, KIDNAP_FLAG_RESTRAINT) \
                && SeverActionsNativeExt.Native_Kidnap_GetDestLabel(av) == ""
                _AbortRestrainApproach(av)
            EndIf
            avi += 1
        EndWhile
    EndIf
    SweepCaptiveAliasesOnLoad()  ; alias pool <-> KidnapStore reconciliation
    KidnapTick(true)  ; load pass — re-pose standing-bound restraint captives
EndFunction

; ── Captive-hold alias pool (KDNP v6) ──

Quest Function GetCaptiveQuest()
    {Lazy-resolve the captive-hold alias quest (the EnsureSchedQuests pattern:
     never ESP properties, always GetFormFromFile). None while the ESP
     predates the pool — the kneel hold then runs on the priority-95
     override exactly as before. Retried on each call until it resolves.}
    If _captiveQuestResolved
        Return _captiveQuest
    EndIf
    _captiveQuest = Game.GetFormFromFile(CAPTIVE_QUEST_FORMID, "SeverActions.esp") as Quest
    If !_captiveQuest
        Debug.Trace("[SeverActions] CAPTIVE ALIAS POOL UNAVAILABLE — SeverActions_CaptiveQuest failed to resolve from SeverActions.esp (outdated ESP?). Alias-held captivity disabled; the priority-95 override remains the hold.")
        Return None
    EndIf
    _captiveQuestResolved = true
    Return _captiveQuest
EndFunction

ReferenceAlias Function GetCaptiveAlias(Int aiIndex)
    If aiIndex < 0 || aiIndex >= CAPTIVE_ALIAS_POOL_SIZE
        Return None
    EndIf
    Quest q = GetCaptiveQuest()
    If !q
        Return None
    EndIf
    Return q.GetNthAlias(aiIndex) as ReferenceAlias
EndFunction

Int Function FindFreeCaptiveAlias()
    {Rotating-cursor scan for an unoccupied captive alias (the
     FindFreeSchedAlias pattern). -1 = pool exhausted (or pool unavailable).}
    Quest q = GetCaptiveQuest()
    If !q
        Return -1
    EndIf
    Int n = 0
    While n < CAPTIVE_ALIAS_POOL_SIZE
        Int idx = _captiveCursor + n
        If idx >= CAPTIVE_ALIAS_POOL_SIZE
            idx -= CAPTIVE_ALIAS_POOL_SIZE
        EndIf
        ReferenceAlias al = q.GetNthAlias(idx) as ReferenceAlias
        If al && al.GetReference() == None
            _captiveCursor = idx + 1
            If _captiveCursor >= CAPTIVE_ALIAS_POOL_SIZE
                _captiveCursor = 0
            EndIf
            Return idx
        EndIf
        n += 1
    EndWhile
    Return -1
EndFunction

Function _FreeCaptiveAlias(Actor akVictim)
    {Release the captive-hold alias (if any) and drop the cosaved index
     (the EmptySchedAlias fast path: index verify only, no pool scan).
     Idempotent — safe no-op when the victim holds no alias. Does NOT call
     EvaluatePackage; the caller's teardown batches that.}
    If !akVictim
        Return
    EndIf
    Int idx = SeverActionsNativeExt.Native_Kidnap_GetAliasIndex(akVictim)
    If idx < 0
        Return
    EndIf
    ReferenceAlias al = GetCaptiveAlias(idx)
    If al && al.GetReference() == akVictim
        al.Clear()
    EndIf
    ; Index was stale (alias repurposed under us) — drop the bookkeeping
    ; either way; SweepCaptiveAliasesOnLoad owns cross-checking the pool.
    SeverActionsNativeExt.Native_Kidnap_SetAliasIndex(akVictim, -1)
    DebugMsg("CaptiveAlias: freed alias " + idx + " for " + akVictim.GetDisplayName())
EndFunction

Function SweepCaptiveAliasesOnLoad()
    {Load reconciliation for the captive-alias pool (the
     SweepSchedAliasesOnLoad pattern, shrunk to 16 slots): every held
     entry's recorded alias must still point at that victim; every filled
     pool slot must point at a live held KidnapStore entry. Drift is
     emptied + logged — the override hold carries any captive whose alias
     vanished until the next bind refills a slot.}
    Quest q = GetCaptiveQuest()
    If !q
        Return
    EndIf
    ; Pass 1 (pool side): an alias holding a deleted/disabled actor, or
    ; someone with no live HELD entry, gets emptied.
    Int i = 0
    While i < CAPTIVE_ALIAS_POOL_SIZE
        ReferenceAlias al = q.GetNthAlias(i) as ReferenceAlias
        If al
            Actor a = al.GetReference() as Actor
            If a
                If a.IsDeleted() || a.IsDisabled()
                    al.Clear()
                    Debug.Trace("[SeverActions_FollowerManager] CaptiveAlias: load sweep emptied alias " + i + " (deleted/disabled holder)")
                ElseIf SeverActionsNativeExt.Native_Kidnap_GetPhase(a) != 3
                    al.Clear()
                    Debug.Trace("[SeverActions_FollowerManager] CaptiveAlias: load sweep emptied alias " + i + " (no live held entry)")
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile
    ; Pass 2 (entry side): drop recorded indices whose alias no longer
    ; points at the victim.
    Actor[] victims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    If !victims
        Return
    EndIf
    Int vi = 0
    While vi < victims.Length
        Actor v = victims[vi]
        If v
            Int idx = SeverActionsNativeExt.Native_Kidnap_GetAliasIndex(v)
            If idx >= 0
                ReferenceAlias held = GetCaptiveAlias(idx)
                If !held || held.GetReference() != v
                    SeverActionsNativeExt.Native_Kidnap_SetAliasIndex(v, -1)
                    Debug.Trace("[SeverActions_FollowerManager] CaptiveAlias: load sweep dropped stale index " + idx + " for " + v.GetDisplayName())
                EndIf
            EndIf
        EndIf
        vi += 1
    EndWhile
    DebugMsg("CaptiveAlias: load sweep complete")
EndFunction

Function KidnapTick(Bool abFromLoad = false)
    {Re-assert held captives' bound state — restraint and idles don't
     reliably survive 3D reloads. Runs every ~30s off OnUpdate (abFromLoad
     false) and once on load via KidnapMaintenance (abFromLoad true; only
     the load pass re-plays the standing-bound idle, to avoid a per-tick
     animation twitch). Also HEALS legacy captives bound by the removed furniture-sandbox
     treatment: strips the sandbox override + furniture LinkedRef and
     deletes the placed marker (that combo CTD'd on cell attach). Cheap —
     usually zero or one victim.}
    Actor[] victims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    If !victims || victims.Length == 0
        Return
    EndIf
    SeverActions_Furniture furn = GetFurnitureScript()
    Float kidnapNowGT = Utility.GetCurrentGameTime()
    ; >= 1 game hour between 30s-real ticks = a wait/sleep/fast-travel skip.
    Bool kidnapTimeJumped = KidnapLastTickGT > 0.0 && (kidnapNowGT - KidnapLastTickGT) >= 0.042
    KidnapLastTickGT = kidnapNowGT
    Int i = 0
    While i < victims.Length
        Actor v = victims[i]
        Int phase = 0
        If v && v.IsDead()
            ; Slice 3: death in captivity IS murder — consequence + cleanup
            ; (the entry used to just linger for a dead victim).
            _OnCaptiveDied(v)
        ElseIf v
            phase = SeverActionsNativeExt.Native_Kidnap_GetPhase(v)
        EndIf

        ; A SkyrimNet package registered on a bound captive mid-captivity
        ; (the LLM can re-issue its OWN StartFollow - our is_kidnap_victim
        ; gate only covers SA actions) rides the eval hook and outranks the
        ; entire hold. Strip it every tick; seizure cleared the stack once.
        If phase >= 2 && (SkyrimNetApi.HasPackage(v, "FollowPlayer") > 0 || SkyrimNetApi.HasPackage(v, "TalkToPlayer") > 0)
            ; TalkToPlayer lands from SkyrimNet's own dialogue controller the
            ; moment anyone TALKS to the captive (interrogation is a designed
            ; flow) - its eval hook outranks the hold, stood a bound captive
            ; up, and walked him off after the player. Clear the whole
            ; SkyrimNet stack; the sit package / pin re-asserts on re-eval.
            SkyrimNetApi.ClearAllPackages(v)
            SkyrimNetApi.CancelPendingPackageTasks(v)
            v.EvaluatePackage()
        EndIf

        If phase == 3
            ; Legacy heals — safe no-ops on new binds: the CTD build's
            ; sandbox-on-furniture package, and the restrained/DontMove build's
            ; movement pins (which blocked walking to the marker).
            If furn && furn.SeverActions_UseFurniturePackage
                ActorUtil.RemovePackageOverride(v, furn.SeverActions_UseFurniturePackage)
            EndIf

            ; v2 marker heal: pre-persistence markers UNLOAD with their cell
            ; and the Sit package CTDs in low process (crash 18-56-33).
            ; Immediately strip the hold from any pre-v2 captive — safe
            ; beats seated — then re-bind fresh once they're loaded.
            If SeverActionsNativeExt.Native_Kidnap_GetMarkerSchema(v) < 2
                Package sitPkgHeal = Game.GetFormFromFile(KIDNAP_SIT_PKG_FORMID, "SeverActions.esp") as Package
                If sitPkgHeal
                    ActorUtil.RemovePackageOverride(v, sitPkgHeal)
                EndIf
                If furn && furn.SeverActions_FurnitureTargetKeyword
                    SeverActionsNative.LinkedRef_Clear(v, furn.SeverActions_FurnitureTargetKeyword)
                EndIf
                ObjectReference oldMarker = SeverActionsNativeExt.Native_Kidnap_GetMarker(v)
                If oldMarker
                    oldMarker.Disable()
                    oldMarker.Delete()
                    SeverActionsNativeExt.Native_Kidnap_SetHeld(v, None)
                EndIf
                If v.Is3DLoaded()
                    Actor healKd = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(v)
                    If healKd
                        Debug.Trace("[SeverActions_FollowerManager] Kidnap: v2 marker heal - re-binding " + v.GetDisplayName())
                        _BindCaptive(v, healKd)
                    EndIf
                EndIf
                ; Not loaded: stays phase-3 hooded but packageless (no CTD
                ; surface); this branch retries every tick until loaded.

            ElseIf v.Is3DLoaded()
                If SeverActionsNativeExt.Native_Kidnap_GetFlag(v, KIDNAP_FLAG_LEASHED)
                    ; LEASHED: bound but walking behind a leader. The
                    ; escort-follow package does the moving; never pin. If the
                    ; leader is gone (dead / unloaded for good), fall back to a
                    ; pin where they stand.
                    v.SetDontMove(false)
                    Actor leashLd = StorageUtil.GetFormValue(v, "SeverKidnap_LeashLeader") as Actor
                    If !leashLd || leashLd.IsDead()
                        UnleashCaptive(v)
                    Else
                        ; Bound-at-rest (2026-08-23 user ask): there is NO
                        ; vanilla bound-WALK idle - the hands-behind-back look
                        ; is a behavior-graph state the follow package cancels
                        ; the instant it issues a walk. So re-assert the bound
                        ; standing idle whenever they are STOPPED; the walk
                        ; naturally drops it again when they set off after the
                        ; leader. Cuffs (still equipped) carry the bound read
                        ; while moving. Posed flag reused so we only fire the
                        ; idle on the moving->stopped edge, never every tick
                        ; (which would twitch it).
                        SeverActions_Arrest arrestLsh = GetArrestScript()
                        Float leashSpd = v.GetAnimationVariableFloat("Speed")
                        If leashSpd < 5.0
                            If StorageUtil.GetIntValue(v, "SeverRestrain_Posed", 0) == 0                                 && arrestLsh && arrestLsh.OffsetBoundStandingStart
                                If v.PlayIdle(arrestLsh.OffsetBoundStandingStart)
                                    StorageUtil.SetIntValue(v, "SeverRestrain_Posed", 1)
                                EndIf
                            EndIf
                        Else
                            ; Moving: clear the flag so the next stop re-poses,
                            ; and let the walk own the animation.
                            StorageUtil.SetIntValue(v, "SeverRestrain_Posed", 0)
                        EndIf
                    EndIf
                ElseIf SeverActionsNativeExt.Native_Kidnap_GetFlag(v, KIDNAP_FLAG_UNBOUND)
                    ; Loose captivity (UntieCaptive): no pin, no furniture -
                    ; the hold-anchored sandbox does the holding. Keep them
                    ; unrestrained; the guard/escape machinery below runs.
                    v.SetRestrained(false)
                    v.SetDontMove(false)
                ElseIf SeverActionsNativeExt.Native_Kidnap_GetFlag(v, KIDNAP_FLAG_RESTRAINT)
                    ; Standing-bound restraint hold: keep them pinned every
                    ; tick (idempotent, no visual). The bound offset idle does
                    ; NOT survive a 3D reload (cell unload/reload, save/load),
                    ; so re-play it on the unloaded->loaded EDGE, tracked by a
                    ; per-victim posed flag: cleared whenever the tick sees
                    ; them unloaded (below) and on the load pass (idles never
                    ; survive a reload even if the flag was saved as set).
                    ; Re-playing every tick would twitch the animation.
                    ; PROXIMITY GATE: a relocated captive can still be walking
                    ; in behind the escort when the bind fires (trailing
                    ; deferral in _BindCaptive) — pinning them mid-walk
                    ; strands them short of the hold, so only pin at the
                    ; marker; until then let the kept escort-follow package
                    ; close the gap, with a snap after ~4 ticks as the
                    ; pathing-failure backstop.
                    ObjectReference pinM = SeverActionsNativeExt.Native_Kidnap_GetMarker(v)
                    Bool atHold = !pinM || (v.GetParentCell() == pinM.GetParentCell() && v.GetDistance(pinM) <= 300.0)
                    If !atHold && StorageUtil.GetIntValue(v, "SeverRestrain_TrailTicks", 0) >= 4
                        v.MoveTo(pinM)
                        atHold = true
                    EndIf
                    If atHold
                        StorageUtil.UnsetIntValue(v, "SeverRestrain_TrailTicks")
                        SeverActions_Arrest arrestHeal = GetArrestScript()
                        ; Finish what a trailing bind deferred: strip the
                        ; escort-follow remnant (idempotent), then pin.
                        If arrestHeal && arrestHeal.SeverActions_FollowGuard_Prisoner
                            ActorUtil.RemovePackageOverride(v, arrestHeal.SeverActions_FollowGuard_Prisoner)
                        EndIf
                        If arrestHeal && arrestHeal.SeverActions_FollowTargetKW
                            SeverActionsNative.LinkedRef_Clear(v, arrestHeal.SeverActions_FollowTargetKW)
                        EndIf
                        v.SetDontMove(true)
                        If abFromLoad
                            StorageUtil.SetIntValue(v, "SeverRestrain_Posed", 0)
                        EndIf
                        If StorageUtil.GetIntValue(v, "SeverRestrain_Posed", 0) == 0
                            If arrestHeal && arrestHeal.OffsetBoundStandingStart
                                If v.PlayIdle(arrestHeal.OffsetBoundStandingStart)
                                    StorageUtil.SetIntValue(v, "SeverRestrain_Posed", 1)
                                EndIf
                            EndIf
                        EndIf
                    Else
                        StorageUtil.SetIntValue(v, "SeverRestrain_TrailTicks", StorageUtil.GetIntValue(v, "SeverRestrain_TrailTicks", 0) + 1)
                    EndIf
                Else
                    v.SetRestrained(false)
                    v.SetDontMove(false)
                    ; The furniture-driven hold: if they're not seated on the
                    ; bound marker, nudge the AI back onto it (packages re-seat
                    ; furniture automatically — this covers post-load hiccups).
                    If v.GetSitState() == 0
                        v.EvaluatePackage()
                    EndIf
                EndIf
            ElseIf SeverActionsNativeExt.Native_Kidnap_GetFlag(v, KIDNAP_FLAG_RESTRAINT)
                ; Unloaded restraint captive: their 3D (and the offset idle)
                ; is gone — arm the re-pose for when they load back in.
                StorageUtil.SetIntValue(v, "SeverRestrain_Posed", 0)
            EndIf

            ; (The restrain approach watchdog lives in the phase == 1 branch
            ; below.)

            ; Guard-on-station heal: something can move an on-duty guard off
            ; the hold (observed: guard ended up OUTSIDE Tundra Homestead
            ; while the captive sat bound inside - engine teammate drag on
            ; fast travel and anchorless-sandbox door leaks are both
            ; suspects). While the on-guard flag is set and the guard is off
            ; the hold cell AND unloaded, re-post them to the marker
            ; (never a visible teleport).
            ; Captive-on-hold heal (mirror of the guard heal below): if the
            ; captive ended up outside the hold cell - a TalkToPlayer window
            ; between ticks could walk them out after the player - re-post
            ; them to the marker once unloaded (never a visible teleport);
            ; the sit package / standing pin re-takes them on re-eval.
            ObjectReference holdHealM = SeverActionsNativeExt.Native_Kidnap_GetMarker(v)
            If holdHealM && !v.Is3DLoaded() && v.GetParentCell() != holdHealM.GetParentCell()
                Debug.Trace("[SeverActions_FollowerManager] Kidnap: captive " + v.GetDisplayName() + " off the hold - re-posting to the marker")
                v.MoveTo(holdHealM)
                v.EvaluatePackage()
            EndIf

            Actor guardKd = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(v)
            If guardKd && !guardKd.IsDead() \
                && StorageUtil.GetIntValue(guardKd, "SeverKidnap_OnGuard", 0) == 1
                ObjectReference stationM = SeverActionsNativeExt.Native_Kidnap_GetMarker(v)
                If stationM && guardKd.GetParentCell() != stationM.GetParentCell() \
                    && !guardKd.Is3DLoaded()
                    Debug.Trace("[SeverActions_FollowerManager] Kidnap: guard " + guardKd.GetDisplayName() + " off station - re-posting to the hold")
                    guardKd.MoveTo(stationM)
                    guardKd.EvaluatePackage()
                EndIf
            EndIf

            ; ── V2 Slice 2: pending ransom comes due ──
            Int rState = SeverActionsNativeExt.Native_Kidnap_GetRansomState(v)
            If rState == KIDNAP_RANSOM_PENDING \
                && Utility.GetCurrentGameTime() - SeverActionsNativeExt.Native_Kidnap_GetRansomTime(v) >= KIDNAP_RANSOM_RESOLVE_DAYS
                _ResolveRansom(v)
                rState = SeverActionsNativeExt.Native_Kidnap_GetRansomState(v)
            EndIf

            ; ── V2 Slice 1 consequences (one-shot flags, cheap guards) ──
            Float grabT = SeverActionsNativeExt.Native_Kidnap_GetGrabTime(v)
            If grabT > 0.0
                Float heldDays = Utility.GetCurrentGameTime() - grabT
                ; Disappearance gossip: after ~2 game days the victim's home
                ; hold starts talking (same rumor pool the 0185 gossip prompt
                ; reads — hold-scoped, listener needs to be in that location).
                If heldDays >= KIDNAP_GOSSIP_DAYS && !SeverActionsNativeExt.Native_Kidnap_GetFlag(v, KIDNAP_FLAG_GOSSIP)
                    SeverActionsNativeExt.Native_Kidnap_SetFlag(v, KIDNAP_FLAG_GOSSIP, true)
                    String vHold = SeverActionsNativeExt.Hold_GetHoldName(v)
                    If vHold != ""
                        AppendGossip(vHold, v.GetDisplayName() + " has vanished without a trace - no one has seen them for days, and people are starting to ask questions")
                        Debug.Trace("[SeverActions_FollowerManager] Kidnap: disappearance gossip fired in " + vHold)
                    EndIf
                EndIf
                ; Search party: a long-held PROMINENT victim (someone a hold
                ; would miss = has a home-hold crime faction) gets tracked to
                ; the hold site. Fires only while the player is AT the site
                ; (the standoff spawns around the player); the native gates
                ; the ambush master toggle + global cooldown + player state.
                ; Ransom fast-tracks it: a REFUSAL means they chose steel over
                ; coin, and a PAID ransom whose captive is still held past the
                ; grace window means the bargain was broken — both arm the
                ; searchers immediately, no 4-day wait.
                Bool searchDue = heldDays >= KIDNAP_SEARCH_DAYS
                If !searchDue
                    If rState == KIDNAP_RANSOM_REFUSED
                        searchDue = true
                    ElseIf rState == KIDNAP_RANSOM_PAID
                        searchDue = Utility.GetCurrentGameTime() - SeverActionsNativeExt.Native_Kidnap_GetRansomTime(v) \
                            >= KIDNAP_RANSOM_RESOLVE_DAYS + KIDNAP_RANSOM_GRACE_DAYS
                    EndIf
                EndIf
                If searchDue && !SeverActionsNativeExt.Native_Kidnap_GetFlag(v, KIDNAP_FLAG_SEARCH)
                    If SeverActionsNativeExt.Native_Kidnap_GetGrabFaction(v)
                        ObjectReference holdSite = SeverActionsNativeExt.Native_Kidnap_GetMarker(v)
                        If holdSite && Game.GetPlayer().GetParentCell() == holdSite.GetParentCell()
                            If SeverActionsNativeExt2.Venture_FireKidnapSearch(v)
                                SeverActionsNativeExt.Native_Kidnap_SetFlag(v, KIDNAP_FLAG_SEARCH, true)
                                Debug.Trace("[SeverActions_FollowerManager] Kidnap: search party fired for " + v.GetDisplayName())
                            EndIf
                        EndIf
                    EndIf
                EndIf
                ; Give-up-and-negotiate (user request): a refused ransom must
                ; not dead-end once the hold's steel is SPENT (Travel stamps
                ; the searchers' fight/stand-down; a refusal AFTER the party
                ; already came stamps it inside _ResolveRansom). The court
                ; waits out the reopen window, swallows its pride, and writes
                ; that it will hear terms again - the ransom slate resets so
                ; a fresh demand can go out, priced with the desperation
                ; premium (their blades already failed them once).
                If rState == KIDNAP_RANSOM_REFUSED
                    Float steelSpentGT = StorageUtil.GetFloatValue(v, "SA_KidnapSteelSpentGT", 0.0)
                    If steelSpentGT > 0.0 && Utility.GetCurrentGameTime() - steelSpentGT >= KIDNAP_RANSOM_REOPEN_DAYS
                        StorageUtil.UnsetFloatValue(v, "SA_KidnapSteelSpentGT")
                        Actor roSteward = _GetHoldSteward(SeverActionsNativeExt.Native_Kidnap_GetGrabFaction(v))
                        String roStewardName = ""
                        If roSteward
                            roStewardName = roSteward.GetDisplayName()
                        EndIf
                        String roHold = SeverActionsNativeExt.Hold_GetHoldName(v)
                        If roHold == ""
                            roHold = "The captive's people"
                        EndIf
                        ; Cut-losses roll (user request): before crawling back
                        ; to the table, the court weighs what the captive is
                        ; WORTH to the hold. Degaine gets written off; the
                        ; Jarl's own almost never are. Same standing signals
                        ; as the pay odds, condensed.
                        Int abandonChance = 30
                        Faction roFacJarl      = Game.GetFormFromFile(0x00050920, "Skyrim.esm") as Faction
                        Faction roFacSteward   = Game.GetFormFromFile(0x00050922, "Skyrim.esm") as Faction
                        Faction roFacMerchant  = Game.GetFormFromFile(0x00051596, "Skyrim.esm") as Faction
                        Faction roFacInnkeeper = Game.GetFormFromFile(0x0005091B, "Skyrim.esm") as Faction
                        Faction roFacBeggar    = Game.GetFormFromFile(0x00060028, "Skyrim.esm") as Faction
                        Faction roFacDrunk     = Game.GetFormFromFile(0x00060027, "Skyrim.esm") as Faction
                        If (roFacJarl && v.IsInFaction(roFacJarl)) || (roFacSteward && v.IsInFaction(roFacSteward))
                            abandonChance -= 25
                        ElseIf (roFacMerchant && v.IsInFaction(roFacMerchant)) || (roFacInnkeeper && v.IsInFaction(roFacInnkeeper))
                            abandonChance -= 10
                        EndIf
                        If (roFacBeggar && v.IsInFaction(roFacBeggar)) || (roFacDrunk && v.IsInFaction(roFacDrunk))
                            abandonChance += 45
                        EndIf
                        ActorBase roBase = v.GetActorBase()
                        If roBase && roBase.IsEssential()
                            abandonChance -= 15
                        EndIf
                        If abandonChance < 5
                            abandonChance = 5
                        ElseIf abandonChance > 85
                            abandonChance = 85
                        EndIf
                        If Utility.RandomInt(0, 99) < abandonChance
                            ; WRITTEN OFF: the hold spends nothing more - no
                            ; coin, no steel. State stays REFUSED (no fresh
                            ; demand possible) and the spent clock is consumed,
                            ; so this fires exactly once. The captive still
                            ; escapes, still costs a bounty - they are simply
                            ; worthless as ransom stock now.
                            SeverActionsNativeExt.Native_Kidnap_RequestRansomReopenLetter(v, roStewardName, true)
                            If roSteward
                                SeverActionsNative.Native_AddMemory(roSteward, \
                                    "I closed the matter of " + v.GetDisplayName() + " - the hold has spent blades enough, and I will not bleed the treasury for them. I signed it, and I will carry it: we left one of our own in a captor's hands.", \
                                    0.8, "EXPERIENCE", "grim", "", "[\"ransom\"]", "[]")
                            EndIf
                            SkyrimNetApi.RegisterPersistentEvent( \
                                roHold + " has cut its losses: their court has written that no ransom will be paid and no more blades hired for " + v.GetDisplayName() + ". The hold has washed its hands of the matter.", \
                                Game.GetPlayer(), v)
                            Debug.Notification(roHold + " cuts their losses - no ransom will ever come for " + v.GetDisplayName() + ".")
                            Debug.Trace("[SeverActions_FollowerManager] Kidnap: ransom WRITTEN OFF for " + v.GetDisplayName() + " (abandonChance=" + abandonChance + ")")
                        Else
                            ; SA_KidnapSteelFailed stays set - the next resolve
                            ; prices in that force already failed them.
                            SeverActionsNativeExt.Native_Kidnap_SetRansomState(v, 0)
                            SeverActionsNativeExt.Native_Kidnap_RequestRansomReopenLetter(v, roStewardName)
                            If roSteward
                                SeverActionsNative.Native_AddMemory(roSteward, \
                                    "The blades I hired to bring " + v.GetDisplayName() + " home availed us nothing. I have written that the hold will hear ransom terms after all - it cost me my pride to sign it, but pride does not bring people home.", \
                                    0.8, "EXPERIENCE", "resigned", "", "[\"ransom\"]", "[]")
                            EndIf
                            SkyrimNetApi.RegisterPersistentEvent( \
                                roHold + "'s attempt to reclaim " + v.GetDisplayName() + " by force has failed, and their court has written that they will hear ransom terms again. A new demand can be sent.", \
                                Game.GetPlayer(), v)
                            Debug.Notification(roHold + " gives up on steel - they will hear ransom terms for " + v.GetDisplayName() + " again.")
                            Debug.Trace("[SeverActions_FollowerManager] Kidnap: ransom negotiation REOPENED for " + v.GetDisplayName())
                        EndIf
                    EndIf
                EndIf
            EndIf

            ; ── Slice 3: escape watch — LAST in the held branch, it can
            ; clear the entry. A captive nobody is watching works their
            ; bonds loose. Guards: the player, the kidnapper on station,
            ; any follower, any Enterprises retainer (a hired jailer via
            ; Assign Work covers work hours — an overnight gap stays under
            ; the threshold and resets when they return).
            ; Roll cadence: 5% per 6 UNGUARDED game hours (anchor-tracked),
            ; not per 30s tick — the old per-tick roll made escape near-
            ; certain within minutes once eligible.
            Bool kdGuarded = _IsCaptiveGuarded(v)
            Float unguardedH = SeverActionsNativeExt.Native_Kidnap_TickUnguarded(v, kdGuarded, Utility.GetCurrentGameTime())
            If kdGuarded
                ; Guard resets the native unguarded clock — reset the roll
                ; anchor too so the next lapse starts a fresh 6h count.
                StorageUtil.SetFloatValue(v, "SeverKidnap_EscAnchor", 0.0)
            Else
                Float escAnchor = StorageUtil.GetFloatValue(v, "SeverKidnap_EscAnchor", 0.0)
                If unguardedH >= escAnchor + KIDNAP_ESCAPE_ROLL_HOURS
                    Int escChance = KIDNAP_ESCAPE_CHANCE
                    If SeverActionsNativeExt.Native_Kidnap_GetFlag(v, KIDNAP_FLAG_UNBOUND)
                        escChance += KIDNAP_ESCAPE_CHANCE  ; untied: no bonds to work loose - twice the odds
                    EndIf
                    StorageUtil.SetFloatValue(v, "SeverKidnap_EscAnchor", unguardedH)
                    If Utility.RandomInt(0, 99) < escChance
                        _EscapeCaptive(v)
                    EndIf
                EndIf
            EndIf

        ElseIf phase == 1
            ; ── Restrain approach (same-scene walk-up, no destination) ──
            ; Arrival belongs EXCLUSIVELY to ArrivalMonitor -> restrain_arrived
            ; -> HandleRestrainArrived; the tick runs only the deadline
            ; watchdog. Without this gate the kidnap grab logic below hijacked
            ; the walk-up on the first tick in any interior (grabArrived is
            ; instantly true same-cell): it stamped grab info + could charge
            ; the witnessed-kidnapping bounty for an explicitly no-crime
            ; action, MoveTo-yanked the victim, and orphaned the restrainer's
            ; approach package. A restrained captive being MOVED still uses
            ; the kidnap transport machinery in the Else (MoveCaptive sets a
            ; real destination) — discriminate on destLabel.
            If SeverActionsNativeExt.Native_Kidnap_GetFlag(v, KIDNAP_FLAG_RESTRAINT) \
                && SeverActionsNativeExt.Native_Kidnap_GetDestLabel(v) == ""
                ; Watchdog: a walk-up that never arrives (pathing failure,
                ; target zoned away, combat) would leave the restrainer
                ; following the target forever. Past the deadline, unwind.
                Float restrainDl = SeverActionsNativeExt.Native_Kidnap_GetLegDeadline(v)
                If restrainDl > 0.0 && Utility.GetCurrentGameTime() > restrainDl
                    _AbortRestrainApproach(v)
                EndIf
            Else
                Actor kdnp = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(v)
                If kdnp && !kdnp.IsDead()
                    ; IntelEngine's arrival rule: reaching the victim's INTERIOR
                    ; cell counts as arrived; same-cell within 300u covers
                    ; exteriors and watched approaches.
                    Cell kCell = kdnp.GetParentCell()
                    Bool grabArrived = false
                    If kCell && kCell == v.GetParentCell()
                        grabArrived = kCell.IsInterior() || kdnp.GetDistance(v) <= 300.0
                    EndIf
                    If grabArrived
                        Debug.Trace("[SeverActions_FollowerManager] Kidnap: kidnapper reached the victim - grab resolves")
                        _OnKidnapGrabResolved(kdnp)
                    Else
                        _KidnapLegWatchdog(kdnp, v, v, kidnapTimeJumped)
                    EndIf
                Else
                    ; Kidnapper DEAD (or unresolvable after load) mid-approach:
                    ; no other path cleans this up — the entry wedged forever
                    ; and, in alias mode, held the borrowed arrest dispatch
                    ; aliases hostage. Nothing has happened to the victim at
                    ; phase 1, so unwind quietly.
                    _AbortKidnapForVictim(v, kdnp)
                EndIf
            EndIf

        ElseIf phase == 2
            Actor kdnp2 = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(v)
            If kdnp2 && !kdnp2.IsDead()
                ObjectReference destRef = SeverActionsNativeExt.Native_Kidnap_GetDestAnchor(v)
                ; No destination anchor at all (KidnapStore::Load degrades an
                ; unresolvable destAnchorID to 0 while phase/aliasMode survive;
                ; runtime binds-in-place guard this, the post-load state did
                ; not): the march can never "arrive" — atDest stays false and
                ; the alias watchdog early-returns on a None goal BEFORE its
                ; deadline check, hanging the leg forever. Bind in place:
                ; _OnKidnapTransportResolved's destMarker=None path already
                ; handles anchor-less binds.
                If !destRef
                    ; (No Return here — this runs inside the per-victim loop.)
                    Debug.Trace("[SeverActions_FollowerManager] Kidnap: transport has no destination anchor - binding in place")
                    _OnKidnapTransportResolved(kdnp2, "arrived")
                Else
                    Bool atDest = false
                    If kdnp2.GetParentCell() == destRef.GetParentCell()
                        atDest = kdnp2.GetParentCell().IsInterior() || kdnp2.GetDistance(destRef) <= 400.0
                    EndIf
                    If atDest
                        Debug.Trace("[SeverActions_FollowerManager] Kidnap: kidnapper reached the destination - binding")
                        _OnKidnapTransportResolved(kdnp2, "arrived")
                    ElseIf SeverActionsNativeExt.Native_Kidnap_GetAliasMode(v)
                        _KidnapLegWatchdog(kdnp2, v, destRef, kidnapTimeJumped)
                    Else
                        ; Slot-fallback transport — poll the slot flow's state.
                        String travelSt = StorageUtil.GetStringValue(kdnp2, "SeverTravel_State", "")
                        If travelSt == "waiting" || travelSt == "complete"
                            Debug.Trace("[SeverActions_FollowerManager] Kidnap: slot travel state '" + travelSt + "' - binding")
                            _OnKidnapTransportResolved(kdnp2, "arrived")
                        ElseIf travelSt == "timeout"
                            _OnKidnapTransportResolved(kdnp2, "timedout")
                        ElseIf travelSt == ""
                            If SeverActionsNativeExt.Native_Kidnap_BumpNoTravelStrikes(v, false) >= 2
                                SeverActionsNativeExt.Native_Kidnap_BumpNoTravelStrikes(v, true)
                                Debug.Trace("[SeverActions_FollowerManager] Kidnap: slot travel state lost - aborting kidnap")
                                _AbortKidnap(kdnp2)
                            EndIf
                        Else
                            SeverActionsNativeExt.Native_Kidnap_BumpNoTravelStrikes(v, true)
                        EndIf
                    EndIf
                EndIf
            Else
                ; Kidnapper DEAD (or unresolvable) mid-transport: the seized
                ; victim walks free — with consequences, since they were
                ; taken (phase >= 2). Mirrors _AbortKidnap keyed off the
                ; victim; a dead captor cannot narrate an abort.
                _AbortKidnapForVictim(v, kdnp2)
            EndIf
        EndIf
        i += 1
    EndWhile
EndFunction

Function KidnapNPC(Actor akKidnapper, String targetName, String destination)
    {A follower abducts a named NPC and delivers them, bound and hooded, to a
     destination of the player's choosing. Called by SkyrimNet via
     kidnapnpc.yaml. Opt-in via EnableKidnapActions (MCM / PrismaUI Settings).}
    If !akKidnapper || akKidnapper.IsDead()
        Return
    EndIf
    If !EnableKidnapActions
        ; Explicit feedback — both the SkyrimNet path (eligibility should
        ; already gate this) and the Prisma Actions page land here, and a
        ; silent no-op reads as "the button is broken".
        Debug.Notification("Kidnap actions are disabled (Settings > Behavior > Enable Kidnap Actions).")
        Return
    EndIf
    If _RejectIfBoundActor(akKidnapper, "abduct anyone")
        Return
    EndIf
    If _RejectIfActorOccupied(akKidnapper, "abduct anyone")
        Return
    EndIf

    ; Resolve the victim by name — global form-table scan so a specific
    ; OFF-SCREEN NPC resolves too (unique refs stay in memory unloaded).
    Actor victim = SeverActionsNativeExt.Native_Kidnap_FindActorByName(targetName)
    If !victim
        SkyrimNetApi.RegisterEvent("kidnap_failed", \
            akKidnapper.GetDisplayName() + " could not find anyone called " + targetName + " to abduct.", \
            akKidnapper, None)
        Return
    EndIf
    If victim == akKidnapper || victim == Game.GetPlayer()
        Return
    EndIf
    If IsRegisteredFollower(victim)
        SkyrimNetApi.RegisterEvent("kidnap_failed", \
            akKidnapper.GetDisplayName() + " will not abduct one of " + Game.GetPlayer().GetDisplayName() + "'s own companions.", \
            akKidnapper, None)
        Return
    EndIf
    If SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) != 0
        Return  ; already being kidnapped
    EndIf
    If _RejectInvalidCaptiveTarget(akKidnapper, victim, "abduct")
        Return
    EndIf

    ; Destination through the travel system's resolver (same names the
    ; TravelToPlace action accepts — cities, homes, known interiors).
    SeverActions_Travel travel = GetTravelScript()
    If !travel
        Return
    EndIf
    ObjectReference destMarker = travel.ResolvePlace(akKidnapper, destination)
    If !destMarker
        SkyrimNetApi.RegisterEvent("kidnap_failed", \
            akKidnapper.GetDisplayName() + " does not know how to reach " + destination + ".", \
            akKidnapper, None)
        Return
    EndIf
    ; Door destination → follow through to the interior marker and unlock it
    ; so AI pathing isn't blocked (mirrors TravelToPlace's slot flow).
    If destMarker.GetBaseObject().GetType() == 29
        ; Unlock the DOOR itself BEFORE swapping to the interior marker
        ; (audit: the unlock used to run after the reassignment and targeted
        ; the interior marker, so a locked door stayed shut and pathing
        ; stalled until the off-screen watchdog).
        If destMarker.IsLocked()
            destMarker.Lock(false)
        EndIf
        ObjectReference interiorMarker = SeverActionsNative.FindInteriorMarkerForDoor(destMarker)
        If interiorMarker != None
            destMarker = interiorMarker
        EndIf
    EndIf

    ; Essential NPCs CAN be kidnapped (user decision) — but surface the
    ; save-your-quests warning once at order time.
    ActorBase vBase = victim.GetActorBase()
    If vBase && vBase.IsEssential()
        Debug.Notification(victim.GetDisplayName() + " is quest-protected. Holding them captive may break their quest content.")
    EndIf

    ; Track state — the per-victim entry state lives in KidnapStore ('KDNP' v2)
    ; now (V2 Slice 0 hardening); a few SeverKidnap_* StorageUtil keys remain
    ; for transient per-actor markers (EscAnchor / MovePin / OnGuard / LeashLeader).
    If !SeverActionsNativeExt.Native_Kidnap_BeginIfFree(victim, akKidnapper, destination, false)
        Return  ; victim claimed by a concurrent action, or this kidnapper already has a job
    EndIf
    ; Steel bookkeeping is per-CAPTIVITY - a stale flag from a previous
    ; kidnapping of this same NPC must not pre-arm the reopen clock or the
    ; desperation premium.
    StorageUtil.UnsetFloatValue(victim, "SA_KidnapSteelSpentGT")
    StorageUtil.UnsetIntValue(victim, "SA_KidnapSteelFailed")
    SeverActionsNativeExt.Native_Kidnap_SetDestAnchor(victim, destMarker)
    Debug.Trace("[SeverActions_FollowerManager] Kidnap: leg 1 begins - " + akKidnapper.GetDisplayName() + " -> " + victim.GetDisplayName() + " (dest '" + destination + "')")

    _LaunchGrabLeg(akKidnapper, victim, destination, travel)

    ; Mid-job recall handling: player calling the kidnapper binds the victim
    ; on the spot (see OnKidnapGuardRecall).
    RegisterForModEvent("SeverActions_FollowerCalledByPlayer", "OnKidnapGuardRecall")

    SkyrimNetApi.RegisterPersistentEvent( \
        akKidnapper.GetDisplayName() + " sets out to quietly abduct " + victim.GetDisplayName() + " and bring them to " + destination + ".", \
        akKidnapper, Game.GetPlayer())
    Debug.Notification(akKidnapper.GetDisplayName() + " sets out to abduct " + victim.GetDisplayName())
EndFunction

Function _LaunchGrabLeg(Actor akKidnapper, Actor victim, String destination, SeverActions_Travel travel)
    {Leg 1 — BORROW THE ARREST DISPATCH APPARATUS (user design): fill the
     dispatch aliases so BOTH actors stay high-process while unloaded, and
     give the kidnapper the alias-TARGETING travel package so he pursues
     the victim HERSELF (wherever she wanders). On the transport leg the
     target alias is re-pointed at the destination — the arrest return-leg
     trick. Apparatus handed back at bind/abort/release. Shared by
     KidnapNPC and MoveCaptive.}
    SeverActions_Arrest arrestK = GetArrestScript()
    ; (The bound-hands walk cuffs equip at SEIZURE in _OnKidnapGrabResolved,
    ; not here — equipping at leg-1 launch had a fresh kidnap target visibly
    ; wearing locked cuffs before anything happened to them.)
    Bool aliasMode = false
    If arrestK && arrestK.DispatchGuardAlias && arrestK.DispatchTargetAlias \
        && arrestK.SeverActions_DispatchJog \
        && arrestK.DispatchGuardAlias.GetReference() == None \
        && arrestK.DispatchTargetAlias.GetReference() == None
        arrestK.DispatchGuardAlias.ForceRefTo(akKidnapper)
        arrestK.DispatchTargetAlias.ForceRefTo(victim)
        ActorUtil.AddPackageOverride(akKidnapper, arrestK.SeverActions_DispatchJog, arrestK.PackagePriority, 1)
        akKidnapper.EvaluatePackage()
        SeverActionsNative.Native_SetTravelState(akKidnapper, "traveling", destination)
        SeverActionsNativeExt.Native_Kidnap_SetAliasMode(victim, true)
        ; Game-time leg deadline (IntelEngine model — the wait menu advances
        ; it): 12 game hours, then KidnapTick force-resolves off-screen.
        SeverActionsNativeExt.Native_Kidnap_SetLegDeadline(victim, Utility.GetCurrentGameTime() + 0.5)
        ; Native contact detection (1s checks) — without it the grab resolved
        ; only on KidnapTick's 30s poll, so the escort stood beside the target
        ; for many seconds before the seizure fired. The tick poll stays as
        ; the unloaded/off-screen fallback; _OnKidnapGrabResolved's 1->2 CAS
        ; makes the double resolution path harmless.
        If !SeverActionsNativeExt.Arrival_IsTracked(akKidnapper)
            SeverActionsNativeExt.Arrival_Register(akKidnapper, victim, 200.0, "kidnap_grab_arrived")
        EndIf
        aliasMode = true
    EndIf
    Debug.Trace("[SeverActions_FollowerManager] Kidnap: grab leg aliasMode=" + aliasMode)

    If !aliasMode
        ; FALLBACK — the dispatch apparatus is busy with a real arrest:
        ; raw orchestrator leg + KidnapTick's off-screen fast-forward.
        SeverActionsNativeExt.Native_Kidnap_SetAliasMode(victim, false)
        Package kidnapTravelPkg = travel.GetTravelPackageForSpeed(travel.SPEED_JOG)
        ; Long walk spans many 5s orphan-scan windows — without this the
        ; scanner strips the travel LinkedRef mid-journey (courier lesson).
        SeverActionsNative.OrphanCleanup_RegisterTraveler(akKidnapper)
        ; travelState gates the follower teleport/catch-up systems.
        SeverActionsNative.Native_SetTravelState(akKidnapper, "traveling", destination)
        Int kHandle = SeverActionsNativeExt.Travel_Begin(akKidnapper, victim, travel.TravelTargetKeyword, \
            250.0, "kidnap_grab", travel.TRAVEL_OPTIONS_LONGRANGE, 180, travel.SPEED_JOG)
        ; Phase 2: the Traveler_NN pool alias (priority 106) drives the walk; the
        ; legacy override applies only as the pool-exhaustion fallback (or if Begin failed).
        If kidnapTravelPkg && (kHandle <= 0 || !SeverActionsNativeExt2.Travel_HasAlias(kHandle))
            ActorUtil.AddPackageOverride(akKidnapper, kidnapTravelPkg, travel.TravelPackagePriority, 1)
            akKidnapper.EvaluatePackage()
        EndIf
    EndIf
EndFunction

Bool Function PlayerRestrainOnSpot(Actor akVictim)
    {Hotkey restrain (2026-08-23): bind akVictim on the spot with the PLAYER
     as captor. Same store entry and bind RestrainNPC lands in (restraint
     flag: no hood, no crime, open act) but WITHOUT the NPC walk-up leg or
     the ArrivalMonitor registration - the player is already in reach. Returns
     true once bound; every refusal notifies/narrates itself so the caller
     only narrates success.}
    Actor player = Game.GetPlayer()
    If !akVictim || akVictim == player || akVictim.IsDead()
        Return False
    EndIf
    If _RejectInvalidCaptiveTarget(player, akVictim, "restrain")
        Return False
    EndIf
    If !akVictim.Is3DLoaded() || player.GetDistance(akVictim) > 400.0
        Debug.Notification(akVictim.GetDisplayName() + " is too far to take hold of")
        Return False
    EndIf
    ; Atomic claim - refuses if they are already someone's captive or in an
    ; active kidnap/restrain leg (the hotkey's own phase check runs first,
    ; but this is the authoritative guard against a concurrent action).
    If !SeverActionsNativeExt.Native_Kidnap_BeginIfFree(akVictim, player, "", True)
        Debug.Notification(akVictim.GetDisplayName() + " cannot be restrained right now")
        Return False
    EndIf
    StorageUtil.UnsetFloatValue(akVictim, "SA_KidnapSteelSpentGT")
    StorageUtil.UnsetIntValue(akVictim, "SA_KidnapSteelFailed")
    SeverActionsNativeExt.Native_Kidnap_SetLegDeadline(akVictim, 0.0)

    ; Bind flourish, then the shared pacify + bind (what OnRestrainArrived
    ; does at the end of an NPC's walk-up). TOCTOU re-check after the wait.
    SeverActions_Arrest arrestH = GetArrestScript()
    If arrestH && arrestH.IdleGive
        player.PlayIdle(arrestH.IdleGive)
        Utility.Wait(1.2)
        If SeverActionsNativeExt.Native_Kidnap_GetPhase(akVictim) != 1
            Return False
        EndIf
    EndIf
    _PacifyCaptive(akVictim)
    _BindCaptive(akVictim, player, False)   ; abGuard False: the player isn't posted on guard duty
    Return True
EndFunction

Function RestrainNPC(Actor akRestrainer, String targetName)
    {RESTRAIN: the speaker walks to a named same-scene NPC, binds their hands
     (IdleGive flourish at contact), and holds them standing with
     hands bound — the kidnap hold WITHOUT the hood or the kneel furniture, the abduction
     legs, or any crime consequences (an open, ordered act: a jarl's command,
     a guard commander's order, helping law enforcement). The captive plugs
     straight into the existing machinery: MoveCaptive relocates them,
     ReleaseCaptive frees them, the guard-radius/escape sim applies, and
     kidnap_context narrates both sides restraint-aware (kFlagRestraint).
     Called by SkyrimNet via restrainnpc.yaml — ANY NPC can be the
     restrainer, not just followers (the ordering NPC simply tells them to
     in dialogue; the restrainer's own LLM turn calls this action).}
    If !akRestrainer || akRestrainer.IsDead()
        Return
    EndIf
    If !EnableRestrainAction
        Debug.Notification("Restrain action is disabled (Settings > Behavior).")
        Return
    EndIf
    If _RejectIfBoundActor(akRestrainer, "restrain anyone")
        Return
    EndIf
    If _RejectIfActorOccupied(akRestrainer, "restrain anyone")
        Return
    EndIf
    Actor victim = SeverActionsNativeExt.Native_Kidnap_FindActorByName(targetName)
    If !victim || victim == akRestrainer || victim == Game.GetPlayer() || victim.IsDead()
        Return
    EndIf
    If IsRegisteredFollower(victim)
        SkyrimNetApi.RegisterEvent("restrain_failed", \
            akRestrainer.GetDisplayName() + " will not restrain one of " + Game.GetPlayer().GetDisplayName() + "'s own companions.", \
            akRestrainer, None)
        Return
    EndIf
    If _RejectInvalidCaptiveTarget(akRestrainer, victim, "restrain")
        Return
    EndIf
    ; The restrainer may already be mid-approach for the ARREST system
    ; (guards are the archetypal restrainers): ArrivalMonitor keeps ONE
    ; registration per actor, so registering restrain_arrived would silently
    ; kill a live arrest approach/escort watch. Refuse instead.
    If SeverActionsNativeExt.Arrival_IsTracked(akRestrainer)
        SkyrimNetApi.RegisterEvent("restrain_failed",             akRestrainer.GetDisplayName() + " has their hands full and cannot restrain anyone right now.",             akRestrainer, None)
        Return
    EndIf
    ; (Availability is checked ATOMICALLY by BeginIfFree below - a separate
    ; phase/FindVictimOf pre-check raced a concurrent action execution.)
    ; Same-scene only — unlike kidnap there is no off-screen leg; the whole
    ; point of a restraint is that it happens in front of people.
    If !victim.Is3DLoaded() || !akRestrainer.Is3DLoaded() \
        || akRestrainer.GetDistance(victim) > 4000.0
        SkyrimNetApi.RegisterEvent("restrain_failed", \
            akRestrainer.GetDisplayName() + " cannot restrain " + targetName + " - they are not here.", \
            akRestrainer, None)
        Return
    EndIf

    ; Open the store entry (restraint-flagged) in the approach phase — the
    ; kidnap_context decorator narrates the walk-up from it. No grab info is
    ; ever set, so the gossip/search/ransom timer block never arms.
    If !SeverActionsNativeExt.Native_Kidnap_BeginIfFree(victim, akRestrainer, "", true)
        Return  ; target already held, or the restrainer already has a captive (atomic claim)
    EndIf
    StorageUtil.UnsetFloatValue(victim, "SA_KidnapSteelSpentGT")
    StorageUtil.UnsetIntValue(victim, "SA_KidnapSteelFailed")
    ; Recall listener (audit): every other kidnap entry point registers this;
    ; without it, a player recall during the FIRST-EVER restrain walk-up of a
    ; session was silently ignored and the stale approach could bind the
    ; target spuriously wherever they later crossed 160u of the restrainer.
    RegisterForModEvent("SeverActions_FollowerCalledByPlayer", "OnKidnapGuardRecall")
    ; Approach watchdog — if pathing never gets there, KidnapTick unwinds
    ; (~2.4 game hours; GetCurrentGameTime is in days).
    SeverActionsNativeExt.Native_Kidnap_SetLegDeadline(victim, Utility.GetCurrentGameTime() + 0.1)

    ; Walk over — borrow the dispatch aliases + the alias-targeting Jog
    ; package when free (the mover the kidnap grab leg uses; it closes to
    ; CONTACT). The old walk-up reused the arrest PRISONER follow package via
    ; LinkedRef, but a Follow-template package is satisfied at its follow
    ; RADIUS — far wider than the 160u arrival threshold — so a same-room
    ; restrainer stood content where they were and restrain_arrived never
    ; fired unless the player shoved the target closer. ArrivalMonitor still
    ; fires restrain_arrived — routed through Arrest's OnArrival (one
    ; ModEvent callback per (form,event); Arrest owns this quest's OnArrival
    ; and forwards our tag to HandleRestrainArrived).
    SeverActions_Arrest arrest = GetArrestScript()
    If arrest && arrest.DispatchGuardAlias && arrest.DispatchTargetAlias \
        && arrest.SeverActions_DispatchJog \
        && arrest.DispatchGuardAlias.GetReference() == None \
        && arrest.DispatchTargetAlias.GetReference() == None
        arrest.DispatchGuardAlias.ForceRefTo(akRestrainer)
        arrest.DispatchTargetAlias.ForceRefTo(victim)
        ActorUtil.AddPackageOverride(akRestrainer, arrest.SeverActions_DispatchJog, arrest.PackagePriority, 1)
        akRestrainer.EvaluatePackage()
        SeverActionsNativeExt.Native_Kidnap_SetAliasMode(victim, true)
    ElseIf arrest && arrest.SeverActions_FollowTargetKW && arrest.SeverActions_FollowGuard_Prisoner
        ; Degraded walk-up — the apparatus is busy with a real arrest.
        SeverActionsNative.LinkedRef_Set(akRestrainer, victim, arrest.SeverActions_FollowTargetKW)
        ActorUtil.AddPackageOverride(akRestrainer, arrest.SeverActions_FollowGuard_Prisoner, 95, 1)
        akRestrainer.EvaluatePackage()
    EndIf
    SeverActionsNativeExt.Arrival_Register(akRestrainer, victim, 160.0, "restrain_arrived")
    Debug.Trace("[SeverActions_FollowerManager] Restrain: " + akRestrainer.GetDisplayName() + " moving to restrain " + victim.GetDisplayName())
EndFunction

Function HandleRestrainArrived(Actor akRestrainer)
    {Arrest's OnArrival router forwards restrain_arrived here: the restrainer
     reached the target. Re-validate (the async event may fire after the
     world moved on), play the bind flourish, pacify the way the kidnap grab
     does (capture-then-zero AVs + prisoner faction — restored/removed by
     _UnbindCaptive), and bind. _BindCaptive skips the hood and picks the
     restraint event text off the kFlagRestraint flag.}
    If !akRestrainer
        Return
    EndIf
    Actor victim = SeverActionsNativeExt.Native_Kidnap_FindVictimOf(akRestrainer)
    If !victim
        Return
    EndIf
    If !SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_RESTRAINT) \
        || SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) != 1
        Return  ; not a restrain approach (or already bound) — stale event
    EndIf
    _EndRestrainApproach(akRestrainer)
    SeverActionsNativeExt.Native_Kidnap_SetLegDeadline(victim, 0.0)
    If victim.IsDead()
        SeverActionsNativeExt.Native_Kidnap_Clear(victim)
        Return
    EndIf

    ; The bind flourish — the close-quarters hand-motion idle the arrest
    ; evidence handoff uses reads as tying the wrists at this range.
    SeverActions_Arrest arrestR = GetArrestScript()
    If arrestR && arrestR.IdleGive
        akRestrainer.PlayIdle(arrestR.IdleGive)
        Utility.Wait(1.2)
        ; TOCTOU: Papyrus stacks are concurrent — if anything else resolved
        ; this entry during the flourish window (tick, release, death), a
        ; second bind here would place a SECOND persistent marker and leak
        ; the first. Re-validate before proceeding.
        If SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) != 1
            Return
        EndIf
    EndIf

    ; Pacify via the shared helper (capture-then-zero + prisoner faction).
    _PacifyCaptive(victim)

    _BindCaptive(victim, akRestrainer)
EndFunction

Function HandleKidnapGrabArrived(Actor akKidnapper)
    {Arrest's OnArrival router forwards kidnap_grab_arrived here: native
     contact detection for the grab leg (see _LaunchGrabLeg).
     _OnKidnapGrabResolved's 1->2 CAS makes a stale or duplicate event a
     clean no-op.}
    If akKidnapper
        _OnKidnapGrabResolved(akKidnapper)
    EndIf
EndFunction

Function _EndRestrainApproach(Actor akRestrainer)
    {Strip the walk-up apparatus from the restrainer: the dispatch-alias Jog
     (the primary mover since the same-room fix) AND the borrowed follow
     package + its LinkedRef (degraded path). Reference-checked — safe to
     call on any state; never touches a real arrest's alias fills.}
    SeverActions_Arrest arrest = GetArrestScript()
    If arrest
        If arrest.SeverActions_DispatchJog
            ActorUtil.RemovePackageOverride(akRestrainer, arrest.SeverActions_DispatchJog)
        EndIf
        If arrest.DispatchGuardAlias && arrest.DispatchGuardAlias.GetReference() == akRestrainer
            arrest.DispatchGuardAlias.Clear()
            If arrest.DispatchTargetAlias
                arrest.DispatchTargetAlias.Clear()
            EndIf
        EndIf
        If arrest.SeverActions_FollowGuard_Prisoner
            ActorUtil.RemovePackageOverride(akRestrainer, arrest.SeverActions_FollowGuard_Prisoner)
        EndIf
        If arrest.SeverActions_FollowTargetKW
            SeverActionsNative.LinkedRef_Clear(akRestrainer, arrest.SeverActions_FollowTargetKW)
        EndIf
    EndIf
    akRestrainer.EvaluatePackage()
EndFunction

Function _AbortRestrainApproach(Actor akVictim)
    {KidnapTick watchdog: the restrain walk-up never arrived (pathing
     failure, target zoned away, combat). Unwind the restrainer and drop the
     entry — nothing happened to the target, so no memory, no consequences.}
    Actor restrainer = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(akVictim)
    If restrainer
        SeverActionsNativeExt.Arrival_Cancel(restrainer)
        _EndRestrainApproach(restrainer)
    EndIf
    SeverActionsNativeExt.Native_Kidnap_Clear(akVictim)
    Debug.Trace("[SeverActions_FollowerManager] Restrain: approach timed out for " + akVictim.GetDisplayName() + " - unwound")
EndFunction

Function MoveCaptive(Actor akEscort, String targetName, String destination)
    {Relocate a held captive to a new destination — the same two-leg flow as
     KidnapNPC (escort walks to the captive, unties them, marches them to the
     new hold, re-binds). akEscort may be a different companion than the
     original kidnapper. Called by SkyrimNet via movecaptive.yaml and the
     Prisma Actions page.}
    ; Kidnap OR restrain: restraint is default-ON while kidnap is default-OFF,
    ; and a restrained captive must be manageable under default settings.
    If !akEscort || akEscort.IsDead() || (!EnableKidnapActions && !EnableRestrainAction)
        Return
    EndIf
    If _RejectIfBoundActor(akEscort, "escort a captive anywhere")
        Return
    EndIf
    ; Same guard as KidnapNPC/RestrainNPC, and if anything more load-bearing
    ; here: _LaunchGrabLeg BORROWS the arrest dispatch aliases, so a guard who
    ; starts a captive move mid-arrest evicts their own arrest from them.
    If _RejectIfActorOccupied(akEscort, "escort a captive anywhere")
        Return
    EndIf

    ; Resolve among ACTIVE captives only.
    Actor victim = None
    Actor[] victims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    If !victims || victims.Length == 0
        Return
    EndIf
    If victims.Length == 1 && targetName == ""
        victim = victims[0]
    Else
        Int i = 0
        While i < victims.Length && !victim
            If victims[i] && StringUtil.Find(victims[i].GetDisplayName(), targetName) >= 0
                victim = victims[i]
            EndIf
            i += 1
        EndWhile
    EndIf
    If !victim || SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) != 3
        Return  ; only HELD captives can be moved
    EndIf

    SeverActions_Travel travel = GetTravelScript()
    If !travel
        Return
    EndIf
    ObjectReference destMarker = travel.ResolvePlace(akEscort, destination)
    If !destMarker
        SkyrimNetApi.RegisterEvent("kidnap_failed", \
            akEscort.GetDisplayName() + " does not know how to reach " + destination + ".", \
            akEscort, None)
        Return
    EndIf
    If destMarker.GetBaseObject().GetType() == 29
        ; Unlock the DOOR itself BEFORE swapping to the interior marker
        ; (audit: the unlock used to run after the reassignment and targeted
        ; the interior marker, so a locked door stayed shut and pathing
        ; stalled until the off-screen watchdog).
        If destMarker.IsLocked()
            destMarker.Lock(false)
        EndIf
        ObjectReference interiorMarker = SeverActionsNative.FindInteriorMarkerForDoor(destMarker)
        If interiorMarker != None
            destMarker = interiorMarker
        EndIf
    EndIf

    ; Release the OLD guard (may be a different NPC), tear down the hold
    ; (marker/sit package) but KEEP the hood + pacify faction + entry.
    Actor oldKidnapper = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(victim)
    ; ATOMIC re-key (audit): the old GetPhase-check + Begin pair raced
    ; ReleaseCaptive (Begin re-created an entry for a just-freed NPC and the
    ; escort marched a free person off) and never checked the escort was not
    ; already mid-job for a DIFFERENT victim (FindVictimOf then routed the
    ; wrong victim's leg events). RekeyIfHeld refuses both under one mutex
    ; hold. markerID survives the re-key so _TearDownHold below can still
    ; delete the old hold marker.
    If !SeverActionsNativeExt.Native_Kidnap_RekeyIfHeld(victim, akEscort, destination)
        SkyrimNetApi.RegisterEvent("kidnap_failed", \
            akEscort.GetDisplayName() + " cannot move " + victim.GetDisplayName() + " right now - the captive is spoken for, or the escort already has their hands full.", \
            akEscort, None)
        Return
    EndIf
    ; Unconditional guard-duty teardown (audit): when the GUARDING kidnapper
    ; is also the new escort, the old gate skipped this - the 110-priority
    ; KidnapGuardSandbox stayed anchored to the just-deleted hold marker and
    ; outranked the 100-priority march packages, pinning the escort at the
    ; old hold. Safe no-op when no guard package is applied.
    If oldKidnapper
        _EndGuardDuty(oldKidnapper)
    EndIf
    _TearDownHold(victim)

    ; Re-key the entry to the new escort + destination and run the same
    ; two-leg flow (leg 1 resolves instantly if the escort is adjacent).
    ; (Entry already re-keyed atomically above - no Begin here.)
    SeverActionsNativeExt.Native_Kidnap_SetDestAnchor(victim, destMarker)
    _LaunchGrabLeg(akEscort, victim, destination, travel)
    RegisterForModEvent("SeverActions_FollowerCalledByPlayer", "OnKidnapGuardRecall")

    SkyrimNetApi.RegisterPersistentEvent( \
        akEscort.GetDisplayName() + " sets out to move the captive " + victim.GetDisplayName() + " to " + destination + ".", \
        akEscort, victim)
    Debug.Notification(akEscort.GetDisplayName() + " is moving " + victim.GetDisplayName() + " to " + destination)
EndFunction

Function MoveCaptiveHere(Actor akEscort, String captiveName)
    {Relocate a HELD captive to where the player is standing RIGHT NOW — the
     PrismaUI Arrests view's "Move here" button. The entry's CURRENT kidnapper
     re-takes them via the same two-leg flow as MoveCaptive (walk there, cuff,
     march back) and binds them at a force-persistent pin marker dropped at
     the player's position at click time. akEscort arrives from the dispatch's
     target resolution (the row's kidnapper) and is only a hint — the entry's
     current kidnapper is authoritative.}
    If !akEscort || akEscort.IsDead() || (!EnableKidnapActions && !EnableRestrainAction)
        Return
    EndIf

    ; Resolve among ACTIVE captives only (same pattern as MoveCaptive).
    Actor victim = None
    Actor[] victims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    If !victims || victims.Length == 0
        Return
    EndIf
    If victims.Length == 1 && captiveName == ""
        victim = victims[0]
    Else
        Int i = 0
        While i < victims.Length && !victim
            If victims[i] && StringUtil.Find(victims[i].GetDisplayName(), captiveName) >= 0
                victim = victims[i]
            EndIf
            i += 1
        EndWhile
    EndIf
    If !victim
        Return
    EndIf
    If SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) != 3
        Debug.Notification("Only a held captive can be moved - " + victim.GetDisplayName() + " is not bound at a hold.")
        Return  ; only HELD captives can be moved
    EndIf

    ; The escort is the entry's CURRENT kidnapper — they know the hold and
    ; are the one standing guard. The row's akEscort may be a stale read, so
    ; validate the real one: no living escort, no move.
    Actor escort = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(victim)
    If !escort || escort.IsDead()
        Debug.Notification("No living kidnapper can bring " + victim.GetDisplayName() + " here.")
        Return
    EndIf
    If _RejectIfBoundActor(escort, "escort a captive anywhere")
        Return
    EndIf
    ; Same occupancy guard as MoveCaptive — this runs the identical two-leg
    ; flow, and leg 1 borrows the arrest dispatch aliases.
    If _RejectIfActorOccupied(escort, "escort a captive anywhere")
        Return
    EndIf
    ; Player mid-fight: the march would walk the escort + captive INTO the
    ; combat, and the guard-duty teardown below strips the escort's
    ; protection before they arrive. Refuse.
    If Game.GetPlayer().IsInCombat()
        Debug.Notification("Not in the middle of a fight - the move can wait.")
        Return
    EndIf

    SeverActions_Travel travel = GetTravelScript()
    If !travel
        Return
    EndIf

    ; The pin IS the destination, so resolve it BEFORE any state changes
    ; (MoveCaptive resolves its destination marker before the re-key for the
    ; same reason: nothing is mutated when resolution fails).
    ; abForcePersist=TRUE is load-bearing, same as the hold marker — a
    ; default PlaceAtMe ref unloads with its cell and the captive's
    ; low-process AI then dereferences the gone anchor (the documented
    ; BGSProcedureSit CTD class, crash-2026-07-06-18-56-33).
    Form pinBase = GetWorkMarkerBase()   ; XMarkerHeading
    If !pinBase
        Return
    EndIf
    ; A leftover pin from an aborted earlier move-here is dead weight —
    ; force-persistent refs never unload on their own, so sweep it before
    ; dropping the new one or they accumulate forever.
    ObjectReference oldPin = StorageUtil.GetFormValue(victim, "SeverKidnap_MovePin") as ObjectReference
    If oldPin
        oldPin.Disable()
        oldPin.Delete()
        StorageUtil.UnsetFormValue(victim, "SeverKidnap_MovePin")
    EndIf
    ObjectReference pin = Game.GetPlayer().PlaceAtMe(pinBase, 1, true, false)
    If !pin
        Return
    EndIf
    StorageUtil.SetFormValue(victim, "SeverKidnap_MovePin", pin)

    ; ATOMIC re-key (same audit wedge as MoveCaptive): refuses under one
    ; mutex hold when the captive is spoken for or the escort is already
    ; mid-job for a DIFFERENT victim. markerID survives the re-key so
    ; _TearDownHold below can still delete the old hold marker.
    If !SeverActionsNativeExt.Native_Kidnap_RekeyIfHeld(victim, escort, "where you stand")
        pin.Disable()
        pin.Delete()
        StorageUtil.UnsetFormValue(victim, "SeverKidnap_MovePin")
        Debug.Notification(escort.GetDisplayName() + " cannot move " + victim.GetDisplayName() + " right now.")
        Return
    EndIf
    ; Unconditional guard-duty teardown (MoveCaptive audit): the guarding
    ; kidnapper IS the escort here — their 110-priority KidnapGuardSandbox
    ; anchored to the old hold marker would outrank the 100-priority march
    ; packages and pin them at the old hold.
    _EndGuardDuty(escort)
    _TearDownHold(victim)

    ; Run the same two-leg flow (leg 1 resolves instantly if the escort is
    ; adjacent). The pin is deleted in _BindCaptive once the hold marker
    ; stands at its spot.
    SeverActionsNativeExt.Native_Kidnap_SetDestAnchor(victim, pin)
    _LaunchGrabLeg(escort, victim, "where you stand", travel)
    RegisterForModEvent("SeverActions_FollowerCalledByPlayer", "OnKidnapGuardRecall")

    DebugMsg("MoveCaptiveHere: " + escort.GetDisplayName() + " re-taking " + victim.GetDisplayName() + " to the player's position (pin=" + pin + ")")
    Debug.Notification(escort.GetDisplayName() + " is bringing " + victim.GetDisplayName() + " to you.")
EndFunction

Function DemandRansom(Actor akSpeaker, String targetName, Int aiAmount = 0)
    {V2 Slice 2: send a ransom demand to a held captive's people — the
     home-hold steward abstraction (the same crime faction the bounty
     jurisdiction resolves from). The answer comes back in
     KIDNAP_RANSOM_RESOLVE_DAYS via _ResolveRansom: a courier with the
     payment (scaled by the victim's standing), or a refusal that arms the
     search party. aiAmount 0 = a fair price from the victim's standing;
     a player-named amount is honored (100-10000, rounded to 50s) but
     GREED HAS ODDS — _ResolveRansom docks the pay chance when the demand
     overreaches the fair value. Called by SkyrimNet via demandransom.yaml
     and the Prisma Actions page.}
    If !akSpeaker || akSpeaker.IsDead() || !EnableKidnapActions
        Return
    EndIf
    If _RejectIfBoundActor(akSpeaker, "demand ransom for anyone")
        Return
    EndIf

    ; Resolve among HELD captives only (same pattern as MoveCaptive).
    Actor victim = None
    Actor[] victims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    If !victims || victims.Length == 0
        Return
    EndIf
    If victims.Length == 1 && targetName == ""
        victim = victims[0]
    Else
        Int i = 0
        While i < victims.Length && !victim
            If victims[i] && StringUtil.Find(victims[i].GetDisplayName(), targetName) >= 0
                victim = victims[i]
            EndIf
            i += 1
        EndWhile
    EndIf
    If !victim || SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) != 3
        Return  ; only HELD captives can be ransomed
    EndIf
    ; RESTRAINT captives have no ransom market: an open, ordered, no-crime
    ; hold in plain sight. Critically, the pre-v3 grab-record heal below
    ; would stamp SetGrabInfo onto the restraint entry (grabTime stays 0 BY
    ; DESIGN for restraints) and retroactively arm the vanished-gossip,
    ; search-party, and release-bounty machinery the restraint contract
    ; explicitly excludes.
    If SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_RESTRAINT)
        SkyrimNetApi.RegisterEvent("kidnap_ransom_failed",             akSpeaker.GetDisplayName() + " considers it, but no one pays ransom for someone held openly in plain sight.",             akSpeaker, None)
        Return
    EndIf
    If SeverActionsNativeExt.Native_Kidnap_GetRansomState(victim) != 0
        Debug.Notification("A ransom for " + victim.GetDisplayName() + " has already been demanded.")
        Return
    EndIf

    ; The payer: the victim's home-hold crime faction (the steward
    ; abstraction). Heal a missing grab record (pre-v3 captivity) so the
    ; refusal→search path has jurisdiction to work with.
    Faction payerFac = SeverActionsNativeExt.Native_Kidnap_GetGrabFaction(victim)
    If !payerFac
        payerFac = SeverActionsNativeExt.Hold_GetCrimeFaction(victim)
        If payerFac && SeverActionsNativeExt.Native_Kidnap_GetGrabTime(victim) <= 0.0
            SeverActionsNativeExt.Native_Kidnap_SetGrabInfo(victim, payerFac, Utility.GetCurrentGameTime())
        EndIf
    EndIf
    If !payerFac
        SkyrimNetApi.RegisterEvent("kidnap_ransom_failed", \
            "No one of standing would pay a ransom for " + victim.GetDisplayName() + " - the demand has nowhere to go.", \
            akSpeaker, victim)
        Debug.Notification("No one of standing will pay for " + victim.GetDisplayName() + ".")
        Return
    EndIf

    ; Fair price scales with the victim's standing: level + quest protection.
    Int amount = 400 + victim.GetLevel() * 30
    ActorBase vBase = victim.GetActorBase()
    If vBase && vBase.IsEssential()
        amount += 600
    EndIf
    If amount > 4000
        amount = 4000
    EndIf
    ; Wealth raises the fair price (user request): carried coin and a roof
    ; of their own both signal a family that can raise more. MIRRORED in
    ; _ResolveRansom's greed-dock fair recompute - keep the two in sync.
    amount += (victim.GetItemCount(Game.GetForm(0x0000000F)) / 2)
    If SeverActionsNative.GetActorHomeCellName(victim) != ""
        amount += 400
    EndIf
    If amount > 4500
        amount = 4500
    EndIf

    ; Player-named amount (user request): honored within sane bounds; the
    ; resolve roll punishes overreach (see _ResolveRansom's greed dock).
    If aiAmount > 0
        amount = aiAmount
        If amount < 100
            amount = 100
        ElseIf amount > 10000
            amount = 10000
        EndIf
    EndIf
    amount = (amount / 50) * 50

    SeverActionsNativeExt.Native_Kidnap_SetRansom(victim, amount, Utility.GetCurrentGameTime())

    String holdName = SeverActionsNativeExt.Hold_GetHoldName(victim)
    If holdName == ""
        holdName = "their people"
    EndIf
    SkyrimNetApi.RegisterPersistentEvent( \
        akSpeaker.GetDisplayName() + " has sent word to " + holdName + " demanding " + amount + " gold for the safe return of " + victim.GetDisplayName() + ". The answer will take a day or two to come back.", \
        akSpeaker, victim)
    Debug.Notification("Ransom demanded for " + victim.GetDisplayName() + ": " + amount + " gold.")
    Debug.Trace("[SeverActions_FollowerManager] Kidnap: ransom demanded for " + victim.GetDisplayName() + " (" + amount + "g, payer hold '" + holdName + "')")
EndFunction

Function _ResolveRansom(Actor akVictim)
    {The steward's answer, KIDNAP_RANSOM_RESOLVE_DAYS after the demand.
     Weighted roll: quest-protected hostages get paid for more readily; a
     WITNESSED grab means they know exactly who to blame and lean toward
     sending steel instead of coin. The written answer is LLM-composed
     native-side (Native_Kidnap_RequestRansomLetter → sever_letter_writer,
     templated fallback) and arrives by the standard courier pump; payment
     gold goes straight to the player (the ledger's gold-delta monitor
     records it).}
    Int amount = SeverActionsNativeExt.Native_Kidnap_GetRansomAmount(akVictim)
    String vName = akVictim.GetDisplayName()
    String plName = Game.GetPlayer().GetDisplayName()

    ; The steward is a real person (user request): resolve the payer hold's
    ; actual steward so the letter signs with their name and THEY carry the
    ; memory of the exchange - ask them about it later and they know.
    Actor steward = _GetHoldSteward(SeverActionsNativeExt.Native_Kidnap_GetGrabFaction(akVictim))
    String stewardName = ""
    If steward
        stewardName = steward.GetDisplayName()
    EndIf

    ; STANDING model (user request): the hold weighs who the captive IS to
    ; them before opening the coffers. (True nobodies - bandits, wilderness
    ; spawns - never get this far: they belong to no hold crime faction, so
    ; the demand already fails with 'no one of standing will pay'.)
    ;   base 55        a citizen with a hearth and neighbors
    ;   +25 court      Jarl or steward - the court ransoms its own
    ;   +15 commerce   merchant / innkeeper - the town needs its shops open
    ;   +5  bard       well-liked, not exactly vital
    ;   -45 beggar/drunk  nobody passes the hat for Degaine
    ;   +15 essential  someone's story needs them alive
    ;   -20 witnessed  they know WHO took them - steel tempts more than coin
    ;   greed dock     below - overreaching the fair price sours the deal
    Int payChance = 55
    ActorBase vBase = akVictim.GetActorBase()
    If vBase && vBase.IsEssential()
        payChance += 15
    EndIf
    Faction facJarl      = Game.GetFormFromFile(0x00050920, "Skyrim.esm") as Faction
    Faction facSteward   = Game.GetFormFromFile(0x00050922, "Skyrim.esm") as Faction
    Faction facMerchant  = Game.GetFormFromFile(0x00051596, "Skyrim.esm") as Faction
    Faction facInnkeeper = Game.GetFormFromFile(0x0005091B, "Skyrim.esm") as Faction
    Faction facBard      = Game.GetFormFromFile(0x00053514, "Skyrim.esm") as Faction
    Faction facBeggar    = Game.GetFormFromFile(0x00060028, "Skyrim.esm") as Faction
    Faction facDrunk     = Game.GetFormFromFile(0x00060027, "Skyrim.esm") as Faction
    If (facJarl && akVictim.IsInFaction(facJarl)) || (facSteward && akVictim.IsInFaction(facSteward))
        payChance += 25
    ElseIf (facMerchant && akVictim.IsInFaction(facMerchant)) || (facInnkeeper && akVictim.IsInFaction(facInnkeeper))
        payChance += 15
    ElseIf facBard && akVictim.IsInFaction(facBard)
        payChance += 5
    EndIf
    If (facBeggar && akVictim.IsInFaction(facBeggar)) || (facDrunk && akVictim.IsInFaction(facDrunk))
        payChance -= 45
    EndIf
    ; Wealth signals (user request): coin in their pockets and a roof of
    ; their own mean people who can actually raise the ransom.
    Int vGold = akVictim.GetItemCount(Game.GetForm(0x0000000F))
    Bool vHasHome = SeverActionsNative.GetActorHomeCellName(akVictim) != ""
    If vGold >= 300
        payChance += 10
    ElseIf vGold >= 100
        payChance += 5
    EndIf
    If vHasHome
        payChance += 10
    EndIf
    If SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_WITNESSED)
        payChance -= 20
    EndIf
    ; Desperation premium: the hold's hired steel already failed to bring the
    ; captive home (searchers dead or talked down) - coin looks cheap now.
    If StorageUtil.GetIntValue(akVictim, "SA_KidnapSteelFailed", 0) == 1
        payChance += 25
    EndIf
    ; Greed dock (player-named amounts): recompute the fair price and dock
    ; the odds as the demand overreaches it. A modest premium is tolerated;
    ; triple the fair value and they will likely hire steel instead.
    ; MIRRORS DemandRansom's fair formula incl. the wealth terms.
    Int fairAmount = 400 + akVictim.GetLevel() * 30
    If vBase && vBase.IsEssential()
        fairAmount += 600
    EndIf
    If fairAmount > 4000
        fairAmount = 4000
    EndIf
    fairAmount += vGold / 2
    If vHasHome
        fairAmount += 400
    EndIf
    If fairAmount > 4500
        fairAmount = 4500
    EndIf
    If amount > fairAmount * 3
        payChance -= 35
    ElseIf amount * 2 > fairAmount * 3
        payChance -= 15
    EndIf

    If payChance < 5
        payChance = 5
    ElseIf payChance > 95
        payChance = 95
    EndIf
    Debug.Trace("[SeverActions_FollowerManager] Kidnap: ransom resolve for " + vName + " - payChance=" + payChance)

    If Utility.RandomInt(0, 99) < payChance
        SeverActionsNativeExt.Native_Kidnap_SetRansomState(akVictim, KIDNAP_RANSOM_PAID)
        Game.GetPlayer().AddItem(Game.GetForm(0x0000000F), amount, true)
        SeverActionsNativeExt.Native_Kidnap_RequestRansomLetter(akVictim, true, stewardName)
        If steward
            SeverActionsNative.Native_AddMemory(steward, \
                "As steward I handled the ransom of " + vName + " - I arranged payment of " + amount + " gold to " + plName + "'s go-between for " + vName + "'s safe return, and I signed the letter that went with it myself. The hold expects " + vName + " released promptly and whole; if they are not, I will see steel sent instead of coin.", \
                0.8, "EXPERIENCE", "grim", "", "[\"ransom\"]", "[]")
        EndIf
        SkyrimNetApi.RegisterPersistentEvent( \
            "The ransom for " + vName + " has been PAID - " + amount + " gold delivered to " + plName + ". " + vName + "'s people now expect their prompt release; keeping them would be a betrayal of the bargain.", \
            Game.GetPlayer(), akVictim)
        Debug.Notification("The ransom for " + vName + " was paid: +" + amount + " gold.")
        Debug.Trace("[SeverActions_FollowerManager] Kidnap: ransom PAID (" + amount + "g) for " + vName)
    Else
        SeverActionsNativeExt.Native_Kidnap_SetRansomState(akVictim, KIDNAP_RANSOM_REFUSED)
        SeverActionsNativeExt.Native_Kidnap_RequestRansomLetter(akVictim, false, stewardName)
        If SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_SEARCH)
            ; Their searchers already came and went BEFORE this refusal -
            ; steel is spent, so the give-up clock starts immediately.
            StorageUtil.SetFloatValue(akVictim, "SA_KidnapSteelSpentGT", Utility.GetCurrentGameTime())
            StorageUtil.SetIntValue(akVictim, "SA_KidnapSteelFailed", 1)
        EndIf
        If steward
            SeverActionsNative.Native_AddMemory(steward, \
                "As steward I refused the ransom demanded for " + vName + " - " + amount + " gold to brigands buys nothing but more brigands. I signed the refusal myself, and I would sooner spend that coin on hired steel to bring " + vName + " home.", \
                0.8, "EXPERIENCE", "defiant", "", "[\"ransom\"]", "[]")
        EndIf
        SkyrimNetApi.RegisterPersistentEvent( \
            "The ransom demand for " + vName + " was REFUSED - their people would sooner hire steel than pay coin.", \
            Game.GetPlayer(), akVictim)
        Debug.Notification("The ransom demand for " + vName + " was refused.")
        Debug.Trace("[SeverActions_FollowerManager] Kidnap: ransom REFUSED for " + vName)
    EndIf
EndFunction

Actor Function _GetHoldSteward(Faction akCrimeFac)
    {The hold's actual steward NPC behind the ransom 'steward' abstraction.
     Crime faction -> steward resolved by NAME through the global finder
     (NND/rename tolerant); None when unresolvable and callers degrade to
     the faceless steward. Vanilla courts only - modded holds return None.
     FormIDs verified against the load order via HouseCARL (the 0x267Ex
     block guess was wrong for six of nine - always verify).}
    If !akCrimeFac
        Return None
    EndIf
    Int fid = akCrimeFac.GetFormID()
    String sName = ""
    If fid == 0x000267EA        ; CrimeFactionWhiterun
        sName = "Proventus Avenicci"
    ElseIf fid == 0x000267E3    ; CrimeFactionEastmarch
        sName = "Jorleif"
    ElseIf fid == 0x00029DB0    ; CrimeFactionHaafingar
        sName = "Falk Firebeard"
    ElseIf fid == 0x00028170    ; CrimeFactionFalkreath
        sName = "Nenya"
    ElseIf fid == 0x0002816F    ; CrimeFactionWinterhold
        sName = "Malur Seloth"
    ElseIf fid == 0x0002816E    ; CrimeFactionPale
        sName = "Bulfrek"
    ElseIf fid == 0x0002816D    ; CrimeFactionHjaalmarch
        sName = "Aslfur"
    ElseIf fid == 0x0002816C    ; CrimeFactionReach
        sName = "Raerek"
    ElseIf fid == 0x0002816B    ; CrimeFactionRift
        sName = "Anuriel"
    EndIf
    If sName == ""
        Return None
    EndIf
    Return SeverActionsNativeExt.Native_Kidnap_FindActorByName(sName)
EndFunction

Function _TearDownHold(Actor akVictim)
    {Remove ONLY the hold pieces (sit package, furniture LinkedRef, placed
     marker) — hood, pacify faction, captured AVs, and the store entry stay.
     Used by MoveCaptive and the grab-resolved handler when re-taking an
     already-held captive.}
    SeverActions_Furniture furn = GetFurnitureScript()
    Package sitPkg = Game.GetFormFromFile(KIDNAP_SIT_PKG_FORMID, "SeverActions.esp") as Package
    If sitPkg
        ActorUtil.RemovePackageOverride(akVictim, sitPkg)
    EndIf
    ; The alias seat goes with the hold (re-binds refill a fresh slot).
    _FreeCaptiveAlias(akVictim)
    If furn && furn.SeverActions_FurnitureTargetKeyword
        SeverActionsNative.LinkedRef_Clear(akVictim, furn.SeverActions_FurnitureTargetKeyword)
    EndIf
    ObjectReference oldMarker = SeverActionsNativeExt.Native_Kidnap_GetMarker(akVictim)
    If oldMarker
        oldMarker.Disable()
        oldMarker.Delete()
    EndIf
    ; Loose-captivity pieces (UntieCaptive): the hold-anchored sandbox +
    ; its LinkedRef, if present. Safe no-ops otherwise.
    Package guardPkgTD = Game.GetFormFromFile(KIDNAP_GUARD_PKG_FORMID, "SeverActions.esp") as Package
    If guardPkgTD
        ActorUtil.RemovePackageOverride(akVictim, guardPkgTD)
    EndIf
    SeverActions_Arrest arrTD = GetArrestScript()
    If arrTD && arrTD.SeverActions_PrisonerSandBox
        ; The wide loose-captivity sandbox (UntieCaptive uses PrisonerSandBox).
        ActorUtil.RemovePackageOverride(akVictim, arrTD.SeverActions_PrisonerSandBox)
    EndIf
    If arrTD && arrTD.SeverActions_SandboxAnchorKW
        SeverActionsNative.LinkedRef_Clear(akVictim, arrTD.SeverActions_SandboxAnchorKW)
    EndIf
    SeverActionsNativeExt.Native_Kidnap_SetHeld(akVictim, None)
    ; Release the standing-bound pin so a MOVED restraint captive can actually
    ; walk the relocation leg (the standing bound idle sets SetDontMove(true);
    ; without this they'd be dragged frozen). Safe no-op for kidnap captives,
    ; which never set it. IdleForceDefaultState below drops the bound offset.
    akVictim.SetDontMove(false)
    Debug.SendAnimationEvent(akVictim, "IdleForceDefaultState")
    ; The pose is gone — clear the posed flag or the stale "already posed"
    ; state suppresses every later re-play (the moved captive arrived at the
    ; new hold with free hands and nothing ever healed it).
    StorageUtil.SetIntValue(akVictim, "SeverRestrain_Posed", 0)
    akVictim.EvaluatePackage()
EndFunction

Function HandleKidnapTravelComplete(Actor npc, String tag, String status)
    {Called by SeverActions_Travel.OnTravelComplete for kidnap_* tags — that
     script owns the quest's single SeverActions_TravelComplete registration
     (SKSE: one ModEvent callback per form per event; all SA scripts share
     the quest form, so a listener registered here would be silently dead).}
    If !npc
        Return
    EndIf

    ; STALE-CANCEL GUARD (audit): a "cancelled" completion only matters while
    ; its leg is still the CURRENT phase. In slot-fallback mode the leg-1
    ; orchestrator handle stays live through the grab resolve, and leg 2's
    ; DoTravelToPlace internally CancelTravel()s it - that async
    ; kidnap_grab|cancelled used to reach _AbortKidnap (no phase guard) and
    ; unwind a SUCCESSFUL grab seconds after it happened, release
    ; consequences and all. Same class protects the transport leg.
    Actor tcVictim = SeverActionsNativeExt.Native_Kidnap_FindVictimOf(npc)
    If tag == "kidnap_grab"
        If status == "cancelled"
            If tcVictim && SeverActionsNativeExt.Native_Kidnap_GetPhase(tcVictim) == 1
                _AbortKidnap(npc)
            EndIf
        Else
            ; arrived | aborted | gaveup | timedout → the grab resolves
            ; off-screen regardless; leg 2 walks them back on-screen.
            _OnKidnapGrabResolved(npc)
        EndIf
    ElseIf tag == "kidnap_transport"
        If status == "cancelled"
            If tcVictim && SeverActionsNativeExt.Native_Kidnap_GetPhase(tcVictim) == 2
                _AbortKidnap(npc)
            EndIf
        Else
            _OnKidnapTransportResolved(npc, status)
        EndIf
    EndIf
EndFunction

Function _KidnapLegWatchdog(Actor akKidnapper, Actor akVictim, ObjectReference akGoal, Bool abTimeJumped = false)
    {Shared progress backstops for an in-flight leg (alias or orchestrator
     mode): (1) off-screen fast-forward — 4 consecutive unobserved ticks
     (~2 min; generous so aliased pathing gets a real chance) teleports the
     kidnapper to the leg goal, never while visible; (2) game-time deadline
     (12h) force-teleports off-screen the same way; (3) abTimeJumped — the
     player waited/slept/fast-traveled >= 1 game hour since the last tick,
     which counts as elapsed march time and skips the 4-tick patience
     outright. All three respect never-in-view and the roadside hold.}
    If !akGoal
        Return
    EndIf
    Float deadline = SeverActionsNativeExt.Native_Kidnap_GetLegDeadline(akVictim)
    Bool deadlinePassed = deadline > 0.0 && Utility.GetCurrentGameTime() > deadline
    If akKidnapper.Is3DLoaded() && !deadlinePassed
        SeverActionsNativeExt.Native_Kidnap_BumpOffscreenTicks(akVictim, true)
        Return
    EndIf
    ; LOADED and past the deadline (audit): neither branch below handled this
    ; - an on-screen pathing failure (blocked door, stripped package, navmesh
    ; dead end) stalled forever as long as the player kept watching. The
    ; off-screen teleport is not an option in view, so the kidnapper visibly
    ; gives up instead.
    If akKidnapper.Is3DLoaded() && deadlinePassed
        Debug.Trace("[SeverActions_FollowerManager] Kidnap: leg deadline passed while loaded - giving up")
        _AbortKidnap(akKidnapper)
        Return
    EndIf
    If !akKidnapper.Is3DLoaded()
        Int ticks = SeverActionsNativeExt.Native_Kidnap_BumpOffscreenTicks(akVictim, false)
        If ticks < 4 && !deadlinePassed && !abTimeJumped
            Return
        EndIf
        ; ROAD-ENCOUNTER guard: if the player is near the pair's current
        ; position (persistent actors keep real positions off-screen, and
        ; the alias pin keeps their travel packages advancing), keep them
        ; WALKING instead of teleporting - the player may be coming to
        ; intercept the march. Ticks are deliberately NOT reset: the
        ; fast-forward resumes the moment the player leaves the area.
        ; Cross-worldspace GetDistance returns huge values, which correctly
        ; falls through to the teleport.
        If akKidnapper.GetDistance(Game.GetPlayer()) <= KIDNAP_ROADSIDE_RADIUS
            Debug.Trace("[SeverActions_FollowerManager] Kidnap: watchdog hold - player near the march, letting them walk")
            Return
        EndIf
        SeverActionsNativeExt.Native_Kidnap_BumpOffscreenTicks(akVictim, true)
        Debug.Trace("[SeverActions_FollowerManager] Kidnap: watchdog fast-forward (deadline=" + deadlinePassed + ")")
        akKidnapper.MoveTo(akGoal)
        ; Escorted victim rides along off-screen so the pair doesn't strand.
        If akVictim && !akVictim.Is3DLoaded() && akVictim.GetParentCell() != akKidnapper.GetParentCell()
            akVictim.MoveTo(akKidnapper)
        EndIf
    EndIf
EndFunction

Function _EndDispatchAliases(Actor akKidnapper, Actor akVictim)
    {Hand the borrowed arrest-dispatch apparatus back: remove the alias-
     targeting travel package and clear any dispatch alias WE filled (only
     ours — checked by reference, so a real arrest's fills are untouched).}
    If !akKidnapper
        Return
    EndIf
    SeverActions_Arrest arrest = GetArrestScript()
    If arrest
        If arrest.SeverActions_DispatchJog
            ActorUtil.RemovePackageOverride(akKidnapper, arrest.SeverActions_DispatchJog)
        EndIf
        If arrest.SeverActions_DispatchWalk
            ActorUtil.RemovePackageOverride(akKidnapper, arrest.SeverActions_DispatchWalk)
        EndIf
        If arrest.DispatchGuardAlias && arrest.DispatchGuardAlias.GetReference() == akKidnapper
            arrest.DispatchGuardAlias.Clear()
            ; Target alias is ours too if the guard slot was ours (it holds
            ; either the victim or our destination marker).
            If arrest.DispatchTargetAlias
                arrest.DispatchTargetAlias.Clear()
            EndIf
        EndIf
        If akVictim && arrest.DispatchPrisonerAlias && arrest.DispatchPrisonerAlias.GetReference() == akVictim
            arrest.DispatchPrisonerAlias.Clear()
        EndIf
    EndIf
    ; Grab-leg arrival watch: fired registrations self-clear; this catches
    ; aborts and unwinds that end the borrow before contact.
    SeverActionsNativeExt.Arrival_Cancel(akKidnapper)
    If akVictim
        SeverActionsNativeExt.Native_Kidnap_SetAliasMode(akVictim, false)
        SeverActionsNativeExt.Native_Kidnap_SetLegDeadline(akVictim, 0.0)
        SeverActionsNativeExt.Native_Kidnap_BumpOffscreenTicks(akVictim, true)
    EndIf
EndFunction

Function SyncAllPremisesFromWork()
    {Walk every worker SA tracks (homed + work-only lists cover everyone with
     a work marker) and re-derive their venture premises from the marker's
     actual cell. Venture_SyncPremisesFromWork no-ops for non-retainers and
     for unchanged premises, so this is safe to run on every load.}
    Int synced = 0
    Int li = 0
    While li < 2
        String listKey = KEY_HOMED_NPCS
        If li == 1
            listKey = KEY_WORK_ONLY_NPCS
        EndIf
        Int n = StorageUtil.FormListCount(None, listKey)
        Int i = 0
        While i < n
            Actor npc = StorageUtil.FormListGet(None, listKey, i) as Actor
            If npc
                ObjectReference wm = StorageUtil.GetFormValue(npc, "SeverActions_WorkMarkerRef") as ObjectReference
                If SeverActionsNativeExt2.Venture_SyncPremisesFromWork(npc, wm)
                    synced += 1
                EndIf
            EndIf
            i += 1
        EndWhile
        li += 1
    EndWhile
    If synced > 0
        Debug.Trace("[SeverActions_FollowerManager] Premises re-derived for " + synced + " retainer(s) from their work markers")
    EndIf
EndFunction

Function OnGameLoaded()
    {Load recovery (routed via SeverActions_Init.RunLoadRecovery - a
     OnPlayerLoadGame here would be dead code on a Quest script).

     Orphan captivity-sandbox healer (user report: a freed captive kept the
     prisoner sandbox). Every release/escape/abort path strips the anchored
     sandbox packages, but a save written by an older build - or any edge a
     strip path missed - bakes the PapyrusUtil override into the save, and
     once the kidnap/jail entry is gone NO strip path ever runs again for
     that actor. Sweep the player's cell on load: any live actor carrying
     our captivity packages with NO legitimate claim (live kidnap entry as
     victim or captor, jail record, arrest session, active kidnap guard
     duty) gets them stripped. RemovePackageOverride / LinkedRef_Clear are
     safe no-ops on actors that never had them.

     Cell-scoped by design: the annoying case is the NPC the player is
     looking at, and a whole-world sweep has no enumeration surface
     (PapyrusUtil overrides are not enumerable). Runs every load - cheap
     (one pass over loaded cell actors) and idempotent.}
    ; Derive-mode premises re-sync (runs every load - cheap, idempotent):
    ; premises follow the work marker now, but saves from before the
    ; migration carry hand-picked attachments (the Embershard miner with a
    ; bedroom-premises bonus), and a property can be sold while its worker
    ; is off-screen. Re-derive every worker's premises from where their
    ; marker actually stands. No-op for non-retainers.
    SyncAllPremisesFromWork()

    SeverActions_Arrest arrestHeal = GetArrestScript()
    Package guardPkgHeal = Game.GetFormFromFile(KIDNAP_GUARD_PKG_FORMID, "SeverActions.esp") as Package
    Actor playerHeal = Game.GetPlayer()
    Actor[] cellActors = SeverActionsNativeExt.Native_ScanPlayerCellForLiveActors()
    Int healN = 0
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
                legit = StorageUtil.GetIntValue(a, "SeverKidnap_OnGuard", 0) == 1
            EndIf
            If !legit
                If arrestHeal && arrestHeal.SeverActions_PrisonerSandBox
                    ActorUtil.RemovePackageOverride(a, arrestHeal.SeverActions_PrisonerSandBox)
                EndIf
                If guardPkgHeal
                    ActorUtil.RemovePackageOverride(a, guardPkgHeal)
                EndIf
                If arrestHeal && arrestHeal.SeverActions_SandboxAnchorKW
                    SeverActionsNative.LinkedRef_Clear(a, arrestHeal.SeverActions_SandboxAnchorKW)
                EndIf
                a.EvaluatePackage()
                healN += 1
            EndIf
        EndIf
        i += 1
    EndWhile
    Debug.Trace("[SeverActions_FollowerManager] Load recovery: captivity-sandbox sweep checked " + cellActors.Length + " cell actors (" + healN + " without live captivity claims - overrides stripped defensively)")
EndFunction

Function _EndGuardDuty(Actor akKidnapper)
    {Drop the anchored guard package + LinkedRef from a kidnapper. Safe
     no-op when they never guarded. The Sandbox() relax state is handled by
     the normal resume paths (StopSandbox / StartFollowing).}
    If !akKidnapper
        Return
    EndIf
    SeverActions_Arrest arrest = GetArrestScript()
    StorageUtil.UnsetIntValue(akKidnapper, "SeverKidnap_OnGuard")
    Package guardPkg = Game.GetFormFromFile(KIDNAP_GUARD_PKG_FORMID, "SeverActions.esp") as Package
    If guardPkg
        ActorUtil.RemovePackageOverride(akKidnapper, guardPkg)
    EndIf
    If arrest
        ; Heal for older builds that used PrisonerSandBox for guard duty.
        If arrest.SeverActions_PrisonerSandBox
            ActorUtil.RemovePackageOverride(akKidnapper, arrest.SeverActions_PrisonerSandBox)
        EndIf
        If arrest.SeverActions_SandboxAnchorKW
            SeverActionsNative.LinkedRef_Clear(akKidnapper, arrest.SeverActions_SandboxAnchorKW)
        EndIf
    EndIf
    akKidnapper.EvaluatePackage()
EndFunction

Event OnKidnapGuardRecall(string eventName, string strArg, float numArg, Form sender)
    {The player called an NPC to their side (follow/recruit/wait command).
     Guarding kidnapper (phase 3): drop the anchored guard package so the
     normal resume flow wins — the captive stays bound. Mid-job kidnapper
     (leg 1/2): BIND THE VICTIM ON THE SPOT (V2 user decision) — the
     kidnapper ties them up wherever they are and answers the call; the
     captive can be relocated later with MoveCaptive.}
    Actor a = sender as Actor
    If !a
        Return
    EndIf
    Actor jobVictim = SeverActionsNativeExt.Native_Kidnap_FindVictimOf(a)
    If !jobVictim
        Return
    EndIf
    Int jobPhase = SeverActionsNativeExt.Native_Kidnap_GetPhase(jobVictim)
    If jobPhase == 3
        Debug.Trace("[SeverActions_FollowerManager] Kidnap: guard " + a.GetDisplayName() + " recalled from duty - captive stays bound")
        _EndGuardDuty(a)
    ElseIf jobPhase == 2
        ; Mid-march: bind where they stand. Clearing the destination anchor
        ; makes _BindCaptive place the marker at the victim's position; the
        ; abGuard=false skips guard duty so the kidnapper answers the call.
        Debug.Trace("[SeverActions_FollowerManager] Kidnap: kidnapper recalled mid-march - binding on the spot")
        SeverActionsNativeExt.Native_Kidnap_SetDestAnchor(jobVictim, None)
        _BindCaptive(jobVictim, a, false)
    ElseIf jobPhase == 1
        ; Grab never completed — nothing to bind; abort cleanly.
        Debug.Trace("[SeverActions_FollowerManager] Kidnap: kidnapper recalled pre-grab - aborting")
        _AbortKidnap(a)
    EndIf
EndEvent

Function _EndKidnapTravel(Actor akKidnapper)
    {Remove the kidnap travel override + orphan-scan traveler registration.
     Safe no-op when nothing is applied. The follower-registry entry
     (OrphanCleanup_RegisterFollower) is a separate map and is untouched.}
    SeverActions_Travel travel = GetTravelScript()
    If travel
        Package kidnapTravelPkg = travel.GetTravelPackageForSpeed(travel.SPEED_JOG)
        If kidnapTravelPkg
            ActorUtil.RemovePackageOverride(akKidnapper, kidnapTravelPkg)
        EndIf
    EndIf
    SeverActionsNative.OrphanCleanup_UnregisterTraveler(akKidnapper)
    ; Clear the traveling mark so the follower teleport/catch-up systems
    ; resume normal handling of this actor.
    SeverActionsNative.Native_SetTravelState(akKidnapper, "", "")
    akKidnapper.EvaluatePackage()
EndFunction

Function _OnKidnapGrabResolved(Actor akKidnapper)
    {Leg 1 done — seize the victim and start the march to the destination.
     Callable from BOTH the orchestrator completion (fallback mode) and
     KidnapTick (slot mode / same-cell detection) — the phase guard makes
     a double call harmless.}
    Actor victim = SeverActionsNativeExt.Native_Kidnap_FindVictimOf(akKidnapper)
    ; ATOMIC claim (audit): the read-then-act phase guard spanned Papyrus
    ; suspension points, so the dual resolution paths (tick same-cell check +
    ; travel completion event) could BOTH pass it - double witnessed bounty,
    ; double leg-2 launch, and a second in-place bind leaking a persistent
    ; marker. Compare-and-set 1 -> 2 under the store mutex; the loser returns.
    If victim && !victim.IsDead() && !SeverActionsNativeExt.Native_Kidnap_TryAdvancePhase(victim, 1, 2)
        Return  ; already resolved/claimed by the other path
    EndIf
    If !victim || victim.IsDead()
        If victim
            _DeleteKidnapHomeMarker(victim)
            SeverActionsNativeExt.Native_Kidnap_Clear(victim)
        EndIf
        _EndKidnapTravel(akKidnapper)
        _EndDispatchAliases(akKidnapper, victim)
        Return
    EndIf

    ; The grab-leg arrival watch may still be live if the tick poll or the
    ; travel completion resolved first — drop it so it can't fire a stale
    ; event mid-march (a fired registration self-clears; cancel is a no-op).
    SeverActionsNativeExt.Arrival_Cancel(akKidnapper)

    ; Re-taking an already-held captive (MoveCaptive): drop the old hold
    ; pieces before escorting. No-op for fresh grabs. A re-take re-TIES -
    ; clear the loose-captivity flag so contexts return to the bound framing.
    If SeverActionsNativeExt.Native_Kidnap_GetMarker(victim)
        _TearDownHold(victim)
    EndIf
    SeverActionsNativeExt.Native_Kidnap_SetFlag(victim, KIDNAP_FLAG_UNBOUND, false)

    ; Slice 3: a fresh grab drops a persistent home marker at the victim's
    ; pre-grab spot BEFORE the pull — an escaped captive flees back here.
    ; Best-effort: PlaceAtMe off an unloaded actor can misplace (round-10
    ; lesson) — a None marker just means an escapee stays put instead.
    If SeverActionsNativeExt.Native_Kidnap_GetGrabTime(victim) <= 0.0 \
        && !SeverActionsNativeExt.Native_Kidnap_GetHomeMarker(victim)
        Static xmBase = Game.GetFormFromFile(0x00003B, "Skyrim.esm") as Static
        If xmBase
            ObjectReference homeM = victim.PlaceAtMe(xmBase, 1, true, false)
            If homeM
                SeverActionsNativeExt.Native_Kidnap_SetHomeMarker(victim, homeM)
            EndIf
        EndIf
    EndIf

    ; Off-screen grab abstraction: pull the victim to the kidnapper. For an
    ; on-screen arrival this is a near-no-op; for an unreachable interior
    ; target it IS the abduction.
    If victim.GetParentCell() != akKidnapper.GetParentCell() || victim.GetDistance(akKidnapper) > 400.0
        victim.MoveTo(akKidnapper)
    EndIf

    ; Pacify via the shared helper (capture-then-zero + prisoner faction).
    _PacifyCaptive(victim)
    SeverActions_Arrest arrest = GetArrestScript()

    ; Bound-hands cuffs for the WALK — the arrest-march look. Equipped at
    ; SEIZURE (here), not at leg-1 launch: cuffing the victim the moment the
    ; kidnap ORDER was given had them visibly wearing locked cuffs while
    ; going about their day pre-grab. Covers both a fresh kidnap and a
    ; MoveCaptive relocation (re-equip on an already-cuffed captive is a
    ; no-op). Removed by _UnbindCaptive at release; the kidnap KNEEL strips
    ; them at _BindCaptive (the furniture supplies the bound-hands pose).
    If arrest && arrest.SeverActions_PrisonerCuffs
        victim.EquipItem(arrest.SeverActions_PrisonerCuffs, true, true)  ; abPreventRemoval, abSilent
    EndIf

    ; ── Consequences (V2 Slice 1): stamp the grab record ONCE (a MoveCaptive
    ; re-take keeps the original). Jurisdiction = the victim's own crime-
    ; faction membership — vanilla puts citizens IN their hold's crime
    ; faction, so this resolves their home hold even off-screen; NPCs no
    ; hold would miss (bandits, wilderness spawns) resolve None and draw
    ; no bounty, gossip, or search party.
    ; RESTRAINT-flagged entries (a restrained captive being MOVED — the
    ; same-scene walk-up never reaches this function since the phase-1 tick
    ; gate) stamp NOTHING: restraint is an open, ordered, no-crime act.
    If SeverActionsNativeExt.Native_Kidnap_GetGrabTime(victim) <= 0.0 \
        && !SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_RESTRAINT)
        Faction grabCrimeFac = SeverActionsNativeExt.Hold_GetCrimeFaction(victim)
        SeverActionsNativeExt.Native_Kidnap_SetGrabInfo(victim, grabCrimeFac, Utility.GetCurrentGameTime())
        ; Witnessed grab: a third party (not the victim, not a follower) saw
        ; it — the hold learns immediately.
        If SeverActionsNativeExt.Native_Kidnap_IsGrabWitnessed(akKidnapper, victim, 1500.0)
            SeverActionsNativeExt.Native_Kidnap_SetFlag(victim, KIDNAP_FLAG_WITNESSED, true)
            If grabCrimeFac
                ; The DOER carries the bounty (user decision): a witnessed
                ; grab charges the kidnapper's own tracked bounty, not the
                ; player's - unless the player somehow did the grabbing.
                SeverActionsNativeExt.Native_Bounty_ModFor(akKidnapper, grabCrimeFac, KIDNAP_BOUNTY)
                SeverActionsNativeExt.Native_Bounty_AddEventFor(akKidnapper, grabCrimeFac, KIDNAP_BOUNTY, "kidnapping", "")
                Debug.Notification("The abduction was witnessed! +" + KIDNAP_BOUNTY + " bounty on " + akKidnapper.GetDisplayName() + ".")
            EndIf
            SkyrimNetApi.RegisterEvent("kidnap_witnessed", \
                "Bystanders witnessed " + akKidnapper.GetDisplayName() + " seizing " + victim.GetDisplayName() + " - word of the abduction will spread.", \
                akKidnapper, victim)
            Debug.Trace("[SeverActions_FollowerManager] Kidnap: grab was WITNESSED")
        EndIf
    EndIf

    ; Victim trails the kidnapper — the arrest escort look: follow package
    ; targeting a LinkedRef with the follow keyword, outranking any travel
    ; package (110 > TravelPackagePriority 100) while loaded.
    If arrest && arrest.SeverActions_FollowGuard_Prisoner && arrest.SeverActions_FollowTargetKW
        SeverActionsNative.LinkedRef_Set(victim, akKidnapper, arrest.SeverActions_FollowTargetKW)
        ActorUtil.AddPackageOverride(victim, arrest.SeverActions_FollowGuard_Prisoner, 110, 1)
        victim.EvaluatePackage()
    EndIf
    SeverActionsNativeExt.Native_Kidnap_SetPhase(victim, 2)  ; no-op: phase already claimed 1->2 at entry

    ; Leg 2 — march to the destination.
    If SeverActionsNativeExt.Native_Kidnap_GetAliasMode(victim) && arrest
        ; ALIAS MODE (arrest-dispatch parity): re-point the target alias at
        ; the destination — the arrest return-leg trick; the kidnapper's
        ; DispatchJog keeps targeting the alias and simply walks on. The
        ; victim rides DispatchPrisonerAlias for high-process persistence
        ; (she NOW needs an alias: her escort AI must keep running unloaded
        ; so the pair emerges from interiors together).
        ObjectReference aliasDest = SeverActionsNativeExt.Native_Kidnap_GetDestAnchor(victim)
        If aliasDest
            arrest.DispatchTargetAlias.Clear()
            arrest.DispatchTargetAlias.ForceRefTo(aliasDest)
            If arrest.DispatchPrisonerAlias && arrest.DispatchPrisonerAlias.GetReference() == None
                arrest.DispatchPrisonerAlias.ForceRefTo(victim)
            EndIf
            ; SWITCH packages (Jog -> Walk), don't reuse: a running package's
            ; procedure caches its target ref, so re-pointing the alias alone
            ; leaves the kidnapper chasing the VICTIM forever (round-7:
            ; "Idolaf is following Saadia around"). The arrest return leg
            ; does exactly this swap for the same reason — the package
            ; identity change forces a fresh evaluation against the alias.
            If arrest.SeverActions_DispatchJog
                ActorUtil.RemovePackageOverride(akKidnapper, arrest.SeverActions_DispatchJog)
            EndIf
            If arrest.SeverActions_DispatchWalk
                ActorUtil.AddPackageOverride(akKidnapper, arrest.SeverActions_DispatchWalk, arrest.PackagePriority, 1)
            EndIf
            akKidnapper.EvaluatePackage()
            SeverActionsNativeExt.Native_Kidnap_SetLegDeadline(victim, Utility.GetCurrentGameTime() + 0.5)
            Debug.Trace("[SeverActions_FollowerManager] Kidnap: leg 2 (alias mode) - target alias re-pointed + Jog->Walk package swap")
        Else
            ; No destination survived — bind where they stand.
            _BindCaptive(victim, akKidnapper)
            Return
        EndIf
    Else
        ; FALLBACK — slot travel flow (its alias is a persistence pin too):
        ; kidnapper travels by place name; the victim gets her OWN slot to
        ; the same place so she stays high-process, with the escort override
        ; on top so she trails him while loaded. Arrival detected by
        ; KidnapTick polling SeverTravel_State.
        _EndKidnapTravel(akKidnapper)  ; strip the leg-1 override/registration
        String destName = SeverActionsNativeExt.Native_Kidnap_GetDestLabel(victim)
        SeverActions_Travel travel = GetTravelScript()
        Bool started = false
        If travel && destName != ""
            started = travel.DoTravelToPlace(akKidnapper, destName, 48.0, false, travel.SPEED_JOG)
            travel.DoTravelToPlace(victim, destName, 48.0, false, travel.SPEED_JOG)
            ; Re-assert the escort on top of her slot's travel package.
            If arrest && arrest.SeverActions_FollowGuard_Prisoner
                ActorUtil.AddPackageOverride(victim, arrest.SeverActions_FollowGuard_Prisoner, 110, 1)
                victim.EvaluatePackage()
            EndIf
        EndIf
        Debug.Trace("[SeverActions_FollowerManager] Kidnap: leg 2 (slot fallback) started=" + started + " dest '" + destName + "'")
        If !started
            ; Degraded: slot flow refused (no free slot / unresolvable) —
            ; bind where they stand rather than stranding the pair.
            _BindCaptive(victim, akKidnapper)
            Return
        EndIf
    EndIf

    ; The bound-hands MARCH look: the cuffs ITEM alone does not pose the
    ; hands — the arrest system pairs it with the standing-bound offset
    ; idle, which persists through walking (PerformArrest does exactly
    ; this). Played AFTER all the leg-2 package work above so no
    ; EvaluatePackage drops it; _BindCaptive's kneel branch resets to the
    ; default state before the furniture supplies its own pose.
    If arrest && arrest.OffsetBoundStandingStart
        victim.PlayIdle(arrest.OffsetBoundStandingStart)
    EndIf

    If SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_RESTRAINT)
        SkyrimNetApi.RegisterPersistentEvent( \
            akKidnapper.GetDisplayName() + " is openly escorting the restrained " + victim.GetDisplayName() + " to a new place of holding.", \
            akKidnapper, victim)
        Debug.Notification(akKidnapper.GetDisplayName() + " is moving " + victim.GetDisplayName() + ".")
    Else
        SkyrimNetApi.RegisterPersistentEvent( \
            akKidnapper.GetDisplayName() + " has seized " + victim.GetDisplayName() + " and is marching them off.", \
            akKidnapper, victim)
        Debug.Notification(akKidnapper.GetDisplayName() + " has seized " + victim.GetDisplayName() + ".")
    EndIf
EndFunction

Function _OnKidnapTransportResolved(Actor akKidnapper, String status)
    {Leg 2 done — bind + hood at the destination. A non-arrived terminal
     status force-finalizes off-screen (the OffscreenEscortFinalizer idea):
     teleport the pair to the marker, then bind. The same relocation ALSO
     covers "arrived" when the kidnapper isn't actually at the destination —
     an interior dest gives the arrival monitor cross-cell distance garbage
     and it can declare arrival seconds in (log-confirmed: 2.6s "arrival"
     to a marker inside Arcadia's Cauldron from the Whiterun street, which
     bound the victim mid-street).}
    Actor victim = SeverActionsNativeExt.Native_Kidnap_FindVictimOf(akKidnapper)
    SeverActions_Travel travelSys = GetTravelScript()
    If !victim || victim.IsDead()
        If victim
            _DeleteKidnapHomeMarker(victim)
            SeverActionsNativeExt.Native_Kidnap_Clear(victim)
        EndIf
        _EndKidnapTravel(akKidnapper)
        _EndDispatchAliases(akKidnapper, victim)
        If travelSys
            travelSys.CancelTravel(akKidnapper, false)
        EndIf
        Return
    EndIf
    ; Tear down the slot travel (alias, packages, waiting state) BEFORE the
    ; bind so its arrival-sandbox doesn't fight the guard anchor. The slot's
    ; orchestrator handle is already terminal here, so no "cancelled" event
    ; fires back at us.
    If travelSys
        travelSys.CancelTravel(akKidnapper, false)
    EndIf
    ObjectReference destMarker = SeverActionsNativeExt.Native_Kidnap_GetDestAnchor(victim)
    If destMarker
        Bool needsRelocate = (status != "arrived")
        If !needsRelocate
            needsRelocate = (akKidnapper.GetParentCell() != destMarker.GetParentCell()) \
                || (akKidnapper.GetDistance(destMarker) > 600.0)
        EndIf
        If needsRelocate
            akKidnapper.MoveTo(destMarker)
        EndIf
    EndIf
    If victim.GetParentCell() != akKidnapper.GetParentCell() || victim.GetDistance(akKidnapper) > 400.0
        victim.MoveTo(akKidnapper)
    EndIf
    _BindCaptive(victim, akKidnapper)
EndFunction

Function _BindCaptive(Actor akVictim, Actor akKidnapper, Bool abGuard = true)
    {THE SHACK TREATMENT: the real BoundCaptiveMarker (force-persistent,
     placed at the destination anchor) driven by the vanilla-copy Sit
     package via the FurnitureTargetKW LinkedRef, plus the Execution Hood.
     abGuard=false skips guard duty for the kidnapper (used when the player
     RECALLED them mid-march — they bind the victim on the spot and answer
     the call instead of standing watch).}
    ; The kidnapper's job is done — drop their travel override + traveler
    ; registration and hand back the borrowed dispatch aliases so normal
    ; (follower) AI resumes and the arrest system gets its apparatus back.
    _EndKidnapTravel(akKidnapper)
    _EndDispatchAliases(akKidnapper, akVictim)

    ; Double-bind guard (audit): _BindCaptive is reachable from three async
    ; callers; a second call used to place a SECOND force-persistent marker
    ; and orphan the first forever (SetHeld only stores one FormID). If a
    ; hold marker already exists, tear the old hold down first - re-binds
    ; (marker heal, recall bind) already arrive with it cleared.
    If SeverActionsNativeExt.Native_Kidnap_GetMarker(akVictim)
        _TearDownHold(akVictim)
    EndIf

    SeverActions_Arrest arrest = GetArrestScript()
    ; Binding re-ties: drop the loose-captivity flag (no-op when never untied).
    SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, KIDNAP_FLAG_UNBOUND, false)
    Bool bindIsRestraint = SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_RESTRAINT)
    ; Trailing check (restraint relocation): the bind fires off the ESCORT's
    ; arrival while the captive may still be walking in behind them. Pinning
    ; a trailing captive stranded them mid-walk short of the hold (and the
    ; moving state ate the pose PlayIdle). Keep the escort-follow package on
    ; them and defer the pin + pose to the phase-3 tick, which completes
    ; both once they close on the marker.
    Bool bindTrailing = bindIsRestraint && akVictim.Is3DLoaded() \
        && (akVictim.GetParentCell() != akKidnapper.GetParentCell() || akVictim.GetDistance(akKidnapper) > 300.0)

    ; End the escort leg + the victim's own persistence slot travel (kept on
    ; a trailing restraint captive — it is what walks them the last stretch).
    If arrest && !bindTrailing
        If arrest.SeverActions_FollowGuard_Prisoner
            ActorUtil.RemovePackageOverride(akVictim, arrest.SeverActions_FollowGuard_Prisoner)
        EndIf
        If arrest.SeverActions_FollowTargetKW
            SeverActionsNative.LinkedRef_Clear(akVictim, arrest.SeverActions_FollowTargetKW)
        EndIf
    EndIf
    SeverActions_Travel travelBind = GetTravelScript()
    If travelBind
        travelBind.CancelTravel(akVictim, false)
    EndIf

    ; THE SHACK TREATMENT — the real BoundCaptiveMarker furniture (user
    ; spec), driven the vanilla way: a pure Sit package targeting the
    ; FurnitureTargetKW linked ref. Furniture-driven pose self-restores on
    ; cell reload via normal package re-eval; no restraint/idle layering
    ; needed. Deliberately NOT registered with FurnitureManager (distance
    ; auto-cleanup would free the captive) — the orphan scanners have
    ; kidnap exemptions instead.
    ObjectReference holdMarker = None
    SeverActions_Furniture furn = GetFurnitureScript()
    Furniture markerBase = Game.GetFormFromFile(KIDNAP_MARKER_FORMID, "Skyrim.esm") as Furniture
    Package sitPkg = Game.GetFormFromFile(KIDNAP_SIT_PKG_FORMID, "SeverActions.esp") as Package
    ; Place the bound marker AT THE RESOLVED DESTINATION MARKER — the same
    ; CK-placed, persistent, navmeshed ref the travel system parks arrivals
    ; at. PlaceAtMe from a persistent world ref is deterministic and works
    ; identically whether the actors are loaded or not (PlaceAtMe off an
    ; unloaded ACTOR is the flaky case — round-10 put the marker in the
    ; street). Actor-position placement is only the no-destination fallback.
    ; abForcePersist=TRUE is load-bearing: the shack's marker is CK-placed
    ; (persistent — its data always exists in memory), but a default
    ; PlaceAtMe ref UNLOADS with its cell, and the captive's low-process AI
    ; evaluating the Sit package from outside the cell then dereferences
    ; the gone furniture (crash-2026-07-06-18-56-33: BGSProcedureSit CTD
    ; while the player stood OUTSIDE Tundra Homestead).
    ObjectReference destAnchor = SeverActionsNativeExt.Native_Kidnap_GetDestAnchor(akVictim)
    ; destLabel freshness (audit): a bind with no destination anchor (recall
    ; bind-on-the-spot, degraded grab binds) kept narrating the ORIGINAL
    ; ordered destination in kidnap_context.
    If !destAnchor
        SeverActionsNativeExt.Native_Kidnap_SetDestLabel(akVictim, "where they were taken")
    EndIf
    If markerBase && sitPkg && furn && furn.SeverActions_FurnitureTargetKeyword
        If destAnchor
            holdMarker = destAnchor.PlaceAtMe(markerBase, 1, true)
        EndIf
        ; In-place bind (restrain, or any hold with no resolved destination):
        ; place at the CAPTOR, not the victim. The captor is standing at a
        ; known-reachable navmesh spot; placing at the victim drops the marker
        ; under a captive already standing INSIDE the furniture volume, and the
        ; engine's furniture-entry then fails to seat them — they end up
        ; bound-but-standing (restrain kneel-pose bug). The victim is snapped
        ; onto the marker below so they enter the sit cleanly.
        If !holdMarker
            holdMarker = akKidnapper.PlaceAtMe(markerBase, 1, true)
        EndIf
        If !holdMarker
            holdMarker = akVictim.PlaceAtMe(markerBase, 1, true)
        EndIf
        If holdMarker
            ; Two hold styles share this marker:
            ;  - KIDNAP (kneel) is FURNITURE-driven: the victim arrives fresh
            ;    from travel a short walk from a good marker and EvaluatePackage
            ;    (below) paths them INTO the furniture entry — that approach-
            ;    then-enter is what engages the kneel pose. Teleporting them ONTO
            ;    the marker drops them inside the volume and entry no-ops, so
            ;    only MoveTo when genuinely far (different cell or a stretched
            ;    march that outran the marker).
            ;  - RESTRAIN (standing bound) does NOT use the furniture: in-place
            ;    furniture entry proved unreliable on a busy NPC (they FROZE
            ;    instead of kneeling — no clean approach path from behind a shop
            ;    counter, and spawning them on the marker never seats them).
            ;    Pin them where they stand and play the arrest system's proven
            ;    hands-bound standing offset idle (played after EvaluatePackage
            ;    below so a package re-eval can't overwrite it). Re-pinned every
            ;    tick + re-posed on load (idles don't survive a save/reload);
            ;    released by _UnbindCaptive (SetDontMove(false) +
            ;    IdleForceDefaultState).
            If bindIsRestraint
                If !bindTrailing
                    akVictim.SetDontMove(true)
                EndIf
            Else
                If akVictim.GetParentCell() != holdMarker.GetParentCell() || akVictim.GetDistance(holdMarker) > 300.0
                    akVictim.MoveTo(holdMarker)
                EndIf
                SeverActionsNativeExt.LinkedRef_SetPermanent(akVictim, holdMarker, furn.SeverActions_FurnitureTargetKeyword)
                ActorUtil.AddPackageOverride(akVictim, sitPkg, 95, 1)
                ; Alias-held captivity (KDNP v6): ALSO seat the sit package
                ; through the captive-alias pool — an alias package re-applies
                ; natively on cell load, where the override above drops on 3D
                ; unload. Both stay (belt and suspenders for this first
                ; iteration), as does the FurnitureTargetKW LinkedRef — the
                ; alias package anchors through it, same as the override.
                Int captiveAliasIdx = FindFreeCaptiveAlias()
                If captiveAliasIdx >= 0
                    ReferenceAlias cal = GetCaptiveAlias(captiveAliasIdx)
                    If cal
                        cal.ForceRefTo(akVictim)
                        SeverActionsNativeExt.Native_Kidnap_SetAliasIndex(akVictim, captiveAliasIdx)
                        DebugMsg("CaptiveAlias: seated " + akVictim.GetDisplayName() + " in alias " + captiveAliasIdx)
                    EndIf
                ElseIf GetCaptiveQuest()
                    DebugMsg("CaptiveAlias: pool exhausted (" + CAPTIVE_ALIAS_POOL_SIZE + " slots) — " + akVictim.GetDisplayName() + " stays on the override hold")
                EndIf
            EndIf
            ; The guard anchors to the marker (at the captor) in either style.
            If akKidnapper.GetParentCell() != holdMarker.GetParentCell()
                akKidnapper.MoveTo(holdMarker)
            EndIf
            ; Marker schema 2 = persistent marker. KidnapTick's heal strips
            ; pre-v2 holds (their markers unload with the cell and the Sit
            ; package CTDs low-process).
            SeverActionsNativeExt.Native_Kidnap_SetMarkerSchema(akVictim, 2)
        EndIf
    EndIf
    Debug.Trace("[SeverActions_FollowerManager] Kidnap: binding " + akVictim.GetDisplayName() + " (marker=" + holdMarker + ", cell match=" + (akVictim.GetParentCell() == akKidnapper.GetParentCell()) + ")")

    ; Hood — the shack captives' Execution Hood, equip-locked. SKIPPED for a
    ; RESTRAINT hold: an open, ordered restraint leaves them bare-headed —
    ; they see everything and everyone (the kidnap_context decorator narrates
    ; accordingly). This gate also covers MoveCaptive's re-bind and the
    ; KidnapTick marker heal, which both route back through here.
    If !bindIsRestraint
        ; Kidnap KNEEL: the furniture supplies the bound-hands pose — drop the
        ; march's bound-hands OFFSET first (it would layer over the kneel) and
        ; the walk cuffs (equipped at seizure by _OnKidnapGrabResolved) to keep
        ; the verified kneel look clean. The standing restraint hold KEEPS its
        ; cuffs and its offset.
        Debug.SendAnimationEvent(akVictim, "IdleForceDefaultState")
        If arrest && arrest.SeverActions_PrisonerCuffs
            akVictim.UnequipItem(arrest.SeverActions_PrisonerCuffs, false, true)
            akVictim.RemoveItem(arrest.SeverActions_PrisonerCuffs, 1, true)
        EndIf
        Armor hood = Game.GetFormFromFile(KIDNAP_HOOD_FORMID, "Skyrim.esm") as Armor
        If hood
            akVictim.EquipItem(hood, true, true)  ; abPreventRemoval, abSilent
        EndIf
    EndIf

    akVictim.EvaluatePackage()
    ; Standing-bound restraint: play the hands-bound offset LAST, after the
    ; package re-eval, so nothing overwrites it (the furniture kneel is driven
    ; by the sit package + EvaluatePackage above and needs no idle). The
    ; posed flag pairs with KidnapTick's unloaded->loaded edge re-play.
    If bindIsRestraint
        If bindTrailing
            ; Deferred: the phase-3 tick pins + poses once they close on the
            ; marker (flag left 0; the march offset keeps the look meanwhile).
            StorageUtil.SetIntValue(akVictim, "SeverRestrain_Posed", 0)
        ElseIf arrest && arrest.OffsetBoundStandingStart
            If akVictim.PlayIdle(arrest.OffsetBoundStandingStart)
                StorageUtil.SetIntValue(akVictim, "SeverRestrain_Posed", 1)
            Else
                StorageUtil.SetIntValue(akVictim, "SeverRestrain_Posed", 0)
            EndIf
        EndIf
    EndIf
    SeverActionsNativeExt.Native_Kidnap_SetHeld(akVictim, holdMarker)

    ; Move-here pin (MoveCaptiveHere): the pin's only job was to be the
    ; march's destination anchor — once the hold marker stands at its spot,
    ; the pin is dead weight. Force-persistent refs never unload on their
    ; own, so an un-deleted pin would leak permanently. Cleanup lands HERE
    ; because this is the single bind choke point (march completion, recall
    ; bind-on-the-spot, and the KidnapTick marker heal all route through
    ; _BindCaptive), so every move-here bind cleans up exactly once.
    ; Safe no-op for non-move-here binds.
    ObjectReference movePin = StorageUtil.GetFormValue(akVictim, "SeverKidnap_MovePin") as ObjectReference
    If movePin
        movePin.Disable()
        movePin.Delete()
        StorageUtil.UnsetFormValue(akVictim, "SeverKidnap_MovePin")
    EndIf

    If abGuard
        ; The kidnapper stands guard, ANCHORED. Sandbox() gives the standard
        ; relax-state bookkeeping (WaitingForPlayer, waiting faction, recall
        ; paths); the tight KidnapGuardSandbox (r=180) pinned to the hold
        ; marker keeps them in the room (LeisureSandbox is anchorless and
        ; leaked out shop doors). Released by ReleaseCaptive, abort, or the
        ; follow-recall hook.
        ; Sandbox() bookkeeping (WaitingForPlayer, waiting faction, recall
        ; paths) is FOLLOWER state — a vanilla guard or housecarl acting as
        ; the restrainer must not be threaded into follower machinery; the
        ; anchored guard package below suffices for them and is fully
        ; unwound by _EndGuardDuty.
        If IsRegisteredFollower(akKidnapper)
            SeverActions_Follow followSys = GetFollowScript()
            If followSys
                followSys.Sandbox(akKidnapper)
            EndIf
        EndIf
        Package guardPkg = Game.GetFormFromFile(KIDNAP_GUARD_PKG_FORMID, "SeverActions.esp") as Package
        If holdMarker && guardPkg && arrest && arrest.SeverActions_SandboxAnchorKW
            SeverActionsNativeExt.LinkedRef_SetPermanent(akKidnapper, holdMarker, arrest.SeverActions_SandboxAnchorKW)
            ; Re-bind after loose captivity: drop the wide watch sandbox so
            ; the tight guard package is unambiguous at its priority.
            If arrest.SeverActions_PrisonerSandBox
                ActorUtil.RemovePackageOverride(akKidnapper, arrest.SeverActions_PrisonerSandBox)
            EndIf
            ActorUtil.AddPackageOverride(akKidnapper, guardPkg, 110, 1)
            akKidnapper.EvaluatePackage()
            ; On-guard flag: KidnapTick's station heal re-posts a strayed
            ; guard (engine teammate drag on fast travel, sandbox door leak,
            ; spurious follow re-asserts) while this is set. Cleared by
            ; _EndGuardDuty on any legitimate stand-down.
            StorageUtil.SetIntValue(akKidnapper, "SeverKidnap_OnGuard", 1)
        EndIf
    EndIf
    ; Recall hook: StartFollowing fires this when the player calls the NPC
    ; back — free to claim on our quest form (no SA sibling registers it;
    ; Hearth's listener is a different form, so no one-callback collision).
    RegisterForModEvent("SeverActions_FollowerCalledByPlayer", "OnKidnapGuardRecall")

    If bindIsRestraint
        SkyrimNetApi.RegisterPersistentEvent( \
            akKidnapper.GetDisplayName() + " has RESTRAINED " + akVictim.GetDisplayName() + " - hands bound, held standing in plain sight until someone decides what happens to them.", \
            akKidnapper, akVictim)
        Debug.Notification(akVictim.GetDisplayName() + " has been restrained.")
    Else
        SkyrimNetApi.RegisterPersistentEvent( \
            akKidnapper.GetDisplayName() + " has delivered " + akVictim.GetDisplayName() + ", now bound and hooded, as instructed.", \
            akKidnapper, akVictim)
        Debug.Notification(akVictim.GetDisplayName() + " has been bound and hooded.")
    EndIf
EndFunction

Function _FireKidnapReleaseConsequences(Actor akVictim)
    {V2 Slice 1: the victim walks free after actually being SEIZED (phase 2+)
     — they know exactly what happened and who did it. A pre-grab abort
     (phase 1) is a non-event: nothing happened to them. Two effects:
     (1) a high-importance grudge memory on the victim (anchors every
     post-release conversation), and (2) if the grab was never witnessed,
     the freed victim reports it — the tracked bounty lands now instead.
     Call BEFORE Native_Kidnap_Clear (reads the entry).}
    If !akVictim || SeverActionsNativeExt.Native_Kidnap_GetPhase(akVictim) < 2
        Return
    EndIf

    Actor kd = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(akVictim)
    String kdName = "someone"
    If kd
        kdName = kd.GetDisplayName()
    EndIf
    String plName = Game.GetPlayer().GetDisplayName()
    Bool relRansomPaid = SeverActionsNativeExt.Native_Kidnap_GetRansomState(akVictim) == KIDNAP_RANSOM_PAID
    If SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_RESTRAINT)
        ; Restraint memory — indignity, not abduction trauma. Lower weight:
        ; an open, ordered hold reads as rough treatment, not a life-scar.
        SeverActionsNative.Native_AddMemory(akVictim, \
            "I was restrained by " + kdName + " - my hands bound, made to stand helpless in front of everyone until they saw fit to release me. I know exactly who did it, and I remember how it felt.", \
            0.6, "EXPERIENCE", "indignant", "", "[\"restrained\"]", "[]")
    ElseIf relRansomPaid
        ; Ransomed home per the bargain: still a grudge, but the victim
        ; acknowledges the deal was honored - the LLM should not play them
        ; as intending to report a matter their own hold settled with coin.
        SeverActionsNative.Native_AddMemory(akVictim, \
            "I was abducted by " + kdName + " and held for ransom on " + plName + "'s orders. My people paid for my return, and - I will grant this much - the bargain was honored: I was released as agreed. The coin settled the matter in the law's eyes, but I remember every hour of it.", \
            0.8, "EXPERIENCE", "bitter", "", "[\"kidnap\",\"grudge\"]", "[]")
    Else
        SeverActionsNative.Native_AddMemory(akVictim, \
            "I was abducted by " + kdName + " - seized, bound, and hooded, held against my will on " + plName + "'s orders. I know " + kdName + "'s voice and face, and I will not forgive or forget what was done to me.", \
            0.9, "EXPERIENCE", "traumatized", "", "[\"kidnap\",\"grudge\"]", "[]")
    EndIf

    ; Interrogation retirement (audit): the duress directive is present-tense
    ; ("I give up secrets when pressed") and would otherwise shape every
    ; post-release conversation forever. Supersede it with a closed,
    ; past-tense record.
    If SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_INTERROGATED)
        SeverActionsNative.Native_AddMemory(akVictim, \
            "While I was held, I was interrogated and gave up things I knew under duress. That is over now - I am free, and I owe my captors nothing further.", \
            0.6, "EXPERIENCE", "resentful", "", "[\"interrogation\"]", "[]")
    EndIf

    If relRansomPaid
        ; PAID ransom + release = the bargain HONORED (user report: Idolaf
        ; released Hulda per the deal and she reported him anyway). The coin
        ; WAS the settlement - the hold bought her back, so the freed victim
        ; does not report a matter their own court closed. A witnessed grab
        ; already charged its bounty at the grab and keeps it.
        Debug.Trace("[SeverActions_FollowerManager] Kidnap: release completes a PAID ransom - no report, the coin settled it")
    ElseIf !SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_WITNESSED)
        Faction repFac = SeverActionsNativeExt.Native_Kidnap_GetGrabFaction(akVictim)
        If repFac
            ; The freed victim names the DOER - they know the kidnapper's
            ; face (the grudge memory says so). kd None falls back to the
            ; player entry inside the native.
            SeverActionsNativeExt.Native_Bounty_ModFor(kd, repFac, KIDNAP_BOUNTY)
            SeverActionsNativeExt.Native_Bounty_AddEventFor(kd, repFac, KIDNAP_BOUNTY, "kidnapping", "")
            Debug.Notification(akVictim.GetDisplayName() + " reported the abduction. +" + KIDNAP_BOUNTY + " bounty on " + kdName + ".")
            Debug.Trace("[SeverActions_FollowerManager] Kidnap: released victim reported the crime")
        EndIf
    EndIf
EndFunction

Bool Function _IsCaptiveGuarded(Actor akVictim)
    {Slice 3: is anyone watching this captive? Guards: the player nearby,
     the kidnapper still on station, any registered follower (posted via
     Wait), or any Enterprises retainer — a hired jailer via Assign Work at
     the hold site counts during their work hours because they are
     physically there. Same-cell + radius; unloaded persistent actors keep
     their parked position, so this works while the player is away.}
    Cell c = akVictim.GetParentCell()
    If !c
        Return true  ; indeterminate — fail safe, no escape credit
    EndIf
    Actor player = Game.GetPlayer()
    If player.GetParentCell() == c && player.GetDistance(akVictim) <= KIDNAP_GUARD_RADIUS
        Return true
    EndIf
    Actor kd = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(akVictim)
    If kd && !kd.IsDead() && kd.GetParentCell() == c && kd.GetDistance(akVictim) <= KIDNAP_GUARD_RADIUS
        Return true
    EndIf
    Actor[] fl = GetAllFollowers()
    Int i = 0
    While i < fl.Length
        If fl[i] && fl[i] != kd && fl[i] != akVictim && !fl[i].IsDead() \
            && fl[i].GetParentCell() == c && fl[i].GetDistance(akVictim) <= KIDNAP_GUARD_RADIUS
            Return true
        EndIf
        i += 1
    EndWhile
    Int rc = SeverActionsNativeExt2.Venture_Count()
    i = 0
    While i < rc
        Actor r = SeverActionsNativeExt2.Venture_GetAssigneeAt(i)
        ; r != akVictim (audit): a kidnapped RETAINER counted as their own
        ; jailer (distance 0 always passes) - escape sim permanently dead.
        If r && r != akVictim && !r.IsDead() && r.GetParentCell() == c && r.GetDistance(akVictim) <= KIDNAP_GUARD_RADIUS
            Return true
        EndIf
        i += 1
    EndWhile
    Return false
EndFunction

Function _DeleteKidnapHomeMarker(Actor akVictim)
    {Delete the persistent pre-grab home marker. Call before every
     Native_Kidnap_Clear — a cleared entry orphans the ref forever.}
    ObjectReference hm = SeverActionsNativeExt.Native_Kidnap_GetHomeMarker(akVictim)
    If hm
        hm.Disable()
        hm.Delete()
    EndIf
EndFunction

Function _EscapeCaptive(Actor akVictim)
    {Slice 3: nobody has watched them for KIDNAP_ESCAPE_ROLL_HOURS+ — they work
     their bonds loose and flee home (the persistent marker dropped at the
     grab site). Full release consequences fire: they know exactly who did
     this, and an unwitnessed grab gets reported the moment they're free.}
    Debug.Trace("[SeverActions_FollowerManager] Kidnap: " + akVictim.GetDisplayName() + " ESCAPES (unguarded)")
    ; Capture narration state BEFORE the entry is cleared below.
    Bool escRestraint = SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_RESTRAINT)
    Bool escRansomPending = SeverActionsNativeExt.Native_Kidnap_GetRansomState(akVictim) == KIDNAP_RANSOM_PENDING
    Actor kd = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(akVictim)
    _FireKidnapReleaseConsequences(akVictim)
    If kd
        _EndGuardDuty(kd)
        _EndDispatchAliases(kd, akVictim)
    EndIf
    _FreeCaptiveAlias(akVictim)  ; _UnbindCaptive does this too — explicit for clarity
    _UnbindCaptive(akVictim)
    ; Flee home — teleport only while unobserved (never in front of the
    ; player; an unguarded captive is off-screen by definition, but a
    ; same-cell-hidden edge case shouldn't pop them across the room).
    ObjectReference home = SeverActionsNativeExt.Native_Kidnap_GetHomeMarker(akVictim)
    If home && !akVictim.Is3DLoaded()
        akVictim.MoveTo(home)
    EndIf
    _DeleteKidnapHomeMarker(akVictim)
    SeverActionsNativeExt.Native_Kidnap_Clear(akVictim)

    If escRestraint
        ; Restraint fiction (audit): a never-moved restraint has no home
        ; marker and no "fled home" - they simply slip loose where they stand.
        SkyrimNetApi.RegisterPersistentEvent( \
            akVictim.GetDisplayName() + " slipped their bonds - left unwatched too long, they worked their hands free and walked off.", \
            Game.GetPlayer(), akVictim)
    Else
        SkyrimNetApi.RegisterPersistentEvent( \
            akVictim.GetDisplayName() + " has ESCAPED captivity - left unguarded too long, they worked free of their bonds and fled home.", \
            Game.GetPlayer(), akVictim)
    EndIf
    If escRansomPending
        ; Dangling ransom (audit): the demand was outstanding - the player was
        ; told an answer would come, and it never would have.
        SkyrimNetApi.RegisterPersistentEvent( \
            "Word spreads that " + akVictim.GetDisplayName() + " is free - the ransom demand collapses unanswered.", \
            Game.GetPlayer(), akVictim)
    EndIf
    Debug.Notification(akVictim.GetDisplayName() + " has escaped captivity!")
EndFunction

Function _OnCaptiveDied(Actor akVictim)
    {Slice 3: a captive died during a kidnap — that is murder. The hold
     charges it once it knows to blame the player (witnessed grab, or the
     disappearance was already the talk of the town); a completely quiet
     captivity yields no legal trail, just the deed. Cleans up all state —
     dead captives used to leave a lingering entry.}
    String vName = akVictim.GetDisplayName()
    Int diedPhase = SeverActionsNativeExt.Native_Kidnap_GetPhase(akVictim)
    Bool diedRansomPending = SeverActionsNativeExt.Native_Kidnap_GetRansomState(akVictim) == KIDNAP_RANSOM_PENDING
    Debug.Trace("[SeverActions_FollowerManager] Kidnap: " + vName + " DIED in captivity (phase " + diedPhase + ")")

    Faction fac = SeverActionsNativeExt.Native_Kidnap_GetGrabFaction(akVictim)
    Bool holdKnows = SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_WITNESSED) \
        || SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_GOSSIP)
    ; Phase gate (audit): a phase-1 target killed by unrelated causes (dragon,
    ; vampire raid) is NOT a captivity death - narrating "died in captivity,
    ; bound and hooded" injected false world state. Quiet cleanup instead.
    If diedPhase >= 2 && fac && holdKnows
        ; Murder charges the captor's own bounty (offender axis).
        Actor diedCaptor = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(akVictim)
        SeverActionsNativeExt.Native_Bounty_ModFor(diedCaptor, fac, KIDNAP_BOUNTY)
        SeverActionsNativeExt.Native_Bounty_AddEventFor(diedCaptor, fac, KIDNAP_BOUNTY, "murder", "")
        Debug.Notification(vName + " died in captivity. The hold will call it murder.")
        String vHold = SeverActionsNativeExt.Hold_GetHoldName(akVictim)
        If vHold != ""
            AppendGossip(vHold, vName + " is dead - vanished, and now dead. Someone took them, and someone let them die")
        EndIf
    EndIf
    If diedPhase >= 2
        If SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_RESTRAINT)
            SkyrimNetApi.RegisterPersistentEvent( \
                vName + " has died while restrained - hands bound, unable to defend themselves.", \
                Game.GetPlayer(), akVictim)
        Else
            SkyrimNetApi.RegisterPersistentEvent( \
                vName + " has died in captivity, bound and hooded - a death that was entirely preventable.", \
                Game.GetPlayer(), akVictim)
        EndIf
        If diedRansomPending
            SkyrimNetApi.RegisterPersistentEvent( \
                "Word spreads that " + vName + " is dead - the ransom demand collapses, unanswered and unpayable.", \
                Game.GetPlayer(), akVictim)
        EndIf
    EndIf

    ; Cleanup: guard duty, hold marker, home marker, entry. No unbind — the
    ; body stays as it fell; the equip-locked hood stays with it.
    Actor kd = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(akVictim)
    If kd
        _EndGuardDuty(kd)
        _EndDispatchAliases(kd, akVictim)
        ; Travel cleanup (audit): a victim dying mid-leg left the kidnapper's
        ; raw travel override + traveler registration and the victim's
        ; persistence slot live until the travel system's own watchdog.
        _EndKidnapTravel(kd)
        SeverActions_Travel travelDied = GetTravelScript()
        If travelDied
            travelDied.CancelTravel(kd, false)
            travelDied.CancelTravel(akVictim, false)
        EndIf
        ; A restrain target who died mid-WALK-UP (combat, dragon): strip the
        ; restrainer's approach apparatus too, or they follow the corpse.
        If SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_RESTRAINT)
            SeverActionsNativeExt.Arrival_Cancel(kd)
            _EndRestrainApproach(kd)
        EndIf
    EndIf
    ObjectReference holdM = SeverActionsNativeExt.Native_Kidnap_GetMarker(akVictim)
    If holdM
        holdM.Disable()
        holdM.Delete()
    EndIf
    ; The body stays as it fell (no unbind), but the alias seat must not —
    ; a dead captive holds no pool slot.
    _FreeCaptiveAlias(akVictim)
    _DeleteKidnapHomeMarker(akVictim)
    SeverActionsNativeExt.Native_Kidnap_Clear(akVictim)
EndFunction

Function InterrogateCaptive(Actor akInterrogator, String targetName)
    {Slice 3: press a held captive for what they know. The duress directive
     cracks their resolve — the conditional-knowledge and memory context
     they already carry in their prompts becomes fair game to reveal.
     Called by SkyrimNet via interrogatecaptive.yaml and the Prisma
     Actions page.}
    ; Kidnap OR restrain (see MoveCaptive): a restrained captive must be
    ; manageable under default settings.
    If !akInterrogator || akInterrogator.IsDead() || (!EnableKidnapActions && !EnableRestrainAction)
        Return
    EndIf
    If _RejectIfBoundActor(akInterrogator, "interrogate anyone")
        Return
    EndIf

    Actor victim = None
    Actor[] victims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    If !victims || victims.Length == 0
        Return
    EndIf
    If victims.Length == 1 && targetName == ""
        victim = victims[0]
    Else
        Int i = 0
        While i < victims.Length && !victim
            If victims[i] && StringUtil.Find(victims[i].GetDisplayName(), targetName) >= 0
                victim = victims[i]
            EndIf
            i += 1
        EndWhile
    EndIf
    If !victim || SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) != 3
        Return  ; only HELD captives can be interrogated
    EndIf

    String iName = akInterrogator.GetDisplayName()
    String vName = victim.GetDisplayName()
    ; The duress directive rides a high-importance memory (the thug-directive
    ; pattern) so it shapes the captive's replies for the whole session.
    ; Written ONCE per captivity (audit: repeat calls stacked duplicate
    ; 0.95-importance memories) and branched on the restraint flag (audit:
    ; a restraint captive has no hood and can see - the old text contradicted
    ; their own kidnap_context in the same prompt).
    If !SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_INTERROGATED)
        SeverActionsNativeExt.Native_Kidnap_SetFlag(victim, KIDNAP_FLAG_INTERROGATED, true)
        If SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_RESTRAINT)
            SeverActionsNative.Native_AddMemory(victim, \
                "I am bound and held standing in the open, being INTERROGATED by " + iName + ". I cannot hold out much longer - when they press me, I give up TRUE things I actually know: secrets, names, hidden valuables, anything in my knowledge or memories they might want. I may try to bargain what I know for my release, but I do not invent lies - I am too frightened to risk being caught in one.", \
                0.95, "EXPERIENCE", "fear", "", "[\"restrained\",\"interrogation\"]", "[]")
        Else
            SeverActionsNative.Native_AddMemory(victim, \
                "I am bound, hooded, and being INTERROGATED by " + iName + ". I cannot hold out much longer - when they press me, I give up TRUE things I actually know: secrets, names, hidden valuables, anything in my knowledge or memories they might want. I may try to bargain what I know for food, water, or my freedom, but I do not invent lies - I am too frightened to risk being caught in one.", \
                0.95, "EXPERIENCE", "fear", "", "[\"kidnap\",\"interrogation\"]", "[]")
        EndIf
    EndIf
    SkyrimNetApi.RegisterPersistentEvent( \
        iName + " begins interrogating the captive " + vName + ", pressing them for anything they know - secrets, names, valuables.", \
        akInterrogator, victim)
    Debug.Notification(iName + " is interrogating " + vName + ".")
EndFunction

Function LeashCaptiveByName(Actor akLeader, String targetName)
    {SkyrimNet action (leashcaptive.yaml): the speaker takes a held captive
     along, bound. Resolves among ACTIVE captives by name (single captive +
     empty name = that one), same contract as UntieCaptive/ReleaseCaptive.}
    If !akLeader || akLeader.IsDead() || (!EnableKidnapActions && !EnableRestrainAction)
        Return
    EndIf
    If _RejectIfBoundActor(akLeader, "lead anyone anywhere")
        Return
    EndIf
    Actor victim = _ResolveCaptiveByName(targetName)
    If !victim
        SkyrimNetApi.RegisterEvent("kidnap_failed",             akLeader.GetDisplayName() + " looks for a captive to bring along, but holds no one" + _NameClause(targetName) + ".",             akLeader, None)
        Return
    EndIf
    If SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_LEASHED)
        Debug.Notification(victim.GetDisplayName() + " is already being led.")
        Return
    EndIf
    If !LeashCaptive(victim, akLeader)
        SkyrimNetApi.RegisterEvent("kidnap_failed",             akLeader.GetDisplayName() + " cannot lead " + victim.GetDisplayName() + " along right now.",             akLeader, None)
    EndIf
EndFunction

Function UnleashCaptiveByName(Actor akSpeaker, String targetName)
    {SkyrimNet action (unleashcaptive.yaml): stop leading a captive and hold
     them where they stand. Name-resolved like the sibling actions.}
    If !akSpeaker || akSpeaker.IsDead() || (!EnableKidnapActions && !EnableRestrainAction)
        Return
    EndIf
    If _RejectIfBoundActor(akSpeaker, "hold anyone")
        Return
    EndIf
    Actor victim = _ResolveCaptiveByName(targetName)
    If !victim || !SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_LEASHED)
        SkyrimNetApi.RegisterEvent("kidnap_failed",             akSpeaker.GetDisplayName() + " goes to halt a captive they are leading, but is leading no one" + _NameClause(targetName) + ".",             akSpeaker, None)
        Return
    EndIf
    UnleashCaptive(victim)
    SkyrimNetApi.RegisterPersistentEvent(         akSpeaker.GetDisplayName() + " halts " + victim.GetDisplayName() + " and holds them in place, hands still bound.",         akSpeaker, victim)
EndFunction

Actor Function _ResolveCaptiveByName(String targetName)
    {Shared resolver for the captive-verb actions: among ACTIVE victims only
     (never a global scan). A single captive matches an empty name; otherwise
     substring-match the display name.}
    Actor[] victims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    If !victims || victims.Length == 0
        Return None
    EndIf
    If victims.Length == 1 && targetName == ""
        Return victims[0]
    EndIf
    Int i = 0
    While i < victims.Length
        If victims[i] && StringUtil.Find(victims[i].GetDisplayName(), targetName) >= 0
            Return victims[i]
        EndIf
        i += 1
    EndWhile
    Return None
EndFunction

String Function _NameClause(String targetName)
    If targetName == ""
        Return ""
    EndIf
    Return " called " + targetName
EndFunction

Bool Function LeashCaptive(Actor akVictim, Actor akLeader)
    {Put a HELD, bound captive on a leash: they keep their bonds (cuffs, the
     restrained state) but walk behind akLeader on the arrest system's
     escort-follow package (FollowGuard_Prisoner targeting a LinkedRef) instead
     of standing pinned to the hold marker. The kidnap entry stays live - guard
     radius, escape, ransom and interrogation all still apply - and the
     kidnap_context decorator switches to the led-along framing (kFlagLeashed).
     UnleashCaptive re-pins them where they stand. Leader may be the player or
     any NPC. User request 2026-08-23: a restrained NPC should still be able to
     follow the player (or whoever) rather than being frozen in place.}
    If !akVictim || !akLeader || akVictim == akLeader || akVictim.IsDead() || akLeader.IsDead()
        Debug.Trace("[SeverActions_FollowerManager] Leash: refused - bad actors")
        Return False
    EndIf
    Int leashPhase = SeverActionsNativeExt.Native_Kidnap_GetPhase(akVictim)
    If leashPhase != 3
        Debug.Trace("[SeverActions_FollowerManager] Leash: refused - " + akVictim.GetDisplayName() + " phase " + leashPhase + " (need 3 held)")
        Return False   ; only a HELD captive can be leashed
    EndIf
    If SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_UNBOUND)
        Debug.Trace("[SeverActions_FollowerManager] Leash: refused - " + akVictim.GetDisplayName() + " is unbound (loose captivity)")
        Return False   ; loosened bonds - nothing to leash; re-bind via MoveCaptive first
    EndIf
    SeverActions_Arrest arrestL = GetArrestScript()
    If !arrestL || !arrestL.SeverActions_FollowGuard_Prisoner || !arrestL.SeverActions_FollowTargetKW
        Debug.Trace("[SeverActions_FollowerManager] Leash: refused - arrest script/package/keyword unbound")
        Return False
    EndIf
    Debug.Trace("[SeverActions_FollowerManager] Leash: " + akVictim.GetDisplayName() + " -> following " + akLeader.GetDisplayName())

    ; Strip the PIN (sit package + hold LinkedRef + DontMove + idle). The
    ; marker and the store entry stay - UnleashCaptive re-attaches to them.
    SeverActions_Furniture furnL = GetFurnitureScript()
    Package sitPkgL = Game.GetFormFromFile(KIDNAP_SIT_PKG_FORMID, "SeverActions.esp") as Package
    If sitPkgL
        ActorUtil.RemovePackageOverride(akVictim, sitPkgL)
    EndIf
    If furnL && furnL.SeverActions_FurnitureTargetKeyword
        SeverActionsNative.LinkedRef_Clear(akVictim, furnL.SeverActions_FurnitureTargetKeyword)
    EndIf
    akVictim.SetDontMove(false)
    akVictim.SetRestrained(false)
    StorageUtil.SetIntValue(akVictim, "SeverRestrain_Posed", 0)
    Debug.SendAnimationEvent(akVictim, "IdleForceDefaultState")
    ; Bonds STAY as the CUFFS (still equipped - never touched here). Do NOT
    ; SetRestrained(true): that engine flag forbids movement outright, so a
    ; follow package issued move commands against a rooted actor - the
    ; "fighting to move in place" report (2026-08-23). The restraint hold
    ; never used it either (SetDontMove + the standing idle); a walking
    ; captive looks bound through the cuffs, same as the escort march.

    ; Walk behind the leader.
    SeverActionsNative.LinkedRef_Set(akVictim, akLeader, arrestL.SeverActions_FollowTargetKW)
    ActorUtil.AddPackageOverride(akVictim, arrestL.SeverActions_FollowGuard_Prisoner, 95, 1)
    akVictim.EvaluatePackage()
    StorageUtil.SetFormValue(akVictim, "SeverKidnap_LeashLeader", akLeader)
    SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, KIDNAP_FLAG_LEASHED, True)

    ; Pose them bound RIGHT NOW (user ask 2026-08-23): they are stationary at
    ; the moment the leash is applied, so the bound standing idle establishes
    ; the behaviour-graph bound state cleanly and carries into the walk. Without
    ; this the pose only appeared on the next 30s KidnapTick, so a fresh leash
    ; walked with free hands for up to half a minute. Posed=1 so the tick does
    ; not double-play it; it re-poses on each later stop as before.
    If arrestL.OffsetBoundStandingStart && akVictim.PlayIdle(arrestL.OffsetBoundStandingStart)
        StorageUtil.SetIntValue(akVictim, "SeverRestrain_Posed", 1)
    EndIf

    SkyrimNetApi.RegisterPersistentEvent( \
        akLeader.GetDisplayName() + " leads " + akVictim.GetDisplayName() + " along, hands still bound - a prisoner on a short leash.", \
        akLeader, akVictim)
    Debug.Notification(akVictim.GetDisplayName() + " follows, bound.")
    Return True
EndFunction

Function UnleashCaptive(Actor akVictim)
    {Take a leashed captive off the leash and pin them where they stand: the
     hold marker is moved to their current spot and the normal standing-bound
     hold re-applies (the KidnapTick heal / _BindCaptive path). No-op unless
     leashed.}
    If !akVictim || !SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_LEASHED)
        Return
    EndIf
    SeverActions_Arrest arrestU = GetArrestScript()
    If arrestU && arrestU.SeverActions_FollowGuard_Prisoner
        ActorUtil.RemovePackageOverride(akVictim, arrestU.SeverActions_FollowGuard_Prisoner)
    EndIf
    If arrestU && arrestU.SeverActions_FollowTargetKW
        SeverActionsNative.LinkedRef_Clear(akVictim, arrestU.SeverActions_FollowTargetKW)
    EndIf
    StorageUtil.UnsetFormValue(akVictim, "SeverKidnap_LeashLeader")
    SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, KIDNAP_FLAG_LEASHED, False)
    ; Re-anchor the hold where they are now, then let the standard bind pin
    ; them (same choke point the marker heal uses).
    ObjectReference mU = SeverActionsNativeExt.Native_Kidnap_GetMarker(akVictim)
    If mU && akVictim.Is3DLoaded()
        mU.MoveTo(akVictim)
    EndIf
    Actor kdU = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(akVictim)
    If kdU && akVictim.Is3DLoaded()
        _BindCaptive(akVictim, kdU, False)
    EndIf
    Debug.Notification(akVictim.GetDisplayName() + " is held in place again.")
EndFunction

Function UntieCaptive(Actor akSpeaker, String targetName)
    {Loosen a held captive's bonds WITHOUT freeing them (user request): the
     hood, cuffs, kneel/pin come off and both captive and watching captor
     get the wide (r=350) hold-anchored sandbox - a prisoner with the run
     of the place and a jailer pacing it, not two statues on a marker.
     The kidnap entry stays LIVE: the context decorator switches to the
     unbound framing, guards still matter, escape still rolls (twice the
     chance - no bonds to work loose), ransom and interrogation still work,
     and MoveCaptive re-takes them bound as usual. Called by SkyrimNet via
     untiecaptive.yaml and the Prisma Actions/Arrest pages.}
    If !akSpeaker || akSpeaker.IsDead() || (!EnableKidnapActions && !EnableRestrainAction)
        Return
    EndIf
    If _RejectIfBoundActor(akSpeaker, "untie anyone")
        Return
    EndIf

    Actor victim = None
    Actor[] victims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    If !victims || victims.Length == 0
        Return
    EndIf
    If victims.Length == 1 && targetName == ""
        victim = victims[0]
    Else
        Int i = 0
        While i < victims.Length && !victim
            If victims[i] && StringUtil.Find(victims[i].GetDisplayName(), targetName) >= 0
                victim = victims[i]
            EndIf
            i += 1
        EndWhile
    EndIf
    If !victim || SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) != 3
        ; Feedback (audit class): SkyrimNet registers the action eventString
        ; on dispatch regardless - a silent refusal narrated an untying that
        ; never happened (review finding: this copy drifted from
        ; ReleaseCaptive's fixed version).
        SkyrimNetApi.RegisterEvent("kidnap_failed", \
            akSpeaker.GetDisplayName() + " goes to loosen a captive's bonds, but holds no such captive.", \
            akSpeaker, None)
        Return  ; only HELD captives can be untied
    EndIf
    If SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_UNBOUND)
        Debug.Notification(victim.GetDisplayName() + " is already unbound.")
        Return
    EndIf

    ; Strip the PHYSICAL hold - the marker and the entry stay.
    SeverActions_Furniture furnU = GetFurnitureScript()
    Package sitPkgU = Game.GetFormFromFile(KIDNAP_SIT_PKG_FORMID, "SeverActions.esp") as Package
    If sitPkgU
        ActorUtil.RemovePackageOverride(victim, sitPkgU)
    EndIf
    If furnU && furnU.SeverActions_FurnitureTargetKeyword
        SeverActionsNative.LinkedRef_Clear(victim, furnU.SeverActions_FurnitureTargetKeyword)
    EndIf
    victim.SetDontMove(false)
    victim.SetRestrained(false)
    StorageUtil.SetIntValue(victim, "SeverRestrain_Posed", 0)
    Debug.SendAnimationEvent(victim, "IdleForceDefaultState")
    SeverActions_Arrest arrestU = GetArrestScript()
    If arrestU && arrestU.SeverActions_PrisonerCuffs
        victim.UnequipItem(arrestU.SeverActions_PrisonerCuffs, false, true)
        victim.RemoveItem(arrestU.SeverActions_PrisonerCuffs, 1, true)
    EndIf
    Armor hoodU = Game.GetFormFromFile(KIDNAP_HOOD_FORMID, "Skyrim.esm") as Armor
    If hoodU
        victim.UnequipItem(hoodU, false, true)
        victim.RemoveItem(hoodU, 1, true)
    EndIf

    SeverActionsNativeExt.Native_Kidnap_SetFlag(victim, KIDNAP_FLAG_UNBOUND, true)

    ; The loose sandbox (user request): the r=350 anchored PrisonerSandBox
    ; instead of the guard's tight r=180 - an untied captive gets the run of
    ; the place, not a spot to stand on. Reuses the byte-proven jail package
    ; (minting a NEW PACK record is the malformed-block/pre-menu-hang class;
    ; not worth it for a radius). The captive-on-hold heal re-posts anyone
    ; the wider radius walks out a load door.
    ObjectReference mU = SeverActionsNativeExt.Native_Kidnap_GetMarker(victim)
    If mU && arrestU && arrestU.SeverActions_PrisonerSandBox && arrestU.SeverActions_SandboxAnchorKW
        SeverActionsNativeExt.LinkedRef_SetPermanent(victim, mU, arrestU.SeverActions_SandboxAnchorKW)
        ActorUtil.AddPackageOverride(victim, arrestU.SeverActions_PrisonerSandBox, 105, 1)
    EndIf
    victim.EvaluatePackage()

    ; The watching captor loosens up too (user request): swap their tight
    ; guard sandbox for the same r=350 so jailer and prisoner share the room
    ; instead of both standing pinned to the marker. _EndGuardDuty and the
    ; re-bind path both already strip PrisonerSandBox (legacy heal), so this
    ; unwinds everywhere guard duty does.
    Actor watcherU = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(victim)
    If watcherU && !watcherU.IsDead() && arrestU && StorageUtil.GetIntValue(watcherU, "SeverKidnap_OnGuard", 0) == 1
        Package guardPkgU = Game.GetFormFromFile(KIDNAP_GUARD_PKG_FORMID, "SeverActions.esp") as Package
        If guardPkgU
            ActorUtil.RemovePackageOverride(watcherU, guardPkgU)
        EndIf
        If arrestU.SeverActions_PrisonerSandBox
            ActorUtil.AddPackageOverride(watcherU, arrestU.SeverActions_PrisonerSandBox, 110, 1)
        EndIf
        watcherU.EvaluatePackage()
    EndIf

    String vNameU = victim.GetDisplayName()
    SeverActionsNative.Native_AddMemory(victim, \
        "My bonds have been loosened - I can move about my place of holding now, see, and speak. But I am still a captive: watched, and not permitted to leave.", \
        0.7, "EXPERIENCE", "wary", "", "[\"kidnap\"]", "[]")
    SkyrimNetApi.RegisterPersistentEvent( \
        akSpeaker.GetDisplayName() + " loosens " + vNameU + "'s bonds - still held, but no longer tied.", \
        akSpeaker, victim)
    Debug.Notification(vNameU + " is unbound but still held captive.")
    Debug.Trace("[SeverActions_FollowerManager] Kidnap: " + vNameU + " untied (loose captivity)")
EndFunction

Function _AbortKidnapForVictim(Actor akVictim, Actor akKidnapper)
    {Unwind a kidnap whose KIDNAPPER is dead or unresolvable - keyed off the
     victim, because _AbortKidnap resolves through FindVictimOf(kidnapper)
     and needs a live captor. Phase 1: nothing has happened to the target
     yet, unwind quietly. Phase >= 2: the seized victim walks free with the
     seized-then-abandoned consequences. Closes the audit wedge where a dead
     captor left the victim pacified and cuffed forever and, in alias mode,
     held the borrowed arrest dispatch aliases hostage.}
    Int deadPh = SeverActionsNativeExt.Native_Kidnap_GetPhase(akVictim)
    If akKidnapper
        _EndKidnapTravel(akKidnapper)
        _EndDispatchAliases(akKidnapper, akVictim)
        _EndGuardDuty(akKidnapper)
        If SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_RESTRAINT)
            SeverActionsNativeExt.Arrival_Cancel(akKidnapper)
            _EndRestrainApproach(akKidnapper)
        EndIf
    ElseIf SeverActionsNativeExt.Native_Kidnap_GetAliasMode(akVictim)
        ; Kidnapper FormID no longer resolves but the entry says the run was
        ; alias-mode: the dispatch aliases were OURS - hand them back by
        ; victim/state inference (a real arrest cleans its own fills).
        SeverActions_Arrest arrestDead = GetArrestScript()
        If arrestDead
            If arrestDead.DispatchGuardAlias
                arrestDead.DispatchGuardAlias.Clear()
            EndIf
            If arrestDead.DispatchTargetAlias
                arrestDead.DispatchTargetAlias.Clear()
            EndIf
            If arrestDead.DispatchPrisonerAlias && arrestDead.DispatchPrisonerAlias.GetReference() == akVictim
                arrestDead.DispatchPrisonerAlias.Clear()
            EndIf
        EndIf
    EndIf
    SeverActions_Travel travelDead = GetTravelScript()
    If travelDead
        If akKidnapper
            travelDead.CancelTravel(akKidnapper, false)
        EndIf
        travelDead.CancelTravel(akVictim, false)
    EndIf
    If deadPh >= 2
        _FireKidnapReleaseConsequences(akVictim)
        _UnbindCaptive(akVictim)
        SkyrimNetApi.RegisterPersistentEvent(             "With their captor dead, " + akVictim.GetDisplayName() + " is free - shaken, but no longer anyone's captive.",             akVictim, None)
    EndIf
    _DeleteKidnapHomeMarker(akVictim)
    SeverActionsNativeExt.Native_Kidnap_Clear(akVictim)
    Debug.Trace("[SeverActions_FollowerManager] Kidnap: unwound for " + akVictim.GetDisplayName() + " - kidnapper dead/unresolvable (phase " + deadPh + ")")
EndFunction

Function _AbortKidnap(Actor akKidnapper)
    {Travel leg cancelled (player recalled the kidnapper, etc.) — unwind
     whatever state the victim accumulated and drop the kidnap.}
    Actor victim = SeverActionsNativeExt.Native_Kidnap_FindVictimOf(akKidnapper)
    _EndKidnapTravel(akKidnapper)
    _EndDispatchAliases(akKidnapper, victim)
    _EndGuardDuty(akKidnapper)
    ; Slot travel (grab or transport leg) — safe no-op when none is active.
    SeverActions_Travel travelAbort = GetTravelScript()
    If travelAbort
        travelAbort.CancelTravel(akKidnapper, false)
    EndIf
    If !victim
        Return
    EndIf
    ; Restrain approach apparatus (follow package + LinkedRef + arrival
    ; watch) — _EndGuardDuty above doesn't touch it. Safe no-op otherwise.
    Bool abortWasRestraint = SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_RESTRAINT)
    If abortWasRestraint
        SeverActionsNativeExt.Arrival_Cancel(akKidnapper)
        _EndRestrainApproach(akKidnapper)
    EndIf
    ; A seized-then-abandoned victim knows what happened (no-op pre-grab).
    _FireKidnapReleaseConsequences(victim)
    _UnbindCaptive(victim)
    _DeleteKidnapHomeMarker(victim)
    SeverActionsNativeExt.Native_Kidnap_Clear(victim)
    If abortWasRestraint
        SkyrimNetApi.RegisterEvent("kidnap_aborted", \
            akKidnapper.GetDisplayName() + " gave up on restraining " + victim.GetDisplayName() + ".", \
            akKidnapper, victim)
    Else
        SkyrimNetApi.RegisterEvent("kidnap_aborted", \
            akKidnapper.GetDisplayName() + " abandoned the abduction of " + victim.GetDisplayName() + ".", \
            akKidnapper, victim)
    EndIf
EndFunction

Bool Function _RejectInvalidCaptiveTarget(Actor akActor, Actor akTarget, String verbPhrase)
    {Audit: cross-system target validation shared by KidnapNPC and
     RestrainNPC. TRUE (with a narrated refusal) when the target is owned by
     another subsystem whose state a kidnap would corrupt:
     - jailed / in an active arrest session (kidnapping a prisoner yanked
       them out of jail while JailedNPCStore still tracked them, and the
       shared SandboxAnchorKW meant a later release destroyed the jail
       anchor);
     - a live Venture ambush thug (restraining one corrupted the standoff
       and a thug despawn left a live KDNP entry).}
    Bool owned = false
    SeverActions_Arrest arrestX = GetArrestScript()
    ; IsActorInArrest, not HasSession: HasSession is keyed by PRISONER, so
    ; kidnapping the GUARD who is mid-arrest sailed straight through and
    ; stranded the arrest FSM mid-escort.
    If SeverActionsNativeExt.Native_Jailed_IsJailed(akTarget)         || SeverActionsNative.Native_ArrestSession_IsActorInArrest(akTarget)
        owned = true
    ElseIf SeverActionsNativeExt2.Venture_IsAmbushThug(akTarget)
        owned = true
    EndIf
    If owned
        SkyrimNetApi.RegisterEvent("kidnap_failed",             akActor.GetDisplayName() + " cannot " + verbPhrase + " " + akTarget.GetDisplayName() + " - the law (or worse) already has its hands on them.",             akActor, None)
        Return true
    EndIf
    ; Mid-scene targets (SexLab / OStim). Eligibility can only gate the
    ; SPEAKER, so without this a bystander - or the other participant - could
    ; bind someone who is locked into an animation: the seize AV-zeroes and
    ; re-packages an actor the animation framework owns, and the reported case
    ; was one participant restraining the other inside the same scene.
    If SeverActionsNative.Native_Outfit_IsInAnimationScene(akTarget)
        SkyrimNetApi.RegisterEvent("kidnap_failed",             akActor.GetDisplayName() + " cannot " + verbPhrase + " " + akTarget.GetDisplayName() + " - they are rather occupied at the moment.",             akActor, None)
        Return true
    EndIf
    Return false
EndFunction

Bool Function _RejectIfActorOccupied(Actor akActor, String verbPhrase)
    {SPEAKER-side companion to _RejectInvalidCaptiveTarget. TRUE (with a
     narrated refusal) when the would-be kidnapper/restrainer is already
     committed to something that owns their packages and AVs:

     - an arrest in flight, on EITHER side. Users reported both the arresting
       guard and the NPC being arrested kicking off an abduction mid-arrest;
       two FSMs then fight over the same actor's package stack and captured
       aggression/confidence, and whichever finishes last restores garbage.
     - a SexLab / OStim scene. Same class as the outfit system's scene
       suppression - walking an animating actor into a grab leg desyncs the
       animation framework.

     Mirrored by the is_busy / SexLabAnimatingFaction / OStimExcitementFaction
     eligibility rules on kidnapnpc.yaml + restrainnpc.yaml; this is the hard
     guard for the PrismaUI Actions page (no eligibility at all there) and for
     any eligibility miss. Deliberately does NOT read SkyrimNet's is_busy:
     that API is v6+ and reports false when absent, so the arrest check reads
     our own cosaved state instead.}
    If !akActor
        Return false
    EndIf
    If SeverActionsNative.Native_ArrestSession_IsActorInArrest(akActor)
        SkyrimNetApi.RegisterEvent("kidnap_failed",             akActor.GetDisplayName() + " is in the middle of an arrest and cannot " + verbPhrase + ".",             akActor, None)
        Return true
    EndIf
    If SeverActionsNative.Native_Outfit_IsInAnimationScene(akActor)
        SkyrimNetApi.RegisterEvent("kidnap_failed",             akActor.GetDisplayName() + " is rather occupied and cannot " + verbPhrase + ".",             akActor, None)
        Return true
    EndIf
    Return false
EndFunction

Function _PacifyCaptive(Actor akVictim)
    {Capture-then-zero (the arrest lesson: zeroing without capture permanently
     pacifies the NPC) + the prisoner faction so guards do not intervene.
     Shared by the kidnap grab and the restrain bind; restored/removed by
     _UnbindCaptive via the -1 capture sentinel. Keep both halves together -
     the capture/restore contract must never drift between call sites.}
    SeverActionsNativeExt.Native_Kidnap_CaptureAVs(akVictim, akVictim.GetAV("Aggression"), akVictim.GetAV("Confidence"))
    akVictim.SetAV("Aggression", 0)
    akVictim.SetAV("Confidence", 0)
    SeverActions_Arrest arrestP = GetArrestScript()
    If arrestP && arrestP.dunPrisonerFaction
        akVictim.AddToFaction(arrestP.dunPrisonerFaction)
    EndIf
    ; SkyrimNet packages are applied by a native hook on the engine's
    ; package-eval that returns SkyrimNet's pick UNCONDITIONALLY - it
    ; outranks every ActorUtil override and alias package we layer on a
    ; captive (its priority number only ranks SkyrimNet's own packages).
    ; A victim carrying SkyrimNet's persistent FollowPlayer beelined to the
    ; player in every unpinned window (march, trailing walk-in, post-load
    ; pre-pin). Being seized overrides any prior AI intent: clear SkyrimNet's
    ; package stack on the victim. KidnapTick heals mid-captivity re-issues.
    SkyrimNetApi.ClearAllPackages(akVictim)
    SkyrimNetApi.CancelPendingPackageTasks(akVictim)
EndFunction

Bool Function _RejectIfBoundActor(Actor akActor, String verbPhrase)
    {A bound captive cannot manage captives or take new ones. Returns TRUE
     (and narrates the failed attempt) when akActor is themselves an actually
     BOUND kidnap/restraint victim (phase >= 2: seized/held) — closes the
     hole where a lone captive's own LLM turn called ReleaseCaptive and freed
     herself (single-captive resolve ignores targetName, and nothing gated
     the speaker). Phase 1 (someone is merely WALKING toward them) does not
     count: they have no bonds yet and narrating "strains against their
     bonds" would contradict the world state. Mirrored by the
     is_kidnap_victim eligibility rule on the six captive-verb YAMLs; this
     is the hard guard for the Prisma Actions page and any eligibility miss.}
    If !akActor || SeverActionsNativeExt.Native_Kidnap_GetPhase(akActor) < 2
        Return false
    EndIf
    SkyrimNetApi.RegisterEvent("kidnap_failed", \
        akActor.GetDisplayName() + " strains against their bonds, but a bound captive cannot " + verbPhrase + ".", \
        akActor, None)
    Return true
EndFunction

Function ReleaseCaptive(Actor akActor, String targetName)
    {Free a held (or in-transit) kidnap victim. Called by SkyrimNet via
     releasecaptive.yaml — akActor is whoever unties them.}
    If !akActor
        Return
    EndIf
    If _RejectIfBoundActor(akActor, "free anyone, least of all themselves")
        Return
    EndIf

    ; Resolve among ACTIVE victims only (never a global scan here).
    Actor victim = None
    Actor[] victims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    If !victims || victims.Length == 0
        Return
    EndIf
    If victims.Length == 1 && targetName == ""
        victim = victims[0]
    Else
        Int i = 0
        While i < victims.Length && !victim
            If victims[i] && StringUtil.Find(victims[i].GetDisplayName(), targetName) >= 0
                victim = victims[i]
            EndIf
            i += 1
        EndWhile
    EndIf
    If !victim
        ; Feedback (audit): SkyrimNet registers the action eventString on
        ; dispatch regardless, so a silent refusal narrated a release that
        ; never happened.
        SkyrimNetApi.RegisterEvent("kidnap_failed", \
            akActor.GetDisplayName() + " looks for a captive called " + targetName + " to free, but holds no one by that name.", \
            akActor, None)
        Return
    EndIf
    Int relPhase = SeverActionsNativeExt.Native_Kidnap_GetPhase(victim)

    Actor kidnapper = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(victim)
    If kidnapper
        _EndGuardDuty(kidnapper)
        _EndDispatchAliases(kidnapper, victim)
        ; Mid-APPROACH release of a restrain: also strip the restrainer's
        ; walk-up apparatus (follow package + LinkedRef + arrival watch) —
        ; _EndGuardDuty doesn't touch those, and without this the restrainer
        ; trailed the freed target forever. Safe no-op in any other state.
        If SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_RESTRAINT)
            SeverActionsNativeExt.Arrival_Cancel(kidnapper)
            _EndRestrainApproach(kidnapper)
        EndIf
        ; Mid-transport release: also tear down the slot travel. Safe no-op
        ; when the kidnapper isn't traveling.
        SeverActions_Travel travelSys = GetTravelScript()
        If travelSys
            travelSys.CancelTravel(kidnapper, false)
        EndIf
    EndIf
    ; Consequences BEFORE the entry is cleared (reads grab record + flags).
    _FireKidnapReleaseConsequences(victim)
    _FreeCaptiveAlias(victim)  ; _UnbindCaptive does this too — explicit for clarity
    _UnbindCaptive(victim)
    _DeleteKidnapHomeMarker(victim)
    SeverActionsNativeExt.Native_Kidnap_Clear(victim)

    If relPhase == 1
        ; Approach-only release (audit): nothing had happened to the target
        ; yet - "freed from captivity" narrated bonds that never existed.
        SkyrimNetApi.RegisterEvent("kidnap_aborted", \
            akActor.GetDisplayName() + " called off the attempt on " + victim.GetDisplayName() + " before anything happened.", \
            akActor, victim)
        Return
    EndIf
    SkyrimNetApi.RegisterPersistentEvent( \
        akActor.GetDisplayName() + " has freed " + victim.GetDisplayName() + " from captivity.", \
        akActor, victim)
    Debug.Notification(victim.GetDisplayName() + " has been freed.")
EndFunction

Function _UnbindCaptive(Actor akVictim)
    {Tear down every piece of kidnap state on the victim: restraint, idle,
     hood, escort packages, LinkedRefs, pacify faction, captured AVs. Safe to
     call on a victim in ANY phase — each step no-ops when absent. The
     furniture package/keyword/marker lines heal LEGACY captives bound by
     the removed furniture-sandbox treatment (the cell-attach CTD combo).}
    ; Leash remnants (kFlagLeashed): drop the escort-follow + LinkedRef so a
    ; freed captive stops trailing whoever was leading them.
    SeverActions_Arrest arrestLz = GetArrestScript()
    If arrestLz && arrestLz.SeverActions_FollowGuard_Prisoner
        ActorUtil.RemovePackageOverride(akVictim, arrestLz.SeverActions_FollowGuard_Prisoner)
    EndIf
    If arrestLz && arrestLz.SeverActions_FollowTargetKW
        SeverActionsNative.LinkedRef_Clear(akVictim, arrestLz.SeverActions_FollowTargetKW)
    EndIf
    StorageUtil.UnsetFormValue(akVictim, "SeverKidnap_LeashLeader")
    SeverActions_Arrest arrest = GetArrestScript()
    SeverActions_Furniture furn = GetFurnitureScript()

    ; Tear down the victim's own persistence slot travel (leg-2 alias pin).
    ; Safe no-op when none is active.
    SeverActions_Travel travelSys = GetTravelScript()
    If travelSys
        travelSys.CancelTravel(akVictim, false)
    EndIf

    ; Release the restraint + play the getting-up animation.
    akVictim.SetDontMove(false)
    akVictim.SetRestrained(false)
    StorageUtil.UnsetIntValue(akVictim, "SeverRestrain_Posed")
    Idle kneelExit = Game.GetFormFromFile(KIDNAP_IDLE_KNEEL_EXIT, "Skyrim.esm") as Idle
    If kneelExit
        akVictim.PlayIdle(kneelExit)
    EndIf

    ; The hold: the BoundCaptiveSit package + furniture LinkedRef (+ the
    ; legacy furniture-sandbox package from the CTD build).
    Package sitPkgRel = Game.GetFormFromFile(KIDNAP_SIT_PKG_FORMID, "SeverActions.esp") as Package
    If sitPkgRel
        ActorUtil.RemovePackageOverride(akVictim, sitPkgRel)
    EndIf
    _FreeCaptiveAlias(akVictim)
    ; Loose-captivity sandbox (UntieCaptive) - its SandboxAnchorKW LinkedRef
    ; is cleared with the anchor block below.
    Package guardPkgRel = Game.GetFormFromFile(KIDNAP_GUARD_PKG_FORMID, "SeverActions.esp") as Package
    If guardPkgRel
        ActorUtil.RemovePackageOverride(akVictim, guardPkgRel)
    EndIf
    If furn && furn.SeverActions_UseFurniturePackage
        ActorUtil.RemovePackageOverride(akVictim, furn.SeverActions_UseFurniturePackage)
    EndIf
    If furn && furn.SeverActions_FurnitureTargetKeyword
        SeverActionsNative.LinkedRef_Clear(akVictim, furn.SeverActions_FurnitureTargetKeyword)
    EndIf
    If arrest
        If arrest.SeverActions_FollowGuard_Prisoner
            ActorUtil.RemovePackageOverride(akVictim, arrest.SeverActions_FollowGuard_Prisoner)
        EndIf
        If arrest.SeverActions_FollowTargetKW
            SeverActionsNative.LinkedRef_Clear(akVictim, arrest.SeverActions_FollowTargetKW)
        EndIf
        ; The hold anchor (jail-pattern AI pin applied at bind).
        If arrest.SeverActions_PrisonerSandBox
            ActorUtil.RemovePackageOverride(akVictim, arrest.SeverActions_PrisonerSandBox)
        EndIf
        If arrest.SeverActions_SandboxAnchorKW
            SeverActionsNative.LinkedRef_Clear(akVictim, arrest.SeverActions_SandboxAnchorKW)
        EndIf
        If arrest.dunPrisonerFaction
            akVictim.RemoveFromFaction(arrest.dunPrisonerFaction)
        EndIf
    EndIf

    ; Hood off + out of inventory.
    Armor hood = Game.GetFormFromFile(KIDNAP_HOOD_FORMID, "Skyrim.esm") as Armor
    If hood
        akVictim.UnequipItem(hood, false, true)
        akVictim.RemoveItem(hood, 1, true)
    EndIf

    ; Bound-hands cuffs off (equipped during any transport leg by _LaunchGrabLeg
    ; for the walk-bound look). Safe no-op when the captive never travelled.
    If arrest && arrest.SeverActions_PrisonerCuffs
        akVictim.UnequipItem(arrest.SeverActions_PrisonerCuffs, false, true)
        akVictim.RemoveItem(arrest.SeverActions_PrisonerCuffs, 1, true)
    EndIf

    ; Restore the captured AVs (sentinel -1 = never captured — leave alone).
    Float origAggr = SeverActionsNativeExt.Native_Kidnap_GetOrigAggression(akVictim)
    If origAggr >= 0.0
        akVictim.SetAV("Aggression", origAggr)
    EndIf
    Float origConf = SeverActionsNativeExt.Native_Kidnap_GetOrigConfidence(akVictim)
    If origConf >= 0.0
        akVictim.SetAV("Confidence", origConf)
    EndIf

    ; Delete the placed bound-captive marker.
    ObjectReference marker = SeverActionsNativeExt.Native_Kidnap_GetMarker(akVictim)
    If marker
        marker.Disable()
        marker.Delete()
    EndIf

    ; Break the furniture/idle lock so they actually stand up.
    Debug.SendAnimationEvent(akVictim, "IdleForceDefaultState")
    akVictim.EvaluatePackage()
EndFunction

; =============================================================================
; HELPER FUNCTIONS
; =============================================================================

Float Function GetGameTimeInSeconds()
    {Convert current game time to seconds for precise tracking}
    ; GetCurrentGameTime() returns days as float
    ; Multiply by 24 to get hours, then by SECONDS_PER_GAME_HOUR for game seconds
    Return Utility.GetCurrentGameTime() * 24.0 * SECONDS_PER_GAME_HOUR
EndFunction

SeverActions_FollowerManager Function GetInstance() Global
    Return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_FollowerManager
EndFunction

SeverActions_Follow Function GetFollowScript()
    If FollowScript
        Return FollowScript
    EndIf
    ; Fallback: try to find on the quest (0x000800 was a phantom FormID --
    ; the only quest in SeverActions.esp is 0x000D62)
    Return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Follow
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
    {Papyrus pump for SkyrimNet < v8. On v8+ the C++ side dispatches the
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
        DebugMsg("Quest awareness skipped (toggle off or prompt missing) - draining queue")
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
    {Callback from SendCustomPromptToLLM (Papyrus pump). Parses routing
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
        Actor akActor = Game.GetFormEx(npcFid) as Actor
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

    DebugMsg("Quest awareness: quest completed - " + strArg)

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

        Actor akFollower = Game.GetFormEx(fidVal) as Actor
        If akFollower && summary != ""
            ; All awareness entries are firsthand witnesses now — the secondhand
            ; tier was retired. Memory type is always EXPERIENCE at the firsthand
            ; importance weight. The isFirsthand JSON field is ignored.
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
                DebugMsg("Quest awareness: Native_AddMemory failed for " + akFollower.GetDisplayName() + " on " + entryEditorID + " - entry stays visible")
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

Int Property FollowStateTTLMs = 300000 Auto
{How long a wait/resume line stays in scene context (ms).}

Function RegisterFollowStateEvent(Actor akActor, String asType, String asText)
    {Waiting vs following is STATE, not history - short-lived, keyed per actor.

     These fire once per companion, so Wait All / Follow All with a large
     retinue used to append one permanent line each, and the pair flips back
     and forth all session. Keying the event on the actor means the newest
     line REPLACES the previous one: a companion is either waiting or
     following, never both, and never a paragraph of both.

     Same treatment as the furniture pair - see the note in
     SeverActions_Furniture.RegisterFurnitureSceneEvent.}

    If akActor == None
        Return
    EndIf
    SkyrimNetApi.RegisterShortLivedEvent("follow_state_" + akActor.GetFormID(), \
        asType, asText, "", FollowStateTTLMs, akActor, Game.GetPlayer())
EndFunction

; ============================================================================
; INTIMACY GATES (surfacing only - NO tracking on main)
; Intimate-history tracking lives solely on the NSFW sibling's
; SexualHistoryStore; main has no scene-end listeners or cosaved history and
; keeps only the 0046 Intimacy & Consent posture section + the persona/trade
; decorators. These two properties are the MCM/settings mirror of the native
; IntimacyGate (write-through via Native_IntimateHistory_SetEnabled/_SetGenderGate).
; ============================================================================

Bool Property IntimateHistoryEnabled = true Auto
{Master toggle for the intimacy-flavored prompt sections (0046 consent
 posture, persona/trade decorators). MCM General page / PrismaUI Settings;
 surfacing is gated natively (IntimacyGate) via the same setting.}

Int Property IntimacyGenderGate = 1 Auto
{0 = everyone, 1 = women only, 2 = men only. Gates whose bio renders the
 intimacy sections; nothing is recorded on main either way.}
