Scriptname SeverActions_Courier extends Quest
{The couriers bundle's letter courier (plan 5.1 S02): letters queue on this quest form's
 StorageUtil keys (the form Travel used, so a save's queue carries over) and one courier at a
 time, spawned by the native CourierManager, hands over the whole queue. Travel keeps an
 M-I-STUB safe exit for each function moved here (F7). No OnInit setup (DR20): the couriers
 provider's stage 1 calls Maintenance. Answers the shared SeverActions_TravelComplete on the
 "courier" tag only (M-E); its tick arms only while there is work, so Init K4 does not watch it.
 Calls SeverActions_TravelCore statically, legal because travelcore is in this bundle's
 requires closure (DR2).}

; Records by FormID (SeverActions.esp; the VR rule)
Int Property FID_TRAVEL_TARGET_KW = 0x076F5F AutoReadOnly   ; SeverTravelKeyword (Travel.TravelTargetKeyword's fill)
Int Property FID_SANDBOX_PKG      = 0x0BDDFF AutoReadOnly   ; SeverActions_LeisureSandbox (the loiter fallback)

; Constants: SeverActions_Travel's runtime values (DR18)
Int Property SPEED_JOG = 1 AutoReadOnly
Int Property TRAVEL_PACKAGE_PRIORITY = 85 AutoReadOnly
{Priority of the pool-exhaustion fallback override (Travel.TravelPackagePriority's VMAD fill).}
Int Property TRAVEL_OPTIONS_DEFAULT = 4 AutoReadOnly
{4 = kTravelOpt_AbortOnDegraded.}
Float Property TICK_INTERVAL = 3.0 AutoReadOnly
{The queue-poll cadence in seconds (Travel.UpdateInterval).}
String Property JOURNEY_TAG = "courier" AutoReadOnly
{The callbackTag of a courier's journey; this script's OnTravelComplete answers it.}
Float Property CourierMinIntervalDays = 7.0 AutoReadOnly
{Minimum game days between courier dispatches (urgent letters excepted).}

; Built on first use by CourierBlockedWorldspace, then kept in the save.
Form[] CourierWsBlacklist
Bool CourierWsBlacklistBuilt = false

; Single-courier rule: at most one courier at a time and one per
; CourierMinIntervalDays. Every letter queues; the courier hands over the first
; with ceremony and the rest of the queue with it. Urgent (ransom) letters bypass
; the cooldown, never the one-at-a-time rule.

Event OnInit()
    ; No setup here (DR20): a script re-added to a save that once held it gets no OnInit (F35).
    Debug.Trace("[SeverActions] SeverActions_Courier: bound")
EndEvent

Function Maintenance()
    {Load recovery from the couriers provider's stage 1 (idempotent, DR20): re-registers the
     listeners and re-arms the poll while letters wait or a courier is out (ticks do not survive a load).}
    _RegisterEvents()
    If StorageUtil.StringListCount(self, "SeverTravel_CourierQ_Body") > 0 || ActiveCourierLive()
        ChronoArm(TICK_INTERVAL)
    EndIf
EndFunction

Function _RegisterEvents()
    {Idempotent: a retainer's letter, the orchestrator's completion (canonical callback), the tick.}
    RegisterForModEvent("SeverActions_VentureLetter", "OnVentureLetter")
    RegisterForModEvent("SeverActions_TravelComplete", "OnTravelComplete")
    RegisterForModEvent("SeverActions_Tick_Courier", "OnChronoTick_Courier")
EndFunction

Keyword Function _TravelKW()
    Return Game.GetFormFromFile(FID_TRAVEL_TARGET_KW, "SeverActions.esp") as Keyword
EndFunction

Function DebugMsg(String msg)
    Debug.Trace("[SeverActions_Courier] " + msg)
EndFunction

; The tick

Function ChronoArm(Float afSeconds)
    {Arm this script's one-shot tick (event and callback names unique per script); a re-arm
     replaces the pending tick.}
    RegisterForModEvent("SeverActions_Tick_Courier", "OnChronoTick_Courier")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_Courier", afSeconds)
EndFunction

Event OnChronoTick_Courier(String eventName, String strArg, Float numArg, Form sender)
    ; Poll while anything waits; otherwise end the loop with a Cancel (a fired tick is
    ; acknowledged only by a re-Request or a Cancel).
    If ProcessCourierQueue()
        ChronoArm(TICK_INTERVAL)
    Else
        SeverActionsNativeExt2.Chrono_Cancel("SeverActions_Tick_Courier")
    EndIf
EndEvent

; The orchestrator's completion (canonical callback, M-E)

Event OnTravelComplete(string eventName, string strArg, float numArg, Form sender)
    {strArg = "<callbackTag>|<status>"; answers the courier tag only. Any status but
     "cancelled" delivers; cancelled releases the courier and loses its letter.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    If StringUtil.Substring(strArg, 0, pipePos) != JOURNEY_TAG
        Return
    EndIf
    String status = StringUtil.Substring(strArg, pipePos + 1, 0)
    Actor courierNpc = sender as Actor
    If courierNpc != None
        If status != "cancelled"
            DeliverCourierLetter(courierNpc)
        Else
            SeverActionsNativeExt.Courier_Release(courierNpc)
        EndIf
    EndIf
EndEvent

; The courier

Function _ClearCourierHolds(Actor akCourier)
    {What a delivery leaves on the courier: the loiter sandbox, a pool-full jog override and
     SkyrimNet's talk package.}
    Package loiter = Game.GetFormFromFile(0x165673, "SeverActions.esp") as Package
    If loiter
        ActorUtil.RemovePackageOverride(akCourier, loiter)
    EndIf
    Package sandbox = Game.GetFormFromFile(FID_SANDBOX_PKG, "SeverActions.esp") as Package
    If sandbox
        ActorUtil.RemovePackageOverride(akCourier, sandbox)
    EndIf
    SeverActions_TravelCore.StripTravelOverrides(akCourier)
    SkyrimNetApi.UnregisterPackage(akCourier, "TalkToPlayer")
EndFunction

Event OnVentureLetter(string eventName, string strArg, float numArg, Form sender)
    {A retainer (sender) has a letter from this week's settlement: take it from the native
     store and queue it for a courier.}
    Actor retainer = sender as Actor
    Debug.Trace("[SeverActions_Courier] OnVentureLetter fired, sender=" + retainer)
    If retainer == None
        Return
    EndIf
    String subj   = SeverActionsNativeExt2.Venture_LetterSubject(retainer)
    String body   = SeverActionsNativeExt2.Venture_LetterBody(retainer)
    String reason = SeverActionsNativeExt2.Venture_LetterReason(retainer)
    SeverActionsNativeExt2.Venture_ClearLetter(retainer)
    If body != ""
        DispatchCourier(retainer, subj, body, reason)
    EndIf
EndEvent

Int Function DispatchCourier(Actor akSender, String asSubject, String asBody, String asReason)
    {Queue a letter for courier delivery; TryDispatchQueuedCourier decides when a courier
     goes. Returns 1 when queued, 0 on bad args.}
    _RegisterEvents()
    Actor player = Game.GetPlayer()
    If player == None || asBody == ""
        Return 0
    EndIf
    QueueCourierLetter(akSender, asSubject, asBody, asReason)
    ChronoArm(TICK_INTERVAL)  ; keep the queue poll alive
    TryDispatchQueuedCourier()
    Return 1
EndFunction

Bool Function ActiveCourierLive()
    {Is a dispatched courier still on the job? Frees the lock when the courier is dead,
     deleted or parked (CourierManager disables the reused courier), or unloaded more than
     6 game hours after dispatch.}
    Actor c = StorageUtil.GetFormValue(self, "SeverTravel_ActiveCourier") as Actor
    If c == None
        Return false
    EndIf
    Bool stale = (!c.Is3DLoaded()) && \
        (Utility.GetCurrentGameTime() - StorageUtil.GetFloatValue(self, "SeverTravel_ActiveCourierGT", 0.0)) > 0.25
    If c.IsDead() || c.IsDeleted() || c.IsDisabled() || stale
        StorageUtil.UnsetFormValue(self, "SeverTravel_ActiveCourier")
        Return false
    EndIf
    Return true
EndFunction

Bool Function QueueHasUrgent()
    Int i = 0
    Int n = StorageUtil.StringListCount(self, "SeverTravel_CourierQ_Reason")
    While i < n
        If StorageUtil.StringListGet(self, "SeverTravel_CourierQ_Reason", i) == "ransom"
            Return true
        EndIf
        i += 1
    EndWhile
    Return false
EndFunction

Bool Function TryDispatchQueuedCourier()
    {The gate for every courier spawn (outdoors, no live courier, cooldown). Moves the first
     queued letter onto the courier; the rest stay queued and go with it at delivery, so a
     lost courier costs at most one letter. Returns true when a courier was dispatched.}
    If StorageUtil.StringListCount(self, "SeverTravel_CourierQ_Body") == 0
        Return false
    EndIf
    Actor player = Game.GetPlayer()
    If player == None || player.IsInInterior() || CourierBlockedWorldspace(player)
        Return false
    EndIf
    If ActiveCourierLive()
        Return false   ; their arrival hands over the whole queue anyway
    EndIf
    Float nowGT = Utility.GetCurrentGameTime()
    If nowGT - StorageUtil.GetFloatValue(self, "SeverTravel_LastCourierGT", -100.0) < CourierMinIntervalDays && !QueueHasUrgent()
        Return false   ; cooldown (urgent letters bypass it)
    EndIf

    ; Read letter 0; pop it only after a successful spawn.
    Actor akSender = Game.GetFormEx(StorageUtil.StringListGet(self, "SeverTravel_CourierQ_SenderFid", 0) as Int) as Actor
    String asSubject = StorageUtil.StringListGet(self, "SeverTravel_CourierQ_Subject", 0)
    String asBody    = StorageUtil.StringListGet(self, "SeverTravel_CourierQ_Body", 0)
    String asReason  = StorageUtil.StringListGet(self, "SeverTravel_CourierQ_Reason", 0)
    String senderNm  = StorageUtil.StringListGet(self, "SeverTravel_CourierQ_SenderName", 0)
    If senderNm == "" && akSender != None
        senderNm = akSender.GetDisplayName()
    EndIf

    ; Spawn well out so the courier travels in rather than appearing beside the player.
    Float spawnDist = 3000.0
    Actor courier = SeverActionsNativeExt.Courier_Spawn(player, spawnDist)
    If courier == None
        DebugMsg("TryDispatchQueuedCourier: spawn failed - letters stay queued")
        Return false
    EndIf
    ; The courier is one reused actor (CourierManager), so the last delivery's holds are
    ; still on him: the loiter sandbox (100) would outrank a pool-full jog override (85)
    ; and hold him after the journey.
    _ClearCourierHolds(courier)
    StorageUtil.StringListRemoveAt(self, "SeverTravel_CourierQ_SenderFid", 0)
    StorageUtil.StringListRemoveAt(self, "SeverTravel_CourierQ_Subject", 0)
    StorageUtil.StringListRemoveAt(self, "SeverTravel_CourierQ_Body", 0)
    StorageUtil.StringListRemoveAt(self, "SeverTravel_CourierQ_Reason", 0)
    StorageUtil.StringListRemoveAt(self, "SeverTravel_CourierQ_SenderName", 0)
    StorageUtil.SetFormValue(self, "SeverTravel_ActiveCourier", courier)
    StorageUtil.SetFloatValue(self, "SeverTravel_ActiveCourierGT", nowGT)
    StorageUtil.SetFloatValue(self, "SeverTravel_LastCourierGT", nowGT)

    ; Stash the letter on the courier until it reaches the player, with the sender's
    ; name snapshot (see QueueCourierLetter).
    StorageUtil.SetFormValue(courier, "SA_CourierSender", akSender)
    StorageUtil.SetStringValue(courier, "SA_CourierSenderName", senderNm)
    StorageUtil.SetStringValue(courier, "SA_CourierSubject", asSubject)
    StorageUtil.SetStringValue(courier, "SA_CourierBody", asBody)
    StorageUtil.SetStringValue(courier, "SA_CourierReason", asReason)

    ; Jog in through the orchestrator: OnTravelComplete fires in arrival range and
    ; DeliverCourierLetter does the final approach. 300s cap; a timeout or abort still
    ; delivers, only a cancel loses the letter.
    Package travelPkg = SeverActionsNativeExt.Travel_GetSpeedPackage(SPEED_JOG)
    Int cHandle = SeverActionsNativeExt.Travel_Begin(courier, player, _TravelKW(), 400.0, JOURNEY_TAG, TRAVEL_OPTIONS_DEFAULT, 300, SPEED_JOG)
    ; The Traveler_NN pool alias (a clone of travelPkg, priority 106) drives the jog; the
    ; override applies only when the pool is exhausted or Begin failed, so no two compete.
    If travelPkg != None && (cHandle <= 0 || !SeverActionsNativeExt2.Travel_HasAlias(cHandle))
        ActorUtil.AddPackageOverride(courier, travelPkg, TRAVEL_PACKAGE_PRIORITY, 1)
        courier.EvaluatePackage()
    EndIf
    ; Register with OrphanCleanup: the jog spans several of its 5s scans (when
    ; orphanCleanupEnabled is on), which would strip the travel anchor mid-journey.
    ; Stays registered until the native despawn (see DeliverCourierLetter).
    SeverActionsNative.OrphanCleanup_RegisterTraveler(courier)
    DebugMsg("TryDispatchQueuedCourier: courier en route from afar (" \
        + StorageUtil.StringListCount(self, "SeverTravel_CourierQ_Body") + " more letter(s) ride the same delivery)")
    Return true
EndFunction

Bool Function CourierBlockedWorldspace(Actor akPlayer)
    {True in an exterior worldspace a courier could never reach: underground zones, other
     planes and roadless hidden areas (listed below; IsInInterior covers real interiors).
     By FormID, never EditorID (VR); an absent DLC's entries are None.}
    WorldSpace ws = akPlayer.GetWorldSpace()
    If !ws
        Return false
    EndIf
    If !CourierWsBlacklistBuilt
        Form[] bl = new Form[11]
        bl[0]  = Game.GetFormFromFile(0x01EE62, "Skyrim.esm")      ; Blackreach
        bl[1]  = Game.GetFormFromFile(0x02EE41, "Skyrim.esm")      ; Sovngarde
        bl[2]  = Game.GetFormFromFile(0x0278DD, "Skyrim.esm")      ; SkuldafnWorld
        bl[3]  = Game.GetFormFromFile(0x001408, "Dawnguard.esm")   ; DLC01SoulCairn
        bl[4]  = Game.GetFormFromFile(0x000BB5, "Dawnguard.esm")   ; DLC01FalmerValley (Forgotten Vale)
        bl[5]  = Game.GetFormFromFile(0x004BEA, "Dawnguard.esm")   ; DLC1DarkfallPassageWorld
        bl[6]  = Game.GetFormFromFile(0x002F64, "Dawnguard.esm")   ; DLC1ForebearsHoldout
        bl[7]  = Game.GetFormFromFile(0x0048C7, "Dawnguard.esm")   ; DLC1AncestorsGladeWorld
        bl[8]  = Game.GetFormFromFile(0x00528D, "Dawnguard.esm")   ; DLC01Boneyard
        bl[9]  = Game.GetFormFromFile(0x007202, "Dawnguard.esm")   ; DLC1VampireCastleCourtyard
        bl[10] = Game.GetFormFromFile(0x01C0B2, "Dragonborn.esm")  ; DLC2ApocryphaWorld
        CourierWsBlacklist = bl
        CourierWsBlacklistBuilt = true
    EndIf
    Return CourierWsBlacklist.Find(ws as Form) >= 0
EndFunction

Function QueueCourierLetter(Actor akSender, String asSubject, String asBody, String asReason)
    {Append to the FIFO of letters waiting for the player to step outside: parallel StorageUtil
     string lists on self. The sender rides as a FormID string (a None in a FormList would
     desync the lists) and its name is snapshotted now, since the sender can be gone by
     delivery and the letter view needs its from-line.}
    Int senderFid = 0
    If akSender
        senderFid = akSender.GetFormID()
    EndIf
    StorageUtil.StringListAdd(self, "SeverTravel_CourierQ_SenderFid", senderFid as String)
    StorageUtil.StringListAdd(self, "SeverTravel_CourierQ_Subject", asSubject)
    StorageUtil.StringListAdd(self, "SeverTravel_CourierQ_Body", asBody)
    StorageUtil.StringListAdd(self, "SeverTravel_CourierQ_Reason", asReason)
    String qSenderNm = ""
    If akSender
        qSenderNm = akSender.GetDisplayName()
    EndIf
    StorageUtil.StringListAdd(self, "SeverTravel_CourierQ_SenderName", qSenderNm)
EndFunction

Bool Function ProcessCourierQueue()
    {The tick's poll: try to dispatch. Returns whether the loop must stay alive (letters
     queued, or a courier en route whose staleness needs polling).}
    TryDispatchQueuedCourier()
    Return StorageUtil.StringListCount(self, "SeverTravel_CourierQ_Body") > 0 || ActiveCourierLive()
EndFunction

Function DeliverCourierLetter(Actor akCourier)
    {Narrate and hand over the stashed letter and the rest of the queue, free the lock, then
     leave the courier to loiter and despawn.}
    If akCourier == None
        Return
    EndIf
    Actor player = Game.GetPlayer()
    Actor sender = StorageUtil.GetFormValue(akCourier, "SA_CourierSender") as Actor
    String subj = StorageUtil.GetStringValue(akCourier, "SA_CourierSubject")
    String body = StorageUtil.GetStringValue(akCourier, "SA_CourierBody")
    String reason = StorageUtil.GetStringValue(akCourier, "SA_CourierReason")
    ; The sender's name as queued: the sender ref can be gone by now (an applicant out of memory).
    String senderSnap = StorageUtil.GetStringValue(akCourier, "SA_CourierSenderName")

    ; Into the courier's pack, so they can hand it over with the give animation.
    Form note = None
    If body != ""
        note = SeverActionsNativeExt.Letter_DeliverToCourier(sender, akCourier, subj, body, reason, senderSnap)
    EndIf

    ; End the travel package and force SkyrimNet's TalkToPlayer package (as SkyrimNet does
    ; for live dialogue): the courier closes the last gap and holds to speak instead of
    ; stopping short.
    ; Do NOT unregister the traveler: the loiter below re-anchors on the same _TravelKW()
    ; LinkedRef, and with orphanCleanupEnabled on, OrphanCleanup's scan strips an unregistered
    ; holder of it (the courier freezes until despawn). CourierManager deregisters at despawn.
    SeverActions_TravelCore.StripTravelOverrides(akCourier)
    If player != None
        SkyrimNetApi.RegisterPackage(akCourier, "TalkToPlayer", 100, 0, false)
        akCourier.EvaluatePackage()
    EndIf

    ; SkyrimNet turns this narration into the courier's line.
    If player != None
        String senderName = senderSnap
        If sender != None
            senderName = sender.GetDisplayName()
        EndIf
        ; Ransom letters are keyed by the CAPTIVE, so the sender is the victim: the answer comes
        ; from their hold's court, or their people, never "from" the victim.
        If reason == "ransom" && sender != None
            String ransomHold = SeverActionsNativeExt.Hold_GetHoldName(sender)
            If ransomHold != ""
                senderName = "the court of " + ransomHold + ", concerning " + sender.GetDisplayName()
            Else
                senderName = sender.GetDisplayName() + "'s people"
            EndIf
        ElseIf reason == "ransom" && senderName != ""
            senderName = senderName + "'s people"
        EndIf
        ; The courier carries the whole queue; say so.
        Int pendingExtra = StorageUtil.StringListCount(self, "SeverTravel_CourierQ_Body")
        String letterWord = "a sealed letter"
        If pendingExtra > 0
            letterWord = "a small bundle of letters, the topmost"
        EndIf
        String narration = "*A courier catches up to " + player.GetDisplayName() + ", a little out of breath, and holds out " + letterWord
        If senderName != ""
            narration += " from " + senderName
        EndIf
        narration += ". They explain they were paid to put it into " + player.GetDisplayName() + "'s own hands, and urge them to read it before long.*"
        SkyrimNetApi.DirectNarration(narration, akCourier, player)
    EndIf

    ; Give the courier a moment to close in and turn, then hand the note over by FORM
    ; (it is runtime-retitled, so a name lookup would miss it).
    Utility.Wait(2.5)
    If note != None && player != None
        ; The items provider's giveItemForm (give animation + SkyrimNet event) takes the FormID
        ; as signed-decimal text; false without the items module, so hand it over directly.
        ; No items type is named here (N2).
        If !SeverActions_ModuleBase.CallBool("items", "giveItemForm", akCourier, player, "" + (note.GetFormID() as Int), 1.0)
            akCourier.RemoveItem(note, 1, false, player)
        EndIf
    EndIf

    ; Hand over the rest of the queue silently, each as a real note.
    Int extraDelivered = 0
    While StorageUtil.StringListCount(self, "SeverTravel_CourierQ_Body") > 0
        Actor qSnd = Game.GetFormEx(StorageUtil.StringListGet(self, "SeverTravel_CourierQ_SenderFid", 0) as Int) as Actor
        String qSubj   = StorageUtil.StringListGet(self, "SeverTravel_CourierQ_Subject", 0)
        String qBody   = StorageUtil.StringListGet(self, "SeverTravel_CourierQ_Body", 0)
        String qReason = StorageUtil.StringListGet(self, "SeverTravel_CourierQ_Reason", 0)
        String qName   = StorageUtil.StringListGet(self, "SeverTravel_CourierQ_SenderName", 0)
        StorageUtil.StringListRemoveAt(self, "SeverTravel_CourierQ_SenderFid", 0)
        StorageUtil.StringListRemoveAt(self, "SeverTravel_CourierQ_Subject", 0)
        StorageUtil.StringListRemoveAt(self, "SeverTravel_CourierQ_Body", 0)
        StorageUtil.StringListRemoveAt(self, "SeverTravel_CourierQ_Reason", 0)
        StorageUtil.StringListRemoveAt(self, "SeverTravel_CourierQ_SenderName", 0)
        If qBody != ""
            If qName == "" && qSnd != None
                qName = qSnd.GetDisplayName()
            EndIf
            Form qNote = SeverActionsNativeExt.Letter_DeliverToCourier(qSnd, akCourier, qSubj, qBody, qReason, qName)
            If qNote != None && player != None
                akCourier.RemoveItem(qNote, 1, true, player)
                extraDelivered += 1
            EndIf
        EndIf
    EndWhile

    ; Free the single-courier lock.
    StorageUtil.UnsetFormValue(self, "SeverTravel_ActiveCourier")

    If extraDelivered > 0
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("travel.courierHandsYouLetters", ("" + (extraDelivered + 1))))
    Else
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("travel.courierHandsYouLetter"))
    EndIf

    ; Loiter around the player: CourierLoiter sandboxes around the _TravelKW() linked ref,
    ; so pointing it at the player keeps the courier near them. Link and add the sandbox
    ; BEFORE dropping the talk package so there is no default-AI gap.
    If player != None
        SeverActionsNative.LinkedRef_Set(akCourier, player, _TravelKW())
    EndIf
    Package courierLoiterPkg = Game.GetFormFromFile(0x165673, "SeverActions.esp") as Package
    Package fallbackSandbox = Game.GetFormFromFile(FID_SANDBOX_PKG, "SeverActions.esp") as Package
    If courierLoiterPkg != None
        ActorUtil.AddPackageOverride(akCourier, courierLoiterPkg, 100, 1)
    ElseIf fallbackSandbox != None
        ActorUtil.AddPackageOverride(akCourier, fallbackSandbox, TRAVEL_PACKAGE_PRIORITY, 1)
    EndIf
    If player != None
        SkyrimNetApi.UnregisterPackage(akCourier, "TalkToPlayer")
    EndIf
    akCourier.EvaluatePackage()

    ; Clear the stash: the same courier carries the next letter.
    StorageUtil.UnsetFormValue(akCourier, "SA_CourierSender")
    StorageUtil.UnsetStringValue(akCourier, "SA_CourierSenderName")
    StorageUtil.UnsetStringValue(akCourier, "SA_CourierSubject")
    StorageUtil.UnsetStringValue(akCourier, "SA_CourierBody")
    StorageUtil.UnsetStringValue(akCourier, "SA_CourierReason")

    ; CourierManager's linger: despawn once 2 game hours have passed and the player has left
    ; the cell, or at 8 hours regardless.
    SeverActionsNativeExt.Courier_Release(akCourier)
EndFunction
