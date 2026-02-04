Scriptname SeverActions_WheelMenu extends Quest
{Wheel menu interface for SeverActions - requires UIExtensions mod}

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

; =============================================================================
; WHEEL HOTKEY SETTING - Configured via MCM
; =============================================================================

int Property WheelMenuKey = -1 Auto Hidden
{Key code for opening wheel menu. -1 = unset/disabled}

bool Property IsRegistered = false Auto Hidden

; =============================================================================
; OPTION INDICES (matches wheel positions)
; =============================================================================

int Property OPT_TOGGLE_FOLLOW = 0 AutoReadOnly
int Property OPT_DISMISS_ALL = 1 AutoReadOnly
int Property OPT_STAND_UP = 2 AutoReadOnly
int Property OPT_YIELD = 3 AutoReadOnly
int Property OPT_UNDRESS = 4 AutoReadOnly
int Property OPT_DRESS = 5 AutoReadOnly
int Property OPT_CANCEL = 6 AutoReadOnly
; Index 7 reserved for future use

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    Debug.Trace("[SeverActions_WheelMenu] Initialized")
    RegisterWheelKey()
EndEvent

Event OnPlayerLoadGame()
    Debug.Trace("[SeverActions_WheelMenu] Game loaded, re-registering wheel key")
    RegisterWheelKey()
EndEvent

; =============================================================================
; KEY REGISTRATION
; =============================================================================

Function RegisterWheelKey()
    UnregisterForAllKeys()
    IsRegistered = false

    if WheelMenuKey > 0
        RegisterForKey(WheelMenuKey)
        IsRegistered = true
        Debug.Trace("[SeverActions_WheelMenu] Registered wheel menu key: " + WheelMenuKey)
    else
        Debug.Trace("[SeverActions_WheelMenu] Wheel menu key not set")
    endif
EndFunction

Function UpdateWheelMenuKey(int newKey)
    ; Unregister old key if it was valid
    if WheelMenuKey > 0 && WheelMenuKey != newKey
        UnregisterForKey(WheelMenuKey)
    endif

    WheelMenuKey = newKey

    ; Register new key (only if valid)
    if newKey > 0
        RegisterForKey(newKey)
        IsRegistered = true
        Debug.Trace("[SeverActions_WheelMenu] Updated wheel menu key to: " + newKey)
    else
        IsRegistered = false
        Debug.Trace("[SeverActions_WheelMenu] Wheel menu key cleared")
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

    ; Check if UIExtensions is installed
    if !IsUIExtensionsInstalled()
        Debug.Notification("SeverActions: UIExtensions mod required for wheel menu!")
        return
    endif

    Actor player = Game.GetPlayer()

    ; Ignore if player is in dialogue, dead, or incapacitated
    if player.IsInDialogueWithPlayer() || player.IsDead() || player.GetSitState() == 3
        return
    endif

    if keyCode == WheelMenuKey && WheelMenuKey > 0
        OpenWheelMenu()
    endif
EndEvent

; =============================================================================
; UIEXTENSIONS CHECK
; =============================================================================

bool Function IsUIExtensionsInstalled()
    return Game.GetModByName("UIExtensions.esp") != 255
EndFunction

; =============================================================================
; WHEEL MENU
; =============================================================================

Function OpenWheelMenu()
    ; Get target first so we can show context-aware options
    Actor target = GetCrosshairTarget()

    ; Initialize the wheel menu
    UIExtensions.InitMenu("UIWheelMenu")

    ; Set up options with icons
    ; Option 0 - Toggle Follow
    if target && FollowScript
        bool isFollowing = FollowScript.HasFollowPackage(target)
        if isFollowing
            if target.GetAV("WaitingForPlayer") > 0
                UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionText", OPT_TOGGLE_FOLLOW, "Resume Follow")
            else
                UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionText", OPT_TOGGLE_FOLLOW, "Stop Follow")
            endif
        else
            UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionText", OPT_TOGGLE_FOLLOW, "Start Follow")
        endif
    else
        UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionText", OPT_TOGGLE_FOLLOW, "Toggle Follow")
    endif
    UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionLabelText", OPT_TOGGLE_FOLLOW, "Follow")

    ; Option 1 - Dismiss All
    UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionText", OPT_DISMISS_ALL, "Dismiss All")
    UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionLabelText", OPT_DISMISS_ALL, "Dismiss")

    ; Option 2 - Stand Up
    UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionText", OPT_STAND_UP, "Stand Up")
    UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionLabelText", OPT_STAND_UP, "Furniture")

    ; Option 3 - Yield/Surrender
    UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionText", OPT_YIELD, "Yield")
    UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionLabelText", OPT_YIELD, "Surrender")

    ; Option 4 - Undress
    UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionText", OPT_UNDRESS, "Undress")
    UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionLabelText", OPT_UNDRESS, "Undress")

    ; Option 5 - Dress
    UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionText", OPT_DRESS, "Dress")
    UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionLabelText", OPT_DRESS, "Dress")

    ; Option 6 - Cancel
    UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionText", OPT_CANCEL, "Cancel")
    UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionLabelText", OPT_CANCEL, "")
    UIExtensions.SetMenuPropertyIndexInt("UIWheelMenu", "optionTextColor", OPT_CANCEL, 0x808080) ; Gray

    ; Option 7 - Empty/Reserved
    UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionText", 7, "")
    UIExtensions.SetMenuPropertyIndexBool("UIWheelMenu", "optionEnabled", 7, false)

    ; Enable all options except reserved slot
    int i = 0
    while i < 7
        UIExtensions.SetMenuPropertyIndexBool("UIWheelMenu", "optionEnabled", i, true)
        i += 1
    endwhile

    ; Open menu and get selection
    int selection = UIExtensions.OpenMenu("UIWheelMenu")

    ; Handle selection
    HandleWheelSelection(selection, target)
EndFunction

Function HandleWheelSelection(int selection, Actor target)
    ; 255 = cancelled (clicked outside or escape)
    if selection == 255 || selection == OPT_CANCEL
        return
    endif

    ; For most actions, we need a target
    if selection != OPT_DISMISS_ALL && !target
        Debug.Notification("No valid target - look at an NPC")
        return
    endif

    if target == Game.GetPlayer()
        Debug.Notification("Cannot target yourself")
        return
    endif

    if selection == OPT_TOGGLE_FOLLOW
        HandleFollowToggle(target)
    elseif selection == OPT_DISMISS_ALL
        HandleDismissAll()
    elseif selection == OPT_STAND_UP
        HandleStandUp(target)
    elseif selection == OPT_YIELD
        HandleYield(target)
    elseif selection == OPT_UNDRESS
        HandleUndress(target)
    elseif selection == OPT_DRESS
        HandleDress(target)
    endif
EndFunction

; =============================================================================
; ACTION HANDLERS (same logic as hotkeys, but consolidated here)
; =============================================================================

Function HandleFollowToggle(Actor target)
    if !FollowScript
        Debug.Notification("SeverActions: Follow script not configured!")
        return
    endif

    ; Check current follow state and toggle
    bool isCurrentlyFollowing = FollowScript.HasFollowPackage(target)

    if isCurrentlyFollowing
        ; Check if they're waiting - if so, resume following instead of stopping
        if target.GetAV("WaitingForPlayer") > 0
            FollowScript.StartFollowing(target)
        else
            FollowScript.StopFollowing(target)
        endif
    else
        ; Not following - start following
        if SeverActions_Follow.StartFollowing_IsEligible(target)
            FollowScript.StartFollowing(target)
        endif
    endif
EndFunction

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

Function HandleStandUp(Actor target)
    if !FurnitureScript
        Debug.Notification("SeverActions: Furniture script not configured!")
        return
    endif

    ; Check if they're using furniture
    if SeverActions_Furniture.StopUsingFurniture_IsEligible(target)
        FurnitureScript.StopUsingFurniture_Execute(target)
    else
        Debug.Notification(target.GetDisplayName() + " is not using furniture")
    endif
EndFunction

Function HandleYield(Actor target)
    if !CombatScript
        Debug.Notification("SeverActions: Combat script not configured!")
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

Function HandleUndress(Actor target)
    if !OutfitScript
        Debug.Notification("SeverActions: Outfit script not configured!")
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

Function HandleDress(Actor target)
    if !OutfitScript
        Debug.Notification("SeverActions: Outfit script not configured!")
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
; TARGET ACQUISITION
; =============================================================================

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

; =============================================================================
; SINGLETON ACCESS
; =============================================================================

SeverActions_WheelMenu Function GetInstance() Global
    ; Update this FormID to match your quest's FormID in CK
    return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_WheelMenu
EndFunction