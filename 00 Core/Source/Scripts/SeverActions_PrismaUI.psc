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
SeverActions_Survival Property SurvivalScript Auto
SeverActions_FollowerManager Property FollowerManagerScript Auto
SeverActions_Loot Property LootScript Auto
SeverActions_SpellTeach Property SpellTeachScript Auto
SeverActions_Outfit Property OutfitScript Auto
SeverActions_Follow Property FollowScript Auto
SeverActions_Combat Property CombatScript Auto
SeverActions_Crafting Property CraftingScript Auto
SeverActions_Property Property PropertyScript Auto

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
    SeverActionsNative.PrismaUI_BeginPage("companions")

    ; ── Framework settings ──
    If FollowerManagerScript
        SeverActionsNative.PrismaUI_AddInt("frameworkMode", FollowerManagerScript.FrameworkMode)
        SeverActionsNative.PrismaUI_AddInt("maxFollowers", FollowerManagerScript.MaxFollowers)
        SeverActionsNative.PrismaUI_AddBool("autoDismissHostile", FollowerManagerScript.AllowAutonomousLeaving)
        SeverActionsNative.PrismaUI_AddBool("trackRelationships", FollowerManagerScript.AutoRelAssessment)
        SeverActionsNative.PrismaUI_AddFloat("rapportDecay", FollowerManagerScript.RapportDecayRate)
        SeverActionsNative.PrismaUI_AddInt("leavingThreshold", FollowerManagerScript.LeavingThreshold as Int)
        SeverActionsNative.PrismaUI_AddInt("relCooldown", FollowerManagerScript.RelationshipCooldown as Int)
    EndIf

    ; ── Companion array ──
    SeverActionsNative.PrismaUI_BeginArray("companions")
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
    SeverActionsNative.PrismaUI_EndArray()

    SeverActionsNative.PrismaUI_SendPage()
    Debug.Trace("[SeverActions_PrismaUI] SendCompanionsData DONE")
EndFunction

Function SendWorldData()
    {Build unified world page: bounties + arrest settings + travel + currency/debt.
     Combines old SendBountyData() + SendTravelData() + SendCurrencyData() under "world".}
    Debug.Trace("[SeverActions_PrismaUI] SendWorldData START")
    SeverActionsNative.PrismaUI_BeginPage("world")

    ; ── Bounties (from ArrestScript StorageUtil tracking) ──
    SeverActionsNative.PrismaUI_BeginNamedObject("bounties")
    If ArrestScript
        SeverActionsNative.PrismaUI_AddInt("Eastmarch", ArrestScript.GetTrackedBounty(ArrestScript.CrimeFactionEastmarch))
        SeverActionsNative.PrismaUI_AddInt("Falkreath", ArrestScript.GetTrackedBounty(ArrestScript.CrimeFactionFalkreath))
        SeverActionsNative.PrismaUI_AddInt("Haafingar", ArrestScript.GetTrackedBounty(ArrestScript.CrimeFactionHaafingar))
        SeverActionsNative.PrismaUI_AddInt("Hjaalmarch", ArrestScript.GetTrackedBounty(ArrestScript.CrimeFactionHjaalmarch))
        SeverActionsNative.PrismaUI_AddInt("The Pale", ArrestScript.GetTrackedBounty(ArrestScript.CrimeFactionPale))
        SeverActionsNative.PrismaUI_AddInt("The Reach", ArrestScript.GetTrackedBounty(ArrestScript.CrimeFactionReach))
        SeverActionsNative.PrismaUI_AddInt("The Rift", ArrestScript.GetTrackedBounty(ArrestScript.CrimeFactionRift))
        SeverActionsNative.PrismaUI_AddInt("Whiterun", ArrestScript.GetTrackedBounty(ArrestScript.CrimeFactionWhiterun))
        SeverActionsNative.PrismaUI_AddInt("Winterhold", ArrestScript.GetTrackedBounty(ArrestScript.CrimeFactionWinterhold))
    EndIf
    SeverActionsNative.PrismaUI_EndObject()

    ; ── Arrest settings ──
    If ArrestScript
        SeverActionsNative.PrismaUI_AddInt("arrestCooldown", ArrestScript.ArrestPlayerCooldown as Int)
        SeverActionsNative.PrismaUI_AddInt("persuasionTimeLimit", ArrestScript.PersuasionTimeLimit as Int)
    Else
        SeverActionsNative.PrismaUI_AddInt("arrestCooldown", 60)
        SeverActionsNative.PrismaUI_AddInt("persuasionTimeLimit", 90)
    EndIf

    ; ── Travel slots ──
    Int activeCount = 0
    If TravelScript
        activeCount = TravelScript.GetActiveTravelCount()
    EndIf
    SeverActionsNative.PrismaUI_AddInt("activeSlots", activeCount)

    SeverActionsNative.PrismaUI_BeginArray("slots")
    Int ti = 0
    Int slotState = 0
    ReferenceAlias slotAlias = None
    Actor slotNPC = None
    While ti < 5
        slotState = 0
        If TravelScript
            slotState = TravelScript.GetSlotState(ti)
        EndIf
        SeverActionsNative.PrismaUI_BeginObject()
        If slotState > 0
            SeverActionsNative.PrismaUI_AddBool("active", True)
            slotAlias = GetTravelAlias(ti)
            slotNPC = None
            If slotAlias
                slotNPC = slotAlias.GetActorReference()
            EndIf
            If slotNPC
                SeverActionsNative.PrismaUI_AddString("npcName", SafeActorName(slotNPC))
            Else
                SeverActionsNative.PrismaUI_AddString("npcName", "Unknown")
            EndIf
            SeverActionsNative.PrismaUI_AddString("destination", TravelScript.GetSlotDestination(ti))
            SeverActionsNative.PrismaUI_AddString("status", TravelScript.GetSlotStatusText(ti))
        Else
            SeverActionsNative.PrismaUI_AddBool("active", False)
        EndIf
        SeverActionsNative.PrismaUI_EndObject()
        ti += 1
    EndWhile
    SeverActionsNative.PrismaUI_EndArray()

    ; ── Currency settings ──
    If MCMScript
        SeverActionsNative.PrismaUI_AddBool("allowConjuredGold", MCMScript.AllowConjuredGold)
    Else
        SeverActionsNative.PrismaUI_AddBool("allowConjuredGold", True)
    EndIf

    ; ── Debt settings ──
    If DebtScript
        SeverActionsNative.PrismaUI_AddBool("overdueReminders", DebtScript.EnableOverdueReminders)
        SeverActionsNative.PrismaUI_AddInt("gracePeriod", DebtScript.OverdueGracePeriodHours as Int)
        SeverActionsNative.PrismaUI_AddInt("reportThreshold", DebtScript.ReportThresholdHours as Int)
    Else
        SeverActionsNative.PrismaUI_AddBool("overdueReminders", True)
        SeverActionsNative.PrismaUI_AddInt("gracePeriod", 24)
        SeverActionsNative.PrismaUI_AddInt("reportThreshold", 72)
    EndIf

    ; ── Debt structured data ──
    Int debtCount = 0
    Int totalPlayerOwes = 0
    Int totalOwedToPlayer = 0
    Actor thePlayer = Game.GetPlayer()
    If DebtScript && thePlayer
        debtCount = DebtScript.GetDebtCount()
        totalPlayerOwes = DebtScript.GetTotalOwedBy(thePlayer)
        totalOwedToPlayer = DebtScript.GetTotalOwedTo(thePlayer)
    EndIf
    SeverActionsNative.PrismaUI_AddInt("debtCount", debtCount)
    SeverActionsNative.PrismaUI_AddInt("totalPlayerOwes", totalPlayerOwes)
    SeverActionsNative.PrismaUI_AddInt("totalOwedToPlayer", totalOwedToPlayer)

    ; Build structured debt objects instead of flat strings
    Float currentTime = 0.0
    If DebtScript
        currentTime = DebtScript.GetGameTimeInSeconds()
    EndIf

    SeverActionsNative.PrismaUI_BeginArray("playerOwes")
    If DebtScript && thePlayer
        Int pi = 0
        While pi < debtCount
            Actor creditor = StorageUtil.GetFormValue(DebtScript, DebtScript.GetDebtKey(pi, "Creditor"), None) as Actor
            Actor debtor = StorageUtil.GetFormValue(DebtScript, DebtScript.GetDebtKey(pi, "Debtor"), None) as Actor
            If debtor == thePlayer && creditor
                Int amount = StorageUtil.GetIntValue(DebtScript, DebtScript.GetDebtKey(pi, "Amount"), 0)
                String reason = StorageUtil.GetStringValue(DebtScript, DebtScript.GetDebtKey(pi, "Reason"), "")
                Bool isRecurring = StorageUtil.GetIntValue(DebtScript, DebtScript.GetDebtKey(pi, "IsRecurring"), 0) == 1
                Float dueTime = StorageUtil.GetFloatValue(DebtScript, DebtScript.GetDebtKey(pi, "DueTime"), 0.0)
                Int creditLimit = StorageUtil.GetIntValue(DebtScript, DebtScript.GetDebtKey(pi, "CreditLimit"), 0)
                SeverActionsNative.PrismaUI_BeginObject()
                SeverActionsNative.PrismaUI_AddString("name", creditor.GetDisplayName())
                SeverActionsNative.PrismaUI_AddInt("amount", amount)
                SeverActionsNative.PrismaUI_AddString("reason", reason)
                SeverActionsNative.PrismaUI_AddBool("recurring", isRecurring)
                SeverActionsNative.PrismaUI_AddInt("creditLimit", creditLimit)
                If isRecurring
                    Int chargeAmount = StorageUtil.GetIntValue(DebtScript, DebtScript.GetDebtKey(pi, "RecurringCharge"), 0)
                    Float intervalHours = StorageUtil.GetFloatValue(DebtScript, DebtScript.GetDebtKey(pi, "RecurringInterval"), 0.0)
                    If chargeAmount > 0
                        SeverActionsNative.PrismaUI_AddString("rate", DebtScript.FormatRecurringRate(chargeAmount, intervalHours))
                    Else
                        SeverActionsNative.PrismaUI_AddString("rate", DebtScript.FormatRecurringRate(amount, intervalHours))
                    EndIf
                Else
                    SeverActionsNative.PrismaUI_AddString("rate", "")
                EndIf
                String timeStr = DebtScript.FormatTimeRemaining(dueTime, currentTime)
                SeverActionsNative.PrismaUI_AddString("due", timeStr)
                SeverActionsNative.PrismaUI_AddBool("overdue", dueTime > 0.0 && currentTime > dueTime)
                SeverActionsNative.PrismaUI_EndObject()
            EndIf
            pi += 1
        EndWhile
    EndIf
    SeverActionsNative.PrismaUI_EndArray()

    SeverActionsNative.PrismaUI_BeginArray("owedToPlayer")
    If DebtScript && thePlayer
        Int oi = 0
        While oi < debtCount
            Actor creditor2 = StorageUtil.GetFormValue(DebtScript, DebtScript.GetDebtKey(oi, "Creditor"), None) as Actor
            Actor debtor2 = StorageUtil.GetFormValue(DebtScript, DebtScript.GetDebtKey(oi, "Debtor"), None) as Actor
            If creditor2 == thePlayer && debtor2
                Int amount2 = StorageUtil.GetIntValue(DebtScript, DebtScript.GetDebtKey(oi, "Amount"), 0)
                String reason2 = StorageUtil.GetStringValue(DebtScript, DebtScript.GetDebtKey(oi, "Reason"), "")
                Bool isRecurring2 = StorageUtil.GetIntValue(DebtScript, DebtScript.GetDebtKey(oi, "IsRecurring"), 0) == 1
                Float dueTime2 = StorageUtil.GetFloatValue(DebtScript, DebtScript.GetDebtKey(oi, "DueTime"), 0.0)
                Int creditLimit2 = StorageUtil.GetIntValue(DebtScript, DebtScript.GetDebtKey(oi, "CreditLimit"), 0)
                SeverActionsNative.PrismaUI_BeginObject()
                SeverActionsNative.PrismaUI_AddString("name", debtor2.GetDisplayName())
                SeverActionsNative.PrismaUI_AddInt("amount", amount2)
                SeverActionsNative.PrismaUI_AddString("reason", reason2)
                SeverActionsNative.PrismaUI_AddBool("recurring", isRecurring2)
                SeverActionsNative.PrismaUI_AddInt("creditLimit", creditLimit2)
                If isRecurring2
                    Int chargeAmount2 = StorageUtil.GetIntValue(DebtScript, DebtScript.GetDebtKey(oi, "RecurringCharge"), 0)
                    Float intervalHours2 = StorageUtil.GetFloatValue(DebtScript, DebtScript.GetDebtKey(oi, "RecurringInterval"), 0.0)
                    If chargeAmount2 > 0
                        SeverActionsNative.PrismaUI_AddString("rate", DebtScript.FormatRecurringRate(chargeAmount2, intervalHours2))
                    Else
                        SeverActionsNative.PrismaUI_AddString("rate", DebtScript.FormatRecurringRate(amount2, intervalHours2))
                    EndIf
                Else
                    SeverActionsNative.PrismaUI_AddString("rate", "")
                EndIf
                String timeStr2 = DebtScript.FormatTimeRemaining(dueTime2, currentTime)
                SeverActionsNative.PrismaUI_AddString("due", timeStr2)
                SeverActionsNative.PrismaUI_AddBool("overdue", dueTime2 > 0.0 && currentTime > dueTime2)
                SeverActionsNative.PrismaUI_EndObject()
            EndIf
            oi += 1
        EndWhile
    EndIf
    SeverActionsNative.PrismaUI_EndArray()

    SeverActionsNative.PrismaUI_SendPage()
    Debug.Trace("[SeverActions_PrismaUI] SendWorldData DONE")
EndFunction

Function SendDashboardData()
    {Build dashboard page: mod info + system availability.
     This is a simple Papyrus fallback in case C++ DataGatherer didn't serve it.}
    Debug.Trace("[SeverActions_PrismaUI] SendDashboardData START")
    SeverActionsNative.PrismaUI_BeginPage("dashboard")

    SeverActionsNative.PrismaUI_AddString("version", "1.1")
    SeverActionsNative.PrismaUI_AddString("author", "Severause")

    ; System availability flags
    SeverActionsNative.PrismaUI_AddBool("hasFollowerManager", FollowerManagerScript != None)
    SeverActionsNative.PrismaUI_AddBool("hasSurvivalScript", SurvivalScript != None)
    SeverActionsNative.PrismaUI_AddBool("hasOutfitScript", OutfitScript != None)
    SeverActionsNative.PrismaUI_AddBool("hasLootScript", LootScript != None)
    SeverActionsNative.PrismaUI_AddBool("hasSpellTeachScript", SpellTeachScript != None)

    If FollowerManagerScript
        SeverActionsNative.PrismaUI_AddInt("frameworkMode", FollowerManagerScript.FrameworkMode)
        SeverActionsNative.PrismaUI_AddInt("maxFollowers", FollowerManagerScript.MaxFollowers)
    EndIf

    If SurvivalScript
        SeverActionsNative.PrismaUI_AddBool("survivalEnabled", SurvivalScript.Enabled)
    EndIf

    SeverActionsNative.PrismaUI_SendPage()
    Debug.Trace("[SeverActions_PrismaUI] SendDashboardData DONE")
EndFunction

; SendOutfitsData() — REMOVED: Outfits page now served by C++ DataGatherer
; via OutfitDataStore (native cosave). No Papyrus fallback needed.

Function SendSettingsData()
    {Build settings page: dialogue/tags, survival, spell teach config.
     Papyrus fallback when C++ ScriptReader can't read MCM properties.}
    Debug.Trace("[SeverActions_PrismaUI] SendSettingsData START")
    SeverActionsNative.PrismaUI_BeginPage("settings")

    ; ── Dialogue settings ──
    If MCMScript
        SeverActionsNative.PrismaUI_AddBool("dialogueAnimEnabled", MCMScript.DialogueAnimEnabled)
        SeverActionsNative.PrismaUI_AddInt("silenceChance", MCMScript.SilenceChance)
        SeverActionsNative.PrismaUI_AddBool("tagCompanion", MCMScript.TagCompanionEnabled)
        SeverActionsNative.PrismaUI_AddBool("tagEngaged", MCMScript.TagEngagedEnabled)
        SeverActionsNative.PrismaUI_AddBool("tagInScene", MCMScript.TagInSceneEnabled)
    EndIf

    ; ── Book reading ──
    SeverActionsNative.PrismaUI_AddBool("hasLootScript", LootScript != None)
    If LootScript
        SeverActionsNative.PrismaUI_AddInt("bookReadMode", LootScript.BookReadMode)
    EndIf

    ; ── Spell teaching ──
    SeverActionsNative.PrismaUI_AddBool("hasSpellTeachScript", SpellTeachScript != None)
    If SpellTeachScript
        SeverActionsNative.PrismaUI_AddBool("spellFailEnabled", SpellTeachScript.EnableFailureSystem)
        SeverActionsNative.PrismaUI_AddFloat("spellFailDifficulty", SpellTeachScript.FailureDifficultyMult)
    EndIf

    ; ── Survival ──
    SeverActionsNative.PrismaUI_AddBool("hasSurvivalScript", SurvivalScript != None)
    If SurvivalScript
        SeverActionsNative.PrismaUI_AddBool("survivalEnabled", SurvivalScript.Enabled)
        SeverActionsNative.PrismaUI_AddBool("hungerEnabled", SurvivalScript.HungerEnabled)
        SeverActionsNative.PrismaUI_AddFloat("hungerRate", SurvivalScript.HungerRate)
        SeverActionsNative.PrismaUI_AddInt("autoEatThreshold", SurvivalScript.AutoEatThreshold)
        SeverActionsNative.PrismaUI_AddBool("fatigueEnabled", SurvivalScript.FatigueEnabled)
        SeverActionsNative.PrismaUI_AddFloat("fatigueRate", SurvivalScript.FatigueRate)
        SeverActionsNative.PrismaUI_AddBool("coldEnabled", SurvivalScript.ColdEnabled)
        SeverActionsNative.PrismaUI_AddFloat("coldRate", SurvivalScript.ColdRate)
    EndIf

    ; ── Follower manager ──
    SeverActionsNative.PrismaUI_AddBool("hasFollowerManager", FollowerManagerScript != None)

    SeverActionsNative.PrismaUI_SendPage()
    Debug.Trace("[SeverActions_PrismaUI] SendSettingsData DONE")
EndFunction

; =============================================================================
; COMPANION DATA BUILDER
; Used by SendCompanionsData to build per-companion JSON objects.
; =============================================================================

Function BuildCompanionData(Actor c)
    {Build one companion object inside the companions array using the C++ builder.}
    SeverActionsNative.PrismaUI_BeginObject()
    SeverActionsNative.PrismaUI_AddString("name", SafeActorName(c))

    ; Race
    Race cRace = c.GetRace()
    If cRace
        SeverActionsNative.PrismaUI_AddString("race", cRace.GetName())
    Else
        SeverActionsNative.PrismaUI_AddString("race", "Unknown")
    EndIf

    SeverActionsNative.PrismaUI_AddInt("rapport", StorageUtil.GetFloatValue(c, "SeverFollower_Rapport", 0.0) as Int)
    SeverActionsNative.PrismaUI_AddInt("trust", StorageUtil.GetFloatValue(c, "SeverFollower_Trust", 25.0) as Int)
    SeverActionsNative.PrismaUI_AddInt("loyalty", StorageUtil.GetFloatValue(c, "SeverFollower_Loyalty", 50.0) as Int)
    SeverActionsNative.PrismaUI_AddInt("mood", StorageUtil.GetFloatValue(c, "SeverFollower_Mood", 50.0) as Int)

    ; Combat style
    If FollowerManagerScript
        SeverActionsNative.PrismaUI_AddString("combatStyle", FollowerManagerScript.GetCombatStyle(c))
    Else
        SeverActionsNative.PrismaUI_AddString("combatStyle", "balanced")
    EndIf
    SeverActionsNative.PrismaUI_AddString("home", StorageUtil.GetStringValue(c, "SeverFollower_HomeLocation", ""))

    ; Active SkyrimNet packages
    SeverActionsNative.PrismaUI_AddBool("hasFollowPkg", SafeHasPackage(c, "FollowPlayer"))
    SeverActionsNative.PrismaUI_AddBool("hasTalkPlayerPkg", SafeHasPackage(c, "TalkToPlayer"))
    SeverActionsNative.PrismaUI_AddBool("hasTalkNPCPkg", SafeHasPackage(c, "TalkToNPC"))

    ; Behavioral states
    SeverActionsNative.PrismaUI_AddBool("isSandboxing", StorageUtil.GetIntValue(c, "SeverActions_IsSandboxing", 0) == 1)
    String tvState = StorageUtil.GetStringValue(c, "SeverTravel_State", "")
    SeverActionsNative.PrismaUI_AddString("travelState", tvState)
    If tvState != ""
        SeverActionsNative.PrismaUI_AddString("travelDest", StorageUtil.GetStringValue(c, "SeverTravel_Destination", ""))
    EndIf
    SeverActionsNative.PrismaUI_AddBool("inForcedCombat", StorageUtil.GetIntValue(c, "SeverCombat_InForcedCombat", 0) == 1)
    SeverActionsNative.PrismaUI_AddBool("hasSurrendered", StorageUtil.GetIntValue(c, "SeverCombat_WasSurrendered", 0) == 1)

    SeverActionsNative.PrismaUI_EndObject()
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

Function HandleHotkeysSetting(String sKey, String sVal)
    If !MCMScript
        Return
    EndIf
    Int newKey = sVal as Int
    If sKey == "targetMode"
        MCMScript.TargetMode = newKey
        If HotkeyScript
            HotkeyScript.TargetMode = newKey
        EndIf
    ElseIf sKey == "nearestNPCRadius"
        MCMScript.NearestNPCRadius = sVal as Float
        If HotkeyScript
            HotkeyScript.NearestNPCRadius = sVal as Float
        EndIf
    ElseIf sKey == "wheelMenuKey"
        MCMScript.WheelMenuKey = newKey
        MCMScript.ApplyWheelMenuSettings()
    ElseIf sKey == "followToggleKey"
        MCMScript.FollowToggleKey = newKey
        If HotkeyScript
            HotkeyScript.UpdateFollowToggleKey(newKey)
        EndIf
    ElseIf sKey == "dismissKey"
        MCMScript.DismissKey = newKey
        If HotkeyScript
            HotkeyScript.UpdateDismissKey(newKey)
        EndIf
    ElseIf sKey == "setCompanionKey"
        MCMScript.SetCompanionKey = newKey
        If HotkeyScript
            HotkeyScript.UpdateSetCompanionKey(newKey)
        EndIf
    ElseIf sKey == "companionWaitKey"
        MCMScript.CompanionWaitKey = newKey
        If HotkeyScript
            HotkeyScript.UpdateCompanionWaitKey(newKey)
        EndIf
    ElseIf sKey == "assignHomeKey"
        MCMScript.AssignHomeKey = newKey
        If HotkeyScript
            HotkeyScript.UpdateAssignHomeKey(newKey)
        EndIf
    ElseIf sKey == "standUpKey"
        MCMScript.StandUpKey = newKey
        If HotkeyScript
            HotkeyScript.UpdateStandUpKey(newKey)
        EndIf
    ElseIf sKey == "yieldKey"
        MCMScript.YieldKey = newKey
        If HotkeyScript
            HotkeyScript.UpdateYieldKey(newKey)
        EndIf
    ElseIf sKey == "undressKey"
        MCMScript.UndressKey = newKey
        If HotkeyScript
            HotkeyScript.UpdateUndressKey(newKey)
        EndIf
    ElseIf sKey == "dressKey"
        MCMScript.DressKey = newKey
        If HotkeyScript
            HotkeyScript.UpdateDressKey(newKey)
        EndIf
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
            StorageUtil.SetIntValue(actTarget, "SeverActions_IsSandboxing", 0)
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
                StorageUtil.SetIntValue(actTarget, "SeverActions_IsSandboxing", 0)
            EndIf
        EndIf
        Utility.Wait(0.5)
        SeverActionsNative.PrismaUI_RefreshPage("companions")

    ; Survival actions
    ElseIf actType == "toggleSurvivalExclude"
        actName = SeverActionsNative.PrismaUI_ExtractJsonValue(json, "name")
        actTarget = FindFollowerByName(actName)
        If actTarget && SurvivalScript
            SurvivalScript.ToggleFollowerExcluded(actTarget)
        EndIf
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

    ; Parse pipe-delimited fields
    String actionId = GetPipeField(strArg, 0)
    String targetName = GetPipeField(strArg, 1)
    String target2Name = GetPipeField(strArg, 2)
    String strParam = GetPipeField(strArg, 3)
    Int intParam = GetPipeField(strArg, 4) as Int

    Debug.Trace("[SeverActions_PrismaUI] ExecuteAction: " + actionId + " target=" + targetName \
        + " target2=" + target2Name + " str=" + strParam + " int=" + intParam)

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

    ; Resolve optional second target ("Player" → player ref)
    Actor target2 = None
    If target2Name == "Player" || target2Name == "player"
        target2 = Game.GetPlayer()
    ElseIf target2Name != ""
        target2 = SeverActionsNative.FindActorByName(target2Name)
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

    ; ── Economy Actions ──
    ElseIf actionId == "giveGold"
        If CurrencyScript
            If target2
                CurrencyScript.GiveGold_Execute(target, target2, intParam)
            ElseIf target2Name != ""
                ; Use GiveGoldTrue which resolves by name
                CurrencyScript.GiveGoldTrue_Execute(target, target2Name, intParam)
            EndIf
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
        If ArrestScript && target2
            ArrestScript.ArrestNPC_Internal(target, target2)
        EndIf

    ElseIf actionId == "freeFromJail"
        If ArrestScript && target2
            ArrestScript.FreeNPC_Internal(target, target2)
        EndIf

    ElseIf actionId == "dispatchGuardArrest"
        If ArrestScript
            ; target = guard being dispatched
            ; target2Name = NPC to arrest (text name)
            ; field 5 (str2Param) = authority who ordered the arrest (actor name from picker)
            ; Defaults to player if not specified
            String senderName = GetPipeField(strArg, 5)
            If senderName == ""
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
            If senderName == ""
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
        StorageUtil.SetIntValue(akActor, "SeverActions_IsSandboxing", 0)
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
            StorageUtil.SetIntValue(akActor, "SeverActions_IsSandboxing", 0)
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
    If !ArrestScript
        Return
    EndIf
    Faction f = GetCrimeFactionForHold(hold)
    If f
        ArrestScript.ClearTrackedBounty(f)
    EndIf
EndFunction

Function ClearAllBounties()
    If !ArrestScript
        Return
    EndIf
    ArrestScript.ClearTrackedBounty(ArrestScript.CrimeFactionEastmarch)
    ArrestScript.ClearTrackedBounty(ArrestScript.CrimeFactionFalkreath)
    ArrestScript.ClearTrackedBounty(ArrestScript.CrimeFactionHaafingar)
    ArrestScript.ClearTrackedBounty(ArrestScript.CrimeFactionHjaalmarch)
    ArrestScript.ClearTrackedBounty(ArrestScript.CrimeFactionPale)
    ArrestScript.ClearTrackedBounty(ArrestScript.CrimeFactionReach)
    ArrestScript.ClearTrackedBounty(ArrestScript.CrimeFactionRift)
    ArrestScript.ClearTrackedBounty(ArrestScript.CrimeFactionWhiterun)
    ArrestScript.ClearTrackedBounty(ArrestScript.CrimeFactionWinterhold)
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
