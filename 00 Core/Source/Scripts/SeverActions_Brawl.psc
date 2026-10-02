Scriptname SeverActions_Brawl extends Quest
{Fist fights between any two actors. Native BrawlManager owns the engine state (DGIntimidateFaction,
 loadout snapshot, fists-only equip block, bleedout detection); this script holds the Challenge /
 Accept / Decline / Forfeit actions, the pending-challenge state, the teammate strip around a fight
 and the SeverBrawl_* event handlers.}

Faction Property DGIntimidateFaction Auto
{Skyrim.esm 0x0004CFA6, filled by the ESP. Its kSpecialCombat flag routes brawl damage to bleedout
 instead of death.}

CombatStyle Property csWEBrawler Auto
{Skyrim.esm 0x10555D. Applied per reference (ExtraCombatStyle) for the fight, never to the NPC base:
 base writes corrupt shared bases and are ignored on templated NPCs.}

Float Property PendingChallengeExpiry = 60.0 Auto
{How long (real-time seconds) a challenge stays pending before auto-expiring.}

Float Property BrawlCooldownDuration = 30.0 Auto
{Cooldown (real seconds) applied to both combatants after a brawl ends; blocks new challenges and
 AttackTarget between them.}

Float Property ChallengeFollowDistance = 3000.0 Auto
{NPC-to-NPC challenge: a challenger further than this from the target expires the challenge
 (reason "distance").}

Float Property PopupPollIntervalSec = 0.5 Auto
{Chronometer poll interval for the SkyMessage popup's answer.}

Float Property TrackOnlyRerecruitDelay = 1.5 Auto
{Seconds after a brawl ends before re-recruiting a tracking-only follower whose framework (NFF /
 custom-AI / DLC) read the teammate strip as a dismiss. The flag itself is restored at once
 (RestoreTeammateAfterBrawl).}

; SkyMessage popup poll state (transient).
Int Property PendingPopupId = 0 Auto Hidden
Form Property PendingPopupChallenger = None Auto Hidden
Float Property PendingPopupStartTime = 0.0 Auto Hidden

; Magelight overlay defer-retry (transient): a Magelight menu that launched the challenge keeps focus
; for a beat after closing, so the overlay open fails; the tick retries it before falling back.
Form Property PendingOverlayChallenger = None Auto Hidden
Int Property OverlayRetryCount = 0 Auto Hidden

; StorageUtil keys, per actor. Only this script reads them (sever_brawl_state is built natively).
; SeverBrawl_ChallengeFrom    - Form (who challenged this actor)
; SeverBrawl_ChallengeTo      - Form (who this actor challenged)
; SeverBrawl_ChallengeTime    - Float (Utility.GetCurrentRealTime() of issue)
; SeverBrawl_LastWinner       - Form (winner of this actor's last brawl)
; SeverBrawl_LastLoser        - Form (loser of this actor's last brawl)
; SeverBrawl_LastEndReason    - Int (1=Bleedout, 2=Forfeit, 3=WalkedAway, 4=Broken, 5=Abort, 6=ForfeitSheathed - player dropped their fists,
;                               7=CalledOff - a cheat or an outside hit broke a brawl between the player and a companion, or two companions)
; SeverBrawl_LastEndTime      - Float (Utility.GetCurrentGameTime() of end)
; SeverBrawl_Active / _Opponent (live mirror), _WasTeammate / _WasNFF / _NFFSparFac (strip markers).
; On the quest: form lists SeverBrawl_OpenChallengers, _StrippedTeammates, _PendingRerecruit.

SeverActions_Brawl Function GetInstance() Global
    Quest kQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
    Return kQuest as SeverActions_Brawl
EndFunction

Function RegisterEvents()
    {Registers this script's ModEvents and pushes its form properties to BrawlManager. Called from the
     combat provider's stage 0 on every load (DR16: the provider registers nothing itself) and from
     OnInit. Idempotent.}
    RegisterForModEvent("SeverBrawl_Ended", "OnBrawlEnded")
    RegisterForModEvent("SeverBrawl_Started", "OnBrawlStarted")
    RegisterForModEvent("SeverActions_BrawlChallengeExpired", "OnChallengeExpired")
    RegisterForModEvent("SeverActions_BrawlChallengeChoice", "OnBrawlPromptChoice")
    RegisterForModEvent("SeverBrawl_Rekick", "OnBrawlRekick")
    RegisterForModEvent("SeverBrawl_HandsClean", "OnBrawlHandsClean")
    PushBrawlConfigToNative()
EndFunction

Event OnInit()
    RegisterEvents()
EndEvent

Event OnBrawlHandsClean(String eventName, String strArg, Float numArg, Form sender)
    {A brawler had a spell equipped mid-fight. Native routes spell equips here: a SpellItem is not a
     TESBoundObject, so UnequipObject cannot touch it, while Papyrus UnequipSpell works on NPCs and
     the player.}
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
    {The engagement watchdog found the pair not in mutual combat at half its window: re-issue
     StartCombat (an NFF brawler's alias teardown is async and can swallow the first one). Opponent
     rides strArg as signed decimal for GetFormEx, never the float numArg.}
    Actor a = sender as Actor
    Actor b = Game.GetFormEx(strArg as Int) as Actor
    If a && b && !a.IsDead() && !b.IsDead()
        Debug.Trace("[SeverBrawl] Rekick: re-issuing StartCombat " + a.GetDisplayName() + " <-> " + b.GetDisplayName())
        ; The engine refuses Actor.StartCombat called on the player.
        If a != Game.GetPlayer()
            a.StartCombat(b)
        EndIf
        If b != Game.GetPlayer()
            b.StartCombat(a)
        EndIf
    EndIf
EndEvent

Function OnGameLoaded()
    {Load recovery, called on every load from the combat provider's stage 1 (quest scripts never get
     OnPlayerLoadGame): drops popup and challenge state from before the save, restores brawl-stripped
     teammates and re-arms the tick.}
    ; One idempotent wake: pending ticks do not survive save/load, so this resumes a popup poll or
    ; re-recruit drain in flight at the save. Not listed in ChronoTickNames (K4): it ticks only while
    ; there is work.
    ChronoArm(1.0)
    ; Auto-property defaults are baked into saves; force the current value.
    TrackOnlyRerecruitDelay = 1.5
    ; No RegisterEvents here: the provider's stage 0 already ran it.
    ; SkyMessage box ids are process-lifetime, invalid after a reload.
    PendingPopupId = 0
    PendingPopupChallenger = None
    PendingPopupStartTime = 0.0
    ; The Magelight view survives the load, its challenger does not.
    If SeverActionsNative.Magelight_IsBrawlPromptOpen()
        SeverActionsNative.Magelight_CloseBrawlPrompt()
    EndIf
    ; The native expiry monitor is not cosaved, but the challenger's follow package, LinkedRef (LREF)
    ; and StorageUtil keys are: an open challenge would trail the target forever. Clear them all.
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
    ; Brawls are not cosaved, but a save made mid-brawl keeps the stripped IsPlayerTeammate flag and
    ; our strip markers: put them back.
    RestoreStrippedTeammatesAfterReload()
    ; A save inside the TrackOnlyRerecruitDelay window lost its tick; re-arm it.
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

; ---- Challenge ----

Function ChallengeBrawl_Execute(Actor akChallenger, Actor akTarget)
{Speaker issues a fist-fight challenge. Player target: ShowPlayerChallengePopup. NPC target: record
 the pending challenge, the challenger trails the target under the native expiry monitor, and the
 target's next SkyrimNet prompt carries ANSWER REQUIRED.}

    ; Logged before any early return: no ENTRY line means SkyrimNet never dispatched the action.
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
    ; Either party on a journey: a challenger cannot trail anyone off it, and a target would be
    ; pulled into a fight mid-trip.
    If SeverActionsNativeExt2.Travel_GetPhaseByActor(akChallenger) > 0 || SeverActionsNativeExt2.Travel_GetPhaseByActor(akTarget) > 0
        Debug.Trace("[SeverBrawl] Challenge REJECTED: a party is traveling")
        Return
    EndIf
    ; A new target is a change of mind, not an error: cancel the pending outbound challenge, since the
    ; native monitor is keyed by challenger and a second Begin would orphan the first target's expiry.
    Actor priorTarget = StorageUtil.GetFormValue(akChallenger, "SeverBrawl_ChallengeTo") as Actor
    If priorTarget && priorTarget != akTarget
        Debug.Trace("[SeverBrawl] Cancelling prior challenge " + akChallenger.GetDisplayName() + " -> " + priorTarget.GetDisplayName())
        StopChallengeFollow(akChallenger)
        ClearChallengeState(akChallenger, priorTarget)
    EndIf
    ; Post-brawl cooldown (Cooldown_Set in OnBrawlEnded).
    If SeverActionsNativeExt.Cooldown_IsActive(akChallenger) || SeverActionsNativeExt.Cooldown_IsActive(akTarget)
        Debug.Trace("[SeverBrawl] Challenge REJECTED: post-brawl cooldown active")
        Return
    EndIf

    ; Every branch reads the pending state. The quest list is what the load sweep walks.
    StorageUtil.FormListAdd(self, "SeverBrawl_OpenChallengers", akChallenger, False)
    StorageUtil.SetFormValue(akChallenger, "SeverBrawl_ChallengeTo", akTarget)
    StorageUtil.SetFormValue(akTarget, "SeverBrawl_ChallengeFrom", akChallenger)
    Float now = Utility.GetCurrentRealTime()
    StorageUtil.SetFloatValue(akChallenger, "SeverBrawl_ChallengeTime", now)
    StorageUtil.SetFloatValue(akTarget, "SeverBrawl_ChallengeTime", now)

    SkyrimNetApi.RegisterEvent("brawl_challenged", \
        akChallenger.GetDisplayName() + " challenged " + akTarget.GetDisplayName() + " to a brawl", \
        akChallenger, akTarget)

    ; Player target: popup.
    If akTarget == Game.GetPlayer()
        ShowPlayerChallengePopup(akChallenger)
        Return
    EndIf

    ; NPC target: follow + monitor.
    StartChallengeFollow(akChallenger, akTarget)

    Debug.Trace("[SeverBrawl] Challenge issued: " + akChallenger.GetDisplayName() + " -> " + akTarget.GetDisplayName())
EndFunction

; ---- Player-target popup ----

Function ShowPlayerChallengePopup(Actor akChallenger, Bool abIsRetry = false)
    {Magelight overlay (native timer), else a SkyMessage box polled by the tick, else a notification
     (no timer or monitor: the pending state waits for a dialogue answer, and Accept refuses one
     older than PendingChallengeExpiry). abIsRetry: re-entered from the tick's overlay retry, keep the
     retry count.}
    If !abIsRetry
        OverlayRetryCount = 0
    EndIf

    ; Idempotent belt: the choice listener must be live before the popup opens.
    RegisterForModEvent("SeverActions_BrawlChallengeChoice", "OnBrawlPromptChoice")

    String challengerName = akChallenger.GetDisplayName()

    ; Clear any stale overlay and SkyMessage box first, so a prompt that never closed cannot push a
    ; Magelight user onto the message box. The close is synchronous.
    If SeverActionsNative.Magelight_IsBrawlPromptOpen()
        SeverActionsNative.Magelight_CloseBrawlPrompt()
        Debug.Trace("[SeverBrawl] ShowPlayerChallengePopup: cleared stale brawl prompt before reopening")
    EndIf
    If PendingPopupId != 0
        If SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
            SeverActions_SkyMessageLib.Delete(PendingPopupId)
        EndIf
        PendingPopupId = 0
    EndIf

    ; Magelight overlay.
    If SeverActionsNative.Magelight_IsBrawlPromptAvailable()
        Int timeoutMs = (PendingChallengeExpiry * 1000) as Int
        If SeverActionsNative.Magelight_OpenBrawlPrompt(akChallenger, challengerName, timeoutMs)
            ; The answer arrives via OnBrawlPromptChoice; the bridge owns the timer.
            OverlayRetryCount = 0
            PendingOverlayChallenger = None
            Debug.Trace("[SeverBrawl] ShowPlayerChallengePopup: brawl prompt opened")
            Return
        EndIf
        ; Open failed, usually because the launching Magelight menu still holds focus: retry up to
        ; 6 x 0.25 s before falling back.
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

    ; SkyMessage fallback.
    String body = challengerName + " squares up and challenges you to a brawl. Fists only - no weapons, no spells."
    Int boxId = 0
    If SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
        boxId = SeverActions_SkyMessageLib.ShowNonBlocking(body, "Accept", "Decline")
    EndIf
    If boxId != 0
        PendingPopupId = boxId
        PendingPopupChallenger = akChallenger
        PendingPopupStartTime = Utility.GetCurrentRealTime()
        ChronoArm(PopupPollIntervalSec)
        Debug.Trace("[SeverBrawl] ShowPlayerChallengePopup: SkyMessage fallback engaged")
        Return
    EndIf

    ; Neither installed: notify only.
    Debug.Notification(challengerName + " challenges you to a brawl. Speak to them to accept or decline. (The SeverActions interface or Papyrus MessageBox shows a proper prompt.)")
EndFunction

Event OnBrawlPromptChoice(String asEventName, String asChoice, Float afNumArg, Form akSender)
    {The overlay's answer: sender = challenger, strArg = "accept" | "decline".}
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
    {Arm this script's one-shot chronometer tick (never RegisterForSingleUpdate on 0D62; see the
     Chronometer block in SeverActionsNativeExt2.psc). Event and callback names are this script's
     own. Re-arm replaces; ticks do not survive a load; one in-flight tick can still land after a
     Cancel, so the handler stays state-guarded.}
    RegisterForModEvent("SeverActions_Tick_Brawl", "OnChronoTick_Brawl")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_Brawl", afSeconds)
EndFunction

Event OnChronoTick_Brawl(String eventName, String strArg, Float numArg, Form sender)
    ; Re-recruit drain first, independent of the popup poll; cheap when empty.
    ProcessPendingRerecruit()

    ; Overlay retry: re-run the popup chain, keeping the retry count.
    If PendingOverlayChallenger != None
        Actor overlayChallenger = PendingOverlayChallenger as Actor
        PendingOverlayChallenger = None
        If overlayChallenger
            ShowPlayerChallengePopup(overlayChallenger, true)
        EndIf
        Return
    EndIf

    If PendingPopupId == 0
        ; Nothing pending: Cancel acknowledges the tick, or the chronometer re-sends an unanswered tick
        ; every 60 s as a dropped delivery.
        SeverActionsNativeExt2.Chrono_Cancel("SeverActions_Tick_Brawl")
        Return
    EndIf

    ; Timed out: auto-decline.
    Float elapsed = Utility.GetCurrentRealTime() - PendingPopupStartTime
    If elapsed > PendingChallengeExpiry
        Debug.Trace("[SeverBrawl] Popup: timed out, auto-declining")
        If SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
            SeverActions_SkyMessageLib.Delete(PendingPopupId)
        EndIf
        ClosePlayerChallengePopup(false)
        SeverActionsNativeExt2.Chrono_Cancel("SeverActions_Tick_Brawl")
        Return
    EndIf

    If !SeverActionsNativeExt2.Native_IsSkyMessageInstalled() || !SeverActions_SkyMessageLib.IsResultAvailable(PendingPopupId)
        ChronoArm(PopupPollIntervalSec)
        Return
    EndIf

    Int idx = -1
    If SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
        idx = SeverActions_SkyMessageLib.GetResultIndex(PendingPopupId)
    EndIf
    ClosePlayerChallengePopup(idx == 0)
    SeverActionsNativeExt2.Chrono_Cancel("SeverActions_Tick_Brawl")
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

; ---- NPC-to-NPC follow-and-wait ----

Function StartChallengeFollow(Actor akChallenger, Actor akTarget)
    {The challenger trails the target (LinkedRef follow) until the target answers; native
     BrawlChallengeMonitor fires SeverActions_BrawlChallengeExpired on timeout, distance or death.
     Reuses the arrest system's SeverActions_GuardFollowPlayer + SeverActions_FollowTargetKW, so the
     challenger follows with weapons drawn.}

    ; By FormID (SeverActions.esp 030155 keyword, 0AEAF6 package) so this script names no Arrest type.
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
    {sender = target, strArg = "timeout" | "died" | "distance" + "|<challenger FormID, signed decimal>".
     Declines for the target and drops the challenger's follow package. The challenger rides the event:
     the native's one last-expired slot is overwritten when two expiries land in one pass, and the
     StorageUtil ChallengeFrom key can already be cleared (or hold a newer challenger).}
    Actor target = sender as Actor
    If !target
        Return
    EndIf
    String reason = SeverActions_ModuleBase.VerbField(strArg, 0)
    Actor challenger = Game.GetFormEx(SeverActions_ModuleBase.VerbField(strArg, 1) as Int) as Actor
    If !challenger
        challenger = StorageUtil.GetFormValue(target, "SeverBrawl_ChallengeFrom") as Actor
    EndIf
    Debug.Trace("[SeverBrawl] Challenge expired (" + reason + ") for " + target.GetDisplayName() + " (challenger=" + challenger + ")")
    ; The expired entry was erased before this event was queued, so a live one is a challenge
    ; re-issued in between; ChallengeBrawl_Execute owns it.
    If challenger && SeverActionsNative.Native_BrawlChallenge_IsActive(challenger)
        Return
    EndIf
    If challenger
        StopChallengeFollow(challenger)
    EndIf
    ; Pass the resolved challenger: the target's ChallengeFrom slot may hold a newer, live challenge.
    DeclineBrawl_Execute(target, challenger)
EndEvent

; ---- Accept ----

Function AcceptBrawl_Execute(Actor akAccepter, Actor akChallenger = None)
{Speaker starts a fist fight. akChallenger None: take the pending challenger (ChallengeFrom) and
 refuse one older than PendingChallengeExpiry. akChallenger given: no expiry check (a direct start
 needing no prior challenge, or the overlay's answer). Both clear the pending state and monitor,
 then Brawl_Begin + StartCombat.}

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

    ; Drop the monitor and follow package before Brawl_Begin. EndForActor matches either side.
    SeverActionsNative.Native_BrawlChallenge_EndForActor(challenger)
    StopChallengeFollow(challenger)

    Bool started = SeverActionsNativeExt.Brawl_Begin(challenger, akAccepter)
    If !started
        Debug.Trace("[SeverBrawl] Accept: native Brawl_Begin rejected")
        Return
    EndIf

    ; Before StartCombat, so other followers never see a teammate under attack. Restored in OnBrawlEnded.
    StripTeammateForBrawl(challenger)
    StripTeammateForBrawl(akAccepter)

    ; An NFF dismissal from the strip tears down asynchronously and kills combat started too early:
    ; settle first. Must follow the strips, which set WasNFF.
    If StorageUtil.GetIntValue(challenger, "SeverBrawl_WasNFF", 0) == 1 || StorageUtil.GetIntValue(akAccepter, "SeverBrawl_WasNFF", 0) == 1
        Debug.Trace("[SeverBrawl] Accept: NFF release in flight - settling 2.0s before combat")
        Utility.Wait(2.0)
    EndIf

    ; Let the native hand unequip + sheath settle, or StartCombat can draw into a half-equipped pose.
    Utility.Wait(0.15)

    ; Belt for brawl start: some base loadouts re-attach a spell at combat start. Both fighters, both
    ; hands; OnBrawlHandsClean covers mid-fight re-equips.
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

    ; StartCombat is driven from Papyrus (no CommonLibSSE-NG member for it).
    challenger.StartCombat(akAccepter)
    Utility.Wait(0.1)
    akAccepter.StartCombat(challenger)

    SkyrimNetApi.RegisterEvent("brawl_accepted", \
        akAccepter.GetDisplayName() + " accepted " + challenger.GetDisplayName() + "'s brawl challenge", \
        akAccepter, challenger)

    Debug.Trace("[SeverBrawl] Accept: brawl begun " + challenger.GetDisplayName() + " vs " + akAccepter.GetDisplayName())
EndFunction

; ---- Decline ----

Function DeclineBrawl_Execute(Actor akDecliner, Actor akChallenger = None)
{Speaker brushes off a challenge (akChallenger None: the pending one). Clears the state, follow
 package and monitor, and fires brawl_declined.}
    ; Accept can wait up to ~2.25 s between Brawl_Begin and StartCombat; a Decline in that window must
    ; not narrate a decline for a brawl that is starting.
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

; ---- Forfeit ----

Function ForfeitBrawl_Execute(Actor akForfeiter)
{Speaker forfeits an active brawl; the other fighter wins. Native restores state and fires
 SeverBrawl_Ended.}

    If !akForfeiter
        Return
    EndIf
    If !SeverActionsNativeExt.Brawl_IsActive(akForfeiter)
        Debug.Trace("[SeverBrawl] Forfeit: " + akForfeiter.GetDisplayName() + " not in a brawl")
        Return
    EndIf

    ; 2 = Forfeit. OnBrawlEnded does the event and the LastWinner/LastLoser keys.
    SeverActionsNativeExt.Brawl_End(akForfeiter, 2)
EndFunction

; ---- Teammate strip / restore ----
; A brawling follower would draw the player's other followers in: teammate defense keys on
; IsPlayerTeammate, which DGIntimidateFaction does not gate. The flag is cleared for the fight; native
; TeammateMonitor suppresses the removal and keeps them tracked meanwhile. Markers: per-actor
; SeverBrawl_WasTeammate, and the quest list SeverBrawl_StrippedTeammates for the load path.

Function StripTeammateForBrawl(Actor a)
    If !a || a == Game.GetPlayer()
        Return
    EndIf
    ; Tracking-only followers are stripped too (their framework reads it as a dismiss) and are
    ; re-recruited at brawl end through SeverBrawl_PendingRerecruit.
    If a.IsPlayerTeammate()
        StorageUtil.SetIntValue(a, "SeverBrawl_WasTeammate", 1)
        StorageUtil.FormListAdd(self, "SeverBrawl_StrippedTeammates", a, False)
        a.SetPlayerTeammate(false, false)
        Debug.Trace("[SeverBrawl] StripTeammateForBrawl: cleared IsPlayerTeammate on " + a.GetDisplayName())
    EndIf
    ; NFF suppresses combat for a follower it seats, whatever flag we clear (StartCombat is silently
    ; dropped), so an NFF brawler is dismissed through NFF's controller for the fight and re-seated via
    ; PendingRerecruit. WasNFF marks that, since IsTrackOnlyFollower may answer false afterwards.
    If SeverActionsNativeExt2.Native_IsNFFManaged(a)
        ; Static calls into fwlib (N2), so this works without the Followers module. Joining NFF's spar
        ; faction alone does not hold off its suppression; it stays as a belt for the teardown window.
        Faction sparFac
        If SeverActionsNativeExt2.Native_IsNFFInstalled()
            sparFac = SeverActions_NFFLib.NFFSparFaction()
        EndIf
        If sparFac
            StorageUtil.SetIntValue(a, "SeverBrawl_NFFSparFac", 1)
            a.AddToFaction(sparFac)
        EndIf
        StorageUtil.SetIntValue(a, "SeverBrawl_WasNFF", 1)
        ; Listed even when the teammate flag read false (SA travel and muster clear it), or the reload
        ; restore, which walks this list, would never bring them back.
        StorageUtil.FormListAdd(self, "SeverBrawl_StrippedTeammates", a, False)
        ; Silent dismissal, as NFF's own spar flow does it (SparPrep dismisses, SparEnd re-recruits).
        If SeverActionsNativeExt2.Native_IsNFFInstalled()
            SeverActions_NFFLib.NFFDismiss(a, true)
        EndIf
        ; _InvalidateTrackOnlyCache is a no-op since P12-02. Own gate: check 6 reads the line above.
        If SeverActionsNativeExt2.Native_IsNFFInstalled()
            SeverActions_NFFLib._InvalidateTrackOnlyCache(a)
        EndIf
        Debug.Trace("[SeverBrawl] StripTeammateForBrawl: released " + a.GetDisplayName() + " from NFF for the brawl (dismissal primary, sparFac=" + (sparFac != None) + ")")
    EndIf
EndFunction

Function RestoreTeammateAfterBrawl(Actor a)
    If !a || a == Game.GetPlayer()
        Return
    EndIf
    Bool wasTeammate = StorageUtil.GetIntValue(a, "SeverBrawl_WasTeammate", 0) == 1
    If wasTeammate || StorageUtil.GetIntValue(a, "SeverBrawl_WasNFF", 0) == 1
        ; Restore at once, or TeammateMonitor reads the strip as a dismiss and untracks them.
        If wasTeammate
            a.SetPlayerTeammate(true, false)
        EndIf
        StorageUtil.UnsetIntValue(a, "SeverBrawl_WasTeammate")
        StorageUtil.FormListRemove(self, "SeverBrawl_StrippedTeammates", a, True)

        ; Leave NFF's spar faction directly: the controller's SparEnd services NFF's own spar flow,
        ; which we never entered.
        If StorageUtil.GetIntValue(a, "SeverBrawl_NFFSparFac", 0) == 1
            StorageUtil.UnsetIntValue(a, "SeverBrawl_NFFSparFac")
            Faction sparFacR
            If SeverActionsNativeExt2.Native_IsNFFInstalled()
                sparFacR = SeverActions_NFFLib.NFFSparFaction()
            EndIf
            If sparFacR
                a.RemoveFromFaction(sparFacR)
                Debug.Trace("[SeverBrawl] RestoreTeammateAfterBrawl: " + a.GetDisplayName() + " leaves NFF's spar faction")
            EndIf
        EndIf
        Bool wasNFF = StorageUtil.GetIntValue(a, "SeverBrawl_WasNFF", 0) == 1
        If wasNFF
            StorageUtil.UnsetIntValue(a, "SeverBrawl_WasNFF")
        EndIf
        ; The flag does not refill a framework's alias (NFF / DLC / custom-AI), so a tracking-only
        ; follower (the kernel's verdict, never a FollowerManager cast) is re-seated by
        ; ProcessPendingRerecruit. Full-SA followers need only the flag.
        If wasNFF || SeverActionsNativeExt2.Native_IsTrackOnlyFollower(a)
            StorageUtil.FormListAdd(self, "SeverBrawl_PendingRerecruit", a, False)
            ; By re-recruit time the NFF teardown is done and Native_IsNFFManaged reads false, so in
            ; SeverActions mode (FrameworkMode 0) NFFRecruit would keep them in SA. Force the NFF re-seat
            ; (one-shot flag), for real NFF followers only.
            If wasNFF
                StorageUtil.SetIntValue(a, "SeverActions_NFFReseatForce", 1)
            EndIf
            Debug.Trace("[SeverBrawl] RestoreTeammateAfterBrawl: queued re-recruit for " + a.GetDisplayName() + " (wasNFF=" + wasNFF + ")")
        EndIf

        Debug.Trace("[SeverBrawl] RestoreTeammateAfterBrawl: restored IsPlayerTeammate on " + a.GetDisplayName())
    EndIf
EndFunction

Function ProcessPendingRerecruit()
{Drains SeverBrawl_PendingRerecruit: each actor is re-seated unconditionally through the Followers
 provider's "rerecruit" (RegisterFollower, idempotent), or without Followers through
 SeverActions_FollowerFrameworkLib.ReseatExternal. Not gated on IsPlayerTeammate: the restore has
 already set it. Runs from the tick after TrackOnlyRerecruitDelay, and at once on the load path.}
    Int n = StorageUtil.FormListCount(self, "SeverBrawl_PendingRerecruit")
    If n <= 0
        Return
    EndIf
    ; Without Followers the service answers False; ReseatExternal (B17) picks NFF when the force flag
    ; is set, else Serana / custom-AI / vanilla.
    Int i = 0
    While i < n
        Form f = StorageUtil.FormListGet(self, "SeverBrawl_PendingRerecruit", i)
        Actor a = f as Actor
        If a && a != Game.GetPlayer() && !a.IsDead()
            If SeverActions_ModuleBase.CallBool("followers", "rerecruit", a)
                Debug.Trace("[SeverBrawl] ProcessPendingRerecruit: re-recruited track-only " + a.GetDisplayName())
            Else
                Bool wasNFFSeat = StorageUtil.GetIntValue(a, "SeverActions_NFFReseatForce", 0) == 1
                Bool reseated = SeverActions_FollowerFrameworkLib.ReseatExternal(a, wasNFFSeat)
                Debug.Trace("[SeverBrawl] ProcessPendingRerecruit: no FollowerManager - ReseatExternal(" + a.GetDisplayName() + ", wasNFF=" + wasNFFSeat + ") -> " + reseated)
            EndIf
        EndIf
        ; The queue owner clears the force flag: RegisterFollower can return before NFFRecruit reads it,
        ; and skipped actors never reach it, so a leftover would force NFF on a later unrelated recruit.
        If a
            StorageUtil.UnsetIntValue(a, "SeverActions_NFFReseatForce")
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
            ; The spar-faction membership and its marker both persist in the save.
            If StorageUtil.GetIntValue(a, "SeverBrawl_NFFSparFac", 0) == 1
                StorageUtil.UnsetIntValue(a, "SeverBrawl_NFFSparFac")
                Faction sparFacL
                If SeverActionsNativeExt2.Native_IsNFFInstalled()
                    sparFacL = SeverActions_NFFLib.NFFSparFaction()
                EndIf
                If sparFacL
                    a.RemoveFromFaction(sparFacL)
                EndIf
            EndIf
            ; Same re-seat queue and NFF force flag as RestoreTeammateAfterBrawl.
            Bool wasNFFReload = StorageUtil.GetIntValue(a, "SeverBrawl_WasNFF", 0) == 1
            If wasNFFReload
                StorageUtil.UnsetIntValue(a, "SeverBrawl_WasNFF")
            EndIf
            If wasNFFReload || SeverActionsNativeExt2.Native_IsTrackOnlyFollower(a)
                StorageUtil.FormListAdd(self, "SeverBrawl_PendingRerecruit", a, False)
                If wasNFFReload
                    StorageUtil.SetIntValue(a, "SeverActions_NFFReseatForce", 1)
                EndIf
                Debug.Trace("[SeverBrawl] RestoreStrippedTeammatesAfterReload: queued track-only re-recruit for " + a.GetDisplayName() + " (wasNFF=" + wasNFFReload + ")")
            EndIf
        EndIf
        i += 1
    EndWhile
    StorageUtil.FormListClear(self, "SeverBrawl_StrippedTeammates")
    ; Drain now: the delay is for a live brawl to finish, and brawls do not survive a load.
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

; ---- Native ModEvent handlers ----

Event OnBrawlStarted(String eventName, String strArg, Float numArg, Form sender)
    {Brawl_Begin succeeded. Writes the SeverBrawl_Active / _Opponent mirror (this script's own
     bookkeeping).}
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
    {sender = the actor the brawl ended on, numArg = reason. Reason, winner and loser are read from
     the Brawl_GetLast* natives, so no FormID travels through the event.}

    Int reason = SeverActionsNativeExt.Brawl_GetLastReason()
    Actor winner = SeverActionsNativeExt.Brawl_GetLastWinner()
    Actor loser  = SeverActionsNativeExt.Brawl_GetLastLoser()

    ; Restore teammates first, before anything below reads follower status. An abort names no winner
    ; (a voided knockout names only its loser and is sent from the opponent), so the sender and its
    ; SeverBrawl_Opponent mirror are restored too.
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

    ; Re-recruits queued above wait for the external framework to settle.
    If StorageUtil.FormListCount(self, "SeverBrawl_PendingRerecruit") > 0
        ChronoArm(TrackOnlyRerecruitDelay)
    EndIf

    ; Clear the active mirror. The brawl is already torn down (Brawl_GetOpponent returns None), and on
    ; abort the opponent is reachable only through the sender's mirror: read it before clearing.
    Actor senderActor = sender as Actor
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

    If winner && loser && reason == 6
        ; Say how they gave up, so the NPC can react to the gesture.
        SkyrimNetApi.RegisterEvent("brawl_ended", \
            loser.GetDisplayName() + " lowered their fists and sheathed mid-brawl, conceding to " + winner.GetDisplayName() + " without a word", \
            winner, loser)
    ElseIf winner && loser && reason == 3
        ; Walked away: winner/loser are just A/B here, so word it neutrally.
        SkyrimNetApi.RegisterEvent("brawl_ended", \
            "the brawl between " + winner.GetDisplayName() + " and " + loser.GetDisplayName() + " fizzled out - they drifted apart with no clear winner", \
            winner, loser)
    ElseIf winner && loser && reason == 4
        ; Broken to combat: the native fills A/B arbitrarily, so name no winner.
        SkyrimNetApi.RegisterEvent("brawl_ended", \
            "the brawl between " + winner.GetDisplayName() + " and " + loser.GetDisplayName() + " stopped being a brawl - it turned into a real fight", \
            winner, loser)
    ElseIf winner && loser && reason == 7
        ; Called off: between the player and a companion, or two companions, a real blow ends the
        ; brawl without a fight (BrawlManager). A/B again, so no winner is named.
        SkyrimNetApi.RegisterEvent("brawl_ended", \
            "the brawl between " + winner.GetDisplayName() + " and " + loser.GetDisplayName() + " broke off when a weapon or spell came out - it stopped there and never became a real fight", \
            winner, loser)
    ElseIf winner && loser && reason == 2
        SkyrimNetApi.RegisterEvent("brawl_ended", \
            loser.GetDisplayName() + " gave up and conceded the brawl to " + winner.GetDisplayName(), \
            winner, loser)
    ElseIf winner && loser
        SkyrimNetApi.RegisterEvent("brawl_ended", \
            winner.GetDisplayName() + " beat " + loser.GetDisplayName() + " in a brawl, knocking them to their knees", \
            winner, loser)
    ElseIf loser
        ; kAbort names no winner: a safety cleanup, or a knockout an outside hit decided.
        SkyrimNetApi.RegisterEvent("brawl_ended", \
            loser.GetDisplayName() + "'s brawl was broken off before anyone won", \
            loser, None)
    EndIf

    ; Direct narration so someone reacts now instead of at the next dialogue. Clean outcomes only;
    ; reason 4 goes to ForceAttack below.
    If winner && loser && (reason == 1 || reason == 2 || reason == 6)
        String narration = ""
        If reason == 1
            ; Stage directions only; the LLM speaks the line.
            narration = "*" + loser.GetDisplayName() + " drops to one knee, spitting blood, hands raised. The fight's over - they've been bested.*"
        ElseIf reason == 2
            narration = "*" + loser.GetDisplayName() + " backs off with a hand raised, breathing hard. They've called it - " + winner.GetDisplayName() + " wins this one.*"
        ElseIf reason == 6
            ; The player dropped their fists; the winner reads the gesture.
            narration = "*" + loser.GetDisplayName() + " lowers their fists and steps back, hands open - no words, but the meaning is plain. " + winner.GetDisplayName() + " has won this one.*"
        EndIf
        If narration != ""
            ; The loser speaks, unless it is the player: SkyrimNet silently drops player-voiced
            ; narration, so the winner speaks instead.
            If loser == Game.GetPlayer()
                SkyrimNetApi.DirectNarration(narration, winner, loser)
            Else
                SkyrimNetApi.DirectNarration(narration, loser, winner)
            EndIf
        EndIf
    EndIf

    If reason == 4 && winner && loser
        ; Broken into real combat: hand both to the forced-combat pipeline, past the cooldown just set.
        SeverActions_Combat.GetInstance().ForceAttack(winner, loser)
    EndIf
EndEvent
