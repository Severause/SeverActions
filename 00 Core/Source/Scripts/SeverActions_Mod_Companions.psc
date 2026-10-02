Scriptname SeverActions_Mod_Companions extends SeverActions_ModuleBase
{Provider of the "companions" module (Companion Depth), alias 261 of quest 0x000D62; the contract
 is SeverActions_ModuleBase's. The hosts are SeverActions_CompanionMind (relationship assessment)
 and SeverActions_CompanionLife (off-screen life, banter), each with an always-on chronometer
 chain the watchdog heals.}

String Function BundleId()
    Return "companions"
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
        ; Each host's Maintenance registers its events (DR16) and arms its tick. The followers
        ; provider's stage 1 runs first in the static order, so the roster is settled.
        SeverActions_CompanionMind mind = q as SeverActions_CompanionMind
        If mind
            mind.Maintenance()
            Debug.Trace("[SeverActions] CompanionMind initialized (relationship assessment)")
        Else
            Debug.Trace("[SeverActions] CompanionMind not found (optional)")
        EndIf
        SeverActions_CompanionLife life = q as SeverActions_CompanionLife
        If life
            life.Maintenance()
            Debug.Trace("[SeverActions] CompanionLife initialized (off-screen life, banter)")
        Else
            Debug.Trace("[SeverActions] CompanionLife not found (optional)")
        EndIf
    EndIf
EndFunction

String[] Function ChronoTickNames()
    {The always-on chains the watchdog (Init K4, R13) heals.}
    String[] names = new String[2]
    names[0] = "SeverActions_Tick_CompanionMind"
    names[1] = "SeverActions_Tick_CompanionLife"
    Return names
EndFunction

Function OnChronoDead(String asTickName)
    {Re-arm the chain the watchdog found unacknowledged since load.}
    If asTickName == "SeverActions_Tick_CompanionMind"
        SeverActions_CompanionMind mindKick = GetOwningQuest() as SeverActions_CompanionMind
        If mindKick
            mindKick.ChronoArm(0.1)
        EndIf
    ElseIf asTickName == "SeverActions_Tick_CompanionLife"
        SeverActions_CompanionLife lifeKick = GetOwningQuest() as SeverActions_CompanionLife
        If lifeKick
            lifeKick.ChronoArm(0.1)
        EndIf
    EndIf
EndFunction

Event OnInit()
    ; No setup here (DR20): a script re-added to a save that once held it gets no OnInit (F35).
    Debug.Trace("[SeverActions] provider companions: bound (alias 261)")
EndEvent
