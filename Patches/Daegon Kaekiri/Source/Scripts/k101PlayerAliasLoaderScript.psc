ScriptName k101PlayerAliasLoaderScript Extends ReferenceAlias

; -----------------------------------------------------------------------------
; SeverActions compatibility patch for Daegon Kaekiri
; Repo: github.com/Severause/SeverActions
;
; Change vs. original: the player alias Initialize() no longer force-reequips
; Daegon's default outfit on save load when Daegon is a registered SeverActions
; follower. Without this, the custom outfit container re-runs EquipCustomOutfit()
; every OnPlayerLoadGame and overrides whatever SeverActions' outfit lock did.
;
; When SeverActions isn't installed (or Daegon isn't a SeverActions follower),
; the faction lookup returns None and the original outfit-restore path runs.
; -----------------------------------------------------------------------------

;-- Variables ---------------------------------------
Int PlayerLocksPicked = 0

;-- Properties --------------------------------------
Faction Property CurrentFollowerFaction Auto
Actor Property FollowerRef Auto
Quest Property HugDialogueQuest Auto
GlobalVariable Property IsGYHInstalled Auto
k101DaegonCustomOutfitContainerScript Property k101DaegonCustomOutfitContainerRef Auto
Quest Property k101DaegonFollower Auto
Topic Property k101DaegonLockpickingTopic Auto
Topic Property k101DaegonPlayerDeathTopic Auto
Spell Property k101DaegonSummon Auto
Spell Property k101PlayerPickpocketTrackerAbility Auto

;-- Functions ---------------------------------------

Event OnDeath(Actor akKiller)
  If FollowerRef.IsInFaction(CurrentFollowerFaction)
    FollowerRef.Say(k101DaegonPlayerDeathTopic, None, False)
  EndIf
EndEvent

Event OnInit()
  Self.Initialize()
EndEvent

Event OnLocationChange(Location akOldLoc, Location akNewLoc)
  If akNewLoc != None && FollowerRef.IsInFaction(CurrentFollowerFaction) && (FollowerRef.GetActorValue("WaitingForPlayer") == 0.0)
    (k101DaegonFollower as k101DaegonController).MoondancerPlayerMaintenanceOnLocationChange()
  EndIf
EndEvent

Function OnMenuClose(String MenuName)
  If MenuName == "Lockpicking Menu"
    If FollowerRef.IsInFaction(CurrentFollowerFaction)
      If Game.QueryStat("Locks Picked") > PlayerLocksPicked
        FollowerRef.Say(k101DaegonLockpickingTopic, None, False)
      EndIf
    EndIf
  EndIf
EndFunction

Function OnMenuOpen(String MenuName)
  If MenuName == "Lockpicking Menu"
    If FollowerRef.IsInFaction(CurrentFollowerFaction)
      PlayerLocksPicked = Game.QueryStat("Locks Picked")
    EndIf
  EndIf
EndFunction

Event OnPlayerFastTravelEnd(Float afTravelGameTimeHours)
  If FollowerRef.IsInFaction(CurrentFollowerFaction) && (FollowerRef.GetActorValue("WaitingForPlayer") == 0.0)
    k101DaegonSummon.Cast(FollowerRef, FollowerRef)
    Utility.Wait(0.75)
    (k101DaegonFollower as k101DaegonController).MoondancerPlayerMaintenanceOnFastTravel()
  EndIf
EndEvent

Event OnPlayerLoadGame()
  Self.Initialize()
EndEvent

Function CheckForInstalledGYH()
  If Game.IsPluginInstalled("ImGladYoureHere.esp")
    Faction DisableMainFac = Game.GetFormFromFile(0x00270B4D, "ImGladYoureHere.esp") as Faction
    FollowerRef.AddToFaction(DisableMainFac)
    k101DaeHugScript HugScript = HugDialogueQuest as k101DaeHugScript
    HugScript.WW42HugFollower = Game.GetFormFromFile(0x00000D62, "ImGladYoureHere.esp") as Quest
    IsGYHInstalled.SetValue(1.0)
  Else
    IsGYHInstalled.SetValue(0.0)
  EndIf
EndFunction

Function Initialize()
  Self.CheckForInstalledGYH()
  Utility.Wait(0.1)
  Actor SelfRef = Self.GetActorReference()
  If !SelfRef.HasSpell(k101PlayerPickpocketTrackerAbility)
    SelfRef.AddSpell(k101PlayerPickpocketTrackerAbility, False)
  EndIf
  Self.RegisterForMenu("Lockpicking Menu")

  ; SeverActions compat: skip EquipCustomOutfit when Daegon is a tracked
  ; SeverActions follower. This is what fixes "default clothes come back on
  ; load" - SeverActions' outfit lock would otherwise be overwritten.
  If !Self.IsSeverActionsFollower()
    k101DaegonCustomOutfitContainerRef.EquipCustomOutfit()
  EndIf

  If FollowerRef.IsInFaction(CurrentFollowerFaction) && (FollowerRef.GetActorValue("WaitingForPlayer") == 0.0)
    If FollowerRef.GetDistance(SelfRef) > 1536.0
      (k101DaegonFollower as k101DaegonController).MoondancerPlayerMaintenanceOnFastTravel()
    EndIf
  EndIf
EndFunction

; SeverActions compat helper. Resolves the SeverActions follower faction at
; runtime via GetFormFromFile so this script does NOT require SeverActions.esp
; as a master. If the plugin isn't installed, returns False and the original
; outfit logic runs unchanged.
Bool Function IsSeverActionsFollower()
  Faction SeverFF = Game.GetFormFromFile(0x000EB708, "SeverActions.esp") as Faction
  If SeverFF == None
    Return False
  EndIf
  If FollowerRef == None
    Return False
  EndIf
  Return FollowerRef.IsInFaction(SeverFF)
EndFunction
