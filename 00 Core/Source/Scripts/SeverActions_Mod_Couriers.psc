Scriptname SeverActions_Mod_Couriers extends SeverActions_ModuleBase
{Provider of the "couriers" support bundle (couriers and ambushes), alias 259 of quest 0x000D62;
 the contract is SeverActions_ModuleBase's. Stage 1 runs the Courier and Ambush Maintenance
 (listeners, the load teardown of a live standoff, ticks re-armed while work waits). K4 watches
 neither tick: both arm only while there is work, and an idle watched chain reads as dead.
 Service: "dispatchCourier" (the MCM's test letter).}

String Function BundleId()
    Return "couriers"
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
        SeverActions_Courier courier = q as SeverActions_Courier
        If courier
            courier.Maintenance()
        Else
            Debug.Trace("[SeverActions] WARNING: SeverActions_Courier not found")
        EndIf
        SeverActions_Ambush ambush = q as SeverActions_Ambush
        If ambush
            ambush.Maintenance()
        Else
            Debug.Trace("[SeverActions] WARNING: SeverActions_Ambush not found")
        EndIf
        Debug.Trace("[SeverActions] Couriers initialized (load recovery run)")
    EndIf
EndFunction

Int Function ServiceInt(String asSvc, Form akA, Form akB, String asArg, Float afArg)
    {"dispatchCourier": queue a letter from akA (the sender, may be None); asArg = reason, subject
     and body joined by newlines ("meet\nA Word\n...", neither header containing one). Returns 1
     when queued, 0 on bad args. The MCM's Enterprises debug harness calls it.}
    If asSvc != "dispatchCourier"
        Return Parent.ServiceInt(asSvc, akA, akB, asArg, afArg)
    EndIf
    SeverActions_Courier courier = GetOwningQuest() as SeverActions_Courier
    If !courier
        Return 0
    EndIf
    Int nl1 = StringUtil.Find(asArg, "\n")
    If nl1 < 0
        Return 0
    EndIf
    String reason = StringUtil.Substring(asArg, 0, nl1)
    String rest = StringUtil.Substring(asArg, nl1 + 1, 0)
    Int nl2 = StringUtil.Find(rest, "\n")
    If nl2 < 0
        Return 0
    EndIf
    String subject = StringUtil.Substring(rest, 0, nl2)
    String body = StringUtil.Substring(rest, nl2 + 1, 0)
    Return courier.DispatchCourier(akA as Actor, subject, body, reason)
EndFunction

Event OnInit()
    ; No setup here (DR20): a script re-added to a save that once held it gets no OnInit (F35).
    Debug.Trace("[SeverActions] provider couriers: bound (alias 259)")
EndEvent
