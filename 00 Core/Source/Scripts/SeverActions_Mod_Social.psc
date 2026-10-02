Scriptname SeverActions_Mod_Social extends SeverActions_ModuleBase
{Provider of the "social" module, alias 262 of quest 0x000D62; the contract is
 SeverActions_ModuleBase's. The hosts are SeverActions_Ambient (ambient banter and actions) and
 SeverActions_Familiarity (the reputation assessment); Ambient's always-on chronometer chain
 (30 s, 2 s while a social gate is polled) is the one the watchdog heals.}

String Function BundleId()
    Return "social"
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
        ; Maintenance registers each host's events (DR16); Ambient's also arms its tick.
        SeverActions_Ambient ambient = q as SeverActions_Ambient
        If ambient
            ambient.Maintenance()
            Debug.Trace("[SeverActions] Ambient initialized (ambient banter, actions)")
        Else
            Debug.Trace("[SeverActions] Ambient not found (optional)")
        EndIf
        SeverActions_Familiarity familiarity = q as SeverActions_Familiarity
        If familiarity
            familiarity.Maintenance()
            Debug.Trace("[SeverActions] Familiarity initialized (reputation assessment)")
        Else
            Debug.Trace("[SeverActions] Familiarity not found (optional)")
        EndIf
    EndIf
EndFunction

String[] Function ChronoTickNames()
    {The always-on chain the watchdog (Init K4, R13) heals: the ambient pass.}
    String[] names = new String[1]
    names[0] = "SeverActions_Tick_Ambient"
    Return names
EndFunction

Function OnChronoDead(String asTickName)
    {Re-arm the chain the watchdog found unacknowledged since load.}
    If asTickName == "SeverActions_Tick_Ambient"
        SeverActions_Ambient ambientKick = GetOwningQuest() as SeverActions_Ambient
        If ambientKick
            ambientKick.ChronoArm(0.1)
        EndIf
    EndIf
EndFunction

Event OnInit()
    ; No setup here (DR20): a script re-added to a save that once held it gets no OnInit (F35).
    Debug.Trace("[SeverActions] provider social: bound (alias 262)")
EndEvent
