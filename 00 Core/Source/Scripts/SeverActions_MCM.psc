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
SeverActions_Loot Property LootScript Auto
SeverActions_SpellTeach Property SpellTeachScript Auto

; =============================================================================
; SETTINGS - These mirror the properties in other scripts
; =============================================================================

; Currency Settings
bool Property AllowConjuredGold = true Auto

; Dialogue Animation Settings (stored here, applied to native DLL)
bool Property DialogueAnimEnabled = true Auto Hidden
int Property SilenceChance = 50 Auto Hidden

; Speaker Tag Toggles (stored here, synced to StorageUtil for prompt access)
bool Property TagCompanionEnabled = true Auto Hidden
bool Property TagEngagedEnabled = true Auto Hidden
bool Property TagInSceneEnabled = true Auto Hidden

; Hotkey Settings (stored here, applied to HotkeyScript)
int Property FollowToggleKey = -1 Auto Hidden
int Property DismissKey = -1 Auto Hidden
int Property StandUpKey = -1 Auto Hidden
int Property YieldKey = -1 Auto Hidden
int Property UndressKey = -1 Auto Hidden
int Property DressKey = -1 Auto Hidden
int Property SetCompanionKey = -1 Auto Hidden
int Property CompanionWaitKey = -1 Auto Hidden
int Property AssignHomeKey = -1 Auto Hidden
int Property TargetMode = 0 Auto Hidden
float Property NearestNPCRadius = 500.0 Auto Hidden

; Wheel Menu Settings (stored here, applied to WheelMenuScript)
int Property WheelMenuKey = -1 Auto Hidden

; Config Menu Key (opens PrismaUI config — stored here, applied to HotkeyScript)
int Property ConfigMenuKey = -1 Auto Hidden

; =============================================================================
; MCM STATE - Option IDs
; =============================================================================

; General page
int OID_Version

; Currency page
int OID_AllowConjuredGold
int OID_DebtActiveCount
int OID_DebtPlayerOwes
int OID_DebtOwedToPlayer

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
int OID_DismissKey
int OID_StandUpKey
int OID_YieldKey
int OID_UndressKey
int OID_DressKey
int OID_SetCompanionKey
int OID_CompanionWaitKey
int OID_AssignHomeKey
int OID_TargetMode
int OID_NearestNPCRadius
int OID_WheelMenuKey
int OID_ConfigMenuKey

; Bounty page
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
int OID_NPCArrestCooldown
int OID_PersuasionTimeLimit

; General page - Native DLL toggles
int OID_DialogueAnimEnabled
int OID_SilenceChance
int OID_BookReadMode

; General page - Speaker Tags
int OID_TagCompanion
int OID_TagEngaged
int OID_TagInScene

; General page - Spell Teaching
int OID_SpellFailEnabled
int OID_SpellFailDifficulty

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
int OID_FM_RelCooldown
int OID_FM_OutfitLock
int OID_FM_AutoSwitch
int OID_FM_StabilityDelay
int OID_FM_PerActorAutoSwitch
int OID_FM_FrameworkMode
int OID_FM_AutoAssessment
int OID_FM_AssessCooldownMin
int OID_FM_AssessCooldownMax
int OID_FM_AutoInterAssessment
int OID_FM_InterAssessCooldownMin
int OID_FM_InterAssessCooldownMax
int OID_FM_ResetAll
int OID_FM_DeathGracePeriod
int OID_FM_AutoOffScreenLife
int OID_FM_OffScreenCooldownMin
int OID_FM_OffScreenCooldownMax
int OID_FM_OffScreenConsequences
int OID_FM_ConsequenceCooldown
int OID_FM_MaxBounty
int OID_FM_MaxGoldChange
int[] OID_FM_DismissFollower
int OID_FM_ForceRemove
int[] OID_FM_ClearHome
int[] OID_FM_AssignHome
int[] OID_FM_Rapport
int[] OID_FM_Trust
int[] OID_FM_Loyalty
int[] OID_FM_Mood
int[] OID_FM_CombatStyle
int[] OID_FM_DeletePreset
String[] CachedPresetNames
Actor[] CachedManagedFollowers

; NPC Homes section (General page)
int[] OID_ClearNPCHome
Actor[] CachedHomedNPCs

; Dismissed NPCs section (Followers page)
int OID_FM_DismissedSelect
int[] OID_FM_DismissedClearHome
int[] OID_FM_DismissedReRecruit
Actor[] CachedDismissedFollowers
int SelectedDismissedIdx = 0

; Combat style dropdown options
string[] CombatStyleOptions

; Framework mode dropdown options
string[] FrameworkModeOptions

; Book reading mode dropdown options
string[] BookReadModeOptions

; Companion selector
int OID_FM_CompanionSelect
int SelectedCompanionIdx = 0

; Page names
string PAGE_GENERAL = "General"
string PAGE_HOTKEYS = "Hotkeys"
string PAGE_CURRENCY = "Currency"
string PAGE_TRAVEL = "Travel"
string PAGE_BOUNTY = "Bounty"
string PAGE_SURVIVAL = "Survival"
string PAGE_FOLLOWERS = "Followers"
string PAGE_OUTFITS = "Outfits"

; Outfits page OIDs
int OID_Outfit_NPCSelect
int OID_Outfit_Lock
int[] OID_Outfit_DeletePreset
String[] CachedOutfitPresetNames
Actor[] CachedPresetActors
int SelectedOutfitNPCIdx = 0

; Target mode options
string[] TargetModeOptions

; =============================================================================
; INITIALIZATION
; =============================================================================

Int Function GetVersion()
    {Override SKI_ConfigBase. SkyUI compares this against the saved version
     to trigger OnVersionUpdate. Increment when MCM structure changes.}
    Return 121
EndFunction

Event OnConfigInit()
    ModName = "SeverActions"

    ; Set current version - increment this when you make MCM changes
    ; Format: major * 100 + minor (e.g., 107 = version 1.07)
    CurrentVersion = 122

    Pages = new string[8]
    Pages[0] = PAGE_GENERAL
    Pages[1] = PAGE_HOTKEYS
    Pages[2] = PAGE_CURRENCY
    Pages[3] = PAGE_TRAVEL
    Pages[4] = PAGE_BOUNTY
    Pages[5] = PAGE_SURVIVAL
    Pages[6] = PAGE_FOLLOWERS
    Pages[7] = PAGE_OUTFITS

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

    ; Initialize framework mode dropdown options
    FrameworkModeOptions = new string[3]
    FrameworkModeOptions[0] = "Auto"
    FrameworkModeOptions[1] = "SeverActions Only"
    FrameworkModeOptions[2] = "Tracking Only"

    ; Initialize book reading mode dropdown options
    BookReadModeOptions = new string[2]
    BookReadModeOptions[0] = "Read Aloud (Verbatim)"
    BookReadModeOptions[1] = "Summarize & React"
EndEvent

Event OnVersionUpdate(int newVersion)
    ; Called when CurrentVersion is higher than saved version
    Debug.Trace("[SeverActions_MCM] Updating from version " + CurrentVersion + " to " + newVersion)

    ; Force page rebuild on any version change
    Pages = new string[8]
    Pages[0] = PAGE_GENERAL
    Pages[1] = PAGE_HOTKEYS
    Pages[2] = PAGE_CURRENCY
    Pages[3] = PAGE_TRAVEL
    Pages[4] = PAGE_BOUNTY
    Pages[5] = PAGE_SURVIVAL
    Pages[6] = PAGE_FOLLOWERS
    Pages[7] = PAGE_OUTFITS

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

    ; Re-initialize framework mode dropdown options
    FrameworkModeOptions = new string[3]
    FrameworkModeOptions[0] = "Auto"
    FrameworkModeOptions[1] = "SeverActions Only"
    FrameworkModeOptions[2] = "Tracking Only"

    ; Re-initialize book reading mode dropdown options
    BookReadModeOptions = new string[2]
    BookReadModeOptions[0] = "Read Aloud (Verbatim)"
    BookReadModeOptions[1] = "Summarize & React"
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
    elseif page == PAGE_BOUNTY
        DrawCrimePage()
    elseif page == PAGE_SURVIVAL
        DrawSurvivalPage()
    elseif page == PAGE_FOLLOWERS
        DrawFollowersPage()
    elseif page == PAGE_OUTFITS
        DrawOutfitsPage()
    endif
EndEvent

; =============================================================================
; OUTFITS PAGE
; =============================================================================

Function DrawOutfitsPage()
    If !OutfitScript
        AddTextOption("", "Outfit system not connected!")
        return
    EndIf

    ; Get all actors with saved presets
    Actor[] allPresetActors = OutfitScript.GetPresetActors()

    ; Filter out registered followers (they're managed on the Followers page)
    CachedPresetActors = PapyrusUtil.ActorArray(0)
    Int f = 0
    While f < allPresetActors.Length
        If allPresetActors[f] && FollowerManagerScript
            If !FollowerManagerScript.IsRegisteredFollower(allPresetActors[f])
                CachedPresetActors = PapyrusUtil.PushActor(CachedPresetActors, allPresetActors[f])
            EndIf
        ElseIf allPresetActors[f]
            CachedPresetActors = PapyrusUtil.PushActor(CachedPresetActors, allPresetActors[f])
        EndIf
        f += 1
    EndWhile

    If CachedPresetActors.Length == 0
        AddTextOption("", "No outfit presets saved for non-followers.")
        AddTextOption("", "Dress an NPC and save a preset to see them here.")
        return
    EndIf

    ; Clamp selection index
    If SelectedOutfitNPCIdx >= CachedPresetActors.Length
        SelectedOutfitNPCIdx = 0
    EndIf

    AddHeaderOption("NPC Outfits")
    AddTextOption("NPCs with presets", CachedPresetActors.Length + " tracked", OPTION_FLAG_DISABLED)
    OID_Outfit_NPCSelect = AddMenuOption("Select NPC", CachedPresetActors[SelectedOutfitNPCIdx].GetDisplayName())

    AddEmptyOption()

    ; Show selected NPC's details
    Actor selected = CachedPresetActors[SelectedOutfitNPCIdx]
    If selected
        AddHeaderOption(selected.GetDisplayName())

        ; Outfit lock toggle
        Bool hasLock = OutfitScript.HasNonFollowerOutfitLock(selected)
        OID_Outfit_Lock = AddToggleOption("Outfit Lock", hasLock)

        ; List presets
        CachedOutfitPresetNames = OutfitScript.GetPresetNames(selected)
        If CachedOutfitPresetNames.Length > 0
            AddHeaderOption("Saved Presets")
            OID_Outfit_DeletePreset = new int[20]
            Int p = 0
            While p < CachedOutfitPresetNames.Length && p < 20
                Int presetItems = OutfitScript.GetPresetItemCount(selected, CachedOutfitPresetNames[p])
                AddTextOption(CachedOutfitPresetNames[p], presetItems + " items", OPTION_FLAG_DISABLED)
                OID_Outfit_DeletePreset[p] = AddTextOption("Delete '" + CachedOutfitPresetNames[p] + "'", "CLICK")
                p += 1
            EndWhile
        Else
            CachedOutfitPresetNames = PapyrusUtil.StringArray(0)
            OID_Outfit_DeletePreset = new int[1]
        EndIf
    EndIf
EndFunction

Function DrawGeneralPage()
    SetCursorFillMode(TOP_TO_BOTTOM)

    AddHeaderOption("SeverActions Configuration")
    AddEmptyOption()
    OID_Version = AddTextOption("Version", "1.1")
    AddTextOption("Author", "Severause")
    AddEmptyOption()
    AddTextOption("", "Configure SeverActions modules")
    AddTextOption("", "using the pages on the left.")
    AddEmptyOption()
    AddHeaderOption("Native Features")
    OID_DialogueAnimEnabled = AddToggleOption("Dialogue Animations", DialogueAnimEnabled)
    OID_SilenceChance = AddSliderOption("Silence Chance", SilenceChance as Float, "{0}%")
    if !LootScript
        Quest myQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
        if myQuest
            LootScript = myQuest as SeverActions_Loot
        endif
    endif
    if LootScript
        if !BookReadModeOptions
            BookReadModeOptions = new string[2]
            BookReadModeOptions[0] = "Read Aloud (Verbatim)"
            BookReadModeOptions[1] = "Summarize & React"
        endif
        OID_BookReadMode = AddMenuOption("Book Reading Style", BookReadModeOptions[LootScript.BookReadMode])
    endif

    AddEmptyOption()
    AddHeaderOption("Speaker Tags")
    OID_TagCompanion = AddToggleOption("[COMPANION] Tag", TagCompanionEnabled)
    OID_TagEngaged = AddToggleOption("[ENGAGED] Tag", TagEngagedEnabled)
    OID_TagInScene = AddToggleOption("[IN SCENE] Tag", TagInSceneEnabled)

    AddEmptyOption()
    AddHeaderOption("Spell Teaching")
    if !SpellTeachScript
        Quest myQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
        if myQuest
            SpellTeachScript = myQuest as SeverActions_SpellTeach
        endif
    endif
    if SpellTeachScript
        OID_SpellFailEnabled = AddToggleOption("Failure System", SpellTeachScript.EnableFailureSystem)
        OID_SpellFailDifficulty = AddSliderOption("Failure Difficulty", SpellTeachScript.FailureDifficultyMult, "{1}x")
    endif

    ; --- NPC Homes ---
    AddEmptyOption()
    AddHeaderOption("NPC Homes")
    If FollowerManagerScript
        CachedHomedNPCs = FollowerManagerScript.GetAllHomedNPCs()
        OID_ClearNPCHome = new int[20]
        If CachedHomedNPCs.Length > 0
            Int h = 0
            While h < CachedHomedNPCs.Length && h < 20
                String homeLoc = FollowerManagerScript.GetAssignedHome(CachedHomedNPCs[h])
                AddTextOption(CachedHomedNPCs[h].GetDisplayName(), homeLoc, OPTION_FLAG_DISABLED)
                OID_ClearNPCHome[h] = AddTextOption("Clear Home", "CLICK")
                h += 1
            EndWhile
        Else
            AddTextOption("No custom homes assigned", "", OPTION_FLAG_DISABLED)
        EndIf
    EndIf

    AddEmptyOption()
    AddHeaderOption("Quick Reference")
    AddTextOption("", "Hotkeys - Keyboard shortcuts")
    AddTextOption("", "Currency - Gold/payment settings")
    AddTextOption("", "Travel - NPC travel system")
    AddTextOption("", "Bounty - View/manage bounties")
    AddTextOption("", "Survival - Follower survival needs")
    AddTextOption("", "Followers - Companion framework")
EndFunction

Function DrawHotkeysPage()
    SetCursorFillMode(TOP_TO_BOTTOM)

    ; --- Config Menu (PrismaUI) ---
    AddHeaderOption("Config Menu (Requires PrismaUI)")
    OID_ConfigMenuKey = AddKeyMapOption("Open Config Menu", ConfigMenuKey)
    AddTextOption("", "Opens the PrismaUI settings overlay")

    AddEmptyOption()

    ; --- Wheel Menu (at the top since it's a combined interface) ---
    AddHeaderOption("Wheel Menu (Requires UIExtensions)")
    OID_WheelMenuKey = AddKeyMapOption("Open Wheel Menu", WheelMenuKey)
    AddTextOption("", "All actions in one menu - crosshair target")

    AddEmptyOption()
    AddHeaderOption("Follow System Hotkeys")
    OID_FollowToggleKey = AddKeyMapOption("Toggle Follow", FollowToggleKey)
    OID_DismissKey = AddKeyMapOption("Dismiss Companion", DismissKey)
    OID_SetCompanionKey = AddKeyMapOption("Set Companion", SetCompanionKey)
    OID_CompanionWaitKey = AddKeyMapOption("Wait Here / Resume", CompanionWaitKey)
    OID_AssignHomeKey = AddKeyMapOption("Assign Home Here", AssignHomeKey)

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

    AddEmptyOption()
    AddHeaderOption("Debt Tracking")
    If FollowerManagerScript && FollowerManagerScript.DebtScript
        SeverActions_Debt debtSys = FollowerManagerScript.DebtScript
        Int totalPlayerOwes = debtSys.GetTotalOwedBy(Game.GetPlayer())
        Int totalOwedToPlayer = debtSys.GetTotalOwedTo(Game.GetPlayer())
        Int activeDebts = debtSys.GetDebtCount()
        OID_DebtActiveCount = AddTextOption("Active Debts", activeDebts)

        ; --- You Owe ---
        OID_DebtPlayerOwes = AddTextOption("You Owe", totalPlayerOwes + " gold")
        If totalPlayerOwes > 0
            String[] owesDetails = debtSys.GetPlayerOwesDetails()
            Int i = 0
            While i < owesDetails.Length
                AddTextOption("  " + owesDetails[i], "")
                i += 1
            EndWhile
        EndIf

        ; --- Owed to You ---
        OID_DebtOwedToPlayer = AddTextOption("Owed to You", totalOwedToPlayer + " gold")
        If totalOwedToPlayer > 0
            String[] owedDetails = debtSys.GetOwedToPlayerDetails()
            Int i = 0
            While i < owedDetails.Length
                AddTextOption("  " + owedDetails[i], "")
                i += 1
            EndWhile
        EndIf
    Else
        AddTextOption("", "Debt system not connected")
    EndIf
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
        OID_NPCArrestCooldown = AddSliderOption("NPC Arrest Cooldown", ArrestScript.NPCArrestCooldown, "{0} sec")
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
        OID_FollowerExclude = new int[20]

        If CachedFollowers.Length == 0
            AddTextOption("", "No followers detected", OPTION_FLAG_DISABLED)
        Else
            Int j = 0
            While j < CachedFollowers.Length && j < 20
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
        OID_FM_RelCooldown = AddSliderOption("Relationship Cooldown", FollowerManagerScript.RelationshipCooldown, "{0} sec")
        If OutfitScript
            OID_FM_OutfitLock = AddToggleOption("Outfit Lock System", OutfitScript.OutfitLockEnabled)
            OID_FM_AutoSwitch = AddToggleOption("Outfit Auto-Switching", SeverActionsNative.SituationMonitor_IsEnabled())
            OID_FM_StabilityDelay = AddSliderOption("Situation Stability", (SeverActionsNative.SituationMonitor_GetStabilityThreshold() as Float) / 1000.0, "{0} sec")
        EndIf
        OID_FM_FrameworkMode = AddMenuOption("Recruitment Mode", FrameworkModeOptions[FollowerManagerScript.FrameworkMode])
        OID_FM_Notifications = AddToggleOption("Show Notifications", FollowerManagerScript.ShowNotifications)
        OID_FM_Debug = AddToggleOption("Debug Mode", FollowerManagerScript.DebugMode)
        OID_FM_AutoAssessment = AddToggleOption("Auto Relationship Assessment", FollowerManagerScript.AutoRelAssessment)
        OID_FM_AssessCooldownMin = AddSliderOption("Assessment Min Cooldown", FollowerManagerScript.AssessmentCooldownMinHours, "{1} hrs")
        OID_FM_AssessCooldownMax = AddSliderOption("Assessment Max Cooldown", FollowerManagerScript.AssessmentCooldownMaxHours, "{1} hrs")
        OID_FM_AutoInterAssessment = AddToggleOption("Inter-Follower Assessment", FollowerManagerScript.AutoInterFollowerAssessment)
        OID_FM_InterAssessCooldownMin = AddSliderOption("Inter-Follower Min Cooldown", FollowerManagerScript.InterFollowerCooldownMinHours, "{1} hrs")
        OID_FM_InterAssessCooldownMax = AddSliderOption("Inter-Follower Max Cooldown", FollowerManagerScript.InterFollowerCooldownMaxHours, "{1} hrs")
        OID_FM_AutoOffScreenLife = AddToggleOption("Off-Screen Life Events", FollowerManagerScript.AutoOffScreenLife)
        OID_FM_OffScreenCooldownMin = AddSliderOption("Off-Screen Min Cooldown", FollowerManagerScript.OffScreenLifeCooldownMinHours, "{1} hrs")
        OID_FM_OffScreenCooldownMax = AddSliderOption("Off-Screen Max Cooldown", FollowerManagerScript.OffScreenLifeCooldownMaxHours, "{1} hrs")
        OID_FM_OffScreenConsequences = AddToggleOption("Off-Screen Consequences", FollowerManagerScript.OffScreenConsequences)
        OID_FM_ConsequenceCooldown = AddSliderOption("Consequence Cooldown", FollowerManagerScript.ConsequenceCooldownHours, "{1} hrs")
        OID_FM_MaxBounty = AddSliderOption("Max Off-Screen Bounty", FollowerManagerScript.MaxOffScreenBounty as Float, "{0}")
        OID_FM_MaxGoldChange = AddSliderOption("Max Gold Change", FollowerManagerScript.MaxOffScreenGoldChange as Float, "{0}")
        OID_FM_DeathGracePeriod = AddSliderOption("Death Cleanup Delay", FollowerManagerScript.DeathGracePeriodHours, "{0} hrs")

        AddEmptyOption()

        ; Current companions - dropdown selector
        AddHeaderOption("Current Companions")
        CachedManagedFollowers = FollowerManagerScript.GetAllFollowers()
        OID_FM_DismissFollower = new int[20]
        OID_FM_ClearHome = new int[20]
        OID_FM_AssignHome = new int[20]
        OID_FM_Rapport = new int[20]
        OID_FM_Trust = new int[20]
        OID_FM_Loyalty = new int[20]
        OID_FM_Mood = new int[20]
        OID_FM_CombatStyle = new int[20]

        If CachedManagedFollowers.Length == 0
            AddTextOption("", "No companions recruited", OPTION_FLAG_DISABLED)
            AddTextOption("", "Adjust values here for mid-playthrough", OPTION_FLAG_DISABLED)
            AddTextOption("", "followers once they are recruited.", OPTION_FLAG_DISABLED)
        Else
            ; Clamp selection to valid range
            If SelectedCompanionIdx >= CachedManagedFollowers.Length
                SelectedCompanionIdx = 0
            EndIf

            AddTextOption("Companions", CachedManagedFollowers.Length + " recruited", OPTION_FLAG_DISABLED)
            OID_FM_CompanionSelect = AddMenuOption("Select Companion", CachedManagedFollowers[SelectedCompanionIdx].GetDisplayName())

            AddEmptyOption()

            ; Draw only the selected companion's details
            Int j = SelectedCompanionIdx
            Actor follower = CachedManagedFollowers[j]
            If follower
                Float rapport = FollowerManagerScript.GetRapport(follower)
                Float trust = FollowerManagerScript.GetTrust(follower)
                Float loyalty = FollowerManagerScript.GetLoyalty(follower)
                Float mood = FollowerManagerScript.GetMood(follower)
                String style = FollowerManagerScript.GetCombatStyle(follower)
                String home = FollowerManagerScript.GetAssignedHome(follower)

                AddHeaderOption(follower.GetDisplayName())

                ; Survival needs (read-only, only if survival is enabled)
                If SurvivalScript && SurvivalScript.Enabled && !SurvivalScript.IsFollowerExcluded(follower)
                    If SurvivalScript.HungerEnabled
                        Int hunger = SurvivalScript.GetFollowerHunger(follower)
                        AddTextOption("Hunger", hunger + "% (" + SurvivalScript.GetHungerLevelName(hunger) + ")", OPTION_FLAG_DISABLED)
                    EndIf
                    If SurvivalScript.FatigueEnabled
                        Int fatigue = SurvivalScript.GetFollowerFatigue(follower)
                        AddTextOption("Fatigue", fatigue + "% (" + SurvivalScript.GetFatigueLevelName(fatigue) + ")", OPTION_FLAG_DISABLED)
                    EndIf
                    If SurvivalScript.ColdEnabled
                        Int cold = SurvivalScript.GetFollowerCold(follower)
                        AddTextOption("Cold", cold + "% (" + SurvivalScript.GetColdLevelName(cold) + ")", OPTION_FLAG_DISABLED)
                    EndIf
                EndIf

                ; Outfit lock status (read-only)
                Int lockActive = StorageUtil.GetIntValue(follower, "SeverOutfit_LockActive", 0)
                If lockActive == 1
                    String lockKey = "SeverOutfit_Locked_" + (follower.GetFormID() as String)
                    Int itemCount = StorageUtil.FormListCount(None, lockKey)
                    AddTextOption("Outfit Lock", "Active (" + itemCount + " items)", OPTION_FLAG_DISABLED)
                Else
                    AddTextOption("Outfit Lock", "Inactive", OPTION_FLAG_DISABLED)
                EndIf

                ; Per-follower auto-switch toggle
                If OutfitScript
                    Bool actorAutoSwitch = SeverActionsNative.Native_Outfit_GetAutoSwitchEnabled(follower)
                    OID_FM_PerActorAutoSwitch = AddToggleOption("Auto-Switch Outfits", actorAutoSwitch)

                    ; Show current situation if available
                    String curSit = SeverActionsNative.Native_Outfit_GetCurrentSituation(follower)
                    String activePreset = SeverActionsNative.Native_Outfit_GetActivePreset(follower)
                    If curSit != ""
                        String sitDisplay = curSit
                        If activePreset != ""
                            sitDisplay = curSit + " (" + activePreset + ")"
                        EndIf
                        AddTextOption("Current Situation", sitDisplay, OPTION_FLAG_DISABLED)
                    EndIf
                EndIf

                OID_FM_Rapport[j] = AddSliderOption("Rapport", rapport, "{0}")
                OID_FM_Trust[j] = AddSliderOption("Trust", trust, "{0}")
                OID_FM_Loyalty[j] = AddSliderOption("Loyalty", loyalty, "{0}")
                OID_FM_Mood[j] = AddSliderOption("Mood", mood, "{0}")
                OID_FM_CombatStyle[j] = AddMenuOption("Combat Style", style)
                If home != ""
                    AddTextOption("Home", home, OPTION_FLAG_DISABLED)
                    OID_FM_AssignHome[j] = AddTextOption("Assign Home Here", "CLICK")
                    OID_FM_ClearHome[j] = AddTextOption("Clear Home", "CLICK")
                Else
                    AddTextOption("Home", "Not assigned", OPTION_FLAG_DISABLED)
                    OID_FM_AssignHome[j] = AddTextOption("Assign Home Here", "CLICK")
                EndIf
                OID_FM_DismissFollower[j] = AddTextOption("Dismiss", "CLICK")
                OID_FM_ForceRemove = AddTextOption("Force Remove", "CLICK")

                ; Saved outfit presets
                If OutfitScript
                    CachedPresetNames = OutfitScript.GetPresetNames(follower)
                    If CachedPresetNames.Length > 0
                        AddHeaderOption("Saved Outfits")
                        OID_FM_DeletePreset = new int[20]
                        Int p = 0
                        While p < CachedPresetNames.Length && p < 20
                            Int presetItems = OutfitScript.GetPresetItemCount(follower, CachedPresetNames[p])
                            AddTextOption(CachedPresetNames[p], presetItems + " items", OPTION_FLAG_DISABLED)
                            OID_FM_DeletePreset[p] = AddTextOption("Delete '" + CachedPresetNames[p] + "'", "CLICK")
                            p += 1
                        EndWhile
                    Else
                        CachedPresetNames = PapyrusUtil.StringArray(0)
                        OID_FM_DeletePreset = new int[1]
                    EndIf
                EndIf
            EndIf
        EndIf

        ; --- Dismissed NPCs with Homes ---
        AddEmptyOption()
        AddHeaderOption("Assigned NPCs")
        CachedDismissedFollowers = FollowerManagerScript.GetDismissedWithHomes()
        OID_FM_DismissedClearHome = new int[20]
        OID_FM_DismissedReRecruit = new int[20]

        If CachedDismissedFollowers.Length == 0
            AddTextOption("", "No dismissed NPCs with homes", OPTION_FLAG_DISABLED)
        Else
            If SelectedDismissedIdx >= CachedDismissedFollowers.Length
                SelectedDismissedIdx = 0
            EndIf
            AddTextOption("Assigned", CachedDismissedFollowers.Length + " NPCs", OPTION_FLAG_DISABLED)
            OID_FM_DismissedSelect = AddMenuOption("Select NPC", CachedDismissedFollowers[SelectedDismissedIdx].GetDisplayName())

            Int d = SelectedDismissedIdx
            Actor dismissed = CachedDismissedFollowers[d]
            If dismissed
                String dHome = FollowerManagerScript.GetAssignedHome(dismissed)
                AddTextOption("Home", dHome, OPTION_FLAG_DISABLED)
                OID_FM_DismissedClearHome[d] = AddTextOption("Clear Home", "CLICK")
                OID_FM_DismissedReRecruit[d] = AddTextOption("Re-Recruit", "CLICK")
            EndIf
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

    elseif option == OID_TagCompanion
        TagCompanionEnabled = !TagCompanionEnabled
        SetToggleOptionValue(OID_TagCompanion, TagCompanionEnabled)
        StorageUtil.SetIntValue(None, "SeverActions_TagCompanion", TagCompanionEnabled as Int)

    elseif option == OID_TagEngaged
        TagEngagedEnabled = !TagEngagedEnabled
        SetToggleOptionValue(OID_TagEngaged, TagEngagedEnabled)
        StorageUtil.SetIntValue(None, "SeverActions_TagEngaged", TagEngagedEnabled as Int)

    elseif option == OID_TagInScene
        TagInSceneEnabled = !TagInSceneEnabled
        SetToggleOptionValue(OID_TagInScene, TagInSceneEnabled)
        StorageUtil.SetIntValue(None, "SeverActions_TagInScene", TagInSceneEnabled as Int)

    elseif option == OID_SpellFailEnabled
        if SpellTeachScript
            SpellTeachScript.EnableFailureSystem = !SpellTeachScript.EnableFailureSystem
            SetToggleOptionValue(OID_SpellFailEnabled, SpellTeachScript.EnableFailureSystem)
            StorageUtil.SetIntValue(None, "SeverActions_SpellFailEnabled", SpellTeachScript.EnableFailureSystem as Int)
        endif

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

    ; Bounty page - clear individual bounties
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
    elseif option == OID_FM_OutfitLock
        If OutfitScript
            OutfitScript.OutfitLockEnabled = !OutfitScript.OutfitLockEnabled
            SetToggleOptionValue(OID_FM_OutfitLock, OutfitScript.OutfitLockEnabled)
        EndIf
    elseif option == OID_FM_AutoSwitch
        Bool curEnabled = SeverActionsNative.SituationMonitor_IsEnabled()
        SeverActionsNative.SituationMonitor_SetEnabled(!curEnabled)
        StorageUtil.SetIntValue(None, "SeverOutfit_GlobalAutoSwitch", (!curEnabled) as Int)
        SetToggleOptionValue(OID_FM_AutoSwitch, !curEnabled)
    elseif option == OID_FM_PerActorAutoSwitch
        If CachedManagedFollowers && SelectedCompanionIdx < CachedManagedFollowers.Length
            Actor follower = CachedManagedFollowers[SelectedCompanionIdx]
            If follower
                Bool curVal = SeverActionsNative.Native_Outfit_GetAutoSwitchEnabled(follower)
                Bool newVal = !curVal
                Debug.Trace("[SeverActions_MCM] PerActorAutoSwitch: " + follower.GetDisplayName() + " (" + follower.GetFormID() + ") curVal=" + curVal + " → newVal=" + newVal)
                SeverActionsNative.Native_Outfit_SetAutoSwitchEnabled(follower, newVal)
                StorageUtil.SetIntValue(follower, "SeverOutfit_AutoSwitch", newVal as Int)
                ; Verify the write took effect
                Bool verifyVal = SeverActionsNative.Native_Outfit_GetAutoSwitchEnabled(follower)
                Debug.Trace("[SeverActions_MCM] PerActorAutoSwitch verify: " + verifyVal)
                ForcePageReset()
            EndIf
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
    elseif option == OID_FM_AutoAssessment
        If FollowerManagerScript
            FollowerManagerScript.AutoRelAssessment = !FollowerManagerScript.AutoRelAssessment
            SetToggleOptionValue(OID_FM_AutoAssessment, FollowerManagerScript.AutoRelAssessment)
        EndIf
    elseif option == OID_FM_AutoInterAssessment
        If FollowerManagerScript
            FollowerManagerScript.AutoInterFollowerAssessment = !FollowerManagerScript.AutoInterFollowerAssessment
            SetToggleOptionValue(OID_FM_AutoInterAssessment, FollowerManagerScript.AutoInterFollowerAssessment)
        EndIf
    elseif option == OID_FM_AutoOffScreenLife
        If FollowerManagerScript
            FollowerManagerScript.AutoOffScreenLife = !FollowerManagerScript.AutoOffScreenLife
            SetToggleOptionValue(OID_FM_AutoOffScreenLife, FollowerManagerScript.AutoOffScreenLife)
        EndIf
    elseif option == OID_FM_OffScreenConsequences
        If FollowerManagerScript
            FollowerManagerScript.OffScreenConsequences = !FollowerManagerScript.OffScreenConsequences
            SetToggleOptionValue(OID_FM_OffScreenConsequences, FollowerManagerScript.OffScreenConsequences)
        EndIf
    elseif option == OID_FM_ForceRemove
        If FollowerManagerScript && CachedManagedFollowers && SelectedCompanionIdx < CachedManagedFollowers.Length
            Actor follower = CachedManagedFollowers[SelectedCompanionIdx]
            String fName = "this follower"
            If follower
                fName = follower.GetDisplayName()
            EndIf
            bool confirm = ShowMessage("Force remove " + fName + "? This erases ALL data (factions, aliases, relationships, outfits, home) and cannot be undone.", true, "Yes", "No")
            If confirm
                If follower
                    FollowerManagerScript.PurgeFollower(follower)
                EndIf
                ; Also clear from native stores
                If follower
                    SeverActionsNative.Native_RemoveFollowerData(follower)
                    SeverActionsNative.Native_Outfit_RemoveActor(follower)
                EndIf
                ForcePageReset()
                Debug.Notification(fName + " force-removed.")
            EndIf
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
            While j < CachedManagedFollowers.Length && j < 20
                If option == OID_FM_DismissFollower[j] && CachedManagedFollowers[j]
                    bool confirm = ShowMessage("Dismiss " + CachedManagedFollowers[j].GetDisplayName() + "?", true, "Yes", "No")
                    If confirm
                        FollowerManagerScript.UnregisterFollower(CachedManagedFollowers[j])
                        ForcePageReset()
                    EndIf
                ElseIf OID_FM_AssignHome && option == OID_FM_AssignHome[j] && CachedManagedFollowers[j]
                    Location currentLoc = Game.GetPlayer().GetCurrentLocation()
                    If currentLoc
                        String locName = currentLoc.GetName()
                        If locName != ""
                            FollowerManagerScript.AssignHome(CachedManagedFollowers[j], locName)
                            ForcePageReset()
                        Else
                            Debug.Notification("Current location has no name.")
                        EndIf
                    Else
                        Debug.Notification("No location detected — try from inside a named area.")
                    EndIf
                ElseIf OID_FM_ClearHome && option == OID_FM_ClearHome[j] && CachedManagedFollowers[j]
                    FollowerManagerScript.ClearHome(CachedManagedFollowers[j])
                    Debug.Notification(CachedManagedFollowers[j].GetDisplayName() + "'s home cleared.")
                    ForcePageReset()
                EndIf
                j += 1
            EndWhile
        EndIf

        ; Dismissed NPCs: clear home / re-recruit
        If FollowerManagerScript && OID_FM_DismissedClearHome && CachedDismissedFollowers
            Int d = 0
            While d < CachedDismissedFollowers.Length && d < 20
                If option == OID_FM_DismissedClearHome[d] && CachedDismissedFollowers[d]
                    FollowerManagerScript.ClearHome(CachedDismissedFollowers[d])
                    Debug.Notification(CachedDismissedFollowers[d].GetDisplayName() + "'s home cleared.")
                    ForcePageReset()
                ElseIf OID_FM_DismissedReRecruit && option == OID_FM_DismissedReRecruit[d] && CachedDismissedFollowers[d]
                    bool confirm = ShowMessage("Re-recruit " + CachedDismissedFollowers[d].GetDisplayName() + "?", true, "Yes", "No")
                    If confirm
                        FollowerManagerScript.RegisterFollower(CachedDismissedFollowers[d])
                        ForcePageReset()
                    EndIf
                EndIf
                d += 1
            EndWhile
        EndIf

        ; General page: NPC Home clear buttons
        If FollowerManagerScript && OID_ClearNPCHome && CachedHomedNPCs
            Int h = 0
            While h < CachedHomedNPCs.Length && h < 20
                If option == OID_ClearNPCHome[h] && CachedHomedNPCs[h]
                    FollowerManagerScript.ClearHome(CachedHomedNPCs[h])
                    Debug.Notification(CachedHomedNPCs[h].GetDisplayName() + "'s home cleared.")
                    ForcePageReset()
                EndIf
                h += 1
            EndWhile
        EndIf

        ; --- Outfits page: lock toggle ---
        If option == OID_Outfit_Lock && OutfitScript && CachedPresetActors
            If SelectedOutfitNPCIdx < CachedPresetActors.Length
                Actor target = CachedPresetActors[SelectedOutfitNPCIdx]
                If target
                    Bool currentLock = OutfitScript.HasNonFollowerOutfitLock(target)
                    OutfitScript.SetNonFollowerOutfitLock(target, !currentLock)
                    SetToggleOptionValue(OID_Outfit_Lock, !currentLock)
                    ; Assign/clear outfit alias slot via FollowerManager
                    If FollowerManagerScript
                        If !currentLock
                            FollowerManagerScript.AssignOutfitSlot(target)
                        Else
                            FollowerManagerScript.ClearOutfitSlot(target)
                        EndIf
                    EndIf
                EndIf
            EndIf
        EndIf

        ; --- Outfits page: preset delete buttons ---
        If OutfitScript && OID_Outfit_DeletePreset && CachedOutfitPresetNames && CachedPresetActors
            Int p = 0
            While p < CachedOutfitPresetNames.Length && p < 20
                If option == OID_Outfit_DeletePreset[p]
                    If SelectedOutfitNPCIdx < CachedPresetActors.Length
                        Actor target = CachedPresetActors[SelectedOutfitNPCIdx]
                        If target
                            bool confirm = ShowMessage("Delete outfit preset '" + CachedOutfitPresetNames[p] + "' for " + target.GetDisplayName() + "?", true, "Yes", "No")
                            If confirm
                                OutfitScript.DeletePreset(target, CachedOutfitPresetNames[p])
                                Debug.Notification("Deleted preset: " + CachedOutfitPresetNames[p])
                                ForcePageReset()
                            EndIf
                        EndIf
                    EndIf
                    return
                EndIf
                p += 1
            EndWhile
        EndIf

        ; Follower page: Preset delete buttons
        If OutfitScript && OID_FM_DeletePreset && CachedPresetNames && CachedManagedFollowers
            Int p = 0
            While p < CachedPresetNames.Length && p < 20
                If option == OID_FM_DeletePreset[p]
                    Actor target = CachedManagedFollowers[SelectedCompanionIdx]
                    If target
                        bool confirm = ShowMessage("Delete outfit preset '" + CachedPresetNames[p] + "' for " + target.GetDisplayName() + "?", true, "Yes", "No")
                        If confirm
                            OutfitScript.DeletePreset(target, CachedPresetNames[p])
                            Debug.Notification("Deleted preset: " + CachedPresetNames[p])
                            ForcePageReset()
                        EndIf
                    EndIf
                    return
                EndIf
                p += 1
            EndWhile
        EndIf

        If SurvivalScript && OID_FollowerExclude && CachedFollowers
            Int j = 0
            While j < CachedFollowers.Length && j < 20
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

    elseif option == OID_DismissKey
        DismissKey = keyCode
        SetKeyMapOptionValue(OID_DismissKey, keyCode)
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

    elseif option == OID_SetCompanionKey
        SetCompanionKey = keyCode
        SetKeyMapOptionValue(OID_SetCompanionKey, keyCode)
        ApplyHotkeySettings()

    elseif option == OID_CompanionWaitKey
        CompanionWaitKey = keyCode
        SetKeyMapOptionValue(OID_CompanionWaitKey, keyCode)
        ApplyHotkeySettings()

    elseif option == OID_AssignHomeKey
        AssignHomeKey = keyCode
        SetKeyMapOptionValue(OID_AssignHomeKey, keyCode)
        ApplyHotkeySettings()

    elseif option == OID_WheelMenuKey
        WheelMenuKey = keyCode
        SetKeyMapOptionValue(OID_WheelMenuKey, keyCode)
        ApplyWheelMenuSettings()

    elseif option == OID_ConfigMenuKey
        ConfigMenuKey = keyCode
        SetKeyMapOptionValue(OID_ConfigMenuKey, keyCode)
        ApplyConfigMenuKeySettings()
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
    elseif option == OID_BookReadMode
        If LootScript
            SetMenuDialogStartIndex(LootScript.BookReadMode)
            SetMenuDialogDefaultIndex(0)
            SetMenuDialogOptions(BookReadModeOptions)
        EndIf
    elseif option == OID_FM_FrameworkMode
        If FollowerManagerScript
            SetMenuDialogStartIndex(FollowerManagerScript.FrameworkMode)
            SetMenuDialogDefaultIndex(0)
            SetMenuDialogOptions(FrameworkModeOptions)
        EndIf
    elseif option == OID_Outfit_NPCSelect
        ; Build NPC name list for the Outfits page dropdown
        If CachedPresetActors && CachedPresetActors.Length > 0
            string[] npcNames = new string[10]
            Int n = 0
            Int nCount = 0
            While n < CachedPresetActors.Length && n < 20
                If CachedPresetActors[n]
                    npcNames[nCount] = CachedPresetActors[n].GetDisplayName()
                    nCount += 1
                EndIf
                n += 1
            EndWhile
            SetMenuDialogStartIndex(SelectedOutfitNPCIdx)
            SetMenuDialogDefaultIndex(0)
            SetMenuDialogOptions(npcNames)
        EndIf
    elseif option == OID_FM_CompanionSelect
        ; Build companion name list for the dropdown
        If CachedManagedFollowers && CachedManagedFollowers.Length > 0
            string[] names = new string[10]
            Int j = 0
            Int count = 0
            While j < CachedManagedFollowers.Length && j < 20
                If CachedManagedFollowers[j]
                    names[count] = CachedManagedFollowers[j].GetDisplayName()
                    count += 1
                EndIf
                j += 1
            EndWhile
            ; Trim to actual count
            string[] trimmed = PapyrusUtil.StringArray(count)
            j = 0
            While j < count
                trimmed[j] = names[j]
                j += 1
            EndWhile
            SetMenuDialogStartIndex(SelectedCompanionIdx)
            SetMenuDialogDefaultIndex(0)
            SetMenuDialogOptions(trimmed)
        EndIf
    elseif option == OID_FM_DismissedSelect
        ; Build dismissed NPC name list for the dropdown
        If CachedDismissedFollowers && CachedDismissedFollowers.Length > 0
            string[] dnames = new string[10]
            Int j = 0
            Int count = 0
            While j < CachedDismissedFollowers.Length && j < 20
                If CachedDismissedFollowers[j]
                    dnames[count] = CachedDismissedFollowers[j].GetDisplayName()
                    count += 1
                EndIf
                j += 1
            EndWhile
            string[] dtrimmed = PapyrusUtil.StringArray(count)
            j = 0
            While j < count
                dtrimmed[j] = dnames[j]
                j += 1
            EndWhile
            SetMenuDialogStartIndex(SelectedDismissedIdx)
            SetMenuDialogDefaultIndex(0)
            SetMenuDialogOptions(dtrimmed)
        EndIf
    else
        ; Per-follower combat style menus
        If FollowerManagerScript && CachedManagedFollowers && OID_FM_CombatStyle
            Int j = 0
            While j < CachedManagedFollowers.Length && j < 20
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
    elseif option == OID_BookReadMode
        If LootScript
            LootScript.BookReadMode = index
            SetMenuOptionValue(OID_BookReadMode, BookReadModeOptions[index])
        EndIf
    elseif option == OID_FM_FrameworkMode
        If FollowerManagerScript
            FollowerManagerScript.FrameworkMode = index
            SetMenuOptionValue(OID_FM_FrameworkMode, FrameworkModeOptions[index])
        EndIf
    elseif option == OID_Outfit_NPCSelect
        SelectedOutfitNPCIdx = index
        ForcePageReset()
    elseif option == OID_FM_CompanionSelect
        SelectedCompanionIdx = index
        ForcePageReset()
    elseif option == OID_FM_DismissedSelect
        SelectedDismissedIdx = index
        ForcePageReset()
    else
        ; Per-follower combat style menus
        If FollowerManagerScript && CachedManagedFollowers && OID_FM_CombatStyle
            Int j = 0
            While j < CachedManagedFollowers.Length && j < 20
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
    elseif option == OID_NPCArrestCooldown
        SetSliderDialogStartValue(ArrestScript.NPCArrestCooldown)
        SetSliderDialogDefaultValue(300.0)
        SetSliderDialogRange(0.0, 600.0)
        SetSliderDialogInterval(15.0)
    elseif option == OID_PersuasionTimeLimit
        SetSliderDialogStartValue(ArrestScript.PersuasionTimeLimit)
        SetSliderDialogDefaultValue(90.0)
        SetSliderDialogRange(30.0, 300.0)
        SetSliderDialogInterval(5.0)
    elseif option == OID_SilenceChance
        SetSliderDialogStartValue(SilenceChance as Float)
        SetSliderDialogDefaultValue(50.0)
        SetSliderDialogRange(0.0, 100.0)
        SetSliderDialogInterval(5.0)

    elseif option == OID_SpellFailDifficulty
        if SpellTeachScript
            SetSliderDialogStartValue(SpellTeachScript.FailureDifficultyMult)
            SetSliderDialogDefaultValue(1.0)
            SetSliderDialogRange(0.0, 3.0)
            SetSliderDialogInterval(0.1)
        endif

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
            SetSliderDialogDefaultValue(20.0)
            SetSliderDialogRange(1.0, 30.0)
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
    elseif option == OID_FM_RelCooldown
        If FollowerManagerScript
            SetSliderDialogStartValue(FollowerManagerScript.RelationshipCooldown)
            SetSliderDialogDefaultValue(120.0)
            SetSliderDialogRange(60.0, 300.0)
            SetSliderDialogInterval(15.0)
        EndIf
    elseif option == OID_FM_AssessCooldownMin
        If FollowerManagerScript
            SetSliderDialogStartValue(FollowerManagerScript.AssessmentCooldownMinHours)
            SetSliderDialogDefaultValue(4.0)
            SetSliderDialogRange(1.0, 24.0)
            SetSliderDialogInterval(1.0)
        EndIf
    elseif option == OID_FM_AssessCooldownMax
        If FollowerManagerScript
            SetSliderDialogStartValue(FollowerManagerScript.AssessmentCooldownMaxHours)
            SetSliderDialogDefaultValue(10.0)
            SetSliderDialogRange(1.0, 48.0)
            SetSliderDialogInterval(1.0)
        EndIf
    elseif option == OID_FM_InterAssessCooldownMin
        If FollowerManagerScript
            SetSliderDialogStartValue(FollowerManagerScript.InterFollowerCooldownMinHours)
            SetSliderDialogDefaultValue(6.0)
            SetSliderDialogRange(2.0, 48.0)
            SetSliderDialogInterval(1.0)
        EndIf
    elseif option == OID_FM_InterAssessCooldownMax
        If FollowerManagerScript
            SetSliderDialogStartValue(FollowerManagerScript.InterFollowerCooldownMaxHours)
            SetSliderDialogDefaultValue(14.0)
            SetSliderDialogRange(2.0, 72.0)
            SetSliderDialogInterval(1.0)
        EndIf
    elseif option == OID_FM_OffScreenCooldownMin
        If FollowerManagerScript
            SetSliderDialogStartValue(FollowerManagerScript.OffScreenLifeCooldownMinHours)
            SetSliderDialogDefaultValue(10.0)
            SetSliderDialogRange(4.0, 48.0)
            SetSliderDialogInterval(1.0)
        EndIf
    elseif option == OID_FM_OffScreenCooldownMax
        If FollowerManagerScript
            SetSliderDialogStartValue(FollowerManagerScript.OffScreenLifeCooldownMaxHours)
            SetSliderDialogDefaultValue(40.0)
            SetSliderDialogRange(6.0, 96.0)
            SetSliderDialogInterval(1.0)
        EndIf
    elseif option == OID_FM_ConsequenceCooldown
        If FollowerManagerScript
            SetSliderDialogStartValue(FollowerManagerScript.ConsequenceCooldownHours)
            SetSliderDialogDefaultValue(36.0)
            SetSliderDialogRange(6.0, 72.0)
            SetSliderDialogInterval(1.0)
        EndIf
    elseif option == OID_FM_MaxBounty
        If FollowerManagerScript
            SetSliderDialogStartValue(FollowerManagerScript.MaxOffScreenBounty as Float)
            SetSliderDialogDefaultValue(1000.0)
            SetSliderDialogRange(100.0, 5000.0)
            SetSliderDialogInterval(100.0)
        EndIf
    elseif option == OID_FM_MaxGoldChange
        If FollowerManagerScript
            SetSliderDialogStartValue(FollowerManagerScript.MaxOffScreenGoldChange as Float)
            SetSliderDialogDefaultValue(500.0)
            SetSliderDialogRange(50.0, 2000.0)
            SetSliderDialogInterval(50.0)
        EndIf
    elseif option == OID_FM_DeathGracePeriod
        If FollowerManagerScript
            SetSliderDialogStartValue(FollowerManagerScript.DeathGracePeriodHours)
            SetSliderDialogDefaultValue(4.0)
            SetSliderDialogRange(0.0, 48.0)
            SetSliderDialogInterval(1.0)
        EndIf
    elseif option == OID_FM_StabilityDelay
        SetSliderDialogStartValue((SeverActionsNative.SituationMonitor_GetStabilityThreshold() as Float) / 1000.0)
        SetSliderDialogDefaultValue(5.0)
        SetSliderDialogRange(3.0, 15.0)
        SetSliderDialogInterval(1.0)

    ; Per-follower relationship sliders
    else
        If FollowerManagerScript && CachedManagedFollowers
            Int j = 0
            While j < CachedManagedFollowers.Length && j < 20
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
    elseif option == OID_NPCArrestCooldown
        ArrestScript.NPCArrestCooldown = value
        SetSliderOptionValue(OID_NPCArrestCooldown, value, "{0} sec")
    elseif option == OID_PersuasionTimeLimit
        ArrestScript.PersuasionTimeLimit = value
        SetSliderOptionValue(OID_PersuasionTimeLimit, value, "{0} sec")
    elseif option == OID_SilenceChance
        SilenceChance = value as Int
        StorageUtil.SetIntValue(None, "SeverActions_ZeroChance", SilenceChance)
        SetSliderOptionValue(OID_SilenceChance, value, "{0}%")

    elseif option == OID_SpellFailDifficulty
        if SpellTeachScript
            SpellTeachScript.FailureDifficultyMult = value
            StorageUtil.SetFloatValue(None, "SeverActions_SpellFailDifficulty", value)
            SetSliderOptionValue(OID_SpellFailDifficulty, value, "{1}x")
        endif

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
    elseif option == OID_FM_RelCooldown
        If FollowerManagerScript
            FollowerManagerScript.RelationshipCooldown = value
            SetSliderOptionValue(OID_FM_RelCooldown, value, "{0} sec")
        EndIf
    elseif option == OID_FM_AssessCooldownMin
        If FollowerManagerScript
            FollowerManagerScript.AssessmentCooldownMinHours = value
            ; Clamp max if min exceeds it
            If value > FollowerManagerScript.AssessmentCooldownMaxHours
                FollowerManagerScript.AssessmentCooldownMaxHours = value
                SetSliderOptionValue(OID_FM_AssessCooldownMax, value, "{1} hrs")
            EndIf
            SetSliderOptionValue(OID_FM_AssessCooldownMin, value, "{1} hrs")
        EndIf
    elseif option == OID_FM_AssessCooldownMax
        If FollowerManagerScript
            FollowerManagerScript.AssessmentCooldownMaxHours = value
            ; Clamp min if max falls below it
            If value < FollowerManagerScript.AssessmentCooldownMinHours
                FollowerManagerScript.AssessmentCooldownMinHours = value
                SetSliderOptionValue(OID_FM_AssessCooldownMin, value, "{1} hrs")
            EndIf
            SetSliderOptionValue(OID_FM_AssessCooldownMax, value, "{1} hrs")
        EndIf
    elseif option == OID_FM_InterAssessCooldownMin
        If FollowerManagerScript
            FollowerManagerScript.InterFollowerCooldownMinHours = value
            If value > FollowerManagerScript.InterFollowerCooldownMaxHours
                FollowerManagerScript.InterFollowerCooldownMaxHours = value
                SetSliderOptionValue(OID_FM_InterAssessCooldownMax, value, "{1} hrs")
            EndIf
            SetSliderOptionValue(OID_FM_InterAssessCooldownMin, value, "{1} hrs")
        EndIf
    elseif option == OID_FM_InterAssessCooldownMax
        If FollowerManagerScript
            FollowerManagerScript.InterFollowerCooldownMaxHours = value
            If value < FollowerManagerScript.InterFollowerCooldownMinHours
                FollowerManagerScript.InterFollowerCooldownMinHours = value
                SetSliderOptionValue(OID_FM_InterAssessCooldownMin, value, "{1} hrs")
            EndIf
            SetSliderOptionValue(OID_FM_InterAssessCooldownMax, value, "{1} hrs")
        EndIf
    elseif option == OID_FM_OffScreenCooldownMin
        If FollowerManagerScript
            FollowerManagerScript.OffScreenLifeCooldownMinHours = value
            If value > FollowerManagerScript.OffScreenLifeCooldownMaxHours
                FollowerManagerScript.OffScreenLifeCooldownMaxHours = value
                SetSliderOptionValue(OID_FM_OffScreenCooldownMax, value, "{1} hrs")
            EndIf
            SetSliderOptionValue(OID_FM_OffScreenCooldownMin, value, "{1} hrs")
        EndIf
    elseif option == OID_FM_OffScreenCooldownMax
        If FollowerManagerScript
            FollowerManagerScript.OffScreenLifeCooldownMaxHours = value
            If value < FollowerManagerScript.OffScreenLifeCooldownMinHours
                FollowerManagerScript.OffScreenLifeCooldownMinHours = value
                SetSliderOptionValue(OID_FM_OffScreenCooldownMin, value, "{1} hrs")
            EndIf
            SetSliderOptionValue(OID_FM_OffScreenCooldownMax, value, "{1} hrs")
        EndIf
    elseif option == OID_FM_ConsequenceCooldown
        If FollowerManagerScript
            FollowerManagerScript.ConsequenceCooldownHours = value
            SetSliderOptionValue(OID_FM_ConsequenceCooldown, value, "{1} hrs")
        EndIf
    elseif option == OID_FM_MaxBounty
        If FollowerManagerScript
            FollowerManagerScript.MaxOffScreenBounty = value as Int
            SetSliderOptionValue(OID_FM_MaxBounty, value, "{0}")
        EndIf
    elseif option == OID_FM_MaxGoldChange
        If FollowerManagerScript
            FollowerManagerScript.MaxOffScreenGoldChange = value as Int
            SetSliderOptionValue(OID_FM_MaxGoldChange, value, "{0}")
        EndIf
    elseif option == OID_FM_DeathGracePeriod
        If FollowerManagerScript
            FollowerManagerScript.DeathGracePeriodHours = value
            SetSliderOptionValue(OID_FM_DeathGracePeriod, value, "{0} hrs")
        EndIf
    elseif option == OID_FM_StabilityDelay
        SeverActionsNative.SituationMonitor_SetStabilityThreshold((value * 1000.0) as Int)
        SetSliderOptionValue(OID_FM_StabilityDelay, value, "{0} sec")

    ; Per-follower relationship sliders
    else
        If FollowerManagerScript && CachedManagedFollowers
            Int j = 0
            While j < CachedManagedFollowers.Length && j < 20
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
    elseif option == OID_SilenceChance
        SetInfoText("Probability (0-100%) that silence is offered as an option when choosing the next speaker. 0% = NPCs always speak, 100% = silence always available. Default: 50%")
    elseif option == OID_BookReadMode
        SetInfoText("How NPCs read books aloud. Verbatim: reads word-for-word (takes longer). Summarize: gives a summary and shares their in-character thoughts. Default: Read Aloud.")

    elseif option == OID_SpellFailEnabled
        SetInfoText("Enable the spell failure system. When enabled, learning spells above Novice tier has a chance to fail with school-specific consequences (explosions, hostile summons, etc).")
    elseif option == OID_SpellFailDifficulty
        SetInfoText("Multiplier for failure chance. 0.5 = half as likely to fail, 1.0 = normal, 2.0 = twice as likely. Set to 0 to disable failures without turning off the system.")

    elseif option == OID_TagCompanion
        SetInfoText("Show the [COMPANION] tag in the speaker selector prompt. When enabled, the AI sees which NPCs are your followers and weighs them more heavily for conversation. Disable to make companions less chatty.")
    elseif option == OID_TagEngaged
        SetInfoText("Show the [ENGAGED] tag in the speaker selector prompt. Engaged NPCs have a lower threshold to speak up. Disable to remove the engagement bias from speaker selection.")
    elseif option == OID_TagInScene
        SetInfoText("Show the [IN SCENE] tag in the speaker selector prompt. NPCs in intimate scenes are strongly deprioritized from speaking. Disable to remove this tag from the AI's consideration.")

    elseif option == OID_AllowConjuredGold
        SetInfoText("Allow NPCs to give gold they don't actually have. Useful for rewards and quest payments. Disable for hardcore economy.")

    elseif option == OID_DebtActiveCount
        SetInfoText("Number of active debt records between you and NPCs.")
    elseif option == OID_DebtPlayerOwes
        SetInfoText("Total gold you owe to all NPCs combined.")
    elseif option == OID_DebtOwedToPlayer
        SetInfoText("Total gold all NPCs owe to you combined.")

    elseif option == OID_ResetTravelSlots
        SetInfoText("Emergency reset: Clears all travel slots and cancels any active NPC travel. Use if travel slots appear stuck or show incorrect status.")
        
    elseif option == OID_TravelSlot0 || option == OID_TravelSlot1 || option == OID_TravelSlot2 || option == OID_TravelSlot3 || option == OID_TravelSlot4
        SetInfoText("Click to clear this travel slot. This will cancel travel for the NPC and restore their follower status if applicable.")
        
    elseif option == OID_FollowToggleKey
        SetInfoText("Hotkey to toggle NPC following. Look at an NPC and press this key to make them follow you or stop following. Also resumes following if they were waiting.")
        
    elseif option == OID_DismissKey
        SetInfoText("Hotkey to dismiss the targeted companion. Look at a companion and press this key to send them home.")

    elseif option == OID_SetCompanionKey
        SetInfoText("Hotkey to make the targeted NPC a companion. Registers them as a full companion with relationship tracking, survival needs, and outfit persistence.")

    elseif option == OID_CompanionWaitKey
        SetInfoText("Hotkey to tell an NPC to wait here. They'll sandbox around the area until you return. Press again on a waiting NPC to resume following. Works on any NPC, not just companions.")

    elseif option == OID_AssignHomeKey
        SetInfoText("Hotkey to assign the targeted NPC's home to your current location. The NPC will return here when dismissed. Works on any following NPC.")

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

    elseif option == OID_ConfigMenuKey
        SetInfoText("Hotkey to open the PrismaUI config menu. Requires PrismaUI mod. If PrismaUI is not installed, the key will do nothing. This provides a modern visual alternative to the MCM.")

    ; Bounty page tooltips
    elseif option == OID_BountyWhiterun || option == OID_BountyRift || option == OID_BountyHaafingar || option == OID_BountyEastmarch || option == OID_BountyReach || option == OID_BountyFalkreath || option == OID_BountyPale || option == OID_BountyHjaalmarch || option == OID_BountyWinterhold
        SetInfoText("Your tracked bounty in this hold. Click to clear. These bounties are managed by SeverActions and won't trigger vanilla guard arrest dialogue.")

    elseif option == OID_ClearAllBounties
        SetInfoText("Clear all tracked bounties in all holds at once. Use this to start fresh or if bounties are causing issues.")

    elseif option == OID_ArrestCooldown
        SetInfoText("Cooldown in seconds before guards can use the ArrestPlayer action again. Prevents guards from spamming arrest during persuasion. Set to 0 to disable. Default: 60 seconds.")

    elseif option == OID_NPCArrestCooldown
        SetInfoText("Cooldown in seconds before the ArrestNPC and Dispatch actions can be used again. Set to 0 to disable. Default: 300 seconds (5 minutes).")

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
        SetInfoText("Maximum number of companions allowed at once. Default: 20")
    elseif option == OID_FM_RapportDecay
        SetInfoText("How fast rapport decays when you don't talk to a companion. 1.0x is normal. Set to 0 to disable rapport decay. Default: 1.0x")
    elseif option == OID_FM_AllowLeaving
        SetInfoText("When enabled, companions with very low rapport may decide to leave on their own. Disable for companions that never leave regardless of treatment.")
    elseif option == OID_FM_LeavingThreshold
        SetInfoText("Rapport level at which companions may decide to leave. Lower values (closer to -100) mean they tolerate more mistreatment. Default: -60")
    elseif option == OID_FM_OutfitLock
        SetInfoText("When enabled, companion outfits are locked after dressing them and automatically re-applied on cell transitions. Disable if you want the game to handle companion gear normally.")
    elseif option == OID_FM_AutoSwitch
        SetInfoText("When enabled, companions automatically change outfits based on their situation (town, adventure, home, sleep). Requires outfit presets assigned to situations.")
    elseif option == OID_FM_StabilityDelay
        SetInfoText("How long a situation must be stable before triggering an outfit change. Higher values prevent flickering at town gates. Default: 5 seconds.")
    elseif option == OID_FM_PerActorAutoSwitch
        SetInfoText("Toggle automatic outfit switching for this specific companion. When disabled, this companion will not change outfits based on situation even if the global setting is enabled.")
    elseif option == OID_FM_FrameworkMode
        SetInfoText("How followers are managed.\nAuto: Uses NFF/EFF when installed. Ignore-token holders are tracked only.\nSeverActions Only: Bypasses NFF/EFF, uses our follow system for all.\nTracking Only: Never touches packages, AI, or teammate status. Followers are tracked for relationships, outfits, survival, and debt only — your other framework handles everything else.\nTakes effect on next recruit.")
    elseif option == OID_FM_Notifications
        SetInfoText("Show notifications when companions are recruited, dismissed, or when relationship milestones occur.")
    elseif option == OID_FM_Debug
        SetInfoText("Enable debug messages for companion framework. Shows relationship value changes in the console.")
    elseif option == OID_FM_AutoAssessment
        SetInfoText("When enabled, companions periodically reflect on recent events, memories, and diary entries. The system automatically adjusts rapport, trust, loyalty, and mood based on these reflections. Disable to manage relationship values manually or through actions only.")
    elseif option == OID_FM_AssessCooldownMin
        SetInfoText("Minimum game hours between relationship assessments per follower. Each follower gets a random cooldown between min and max after each assessment. Default: 4 hours.")
    elseif option == OID_FM_AssessCooldownMax
        SetInfoText("Maximum game hours between relationship assessments per follower. Each follower gets a random cooldown between min and max after each assessment. Default: 10 hours.")
    elseif option == OID_FM_AutoInterAssessment
        SetInfoText("When enabled, followers periodically evaluate how they feel about each other. Builds inter-party opinions based on shared events, memories, and interactions.")
    elseif option == OID_FM_InterAssessCooldownMin
        SetInfoText("Minimum game hours between inter-follower assessments per follower. Random cooldown between min and max. Default: 6 hours.")
    elseif option == OID_FM_InterAssessCooldownMax
        SetInfoText("Maximum game hours between inter-follower assessments per follower. Random cooldown between min and max. Default: 14 hours.")
    elseif option == OID_FM_AutoOffScreenLife
        SetInfoText("When enabled, dismissed followers with assigned homes will generate life events while you're away. They'll have things to talk about when you return, and local NPCs may gossip about their activities.")
    elseif option == OID_FM_OffScreenCooldownMin
        SetInfoText("Minimum game hours between off-screen life events per dismissed follower. Random cooldown between min and max. Default: 10 hours.")
    elseif option == OID_FM_OffScreenCooldownMax
        SetInfoText("Maximum game hours between off-screen life events per dismissed follower. Random cooldown between min and max. Default: 40 hours.")
    elseif option == OID_FM_OffScreenConsequences
        SetInfoText("When enabled, off-screen life events may have real consequences: followers can get arrested, earn or lose gold, or take on debt. Events are personality-driven — principled followers rarely commit crimes. Default: OFF.")
    elseif option == OID_FM_ConsequenceCooldown
        SetInfoText("Game hours between consequential off-screen events per follower. Consequences are rarer than regular events. Default: 36 hours.")
    elseif option == OID_FM_MaxBounty
        SetInfoText("Maximum cumulative bounty a follower can accumulate from off-screen crime events. Prevents runaway bounties. Default: 1000 gold.")
    elseif option == OID_FM_MaxGoldChange
        SetInfoText("Maximum gold a follower can gain or lose per off-screen event. Keeps the economy grounded. Default: 500 gold.")
    elseif option == OID_FM_DeathGracePeriod
        SetInfoText("Hours after a follower's death before they are automatically removed from the roster. Set to 0 to never auto-remove (manual only via PrismaUI). Default: 4 hours.")
    elseif option == OID_FM_RelCooldown
        SetInfoText("Minimum real-time seconds between relationship changes per companion. Prevents the AI from adjusting rapport/trust/loyalty/mood too frequently during conversation. Default: 120 seconds (2 minutes).")
    elseif option == OID_FM_CompanionSelect
        SetInfoText("Select which companion to view and edit. Use the dropdown to switch between your recruited companions.")
    elseif option == OID_Outfit_NPCSelect
        SetInfoText("Select which NPC to view and manage. Shows non-follower NPCs with saved outfit presets.")
    elseif option == OID_Outfit_Lock
        SetInfoText("When enabled, this NPC's outfit will be locked in place and re-equipped automatically on cell transitions. Disable to allow normal outfit changes.")
    elseif option == OID_FM_ResetAll
        SetInfoText("Emergency reset: dismisses all companions and clears all relationship data. Use if the system is stuck or broken.")

    ; Per-follower tooltips (survival exclusions + relationship sliders)
    else
        If OID_FollowerExclude && CachedFollowers
            Int j = 0
            While j < CachedFollowers.Length && j < 20
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
            While k < CachedManagedFollowers.Length && k < 20
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

        ; Follower page preset delete tooltips
        If OID_FM_DeletePreset && CachedPresetNames
            Int p = 0
            While p < CachedPresetNames.Length && p < 20
                If option == OID_FM_DeletePreset[p]
                    SetInfoText("Delete the saved outfit preset '" + CachedPresetNames[p] + "'. This cannot be undone.")
                    return
                EndIf
                p += 1
            EndWhile
        EndIf

        ; Outfits page preset delete tooltips
        If OID_Outfit_DeletePreset && CachedOutfitPresetNames
            Int p = 0
            While p < CachedOutfitPresetNames.Length && p < 20
                If option == OID_Outfit_DeletePreset[p]
                    SetInfoText("Delete the saved outfit preset '" + CachedOutfitPresetNames[p] + "'. This cannot be undone.")
                    return
                EndIf
                p += 1
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
    elseif option == OID_SilenceChance
        SilenceChance = 50
        StorageUtil.SetIntValue(None, "SeverActions_ZeroChance", 50)
        SetSliderOptionValue(OID_SilenceChance, 50.0, "{0}%")
    elseif option == OID_BookReadMode
        If LootScript
            LootScript.BookReadMode = 0
            SetMenuOptionValue(OID_BookReadMode, BookReadModeOptions[0])
        EndIf

    elseif option == OID_SpellFailEnabled
        if SpellTeachScript
            SpellTeachScript.EnableFailureSystem = true
            StorageUtil.SetIntValue(None, "SeverActions_SpellFailEnabled", 1)
            SetToggleOptionValue(OID_SpellFailEnabled, true)
        endif
    elseif option == OID_SpellFailDifficulty
        if SpellTeachScript
            SpellTeachScript.FailureDifficultyMult = 1.0
            StorageUtil.SetFloatValue(None, "SeverActions_SpellFailDifficulty", 1.0)
            SetSliderOptionValue(OID_SpellFailDifficulty, 1.0, "{1}x")
        endif

    elseif option == OID_TagCompanion
        TagCompanionEnabled = true
        StorageUtil.SetIntValue(None, "SeverActions_TagCompanion", 1)
        SetToggleOptionValue(OID_TagCompanion, true)
    elseif option == OID_TagEngaged
        TagEngagedEnabled = true
        StorageUtil.SetIntValue(None, "SeverActions_TagEngaged", 1)
        SetToggleOptionValue(OID_TagEngaged, true)
    elseif option == OID_TagInScene
        TagInSceneEnabled = true
        StorageUtil.SetIntValue(None, "SeverActions_TagInScene", 1)
        SetToggleOptionValue(OID_TagInScene, true)

    elseif option == OID_AllowConjuredGold
        AllowConjuredGold = true
        SetToggleOptionValue(OID_AllowConjuredGold, AllowConjuredGold)
        ApplyCurrencySettings()
        
    elseif option == OID_FollowToggleKey
        FollowToggleKey = -1
        SetKeyMapOptionValue(OID_FollowToggleKey, FollowToggleKey)
        ApplyHotkeySettings()
        
    elseif option == OID_DismissKey
        DismissKey = -1
        SetKeyMapOptionValue(OID_DismissKey, DismissKey)
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

    elseif option == OID_CompanionWaitKey
        CompanionWaitKey = -1
        SetKeyMapOptionValue(OID_CompanionWaitKey, CompanionWaitKey)
        ApplyHotkeySettings()

    elseif option == OID_AssignHomeKey
        AssignHomeKey = -1
        SetKeyMapOptionValue(OID_AssignHomeKey, AssignHomeKey)
        ApplyHotkeySettings()

    elseif option == OID_WheelMenuKey
        WheelMenuKey = -1
        SetKeyMapOptionValue(OID_WheelMenuKey, WheelMenuKey)
        ApplyWheelMenuSettings()

    elseif option == OID_ConfigMenuKey
        ConfigMenuKey = -1
        SetKeyMapOptionValue(OID_ConfigMenuKey, ConfigMenuKey)
        ApplyConfigMenuKeySettings()

    elseif option == OID_ArrestCooldown
        If ArrestScript
            ArrestScript.ArrestPlayerCooldown = 60.0
            SetSliderOptionValue(OID_ArrestCooldown, 60.0, "{0} sec")
        EndIf

    elseif option == OID_NPCArrestCooldown
        If ArrestScript
            ArrestScript.NPCArrestCooldown = 300.0
            SetSliderOptionValue(OID_NPCArrestCooldown, 300.0, "{0} sec")
        EndIf

    elseif option == OID_PersuasionTimeLimit
        If ArrestScript
            ArrestScript.PersuasionTimeLimit = 90.0
            SetSliderOptionValue(OID_PersuasionTimeLimit, 90.0, "{0} sec")
        EndIf

    ; Survival defaults
    elseif option == OID_SurvivalEnabled
        If SurvivalScript
            SurvivalScript.Enabled = true
            SetToggleOptionValue(OID_SurvivalEnabled, true)
            SurvivalScript.StartTracking()
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
            FollowerManagerScript.MaxFollowers = 20
            SetSliderOptionValue(OID_FM_MaxFollowers, 20.0, "{0}")
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
    elseif option == OID_FM_RelCooldown
        If FollowerManagerScript
            FollowerManagerScript.RelationshipCooldown = 120.0
            SetSliderOptionValue(OID_FM_RelCooldown, 120.0, "{0} sec")
        EndIf
    elseif option == OID_FM_OutfitLock
        If OutfitScript
            OutfitScript.OutfitLockEnabled = true
            SetToggleOptionValue(OID_FM_OutfitLock, true)
        EndIf
    elseif option == OID_FM_AutoSwitch
        SeverActionsNative.SituationMonitor_SetEnabled(true)
        StorageUtil.SetIntValue(None, "SeverOutfit_GlobalAutoSwitch", 1)
        SetToggleOptionValue(OID_FM_AutoSwitch, true)
    elseif option == OID_FM_StabilityDelay
        SeverActionsNative.SituationMonitor_SetStabilityThreshold(5000)
        SetSliderOptionValue(OID_FM_StabilityDelay, 5.0, "{0} sec")
    elseif option == OID_FM_PerActorAutoSwitch
        If CachedManagedFollowers && SelectedCompanionIdx < CachedManagedFollowers.Length
            Actor follower = CachedManagedFollowers[SelectedCompanionIdx]
            If follower
                SeverActionsNative.Native_Outfit_SetAutoSwitchEnabled(follower, true)
                StorageUtil.SetIntValue(follower, "SeverOutfit_AutoSwitch", 1)
                SetToggleOptionValue(OID_FM_PerActorAutoSwitch, true)
            EndIf
        EndIf
    elseif option == OID_Outfit_Lock
        If OutfitScript && CachedPresetActors
            If SelectedOutfitNPCIdx < CachedPresetActors.Length
                OutfitScript.SetNonFollowerOutfitLock(CachedPresetActors[SelectedOutfitNPCIdx], false)
                SetToggleOptionValue(OID_Outfit_Lock, false)
                If FollowerManagerScript
                    FollowerManagerScript.ClearOutfitSlot(CachedPresetActors[SelectedOutfitNPCIdx])
                EndIf
            EndIf
        EndIf
    elseif option == OID_FM_FrameworkMode
        If FollowerManagerScript
            FollowerManagerScript.FrameworkMode = 0
            SetMenuOptionValue(OID_FM_FrameworkMode, FrameworkModeOptions[0])
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
    elseif option == OID_FM_AutoAssessment
        If FollowerManagerScript
            FollowerManagerScript.AutoRelAssessment = true
            SetToggleOptionValue(OID_FM_AutoAssessment, true)
        EndIf
    elseif option == OID_FM_AssessCooldownMin
        If FollowerManagerScript
            FollowerManagerScript.AssessmentCooldownMinHours = 4.0
            SetSliderOptionValue(OID_FM_AssessCooldownMin, 4.0, "{1} hrs")
        EndIf
    elseif option == OID_FM_AssessCooldownMax
        If FollowerManagerScript
            FollowerManagerScript.AssessmentCooldownMaxHours = 10.0
            SetSliderOptionValue(OID_FM_AssessCooldownMax, 10.0, "{1} hrs")
        EndIf
    elseif option == OID_FM_AutoInterAssessment
        If FollowerManagerScript
            FollowerManagerScript.AutoInterFollowerAssessment = true
            SetToggleOptionValue(OID_FM_AutoInterAssessment, true)
        EndIf
    elseif option == OID_FM_InterAssessCooldownMin
        If FollowerManagerScript
            FollowerManagerScript.InterFollowerCooldownMinHours = 6.0
            SetSliderOptionValue(OID_FM_InterAssessCooldownMin, 6.0, "{1} hrs")
        EndIf
    elseif option == OID_FM_InterAssessCooldownMax
        If FollowerManagerScript
            FollowerManagerScript.InterFollowerCooldownMaxHours = 14.0
            SetSliderOptionValue(OID_FM_InterAssessCooldownMax, 14.0, "{1} hrs")
        EndIf
    elseif option == OID_FM_AutoOffScreenLife
        If FollowerManagerScript
            FollowerManagerScript.AutoOffScreenLife = true
            SetToggleOptionValue(OID_FM_AutoOffScreenLife, true)
        EndIf
    elseif option == OID_FM_OffScreenCooldownMin
        If FollowerManagerScript
            FollowerManagerScript.OffScreenLifeCooldownMinHours = 10.0
            SetSliderOptionValue(OID_FM_OffScreenCooldownMin, 10.0, "{1} hrs")
        EndIf
    elseif option == OID_FM_OffScreenCooldownMax
        If FollowerManagerScript
            FollowerManagerScript.OffScreenLifeCooldownMaxHours = 40.0
            SetSliderOptionValue(OID_FM_OffScreenCooldownMax, 40.0, "{1} hrs")
        EndIf
    elseif option == OID_FM_OffScreenConsequences
        If FollowerManagerScript
            FollowerManagerScript.OffScreenConsequences = false
            SetToggleOptionValue(OID_FM_OffScreenConsequences, false)
        EndIf
    elseif option == OID_FM_ConsequenceCooldown
        If FollowerManagerScript
            FollowerManagerScript.ConsequenceCooldownHours = 36.0
            SetSliderOptionValue(OID_FM_ConsequenceCooldown, 36.0, "{1} hrs")
        EndIf
    elseif option == OID_FM_MaxBounty
        If FollowerManagerScript
            FollowerManagerScript.MaxOffScreenBounty = 1000
            SetSliderOptionValue(OID_FM_MaxBounty, 1000.0, "{0}")
        EndIf
    elseif option == OID_FM_MaxGoldChange
        If FollowerManagerScript
            FollowerManagerScript.MaxOffScreenGoldChange = 500
            SetSliderOptionValue(OID_FM_MaxGoldChange, 500.0, "{0}")
        EndIf
    elseif option == OID_FM_DeathGracePeriod
        If FollowerManagerScript
            FollowerManagerScript.DeathGracePeriodHours = 4.0
            SetSliderOptionValue(OID_FM_DeathGracePeriod, 4.0, "{0} hrs")
        EndIf

    ; Per-follower relationship defaults
    else
        If FollowerManagerScript && CachedManagedFollowers
            Int j = 0
            While j < CachedManagedFollowers.Length && j < 20
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
        HotkeyScript.UpdateDismissKey(DismissKey)
        HotkeyScript.UpdateStandUpKey(StandUpKey)
        HotkeyScript.UpdateYieldKey(YieldKey)
        HotkeyScript.UpdateUndressKey(UndressKey)
        HotkeyScript.UpdateDressKey(DressKey)
        HotkeyScript.UpdateSetCompanionKey(SetCompanionKey)
        HotkeyScript.UpdateCompanionWaitKey(CompanionWaitKey)
        HotkeyScript.UpdateAssignHomeKey(AssignHomeKey)
        HotkeyScript.UpdateConfigMenuKey(ConfigMenuKey)

        ; Update other settings directly
        HotkeyScript.TargetMode = TargetMode
        HotkeyScript.NearestNPCRadius = NearestNPCRadius
        
        Debug.Trace("[SeverActions_MCM] Applied hotkey settings")
        Debug.Trace("[SeverActions_MCM]   FollowToggleKey: " + FollowToggleKey)
        Debug.Trace("[SeverActions_MCM]   DismissKey: " + DismissKey)
        Debug.Trace("[SeverActions_MCM]   StandUpKey: " + StandUpKey)
        Debug.Trace("[SeverActions_MCM]   YieldKey: " + YieldKey)
        Debug.Trace("[SeverActions_MCM]   UndressKey: " + UndressKey)
        Debug.Trace("[SeverActions_MCM]   DressKey: " + DressKey)
        Debug.Trace("[SeverActions_MCM]   SetCompanionKey: " + SetCompanionKey)
        Debug.Trace("[SeverActions_MCM]   CompanionWaitKey: " + CompanionWaitKey)
        Debug.Trace("[SeverActions_MCM]   AssignHomeKey: " + AssignHomeKey)
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

Function ApplyConfigMenuKeySettings()
    if HotkeyScript
        HotkeyScript.UpdateConfigMenuKey(ConfigMenuKey)
        Debug.Trace("[SeverActions_MCM] Applied config menu key: " + ConfigMenuKey)
    else
        Debug.Trace("[SeverActions_MCM] WARNING: HotkeyScript not set!")
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

    ; Sync prompt-accessible settings via StorageUtil
    StorageUtil.SetIntValue(None, "SeverActions_ZeroChance", SilenceChance)
    Debug.Trace("[SeverActions_MCM] Silence Chance: " + SilenceChance + "%")

    ; Sync spell teaching settings
    if !SpellTeachScript
        Quest myQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
        if myQuest
            SpellTeachScript = myQuest as SeverActions_SpellTeach
        endif
    endif
    if SpellTeachScript
        StorageUtil.SetIntValue(None, "SeverActions_SpellFailEnabled", SpellTeachScript.EnableFailureSystem as Int)
        StorageUtil.SetFloatValue(None, "SeverActions_SpellFailDifficulty", SpellTeachScript.FailureDifficultyMult)
        Debug.Trace("[SeverActions_MCM] Spell Fail Enabled: " + SpellTeachScript.EnableFailureSystem)
        Debug.Trace("[SeverActions_MCM] Spell Fail Difficulty: " + SpellTeachScript.FailureDifficultyMult + "x")
    endif

    ; Sync speaker tag settings
    StorageUtil.SetIntValue(None, "SeverActions_TagCompanion", TagCompanionEnabled as Int)
    StorageUtil.SetIntValue(None, "SeverActions_TagEngaged", TagEngagedEnabled as Int)
    StorageUtil.SetIntValue(None, "SeverActions_TagInScene", TagInSceneEnabled as Int)
    Debug.Trace("[SeverActions_MCM] Speaker Tags - Companion: " + TagCompanionEnabled + ", Engaged: " + TagEngagedEnabled + ", InScene: " + TagInSceneEnabled)

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