Scriptname SeverActions_Mod_Survival extends SeverActions_ModuleBase
{Provider of the "survival" module: alias 268 of quest 0x000D62 (plan 3.0 M-P). Init K3 runs its
 idempotent OnModuleLoad stages on every load (DR20); they forward to the module's host scripts,
 which register their own events (DR16). Survival's tick arms only while the system is enabled,
 so no tick name is watched.
 Services for the MCM's survival rows (the default without this module): ServiceBool
 "isFollowerExcluded" / "toggleExcluded" (akA the follower), ServiceInt "trackedFollowerCount".
 The MCM calls them synchronously, since its page draws from the result (DR13).}

String Function BundleId()
    Return "survival"
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
        SeverActions_Survival survival = q as SeverActions_Survival
        If survival
            survival.Maintenance()
            Debug.Trace("[SeverActions] Survival System initialized - Enabled: " + survival.Enabled)
        Else
            Debug.Trace("[SeverActions] Survival System not found (optional)")
        EndIf
    EndIf
EndFunction

Bool Function ServiceBool(String asSvc, Form akA, Form akB, String asArg, Float afArg)
    {"isFollowerExcluded": Survival.IsFollowerExcluded(akA) - whether the follower is left out
     of survival tracking. "toggleExcluded": Survival.ToggleFollowerExcluded(akA), then answers
     the NEW excluded state. Both answer False without an actor or the module (unlike
     Survival's own IsFollowerExcluded, which answers True for None).}
    If asSvc != "isFollowerExcluded" && asSvc != "toggleExcluded"
        Return Parent.ServiceBool(asSvc, akA, akB, asArg, afArg)
    EndIf
    SeverActions_Survival survival = GetOwningQuest() as SeverActions_Survival
    Actor a = akA as Actor
    If !survival || !a
        Return False
    EndIf
    If asSvc == "isFollowerExcluded"
        Return survival.IsFollowerExcluded(a)
    ElseIf asSvc == "toggleExcluded"
        survival.ToggleFollowerExcluded(a)
        Return survival.IsFollowerExcluded(a)
    EndIf
    Return Parent.ServiceBool(asSvc, akA, akB, asArg, afArg)
EndFunction

Int Function ServiceInt(String asSvc, Form akA, Form akB, String asArg, Float afArg)
    {"trackedFollowerCount": Survival.GetTrackedFollowerCount() - the current followers not
     excluded from survival tracking. 0 without the module.}
    If asSvc == "trackedFollowerCount"
        SeverActions_Survival survival = GetOwningQuest() as SeverActions_Survival
        If !survival
            Return 0
        EndIf
        Return survival.GetTrackedFollowerCount()
    EndIf
    Return Parent.ServiceInt(asSvc, akA, akB, asArg, afArg)
EndFunction

Event OnInit()
    ; Log only: setup runs from the load stages, since a re-added script gets no OnInit (DR20, F35).
    Debug.Trace("[SeverActions] provider survival: bound (alias 268)")
EndEvent
