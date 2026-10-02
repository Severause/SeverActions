Scriptname SeverActions_Mod_ArousalOsl extends SeverActions_ModuleBase
{Provider of the "arousal_osl" module (OSL Aroused), alias 271 of quest 0x000D62; the contract
 is SeverActions_ModuleBase's. No load stages: the OSL Aroused decorator is native
 (SkyrimNetBridge) and SeverActions_Arousal has no load work.}

String Function BundleId()
    Return "arousal_osl"
EndFunction

Int Function ContractVersion()
    ; A literal, not kContractVersion (that resolves on the base at run time and always agrees,
    ; so K2 could never catch a mismatch); check 13 (c) keeps it equal to the base's constant.
    Return 1
EndFunction

Event OnInit()
    ; No setup here (DR20): a script re-added to a save that once held it gets no OnInit (F35).
    Debug.Trace("[SeverActions] provider arousal_osl: bound (alias 271)")
EndEvent
