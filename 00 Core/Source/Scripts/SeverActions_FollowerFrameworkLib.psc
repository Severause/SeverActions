Scriptname SeverActions_FollowerFrameworkLib Hidden
{Base-game follower-framework routes (M-L, D42): the vanilla DialogueFollower quest (0x000750BA, Skyrim.esm),
 Serana's mental model (DLC1_NPCMentalModelScript, quest 0x002B6E of Dawnguard.esm), the SFF presence test and
 ReseatExternal (B17). Unattached, Global-only (bundle fwlib); callers make static calls only (N2).
 It names no optional type (Dawnguard ships with every supported install), so it links everywhere; the NFF
 calls live in SeverActions_NFFLib behind Native_IsNFFInstalled, because a Global library naming an absent
 type is dead in every function (F32).
 Traces log unconditionally: these routes run on player actions.}

Bool Function HasSFF() Global
    {TRUE when Simple Follower Framework is installed. SFF overrides DialogueFollower and seats followers 2-8
     in extra aliases that SA's GetAlias(0)-only dismiss cannot clear (the NPC keeps an unremovable
     PlayerFollowerPackage), so the vanilla route is skipped under SFF as under NFF. Only vanilla follower
     idle dialogue is lost: SA owns the follow package and teammate flag anyway.}
    Return Game.GetModByName("Simple Follower Framework.esp") != 255
EndFunction

; === Vanilla DialogueFollower + Serana mental model: recruit/dismiss through the NPC's own quest ===

Bool Function IsSerana(Actor akActor) Global
    {Check if this actor is Serana via DLC1SeranaFaction.}
    If !akActor
        Return false
    EndIf
    Faction seranaFaction = Game.GetFormFromFile(0x000183A5, "Dawnguard.esm") as Faction
    Return seranaFaction && akActor.IsInFaction(seranaFaction)
EndFunction

Bool Function RecruitViaVanillaDialogue(Actor akActor) Global
    {Recruit through vanilla DialogueFollowerScript.SetFollower(), exactly as the "Follow me" line does
     (leaves DismissedFollower, rank >= 3, teammate, pFollowerAlias, PlayerFollowerCount 1), without
     the alias's bow and arrows.}
    Return SeatViaVanillaDialogue(akActor, true)
EndFunction

Bool Function SeatViaVanillaDialogue(Actor akActor, Bool abStripAliasKit) Global
    {RecruitViaVanillaDialogue with the choice of kit: abStripAliasKit False leaves the bow and arrows
     the vanilla alias hands out, as a "Follow me" recruit has them.}
    If !akActor
        Return false
    EndIf
    Quest dfQuest = Game.GetFormFromFile(0x000750BA, "Skyrim.esm") as Quest
    If !dfQuest
        Debug.Trace("[SeverActions_FollowerFrameworkLib] RecruitViaVanillaDialogue: DialogueFollower quest not found")
        Return false
    EndIf
    DialogueFollowerScript dfScript = dfQuest as DialogueFollowerScript
    If !dfScript
        Debug.Trace("[SeverActions_FollowerFrameworkLib] RecruitViaVanillaDialogue: Cast to DialogueFollowerScript failed")
        Return false
    EndIf
    ; SetFollower's follower alias hands out FollowerHuntingBow and FollowerIronArrow, their own records
    ; (not HuntingBow / IronArrow). Strip only the delta over the pre-call counts.
    Form huntingBow = Game.GetFormFromFile(0x0010E2DD, "Skyrim.esm")
    Form ironArrow  = Game.GetFormFromFile(0x0010E2DE, "Skyrim.esm")
    Int  preBowCount   = 0
    Int  preArrowCount = 0
    If huntingBow
        preBowCount = akActor.GetItemCount(huntingBow)
    EndIf
    If ironArrow
        preArrowCount = akActor.GetItemCount(ironArrow)
    EndIf

    dfScript.SetFollower(akActor as ObjectReference)

    If !abStripAliasKit
        Return true
    EndIf
    If huntingBow
        Int addedBows = akActor.GetItemCount(huntingBow) - preBowCount
        If addedBows > 0
            akActor.RemoveItem(huntingBow, addedBows, true)
            Debug.Trace("[SeverActions_FollowerFrameworkLib] RecruitViaVanillaDialogue: Stripped " + addedBows + " vanilla hunting bow(s) from " + akActor.GetDisplayName())
        EndIf
    EndIf
    If ironArrow
        Int addedArrows = akActor.GetItemCount(ironArrow) - preArrowCount
        If addedArrows > 0
            akActor.RemoveItem(ironArrow, addedArrows, true)
            Debug.Trace("[SeverActions_FollowerFrameworkLib] RecruitViaVanillaDialogue: Stripped " + addedArrows + " vanilla iron arrow(s) from " + akActor.GetDisplayName())
        EndIf
    EndIf

    Debug.Trace("[SeverActions_FollowerFrameworkLib] RecruitViaVanillaDialogue: Called SetFollower for " + akActor.GetDisplayName())
    Return true
EndFunction

Bool Function DismissViaVanillaDialogue(Actor akActor) Global
    {Dismiss through vanilla DialogueFollowerScript.DismissFollower() (DismissedFollower, teammate off, alias
     cleared, PlayerFollowerCount 0). FALSE unless akActor holds the vanilla follower alias.}
    If !akActor
        Return false
    EndIf
    Quest dfQuest = Game.GetFormFromFile(0x000750BA, "Skyrim.esm") as Quest
    If !dfQuest
        Return false
    EndIf
    DialogueFollowerScript dfScript = dfQuest as DialogueFollowerScript
    If !dfScript
        Return false
    EndIf
    ReferenceAlias followerAlias = dfQuest.GetAlias(0) as ReferenceAlias
    If followerAlias && followerAlias.GetReference() == akActor as ObjectReference
        dfScript.DismissFollower(0, 0)  ; iMessage=0 (standard), iSayLine=0 (skip line)
        Debug.Trace("[SeverActions_FollowerFrameworkLib] DismissViaVanillaDialogue: Called DismissFollower for " + akActor.GetDisplayName())
        Return true
    EndIf
    ; Vanilla DismissFollower takes back the alias's FollowerHuntingBow / FollowerIronArrow; an occupant a
    ; later recruit pushed out of the alias never gets that, so do it here. Only this alias hands them out.
    Form huntingBow = Game.GetFormFromFile(0x0010E2DD, "Skyrim.esm")
    Form ironArrow  = Game.GetFormFromFile(0x0010E2DE, "Skyrim.esm")
    If huntingBow && akActor.GetItemCount(huntingBow) > 0
        akActor.RemoveItem(huntingBow, 999, true)
        Debug.Trace("[SeverActions_FollowerFrameworkLib] DismissViaVanillaDialogue: stripped the vanilla follower bow from " + akActor.GetDisplayName())
    EndIf
    If ironArrow && akActor.GetItemCount(ironArrow) > 0
        akActor.RemoveItem(ironArrow, 999, true)
        Debug.Trace("[SeverActions_FollowerFrameworkLib] DismissViaVanillaDialogue: stripped the vanilla follower arrows from " + akActor.GetDisplayName())
    EndIf
    Debug.Trace("[SeverActions_FollowerFrameworkLib] DismissViaVanillaDialogue: " + akActor.GetDisplayName() + " not in vanilla alias - no DismissFollower")
    Return false
EndFunction

Bool Function RecruitSerana(Actor akActor) Global
    {Recruit Serana through her mental model's EngageFollowBehavior() (her flags, teammate,
     WIFollowerCommentFaction, the monitoring quest).}
    Quest mmQuest = Game.GetFormFromFile(0x002B6E, "Dawnguard.esm") as Quest
    If !mmQuest
        Debug.Trace("[SeverActions_FollowerFrameworkLib] RecruitSerana: Mental model quest (0x002B6E) not found in Dawnguard.esm")
        Return false
    EndIf
    DLC1_NPCMentalModelScript mm = mmQuest as DLC1_NPCMentalModelScript
    If !mm
        Debug.Trace("[SeverActions_FollowerFrameworkLib] RecruitSerana: Cast to DLC1_NPCMentalModelScript failed")
        Return false
    EndIf
    mm.EngageFollowBehavior(true)  ; allowDismiss=true so player can dismiss via dialogue
    Debug.Trace("[SeverActions_FollowerFrameworkLib] RecruitSerana: Called EngageFollowBehavior for Serana")
    Return true
EndFunction

Bool Function DismissSerana(Actor akActor) Global
    {Dismiss Serana through her mental model's DisengageFollowBehavior(), the inverse of RecruitSerana.}
    Quest mmQuest = Game.GetFormFromFile(0x002B6E, "Dawnguard.esm") as Quest
    If !mmQuest
        Return false
    EndIf
    DLC1_NPCMentalModelScript mm = mmQuest as DLC1_NPCMentalModelScript
    If !mm
        Return false
    EndIf
    mm.DisengageFollowBehavior()
    Debug.Trace("[SeverActions_FollowerFrameworkLib] DismissSerana: Called DisengageFollowBehavior for Serana")
    Return true
EndFunction

Bool Function WaitSerana(Actor akActor) Global
    {Park Serana through her mental model's Wait(), which her own wait dialogue calls: it sets IsWaiting and,
     when she is willing to wait, sets WaitingForPlayer and arms her 72h auto-release. A bare SetAV does not
     hold: DLC1NPCMonitoringPlayerScript zeroes the AV while she is unwilling, and that refusal is canon.
     SDA's fork keeps this surface, so vanilla and SDA Serana both work. TRUE when the mental model resolved;
     the caller then skips its own SetAV.}
    DLC1_NPCMentalModelScript seranaMM = Game.GetFormFromFile(0x002B6E, "Dawnguard.esm") as DLC1_NPCMentalModelScript
    If !seranaMM
        Return false
    EndIf
    seranaMM.Wait()
    If akActor
        Debug.Trace("[SeverActions_FollowerFrameworkLib] WaitSerana: routed wait through the DLC mental model for " + akActor.GetDisplayName())
    EndIf
    Return true
EndFunction

Bool Function ResumeSerana(Actor akActor) Global
    {Resume Serana through StopWaiting(), the counterpart of WaitSerana: clearing the AV alone leaves IsWaiting
     set and her 72h timer armed. TRUE when the mental model resolved; the caller still clears the AV.}
    DLC1_NPCMentalModelScript seranaMMR = Game.GetFormFromFile(0x002B6E, "Dawnguard.esm") as DLC1_NPCMentalModelScript
    If !seranaMMR
        Return false
    EndIf
    seranaMMR.StopWaiting()
    If akActor
        Debug.Trace("[SeverActions_FollowerFrameworkLib] ResumeSerana: routed resume through the DLC mental model for " + akActor.GetDisplayName())
    EndIf
    Return true
EndFunction

Bool Function ReseatExternal(Actor akActor, Bool abWasNFF) Global
    {Put a framework-owned follower back into its own framework after a transient SA release (the brawl strip)
     on an install without the Followers module: Brawl's fallback for followers.rerecruit (B17). With Followers
     the caller runs RegisterFollower instead, so Legacy never reaches this. Routes, most specific first:
       abWasNFF     -> SeverActions_NFFLib.NFFRecruit behind Native_IsNFFInstalled (it honours the brawl's
                       SeverActions_NFFReseatForce key, which Brawl's queue clears); without NFF, fall through.
       DLC (Serana) -> RecruitSerana unless already a teammate (the brawl restores the flag before its queue
                       drains; re-engaging resets her state). Owner verdict 3 OR the faction test, since a
                       Serana replacer can prune the faction.
       custom-AI    -> the teammate flag only (owner 4): their framework drives them, and without Followers
                       SA applied no sandbox or schedule hold to strip.
       otherwise    -> the vanilla route, unless NFF or SFF holds that quest (see HasSFF).
     TRUE when some route took the actor.}
    If !akActor || akActor == Game.GetPlayer() || akActor.IsDead()
        Return false
    EndIf
    If abWasNFF
        If SeverActionsNativeExt2.Native_IsNFFInstalled() && SeverActions_NFFLib.NFFRecruit(akActor)
            Debug.Trace("[SeverActions_FollowerFrameworkLib] ReseatExternal: " + akActor.GetDisplayName() + " re-seated through NFF")
            Return true
        EndIf
        Debug.Trace("[SeverActions_FollowerFrameworkLib] ReseatExternal: NFF did not take " + akActor.GetDisplayName() + " back (absent or refused) - trying the base-game routes")
    EndIf
    Int owner = SeverActionsNativeExt2.Native_GetFollowerOwner(akActor)
    If owner == 3 || IsSerana(akActor)
        ; No recruited-via-Serana stamp: that row is the Followers module's, absent here.
        If akActor.IsPlayerTeammate()
            Debug.Trace("[SeverActions_FollowerFrameworkLib] ReseatExternal: " + akActor.GetDisplayName() + " is DLC-owned and already a teammate - her mental model keeps her")
            Return true
        EndIf
        Return RecruitSerana(akActor)
    EndIf
    If owner == 4
        akActor.SetPlayerTeammate(true, false)
        Debug.Trace("[SeverActions_FollowerFrameworkLib] ReseatExternal: " + akActor.GetDisplayName() + " is custom-AI - teammate flag only")
        Return true
    EndIf
    If !SeverActionsNativeExt2.Native_IsNFFInstalled() && !HasSFF()
        Return RecruitViaVanillaDialogue(akActor)
    EndIf
    Debug.Trace("[SeverActions_FollowerFrameworkLib] ReseatExternal: no route took " + akActor.GetDisplayName() + " (NFF/SFF hold the vanilla quest)")
    Return false
EndFunction
