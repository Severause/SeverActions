Scriptname nwsFollowerControllerScript extends Quest Conditional

{
    COMPILE-TIME STUB for Nether's Follower Framework integration.
    This stub provides the function signatures needed to compile SeverActions
    scripts that call NFF functions. At runtime, the REAL NFF script is used.

    DO NOT deploy the compiled .pex from this stub - it is only for compilation.
    The actual nwsFollowerControllerScript.pex comes from NFF itself.

    To compile, include this directory in the import path:
    -i="...BuildStubs;...Source/Scripts;..."
}

; Recruit an NPC as a follower through NFF's system
; This defers execution via RegisterForSingleUpdate(0.2)
Function RecruitFollower(Actor myActor)
EndFunction

; Dismiss a follower through NFF's system
; iMessage: 0=standard, -1=silent, 5=waiting dismiss
; iSayLine: 1=say goodbye line, 0=silent
Function RemoveFollower(Actor myActor, Int iMessage = 0, Int iSayLine = 1)
EndFunction
