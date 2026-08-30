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
SeverActions_Furniture Property FurnitureScript Auto
SeverActions_ArrestPlayer Property ArrestPlayerScript Auto

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
    If !FurnitureScript
        FurnitureScript = q as SeverActions_Furniture
    EndIf
    If !ArrestPlayerScript
        ArrestPlayerScript = q as SeverActions_ArrestPlayer
    EndIf

    Debug.Trace("[SeverActions_PrismaUI] Script references resolved - " \
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

        ; Only ONE data-request event — settings and most data are C++-owned
        ; (PrismaUISettingsHandler / PrismaUIActionHandler). The other events
        ; below are action dispatches C++ can't do itself (DispatchMethodCall
        ; reports success but never runs). World page still falls back to
        ; Papyrus for StorageUtil-dependent data.
        RegisterForModEvent("SeverActions_PrismaUI_RequestData", "OnRequestData")
        RegisterForModEvent("SeverActions_PrismaClearPkgs", "OnPrismaClearPkgs")
        RegisterForModEvent("SeverActions_PrismaRemovePkg", "OnPrismaRemovePkg")
        RegisterForModEvent("SeverActions_PrismaExecuteAction", "OnPrismaExecuteAction")
        RegisterForModEvent("SeverActions_PrismaSetHotkey", "OnPrismaSetHotkey")
        ; Bounty clear buttons — routed by ModEvent for the same DispatchMethodCall
        ; reason (see OnPrismaSetHotkey docstring).
        RegisterForModEvent("SeverActions_PrismaClearBounty", "OnPrismaClearBounty")
        RegisterForModEvent("SeverActions_PrismaClearAllBounties", "OnPrismaClearAllBounties")
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
            Debug.Trace("[SeverActions_PrismaUI] Migration complete - refreshing outfits page")
            Utility.Wait(0.5)
            SeverActionsNative.PrismaUI_RefreshPage("outfits")
        else
            Debug.Trace("[SeverActions_PrismaUI] ERROR: OutfitScript not available for migration")
        endif
    EndIf
EndEvent

; Settings and UI actions are owned entirely by C++: all settings changes
; route through PrismaUISettingsHandler (the single settings authority,
; including the debt trio the World page reads), UI actions through
; PrismaUIActionHandler. This script only serves the data-request events
; registered above — do not add Papyrus settings/action handlers here.

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
        SeverActionsNativeExt.PrismaUI_AddBool("allowAutonomousLeaving", FollowerManagerScript.AllowAutonomousLeaving)
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

    ; Bounties (with per-faction event timelines) ship from the C++ side via
    ; PrismaUIDataGatherer::BuildWorldSettingsData as an array of
    ; {crimeFactionId, amount, hold, events[]} entries. Do NOT echo them from
    ; Papyrus here — both reach the frontend on the same page request and last
    ; write wins, so a Papyrus copy would clobber the C++ array.

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

    ; Debt structured data (debtCount / totalPlayerOwes / totalOwedToPlayer /
    ; playerOwes[] / owedToPlayer[]) is built on the C++ side by
    ; PrismaUIDataGatherer::BuildWorldSettingsData. Do NOT echo it from Papyrus —
    ; both reach the frontend on the same page request and last write wins.

    SeverActionsNativeExt.PrismaUI_SendPage()
    Debug.Trace("[SeverActions_PrismaUI] SendWorldData DONE")
EndFunction

Function SendDashboardData()
    {Build dashboard page: mod info + system availability.
     This is a simple Papyrus fallback in case C++ DataGatherer didn't serve it.}
    Debug.Trace("[SeverActions_PrismaUI] SendDashboardData START")
    SeverActionsNativeExt.PrismaUI_BeginPage("dashboard")

    SeverActionsNativeExt.PrismaUI_AddString("version", "3.9.13")
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
    ; hasFollowPkg = "actively following" (drives the rail "Following" badge +
    ; the casual-follow filter). Since the 200-alias pool migration a follower
    ; rides the pool with NO FollowPlayer package for the common case, so
    ; SafeHasPackage read false while following and the badge never lit. Use
    ; IsActorActivelyFollowing — faction-gated (so it excludes a WAITING
    ; follower, unlike a bare slot check) and pool-slot aware.
    SeverActionsNativeExt.PrismaUI_AddBool("hasFollowPkg", FollowerManagerScript && FollowerManagerScript.IsActorActivelyFollowing(c))
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
; C++ DISPATCH TARGETS
; These functions are called from C++ via vm->DispatchMethodCall when an
; action requires SkyrimNet API access or other Papyrus-only functionality.
; =============================================================================

; =============================================================================
; PRISMAUI ACTIONS PAGE — Generic Action Executor
; Receives pipe-delimited (8 slots): actionId|target|target2|strParam|intParam|str2Param|targetFid|target2Fid
; Resolves actors by name and dispatches to the correct script function.
; =============================================================================

Event OnPrismaExecuteAction(string eventName, string strArg, float numArg, Form sender)
    EnsureScriptReferences()

    ; Parse pipe-delimited fields (8 slots — actionId | target | target2 |
    ; strParam | intParam | str2Param | targetFid | target2Fid). str2Param is
    ; empty for most actions; many verbs (setSituationOutfit, createRecurringDebt,
    ; travel pace, loot take-lists, sell/buy gold, dispatch authority, etc.) use
    ; it for a second string parameter. Fields 7/8 carry the pickers' exact
    ; FormIDs as signed decimal (empty on an older DLL → 0 → name fallback below).
    String actionId = GetPipeField(strArg, 0)
    String targetName = GetPipeField(strArg, 1)
    String target2Name = GetPipeField(strArg, 2)
    String strParam = GetPipeField(strArg, 3)
    Int intParam = GetPipeField(strArg, 4) as Int
    String str2Param = GetPipeField(strArg, 5)
    Int targetFid = GetPipeField(strArg, 6) as Int
    Int target2Fid = GetPipeField(strArg, 7) as Int

    Debug.Trace("[SeverActions_PrismaUI] ExecuteAction: " + actionId + " target=" + targetName \
        + " target2=" + target2Name + " str=" + strParam + " int=" + intParam + " str2=" + str2Param \
        + " fid=" + targetFid + " fid2=" + target2Fid)

    ; ── Resolve primary target: exact identity first ──
    ; sender (set by C++ from targetFormId) > pipe FormID > name. Name
    ; resolution is Levenshtein-fuzzy and picked the wrong duplicate-named
    ; NPC — this page includes hostile verbs (attackTarget / arrestNPC), so
    ; exactness matters. "Player" keeps its sentinel path (rail sends fid 0).
    Actor target = sender as Actor
    If !target && targetFid != 0
        target = Game.GetFormEx(targetFid) as Actor
    EndIf
    If !target
        If targetName == "Player" || targetName == "player"
            target = Game.GetPlayer()
        Else
            target = SeverActionsNative.FindActorByName(targetName)
        EndIf
    EndIf
    If !target
        Debug.Trace("[SeverActions_PrismaUI] ExecuteAction: Could not find target '" + targetName + "'")
        Return
    EndIf

    ; ── Resolve optional second target: exact identity first ──
    ; Several downstream Execute paths take target2Name as a raw string and
    ; resolve it again themselves via FindActorByName (DispatchGuardToArrest_Execute
    ; target2Name slot, DispatchGuardToHome_Execute target2Name slot, etc.).
    ; FindActorByName fuzzy-matches via Levenshtein,
    ; so a literal "Player" sentinel from the picker would otherwise match the
    ; first NPC whose name contains "Player" (e.g. "Player Friend"). Whenever
    ; we successfully resolve target2 to an Actor, also overwrite target2Name
    ; with that actor's actual display name so the raw-string path can't
    ; collide. For the player specifically, "Player" → player.GetDisplayName().
    Actor target2 = None
    If target2Fid != 0
        target2 = Game.GetFormEx(target2Fid) as Actor
    EndIf
    If target2
        target2Name = target2.GetDisplayName()
    ElseIf target2Name == "Player" || target2Name == "player"
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

    ElseIf actionId == "assignWork"
        ; Same model as the AssignWork SkyrimNet action — works on ANY NPC
        ; (target resolved via FindActorByName above) and opens the retainer
        ; popup so the player picks the workplace + job. The frontend closes the
        ; dashboard on Execute so the non-pausing popup isn't suppressed.
        If FollowerManagerScript
            FollowerManagerScript.AssignWork(target, "")
        EndIf

    ElseIf actionId == "setCombatStyle"
        If FollowerManagerScript
            FollowerManagerScript.SetCombatStyle(target, strParam)
        EndIf

    ElseIf actionId == "kidnapNPC"
        ; Kidnap system (opt-in): target = the abducting companion,
        ; strParam = victim name (global off-screen resolve inside KidnapNPC),
        ; str2Param = destination. KidnapNPC itself notifies if the toggle is off.
        If FollowerManagerScript
            FollowerManagerScript.KidnapNPC(target, strParam, str2Param)
        EndIf

    ElseIf actionId == "releaseCaptive"
        ; target = whoever unties them; strParam = captive name (optional —
        ; matched against active captives only, single captive needs no name).
        If FollowerManagerScript
            FollowerManagerScript.ReleaseCaptive(target, strParam)
        EndIf

    ElseIf actionId == "moveCaptive"
        ; target = escorting companion; strParam = captive name (optional);
        ; str2Param = the new hold destination.
        If FollowerManagerScript
            FollowerManagerScript.MoveCaptive(target, strParam, str2Param)
        EndIf

    ElseIf actionId == "moveCaptiveHere"
        ; target = the row's kidnapper (hint only — the entry's CURRENT
        ; kidnapper is authoritative inside); strParam = captive name.
        ; The captive is re-taken and bound at a pin dropped where the
        ; player stood at click time.
        If FollowerManagerScript
            FollowerManagerScript.MoveCaptiveHere(target, strParam)
        EndIf

    ElseIf actionId == "demandRansom"
        ; target = the companion sending the demand; strParam = captive name
        ; (optional - single captive needs no name); intParam = gold demanded
        ; (0 = ask a fair price).
        If FollowerManagerScript
            FollowerManagerScript.DemandRansom(target, strParam, intParam)
        EndIf

    ElseIf actionId == "untieCaptive"
        If FollowerManagerScript
            FollowerManagerScript.UntieCaptive(target, strParam)
        EndIf

    ElseIf actionId == "interrogateCaptive"
        ; target = the interrogator; strParam = captive name (optional).
        If FollowerManagerScript
            FollowerManagerScript.InterrogateCaptive(target, strParam)
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
        ; The PrismaUI action picker always supplies a resolved target2 Actor,
        ; so only the Actor path exists here. If a future UI surface needs
        ; name-resolution, restore a GiveGoldTrue-style fallback first.
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
            ; waitForPlayer=True preserves the page's long-standing semantics
            ; (they go there and wait). NOTE: this call site MUST be recompiled
            ; whenever TravelToPlace's signature changes - a stale 5-arg pex
            ; hard-errors at the VM (Expected 6, got 5) and the whole action
            ; silently dies (field report, Actions-page travel doing nothing).
            TravelScript.TravelToPlace(target, strParam, 0.0, True, speed, True)
        EndIf

    ElseIf actionId == "cancelTravel"
        If TravelScript
            TravelScript.CancelTravel(target)
        EndIf

    ElseIf actionId == "travelPace"
        ; str2Param carries the pace word via the 'speed' key (walk/run/sprint) —
        ; SetTravelSpeedNatural normalizes natural-language variants itself.
        If TravelScript
            TravelScript.SetTravelSpeedNatural(target, str2Param)
        EndIf

    ; ── Artisanry Actions (v5 Writ & Command coverage) ──
    ; Same member functions the SkyrimNet YAMLs call. strParam = the thing
    ; being made (frontend key 'name'); target2 = optional recipient of the
    ; finished goods; intParam = count (page seeds 1).
    ElseIf actionId == "cookMeal"
        If CraftingScript
            CraftingScript.CookMeal_Internal(target, strParam, target2, intParam)
        EndIf

    ElseIf actionId == "brewPotion"
        If CraftingScript
            CraftingScript.BrewPotion_Internal(target, strParam, target2, intParam)
        EndIf

    ElseIf actionId == "craftItem"
        If CraftingScript
            CraftingScript.CraftItem_Internal(target, strParam, target2, intParam)
        EndIf

    ElseIf actionId == "commissionItem"
        ; str2Param ('detail') = ETA text; quotedTotal 0 = the smith quotes it.
        If CraftingScript
            CraftingScript.CommissionItem_Internal(target, strParam, str2Param, intParam, 0)
        EndIf

    ElseIf actionId == "collectCommission"
        If CraftingScript
            CraftingScript.CollectCommission_Internal(target)
        EndIf

    ; ── Plunder Actions ──
    ; The loot family honours the PR #184 owned-item theft contract inside
    ; the Execute functions (silent transfer + SA tracked bounty if
    ; witnessed) — nothing extra to do at dispatch.
    ElseIf actionId == "setFollowDistance"
        ; target = companion; strParam ('name') = 'close' or 'normal'.
        If FollowScript
            FollowScript.SetFollowDistance(target, strParam)
        EndIf

    ElseIf actionId == "searchCorpse"
        ; strParam = corpse name — reveal-only, no take.
        If LootScript
            LootScript.SearchCorpse_Execute(target, strParam)
        EndIf

    ElseIf actionId == "searchContainer"
        ; strParam = container name — reveal-only, no take.
        If LootScript
            LootScript.SearchContainer_Execute(target, strParam)
        EndIf

    ElseIf actionId == "lootCorpse"
        ; strParam = corpse name; str2Param ('detail') = items to take.
        If LootScript
            String corpseTake = str2Param
            If corpseTake == ""
                corpseTake = "everything"
            EndIf
            LootScript.LootCorpse_Execute(target, strParam, corpseTake)
        EndIf

    ElseIf actionId == "lootContainer"
        If LootScript
            String contTake = str2Param
            If contTake == ""
                contTake = "everything"
            EndIf
            LootScript.LootContainer_Execute(target, strParam, contTake)
        EndIf

    ElseIf actionId == "pickUpItem"
        If LootScript
            LootScript.PickUpItem_Execute(target, strParam)
        EndIf

    ElseIf actionId == "bringItem"
        ; target2 = the recipient (required by the page). Re-enabled after the
        ; theft-contract fix in BringItem_Execute.
        If LootScript && target2
            LootScript.BringItem_Execute(target, target2, strParam)
        EndIf

    ; ── Trade Actions (buy/sell) ──
    ; str2Param ('detail') carries the total gold as text (the single int
    ; slot already holds quantity).
    ElseIf actionId == "sellItem"
        If CurrencyScript && target2
            CurrencyScript.SellItem_Execute(target, target2, strParam, intParam, str2Param as Int)
        EndIf

    ElseIf actionId == "buyItem"
        If CurrencyScript && target2
            CurrencyScript.BuyItem_Execute(target, target2, strParam, intParam, str2Param as Int)
        EndIf

    ; ── Field extras ──
    ElseIf actionId == "startFollowing"
        ; Temporary follow for ANY NPC — distinct from Recruit (no roster).
        If FollowScript
            FollowScript.StartFollowing(target)
        EndIf

    ElseIf actionId == "stopFollowing"
        If FollowScript
            FollowScript.StopFollowing(target)
        EndIf

    ElseIf actionId == "standUp"
        If FurnitureScript
            FurnitureScript.StopUsingFurniture_Execute(target)
        EndIf

    ; ── Employment (Enterprises retainers) ──────────────────────────────
    ; The board can do all of this; until now the Actions page could not.
    ; Same natives the board's Venture_UIAction verbs call, issued per-NPC.
    ; CollectInPerson (not Collect) is deliberate: the face-to-face path is
    ; the only one that reaches a defiant Tribute retainer's withheld coin.
    ElseIf actionId == "collectFromRetainer"
        SeverActionsNativeExt2.Venture_CollectInPerson(target)

    ElseIf actionId == "payRetainerArrears"
        SeverActionsNativeExt2.Venture_PayArrears(target)

    ElseIf actionId == "grantRetainerRaise"
        SeverActionsNativeExt2.Venture_GrantRaiseInPerson(target)

    ElseIf actionId == "reassureRetainer"
        SeverActionsNativeExt2.Venture_Reassure(target)

    ElseIf actionId == "brushOffRetainer"
        SeverActionsNativeExt2.Venture_BrushOff(target)

    ElseIf actionId == "grantLoan"
        SeverActionsNativeExt2.Venture_GrantLoan(target)

    ElseIf actionId == "refuseLoan"
        SeverActionsNativeExt2.Venture_RefuseLoan(target)

    ElseIf actionId == "forgiveLoan"
        SeverActionsNativeExt2.Venture_ForgiveLoan(target)

    ElseIf actionId == "bailRetainer"
        SeverActionsNativeExt2.Venture_Bail(target)

    ElseIf actionId == "settleRetainerBounty"
        SeverActionsNativeExt2.Venture_SettleBounty(target)

    ElseIf actionId == "dismissRetainer"
        SeverActionsNativeExt2.Venture_Dismiss(target)

    ; ── Gap-audit additions (2026-07) ───────────────────────────────────
    ElseIf actionId == "restrainNPC"
        ; RestrainNPC takes the victim by NAME (not an Actor) — target2 is
        ; already the resolved display name from the frontend's actor picker.
        If FollowerManagerScript
            FollowerManagerScript.RestrainNPC(target, target2Name)
        EndIf

    ElseIf actionId == "adjustRelationship"
        ; The frontend sends one axis + one signed amount; the Papyrus fn
        ; takes all four axes positionally, so route the amount into the
        ; chosen slot and leave the rest at zero.
        If FollowerManagerScript
            If strParam == "rapport"
                FollowerManagerScript.AdjustRelationship(target, intParam, 0, 0, 0)
            ElseIf strParam == "trust"
                FollowerManagerScript.AdjustRelationship(target, 0, intParam, 0, 0)
            ElseIf strParam == "loyalty"
                FollowerManagerScript.AdjustRelationship(target, 0, 0, intParam, 0)
            ElseIf strParam == "mood"
                FollowerManagerScript.AdjustRelationship(target, 0, 0, 0, intParam)
            EndIf
        EndIf

    ElseIf actionId == "payNpcBounty"
        ; target = the authority taking payment; target2 = the wanted person
        ; by name (they need not be present — the authority keys off their
        ; own hold's wanted list).
        If BountyScript
            BountyScript.PayNpcBountyToGuard_Internal(target, target2Name)
        EndIf

    ElseIf actionId == "readAloud"
        If LootScript
            LootScript.ReadBook_Execute(target, strParam)
        EndIf

    ElseIf actionId == "stopReading"
        If LootScript
            LootScript.StopReading_Execute(target)
        EndIf

    ; ── Lawkeeping extras ──
    ElseIf actionId == "turnMeIn"
        ; The guard (target) arrests the PLAYER — surrender / clear a bounty
        ; the honest way. Dangerous-flagged on the page (confirm before fire).
        If ArrestPlayerScript
            ArrestPlayerScript.ArrestPlayer_Internal(target)
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
            SeverActionsNative.Native_Arrest_Log("PrismaUI arrestNPC skipped - ArrestScript reference is None (script ref binding failed)")
        ElseIf !target2
            SeverActionsNative.Native_Arrest_Log("PrismaUI arrestNPC skipped - target2 (suspect) is None. target='" + targetName + "' target2Name='" + target2Name + "'")
        Else
            SeverActionsNative.Native_Arrest_Log("PrismaUI arrestNPC dispatching: guard='" + target.GetDisplayName() + "' suspect='" + target2.GetDisplayName() + "'")
            Bool arrestStarted = ArrestScript.ArrestNPC_Internal(target, target2)
            SeverActionsNative.Native_Arrest_Log("PrismaUI arrestNPC result: " + arrestStarted)
        EndIf

    ElseIf actionId == "freeFromJail"
        If !ArrestScript
            SeverActionsNative.Native_Arrest_Log("PrismaUI freeFromJail skipped - ArrestScript reference is None")
        ElseIf !target2
            SeverActionsNative.Native_Arrest_Log("PrismaUI freeFromJail skipped - target2 (jailed NPC) is None. target='" + targetName + "' target2Name='" + target2Name + "'")
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

    ; Completion-driven UI refresh (PR #452 review): the C++ dispatcher fires
    ; a best-effort refresh one frame after SendEvent, but most verbs mint
    ; their debts/bounties/journeys on this Papyrus stack seconds later - by
    ; here the dispatched Execute call has returned, so the gathers finally
    ; see the post-mutation stores. Runs once per verb, player-clicked, so
    ; two gathers are cheap.
    SeverActionsNative.PrismaUI_RefreshPage("world")
    SeverActionsNative.PrismaUI_RefreshPage("enterprises")
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
    ; EMPTY field guard: SKSE's StringUtil.Substring treats len=0 as
    ; "to the end of the string", so an empty field ("||") used to return
    ; the ENTIRE remaining pipe tail (field bleed - live log: target2 came
    ; back as '|outside of warmaiden's|0|walk|...', which then went through
    ; fuzzy actor-name resolution as garbage).
    If nextPipe == pos
        Return ""
    EndIf
    Return StringUtil.Substring(data, pos, nextPipe - pos)
EndFunction

Event OnPrismaClearPkgs(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: Clear all packages on an actor. strArg = "actorName|".
     Sender-first — the C++ helper sets the exact actor; the fuzzy name
     lookup is only a stale-DLL fallback (wrong-duplicate hazard).}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    Actor akActor = sender as Actor
    If !akActor
        akActor = SeverActionsNative.FindActorByName(actorName)
    EndIf
    If akActor
        Debug.Trace("[SeverActions_PrismaUI] ClearAllPackages: " + akActor.GetDisplayName())
        SkyrimNetApi.ClearAllPackages(akActor)
        SeverActionsNative.Native_SetSandboxing(akActor, false)
    EndIf
EndEvent

Event OnPrismaRemovePkg(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: Remove a specific package from an actor. strArg = "actorName|packageName".
     Sender-first — see OnPrismaClearPkgs.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String actorName = StringUtil.Substring(strArg, 0, pipePos)
    String packageName = StringUtil.Substring(strArg, pipePos + 1)
    Actor akActor = sender as Actor
    If !akActor
        akActor = SeverActionsNative.FindActorByName(actorName)
    EndIf
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

Event OnPrismaSetHotkey(String eventName, String strArg, Float numArg, Form sender)
    {Key binding changed on the PrismaUI Settings page.

     The C++ handler has ALREADY written the display value onto the MCM script
     property (that is what makes the MCM show the new key without a reload —
     both menus read the one variable). What C++ cannot do is register the key
     with the input system, so that half arrives here: SeverActions_Hotkeys
     keeps its own copy of every binding and its UpdateXKey functions do the
     UnregisterForKey/RegisterForKey pair.

     Routed as a ModEvent rather than vm->DispatchMethodCall, which reports
     success and never runs the function (see CLAUDE.md).

     strArg = "PropertyName|scanCode"; numArg carries the same code.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String propName = StringUtil.Substring(strArg, 0, pipePos)
    Int code = numArg as Int

    If !HotkeyScript
        EnsureScriptReferences()
    EndIf
    If !HotkeyScript
        Debug.Trace("[SeverActions_PrismaUI] SetHotkey: no HotkeyScript - " + propName + " not registered")
        Return
    EndIf

    ; Not a key — the config menu's Shift modifier, pushed down the same
    ; channel. Re-pushes the native menu-key registration so the new
    ; requirement takes effect immediately.
    If propName == "ConfigMenuRequireShift"
        If MCMScript
            HotkeyScript.ConfigMenuRequireShift = MCMScript.ConfigMenuRequireShift
        Else
            HotkeyScript.ConfigMenuRequireShift = (code == 1)
        EndIf
        SeverActionsNative.PrismaUI_SetMenuKey(HotkeyScript.ConfigMenuKey, HotkeyScript.ConfigMenuRequireShift)
        Debug.Trace("[SeverActions_PrismaUI] SetHotkey ConfigMenuRequireShift = " + HotkeyScript.ConfigMenuRequireShift)
        Return
    EndIf

    If propName == "FollowToggleKey"
        HotkeyScript.UpdateFollowToggleKey(code)
    ElseIf propName == "DismissKey"
        HotkeyScript.UpdateDismissKey(code)
    ElseIf propName == "StandUpKey"
        HotkeyScript.UpdateStandUpKey(code)
    ElseIf propName == "UseFurnitureKey"
        HotkeyScript.UpdateUseFurnitureKey(code)
    ElseIf propName == "YieldKey"
        HotkeyScript.UpdateYieldKey(code)
    ElseIf propName == "UndressKey"
        HotkeyScript.UpdateUndressKey(code)
    ElseIf propName == "DressKey"
        HotkeyScript.UpdateDressKey(code)
    ElseIf propName == "SetCompanionKey"
        HotkeyScript.UpdateSetCompanionKey(code)
    ElseIf propName == "CompanionWaitKey"
        HotkeyScript.UpdateCompanionWaitKey(code)
    ElseIf propName == "AssignHomeKey"
        HotkeyScript.UpdateAssignHomeKey(code)
    ElseIf propName == "SetupCampKey"
        HotkeyScript.UpdateSetupCampKey(code)
    ElseIf propName == "DropMarkerKey"
        HotkeyScript.UpdateDropMarkerKey(code)
    ElseIf propName == "TieUntieKey"
        HotkeyScript.UpdateTieUntieKey(code)
    ElseIf propName == "ConfigMenuKey"
        HotkeyScript.UpdateConfigMenuKey(code)
    Else
        Debug.Trace("[SeverActions_PrismaUI] SetHotkey: unknown binding " + propName)
        Return
    EndIf
    Debug.Trace("[SeverActions_PrismaUI] SetHotkey " + propName + " = " + code)
EndEvent

Event OnPrismaClearBounty(String eventName, String strArg, Float numArg, Form sender)
    {Native PrismaUIActionHandler routes the Clear Bounty button here.
     strArg = "0|<hold>" (SendModEvent packs "actorName|payload"; no actor
     involved in a hold-level clear, so the name half is "0").}
    Int pipePos = StringUtil.Find(strArg, "|")
    String hold = strArg
    If pipePos >= 0
        hold = StringUtil.Substring(strArg, pipePos + 1)
    EndIf
    If hold != ""
        ClearBountyForHold(hold)
    EndIf
EndEvent

Event OnPrismaClearAllBounties(String eventName, String strArg, Float numArg, Form sender)
    {Native PrismaUIActionHandler routes the Clear All Bounties button here.}
    ClearAllBounties()
EndEvent

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
