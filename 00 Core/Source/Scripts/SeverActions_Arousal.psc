Scriptname SeverActions_Arousal extends Quest
{OSL Aroused: the ModifyArousal action (no action YAML calls SetArousal_Execute). The
 get_arousal_state decorator is native (SkyrimNetBridge.h).}

; No longer registered as a decorator; kept for old frames and third-party callers. Its JSON
; shape differs from the native decorator's, and nothing in this tree calls it.

String Function GetArousalState(Actor akActor) Global
    if !akActor || akActor.IsDead()
        return "{\"available\":false}"
    endif
    
    if Game.GetModByName("OSLAroused.esp") == 255
        return "{\"available\":false,\"reason\":\"OSLAroused not installed\"}"
    endif
    
    float arousal = OSLArousedNative.GetArousal(akActor)
    float baseline = OSLArousedNative.GetArousalBaseline(akActor)
    float libido = OSLArousedNative.GetLibido(akActor)
    bool isNaked = OSLArousedNative.IsActorNaked(akActor)
    bool inScene = OSLArousedNative.IsInScene(akActor)
    
    String arousalDesc = GetArousalDescription(arousal)
    String libidoDesc = GetLibidoDescription(libido)
    
    String json = "{"
    json += "\"available\":true,"
    json += "\"arousal\":" + (arousal as Int) + ","
    json += "\"baseline\":" + (baseline as Int) + ","
    json += "\"libido\":" + (libido as Int) + ","
    json += "\"arousal_state\":\"" + arousalDesc + "\","
    json += "\"libido_state\":\"" + libidoDesc + "\","
    json += "\"is_naked\":" + BoolToString(isNaked) + ","
    json += "\"in_scene\":" + BoolToString(inScene)
    json += "}"
    
    return json
EndFunction

String Function GetArousalDescription(float arousal) Global
    if arousal < 10
        return "not aroused"
    elseif arousal < 25
        return "slightly aroused"
    elseif arousal < 50
        return "moderately aroused"
    elseif arousal < 75
        return "very aroused"
    elseif arousal < 90
        return "extremely aroused"
    else
        return "overwhelmed with desire"
    endif
EndFunction

String Function GetLibidoDescription(float libido) Global
    if libido < 20
        return "low libido"
    elseif libido < 40
        return "normal libido"
    elseif libido < 60
        return "moderate libido"
    elseif libido < 80
        return "high libido"
    else
        return "insatiable"
    endif
EndFunction

String Function BoolToString(bool value) Global
    if value
        return "true"
    else
        return "false"
    endif
EndFunction

; Action: ModifyArousal.

Bool Function ModifyArousal_IsEligible(Actor akActor, float amount)
    if !akActor || akActor.IsDead()
        return false
    endif
    if Game.GetModByName("OSLAroused.esp") == 255
        return false
    endif
    return true
EndFunction

Function ModifyArousal_Execute(Actor akActor, float amount)
    if !akActor
        return
    endif
    
    OSLArousedNative.ModifyArousal(akActor, amount)
EndFunction

; SetArousal (value 0-100).

Bool Function SetArousal_IsEligible(Actor akActor, float value)
    if !akActor || akActor.IsDead()
        return false
    endif
    if Game.GetModByName("OSLAroused.esp") == 255
        return false
    endif
    if value < 0 || value > 100
        return false
    endif
    return true
EndFunction

Function SetArousal_Execute(Actor akActor, float value)
    if !akActor
        return
    endif
    
    OSLArousedNative.SetArousal(akActor, value)
EndFunction