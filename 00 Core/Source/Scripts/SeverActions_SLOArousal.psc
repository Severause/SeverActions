Scriptname SeverActions_SLOArousal extends Quest
{SkyrimNet integration for SL OAroused NG - Event Logging Version}

; =============================================================================
; DECORATORS (Global for template access)
; =============================================================================

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

; =============================================================================
; ACTION EXECUTION (Instance Functions)
; =============================================================================

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
        ; Use UpdateActorExposure to add the delta directly to the exposure component.
        ; Previously used SetActorExposure(GetActorArousal + amount) which treated total
        ; arousal as the base, causing exposure to balloon when other sources were high.
        sla.UpdateActorExposure(akActor, amount as Int)
        main.UpdateSingleActorArousal(akActor)

        String stateDesc = ArousalToDescription(sla.GetActorArousal(akActor))

        If amount > 0
            SkyrimNetApi.RegisterEvent("arousal_increase", akActor.GetDisplayName() + " arousal increased to " + stateDesc, akActor, None)
        ElseIf amount < 0
            SkyrimNetApi.RegisterEvent("arousal_decrease", akActor.GetDisplayName() + " arousal decreased to " + stateDesc, akActor, None)
        EndIf
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

    Int oldArousal = GetActorArousal(akActor)

    slaFrameworkScr sla = Quest.GetQuest("sla_Framework") as slaFrameworkScr
    slaMainScr main = Quest.GetQuest("sla_Main") as slaMainScr

    If sla && main
        ; Total arousal = exposure + other sources (TimeRate, Libido, keywords, etc.)
        ; To reach a target total, set exposure to: target - (total - exposure)
        ; This accounts for non-exposure contributions so the final total lands where intended.
        Int currentTotal = sla.GetActorArousal(akActor)
        Int currentExposure = sla.GetActorExposure(akActor)
        Int nonExposure = currentTotal - currentExposure
        Int targetExposure = (level as Int) - nonExposure
        sla.SetActorExposure(akActor, targetExposure)
        main.UpdateSingleActorArousal(akActor)

        Int finalArousal = sla.GetActorArousal(akActor)
        String stateDesc = ArousalToDescription(finalArousal)

        If finalArousal > oldArousal
            SkyrimNetApi.RegisterEvent("arousal_increase", akActor.GetDisplayName() + " arousal increased to " + stateDesc, akActor, None)
        ElseIf finalArousal < oldArousal
            SkyrimNetApi.RegisterEvent("arousal_decrease", akActor.GetDisplayName() + " arousal decreased to " + stateDesc, akActor, None)
        EndIf
    EndIf
EndFunction

; =============================================================================
; CORE HELPERS
; =============================================================================

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
    ; Check body slot (32 = body)
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