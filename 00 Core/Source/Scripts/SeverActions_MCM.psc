Scriptname SeverActions_MCM extends SKI_ConfigBase
{MCM Configuration menu for SeverActions - includes hotkey configuration}

; =============================================================================
; SCRIPT REFERENCES - Set in CK or use GetInstance functions
; =============================================================================

SeverActions_Currency Property CurrencyScript Auto
SeverActions_Travel Property TravelScript Auto
SeverActions_Hotkeys Property HotkeyScript Auto
SeverActions_Combat Property CombatScript Auto
SeverActions_Outfit Property OutfitScript Auto
SeverActions_WheelMenu Property WheelMenuScript Auto
SeverActions_Arrest Property ArrestScript Auto
SeverActions_Survival Property SurvivalScript Auto
SeverActions_FollowerManager Property FollowerManagerScript Auto

; =============================================================================
; SETTINGS - These mirror the properties in other scripts
; =============================================================================

; Currency Settings
bool Property AllowConjuredGold = true Auto

; Dialogue Animation Settings (stored here, applied to native DLL)
bool Property DialogueAnimEnabled = true Auto Hidden

; Hotkey Settings (stored here, applied to HotkeyScript)
int Property FollowToggleKey = -1 Auto Hidden
int Property DismissAllKey = -1 Auto Hidden
int Property StandUpKey = -1 Auto Hidden
int Property YieldKey = -1 Auto Hidden
int Property UndressKey = -1 Auto Hidden
int Property DressKey = -1 Auto Hidden
int Property TargetMode = 0 Auto Hidden
float Property NearestNPCRadius = 500.0 Auto Hidden

; Wheel Menu Settings (stored here, applied to WheelMenuScript)
int Property WheelMenuKey = -1 Auto Hidden

; =============================================================================
; MCM STATE - Option IDs
; =============================================================================

; General page
int OID_Version

; Currency page
int OID_AllowConjuredGold

; Travel page
int OID_ResetTravelSlots
int OID_TravelSlot0
int OID_TravelSlot1
int OID_TravelSlot2
int OID_TravelSlot3
int OID_TravelSlot4
int OID_ActiveSlotCount

; Hotkeys page
int OID_FollowToggleKey
int OID_DismissAllKey
int OID_StandUpKey
int OID_YieldKey
int OID_UndressKey
int OID_DressKey
int OID_TargetMode
int OID_NearestNPCRadius
int OID_WheelMenuKey

; Crime page
int OID_BountyWhiterun
int OID_BountyRift
int OID_BountyHaafingar
int OID_BountyEastmarch
int OID_BountyReach
int OID_BountyFalkreath
int OID_BountyPale
int OID_BountyHjaalmarch
int OID_BountyWinterhold
int OID_ClearAllBounties
int OID_ArrestCooldown
int OID_PersuasionTimeLimit

; General page - Native DLL toggles
int OID_DialogueAnimEnabled

; Survival page
int OID_SurvivalEnabled
int OID_HungerEnabled
int OID_HungerRate
int OID_AutoEatThreshold
int OID_FatigueEnabled
int OID_FatigueRate
int OID_ColdEnabled
int OID_ColdRate
int OID_SurvivalNotifications
int OID_SurvivalDebug

; Per-follower exclusion toggles (up to 10 followers shown)
int[] OID_FollowerExclude
Actor[] CachedFollowers

; Follower Manager page
int OID_FM_MaxFollowers
int OID_FM_RapportDecay
int OID_FM_AllowLeaving
int OID_FM_LeavingThreshold
int OID_FM_Notifications
int OID_FM_Debug
int OID_FM_ResetAll
int[] OID_FM_DismissFollower
int[] OID_FM_ClearHome
int[] OID_FM_Rapport
int[] OID_FM_Trust
int[] OID_FM_Loyalty
int[] OID_FM_Mood
int[] OID_FM_CombatStyle
Actor[] CachedManagedFollowers

; Combat style dropdown options
string[] CombatStyleOptions

; Page names
string PAGE_GENERAL = "General"
string PAGE_HOTKEYS = "Hotkeys"
string PAGE_CURRENCY = "Currency"
string PAGE_TRAVEL = "Travel"
string PAGE_CRIME = "Crime"
string PAGE_SURVIVAL = "Survival"
string PAGE_FOLLOWERS = "Followers"

; Target mode options
string[] TargetModeOptions

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnConfigInit()
    ModName = "SeverActions"

    ; Set current version - increment this when you make MCM changes
    ; Format: major * 100 + minor (e.g., 107 = version 1.07)
    CurrentVersion = 110

    Pages = new string[7]
    Pages[0] = PAGE_GENERAL
    Pages[1] = PAGE_HOTKEYS
    Pages[2] = PAGE_CURRENCY
    Pages[3] = PAGE_TRAVEL
    Pages[4] = PAGE_CRIME
    Pages[5] = PAGE_SURVIVAL
    Pages[6] = PAGE_FOLLOWERS

    ; Initialize target mode dropdown options
    TargetModeOptions = new string[3]
    TargetModeOptions[0] = "Crosshair Target"
    TargetModeOptions[1] = "Nearest NPC"
    TargetModeOptions[2] = "Last Talked To"

    ; Initialize combat style dropdown options
    CombatStyleOptions = new string[5]
    CombatStyleOptions[0] = "balanced"
    CombatStyleOptions[1] = "aggressive"
    CombatStyleOptions[2] = "defensive"
    CombatStyleOptions[3] = "ranged"
    CombatStyleOptions[4] = "healer"
EndEvent

Event OnVersionUpdate(int newVersion)
    ; Called when CurrentVersion is higher than saved version
    Debug.Trace("[SeverActions_MCM] Updating from version " + CurrentVersion + " to " + newVersion)

    ; Force page rebuild on any version change
    Pages = new string[7]
    Pages[0] = PAGE_GENERAL
    Pages[1] = PAGE_HOTKEYS
    Pages[2] = PAGE_CURRENCY
    Pages[3] = PAGE_TRAVEL
    Pages[4] = PAGE_CRIME
    Pages[5] = PAGE_SURVIVAL
    Pages[6] = PAGE_FOLLOWERS

    ; Re-initialize dropdown options
    TargetModeOptions = new string[3]
    TargetModeOptions[0] = "Crosshair Target"
    TargetModeOptions[1] = "Nearest NPC"
    TargetModeOptions[2] = "Last Talked To"

    ; Re-initialize combat style dropdown options
    CombatStyleOptions = new string[5]
    CombatStyleOptions[0] = "balanced"
    CombatStyleOptions[1] = "aggressive"
    CombatStyleOptions[2] = "defensive"
    CombatStyleOptions[3] = "ranged"
    CombatStyleOptions[4] = "healer"
EndEvent

; Force MCM to rebuild - call this on game load
Function ForceMenuRebuild()
    OnConfigInit()
    Debug.Trace("[SeverActions_MCM] Forced menu rebuild")
EndFunction

; Get singleton instance
SeverActions_MCM Function GetInstance() Global
    return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_MCM
EndFunction

; =============================================================================
; PAGE LAYOUT
; =============================================================================

Event OnPageReset(string page)
    SetCursorFillMode(TOP_TO_BOTTOM)

    if page == "" || page == PAGE_GENERAL
        DrawGeneralPage()
    elseif page == PAGE_HOTKEYS
        DrawHotkeysPage()
    elseif page == PAGE_CURRENCY
        DrawCurrencyPage()
    elseif page == PAGE_TRAVEL
        DrawTravelPage()
    elseif page == PAGE_CRIME
        DrawCrimePage()
    elseif page == PAGE_SURVIVAL
        DrawSurvivalPage()
    elseif page == PAGE_FOLLOWERS
        DrawFollowersPage()
    endif
EndEvent

Function DrawGeneralPage()
    SetCursorFillMode(TOP_TO_BOTTOM)

    AddHeaderOption("SeverActions Configuration")
    AddEmptyOption()
    OID_Version = AddTextOption("Version", "1.08")
    AddTextOption("Author", "Severause")
    AddEmptyOption()
    AddTextOption("", "Configure SeverActions modules")
    AddTextOption("", "using the pages on the left.")
    AddEmptyOption()
    AddHeaderOption("Native Features")
    OID_DialogueAnimEnabled = AddToggleOption("Dialogue Animations", DialogueAnimEnabled)

    AddEmptyOption()
    AddHeaderOption("Quick Reference")
    AddTextOption("", "Hotkeys - Keyboard shortcuts")
    AddTextOption("", "Currency - Gold/payment settings")
    AddTextOption("", "Travel - NPC travel system")
    AddTextOption("", "Crime - View/manage bounties")
    AddTextOption("", "Survival - Follower survival needs")
    AddTextOption("", "Followers - Companion framework")
EndFunction

Function DrawHotkeysPage()
    SetCursorFillMode(TOP_TO_BOTTOM)

    ; --- Wheel Menu (at the top since it's a combined interface) ---
    AddHeaderOption("Wheel Menu (Requires UIExtensions)")
    OID_WheelMenuKey = AddKeyMapOption("Open Wheel Menu", WheelMenuKey)
    AddTextOption("", "All actions in one menu - crosshair target")

    AddEmptyOption()
    AddHeaderOption("Follow System Hotkeys")
    OID_FollowToggleKey = AddKeyMapOption("Toggle Follow", FollowToggleKey)
    OID_DismissAllKey = AddKeyMapOption("Dismiss All Followers", DismissAllKey)

    AddEmptyOption()
    AddHeaderOption("Furniture Hotkeys")
    OID_StandUpKey = AddKeyMapOption("Make NPC Stand Up", StandUpKey)

    AddEmptyOption()
    AddHeaderOption("Combat Hotkeys")
    OID_YieldKey = AddKeyMapOption("Make NPC Yield/Surrender", YieldKey)

    AddEmptyOption()
    AddHeaderOption("Outfit Hotkeys")
    OID_UndressKey = AddKeyMapOption("Undress NPC", UndressKey)
    OID_DressKey = AddKeyMapOption("Dress NPC", DressKey)

    AddEmptyOption()
    AddHeaderOption("Target Selection (Hotkeys Only)")
    OID_TargetMode = AddMenuOption("Target Mode", TargetModeOptions[TargetMode])

    ; Only show radius option if using Nearest NPC mode
    if TargetMode == 1
        OID_NearestNPCRadius = AddSliderOption("Search Radius", NearestNPCRadius, "{0} units")
    else
        OID_NearestNPCRadius = AddTextOption("Search Radius", "N/A (using " + TargetModeOptions[TargetMode] + ")")
    endif

    ; Show hotkey script status
    AddEmptyOption()
    AddHeaderOption("Status")
    if HotkeyScript
        if HotkeyScript.IsRegistered
            AddTextOption("Hotkey System", "Active", OPTION_FLAG_DISABLED)
        else
            AddTextOption("Hotkey System", "Not Registered", OPTION_FLAG_DISABLED)
        endif
    else
        AddTextOption("Hotkey System", "ERROR: Script not linked!", OPTION_FLAG_DISABLED)
    endif

    ; Show wheel menu status
    if WheelMenuScript
        if Game.GetModByName("UIExtensions.esp") != 255
            if WheelMenuScript.IsRegistered
                AddTextOption("Wheel Menu", "Active", OPTION_FLAG_DISABLED)
            else
                AddTextOption("Wheel Menu", "Key not set", OPTION_FLAG_DISABLED)
            endif
        else
            AddTextOption("Wheel Menu", "UIExtensions not found!", OPTION_FLAG_DISABLED)
        endif
    else
        AddTextOption("Wheel Menu", "Script not linked", OPTION_FLAG_DISABLED)
    endif
EndFunction

Function DrawCurrencyPage()
    SetCursorFillMode(TOP_TO_BOTTOM)
    
    AddHeaderOption("Gold Settings")
    OID_AllowConjuredGold = AddToggleOption("Allow Conjured Gold", AllowConjuredGold)
    AddTextOption("", "When enabled, NPCs can give gold")
    AddTextOption("", "even if they don't have any.")
    AddEmptyOption()
    AddTextOption("", "Disable for more realistic economy")
    AddTextOption("", "where NPCs need actual gold to give.")
EndFunction

Function DrawTravelPage()
    SetCursorFillMode(TOP_TO_BOTTOM)
    
    AddHeaderOption("Travel Slot Status")
    
    If TravelScript
        Int activeCount = TravelScript.GetActiveTravelCount()
        OID_ActiveSlotCount = AddTextOption("Active Slots", activeCount + " / 5")
        AddEmptyOption()
        
        ; Show each slot's status - clickable to clear if active
        OID_TravelSlot0 = AddTextOption("Slot 0", TravelScript.GetSlotStatusText(0))
        OID_TravelSlot1 = AddTextOption("Slot 1", TravelScript.GetSlotStatusText(1))
        OID_TravelSlot2 = AddTextOption("Slot 2", TravelScript.GetSlotStatusText(2))
        OID_TravelSlot3 = AddTextOption("Slot 3", TravelScript.GetSlotStatusText(3))
        OID_TravelSlot4 = AddTextOption("Slot 4", TravelScript.GetSlotStatusText(4))
        
        AddEmptyOption()
        AddTextOption("", "Click a slot to clear it.")
        
        AddEmptyOption()
        AddHeaderOption("Maintenance")
        OID_ResetTravelSlots = AddTextOption("Reset All Travel Slots", "CLICK")
        AddTextOption("", "Use if slots are stuck or broken.")
    Else
        AddTextOption("", "Travel script not connected!")
        AddTextOption("", "Set TravelScript property in CK.")
    EndIf
EndFunction

Function DrawCrimePage()
    SetCursorFillMode(TOP_TO_BOTTOM)

    AddHeaderOption("Tracked Bounties")
    AddTextOption("", "Bounties tracked by SeverActions.")
    AddTextOption("", "Vanilla guards won't see these.")
    AddEmptyOption()

    If ArrestScript
        ; Display bounty for each hold
        OID_BountyWhiterun = AddTextOption("$Whiterun", GetBountyDisplayText(ArrestScript.CrimeFactionWhiterun))
        OID_BountyRift = AddTextOption("$The Rift", GetBountyDisplayText(ArrestScript.CrimeFactionRift))
        OID_BountyHaafingar = AddTextOption("$Haafingar", GetBountyDisplayText(ArrestScript.CrimeFactionHaafingar))
        OID_BountyEastmarch = AddTextOption("$Eastmarch", GetBountyDisplayText(ArrestScript.CrimeFactionEastmarch))
        OID_BountyReach = AddTextOption("$The Reach", GetBountyDisplayText(ArrestScript.CrimeFactionReach))
        OID_BountyFalkreath = AddTextOption("$Falkreath", GetBountyDisplayText(ArrestScript.CrimeFactionFalkreath))
        OID_BountyPale = AddTextOption("$The Pale", GetBountyDisplayText(ArrestScript.CrimeFactionPale))
        OID_BountyHjaalmarch = AddTextOption("$Hjaalmarch", GetBountyDisplayText(ArrestScript.CrimeFactionHjaalmarch))
        OID_BountyWinterhold = AddTextOption("$Winterhold", GetBountyDisplayText(ArrestScript.CrimeFactionWinterhold))

        AddEmptyOption()
        AddHeaderOption("Settings")
        OID_ArrestCooldown = AddSliderOption("Arrest Cooldown", ArrestScript.ArrestPlayerCooldown, "{0} sec")
        OID_PersuasionTimeLimit = AddSliderOption("Persuasion Time", ArrestScript.PersuasionTimeLimit, "{0} sec")

        AddEmptyOption()
        AddHeaderOption("Maintenance")
        OID_ClearAllBounties = AddTextOption("Clear All Bounties", "CLICK")
        AddTextOption("", "Clears all tracked bounties.")
    Else
        AddTextOption("", "Arrest script not connected!")
        AddTextOption("", "Set ArrestScript property in CK.")
    EndIf
EndFunction

String Function GetBountyDisplayText(Faction akCrimeFaction)
    {Get display text for a bounty amount}
    If ArrestScript
        Int bounty = ArrestScript.GetTrackedBounty(akCrimeFaction)
        If bounty > 0
            Return bounty + " gold"
        Else
            Return "None"
        EndIf
    EndIf
    Return "N/A"
EndFunction

Function DrawSurvivalPage()
    SetCursorFillMode(TOP_TO_BOTTOM)

    AddHeaderOption("Follower Survival System")
    AddTextOption("", "Track hunger, fatigue, and cold")
    AddTextOption("", "for your followers.")
    AddEmptyOption()

    If SurvivalScript
        ; Master toggle
        OID_SurvivalEnabled = AddToggleOption("Enable Survival System", SurvivalScript.Enabled)
        AddEmptyOption()

        ; Hunger settings
        AddHeaderOption("Hunger")
        OID_HungerEnabled = AddToggleOption("Track Hunger", SurvivalScript.HungerEnabled)
        OID_HungerRate = AddSliderOption("Hunger Rate", SurvivalScript.HungerRate, "{1}x")
        OID_AutoEatThreshold = AddSliderOption("Auto-Eat Threshold", SurvivalScript.AutoEatThreshold as Float, "{0}%")
        AddTextOption("", "Auto-eat when hunger exceeds threshold.")

        AddEmptyOption()

        ; Fatigue settings
        AddHeaderOption("Fatigue")
        OID_FatigueEnabled = AddToggleOption("Track Fatigue", SurvivalScript.FatigueEnabled)
        OID_FatigueRate = AddSliderOption("Fatigue Rate", SurvivalScript.FatigueRate, "{1}x")
        AddTextOption("", "Fatigue resets when player sleeps.")

        AddEmptyOption()

        ; Cold settings
        AddHeaderOption("Cold")
        OID_ColdEnabled = AddToggleOption("Track Cold", SurvivalScript.ColdEnabled)
        OID_ColdRate = AddSliderOption("Cold Rate", SurvivalScript.ColdRate, "{1}x")
        AddTextOption("", "Based on weather and location.")

        AddEmptyOption()

        ; Notifications and debug
        AddHeaderOption("Notifications")
        OID_SurvivalNotifications = AddToggleOption("Show Notifications", SurvivalScript.ShowNotifications)
        OID_SurvivalDebug = AddToggleOption("Debug Mode", SurvivalScript.DebugMode)

        ; Per-follower tracking
        AddEmptyOption()
        AddHeaderOption("Follower Tracking")
        AddTextOption("", "Toggle survival for individual followers.")
        AddTextOption("", "Excluded followers won't get hungry/tired/cold.")

        ; Cache current followers and create toggles
        CachedFollowers = SurvivalScript.GetCurrentFollowers()
        OID_FollowerExclude = new int[10]

        If CachedFollowers.Length == 0
            AddTextOption("", "No followers detected", OPTION_FLAG_DISABLED)
        Else
            Int j = 0
            While j < CachedFollowers.Length && j < 10
                Actor follower = CachedFollowers[j]
                If follower
                    Bool isExcluded = SurvivalScript.IsFollowerExcluded(follower)
                    OID_FollowerExclude[j] = AddToggleOption(follower.GetDisplayName(), !isExcluded)
                EndIf
                j += 1
            EndWhile
        EndIf

        ; Status display
        AddEmptyOption()
        AddHeaderOption("Status")
        Int followerCount = SurvivalScript.GetTrackedFollowerCount()
        Int totalFollowers = CachedFollowers.Length
        AddTextOption("Tracked Followers", followerCount + " / " + totalFollowers)
    Else
        AddTextOption("", "Survival script not connected!")
        AddTextOption("", "Set SurvivalScript property in CK.")
    EndIf
EndFunction

Function DrawFollowersPage()
    SetCursorFillMode(TOP_TO_BOTTOM)

    AddHeaderOption("Companion Framework")
    AddTextOption("", "Manage recruited companions and")
    AddTextOption("", "relationship settings.")
    AddEmptyOption()

    If FollowerManagerScript
        ; Settings
        AddHeaderOption("Settings")
        OID_FM_MaxFollowers = AddSliderOption("Max Companions", FollowerManagerScript.MaxFollowers as Float, "{0}")
        OID_FM_RapportDecay = AddSliderOption("Rapport Decay Rate", FollowerManagerScript.RapportDecayRate, "{1}x")
        OID_FM_AllowLeaving = AddToggleOption("Allow Autonomous Leaving", FollowerManagerScript.AllowAutonomousLeaving)
        OID_FM_LeavingThreshold = AddSliderOption("Leaving Threshold", FollowerManagerScript.LeavingThreshold, "{0}")
        OID_FM_Notifications = AddToggleOption("Show Notifications", FollowerManagerScript.ShowNotifications)
        OID_FM_Debug = AddToggleOption("Debug Mode", FollowerManagerScript.DebugMode)

        AddEmptyOption()

        ; Current companions
        AddHeaderOption("Current Companions")
        CachedManagedFollowers = FollowerManagerScript.GetAllFollowers()
        OID_FM_DismissFollower = new int[10]
        OID_FM_ClearHome = new int[10]
        OID_FM_Rapport = new int[10]
        OID_FM_Trust = new int[10]
        OID_FM_Loyalty = new int[10]
        OID_FM_Mood = new int[10]
        OID_FM_CombatStyle = new int[10]

        If CachedManagedFollowers.Length == 0
            AddTextOption("", "No companions recruited", OPTION_FLAG_DISABLED)
            AddTextOption("", "Adjust values here for mid-playthrough", OPTION_FLAG_DISABLED)
            AddTextOption("", "followers once they are recruited.", OPTION_FLAG_DISABLED)
        Else
            Int j = 0
            While j < CachedManagedFollowers.Length && j < 10
                Actor follower = CachedManagedFollowers[j]
                If follower
                    Float rapport = FollowerManagerScript.GetRapport(follower)
                    Float trust = FollowerManagerScript.GetTrust(follower)
                    Float loyalty = FollowerManagerScript.GetLoyalty(follower)
                    Float mood = FollowerManagerScript.GetMood(follower)
                    String style = FollowerManagerScript.GetCombatStyle(follower)
                    String home = FollowerManagerScript.GetAssignedHome(follower)

                    AddHeaderOption(follower.GetDisplayName())
                    OID_FM_Rapport[j] = AddSliderOption("$Rapport", rapport, "{0}")
                    OID_FM_Trust[j] = AddSliderOption("$Trust", trust, "{0}")
                    OID_FM_Loyalty[j] = AddSliderOption("$Loyalty", loyalty, "{0}")
                    OID_FM_Mood[j] = AddSliderOption("Mood", mood, "{0}")
                    OID_FM_CombatStyle[j] = AddMenuOption("Combat Style", style)
                    If home != ""
                        AddTextOption("Home", home, OPTION_FLAG_DISABLED)
                        OID_FM_ClearHome[j] = AddTextOption("Clear Home", "CLICK")
                    Else
                        AddTextOption("Home", "Not assigned", OPTION_FLAG_DISABLED)
                    EndIf
                    OID_FM_DismissFollower[j] = AddTextOption("Dismiss", "CLICK")
                    AddEmptyOption()
                EndIf
                j += 1
            EndWhile
        EndIf

        AddEmptyOption()
        AddHeaderOption("Maintenance")
        OID_FM_ResetAll = AddTextOption("Reset All Companions", "CLICK")
        AddTextOption("", "Emergency: dismiss and clear all data.")
    Else
        AddTextOption("", "Follower Manager not connected!")
        AddTextOption("", "Set FollowerManagerScript property in CK.")
    EndIf
EndFunction

; =============================================================================
; OPTION SELECTION
; =============================================================================

Event OnOptionSelect(int option)
    if option == OID_DialogueAnimEnabled
        DialogueAnimEnabled = !DialogueAnimEnabled
        SetToggleOptionValue(OID_DialogueAnimEnabled, DialogueAnimEnabled)
        SeverActionsNative.SetDialogueAnimEnabled(DialogueAnimEnabled)

    elseif option == OID_AllowConjuredGold
        AllowConjuredGold = !AllowConjuredGold
        SetToggleOptionValue(OID_AllowConjuredGold, AllowConjuredGold)
        ApplyCurrencySettings()
        
    elseif option == OID_ResetTravelSlots
        bool confirm = ShowMessage("This will cancel ALL active NPC travel, restore follower status, and reset all slots. Continue?", true, "Yes", "No")
        if confirm && TravelScript
            TravelScript.ForceResetAllSlots(true)
            ForcePageReset()
        endif
        
    elseif option == OID_TravelSlot0
        ClearTravelSlotWithConfirm(0)
    elseif option == OID_TravelSlot1
        ClearTravelSlotWithConfirm(1)
    elseif option == OID_TravelSlot2
        ClearTravelSlotWithConfirm(2)
    elseif option == OID_TravelSlot3
        ClearTravelSlotWithConfirm(3)
    elseif option == OID_TravelSlot4
        ClearTravelSlotWithConfirm(4)

    ; Crime page - clear individual bounties
    elseif option == OID_BountyWhiterun
        ClearBountyWithConfirm(ArrestScript.CrimeFactionWhiterun, "Whiterun")
    elseif option == OID_BountyRift
        ClearBountyWithConfirm(ArrestScript.CrimeFactionRift, "The Rift")
    elseif option == OID_BountyHaafingar
        ClearBountyWithConfirm(ArrestScript.CrimeFactionHaafingar, "Haafingar")
    elseif option == OID_BountyEastmarch
        ClearBountyWithConfirm(ArrestScript.CrimeFactionEastmarch, "Eastmarch")
    elseif option == OID_BountyReach
        ClearBountyWithConfirm(ArrestScript.CrimeFactionReach, "The Reach")
    elseif option == OID_BountyFalkreath
        ClearBountyWithConfirm(ArrestScript.CrimeFactionFalkreath, "Falkreath")
    elseif option == OID_BountyPale
        ClearBountyWithConfirm(ArrestScript.CrimeFactionPale, "The Pale")
    elseif option == OID_BountyHjaalmarch
        ClearBountyWithConfirm(ArrestScript.CrimeFactionHjaalmarch, "Hjaalmarch")
    elseif option == OID_BountyWinterhold
        ClearBountyWithConfirm(ArrestScript.CrimeFactionWinterhold, "Winterhold")
    elseif option == OID_ClearAllBounties
        ClearAllBountiesWithConfirm()

    ; Survival page toggles
    elseif option == OID_SurvivalEnabled
        If SurvivalScript
            SurvivalScript.Enabled = !SurvivalScript.Enabled
            SetToggleOptionValue(OID_SurvivalEnabled, SurvivalScript.Enabled)
            If SurvivalScript.Enabled
                SurvivalScript.StartTracking()
            Else
                SurvivalScript.StopTracking()
            EndIf
        EndIf
    elseif option == OID_HungerEnabled
        If SurvivalScript
            SurvivalScript.HungerEnabled = !SurvivalScript.HungerEnabled
            SetToggleOptionValue(OID_HungerEnabled, SurvivalScript.HungerEnabled)
        EndIf
    elseif option == OID_FatigueEnabled
        If SurvivalScript
            SurvivalScript.FatigueEnabled = !SurvivalScript.FatigueEnabled
            SetToggleOptionValue(OID_FatigueEnabled, SurvivalScript.FatigueEnabled)
        EndIf
    elseif option == OID_ColdEnabled
        If SurvivalScript
            SurvivalScript.ColdEnabled = !SurvivalScript.ColdEnabled
            SetToggleOptionValue(OID_ColdEnabled, SurvivalScript.ColdEnabled)
        EndIf
    elseif option == OID_SurvivalNotifications
        If SurvivalScript
            SurvivalScript.ShowNotifications = !SurvivalScript.ShowNotifications
            SetToggleOptionValue(OID_SurvivalNotifications, SurvivalScript.ShowNotifications)
        EndIf
    elseif option == OID_SurvivalDebug
        If SurvivalScript
            SurvivalScript.DebugMode = !SurvivalScript.DebugMode
            SetToggleOptionValue(OID_SurvivalDebug, SurvivalScript.DebugMode)
        EndIf

    ; Follower Manager page toggles
    elseif option == OID_FM_AllowLeaving
        If FollowerManagerScript
            FollowerManagerScript.AllowAutonomousLeaving = !FollowerManagerScript.AllowAutonomousLeaving
            SetToggleOptionValue(OID_FM_AllowLeaving, FollowerManagerScript.AllowAutonomousLeaving)
        EndIf
    elseif option == OID_FM_Notifications
        If FollowerManagerScript
            FollowerManagerScript.ShowNotifications = !FollowerManagerScript.ShowNotifications
            SetToggleOptionValue(OID_FM_Notifications, FollowerManagerScript.ShowNotifications)
        EndIf
    elseif option == OID_FM_Debug
        If FollowerManagerScript
            FollowerManagerScript.DebugMode = !FollowerManagerScript.DebugMode
            SetToggleOptionValue(OID_FM_Debug, FollowerManagerScript.DebugMode)
        EndIf
    elseif option == OID_FM_ResetAll
        If FollowerManagerScript
            bool confirm = ShowMessage("This will dismiss ALL companions and clear all relationship data. Continue?", true, "Yes", "No")
            If confirm
                Actor[] managed = FollowerManagerScript.GetAllFollowers()
                Int j = 0
                While j < managed.Length
                    If managed[j]
                        FollowerManagerScript.UnregisterFollower(managed[j], false)
                    EndIf
                    j += 1
                EndWhile
                ForcePageReset()
                Debug.Notification("All companions dismissed and data cleared.")
            EndIf
        EndIf

    ; Per-follower exclusion toggles and follower manager per-follower actions
    else
        ; Follower Manager dismiss/clear home buttons
        If FollowerManagerScript && OID_FM_DismissFollower && CachedManagedFollowers
            Int j = 0
            While j < CachedManagedFollowers.Length && j < 10
                If option == OID_FM_DismissFollower[j] && CachedManagedFollowers[j]
                    bool confirm = ShowMessage("Dismiss " + CachedManagedFollowers[j].GetDisplayName() + "?", true, "Yes", "No")
                    If confirm
                        FollowerManagerScript.UnregisterFollower(CachedManagedFollowers[j])
                        ForcePageReset()
                    EndIf
                ElseIf OID_FM_ClearHome && option == OID_FM_ClearHome[j] && CachedManagedFollowers[j]
                    FollowerManagerScript.ClearHome(CachedManagedFollowers[j])
                    Debug.Notification(CachedManagedFollowers[j].GetDisplayName() + "'s home cleared.")
                    ForcePageReset()
                EndIf
                j += 1
            EndWhile
        EndIf

        If SurvivalScript && OID_FollowerExclude && CachedFollowers
            Int j = 0
            While j < CachedFollowers.Length && j < 10
                If option == OID_FollowerExclude[j] && CachedFollowers[j]
                    SurvivalScript.ToggleFollowerExcluded(CachedFollowers[j])
                    Bool isExcluded = SurvivalScript.IsFollowerExcluded(CachedFollowers[j])
                    SetToggleOptionValue(option, !isExcluded)

                    If isExcluded
                        Debug.Notification(CachedFollowers[j].GetDisplayName() + " excluded from survival")
                    Else
                        Debug.Notification(CachedFollowers[j].GetDisplayName() + " included in survival")
                    EndIf
                EndIf
                j += 1
            EndWhile
        EndIf
    endif
EndEvent

Function ClearTravelSlotWithConfirm(Int slotIndex)
    {Clear a travel slot with user confirmation}
    Int slotState
    String statusText
    String confirmMsg
    Bool doConfirm
    
    If !TravelScript
        Return
    EndIf
    
    ; Check if slot is active
    slotState = TravelScript.GetSlotState(slotIndex)
    If slotState == 0
        ShowMessage("This slot is already empty.", false)
        Return
    EndIf
    
    statusText = TravelScript.GetSlotStatusText(slotIndex)
    confirmMsg = "Clear slot " + slotIndex + "? " + statusText + " This will cancel travel and restore follower status if applicable."
    doConfirm = ShowMessage(confirmMsg, true, "Yes", "No")
    
    If doConfirm
        TravelScript.ClearSlotFromMCM(slotIndex, true)
        ForcePageReset()
    EndIf
EndFunction

Function ClearBountyWithConfirm(Faction akCrimeFaction, String holdName)
    {Clear a specific hold's bounty with confirmation}
    If !ArrestScript || !akCrimeFaction
        Return
    EndIf

    Int bounty = ArrestScript.GetTrackedBounty(akCrimeFaction)
    If bounty <= 0
        ShowMessage("You have no bounty in " + holdName + ".", false)
        Return
    EndIf

    String confirmMsg = "Clear your " + bounty + " gold bounty in " + holdName + "?"
    Bool doConfirm = ShowMessage(confirmMsg, true, "Yes", "No")

    If doConfirm
        ArrestScript.ClearTrackedBounty(akCrimeFaction)
        ForcePageReset()
        Debug.Notification("Bounty cleared in " + holdName)
    EndIf
EndFunction

Function ClearAllBountiesWithConfirm()
    {Clear all bounties in all holds with confirmation}
    If !ArrestScript
        Return
    EndIf

    ; Check if there are any bounties to clear
    Int totalBounty = 0
    totalBounty += ArrestScript.GetTrackedBounty(ArrestScript.CrimeFactionWhiterun)
    totalBounty += ArrestScript.GetTrackedBounty(ArrestScript.CrimeFactionRift)
    totalBounty += ArrestScript.GetTrackedBounty(ArrestScript.CrimeFactionHaafingar)
    totalBounty += ArrestScript.GetTrackedBounty(ArrestScript.CrimeFactionEastmarch)
    totalBounty += ArrestScript.GetTrackedBounty(ArrestScript.CrimeFactionReach)
    totalBounty += ArrestScript.GetTrackedBounty(ArrestScript.CrimeFactionFalkreath)
    totalBounty += ArrestScript.GetTrackedBounty(ArrestScript.CrimeFactionPale)
    totalBounty += ArrestScript.GetTrackedBounty(ArrestScript.CrimeFactionHjaalmarch)
    totalBounty += ArrestScript.GetTrackedBounty(ArrestScript.CrimeFactionWinterhold)

    If totalBounty <= 0
        ShowMessage("You have no bounties in any hold.", false)
        Return
    EndIf

    String confirmMsg = "Clear ALL bounties across all holds? Total: " + totalBounty + " gold."
    Bool doConfirm = ShowMessage(confirmMsg, true, "Yes", "No")

    If doConfirm
        ArrestScript.ClearTrackedBounty(ArrestScript.CrimeFactionWhiterun)
        ArrestScript.ClearTrackedBounty(ArrestScript.CrimeFactionRift)
        ArrestScript.ClearTrackedBounty(ArrestScript.CrimeFactionHaafingar)
        ArrestScript.ClearTrackedBounty(ArrestScript.CrimeFactionEastmarch)
        ArrestScript.ClearTrackedBounty(ArrestScript.CrimeFactionReach)
        ArrestScript.ClearTrackedBounty(ArrestScript.CrimeFactionFalkreath)
        ArrestScript.ClearTrackedBounty(ArrestScript.CrimeFactionPale)
        ArrestScript.ClearTrackedBounty(ArrestScript.CrimeFactionHjaalmarch)
        ArrestScript.ClearTrackedBounty(ArrestScript.CrimeFactionWinterhold)
        ForcePageReset()
        Debug.Notification("All bounties cleared!")
    EndIf
EndFunction

; =============================================================================
; KEYMAP HANDLING
; =============================================================================

Event OnOptionKeyMapChange(int option, int keyCode, string conflictControl, string conflictName)
    ; Escape key (keyCode 1) clears the hotkey
    if keyCode == 1
        keyCode = -1
    endif

    ; Handle conflict checking (only if setting a real key, not clearing)
    if keyCode > 0 && conflictControl != ""
        string msg = "This key is already mapped to:\n" + conflictControl
        if conflictName != ""
            msg += " (" + conflictName + ")"
        endif
        msg += "\n\nAre you sure you want to use this key?"

        if !ShowMessage(msg, true, "Yes", "No")
            return
        endif
    endif

    if option == OID_FollowToggleKey
        FollowToggleKey = keyCode
        SetKeyMapOptionValue(OID_FollowToggleKey, keyCode)
        ApplyHotkeySettings()

    elseif option == OID_DismissAllKey
        DismissAllKey = keyCode
        SetKeyMapOptionValue(OID_DismissAllKey, keyCode)
        ApplyHotkeySettings()

    elseif option == OID_StandUpKey
        StandUpKey = keyCode
        SetKeyMapOptionValue(OID_StandUpKey, keyCode)
        ApplyHotkeySettings()

    elseif option == OID_YieldKey
        YieldKey = keyCode
        SetKeyMapOptionValue(OID_YieldKey, keyCode)
        ApplyHotkeySettings()

    elseif option == OID_UndressKey
        UndressKey = keyCode
        SetKeyMapOptionValue(OID_UndressKey, keyCode)
        ApplyHotkeySettings()

    elseif option == OID_DressKey
        DressKey = keyCode
        SetKeyMapOptionValue(OID_DressKey, keyCode)
        ApplyHotkeySettings()

    elseif option == OID_WheelMenuKey
        WheelMenuKey = keyCode
        SetKeyMapOptionValue(OID_WheelMenuKey, keyCode)
        ApplyWheelMenuSettings()
    endif
EndEvent

; =============================================================================
; MENU HANDLING (Target Mode dropdown)
; =============================================================================

Event OnOptionMenuOpen(int option)
    if option == OID_TargetMode
        SetMenuDialogStartIndex(TargetMode)
        SetMenuDialogDefaultIndex(0)
        SetMenuDialogOptions(TargetModeOptions)
    else
        ; Per-follower combat style menus
        If FollowerManagerScript && CachedManagedFollowers && OID_FM_CombatStyle
            Int j = 0
            While j < CachedManagedFollowers.Length && j < 10
                If option == OID_FM_CombatStyle[j] && CachedManagedFollowers[j]
                    String currentStyle = FollowerManagerScript.GetCombatStyle(CachedManagedFollowers[j])
                    Int startIdx = CombatStyleIndexFromString(currentStyle)
                    SetMenuDialogStartIndex(startIdx)
                    SetMenuDialogDefaultIndex(0)
                    SetMenuDialogOptions(CombatStyleOptions)
                EndIf
                j += 1
            EndWhile
        EndIf
    endif
EndEvent

Event OnOptionMenuAccept(int option, int index)
    if option == OID_TargetMode
        TargetMode = index
        SetMenuOptionValue(OID_TargetMode, TargetModeOptions[TargetMode])
        ApplyHotkeySettings()
        ; Force page refresh to show/hide radius slider
        ForcePageReset()
    else
        ; Per-follower combat style menus
        If FollowerManagerScript && CachedManagedFollowers && OID_FM_CombatStyle
            Int j = 0
            While j < CachedManagedFollowers.Length && j < 10
                If option == OID_FM_CombatStyle[j] && CachedManagedFollowers[j]
                    FollowerManagerScript.SetCombatStyle(CachedManagedFollowers[j], CombatStyleOptions[index])
                    SetMenuOptionValue(OID_FM_CombatStyle[j], CombatStyleOptions[index])
                EndIf
                j += 1
            EndWhile
        EndIf
    endif
EndEvent

; =============================================================================
; SLIDER HANDLING
; =============================================================================

Event OnOptionSliderOpen(int option)
    if option == OID_NearestNPCRadius
        SetSliderDialogStartValue(NearestNPCRadius)
        SetSliderDialogDefaultValue(500.0)
        SetSliderDialogRange(100.0, 2000.0)
        SetSliderDialogInterval(50.0)
    elseif option == OID_ArrestCooldown
        SetSliderDialogStartValue(ArrestScript.ArrestPlayerCooldown)
        SetSliderDialogDefaultValue(60.0)
        SetSliderDialogRange(0.0, 300.0)
        SetSliderDialogInterval(5.0)
    elseif option == OID_PersuasionTimeLimit
        SetSliderDialogStartValue(ArrestScript.PersuasionTimeLimit)
        SetSliderDialogDefaultValue(90.0)
        SetSliderDialogRange(30.0, 300.0)
        SetSliderDialogInterval(5.0)

    ; Survival sliders
    elseif option == OID_HungerRate
        If SurvivalScript
            SetSliderDialogStartValue(SurvivalScript.HungerRate)
            SetSliderDialogDefaultValue(1.0)
            SetSliderDialogRange(0.25, 3.0)
            SetSliderDialogInterval(0.25)
        EndIf
    elseif option == OID_AutoEatThreshold
        If SurvivalScript
            SetSliderDialogStartValue(SurvivalScript.AutoEatThreshold as Float)
            SetSliderDialogDefaultValue(50.0)
            SetSliderDialogRange(0.0, 100.0)
            SetSliderDialogInterval(5.0)
        EndIf
    elseif option == OID_FatigueRate
        If SurvivalScript
            SetSliderDialogStartValue(SurvivalScript.FatigueRate)
            SetSliderDialogDefaultValue(1.0)
            SetSliderDialogRange(0.25, 3.0)
            SetSliderDialogInterval(0.25)
        EndIf
    elseif option == OID_ColdRate
        If SurvivalScript
            SetSliderDialogStartValue(SurvivalScript.ColdRate)
            SetSliderDialogDefaultValue(1.0)
            SetSliderDialogRange(0.25, 3.0)
            SetSliderDialogInterval(0.25)
        EndIf

    ; Follower Manager sliders
    elseif option == OID_FM_MaxFollowers
        If FollowerManagerScript
            SetSliderDialogStartValue(FollowerManagerScript.MaxFollowers as Float)
            SetSliderDialogDefaultValue(5.0)
            SetSliderDialogRange(1.0, 10.0)
            SetSliderDialogInterval(1.0)
        EndIf
    elseif option == OID_FM_RapportDecay
        If FollowerManagerScript
            SetSliderDialogStartValue(FollowerManagerScript.RapportDecayRate)
            SetSliderDialogDefaultValue(1.0)
            SetSliderDialogRange(0.0, 5.0)
            SetSliderDialogInterval(0.25)
        EndIf
    elseif option == OID_FM_LeavingThreshold
        If FollowerManagerScript
            SetSliderDialogStartValue(FollowerManagerScript.LeavingThreshold)
            SetSliderDialogDefaultValue(-60.0)
            SetSliderDialogRange(-100.0, -10.0)
            SetSliderDialogInterval(5.0)
        EndIf

    ; Per-follower relationship sliders
    else
        If FollowerManagerScript && CachedManagedFollowers
            Int j = 0
            While j < CachedManagedFollowers.Length && j < 10
                If CachedManagedFollowers[j]
                    If option == OID_FM_Rapport[j]
                        SetSliderDialogStartValue(FollowerManagerScript.GetRapport(CachedManagedFollowers[j]))
                        SetSliderDialogDefaultValue(0.0)
                        SetSliderDialogRange(-100.0, 100.0)
                        SetSliderDialogInterval(5.0)
                    ElseIf option == OID_FM_Trust[j]
                        SetSliderDialogStartValue(FollowerManagerScript.GetTrust(CachedManagedFollowers[j]))
                        SetSliderDialogDefaultValue(25.0)
                        SetSliderDialogRange(0.0, 100.0)
                        SetSliderDialogInterval(5.0)
                    ElseIf option == OID_FM_Loyalty[j]
                        SetSliderDialogStartValue(FollowerManagerScript.GetLoyalty(CachedManagedFollowers[j]))
                        SetSliderDialogDefaultValue(50.0)
                        SetSliderDialogRange(0.0, 100.0)
                        SetSliderDialogInterval(5.0)
                    ElseIf option == OID_FM_Mood[j]
                        SetSliderDialogStartValue(FollowerManagerScript.GetMood(CachedManagedFollowers[j]))
                        SetSliderDialogDefaultValue(50.0)
                        SetSliderDialogRange(-100.0, 100.0)
                        SetSliderDialogInterval(5.0)
                    EndIf
                EndIf
                j += 1
            EndWhile
        EndIf
    endif
EndEvent

Event OnOptionSliderAccept(int option, float value)
    if option == OID_NearestNPCRadius
        NearestNPCRadius = value
        SetSliderOptionValue(OID_NearestNPCRadius, NearestNPCRadius, "{0} units")
        ApplyHotkeySettings()
    elseif option == OID_ArrestCooldown
        ArrestScript.ArrestPlayerCooldown = value
        SetSliderOptionValue(OID_ArrestCooldown, value, "{0} sec")
    elseif option == OID_PersuasionTimeLimit
        ArrestScript.PersuasionTimeLimit = value
        SetSliderOptionValue(OID_PersuasionTimeLimit, value, "{0} sec")

    ; Survival sliders
    elseif option == OID_HungerRate
        If SurvivalScript
            SurvivalScript.HungerRate = value
            SetSliderOptionValue(OID_HungerRate, value, "{1}x")
        EndIf
    elseif option == OID_AutoEatThreshold
        If SurvivalScript
            SurvivalScript.AutoEatThreshold = value as Int
            SetSliderOptionValue(OID_AutoEatThreshold, value, "{0}%")
        EndIf
    elseif option == OID_FatigueRate
        If SurvivalScript
            SurvivalScript.FatigueRate = value
            SetSliderOptionValue(OID_FatigueRate, value, "{1}x")
        EndIf
    elseif option == OID_ColdRate
        If SurvivalScript
            SurvivalScript.ColdRate = value
            SetSliderOptionValue(OID_ColdRate, value, "{1}x")
        EndIf

    ; Follower Manager sliders
    elseif option == OID_FM_MaxFollowers
        If FollowerManagerScript
            FollowerManagerScript.MaxFollowers = value as Int
            SetSliderOptionValue(OID_FM_MaxFollowers, value, "{0}")
        EndIf
    elseif option == OID_FM_RapportDecay
        If FollowerManagerScript
            FollowerManagerScript.RapportDecayRate = value
            SetSliderOptionValue(OID_FM_RapportDecay, value, "{1}x")
        EndIf
    elseif option == OID_FM_LeavingThreshold
        If FollowerManagerScript
            FollowerManagerScript.LeavingThreshold = value
            SetSliderOptionValue(OID_FM_LeavingThreshold, value, "{0}")
        EndIf

    ; Per-follower relationship sliders
    else
        If FollowerManagerScript && CachedManagedFollowers
            Int j = 0
            While j < CachedManagedFollowers.Length && j < 10
                If CachedManagedFollowers[j]
                    If option == OID_FM_Rapport[j]
                        FollowerManagerScript.SetRapport(CachedManagedFollowers[j], value)
                        SetSliderOptionValue(OID_FM_Rapport[j], value, "{0}")
                    ElseIf option == OID_FM_Trust[j]
                        FollowerManagerScript.SetTrust(CachedManagedFollowers[j], value)
                        SetSliderOptionValue(OID_FM_Trust[j], value, "{0}")
                    ElseIf option == OID_FM_Loyalty[j]
                        FollowerManagerScript.SetLoyalty(CachedManagedFollowers[j], value)
                        SetSliderOptionValue(OID_FM_Loyalty[j], value, "{0}")
                    ElseIf option == OID_FM_Mood[j]
                        FollowerManagerScript.SetMood(CachedManagedFollowers[j], value)
                        SetSliderOptionValue(OID_FM_Mood[j], value, "{0}")
                    EndIf
                EndIf
                j += 1
            EndWhile
        EndIf
    endif
EndEvent

; =============================================================================
; OPTION HIGHLIGHTING (Tooltips)
; =============================================================================

Event OnOptionHighlight(int option)
    if option == OID_DialogueAnimEnabled
        SetInfoText("Enable or disable conversation animations on NPCs during SkyrimNet dialogue. When enabled, NPCs will use vanilla Skyrim talking gestures while conversing.")

    elseif option == OID_AllowConjuredGold
        SetInfoText("Allow NPCs to give gold they don't actually have. Useful for rewards and quest payments. Disable for hardcore economy.")
        
    elseif option == OID_ResetTravelSlots
        SetInfoText("Emergency reset: Clears all travel slots and cancels any active NPC travel. Use if travel slots appear stuck or show incorrect status.")
        
    elseif option == OID_TravelSlot0 || option == OID_TravelSlot1 || option == OID_TravelSlot2 || option == OID_TravelSlot3 || option == OID_TravelSlot4
        SetInfoText("Click to clear this travel slot. This will cancel travel for the NPC and restore their follower status if applicable.")
        
    elseif option == OID_FollowToggleKey
        SetInfoText("Hotkey to toggle NPC following. Look at an NPC and press this key to make them follow you or stop following. Also resumes following if they were waiting.")
        
    elseif option == OID_DismissAllKey
        SetInfoText("Hotkey to dismiss ALL followers at once. Useful for quickly clearing all NPCs following you.")
        
    elseif option == OID_StandUpKey
        SetInfoText("Hotkey to make an NPC stand up from furniture. Look at the NPC and press this key to make them get up from chairs, beds, workstations, etc.")
        
    elseif option == OID_YieldKey
        SetInfoText("Hotkey to make an NPC yield/surrender. Stops combat, removes them from hostile factions, and makes them friendly. Works on NPCs currently in combat.")
        
    elseif option == OID_UndressKey
        SetInfoText("Hotkey to remove all armor/clothing from an NPC. Items are stored and can be re-equipped with the Dress hotkey.")
        
    elseif option == OID_DressKey
        SetInfoText("Hotkey to re-equip all stored armor/clothing on an NPC. Only works if the NPC was previously undressed with the Undress hotkey.")
        
    elseif option == OID_TargetMode
        SetInfoText("How to select which NPC the hotkey affects:\n- Crosshair: NPC you're looking at\n- Nearest NPC: Closest NPC to you\n- Last Talked To: Last NPC you had dialogue with")
        
    elseif option == OID_NearestNPCRadius
        SetInfoText("Maximum distance (in game units) to search for the nearest NPC. Only used when Target Mode is set to 'Nearest NPC'. Default: 500 units.")

    elseif option == OID_WheelMenuKey
        SetInfoText("Hotkey to open the wheel menu with all actions. Requires UIExtensions mod. The wheel always targets the NPC under your crosshair. Great for VR users or those who prefer a single hotkey.")

    ; Crime page tooltips
    elseif option == OID_BountyWhiterun || option == OID_BountyRift || option == OID_BountyHaafingar || option == OID_BountyEastmarch || option == OID_BountyReach || option == OID_BountyFalkreath || option == OID_BountyPale || option == OID_BountyHjaalmarch || option == OID_BountyWinterhold
        SetInfoText("Your tracked bounty in this hold. Click to clear. These bounties are managed by SeverActions and won't trigger vanilla guard arrest dialogue.")

    elseif option == OID_ClearAllBounties
        SetInfoText("Clear all tracked bounties in all holds at once. Use this to start fresh or if bounties are causing issues.")

    elseif option == OID_ArrestCooldown
        SetInfoText("Cooldown in seconds before guards can use the ArrestPlayer action again. Prevents guards from spamming arrest during persuasion. Set to 0 to disable. Default: 60 seconds.")

    elseif option == OID_PersuasionTimeLimit
        SetInfoText("Time in seconds the player has to convince the guard during the persuasion phase. After this time expires, the guard will demand a decision. Default: 90 seconds.")

    ; Survival page tooltips
    elseif option == OID_SurvivalEnabled
        SetInfoText("Enable or disable the follower survival tracking system. When disabled, followers won't accumulate hunger, fatigue, or cold.")

    elseif option == OID_HungerEnabled
        SetInfoText("Track hunger for followers. Hunger increases over time and causes stamina/magicka penalties. Followers auto-eat from their inventory when hungry.")

    elseif option == OID_HungerRate
        SetInfoText("How fast hunger increases. 1.0x is normal speed. Higher values make followers get hungry faster. Default: 1.0x")

    elseif option == OID_AutoEatThreshold
        SetInfoText("Hunger level (0-100) at which followers automatically eat food from their inventory. Set to 0 to disable auto-eat. Default: 50%")

    elseif option == OID_FatigueEnabled
        SetInfoText("Track fatigue for followers. Fatigue increases over time and causes health/stamina penalties. Resets when the player sleeps.")

    elseif option == OID_FatigueRate
        SetInfoText("How fast fatigue increases. 1.0x is normal speed. Higher values make followers tire faster. Default: 1.0x")

    elseif option == OID_ColdEnabled
        SetInfoText("Track cold for followers based on weather and location. Cold weather and snowy areas increase cold faster. Causes stamina/movement penalties.")

    elseif option == OID_ColdRate
        SetInfoText("How fast cold increases in harsh conditions. 1.0x is normal speed. Higher values make followers get cold faster. Default: 1.0x")

    elseif option == OID_SurvivalNotifications
        SetInfoText("Show notifications when followers reach critical survival levels (very hungry, exhausted, freezing).")

    elseif option == OID_SurvivalDebug
        SetInfoText("Enable debug messages for survival system. Shows detailed tracking info in the console. Useful for troubleshooting.")

    ; Follower Manager tooltips
    elseif option == OID_FM_MaxFollowers
        SetInfoText("Maximum number of companions allowed at once. Default: 5")
    elseif option == OID_FM_RapportDecay
        SetInfoText("How fast rapport decays when you don't talk to a companion. 1.0x is normal. Set to 0 to disable rapport decay. Default: 1.0x")
    elseif option == OID_FM_AllowLeaving
        SetInfoText("When enabled, companions with very low rapport may decide to leave on their own. Disable for companions that never leave regardless of treatment.")
    elseif option == OID_FM_LeavingThreshold
        SetInfoText("Rapport level at which companions may decide to leave. Lower values (closer to -100) mean they tolerate more mistreatment. Default: -60")
    elseif option == OID_FM_Notifications
        SetInfoText("Show notifications when companions are recruited, dismissed, or when relationship milestones occur.")
    elseif option == OID_FM_Debug
        SetInfoText("Enable debug messages for companion framework. Shows relationship value changes in the console.")
    elseif option == OID_FM_ResetAll
        SetInfoText("Emergency reset: dismisses all companions and clears all relationship data. Use if the system is stuck or broken.")

    ; Per-follower tooltips (survival exclusions + relationship sliders)
    else
        If OID_FollowerExclude && CachedFollowers
            Int j = 0
            While j < CachedFollowers.Length && j < 10
                If option == OID_FollowerExclude[j] && CachedFollowers[j]
                    Bool isExcluded = SurvivalScript.IsFollowerExcluded(CachedFollowers[j])
                    If isExcluded
                        SetInfoText(CachedFollowers[j].GetDisplayName() + " is excluded from survival tracking. Toggle ON to track hunger, fatigue, and cold for this follower.")
                    Else
                        SetInfoText(CachedFollowers[j].GetDisplayName() + " is being tracked. Toggle OFF to exclude this follower from survival (useful for undead, automaton, or daedric followers).")
                    EndIf
                EndIf
                j += 1
            EndWhile
        EndIf

        ; Per-follower relationship slider tooltips
        If FollowerManagerScript && CachedManagedFollowers
            Int k = 0
            While k < CachedManagedFollowers.Length && k < 10
                If CachedManagedFollowers[k]
                    If option == OID_FM_Rapport[k]
                        SetInfoText("How much " + CachedManagedFollowers[k].GetDisplayName() + " likes the player. Range: -100 (hostile) to 100 (devoted). Affects willingness to help and dialogue tone. Useful for mid-playthrough adjustment.")
                    ElseIf option == OID_FM_Trust[k]
                        SetInfoText("How much " + CachedManagedFollowers[k].GetDisplayName() + " trusts the player's judgment. Range: 0 to 100. Affects willingness to follow dangerous orders. Low trust = more refusals.")
                    ElseIf option == OID_FM_Loyalty[k]
                        SetInfoText("How committed " + CachedManagedFollowers[k].GetDisplayName() + " is to staying. Range: 0 to 100. Very low loyalty combined with low rapport may cause them to leave.")
                    ElseIf option == OID_FM_Mood[k]
                        SetInfoText(CachedManagedFollowers[k].GetDisplayName() + "'s current temperament. Range: -100 (miserable) to 100 (ecstatic). Mood drifts toward baseline over time and is affected by events.")
                    ElseIf option == OID_FM_CombatStyle[k]
                        SetInfoText("How " + CachedManagedFollowers[k].GetDisplayName() + " approaches combat. Aggressive = charges in, Defensive = protects, Ranged = keeps distance, Healer = supports allies, Balanced = adapts.")
                    EndIf
                EndIf
                k += 1
            EndWhile
        EndIf
    endif
EndEvent

; =============================================================================
; DEFAULT VALUES
; =============================================================================

Event OnOptionDefault(int option)
    if option == OID_DialogueAnimEnabled
        DialogueAnimEnabled = true
        SetToggleOptionValue(OID_DialogueAnimEnabled, true)
        SeverActionsNative.SetDialogueAnimEnabled(true)

    elseif option == OID_AllowConjuredGold
        AllowConjuredGold = true
        SetToggleOptionValue(OID_AllowConjuredGold, AllowConjuredGold)
        ApplyCurrencySettings()
        
    elseif option == OID_FollowToggleKey
        FollowToggleKey = -1
        SetKeyMapOptionValue(OID_FollowToggleKey, FollowToggleKey)
        ApplyHotkeySettings()
        
    elseif option == OID_DismissAllKey
        DismissAllKey = -1
        SetKeyMapOptionValue(OID_DismissAllKey, DismissAllKey)
        ApplyHotkeySettings()
        
    elseif option == OID_StandUpKey
        StandUpKey = -1
        SetKeyMapOptionValue(OID_StandUpKey, StandUpKey)
        ApplyHotkeySettings()
        
    elseif option == OID_YieldKey
        YieldKey = -1
        SetKeyMapOptionValue(OID_YieldKey, YieldKey)
        ApplyHotkeySettings()
        
    elseif option == OID_UndressKey
        UndressKey = -1
        SetKeyMapOptionValue(OID_UndressKey, UndressKey)
        ApplyHotkeySettings()
        
    elseif option == OID_DressKey
        DressKey = -1
        SetKeyMapOptionValue(OID_DressKey, DressKey)
        ApplyHotkeySettings()
        
    elseif option == OID_TargetMode
        TargetMode = 0
        SetMenuOptionValue(OID_TargetMode, TargetModeOptions[0])
        ApplyHotkeySettings()
        ForcePageReset()
        
    elseif option == OID_NearestNPCRadius
        NearestNPCRadius = 500.0
        SetSliderOptionValue(OID_NearestNPCRadius, 500.0, "{0} units")
        ApplyHotkeySettings()

    elseif option == OID_WheelMenuKey
        WheelMenuKey = -1
        SetKeyMapOptionValue(OID_WheelMenuKey, WheelMenuKey)
        ApplyWheelMenuSettings()

    elseif option == OID_ArrestCooldown
        If ArrestScript
            ArrestScript.ArrestPlayerCooldown = 60.0
            SetSliderOptionValue(OID_ArrestCooldown, 60.0, "{0} sec")
        EndIf

    elseif option == OID_PersuasionTimeLimit
        If ArrestScript
            ArrestScript.PersuasionTimeLimit = 90.0
            SetSliderOptionValue(OID_PersuasionTimeLimit, 90.0, "{0} sec")
        EndIf

    ; Survival defaults
    elseif option == OID_SurvivalEnabled
        If SurvivalScript
            SurvivalScript.Enabled = false
            SetToggleOptionValue(OID_SurvivalEnabled, false)
            SurvivalScript.StopTracking()
        EndIf
    elseif option == OID_HungerEnabled
        If SurvivalScript
            SurvivalScript.HungerEnabled = true
            SetToggleOptionValue(OID_HungerEnabled, true)
        EndIf
    elseif option == OID_HungerRate
        If SurvivalScript
            SurvivalScript.HungerRate = 1.0
            SetSliderOptionValue(OID_HungerRate, 1.0, "{1}x")
        EndIf
    elseif option == OID_AutoEatThreshold
        If SurvivalScript
            SurvivalScript.AutoEatThreshold = 50
            SetSliderOptionValue(OID_AutoEatThreshold, 50.0, "{0}%")
        EndIf
    elseif option == OID_FatigueEnabled
        If SurvivalScript
            SurvivalScript.FatigueEnabled = true
            SetToggleOptionValue(OID_FatigueEnabled, true)
        EndIf
    elseif option == OID_FatigueRate
        If SurvivalScript
            SurvivalScript.FatigueRate = 1.0
            SetSliderOptionValue(OID_FatigueRate, 1.0, "{1}x")
        EndIf
    elseif option == OID_ColdEnabled
        If SurvivalScript
            SurvivalScript.ColdEnabled = true
            SetToggleOptionValue(OID_ColdEnabled, true)
        EndIf
    elseif option == OID_ColdRate
        If SurvivalScript
            SurvivalScript.ColdRate = 1.0
            SetSliderOptionValue(OID_ColdRate, 1.0, "{1}x")
        EndIf
    elseif option == OID_SurvivalNotifications
        If SurvivalScript
            SurvivalScript.ShowNotifications = true
            SetToggleOptionValue(OID_SurvivalNotifications, true)
        EndIf
    elseif option == OID_SurvivalDebug
        If SurvivalScript
            SurvivalScript.DebugMode = false
            SetToggleOptionValue(OID_SurvivalDebug, false)
        EndIf

    ; Follower Manager defaults
    elseif option == OID_FM_MaxFollowers
        If FollowerManagerScript
            FollowerManagerScript.MaxFollowers = 5
            SetSliderOptionValue(OID_FM_MaxFollowers, 5.0, "{0}")
        EndIf
    elseif option == OID_FM_RapportDecay
        If FollowerManagerScript
            FollowerManagerScript.RapportDecayRate = 1.0
            SetSliderOptionValue(OID_FM_RapportDecay, 1.0, "{1}x")
        EndIf
    elseif option == OID_FM_AllowLeaving
        If FollowerManagerScript
            FollowerManagerScript.AllowAutonomousLeaving = true
            SetToggleOptionValue(OID_FM_AllowLeaving, true)
        EndIf
    elseif option == OID_FM_LeavingThreshold
        If FollowerManagerScript
            FollowerManagerScript.LeavingThreshold = -60.0
            SetSliderOptionValue(OID_FM_LeavingThreshold, -60.0, "{0}")
        EndIf
    elseif option == OID_FM_Notifications
        If FollowerManagerScript
            FollowerManagerScript.ShowNotifications = true
            SetToggleOptionValue(OID_FM_Notifications, true)
        EndIf
    elseif option == OID_FM_Debug
        If FollowerManagerScript
            FollowerManagerScript.DebugMode = false
            SetToggleOptionValue(OID_FM_Debug, false)
        EndIf

    ; Per-follower relationship defaults
    else
        If FollowerManagerScript && CachedManagedFollowers
            Int j = 0
            While j < CachedManagedFollowers.Length && j < 10
                If CachedManagedFollowers[j]
                    If option == OID_FM_Rapport[j]
                        FollowerManagerScript.SetRapport(CachedManagedFollowers[j], 0.0)
                        SetSliderOptionValue(OID_FM_Rapport[j], 0.0, "{0}")
                    ElseIf option == OID_FM_Trust[j]
                        FollowerManagerScript.SetTrust(CachedManagedFollowers[j], 25.0)
                        SetSliderOptionValue(OID_FM_Trust[j], 25.0, "{0}")
                    ElseIf option == OID_FM_Loyalty[j]
                        FollowerManagerScript.SetLoyalty(CachedManagedFollowers[j], 50.0)
                        SetSliderOptionValue(OID_FM_Loyalty[j], 50.0, "{0}")
                    ElseIf option == OID_FM_Mood[j]
                        FollowerManagerScript.SetMood(CachedManagedFollowers[j], 50.0)
                        SetSliderOptionValue(OID_FM_Mood[j], 50.0, "{0}")
                    ElseIf option == OID_FM_CombatStyle[j]
                        FollowerManagerScript.SetCombatStyle(CachedManagedFollowers[j], "balanced")
                        SetMenuOptionValue(OID_FM_CombatStyle[j], "balanced")
                    EndIf
                EndIf
                j += 1
            EndWhile
        EndIf
    endif
EndEvent

; =============================================================================
; APPLY SETTINGS TO SCRIPTS
; =============================================================================

Function ApplyCurrencySettings()
    if CurrencyScript
        CurrencyScript.AllowConjuredGold = AllowConjuredGold
        Debug.Trace("[SeverActions_MCM] Applied currency settings - Conjured Gold: " + AllowConjuredGold)
    else
        Debug.Trace("[SeverActions_MCM] WARNING: CurrencyScript not set!")
    endif
EndFunction

Function ApplyHotkeySettings()
    if HotkeyScript
        ; Update individual keys (handles re-registration)
        HotkeyScript.UpdateFollowToggleKey(FollowToggleKey)
        HotkeyScript.UpdateDismissAllKey(DismissAllKey)
        HotkeyScript.UpdateStandUpKey(StandUpKey)
        HotkeyScript.UpdateYieldKey(YieldKey)
        HotkeyScript.UpdateUndressKey(UndressKey)
        HotkeyScript.UpdateDressKey(DressKey)
        
        ; Update other settings directly
        HotkeyScript.TargetMode = TargetMode
        HotkeyScript.NearestNPCRadius = NearestNPCRadius
        
        Debug.Trace("[SeverActions_MCM] Applied hotkey settings")
        Debug.Trace("[SeverActions_MCM]   FollowToggleKey: " + FollowToggleKey)
        Debug.Trace("[SeverActions_MCM]   DismissAllKey: " + DismissAllKey)
        Debug.Trace("[SeverActions_MCM]   StandUpKey: " + StandUpKey)
        Debug.Trace("[SeverActions_MCM]   YieldKey: " + YieldKey)
        Debug.Trace("[SeverActions_MCM]   UndressKey: " + UndressKey)
        Debug.Trace("[SeverActions_MCM]   DressKey: " + DressKey)
        Debug.Trace("[SeverActions_MCM]   TargetMode: " + TargetMode)
        Debug.Trace("[SeverActions_MCM]   NearestNPCRadius: " + NearestNPCRadius)
    else
        Debug.Trace("[SeverActions_MCM] WARNING: HotkeyScript not set!")
    endif
EndFunction

Function ApplyWheelMenuSettings()
    if WheelMenuScript
        WheelMenuScript.UpdateWheelMenuKey(WheelMenuKey)
        Debug.Trace("[SeverActions_MCM] Applied wheel menu settings")
        Debug.Trace("[SeverActions_MCM]   WheelMenuKey: " + WheelMenuKey)
    else
        Debug.Trace("[SeverActions_MCM] WARNING: WheelMenuScript not set!")
    endif
EndFunction

; Called on game load to sync settings
Function SyncAllSettings()
    ; Force MCM to rebuild pages (fixes version/page issues)
    OnConfigInit()

    ApplyCurrencySettings()
    ApplyHotkeySettings()
    ApplyWheelMenuSettings()

    ; Sync native DLL settings
    SeverActionsNative.SetDialogueAnimEnabled(DialogueAnimEnabled)
    Debug.Trace("[SeverActions_MCM] Dialogue Animations: " + DialogueAnimEnabled)

    Debug.Trace("[SeverActions_MCM] All settings synced and menu rebuilt")
EndFunction

; =============================================================================
; HELPERS
; =============================================================================

Int Function CombatStyleIndexFromString(String style)
    {Convert combat style string to dropdown index}
    If style == "balanced"
        Return 0
    ElseIf style == "aggressive"
        Return 1
    ElseIf style == "defensive"
        Return 2
    ElseIf style == "ranged"
        Return 3
    ElseIf style == "healer"
        Return 4
    EndIf
    Return 0
EndFunction