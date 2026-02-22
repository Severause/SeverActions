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

Form Function FindWornItemByName(Actor akActor, String itemName) Global Native
{Find a currently worn/equipped item by name (case-insensitive substring match).
Checks all worn armor slots via InventoryChanges.IsWorn() plus equipped weapons.
Returns None if no worn item matches. Much faster than Papyrus slot iteration.}

Int Function EquipItemsByName(Actor akActor, String itemNames) Global Native
{Equip multiple items from inventory by comma-separated name list.
Splits string, searches inventory for each item, equips via ActorEquipManager.
Returns count of items successfully equipped.
Example: EquipItemsByName(actor, "steel gauntlets, iron helmet, glass cuirass")}

Int Function UnequipItemsByName(Actor akActor, String itemNames) Global Native
{Unequip multiple worn items by comma-separated name list.
Splits string, searches worn items for each, unequips via ActorEquipManager.
Returns count of items successfully unequipped.
Example: UnequipItemsByName(actor, "steel gauntlets, iron helmet")}

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

String Function GetDirectionString(Actor akActor, ObjectReference akTarget) Global Native
{Get direction string ("ahead", "to the right", "to the left", "behind")
Replaces Papyrus heading angle calculation}

ObjectReference Function FindSuspiciousItem(Actor akActor, Float radius = 1000.0) Global Native
{Find nearest suspicious item within radius (for crime/investigation)}

Form Function GenerateContextualEvidence(Actor akTargetNPC) Global Native
{Generate contextual evidence form for a target NPC}

Form Function GenerateEvidenceForReason(String reason, Actor akTargetNPC) Global Native
{Generate evidence form for a specific reason targeting an NPC}

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

String Function NSFW_GetInteractionTypeName(Int typeId) Global Native
{Convert interaction type ID to human-readable name string}

String Function NSFW_BuildInteractionsJson(String[] actorNames, String[] partnerNames, Int[] typeIds, Float[] velocities) Global Native
{Build JSON interactions array from parallel arrays of actor data.
actorNames, partnerNames, typeIds, and velocities must be same length.}

String Function NSFW_BuildGetThreadsResponse(Bool speakerHavingSex, String speakerName, Bool speakerSpectating, Bool speakerFleeing, String threadsJsonArray, Int counter) Global Native
{Build complete GetThreads response JSON with speaker status and thread data.}

; =============================================================================
; RECIPE DATABASE
; Native recipe lookup for smithing, cooking, smelting
; =============================================================================

Bool Function IsRecipeDBLoaded() Global Native
{Check if the smithing/cooking recipe database has been loaded}

Form Function FindSmithingRecipe(String itemName) Global Native
{Find a smithing recipe result by item name (case-insensitive)}

Form Function FindCookingRecipe(String itemName) Global Native
{Find a cooking recipe result by item name (case-insensitive)}

Form Function FindSmeltingRecipe(String itemName) Global Native
{Find a smelting recipe result by item name (case-insensitive)}

Bool Function IsOvenRecipe(String itemName) Global Native
{Check if a cooking recipe requires an oven (Hearthfire BYOHCraftingOven) instead of a cooking pot.
Returns true for baked goods like Apple Pie, Crostata, Dumplings, etc.}

String Function GetRecipeDBStats() Global Native
{Get recipe database statistics string (smithing/cooking/smelting counts)}

; =============================================================================
; ALCHEMY DATABASE
; Native potion/poison lookup by name or effect
; =============================================================================

Bool Function IsAlchemyDBLoaded() Global Native
{Check if the alchemy database has been loaded}

Potion Function FindPotion(String itemName) Global Native
{Find a potion by name from the alchemy database}

Potion Function FindPoison(String itemName) Global Native
{Find a poison by name from the alchemy database}

Potion Function FindPotionByEffect(String effectName) Global Native
{Find a potion by magic effect name (case-insensitive)}

Potion Function FindPoisonByEffect(String effectName) Global Native
{Find a poison by magic effect name (case-insensitive)}

String Function GetAlchemyDBStats() Global Native
{Get alchemy database statistics string (potion/poison counts)}

; =============================================================================
; NEARBY SEARCH - Extended
; Additional workstation search functions
; =============================================================================

ObjectReference Function FindNearbyCookingPot(Actor akActor, Float radius = 2000.0) Global Native
{Find nearest cooking pot/spit within radius}

ObjectReference Function FindNearbyOven(Actor akActor, Float radius = 2000.0) Global Native
{Find nearest oven (Hearthfire BYOHCraftingOven) within radius.
Used for baked goods that require an oven instead of a cooking pot.}

ObjectReference Function FindNearbyAlchemyLab(Actor akActor, Float radius = 2000.0) Global Native
{Find nearest alchemy lab within radius}

; =============================================================================
; SANDBOX MANAGER
; Native sandbox package management (similar to furniture manager)
; =============================================================================

Function RegisterSandboxUser(Actor akActor, Package akPackage, Float autoStandDistance = 500.0) Global Native
{Register an actor with a sandbox package for automatic cleanup}

Function UnregisterSandboxUser(Actor akActor) Global Native
{Unregister an actor from sandbox management}

Function ForceAllSandboxUsersStop() Global Native
{Force all registered sandbox users to stop immediately}

Bool Function IsSandboxUserRegistered(Actor akActor) Global Native
{Check if an actor is registered with the sandbox manager}

Int Function GetSandboxUserCount() Global Native
{Get the number of actors currently registered with the sandbox manager}

; =============================================================================
; DIALOGUE ANIMATION
; =============================================================================

Function SetDialogueAnimEnabled(Bool enabled) Global Native
{Enable or disable dialogue animations globally}

Bool Function IsDialogueAnimEnabled() Global Native
{Check if dialogue animations are currently enabled}

; =============================================================================
; SURVIVAL UTILITIES
; Native follower survival tracking, weather, heat sources, and need states
; =============================================================================

; --- Follower Tracking ---

Bool Function Survival_StartTracking(Actor akActor) Global Native
{Begin tracking an actor for survival needs. Returns true if successfully started.}

Function Survival_StopTracking(Actor akActor) Global Native
{Stop tracking an actor for survival needs}

Bool Function Survival_IsTracked(Actor akActor) Global Native
{Check if an actor is currently being tracked for survival}

Int Function Survival_GetTrackedCount() Global Native
{Get the number of actors currently being tracked}

Actor[] Function Survival_GetTrackedFollowers() Global Native
{Get array of all currently tracked followers}

Actor[] Function Survival_GetCurrentFollowers() Global Native
{Get array of current player followers using native detection.
More reliable than Papyrus cell scanning — checks IsPlayerTeammate.}

; --- Food Detection ---

Bool Function Survival_IsFoodItem(Form akForm) Global Native
{Check if a form is a food item}

Int Function Survival_GetFoodRestoreValue(Form akForm) Global Native
{Get the restore value of a food item}

; --- Weather & Cold ---

Float Function Survival_GetWeatherColdFactor() Global Native
{Get the current weather's cold factor (0.0 = warm, 1.0 = freezing)}

Int Function Survival_GetWeatherClassification() Global Native
{Get weather classification (0=clear, 1=cloudy, 2=rain, 3=snow, etc.)}

Bool Function Survival_IsSnowingWeather() Global Native
{Check if it is currently snowing}

Bool Function Survival_IsInColdRegion(Actor akActor) Global Native
{Check if actor is in a cold region (Winterhold, Pale, etc.)}

Float Function Survival_CalculateColdExposure(Actor akActor) Global Native
{Get cold exposure factor (0.0 to 1.0) for actor based on environment}

Float Function Survival_GetArmorWarmthFactor(Actor akActor) Global Native
{Get warmth factor from actor's equipped armor (higher = warmer)}

; --- Heat Sources ---

Bool Function Survival_IsNearHeatSource(Actor akActor, Float radius = 512.0) Global Native
{Check if actor is near a heat source within radius}

Float Function Survival_GetDistanceToNearestHeatSource(Actor akActor, Float maxRadius = 512.0) Global Native
{Get distance to the nearest heat source. Returns maxRadius if none found.}

Bool Function Survival_IsNearCampfire(Actor akActor, Float radius = 512.0) Global Native
{Check if actor is near a campfire within radius}

Bool Function Survival_IsNearForge(Actor akActor, Float radius = 512.0) Global Native
{Check if actor is near a forge within radius}

Bool Function Survival_IsNearHearth(Actor akActor, Float radius = 512.0) Global Native
{Check if actor is near a hearth/fireplace within radius}

Bool Function Survival_IsInWarmInterior(Actor akActor) Global Native
{Check if actor is in a warm interior (includes heat source detection)}

; --- Survival Data Storage (per-actor need states) ---

Float Function Survival_GetLastAteTime(Actor akActor) Global Native
{Get game time when actor last ate}

Function Survival_SetLastAteTime(Actor akActor, Float gameTime) Global Native
{Set game time when actor last ate}

Float Function Survival_GetLastSleptTime(Actor akActor) Global Native
{Get game time when actor last slept}

Function Survival_SetLastSleptTime(Actor akActor, Float gameTime) Global Native
{Set game time when actor last slept}

Float Function Survival_GetLastWarmedTime(Actor akActor) Global Native
{Get game time when actor was last warmed}

Function Survival_SetLastWarmedTime(Actor akActor, Float gameTime) Global Native
{Set game time when actor was last warmed}

Int Function Survival_GetHungerLevel(Actor akActor) Global Native
{Get actor's hunger level (0=full, higher=hungrier)}

Function Survival_SetHungerLevel(Actor akActor, Int level) Global Native
{Set actor's hunger level}

Int Function Survival_GetFatigueLevel(Actor akActor) Global Native
{Get actor's fatigue level (0=rested, higher=more tired)}

Function Survival_SetFatigueLevel(Actor akActor, Int level) Global Native
{Set actor's fatigue level}

Int Function Survival_GetColdLevel(Actor akActor) Global Native
{Get actor's cold level (0=warm, higher=colder)}

Function Survival_SetColdLevel(Actor akActor, Int level) Global Native
{Set actor's cold level}

Function Survival_ClearActorData(Actor akActor) Global Native
{Clear all survival data for an actor}

; --- Utility ---

Float Function Survival_GetGameTimeInSeconds() Global Native
{Get current game time in seconds (faster than Papyrus Utility.GetCurrentGameTime * 86400)}

; =============================================================================
; FERTILITY MODE BRIDGE
; Native integration with Fertility Mode
; =============================================================================

Bool Function FM_Initialize() Global Native
{Initialize the Fertility Mode native bridge. Returns true if FM is available.}

Bool Function FM_IsInstalled() Global Native
{Check if Fertility Mode is installed and available}

Function FM_RefreshCache() Global Native
{Refresh the Fertility Mode cache from current game data}

Function FM_ClearActorData(Actor akActor) Global Native
{Clear cached fertility data for a specific actor}

Function FM_ClearAllCache() Global Native
{Clear all cached fertility data}

Int Function FM_GetCachedActorCount() Global Native
{Get the number of actors with cached fertility data}

Function FM_SetActorData(Actor akActor, Float lastConception, Float lastBirth, Float babyAdded, Float lastOvulation, Float lastGameHours, Int lastGameHoursDelta, String currentFather) Global Native
{Push fertility data to native cache for fast decorator access}

String Function FM_GetFertilityState(Actor akActor) Global Native
{Get fertility state string for actor}

String Function FM_GetFertilityFather(Actor akActor) Global Native
{Get the father name for a pregnant actor}

String Function FM_GetCycleDay(Actor akActor) Global Native
{Get the current cycle day string}

String Function FM_GetPregnantDays(Actor akActor) Global Native
{Get number of days pregnant}

String Function FM_GetHasBaby(Actor akActor) Global Native
{Get whether actor has a baby}

String Function FM_GetFertilityDataBatch(Actor akActor) Global Native
{Get all fertility data in one call (5x faster than individual calls).
Returns pipe-delimited string: state|father|cycleDay|pregnantDays|hasBaby}

; =============================================================================
; DYNAMIC BOOK FRAMEWORK BRIDGE
; Soft dependency — reads DBF config to enable .txt file book content
; When DBF maps a book to a .txt file, GetBookText() returns the file contents
; instead of the book's DESC field. Transparent to all callers.
; =============================================================================

Bool Function IsDBFInstalled() Global Native
{Check if Dynamic Book Framework is detected and active.
Returns false if DBF is not installed — all DBF functions are safe to call regardless.}

Function ReloadDBFMappings() Global Native
{Re-scan Dynamic Book Framework INI configs to pick up new book mappings.
Call after creating new books via DBF's AppendToFile to refresh the mappings.
No-op if DBF is not installed.}

; =============================================================================
; STUCK DETECTOR
; Native actor stuck detection and teleport escalation
; Tracks actor positions over time and detects when they fail to move
; =============================================================================

Function Stuck_StartTracking(Actor akActor) Global Native
{Begin tracking an actor for stuck detection}

Function Stuck_StopTracking(Actor akActor) Global Native
{Stop tracking an actor for stuck detection}

Int Function Stuck_CheckStatus(Actor akActor, Float checkInterval, Float moveThreshold) Global Native
{Check if actor is stuck. Returns escalation level:
0 = not stuck, 1+ = stuck (higher = longer stuck duration).
checkInterval: seconds between checks, moveThreshold: min distance to count as moved.}

Float Function Stuck_GetTeleportDistance(Actor akActor) Global Native
{Get the recommended teleport distance based on escalation level}

Bool Function Stuck_IsTracked(Actor akActor) Global Native
{Check if an actor is currently being tracked for stuck detection}

Function Stuck_ResetEscalation(Actor akActor) Global Native
{Reset the escalation level for an actor (call after successful unstick)}

Function Stuck_ClearAll() Global Native
{Clear all stuck tracking data for all actors}

Int Function Stuck_GetTrackedCount() Global Native
{Get the number of actors currently being tracked for stuck detection}

; =============================================================================
; ACTOR FINDER
; Native NPC lookup by name, location, and position snapshot tracking
; Scans all loaded actors and builds searchable indexes at kDataLoaded
; =============================================================================

Actor Function FindActorByName(String name) Global Native
{Find an actor by display name (case-insensitive partial match).
Uses native index for O(1) lookup. Returns None if not found.}

String Function GetActorLocationName(Actor akActor) Global Native
{Get the display name of the actor's current location/cell}

ObjectReference Function FindActorHome(Actor akActor) Global Native
{Find the actor's home marker (ownership-based lookup)}

String Function GetActorHomeCellName(Actor akActor) Global Native
{Get the display name of the actor's home cell}

Bool Function IsActorFinderReady() Global Native
{Check if the actor finder index has been initialized}

String Function GetActorIndexedCellName(Actor akActor) Global Native
{Get the cell name as stored in the actor finder index}

String Function GetActorFinderStats() Global Native
{Get actor finder statistics string (indexed count, etc.)}

Int Function GetUnmappedNPCCount() Global Native
{Get the number of NPCs that could not be mapped to a location}

Function ActorFinder_ForceRescan() Global Native
{Force a full rescan of all actors (expensive — use sparingly)}

Float[] Function GetActorLastKnownPosition(Actor akActor) Global Native
{Get actor's last known position as [x, y, z] array.
Returns empty array if no snapshot available.}

String Function GetActorWorldspaceName(Actor akActor) Global Native
{Get the name of the worldspace the actor is in}

Bool Function IsActorInExterior(Actor akActor) Global Native
{Check if the actor is in an exterior cell}

Float Function GetActorSnapshotGameTime(Actor akActor) Global Native
{Get the game time when the actor's position snapshot was last updated}

Bool Function HasPositionSnapshot(Actor akActor) Global Native
{Check if a position snapshot exists for this actor}

Float Function GetDistanceBetweenActors(Actor actor1, Actor actor2) Global Native
{Get the 3D distance between two actors using position snapshots}

Int Function GetPositionSnapshotCount() Global Native
{Get the total number of stored position snapshots}

; =============================================================================
; BOOK UTILITIES
; Extract book text content, search actor inventories for books
; Integrates with Dynamic Book Framework for .txt file content
; =============================================================================

String Function GetBookText(Form akForm) Global Native
{Get the full text content of a book form.
Strips HTML tags ([pagebreak], <p>, <br>, <font>, etc.) and normalizes whitespace.
If DBF is installed and maps this book, returns the .txt file contents instead.}

Form Function FindBookInInventory(Actor akActor, String bookName) Global Native
{Find a book in an actor's inventory by name (case-insensitive partial match).
Returns the book Form if found, None otherwise.}

Bool Function HasBooks(Actor akActor) Global Native
{Check if an actor has any books in their inventory}

String Function ListBooks(Actor akActor) Global Native
{Get a comma-separated list of book names in an actor's inventory}

; =============================================================================
; COLLISION UTILITIES
; Control actor bump/collision behavior
; =============================================================================

Function SetActorBumpable(Actor akActor, Bool bumpable) Global Native
{Set whether an actor can be bumped/collided with by other actors.
Use false to prevent NPCs from being pushed around during scenes.}

Bool Function IsActorBumpable(Actor akActor) Global Native
{Check if an actor is currently bumpable/collidable}

; =============================================================================
; LOCATION RESOLVER
; Native location/destination resolution for travel and door finding
; Resolves place names to actual map markers and door references
; =============================================================================

ObjectReference Function ResolveDestination(Actor akActor, String destination) Global Native
{Resolve a destination name to a travel marker reference.
Combines location database lookup with context-aware resolution.
Returns None if destination cannot be resolved.}

String Function GetLocationName(String destination) Global Native
{Get the canonical display name for a destination string}

Bool Function IsLocationResolverReady() Global Native
{Check if the location resolver has been initialized}

Int Function GetLocationCount() Global Native
{Get the number of locations in the resolver database}

String Function GetLocationResolverStats() Global Native
{Get location resolver statistics string}

String Function GetDisambiguatedCellName(Actor akActor) Global Native
{Get a disambiguated cell name for the actor's current location.
Adds context (e.g., hold name) when cell names are generic.}

ObjectReference Function FindDoorToActorCell(Actor akActor) Global Native
{Find a door that leads to the actor's current cell.
Useful for pathfinding to an NPC's location.}

ObjectReference Function FindDoorToActorHome(Actor akActor) Global Native
{Find a door that leads to the actor's home cell}

ObjectReference Function FindExitDoorFromCell(Actor akActor) Global Native
{Find the exit door from the actor's current cell (leads outside)}

ObjectReference Function FindHomeInteriorMarker(Actor akActor) Global Native
{Find an interior marker in the actor's home cell}

ObjectReference Function FindInteriorMarkerForDoor(ObjectReference doorRef) Global Native
{Find the interior marker on the other side of a door reference}

; =============================================================================
; YIELD MONITOR
; Tracks hits on surrendered actors and auto-restores combat if attacked enough
; =============================================================================

Function RegisterYieldedActor(Actor akActor, Float originalAggression, Faction surrenderedFaction) Global Native
{Start monitoring a yielded actor for incoming hits. After threshold hits, auto-reverts surrender.
 surrenderedFaction is cached on first call — pass SeverSurrenderedFaction.}

Function UnregisterYieldedActor(Actor akActor) Global Native
{Stop monitoring a yielded actor. Called on ReturnToCrime, FullCleanup, or dismissal.}

Bool Function IsYieldMonitored(Actor akActor) Global Native
{Check if an actor is currently being monitored for yield-break hits.}

Int Function GetYieldHitCount(Actor akActor) Global Native
{Get the current hit count for a monitored yielded actor.}

Function SetYieldHitThreshold(Int threshold) Global Native
{Set how many hits a yielded actor must take before auto-reverting surrender. Default: 3.}

; =============================================================================
; DEPARTURE DETECTION (extension of StuckDetector)
; Verifies an NPC actually started moving after receiving a travel package.
; Uses baseline position from Stuck_StartTracking. Grace period: 15s, recovery: 30s.
; =============================================================================

Int Function Stuck_CheckDeparture(Actor akActor, Float departureThreshold) Global Native
{Check if a tracked actor has moved from their starting position.
 Returns: 0=too_early (grace period), 1=departed successfully, 2=soft recovery needed (30s no movement).
 departureThreshold: minimum distance from start to count as departed (default 100 units).}

; =============================================================================
; OFF-SCREEN TRAVEL ESTIMATION
; Estimates travel time for unloaded NPCs based on distance to destination.
; Uses ~18000 units/game-hour walking speed estimate.
; =============================================================================

Float Function OffScreen_InitTracking(Actor akActor, ObjectReference akDestination, Float minHours, Float maxHours) Global Native
{Start tracking off-screen travel for an actor. Calculates estimated arrival time based on distance.
 Returns the estimated arrival time in game-time format (days since epoch).
 minHours/maxHours: bounds for the estimate in game-hours (e.g., 0.5 to 18.0).}

Int Function OffScreen_CheckArrival(Actor akActor, Float currentGameTime) Global Native
{Check if an off-screen actor's estimated travel time has elapsed.
 currentGameTime: pass Utility.GetCurrentGameTime().
 Returns: 0=in_transit, 1=estimated arrival (should teleport to destination).}

Function OffScreen_StopTracking(Actor akActor) Global Native
{Stop off-screen tracking for an actor. Call on dispatch completion or cancellation.}

Float Function OffScreen_GetEstimatedArrival(Actor akActor) Global Native
{Get the estimated arrival game-time for a tracked actor. Returns 0 if not tracked.}

Function OffScreen_ClearAll() Global Native
{Clear all off-screen tracking data.}

; =============================================================================
; TEAMMATE MONITOR
; Detects SetPlayerTeammate changes for instant follower onboarding.
; Periodically scans loaded actors (~1 second intervals) and fires mod events
; when new teammates are detected or existing teammates are removed.
; Events: "SeverActions_NewTeammateDetected", "SeverActions_TeammateRemoved"
; =============================================================================

Function TeammateMonitor_SetEnabled(Bool enabled) Global Native
{Enable or disable the teammate monitor. Enabled by default.}

Bool Function TeammateMonitor_IsEnabled() Global Native
{Check if the teammate monitor is currently enabled.}

Int Function TeammateMonitor_GetTrackedCount() Global Native
{Get the number of currently tracked teammates.}

Function TeammateMonitor_ClearTracking() Global Native
{Clear all tracked teammate data. Called automatically on game load/new game.}

; =============================================================================
; ORPHAN CLEANUP - Detects stale LinkedRef keywords from crashed scripts
; Scans loaded actors (~5 second intervals) for SeverActions LinkedRef keywords
; that aren't tracked by any management system. Fires "SeverActions_OrphanCleanup"
; mod event with strArg = keyword type ("travel", "furniture", "follow").
; =============================================================================

Function OrphanCleanup_Initialize(Keyword travelKW, Keyword furnitureKW, Keyword followKW) Global Native
{Set the LinkedRef keywords to scan for. Call once during Maintenance.}

Function OrphanCleanup_RegisterTraveler(Actor akActor) Global Native
{Register an actor as actively traveling. Call when travel starts.}

Function OrphanCleanup_UnregisterTraveler(Actor akActor) Global Native
{Unregister an actor from travel tracking. Call when travel ends/clears.}

Function OrphanCleanup_RegisterFollower(Actor akActor) Global Native
{Register an actor as actively following. Call when follow starts.}

Function OrphanCleanup_UnregisterFollower(Actor akActor) Global Native
{Unregister an actor from follow tracking. Call when follow stops.}

Function OrphanCleanup_SetEnabled(Bool enabled) Global Native
{Enable or disable the orphan cleanup scanner. Enabled by default.}

Bool Function OrphanCleanup_IsEnabled() Global Native
{Check if the orphan cleanup scanner is currently enabled.}

Function OrphanCleanup_ClearTracking() Global Native
{Clear all tracked actor data. Called automatically on game load/new game.}
