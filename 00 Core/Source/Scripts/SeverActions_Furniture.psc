Scriptname SeverActions_Furniture extends Quest
{Furniture actions for SkyrimNet (sit, sleep, use workstations via an Activate package).
 The bodies live in SeverActions_FurnitureLib; this script keeps the VMAD-filled
 properties, the action entry points SkyrimNet calls by name (member functions that
 forward) and its handler of the shared native cleanup event.}

; Properties

Package Property SeverActions_UseFurniturePackage Auto
{The Activate package on the target LinkedRef (0x062B5A; see SeverActions_FurnitureLib.UsePackage).}

Keyword Property SeverActions_FurnitureTargetKeyword Auto
{Keyword for linked ref to furniture target}
; The package priority and scene-event TTLs are SeverActions_FurnitureLib literals; the
; auto-stand distance is the furnitureAutoStandDistance settings row.

; Init & maintenance

Event OnInit()
    Debug.Trace("[SeverActions_Furniture] Initialized")
    RegisterEvents()
EndEvent

; The event registration, from the travel provider's stage 1 on every load.
Function Maintenance()
    Debug.Trace("[SeverActions_Furniture] Maintenance - re-registering events")
    RegisterEvents()
EndFunction

Function RegisterEvents()
    RegisterForModEvent("SeverActionsNative_FurnitureCleanup", "OnNativeFurnitureCleanup")
    Debug.Trace("[SeverActions_Furniture] Registered for SeverActionsNative_FurnitureCleanup event")
EndFunction

; Native cleanup: the DLL fires it when the player changes cells or moves too far away,
; and when CompanionSeating releases a companion it seated.

Event OnNativeFurnitureCleanup(string eventName, string strArg, float numArg, Form sender)
    {The canonical handler of the shared native event (M-E), for every registered user.
     FollowerManager's handler also lands for its bed sleepers; CleanupFor is
     idempotent. No HasPackage guard: 062B5A is never in SkyrimNet's package registry
     (see SeverActions_FurnitureLib.UsePackage).}
    ; The actor rides in sender; numArg is always 0 (a float cannot hold a high FormID).
    Actor akActor = sender as Actor

    if !akActor
        Debug.Trace("[SeverActions_Furniture] Cleanup event received but actor not found: " + numArg)
        return
    endif

    SeverActions_FurnitureLib.CleanupFor(akActor)
EndEvent

; Furniture lookup

ObjectReference Function GetFurnitureByFormIDForActor(String formIdStr, Actor akActor)
    {Forwarder; the body lives in SeverActions_FurnitureLib.}
    ; M-I-STUB 3.9.14-beta25 (P3-06): forwards to SeverActions_FurnitureLib.GetFurnitureByFormIDForActor
    return SeverActions_FurnitureLib.GetFurnitureByFormIDForActor(formIdStr, akActor)
EndFunction

; Action: UseFurniture (by FormID)

Bool Function UseFurniture_IsEligible(Actor akActor, String furnitureFormId) Global
    {Forwarder; the body lives in SeverActions_FurnitureLib.CanUse.}
    return SeverActions_FurnitureLib.CanUse(akActor, furnitureFormId)
EndFunction

Function UseFurniture_Execute(Actor akActor, String furnitureFormId)
    {SitOrLayDown: the named furniture, or the nearest free one of the same kind beside it
     when it is taken (SeverActions_FurnitureLib.UseNearest).}
    if !akActor || furnitureFormId == ""
        return
    endif

    ObjectReference furnRef = GetFurnitureByFormIDForActor(furnitureFormId, akActor)
    if !furnRef
        SeverActions_FurnitureLib.RegisterSceneEvent(akActor, "furniture_not_found", akActor.GetDisplayName() + " couldn't find the spot they meant to settle in", 60000)
        return
    endif
    SeverActions_FurnitureLib.UseNearest(akActor, furnRef)
EndFunction

Function UseFurnitureRef_Execute(Actor akActor, ObjectReference furnRef)
    {Uses an already-resolved furniture reference (e.g. the hotkey's crosshair target).
     Forwarder; the body lives in SeverActions_FurnitureLib.UseRef.}
    ; M-I-STUB 3.9.14-beta25 (P3-06): forwards to SeverActions_FurnitureLib.UseRef
    SeverActions_FurnitureLib.UseRef(akActor, furnRef)
EndFunction

; Stand up: kept for old frames and for an action copy a player saved in SkyrimNet's editor (the body is
; SeverActions_FurnitureLib.Stop, which SA's own stand-up paths call).

Bool Function StopUsingFurniture_IsEligible(Actor akActor) Global
    {Forwarder; the body lives in SeverActions_FurnitureLib.CanStop.}
    return SeverActions_FurnitureLib.CanStop(akActor)
EndFunction

Function StopUsingFurniture_Execute(Actor akActor)
    {Forwarder; the body lives in SeverActions_FurnitureLib.Stop.}
    ; M-I-STUB 3.9.14-beta25 (P3-06): forwards to SeverActions_FurnitureLib.Stop
    SeverActions_FurnitureLib.Stop(akActor)
EndFunction

; Global API for actions

SeverActions_Furniture Function GetInstance() Global
    {This script on the SeverActions quest (0x000D62), or None.}
    return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Furniture
EndFunction

; --- UseFurniture ---
Bool Function UseFurniture_Global_IsEligible(Actor akActor, String furnitureFormId) Global
    return UseFurniture_IsEligible(akActor, furnitureFormId)
EndFunction

Function UseFurniture_Global_Execute(Actor akActor, String furnitureFormId) Global
    SeverActions_Furniture instance = GetInstance()
    if instance
        instance.UseFurniture_Execute(akActor, furnitureFormId)
    endif
EndFunction

; --- StopUsingFurniture ---
Bool Function StopUsingFurniture_Global_IsEligible(Actor akActor) Global
    return StopUsingFurniture_IsEligible(akActor)
EndFunction

Function StopUsingFurniture_Global_Execute(Actor akActor) Global
    SeverActions_Furniture instance = GetInstance()
    if instance
        instance.StopUsingFurniture_Execute(akActor)
    endif
EndFunction

; Scene events

Function RegisterFurnitureSceneEvent(Actor akActor, String asType, String asText, Int aiTTLMs)
    {Forwarder; the body (and the why of short-lived, actor-keyed scene events)
     lives in SeverActions_FurnitureLib.RegisterSceneEvent.}
    ; M-I-STUB 3.9.14-beta25 (P3-06): forwards to SeverActions_FurnitureLib.RegisterSceneEvent
    SeverActions_FurnitureLib.RegisterSceneEvent(akActor, asType, asText, aiTTLMs)
EndFunction
