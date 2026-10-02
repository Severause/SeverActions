Scriptname SeverActions_Mod_Economy extends SeverActions_ModuleBase
{Provider of the "economy" module (Economy & Crafting): alias 269 of quest 0x000D62 (plan 3.0
 M-P). Init K3 runs its idempotent OnModuleLoad stages on every load (DR20); they forward to the
 module's host scripts, which register their own events (DR16). Stage 1 runs Debt's, Currency's
 and Crafting's Maintenance.}

String Function BundleId()
    Return "economy"
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
        ; Debt's Maintenance, then Currency's (the verb and CollectPayment listeners).
        SeverActions_Debt debt = q as SeverActions_Debt
        If debt
            debt.Maintenance()
            Int debtCount = debt.GetDebtCount()
            Debug.Trace("[SeverActions] Debt System initialized - " + debtCount + " active debts")
        Else
            Debug.Trace("[SeverActions] Debt System not found (optional)")
        EndIf
        SeverActions_Currency currency = q as SeverActions_Currency
        If currency
            currency.Maintenance()
            Debug.Trace("[SeverActions] Currency load recovery complete")
        EndIf
        ; Crafting: its registrations and its commission tick.
        SeverActions_Crafting crafting = q as SeverActions_Crafting
        If crafting
            crafting.Maintenance()
        EndIf
    EndIf
EndFunction

String[] Function ChronoTickNames()
    {The always-on tick chains the Init K4 watchdog heals: Debt's and Crafting's re-arm on
     every wake, so a zero count means a dead chain.}
    String[] names = new String[2]
    names[0] = "SeverActions_Tick_Debt"
    names[1] = "SeverActions_Tick_Crafting"
    Return names
EndFunction

Function OnChronoDead(String asTickName)
    {Re-arm the chain the watchdog found unacknowledged since load.}
    Quest q = GetOwningQuest()
    If asTickName == "SeverActions_Tick_Debt"
        SeverActions_Debt debtKick = q as SeverActions_Debt
        If debtKick
            debtKick.ChronoArm(0.1)
        EndIf
    ElseIf asTickName == "SeverActions_Tick_Crafting"
        SeverActions_Crafting craftKick = q as SeverActions_Crafting
        If craftKick
            craftKick.ChronoArm(0.1)
        EndIf
    EndIf
EndFunction

Bool Function ServiceBool(String asSvc, Form akA, Form akB, String asArg, Float afArg)
    {The debt ledger's two entry points for SeverActions_Loot (which may not name Debt, DR2).
     True once forwarded; False without the module or both actors, or when afArg is under 1 gold.
     "autoAddToDebt": akA (the giver) is a creditor of akB (the receiver) - grow that debt by
     afArg gold (Debt.AutoAddToDebt; a no-op when no such debt exists).
     "reduceDebtByPayment": akA (the collector) just took afArg gold from akB (the payer) -
     settle it toward what akB owes akA (Debt.ReduceDebtByPayment; never below zero).}
    If asSvc != "autoAddToDebt" && asSvc != "reduceDebtByPayment"
        Return Parent.ServiceBool(asSvc, akA, akB, asArg, afArg)
    EndIf
    SeverActions_Debt debt = GetOwningQuest() as SeverActions_Debt
    Actor a = akA as Actor
    Actor b = akB as Actor
    Int gold = afArg as Int
    If !debt || !a || !b || gold <= 0
        Return False
    EndIf
    If asSvc == "autoAddToDebt"
        debt.AutoAddToDebt(a, b, gold)
    Else
        debt.ReduceDebtByPayment(a, b, gold)
    EndIf
    Return True
EndFunction

Event OnInit()
    ; Log only: setup runs from the load stages, since a re-added script gets no OnInit (DR20, F35).
    Debug.Trace("[SeverActions] provider economy: bound (alias 269)")
EndEvent
