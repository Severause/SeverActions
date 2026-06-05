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
{Vanilla DGIntimidateFaction — Skyrim.esm 0x0005C84D. Set via CK on the alias
 properties. The kSpecialCombat flag on this faction is what routes brawl
 damage to bleedout instead of death.}

CombatStyle Property csWEBrawler Auto
{Vanilla brawler combat style — Skyrim.esm 0x10555D. Swapped onto NPC actor
 bases for the duration of a brawl so combat AI prefers unarmed.}

Float Property PendingChallengeExpiry = 60.0 Auto
{How long (real-time seconds) a challenge stays pending before auto-expiring.}

Float Property BrawlCooldownDuration = 30.0 Auto
{Cooldown applied to both combatants after a brawl ends — gates re-challenges.}

Float Property ChallengeFollowDistance = 3000.0 Auto
{Native distance check for NPC↔NPC challenge wait — if challenger drifts
 further than this from target, monitor fires expiry with reason="distance".}

Float Property PopupPollIntervalSec = 0.5 Auto
{How often OnUpdate polls SkyMessage for the player's Accept/Decline answer.}

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

; ============================================================================
; STORAGEUTIL KEYS (per-actor, set by this script, read by prompts)
; ============================================================================
; SeverBrawl_ChallengeFrom    - Form (who challenged this actor)
; SeverBrawl_ChallengeTo      - Form (who this actor challenged)
; SeverBrawl_ChallengeTime    - Float (Utility.GetCurrentRealTime() of issue)
; SeverBrawl_LastWinner       - Form (most recent brawl winner against this actor)
; SeverBrawl_LastLoser        - Form (most recent brawl loser against this actor)
; SeverBrawl_LastEndReason    - Int (1=Bleedout, 2=Forfeit, 3=WalkedAway, 4=Broken)
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
    PushBrawlConfigToNative()
EndEvent

Event OnPlayerLoadGame()
    ; Auto-property defaults are baked into existing saves, so a save created
    ; before this value changed keeps the old (slower) delay. Force the current
    ; intended value on every load so the tuning applies to in-progress games,
    ; not just new ones.
    TrackOnlyRerecruitDelay = 1.5
    RegisterForModEvent("SeverBrawl_Ended", "OnBrawlEnded")
    RegisterForModEvent("SeverBrawl_Started", "OnBrawlStarted")
    RegisterForModEvent("SeverActions_BrawlChallengeExpired", "OnChallengeExpired")
    RegisterForModEvent("SeverActions_BrawlChallengeChoice", "OnBrawlPromptChoice")
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
        RegisterForSingleUpdate(TrackOnlyRerecruitDelay)
    EndIf
EndEvent

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

    ; Always record the pending challenge state — every branch reads it.
    StorageUtil.SetFormValue(akChallenger, "SeverBrawl_ChallengeTo", akTarget)
    StorageUtil.SetFormValue(akTarget, "SeverBrawl_ChallengeFrom", akChallenger)
    Float now = Utility.GetCurrentRealTime()
    StorageUtil.SetFloatValue(akChallenger, "SeverBrawl_ChallengeTime", now)
    StorageUtil.SetFloatValue(akTarget, "SeverBrawl_ChallengeTime", now)

    SkyrimNetApi.RegisterEvent("brawl_challenged", \
        akChallenger.GetDisplayName() + " challenged " + akTarget.GetDisplayName() + " to a brawl", \
        akChallenger, akTarget)

    ; Branch 1 — target is the player → SkyMessage popup.
    If akTarget == Game.GetPlayer()
        ShowPlayerChallengePopup(akChallenger)
        Return
    EndIf

    ; Branch 2 — NPC ↔ NPC → follow + monitor.
    StartChallengeFollow(akChallenger, akTarget)

    Debug.Trace("[SeverBrawl] Challenge issued: " + akChallenger.GetDisplayName() + " -> " + akTarget.GetDisplayName())
EndFunction

; ============================================================================
; PLAYER-TARGET POPUP (SkyMessage)
; ============================================================================

Function ShowPlayerChallengePopup(Actor akChallenger)
    {Three-tier popup chain:
       1. PrismaUI HUD overlay (preferred — non-pausing, brass-on-dark card).
       2. SkyMessage non-blocking popup (fallback if PrismaUI absent).
       3. Debug.Notification (last resort if both are absent — challenge
          still auto-expires via the native monitor).}

    String challengerName = akChallenger.GetDisplayName()

    ; Tier 1 — PrismaUI overlay.
    If SeverActionsNative.PrismaUI_IsBrawlPromptAvailable() && !SeverActionsNative.PrismaUI_IsBrawlPromptOpen()
        Int timeoutMs = (PendingChallengeExpiry * 1000) as Int
        If SeverActionsNative.PrismaUI_OpenBrawlPrompt(akChallenger, challengerName, timeoutMs)
            ; Choice arrives asynchronously via OnBrawlPromptChoice. No
            ; OnUpdate poll needed — the native bridge owns the timer and
            ; ModEvent dispatch.
            Debug.Trace("[SeverBrawl] ShowPlayerChallengePopup: PrismaUI overlay opened")
            Return
        EndIf
    EndIf

    ; Tier 2 — SkyMessage fallback.
    String body = challengerName + " squares up and challenges you to a brawl. Fists only — no weapons, no spells."
    Int boxId = SkyMessage.Show_NonBlocking(body, "Accept", "Decline")
    If boxId != 0
        PendingPopupId = boxId
        PendingPopupChallenger = akChallenger
        PendingPopupStartTime = Utility.GetCurrentRealTime()
        RegisterForSingleUpdate(PopupPollIntervalSec)
        Debug.Trace("[SeverBrawl] ShowPlayerChallengePopup: SkyMessage fallback engaged")
        Return
    EndIf

    ; Tier 3 — no popup mod installed. Notify and let expiry handle it.
    Debug.Notification(challengerName + " challenges you to a brawl. (Install PrismaUI or Papyrus MessageBox for the prompt; otherwise the challenge will lapse.)")
EndFunction

Event OnBrawlPromptChoice(String asEventName, String asChoice, Float afNumArg, Form akSender)
    {Native fired SeverActions_BrawlChallengeChoice. sender = challenger,
     strArg = "accept" or "decline". Dispatch to the existing Execute paths.}
    Actor challenger = akSender as Actor
    If !challenger
        Debug.Trace("[SeverBrawl] OnBrawlPromptChoice: sender is not an Actor — ignoring")
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

Event OnUpdate()
    ; Process any pending track-only re-recruits first — independent of the
    ; popup-poll loop so both can coexist. Cheap when no queue is pending
    ; (single FormListCount read).
    ProcessPendingRerecruit()

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
        RegisterForSingleUpdate(PopupPollIntervalSec)
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
        Debug.Trace("[SeverBrawl] No follow package available — challenge will not actively trail target")
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
    DeclineBrawl_Execute(target)
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
; per-quest formlist (SeverBrawl_StrippedTeammates) used by
; OnPlayerLoadGame to recover from mid-brawl saves.

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
        If fm && fm.IsTrackOnlyFollower(a)
            StorageUtil.FormListAdd(self, "SeverBrawl_PendingRerecruit", a, False)
            Debug.Trace("[SeverBrawl] RestoreTeammateAfterBrawl: queued track-only re-recruit for " + a.GetDisplayName())
        EndIf

        Debug.Trace("[SeverBrawl] RestoreTeammateAfterBrawl: restored IsPlayerTeammate on " + a.GetDisplayName())
    EndIf
EndFunction

Function ProcessPendingRerecruit()
{Runs from OnUpdate after the TrackOnlyRerecruitDelay window. Walks the
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
        EndIf
        i += 1
    EndWhile
    StorageUtil.FormListClear(self, "SeverBrawl_StrippedTeammates")
EndFunction

Function ClearChallengeState(Actor a, Actor b)
    If a
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
    ; calls above, schedule the OnUpdate that processes them after the external
    ; framework has settled its dismiss state.
    If StorageUtil.FormListCount(self, "SeverBrawl_PendingRerecruit") > 0
        RegisterForSingleUpdate(TrackOnlyRerecruitDelay)
    EndIf

    ; Clear active-mirror flags on both sides. By the time we get here the
    ; native side has already torn down the brawl, so Brawl_GetOpponent on
    ; either party returns None — we have to use what we know from sender +
    ; the last-result natives.
    Actor senderActor = sender as Actor
    ClearActiveMirror(senderActor)
    ClearActiveMirror(winner)
    ClearActiveMirror(loser)

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
    EndIf

    If winner && loser
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
    If winner && loser && (reason == 1 || reason == 2)
        String narration = ""
        If reason == 1
            ; Knockout — loser hit bleedout. They're on the ground catching
            ; their breath. Stage directions only; let the LLM finish the
            ; line in-voice.
            narration = "*" + loser.GetDisplayName() + " drops to one knee, spitting blood, hands raised. The fight's over — they've been bested.*"
        ElseIf reason == 2
            ; Forfeit — loser voluntarily gave up. Less battered, more
            ; pragmatic.
            narration = "*" + loser.GetDisplayName() + " backs off with a hand raised, breathing hard. They've called it — " + winner.GetDisplayName() + " wins this one.*"
        EndIf
        If narration != ""
            SkyrimNetApi.DirectNarration(narration, loser, winner)
        EndIf
    EndIf

    If reason == 4 && winner && loser
        ; Cheating / interference broke the brawl into real combat. Push
        ; both into the regular forced-combat pipeline so AttackTarget-style
        ; cleanup hooks apply.
        SeverActions_Combat.GetInstance().AttackTarget_Execute(winner, loser)
    EndIf
EndEvent
