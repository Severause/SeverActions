ScriptName k101DaegonQuestAliasScript Extends ReferenceAlias

; -----------------------------------------------------------------------------
; SeverActions compatibility patch for Daegon Kaekiri
; Repo: github.com/Severause/SeverActions
;
; Changes vs. original:
;   OnItemRemoved       - no longer force-restores outfit pieces to Daegon
;                         when SeverActions is actively managing her outfit.
;                         Without this, SA's Undress/Unequip actions silently
;                         fail because the piece is re-added and re-equipped
;                         with preventRemoval=True.
;   OnObjectUnequipped  - no longer re-equips custom-outfit pieces when SA is
;                         actively managing her outfit. Without this, any
;                         unequip through SA gets reverted on the next frame.
;
; v2 (post-review) — the gate is now Native_Outfit_IsActivelyManaged() instead
; of a bare faction check. This avoids the previous behavior where flagging
; Daegon as "outfit excluded" in SA (or registering her in a tracking-mode-only
; setup with no preset/lock) would suppress BOTH systems' enforcement and
; leave her permanently undressed. The helper returns true only when SA is
; actually locking or running a slot preset for her — so when SA is hands-off
; the original Daegon force-reequip resumes.
;
; Default-outfit dialogue behavior is untouched. The outfit container still
; tracks what the mod considers Daegon's "current" outfit; SeverActions just
; takes over enforcement while it has an active lock / preset on her.
; -----------------------------------------------------------------------------

;-- Variables ---------------------------------------

;-- Properties --------------------------------------
Faction Property CurrentFollowerFaction Auto
Faction Property CurrentHireling Auto
Message Property FollowerDismissMessage Auto
Actor Property PlayerRef Auto
Light Property Torch01 Auto
Armor Property k101DaeLantern Auto
Topic Property k101DaegonCourageTopic Auto
k101DaegonCustomOutfitContainerScript Property k101DaegonCustomOutfitContainerRef Auto
Weapon Property k101DaegonDagger Auto
Topic Property k101DaegonDaggerUnequipTopic Auto
Topic Property k101DaegonHealedByPlayerTopic Auto
Armor Property k101DaegonRatticus Auto
FormList Property k101DaegonSpellsWithReactions Auto
GlobalVariable Property k101LanternIsEquipped Auto
Actor Property k101Rat Auto

;-- Functions ---------------------------------------

Event OnDeath(Actor akKiller)
  Self.GetActorReference().RemoveFromFaction(CurrentHireling)
  Self.Clear()
EndEvent

Event OnEnterBleedout()
  Actor SelfRef = Self.GetActorReference()
  Float CurrentHealth = SelfRef.GetActorValue("Health")
  If CurrentHealth < 0.0
    Utility.Wait(5.0)
    SelfRef.RestoreActorValue("Health", CurrentHealth)
  EndIf
EndEvent

Event OnItemAdded(Form akBaseItem, Int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
  If akBaseItem.GetName() == "Torch"
    Actor SelfRef = Self.GetActorReference()
    SelfRef.RemoveItem(akBaseItem, aiItemCount, False, None)
    If k101LanternIsEquipped.GetValue() == 1.0
      SelfRef.RemoveItem(k101DaeLantern, 1, False, None)
      SelfRef.AddItem(k101DaeLantern, 1, False)
      SelfRef.EquipItem(k101DaeLantern, False, False)
    EndIf
  EndIf
EndEvent

Event OnItemRemoved(Form akBaseItem, Int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
  ; SeverActions compat: when Daegon is a SeverActions follower, let SeverActions
  ; handle outfit management. Do not force the piece back.
  If Self.IsSeverActionsActivelyManagingOutfit()
    If akBaseItem == k101DaegonDagger
      Actor selfref = Self.GetActorReference()
      Debug.Notification("Daegon won't let you touch this.")
      akDestContainer.RemoveItem(akBaseItem, aiItemCount, True, selfref)
      While Utility.IsInMenuMode()
        Utility.Wait(0.1)
      EndWhile
      selfref.Say(k101DaegonDaggerUnequipTopic, None, False)
    EndIf
    Return
  EndIf

  If k101DaegonCustomOutfitContainerRef.GetItemCount(akBaseItem) > 0
    Actor SelfRef = Self.GetActorReference()
    Debug.Notification("This item is a part of Dae's custom outfit and can only be removed through her outfit dialogue.")
    akDestContainer.RemoveItem(akBaseItem, aiItemCount, True, SelfRef)
    SelfRef.EquipItem(akBaseItem, True, True)
  ElseIf akBaseItem == k101DaegonDagger
    Actor selfref = Self.GetActorReference()
    Debug.Notification("Daegon won't let you touch this.")
    akDestContainer.RemoveItem(akBaseItem, aiItemCount, True, selfref)
    While Utility.IsInMenuMode()
      Utility.Wait(0.1)
    EndWhile
    selfref.Say(k101DaegonDaggerUnequipTopic, None, False)
  EndIf
EndEvent

Event OnLoad()
  PO3_Events_Alias.RegisterForMagicEffectApplyEx(Self as ReferenceAlias, k101DaegonSpellsWithReactions, True)
  Self.CheckRat()
EndEvent

Event OnLocationChange(Location akOldLoc, Location akNewLoc)
  If akNewLoc != None
    Self.CheckRat()
  EndIf
EndEvent

Function OnMagicEffectApplyEx(ObjectReference akCaster, MagicEffect akEffect, Form akSource, Bool abApplied)
  If akCaster == PlayerRef
    String Skill = akEffect.GetAssociatedSkill()
    If Skill == "Illusion"
      Self.GetActorReference().Say(k101DaegonCourageTopic, None, False)
    ElseIf Skill == "Restoration"
      Self.GetActorReference().Say(k101DaegonHealedByPlayerTopic, None, False)
    EndIf
  EndIf
EndFunction

Event OnObjectUnequipped(Form akBaseObject, ObjectReference akReference)
  ; SeverActions compat: SeverActions owns outfit enforcement when it's tracking
  ; Daegon. Skip the force-reequip entirely.
  If Self.IsSeverActionsActivelyManagingOutfit()
    Return
  EndIf

  Actor k101DaegonActor = Self.GetActorReference()
  If k101DaegonCustomOutfitContainerRef.GetItemCount(akBaseObject) > 0 && k101DaegonActor.GetItemCount(akBaseObject) > 0
    k101DaegonActor.EquipItem(akBaseObject, True, True)
  EndIf
EndEvent

Event OnUnload()
  PO3_Events_Alias.UnregisterForAllMagicEffectApplyEx(Self as ReferenceAlias)
EndEvent

Function CheckRat()
  Actor k101DaegonActor = Self.GetActorReference()
  If k101DaegonActor.IsInInterior()
    If k101DaegonActor.IsEquipped(k101DaegonRatticus)
      k101Rat.Disable(False)
      k101DaegonActor.RemoveItem(k101DaegonRatticus, k101DaegonActor.GetItemCount(k101DaegonRatticus), True, None)
      k101Rat.Enable(False)
    EndIf
  ElseIf !k101DaegonActor.IsEquipped(k101DaegonRatticus)
    k101Rat.Enable(False)
    If k101DaegonActor.GetItemCount(k101DaegonRatticus) == 0
      k101DaegonActor.AddItem(k101DaegonRatticus, 1, False)
    EndIf
    k101Rat.Disable(False)
    k101DaegonActor.EquipItem(k101DaegonRatticus, False, False)
  EndIf
EndFunction

; SeverActions compat helper. v2: asks the SA DLL directly whether SA is
; actively managing this actor's outfit RIGHT NOW (isFollower AND not
; outfit-excluded AND has an active lock or slot preset). The plugin-presence
; check via Game.GetFormFromFile stays as a soft-dep gate so this script
; does NOT require SeverActions.esp as a master — if SA isn't installed,
; the function returns False and the original Daegon force-reequip logic
; runs unchanged.
;
; The previous version did a bare faction check, which was too coarse:
;   * Actors flagged "outfit excluded" in SA still passed the faction check,
;     so the patch suppressed Daegon's enforcement while SA also did nothing
;     (outfit-excluded short-circuits SA's outfit alias). End state: nothing
;     enforced, Daegon stayed naked.
;   * Tracking-mode followers with no lock/preset had the same issue.
; The new helper closes both holes by mirroring exactly the gate SA's own
; outfit alias uses in OnObjectUnequipped.
Bool Function IsSeverActionsActivelyManagingOutfit()
  ; Soft-dep gate: if SeverActions.esp isn't loaded, the follower faction
  ; can't resolve and we fall back to the mod's native outfit enforcement.
  Faction SeverFF = Game.GetFormFromFile(0x000EB708, "SeverActions.esp") as Faction
  If SeverFF == None
    Return False
  EndIf
  Actor Daegon = Self.GetActorReference()
  If Daegon == None
    Return False
  EndIf
  ; Native helper rolled into the SA DLL — see SeverActionsNativeExt.psc.
  Return SeverActionsNativeExt.Native_Outfit_IsActivelyManaged(Daegon)
EndFunction
