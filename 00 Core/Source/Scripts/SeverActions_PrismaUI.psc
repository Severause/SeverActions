Scriptname SeverActions_PrismaUI extends Quest
{PrismaUI config menu bridge -- handles data flow between PrismaUI web frontend
 and game scripts via SKSE ModEvents. Attach to a quest and set properties in CK.
 Data gathering uses C++ JSON builder (nlohmann_json) for correct types/escaping.}

; =============================================================================
; SCRIPT REFERENCES (set in CK -- same targets as MCM)
; =============================================================================

SeverActions_MCM Property MCMScript Auto
SeverActions_Currency Property CurrencyScript Auto
SeverActions_Debt Property DebtScript Auto
SeverActions_Travel Property TravelScript Auto
SeverActions_Hotkeys Property HotkeyScript Auto
SeverActions_Arrest Property ArrestScript Auto
SeverActions_ArrestBounty Property BountyScript Auto
SeverActions_Survival Property SurvivalScript Auto
SeverActions_FollowerManager Property FollowerManagerScript Auto
SeverActions_Loot Property LootScript Auto
SeverActions_SpellTeach Property SpellTeachScript Auto
SeverActions_Outfit Property OutfitScript Auto
SeverActions_Follow Property FollowScript Auto
SeverActions_Combat Property CombatScript Auto
SeverActions_Crafting Property CraftingScript Auto
SeverActions_Property Property PropertyScript Auto
SeverActions_SpellCast Property SpellCastScript Auto
SeverActions_Brawl Property BrawlScript Auto

; =============================================================================
; LIFECYCLE
; =============================================================================

Event OnInit()
    RegisterForPrismaEvents()
EndEvent

Function EnsureScriptReferences()
    {Resolve script references at runtime via quest cast.
     CK properties may be None if not configured — this fills them in.
     All scripts live on the same quest (FormID 0x000D62).}
    Quest q = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
    If !q
        Debug.Trace("[SeverActions_PrismaUI] ERROR: Could not find SeverActions quest")
        Return
    EndIf

    If !MCMScript
        MCMScript = q as SeverActions_MCM
    EndIf
    If !CurrencyScript
        CurrencyScript = q as SeverActions_Currency
    EndIf
    If !DebtScript
        DebtScript = q as SeverActions_Debt
    EndIf
    If !TravelScript
        TravelScript = q as SeverActions_Travel
    EndIf
    If !HotkeyScript
        HotkeyScript = q as SeverActions_Hotkeys
    EndIf
    If !ArrestScript
        ArrestScript = q as SeverActions_Arrest
    EndIf
    If !BountyScript
        BountyScript = q as SeverActions_ArrestBounty
    EndIf
    If !SurvivalScript
        SurvivalScript = q as SeverActions_Survival
    EndIf
    If !FollowerManagerScript
        FollowerManagerScript = q as SeverActions_FollowerManager
    EndIf
    If !LootScript
        LootScript = q as SeverActions_Loot
    EndIf
    If !SpellTeachScript
        SpellTeachScript = q as SeverActions_SpellTeach
    EndIf
    If !OutfitScript
        OutfitScript = q as SeverActions_Outfit
    EndIf
    If !FollowScript
        FollowScript = q as SeverActions_Follow
    EndIf
    If !CombatScript
        CombatScript = q as SeverActions_Combat
    EndIf
    If !CraftingScript
        CraftingScript = q as SeverActions_Crafting
    EndIf
    If !PropertyScript
        PropertyScript = q as SeverActions_Property
    EndIf
    If !SpellCastScript
        SpellCastScript = q as SeverActions_SpellCast
    EndIf
    If !BrawlScript
        BrawlScript = q as SeverActions_Brawl
    EndIf

    Debug.Trace("[SeverActions_PrismaUI] Script references resolved — " \
        + "MCM=" + (MCMScript != None) + " Follower=" + (FollowerManagerScript != None) \
        + " Survival=" + (SurvivalScript != None) + " Arrest=" + (ArrestScript != None) \
        + " Outfit=" + (OutfitScript != None) + " Follow=" + (FollowScript != None) \
        + " Combat=" + (CombatScript != None))
EndFunction

Function RegisterForPrismaEvents()
    {Call from OnInit or from SeverActions_Init on game load.}
    EnsureScriptReferences()

    If SeverActionsNative.PrismaUI_IsAvailable()
        ; Pass quest references to C++ for direct script property reading.
        ; This lets the DataGatherer read settings without going through Papyrus.
        ; Optional scripts may be None — C++ handles null quest pointers gracefully.
        ; These scripts all extend Quest (or SKI_ConfigBase which extends Quest),
        ; so we cast them to Quest with "as Quest".
        Quest mcmQ = MCMScript as Quest
        Quest followerQ = FollowerManagerScript as Quest
        Quest survivalQ = SurvivalScript as Quest
        Quest arrestQ = ArrestScript as Quest
        Quest debtQ = DebtScript as Quest
        Quest travelQ = TravelScript as Quest
        Quest outfitQ = OutfitScript as Quest
        Quest lootQ = LootScript as Quest
        Quest spellTeachQ = SpellTeachScript as Quest
        Quest hotkeyQ = HotkeyScript as Quest
        SeverActionsNative.PrismaUI_SetQuestRefs(mcmQ, followerQ, survivalQ, \
            arrestQ, debtQ, travelQ, outfitQ, lootQ, spellTeachQ, hotkeyQ)
        Debug.Trace("[SeverActions_PrismaUI] Quest references passed to C++ DataGatherer")

        ; Only register data request event — settings and actions are now
        ; handled directly by C++ (PrismaUISettingsHandler / PrismaUIActionHandler).
        ; World page still falls back to Papyrus for StorageUtil-dependent data.
        RegisterForModEvent("SeverActions_PrismaUI_RequestData", "OnRequestData")
        RegisterForModEvent("SeverActions_PrismaClearPkgs", "OnPrismaClearPkgs")
        RegisterForModEvent("SeverActions_PrismaRemovePkg", "OnPrismaRemovePkg")
        RegisterForModEvent("SeverActions_PrismaExecuteAction", "OnPrismaExecuteAction")
        Debug.Trace("[SeverActions_PrismaUI] Registered for PrismaUI data request and action events")
    Else
        Debug.Trace("[SeverActions_PrismaUI] PrismaUI not available -- skipping registration")
    EndIf
EndFunction

; =============================================================================
; MOD EVENT ROUTING
; =============================================================================

Event OnRequestData(String eventName, String strArg, Float numArg, Form sender)
    String page = strArg
    Debug.Trace("[SeverActions_PrismaUI] OnRequestData page='" + page + "'")

    ; ── PrismaUI v2 page names (used by DataGatherer Papyrus fallback) ──
    If page == "companions"
        SendCompanionsData()
    ElseIf page == "world"
        SendWorldData()
    ElseIf page == "dashboard"
        SendDashboardData()
    ; outfits page served by C++ DataGatherer (OutfitDataStore)
    ElseIf page == "settings"
        SendSettingsData()
    ElseIf page == "triggerOutfitMigration"
        ; C++ detected OutfitDataStore was empty — run Papyrus migration and refresh
        Debug.Trace("[SeverActions_PrismaUI] Triggering outfit data migration from C++ request")
        EnsureScriptReferences()
        if OutfitScript
            OutfitScript.MigrateOutfitDataToNative()
            Debug.Trace("[SeverActions_PrismaUI] Migration complete — refreshing outfits page")
            Utility.Wait(0.5)
            SeverActionsNative.PrismaUI_RefreshPage("outfits")
        else
            Debug.Trace("[SeverActions_PrismaUI] ERROR: OutfitScript not available for migration")
        endif
    EndIf
EndEvent

Event OnSettingChanged(String eventName, String strArg, Float numArg, Form sender)
    String page = SeverActionsNative.PrismaUI_ExtractJsonValue(strArg, "page")
    String sKey = SeverActionsNative.PrismaUI_ExtractJsonValue(strArg, "key")
    String sVal = SeverActionsNative.PrismaUI_ExtractJsonValue(strArg, "value")
    String sTarget = SeverActionsNative.PrismaUI_ExtractJsonValue(strArg, "target")

    ; ── PrismaUI v2 page names ──
    If page == "settings"
        ; Settings consolidates: dialogue/tags (General), survival config
        HandleGeneralSetting(sKey, sVal)
        HandleSurvivalSetting(sKey, sVal)
    ElseIf page == "world"
        ; World consolidates: currency/debt, bounty/arrest
        HandleCurrencySetting(sKey, sVal)
        HandleBountySetting(sKey, sVal)
    ElseIf page == "companions"
        ; Companions consolidates: follower framework
        HandleFollowersSetting(sKey, sVal, sTarget)
    ; outfits page settings handled by C++ SettingsHandler
    EndIf
EndEvent

Event OnActionRequested(String eventName, String strArg, Float numArg, Form sender)
    String actType = SeverActionsNative.PrismaUI_ExtractJsonValue(strArg, "action")
    HandleAction(actType, strArg)
EndEvent

; =============================================================================
; HELPERS
; =============================================================================

String Function SafeActorName(Actor a)
    {Get display name safely -- returns 'Unknown' if anything goes wrong.}
    If !a
        Return "Unknown"
    EndIf
    String n = a.GetDisplayName()
    If n == ""
        Return "Unknown"
    EndIf
    Return n
EndFunction

Bool Function SafeHasPackage(Actor a, String packageName)
    {Check SkyrimNetApi.HasPackage safely -- returns false if API unavailable or call fails.}
    If !a
        Return False
    EndIf
    Int result = SkyrimNetApi.HasPackage(a, packageName)
    Return result == 1
EndFunction

; =============================================================================
; PrismaUI v2 DATA GATHERERS
; These build unified page data for the new 5-page layout.
; Used as Papyrus fallback when C++ DataGatherer can't serve the page
; (pages needing StorageUtil or Papyrus function dispatch).
; =============================================================================

Function SendCompanionsData()
    {Build unified companions page: framework settings + per-NPC companion array.
     Combines old SendFollowersData() logic under page name "companions".}
    Debug.Trace("[SeverActions_PrismaUI] SendCompanionsData START")
    SeverActionsNativeExt.PrismaUI_BeginPage("companions")

    ; ── Framework settings ──
    If FollowerManagerScript
        SeverActionsNativeExt.PrismaUI_AddInt("frameworkMode", FollowerManagerScript.FrameworkMode)
        SeverActionsNativeExt.PrismaUI_AddInt("maxFollowers", FollowerManagerScript.MaxFollowers)
        SeverActionsNativeExt.PrismaUI_AddBool("autoDismissHostile", FollowerManagerScript.AllowAutonomousLeaving)
        SeverActionsNativeExt.PrismaUI_AddBool("trackRelationships", FollowerManagerScript.AutoRelAssessment)
        SeverActionsNativeExt.PrismaUI_AddFloat("rapportDecay", FollowerManagerScript.RapportDecayRate)
        SeverActionsNativeExt.PrismaUI_AddInt("leavingThreshold", FollowerManagerScript.LeavingThreshold as Int)
        SeverActionsNativeExt.PrismaUI_AddInt("relCooldown", FollowerManagerScript.RelationshipCooldown as Int)
    EndIf

    ; ── Companion array ──
    SeverActionsNativeExt.PrismaUI_BeginArray("companions")
    Actor[] companions = None
    If FollowerManagerScript
        companions = FollowerManagerScript.GetAllFollowers()
    EndIf
    Int ci = 0
    If companions
        Debug.Trace("[SeverActions_PrismaUI] Building companion data for " + companions.Length + " followers")
        While ci < companions.Length
            Actor c = companions[ci]
            If c
                BuildCompanionData(c)
            EndIf
            ci += 1
        EndWhile
    EndIf
    SeverActionsNativeExt.PrismaUI_EndArray()

    SeverActionsNativeExt.PrismaUI_SendPage()
    Debug.Trace("[SeverActions_PrismaUI] SendCompanionsData DONE")
EndFunction

Function SendWorldData()
    {Build unified world page: bounties + arrest settings + travel + currency/debt.
     Combines old SendBountyData() + SendTravelData() + SendCurrencyData() under "world".}
    Debug.Trace("[SeverActions_PrismaUI] SendWorldData START")
    SeverActionsNativeExt.PrismaUI_BeginPage("world")

    ; Phase 5 — bounties (with per-faction event timelines) now ship via
    ; PrismaUIDataGatherer::BuildWorldSettingsData on the C++ side. Shape
    ; changed from a hold-name-keyed object to an array of
    ; {crimeFactionId, amount, hold, events[]} entries — the Papyrus echo
    ; here would clobber the C++ array on the frontend merge ("last write
    ; wins"), so it's been removed.

    ; ── Arrest settings ──
    If ArrestScript
        SeverActionsNativeExt.PrismaUI_AddInt("arrestCooldown", ArrestScript.ArrestPlayerCooldown as Int)
        SeverActionsNativeExt.PrismaUI_AddInt("persuasionTimeLimit", ArrestScript.PersuasionTimeLimit as Int)
    Else
        SeverActionsNativeExt.PrismaUI_AddInt("arrestCooldown", 60)
        SeverActionsNativeExt.PrismaUI_AddInt("persuasionTimeLimit", 90)
    EndIf

    ; ── Travel slots ──
    Int activeCount = 0
    If TravelScript
        activeCount = TravelScript.GetActiveTravelCount()
    EndIf
    SeverActionsNativeExt.PrismaUI_AddInt("activeSlots", activeCount)

    SeverActionsNativeExt.PrismaUI_BeginArray("slots")
    Int ti = 0
    Int slotState = 0
    ReferenceAlias slotAlias = None
    Actor slotNPC = None
    While ti < 5
        slotState = 0
        If TravelScript
            slotState = TravelScript.GetSlotState(ti)
        EndIf
        SeverActionsNativeExt.PrismaUI_BeginObject()
        If slotState > 0
            SeverActionsNativeExt.PrismaUI_AddBool("active", True)
            slotAlias = GetTravelAlias(ti)
            slotNPC = None
            If slotAlias
                slotNPC = slotAlias.GetActorReference()
            EndIf
            If slotNPC
                SeverActionsNativeExt.PrismaUI_AddString("npcName", SafeActorName(slotNPC))
            Else
                SeverActionsNativeExt.PrismaUI_AddString("npcName", "Unknown")
            EndIf
            SeverActionsNativeExt.PrismaUI_AddString("destination", TravelScript.GetSlotDestination(ti))
            SeverActionsNativeExt.PrismaUI_AddString("status", TravelScript.GetSlotStatusText(ti))
        Else
            SeverActionsNativeExt.PrismaUI_AddBool("active", False)
        EndIf
        SeverActionsNativeExt.PrismaUI_EndObject()
        ti += 1
    EndWhile
    SeverActionsNativeExt.PrismaUI_EndArray()

    ; ── Currency settings ──
    If MCMScript
        SeverActionsNativeExt.PrismaUI_AddBool("allowConjuredGold", MCMScript.AllowConjuredGold)
    Else
        SeverActionsNativeExt.PrismaUI_AddBool("allowConjuredGold", True)
    EndIf

    ; ── Debt settings ──
    If DebtScript
        SeverActionsNativeExt.PrismaUI_AddBool("overdueReminders", DebtScript.EnableOverdueReminders)
        SeverActionsNativeExt.PrismaUI_AddInt("gracePeriod", DebtScript.OverdueGracePeriodHours as Int)
        SeverActionsNativeExt.PrismaUI_AddInt("reportThreshold", DebtScript.ReportThresholdHours as Int)
    Else
        SeverActionsNativeExt.PrismaUI_AddBool("overdueReminders", True)
        SeverActionsNativeExt.PrismaUI_AddInt("gracePeriod", 24)
        SeverActionsNativeExt.PrismaUI_AddInt("reportThreshold", 72)
    EndIf

    ; Phase 4 — debt structured data (debtCount / totalPlayerOwes /
    ; totalOwedToPlayer / playerOwes[] / owedToPlayer[]) is now built by
    ; PrismaUIDataGatherer::BuildWorldSettingsData on the C++ side. The
    ; Papyrus fallback used to send the same fields; both reach the
    ; frontend on the same page request, last write wins, so removing the
    ; Papyrus version simplifies the source of truth without changing the
    ; rendered output.

    SeverActionsNativeExt.PrismaUI_SendPage()
    Debug.Trace("[SeverActions_PrismaUI] SendWorldData DONE")
EndFunction

Function SendDashboardData()
    {Build dashboard page: mod info + system availability.
     This is a simple Papyrus fallback in case C++ DataGatherer didn't serve it.}
    Debug.Trace("[SeverActions_PrismaUI] SendDashboardData START")
    SeverActionsNativeExt.PrismaUI_BeginPage("dashboard")

    SeverActionsNativeExt.PrismaUI_AddString("version", "1.1")
    SeverActionsNativeExt.PrismaUI_AddString("author", "Severause")

    ; System availability flags
    SeverActionsNativeExt.PrismaUI_AddBool("hasFollowerManager", FollowerManagerScript != None)
    SeverActionsNativeExt.PrismaUI_AddBool("hasSurvivalScript", SurvivalScript != None)
    SeverActionsNativeExt.PrismaUI_AddBool("hasOutfitScript", OutfitScript != None)
    SeverActionsNativeExt.PrismaUI_AddBool("hasLootScript", LootScript != None)
    SeverActionsNativeExt.PrismaUI_AddBool("hasSpellTeachScript", SpellTeachScript != None)

    If FollowerManagerScript
        SeverActionsNativeExt.PrismaUI_AddInt("frameworkMode", FollowerManagerScript.FrameworkMode)
        SeverActionsNativeExt.PrismaUI_AddInt("maxFollowers", FollowerManagerScript.MaxFollowers)
    EndIf

    If SurvivalScript
        SeverActionsNativeExt.PrismaUI_AddBool("survivalEnabled", SurvivalScript.Enabled)
    EndIf

    SeverActionsNativeExt.PrismaUI_SendPage()
    Debug.Trace("[SeverActions_PrismaUI] SendDashboardData DONE")
EndFunction

; SendOutfitsData() — REMOVED: Outfits page now served by C++ DataGatherer
; via OutfitDataStore (native cosave). No Papyrus fallback needed.

Function SendSettingsData()
    {Build settings page: dialogue/tags, survival, spell teach config.
     Papyrus fallback when C++ ScriptReader can't read MCM properties.}
    Debug.Trace("[SeverActions_PrismaUI] SendSettingsData START")
    SeverActionsNativeExt.PrismaUI_BeginPage("settings")

    ; ── Dialogue settings ──
    If MCMScript
        SeverActionsNativeExt.PrismaUI_AddBool("dialogueAnimEnabled", MCMScript.DialogueAnimEnabled)
        SeverActionsNativeExt.PrismaUI_AddInt("silenceChance", MCMScript.SilenceChance)
        SeverActionsNativeExt.PrismaUI_AddBool("tagCompanion", MCMScript.TagCompanionEnabled)
        SeverActionsNativeExt.PrismaUI_AddBool("tagEngaged", MCMScript.TagEngagedEnabled)
        SeverActionsNativeExt.PrismaUI_AddBool("tagInScene", MCMScript.TagInSceneEnabled)
    EndIf

    ; ── Book reading ──
    SeverActionsNativeExt.PrismaUI_AddBool("hasLootScript", LootScript != None)
    If LootScript
        SeverActionsNativeExt.PrismaUI_AddInt("bookReadMode", LootScript.BookReadMode)
    EndIf

    ; ── Spell teaching ──
    SeverActionsNativeExt.PrismaUI_AddBool("hasSpellTeachScript", SpellTeachScript != None)
    If SpellTeachScript
        SeverActionsNativeExt.PrismaUI_AddBool("spellFailEnabled", SpellTeachScript.EnableFailureSystem)
        SeverActionsNativeExt.PrismaUI_AddFloat("spellFailDifficulty", SpellTeachScript.FailureDifficultyMult)
    EndIf

    ; ── Survival ──
    SeverActionsNativeExt.PrismaUI_AddBool("hasSurvivalScript", SurvivalScript != None)
    If SurvivalScript
        SeverActionsNativeExt.PrismaUI_AddBool("survivalEnabled", SurvivalScript.Enabled)
        SeverActionsNativeExt.PrismaUI_AddBool("hungerEnabled", SurvivalScript.HungerEnabled)
        SeverActionsNativeExt.PrismaUI_AddFloat("hungerRate", SurvivalScript.HungerRate)
        SeverActionsNativeExt.PrismaUI_AddInt("autoEatThreshold", SurvivalScript.AutoEatThreshold)
        SeverActionsNativeExt.PrismaUI_AddBool("fatigueEnabled", SurvivalScript.FatigueEnabled)
        SeverActionsNativeExt.PrismaUI_AddFloat("fatigueRate", SurvivalScript.FatigueRate)
        SeverActionsNativeExt.PrismaUI_AddBool("coldEnabled", SurvivalScript.ColdEnabled)
        SeverActionsNativeExt.PrismaUI_AddFloat("coldRate", SurvivalScript.ColdRate)
    EndIf

    ; ── Follower manager ──
    SeverActionsNativeExt.PrismaUI_AddBool("hasFollowerManager", FollowerManagerScript != None)

    SeverActionsNativeExt.PrismaUI_SendPage()
    Debug.Trace("[SeverActions_PrismaUI] SendSettingsData DONE")
EndFunction

; =============================================================================
; COMPANION DATA BUILDER
; Used by SendCompanionsData to build per-companion JSON objects.
; =============================================================================

Function BuildCompanionData(Actor c)
    {Build one companion object inside the companions array using the C++ builder.}
    SeverActionsNativeExt.PrismaUI_BeginObject()
    SeverActionsNativeExt.PrismaUI_AddString("name", SafeActorName(c))

    ; Race
    Race cRace = c.GetRace()
    If cRace
        SeverActionsNativeExt.PrismaUI_AddString("race", cRace.GetName())
    Else
        SeverActionsNativeExt.PrismaUI_AddString("race", "Unknown")
    EndIf

    SeverActionsNativeExt.PrismaUI_AddInt("rapport", SeverActionsNative.Native_GetRapport(c) as Int)
    SeverActionsNativeExt.PrismaUI_AddInt("trust",   SeverActionsNative.Native_GetTrust(c)   as Int)
    SeverActionsNativeExt.PrismaUI_AddInt("loyalty", SeverActionsNative.Native_GetLoyalty(c) as Int)
    SeverActionsNativeExt.PrismaUI_AddInt("mood",    SeverActionsNative.Native_GetMood(c)    as Int)

    ; Combat style
    If FollowerManagerScript
        SeverActionsNativeExt.PrismaUI_AddString("combatStyle", FollowerManagerScript.GetCombatStyle(c))
    Else
        SeverActionsNativeExt.PrismaUI_AddString("combatStyle", "balanced")
    EndIf
    SeverActionsNativeExt.PrismaUI_AddString("home", SeverActionsNative.Native_GetHome(c))

    ; Active SkyrimNet packages
    SeverActionsNativeExt.PrismaUI_AddBool("hasFollowPkg", SafeHasPackage(c, "FollowPlayer"))
    SeverActionsNativeExt.PrismaUI_AddBool("hasTalkPlayerPkg", SafeHasPackage(c, "TalkToPlayer"))
    SeverActionsNativeExt.PrismaUI_AddBool("hasTalkNPCPkg", SafeHasPackage(c, "TalkToNPC"))

    ; Behavioral states
    SeverActionsNativeExt.PrismaUI_AddBool("isSandboxing", SeverActionsNativeExt.Native_GetSandboxing(c))
    String tvState = StorageUtil.GetStringValue(c, "SeverTravel_State", "")
    SeverActionsNativeExt.PrismaUI_AddString("travelState", tvState)
    If tvState != ""
        SeverActionsNativeExt.PrismaUI_AddString("travelDest", StorageUtil.GetStringValue(c, "SeverTravel_Destination", ""))
    EndIf
    SeverActionsNativeExt.PrismaUI_AddBool("inForcedCombat", StorageUtil.GetIntValue(c, "SeverCombat_InForcedCombat", 0) == 1)
    SeverActionsNativeExt.PrismaUI_AddBool("hasSurrendered", StorageUtil.GetIntValue(c, "SeverCombat_WasSurrendered", 0) == 1)

    SeverActionsNativeExt.PrismaUI_EndObject()
EndFunction

; =============================================================================
; SETTING CHANGE HANDLERS
; =============================================================================

Function HandleGeneralSetting(String sKey, String sVal)
    If sKey == "dialogueAnimEnabled" && MCMScript
        MCMScript.DialogueAnimEnabled = (sVal == "true")
        SeverActionsNative.SetDialogueAnimEnabled(MCMScript.DialogueAnimEnabled)
    ElseIf sKey == "silenceChance" && MCMScript
        MCMScript.SilenceChance = sVal as Int
        StorageUtil.SetIntValue(None, "SeverActions_ZeroChance", MCMScript.SilenceChance)
    ElseIf sKey == "bookReadMode" && LootScript
        LootScript.BookReadMode = sVal as Int
    ElseIf sKey == "tagCompanion" && MCMScript
        MCMScript.TagCompanionEnabled = (sVal == "true")
        StorageUtil.SetIntValue(None, "SeverActions_TagCompanion", BoolToInt(sVal == "true"))
    ElseIf sKey == "tagEngaged" && MCMScript
        MCMScript.TagEngagedEnabled = (sVal == "true")
        StorageUtil.SetIntValue(None, "SeverActions_TagEngaged", BoolToInt(sVal == "true"))
    ElseIf sKey == "tagInScene" && MCMScript
        MCMScript.TagInSceneEnabled = (sVal == "true")
        StorageUtil.SetIntValue(None, "SeverActions_TagInScene", BoolToInt(sVal == "true"))
    ElseIf sKey == "spellFailEnabled" && SpellTeachScript
        SpellTeachScript.EnableFailureSystem = (sVal == "true")
        StorageUtil.SetIntValue(None, "SeverActions_SpellFailEnabled", BoolToInt(sVal == "true"))
    ElseIf sKey == "spellFailDifficulty" && SpellTeachScript
        SpellTeachScript.FailureDifficultyMult = sVal as Float
        StorageUtil.SetFloatValue(None, "SeverActions_SpellFailDifficulty", sVal as Float)
    EndIf
EndFunction

Function HandleCurrencySetting(String sKey, String sVal)
    If sKey == "allowConjuredGold" && MCMScript
        MCMScript.AllowConjuredGold = (sVal == "true")
        If CurrencyScript
            CurrencyScript.AllowConjuredGold = (sVal == "true")
        EndIf
    ElseIf sKey == "overdueReminders" && DebtScript
        DebtScript.EnableOverdueReminders = (sVal == "true")
    ElseIf sKey == "gracePeriod" && DebtScript
        DebtScript.OverdueGracePeriodHours = sVal as Float
    ElseIf sKey == "reportThreshold" && DebtScript
        DebtScript.ReportThresholdHours = sVal as Float
    EndIf
EndFunction

Function HandleBountySetting(String sKey, String sVal)
    If !ArrestScript
        Return
    EndIf
    If sKey == "arrestCooldown"
        ArrestScript.ArrestPlayerCooldown = sVal as Float
    ElseIf sKey == "persuasionTimeLimit"
        ArrestScript.PersuasionTimeLimit = sVal as Float
    EndIf
EndFunction

Function HandleSurvivalSetting(String sKey, String sVal)
    If !SurvivalScript
        Return
    EndIf
    If sKey == "survivalEnabled"
        SurvivalScript.Enabled = (sVal == "true")
    ElseIf sKey == "hungerEnabled"
        SurvivalScript.HungerEnabled = (sVal == "true")
    ElseIf sKey == "hungerRate"
        SurvivalScript.HungerRate = sVal as Float
    ElseIf sKey == "autoEatThreshold"
        SurvivalScript.AutoEatThreshold = sVal as Int
    ElseIf sKey == "fatigueEnabled"
        SurvivalScript.FatigueEnabled = (sVal == "true")
    ElseIf sKey == "fatigueRate"
        SurvivalScript.FatigueRate = sVal as Float
    ElseIf sKey == "coldEnabled"
        SurvivalScript.ColdEnabled = (sVal == "true")
    ElseIf sKey == "coldRate"
        SurvivalScript.ColdRate = sVal as Float
    EndIf
EndFunction

Function HandleFollowersSetting(String sKey, String sVal, String sTarget)
    If !FollowerManagerScript
        Return
    EndIf
    ; Framework-level settings
    If sKey == "frameworkMode"
        FollowerManagerScript.FrameworkMode = sVal as Int
    ElseIf sKey == "maxFollowers"
        FollowerManagerScript.MaxFollowers = sVal as Int
    ElseIf sKey == "autoDismissHostile"
        FollowerManagerScript.AllowAutonomousLeaving = (sVal == "true")
    ElseIf sKey == "trackRelationships"
        FollowerManagerScript.AutoRelAssessment = (sVal == "true")
    ElseIf sKey == "rapportDecay"
        FollowerManagerScript.RapportDecayRate = sVal as Float
    ElseIf sKey == "leavingThreshold"
        FollowerManagerScript.LeavingThreshold = sVal as Float
    ElseIf sKey == "relCooldown"
        FollowerManagerScript.RelationshipCooldown = sVal as Float
    ; Per-companion settings (sTarget = companion name)
    ElseIf sKey == "companionCombatStyle" && sTarget != ""
        HandleCompanionCombatStyle(sTarget, sVal)
    EndIf
EndFunction

Function HandleCompanionCombatStyle(String companionName, String sVal)
    Actor companion = FindFollowerByName(companionName)
    If companion && FollowerManagerScript
        String style = GetCombatStyleFromIndex(sVal as Int)
        FollowerManagerScript.SetCombatStyle(companion, style)
    EndIf
EndFunction

; HandleOutfitsSetting() — REMOVED: Handled by C++ PrismaUISettingsHandler

; =============================================================================
; ACTION HANDLER
; =============================================================================

Function HandleAction(String actType, String json)
    ; Pre-declare all variables at function scope (Papyrus requires this)
    String actName = ""
    Actor actTarget = None
    Int actSlot = 0
    String actLocName = ""

    ; Bounty actions
    If actType == "clearBounty"
        actName = SeverActionsNative.PrismaUI_ExtractJsonValue(json, "hold")
        ClearBountyForHold(actName)
        SeverActionsNative.PrismaUI_RefreshPage("world")
    ElseIf actType == "clearAllBounties"
        ClearAllBounties()
        SeverActionsNative.PrismaUI_RefreshPage("world")

    ; Travel actions
    ElseIf actType == "clearTravelSlot"
        actSlot = SeverActionsNative.PrismaUI_ExtractJsonValue(json, "slot") as Int
        If TravelScript
            TravelScript.ClearSlotFromMCM(actSlot)
        EndIf
        SeverActionsNative.PrismaUI_RefreshPage("world")
    ElseIf actType == "resetAllTravel"
        If TravelScript
            TravelScript.CancelAllTravel()
        EndIf
        SeverActionsNative.PrismaUI_RefreshPage("world")

    ; NPC Home actions
    ElseIf actType == "clearNPCHome"
        actName = SeverActionsNative.PrismaUI_ExtractJsonValue(json, "name")
        actTarget = FindFollowerByName(actName)
        If actTarget && FollowerManagerScript
            FollowerManagerScript.ClearHome(actTarget)
        EndIf
        SeverActionsNative.PrismaUI_RefreshPage("companions")

    ; Follower actions
    ElseIf actType == "assignHomeHere"
        actName = SeverActionsNative.PrismaUI_ExtractJsonValue(json, "name")
        actTarget = FindFollowerByName(actName)
        If actTarget && FollowerManagerScript
            actLocName = GetPlayerLocationName()
            FollowerManagerScript.AssignHome(actTarget, actLocName)
        EndIf
        SeverActionsNative.PrismaUI_RefreshPage("companions")
    ElseIf actType == "clearCompanionHome"
        actName = SeverActionsNative.PrismaUI_ExtractJsonValue(json, "name")
        actTarget = FindFollowerByName(actName)
        If actTarget && FollowerManagerScript
            FollowerManagerScript.ClearHome(actTarget)
        EndIf
        SeverActionsNative.PrismaUI_RefreshPage("companions")
    ElseIf actType == "dismissFollower"
        actName = SeverActionsNative.PrismaUI_ExtractJsonValue(json, "name")
        actTarget = FindFollowerByName(actName)
        If actTarget
            FollowerManagerScript.DismissCompanion(actTarget)
        EndIf
        Utility.Wait(0.5)
        SeverActionsNative.PrismaUI_RefreshPage("companions")
    ElseIf actType == "resetAllCompanions"
        If FollowerManagerScript
            Actor[] allComp = FollowerManagerScript.GetAllFollowers()
            Int ci = 0
            If allComp
                While ci < allComp.Length
                    If allComp[ci]
                        FollowerManagerScript.DismissCompanion(allComp[ci])
                    EndIf
                    ci += 1
                EndWhile
            EndIf
        EndIf
        Utility.Wait(1.0)
        SeverActionsNative.PrismaUI_RefreshPage("companions")

    ; Outfit actions handled by C++ PrismaUIActionHandler

    ; Package management actions (SkyrimNetApi calls)
    ElseIf actType == "clearAllPackages"
        actName = SeverActionsNative.PrismaUI_ExtractJsonValue(json, "name")
        actTarget = FindFollowerByName(actName)
        If actTarget
            Debug.Trace("[SeverActions_PrismaUI] ClearAllPackages for " + actName)
            SkyrimNetApi.ClearAllPackages(actTarget)
            SeverActionsNative.Native_SetSandboxing(actTarget, false)
        EndIf
        Utility.Wait(0.5)
        SeverActionsNative.PrismaUI_RefreshPage("companions")
    ElseIf actType == "removePackage"
        actName = SeverActionsNative.PrismaUI_ExtractJsonValue(json, "name")
        actLocName = SeverActionsNative.PrismaUI_ExtractJsonValue(json, "package")
        actTarget = FindFollowerByName(actName)
        If actTarget
            Debug.Trace("[SeverActions_PrismaUI] UnregisterPackage " + actLocName + " from " + actName)
            SkyrimNetApi.UnregisterPackage(actTarget, actLocName)
            If actLocName == "FollowPlayer"
                SeverActionsNative.Native_SetSandboxing(actTarget, false)
            EndIf
        EndIf
        Utility.Wait(0.5)
        SeverActionsNative.PrismaUI_RefreshPage("companions")
    EndIf
EndFunction

; =============================================================================
; C++ DISPATCH TARGETS
; These functions are called from C++ via vm->DispatchMethodCall when an
; action requires SkyrimNet API access or other Papyrus-only functionality.
; =============================================================================

; =============================================================================
; PRISMAUI ACTIONS PAGE — Generic Action Executor
; Receives pipe-delimited: actionId|target|target2|strParam|intParam
; Resolves actors by name and dispatches to the correct script function.
; =============================================================================

Event OnPrismaExecuteAction(string eventName, string strArg, float numArg, Form sender)
    EnsureScriptReferences()

    ; Parse pipe-delimited fields (6 slots — actionId | target | target2 |
    ; strParam | intParam | str2Param). str2Param is empty for most actions;
    ; v4 verbs (castSpell, setSituationOutfit, createRecurringDebt) use it
    ; for a second string parameter (preset name / interval days / etc.).
    String actionId = GetPipeField(strArg, 0)
    String targetName = GetPipeField(strArg, 1)
    String target2Name = GetPipeField(strArg, 2)
    String strParam = GetPipeField(strArg, 3)
    Int intParam = GetPipeField(strArg, 4) as Int
    String str2Param = GetPipeField(strArg, 5)

    Debug.Trace("[SeverActions_PrismaUI] ExecuteAction: " + actionId + " target=" + targetName \
        + " target2=" + target2Name + " str=" + strParam + " int=" + intParam + " str2=" + str2Param)

    ; Resolve primary target ("Player" → player ref, otherwise search by name)
    Actor target = None
    If targetName == "Player" || targetName == "player"
        target = Game.GetPlayer()
    Else
        target = SeverActionsNative.FindActorByName(targetName)
    EndIf
    If !target
        Debug.Trace("[SeverActions_PrismaUI] ExecuteAction: Could not find target '" + targetName + "'")
        Return
    EndIf

    ; Resolve optional second target ("Player" → player ref).
    ; Several downstream Execute paths take target2Name as a raw string and
    ; resolve it again themselves via FindActorByName (GiveGoldTrue_Execute,
    ; DispatchGuardToArrest_Execute target2Name slot, DispatchGuardToHome_Execute
    ; target2Name slot, etc.). FindActorByName fuzzy-matches via Levenshtein,
    ; so a literal "Player" sentinel from the picker would otherwise match the
    ; first NPC whose name contains "Player" (e.g. "Player Friend"). Whenever
    ; we successfully resolve target2 to an Actor, also overwrite target2Name
    ; with that actor's actual display name so the raw-string path can't
    ; collide. For the player specifically, "Player" → player.GetDisplayName().
    Actor target2 = None
    If target2Name == "Player" || target2Name == "player"
        target2 = Game.GetPlayer()
        target2Name = target2.GetDisplayName()
    ElseIf target2Name != ""
        target2 = SeverActionsNative.FindActorByName(target2Name)
        If target2
            ; Re-canonicalize so any downstream string-based resolve uses the
            ; actor's authoritative display name rather than the picker's typed
            ; value (which may differ in case / whitespace / NND-bracket form).
            target2Name = target2.GetDisplayName()
        Else
            String resolveMsg = "PrismaUI dispatch: target2 name '" + target2Name + "' did not resolve to an actor (action=" + actionId + ")"
            Debug.Trace("[SeverActions_PrismaUI] " + resolveMsg)
            SeverActionsNative.Native_Arrest_Log(resolveMsg)
        EndIf
    EndIf

    ; Same canonicalization for targetName — primary target string is also
    ; passed downstream by some legacy paths.
    If targetName == "Player" || targetName == "player"
        ; target was already set to Game.GetPlayer() above; just rename.
        targetName = target.GetDisplayName()
    ElseIf target
        targetName = target.GetDisplayName()
    EndIf

    ; ── Follower Actions ──
    If actionId == "registerFollower"
        If FollowerManagerScript
            FollowerManagerScript.RegisterFollower(target)
        EndIf

    ElseIf actionId == "companionFollow"
        If FollowerManagerScript
            FollowerManagerScript.CompanionFollow(target)
        EndIf

    ElseIf actionId == "companionWait"
        If FollowerManagerScript
            FollowerManagerScript.CompanionWait(target)
        EndIf

    ElseIf actionId == "dismissCompanion"
        If FollowerManagerScript
            FollowerManagerScript.DismissCompanion(target)
        EndIf

    ElseIf actionId == "followerLeaves"
        If FollowerManagerScript
            FollowerManagerScript.FollowerLeaves(target)
        EndIf

    ElseIf actionId == "assignHome"
        If FollowerManagerScript
            String locName = strParam
            If locName == ""
                locName = GetPlayerLocationName()
            EndIf
            FollowerManagerScript.AssignHome(target, locName)
        EndIf

    ElseIf actionId == "setCombatStyle"
        If FollowerManagerScript
            FollowerManagerScript.SetCombatStyle(target, strParam)
        EndIf

    ; ── Combat Actions ──
    ElseIf actionId == "ceaseFire"
        If CombatScript
            CombatScript.CeaseFire_Execute(target, None)
        EndIf

    ElseIf actionId == "attackTarget"
        If CombatScript && target2
            CombatScript.AttackTarget_Execute(target, target2)
        EndIf

    ElseIf actionId == "yield"
        If CombatScript
            CombatScript.Yield_Execute(target)
        EndIf

    ; ── Brawl Actions ──
    ; All four mirror the SkyrimNet YAML entry points 1:1 so the PrismaUI
    ; Actions page can drive a brawl end-to-end without the LLM. target =
    ; subject (challenger / accepter / decliner / forfeiter); target2 =
    ; opposite participant where relevant.
    ElseIf actionId == "challengeBrawl"
        If BrawlScript && target && target2
            BrawlScript.ChallengeBrawl_Execute(target, target2)
        EndIf

    ElseIf actionId == "acceptBrawl"
        ; akChallenger (target2) is optional in AcceptBrawl_Execute — when
        ; omitted, the script looks up the pending challenge from native state.
        ; The accepter (target) is dereferenced unconditionally, so guard it.
        If BrawlScript && target
            BrawlScript.AcceptBrawl_Execute(target, target2)
        EndIf

    ElseIf actionId == "declineBrawl"
        If BrawlScript && target
            BrawlScript.DeclineBrawl_Execute(target, target2)
        EndIf

    ElseIf actionId == "forfeitBrawl"
        If BrawlScript && target
            BrawlScript.ForfeitBrawl_Execute(target)
        EndIf

    ; ── Economy Actions ──
    ElseIf actionId == "giveGold"
        ; Name-resolution fallback (GiveGoldTrue) was deleted in Phase 1 — the
        ; PrismaUI action picker always supplies a resolved target2 Actor, so
        ; the string-based path is unreachable in practice. If a future UI
        ; surface needs name-resolution, restore GiveGoldTrue first.
        If CurrencyScript && target2
            CurrencyScript.GiveGold_Execute(target, target2, intParam)
        EndIf

    ElseIf actionId == "collectPayment"
        If CurrencyScript
            ; target = Collector, target2 = Payer (matches YAML: akCollector, akPayer)
            If target2
                CurrencyScript.CollectPayment_Execute(target, target2, intParam)
            Else
                ; Fallback: collect from player if no payer chosen
                CurrencyScript.CollectPayment_Execute(target, Game.GetPlayer(), intParam)
            EndIf
        EndIf

    ElseIf actionId == "extortGold"
        If CurrencyScript
            ; target = Extorter, target2 = Victim (matches YAML: akExtorter, akVictim)
            If target2
                CurrencyScript.ExtortGold_Execute(target, target2, intParam)
            Else
                ; Fallback: extort player if no victim chosen
                CurrencyScript.ExtortGold_Execute(target, Game.GetPlayer(), intParam)
            EndIf
        EndIf

    ; ── Outfit Actions ──
    ElseIf actionId == "undress"
        If OutfitScript
            OutfitScript.Undress_Execute(target)
        EndIf

    ElseIf actionId == "getDressed"
        If OutfitScript
            OutfitScript.Dress_Execute(target)
        EndIf

    ElseIf actionId == "equipItems"
        If OutfitScript
            OutfitScript.EquipMultipleItems_Execute(target, strParam)
        EndIf

    ElseIf actionId == "unequipItems"
        If OutfitScript
            OutfitScript.UnequipMultipleItems_Execute(target, strParam)
        EndIf

    ElseIf actionId == "applyPreset"
        If OutfitScript
            OutfitScript.ApplyOutfitPreset_Execute(target, strParam)
        EndIf

    ElseIf actionId == "savePreset"
        If OutfitScript
            OutfitScript.SaveOutfitPreset_Execute(target, strParam)
        EndIf

    ; ── Travel Actions ──
    ElseIf actionId == "travelToPlace"
        If TravelScript
            ; strParam = location name, field 5 = speed string (Walk/Jog/Run)
            String speedStr = GetPipeField(strArg, 5)
            Int speed = 0
            If speedStr == "Walk"
                speed = 0
            ElseIf speedStr == "Run"
                speed = 2
            Else
                speed = 1  ; Jog (default)
            EndIf
            TravelScript.TravelToPlace(target, strParam, 0.0, True, speed)
        EndIf

    ElseIf actionId == "cancelTravel"
        If TravelScript
            TravelScript.CancelTravel(target)
        EndIf

    ; ── Spell Actions ──
    ElseIf actionId == "teachSpell"
        If SpellTeachScript
            SpellTeachScript.TeachSpell(target, strParam)
        EndIf

    ElseIf actionId == "learnSpell"
        If SpellTeachScript
            SpellTeachScript.LearnSpell(target, strParam)
        EndIf

    ; ── Arrest Actions ──
    ElseIf actionId == "arrestNPC"
        If !ArrestScript
            SeverActionsNative.Native_Arrest_Log("PrismaUI arrestNPC skipped — ArrestScript reference is None (script ref binding failed)")
        ElseIf !target2
            SeverActionsNative.Native_Arrest_Log("PrismaUI arrestNPC skipped — target2 (suspect) is None. target='" + targetName + "' target2Name='" + target2Name + "'")
        Else
            SeverActionsNative.Native_Arrest_Log("PrismaUI arrestNPC dispatching: guard='" + target.GetDisplayName() + "' suspect='" + target2.GetDisplayName() + "'")
            Bool arrestStarted = ArrestScript.ArrestNPC_Internal(target, target2)
            SeverActionsNative.Native_Arrest_Log("PrismaUI arrestNPC result: " + arrestStarted)
        EndIf

    ElseIf actionId == "freeFromJail"
        If !ArrestScript
            SeverActionsNative.Native_Arrest_Log("PrismaUI freeFromJail skipped — ArrestScript reference is None")
        ElseIf !target2
            SeverActionsNative.Native_Arrest_Log("PrismaUI freeFromJail skipped — target2 (jailed NPC) is None. target='" + targetName + "' target2Name='" + target2Name + "'")
        Else
            ArrestScript.FreeNPC_Internal(target, target2)
        EndIf

    ElseIf actionId == "dispatchGuardArrest"
        If ArrestScript
            ; target = guard being dispatched
            ; target2Name = NPC to arrest (text name)
            ; field 5 (str2Param) = authority who ordered the arrest (actor name from picker)
            ; Defaults to player if not specified
            String senderName = GetPipeField(strArg, 5)
            ; Normalize the literal "Player" sentinel from the picker to the
            ; player's actual display name. The downstream Execute path resolves
            ; senders via FindActorByName, which fuzzy-matches "Player" to any
            ; NPC whose display name contains "Player" (e.g. "Player Friend"),
            ; sending the guard to the wrong actor entirely.
            If senderName == "" || senderName == "Player" || senderName == "player"
                senderName = Game.GetPlayer().GetDisplayName()
            EndIf
            ArrestScript.DispatchGuardToArrest_Execute(target, target2Name, senderName)
        EndIf

    ElseIf actionId == "dispatchGuardHome"
        If ArrestScript
            ; target = guard being dispatched
            ; target2Name = NPC whose home to search (text name)
            ; strParam = reason for search
            ; field 5 (str2Param) = authority who ordered (actor name from picker)
            ; Defaults to player if not specified
            String senderName = GetPipeField(strArg, 5)
            ; Same "Player" sentinel normalization as dispatchGuardArrest above.
            If senderName == "" || senderName == "Player" || senderName == "player"
                senderName = Game.GetPlayer().GetDisplayName()
            EndIf
            ArrestScript.DispatchGuardToHome_Execute(target, target2Name, senderName, strParam)
        EndIf

    ; ── Debt Actions ──
    ElseIf actionId == "createDebt"
        If DebtScript && target2
            ; target = creditor, target2 = debtor, intParam = amount, strParam = reason
            String reason = strParam
            If reason == ""
                reason = "debt"
            EndIf
            DebtScript.CreateDebt_Execute(target, target, target2, intParam, reason, 0, 0)
        EndIf

    ElseIf actionId == "addToDebt"
        If DebtScript && target2
            ; target = creditor, target2 = debtor, intParam = amount
            DebtScript.AddToDebt_Execute(target, target2, intParam, "additional charges")
        EndIf

    ElseIf actionId == "forgiveDebt"
        If DebtScript && target2
            ; target = creditor, target2 = debtor
            DebtScript.ForgiveDebt_Execute(target, target2)
        EndIf

    ; ── Item Actions ──
    ElseIf actionId == "giveItem"
        If LootScript && target2
            ; target = giver, target2 = receiver, strParam = item name
            LootScript.GiveItem_Execute(target, target2, strParam, 1)
        EndIf

    ElseIf actionId == "takeItemFromPlayer"
        If LootScript
            ; target = NPC taking, strParam = item name
            LootScript.TakeItemFromPlayer_Execute(target, strParam, 1)
        EndIf

    ; ── Property Actions ──
    ElseIf actionId == "transferOwnership"
        ; target = NPC giving away ownership (speaker)
        ; strParam = property name (blank = use actor's current location)
        If PropertyScript
            PropertyScript.TransferOwnership(target, strParam)
        EndIf

    ; ── Mysticism Actions (v4 Composer additions) ──
    ElseIf actionId == "castSpell"
        ; target  = caster (Subject), strParam = spell name
        ; target2 = optional target NPC (empty/"0" = aimed cast in front of caster)
        If SpellCastScript
            String castTargetName = target2Name
            If castTargetName == ""
                castTargetName = "0"
            EndIf
            SpellCastScript.CastSpell_Execute(target, strParam, castTargetName, false, true, true)
        EndIf

    ; ── Outfit Situation Actions (v4) ──
    ElseIf actionId == "setSituationOutfit"
        ; target = NPC, strParam = situation, str2Param = preset name
        If OutfitScript
            OutfitScript.SetSituationPreset_Execute(target, strParam, str2Param)
        EndIf

    ElseIf actionId == "clearSituationOutfit"
        ; target = NPC, strParam = situation
        If OutfitScript
            OutfitScript.ClearSituationPreset_Execute(target, strParam)
        EndIf

    ; ── Recurring Debt (v4) ──
    ElseIf actionId == "createRecurringDebt"
        ; target = creditor (also the speaker), target2 = debtor,
        ; intParam = amount per cycle, strParam = reason,
        ; str2Param = interval in days (string-encoded — parses to Int)
        If DebtScript && target2
            String rdReason = strParam
            If rdReason == ""
                rdReason = "recurring debt"
            EndIf
            Int rdInterval = str2Param as Int
            If rdInterval <= 0
                rdInterval = 7
            EndIf
            DebtScript.CreateRecurringDebt_Execute(target, target, target2, intParam, rdReason, rdInterval, 0)
        EndIf

    Else
        Debug.Trace("[SeverActions_PrismaUI] ExecuteAction: Unknown actionId '" + actionId + "'")
    EndIf
EndEvent

; Get the Nth pipe-delimited field from a string (0-indexed)
String Function GetPipeField(String data, Int index)
    Int pos = 0
    Int fieldNum = 0
    Int len = StringUtil.GetLength(data)

    While fieldNum < index && pos < len
        Int pipePos = StringUtil.Find(data, "|", pos)
        If pipePos < 0
            Return ""
        EndIf
        pos = pipePos + 1
        fieldNum += 1
    EndWhile

    Int nextPipe = StringUtil.Find(data, "|", pos)
    If nextPipe < 0
        Return StringUtil.Substring(data, pos)
    EndIf
    Return StringUtil.Substring(data, pos, nextPipe - pos)
EndFunction

Event OnPrismaClearPkgs(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: Clear all packages on an actor. strArg = "actorName|".}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = SeverActionsNative.FindActorByName(actorName)
    If akActor
        Debug.Trace("[SeverActions_PrismaUI] ClearAllPackages: " + akActor.GetDisplayName())
        SkyrimNetApi.ClearAllPackages(akActor)
        SeverActionsNative.Native_SetSandboxing(akActor, false)
    EndIf
EndEvent

Event OnPrismaRemovePkg(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: Remove a specific package from an actor. strArg = "actorName|packageName".}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    String packageName = StringUtil.Substring(strArg, pipePos + 1)
    Actor akActor = SeverActionsNative.FindActorByName(actorName)
    If akActor
        Debug.Trace("[SeverActions_PrismaUI] RemovePackage: " + packageName + " from " + akActor.GetDisplayName())
        SkyrimNetApi.UnregisterPackage(akActor, packageName)
        If packageName == "FollowPlayer"
            SeverActionsNative.Native_SetSandboxing(akActor, false)
        EndIf
    EndIf
EndEvent

; =============================================================================
; UTILITY FUNCTIONS
; =============================================================================

Actor Function FindFollowerByName(String name)
    {Find a registered follower by display name.}
    If !FollowerManagerScript || name == ""
        Return None
    EndIf
    Actor[] followers = FollowerManagerScript.GetAllFollowers()
    If !followers
        Return None
    EndIf
    Int i = 0
    While i < followers.Length
        Actor f = followers[i]
        If f && f.GetDisplayName() == name
            Return f
        EndIf
        i += 1
    EndWhile
    Return None
EndFunction

; FindOutfitNPCByName() — REMOVED: C++ ActionHandler searches OutfitDataStore directly

ReferenceAlias Function GetTravelAlias(Int slot)
    If !TravelScript
        Return None
    EndIf
    If slot == 0
        Return TravelScript.TravelAlias00
    ElseIf slot == 1
        Return TravelScript.TravelAlias01
    ElseIf slot == 2
        Return TravelScript.TravelAlias02
    ElseIf slot == 3
        Return TravelScript.TravelAlias03
    ElseIf slot == 4
        Return TravelScript.TravelAlias04
    EndIf
    Return None
EndFunction

Function ClearBountyForHold(String hold)
    If !ArrestScript || !BountyScript
        Return
    EndIf
    Faction f = GetCrimeFactionForHold(hold)
    If f
        BountyScript.ClearTrackedBounty(f)
    EndIf
EndFunction

Function ClearAllBounties()
    If !ArrestScript || !BountyScript
        Return
    EndIf
    BountyScript.ClearTrackedBounty(ArrestScript.CrimeFactionEastmarch)
    BountyScript.ClearTrackedBounty(ArrestScript.CrimeFactionFalkreath)
    BountyScript.ClearTrackedBounty(ArrestScript.CrimeFactionHaafingar)
    BountyScript.ClearTrackedBounty(ArrestScript.CrimeFactionHjaalmarch)
    BountyScript.ClearTrackedBounty(ArrestScript.CrimeFactionPale)
    BountyScript.ClearTrackedBounty(ArrestScript.CrimeFactionReach)
    BountyScript.ClearTrackedBounty(ArrestScript.CrimeFactionRift)
    BountyScript.ClearTrackedBounty(ArrestScript.CrimeFactionWhiterun)
    BountyScript.ClearTrackedBounty(ArrestScript.CrimeFactionWinterhold)
EndFunction

Faction Function GetCrimeFactionForHold(String hold)
    If !ArrestScript
        Return None
    EndIf
    If hold == "Eastmarch"
        Return ArrestScript.CrimeFactionEastmarch
    ElseIf hold == "Falkreath"
        Return ArrestScript.CrimeFactionFalkreath
    ElseIf hold == "Haafingar"
        Return ArrestScript.CrimeFactionHaafingar
    ElseIf hold == "Hjaalmarch"
        Return ArrestScript.CrimeFactionHjaalmarch
    ElseIf hold == "The Pale"
        Return ArrestScript.CrimeFactionPale
    ElseIf hold == "The Reach"
        Return ArrestScript.CrimeFactionReach
    ElseIf hold == "The Rift"
        Return ArrestScript.CrimeFactionRift
    ElseIf hold == "Whiterun"
        Return ArrestScript.CrimeFactionWhiterun
    ElseIf hold == "Winterhold"
        Return ArrestScript.CrimeFactionWinterhold
    EndIf
    Return None
EndFunction

String Function GetCombatStyleFromIndex(Int idx)
    If idx == 0
        Return "balanced"
    ElseIf idx == 1
        Return "aggressive"
    ElseIf idx == 2
        Return "defensive"
    ElseIf idx == 3
        Return "ranged"
    ElseIf idx == 4
        Return "healer"
    EndIf
    Return "balanced"
EndFunction

String Function GetPlayerLocationName()
    Location loc = Game.GetPlayer().GetCurrentLocation()
    String locName = ""
    If loc
        locName = loc.GetName()
        If locName != ""
            Return locName
        EndIf
    EndIf
    Return "Unknown Location"
EndFunction

Int Function BoolToInt(Bool val)
    If val
        Return 1
    EndIf
    Return 0
EndFunction
