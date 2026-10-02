Scriptname SeverActions_Mod_Fertility extends SeverActions_ModuleBase
{Provider of the "fertility" module (Fertility Mode), alias 273 of quest 0x000D62; the contract
 is SeverActions_ModuleBase's. K4 watches no tick: the bridge's arms only with Fertility Mode
 present and enabled.}

String Function BundleId()
    Return "fertility"
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
        ; The decorators and the native FM module; both skip themselves without the esm.
        SeverActions_FertilityMode_Bridge bridge = q as SeverActions_FertilityMode_Bridge
        If bridge
            bridge.RegisterDecorators()
            bridge.InitializeNative()
        EndIf
    EndIf
    If aiStage == 1
        SeverActions_FertilityMode_Bridge bridge = q as SeverActions_FertilityMode_Bridge
        If bridge
            Debug.Trace("[SeverActions] Calling FertilityBridge.Maintenance()...")
            bridge.Maintenance()
        Else
            Debug.Trace("[SeverActions] WARNING: Could not cast quest to FertilityBridge")
        EndIf
    EndIf
EndFunction

Event OnInit()
    ; No setup here (DR20): a script re-added to a save that once held it gets no OnInit (F35).
    Debug.Trace("[SeverActions] provider fertility: bound (alias 273)")
EndEvent
