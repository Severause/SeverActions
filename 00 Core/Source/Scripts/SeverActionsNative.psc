Scriptname SeverActionsNative Hidden
{Native SKSE plugin for SeverActions - high-performance utility functions
Replace slow Papyrus string operations, database lookups, and searches with native C++ implementations.

Performance improvements:
- String operations: 2000-10000x faster
- Database lookups: 500x faster
- Inventory searches: 100-200x faster
- Nearby object searches: 10+ calls reduced to 1

Author: Severause}

; =============================================================================
; PLUGIN INFO
; =============================================================================

String Function GetPluginVersion() Global Native
{Get the version string of the native plugin}

; =============================================================================
; STRING UTILITIES
; Replaces character-by-character Papyrus loops with native C++ implementations
; =============================================================================

String Function StringToLower(String text) Global Native
{Convert string to lowercase - ~2000-5000x faster than Papyrus loop}

Int Function HexToInt(String hexString) Global Native
{Parse hex string to integer - supports "0x12EB7" or "12EB7" format - ~10000x faster}

String Function TrimString(String text) Global Native
{Trim whitespace from both ends of string - much faster than Papyrus loop}

String Function EscapeJsonString(String text) Global Native
{Escape special characters for JSON - handles quotes, backslashes, control chars}

Bool Function StringContains(String haystack, String needle) Global Native
{Case-insensitive substring search - faster than StringUtil.Find + ToLower}

Bool Function StringEquals(String a, String b) Global Native
{Case-insensitive string equality check}

; =============================================================================
; CRAFTING DATABASE
; Fast item lookup replacing JContainers iteration
; =============================================================================

Bool Function LoadCraftingDatabase(String folderPath) Global Native
{Load all JSON crafting database files from a folder
Example: LoadCraftingDatabase("Data/SKSE/Plugins/SeverActions/CraftingDB/")}

Form Function FindCraftableByName(String itemName) Global Native
{Find craftable item by exact name (case-insensitive) - O(1) lookup}

Form Function FuzzySearchCraftable(String searchTerm) Global Native
{Find craftable item by partial name match - much faster than Papyrus iteration}

Form Function SearchCraftableCategory(String category, String searchTerm) Global Native
{Search within a specific category ("weapons", "armor", "misc")}

String Function GetCraftingDatabaseStats() Global Native
{Get database statistics string (weapon/armor/misc counts)}

Bool Function IsCraftingDatabaseLoaded() Global Native
{Check if crafting database has been loaded}

; =============================================================================
; TRAVEL DATABASE
; Fast location lookup replacing JContainers iteration
; =============================================================================

Bool Function LoadTravelDatabase(String filePath) Global Native
{Load travel markers from JSON file
Example: LoadTravelDatabase("Data/SKSE/Plugins/SeverActions/TravelDB/TravelMarkersVanilla.json")}

String Function FindCellId(String placeName) Global Native
{Find cell editor ID by place name - handles aliases like "whiterun" -> "WhiterunBanneredMare"
Returns empty string if not found - O(1) lookup}

ObjectReference Function GetMarkerForCell(String cellId) Global Native
{Get the XMarker reference for a cell ID}

ObjectReference Function ResolvePlace(String placeName) Global Native
{Resolve place name directly to marker reference - combines FindCellId + GetMarkerForCell}

Bool Function IsTravelDatabaseLoaded() Global Native
{Check if travel database has been loaded}

Int Function GetTravelMarkerCount() Global Native
{Get number of travel markers loaded}

; =============================================================================
; INVENTORY UTILITIES
; Fast inventory searching replacing GetNthForm loops
; =============================================================================

Form Function FindItemByName(Actor akActor, String itemName) Global Native
{Find item in actor's inventory by name (case-insensitive partial match)
Returns None if not found - much faster than Papyrus GetNthForm loop}

Form Function FindItemInContainer(ObjectReference akContainer, String itemName) Global Native
{Find item in container by name}

Bool Function ActorHasItemByName(Actor akActor, String itemName) Global Native
{Check if actor has item by name - faster than FindItemByName != None}

Int Function GetFormGoldValue(Form akForm) Global Native
{Get gold value of any form - replaces type-checking cascade in Papyrus}

Int Function GetInventoryItemCount(ObjectReference akContainer) Global Native
{Get count of unique item types in container}

Bool Function IsConsumable(Form akForm) Global Native
{Check if form is consumable (potion, food, ingredient)}

Bool Function IsFood(Form akForm) Global Native
{Check if form is specifically food}

Bool Function IsPoison(Form akForm) Global Native
{Check if form is a poison}

; =============================================================================
; NEARBY SEARCH
; Single-pass searching replacing multiple PO3_SKSEFunctions calls
; =============================================================================

ObjectReference Function FindNearbyItemOfType(Actor akActor, String itemType, Float radius = 1000.0) Global Native
{Find nearest pickupable item matching type name
Replaces 10+ sequential CheckFormType calls with single pass
Returns closest match or None}

ObjectReference Function FindNearbyContainer(Actor akActor, String containerType, Float radius = 1000.0) Global Native
{Find nearest container matching type name
Use "" or "any" for any container with items}

ObjectReference Function FindNearbyForge(Actor akActor, Float radius = 2000.0) Global Native
{Find nearest forge/smithing station}

ObjectReference Function FindNearbyCookingPot(Actor akActor, Float radius = 2000.0) Global Native
{Find nearest cooking pot/spit}

ObjectReference Function FindNearbyAlchemyLab(Actor akActor, Float radius = 2000.0) Global Native
{Find nearest alchemy lab/workbench}

String Function GetDirectionString(Actor akActor, ObjectReference akTarget) Global Native
{Get direction string ("ahead", "to the right", "to the left", "behind")
Replaces Papyrus heading angle calculation}

; =============================================================================
; FURNITURE MANAGER
; Native furniture package management - no Papyrus polling required
; Auto-removes packages when player changes cells or moves away
; =============================================================================

Bool Function RegisterFurnitureUser(Actor akActor, Package akPackage, ObjectReference akFurniture, Keyword akLinkedRefKeyword, Float autoStandDistance = 500.0) Global Native
{Register an actor as using furniture with automatic cleanup.
When player moves > autoStandDistance units away, or changes cells,
the package is automatically removed and the actor stands up.
akLinkedRefKeyword: The keyword used for SetLinkedRef (can be None)
Returns true if successfully registered.}

Function UnregisterFurnitureUser(Actor akActor) Global Native
{Unregister an actor from furniture management.
Call this when they stand up normally via StopUsingFurniture.}

Function ForceAllFurnitureUsersStandUp() Global Native
{Force all registered furniture users to stand up immediately.
Useful for cleanup on cell change or mod reset.}

Bool Function IsFurnitureUserRegistered(Actor akActor) Global Native
{Check if an actor is registered with the furniture manager.}

Float Function GetDefaultAutoStandDistance() Global Native
{Get the default auto-stand distance for new registrations.}

Function SetDefaultAutoStandDistance(Float distance) Global Native
{Set the default auto-stand distance for new registrations.
Default is 500 units.}

Int Function GetFurnitureUserCount() Global Native
{Get the number of actors currently registered with the furniture manager.}

; =============================================================================
; SANDBOX MANAGER
; Native sandbox package management - separate from FurnitureManager
; Auto-removes sandbox packages when player changes cells or moves away
; =============================================================================

Bool Function RegisterSandboxUser(Actor akActor, Package akPackage, Float autoStandDistance = 2000.0) Global Native
{Register an actor as sandboxing with automatic cleanup.
When player moves > autoStandDistance units away, or changes cells,
the SeverActionsNative_SandboxCleanup mod event is sent.
Returns true if successfully registered.}

Function UnregisterSandboxUser(Actor akActor) Global Native
{Unregister an actor from sandbox management.
Call this when sandbox is stopped normally via StopSandbox.}

Function ForceAllSandboxUsersStop() Global Native
{Force all registered sandbox users to stop immediately.
Useful for cleanup on cell change or mod reset.}

Bool Function IsSandboxUserRegistered(Actor akActor) Global Native
{Check if an actor is registered with the sandbox manager.}

Int Function GetSandboxUserCount() Global Native
{Get the number of actors currently registered with the sandbox manager.}

; =============================================================================
; DIALOGUE ANIMATION MANAGER
; Plays conversation idle animations on actors using SkyrimNet dialogue packages
; =============================================================================

Function SetDialogueAnimEnabled(Bool enabled) Global Native
{Enable or disable dialogue conversation animations.
When enabled, actors in SkyrimNet's TalkToPlayer/TalkToNPC packages will
play natural conversation idle animations (gestures, nods, etc).}

Bool Function IsDialogueAnimEnabled() Global Native
{Check if the dialogue animation system is currently enabled.}

; =============================================================================
; CRIME UTILITIES
; Access crime faction data not exposed to Papyrus
; =============================================================================

ObjectReference Function GetFactionJailMarker(Faction akFaction) Global Native
{Get the jail marker (interior) for a crime faction.
This is where prisoners are sent when arrested.
Returns None if faction is null or has no jail marker set.}

ObjectReference Function GetFactionWaitMarker(Faction akFaction) Global Native
{Get the exterior jail marker (wait marker) for a crime faction.
This is where the player/NPCs appear after serving time.
Returns None if faction is null or has no wait marker set.}

ObjectReference Function GetFactionStolenGoodsContainer(Faction akFaction) Global Native
{Get the stolen goods container for a crime faction.
Returns None if faction is null or has no container set.}

ObjectReference Function GetFactionPlayerInventoryContainer(Faction akFaction) Global Native
{Get the player inventory container for a crime faction.
Returns None if faction is null or has no container set.}

Outfit Function GetFactionJailOutfit(Faction akFaction) Global Native
{Get the jail outfit for a crime faction.
Returns None if faction is null or has no outfit set.}

; =============================================================================
; RECIPE DATABASE
; Native database built from scanning all COBJ records at game load
; Provides fast lookup for smithing, cooking, smelting, and tanning recipes
; =============================================================================

Bool Function IsRecipeDBLoaded() Global Native
{Check if the recipe database has been initialized}

Form Function FindSmithingRecipe(String itemName) Global Native
{Find a smithing recipe by item name (fuzzy search)
Returns the created item Form, or None if not found}

Form Function FindCookingRecipe(String itemName) Global Native
{Find a cooking recipe by item name (fuzzy search)
Returns the created item Form, or None if not found}

Form Function FindSmeltingRecipe(String itemName) Global Native
{Find a smelting recipe by item name (fuzzy search)
Returns the created item Form, or None if not found}

String Function GetRecipeDBStats() Global Native
{Get statistics about loaded recipes (counts by category)}

; =============================================================================
; ALCHEMY DATABASE
; Native database built from scanning all AlchemyItem records at game load
; Provides fast lookup for potions, poisons, foods, and ingredients
; =============================================================================

Bool Function IsAlchemyDBLoaded() Global Native
{Check if the alchemy database has been initialized}

Potion Function FindPotion(String potionName) Global Native
{Find a potion by name (fuzzy search)
Returns the Potion, or None if not found}

Potion Function FindPoison(String poisonName) Global Native
{Find a poison by name (fuzzy search)
Returns the Potion, or None if not found}

Potion Function FindPotionByEffect(String effectName) Global Native
{Find a potion that has a specific effect (e.g., "restore health")
Returns the Potion, or None if not found}

Potion Function FindPoisonByEffect(String effectName) Global Native
{Find a poison that has a specific effect (e.g., "damage health")
Returns the Potion, or None if not found}

String Function GetAlchemyDBStats() Global Native
{Get statistics about loaded alchemy items (counts by category)}

; =============================================================================
; SURVIVAL UTILITIES
; Native functions for Follower Survival System integration
; Provides food consumption detection, weather/cold calculation, heat source detection
; =============================================================================

; --- Follower Tracking ---

Bool Function Survival_StartTracking(Actor akActor) Global Native
{Start tracking an actor for survival stats. Returns true if successful.}

Function Survival_StopTracking(Actor akActor) Global Native
{Stop tracking an actor for survival stats.}

Bool Function Survival_IsTracked(Actor akActor) Global Native
{Check if an actor is being tracked for survival.}

Int Function Survival_GetTrackedCount() Global Native
{Get the number of actors currently being tracked.}

Actor[] Function Survival_GetTrackedFollowers() Global Native
{Get all currently tracked followers as an array.}

Actor[] Function Survival_GetCurrentFollowers() Global Native
{Get all current followers (in CurrentFollowerFaction) - fast native lookup.}

; --- Food Detection ---

Bool Function Survival_IsFoodItem(Form akForm) Global Native
{Check if a form is a food item (AlchemyItem.IsFood() or Ingredient).}

Int Function Survival_GetFoodRestoreValue(Form akForm) Global Native
{Get estimated hunger restore value for a food item (based on effect magnitude).}

; --- Weather & Cold ---

Float Function Survival_GetWeatherColdFactor() Global Native
{Get current weather cold factor (0.0 = warm/pleasant, 1.0 = freezing/snow).}

Int Function Survival_GetWeatherClassification() Global Native
{Get weather classification: 0=Pleasant, 1=Cloudy, 2=Rainy, 3=Snow}

Bool Function Survival_IsSnowingWeather() Global Native
{Check if current weather is snowing.}

Bool Function Survival_IsInColdRegion(Actor akActor) Global Native
{Check if actor is in a cold region (based on location/worldspace name).}

Float Function Survival_CalculateColdExposure(Actor akActor) Global Native
{Calculate cold exposure factor (0.0-1.0) considering weather, region, interior, heat sources, armor.}

; --- Armor Warmth ---

Float Function Survival_GetArmorWarmthFactor(Actor akActor) Global Native
{Get armor warmth factor (0.0-1.0) based on equipped armor.
0.0 = naked/no protection, 1.0 = fully insulated.
Considers: body slot coverage, warm materials (fur, hide, leather),
cold materials (metal armor provides less warmth), head/hands/feet coverage bonus.}

; --- Heat Source Detection ---

Bool Function Survival_IsNearHeatSource(Actor akActor, Float radius = 512.0) Global Native
{Check if actor is near any heat source (campfire, forge, hearth, etc.).}

Float Function Survival_GetDistanceToNearestHeatSource(Actor akActor, Float maxRadius = 1024.0) Global Native
{Get distance to nearest heat source. Returns -1.0 if none found within radius.}

Bool Function Survival_IsNearCampfire(Actor akActor, Float radius = 512.0) Global Native
{Check if actor is near a campfire or bonfire specifically.}

Bool Function Survival_IsNearForge(Actor akActor, Float radius = 512.0) Global Native
{Check if actor is near a forge or smithing station.}

Bool Function Survival_IsNearHearth(Actor akActor, Float radius = 512.0) Global Native
{Check if actor is near a hearth or fireplace.}

Bool Function Survival_IsInWarmInterior(Actor akActor) Global Native
{Check if actor is in a warm interior (interior cell with heat source).}

; --- Survival Data Storage ---

Float Function Survival_GetLastAteTime(Actor akActor) Global Native
{Get game time (in seconds) when actor last ate.}

Function Survival_SetLastAteTime(Actor akActor, Float gameTime) Global Native
{Set game time (in seconds) when actor last ate.}

Float Function Survival_GetLastSleptTime(Actor akActor) Global Native
{Get game time (in seconds) when actor last slept.}

Function Survival_SetLastSleptTime(Actor akActor, Float gameTime) Global Native
{Set game time (in seconds) when actor last slept.}

Float Function Survival_GetLastWarmedTime(Actor akActor) Global Native
{Get game time (in seconds) when actor last warmed up.}

Function Survival_SetLastWarmedTime(Actor akActor, Float gameTime) Global Native
{Set game time (in seconds) when actor last warmed up.}

Int Function Survival_GetHungerLevel(Actor akActor) Global Native
{Get actor's hunger level (0-100).}

Function Survival_SetHungerLevel(Actor akActor, Int level) Global Native
{Set actor's hunger level (0-100).}

Int Function Survival_GetFatigueLevel(Actor akActor) Global Native
{Get actor's fatigue level (0-100).}

Function Survival_SetFatigueLevel(Actor akActor, Int level) Global Native
{Set actor's fatigue level (0-100).}

Int Function Survival_GetColdLevel(Actor akActor) Global Native
{Get actor's cold level (0-100).}

Function Survival_SetColdLevel(Actor akActor, Int level) Global Native
{Set actor's cold level (0-100).}

Function Survival_ClearActorData(Actor akActor) Global Native
{Clear all survival data for an actor (stops tracking).}

; --- Utility ---

Float Function Survival_GetGameTimeInSeconds() Global Native
{Get current game time in seconds format (GetCurrentGameTime() * 24 * 3631).}

; =============================================================================
; FERTILITY MODE INTEGRATION
; Native caching and decorator functions for Fertility Mode Reloaded
; =============================================================================

; --- Initialization & Status ---

Bool Function FM_Initialize() Global Native
{Initialize the Fertility Mode native module. Returns true if FM is installed and init succeeded.}

Bool Function FM_IsInstalled() Global Native
{Check if Fertility Mode is installed and native module is initialized.}

Function FM_RefreshCache() Global Native
{Refresh cached GlobalVariable values from Fertility Mode.}

; --- Cache Management (called from Papyrus bridge) ---

Function FM_SetActorData(Actor akActor, Float lastConception, Float lastBirth, Float babyAdded, Float lastOvulation, Float lastGameHours, Int lastGameHoursDelta, String currentFather) Global Native
{Push actor fertility data into native cache for O(1) lookups.}

Function FM_ClearActorData(Actor akActor) Global Native
{Clear cached fertility data for an actor.}

Function FM_ClearAllCache() Global Native
{Clear all cached fertility data.}

Int Function FM_GetCachedActorCount() Global Native
{Get number of actors currently in the native fertility cache.}

; --- Decorator Functions (called by SkyrimNet prompts) ---

String Function FM_GetFertilityState(Actor akActor) Global Native
{Get fertility state: "normal", "menstruating", "ovulating", "fertile", "pms",
"first_trimester", "second_trimester", "third_trimester", "recovery"}

String Function FM_GetFertilityFather(Actor akActor) Global Native
{Get father name if actor is pregnant. Returns empty string if not pregnant.}

String Function FM_GetCycleDay(Actor akActor) Global Native
{Get current cycle day as string. Returns "-1" if not tracked.}

String Function FM_GetPregnantDays(Actor akActor) Global Native
{Get days pregnant as string. Returns "0" if not pregnant.}

String Function FM_GetHasBaby(Actor akActor) Global Native
{Check if actor has a baby. Returns "true" or "false".}

String Function FM_GetFertilityDataBatch(Actor akActor) Global Native
{Get all fertility data in one call. Returns pipe-delimited: "state|father|cycleDay|pregnantDays|hasBaby"}

; =============================================================================
; NSFW UTILITIES
; High-performance JSON builders for SeverActionsNSFW
; Replaces O(n2) Papyrus string concatenation with native C++ string building
; 500-2000x faster than Papyrus equivalents
; =============================================================================

String Function NSFW_ActorsToJson(Actor[] actors) Global Native
{Build JSON array of actor objects from Actor array.
Each actor object has name, sex, and is_player fields.
500-1500x faster than Papyrus loop with string concat.}

String Function NSFW_ActorsToString(Actor[] actors) Global Native
{Build comma-separated string of actor display names.
400-1600x faster than Papyrus loop.}

String Function NSFW_StringArrayToJsonArray(String[] strings) Global Native
{Convert String array to JSON array string.
600-2000x faster than Papyrus loop.}

String Function NSFW_BuildSexEventJson(String eventName, Actor[] actors, String animName, String tagsStr, String styleStr, Int threadId, Int stage, Bool hasPlayer) Global Native
{Build complete SexLab event JSON string with actors, anim, tags, style, etc.
Replaces massive string concatenation in event handlers.
Pass stage=-1 to omit stage field. 750-2000x faster.}

String Function NSFW_BuildOrgasmEventJson(String eventName, String actorName, Actor[] actors, String styleStr, Int threadId, Int numOrgasms, Bool hasPlayer) Global Native
{Build orgasm/ejaculation event JSON with actor name and orgasm count.
750-2000x faster than Papyrus equivalent.}

String Function NSFW_ActorNamesToJsonArray(Actor[] actors) Global Native
{Build JSON array of just actor names.
500-1500x faster than Papyrus loop.}

String Function NSFW_BuildEnjoymentJson(Actor[] actors, Int[] enjoyments) Global Native
{Build JSON object of actor enjoyment values.
Actors and enjoyments are parallel arrays. 500-1500x faster.}

String Function NSFW_JoinStrings(String[] strings, String separator = ", ") Global Native
{Join string array with separator. Much faster than Papyrus loop concatenation.}

String Function NSFW_NaturalNameList(Actor[] actors) Global Native
{Build natural language name list with and.
3 actors: Lydia, Aela, and Farkas. 2 actors: Lydia and Aela.}

String Function NSFW_GetStyleString(Int style) Global Native
{Convert style int to string. 0=forcefully, 1=normally, 2=gently, 3=silently}

; =============================================================================
; NSFW JSON BUILDERS (Phase 2)
; Move expensive per-thread JSON assembly from Papyrus to C++
; These replace O(n) string concatenation loops in Decorators.Get_Threads
; =============================================================================

String Function NSFW_GetInteractionTypeName(Int typeId) Global Native
{Map P+ CTYPE_ constant to human-readable string.
1=vaginal, 2=anal, 3=oral, 4=grinding, 5=deepthroat, 6=skullfuck,
7=licking shaft, 8=footjob, 9=handjob, 10=kissing, 11=facial,
12=anim object face, 13=sucking toes. Called in tight loops.}

String Function NSFW_BuildInteractionsJson(String[] actorNames, String[] partnerNames, Int[] typeIds, Float[] velocities) Global Native
{Build JSON array of P+ interaction objects from parallel arrays.
Replaces nested-loop Papyrus string concat in the interaction builder.}

String Function NSFW_BuildGetThreadsResponse(Bool speakerHavingSex, String speakerName, Bool speakerSpectating, Bool speakerFleeing, String threadsJsonArray, Int counter) Global Native
{Build the complete Get_Threads JSON response envelope.
Wraps the pre-built threads JSON array with speaker metadata fields.}
