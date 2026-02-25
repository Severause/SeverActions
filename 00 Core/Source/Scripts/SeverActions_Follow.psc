Scriptname SeverActions_Follow extends Quest
{Multi-follower system with two distinct follow modes:

 1. Casual Follow (StartFollowing/StopFollowing) — uses SkyrimNet's built-in follow package
    via RegisterPackage. For guards, random NPCs, anyone the LLM decides should follow
    temporarily. No alias slots, no LinkedRef, no persistence across save/load.

 2. Companion Follow (CompanionStartFollowing/CompanionStopFollowing) — uses our CK alias-based
    follow package. For formal companions recruited through SetCompanion. Alias slot + LinkedRef
    + package attached to alias. Persists across save/load natively (only LinkedRef needs reapply).}

; =============================================================================
; PROPERTIES
; =============================================================================

int Property FollowPackagePriority = 50 AutoReadOnly
{Priority for SkyrimNet's casual follow package. Kept low so it doesn't
overtake important packages from other mods. Companions use CK alias
packages instead which don't use this priority.}

ReferenceAlias[] Property FollowerSlots Auto
{Array of 10 ReferenceAlias slots for companion follow package persistence.
Each alias has SeverActions_FollowPlayerPackage attached in CK.
When ForceRefTo fills an alias, the follow package auto-applies.
Alias state persists in save data, so packages survive save/load.}

Keyword Property SeverActions_FollowerFollowKW Auto
{Dedicated keyword for companion linked ref targeting. Created in CK for this system only.
Set on companion pointing to the player, so FollowPlayerPackage knows who to follow.}

Faction Property SeverActions_ActivelyFollowing Auto
{Dynamic faction: added when a companion is actively following the player,
removed when they wait, sandbox, stop following, or get dismissed.
Used by SkyrimNet target selector prompts to identify engaged companions
who should have a lower threshold to speak in conversations.
Create in CK — just a new faction, no special setup needed.}

Package Property SandboxPackage Auto
{Sandbox package for relaxing in place - NPC wanders and interacts with nearby furniture}

int Property SandboxPackagePriority = 40 AutoReadOnly
{Below follow (50) so orphaned FF sandbox packages can never block following.
 When we want an NPC to sandbox, we explicitly pause/remove the follow package
 first so sandbox can take effect. This makes the system self-healing: if a
 sandbox FF orphan survives a bad transition, follow still wins.}

float Property SandboxAutoStandDistance = 2000.0 Auto
{Distance at which sandboxing actors auto-resume following when player moves away}

; =============================================================================
; INIT
; =============================================================================

Event OnInit()
    Debug.Trace("[SeverActions_Follow] Initialized")
    RegisterForModEvent("SeverActionsNative_SandboxCleanup", "OnNativeSandboxCleanup")
EndEvent

; Called on game load to re-register events and restore state
Function Maintenance()
    RegisterForModEvent("SeverActionsNative_SandboxCleanup", "OnNativeSandboxCleanup")

    ; Re-apply ENGAGED faction to any NPCs that already have the FollowPlayer package
    ; (faction state doesn't persist across save/load, but SkyrimNet packages do)
    Actor player = Game.GetPlayer()
    Cell playerCell = player.GetParentCell()
    If playerCell
        Int numRefs = playerCell.GetNumRefs(43) ; 43 = kNPC
        Int i = 0
        While i < numRefs
            ObjectReference ref = playerCell.GetNthRef(i, 43)
            Actor actorRef = ref as Actor
            If actorRef && actorRef != player && !actorRef.IsDead() && SkyrimNetApi.HasPackage(actorRef, "FollowPlayer")
                SetActivelyFollowing(actorRef, true)
            EndIf
            i += 1
        EndWhile
    EndIf
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

    ; Back to actively following
    SetActivelyFollowing(akActor, true)

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
; ACTIVELY FOLLOWING FACTION — dynamic state for SkyrimNet prompt integration
; =============================================================================

Function SetActivelyFollowing(Actor akActor, Bool active)
    {Add or remove the SeverActions_ActivelyFollowing faction.
     Called whenever a companion's follow state changes.}
    If !SeverActions_ActivelyFollowing || !akActor
        Return
    EndIf
    If active
        akActor.AddToFaction(SeverActions_ActivelyFollowing)
    Else
        akActor.RemoveFromFaction(SeverActions_ActivelyFollowing)
    EndIf
EndFunction

; =============================================================================
; COMPANION ALIAS SLOT MANAGEMENT
; =============================================================================

Function AssignFollowerSlot(Actor akActor)
    {Find an empty follower alias slot and assign the actor to it.
     The alias's CK-attached follow package will auto-apply.}
    If !FollowerSlots
        Debug.Trace("[SeverActions_Follow] WARNING: FollowerSlots array not set - alias follow disabled")
        Return
    EndIf

    ; Check if actor is already in a slot (avoid duplicates)
    Int i = 0
    While i < FollowerSlots.Length
        If FollowerSlots[i] && FollowerSlots[i].GetActorRef() == akActor
            Debug.Trace("[SeverActions_Follow] " + akActor.GetDisplayName() + " already in FollowerSlot" + i)
            Return
        EndIf
        i += 1
    EndWhile

    ; Find first empty slot
    i = 0
    While i < FollowerSlots.Length
        If FollowerSlots[i] && !FollowerSlots[i].GetActorRef()
            FollowerSlots[i].ForceRefTo(akActor)
            Debug.Trace("[SeverActions_Follow] Assigned " + akActor.GetDisplayName() + " to FollowerSlot" + i)
            Return
        EndIf
        i += 1
    EndWhile
    Debug.Trace("[SeverActions_Follow] WARNING: No empty follower slots available for " + akActor.GetDisplayName())
EndFunction

Function ClearFollowerSlot(Actor akActor)
    {Find and clear the follower alias slot for this actor.
     Removing from alias auto-removes the CK-attached follow package.}
    If !FollowerSlots
        Return
    EndIf
    Int i = 0
    While i < FollowerSlots.Length
        If FollowerSlots[i] && FollowerSlots[i].GetActorRef() == akActor
            FollowerSlots[i].Clear()
            Debug.Trace("[SeverActions_Follow] Cleared " + akActor.GetDisplayName() + " from FollowerSlot" + i)
            Return
        EndIf
        i += 1
    EndWhile
EndFunction

; =============================================================================
; SAVE/LOAD PERSISTENCE (Companions only)
; =============================================================================

Function ReapplyFollowTracking(Actor[] followers)
    {Re-apply runtime-only data for companions after save/load.
     The CK alias packages persist natively — this only restores:
     - LinkedRef (PO3_SKSEFunctions.SetLinkedRef doesn't persist)
     - Sandbox overrides for waiting companions
     Does NOT register with SkyrimNet — companion eligibility uses faction.}
    Actor player = Game.GetPlayer()
    Int i = 0
    While i < followers.Length
        Actor akActor = followers[i]
        If akActor && !akActor.IsDead()
            ; Re-set linked ref (runtime-only, doesn't survive save/load)
            If SeverActions_FollowerFollowKW
                PO3_SKSEFunctions.SetLinkedRef(akActor, player, SeverActions_FollowerFollowKW)
            EndIf

            Bool isWaiting = akActor.GetAV("WaitingForPlayer") > 0
            ; If they were waiting/sandboxing, re-apply sandbox package + tracking
            If isWaiting && SandboxPackage
                ActorUtil.AddPackageOverride(akActor, SandboxPackage, SandboxPackagePriority, 1)
                SkyrimNetApi.RegisterPackage(akActor, "Sandbox", SandboxPackagePriority, 0, false)
            EndIf

            ; Re-apply actively following faction based on current state
            SetActivelyFollowing(akActor, !isWaiting)

            akActor.EvaluatePackage()
            Debug.Trace("[SeverActions_Follow] Reapplied companion follow tracking for: " + akActor.GetDisplayName() + " (waiting=" + isWaiting + ")")
        EndIf
        i += 1
    EndWhile
EndFunction

; =============================================================================
; CASUAL FOLLOW — SkyrimNet package (guards, random NPCs, temporary)
; Called by startfollowing.yaml / stopfollowing.yaml
; =============================================================================

Function StartFollowing(Actor akActor)
    {Start casual following via SkyrimNet's built-in follow package.
     For any NPC the LLM decides should follow temporarily.
     Does NOT use alias slots or LinkedRef — purely SkyrimNet managed.}
    if !akActor || akActor.IsDead()
        return
    endif

    ; Clear sandbox tracking if active
    if SkyrimNetApi.HasPackage(akActor, "Sandbox")
        SeverActionsNative.UnregisterSandboxUser(akActor)
        SkyrimNetApi.UnregisterPackage(akActor, "Sandbox")
    endif

    ; Safety net: nuke ALL package overrides to clear any orphaned FF packages
    ; (sandbox FF copies that survived a bad transition, sleep time-skip, etc.)
    ActorUtil.ClearPackageOverride(akActor)

    ; Clear waiting state (in case they were waiting)
    akActor.SetAV("WaitingForPlayer", 0)

    ; Register SkyrimNet's built-in follow package (re-applied fresh after the clear)
    SkyrimNetApi.RegisterPackage(akActor, "FollowPlayer", FollowPackagePriority, 0, true)

    ; Mark as actively following for ENGAGED tag in prompts
    SetActivelyFollowing(akActor, true)

    akActor.EvaluatePackage()

    Debug.Notification(akActor.GetDisplayName() + " is now following you.")
EndFunction

Function StopFollowing(Actor akActor)
    {Stop casual following — removes SkyrimNet's follow package.}
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

    ; Unregister SkyrimNet's follow package
    SkyrimNetApi.UnregisterPackage(akActor, "FollowPlayer")

    ; Remove actively following state
    SetActivelyFollowing(akActor, false)

    akActor.EvaluatePackage()

    Debug.Notification(akActor.GetDisplayName() + " stopped following you.")
    SkyrimNetApi.RegisterEvent("follower_left", akActor.GetDisplayName() + " stopped following " + Game.GetPlayer().GetDisplayName(), akActor, Game.GetPlayer())
EndFunction

; =============================================================================
; COMPANION FOLLOW — CK alias-based package (formal companions only)
; Called internally by FollowerManager.RegisterFollower / UnregisterFollower
; =============================================================================

Function CompanionStartFollowing(Actor akActor)
    {Start companion following via our CK alias-based follow package.
     Assigns alias slot (auto-applies CK package) + sets LinkedRef to player.
     Only for formal companions recruited through SetCompanion.}
    if !akActor || akActor.IsDead()
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

    ; Clear waiting state
    akActor.SetAV("WaitingForPlayer", 0)

    ; Set linked ref to player (so CK follow package knows who to follow)
    If SeverActions_FollowerFollowKW
        PO3_SKSEFunctions.SetLinkedRef(akActor, Game.GetPlayer(), SeverActions_FollowerFollowKW)
    Else
        Debug.Trace("[SeverActions_Follow] WARNING: FollowerFollowKW not set!")
    EndIf

    ; Assign to alias slot — CK package auto-applies (persists across save/load)
    AssignFollowerSlot(akActor)

    ; No SkyrimNetApi.RegisterPackage — our CK alias package handles the AI.
    ; Companion eligibility uses SeverActions_FollowerFaction, not HasPackage.

    ; Mark as actively following for SkyrimNet prompt integration
    SetActivelyFollowing(akActor, true)

    ; Register with native orphan cleanup so stale follow packages get detected
    SeverActionsNative.OrphanCleanup_RegisterFollower(akActor)

    akActor.EvaluatePackage()
EndFunction

Function CompanionStopFollowing(Actor akActor)
    {Stop companion following — clears alias slot (auto-removes CK package) and LinkedRef.}
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

    ; Clear alias slot — CK package auto-removes
    ClearFollowerSlot(akActor)

    ; Unregister from orphan cleanup tracking
    SeverActionsNative.OrphanCleanup_UnregisterFollower(akActor)

    ; Clear linked ref
    If SeverActions_FollowerFollowKW
        PO3_SKSEFunctions.SetLinkedRef(akActor, None, SeverActions_FollowerFollowKW)
    EndIf

    ; Also unregister from SkyrimNet in case they had a casual follow registered too
    SkyrimNetApi.UnregisterPackage(akActor, "FollowPlayer")

    ; No longer actively following
    SetActivelyFollowing(akActor, false)

    akActor.EvaluatePackage()
EndFunction

; =============================================================================
; SHARED FUNCTIONS — Work for both casual and companion follow
; =============================================================================

Function WaitHere(Actor akActor)
    if !akActor
        return
    endif

    ; Set waiting state - package condition will make them stop following
    akActor.SetAV("WaitingForPlayer", 1)

    ; No longer actively following (waiting in place)
    SetActivelyFollowing(akActor, false)

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

    ; Remove follow package so sandbox (lower priority) can take effect
    ; For casual follow: unregister SkyrimNet's FollowPlayer package
    ; For companion follow: WaitingForPlayer=1 deactivates the CK follow package condition
    SkyrimNetApi.UnregisterPackage(akActor, "FollowPlayer")
    akActor.SetAV("WaitingForPlayer", 1)

    ; Apply sandbox package at current location
    ActorUtil.AddPackageOverride(akActor, SandboxPackage, SandboxPackagePriority, 1)

    ; Register with SkyrimNet for tracking
    SkyrimNetApi.RegisterPackage(akActor, "Sandbox", SandboxPackagePriority, 0, false)

    ; Register with native SandboxManager for auto-cleanup when player moves away/changes cells
    SeverActionsNative.RegisterSandboxUser(akActor, SandboxPackage, SandboxAutoStandDistance)

    ; No longer actively following (relaxing in place)
    SetActivelyFollowing(akActor, false)

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

    ; Unregister from SkyrimNet
    SkyrimNetApi.UnregisterPackage(akActor, "Sandbox")

    ; Safety net: nuke ALL package overrides to clear any orphaned FF packages
    ActorUtil.ClearPackageOverride(akActor)

    ; Resume following
    akActor.SetAV("WaitingForPlayer", 0)

    ; Re-apply follow package (cleared above with everything else)
    SkyrimNetApi.RegisterPackage(akActor, "FollowPlayer", FollowPackagePriority, 0, true)

    ; Back to actively following
    SetActivelyFollowing(akActor, true)

    akActor.EvaluatePackage()

    Debug.Notification(akActor.GetDisplayName() + " stopped relaxing.")
    SkyrimNetApi.RegisterPersistentEvent(akActor.GetDisplayName() + " stops relaxing and is ready to move.", akActor, Game.GetPlayer())
EndFunction

; =============================================================================
; GLOBAL API FOR ACTIONS
; =============================================================================

; --- StartFollowing Action (Casual) ---

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

; --- StopFollowing Action (Casual) ---

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