Scriptname SeverActions_SLOArousal extends Quest
{SL OAroused NG for SkyrimNet: the get_slo_* decorators and the ModifyArousal action (no action
 YAML calls SetArousal_Execute). Neither _Execute registers an event: arousal is private (0155).}

Function RegisterDecorators()
    {Register the decorators when SexLabAroused.esm is loaded; the arousal_slo provider's stage 0
     calls it on every load. Idempotent: SkyrimNet replaces a same-name registration.}
    If Game.GetModByName("SexLabAroused.esm") == 255
        Return
    EndIf
    Int result
    result = SkyrimNetApi.RegisterDecorator("get_slo_arousal_state", "SeverActions_SLOArousal", "GetSLOArousalState")
    Debug.Trace("[SeverActions] get_slo_arousal_state: " + (result == 0) as String)
    result = SkyrimNetApi.RegisterDecorator("get_slo_arousal", "SeverActions_SLOArousal", "GetSLOArousal")
    Debug.Trace("[SeverActions] get_slo_arousal: " + (result == 0) as String)
    result = SkyrimNetApi.RegisterDecorator("get_slo_arousal_desc", "SeverActions_SLOArousal", "GetSLOArousalDesc")
    Debug.Trace("[SeverActions] get_slo_arousal_desc: " + (result == 0) as String)
    result = SkyrimNetApi.RegisterDecorator("get_slo_is_naked", "SeverActions_SLOArousal", "GetSLOIsNaked")
    Debug.Trace("[SeverActions] get_slo_is_naked: " + (result == 0) as String)
EndFunction

; Decorators: Globals, called by SkyrimNet by script and function name.

String Function GetSLOArousalState(Actor akActor) Global
    Int arousal
    String arousalState
    Bool isNaked
    String nakedStr
    
    If !akActor
        Return "{\"arousal\": 0, \"state\": \"unknown\", \"naked\": false}"
    EndIf
    
    arousal = GetActorArousal(akActor)
    arousalState = ArousalToDescription(arousal)
    isNaked = IsActorNaked(akActor)
    
    nakedStr = "false"
    If isNaked
        nakedStr = "true"
    EndIf
    
    Return "{\"arousal\": " + arousal + ", \"state\": \"" + arousalState + "\", \"naked\": " + nakedStr + "}"
EndFunction

String Function GetSLOArousal(Actor akActor) Global
    If !akActor
        Return "0"
    EndIf
    Return GetActorArousal(akActor) as String
EndFunction

String Function GetSLOArousalDesc(Actor akActor) Global
    If !akActor
        Return "not aroused"
    EndIf
    Return ArousalToDescription(GetActorArousal(akActor))
EndFunction

String Function GetSLOIsNaked(Actor akActor) Global
    If !akActor
        Return "false"
    EndIf
    If IsActorNaked(akActor)
        Return "true"
    EndIf
    Return "false"
EndFunction

; Actions (member functions: SkyrimNet calls instance.Function()).

Function ModifyArousal_Execute(Actor akActor, Float amount)
    If !akActor
        Return
    EndIf

    If amount > 100.0
        amount = 100.0
    ElseIf amount < -100.0
        amount = -100.0
    EndIf

    slaFrameworkScr sla = Quest.GetQuest("sla_Framework") as slaFrameworkScr
    slaMainScr main = Quest.GetQuest("sla_Main") as slaMainScr

    If sla && main
        ; Add the delta to exposure alone: SetActorExposure(GetActorArousal + amount) would take
        ; total arousal as the base and balloon exposure when other sources are high.
        sla.UpdateActorExposure(akActor, amount as Int)
        main.UpdateSingleActorArousal(akActor)
    EndIf
EndFunction

Function SetArousal_Execute(Actor akActor, Float level)
    If !akActor
        Return
    EndIf

    If level > 100.0
        level = 100.0
    ElseIf level < 0.0
        level = 0.0
    EndIf

    slaFrameworkScr sla = Quest.GetQuest("sla_Framework") as slaFrameworkScr
    slaMainScr main = Quest.GetQuest("sla_Main") as slaMainScr

    If sla && main
        ; Total = exposure + other sources (TimeRate, Libido, keywords), so the exposure that
        ; lands the total on the target is target - (total - exposure).
        Int currentTotal = sla.GetActorArousal(akActor)
        Int currentExposure = sla.GetActorExposure(akActor)
        Int nonExposure = currentTotal - currentExposure
        Int targetExposure = (level as Int) - nonExposure
        sla.SetActorExposure(akActor, targetExposure)
        main.UpdateSingleActorArousal(akActor)
    EndIf
EndFunction

Int Function GetActorArousal(Actor akActor) Global
    slaFrameworkScr sla = Quest.GetQuest("sla_Framework") as slaFrameworkScr
    If sla
        Return sla.GetActorArousal(akActor)
    EndIf
    Return 0
EndFunction

Bool Function IsActorNaked(Actor akActor) Global
    If !akActor
        Return False
    EndIf
    ; Slot 32 (body) is mask 0x4.
    Return akActor.GetWornForm(0x00000004) == None
EndFunction

String Function ArousalToDescription(Int arousal) Global
    If arousal < 10
        Return "not aroused"
    ElseIf arousal < 25
        Return "slightly aroused"
    ElseIf arousal < 40
        Return "somewhat aroused"
    ElseIf arousal < 55
        Return "moderately aroused"
    ElseIf arousal < 70
        Return "quite aroused"
    ElseIf arousal < 85
        Return "very aroused"
    ElseIf arousal < 95
        Return "extremely aroused"
    Else
        Return "overwhelmingly aroused"
    EndIf
EndFunction