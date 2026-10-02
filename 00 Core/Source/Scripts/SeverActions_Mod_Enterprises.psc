Scriptname SeverActions_Mod_Enterprises extends SeverActions_ModuleBase
{Provider of the "enterprises" module, alias 270 of quest 0x000D62; the contract is
 SeverActions_ModuleBase's. Stage 1 runs SeverActions_Enterprises.Maintenance: the module's
 listeners, the Final Audit re-apply, the muster pump's kick, both pool sweeps, the premises
 re-derivation and the camp-cut migration. No chronometer tick for K4 to watch (the muster
 pump is a game-time update). Service: "collectAuthorizedTaxes".}

String Function BundleId()
    Return "enterprises"
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
    If aiStage == 1
        SeverActions_Enterprises ent = q as SeverActions_Enterprises
        If ent
            ent.Maintenance()
            Debug.Trace("[SeverActions] Enterprises initialized (load recovery run)")
        Else
            Debug.Trace("[SeverActions] WARNING: SeverActions_Enterprises not found")
        EndIf
    EndIf
EndFunction

Bool Function ServiceBool(String asSvc, Form akA, Form akB, String asArg, Float afArg)
    {"collectAuthorizedTaxes": akA is the Final Audit collector the player agreed to pay through
     an Economy action (Currency's CollectPayment redirect). Runs CollectAuthorizedTaxes(akA), as
     the LLM action does; returns its result. False for a non-actor akA or with no provider bound.}
    If asSvc != "collectAuthorizedTaxes"
        Return Parent.ServiceBool(asSvc, akA, akB, asArg, afArg)
    EndIf
    SeverActions_Enterprises ent = GetOwningQuest() as SeverActions_Enterprises
    Actor a = akA as Actor
    If !ent || !a
        Return False
    EndIf
    Return ent.CollectAuthorizedTaxes(a)
EndFunction

Event OnInit()
    ; No setup here (DR20): a script re-added to a save that once held it gets no OnInit (F35).
    Debug.Trace("[SeverActions] provider enterprises: bound (alias 270)")
EndEvent
