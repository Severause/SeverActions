Scriptname EFFCore extends Quest Conditional

{
    COMPILE-TIME STUB for Extensible Follower Framework (EFF) integration.
    This stub provides the function signatures needed to compile SeverActions
    scripts that call EFF functions. At runtime, the REAL EFF script is used.

    DO NOT deploy the compiled .pex from this stub - it is only for compilation.
    The actual EFFCore.pex comes from EFF itself (inside EFFCore.bsa).

    To compile, include this directory in the import path:
    -i="...BuildStubs;...Source/Scripts;..."
}

Faction Property XFL_FollowerFaction Auto

; Add an NPC as a follower through EFF's system
; Handles factions, alias slots, teammate status, relationship ranks, etc.
Function XFL_AddFollower(Form follower)
EndFunction

; Remove a follower through EFF's system
; iMessage: 0=standard dismiss, 1=wedding, 2-4=companions variants, 5=wait dismiss
; iSayLine: 1=say goodbye line, 0=silent
Function XFL_RemoveFollower(Form follower, Int iMessage = 0, Int iSayLine = 1)
EndFunction

; Check if an actor is currently managed by EFF
Bool Function XFL_IsFollower(Actor follower)
    Return false
EndFunction

; Get the total number of EFF-managed followers
Int Function XFL_GetCount()
    Return 0
EndFunction
