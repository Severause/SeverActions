ScriptName k101DaegonController Extends Quest

;-- Variables ---------------------------------------

;-- Properties --------------------------------------
Faction Property CurrentFollowerFaction Auto
Faction Property CurrentHireling Auto
Actor Property DismissedFollowerActor Auto
Faction Property DismissedFollowerFaction Auto
ReferenceAlias Property FollowerAlias Auto
Message Property FollowerDismissMessage Auto
Message Property FollowerDismissMessageCompanions Auto
Message Property FollowerDismissMessageCompanionsFemale Auto
Message Property FollowerDismissMessageCompanionsMale Auto
Message Property FollowerDismissMessageWait Auto
Message Property FollowerDismissMessageWedding Auto
GlobalVariable Property FollowerRecruited Auto
sethirelingrehire Property HirelingRehireScript Auto
Actor Property PlayerRef Auto
Int Property iFollowerDismiss Auto conditional
ObjectReference Property k101DaegonHomeXMarker Auto
GlobalVariable Property k101DaegonIsGoingHome Auto
FormList Property k101DaegonRidableWorldSpaces Auto
GlobalVariable Property k101DaegonRideHorse Auto
GlobalVariable Property k101DaegonWasRiding Auto
Actor Property k101Moondancer Auto
ObjectReference Property k101MoondancerHomeXMarker Auto
Spell Property k101MoondancerTeleportSpell Auto
ObjectReference Property k101PlayerOffsetXMarker Auto

;-- Functions ---------------------------------------

; Skipped compiler generated GetState

; Skipped compiler generated GotoState

Function DismissFollower(Int iMessage, Int iSayLine)
  If FollowerAlias as Bool && FollowerAlias.GetActorReference().IsDead() == False ; #DEBUG_LINE_NO:38
    If iMessage == 0 ; #DEBUG_LINE_NO:39
      FollowerDismissMessage.Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:40
    ElseIf iMessage == 1 ; #DEBUG_LINE_NO:41
      FollowerDismissMessageWedding.Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:42
    ElseIf iMessage == 2 ; #DEBUG_LINE_NO:43
      FollowerDismissMessageCompanions.Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:44
    ElseIf iMessage == 3 ; #DEBUG_LINE_NO:45
      FollowerDismissMessageCompanionsMale.Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:46
    ElseIf iMessage == 4 ; #DEBUG_LINE_NO:47
      FollowerDismissMessageCompanionsFemale.Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:48
    ElseIf iMessage == 5 ; #DEBUG_LINE_NO:49
      FollowerDismissMessageWait.Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:50
    Else
      FollowerDismissMessage.Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:52
    EndIf
    DismissedFollowerActor = FollowerAlias.GetActorReference() ; #DEBUG_LINE_NO:54
    DismissedFollowerActor.StopCombatAlarm() ; #DEBUG_LINE_NO:55
    Self.DismissMoondancer() ; #DEBUG_LINE_NO:56
    Self.MoveDismissalFireboltXMarker() ; #DEBUG_LINE_NO:57
    DismissedFollowerActor.AddToFaction(DismissedFollowerFaction) ; #DEBUG_LINE_NO:58
    DismissedFollowerActor.SetPlayerTeammate(False, True) ; #DEBUG_LINE_NO:59
    DismissedFollowerActor.RemoveFromFaction(CurrentHireling) ; #DEBUG_LINE_NO:60
    DismissedFollowerActor.SetActorValue("WaitingForPlayer", 0 as Float) ; #DEBUG_LINE_NO:61
    FollowerRecruited.SetValue(0.0) ; #DEBUG_LINE_NO:62
    HirelingRehireScript.DismissHireling(DismissedFollowerActor.GetActorBase()) ; #DEBUG_LINE_NO:63
    If iSayLine == 1 ; #DEBUG_LINE_NO:64
      iFollowerDismiss = 1 ; #DEBUG_LINE_NO:65
      DismissedFollowerActor.EvaluatePackage() ; #DEBUG_LINE_NO:66
      Utility.Wait(2 as Float) ; #DEBUG_LINE_NO:67
    EndIf
    FollowerAlias.Clear() ; #DEBUG_LINE_NO:69
    iFollowerDismiss = 0 ; #DEBUG_LINE_NO:70
    k101DaegonIsGoingHome.SetValue(1.0) ; #DEBUG_LINE_NO:71
  EndIf
EndFunction

Function DismissMoondancer()
  If k101DaegonRideHorse.GetValue() == 1.0 ; #DEBUG_LINE_NO:76
    k101DaegonRideHorse.SetValue(0.0) ; #DEBUG_LINE_NO:77
    k101DaegonWasRiding.SetValue(0.0) ; #DEBUG_LINE_NO:78
    If DismissedFollowerActor != None ; #DEBUG_LINE_NO:79
      DismissedFollowerActor.Dismount() ; #DEBUG_LINE_NO:80
      DismissedFollowerActor.EvaluatePackage() ; #DEBUG_LINE_NO:81
    EndIf
    If FollowerAlias != None ; #DEBUG_LINE_NO:83
      Actor FollowerActor = FollowerAlias.GetActorReference() ; #DEBUG_LINE_NO:84
      FollowerActor.Dismount() ; #DEBUG_LINE_NO:85
      FollowerActor.EvaluatePackage() ; #DEBUG_LINE_NO:86
    EndIf
    Utility.Wait(3.0) ; #DEBUG_LINE_NO:88
    k101MoondancerTeleportSpell.Cast(k101Moondancer as ObjectReference, k101Moondancer as ObjectReference) ; #DEBUG_LINE_NO:89
    Utility.Wait(0.75) ; #DEBUG_LINE_NO:90
    k101Moondancer.MoveTo(k101MoondancerHomeXMarker, 0.0, 0.0, 0.0, True) ; #DEBUG_LINE_NO:91
  EndIf
EndFunction

Function DismissMoondancerTemporarily()
  If k101DaegonRideHorse.GetValue() == 1.0 ; #DEBUG_LINE_NO:96
    k101DaegonRideHorse.SetValue(0.0) ; #DEBUG_LINE_NO:97
    k101DaegonWasRiding.SetValue(1.0) ; #DEBUG_LINE_NO:98
    If DismissedFollowerActor != None ; #DEBUG_LINE_NO:99
      DismissedFollowerActor.Dismount() ; #DEBUG_LINE_NO:100
      DismissedFollowerActor.EvaluatePackage() ; #DEBUG_LINE_NO:101
    EndIf
    If FollowerAlias != None ; #DEBUG_LINE_NO:103
      Actor FollowerActor = FollowerAlias.GetActorReference() ; #DEBUG_LINE_NO:104
      FollowerActor.Dismount() ; #DEBUG_LINE_NO:105
      FollowerActor.EvaluatePackage() ; #DEBUG_LINE_NO:106
    EndIf
    Utility.Wait(3.0) ; #DEBUG_LINE_NO:108
    If k101Moondancer.Is3DLoaded() ; #DEBUG_LINE_NO:109
      k101MoondancerTeleportSpell.Cast(k101Moondancer as ObjectReference, k101Moondancer as ObjectReference) ; #DEBUG_LINE_NO:110
      Utility.Wait(0.75) ; #DEBUG_LINE_NO:111
    EndIf
    k101Moondancer.MoveTo(k101MoondancerHomeXMarker, 0.0, 0.0, 0.0, True) ; #DEBUG_LINE_NO:113
  EndIf
EndFunction

Function FollowerFollow()
  Actor FollowerActor = FollowerAlias.GetActorReference() ; #DEBUG_LINE_NO:118
  FollowerActor.SetActorValue("WaitingForPlayer", 0 as Float) ; #DEBUG_LINE_NO:119
  Self.SetObjectiveDisplayed(10, False, False) ; #DEBUG_LINE_NO:120
  FollowerActor.EvaluatePackage() ; #DEBUG_LINE_NO:121
EndFunction

Function FollowerWait()
  Actor FollowerActor = FollowerAlias.GetActorReference() ; #DEBUG_LINE_NO:125
  FollowerActor.SetActorValue("WaitingForPlayer", 1 as Float) ; #DEBUG_LINE_NO:126
  Self.SetObjectiveDisplayed(10, True, True) ; #DEBUG_LINE_NO:127
EndFunction

Function MoondancerPlayerMaintenanceOnFastTravel()
  If k101DaegonRideHorse.GetValue() == 1.0 ; #DEBUG_LINE_NO:131
    If PlayerRef.IsInInterior() || !k101DaegonRidableWorldSpaces.HasForm(PlayerRef.GetWorldSpace() as Form) ; #DEBUG_LINE_NO:132
      Self.DismissMoondancerTemporarily() ; #DEBUG_LINE_NO:133
    Else
      Self.SummonMoondancer() ; #DEBUG_LINE_NO:135
    EndIf
  EndIf
EndFunction

Function MoondancerPlayerMaintenanceOnLocationChange()
  If k101DaegonRideHorse.GetValue() == 1.0 || k101DaegonWasRiding.GetValue() == 1.0 ; #DEBUG_LINE_NO:141
    If PlayerRef.IsInInterior() || !k101DaegonRidableWorldSpaces.HasForm(PlayerRef.GetWorldSpace() as Form) ; #DEBUG_LINE_NO:142
      Self.DismissMoondancerTemporarily() ; #DEBUG_LINE_NO:143
    ElseIf !FollowerAlias.GetActorReference().IsOnMount() ; #DEBUG_LINE_NO:144
      Self.SummonMoondancer() ; #DEBUG_LINE_NO:145
    EndIf
  EndIf
EndFunction

Function MoveDismissalFireboltXMarker()
  Float OffsetY
  Float OffsetX
  If PlayerRef.GetPositionX() < k101DaegonHomeXMarker.GetPositionX() ; #DEBUG_LINE_NO:153
    OffsetX = -192.0 ; #DEBUG_LINE_NO:154
  Else
    OffsetX = 192.0 ; #DEBUG_LINE_NO:156
  EndIf
  If PlayerRef.GetPositionY() < k101DaegonHomeXMarker.GetPositionY() ; #DEBUG_LINE_NO:158
    OffsetY = 192.0 ; #DEBUG_LINE_NO:159
  Else
    OffsetY = -192.0 ; #DEBUG_LINE_NO:161
  EndIf
  Float AngleZ = PlayerRef.GetAngleZ() ; #DEBUG_LINE_NO:163
  k101PlayerOffsetXMarker.MoveTo(PlayerRef as ObjectReference, OffsetX * Math.Sin(AngleZ), OffsetY * Math.Cos(AngleZ), PlayerRef.GetHeight() / 2.0, False) ; #DEBUG_LINE_NO:164
EndFunction

Function SetFollower(ObjectReference FollowerRef)
  Actor FollowerActor = FollowerRef as Actor ; #DEBUG_LINE_NO:198
  FollowerActor.RemoveFromFaction(DismissedFollowerFaction) ; #DEBUG_LINE_NO:199
  If FollowerActor.GetRelationshipRank(PlayerRef) < 3 && FollowerActor.GetRelationshipRank(PlayerRef) >= 0 ; #DEBUG_LINE_NO:200
    FollowerActor.SetRelationshipRank(PlayerRef, 3) ; #DEBUG_LINE_NO:201
  EndIf
  FollowerActor.SetPlayerTeammate(True, True) ; #DEBUG_LINE_NO:203
  FollowerAlias.ForceRefTo(FollowerActor as ObjectReference) ; #DEBUG_LINE_NO:204
  FollowerActor.EvaluatePackage() ; #DEBUG_LINE_NO:205
  FollowerRecruited.SetValue(1.0) ; #DEBUG_LINE_NO:206
EndFunction

Function SummonMoondancer()
  If FollowerAlias != None ; #DEBUG_LINE_NO:211
    FollowerAlias.GetActorReference().Dismount() ; #DEBUG_LINE_NO:213
    Utility.Wait(0.25) ; #DEBUG_LINE_NO:214
  EndIf
  Float AngleZ = PlayerRef.GetAngleZ() ; #DEBUG_LINE_NO:218
  k101Moondancer.MoveTo(PlayerRef as ObjectReference, 256.0 * Math.Sin(AngleZ), Math.Cos(AngleZ), PlayerRef.GetHeight() / 2.0, False) ; #DEBUG_LINE_NO:219
  Utility.Wait(0.75) ; #DEBUG_LINE_NO:220
  k101MoondancerTeleportSpell.Cast(k101Moondancer as ObjectReference, k101Moondancer as ObjectReference) ; #DEBUG_LINE_NO:221
  k101DaegonRideHorse.SetValue(1.0) ; #DEBUG_LINE_NO:222
  k101DaegonWasRiding.SetValue(0.0) ; #DEBUG_LINE_NO:223
EndFunction
