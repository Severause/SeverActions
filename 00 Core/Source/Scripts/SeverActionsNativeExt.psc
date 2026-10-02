Scriptname SeverActionsNativeExt Hidden
{Spillover class for SeverActions natives. A Papyrus class holds at most 511
 natives (a 9-bit static-count field); one more invalidates the whole class and
 every call on it returns None. This class is near the cap too: new natives go
 on SeverActionsNativeExt2.}

; === HEALER POLL: the "healer" combat style ===
; Ticks ~1s in combat per registered healer: picks a target (player > self >
; ally), gates on cooldowns, magicka and the chance roll, then sends
; SeverActionsNative_HealerCast for Papyrus to cast, bonus-heal and speak.
; The roster is in memory only; it derives from FollowerData's combatStyle and
; is re-registered on load (FollowerSystemHydrator, FollowerManager.ReapplyCombatStyles).

Function Native_RegisterHealer(Actor akActor) Global Native
{Add an actor to the healer poll. Idempotent.}

Function Native_UnregisterHealer(Actor akActor) Global Native
{Remove an actor from the healer poll.}

Bool Function Native_IsHealer(Actor akActor) Global Native
{Returns true if the actor is currently in the healer poll roster.}

Int Function Native_GetHealerCount() Global Native
{Returns the number of registered healers.}

Function Native_ClearAllHealers() Global Native
{Clear the entire healer roster.}

Function Native_SetHealerThresholds(Float playerThresh, Float selfThresh, Float allyThresh) Global Native
{Health-fraction trigger per tier, clamped 0.0-0.95; 0 disables the tier.}

Function Native_SetHealerMult(Float mult) Global Native
{Bonus-heal multiplier, clamped 0.05-2.0. Default 1.0.}

Function Native_SetHealerChance(Int chance) Global Native
{Per-tick attempt chance, 0-100. Default 75.}

Function Native_SetHealerCooldowns(Int targetMs, Int healerMs, Int voiceMs) Global Native
{Cooldowns in ms: per-target heal, per-healer cast, per-healer voice line
 (defaults 4000 / 1500 / 30000).}

Function Native_SetBleedoutCheatHeal(Bool enabled) Global Native
{Toggle the bleedout fail-safe heal for healer-mode followers.}

Bool Function Native_IsBleedoutCheatHealEnabled() Global Native
{Read the bleedout fail-safe toggle.}

Float Function Native_ComputeBonusHeal(Actor akCaster) Global Native
{Bonus heal for this caster: (Restoration * 0.2 + Level + 74) * healMult.
 Applied with RestoreActorValue("Health", ...) after Spell.Cast().}

Function Native_NotifyHealApplied(Actor akHealer, Actor akTarget) Global Native
{Start the per-target cooldown after a heal lands.}

Bool Function Native_ShouldEmitVoiceLine(Actor akHealer) Global Native
{True (and restarts the per-healer voice cooldown) when a voice line may play.}

; === CELL CATCHUP ===
; After a load door or fast travel, and a grace period that lets the vanilla
; teleport go first, MoveTo's rostered followers left in another cell to the
; player. The skip gates are CellCatchup.cpp RunCatchup's. The settings below are
; RAM-only: FollowerManager.SyncCellCatchupConfig pushes them on every load.

Function Native_SetCellCatchupEnabled(Bool enabled) Global Native
{Master toggle for the event-armed sweeps (TriggerNow ignores it). Default true.}

Bool Function Native_IsCellCatchupEnabled() Global Native
{Read the cell-catchup master toggle.}

Function Native_SetCellCatchupGracePeriodMs(Int ms) Global Native
{Delay after a cell load before the sweep. Default 1500 ms.}

Function Native_SetCellCatchupMaxFollowers(Int n) Global Native
{Most followers moved per sweep (min 1). Native default 16; the pushed
 FollowerManager property defaults to 8.}

Function Native_SetCellCatchupOffsetRadius(Float radius) Global Native
{XY scatter radius (units) around the drop point so followers don't pile up.
 Default 100.0.}

Function Native_CellCatchup_TriggerNow() Global Native
{Run the sweep now, skipping the grace period.}

; === HOLD RESOLVER: crime faction -> jail marker, hold name, jail name, bounty key ===
; The kernel seeds the nine vanilla holds by FormID at kDataLoaded, so it answers
; without the arrest module; SeverActions_Arrest.Maintenance re-registers them as a
; belt. Keyed by CRIME faction: a guard resolves through the crime faction they hold.

Function Hold_Register(Faction akCrimeFaction, ObjectReference akJailMarker, String asHoldName, String asBountyKey, String asJailName) Global Native
{Register or overwrite one hold, keyed by crime faction (idempotent; third-party
holds may call it). akJailMarker may be None: the faction's crimeData.factionJailMarker
is used.}

Bool Function Hold_Resolve(Actor akGuard) Global Native
{Returns true if akGuard is in any registered crime faction.}

Faction Function Hold_GetCrimeFaction(Actor akGuard) Global Native
{Return the crime faction for akGuard's hold, or None if no match.}

ObjectReference Function Hold_GetJailMarker(Actor akGuard) Global Native
{Jail marker for akGuard's hold (registered, else crimeData.factionJailMarker), or None.}

String Function Hold_GetHoldName(Actor akGuard) Global Native
{Return the display name of akGuard's hold, or "" if no match.}

String Function Hold_GetJailName(Actor akGuard) Global Native
{Return the display name of the jail in akGuard's hold, or "" if no match.}

String Function Hold_GetBountyKey(Actor akGuard) Global Native
{Return the storage key for tracked bounty in akGuard's hold, or "" if no match.}

String Function Hold_GetBountyKeyForCrime(Faction akCrimeFaction) Global Native
{Return the storage key for tracked bounty in a crime faction's hold, or "" if no match.}

ObjectReference Function Hold_GetJailMarkerForCrime(Faction akCrimeFaction) Global Native
{Jail marker for a crime faction's hold, same fallback as Hold_GetJailMarker.
For jailing an NPC with no guard at hand.}

Function Hold_Clear() Global Native
{Clear every registered hold, for a mod that rebuilds the table. The kDataLoaded
 seed does not re-run.}

Int Function Hold_Count() Global Native
{Return the number of registered hold tuples.}

; === JAILED NPC STORE: cosaved roster of jailed NPCs; dead prisoners drop out on TESDeathEvent ===

Function Native_Jailed_Add(Actor akPrisoner, ObjectReference akJailMarker, Faction akCrimeFaction, Int aiFlags) Global Native
{Add or overwrite a jailed NPC. aiFlags bit 0 = was Disabled (DisablePrisonerOnArrival).}

Bool Function Native_Jailed_Remove(Actor akPrisoner) Global Native
{Remove a jailed NPC. Returns true if was tracked.}

Function Native_Jailed_RemoveAll() Global Native
{Clear every entry.}

Bool Function Native_Jailed_IsJailed(Actor akPrisoner) Global Native
{True if akPrisoner is in the roster.}

ObjectReference Function Native_Jailed_GetMarker(Actor akPrisoner) Global Native
{Return the prisoner's jail marker, or None if not tracked.}

Faction Function Native_Jailed_GetCrimeFaction(Actor akPrisoner) Global Native
{Return the crime faction the prisoner was jailed under, or None if not tracked.}

Float Function Native_Jailed_GetAgeHours(Actor akPrisoner) Global Native
{Return in-game hours elapsed since the prisoner was jailed, or 0 if not tracked.}

Int Function Native_Jailed_GetCount() Global Native
{Return the size of the roster.}

Actor[] Function Native_Jailed_GetAll() Global Native
{The roster, capped at 128 (the Papyrus array limit).}

; === CRAFTING ORCHESTRATOR (state machine: CraftingOrchestrator.h) ===
; One session runs at a time because the crafting aliases on the quest are
; singletons; later Craft_Begin calls queue and run in order.

Int Function Craft_Begin(Actor akActor, Form akItemForm, ObjectReference akWorkstation, Actor akRecipient, Int itemCount, String workstationType, String actionVerb) Global Native
{Begin a craft session. Returns a handle > 0, or 0 on a None actor, item or
 workstation. While another session runs the new one waits in Queued.}

Function Craft_Cancel(Int handle) Global Native
{Cancel a session; fires the TermCancelled phase event. No-op for an unknown handle.}

Bool Function Craft_IsActive(Int handle) Global Native
{Returns true while the handle is in a non-terminal state.}

Int Function Craft_GetActiveCount() Global Native
{Number of non-terminal sessions, queued ones included.}

Int Function Craft_GetState(Int handle) Global Native
{Returns the current CraftState as an int. See Craft_GetStateName.}

String Function Craft_GetStateName(Int stateCode) Global Native
{Stable name for a CraftState code:
 0=Idle, 1=Queued, 2=WalkingToWorkstation, 3=AnimatingAtWorkstation,
 4=ExitingWorkstation, 5=ReturningToRecipient, 6=HandingOff,
 10=Completed, 11=AbortedNoArrival, 12=AbortedNoWorkstation, 13=Cancelled.}

Actor Function Craft_GetActor(Int handle) Global Native
{Returns the crafter for the given handle, or None.}

ObjectReference Function Craft_GetWorkstation(Int handle) Global Native
{Returns the workstation ref for the given handle, or None.}

Actor Function Craft_GetRecipient(Int handle) Global Native
{The recipient (the player when Begin got None), or None for an unknown handle.}

String Function Craft_GetWorkstationType(Int handle) Global Native
{The workstation label ("forge"/"cooking pot"/"oven"/"alchemy lab"), or "".}

; Console probe only, not on the orchestrator's path.

Bool Function Craft_SpikePackageOverride(Actor akActor, Package akPackage, Int priority, Int flags) Global Native
{Probe: does DispatchStaticCall reach ActorUtil.AddPackageOverride from C++?
 True when the call was queued; watch whether the NPC walks to the target.
   cgf "SeverActionsNativeExt.Craft_SpikePackageOverride" <npc_formid> <package_formid> 100 1}

; === OUTFIT (OutfitDataStore) ===

Bool Function Native_Outfit_IsLockActive(Actor akActor) Global Native
{True if the actor has an active outfit lock.}

Bool Function Native_Outfit_IsExternallyControlled(Actor akActor) Global Native
{True while Diary of Mine / Paradise Halls holds the actor captive (their
 factions) and defer-to-bondage is on; outfit enforcement then skips re-equip
 so SA doesn't fight their strip or restraints. False without those mods.}

Function Native_Outfit_SetDeferBondage(Bool abEnabled) Global Native
{Toggle for the deferral above (default ON; off = IsExternallyControlled is
 always false). RAM-only: SeverActions_Outfit.Maintenance re-pushes it on load.}

Bool Function Native_Outfit_IsActivelyManaged(Actor akActor) Global Native
{For soft-dep compat patches deciding whether to skip their own outfit
 re-equip: true iff the actor is a recruited SA follower, not outfit-excluded,
 and has an active lock or slot preset (the OutfitAlias's own gate).}

Bool Function Native_IsDeviousDevice(Form akForm) Global Native
{True for a Devious Devices armor: the rendered device (zad_Lockable /
 zad_DeviousX) or its locked inventory token (zad_InventoryDevice). Strip paths
 skip these so a device is never unequipped behind its own script.
 Keyword-based; no DD dependency.}

Function Native_UnequipItemNow(Actor akActor, Form akItem) Global Native
{Pause-safe unequip (armor only). Papyrus UnequipItem goes through the actor
 task queue, which does not run while the game is paused, so it fires on
 unpause against whatever is worn then. This applies at once. Use it in any
 worn change reachable from the paused menu; no-op if the item is not worn.}

Function Native_EquipItemNow(Actor akActor, Form akItem) Global Native
{Pause-safe equip (armor only) - see Native_UnequipItemNow. Force-equip: the
 engine keeps our item, no best-armor re-evaluation.}

Function Native_Preview_NotifyWornChanged(Actor akActor) Global Native
{Call at the END of a committed worn change that can run while the wardrobe
 is open (ApplyOutfitPreset, both paths): re-baselines the actor's preview
 session so menu close keeps the new outfit, and re-bakes the mannequin view.
 No-op without a preview session or prior bake.}

Function LinkedRef_SetPermanent(Actor akActor, ObjectReference akTarget, Keyword akKeyword) Global Native
{LinkedRef exempt from PackageManager's 30-day staleness prune (LREF v3), for
 set-once anchors (work markers, guard links, jail sandboxes).
 LinkedRef_Clear removes it, ClearAll keeps it, and a session start keeps it while its actor is only out of
 memory (re-set when she loads); a plain LinkedRef_Set on the same actor+keyword does not demote it.}

; === KIDNAP (KidnapStore, cosave 'KDNP') ===

Function Native_Kidnap_SetEnabled(Bool enabled) Global Native
{Feed the sever_kidnap_enabled decorator's flag. Session-only; SeverActions_Kidnap
 re-pushes it on load.}

Function Native_Restrain_SetEnabled(Bool enabled) Global Native
{Feed the sever_restrain_enabled decorator's flag (default ON). Session-only;
 SeverActions_Kidnap re-pushes it on load.}


Bool Function Native_Kidnap_IsEnabled() Global Native

; Atomic claim: creates the entry only if the victim is free and the kidnapper
; holds no one; true if taken. Never create an entry unchecked - it would
; overwrite a live captive's record. abIsRestraint sets the restraint flag.
Bool Function Native_Kidnap_BeginIfFree(Actor victim, Actor kidnapper, String destLabel, Bool abIsRestraint) Global Native
; Atomic re-key for MoveCaptive: only while HELD and the escort holds no one
; else. Keeps the marker and consequence state.
Bool Function Native_Kidnap_RekeyIfHeld(Actor victim, Actor escort, String destLabel) Global Native
; Atomic compare-and-set of the phase.
Bool Function Native_Kidnap_TryAdvancePhase(Actor victim, Int fromPhase, Int toPhase) Global Native
; Overwrite the narrated destination label (binds without a destination).
Function Native_Kidnap_SetDestLabel(Actor victim, String label) Global Native

Function Native_Kidnap_SetPhase(Actor victim, Int phase) Global Native
{1=grabbing, 2=transport, 3=held.}

Function Native_Kidnap_SetHeld(Actor victim, ObjectReference marker) Global Native
{Phase 3 + remembers the placed BoundCaptiveMarker for release cleanup.}

Function Native_Kidnap_CaptureAVs(Actor victim, Float aggression, Float confidence) Global Native
{Idempotent original-AV capture (arrest pattern) so release restores them.}

Float Function Native_Kidnap_GetOrigAggression(Actor victim) Global Native
{-1 = never captured.}

Float Function Native_Kidnap_GetOrigConfidence(Actor victim) Global Native

Int Function Native_Kidnap_GetPhase(Actor victim) Global Native
{0 = not a kidnap victim.}

Actor Function Native_Kidnap_GetKidnapper(Actor victim) Global Native

ObjectReference Function Native_Kidnap_GetMarker(Actor victim) Global Native

Function Native_Kidnap_Clear(Actor victim) Global Native

Actor Function Native_Kidnap_FindVictimOf(Actor kidnapper) Global Native

Actor[] Function Native_Kidnap_ListVictims() Global Native
{All actors with an active kidnap entry (load-recovery iteration).}

Actor Function Native_Kidnap_FindActorByName(String name) Global Native
{Actor lookup over the whole form table (exact > prefix > substring,
 case-insensitive), so off-screen NPCs resolve. Skips the player and the dead.}

; -- KDNP v2 fields --

Function Native_Kidnap_SetDestAnchor(Actor victim, ObjectReference anchor) Global Native
{The resolved destination marker (travel arrival point). Cosaved.}

ObjectReference Function Native_Kidnap_GetDestAnchor(Actor victim) Global Native

String Function Native_Kidnap_GetDestLabel(Actor victim) Global Native
{The destination name given at Begin (used by the leg-2 slot fallback).}

Function Native_Kidnap_SetAliasMode(Actor victim, Bool aliasMode) Global Native
{True while the kidnap rides the arrest dispatch aliases.}

Bool Function Native_Kidnap_GetAliasMode(Actor victim) Global Native

Function Native_Kidnap_SetLegDeadline(Actor victim, Float deadline) Global Native
{Game-time deadline for the active leg (wait menu advances it).}

Float Function Native_Kidnap_GetLegDeadline(Actor victim) Global Native

Function Native_Kidnap_SetMarkerSchema(Actor victim, Int schema) Global Native
{2 = force-persistent hold marker; v1-loaded entries default 1 (heal fires).}

Int Function Native_Kidnap_GetMarkerSchema(Actor victim) Global Native

; -- KDNP v6: the SeverActions_CaptiveQuest slot (0..15) holding the kneel
; package; -1 = none (the priority-95 ActorUtil override holds them). Cosaved.
Function Native_Kidnap_SetAliasIndex(Actor victim, Int aliasIndex) Global Native

Function Native_Kidnap_SetLeashLeader(Actor victim, Actor leader) Global Native
{Who LEADS the captive on a leash (KDNP v7), which is not always the captor:
 RestrainNPC can hand a captive over while kidnapper keeps saying who took them.
 Mirrors StorageUtil "SeverKidnap_LeashLeader" for has_captive_in_hand and caches
 the leader's name for kidnap_context (v8). None clears.}

Int Function Native_Kidnap_GetAliasIndex(Actor victim) Global Native

Int Function Native_Kidnap_BumpOffscreenTicks(Actor victim, Bool reset) Global Native
{Transient watchdog counter (not cosaved): increments and returns the new
 value, or zeroes it when reset.}

Int Function Native_Kidnap_BumpNoTravelStrikes(Actor victim, Bool reset) Global Native

Function Native_SceneBound_Set(Actor akActor, Bool bound) Global Native
{Mark an actor as setting up a scene (the NSFW add-on marks both partners);
 suppresses TravelToPlace for them. TTL-backstopped; cleared on revert.}

; True once after a ResolveDestination whose phrase had an exterior prefix
; ("outside"/"beside"/"near"/"in front of"): DoTravelToPlace then stops at the
; entrance instead of going through the door. Reading consumes it.
Bool Function Native_TravelExteriorIntent(Actor akActor) Global Native

Bool Function Native_SceneBound_IsBound(Actor akActor) Global Native

Bool Function Native_IsListedCustomAI(Actor akActor) Global Native
{True if the actor's base name or EditorID is listed in
 SeverActions_CustomAI_DISTR.ini (custom-AI detection without SPID). Matching
 by name also covers forks that renamed the EditorID.}

Function Native_Trespass_SetLLMMode(Bool enabled) Global Native
{LLM-driven trespass: on = the vanilla warn-follow reaction is suppressed and
 occupants get SkyrimNet context (an event + sever_trespass_context).
 Session-only; SeverActions_Follow re-pushes it on load.}

Bool Function Native_Trespass_IsLLMMode() Global Native
{Read the current LLM-trespass toggle (the value pushed by Native_Trespass_SetLLMMode).}

; -- KDNP v3 consequences --
; SetFlag/GetFlag bits are KidnapStore::Flag's (1 grab witnessed, 2 gossip
; fired, 4 search party fired; 8 and up: see the enum); keep them in step.

Function Native_Kidnap_SetGrabInfo(Actor victim, Faction crimeFaction, Float grabTime) Global Native
{Stamp the grab record: the victim's home-hold crime faction (bounty
 jurisdiction) and game time seized. Set once: guard on GetGrabTime() == 0 so
 a MoveCaptive re-take keeps the original.}

Faction Function Native_Kidnap_GetGrabFaction(Actor victim) Global Native

Float Function Native_Kidnap_GetGrabTime(Actor victim) Global Native
{0.0 = no grab record (pre-v3 entry or never seized).}

Function Native_Kidnap_SetFlag(Actor victim, Int flag, Bool value) Global Native

Bool Function Native_Kidnap_GetFlag(Actor victim, Int flag) Global Native

Bool Function Native_Kidnap_IsGrabWitnessed(Actor kidnapper, Actor victim, Float radius) Global Native
{IsTheftWitnessed excluding the victim: a loaded, awake, non-follower third party with line-of-sight to the kidnapper within radius.}


; -- KDNP v4 ransom --
; States (KidnapStore::RansomState): 0 none, 1 pending (awaiting the steward),
; 2 paid (release expected), 3 refused.

Function Native_Kidnap_SetRansom(Actor victim, Int amount, Float demandTime) Global Native
{Record a ransom demand (sets state to pending). Cosaved.}

Function Native_Kidnap_SetRansomState(Actor victim, Int aiState) Global Native

Int Function Native_Kidnap_GetRansomState(Actor victim) Global Native

Int Function Native_Kidnap_GetRansomAmount(Actor victim) Global Native

Float Function Native_Kidnap_GetRansomTime(Actor victim) Global Native

Function Native_Kidnap_RequestRansomLetter(Actor victim, Bool paid, String stewardName = "") Global Native
{Request the steward's ransom reply (sever_letter_writer, templated fallback)
 and queue it as the victim's courier letter; the courier pump delivers it
 (OnVentureLetter), so the caller sends nothing.}

Function Native_Kidnap_RequestRansomReopenLetter(Actor victim, String stewardName = "", Bool abAbandon = false) Global Native
{After a refused ransom whose hired searchers failed: the steward's letter
 reopening negotiation, or (abAbandon) writing the captive off. Same courier
 path as RequestRansomLetter.}

; -- KDNP v5 captivity life --

Function Native_Kidnap_SetHomeMarker(Actor victim, ObjectReference marker) Global Native
{Persistent marker at the victim's pre-grab spot (the escape destination).
 Cosaved; set once at the first grab.}

ObjectReference Function Native_Kidnap_GetHomeMarker(Actor victim) Global Native

Float Function Native_Kidnap_TickUnguarded(Actor victim, Bool guarded, Float now) Global Native
{One guard-watch tick: guarded resets the clock, unguarded adds the game hours
 since the last tick (the first tick after a load only stamps). Returns the
 unguarded hours so far.}

Bool Function Native_Outfit_HasSituationPreset(Actor akActor, String situation) Global Native
{True if the actor has a non-empty preset mapped to this situation.}

Int Function Native_Outfit_GetSchemaVersion() Global Native
{Legacy-importer schema version in the cosave; 0 = needs import.}

Function Native_Outfit_SetSchemaVersion(Int v) Global Native
{Set the schema version once the importer completes.}

Actor[] Function Native_Outfit_GetActorsWithLocks() Global Native
{Every actor with an active lock.}

Actor[] Function Native_Outfit_GetAllTrackedActors() Global Native
{Every actor in OutfitDataStore, locked or not (for Maintenance sweeps; not
 for hot paths - it walks the whole store).}

Bool Function Native_Outfit_IsFollowerLock(Actor akActor) Global Native
{True (default) for a follower lock; false for a non-follower the player
 locked explicitly.}

Function Native_Outfit_SetIsFollowerLock(Actor akActor, Bool isFollower) Global Native
{Set the lock kind; false = non-follower explicit lock.}

Function Native_Outfit_DressStashAdd(Actor akActor, Form item) Global Native
{Stash one item for the Undress/Dress pair. Cosaved (OTFT v6+), so a reload
 between Undress and Dress keeps it.}

Form[] Function Native_Outfit_DressStashGet(Actor akActor) Global Native
{The stashed Undress items.}

Function Native_Outfit_DressStashClear(Actor akActor) Global Native
{Clear the stash once Dress has used it.}

Function Native_Outfit_DressStashSetDefaultOutfit(Actor akActor, Outfit outfit) Global Native
{Snapshot the actor's DefaultOutfit for Dress's fallback.}

Outfit Function Native_Outfit_DressStashGetDefaultOutfit(Actor akActor) Global Native
{The snapshotted DefaultOutfit, or None.}

; === OUTFIT-LOCK SUSPEND / RESUME ===

Function Native_Outfit_SuspendLock(Actor akActor) Global Native
{Suspend the OutfitAlias's re-equip reactions for this actor. Self-clears
 after 300 s if Native_Outfit_ResumeLock never comes (a crash mid-operation).}

Function Native_Outfit_ResumeLock(Actor akActor) Global Native
{Clear the suspend and its deadline. Pair with Native_Outfit_SuspendLock
 around every outfit-changing operation.}

; === FOLLOWER DATA (FollowerDataStore) ===

; --- Per-field relationship setters ---

Function Native_SetRapport(Actor akActor, Float value) Global Native
{Set rapport (clamped to -100..100).}

Function Native_SetTrust(Actor akActor, Float value) Global Native
{Set trust (clamped to 0..100).}

Function Native_SetLoyalty(Actor akActor, Float value) Global Native
{Set loyalty (clamped to 0..100).}

Function Native_SetMood(Actor akActor, Float value) Global Native
{Set mood (clamped to -100..100).}

; --- Atomic relationship deltas ---

Float Function Native_ModifyRapport(Actor akActor, Float delta) Global Native
{Atomic +=delta under FollowerData's mutex; returns the new clamped value.}

Float Function Native_ModifyTrust(Actor akActor, Float delta) Global Native
{Atomic +=delta under FollowerData's mutex; returns the new clamped value.}

Float Function Native_ModifyLoyalty(Actor akActor, Float delta) Global Native
{Atomic +=delta under FollowerData's mutex; returns the new clamped value.}

Float Function Native_ModifyMood(Actor akActor, Float delta) Global Native
{Atomic +=delta under FollowerData's mutex; returns the new clamped value.}

; --- Reads for SetSandboxing / SetIsFollower ---

Bool Function Native_GetSandboxing(Actor akActor) Global Native
{True if the actor is in SA's sandbox state.}

; Every CASUAL follower (hasFollowPkg set, never registered as a companion).
; hasFollowPkg is SA's bookkeeping and goes stale when anything removes the
; package without our clear, so callers re-verify each with
; SkyrimNetApi.HasPackage (a stale flag makes cell catch-up teleport them).
Actor[] Function Native_GetCasualFollowers() Global Native

Actor[] Function Native_GetDeadTrackedFollowers() Global Native
{Tracked followers who are dead (isFollower && IsDead): they stay tracked until Papyrus purges them after the grace period, and the active roster leaves them out.}

Actor[] Function Native_GetActiveFollowerRoster() Global Native
{The active roster: every FollowerDataStore entry with isFollower, resolved and alive, minus the player. No duplicates.}

Bool Function Native_GetIsFollower(Actor akActor) Global Native
{True if the actor is on the roster.}

Bool Function Native_HasFollowerData(Actor akActor) Global Native
{True iff actor has ANY FollowerData entry, even with isFollower=false. Survives soft-dismiss; only cleared by explicit Purge. NOT a follower test (travel, forced combat, casual follow and home/work assignment create rows too) - for "returning vs first recruit" use SeverActionsNativeExt2.Native_WasEverFollower.}

; --- Relationship ticker ---

Function Native_SetInteractionTime(Actor akActor, Float gameTimeSec) Global Native
{Record the player's last interaction with this follower (drives rapport neglect).}

Float Function Native_GetInteractionTime(Actor akActor) Global Native
{Read the last-interaction time. 0.0 = never interacted (no neglect penalty).}

Function Native_SetPlayerBlurb(Actor akActor, String blurb) Global Native
{Store the LLM-written blurb for how this follower feels about the player (shown on the Companions page). "" clears it.}

String Function Native_GetPlayerBlurb(Actor akActor) Global Native
{The player-relationship blurb, or "" if never assessed.}

Actor[] Function Native_TickAllRelationships(Float moodChange, Float rapportLossOnNeglect, Float currentTimeSec, Float neglectSecondsThreshold, Float leavingThreshold, Bool allowLeaving) Global Native
{Run the relationship math (mood drift toward 0.5*rapport, rapport neglect after the grace period) across every tracked follower under one lock acquisition. Unit-agnostic — pass pre-computed deltas:
  moodChange              = MOOD_DECAY_RATE * hoursPassed
  rapportLossOnNeglect    = RapportDecayRate * (hoursPassed / NEGLECT_HOURS)
  currentTimeSec          = GetGameTimeInSeconds()
  neglectSecondsThreshold = NEGLECT_HOURS * SECONDS_PER_GAME_HOUR
Returns actors at or below leavingThreshold so Papyrus can fire the SkyrimNet persistent "considering leaving" event (filtering already-warned ones itself).}

; --- Ambient banter: the request and the gamemaster_dialogue event JSON are
; built in C++ so non-ASCII names survive (Papyrus string concat mangled them).

Int Function Native_AmbientBanter_FireToLLM(Float hearingRadius, Float pairRadius, Int maxPairs) Global Native
{Scan for banter pairs and send the LLM request. Returns >0 pairs sent, 0 no candidates / hostile cell, -1 bridge unavailable. The reply fires SeverActions_AmbientBanterReady (numArg 1.0 = event prepared, 0.0 = silence/failure).}

Form Function Native_FindShoutOnActor(Actor akTeacher, String shoutName) Global Native
{Fuzzy-match a Shout name against the teacher's effective (template-resolved)
 shout list; returns the player-facing Shout, or None. Same match ladder as
 FindSpellOnActor.}

Form Function Native_Shout_GetNextWord(Form akShout) Global Native
{The first of the Shout's three Words of Power the player does not know yet
 (the player-global known flag word walls also set). None = all three learned.}

String Function Native_Shout_WordName(Form akWord) Global Native
{Display name for a Word of Power: the dragon word plus its translation,
 e.g. 'Fus (Force)'.}

Int Function Native_Shout_KnownWordCount(Form akShout) Global Native
{How many of the Shout's three words the player knows (0-3).}

Bool Function Magelight_OpenTradePrompt(Actor counterparty, Int gold, String counterpartyName, String itemName, Int qty, Bool playerBuys, Int timeoutMs) Global Native
{Non-pausing confirm for BuyItem/SellItem when the player is a party: item,
 count and gold, with Accept / Refuse / Refuse silently. A timeout REFUSES.
 Fires SeverActions_TradeChoice (strArg = choice, numArg = gold, sender =
 counterparty). False if the UI is down or another prompt is open - fall back
 to SkyMessage.}

Function Magelight_CloseTradePrompt() Global Native
{Force-close the trade prompt (silent).}

Bool Function Magelight_IsTradePromptOpen() Global Native
{True while a trade prompt is on screen.}

Bool Function Magelight_IsTradePromptAvailable() Global Native
{True when the trade prompt view is created and ready.}

Bool Function Native_LLM_Dispatch(String promptName, String contextJson, String modEventName) Global Native
{LLM relay over the C++ bridge. Use it instead of SkyrimNetApi.SendCustomPromptToLLM,
 whose Papyrus callback truncates replies near 1024 chars. Sends promptName
 (sever_background variant); the reply fires modEventName with strArg = the raw
 response, numArg 1.0 success / 0.0 failure, sender None - register for it
 first. False, and nothing sent, when the bridge is down, llmCallsEnabled is
 off or the prompt is not installed.}

String Function Native_AmbientBanter_GetReadyEventJson() Global Native
{After SeverActions_AmbientBanterReady with numArg 1.0: the gamemaster_dialogue event JSON for SkyrimNetApi.RegisterEvent. "" = nothing ready.}

Actor Function Native_AmbientBanter_GetReadySpeaker() Global Native
{Speaker actor for the prepared event. None if not ready.}

Actor Function Native_AmbientBanter_GetReadyTarget() Global Native
{Target actor for the prepared event. None if not ready.}

Function Native_AmbientBanter_ClearReady() Global Native
{Clear the ready slot after Papyrus consumes it. Idempotent.}

; --- Travel Orchestrator (TravelOrchestrator.h) ---
; A session ticks ~1/s (arrival, stuck escalation, abort, timeout) and ends by
; firing "SeverActions_TravelComplete", strArg "<callbackTag>|<status>", status
; arrived|aborted|gaveup|timedout|cancelled|waitdone|waittimeout|stayended
; (plus a non-terminal "waiting" when an arrival wait starts).
; Options bits: 1 require LOS | 2 return home on fail | 4 abort on degraded
; state | 8 skip preflight | 16 no recovery | 32 quiet (no Traveler_NN
; objective / map marker) | 64 wait at arrival.

Int Function Travel_Begin(Actor akActor, ObjectReference akDestination, Keyword akKeyword, Float arrivalThreshold, String callbackTag, Int options, Int maxDurationSeconds, Int speed) Global Native
{Begin a travel session: a handle > 0, or 0 on rejection.
 speed: 0=walk, 1=jog, 2=run, 3=default (also feeds the time-skip catch-up estimate).}

Int Function Travel_BeginXY(Actor akActor, Float destX, Float destY, Float destZ, Keyword akKeyword, Float arrivalThreshold, String callbackTag, Int options, Int maxDurationSeconds) Global Native
{Begin travel to raw coordinates (no destination ref). Otherwise same as Travel_Begin.}

Function Travel_Cancel(Int handle) Global Native
{Cancel a travel session. Fires the completion event with status 'cancelled'.}

Int Function Travel_CancelByActor(Actor akActor) Global Native
{Cancel all active travels for this actor. Returns the count cancelled.}

Bool Function Travel_IsActive(Int handle) Global Native

Int Function Travel_GetState(Int handle) Global Native
{Returns the numeric TravelState. Live: 2=departing, 3=traveling, 4=recovering, 5=waiting (the arrival wait).
 Terminal: 10=arrived, 11=aborted, 12=gaveup, 13=timedout, 14=cancelled, 15=waitdone, 16=waittimeout, 17=stayended.}

String Function Travel_GetStateName(Int stateCode) Global Native
{idle|preflight|departing|traveling|recovering|waiting|arrived|aborted|gaveup|timedout|cancelled|waitdone|waittimeout|stayended.}

Float Function Travel_GetDistance(Int handle) Global Native
{Live 2D distance from actor to destination, or -1 if unavailable.}

Int Function Travel_GetActiveCount() Global Native

Bool Function Travel_SetSpeed(Int handle, Int speed) Global Native
{Update a live session's speed preset; the caller still swaps the package.}

Int Function Travel_GetSpeed(Int handle) Global Native

Function Travel_RegisterSpeedPackages(Package akWalk, Package akJog, Package akRun, Package akDefault) Global Native
{Register the four speed packages once at init. Any slot may be None.}

Package Function Travel_GetSpeedPackage(Int speed) Global Native
{Resolve a speed preset (0-3) to the registered Package; falls back to default.}

Int Function Travel_ParseSpeedFromText(String text) Global Native
{Parse natural-language ("hurry up", "slow down", "run") to a speed preset.}

String Function Travel_GetSpeedName(Int speed) Global Native
{Human name: 0->"walking", 1->"jogging", 2->"running", else "moving".}

; --- Assign-retainer popup: a non-pausing card offered when the player marks
; work for a non-retainer; Confirm hires like the dashboard's "+ Assign".

Bool Function Magelight_OpenRetainerAssignPrompt(Actor akNpc, String asNamedPlace, String asJob, String asArrangement, Int aiTimeoutMs) Global Native
{Open the popup for this NPC. asNamedPlace prefills the Workplace ("" = here); asJob/asArrangement prefill Trade/Terms ("" = defaults; case-insensitive, e.g. "miner"/"employed"). False if the UI isn't ready, a prompt is open, or another view has focus.
 In VR immersive mode no card shows: a parseable asJob hires on catalog defaults (True); otherwise False, so the caller takes its own path.}

Function Magelight_CloseRetainerAssignPrompt() Global Native
{Silently dismiss the assign-retainer popup (no hire).}

Bool Function Magelight_IsRetainerAssignPromptOpen() Global Native
{True while the assign-retainer popup is showing.}

Bool Function Magelight_IsRetainerAssignPromptAvailable() Global Native
{True if the assign-retainer popup view is created and ready to open, and always True in VR immersive mode (the open call resolves it).}

; --- Travel prompt (non-pausing destination confirm/redirect) ---
Bool Function Magelight_OpenTravelPrompt(Actor akNpc, String asNamedPlace, Int aiTimeoutMs) Global Native
{Open the travel popup for this NPC; asNamedPlace prefills the destination. Confirm fires SeverActions_TravelPromptResult (sender = NPC, strArg = place). False if the UI isn't ready, a prompt is open, or another view has focus.}

Function Magelight_CloseTravelPrompt() Global Native
{Silently dismiss the travel popup (no travel).}

Bool Function Magelight_IsTravelPromptOpen() Global Native
{True while the travel popup is showing.}

Bool Function Magelight_IsTravelPromptAvailable() Global Native
{True if the travel popup view is created and ready to open.}

; --- Camp pushers for Sever's Hearth (Magelight_SetPinnedRestStop and
; Magelight_SetCampStatus are on SeverActionsNative) ---

Function Magelight_SetCampMeta(Float hoursEstablished, Float distanceUnits) Global Native
{Push hours since the camp was made and the player-to-camp distance (game
 units) to the Survival page's camp section.}

Function Magelight_SetCampThreats(String warning) Global Native
{Push a short threats warning to the Survival page's camp section; "" clears it.}

Function Magelight_SetCampMarked(Bool marked) Global Native
{Push whether the camp has a world-map marker (the Mark/Unmark button label).}

Function Magelight_SetCampSandboxPref(Bool enabled) Global Native
{Mirror Hearth's cosaved SandboxOnEstablish so the Settings page shows it.
 Hearth calls it on load and on every toggle; the first call also marks the
 camp system as present.}

; --- StuckDetector, ArrivalMonitor, the page JSON builder, ambient banter pair queries ---

Function Stuck_StartTracking(Actor akActor) Global Native
{Begin tracking an actor for stuck detection}

Function Stuck_StopTracking(Actor akActor) Global Native
{Stop tracking an actor for stuck detection}

Int Function Stuck_CheckStatus(Actor akActor, Float checkInterval, Float moveThreshold) Global Native
{Escalation level: 0 = not stuck, 1+ = stuck (higher = stuck longer).
checkInterval: seconds between checks; moveThreshold: min distance that counts as moving.}

Float Function Stuck_GetTeleportDistance(Actor akActor) Global Native
{Recommended teleport distance for the actor's escalation level.}

Bool Function Stuck_IsTracked(Actor akActor) Global Native
{True if the actor is tracked for stuck detection.}

Function Stuck_ResetEscalation(Actor akActor) Global Native
{Reset the actor's escalation level (after a successful unstick).}

Function Stuck_ClearAll() Global Native
{Clear all stuck tracking.}

Int Function Stuck_GetTrackedCount() Global Native
{Number of actors tracked for stuck detection.}

Int Function Stuck_CheckDeparture(Actor akActor, Float departureThreshold) Global Native
{Has a tracked actor left their start point? 0 = too early (grace period),
 1 = departed, 2 = soft recovery needed (30 s without moving).
 departureThreshold: distance from start that counts as departed (default 100).}

Bool Function Stuck_PreflightReachable(Actor akActor, ObjectReference akDestination, Float speed = 2.0, Float slop = 64.0) Global Native
{True if pathing thinks akDestination is reachable. On false, teleport at once
 instead of spending stuck escalation on an unreachable spot.}

Bool Function Stuck_PreflightReachableXYZ(Actor akActor, Float destX, Float destY, Float destZ, Float speed = 2.0, Float slop = 64.0) Global Native
{Same as Stuck_PreflightReachable but for raw coordinates (no ref).}

Bool Function Stuck_ShouldAbort(Actor akActor) Global Native
{True when travel should abort: the actor is in a kill move (or is None); false while
 unloaded. Death, bleedout, mounts and arrest are not tested (a death aborts the journey itself).}

Bool Function Stuck_GiveUpToEditorLocation(Actor akActor) Global Native
{MoveToEditorLocation, for when teleporting to the destination won't recover
 the actor (e.g. broken navmesh). True on success.}

Function Arrival_Register(Actor akActor, ObjectReference akDestination, Float distanceThreshold, String callbackTag) Global Native
{Watch an actor until they are within distanceThreshold of a ref, then fire
 SeverActionsNative_OnArrival once (strArg = callbackTag, numArg = distance,
 sender = the actor).}

Function Arrival_RegisterXY(Actor akActor, Float destX, Float destY, Float distanceThreshold, String callbackTag) Global Native
{Arrival_Register for an X/Y point.}

Function Arrival_Cancel(Actor akActor) Global Native
{Cancel arrival monitoring for an actor.}

Bool Function Arrival_IsTracked(Actor akActor) Global Native
{True if the actor is watched for arrival.}

Float Function Arrival_GetDistance(Actor akActor) Global Native
{Current distance from a watched actor to their destination, or -1 if not watched.}

Int Function Arrival_GetTrackedCount() Global Native
{Number of actors watched for arrival.}

Function Arrival_RegisterLOS(Actor akActor, ObjectReference akDestination, Float distanceThreshold, String callbackTag) Global Native
{Arrival_Register that also needs line of sight.}

Function Arrival_RegisterLOSXY(Actor akActor, Float destX, Float destY, Float distanceThreshold, String callbackTag) Global Native
{Arrival_RegisterXY that also needs line of sight.}

Function Arrival_ClearAll() Global Native
{Clear all arrival monitoring data.}

Function Magelight_BeginPage(String page) Global Native
{Start building JSON for a page. Resets any in-progress build.}

Function Magelight_AddString(String key, String value) Global Native
{Add a string key-value to the current object.}

Function Magelight_AddBool(String key, Bool value) Global Native
{Add a boolean key-value (C++ writes true/false, not TRUE/FALSE).}

Function Magelight_AddInt(String key, Int value) Global Native
{Add an integer key-value to the current object.}

Function Magelight_AddFloat(String key, Float value) Global Native
{Add a float key-value to the current object.}

Function Magelight_BeginArray(String key) Global Native
{Start a JSON array under the given key.}

Function Magelight_EndArray() Global Native
{End the current array.}

Function Magelight_BeginObject() Global Native
{Start an anonymous object (typically inside an array).}

Function Magelight_BeginNamedObject(String key) Global Native
{Start a named object under the given key.}

Function Magelight_EndObject() Global Native
{End the current object (named or anonymous).}

Function Magelight_PushString(String value) Global Native
{Push a bare string value into the current array.}

Function Magelight_PushInt(Int value) Global Native
{Push a bare integer value into the current array.}

Function Magelight_PushFloat(Float value) Global Native
{Push a bare float value into the current array.}

Function Magelight_PushBool(Bool value) Global Native
{Push a bare boolean value into the current array.}

Function Magelight_SendPage() Global Native
{Serialize the built JSON and send it to the UI.}

Int Function Native_AmbientBanter_ScanAndCache(Float hearingRadius, Float pairRadius, Int maxPairs) Global Native
{Scan the player's cell for banter pairs and cache them for the GetPair*
 getters. Returns the pair count (0-maxPairs); 0 when a hostile is loaded near
 the player. 0 for any param = its default (2000, 768, 6).}

Int Function Native_AmbientBanter_GetPairFormA(Int idx) Global Native
Int Function Native_AmbientBanter_GetPairFormB(Int idx) Global Native
String Function Native_AmbientBanter_GetPairNameA(Int idx) Global Native
String Function Native_AmbientBanter_GetPairNameB(Int idx) Global Native
String Function Native_AmbientBanter_GetPairRaceA(Int idx) Global Native
String Function Native_AmbientBanter_GetPairRaceB(Int idx) Global Native
Float Function Native_AmbientBanter_GetPairDistance(Int idx) Global Native


; --- SpellCastManager, SituationMonitor ---
; (Native_GetActorProcessLevel is on SeverActionsNative, where GuardFinder registers it.)

Function Native_EvaluateActorPackage(Actor akActor) Global Native
{Force the actor's AI package re-evaluation, e.g. after removing an override.
 SpellCastManager registers it on this class; declare it nowhere else.}

Bool Function Native_InjectSpellIntoPackage(Package akPackage, Spell akSpell) Global Native
{Swap the Spell in akPackage's custom data for akSpell, so one castmagic
package can cast any spell the LLM names.}

Bool Function Native_IsSelfDeliveredSpell(Spell akSpell) Global Native
{True if the spell's delivery type is Self (costliest effect targets the caster).}

Bool Function Native_IsHealingSpell(Spell akSpell) Global Native
{True if the spell is Restoration with an effect that restores Health (a value or peak-value
 modifier, not detrimental or Recover), so wards and Turn Undead are false. Gates the heal-to-full loop.}

Int Function Native_GetEffectiveMagickaCost(Actor akCaster, Spell akSpell, Bool bDualCasting) Global Native
{Magicka cost the caster will actually pay, post skill/perk modifiers. Doubled for dual cast.}

Bool Function Native_IsCasterStillCasting(Actor akCaster) Global Native
{True while the caster's graph reports IsCastingLeft/IsCastingRight (the stuck-charge watchdog).}

Function Native_ForceReleaseCast(Actor akCaster) Global Native
{Interrupt + fire animation release events on both hands. Recovers a caster stuck in ChargeLoop.}

Function Native_DiagnoseCastSetup(Actor akActor, Spell akSpell) Global Native
{Logs the spell's castingType, equipSlot and cost, the actor's package, combat
state and equipped slots - to find out why a cast won't fire.}

Function Native_EquipSpellOnActor(Actor akActor, Spell akSpell, Int aiSlot) Global Native
{Equip a spell in a slot (0=left, 1=right, 2=voice, else either hand). Without it the
UseMagic procedure can lose the equip race to CombatStyle weapon preferences.}

Spell Function Native_CloneSpellForCast(Actor akActor, Spell akSource, Bool abDualCasting) Global Native
{Clone a spell into a fresh runtime SpellItem (after bosn's clonePackageSpell):
no casting perk, equipSlot EitherHand. Inject the clone with
Native_InjectSpellIntoPackage - with some originals (Requiem's) the UseMagic
procedure runs but never reaches the MagicCaster.}

Bool Function Native_ForceFireSpell(Actor akActor, Spell akSpell, ObjectReference akTarget) Global Native
{Fire a spell from the actor's MagicCaster at the target, bypassing the package
procedure (the animation may not play). Fallback for when UseMagic never
dispatches (MagicCaster state stays 0).}

Function SituationMonitor_SetEnabled(Bool enabled) Global Native
{Enable or disable the OUTFIT auto-switch half of the situation monitor
 (settings row outfitAutoSwitch). The safe-interior half has its own toggle,
 SituationMonitor_SetSafeInteriorEnabled.}

Bool Function SituationMonitor_IsEnabled() Global Native
{Check if the outfit auto-switch half of the situation monitor is enabled.}

String Function SituationMonitor_GetSituation(Actor akActor) Global Native
{Get the current detected situation for an actor (adventure, town, home, sleep).}

Function SituationMonitor_ForceEvaluate(Actor akActor) Global Native
{Force immediate situation re-evaluation for an actor, bypassing stability delay.}

Function SituationMonitor_SetScanInterval(Int ms) Global Native
{Set the scan interval in milliseconds (1000-30000, default 3000).}

Int Function SituationMonitor_GetScanInterval() Global Native
{Get the current scan interval in milliseconds.}

Function SituationMonitor_SetStabilityThreshold(Int ms) Global Native
{Set the stability threshold in milliseconds (1000-30000, default 5000).}

Int Function SituationMonitor_GetStabilityThreshold() Global Native
{Get the current stability threshold in milliseconds.}

Function SituationMonitor_RescueSandboxers() Global Native
{Bring auto-sandboxing followers left in a previous cell to the player (call on cell load).}

Function SituationMonitor_SetSafeInteriorEnabled(Bool enabled) Global Native
{Enable or disable the safe-interior auto-sandbox. Session-only; SeverActions_Follow re-pushes it on load.}

Bool Function SituationMonitor_IsSafeInteriorEnabled() Global Native
{Check if safe interior auto-sandbox is currently enabled in C++.}

; === BOUNTY STORE: tracked bounty per crime faction, cosave 'BNTY' ===
; Set <= 0 and Clear drop an entry with its event log; Mod to <= 0 keeps the
; row at 0 while it has events, so the ledger history survives a payoff.

Int Function Native_Bounty_Get(Faction crimeFaction) Global Native
{Return the tracked bounty for the given crime faction (0 if none).}

Function Native_Bounty_Set(Faction crimeFaction, Int amount) Global Native
{Set absolute bounty for the faction. amount <= 0 removes the entry and its events.}

Int Function Native_Bounty_Mod(Faction crimeFaction, Int delta) Global Native
{Atomically add delta; returns the new total (0 once it reaches <= 0).}

; BNTY v3 offender axis: an NPC's own tracked bounty. akOffender None (or the
; player) means the player's entries, which the calls above always use.
Int Function Native_Bounty_ModFor(Actor akOffender, Faction crimeFaction, Int delta) Global Native
Int Function Native_Bounty_GetFor(Actor akOffender, Faction crimeFaction) Global Native
Function Native_Bounty_AddEventFor(Actor akOffender, Faction crimeFaction, Int delta, String crimeType, String holdName) Global Native
{Metadata only: append a crime event row (type/hold/delta) to the offender's
 ring for the ledger timeline. Never changes the amount - pair with ModFor.}

Function Native_Bounty_Clear(Faction crimeFaction) Global Native
{Remove the bounty entry for this faction.}

Function Native_Bounty_ClearAll() Global Native
{Wipe the whole store, NPC offenders' entries included.}

Int Function Native_Bounty_GetCount() Global Native
{Number of entries in the store, NPC offenders' included.}

Int Function Native_Bounty_GetTotal() Global Native
{The player's tracked bounty summed over every hold.}

; --- Paired snapshot (player entries, at most 32): call SnapshotAll, then the
; two getters, which read that one capture so facs[i] pairs with amounts[i].

Int Function Native_Bounty_SnapshotAll() Global Native
{Capture the player's bounty entries into the snapshot. Returns the count.}

Faction[] Function Native_Bounty_GetSnapshotFactions() Global Native
{Read the factions from the snapshot captured by Native_Bounty_SnapshotAll. Index-aligned with GetSnapshotAmounts.}

Int[] Function Native_Bounty_GetSnapshotAmounts() Global Native
{Read the amounts from the snapshot captured by Native_Bounty_SnapshotAll. Index-aligned with GetSnapshotFactions.}

; --- Bounty event log (the World page Ledger timelines) ---

Function Native_Bounty_AddEvent(Faction crimeFaction, Int delta, String crimeType, String hold) Global Native
{Append a crime row to the faction's event ring (32 rows, FIFO). Metadata only:
 call Native_Bounty_Mod with the same delta first. crimeType is canonical
 (ArrestBounty.NormalizeCrimeType: assault / theft / murder / trespass /
 pickpocket / contempt / abuse_of_power); hold is the display name, stored so
 the row renders even if the faction later fails to resolve.}

; === LOOT THEFT (InventoryUtils.h) ===
; ProcessLoot / PickUpItemSilent leave the theft result for the getters below;
; read it right after. Owned takes never raise vanilla crime: the loot script
; charges a tracked bounty (Native_Bounty_Mod) instead, only when witnessed.

Int Function GetLastStolenValue() Global Native
{Summed gold value of OWNED items taken by the most recent ProcessLoot / PickUpItemSilent. 0 if the source was unowned (no theft).}

Faction Function GetLastStolenCrimeFaction() Global Native
{Crime faction the theft bounty should be charged to (owner NPC's crime faction, else the player's current-location crime faction). None if unresolved.}

Bool Function IsRefOwnedByNonPlayer(ObjectReference ref) Global Native
{True if ref is owned by someone other than the player / a player-allied faction. Used to route owned pickups through the silent path.}

Bool Function IsTheftWitnessed(Actor thief, Float radius) Global Native
{True if a loaded, alive, awake, non-follower actor within radius has line-of-sight to the thief. Gates the SA theft bounty so unseen looting is free.}

String Function Native_Loot_DescribeContents(ObjectReference source, Int maxNotable) Global Native
{Inventory summary for the Search actions: named entries by unit value (up to
 maxNotable), gold as a total, a "sundry lesser goods" tail when cut short.
 "" = empty.}

Int Function PickUpItemSilent(Actor akActor, ObjectReference itemRef) Global Native
{Move a world item into akActor's inventory WITHOUT Activate (no vanilla theft alarm), best-effort flag it stolen and record the theft. Returns the count moved. Owned items only: unowned pickups should Activate (keeps extras, no crime).}

Actor Function FindNearestDeadByName(Actor origin, String name, Float radius) Global Native
{Nearest DEAD actor named `name` within radius of origin, so a living namesake can't shadow the corpse. Falls back to the global index when no loaded corpse matches.}

; === CEASEFIRE (CeasefireMonitor, cosave 'CEAS') ===
; The monitor owns apply and restore. Combat.RegisterEvents pushes the two
; Set* configs on every load (they are cosaved as well).

Function Ceasefire_SetSurrenderedFaction(Faction f) Global Native
{The faction pacified actors are put INTO.}

Function Ceasefire_SetHostileFactionsList(FormList l) Global Native
{The "normally hostile" factions: an actor's membership in any is stashed for restore on break and sets wasNormallyHostile. The ESP never fills this list; unset, TruceEligibility's hostile set is used.}

Bool Function Ceasefire_ApplyToActor(Actor akActor, Actor akPartner) Global Native
{Zero aggression, faction-swap, stop combat, register. True if newly applied, false if already monitored.}

Actor[] Function Ceasefire_PropagateGroup(Actor akInitiator, Actor akPartner, Float radius) Global Native
{Ceasefire the initiator, the partner and nearby faction allies in combat. Returns every actor affected, for Papyrus bookkeeping.}

Function Ceasefire_ForceBreak(Actor akActor) Global Native
{Restore aggression, factions and relationship rank WITHOUT the broken ModEvent (FullCleanup, so the prompt sees no yield-broken transition).}

Bool Function Ceasefire_IsWasNormallyHostile(Actor akActor) Global Native
{The entry's wasNormallyHostile flag (Papyrus mirrors it to StorageUtil for prompts).}

; === YIELD (YieldMonitor, cosave 'YLDD') ===
; The monitor converts a yielded actor and restores it on a hit-driven break or
; ReturnToCrime, so the Papyrus handlers only clear prompt StorageUtil keys.
; Combat.RegisterEvents pushes the Set* configs on every load (also cosaved).

Function Yield_SetSurrenderedFaction(Faction f) Global Native
{The faction yielded actors are put INTO.}

Function Yield_SetHostileFactionsList(FormList l) Global Native
{The "normally hostile" factions: an actor's membership in any is stashed for restore on revert / return-to-crime and sets wasNormallyHostile. Same TruceEligibility fallback as Ceasefire_SetHostileFactionsList.}

Bool Function Yield_ConvertToSurrendered(Actor akActor) Global Native
{Zero aggression, swap hostile factions for SeverSurrenderedFaction, and store the originals in the entry. True if a hostile faction was removed (WasNormallyHostile).}

Function Yield_ReturnToCrime(Actor akActor) Global Native
{Deliberate revert: restore aggression and hostile factions, leave SeverSurrenderedFaction, unregister. Silent (no SeverActionsNative_YieldBroken).}

Function Yield_ForceBreak(Actor akActor) Global Native
{Same as Yield_ReturnToCrime (named for FullCleanup's call site).}

Bool Function Yield_IsWasNormallyHostile(Actor akActor) Global Native
{The entry's wasNormallyHostile flag, for the prompt-side StorageUtil mirror.}

; === BRAWL MANAGER: fist-fight pairs (player-NPC and NPC-NPC) ===
; Vanilla DGIntimidateFaction makes bleedout non-lethal; a TESEquipEvent sink
; enforces fists. Ends on bleedout, forfeit, cheating (a non-unarmed hit) or
; interference. Active brawls are NOT cosaved (only 'BSRC', the stripped-spell
; recovery list).

Bool Function Brawl_Begin(Actor a, Actor b) Global Native
{Start a brawl: snapshot loadouts, apply DGIntimidateFaction, give NPCs the
 brawler CombatStyle and Aggression 1 / Confidence 3, unequip weapons, spells,
 scrolls and ammo, StartCombat both ways. False if either is None, dead or
 already brawling.}

Function Brawl_End(Actor actor, Int reason) Global Native
{End `actor`'s brawl: restore the snapshot and re-equip. Reasons:
   1 = LoserBleedout
   2 = Forfeit
   3 = WalkedAway
   4 = BrokenToCombat (cheating / interference; Papyrus then forces a real fight)
   5 = Abort (no winner: a safety wipe, or a knockout an outside hit decided, which
       names the downed fighter as loser)
   6 = ForfeitSheathed (the player sheathed mid-brawl; set natively, not an argument here)
   7 = CalledOff (cheating / interference between the player and a companion, or two
       companions: it ends there, never as a real fight)
 No-op outside a brawl. Fires SeverBrawl_Ended (sender = the actor, numArg = the
 reason); read the outcome with the Brawl_GetLast* natives.}

Bool Function Brawl_IsActive(Actor a) Global Native
{True iff `a` is in an active brawl.}

Actor Function Brawl_GetOpponent(Actor a) Global Native
{Returns the other participant in `a`'s active brawl, or None if not brawling.}

Function Brawl_SetDGFaction(Faction f) Global Native
{Hand the vanilla DGIntimidateFaction (Skyrim.esm 0x04CFA6) to the manager.
 Pushed by SeverActions_Brawl.PushBrawlConfigToNative on every load.}

Function Brawl_SetBrawlerCS(CombatStyle cs) Global Native
{Hand the brawler CombatStyle (vanilla csWEBrawler, Skyrim.esm 0x10555D) to the
 manager; it is swapped onto NPC brawlers at brawl start.}

Actor Function Brawl_GetLastWinner() Global Native
{Winner of the last brawl to end this session (set by Brawl_End). None before
 any brawl and after an Abort. A WalkedAway, BrokenToCombat or CalledOff end has no
 real loser, so participant A fills winner and B loser.}

Actor Function Brawl_GetLastLoser() Global Native
{Loser of the last brawl to end. See Brawl_GetLastWinner; after an Abort, the
 fighter who went down in a knockout an outside hit decided, else None.}

Int Function Brawl_GetLastReason() Global Native
{Reason code of the last brawl to end (see Brawl_End), 0 if none.}

; === COMBAT COOLDOWN (cosave 'CDWN') ===
; Per-actor cooldown set after a yield, ceasefire or brawl; AttackTarget and
; ChallengeBrawl_Execute refuse while it runs (SeverActions_Combat.AttackOnCooldown).
; Stores the expiry as absolute game time in days.

Function Cooldown_Set(Actor akActor, Float durationSeconds) Global Native
{Set the cooldown to expire durationSeconds of real time from now (at the current timescale),
 replacing any existing one.}

Bool Function Cooldown_IsActive(Actor akActor) Global Native
{True while the actor's cooldown runs. Drops an expired entry.}

Function Cooldown_Clear(Actor akActor) Global Native
{Clear the actor's cooldown.}

; === DEBT STORE (cosave 'DEBT'): gold owed between actors ===
; Ids are monotonic Ints (>= 1) assigned at Add and never recycled, so event keys
; built from an id never collide; 0 = not found. Times are game DAYS
; (Utility.GetCurrentGameTime() units).

Int Function Native_Debt_Add(Actor creditor, Actor debtor, Int amount, String reason, Float dueGameDays, Bool isRecurring, Float intervalDays, Int creditLimit, Int recurringCharge) Global Native
{Create a debt. Returns its id, or 0 on bad args (None actor, amount <= 0,
 creditor == debtor). The amount clamps to creditLimit; a recurring debt with
 recurringCharge <= 0 charges amount. Non-recurring: pass false, 0.0, 0.}

Bool Function Native_Debt_Remove(Int id) Global Native
{Remove the debt. True if it existed.}

Bool Function Native_Debt_Exists(Int id) Global Native
{True while the debt is in the store.}

Int Function Native_Debt_GetCount() Global Native
{Number of debts in the store.}

Int[] Function Native_Debt_GetAllIDs() Global Native
{All live debt ids, unordered.}

Actor Function Native_Debt_GetCreditor(Int id) Global Native
Actor Function Native_Debt_GetDebtor(Int id) Global Native
Int   Function Native_Debt_GetAmount(Int id) Global Native
String Function Native_Debt_GetReason(Int id) Global Native
Float Function Native_Debt_GetDueGameDays(Int id) Global Native
{0.0 = open-ended.}
Int   Function Native_Debt_GetCreditLimit(Int id) Global Native
{0 = unlimited.}
Bool  Function Native_Debt_GetIsRecurring(Int id) Global Native
Float Function Native_Debt_GetIntervalDays(Int id) Global Native
Float Function Native_Debt_GetLastRecurredGameDays(Int id) Global Native
Int   Function Native_Debt_GetRecurringCharge(Int id) Global Native
Bool  Function Native_Debt_GetOverdueNotified(Int id) Global Native
Bool  Function Native_Debt_GetReportedToGuards(Int id) Global Native

Int Function Native_Debt_ModifyAmount(Int id, Int delta) Global Native
{Apply delta; a rise clamps to the credit limit. Returns the new amount (0 = paid
 off and removed, also 0 for an unknown id), or -1 when the debt is already at
 its limit (unchanged).}

Function Native_Debt_MarkRecurred(Int id, Float gameDays) Global Native
{Stamp lastRecurredGameDays, the recurring-cycle cursor.}

Function Native_Debt_SetOverdueNotified(Int id, Bool value) Global Native
Function Native_Debt_SetReportedToGuards(Int id, Bool value) Global Native

Int Function Native_Debt_FindByTriple(Actor creditor, Actor debtor, String reason) Global Native
{A creditor + debtor + reason match (reason case-insensitive), or 0.}

Int Function Native_Debt_FindFirstPair(Actor creditor, Actor debtor) Global Native
{The creditor -> debtor debt to charge a new amount to (any reason): the oldest
 non-recurring tab, else the oldest recurring one, or 0.}

Int Function Native_Debt_FindRecurringPair(Actor creditor, Actor debtor) Global Native
{A recurring creditor -> debtor debt, or 0.}

Int Function Native_Debt_SumOwed(Actor creditor, Actor debtor) Global Native
{Total gold debtor owes creditor across all their debts.}

Int Function Native_Debt_SumOwedBy(Actor debtor) Global Native
Int Function Native_Debt_SumOwedTo(Actor creditor) Global Native

Bool Function Native_Debt_HasAnyDebt(Actor actor) Global Native
Bool Function Native_Debt_IsCreditorOnAnyDebt(Actor actor) Global Native

Int Function Native_Debt_ReduceForPayment(Actor creditor, Actor debtor, Int amountPaid) Global Native
{Pay down the creditor -> debtor debts oldest first, removing any that reach 0.
 Returns the amount applied (<= amountPaid). The caller registers any events.}

Int Function Native_Debt_FindBestForGiveItem(Actor giver, Actor receiver) Global Native
{The giver -> receiver debt to charge a given item's value to: the oldest tab
 (non-recurring), else the oldest rent (recurring), or 0.}

; --- Debt tick + event drain ---
; Native_Debt_Tick applies recurring charges and overdue / guard-report changes
; and queues SkyrimNet events. SkyrimNet's event registration is Papyrus-only, so
; the caller drains the queue by index and then clears it: see
; SeverActions_Debt.TickDebts. Kinds (DebtStore::DebtEventKind): 0 RegisterEvent,
; 1 RegisterShortLivedEvent, 2 RegisterPersistentEvent, 3 DirectNarration (the
; creditor's collection ask).

Int Function Native_Debt_Tick(Bool overdueEnabled, Float graceGameDays, Float reportGameDays) Global Native
{Run the debt tick. Returns how many queued events the caller must drain. The
 grace and report thresholds are in game days.}

Int Function Native_Debt_PendingEventCount() Global Native
Int Function Native_Debt_PendingEvent_Kind(Int index) Global Native
String Function Native_Debt_PendingEvent_Name(Int index) Global Native
String Function Native_Debt_PendingEvent_Content(Int index) Global Native
String Function Native_Debt_PendingEvent_Key(Int index) Global Native
Int Function Native_Debt_PendingEvent_TTL(Int index) Global Native
Actor Function Native_Debt_PendingEvent_Creditor(Int index) Global Native
Actor Function Native_Debt_PendingEvent_Debtor(Int index) Global Native
Function Native_Debt_ClearPendingEvents() Global Native

; === Follower pair relationships ===

String Function Native_GetPairBlurb(Actor akActor, Actor akTarget) Global Native
{The LLM-written blurb of how akActor feels about akTarget, or "".}


; === Per-follower scalars on FollowerData (FLWD v10) ===
; An unset value reads 0 / false / None.

; Dedup watermarks for the relationship-assess LLM pass.
Int Function Native_GetLastAssessEventId(Actor akActor) Global Native
Function Native_SetLastAssessEventId(Actor akActor, Int value) Global Native

Int Function Native_GetLastAssessMemoryId(Actor akActor) Global Native
Function Native_SetLastAssessMemoryId(Actor akActor, Int value) Global Native

Int Function Native_GetLastAssessDiaryId(Actor akActor) Global Native
Function Native_SetLastAssessDiaryId(Actor akActor, Int value) Global Native

; Dedup watermarks for the inter-follower (pair) opinions assess loop.
Int Function Native_GetLastInterAssessEventId(Actor akActor) Global Native
Function Native_SetLastInterAssessEventId(Actor akActor, Int value) Global Native

Int Function Native_GetLastInterAssessMemoryId(Actor akActor) Global Native
Function Native_SetLastInterAssessMemoryId(Actor akActor, Int value) Global Native

Int Function Native_GetLastInterAssessDiaryId(Actor akActor) Global Native
Function Native_SetLastInterAssessDiaryId(Actor akActor, Int value) Global Native

; Suppresses home behaviour re-entry until cleared.
Bool Function Native_GetHomeSceneSuspended(Actor akActor) Global Native
Function Native_SetHomeSceneSuspended(Actor akActor, Bool value) Global Native

; Set once the "wants to leave" warning has fired (dedup).
Bool Function Native_GetLeaveWarned(Actor akActor) Global Native
Function Native_SetLeaveWarned(Actor akActor, Bool value) Global Native

; Game-time seconds when the follower's death was detected; 0 = none recorded.
Float Function Native_GetDeathTime(Actor akActor) Global Native
Function Native_SetDeathTime(Actor akActor, Float value) Global Native

; Pre-recruitment combat style, restored on dismiss.
Form Function Native_GetOrigCombatStyleForm(Actor akActor) Global Native
Function Native_SetOrigCombatStyleForm(Actor akActor, Form combatStyle) Global Native

; Essential-flag tracking.
Bool Function Native_GetEssentialOff(Actor akActor) Global Native
Function Native_SetEssentialOff(Actor akActor, Bool value) Global Native

Bool Function Native_GetWasEssential(Actor akActor) Global Native
Function Native_SetWasEssential(Actor akActor, Bool value) Global Native

; Recruited through Serana's vampire-companion route (a custom-AI signal).
Bool Function Native_GetRecruitedViaSerana(Actor akActor) Global Native
Function Native_SetRecruitedViaSerana(Actor akActor, Bool value) Global Native

; === Per-follower text (FLWD v11) ===
; companionOpinions: markdown built by FollowerSystemHydrator. lifeEventHistory:
; "- [when] summary" lines of recent off-screen life events. Read by the sever_companion_opinions /
; sever_life_event_history decorators.

String Function Native_GetCompanionOpinions(Actor akActor) Global Native
Function Native_SetCompanionOpinions(Actor akActor, String value) Global Native

String Function Native_GetLifeEventHistory(Actor akActor) Global Native
Function Native_SetLifeEventHistory(Actor akActor, String value) Global Native

; === Life summary and work / play marker labels (FLWD v12) ===

String Function Native_GetLifeSummary(Actor akActor) Global Native
Function Native_SetLifeSummary(Actor akActor, String value) Global Native

String Function Native_GetWorkLocationName(Actor akActor) Global Native
Function Native_SetWorkLocationName(Actor akActor, String value) Global Native

; === Truce probes (read-only diagnostics) ===
; Would this actor be pacified, and if not, which gate refused it: quest alias,
; unique, essential / protected, frenzied, quest-scoped faction, raidable dungeon,
; or not in an enabled faction.
String Function Native_Truce_ExplainActor(Actor akActor, Bool abNecromancers, Bool abForsworn, Bool abVampires) Global Native

; Same, for the actor under the crosshair. Vampires count only with abVampires
; AND a vampire PLAYER.
String Function Native_Truce_ExplainTarget(Bool abNecromancers, Bool abForsworn, Bool abVampires) Global Native

; Log a verdict for every in-scope loaded actor within afRadius (<= 0 = 3000),
; skipping out-of-scope ones, so one call reads a whole camp. Returns a one-line
; summary.
String Function Native_Truce_ExplainNearby(Float afRadius, Bool abNecromancers, Bool abForsworn, Bool abVampires) Global Native

; === Camp probes (diagnostics) ===
; Every camp the sweep has found: name, state, member count and leader.
String Function Native_Camp_Probe() Global Native

; Freeze respawn for the camp the player stands in: kNeverResets on its encounter
; zone (what actually stops repopulation) plus Location.cleared (the map only).
; Both originals are recorded for Native_Camp_ThawHere.
String Function Native_Camp_FreezeHere() Global Native

; Undo Native_Camp_FreezeHere for the camp the player stands in.
String Function Native_Camp_ThawHere() Global Native

; === Truce controls ===
; Master switch. OFF restores every pacified actor at once.
Function Native_Truce_SetEnabled(Bool abEnabled) Global Native

; The opt-in faction groups (bandits are always in scope). Vampires count only
; while the PLAYER is one.
Function Native_Truce_SetScope(Bool abNecromancers, Bool abForsworn, Bool abVampires) Global Native

; Include named camp leaders / bosses (default ON: the chief is the one worth
; negotiating with). The quest, essential and frenzied gates still apply.
Function Native_Truce_SetIncludeLeaders(Bool abInclude) Global Native

; Include actors a RUNNING quest is using (default ON: camp chiefs are often
; radiant targets). An attack still breaks the truce, so kill objectives play out
; as vanilla; turn OFF if a quest that needs the NPC to strike first stalls.
Function Native_Truce_SetIncludeQuestNPCs(Bool abInclude) Global Native

; Sweep radius in units, clamped 512-12000 (default 8000).
Function Native_Truce_SetRadius(Float afRadius) Global Native

; How many actors are pacified now (the restore ledger's size).
Int Function Native_Truce_PacifiedCount() Global Native

; Panic button / uninstall path: restore every pacified actor now.
Function Native_Truce_RestoreAll() Global Native

; The play-marker label (FLWD v12, with Native_GetWorkLocationName above).
String Function Native_GetPlayLocationName(Actor akActor) Global Native
Function Native_SetPlayLocationName(Actor akActor, String value) Global Native

; === Schedule alias pools (FLWD v16) ===
; The NPC's alias index in each of the three 200-alias schedule quests
; (SeverActions_SchedHome/Work/RelaxQuest). aiSchedType: 0 home, 1 work,
; 2 relax/play (FollowerManager's SCHEDULE_*); -1 = no alias of that type. The
; alias fill is the enforcement; the index is bookkeeping for verification, pool
; display and drift repair.
Int Function Native_GetSchedAliasIndex(Actor akActor, Int aiSchedType) Global Native
Function Native_SetSchedAliasIndex(Actor akActor, Int aiSchedType, Int aiIndex) Global Native

; One-way Route B -> alias migration flag (store-global, cosaved), set once
; before the first migration fill batch.
Bool Function Native_GetAliasesMigrated() Global Native
Function Native_SetAliasesMigrated(Bool abMigrated) Global Native

; Pool usage for the MCM / board: Int[3] {homeUsed, workUsed, relaxUsed}.
Int[] Function Native_GetSchedPoolUsage() Global Native

; === Work-hours override (FLWD v17) ===
; Game hours 0-24, -1 = inherit the global WORK window. start > end wraps past
; midnight; 0-24 is round the clock. Work beats Relax where the windows overlap.
Function Native_SetWorkHoursOverride(Actor akActor, Float afStart, Float afEnd) Global Native
Function Native_ClearWorkHoursOverride(Actor akActor) Global Native
Float Function Native_GetWorkHoursOverrideStart(Actor akActor) Global Native
Float Function Native_GetWorkHoursOverrideEnd(Actor akActor) Global Native

; === Follow alias pool (FLWD v18) ===
; The companion's alias in the 200-alias SeverActions_FollowQuest
; (Follower_000..199); -1 = not alias-held (legacy slot, overflow or casual
; follow). The alias packages re-apply natively on cell load; the index is
; bookkeeping for verification and the load-time adoption sweep.
Int Function Native_GetFollowAliasIndex(Actor akActor) Global Native
Function Native_SetFollowAliasIndex(Actor akActor, Int aiIndex) Global Native

; === Guard alias pool (FLWD v19) ===
; A guard-mode retainer's alias in the 100-alias SeverActions_GuardQuest
; (Guard_00..99); -1 = not alias-held. The alias's GuardBodyguard package
; re-applies natively on cell load; the prio-110 override stays as the
; pool-exhaustion fallback.
Int Function Native_GetGuardAliasIndex(Actor akActor) Global Native
Function Native_SetGuardAliasIndex(Actor akActor, Int aiIndex) Global Native

; === Active player arrest: the arrest quest's FSM state (cosave 'AARS') ===

Function Native_Arrest_SetActiveArrest(Int arrestState, Actor guard, Actor prisoner, ObjectReference jailMarker, String jailName, Float approachStart, Float escortStart) Global Native
Function Native_Arrest_ClearActiveArrest() Global Native

Int Function Native_Arrest_GetActiveArrestState() Global Native
Actor Function Native_Arrest_GetActiveArrestGuard() Global Native
Actor Function Native_Arrest_GetActiveArrestPrisoner() Global Native
ObjectReference Function Native_Arrest_GetActiveArrestJailMarker() Global Native
String Function Native_Arrest_GetActiveArrestJailName() Global Native

; === Per-guard dispatch context + the active dispatch guard (cosave 'ARDC') ===

Function Native_Arrest_SetDispatchContext(Actor guard, Int phase, Actor target, ObjectReference returnMarker, Actor sender, ObjectReference homeMarker, String reason, Bool isHome, Float origAggro, Float origConf) Global Native
Function Native_Arrest_SetDispatchPhase(Actor guard, Int phase) Global Native
Function Native_Arrest_ClearDispatchContext(Actor guard) Global Native

Int Function Native_Arrest_GetDispatchPhase(Actor guard) Global Native
Actor Function Native_Arrest_GetDispatchTarget(Actor guard) Global Native
ObjectReference Function Native_Arrest_GetDispatchReturnMarker(Actor guard) Global Native
Actor Function Native_Arrest_GetDispatchSender(Actor guard) Global Native
ObjectReference Function Native_Arrest_GetDispatchHomeMarker(Actor guard) Global Native
String Function Native_Arrest_GetDispatchReason(Actor guard) Global Native
Bool Function Native_Arrest_GetDispatchIsHome(Actor guard) Global Native
Float Function Native_Arrest_GetDispatchOrigAggro(Actor guard) Global Native
Float Function Native_Arrest_GetDispatchOrigConf(Actor guard) Global Native

Function Native_Arrest_SetActiveDispatchGuard(Actor guard) Global Native
Actor Function Native_Arrest_GetActiveDispatchGuard() Global Native

; === Pending evidence (cosave 'ARPE') ===
; Keyed by the SENDER (the crime reporter); the deferred-sender singleton tracks
; the current sender through the dispatch flow.

Function Native_Arrest_SetPendingEvidence(Actor sender, String narration, Actor guard) Global Native
Function Native_Arrest_ClearPendingEvidence(Actor sender) Global Native
Bool Function Native_Arrest_HasPendingEvidence(Actor sender) Global Native
String Function Native_Arrest_GetPendingNarration(Actor sender) Global Native
Actor Function Native_Arrest_GetPendingGuard(Actor sender) Global Native

Function Native_Arrest_SetDeferredSender(Actor sender) Global Native
Actor Function Native_Arrest_GetDeferredSender() Global Native

; === Survival: last eat attempt (SurvivalDataStore v3) ===
; The hunger bracket (a multiple of 10) of the follower's last auto-eat attempt;
; the survival tick retries only once hunger reaches a higher bracket.

Int Function Native_Survival_GetLastEatAttempt(Actor akActor) Global Native
Function Native_Survival_SetLastEatAttempt(Actor akActor, Int bracket) Global Native

; === Arrest: the prisoner's original outfit ('ARST' v3) ===

Function Native_ArrestSession_SetOriginalOutfit(Actor prisoner, Form outfit) Global Native
Form Function Native_ArrestSession_GetOriginalOutfit(Actor prisoner) Global Native

; The prisoner's jail marker is Native_Jailed_GetMarker (JailedNPCStore).

; === Ledger (LedgerStore): the World page's gold transaction log ===
; source: a stable category key the frontend groups by (e.g. "give_gold",
; "debt_payment", "bounty_paid", "vendor_spend"). isOut: False = gold flowed TO
; the player. counterparty may be None; hold matters only for bounty rows; debtId
; optionally links a DebtStore entry for "debt_payment" / "debt_added".

Function Native_Ledger_RecordEvent(Int amount, Bool isOut, String source, Actor counterparty, String hold, String reason, Int debtId) Global Native

Int Function Native_Ledger_RawCount() Global Native
{Raw entries held (the last ~30 game days).}

Int Function Native_Ledger_DailyCount() Global Native
{Daily aggregate buckets (capped at ~10 game years).}

Function Native_Ledger_ClearAll() Global Native
{Wipe the whole ledger (raw entries, daily buckets, names, lifetime totals). A reset hook; nothing calls it yet.}

; === FollowerSystemHydrator ===
; Native twin of FollowerManager.RunDeferredMaintenance's heavy per-follower
; passes (essential flag, combat style + HealerPoll, companionOpinions), run at
; session start before Papyrus load recovery. New recruits outside the load path
; still take the Papyrus passes.

Bool Function Native_HydrateFollowerSystem_DidRun() Global Native
{True when the last Hydrate() run processed at least one follower (reset on
 revert; false after an empty new game, so the Papyrus fallback still covers
 later recruits). While true, RunDeferredMaintenance skips ReapplyCombatStyles
 and Native_HydrateFollowerSystem_RebuildOpinions (Ext2).}

Int Function Native_HydrateFollowerSystem_Run() Global Native
{Re-run Hydrate() and return how many followers it processed. Idempotent; called
 after the load-time detection passes so followers found there get the same
 treatment. Sets DidRun to (processed > 0). Load path only (it re-applies essential
 and combat-style values); mid-session use Native_HydrateFollowerSystem_RebuildOpinions (Ext2).}

Actor[] Function Native_ScanPlayerCellForLiveActors() Global Native
{Alive, non-player, non-commanded actors in the player's parent cell.}

; === Survival switch and the Fertility cell scan ===

Function Native_Survival_SetEnabled(Bool abEnabled) Global Native
{Survival master switch. While off, the sever_hunger / sever_fatigue / sever_cold
 decorators report 0 so the survival prompt stays silent; stored needs are kept.
 SeverActions_Survival pushes it on load and on start / stop tracking.}

Actor[] Function Native_ScanPlayerCellFemales3DLoaded() Global Native
{Non-player, 3D-loaded female actors in the player's parent cell (no dead or
 commanded filter). The Fertility bridge reads Fertility Mode's data per actor itself.}

; === CommissionStore (cosave 'CMSN'): deferred crafting orders ===
; CommissionItem takes a 50% deposit and records the smith's ETA;
; Native_Commission_Tick flips matured orders to Ready and queues a
; commission_ready event; CollectCommission (gated by has_ready_commission) takes
; the balance and hands over the item. No DebtStore: an unpaid balance just leaves
; the order Ready. Ids are monotonic (>= 1), never recycled; 0 = not found. Times
; are game days.

Int Function Native_Commission_Add(Actor crafter, Actor customer, Form item, Int count, String itemName, String crafterName, String customerName, Int priceTotal, Int depositPaid, Float etaDays) Global Native
{Record a commission. Returns its id, or 0 on bad args (None crafter, customer or
 item; count <= 0) or at the cap of 10. readyAtDays = now + etaDays; the balance
 is priceTotal - depositPaid, floored at 0. Names are stored as strings so the
 decorator never looks a form up.}

Bool Function Native_Commission_Remove(Int id) Global Native
{Remove the commission. True if it existed.}

Bool Function Native_Commission_Exists(Int id) Global Native
{True while the commission is in the store.}

Int Function Native_Commission_GetCount() Global Native
{Number of active commissions across all crafters.}

Int[] Function Native_Commission_GetAllIDs() Global Native
{All live commission ids, unordered.}

Actor Function Native_Commission_GetCrafter(Int id) Global Native
Actor Function Native_Commission_GetCustomer(Int id) Global Native
Form  Function Native_Commission_GetItem(Int id) Global Native
Int   Function Native_Commission_GetItemCount(Int id) Global Native
String Function Native_Commission_GetItemName(Int id) Global Native
Int   Function Native_Commission_GetPriceTotal(Int id) Global Native
Int   Function Native_Commission_GetDepositPaid(Int id) Global Native
Int   Function Native_Commission_GetBalanceDue(Int id) Global Native
Float Function Native_Commission_GetReadyAtDays(Int id) Global Native
Int   Function Native_Commission_GetStatus(Int id) Global Native
{0 = Ordered (smith still working), 1 = Ready (waiting for collection), -1 = no such id.}

Int Function Native_Commission_FindReadyForCrafter(Actor crafter) Global Native
{A Ready commission id for this crafter, or 0. The customer is always the player,
 so this is the player's finished order here.}

Bool Function Native_Commission_HasReadyForCrafter(Actor crafter) Global Native
{True if this crafter has a Ready commission (the has_ready_commission decorator's
 test, for Papyrus).}

Int Function Native_Commission_CountForCrafter(Actor crafter) Global Native
{Active commissions (any status) for this crafter; drives the smith's backlog line.}

Float Function Native_Commission_ParseEtaDays(String text) Global Native
{Parse a smith's spoken ETA ("a couple days", "a week", "tomorrow", "a few hours")
 into game days, clamped 1 hour to 60 days; 2.0 when nothing parses.}

; --- Commission tick + event drain ---
; Native_Commission_Tick flips matured orders to Ready and queues a
; commission_ready event for each (kind 1, ShortLived). The caller drains and
; clears the queue like the debt one: see SeverActions_Crafting.TickCommissions.
; Kinds: 0 RegisterEvent, 1 RegisterShortLivedEvent, 2 RegisterPersistentEvent.

Int Function Native_Commission_Tick() Global Native
{Run the commission tick at the current game time. Returns how many queued events
 the caller must drain.}

Int Function Native_Commission_PendingEventCount() Global Native
Int Function Native_Commission_PendingEvent_Kind(Int index) Global Native
String Function Native_Commission_PendingEvent_Name(Int index) Global Native
String Function Native_Commission_PendingEvent_Content(Int index) Global Native
String Function Native_Commission_PendingEvent_Key(Int index) Global Native
Int Function Native_Commission_PendingEvent_TTL(Int index) Global Native
Actor Function Native_Commission_PendingEvent_Crafter(Int index) Global Native
Actor Function Native_Commission_PendingEvent_Customer(Int index) Global Native
Function Native_Commission_ClearPendingEvents() Global Native

; Copy a commission into the completed-history log (World -> Ledger), stamped with
; the collection time. Call just before removing it on collection.
Function Native_Commission_RecordCompleted(Int id) Global Native

; --- Commission confirm overlay (deposit at order, balance at pickup) ---
; Non-pausing, on the SeverActionsPrompt view like Magelight_OpenPaymentPrompt.
; asMode is "deposit" or "balance". The choice arrives as the
; SeverActions_CommissionPromptChoice ModEvent (strArg "accept" / "deny", numArg =
; amount, sender = smith); SeverActions_Crafting holds the rest of the order.

Bool Function Magelight_OpenCommissionPrompt(Actor akSmith, Int aiAmountNow, String asSmithName, String asItemName, Int aiTotal, Int aiDeposit, Int aiBalance, String asMode, Int aiTimeoutMs) Global Native
{Open the overlay. True if shown (then wait for SeverActions_CommissionPromptChoice). False if the UI is unavailable, another prompt is open or another view has focus: fall back to SkyMessage.}

Function Magelight_CloseCommissionPrompt() Global Native
{Close the overlay without firing a choice (a decline).}

Bool Function Magelight_IsCommissionPromptOpen() Global Native
{True while the overlay is shown.}

Bool Function Magelight_IsCommissionPromptAvailable() Global Native
{True once the bridge is up and the view has finished its DOM-ready handshake. Check before Magelight_OpenCommissionPrompt.}

; Pay a NAMED offender's bounty through the guard / authority the player is
; talking to (tracked follower and NPC bounties, and Enterprises fence bounties,
; matched by name in the guard's hold). Returns gold paid (> 0), 0 = nobody by
; that name is wanted here, -1 = found but the player cannot afford it.
Int Function Native_PayHoldBountyByName(Actor akGuard, String asOffenderName) Global Native

; Read-only: what the named offender owes in the guard's hold (0 = nothing).
; Seeds the confirm popup.
Int Function Native_ResolveHoldBountyByName(Actor akGuard, String asOffenderName) Global Native

; Non-pausing bounty-payment confirm. True if it opened (the choice arrives as the
; SeverActions_BountyPayChoice ModEvent); False = the caller pays directly.
Bool Function Magelight_OpenBountyPrompt(Actor akGuard, Int aiAmount, String asOffenderName, Int aiTimeoutMs) Global Native
Function Magelight_CloseBountyPrompt() Global Native
Bool Function Magelight_IsBountyPromptOpen() Global Native
Bool Function Magelight_IsBountyPromptAvailable() Global Native


; === Quest awareness ===
Function Native_QuestAwareness_SetEnabled(Bool abEnabled) Global Native
{AutoQuestAwareness master toggle. Off: stage events are still tracked, but no sever_quest_awareness summary LLM call is made. The prompt-presence check is native.}

; === Letters (courier deliveries) ===
Form Function Letter_DeliverToCourier(Actor akSender, Actor akCourier, String asSubject, String asBody, String asReason, String asSenderName = "") Global Native
{Archive and title a letter and put it in the COURIER's inventory for the give animation. Returns the book form (None on failure).
 asSenderName is the attribution fallback: a letter's sender is away by definition, so their ref may be unloaded at delivery.}

Int Function Letter_Count() Global Native
{Number of archived letters.}

Int Function Letter_LatestId() Global Native
{Id of the last delivered letter (0 if none).}

Int Function Letter_DebugDeliverTest() Global Native
{DEBUG: deliver a hardcoded test letter on a vanilla note, to test the reading loop from the console.}

; === Survival: party-larder auto-eat ===
; Move one of the cheapest suitable foods (cooked first, then raw) from whichever
; party member carries it (the player included) into the follower's pack.
; Returns the food, or None when the party carries none.
Form Function Native_Survival_PullFoodFromParty(Actor akFollower) Global Native

; === Courier (letter-delivery NPC) ===
Actor Function Courier_Spawn(Actor akTarget, Float afDistance) Global Native
{Bring the courier (one WICourierNPC, placed on first use and reused) on navmesh beside akTarget (afDistance <= 1) or afDistance units behind it, to walk up. Returns the courier (None on failure). Routing is the caller's job; putting him away is automatic, with a backstop TTL.}

Function Courier_Release(Actor akCourier) Global Native
{Let a delivered courier sandbox in place; he is put away once the player leaves that cell (with a long backstop TTL).}
