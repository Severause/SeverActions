Scriptname SeverActions_Furniture extends Quest
{Furniture interaction actions for SkyrimNet - sit, sleep, use workstations via sandbox package}

; =============================================================================
; PROPERTIES
; =============================================================================

Package Property SeverActions_UseFurniturePackage Auto
{Sandbox package with small radius - created in CK}

Keyword Property SeverActions_FurnitureTargetKeyword Auto
{Keyword for linked ref to furniture target}

int Property FurniturePackagePriority = 80 AutoReadOnly
{High priority so it overrides other behaviors}

float Property AutoStandDistance = 500.0 Auto
{Distance at which actors auto-stand when player moves away}

; =============================================================================
; INIT & MAINTENANCE
; =============================================================================

Event OnInit()
    Debug.Trace("[SeverActions_Furniture] Initialized")
    RegisterEvents()
EndEvent

; Called on game load to ensure event registration persists across saves
Function Maintenance()
    Debug.Trace("[SeverActions_Furniture] Maintenance - re-registering events")
    RegisterEvents()
EndFunction

Function RegisterEvents()
    ; Register for native cleanup event from FurnitureManager
    RegisterForModEvent("SeverActionsNative_FurnitureCleanup", "OnNativeFurnitureCleanup")
    Debug.Trace("[SeverActions_Furniture] Registered for SeverActionsNative_FurnitureCleanup event")
EndFunction

; =============================================================================
; NATIVE CLEANUP EVENT HANDLER
; Called by native DLL when player changes cells or moves too far away
; =============================================================================

Event OnNativeFurnitureCleanup(string eventName, string strArg, float numArg, Form sender)
    ; numArg contains the actor's FormID
    Actor akActor = sender as Actor
    if !akActor
        ; Try to look up by FormID
        akActor = Game.GetFormEx(numArg as int) as Actor
    endif

    if !akActor
        Debug.Trace("[SeverActions_Furniture] Cleanup event received but actor not found: " + numArg)
        return
    endif

    Debug.Trace("[SeverActions_Furniture] Native cleanup for: " + akActor.GetDisplayName())

    ; Remove the sandbox package
    if SeverActions_UseFurniturePackage
        ActorUtil.RemovePackageOverride(akActor, SeverActions_UseFurniturePackage)
    endif

    ; Clear linked ref
    if SeverActions_FurnitureTargetKeyword
        PO3_SKSEFunctions.SetLinkedRef(akActor, None, SeverActions_FurnitureTargetKeyword)
    endif

    ; Unregister from SkyrimNet
    SkyrimNetApi.UnregisterPackage(akActor, "SeverActions_UseFurniture")

    ; Evaluate to let them stand up and return to normal AI
    akActor.EvaluatePackage()

    SkyrimNetApi.RegisterEvent("furniture_stopped", akActor.GetDisplayName() + " got up (auto)", akActor, None)
EndEvent

; =============================================================================
; FURNITURE LOOKUP
; =============================================================================

ObjectReference Function GetFurnitureByFormID(String formIdStr)
    if formIdStr == ""
        return None
    endif
    
    int formId = formIdStr as int
    if formId == 0 && formIdStr != "0"
        Debug.Trace("[SeverActions_Furniture] Failed to parse formID: " + formIdStr)
        return None
    endif
    
    Form foundForm = Game.GetFormEx(formId)
    if !foundForm
        Debug.Trace("[SeverActions_Furniture] GetFormEx returned None for: " + formIdStr)
        return None
    endif
    
    ObjectReference furnRef = foundForm as ObjectReference
    if !furnRef
        Debug.Trace("[SeverActions_Furniture] Form is not an ObjectReference")
        return None
    endif
    
    return furnRef
EndFunction

; =============================================================================
; ACTION: UseFurniture - Use furniture by formID
; =============================================================================

Bool Function UseFurniture_IsEligible(Actor akActor, String furnitureFormId) Global
    if !akActor || akActor.IsDead() || akActor.IsInCombat()
        return false
    endif
    
    ; Already using furniture
    if akActor.GetSitState() != 0
        return false
    endif
    
    return furnitureFormId != ""
EndFunction

Function UseFurniture_Execute(Actor akActor, String furnitureFormId)
    if !akActor || furnitureFormId == ""
        return
    endif
    
    ObjectReference furnRef = GetFurnitureByFormID(furnitureFormId)
    if !furnRef
        SkyrimNetApi.RegisterEvent("furniture_not_found", akActor.GetDisplayName() + " couldn't find that furniture", akActor, None)
        return
    endif
    
    if furnRef.IsFurnitureInUse()
        SkyrimNetApi.RegisterEvent("furniture_in_use", akActor.GetDisplayName() + " - furniture is already in use", akActor, None)
        return
    endif
    
    String furnName = furnRef.GetBaseObject().GetName()
    Debug.Trace("[SeverActions_Furniture] " + akActor.GetDisplayName() + " using: " + furnName)
    
    ; Set linked ref to the furniture
    if SeverActions_FurnitureTargetKeyword
        PO3_SKSEFunctions.SetLinkedRef(akActor, furnRef, SeverActions_FurnitureTargetKeyword)
    endif
    
    ; Apply sandbox package - they'll walk to and use the furniture
    if SeverActions_UseFurniturePackage
        ActorUtil.AddPackageOverride(akActor, SeverActions_UseFurniturePackage, FurniturePackagePriority)
        akActor.EvaluatePackage()

        ; Register with native FurnitureManager for auto-cleanup
        SeverActionsNative.RegisterFurnitureUser(akActor, SeverActions_UseFurniturePackage, furnRef, SeverActions_FurnitureTargetKeyword, AutoStandDistance)
    endif

    ; Register with SkyrimNet
    SkyrimNetApi.RegisterPackage(akActor, "SeverActions_UseFurniture", FurniturePackagePriority, 0, false)

    SkyrimNetApi.RegisterEvent("furniture_used", akActor.GetDisplayName() + " is using " + furnName, akActor, None)
EndFunction

; =============================================================================
; ACTION: StopUsingFurniture - Stand up and stop using furniture
; =============================================================================

Bool Function StopUsingFurniture_IsEligible(Actor akActor) Global
    if !akActor || akActor.IsDead()
        return false
    endif
    
    ; Must be using furniture or have the package
    return akActor.GetSitState() >= 2 || SkyrimNetApi.HasPackage(akActor, "SeverActions_UseFurniture")
EndFunction

Function StopUsingFurniture_Execute(Actor akActor)
    if !akActor
        return
    endif

    Debug.Trace("[SeverActions_Furniture] " + akActor.GetDisplayName() + " stopping furniture use")

    ; Unregister from native FurnitureManager first
    SeverActionsNative.UnregisterFurnitureUser(akActor)

    ; Remove the sandbox package
    if SeverActions_UseFurniturePackage
        ActorUtil.RemovePackageOverride(akActor, SeverActions_UseFurniturePackage)
    endif

    ; Clear linked ref
    if SeverActions_FurnitureTargetKeyword
        PO3_SKSEFunctions.SetLinkedRef(akActor, None, SeverActions_FurnitureTargetKeyword)
    endif

    ; Unregister from SkyrimNet
    SkyrimNetApi.UnregisterPackage(akActor, "SeverActions_UseFurniture")

    ; Evaluate to let them stand up and return to normal AI
    akActor.EvaluatePackage()

    SkyrimNetApi.RegisterEvent("furniture_stopped", akActor.GetDisplayName() + " got up", akActor, None)
EndFunction

; =============================================================================
; GLOBAL API FOR ACTIONS
; =============================================================================

SeverActions_Furniture Function GetInstance() Global
    return Game.GetFormFromFile(0x000801, "SeverActions.esp") as SeverActions_Furniture
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