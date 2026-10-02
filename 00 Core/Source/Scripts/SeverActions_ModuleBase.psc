Scriptname SeverActions_ModuleBase extends ReferenceAlias
{The kernel's base type for module providers (plan 3.0 M-P). A provider is one
 SeverActions_Mod_<Name> script extending this type on one appended alias of quest
 0x000D62 (ids 258-273, Optional, never filled): the kernel's synchronous way into
 module code (the load stages) and a module's into an OPTIONAL module (the services).
 Callers name only THIS type, through the Global helpers below: a script naming an
 absent SeverActions_Mod_* type is dead on the stock VM.
 Contract:
 - BundleId() = the module id in fomod/modules.json; ContractVersion() = the literal
   the provider was compiled against, which Init K2 compares with kContractVersion.
 - OnModuleLoad(stage, newGame) runs on every load and new game from Init K3
   (RunProviderStages), in ProviderBundleIds() order, stage by stage (0 registrations
   and migration claims, 1 maintenance, 2 late passes needing another module's stage 1).
   Every stage is idempotent: first-time setup on an existing save is just the first
   pass, and nothing relies on OnInit (DR20).
 - Providers never register anything (DR16): a stage calls the module's quest script.
 - Service*(svc, a, b, arg, farg): an unknown service returns the default and is
   logged; callers read a default as "not available".
 - ProbeLiveState(): a cheap count of live Papyrus-only state, for the install guard.
 The provider table is GENERATED into the marked blocks below from fomod/modules.json
 (Invoke-SaModuleBase.ps1 -Write; check 13 (c)).}

Int Property kContractVersion = 1 AutoReadOnly
{The kernel/provider contract version. A provider's ContractVersion() returns a
 LITERAL equal to this, never this property (a propget resolves on the base and would
 always agree); Init K2 skips a mismatch. Check 13 (c) keeps the literals equal.}

; Unknown services already logged, so a polling caller does not flood the log. Script
; variables persist in the save, so stage 0 resets the list.
String[] _unknownLogged
Int _unknownCount = 0

; Provider contract (overridden by SeverActions_Mod_<Name>)

String Function BundleId()
    {The module id this provider serves. The base answers "" (no provider).}
    Return ""
EndFunction

Int Function ContractVersion()
    {The contract the provider was compiled against. Overrides return a literal (1).}
    Return 0
EndFunction

Function OnModuleLoad(Int aiStage, Bool abNewGame)
    {Stage 0, 1 or 2 of the load. Overrides call Parent.OnModuleLoad FIRST, so stage 0
     resets the base's per-session state.}
    If aiStage == 0
        _unknownCount = 0
        _unknownLogged = new String[8]
    EndIf
EndFunction

String[] Function ChronoTickNames()
    {The chronometer tick names this module arms (SeverActions_Tick_<Script>), for
     Init K4's watchdog. The base returns no array (an unassigned variable); callers
     test the result before .Length.}
    String[] noNames
    Return noNames
EndFunction

Function OnChronoDead(String asTickName)
    {The watchdog found asTickName unacknowledged since load: re-arm that chain.}
EndFunction

Bool Function ServiceBool(String asSvc, Form akA, Form akB, String asArg, Float afArg)
    _NoteUnknownService(asSvc)
    Return False
EndFunction

Int Function ServiceInt(String asSvc, Form akA, Form akB, String asArg, Float afArg)
    _NoteUnknownService(asSvc)
    Return 0
EndFunction

Float Function ServiceFloat(String asSvc, Form akA, Form akB, String asArg, Float afArg)
    _NoteUnknownService(asSvc)
    Return 0.0
EndFunction

String Function ServiceString(String asSvc, Form akA, Form akB, String asArg, Float afArg)
    _NoteUnknownService(asSvc)
    Return ""
EndFunction

Form Function ServiceForm(String asSvc, Form akA, Form akB, String asArg, Float afArg)
    _NoteUnknownService(asSvc)
    Return None
EndFunction

Int Function ProbeLiveState()
    {How many live things this module's Papyrus-only state holds (0 = none).}
    Return 0
EndFunction

Function _NoteUnknownService(String asSvc)
    {Log a service this provider does not implement, once per name per session.}
    If !_unknownLogged
        _unknownLogged = new String[8]
        _unknownCount = 0
    EndIf
    Int i = 0
    While i < _unknownCount
        If _unknownLogged[i] == asSvc
            Return
        EndIf
        i += 1
    EndWhile
    If _unknownCount < _unknownLogged.Length
        _unknownLogged[_unknownCount] = asSvc
        _unknownCount += 1
    EndIf
    Debug.Trace("[SeverActions] provider " + BundleId() + ": unknown service '" + asSvc + "' - default returned")
EndFunction

; Global helpers (name only kernel types)

Int Function ProviderAliasId(String asBundle) Global
    {The alias of quest 0x000D62 that carries asBundle's provider, or -1. GENERATED.}
    ; BEGIN GENERATED provider table (fomod/modules.json providerAliasId; scripts/fomod/Invoke-SaModuleBase.ps1 -Write)
    ; 16 providers, plan 3.0 static load order; alias ids frozen (plan A7, 6.1)
    If asBundle == "travelcore"
        Return 258
    ElseIf asBundle == "couriers"
        Return 259
    ElseIf asBundle == "followers"
        Return 260
    ElseIf asBundle == "companions"
        Return 261
    ElseIf asBundle == "social"
        Return 262
    ElseIf asBundle == "arrest"
        Return 263
    ElseIf asBundle == "combat"
        Return 264
    ElseIf asBundle == "travel"
        Return 265
    ElseIf asBundle == "items"
        Return 266
    ElseIf asBundle == "outfit"
        Return 267
    ElseIf asBundle == "survival"
        Return 268
    ElseIf asBundle == "economy"
        Return 269
    ElseIf asBundle == "enterprises"
        Return 270
    ElseIf asBundle == "arousal_osl"
        Return 271
    ElseIf asBundle == "arousal_slo"
        Return 272
    ElseIf asBundle == "fertility"
        Return 273
    EndIf
    Return -1
    ; END GENERATED provider table
EndFunction

String[] Function ProviderBundleIds() Global
    {Every provider's module id in the plan's static load order (Init K2/K3 walk it). GENERATED.}
    ; BEGIN GENERATED provider table (fomod/modules.json providerAliasId; scripts/fomod/Invoke-SaModuleBase.ps1 -Write)
    String[] ids = new String[16]
    ids[0] = "travelcore"
    ids[1] = "couriers"
    ids[2] = "followers"
    ids[3] = "companions"
    ids[4] = "social"
    ids[5] = "arrest"
    ids[6] = "combat"
    ids[7] = "travel"
    ids[8] = "items"
    ids[9] = "outfit"
    ids[10] = "survival"
    ids[11] = "economy"
    ids[12] = "enterprises"
    ids[13] = "arousal_osl"
    ids[14] = "arousal_slo"
    ids[15] = "fertility"
    Return ids
    ; END GENERATED provider table
EndFunction

SeverActions_ModuleBase Function Provider(String asBundle) Global
    {asBundle's provider, or None when it is not installed (no script on the alias,
     or its pex is absent: the cast answers None).}
    Int id = ProviderAliasId(asBundle)
    If id < 0
        Return None
    EndIf
    Quest q = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
    If !q
        Return None
    EndIf
    Return q.GetAlias(id) as SeverActions_ModuleBase
EndFunction

Bool Function IsBound(String asBundle) Global
    {True when asBundle's provider is present and answers its own id.}
    SeverActions_ModuleBase p = Provider(asBundle)
    Return p && p.BundleId() == asBundle
EndFunction

Bool Function CallBool(String asBundle, String asSvc, Form akA = None, Form akB = None, String asArg = "", Float afArg = 0.0) Global
    {A service call into an optional module: the default (False) when it is absent.}
    SeverActions_ModuleBase p = Provider(asBundle)
    If !p
        Return False
    EndIf
    Return p.ServiceBool(asSvc, akA, akB, asArg, afArg)
EndFunction

Int Function CallInt(String asBundle, String asSvc, Form akA = None, Form akB = None, String asArg = "", Float afArg = 0.0) Global
    SeverActions_ModuleBase p = Provider(asBundle)
    If !p
        Return 0
    EndIf
    Return p.ServiceInt(asSvc, akA, akB, asArg, afArg)
EndFunction

Float Function CallFloat(String asBundle, String asSvc, Form akA = None, Form akB = None, String asArg = "", Float afArg = 0.0) Global
    SeverActions_ModuleBase p = Provider(asBundle)
    If !p
        Return 0.0
    EndIf
    Return p.ServiceFloat(asSvc, akA, akB, asArg, afArg)
EndFunction

String Function CallString(String asBundle, String asSvc, Form akA = None, Form akB = None, String asArg = "", Float afArg = 0.0) Global
    SeverActions_ModuleBase p = Provider(asBundle)
    If !p
        Return ""
    EndIf
    Return p.ServiceString(asSvc, akA, akB, asArg, afArg)
EndFunction

Form Function CallForm(String asBundle, String asSvc, Form akA = None, Form akB = None, String asArg = "", Float afArg = 0.0) Global
    SeverActions_ModuleBase p = Provider(asBundle)
    If !p
        Return None
    EndIf
    Return p.ServiceForm(asSvc, akA, akB, asArg, afArg)
EndFunction

; Verb decoding (plan 3.0 M-V). The DLL sends each UI verb (Native/data/verb_table.json)
; to the owning module's dispatcher as SeverActions_Verb_<Name> (callback OnVerb_<Name>,
; one dispatcher script per module, DR10); strArg is 8
; pipe fields, actionId|target|target2|str|int|str2|targetFid|target2Fid (FormIDs
; signed decimal). These two Globals are the one decoder every dispatcher shares.

String Function VerbField(String asData, Int aiIndex) Global
    {The aiIndex-th pipe field of a verb payload (0 = the actionId); "" past the end.
     An empty field ("||") is returned as "" explicitly: SKSE's Substring reads a zero
     length as "to the end".}
    Int pos = 0
    Int fieldNum = 0
    Int len = StringUtil.GetLength(asData)
    While fieldNum < aiIndex && pos < len
        Int pipePos = StringUtil.Find(asData, "|", pos)
        If pipePos < 0
            Return ""
        EndIf
        pos = pipePos + 1
        fieldNum += 1
    EndWhile
    If pos >= len
        Return ""
    EndIf
    Int nextPipe = StringUtil.Find(asData, "|", pos)
    If nextPipe < 0
        Return StringUtil.Substring(asData, pos)
    EndIf
    If nextPipe == pos
        Return ""
    EndIf
    Return StringUtil.Substring(asData, pos, nextPipe - pos)
EndFunction

Actor Function VerbActor(Form akSender, Int aiFormId, String asName) Global
    {The actor a verb names: the event's sender (the picker's exact identity) first,
     then the encoded FormID, then the name ("Player", else the fuzzy FindActorByName).
     None when nothing resolves. The exact identities come first because the fuzzy
     match can pick the wrong same-named NPC, and some verbs are hostile.}
    Actor a = akSender as Actor
    If !a && aiFormId != 0
        a = Game.GetFormEx(aiFormId) as Actor
    EndIf
    If !a && asName != ""
        If asName == "Player" || asName == "player"
            a = Game.GetPlayer()
        Else
            a = SeverActionsNative.FindActorByName(asName)
        EndIf
    EndIf
    Return a
EndFunction

; The follow gate (plan D45)

Bool Function IsFollowHandsOff(Actor akActor) Global
    {The FOLLOW gate every script asks before leading an actor: True when SA must not
     lead akActor (follow package or wait sandbox) because someone else owns them
     (Native_IsTrackOnlyFollower: NFF, DLC, custom AI) or the player is in Tracking
     mode (frameworkMode 1), where SA leads nobody. Home and schedule orders are the
     player's own and stay live in Tracking mode: their sites read the ownership verdict
     alone. FollowerManager keeps
     a member copy of the same test.}
    If !akActor
        Return False
    EndIf
    If SeverActionsNativeExt2.Settings_GetInt("frameworkMode") == 1
        Return True
    EndIf
    Return SeverActionsNativeExt2.Native_IsTrackOnlyFollower(akActor)
EndFunction
