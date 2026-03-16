Scriptname SeverActions_Arousal extends Quest
{OSLAroused integration - provides arousal state decorator for NPCs}

; =============================================================================
; DECORATOR: get_arousal_state
; Returns JSON with arousal info for an NPC
; Called from prompts as: {{ get_arousal_state(npc.UUID) }}
; =============================================================================

String Function GetArousalState(Actor akActor) Global
    if !akActor || akActor.IsDead()
        return "{\"available\":false}"
    endif
    
    ; Check if OSLAroused is loaded
    if Game.GetModByName("OSLAroused.esp") == 255
        return "{\"available\":false,\"reason\":\"OSLAroused not installed\"}"
    endif
    
    ; Get arousal values
    float arousal = OSLArousedNative.GetArousal(akActor)
    float baseline = OSLArousedNative.GetArousalBaseline(akActor)
    float libido = OSLArousedNative.GetLibido(akActor)
    bool isNaked = OSLArousedNative.IsActorNaked(akActor)
    bool inScene = OSLArousedNative.IsInScene(akActor)
    
    ; Determine arousal description
    String arousalDesc = GetArousalDescription(arousal)
    String libidoDesc = GetLibidoDescription(libido)
    
    ; Build JSON
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

; Get human-readable arousal description
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

; Get human-readable libido description
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

; =============================================================================
; ACTION: ModifyArousal - Change an NPC's arousal
; =============================================================================

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
    
    float newArousal = OSLArousedNative.GetArousal(akActor)
    String desc = GetArousalDescription(newArousal)
    
    if amount > 0
        SkyrimNetApi.RegisterEvent("arousal_increased", akActor.GetDisplayName() + " is now " + desc, akActor, None)
    else
        SkyrimNetApi.RegisterEvent("arousal_decreased", akActor.GetDisplayName() + " is now " + desc, akActor, None)
    endif
EndFunction

; =============================================================================
; ACTION: SetArousal - Set an NPC's arousal to specific value
; =============================================================================

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
    
    String desc = GetArousalDescription(value)
    SkyrimNetApi.RegisterEvent("arousal_set", akActor.GetDisplayName() + " is now " + desc, akActor, None)
EndFunction