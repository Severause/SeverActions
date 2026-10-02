Scriptname SeverActions_Mod_Outfit extends SeverActions_ModuleBase
{Provider of the "outfit" module: alias 267 of quest 0x000D62 (plan 3.0 M-P). Init K3 runs its
 idempotent OnModuleLoad stages on every load (DR20); they forward to the module's host scripts,
 which register their own events (DR16).
 ServiceBool services, akA the actor (see ServiceBool): "assignOutfitSlot", "clearOutfitSlot",
 "deletePreset", "setNonFollowerLock". The MCM calls them synchronously, since its page redraws
 or reads the lock back right after (DR13).}

String Function BundleId()
    Return "outfit"
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
    If aiStage == 2
        ; Outfit's migration + Maintenance, then OutfitSlot's (which re-binds every
        ; native slot owner to their alias), then the alias pool's re-seat - in that
        ; order, so the pool sees the owners already bound. The roster is the
        ; kernel's cosaved one, so an install without Followers re-seats too.
        SeverActions_Outfit outfitScript = q as SeverActions_Outfit
        If outfitScript
            outfitScript.MigrateOutfitDataToNative()
            outfitScript.Maintenance()
        EndIf
        SeverActions_OutfitSlot slotScript = q as SeverActions_OutfitSlot
        If slotScript
            slotScript.MigrateToOutfitSlotSystem()
            slotScript.Maintenance()
        EndIf
        If outfitScript
            outfitScript.ReassignOutfitSlots(SeverActionsNativeExt.Native_GetActiveFollowerRoster())
        EndIf
    EndIf
EndFunction

Bool Function ServiceBool(String asSvc, Form akA, Form akB, String asArg, Float afArg)
    {False without the module or an actor; an unanswered name gets the base default.
     "assignOutfitSlot" / "clearOutfitSlot": seat / unseat akA in the outfit alias pool. The
     targets of FollowerManager's two safe-exit forwards and of the MCM's outfit-lock toggle.
     True once forwarded.
     "deletePreset": Outfit.DeletePreset(akA, asArg), asArg the STORED preset name, verbatim -
     never re-normalised. A service, not a verb, because a verb payload is pipe-split. False
     when asArg is "".
     "setNonFollowerLock": Outfit.SetNonFollowerOutfitLock(akA, afArg != 0.0), then answers
     HasNonFollowerOutfitLock(akA), so an enable refused (outfit system or Outfit Lock off, an
     empty capture) reads False.}
    If asSvc != "assignOutfitSlot" && asSvc != "clearOutfitSlot" && asSvc != "deletePreset" && asSvc != "setNonFollowerLock"
        Return Parent.ServiceBool(asSvc, akA, akB, asArg, afArg)
    EndIf
    SeverActions_Outfit outfitScript = GetOwningQuest() as SeverActions_Outfit
    Actor a = akA as Actor
    If !outfitScript || !a
        Return False
    EndIf
    If asSvc == "assignOutfitSlot"
        outfitScript.AssignOutfitSlot(a)
        Return True
    ElseIf asSvc == "clearOutfitSlot"
        outfitScript.ClearOutfitSlot(a)
        Return True
    ElseIf asSvc == "deletePreset"
        If asArg == ""
            Return False
        EndIf
        outfitScript.DeletePreset(a, asArg)
        Return True
    ElseIf asSvc == "setNonFollowerLock"
        outfitScript.SetNonFollowerOutfitLock(a, afArg != 0.0)
        Return outfitScript.HasNonFollowerOutfitLock(a)
    EndIf
    Return Parent.ServiceBool(asSvc, akA, akB, asArg, afArg)
EndFunction

Event OnInit()
    ; Log only: setup runs from the load stages, since a re-added script gets no OnInit (DR20, F35).
    Debug.Trace("[SeverActions] provider outfit: bound (alias 267)")
EndEvent
