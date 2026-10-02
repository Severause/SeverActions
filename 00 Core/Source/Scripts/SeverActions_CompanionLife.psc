Scriptname SeverActions_CompanionLife extends Quest
{Companion Life (companions module): off-screen life for dismissed companions - the
 LLM-authored events, their consequences (arrest, bounty, gold, debt, items) and the gossip
 ring per location - plus the follower banter director. FollowerManager keeps a safe-exit
 stub for each function moved here (F7). Maintenance runs from the companions provider's
 stage 1 on every load and new game (DR20). An off-screen arrest's jailing goes to the arrest
 module by the async verb arrest.offscreenJail (DR3). Own chain SeverActions_Tick_CompanionLife
 (30 s), watched by SeverActions_Mod_Companions (keep its ChronoTickNames in step).}

Float Property SECONDS_PER_GAME_HOUR = 3631.0 AutoReadOnly ; not 3600: the native stores decode these timestamps with 3631 (CosaveUtils.h)
Float Property OffScreenLifeMinRealGapSeconds = 180.0 AutoReadOnly
{Minimum real seconds between two off-screen life dispatches (widened past 50 tracked followers).}
Float Property OffScreenGracePeriodHours = 6.0 AutoReadOnly
{Game hours after a dismissal before the first off-screen life event can fire.}
Int Property BanterHistoryMax = 12 AutoReadOnly
String Property KEY_LAST_BANTER_GT = "SeverActions_LastBanterGT" AutoReadOnly
String Property KEY_NEXT_BANTER_GT = "SeverActions_NextBanterGT" AutoReadOnly
String Property KEY_BANTER_HISTORY = "SeverActions_BanterHistory" AutoReadOnly
String Property KEY_LAST_LIFE_EVENT_GT = "SeverFollower_LastLifeEventGT" AutoReadOnly
String Property KEY_NEXT_LIFE_EVENT_GT = "SeverFollower_NextLifeEventGT" AutoReadOnly
String Property KEY_DISMISS_GT = "SeverFollower_DismissGT" AutoReadOnly
String Property KEY_LAST_CONSEQUENCE_GT = "SeverFollower_LastConsequenceGT" AutoReadOnly
String Property KEY_OFFSCREEN_BOUNTY_TOTAL = "SeverFollower_OffScreenBountyTotal" AutoReadOnly
String Property KEY_OFFSCREEN_DEBT = "SeverFollower_OffScreenDebt" AutoReadOnly

; The actor of the off-screen life dispatch in flight (the reply's fallback when its sender is lost).
Actor PendingOffScreenLifeActor = None
; Per-dispatch banter reply event name, so an expired claim's late reply is dropped after a re-fire.
Int BanterSeq = 0
String BanterEventNameCur = ""
; Real-time stamp of the last off-screen life fire; one from an earlier session reads as a
; negative delta, which the pacing gate treats as satisfied.
Float LastOffScreenLifeFireRT = 0.0
Bool _lifeTickInFlight = false
Float _lifeTickStartedRT = 0.0

Function Maintenance()
    {Load recovery from the companions provider's stage 1 (every load and new game):
     registers the SeverActions_OffScreenLifeReady reply listener and arms the tick.}
    _lifeTickInFlight = false
    _lifeTickStartedRT = 0.0
    ; The LLM in-flight state is the native lanes' (cleared on revert, expired by TTL).
    RegisterForModEvent("SeverActions_OffScreenLifeReady", "OnOffScreenLifeReady")
    ; First wake at 45 s, then 30 s: half a period off CompanionMind's chain (armed in the
    ; same stage), so the "wait for an assessment" hold does not race its tick. Still
    ; inside Init's watchdog window.
    ChronoArm(45.0)
EndFunction

Function ChronoArm(Float afSeconds)
    {This script's one-shot chronometer tick: event name AND callback name unique per script.}
    RegisterForModEvent("SeverActions_Tick_CompanionLife", "OnChronoTick_CompanionLife")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_CompanionLife", afSeconds)
EndFunction

Event OnChronoTick_CompanionLife(String eventName, String strArg, Float numArg, Form sender)
    {The 30 s off-screen life + banter pass. Re-armed first; a stuck in-flight guard clears
     after 120 s. Off-screen life holds back while CompanionMind (same module) has an
     assessment in flight.}
    ChronoArm(30.0)
    If _lifeTickInFlight
        Float inFlightFor = Utility.GetCurrentRealTime() - _lifeTickStartedRT
        If inFlightFor >= 0.0 && inFlightFor < 120.0
            Return
        EndIf
        Debug.Trace("[SeverActions_CompanionLife] tick guard STUCK (" + inFlightFor + " s) - clearing")
    EndIf
    _lifeTickInFlight = true
    _lifeTickStartedRT = Utility.GetCurrentRealTime()
    ; A reply that never comes is covered by the off-screen life lane's own 120 s TTL.
    Bool assessBusy = false
    SeverActions_CompanionMind mind = (Self as Quest) as SeverActions_CompanionMind
    If mind
        assessBusy = mind.AssessmentBusy()
    EndIf
    ; Off-screen life: only while no assessment is in flight.
    If SeverActionsNativeExt2.Settings_GetBool("autoOffScreenLife") && !assessBusy && !SeverActionsNativeExt2.LLMLane_IsHeld("companions.offscreenLife")
        CheckOffScreenLifeEvents()
    EndIf
    ; Banter: gated only by its own cooldown and lane.
    If SeverActionsNativeExt2.Settings_GetBool("followerBanterEnabled") && !SeverActionsNativeExt2.LLMLane_IsHeld("companions.banter")
        Actor[] tickFollowers = SeverActionsNativeExt.Native_GetActiveFollowerRoster()
        If tickFollowers && tickFollowers.Length > 0
            CheckFollowerBanter(tickFollowers)
        EndIf
    EndIf
    _lifeTickInFlight = false
EndEvent

Function DebugMsg(String msg)
    If SeverActionsNativeExt2.Settings_GetBool("debugMode")
        Debug.Trace("[SeverActions_CompanionLife] " + msg)
    EndIf
EndFunction

Bool Function _IsFollower(Actor akActor)
    Return akActor && SeverActionsNativeExt.Native_GetIsFollower(akActor)
EndFunction

Float Function GetGameTimeInSeconds()
    {Current game time in seconds (SECONDS_PER_GAME_HOUR per hour).}
    Return Utility.GetCurrentGameTime() * 24.0 * SECONDS_PER_GAME_HOUR
EndFunction

String Function WrapPersistentEvent(String line)
    {A plain line as persistent_generic event JSON (escaped).}
    Return "{\"line\":\"" + SeverActionsNative.EscapeJsonString(line) + "\"}"
EndFunction

Bool Function SpeakingWouldInterruptScene(Actor akSpeaker, Actor akTarget)
    {True when either actor is in a running scene. A named gamemaster_dialogue speaker skips
     SkyrimNet's own speaker filters, so every such emitter asks this first (CLAUDE.md lessons).}
    If akSpeaker && SeverActionsNative.Native_IsActorInScene(akSpeaker)
        Return true
    EndIf
    If akTarget && SeverActionsNative.Native_IsActorInScene(akTarget)
        Return true
    EndIf
    Return false
EndFunction

; ---- Banter and off-screen life ----

Function CheckFollowerBanter(Actor[] followers)
    {From the 30 s tick, with the roster it already read. Gated only by the banter lane (the
     caller checks it) and its own game-time cooldown, never by assessments or off-screen life.}

    Float now = GetGameTimeInSeconds()
    Float nextEligible = StorageUtil.GetFloatValue(None, KEY_NEXT_BANTER_GT, 0.0)
    If nextEligible > 0.0 && now < nextEligible
        Return
    EndIf

    Actor player = Game.GetPlayer()
    If player.IsInCombat()
        Return
    EndIf

    ; Up to 10 followers in the player's cell
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

    Debug.Trace("[SeverActions_CompanionLife][Banter] Checking " + eligibleCount + " followers...")
    FireFollowerBanter(eligible, eligibleCount)
EndFunction

Function FireFollowerBanter(Actor[] eligible, Int count)
    {Claims the banter lane (TTL 0 = the 300 s default), sets the cooldown and sends the banter
     director prompt with every eligible follower and pair.}
    If !SeverActionsNativeExt2.LLMLane_TryClaim("companions.banter", 0.0)
        Return
    EndIf

    ; Cooldown first, so the next tick cannot re-fire
    Float now = GetGameTimeInSeconds()
    StorageUtil.SetFloatValue(None, KEY_LAST_BANTER_GT, now)
    Float nextCooldown = Utility.RandomFloat(SeverActionsNativeExt2.Settings_GetFloat("banterCooldownMin"), SeverActionsNativeExt2.Settings_GetFloat("banterCooldownMax")) * SECONDS_PER_GAME_HOUR
    StorageUtil.SetFloatValue(None, KEY_NEXT_BANTER_GT, now + nextCooldown)

    ; followers[]
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
        contextJson += ",\"mood\":" + (folMood as Int)
        contextJson += ",\"combatStyle\":\"" + folStyle + "\"}"
        i += 1
    EndWhile
    contextJson += "]"

    ; pairs[]: every combination, both directions
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
                String blurbAB = SeverActionsNativeExt.Native_GetPairBlurb(a, b)
                String blurbBA = SeverActionsNativeExt.Native_GetPairBlurb(b, a)

                If !firstPair
                    contextJson += ","
                EndIf
                contextJson += "{\"formIdA\":" + a.GetFormID()
                contextJson += ",\"formIdB\":" + b.GetFormID()
                contextJson += ",\"affinityAB\":" + (affinityAB as Int)
                contextJson += ",\"respectAB\":" + (respectAB as Int)
                contextJson += ",\"affinityBA\":" + (affinityBA as Int)
                contextJson += ",\"respectBA\":" + (respectBA as Int)
                ; LLM-written blurbs: a quote or newline unescaped makes SkyrimNet drop the whole context.
                contextJson += ",\"blurbAB\":\"" + SeverActionsNative.EscapeJsonString(blurbAB) + "\""
                contextJson += ",\"blurbBA\":\"" + SeverActionsNative.EscapeJsonString(blurbBA) + "\"}"
                firstPair = false
            EndIf
            j += 1
        EndWhile
        i += 1
    EndWhile
    contextJson += "]"

    ; recentBanter[]: the persisted topic history for the prompt's anti-repetition and rotation
    ; sections (get_recent_events does not surface our gamemaster_dialogue topics).
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

    ; Skip if the prompt is not installed.
    If !SeverActionsNative.Native_IsPromptAvailable("sever_follower_banter")
        SeverActionsNativeExt2.LLMLane_Release("companions.banter")
        DebugMsg("Follower banter skipped: sever_follower_banter.prompt not installed")
        Return
    EndIf

    ; Through the C++ bridge relay (the Background AI master toggle covers it), on a
    ; per-dispatch reply event name.
    If BanterEventNameCur != ""
        UnregisterForModEvent(BanterEventNameCur)
    EndIf
    BanterSeq += 1
    BanterEventNameCur = "SeverActions_LLM_Banter_" + BanterSeq
    RegisterForModEvent(BanterEventNameCur, "OnLLMBanterReady")
    Bool sent = SeverActionsNativeExt.Native_LLM_Dispatch("sever_follower_banter", contextJson, \
        BanterEventNameCur)

    If !sent
        SeverActionsNativeExt2.LLMLane_Release("companions.banter")
        Debug.Trace("[SeverActions_CompanionLife][Banter] dispatch refused (bridge down, master toggle off, or prompt missing)")
    EndIf
EndFunction

Event OnLLMBanterReady(string eventName, string strArg, float numArg, Form sender)
    {Bridge relay reply. Drops a reply not on the current channel (an expired claim's late
     callback after a re-fire).}
    UnregisterForModEvent(eventName)
    If eventName != BanterEventNameCur
        Return
    EndIf
    BanterEventNameCur = ""
    OnFollowerBanter(strArg, numArg as Int)
EndEvent

Function OnFollowerBanter(String response, Int success)
    {The banter director's reply: releases the lane and, when the LLM picked a pair, fires a
     gamemaster_dialogue event from the speaker to the target and records the topic.}
    SeverActionsNativeExt2.LLMLane_Release("companions.banter")

    If success != 1
        Debug.Trace("[SeverActions_CompanionLife][Banter] LLM call failed")
        Return
    EndIf

    ; A null "banter" is the director choosing silence
    If SeverActionsNativeExt2.Json_GetString(response, "/banter") == ""   ; null (and absent) read as empty
        Debug.Trace("[SeverActions_CompanionLife][Banter] LLM chose silence this cycle")
        Return
    EndIf

    ; The fields sit inside "banter": a root pointer misses and Json_GetString's tolerant scan finds them
    String speakerName = SeverActionsNativeExt2.Json_GetString(response, "/speaker")
    String targetName = SeverActionsNativeExt2.Json_GetString(response, "/target")
    String banterTopic = SeverActionsNativeExt2.Json_GetString(response, "/topic")

    If speakerName == "" || targetName == ""
        Debug.Trace("[SeverActions_CompanionLife][Banter] Bad LLM response - missing names")
        Return
    EndIf

    Actor[] followers = SeverActionsNativeExt.Native_GetActiveFollowerRoster()
    Actor speakerActor = ResolveFollowerByName(speakerName, followers)
    Actor targetActor = ResolveFollowerByName(targetName, followers)

    If !speakerActor || !targetActor
        Debug.Trace("[SeverActions_CompanionLife][Banter] Can't find " + speakerName + " or " + targetName)
        Return
    EndIf

    ; gamemaster_dialogue renders only speaker + topic (the "dialogue" field never reaches the
    ; LLM), so the native builder appends the direction to the topic. Built natively: Papyrus
    ; string concat corrupts non-ASCII names. isContinuation is left out: it tags a fresh
    ; banter "(continuing conversation)" in the event log and get_recent_events.
    String banterDirection = SeverActionsNativeExt2.Json_GetString(response, "/direction")
    String eventJson = SeverActionsNativeExt2.Native_BuildGMDialogueEventJson(speakerName, targetName, banterTopic, banterDirection)

    If SpeakingWouldInterruptScene(speakerActor, targetActor)
        Debug.Trace("[SeverActions_CompanionLife] gamemaster_dialogue held - a party is mid-scene")
        Return
    EndIf
    SkyrimNetApi.RegisterEvent("gamemaster_dialogue", eventJson, speakerActor, targetActor)

    Debug.Trace("[SeverActions_CompanionLife][Banter] " + speakerName + " -> " + targetName + ": " + banterTopic)

    ; The history keeps the topic only: it compares themes, and the direction is per-scene.
    String topicForHistory = banterTopic
    If topicForHistory == ""
        topicForHistory = "casual conversation"
    EndIf
    RecordBanterTopic(speakerName, targetName, topicForHistory)
EndFunction

Function RecordBanterTopic(String speakerName, String targetName, String topicText)
    {Appends a pre-escaped JSON object (speaker, target, topic) to the rolling banter history
     (StorageUtil StringList on None, capped at BanterHistoryMax); FireFollowerBanter sends it
     as the prompt's "recentBanter".}
    String obj = "{\"speaker\":\"" + SeverActionsNative.EscapeJsonString(speakerName) + "\","
    obj += "\"target\":\"" + SeverActionsNative.EscapeJsonString(targetName) + "\","
    obj += "\"topic\":\"" + SeverActionsNative.EscapeJsonString(topicText) + "\"}"
    StorageUtil.StringListAdd(None, KEY_BANTER_HISTORY, obj, true)
    While StorageUtil.StringListCount(None, KEY_BANTER_HISTORY) > BanterHistoryMax
        StorageUtil.StringListRemoveAt(None, KEY_BANTER_HISTORY, 0)
    EndWhile
EndFunction

Function CheckOffScreenLifeEvents()
    {Fires an off-screen life event for the dismissed follower with a home who is most overdue,
     at most one per tick. Each NPC has its own randomized next-eligible time.}
    If SeverActionsNativeExt2.LLMLane_IsHeld("companions.offscreenLife")
        Return
    EndIf

    ; Every tracked follower in the native cosave, dismissed ones included
    Actor[] allTracked = SeverActionsNative.Native_GetAllTrackedFollowers()
    If !allTracked || allTracked.Length == 0
        Return
    EndIf

    ; Global pacing floor, widened past 50 tracked followers, so a big roster whose windows
    ; have all expired cannot fire every tick.
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

    ; The dismissed follower most overdue for a life event
    Actor bestCandidate = None
    Float bestOverdue = 0.0

    Int i = 0
    While i < allTracked.Length
        Actor follower = allTracked[i]
        If follower && !follower.IsDead() && !_IsFollower(follower)
            ; Not while they share the player's cell (the player can see them)
            Bool skipFollower = false
            If playerCell && follower.GetParentCell() == playerCell
                skipFollower = true
            EndIf

            ; Grace period after a dismissal
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
                        ; A per-NPC override (Life Tracker page; 0 = none) replaces the global window.
                        Float overrideHours = SeverActionsNative.Native_OffScreen_GetCooldownOverride(follower)
                        Float windowMaxHours = SeverActionsNativeExt2.Settings_GetFloat("offScreenCooldownMax")
                        If overrideHours > 0.0
                            windowMaxHours = overrideHours
                        EndIf
                        ; Keep the stagger window at least Min wide: a Max of 0 (or below Min)
                        ; would make every NPC eligible at once.
                        If windowMaxHours < SeverActionsNativeExt2.Settings_GetFloat("offScreenCooldownMin")
                            windowMaxHours = SeverActionsNativeExt2.Settings_GetFloat("offScreenCooldownMin")
                        EndIf
                        If windowMaxHours <= 0.0
                            windowMaxHours = 1.0
                        EndIf

                        Float nextEligible = StorageUtil.GetFloatValue(follower, KEY_NEXT_LIFE_EVENT_GT, 0.0)
                        If nextEligible == 0.0
                            Float lastEvent = StorageUtil.GetFloatValue(follower, KEY_LAST_LIFE_EVENT_GT, 0.0)
                            If lastEvent == 0.0
                                ; First sight: a random offset inside the window staggers a wave of
                                ; dismissals; persisted so it rolls once per NPC.
                                Float initialOffset = Utility.RandomFloat(0.0, windowMaxHours) * SECONDS_PER_GAME_HOUR
                                nextEligible = now + initialOffset
                                StorageUtil.SetFloatValue(follower, KEY_NEXT_LIFE_EVENT_GT, nextEligible)
                            Else
                                ; Older save: lastEvent without nextEligible.
                                Float legacyCooldown = SeverActionsNativeExt2.Settings_GetFloat("offScreenCooldownMin")
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

    If bestCandidate
        FireOffScreenLifeEvent(bestCandidate)
    EndIf
EndFunction

Function FireOffScreenLifeEvent(Actor akActor)
    {Claims the off-screen life lane (120 s TTL), rolls the NPC's next cooldown, builds the
     context natively and dispatches the sever_offscreen_life prompt (1-2 daily events).}
    If !SeverActionsNativeExt2.LLMLane_TryClaim("companions.offscreenLife", 120.0)
        Return
    EndIf
    LastOffScreenLifeFireRT = Utility.GetCurrentRealTime()
    PendingOffScreenLifeActor = akActor
    Float nowTime = GetGameTimeInSeconds()
    StorageUtil.SetFloatValue(akActor, KEY_LAST_LIFE_EVENT_GT, nowTime)
    ; A per-NPC override beats the global window (0 = random(min, max)).
    Float fireOverrideHours = SeverActionsNative.Native_OffScreen_GetCooldownOverride(akActor)
    Float nextCooldown
    If fireOverrideHours > 0.0
        nextCooldown = fireOverrideHours * SECONDS_PER_GAME_HOUR
    Else
        nextCooldown = Utility.RandomFloat(SeverActionsNativeExt2.Settings_GetFloat("offScreenCooldownMin"), SeverActionsNativeExt2.Settings_GetFloat("offScreenCooldownMax")) * SECONDS_PER_GAME_HOUR
    EndIf
    StorageUtil.SetFloatValue(akActor, KEY_NEXT_LIFE_EVENT_GT, nowTime + nextCooldown)

    ; Native context: home, social graph, nearby dismissed followers, consequence eligibility
    Float lastConsequence = StorageUtil.GetFloatValue(akActor, KEY_LAST_CONSEQUENCE_GT, 0.0)
    Float consequenceCooldown = SeverActionsNativeExt2.Settings_GetFloat("consequenceCooldown") * SECONDS_PER_GAME_HOUR

    String contextJson = SeverActionsNative.Native_OffScreen_BuildContext(akActor, \
        SeverActionsNativeExt2.Settings_GetBool("consequencesEnabled"), consequenceCooldown, lastConsequence, nowTime)

    If contextJson == ""
        SeverActionsNativeExt2.LLMLane_Release("companions.offscreenLife")
        PendingOffScreenLifeActor = None
        DebugMsg("Off-screen life: native context build failed for " + akActor.GetDisplayName())
        Return
    EndIf

    ; Skip if the prompt is not installed.
    If !SeverActionsNative.Native_IsPromptAvailable("sever_offscreen_life")
        SeverActionsNativeExt2.LLMLane_Release("companions.offscreenLife")
        PendingOffScreenLifeActor = None
        DebugMsg("Off-screen life skipped: sever_offscreen_life.prompt not installed")
        Return
    EndIf

    ; Dispatched natively: a Papyrus SendCustomPromptToLLM reply truncates near 1024 chars.
    ; The native parser stores the events, gossip and memories, then fires
    ; SeverActions_OffScreenLifeReady (OnOffScreenLifeReady).
    Bool sent = SeverActionsNative.Native_OffScreen_RequestLifeEventLLM(akActor, contextJson, GetGameTimeInSeconds())
    If !sent
        SeverActionsNativeExt2.LLMLane_Release("companions.offscreenLife")
        PendingOffScreenLifeActor = None
        DebugMsg("Off-screen life LLM dispatch failed for " + akActor.GetDisplayName() \
            + " (SkyrimNet v8 PublicSendCustomPromptToLLM unavailable?)")
    Else
        String home = SeverActionsNative.Native_GetHome(akActor)
        DebugMsg("Off-screen life event queued via C++ for " + akActor.GetDisplayName() + " at " + home)
    EndIf
EndFunction

Event OnOffScreenLifeReady(string eventName, string strArg, float numArg, Form sender)
    {The native reply, after the parser stored the events, gossip and memories: strArg is the
     15-field pipe string, sender the actor, numArg 1 on success and 0 on LLM failure.}
    ; Release the lane (and use the pending-actor fallback) only for the dispatch in flight: a
    ; reply whose claim expired must not release a newer dispatch's claim or take its actor.
    ; The native store already filed the events under the reply's own actor.
    Actor akActor = sender as Actor
    Bool ownDispatch = akActor && akActor == PendingOffScreenLifeActor
    If !akActor && SeverActionsNativeExt2.LLMLane_IsHeld("companions.offscreenLife")
        ; The sender can be lost across the ThreadPool -> game-thread hop.
        akActor = PendingOffScreenLifeActor
        ownDispatch = true
    EndIf
    If ownDispatch
        SeverActionsNativeExt2.LLMLane_Release("companions.offscreenLife")
        PendingOffScreenLifeActor = None
    Else
        DebugMsg("Off-screen life: a reply for an expired claim (the lane belongs to a newer dispatch)")
    EndIf

    If numArg != 1.0
        DebugMsg("Off-screen life LLM failed for sender")
        Return
    EndIf
    If !akActor
        DebugMsg("Off-screen life: sender + pending actor both None")
        Return
    EndIf

    ; Re-recruited while the LLM was working: skip
    If _IsFollower(akActor)
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

    ; 15 fields, indices 0-14, in the native parser's order; 2 and 5 (the gossip flags) are not read
    String summary1 = PipeField(parsed, 0)
    String type1    = PipeField(parsed, 1)
    String summary2 = PipeField(parsed, 3)
    String type2    = PipeField(parsed, 4)

    If summary1 == ""
        DebugMsg("Off-screen life: no events parsed from response for " + actorName)
        Return
    EndIf

    ; The life summary, read by prompts through the sever_life_summary decorator.
    String lifeSummary = summary1
    If summary2 != ""
        lifeSummary += " " + summary2
    EndIf
    SeverActionsNativeExt.Native_SetLifeSummary(akActor, lifeSummary)

    ; Re-roll survival needs to stand in for eating, resting and exposure while away.
    If !SeverActionsNative.Native_Survival_IsExcluded(akActor)
        Int newHunger = Utility.RandomInt(5, 45)
        Int newFatigue = Utility.RandomInt(5, 50)
        Int newCold = Utility.RandomInt(0, 20)
        SeverActionsNative.Native_Survival_SetNeeds(akActor, newHunger as Float, newFatigue as Float, newCold as Float)
        DebugMsg("Off-screen life: randomized survival for " + actorName + " H=" + newHunger + " F=" + newFatigue + " C=" + newCold)
    EndIf

    ; The event history, read by prompts through the sever_life_event_history decorator.
    String eventHistory = SeverActionsNative.Native_OffScreen_GetRecentLifeEvents(akActor, 10, currentGameTime)
    If eventHistory != ""
        SeverActionsNativeExt.Native_SetLifeEventHistory(akActor, eventHistory)
    EndIf

    ; Persistent events, so the follower remembers them
    SkyrimNetApi.RegisterEvent("persistent_generic", WrapPersistentEvent(actorName + ": " + summary1), akActor, None)
    If summary2 != ""
        SkyrimNetApi.RegisterEvent("persistent_generic", WrapPersistentEvent(actorName + ": " + summary2), akActor, None)
    EndIf

    ; Memories (this actor's and the involved NPCs') and the rumor gossip are the native parser's:
    ; long text garbles on the Papyrus path.

    ; Consequences
    If SeverActionsNativeExt2.Settings_GetBool("consequencesEnabled")
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
                ; Needs the amount (field 7) and the item fields (10-12), so not the
                ; 6-arg dispatch below.
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

    ; Involved NPCs share the event; the field is validated against pipe/JSON remnants.
    String involvedStr = PipeField(parsed, 13)
    involvedStr = SeverActionsNative.TrimString(involvedStr)
    If involvedStr != "" && StringUtil.GetLength(involvedStr) >= 3 && StringUtil.Find(involvedStr, "|") < 0 && StringUtil.Find(involvedStr, "0") != 0 && StringUtil.Find(involvedStr, "{") < 0
        ; Comma-separated names
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

            ; 3+ chars, no pipe, not starting with 0, no bracket
            If involvedName != "" && StringUtil.GetLength(involvedName) >= 3 && StringUtil.Find(involvedName, "|") < 0 && StringUtil.Find(involvedName, "0") != 0 && StringUtil.Find(involvedName, "[") < 0
                Actor involvedActor = SeverActionsNative.FindActorByName(involvedName)
                If involvedActor && involvedActor != akActor
                    SkyrimNetApi.RegisterEvent("persistent_generic", WrapPersistentEvent(involvedName + ": " + summary1), involvedActor, akActor)
                    If summary2 != ""
                        SkyrimNetApi.RegisterEvent("persistent_generic", WrapPersistentEvent(involvedName + ": " + summary2), involvedActor, akActor)
                    EndIf
                    DebugMsg("Off-screen life: shared event + memory registered for " + involvedName)
                EndIf
            EndIf
        EndWhile
    EndIf

    ; Field 14: a diary entry was requested
    If PipeField(parsed, 14) == "1"
        SkyrimNetApi.GenerateDiaryEntry(akActor)
        DebugMsg("Off-screen life: diary entry requested for " + actorName)
    EndIf

    If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.hasBeenBusyAt", ("" + actorName), ("" + home)))
    EndIf

    DebugMsg("Off-screen life: " + actorName + " -> " + lifeSummary)
EndEvent

String Function PipeField(String data, Int fieldIndex)
    {Field fieldIndex (0-based) of a pipe-delimited string; "" when out of range.}
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
    ElseIf nextPipe == pos
        Return ""  ; Substring with length 0 would return the rest of the string
    EndIf
    Return StringUtil.Substring(data, pos, nextPipe - pos)
EndFunction

Function AppendGossip(String locationName, String gossipText)
    {Appends to a location's gossip ring: StorageUtil string "SeverGossip_<location>" on None,
     pipe-delimited, the newest 3 kept, and lists the place in SeverGossip_Places. Read by the
     0185 gossip prompt; SeverActions_Kidnap keeps a twin.}
    String gossipKey = "SeverGossip_" + locationName
    ; The 0185 gossip prompt finds each ring through this index of place names.
    StorageUtil.StringListAdd(None, "SeverGossip_Places", locationName, false)
    String existing = StorageUtil.GetStringValue(None, gossipKey, "")

    If existing == ""
        StorageUtil.SetStringValue(None, gossipKey, gossipText)
        Return
    EndIf

    ; Count the items
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
    {Whether the follower is excluded from off-screen life (the FollowerDataStore flag).}
    If !akActor
        Return false
    EndIf
    Return SeverActionsNative.Native_GetOffscreenExcluded(akActor)
EndFunction

Function SetOffScreenExcluded(Actor akActor, Bool excluded)
    {Sets or clears the off-screen life exclusion flag.}
    If akActor
        SeverActionsNative.Native_SetOffscreenExcluded(akActor, excluded)
    EndIf
EndFunction

Function ToggleOffScreenExcluded(Actor akActor)
    {Toggles the off-screen life exclusion flag.}
    If IsOffScreenExcluded(akActor)
        SetOffScreenExcluded(akActor, false)
    Else
        SetOffScreenExcluded(akActor, true)
    EndIf
EndFunction

Actor[] Function GetDismissedFollowersInHold(String holdName)
    {Up to 10 dismissed, non-excluded followers whose home and holdName contain one another,
     in a None-padded array.}
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
        If follower && !follower.IsDead() && !_IsFollower(follower)
            String followerHome = SeverActionsNative.Native_GetHome(follower)
            If followerHome != ""
                ; "Whiterun" matches "Whiterun Breezehome"
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

    If resultCount == 0
        Return new Actor[1]
    EndIf
    Return result
EndFunction

Actor Function FindFollowerByName(String targetName)
    {Any tracked follower, active or dismissed, by display name (ResolveFollowerByName).}
    If targetName == ""
        Return None
    EndIf
    Actor[] allTracked = SeverActionsNative.Native_GetAllTrackedFollowers()
    If !allTracked || allTracked.Length == 0
        Return None
    EndIf
    Return ResolveFollowerByName(targetName, allTracked)
EndFunction

Function ProcessOffScreenConsequence(Actor akActor, String home, String conseqType, Int amount, String reason, String crime)
    {Routes an off-screen consequence (arrest, gold_change, debt, bounty, item_acquired) and
     stamps the consequence cooldown; an unknown type is logged and ignored.}
    String actorName = akActor.GetDisplayName()

    If conseqType == "arrest"
        ProcessOffScreenArrest(akActor, home, crime, amount)
    ElseIf conseqType == "gold_change"
        ProcessOffScreenGoldChange(akActor, amount, reason)
    ElseIf conseqType == "debt"
        ProcessOffScreenDebt(akActor, amount, reason)
    ElseIf conseqType == "bounty"
        ; Wanted, not caught
        ProcessOffScreenBounty(akActor, home, crime, amount)
    ElseIf conseqType == "item_acquired"
        ; Repurposed fields: see ProcessOffScreenItemAcquired
        ProcessOffScreenItemAcquired(akActor, reason, crime, amount)
    Else
        DebugMsg("Off-screen consequence: unknown type '" + conseqType + "' for " + actorName)
        Return
    EndIf

    ; Consequence cooldown
    StorageUtil.SetFloatValue(akActor, KEY_LAST_CONSEQUENCE_GT, GetGameTimeInSeconds())
EndFunction

Function ProcessOffScreenArrest(Actor akActor, String home, String crime, Int bounty)
    {Arrest consequence: records the bounty (cumulative cap maxBounty), the event and the
     gossip, then hands the physical jailing to the arrest module (arrest.offscreenJail).}
    String actorName = akActor.GetDisplayName()

    ; Their Enterprises venture may already have jailed them this settlement week; the venture
    ; owns that beat, and a second arrest here would stack a second bounty.
    If SeverActionsNativeExt2.Venture_ClaimsJailThisWeek(akActor)
        DebugMsg("Off-screen arrest SKIPPED for " + actorName + " - their venture already put them in custody this week")
        Return
    EndIf

    If bounty <= 0
        bounty = 100
    EndIf

    ; Cumulative cap
    Int currentTotal = StorageUtil.GetIntValue(akActor, KEY_OFFSCREEN_BOUNTY_TOTAL, 0)
    If currentTotal + bounty > SeverActionsNativeExt2.Settings_GetInt("maxBounty")
        bounty = SeverActionsNativeExt2.Settings_GetInt("maxBounty") - currentTotal
        If bounty <= 0
            DebugMsg("Off-screen arrest: " + actorName + " at bounty cap (" + SeverActionsNativeExt2.Settings_GetInt("maxBounty") + "), skipping")
            Return
        EndIf
    EndIf

    StorageUtil.SetIntValue(akActor, KEY_OFFSCREEN_BOUNTY_TOTAL, currentTotal + bounty)

    String crimeStr = crime
    If crimeStr == ""
        crimeStr = "a minor offense"
    EndIf

    DebugMsg("Off-screen arrest: " + actorName + " +" + bounty + " bounty for " + crimeStr + " in " + home)

    SkyrimNetApi.RegisterEvent("persistent_generic", WrapPersistentEvent(actorName + " was arrested for " + crimeStr + " in " + home + " and has a " + (currentTotal + bounty) + " gold bounty."), akActor, None)

    AppendGossip(home, actorName + " was arrested for " + crimeStr + "!")

    ; The native store, for the UI
    SeverActionsNative.Native_OffScreen_IncrementBounty(akActor, bounty)
    SeverActionsNative.Native_OffScreen_IncrementArrestCount(akActor)
    SeverActionsNative.Native_OffScreen_AddEvent(akActor, actorName + " was arrested for " + crimeStr + " in " + home, "significant", GetGameTimeInSeconds(), true, "arrest", bounty, crimeStr, "")

    ; The physical jailing is SeverActions_Arrest's; it resolves the hold's jail from the home
    ; name. An async verb (DR3): without the arrest module the bounty stands and nobody moves.
    ; args = target|target2|str|int|str2|targetFid|target2Fid (the actionId is prepended);
    ; the target is the sender, str the home.
    SeverActionsNativeExt2.Verb_Send("arrest", "offscreenJail", "||" + home, akActor)

    If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
        Debug.Notification(actorName + " was arrested in " + home + "! (" + bounty + " bounty)")
    EndIf
EndFunction

Function ProcessOffScreenBounty(Actor akActor, String home, String crime, Int bounty)
    {Bounty without arrest (wanted, not caught), under the same cumulative maxBounty cap.}
    String actorName = akActor.GetDisplayName()

    ; The venture-jail yield of ProcessOffScreenArrest.
    If SeverActionsNativeExt2.Venture_ClaimsJailThisWeek(akActor)
        DebugMsg("Off-screen bounty SKIPPED for " + actorName + " - their venture already put them in custody this week")
        Return
    EndIf

    If bounty <= 0
        bounty = 50
    EndIf

    ; Cumulative cap
    Int currentTotal = StorageUtil.GetIntValue(akActor, KEY_OFFSCREEN_BOUNTY_TOTAL, 0)
    If currentTotal + bounty > SeverActionsNativeExt2.Settings_GetInt("maxBounty")
        bounty = SeverActionsNativeExt2.Settings_GetInt("maxBounty") - currentTotal
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

    SeverActionsNative.Native_OffScreen_IncrementBounty(akActor, bounty)
    SeverActionsNative.Native_OffScreen_AddEvent(akActor, actorName + " is wanted for " + crimeStr + " in " + home, "notable", GetGameTimeInSeconds(), true, "bounty", bounty, crimeStr, "")

    DebugMsg("Off-screen bounty: " + actorName + " +" + bounty + " for " + crimeStr + " in " + home)
EndFunction

Function ProcessOffScreenGoldChange(Actor akActor, Int amount, String reason)
    {Adds or removes gold, capped at maxGoldChange either way; never below 0 gold.}
    String actorName = akActor.GetDisplayName()

    If amount > SeverActionsNativeExt2.Settings_GetInt("maxGoldChange")
        amount = SeverActionsNativeExt2.Settings_GetInt("maxGoldChange")
    ElseIf amount < 0 && (0 - amount) > SeverActionsNativeExt2.Settings_GetInt("maxGoldChange")
        amount = 0 - SeverActionsNativeExt2.Settings_GetInt("maxGoldChange")
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
    {Adds to the actor's off-screen debt (a StorageUtil accumulator plus the native store),
     capped at maxGoldChange per event. No creditor is involved.}
    String actorName = akActor.GetDisplayName()

    If amount <= 0
        Return
    EndIf

    If amount > SeverActionsNativeExt2.Settings_GetInt("maxGoldChange")
        amount = SeverActionsNativeExt2.Settings_GetInt("maxGoldChange")
    EndIf

    Int currentDebt = StorageUtil.GetIntValue(akActor, KEY_OFFSCREEN_DEBT, 0)
    StorageUtil.SetIntValue(akActor, KEY_OFFSCREEN_DEBT, currentDebt + amount)

    SkyrimNetApi.RegisterEvent("persistent_generic", WrapPersistentEvent(actorName + " incurred a debt of " + amount + " gold for " + reason + "."), akActor, None)

    SeverActionsNative.Native_OffScreen_IncrementDebt(akActor, amount)
    SeverActionsNative.Native_OffScreen_AddEvent(akActor, actorName + " incurred " + amount + " gold debt for " + reason, "notable", GetGameTimeInSeconds(), true, "debt", amount, "", "")

    If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.tookOnGoldInDebt", ("" + actorName), ("" + amount)))
    EndIf

    DebugMsg("Off-screen debt: " + actorName + " +" + amount + "g (" + reason + ")")
EndFunction

Function ProcessOffScreenPurchase(Actor akActor, Int cost, String reason, String itemName, String category, Int count)
    {The NPC bought something: the gold leaves their inventory (capped at maxGoldChange and at
     what they carry; an empty purse skips it, so no item comes free) and the item lands in it
     via the item_acquired resolver. An unresolvable item still spends the gold.}
    String actorName = akActor.GetDisplayName()
    If cost <= 0
        DebugMsg("Off-screen purchase: no cost given for " + actorName + ", ignoring")
        Return
    EndIf
    If cost > SeverActionsNativeExt2.Settings_GetInt("maxGoldChange")
        cost = SeverActionsNativeExt2.Settings_GetInt("maxGoldChange")
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

    ; Item: capped and category-defaulted like item_acquired.
    If count > 5
        count = 5
    EndIf
    If count <= 0
        count = 1
    EndIf
    If category == ""
        category = "any"
    EndIf
    ; Native_GiveItemByName returns true once the give is queued, so resolve first.
    String resolvedName = ""
    If itemName != ""
        resolvedName = SeverActionsNative.Native_ResolveItemName(itemName, category)
    EndIf
    Bool gotItem = false
    If resolvedName != ""
        gotItem = SeverActionsNative.Native_GiveItemByName(akActor, itemName, category, count)
    EndIf

    String eventText
    If gotItem
        eventText = actorName + " spent " + cost + " gold on " + resolvedName + " — " + reason
    Else
        eventText = actorName + " spent " + cost + " gold — " + reason
    EndIf
    SkyrimNetApi.RegisterEvent("persistent_generic", WrapPersistentEvent(eventText + "."), akActor, None)
    SeverActionsNative.Native_OffScreen_AddEvent(akActor, eventText, "notable", GetGameTimeInSeconds(), true, "gold_change", 0 - cost, "", "")
    DebugMsg("Off-screen purchase: " + actorName + " -" + cost + "g for '" + itemName + "' (resolved=" + gotItem + ", " + reason + ")")

    ; The consequence cooldown ProcessOffScreenConsequence stamps for the other kinds.
    StorageUtil.SetFloatValue(akActor, KEY_LAST_CONSEQUENCE_GT, GetGameTimeInSeconds())
EndFunction

Function ProcessOffScreenItemAcquired(Actor akActor, String itemName, String category, Int count)
    {Gives a dismissed follower up to 5 of an item by fuzzy name (category "" = "any"). From the
     item_acquired consequence, whose dispatch passes reason = item name, crime = category,
     amount = count.}
    String actorName = akActor.GetDisplayName()

    If itemName == "" || count <= 0
        DebugMsg("Off-screen item: invalid params for " + actorName + " (item='" + itemName + "', count=" + count + ")")
        Return
    EndIf

    If count > 5
        count = 5
    EndIf

    If category == ""
        category = "any"
    EndIf

    ; The native item resolver (4-stage, fuzzy last)
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

    String eventDesc = actorName + " acquired " + resolvedName
    If count > 1
        eventDesc = actorName + " acquired " + count + " " + resolvedName
    EndIf
    SkyrimNetApi.RegisterEvent("persistent_generic", WrapPersistentEvent(eventDesc + "."), akActor, None)

    ; The native store, for the UI
    SeverActionsNative.Native_OffScreen_AddEvent(akActor, eventDesc, "notable", GetGameTimeInSeconds(), true, "item_acquired", count, itemName, "")

    If SeverActionsNativeExt2.Settings_GetBool("showNotifications")
        Debug.Notification(actorName + " acquired " + count + "x " + resolvedName)
    EndIf

    DebugMsg("Off-screen item: " + actorName + " +" + count + "x " + resolvedName + " (searched: '" + itemName + "', cat: " + category + ")")
EndFunction

String Function GetCombatStyle(Actor akActor)
    {The native combat style, with "" and the legacy "balanced" read as "no combat style" (a
     copy of FollowerManager's reader, for the banter context).}
    If !akActor
        Return "no combat style"
    EndIf
    String nativeStyle = SeverActionsNative.Native_GetCombatStyle(akActor)
    If nativeStyle == "" || nativeStyle == "balanced"
        Return "no combat style"
    EndIf
    Return nativeStyle
EndFunction

Actor Function ResolveFollowerByName(String targetName, Actor[] followers)
    {The follower named targetName: exact match first (Papyrus == ignores case), then either
     name containing the other. None when nothing matches.}
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

    ; Fallback: either name contains the other (e.g. a first name)
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

Event OnInit()
    ; Existing saves hold this instance since P3-02 (F6); no setup here (DR20).
    Debug.Trace("[SeverActions] SeverActions_CompanionLife: bound")
EndEvent
