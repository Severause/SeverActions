Scriptname SeverActions_Survival extends Quest

{
    Follower survival: hunger, fatigue and cold, with stat penalties like vanilla
    Survival Mode, sleep recovery and auto-eating from inventory.

    Needs live in the native SurvivalDataStore (cosave 'SURV' v3), each 0-100
    (0 = fine, 100 = starving / exhausted / freezing), plus lastEatAttempt (the
    hunger bracket of the last auto-eat try). Prompts read them through the
    sever_hunger / sever_fatigue / sever_cold decorators.
}

; ---- Settings (MCM) ----

Bool Property Enabled = true Auto
{Master toggle for follower survival system}

Bool Property HungerEnabled = true Auto
{Enable hunger tracking}

Bool Property FatigueEnabled = true Auto
{Enable fatigue tracking}

Bool Property ColdEnabled = true Auto
{Enable cold tracking}

Float Property HungerRate = 1.0 Auto
{Multiplier for hunger accumulation rate (0.5 = half speed, 2.0 = double)}

Float Property FatigueRate = 1.0 Auto
{Multiplier for fatigue accumulation rate}

Float Property ColdRate = 1.0 Auto
{Multiplier for cold accumulation rate}

Int Property AutoEatThreshold = 50 Auto
{Hunger level at which followers will automatically eat (0-100). 0 disables auto-eat.}

Bool Property ShowNotifications = true Auto
{Master toggle for all survival notifications}

Bool Property ShowHungerNotifications = true Auto
{Show notifications when followers eat or become hungry}

Bool Property ShowFatigueNotifications = true Auto
{Show notifications when followers become tired}

Bool Property ShowColdNotifications = true Auto
{Show notifications when followers become cold}

Float Property DebuffSeverity = 1.0 Auto
{Multiplier for all survival debuffs (speed, regen, stamina/magicka drain, cold damage).
0.0 = no penalties (needs still track), 1.0 = full (default).}

Bool Property DebugMode = false Auto
{Enable debug tracing for troubleshooting}

Bool Property UseNativeFunctions = true Auto
{Use native SKSE functions for better performance (requires SeverActionsNative.dll)}

; ---- Forms (ESP-filled) ----

Keyword Property VendorItemFood Auto
{Vanilla keyword for food items}

Keyword Property VendorItemFoodRaw Auto
{Vanilla keyword for raw food items}

; The LootScript property is gone (DR2): TryAutoEat goes through the items provider's useItem
; service. The ESP's leftover VMAD fill warning is allowlisted until P12.

FormList Property SeverActions_WarmLocations Auto
{Unused: warmth comes from IsInWarmLocation / the native checks.}

; ---- Constants ----

; Severity thresholds (as vanilla Survival Mode)
Int Property LEVEL_FINE = 0 AutoReadOnly
Int Property LEVEL_MILD = 25 AutoReadOnly      ; Peckish/Tired/Chilly
Int Property LEVEL_MODERATE = 50 AutoReadOnly  ; Hungry/Drained/Cold
Int Property LEVEL_SEVERE = 75 AutoReadOnly    ; Ravenous/Exhausted/Freezing

; Hunger removed per item
Int Property HUNGER_COOKED_MEAL = 40 AutoReadOnly
Int Property HUNGER_RAW_FOOD = 25 AutoReadOnly
Int Property HUNGER_INGREDIENT = 10 AutoReadOnly     ; a raw Ingredient, or a food Potion with neither VendorItem keyword
Int Property HUNGER_BEVERAGE = 15 AutoReadOnly       ; ales, meads, wines (IsBeverage)
Int Property HUNGER_POTION = 10 AutoReadOnly         ; non-food potions

; Base accumulation per game hour
Float Property BASE_HUNGER_PER_HOUR = 2.5 AutoReadOnly   ; ~40 hours to starving
Float Property BASE_FATIGUE_PER_HOUR = 1.67 AutoReadOnly ; ~60 hours to exhausted
Float Property BASE_COLD_PER_HOUR = 5.0 AutoReadOnly     ; scaled by exposure; warmth lowers cold instead

; The pack's "game seconds" per game hour (shared with the other scripts and SurvivalUtils.h, not
; the engine's 3600). Here only LastUpdateTime uses it.
Float Property SECONDS_PER_GAME_HOUR = 3631.0 AutoReadOnly

; ---- Internal state ----

Float LastUpdateTime        ; GetGameTimeInSeconds() at the last needs update
Bool IsUpdating = false     ; re-entrancy guard for the tick
Bool NativeAvailable = false ; cached CheckNativeAvailable()

; ---- Initialization ----

Event OnInit()
    Debug.Trace("[SeverActions_Survival] Initialized")
    Maintenance()
EndEvent

Function Maintenance()
    {Called on init, on every load (the survival provider) and by StartTracking: registers the
     listeners and arms the update loop.}

    ; These two register even while disabled: the UI master toggle must work without a reload,
    ; and the verb handlers (survival.ateFood / survival.drank from SeverActions_Loot, M-V) no-op
    ; while the system is off.
    RegisterForModEvent("SeverActions_SurvivalToggle", "OnPrismaSurvivalToggle")
    RegisterForModEvent("SeverActions_Verb_Survival", "OnVerb_Survival")

    NativeAvailable = CheckNativeAvailable()

    ; IsUpdating is save-persisted: a save made mid-tick would otherwise stall the loop forever.
    IsUpdating = false

    ; Push the master switch before the disabled early-out: while off, the survival decorators
    ; report 0 for every actor so the prompt stops rendering. Stored needs are kept.
    If NativeAvailable
        SeverActionsNativeExt.Native_Survival_SetEnabled(Enabled)
    EndIf

    ; Before the disabled early-out: the penalties it removes outlive the switch.
    _ClearHomedStrangerPenalties()

    If !Enabled
        Debug.Trace("[SeverActions_Survival] System disabled, skipping maintenance")
        Return
    EndIf
    If NativeAvailable
        Debug.Trace("[SeverActions_Survival] Native SKSE functions available")
        RegisterForModEvent("SeverActionsNative_FoodConsumed", "OnNativeFoodConsumed")
        ; PrismaUI per-follower include / exclude and the care-sheet "Feed" chip
        RegisterForModEvent("SeverActions_SurvivalInclude", "OnPrismaIncludeFollower")
        RegisterForModEvent("SeverActions_SurvivalExclude", "OnPrismaExcludeFollower")
        RegisterForModEvent("SeverActions_SurvivalFeed", "OnPrismaFeedFollower")
    Else
        Debug.Trace("[SeverActions_Survival] Native SKSE functions not available, using Papyrus fallback")
    EndIf

    ; OnSleepStop restores fatigue
    RegisterForSleep()

    ; Push exclusion flags to native and seed never-tracked followers
    If NativeAvailable
        SyncFollowerSurvivalToNative()
    EndIf

    LastUpdateTime = GetGameTimeInSeconds()
    ChronoArm(30.0) ; real seconds

    Debug.Trace("[SeverActions_Survival] Maintenance complete, update loop started")
EndFunction

Bool Function CheckNativeAvailable()
    {Check if SeverActionsNative SKSE plugin is available}
    If !UseNativeFunctions
        Return false
    EndIf
    ; Empty when the DLL is not loaded
    String version = SeverActionsNative.GetPluginVersion()
    Return version != ""
EndFunction

Event OnNativeFoodConsumed(String eventName, String strArg, Float numArg, Form sender)
    {Native TESEquipEvent sink: a tracked follower ate food. The sink only reports actors
     registered with Survival_StartTracking, which no script calls, so this is idle today; if
     that changes, a meal Loot.UseItem_Execute serves (EquipItem) counts here AND through the
     survival.ateFood verb.
     strArg = "<food name>|<signed decimal FormID>". numArg is the legacy float FormID (exact
     only to 2^24), a fallback for an old DLL.}
    If !Enabled || !HungerEnabled
        Return
    EndIf

    Actor follower = sender as Actor
    If !follower
        Return
    EndIf

    ; GetFormEx, not GetForm: a negative signed int is a high-mod-index FormID.
    Form foodForm = None
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos >= 0
        Int formId = StringUtil.Substring(strArg, pipePos + 1) as Int
        If formId != 0
            foodForm = Game.GetFormEx(formId)
        EndIf
    EndIf
    If !foodForm && numArg > 0.0
        foodForm = Game.GetForm(numArg as Int)
    EndIf

    If DebugMode
        Debug.Trace("[SeverActions_Survival] Native food consumed event: " + follower.GetDisplayName() + " ate " + strArg)
    EndIf

    OnFollowerAteFood(follower, foodForm)
EndEvent

Event OnPrismaIncludeFollower(String eventName, String strArg, Float numArg, Form sender)
    {PrismaUI: include a follower in survival tracking. strArg = "formID|" (signed int32).
     Resolve with Game.GetFormEx: bare GetForm returns None for a negative int, i.e. any
     high-mod-index FormID such as 0xFA005902.}
    Int pipePos = StringUtil.Find(strArg, "|")
    String formIdStr = strArg
    If pipePos >= 0
        formIdStr = StringUtil.Substring(strArg, 0, pipePos)
    EndIf
    Int formId = formIdStr as Int
    Actor follower = Game.GetFormEx(formId) as Actor
    If follower
        Debug.Trace("[SeverActions_Survival] Menu including " + follower.GetDisplayName())
        SetFollowerExcluded(follower, false)
    EndIf
EndEvent

Event OnPrismaExcludeFollower(String eventName, String strArg, Float numArg, Form sender)
    {PrismaUI: exclude a follower from survival tracking. strArg as OnPrismaIncludeFollower.}
    Int pipePos = StringUtil.Find(strArg, "|")
    String formIdStr = strArg
    If pipePos >= 0
        formIdStr = StringUtil.Substring(strArg, 0, pipePos)
    EndIf
    Int formId = formIdStr as Int
    Actor follower = Game.GetFormEx(formId) as Actor
    If follower
        Debug.Trace("[SeverActions_Survival] Menu excluding " + follower.GetDisplayName())
        SetFollowerExcluded(follower, true)
    EndIf
EndEvent

Event OnPrismaFeedFollower(String eventName, String strArg, Float numArg, Form sender)
    {PrismaUI care-sheet "Feed" chip: feed one follower through TryAutoEat, the normal meal
     path. strArg as OnPrismaIncludeFollower.}
    Int pipePos = StringUtil.Find(strArg, "|")
    String formIdStr = strArg
    If pipePos >= 0
        formIdStr = StringUtil.Substring(strArg, 0, pipePos)
    EndIf
    Int formId = formIdStr as Int
    Actor follower = Game.GetFormEx(formId) as Actor
    If follower
        Debug.Trace("[SeverActions_Survival] Menu Feed: " + follower.GetDisplayName())
        TryAutoEat(follower)
    EndIf
EndEvent

Event OnPrismaSurvivalToggle(String eventName, String strArg, Float numArg, Form sender)
    {PrismaUI master toggle. strArg = "0|on" or "0|off" -> StartTracking / StopTracking.}
    Int pipePos = StringUtil.Find(strArg, "|")
    String val = strArg
    If pipePos >= 0
        val = StringUtil.Substring(strArg, pipePos + 1)
    EndIf
    If val == "on"
        Debug.Trace("[SeverActions_Survival] Menu enabled survival system")
        StartTracking()
    Else
        Debug.Trace("[SeverActions_Survival] Menu disabled survival system")
        StopTracking()
    EndIf
EndEvent

Float Function GetGameTimeInSeconds()
    {Current game time in SECONDS_PER_GAME_HOUR units.}
    Return Utility.GetCurrentGameTime() * 24.0 * SECONDS_PER_GAME_HOUR
EndFunction

; ---- Update loop ----

Function ChronoArm(Float afSeconds)
    {Arm this script's one-shot chronometer tick (see the Chronometer block in
     SeverActionsNativeExt2.psc; event and callback names are unique per script). Re-arm
     replaces the pending tick; ticks do not survive a load (Maintenance re-arms); one
     in-flight tick can still land after Chrono_Cancel, so the handler checks Enabled.}
    RegisterForModEvent("SeverActions_Tick_Survival", "OnChronoTick_Survival")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_Survival", afSeconds)
EndFunction

Event OnChronoTick_Survival(String eventName, String strArg, Float numArg, Form sender)
    If !Enabled
        ; Let the loop die (re-arming would defeat StopTracking's Chrono_Cancel). Re-enabling
        ; goes through StartTracking -> Maintenance, which re-arms.
        Return
    EndIf
    If IsUpdating
        ChronoArm(30.0)
        Return
    EndIf

    IsUpdating = true

    Float currentTime = GetGameTimeInSeconds()
    Float secondsPassed = currentTime - LastUpdateTime
    Float hoursPassed = secondsPassed / SECONDS_PER_GAME_HOUR

    ; Accumulate until at least half a game hour has passed
    If hoursPassed >= 0.5
        UpdateAllFollowers(hoursPassed)
        LastUpdateTime = currentTime
    EndIf

    IsUpdating = false
    ChronoArm(30.0)
EndEvent

Function UpdateAllFollowers(Float hoursPassed)
    {Update needs for every current follower within 10000 units.}

    Actor player = Game.GetPlayer()
    Actor[] followers = GetCurrentFollowers()

    Int i = 0
    While i < followers.Length
        Actor follower = followers[i]
        If follower && !follower.IsDead() && !IsFollowerExcluded(follower) && follower.GetDistance(player) < 10000.0
            ; Never tracked (all zeros): seed random starting needs
            Int h = GetFollowerHunger(follower)
            Int f = GetFollowerFatigue(follower)
            Int c = GetFollowerCold(follower)
            If h == 0 && f == 0 && c == 0
                h = Utility.RandomInt(10, 35)
                f = Utility.RandomInt(10, 40)
                c = Utility.RandomInt(0, 15)
                SetFollowerHunger(follower, h)
                SetFollowerFatigue(follower, f)
                SetFollowerCold(follower, c)
                Debug.Trace("[SeverActions_Survival] Auto-initialized " + follower.GetDisplayName() + " H=" + h + " F=" + f + " C=" + c)
            EndIf
            UpdateFollowerSurvival(follower, hoursPassed)
        EndIf
        i += 1
    EndWhile

    ; Followers only by design: needs invented for bystanders get narrated by the prompt.
    ; The decorators are follower-gated too.
EndFunction

Function UpdateFollowerSurvival(Actor akFollower, Float hoursPassed)
    {Update a single follower's survival stats}

    Int currentHunger = GetFollowerHunger(akFollower)
    Int currentFatigue = GetFollowerFatigue(akFollower)
    Int currentCold = GetFollowerCold(akFollower)

    ; Previous levels, for the level-change notifications
    Int prevHungerLevel = GetSeverityLevel(currentHunger)
    Int prevFatigueLevel = GetSeverityLevel(currentFatigue)
    Int prevColdLevel = GetSeverityLevel(currentCold)
    Bool mealInFlight = False

    If HungerEnabled
        Float hungerIncrease = BASE_HUNGER_PER_HOUR * hoursPassed * HungerRate
        currentHunger = ClampInt(currentHunger + hungerIncrease as Int, 0, 100)
        SetFollowerHunger(akFollower, currentHunger)

        ; Auto-eat once per 10-point bracket from AutoEatThreshold up (50, 60, ... 100), so a
        ; follower with no food retries as hunger climbs. AutoEatThreshold 0 disables auto-eat
        ; (hunger still ticks; a manual feed still works).
        If AutoEatThreshold > 0 && currentHunger >= AutoEatThreshold
            Int lastAttemptThreshold = SeverActionsNativeExt.Native_Survival_GetLastEatAttempt(akFollower)
            Int currentBracket = (currentHunger / 10) * 10
            If currentBracket < AutoEatThreshold
                currentBracket = AutoEatThreshold
            EndIf
            If currentBracket > lastAttemptThreshold
                SeverActionsNativeExt.Native_Survival_SetLastEatAttempt(akFollower, currentBracket)
                mealInFlight = TryAutoEat(akFollower)
                If mealInFlight
                    ; The items module took the meal; its reduction lands later through the
                    ; survival.ateFood verb, which also resets the attempt tracker. Skip this
                    ; pass's notification and drain rather than act on a stale value.
                Else
                    ; A direct meal is synchronous, and EatFood reset the attempt tracker.
                    currentHunger = GetFollowerHunger(akFollower)
                EndIf
            EndIf
        Else
            SeverActionsNativeExt.Native_Survival_SetLastEatAttempt(akFollower, 0)
        EndIf

        If !mealInFlight
            If ShowNotifications && ShowHungerNotifications && GetSeverityLevel(currentHunger) > prevHungerLevel
                NotifyHungerChange(akFollower, currentHunger)
            EndIf

            ApplyHungerDrain(akFollower, currentHunger, hoursPassed)
        EndIf
    EndIf

    If FatigueEnabled
        Float fatigueIncrease = BASE_FATIGUE_PER_HOUR * hoursPassed * FatigueRate
        currentFatigue = ClampInt(currentFatigue + fatigueIncrease as Int, 0, 100)
        SetFollowerFatigue(akFollower, currentFatigue)

        If ShowNotifications && ShowFatigueNotifications && GetSeverityLevel(currentFatigue) > prevFatigueLevel
            NotifyFatigueChange(akFollower, currentFatigue)
        EndIf

        ApplyFatigueDrain(akFollower, currentFatigue, hoursPassed)
    EndIf

    If ColdEnabled
        Float coldChange = CalculateColdChange(akFollower, hoursPassed)
        currentCold = ClampInt(currentCold + coldChange as Int, 0, 100)
        SetFollowerCold(akFollower, currentCold)

        If ShowNotifications && ShowColdNotifications && GetSeverityLevel(currentCold) > prevColdLevel
            NotifyColdChange(akFollower, currentCold)
        EndIf

        ApplyColdDamage(akFollower, currentCold, hoursPassed)
    EndIf

    ; Speed and regen penalties
    ApplyStatPenalties(akFollower, currentHunger, currentFatigue, currentCold)

    ; Re-read hunger from the store rather than write back the local copy: a meal handed to
    ; the items module may have lowered it since, and the local value would undo that meal.
    If NativeAvailable
        SeverActionsNative.Native_Survival_SetNeeds(akFollower, GetFollowerHunger(akFollower) as Float, currentFatigue as Float, currentCold as Float)
    EndIf
EndFunction

; ---- Sleep ----

Event OnSleepStart(Float afSleepStartTime, Float afDesiredSleepEndTime)
    Debug.Trace("[SeverActions_Survival] Player sleeping, followers will rest")
EndEvent

Event OnSleepStop(Bool abInterrupted)
    {When the player wakes from an uninterrupted sleep, followers' fatigue is fully restored.}

    If !Enabled || !FatigueEnabled || abInterrupted
        Return
    EndIf

    ; Sleep length is not measured: every uninterrupted sleep counts as a full 8 hours
    Float hoursSlept = 8.0
    Float fatigueReduction = (hoursSlept / 8.0) * 100.0 ; 8 hours = full restore

    Actor[] followers = GetCurrentFollowers()
    Int i = 0
    While i < followers.Length
        Actor follower = followers[i]
        If follower && !follower.IsDead() && !IsFollowerExcluded(follower)
            Int currentFatigue = GetFollowerFatigue(follower)
            Int newFatigue = ClampInt(currentFatigue - fatigueReduction as Int, 0, 100)
            SetFollowerFatigue(follower, newFatigue)

            If ShowNotifications && ShowFatigueNotifications && currentFatigue >= LEVEL_MILD
                Debug.Notification(follower.GetDisplayName() + " is now well rested")
            EndIf
        EndIf
        i += 1
    EndWhile

    Debug.Trace("[SeverActions_Survival] Followers rested, fatigue restored")
EndEvent

; ---- Hunger and auto-eat ----

Bool Function TryAutoEat(Actor akFollower)
    {Have a follower eat from their inventory (cooked first, then any food, then the party's).
     Returns True when the items module took the meal and its hunger reduction is still in
     flight (it lands later in OnVerb_Survival); False when the follower ate directly here
     (hunger already reduced) or found nothing.}

    Form food = FindFoodInInventory(akFollower, true)
    If !food
        food = FindFoodInInventory(akFollower, false)
    EndIf
    If !food && NativeAvailable
        ; Party larder (the rations pool the Survival page shows): move the cheapest suitable
        ; food from whoever carries it (player included) into this follower's pack, so the
        ; normal flow below still plays the animation, sends the event and stamps MarkFed.
        ; None for a follower set to eat only their own food (the Survival page's toggle).
        food = SeverActionsNativeExt.Native_Survival_PullFoodFromParty(akFollower)
    EndIf

    If food
        ; The items module's useItem service runs Loot.UseItem_Execute (animation, SkyrimNet
        ; event), which reports back through survival.ateFood. Without the module it returns
        ; False and the follower eats directly.
        String foodName = food.GetName()
        If SeverActions_ModuleBase.CallBool("items", "useItem", akFollower, None, foodName)
            Debug.Trace("[SeverActions_Survival] TryAutoEat: items.useItem fed " + akFollower.GetDisplayName() + " " + foodName)
            Return True
        EndIf
        ; Direct eating: the items module is absent, or its service could not find the item
        EatFood(akFollower, food, HungerRestoreFor(food))
        Return False
    EndIf

    If ShowNotifications && ShowHungerNotifications && GetFollowerHunger(akFollower) >= LEVEL_SEVERE
        Debug.Notification(akFollower.GetDisplayName() + " is starving and has no food!")
    EndIf
    Return False
EndFunction

Form Function FindFoodInInventory(Actor akActor, Bool cookedOnly)
    {First food item in the actor's inventory; cookedOnly limits it to VendorItemFood items that are not raw.}

    Int numItems = akActor.GetNumItems()
    Int i = 0
    While i < numItems
        Form item = akActor.GetNthForm(i)
        If item
            Potion foodItem = item as Potion
            If foodItem && foodItem.IsFood()
                Bool isCooked = foodItem.HasKeyword(VendorItemFood) && !foodItem.HasKeyword(VendorItemFoodRaw)

                If cookedOnly && isCooked
                    Return item
                ElseIf !cookedOnly
                    Return item
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile

    Return None
EndFunction

Function EatFood(Actor akFollower, Form akFood, Int hungerRestore)
    {Direct meal: remove one item silently (no animation) and lower hunger by hungerRestore.}

    akFollower.RemoveItem(akFood, 1, true)

    Int currentHunger = GetFollowerHunger(akFollower)
    Int newHunger = ClampInt(currentHunger - hungerRestore, 0, 100)
    SetFollowerHunger(akFollower, newHunger)

    ; They ate: auto-eat starts over from the first bracket (as OnFollowerAteFood)
    SeverActionsNativeExt.Native_Survival_SetLastEatAttempt(akFollower, 0)

    ; lastFedGameTime, for the care sheet's "fed N hours ago"
    If NativeAvailable
        SeverActionsNative.Native_Survival_MarkFed(akFollower)
    EndIf

    If ShowNotifications && ShowHungerNotifications
        Debug.Notification(akFollower.GetDisplayName() + " ate some " + akFood.GetName())
    EndIf

    Debug.Trace("[SeverActions_Survival] " + akFollower.GetDisplayName() + " ate " + akFood.GetName() + ", hunger: " + currentHunger + " -> " + newHunger)
EndFunction

; ---- Cold ----

Float Function CalculateColdChange(Actor akFollower, Float hoursPassed)
    {Change in cold over hoursPassed (negative = warming up), from the environment.}

    If NativeAvailable
        Return CalculateColdChangeNative(akFollower, hoursPassed)
    EndIf

    Return CalculateColdChangePapyrus(akFollower, hoursPassed)
EndFunction

Float Function CalculateColdChangeNative(Actor akFollower, Float hoursPassed)
    {Calculate cold change using native SKSE functions}

    ; Warm interior or a heat source within 512 units: warm up quickly
    If SeverActionsNative.Survival_IsInWarmInterior(akFollower)
        Return -10.0 * hoursPassed
    EndIf

    If SeverActionsNative.Survival_IsNearHeatSource(akFollower, 512.0)
        Return -10.0 * hoursPassed
    EndIf

    ; Exposure 0.0-1.0; none = a mild environment, warm up slowly
    Float exposure = SeverActionsNative.Survival_CalculateColdExposure(akFollower)

    If exposure <= 0.0
        Return -5.0 * hoursPassed
    EndIf

    ; Exposure 1.0 doubles the base rate
    Float coldMultiplier = 1.0 + exposure

    Return BASE_COLD_PER_HOUR * hoursPassed * ColdRate * coldMultiplier
EndFunction

Float Function CalculateColdChangePapyrus(Actor akFollower, Float hoursPassed)
    {Calculate cold change using Papyrus (fallback when native unavailable)}

    If IsInWarmLocation(akFollower)
        Return -10.0 * hoursPassed
    EndIf

    Weather currentWeather = Weather.GetCurrentWeather()
    Float coldMultiplier = 1.0

    If currentWeather
        Int weatherClass = currentWeather.GetClassification()
        ; 0=Pleasant, 1=Cloudy, 2=Rainy, 3=Snow
        If weatherClass == 3 ; Snow
            coldMultiplier = 2.0
        ElseIf weatherClass == 2 ; Rain
            coldMultiplier = 1.5
        EndIf
    EndIf

    ; Interiors are warmer. Unreachable while IsInWarmLocation treats every interior as warm.
    If akFollower.IsInInterior()
        coldMultiplier = coldMultiplier * 0.3
    EndIf

    Return BASE_COLD_PER_HOUR * hoursPassed * ColdRate * coldMultiplier
EndFunction

Bool Function IsInWarmLocation(Actor akFollower)
    {True in a warm interior or near a heat source (Papyrus fallback: any interior, or a campfire).}

    If NativeAvailable
        If SeverActionsNative.Survival_IsInWarmInterior(akFollower)
            Return true
        EndIf
        If SeverActionsNative.Survival_IsNearHeatSource(akFollower, 512.0)
            Return true
        EndIf
        Return false
    EndIf

    If akFollower.IsInInterior()
        Return true
    EndIf

    If IsNearCampfire(akFollower)
        Return true
    EndIf

    Return false
EndFunction

Bool Function IsNearCampfire(Actor akFollower)
    {Check if follower is near a campfire or heat source}

    If NativeAvailable
        Return SeverActionsNative.Survival_IsNearCampfire(akFollower, 512.0)
    EndIf

    Return IsNearCampfirePapyrus(akFollower)
EndFunction

Bool Function IsNearCampfirePapyrus(Actor akFollower)
    {Check if follower is near a campfire (Papyrus fallback): a named fire-like object in the
     follower's cell within 512 units.}

    Float searchRadius = 512.0 ; ~7 m

    Cell currentCell = akFollower.GetParentCell()
    If !currentCell
        Return false
    EndIf

    ; 31 is kLight, not kActivator (24); light bases rarely carry a name, so this pass seldom matches
    Int numRefs = currentCell.GetNumRefs(31)
    Int i = 0
    While i < numRefs
        ObjectReference ref = currentCell.GetNthRef(i, 31)
        If ref && ref.GetDistance(akFollower) <= searchRadius
            String name = ref.GetBaseObject().GetName()
            If StringUtil.Find(name, "Fire") >= 0 || StringUtil.Find(name, "fire") >= 0 || \
               StringUtil.Find(name, "Campfire") >= 0 || StringUtil.Find(name, "campfire") >= 0 || \
               StringUtil.Find(name, "Hearth") >= 0 || StringUtil.Find(name, "hearth") >= 0 || \
               StringUtil.Find(name, "Forge") >= 0 || StringUtil.Find(name, "forge") >= 0 || \
               StringUtil.Find(name, "Brazier") >= 0 || StringUtil.Find(name, "brazier") >= 0 || \
               StringUtil.Find(name, "Pit") >= 0
                If DebugMode
                    Debug.Trace("[SeverActions_Survival] Found heat source: " + name + " at distance " + ref.GetDistance(akFollower))
                EndIf
                Return true
            EndIf
        EndIf
        i += 1
    EndWhile

    ; Cooking furniture (pots, spits)
    numRefs = currentCell.GetNumRefs(40) ; 40 = kFurniture
    i = 0
    While i < numRefs
        ObjectReference ref = currentCell.GetNthRef(i, 40)
        If ref && ref.GetDistance(akFollower) <= searchRadius
            String name = ref.GetBaseObject().GetName()
            If StringUtil.Find(name, "Cook") >= 0 || StringUtil.Find(name, "cook") >= 0 || \
               StringUtil.Find(name, "Spit") >= 0 || StringUtil.Find(name, "spit") >= 0
                If DebugMode
                    Debug.Trace("[SeverActions_Survival] Found cooking heat source: " + name)
                EndIf
                Return true
            EndIf
        EndIf
        i += 1
    EndWhile

    Return false
EndFunction

; ---- Stat penalties ----

; Per-actor StorageUtil ints: the penalty currently applied, so it can be undone exactly
String Property PENALTY_SPEED_KEY = "SeverActions_Penalty_Speed" AutoReadOnly
String Property PENALTY_STAMINA_REGEN_KEY = "SeverActions_Penalty_StaminaRegen" AutoReadOnly
String Property PENALTY_MAGICKA_REGEN_KEY = "SeverActions_Penalty_MagickaRegen" AutoReadOnly
String Property PENALTY_HEALTH_REGEN_KEY = "SeverActions_Penalty_HealthRegen" AutoReadOnly

; Per-actor StorageUtil int, 1 = excluded from survival tracking (the source of truth; mirrored to native)
String Property EXCLUSION_KEY = "SeverActions_Survival_Excluded" AutoReadOnly

; Regen penalties, subtracted from the *RateMult AVs (HealRateMult / MagickaRateMult /
; StaminaRateMult, default 100 = full regen), never from the flat HealRate / MagickaRate /
; StaminaRate: their base values are tiny (~0.7/3/5), so any penalty there drives regen to zero.
Int Property REGEN_PENALTY_MILD = 50 AutoReadOnly      ; -> 50% regen
Int Property REGEN_PENALTY_MODERATE = 75 AutoReadOnly  ; -> 25% regen
Int Property REGEN_PENALTY_SEVERE = 90 AutoReadOnly    ; -> 10% regen
; Cap after DebuffSeverity scaling: regen never drops below 10%.
Int Property REGEN_PENALTY_FLOOR_MULT = 90 AutoReadOnly
; Per-actor flag for MigrateRegenPenalty (1 = done)
String Property REGEN_MIG_KEY = "SeverActions_RegenMigDone" AutoReadOnly

; Stamina drain per game hour by hunger level
Float Property HUNGER_STAMINA_DRAIN_MILD = 10.0 AutoReadOnly
Float Property HUNGER_STAMINA_DRAIN_MODERATE = 25.0 AutoReadOnly
Float Property HUNGER_STAMINA_DRAIN_SEVERE = 50.0 AutoReadOnly

; Magicka drain per game hour by fatigue level
Float Property FATIGUE_MAGICKA_DRAIN_MILD = 10.0 AutoReadOnly
Float Property FATIGUE_MAGICKA_DRAIN_MODERATE = 25.0 AutoReadOnly
Float Property FATIGUE_MAGICKA_DRAIN_SEVERE = 50.0 AutoReadOnly

; Health damage per game hour by cold level
Float Property COLD_DAMAGE_MILD = 5.0 AutoReadOnly
Float Property COLD_DAMAGE_MODERATE = 15.0 AutoReadOnly
Float Property COLD_DAMAGE_SEVERE = 30.0 AutoReadOnly

Function ApplyStatPenalties(Actor akFollower, Int hunger, Int fatigue, Int cold)
    {Apply penalties based on survival levels - speed, regen reduction}

    MigrateRegenPenalty(akFollower)

    ; In bleedout: clear every penalty and give some health back
    If akFollower.IsBleedingOut()
        If DebugMode
            Debug.Trace("[SeverActions_Survival] " + akFollower.GetDisplayName() + " is in bleedout! Clearing penalties and restoring health.")
        EndIf
        ClearAllPenalties(akFollower)
        akFollower.RestoreActorValue("Health", 50.0)
        Return
    EndIf

    ApplyColdSpeedPenalty(akFollower, cold)

    ApplyStaminaRegenPenalty(akFollower, hunger)
    ApplyMagickaRegenPenalty(akFollower, fatigue)
    ApplyHealthRegenPenalty(akFollower, cold)
EndFunction

Function ClearAllPenalties(Actor akFollower)
    {Clear all survival penalties from a follower}
    MigrateRegenPenalty(akFollower)
    ClearSpeedPenalty(akFollower)
    ClearStaminaRegenPenalty(akFollower)
    ClearMagickaRegenPenalty(akFollower)
    ClearHealthRegenPenalty(akFollower)
EndFunction

Function MigrateRegenPenalty(Actor akFollower)
    {One-time per-actor migration: give back any regen penalty an older build subtracted from
     the flat rate AVs (HealRate / MagickaRate / StaminaRate) and zero the stored amount, so the
     RateMult penalties start clean.}
    If StorageUtil.GetIntValue(akFollower, REGEN_MIG_KEY, 0) >= 1
        Return
    EndIf
    Int sp = StorageUtil.GetIntValue(akFollower, PENALTY_STAMINA_REGEN_KEY, 0)
    If sp > 0
        akFollower.ModAV("StaminaRate", sp)
        StorageUtil.SetIntValue(akFollower, PENALTY_STAMINA_REGEN_KEY, 0)
    EndIf
    Int mp = StorageUtil.GetIntValue(akFollower, PENALTY_MAGICKA_REGEN_KEY, 0)
    If mp > 0
        akFollower.ModAV("MagickaRate", mp)
        StorageUtil.SetIntValue(akFollower, PENALTY_MAGICKA_REGEN_KEY, 0)
    EndIf
    Int hp = StorageUtil.GetIntValue(akFollower, PENALTY_HEALTH_REGEN_KEY, 0)
    If hp > 0
        akFollower.ModAV("HealRate", hp)
        StorageUtil.SetIntValue(akFollower, PENALTY_HEALTH_REGEN_KEY, 0)
    EndIf
    StorageUtil.SetIntValue(akFollower, REGEN_MIG_KEY, 1)
EndFunction

Function ApplyColdSpeedPenalty(Actor akFollower, Int cold)
    {SpeedMult penalty by cold level: -15 moderate, -30 severe, scaled by DebuffSeverity.}

    Int prevSpeedPenalty = StorageUtil.GetIntValue(akFollower, PENALTY_SPEED_KEY, 0)

    Int newSpeedPenalty = 0

    Int level = GetSeverityLevel(cold)

    If level >= LEVEL_SEVERE
        newSpeedPenalty = (30.0 * DebuffSeverity) as Int
    ElseIf level >= LEVEL_MODERATE
        newSpeedPenalty = (15.0 * DebuffSeverity) as Int
    EndIf

    ; Swap the old penalty for the new one only when it changed
    If newSpeedPenalty != prevSpeedPenalty
        If prevSpeedPenalty > 0
            akFollower.ModAV("SpeedMult", prevSpeedPenalty)
        EndIf
        If newSpeedPenalty > 0
            akFollower.ModAV("SpeedMult", -newSpeedPenalty)
        EndIf
        StorageUtil.SetIntValue(akFollower, PENALTY_SPEED_KEY, newSpeedPenalty)
    EndIf
EndFunction

Function ApplyHungerDrain(Actor akFollower, Int hunger, Float hoursPassed)
    {Apply stamina drain over time based on hunger level - called from update loop}

    Int level = GetSeverityLevel(hunger)

    If level < LEVEL_MILD
        Return
    EndIf

    Float drainPerHour = 0.0
    If level >= LEVEL_SEVERE
        drainPerHour = HUNGER_STAMINA_DRAIN_SEVERE
    ElseIf level >= LEVEL_MODERATE
        drainPerHour = HUNGER_STAMINA_DRAIN_MODERATE
    ElseIf level >= LEVEL_MILD
        drainPerHour = HUNGER_STAMINA_DRAIN_MILD
    EndIf

    Float drain = drainPerHour * hoursPassed * HungerRate * DebuffSeverity

    ; Never below 10% of base stamina
    Float currentStamina = akFollower.GetActorValue("Stamina")
    Float minStamina = akFollower.GetBaseActorValue("Stamina") * 0.1

    If (currentStamina - drain) < minStamina
        drain = currentStamina - minStamina
        If drain < 0.0
            drain = 0.0
        EndIf
    EndIf

    If drain > 0.0
        akFollower.DamageActorValue("Stamina", drain)

        If DebugMode
            Debug.Trace("[SeverActions_Survival] " + akFollower.GetDisplayName() + " lost " + drain + " stamina from hunger (hunger level: " + hunger + ")")
        EndIf
    EndIf
EndFunction

Function ApplyFatigueDrain(Actor akFollower, Int fatigue, Float hoursPassed)
    {Apply magicka drain over time based on fatigue level - called from update loop}

    Int level = GetSeverityLevel(fatigue)

    If level < LEVEL_MILD
        Return
    EndIf

    Float drainPerHour = 0.0
    If level >= LEVEL_SEVERE
        drainPerHour = FATIGUE_MAGICKA_DRAIN_SEVERE
    ElseIf level >= LEVEL_MODERATE
        drainPerHour = FATIGUE_MAGICKA_DRAIN_MODERATE
    ElseIf level >= LEVEL_MILD
        drainPerHour = FATIGUE_MAGICKA_DRAIN_MILD
    EndIf

    Float drain = drainPerHour * hoursPassed * FatigueRate * DebuffSeverity

    ; Never below 10% of base magicka
    Float currentMagicka = akFollower.GetActorValue("Magicka")
    Float minMagicka = akFollower.GetBaseActorValue("Magicka") * 0.1

    If (currentMagicka - drain) < minMagicka
        drain = currentMagicka - minMagicka
        If drain < 0.0
            drain = 0.0
        EndIf
    EndIf

    If drain > 0.0
        akFollower.DamageActorValue("Magicka", drain)

        If DebugMode
            Debug.Trace("[SeverActions_Survival] " + akFollower.GetDisplayName() + " lost " + drain + " magicka from fatigue (fatigue level: " + fatigue + ")")
        EndIf
    EndIf
EndFunction

Function ApplyColdDamage(Actor akFollower, Int cold, Float hoursPassed)
    {Apply cold damage over time based on cold level - called from update loop}

    Int level = GetSeverityLevel(cold)

    If level < LEVEL_MILD
        Return
    EndIf

    Float damagePerHour = 0.0
    If level >= LEVEL_SEVERE
        damagePerHour = COLD_DAMAGE_SEVERE
    ElseIf level >= LEVEL_MODERATE
        damagePerHour = COLD_DAMAGE_MODERATE
    ElseIf level >= LEVEL_MILD
        damagePerHour = COLD_DAMAGE_MILD
    EndIf

    Float damage = damagePerHour * hoursPassed * ColdRate * DebuffSeverity

    ; Never below 10% of base health
    Float currentHealth = akFollower.GetActorValue("Health")
    Float minHealth = akFollower.GetBaseActorValue("Health") * 0.1

    If (currentHealth - damage) < minHealth
        damage = currentHealth - minHealth
        If damage < 0.0
            damage = 0.0
        EndIf
    EndIf

    If damage > 0.0
        akFollower.DamageActorValue("Health", damage)

        If DebugMode
            Debug.Trace("[SeverActions_Survival] " + akFollower.GetDisplayName() + " took " + damage + " cold damage (cold level: " + cold + ")")
        EndIf
    EndIf
EndFunction

Function ClearSpeedPenalty(Actor akFollower)
    {Clear the speed penalty from cold}
    Int speedPenalty = StorageUtil.GetIntValue(akFollower, PENALTY_SPEED_KEY, 0)

    If speedPenalty > 0
        akFollower.ModAV("SpeedMult", speedPenalty)
        StorageUtil.SetIntValue(akFollower, PENALTY_SPEED_KEY, 0)
    EndIf
EndFunction

; ---- Regen penalties ----

Function ApplyStaminaRegenPenalty(Actor akFollower, Int hunger)
    {Apply stamina regen penalty based on hunger level}
    Int prevPenalty = StorageUtil.GetIntValue(akFollower, PENALTY_STAMINA_REGEN_KEY, 0)
    Int newPenalty = GetRegenPenaltyForLevel(hunger)

    If newPenalty != prevPenalty
        If prevPenalty > 0
            akFollower.ModAV("StaminaRateMult",prevPenalty)
        EndIf
        If newPenalty > 0
            akFollower.ModAV("StaminaRateMult",-newPenalty)
        EndIf
        StorageUtil.SetIntValue(akFollower, PENALTY_STAMINA_REGEN_KEY, newPenalty)

        If DebugMode
            Debug.Trace("[SeverActions_Survival] " + akFollower.GetDisplayName() + " stamina regen penalty: " + prevPenalty + " -> " + newPenalty)
        EndIf
    EndIf
EndFunction

Function ClearStaminaRegenPenalty(Actor akFollower)
    {Clear the stamina regen penalty}
    Int penalty = StorageUtil.GetIntValue(akFollower, PENALTY_STAMINA_REGEN_KEY, 0)
    If penalty > 0
        akFollower.ModAV("StaminaRateMult",penalty)
        StorageUtil.SetIntValue(akFollower, PENALTY_STAMINA_REGEN_KEY, 0)
    EndIf
EndFunction

Function ApplyMagickaRegenPenalty(Actor akFollower, Int fatigue)
    {Apply magicka regen penalty based on fatigue level}
    Int prevPenalty = StorageUtil.GetIntValue(akFollower, PENALTY_MAGICKA_REGEN_KEY, 0)
    Int newPenalty = GetRegenPenaltyForLevel(fatigue)

    If newPenalty != prevPenalty
        If prevPenalty > 0
            akFollower.ModAV("MagickaRateMult",prevPenalty)
        EndIf
        If newPenalty > 0
            akFollower.ModAV("MagickaRateMult",-newPenalty)
        EndIf
        StorageUtil.SetIntValue(akFollower, PENALTY_MAGICKA_REGEN_KEY, newPenalty)

        If DebugMode
            Debug.Trace("[SeverActions_Survival] " + akFollower.GetDisplayName() + " magicka regen penalty: " + prevPenalty + " -> " + newPenalty)
        EndIf
    EndIf
EndFunction

Function ClearMagickaRegenPenalty(Actor akFollower)
    {Clear the magicka regen penalty}
    Int penalty = StorageUtil.GetIntValue(akFollower, PENALTY_MAGICKA_REGEN_KEY, 0)
    If penalty > 0
        akFollower.ModAV("MagickaRateMult",penalty)
        StorageUtil.SetIntValue(akFollower, PENALTY_MAGICKA_REGEN_KEY, 0)
    EndIf
EndFunction

Function ApplyHealthRegenPenalty(Actor akFollower, Int cold)
    {Apply health regen penalty based on cold level}
    Int prevPenalty = StorageUtil.GetIntValue(akFollower, PENALTY_HEALTH_REGEN_KEY, 0)
    Int newPenalty = GetRegenPenaltyForLevel(cold)

    If newPenalty != prevPenalty
        If prevPenalty > 0
            akFollower.ModAV("HealRateMult",prevPenalty)
        EndIf
        If newPenalty > 0
            akFollower.ModAV("HealRateMult",-newPenalty)
        EndIf
        StorageUtil.SetIntValue(akFollower, PENALTY_HEALTH_REGEN_KEY, newPenalty)

        If DebugMode
            Debug.Trace("[SeverActions_Survival] " + akFollower.GetDisplayName() + " health regen penalty: " + prevPenalty + " -> " + newPenalty)
        EndIf
    EndIf
EndFunction

Function ClearHealthRegenPenalty(Actor akFollower)
    {Clear the health regen penalty}
    Int penalty = StorageUtil.GetIntValue(akFollower, PENALTY_HEALTH_REGEN_KEY, 0)
    If penalty > 0
        akFollower.ModAV("HealRateMult",penalty)
        StorageUtil.SetIntValue(akFollower, PENALTY_HEALTH_REGEN_KEY, 0)
    EndIf
EndFunction

Int Function GetRegenPenaltyForLevel(Int survivalValue)
    {Calculate regen penalty based on survival level, scaled by DebuffSeverity}
    Int level = GetSeverityLevel(survivalValue)

    Int basePenalty = 0
    If level >= LEVEL_SEVERE
        basePenalty = REGEN_PENALTY_SEVERE
    ElseIf level >= LEVEL_MODERATE
        basePenalty = REGEN_PENALTY_MODERATE
    ElseIf level >= LEVEL_MILD
        basePenalty = REGEN_PENALTY_MILD
    EndIf

    Int scaled = (basePenalty as Float * DebuffSeverity) as Int
    ; DebuffSeverity > 1 must not push regen below the floor
    If scaled > REGEN_PENALTY_FLOOR_MULT
        scaled = REGEN_PENALTY_FLOOR_MULT
    EndIf
    Return scaled
EndFunction

; ---- Notifications ----

Function NotifyHungerChange(Actor akFollower, Int hunger)
    String name = akFollower.GetDisplayName()
    Int level = GetSeverityLevel(hunger)

    If level >= LEVEL_SEVERE
        Debug.Notification(name + " is ravenous!")
    ElseIf level >= LEVEL_MODERATE
        Debug.Notification(name + " is getting hungry")
    ElseIf level >= LEVEL_MILD
        Debug.Notification(name + " is feeling peckish")
    EndIf
EndFunction

Function NotifyFatigueChange(Actor akFollower, Int fatigue)
    String name = akFollower.GetDisplayName()
    Int level = GetSeverityLevel(fatigue)

    If level >= LEVEL_SEVERE
        Debug.Notification(name + " is exhausted!")
    ElseIf level >= LEVEL_MODERATE
        Debug.Notification(name + " is getting tired")
    ElseIf level >= LEVEL_MILD
        Debug.Notification(name + " could use some rest")
    EndIf
EndFunction

Function NotifyColdChange(Actor akFollower, Int cold)
    String name = akFollower.GetDisplayName()
    Int level = GetSeverityLevel(cold)

    If level >= LEVEL_SEVERE
        Debug.Notification(name + " is freezing!")
    ElseIf level >= LEVEL_MODERATE
        Debug.Notification(name + " is getting cold")
    ElseIf level >= LEVEL_MILD
        Debug.Notification(name + " feels a chill")
    EndIf
EndFunction

; ---- Follower detection ----

Function SyncFollowerSurvivalToNative()
    {On load: push each current follower's exclusion flag (StorageUtil is the source of truth)
     to the native store and seed random needs for a never-tracked, non-excluded follower.}

    Actor[] followers = GetCurrentFollowers()
    Int i = 0
    While i < followers.Length
        Actor follower = followers[i]
        If follower && !follower.IsDead()
            Bool excluded = IsFollowerExcluded(follower)
            SeverActionsNative.Native_Survival_SetExcluded(follower, excluded)

            Int hunger = GetFollowerHunger(follower)
            Int fatigue = GetFollowerFatigue(follower)
            Int cold = GetFollowerCold(follower)

            ; All zeros = never tracked
            If hunger == 0 && fatigue == 0 && cold == 0 && !excluded
                hunger = Utility.RandomInt(5, 30)
                fatigue = Utility.RandomInt(5, 35)
                cold = Utility.RandomInt(0, 15)
                SetFollowerHunger(follower, hunger)
                SetFollowerFatigue(follower, fatigue)
                SetFollowerCold(follower, cold)
                Debug.Trace("[SeverActions_Survival] Initialized " + follower.GetDisplayName() + " with random values: H=" + hunger + " F=" + fatigue + " C=" + cold)
            EndIf

            SeverActionsNative.Native_Survival_SetNeeds(follower, hunger as Float, fatigue as Float, cold as Float)
            Debug.Trace("[SeverActions_Survival] Synced " + follower.GetDisplayName() + ": H=" + hunger + " F=" + fatigue + " C=" + cold + " excluded=" + excluded)
        EndIf
        i += 1
    EndWhile

    Debug.Trace("[SeverActions_Survival] Synced " + followers.Length + " followers to native SurvivalDataStore")
EndFunction

Actor[] Function GetCurrentFollowers()
    {Loaded player teammates (native: plus dismissed followers with a home in the player's cell,
     when trackDismissedSurvival is on; Papyrus fallback: teammates in the player's cell).}

    If NativeAvailable
        Return SeverActionsNative.Survival_GetCurrentFollowers()
    EndIf

    Return GetCurrentFollowersPapyrus()
EndFunction

Actor[] Function GetCurrentFollowersPapyrus()
    {Get current followers using Papyrus (fallback)}

    ; IsPlayerTeammate covers every follower framework; CurrentFollowerFaction misses mods that
    ; don't use it.

    Actor player = Game.GetPlayer()
    Actor[] result = PapyrusUtil.ActorArray(0)

    Cell playerCell = player.GetParentCell()
    If playerCell
        Int numRefs = playerCell.GetNumRefs(43) ; 43 = kNPC
        Int i = 0
        While i < numRefs
            ObjectReference ref = playerCell.GetNthRef(i, 43)
            Actor actorRef = ref as Actor
            If actorRef && actorRef != player && actorRef.IsPlayerTeammate()
                result = PapyrusUtil.PushActor(result, actorRef)
            EndIf
            i += 1
        EndWhile
    EndIf

    Return result
EndFunction

; ---- Needs accessors (native SurvivalDataStore; no StorageUtil copy) ----

Int Function GetFollowerHunger(Actor akFollower)
    Return SeverActionsNative.Native_Survival_GetHunger(akFollower) as Int
EndFunction

Function SetFollowerHunger(Actor akFollower, Int value)
    SeverActionsNative.Native_Survival_SetNeeds(akFollower, value as Float, \
        GetFollowerFatigue(akFollower) as Float, GetFollowerCold(akFollower) as Float)
EndFunction

Int Function GetFollowerFatigue(Actor akFollower)
    Return SeverActionsNative.Native_Survival_GetFatigue(akFollower) as Int
EndFunction

Function SetFollowerFatigue(Actor akFollower, Int value)
    SeverActionsNative.Native_Survival_SetNeeds(akFollower, \
        GetFollowerHunger(akFollower) as Float, value as Float, GetFollowerCold(akFollower) as Float)
EndFunction

Int Function GetFollowerCold(Actor akFollower)
    Return SeverActionsNative.Native_Survival_GetCold(akFollower) as Int
EndFunction

Function SetFollowerCold(Actor akFollower, Int value)
    SeverActionsNative.Native_Survival_SetNeeds(akFollower, \
        GetFollowerHunger(akFollower) as Float, GetFollowerFatigue(akFollower) as Float, value as Float)
EndFunction

; ---- Utilities ----

Int Function GetSeverityLevel(Int value)
    {Map a 0-100 need to its LEVEL_* threshold.}
    If value >= LEVEL_SEVERE
        Return LEVEL_SEVERE
    ElseIf value >= LEVEL_MODERATE
        Return LEVEL_MODERATE
    ElseIf value >= LEVEL_MILD
        Return LEVEL_MILD
    Else
        Return LEVEL_FINE
    EndIf
EndFunction

Int Function ClampInt(Int value, Int minVal, Int maxVal)
    If value < minVal
        Return minVal
    ElseIf value > maxVal
        Return maxVal
    Else
        Return value
    EndIf
EndFunction

String Function GetHungerLevelName(Int hunger)
    Int level = GetSeverityLevel(hunger)
    If level >= LEVEL_SEVERE
        Return "Ravenous"
    ElseIf level >= LEVEL_MODERATE
        Return "Hungry"
    ElseIf level >= LEVEL_MILD
        Return "Peckish"
    Else
        Return "Satisfied"
    EndIf
EndFunction

String Function GetFatigueLevelName(Int fatigue)
    Int level = GetSeverityLevel(fatigue)
    If level >= LEVEL_SEVERE
        Return "Exhausted"
    ElseIf level >= LEVEL_MODERATE
        Return "Drained"
    ElseIf level >= LEVEL_MILD
        Return "Tired"
    Else
        Return "Rested"
    EndIf
EndFunction

String Function GetColdLevelName(Int cold)
    Int level = GetSeverityLevel(cold)
    If level >= LEVEL_SEVERE
        Return "Freezing"
    ElseIf level >= LEVEL_MODERATE
        Return "Cold"
    ElseIf level >= LEVEL_MILD
        Return "Chilly"
    Else
        Return "Warm"
    EndIf
EndFunction

; ---- Public API ----

String Function GetFollowerSurvivalStatus(Actor akFollower)
    {Readable status such as "Hungry (55/100), Chilly (30/100)", "Fine", or "" when disabled or excluded.}

    If !Enabled || IsFollowerExcluded(akFollower)
        Return ""
    EndIf

    Int hunger = GetFollowerHunger(akFollower)
    Int fatigue = GetFollowerFatigue(akFollower)
    Int cold = GetFollowerCold(akFollower)

    String status = ""

    If HungerEnabled && hunger >= LEVEL_MILD
        status += GetHungerLevelName(hunger) + " (" + hunger + "/100)"
    EndIf

    If FatigueEnabled && fatigue >= LEVEL_MILD
        If status != ""
            status += ", "
        EndIf
        status += GetFatigueLevelName(fatigue) + " (" + fatigue + "/100)"
    EndIf

    If ColdEnabled && cold >= LEVEL_MILD
        If status != ""
            status += ", "
        EndIf
        status += GetColdLevelName(cold) + " (" + cold + "/100)"
    EndIf

    If status == ""
        status = "Fine"
    EndIf

    Return status
EndFunction

Bool Function IsFollowerSurvivalEnabled()
    Return Enabled
EndFunction

; ---- Per-follower exclusion ----

Bool Function IsFollowerExcluded(Actor akFollower)
    {Check if a follower is excluded from survival tracking (None counts as excluded)}
    If !akFollower
        Return true
    EndIf
    Return StorageUtil.GetIntValue(akFollower, EXCLUSION_KEY, 0) == 1
EndFunction

Function SetFollowerExcluded(Actor akFollower, Bool excluded)
    {Exclude (clears penalties and zeroes needs) or include (seeds random needs when all are zero,
     only while survival is on) a follower; writes the StorageUtil flag and mirrors it to native.}
    If !akFollower
        Return
    EndIf

    If excluded
        ClearAllPenalties(akFollower)
        SetFollowerHunger(akFollower, 0)
        SetFollowerFatigue(akFollower, 0)
        SetFollowerCold(akFollower, 0)
        StorageUtil.SetIntValue(akFollower, EXCLUSION_KEY, 1)
        If NativeAvailable
            SeverActionsNative.Native_Survival_SetExcluded(akFollower, true)
        EndIf
        Debug.Trace("[SeverActions_Survival] " + akFollower.GetDisplayName() + " excluded from survival tracking")
    Else
        StorageUtil.SetIntValue(akFollower, EXCLUSION_KEY, 0)
        If NativeAvailable
            SeverActionsNative.Native_Survival_SetExcluded(akFollower, false)
        EndIf
        ; While survival is off the getters read 0 for everyone, so seeding would overwrite frozen needs.
        If !Enabled
            Debug.Trace("[SeverActions_Survival] " + akFollower.GetDisplayName() + " included in survival tracking (off: needs kept)")
            Return
        EndIf
        ; All zeros: never tracked, or zeroed when excluded
        Int hunger = GetFollowerHunger(akFollower)
        Int fatigue = GetFollowerFatigue(akFollower)
        Int cold = GetFollowerCold(akFollower)
        If hunger == 0 && fatigue == 0 && cold == 0
            hunger = Utility.RandomInt(5, 30)
            fatigue = Utility.RandomInt(5, 35)
            cold = Utility.RandomInt(0, 15)
            SetFollowerHunger(akFollower, hunger)
            SetFollowerFatigue(akFollower, fatigue)
            SetFollowerCold(akFollower, cold)
            If NativeAvailable
                SeverActionsNative.Native_Survival_SetNeeds(akFollower, hunger as Float, fatigue as Float, cold as Float)
            EndIf
            Debug.Trace("[SeverActions_Survival] Initialized " + akFollower.GetDisplayName() + " with random values: H=" + hunger + " F=" + fatigue + " C=" + cold)
        EndIf
        Debug.Trace("[SeverActions_Survival] " + akFollower.GetDisplayName() + " included in survival tracking")
    EndIf
EndFunction

Function ToggleFollowerExcluded(Actor akFollower)
    {Toggle a follower's exclusion from survival tracking}
    SetFollowerExcluded(akFollower, !IsFollowerExcluded(akFollower))
EndFunction

Function ExcludeFollower(Actor akFollower)
    {Exclude a follower from survival tracking. No in-tree caller (the UI uses OnPrismaExcludeFollower).}
    SetFollowerExcluded(akFollower, true)
EndFunction

Function IncludeFollower(Actor akFollower)
    {Include a follower in survival tracking. No in-tree caller (the UI uses OnPrismaIncludeFollower).}
    SetFollowerExcluded(akFollower, false)
EndFunction

Event OnVerb_Survival(String eventName, String strArg, Float numArg, Form sender)
    {The survival module's verb dispatcher (M-V). SeverActions_Loot sends "ateFood" and "drank"
     through Verb_Send: sender = the eater, str field = the item's FormID as signed decimal
     (never a float; a name would not survive localisation). Fire-and-forget (DR13): the meal
     already happened.}
    String actionId = SeverActions_ModuleBase.VerbField(strArg, 0)
    Actor eater = sender as Actor
    If !eater
        Debug.Trace("[SeverActions_Survival] OnVerb_Survival: no eater for " + actionId)
        Return
    EndIf
    Form item = None
    Int itemFid = SeverActions_ModuleBase.VerbField(strArg, 3) as Int
    If itemFid != 0
        item = Game.GetFormEx(itemFid)
    EndIf
    If actionId == "ateFood"
        OnFollowerAteFood(eater, item)
    ElseIf actionId == "drank"
        OnFollowerDrank(eater, item)
    Else
        Debug.Trace("[SeverActions_Survival] OnVerb_Survival: unknown verb " + actionId)
    EndIf
EndEvent

Function _ClearHomedStrangerPenalties()
    {One-shot: Track Dismissed survival once ticked anyone with a home, not only former followers,
     and nothing re-evaluates those NPCs now, so their stat penalties and SURV rows would stay.}
    String kClaim = "SurvivalHomedStrangerPenalties"
    If !SeverActionsNativeExt2.Migration_TryClaim(kClaim, 1)
        Return
    EndIf
    Actor[] homed = SeverActionsNative.Native_GetAllTrackedFollowers()
    Int cleared = 0
    If homed   ; not `!= None`: comparing an array with None casts None at runtime
        Int i = 0
        While i < homed.Length
            Actor a = homed[i]
            If a && !SeverActionsNativeExt2.Native_WasEverFollower(a)
                ClearAllPenalties(a)
                SeverActionsNative.Native_Survival_RemoveFollower(a)
                cleared += 1
            EndIf
            i += 1
        EndWhile
    EndIf
    SeverActionsNativeExt2.Migration_MarkDone(kClaim, 1)
    Debug.Trace("[SeverActions_Survival] cleared survival state from " + cleared + " homed non-follower(s)")
EndFunction

Int Function HungerRestoreFor(Form akFood)
    {Hunger one item removes, for both eating paths: a beverage (checked first, drinks are food
     too), raw food, a cooked meal, a raw Ingredient or a keyword-less food; a cooked meal for None
     or any other form.}
    If !akFood
        Return HUNGER_COOKED_MEAL
    EndIf
    If IsBeverage(akFood)
        Return HUNGER_BEVERAGE
    EndIf
    Potion foodItem = akFood as Potion
    If foodItem
        If VendorItemFoodRaw && foodItem.HasKeyword(VendorItemFoodRaw)
            Return HUNGER_RAW_FOOD
        ElseIf VendorItemFood && foodItem.HasKeyword(VendorItemFood)
            Return HUNGER_COOKED_MEAL
        EndIf
        Return HUNGER_INGREDIENT
    EndIf
    If akFood as Ingredient
        Return HUNGER_INGREDIENT
    EndIf
    Return HUNGER_COOKED_MEAL
EndFunction

Function OnFollowerAteFood(Actor akFollower, Form akFood = None)
    {A follower ate outside TryAutoEat's direct path (the ateFood verb, the native food event).
     Lowers hunger by the food's type (a cooked meal when akFood is None), resets the auto-eat
     tracker and stamps MarkFed.}

    If !Enabled || !HungerEnabled
        Return
    EndIf

    If !akFollower
        Return
    EndIf

    Int hungerRestore = HungerRestoreFor(akFood)

    Int currentHunger = GetFollowerHunger(akFollower)
    Int newHunger = ClampInt(currentHunger - hungerRestore, 0, 100)
    SetFollowerHunger(akFollower, newHunger)

    ; They ate: auto-eat starts over from the first bracket
    SeverActionsNativeExt.Native_Survival_SetLastEatAttempt(akFollower, 0)

    ; lastFedGameTime, for the care sheet's "fed N hours ago"
    If NativeAvailable
        SeverActionsNative.Native_Survival_MarkFed(akFollower)
    EndIf

    If DebugMode
        String foodName = "food"
        If akFood
            foodName = akFood.GetName()
        EndIf
        Debug.Trace("[SeverActions_Survival] OnFollowerAteFood: " + akFollower.GetDisplayName() + " ate " + foodName + ", hunger: " + currentHunger + " -> " + newHunger + " (restored " + hungerRestore + ")")
    EndIf
EndFunction

Function OnFollowerDrank(Actor akFollower, Form akPotion = None)
    {A follower drank a non-food potion (the drank verb): lowers hunger by HUNGER_POTION.
     Beverages are food and go through OnFollowerAteFood.}

    If !Enabled || !HungerEnabled
        Return
    EndIf

    If !akFollower
        Return
    EndIf

    Int hungerRestore = HUNGER_POTION

    Int currentHunger = GetFollowerHunger(akFollower)
    Int newHunger = ClampInt(currentHunger - hungerRestore, 0, 100)
    SetFollowerHunger(akFollower, newHunger)

    If DebugMode
        String potionName = "potion"
        If akPotion
            potionName = akPotion.GetName()
        EndIf
        Debug.Trace("[SeverActions_Survival] OnFollowerDrank: " + akFollower.GetDisplayName() + " drank " + potionName + ", hunger: " + currentHunger + " -> " + newHunger + " (restored " + hungerRestore + ")")
    EndIf
EndFunction

Bool Function IsBeverage(Form akItem)
    {True for a food Potion whose name contains a drink word (ale, wine, mead, ...). By name
     because vanilla has no beverage keyword.}
    If !akItem
        Return false
    EndIf

    Potion potionForm = akItem as Potion
    If !potionForm || !potionForm.IsFood()
        Return false
    EndIf

    String itemName = SeverActionsNative.StringToLower(akItem.GetName())

    If SeverActionsNative.StringContains(itemName, "ale")
        Return true
    ElseIf SeverActionsNative.StringContains(itemName, "wine")
        Return true
    ElseIf SeverActionsNative.StringContains(itemName, "mead")
        Return true
    ElseIf SeverActionsNative.StringContains(itemName, "milk")
        Return true
    ElseIf SeverActionsNative.StringContains(itemName, "sujamma")
        Return true
    ElseIf SeverActionsNative.StringContains(itemName, "flin")
        Return true
    ElseIf SeverActionsNative.StringContains(itemName, "shein")
        Return true
    ElseIf SeverActionsNative.StringContains(itemName, "mazte")
        Return true
    ElseIf SeverActionsNative.StringContains(itemName, "brew")
        Return true
    ElseIf SeverActionsNative.StringContains(itemName, "cider")
        Return true
    ElseIf SeverActionsNative.StringContains(itemName, "grog")
        Return true
    ElseIf SeverActionsNative.StringContains(itemName, "lager")
        Return true
    ElseIf SeverActionsNative.StringContains(itemName, "stout")
        Return true
    ElseIf SeverActionsNative.StringContains(itemName, "brandy")
        Return true
    ElseIf SeverActionsNative.StringContains(itemName, "rum")
        Return true
    ElseIf SeverActionsNative.StringContains(itemName, "whiskey")
        Return true
    ElseIf SeverActionsNative.StringContains(itemName, "vodka")
        Return true
    ElseIf SeverActionsNative.StringContains(itemName, "water")
        Return true
    ElseIf SeverActionsNative.StringContains(itemName, "juice")
        Return true
    ElseIf SeverActionsNative.StringContains(itemName, "tea")
        ; Avoid false positives: "steak" contains "tea"
        If !SeverActionsNative.StringContains(itemName, "steak")
            Return true
        EndIf
    EndIf

    Return false
EndFunction

Int Function GetTrackedFollowerCount()
    {Returns the number of followers currently being tracked (excluding excluded ones)}
    Actor[] followers = GetCurrentFollowers()
    Int count = 0
    Int i = 0
    While i < followers.Length
        If followers[i] && !IsFollowerExcluded(followers[i])
            count += 1
        EndIf
        i += 1
    EndWhile
    Return count
EndFunction

Function StartTracking()
    {Start or restart the survival tracking system}
    If DebugMode
        Debug.Trace("[SeverActions_Survival] StartTracking called")
    EndIf

    Enabled = true
    Maintenance()
EndFunction

Function StopTracking()
    {Stop the survival tracking system and clear penalties}
    If DebugMode
        Debug.Trace("[SeverActions_Survival] StopTracking called")
    EndIf

    ; Undo the speed / regen penalties on everyone who could hold one (drained stamina,
    ; magicka and health recover by themselves)
    ClearPenaltiesForEveryFollower()

    SeverActionsNativeExt2.Chrono_Cancel("SeverActions_Tick_Survival")
    Enabled = false

    ; Decorators report 0 while off (see Maintenance); stored needs are kept
    If NativeAvailable
        SeverActionsNativeExt.Native_Survival_SetEnabled(false)
    EndIf

    If DebugMode
        Debug.Trace("[SeverActions_Survival] Tracking stopped, penalties cleared")
    EndIf
EndFunction

Function ClearPenaltiesForEveryFollower()
    {Clear survival penalties from the loaded party AND the whole managed roster. Both are
     needed: GetCurrentFollowers misses unloaded / dismissed followers, the roster misses
     unmanaged teammates. ClearAllPenalties is idempotent, so the overlap is harmless.}
    Actor[] party = GetCurrentFollowers()
    Int i = 0
    While i < party.Length
        If party[i]
            ClearAllPenalties(party[i])
        EndIf
        i += 1
    EndWhile

    ; The roster from the kernel's FollowerDataStore, not FollowerManager (DR2: no cast into
    ; the followers module)
    Actor[] roster = SeverActionsNativeExt.Native_GetActiveFollowerRoster()
    If roster
        Int j = 0
        While j < roster.Length
            If roster[j]
                ClearAllPenalties(roster[j])
            EndIf
            j += 1
        EndWhile
    EndIf
EndFunction

Function DebugMsg(String msg)
    {Log debug message if debug mode is enabled}
    If DebugMode
        Debug.Trace("[SeverActions_Survival] " + msg)
    EndIf
EndFunction
