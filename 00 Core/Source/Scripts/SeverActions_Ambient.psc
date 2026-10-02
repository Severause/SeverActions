Scriptname SeverActions_Ambient extends Quest
{Ambient Life (the social module, half one): ambient NPC banter near the player and the
 ambient ACTION director - scan and LLM dispatch through the kernel scanners, the social gate
 poll, and the chosen action sent as its OWNING module's verb, so this script names no other
 module's type. Moved from SeverActions_FollowerManager, which keeps a safe-exit stub per
 function (F7). Maintenance runs from the social provider's stage 1 (DR20). Own chronometer
 chain SeverActions_Tick_Ambient (30 s; 2 s while a social gate is polled; watched by
 SeverActions_Mod_Social).}

Float Property SECONDS_PER_GAME_HOUR = 3631.0 AutoReadOnly
Float Property AmbientSceneSeparationHours = 1.0 AutoReadOnly
{Minimum game hours between ambient scenes of either kind (banter or action).}
String Property KEY_LAST_AMBIENT_GT = "SeverActions_LastAmbientGT" AutoReadOnly
String Property KEY_NEXT_AMBIENT_GT = "SeverActions_NextAmbientGT" AutoReadOnly
String Property KEY_NEXT_AMBIENT_ACTION_GT = "SeverActions_NextAmbientActionGT" AutoReadOnly
; Game time of the last scene EITHER ambient system dispatched (silence cycles don't count);
; both Check functions wait AmbientSceneSeparationHours past it.
String Property KEY_LAST_AMBIENT_SCENE_GT = "SeverActions_LastAmbientSceneGT" AutoReadOnly

; The in-flight gates are the social.ambientBanter / social.ambientAction lanes (default
; 300 s TTL); the action lane stays held while a social gate is adjudicated (until _FinishAmbientGate).
; Social-gate poll state: while AmbientGatePolling the tick runs at 2 s and drives
; PollAmbientGate. Never a Utility.Wait loop in the handler: it held the VM stack and
; serialized sibling ModEvents. The native gate owns settling, adjudication and the busy lock.
Bool AmbientGatePolling = false
Actor _AmbientGateInitiator = None
String _AmbientGateAction = ""
String _AmbientGateDest = ""
Actor _AmbientGateTarget = None
String _AmbientGateItem = ""
Int _AmbientGateQty = 1
Int _AmbientGateGold = 0
Bool _AmbientGateWait = false
Int _AmbientGatePollCount = 0
Bool _ambientTickInFlight = false
Float _ambientTickStartedRT = 0.0

Function Maintenance()
    {Load recovery from the social provider's stage 1 (every load and new game): registers
     the two scanner reply listeners, clears the save-persisted gate poll state (the native
     gate resets on revert) and arms the tick. The lanes clear on revert themselves.}
    _ambientTickInFlight = false
    _ambientTickStartedRT = 0.0
    AmbientGatePolling      = false
    _AmbientGateInitiator   = None
    _AmbientGatePollCount   = 0
    ; From AmbientBanterScanner once the LLM reply is parsed.
    RegisterForModEvent("SeverActions_AmbientBanterReady", "OnAmbientBanterReady")
    ; From AmbientActionScanner once the director picks an intent or declines.
    RegisterForModEvent("SeverActions_AmbientActionReady", "OnAmbientActionReady")
    ChronoArm(30.0)
EndFunction

Function ChronoArm(Float afSeconds)
    {This script's one-shot chronometer tick: event name AND callback name unique per script.}
    RegisterForModEvent("SeverActions_Tick_Ambient", "OnChronoTick_Ambient")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_Ambient", afSeconds)
EndFunction

Event OnChronoTick_Ambient(String eventName, String strArg, Float numArg, Form sender)
    {The ambient pass. While a social gate is armed it runs at 2 s and drives PollAmbientGate
     instead of the 30 s body (the held action lane blocks new cycles anyway). Re-armed FIRST
     (the acknowledgement the watchdog counts); a stuck in-flight guard clears after 120 s.}
    If AmbientGatePolling
        PollAmbientGate()
        If AmbientGatePolling
            ChronoArm(2.0)
        Else
            ChronoArm(30.0)
        EndIf
        Return
    EndIf
    ChronoArm(30.0)
    If _ambientTickInFlight
        Float inFlightFor = Utility.GetCurrentRealTime() - _ambientTickStartedRT
        If inFlightFor >= 0.0 && inFlightFor < 120.0
            Return
        EndIf
        Debug.Trace("[SeverActions_Ambient] tick guard STUCK (" + inFlightFor + " s) - clearing")
    EndIf
    _ambientTickInFlight = true
    _ambientTickStartedRT = Utility.GetCurrentRealTime()
    ; Banter and actions draw on the same nearby NPCs, so neither starts a cycle while
    ; either lane is held; the shared scene stamp spaces them after completion.
    If SeverActionsNativeExt2.Settings_GetBool("ambientBanterEnabled") && !SeverActionsNativeExt2.LLMLane_IsHeld("social.ambientBanter") && !SeverActionsNativeExt2.LLMLane_IsHeld("social.ambientAction")
        CheckAmbientBanter()
    EndIf
    If SeverActionsNativeExt2.Settings_GetBool("ambientActionsEnabled") && !SeverActionsNativeExt2.LLMLane_IsHeld("social.ambientAction") && !SeverActionsNativeExt2.LLMLane_IsHeld("social.ambientBanter")
        CheckAmbientAction()
    EndIf
    _ambientTickInFlight = false
EndEvent

Float Function GetGameTimeInSeconds()
    {Game time as game hours x SECONDS_PER_GAME_HOUR (~seconds); every ambient stamp uses this scale.}
    Return Utility.GetCurrentGameTime() * 24.0 * SECONDS_PER_GAME_HOUR
EndFunction

Bool Function SpeakingWouldInterruptScene(Actor akSpeaker, Actor akTarget)
    {True when either actor is in a running scene. A named speaker skips SkyrimNet's own
     speaker filters, so every gamemaster_dialogue emitter asks this first.}
    If akSpeaker && SeverActionsNative.Native_IsActorInScene(akSpeaker)
        Return true
    EndIf
    If akTarget && SeverActionsNative.Native_IsActorInScene(akTarget)
        Return true
    EndIf
    Return false
EndFunction

Function CheckAmbientBanter()
    {Per 30 s tick: past the cooldown, the scene separation and a combat check, asks the C++
     scanner for non-follower NPC pairs in the player's cell (none while a hostile actor is
     within hearing range) and has the LLM decide whether one speaks to the other.
     Independent of follower banter.}

    Float now = GetGameTimeInSeconds()
    Float nextEligible = StorageUtil.GetFloatValue(None, KEY_NEXT_AMBIENT_GT, 0.0)
    If nextEligible > 0.0 && now < nextEligible
        Return
    EndIf

    ; Separation from the last ambient scene of either kind.
    Float lastScene = StorageUtil.GetFloatValue(None, KEY_LAST_AMBIENT_SCENE_GT, 0.0)
    If lastScene > 0.0 && now < lastScene + (AmbientSceneSeparationHours * SECONDS_PER_GAME_HOUR)
        Return
    EndIf

    Actor player = Game.GetPlayer()
    If player.IsInCombat()
        Return
    EndIf

    ; 0 for every argument = the scanner's defaults.
    Int pairCount = SeverActionsNativeExt.Native_AmbientBanter_ScanAndCache(0.0, 0.0, 0)
    If pairCount < 1
        Return
    EndIf

    Debug.Trace("[SeverActions_Ambient][Banter] " + pairCount + " candidate pair(s) found")
    FireAmbientBanter(pairCount)
EndFunction

Function FireAmbientBanter(Int pairCount)
    {Dispatches the ambient-banter LLM request natively. The DLL builds the context, parses
     the reply and assembles the event JSON so UTF-8 names survive; never build it with
     Papyrus String concat, which mangles non-ASCII names (issue #9).}
    If !SeverActionsNativeExt2.LLMLane_TryClaim("social.ambientBanter", 0.0)
        Return
    EndIf

    ; Cooldown set up front so nothing re-fires while the request is in flight.
    Float now = GetGameTimeInSeconds()
    StorageUtil.SetFloatValue(None, KEY_LAST_AMBIENT_GT, now)
    Float nextCooldown = Utility.RandomFloat(SeverActionsNativeExt2.Settings_GetFloat("ambientBanterCooldownMin"), SeverActionsNativeExt2.Settings_GetFloat("ambientBanterCooldownMax")) * SECONDS_PER_GAME_HOUR
    StorageUtil.SetFloatValue(None, KEY_NEXT_AMBIENT_GT, now + nextCooldown)

    ; The prompt is an optional FOMOD install.
    If !SeverActionsNative.Native_IsPromptAvailable("sever_ambient_banter")
        SeverActionsNativeExt2.LLMLane_Release("social.ambientBanter")
        Debug.Trace("[SeverActions_Ambient][Banter] skipped: sever_ambient_banter.prompt not installed")
        Return
    EndIf

    ; Re-runs the scan (pairs may have dispersed); 0 = the scanner's defaults.
    Int dispatched = SeverActionsNativeExt.Native_AmbientBanter_FireToLLM(0.0, 0.0, 0)

    If dispatched <= 0
        SeverActionsNativeExt2.LLMLane_Release("social.ambientBanter")
        If dispatched == 0
            Debug.Trace("[SeverActions_Ambient][Banter] no pairs after re-scan (hostile cell or pairs dispersed)")
        Else
            Debug.Trace("[SeverActions_Ambient][Banter] native dispatch failed (SkyrimNet v8 PublicAPI unavailable?)")
        EndIf
    EndIf
    ; On success the lane stays held until OnAmbientBanterReady.
EndFunction

Event OnAmbientBanterReady(string eventName, string strArg, float numArg, Form sender)
    {numArg 1.0 = the DLL has a gamemaster_dialogue event ready in its slot; 0.0 = silence
     or failure (the DLL logged why). No String concat on names here (see FireAmbientBanter).}
    SeverActionsNativeExt2.LLMLane_Release("social.ambientBanter")

    If numArg < 0.5
        Return
    EndIf

    String eventJson    = SeverActionsNativeExt.Native_AmbientBanter_GetReadyEventJson()
    Actor speakerActor  = SeverActionsNativeExt.Native_AmbientBanter_GetReadySpeaker()
    Actor targetActor   = SeverActionsNativeExt.Native_AmbientBanter_GetReadyTarget()
    SeverActionsNativeExt.Native_AmbientBanter_ClearReady()

    If eventJson == "" || !speakerActor || !targetActor
        Debug.Trace("[SeverActions_Ambient][Banter] ready slot was empty - race or stale call?")
        Return
    EndIf

    If SpeakingWouldInterruptScene(speakerActor, targetActor)
        Debug.Trace("[SeverActions_Ambient] gamemaster_dialogue held - a party is mid-scene")
        Return
    EndIf
    SkyrimNetApi.RegisterEvent("gamemaster_dialogue", eventJson, speakerActor, targetActor)

    ; A scene was staged: stamp the shared separation.
    StorageUtil.SetFloatValue(None, KEY_LAST_AMBIENT_SCENE_GT, GetGameTimeInSeconds())

    Debug.Trace("[SeverActions_Ambient][Banter] dispatched (speaker=" + speakerActor.GetDisplayName() + ", target=" + targetActor.GetDisplayName() + ")")
EndEvent

Function CheckAmbientAction()
    {Per 30 s tick: past the cooldown, separation and combat checks, has the native
     AmbientActionScanner ask the sever_ambient_action_director LLM for a nearby non-follower
     NPC and an action (it usually declines). OnAmbientActionReady handles the result.}

    Float now = GetGameTimeInSeconds()
    Float nextEligible = StorageUtil.GetFloatValue(None, KEY_NEXT_AMBIENT_ACTION_GT, 0.0)
    If nextEligible > 0.0 && now < nextEligible
        Return
    EndIf

    ; Separation from the last ambient scene of either kind.
    Float lastScene = StorageUtil.GetFloatValue(None, KEY_LAST_AMBIENT_SCENE_GT, 0.0)
    If lastScene > 0.0 && now < lastScene + (AmbientSceneSeparationHours * SECONDS_PER_GAME_HOUR)
        Return
    EndIf

    Actor player = Game.GetPlayer()
    If player.IsInCombat()
        Return
    EndIf

    ; The director prompt is an optional FOMOD install; if absent, back off about a game hour.
    If !SeverActionsNative.Native_IsPromptAvailable("sever_ambient_action_director")
        StorageUtil.SetFloatValue(None, KEY_NEXT_AMBIENT_ACTION_GT, now + 3600.0)
        Return
    EndIf

    If !SeverActionsNativeExt2.LLMLane_TryClaim("social.ambientAction", 0.0)
        Return
    EndIf

    ; Cooldown set up front so nothing re-fires while the request is in flight.
    Float nextCooldown = Utility.RandomFloat(SeverActionsNativeExt2.Settings_GetFloat("ambientActionCooldownMin"), SeverActionsNativeExt2.Settings_GetFloat("ambientActionCooldownMax")) * SECONDS_PER_GAME_HOUR
    StorageUtil.SetFloatValue(None, KEY_NEXT_AMBIENT_ACTION_GT, now + nextCooldown)

    ; 0 for every argument = the scanner's defaults.
    Int dispatched = SeverActionsNativeExt2.Native_AmbientAction_FireToLLM(0.0, 0.0, 0)
    ; No candidates comes back through OnAmbientActionReady (kind 0); 0 here means the native is unbound.
    If dispatched <= 0
        SeverActionsNativeExt2.LLMLane_Release("social.ambientAction")
        Debug.Trace("[SeverActions_Ambient][Action] native dispatch failed (custom-prompt API unavailable, or the native is unbound)")
    EndIf
    ; On success the lane stays held until OnAmbientActionReady.
EndFunction

Event OnAmbientActionReady(string eventName, string strArg, float numArg, Form sender)
    {The director produced an intent or declined. numArg = IntentKind: 0 none,
     1 solo (execute now), 2 social (announce, then the gate).}
    Int kind = numArg as Int

    If kind == 0
        SeverActionsNativeExt2.LLMLane_Release("social.ambientAction")
        Return
    EndIf

    ; Stamp the shared separation now, not at commit, so banter also stays off a pair
    ; whose social gate is in progress.
    StorageUtil.SetFloatValue(None, KEY_LAST_AMBIENT_SCENE_GT, GetGameTimeInSeconds())

    Actor initiator     = SeverActionsNativeExt2.Native_AmbientAction_GetInitiator()
    String actionName   = SeverActionsNativeExt2.Native_AmbientAction_GetActionName()
    String destination  = SeverActionsNativeExt2.Native_AmbientAction_GetDestination()
    Actor targetActor   = SeverActionsNativeExt2.Native_AmbientAction_GetTarget()
    String itemName     = SeverActionsNativeExt2.Native_AmbientAction_GetItemName()
    Int qty             = SeverActionsNativeExt2.Native_AmbientAction_GetQuantity()
    Int goldAmt         = SeverActionsNativeExt2.Native_AmbientAction_GetGold()
    ; Read before ClearReady, which wipes the slot; for a solo brawl it is the challenge line.
    String soloAnnounceJson = SeverActionsNativeExt2.Native_AmbientAction_GetAnnounceEventJson()
    Bool waitForPlayer  = SeverActionsNativeExt2.Native_AmbientAction_GetWaitForPlayer()

    If !initiator || actionName == ""
        Debug.Trace("[SeverActions_Ambient][Action] ready slot unusable - clearing")
        SeverActionsNativeExt2.Native_AmbientAction_ClearReady()
        SeverActionsNativeExt2.LLMLane_Release("social.ambientAction")
        Return
    EndIf

    If kind == 1
        ; SOLO (ChallengeBrawl, UseItem): execute now; the DLL validated the params.
        SeverActionsNativeExt2.Native_AmbientAction_ClearReady()
        DispatchAmbientAction(initiator, actionName, destination, targetActor, itemName, qty, goldAmt, waitForPlayer)
        ; Brawl: the verb is queued, but its pending state lands long before any LLM reply; speak
        ; the challenge so the target's LLM accepts or declines (unspoken, it times out into a decline).
        If actionName == "ChallengeBrawl" && targetActor && soloAnnounceJson != "" \
            && !SpeakingWouldInterruptScene(initiator, targetActor)
            SkyrimNetApi.RegisterEvent("gamemaster_dialogue", soloAnnounceJson, initiator, targetActor)
        EndIf
        SeverActionsNativeExt2.LLMLane_Release("social.ambientAction")
        Debug.Trace("[SeverActions_Ambient][Action] SOLO dispatched: " + initiator.GetDisplayName() + " " + actionName)
        Return
    EndIf

    ; SOCIAL (kind 2): announce, let the dialogue rounds finish, then the native gate adjudicates.
    Actor addressee     = SeverActionsNativeExt2.Native_AmbientAction_GetAddressee()
    String announceJson = SeverActionsNativeExt2.Native_AmbientAction_GetAnnounceEventJson()
    SeverActionsNativeExt2.Native_AmbientAction_ClearReady()

    If !addressee || announceJson == ""
        Debug.Trace("[SeverActions_Ambient][Action] social intent missing addressee/announce - aborting gate")
        SeverActionsNativeExt2.Native_AmbientAction_AbortGate(initiator)
        SeverActionsNativeExt2.LLMLane_Release("social.ambientAction")
        Return
    EndIf

    If SpeakingWouldInterruptScene(initiator, addressee)
        ; The director armed the gate before firing: a bare Return would leave the initiator
        ; busy until the next load and hold the lane (blocking banter too) until its TTL.
        Debug.Trace("[SeverActions_Ambient][Action] SOCIAL announce held - a party is mid-scene; gate aborted")
        SeverActionsNativeExt2.Native_AmbientAction_AbortGate(initiator)
        SeverActionsNativeExt2.LLMLane_Release("social.ambientAction")
        Return
    EndIf
    SkyrimNetApi.RegisterEvent("gamemaster_dialogue", announceJson, initiator, addressee)
    Debug.Trace("[SeverActions_Ambient][Action] SOCIAL announced: " + initiator.GetDisplayName() + " -> " + addressee.GetDisplayName() + " (dest " + destination + ")")

    ; Hand off to the 2 s gate poll; the lane stays held until _FinishAmbientGate.
    _AmbientGateInitiator = initiator
    _AmbientGateAction    = actionName
    _AmbientGateDest      = destination
    _AmbientGateTarget    = targetActor
    _AmbientGateItem      = itemName
    _AmbientGateQty       = qty
    _AmbientGateGold      = goldAmt
    _AmbientGateWait      = waitForPlayer
    _AmbientGatePollCount = 0
    AmbientGatePolling    = true
    ChronoArm(2.0)
EndEvent

Function PollAmbientGate()
    {One social-gate poll per 2 s tick while AmbientGatePolling; commits the action only on GO.
     Codes mirror AmbientActionScanner::PollResult: 0 pending, 1 go, 2 blocked,
     3 done (deferred/aborted/no gate).}
    Actor initiator = _AmbientGateInitiator
    If !initiator
        _FinishAmbientGate()
        Return
    EndIf

    _AmbientGatePollCount += 1
    Int verdict = SeverActionsNativeExt2.Native_AmbientAction_PollGate(initiator)

    If verdict == 1
        DispatchAmbientAction(initiator, _AmbientGateAction, _AmbientGateDest, _AmbientGateTarget, \
            _AmbientGateItem, _AmbientGateQty, _AmbientGateGold, _AmbientGateWait)
        Debug.Trace("[SeverActions_Ambient][Action] gate GO: " + initiator.GetDisplayName() + " " + _AmbientGateAction)
        _FinishAmbientGate()
    ElseIf verdict == 2
        Debug.Trace("[SeverActions_Ambient][Action] gate BLOCKED (addressee refused): " + initiator.GetDisplayName())
        _FinishAmbientGate()
    ElseIf verdict == 3
        Debug.Trace("[SeverActions_Ambient][Action] gate deferred/aborted: " + initiator.GetDisplayName())
        _FinishAmbientGate()
    Else
        ; Pending. Ceiling in case the gate never resolves: 75 polls (~150 s) cover the
        ; native 90 s cap plus the adjudicator's own LLM call.
        If _AmbientGatePollCount >= 75
            SeverActionsNativeExt2.Native_AmbientAction_AbortGate(initiator)
            Debug.Trace("[SeverActions_Ambient][Action] gate poll ceiling hit - aborted")
            _FinishAmbientGate()
        EndIf
    EndIf
EndFunction

Function _FinishAmbientGate()
    {The social gate's single exit. ClearReady resets a resolved native gate; the DLL has
     already cleared the busy lock on every verdict.}
    SeverActionsNativeExt2.Native_AmbientAction_ClearReady()
    AmbientGatePolling      = false
    _AmbientGateInitiator   = None
    _AmbientGateAction      = ""
    _AmbientGateDest        = ""
    _AmbientGateTarget      = None
    _AmbientGateItem        = ""
    _AmbientGateQty         = 1
    _AmbientGateGold        = 0
    _AmbientGateWait        = false
    _AmbientGatePollCount   = 0
    SeverActionsNativeExt2.LLMLane_Release("social.ambientAction")
EndFunction

Function DispatchAmbientAction(Actor akActor, String actionName, String destination, Actor akTarget, \
        String itemName, Int aiQty, Int aiGold, Bool waitForPlayer)
    {The ambient action whitelist, the one place Papyrus enforces it. The DLL already
     validated the params, clamped quantity (1..10) and gold (0..500) and refused an action
     whose module is absent; each case re-checks its preconditions cheaply. Each action goes
     out as its owning module's verb (the Actions page's event), and the module per action
     must match AmbientActionScanner's check. No action uses destination (travel is not on
     the whitelist).}
    If !akActor || akActor.IsDead()
        Return
    EndIf

    If actionName == "ChallengeBrawl"
        If akTarget && akTarget != akActor && !akTarget.IsDead()
            SeverActionsNativeExt2.Verb_Send("combat", "challengeBrawl", _VerbTail(akTarget, "", 0, ""), akActor)
        EndIf

    ElseIf actionName == "GiveItem"
        If akTarget && itemName != ""
            SeverActionsNativeExt2.Verb_Send("items", "giveItem", _VerbTail(akTarget, itemName, aiQty, ""), akActor)
        EndIf

    ElseIf actionName == "GiveGold"
        If akTarget && aiGold > 0
            SeverActionsNativeExt2.Verb_Send("economy", "giveGold", _VerbTail(akTarget, "", aiGold, ""), akActor)
        EndIf

    ElseIf actionName == "BuyItem"
        If akTarget && itemName != "" && aiGold > 0
            SeverActionsNativeExt2.Verb_Send("economy", "buyItem", _VerbTail(akTarget, itemName, aiQty, "" + aiGold), akActor)
        EndIf

    ElseIf actionName == "SellItem"
        If akTarget && akTarget != akActor && itemName != "" && aiGold > 0
            SeverActionsNativeExt2.Verb_Send("economy", "sellItem", _VerbTail(akTarget, itemName, aiQty, "" + aiGold), akActor)
        EndIf

    ElseIf actionName == "TakeItem"
        If akTarget && akTarget != akActor && itemName != ""
            SeverActionsNativeExt2.Verb_Send("items", "takeItem", _VerbTail(akTarget, itemName, aiQty, ""), akActor)
        EndIf

    ElseIf actionName == "UseItem"
        If itemName != ""
            SeverActionsNativeExt2.Verb_Send("items", "useItem", _VerbTail(None, itemName, 0, ""), akActor)
        EndIf

    ElseIf actionName == "CookMeal" || actionName == "BrewPotion" || actionName == "CraftItem"
        If akTarget && itemName != ""
            String craftVerb = "craftItem"
            If actionName == "CookMeal"
                craftVerb = "cookMeal"
            ElseIf actionName == "BrewPotion"
                craftVerb = "brewPotion"
            EndIf
            SeverActionsNativeExt2.Verb_Send("economy", craftVerb, _VerbTail(akTarget, itemName, aiQty, ""), akActor)
        EndIf
    EndIf
EndFunction

String Function _VerbTail(Actor akTarget2, String asStr, Int aiInt, String asStr2)
    {Verb_Send's args, the tail after the actionId: target|target2|str|int|str2|targetFid|target2Fid.
     The initiator rides as the sender (the dispatcher's VerbActor resolves it first), so target
     stays empty; the counterpart is target2, by name and FormID so the resolve is exact.}
    String t2Name = ""
    Int t2Fid = 0
    If akTarget2
        t2Name = akTarget2.GetDisplayName()
        t2Fid = akTarget2.GetFormID()
    EndIf
    Return "|" + t2Name + "|" + asStr + "|" + aiInt + "|" + asStr2 + "|0|" + t2Fid
EndFunction

Event OnInit()
    ; No setup here (DR20).
    Debug.Trace("[SeverActions] SeverActions_Ambient: bound")
EndEvent
