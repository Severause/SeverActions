Scriptname SeverActions_CompanionMind extends Quest
{The companions' relationship assessments (companions module), about the player and about
 each other: cooldowns, LLM dispatch through the kernel relay, reply parse, clamped deltas,
 blurbs and dedup watermarks; quest awareness is native (QuestAwarenessStore). FollowerManager
 keeps an M-I-STUB safe exit per moved function (F7). Maintenance runs from the companions
 provider's stage 1 (DR20). Kernel natives only (no FollowerManager type); settings are
 Authority rows; own 30 s chain SeverActions_Tick_CompanionMind (watchdog: SeverActions_Mod_Companions).}

Float Property SECONDS_PER_GAME_HOUR = 3631.0 AutoReadOnly
Float Property AssessmentMinRealGapSeconds = 90.0 AutoReadOnly
{Real-time floor between two assessment dispatches of either kind (scaled up past 10 followers).}
String Property KEY_LAST_ASSESS_GT = "SeverFollower_LastAssessGT" AutoReadOnly
String Property KEY_NEXT_ASSESS_GT = "SeverFollower_NextAssessGT" AutoReadOnly
String Property KEY_LAST_INTER_ASSESS_GT = "SeverFollower_LastInterAssessGT" AutoReadOnly
String Property KEY_NEXT_INTER_ASSESS_GT = "SeverFollower_NextInterAssessGT" AutoReadOnly

; Pending actors are held as references, not FormIDs (ESL FormID sign issues with Game.GetForm).
Actor PendingAssessmentActor = None
; Per-dispatch reply channel: a request abandoned by its lane's expiry or pre-empted by the
; manual button answers on a retired channel name and is dropped, never applied to the
; follower pending by then. The inter-follower dispatch carries the same guard.
Int AssessSeq = 0
String AssessEventNameCur = ""
Int InterAssessSeq = 0
String InterAssessEventNameCur = ""
Actor PendingInterAssessActor = None
; Last fire of either assessment kind (pacing floor). GetCurrentRealTime restarts per
; process, so a stamp from an earlier session reads as a negative delta = gap satisfied.
Float LastAssessClassFireRT = 0.0
Bool _mindTickInFlight = false
Float _mindTickStartedRT = 0.0

Function Maintenance()
    {Load recovery (companions provider stage 1, every load and new game): registers the
     Companions page's "How they see you" listener (sender = the follower) and arms the
     tick. Re-registering is idempotent.}
    _mindTickInFlight = false
    _mindTickStartedRT = 0.0
    ; In-flight state lives in the native lanes (cleared on revert, TTL-expired).
    RegisterForModEvent("SeverActions_AssessRelNow", "OnAssessRelNow")
    ChronoArm(30.0)
EndFunction

Function ChronoArm(Float afSeconds)
    {Arms this script's one-shot chronometer tick (event and callback names unique per script).}
    RegisterForModEvent("SeverActions_Tick_CompanionMind", "OnChronoTick_CompanionMind")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_CompanionMind", afSeconds)
EndFunction

Event OnChronoTick_CompanionMind(String eventName, String strArg, Float numArg, Form sender)
    {The 30 s assessment pass. Re-armed first (the re-arm is the acknowledgement the
     watchdog counts); a pass still running blocks it unless stuck past 120 s or stamped by
     an earlier process.}
    ChronoArm(30.0)
    If _mindTickInFlight
        Float inFlightFor = Utility.GetCurrentRealTime() - _mindTickStartedRT
        If inFlightFor >= 0.0 && inFlightFor < 120.0
            Return
        EndIf
        Debug.Trace("[SeverActions_CompanionMind] tick guard STUCK (" + inFlightFor + " s) - clearing")
    EndIf
    _mindTickInFlight = true
    _mindTickStartedRT = Utility.GetCurrentRealTime()
    Actor[] tickFollowers = SeverActionsNativeExt.Native_GetActiveFollowerRoster()
    If tickFollowers && tickFollowers.Length > 0
        ; The two automatic kinds never overlap (no LLM flooding): each waits out the other's
        ; lane, so a player claim taken this pass skips the inter-follower check.
        If SeverActionsNativeExt2.Settings_GetBool("trackRelationships") && !SeverActionsNativeExt2.LLMLane_IsHeld("companions.interAssess")
            CheckRelationshipAssessments(tickFollowers)
        EndIf
        If SeverActionsNativeExt2.Settings_GetBool("interFollowerAssessment") && !SeverActionsNativeExt2.LLMLane_IsHeld("companions.assess") && !SeverActionsNativeExt2.LLMLane_IsHeld("companions.interAssess")
            CheckInterFollowerAssessments(tickFollowers)
        EndIf
    EndIf
    _mindTickInFlight = false
EndEvent

Bool Function AssessmentBusy()
    {True while an assessment of either kind is in flight; SeverActions_CompanionLife holds
     its off-screen life dispatch back meanwhile.}
    Return SeverActionsNativeExt2.LLMLane_IsHeld("companions.assess") || SeverActionsNativeExt2.LLMLane_IsHeld("companions.interAssess")
EndFunction

Function DebugMsg(String msg)
    If SeverActionsNativeExt2.Settings_GetBool("debugMode")
        Debug.Trace("[SeverActions_CompanionMind] " + msg)
    EndIf
EndFunction

Bool Function _IsFollower(Actor akActor)
    Return akActor && SeverActionsNativeExt.Native_GetIsFollower(akActor)
EndFunction

Float Function GetGameTimeInSeconds()
    {Current game time in seconds.}
    Return Utility.GetCurrentGameTime() * 24.0 * SECONDS_PER_GAME_HOUR
EndFunction

Bool Function SpeakingWouldInterruptScene(Actor akSpeaker, Actor akTarget)
    {True when either actor is in a running scene. A named speaker skips SkyrimNet's own
     speaker filters, so every gamemaster_dialogue emitter must ask this.}
    If akSpeaker && SeverActionsNative.Native_IsActorInScene(akSpeaker)
        Return true
    EndIf
    If akTarget && SeverActionsNative.Native_IsActorInScene(akTarget)
        Return true
    EndIf
    Return false
EndFunction

; === Assessments ===

Function CheckRelationshipAssessments(Actor[] followers)
    {Fires at most one automatic player assessment per tick: the most overdue loaded
     follower past their randomized next-eligible time.}
    ; The lane is the in-flight gate and the watchdog (its 120 s claim expires by itself).
    ; A late reply still on the current channel lands on its own follower; once the next
    ; fire retires that channel, OnLLMRelAssessReady drops it.
    If SeverActionsNativeExt2.LLMLane_IsHeld("companions.assess")
        Return
    EndIf

    ; Pacing floor between LLM calls, scaled with party size above 10.
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

    Actor bestCandidate = None
    Float bestOverdue = 0.0

    Int i = 0
    While i < followers.Length
        Actor follower = followers[i]
        ; Loaded, not same-cell: exterior cells are 4096u, so a same-cell test starves a
        ; companion waiting a few metres away.
        If follower && !follower.IsDead() && follower.Is3DLoaded()
            Float nextEligible = StorageUtil.GetFloatValue(follower, KEY_NEXT_ASSESS_GT, 0.0)
            ; No next-eligible yet: last assess + the min cooldown.
            If nextEligible == 0.0
                Float lastAssess = StorageUtil.GetFloatValue(follower, KEY_LAST_ASSESS_GT, 0.0)
                nextEligible = lastAssess + (SeverActionsNativeExt2.Settings_GetFloat("assessmentCooldownMin") * SECONDS_PER_GAME_HOUR)
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
        FireRelationshipAssessment(bestCandidate)
    EndIf
EndFunction

Event OnAssessRelNow(String eventName, String strArg, Float numArg, Form sender)
    {Manual "How They See You" refresh from the Companions page (sender = the follower).
     Skips the picker's game-time cooldown and pre-empts an autonomous assessment in
     flight (claim released, channel retired, so its reply is dropped). The Background AI
     toggle still applies.}
    Actor akActor = sender as Actor
    If !akActor
        Return
    EndIf
    DebugMsg("Manual relationship assessment requested for " + akActor.GetDisplayName())
    If SeverActionsNativeExt2.LLMLane_IsHeld("companions.assess")
        DebugMsg("Manual request pre-empts the assessment in flight")
        SeverActionsNativeExt2.LLMLane_Release("companions.assess")
        PendingAssessmentActor = None
        If AssessEventNameCur != ""
            String retired = AssessEventNameCur
            AssessEventNameCur = ""
            UnregisterForModEvent(retired)
        EndIf
    EndIf
    FireRelationshipAssessment(akActor)
EndEvent

Function FireRelationshipAssessment(Actor akActor)
    {Sends sever_relationship_assess for one follower; cooldown and pacing checks are the
     callers'. The native builds the context (FormID, plus socialGraph and relevantMemories
     when PublicAPI is up, trimmed and capped) so the raw memory JSON - tens of KB - never
     becomes a Papyrus string: a save that captures one will not load.}
    If !SeverActionsNativeExt2.LLMLane_TryClaim("companions.assess", 120.0)
        DebugMsg("Relationship assessment already in flight - request for " + akActor.GetDisplayName() + " dropped")
        Return
    EndIf
    ; Retire the previous channel (an expired claim's, or a refused dispatch's) BEFORE the
    ; pending actor changes: every call below can yield, and a late reply on the old channel
    ; must not land on this follower.
    If AssessEventNameCur != ""
        String retired = AssessEventNameCur
        AssessEventNameCur = ""
        UnregisterForModEvent(retired)
    EndIf
    PendingAssessmentActor = akActor
    LastAssessClassFireRT = Utility.GetCurrentRealTime()
    Float nowTime = GetGameTimeInSeconds()
    StorageUtil.SetFloatValue(akActor, KEY_LAST_ASSESS_GT, nowTime)
    ; Provisional 0.5 game-hr retry only: OnRelationshipAssessment commits the full
    ; randomized cooldown on success, so a dropped or refused call does not shelve this
    ; follower for hours.
    StorageUtil.SetFloatValue(akActor, KEY_NEXT_ASSESS_GT, nowTime + (0.5 * SECONDS_PER_GAME_HOUR))

    ; Prompt module not installed (FOMOD): skip, or SkyrimNet logs "prompt not found" every cycle.
    If !SeverActionsNative.Native_IsPromptAvailable("sever_relationship_assess")
        DebugMsg("Relationship assessment skipped: sever_relationship_assess.prompt not installed")
        ; Release the claim, or the lane stays held for its TTL (blocking off-screen life).
        SeverActionsNativeExt2.LLMLane_Release("companions.assess")
        PendingAssessmentActor = None
        Return
    EndIf

    ; Through the native bridge relay: the reply comes back full-length by ModEvent
    ; (SkyrimNet's Papyrus callback truncates at ~1024 chars) and the Background AI toggle
    ; covers the call. This dispatch opens its own channel (see AssessSeq).
    AssessSeq += 1
    AssessEventNameCur = "SeverActions_LLM_RelAssess_" + AssessSeq
    RegisterForModEvent(AssessEventNameCur, "OnLLMRelAssessReady")
    Bool sent = SeverActionsNativeExt2.Native_LLM_DispatchRelationshipAssess(akActor, AssessEventNameCur)

    If !sent
        SeverActionsNativeExt2.LLMLane_Release("companions.assess")
        DebugMsg("Relationship assessment LLM dispatch refused for " + akActor.GetDisplayName() \
            + " (bridge down, master toggle off, or prompt missing)")
    Else
        DebugMsg("Relationship assessment queued for " + akActor.GetDisplayName() + " (enriched=" + SeverActionsNative.IsPublicAPIReady() + ")")
    EndIf
EndFunction

Event OnLLMRelAssessReady(string eventName, string strArg, float numArg, Form sender)
    {Relay reply (strArg = response, numArg = success). A reply on any channel but the
     current one is dropped (see AssessSeq).}
    UnregisterForModEvent(eventName)
    If eventName != AssessEventNameCur
        Return
    EndIf
    AssessEventNameCur = ""
    OnRelationshipAssessment(strArg, numArg as Int)
EndEvent

Function OnRelationshipAssessment(String response, Int success)
    {Applies a player-assessment reply (JSON: rapport, trust, loyalty, mood deltas, blurb,
     eid/mid/did watermarks) to the pending follower.}
    ; Read before the first native call: a fire during that call's yield changes the pending actor.
    Actor akActor = PendingAssessmentActor
    SeverActionsNativeExt2.LLMLane_Release("companions.assess")

    If success != 1
        DebugMsg("Relationship assessment LLM failed: " + response)
        Return
    EndIf

    If !akActor || !_IsFollower(akActor)
        DebugMsg("Relationship assessment: actor not found or no longer a follower")
        Return
    EndIf

    ; Success: commit the full randomized cooldown (the fire set only a provisional retry).
    Float assessCooldownSec = Utility.RandomFloat(SeverActionsNativeExt2.Settings_GetFloat("assessmentCooldownMin"), SeverActionsNativeExt2.Settings_GetFloat("assessmentCooldownMax")) * SECONDS_PER_GAME_HOUR
    StorageUtil.SetFloatValue(akActor, KEY_NEXT_ASSESS_GT, GetGameTimeInSeconds() + assessCooldownSec)

    ; The prompt caps deltas at +/-15 (rapport/trust/loyalty) and +/-20 (mood); the natives
    ; only clamp the range to +/-100, so the caps are enforced here.
    Int rapportChange = ClampAssessDelta(SeverActionsNativeExt2.Json_GetInt(response, "/rapport"), 15)
    Int trustChange = ClampAssessDelta(SeverActionsNativeExt2.Json_GetInt(response, "/trust"), 15)
    Int loyaltyChange = ClampAssessDelta(SeverActionsNativeExt2.Json_GetInt(response, "/loyalty"), 15)
    Int moodChange = ClampAssessDelta(SeverActionsNativeExt2.Json_GetInt(response, "/mood"), 20)
    Int lastEventId = SeverActionsNativeExt2.Json_GetInt(response, "/eid")
    Int lastMemoryId = SeverActionsNativeExt2.Json_GetInt(response, "/mid")
    Int lastDiaryId = SeverActionsNativeExt2.Json_GetInt(response, "/did")
    String blurb = SeverActionsNativeExt2.Json_GetString(response, "/blurb")

    ; Dedup watermarks live in FollowerData.
    If lastEventId > 0
        SeverActionsNativeExt.Native_SetLastAssessEventId(akActor, lastEventId)
    EndIf
    If lastMemoryId > 0
        SeverActionsNativeExt.Native_SetLastAssessMemoryId(akActor, lastMemoryId)
    EndIf
    If lastDiaryId > 0
        SeverActionsNativeExt.Native_SetLastAssessDiaryId(akActor, lastDiaryId)
    EndIf

    ; The native blurb is the only copy; prompts read it through the sever_player_blurb
    ; decorator (no SeverFollower_PlayerBlurb StorageUtil mirror).
    If blurb != ""
        SeverActionsNativeExt.Native_SetPlayerBlurb(akActor, blurb)
        SeverActionsNative.Magelight_RefreshPage("companions")
    EndIf

    If rapportChange == 0 && trustChange == 0 && loyaltyChange == 0 && moodChange == 0
        DebugMsg(akActor.GetDisplayName() + " assessment: no change (eid " + lastEventId + ", mid " + lastMemoryId + ", did " + lastDiaryId + ")" + ", blurb=" + (blurb != ""))
        Return
    EndIf

    ; The Modify* natives clamp to the valid range.
    If rapportChange != 0
        SeverActionsNativeExt.Native_ModifyRapport(akActor, rapportChange as Float)
    EndIf
    If trustChange != 0
        SeverActionsNativeExt.Native_ModifyTrust(akActor, trustChange as Float)
    EndIf
    If loyaltyChange != 0
        SeverActionsNativeExt.Native_ModifyLoyalty(akActor, loyaltyChange as Float)
    EndIf
    If moodChange != 0
        SeverActionsNativeExt.Native_ModifyMood(akActor, moodChange as Float)
    EndIf

    ; Resets the native ticker's neglect clock.
    SeverActionsNativeExt.Native_SetInteractionTime(akActor, GetGameTimeInSeconds())

    ; Debug log only, never a SkyrimNet event: mechanics text ("rapport +3") would leak into
    ; get_recent_events and the diaries. The blurb is the narrative-facing output.
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

Function CheckInterFollowerAssessments(Actor[] followers)
    {Fires at most one inter-follower assessment per tick, for the most overdue follower.
     No proximity requirement (opinions come from shared events and memories); needs 2+.}
    If SeverActionsNativeExt2.LLMLane_IsHeld("companions.interAssess")
        Return
    EndIf

    If followers.Length < 2
        Return
    EndIf

    ; Pacing floor shared with the player assessments (one stamp paces both).
    Float gapI = AssessmentMinRealGapSeconds
    If followers.Length > 10
        gapI = gapI * (1.0 + (followers.Length - 10) / 10.0)
    EndIf
    Float dtI = Utility.GetCurrentRealTime() - LastAssessClassFireRT
    If LastAssessClassFireRT > 0.0 && dtI >= 0.0 && dtI < gapI
        Return
    EndIf

    Float now = GetGameTimeInSeconds()

    Actor bestCandidate = None
    Float bestOverdue = 0.0

    Int i = 0
    While i < followers.Length
        Actor follower = followers[i]
        If follower && !follower.IsDead()
            Float nextEligible = StorageUtil.GetFloatValue(follower, KEY_NEXT_INTER_ASSESS_GT, 0.0)
            If nextEligible == 0.0
                Float lastAssess = StorageUtil.GetFloatValue(follower, KEY_LAST_INTER_ASSESS_GT, 0.0)
                nextEligible = lastAssess + (SeverActionsNativeExt2.Settings_GetFloat("interFollowerCooldownMin") * SECONDS_PER_GAME_HOUR)
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
    {Sends sever_relationship_interfollower for one assessor: context JSON with their FormID
     and dedup watermarks, and each other party member's FormID with the current pair values.}
    ; TTL 0 = the lane default (300 s).
    If !SeverActionsNativeExt2.LLMLane_TryClaim("companions.interAssess", 0.0)
        Return
    EndIf
    ; Retire the previous channel before the pending actor changes, as in FireRelationshipAssessment.
    If InterAssessEventNameCur != ""
        String retired = InterAssessEventNameCur
        InterAssessEventNameCur = ""
        UnregisterForModEvent(retired)
    EndIf
    PendingInterAssessActor = akActor
    LastAssessClassFireRT = Utility.GetCurrentRealTime()
    Float nowTime = GetGameTimeInSeconds()
    StorageUtil.SetFloatValue(akActor, KEY_LAST_INTER_ASSESS_GT, nowTime)
    ; Provisional 0.5 game-hr retry, as in FireRelationshipAssessment.
    StorageUtil.SetFloatValue(akActor, KEY_NEXT_INTER_ASSESS_GT, nowTime + (0.5 * SECONDS_PER_GAME_HOUR))

    ; No display names in this hand-built JSON: EscapeJsonString keeps a non-UTF-8 byte, and one
    ; makes SkyrimNet drop the whole context. The prompt names everyone through decnpc.
    String contextJson = "{\"npcFormId\":" + akActor.GetFormID()
    ; The prompt's dedup watermarks, from FollowerData.
    contextJson += ",\"lastInterEventId\":" + SeverActionsNativeExt.Native_GetLastInterAssessEventId(akActor)
    contextJson += ",\"lastInterMemoryId\":" + SeverActionsNativeExt.Native_GetLastInterAssessMemoryId(akActor)
    contextJson += ",\"lastInterDiaryId\":" + SeverActionsNativeExt.Native_GetLastInterAssessDiaryId(akActor)

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

    ; Prompt module not installed: skip and release the claim (as in FireRelationshipAssessment).
    If !SeverActionsNative.Native_IsPromptAvailable("sever_relationship_interfollower")
        DebugMsg("Inter-follower assessment skipped: sever_relationship_interfollower.prompt not installed")
        SeverActionsNativeExt2.LLMLane_Release("companions.interAssess")
        PendingInterAssessActor = None
        Return
    EndIf

    ; Bridge relay and per-dispatch channel, as in FireRelationshipAssessment (the reply's
    ; pair array grows with the party, so the full-length reply matters most here).
    InterAssessSeq += 1
    InterAssessEventNameCur = "SeverActions_LLM_InterAssess_" + InterAssessSeq
    RegisterForModEvent(InterAssessEventNameCur, "OnLLMInterAssessReady")
    Bool sent = SeverActionsNativeExt.Native_LLM_Dispatch("sever_relationship_interfollower", contextJson, \
        InterAssessEventNameCur)

    If !sent
        SeverActionsNativeExt2.LLMLane_Release("companions.interAssess")
        DebugMsg("Inter-follower assessment dispatch refused for " + akActor.GetDisplayName() \
            + " (bridge down, master toggle off, or prompt missing)")
    Else
        DebugMsg("Inter-follower assessment queued for " + akActor.GetDisplayName())
    EndIf
EndFunction

Event OnLLMInterAssessReady(string eventName, string strArg, float numArg, Form sender)
    {Relay reply; a reply on any channel but the current one is dropped (see AssessSeq).}
    UnregisterForModEvent(eventName)
    If eventName != InterAssessEventNameCur
        Return
    EndIf
    InterAssessEventNameCur = ""
    OnInterFollowerAssessment(strArg, numArg as Int)
EndEvent

Function OnInterFollowerAssessment(String response, Int success)
    {Applies an inter-follower reply (JSON: assessor, src, pairs[target, affinity, respect,
     blurb], eid/mid/did watermarks).}
    Actor pendingActor = PendingInterAssessActor  ; before any native call, as in OnRelationshipAssessment
    SeverActionsNativeExt2.LLMLane_Release("companions.interAssess")

    If success != 1
        DebugMsg("Inter-follower assessment LLM failed: " + response)
        Return
    EndIf

    ; Assessor by name first (light-plugin FormIDs are unreliable), then the reply's src
    ; FormID, then the pending actor.
    Actor[] followers = SeverActionsNativeExt.Native_GetActiveFollowerRoster()
    String assessorName = SeverActionsNativeExt2.Json_GetString(response, "/assessor")
    Actor akActor = None
    If assessorName != ""
        akActor = ResolveFollowerByName(assessorName, followers)
    EndIf

    If !akActor
        Int srcFormId = SeverActionsNativeExt2.Json_GetInt(response, "/src")
        If srcFormId != 0
            akActor = Game.GetFormEx(srcFormId) as Actor
        EndIf
    EndIf

    If !akActor
        akActor = pendingActor
    EndIf

    If !akActor || !_IsFollower(akActor)
        DebugMsg("Inter-follower assessment: assessor not found (name=" + assessorName + ")")
        Return
    EndIf

    ; Success: commit the full randomized cooldown (the fire set only a provisional retry).
    Float interCooldownSec = Utility.RandomFloat(SeverActionsNativeExt2.Settings_GetFloat("interFollowerCooldownMin"), SeverActionsNativeExt2.Settings_GetFloat("interFollowerCooldownMax")) * SECONDS_PER_GAME_HOUR
    StorageUtil.SetFloatValue(akActor, KEY_NEXT_INTER_ASSESS_GT, GetGameTimeInSeconds() + interCooldownSec)

    ; Dedup watermarks live in FollowerData.
    Int lastEventId = SeverActionsNativeExt2.Json_GetInt(response, "/eid")
    Int lastMemoryId = SeverActionsNativeExt2.Json_GetInt(response, "/mid")
    Int lastDiaryId = SeverActionsNativeExt2.Json_GetInt(response, "/did")
    If lastEventId > 0
        SeverActionsNativeExt.Native_SetLastInterAssessEventId(akActor, lastEventId)
    EndIf
    If lastMemoryId > 0
        SeverActionsNativeExt.Native_SetLastInterAssessMemoryId(akActor, lastMemoryId)
    EndIf
    If lastDiaryId > 0
        SeverActionsNativeExt.Native_SetLastInterAssessDiaryId(akActor, lastDiaryId)
    EndIf

    ; Each pair's target is a name, resolved against the roster.
    String summary = akActor.GetDisplayName() + " inter-follower assessment:"
    Bool anyChange = false

    Int pairCount = SeverActionsNativeExt2.Json_ArrayCount(response, "/pairs")
    Int pi = 0
    While pi < pairCount
        String targetName = SeverActionsNativeExt2.Json_GetString(response, "/pairs/" + pi + "/target")
        ; The prompt's caps (+/-15 affinity, +/-10 respect), as in OnRelationshipAssessment.
        Int affinityDelta = ClampAssessDelta(SeverActionsNativeExt2.Json_GetInt(response, "/pairs/" + pi + "/affinity"), 15)
        Int respectDelta = ClampAssessDelta(SeverActionsNativeExt2.Json_GetInt(response, "/pairs/" + pi + "/respect"), 10)

        Actor targetActor = ResolveFollowerByName(targetName, followers)
        If targetActor && targetActor != akActor && (affinityDelta != 0 || respectDelta != 0)
            Float curAffinity = SeverActionsNative.Native_GetPairAffinity(akActor, targetActor)
            Float curRespect = SeverActionsNative.Native_GetPairRespect(akActor, targetActor)

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

            String blurb = SeverActionsNativeExt2.Json_GetString(response, "/pairs/" + pi + "/blurb")

            ; The native pair row is the only copy (no StorageUtil mirror).
            SeverActionsNative.Native_SetPairRelationship(akActor, targetActor, newAffinity, newRespect, blurb)

            summary += " " + targetActor.GetDisplayName() + "(aff" + affinityDelta + " res" + respectDelta + ")"
            anyChange = true
        EndIf

        pi += 1
    EndWhile

    If anyChange
        ; Rebuild every follower's opinions string, not just the assessor's, so a stale or
        ; empty one (a mid-session recruit) heals here.
        SeverActionsNativeExt2.Native_HydrateFollowerSystem_RebuildOpinions()

        ; Debug log only, no SkyrimNet event (see OnRelationshipAssessment).
        DebugMsg(summary)
    Else
        DebugMsg(akActor.GetDisplayName() + " inter-follower assessment: no changes")
    EndIf
EndFunction

Actor Function ResolveFollowerByName(String targetName, Actor[] followers)
    {The roster follower whose display name matches targetName (case-insensitive), else
     one whose name contains or is contained in it; None if neither.}
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

    ; Fallback: substring either way (a short name vs a full display name).
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

Int Function ClampAssessDelta(Int value, Int limit)
    {An LLM assessment delta held to the +/-limit the prompt states.}
    If value > limit
        Return limit
    ElseIf value < -limit
        Return -limit
    EndIf
    Return value
EndFunction

Event OnInit()
    ; No setup here (DR20): Maintenance runs from the companions provider.
    Debug.Trace("[SeverActions] SeverActions_CompanionMind: bound")
EndEvent
