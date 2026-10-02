Scriptname SeverActionsNativeExt2 Hidden
{Third class of SeverActions natives: the Enterprises (Venture_*) natives and
 every newer batch. SeverActionsNativeExt hit the ~511-natives-per-script VM cap,
 which breaks native lookup for the whole class. The C++ registration's script
 name must match this class.}

; ── Enterprises (see ENTERPRISES.md), mixed with other toggles ──────────────
Bool Function Native_GetLLMCallsEnabled() Global Native
{Background-AI master toggle (llmCallsEnabled): false silences every SeverActions
 background LLM call. SkyrimNet's own dialogue is unaffected.}

Function Native_SetLLMCallsEnabled(Bool abEnabled) Global Native
{Set the Background-AI master toggle live only: nothing is recorded to the
 settings file or the Authority.}

Bool Function Native_GetFollowersCanTravel() Global Native
{Followers-can-travel toggle: true lets anyone SA rosters, walks or parks (a
 follower, a tag-along, a waiting casual) use the LLM TravelToPlace action
 (default false; anyone else always may). Read by the sever_travel_allowed
 decorator.}

Function Native_SetFollowersCanTravel(Bool abEnabled) Global Native
{Set the followers-can-travel toggle live only: nothing is recorded to the
 settings file or the Authority.}

Actor Function Native_GetKillerOf(Actor akActor) Global Native
{Who the engine records as this actor's killer (RE::Actor::GetKiller), or None.
 Lets the captive-death consequence tell an execution from neglect.}

Function Venture_SetTaxEnabled(Bool abEnabled) Global Native
{Master toggle for hold taxes on weekly enterprise income.}

Function Venture_SetTaxMult(Int aiPercent) Global Native
{Scale on the marginal hold-tax brackets, 0-200 percent (100 = baseline).}

Int Function Venture_AdjustHoldTaxForJarl(Actor akJarl, Int aiDeltaPct) Global Native
{Jarl petition: shift the jarl's hold tax by aiDeltaPct points (total adjust
 clamped -15..+25). Returns the new rate at a 250g take, or -1 when the actor has
 no crime faction.}

Int Function Venture_GetHoldTaxForJarl(Actor akJarl) Global Native
{The jarl's hold tax rate at a 250g take (-1 = no crime faction).}

Function Venture_DebugAdd(Actor akAssignee, Int job, Int arrangement, Int wageWeekly) Global Native
{Hire a test retainer. job: 0 Miner 1 Merchant 2 Alchemist 3 Farmer 4 Fence 5 Mercenary 6 Courtesan 7 Guard 8 Lumberjack 9 Custom 10 Blacksmith 11 Hunter 12 Brewer 13 Tanner. \
arrangement: 0 Employed 1 Partnership 2 Vassalage (coerced) 3 Sworn. wageWeekly applies to Employed/Sworn.}

Function Venture_DebugRemove(Actor akAssignee) Global Native
{Remove a retainer (debug cleanup / re-hire).}

Function Venture_ForceSettle() Global Native
{Force every active venture due and run a settlement pass now (logs each step).}

Function Venture_Collect(Actor akAssignee) Global Native
{Pay one retainer's pending escrow (gold + goods) to the player, remotely (board/MCM). Refuses a defiant Tribute retainer; dialogue uses Venture_CollectInPerson.}

Function Venture_CollectInPerson(Actor akAssignee) Global Native
{Face-to-face collect (dialogue): the only route to a DEFIANT Tribute retainer's withheld escrow; answering the dare makes them back down until the next settle.}

Function Venture_CollectAll() Global Native
{Collect pending escrow from every retainer.}

Function Venture_PayAllArrears() Global Native
{Pay back-wages across the roster, cheapest-first, clearing as many retainers as the player's purse can fully cover.}

Actor[] Function Venture_ListCourtesans() Global Native
{Active courtesan retainers (not deserted/hostile/jailed); empty when none.
 Soft cross-plugin surface for the NSFW plugin's client-visit scheduler.}

Function Venture_BookClientCoin(Actor akCourtesan, Int aiAmount) Global Native
{Settle a client's fee: the player's cut (the arrangement's playerCutPct) goes to
 escrow and is collected with the weekly income; the rest goes to the courtesan
 as real coin.}

Function Venture_Bail(Actor akAssignee) Global Native
{Pay a JAILED fence retainer's bounty from the player's gold to free them from the cell early. No-op unless the retainer is actually jailed.}

; Pay an ACTIVE fence's own illicit bounty from the player's purse, before the
; guards act. A jailed fence routes to Venture_Bail.
Function Venture_SettleBounty(Actor akAssignee) Global Native

Function Venture_ForceArrest(Actor akAssignee) Global Native
{Debug: deterministically arrest+jail a retainer now (seeds a test bounty if none).}

Function Venture_Reassure(Actor akAssignee) Global Native
{Temper hearing SUCCESS (heard out face to face). Consensual terms: morale up, any standing notice withdrawn. Coerced terms: cowed for one settle, no morale repair. Clears an armed Send-Word meeting; cooldown-gated when no meeting was armed.}

Function Venture_BrushOff(Actor akAssignee) Global Native
{Temper hearing FAILURE (grievance dismissed to their face): a bigger morale drop than a no-show; a resentful/aggrieved consensual retainer gives notice at once, a Tribute retainer turns defiant. Clears the armed meeting.}

Function Venture_GrantRaiseInPerson(Actor akAssignee) Global Native
{Temper hearing: the player agrees in conversation to raise pay (or ease coerced terms). Grants the pending ask, re-grants refused terms, or synthesizes standard raise terms, then runs the full grant settlement. Consumes an armed meeting. No-op for Enslaved.}

Function Venture_SetTemperEnabled(Bool abEnabled) Global Native
{Master toggle for the Temper consequence ladder. Off = morale still tracks, but no complaint letters, pilfering, notices, defiance, betrayal or escapes; standing notices lapse at the next settle.}

Function Venture_SetLevyEnabled(Bool abEnabled) Global Native
{Imperial Levy master switch (the Final Audit detail). Off = no case opens, and a
 detail in the field is disbanded on the next native tick: all fifteen disabled in
 place, the patrol quest stopped, the case reset to Dormant (Papyrus strips their
 overrides on SeverActions_FinalAuditDisbanded). On re-arms the purse-threshold
 deploy.}

Bool Function Venture_GetLevyEnabled() Global Native
{Current state of the Imperial Levy master switch.}

Bool Function Native_LeashHasHandLeash() Global Native
{Leash Framework 1.1.1+: the Leash_hand_chain armor (0x000D69) and the
 ApplyHolderOwnedLeashToBone API exist, so the rope can run from the holder's
 hand. False on 1.1.0 (neck only). The armor record is the gate: esm and DLL ship
 together.}
Function Native_Familiarity_SetTier(Actor akActor, String asTier) Global Native
{Store the reputation assessment's familiarity verdict: "stranger" / "passing" /
 "met_once" / "acquainted" / "familiar". The player_familiarity decorator prefers
 it over the conversation-count ladder (hard bonds still set a floor). An unknown
 token is ignored.}

Bool Function Native_IsLeashFrameworkInstalled() Global Native
{Leash Framework (Nexus 187303) present: LeashFramework.dll loaded AND
 Leash.esm in the load order. False = the package-only leash.}

Bool Function Native_IsSkyMessageInstalled() Global Native
{SkyMessage present (SkyrimScripting.MessageBox.dll loaded). Every call into
 SeverActions_SkyMessageLib is gated on it; false = no popup, the caller takes
 its no-selection path.}

Bool Function Venture_Hire(Actor akAssignee, String asJob, String asArrangement) Global Native
{Hire an NPC as a retainer. Job/arrangement are free text (normalized natively). Returns false on unparseable job or if already a retainer.}

Function Venture_PayArrears(Actor akAssignee) Global Native
{Pay a retainer's owed back-wages from the player's gold; clearing it restores good standing.}

Bool Function Venture_ClaimsJailThisWeek(Actor akAssignee) Global Native
{True while this actor's venture already put them in custody this settle week. The off-screen life sim checks it before its own arrest/bounty consequence, so one week cannot land two bounties. False for non-retainers.}

Function Venture_GrantLoan(Actor akAssignee) Global Native
{Grant the loan this retainer asked for - gold leaves the player's purse, a DebtStore entry backs it, and repayment is garnished from THEIR weekly take. No-op if no ask is pending or the player can't afford it.}

Int Function Venture_MigrateCampCuts() Global Native
{Migration: camp Tribute ventures still at the old default cuts move to the new
 ones (Partnership 40 -> 20, Vassalage 60 -> 40); renegotiated cuts are untouched.
 Idempotent. Returns how many moved. Run by SeverActions_Enterprises._MigrateCampCuts
 under the MIGR claim CampCutRetune.}

Function Venture_RefuseLoan(Actor akAssignee) Global Native
{Refuse the loan this retainer asked for. Costs loyalty and starts an ask cooldown. No-op if no ask is pending.}

Function Venture_ForgiveLoan(Actor akAssignee) Global Native
{Write off what this retainer still owes on a loan - clears the balance and the backing DebtStore entry, and buys real loyalty. No-op if they owe nothing.}

Bool Function Venture_Dismiss(Actor akAssignee) Global Native
{End a retainer's service (amicable - no exit theft). Returns false if not a retainer.}

Int Function Venture_Count() Global Native
{Number of venture records, whatever their status.}

Bool Function Venture_IsRetainer(Actor akActor) Global Native
{True if this actor has a venture record, whatever its status (a deserter or a hostile ex-retainer included). See Venture_IsActiveRetainer.}

Actor Function Venture_GetAssigneeAt(Int index) Global Native
{The retainer at an index (0..Venture_Count()-1); the order holds only while the roster is unchanged. None if out of range or not loadable.}

String Function Venture_LetterSubject(Actor akRetainer) Global Native
{Pending courier-letter subject for this retainer ("" if none). Queued by the worklife story gen; pull on the SeverActions_VentureLetter ModEvent.}

String Function Venture_LetterBody(Actor akRetainer) Global Native
{Pending courier-letter body for this retainer ("" if none).}

String Function Venture_LetterReason(Actor akRetainer) Global Native
{Pending courier-letter reason tag for this retainer.}

Function Venture_ClearLetter(Actor akRetainer) Global Native
{Drop the pending courier letter for this retainer (call after dispatching).}

Function Venture_DebugRequestLetter(Actor akRetainer) Global Native
{DEBUG: force an LLM-generated letter from this retainer; a courier goes out when the model returns (the real settle->letter->courier path).}

Bool Function Venture_DebugForceAmbush() Global Native
{DEBUG: force a retainer-grudge ambush now, skipping the delay/cooldown/location gates (an armed grudge, else one armed on a deserter, else any venture entry). Fires SeverActions_VentureAmbush. False only with no venture entries.}

Function Venture_RegisterAmbushThug(Actor akThug) Global Native
{Mark a spawned actor as part of the live ambush standoff, so the is_ambush_thug decorator offers them Stand Down / Attack. Cleared on resolve.}

Function Venture_ClearAmbushThugs() Global Native
{Clear the live-ambush thug roster when the standoff resolves (stood down, attacked or failed).}

String Function Venture_AmbushTaunt(Actor akDeserter) Global Native
{The lead thug's spoken opener: who sent them and why (templated from the deserter's grievance).}

Function Venture_StageThugDirective(Actor akThug, Actor akDeserter) Global Native
{Give a spawned thug a high-importance memory to hold and parley until the player answers, then resolve by stand-down or attack, so they don't swing on the first word.}

Function Venture_Dump() Global Native
{Log a summary of every venture (escrow, purse, arrears, heat, loyalty, status).}

Function Venture_SetEnabled(Bool abEnabled) Global Native
{Enable/disable the autonomous weekly settlement heartbeat.}

; ─── Camp takeover ──────────────────────────────────────────────────────────
; The speaker's camp swears to the player. abViaLeader True: the speaker must be
; the leader. False: one member's consent vote in a leaderless camp; only the vote
; that completes the roll swears (Camp_ConsentTally). True only when the camp
; swore, so an LLM cannot swear a camp while its chief stands there.
Bool Function Camp_Swear(Actor akSpeaker, Bool abViaLeader) Global Native

; The leader of the camp the player is standing in (None if none).
Actor Function Camp_LeaderAtPlayer() Global Native

; Any living member of the camp the player is standing in.
Actor Function Camp_AnyMemberAtPlayer() Global Native

; Let a camp go: closes its books, thaws the respawn freeze and drops it back to wild.
Bool Function Camp_Release(Actor akMember) Global Native

; The chief renounces the oath (hostile Camp_Release): books close, the camp
; reverts to wild and the whole crew turns on the player. Refuses non-leaders.
Bool Function Camp_Renounce(Actor akLeader) Global Native

; 0 wild / 1 leaderless / 2 sworn / -1 not in a camp.
Int Function Camp_State(Actor akMember) Global Native

; Is this actor the leader of their camp?
Bool Function Camp_IsLeader(Actor akActor) Global Native

; ── War-band muster ──────────────────────────────────────────────────────
; Camp ids cross as Int, bit-exact (ESL-range ids come out negative).
Int Function Camp_CampIdOf(Actor akActor) Global Native
Actor[] Function Camp_GetMembers(Int aiCampId) Global Native
; Full roster size, including members whose refs do not resolve right now
; (detached cell); Camp_GetMembers returns only the resolvable ones.
Int Function Camp_RosterCount(Int aiCampId) Global Native
Bool Function Camp_SetMustered(Int aiCampId, Bool abOn) Global Native
Bool Function Camp_IsMustered(Int aiCampId) Global Native
Bool Function Camp_IsSworn(Int aiCampId) Global Native

; True removal of a runtime-added faction membership. RemoveFromFaction only
; writes rank -1, which rank-blind readers (IsInFaction, GetInFaction package
; conditions) still count as membership. Pass only a faction never authored on
; an NPC base (see FactionUtils::RemoveClean). True = something was removed.
Bool Function Faction_RemoveClean(Actor akActor, Faction akFaction) Global Native
; True while akActor is the guard of a live arrest or dispatch; false once their part
; ends (jailing, a release, a cancel), though a jailed prisoner's session still names
; them.
Bool Function Native_ArrestSession_IsGuardOnTask(Actor akActor) Global Native
; True for a player teammate, a rostered follower or a retainer on guard duty: the
; companions the friendly-fire guard keeps from fighting the player or each other.
Bool Function FriendlyFire_IsProtected(Actor akActor) Global Native
; True, once, when the friendly-fire guard caught akActor turning on the player within the
; last afSeconds of real time: the mark is used up.
Bool Function FriendlyFire_TakeForgiven(Actor akActor, Float afSeconds) Global Native
; Records who akActor's SA forced fight is against (ForceAttack), so the friendly-fire guard
; exempts that pair only. Cleared with the forced-combat flag.
Function Native_SetForcedCombatPartner(Actor akActor, Actor akPartner) Global Native
; True while Walk With Me leads akActor (seated in its quest alias now or within 30 s): SA's
; follow upkeep stands down for them. False without Walk With Me.
Bool Function WalkWithMe_Leads(Actor akActor) Global Native
ObjectReference Function Camp_HomeMarker(Int aiCampId) Global Native
Float Function Camp_TravelHoursTo(Actor akMember) Global Native

; Master toggle for camp takeover (the Truce has its own). Off removes the
; takeover actions from eligibility.
Function Camp_SetTakeoverEnabled(Bool abEnabled) Global Native

; Toggle (default on): freeze a camp's encounter zone on takeover so it stops
; repopulating.
Function Camp_SetFreezeRespawn(Bool abEnabled) Global Native

; Master toggle for retainer LOAN requests (raises have their own).
Function Venture_SetLoansEnabled(Bool abEnabled) Global Native

Function Venture_SetStoryCap(Int aiCap) Global Native
{Max work-life vignettes (LLM calls) per settle batch. -1 = Auto (~40% of the active roster, min 1, cap 12); 0 = off (income still settles); 1-12 = fixed. Skipped retainers rotate in later, least-recently-storied first.}

; Global venture-output scaler, 25-300 percent (100 = tuned baseline). Scales
; every venture's weekly production at settle and the board's projection.
Function Venture_SetProductionMult(Int aiPercent) Global Native

; Meet a pending raise ask halfway, in person (the NegotiateTerms action).
; No-op when nothing is pending. Also settles an armed hearing.
Function Venture_NegotiateRaise(Actor akActor) Global Native

Function Venture_SetRaisesEnabled(Bool abEnabled) Global Native
{Master toggle for retainer raise requests. Off = no raise asks, so no refusal skim; the resentment skim follows the Temper toggle.}

Function Venture_SetAmbushesEnabled(Bool abEnabled) Global Native
{Master toggle for retainer grudges: off = a wronged desertion arms no grudge and sends no thugs.}

Function Venture_SetRenownCapEnabled(Bool abEnabled) Global Native
{Master toggle for the Renown roster cap: off = renown and tier still track, but hiring is never capped.}

; ── Stewards ────────────────────────────────────────────────────────────
; One steward per hold (keyed by the hold's crime faction). After each weekly
; settle, the hold's retainer escrow sweeps into the steward's vault (the
; steward keeps a 15% cut of each sweep).

String Function Steward_Appoint(Actor akActor, Int aiWeeklyWage, String asHoldName = "") Global Native
{Appoint a retainer steward of asHoldName ("" = their own hold) and sweep the hold's escrow in now. Returns the hold name, or "" if refused (not a retainer, no hold, seat taken). aiWeeklyWage is stored but no longer drives pay.}

Int Function Steward_Dismiss(Actor akActor) Global Native
{Dismiss this steward: the vault remainder is paid to the player and returned; hold retainers keep their own escrow again. 0 if not a steward.}

Int Function Steward_DismissHold(String asHoldName) Global Native
{Dismiss the named hold's steward (board/UI path). Returns the vault remainder paid to the player; 0 if no steward.}

Int Function Steward_Collect(Actor akActor) Global Native
{Pay the player this steward's whole vault and write the cash-book line. Returns the amount; 0 if not a steward or the vault is empty.}

Int Function Steward_CollectHold(String asHoldName) Global Native
{Collect a hold's steward vault by hold name (board/UI path). Returns the amount paid to the player.}

String Function Steward_HoldNameOf(Actor akActor) Global Native
{The hold this actor stewards ("" if none). Cheap gate for dialogue/UI.}

; ── Steward visits (ai_docs/STEWARD_VISITS.md) ──────────────────────────
; A steward walks out to one of their retainers, lingers a couple of game days
; and goes home. Native picks who and when; SeverActions_Enterprises owns the
; packages.

Function Steward_VisitLegDone(Actor akSteward, Bool abArrived) Global Native
{Report a steward's visit journey. Marshals to the game thread, so arrival comes
 back as the SeverActions_StewardVisitArrived ModEvent (Papyrus then posts the
 anchor + sandbox); false drops the visit. No-op unless that steward is mid-journey.}


; ── The Final Audit's approach (a real journey, not a teleport) ─────────

Function Venture_Audit_TravelLegDone(Bool abArrived) Global Native
{Report the Legate's walk to the player. True hands off to the follow package
 for the last stretch; false stages the detail behind the player, so the
 encounter happens either way. Marshals to the game thread; no-op with no walk
 in flight.}

Bool Function Venture_Audit_IsTraveling() Global Native
{Is the Legate walking to the player under the travel orchestrator? Check it
 before applying the march packages: the follow package (priority 110) outranks
 the traveller alias (106), so the march would stop the walk dead.}

; ── Truce scope ─────────────────────────────────────────────────────────

Function Native_Truce_SetDungeons(Bool abOn) Global Native
{Include outlaws holding a dungeon (barrow, crypt, Dwemer ruin) in the truce.
 False = a dungeon stays a fight. Camps are tagged Dungeon too, but the lair
 keyword is checked first, so a camp never counts. Turning it off releases
 anyone pacified in a dungeon on the next sweep.}

; ── Engine tweaks ───────────────────────────────────────────────────────

Function Sandbox_SetCylinder(Bool abEnabled, Float afHeight) Global Native
{Multi-floor sandboxing: widens the sandbox search cylinder GMSTs (fSandboxCylinderTop/Bottom) so sandboxing NPCs use other floors, at runtime with no ESP override. afHeight = the reach above and below, clamped 150-4096 units. Widen-only, never narrowing another mod's wider value; disabled restores the load order's values.}

; ── Venture: kidnap search, ambush roster ───────────────────────────────
Bool Function Venture_FireKidnapSearch(Actor victim) Global Native
; Fire a search-party standoff for a held captive (event sender = victim; the grudge-ambush machinery, its toggle and global cooldown). True if queued; the caller then marks its once-per-captivity flag.
Bool Function Venture_IsAmbushThug(Actor akActor) Global Native
{True while the actor is a live Venture ambush thug (mutex-guarded set).}

Int Function Venture_AmbushThugCount() Global Native
{How many thugs the live ambush roster holds (transient: 0 right after a load).
 A load-time standoff teardown ends the persuasion window only at 0, so it never
 ends one another owner opened this session (plan R23).}

; ── Camp challenge ─────────────────────────────────────────────────────────
; Entering a WILD camp's interior brings the chief (or nearest outlaw) over to
; ask the player's business, via the SeverActions_CampChallenge ModEvent
; (sender = challenger). Papyrus owns the walk and the card and reports the
; outcome here.

Function Camp_ChallengeAllow() Global Native
{The player talked their way past: the truce holds, and re-entering will not
 re-challenge until they leave the location.}

Function Camp_ChallengeRefuse(String asWhy = "") Global Native
{The challenge failed (refused, lied, walked away, or answered with a blade).
 Breaks the camp's truce on both sides of the door: distance propagation cannot
 cross a cell boundary, but the challenger met the player.}

Function Camp_ChallengeSetEnabled(Bool abEnabled) Global Native
{Master toggle for the challenge encounter.}

Function Camp_ChallengeSetCard(Bool abEnabled) Global Native
{Show the UI card when the challenger arrives. Off by default: the outlaw just
 asks and the player answers in dialogue.}

Bool Function Camp_ChallengeCardEnabled() Global Native

Function Camp_ChallengeSetSeconds(Float afSeconds) Global Native
{Seconds the player has to answer before the challenger gives up (clamped 10-600).}

Float Function Camp_ChallengeGetSeconds() Global Native

Function Camp_ChallengeEngaged() Global Native
{The challenger reached the player: stands the dispatch watchdog down so it does
 not re-send the challenger mid-question.}

Bool Function Camp_ChallengeNoteAttack(Actor akAttacker) Global Native
{An outlaw attacked the player or a teammate during a live challenge. True when
 the attacker is the challenger or a member of the questioned camp: the challenge
 is refused natively (the whole camp breaks) and the caller tears the walk down.}

Bool Function Camp_ChallengeIsPending(Actor akActor) Global Native
{True only for the one outlaw challenging the player and still awaiting an answer
 (the camp_challenge_pending decorator's twin). Use it to drop stale arrival or
 choice events.}

String Function Camp_Name(Actor akMember) Global Native
{Display name of this actor's camp, or "" when they are in no registered camp.}

; ── Challenge card ──────────────────────────────────────────────────────────

Bool Function Magelight_OpenChallengePrompt(Actor akChallenger, String asCampName, Int aiTimeoutMs) Global Native
{Non-pausing card asking how the player answers the challenge. False when the UI
 is unavailable or another view holds focus; the caller then falls back to a
 notification.}

Function Magelight_CloseChallengePrompt() Global Native
Bool Function Magelight_IsChallengePromptOpen() Global Native
Bool Function Magelight_IsChallengePromptAvailable() Global Native

; ─── Chronometer (per-script tick service) ────────────────────────────────
; Replaces RegisterForSingleUpdate on quest 0D62, whose one pending timer is
; shared by every script on the form. Each script owns a unique ModEvent name
; ("SeverActions_Tick_<X>"; registrations are keyed by form and name) AND a
; unique callback name (OnChronoTick_<X>): delivery runs a callback on every
; script of the form that defines it. One slot per name (a re-request replaces
; the pending tick). Pending ticks do not survive save/load (load paths re-arm)
; and are cleared on revert.
Function Chrono_Request(String asEventName, Float afSeconds) Global Native
{Arm (or replace) a one-shot tick: asEventName fires as a senderless ModEvent
 in afSeconds real seconds. Register the handler first or in the same function
 (each script's ChronoArm helper does both).}
Function Chrono_Cancel(String asEventName) Global Native
{Drop a pending tick; no-op when none is pending under that name.}
Int Function Chrono_TickCountSinceLoad(String asEventName) Global Native
{Acknowledged ticks under asEventName since the last load: a fired tick counts
 once the script answers with its own Chrono_Request or Chrono_Cancel. 0 for a
 dropped delivery, an unbound script or a missing DLL. Init's watchdog (K4) reads it.}

; --- Kernel session (plan 3.4 K0, R15) -------------------------------------
Int Function Kernel_AbiVersion() Global Native
{The DLL's kernel ABI number, compared by SeverActions_Init with its own constant.
 0 = no DLL, or a DLL older than the handshake (public 3.9.14); any other mismatch
 = DLL and scripts from different builds. Bump both together.}
Bool Function Kernel_OnSessionStart() Global Native
{Queue the native post-load / new-game task list (settings replay, cosave
 re-seats, load recovery seeds) on the game thread, once per session: a no-op
 after SE's kNewGame; on VR (no kNewGame) Init.OnInit is the only door. True when
 queued now, false when already run or queued. After a kNewGame run it still
 queues the module corroboration, since kNewGame fires before the quest's
 scripts exist.}
Int Function Kernel_SkyrimNetApiVersion() Global Native
{SkyrimNet's PublicAPI version as the DLL resolved it (0 = not loaded). Below v8
 the quest-awareness summaries are off (below v5 the completion memories too),
 and Init shows a notice.}

; --- Module registry (plan 6.2, M-R) ---------------------------------------
; Which modules this install carries, from the FOMOD's marker files
; (SKSE/Plugins/SeverActions/InstallMode.<mode>.json and Modules/<id>.json),
; read at kPostLoad. Legacy or no install-mode marker: every module is
; installed and nothing here changes a gate, the UI or the guard (DR7). Ids are
; the manifest ids, bundles included.
Bool Function Module_IsUsable(String asModuleId) Global Native
{True when the module is Installed in this install (Legacy: every known id;
 Modular: iff its marker is present; hearth: iff hearth.json or
 SeversHearth.esp). False for an unknown id.}
String Function Module_State(String asModuleId) Global Native
{"Installed", "NotSelected", "ScriptMissing", "PresentNotSelected" or
 "Unknown" (an unknown id, or before kPostLoad). ScriptMissing and
 PresentNotSelected come from the session-start corroboration (Modular only).}
String Function Module_Name(String asModuleId) Global Native
{The module's display name ("" for an unknown id).}
String Function Module_Option(String asModuleId) Global Native
{The Modular installer option label to tell the player to re-tick ("" for an
 unknown id).}
Bool Function Module_IsModular() Global Native
{True when the Modular install-mode marker (and only it) is present.}
String[] Function Module_ListInstalled() Global Native
{The ids of every Installed module, in manifest order.}
Function Module_ReportBound(String[] asModuleIds) Global Native
{Init K2 reports the provider ids it found bound this session. Stored only (the
 corroboration probes the quest scripts itself); cleared on revert.}

; --- Migration ledger (plan 3.0 M-H, DR14) ---------------------------------
; Claim, then copy or re-derive, then MarkDone. Claims are per session (cleared
; on revert); done records persist in the 'MIGR' cosave record. A StorageUtil
; sentinel never gates a copy over live data by itself (see AdoptSentinel).
Bool Function Migration_TryClaim(String asName, Int aiVersion) Global Native
{The gate: true once per name per session, false when the migration is
 already done at aiVersion (or later) or already claimed this session, or
 when the name is empty / aiVersion < 1.}
Bool Function Migration_IsDone(String asName, Int aiVersion) Global Native
{True when the migration is recorded done at aiVersion or later.}
Function Migration_MarkDone(String asName, Int aiVersion) Global Native
{Record done at aiVersion (never lowers a later version) and release the
 claim.}
Bool Function Migration_AdoptSentinel(String asName, Int aiVersion, Bool abSentinelDone) Global Native
{Fold a pre-ledger StorageUtil "MigDone" sentinel in as an extra done signal;
 returns the effective done. A set sentinel with no ledger record is adopted
 (recorded done); a ledger record with an unset sentinel is logged loudly and
 stays done. Call before Migration_TryClaim. Empty name or aiVersion < 1: false.}

; --- Script access (plan 6.3, B-38) ----------------------------------------
; Declared properties of a script bound to quest 0x000D62, through the
; ScriptObjectAccess gate (never raw FindBoundObject: a class that failed to
; link answers it with garbage variables). A property whose type tag differs
; from the declared type is refused. A refused script reads as absent: IsBound
; false, Get* the default, Set* false. Callers take script and property names
; from the settings table (SettingsTable.h), never a literal.
Bool Function Script_IsBound(String asScript) Global Native
{True when asScript is bound to quest 0x000D62, its class linked cleanly and
 the object is live; false for an absent or refused script.}
Bool Function Script_GetBool(String asScript, String asProp, Bool abDefault) Global Native
{The declared Bool property's value, or abDefault when the script is refused,
 the property is not declared, or its type tag is not Bool.}
Int Function Script_GetInt(String asScript, String asProp, Int aiDefault) Global Native
{The declared Int property's value, or aiDefault on a refusal (as GetBool).}
Float Function Script_GetFloat(String asScript, String asProp, Float afDefault) Global Native
{The declared Float property's value, or afDefault on a refusal (as GetBool).}
String Function Script_GetString(String asScript, String asProp, String asDefault) Global Native
{The declared String property's value, or asDefault on a refusal (as GetBool).}
Bool Function Script_SetBool(String asScript, String asProp, Bool abValue) Global Native
{Write the declared Bool property; true when written, false on a refusal
 (script absent or refused, property not declared, type tag not Bool).}
Bool Function Script_SetInt(String asScript, String asProp, Int aiValue) Global Native
{Write the declared Int property; true when written, false on a refusal.}
Bool Function Script_SetFloat(String asScript, String asProp, Float afValue) Global Native
{Write the declared Float property; true when written, false on a refusal.}
Bool Function Script_SetString(String asScript, String asProp, String asValue) Global Native
{Write the declared String property; true when written, false on a refusal.}

; --- Settings Authority (plan 3.5 M-S, DR18) -------------------------------
; One per-save value per settings-table row (Native/data/settings_table.json),
; fed by every successful settings write: the settings handler (live and its
; load replay of the global file), Native_SettingsApply / Native_SettingsRecord
; and Settings_Set. A row with no value yet migrates on first read from its
; legacy host property (through ScriptObjectAccess), the global file, or the
; table default. Keys are the table's web keys.
Bool Function Settings_GetBool(String asKey) Global Native
{The row's per-save value; the table default while the row has none (a refused
 host script, a StorageUtil-hosted row before Init K1 seeds it). False, with a
 log warning, for a key the table does not know.}
Int Function Settings_GetInt(String asKey) Global Native
{As Settings_GetBool, for an Int row (0 for an unknown key).}
Float Function Settings_GetFloat(String asKey) Global Native
{As Settings_GetBool, for a Float row (0.0 for an unknown key).}
String Function Settings_GetString(String asKey) Global Native
{As Settings_GetBool, for a String row ("" for an unknown key).}
Function Settings_NoteLegacyWrite(String asKey, String asValue) Global Native
{Tell the Authority the value an MCM handler wrote to a K/M row's host
 property, as the handler's text ("true"/"false", "100", "1.5"). No script calls
 it since the MCM renderer writes through Native_SettingsApply; a call outside the
 MCM fails check 22c. A script's own write is Settings_Set.}
Function Settings_Set(String asKey, String asValue) Global Native
{A script's own per-save write (a one-shot migration, a derived value): the
 Authority row only, no StorageUtil key or global-file record (a player's choice
 goes through Native_SettingsApply / Native_SettingsRecord). The DLL syncs the
 row's legacy host property itself, since some UI still draws from it; the script
 never writes it (check 22c). A prompt-mirror row's mirror follows the feed.}
; The MCM row server (plan 3.0 M-D): SeverActions_MCM draws from
; Native/data/mcm_layout.json (compiled in as McmLayout.h) through these six.
String[] Function Mcm_Pages() Global Native
{"id|labelKey|variantOf" per MCM page, in page order. A variant page (the
 Enterprises debug harness) is listed too; the renderer picks between them.}
String[] Function Mcm_PageRows(String asPageId) Global Native
{One pipe payload per row of the page, in draw order; empty for an unknown page.
 Fields are SeverActions_MCM's ROW_* constants; decode with
 SeverActions_ModuleBase.VerbField, which handles empty fields.}
String[] Function Mcm_MenuOptions(String asListId) Global Native
{The entries of a compile-time menu list (a menu row's menuList); empty for an
 unknown id. A runtime-list menu carries menuSource and the renderer fills it.}
String Function Mcm_Contract(String asKey) Global Native
{One settings key's read/write contract as the tail of a row payload (ten
 fields, ROW_TIER..ROW_CLAMPRULE, re-based to 0); "" when the key is not a drawn
 setting row. For the other half of a clamped min/max pair, which need not be
 on the page.}
String[] Function Mcm_Sources() Global Native
{"id|size|fixed|perSlot|perEntry" per dynamic source. size = entry count when
 fixed, the cap when capped, 0 when unbounded. The renderer reads the cap here so
 it agrees with check 13 (f)'s ceiling report.}
String[] Function Mcm_ModuleRows() Global Native
{"id|option|state" per player-facing module (no support bundles), for the
 Modular-only Modules page: the installer option verbatim and Module_State's word.}

String[] Function Settings_PendingSeeds() Global Native
{K1: the StorageUtil-hosted rows this save has no value for yet, as
 "key|storageKey|type|holder" (holder "quest" = quest 0x000D62, "none" = None).
 Init reads each StorageUtil value and calls Settings_SeedFromStorageUtil.}
Bool Function Settings_SeedFromStorageUtil(String asKey, String asValue) Global Native
{Seed one StorageUtil-hosted row from its per-save copy, only when the row has
 no value and the global settings file has no record for the key (the file's
 replay wins), under the ledger claim "SettingsSeed:<key>". True when taken.}
String[] Function Settings_MirrorRows() Global Native
{The prompt-mirror rows (M-X) of every installed owner, as "key|storageKey|type"
 (a row whose mirror slot is its own seed source waits until settled). Init
 writes each StorageUtil key from the Authority at K1 and on every
 SeverActions_SettingsMirror event.}

; --- Stock & Trade depots --------------------------------------------------
; Per-hold trade stock: 9 depot chests + 9 fence caches in the never-loaded
; SeverActionsDepotCell; merchants and fences restock and sell real items from
; them at the weekly settle. NEVER Activate() a chest: the container menu CTDs
; against that cell (see StockDepots.h). Player access is the Wares panel.
; Index 0-8 is the frozen hold order (Whiterun, Eastmarch, Haafingar, Rift,
; Reach, Hjaalmarch, Pale, Winterhold, Falkreath). Stolen goods sell only
; through the fence cache. No Papyrus caller today.
Int Function Depot_Count() Global Native
{Number of holds with depots (9).}
String Function Depot_HoldName(Int aiIndex) Global Native
{Display name for a depot index ("" out of range).}
ObjectReference Function Depot_GetChest(Int aiIndex, Bool abFence) Global Native
{The hold's depot chest (or fence cache) for native inventory ops only; never
 Activate() it. None out of range.}
Int Function Depot_Value(Int aiIndex, Bool abFence) Global Native
{Sellable value of the hold's stock (legit depots exclude stolen-flagged stacks).}
Int Function Depot_IndexForCrimeFaction(Int aiRuntimeFactionId) Global Native
{Hold index for a runtime crime-faction FormID, -1 if none.}

; ─── Travel ───────────────────────────────────────────────────────────────
Bool Function Travel_SetSpeedByActor(Actor akNPC, Int speed) Global Native
{Change an in-flight journey's speed by actor (works for pool-only journeys),
 re-banding its Traveler_NN alias so the unloaded pace follows. True if a live
 journey was found.}

Bool Function Travel_HasAlias(Int handle) Global Native
{True if the journey holds a Traveler_NN pool alias, whose package drives the unloaded
 leg. False = pool exhausted at Begin. The travel core adds its walk override either way;
 the other journeys (courier, Enterprises, kidnap) add theirs only when false.}

; ─── Ambient Actions (promote half) ───────────────────────────────────────
; See ai_docs/AMBIENT_ACTIONS.md. Pumped by SeverActions_Ambient
; (CheckAmbientAction + OnAmbientActionReady).

Int Function Native_AmbientAction_FireToLLM(Float hearingRadius, Float pairRadius, Int maxCandidates) Global Native
{Queue a scan of nearby non-follower NPCs and the sever_ambient_action_director
 dispatch. Returns 1 once queued, -1 when the custom-prompt API is unavailable. The
 outcome, no candidates included, arrives as SeverActions_AmbientActionReady
 (numArg = IntentKind: 0 none, 1 solo, 2 social). 0/0/0 = native defaults.}

Int Function Native_AmbientAction_GetReadyKind() Global Native
{IntentKind of the pending intent (0 none, 1 solo, 2 social) or 0 if none ready.}

Actor Function Native_AmbientAction_GetInitiator() Global Native
{The NPC who will take the action (None if no intent ready).}

Actor Function Native_AmbientAction_GetAddressee() Global Native
{The NPC the initiator announces to (social intents only; None otherwise).}

String Function Native_AmbientAction_GetActionName() Global Native
{Whitelisted action name, e.g. "TravelToPlace" (empty if none ready).}

String Function Native_AmbientAction_GetDestination() Global Native
{TravelToPlace only: the chosen place name.}

Actor Function Native_AmbientAction_GetTarget() Global Native
{Brawl opponent / give-buy-craft counterparty. None for travel/sit.}

String Function Native_AmbientAction_GetItemName() Global Native
{GiveItem / BuyItem / CookMeal / BrewPotion / CraftItem: the item or recipe name.}

Int Function Native_AmbientAction_GetQuantity() Global Native
{Item count, clamped 1..10 natively.}

Int Function Native_AmbientAction_GetGold() Global Native
{GiveGold amount / BuyItem price, clamped 1..500 natively.}

Bool Function Native_AmbientAction_GetWaitForPlayer() Global Native
{waitForPlayer flag for the travel intent.}

String Function Native_AmbientAction_GetAnnounceEventJson() Global Native
{Pre-built gamemaster_dialogue event JSON for a social intent's announce line
 (empty for solo), for SkyrimNetApi.RegisterEvent. Built in C++ so non-ASCII
 names survive.}

Function Native_AmbientAction_ClearReady() Global Native
{Clear the ready slot; also resets the social gate once it has resolved. Idempotent.}

Int Function Native_AmbientAction_PollGate(Actor akInitiator) Global Native
{Poll the active social gate: 0 pending (keep polling), 1 go (commit the action),
 2 blocked (addressee refused; do not act, memory written), 3 done
 (deferred/aborted/no gate).}

Function Native_AmbientAction_AbortGate(Actor akInitiator) Global Native
{Force-abort the ambient social gate (player interrupt / poll ceiling).}

String Function Native_BuildGMDialogueEventJson(String asSpeaker, String asTarget, String asTopic, String asDirection) Global Native
{UTF-8-safe gamemaster_dialogue event JSON (Papyrus string concat corrupts
 non-ASCII names). asDirection ("" = none) is appended to the topic, because
 SkyrimNet shows the LLM only speaker and topic.}

; ─── Named Travel Markers (ai_docs/NAMED_MARKERS.md) ──────────────────────
Int Function Marker_DropHere(Actor akPlacer, String asName) Global Native
{Place a force-persistent XMarkerHeading at the placer's position and facing,
 scoped to the current location (parent cell fallback), in the cosaved 'MRKR'
 store. "" auto-names "Spot N". Returns the marker id, or 0 (cap of 128, base
 missing, no scope).}

String Function Marker_GetName(Int aiId) Global Native
{The marker's user-facing name ("" = unknown id).}

Bool Function Marker_Rename(Int aiId, String asName) Global Native
{Rename a marker (names clamp to 64 chars; empty refused).}

Bool Function Marker_Delete(Int aiId) Global Native
{Remove the registry row AND disable+delete the placed marker ref.}

Int Function Marker_Count() Global Native
{How many named markers exist.}

String Function Marker_ListJson() Global Native
{JSON array of id/name/ref/loc/cell rows for UI and debugging. Names JSON-escaped.}

Bool Function Travel_ReleaseStaleAliasFor(Actor akActor) Global Native
{If the actor sits in a Traveler_NN pool alias with no live journey (a release
 that gave up), release it now (with retries and quest-bounce escalation) so
 follow or wait can take hold. True when a stale seat was found.}

ObjectReference Function Marker_PickRotationTarget(Actor akNpc, ObjectReference akAnchor) Global Native
{Room rotation: a pseudo-random named marker in the anchor's home (location
 scope, cell fallback), skipping any within 128u of the anchor. None = no other
 markers.}

Bool Function Travel_IsTravelingByActor(Actor akActor) Global Native
{True while the actor has a live journey (any non-terminal state, arrival wait
 included). Gates systems that would fight the travel package, e.g. furniture.}

; ─── The arrival wait (SeverActions_TravelCore) ─────────────────────────
Bool Function Travel_ArmWait(Int handle, Float waitUntilGameTime, Bool waitForPlayer, String placeLabel) Global Native
{Arm a wait on a journey Travel_Begin just returned: on arrival it enters the
 WAITING phase (status "waiting" on SeverActions_TravelComplete) until the player
 comes ("waitdone" via Travel_NotifySpokenTo), waitUntilGameTime passes
 ("waittimeout"; a self-errand's stay ends "stayended") or it is cancelled. The
 five legacy travel aliases pin the waiter. False when the handle is not live.}
Int Function Travel_AdoptWaiting(Actor akActor, ObjectReference akDest, Keyword akKeyword, Float waitUntilGameTime, Bool waitForPlayer, String placeLabel, Int pinAliasId) Global Native
{Adopt an actor already waiting somewhere as a walk-less waiting journey (the
 migration of a legacy slot in its waiting phase). pinAliasId = the legacy alias
 (13..17) holding them, kept as their pin. Returns the handle, 0 when refused.}
Bool Function Travel_HasAliasByActor(Actor akActor) Global Native
{Actor-keyed Travel_HasAlias: the live journey holds a Traveler_NN pool alias.}
Bool Function Travel_SlotHasLiveOwner(Int slot) Global Native
{True when a live journey owns Traveler pool slot 0..23 now. The force-clear
 guard: the same actor's newer journey (a re-route) can hold the seat a cancel
 just freed, so the seated actor alone cannot say whether to empty it.}
Bool Function Travel_NotifySpokenTo(Actor akActor) Global Native
{The player reached a waiting traveler (spoke, or the greet line played): the
 wait ends "waitdone" on the next tick. False when no wait is live.}
Int Function Travel_GetPhaseByActor(Actor akActor) Global Native
{0 = no live journey, 1 = on the road, 2 = waiting at the destination.}
Actor[] Function Travel_GetWaitingActors() Global Native
{Every actor in a live arrival wait (the load-time sandbox re-apply).}
Actor[] Function Travel_GetOrderedJourneyActors() Global Native
{Every actor on a player-ordered journey (armed with a wait), on the road or
 waiting (the MCM's journey list).}
String Function Travel_GetPlaceLabelByActor(Actor akActor) Global Native
{The place label of the actor's live journey ("" when none).}

Int Function Craft_CancelByActor(Actor akActor) Global Native
{Cancel every live crafting session for this actor (travel-start disengage);
 returns how many. TermCancelled still fires, so the Papyrus cleanup runs.}

Bool Function Venture_SyncPremisesFromWork(Actor akActor, ObjectReference akMarker) Global Native
{The only premises writer: the owned-property cell holding the retainer's work
 marker becomes the premises; any other spot (or None = work cleared) detaches
 it. No-op for non-retainers.}

Bool Function Magelight_IsMenuOpen() Global Native
{True while the SeverActions config view is open. It is not engine menu mode
 (Utility.IsInMenuMode() stays false with pause-on-open off), so input handlers
 must gate on this.}

; == The Imperial Final Audit ==================================================

String Function Venture_Audit_State() Global Native
{Audit state token: "" (dormant), "casebuilding", "approaching", "demanding",
 "paid", "refused", or "dead". Mirrors the tax_audit_state decorator.}

Int Function Venture_Audit_Demand() Global Native
{The gold demanded: 40% of the purse the player carried when the case opened,
 clamped to Int.}

Bool Function Venture_Audit_IsCollector(Actor akActor) Global Native
{True for the Treasury's three collectors (gates the follow-refusal guards;
 mirrors the is_tax_collector decorator).}

Bool Function Venture_IsActiveRetainer(Actor akActor) Global Native
{True for a retainer still in service (not deserted or hostile), unlike
 Venture_IsRetainer, which counts any record. Gates HireRetainer and AssignWork's
 assign-retainer popup; the RetainerPersist sweep frees a seated alias on false.}

; ── Combat-gear yield ─────────────────────────────────────────────────────────

Bool Function Native_Outfit_RecordExternalChange(Actor akActor, Form akItem, Bool abIsUnequip) Global Native
{Record an external outfit change for burst detection and classify it for the
 combat-gear yield (a pure helm/shield-slot unequip?). Pass UNEQUIPS only: every
 call counts toward the 3-in-500 ms burst latch, and the alias notes equip
 intrusions itself. True while burst-strip suppression is active. Replaces
 Native_Outfit_RecordExternalUnequip.}

Bool Function Native_Outfit_ShouldYieldCombatGear(Actor akActor) Global Native
{True when outfit enforcement should yield this debounce round: the yield
 setting is on, the actor is out of combat, and the settled burst was only
 helm/shield unequips (a mod such as FollowerLivePackage taking gear off between
 fights). Consumes the burst's classification: ask once per debounce.}

Bool Function Native_Outfit_IsSystemEnabled() Global Native
{The outfit system master switch (key outfitSystemEnabled). False = SeverActions
 dresses nobody, and every enforcement path must early-out on it. The Papyrus face
 of the atomic the decorator and SituationMonitor read.}

Bool Function Venture_Audit_Collect() Global Native
{Atomically latch the audit PAID and send the detail home. Call it first and
 take the gold only on true; false = not demanding, or another call won.}

Bool Function Venture_Audit_Refuse() Global Native
{Latch the audit REFUSED (terminal); Papyrus starts the fight. False unless the
 audit was demanding.}

Actor Function Venture_Audit_Collector(Int aiIndex) Global Native
{The placed collector ref: 0 = Legate Cassius, 1 = Livia, 2 = Drusilla. None if
 it cannot be resolved from SeverActions.esp.}

Function Native_SettingsRecord(String asPage, String asKey, String asValue) Global Native
{Record a value into the global settings file under the settings handler's
 page/key (feeding the Authority too). The file is replayed on load and wins, so
 a property write without this reverts on the next load. Native_SettingsApply
 includes it.}
String Function Native_SettingsGetValue(String asKey, String asDefault) Global Native
{The global settings file's value for asKey, or asDefault when it has no record.
 Lets a load-time restore of a per-save copy defer to the file (which the replay
 applies and which always wins), in either run order.}
Function Native_ClearSAFollowOwnership(Actor akActor) Global Native
{Release SA's claim on this follower (clears hasFollowPkg and isSandboxing in
 the cosave). hasFollowPkg must be false for track-only followers: CellCatchup
 and FollowDriftMonitor use it to drag an actor through doors and re-assert
 follow. Papyrus decides track-only; this applies it.}

Bool Function Native_IsNFFManaged(Actor akActor) Global Native
{True when NFF holds this actor in a running alias of the vanilla DialogueFollower
 quest (0x0750BA, which NFF overrides), i.e. NFF owns them. Factions cannot tell:
 NFF stamps the vanilla CurrentFollowerFaction our own follower tests read.
 Always false without NFF.}

Bool Function Native_WasEverFollower(Actor akActor) Global Native
{True iff the actor is or ever was a registered companion (roster flag or the
 sticky FLWD everFollower bit). False for rows made only by travel, forced
 combat, casual follow or a home/work spot. The returning-vs-first-recruit test;
 Native_HasFollowerData is not.}

Int Function Sched_AliasIndexIn(Actor akActor, Quest akQuest) Global Native
{The alias ID akActor is seated in for akQuest, from the engine's own record,
 or -1. Lets the schedule pools reclaim a seat whose recorded index was lost
 (EmptySchedAlias releases by index) without a Papyrus alias scan. Read-only.}

Bool Function Native_IsNFFInstalled() Global Native
{TRUE when nwsFollowerFramework.esp is in the load order.}

; == Follower ownership - the single source of truth =========================
; 0 None | 1 SeverActions | 2 NFF | 3 DLC (Serana) | 4 CustomAI | 5 Vanilla
Int Function Native_GetFollowerOwner(Actor akActor) Global Native
{Who owns this follower's AI, computed fresh from every signal (NFF alias seat,
 Serana, custom-AI keyword / NFF ignore token / curated list, our store flags,
 CurrentFollowerFaction). A framework's claim outranks our own flags, which go
 stale. Ask this instead of re-deriving ownership from single flags.}

String Function Native_GetFollowerOwnerName(Actor akActor) Global Native
{Native_GetFollowerOwner's verdict as a token for logs: "None", "SeverActions",
 "NFF", "DLC", "CustomAI", "Vanilla".}

Bool Function Native_IsTrackOnlyFollower(Actor akActor) Global Native
{The track-only safety gate (plan 3.1 C): true when NFF (2), the DLC (3) or a
 custom AI (4) drives this actor, so SA must never apply its own packages. Every
 gate reads this, never a FollowerManager cast (None without the Followers
 module, which would read false). Ownership only: Tracking mode is not folded in (home, work and schedule fills
 stay live under it, D45); the follow / wait sites read
 SeverActions_ModuleBase.IsFollowHandsOff (this OR the mode).}

Int Function Native_HydrateFollowerSystem_RebuildOpinions() Global Native
{Only the FollowerSystemHydrator's opinions pass: rebuild every rostered
 follower's companionOpinions string from the pair store. For mid-session
 callers (recruit, NFF adopt batch, an inter-follower assessment reply);
 Native_HydrateFollowerSystem_Run is load-only, since it also re-applies essential
 and combat-style values that would stomp a brawl's or yield's temporary ones.
 Returns the number rebuilt.}

String Function Camp_ConsentTally(Actor akActor) Global Native
{"have/needed" for a leaderless camp's consent roll (e.g. "2/3"), or "" when the
 camp has a living chief, has sworn, or the actor is in no camp.}

; ── Schedule tick pre-filter (ScheduleTickFilter.h) ──────────────────────────
; Return only the actors the 30s FollowerManager schedule pass must touch. The
; filter never decides anything: it can only prove "nothing to do" and omit, so
; anything it cannot see is returned and the Papyrus reconcile runs with every
; guard. Results are sorted by FormID so the caller's chunk cursor is stable.

Actor[] Function Sched_GetTransitionDue(Float afGameHour, Float afWorkStart, Float afWorkEnd, Float afPlayStart, Float afPlayEnd) Global Native
{Every NPC due this pass: a home/work/relax transition (a relax-only NPC included), a registered follower still
 holding a schedule alias, an on-shift guard due its reinforce, an orphaned alias hold, or a held NPC in a hold the
 schedule yields to (Sched_HoldYield). The caller passes the four schedule window rows it reads with
 Settings_GetFloat; per-NPC work-hour overrides are read natively, as DetermineScheduleTypeFor
 applies them. Alias system only (Route B keys on KEY_LAST_SCHEDULED_TYPE):
 gate on SchedSystemActive().}

Actor[] Function Sched_GetSceneSuspendMismatched() Global Native
{Homed, 3D-loaded NPCs whose live scene state disagrees with the cosaved
 home-scene-suspend flag (all CheckSceneSuspendedHomes can act on; usually
 empty). Flagged actors whose home was cleared are included, so a suspend can
 always be undone.}

; The schedule's other natives, not filters: Sched_HoldYield and Sched_GetAssignedRows (ScheduleTickFilter.h),
; Sched_NoteHold (HomeSandboxVerifier.h).

Int Function Sched_HoldYield(Actor akActor) Global Native
{Which other hold the schedule gives way to: 0 none, 1 crafting (CrafterAlias 3 or CrafterApproachAlias 6 of quest
 0x000D62), 2 a spell cast (SpellCastCaster aliases 124-127), 3 a Levy patrol (quest 0x16AC46), 4 Walk With Me leads
 them, 5 a SexLab or OStim scene. The schedule quests outrank each of these. Read-only.}

Int Function Sched_NoteHold(Actor akActor, Int aiReason) Global Native
{Records why the schedule holds nothing on akActor (FollowerManager's SCHED_HOLD_* codes; 0 drops the note) for the
 Assigned NPCs card. Returns the previous code (0 when none). Not saved: cleared on revert.}

Actor[] Function Sched_GetAssignedRows() Global Native
{Every living actor whose row holds a home, a work spot or a relax spot, follower or not, sorted by FormID.}

; --- Intimacy gates ----------------------------------------------------------
; Main tracks no intimate history (that is the NSFW sibling's
; SexualHistoryStore); these gates back the 0046 consent section and the
; persona/trade decorators.

Function Native_IntimateHistory_SetEnabled(Bool abEnabled) Global Native
{Live-apply the intimacy master toggle to the native gate; records nothing. The
 settings handler (and so the MCM row) applies it itself.}

Function Native_IntimateHistory_SetGenderGate(Int aiGate) Global Native
{Live-apply the surfacing gender gate (0 everyone, 1 women only, 2 men only);
 records nothing, as SetEnabled.}

String Function Native_ClosestInventoryNames(Actor akActor, String asQuery, Int aiMaxCount) Global Native
{Comma-joined names of akActor's items that fuzzy-match asQuery, best first, at
 most aiMaxCount ("" for none). The BuyItem/SellItem failure event tells the LLM
 what the seller carries, since on localized games it often names the English item.}

; ── Debt confirm prompt (non-pausing overlay) ───────────────────────────────
; Replaces a SkyMessage modal, which does not render while the dialogue menu is
; up. The choice returns as the SeverActions_DebtChoice ModEvent (strArg =
; accept|deny|denySilent, numArg = amount, sender = the NPC counterparty).

Bool Function Magelight_OpenDebtPrompt(Actor akCounterparty, Int aiAmount, String asReason, Int aiDueDays, Int aiCreditLimit, Bool abPlayerIsCreditor, Int aiTimeoutMs) Global Native
; The same card for CreateRecurringDebt / ForgiveDebt / AddToDebt: asMode =
; recurring|forgive|add (anything else = the CreateDebt card). aiDays = interval
; (recurring) else 0; aiCurrentAmount = the total before the charge (add) else 0.
; Same DebtChoice event; the caller remembers which operation it opened.
Bool Function Magelight_OpenDebtPromptMode(Actor akCounterparty, String asMode, Int aiAmount, String asReason, Int aiDays, Int aiCreditLimit, Int aiCurrentAmount, Bool abPlayerIsCreditor, Int aiTimeoutMs) Global Native
Function Magelight_CloseDebtPrompt() Global Native
Bool Function Magelight_IsDebtPromptOpen() Global Native
Bool Function Magelight_IsDebtPromptAvailable() Global Native

; ── Bio Blocks: MCM apply / faction-rule surface (for VR) ───────────────────
; Authoring stays in the UI/JSON; these apply existing blocks to the crosshair
; target and manage faction rules. Titles[] and Ids[] are parallel arrays.
String[] Function Native_BioBlock_TabList() Global Native
String[] Function Native_BioBlock_BlockTitlesInTab(String tab) Global Native
Int[] Function Native_BioBlock_BlockIdsInTab(String tab) Global Native
Bool Function Native_BioBlock_Apply(Actor akActor, Int blockId) Global Native
Bool Function Native_BioBlock_Unapply(Actor akActor, Int blockId) Global Native
String[] Function Native_BioBlock_AssignedTitles(Actor akActor) Global Native
Int[] Function Native_BioBlock_AssignedIds(Actor akActor) Global Native
String[] Function Native_BioBlock_TargetFactionNames(Actor akActor) Global Native
Bool Function Native_BioBlock_GrantTargetFaction(Actor akActor, Int factionIndex, Int blockId) Global Native
String[] Function Native_BioBlock_FactionRuleNames() Global Native
Bool Function Native_BioBlock_RemoveFactionRule(Int index) Global Native

; ── Bio Blocks PUBLIC API v1 ──
; For other mods. Frozen: these signatures never change and are never removed (fomod/public_api.json).
; A block is named by KEY, "<author>.<mod>:<local>" in a-z 0-9 _ - (the local part may use dots too), e.g.
; "jdoe.grumpyguards:grumpy"; "severause.severactions:*" is reserved.
; Recipe, rules and caveats: Data/SKSE/Plugins/SeverActions/API/BIO_BLOCKS_API.md.
; The API version: 1. An older SeverActions has no such native (the call fails and returns 0).
Int Function BioApi_Version() Global Native
; Create or update the keyed block; call it on every load (an unchanged call writes nothing). Title and content are
; the provider's; asTab applies only when the block is created. False when refused (a malformed or reserved key, an
; empty title, a '{' in the title or content) or when the player deleted this block.
Bool Function BioApi_Define(String asKey, String asTitle, String asContent, String asTab) Global Native
; True while a block with this key is in the player's library.
Bool Function BioApi_Exists(String asKey) Global Native
; Apply the keyed block to an NPC; already applied is True, an unknown or deleted key False. Apply ONCE, on your own
; event, never on every load: the player may remove it from that NPC.
Bool Function BioApi_Apply(Actor akActor, String asKey) Global Native
; Remove the keyed block from an NPC. False when the key is unknown or the block was not applied to them.
Bool Function BioApi_Unapply(Actor akActor, String asKey) Global Native
; True when the keyed block is applied to this NPC (a faction rule's grant does not count).
Bool Function BioApi_IsApplied(Actor akActor, String asKey) Global Native

; Custom-AI override: classify an NPC as a normal follower even when the curated
; custom-AI list matches them. Cosaved in 'CAIO', so the owner verdict is right
; from kPostLoadGame; FollowerManager mirrors changes into its StorageUtil list
; and pushes back any listed actor the record lacks on every load.
Function Native_SetCustomAIOverride(Actor akActor, Bool abForceNormal) Global Native
Bool Function Native_HasCustomAIOverride(Actor akActor) Global Native
; Init K1's one-time seed of 'CAIO' from the StorageUtil list, add only, under the
; migration claim "CustomAIOverrideSeed". True when the actor was not in it yet.
Bool Function CustomAI_SeedOverride(Actor akActor) Global Native
; True when a custom-AI follower shows a positive dismiss signal (vanilla
; DismissedFollowerFaction, WaitingForPlayer = -1, or any *dismiss*-named
; faction), as opposed to a transient behaviour flip. Both untrack paths use it.
Bool Function Native_IsCustomFollowerDismissed(Actor akActor) Global Native

; Actors currently wearing a slot preset (the slot registry, replacing the
; legacy lock registry).
Actor[] Function Native_OutfitSlot_GetActorsWithActivePreset() Global Native

; Hold the active slot preset after an ad-hoc per-item change (Equip/
; UnequipMultipleItems). It stays active, its pieces stay on and every teardown
; still reclaims its catalog copies, but nothing re-applies it (the OutfitAlias,
; the 3D-load re-equip) until the next apply, clear or GetDressed re-apply.
; False when there is no active slot preset.
Bool Function Native_OutfitSlot_HoldActivePreset(Actor akActor) Global Native

; True while the active slot preset is held. An older DLL leaves it unbound,
; which reads False (enforce).
Bool Function Native_OutfitSlot_IsActivePresetHeld(Actor akActor) Global Native

; Release the DefaultOutfit a lock, Undress or slot preset parked: restore it
; onto the base when nothing holds the suppression any more and forget the
; parking, so the load pass stops re-nulling the base. False while a legacy lock
; or slot preset is active. Call where the parking's owner ends (Dress's stash
; branch, ClearPreset, deleting the active preset).
Bool Function Native_Outfit_ReleaseDefaultOutfitSuppression(Actor akActor) Global Native

; Resume after a native apply or synchronous equip loop: drops the hard suspend
; and the watchdog like Native_Outfit_ResumeLock, then keeps the actor suspended
; for exactly aiMs ms (0 = 2000), so the OutfitAlias events still queued for the
; op's own strips and equips are not counted as external changes. For an op
; whose equips have settled, use Native_Outfit_ResumeLock.
Function Native_Outfit_ResumeLockKeepGrace(Actor akActor, Int aiMs) Global Native

; Forget the situation monitor's tracked situation for akActor, so the next scan
; sees a change and a rule for the situation they are already in applies at once.
Function SituationMonitor_ResetActorSituation(Actor akActor) Global Native

; A wait took akActor over from the safe-interior relax: the monitor keeps the
; visit's claim but yields it, so neither its exit nor a rescue moves them.
Function SituationMonitor_YieldSafeInterior(Actor akActor) Global Native

; Owned suspend for a long outfit op (BuildPreset, ApplyPresetBySlot,
; ClearPreset): the Native_Outfit_SuspendLock watchdog (5 min), plus an owner.
; While live, the untokened resumes (Native_Outfit_ResumeLock, ResumeLockKeepGrace)
; leave the actor suspended; only Native_Outfit_ResumeLockOwned with this token,
; or the watchdog, ends it. A nested SuspendLock only lengthens the deadline.
; Returns the token; 0 = an older DLL without owners (pair plain Suspend/Resume).
; Used by SeverActions_OutfitSlot's _BeginOwnedOutfitOp / _EndOwnedOutfitOp.
Int Function Native_Outfit_SuspendLockOwned(Actor akActor) Global Native

; End the owned suspend for aiToken: drops owner, hard suspend and watchdog, and
; leaves a grace of aiGraceMs ms (0 = none; 2000 after equips, as
; ResumeLockKeepGrace). False, changing nothing, when another token owns the actor.
; Token 0 is the untokened resume and is refused while any op owns the actor.
Bool Function Native_Outfit_ResumeLockOwned(Actor akActor, Int aiToken, Int aiGraceMs) Global Native

; The OR of the slot masks of every worn piece outfit enforcement leaves alone
; (a blacklisted piece or a Devious Device). A Papyrus re-equip must skip an item
; whose Armor.GetSlotMask() overlaps it, as the native cell-load pass does, or
; the engine strips the protected piece to make room. 0 when none (or an older DLL).
Int Function Native_Outfit_WornProtectedSlotMask(Actor akActor) Global Native

; The MCM Economy page's debt lines (D34): one per resolvable debt between the
; player and a counterparty, in store order, "Name: <amount>g" plus
; " (rate, reason, due)" when any is set. True = debts owed to the player, false =
; debts the player owes. Uses DebtStore's formatters, as the World page does.
; Empty on an older DLL.
String[] Function Native_Debt_GetPlayerViewLines(Bool abPlayerIsCreditor) Global Native

; The survival word for a 0-100 need value (D34), matching SeverActions_Survival's
; Get<Need>LevelName word for word (thresholds 25/50/75). aiNeedType 0 hunger,
; 1 fatigue, else cold. "" on an older DLL.
String Function Native_Survival_GetSeverityLabel(Int aiNeedType, Int aiValue) Global Native

; Quick wheel (QuickWheelBridge), the only wheel (D8). The DLL owns the key/chord
; and routes a pick through HotkeySink (SeverActions_Hotkey_<Name>, strArg
; wheel:<id>). Wheel_IsNative: a UI host is present and the wheel view exists;
; false = the key shows the not-installed notice.
Bool Function Wheel_IsNative() Global Native
; Push a wheel key (DX scancode, -1 = none) to the sink and record it in the
; global settings file. No script caller (a rebind is the settings handler's
; keybind apply); kept for an older pex.
Function Wheel_SetKey(Int dxScanCode) Global Native
; Load-time sync: returns the key in force, the global file's when it holds one,
; else the save's (then recorded). Never 0, so 0 = an older DLL. The DLL now runs
; this itself at session start (KernelSession); kept for an older pex.
Int Function Wheel_SyncKey(Int savedKey) Global Native
; The config-menu key's load-time sync: same contract, same native caller, kept
; for an older pex.
Int Function Magelight_SyncMenuKey(Int savedKey, Bool savedShift) Global Native
Bool Function Magelight_GetMenuKeyShift() Global Native
; Open (or close) the wheel now, as the key/chord does.
Function Wheel_Open() Global Native

Actor Function Native_GetLastDialoguePartner() Global Native
{The player's most recent dialogue partner, or None: the last vanilla Dialogue
 Menu partner or the last NPC to speak to the player through SkyrimNet,
 whichever came later. Never the player. Backs hotkey target mode "Last Talked
 To" (DialoguePartnerTracker.h).}

; Write a setting through the settings handler, applying it live (a VR chord
; rebinds at once) and recording it. Native_SettingsRecord only records. Queued
; to the game thread; asValue goes into JSON unescaped (numbers, bools, simple
; words only).
Function Native_SettingsApply(String asPage, String asKey, String asValue) Global Native
; The VR chords as the DLL holds them (Magelight button codes: 1 B/Y, 2 Grip,
; 7 A/X, 32 stick click, 33 trigger, 35 touchpad; 0 = no modifier).
; asWhich: menuButton / menuModifier / menuHand / wheelButton / wheelModifier /
; wheelHand (hand: 0 either, 1 left, 2 right); -1 for any other asWhich.
Int Function Native_GetVRChord(String asWhich) Global Native
; True on Skyrim VR - gates the MCM's controller-chord section.
Bool Function Native_IsVRRuntime() Global Native
; The game's language (Skyrim.ini sLanguage: ENGLISH, FRENCH, GERMAN, ITALIAN,
; SPANISH, RUSSIAN, POLISH, CZECH, JAPANESE, CHINESE), the value SkyUI uses to
; pick Interface/Translations/SeverActions_<language>.txt. ENGLISH when unset.
String Function Native_GetGameLanguage() Global Native

; String localization (SeverActions_L10n.json) for notification / MessageBox /
; HUD text SkyUI translation files cannot reach. Resolves game language ->
; English -> the key. Native_L10nFmt fills {0}/{1} ("" for unused).
String Function Native_L10n(String asKey) Global Native
String Function Native_L10nFmt(String asKey, String asArg0 = "", String asArg1 = "") Global Native
; ── Instance-aware inventory ──────────────────────────────────────────────
; A base FormID does not identify an item: enchanting, tempering and renaming
; live on the instance (ExtraEnchantment / ExtraHealth / ExtraTextDisplayData).
; Deciding an item's fate by FormID decides it for the player's own piece too.

Bool Function StackHasPlayerWork(Actor akActor, Form akItem) Global Native
{True when the actor holds a copy of akItem the player enchanted, tempered or
 renamed. Ask before removing or overwriting an item chosen by FormID.}

Int Function CountPlainCopies(Actor akActor, Form akItem) Global Native
{How many of the actor's copies of akItem are not player-modified (safe to take).}

Int Function RemovePlainCopies(Actor akActor, Form akItem, Int aiCount, ObjectReference akDest = None) Global Native
{Remove up to aiCount unmodified copies, never a player-modified one; returns how
 many went. akDest None destroys them, else moves them there. Use instead of
 Actor.RemoveItem for any item picked by FormID (RemoveItem cannot pick the stack).}

String Function GetCustomItemName(Actor akActor, Form akItem) Global Native
{The name the player gave their copy of akItem at an enchanting table, or "".
 Callers fall back to the base form's name.}

; ── Hearth's base (the persistent command camp) on the Survival page ──────
; The second camp slot's twins of Magelight_SetCampStatus / SetCampMeta, called
; by SeversHearth_Camp.psc; tier 1 bivouac / 2 encampment / 3 command.
Function Magelight_SetBaseStatus(Bool active, String location, Int tier, Int occupants) Global Native
Function Magelight_SetBaseMeta(Float hoursEstablished, Float distanceUnits) Global Native
Function Magelight_SetBaseBeds(Int bedrolls) Global Native
; Hearth mirrors its cosaved tent/banner skin here for the Settings page:
; 0 auto (follows the civil war), 1 Nord, 2 Imperial.
Function Magelight_SetCampFactionSkin(Int skin) Global Native
; Hearth's camp kit for the Survival page's camp card: 0 a full camp, 1 small, 2 small and indoors.
Function Magelight_SetCampKit(Int kit) Global Native

; ── LLM relays ──

Bool Function Native_LLM_DispatchRelationshipAssess(Actor akActor, String modEventName) Global Native
{Native_LLM_Dispatch for sever_relationship_assess with the context built in
 C++ (FormID, trimmed social graph and relationship memories, capped). The
 reply arrives as a ModEvent named modEventName. False when refused (no
 bridge, master toggle off, prompt missing).}

; --- Kernel natives (plan 6.3: M-J JSON, M-G LLM lanes, M-T travel, M-W follow pool, M-K hotkey codes) ---
Int Function Json_GetInt(String asJson, String asPointer) Global Native
{The integer at a JSON pointer ("/eid", "/pairs/0/affinity"; a bare key means "/key").
 Strict when the text parses; for a malformed LLM reply, a substring search: the
 pointer's last key, the N-th occurrence for an array index, the value up to the
 next comma or closing brace. 0 when absent.}
Float Function Json_GetFloat(String asJson, String asPointer) Global Native
{The number at a JSON pointer, same rules; 0.0 when absent.}
String Function Json_GetString(String asJson, String asPointer) Global Native
{The string at a JSON pointer (a number or bool as its text, a container as its
 JSON), same rules; the tolerant mode decodes \" \\ \/ and keeps other escapes
 verbatim. "" when absent.}
Int Function Json_ArrayCount(String asJson, String asPointer) Global Native
{The element count of the array (or member count of the object) at a JSON
 pointer ("" = the root). 0 when absent.}
Bool Function LLMLane_TryClaim(String asLane, Float afTtlSeconds) Global Native
{Claim a named in-flight lane for one class of LLM call (M-G); false while a
 live claim holds it. The claim expires after the TTL on a steady clock (0 =
 300 s, capped at an hour) and every lane clears on revert. Release when the
 reply lands.}
Bool Function LLMLane_Release(String asLane) Global Native
{Release a lane; false when it was not held (already released or expired).}
Bool Function LLMLane_IsHeld(String asLane) Global Native
{True while a live claim holds the lane: a tick gate's read before firing,
 without claiming.}
String Function Native_GetTravelState(Actor akActor) Global Native
{The travel state Native_SetTravelState recorded ("traveling", "waiting",
 "complete", "timeout"; "" when not traveling). Scripts read this, not the
 SeverTravel_State StorageUtil key (prompts still read that key).}
Int Function FollowPool_Claim(Actor akActor, String asOwner) Global Native
{Claim an alias index of the 200-alias follow pool (quest 0x0016A78D) under an
 owner tag ("follow", "camp"): the actor's own claim, else an alias the actor
 already fills, else the first alias unclaimed and unfilled. -1 when exhausted.
 The caller fills the alias (ForceRefTo) and releases the claim when it clears it.}
Bool Function FollowPool_Release(Int aiIndex) Global Native
{Release the claim on an alias index; false when none was held.}
String Function FollowPool_OwnerOf(Int aiIndex) Global Native
{The owner tag of the claim on an alias index, "" when free.}
Int Function Hotkey_GetCode(String asId) Global Native
{The bound DirectInput code of a hotkey id (an int keybind row of the settings
 table: FollowToggleKey ... SetupSmallCampKey ... TieUntieKey, ConfigMenuKey, WheelMenuKey), read
 from the Settings Authority; -1 when unbound or not an int keybind row.}
Bool Function Hotkey_SetCode(String asId, Int aiCode) Global Native
{Bind a hotkey id to a code (<= 0 unbinds): queued to the settings handler's
 keybind apply on the game thread, which writes the MCM display property and the
 Authority, as a web rebind does (per save, not in the global file). False for an
 unknown id.}
Int[] Function Hotkey_BoundCodes() Global Native
{The distinct bound codes over every int keybind row, ascending (diagnostics).}
Bool Function Hotkey_SinkInstalled() Global Native
{Is the DLL's InputEvent sink registered on the device manager? It is what makes
 the hotkeys work (the MCM's Hotkey System line). False early in a load (taken at
 kDataLoaded, retried at session start) or with no input device manager yet.}
String Function Hotkey_AbsentModule(String asHotkeyId) Global Native
{The player-facing module id whose absence refuses the hotkey (never a support
 bundle); "" when met, outside Modular, or for an id that is not a hotkey.}
Bool Function Verb_Send(String asModule, String asActionId, String asArgs, Form akSender) Global Native
{The one verb encoder for Papyrus callers (M-V): the DLL looks actionId up in
 its verb table and sends the owning module's SeverActions_Verb_<Name> ModEvent
 (or runs a native row). asModule is cross-checked (the table decides; a
 mismatch logs). asArgs is the 7-field pipe tail after the actionId:
 target|target2|str|int|str2|targetFid|target2Fid (FormIDs signed decimal, ""
 and 0 allowed); akSender is the primary target when known. False for an unknown
 verb, a refused module (Modular only) or a native row with no resolvable target.}
Function Native_Persuasion_EndFor(Actor akGuard) Global Native
{End akGuard's persuasion window only (see SeverActionsNative.Native_Persuasion_Begin).
 Idempotent; None is a no-op.}

; ── Furniture occupancy (FurnitureOccupancy.h) ─────────────────────────────
ObjectReference Function Furniture_SeatFor(Actor akActor, ObjectReference akFurniture, Float afRedirectRadius) Global Native
{akFurniture when it has a place for akActor (a free marker, or one akActor already holds or is
 heading to), else the nearest furniture of the same kind with a place within afRedirectRadius of
 it (0 = no redirect), else None. None too for a ref that is not furniture.}
