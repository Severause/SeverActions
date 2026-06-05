ScriptName k101DaegonUtilityScript

;-- Functions ---------------------------------------

; Skipped compiler generated GetState

; Skipped compiler generated GotoState

Event onBeginState()
{ Event received when this state is switched to }
  ; Empty function
EndEvent

Event onEndState()
{ Event received when this state is switched away from }
  ; Empty function
EndEvent

Bool Function ChangeFace(Actor akTarget, TextureSet tsSkin) Global
  ActorBase abTarget
  Int nHeadIdx = -1 ; #DEBUG_LINE_NO:5
  String szNode = "" ; #DEBUG_LINE_NO:6
  If !akTarget || !tsSkin ; #DEBUG_LINE_NO:7
    Return False ; #DEBUG_LINE_NO:8
  Else
    abTarget = akTarget.GetLeveledActorBase() ; #DEBUG_LINE_NO:10
  EndIf
  If abTarget ; #DEBUG_LINE_NO:12
    nHeadIdx = abTarget.GetIndexOfHeadPartByType(1) ; #DEBUG_LINE_NO:13
  EndIf
  If nHeadIdx >= 0 ; #DEBUG_LINE_NO:15
    szNode = abTarget.GetNthHeadPart(nHeadIdx).GetName() ; #DEBUG_LINE_NO:16
  EndIf
  If nHeadIdx >= 0 ; #DEBUG_LINE_NO:18
    abTarget.SetFaceTextureSet(tsSkin) ; #DEBUG_LINE_NO:19
    netimmerse.SetNodeTextureSet(akTarget as ObjectReference, szNode, tsSkin, False) ; #DEBUG_LINE_NO:20
  EndIf
  Return True ; #DEBUG_LINE_NO:22
EndFunction

String Function GetHeadNode(Actor aAct) Global
  ActorBase ab = aAct.GetActorBase() ; #DEBUG_LINE_NO:26
  Int i = ab.GetNumHeadParts() ; #DEBUG_LINE_NO:27
  While i > 0 ; #DEBUG_LINE_NO:29
    i -= 1 ; #DEBUG_LINE_NO:30
    String headNode = ab.GetNthHeadPart(i).GetPartName() ; #DEBUG_LINE_NO:31
    If stringutil.Find(headNode, "Head", 0) >= 0 ; #DEBUG_LINE_NO:32
      Return headNode ; #DEBUG_LINE_NO:33
    EndIf
  EndWhile
  Return "" ; #DEBUG_LINE_NO:36
EndFunction

DXFlowerGirlsScript Function GetFlowerGirls() Global
  Return Game.GetFormFromFile(4805, "FlowerGirls SE.esm") as DXFlowerGirlsScript ; #DEBUG_LINE_NO:40
EndFunction
