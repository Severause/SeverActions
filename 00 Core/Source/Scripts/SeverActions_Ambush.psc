Scriptname SeverActions_Ambush extends Quest
{The thug ambush standoff (couriers bundle): a retainer grudge's hired thugs, or a kidnap
 search party (sender = the victim), spawn off-screen, jog in and hold a neutral,
 weapons-out standoff with a persuasion window. It ends with ThugStandDown (they walk off
 and despawn) or a fight (ThugAttack, a failed persuasion, any thug entering combat). Moved
 from SeverActions_Travel (P9-01), which keeps M-I-STUB safe exits and tears down a standoff
 a pre-P9 save left on its own variables (R23). No OnInit setup (DR20): the couriers
 provider's stage 1 runs Maintenance. SeverActions_PersuasionFailed is shared with
 SeverActions_ArrestPlayer on the canonical callback; each gates on its own state. The
 departing-thug list keeps Travel's StorageUtil keys on the same quest form, so a pre-P9
 save's list carries over. The tick arms only while there is work, so Init K4 does not
 watch it.}

; Records resolve by FormID (DR2): the script is attached with no VMAD properties.
Int Property FID_TRAVEL_TARGET_KW = 0x076F5F AutoReadOnly   ; SeverTravelKeyword (Travel.TravelTargetKeyword's fill)

; Copies of SeverActions_Travel's runtime values (DR18)
Int Property SPEED_JOG = 1 AutoReadOnly
Int Property TRAVEL_PACKAGE_PRIORITY = 85 AutoReadOnly
{SeverActions_Travel.TravelPackagePriority's VMAD fill (85): the approach jog and walk-off overrides.}
Float Property TICK_INTERVAL = 3.0 AutoReadOnly
{SeverActions_Travel.UpdateInterval: the departing-thug despawn cadence (seconds).}

; Standoff state: one ambush at a time (the native enforces a cooldown).
Actor[] AmbushThugs
Actor AmbushLead
Actor AmbushDeserter
Bool AmbushActive = False
Bool AmbushApproaching = False
ObjectReference AmbushAwayMarker   ; the walk-off waypoint, deleted on the next stand-down
Float AmbushApproachStart = 0.0   ; real-time the approach began (poll timeout anchor)
; Held until the standoff opens, then given to the lead, so the speaker carries it.
String AmbushLetterSubj = ""
String AmbushLetterBody = ""
; A hostile ex-retainer leading the ambush: a real NPC, never despawned, whose own
; Aggression and Confidence are put back on every exit (ReleaseAmbushLeader). While
; LeaderFighting the tick waits for their fight to end to put them back.
Actor AmbushLeader
Float LeaderOrigAggression = 0.0
Float LeaderOrigConfidence = 0.0
Bool LeaderFighting = False

Event OnInit()
    ; No setup here (DR20): a script re-added to a save that once held it gets no OnInit (F35).
    Debug.Trace("[SeverActions] SeverActions_Ambush: bound")
EndEvent

Function Maintenance()
    {Load recovery (couriers provider stage 1, every load and new game; idempotent):
     registers the listeners, tears down a standoff saved mid-flight and re-arms the
     despawn poll, or a fighting leader's release poll.}
    _RegisterEvents()
    _AbandonStandoffOnLoad()
    If StorageUtil.FormListCount(self, "SeverTravel_DepartingThugs") > 0 || LeaderFighting
        ChronoArm(TICK_INTERVAL)
    EndIf
EndFunction

Function _RegisterEvents()
    {Idempotent.}
    RegisterForModEvent("SeverActions_VentureAmbush", "OnVentureAmbush")
    RegisterForModEvent("SeverActions_PersuasionFailed", "OnPersuasionFailedEvent")
    RegisterForModEvent("SeverActions_VentureThugCombat", "OnVentureThugCombat")
    RegisterForModEvent("SeverActions_Tick_Ambush", "OnChronoTick_Ambush")
EndFunction

Function _AbandonStandoffOnLoad()
    {The native thug roster (VentureMonitor m_ambushThugs) is cleared on every load, so a
     standoff saved mid-flight can never resolve: strip packages, undo the faction swap
     and despawn the thugs. R23: no global thug clear; only the lead's persuasion window ends.}
    If !AmbushActive && !AmbushApproaching
        Return
    EndIf
    SeverActionsNativeExt2.Native_Persuasion_EndFor(AmbushLead)
    Faction bladeFaction = GetHiredBladeFaction()
    If AmbushThugs   ; not `!= None`: comparing an array with None casts None at runtime
        Int i = 0
        While i < AmbushThugs.Length
            Actor t = AmbushThugs[i]
            If t != None
                StripThugPackages(t)
                If bladeFaction != None
                    t.RemoveFromFaction(bladeFaction)
                EndIf
                ; A real NPC (the leader, or any venture record on an older save) is let go, not despawned.
                If t == AmbushLeader || SeverActionsNativeExt2.Venture_IsRetainer(t)
                    ReleaseAmbushLeader(t)
                Else
                    t.Disable()
                    t.Delete()
                EndIf
            EndIf
            i += 1
        EndWhile
    EndIf
    AmbushActive = False
    AmbushApproaching = False
    AmbushLead = None
    AmbushDeserter = None
    AmbushLetterSubj = ""
    AmbushLetterBody = ""
    Debug.Trace("[SeverActions_Ambush] abandoned a standoff that was live across a save/reload")
EndFunction

Keyword Function _TravelKW()
    Return Game.GetFormFromFile(FID_TRAVEL_TARGET_KW, "SeverActions.esp") as Keyword
EndFunction

; The tick

Function ChronoArm(Float afSeconds)
    {Arms this script's one-shot tick (event and callback names unique per script). A
     re-arm replaces the pending tick; ticks do not survive a load.}
    RegisterForModEvent("SeverActions_Tick_Ambush", "OnChronoTick_Ambush")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_Ambush", afSeconds)
EndFunction

Event OnChronoTick_Ambush(String eventName, String strArg, Float numArg, Form sender)
    If AmbushApproaching
        CheckAmbushApproach()
    EndIf
    ; The AI re-sheathes a thug that perceives no threat; re-assert the stance each tick.
    If AmbushActive
        ReassertThugStance()
    EndIf
    ProcessDepartingThugs()
    If LeaderFighting && (AmbushLeader == None || AmbushLeader.IsDead() || !AmbushLeader.IsInCombat())
        ReleaseAmbushLeader(AmbushLeader)
    EndIf
    Bool hasDeparting = StorageUtil.FormListCount(self, "SeverTravel_DepartingThugs") > 0 || LeaderFighting
    ; 1 s approaching, 2 s holding the standoff, else the despawn cadence. With nothing
    ; left, Cancel: a fired tick is acknowledged only by a re-Request or a Cancel.
    If AmbushApproaching
        ChronoArm(1.0)
    ElseIf AmbushActive
        ChronoArm(2.0)
    ElseIf hasDeparting
        ChronoArm(TICK_INTERVAL)   ; the despawn poll, or a fighting leader's
    Else
        SeverActionsNativeExt2.Chrono_Cancel("SeverActions_Tick_Ambush")
    EndIf
EndEvent

; The ambush

Event OnVentureAmbush(string eventName, string strArg, float numArg, Form sender)
    {sender = the deserter (a grudge) or the kidnap victim (a search party); numArg = the
     thug count; strArg = a hostile leader's signed-decimal FormID, or empty. Spawns the
     thugs (off-screen outdoors, close indoors), marches them in and opens the standoff.
     Fired by the native grudge scheduler, the kidnap search and the MCM debug button.}
    Actor player = Game.GetPlayer()
    If player == None
        Return
    EndIf
    ; Defensive: tear down a leftover standoff, and let an earlier leader go (their snapshot
    ; would otherwise be overwritten).
    If AmbushActive || AmbushApproaching
        ClearAmbushState()
    EndIf
    If AmbushLeader != None
        ReleaseAmbushLeader(AmbushLeader)
    EndIf

    Actor deserter = sender as Actor
    Int count = numArg as Int
    If count < 1
        count = 2
    ElseIf count > 5
        count = 5
    EndIf

    ; LCharBanditMeleeAny (Skyrim.esm); PlaceAtMe on a leveled character spawns a concrete actor.
    Form thugList = Game.GetForm(0x0003DECD)
    If !thugList
        Debug.Trace("[SeverActions_Ambush] OnVentureAmbush: thug leveled list missing")
        Return
    EndIf

    ; The letter the native queued for this sender, consumed here.
    String subj = ""
    String body = ""
    If deserter != None
        subj = SeverActionsNativeExt2.Venture_LetterSubject(deserter)
        body = SeverActionsNativeExt2.Venture_LetterBody(deserter)
        SeverActionsNativeExt2.Venture_ClearLetter(deserter)
    EndIf
    AmbushLetterSubj = subj
    AmbushLetterBody = body

    ; Outdoors spawn off-screen and travel in; indoors spawn close.
    Bool fromAfar = !player.IsInInterior()
    Float baseAng = Utility.RandomFloat(0.0, 360.0)

    ; Each spawn moves from BanditFaction into our neutral hired-blade faction: a Follow
    ; package will not run on an actor hostile to its target, and the player's follower
    ; would attack a bandit mid-parley. ResolveAmbushCombat swaps them back.
    Faction banditFaction = GetBanditFaction()
    Faction bladeFaction = GetHiredBladeFaction()

    ; A HOSTILE ex-retainer (strArg) leads their own ambush from slot 0, neutral-converted
    ; like the blades but released, never despawned (ReleaseAmbushLeader). Someone in custody
    ; (kidnapped, jailed) or at the player's side stays out of it: the blades come alone.
    Actor leader = None
    If strArg != ""
        Int leaderFid = strArg as Int
        If leaderFid != 0
            leader = Game.GetFormEx(leaderFid) as Actor
        EndIf
    EndIf
    If leader != None && (leader.IsPlayerTeammate() || SeverActionsNativeExt.Native_GetIsFollower(leader) \
        || SeverActionsNativeExt.Native_Kidnap_GetPhase(leader) >= 2 || SeverActionsNativeExt.Native_Jailed_IsJailed(leader))
        Debug.Trace("[SeverActions_Ambush] OnVentureAmbush: " + leader + " is in custody or with the player - blades only")
        leader = None
    EndIf

    AmbushThugs = new Actor[5]
    Int n = 0
    If leader != None && !leader.IsDead() && !leader.IsDisabled()
        AmbushLeader = leader
        LeaderOrigAggression = leader.GetBaseActorValue("Aggression")
        LeaderOrigConfidence = leader.GetBaseActorValue("Confidence")
        LeaderFighting = False
        leader.StopCombat()
        leader.SetActorValue("Aggression", 0)
        If bladeFaction != None
            leader.AddToFaction(bladeFaction)
        EndIf
        If fromAfar
            leader.MoveTo(player, 2800.0 * Math.Cos(baseAng), 2800.0 * Math.Sin(baseAng), 0.0)
        Else
            leader.MoveTo(player, 220.0, 0.0, 0.0)
        EndIf
        AmbushThugs[0] = leader
        n = 1
        Debug.Trace("[SeverActions_Ambush] OnVentureAmbush: hostile ex-retainer " + leader + " leads the ambush")
    EndIf
    Int i = 0
    While i < count && n < 5
        ObjectReference ref = player.PlaceAtMe(thugList, 1)
        Actor thug = ref as Actor
        If thug
            thug.StopCombat()
            thug.SetActorValue("Aggression", 0)  ; won't swing on their own; the standoff resolves them
            If banditFaction != None
                thug.RemoveFromFaction(banditFaction)
            EndIf
            If bladeFaction != None
                thug.AddToFaction(bladeFaction)
            EndIf
            If fromAfar
                ; Clustered in one direction so they read as a pack, not a ring.
                Float ang = baseAng + (n as Float) * 12.0
                Float dist = 2800.0 + (n as Float) * 160.0
                thug.MoveTo(player, dist * Math.Cos(ang), dist * Math.Sin(ang), 0.0)
            Else
                Float ang = (n as Float) * 90.0
                thug.MoveTo(player, 220.0 * Math.Cos(ang), 220.0 * Math.Sin(ang), 0.0)
            EndIf
            AmbushThugs[n] = thug
            n += 1
        EndIf
        i += 1
    EndWhile

    If n == 0
        Debug.Trace("[SeverActions_Ambush] OnVentureAmbush: no thugs spawned")
        Return
    EndIf

    AmbushLead = AmbushThugs[0]
    AmbushDeserter = deserter

    If fromAfar
        ; Jog in on the SA travel package (linked-ref target) without the orchestrator,
        ; whose arrival callback is unreliable for a placed actor chasing a moving
        ; player. The tick detects arrival; the standoff actions stay ineligible until then.
        AmbushApproaching = True
        AmbushApproachStart = Utility.GetCurrentRealTime()
        Package jog = SeverActionsNativeExt.Travel_GetSpeedPackage(SPEED_JOG)
        Int k = 0
        While k < AmbushThugs.Length
            Actor t = AmbushThugs[k]
            If t
                SeverActionsNative.LinkedRef_Set(t, player, _TravelKW())
                ; Registered: with orphanCleanupEnabled on, OrphanCleanup strips an unregistered
                ; travel LinkedRef mid-approach. Unregistered when the approach resolves.
                SeverActionsNative.OrphanCleanup_RegisterTraveler(t)
                If jog != None
                    ; A hostile leader's prio-110 work package would beat the jog (85),
                    ; so theirs goes in at 120. Removal is by package, so it strips clean.
                    Int prio = TRAVEL_PACKAGE_PRIORITY
                    If t == leader
                        prio = 120
                    EndIf
                    ActorUtil.AddPackageOverride(t, jog, prio, 1)
                EndIf
                t.EvaluatePackage()
            EndIf
            k += 1
        EndWhile
        ChronoArm(1.0)   ; poll for arrival
        Debug.Trace("[SeverActions_Ambush] OnVentureAmbush: " + n + " thugs closing in from off-screen (deserter " + deserter + ")")
    Else
        BeginAmbushStandoff()
    EndIf
EndEvent

Actor Function GetNearestThug(Actor player)
    {The live thug nearest the player, or None: detects arrival and picks the speaker.}
    Actor best = None
    Float bestDist = 0.0
    Int i = 0
    While i < AmbushThugs.Length
        Actor t = AmbushThugs[i]
        If t != None && !t.IsDead()
            Float d = t.GetDistance(player as ObjectReference)
            If best == None || d < bestDist
                best = t
                bestDist = d
            EndIf
        EndIf
        i += 1
    EndWhile
    Return best
EndFunction

Function CheckAmbushApproach()
    {Arrival poll: opens the standoff when the FIRST thug is within 700u (the spawn-order
     lead often lags), or after 12 s so a bad-navmesh spawn cannot strand it. The nearest
     thug becomes the lead, so the one the player sees first speaks.}
    If !AmbushApproaching
        Return
    EndIf
    Actor player = Game.GetPlayer()
    If player == None
        BeginAmbushStandoff()   ; degenerate — just open it where they are
        Return
    EndIf
    Actor nearest = GetNearestThug(player)
    Float elapsed = Utility.GetCurrentRealTime() - AmbushApproachStart
    Bool arrived = False
    If nearest != None
        Float dist = nearest.GetDistance(player as ObjectReference)
        ; Distance only, no same-cell test: near an exterior cell border an arrived
        ; thug can stand ~200u away in the adjacent cell.
        If dist <= 700.0
            arrived = True
        EndIf
    EndIf
    If arrived || elapsed >= 12.0
        If nearest != None
            AmbushLead = nearest
        EndIf
        BeginAmbushStandoff()
    EndIf
EndFunction

Function BeginAmbushStandoff()
    {Arrival: halt the approach, draw weapons (neutral, so they still hold their fire), make
     the standoff actions eligible, have the lead state their business and open the
     persuasion window.}
    If AmbushActive
        Return   ; guard against a double trigger
    EndIf
    Actor player = Game.GetPlayer()
    If player == None
        ClearAmbushState()
        Return
    EndIf
    AmbushApproaching = False
    AmbushActive = True
    ; A hired blade speaks and carries the letter (it names the leader as the one who paid);
    ; the leader leads only when no blade stands.
    If AmbushLead == None || AmbushLead == AmbushLeader
        Actor blade = _NearestBlade(player)
        If blade != None
            AmbushLead = blade
        EndIf
    EndIf
    Package jog = SeverActionsNativeExt.Travel_GetSpeedPackage(SPEED_JOG)
    Int i = 0
    While i < AmbushThugs.Length
        Actor t = AmbushThugs[i]
        If t && !t.IsDead()
            t.StopCombat()
            ; Aggression 1 is safe on a neutral actor (it only drives attacks on faction
            ; enemies) and holds the weapon-out stance; at 0 the AI re-sheathes.
            t.SetActorValue("Aggression", 1)
            ; Also forced here and re-asserted each tick (ReassertThugStance).
            t.DrawWeapon()
            t.SetAlert(true)
            ; Hold on the player with SkyrimNet's FollowPlayer (the SA follow action's
            ; mechanism): an ESP GuardFollowPlayer AddPackageOverride did not stick on
            ; these actors. Drop the approach jog and its linked ref first.
            If jog != None
                ActorUtil.RemovePackageOverride(t, jog)
            EndIf
            SeverActionsNative.LinkedRef_Clear(t, _TravelKW())
            ; pairs with the approach's RegisterTraveler
            SeverActionsNative.OrphanCleanup_UnregisterTraveler(t)
            SkyrimNetApi.RegisterPackage(t, "FollowPlayer", _HoldPriority(t), 0, true)
            t.EvaluatePackage()
            SeverActionsNativeExt2.Venture_RegisterAmbushThug(t)        ; gates the standoff actions
            ; Hold/parley bias. The directive is a lasting memory written as a hired blade, so
            ; never on the leader, who outlives the standoff.
            If t != AmbushLeader
                SeverActionsNativeExt2.Venture_StageThugDirective(t, AmbushDeserter)
            EndIf
        EndIf
        i += 1
    EndWhile

    ; The lootable letter goes to the lead (the speaker), never the leader it names.
    If AmbushLead != None && AmbushLead != AmbushLeader && AmbushLetterBody != ""
        String desertNm = ""
        If AmbushDeserter
            desertNm = AmbushDeserter.GetDisplayName()
        EndIf
        SeverActionsNativeExt.Letter_DeliverToCourier(AmbushDeserter, AmbushLead, AmbushLetterSubj, AmbushLetterBody, "thug", desertNm)
        AmbushLetterSubj = ""
        AmbushLetterBody = ""
    EndIf

    ; No TalkToPlayer for the lead: a second SkyrimNet package on top of FollowPlayer
    ; causes the dual-package AI flicker (see SeverActions_Follow). DirectNarration needs none.
    ; The taunt names the leader in the third person: a blade's line only.
    String taunt = SeverActionsNativeExt2.Venture_AmbushTaunt(AmbushDeserter)
    If taunt != "" && AmbushLead != None && AmbushLead != AmbushLeader
        SkyrimNetApi.DirectNarration(taunt, AmbushLead, player)
    EndIf
    If AmbushLead != None
        SeverActionsNative.Native_Persuasion_Begin(AmbushLead, player, 30.0, 600.0)
    EndIf
    Debug.Trace("[SeverActions_Ambush] standoff begun")
EndFunction

Int Function _HoldPriority(Actor t)
    {The standoff hold's priority: 100, or 120 for the leader, whose work sandbox (110)
     would otherwise walk them off the standoff (as for the approach jog).}
    If t == AmbushLeader
        Return 120
    EndIf
    Return 100
EndFunction

Actor Function _NearestBlade(Actor player)
    {The live hired blade (not the leader) nearest the player, or None.}
    Actor best = None
    Float bestDist = 0.0
    Int i = 0
    While i < AmbushThugs.Length
        Actor t = AmbushThugs[i]
        If t != None && t != AmbushLeader && !t.IsDead()
            Float d = t.GetDistance(player as ObjectReference)
            If best == None || d < bestDist
                best = t
                bestDist = d
            EndIf
        EndIf
        i += 1
    EndWhile
    Return best
EndFunction

Faction Function GetBanditFaction()
    {Vanilla BanditFaction: thugs leave it for the parley and rejoin it on combat.}
    Return Game.GetFormFromFile(0x0001BCC0, "Skyrim.esm") as Faction
EndFunction

Faction Function GetHiredBladeFaction()
    {SeverActions_HiredBladeFaction, the neutral faction thugs hold during the parley.}
    Return Game.GetFormFromFile(0x165674, "SeverActions.esp") as Faction
EndFunction

Function StripThugPackages(Actor t)
    {Clears the approach jog, its linked ref and orphan registration, and the SkyrimNet
     packages, so a resolve starts from a clean AI slate.}
    If t == None
        Return
    EndIf
    Package jog = SeverActionsNativeExt.Travel_GetSpeedPackage(SPEED_JOG)
    If jog != None
        ActorUtil.RemovePackageOverride(t, jog)
    EndIf
    SeverActionsNative.LinkedRef_Clear(t, _TravelKW())
    SeverActionsNative.OrphanCleanup_UnregisterTraveler(t)
    SkyrimNetApi.UnregisterPackage(t, "TalkToPlayer")
    SkyrimNetApi.UnregisterPackage(t, "FollowPlayer")
EndFunction

Function ThugStandDown_Execute(Actor akActor)
    {SkyrimNet action: the player talked the thugs down. They sheathe and walk off toward
     a far waypoint on the travel package; ProcessDepartingThugs despawns them. A real NPC
     (the leader) goes on their own AI instead (ReleaseAmbushLeader).}
    If !AmbushActive
        Return
    EndIf
    MarkKidnapSteelSpent()
    Actor player = Game.GetPlayer()
    SeverActionsNativeExt2.Native_Persuasion_EndFor(AmbushLead)

    ; The waypoint is an XMarkerHeading; delete the previous one so at most one exists.
    If AmbushAwayMarker != None
        AmbushAwayMarker.Disable()
        AmbushAwayMarker.Delete()
        AmbushAwayMarker = None
    EndIf
    ObjectReference awayMarker = None
    If player != None
        Form xm = Game.GetForm(0x00000034)
        If xm != None
            awayMarker = player.PlaceAtMe(xm, 1)
            If awayMarker != None
                awayMarker.MoveTo(player, 5000.0, 5000.0, 0.0)
                AmbushAwayMarker = awayMarker
            EndIf
        EndIf
    EndIf
    Package leavePkg = SeverActionsNativeExt.Travel_GetSpeedPackage(SPEED_JOG)
    Faction bladeFaction = GetHiredBladeFaction()

    Int i = 0
    While i < AmbushThugs.Length
        Actor t = AmbushThugs[i]
        If t && !t.IsDead() && (t == AmbushLeader || SeverActionsNativeExt2.Venture_IsRetainer(t))
            ; A real NPC walks away on their own AI, never onto the despawn list.
            StripThugPackages(t)
            If bladeFaction != None
                t.RemoveFromFaction(bladeFaction)
            EndIf
            t.StopCombat()
            t.SetAlert(false)
            t.SheatheWeapon()
            ReleaseAmbushLeader(t)
        ElseIf t && !t.IsDead()
            StripThugPackages(t)
            ; Leave the hired-blade faction; they go peacefully, so no BanditFaction.
            If bladeFaction != None
                t.RemoveFromFaction(bladeFaction)
            EndIf
            t.StopCombat()
            t.SetAlert(false)                  ; so they stay sheathed
            t.SheatheWeapon()
            t.SetActorValue("Aggression", 0)
            t.SetActorValue("Confidence", 0)   ; cowardly — won't turn back to fight
            If awayMarker != None && leavePkg != None
                ; The courier walk: SA travel package, linked-ref target.
                SeverActionsNative.LinkedRef_Set(t, awayMarker, _TravelKW())
                ; Registered: with orphanCleanupEnabled on, the orphan scan strips an unregistered
                ; thug's walk-off package.
                SeverActionsNative.OrphanCleanup_RegisterTraveler(t)
                ActorUtil.AddPackageOverride(t, leavePkg, TRAVEL_PACKAGE_PRIORITY, 1)
            EndIf
            StorageUtil.FormListAdd(self, "SeverTravel_DepartingThugs", t, false)
            t.EvaluatePackage()
        EndIf
        i += 1
    EndWhile
    StorageUtil.SetFloatValue(self, "SeverTravel_ThugDepartStart", Utility.GetCurrentRealTime())
    ; Not ClearAmbushState: it would strip the walk-off package just applied.
    ResetAmbushBookkeeping()
    ChronoArm(TICK_INTERVAL)   ; the despawn poll
    Debug.Trace("[SeverActions_Ambush] thugs stood down and walked off")
EndFunction

Function ProcessDepartingThugs()
    {Despawns walked-off thugs once out of sight (unloaded or past 3500u) after a 20 s
     grace, or after 300 s regardless (a navmesh-stuck thug). Nothing else cleans up
     these spawns. Dead thugs stay as lootable corpses.}
    Int count = StorageUtil.FormListCount(self, "SeverTravel_DepartingThugs")
    If count == 0
        Return
    EndIf
    Float started = StorageUtil.GetFloatValue(self, "SeverTravel_ThugDepartStart", 0.0)
    Float elapsed = Utility.GetCurrentRealTime() - started
    If elapsed < 0.0
        ; GetCurrentRealTime restarts each app session: re-baseline a start saved last session.
        StorageUtil.SetFloatValue(self, "SeverTravel_ThugDepartStart", Utility.GetCurrentRealTime())
        elapsed = 0.0
    EndIf
    Actor player = Game.GetPlayer()
    Int i = count - 1
    While i >= 0
        Actor t = StorageUtil.FormListGet(self, "SeverTravel_DepartingThugs", i) as Actor
        Bool gone = (t == None) || t.IsDead()
        If !gone
            Bool outOfSight = !t.Is3DLoaded()
            If !outOfSight && player != None
                outOfSight = t.GetDistance(player as ObjectReference) > 3500.0
            EndIf
            If SeverActionsNativeExt2.Venture_IsRetainer(t)
                ; A leader an older save put on the list: let them go, never despawn them.
                StripThugPackages(t)
                t.EvaluatePackage()
                gone = True
            ElseIf (elapsed >= 20.0 && outOfSight) || elapsed >= 300.0
                SeverActionsNative.OrphanCleanup_UnregisterTraveler(t)
                t.Disable()
                t.Delete()
                gone = True
            EndIf
        EndIf
        If gone
            StorageUtil.FormListRemoveAt(self, "SeverTravel_DepartingThugs", i)
        EndIf
        i -= 1
    EndWhile
    If StorageUtil.FormListCount(self, "SeverTravel_DepartingThugs") == 0
        StorageUtil.UnsetFloatValue(self, "SeverTravel_ThugDepartStart")
    EndIf
EndFunction

Function ThugAttack_Execute(Actor akActor)
    {SkyrimNet action: the thugs reject the player and attack.}
    If !AmbushActive
        Return
    EndIf
    ResolveAmbushCombat()
    Debug.Trace("[SeverActions_Ambush] thugs attack (rejected)")
EndFunction

Event OnPersuasionFailedEvent(String asEventName, String asReason, Float afUnused, Form akSender)
    {Shared with the arrest flow, so act only on a live ambush and its lead's window: the player
     drew, fled or timed out, and the thugs strike.}
    If !AmbushActive
        Return
    EndIf
    If AmbushLead == None || akSender != AmbushLead
        Return   ; another owner's window (an arrest plea or a camp parley)
    EndIf
    ResolveAmbushCombat()
    Debug.Trace("[SeverActions_Ambush] persuasion failed (" + asReason + ") - thugs attack")
EndEvent

Event OnVentureThugCombat(String asEventName, String asReason, Float afUnused, Form akSender)
    {A standoff thug entered combat by any path (the native combat-enter hook; includes
     a generic AttackTarget that bypasses our resolve). Turn the whole pack hostile so
     the player's follower's hits land too.}
    If !AmbushActive
        Return
    EndIf
    ResolveAmbushCombat()
    Debug.Trace("[SeverActions_Ambush] a thug entered combat - normalizing pack to full fight")
EndEvent

Function ResolveAmbushCombat()
    {Standoff to fight: strip the packages, rejoin BanditFaction, go aggressive and
     engage. The bodies stay to be looted (the lead carries the letter).}
    MarkKidnapSteelSpent()
    Actor player = Game.GetPlayer()
    Faction banditFaction = GetBanditFaction()
    Faction bladeFaction = GetHiredBladeFaction()
    SeverActionsNativeExt2.Native_Persuasion_EndFor(AmbushLead)
    Int i = 0
    While i < AmbushThugs.Length
        Actor t = AmbushThugs[i]
        If t && !t.IsDead()
            StripThugPackages(t)
            ; Hostile again, so the player's follower engages them.
            If bladeFaction != None
                t.RemoveFromFaction(bladeFaction)
            EndIf
            ; The leader is no bandit: combat with the player is enough, and the tick puts
            ; their own values back when the fight ends.
            If t == AmbushLeader
                LeaderFighting = True
            ElseIf banditFaction != None
                t.AddToFaction(banditFaction)
            EndIf
            t.SetActorValue("Aggression", 2)
            t.SetAlert(true)
            t.StartCombat(player)
        EndIf
        i += 1
    EndWhile
    ResetAmbushBookkeeping()
    If LeaderFighting
        ChronoArm(TICK_INTERVAL)
    EndIf
EndFunction

Function ReleaseAmbushLeader(Actor t)
    {Let a real NPC go after an ambush: their own Aggression and Confidence back (the
     snapshot), then their own AI. Safe on None and on an actor with no snapshot.}
    If t != None && t == AmbushLeader
        t.SetActorValue("Aggression", LeaderOrigAggression)
        t.SetActorValue("Confidence", LeaderOrigConfidence)
    EndIf
    If t == AmbushLeader
        AmbushLeader = None
        LeaderFighting = False
    EndIf
    If t != None && !t.IsDead()
        t.EvaluatePackage()
    EndIf
EndFunction

Function MarkKidnapSteelSpent()
    {For a search party after a REFUSED ransom, any resolution spends the hold's steel:
     stamp the victim so the kidnap tick can reopen negotiation (the flag also feeds the
     next ransom's desperation premium). Grudge ambushes no-op (their sender has no ransom
     state). Both keys are sharedKeys rows.}
    If AmbushDeserter == None
        Return
    EndIf
    ; 3 = KIDNAP_RANSOM_REFUSED (KidnapStore::RansomState).
    If SeverActionsNativeExt.Native_Kidnap_GetRansomState(AmbushDeserter) == 3
        StorageUtil.SetFloatValue(AmbushDeserter, "SA_KidnapSteelSpentGT", Utility.GetCurrentGameTime())
        StorageUtil.SetIntValue(AmbushDeserter, "SA_KidnapSteelFailed", 1)
        Debug.Trace("[SeverActions_Ambush] hold steel spent for refused-ransom captive " + AmbushDeserter.GetDisplayName())
    EndIf
EndFunction

Function ResetAmbushBookkeeping()
    {Resets the flags and the standoff-action eligibility WITHOUT touching packages (the
     stand-down relies on its walk-off package surviving).}
    SeverActionsNativeExt2.Venture_ClearAmbushThugs()
    AmbushActive = False
    AmbushApproaching = False
    ; The lead's persuasion window goes with the lead (a new ambush can reset mid-standoff).
    SeverActionsNativeExt2.Native_Persuasion_EndFor(AmbushLead)
    AmbushLead = None
    AmbushDeserter = None
    AmbushLetterSubj = ""
    AmbushLetterBody = ""
EndFunction

Function ClearAmbushState()
    {Full teardown: strip packages, leave the hired-blade faction, reset bookkeeping.}
    Faction bladeFaction = GetHiredBladeFaction()
    If AmbushThugs   ; not `!= None` (see _AbandonStandoffOnLoad)
        Int i = 0
        While i < AmbushThugs.Length
            Actor t = AmbushThugs[i]
            StripThugPackages(t)
            If t != None && bladeFaction != None
                t.RemoveFromFaction(bladeFaction)
            EndIf
            If t != None && t == AmbushLeader
                ReleaseAmbushLeader(t)
            EndIf
            i += 1
        EndWhile
    EndIf
    ResetAmbushBookkeeping()
EndFunction

Function ReassertThugStance()
    {Keeps every live thug weapon-out, alert and on FollowPlayer (re-registered if
     SkyrimNet dropped it) for the whole standoff.}
    Int i = 0
    While i < AmbushThugs.Length
        Actor t = AmbushThugs[i]
        If t != None && !t.IsDead()
            If !t.IsWeaponDrawn()
                t.SetAlert(true)
                t.DrawWeapon()
            EndIf
            If !SkyrimNetApi.HasPackage(t, "FollowPlayer")
                SkyrimNetApi.RegisterPackage(t, "FollowPlayer", _HoldPriority(t), 0, true)
                t.EvaluatePackage()
            EndIf
        EndIf
        i += 1
    EndWhile
EndFunction
