Scriptname SeverActions_Mod_Arrest extends SeverActions_ModuleBase
{Provider of the "arrest" module (Crime, Arrest & Captives), alias 263 of quest 0x000D62; the
 contract is SeverActions_ModuleBase's. The stages forward to the host scripts by typed cast
 (DR2), and the hosts register their own events (DR16). K4 watches only SeverActions_Kidnap's
 always-on 30 s captivity pass; the Arrest and ArrestPlayer ticks arm only while an arrest runs.}

String Function BundleId()
    Return "arrest"
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
        ; Arrest's load pass (maintenance, holds, jailed-NPC migration and checks) runs before
        ; ArrestPlayer's recovery.
        SeverActions_Arrest arrest = q as SeverActions_Arrest
        If arrest
            arrest.OnGameLoaded()
            Debug.Trace("[SeverActions] Arrest System initialized (load recovery run)")
        Else
            Debug.Trace("[SeverActions] Arrest System not found (optional)")
        EndIf
        NoteLeashFrameworkVersion()
        SeverActions_ArrestPlayer arrestPlayer = q as SeverActions_ArrestPlayer
        If arrestPlayer
            arrestPlayer.OnGameLoaded()
            Debug.Trace("[SeverActions] ArrestPlayer load recovery complete")
        EndIf
        ; The captivity load pass: native toggles, event registrations, the alias-pool sweep,
        ; the bound-pose re-play and the tick's arm.
        SeverActions_Kidnap kidnap = q as SeverActions_Kidnap
        If kidnap
            kidnap.KidnapMaintenance()
            Debug.Trace("[SeverActions] Kidnap load recovery complete")
        Else
            Debug.Trace("[SeverActions] Kidnap script not found (optional)")
        EndIf
    EndIf
EndFunction

String[] Function ChronoTickNames()
    {The always-on chain the watchdog (Init K4, R13) heals: the captivity pass.}
    String[] names = new String[1]
    names[0] = "SeverActions_Tick_Kidnap"
    Return names
EndFunction

Function OnChronoDead(String asTickName)
    {Re-arm the chain the watchdog found unacknowledged since load.}
    If asTickName == "SeverActions_Tick_Kidnap"
        SeverActions_Kidnap kidnapKick = GetOwningQuest() as SeverActions_Kidnap
        If kidnapKick
            kidnapKick.ChronoArm(0.1)
        EndIf
    EndIf
EndFunction

Function NoteLeashFrameworkVersion()
    {Every leash rope assumes Leash Framework 1.1.1's wrist attachment: warn a 1.1.0 install once
     per playthrough (LeashLib's sentinel). The notice's only load-path caller.}
    If SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled()
        SeverActions_LeashLib.WarnIfOutdated()
    EndIf
EndFunction

Event OnInit()
    ; No setup here (DR20): a script re-added to a save that once held it gets no OnInit (F35).
    Debug.Trace("[SeverActions] provider arrest: bound (alias 263)")
EndEvent
