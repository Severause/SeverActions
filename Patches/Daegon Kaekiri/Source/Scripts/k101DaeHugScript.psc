ScriptName k101DaeHugScript Extends Quest

;-- Variables ---------------------------------------

;-- Properties --------------------------------------
Quest Property WW42HugFollower Auto

;-- Functions ---------------------------------------

; Skipped compiler generated GetState

; Skipped compiler generated GotoState

Function HugFollower(Actor akSpeaker)
  ww42hugfollowerscript hugscript = WW42HugFollower as ww42hugfollowerscript ; #DEBUG_LINE_NO:6
  hugscript.HugActor(akSpeaker) ; #DEBUG_LINE_NO:7
EndFunction
