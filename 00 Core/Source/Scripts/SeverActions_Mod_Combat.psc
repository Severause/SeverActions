Scriptname SeverActions_Mod_Combat extends SeverActions_ModuleBase
{Provider of the "combat" module (Combat & Brawls), alias 264 of quest 0x000D62; the contract is
 SeverActions_ModuleBase's. The stages forward to the host scripts by typed cast (DR2), and the
 hosts register their own events (DR16).
 No tick is watched (K4). Brawl arms SeverActions_Tick_Brawl on every load, but its quiet path
 returns without a Request or Cancel, so the chronometer never counts a tick acknowledged
 (Chronometer.h awaitingAck) and K4 would report the DLL out of date in every quiet game.
 Combat arms no chain.}

String Function BundleId()
    Return "combat"
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
        ; Each host's RegisterEvents registers on the quest handle old saves hold (DR16) and
        ; pushes its owner-hosted properties into the natives before anything reads them back.
        SeverActions_Combat combatReg = q as SeverActions_Combat
        If combatReg
            combatReg.RegisterEvents()
        EndIf
        SeverActions_Brawl brawlReg = q as SeverActions_Brawl
        If brawlReg
            brawlReg.RegisterEvents()
        EndIf
    EndIf
    If aiStage == 1
        SeverActions_Combat combat = q as SeverActions_Combat
        If combat
            combat.HealPlayerAggression()
            combat.OnGameLoaded()
            Debug.Trace("[SeverActions] Combat load recovery complete")
        EndIf
        SeverActions_Brawl brawl = q as SeverActions_Brawl
        If brawl
            brawl.OnGameLoaded()
            Debug.Trace("[SeverActions] Brawl load recovery complete")
        EndIf
    EndIf
EndFunction

Event OnInit()
    ; No setup here (DR20): a script re-added to a save that once held it gets no OnInit (F35).
    Debug.Trace("[SeverActions] provider combat: bound (alias 264)")
EndEvent
