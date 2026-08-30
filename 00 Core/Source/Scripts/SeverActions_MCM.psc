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
SeverActions_ArrestBounty Property BountyScript Auto
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

; Mannequin renderer fallback (Outfits page) — when true, PrismaUI skips the
; mannequin bake and renders the viewport as a transparent cutout so the user
; can see the live NPC in the world. Read/written by the native settings
; gatherer/handler via GetProperty/SetProperty; no MCM page UI (PrismaUI owns it).
bool Property MannequinRenderDisabled = false Auto Hidden

; Followers auto-stand from furniture when the player walks this far away (0 =
; disabled). Lives here so it survives game restarts: the native FurnitureManager
; singleton holds only a volatile runtime copy, so PrismaUI writes BOTH this
; cosaved property and the singleton, and OnGameReload pushes this value back into
; the singleton on load. Default 500 mirrors the C++ default.
Float Property FurnitureAutoStandDistance = 500.0 Auto Hidden

; Situation-stability threshold for outfit auto-switching (Followers page
; slider, in seconds). Lives here so it survives game restarts: the native
; SituationMonitor threshold is RAM-only and resets to its C++ default on
; every launch, so the slider accept handler writes BOTH this cosaved
; property and the native value, and SyncAllSettings re-pushes it on load.
; Default 5.0 mirrors the slider default / C++ default.
Float Property FMStabilityDelay = 5.0 Auto Hidden

; Speaker Tag Toggles (stored here, synced to StorageUtil for prompt access)
bool Property TagCompanionEnabled = true Auto Hidden
bool Property TagEngagedEnabled = true Auto Hidden
bool Property TagInSceneEnabled = true Auto Hidden

; Inventory Limits (stored here + synced to StorageUtil for prompt access)
int Property InvLimit_Weapons = 10 Auto Hidden
int Property InvLimit_Armor = 10 Auto Hidden
int Property InvLimit_Potions = 10 Auto Hidden
int Property InvLimit_Ingredients = 5 Auto Hidden
int Property InvLimit_Books = 10 Auto Hidden
int Property InvLimit_Scrolls = 5 Auto Hidden
int Property InvLimit_Ammo = 5 Auto Hidden
int Property InvLimit_Keys = 5 Auto Hidden
int Property InvLimit_Misc = 5 Auto Hidden

; Hotkey Settings (stored here, applied to HotkeyScript)
int Property FollowToggleKey = -1 Auto Hidden
int Property DismissKey = -1 Auto Hidden
int Property StandUpKey = -1 Auto Hidden
int Property UseFurnitureKey = -1 Auto Hidden
int Property YieldKey = -1 Auto Hidden
int Property UndressKey = -1 Auto Hidden
int Property DressKey = -1 Auto Hidden
int Property SetCompanionKey = -1 Auto Hidden
int Property CompanionWaitKey = -1 Auto Hidden
int Property AssignHomeKey = -1 Auto Hidden
int Property ClearHomeKey = -1 Auto Hidden
int Property SetupCampKey = -1 Auto Hidden
int Property DropMarkerKey = -1 Auto Hidden
int Property TieUntieKey = -1 Auto Hidden
int Property TargetMode = 0 Auto Hidden
float Property NearestNPCRadius = 500.0 Auto Hidden

; Wheel Menu Settings (stored here, applied to WheelMenuScript)
int Property WheelMenuKey = -1 Auto Hidden

; Config Menu Key (opens PrismaUI config — stored here, applied to HotkeyScript)
int Property ConfigMenuKey = -1 Auto Hidden
bool Property ConfigMenuRequireShift = true Auto Hidden

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
int OID_UseFurnitureKey
int OID_YieldKey
int OID_UndressKey
int OID_DressKey
int OID_SetCompanionKey
int OID_CompanionWaitKey
int OID_AssignHomeKey
int OID_ClearHomeKey
int OID_SetupCampKey
int OID_DropMarkerKey
int OID_TieUntieKey
int OID_TargetMode
int OID_NearestNPCRadius
int OID_WheelMenuKey
int OID_ConfigMenuKey
int OID_ConfigMenuShift

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
int OID_PersuasionTimeLimit

; General page - PrismaUI escape hatch
int OID_UIScale

; General page - Native DLL toggles
int OID_LLMCallsEnabled
int OID_TruceEnabled
int OID_TruceRadius
int OID_TruceLeaders
int OID_TruceQuestNPCs
int OID_TruceDungeons
int OID_TruceNecro
int OID_TruceForsworn
int OID_TruceVampires
int OID_CampTakeover
int OID_CampChallenge
int OID_CampChallengeCard
int OID_ChallengeParleySeconds
int OID_CampFreezeRespawn
int OID_YieldPersistence
int OID_CombatCooldown
int OID_DebuffSeverity
int OID_SurvNotifHunger
int OID_SurvNotifFatigue
int OID_SurvNotifCold
int OID_ArrestBountyThreshold
int OID_BribeMult
int OID_ResistBounty
int OID_DebtOverdue
int OID_DebtGrace
int OID_DebtReport
int OID_TravelMapMarkers
int OID_FollowersCanTravel
int OID_Outfit_UseAnimations
int OID_FM_AutoQuestAwareness
int OID_FM_AutoNPCReputation
int OID_FM_AutoFollowerBanter
int OID_FM_AutoAmbientActions
int OID_FM_SchedWorkStart
int OID_FM_SchedWorkEnd
int OID_FM_SchedPlayStart
int OID_FM_SchedPlayEnd
int OID_FM_HomeSleepEnabled
int OID_FM_HomeSleepStart
int OID_FM_HomeSleepEnd
int OID_FM_TeleportDist
int OID_FM_TeleportCooldown
int OID_FM_CellCatchup
int OID_Ent_Loans
int OID_Ent_Raises
int OID_Ent_Ambushes
int OID_Ent_Temper
int OID_Ent_RenownCap
int OID_Ent_StoryCap
int OID_Ent_OutputPct
int OID_DialogueAnimEnabled
int OID_IntimacyEnabled
int OID_IntimacyGenderGate
int OID_SilenceChance
int OID_BookReadMode

; General page - Inventory Limits (per-category)
int OID_InvLimit_Weapons
int OID_InvLimit_Armor
int OID_InvLimit_Potions
int OID_InvLimit_Ingredients
int OID_InvLimit_Books
int OID_InvLimit_Scrolls
int OID_InvLimit_Ammo
int OID_InvLimit_Keys
int OID_InvLimit_Misc

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
int OID_FM_AllowLeaving
int OID_FM_RoomRotation
int OID_FM_KidnapEnabled
int OID_FM_RestrainEnabled
int OID_FM_LeavingThreshold
int OID_FM_Notifications
int OID_FM_Debug
int OID_FM_RelCooldown
; The outfit-lock toggle lives ONLY on the PrismaUI Outfits page — an MCM copy
; would duplicate it across three surfaces with inconsistent defaults and, with
; no write-through to the global settings file, silently revert on load.
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
int OID_FM_AutoAmbientBanter
int OID_FM_AmbientBanterCooldownMin
int OID_FM_AmbientBanterCooldownMax
int OID_FM_QuestAwarenessOutputCap
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

; NPC Homes section (Homes page)
int[] OID_ClearNPCHome
Actor[] CachedHomedNPCs

; Dismissed NPCs section (Homes page)
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
string[] IntimacyGenderOptions

; Companion selector
int OID_FM_CompanionSelect
int SelectedCompanionIdx = 0

; Page names
string PAGE_INTERFACE = "Interface"
string PAGE_HOTKEYS = "Hotkeys"
string PAGE_PROMPTS = "Prompt Filters"
string PAGE_FOLLOWERS = "Followers"
string PAGE_HOMES = "Homes"
string PAGE_OFFSCREEN = "Off-Screen Life"
string PAGE_OUTFITS = "Outfits"
string PAGE_SURVIVAL = "Survival"
string PAGE_COMBAT = "Combat && Outlaws"
string PAGE_BOUNTY = "Crime && Bounty"
string PAGE_ECONOMY = "Economy"
string PAGE_ENTERPRISES = "Enterprises"
string PAGE_TRAVEL = "Travel"
string PAGE_READING = "Reading && Spells"
string PAGE_BIOBLOCKS = "Bio Blocks"

; Gate for the Enterprises debug harness. The project docs (ENTERPRISES.md)
; say the debug page must not ship in a public release, so the Enterprises
; page only draws the debug controls while this is toggled on. Cosaved.
bool Property EnableEnterpriseDebug = false Auto

; --- Enterprises (Debug) page — temporary harness for the off-screen
;     labor/economy simulation. See ENTERPRISES.md. ---
int OID_Ent_DebugToggle
int OID_Ent_Target
int OID_Ent_Job
int OID_Ent_Arrangement
int OID_Ent_Wage
int OID_Ent_Hire
int OID_Ent_Remove
int OID_Ent_Settle
int OID_Ent_Dump
int OID_Ent_Count
int OID_Ent_Enabled
int OID_Ent_Collect
int OID_Ent_CollectAll
int OID_Ent_Bail
int OID_Ent_ForceArrest
int OID_Ent_TestLetter
int OID_Ent_TestCourier
int OID_Ent_TestCourierLLM
int OID_Ent_ForceAmbush
int EntJob = 0
int EntArrangement = 0
int EntWage = 200
bool EntEnabled = true
string[] EntJobOptions
string[] EntArrangementOptions

; Outfits page OIDs
int OID_Outfit_NPCSelect
int OID_Outfit_Lock
int[] OID_Outfit_DeletePreset
int OID_Outfit_DeferBondage
String[] CachedOutfitPresetNames
Actor[] CachedPresetActors
int SelectedOutfitNPCIdx = 0

; Target mode options
string[] TargetModeOptions

; Bio Blocks (VR) page OIDs + cached library state
int OID_Bio_Target
int OID_Bio_Tab
int OID_Bio_Block
int OID_Bio_Apply
int OID_Bio_GrantFaction
int OID_Bio_RemoveBlock
int[] OID_Bio_Rule
string[] BioTabs
int BioTabIdx = 0
string[] BioBlockTitles
int[] BioBlockIds
int BioBlockIdx = 0
Actor BioTargetActor
string[] BioAssignedTitles
int[] BioAssignedIds
string[] BioTargetFactions
string[] BioRuleNames

; =============================================================================
; INITIALIZATION
; =============================================================================

Int Function GetVersion()
    {Override SKI_ConfigBase. SkyUI compares this against the saved version
     to trigger OnVersionUpdate. Increment when MCM structure changes.}
    Return 123
EndFunction

Event OnConfigInit()
    ModName = "SeverActions"

    ; Set current version - increment this when you make MCM changes
    ; Format: major * 100 + minor (e.g., 107 = version 1.07)
    CurrentVersion = 124

    Pages = new string[15]
    Pages[0] = PAGE_INTERFACE
    Pages[1] = PAGE_HOTKEYS
    Pages[2] = PAGE_PROMPTS
    Pages[3] = PAGE_FOLLOWERS
    Pages[4] = PAGE_OFFSCREEN
    Pages[5] = PAGE_OUTFITS
    Pages[6] = PAGE_SURVIVAL
    Pages[7] = PAGE_COMBAT
    Pages[8] = PAGE_BOUNTY
    Pages[9] = PAGE_ECONOMY
    Pages[10] = PAGE_ENTERPRISES
    Pages[11] = PAGE_TRAVEL
    Pages[12] = PAGE_READING
    Pages[13] = PAGE_HOMES
    Pages[14] = PAGE_BIOBLOCKS

    InitEnterpriseDropdowns()

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
    FrameworkModeOptions = new string[2]
    FrameworkModeOptions[0] = "SeverActions"
    FrameworkModeOptions[1] = "Tracking"

    ; Initialize book reading mode dropdown options
    BookReadModeOptions = new string[2]
    BookReadModeOptions[0] = "Read Aloud (Verbatim)"
    BookReadModeOptions[1] = "Summarize & React"

    ; Register for PrismaUI inventory sync event
    RegisterForModEvent("SeverActions_SyncInvLimits", "OnSyncInvLimits")

    ; Make sure the Enterprises courier-letter event is registered. The handler
    ; lives on SeverActions_Travel, whose OnPlayerLoadGame is unreliable on churned
    ; saves; the MCM's lifecycle is reliable, so kick the registration from here.
    If TravelScript != None
        TravelScript.EnsureCourierEvents()
    EndIf
EndEvent

Event OnGameReload()
    parent.OnGameReload()
    ; Re-assert the courier-letter registration on every load (see OnConfigInit).
    If TravelScript != None
        TravelScript.EnsureCourierEvents()
    EndIf
    ; Restore the cosaved furniture auto-stand distance into the native singleton,
    ; which only keeps a volatile runtime copy (resets to its C++ default on boot).
    SeverActionsNative.SetDefaultAutoStandDistance(FurnitureAutoStandDistance)
EndEvent

; Called by PrismaUI (via ModEvent) after writing inventory limit properties
; Syncs MCM properties → StorageUtil so prompt templates can read them
Event OnSyncInvLimits(string eventName, string strArg, float numArg, Form sender)
    StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Weapons", InvLimit_Weapons)
    StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Armor", InvLimit_Armor)
    StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Potions", InvLimit_Potions)
    StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Ingredients", InvLimit_Ingredients)
    StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Books", InvLimit_Books)
    StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Scrolls", InvLimit_Scrolls)
    StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Ammo", InvLimit_Ammo)
    StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Keys", InvLimit_Keys)
    StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Misc", InvLimit_Misc)
EndEvent

Event OnVersionUpdate(int newVersion)
    ; Called when CurrentVersion is higher than saved version
    Debug.Trace("[SeverActions_MCM] Updating from version " + CurrentVersion + " to " + newVersion)

    ; Force page rebuild on any version change
    Pages = new string[15]
    Pages[0] = PAGE_INTERFACE
    Pages[1] = PAGE_HOTKEYS
    Pages[2] = PAGE_PROMPTS
    Pages[3] = PAGE_FOLLOWERS
    Pages[4] = PAGE_OFFSCREEN
    Pages[5] = PAGE_OUTFITS
    Pages[6] = PAGE_SURVIVAL
    Pages[7] = PAGE_COMBAT
    Pages[8] = PAGE_BOUNTY
    Pages[9] = PAGE_ECONOMY
    Pages[10] = PAGE_ENTERPRISES
    Pages[11] = PAGE_TRAVEL
    Pages[12] = PAGE_READING
    Pages[13] = PAGE_HOMES
    Pages[14] = PAGE_BIOBLOCKS

    InitEnterpriseDropdowns()

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
    FrameworkModeOptions = new string[2]
    FrameworkModeOptions[0] = "SeverActions"
    FrameworkModeOptions[1] = "Tracking"

    ; Re-initialize book reading mode dropdown options
    BookReadModeOptions = new string[2]
    BookReadModeOptions[0] = "Read Aloud (Verbatim)"
    BookReadModeOptions[1] = "Summarize & React"
EndEvent

; Get singleton instance
SeverActions_MCM Function GetInstance() Global
    return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_MCM
EndFunction

; =============================================================================
; PAGE LAYOUT
; =============================================================================

Event OnPageReset(string page)
    SetCursorFillMode(TOP_TO_BOTTOM)

    if page == "" || page == PAGE_INTERFACE
        DrawInterfacePage()
    elseif page == PAGE_HOTKEYS
        DrawHotkeysPage()
    elseif page == PAGE_PROMPTS
        DrawPromptFiltersPage()
    elseif page == PAGE_FOLLOWERS
        DrawFollowersPage()
    elseif page == PAGE_OFFSCREEN
        DrawOffScreenPage()
    elseif page == PAGE_OUTFITS
        DrawOutfitsPage()
    elseif page == PAGE_SURVIVAL
        DrawSurvivalPage()
    elseif page == PAGE_COMBAT
        DrawCombatPage()
    elseif page == PAGE_BOUNTY
        DrawCrimePage()
    elseif page == PAGE_ECONOMY
        DrawEconomyPage()
    elseif page == PAGE_ENTERPRISES
        If EnableEnterpriseDebug
            DrawEnterprisesDebugPage()
        Else
            DrawEnterprisesPage()
        EndIf
    elseif page == PAGE_TRAVEL
        DrawTravelPage()
    elseif page == PAGE_READING
        DrawReadingPage()
    elseif page == PAGE_HOMES
        DrawHomesPage()
    elseif page == PAGE_BIOBLOCKS
        DrawBioBlocksPage()
    endif
EndEvent

; =============================================================================
; BIO BLOCKS (VR) PAGE — apply/remove Bio Blocks without PrismaUI.
; Author blocks in PrismaUI (or the library JSON); this page only assigns them.
; Drives the Native_BioBlock_* natives on SeverActionsNativeExt2.
; =============================================================================

Function DrawBioBlocksPage()
    AddHeaderOption("Bio Blocks")
    AddTextOption("", "Aim at an NPC, pick a block, then Apply.")
    AddTextOption("", "Write the blocks themselves in PrismaUI.")

    BioTabs = SeverActionsNativeExt2.Native_BioBlock_TabList()
    If !BioTabs || BioTabs.Length == 0
        AddEmptyOption()
        AddTextOption("", "No bio blocks exist yet.")
        AddTextOption("", "Create some in PrismaUI first.")
        Return
    EndIf
    If BioTabIdx < 0 || BioTabIdx >= BioTabs.Length
        BioTabIdx = 0
    EndIf
    String curTab = BioTabs[BioTabIdx]
    BioBlockTitles = SeverActionsNativeExt2.Native_BioBlock_BlockTitlesInTab(curTab)
    BioBlockIds = SeverActionsNativeExt2.Native_BioBlock_BlockIdsInTab(curTab)
    ; Guard the EMPTY (length-0) array too, not just None: a tab with no blocks
    ; (the shipped default library's first tab "Library" is empty) returns a
    ; non-None length-0 array, and the unguarded BioBlockTitles[BioBlockIdx]
    ; reads below would go out of bounds on first open.
    If !BioBlockTitles || BioBlockTitles.Length == 0
        BioBlockTitles = new string[1]
        BioBlockTitles[0] = ""
    EndIf
    If BioBlockIdx < 0 || BioBlockIdx >= BioBlockTitles.Length
        BioBlockIdx = 0
    EndIf

    BioTargetActor = Game.GetCurrentCrosshairRef() as Actor
    String tname = "(none - aim at an NPC)"
    If BioTargetActor
        tname = BioTargetActor.GetDisplayName()
    EndIf
    OID_Bio_Target = AddTextOption("Crosshair Target", tname)

    OID_Bio_Tab = AddMenuOption("Tab", curTab)
    String blabel = "(no blocks in this tab)"
    If BioBlockTitles.Length > 0 && BioBlockTitles[BioBlockIdx] != ""
        blabel = BioBlockTitles[BioBlockIdx]
    EndIf
    OID_Bio_Block = AddMenuOption("Block", blabel)

    ; One gate for Apply and Grant: needs a crosshair target AND a real
    ; (non-empty) selected block. BioBlockTitles is length >= 1 by here.
    Int gateFlags = OPTION_FLAG_NONE
    If !BioTargetActor || BioBlockTitles[BioBlockIdx] == ""
        gateFlags = OPTION_FLAG_DISABLED
    EndIf
    OID_Bio_Apply = AddTextOption("Apply to Target", "CLICK", gateFlags)
    OID_Bio_GrantFaction = AddMenuOption("Grant to a Faction", "select...", gateFlags)

    AddHeaderOption("On This Target")
    OID_Bio_RemoveBlock = -1
    If BioTargetActor
        BioAssignedTitles = SeverActionsNativeExt2.Native_BioBlock_AssignedTitles(BioTargetActor)
        BioAssignedIds = SeverActionsNativeExt2.Native_BioBlock_AssignedIds(BioTargetActor)
        If BioAssignedTitles && BioAssignedTitles.Length > 0
            OID_Bio_RemoveBlock = AddMenuOption("Remove a Block", "select...")
            Int a = 0
            While a < BioAssignedTitles.Length
                AddTextOption("  - " + BioAssignedTitles[a], "")
                a += 1
            EndWhile
        Else
            AddTextOption("", "(nothing applied to this NPC)")
        EndIf
    Else
        AddTextOption("", "(aim at an NPC to manage its blocks)")
    EndIf

    AddHeaderOption("Faction Rules")
    AddTextOption("", "Each rule grants a block to a whole faction.")
    BioRuleNames = SeverActionsNativeExt2.Native_BioBlock_FactionRuleNames()
    OID_Bio_Rule = new int[20]
    If BioRuleNames && BioRuleNames.Length > 0
        Int r = 0
        While r < BioRuleNames.Length && r < 20
            OID_Bio_Rule[r] = AddTextOption(BioRuleNames[r], "remove")
            r += 1
        EndWhile
    Else
        AddTextOption("", "(no faction rules)")
    EndIf
EndFunction

; =============================================================================
; ENTERPRISES (DEBUG) PAGE — temporary harness for the Enterprises simulation.
; See ENTERPRISES.md. Drives the Venture_* natives on SeverActionsNativeExt.
; =============================================================================

Function InitEnterpriseDropdowns()
    ; Order matters: the selected index is passed straight to
    ; Venture_DebugAdd(entT, EntJob, EntArrangement, EntWage), so these map
    ; 1:1 to the VentureJob / VentureArrangement enums in VentureStore.h.
    EntJobOptions = new string[14]
    EntJobOptions[0] = "Miner"
    EntJobOptions[1] = "Merchant"
    EntJobOptions[2] = "Alchemist"
    EntJobOptions[3] = "Farmer"
    EntJobOptions[4] = "Fence"
    EntJobOptions[5] = "Mercenary"
    EntJobOptions[6] = "Courtesan"
    EntJobOptions[7] = "Guard"
    EntJobOptions[8] = "Lumberjack"
    EntJobOptions[9] = "Custom"
    EntJobOptions[10] = "Blacksmith"
    EntJobOptions[11] = "Hunter"
    EntJobOptions[12] = "Brewer"
    EntJobOptions[13] = "Tanner"
    EntArrangementOptions = new string[5]
    EntArrangementOptions[0] = "Employed (you pay wage)"
    EntArrangementOptions[1] = "Partnership (you get cut)"
    EntArrangementOptions[2] = "Tribute (they pay you cut)"
    EntArrangementOptions[3] = "Sworn (wage, no production)"
    EntArrangementOptions[4] = "Enslaved (coerced, no wage)"
EndFunction

; Main Enterprises page (public). The simulation is driven from the PrismaUI
; Enterprises board; the only MCM control here is the gate for the debug
; harness below.
Function DrawEnterprisesPage()
    SetCursorFillMode(TOP_TO_BOTTOM)
    AddHeaderOption("Enterprises")
    AddTextOption("", "Retainers are hired & managed from the")
    AddTextOption("", "PrismaUI Enterprises board.")

    If FollowerManagerScript
        AddEmptyOption()
        AddHeaderOption("Economy")
        OID_Ent_OutputPct = AddSliderOption("Venture Output", FollowerManagerScript.EnterpriseOutputPct as Float, "{0}%")
        OID_Ent_StoryCap = AddSliderOption("Weekly Story Budget", FollowerManagerScript.EnterpriseStoryCap as Float, "{0}")
        AddTextOption("", "Story budget: -1 = Auto, 0 = Off, else per week.")

        AddEmptyOption()
        AddHeaderOption("Retainer Systems")
        OID_Ent_Loans = AddToggleOption("Loans", FollowerManagerScript.EnterpriseLoansEnabled)
        OID_Ent_Raises = AddToggleOption("Wage Raises", FollowerManagerScript.EnterpriseRaisesEnabled)
        OID_Ent_Temper = AddToggleOption("Temper / Morale", FollowerManagerScript.EnterpriseTemperEnabled)
        OID_Ent_Ambushes = AddToggleOption("Grudge Ambushes", FollowerManagerScript.EnterpriseAmbushesEnabled)
        OID_Ent_RenownCap = AddToggleOption("Renown Roster Cap", FollowerManagerScript.EnterpriseRenownCapEnabled)
    EndIf

    AddEmptyOption()
    AddHeaderOption("Advanced")
    OID_Ent_DebugToggle = AddToggleOption("Enable Debug Harness", EnableEnterpriseDebug)
EndFunction

Function DrawEnterprisesDebugPage()
    If !EntJobOptions
        InitEnterpriseDropdowns()
    EndIf

    OID_Ent_DebugToggle = AddToggleOption("Enable Debug Harness", EnableEnterpriseDebug)
    AddHeaderOption("Enterprises - Debug Harness")
    AddTextOption("", "Aim your crosshair at an NPC, pick a")
    AddTextOption("", "job/arrangement, then Hire.")

    Actor target = Game.GetCurrentCrosshairRef() as Actor
    string tname = "(none - aim at an NPC)"
    If target
        tname = target.GetDisplayName()
    EndIf
    OID_Ent_Target = AddTextOption("Crosshair Target", tname)

    OID_Ent_Job         = AddMenuOption("Job", EntJobOptions[EntJob])
    OID_Ent_Arrangement = AddMenuOption("Arrangement", EntArrangementOptions[EntArrangement])
    OID_Ent_Wage        = AddSliderOption("Weekly Wage (Employed)", EntWage as Float, "{0}g")

    OID_Ent_Hire   = AddTextOption("Hire Retainer", "")
    OID_Ent_Remove = AddTextOption("Remove Retainer", "")

    AddHeaderOption("Simulation")
    OID_Ent_Count   = AddTextOption("Active Ventures", "" + SeverActionsNativeExt2.Venture_Count())
    OID_Ent_Settle  = AddTextOption("Force Weekly Settle", "")
    OID_Ent_Dump    = AddTextOption("Dump All To Log", "")
    OID_Ent_Enabled = AddToggleOption("Auto Settlement Enabled", EntEnabled)

    AddHeaderOption("Collect")
    OID_Ent_Collect    = AddTextOption("Collect From Target", "")
    OID_Ent_CollectAll = AddTextOption("Collect From All", "")

    AddHeaderOption("Law")
    OID_Ent_ForceArrest = AddTextOption("Force Arrest Target", "")
    OID_Ent_Bail        = AddTextOption("Bail Out Target", "")

    AddHeaderOption("Letters (Debug)")
    OID_Ent_TestLetter     = AddTextOption("Deliver Test Letter", "" + SeverActionsNativeExt.Letter_Count() + " archived")
    OID_Ent_TestCourier    = AddTextOption("Dispatch Courier (canned)", "walks up & hands over")
    OID_Ent_TestCourierLLM = AddTextOption("Send Real Letter (LLM)", "a retainer writes one")
    OID_Ent_ForceAmbush    = AddTextOption("Force Thug Ambush", "grudge thugs attack now")
EndFunction

; =============================================================================
; OUTFITS PAGE
; =============================================================================

Function DrawOutfitsPage()
    If !OutfitScript
        AddTextOption("", "Outfit system not connected!")
        return
    EndIf

    ; --- Global outfit behaviour (moved here from the Followers page) ---
    AddHeaderOption("Global Settings")
    OID_Outfit_UseAnimations = AddToggleOption("Dress/Undress Animations", OutfitScript.UseAnimations)
    OID_FM_AutoSwitch = AddToggleOption("Situational Auto-Switching", SeverActionsNativeExt.SituationMonitor_IsEnabled())
    OID_FM_StabilityDelay = AddSliderOption("Situation Stability", (SeverActionsNativeExt.SituationMonitor_GetStabilityThreshold() as Float) / 1000.0, "{0} sec")
    Bool deferBondage = StorageUtil.GetIntValue(None, "SeverOutfit_DeferBondage", 1) as Bool
    OID_Outfit_DeferBondage = AddToggleOption("Defer to Bondage Mods (DOM/PAH)", deferBondage)
    AddEmptyOption()

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

Function DrawInterfacePage()
    SetCursorFillMode(TOP_TO_BOTTOM)

    AddHeaderOption("SeverActions")
    AddEmptyOption()
    OID_Version = AddTextOption("Version", "3.x")
    AddTextOption("Author", "Severause")
    AddEmptyOption()

    ; PrismaUI escape hatch — if Prisma renders too large to reach the in-app
    ; scale slider, MCM is the fallback (source of truth: FollowerManager.UIScale).
    AddHeaderOption("PrismaUI Display")
    Float curScale = 1.0
    If FollowerManagerScript
        curScale = FollowerManagerScript.UIScale
    EndIf
    OID_UIScale = AddSliderOption("UI Scale", curScale, "{2}x")

    AddEmptyOption()
    AddHeaderOption("Dialogue")
    OID_DialogueAnimEnabled = AddToggleOption("Dialogue Animations", DialogueAnimEnabled)
    OID_SilenceChance = AddSliderOption("Silence Chance", SilenceChance as Float, "{0}%")

    AddEmptyOption()
    AddHeaderOption("Speaker Tags")
    OID_TagCompanion = AddToggleOption("[COMPANION] Tag", TagCompanionEnabled)
    OID_TagEngaged = AddToggleOption("[ENGAGED] Tag", TagEngagedEnabled)
    OID_TagInScene = AddToggleOption("[IN SCENE] Tag", TagInSceneEnabled)

    AddEmptyOption()
    AddHeaderOption("Background AI")
    ; Master kill-switch for every BACKGROUND LLM call SeverActions makes
    ; (assessments, banter, stories, letters, quest summaries, intimacy read).
    ; Does NOT touch SkyrimNet's own dialogue. Per-feature toggles are on the
    ; Followers page.
    Bool llmOn = SeverActionsNativeExt2.Native_GetLLMCallsEnabled()
    OID_LLMCallsEnabled = AddToggleOption("Background AI Calls", llmOn)
    AddTextOption("", "Off = no LLM cost from background features.")
EndFunction

Function DrawPromptFiltersPage()
    SetCursorFillMode(TOP_TO_BOTTOM)

    AddHeaderOption("Player Inventory Display")
    AddTextOption("", "How many of each item type the AI is")
    AddTextOption("", "told the player is carrying.")
    AddEmptyOption()
    OID_InvLimit_Weapons = AddSliderOption("Weapons", InvLimit_Weapons as Float, "{0} items")
    OID_InvLimit_Armor = AddSliderOption("Armor & Jewelry", InvLimit_Armor as Float, "{0} items")
    OID_InvLimit_Potions = AddSliderOption("Potions", InvLimit_Potions as Float, "{0} items")
    OID_InvLimit_Ingredients = AddSliderOption("Ingredients", InvLimit_Ingredients as Float, "{0} items")
    OID_InvLimit_Books = AddSliderOption("Books", InvLimit_Books as Float, "{0} items")
    OID_InvLimit_Scrolls = AddSliderOption("Scrolls", InvLimit_Scrolls as Float, "{0} items")
    OID_InvLimit_Ammo = AddSliderOption("Ammo", InvLimit_Ammo as Float, "{0} items")
    OID_InvLimit_Keys = AddSliderOption("Keys", InvLimit_Keys as Float, "{0} items")
    OID_InvLimit_Misc = AddSliderOption("Misc", InvLimit_Misc as Float, "{0} items")
EndFunction

Function DrawReadingPage()
    SetCursorFillMode(TOP_TO_BOTTOM)

    AddHeaderOption("Book Reading")
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
    else
        AddTextOption("", "Loot script not connected.")
    endif

    AddEmptyOption()
    AddHeaderOption("Spell Teaching")
    if !SpellTeachScript
        Quest myQuest2 = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
        if myQuest2
            SpellTeachScript = myQuest2 as SeverActions_SpellTeach
        endif
    endif
    if SpellTeachScript
        OID_SpellFailEnabled = AddToggleOption("Failure System", SpellTeachScript.EnableFailureSystem)
        OID_SpellFailDifficulty = AddSliderOption("Failure Difficulty", SpellTeachScript.FailureDifficultyMult, "{1}x")
    else
        AddTextOption("", "Spell-teach script not connected.")
    endif
EndFunction

Function DrawOffScreenPage()
    SetCursorFillMode(TOP_TO_BOTTOM)

    AddHeaderOption("Off-Screen Life")
    AddTextOption("", "What dismissed companions get up to")
    AddTextOption("", "when you are not around.")
    AddEmptyOption()

    If FollowerManagerScript
        AddHeaderOption("Events")
        OID_FM_AutoOffScreenLife = AddToggleOption("Off-Screen Life Events", FollowerManagerScript.AutoOffScreenLife)
        OID_FM_OffScreenCooldownMin = AddSliderOption("Off-Screen Min Cooldown", FollowerManagerScript.OffScreenLifeCooldownMinHours, "{1} hrs")
        OID_FM_OffScreenCooldownMax = AddSliderOption("Off-Screen Max Cooldown", FollowerManagerScript.OffScreenLifeCooldownMaxHours, "{1} hrs")

        AddEmptyOption()
        AddHeaderOption("Consequences")
        OID_FM_OffScreenConsequences = AddToggleOption("Off-Screen Consequences", FollowerManagerScript.OffScreenConsequences)
        OID_FM_ConsequenceCooldown = AddSliderOption("Consequence Cooldown", FollowerManagerScript.ConsequenceCooldownHours, "{1} hrs")
        OID_FM_MaxBounty = AddSliderOption("Max Off-Screen Bounty", FollowerManagerScript.MaxOffScreenBounty as Float, "{0}")
        OID_FM_MaxGoldChange = AddSliderOption("Max Gold Change", FollowerManagerScript.MaxOffScreenGoldChange as Float, "{0}")
    Else
        AddTextOption("", "Follower Manager not connected!")
    EndIf
EndFunction

Function DrawCombatPage()
    SetCursorFillMode(TOP_TO_BOTTOM)

    If !CombatScript
        AddTextOption("", "Combat script not connected!")
        Return
    EndIf

    AddHeaderOption("Outlaw Truce")
    AddTextOption("", "Bandits & other outlaws hold their fire")
    AddTextOption("", "until provoked - so you can talk to them.")
    OID_TruceEnabled = AddToggleOption("Peaceful Until Provoked", CombatScript.TruceEnabled)
    OID_TruceRadius = AddSliderOption("Truce Reach", CombatScript.TruceRadius, "{0} units")
    OID_TruceLeaders = AddToggleOption("Include Camp Leaders", CombatScript.TruceLeaders)
    OID_TruceQuestNPCs = AddToggleOption("Include Quest Outlaws", CombatScript.TruceQuestNPCs)
    OID_TruceDungeons = AddToggleOption("Include Dungeon Outlaws", CombatScript.TruceDungeons)
    OID_TruceNecro = AddToggleOption("Include Necromancers", CombatScript.TruceNecromancers)
    OID_TruceForsworn = AddToggleOption("Include Forsworn", CombatScript.TruceForsworn)
    OID_TruceVampires = AddToggleOption("Include Vampires", CombatScript.TruceVampires)

    AddEmptyOption()
    AddHeaderOption("Outlaw Camps")
    OID_CampTakeover = AddToggleOption("Camp Takeover", CombatScript.CampTakeoverEnabled)
    OID_CampChallenge = AddToggleOption("Camp Challenge Encounter", CombatScript.CampChallengeEnabled)
    OID_CampChallengeCard = AddToggleOption("Show Challenge Card", CombatScript.CampChallengeCardEnabled)
    OID_ChallengeParleySeconds = AddSliderOption("Parley Time", CombatScript.ChallengeParleySeconds, "{0} sec")
    OID_CampFreezeRespawn = AddToggleOption("Freeze Sworn Camp Respawn", CombatScript.CampFreezeRespawn)

    AddEmptyOption()
    AddHeaderOption("Combat")
    OID_YieldPersistence = AddToggleOption("Persist Surrendered NPCs", CombatScript.YieldPersistenceEnabled)
    OID_CombatCooldown = AddSliderOption("Forced-Combat Cooldown", CombatScript.CombatCooldownDuration, "{0} sec")
EndFunction

Function DrawHotkeysPage()
    SetCursorFillMode(TOP_TO_BOTTOM)

    ; --- Config Menu (PrismaUI) ---
    AddHeaderOption("Config Menu (Requires PrismaUI)")
    OID_ConfigMenuKey = AddKeyMapOption("Open Config Menu", ConfigMenuKey)
    OID_ConfigMenuShift = AddToggleOption("Require Shift", ConfigMenuRequireShift)

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
    OID_ClearHomeKey = AddKeyMapOption("Clear Home (Target)", ClearHomeKey)
    OID_SetupCampKey = AddKeyMapOption("Set Up Camp (Hearth)", SetupCampKey)
    OID_DropMarkerKey = AddKeyMapOption("Drop Named Marker", DropMarkerKey)
    OID_TieUntieKey = AddKeyMapOption("Tie / Untie NPC", TieUntieKey)

    AddEmptyOption()
    AddHeaderOption("Furniture Hotkeys")
    OID_StandUpKey = AddKeyMapOption("Make NPC Stand Up", StandUpKey)
    OID_UseFurnitureKey = AddKeyMapOption("Use Furniture (NPC, then furniture)", UseFurnitureKey)

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

Function DrawEconomyPage()
    SetCursorFillMode(TOP_TO_BOTTOM)
    
    AddHeaderOption("Gold Settings")
    OID_AllowConjuredGold = AddToggleOption("Allow Conjured Gold", AllowConjuredGold)
    AddTextOption("", "When enabled, NPCs can give gold")
    AddTextOption("", "even if they don't have any.")
    AddEmptyOption()
    AddTextOption("", "Disable for more realistic economy")
    AddTextOption("", "where NPCs need actual gold to give.")

    AddEmptyOption()
    AddHeaderOption("Debt")
    If FollowerManagerScript && FollowerManagerScript.DebtScript
        OID_DebtOverdue = AddToggleOption("Overdue Reminders", FollowerManagerScript.DebtScript.EnableOverdueReminders)
        OID_DebtGrace = AddSliderOption("Overdue Grace", FollowerManagerScript.DebtScript.OverdueGracePeriodHours, "{0} hrs")
        OID_DebtReport = AddSliderOption("Report-to-Guards Delay", FollowerManagerScript.DebtScript.ReportThresholdHours, "{0} hrs")
    EndIf
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
    
    If TravelScript
        AddHeaderOption("Settings")
        OID_TravelMapMarkers = AddToggleOption("Objective Map Markers", TravelScript.TravelMapMarkersEnabled)
        OID_FollowersCanTravel = AddToggleOption("Followers Can Travel", SeverActionsNativeExt2.Native_GetFollowersCanTravel())
        AddEmptyOption()
    EndIf

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
        OID_ArrestBountyThreshold = AddSliderOption("Arrest Threshold", ArrestScript.ArrestBountyThreshold as Float, "{0}g")
        AddTextOption("", "Bounty at/above which a guard arrests (below = fine only).")
        OID_BribeMult = AddSliderOption("Bribe Multiplier", ArrestScript.BribeMultiplier, "{2}x")
        OID_ResistBounty = AddSliderOption("Resist-Arrest Penalty", ArrestScript.ResistBountyIncrease as Float, "{0}g")
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
    If !BountyScript
        Quest myQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
        If myQuest
            BountyScript = myQuest as SeverActions_ArrestBounty
        EndIf
    EndIf
    If BountyScript
        Int bounty = BountyScript.GetTrackedBounty(akCrimeFaction)
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
        AddHeaderOption("Penalties")
        OID_DebuffSeverity = AddSliderOption("Debuff Severity", SurvivalScript.DebuffSeverity, "{2}x")
        AddTextOption("", "0x = needs still tracked, but no penalties.")

        AddEmptyOption()
        AddHeaderOption("Notifications")
        OID_SurvivalNotifications = AddToggleOption("Show Notifications", SurvivalScript.ShowNotifications)
        OID_SurvNotifHunger = AddToggleOption("  Hunger Alerts", SurvivalScript.ShowHungerNotifications)
        OID_SurvNotifFatigue = AddToggleOption("  Fatigue Alerts", SurvivalScript.ShowFatigueNotifications)
        OID_SurvNotifCold = AddToggleOption("  Cold Alerts", SurvivalScript.ShowColdNotifications)
        OID_SurvivalDebug = AddToggleOption("Debug Mode", SurvivalScript.DebugMode)

        ; Per-follower tracking
        AddEmptyOption()
        AddHeaderOption("Follower Tracking")
        AddTextOption("", "Toggle survival for individual followers.")
        AddTextOption("", "Excluded followers won't get hungry/tired/cold.")

        ; When the master switch is off, these per-follower toggles do nothing
        ; (the update loop early-outs on !Enabled), so grey them out — the choices
        ; are preserved, just inactive until the system is turned back on.
        Int perFollowerFlags = 0
        If !SurvivalScript.Enabled
            perFollowerFlags = OPTION_FLAG_DISABLED
            AddTextOption("", "Survival system is OFF - toggles inactive.", OPTION_FLAG_DISABLED)
        EndIf

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
                    OID_FollowerExclude[j] = AddToggleOption(follower.GetDisplayName(), !isExcluded, perFollowerFlags)
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
        ; ── Roster ──────────────────────────────────────────────────────
        AddHeaderOption("Roster")
        OID_FM_MaxFollowers = AddSliderOption("Max Companions", FollowerManagerScript.MaxFollowers as Float, "{0}")
        OID_FM_AllowLeaving = AddToggleOption("Allow Autonomous Leaving", FollowerManagerScript.AllowAutonomousLeaving)
        OID_FM_LeavingThreshold = AddSliderOption("Leaving Threshold", FollowerManagerScript.LeavingThreshold, "{0}")
        OID_FM_RoomRotation = AddToggleOption("Home Room Rotation", FollowerManagerScript.RoomRotationEnabled)
        OID_FM_RelCooldown = AddSliderOption("Relationship Cooldown", FollowerManagerScript.RelationshipCooldown, "{0} sec")
        OID_FM_FrameworkMode = AddMenuOption("Recruitment Mode", FrameworkModeOptions[FollowerManagerScript.FrameworkMode])
        OID_FM_DeathGracePeriod = AddSliderOption("Death Cleanup Delay", FollowerManagerScript.DeathGracePeriodHours, "{0} hrs")
        OID_FM_Notifications = AddToggleOption("Show Notifications", FollowerManagerScript.ShowNotifications)
        OID_FM_Debug = AddToggleOption("Debug Mode", FollowerManagerScript.DebugMode)

        AddEmptyOption()
        AddHeaderOption("Restraint")
        OID_FM_KidnapEnabled = AddToggleOption("Enable Kidnap Actions", FollowerManagerScript.EnableKidnapActions)
        OID_FM_RestrainEnabled = AddToggleOption("Enable Restrain Action", FollowerManagerScript.EnableRestrainAction)

        AddEmptyOption()
        AddHeaderOption("Intimacy & Consent")
        OID_IntimacyEnabled = AddToggleOption("Intimacy && Consent Section", FollowerManagerScript.IntimateHistoryEnabled)
        If !IntimacyGenderOptions
            IntimacyGenderOptions = new string[3]
            IntimacyGenderOptions[0] = "Everyone"
            IntimacyGenderOptions[1] = "Women only"
            IntimacyGenderOptions[2] = "Men only"
        EndIf
        OID_IntimacyGenderGate = AddMenuOption("Show Intimacy Section For", IntimacyGenderOptions[FollowerManagerScript.IntimacyGenderGate])

        AddEmptyOption()
        AddHeaderOption("Relationship Assessment")
        OID_FM_AutoAssessment = AddToggleOption("Auto Relationship Assessment", FollowerManagerScript.AutoRelAssessment)
        OID_FM_AssessCooldownMin = AddSliderOption("Assessment Min Cooldown", FollowerManagerScript.AssessmentCooldownMinHours, "{1} hrs")
        OID_FM_AssessCooldownMax = AddSliderOption("Assessment Max Cooldown", FollowerManagerScript.AssessmentCooldownMaxHours, "{1} hrs")
        OID_FM_AutoInterAssessment = AddToggleOption("Inter-Follower Assessment", FollowerManagerScript.AutoInterFollowerAssessment)
        OID_FM_InterAssessCooldownMin = AddSliderOption("Inter-Follower Min Cooldown", FollowerManagerScript.InterFollowerCooldownMinHours, "{1} hrs")
        OID_FM_InterAssessCooldownMax = AddSliderOption("Inter-Follower Max Cooldown", FollowerManagerScript.InterFollowerCooldownMaxHours, "{1} hrs")

        AddEmptyOption()
        AddHeaderOption("Ambient Banter")
        OID_FM_AutoAmbientBanter = AddToggleOption("Ambient NPC Banter", FollowerManagerScript.AutoAmbientBanter)
        OID_FM_AmbientBanterCooldownMin = AddSliderOption("Ambient Banter Min Cooldown", FollowerManagerScript.AmbientBanterCooldownMinHours, "{1} hrs")
        OID_FM_AmbientBanterCooldownMax = AddSliderOption("Ambient Banter Max Cooldown", FollowerManagerScript.AmbientBanterCooldownMaxHours, "{1} hrs")

        AddEmptyOption()
        AddHeaderOption("Quest Awareness")
        OID_FM_AutoQuestAwareness = AddToggleOption("Quest Awareness Summaries", FollowerManagerScript.AutoQuestAwareness)
        OID_FM_QuestAwarenessOutputCap = AddSliderOption("Quest Awareness Entries", FollowerManagerScript.QuestAwarenessOutputCap as Float, "{0}")

        AddEmptyOption()
        AddHeaderOption("Background AI (per-feature)")
        OID_FM_AutoNPCReputation = AddToggleOption("NPC Reputation Blurbs", FollowerManagerScript.AutoNPCReputation)
        OID_FM_AutoFollowerBanter = AddToggleOption("Follower-to-Follower Banter", FollowerManagerScript.AutoFollowerBanter)
        OID_FM_AutoAmbientActions = AddToggleOption("Ambient Follower Actions", FollowerManagerScript.AutoAmbientActions)

        AddEmptyOption()
        AddHeaderOption("Schedule & Sleep")
        OID_FM_SchedWorkStart = AddSliderOption("Work Start", FollowerManagerScript.SCHEDULE_WORK_START, "{0}:00")
        OID_FM_SchedWorkEnd = AddSliderOption("Work End", FollowerManagerScript.SCHEDULE_WORK_END, "{0}:00")
        OID_FM_SchedPlayStart = AddSliderOption("Relax Start", FollowerManagerScript.SCHEDULE_PLAY_START, "{0}:00")
        OID_FM_SchedPlayEnd = AddSliderOption("Relax End", FollowerManagerScript.SCHEDULE_PLAY_END, "{0}:00")
        OID_FM_HomeSleepEnabled = AddToggleOption("Homed Followers Sleep", FollowerManagerScript.HomeSleepEnabled)
        OID_FM_HomeSleepStart = AddSliderOption("Sleep Start", FollowerManagerScript.HomeSleepStart, "{0}:00")
        OID_FM_HomeSleepEnd = AddSliderOption("Sleep End", FollowerManagerScript.HomeSleepEnd, "{0}:00")

        AddEmptyOption()
        AddHeaderOption("Movement")
        OID_FM_CellCatchup = AddToggleOption("Catch Up On Cell Load", FollowerManagerScript.CellCatchupEnabled)
        OID_FM_TeleportDist = AddSliderOption("Teleport-If-Behind Distance", FollowerManagerScript.FollowerTeleportDistance, "{0}")
        OID_FM_TeleportCooldown = AddSliderOption("Teleport Cooldown", FollowerManagerScript.TeleportCooldownSeconds as Float, "{0} sec")

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

                ; Outfit lock status (read-only). Phase 3: read from native —
                ; the StorageUtil mirror could drift behind C++ catalog writes
                ; that updated lockedItems without going through Papyrus.
                If SeverActionsNativeExt.Native_Outfit_IsLockActive(follower)
                    Form[] nativeLocked = SeverActionsNative.Native_Outfit_GetLockedItems(follower)
                    Int itemCount = 0
                    If nativeLocked
                        itemCount = nativeLocked.Length
                    EndIf
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

    Else
        AddTextOption("", "Follower Manager not connected!")
        AddTextOption("", "Set FollowerManagerScript property in CK.")
    EndIf
EndFunction

Function DrawHomesPage()
    {Home assignments + schedule/roster maintenance. Split off the Followers
     page (2026-08): the settings wall + companion list + these lists on one
     page exceeded SkyUI's ~128-option cap and truncated the bottom sections,
     so the home-clearing controls vanished (DZ report, 3.9.9). Also reachable
     from anywhere by the Clear Home (Target) hotkey.}
    SetCursorFillMode(TOP_TO_BOTTOM)
    If FollowerManagerScript
        AddHeaderOption("NPC Homes")
        CachedHomedNPCs = FollowerManagerScript.GetAllHomedNPCs()
        OID_ClearNPCHome = new int[50]
        If CachedHomedNPCs.Length > 0
            Int hh = 0
            While hh < CachedHomedNPCs.Length && hh < 50
                String homeLoc = FollowerManagerScript.GetAssignedHome(CachedHomedNPCs[hh])
                AddTextOption(CachedHomedNPCs[hh].GetDisplayName(), homeLoc, OPTION_FLAG_DISABLED)
                OID_ClearNPCHome[hh] = AddTextOption("Clear Home", "CLICK")
                hh += 1
            EndWhile
        Else
            AddTextOption("No custom homes assigned", "", OPTION_FLAG_DISABLED)
        EndIf

        ; --- Schedule Alias Pools (scheduling status) ---
        AddEmptyOption()
        AddHeaderOption("Schedule Alias Pools")
        If FollowerManagerScript.GetSchedMigrationDone()
            Int schedType = 0
            While schedType < 3
                Int used = FollowerManagerScript.GetSchedPoolUsed(schedType)
                String typeName = FollowerManagerScript.GetSchedTypeName(schedType)
                If FollowerManagerScript.GetSchedPoolExhausted(schedType)
                    AddTextOption(typeName + " aliases", used + " / 300 - FULL!", OPTION_FLAG_DISABLED)
                Else
                    AddTextOption(typeName + " aliases", used + " / 300", OPTION_FLAG_DISABLED)
                EndIf
                schedType += 1
            EndWhile
        Else
            AddTextOption("Legacy scheduling active", "upgrade pending", OPTION_FLAG_DISABLED)
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
    EndIf
EndFunction

; =============================================================================
; OPTION SELECTION
; =============================================================================

String Function BoolToStr(Bool b)
    {Write-through helper: format a bool as the "true"/"false" string the
     PrismaUI settings file + handler expect (Native_SettingsRecord).}
    If b
        Return "true"
    EndIf
    Return "false"
EndFunction

Event OnOptionSelect(int option)
    if option == OID_DialogueAnimEnabled
        DialogueAnimEnabled = !DialogueAnimEnabled
        SetToggleOptionValue(OID_DialogueAnimEnabled, DialogueAnimEnabled)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "dialogueAnimEnabled", BoolToStr(DialogueAnimEnabled))
        SeverActionsNative.SetDialogueAnimEnabled(DialogueAnimEnabled)

    elseif option == OID_IntimacyEnabled
        If FollowerManagerScript
            FollowerManagerScript.IntimateHistoryEnabled = !FollowerManagerScript.IntimateHistoryEnabled
            SetToggleOptionValue(OID_IntimacyEnabled, FollowerManagerScript.IntimateHistoryEnabled)
            ; Write through to the GLOBAL settings file with the same page/key
            ; PrismaUI uses - otherwise the load-time replay ("global file
            ; always wins") reverts this choice (the Tracking-reverts lesson).
            String ihVal = "false"
            If FollowerManagerScript.IntimateHistoryEnabled
                ihVal = "true"
            EndIf
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "intimacyEnabled", ihVal)
            ; Live-apply to the native store so SURFACING reacts now, not just
            ; recording (the property gates recording; the decorator's gate reads
            ; the native atomic). PrismaUI already does this. (PR #442 review)
            SeverActionsNativeExt2.Native_IntimateHistory_SetEnabled(FollowerManagerScript.IntimateHistoryEnabled)
        EndIf

    elseif option == OID_Ent_DebugToggle
        EnableEnterpriseDebug = !EnableEnterpriseDebug
        SetToggleOptionValue(OID_Ent_DebugToggle, EnableEnterpriseDebug)
        ForcePageReset()  ; swap between the public page and the debug harness
    elseif option == OID_Ent_Hire
        Actor entT = Game.GetCurrentCrosshairRef() as Actor
        If entT
            SeverActionsNativeExt2.Venture_DebugAdd(entT, EntJob, EntArrangement, EntWage)
        Else
            Debug.Notification("Enterprises: aim your crosshair at an NPC first.")
        EndIf
        ForcePageReset()
    elseif option == OID_Ent_Remove
        Actor entR = Game.GetCurrentCrosshairRef() as Actor
        If entR
            SeverActionsNativeExt2.Venture_DebugRemove(entR)
        EndIf
        ForcePageReset()
    elseif option == OID_Ent_Settle
        SeverActionsNativeExt2.Venture_ForceSettle()
        ForcePageReset()
    elseif option == OID_Ent_Dump
        SeverActionsNativeExt2.Venture_Dump()
    elseif option == OID_Ent_Collect
        Actor entC = Game.GetCurrentCrosshairRef() as Actor
        If entC
            SeverActionsNativeExt2.Venture_Collect(entC)
            ForcePageReset()
        Else
            Debug.Notification("Enterprises: aim your crosshair at a retainer first.")
        EndIf
    elseif option == OID_Ent_CollectAll
        SeverActionsNativeExt2.Venture_CollectAll()
        ForcePageReset()
    elseif option == OID_Ent_ForceArrest
        Actor entA = Game.GetCurrentCrosshairRef() as Actor
        If entA
            SeverActionsNativeExt2.Venture_ForceArrest(entA)
            ForcePageReset()
        Else
            Debug.Notification("Enterprises: aim your crosshair at a fence retainer first.")
        EndIf
    elseif option == OID_Ent_Bail
        Actor entB = Game.GetCurrentCrosshairRef() as Actor
        If entB
            SeverActionsNativeExt2.Venture_Bail(entB)
            ForcePageReset()
        Else
            Debug.Notification("Enterprises: aim your crosshair at a jailed retainer first.")
        EndIf
    elseif option == OID_Ent_TestLetter
        int letterId = SeverActionsNativeExt.Letter_DebugDeliverTest()
        If letterId > 0
            Debug.Notification("A courier's letter (#" + letterId + ") is in your inventory - read it.")
        Else
            Debug.Notification("Letter delivery failed - check the log.")
        EndIf
        ForcePageReset()
    elseif option == OID_Ent_TestCourier
        ; Bring a sample letter via a walking courier so the whole walk-up /
        ; handoff loop is testable. Pick one of the player's retainers at random
        ; as the sender so the courier names them (and the letter is attributed).
        Actor letterSender = None
        int retCount = SeverActionsNativeExt2.Venture_Count()
        If retCount > 0
            letterSender = SeverActionsNativeExt2.Venture_GetAssigneeAt(Utility.RandomInt(0, retCount - 1))
        EndIf
        String subj = "A Word, When You Can"
        String body = "I'll keep this short, since paper costs me what little I've got.\n\nThe work goes - not well, not poorly, just on. But there's a matter I'd rather put to you in person than trust to a courier's pocket. Come find me when your road bends back this way.\n\nDon't make me send another of these. They're dear."
        If TravelScript == None
            Debug.Notification("Courier system unavailable - check the log.")
        Else
            int dispatched = TravelScript.DispatchCourier(letterSender, subj, body, "meet")
            If dispatched > 0
                If letterSender != None
                    Debug.Notification("A courier is on the way with a letter from " + letterSender.GetDisplayName() + ".")
                Else
                    Debug.Notification("A courier is on the way with a letter (no retainers - unsigned).")
                EndIf
            Else
                Debug.Notification("Courier dispatch failed - check the log.")
            EndIf
        EndIf
    elseif option == OID_Ent_TestCourierLLM
        ; Force a REAL per-NPC letter: a random retainer writes one via the LLM,
        ; and a courier brings it when the model returns (a few seconds).
        int rc = SeverActionsNativeExt2.Venture_Count()
        If rc <= 0
            Debug.Notification("No retainers - hire one first.")
        Else
            Actor r = SeverActionsNativeExt2.Venture_GetAssigneeAt(Utility.RandomInt(0, rc - 1))
            If r != None
                If TravelScript != None
                    TravelScript.EnsureCourierEvents()  ; guarantee the courier event is live
                EndIf
                SeverActionsNativeExt2.Venture_DebugRequestLetter(r)
                Debug.Notification(r.GetDisplayName() + " is penning a letter - a courier will follow shortly.")
            Else
                Debug.Notification("Could not resolve a retainer - check the log.")
            EndIf
        EndIf
    elseif option == OID_Ent_ForceAmbush
        ; Force a grudge thug ambush right now (bypasses delay/cooldown/location).
        ; Arms a grudge if none is pending so it always fires while testing.
        If TravelScript != None
            TravelScript.EnsureCourierEvents()  ; guarantee the ambush event is live
        EndIf
        Bool fired = SeverActionsNativeExt2.Venture_DebugForceAmbush()
        If fired
            Debug.Notification("Thugs are on their way - watch your back.")
        Else
            Debug.Notification("No retainers to ambush from - hire one first.")
        EndIf
    elseif option == OID_Ent_Enabled
        EntEnabled = !EntEnabled
        SetToggleOptionValue(OID_Ent_Enabled, EntEnabled)
        SeverActionsNativeExt2.Venture_SetEnabled(EntEnabled)

    elseif option == OID_ConfigMenuShift
        ConfigMenuRequireShift = !ConfigMenuRequireShift
        SetToggleOptionValue(OID_ConfigMenuShift, ConfigMenuRequireShift)
        ApplyConfigMenuKeySettings()

    elseif option == OID_LLMCallsEnabled
        Bool llmNow = !SeverActionsNativeExt2.Native_GetLLMCallsEnabled()
        SeverActionsNativeExt2.Native_SetLLMCallsEnabled(llmNow)
        SetToggleOptionValue(OID_LLMCallsEnabled, llmNow)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "llmCallsEnabled", BoolToStr(llmNow))

    elseif option == OID_TruceEnabled
        CombatScript.TruceEnabled = !CombatScript.TruceEnabled
        SetToggleOptionValue(OID_TruceEnabled, CombatScript.TruceEnabled)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "truceEnabled", BoolToStr(CombatScript.TruceEnabled))
    elseif option == OID_TruceLeaders
        CombatScript.TruceLeaders = !CombatScript.TruceLeaders
        SetToggleOptionValue(OID_TruceLeaders, CombatScript.TruceLeaders)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "truceLeaders", BoolToStr(CombatScript.TruceLeaders))
    elseif option == OID_TruceQuestNPCs
        CombatScript.TruceQuestNPCs = !CombatScript.TruceQuestNPCs
        SetToggleOptionValue(OID_TruceQuestNPCs, CombatScript.TruceQuestNPCs)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "truceQuestNPCs", BoolToStr(CombatScript.TruceQuestNPCs))
    elseif option == OID_TruceDungeons
        CombatScript.TruceDungeons = !CombatScript.TruceDungeons
        SetToggleOptionValue(OID_TruceDungeons, CombatScript.TruceDungeons)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "truceDungeons", BoolToStr(CombatScript.TruceDungeons))
    elseif option == OID_TruceNecro
        CombatScript.TruceNecromancers = !CombatScript.TruceNecromancers
        SetToggleOptionValue(OID_TruceNecro, CombatScript.TruceNecromancers)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "truceNecromancers", BoolToStr(CombatScript.TruceNecromancers))
    elseif option == OID_TruceForsworn
        CombatScript.TruceForsworn = !CombatScript.TruceForsworn
        SetToggleOptionValue(OID_TruceForsworn, CombatScript.TruceForsworn)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "truceForsworn", BoolToStr(CombatScript.TruceForsworn))
    elseif option == OID_TruceVampires
        CombatScript.TruceVampires = !CombatScript.TruceVampires
        SetToggleOptionValue(OID_TruceVampires, CombatScript.TruceVampires)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "truceVampires", BoolToStr(CombatScript.TruceVampires))
    elseif option == OID_CampTakeover
        CombatScript.CampTakeoverEnabled = !CombatScript.CampTakeoverEnabled
        SetToggleOptionValue(OID_CampTakeover, CombatScript.CampTakeoverEnabled)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "campTakeoverEnabled", BoolToStr(CombatScript.CampTakeoverEnabled))
    elseif option == OID_CampChallenge
        CombatScript.CampChallengeEnabled = !CombatScript.CampChallengeEnabled
        SetToggleOptionValue(OID_CampChallenge, CombatScript.CampChallengeEnabled)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "campChallengeEnabled", BoolToStr(CombatScript.CampChallengeEnabled))
    elseif option == OID_CampChallengeCard
        CombatScript.CampChallengeCardEnabled = !CombatScript.CampChallengeCardEnabled
        SetToggleOptionValue(OID_CampChallengeCard, CombatScript.CampChallengeCardEnabled)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "campChallengeCard", BoolToStr(CombatScript.CampChallengeCardEnabled))
    elseif option == OID_CampFreezeRespawn
        CombatScript.CampFreezeRespawn = !CombatScript.CampFreezeRespawn
        SetToggleOptionValue(OID_CampFreezeRespawn, CombatScript.CampFreezeRespawn)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "campFreezeRespawn", BoolToStr(CombatScript.CampFreezeRespawn))
    elseif option == OID_YieldPersistence
        CombatScript.YieldPersistenceEnabled = !CombatScript.YieldPersistenceEnabled
        SetToggleOptionValue(OID_YieldPersistence, CombatScript.YieldPersistenceEnabled)
    elseif option == OID_SurvNotifHunger
        SurvivalScript.ShowHungerNotifications = !SurvivalScript.ShowHungerNotifications
        SetToggleOptionValue(OID_SurvNotifHunger, SurvivalScript.ShowHungerNotifications)
    elseif option == OID_SurvNotifFatigue
        SurvivalScript.ShowFatigueNotifications = !SurvivalScript.ShowFatigueNotifications
        SetToggleOptionValue(OID_SurvNotifFatigue, SurvivalScript.ShowFatigueNotifications)
    elseif option == OID_SurvNotifCold
        SurvivalScript.ShowColdNotifications = !SurvivalScript.ShowColdNotifications
        SetToggleOptionValue(OID_SurvNotifCold, SurvivalScript.ShowColdNotifications)
    elseif option == OID_DebtOverdue
        FollowerManagerScript.DebtScript.EnableOverdueReminders = !FollowerManagerScript.DebtScript.EnableOverdueReminders
        SetToggleOptionValue(OID_DebtOverdue, FollowerManagerScript.DebtScript.EnableOverdueReminders)
        SeverActionsNativeExt2.Native_SettingsRecord("world", "overdueReminders", BoolToStr(FollowerManagerScript.DebtScript.EnableOverdueReminders))
    elseif option == OID_TravelMapMarkers
        TravelScript.TravelMapMarkersEnabled = !TravelScript.TravelMapMarkersEnabled
        SetToggleOptionValue(OID_TravelMapMarkers, TravelScript.TravelMapMarkersEnabled)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "travelMapMarkersEnabled", BoolToStr(TravelScript.TravelMapMarkersEnabled))
    elseif option == OID_FollowersCanTravel
        Bool fctNow = !SeverActionsNativeExt2.Native_GetFollowersCanTravel()
        SeverActionsNativeExt2.Native_SetFollowersCanTravel(fctNow)
        SetToggleOptionValue(OID_FollowersCanTravel, fctNow)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "followersCanTravel", BoolToStr(fctNow))
    elseif option == OID_Outfit_UseAnimations
        OutfitScript.UseAnimations = !OutfitScript.UseAnimations
        SetToggleOptionValue(OID_Outfit_UseAnimations, OutfitScript.UseAnimations)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "useAnimations", BoolToStr(OutfitScript.UseAnimations))
    elseif option == OID_FM_AutoQuestAwareness
        FollowerManagerScript.AutoQuestAwareness = !FollowerManagerScript.AutoQuestAwareness
        SetToggleOptionValue(OID_FM_AutoQuestAwareness, FollowerManagerScript.AutoQuestAwareness)
        SeverActionsNativeExt.Native_QuestAwareness_SetEnabled(FollowerManagerScript.AutoQuestAwareness)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "questAwarenessEnabled", BoolToStr(FollowerManagerScript.AutoQuestAwareness))
    elseif option == OID_FM_AutoNPCReputation
        FollowerManagerScript.AutoNPCReputation = !FollowerManagerScript.AutoNPCReputation
        SetToggleOptionValue(OID_FM_AutoNPCReputation, FollowerManagerScript.AutoNPCReputation)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "npcReputationEnabled", BoolToStr(FollowerManagerScript.AutoNPCReputation))
    elseif option == OID_FM_AutoFollowerBanter
        FollowerManagerScript.AutoFollowerBanter = !FollowerManagerScript.AutoFollowerBanter
        SetToggleOptionValue(OID_FM_AutoFollowerBanter, FollowerManagerScript.AutoFollowerBanter)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "followerBanterEnabled", BoolToStr(FollowerManagerScript.AutoFollowerBanter))
    elseif option == OID_FM_AutoAmbientActions
        FollowerManagerScript.AutoAmbientActions = !FollowerManagerScript.AutoAmbientActions
        SetToggleOptionValue(OID_FM_AutoAmbientActions, FollowerManagerScript.AutoAmbientActions)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "ambientActionsEnabled", BoolToStr(FollowerManagerScript.AutoAmbientActions))
    elseif option == OID_FM_HomeSleepEnabled
        FollowerManagerScript.HomeSleepEnabled = !FollowerManagerScript.HomeSleepEnabled
        SetToggleOptionValue(OID_FM_HomeSleepEnabled, FollowerManagerScript.HomeSleepEnabled)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "homeSleepEnabled", BoolToStr(FollowerManagerScript.HomeSleepEnabled))
    elseif option == OID_FM_CellCatchup
        FollowerManagerScript.CellCatchupEnabled = !FollowerManagerScript.CellCatchupEnabled
        SetToggleOptionValue(OID_FM_CellCatchup, FollowerManagerScript.CellCatchupEnabled)
    elseif option == OID_Ent_Loans
        FollowerManagerScript.EnterpriseLoansEnabled = !FollowerManagerScript.EnterpriseLoansEnabled
        SetToggleOptionValue(OID_Ent_Loans, FollowerManagerScript.EnterpriseLoansEnabled)
        SeverActionsNativeExt2.Venture_SetLoansEnabled(FollowerManagerScript.EnterpriseLoansEnabled)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "enterpriseLoansEnabled", BoolToStr(FollowerManagerScript.EnterpriseLoansEnabled))
    elseif option == OID_Ent_Raises
        FollowerManagerScript.EnterpriseRaisesEnabled = !FollowerManagerScript.EnterpriseRaisesEnabled
        SetToggleOptionValue(OID_Ent_Raises, FollowerManagerScript.EnterpriseRaisesEnabled)
        SeverActionsNativeExt2.Venture_SetRaisesEnabled(FollowerManagerScript.EnterpriseRaisesEnabled)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "enterpriseRaisesEnabled", BoolToStr(FollowerManagerScript.EnterpriseRaisesEnabled))
    elseif option == OID_Ent_Temper
        FollowerManagerScript.EnterpriseTemperEnabled = !FollowerManagerScript.EnterpriseTemperEnabled
        SetToggleOptionValue(OID_Ent_Temper, FollowerManagerScript.EnterpriseTemperEnabled)
        SeverActionsNativeExt2.Venture_SetTemperEnabled(FollowerManagerScript.EnterpriseTemperEnabled)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "enterpriseTemperEnabled", BoolToStr(FollowerManagerScript.EnterpriseTemperEnabled))
    elseif option == OID_Ent_Ambushes
        FollowerManagerScript.EnterpriseAmbushesEnabled = !FollowerManagerScript.EnterpriseAmbushesEnabled
        SetToggleOptionValue(OID_Ent_Ambushes, FollowerManagerScript.EnterpriseAmbushesEnabled)
        SeverActionsNativeExt2.Venture_SetAmbushesEnabled(FollowerManagerScript.EnterpriseAmbushesEnabled)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "enterpriseAmbushesEnabled", BoolToStr(FollowerManagerScript.EnterpriseAmbushesEnabled))
    elseif option == OID_Ent_RenownCap
        FollowerManagerScript.EnterpriseRenownCapEnabled = !FollowerManagerScript.EnterpriseRenownCapEnabled
        SetToggleOptionValue(OID_Ent_RenownCap, FollowerManagerScript.EnterpriseRenownCapEnabled)
        SeverActionsNativeExt2.Venture_SetRenownCapEnabled(FollowerManagerScript.EnterpriseRenownCapEnabled)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "enterpriseRenownCapEnabled", BoolToStr(FollowerManagerScript.EnterpriseRenownCapEnabled))

    elseif option == OID_TagCompanion
        TagCompanionEnabled = !TagCompanionEnabled
        SetToggleOptionValue(OID_TagCompanion, TagCompanionEnabled)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "tagCompanion", BoolToStr(TagCompanionEnabled))
        StorageUtil.SetIntValue(None, "SeverActions_TagCompanion", TagCompanionEnabled as Int)

    elseif option == OID_TagEngaged
        TagEngagedEnabled = !TagEngagedEnabled
        SetToggleOptionValue(OID_TagEngaged, TagEngagedEnabled)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "tagEngaged", BoolToStr(TagEngagedEnabled))
        StorageUtil.SetIntValue(None, "SeverActions_TagEngaged", TagEngagedEnabled as Int)

    elseif option == OID_TagInScene
        TagInSceneEnabled = !TagInSceneEnabled
        SetToggleOptionValue(OID_TagInScene, TagInSceneEnabled)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "tagInScene", BoolToStr(TagInSceneEnabled))
        StorageUtil.SetIntValue(None, "SeverActions_TagInScene", TagInSceneEnabled as Int)

    elseif option == OID_SpellFailEnabled
        if SpellTeachScript
            SpellTeachScript.EnableFailureSystem = !SpellTeachScript.EnableFailureSystem
            SetToggleOptionValue(OID_SpellFailEnabled, SpellTeachScript.EnableFailureSystem)
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "spellFailEnabled", BoolToStr(SpellTeachScript.EnableFailureSystem))
            StorageUtil.SetIntValue(None, "SeverActions_SpellFailEnabled", SpellTeachScript.EnableFailureSystem as Int)
        endif

    elseif option == OID_AllowConjuredGold
        AllowConjuredGold = !AllowConjuredGold
        SetToggleOptionValue(OID_AllowConjuredGold, AllowConjuredGold)
        SeverActionsNativeExt2.Native_SettingsRecord("world", "allowConjuredGold", BoolToStr(AllowConjuredGold))
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
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "survivalEnabled", BoolToStr(SurvivalScript.Enabled))
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
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "hungerEnabled", BoolToStr(SurvivalScript.HungerEnabled))
        EndIf
    elseif option == OID_FatigueEnabled
        If SurvivalScript
            SurvivalScript.FatigueEnabled = !SurvivalScript.FatigueEnabled
            SetToggleOptionValue(OID_FatigueEnabled, SurvivalScript.FatigueEnabled)
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "fatigueEnabled", BoolToStr(SurvivalScript.FatigueEnabled))
        EndIf
    elseif option == OID_ColdEnabled
        If SurvivalScript
            SurvivalScript.ColdEnabled = !SurvivalScript.ColdEnabled
            SetToggleOptionValue(OID_ColdEnabled, SurvivalScript.ColdEnabled)
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "coldEnabled", BoolToStr(SurvivalScript.ColdEnabled))
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
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "allowAutonomousLeaving", BoolToStr(FollowerManagerScript.AllowAutonomousLeaving))
        EndIf
    elseif option == OID_FM_RoomRotation
        If FollowerManagerScript
            FollowerManagerScript.RoomRotationEnabled = !FollowerManagerScript.RoomRotationEnabled
            SetToggleOptionValue(OID_FM_RoomRotation, FollowerManagerScript.RoomRotationEnabled)
        EndIf
    elseif option == OID_FM_KidnapEnabled
        If FollowerManagerScript
            FollowerManagerScript.EnableKidnapActions = !FollowerManagerScript.EnableKidnapActions
            SetToggleOptionValue(OID_FM_KidnapEnabled, FollowerManagerScript.EnableKidnapActions)
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "kidnapEnabled", BoolToStr(FollowerManagerScript.EnableKidnapActions))
            ; Push to the native flag the sever_kidnap_enabled decorator reads.
            SeverActionsNativeExt.Native_Kidnap_SetEnabled(FollowerManagerScript.EnableKidnapActions)
        EndIf
    elseif option == OID_FM_RestrainEnabled
        If FollowerManagerScript
            FollowerManagerScript.EnableRestrainAction = !FollowerManagerScript.EnableRestrainAction
            SetToggleOptionValue(OID_FM_RestrainEnabled, FollowerManagerScript.EnableRestrainAction)
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "restrainEnabled", BoolToStr(FollowerManagerScript.EnableRestrainAction))
            ; Push to the native flag the sever_restrain_enabled decorator reads.
            SeverActionsNativeExt.Native_Restrain_SetEnabled(FollowerManagerScript.EnableRestrainAction)
        EndIf
    elseif option == OID_FM_AutoSwitch
        Bool curEnabled = SeverActionsNativeExt.SituationMonitor_IsEnabled()
        SeverActionsNativeExt.SituationMonitor_SetEnabled(!curEnabled)
        StorageUtil.SetIntValue(None, "SeverOutfit_GlobalAutoSwitch", (!curEnabled) as Int)
        SetToggleOptionValue(OID_FM_AutoSwitch, !curEnabled)
    elseif option == OID_FM_PerActorAutoSwitch
        If CachedManagedFollowers && SelectedCompanionIdx < CachedManagedFollowers.Length
            Actor follower = CachedManagedFollowers[SelectedCompanionIdx]
            If follower
                Bool curVal = SeverActionsNative.Native_Outfit_GetAutoSwitchEnabled(follower)
                Bool newVal = !curVal
                Debug.Trace("[SeverActions_MCM] PerActorAutoSwitch: " + follower.GetDisplayName() + " (" + follower.GetFormID() + ") curVal=" + curVal + " -> newVal=" + newVal)
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
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "trackRelationships", BoolToStr(FollowerManagerScript.AutoRelAssessment))
        EndIf
    elseif option == OID_FM_AutoInterAssessment
        If FollowerManagerScript
            FollowerManagerScript.AutoInterFollowerAssessment = !FollowerManagerScript.AutoInterFollowerAssessment
            SetToggleOptionValue(OID_FM_AutoInterAssessment, FollowerManagerScript.AutoInterFollowerAssessment)
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "interFollowerAssessment", BoolToStr(FollowerManagerScript.AutoInterFollowerAssessment))
        EndIf
    elseif option == OID_FM_AutoOffScreenLife
        If FollowerManagerScript
            FollowerManagerScript.AutoOffScreenLife = !FollowerManagerScript.AutoOffScreenLife
            SetToggleOptionValue(OID_FM_AutoOffScreenLife, FollowerManagerScript.AutoOffScreenLife)
            SeverActionsNativeExt2.Native_SettingsRecord("offscreen", "autoOffScreenLife", BoolToStr(FollowerManagerScript.AutoOffScreenLife))
        EndIf
    elseif option == OID_FM_OffScreenConsequences
        If FollowerManagerScript
            FollowerManagerScript.OffScreenConsequences = !FollowerManagerScript.OffScreenConsequences
            SetToggleOptionValue(OID_FM_OffScreenConsequences, FollowerManagerScript.OffScreenConsequences)
            SeverActionsNativeExt2.Native_SettingsRecord("offscreen", "consequencesEnabled", BoolToStr(FollowerManagerScript.OffScreenConsequences))
        EndIf
    elseif option == OID_FM_AutoAmbientBanter
        If FollowerManagerScript
            FollowerManagerScript.AutoAmbientBanter = !FollowerManagerScript.AutoAmbientBanter
            SetToggleOptionValue(OID_FM_AutoAmbientBanter, FollowerManagerScript.AutoAmbientBanter)
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "ambientBanterEnabled", BoolToStr(FollowerManagerScript.AutoAmbientBanter))
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
                        ; abDeliberateExit = TRUE: a player clicking Dismiss and
                        ; confirming is as deliberate as the dialogue action, so
                        ; NFF's alias seat must come down with our roster entry.
                        ; Left false, this button reproduced the undismissable-
                        ; follower bug on the MCM surface. The Reset All sweep
                        ; above stays false - that is bookkeeping, not intent.
                        FollowerManagerScript.UnregisterFollower(CachedManagedFollowers[j], true, true)
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
                        Debug.Notification("No location detected - try from inside a named area.")
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

        ; Homes page: NPC Home clear buttons
        If FollowerManagerScript && OID_ClearNPCHome && CachedHomedNPCs
            Int h = 0
            While h < CachedHomedNPCs.Length && h < 50
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

        ; --- Outfits page: defer-to-bondage-mods global toggle ---
        If option == OID_Outfit_DeferBondage
            Bool curDefer = StorageUtil.GetIntValue(None, "SeverOutfit_DeferBondage", 1) as Bool
            Bool newDefer = !curDefer
            StorageUtil.SetIntValue(None, "SeverOutfit_DeferBondage", newDefer as Int)
            SeverActionsNativeExt.Native_Outfit_SetDeferBondage(newDefer)
            SetToggleOptionValue(OID_Outfit_DeferBondage, newDefer)
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

        ; --- Bio Blocks page: apply selected block to the crosshair target ---
        If option == OID_Bio_Apply
            If BioTargetActor && BioBlockIds && BioBlockIds.Length > 0 && BioBlockIdx < BioBlockIds.Length
                If SeverActionsNativeExt2.Native_BioBlock_Apply(BioTargetActor, BioBlockIds[BioBlockIdx])
                    Debug.Notification("Bio block applied to " + BioTargetActor.GetDisplayName())
                Else
                    Debug.Notification("Bio Blocks: already applied, or no target/block")
                EndIf
                ForcePageReset()
            Else
                Debug.Notification("Bio Blocks: aim at an NPC and pick a block first")
            EndIf
            return
        EndIf

        ; --- Bio Blocks page: faction-rule remove rows ---
        If OID_Bio_Rule && BioRuleNames
            Int br = 0
            While br < OID_Bio_Rule.Length && br < BioRuleNames.Length
                If option == OID_Bio_Rule[br]
                    If SeverActionsNativeExt2.Native_BioBlock_RemoveFactionRule(br)
                        Debug.Notification("Faction rule removed")
                    EndIf
                    ForcePageReset()
                    return
                EndIf
                br += 1
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
    If !BountyScript
        Quest myQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
        If myQuest
            BountyScript = myQuest as SeverActions_ArrestBounty
        EndIf
    EndIf
    If !ArrestScript || !BountyScript || !akCrimeFaction
        Return
    EndIf

    Int bounty = BountyScript.GetTrackedBounty(akCrimeFaction)
    If bounty <= 0
        ShowMessage("You have no bounty in " + holdName + ".", false)
        Return
    EndIf

    String confirmMsg = "Clear your " + bounty + " gold bounty in " + holdName + "?"
    Bool doConfirm = ShowMessage(confirmMsg, true, "Yes", "No")

    If doConfirm
        BountyScript.ClearTrackedBounty(akCrimeFaction)
        ForcePageReset()
        Debug.Notification("Bounty cleared in " + holdName)
    EndIf
EndFunction

Function ClearAllBountiesWithConfirm()
    {Clear all bounties in all holds with confirmation}
    If !BountyScript
        Quest myQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
        If myQuest
            BountyScript = myQuest as SeverActions_ArrestBounty
        EndIf
    EndIf
    If !ArrestScript || !BountyScript
        Return
    EndIf

    ; Check if there are any bounties to clear
    Int totalBounty = 0
    totalBounty += BountyScript.GetTrackedBounty(ArrestScript.CrimeFactionWhiterun)
    totalBounty += BountyScript.GetTrackedBounty(ArrestScript.CrimeFactionRift)
    totalBounty += BountyScript.GetTrackedBounty(ArrestScript.CrimeFactionHaafingar)
    totalBounty += BountyScript.GetTrackedBounty(ArrestScript.CrimeFactionEastmarch)
    totalBounty += BountyScript.GetTrackedBounty(ArrestScript.CrimeFactionReach)
    totalBounty += BountyScript.GetTrackedBounty(ArrestScript.CrimeFactionFalkreath)
    totalBounty += BountyScript.GetTrackedBounty(ArrestScript.CrimeFactionPale)
    totalBounty += BountyScript.GetTrackedBounty(ArrestScript.CrimeFactionHjaalmarch)
    totalBounty += BountyScript.GetTrackedBounty(ArrestScript.CrimeFactionWinterhold)

    If totalBounty <= 0
        ShowMessage("You have no bounties in any hold.", false)
        Return
    EndIf

    String confirmMsg = "Clear ALL bounties across all holds? Total: " + totalBounty + " gold."
    Bool doConfirm = ShowMessage(confirmMsg, true, "Yes", "No")

    If doConfirm
        BountyScript.ClearTrackedBounty(ArrestScript.CrimeFactionWhiterun)
        BountyScript.ClearTrackedBounty(ArrestScript.CrimeFactionRift)
        BountyScript.ClearTrackedBounty(ArrestScript.CrimeFactionHaafingar)
        BountyScript.ClearTrackedBounty(ArrestScript.CrimeFactionEastmarch)
        BountyScript.ClearTrackedBounty(ArrestScript.CrimeFactionReach)
        BountyScript.ClearTrackedBounty(ArrestScript.CrimeFactionFalkreath)
        BountyScript.ClearTrackedBounty(ArrestScript.CrimeFactionPale)
        BountyScript.ClearTrackedBounty(ArrestScript.CrimeFactionHjaalmarch)
        BountyScript.ClearTrackedBounty(ArrestScript.CrimeFactionWinterhold)
        ForcePageReset()
        Debug.Notification("All bounties cleared!")
    EndIf
EndFunction

; =============================================================================
; KEYMAP HANDLING
; =============================================================================

int Function EffectiveConfigMenuKey()
    {The authoritative config-menu key lives on the Hotkeys script (which
     defaults to 9 and is what the native sink actually consumes). The MCM's
     own ConfigMenuKey is only a display copy that starts at -1.}
    If HotkeyScript && HotkeyScript.ConfigMenuKey > 0
        return HotkeyScript.ConfigMenuKey
    EndIf
    return ConfigMenuKey
EndFunction

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

    ; The config-menu key is consumed natively and always wins in OnKeyDown —
    ; a hotkey sharing its code would simply never fire. Refuse the bind so
    ; the user picks a different key instead of getting a dead hotkey.
    ; Compare against the AUTHORITATIVE key on the Hotkeys script: the MCM's
    ; own ConfigMenuKey property defaults to -1 and is only populated once
    ; the user rebinds it HERE, so for default-key users comparing our copy
    ; would refuse nothing (the split-brain field finding).
    if keyCode > 0 && option != OID_ConfigMenuKey && keyCode == EffectiveConfigMenuKey()
        ShowMessage("That key opens the SeverActions config menu. Pick a different key, or rebind the config menu first.", false, "OK")
        return
    endif
    if keyCode > 0 && option == OID_ConfigMenuKey
        bool taken = keyCode == FollowToggleKey || keyCode == DismissKey || keyCode == StandUpKey || keyCode == UseFurnitureKey || keyCode == YieldKey || keyCode == UndressKey || keyCode == DressKey || keyCode == SetCompanionKey || keyCode == CompanionWaitKey || keyCode == AssignHomeKey || keyCode == SetupCampKey || keyCode == DropMarkerKey || keyCode == TieUntieKey || keyCode == WheelMenuKey || keyCode == ClearHomeKey
        if taken
            ShowMessage("A SeverActions hotkey already uses that key - it would stop working (the config menu always wins). Pick a different key or clear that hotkey first.", false, "OK")
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

    elseif option == OID_UseFurnitureKey
        UseFurnitureKey = keyCode
        SetKeyMapOptionValue(OID_UseFurnitureKey, keyCode)
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
    elseif option == OID_ClearHomeKey
        ClearHomeKey = keyCode
        SetKeyMapOptionValue(OID_ClearHomeKey, keyCode)
        ApplyHotkeySettings()

    elseif option == OID_SetupCampKey
        SetupCampKey = keyCode
        SetKeyMapOptionValue(OID_SetupCampKey, keyCode)
        ApplyHotkeySettings()

    elseif option == OID_DropMarkerKey
        DropMarkerKey = keyCode
        SetKeyMapOptionValue(OID_DropMarkerKey, keyCode)
        ApplyHotkeySettings()
    elseif option == OID_TieUntieKey
        TieUntieKey = keyCode
        SetKeyMapOptionValue(OID_TieUntieKey, keyCode)
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
; MENU HANDLING (dropdowns)
; =============================================================================

Event OnOptionMenuOpen(int option)
    if option == OID_Ent_Job
        SetMenuDialogStartIndex(EntJob)
        SetMenuDialogDefaultIndex(0)
        SetMenuDialogOptions(EntJobOptions)
    elseif option == OID_Ent_Arrangement
        SetMenuDialogStartIndex(EntArrangement)
        SetMenuDialogDefaultIndex(0)
        SetMenuDialogOptions(EntArrangementOptions)
    elseif option == OID_TargetMode
        SetMenuDialogStartIndex(TargetMode)
        SetMenuDialogDefaultIndex(0)
        SetMenuDialogOptions(TargetModeOptions)
    elseif option == OID_BookReadMode
        If LootScript
            SetMenuDialogStartIndex(LootScript.BookReadMode)
            SetMenuDialogDefaultIndex(0)
            SetMenuDialogOptions(BookReadModeOptions)
        EndIf
    elseif option == OID_IntimacyGenderGate
        ; Populate the dropdown the same way FrameworkMode does.
        If FollowerManagerScript
            SetMenuDialogStartIndex(FollowerManagerScript.IntimacyGenderGate)
            SetMenuDialogDefaultIndex(0)
            SetMenuDialogOptions(IntimacyGenderOptions)
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
            string[] npcNames = new string[20]
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
            string[] names = new string[20]
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
            string[] dnames = new string[20]
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
    elseif option == OID_Bio_Tab
        If BioTabs && BioTabs.Length > 0
            SetMenuDialogStartIndex(BioTabIdx)
            SetMenuDialogDefaultIndex(0)
            SetMenuDialogOptions(BioTabs)
        EndIf
    elseif option == OID_Bio_Block
        If BioBlockTitles && BioBlockTitles.Length > 0
            SetMenuDialogStartIndex(BioBlockIdx)
            SetMenuDialogDefaultIndex(0)
            SetMenuDialogOptions(BioBlockTitles)
        EndIf
    elseif option == OID_Bio_GrantFaction
        If BioTargetActor
            BioTargetFactions = SeverActionsNativeExt2.Native_BioBlock_TargetFactionNames(BioTargetActor)
            If BioTargetFactions && BioTargetFactions.Length > 0
                SetMenuDialogStartIndex(0)
                SetMenuDialogDefaultIndex(0)
                SetMenuDialogOptions(BioTargetFactions)
            EndIf
        EndIf
    elseif option == OID_Bio_RemoveBlock
        If BioAssignedTitles && BioAssignedTitles.Length > 0
            SetMenuDialogStartIndex(0)
            SetMenuDialogDefaultIndex(0)
            SetMenuDialogOptions(BioAssignedTitles)
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
    if option == OID_Ent_Job
        EntJob = index
        SetMenuOptionValue(OID_Ent_Job, EntJobOptions[index])
    elseif option == OID_Ent_Arrangement
        EntArrangement = index
        SetMenuOptionValue(OID_Ent_Arrangement, EntArrangementOptions[index])
    elseif option == OID_TargetMode
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
    elseif option == OID_IntimacyGenderGate
        If FollowerManagerScript
            FollowerManagerScript.IntimacyGenderGate = index
            ; Same write-through rule as the toggle: file and property must
            ; agree or the load replay reverts it.
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "intimacyGenderGate", "" + index)
            ; Live-apply so the gate takes effect now, not on the next reload
            ; (the decorator reads the native atomic). (PR #442 review)
            SeverActionsNativeExt2.Native_IntimateHistory_SetGenderGate(index)
            SetMenuOptionValue(OID_IntimacyGenderGate, IntimacyGenderOptions[index])
        EndIf
    elseif option == OID_FM_FrameworkMode
        If FollowerManagerScript
            FollowerManagerScript.FrameworkMode = index
            ; Write through to the GLOBAL settings file with the same page/key
            ; PrismaUI uses. Without this the file kept PrismaUI's older value
            ; and the load-time replay ("global file always wins") reverted this
            ; choice on every load - the Tracking-reverts report.
            SeverActionsNativeExt2.Native_SettingsRecord("companions", "frameworkMode", "" + index)
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
    elseif option == OID_Bio_Tab
        If BioTabs && index < BioTabs.Length
            BioTabIdx = index
            BioBlockIdx = 0
            SetMenuOptionValue(OID_Bio_Tab, BioTabs[index])
            ForcePageReset()
        EndIf
    elseif option == OID_Bio_Block
        If BioBlockTitles && index < BioBlockTitles.Length
            BioBlockIdx = index
            SetMenuOptionValue(OID_Bio_Block, BioBlockTitles[index])
        EndIf
    elseif option == OID_Bio_GrantFaction
        If BioTargetActor && BioTargetFactions && index < BioTargetFactions.Length && BioBlockIds && BioBlockIdx < BioBlockIds.Length
            If SeverActionsNativeExt2.Native_BioBlock_GrantTargetFaction(BioTargetActor, index, BioBlockIds[BioBlockIdx])
                Debug.Notification("Block granted to " + BioTargetFactions[index])
            Else
                Debug.Notification("Bio Blocks: could not grant to that faction")
            EndIf
            ForcePageReset()
        EndIf
    elseif option == OID_Bio_RemoveBlock
        If BioTargetActor && BioAssignedIds && index < BioAssignedIds.Length
            SeverActionsNativeExt2.Native_BioBlock_Unapply(BioTargetActor, BioAssignedIds[index])
            Debug.Notification("Block removed")
            ForcePageReset()
        EndIf
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
    if option == OID_Ent_Wage
        SetSliderDialogStartValue(EntWage as Float)
        SetSliderDialogDefaultValue(200.0)
        SetSliderDialogRange(0.0, 5000.0)
        SetSliderDialogInterval(50.0)
    elseif option == OID_NearestNPCRadius
        SetSliderDialogStartValue(NearestNPCRadius)
        SetSliderDialogDefaultValue(500.0)
        SetSliderDialogRange(100.0, 2000.0)
        SetSliderDialogInterval(50.0)
    elseif option == OID_TruceRadius
        SetSliderDialogStartValue(CombatScript.TruceRadius)
        SetSliderDialogDefaultValue(8000.0)
        SetSliderDialogRange(2000.0, 16000.0)
        SetSliderDialogInterval(500.0)
    elseif option == OID_ChallengeParleySeconds
        SetSliderDialogStartValue(CombatScript.ChallengeParleySeconds)
        SetSliderDialogDefaultValue(120.0)
        SetSliderDialogRange(30.0, 300.0)
        SetSliderDialogInterval(10.0)
    elseif option == OID_CombatCooldown
        SetSliderDialogStartValue(CombatScript.CombatCooldownDuration)
        SetSliderDialogDefaultValue(30.0)
        SetSliderDialogRange(5.0, 120.0)
        SetSliderDialogInterval(5.0)
    elseif option == OID_DebuffSeverity
        SetSliderDialogStartValue(SurvivalScript.DebuffSeverity)
        SetSliderDialogDefaultValue(1.0)
        SetSliderDialogRange(0.0, 1.0)
        SetSliderDialogInterval(0.05)
    elseif option == OID_ArrestBountyThreshold
        SetSliderDialogStartValue(ArrestScript.ArrestBountyThreshold as Float)
        SetSliderDialogDefaultValue(300.0)
        SetSliderDialogRange(0.0, 2000.0)
        SetSliderDialogInterval(50.0)
    elseif option == OID_BribeMult
        SetSliderDialogStartValue(ArrestScript.BribeMultiplier)
        SetSliderDialogDefaultValue(1.5)
        SetSliderDialogRange(1.0, 5.0)
        SetSliderDialogInterval(0.25)
    elseif option == OID_ResistBounty
        SetSliderDialogStartValue(ArrestScript.ResistBountyIncrease as Float)
        SetSliderDialogDefaultValue(500.0)
        SetSliderDialogRange(0.0, 2000.0)
        SetSliderDialogInterval(50.0)
    elseif option == OID_DebtGrace
        SetSliderDialogStartValue(FollowerManagerScript.DebtScript.OverdueGracePeriodHours)
        SetSliderDialogDefaultValue(24.0)
        SetSliderDialogRange(0.0, 168.0)
        SetSliderDialogInterval(6.0)
    elseif option == OID_DebtReport
        SetSliderDialogStartValue(FollowerManagerScript.DebtScript.ReportThresholdHours)
        SetSliderDialogDefaultValue(72.0)
        SetSliderDialogRange(0.0, 336.0)
        SetSliderDialogInterval(6.0)
    elseif option == OID_FM_SchedWorkStart
        SetSliderDialogStartValue(FollowerManagerScript.SCHEDULE_WORK_START)
        SetSliderDialogDefaultValue(8.0)
        SetSliderDialogRange(0.0, 24.0)
        SetSliderDialogInterval(1.0)
    elseif option == OID_FM_SchedWorkEnd
        SetSliderDialogStartValue(FollowerManagerScript.SCHEDULE_WORK_END)
        SetSliderDialogDefaultValue(17.0)
        SetSliderDialogRange(0.0, 24.0)
        SetSliderDialogInterval(1.0)
    elseif option == OID_FM_SchedPlayStart
        SetSliderDialogStartValue(FollowerManagerScript.SCHEDULE_PLAY_START)
        SetSliderDialogDefaultValue(17.0)
        SetSliderDialogRange(0.0, 24.0)
        SetSliderDialogInterval(1.0)
    elseif option == OID_FM_SchedPlayEnd
        SetSliderDialogStartValue(FollowerManagerScript.SCHEDULE_PLAY_END)
        SetSliderDialogDefaultValue(22.0)
        SetSliderDialogRange(0.0, 24.0)
        SetSliderDialogInterval(1.0)
    elseif option == OID_FM_HomeSleepStart
        SetSliderDialogStartValue(FollowerManagerScript.HomeSleepStart)
        SetSliderDialogDefaultValue(22.0)
        SetSliderDialogRange(0.0, 24.0)
        SetSliderDialogInterval(1.0)
    elseif option == OID_FM_HomeSleepEnd
        SetSliderDialogStartValue(FollowerManagerScript.HomeSleepEnd)
        SetSliderDialogDefaultValue(6.0)
        SetSliderDialogRange(0.0, 24.0)
        SetSliderDialogInterval(1.0)
    elseif option == OID_FM_TeleportDist
        SetSliderDialogStartValue(FollowerManagerScript.FollowerTeleportDistance)
        SetSliderDialogDefaultValue(2000.0)
        SetSliderDialogRange(0.0, 6000.0)
        SetSliderDialogInterval(250.0)
    elseif option == OID_FM_TeleportCooldown
        SetSliderDialogStartValue(FollowerManagerScript.TeleportCooldownSeconds as Float)
        SetSliderDialogDefaultValue(30.0)
        SetSliderDialogRange(0.0, 300.0)
        SetSliderDialogInterval(5.0)
    elseif option == OID_Ent_OutputPct
        SetSliderDialogStartValue(FollowerManagerScript.EnterpriseOutputPct as Float)
        SetSliderDialogDefaultValue(100.0)
        SetSliderDialogRange(0.0, 300.0)
        SetSliderDialogInterval(10.0)
    elseif option == OID_Ent_StoryCap
        SetSliderDialogStartValue(FollowerManagerScript.EnterpriseStoryCap as Float)
        SetSliderDialogDefaultValue(-1.0)
        SetSliderDialogRange(-1.0, 12.0)
        SetSliderDialogInterval(1.0)
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
    elseif option == OID_SilenceChance
        SetSliderDialogStartValue(SilenceChance as Float)
        SetSliderDialogDefaultValue(50.0)
        SetSliderDialogRange(0.0, 100.0)
        SetSliderDialogInterval(5.0)

    elseif option == OID_UIScale
        Float startScale = 1.0
        If FollowerManagerScript
            startScale = FollowerManagerScript.UIScale
        EndIf
        SetSliderDialogStartValue(startScale)
        SetSliderDialogDefaultValue(1.0)
        SetSliderDialogRange(0.8, 2.0)
        SetSliderDialogInterval(0.05)

    elseif option == OID_SpellFailDifficulty
        if SpellTeachScript
            SetSliderDialogStartValue(SpellTeachScript.FailureDifficultyMult)
            SetSliderDialogDefaultValue(1.0)
            SetSliderDialogRange(0.0, 3.0)
            SetSliderDialogInterval(0.1)
        endif

    ; Inventory limit sliders
    elseif option == OID_InvLimit_Weapons
        SetSliderDialogStartValue(InvLimit_Weapons as Float)
        SetSliderDialogDefaultValue(10.0)
        SetSliderDialogRange(0.0, 20.0)
        SetSliderDialogInterval(1.0)
    elseif option == OID_InvLimit_Armor
        SetSliderDialogStartValue(InvLimit_Armor as Float)
        SetSliderDialogDefaultValue(10.0)
        SetSliderDialogRange(0.0, 20.0)
        SetSliderDialogInterval(1.0)
    elseif option == OID_InvLimit_Potions
        SetSliderDialogStartValue(InvLimit_Potions as Float)
        SetSliderDialogDefaultValue(10.0)
        SetSliderDialogRange(0.0, 20.0)
        SetSliderDialogInterval(1.0)
    elseif option == OID_InvLimit_Ingredients
        SetSliderDialogStartValue(InvLimit_Ingredients as Float)
        SetSliderDialogDefaultValue(5.0)
        SetSliderDialogRange(0.0, 20.0)
        SetSliderDialogInterval(1.0)
    elseif option == OID_InvLimit_Books
        SetSliderDialogStartValue(InvLimit_Books as Float)
        SetSliderDialogDefaultValue(10.0)
        SetSliderDialogRange(0.0, 20.0)
        SetSliderDialogInterval(1.0)
    elseif option == OID_InvLimit_Scrolls
        SetSliderDialogStartValue(InvLimit_Scrolls as Float)
        SetSliderDialogDefaultValue(5.0)
        SetSliderDialogRange(0.0, 20.0)
        SetSliderDialogInterval(1.0)
    elseif option == OID_InvLimit_Ammo
        SetSliderDialogStartValue(InvLimit_Ammo as Float)
        SetSliderDialogDefaultValue(5.0)
        SetSliderDialogRange(0.0, 20.0)
        SetSliderDialogInterval(1.0)
    elseif option == OID_InvLimit_Keys
        SetSliderDialogStartValue(InvLimit_Keys as Float)
        SetSliderDialogDefaultValue(5.0)
        SetSliderDialogRange(0.0, 20.0)
        SetSliderDialogInterval(1.0)
    elseif option == OID_InvLimit_Misc
        SetSliderDialogStartValue(InvLimit_Misc as Float)
        SetSliderDialogDefaultValue(5.0)
        SetSliderDialogRange(0.0, 20.0)
        SetSliderDialogInterval(1.0)

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
            SetSliderDialogDefaultValue(100.0)
            SetSliderDialogRange(0.0, 200.0)  ; 0 = unlimited
            SetSliderDialogInterval(1.0)
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
            SetSliderDialogDefaultValue(72.0)
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
    elseif option == OID_FM_AmbientBanterCooldownMin
        If FollowerManagerScript
            SetSliderDialogStartValue(FollowerManagerScript.AmbientBanterCooldownMinHours)
            SetSliderDialogDefaultValue(3.0)
            SetSliderDialogRange(1.0, 24.0)
            SetSliderDialogInterval(1.0)
        EndIf
    elseif option == OID_FM_AmbientBanterCooldownMax
        If FollowerManagerScript
            SetSliderDialogStartValue(FollowerManagerScript.AmbientBanterCooldownMaxHours)
            SetSliderDialogDefaultValue(7.0)
            SetSliderDialogRange(2.0, 48.0)
            SetSliderDialogInterval(1.0)
        EndIf
    elseif option == OID_FM_QuestAwarenessOutputCap
        If FollowerManagerScript
            SetSliderDialogStartValue(FollowerManagerScript.QuestAwarenessOutputCap as Float)
            SetSliderDialogDefaultValue(5.0)
            SetSliderDialogRange(1.0, 15.0)
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
        SetSliderDialogStartValue((SeverActionsNativeExt.SituationMonitor_GetStabilityThreshold() as Float) / 1000.0)
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
    if option == OID_Ent_Wage
        EntWage = value as Int
        SetSliderOptionValue(OID_Ent_Wage, value, "{0}g")
    elseif option == OID_NearestNPCRadius
        NearestNPCRadius = value
        SetSliderOptionValue(OID_NearestNPCRadius, NearestNPCRadius, "{0} units")
        ApplyHotkeySettings()
    elseif option == OID_ArrestCooldown
        ArrestScript.ArrestPlayerCooldown = value
        SetSliderOptionValue(OID_ArrestCooldown, value, "{0} sec")
        SeverActionsNativeExt2.Native_SettingsRecord("world", "arrestCooldown", "" + value)
    elseif option == OID_TruceRadius
        CombatScript.TruceRadius = value
        CombatScript.PushTruceConfigToNative()
        SetSliderOptionValue(OID_TruceRadius, value, "{0} units")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "truceRadius", "" + value)
    elseif option == OID_ChallengeParleySeconds
        CombatScript.ChallengeParleySeconds = value
        CombatScript.PushTruceConfigToNative()
        SetSliderOptionValue(OID_ChallengeParleySeconds, value, "{0} sec")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "campChallengeSeconds", "" + value)
    elseif option == OID_CombatCooldown
        CombatScript.CombatCooldownDuration = value
        SetSliderOptionValue(OID_CombatCooldown, value, "{0} sec")
    elseif option == OID_DebuffSeverity
        SurvivalScript.DebuffSeverity = value
        SetSliderOptionValue(OID_DebuffSeverity, value, "{2}x")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "debuffSeverity", "" + value)
    elseif option == OID_ArrestBountyThreshold
        ArrestScript.ArrestBountyThreshold = value as Int
        SetSliderOptionValue(OID_ArrestBountyThreshold, value, "{0}g")
    elseif option == OID_BribeMult
        ArrestScript.BribeMultiplier = value
        SetSliderOptionValue(OID_BribeMult, value, "{2}x")
    elseif option == OID_ResistBounty
        ArrestScript.ResistBountyIncrease = value as Int
        SetSliderOptionValue(OID_ResistBounty, value, "{0}g")
    elseif option == OID_DebtGrace
        FollowerManagerScript.DebtScript.OverdueGracePeriodHours = value
        SetSliderOptionValue(OID_DebtGrace, value, "{0} hrs")
        SeverActionsNativeExt2.Native_SettingsRecord("world", "gracePeriod", "" + value)
    elseif option == OID_DebtReport
        FollowerManagerScript.DebtScript.ReportThresholdHours = value
        SetSliderOptionValue(OID_DebtReport, value, "{0} hrs")
        SeverActionsNativeExt2.Native_SettingsRecord("world", "reportThreshold", "" + value)
    elseif option == OID_FM_SchedWorkStart
        FollowerManagerScript.SCHEDULE_WORK_START = value
        SetSliderOptionValue(OID_FM_SchedWorkStart, value, "{0}:00")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "scheduleWorkStart", "" + value)
    elseif option == OID_FM_SchedWorkEnd
        FollowerManagerScript.SCHEDULE_WORK_END = value
        SetSliderOptionValue(OID_FM_SchedWorkEnd, value, "{0}:00")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "scheduleWorkEnd", "" + value)
    elseif option == OID_FM_SchedPlayStart
        FollowerManagerScript.SCHEDULE_PLAY_START = value
        SetSliderOptionValue(OID_FM_SchedPlayStart, value, "{0}:00")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "schedulePlayStart", "" + value)
    elseif option == OID_FM_SchedPlayEnd
        FollowerManagerScript.SCHEDULE_PLAY_END = value
        SetSliderOptionValue(OID_FM_SchedPlayEnd, value, "{0}:00")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "schedulePlayEnd", "" + value)
    elseif option == OID_FM_HomeSleepStart
        FollowerManagerScript.HomeSleepStart = value
        SetSliderOptionValue(OID_FM_HomeSleepStart, value, "{0}:00")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "homeSleepStart", "" + value)
    elseif option == OID_FM_HomeSleepEnd
        FollowerManagerScript.HomeSleepEnd = value
        SetSliderOptionValue(OID_FM_HomeSleepEnd, value, "{0}:00")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "homeSleepEnd", "" + value)
    elseif option == OID_FM_TeleportDist
        FollowerManagerScript.FollowerTeleportDistance = value
        SetSliderOptionValue(OID_FM_TeleportDist, value, "{0}")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "followerTeleportDistance", "" + value)
    elseif option == OID_FM_TeleportCooldown
        FollowerManagerScript.TeleportCooldownSeconds = value as Int
        SetSliderOptionValue(OID_FM_TeleportCooldown, value, "{0} sec")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "teleportCooldown", "" + value)
    elseif option == OID_Ent_OutputPct
        FollowerManagerScript.EnterpriseOutputPct = value as Int
        SeverActionsNativeExt2.Venture_SetProductionMult(FollowerManagerScript.EnterpriseOutputPct)
        SetSliderOptionValue(OID_Ent_OutputPct, value, "{0}%")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "enterpriseOutputPct", "" + value)
    elseif option == OID_Ent_StoryCap
        FollowerManagerScript.EnterpriseStoryCap = value as Int
        SeverActionsNativeExt2.Venture_SetStoryCap(FollowerManagerScript.EnterpriseStoryCap)
        SetSliderOptionValue(OID_Ent_StoryCap, value, "{0}")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "enterpriseStoryCap", "" + value)
    elseif option == OID_PersuasionTimeLimit
        ArrestScript.PersuasionTimeLimit = value
        SetSliderOptionValue(OID_PersuasionTimeLimit, value, "{0} sec")
        SeverActionsNativeExt2.Native_SettingsRecord("world", "persuasionTimeLimit", "" + value)
    elseif option == OID_SilenceChance
        SilenceChance = value as Int
        StorageUtil.SetIntValue(None, "SeverActions_ZeroChance", SilenceChance)
        SetSliderOptionValue(OID_SilenceChance, value, "{0}%")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "silenceChance", "" + value)

    elseif option == OID_UIScale
        ; Write the property + StorageUtil mirror. The PrismaUI gatherer
        ; reads the property on next page-data fetch, so the new scale
        ; takes effect the next time the player opens Prisma.
        If FollowerManagerScript
            FollowerManagerScript.UIScale = value
            StorageUtil.SetFloatValue(None, "SeverActions_UIScale", value)
        EndIf
        SetSliderOptionValue(OID_UIScale, value, "{2}x")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "uiScale", "" + value)

    elseif option == OID_SpellFailDifficulty
        if SpellTeachScript
            SpellTeachScript.FailureDifficultyMult = value
            StorageUtil.SetFloatValue(None, "SeverActions_SpellFailDifficulty", value)
            SetSliderOptionValue(OID_SpellFailDifficulty, value, "{1}x")
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "spellFailDifficulty", "" + value)
        endif

    ; Inventory limit sliders (dual-write: property + StorageUtil for prompt access)
    elseif option == OID_InvLimit_Weapons
        InvLimit_Weapons = value as Int
        StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Weapons", InvLimit_Weapons)
        SetSliderOptionValue(OID_InvLimit_Weapons, value, "{0} items")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "invLimitWeapons", "" + value)
    elseif option == OID_InvLimit_Armor
        InvLimit_Armor = value as Int
        StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Armor", InvLimit_Armor)
        SetSliderOptionValue(OID_InvLimit_Armor, value, "{0} items")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "invLimitArmor", "" + value)
    elseif option == OID_InvLimit_Potions
        InvLimit_Potions = value as Int
        StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Potions", InvLimit_Potions)
        SetSliderOptionValue(OID_InvLimit_Potions, value, "{0} items")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "invLimitPotions", "" + value)
    elseif option == OID_InvLimit_Ingredients
        InvLimit_Ingredients = value as Int
        StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Ingredients", InvLimit_Ingredients)
        SetSliderOptionValue(OID_InvLimit_Ingredients, value, "{0} items")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "invLimitIngredients", "" + value)
    elseif option == OID_InvLimit_Books
        InvLimit_Books = value as Int
        StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Books", InvLimit_Books)
        SetSliderOptionValue(OID_InvLimit_Books, value, "{0} items")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "invLimitBooks", "" + value)
    elseif option == OID_InvLimit_Scrolls
        InvLimit_Scrolls = value as Int
        StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Scrolls", InvLimit_Scrolls)
        SetSliderOptionValue(OID_InvLimit_Scrolls, value, "{0} items")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "invLimitScrolls", "" + value)
    elseif option == OID_InvLimit_Ammo
        InvLimit_Ammo = value as Int
        StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Ammo", InvLimit_Ammo)
        SetSliderOptionValue(OID_InvLimit_Ammo, value, "{0} items")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "invLimitAmmo", "" + value)
    elseif option == OID_InvLimit_Keys
        InvLimit_Keys = value as Int
        StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Keys", InvLimit_Keys)
        SetSliderOptionValue(OID_InvLimit_Keys, value, "{0} items")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "invLimitKeys", "" + value)
    elseif option == OID_InvLimit_Misc
        InvLimit_Misc = value as Int
        StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Misc", InvLimit_Misc)
        SetSliderOptionValue(OID_InvLimit_Misc, value, "{0} items")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "invLimitMisc", "" + value)

    ; Survival sliders
    elseif option == OID_HungerRate
        If SurvivalScript
            SurvivalScript.HungerRate = value
            SetSliderOptionValue(OID_HungerRate, value, "{1}x")
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "hungerRate", "" + value)
        EndIf
    elseif option == OID_AutoEatThreshold
        If SurvivalScript
            SurvivalScript.AutoEatThreshold = value as Int
            SetSliderOptionValue(OID_AutoEatThreshold, value, "{0}%")
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "autoEatThreshold", "" + value)
        EndIf
    elseif option == OID_FatigueRate
        If SurvivalScript
            SurvivalScript.FatigueRate = value
            SetSliderOptionValue(OID_FatigueRate, value, "{1}x")
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "fatigueRate", "" + value)
        EndIf
    elseif option == OID_ColdRate
        If SurvivalScript
            SurvivalScript.ColdRate = value
            SetSliderOptionValue(OID_ColdRate, value, "{1}x")
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "coldRate", "" + value)
        EndIf

    ; Follower Manager sliders
    elseif option == OID_FM_MaxFollowers
        If FollowerManagerScript
            FollowerManagerScript.MaxFollowers = value as Int
            SetSliderOptionValue(OID_FM_MaxFollowers, value, "{0}")
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "maxFollowers", "" + value)
        EndIf
    elseif option == OID_FM_LeavingThreshold
        If FollowerManagerScript
            FollowerManagerScript.LeavingThreshold = value
            SetSliderOptionValue(OID_FM_LeavingThreshold, value, "{0}")
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "leavingThreshold", "" + value)
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
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "assessmentCooldownMin", "" + value)
        EndIf
    elseif option == OID_FM_AssessCooldownMax
        If FollowerManagerScript
            FollowerManagerScript.AssessmentCooldownMaxHours = value
            ; Clamp min if max falls below it
            If value < FollowerManagerScript.AssessmentCooldownMinHours
                FollowerManagerScript.AssessmentCooldownMinHours = value
                SetSliderOptionValue(OID_FM_AssessCooldownMin, value, "{1} hrs")
                SeverActionsNativeExt2.Native_SettingsRecord("settings", "assessmentCooldownMin", "" + value)
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
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "interFollowerCooldownMin", "" + value)
        EndIf
    elseif option == OID_FM_InterAssessCooldownMax
        If FollowerManagerScript
            FollowerManagerScript.InterFollowerCooldownMaxHours = value
            If value < FollowerManagerScript.InterFollowerCooldownMinHours
                FollowerManagerScript.InterFollowerCooldownMinHours = value
                SetSliderOptionValue(OID_FM_InterAssessCooldownMin, value, "{1} hrs")
                SeverActionsNativeExt2.Native_SettingsRecord("settings", "interFollowerCooldownMin", "" + value)
            EndIf
            SetSliderOptionValue(OID_FM_InterAssessCooldownMax, value, "{1} hrs")
        EndIf
    elseif option == OID_FM_OffScreenCooldownMin
        If FollowerManagerScript
            FollowerManagerScript.OffScreenLifeCooldownMinHours = value
            If value > FollowerManagerScript.OffScreenLifeCooldownMaxHours
                FollowerManagerScript.OffScreenLifeCooldownMaxHours = value
                SetSliderOptionValue(OID_FM_OffScreenCooldownMax, value, "{1} hrs")
                SeverActionsNativeExt2.Native_SettingsRecord("offscreen", "offScreenCooldownMax", "" + value)
            EndIf
            SetSliderOptionValue(OID_FM_OffScreenCooldownMin, value, "{1} hrs")
            SeverActionsNativeExt2.Native_SettingsRecord("offscreen", "offScreenCooldownMin", "" + value)
        EndIf
    elseif option == OID_FM_OffScreenCooldownMax
        If FollowerManagerScript
            FollowerManagerScript.OffScreenLifeCooldownMaxHours = value
            If value < FollowerManagerScript.OffScreenLifeCooldownMinHours
                FollowerManagerScript.OffScreenLifeCooldownMinHours = value
                SetSliderOptionValue(OID_FM_OffScreenCooldownMin, value, "{1} hrs")
                SeverActionsNativeExt2.Native_SettingsRecord("offscreen", "offScreenCooldownMin", "" + value)
            EndIf
            SetSliderOptionValue(OID_FM_OffScreenCooldownMax, value, "{1} hrs")
            SeverActionsNativeExt2.Native_SettingsRecord("offscreen", "offScreenCooldownMax", "" + value)
        EndIf
    elseif option == OID_FM_ConsequenceCooldown
        If FollowerManagerScript
            FollowerManagerScript.ConsequenceCooldownHours = value
            SetSliderOptionValue(OID_FM_ConsequenceCooldown, value, "{1} hrs")
            SeverActionsNativeExt2.Native_SettingsRecord("offscreen", "consequenceCooldown", "" + value)
        EndIf
    elseif option == OID_FM_AmbientBanterCooldownMin
        If FollowerManagerScript
            FollowerManagerScript.AmbientBanterCooldownMinHours = value
            If value > FollowerManagerScript.AmbientBanterCooldownMaxHours
                FollowerManagerScript.AmbientBanterCooldownMaxHours = value
                SetSliderOptionValue(OID_FM_AmbientBanterCooldownMax, value, "{1} hrs")
            EndIf
            SetSliderOptionValue(OID_FM_AmbientBanterCooldownMin, value, "{1} hrs")
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "ambientBanterCooldownMin", "" + value)
        EndIf
    elseif option == OID_FM_AmbientBanterCooldownMax
        If FollowerManagerScript
            FollowerManagerScript.AmbientBanterCooldownMaxHours = value
            If value < FollowerManagerScript.AmbientBanterCooldownMinHours
                FollowerManagerScript.AmbientBanterCooldownMinHours = value
                SetSliderOptionValue(OID_FM_AmbientBanterCooldownMin, value, "{1} hrs")
                SeverActionsNativeExt2.Native_SettingsRecord("settings", "ambientBanterCooldownMin", "" + value)
            EndIf
            SetSliderOptionValue(OID_FM_AmbientBanterCooldownMax, value, "{1} hrs")
        EndIf
    elseif option == OID_FM_QuestAwarenessOutputCap
        If FollowerManagerScript
            Int newCap = value as Int
            If newCap < 1
                newCap = 1
            ElseIf newCap > 15
                newCap = 15
            EndIf
            FollowerManagerScript.QuestAwarenessOutputCap = newCap
            ; Push to C++ immediately so the next prompt render uses the new cap
            ; without waiting for a game reload's boot sync.
            SeverActionsNative.Native_QuestAwareness_SetOutputCap(newCap)
            SetSliderOptionValue(OID_FM_QuestAwarenessOutputCap, newCap as Float, "{0}")
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "questAwarenessOutputCap", "" + newCap as Float)
        EndIf
    elseif option == OID_FM_MaxBounty
        If FollowerManagerScript
            FollowerManagerScript.MaxOffScreenBounty = value as Int
            SetSliderOptionValue(OID_FM_MaxBounty, value, "{0}")
            SeverActionsNativeExt2.Native_SettingsRecord("offscreen", "maxBounty", "" + value)
        EndIf
    elseif option == OID_FM_MaxGoldChange
        If FollowerManagerScript
            FollowerManagerScript.MaxOffScreenGoldChange = value as Int
            SetSliderOptionValue(OID_FM_MaxGoldChange, value, "{0}")
            SeverActionsNativeExt2.Native_SettingsRecord("offscreen", "maxGoldChange", "" + value)
        EndIf
    elseif option == OID_FM_DeathGracePeriod
        If FollowerManagerScript
            FollowerManagerScript.DeathGracePeriodHours = value
            SetSliderOptionValue(OID_FM_DeathGracePeriod, value, "{0} hrs")
        EndIf
    elseif option == OID_FM_StabilityDelay
        FMStabilityDelay = value
        SeverActionsNativeExt.SituationMonitor_SetStabilityThreshold((value * 1000.0) as Int)
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
    elseif option == OID_UIScale
        SetInfoText("PrismaUI menu density. Use this if Prisma renders too large for your screen and you can't reach the in-app Settings slider. Takes effect the next time you open PrismaUI. Range 0.8-2.0, default 1.0.")
    elseif option == OID_BookReadMode
        SetInfoText("How NPCs read books aloud. Verbatim: reads word-for-word (takes longer). Summarize: gives a summary and shares their in-character thoughts. Default: Read Aloud.")
    elseif option == OID_IntimacyEnabled
        SetInfoText("Render the Intimacy & Consent section in NPC bios - how open an NPC is to advances, driven by relationship and their own personality. Nothing is tracked or recorded on this side; intimate-history tracking lives in the SeverActionsNSFW plugin (whose consent section takes over automatically when installed).")
    elseif option == OID_IntimacyGenderGate
        SetInfoText("Whose bios render the Intimacy & Consent section: Everyone, Women only, or Men only.")

    elseif option == OID_SpellFailEnabled
        SetInfoText("Enable the spell failure system. When enabled, learning spells above Novice tier has a chance to fail with school-specific consequences (explosions, hostile summons, etc).")
    elseif option == OID_SpellFailDifficulty
        SetInfoText("Multiplier for failure chance. 0.5 = half as likely to fail, 1.0 = normal, 2.0 = twice as likely. Set to 0 to disable failures without turning off the system.")

    elseif option == OID_InvLimit_Weapons || option == OID_InvLimit_Armor || option == OID_InvLimit_Potions || option == OID_InvLimit_Ingredients || option == OID_InvLimit_Books || option == OID_InvLimit_Scrolls || option == OID_InvLimit_Ammo || option == OID_InvLimit_Keys || option == OID_InvLimit_Misc
        SetInfoText("Max items shown to the AI for this category (0-20). Set to 0 to hide the category entirely. Higher values give the AI more context but use more tokens.")

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
    elseif option == OID_ClearHomeKey
        SetInfoText("Hotkey to CLEAR the targeted NPC's home. Point at any NPC stuck with a bad home and press it - releases SeverActions' home sandbox so the NPC (or NFF) takes back over. Works on any NPC, follower or not.")

    elseif option == OID_SetupCampKey
        SetInfoText("Hotkey to set up camp (requires Sever's Hearth). A solid ghost of the whole camp appears ahead of you - aim with your view, Q/E to rotate, Activate to confirm, Tab to cancel.")

    elseif option == OID_TieUntieKey
        SetInfoText("Aim at an NPC and press: if their hands are bound - by you OR by another NPC - you untie them and let them go. If they are free, you seize and bind them on the spot. Each press tells the AI exactly what happened, so it works even when dialogue alone did not trigger the action.")
    elseif option == OID_DropMarkerKey
        SetInfoText("Drop a named travel marker at your feet (auto-named; rename later). Use these to name areas inside a home - the kitchen, the study - so NPCs can be sent to them and homed NPCs can live between them.")

    elseif option == OID_StandUpKey
        SetInfoText("Hotkey to make an NPC stand up from furniture. Look at the NPC and press this key to make them get up from chairs, beds, workstations, etc.")

    elseif option == OID_UseFurnitureKey
        SetInfoText("Two-step hotkey to send an NPC to use furniture. Aim at an NPC and press once to select them, then aim at a chair / bed / workstation and press again to send them to use it. Selection resets after 30s.")

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
        SetInfoText("Hotkey to open the PrismaUI config menu. Requires PrismaUI mod. Default: Shift+8.")
    elseif option == OID_ConfigMenuShift
        SetInfoText("When enabled, you must hold Shift while pressing the config menu key. Frees up the key for other uses when Shift is not held.")

    ; Bounty page tooltips
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
        SetInfoText("Maximum number of companions allowed at once (0 = unlimited). Default: 100")
    elseif option == OID_FM_AllowLeaving
        SetInfoText("When enabled, companions with very low rapport may decide to leave on their own. Disable for companions that never leave regardless of treatment.")
    elseif option == OID_FM_RoomRotation
        SetInfoText("Homed NPCs drift between the named markers dropped in their home every 1-3 in-game hours (drop markers with the Drop Named Marker hotkey). Disable to keep home sandboxing anchored to one spot. Default: ON")
    elseif option == OID_FM_KidnapEnabled
        SetInfoText("Villain-playthrough content: lets you order a companion to abduct a named NPC and hold them bound and hooded at a destination. WARNING: holding an essential or quest-relevant NPC captive can break their later quest content. Default: OFF")
    elseif option == OID_FM_RestrainEnabled
        SetInfoText("Lets any NPC be ordered to restrain a named NPC in the same scene: they walk over, bind their hands, and hold them standing bound (no hood) until released or moved. An open, ordered act with no automatic crime consequences. Default: ON")
    elseif option == OID_FM_LeavingThreshold
        SetInfoText("Rapport level at which companions may decide to leave. Lower values (closer to -100) mean they tolerate more mistreatment. Default: -60")
    elseif option == OID_FM_AutoSwitch
        SetInfoText("When enabled, companions automatically change outfits based on their situation (town, adventure, home, sleep). Requires outfit presets assigned to situations.")
    elseif option == OID_FM_StabilityDelay
        SetInfoText("How long a situation must be stable before triggering an outfit change. Higher values prevent flickering at town gates. Default: 5 seconds.")
    elseif option == OID_FM_PerActorAutoSwitch
        SetInfoText("Toggle automatic outfit switching for this specific companion. When disabled, this companion will not change outfits based on situation even if the global setting is enabled.")
    elseif option == OID_FM_FrameworkMode
        SetInfoText("How new followers are managed.\nSeverActions: Full control - teammate status, follow packages, outfit lock, relationships, essential toggle.\nTracking: Observe only - outfit lock and relationships, but no teammate or AI management. Use when another mod handles recruitment.\nSPID keyword holders and NFF token holders auto-route to Tracking regardless.\nTakes effect on next recruit.")
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
        SetInfoText("Maximum game hours between off-screen life events per dismissed follower. Random cooldown between min and max. Default: 72 hours.")
    elseif option == OID_FM_OffScreenConsequences
        SetInfoText("When enabled, off-screen life events may have real consequences: followers can get arrested, earn or lose gold, or take on debt. Events are personality-driven - principled followers rarely commit crimes. Default: ON.")
    elseif option == OID_FM_ConsequenceCooldown
        SetInfoText("Game hours between consequential off-screen events per follower. Consequences are rarer than regular events. Default: 36 hours.")
    elseif option == OID_FM_AutoAmbientBanter
        SetInfoText("When enabled, nearby non-follower NPCs occasionally talk to each other so populated areas feel alive without requiring player input. Hostile cells (dungeons / bandit camps / under-attack settlements) are skipped automatically. Default: ON.")
    elseif option == OID_FM_AmbientBanterCooldownMin
        SetInfoText("Minimum game hours between ambient NPC banter cycles. The cooldown is global, not per-NPC. Default: 3 hours.")
    elseif option == OID_FM_AmbientBanterCooldownMax
        SetInfoText("Maximum game hours between ambient NPC banter cycles. Each cycle picks a random cooldown between min and max. Default: 7 hours.")
    elseif option == OID_FM_QuestAwarenessOutputCap
        SetInfoText("Maximum quest awareness entries followers see in dialogue context per render. Newest entries fill the budget first; completed quests with memories are skipped automatically. The per-follower storage cap (30) is unaffected - this only controls how many reach the LLM. Range: 1-15. Default: 5.")
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
    elseif option == OID_Outfit_DeferBondage
        SetInfoText("When enabled (default), SeverActions stops enforcing outfits on NPCs captured, enslaved, or tied up by Diary of Mine / Paradise Halls, so it won't fight their strip, restraints, or weapon swaps. Disable to let SeverActions re-equip locked outfits even on those NPCs. No effect if neither mod is installed.")
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
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "dialogueAnimEnabled", BoolToStr(true))
        SeverActionsNative.SetDialogueAnimEnabled(true)
    elseif option == OID_IntimacyEnabled
        If FollowerManagerScript
            FollowerManagerScript.IntimateHistoryEnabled = true
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "intimacyEnabled", "true")
            SeverActionsNativeExt2.Native_IntimateHistory_SetEnabled(true)  ; live-apply (PR #442 review)
            SetToggleOptionValue(OID_IntimacyEnabled, true)
        EndIf
    elseif option == OID_IntimacyGenderGate
        If FollowerManagerScript
            FollowerManagerScript.IntimacyGenderGate = 1
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "intimacyGenderGate", "1")
            SeverActionsNativeExt2.Native_IntimateHistory_SetGenderGate(1)  ; live-apply (PR #442 review)
            SetMenuOptionValue(OID_IntimacyGenderGate, IntimacyGenderOptions[1])
        EndIf
    elseif option == OID_SilenceChance
        SilenceChance = 50
        StorageUtil.SetIntValue(None, "SeverActions_ZeroChance", 50)
        SetSliderOptionValue(OID_SilenceChance, 50.0, "{0}%")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "silenceChance", "" + 50.0)
    elseif option == OID_UIScale
        If FollowerManagerScript
            FollowerManagerScript.UIScale = 1.0
            StorageUtil.SetFloatValue(None, "SeverActions_UIScale", 1.0)
        EndIf
        SetSliderOptionValue(OID_UIScale, 1.0, "{2}x")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "uiScale", "" + 1.0)
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
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "spellFailEnabled", BoolToStr(true))
        endif
    elseif option == OID_SpellFailDifficulty
        if SpellTeachScript
            SpellTeachScript.FailureDifficultyMult = 1.0
            StorageUtil.SetFloatValue(None, "SeverActions_SpellFailDifficulty", 1.0)
            SetSliderOptionValue(OID_SpellFailDifficulty, 1.0, "{1}x")
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "spellFailDifficulty", "" + 1.0)
        endif

    elseif option == OID_InvLimit_Weapons
        InvLimit_Weapons = 10
        StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Weapons", 10)
        SetSliderOptionValue(OID_InvLimit_Weapons, 10.0, "{0} items")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "invLimitWeapons", "" + 10.0)
    elseif option == OID_InvLimit_Armor
        InvLimit_Armor = 10
        StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Armor", 10)
        SetSliderOptionValue(OID_InvLimit_Armor, 10.0, "{0} items")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "invLimitArmor", "" + 10.0)
    elseif option == OID_InvLimit_Potions
        InvLimit_Potions = 10
        StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Potions", 10)
        SetSliderOptionValue(OID_InvLimit_Potions, 10.0, "{0} items")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "invLimitPotions", "" + 10.0)
    elseif option == OID_InvLimit_Ingredients
        InvLimit_Ingredients = 5
        StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Ingredients", 5)
        SetSliderOptionValue(OID_InvLimit_Ingredients, 5.0, "{0} items")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "invLimitIngredients", "" + 5.0)
    elseif option == OID_InvLimit_Books
        InvLimit_Books = 10
        StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Books", 10)
        SetSliderOptionValue(OID_InvLimit_Books, 10.0, "{0} items")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "invLimitBooks", "" + 10.0)
    elseif option == OID_InvLimit_Scrolls
        InvLimit_Scrolls = 5
        StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Scrolls", 5)
        SetSliderOptionValue(OID_InvLimit_Scrolls, 5.0, "{0} items")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "invLimitScrolls", "" + 5.0)
    elseif option == OID_InvLimit_Ammo
        InvLimit_Ammo = 5
        StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Ammo", 5)
        SetSliderOptionValue(OID_InvLimit_Ammo, 5.0, "{0} items")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "invLimitAmmo", "" + 5.0)
    elseif option == OID_InvLimit_Keys
        InvLimit_Keys = 5
        StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Keys", 5)
        SetSliderOptionValue(OID_InvLimit_Keys, 5.0, "{0} items")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "invLimitKeys", "" + 5.0)
    elseif option == OID_InvLimit_Misc
        InvLimit_Misc = 5
        StorageUtil.SetIntValue(None, "SeverActions_InvLimit_Misc", 5)
        SetSliderOptionValue(OID_InvLimit_Misc, 5.0, "{0} items")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "invLimitMisc", "" + 5.0)

    elseif option == OID_TagCompanion
        TagCompanionEnabled = true
        StorageUtil.SetIntValue(None, "SeverActions_TagCompanion", 1)
        SetToggleOptionValue(OID_TagCompanion, true)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "tagCompanion", BoolToStr(true))
    elseif option == OID_TagEngaged
        TagEngagedEnabled = true
        StorageUtil.SetIntValue(None, "SeverActions_TagEngaged", 1)
        SetToggleOptionValue(OID_TagEngaged, true)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "tagEngaged", BoolToStr(true))
    elseif option == OID_TagInScene
        TagInSceneEnabled = true
        StorageUtil.SetIntValue(None, "SeverActions_TagInScene", 1)
        SetToggleOptionValue(OID_TagInScene, true)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "tagInScene", BoolToStr(true))

    elseif option == OID_AllowConjuredGold
        AllowConjuredGold = true
        SetToggleOptionValue(OID_AllowConjuredGold, AllowConjuredGold)
        SeverActionsNativeExt2.Native_SettingsRecord("world", "allowConjuredGold", BoolToStr(AllowConjuredGold))
        ApplyCurrencySettings()
        
    elseif option == OID_FollowToggleKey
        FollowToggleKey = -1
        SetKeyMapOptionValue(OID_FollowToggleKey, FollowToggleKey)
        ApplyHotkeySettings()
        
    elseif option == OID_DismissKey
        DismissKey = -1
        SetKeyMapOptionValue(OID_DismissKey, DismissKey)
        ApplyHotkeySettings()

    elseif option == OID_SetCompanionKey
        SetCompanionKey = -1
        SetKeyMapOptionValue(OID_SetCompanionKey, SetCompanionKey)
        ApplyHotkeySettings()
        
    elseif option == OID_StandUpKey
        StandUpKey = -1
        SetKeyMapOptionValue(OID_StandUpKey, StandUpKey)
        ApplyHotkeySettings()

    elseif option == OID_UseFurnitureKey
        UseFurnitureKey = -1
        SetKeyMapOptionValue(OID_UseFurnitureKey, UseFurnitureKey)
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
    elseif option == OID_ClearHomeKey
        ClearHomeKey = -1
        SetKeyMapOptionValue(OID_ClearHomeKey, ClearHomeKey)
        ApplyHotkeySettings()

    elseif option == OID_SetupCampKey
        SetupCampKey = -1
        SetKeyMapOptionValue(OID_SetupCampKey, SetupCampKey)
        ApplyHotkeySettings()

    elseif option == OID_DropMarkerKey
        DropMarkerKey = -1
        SetKeyMapOptionValue(OID_DropMarkerKey, DropMarkerKey)
        ApplyHotkeySettings()
    elseif option == OID_TieUntieKey
        TieUntieKey = -1
        SetKeyMapOptionValue(OID_TieUntieKey, TieUntieKey)
        ApplyHotkeySettings()

    elseif option == OID_WheelMenuKey
        WheelMenuKey = -1
        SetKeyMapOptionValue(OID_WheelMenuKey, WheelMenuKey)
        ApplyWheelMenuSettings()

    elseif option == OID_ConfigMenuKey
        ConfigMenuKey = 9
        SetKeyMapOptionValue(OID_ConfigMenuKey, ConfigMenuKey)
        ApplyConfigMenuKeySettings()
    elseif option == OID_ConfigMenuShift
        ConfigMenuRequireShift = true
        SetToggleOptionValue(OID_ConfigMenuShift, ConfigMenuRequireShift)
        ApplyConfigMenuKeySettings()

    elseif option == OID_ArrestCooldown
        If ArrestScript
            ArrestScript.ArrestPlayerCooldown = 60.0
            SetSliderOptionValue(OID_ArrestCooldown, 60.0, "{0} sec")
            SeverActionsNativeExt2.Native_SettingsRecord("world", "arrestCooldown", "" + 60.0)
        EndIf
    elseif option == OID_TruceEnabled
        CombatScript.TruceEnabled = false
        SetToggleOptionValue(OID_TruceEnabled, false)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "truceEnabled", "false")
    elseif option == OID_TruceRadius
        CombatScript.TruceRadius = 8000.0
        SetSliderOptionValue(OID_TruceRadius, 8000.0, "{0} units")
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "truceRadius", "" + 8000.0)
    elseif option == OID_TruceLeaders
        CombatScript.TruceLeaders = true
        SetToggleOptionValue(OID_TruceLeaders, true)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "truceLeaders", "true")
    elseif option == OID_TruceQuestNPCs
        CombatScript.TruceQuestNPCs = true
        SetToggleOptionValue(OID_TruceQuestNPCs, true)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "truceQuestNPCs", "true")
    elseif option == OID_TruceDungeons
        CombatScript.TruceDungeons = false
        SetToggleOptionValue(OID_TruceDungeons, false)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "truceDungeons", "false")
    elseif option == OID_TruceNecro
        CombatScript.TruceNecromancers = true
        SetToggleOptionValue(OID_TruceNecro, true)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "truceNecromancers", "true")
    elseif option == OID_TruceForsworn
        CombatScript.TruceForsworn = true
        SetToggleOptionValue(OID_TruceForsworn, true)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "truceForsworn", "true")
    elseif option == OID_TruceVampires
        CombatScript.TruceVampires = true
        SetToggleOptionValue(OID_TruceVampires, true)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "truceVampires", "true")
    elseif option == OID_CampTakeover
        CombatScript.CampTakeoverEnabled = true
        SetToggleOptionValue(OID_CampTakeover, true)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "campTakeoverEnabled", "true")
    elseif option == OID_CampChallenge
        CombatScript.CampChallengeEnabled = true
        SetToggleOptionValue(OID_CampChallenge, true)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "campChallengeEnabled", "true")
    elseif option == OID_CampChallengeCard
        CombatScript.CampChallengeCardEnabled = false
        SetToggleOptionValue(OID_CampChallengeCard, false)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "campChallengeCard", "false")
    elseif option == OID_ChallengeParleySeconds
        CombatScript.ChallengeParleySeconds = 120.0
        SetSliderOptionValue(OID_ChallengeParleySeconds, 120.0, "{0} sec")
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "campChallengeSeconds", "" + 120.0)
    elseif option == OID_CampFreezeRespawn
        CombatScript.CampFreezeRespawn = true
        SetToggleOptionValue(OID_CampFreezeRespawn, true)
        CombatScript.PushTruceConfigToNative()
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "campFreezeRespawn", "true")
    elseif option == OID_YieldPersistence
        CombatScript.YieldPersistenceEnabled = true
        SetToggleOptionValue(OID_YieldPersistence, true)
    elseif option == OID_CombatCooldown
        CombatScript.CombatCooldownDuration = 30.0
        SetSliderOptionValue(OID_CombatCooldown, 30.0, "{0} sec")
    elseif option == OID_DebuffSeverity
        SurvivalScript.DebuffSeverity = 1.0
        SetSliderOptionValue(OID_DebuffSeverity, 1.0, "{2}x")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "debuffSeverity", "" + 1.0)
    elseif option == OID_SurvNotifHunger
        SurvivalScript.ShowHungerNotifications = true
        SetToggleOptionValue(OID_SurvNotifHunger, true)
    elseif option == OID_SurvNotifFatigue
        SurvivalScript.ShowFatigueNotifications = true
        SetToggleOptionValue(OID_SurvNotifFatigue, true)
    elseif option == OID_SurvNotifCold
        SurvivalScript.ShowColdNotifications = true
        SetToggleOptionValue(OID_SurvNotifCold, true)
    elseif option == OID_ArrestBountyThreshold
        ArrestScript.ArrestBountyThreshold = 300
        SetSliderOptionValue(OID_ArrestBountyThreshold, 300.0, "{0}g")
    elseif option == OID_BribeMult
        ArrestScript.BribeMultiplier = 1.5
        SetSliderOptionValue(OID_BribeMult, 1.5, "{2}x")
    elseif option == OID_ResistBounty
        ArrestScript.ResistBountyIncrease = 500
        SetSliderOptionValue(OID_ResistBounty, 500.0, "{0}g")
    elseif option == OID_DebtOverdue
        FollowerManagerScript.DebtScript.EnableOverdueReminders = true
        SetToggleOptionValue(OID_DebtOverdue, true)
        SeverActionsNativeExt2.Native_SettingsRecord("world", "overdueReminders", "true")
    elseif option == OID_DebtGrace
        FollowerManagerScript.DebtScript.OverdueGracePeriodHours = 24.0
        SetSliderOptionValue(OID_DebtGrace, 24.0, "{0} hrs")
        SeverActionsNativeExt2.Native_SettingsRecord("world", "gracePeriod", "" + 24.0)
    elseif option == OID_DebtReport
        FollowerManagerScript.DebtScript.ReportThresholdHours = 72.0
        SetSliderOptionValue(OID_DebtReport, 72.0, "{0} hrs")
        SeverActionsNativeExt2.Native_SettingsRecord("world", "reportThreshold", "" + 72.0)
    elseif option == OID_TravelMapMarkers
        TravelScript.TravelMapMarkersEnabled = true
        SetToggleOptionValue(OID_TravelMapMarkers, true)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "travelMapMarkersEnabled", "true")
    elseif option == OID_FollowersCanTravel
        SeverActionsNativeExt2.Native_SetFollowersCanTravel(false)
        SetToggleOptionValue(OID_FollowersCanTravel, false)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "followersCanTravel", "false")
    elseif option == OID_Outfit_UseAnimations
        OutfitScript.UseAnimations = true
        SetToggleOptionValue(OID_Outfit_UseAnimations, true)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "useAnimations", "true")
    elseif option == OID_FM_AutoQuestAwareness
        FollowerManagerScript.AutoQuestAwareness = true
        SetToggleOptionValue(OID_FM_AutoQuestAwareness, true)
        SeverActionsNativeExt.Native_QuestAwareness_SetEnabled(true)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "questAwarenessEnabled", "true")
    elseif option == OID_FM_AutoNPCReputation
        FollowerManagerScript.AutoNPCReputation = true
        SetToggleOptionValue(OID_FM_AutoNPCReputation, true)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "npcReputationEnabled", "true")
    elseif option == OID_FM_AutoFollowerBanter
        FollowerManagerScript.AutoFollowerBanter = true
        SetToggleOptionValue(OID_FM_AutoFollowerBanter, true)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "followerBanterEnabled", "true")
    elseif option == OID_FM_AutoAmbientActions
        FollowerManagerScript.AutoAmbientActions = false
        SetToggleOptionValue(OID_FM_AutoAmbientActions, false)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "ambientActionsEnabled", "false")
    elseif option == OID_FM_HomeSleepEnabled
        FollowerManagerScript.HomeSleepEnabled = true
        SetToggleOptionValue(OID_FM_HomeSleepEnabled, true)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "homeSleepEnabled", "true")
    elseif option == OID_FM_CellCatchup
        FollowerManagerScript.CellCatchupEnabled = true
        SetToggleOptionValue(OID_FM_CellCatchup, true)
    elseif option == OID_FM_SchedWorkStart
        FollowerManagerScript.SCHEDULE_WORK_START = 8.0
        SetSliderOptionValue(OID_FM_SchedWorkStart, 8.0, "{0}:00")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "scheduleWorkStart", "" + 8.0)
    elseif option == OID_FM_SchedWorkEnd
        FollowerManagerScript.SCHEDULE_WORK_END = 17.0
        SetSliderOptionValue(OID_FM_SchedWorkEnd, 17.0, "{0}:00")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "scheduleWorkEnd", "" + 17.0)
    elseif option == OID_FM_SchedPlayStart
        FollowerManagerScript.SCHEDULE_PLAY_START = 17.0
        SetSliderOptionValue(OID_FM_SchedPlayStart, 17.0, "{0}:00")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "schedulePlayStart", "" + 17.0)
    elseif option == OID_FM_SchedPlayEnd
        FollowerManagerScript.SCHEDULE_PLAY_END = 22.0
        SetSliderOptionValue(OID_FM_SchedPlayEnd, 22.0, "{0}:00")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "schedulePlayEnd", "" + 22.0)
    elseif option == OID_FM_HomeSleepStart
        FollowerManagerScript.HomeSleepStart = 22.0
        SetSliderOptionValue(OID_FM_HomeSleepStart, 22.0, "{0}:00")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "homeSleepStart", "" + 22.0)
    elseif option == OID_FM_HomeSleepEnd
        FollowerManagerScript.HomeSleepEnd = 6.0
        SetSliderOptionValue(OID_FM_HomeSleepEnd, 6.0, "{0}:00")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "homeSleepEnd", "" + 6.0)
    elseif option == OID_FM_TeleportDist
        FollowerManagerScript.FollowerTeleportDistance = 2000.0
        SetSliderOptionValue(OID_FM_TeleportDist, 2000.0, "{0}")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "followerTeleportDistance", "" + 2000.0)
    elseif option == OID_FM_TeleportCooldown
        FollowerManagerScript.TeleportCooldownSeconds = 30
        SetSliderOptionValue(OID_FM_TeleportCooldown, 30.0, "{0} sec")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "teleportCooldown", "" + 30.0)
    elseif option == OID_Ent_Loans
        FollowerManagerScript.EnterpriseLoansEnabled = true
        SetToggleOptionValue(OID_Ent_Loans, true)
        SeverActionsNativeExt2.Venture_SetLoansEnabled(true)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "enterpriseLoansEnabled", "true")
    elseif option == OID_Ent_Raises
        FollowerManagerScript.EnterpriseRaisesEnabled = true
        SetToggleOptionValue(OID_Ent_Raises, true)
        SeverActionsNativeExt2.Venture_SetRaisesEnabled(true)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "enterpriseRaisesEnabled", "true")
    elseif option == OID_Ent_Temper
        FollowerManagerScript.EnterpriseTemperEnabled = true
        SetToggleOptionValue(OID_Ent_Temper, true)
        SeverActionsNativeExt2.Venture_SetTemperEnabled(true)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "enterpriseTemperEnabled", "true")
    elseif option == OID_Ent_Ambushes
        FollowerManagerScript.EnterpriseAmbushesEnabled = true
        SetToggleOptionValue(OID_Ent_Ambushes, true)
        SeverActionsNativeExt2.Venture_SetAmbushesEnabled(true)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "enterpriseAmbushesEnabled", "true")
    elseif option == OID_Ent_RenownCap
        FollowerManagerScript.EnterpriseRenownCapEnabled = true
        SetToggleOptionValue(OID_Ent_RenownCap, true)
        SeverActionsNativeExt2.Venture_SetRenownCapEnabled(true)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "enterpriseRenownCapEnabled", "true")
    elseif option == OID_Ent_OutputPct
        FollowerManagerScript.EnterpriseOutputPct = 100
        SeverActionsNativeExt2.Venture_SetProductionMult(FollowerManagerScript.EnterpriseOutputPct)
        SetSliderOptionValue(OID_Ent_OutputPct, 100.0, "{0}%")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "enterpriseOutputPct", "" + 100.0)
    elseif option == OID_Ent_StoryCap
        FollowerManagerScript.EnterpriseStoryCap = -1
        SeverActionsNativeExt2.Venture_SetStoryCap(FollowerManagerScript.EnterpriseStoryCap)
        SetSliderOptionValue(OID_Ent_StoryCap, -1.0, "{0}")
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "enterpriseStoryCap", "" + -1.0)
    elseif option == OID_LLMCallsEnabled
        SeverActionsNativeExt2.Native_SetLLMCallsEnabled(true)
        SetToggleOptionValue(OID_LLMCallsEnabled, true)
        SeverActionsNativeExt2.Native_SettingsRecord("settings", "llmCallsEnabled", "true")

    elseif option == OID_PersuasionTimeLimit
        If ArrestScript
            ArrestScript.PersuasionTimeLimit = 90.0
            SetSliderOptionValue(OID_PersuasionTimeLimit, 90.0, "{0} sec")
            SeverActionsNativeExt2.Native_SettingsRecord("world", "persuasionTimeLimit", "" + 90.0)
        EndIf

    ; Survival defaults
    elseif option == OID_SurvivalEnabled
        If SurvivalScript
            SurvivalScript.Enabled = true
            SetToggleOptionValue(OID_SurvivalEnabled, true)
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "survivalEnabled", BoolToStr(true))
            SurvivalScript.StartTracking()
        EndIf
    elseif option == OID_HungerEnabled
        If SurvivalScript
            SurvivalScript.HungerEnabled = true
            SetToggleOptionValue(OID_HungerEnabled, true)
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "hungerEnabled", BoolToStr(true))
        EndIf
    elseif option == OID_HungerRate
        If SurvivalScript
            SurvivalScript.HungerRate = 1.0
            SetSliderOptionValue(OID_HungerRate, 1.0, "{1}x")
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "hungerRate", "" + 1.0)
        EndIf
    elseif option == OID_AutoEatThreshold
        If SurvivalScript
            SurvivalScript.AutoEatThreshold = 50
            SetSliderOptionValue(OID_AutoEatThreshold, 50.0, "{0}%")
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "autoEatThreshold", "" + 50.0)
        EndIf
    elseif option == OID_FatigueEnabled
        If SurvivalScript
            SurvivalScript.FatigueEnabled = true
            SetToggleOptionValue(OID_FatigueEnabled, true)
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "fatigueEnabled", BoolToStr(true))
        EndIf
    elseif option == OID_FatigueRate
        If SurvivalScript
            SurvivalScript.FatigueRate = 1.0
            SetSliderOptionValue(OID_FatigueRate, 1.0, "{1}x")
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "fatigueRate", "" + 1.0)
        EndIf
    elseif option == OID_ColdEnabled
        If SurvivalScript
            SurvivalScript.ColdEnabled = true
            SetToggleOptionValue(OID_ColdEnabled, true)
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "coldEnabled", BoolToStr(true))
        EndIf
    elseif option == OID_ColdRate
        If SurvivalScript
            SurvivalScript.ColdRate = 1.0
            SetSliderOptionValue(OID_ColdRate, 1.0, "{1}x")
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "coldRate", "" + 1.0)
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
            FollowerManagerScript.MaxFollowers = 100
            SetSliderOptionValue(OID_FM_MaxFollowers, 100.0, "{0}")
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "maxFollowers", "" + 100.0)
        EndIf
    elseif option == OID_FM_AllowLeaving
        If FollowerManagerScript
            FollowerManagerScript.AllowAutonomousLeaving = true
            SetToggleOptionValue(OID_FM_AllowLeaving, true)
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "allowAutonomousLeaving", BoolToStr(true))
        EndIf
    elseif option == OID_FM_RoomRotation
        If FollowerManagerScript
            FollowerManagerScript.RoomRotationEnabled = true
            SetToggleOptionValue(OID_FM_RoomRotation, true)
        EndIf
    elseif option == OID_FM_KidnapEnabled
        If FollowerManagerScript
            FollowerManagerScript.EnableKidnapActions = false
            SetToggleOptionValue(OID_FM_KidnapEnabled, false)
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "kidnapEnabled", BoolToStr(false))
            SeverActionsNativeExt.Native_Kidnap_SetEnabled(false)
        EndIf
    elseif option == OID_FM_RestrainEnabled
        If FollowerManagerScript
            FollowerManagerScript.EnableRestrainAction = true
            SetToggleOptionValue(OID_FM_RestrainEnabled, true)
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "restrainEnabled", BoolToStr(true))
            SeverActionsNativeExt.Native_Restrain_SetEnabled(true)
        EndIf
    elseif option == OID_FM_LeavingThreshold
        If FollowerManagerScript
            FollowerManagerScript.LeavingThreshold = -60.0
            SetSliderOptionValue(OID_FM_LeavingThreshold, -60.0, "{0}")
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "leavingThreshold", "" + -60.0)
        EndIf
    elseif option == OID_FM_RelCooldown
        If FollowerManagerScript
            FollowerManagerScript.RelationshipCooldown = 120.0
            SetSliderOptionValue(OID_FM_RelCooldown, 120.0, "{0} sec")
        EndIf
    elseif option == OID_FM_AutoSwitch
        SeverActionsNativeExt.SituationMonitor_SetEnabled(true)
        StorageUtil.SetIntValue(None, "SeverOutfit_GlobalAutoSwitch", 1)
        SetToggleOptionValue(OID_FM_AutoSwitch, true)
    elseif option == OID_FM_StabilityDelay
        FMStabilityDelay = 5.0
        SeverActionsNativeExt.SituationMonitor_SetStabilityThreshold(5000)
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
    elseif option == OID_Outfit_DeferBondage
        StorageUtil.SetIntValue(None, "SeverOutfit_DeferBondage", 1)
        SeverActionsNativeExt.Native_Outfit_SetDeferBondage(true)
        SetToggleOptionValue(OID_Outfit_DeferBondage, true)
    elseif option == OID_FM_FrameworkMode
        If FollowerManagerScript
            FollowerManagerScript.FrameworkMode = 0
            ; Reset must write through as well - without this the global file
            ; keeps the old value and the load-time replay undoes the reset,
            ; which is the reported bug arriving through the other control.
            SeverActionsNativeExt2.Native_SettingsRecord("companions", "frameworkMode", "0")
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
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "trackRelationships", BoolToStr(true))
        EndIf
    elseif option == OID_FM_AssessCooldownMin
        If FollowerManagerScript
            FollowerManagerScript.AssessmentCooldownMinHours = 4.0
            SetSliderOptionValue(OID_FM_AssessCooldownMin, 4.0, "{1} hrs")
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "assessmentCooldownMin", "" + 4.0)
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
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "interFollowerAssessment", BoolToStr(true))
        EndIf
    elseif option == OID_FM_InterAssessCooldownMin
        If FollowerManagerScript
            FollowerManagerScript.InterFollowerCooldownMinHours = 6.0
            SetSliderOptionValue(OID_FM_InterAssessCooldownMin, 6.0, "{1} hrs")
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "interFollowerCooldownMin", "" + 6.0)
        EndIf
    elseif option == OID_FM_InterAssessCooldownMax
        If FollowerManagerScript
            FollowerManagerScript.InterFollowerCooldownMaxHours = 14.0
            SetSliderOptionValue(OID_FM_InterAssessCooldownMax, 14.0, "{1} hrs")
        EndIf
    elseif option == OID_FM_AutoAmbientBanter
        If FollowerManagerScript
            FollowerManagerScript.AutoAmbientBanter = true
            SetToggleOptionValue(OID_FM_AutoAmbientBanter, true)
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "ambientBanterEnabled", BoolToStr(true))
        EndIf
    elseif option == OID_FM_AmbientBanterCooldownMin
        If FollowerManagerScript
            FollowerManagerScript.AmbientBanterCooldownMinHours = 3.0
            SetSliderOptionValue(OID_FM_AmbientBanterCooldownMin, 3.0, "{1} hrs")
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "ambientBanterCooldownMin", "" + 3.0)
        EndIf
    elseif option == OID_FM_AmbientBanterCooldownMax
        If FollowerManagerScript
            FollowerManagerScript.AmbientBanterCooldownMaxHours = 7.0
            SetSliderOptionValue(OID_FM_AmbientBanterCooldownMax, 7.0, "{1} hrs")
        EndIf
    elseif option == OID_FM_QuestAwarenessOutputCap
        If FollowerManagerScript
            FollowerManagerScript.QuestAwarenessOutputCap = 5
            SeverActionsNative.Native_QuestAwareness_SetOutputCap(5)
            SetSliderOptionValue(OID_FM_QuestAwarenessOutputCap, 5.0, "{0}")
            SeverActionsNativeExt2.Native_SettingsRecord("settings", "questAwarenessOutputCap", "" + 5.0)
        EndIf
    elseif option == OID_FM_AutoOffScreenLife
        If FollowerManagerScript
            FollowerManagerScript.AutoOffScreenLife = true
            SetToggleOptionValue(OID_FM_AutoOffScreenLife, true)
            SeverActionsNativeExt2.Native_SettingsRecord("offscreen", "autoOffScreenLife", BoolToStr(true))
        EndIf
    elseif option == OID_FM_OffScreenCooldownMin
        If FollowerManagerScript
            FollowerManagerScript.OffScreenLifeCooldownMinHours = 10.0
            SetSliderOptionValue(OID_FM_OffScreenCooldownMin, 10.0, "{1} hrs")
            SeverActionsNativeExt2.Native_SettingsRecord("offscreen", "offScreenCooldownMin", "" + 10.0)
        EndIf
    elseif option == OID_FM_OffScreenCooldownMax
        If FollowerManagerScript
            FollowerManagerScript.OffScreenLifeCooldownMaxHours = 72.0
            SetSliderOptionValue(OID_FM_OffScreenCooldownMax, 72.0, "{1} hrs")
            SeverActionsNativeExt2.Native_SettingsRecord("offscreen", "offScreenCooldownMax", "" + 72.0)
        EndIf
    elseif option == OID_FM_OffScreenConsequences
        If FollowerManagerScript
            FollowerManagerScript.OffScreenConsequences = true
            SetToggleOptionValue(OID_FM_OffScreenConsequences, true)
            SeverActionsNativeExt2.Native_SettingsRecord("offscreen", "consequencesEnabled", BoolToStr(true))
        EndIf
    elseif option == OID_FM_ConsequenceCooldown
        If FollowerManagerScript
            FollowerManagerScript.ConsequenceCooldownHours = 36.0
            SetSliderOptionValue(OID_FM_ConsequenceCooldown, 36.0, "{1} hrs")
            SeverActionsNativeExt2.Native_SettingsRecord("offscreen", "consequenceCooldown", "" + 36.0)
        EndIf
    elseif option == OID_FM_MaxBounty
        If FollowerManagerScript
            FollowerManagerScript.MaxOffScreenBounty = 1000
            SetSliderOptionValue(OID_FM_MaxBounty, 1000.0, "{0}")
            SeverActionsNativeExt2.Native_SettingsRecord("offscreen", "maxBounty", "" + 1000.0)
        EndIf
    elseif option == OID_FM_MaxGoldChange
        If FollowerManagerScript
            FollowerManagerScript.MaxOffScreenGoldChange = 500
            SetSliderOptionValue(OID_FM_MaxGoldChange, 500.0, "{0}")
            SeverActionsNativeExt2.Native_SettingsRecord("offscreen", "maxGoldChange", "" + 500.0)
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
        HotkeyScript.UpdateUseFurnitureKey(UseFurnitureKey)
        HotkeyScript.UpdateYieldKey(YieldKey)
        HotkeyScript.UpdateUndressKey(UndressKey)
        HotkeyScript.UpdateDressKey(DressKey)
        HotkeyScript.UpdateSetCompanionKey(SetCompanionKey)
        HotkeyScript.UpdateCompanionWaitKey(CompanionWaitKey)
        HotkeyScript.UpdateAssignHomeKey(AssignHomeKey)
        HotkeyScript.UpdateClearHomeKey(ClearHomeKey)
        HotkeyScript.UpdateSetupCampKey(SetupCampKey)
        HotkeyScript.UpdateDropMarkerKey(DropMarkerKey)
        HotkeyScript.UpdateTieUntieKey(TieUntieKey)
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
        ; Shift flag FIRST — UpdateConfigMenuKey pushes both values to the
        ; native input sink, so it must see the fresh shift requirement.
        HotkeyScript.ConfigMenuRequireShift = ConfigMenuRequireShift
        HotkeyScript.UpdateConfigMenuKey(ConfigMenuKey)
        Debug.Trace("[SeverActions_MCM] Applied config menu key: " + ConfigMenuKey + " shift=" + ConfigMenuRequireShift)
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

    ; Re-push the situation-stability threshold -- the native SituationMonitor
    ; value is RAM-only and resets to its C++ default on every game restart;
    ; without this the MCM showed the saved value while the monitor ran on the
    ; default. (FMStabilityDelay is the cosaved source of truth, in seconds.)
    SeverActionsNativeExt.SituationMonitor_SetStabilityThreshold((FMStabilityDelay * 1000.0) as Int)
    Debug.Trace("[SeverActions_MCM] Situation Stability: " + FMStabilityDelay + " sec")

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