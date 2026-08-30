Scriptname SeverActionsNativeExt2 Hidden
{Second extension class for SeverActions native Papyrus exports — the
 Enterprises (Venture_*) natives and later native batches.

 Why a THIRD class: the same hard ~511-function-per-script VM cap that
 spawned SeverActionsNativeExt. Ext itself crossed the cap (512
 declarations) and native lookups broke class-wide at runtime (e.g.
 Native_GetIsFollower erroring, followers unrecognized). New native
 batches register on this class now. Keep the C++ registration's
 script name in sync with this class.}

; ── Enterprises (off-screen labor/economy) ──────────────────────────────────
; See ENTERPRISES.md.

; ── Hold taxes (P1) ─────────────────────────────────────────────────────────
Bool Function Native_GetLLMCallsEnabled() Global Native
{Background-AI master toggle state (llmCallsEnabled): true = SeverActions makes its
 background LLM calls (assessments, banter, stories, letters, quest summaries,
 intimacy read). Does NOT touch SkyrimNet's own dialogue.}

Function Native_SetLLMCallsEnabled(Bool abEnabled) Global Native
{Flip the Background-AI master toggle live. The MCM also records it to the global
 settings file so PrismaUI + the load replay agree.}

Bool Function Native_GetFollowersCanTravel() Global Native
{Followers-can-travel toggle state: true = the player's followers may use the LLM
 TravelToPlace action; false (default) = they're blocked from it (non-followers
 always travel). Read by the sever_travel_allowed decorator.}

Function Native_SetFollowersCanTravel(Bool abEnabled) Global Native
{Flip the followers-can-travel toggle live. The MCM also records it to the global
 settings file so PrismaUI + the load replay agree.}

Function Venture_SetTaxEnabled(Bool abEnabled) Global Native
{Master toggle for hold taxes on weekly enterprise income.}

Function Venture_SetTaxMult(Int aiPercent) Global Native
{Scale on the tax brackets, 0-200 (100 = baseline 5/10/15%).}

Int Function Venture_AdjustHoldTaxForJarl(Actor akJarl, Int aiDeltaPct) Global Native
{Jarl petition: shift the jarl's own hold's tax by aiDeltaPct points
 (accumulated adjust clamped -15..+25). Returns the new representative
 rate for narration, or -1 if the actor has no crime faction.}

Int Function Venture_GetHoldTaxForJarl(Actor akJarl) Global Native
{Current representative tax rate for the jarl's hold (-1 = no crime faction).}

Function Venture_DebugAdd(Actor akAssignee, Int job, Int arrangement, Int wageWeekly) Global Native
{Hire a test retainer. job: 0 Miner 1 Merchant 2 Alchemist 3 Farmer 4 Fence 5 Mercenary 6 Courtesan 7 Guard 8 Lumberjack 9 Custom 10 Blacksmith 11 Hunter 12 Brewer 13 Tanner. \
arrangement: 0 Employed 1 Partnership 2 Vassalage (coerced) 3 Sworn. wageWeekly applies to Employed/Sworn.}

Function Venture_DebugRemove(Actor akAssignee) Global Native
{Remove a retainer (debug cleanup / re-hire).}

Function Venture_ForceSettle() Global Native
{Force every active venture due and run a settlement pass now (logs each step).}

Function Venture_Collect(Actor akAssignee) Global Native
{Grant one retainer's pending escrow (gold + goods) to the player and clear it. REMOTE path (board/MCM) - refuses a defiant Tribute retainer; use Venture_CollectInPerson from dialogue.}

Function Venture_CollectInPerson(Actor akAssignee) Global Native
{Dialogue-path collect: the player is face to face with the retainer. The only route that reaches a DEFIANT Tribute retainer's withheld escrow - answering the dare makes them back down (until the next settle if nothing changes).}

Function Venture_CollectAll() Global Native
{Collect pending escrow from every retainer.}

Function Venture_PayAllArrears() Global Native
{Pay back-wages across the roster, cheapest-first, clearing as many retainers as the player's purse can fully cover.}

Actor[] Function Venture_ListCourtesans() Global Native
{Active courtesan retainers (not deserted/hostile/jailed). Roster for the
 NSFW plugin's off-screen client-visit scheduler - soft cross-plugin
 surface, safe to call with no courtesans hired (empty array).}

Function Venture_BookClientCoin(Actor akCourtesan, Int aiAmount) Global Native
{Settle a client's fee through the venture: the player's cut (arrangement
 playerCutPct) rides the escrow and is collected with the weekly income;
 the remainder lands in the courtesan's pockets as real coin.}

Function Venture_Bail(Actor akAssignee) Global Native
{Pay a JAILED fence retainer's bounty from the player's gold to free them from the cell early. No-op unless the retainer is actually jailed.}

; Settle an ACTIVE fence's own illicit bounty from the player's purse (pay it
; off before the guards act). Jailed fences route to Venture_Bail internally.
Function Venture_SettleBounty(Actor akAssignee) Global Native

Function Venture_ForceArrest(Actor akAssignee) Global Native
{Debug: deterministically arrest+jail a retainer now (seeds a test bounty if none).}

Function Venture_Reassure(Actor akAssignee) Global Native
{Temper hearing SUCCESS: the retainer was genuinely heard out face to face. Consensual terms: morale lift + withdraws any standing notice. Coerced terms: cows them for exactly one settle (no morale repair). Clears an armed Send-Word meeting; cooldown-gated on the organic (no-meeting) path.}

Function Venture_BrushOff(Actor akAssignee) Global Native
{Temper hearing FAILURE: the player dismissed the grievance to their face. Morale drops harder than a no-show; a resentful/aggrieved consensual retainer gives notice on the spot, a Tribute retainer turns openly defiant. Clears the armed meeting.}

Function Venture_GrantRaiseInPerson(Actor akAssignee) Global Native
{Temper hearing: the player agrees IN CONVERSATION to raise this retainer's pay (or ease coerced terms). Grants the pending ask if one exists, re-grants previously refused terms, or synthesizes standard raise terms - then the full grant settlement runs (terms move, skim stops, refusals clear, morale up, notice withdrawn). Consumes an armed meeting. No-op for Enslaved (no wage/cut to move).}

Function Venture_SetTemperEnabled(Bool abEnabled) Global Native
{Master toggle for the Temper consequence ladder. Off = morale still tracks/displays but no complaint letters, pilfering, notices, defiance, betrayal, or escapes; standing notices quiesce at the next settle.}

Bool Function Venture_Hire(Actor akAssignee, String asJob, String asArrangement) Global Native
{Hire an NPC as a retainer. Job/arrangement are free text (normalized natively). Returns false on unparseable job or if already a retainer.}

Function Venture_PayArrears(Actor akAssignee) Global Native
{Pay a retainer's owed back-wages from the player's gold; clearing it restores good standing.}

Bool Function Venture_ClaimsJailThisWeek(Actor akAssignee) Global Native
{Yield-on-collision (v18): true while this actor's VENTURE already put them in custody this settlement week. The off-screen life sim checks this before applying its own arrest/bounty consequence, so one week's trouble cannot land two bounties from two independent pipelines. False for non-retainers.}

Function Venture_GrantLoan(Actor akAssignee) Global Native
{Grant the loan this retainer asked for - gold leaves the player's purse, a DebtStore entry backs it, and repayment is garnished from THEIR weekly take. No-op if no ask is pending or the player can't afford it.}

Int Function Venture_MigrateCampCuts() Global Native
{One-shot dev149 cut retune migration: camp Tribute ventures still at the OLD
 defaults move to the new ones (40 -> 20 Partnership, 60 -> 40 Vassalage);
 renegotiated cuts are untouched. Returns how many moved. Idempotent - safe
 to re-run, but gated by SeverActions_CampCutMigDone in Combat's Maintenance.}

Function Venture_RefuseLoan(Actor akAssignee) Global Native
{Refuse the loan this retainer asked for. Costs loyalty and starts an ask cooldown. No-op if no ask is pending.}

Function Venture_ForgiveLoan(Actor akAssignee) Global Native
{Write off what this retainer still owes on a loan - clears the balance and the backing DebtStore entry, and buys real loyalty. No-op if they owe nothing.}

Bool Function Venture_Dismiss(Actor akAssignee) Global Native
{End a retainer's service (amicable - no exit theft). Returns false if not a retainer.}

Int Function Venture_Count() Global Native
{Number of active ventures.}

Bool Function Venture_IsRetainer(Actor akActor) Global Native
{True if this actor is currently one of the player's retainers. Used to gate the assign-retainer popup (offered only for non-retainers).}

Actor Function Venture_GetAssigneeAt(Int index) Global Native
{The retainer actor at a stable index (0..Venture_Count()-1). None if out of range or not loadable. Use with Venture_Count() to enumerate/pick retainers.}

String Function Venture_LetterSubject(Actor akRetainer) Global Native
{Pending courier-letter subject for this retainer ("" if none). Queued by the worklife story gen; pull on the SeverActions_VentureLetter ModEvent.}

String Function Venture_LetterBody(Actor akRetainer) Global Native
{Pending courier-letter body for this retainer ("" if none).}

String Function Venture_LetterReason(Actor akRetainer) Global Native
{Pending courier-letter reason tag for this retainer.}

Function Venture_ClearLetter(Actor akRetainer) Global Native
{Drop the pending courier letter for this retainer (call after dispatching).}

Function Venture_DebugRequestLetter(Actor akRetainer) Global Native
{DEBUG: force an LLM-generated letter from this retainer; dispatches a courier when the model returns. Tests the real settlement->letter->courier path.}

Bool Function Venture_DebugForceAmbush() Global Native
{DEBUG: force a retainer-grudge thug ambush right now, bypassing the delay/cooldown/location gates. Picks an armed grudge, else arms one on any deserter, else conscripts any venture entry. Fires SeverActions_VentureAmbush so the thugs spawn on the player. Returns false only if there are no venture entries at all.}

Function Venture_RegisterAmbushThug(Actor akThug) Global Native
{Mark a spawned actor as part of the live ambush standoff, so the is_ambush_thug decorator gates the Stand Down / Attack actions to them. Cleared on resolve.}

Function Venture_ClearAmbushThugs() Global Native
{Clear the live-ambush thug roster (call when the standoff resolves - stood down, attacked, or failed).}

String Function Venture_AmbushTaunt(Actor akDeserter) Global Native
{Short spoken opener for the lead thug's DirectNarration - names who sent them and why (templated from the deserter's grievance).}

Function Venture_StageThugDirective(Actor akThug, Actor akDeserter) Global Native
{Stage a 'hold and parley, wait for the player's reply, resolve via stand-down/attack' directive as a high-importance memory on a spawned ambush thug, so they don't swing on the first word.}

Function Venture_Dump() Global Native
{Log a summary of every venture (escrow, purse, arrears, heat, loyalty, status).}

Function Venture_SetEnabled(Bool abEnabled) Global Native
{Enable/disable the autonomous weekly settlement heartbeat.}

; ─── Camp takeover (Phase 2) ────────────────────────────────────────────────
; The camp this actor belongs to swears to the player.
;   abViaLeader = True  -> the chief agreed; the speaker must BE the leader.
;   abViaLeader = False -> recruited after the chief fell; the camp must
;                          already be leaderless.
; Refused (returns False) if those conditions aren't met, so an LLM cannot
; talk a camp into swearing while its chief is standing right there.
Bool Function Camp_Swear(Actor akSpeaker, Bool abViaLeader) Global Native

; The leader of the camp the player is standing in (None if none).
Actor Function Camp_LeaderAtPlayer() Global Native

; Any living member of the camp the player is standing in.
Actor Function Camp_AnyMemberAtPlayer() Global Native

; Let a camp go: thaws the respawn freeze and drops it back to wild.
Bool Function Camp_Release(Actor akMember) Global Native

; The CHIEF renounces the camp's oath — hostile mirror of Camp_Release:
; books close, camp reverts to wild, the whole crew turns on the player
; together. Native refuses non-leaders.
Bool Function Camp_Renounce(Actor akLeader) Global Native

; 0 wild / 1 leaderless / 2 sworn / -1 not in a camp.
Int Function Camp_State(Actor akMember) Global Native

; Is this actor the leader of their camp?
Bool Function Camp_IsLeader(Actor akActor) Global Native

; ── War-band muster (Phase 3) ────────────────────────────────────────────
; Camp ids cross as Int (bit-exact through the signed type; ESL-range ids
; land negative and cast back clean natively).
Int Function Camp_CampIdOf(Actor akActor) Global Native
Actor[] Function Camp_GetMembers(Int aiCampId) Global Native
; Full roster size INCLUDING members whose temporary refs are unresolvable
; right now (detached cell) - Camp_GetMembers can only return who resolves.
Int Function Camp_RosterCount(Int aiCampId) Global Native
Bool Function Camp_SetMustered(Int aiCampId, Bool abOn) Global Native
Bool Function Camp_IsMustered(Int aiCampId) Global Native
Bool Function Camp_IsSworn(Int aiCampId) Global Native

; TRUE faction-entry removal. Papyrus RemoveFromFaction only writes rank -1
; into the actor's faction overrides - rank-blind consumers (IsInFaction,
; GetInFaction package conditions, other mods' wait checks) still read that
; residue as membership (the casual-followers-stuck-at-load-doors report).
; This erases the override entries outright. True = something was removed.
Bool Function Faction_RemoveClean(Actor akActor, Faction akFaction) Global Native
ObjectReference Function Camp_HomeMarker(Int aiCampId) Global Native
Float Function Camp_TravelHoursTo(Actor akMember) Global Native

; Master toggle for camp TAKEOVER (the Truce standoff has its own, separate
; toggle). Off removes the takeover actions from eligibility entirely.
Function Camp_SetTakeoverEnabled(Bool abEnabled) Global Native

; Freeze a sworn camp's encounter zone so it stops repopulating.
Function Camp_SetFreezeRespawn(Bool abEnabled) Global Native

; Master toggle for retainer LOAN requests (raises have their own).
Function Venture_SetLoansEnabled(Bool abEnabled) Global Native

Function Venture_SetStoryCap(Int aiCap) Global Native
{Max weekly work-life vignettes (LLM calls) generated per settle batch. -1 = Auto (~40% of the active roster, min 1, cap 12); 0 = off (income still settles, no vignettes); 1-12 = a fixed max. Skipped retainers rotate in over following weeks (least-recently-storied first).}

; Global venture-output scaler (v19). 25-300 percent; 100 = tuned baseline.
; Multiplies every venture's weekly production at settle, and the board's
; projection with it. Boot-synced from EnterpriseOutputPct.
Function Venture_SetProductionMult(Int aiPercent) Global Native

; Meet a pending raise ask halfway, in person (the NegotiateTerms action).
; No-op when nothing is pending. Also settles an armed hearing.
Function Venture_NegotiateRaise(Actor akActor) Global Native

Function Venture_SetRaisesEnabled(Bool abEnabled) Global Native
{Master toggle for retainer raise requests (Living payroll Phase B). When off, retainers never ask for a raise and never skim — income settles flat. Boot-synced + live-pushed from PrismaUI Settings.}

Function Venture_SetAmbushesEnabled(Bool abEnabled) Global Native
{Master toggle for retainer grudges (desertion consequences). When off, a wronged desertion arms no grudge and no thugs will come. Boot-synced + live-pushed from PrismaUI Settings.}

Function Venture_SetRenownCapEnabled(Bool abEnabled) Global Native
{Master toggle for the Renown roster cap (VSTR v2). When off, the renown score and tier still track but hiring is never gated by the cap. Boot-synced + live-pushed from PrismaUI Settings.}

; ── Stewards (VSTR v3) ──────────────────────────────────────────────────
; One steward per hold (keyed natively by the hold's crime faction). After
; each weekly settle, hold retainers' escrow sweeps into the steward's
; vault; the steward's own wage is drawn FROM that vault as real gold.

String Function Steward_Appoint(Actor akActor, Int aiWeeklyWage, String asHoldName = "") Global Native
{Appoint a retainer as steward of their hold. Returns the hold name, or "" if refused (not a retainer, hold unresolved, or the hold already has a living steward). Takes over the books immediately.}

Int Function Steward_Dismiss(Actor akActor) Global Native
{Dismiss this actor as steward. The vault remainder is paid out to the player as real gold (returned for the notification); the seat is cleared and hold retainers accrue their own escrow again. 0 if not a steward.}

Int Function Steward_DismissHold(String asHoldName) Global Native
{Dismiss whichever steward holds this hold's seat (board/UI path). Vault remainder pays out to the player; returns the amount. 0 if no steward.}

Int Function Steward_Collect(Actor akActor) Global Native
{Collect this steward's vault: pays the player the full balance as real gold and writes the cash-book line. Returns the amount; 0 if not a steward or the vault is empty.}

Int Function Steward_CollectHold(String asHoldName) Global Native
{Collect a hold's steward vault by hold name (board/UI path). Returns the amount paid to the player.}

String Function Steward_HoldNameOf(Actor akActor) Global Native
{The hold this actor stewards ("" if none). Cheap gate for dialogue/UI.}

; ── Steward visits (VSTR v6, ai_docs/STEWARD_VISITS.md) ─────────────────
; A steward walks out to one of the retainers whose takings they sweep,
; loiters near them a couple of game days, and goes home. Native decides who
; and when; SeverActions_Travel owns the packages. Both of these marshal onto
; the game thread internally, so the arrival hands back through the
; SeverActions_StewardVisitArrived ModEvent rather than a return value.

Function Steward_VisitLegDone(Actor akSteward, Bool abArrived) Global Native
{Report the outcome of a steward's visit journey. abArrived true fires
 SeverActions_StewardVisitArrived so Papyrus posts the anchor + sandbox;
 false drops the visit. No-op unless that steward is actually mid-journey.}


; ── The Final Audit's approach (a real journey, not a teleport) ─────────

Function Venture_Audit_TravelLegDone(Bool abArrived) Global Native
{Report the outcome of the Legate's walk to the player. True hands off to the
 follow package for the last stretch; false stages the detail behind the
 player instead, so the encounter happens either way. Marshals to the game
 thread internally. No-op when no walk is in flight.}

Bool Function Venture_Audit_IsTraveling() Global Native
{Is the Legate currently walking to the player under the travel orchestrator?
 Papyrus MUST check this before applying the march packages - the follow
 package is priority 110 and the traveller pool alias 106, so applying the
 march over a live journey stops the walk dead.}

; ── Truce scope (spillover from Ext, which is at 499/511) ───────────────

Function Native_Truce_SetDungeons(Bool abOn) Global Native
{Include outlaws HOLDING a dungeon (barrow, crypt, Dwemer ruin) in the truce,
 as opposed to those living in a camp. False = a place you delve stays a fight.
 A camp is never a dungeon for this purpose even though the game tags most
 camps as both - the lair keyword is checked first, so sworn camps are safe.
 Turning it off releases anyone already pacified in one on the next sweep.}

; ── Engine tweaks ───────────────────────────────────────────────────────

Function Sandbox_SetCylinder(Bool abEnabled, Float afHeight) Global Native
{Multi-floor sandboxing: widens the engine's sandbox search cylinder (fSandboxCylinderTop/Bottom GMSTs) so sandboxing NPCs use stairs and other floors - the Multiple Floors Sandboxing (nexus 4524) tweak applied at runtime, no ESP override. Widen-only: never narrows a wider value another mod shipped; disabled restores the load order's values.}

; ── Venture strays (were orphaned in Ext's kidnap section) ─────────────
Bool Function Venture_FireKidnapSearch(Actor victim) Global Native
; Fire a search-party standoff for a HELD captive (sender = victim; rides the grudge-ambush machinery + its master toggle and global cooldown). Returns true if queued — mark the one-per-captivity flag then.
Bool Function Venture_IsAmbushThug(Actor akActor) Global Native
{True while the actor is a live Venture ambush thug (mutex-guarded set).}

; ── Camp challenge (3.9.1) ─────────────────────────────────────────────────
; Walking into a WILD camp's interior earns a challenge: the chief (or the
; nearest outlaw) comes over and asks the player's business. Fired natively as
; the SeverActions_CampChallenge ModEvent (sender = the challenger); Papyrus
; owns the approach walk and the prompt card, then reports the outcome here.

Function Camp_ChallengeAllow() Global Native
{The player talked their way past. The camp's truce holds for this visit -
 re-entering the cell will not re-challenge until they leave the location.}

Function Camp_ChallengeRefuse(String asWhy = "") Global Native
{The challenge failed - refused, lied through, walked away from, or answered
 with a blade. Breaks the camp's truce on BOTH sides of the door: the
 challenger physically met the player, which is the causal link plain distance
 propagation can never provide across a cell boundary.}

Function Camp_ChallengeSetEnabled(Bool abEnabled) Global Native
{Master toggle for the challenge encounter.}

Function Camp_ChallengeSetCard(Bool abEnabled) Global Native
{Show the PrismaUI card when the challenger arrives. Off by default - the
 outlaw just walks up and asks, and the player answers in dialogue.}

Bool Function Camp_ChallengeCardEnabled() Global Native

Function Camp_ChallengeSetSeconds(Float afSeconds) Global Native
{How long the player has to talk before the challenger gives up on them.
 Clamped to 10-600 natively.}

Float Function Camp_ChallengeGetSeconds() Global Native

Function Camp_ChallengeEngaged() Global Native
{The challenger reached the player and the parley is live - stands the
 dispatch watchdog down so it does not re-send the challenger mid-question.}

Bool Function Camp_ChallengeNoteAttack(Actor akAttacker) Global Native
{An outlaw attacked the player (or a teammate) during a live challenge. True
 when the attacker is the pending challenger or any member of the questioned
 camp - the challenge is refused natively (whole camp breaks by roster) and
 the caller should tear the walk down. False otherwise: not our business.}

Bool Function Camp_ChallengeIsPending(Actor akActor) Global Native
{True only for the ONE outlaw currently challenging the player and still
 waiting on an answer. Papyrus-side mirror of the camp_challenge_pending
 decorator - use it to reject stale arrival/choice events before acting.}

String Function Camp_Name(Actor akMember) Global Native
{Display name of the camp this actor belongs to, or empty when they are in no
 registered camp.}

; ---------------------------------------------------------------------------
; PrismaUI challenge card
; ---------------------------------------------------------------------------

Bool Function PrismaUI_OpenChallengePrompt(Actor akChallenger, String asCampName, Int aiTimeoutMs) Global Native
{Non-pausing card asking how the player answers the challenge. False when
 PrismaUI is unavailable or another view holds focus - the caller falls back to
 a notification so the challenge is never silently swallowed.}

Function PrismaUI_CloseChallengePrompt() Global Native
Bool Function PrismaUI_IsChallengePromptOpen() Global Native
Bool Function PrismaUI_IsChallengePromptAvailable() Global Native

; ─── Chronometer (per-script tick service) ────────────────────────────────
; Replaces Papyrus RegisterForSingleUpdate on quest 0D62: update registrations
; are keyed to the FORM, so every quest script on 0D62 shared ONE pending
; timer (last registration wins, OnUpdate broadcast to all — the 3s Fertility
; bridge loop ran at ~32s once the FollowerManager loop started; dev field
; report 2026-08-18). Each script owns a unique ModEvent name
; ("SeverActions_Tick_<X>") and a native steady-clock thread fires it — SKSE
; ModEvent registrations are keyed (form, event NAME), so the ticks stay
; independent on the shared form - AND the callback name must be unique per
; script too (OnChronoTick_<X>): delivery invokes the callback on every
; script of the form that defines it (field-verified: a shared name ran the
; FollowerManager pass on the bridge's 3s beat). One slot per NAME: a re-request replaces
; the pending tick, mirroring RegisterForSingleUpdate within one script.
; Pending ticks do NOT survive save/load (scripts re-arm from their load
; paths) and are cleared on revert.
Function Chrono_Request(String asEventName, Float afSeconds) Global Native
{Arm (or replace) a one-shot tick: asEventName fires as a senderless ModEvent
 in afSeconds real seconds. Register the handler with RegisterForModEvent
 BEFORE (or in the same function as) the request - the ChronoArm helper
 pattern in each converted script does both.}
Function Chrono_Cancel(String asEventName) Global Native
{Drop a pending tick (UnregisterForUpdate equivalent). No-op when nothing is
 pending under that name.}

; --- Stock & Trade depots (issue #422 phase 1) -----------------------------
; Per-hold trade stock: 9 depot chests + 9 fence caches in a holding cell
; (SeverActionsDepotCell). Merchants/fences restock and sell REAL items out
; of them at the weekly settle. The chests live in a never-loaded cell, so
; NEVER call chest.Activate(player) on them (the vanilla ContainerMenu route
; against that uninitialized cell is a confirmed CTD - see StockDepots.h /
; PrismaUIActionHandler openDepot). The player-facing surface is the PrismaUI
; Wares panel (openDepot / depotTransfer / depotDepositCategory); the chest
; ref returned below is for NATIVE inventory ops only. Index 0-8 is the frozen
; hold order (Whiterun, Eastmarch, Haafingar, Rift, Reach, Hjaalmarch, Pale,
; Winterhold, Falkreath). Stolen-flagged goods only sell through the fence
; cache. NOTE: this Papyrus surface has no caller today - it is a reserved
; native surface for future scripted access.
Int Function Depot_Count() Global Native
{Number of holds with depots (9).}
String Function Depot_HoldName(Int aiIndex) Global Native
{Display name for a depot index ("" out of range).}
ObjectReference Function Depot_GetChest(Int aiIndex, Bool abFence) Global Native
{The hold's depot chest (or fence cache), for NATIVE inventory ops only.
 Do NOT call .Activate() on it - the chest is in a never-loaded cell and
 the vanilla container menu CTDs there; player access is the Wares panel.
 None out of range.}
Int Function Depot_Value(Int aiIndex, Bool abFence) Global Native
{Current sellable value of the hold's stock (legit depots exclude
 stolen-flagged stacks - those only sell through the fence cache).}
Int Function Depot_IndexForCrimeFaction(Int aiRuntimeFactionId) Global Native
{Hold index for a runtime crime-faction FormID, -1 if none. Routes a
 merchant retainer's own hold to the right chest.}

; ─── Travel (pool-side consolidation) ─────────────────────────────────────
Bool Function Travel_SetSpeedByActor(Actor akNPC, Int speed) Global Native
{Change an in-flight travel's speed keyed by ACTOR (no slot needed - works for
 pool-only journeys). Re-bands the Traveler_NN pool alias into the new speed's
 band so the unloaded pace follows too. Returns true if a live journey was found.}

Bool Function Travel_HasAlias(Int handle) Global Native
{True if the journey holds a Traveler_NN pool alias (the pool package governs -
 do NOT add the override). False = pool exhausted at Begin; apply the override
 fallback. Phase 2 consolidation: the pool package is the only package.}

; ─── Ambient Actions (Action Orchestrator — promote half) ─────────────────
; See ai_docs/AMBIENT_ACTIONS.md. AmbientActionScanner::RegisterFunctions binds
; these on this class. Pumped by SeverActions_FollowerManager (CheckAmbientAction
; + OnAmbientActionReady).

Int Function Native_AmbientAction_FireToLLM(Float hearingRadius, Float pairRadius, Int maxCandidates) Global Native
{Scan nearby non-follower NPCs, score candidates, dispatch the
 sever_ambient_action_director LLM. Returns >0 candidate count dispatched
 (request in flight), 0 no candidates / hostile cell, -1 bridge/API unavailable.
 Fires SeverActions_AmbientActionReady when the director responds (numArg =
 IntentKind: 0 none, 1 solo, 2 social). Pass 0/0/0 for native defaults.}

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
 (empty for solo). Hand straight to SkyrimNetApi.RegisterEvent — built in C++
 so non-ASCII names survive.}

Function Native_AmbientAction_ClearReady() Global Native
{Clear the ready slot; also resets the social gate once it has resolved. Idempotent.}

Int Function Native_AmbientAction_PollGate(Actor akInitiator) Global Native
{Poll the active social gate. Returns 0 pending (keep polling), 1 go (commit the
 action), 2 blocked (addressee refused — do NOT act, memory written), 3 done
 (deferred/aborted/no gate). Native drives settle detection + adjudication.}

Function Native_AmbientAction_AbortGate(Actor akInitiator) Global Native
{Force-abort the ambient social gate (player interrupt / poll ceiling).}

String Function Native_BuildGMDialogueEventJson(String asSpeaker, String asTarget, String asTopic, String asDirection) Global Native
{UTF-8-safe gamemaster_dialogue event JSON builder (nlohmann in C++ — Papyrus
 String concat corrupts non-ASCII names, issue #9). asDirection (optional, "")
 is APPENDED TO TOPIC: SkyrimNet renders only speaker+topic; the dialogue field
 is never shown to the generating LLM and exists only because the schema
 requires it. Used by follower banter; ambient banter builds natively.}

; ─── Named Travel Markers (ai_docs/NAMED_MARKERS.md, M0) ──────────────────
Int Function Marker_DropHere(Actor akPlacer, String asName) Global Native
{Place a force-persistent XMarkerHeading at the placer's position + facing,
 scope it to the current BGSLocation (parent cell fallback), and register it
 in the cosaved 'MRKR' store. Empty name auto-names "Spot N". Returns the new
 marker id, or 0 (cap of 128 hit / base missing / no scope).}

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
{Belt for the companion verbs: if the actor sits in a Traveler_NN pool alias
 with NO live journey (a release that gave up - the arrived-but-pinned field
 case), release it now (retries + quest-bounce escalation included) so follow
 or wait can actually take hold. Returns true when a stale seat was found.}

ObjectReference Function Marker_PickRotationTarget(Actor akNpc, ObjectReference akAnchor) Global Native
{Room rotation (NAMED_MARKERS.md 5.5): pick the next named marker in the
 anchor's home (location scope, cell fallback), excluding the spot the anchor
 already sits on. None = the home has no other markers. Varies per call.}

Bool Function Travel_IsTravelingByActor(Actor akActor) Global Native
{True while the actor has a LIVE travel journey (any non-terminal state).
 Gates systems that would fight the travel package for the actor's AI -
 e.g. the furniture action re-parking a mid-journey traveler.}

Int Function Craft_CancelByActor(Actor akActor) Global Native
{Cancel every live crafting session for this actor (travel-start disengage).
 Returns how many sessions were cancelled. The TermCancelled ModEvent still
 fires, so the Papyrus-side package/alias cleanup runs as usual.}

Bool Function Venture_SyncPremisesFromWork(Actor akActor, ObjectReference akMarker) Global Native
{Derive-mode premises (the ONLY premises writer): the owned-property cell
 containing the retainer's work marker becomes the premises; any other spot
 (or None = work cleared) detaches it. No-op for non-retainers.}

Bool Function Prisma_IsMenuOpen() Global Native
{True while the SeverActions PrismaUI config view is open. The Prisma view is
 NOT engine menu mode - with pause-on-open disabled, Utility.IsInMenuMode()
 stays false - so hotkey scripts must gate on this to avoid firing while the
 user interacts with the UI (the phantom marker-drop bug).}

; == The Imperial Final Audit (Taxes P2) =======================================

String Function Venture_Audit_State() Global Native
{Audit state token: "" (dormant), "casebuilding", "approaching", "demanding",
 "paid", "refused", or "dead". Mirrors the tax_audit_state decorator.}

Int Function Venture_Audit_Demand() Global Native
{The gold the Final Audit is demanding (40% of the purse the player was
 carrying when the case opened). Clamped to Int range natively.}

Bool Function Venture_Audit_IsCollector(Actor akActor) Global Native
{True when the actor is one of the Treasury's three collectors. Gates the
 follow-refusal guards; mirrors the is_tax_collector decorator.}

Bool Function Venture_IsActiveRetainer(Actor akActor) Global Native
{True when the actor is a retainer still in service (present, not deserted or
 hostile). NOT the same as Venture_IsRetainer, which is true for any record
 including ex-retainers. The RetainerPersist free-sweep uses this to decide
 whether to release a seated alias.}

; ── Combat-gear yield (FollowerLivePackage accommodation) ────────────────────

Bool Function Native_Outfit_RecordExternalChange(Actor akActor, Form akItem, Bool abIsUnequip) Global Native
{Form-aware replacement for Native_Outfit_RecordExternalUnequip: records the
 change for burst detection AND classifies it for the combat-gear yield (was
 this change an unequip of a pure helm/shield-slot armor?). Same return as the
 legacy call: true when the burst-strip suppression is active.}

Bool Function Native_Outfit_ShouldYieldCombatGear(Actor akActor) Global Native
{True when outfit enforcement should YIELD this debounce round: the yield
 setting is on, the actor is out of combat, and the just-settled burst was
 nothing but helm/shield unequips - an external mod (FollowerLivePackage)
 taking gear off between fights, which is a choice, not a strip. Consumes the
 burst's classification, so ask ONCE per debounce.}

Bool Function Venture_Audit_Collect() Global Native
{Latch the audit PAID (atomically - only one caller can win) and send the
 detail home. Call this FIRST and remove the gold only if it returns true;
 false means the audit was not demanding, or another call already won.}

Bool Function Venture_Audit_Refuse() Global Native
{Latch the audit REFUSED (terminal). Papyrus starts the fight itself.
 False unless the audit was demanding.}

Actor Function Venture_Audit_Collector(Int aiIndex) Global Native
{The PLACED collector ref: 0 = Legate Cassius, 1 = Livia, 2 = Drusilla.
 None if that collector's ref cannot be resolved from SeverActions.esp.}

Function Native_SettingsRecord(String asPage, String asKey, String asValue) Global Native
{Mirror a setting the MCM just wrote into the GLOBAL settings file, using the
 same page/key PrismaUI uses. PrismaUI records every target-less change and the
 file is replayed on load ("the global file always wins"), but the MCM writes
 Papyrus properties only - so an MCM choice was overwritten by the stale file on
 the next load. Call this right after setting the property.}
Function Native_ClearSAFollowOwnership(Actor akActor) Global Native
{Release SA's claim on this follower's follow package (clears hasFollowPkg and
 isSandboxing in the cosave). hasFollowPkg must be FALSE for track-only
 followers - it is the gate CellCatchup and FollowDriftMonitor use to decide
 whether to drag someone through load doors and re-assert follow on them. A
 stale TRUE left a DLC/framework follower permanently mis-owned. Papyrus owns
 the track-only verdict; this applies it.}

Bool Function Native_IsNFFManaged(Actor akActor) Global Native
{TRUE when Nether's Follower Framework currently owns this actor - i.e. they are
 filled into a RUNNING alias of a quest defined by nwsFollowerFramework.esp,
 which is how NFF's RecruitAction claims a follower. Factions cannot answer this:
 NFF stamps the VANILLA CurrentFollowerFaction, the same one our is_follower test
 reads. Keyed on the defining plugin rather than a quest FormID so NFF updates
 don't break it. Always FALSE when NFF is not installed.}

Bool Function Native_IsNFFInstalled() Global Native
{TRUE when nwsFollowerFramework.esp is in the load order.}

; == Follower ownership - the single source of truth =========================
; 0 None | 1 SeverActions | 2 NFF | 3 DLC (Serana) | 4 CustomAI | 5 Vanilla
Int Function Native_GetFollowerOwner(Actor akActor) Global Native
{WHO owns this follower's AI, computed fresh from every signal at once (NFF
 alias seat, DLC1SeranaFaction, SPID keyword / NFF ignore token / curated list,
 our own store flags, vanilla CurrentFollowerFaction) with a deliberate
 precedence: a framework that actively CLAIMED the actor outranks our own
 bookkeeping, because our flags are the ones that go stale. Ask this rather than
 re-deriving ownership from individual flags - that spread is what let a single
 stale hasFollowPkg have SA fighting Serana's DLC AI.}

String Function Native_GetFollowerOwnerName(Actor akActor) Global Native
{Same verdict as Native_GetFollowerOwner as a readable token, for logs and
 diagnostics: "None", "SeverActions", "NFF", "DLC", "CustomAI", "Vanilla".}

String Function Camp_ConsentTally(Actor akActor) Global Native
{"have/needed" for a LEADERLESS camp's consent roll (e.g. "2/3"), or "" when
 the camp has a living chief, has already sworn, or the actor is in no camp.
 A chief speaks for everyone; without one the camp is won a person at a time.}

; ── Schedule tick pre-filter (issue #402) ───────────────────────────────────
; The 30s FollowerManager pass used to walk the whole homed roster five times
; and pay 20-30 VM round-trips per NPC to conclude "nothing to do". These two
; answer the same question natively, in one call, returning ONLY the actors that
; need Papyrus. Native/src/ScheduleTickFilter.h documents the contract; the
; short version is that the filter never decides anything — it can only prove
; "nothing to do" and omit, so anything it cannot see is still returned and the
; unmodified Papyrus reconcile runs on it with every guard intact.
; Both results are SORTED BY FORMID so the caller's rotating chunk cursor is
; stable across ticks (FollowerDataStore's map order is not).

Actor[] Function Sched_GetTransitionDue(Float afGameHour, Float afWorkStart, Float afWorkEnd, Float afPlayStart, Float afPlayEnd) Global Native
{Every NPC the schedule tick must actually touch this pass: a real
 home/work/relax transition, a registered follower still holding a schedule
 alias (self-heal), an on-shift guard needing the mid-shift reinforce, or an
 orphaned alias hold with no assignment left behind it. The global work/relax
 windows are passed in because they are MCM-owned Papyrus properties; per-NPC
 work-hour overrides (FLWD v17) are read natively and take precedence exactly
 as DetermineScheduleTypeFor applies them. Alias-era only — Route B enforcement
 is keyed on KEY_LAST_SCHEDULED_TYPE, not alias indices, so gate on
 SchedSystemActive().}

Actor[] Function Sched_GetSceneSuspendMismatched() Global Native
{Homed, 3D-loaded NPCs whose live BGSScene state disagrees with the cosaved
 home-scene-suspend flag — i.e. the only ones CheckSceneSuspendedHomes can act
 on. Both halves of that comparison are native, so this is almost always empty.
 Actors still carrying the suspended flag are included even if their home was
 cleared meanwhile, so a suspend can always be undone.}

; --- Intimate history (moved here from Ext at the 511-fn cap, PR #442 review) ---

; Main tracks no intimate history — no duplication of the NSFW sibling's
; SexualHistoryStore; only the surfacing gates below remain, backing the 0046
; consent section and the persona/trade decorators.

Function Native_IntimateHistory_SetEnabled(Bool abEnabled) Global Native
{Live-apply the intimacy master toggle to the native store so the surfacing
 gate takes effect WITHOUT a reload (the settings-file write is separate).
 Call from MCM alongside the property + Native_SettingsRecord writes.}

Function Native_IntimateHistory_SetGenderGate(Int aiGate) Global Native
{Live-apply the surfacing gender gate to the native store (0=everyone,
 1=women only, 2=men only). Call from MCM alongside the property +
 Native_SettingsRecord writes so the change is not inert until reload.}

String Function Native_ClosestInventoryNames(Actor akActor, String asQuery, Int aiMaxCount) Global Native
{Comma-joined inventory item names of akActor that fuzzy-match asQuery (best
 match first, capped at aiMaxCount, "" when nothing matches). Used by the
 BuyItem/SellItem failure event to tell the LLM what the seller actually
 carries - on localized games the model often passes the English canonical
 name while the inventory holds the localized one (public issue #16).}

; ── Debt confirm prompt (non-pausing PrismaUI overlay; public issue #16) ─────
; CreateDebt with the player as a party used a modal SkyMessage, which does not
; render while the dialogue menu is up - the confirm silently died and no debt
; was recorded. Same UX family as the trade/bounty prompts. Choice returns via
; the SeverActions_DebtChoice ModEvent (strArg = accept|deny|denySilent,
; numArg = amount, sender = the NPC counterparty).

Bool Function PrismaUI_OpenDebtPrompt(Actor akCounterparty, Int aiAmount, String asReason, Int aiDueDays, Int aiCreditLimit, Bool abPlayerIsCreditor, Int aiTimeoutMs) Global Native
Function PrismaUI_CloseDebtPrompt() Global Native
Bool Function PrismaUI_IsDebtPromptOpen() Global Native
Bool Function PrismaUI_IsDebtPromptAvailable() Global Native

; ── Bio Blocks — MCM (VR) apply / faction-rule surface ─────────────────────
; Library authoring stays in PrismaUI/JSON; these let the SkyUI MCM APPLY
; existing blocks to the crosshair target and manage faction rules in VR.
; Titles[] and Ids[] returned in parallel (title[i] <-> id[i]).
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

; Outfit slot registry — actors currently wearing a slot preset. Replaces the
; legacy OutfitDataStore lock registry as the outfit-lock system retires.
Actor[] Function Native_OutfitSlot_GetActorsWithActivePreset() Global Native
