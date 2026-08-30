Scriptname SeverActions_Brawl extends Quest
{Brawl actions for SkyrimNet — fist-fight orchestration between any two actors.
 Native BrawlManager owns engine-side state (DGIntimidateFaction membership,
 loadout snapshot, fists-only equip-block, bleedout-detection). This script:
   - Exposes Challenge / Accept / Decline / Forfeit actions to SkyrimNet.
   - Maintains a Pending-Challenge map (challenger -> target, with expiry).
   - Handles the SeverBrawl_Ended ModEvent fired by the native manager.
   - Pushes vanilla form references (DGIntimidateFaction, csWEBrawler) into
     the native cosave at init / load.}

; ============================================================================
; PROPERTIES
; ============================================================================

Faction Property DGIntimidateFaction Auto
{Vanilla DGIntimidateFaction — Skyrim.esm 0x0004CFA6. Set via CK on the alias
 properties. The kSpecialCombat flag on this faction is what routes brawl
 damage to bleedout instead of death.}

CombatStyle Property csWEBrawler Auto
{Vanilla brawler combat style — Skyrim.esm 0x10555D. Applied PER-REFERENCE
 (ExtraCombatStyle on the actor) for the duration of a brawl so combat AI
 prefers unarmed — never written to the NPC base: base writes corrupt shared
 bases and are ignored on templated NPCs.}

Float Property PendingChallengeExpiry = 60.0 Auto
{How long (real-time seconds) a challenge stays pending before auto-expiring.}

Float Property BrawlCooldownDuration = 30.0 Auto
{Cooldown applied to both combatants after a brawl ends — gates re-challenges.}

Float Property ChallengeFollowDistance = 3000.0 Auto
{Native distance check for NPC↔NPC challenge wait — if challenger drifts
 further than this from target, monitor fires expiry with reason="distance".}

Float Property PopupPollIntervalSec = 0.5 Auto
{How often the chronometer tick polls SkyMessage for the player's Accept/Decline answer.}

Float Property TrackOnlyRerecruitDelay = 1.5 Auto
{Seconds after a brawl ends before we auto-re-recruit any tracking-only follower
 whose external framework (NFF / SPID custom-AI / Daegon controller / DLC) saw
 our IsPlayerTeammate strip as a real dismiss. Short enough that they snap back
 quickly; the teammate flag is restored immediately at brawl end (see
 RestoreTeammateAfterBrawl) so nothing untracks them while we wait.}

; Transient state for the player-target popup loop.
Int Property PendingPopupId = 0 Auto Hidden
Form Property PendingPopupChallenger = None Auto Hidden
Float Property PendingPopupStartTime = 0.0 Auto Hidden

; Transient state for the PrismaUI-overlay defer-retry. When a challenge is
; triggered from a PrismaUI menu (e.g. the Actions page), that menu still holds
; focus for a beat after it closes, so PrismaUI_OpenBrawlPrompt is suppressed.
; Rather than drop to the SkyMessage box, we retry the overlay a few times via
; the chronometer tick until focus is released.
Form Property PendingOverlayChallenger = None Auto Hidden
Int Property OverlayRetryCount = 0 Auto Hidden

; ============================================================================
; STORAGEUTIL KEYS (per-actor, set by this script, read by prompts)
; ============================================================================
; SeverBrawl_ChallengeFrom    - Form (who challenged this actor)
; SeverBrawl_ChallengeTo      - Form (who this actor challenged)
; SeverBrawl_ChallengeTime    - Float (Utility.GetCurrentRealTime() of issue)
; SeverBrawl_LastWinner       - Form (most recent brawl winner against this actor)
; SeverBrawl_LastLoser        - Form (most recent brawl loser against this actor)
; SeverBrawl_LastEndReason    - Int (1=Bleedout, 2=Forfeit, 3=WalkedAway, 4=Broken, 5=Abort, 6=ForfeitSheathed - player dropped their fists)
; SeverBrawl_LastEndTime      - Float (Utility.GetCurrentGameTime() of end)

; ============================================================================
; SINGLETON
; ============================================================================

SeverActions_Brawl Function GetInstance() Global
    Quest kQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
    Return kQuest as SeverActions_Brawl
EndFunction

; ============================================================================
; INITIALIZATION
; ============================================================================

Event OnInit()
    RegisterForModEvent("SeverBrawl_Ended", "OnBrawlEnded")
    RegisterForModEvent("SeverBrawl_Started", "OnBrawlStarted")
    RegisterForModEvent("SeverActions_BrawlChallengeExpired", "OnChallengeExpired")
    RegisterForModEvent("SeverActions_BrawlChallengeChoice", "OnBrawlPromptChoice")
    RegisterForModEvent("SeverBrawl_Rekick", "OnBrawlRekick")
    RegisterForModEvent("SeverBrawl_HandsClean", "OnBrawlHandsClean")
    PushBrawlConfigToNative()
EndEvent

Event OnBrawlHandsClean(String eventName, String strArg, Float numArg, Form sender)
    {A brawl participant just had a SPELL equipped mid-fight (wardrobe/equip
     mods re-equip behind us, and the player's own strip natively reports
     ok=false on hand spells). Native routes spell equips here because a
     SpellItem is not a TESBoundObject - UnequipObject cannot touch it -
     while Papyrus UnequipSpell provably works on NPCs AND the player.}
    Actor a = sender as Actor
    If !a
        Return
    EndIf
    Int hand = 0
    While hand < 2
        Spell sp = a.GetEquippedSpell(hand)
        If sp
            a.UnequipSpell(sp, hand)
            Debug.Trace("[SeverBrawl] HandsClean: unequipped " + sp.GetName() + " from " + a.GetDisplayName() + " (hand " + hand + ")")
        EndIf
        hand += 1
    EndWhile
EndEvent

Event OnBrawlRekick(String eventName, String strArg, Float numArg, Form sender)
    {The engagement watchdog found the pair not yet in mutual combat at half
     its window: re-issue StartCombat. Exists for the NFF-release race - the
     dismissal that frees an NFF brawler tears its alias down ASYNCHRONOUSLY,
     so the Begin-time StartCombat can fire while the suppression is still
     seated. Opponent rides strArg as signed decimal + GetFormEx, never the
     float numArg (the 2^24 FormID precision trap).}
    Actor a = sender as Actor
    Actor b = Game.GetFormEx(strArg as Int) as Actor
    If a && b && !a.IsDead() && !b.IsDead()
        Debug.Trace("[SeverBrawl] Rekick: re-issuing StartCombat " + a.GetDisplayName() + " <-> " + b.GetDisplayName())
        ; Only NPCs kick - the engine refuses Actor.StartCombat on the player
        ; outright ("Actor is the player, cannot start combat", field log).
        If a != Game.GetPlayer()
            a.StartCombat(b)
        EndIf
        If b != Game.GetPlayer()
            b.StartCombat(a)
        EndIf
    EndIf
EndEvent

Function OnGameLoaded()
    {Load-time recovery. Called by SeverActions_Init.RunLoadRecovery() on
     every load — Quest scripts NEVER receive OnPlayerLoadGame, so recovery must
     be driven from here: re-register the popup choice listener, restore
     brawl-stripped teammate flags, and re-push the native brawl config.}
    ; Chronometer: one idempotent wake on load - re-primes the popup poll /
    ; rerecruit drain if a brawl flow was mid-flight at the save (pending
    ; ticks do not survive save/load the way engine registrations did).
    ChronoArm(1.0)
    ; Auto-property defaults are baked into existing saves, so a save created
    ; before this value changed keeps the old (slower) delay. Force the current
    ; intended value on every load so the tuning applies to in-progress games,
    ; not just new ones.
    TrackOnlyRerecruitDelay = 1.5
    RegisterForModEvent("SeverBrawl_Ended", "OnBrawlEnded")
    RegisterForModEvent("SeverBrawl_Started", "OnBrawlStarted")
    RegisterForModEvent("SeverActions_BrawlChallengeExpired", "OnChallengeExpired")
    RegisterForModEvent("SeverActions_BrawlChallengeChoice", "OnBrawlPromptChoice")
    RegisterForModEvent("SeverBrawl_Rekick", "OnBrawlRekick")
    RegisterForModEvent("SeverBrawl_HandsClean", "OnBrawlHandsClean")
    PushBrawlConfigToNative()
    ; Drop any stale popup state from before the save was taken — SkyMessage's
    ; messageBoxId is process-lifetime so it's invalid after a reload.
    PendingPopupId = 0
    PendingPopupChallenger = None
    PendingPopupStartTime = 0.0
    ; Likewise dismiss any in-flight PrismaUI brawl prompt — the view stays
    ; across saves but its session state (challenger FormID) does not.
    If SeverActionsNative.PrismaUI_IsBrawlPromptOpen()
        SeverActionsNative.PrismaUI_CloseBrawlPrompt()
    EndIf
    ; Challenge-state reconciliation (audit #419). The native expiry monitor
    ; is deliberately non-cosaved and wiped on revert, but the challenger's
    ; follow package + LinkedRef DO survive the save (LREF is cosave-restored)
    ; and so do the StorageUtil challenge keys - so a challenge interrupted by
    ; a save left the challenger trailing the target FOREVER with no expiry
    ; able to fire. StorageUtil.GetFormValue survives on the actors
    ; themselves, so sweep via the tracked list the challenge writes.
    Int ci = StorageUtil.FormListCount(self, "SeverBrawl_OpenChallengers")
    While ci > 0
        ci -= 1
        Actor ch = StorageUtil.FormListGet(self, "SeverBrawl_OpenChallengers", ci) as Actor
        If ch
            Actor tgt = StorageUtil.GetFormValue(ch, "SeverBrawl_ChallengeTo") as Actor
            Debug.Trace("[SeverBrawl] OnGameLoaded: clearing stale challenge " + ch.GetDisplayName())
            StopChallengeFollow(ch)
            ClearChallengeState(ch, tgt)
        EndIf
    EndWhile
    StorageUtil.FormListClear(self, "SeverBrawl_OpenChallengers")
    ; Mid-brawl save safety: brawls are deliberately not persisted in the
    ; native cosave, but our StorageUtil "SeverBrawl_WasTeammate" markers
    ; (set when we stripped IsPlayerTeammate on a brawling follower) do
    ; persist. On load, any follower whose flag was stripped at save time
    ; has IsPlayerTeammate=false saved in the .ess. Walk the marker list
    ; and force the flag back on so they re-register as followers.
    RestoreStrippedTeammatesAfterReload()
    ; Pending track-only re-recruits also survive in StorageUtil — if a
    ; save landed inside the TrackOnlyRerecruitDelay window, the
    ; RegisterForSingleUpdate didn't carry over. Re-schedule now.
    If StorageUtil.FormListCount(self, "SeverBrawl_PendingRerecruit") > 0
        ChronoArm(TrackOnlyRerecruitDelay)
    EndIf
EndFunction

Function PushBrawlConfigToNative()
    If DGIntimidateFaction
        SeverActionsNativeExt.Brawl_SetDGFaction(DGIntimidateFaction)
    EndIf
    If csWEBrawler
        SeverActionsNativeExt.Brawl_SetBrawlerCS(csWEBrawler)
    EndIf
EndFunction

; ============================================================================
; CHALLENGE
; ============================================================================

Function ChallengeBrawl_Execute(Actor akChallenger, Actor akTarget)
{Speaker issues a fist-fight challenge. Two branches:
   1. Target = player → ShowPlayerChallengePopup (PrismaUI / SkyMessage / Notification fallback).
   2. NPC ↔ NPC      → record pending state, apply follow package to
      challenger, start native expiry monitor, surface ANSWER REQUIRED to
      target's next SkyrimNet prompt.}

    ; Diagnostic entry log — first line so the script's invocation is
    ; always visible even when an early-return blocks. If this line is
    ; missing from Papyrus.0.log, the action wasn't dispatched at all
    ; (SkyrimNet eligibility / dynamic-resolution / routing problem).
    String challengerName = "None"
    String targetName = "None"
    If akChallenger
        challengerName = akChallenger.GetDisplayName()
    EndIf
    If akTarget
        targetName = akTarget.GetDisplayName()
    EndIf
    Debug.Trace("[SeverBrawl] ChallengeBrawl_Execute ENTRY: challenger=" + challengerName + " target=" + targetName)

    If !akChallenger || !akTarget
        Debug.Trace("[SeverBrawl] Challenge REJECTED: invalid actor(s)")
        Return
    EndIf
    If akChallenger == akTarget
        Debug.Trace("[SeverBrawl] Challenge REJECTED: challenger == target")
        Return
    EndIf
    If akChallenger.IsDead() || akTarget.IsDead()
        Debug.Trace("[SeverBrawl] Challenge REJECTED: at least one party is dead")
        Return
    EndIf
    If SeverActionsNativeExt.Brawl_IsActive(akChallenger) || SeverActionsNativeExt.Brawl_IsActive(akTarget)
        Debug.Trace("[SeverBrawl] Challenge REJECTED: at least one party already brawling (challenger active=" \
            + SeverActionsNativeExt.Brawl_IsActive(akChallenger) + " target active=" + SeverActionsNativeExt.Brawl_IsActive(akTarget) + ")")
        Return
    EndIf
    If akChallenger.IsInCombat() || akTarget.IsInCombat()
        Debug.Trace("[SeverBrawl] Challenge REJECTED: in real combat (challenger=" \
            + akChallenger.IsInCombat() + " target=" + akTarget.IsInCombat() + ")")
        Return
    EndIf
    ; Re-entrancy (audit #419): a challenger with a pending OUTBOUND challenge
    ; must cancel it before issuing a new one - the native monitor is keyed by
    ; challenger FormID, so a second Begin silently overwrites the first and
    ; the abandoned target's expiry never fires. Cancel-and-proceed rather
    ; than reject: the LLM re-challenging someone new is a legitimate change
    ; of mind, it just has to be bookkept.
    Actor priorTarget = StorageUtil.GetFormValue(akChallenger, "SeverBrawl_ChallengeTo") as Actor
    If priorTarget && priorTarget != akTarget
        Debug.Trace("[SeverBrawl] Cancelling prior challenge " + akChallenger.GetDisplayName() + " -> " + priorTarget.GetDisplayName())
        StopChallengeFollow(akChallenger)
        ClearChallengeState(akChallenger, priorTarget)
    EndIf
    ; Post-brawl cooldown (audit #419): reject a challenge while either party is
    ; still within the post-brawl cooldown window Cooldown_Set writes at brawl end.
    If SeverActionsNativeExt.Cooldown_IsActive(akChallenger) || SeverActionsNativeExt.Cooldown_IsActive(akTarget)
        Debug.Trace("[SeverBrawl] Challenge REJECTED: post-brawl cooldown active")
        Return
    EndIf

    ; Always record the pending challenge state — every branch reads it.
    ; Also list the challenger on the quest so the load sweep can find open
    ; challenges without scanning the world (audit #419).
    StorageUtil.FormListAdd(self, "SeverBrawl_OpenChallengers", akChallenger, False)
    StorageUtil.SetFormValue(akChallenger, "SeverBrawl_ChallengeTo", akTarget)
    StorageUtil.SetFormValue(akTarget, "SeverBrawl_ChallengeFrom", akChallenger)
    Float now = Utility.GetCurrentRealTime()
    StorageUtil.SetFloatValue(akChallenger, "SeverBrawl_ChallengeTime", now)
    StorageUtil.SetFloatValue(akTarget, "SeverBrawl_ChallengeTime", now)

    SkyrimNetApi.RegisterEvent("brawl_challenged", \
        akChallenger.GetDisplayName() + " challenged " + akTarget.GetDisplayName() + " to a brawl", \
        akChallenger, akTarget)

    ; Branch 1 — target is the player → popup (PrismaUI → SkyMessage → notification).
    If akTarget == Game.GetPlayer()
        ShowPlayerChallengePopup(akChallenger)
        Return
    EndIf

    ; Branch 2 — NPC ↔ NPC → follow + monitor.
    StartChallengeFollow(akChallenger, akTarget)

    Debug.Trace("[SeverBrawl] Challenge issued: " + akChallenger.GetDisplayName() + " -> " + akTarget.GetDisplayName())
EndFunction

; ============================================================================
; PLAYER-TARGET POPUP (PrismaUI → SkyMessage → notification)
; ============================================================================

Function ShowPlayerChallengePopup(Actor akChallenger, Bool abIsRetry = false)
    {Three-tier popup chain:
       1. PrismaUI HUD overlay (preferred — non-pausing, brass-on-dark card).
       2. SkyMessage non-blocking popup (fallback if PrismaUI absent).
       3. Debug.Notification (last resort if both are absent — challenge
          still auto-expires via the native monitor).
     abIsRetry: true when re-entered from OnChronoTick_Brawl's overlay defer-retry,
     so the retry counter is preserved instead of reset.}

    ; Fresh challenge (not a retry) resets the overlay-retry budget.
    If !abIsRetry
        OverlayRetryCount = 0
    EndIf

    ; Belt-and-suspenders: guarantee the choice listener is live before the
    ; popup opens (idempotent — RegisterForModEvent dedups). Covers any save
    ; where neither OnInit nor Init's load router ran this session.
    RegisterForModEvent("SeverActions_BrawlChallengeChoice", "OnBrawlPromptChoice")

    String challengerName = akChallenger.GetDisplayName()

    ; A fresh challenge supersedes any stale prompt. Clear a leftover PrismaUI
    ; overlay AND any pending SkyMessage box first, so a stale "prompt open" flag
    ; from a prior challenge that never closed can't shove a PrismaUI user onto
    ; the Papyrus message box (Tier 2). ClosePromptSilent clears the open flag
    ; and unfocuses the view synchronously, so the Tier-1 open below sees a clean
    ; slate.
    If SeverActionsNative.PrismaUI_IsBrawlPromptOpen()
        SeverActionsNative.PrismaUI_CloseBrawlPrompt()
        Debug.Trace("[SeverBrawl] ShowPlayerChallengePopup: cleared stale PrismaUI brawl prompt before reopening")
    EndIf
    If PendingPopupId != 0
        SkyMessage.Delete(PendingPopupId)
        PendingPopupId = 0
    EndIf

    ; Tier 1 — PrismaUI overlay. Availability is no longer gated on "not already
    ; open" (we just cleared any stale prompt); only a genuine open failure
    ; (another PrismaUI view holding focus, or a bridge error) drops through to
    ; the SkyMessage fallback below.
    If SeverActionsNative.PrismaUI_IsBrawlPromptAvailable()
        Int timeoutMs = (PendingChallengeExpiry * 1000) as Int
        If SeverActionsNative.PrismaUI_OpenBrawlPrompt(akChallenger, challengerName, timeoutMs)
            ; Choice arrives asynchronously via OnBrawlPromptChoice. No
            ; chronometer-tick poll needed — the native bridge owns the timer and
            ; ModEvent dispatch.
            OverlayRetryCount = 0
            PendingOverlayChallenger = None
            Debug.Trace("[SeverBrawl] ShowPlayerChallengePopup: PrismaUI overlay opened")
            Return
        EndIf
        ; Open failed — almost always because another PrismaUI view (e.g. the
        ; SeverActions config menu this challenge was launched from) still holds
        ; focus and hasn't finished closing. Defer and retry a few times so the
        ; overlay wins once focus is released, instead of dropping to SkyMessage.
        ; 6 x 0.25s = up to ~1.5s grace for the menu to close.
        If OverlayRetryCount < 6
            OverlayRetryCount += 1
            PendingOverlayChallenger = akChallenger
            ChronoArm(0.25)
            Debug.Trace("[SeverBrawl] ShowPlayerChallengePopup: overlay suppressed (a view has focus); deferring retry " + OverlayRetryCount + "/6")
            Return
        EndIf
        OverlayRetryCount = 0
        PendingOverlayChallenger = None
        Debug.Trace("[SeverBrawl] ShowPlayerChallengePopup: overlay retries exhausted - SkyMessage fallback")
    EndIf

    ; Tier 2 — SkyMessage fallback.
    String body = challengerName + " squares up and challenges you to a brawl. Fists only - no weapons, no spells."
    Int boxId = SkyMessage.Show_NonBlocking(body, "Accept", "Decline")
    If boxId != 0
        PendingPopupId = boxId
        PendingPopupChallenger = akChallenger
        PendingPopupStartTime = Utility.GetCurrentRealTime()
        ChronoArm(PopupPollIntervalSec)
        Debug.Trace("[SeverBrawl] ShowPlayerChallengePopup: SkyMessage fallback engaged")
        Return
    EndIf

    ; Tier 3 — no popup mod installed. Notify and let expiry handle it.
    Debug.Notification(challengerName + " challenges you to a brawl. Speak to them to accept or decline. (Install PrismaUI or Papyrus MessageBox for a proper prompt.)")
EndFunction

Event OnBrawlPromptChoice(String asEventName, String asChoice, Float afNumArg, Form akSender)
    {Native fired SeverActions_BrawlChallengeChoice. sender = challenger,
     strArg = "accept" or "decline". Dispatch to the existing Execute paths.}
    Actor challenger = akSender as Actor
    If !challenger
        Debug.Trace("[SeverBrawl] OnBrawlPromptChoice: sender is not an Actor - ignoring")
        Return
    EndIf
    Actor player = Game.GetPlayer()
    Debug.Trace("[SeverBrawl] OnBrawlPromptChoice: " + asChoice + " from " + challenger.GetDisplayName())
    If asChoice == "accept"
        AcceptBrawl_Execute(player, challenger)
    ElseIf asChoice == "decline"
        DeclineBrawl_Execute(player, challenger)
    EndIf
EndEvent

Function ChronoArm(Float afSeconds)
    {Arm this script's one-shot chronometer tick - replaces the FORM-keyed
     RegisterForSingleUpdate (canonical explanation: the Chronometer block in
     SeverActionsNativeExt2.psc + the CLAUDE.md lesson). Event name AND
     callback name are unique per script - both, always. Re-arm replaces the
     pending tick; ticks do NOT survive save/load (load paths re-arm); at
     most one already-in-flight wake can land after Cancel/Clear, so keep
     the handler state-guarded.}
    RegisterForModEvent("SeverActions_Tick_Brawl", "OnChronoTick_Brawl")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_Brawl", afSeconds)
EndFunction

Event OnChronoTick_Brawl(String eventName, String strArg, Float numArg, Form sender)
    ; Process any pending track-only re-recruits first — independent of the
    ; popup-poll loop so both can coexist. Cheap when no queue is pending
    ; (single FormListCount read).
    ProcessPendingRerecruit()

    ; Pending PrismaUI-overlay retry — the menu that launched the challenge
    ; needed a moment to release focus. Re-attempt the popup chain (preserving
    ; the retry counter); it either opens the overlay, schedules another retry,
    ; or finally falls to the SkyMessage box.
    If PendingOverlayChallenger != None
        Actor overlayChallenger = PendingOverlayChallenger as Actor
        PendingOverlayChallenger = None
        If overlayChallenger
            ShowPlayerChallengePopup(overlayChallenger, true)
        EndIf
        Return
    EndIf

    If PendingPopupId == 0
        Return
    EndIf

    ; Timeout — auto-decline if too long.
    Float elapsed = Utility.GetCurrentRealTime() - PendingPopupStartTime
    If elapsed > PendingChallengeExpiry
        Debug.Trace("[SeverBrawl] Popup: timed out, auto-declining")
        SkyMessage.Delete(PendingPopupId)
        ClosePlayerChallengePopup(false)
        Return
    EndIf

    If !SkyMessage.IsMessageResultAvailable(PendingPopupId)
        ChronoArm(PopupPollIntervalSec)
        Return
    EndIf

    Int idx = SkyMessage.GetResultIndex(PendingPopupId)
    ClosePlayerChallengePopup(idx == 0)
EndEvent

Function ClosePlayerChallengePopup(Bool bAccepted)
    Actor challenger = PendingPopupChallenger as Actor
    PendingPopupId = 0
    PendingPopupChallenger = None
    PendingPopupStartTime = 0.0

    If !challenger
        Return
    EndIf
    Actor player = Game.GetPlayer()
    If bAccepted
        AcceptBrawl_Execute(player)
    Else
        DeclineBrawl_Execute(player)
    EndIf
EndFunction

; ============================================================================
; NPC ↔ NPC FOLLOW-AND-WAIT
; ============================================================================

Function StartChallengeFollow(Actor akChallenger, Actor akTarget)
    {Apply a follow package to the challenger so they trail the target until
     the target picks Accept/Decline. Native BrawlChallengeMonitor enforces
     timeout / distance / death via SeverActions_BrawlChallengeExpired event.

     We reuse SeverActions_GuardFollowPlayer + SeverActions_FollowTargetKW —
     they're the existing generic LinkedRef follow infra from the arrest
     persuasion system. Visual quirk: that package has the WeaponDrawn flag.
     Acceptable for v2; a fist-only variant can be cloned later.}

    ; Resolve the follow package + keyword by FormID to avoid pulling
    ; SeverActions_Arrest into the import chain (it transitively pulls
    ; SeverActions_ArrestPlayer / Debt which have pre-existing compile errors
    ; in this branch). The FormIDs are stable — SeverActions.esp 030155 and
    ; 0AEAF6.
    Keyword followKW = Game.GetFormFromFile(0x030155, "SeverActions.esp") as Keyword
    Package followPkg = Game.GetFormFromFile(0x0AEAF6, "SeverActions.esp") as Package
    If followKW && followPkg
        SeverActionsNative.LinkedRef_Set(akChallenger, akTarget, followKW)
        ActorUtil.AddPackageOverride(akChallenger, followPkg, 75, 1)
        akChallenger.EvaluatePackage()
        Debug.Trace("[SeverBrawl] Follow package applied to " + akChallenger.GetDisplayName())
    Else
        Debug.Trace("[SeverBrawl] No follow package available - challenge will not actively trail target")
    EndIf

    SeverActionsNative.Native_BrawlChallenge_Begin(akChallenger, akTarget, \
        PendingChallengeExpiry, ChallengeFollowDistance)
EndFunction

Function StopChallengeFollow(Actor akChallenger)
    If !akChallenger
        Return
    EndIf
    Keyword followKW = Game.GetFormFromFile(0x030155, "SeverActions.esp") as Keyword
    Package followPkg = Game.GetFormFromFile(0x0AEAF6, "SeverActions.esp") as Package
    If followPkg
        ActorUtil.RemovePackageOverride(akChallenger, followPkg)
    EndIf
    If followKW
        SeverActionsNative.LinkedRef_Clear(akChallenger, followKW)
    EndIf
    akChallenger.EvaluatePackage()
EndFunction

Event OnChallengeExpired(String eventName, String strArg, Float numArg, Form sender)
    {Native fired SeverActions_BrawlChallengeExpired. sender = target,
     strArg = "timeout"|"died"|"distance". Auto-decline on the target's behalf
     and clean up the challenger's follow package.

     We prefer Native_BrawlChallenge_GetLastExpiredChallenger over the
     StorageUtil ChallengeFrom key because the latter can be cleared
     out-of-band (DeclineBrawl_Execute runs ClearChallengeState first),
     which would leave us with no handle on the actor holding the package
     override and LinkedRef keyword.}
    Actor target = sender as Actor
    If !target
        Return
    EndIf
    Actor challenger = SeverActionsNative.Native_BrawlChallenge_GetLastExpiredChallenger()
    If !challenger
        ; Native getter raced or cleared. Fall back to StorageUtil; if that
        ; is also empty we lose the follow-package cleanup handle.
        challenger = StorageUtil.GetFormValue(target, "SeverBrawl_ChallengeFrom") as Actor
    EndIf
    Debug.Trace("[SeverBrawl] Challenge expired (" + strArg + ") for " + target.GetDisplayName() + " (challenger=" + challenger + ")")
    If challenger
        StopChallengeFollow(challenger)
    EndIf
    ; Pass the RESOLVED challenger explicitly (audit #419): the target's
    ; single ChallengeFrom slot may already hold a NEWER challenger, and the
    ; no-arg path would decline THAT still-live challenge and misattribute
    ; the brawl_declined event to the wrong pair.
    DeclineBrawl_Execute(target, challenger)
EndEvent

; ============================================================================
; ACCEPT
; ============================================================================

Function AcceptBrawl_Execute(Actor akAccepter, Actor akChallenger = None)
{Speaker engages in a fist-fight against a specific opponent. Two entry paths:

   1. Pending-challenge path: akChallenger is None. We read it from the
      StorageUtil ChallengeFrom key that ChallengeBrawl_Execute wrote.

   2. Direct-start path: akChallenger is provided. This is how the
      player-via-dialogue and NPC↔NPC scenes start brawls without needing a
      ChallengeBrawl action to fire first — the LLM on the accepter just
      names the other fighter directly. No StorageUtil round-trip needed.

   The expiry check only applies to path 1, since path 2 has no recorded
   issue time. Both paths converge on the same Brawl_Begin + StartCombat
   sequence and the same cleanup (clear pending state, drop follow package,
   clear native challenge monitor entries).}

    If !akAccepter
        Return
    EndIf

    Actor challenger = akChallenger
    Bool fromPending = False
    If !challenger
        challenger = StorageUtil.GetFormValue(akAccepter, "SeverBrawl_ChallengeFrom") as Actor
        fromPending = challenger != None
    EndIf
    If !challenger
        Debug.Trace("[SeverBrawl] Accept: no challenger provided and none pending for " + akAccepter.GetDisplayName())
        Return
    EndIf
    If challenger == akAccepter
        Debug.Trace("[SeverBrawl] Accept: cannot brawl self")
        Return
    EndIf
    If challenger.IsDead() || akAccepter.IsDead()
        ClearChallengeState(challenger, akAccepter)
        Return
    EndIf
    If SeverActionsNativeExt.Brawl_IsActive(akAccepter) || SeverActionsNativeExt.Brawl_IsActive(challenger)
        Debug.Trace("[SeverBrawl] Accept: at least one party already brawling")
        ClearChallengeState(challenger, akAccepter)
        Return
    EndIf

    ; Expiry check applies only to pending-challenge path.
    If fromPending
        Float issuedAt = StorageUtil.GetFloatValue(akAccepter, "SeverBrawl_ChallengeTime", 0.0)
        Float now = Utility.GetCurrentRealTime()
        If issuedAt > 0.0 && (now - issuedAt) > PendingChallengeExpiry
            Debug.Trace("[SeverBrawl] Accept: challenge expired")
            ClearChallengeState(challenger, akAccepter)
            Return
        EndIf
    EndIf

    ClearChallengeState(challenger, akAccepter)

    ; Clear native expiry monitor + drop the challenger's follow package
    ; before BrawlBegin — the brawl itself owns the engine state from here.
    ; EndForActor erases any monitor entry where either side matches, so a
    ; single call covers both challenger and accepter.
    SeverActionsNative.Native_BrawlChallenge_EndForActor(challenger)
    StopChallengeFollow(challenger)

    Bool started = SeverActionsNativeExt.Brawl_Begin(challenger, akAccepter)
    If !started
        Debug.Trace("[SeverBrawl] Accept: native Brawl_Begin rejected")
        Return
    EndIf

    ; Strip IsPlayerTeammate on any brawling follower BEFORE StartCombat so
    ; the engine never sees a "teammate under attack" signal that would
    ; trigger other followers' protection AI. Restored in OnBrawlEnded.
    StripTeammateForBrawl(challenger)
    StripTeammateForBrawl(akAccepter)

    ; NFF-teardown settle (field: round 1 vs round 2). The strip above may
    ; have just dismissed an NFF brawler, and that teardown is ASYNCHRONOUS -
    ; round 1 engaged one second after release and died as NFF finished
    ; letting go, while a manual re-fire against the already-dismissed actor
    ; stuck immediately. Give the framework a beat BEFORE StartCombat below.
    ; Placed AFTER the strips because the WasNFF marker is what the strip
    ; sets - checking it before Begin read a key that did not exist yet.
    ; Only paid when an NFF release actually happened this accept.
    If StorageUtil.GetIntValue(challenger, "SeverBrawl_WasNFF", 0) == 1 || StorageUtil.GetIntValue(akAccepter, "SeverBrawl_WasNFF", 0) == 1
        Debug.Trace("[SeverBrawl] Accept: NFF release in flight - settling 2.0s before combat")
        Utility.Wait(2.0)
    EndIf

    ; Give the native-side hand-slot unequip + sheath a tick to settle
    ; before kicking combat. Without this, StartCombat can race the engine's
    ; hand-state refresh and the actor draws back into a half-equipped pose
    ; (the "Daegon stands there holding Flames" symptom).
    Utility.Wait(0.15)

    ; Belt-and-suspenders: walk both hand slots and force-unequip whatever
    ; spell is still there from Papyrus, then re-evaluate the package. The
    ; native side already attempted this with the correct BGSEquipSlot, but
    ; some NPC-base loadouts have the spell re-attached at combat-start;
    ; this catches that re-equip window.
    ; Both fighters, both hands. HandsClean handles mid-fight wardrobe
    ; re-equips; this belt just covers brawl START.
    Int hand = 0
    While hand < 2
        Spell rhSpell = challenger.GetEquippedSpell(hand)
        If rhSpell
            challenger.UnequipSpell(rhSpell, hand)
        EndIf
        Spell lhSpell = akAccepter.GetEquippedSpell(hand)
        If lhSpell
            akAccepter.UnequipSpell(lhSpell, hand)
        EndIf
        hand += 1
    EndWhile
    challenger.EvaluatePackage()
    akAccepter.EvaluatePackage()

    ; Native does the engine-state prep; Papyrus drives StartCombat (not a
    ; CommonLibSSE-NG direct member on Actor).
    challenger.StartCombat(akAccepter)
    Utility.Wait(0.1)
    akAccepter.StartCombat(challenger)

    SkyrimNetApi.RegisterEvent("brawl_accepted", \
        akAccepter.GetDisplayName() + " accepted " + challenger.GetDisplayName() + "'s brawl challenge", \
        akAccepter, challenger)

    Debug.Trace("[SeverBrawl] Accept: brawl begun " + challenger.GetDisplayName() + " vs " + akAccepter.GetDisplayName())
EndFunction

; ============================================================================
; DECLINE
; ============================================================================

Function DeclineBrawl_Execute(Actor akDecliner, Actor akChallenger = None)
{Speaker brushes off a brawl challenge. Same two paths as AcceptBrawl:
   1. Pending-challenge path: read challenger from StorageUtil.
   2. Direct: caller names the challenger explicitly (dialogue context).
 Either way: clear state, drop follow package, stop the native expiry
 monitor, fire a SkyrimNet brawl_declined event.}
    ; Re-entrancy (review finding): Accept sleeps ~2.25s between Brawl_Begin
    ; and StartCombat (the NFF settle), and Papyrus yields on Wait - a
    ; Decline landing in that window would narrate a decline for a brawl
    ; that is actually mid-start. Mirror Accept's own guard.
    If akDecliner && SeverActionsNativeExt.Brawl_IsActive(akDecliner)
        Debug.Trace("[SeverBrawl] Decline ignored: " + akDecliner.GetDisplayName() + " is mid-brawl")
        Return
    EndIf

    If !akDecliner
        Return
    EndIf
    Actor challenger = akChallenger
    If !challenger
        challenger = StorageUtil.GetFormValue(akDecliner, "SeverBrawl_ChallengeFrom") as Actor
    EndIf
    ClearChallengeState(challenger, akDecliner)
    SeverActionsNative.Native_BrawlChallenge_EndForActor(akDecliner)
    If challenger
        StopChallengeFollow(challenger)
        SkyrimNetApi.RegisterEvent("brawl_declined", \
            akDecliner.GetDisplayName() + " declined " + challenger.GetDisplayName() + "'s brawl challenge", \
            akDecliner, challenger)
    EndIf
EndFunction

; ============================================================================
; FORFEIT (mid-brawl give-up)
; ============================================================================

Function ForfeitBrawl_Execute(Actor akForfeiter)
{Speaker forfeits an active brawl. Native side restores state and fires
 SeverBrawl_Ended with reason=Forfeit. The OTHER participant wins.}

    If !akForfeiter
        Return
    EndIf
    If !SeverActionsNativeExt.Brawl_IsActive(akForfeiter)
        Debug.Trace("[SeverBrawl] Forfeit: " + akForfeiter.GetDisplayName() + " not in a brawl")
        Return
    EndIf

    ; reason=2 (Forfeit). Native fires SeverBrawl_Ended which our handler
    ; turns into a SkyrimNet brawl_ended event with the right winner/loser
    ; AND writes the SeverBrawl_LastWinner/LastLoser mirror keys on both
    ; sides — no need to duplicate those writes here.
    SeverActionsNativeExt.Brawl_End(akForfeiter, 2)
EndFunction

; ============================================================================
; HELPERS
; ============================================================================

; ============================================================================
; TEAMMATE-FLAG STRIP / RESTORE (root fix for follower-vs-NPC brawl bug)
; ============================================================================
; When a follower (non-player) brawls another NPC, the player's OTHER
; followers' teammate-defense AI fires because their fellow teammate is being
; hit. DGIntimidateFaction membership controls factional hostility — it does
; NOT gate the teammate-protection path, which is keyed on IsPlayerTeammate().
; We temporarily clear the flag on each brawler so the engine no longer sees
; them as "an ally to defend". TeammateMonitor on the native side suppresses
; the removal event AND keeps them tracked while the brawl is active, so the
; restore at brawl-end doesn't surface as a spurious re-onboarding.
;
; Markers live in StorageUtil per-actor (SeverBrawl_WasTeammate=1) and in a
; per-quest formlist (SeverBrawl_StrippedTeammates) used by the load path
; (RestoreStrippedTeammatesAfterReload) to recover from mid-brawl saves.

Function StripTeammateForBrawl(Actor a)
    If !a || a == Game.GetPlayer()
        Return
    EndIf
    ; Strip the participant's teammate flag for the brawl. This is what stops
    ; the player's OTHER followers from treating the fight as "a teammate is
    ; under attack" and piling in — the C++ DGIntimidateFaction spectator
    ; pacification alone does NOT prevent that. Tracking-only followers are
    ; stripped too (their framework reads it as a dismiss); they're re-recruited
    ; at brawl end via the SeverBrawl_PendingRerecruit queue.
    If a.IsPlayerTeammate()
        StorageUtil.SetIntValue(a, "SeverBrawl_WasTeammate", 1)
        StorageUtil.FormListAdd(self, "SeverBrawl_StrippedTeammates", a, False)
        a.SetPlayerTeammate(false, false)
        Debug.Trace("[SeverBrawl] StripTeammateForBrawl: cleared IsPlayerTeammate on " + a.GetDisplayName())
    EndIf
    ; NFF release (Idolaf field report): stripping the teammate flag is NOT
    ; enough for an NFF-managed brawler - NFF holds them in its own quest
    ; ALIAS, and its aggro suppression / never-fight-the-player behaviour
    ; rides that seat regardless of any flag we clear. StartCombat against
    ; the player was silently dropped and the watchdog aborted at 10s, twice.
    ; There is no off-switch for the suppression from our side, so route
    ; through NFF's own controller per the standing rule: dismiss for the
    ; fight, and RestoreTeammateAfterBrawl re-recruits (RegisterFollower ->
    ; NFFRecruit) via the existing PendingRerecruit queue. WasNFF marks the
    ; re-recruit, because after the dismissal IsTrackOnlyFollower may no
    ; longer answer true for this actor.
    If SeverActionsNativeExt2.Native_IsNFFManaged(a)
        SeverActions_FollowerManager fmStrip = SeverActions_FollowerManager.GetInstance()
        If fmStrip
            ; PRIMARY route (owner's suggestion): NFF's OWN spar mechanic.
            ; nwsFF_SparFac membership is how NFF exempts a follower from its
            ; protection logic during ITS spars - joining it uses the designed
            ; door instead of dismissing through the whole framework. Fallback
            ; when the property is absent (older NFF): dismiss for the fight,
            ; re-recruited at restore via PendingRerecruit.
            ; FIELD RESULT (Idolaf, three rounds): the spar faction alone is
            ; NOT the whole exemption. With it applied, combat engaged exactly
            ; once and NFF killed the combat state within seconds every time
            ; after - its spar flow evidently sets script-side state we cannot
            ; reach from outside. So DISMISSAL is the primary (the alias seat
            ; is the one lever that provably ends its suppression), and the
            ; faction join stays as a harmless belt for the teardown window.
            ; The existing PendingRerecruit machinery re-seats NFF at brawl
            ; end either way.
            Faction sparFac = fmStrip.NFFSparFaction()
            If sparFac
                StorageUtil.SetIntValue(a, "SeverBrawl_NFFSparFac", 1)
                a.AddToFaction(sparFac)
            EndIf
            StorageUtil.SetIntValue(a, "SeverBrawl_WasNFF", 1)
            ; SILENT, and canonical: decompiling nwsFollower_Sparring proves
            ; dismissal-for-the-fight is NFF's OWN spar mechanism (SparPrep
            ; dismisses, SparEnd RecruitActions back) - this is not a
            ; workaround, it is the framework's sanctioned flow, with its own
            ; silent (-1, 0) dismissal arguments.
            fmStrip.NFFDismiss(a, true)
            fmStrip.InvalidateTrackOnlyCache(a)
            Debug.Trace("[SeverBrawl] StripTeammateForBrawl: released " + a.GetDisplayName() + " from NFF for the brawl (dismissal primary, sparFac=" + (sparFac != None) + ")")
        EndIf
    EndIf
EndFunction

Function RestoreTeammateAfterBrawl(Actor a)
    If !a || a == Game.GetPlayer()
        Return
    EndIf
    If StorageUtil.GetIntValue(a, "SeverBrawl_WasTeammate", 0) == 1
        ; Restore the teammate flag immediately. This is what stops our own
        ; native TeammateMonitor from reading the brawl strip as a vanilla
        ; dismiss and queuing a (racing) untrack — leaving it false caused the
        ; "re-recruited then lost tracking again" flicker.
        a.SetPlayerTeammate(true, false)
        StorageUtil.UnsetIntValue(a, "SeverBrawl_WasTeammate")
        StorageUtil.FormListRemove(self, "SeverBrawl_StrippedTeammates", a, True)

        ; The flag alone won't make a tracking-only follower follow again: their
        ; owning framework (NFF / SPID custom-AI controller / Daegon's quest /
        ; DLC like Serana) already cleared its own alias during the strip window.
        ; Queue a real re-recruit — RegisterFollower (the same call the wheel's
        ; SetCompanion uses) re-engages the framework. Full-SA followers stay
        ; registered through the brawl, so the flag restore above is all they need.
        SeverActions_FollowerManager fm = SeverActions_FollowerManager.GetInstance()
        ; Spar-faction route: just leave NFF's spar faction again. No dismiss
        ; happened, so no re-recruit is owed. We remove the membership OURSELVES
        ; rather than calling the controller's SparEnd - that function services
        ; NFF's own spar flow, whose state we never entered.
        If StorageUtil.GetIntValue(a, "SeverBrawl_NFFSparFac", 0) == 1
            StorageUtil.UnsetIntValue(a, "SeverBrawl_NFFSparFac")
            If fm
                Faction sparFacR = fm.NFFSparFaction()
                If sparFacR
                    a.RemoveFromFaction(sparFacR)
                    Debug.Trace("[SeverBrawl] RestoreTeammateAfterBrawl: " + a.GetDisplayName() + " leaves NFF's spar faction")
                EndIf
            EndIf
        EndIf
        Bool wasNFF = StorageUtil.GetIntValue(a, "SeverBrawl_WasNFF", 0) == 1
        If wasNFF
            StorageUtil.UnsetIntValue(a, "SeverBrawl_WasNFF")
        EndIf
        If fm && (wasNFF || fm.IsTrackOnlyFollower(a))
            StorageUtil.FormListAdd(self, "SeverBrawl_PendingRerecruit", a, False)
            Debug.Trace("[SeverBrawl] RestoreTeammateAfterBrawl: queued re-recruit for " + a.GetDisplayName() + " (wasNFF=" + wasNFF + ")")
        EndIf

        Debug.Trace("[SeverBrawl] RestoreTeammateAfterBrawl: restored IsPlayerTeammate on " + a.GetDisplayName())
    EndIf
EndFunction

Function ProcessPendingRerecruit()
{Runs from OnChronoTick_Brawl after the TrackOnlyRerecruitDelay window. Walks the
 SeverBrawl_PendingRerecruit formlist and calls RegisterFollower on each
 queued track-only follower — unconditionally. Every actor in this queue was
 stripped for the brawl and is tracking-only, so their framework treated the
 strip as a dismiss; re-recruiting is exactly what the wheel's SetCompanion
 does, and RegisterFollower is idempotent on an already-following actor.
 (Earlier this gated on !IsPlayerTeammate, but RestoreTeammateAfterBrawl had
 already flipped the flag back on, so the gate always read "still teammate"
 and the re-recruit never fired — the bug this fixes.)}
    Int n = StorageUtil.FormListCount(self, "SeverBrawl_PendingRerecruit")
    If n <= 0
        Return
    EndIf
    SeverActions_FollowerManager fm = SeverActions_FollowerManager.GetInstance()
    If !fm
        Debug.Trace("[SeverBrawl] ProcessPendingRerecruit: FollowerManager instance unavailable, deferring")
        Return
    EndIf
    Int i = 0
    While i < n
        Form f = StorageUtil.FormListGet(self, "SeverBrawl_PendingRerecruit", i)
        Actor a = f as Actor
        If a && a != Game.GetPlayer() && !a.IsDead()
            fm.RegisterFollower(a)
            Debug.Trace("[SeverBrawl] ProcessPendingRerecruit: re-recruited track-only " + a.GetDisplayName())
        EndIf
        i += 1
    EndWhile
    StorageUtil.FormListClear(self, "SeverBrawl_PendingRerecruit")
EndFunction

Function RestoreStrippedTeammatesAfterReload()
    Int n = StorageUtil.FormListCount(self, "SeverBrawl_StrippedTeammates")
    If n <= 0
        Return
    EndIf
    Debug.Trace("[SeverBrawl] RestoreStrippedTeammatesAfterReload: recovering " + n + " stripped teammate marker(s)")
    Int i = 0
    While i < n
        Form f = StorageUtil.FormListGet(self, "SeverBrawl_StrippedTeammates", i)
        Actor a = f as Actor
        If a && a != Game.GetPlayer() && !a.IsDead()
            a.SetPlayerTeammate(true, false)
            StorageUtil.UnsetIntValue(a, "SeverBrawl_WasTeammate")
            ; Spar-faction cleanup on the load path too - the StorageUtil
            ; marker persists, and factions persist in the save.
            If StorageUtil.GetIntValue(a, "SeverBrawl_NFFSparFac", 0) == 1
                StorageUtil.UnsetIntValue(a, "SeverBrawl_NFFSparFac")
                SeverActions_FollowerManager fmSpar = SeverActions_FollowerManager.GetInstance()
                If fmSpar
                    Faction sparFacL = fmSpar.NFFSparFaction()
                    If sparFacL
                        a.RemoveFromFaction(sparFacL)
                    EndIf
                EndIf
            EndIf
            ; The flag alone does not re-seat a track-only follower - their
            ; owning framework (NFF et al.) already emptied its alias during
            ; the strip window, and restoring a bool does not refill it. The
            ; sibling path (RestoreTeammateAfterBrawl) has queued this
            ; re-recruit since the "re-recruited then lost tracking again"
            ; fix; this reload path just never got it (issue #412 S1).
            SeverActions_FollowerManager fm = SeverActions_FollowerManager.GetInstance()
            If fm && fm.IsTrackOnlyFollower(a)
                StorageUtil.FormListAdd(self, "SeverBrawl_PendingRerecruit", a, False)
                Debug.Trace("[SeverBrawl] RestoreStrippedTeammatesAfterReload: queued track-only re-recruit for " + a.GetDisplayName())
            EndIf
        EndIf
        i += 1
    EndWhile
    StorageUtil.FormListClear(self, "SeverBrawl_StrippedTeammates")
    ; Drain immediately: the tick delay window exists to let a live brawl
    ; finish cleanly, but on the load path there is no brawl - the strip
    ; markers only survive a save made MID-brawl, and the brawl itself did not.
    ProcessPendingRerecruit()
EndFunction

Function ClearChallengeState(Actor a, Actor b)
    If a
        StorageUtil.FormListRemove(self, "SeverBrawl_OpenChallengers", a, True)
        StorageUtil.UnsetFormValue(a, "SeverBrawl_ChallengeTo")
        StorageUtil.UnsetFormValue(a, "SeverBrawl_ChallengeFrom")
        StorageUtil.UnsetFloatValue(a, "SeverBrawl_ChallengeTime")
    EndIf
    If b
        StorageUtil.UnsetFormValue(b, "SeverBrawl_ChallengeTo")
        StorageUtil.UnsetFormValue(b, "SeverBrawl_ChallengeFrom")
        StorageUtil.UnsetFloatValue(b, "SeverBrawl_ChallengeTime")
    EndIf
EndFunction

; ============================================================================
; NATIVE MOD-EVENT HANDLERS
; ============================================================================

Event OnBrawlStarted(String eventName, String strArg, Float numArg, Form sender)
    {Native fired this when Brawl_Begin succeeded. We write StorageUtil mirror
     keys here so prompts can read brawl state via papyrus_util (the only
     decorator available for arbitrary native-state reads).}
    Actor a = sender as Actor
    If !a
        Return
    EndIf
    Actor b = SeverActionsNativeExt.Brawl_GetOpponent(a)
    StorageUtil.SetIntValue(a, "SeverBrawl_Active", 1)
    StorageUtil.SetFormValue(a, "SeverBrawl_Opponent", b)
    If b
        StorageUtil.SetIntValue(b, "SeverBrawl_Active", 1)
        StorageUtil.SetFormValue(b, "SeverBrawl_Opponent", a)
    EndIf
    Debug.Trace("[SeverBrawl] OnBrawlStarted: " + a.GetDisplayName() + " vs " + b)
EndEvent

Function ClearActiveMirror(Actor a)
    If a
        StorageUtil.UnsetIntValue(a, "SeverBrawl_Active")
        StorageUtil.UnsetFormValue(a, "SeverBrawl_Opponent")
    EndIf
EndFunction

Event OnBrawlEnded(String eventName, String strArg, Float numArg, Form sender)
    {Native fired SeverBrawl_Ended with numArg=reason. Winner/loser come
     from Brawl_GetLastWinner / Brawl_GetLastLoser — FormIDs can't round-trip
     through a Papyrus Int (unsigned-32 vs. signed-32 overflow for light
     plugin FormIDs 0xFEnnXXXX).}

    Int reason = SeverActionsNativeExt.Brawl_GetLastReason()
    Actor winner = SeverActionsNativeExt.Brawl_GetLastWinner()
    Actor loser  = SeverActionsNativeExt.Brawl_GetLastLoser()

    ; Restore IsPlayerTeammate FIRST so the engine sees them as a follower
    ; again before any downstream handlers (cooldown, narration, escalation)
    ; query their status. The native TeammateMonitor was suppressing removal
    ; events for these actors while the brawl was active, so the restore
    ; lands silently — no spurious "new teammate detected" surface.
    ;
    ; Cover every reason-code path: kLoserBleedout sets winner+loser cleanly;
    ; kForfeit too; kBrokenToCombat picks A/B deterministically; kAbort
    ; leaves both at None. For abort we fall back to (sender, sender's
    ; SeverBrawl_Opponent mirror) so neither side stays stripped.
    RestoreTeammateAfterBrawl(winner)
    RestoreTeammateAfterBrawl(loser)
    Actor senderActorEarly = sender as Actor
    If senderActorEarly && senderActorEarly != winner && senderActorEarly != loser
        RestoreTeammateAfterBrawl(senderActorEarly)
        Actor senderOpp = StorageUtil.GetFormValue(senderActorEarly, "SeverBrawl_Opponent") as Actor
        If senderOpp && senderOpp != winner && senderOpp != loser
            RestoreTeammateAfterBrawl(senderOpp)
        EndIf
    EndIf

    ; If any tracking-only followers got queued for re-recruit in the restore
    ; calls above, schedule the tick that processes them after the external
    ; framework has settled its dismiss state.
    If StorageUtil.FormListCount(self, "SeverBrawl_PendingRerecruit") > 0
        ChronoArm(TrackOnlyRerecruitDelay)
    EndIf

    ; Clear active-mirror flags on both sides. By the time we get here the
    ; native side has already torn down the brawl, so Brawl_GetOpponent on
    ; either party returns None — we have to use what we know from sender +
    ; the last-result natives.
    Actor senderActor = sender as Actor
    ; Capture the opponent from the sender's mirror BEFORE clearing it. On
    ; the abort path (reason 5) winner/loser are both None, so the opponent
    ; is only reachable through this mirror -- clearing just sender/winner/
    ; loser left the opponent's SeverBrawl_Active=1 stuck forever and
    ; prompts kept telling that NPC they were mid-brawl. Redundant (and
    ; harmless) on the other reason paths where it matches winner/loser.
    Actor senderOppMirror = None
    If senderActor
        senderOppMirror = StorageUtil.GetFormValue(senderActor, "SeverBrawl_Opponent") as Actor
    EndIf
    ClearActiveMirror(senderActor)
    ClearActiveMirror(winner)
    ClearActiveMirror(loser)
    ClearActiveMirror(senderOppMirror)

    Debug.Trace("[SeverBrawl] OnBrawlEnded reason=" + reason + " winner=" + winner + " loser=" + loser)

    Float endTime = Utility.GetCurrentGameTime()
    If winner
        StorageUtil.SetFormValue(winner, "SeverBrawl_LastWinner", winner)
        StorageUtil.SetFormValue(winner, "SeverBrawl_LastLoser", loser)
        StorageUtil.SetIntValue(winner, "SeverBrawl_LastEndReason", reason)
        StorageUtil.SetFloatValue(winner, "SeverBrawl_LastEndTime", endTime)
        SeverActionsNativeExt.Cooldown_Set(winner, BrawlCooldownDuration)
    EndIf
    If loser
        StorageUtil.SetFormValue(loser, "SeverBrawl_LastWinner", winner)
        StorageUtil.SetFormValue(loser, "SeverBrawl_LastLoser", loser)
        StorageUtil.SetIntValue(loser, "SeverBrawl_LastEndReason", reason)
        StorageUtil.SetFloatValue(loser, "SeverBrawl_LastEndTime", endTime)
        SeverActionsNativeExt.Cooldown_Set(loser, BrawlCooldownDuration)
    EndIf

    String reasonName = "ended"
    If reason == 1
        reasonName = "knockout"
    ElseIf reason == 2
        reasonName = "forfeit"
    ElseIf reason == 3
        reasonName = "walked_away"
    ElseIf reason == 4
        reasonName = "broken_to_combat"
    ElseIf reason == 5
        reasonName = "aborted"
    ElseIf reason == 6
        reasonName = "forfeit - lowered their fists"
    EndIf

    If winner && loser && reason == 6
        ; Sheathe-forfeit: the persistent line says HOW they gave up, so the
        ; NPC can react to the gesture itself (no words were spoken).
        SkyrimNetApi.RegisterEvent("brawl_ended", \
            loser.GetDisplayName() + " lowered their fists and sheathed mid-brawl, conceding to " + winner.GetDisplayName() + " without a word", \
            winner, loser)
    ElseIf winner && loser && reason == 3
        ; Walked away: no concession happened - the fighters just drifted
        ; apart until the engine dropped combat. Native now fills both handles
        ; deterministically (A/B, not victor/vanquished), so word it neutral:
        ; nobody beat anybody, the thing simply fizzled.
        SkyrimNetApi.RegisterEvent("brawl_ended", \
            "the brawl between " + winner.GetDisplayName() + " and " + loser.GetDisplayName() + " fizzled out - they drifted apart with no clear winner", \
            winner, loser)
    ElseIf winner && loser
        SkyrimNetApi.RegisterEvent("brawl_ended", \
            winner.GetDisplayName() + " beat " + loser.GetDisplayName() + " in a brawl (" + reasonName + ")", \
            winner, loser)
    ElseIf loser
        SkyrimNetApi.RegisterEvent("brawl_ended", \
            loser.GetDisplayName() + "'s brawl ended (" + reasonName + ")", \
            loser, None)
    EndIf

    ; Fire a direct-narration prompt so the loser speaks immediately —
    ; otherwise the persistent event sits in the LLM context until the
    ; player next initiates dialogue, which feels like dead air right after
    ; a fight ends. Speaker = loser, target = winner (the loser is the one
    ; reacting to the loss). Only fires for clean outcomes (knockout /
    ; forfeit). Reason 4 (broken_to_combat) skips this — the brawl
    ; escalated into real combat and AttackTarget_Execute takes over below.
    If winner && loser && (reason == 1 || reason == 2 || reason == 6)
        String narration = ""
        If reason == 1
            ; Knockout — loser hit bleedout. They're on the ground catching
            ; their breath. Stage directions only; let the LLM finish the
            ; line in-voice.
            narration = "*" + loser.GetDisplayName() + " drops to one knee, spitting blood, hands raised. The fight's over - they've been bested.*"
        ElseIf reason == 2
            ; Forfeit — loser voluntarily gave up. Less battered, more
            ; pragmatic.
            narration = "*" + loser.GetDisplayName() + " backs off with a hand raised, breathing hard. They've called it - " + winner.GetDisplayName() + " wins this one.*"
        ElseIf reason == 6
            ; Sheathe-forfeit — no words, just the gesture. The WINNER is
            ; the one who has to read it: the player dropped their fists
            ; and stood down.
            narration = "*" + loser.GetDisplayName() + " lowers their fists and steps back, hands open - no words, but the meaning is plain. " + winner.GetDisplayName() + " has won this one.*"
        EndIf
        If narration != ""
            ; Speaker must be an actor SkyrimNet will voice. The loser is the
            ; natural reactor — but when the loser is the PLAYER (sheathe-
            ; forfeit always; knockout/forfeit when the player lost), SkyrimNet
            ; does not voice the player and silently drops the narration (the
            ; dropped-fists dead-air report, 2026-08-24). Flip to the winner:
            ; they read the gesture and answer it.
            If loser == Game.GetPlayer()
                SkyrimNetApi.DirectNarration(narration, winner, loser)
            Else
                SkyrimNetApi.DirectNarration(narration, loser, winner)
            EndIf
        EndIf
    EndIf

    If reason == 4 && winner && loser
        ; Cheating / interference broke the brawl into real combat. Push
        ; both into the regular forced-combat pipeline so AttackTarget-style
        ; cleanup hooks apply.
        SeverActions_Combat.GetInstance().AttackTarget_Execute(winner, loser)
    EndIf
EndEvent
