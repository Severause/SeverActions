Scriptname SeverActionsNativeExt Hidden
{Extension class for SeverActions native Papyrus exports.

 Why a second class: the Skyrim Papyrus VM has a hard ~511-function limit per
 script class (a 9-bit static-count bitfield). Once exceeded, the engine marks
 the entire class as invalid and all its native functions become unreachable
 at runtime — even ones that DO have valid registrations on the C++ side.

 v2.9.9 had ~465 natives in SeverActionsNative — well under the limit.
 Subsequent feature work (arrest pipeline, travel orchestrator, healer poll,
 cell catchup, etc.) pushed the count to 523, breaking the entire class
 silently. Symptoms: every SeverActionsNative.X call returns None and logs
 "Static function X not found on object SeverActionsNative" + "Class
 SeverActionsNative overflowed the static count field while linking."

 This class holds the most recent native-function additions (HealerPoll +
 CellCatchup, 20 functions total) so the main SeverActionsNative class stays
 comfortably under the engine limit. Future native subsystems should extend
 this class (or new sibling classes) rather than the main one.}

; ============================================================================
; HEALER POLL — Native combat-tick subsystem for the "healer" combat style
; ============================================================================
; HealerPoll fires every ~1s during combat for any actor registered via
; Native_RegisterHealer. It picks a target via priority chain (player > self >
; ally), gates by per-target / per-healer cooldowns + magicka availability +
; healChance roll, then dispatches SeverActionsNative_HealerCast for Papyrus
; to perform the actual Spell.Cast + bonus heal + voice line.
;
; Healer state is NOT independently persisted — derives from FollowerDataStore's
; CombatStyle field (already cosaved). On load, FollowerManager.Maintenance()
; re-registers anyone whose CombatStyle == "healer".

Function Native_RegisterHealer(Actor akActor) Global Native
{Add an actor to the healer poll. Idempotent.}

Function Native_UnregisterHealer(Actor akActor) Global Native
{Remove an actor from the healer poll.}

Bool Function Native_IsHealer(Actor akActor) Global Native
{Returns true if the actor is currently in the healer poll roster.}

Int Function Native_GetHealerCount() Global Native
{Returns the number of registered healers.}

Function Native_ClearAllHealers() Global Native
{Clear the entire healer roster — used on game load before re-registration.}

Function Native_SetHealerThresholds(Float playerThresh, Float selfThresh, Float allyThresh) Global Native
{Set health-percent triggers for each tier. Range 0.0-0.95. Set 0 to disable a tier.}

Function Native_SetHealerMult(Float mult) Global Native
{Multiplier on the bonus-heal magnitude. Range 0.05-2.0. Default 1.0.}

Function Native_SetHealerChance(Int chance) Global Native
{Per-tick attempt chance, 0-100. Default 75.}

Function Native_SetHealerCooldowns(Int targetMs, Int healerMs, Int voiceMs) Global Native
{Cooldowns in ms: per-target heal, per-healer cast, per-healer voice line.}

Function Native_SetBleedoutCheatHeal(Bool enabled) Global Native
{Toggle the OnEnterBleedout fail-safe heal on player + healer-mode followers.}

Bool Function Native_IsBleedoutCheatHealEnabled() Global Native
{Read the bleedout fail-safe toggle.}

Float Function Native_ComputeBonusHeal(Actor akCaster) Global Native
{Compute the bonus heal amount for the given caster:
 (Restoration * 0.2 + Level + 74) * healMult.
 Use this AFTER Spell.Cast() to apply RestoreActorValue("Health", bonus) on top.}

Function Native_NotifyHealApplied(Actor akHealer, Actor akTarget) Global Native
{Update the per-target cooldown after a heal lands. Called from the Papyrus
 dispatch handler so subsequent ticks don't re-heal the same target immediately.}

Bool Function Native_ShouldEmitVoiceLine(Actor akHealer) Global Native
{Returns true and resets the per-healer voice cooldown when a voice line
 is allowed to fire. Use to gate Say() calls in the heal handler.}

; ============================================================================
; CELL CATCHUP — reliable follower-through-load-doors
; ============================================================================
; Listens for TESCellFullyLoadedEvent on the player's cell. After a grace
; period (default 1.5s — gives vanilla teleport-on-cell-load a chance first),
; iterates the FollowerDataStore roster and force-MoveTo's any follower whose
; parent cell != player's. Fixes the classic "follower stuck in elevator" bug.
; Skips: sandboxing, traveling, in-dialogue, dead, mounted, bleedout.

Function Native_SetCellCatchupEnabled(Bool enabled) Global Native
{Master toggle for the cell-load follower catch-up system. Default true.}

Bool Function Native_IsCellCatchupEnabled() Global Native
{Read the cell-catchup master toggle.}

Function Native_SetCellCatchupGracePeriodMs(Int ms) Global Native
{Wait this long after a cell load before catching up followers. Lets vanilla
 teleport-on-cell-load try first. Default 1500ms.}

Function Native_SetCellCatchupMaxFollowers(Int n) Global Native
{Cap on followers caught up per cell-load. Prevents slideshow with very
 large rosters. Default 8.}

Function Native_SetCellCatchupOffsetRadius(Float radius) Global Native
{XY offset radius (units) for drop position randomization. Prevents pile-up
 when multiple followers catch up at the same door. Default 100.0.}

Function Native_CellCatchup_TriggerNow() Global Native
{Manually trigger the catch-up sweep right now, bypassing the grace period.
 Use for a Summon hotkey or UI button.}

; =============================================================================
; HOLD RESOLVER (PR-A)
; Crime faction → hold metadata (jail marker, hold name, jail name, bounty key).
; Replaces five parallel 9-way if/elseif ladders in SeverActions_Arrest with a
; single registered lookup table. Hold_Register is called once per hold from
; SeverActions_Arrest.Maintenance at script init.
;
; Entries are keyed by CRIME faction. Vanilla guards are members of their hold's
; crime faction, so actor-side lookups (Hold_GetJailMarker(guard) etc.) work
; exactly as the prior Papyrus ladders did. Crime-faction-keyed lookups
; (Hold_GetBountyKeyForCrime) work directly without an actor.
;
; Registered here on SeverActionsNativeExt (not the main SeverActionsNative
; class) because that class is at the 511-function VM limit.
; =============================================================================

Function Hold_Register(Faction akCrimeFaction, ObjectReference akJailMarker, String asHoldName, String asBountyKey, String asJailName) Global Native
{Register or update one hold tuple. Idempotent — re-registering the same crime
faction overwrites prior data, so calling Maintenance multiple times does not
grow the table. Third-party mods can also call this to add their own holds.
akJailMarker may be None — the resolver falls back to crimeData.factionJailMarker
on the crime faction (engine-set for all vanilla holds).}

Bool Function Hold_Resolve(Actor akGuard) Global Native
{Returns true if akGuard is in any registered crime faction.}

Faction Function Hold_GetCrimeFaction(Actor akGuard) Global Native
{Return the crime faction for akGuard's hold, or None if no match.}

ObjectReference Function Hold_GetJailMarker(Actor akGuard) Global Native
{Return the jail marker for akGuard's hold, or None if no match.
Fallback chain: registered marker → crimeData.factionJailMarker.}

String Function Hold_GetHoldName(Actor akGuard) Global Native
{Return the display name of akGuard's hold, or "" if no match.}

String Function Hold_GetJailName(Actor akGuard) Global Native
{Return the display name of the jail in akGuard's hold, or "" if no match.}

String Function Hold_GetBountyKey(Actor akGuard) Global Native
{Return the storage key for tracked bounty in akGuard's hold, or "" if no match.}

String Function Hold_GetBountyKeyForCrime(Faction akCrimeFaction) Global Native
{Return the storage key for tracked bounty in a crime faction's hold, or "" if no match.
Used by SeverActions_ArrestBounty where the caller already has the faction.}

Function Hold_Clear() Global Native
{Clear every registered hold tuple. Mainly for testing / hot-reload.}

Int Function Hold_Count() Global Native
{Return the number of registered hold tuples.}

; =============================================================================
; JAILED NPC STORE (PR-B)
; Cosave-backed roster of NPCs currently in jail. Replaces the per-quest
; Actor[] JailedNPCs script var + the StorageUtil SeverActions_JailMarker
; per-actor form value. O(1) IsJailed / GetMarker. Auto-prunes via
; TESDeathEvent so dead prisoners drop out without Papyrus polling.
;
; Registered on SeverActionsNativeExt because the main SeverActionsNative
; class is at the 511-function VM limit.
; =============================================================================

Function Native_Jailed_Add(Actor akPrisoner, ObjectReference akJailMarker, Faction akCrimeFaction, Int aiFlags) Global Native
{Add or update a jailed NPC. Idempotent — re-adding overwrites the prior entry.
aiFlags is a bitfield: bit 0 = was Disabled (DisablePrisonerOnArrival).}

Bool Function Native_Jailed_Remove(Actor akPrisoner) Global Native
{Remove a jailed NPC. Returns true if was tracked.}

Function Native_Jailed_RemoveAll() Global Native
{Clear every entry. Used by FreeAllPrisoners after the Papyrus side iterates.}

Bool Function Native_Jailed_IsJailed(Actor akPrisoner) Global Native
{O(1) check — true if akPrisoner is in the roster.}

ObjectReference Function Native_Jailed_GetMarker(Actor akPrisoner) Global Native
{Return the prisoner's jail marker, or None if not tracked.}

Faction Function Native_Jailed_GetCrimeFaction(Actor akPrisoner) Global Native
{Return the crime faction the prisoner was jailed under, or None if not tracked.}

Float Function Native_Jailed_GetAgeHours(Actor akPrisoner) Global Native
{Return in-game hours elapsed since the prisoner was jailed, or 0 if not tracked.}

Int Function Native_Jailed_GetCount() Global Native
{Return the size of the roster.}

Actor[] Function Native_Jailed_GetAll() Global Native
{Return the roster as a Papyrus array. Capped at 128 entries (Papyrus array limit).}

; =============================================================================
; CRAFTING ORCHESTRATOR (PR A — SKELETON ONLY)
; Native port of SeverActions_Crafting.psc::_Execute. Mirrors the Travel
; orchestrator's shape (handle-based session, InputEvent heartbeat tick,
; completion ModEvent). PR A registers the surface and the package-override
; spike below; the full state machine lands in PR B+C.
;
; Concurrency model (PR B+C): queue. Only one craft session is active in any
; non-terminal state at a time because the crafting aliases on the SeverActions
; quest (ForgeAlias, CrafterAlias, etc.) are quest-scoped singletons.
; Subsequent Craft_Begin calls enqueue and run serially. Proper fix
; (per-instance aliases via CK record changes) is deferred.
;
; Registered on SeverActionsNativeExt (not the main class) because that class
; is at the 511-function VM limit.
; =============================================================================

Int Function Craft_Begin(Actor akActor, Form akItemForm, ObjectReference akWorkstation, Actor akRecipient, Int itemCount, String workstationType, String actionVerb) Global Native
{Begin a craft session. Returns a positive handle on acceptance, 0 on
 rejection (null actor / null itemForm / null workstation). If another
 session is currently active, the new entry enters Queued and starts
 automatically when the active session terminates (single-active-session
 rule — see header for the alias-singleton reason).}

Function Craft_Cancel(Int handle) Global Native
{Cancel a craft session. Fires the TermCancelled phase event for cleanup.
 No-op for unknown handles.}

Bool Function Craft_IsActive(Int handle) Global Native
{Returns true while the handle is in a non-terminal state.}

Int Function Craft_GetActiveCount() Global Native
{Returns the number of in-flight (non-terminal) craft sessions, including
 queued ones.}

Int Function Craft_GetState(Int handle) Global Native
{Returns the current CraftState as an int. See Craft_GetStateName.}

String Function Craft_GetStateName(Int stateCode) Global Native
{Returns a stable string name for a CraftState code.
 0=Idle, 1=Queued, 2=WalkingToWorkstation, 3=AnimatingAtWorkstation,
 4=ExitingWorkstation, 5=ReturningToRecipient, 6=HandingOff,
 10=Completed, 11=AbortedNoArrival, 12=AbortedNoWorkstation, 13=Cancelled.}

Actor Function Craft_GetActor(Int handle) Global Native
{Returns the crafter for the given handle, or None.}

ObjectReference Function Craft_GetWorkstation(Int handle) Global Native
{Returns the workstation ref for the given handle, or None.}

Actor Function Craft_GetRecipient(Int handle) Global Native
{Returns the recipient for the given handle, or the player if recipient was
 passed as None at Begin, or None if the handle is unknown.}

String Function Craft_GetWorkstationType(Int handle) Global Native
{Returns the workstation type label ("forge"/"cooking pot"/"oven"/"alchemy lab")
 for the given handle, or empty string.}

; ---- SPIKE — preserved from PR A for empirical testing of DispatchStaticCall.
; Will be removed once PR B+C is proven stable and we know whether the
; ModEvent shim or the direct-dispatch path is the long-term answer.

Bool Function Craft_SpikePackageOverride(Actor akActor, Package akPackage, Int priority, Int flags) Global Native
{Spike: test whether DispatchStaticCall can invoke ActorUtil.AddPackageOverride
 directly from C++. Returns true if the call was dispatched (queued onto the
 VM). Caller verifies success by observing whether the NPC actually walks
 toward the package's target.

 Test recipe (console):
   cgf "SeverActionsNativeExt.Craft_SpikePackageOverride" <npc_formid> <package_formid> 100 1}

; =============================================================================
; OUTFIT MIGRATION (Phase 1-5) — moved here from SeverActionsNative.psc.
; The main script hit the ~511-function VM cap during Phase 5; the 12 outfit-
; migration scalars + DressStash session helpers landed here instead. All
; outfit Papyrus code (SeverActions_Outfit / OutfitSlot / OutfitAlias / MCM)
; calls these via the SeverActionsNativeExt qualifier.
; =============================================================================

Bool Function Native_Outfit_IsLockActive(Actor akActor) Global Native
{Phase 1: O(1) bool — true if actor has an active outfit lock in native.}

Bool Function Native_Outfit_IsActivelyManaged(Actor akActor) Global Native
{True iff SeverActions is actively managing this actor's outfit RIGHT NOW.
 Three-flag check rolled into one native call for soft-dep compat patches
 (Daegon Kaekiri, etc.) — partner mods consult this to decide whether to
 suppress their own outfit force-reequip logic. Returns true when:
  1. the actor is a recruited SeverActions follower (isFollower=true),
  2. the actor is NOT outfit-excluded by the player, AND
  3. there's an active outfit lock OR an active slot preset.
 When false, the partner mod's enforcement should run normally — SA either
 isn't tracking this actor at all, isn't managing their outfit, or has
 nothing currently locked. Mirrors the gate the SA outfit alias itself uses
 in OnObjectUnequipped (Native_GetOutfitExcluded + lock/preset check).}

Bool Function Native_Outfit_HasSituationPreset(Actor akActor, String situation) Global Native
{Phase 1: true if actor has a non-empty preset mapped to the given situation.}

Int Function Native_Outfit_GetSchemaVersion() Global Native
{Phase 2: legacy-importer schema version stored in cosave. 0 = needs import.}

Function Native_Outfit_SetSchemaVersion(Int v) Global Native
{Phase 2: bump schema version after importer completes.}

Actor[] Function Native_Outfit_GetActorsWithLocks() Global Native
{Phase 4: every actor with lockActive=true in native (replaces legacy
 SeverOutfit_TrackedActors StorageUtil FormList).}

Actor[] Function Native_Outfit_GetAllTrackedActors() Global Native
{Phase 5: every actor in the native OutfitDataStore regardless of lockActive
 state. Used by Maintenance() to sweep stale StorageUtil suspend keys from
 pre-migration saves on actors whose locks have since been cleared (e.g.
 dismissed followers). Hot paths should NOT use this — it returns the full
 m_data map and includes non-resolvable formIDs.}

Bool Function Native_Outfit_IsFollowerLock(Actor akActor) Global Native
{Phase 5: true (default) if the actor's lock is a follower-lock; false if
 it's a non-follower NPC the user explicitly locked.}

Function Native_Outfit_SetIsFollowerLock(Actor akActor, Bool isFollower) Global Native
{Phase 5: set the follower-lock kind. False = non-follower explicit lock.}

Function Native_Outfit_DressStashAdd(Actor akActor, Form item) Global Native
{Phase 5: stash one item in the Dress/Undress session map. Cosave-backed
 from v6 onward — Undress→reload→Dress preserves the stash.}

Form[] Function Native_Outfit_DressStashGet(Actor akActor) Global Native
{Phase 5: retrieve stashed Dress/Undress items.}

Function Native_Outfit_DressStashClear(Actor akActor) Global Native
{Phase 5: clear stashed items after Dress consumes them.}

Function Native_Outfit_DressStashSetDefaultOutfit(Actor akActor, Outfit outfit) Global Native
{Phase 5: snapshot the actor's DefaultOutfit so Dress fallback can restore.}

Outfit Function Native_Outfit_DressStashGetDefaultOutfit(Actor akActor) Global Native
{Phase 5: retrieve the snapshotted DefaultOutfit, or None if unset.}

; =============================================================================
; OUTFIT-LOCK SUSPEND / RESUME (Phase 5: native-backed)
; Replaces the StorageUtil-mirrored Suspend/Resume in SeverActions_Outfit.psc.
; Watchdog duration (5 min auto-clear) lives in OutfitDataStore via SuspendUntil
; — no more stale StorageUtil keys persisting in cosaves across crashes.
; =============================================================================

Function Native_Outfit_SuspendLock(Actor akActor) Global Native
{Suspend the outfit-lock alias's re-equip reactions for this actor. Watchdog
 is 300 seconds — if Native_Outfit_ResumeLock isn't called by then, the
 suspend self-clears via the SuspendUntil deadline (handles dropped ModEvents
 from crashes / alt-F4 mid-session).}

Function Native_Outfit_ResumeLock(Actor akActor) Global Native
{Clear both the hard-suspend flag and any pending deadline for this actor.
 Pair with Native_Outfit_SuspendLock around any outfit-changing operation.}

; =============================================================================
; FOLLOWER SPLIT-BRAIN REFACTOR (Phase 4A/4B) — moved here from
; SeverActionsNative.psc for the same reason as the Phase 5 outfit migration:
; the main script is at the ~511-function VM cap. All follower Papyrus code
; (FollowerManager, Follow, PrismaUI, Hotkeys, Outfit, OutfitSlot, WheelMenu)
; calls these via the SeverActionsNativeExt qualifier.
; =============================================================================

; --- Per-field relationship setters ---

Function Native_SetRapport(Actor akActor, Float value) Global Native
{Set rapport (clamped to -100..100). Single-field write; safer than SetRelationship when you only want one value.}

Function Native_SetTrust(Actor akActor, Float value) Global Native
{Set trust (clamped to 0..100).}

Function Native_SetLoyalty(Actor akActor, Float value) Global Native
{Set loyalty (clamped to 0..100).}

Function Native_SetMood(Actor akActor, Float value) Global Native
{Set mood (clamped to -100..100).}

; --- Atomic relationship deltas (lock-safe; return new clamped value) ---

Float Function Native_ModifyRapport(Actor akActor, Float delta) Global Native
{Atomic +=delta under FollowerData's mutex; returns the new clamped value.}

Float Function Native_ModifyTrust(Actor akActor, Float delta) Global Native
{Atomic +=delta under FollowerData's mutex; returns the new clamped value.}

Float Function Native_ModifyLoyalty(Actor akActor, Float delta) Global Native
{Atomic +=delta under FollowerData's mutex; returns the new clamped value.}

Float Function Native_ModifyMood(Actor akActor, Float delta) Global Native
{Atomic +=delta under FollowerData's mutex; returns the new clamped value.}

; --- Read symmetry for SetSandboxing / SetIsFollower ---

Bool Function Native_GetSandboxing(Actor akActor) Global Native
{Check if actor is in our sandbox state. Replaces StorageUtil("SeverActions_IsSandboxing").}

Bool Function Native_GetIsFollower(Actor akActor) Global Native
{Per-actor roster check. Replaces StorageUtil(KEY_IS_FOLLOWER).}

Bool Function Native_HasFollowerData(Actor akActor) Global Native
{True iff actor has ANY FollowerData entry, even with isFollower=false. Survives soft-dismiss; only cleared by explicit Purge. Use this as the "returning vs first recruit" signal.}

; --- Phase 4C: native relationship ticker ---

Function Native_SetInteractionTime(Actor akActor, Float gameTimeSec) Global Native
{Record the player's last-interaction time on this follower. Drives rapport-neglect decay in the native ticker. Replaces StorageUtil(KEY_LAST_INTERACTION).}

Float Function Native_GetInteractionTime(Actor akActor) Global Native
{Read the last-interaction time. 0.0 = never interacted (no neglect penalty).}

Function Native_SetPlayerBlurb(Actor akActor, String blurb) Global Native
{Phase 5b — store the LLM-generated narrative blurb for how this follower currently feels about the player. Surfaced verbatim in the PrismaUI Companions sheet under the subtab strip. Empty string clears it.}

String Function Native_GetPlayerBlurb(Actor akActor) Global Native
{Phase 5b — read the player-relationship blurb. Returns "" if never assessed.}

Actor[] Function Native_TickAllRelationships(Float moodChange, Float rapportLossOnNeglect, Float currentTimeSec, Float neglectSecondsThreshold, Float leavingThreshold, Bool allowLeaving) Global Native
{Run the relationship math (mood drift toward 0.5*rapport, rapport neglect after the grace period) across every tracked follower under one lock acquisition. Unit-agnostic — pass pre-computed deltas:
  moodChange              = MOOD_DECAY_RATE * hoursPassed
  rapportLossOnNeglect    = RapportDecayRate * (hoursPassed / NEGLECT_HOURS)
  currentTimeSec          = GetGameTimeInSeconds()
  neglectSecondsThreshold = NEGLECT_HOURS * SECONDS_PER_GAME_HOUR
Returns actors at or below leavingThreshold so Papyrus can fire the SkyrimNet persistent "considering leaving" event (filtering already-warned ones itself).}

; ─── Ambient Banter — UTF-8-safe native dispatch (issue #9) ────────────────
; The original 2.9.9 path concatenated NPC names into the LLM context JSON via
; Papyrus String +=, which mangled Cyrillic / other non-ASCII to mojibake. The
; native path below scans + builds the request + parses the response + assembles
; the gamemaster_dialogue eventJson entirely in C++ via nlohmann::json, so UTF-8
; bytes survive end-to-end. Papyrus side only kicks off and consumes.

Int Function Native_AmbientBanter_FireToLLM(Float hearingRadius, Float pairRadius, Int maxPairs) Global Native
{Scan for banter-eligible pairs, build the LLM context JSON in C++, dispatch via SkyrimNet's native PublicSendCustomPromptToLLM. Returns: >0 pair count dispatched (request in flight), 0 no candidates / hostile cell, -1 bridge unavailable. Fires SeverActions_AmbientBanterReady ModEvent when the LLM responds (numArg: 1.0 = event prepared, 0.0 = silence/failure).}

String Function Native_AmbientBanter_GetReadyEventJson() Global Native
{After SeverActions_AmbientBanterReady fires with numArg=1.0, returns the pre-built gamemaster_dialogue event JSON to pass to SkyrimNetApi.RegisterEvent. Empty string = nothing ready (silence cycle, parse failure, actor not found).}

Actor Function Native_AmbientBanter_GetReadySpeaker() Global Native
{Speaker actor for the prepared event. None if not ready.}

Actor Function Native_AmbientBanter_GetReadyTarget() Global Native
{Target actor for the prepared event. None if not ready.}

Function Native_AmbientBanter_ClearReady() Global Native
{Clear the ready slot after Papyrus consumes it. Idempotent — guards against stale data if anything races.}

; ─── Travel Orchestrator (Tier 3 — unified high-level travel API) ──────────
; Migrated from SeverActionsNative to keep the main class's static-count
; under the 511-bitfield limit. Same reason as Craft_* / Heal_* / Cell_*.
;
; Lifecycle: Travel_Begin returns a handle (>0) or 0 on rejection. While
; active, the orchestrator ticks each session ~1/sec watching for arrival,
; stuck escalation, abort signals, timeout. On terminal state fires ModEvent
; "SeverActions_TravelComplete" with strArg = "<callbackTag>|<status>" where
; <status> is one of: arrived|aborted|gaveup|timedout|cancelled.
;
; Options bitfield: 0=none | 1=require LOS | 2=return home on fail |
;                   4=abort on degraded actor state | 8=skip preflight |
;                   16=no recovery

Int Function Travel_Begin(Actor akActor, ObjectReference akDestination, Keyword akKeyword, Float arrivalThreshold, String callbackTag, Int options, Int maxDurationSeconds, Int speed) Global Native
{Begin a travel session. Returns a handle (>0) on success, 0 on rejection.
 speed: 0=walk, 1=jog, 2=run, 3=default. Drives the time-skip catch-up estimator.}

Int Function Travel_BeginXY(Actor akActor, Float destX, Float destY, Float destZ, Keyword akKeyword, Float arrivalThreshold, String callbackTag, Int options, Int maxDurationSeconds) Global Native
{Begin travel to raw coordinates (no destination ref). Otherwise same as Travel_Begin.}

Function Travel_Cancel(Int handle) Global Native
{Cancel a travel session. Fires the completion event with status 'cancelled'.}

Int Function Travel_CancelByActor(Actor akActor) Global Native
{Cancel all active travels for this actor. Returns the count cancelled.}

Bool Function Travel_IsActive(Int handle) Global Native

Int Function Travel_GetState(Int handle) Global Native
{Returns the numeric TravelState. Terminal: 10=arrived, 11=aborted, 12=gaveup, 13=timedout, 14=cancelled.}

String Function Travel_GetStateName(Int stateCode) Global Native
{idle|preflight|departing|traveling|recovering|arrived|aborted|gaveup|timedout|cancelled.}

Float Function Travel_GetDistance(Int handle) Global Native
{Live 2D distance from actor to destination, or -1 if unavailable.}

Int Function Travel_GetActiveCount() Global Native

Bool Function Travel_SetSpeed(Int handle, Int speed) Global Native
{Update the speed preset on an in-flight travel. Caller still does the package swap.}

Int Function Travel_GetSpeed(Int handle) Global Native

Function Travel_RegisterSpeedPackages(Package akWalk, Package akJog, Package akRun, Package akDefault) Global Native
{Register the four speed packages once at init. Any slot may be None.}

Package Function Travel_GetSpeedPackage(Int speed) Global Native
{Resolve a speed preset (0-3) to the registered Package; falls back to default.}

Int Function Travel_ParseSpeedFromText(String text) Global Native
{Parse natural-language ("hurry up", "slow down", "run") to a speed preset.}

String Function Travel_GetSpeedName(Int speed) Global Native
{Human name: 0->"walking", 1->"jogging", 2->"running", else "moving".}

; ─── PrismaUI camp pushers (SeversHearth integration) ──────────────────────
; Migrated from SeverActionsNative for the same 511-limit reason. The older
; PrismaUI_SetPinnedRestStop / SetCampStatus stay on the main class because
; they're in wide use; these three are fresh adds.

Function PrismaUI_SetCampMeta(Float hoursEstablished, Float distanceUnits) Global Native
{Push tick-frequent camp meta (hours since establishment + player-to-camp
 distance in raw game units) to the Survival page camp-detail section.}

Function PrismaUI_SetCampThreats(String warning) Global Native
{Push a short narrative threats warning to the Survival page camp section.
 Empty string clears the banner.}

Function PrismaUI_SetCampMarked(Bool marked) Global Native
{Push the camp's "marker on world map?" state so the Survival page renders
 the right Mark/Unmark button label.}

; ─── Migrated from SeverActionsNative (511-limit) ─────────────────────────
; ArrivalMonitor (9), StuckDetector (13), AmbientBanter scan+pair queries (8),
; PrismaUIDataBuilder (15). All callers rewritten to use SeverActionsNativeExt.

Function Stuck_StartTracking(Actor akActor) Global Native
{Begin tracking an actor for stuck detection}

Function Stuck_StopTracking(Actor akActor) Global Native
{Stop tracking an actor for stuck detection}

Int Function Stuck_CheckStatus(Actor akActor, Float checkInterval, Float moveThreshold) Global Native
{Check if actor is stuck. Returns escalation level:
0 = not stuck, 1+ = stuck (higher = longer stuck duration).
checkInterval: seconds between checks, moveThreshold: min distance to count as moved.}

Float Function Stuck_GetTeleportDistance(Actor akActor) Global Native
{Get the recommended teleport distance based on escalation level}

Bool Function Stuck_IsTracked(Actor akActor) Global Native
{Check if an actor is currently being tracked for stuck detection}

Function Stuck_ResetEscalation(Actor akActor) Global Native
{Reset the escalation level for an actor (call after successful unstick)}

Function Stuck_ClearAll() Global Native
{Clear all stuck tracking data for all actors}

Int Function Stuck_GetTrackedCount() Global Native
{Get the number of actors currently being tracked for stuck detection}

Int Function Stuck_CheckDeparture(Actor akActor, Float departureThreshold) Global Native
{Check if a tracked actor has moved from their starting position.
 Returns: 0=too_early (grace period), 1=departed successfully, 2=soft recovery needed (30s no movement).
 departureThreshold: minimum distance from start to count as departed (default 100 units).}

Bool Function Stuck_PreflightReachable(Actor akActor, ObjectReference akDestination, Float speed = 2.0, Float slop = 64.0) Global Native
{Returns true if the actor's pathing system thinks akDestination is reachable.
 Use as a guard before kicking off travel. False → skip directly to teleport
 (no point spending 30s on stuck escalation for an unreachable spot).}

Bool Function Stuck_PreflightReachableXYZ(Actor akActor, Float destX, Float destY, Float destZ, Float speed = 2.0, Float slop = 64.0) Global Native
{Same as Stuck_PreflightReachable but for raw coordinates (no ref).}

Bool Function Stuck_ShouldAbort(Actor akActor) Global Native
{Returns true if the actor is in any state where travel should be aborted:
 dead, bleeding out / engine-down (essential bleedout), killmove, unconscious,
 commanded by another script (summon/thrall), on a mount, or arrested.
 Avoids escalating-to-teleport on an actor who's no longer travel-capable.}

Bool Function Stuck_GiveUpToEditorLocation(Actor akActor) Global Native
{Send the actor to their editor-defined location via MoveToEditorLocation.
 Use as a fallback when force-teleport to the destination won't recover the
 actor (e.g. destination has broken navmesh). Returns true on success.}

Function Arrival_Register(Actor akActor, ObjectReference akDestination, Float distanceThreshold, String callbackTag) Global Native
{Register an actor to be monitored for arrival at a destination reference.
 Fires ModEvent "SeverActions_ArrivalDetected" with callbackTag when within distanceThreshold.}

Function Arrival_RegisterXY(Actor akActor, Float destX, Float destY, Float distanceThreshold, String callbackTag) Global Native
{Register an actor to be monitored for arrival at X/Y coordinates.
 Fires ModEvent "SeverActions_ArrivalDetected" with callbackTag when within distanceThreshold.}

Function Arrival_Cancel(Actor akActor) Global Native
{Cancel arrival monitoring for an actor.}

Bool Function Arrival_IsTracked(Actor akActor) Global Native
{Check if an actor is being monitored for arrival.}

Float Function Arrival_GetDistance(Actor akActor) Global Native
{Get the current distance between a tracked actor and their destination. Returns -1 if not tracked.}

Int Function Arrival_GetTrackedCount() Global Native
{Get the number of actors currently being monitored for arrival.}

Function Arrival_RegisterLOS(Actor akActor, ObjectReference akDestination, Float distanceThreshold, String callbackTag) Global Native
{Same as Arrival_Register but only fires when distance AND line-of-sight conditions are met.}

Function Arrival_RegisterLOSXY(Actor akActor, Float destX, Float destY, Float distanceThreshold, String callbackTag) Global Native
{Same as Arrival_RegisterXY but only fires when distance AND line-of-sight conditions are met.}

Function Arrival_ClearAll() Global Native
{Clear all arrival monitoring data.}

Function PrismaUI_BeginPage(String page) Global Native
{Start building JSON for a page. Resets any in-progress build.}

Function PrismaUI_AddString(String key, String value) Global Native
{Add a string key-value to the current object.}

Function PrismaUI_AddBool(String key, Bool value) Global Native
{Add a boolean key-value (C++ writes true/false, not TRUE/FALSE).}

Function PrismaUI_AddInt(String key, Int value) Global Native
{Add an integer key-value to the current object.}

Function PrismaUI_AddFloat(String key, Float value) Global Native
{Add a float key-value to the current object.}

Function PrismaUI_BeginArray(String key) Global Native
{Start a JSON array under the given key.}

Function PrismaUI_EndArray() Global Native
{End the current array.}

Function PrismaUI_BeginObject() Global Native
{Start an anonymous object (typically inside an array).}

Function PrismaUI_BeginNamedObject(String key) Global Native
{Start a named object under the given key.}

Function PrismaUI_EndObject() Global Native
{End the current object (named or anonymous).}

Function PrismaUI_PushString(String value) Global Native
{Push a bare string value into the current array.}

Function PrismaUI_PushInt(Int value) Global Native
{Push a bare integer value into the current array.}

Function PrismaUI_PushFloat(Float value) Global Native
{Push a bare float value into the current array.}

Function PrismaUI_PushBool(Bool value) Global Native
{Push a bare boolean value into the current array.}

Function PrismaUI_SendPage() Global Native
{Serialize the built JSON and send to PrismaUI.}

Int Function Native_AmbientBanter_ScanAndCache(Float hearingRadius, Float pairRadius, Int maxPairs) Global Native
{Scan the player's cell for banter-eligible NPC pairs. Caches results for the
 GetPair* getters. Returns the count of pairs found (0-maxPairs). Returns 0 if
 a hostile actor is loaded near the player. Pass 0 for any param to use defaults
 (hearingRadius=2000, pairRadius=768, maxPairs=6).}

Int Function Native_AmbientBanter_GetPairFormA(Int idx) Global Native
Int Function Native_AmbientBanter_GetPairFormB(Int idx) Global Native
String Function Native_AmbientBanter_GetPairNameA(Int idx) Global Native
String Function Native_AmbientBanter_GetPairNameB(Int idx) Global Native
String Function Native_AmbientBanter_GetPairRaceA(Int idx) Global Native
String Function Native_AmbientBanter_GetPairRaceB(Int idx) Global Native
Float Function Native_AmbientBanter_GetPairDistance(Int idx) Global Native


; ─── SituationMonitor (11) + SpellCastManager (11) migrated for 511-limit ──

; Native_GetActorProcessLevel was declared here but registered by the DLL on
; SeverActionsNative (via GuardFinder::RegisterFunctions alongside the rest
; of the FindNearestGuard family). Declaration moved to SeverActionsNative.psc
; to match — see callers in SeverActions_Arrest.psc.

Function Native_EvaluateActorPackage(Actor akActor) Global Native
{Force re-evaluation of the actor's AI package. Use after removing a package
 override. Moved here from SeverActionsNative.psc — the DLL registers it via
 SpellCastManager::RegisterFunctions(... "SeverActionsNativeExt"), so it has
 to be declared on Ext to link correctly.}

Bool Function Native_InjectSpellIntoPackage(Package akPackage, Spell akSpell) Global Native
{Swap the Spell form inside akPackage's custom data to akSpell.
Lets a single castmagic package scaffold cast any spell the LLM names.}

Bool Function Native_IsSelfDeliveredSpell(Spell akSpell) Global Native
{True if the spell's delivery type is Self (costliest effect targets the caster).}

Bool Function Native_IsHealingSpell(Spell akSpell) Global Native
{True if the spell is non-hostile Restoration. Used to gate the heal-to-full loop.}

Int Function Native_GetEffectiveMagickaCost(Actor akCaster, Spell akSpell, Bool bDualCasting) Global Native
{Magicka cost the caster will actually pay, post skill/perk modifiers. Doubled for dual cast.}

Bool Function Native_IsCasterStillCasting(Actor akCaster) Global Native
{Poll the caster's animation graph for IsCastingLeft/IsCastingRight. Used by the stuck-charge watchdog.}

Function Native_ForceReleaseCast(Actor akCaster) Global Native
{Interrupt + fire animation release events on both hands. Recovers a caster stuck in ChargeLoop.}

Function Native_DiagnoseCastSetup(Actor akActor, Spell akSpell) Global Native
{Logs spell properties (castingType, equipSlot, magickaCost), actor's current package,
combat state, and equipped slots. Diagnostic for figuring out why a cast won't fire.}

Function Native_EquipSpellOnActor(Actor akActor, Spell akSpell, Int aiSlot) Global Native
{Equip a spell in a hand slot. aiSlot: 0=left, 1=right, 2=voice. Mimics what bosn's
clonePackageSpell does — without an explicit equip the engine's UseMagic procedure
sometimes loses the spell-equip race against CombatStyle weapon preferences.}

Spell Function Native_CloneSpellForCast(Actor akActor, Spell akSource, Bool abDualCasting) Global Native
{Clone a spell into a fresh runtime SpellItem (mirrors bosn's clonePackageSpell).
The clone has its casting perk dropped and its equipSlot set to EitherHand. Use the
returned spell as the target of Native_InjectSpellIntoPackage so the UseMagic
procedure has a clean form to drive — the original Requiem spell carries enough
state that the procedure runs silently and never dispatches to MagicCaster.}

Bool Function Native_ForceFireSpell(Actor akActor, Spell akSpell, ObjectReference akTarget) Global Native
{Force-fire a spell from the actor's MagicCaster at the target. Bypasses the AI
package procedure entirely — projectile spawns, effects apply, animation may or
may not play. Used as a fallback when the UseMagic procedure refuses to dispatch
(diagnostic shows MagicCaster state=0 across all polls). At minimum the cast
actually happens, which is better than the alternative.}

Function SituationMonitor_SetEnabled(Bool enabled) Global Native
{Enable or disable the situation monitor globally.}

Bool Function SituationMonitor_IsEnabled() Global Native
{Check if the situation monitor is currently enabled.}

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
{Rescue any auto-sandboxing followers stranded in a previous cell. \
Call on cell load to bring them to the player.}

Function SituationMonitor_SetSafeInteriorEnabled(Bool enabled) Global Native
{Enable or disable safe interior auto-sandbox globally. \
Call from Papyrus to push persisted StorageUtil value to C++ on load.}

Bool Function SituationMonitor_IsSafeInteriorEnabled() Global Native
{Check if safe interior auto-sandbox is currently enabled in C++.}

; ============================================================================
; BOUNTY STORE — Cosave-backed per-hold bounty tracker
; ============================================================================
; Replaces the StorageUtil.SetIntValue(player, "SeverActions_Bounty_<Hold>", n)
; layer that SeverActions_ArrestBounty.psc has been carrying. Same shape as
; JailedNPCStore — keyed by the crime faction's FormID, persists across
; save/load via cosave record 'BNTY'.
;
; All amounts are absolute (set < 0 to clear). The store auto-removes entries
; whose amount drops to <= 0 so the map stays tight.

Int Function Native_Bounty_Get(Faction crimeFaction) Global Native
{Return the tracked bounty for the given crime faction (0 if none).}

Function Native_Bounty_Set(Faction crimeFaction, Int amount) Global Native
{Set absolute bounty for the faction. amount <= 0 clears the entry.}

Int Function Native_Bounty_Mod(Faction crimeFaction, Int delta) Global Native
{Atomically add delta. Returns the new total. Drops to 0 / clears when new total <= 0.}

Function Native_Bounty_Clear(Faction crimeFaction) Global Native
{Remove the bounty entry for this faction.}

Function Native_Bounty_ClearAll() Global Native
{Wipe the entire bounty store.}

Int Function Native_Bounty_GetCount() Global Native
{Return the number of factions currently carrying a non-zero bounty.}

Int Function Native_Bounty_GetTotal() Global Native
{Return the sum of all tracked bounties across every hold.}

; ── Atomic paired-array snapshot API ─────────────────────────────────────
; The legacy `GetAllFactions` + `GetAllAmounts` pair (removed in this
; refactor) took independent snapshots and could desync if a mutator ran
; between the two calls. Use this explicit 3-call pattern instead:
;
;   Int n = SeverActionsNativeExt.Native_Bounty_SnapshotAll()
;   Faction[] facs    = SeverActionsNativeExt.Native_Bounty_GetSnapshotFactions()
;   Int[]     amounts = SeverActionsNativeExt.Native_Bounty_GetSnapshotAmounts()
;
; SnapshotAll captures the current state into a thread-local cache. The
; two getters drain from that cache and are guaranteed index-aligned —
; facs[i] always pairs with amounts[i]. Cap is 32 entries (vanilla has 9
; holds; covers any modded hold setup).

Int Function Native_Bounty_SnapshotAll() Global Native
{Atomically capture all bounty entries into a thread-local snapshot. Returns the count.}

Faction[] Function Native_Bounty_GetSnapshotFactions() Global Native
{Read the factions from the snapshot captured by Native_Bounty_SnapshotAll. Index-aligned with GetSnapshotAmounts.}

Int[] Function Native_Bounty_GetSnapshotAmounts() Global Native
{Read the amounts from the snapshot captured by Native_Bounty_SnapshotAll. Index-aligned with GetSnapshotFactions.}

; ─── Ledger expansion Phase 4 — per-faction bounty event log ──────────
; Append a single crime row to BountyStore's per-faction event ring.
; Caller is expected to have already invoked Native_Bounty_Mod with the
; same delta — AddEvent only writes the metadata row, never mutates the
; faction's running amount. crimeType should be canonical (output of
; SeverActions_ArrestBounty.NormalizeCrimeType): assault / theft /
; murder / trespass / pickpocket / contempt / abuse_of_power. hold is
; the human display name (e.g. "Whiterun") cached at write time so
; rendering survives load-order changes that might invalidate the
; faction lookup later. Phase 5 surfaces these rows in the World page
; Ledger as per-hold timelines.

Function Native_Bounty_AddEvent(Faction crimeFaction, Int delta, String crimeType, String hold) Global Native
{Append a crime row to the per-faction event ring. Caller must have already called Native_Bounty_Mod with the same delta — this only writes the metadata row, never mutates the running amount. crimeType should be canonical (NormalizeCrimeType output); hold is the cached display name. Ring is bounded at 32 entries per faction, FIFO.}

; ============================================================================
; LOOT THEFT NATIVES (ownership-aware loot/pickup — see InventoryUtils.h)
; ============================================================================
; ProcessLoot / PickUpItemSilent write the theft scratch state; read it back
; immediately after via these getters. Taking from an owned source NEVER
; raises vanilla crime — the loot script charges a SeverActions tracked bounty
; (Native_Bounty_Mod) instead, gated on the theft being witnessed.

Int Function GetLastStolenValue() Global Native
{Summed gold value of OWNED items taken by the most recent ProcessLoot / PickUpItemSilent. 0 if the source was unowned (no theft).}

Faction Function GetLastStolenCrimeFaction() Global Native
{Crime faction the theft bounty should be charged to (owner NPC's crime faction, else the player's current-location crime faction). None if unresolved.}

Bool Function IsRefOwnedByNonPlayer(ObjectReference ref) Global Native
{True if ref is owned by someone other than the player / a player-allied faction. Used to route owned pickups through the silent path.}

Bool Function IsTheftWitnessed(Actor thief, Float radius) Global Native
{True if a loaded, alive, awake, non-follower actor within radius has line-of-sight to the thief. Gates the SA theft bounty so unseen looting is free.}

Int Function PickUpItemSilent(Actor akActor, ObjectReference itemRef) Global Native
{Move a world-item ref into akActor's inventory WITHOUT Activate (no vanilla theft alarm); best-effort flags owned items stolen + records stolenValue/crimeFaction. Returns count moved. Use ONLY for owned items — unowned pickups should Activate (preserves extras, raises no crime).}

Actor Function FindNearestDeadByName(Actor origin, String name, Float radius) Global Native
{Nearest DEAD actor whose display name matches `name` within radius of origin. Avoids a live same-named actor shadowing the corpse. Falls back to the global index if no loaded dead match.}

; ============================================================================
; CEASEFIRE NATIVE (Phase 5 — moved out of Papyrus)
; ============================================================================
; The Papyrus ApplyCeasefireToActor + group-propagation loop used to do N
; round-trips into C++ per actor (one StorageUtil flag, one faction add, one
; faction remove, one EvaluatePackage, one register, repeat). The native
; CeasefireMonitor now owns the full apply/restore cycle — Papyrus calls
; PropagateGroup once with the initiator + partner, and gets back the array
; of all actors that ended up ceasefire'd for timestamp/prompt-flag bookkeeping.
;
; Set*Faction must be called once at OnInit and OnPlayerLoadGame so the
; native side knows which faction is "surrendered" and which list defines
; "normally hostile". Both are persisted in the C++ cosave for safety.

Function Ceasefire_SetSurrenderedFaction(Faction f) Global Native
{Tell the native ceasefire monitor which faction to put pacified actors INTO.}

Function Ceasefire_SetHostileFactionsList(FormList l) Global Native
{Tell the native ceasefire monitor which factions to consider "normally hostile" — actors in any of these get that membership stashed for restore on break, and the wasNormallyHostile flag set.}

Bool Function Ceasefire_ApplyToActor(Actor akActor, Actor akPartner) Global Native
{Zero aggression, faction-swap, stop combat, register. Returns true if newly applied, false if already monitored.}

Actor[] Function Ceasefire_PropagateGroup(Actor akInitiator, Actor akPartner, Float radius) Global Native
{Apply ceasefire to initiator + partner + nearby faction allies in combat. Returns the full set of affected actors for Papyrus timestamp bookkeeping.}

Function Ceasefire_ForceBreak(Actor akActor) Global Native
{Restore aggression / factions / relationship rank WITHOUT firing the broken ModEvent. Used by FullCleanup mid-ceasefire so the prompt doesn't see a spurious yield-broken transition.}

Bool Function Ceasefire_IsWasNormallyHostile(Actor akActor) Global Native
{Query the native entry's wasNormallyHostile flag — Papyrus uses this to mirror the flag into StorageUtil for prompt-side branching.}

; ============================================================================
; YIELD NATIVE (Phase 6 — moved out of Papyrus)
; ============================================================================
; Mirror of the Phase 5 ceasefire migration: the Papyrus ConvertToSurrendered
; function (~30 lines per call site, walks SeverHostileFactions FormList,
; manipulates factions, sets WasSurrendered + WasNormallyHostile + original
; aggression) now lives in YieldMonitor. The hit-driven break path
; (RevertSurrender) and the deliberate ReturnToCrime path also restore the
; hostile factions natively, so OnYieldBroken/ReturnToCrime in Papyrus only
; clear prompt-side StorageUtil keys.
;
; Set*Faction is called at OnInit/OnPlayerLoadGame so the native side knows
; which factions to swap. Persisted in the C++ cosave.

Function Yield_SetSurrenderedFaction(Faction f) Global Native
{Tell the native yield monitor which faction to put yielded actors INTO.}

Function Yield_SetHostileFactionsList(FormList l) Global Native
{Tell the native yield monitor which factions to consider "normally hostile" — actors in any of these get that membership stashed for restore on revert / return-to-crime, and the wasNormallyHostile flag set.}

Bool Function Yield_ConvertToSurrendered(Actor akActor) Global Native
{Zero aggression, faction-swap (hostile -> SeverSurrenderedFaction), store original aggression + removed factions in the monitor entry. Returns true if at least one hostile faction was removed (i.e. WasNormallyHostile).}

Function Yield_ReturnToCrime(Actor akActor) Global Native
{Deliberate revert: restore aggression, remove from SeverSurrenderedFaction, re-add hostile factions, unregister from monitor. Silent (does not fire SeverActionsNative_YieldBroken).}

Function Yield_ForceBreak(Actor akActor) Global Native
{Alias for Yield_ReturnToCrime — same restore + unregister semantic, used by FullCleanup so the call site reads clearly.}

Bool Function Yield_IsWasNormallyHostile(Actor akActor) Global Native
{Query the native entry's wasNormallyHostile flag for prompt-side StorageUtil mirroring.}

; ============================================================================
; BRAWL MANAGER — fist-fight pair tracker
; ============================================================================
; Tracks active brawls (player↔NPC and NPC↔NPC). Uses vanilla
; DGIntimidateFaction (kSpecialCombat) for engine-level non-lethal bleedout
; routing. Enforces fists-only via TESEquipEvent sink. Ends on bleedout, on
; forfeit, on cheating (non-unarmed hit), or on third-party interference.
; Cosave record 'BRWL'.

Bool Function Brawl_Begin(Actor a, Actor b) Global Native
{Start a brawl between a and b. Snapshots loadout, applies DGIntimidateFaction,
 swaps NPC CombatStyle to brawler, unequips weapons/spells/scrolls/ammo, sets
 Aggression=1 / Confidence=3 on NPCs, calls StartCombat both ways. Returns
 false if either actor is null/dead or already in a brawl.}

Function Brawl_End(Actor actor, Int reason) Global Native
{End the brawl `actor` is in. Restores all snapshotted state and re-equips the
 loadout. Reasons:
   1 = LoserBleedout
   2 = Forfeit
   3 = WalkedAway
   4 = BrokenToCombat (cheating / interference)
   5 = Abort (safety wipe)
 Idempotent — no-op if actor isn't in an active brawl. Fires the
 SeverBrawl_Ended ModEvent with strArg="reason|winnerFID|loserFID".}

Bool Function Brawl_IsActive(Actor a) Global Native
{True iff `a` is a participant in an active brawl. Cheap (single map lookup).}

Actor Function Brawl_GetOpponent(Actor a) Global Native
{Returns the other participant in `a`'s active brawl, or None if not brawling.}

Function Brawl_SetDGFaction(Faction f) Global Native
{Hand the vanilla DGIntimidateFaction (FID 0x04CFA6 on Skyrim.esm) to the
 native manager. Called from SeverActions_Brawl.OnInit / OnPlayerLoadGame.}

Function Brawl_SetBrawlerCS(CombatStyle cs) Global Native
{Hand the brawler CombatStyle (vanilla csWEBrawler 0x10555D on Skyrim.esm) to
 the manager for NPC combat-style swapping on brawl start.}

Actor Function Brawl_GetLastWinner() Global Native
{The winner of the most-recently-ended brawl in this session. Populated by
 Brawl_End. Returns None for sessions with no brawls yet, or for brawls
 where there was no clear winner (e.g. BrokenToCombat).}

Actor Function Brawl_GetLastLoser() Global Native
{The loser of the most-recently-ended brawl. See Brawl_GetLastWinner.}

Int Function Brawl_GetLastReason() Global Native
{Reason code of the most-recently-ended brawl. 0 if none.
 1=LoserBleedout, 2=Forfeit, 3=WalkedAway, 4=BrokenToCombat, 5=Abort.}

; ============================================================================
; COMBAT COOLDOWN STORE (Phase 6 — replaces SeverCombat_CooldownEnd StorageUtil)
; ============================================================================
; Per-actor "AttackTarget unavailable" gate. Set on yield/ceasefire, queried
; by AttackTarget_IsEligible. The previous StorageUtil-backed implementation
; computed expiry from Utility.GetCurrentGameTime() + duration_sec/24/60;
; the new native uses Calendar::GetCurrentGameTime() with the same semantic
; (absolute game-time-in-days as the expiry timestamp).

Function Cooldown_Set(Actor akActor, Float durationSeconds) Global Native
{Set/extend a cooldown to expire durationSeconds from now (game-time scaled).}

Bool Function Cooldown_IsActive(Actor akActor) Global Native
{True iff the actor has an active cooldown. Lazily clears expired entries.}

Function Cooldown_Clear(Actor akActor) Global Native
{Clear any active cooldown for the actor.}

; =============================================================================
; DebtStore (Phase 3a) — cosave-backed registry of gold obligations.
;
; Replaces the SeverDebt_<i>_<field> StorageUtil slot layer in
; SeverActions_Debt.psc. Each debt has a stable monotonic Int id assigned
; at Add() time and never recycled (so short-lived event keys derived from
; the id are collision-free across removals — fixes bug A9).
;
; Time fields are in game DAYS (Utility.GetCurrentGameTime() units), not
; the seconds-equivalent the legacy Papyrus code multiplied through.
; Persisted in cosave record 'DEBT'.

Int Function Native_Debt_Add(Actor creditor, Actor debtor, Int amount, String reason, Float dueGameDays, Bool isRecurring, Float intervalDays, Int creditLimit, Int recurringCharge) Global Native
{Create a new debt. Returns the assigned id (>= 1), or 0 on invalid args
 (null actors, amount <= 0, creditor == debtor). For non-recurring debts
 pass isRecurring=false, intervalDays=0.0, recurringCharge=0.}

Bool Function Native_Debt_Remove(Int id) Global Native
{Remove the debt by id. Returns true if it existed.}

Bool Function Native_Debt_Exists(Int id) Global Native
{Check whether a debt with this id is still in the store.}

Int Function Native_Debt_GetCount() Global Native
{Total number of debts in the store.}

Int[] Function Native_Debt_GetAllIDs() Global Native
{All live debt ids. Order is unspecified.}

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
{Atomically apply delta. Returns:
   - newAmount (>= 0) on success (entry removed when newAmount drops to 0)
   - -1 when the debt is already at its credit limit (no mutation)}

Function Native_Debt_MarkRecurred(Int id, Float gameDays) Global Native
{Stamp lastRecurredGameDays — called from tick after a cycle is applied or skipped.}

Function Native_Debt_SetOverdueNotified(Int id, Bool value) Global Native
Function Native_Debt_SetReportedToGuards(Int id, Bool value) Global Native

Int Function Native_Debt_FindByTriple(Actor creditor, Actor debtor, String reason) Global Native
{First id with exact creditor + debtor + reason match, or 0.}

Int Function Native_Debt_FindFirstPair(Actor creditor, Actor debtor) Global Native
{First id where creditor=creditor and debtor=debtor (any reason), or 0.}

Int Function Native_Debt_FindRecurringPair(Actor creditor, Actor debtor) Global Native
{First recurring debt between this creditor and debtor, or 0.}

Int Function Native_Debt_SumOwed(Actor creditor, Actor debtor) Global Native
{Total gold debtor owes creditor across all matching debts.}

Int Function Native_Debt_SumOwedBy(Actor debtor) Global Native
Int Function Native_Debt_SumOwedTo(Actor creditor) Global Native

Bool Function Native_Debt_HasAnyDebt(Actor actor) Global Native
Bool Function Native_Debt_IsCreditorOnAnyDebt(Actor actor) Global Native

Int Function Native_Debt_ReduceForPayment(Actor creditor, Actor debtor, Int amountPaid) Global Native
{Reduce all (creditor→debtor) debts by amountPaid, removing any that hit zero.
 Returns the actual reduction applied (≤ amountPaid). Caller is responsible
 for any SkyrimNet event registration / summary rebuild.}

Int Function Native_Debt_RemoveDebtsInvolvingName(String targetName) Global Native
{Remove every debt where either party's display name equals targetName.
 Returns the count removed. Used by PrismaUI's per-actor "Clear" button.}

Int Function Native_Debt_FindBestForGiveItem(Actor giver, Actor receiver) Global Native
{Find the creditor=giver, debtor=receiver debt best suited for auto-charging
 a transferred item's gold value. Prefers non-recurring (tabs) over recurring
 (rent). Returns 0 if no such debt exists.}

; =============================================================================
; DebtStore tick + event drain (Phase 3b)
;
; Native_Debt_Tick walks every debt, applies recurring charges + overdue/guard
; report state changes, and enqueues SkyrimNet events. Papyrus is still the
; one that actually calls SkyrimNetApi.Register*Event (SkyrimNet's PublicAPI
; doesn't expose event registration to C++), so the caller must drain the
; queue immediately after Tick:
;
;   Int n = SeverActionsNativeExt.Native_Debt_Tick(enableOverdue, graceDays, reportDays)
;   Int i = 0
;   While i < n
;       Int kind = SeverActionsNativeExt.Native_Debt_PendingEvent_Kind(i)
;       ; … dispatch …
;       i += 1
;   EndWhile
;   SeverActionsNativeExt.Native_Debt_ClearPendingEvents()
;
; Kind values:  0 = Regular  → SkyrimNetApi.RegisterEvent(name, content, c, d)
;               1 = ShortLived → RegisterShortLivedEvent(key, name, content, "", ttlMs, c, d)
;               2 = Persistent → RegisterPersistentEvent(content, c, d)

Int Function Native_Debt_Tick(Bool overdueEnabled, Float graceGameDays, Float reportGameDays) Global Native
{Run the native debt tick. Returns the number of queued events Papyrus must
 drain. graceGameDays / reportGameDays are in game days (Papyrus passes the
 MCM hours-tunable values divided by 24).}

Int Function Native_Debt_PendingEventCount() Global Native
Int Function Native_Debt_PendingEvent_Kind(Int index) Global Native
String Function Native_Debt_PendingEvent_Name(Int index) Global Native
String Function Native_Debt_PendingEvent_Content(Int index) Global Native
String Function Native_Debt_PendingEvent_Key(Int index) Global Native
Int Function Native_Debt_PendingEvent_TTL(Int index) Global Native
Actor Function Native_Debt_PendingEvent_Creditor(Int index) Global Native
Actor Function Native_Debt_PendingEvent_Debtor(Int index) Global Native
Function Native_Debt_ClearPendingEvents() Global Native

; ─── Follower Pair Relationships ───────────────────────────────────────
; Co-located with the rest of the pair-relationship accessors on the
; "Native" class for historical reasons; declared here on Ext to keep
; SeverActionsNative under the 511-function-per-class Papyrus VM ceiling.

String Function Native_GetPairBlurb(Actor akActor, Actor akTarget) Global Native
{Get the LLM-generated narrative blurb describing how akActor feels about
 akTarget. Returns "" when no blurb has been set. Completes the pair-
 relationship accessor trio (affinity / respect / blurb) so FollowerManager
 can sunset the SeverFollower_Blurb_<fid> StorageUtil mirror.}


; ─── T1-B (v10): per-follower scalars + dedup watermarks ──────────────
; Consolidates 11 SeverFollower_*/SeverActions_* StorageUtil keys into
; the native FollowerData struct. Declared on Ext to avoid pushing the
; main SeverActionsNative class past the 511-function-per-class ceiling.
; All defaults match the pre-migration StorageUtil defaults (0, false, "").

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

; Home / scene state — suppresses home behaviour re-entry until cleared.
Bool Function Native_GetHomeSceneSuspended(Actor akActor) Global Native
Function Native_SetHomeSceneSuspended(Actor akActor, Bool value) Global Native

; LLM "this follower wants to leave" warning dedup.
Bool Function Native_GetLeaveWarned(Actor akActor) Global Native
Function Native_SetLeaveWarned(Actor akActor, Bool value) Global Native

; Game-time seconds of follower death. 0 = alive.
Float Function Native_GetDeathTime(Actor akActor) Global Native
Function Native_SetDeathTime(Actor akActor, Float value) Global Native

; Pre-recruitment combat style preserved for restore-on-dismiss.
Form Function Native_GetOrigCombatStyleForm(Actor akActor) Global Native
Function Native_SetOrigCombatStyleForm(Actor akActor, Form combatStyle) Global Native

; Essential-flag tracking.
Bool Function Native_GetEssentialOff(Actor akActor) Global Native
Function Native_SetEssentialOff(Actor akActor, Bool value) Global Native

Bool Function Native_GetWasEssential(Actor akActor) Global Native
Function Native_SetWasEssential(Actor akActor, Bool value) Global Native

; Custom-AI signal — recruited via Serana's vampire-companion route.
Bool Function Native_GetRecruitedViaSerana(Actor akActor) Global Native
Function Native_SetRecruitedViaSerana(Actor akActor, Bool value) Global Native

; ─── T1-A.2 (v11): per-follower string blobs ──────────────────────────
; companionOpinions: pre-built markdown rebuilt every assess sweep.
; lifeEventHistory: JSON event history maintained by the off-screen life
; processor. Both surfaced into prompts via dedicated SkyrimNet decorators
; (sever_companion_opinions / sever_life_event_history) registered in
; SkyrimNetBridge — the StorageUtil + papyrus_util pipeline that fed
; 0175_severactions_follower / 0176_severactions_offscreen_life is retired.

String Function Native_GetCompanionOpinions(Actor akActor) Global Native
Function Native_SetCompanionOpinions(Actor akActor, String value) Global Native

String Function Native_GetLifeEventHistory(Actor akActor) Global Native
Function Native_SetLifeEventHistory(Actor akActor, String value) Global Native

; ─── T1-A.3 (v12): life summary + work/play marker labels ─────────────

String Function Native_GetLifeSummary(Actor akActor) Global Native
Function Native_SetLifeSummary(Actor akActor, String value) Global Native

String Function Native_GetWorkLocationName(Actor akActor) Global Native
Function Native_SetWorkLocationName(Actor akActor, String value) Global Native

String Function Native_GetPlayLocationName(Actor akActor) Global Native
Function Native_SetPlayLocationName(Actor akActor, String value) Global Native

; ─── T1-D.1: Active arrest singleton (player quest FSM state) ─────────
; Replaces 7 SeverActions_ActiveArrest* StorageUtil keys keyed by
; `Self as Form` on the arrest quest. Saved to a separate 'AARS' cosave
; record alongside the existing 'ARST' session map. No upgrade migration
; — accept transient state loss on upgrade (user can serve sentence /
; escape normally; next crime triggers a fresh arrest cleanly).

Function Native_Arrest_SetActiveArrest(Int arrestState, Actor guard, Actor prisoner, ObjectReference jailMarker, String jailName, Float approachStart, Float escortStart) Global Native
Function Native_Arrest_ClearActiveArrest() Global Native

Int Function Native_Arrest_GetActiveArrestState() Global Native
Actor Function Native_Arrest_GetActiveArrestGuard() Global Native
Actor Function Native_Arrest_GetActiveArrestPrisoner() Global Native
ObjectReference Function Native_Arrest_GetActiveArrestJailMarker() Global Native
String Function Native_Arrest_GetActiveArrestJailName() Global Native

; ─── T1-D.2: per-guard dispatch context + active-dispatch singleton ───
; Replaces 9 SeverActions_Dispatch* StorageUtil keys (keyed by guard
; Actor form) and 1 SeverActions_ActiveDispatchGuard (keyed by quest
; form). Stored in the 'ARDC' cosave record alongside the existing
; 'ARST' / 'AARS' arrest records. No upgrade migration — transient
; state, accept loss on upgrade.

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

; ─── T1-D.3: pending-evidence packet + deferred-sender singleton ──────
; Replaces 4 SeverActions_Pending* / DeferredSender StorageUtil keys.
; Map is keyed by the SENDER (crime reporter); singleton tracks the
; current deferred sender across the dispatch flow.

Function Native_Arrest_SetPendingEvidence(Actor sender, String narration, Actor guard) Global Native
Function Native_Arrest_ClearPendingEvidence(Actor sender) Global Native
Bool Function Native_Arrest_HasPendingEvidence(Actor sender) Global Native
String Function Native_Arrest_GetPendingNarration(Actor sender) Global Native
Actor Function Native_Arrest_GetPendingGuard(Actor sender) Global Native

Function Native_Arrest_SetDeferredSender(Actor sender) Global Native
Actor Function Native_Arrest_GetDeferredSender() Global Native

; ─── T3-A: survival LastEatAttempt accessor ───────────────────────────
; Hour bracket of the last eat-attempt the follower made on the 30-second
; survival tick. Stored on SurvivalDataStore.FollowerNeeds (v3). Replaces
; the SeverActions_Survival_LastEatAttempt StorageUtil key. Survival
; needs (hunger/fatigue/cold) now read via sever_hunger / sever_fatigue
; / sever_cold SkyrimNet decorators in prompts.

Int Function Native_Survival_GetLastEatAttempt(Actor akActor) Global Native
Function Native_Survival_SetLastEatAttempt(Actor akActor, Int bracket) Global Native

; ─── T3-B: Arrest prisoner outfit + jail marker on ArrestSession ──────
; Per-prisoner data folded into the existing 'ARST' cosave record (v3).
; Replaces SeverActions_OriginalOutfit + SeverActions_JailMarker keys.

Function Native_ArrestSession_SetOriginalOutfit(Actor prisoner, Form outfit) Global Native
Form Function Native_ArrestSession_GetOriginalOutfit(Actor prisoner) Global Native

; Jail-marker accessors on ArrestSession dropped — Native_Jailed_GetMarker
; (declared above on JailedNPCStore) is the single source of truth.

; ─── Ledger expansion Phase 1: LedgerStore transaction log ────────────
; Cosave-backed transaction log + per-day/per-week aggregates feeding the
; World page Ledger. Phase 1 ships only the ingest API + admin helpers;
; Phase 2 wires Currency / Debt / Bounty write paths through RecordEvent.
; Source strings are stable category keys consumed by the frontend
; (e.g. "give_gold", "collect_payment", "extort", "buy_item", "sell_item",
; "debt_payment", "debt_added", "bounty_added", "bounty_paid",
; "unclassified", "vendor_spend"). Direction follows player gold flow:
; isOut=False means gold flowed TO the player, True means away.
; counterparty may be None for system-level events; hold is optional and
; only meaningful for bounty entries; debtId is optional cross-ref to a
; DebtStore entry for "debt_payment" / "debt_added" rows.

Function Native_Ledger_RecordEvent(Int amount, Bool isOut, String source, Actor counterparty, String hold, String reason, Int debtId) Global Native

Int Function Native_Ledger_RawCount() Global Native
{Count of raw entries currently held (within the last ~30 game days).}

Int Function Native_Ledger_DailyCount() Global Native
{Count of daily aggregate buckets (lifetime, capped ~10 game years).}

Function Native_Ledger_ClearAll() Global Native
{Wipe raw + daily + weekly. Intended for MCM "Reset Ledger" only.}

; ============================================================================
; FollowerSystemHydrator (Phase 3 — C++ follower refactor)
; ============================================================================
; Native equivalent of the heaviest per-follower passes in
; SeverActions_FollowerManager.RunDeferredMaintenance. Runs at kPostLoadGame
; (C++ plugin.cpp) so the engine-side state (essential / combat style /
; HealerPoll registration) is ready before Papyrus OnPlayerLoadGame fires.
;
; The Papyrus deferred-maintenance chain still exists for new-recruit flows
; (which fire outside the load path). Native_HydrateFollowerSystem_DidRun
; lets RunDeferredMaintenance short-circuit the equivalent passes when the
; native side has already taken care of them this session.

Bool Function Native_HydrateFollowerSystem_DidRun() Global Native
{True when FollowerSystemHydrator::Hydrate() has actually processed at
 least one follower this session. Cleared on kRevert; also false on a
 fresh kNewGame where the cosave starts empty (so the Papyrus reapply
 chain still runs for whoever the player recruits later). RunDeferredMaintenance
 checks this and skips ReapplyEssentialStatus + ReapplyCombatStyles +
 RebuildAllCompanionOpinions when it returns true.}

Int Function Native_HydrateFollowerSystem_Run() Global Native
{Re-run FollowerSystemHydrator::Hydrate() and return the number of
 followers processed. Idempotent — Papyrus calls this after detection
 passes (DetectExistingFollowers / RecoverCustomAIFollowers) so that
 followers added to the cosave during this Maintenance pass receive
 the same engine-side combat-style / essential-flag / opinion treatment
 the kPostLoadGame hydrator gave to pre-existing cosaved followers.
 Flips Native_HydrateFollowerSystem_DidRun to true iff processed > 0.}

Actor[] Function Native_ScanPlayerCellForLiveActors() Global Native
{Return alive, non-player, non-commanded NPCs in the player's parent cell.
 Replaces the Papyrus playerCell.GetNumRefs(43) + GetNthRef + IsDead +
 IsCommandedActor + IsPlayerRef filter loop in DetectExistingFollowers /
 GetAllFollowers (60-300+ native dispatches in a populated city cell). The
 returned list is small and pre-filtered, so the per-actor follower checks
 in Papyrus run on a fraction of the original ref count.}

; ============================================================================
; PERIODIC CELL-SCAN NATIVES (perf — replaces per-tick Papyrus GetNumRefs loops)
; ============================================================================

Function Native_Survival_UpdateNearby(Int maxCount, Float maxDist) Global Native
{Scan the player's parent cell and seed the native nearby-NPC survival map.
 Replaces SeverActions_Survival.UpdateNearbyNPCs's GetNumRefs(43) + GetNthRef
 + IsDead/IsPlayerTeammate/distance filter loop. maxCount mirrors the old
 `i < 25` budget (counts every actor ref examined, player/dead included);
 maxDist is the inclusion radius in raw game units (old loop used 4096.0).
 Calls InitNearbyNPC on each qualifying actor entirely in C++.}

Function Native_Survival_SetEnabled(Bool abEnabled) Global Native
{Push the survival master-switch state to the native store. When false, the
 sever_hunger/sever_fatigue/sever_cold decorators report 0 for every actor so
 the survival prompt never renders; stored needs are preserved (not zeroed) and
 resume when survival is re-enabled. SeverActions_Survival pushes this on every
 StartTracking/StopTracking and on game load (Maintenance).}

Actor[] Function Native_ScanPlayerCellFemales3DLoaded() Global Native
{Return non-player, 3D-loaded female actors in the player's parent cell.
 Replaces SeverActions_FertilityMode_Bridge.UpdateNearbyActors's GetNumRefs(43)
 + GetNthRef + female + Is3DLoaded filter loop. No dead/commanded filter —
 matches the original Papyrus loop exactly. Papyrus iterates the returned
 array and calls UpdateActorFertilityData per actor (that read stays Papyrus —
 it touches Fertility Mode's external store).}

; =============================================================================
; CommissionStore — deferred crafting commissions (cosave record 'CMSN')
;
; A commission is an order the player places with a blacksmith for an item that
; isn't handed over on the spot ("forge me a sword — it'll be ready in a few
; days"). The instant-craft path (SeverActions_Crafting.CraftItem_Internal →
; CraftingOrchestrator) is untouched; this is the deferred path:
;
;   CommissionItem  → take a 50% deposit, parse the smith's NL ETA, record it.
;   <game time>     → Native_Commission_Tick flips matured orders to Ready and
;                     queues a "commission_ready" SkyrimNet event.
;   CollectCommission (gated by has_ready_commission decorator) → pay the
;                     balance, conjure the item, remove the record.
;
; Economy (locked v1): priceTotal = item gold value × count; 50% deposit at
; order; balance due at pickup. No DebtStore involvement — an unpaid balance
; just means the commission stays Ready until the player pays.
;
; Identity: monotonic Int id assigned at Add (>= 1), never recycled (persisted
; in the cosave header). id == 0 is the universal "not found / invalid"
; sentinel. Time fields are in game DAYS (Utility.GetCurrentGameTime() units).

Int Function Native_Commission_Add(Actor crafter, Actor customer, Form item, Int count, String itemName, String crafterName, String customerName, Int priceTotal, Int depositPaid, Float etaDays) Global Native
{Record a new commission. Returns the assigned id (>= 1), or 0 on invalid args
 (null crafter/customer/item, count <= 0) or when the store is at its cap (10).
 readyAtDays is computed as now + etaDays; balanceDue as priceTotal - depositPaid
 (clamped >= 0). Names are captured as strings so the decorator never LookupByID.}

Bool Function Native_Commission_Remove(Int id) Global Native
{Remove the commission by id. Returns true if it existed.}

Bool Function Native_Commission_Exists(Int id) Global Native
{Check whether a commission with this id is still in the store.}

Int Function Native_Commission_GetCount() Global Native
{Total number of active commissions across all crafters.}

Int[] Function Native_Commission_GetAllIDs() Global Native
{All live commission ids. Order is unspecified.}

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
{0 = Ordered (smith still working), 1 = Ready (waiting for collection). -1 if id not found.}

Int Function Native_Commission_FindReadyForCrafter(Actor crafter) Global Native
{First Ready commission id for this crafter, or 0. v1 customers are all the
 player, so a crafter match identifies "the player's finished order here".}

Bool Function Native_Commission_HasReadyForCrafter(Actor crafter) Global Native
{True iff this crafter has at least one Ready commission. Mirrors the
 has_ready_commission decorator for Papyrus-side gating.}

Int Function Native_Commission_CountForCrafter(Actor crafter) Global Native
{Number of active commissions (any status) for this crafter. Drives the
 per-smith backlog narration ("I've got a few orders ahead of yours").}

Float Function Native_Commission_ParseEtaDays(String text) Global Native
{Clean-room natural-language ETA parser. "a couple days" -> 2.0, "a week" ->
 7.0, "tomorrow" -> 1.0, "three days" -> 3.0, "a few hours" -> ~0.125. Floors
 at 1 hour, ceilings at 60 days, defaults to 2.0 days when nothing parses.}

; ─── CommissionStore tick + event drain ──────────────────────────────────────
;
; Native_Commission_Tick flips every matured (Ordered, readyAtDays reached)
; commission to Ready and enqueues a "commission_ready" SkyrimNet event for
; each. Papyrus drains the queue and calls SkyrimNetApi.Register*Event
; (SkyrimNet's PublicAPI doesn't expose event registration to C++):
;
;   Int n = SeverActionsNativeExt.Native_Commission_Tick()
;   Int i = 0
;   While i < n
;       Int kind = SeverActionsNativeExt.Native_Commission_PendingEvent_Kind(i)
;       ; … dispatch …
;       i += 1
;   EndWhile
;   SeverActionsNativeExt.Native_Commission_ClearPendingEvents()
;
; Kind values:  0 = Regular  → SkyrimNetApi.RegisterEvent(name, content, c, cust)
;               1 = ShortLived → RegisterShortLivedEvent(key, name, content, "", ttlMs, c, cust)
;               2 = Persistent → RegisterPersistentEvent(content, c, cust)
; commission_ready events are emitted as ShortLived (kind 1).

Int Function Native_Commission_Tick() Global Native
{Run the native commission tick. Returns the number of queued events Papyrus
 must drain. Reads the current game time internally (no args).}

Int Function Native_Commission_PendingEventCount() Global Native
Int Function Native_Commission_PendingEvent_Kind(Int index) Global Native
String Function Native_Commission_PendingEvent_Name(Int index) Global Native
String Function Native_Commission_PendingEvent_Content(Int index) Global Native
String Function Native_Commission_PendingEvent_Key(Int index) Global Native
Int Function Native_Commission_PendingEvent_TTL(Int index) Global Native
Actor Function Native_Commission_PendingEvent_Crafter(Int index) Global Native
Actor Function Native_Commission_PendingEvent_Customer(Int index) Global Native
Function Native_Commission_ClearPendingEvents() Global Native

; Snapshot a finished commission into the completed-history log (World → Ledger)
; just before it's removed on collection. Pass the commission id; the native
; copies item/crafter/price/deposit + stamps the collection game-time.
Function Native_Commission_RecordCompleted(Int id) Global Native

; ── Commission PrismaUI confirm prompts (deposit at order, balance at pickup) ──
; Non-pausing overlay sibling of PrismaUI_OpenPaymentPrompt, reusing the
; SeverActionsPrompt view. `mode` is "deposit" or "balance"; the bridge posts
; the player's choice back via the SeverActions_CommissionPromptChoice ModEvent
; (strArg = "accept"/"deny", numArg = amount charged, sender = smith). The
; Crafting script holds the rest of the pending order context. Falls back to
; SkyMessage.Show when the overlay isn't available.

Bool Function PrismaUI_OpenCommissionPrompt(Actor akSmith, Int aiAmountNow, String asSmithName, String asItemName, Int aiTotal, Int aiDeposit, Int aiBalance, String asMode, Int aiTimeoutMs) Global Native
{Open the commission deposit/balance confirm overlay. Returns True if shown — \
caller then waits for SeverActions_CommissionPromptChoice. False if PrismaUI is \
unavailable, another prompt is open, or another view has focus (fall back to SkyMessage).}

Function PrismaUI_CloseCommissionPrompt() Global Native
{Force-close the commission overlay without firing a choice (treated as decline).}

Bool Function PrismaUI_IsCommissionPromptOpen() Global Native
{Returns True while the commission overlay is currently displayed.}

Bool Function PrismaUI_IsCommissionPromptAvailable() Global Native
{Returns True if the bridge is initialized AND the view finished its DOM-ready \
handshake. Check before calling PrismaUI_OpenCommissionPrompt.}
