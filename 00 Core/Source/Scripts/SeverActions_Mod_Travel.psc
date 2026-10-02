Scriptname SeverActions_Mod_Travel extends SeverActions_ModuleBase
{Provider of the "travel" module (Travel & Furniture): alias 265 of quest 0x000D62 (plan 3.0
 M-P). Init K3 runs its idempotent OnModuleLoad stages on every load (DR20); they forward to the
 module's host scripts, which register their own events (DR16). Travel's tick arms only while a
 journey or a courier runs, so no tick name is watched.
 Services (the default without this module): ServiceBool "loadRecovery" (travelcore's stage 1),
 "cancelJourney", "cancelAllJourneys" and ServiceString "journeyLine" (the MCM's Travel page,
 called synchronously since the page redraws from the result, DR13).}

String Function BundleId()
    Return "travel"
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
        ; Travel's recovery already ran from the travelcore provider (R23). Here: the
        ; readiness log, the debug status, then Furniture's Maintenance.
        SeverActions_Travel travel = q as SeverActions_Travel
        If travel
            If SeverActionsNative.IsLocationResolverReady()
                Int locCount = SeverActionsNative.GetLocationCount()
                Debug.Trace("[SeverActions] Travel System ready - " + locCount + " locations indexed natively")
            Else
                Debug.Trace("[SeverActions] WARNING: Native LocationResolver not yet initialized")
            EndIf
            If travel.EnableDebugMessages
                travel.ShowStatus()
            EndIf
            Debug.Trace("[SeverActions] Travel System initialized successfully")
        Else
            Debug.Trace("[SeverActions] WARNING: Travel System not found!")
        EndIf
        SeverActions_Furniture furnSys = q as SeverActions_Furniture
        If furnSys
            furnSys.Maintenance()
            Debug.Trace("[SeverActions] Furniture System initialized successfully")
        Else
            Debug.Trace("[SeverActions] Furniture System not found (optional)")
        EndIf
    EndIf
EndFunction

Bool Function ServiceBool(String asSvc, Form akA, Form akB, String asArg, Float afArg)
    {Each answers True once forwarded, False without the module.
     "loadRecovery": Travel.OnGameLoaded, the first-of-every-module recovery (R23). Travelcore
     asks for it rather than casting: it is in the closure of modules without travel (arrest),
     where naming SeverActions_Travel would leave its class dead (F3).
     "cancelJourney": Travel.CancelTravel(akA, afArg != 0.0) - akA's journey or its wait, torn
     down synchronously; afArg 1.0 restores follower status (what the MCM passes). False
     without an actor.
     "cancelAllJourneys": Travel.ForceResetAllSlots(afArg != 0.0) - every player-ordered
     journey, with Travel's two notices (the MCM's Reset).
     A module without travel cancels or begins a journey through SeverActions_TravelCore
     statically. The retired "cancelTravel" name is deliberately not reused: an old caller of
     it gets the base default, as does any name without its own branch.}
    If asSvc != "loadRecovery" && asSvc != "cancelJourney" && asSvc != "cancelAllJourneys"
        Return Parent.ServiceBool(asSvc, akA, akB, asArg, afArg)
    EndIf
    SeverActions_Travel travel = GetOwningQuest() as SeverActions_Travel
    If !travel
        Return False
    EndIf
    If asSvc == "loadRecovery"
        travel.OnGameLoaded()
        Return True
    ElseIf asSvc == "cancelJourney"
        Actor a = akA as Actor
        If !a
            Return False
        EndIf
        travel.CancelTravel(a, afArg != 0.0)
        Return True
    ElseIf asSvc == "cancelAllJourneys"
        travel.ForceResetAllSlots(afArg != 0.0)
        Return True
    EndIf
    Return Parent.ServiceBool(asSvc, akA, akB, asArg, afArg)
EndFunction

String Function ServiceString(String asSvc, Form akA, Form akB, String asArg, Float afArg)
    {"journeyLine": Travel.GetJourneyLine(afArg as Int) - "<name>: Traveling to <place>" /
     "<name>: Waiting at <place>" for the journey at that index, "" past the end or without
     the module. The MCM's journey rows and Cancel Journey confirm text.}
    If asSvc == "journeyLine"
        SeverActions_Travel travel = GetOwningQuest() as SeverActions_Travel
        If !travel
            Return ""
        EndIf
        Return travel.GetJourneyLine(afArg as Int)
    EndIf
    Return Parent.ServiceString(asSvc, akA, akB, asArg, afArg)
EndFunction

Event OnInit()
    ; Log only: setup runs from the load stages, since a re-added script gets no OnInit (DR20, F35).
    Debug.Trace("[SeverActions] provider travel: bound (alias 265)")
EndEvent
