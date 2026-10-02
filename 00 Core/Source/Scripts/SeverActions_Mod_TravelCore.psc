Scriptname SeverActions_Mod_TravelCore extends SeverActions_ModuleBase
{Provider of the "travelcore" support bundle: alias 258 of quest 0x000D62 (plan 3.0 M-P). Init K3
 runs its idempotent OnModuleLoad stages on every load (DR20); they forward to the bundle's
 host scripts, which register their own events (DR16). SeverActions_TravelCore is the journey
 primitive and the arrival wait's Papyrus half.
 ServiceBool "cancelJourney" / "stripTravelOverrides" expose two TravelCore Globals to modules
 outside this bundle's closure (FollowerManager, Follow: followers may not name TravelCore, DR2).
 They live here, not on travel's provider, because a journey can run without the travel module
 (kidnap and arrest walk captives through travelcore).}

String Function BundleId()
    Return "travelcore"
EndFunction

Int Function ContractVersion()
    ; A literal, never kContractVersion (see SeverActions_ModuleBase.kContractVersion).
    Return 1
EndFunction

Function OnModuleLoad(Int aiStage, Bool abNewGame)
    Parent.OnModuleLoad(aiStage, abNewGame)
    Quest q = GetOwningQuest()
    If !q
        Return
    EndIf
    If aiStage == 1
        ; The core's own recovery first: listeners, the slot migration, the arrival
        ; sandbox re-applied on every waiting NPC, the wait pin sweep.
        SeverActions_TravelCore core = q as SeverActions_TravelCore
        If core
            core.Maintenance()
            Debug.Trace("[SeverActions] TravelCore initialized (the journey primitive, the arrival wait)")
        Else
            Debug.Trace("[SeverActions] WARNING: SeverActions_TravelCore not found")
        EndIf
        ; Then Travel's load recovery, first of every module (R23: the ambush
        ; teardown before anything re-seats a follower). A service, not a cast:
        ; naming SeverActions_Travel would kill this class where travel is absent
        ; (F3). K2 binds every provider before any stage, so it is reachable.
        If SeverActions_ModuleBase.CallBool("travel", "loadRecovery")
            Debug.Trace("[SeverActions] Travel load recovery complete")
        EndIf
    EndIf
EndFunction

Bool Function ServiceBool(String asSvc, Form akA, Form akB, String asArg, Float afArg)
    {Each answers True once forwarded, False without an actor or the bundle (an install without
     the bundle cannot have a journey either).
     "cancelJourney": SeverActions_TravelCore.CancelJourney(akA, afArg != 0.0) - akA's journey
     or its wait, torn down synchronously because the caller puts its own package on next
     (DR13). afArg 0.0 (dismiss / wait / follow) leaves follower status alone; 1.0 restores it.
     "stripTravelOverrides": SeverActions_TravelCore.StripTravelOverrides(akA) - every travel
     package override a journey may have left on akA, for the orphan-cleanup travel branch.
     An unanswered name gets the base default, never another service's work.}
    If asSvc != "cancelJourney" && asSvc != "stripTravelOverrides"
        Return Parent.ServiceBool(asSvc, akA, akB, asArg, afArg)
    EndIf
    Actor a = akA as Actor
    If !a
        Return False
    EndIf
    If asSvc == "cancelJourney"
        SeverActions_TravelCore.CancelJourney(a, afArg != 0.0)
        Return True
    ElseIf asSvc == "stripTravelOverrides"
        SeverActions_TravelCore.StripTravelOverrides(a)
        Return True
    EndIf
    Return Parent.ServiceBool(asSvc, akA, akB, asArg, afArg)
EndFunction

Event OnInit()
    ; Log only: setup runs from the load stages, since a re-added script gets no OnInit (DR20, F35).
    Debug.Trace("[SeverActions] provider travelcore: bound (alias 258)")
EndEvent
