Scriptname SeverActions_Survival extends Quest

{
    Follower Survival System for SeverActions

    Tracks hunger, fatigue, and cold for followers, applying stat penalties
    similar to vanilla Survival Mode. Integrates with player sleep events
    and allows followers to auto-eat from their inventory.

    Data is stored per-follower via StorageUtil:
    - SeverActions_Survival_Hunger (0-100, 0=full, 100=starving)
    - SeverActions_Survival_Fatigue (0-100, 0=rested, 100=exhausted)
    - SeverActions_Survival_Cold (0-100, 0=warm, 100=freezing)
    - SeverActions_Survival_LastUpdate (game time of last update)
}

; =============================================================================
; PROPERTIES - Settings (Can be modified via MCM)
; =============================================================================

Bool Property Enabled = false Auto
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
{Hunger level at which followers will automatically eat (0-100)}

Bool Property ShowNotifications = true Auto
{Master toggle for all survival notifications}

Bool Property ShowHungerNotifications = true Auto
{Show notifications when followers eat or become hungry}

Bool Property ShowFatigueNotifications = true Auto
{Show notifications when followers become tired}

Bool Property ShowColdNotifications = true Auto
{Show notifications when followers become cold}

Bool Property DebugMode = false Auto
{Enable debug tracing for troubleshooting}

Bool Property UseNativeFunctions = true Auto
{Use native SKSE functions for better performance (requires SeverActionsNative.dll)}

; =============================================================================
; PROPERTIES - Keywords and Forms (Fill in CK)
; =============================================================================

Keyword Property VendorItemFood Auto
{Vanilla keyword for food items}

Keyword Property VendorItemFoodRaw Auto
{Vanilla keyword for raw food items}

; =============================================================================
; SCRIPT REFERENCES
; =============================================================================

SeverActions_Loot Property LootScript Auto
{Reference to the Loot script for UseItem action integration}

FormList Property SeverActions_WarmLocations Auto
{Optional: List of location keywords considered warm (taverns, homes, etc.)}

; =============================================================================
; CONSTANTS
; =============================================================================

; Threshold levels (matching vanilla Survival Mode)
Int Property LEVEL_FINE = 0 AutoReadOnly
Int Property LEVEL_MILD = 25 AutoReadOnly      ; Peckish/Tired/Chilly
Int Property LEVEL_MODERATE = 50 AutoReadOnly  ; Hungry/Drained/Cold
Int Property LEVEL_SEVERE = 75 AutoReadOnly    ; Ravenous/Exhausted/Freezing

; Hunger values for different food types
Int Property HUNGER_COOKED_MEAL = 40 AutoReadOnly    ; Cooked food restores more
Int Property HUNGER_RAW_FOOD = 25 AutoReadOnly       ; Raw food restores less
Int Property HUNGER_INGREDIENT = 10 AutoReadOnly     ; Ingredients restore minimal
Int Property HUNGER_BEVERAGE = 15 AutoReadOnly       ; Ales, meads, wines - not a meal but takes the edge off
Int Property HUNGER_POTION = 10 AutoReadOnly         ; Regular potions - liquid counts for something

; Base accumulation per game hour
Float Property BASE_HUNGER_PER_HOUR = 2.5 AutoReadOnly   ; ~40 hours to starving
Float Property BASE_FATIGUE_PER_HOUR = 1.67 AutoReadOnly ; ~60 hours (2.5 days) to exhausted
Float Property BASE_COLD_PER_HOUR = 5.0 AutoReadOnly     ; Faster in cold, 0 when warm

; Time conversion constant: 3631 seconds per game hour at default 20:1 timescale
Float Property SECONDS_PER_GAME_HOUR = 3631.0 AutoReadOnly

; =============================================================================
; INTERNAL STATE
; =============================================================================

Float LastUpdateTime        ; Game time in "game seconds" format (GetCurrentGameTime() * 24 * 3631)
Bool IsUpdating = false     ; Prevent re-entrant updates
Bool NativeAvailable = false ; Cached check for native function availability

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    Debug.Trace("[SeverActions_Survival] Initialized")
    Maintenance()
EndEvent

Function Maintenance()
    {Called on init and game load to set up event listeners}

    If !Enabled
        Debug.Trace("[SeverActions_Survival] System disabled, skipping maintenance")
        Return
    EndIf

    ; Check if native functions are available
    NativeAvailable = CheckNativeAvailable()
    If NativeAvailable
        Debug.Trace("[SeverActions_Survival] Native SKSE functions available")
        ; Register for native food consumption events
        RegisterForModEvent("SeverActionsNative_FoodConsumed", "OnNativeFoodConsumed")
    Else
        Debug.Trace("[SeverActions_Survival] Native SKSE functions not available, using Papyrus fallback")
    EndIf

    ; Register for game load
    RegisterForModEvent("OnPlayerLoadGame", "OnPlayerLoadGame")

    ; Register for sleep events to restore follower fatigue
    RegisterForSleep()

    ; Start the update loop - use game seconds format for precision
    LastUpdateTime = GetGameTimeInSeconds()
    RegisterForSingleUpdate(30.0) ; Check every 30 real seconds

    Debug.Trace("[SeverActions_Survival] Maintenance complete, update loop started")
EndFunction

Bool Function CheckNativeAvailable()
    {Check if SeverActionsNative SKSE plugin is available}
    If !UseNativeFunctions
        Return false
    EndIf
    ; Try to get the plugin version - if it returns empty, plugin isn't loaded
    String version = SeverActionsNative.GetPluginVersion()
    Return version != ""
EndFunction

Event OnNativeFoodConsumed(String eventName, String strArg, Float numArg, Form sender)
    {Called by native SKSE when a tracked follower eats food}
    If !Enabled || !HungerEnabled
        Return
    EndIf

    Actor follower = sender as Actor
    If !follower
        Return
    EndIf

    If DebugMode
        Debug.Trace("[SeverActions_Survival] Native food consumed event: " + follower.GetDisplayName() + " ate " + strArg)
    EndIf

    ; The native code already updated hunger in its storage
    ; Stamina recovers naturally, no penalties to update
    ; (we no longer reduce max stamina, just drain it over time)
    Int currentHunger = GetFollowerHunger(follower)

    If ShowNotifications && ShowHungerNotifications
        Debug.Notification(follower.GetDisplayName() + " ate some " + strArg)
    EndIf
EndEvent

Float Function GetGameTimeInSeconds()
    {Convert current game time to seconds for precise tracking}
    ; GetCurrentGameTime() returns days as float
    ; Multiply by 24 to get hours, then by 3631 to get game seconds
    Return Utility.GetCurrentGameTime() * 24.0 * SECONDS_PER_GAME_HOUR
EndFunction

Event OnPlayerLoadGame()
    Debug.Trace("[SeverActions_Survival] Game loaded")
    Maintenance()
EndEvent

; =============================================================================
; UPDATE LOOP
; =============================================================================

Event OnUpdate()
    If !Enabled || IsUpdating
        RegisterForSingleUpdate(30.0)
        Return
    EndIf

    IsUpdating = true

    Float currentTime = GetGameTimeInSeconds()
    Float secondsPassed = currentTime - LastUpdateTime
    Float hoursPassed = secondsPassed / SECONDS_PER_GAME_HOUR ; Convert game seconds to hours

    ; Only update if meaningful time has passed (at least 0.5 game hours = ~1815 game seconds)
    If hoursPassed >= 0.5
        UpdateAllFollowers(hoursPassed)
        LastUpdateTime = currentTime
    EndIf

    IsUpdating = false
    RegisterForSingleUpdate(30.0)
EndEvent

Function UpdateAllFollowers(Float hoursPassed)
    {Update survival stats for all current followers (skips excluded followers)}

    Actor player = Game.GetPlayer()
    Actor[] followers = GetCurrentFollowers()

    Int i = 0
    While i < followers.Length
        Actor follower = followers[i]
        If follower && !follower.IsDead() && !IsFollowerExcluded(follower) && follower.GetDistance(player) < 10000.0
            UpdateFollowerSurvival(follower, hoursPassed)
        EndIf
        i += 1
    EndWhile
EndFunction

Function UpdateFollowerSurvival(Actor akFollower, Float hoursPassed)
    {Update a single follower's survival stats}

    ; Get current values
    Int currentHunger = GetFollowerHunger(akFollower)
    Int currentFatigue = GetFollowerFatigue(akFollower)
    Int currentCold = GetFollowerCold(akFollower)

    ; Store previous levels for notification checks
    Int prevHungerLevel = GetSeverityLevel(currentHunger)
    Int prevFatigueLevel = GetSeverityLevel(currentFatigue)
    Int prevColdLevel = GetSeverityLevel(currentCold)

    ; Update hunger
    If HungerEnabled
        Float hungerIncrease = BASE_HUNGER_PER_HOUR * hoursPassed * HungerRate
        currentHunger = ClampInt(currentHunger + hungerIncrease as Int, 0, 100)
        SetFollowerHunger(akFollower, currentHunger)

        ; Check for auto-eat
        If currentHunger >= AutoEatThreshold
            TryAutoEat(akFollower)
            currentHunger = GetFollowerHunger(akFollower) ; Re-get after eating
        EndIf

        ; Notification on level change
        If ShowNotifications && ShowHungerNotifications && GetSeverityLevel(currentHunger) > prevHungerLevel
            NotifyHungerChange(akFollower, currentHunger)
        EndIf

        ; Apply stamina drain over time (actual stamina damage)
        ApplyHungerDrain(akFollower, currentHunger, hoursPassed)
    EndIf

    ; Update fatigue
    If FatigueEnabled
        Float fatigueIncrease = BASE_FATIGUE_PER_HOUR * hoursPassed * FatigueRate
        currentFatigue = ClampInt(currentFatigue + fatigueIncrease as Int, 0, 100)
        SetFollowerFatigue(akFollower, currentFatigue)

        ; Notification on level change
        If ShowNotifications && ShowFatigueNotifications && GetSeverityLevel(currentFatigue) > prevFatigueLevel
            NotifyFatigueChange(akFollower, currentFatigue)
        EndIf

        ; Apply magicka drain over time (actual magicka damage)
        ApplyFatigueDrain(akFollower, currentFatigue, hoursPassed)
    EndIf

    ; Update cold (based on environment)
    If ColdEnabled
        Float coldChange = CalculateColdChange(akFollower, hoursPassed)
        currentCold = ClampInt(currentCold + coldChange as Int, 0, 100)
        SetFollowerCold(akFollower, currentCold)

        ; Notification on level change
        If ShowNotifications && ShowColdNotifications && GetSeverityLevel(currentCold) > prevColdLevel
            NotifyColdChange(akFollower, currentCold)
        EndIf

        ; Apply cold damage over time (actual health damage)
        ApplyColdDamage(akFollower, currentCold, hoursPassed)
    EndIf

    ; Apply speed penalty from cold (the only remaining modifier)
    ApplyStatPenalties(akFollower, currentHunger, currentFatigue, currentCold)
EndFunction

; =============================================================================
; SLEEP INTEGRATION
; =============================================================================

Event OnSleepStart(Float afSleepStartTime, Float afDesiredSleepEndTime)
    ; Player started sleeping - followers will rest too
    Debug.Trace("[SeverActions_Survival] Player sleeping, followers will rest")
EndEvent

Event OnSleepStop(Bool abInterrupted)
    {When player wakes up, restore follower fatigue based on hours slept}

    If !Enabled || !FatigueEnabled || abInterrupted
        Return
    EndIf

    ; Estimate hours slept (we don't have exact value, so use a reasonable default)
    ; In vanilla, 8 hours fully restores fatigue
    Float hoursSlept = 8.0 ; Assume full rest for simplicity
    Float fatigueReduction = (hoursSlept / 8.0) * 100.0 ; Full 8 hours = full restore

    Actor[] followers = GetCurrentFollowers()
    Int i = 0
    While i < followers.Length
        Actor follower = followers[i]
        If follower && !follower.IsDead() && !IsFollowerExcluded(follower)
            Int currentFatigue = GetFollowerFatigue(follower)
            Int newFatigue = ClampInt(currentFatigue - fatigueReduction as Int, 0, 100)
            SetFollowerFatigue(follower, newFatigue)

            ; Magicka recovers naturally during sleep, no need to clear penalties
            ; (we no longer reduce max magicka, just drain it over time)

            If ShowNotifications && ShowFatigueNotifications && currentFatigue >= LEVEL_MILD
                Debug.Notification(follower.GetDisplayName() + " is now well rested")
            EndIf
        EndIf
        i += 1
    EndWhile

    Debug.Trace("[SeverActions_Survival] Followers rested, fatigue restored")
EndEvent

; =============================================================================
; HUNGER & AUTO-EAT
; =============================================================================

Function TryAutoEat(Actor akFollower)
    {Attempt to have follower eat food from their inventory}

    ; First try cooked food
    Form food = FindFoodInInventory(akFollower, true)
    If !food
        ; Then try raw food
        food = FindFoodInInventory(akFollower, false)
    EndIf

    If food
        ; Use the Loot script's UseItem action if available
        ; This provides proper animations and fires the persistent event
        If LootScript
            String foodName = food.GetName()
            Debug.Trace("[SeverActions_Survival] TryAutoEat: Using LootScript.UseItem_Execute for " + akFollower.GetDisplayName() + " to eat " + foodName)
            LootScript.UseItem_Execute(akFollower, foodName)
            ; Note: UseItem_Execute calls OnFollowerAteFood() internally, so hunger is already reduced
        Else
            ; Fallback to direct eating if Loot script not available
            Potion foodPotion = food as Potion
            Int hungerRestore = HUNGER_COOKED_MEAL
            If foodPotion && VendorItemFoodRaw && foodPotion.HasKeyword(VendorItemFoodRaw)
                hungerRestore = HUNGER_RAW_FOOD
            EndIf
            EatFood(akFollower, food, hungerRestore)
        EndIf
        Return
    EndIf

    ; No food available - maybe notify?
    If ShowNotifications && ShowHungerNotifications && GetFollowerHunger(akFollower) >= LEVEL_SEVERE
        Debug.Notification(akFollower.GetDisplayName() + " is starving and has no food!")
    EndIf
EndFunction

Form Function FindFoodInInventory(Actor akActor, Bool cookedOnly)
    {Find edible food in actor's inventory}

    Int numItems = akActor.GetNumItems()
    Int i = 0
    While i < numItems
        Form item = akActor.GetNthForm(i)
        If item
            Potion foodItem = item as Potion
            If foodItem && foodItem.IsFood()
                ; Check if it's cooked (has VendorItemFood but not VendorItemFoodRaw)
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
    {Have follower consume food item}

    ; Remove from inventory
    akFollower.RemoveItem(akFood, 1, true)

    ; Restore hunger
    Int currentHunger = GetFollowerHunger(akFollower)
    Int newHunger = ClampInt(currentHunger - hungerRestore, 0, 100)
    SetFollowerHunger(akFollower, newHunger)

    ; Stamina recovers naturally, no penalties to update
    ; (we no longer reduce max stamina, just drain it over time)

    If ShowNotifications && ShowHungerNotifications
        Debug.Notification(akFollower.GetDisplayName() + " ate some " + akFood.GetName())
    EndIf

    Debug.Trace("[SeverActions_Survival] " + akFollower.GetDisplayName() + " ate " + akFood.GetName() + ", hunger: " + currentHunger + " -> " + newHunger)
EndFunction

; =============================================================================
; COLD CALCULATION
; =============================================================================

Float Function CalculateColdChange(Actor akFollower, Float hoursPassed)
    {Calculate how much cold changes based on environment}

    ; Use native cold exposure calculation if available (much faster)
    If NativeAvailable
        Return CalculateColdChangeNative(akFollower, hoursPassed)
    EndIf

    ; Fallback to Papyrus implementation
    Return CalculateColdChangePapyrus(akFollower, hoursPassed)
EndFunction

Float Function CalculateColdChangeNative(Actor akFollower, Float hoursPassed)
    {Calculate cold change using native SKSE functions}

    ; Check if in warm interior (native check includes heat source detection)
    If SeverActionsNative.Survival_IsInWarmInterior(akFollower)
        Return -10.0 * hoursPassed ; Warm up quickly indoors
    EndIf

    ; Check if near a heat source
    If SeverActionsNative.Survival_IsNearHeatSource(akFollower, 512.0)
        Return -10.0 * hoursPassed ; Warm up near fire
    EndIf

    ; Get cold exposure factor (0.0 to 1.0)
    Float exposure = SeverActionsNative.Survival_CalculateColdExposure(akFollower)

    ; If no exposure (warm environment), warm up slowly
    If exposure <= 0.0
        Return -5.0 * hoursPassed
    EndIf

    ; Calculate cold increase based on exposure
    ; exposure of 1.0 = double cold rate, 0.5 = 1.5x cold rate
    Float coldMultiplier = 1.0 + exposure

    Return BASE_COLD_PER_HOUR * hoursPassed * ColdRate * coldMultiplier
EndFunction

Float Function CalculateColdChangePapyrus(Actor akFollower, Float hoursPassed)
    {Calculate cold change using Papyrus (fallback when native unavailable)}

    ; Check if in warm location (interior, near fire, etc.)
    If IsInWarmLocation(akFollower)
        ; Warm up - reduce cold
        Return -10.0 * hoursPassed ; Warm up fairly quickly
    EndIf

    ; Check weather
    Weather currentWeather = Weather.GetCurrentWeather()
    Float coldMultiplier = 1.0

    If currentWeather
        ; Check weather flags for cold/snow
        Int weatherClass = currentWeather.GetClassification()
        ; 0=Pleasant, 1=Cloudy, 2=Rainy, 3=Snow
        If weatherClass == 3 ; Snow
            coldMultiplier = 2.0
        ElseIf weatherClass == 2 ; Rain
            coldMultiplier = 1.5
        EndIf
    EndIf

    ; Check if exterior
    If akFollower.IsInInterior()
        ; Interiors are generally warmer (unless specifically cold)
        coldMultiplier = coldMultiplier * 0.3
    EndIf

    ; Check region (could expand this with specific cold regions)
    ; For now, just use basic calculation

    Return BASE_COLD_PER_HOUR * hoursPassed * ColdRate * coldMultiplier
EndFunction

Bool Function IsInWarmLocation(Actor akFollower)
    {Check if follower is in a warm location}

    ; Use native function if available
    If NativeAvailable
        If SeverActionsNative.Survival_IsInWarmInterior(akFollower)
            Return true
        EndIf
        If SeverActionsNative.Survival_IsNearHeatSource(akFollower, 512.0)
            Return true
        EndIf
        Return false
    EndIf

    ; Fallback to Papyrus
    ; Check interior
    If akFollower.IsInInterior()
        ; Most interiors are warm - could refine with location keywords
        Return true
    EndIf

    ; Check for nearby campfire/heat source
    If IsNearCampfire(akFollower)
        Return true
    EndIf

    Return false
EndFunction

Bool Function IsNearCampfire(Actor akFollower)
    {Check if follower is near a campfire or heat source}

    ; Use native function if available (much faster - single pass with keyword check)
    If NativeAvailable
        Return SeverActionsNative.Survival_IsNearCampfire(akFollower, 512.0)
    EndIf

    ; Fallback to Papyrus implementation
    Return IsNearCampfirePapyrus(akFollower)
EndFunction

Bool Function IsNearCampfirePapyrus(Actor akFollower)
    {Check if follower is near a campfire (Papyrus fallback)}

    ; Search radius for campfires (512 units is roughly 7-8 feet in-game)
    Float searchRadius = 512.0

    ; Look for fire-related objects by checking for lit fires in the cell
    ; We'll search for common fire base objects and light sources
    Cell currentCell = akFollower.GetParentCell()
    If !currentCell
        Return false
    EndIf

    ; Search for static fires and activators (campfires, hearths, forges)
    Int numRefs = currentCell.GetNumRefs(31) ; 31 = kActivator
    Int i = 0
    While i < numRefs
        ObjectReference ref = currentCell.GetNthRef(i, 31)
        If ref && ref.GetDistance(akFollower) <= searchRadius
            ; Check if this is a fire-type object by name (common fire objects)
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

    ; Also check for furniture (cooking pots, etc.)
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

; =============================================================================
; STAT PENALTIES
; =============================================================================

; StorageUtil keys for tracking penalties
String Property PENALTY_SPEED_KEY = "SeverActions_Penalty_Speed" AutoReadOnly
String Property PENALTY_STAMINA_REGEN_KEY = "SeverActions_Penalty_StaminaRegen" AutoReadOnly
String Property PENALTY_MAGICKA_REGEN_KEY = "SeverActions_Penalty_MagickaRegen" AutoReadOnly
String Property PENALTY_HEALTH_REGEN_KEY = "SeverActions_Penalty_HealthRegen" AutoReadOnly

; Per-follower exclusion key (1 = excluded from survival tracking)
String Property EXCLUSION_KEY = "SeverActions_Survival_Excluded" AutoReadOnly

; Regen reduction percentages at each severity level
; These reduce the regen rate actor values (StaminaRate, MagickaRate, HealRate)
; Vanilla regen is typically 100 (100% of base regen), so -50 = half regen, -100 = no regen
Int Property REGEN_PENALTY_MILD = 50 AutoReadOnly      ; 50% reduction
Int Property REGEN_PENALTY_MODERATE = 75 AutoReadOnly  ; 75% reduction
Int Property REGEN_PENALTY_SEVERE = 100 AutoReadOnly   ; 100% reduction (no regen)

; Stamina drain per game hour at each hunger level
Float Property HUNGER_STAMINA_DRAIN_MILD = 10.0 AutoReadOnly      ; Peckish: 10 stamina/hour
Float Property HUNGER_STAMINA_DRAIN_MODERATE = 25.0 AutoReadOnly  ; Hungry: 25 stamina/hour
Float Property HUNGER_STAMINA_DRAIN_SEVERE = 50.0 AutoReadOnly    ; Ravenous: 50 stamina/hour

; Magicka drain per game hour at each fatigue level
Float Property FATIGUE_MAGICKA_DRAIN_MILD = 10.0 AutoReadOnly     ; Tired: 10 magicka/hour
Float Property FATIGUE_MAGICKA_DRAIN_MODERATE = 25.0 AutoReadOnly ; Drained: 25 magicka/hour
Float Property FATIGUE_MAGICKA_DRAIN_SEVERE = 50.0 AutoReadOnly   ; Exhausted: 50 magicka/hour

; Cold damage per game hour at each severity level
Float Property COLD_DAMAGE_MILD = 5.0 AutoReadOnly      ; Chilly: 5 health/hour
Float Property COLD_DAMAGE_MODERATE = 15.0 AutoReadOnly ; Cold: 15 health/hour
Float Property COLD_DAMAGE_SEVERE = 30.0 AutoReadOnly   ; Freezing: 30 health/hour

Function ApplyStatPenalties(Actor akFollower, Int hunger, Int fatigue, Int cold)
    {Apply penalties based on survival levels - speed, regen reduction}

    ; Safety check: if follower is in bleedout, clear penalties and help them recover
    If akFollower.IsBleedingOut()
        If DebugMode
            Debug.Trace("[SeverActions_Survival] " + akFollower.GetDisplayName() + " is in bleedout! Clearing penalties and restoring health.")
        EndIf
        ClearAllPenalties(akFollower)
        akFollower.RestoreActorValue("Health", 50.0)
        Return
    EndIf

    ; Apply speed penalty from cold
    ApplyColdSpeedPenalty(akFollower, cold)

    ; Apply regen penalties based on survival levels
    ApplyStaminaRegenPenalty(akFollower, hunger)  ; Hunger reduces stamina regen
    ApplyMagickaRegenPenalty(akFollower, fatigue) ; Fatigue reduces magicka regen
    ApplyHealthRegenPenalty(akFollower, cold)     ; Cold reduces health regen
EndFunction

Function ClearAllPenalties(Actor akFollower)
    {Clear all survival penalties from a follower}
    ClearSpeedPenalty(akFollower)
    ClearStaminaRegenPenalty(akFollower)
    ClearMagickaRegenPenalty(akFollower)
    ClearHealthRegenPenalty(akFollower)
EndFunction

Function ApplyColdSpeedPenalty(Actor akFollower, Int cold)
    {Apply speed penalties based on cold level}

    ; Get what we previously applied
    Int prevSpeedPenalty = StorageUtil.GetIntValue(akFollower, PENALTY_SPEED_KEY, 0)

    ; Calculate what the new speed penalty should be
    Int newSpeedPenalty = 0

    Int level = GetSeverityLevel(cold)

    If level >= LEVEL_SEVERE
        ; Freezing: significant movement slow
        newSpeedPenalty = 30
    ElseIf level >= LEVEL_MODERATE
        ; Cold: slight slow
        newSpeedPenalty = 15
    EndIf
    ; Mild (Chilly) has no speed penalty

    ; Only modify if the penalty changed
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

    ; No drain if not hungry
    If level < LEVEL_MILD
        Return
    EndIf

    ; Calculate drain based on severity
    Float drainPerHour = 0.0
    If level >= LEVEL_SEVERE
        drainPerHour = HUNGER_STAMINA_DRAIN_SEVERE
    ElseIf level >= LEVEL_MODERATE
        drainPerHour = HUNGER_STAMINA_DRAIN_MODERATE
    ElseIf level >= LEVEL_MILD
        drainPerHour = HUNGER_STAMINA_DRAIN_MILD
    EndIf

    ; Calculate actual drain for this update period
    Float drain = drainPerHour * hoursPassed * HungerRate

    ; Don't drain below 10% stamina
    Float currentStamina = akFollower.GetActorValue("Stamina")
    Float minStamina = akFollower.GetBaseActorValue("Stamina") * 0.1

    If (currentStamina - drain) < minStamina
        drain = currentStamina - minStamina
        If drain < 0.0
            drain = 0.0
        EndIf
    EndIf

    ; Apply the drain
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

    ; No drain if not tired
    If level < LEVEL_MILD
        Return
    EndIf

    ; Calculate drain based on severity
    Float drainPerHour = 0.0
    If level >= LEVEL_SEVERE
        drainPerHour = FATIGUE_MAGICKA_DRAIN_SEVERE
    ElseIf level >= LEVEL_MODERATE
        drainPerHour = FATIGUE_MAGICKA_DRAIN_MODERATE
    ElseIf level >= LEVEL_MILD
        drainPerHour = FATIGUE_MAGICKA_DRAIN_MILD
    EndIf

    ; Calculate actual drain for this update period
    Float drain = drainPerHour * hoursPassed * FatigueRate

    ; Don't drain below 10% magicka
    Float currentMagicka = akFollower.GetActorValue("Magicka")
    Float minMagicka = akFollower.GetBaseActorValue("Magicka") * 0.1

    If (currentMagicka - drain) < minMagicka
        drain = currentMagicka - minMagicka
        If drain < 0.0
            drain = 0.0
        EndIf
    EndIf

    ; Apply the drain
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

    ; No damage if not cold
    If level < LEVEL_MILD
        Return
    EndIf

    ; Calculate damage based on severity
    Float damagePerHour = 0.0
    If level >= LEVEL_SEVERE
        damagePerHour = COLD_DAMAGE_SEVERE
    ElseIf level >= LEVEL_MODERATE
        damagePerHour = COLD_DAMAGE_MODERATE
    ElseIf level >= LEVEL_MILD
        damagePerHour = COLD_DAMAGE_MILD
    EndIf

    ; Calculate actual damage for this update period
    Float damage = damagePerHour * hoursPassed * ColdRate

    ; Don't kill them - leave at least 10% health
    Float currentHealth = akFollower.GetActorValue("Health")
    Float minHealth = akFollower.GetBaseActorValue("Health") * 0.1

    If (currentHealth - damage) < minHealth
        damage = currentHealth - minHealth
        If damage < 0.0
            damage = 0.0
        EndIf
    EndIf

    ; Apply the damage
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

; =============================================================================
; REGEN PENALTIES
; =============================================================================

Function ApplyStaminaRegenPenalty(Actor akFollower, Int hunger)
    {Apply stamina regen penalty based on hunger level}
    Int prevPenalty = StorageUtil.GetIntValue(akFollower, PENALTY_STAMINA_REGEN_KEY, 0)
    Int newPenalty = GetRegenPenaltyForLevel(hunger)

    If newPenalty != prevPenalty
        ; Restore previous penalty
        If prevPenalty > 0
            akFollower.ModAV("StaminaRate", prevPenalty)
        EndIf
        ; Apply new penalty
        If newPenalty > 0
            akFollower.ModAV("StaminaRate", -newPenalty)
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
        akFollower.ModAV("StaminaRate", penalty)
        StorageUtil.SetIntValue(akFollower, PENALTY_STAMINA_REGEN_KEY, 0)
    EndIf
EndFunction

Function ApplyMagickaRegenPenalty(Actor akFollower, Int fatigue)
    {Apply magicka regen penalty based on fatigue level}
    Int prevPenalty = StorageUtil.GetIntValue(akFollower, PENALTY_MAGICKA_REGEN_KEY, 0)
    Int newPenalty = GetRegenPenaltyForLevel(fatigue)

    If newPenalty != prevPenalty
        ; Restore previous penalty
        If prevPenalty > 0
            akFollower.ModAV("MagickaRate", prevPenalty)
        EndIf
        ; Apply new penalty
        If newPenalty > 0
            akFollower.ModAV("MagickaRate", -newPenalty)
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
        akFollower.ModAV("MagickaRate", penalty)
        StorageUtil.SetIntValue(akFollower, PENALTY_MAGICKA_REGEN_KEY, 0)
    EndIf
EndFunction

Function ApplyHealthRegenPenalty(Actor akFollower, Int cold)
    {Apply health regen penalty based on cold level}
    Int prevPenalty = StorageUtil.GetIntValue(akFollower, PENALTY_HEALTH_REGEN_KEY, 0)
    Int newPenalty = GetRegenPenaltyForLevel(cold)

    If newPenalty != prevPenalty
        ; Restore previous penalty
        If prevPenalty > 0
            akFollower.ModAV("HealRate", prevPenalty)
        EndIf
        ; Apply new penalty
        If newPenalty > 0
            akFollower.ModAV("HealRate", -newPenalty)
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
        akFollower.ModAV("HealRate", penalty)
        StorageUtil.SetIntValue(akFollower, PENALTY_HEALTH_REGEN_KEY, 0)
    EndIf
EndFunction

Int Function GetRegenPenaltyForLevel(Int survivalValue)
    {Calculate regen penalty based on survival level (hunger/fatigue/cold)}
    Int level = GetSeverityLevel(survivalValue)

    If level >= LEVEL_SEVERE
        Return REGEN_PENALTY_SEVERE   ; 100% reduction - no regen
    ElseIf level >= LEVEL_MODERATE
        Return REGEN_PENALTY_MODERATE ; 50% reduction
    ElseIf level >= LEVEL_MILD
        Return REGEN_PENALTY_MILD     ; 25% reduction
    Else
        Return 0  ; No penalty
    EndIf
EndFunction

; =============================================================================
; NOTIFICATIONS
; =============================================================================

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

; =============================================================================
; FOLLOWER DETECTION
; =============================================================================

Actor[] Function GetCurrentFollowers()
    {Get array of current player followers}

    ; Use native function if available (much faster)
    If NativeAvailable
        Return SeverActionsNative.Survival_GetCurrentFollowers()
    EndIf

    ; Fallback to Papyrus implementation
    Return GetCurrentFollowersPapyrus()
EndFunction

Actor[] Function GetCurrentFollowersPapyrus()
    {Get current followers using Papyrus (fallback)}

    ; Use IsPlayerTeammate() which works with all follower frameworks (vanilla, NFF, AFT, etc.)
    ; This is more reliable than checking CurrentFollowerFaction which modded frameworks may not use

    Actor player = Game.GetPlayer()
    Actor[] result = PapyrusUtil.ActorArray(0)

    ; Search player's cell for NPCs that are player teammates
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

; =============================================================================
; STORAGE UTIL WRAPPERS
; =============================================================================

Int Function GetFollowerHunger(Actor akFollower)
    Return StorageUtil.GetIntValue(akFollower, "SeverActions_Survival_Hunger", 0)
EndFunction

Function SetFollowerHunger(Actor akFollower, Int value)
    StorageUtil.SetIntValue(akFollower, "SeverActions_Survival_Hunger", value)
EndFunction

Int Function GetFollowerFatigue(Actor akFollower)
    Return StorageUtil.GetIntValue(akFollower, "SeverActions_Survival_Fatigue", 0)
EndFunction

Function SetFollowerFatigue(Actor akFollower, Int value)
    StorageUtil.SetIntValue(akFollower, "SeverActions_Survival_Fatigue", value)
EndFunction

Int Function GetFollowerCold(Actor akFollower)
    Return StorageUtil.GetIntValue(akFollower, "SeverActions_Survival_Cold", 0)
EndFunction

Function SetFollowerCold(Actor akFollower, Int value)
    StorageUtil.SetIntValue(akFollower, "SeverActions_Survival_Cold", value)
EndFunction

; =============================================================================
; UTILITY FUNCTIONS
; =============================================================================

Int Function GetSeverityLevel(Int value)
    {Convert 0-100 value to severity level threshold}
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

; =============================================================================
; PUBLIC API - For prompts and external access
; =============================================================================

String Function GetFollowerSurvivalStatus(Actor akFollower)
    {Get a formatted string of follower's survival status for prompts}

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

; =============================================================================
; PER-FOLLOWER EXCLUSION
; =============================================================================

Bool Function IsFollowerExcluded(Actor akFollower)
    {Check if a follower is excluded from survival tracking}
    If !akFollower
        Return true
    EndIf
    Return StorageUtil.GetIntValue(akFollower, EXCLUSION_KEY, 0) == 1
EndFunction

Function SetFollowerExcluded(Actor akFollower, Bool excluded)
    {Set whether a follower is excluded from survival tracking}
    If !akFollower
        Return
    EndIf

    If excluded
        ; Clear any existing penalties and survival data before excluding
        ClearAllPenalties(akFollower)
        SetFollowerHunger(akFollower, 0)
        SetFollowerFatigue(akFollower, 0)
        SetFollowerCold(akFollower, 0)
        StorageUtil.SetIntValue(akFollower, EXCLUSION_KEY, 1)
        If DebugMode
            Debug.Trace("[SeverActions_Survival] " + akFollower.GetDisplayName() + " excluded from survival tracking")
        EndIf
    Else
        StorageUtil.SetIntValue(akFollower, EXCLUSION_KEY, 0)
        If DebugMode
            Debug.Trace("[SeverActions_Survival] " + akFollower.GetDisplayName() + " included in survival tracking")
        EndIf
    EndIf
EndFunction

Function ToggleFollowerExcluded(Actor akFollower)
    {Toggle a follower's exclusion from survival tracking}
    SetFollowerExcluded(akFollower, !IsFollowerExcluded(akFollower))
EndFunction

Function OnFollowerAteFood(Actor akFollower, Form akFood = None)
    {Call this when a follower eats food through external means (UseItem action, etc.)
     This will reduce their hunger level.
     akFood is optional - if provided, we determine restore amount based on food type}

    If !Enabled || !HungerEnabled
        Return
    EndIf

    If !akFollower
        Return
    EndIf

    ; Determine hunger restore amount
    Int hungerRestore = HUNGER_COOKED_MEAL ; Default to cooked meal value

    If akFood
        ; Check if it's a beverage first (ales, meads, wines) — less hunger than real food
        If IsBeverage(akFood)
            hungerRestore = HUNGER_BEVERAGE
        Else
            Potion foodItem = akFood as Potion
            If foodItem
                ; Check if raw food (restores less)
                If VendorItemFoodRaw && foodItem.HasKeyword(VendorItemFoodRaw)
                    hungerRestore = HUNGER_RAW_FOOD
                ElseIf VendorItemFood && foodItem.HasKeyword(VendorItemFood)
                    hungerRestore = HUNGER_COOKED_MEAL
                Else
                    ; Ingredient or unknown food type
                    hungerRestore = HUNGER_INGREDIENT
                EndIf
            EndIf
        EndIf
    EndIf

    ; Reduce hunger
    Int currentHunger = GetFollowerHunger(akFollower)
    Int newHunger = ClampInt(currentHunger - hungerRestore, 0, 100)
    SetFollowerHunger(akFollower, newHunger)

    ; Stamina recovers naturally, no penalties to update
    ; (we no longer reduce max stamina, just drain it over time)

    If DebugMode
        String foodName = "food"
        If akFood
            foodName = akFood.GetName()
        EndIf
        Debug.Trace("[SeverActions_Survival] OnFollowerAteFood: " + akFollower.GetDisplayName() + " ate " + foodName + ", hunger: " + currentHunger + " -> " + newHunger + " (restored " + hungerRestore + ")")
    EndIf
EndFunction

Function OnFollowerDrank(Actor akFollower, Form akPotion = None)
    {Call this when a follower drinks a regular potion (health, stamina, magicka, etc.)
     Beverages (ales, meads) go through OnFollowerAteFood since they're flagged as food.
     Regular potions sate hunger slightly — liquid is liquid.}

    If !Enabled || !HungerEnabled
        Return
    EndIf

    If !akFollower
        Return
    EndIf

    Int hungerRestore = HUNGER_POTION

    ; Reduce hunger
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
    {Check if a food item is a beverage (ale, wine, mead, milk, etc.)
     Uses name-based detection since vanilla Skyrim has no beverage keyword.
     Items must also be IsFood() — regular potions are handled separately.}
    If !akItem
        Return false
    EndIf

    Potion potionForm = akItem as Potion
    If !potionForm || !potionForm.IsFood()
        Return false
    EndIf

    String itemName = SeverActionsNative.StringToLower(akItem.GetName())

    ; Common Skyrim beverages
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

    ; Clear speed penalties from all currently tracked followers
    ; Note: Stamina/Magicka/Health drain recovers naturally, no need to restore
    Actor[] followers = GetCurrentFollowers()
    Int i = 0
    While i < followers.Length
        Actor follower = followers[i]
        If follower
            ClearAllPenalties(follower)
        EndIf
        i += 1
    EndWhile

    ; Stop the update loop
    UnregisterForUpdate()
    Enabled = false

    If DebugMode
        Debug.Trace("[SeverActions_Survival] Tracking stopped, penalties cleared")
    EndIf
EndFunction

Function DebugMsg(String msg)
    {Log debug message if debug mode is enabled}
    If DebugMode
        Debug.Trace("[SeverActions_Survival] " + msg)
    EndIf
EndFunction
