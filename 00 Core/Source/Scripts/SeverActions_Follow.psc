Scriptname SeverActions_Follow extends Quest
{Simple multi-follower system based on SkyrimNet's approach}

; =============================================================================
; PROPERTIES
; =============================================================================

; No package property needed - SkyrimNet handles it internally via RegisterPackage
; But we need to tell SkyrimNet which package to use, so we register it in GetPackageFromString

int Property FollowPackagePriority = 10 AutoReadOnly
{Keep low so other packages can interrupt when needed}

Package Property SandboxPackage Auto
{Sandbox package for relaxing in place - NPC wanders and interacts with nearby furniture}

int Property SandboxPackagePriority = 90 AutoReadOnly
{Higher than follow (10) so it overrides follow behavior, but lower than crafting/travel (100)}

float Property SandboxAutoStandDistance = 2000.0 Auto
{Distance at which sandboxing actors auto-resume following when player moves away}

; =============================================================================
; INIT
; =============================================================================

Event OnInit()
    Debug.Trace("[SeverActions_Follow] Initialized")
    RegisterForModEvent("SeverActionsNative_SandboxCleanup", "OnNativeSandboxCleanup")
EndEvent

; Called on game load to re-register events
Function Maintenance()
    RegisterForModEvent("SeverActionsNative_SandboxCleanup", "OnNativeSandboxCleanup")
EndFunction

; =============================================================================
; NATIVE SANDBOX CLEANUP EVENT HANDLER
; Called by native SandboxManager when player changes cells or moves too far
; =============================================================================

Event OnNativeSandboxCleanup(string eventName, string strArg, float numArg, Form sender)
    Actor akActor = sender as Actor
    if !akActor
        akActor = Game.GetFormEx(numArg as int) as Actor
    endif

    if !akActor
        return
    endif

    ; Only handle actors that are sandboxing through our system
    if !SkyrimNetApi.HasPackage(akActor, "Sandbox")
        return
    endif

    Debug.Trace("[SeverActions_Follow] Native sandbox cleanup for: " + akActor.GetDisplayName())

    ; Remove sandbox package
    if SandboxPackage
        ActorUtil.RemovePackageOverride(akActor, SandboxPackage)
    endif

    ; Unregister from SkyrimNet
    SkyrimNetApi.UnregisterPackage(akActor, "Sandbox")

    ; Resume following
    akActor.SetAV("WaitingForPlayer", 0)
    akActor.EvaluatePackage()

    Debug.Notification(akActor.GetDisplayName() + " stopped relaxing.")
    SkyrimNetApi.RegisterPersistentEvent(akActor.GetDisplayName() + " stops relaxing and catches up with " + Game.GetPlayer().GetDisplayName() + ".", akActor, Game.GetPlayer())
EndEvent

; =============================================================================
; HELPER - Check if actor has follow package
; =============================================================================

Bool Function HasFollowPackage(Actor akActor)
    return SkyrimNetApi.HasPackage(akActor, "FollowPlayer")
EndFunction

; =============================================================================
; PUBLIC API
; =============================================================================

Function StartFollowing(Actor akActor)
    if !akActor || akActor.IsDead()
        return
    endif

    ; Clear sandbox if active (so they resume following cleanly)
    if SkyrimNetApi.HasPackage(akActor, "Sandbox")
        SeverActionsNative.UnregisterSandboxUser(akActor)
        if SandboxPackage
            ActorUtil.RemovePackageOverride(akActor, SandboxPackage)
        endif
        SkyrimNetApi.UnregisterPackage(akActor, "Sandbox")
    endif

    ; Clear waiting state (in case they were waiting)
    akActor.SetAV("WaitingForPlayer", 0)

    ; Register package with SkyrimNet - the 'true' lets SkyrimNet handle applying it
    SkyrimNetApi.RegisterPackage(akActor, "FollowPlayer", FollowPackagePriority, 0, true)
    
    akActor.EvaluatePackage()
    
    Debug.Notification(akActor.GetDisplayName() + " is now following you.")
    SkyrimNetApi.RegisterEvent("follower_joined", akActor.GetDisplayName() + " started following " + Game.GetPlayer().GetDisplayName(), akActor, Game.GetPlayer())
EndFunction

Function StopFollowing(Actor akActor)
    if !akActor
        return
    endif

    ; Clear sandbox if active
    if SkyrimNetApi.HasPackage(akActor, "Sandbox")
        SeverActionsNative.UnregisterSandboxUser(akActor)
        if SandboxPackage
            ActorUtil.RemovePackageOverride(akActor, SandboxPackage)
        endif
        SkyrimNetApi.UnregisterPackage(akActor, "Sandbox")
    endif

    ; Unregister from SkyrimNet - this also removes the package override
    SkyrimNetApi.UnregisterPackage(akActor, "FollowPlayer")
    
    akActor.EvaluatePackage()
    
    Debug.Notification(akActor.GetDisplayName() + " stopped following you.")
    SkyrimNetApi.RegisterEvent("follower_left", akActor.GetDisplayName() + " stopped following " + Game.GetPlayer().GetDisplayName(), akActor, Game.GetPlayer())
EndFunction

Function WaitHere(Actor akActor)
    if !akActor
        return
    endif

    ; Set waiting state - package condition will make them stop following
    akActor.SetAV("WaitingForPlayer", 1)

    akActor.EvaluatePackage()

    Debug.Notification(akActor.GetDisplayName() + " is waiting here.")
    SkyrimNetApi.RegisterEvent("follower_waiting", akActor.GetDisplayName() + " is waiting for " + Game.GetPlayer().GetDisplayName(), akActor, Game.GetPlayer())
EndFunction

Function Sandbox(Actor akActor)
    if !akActor || akActor.IsDead()
        return
    endif

    if !SandboxPackage
        Debug.Trace("[SeverActions_Follow] Sandbox: No SandboxPackage assigned!")
        return
    endif

    ; Pause follow package so sandbox can take over
    akActor.SetAV("WaitingForPlayer", 1)

    ; Apply sandbox package at current location
    ActorUtil.AddPackageOverride(akActor, SandboxPackage, SandboxPackagePriority, 1)

    ; Register with SkyrimNet for tracking
    SkyrimNetApi.RegisterPackage(akActor, "Sandbox", SandboxPackagePriority, 0, false)

    ; Register with native SandboxManager for auto-cleanup when player moves away/changes cells
    SeverActionsNative.RegisterSandboxUser(akActor, SandboxPackage, SandboxAutoStandDistance)

    akActor.EvaluatePackage()

    Debug.Notification(akActor.GetDisplayName() + " is relaxing.")
    SkyrimNetApi.RegisterPersistentEvent(akActor.GetDisplayName() + " decides to relax and wander around the area.", akActor, Game.GetPlayer())
EndFunction

Function StopSandbox(Actor akActor)
    if !akActor
        return
    endif

    ; Unregister from native SandboxManager
    SeverActionsNative.UnregisterSandboxUser(akActor)

    ; Remove sandbox package
    if SandboxPackage
        ActorUtil.RemovePackageOverride(akActor, SandboxPackage)
    endif

    ; Unregister from SkyrimNet
    SkyrimNetApi.UnregisterPackage(akActor, "Sandbox")

    ; Resume following
    akActor.SetAV("WaitingForPlayer", 0)

    akActor.EvaluatePackage()

    Debug.Notification(akActor.GetDisplayName() + " stopped relaxing.")
    SkyrimNetApi.RegisterPersistentEvent(akActor.GetDisplayName() + " stops relaxing and is ready to move.", akActor, Game.GetPlayer())
EndFunction

; =============================================================================
; GLOBAL API FOR ACTIONS
; =============================================================================

; --- StartFollowing Action ---

Bool Function StartFollowing_IsEligible(Actor akActor) Global
    if !akActor || akActor.IsDead() || akActor.IsInCombat()
        return false
    endif
    
    ; Don't allow vanilla followers
    Faction factionCompanion = Game.GetFormFromFile(0x084D1B, "Skyrim.esm") as Faction
    if factionCompanion && akActor.IsInFaction(factionCompanion)
        return false
    endif
    
    ; Allow if: not following, OR following but waiting/sandboxing (to resume)
    Bool hasPackage = SkyrimNetApi.HasPackage(akActor, "FollowPlayer")
    Bool isWaiting = akActor.GetAV("WaitingForPlayer") > 0
    Bool isSandboxing = SkyrimNetApi.HasPackage(akActor, "Sandbox")

    if hasPackage && !isWaiting && !isSandboxing
        return false  ; Already following and not waiting/sandboxing
    endif
    
    return true
EndFunction

Function StartFollowing_Execute(Actor akActor) Global
    SeverActions_Follow instance = Game.GetFormFromFile(0x000800, "SeverActions.esp") as SeverActions_Follow
    if instance
        instance.StartFollowing(akActor)
    endif
EndFunction

; --- StopFollowing Action ---

Bool Function StopFollowing_IsEligible(Actor akActor) Global
    if !akActor
        return false
    endif
    
    return SkyrimNetApi.HasPackage(akActor, "FollowPlayer")
EndFunction

Function StopFollowing_Execute(Actor akActor) Global
    SeverActions_Follow instance = Game.GetFormFromFile(0x000800, "SeverActions.esp") as SeverActions_Follow
    if instance
        instance.StopFollowing(akActor)
    endif
EndFunction

; --- WaitHere Action ---

Bool Function WaitHere_IsEligible(Actor akActor) Global
    if !akActor
        return false
    endif
    
    ; Must be following and not already waiting
    Bool hasPackage = SkyrimNetApi.HasPackage(akActor, "FollowPlayer")
    Bool isWaiting = akActor.GetAV("WaitingForPlayer") > 0
    
    return hasPackage && !isWaiting
EndFunction

Function WaitHere_Execute(Actor akActor) Global
    SeverActions_Follow instance = Game.GetFormFromFile(0x000800, "SeverActions.esp") as SeverActions_Follow
    if instance
        instance.WaitHere(akActor)
    endif
EndFunction

; --- Sandbox Action ---

Bool Function Sandbox_IsEligible(Actor akActor) Global
    if !akActor || akActor.IsDead() || akActor.IsInCombat()
        return false
    endif

    ; Must be a follower
    if !SkyrimNetApi.HasPackage(akActor, "FollowPlayer")
        return false
    endif

    ; Must not already be sandboxing
    if SkyrimNetApi.HasPackage(akActor, "Sandbox")
        return false
    endif

    return true
EndFunction

Function Sandbox_Execute(Actor akActor) Global
    SeverActions_Follow instance = Game.GetFormFromFile(0x000800, "SeverActions.esp") as SeverActions_Follow
    if instance
        instance.Sandbox(akActor)
    endif
EndFunction

; --- StopSandbox Action ---

Bool Function StopSandbox_IsEligible(Actor akActor) Global
    if !akActor
        return false
    endif

    return SkyrimNetApi.HasPackage(akActor, "Sandbox")
EndFunction

Function StopSandbox_Execute(Actor akActor) Global
    SeverActions_Follow instance = Game.GetFormFromFile(0x000800, "SeverActions.esp") as SeverActions_Follow
    if instance
        instance.StopSandbox(akActor)
    endif
EndFunction