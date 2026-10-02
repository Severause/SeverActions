Scriptname SeverActions_Familiarity extends Quest
{Familiarity (social module): the reputation assessment an NPC forms of the player at
 the milestones the native player_familiarity decorator detects - queue pop, LLM
 dispatch through the kernel relay, reply parse, tier write. FollowerManager keeps a
 safe-exit stub for each moved function (F7). The native stores (FamiliarityStore,
 IntimacyStanceStore, IntimacyGate) are gated on this module. Maintenance runs from
 the social provider's stage 1 on every load and new game (DR20); no tick of its own,
 the DLL's SeverActions_ReputationAssess drives it.}

; The NPC whose assessment is in flight.
Actor PendingReputationActor = None
; Per-dispatch reply channel: the blurb is free prose with nothing to re-key it by, so
; an expired claim's late reply after a re-fire is dropped by event name.
Int RepAssessSeq = 0
String RepAssessEventNameCur = ""

Function Maintenance()
    {Load recovery (the social provider's stage 1): the request listener. The in-flight
     state is the native lane social.reputation (cleared on revert, TTL-expired), so a
     save made mid-call cannot wedge the queue.}
    ; Fired on a blurb milestone: the first real conversation (10+ lines), every +100
    ; lines after, or a bond rise; at most once a game day (FamiliarityStore decides).
    RegisterForModEvent("SeverActions_ReputationAssess", "OnReputationAssessRequest")
EndFunction

Function DebugMsg(String msg)
    If SeverActionsNativeExt2.Settings_GetBool("debugMode")
        Debug.Trace("[SeverActions_Familiarity] " + msg)
    EndIf
EndFunction

Bool Function _IsFollower(Actor akActor)
    Return akActor && SeverActionsNativeExt.Native_GetIsFollower(akActor)
EndFunction

; Reputation assessment

Event OnReputationAssessRequest(String eventName, String strArg, Float numArg, Form sender)
    {The native queue gained an NPC (see Maintenance). Papyrus drains it one at a time
     through the reply chain.}
    If SeverActionsNativeExt2.LLMLane_IsHeld("social.reputation")
        Return  ; Current assessment will chain to next when done
    EndIf
    ProcessNextReputationAssessment()
EndEvent

Function ProcessNextReputationAssessment()
    {Pops the next NPC from the native queue and dispatches its assessment; each reply
     chains back here. The lane is claimed BEFORE the pop, so a refused claim leaves the
     entry queued for the in-flight chain. Every skip path releases before it chains.}
    If !SeverActionsNativeExt2.LLMLane_TryClaim("social.reputation", 0.0)
        Return  ; A call is in flight; its reply chains back here
    EndIf
    Actor npcActor = SeverActionsNative.Native_PopReputationAssessRequestActor()
    If !npcActor
        SeverActionsNativeExt2.LLMLane_Release("social.reputation")
        Return  ; Queue empty (or popped FormID failed to resolve)
    EndIf

    If npcActor.IsDead()
        Debug.Trace("[SeverActions_Familiarity] Reputation assessment: skipping dead actor " + npcActor.GetDisplayName())
        SeverActionsNativeExt2.LLMLane_Release("social.reputation")
        ProcessNextReputationAssessment()  ; Skip invalid, try next
        Return
    EndIf

    ; Followers get the relationship assessment instead.
    If _IsFollower(npcActor)
        Debug.Trace("[SeverActions_Familiarity] Reputation assessment: skipping follower " + npcActor.GetDisplayName())
        SeverActionsNativeExt2.LLMLane_Release("social.reputation")
        ProcessNextReputationAssessment()  ; Skip follower, try next
        Return
    EndIf

    ; The "NPC Reputation Blurbs" toggle, and the prompt (the optional Familiarity prompt
    ; module). Skipped silently, and the chain moves on so it does not stall.
    If !SeverActionsNativeExt2.Settings_GetBool("npcReputationEnabled") || !SeverActionsNative.Native_IsPromptAvailable("sever_reputation_assess")
        DebugMsg("Reputation assessment skipped (toggle off or prompt missing) for " + npcActor.GetDisplayName())
        SeverActionsNativeExt2.LLMLane_Release("social.reputation")
        ProcessNextReputationAssessment()
        Return
    EndIf

    ; Retire the previous channel before the pending actor changes (see
    ; CompanionMind.FireRelationshipAssessment).
    If RepAssessEventNameCur != ""
        String retired = RepAssessEventNameCur
        RepAssessEventNameCur = ""
        UnregisterForModEvent(retired)
    EndIf
    PendingReputationActor = npcActor

    ; The prompt reads the FormID back with formid_to_uuid(), which handles a negative
    ; (signed) FormID.
    Int formId = npcActor.GetFormID()
    String contextJson = "{\"npcFormId\":" + formId + "}"

    ; Through the bridge relay (like CompanionMind.FireRelationshipAssessment): the reply
    ; is free prose, which SkyrimNet's Papyrus callback truncates at ~1024 chars.
    RepAssessSeq += 1
    RepAssessEventNameCur = "SeverActions_LLM_RepAssess_" + RepAssessSeq
    RegisterForModEvent(RepAssessEventNameCur, "OnLLMRepAssessReady")
    Bool sent = SeverActionsNativeExt.Native_LLM_Dispatch("sever_reputation_assess", contextJson, \
        RepAssessEventNameCur)

    If !sent
        SeverActionsNativeExt2.LLMLane_Release("social.reputation")
        Debug.Trace("[SeverActions_Familiarity] Reputation assessment dispatch refused for " + npcActor.GetDisplayName() \
            + " (bridge down, master toggle off, or prompt missing)")
        ProcessNextReputationAssessment()  ; Try next in queue
    Else
        Debug.Trace("[SeverActions_Familiarity] Reputation assessment queued for " + npcActor.GetDisplayName())
    EndIf
EndFunction

Event OnLLMRepAssessReady(string eventName, string strArg, float numArg, Form sender)
    {The relay's reply. One not on the CURRENT channel (an expired claim's late reply
     after a re-fire) is dropped without chaining; the live dispatch chains on its own.}
    UnregisterForModEvent(eventName)
    If eventName != RepAssessEventNameCur
        Return
    EndIf
    RepAssessEventNameCur = ""
    OnReputationAssessResult(strArg, numArg as Int)
EndEvent

Function OnReputationAssessResult(String response, Int success)
    {Handles the assessment reply (from OnLLMRepAssessReady): applies the tier verdict,
     stores the impression blurb for the character bio, then chains to the next NPC.}
    ; Taken before the first native call (see CompanionMind.OnRelationshipAssessment).
    Actor npcActor = PendingReputationActor
    PendingReputationActor = None
    SeverActionsNativeExt2.LLMLane_Release("social.reputation")

    If success != 1
        Debug.Trace("[SeverActions_Familiarity] Reputation assessment LLM failed: " + response)
        ProcessNextReputationAssessment()
        Return
    EndIf

    If !npcActor
        Debug.Trace("[SeverActions_Familiarity] Reputation assessment: pending actor is None")
        ProcessNextReputationAssessment()
        Return
    EndIf

    ; Trimmed: some models pad the reply with whitespace or newlines.
    String blurb = SeverActionsNative.TrimString(response)

    ; The reply leads with a verdict, "TIER:<token>|", then the prose. The verdict
    ; replaces the conversation ladder for this NPC from now on (the ladder only
    ; bootstraps an unassessed NPC; bonds still floor it natively). Without the prefix
    ; the computed tier stands. A pipe, not a newline: a Papyrus string literal cannot
    ; express a newline to search for.
    If StringUtil.Find(blurb, "TIER:") == 0
        Int tierBar = StringUtil.Find(blurb, "|")
        If tierBar > 5
            SeverActionsNativeExt2.Native_Familiarity_SetTier(npcActor, \
                StringUtil.Substring(blurb, 5, tierBar - 5))
            blurb = SeverActionsNative.TrimString(StringUtil.Substring(blurb, tierBar + 1))
        EndIf
    EndIf

    ; "NONE": nothing about the player worth an impression.
    If blurb == "NONE" || blurb == ""
        Debug.Trace("[SeverActions_Familiarity] Reputation assessment: no reputation data for " + npcActor.GetDisplayName())
        ProcessNextReputationAssessment()
        Return
    EndIf

    ; Read by the character bio (0045) and the next assessment through
    ; papyrus_util("GetStringValue", <uuid>, "SeverFamiliarity_Blurb", "").
    StorageUtil.SetStringValue(npcActor, "SeverFamiliarity_Blurb", blurb)
    Debug.Trace("[SeverActions_Familiarity] Reputation blurb stored for " + npcActor.GetDisplayName())

    ProcessNextReputationAssessment()
EndFunction

Event OnInit()
    ; No setup here (DR20): Maintenance runs from the provider's stage 1.
    Debug.Trace("[SeverActions] SeverActions_Familiarity: bound")
EndEvent
