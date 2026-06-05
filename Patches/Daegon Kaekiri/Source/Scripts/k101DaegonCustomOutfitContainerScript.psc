ScriptName k101DaegonCustomOutfitContainerScript Extends ObjectReference

;-- Variables ---------------------------------------

;-- Properties --------------------------------------
ObjectReference Property k101Daegon Auto
Armor Property k101DaegonAmulet Auto
Armor Property k101DaegonBoots Auto
Armor Property k101DaegonCuirass Auto
Armor Property k101DaegonGauntlets Auto

;-- Functions ---------------------------------------

; Skipped compiler generated GetState

; Skipped compiler generated GotoState

Event OnItemAdded(Form akBaseItem, Int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
  If akBaseItem.GetType() != 26 || Self.GetItemCount(akBaseItem) > 1 ; #DEBUG_LINE_NO:10
    Self.RemoveItem(akBaseItem, aiItemCount, akSourceContainer as Bool, None) ; #DEBUG_LINE_NO:11
  EndIf
EndEvent

Event OnItemRemoved(Form akBaseItem, Int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
  k101Daegon.RemoveItem(akBaseItem, aiItemCount, False, None) ; #DEBUG_LINE_NO:16
EndEvent

Function EquipCustomOutfit()
  Int Index = Self.GetNumItems() ; #DEBUG_LINE_NO:20
  While Index > 0 ; #DEBUG_LINE_NO:22
    Index -= 1 ; #DEBUG_LINE_NO:23
    Armor OutfitPiece = Self.GetNthForm(Index) as Armor ; #DEBUG_LINE_NO:24
    If k101Daegon.GetItemCount(OutfitPiece as Form) == 0 ; #DEBUG_LINE_NO:25
      k101Daegon.AddItem(OutfitPiece as Form, 1, False) ; #DEBUG_LINE_NO:26
    EndIf
    (k101Daegon as Actor).EquipItem(OutfitPiece as Form, True, True) ; #DEBUG_LINE_NO:28
  EndWhile
EndFunction

Function EquipDefaultOutfit()
  Self.RemoveAllItems(None, False, False) ; #DEBUG_LINE_NO:34
  Self.AddItem(k101DaegonAmulet as Form, 1, False) ; #DEBUG_LINE_NO:35
  Self.AddItem(k101DaegonBoots as Form, 1, False) ; #DEBUG_LINE_NO:36
  Self.AddItem(k101DaegonCuirass as Form, 1, False) ; #DEBUG_LINE_NO:37
  Self.AddItem(k101DaegonGauntlets as Form, 1, False) ; #DEBUG_LINE_NO:38
  Self.EquipCustomOutfit() ; #DEBUG_LINE_NO:39
EndFunction
