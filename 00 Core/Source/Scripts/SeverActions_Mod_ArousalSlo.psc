Scriptname SeverActions_Mod_ArousalSlo extends SeverActions_ModuleBase
{Provider of the "arousal_slo" module (SL Aroused), alias 272 of quest 0x000D62; the contract
 is SeverActions_ModuleBase's.}

String Function BundleId()
    Return "arousal_slo"
EndFunction

Int Function ContractVersion()
    ; A literal, not kContractVersion (that resolves on the base at run time and always agrees,
    ; so K2 could never catch a mismatch); check 13 (c) keeps it equal to the base's constant.
    Return 1
EndFunction

Function OnModuleLoad(Int aiStage, Bool abNewGame)
    Parent.OnModuleLoad(aiStage, abNewGame)
    Quest q = GetOwningQuest()
    If !q
        Return
    EndIf
    If aiStage == 0
        ; The SL Aroused decorators; RegisterDecorators skips itself without SexLabAroused.esm.
        SeverActions_SLOArousal slo = q as SeverActions_SLOArousal
        If slo
            slo.RegisterDecorators()
        EndIf
    EndIf
EndFunction

Event OnInit()
    ; No setup here (DR20): a script re-added to a save that once held it gets no OnInit (F35).
    Debug.Trace("[SeverActions] provider arousal_slo: bound (alias 272)")
EndEvent
