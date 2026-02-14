Scriptname SeverActions_Hotkeys extends Quest
{Hotkey handler for SeverActions - manages key bindings for quick actions}

; =============================================================================
; PROPERTIES - Set in CK
; =============================================================================

SeverActions_Follow Property FollowScript Auto
{Reference to the follow system script}

SeverActions_Furniture Property FurnitureScript Auto
{Reference to the furniture system script}

SeverActions_Combat Property CombatScript Auto
{Reference to the combat system script}

SeverActions_Outfit Property OutfitScript Auto
{Reference to the outfit system script}

SeverActions_FollowerManager Property FollowerManagerScript Auto
{Reference to the follower manager script}

; =============================================================================
; HOTKEY SETTINGS - Configured via MCM
; =============================================================================

int Property FollowToggleKey = -1 Auto Hidden
{Key code for toggling follow state. -1 = unset/disabled}

int Property DismissAllKey = -1 Auto Hidden
{Key code for dismissing all followers. -1 = unset/disabled}

int Property StandUpKey = -1 Auto Hidden
{Key code for making target NPC stand up from furniture. -1 = unset/disabled}

int Property YieldKey = -1 Auto Hidden
{Key code for making target NPC yield/surrender. -1 = unset/disabled}

int Property UndressKey = -1 Auto Hidden
{Key code for undressing target NPC. -1 = unset/disabled}

int Property DressKey = -1 Auto Hidden
{Key code for dressing target NPC. -1 = unset/disabled}

int Property SetCompanionKey = -1 Auto Hidden
{Key code for making target NPC a companion. -1 = unset/disabled}

int Property CompanionWaitKey = -1 Auto Hidden
{Key code for toggling wait state on target NPC. -1 = unset/disabled}

; =============================================================================
; TARGET MODE SETTINGS
; =============================================================================

int Property TargetMode = 0 Auto Hidden
{0 = Crosshair, 1 = Nearest NPC, 2 = Last talked to}

float Property NearestNPCRadius = 500.0 Auto Hidden
{Radius to search for nearest NPC when using TargetMode 1}

; =============================================================================
; STATE
; =============================================================================

Actor LastTalkedTo = None
bool Property IsRegistered = false Auto Hidden

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    Debug.Trace("[SeverActions_Hotkeys] Initialized")
    RegisterKeys()
EndEvent

Event OnPlayerLoadGame()
    Debug.Trace("[SeverActions_Hotkeys] Game loaded, re-registering keys")
    RegisterKeys()
EndEvent

; =============================================================================
; KEY REGISTRATION
; =============================================================================

Function RegisterKeys()
    ; Unregister all first to avoid duplicates
    UnregisterForAllKeys()
    IsRegistered = false
    
    ; Register follow toggle key (only if set)
    if FollowToggleKey > 0
        RegisterForKey(FollowToggleKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered follow toggle key: " + FollowToggleKey)
    endif
    
    ; Register dismiss all key (only if set)
    if DismissAllKey > 0
        RegisterForKey(DismissAllKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered dismiss all key: " + DismissAllKey)
    endif
    
    ; Register stand up key (only if set)
    if StandUpKey > 0
        RegisterForKey(StandUpKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered stand up key: " + StandUpKey)
    endif
    
    ; Register yield key (only if set)
    if YieldKey > 0
        RegisterForKey(YieldKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered yield key: " + YieldKey)
    endif
    
    ; Register undress key (only if set)
    if UndressKey > 0
        RegisterForKey(UndressKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered undress key: " + UndressKey)
    endif
    
    ; Register dress key (only if set)
    if DressKey > 0
        RegisterForKey(DressKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered dress key: " + DressKey)
    endif

    ; Register set companion key (only if set)
    if SetCompanionKey > 0
        RegisterForKey(SetCompanionKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered set companion key: " + SetCompanionKey)
    endif

    ; Register companion wait key (only if set)
    if CompanionWaitKey > 0
        RegisterForKey(CompanionWaitKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered companion wait key: " + CompanionWaitKey)
    endif

    IsRegistered = true
EndFunction

Function UpdateFollowToggleKey(int newKey)
    ; Unregister old key if it was valid
    if FollowToggleKey > 0 && FollowToggleKey != newKey
        UnregisterForKey(FollowToggleKey)
    endif
    
    FollowToggleKey = newKey
    
    ; Register new key (only if valid)
    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated follow toggle key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Follow toggle key cleared")
    endif
EndFunction

Function UpdateDismissAllKey(int newKey)
    ; Unregister old key if it was valid
    if DismissAllKey > 0 && DismissAllKey != newKey
        UnregisterForKey(DismissAllKey)
    endif
    
    DismissAllKey = newKey
    
    ; Register new key (only if valid)
    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated dismiss all key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Dismiss all key cleared")
    endif
EndFunction

Function UpdateStandUpKey(int newKey)
    ; Unregister old key if it was valid
    if StandUpKey > 0 && StandUpKey != newKey
        UnregisterForKey(StandUpKey)
    endif
    
    StandUpKey = newKey
    
    ; Register new key (only if valid)
    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated stand up key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Stand up key cleared")
    endif
EndFunction

Function UpdateYieldKey(int newKey)
    ; Unregister old key if it was valid
    if YieldKey > 0 && YieldKey != newKey
        UnregisterForKey(YieldKey)
    endif

    YieldKey = newKey

    ; Register new key (only if valid)
    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated yield key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Yield key cleared")
    endif
EndFunction

Function UpdateUndressKey(int newKey)
    ; Unregister old key if it was valid
    if UndressKey > 0 && UndressKey != newKey
        UnregisterForKey(UndressKey)
    endif
    
    UndressKey = newKey
    
    ; Register new key (only if valid)
    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated undress key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Undress key cleared")
    endif
EndFunction

Function UpdateDressKey(int newKey)
    ; Unregister old key if it was valid
    if DressKey > 0 && DressKey != newKey
        UnregisterForKey(DressKey)
    endif
    
    DressKey = newKey
    
    ; Register new key (only if valid)
    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated dress key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Dress key cleared")
    endif
EndFunction

Function UpdateSetCompanionKey(int newKey)
    if SetCompanionKey > 0 && SetCompanionKey != newKey
        UnregisterForKey(SetCompanionKey)
    endif

    SetCompanionKey = newKey

    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated set companion key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Set companion key cleared")
    endif
EndFunction

Function UpdateCompanionWaitKey(int newKey)
    if CompanionWaitKey > 0 && CompanionWaitKey != newKey
        UnregisterForKey(CompanionWaitKey)
    endif

    CompanionWaitKey = newKey

    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated companion wait key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Companion wait key cleared")
    endif
EndFunction

; =============================================================================
; KEY EVENT HANDLING
; =============================================================================

Event OnKeyDown(int keyCode)
    ; Ignore if in menu or invalid key
    if Utility.IsInMenuMode() || keyCode <= 0
        return
    endif
    
    Actor player = Game.GetPlayer()
    
    ; Ignore if player is in dialogue, dead, or incapacitated
    if player.IsInDialogueWithPlayer() || player.IsDead() || player.GetSitState() == 3
        return
    endif
    
    if keyCode == FollowToggleKey && FollowToggleKey > 0
        HandleFollowToggle()
    elseif keyCode == DismissAllKey && DismissAllKey > 0
        HandleDismissAll()
    elseif keyCode == StandUpKey && StandUpKey > 0
        HandleStandUp()
    elseif keyCode == YieldKey && YieldKey > 0
        HandleYield()
    elseif keyCode == UndressKey && UndressKey > 0
        HandleUndress()
    elseif keyCode == DressKey && DressKey > 0
        HandleDress()
    elseif keyCode == SetCompanionKey && SetCompanionKey > 0
        HandleSetCompanion()
    elseif keyCode == CompanionWaitKey && CompanionWaitKey > 0
        HandleCompanionWait()
    endif
EndEvent

; =============================================================================
; FOLLOW TOGGLE HANDLER
; =============================================================================

Function HandleFollowToggle()
    if !FollowScript
        Debug.Notification("SeverActions: Follow script not configured!")
        return
    endif
    
    Actor target = GetTargetActor()
    
    if !target
        Debug.Notification("No valid target found")
        return
    endif
    
    if target == Game.GetPlayer()
        Debug.Notification("Cannot target yourself")
        return
    endif
    
    ; Check current follow state and toggle
    bool isCurrentlyFollowing = FollowScript.HasFollowPackage(target)
    
    if isCurrentlyFollowing
        ; Check if they're waiting - if so, resume following instead of stopping
        if target.GetAV("WaitingForPlayer") > 0
            FollowScript.StartFollowing(target)
            ;Debug.Notification(target.GetDisplayName() + " is following again")
        else
            FollowScript.StopFollowing(target)
            ;Debug.Notification(target.GetDisplayName() + " stopped following")
        endif
    else
        ; Not following - start following
        ; Note: StartFollowing_IsEligible is a Global function, must call on type not instance
        if SeverActions_Follow.StartFollowing_IsEligible(target)
            FollowScript.StartFollowing(target)
            ;Debug.Notification(target.GetDisplayName() + " is now following")
        else
            ;Debug.Notification(target.GetDisplayName() + " cannot follow you")
        endif
    endif
EndFunction

; =============================================================================
; DISMISS ALL HANDLER
; =============================================================================

Function HandleDismissAll()
    if !FollowScript
        Debug.Notification("SeverActions: Follow script not configured!")
        return
    endif
    
    ; Find all followers and dismiss them
    Actor player = Game.GetPlayer()
    int dismissed = 0
    
    ; Search nearby actors
    Cell currentCell = player.GetParentCell()
    if currentCell
        int numRefs = currentCell.GetNumRefs(43) ; kActorCharacter
        int i = 0
        while i < numRefs
            Actor npc = currentCell.GetNthRef(i, 43) as Actor
            if npc && npc != player && !npc.IsDead()
                if FollowScript.HasFollowPackage(npc)
                    FollowScript.StopFollowing(npc)
                    dismissed += 1
                endif
            endif
            i += 1
        endwhile
    endif
    
    if dismissed > 0
        Debug.Notification("Dismissed " + dismissed + " follower(s)")
    else
        Debug.Notification("No followers to dismiss")
    endif
EndFunction

; =============================================================================
; STAND UP HANDLER
; =============================================================================

Function HandleStandUp()
    if !FurnitureScript
        Debug.Notification("SeverActions: Furniture script not configured!")
        return
    endif
    
    Actor target = GetTargetActor()
    
    if !target
        Debug.Notification("No valid target found")
        return
    endif
    
    if target == Game.GetPlayer()
        Debug.Notification("Cannot target yourself")
        return
    endif
    
    ; Check if they're using furniture
    if SeverActions_Furniture.StopUsingFurniture_IsEligible(target)
        FurnitureScript.StopUsingFurniture_Execute(target)
        ; Notification is handled by the furniture script via SkyrimNet event
    else
        Debug.Notification(target.GetDisplayName() + " is not using furniture")
    endif
EndFunction

; =============================================================================
; YIELD HANDLER
; =============================================================================

Function HandleYield()
    if !CombatScript
        Debug.Notification("SeverActions: Combat script not configured!")
        return
    endif

    Actor target = GetTargetActor()

    if !target
        Debug.Notification("No valid target found")
        return
    endif

    if target == Game.GetPlayer()
        Debug.Notification("Cannot target yourself")
        return
    endif

    ; Check if yield can be performed (must be in combat)
    if CombatScript.Yield_IsEligible(target)
        CombatScript.Yield_Execute(target)
        Debug.Notification(target.GetDisplayName() + " has surrendered")
    else
        Debug.Notification(target.GetDisplayName() + " is not in combat")
    endif
EndFunction

; =============================================================================
; UNDRESS HANDLER
; =============================================================================

Function HandleUndress()
    if !OutfitScript
        Debug.Notification("SeverActions: Outfit script not configured!")
        return
    endif
    
    Actor target = GetTargetActor()
    
    if !target
        Debug.Notification("No valid target found")
        return
    endif
    
    if target == Game.GetPlayer()
        Debug.Notification("Cannot target yourself")
        return
    endif
    
    ; Check if undress can be performed
    if OutfitScript.Undress_IsEligible(target)
        OutfitScript.Undress_Execute(target)
        Debug.Notification(target.GetDisplayName() + " - undressed")
    else
        Debug.Notification(target.GetDisplayName() + " cannot be undressed")
    endif
EndFunction

; =============================================================================
; DRESS HANDLER
; =============================================================================

Function HandleDress()
    if !OutfitScript
        Debug.Notification("SeverActions: Outfit script not configured!")
        return
    endif
    
    Actor target = GetTargetActor()
    
    if !target
        Debug.Notification("No valid target found")
        return
    endif
    
    if target == Game.GetPlayer()
        Debug.Notification("Cannot target yourself")
        return
    endif
    
    ; Check if dress can be performed (has stored clothing)
    if OutfitScript.Dress_IsEligible(target)
        OutfitScript.Dress_Execute(target)
        Debug.Notification(target.GetDisplayName() + " - dressed")
    else
        Debug.Notification(target.GetDisplayName() + " has no stored clothing")
    endif
EndFunction

; =============================================================================
; SET COMPANION HANDLER
; =============================================================================

Function HandleSetCompanion()
    if !FollowerManagerScript
        ; Fallback: try to get instance
        FollowerManagerScript = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_FollowerManager
    endif

    if !FollowerManagerScript
        Debug.Notification("SeverActions: Follower Manager script not configured!")
        return
    endif

    Actor target = GetTargetActor()

    if !target
        Debug.Notification("No valid target found")
        return
    endif

    if target == Game.GetPlayer()
        Debug.Notification("Cannot target yourself")
        return
    endif

    ; Register as companion
    FollowerManagerScript.RegisterFollower(target)
EndFunction

; =============================================================================
; COMPANION WAIT HANDLER
; =============================================================================

Function HandleCompanionWait()
    if !FollowerManagerScript
        FollowerManagerScript = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_FollowerManager
    endif

    if !FollowerManagerScript
        Debug.Notification("SeverActions: Follower Manager not configured!")
        return
    endif

    Actor target = GetTargetActor()

    if !target
        Debug.Notification("No valid target found")
        return
    endif

    if target == Game.GetPlayer()
        Debug.Notification("Cannot target yourself")
        return
    endif

    ; Toggle: if waiting, resume following; if not, wait
    if target.GetAV("WaitingForPlayer") > 0
        if FollowScript
            FollowScript.StartFollowing(target)
        endif
    else
        FollowerManagerScript.CompanionWait(target)
    endif
EndFunction

; =============================================================================
; TARGET ACQUISITION
; =============================================================================

Actor Function GetTargetActor()
    if TargetMode == 0
        return GetCrosshairTarget()
    elseif TargetMode == 1
        return GetNearestNPC()
    elseif TargetMode == 2
        return GetLastTalkedTo()
    endif
    
    ; Default to crosshair
    return GetCrosshairTarget()
EndFunction

Actor Function GetCrosshairTarget()
    ; Get whatever the player is looking at
    ObjectReference crosshairRef = Game.GetCurrentCrosshairRef()
    
    if crosshairRef
        Actor target = crosshairRef as Actor
        if target && !target.IsDead()
            return target
        endif
    endif
    
    return None
EndFunction

Actor Function GetNearestNPC()
    Actor player = Game.GetPlayer()
    Actor nearest = None
    float nearestDist = NearestNPCRadius + 1.0
    
    Cell currentCell = player.GetParentCell()
    if currentCell
        int numRefs = currentCell.GetNumRefs(43) ; kActorCharacter
        int i = 0
        while i < numRefs
            Actor npc = currentCell.GetNthRef(i, 43) as Actor
            if npc && npc != player && !npc.IsDead() && npc.Is3DLoaded()
                float dist = player.GetDistance(npc)
                if dist < nearestDist
                    nearestDist = dist
                    nearest = npc
                endif
            endif
            i += 1
        endwhile
    endif
    
    return nearest
EndFunction

Actor Function GetLastTalkedTo()
    if LastTalkedTo && !LastTalkedTo.IsDead()
        return LastTalkedTo
    endif
    return None
EndFunction

; =============================================================================
; DIALOGUE TRACKING - Call from dialogue events to track last talked to
; =============================================================================

Function SetLastTalkedTo(Actor akActor)
    LastTalkedTo = akActor
EndFunction

; =============================================================================
; SINGLETON ACCESS
; =============================================================================

SeverActions_Hotkeys Function GetInstance() Global
    ; Update this FormID to match your quest's FormID in CK
    return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Hotkeys
EndFunction