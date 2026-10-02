Scriptname SeverActions_NFFLib Hidden
{The NFF support library (M-L, D42): the only script naming an NFF type (nwsFollowerControllerScript, the
 controller quest 0x0000434F of nwsFollowerFramework.esp; DR2). Unattached, Global-only (bundle fwlib).
 Public functions take and return only vanilla or SA types (N2); callers make static calls only.
 Without NFF the whole class is dead on the stock VM (F32) and each call logs link errors, so EVERY call into
 it is gated by SeverActionsNativeExt2.Native_IsNFFInstalled() on the same line or the If directly above
 (check 6, trap nfflib-ungated). FrameworkMode comes from the Settings Authority, never FollowerManager (R3).}

nwsFollowerControllerScript Function GetNFFController() Global
    {NFF's controller quest cast to its script, or None without NFF. Internal: the only function returning the
     NFF type, so no caller outside this script holds one (N2). We route THROUGH NFF because it owns its
     followers by alias seat: changing their packages behind its back leaves them in neither roster.}
    If !SeverActionsNativeExt2.Native_IsNFFInstalled()
        Return None
    EndIf
    nwsFollowerControllerScript nff = Game.GetFormFromFile(0x0000434F, "nwsFollowerFramework.esp") as nwsFollowerControllerScript
    If !nff
        Debug.Trace("[SeverActions_NFFLib] NFF is installed but its controller quest did not resolve - falling back to SA handling")
    EndIf
    Return nff
EndFunction

Function _InvalidateTrackOnlyCache(Actor akActor) Global
    {No-op since P12-02 (FollowerManager's track-only memo is gone). Kept for its callers here and in
     SeverActions_Brawl.}
EndFunction

Bool Function NFFWait(Actor akActor) Global
    {Ask NFF to park one of ITS followers. TRUE when NFF handled it.}
    If !akActor || !SeverActionsNativeExt2.Native_IsNFFManaged(akActor)
        Return false
    EndIf
    nwsFollowerControllerScript nff = GetNFFController()
    If !nff
        Return false
    EndIf
    nff.FollowerWaitHere(akActor, 0, 0)
    Debug.Trace("[SeverActions_NFFLib] NFFWait: routed wait for " + akActor.GetDisplayName() + " through NFF")
    Return true
EndFunction

Bool Function NFFResume(Actor akActor) Global
    {Release one of NFF's followers from NFF's wait, the counterpart of NFFWait: clearing WaitingForPlayer does
     not reach NFF's packages, so wait and resume must stay symmetric. TRUE when NFF handled it.}
    If !akActor || !SeverActionsNativeExt2.Native_IsNFFManaged(akActor)
        Return false
    EndIf
    nwsFollowerControllerScript nff = GetNFFController()
    If !nff
        Return false
    EndIf
    nff.FollowerFollowMe(akActor, 0)
    Debug.Trace("[SeverActions_NFFLib] NFFResume: released " + akActor.GetDisplayName() + " from NFF's wait")
    Return true
EndFunction

Faction Function NFFSparFaction() Global
    {NFF's spar-exemption faction (nwsFF_SparFac): membership lets a follower fight while NFF's protection
     runs. None without NFF or on a build lacking the property; callers then use the dismiss route.}
    nwsFollowerControllerScript nff = GetNFFController()
    If !nff
        Return None
    EndIf
    Return nff.nwsFF_SparFac
EndFunction

Bool Function NFFDismiss(Actor akActor, Bool abSilent = false) Global
    {Ask NFF to dismiss one of ITS followers. TRUE when NFF handled it. abSilent passes (-1, 0), the pair NFF's
     own spar flow uses (nwsFollower_Sparring.SparPrep): no message, no goodbye line - for a transient release
     such as the brawl strip.}
    If !akActor || !SeverActionsNativeExt2.Native_IsNFFManaged(akActor)
        Return false
    EndIf
    nwsFollowerControllerScript nff = GetNFFController()
    If !nff
        Return false
    EndIf
    If abSilent
        nff.RemoveFollower(akActor, -1, 0)
    Else
        nff.RemoveFollower(akActor, 0, 1)
    EndIf
    _InvalidateTrackOnlyCache(akActor)
    Debug.Trace("[SeverActions_NFFLib] NFFDismiss: routed dismissal for " + akActor.GetDisplayName() + " through NFF")
    Return true
EndFunction

Bool Function NFFRecruit(Actor akActor) Global
    {Hand recruitment to NFF so it registers them as a real follower. TRUE when NFF handled it; FALSE in
     SeverActions mode for a new recruit, or for a DLC or custom-AI actor.}
    If !akActor || !SeverActionsNativeExt2.Native_IsNFFInstalled()
        Return false
    EndIf
    ; FrameworkMode 0 (SeverActions) keeps NEW recruits out of NFF; only Tracking (1) routes them through it.
    ; Two cases route regardless of mode: an actor NFF already seats (a vanilla "Follow me" recruit NFF took;
    ; going around that seat leaves them undismissable), and the brawl's one-shot SeverActions_NFFReseatForce
    ; flag (NFFDismiss's async teardown makes Native_IsNFFManaged read FALSE by re-recruit time, so mode 0
    ; would otherwise steal the NFF follower into SA). Dismiss/wait/resume route on Native_IsNFFManaged and
    ; need no mode gate.
    Bool forceNFFReseat = StorageUtil.GetIntValue(akActor, "SeverActions_NFFReseatForce", 0) == 1
    If forceNFFReseat
        StorageUtil.UnsetIntValue(akActor, "SeverActions_NFFReseatForce")
    EndIf
    ; Read once: the seat teardown is async, so two reads can disagree.
    Bool nffSeated = SeverActionsNativeExt2.Native_IsNFFManaged(akActor)
    If SeverActionsNativeExt2.Settings_GetInt("frameworkMode") != 1 && !nffSeated && !forceNFFReseat
        Debug.Trace("[SeverActions_NFFLib] NFFRecruit: SeverActions mode (FrameworkMode 0) - driving " + akActor.GetDisplayName() + " directly, not routing through NFF")
        Return false
    EndIf
    If nffSeated
        ; Still call RecruitFollower: the seat detector (DialogueFollower) also matches a vanilla-recruited
        ; follower NFF has not imported, who needs it, and NFF tolerates it on an imported actor (its spar
        ; flow does the same).
        Debug.Trace("[SeverActions_NFFLib] NFFRecruit: " + akActor.GetDisplayName() + " already seated - importing through NFF anyway (vanilla-seat case)")
    EndIf
    ; Never make NFF claim an actor another framework owns: RecruitFollower walks past NFF's own ignore token.
    ; Read the owner directly: the track-only verdict is also true for owner NFF and would refuse every hand-off.
    Int owner = SeverActionsNativeExt2.Native_GetFollowerOwner(akActor)
    If owner == 3 || owner == 4   ; DLC-managed or custom-AI
        Return false
    EndIf
    nwsFollowerControllerScript nff = GetNFFController()
    If !nff
        Return false
    EndIf
    nff.RecruitFollower(akActor)
    _InvalidateTrackOnlyCache(akActor)
    Debug.Trace("[SeverActions_NFFLib] NFFRecruit: routed recruitment for " + akActor.GetDisplayName() + " through NFF")
    Return true
EndFunction
