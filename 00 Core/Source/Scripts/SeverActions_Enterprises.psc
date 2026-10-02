Scriptname SeverActions_Enterprises extends Quest
{The Enterprises module (plan 5.1 B21): the LLM-callable entry points of the retainer economy
 and camp takeover, the Final Audit / Levy packages, steward visits and the Audit's walk
 (orchestrator journeys tagged stewardvisit / finalaudit), the camp war-band muster, and the free
 side of the camp and retainer persistence pools. The Ext2 natives own every rule; these
 functions stay thin. Maintenance runs from the enterprises provider's stage 1 on every load
 (DR20). Other scripts named are in the requires closure (followers, travelcore; furniturelib
 via followers; DR2). No chronometer tick; the muster pump is the quest's only game-time
 update user (S4).}

; Records and values, by FormID / runtime value (DR3, DR18)
Int Property FID_TRAVEL_TARGET_KW = 0x076F5F AutoReadOnly   ; SeverTravelKeyword (Travel.TravelTargetKeyword's fill)
Int Property SPEED_WALK = 0 AutoReadOnly
Int Property SPEED_JOG = 1 AutoReadOnly
Float Property ARRIVAL_DISTANCE = 300.0 AutoReadOnly
{SeverActions_Travel.ArrivalDistance's runtime value (the .psc default; the ESP has no fill).}
Int Property TRAVEL_PACKAGE_PRIORITY = 85 AutoReadOnly
{SeverActions_Travel.TravelPackagePriority's VMAD fill: the pool-exhaustion fallback override.}
Int Property TRAVEL_OPTIONS_QUIETLONG = 44 AutoReadOnly
{Quiet | SkipPreflight | AbortOnDegraded: no journal objective, no map marker.}
Int Property STEWARD_VISIT_PRIORITY = 110 AutoReadOnly
{Above the guard-duty pool (105) and the traveler pool (106), so a steward on
 person duty still keeps the visit.}
Float Property AUDIT_FOLLOW_HANDOFF = 1000.0 AutoReadOnly
{Where the Final Audit's walk hands over to the follow package; mirrors
 VentureMonitor::kAuditFollowHandoff (keep in step). Wider than ARRIVAL_DISTANCE:
 route steering is coarse, and the follow package makes the final beeline.}
Int Property FOLLOW_QUEST_FORMID = 0x0016A78D AutoReadOnly
{SeverActions_FollowQuest, the 200-alias follow pool the war band sits in (FollowPool_Claim,
 plan M-W).}
Int Property FOLLOW_POOL_SIZE = 200 AutoReadOnly
Int Property CAMP_PERSIST_QUEST_FORMID = 0x16A793 AutoReadOnly
{SeverActions_CampPersist: 300 package-free aliases keeping every sworn camp member persistent
 (resolvable anywhere, immune to the leveled re-roll). Native seats; this script frees.}
Int Property CAMP_PERSIST_POOL_SIZE = 300 AutoReadOnly
Int Property RETAINER_PERSIST_QUEST_FORMID = 0x16B000 AutoReadOnly
{SeverActions_RetainerPersist: 500 package-free aliases keeping every active retainer
 persistent. Native seats (VentureMonitor::SeatInPersistPool); this script frees, because a
 native alias clear is unreliable and ReferenceAlias.Clear() is not.}
Int Property RETAINER_PERSIST_POOL_SIZE = 500 AutoReadOnly

Quest _followQuest = None
Quest _campPersistQuest = None
Bool _campPersistResolved = false
Bool _campPersistMissingWarned = false
Quest _retainerPersistQuest = None
Bool _retainerPersistResolved = false
Bool _retainerPersistMissingWarned = false


Event OnInit()
    ; No setup here (DR20): a script re-added to a save that once held it gets no OnInit (F35).
    Debug.Trace("[SeverActions] SeverActions_Enterprises: bound")
EndEvent

MiscObject Function _Gold()
    {Gold001 by FormID; Currency's Gold001 property is that module's (DR2).}
    Return Game.GetFormFromFile(0x0000000F, "Skyrim.esm") as MiscObject
EndFunction

Function Maintenance()
    {Load recovery, from the enterprises provider's stage 1 on every load and new game
     (idempotent, DR20). Every listener is registered HERE only: a partial copy elsewhere is
     how a listener ends up bound on one path and silently dead on the other. The court
     package is re-applied directly so the detail's AI never depends on an event landing.}
    RegisterForModEvent("SeverActions_FinalAuditArrived", "OnFinalAuditArrived")
    RegisterForModEvent("SeverActions_FinalAuditDeployed", "OnFinalAuditDeployed")
    RegisterForModEvent("SeverActions_FinalAuditApproach", "OnFinalAuditApproach")
    RegisterForModEvent("SeverActions_FinalAuditStandDown", "OnFinalAuditStandDown")
    RegisterForModEvent("SeverActions_FinalAuditEscortMode", "OnFinalAuditEscortMode")
    RegisterForModEvent("SeverActions_LevySquadDwell", "OnLevySquadDwell")
    RegisterForModEvent("SeverActions_FinalAuditDisbanded", "OnFinalAuditDisbanded")
    ; Orchestrator journeys (the Audit's walk, steward visits) and the shared completion event.
    RegisterForModEvent("SeverActions_FinalAuditTravel", "OnFinalAuditTravel")
    RegisterForModEvent("SeverActions_FinalAuditTravelAbort", "OnFinalAuditTravelAbort")
    RegisterForModEvent("SeverActions_StewardVisitTravel", "OnStewardVisitTravel")
    RegisterForModEvent("SeverActions_StewardVisitArrived", "OnStewardVisitArrived")
    RegisterForModEvent("SeverActions_StewardVisitEnd", "OnStewardVisitEnd")
    RegisterForModEvent("SeverActions_TravelComplete", "OnTravelComplete")
    ; A retainer left service during the off-screen settle; C++ has no notification primitive.
    RegisterForModEvent("SeverActions_VentureDeparted", "OnVentureDeparted")
    ; The camp war band and the persistence pools. CampMuster (the UI handler at menu close,
    ; Camp_Renounce's unwind): strArg = signed-decimal camp id, numArg 1 = rally, 0 = send home.
    RegisterForModEvent("SeverActions_CampMuster", "OnCampMusterEvent")
    RegisterForModEvent("SeverActions_CampMemberSeen", "OnCampMemberSeen")
    RegisterForModEvent("SeverActions_CampMemberDied", "OnCampMemberDied")
    RegisterForModEvent("SeverActions_CampReleased", "OnCampReleased")
    RegisterForModEvent("SeverActions_RetainerUnpersist", "OnRetainerUnpersist")
    ; The assign-retainer popup's confirm (see OnRetainerWorkLoc).
    RegisterForModEvent("SeverActions_RetainerWorkLoc", "OnRetainerWorkLoc")
    String auditState = SeverActionsNativeExt2.Venture_Audit_State()
    If auditState == "casebuilding"
        ApplyFinalAuditCourtPackage()
    ElseIf auditState == "approaching" || auditState == "demanding"
        ; Put the march packages back - unless he is still walking: the march follow
        ; (110) outranks the Traveler_NN alias (106) and would stop the journey dead.
        ; Native answers from a live travel session and fires
        ; SeverActions_FinalAuditApproach itself when he arrives.
        If !SeverActionsNativeExt2.Venture_Audit_IsTraveling()
            ApplyFinalAuditApproachPackages()
        Else
            Debug.Trace("[SeverActions] Final Audit: the General is still on the road - march packages held back")
        EndIf
    ElseIf auditState == "paid"
        ; Paid is terminal and the native tick ignores the detail, so a dropped stand-down
        ; event would leave the march overrides and drawn weapons on for good. Idempotent.
        StandDownFinalAudit()
    EndIf
    ; Kick the muster pump once per load; with nobody seated it scans once and stops.
    RegisterForSingleUpdateGameTime(0.1)
    ; Persistence-pool janitors (holders that left a sworn camp or service across a save).
    SweepCampPersistPool()
    SweepRetainerPersistPool()
    ; Premises follow the work marker: older saves carry hand-picked premises, and a
    ; property can be sold while its worker is off-screen.
    SyncAllPremisesFromWork()
    _MigrateCampCuts()
    _MigrateRenownCap()
EndFunction

Keyword Function _TravelKW()
    Return Game.GetFormFromFile(FID_TRAVEL_TARGET_KW, "SeverActions.esp") as Keyword
EndFunction

SeverActions_FollowerManager Function _FM()
    {The homes helpers' host (followers is in this module's requires closure, DR2).}
    Return (Self as Quest) as SeverActions_FollowerManager
EndFunction

Function DebugMsg(String msg)
    Debug.Trace("[SeverActions_Enterprises] " + msg)
EndFunction

Quest Function _FollowQuest()
    {The follow pool quest by FormID (VR strips EditorIDs). None on an ESP without the pool,
     and the muster then seats nobody.}
    If !_followQuest
        _followQuest = Game.GetFormFromFile(FOLLOW_QUEST_FORMID, "SeverActions.esp") as Quest
    EndIf
    Return _followQuest
EndFunction

ReferenceAlias Function _FollowAlias(Int aiIndex)
    If aiIndex < 0 || aiIndex >= FOLLOW_POOL_SIZE
        Return None
    EndIf
    Quest pool = _FollowQuest()
    If !pool
        Return None
    EndIf
    Return pool.GetNthAlias(aiIndex) as ReferenceAlias
EndFunction

Function _DisengageForTravel(Actor akNPC, String asTag)
    {Before a journey: stand the traveler up from furniture and cancel in-flight crafting,
     as SeverActions_Travel.DisengageOverridesForTravel does for its own journeys.}
    If SeverActions_FurnitureLib.CanStop(akNPC)
        DebugMsg(asTag + ": standing " + akNPC.GetDisplayName() + " up from furniture before travel")
        SeverActions_FurnitureLib.Stop(akNPC)
    EndIf
    If SeverActionsNativeExt2.Craft_CancelByActor(akNPC) > 0
        DebugMsg(asTag + ": cancelled in-flight crafting for " + akNPC.GetDisplayName() + " before travel")
    EndIf
EndFunction

Function _ClearTravelQuietly(Actor akNPC)
    {SeverActions_Travel.ClearTravelPackagesQuietly for this script's unannounced journeys:
     strips every travel-family override and the travel LinkedRef, with no notification.}
    SeverActions_TravelCore.StripTravelOverrides(akNPC)
    SeverActionsNative.LinkedRef_Clear(akNPC, _TravelKW())
EndFunction

Function _MigrateRenownCap()
    {Turns the renown cap back ON once per save (ledger claim RenownCapDefaultOn v2, rule 15;
     adopted StorageUtil counter SeverActions_RenownCapOffMig: 1 = forced off, 2 = restored).
     Safe because GrandfatherRenownToRoster promotes an over-cap roster on every load; the
     player's own setting stands afterwards. Lives here because the row is this module's
     (rule 16). Settings_Set writes only the row, so the native is pushed too
     (FollowerManager's push ran earlier, in the followers stage).}
    String mig = "RenownCapDefaultOn"
    Bool sentinel = StorageUtil.GetIntValue(None, "SeverActions_RenownCapOffMig", 0) >= 2
    If SeverActionsNativeExt2.Migration_AdoptSentinel(mig, 2, sentinel)
        Return
    EndIf
    If !SeverActionsNativeExt2.Migration_TryClaim(mig, 2)
        Return
    EndIf
    SeverActionsNativeExt2.Settings_Set("enterpriseRenownCapEnabled", "true")
    SeverActionsNativeExt2.Venture_SetRenownCapEnabled(true)
    StorageUtil.SetIntValue(None, "SeverActions_RenownCapOffMig", 2)
    SeverActionsNativeExt2.Migration_MarkDone(mig, 2)
EndFunction

Function _MigrateCampCuts()
    {C17: moves camp ventures still at the old default cuts (Partnership 40 -> 20, Vassalage
     60 -> 40); renegotiated deals stay. Needed because kCampFairCutPct moved with the
     defaults, so an agreed camp left at 40 would read as coerced. Ledger claim (rule 15);
     Combat's old StorageUtil sentinel is adopted as the done signal and still written.}
    String mig = "CampCutRetune"
    Bool sentinel = StorageUtil.GetIntValue(None, "SeverActions_CampCutMigDone", 0) >= 1
    If SeverActionsNativeExt2.Migration_AdoptSentinel(mig, 1, sentinel)
        Return
    EndIf
    If !SeverActionsNativeExt2.Migration_TryClaim(mig, 1)
        Return
    EndIf
    Int cutsMoved = SeverActionsNativeExt2.Venture_MigrateCampCuts()
    If cutsMoved > 0
        Debug.Trace("[SeverActions] Camp cuts migrated to 20/40 for " + cutsMoved + " venture(s)")
    EndIf
    StorageUtil.SetIntValue(None, "SeverActions_CampCutMigDone", 1)
    SeverActionsNativeExt2.Migration_MarkDone(mig, 1)
EndFunction

; ===== FINAL AUDIT / IMPERIAL LEVY - the detail's packages =====

Function ApplyFinalAuditCourtPackage()
    {Court sandbox override (priority 100) on the General, then the escort and the garrisons.
     An override is required: the TPLT template makes the engine ignore the base record's
     package list. Idempotent (PO3 cosaves overrides); the load path and the deploy event call it.}
    Package courtPkg = Game.GetFormFromFile(0x00165676, "SeverActions.esp") as Package
    If !courtPkg
        Debug.Trace("[SeverActions] Final Audit: court package 0x165676 missing")
        Return
    EndIf
    ; The General only: the Legates' work-anchor link points at him, and a sandbox does not
    ; chase a moving anchor, so it would strand them when he walks off. They keep the Follow.
    Actor general = SeverActionsNativeExt2.Venture_Audit_Collector(0)
    If general && !general.IsDead()
        ActorUtil.AddPackageOverride(general, courtPkg, 100, 1)
        general.EvaluatePackage()
    EndIf
    EnsureFinalAuditEscort()
    PostFinalAuditGarrisons()
    Debug.Trace("[SeverActions] Final Audit: court package on the General, escort following him, garrisons posted")
EndFunction

Int Function FinalAuditEscortSize() Global
    {Bound of the trio loops over Venture_Audit_Collector: 0 = the General, 1-2 = the Legates.
     The twelve (3-14) garrison five holds and are deliberately excluded; see
     PostFinalAuditGarrisons.}
    Return 3
EndFunction

Int Function FinalAuditGarrisonFirst() Global
    {First Venture_Audit_Collector index of the twelve.}
    Return 3
EndFunction

Int Function FinalAuditGarrisonLast() Global
    {One past the last garrison index.}
    Return 15
EndFunction

Function PostFinalAuditGarrisons()
    {Hand the twelve to their patrol aliases on SeverActions_LevyPatrolQuest (16AC46; native
     seats them) by removing every standing override. Alias packages run at the quest's DNAM
     priority (95), so a priority-100 override left on would silently stop the patrols
     while the log says the pool is seated. OnLevySquadDwell uses that lever on purpose.
     Idempotent.}
    ; Older saves may carry 165676 (r1200 court sandbox) or 16AC45 (r4096 work sandbox);
    ; removing an absent override is a no-op.
    Package courtPkg = Game.GetFormFromFile(0x00165676, "SeverActions.esp") as Package
    Package workPkg = Game.GetFormFromFile(0x0016AC45, "SeverActions.esp") as Package
    Int i = FinalAuditGarrisonFirst()
    Int last = FinalAuditGarrisonLast()
    Int posted = 0
    While i < last
        Actor s = SeverActionsNativeExt2.Venture_Audit_Collector(i)
        If s && !s.IsDead()
            If courtPkg
                ActorUtil.RemovePackageOverride(s, courtPkg)
            EndIf
            If workPkg
                ActorUtil.RemovePackageOverride(s, workPkg)
            EndIf
            s.EvaluatePackage()
            posted += 1
        EndIf
        i += 1
    EndWhile
    Debug.Trace("[SeverActions] Levy garrison: " + posted + " soldiers released to their patrol aliases")
EndFunction

Event OnLevySquadDwell(String eventName, String strArg, Float numArg, Form sender)
    {One event per soldier (sender); native decides squad membership. strArg "dwell" applies
     the dwell sandbox 16AC4B (QNAM on the patrol quest) at priority 100, outranking the alias
     patrol (95); anything else removes it and the patrol resumes. Native moves the squad's
     anchor onto the leader first, so they settle where the patrol stopped.}
    Actor s = sender as Actor
    If !s || s.IsDead()
        Return
    EndIf
    Package dwellPkg = Game.GetFormFromFile(0x0016AC4B, "SeverActions.esp") as Package
    If !dwellPkg
        Debug.Trace("[SeverActions] Levy dwell: package 0x16AC4B missing")
        Return
    EndIf
    If strArg == "dwell"
        ActorUtil.AddPackageOverride(s, dwellPkg, 100, 1)
    Else
        ActorUtil.RemovePackageOverride(s, dwellPkg)
    EndIf
    s.EvaluatePackage()
EndEvent

Function EnsureFinalAuditEscort()
    {The two Legates follow the General in every state: a LinkedRef under
     SeverActions_FollowTargetKW and the Follow template (SeverActions_GuardBodyguard 0x165677)
     at priority 110; SetFinalAuditEscortSandbox swaps in the idle sandbox when he settles.
     The FinalAuditEscortSize bound keeps the twelve out on purpose: anchored to the General
     they would collapse the garrison into whatever room he settles in. Idempotent.}
    Package guardPkg = Game.GetFormFromFile(0x00165677, "SeverActions.esp") as Package
    Keyword followKw = Game.GetFormFromFile(0x00030155, "SeverActions.esp") as Keyword
    Actor cassius    = SeverActionsNativeExt2.Venture_Audit_Collector(0)
    If !guardPkg || !followKw || !cassius
        Debug.Trace("[SeverActions] Final Audit: escort package/keyword/General missing")
        Return
    EndIf
    ; No escort on a corpse: if the General fell, the audit is over.
    If cassius.IsDead()
        Debug.Trace("[SeverActions] Final Audit: General is dead - escort left as-is")
        Return
    EndIf
    Int i = 1
    Int detail = FinalAuditEscortSize()
    While i < detail
        Actor escort = SeverActionsNativeExt2.Venture_Audit_Collector(i)
        If escort && !escort.IsDead()
            SeverActionsNativeExt.LinkedRef_SetPermanent(escort, cassius, followKw)
            ActorUtil.AddPackageOverride(escort, guardPkg, 110, 1)
            escort.EvaluatePackage()
        EndIf
        i += 1
    EndWhile
EndFunction

Event OnFinalAuditEscortMode(String eventName, String strArg, Float numArg, Form sender)
    {strArg = "follow" | "sandbox"; native fires it only when the General starts moving or
     settles, not every tick.}
    SetFinalAuditEscortSandbox(strArg == "sandbox")
EndEvent

Function SetFinalAuditEscortSandbox(Bool abSandbox)
    {Swap the escort between the Follow (marching) and the court sandbox (standing easy): the
     Follow template just stands when its target stops. Their work-anchor link (native's
     formation link) points at the General, so the sandbox mills them about him - but it does not chase a moving anchor, so
     it comes off when he moves. The other override is removed, or Follow (110) always wins.}
    Package courtPkg = Game.GetFormFromFile(0x00165676, "SeverActions.esp") as Package
    Package guardPkg = Game.GetFormFromFile(0x00165677, "SeverActions.esp") as Package
    Actor cassius    = SeverActionsNativeExt2.Venture_Audit_Collector(0)
    If !courtPkg || !guardPkg || !cassius || cassius.IsDead()
        Return
    EndIf
    Int i = 1
    Int detail = FinalAuditEscortSize()
    While i < detail
        Actor escort = SeverActionsNativeExt2.Venture_Audit_Collector(i)
        If escort && !escort.IsDead()
            If abSandbox
                ActorUtil.RemovePackageOverride(escort, guardPkg)
                ActorUtil.AddPackageOverride(escort, courtPkg, 100, 1)
            Else
                ActorUtil.RemovePackageOverride(escort, courtPkg)
                ActorUtil.AddPackageOverride(escort, guardPkg, 110, 1)
            EndIf
            escort.EvaluatePackage()
        EndIf
        i += 1
    EndWhile
    If abSandbox
        Debug.Trace("[SeverActions] Final Audit escort standing easy - sandboxing around the General")
    Else
        Debug.Trace("[SeverActions] Final Audit escort marching - following the General")
    EndIf
EndFunction

Event OnFinalAuditDeployed(String eventName, String strArg, Float numArg, Form sender)
    {Case opened mid-session: the same application as the load path.}
    ApplyFinalAuditCourtPackage()
EndEvent

Function ApplyFinalAuditApproachPackages()
    {The march: the General takes the close-follow package on the player at priority 110
     (court sandbox removed); the Legates keep following him, so only one actor is steered.}
    Package courtPkg  = Game.GetFormFromFile(0x00165676, "SeverActions.esp") as Package
    Package followPkg = Game.GetFormFromFile(0x0016567C, "SeverActions.esp") as Package
    Package guardPkg  = Game.GetFormFromFile(0x00165677, "SeverActions.esp") as Package
    Keyword followKw  = Game.GetFormFromFile(0x00030155, "SeverActions.esp") as Keyword
    If !followPkg || !guardPkg || !followKw
        Debug.Trace("[SeverActions] Final Audit: approach packages/keyword missing")
        Return
    EndIf
    Actor cassius = SeverActionsNativeExt2.Venture_Audit_Collector(0)
    If cassius && !cassius.IsDead()
        If courtPkg
            ActorUtil.RemovePackageOverride(cassius, courtPkg)
        EndIf
        ActorUtil.AddPackageOverride(cassius, followPkg, 110, 1)
        cassius.EvaluatePackage()
    EndIf
    ; Strip any court sandbox off the escort (standing easy, or an older save), then
    ; re-assert their Follow.
    Int i = 1
    Int detail = FinalAuditEscortSize()
    While i < detail
        Actor escort = SeverActionsNativeExt2.Venture_Audit_Collector(i)
        If escort && !escort.IsDead() && courtPkg
            ActorUtil.RemovePackageOverride(escort, courtPkg)
        EndIf
        i += 1
    EndWhile
    EnsureFinalAuditEscort()
    Debug.Trace("[SeverActions] Final Audit approach packages applied - the detail is marching")
EndFunction

Event OnFinalAuditApproach(String eventName, String strArg, Float numArg, Form sender)
    {Grace lapsed - they set out for the player.}
    ApplyFinalAuditApproachPackages()
EndEvent

Event OnFinalAuditStandDown(String eventName, String strArg, Float numArg, Form sender)
    {Paid, or the audit withdrew unresolved. Hand the detail back to the court.}
    StandDownFinalAudit()
EndEvent

Function StandDownFinalAudit()
    {Sheathe, drop the General's march package and restore the court sandbox, so the detail
     walks home to court. Idempotent (the stand-down event and the load path).}
    Package followPkg = Game.GetFormFromFile(0x0016567C, "SeverActions.esp") as Package
    Int i = 0
    Int detail = FinalAuditEscortSize()
    While i < detail
        Actor c = SeverActionsNativeExt2.Venture_Audit_Collector(i)
        If c && !c.IsDead()
            c.SheatheWeapon()
            ; Only the General drops his march package. The escort keeps its Follow,
            ; or they are left with no package as he walks home.
            If i == 0 && followPkg
                ActorUtil.RemovePackageOverride(c, followPkg)
            EndIf
        EndIf
        i += 1
    EndWhile
    ApplyFinalAuditCourtPackage()
EndFunction

Event OnFinalAuditDisbanded(String eventName, String strArg, Float numArg, Form sender)
    {The Levy switch went off with the detail deployed. Native already disabled all fifteen
     and reset the case to Dormant; clear every override so a later re-arm starts clean.}
    DisbandFinalAudit()
EndEvent

Function DisbandFinalAudit()
    {Strip every audit/levy override (court 165676, escort 165677, march 16567C, garrison
     16AC45, dwell 16AC4B) off all fifteen and sheathe; nothing is re-applied. The one path
     that loops the trio AND the twelve. Removing an absent override is a no-op.}
    Package courtPkg  = Game.GetFormFromFile(0x00165676, "SeverActions.esp") as Package
    Package guardPkg  = Game.GetFormFromFile(0x00165677, "SeverActions.esp") as Package
    Package followPkg = Game.GetFormFromFile(0x0016567C, "SeverActions.esp") as Package
    Package workPkg   = Game.GetFormFromFile(0x0016AC45, "SeverActions.esp") as Package
    Package dwellPkg  = Game.GetFormFromFile(0x0016AC4B, "SeverActions.esp") as Package
    Int i = 0
    Int last = FinalAuditGarrisonLast()
    Int cleared = 0
    While i < last
        Actor c = SeverActionsNativeExt2.Venture_Audit_Collector(i)
        If c
            If courtPkg
                ActorUtil.RemovePackageOverride(c, courtPkg)
            EndIf
            If guardPkg
                ActorUtil.RemovePackageOverride(c, guardPkg)
            EndIf
            If followPkg
                ActorUtil.RemovePackageOverride(c, followPkg)
            EndIf
            If workPkg
                ActorUtil.RemovePackageOverride(c, workPkg)
            EndIf
            If dwellPkg
                ActorUtil.RemovePackageOverride(c, dwellPkg)
            EndIf
            If !c.IsDead()
                c.SheatheWeapon()
            EndIf
            c.EvaluatePackage()
            cleared += 1
        EndIf
        i += 1
    EndWhile
    Debug.Trace("[SeverActions] Imperial Levy disbanded by setting - overrides cleared on " + cleared + " of " + last + " refs")
EndFunction

Event OnFinalAuditArrived(String eventName, String strArg, Float numArg, Form sender)
    {The detail reached the player; strArg = the assessed demand. Weapons come out and the
     General opens the conversation: DirectNarration forces an LLM response, where
     RegisterEvent would only file context.}
    Actor player = Game.GetPlayer()
    Actor cassius = SeverActionsNativeExt2.Venture_Audit_Collector(0)
    Int i = 0
    Int detail = FinalAuditEscortSize()
    While i < detail
        Actor c = SeverActionsNativeExt2.Venture_Audit_Collector(i)
        If c && !c.IsDead()
            c.DrawWeapon()
        EndIf
        i += 1
    EndWhile
    If !cassius || cassius.IsDead()
        Return
    EndIf
    ; Notify first: the LLM round trip takes seconds, and the drawn weapons and this
    ; line are the only instant cues.
    Debug.Notification(SeverActionsNativeExt2.Native_L10n("currency.imperialFinalAuditFound"))
    SkyrimNetApi.DirectNarration(         "General Cassius Vero of the Imperial Treasury steps into " + player.GetDisplayName() + "'s path and stops them, his two Legates fanning out at his shoulders with weapons drawn and spells banked. He has tracked them down deliberately. He states the Treasury's business without preamble: the Empire has assessed " + strArg + " septims in back-taxes against " + player.GetDisplayName() + "'s enterprises - untaxed coin the ledgers never saw - and he has come to collect the full sum here and now. He is courteous, unhurried, and absolutely certain, and he does not intend to ask twice.",         cassius, player)
EndEvent

; ===== SkyrimNet dialogue actions =====
; The LLM-callable entry points named by the YAMLs under Actions/Enterprises and
; Actions/Enterprises-Camps; the retainer economy itself is native (VentureMonitor).

Bool Function HireRetainer(Actor akActor, String job, String arrangement)
    {Opens the assign-retainer popup prefilled with the agreed job and arrangement; the popup
     commits the hire. Without the popup, hires directly on the agreed terms. False if already
     a retainer in service; a deserter is re-hired on the new terms.}
    If !akActor
        Return false
    EndIf
    ; In service only: a Deserted row is an ended job the hire replaces (VentureStore::Add), and
    ; hireretainer.yaml offers it (retainer_status is "" for a deserter). A Hostile row is never
    ; offered, and the hire itself refuses one.
    If SeverActionsNativeExt2.Venture_IsActiveRetainer(akActor)
        Return false
    EndIf
    ; Called in conversation (no menu open), so the non-pausing popup shows.
    If SeverActionsNativeExt.Magelight_IsRetainerAssignPromptAvailable() \
        && SeverActionsNativeExt.Magelight_OpenRetainerAssignPrompt(akActor, "", job, arrangement, 90000)
        Return true
    EndIf
    Return SeverActionsNativeExt2.Venture_Hire(akActor, job, arrangement)
EndFunction

; Camp takeover
; Camp_Swear owns the guards (a non-leader on the agree route, a living chief on the
; recruit route); the YAML gates mirror them so the actions surface only when they can work.

Bool Function SwearCampToPlayer(Actor akActor)
    {Route B: the camp's leader swears the whole camp to the player (one holding, Partnership
     terms). The native refuses a non-leader.}
    If !akActor
        Return false
    EndIf
    Bool ok = SeverActionsNativeExt2.Camp_Swear(akActor, true)
    If ok
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("currency.campSwornToYou"))
    EndIf
    Return ok
EndFunction

Bool Function RecruitLeaderlessCamp(Actor akActor)
    {Route A: a leaderless camp (chief killed or never designated) swears by consensus, one
     member per call (Vassalage terms). False is the ordinary outcome:
       true             - the vote carried and the camp is sworn.
       false + a tally  - this member's agreement was recorded; more needed.
       false + no tally - refused (chief alive, already sworn, takeover off).}
    If !akActor
        Return false
    EndIf
    Bool ok = SeverActionsNativeExt2.Camp_Swear(akActor, false)
    If ok
        ; The vote carried. Announced here, not by a YAML eventString, which would fire on
        ; every vote.
        SkyrimNetApi.RegisterEvent("camp_sworn_by_consensus",         akActor.GetDisplayName() + " gives the last word needed - with nobody in charge to speak for them, enough of the camp has now agreed that it is settled. They answer to " + Game.GetPlayer().GetDisplayName() + " from here.",         akActor, Game.GetPlayer())
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("currency.campAnswersToYou"))
        Return true
    EndIf

    ; One vote of several: narrate it so the player sees it move and the rest of the
    ; crew hears who broke ranks.
    String tally = SeverActionsNativeExt2.Camp_ConsentTally(akActor)
    If tally != ""
        SkyrimNetApi.RegisterEvent("camp_consent_given",             akActor.GetDisplayName() + " gives their word to " + Game.GetPlayer().GetDisplayName() +             " - but with nobody in charge here, one voice does not settle it. That is " + tally +             " of the camp agreed. The others heard exactly who said yes, and what they think of " +             akActor.GetDisplayName() + " colours what they do next.", akActor, Game.GetPlayer())
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("currency.theyAgreeTally", ("" + tally)))
    EndIf
    Return false
EndFunction

Bool Function ReleaseCampFromService(Actor akActor)
    {Release a sworn camp: drops its ventures and thaws the respawn freeze. A mustered war band
     is sent home first, as the Camps tab's release does, or it keeps its seats and follows on.}
    If !akActor
        Return false
    EndIf
    If SeverActionsNativeExt2.Camp_IsMustered(SeverActionsNativeExt2.Camp_CampIdOf(akActor))
        SendCampHome(akActor)
    EndIf
    Bool ok = SeverActionsNativeExt2.Camp_Release(akActor)
    If ok
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("currency.releaseCampFromService"))
    EndIf
    Return ok
EndFunction

Bool Function RenounceCampOath(Actor akActor)
    {The chief breaks the camp's oath: every venture closes and the whole crew turns hostile
     (the truce layer's group break). The native refuses a non-leader.}
    If !akActor
        Return false
    EndIf
    ; A chief who is also the player's companion turns with the crew: out of service first.
    If SeverActionsNativeExt2.Camp_IsLeader(akActor) && SeverActionsNativeExt.Native_GetIsFollower(akActor)
        SeverActions_ModuleBase.CallBool("followers", "leaveToAttack", akActor, Game.GetPlayer())
    EndIf
    Bool ok = SeverActionsNativeExt2.Camp_Renounce(akActor)
    If ok
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("currency.campTurnedOnYou", ("" + akActor.GetDisplayName())))
    EndIf
    Return ok
EndFunction

Bool Function MusterCamp(Actor akActor)
    {The chief rallies the sworn camp as a war band (MusterCampById, the UI's path too). The
     YAML gates it to the leader; the store refuses a camp that is not sworn.}
    If !akActor
        Return false
    EndIf
    Int campId = SeverActionsNativeExt2.Camp_CampIdOf(akActor)
    If campId == 0
        Return false
    EndIf
    If !SeverActionsNativeExt2.Camp_SetMustered(campId, true)
        Return false
    EndIf
    MusterCampById(campId)
    Return true
EndFunction

Bool Function SendCampHome(Actor akActor)
    {The chief dismisses the war band (SendCampHomeById).}
    If !akActor
        Return false
    EndIf
    Int campId = SeverActionsNativeExt2.Camp_CampIdOf(akActor)
    If campId == 0
        Return false
    EndIf
    SeverActionsNativeExt2.Camp_SetMustered(campId, false)
    SendCampHomeById(campId)
    Return true
EndFunction

Bool Function CollectFromRetainer(Actor akActor)
    {Collect the retainer's pending payout in person, which (unlike the board's button) also
     takes a defiant Tribute retainer's withheld coin and ends the standoff. A steward hands
     over the hold vault too.}
    If !akActor
        Return false
    EndIf
    SeverActionsNativeExt2.Venture_CollectInPerson(akActor)
    If SeverActionsNativeExt2.Steward_HoldNameOf(akActor) != ""
        Int vault = SeverActionsNativeExt2.Steward_Collect(akActor)
        If vault > 0
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("currency.handsOverHoldVault", ("" + akActor.GetDisplayName()), ("" + vault)))
        EndIf
    EndIf
    Return true
EndFunction

Bool Function HireSteward(Actor akActor, Int aiWeeklyWage = 100)
    {Appoint the speaker-retainer steward of their hold: from the next settle the hold's
     retainers pay into the steward's vault. The steward is paid by keeping kStewardCutPct of
     each sweep; aiWeeklyWage is stored but no longer drives pay. Fails if the seat is taken
     or the speaker is not a retainer.}
    If !akActor
        Return false
    EndIf
    If aiWeeklyWage <= 0
        aiWeeklyWage = 100
    EndIf
    String holdName = SeverActionsNativeExt2.Steward_Appoint(akActor, aiWeeklyWage)
    If holdName == ""
        Return false
    EndIf
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("currency.nowStewards", ("" + akActor.GetDisplayName()), holdName))
    Return true
EndFunction

Bool Function DismissSteward(Actor akActor)
    {End the speaker's stewardship: the vault goes to the player now and the hold's retainers
     hold their own takings again. They stay a retainer.}
    If !akActor
        Return false
    EndIf
    String holdName = SeverActionsNativeExt2.Steward_HoldNameOf(akActor)
    If holdName == ""
        Return false
    EndIf
    Int remainder = SeverActionsNativeExt2.Steward_Dismiss(akActor)
    If remainder > 0
        Debug.Notification(akActor.GetDisplayName() + " steps down as steward of " + holdName + " and hands back " + remainder + " gold.")
    Else
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("currency.stepsDownAsSteward", ("" + akActor.GetDisplayName()), ("" + holdName)))
    EndIf
    Return true
EndFunction

Bool Function CollectFromSteward(Actor akActor)
    {Collect the hold vault from the steward. Their own retainer payout is separate
     (CollectFromRetainer takes both).}
    If !akActor
        Return false
    EndIf
    String holdName = SeverActionsNativeExt2.Steward_HoldNameOf(akActor)
    If holdName == ""
        Return false
    EndIf
    Int vault = SeverActionsNativeExt2.Steward_Collect(akActor)
    If vault > 0
        Debug.Notification(akActor.GetDisplayName() + " hands over " + holdName + "'s takings: " + vault + " gold.")
    Else
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("currency.vaultEmptyThisWeek", ("" + holdName)))
    EndIf
    Return true
EndFunction

Bool Function PayArrears(Actor akActor)
    {Pay the back-wages the player owes this retainer, from the player's gold.}
    If !akActor
        Return false
    EndIf
    SeverActionsNativeExt2.Venture_PayArrears(akActor)
    Return true
EndFunction

Bool Function DismissRetainer(Actor akActor)
    {End the speaker-retainer's service amicably.}
    If !akActor
        Return false
    EndIf
    Return SeverActionsNativeExt2.Venture_Dismiss(akActor)
EndFunction

Bool Function GrantLoan(Actor akActor)
    {Lend the retainer what they asked: the gold leaves the player now, a DebtStore entry backs
     it, and repayment comes from the retainer's own weekly take, never the player's cut.
     No-op if the ask was already answered or the player cannot cover it.}
    If !akActor
        Return false
    EndIf
    SeverActionsNativeExt2.Venture_GrantLoan(akActor)
    Return true
EndFunction

Bool Function RefuseLoan(Actor akActor)
    {Refuse the retainer's loan request: costs loyalty and puts the ask on a cooldown.}
    If !akActor
        Return false
    EndIf
    SeverActionsNativeExt2.Venture_RefuseLoan(akActor)
    Return true
EndFunction

Bool Function ForgiveLoan(Actor akActor)
    {Write off the retainer's loan: clears the balance and its DebtStore entry, and buys
     loyalty. Works on a defaulted loan too.}
    If !akActor
        Return false
    EndIf
    SeverActionsNativeExt2.Venture_ForgiveLoan(akActor)
    Return true
EndFunction

Bool Function ReassureRetainer(Actor akActor)
    {Temper hearing success. Consensual terms: morale lift, withdraws a standing notice;
     coerced terms: cows them for one settle, no morale repair. Resolves an armed Send-Word
     meeting; also callable in plain conversation (a native cooldown limits it).}
    If !akActor
        Return false
    EndIf
    SeverActionsNativeExt2.Venture_Reassure(akActor)
    Return true
EndFunction

Bool Function GrantTaxRelief(Actor akActor)
    {The jarl eases their hold's enterprise tax by 5 points (the total adjustment is clamped
     natively).}
    If !akActor
        Return false
    EndIf
    Int newRate = SeverActionsNativeExt2.Venture_AdjustHoldTaxForJarl(akActor, -5)
    If newRate < 0
        Return false
    EndIf
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("currency.easesHoldTax", ("" + akActor.GetDisplayName()), ("" + newRate)))
    Return true
EndFunction

Bool Function RaiseHoldTaxes(Actor akActor)
    {The jarl raises their hold's enterprise tax by 5 points.}
    If !akActor
        Return false
    EndIf
    Int newRate = SeverActionsNativeExt2.Venture_AdjustHoldTaxForJarl(akActor, 5)
    If newRate < 0
        Return false
    EndIf
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("currency.raisesHoldTax", ("" + akActor.GetDisplayName()), ("" + newRate)))
    Return true
EndFunction

Bool Function CollectAuthorizedTaxes(Actor akActor)
    {Final Audit: the player agreed to pay. The full sum leaves their purse, the audit latches
     PAID (terminal) and the detail walks home. Also the enterprises provider's
     collectAuthorizedTaxes service (Currency's CollectPayment).}
    If !akActor || !SeverActionsNativeExt2.Venture_Audit_IsCollector(akActor)
        Return false
    EndIf
    Int demand = SeverActionsNativeExt2.Venture_Audit_Demand()
    Actor player = Game.GetPlayer()
    If player.GetGoldAmount() < demand
        SkyrimNetApi.RegisterEvent("final_audit_short",             player.GetDisplayName() + " agreed to pay but cannot produce the full " + demand + " septims the Treasury has assessed. " + akActor.GetDisplayName() + " notes the shortfall without surprise - the demand stands, in full, and the detail is not leaving.",             akActor, None)
        Return false
    EndIf
    If !SeverActionsNativeExt2.Venture_Audit_Collect()
        Return false
    EndIf
    MiscObject gold = _Gold()
    If !gold
        Debug.Trace("[SeverActions] Final Audit: Gold001 unresolved - payment aborted")
        Return false
    EndIf
    player.RemoveItem(gold, demand, false)
    SkyrimNetApi.RegisterEvent("final_audit_paid",         player.GetDisplayName() + " paid the Imperial Treasury " + demand + " septims in back-taxes. " + akActor.GetDisplayName() + " records the sum, thanks them for their compliance, and the Final Audit withdraws toward the Blue Palace in Solitude - the ledger balanced, the debt closed for good.",         akActor, None)
    Return true
EndFunction

Bool Function PressTheDemand(Actor akActor)
    {Final Audit refusal: the audit latches REFUSED (terminal) and the trio attack (StartCombat,
     so the engine runs a normal fight). The twelve take no part.}
    If !akActor || !SeverActionsNativeExt2.Venture_Audit_IsCollector(akActor)
        Return false
    EndIf
    If !SeverActionsNativeExt2.Venture_Audit_Refuse()
        Return false
    EndIf
    Actor player = Game.GetPlayer()
    Int i = 0
    Int detail = FinalAuditEscortSize()
    While i < detail
        Actor collector = SeverActionsNativeExt2.Venture_Audit_Collector(i)
        If collector && !collector.IsDead()
            collector.StartCombat(player)
        EndIf
        i += 1
    EndWhile
    Return true
EndFunction

Bool Function BrushOffRetainer(Actor akActor)
    {Temper hearing failure: morale drops hard, an aggrieved consensual retainer gives notice,
     a Tribute retainer turns defiant. Resolves the armed meeting.}
    If !akActor
        Return false
    EndIf
    SeverActionsNativeExt2.Venture_BrushOff(akActor)
    Return true
EndFunction

Bool Function NegotiateTerms(Actor akActor)
    {Split a pending raise ask down the middle: a smaller loyalty/morale bump than a full
     grant, and the ask clears. No-op with nothing pending; consumes an armed hearing like
     GrantRetainerRaise.}
    If !akActor
        Return false
    EndIf
    SeverActionsNativeExt2.Venture_NegotiateRaise(akActor)
    Return true
EndFunction

Bool Function GrantRetainerRaise(Actor akActor)
    {Raise the retainer's pay or ease coerced terms: grants the pending ask, re-grants refused
     terms or applies a standard raise (skim stops, morale up, notice withdrawn). Consumes an
     armed hearing. Not for Enslaved (no wage or cut to move).}
    If !akActor
        Return false
    EndIf
    SeverActionsNativeExt2.Venture_GrantRaiseInPerson(akActor)
    Return true
EndFunction

; ===== Steward visits and the Final Audit's walk (ai_docs/STEWARD_VISITS.md) =====
; Native decides who and when and owns the cosaved state (VSTR v6); this script owns every
; package touch. Both journeys ride the orchestrator, and OnTravelComplete reports each leg.

Event OnStewardVisitTravel(String eventName, String strArg, Float numArg, Form sender)
    {sender = the steward; strArg = the retainer's FormID as signed decimal (a float numArg
     is exact only to 2^24). Starts the walk out to the retainer.}
    Actor steward = sender as Actor
    Actor target = Game.GetFormEx(strArg as Int) as Actor
    If !steward || !target
        Debug.Trace("[SeverActions_Enterprises] steward visit: steward or retainer did not resolve")
        Return
    EndIf
    _DisengageForTravel(steward, "StewardVisit")
    ; The destination is the retainer's ref, re-read each tick, so the walk tracks a moving
    ; person. Quiet: the player never ordered this errand.
    Int handle = SeverActionsNativeExt.Travel_Begin(steward, target, _TravelKW(), \
        ARRIVAL_DISTANCE, "stewardvisit", TRAVEL_OPTIONS_QUIETLONG, 0, SPEED_WALK)
    If handle <= 0
        ; Report the failed leg now, or the seat sits in Traveling until its backstop expires.
        Debug.Trace("[SeverActions_Enterprises] steward visit: Travel_Begin refused for " + steward.GetDisplayName())
        SeverActionsNativeExt2.Steward_VisitLegDone(steward, false)
        Return
    EndIf
    ; Pool-exhaustion fallback only: with a Traveler_NN slot the alias package drives the
    ; walk, and an override would compete with it.
    Package travelPkg = SeverActionsNativeExt.Travel_GetSpeedPackage(SPEED_WALK)
    If travelPkg != None && !SeverActionsNativeExt2.Travel_HasAlias(handle)
        ActorUtil.AddPackageOverride(steward, travelPkg, TRAVEL_PACKAGE_PRIORITY, 1)
        steward.EvaluatePackage()
    EndIf
    ; A long walk spans many 5s orphan-scan windows; with orphanCleanupEnabled on, the scanner
    ; strips an unregistered traveler's travel link and package mid-journey.
    SeverActionsNative.OrphanCleanup_RegisterTraveler(steward)
    DebugMsg("StewardVisit: " + steward.GetDisplayName() + " is walking out to " + target.GetDisplayName())
EndEvent

Event OnStewardVisitArrived(String eventName, String strArg, Float numArg, Form sender)
    {The steward reached the retainer (args as OnStewardVisitTravel): post them on that person.}
    Actor steward = sender as Actor
    Actor target = Game.GetFormEx(strArg as Int) as Actor
    If !steward || !target
        Return
    EndIf
    PostStewardVisit(steward, target)
EndEvent

Function PostStewardVisit(Actor akSteward, Actor akTarget)
    {Anchor the steward to the retainer (WorkAnchorKeyword 0x165675) and sandbox them around
     that person; idempotent. The keyword is the steward's own workplace link, so this
     clobbers it: EndStewardVisit must restore it from Native_GetWorkLoc.}
    Package sandboxPkg = Game.GetFormFromFile(0x00165676, "SeverActions.esp") as Package
    Keyword anchorKw = Game.GetFormFromFile(0x00165675, "SeverActions.esp") as Keyword
    If !sandboxPkg || !anchorKw
        Debug.Trace("[SeverActions_Enterprises] steward visit: WorkSandbox package/keyword missing - run GenerateWorkSandbox.pas")
        Return
    EndIf
    ; The leg is over: stop tracking them as a traveler and drop any fallback travel
    ; override, which would compete with the sandbox. Quietly - it was never announced.
    SeverActionsNative.OrphanCleanup_UnregisterTraveler(akSteward)
    _ClearTravelQuietly(akSteward)
    ; Permanent, like the workplace link it stands in for: PackageManager's 30-day
    ; prune and LinkedRef_ClearAll both leave it.
    SeverActionsNativeExt.LinkedRef_SetPermanent(akSteward, akTarget, anchorKw)
    ActorUtil.AddPackageOverride(akSteward, sandboxPkg, STEWARD_VISIT_PRIORITY, 1)
    akSteward.EvaluatePackage()
    DebugMsg("StewardVisit: " + akSteward.GetDisplayName() + " is now keeping company with " + akTarget.GetDisplayName())
EndFunction

Event OnStewardVisitEnd(String eventName, String strArg, Float numArg, Form sender)
    {The visit is over (dwell elapsed, the retainer left the books, the seat was vacated, the
     journey was lost): hand the steward back to their own schedule.}
    Actor steward = sender as Actor
    If steward
        EndStewardVisit(steward)
    EndIf
EndEvent

Function EndStewardVisit(Actor akSteward)
    {Undo PostStewardVisit. Idempotent, and safe on a steward still mid-journey.}
    Package sandboxPkg = Game.GetFormFromFile(0x00165676, "SeverActions.esp") as Package
    Keyword anchorKw = Game.GetFormFromFile(0x00165675, "SeverActions.esp") as Keyword
    ; An end can land mid-walk (a lost completion, a dismissal, the retainer leaving).
    SeverActionsNativeExt.Travel_CancelByActor(akSteward)
    SeverActionsNative.OrphanCleanup_UnregisterTraveler(akSteward)
    _ClearTravelQuietly(akSteward)
    If sandboxPkg
        ActorUtil.RemovePackageOverride(akSteward, sandboxPkg)
    EndIf
    If anchorKw
        ; Restore the work anchor, never just clear it, or the steward's work sandbox has no
        ; target and they never return to their post.
        ObjectReference workMarker = SeverActionsNative.Native_GetWorkLoc(akSteward)
        If workMarker
            SeverActionsNativeExt.LinkedRef_SetPermanent(akSteward, workMarker, anchorKw)
        Else
            SeverActionsNative.LinkedRef_Clear(akSteward, anchorKw)
        EndIf
    EndIf
    akSteward.EvaluatePackage()
    DebugMsg("StewardVisit: " + akSteward.GetDisplayName() + " is released - back to their books")
EndFunction

Event OnFinalAuditTravel(String eventName, String strArg, Float numArg, Form sender)
    {Grace lapsed: the General (sender) walks from court to the player under the
     orchestrator (a Traveler_NN alias; the orchestrator authors his position while unloaded).
     Only he is steered: the Legates follow him, and native keeps them with him off-screen
     (Audit_KeepEscortWithLegate).}
    Actor legate = sender as Actor
    Actor player = Game.GetPlayer()
    If !legate || !player
        SeverActionsNativeExt2.Venture_Audit_TravelLegDone(false)
        Return
    EndIf
    _DisengageForTravel(legate, "FinalAudit")
    ; Drop the court sandbox first: anchored at court at priority 100, it walks him
    ; home once the travel package comes off. ApplyFinalAuditApproachPackages strips it
    ; too, but the walk must not depend on that event.
    Package courtPkg = Game.GetFormFromFile(0x00165676, "SeverActions.esp") as Package
    If courtPkg
        ActorUtil.RemovePackageOverride(legate, courtPkg)
    EndIf
    ; Quiet: no quest arrow gives the taxman away. Arrival radius: see AUDIT_FOLLOW_HANDOFF.
    Int handle = SeverActionsNativeExt.Travel_Begin(legate, player, _TravelKW(), \
        AUDIT_FOLLOW_HANDOFF, "finalaudit", TRAVEL_OPTIONS_QUIETLONG, 0, SPEED_JOG)
    If handle <= 0
        Debug.Trace("[SeverActions_Enterprises] Final Audit: Travel_Begin refused - native will stage instead")
        SeverActionsNativeExt2.Venture_Audit_TravelLegDone(false)
        Return
    EndIf
    ; Pool-exhaustion fallback only (see OnStewardVisitTravel).
    Package travelPkg = SeverActionsNativeExt.Travel_GetSpeedPackage(SPEED_JOG)
    If travelPkg != None && !SeverActionsNativeExt2.Travel_HasAlias(handle)
        ActorUtil.AddPackageOverride(legate, travelPkg, TRAVEL_PACKAGE_PRIORITY, 1)
        legate.EvaluatePackage()
    EndIf
    SeverActionsNative.OrphanCleanup_RegisterTraveler(legate)
    DebugMsg("FinalAudit: the General is on the road to the player")
EndEvent

Event OnFinalAuditTravelAbort(String eventName, String strArg, Float numArg, Form sender)
    {Native stops the walk (over its ceiling, or he reached the player early). The cancel's
     "cancelled" completion reaches OnTravelComplete as a failed leg, and native then stages
     the detail and sends the march.}
    Actor legate = sender as Actor
    If !legate
        Return
    EndIf
    SeverActionsNativeExt.Travel_CancelByActor(legate)
    SeverActionsNative.OrphanCleanup_UnregisterTraveler(legate)
    _ClearTravelQuietly(legate)
    legate.EvaluatePackage()
EndEvent

Event OnTravelComplete(String eventName, String strArg, Float numArg, Form sender)
    {The shared SeverActions_TravelComplete on its canonical callback (M-E): strArg =
     "<callbackTag>|<status>". Answers only this script's tags, stewardvisit and finalaudit;
     every other script on the form answers its own.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String tag = StringUtil.Substring(strArg, 0, pipePos)
    String status = StringUtil.Substring(strArg, pipePos + 1, 0)

    ; Only a real arrival posts the steward; any other status drops the visit.
    If tag == "stewardvisit"
        Actor stewardNpc = sender as Actor
        If stewardNpc
            SeverActionsNativeExt2.Steward_VisitLegDone(stewardNpc, status == "arrived")
            If status != "arrived"
                EndStewardVisit(stewardNpc)
            EndIf
        EndIf
        Return
    EndIf

    ; Native decides what the leg means: on arrival it fires SeverActions_FinalAuditApproach,
    ; on failure it stages the detail near the player.
    If tag == "finalaudit"
        Actor legateNpc = sender as Actor
        If legateNpc
            ; Every terminal status ends the journey: clear it quietly so nothing competes
            ; with the follow package native sends next.
            SeverActionsNative.OrphanCleanup_UnregisterTraveler(legateNpc)
            _ClearTravelQuietly(legateNpc)
        EndIf
        SeverActionsNativeExt2.Venture_Audit_TravelLegDone(status == "arrived")
        Return
    EndIf
EndEvent

Event OnVentureDeparted(String eventName, String strArg, Float numArg, Form sender)
    {A retainer left service (deserted, quit, escaped). strArg is the ready-made line; sender
     the ex-retainer, whose venture entry stays cosaved for sever_former_retainer and a re-hire.}
    If strArg != ""
        Debug.Notification(strArg)
    EndIf
EndEvent

; ===== Camp war-band muster =====
; Each living member of a mustered camp sits in the 200-alias follow pool (its packages
; re-apply on cell load) and is flagged a teammate. They are NOT companions: no
; FollowerDataStore row, and TeammateMonitor skips camp members so the flag never onboards
; them. Per member, StorageUtil SeverCamp_MusterAlias = pool index and SeverCamp_MusterETA =
; arrival game time (days); the camp's flag lives in CampStore. All of it rides the save.

Event OnCampMusterEvent(String eventName, String strArg, Float numArg, Form sender)
    Int campId = strArg as Int
    If campId == 0
        Return
    EndIf
    If numArg > 0.5
        MusterCampById(campId)
    Else
        SendCampHomeById(campId)
    EndIf
EndEvent

Function MusterCampById(Int aiCampId)
    {Rally every living member (_MusterOne): nearby ones walk over, distant ones set out and
     arrive after a distance-based travel time (the pump). Temporary refs leave the form map
     while their cell is detached, so a remote muster reaches only who resolves;
     OnCampMemberSeen adopts the rest, and the notification says so.}
    Actor player = Game.GetPlayer()
    Actor[] members = SeverActionsNativeExt2.Camp_GetMembers(aiCampId)
    Int enroute = 0
    Int i = 0
    While i < members.Length
        If _MusterOne(members[i], player) == 1
            enroute += 1
        EndIf
        i += 1
    EndWhile
    Int roster = SeverActionsNativeExt2.Camp_RosterCount(aiCampId)
    If roster > members.Length
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("follow.wordGoesOutThose"))
    ElseIf enroute > 0
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("follow.wordGoesOutThe"))
    Else
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("follow.theCampMustersTo"))
    EndIf
    RegisterForSingleUpdateGameTime(0.1)
    Debug.Trace("[SeverActions_Enterprises] MusterCampById " + aiCampId + ": reached " + members.Length + " of roster " + roster + " (" + enroute + " en route)")
    SkyrimNetApi.RegisterEvent("camp_mustered", "The sworn camp rallies to " + player.GetDisplayName() + "'s side as a war band - those nearby fall in at once, the rest are on their way", player, None)
EndFunction

Int Function _MusterOne(Actor m, Actor akPlayer)
    {Seat one member in the war band: pool alias, teammate flag, then walk over or set out with
     an ETA. Idempotent. Returns -1 skipped (confirmed dead, a real companion, pool exhausted),
     0 fell in nearby, 1 set out.}
    ; IsDead() is trusted only on a loaded actor (it can false-report on unloaded ones).
    If !m || (m.IsDead() && m.Is3DLoaded())
        Return -1
    EndIf
    ; A real companion keeps their own seat.
    If SeverActionsNativeExt.Native_GetFollowAliasIndex(m) >= 0
        Return -1
    EndIf
    Int held = StorageUtil.GetIntValue(m, "SeverCamp_MusterAlias", -1)
    Bool needSeat = true
    If held >= 0
        ReferenceAlias heldAl = _FollowAlias(held)
        If heldAl && heldAl.GetReference() == m
            needSeat = false
        Else
            StorageUtil.UnsetIntValue(m, "SeverCamp_MusterAlias")
        EndIf
    EndIf
    If needSeat
        Int idx = SeverActionsNativeExt2.FollowPool_Claim(m, "camp")
        If idx < 0
            ; No alias means no follow package, and a teammate flag alone would only
            ; make them drift. Leave them untouched.
            Debug.Trace("[SeverActions_Enterprises] Muster: follow pool exhausted - " + m.GetDisplayName() + " left behind")
            Return -1
        EndIf
        ReferenceAlias al = _FollowAlias(idx)
        If !al
            SeverActionsNativeExt2.FollowPool_Release(idx)
            Return -1
        EndIf
        al.ForceRefTo(m)
        StorageUtil.SetIntValue(m, "SeverCamp_MusterAlias", idx)
    EndIf
    m.SetPlayerTeammate(true, true)
    ; Stray hits from the player and the party pass over them while mustered (FollowerProtection).
    m.IgnoreFriendlyHits(true)
    If m.Is3DLoaded() && m.GetDistance(akPlayer) <= 4000.0
        ; Close: the pool package walks them over.
        m.EvaluatePackage()
        Return 0
    EndIf
    ; Far or unloaded: they set out, and the pump completes the arrival when the ETA lapses.
    Float hrs = SeverActionsNativeExt2.Camp_TravelHoursTo(m)
    StorageUtil.SetFloatValue(m, "SeverCamp_MusterETA", Utility.GetCurrentGameTime() + (hrs / 24.0))
    m.EvaluatePackage()
    Debug.Trace("[SeverActions_Enterprises] Muster: " + m.GetDisplayName() + " sets out - ETA " + hrs + "h")
    Return 1
EndFunction

Function SendCampHomeById(Int aiCampId)
    {Dismiss the war band: clear the seats and send everyone to the camp's map marker. Also
     sweeps the pool for seats the roster no longer covers (the death sink prunes the roster,
     not the pool, so a member who died mid-raid still holds one).}
    Actor player = Game.GetPlayer()
    ObjectReference home = SeverActionsNativeExt2.Camp_HomeMarker(aiCampId)
    If !home
        Debug.Trace("[SeverActions_Enterprises] SendCampHomeById " + aiCampId + ": no map marker - band released in place")
    EndIf
    Actor[] members = SeverActionsNativeExt2.Camp_GetMembers(aiCampId)
    Int cleared = 0
    Int i = 0
    While i < members.Length
        cleared += _UnmusterOne(members[i], home)
        i += 1
    EndWhile
    Int s = 0
    While s < FOLLOW_POOL_SIZE
        ReferenceAlias al = _FollowAlias(s)
        If al
            Actor holder = al.GetReference() as Actor
            If holder && StorageUtil.GetIntValue(holder, "SeverCamp_MusterAlias", -1) == s
                ; Only this camp's members move. Another camp's member keeps their seat whatever
                ; IsDead reads (only the death sink takes someone off their own camp's roster); a corpse already off
                ; every roster (a missed CampMemberDied relay) loses the seat and stays where it is.
                Int holderCamp = SeverActionsNativeExt2.Camp_CampIdOf(holder)
                If holderCamp == aiCampId
                    cleared += _UnmusterOne(holder, home)
                ElseIf holderCamp == 0 && holder.IsDead()
                    cleared += _UnmusterOne(holder, None)
                EndIf
            EndIf
        EndIf
        s += 1
    EndWhile
    Debug.Notification(SeverActionsNativeExt2.Native_L10n("follow.theWarBandReturns"))
    Debug.Trace("[SeverActions_Enterprises] SendCampHomeById " + aiCampId + ": released " + cleared)
    SkyrimNetApi.RegisterEvent("camp_sent_home", "The war band is dismissed and returns to its camp", player, None)
EndFunction

Int Function _UnmusterOne(Actor akMember, ObjectReference akHome)
    {Clear one member's seat, teammate flag and ETA, and send them home. Returns 1 only when
     there was a seat to clear. An en-route member never really left camp, so clearing the
     ETA is their trip cancellation.}
    If !akMember
        Return 0
    EndIf
    Int held = StorageUtil.GetIntValue(akMember, "SeverCamp_MusterAlias", -1)
    If held < 0
        Return 0
    EndIf
    ReferenceAlias al = _FollowAlias(held)
    If al && al.GetReference() == akMember
        al.Clear()
        SeverActionsNativeExt2.FollowPool_Release(held)
    EndIf
    StorageUtil.UnsetIntValue(akMember, "SeverCamp_MusterAlias")
    StorageUtil.UnsetFloatValue(akMember, "SeverCamp_MusterETA")
    akMember.SetPlayerTeammate(false)
    If !SeverActionsNativeExt.Native_GetIsFollower(akMember)
        akMember.IgnoreFriendlyHits(false)
    EndIf
    If !(akMember.IsDead() && akMember.Is3DLoaded())
        If akHome
            akMember.MoveTo(akHome)
        EndIf
        akMember.EvaluatePackage()
    EndIf
    Return 1
EndFunction

Event OnCampMemberSeen(String eventName, String strArg, Float numArg, Form sender)
    {A sworn camp member became resolvable again. If their camp is mustered, adopt them into
     the war band a remote muster could not reach. (Persistence seating is native:
     CampStore::SeatInPersistPool.)}
    Actor m = sender as Actor
    If !m
        Debug.Trace("[SeverActions_Enterprises] MemberSeen: sender resolved to None - dropped")
        Return
    EndIf
    Int cid = SeverActionsNativeExt2.Camp_CampIdOf(m)
    If cid == 0 || !SeverActionsNativeExt2.Camp_IsSworn(cid)
        Debug.Trace("[SeverActions_Enterprises] MemberSeen: " + m.GetDisplayName() + " bailed (campId " + cid + ", sworn " + SeverActionsNativeExt2.Camp_IsSworn(cid) + ")")
        Return
    EndIf
    Debug.Trace("[SeverActions_Enterprises] MemberSeen: " + m.GetDisplayName() + " (camp " + cid + ")")
    If SeverActionsNativeExt2.Camp_IsMustered(cid)
        If _MusterOne(m, Game.GetPlayer()) >= 0
            RegisterForSingleUpdateGameTime(0.1)
            Debug.Trace("[SeverActions_Enterprises] Muster adopt: " + m.GetDisplayName() + " joins the war band")
        EndIf
    EndIf
EndEvent

Event OnCampMemberDied(String eventName, String strArg, Float numArg, Form sender)
    {Death relay: free the corpse's persistence and muster aliases (a corpse held persistent
     is save bloat).}
    Actor m = sender as Actor
    If !m
        Return
    EndIf
    _UnpersistOne(m)
    Int held = StorageUtil.GetIntValue(m, "SeverCamp_MusterAlias", -1)
    If held >= 0
        ReferenceAlias al = _FollowAlias(held)
        If al && al.GetReference() == m
            al.Clear()
            SeverActionsNativeExt2.FollowPool_Release(held)
        EndIf
        StorageUtil.UnsetIntValue(m, "SeverCamp_MusterAlias")
        StorageUtil.UnsetFloatValue(m, "SeverCamp_MusterETA")
        m.SetPlayerTeammate(false)
    EndIf
EndEvent

Event OnCampReleased(String eventName, String strArg, Float numArg, Form sender)
    {A camp was released or renounced: sweep the persistence pool.}
    SweepCampPersistPool()
EndEvent

; Muster pump
; A game-time update every 0.1 game hours (about 18 real seconds at timescale 20) for the
; muster's whole life. Per seated member:
;   1. En route (ETA set): the arrival MoveTo once the ETA lapses.
;   2. Arrived: catch-up. Without a FollowerDataStore row CellCatchup ignores them, and the
;      follow package alone never bridges a fast travel, so an UNLOADED member is brought to
;      the player (a loaded one is never snapped in view).
; Game-time updates fire right after a time skip (fast travel included), so the band
; regroups when the player lands.

Event OnUpdateGameTime()
    If _PumpMusterArrivals() > 0
        RegisterForSingleUpdateGameTime(0.1)
    EndIf
EndEvent

Int Function _PumpMusterArrivals()
    {One pump pass. Returns how many living seated members it still watches (0 = stop until
     the next muster or load).}
    Actor player = Game.GetPlayer()
    Float now = Utility.GetCurrentGameTime()
    Int watched = 0
    Int arrived = 0
    Int gathered = 0
    Int s = 0
    While s < FOLLOW_POOL_SIZE
        ReferenceAlias al = _FollowAlias(s)
        If al
            Actor holder = al.GetReference() as Actor
            If holder && StorageUtil.GetIntValue(holder, "SeverCamp_MusterAlias", -1) == s
                If holder.IsDead() && holder.Is3DLoaded()
                    ; A confirmed corpse keeps its seat until freed elsewhere; drop its trip.
                    StorageUtil.UnsetFloatValue(holder, "SeverCamp_MusterETA")
                ElseIf SeverActionsNativeExt2.Travel_GetPhaseByActor(holder) > 0
                    ; Sent on a journey: never moved during it; still watched, so the
                    ; catch-up resumes once it ends.
                    watched += 1
                Else
                    watched += 1
                    Float eta = StorageUtil.GetFloatValue(holder, "SeverCamp_MusterETA", 0.0)
                    If eta > 0.0
                        If holder.Is3DLoaded() && holder.GetDistance(player) <= 4000.0
                            ; Already near the player: the trip resolves with no placement.
                            StorageUtil.UnsetFloatValue(holder, "SeverCamp_MusterETA")
                            holder.EvaluatePackage()
                        ElseIf now >= eta
                            ; ETA lapsed off-screen: the arrival.
                            StorageUtil.UnsetFloatValue(holder, "SeverCamp_MusterETA")
                            holder.MoveTo(player)
                            holder.EvaluatePackage()
                            arrived += 1
                        EndIf
                    ElseIf !holder.Is3DLoaded()
                        ; Arrived but left behind and unloaded: catch up silently, like a
                        ; vanilla follower.
                        holder.MoveTo(player)
                        holder.EvaluatePackage()
                        gathered += 1
                    EndIf
                EndIf
            EndIf
        EndIf
        s += 1
    EndWhile
    If arrived == 1
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("follow.oneOfYourWar"))
    ElseIf arrived > 1
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("follow.ofYourWarBandArrive", ("" + arrived)))
    EndIf
    If gathered > 0
        Debug.Trace("[SeverActions_Enterprises] Muster pump: gathered " + gathered + " war-band member(s) back to the player")
    EndIf
    Return watched
EndFunction

; ===== Camp and retainer persistence pools: the free side =====

Quest Function GetCampPersistQuest()
    {Lazy-resolves the 300-alias camp persistence quest, retried each call until it resolves.
     None on an ESP without it: persistence no-ops, every other camp feature works.}
    If _campPersistResolved
        Return _campPersistQuest
    EndIf
    _campPersistQuest = Game.GetFormFromFile(CAMP_PERSIST_QUEST_FORMID, "SeverActions.esp") as Quest
    If !_campPersistQuest
        If !_campPersistMissingWarned
            _campPersistMissingWarned = true
            Debug.Trace("[SeverActions_Enterprises] CampPersist quest 0x16A793 DID NOT RESOLVE - ESP predates GenerateCampPersistQuest.pas (or wrong ESP is winning). Persistence seating disabled this session.")
        EndIf
        Return None
    EndIf
    ; A save can hold a failed start-game-enabled start (an older ESP's aliases were not
    ; Optional); start it now.
    If !_campPersistQuest.IsRunning()
        Bool started = _campPersistQuest.Start()
        Debug.Trace("[SeverActions_Enterprises] CampPersist quest was not running - Start() -> " + started)
    EndIf
    _campPersistResolved = true
    Return _campPersistQuest
EndFunction

ReferenceAlias Function GetCampPersistAlias(Int aiIndex)
    If aiIndex < 0 || aiIndex >= CAMP_PERSIST_POOL_SIZE
        Return None
    EndIf
    Quest pool = GetCampPersistQuest()
    If !pool
        Return None
    EndIf
    Return pool.GetNthAlias(aiIndex) as ReferenceAlias
EndFunction

Function _UnpersistOne(Actor akMember)
    {Free one member's persistence alias by holder scan (native seating keeps no index).
     Safe on non-holders; also clears the legacy SeverCamp_PersistAlias key.}
    If !akMember
        Return
    EndIf
    StorageUtil.UnsetIntValue(akMember, "SeverCamp_PersistAlias")
    If GetCampPersistQuest() == None
        Return
    EndIf
    Int s = 0
    While s < CAMP_PERSIST_POOL_SIZE
        ReferenceAlias al = GetCampPersistAlias(s)
        If al && al.GetReference() == akMember
            al.Clear()
            Return
        EndIf
        s += 1
    EndWhile
EndFunction

Function SweepCampPersistPool()
    {Free every persistence alias whose holder is no longer a sworn camp member, or is a
     confirmed (loaded) corpse. Runs on load and on SeverActions_CampReleased.}
    If GetCampPersistQuest() == None
        Return
    EndIf
    Int freed = 0
    Int s = 0
    While s < CAMP_PERSIST_POOL_SIZE
        ReferenceAlias al = GetCampPersistAlias(s)
        If al
            Actor holder = al.GetReference() as Actor
            If holder
                Int cid = SeverActionsNativeExt2.Camp_CampIdOf(holder)
                Bool keep = cid != 0 && SeverActionsNativeExt2.Camp_IsSworn(cid)
                If keep && holder.IsDead() && holder.Is3DLoaded()
                    keep = false
                EndIf
                If !keep
                    StorageUtil.UnsetIntValue(holder, "SeverCamp_PersistAlias")
                    al.Clear()
                    freed += 1
                EndIf
            EndIf
        EndIf
        s += 1
    EndWhile
    If freed > 0
        Debug.Trace("[SeverActions_Enterprises] CampPersist sweep: freed " + freed + " alias(es)")
    EndIf
EndFunction

Quest Function GetRetainerPersistQuest()
    {Lazy-resolves the 500-alias retainer persistence quest (as GetCampPersistQuest). None on
     an ESP without it: freeing no-ops, every other retainer feature works.}
    If _retainerPersistResolved
        Return _retainerPersistQuest
    EndIf
    _retainerPersistQuest = Game.GetFormFromFile(RETAINER_PERSIST_QUEST_FORMID, "SeverActions.esp") as Quest
    If !_retainerPersistQuest
        If !_retainerPersistMissingWarned
            _retainerPersistMissingWarned = true
            Debug.Trace("[SeverActions_Enterprises] RetainerPersist quest 0x16B000 DID NOT RESOLVE - ESP predates GenerateRetainerPersistQuest.pas. Retainer un-persist disabled this session.")
        EndIf
        Return None
    EndIf
    If !_retainerPersistQuest.IsRunning()
        Bool started = _retainerPersistQuest.Start()
        Debug.Trace("[SeverActions_Enterprises] RetainerPersist quest was not running - Start() -> " + started)
    EndIf
    _retainerPersistResolved = true
    Return _retainerPersistQuest
EndFunction

ReferenceAlias Function GetRetainerPersistAlias(Int aiIndex)
    If aiIndex < 0 || aiIndex >= RETAINER_PERSIST_POOL_SIZE
        Return None
    EndIf
    Quest pool = GetRetainerPersistQuest()
    If !pool
        Return None
    EndIf
    Return pool.GetNthAlias(aiIndex) as ReferenceAlias
EndFunction

Function _UnpersistOneRetainer(Actor akRetainer)
    {Free one retainer's persistence alias by holder scan. Safe on non-holders.}
    If !akRetainer || GetRetainerPersistQuest() == None
        Return
    EndIf
    Int s = 0
    While s < RETAINER_PERSIST_POOL_SIZE
        ReferenceAlias al = GetRetainerPersistAlias(s)
        If al && al.GetReference() == akRetainer
            al.Clear()
            Return
        EndIf
        s += 1
    EndWhile
EndFunction

Function SweepRetainerPersistPool()
    {Free every persistence alias whose holder is no longer an active retainer. Runs on load;
     mid-session frees come from the SeverActions_RetainerUnpersist ping.}
    If GetRetainerPersistQuest() == None
        Return
    EndIf
    Int freed = 0
    Int s = 0
    While s < RETAINER_PERSIST_POOL_SIZE
        ReferenceAlias al = GetRetainerPersistAlias(s)
        If al
            Actor holder = al.GetReference() as Actor
            If holder && !SeverActionsNativeExt2.Venture_IsActiveRetainer(holder)
                al.Clear()
                freed += 1
            EndIf
        EndIf
        s += 1
    EndWhile
    If freed > 0
        Debug.Trace("[SeverActions_Enterprises] RetainerPersist sweep: freed " + freed + " alias(es)")
    EndIf
EndFunction

Event OnRetainerUnpersist(String eventName, String strArg, Float numArg, Form sender)
    {Native's per-holder ping off the venture heartbeat when a retainer left service: free
     their persistence alias. Idempotent.}
    _UnpersistOneRetainer(sender as Actor)
EndEvent

; ===== The assign-retainer popup and the premises =====

Event OnRetainerWorkLoc(string eventName, string strArg, float numArg, Form sender)
    {The assign / manage popup's confirm; a cancel fires nothing, and the hire itself is
     native. strArg = "here" | "named|<placeName>" | "clear" | "guard|<hexFormId>[|<name>]".}
    Actor npc = sender as Actor
    If !npc
        Return
    EndIf
    SeverActions_FollowerManager fm = _FM()
    If !fm
        Return
    EndIf
    ; "clear" (the manage modal's Leave them be): the retainer reverts to their own AI.
    If strArg == "clear"
        fm.ClearRoutineLoc(npc, "work")
        Return
    EndIf
    ; "guard|...": the protectee is the work target. The FormID can go stale after a
    ; load-order shuffle, so fall back to the display name.
    If StringUtil.Find(strArg, "guard|") == 0
        String rest = StringUtil.Substring(strArg, 6)
        String hexId = rest
        String targetName = ""
        Int nameBar = StringUtil.Find(rest, "|")
        If nameBar >= 0
            hexId = StringUtil.Substring(rest, 0, nameBar)
            targetName = StringUtil.Substring(rest, nameBar + 1)
        EndIf
        Actor protectee = Game.GetFormEx(SeverActionsNative.HexToInt(hexId)) as Actor
        If !protectee && targetName != ""
            protectee = SeverActionsNative.FindActorByName(targetName)
            If protectee
                DebugMsg("OnRetainerWorkLoc: guard FormID '" + hexId + "' stale — resolved '" + targetName + "' by name instead")
            EndIf
        EndIf
        If protectee
            fm.GuardNPC(npc, protectee)
        Else
            DebugMsg("OnRetainerWorkLoc: guard target did not resolve from '" + strArg + "'")
        EndIf
        Return
    EndIf
    ObjectReference dest = None
    String placeLabel = ""
    Int bar = StringUtil.Find(strArg, "|")
    If bar >= 0
        placeLabel = StringUtil.Substring(strArg, bar + 1)
        If placeLabel != "" && SeverActionsNative.IsLocationResolverReady()
            dest = SeverActionsNative.ResolveDestination(npc, placeLabel)
        EndIf
    EndIf
    fm.SetRoutineLocHere(npc, "work", dest, placeLabel)
    fm.FireWorkAssignedEvent(npc)
    DebugMsg("OnRetainerWorkLoc: placed work marker for " + npc.GetDisplayName() + " (" + strArg + ")")
EndEvent

Function SyncAllPremisesFromWork()
    {Re-derive every tracked worker's venture premises from their work marker's cell (no-op for
     non-retainers and unchanged premises). The two worker lists and the work-marker key are
     FollowerManager's (sharedKeys rows in fomod/modules.json).}
    Int synced = 0
    Int li = 0
    While li < 2
        String listKey = "SeverActions_HomedNPCs"
        If li == 1
            listKey = "SeverActions_WorkOnlyNPCs"
        EndIf
        Int n = StorageUtil.FormListCount(None, listKey)
        Int i = 0
        While i < n
            Actor npc = StorageUtil.FormListGet(None, listKey, i) as Actor
            If npc
                ObjectReference wm = StorageUtil.GetFormValue(npc, "SeverActions_WorkMarkerRef") as ObjectReference
                If SeverActionsNativeExt2.Venture_SyncPremisesFromWork(npc, wm)
                    synced += 1
                EndIf
            EndIf
            i += 1
        EndWhile
        li += 1
    EndWhile
    If synced > 0
        Debug.Trace("[SeverActions_Enterprises] Premises re-derived for " + synced + " retainer(s) from their work markers")
    EndIf
EndFunction
