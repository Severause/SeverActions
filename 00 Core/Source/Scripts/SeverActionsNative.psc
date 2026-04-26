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
; HOME SEARCH & EVIDENCE SYSTEM
; Container scanning, expanded evidence pools, and player-planted evidence detection
; =============================================================================

Int Function FindSearchContainers(Actor akGuard, Float radius = 3000.0) Global Native
{Scan the guard's loaded cell for searchable containers, sorted by suspiciousness.
Returns the number of containers found (max 4). Retrieve by index with GetSearchContainer.}

ObjectReference Function GetSearchContainer(Int index) Global Native
{Get a container reference at the given index from the last FindSearchContainers call.}

String Function GetContainerDescription(ObjectReference akContainer) Global Native
{Get a human-readable description of a container (e.g. "a chest near the bed").}

Form Function ScanContainerForEvidence(ObjectReference akContainer, String crimeCategory) Global Native
{Scan a container's inventory for suspicious items matching the crime category.
Pass 1 of two-pass system: detects player-planted evidence.
Returns the best-matching suspicious item, or None if nothing found.}

Function PlantEvidenceInContainer(ObjectReference akContainer, Form akItem, Int count = 1) Global Native
{Plant an evidence item into a container's inventory for the guard to find later.}

Function RemoveEvidenceFromContainer(ObjectReference akContainer, Actor akGuard, Form akItem, Int count = 1) Global Native
{Remove evidence from a container and transfer to the guard's inventory.}

Int Function ScoreEvidenceQuality(Form akItem, ObjectReference akContainer, String crimeReason) Global Native
{Score the quality/convincingness of evidence. Higher = more damning.
Factors: crime match (+2), bedroom location (+1), common item (-1), high value (+1).}

String Function SelectEvidenceFromPool(String reason, Actor akTargetNPC) Global Native
{Select 1-3 evidence items from the expanded pool for a crime category.
Returns pipe-delimited string: "formID1|name1||formID2|name2||formID3|name3".
Selection: 1 common (always) + 1 rare (30%) + 1 damning (10%).}

Int Function GetEvidenceCount() Global Native
{Get the number of evidence items from the last SelectEvidenceFromPool call.}

Form Function GetEvidenceAtIndex(Int index) Global Native
{Get an evidence form at the given index from the last SelectEvidenceFromPool call.}

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

ObjectReference Function FindFurnitureByFormID(String formIdStr, Actor nearActor) Global Native
{Resolve a furniture FormID string to an ObjectReference. Handles unsigned 32-bit FormIDs
(no Papyrus int overflow), both decimal and hex formats, and BaseID-to-RefID fallback
by searching for the nearest placed instance within 500 units of the actor.}

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
; NSFW UTILITIES — MOVED TO STANDALONE SeverActionsNSFW.dll
; See SeverActionsNSFW.psc for all NSFW native function declarations
; =============================================================================

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
; CEASEFIRE MONITOR
; Tracks player hits on ceasefire'd actors — breaks group ceasefire when player attacks
; =============================================================================

Function Ceasefire_Register(Actor akActor, Float originalAggression) Global Native
{Start monitoring a ceasefire'd actor for player hits. On hit, restores aggression
 and fires SeverActionsNative_CeasefireBroken ModEvent for Papyrus cleanup.}

Function Ceasefire_Unregister(Actor akActor) Global Native
{Stop monitoring a ceasefire'd actor.}

Bool Function Ceasefire_IsMonitored(Actor akActor) Global Native
{Check if an actor is currently being monitored for ceasefire-break hits.}

Function Ceasefire_ClearAll() Global Native
{Clear all ceasefire tracking data.}

Actor[] Function Ceasefire_FindNearbyAllies(Actor akActor, Float radius) Global Native
{Find all loaded actors within radius that share at least one faction with the given actor.
 Used to propagate group ceasefire to nearby allies. Excludes dead actors and the player.}

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
; ARRIVAL MONITOR
; Tracks actors moving toward a destination and fires a ModEvent on arrival.
; Uses distance checks on the game thread for zero-latency detection.
; =============================================================================

Function Arrival_Register(Actor akActor, ObjectReference akDestination, Float distanceThreshold, String callbackTag) Global Native
{Register an actor to be monitored for arrival at a destination reference.
 Fires ModEvent "SeverActions_ArrivalDetected" with callbackTag when within distanceThreshold.}

Function Arrival_RegisterXY(Actor akActor, Float destX, Float destY, Float distanceThreshold, String callbackTag) Global Native
{Register an actor to be monitored for arrival at X/Y coordinates.
 Fires ModEvent "SeverActions_ArrivalDetected" with callbackTag when within distanceThreshold.}

Function Arrival_Cancel(Actor akActor) Global Native
{Cancel arrival monitoring for an actor.}

Bool Function Arrival_IsTracked(Actor akActor) Global Native
{Check if an actor is being monitored for arrival.}

Float Function Arrival_GetDistance(Actor akActor) Global Native
{Get the current distance between a tracked actor and their destination. Returns -1 if not tracked.}

Int Function Arrival_GetTrackedCount() Global Native
{Get the number of actors currently being monitored for arrival.}

Function Arrival_ClearAll() Global Native
{Clear all arrival monitoring data.}

; =============================================================================
; GUARD FINDER
; Fast native search for nearby guard actors
; =============================================================================

Actor Function FindNearestGuard(Actor akNearActor, Float searchRadius = 3000.0) Global Native
{Find the nearest guard actor within searchRadius units of akNearActor. Returns None if no guard found.}

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
; PRISMA UI BRIDGE
; Web-based configuration menu via PrismaUI (soft dependency).
; PrismaUI is optional — all functions gracefully no-op when PrismaUI is absent.
; =============================================================================

Bool Function PrismaUI_IsAvailable() Global Native
{Check if PrismaUI is installed and the web config menu is available.}

Bool Function PrismaUI_IsMenuOpen() Global Native
{Check if the PrismaUI config menu is currently open.}

Function PrismaUI_ToggleMenu() Global Native
{Toggle the PrismaUI config menu open/closed.}

Function PrismaUI_SendData(String jsonData) Global Native
{Send JSON data to the PrismaUI config view (C++ forwards to JS via InteropCall).}

Function PrismaUI_CloseMenu() Global Native
{Close the PrismaUI config menu.}

String Function PrismaUI_ExtractJsonValue(String json, String key) Global Native
{Extract a value from a flat JSON object by key. Returns the value as a string.}

Function PrismaUI_SetPauseOnOpen(Bool enabled) Global Native
{Set whether PrismaUI freezes the game world when the menu opens. \
Called by Papyrus on load to push the StorageUtil-persisted value to C++.}

Bool Function PrismaUI_IsPauseOnOpen() Global Native
{Return the current pause-on-open setting from C++.}

; ── PrismaUI Data Builder ───────────────────────────────────────────
; C++ JSON builder — call these instead of Papyrus string concatenation.
; nlohmann_json produces correct booleans (true/false), escaped strings, etc.

Function PrismaUI_BeginPage(String page) Global Native
{Start building JSON for a page. Resets any in-progress build.}

Function PrismaUI_AddString(String key, String value) Global Native
{Add a string key-value to the current object.}

Function PrismaUI_AddBool(String key, Bool value) Global Native
{Add a boolean key-value (C++ writes true/false, not TRUE/FALSE).}

Function PrismaUI_AddInt(String key, Int value) Global Native
{Add an integer key-value to the current object.}

Function PrismaUI_AddFloat(String key, Float value) Global Native
{Add a float key-value to the current object.}

Function PrismaUI_BeginArray(String key) Global Native
{Start a JSON array under the given key.}

Function PrismaUI_EndArray() Global Native
{End the current array.}

Function PrismaUI_BeginObject() Global Native
{Start an anonymous object (typically inside an array).}

Function PrismaUI_BeginNamedObject(String key) Global Native
{Start a named object under the given key.}

Function PrismaUI_EndObject() Global Native
{End the current object (named or anonymous).}

Function PrismaUI_PushString(String value) Global Native
{Push a bare string value into the current array.}

Function PrismaUI_PushInt(Int value) Global Native
{Push a bare integer value into the current array.}

Function PrismaUI_PushFloat(Float value) Global Native
{Push a bare float value into the current array.}

Function PrismaUI_PushBool(Bool value) Global Native
{Push a bare boolean value into the current array.}

Function PrismaUI_SendPage() Global Native
{Serialize the built JSON and send to PrismaUI.}

; ── PrismaUI Data Gatherer ──────────────────────────────────────────
; Direct C++ data gathering — bypasses Papyrus for fast page loads.
; Quest references are passed once at startup so C++ can read script
; properties directly from the VM without needing EditorIDs.

Function PrismaUI_SetQuestRefs(Quest mcm, Quest followerMgr, Quest survival, \
    Quest arrest, Quest debt, Quest travel, Quest outfit, Quest loot, \
    Quest spellTeach, Quest hotkeys) Global Native
{Pass quest references to C++ for direct script property reading. Call once at startup.}

Function PrismaUI_RefreshPage(String page) Global Native
{Tell C++ to rebuild and send page data to PrismaUI. Call after actions/settings that change game state.}

; ── PrismaUI Diary Viewer ───────────────────────────────────────────
; Standalone popup for browsing and selecting diary entries to read aloud.
; Separate from the config dashboard — has its own C++ bridge (PrismaUIDiaryBridge).

Function PrismaUI_OpenDiaryViewerForBook(Form bookForm, Actor reader) Global Native
{Open the diary viewer popup for the given diary book. Extracts NPC from book title, queries SkyrimNet diary DB, shows entry list.}

Function PrismaUI_CloseDiaryViewer() Global Native
{Close the diary viewer popup.}

Bool Function PrismaUI_IsDiaryViewerOpen() Global Native
{Check if the diary viewer is currently open.}

String Function PrismaUI_GetSelectedDiaryContent() Global Native
{Get the full content of the diary entry selected by the player. Only valid after selection event fires.}

String Function PrismaUI_GetSelectedDiaryTitle() Global Native
{Get the title/date of the diary entry selected by the player. Only valid after selection event fires.}

; =============================================================================
; LINKED REF MANAGEMENT
; Native linked reference setting for package-based AI
; =============================================================================

Function LinkedRef_Set(Actor akActor, ObjectReference akTarget, Keyword akKeyword) Global Native
{Set a linked reference on an actor with a keyword.}

Function LinkedRef_Clear(Actor akActor, Keyword akKeyword) Global Native
{Clear a linked reference from an actor by keyword.}

Function LinkedRef_ClearAll(Actor akActor) Global Native
{Clear all linked references from an actor.}

Int Function LinkedRef_GetTrackedCount() Global Native
{Get the number of actors with active linked references.}

Bool Function LinkedRef_HasAny(Actor akActor) Global Native
{Check if an actor has any active linked references.}

Function NativeEvaluatePackage(Actor akActor) Global Native
{Force native package re-evaluation on an actor.
 Phase 6: now passes immediate=true to the engine call (was default false),
 so the re-evaluation actually takes effect instead of deferring to the next
 AI scheduler tick. Matches SkyrimNet's robust EvaluatePackage pattern.}

Function NativeResetAI(Actor akActor) Global Native
{Full AI reset + package re-evaluation. Same behavior as `resetai` console.
 Use for stragglers where NativeEvaluatePackage isn't enough — the actor's
 AI is still holding onto its previous package state. Disruptive: clears
 combat/alert state too, so don't use routinely.}

Function EnqueueDeferredForceEval(Actor akActor, Int delayMs) Global Native
{Enqueue a force-eval (immediate=true, resetAI=false) for akActor after
 delayMs elapses. Papers over races between our override change and the
 engine's AI scheduler tick. Drained every frame from the PackageManager
 InputEvent heartbeat — the delay is real, not rounded to a scan interval.}

Function EnqueueDeferredResetAI(Actor akActor, Int delayMs) Global Native
{Enqueue a full AI reset (immediate=true, resetAI=true) — same as `resetai`
 console command. Use for the stubborn-straggler case where even a force-eval
 doesn't dislodge the current package. Disruptive: clears combat/alert state
 too. Shares the same delayed-dispatch queue as EnqueueDeferredForceEval.}

Function EscalatedReEvaluate(Actor akActor, Int resetDelayMs = 1500) Global
{The 3-tier escalating package re-evaluation chain used after package swaps or
 marker moves that need to dislodge stuck AI state. Phase 6/7 testing showed no
 single tier was reliable by itself:
   Tier 1 (immediate): NativeEvaluatePackage — handles ~95% of cases.
   Tier 2 (500ms):     EnqueueDeferredForceEval — catches races (cell transitions,
                       ExtraPackage lag).
   Tier 3 (delayed):   EnqueueDeferredResetAI — nuclear hammer for stragglers
                       whose AI state hadn't settled at tier 2. Disruptive
                       (clears combat/alert state) — only use when the actor is
                       NOT expected to be in combat (home, safe-interior, etc).

 Default resetDelayMs=1500 matches the home-sandbox paths. Pass 1000 for the
 safe-interior exit path (shorter reaction window, companion is still local).}
    If !akActor
        Return
    EndIf
    NativeEvaluatePackage(akActor)
    EnqueueDeferredForceEval(akActor, 500)
    EnqueueDeferredResetAI(akActor, resetDelayMs)
EndFunction

; =============================================================================
; HOME SANDBOX VERIFIER (Phase 8 Fix C)
; Periodic native scanner that detects dismissed homed followers running an
; engine FE/FF fallback package and force-resets their AI so the CK alias
; home-sandbox package re-picks. Runs automatically on a 10-second heartbeat
; once the plugin initializes; Papyrus wrappers below are for debugging /
; manual forcing.
; =============================================================================

Function HomeVerifier_ForceScan() Global Native
{Run an immediate scan + reset pass. Useful for testing or after bulk
 cell-load operations that bypass the 10s heartbeat.}

Function HomeVerifier_SetEnabled(Bool enabled) Global Native
{Pause/resume the periodic scanner. Enabled by default on plugin init.}

Bool Function HomeVerifier_IsEnabled() Global Native
{Check if the periodic scanner is currently running.}

Function HomeVerifier_SetScanIntervalSeconds(Int seconds) Global Native
{Change the scan interval (1-600 seconds). Default 10s. Shorter intervals
 catch stragglers faster but add scan overhead; longer intervals save work.}

; =============================================================================
; ORPHAN CLEANUP
; Tracks orphaned travel/follower packages and auto-cleans them
; =============================================================================

Function OrphanCleanup_Initialize(Keyword travelKW, Keyword furnitureKW, Keyword followKW) Global Native
{Initialize orphan cleanup with the package keywords used by the mod.}

Function OrphanCleanup_RegisterTraveler(Actor akActor) Global Native
{Register a traveling actor for orphan monitoring.}

Function OrphanCleanup_UnregisterTraveler(Actor akActor) Global Native
{Unregister a traveling actor from orphan monitoring.}

Function OrphanCleanup_RegisterFollower(Actor akActor) Global Native
{Register a follower for orphan monitoring.}

Function OrphanCleanup_UnregisterFollower(Actor akActor) Global Native
{Unregister a follower from orphan monitoring.}

Function OrphanCleanup_SetEnabled(Bool enabled) Global Native
{Enable or disable orphan cleanup.}

Bool Function OrphanCleanup_IsEnabled() Global Native
{Check if orphan cleanup is enabled.}

Function OrphanCleanup_ClearTracking() Global Native
{Clear all orphan cleanup tracking data.}

; =============================================================================
; SKYRIMNET PLUGIN CONFIG BRIDGE
; Read settings from SkyrimNet's Plugin Configuration WebUI.
; Returns defaults when SkyrimNet is absent or doesn't support plugin config.
; =============================================================================

Bool Function PluginConfig_IsAvailable() Global Native
{Check if SkyrimNet plugin config is available.}

String Function PluginConfig_GetString(String path, String defaultVal) Global Native
{Read a string value from plugin config.}

Bool Function PluginConfig_GetBool(String path, Bool defaultVal) Global Native
{Read a bool value from plugin config.}

Int Function PluginConfig_GetInt(String path, Int defaultVal) Global Native
{Read an int value from plugin config.}

Float Function PluginConfig_GetFloat(String path, Float defaultVal) Global Native
{Read a float value from plugin config.}

; =============================================================================
; SKYRIMNET PUBLIC API BRIDGE
; Query SkyrimNet data (social graph, memories) when SkyrimNet is present
; =============================================================================

Bool Function IsPublicAPIReady() Global Native
{Check if SkyrimNet public API is available and ready.}

String Function GetFollowerEngagement(Actor akActor) Global Native
{Get engagement stats for a follower as JSON string.}

String Function GetFollowerSocialGraph(Actor akActor) Global Native
{Get the social graph data for a follower as JSON string.}

String Function SearchActorMemories(Actor akActor, String query) Global Native
{Search an actor's memory store. Returns JSON array of matching memories.}

; =============================================================================
; BOOK UTILITIES - Extended
; =============================================================================

Bool Function IsNote(Form akForm) Global Native
{Check if a form is a note (as opposed to a regular book).}

; =============================================================================
; SPELL DATABASE
; =============================================================================

Form Function FindSpellOnActor(Actor akActor, String spellName) Global Native
{Find a spell on an actor by name (case-insensitive). Returns the spell form or None.}

Form Function FindSpellByName(String spellName) Global Native
{Find a spell by name from the spell database (case-insensitive). Returns the spell form or None.}

String Function GetTeachableSpells(Actor akTeacher, Actor akLearner) Global Native
{Get a JSON string of spells the teacher knows that the learner doesn't.}

Bool Function IsSpellDBLoaded() Global Native
{Check if the spell database has been initialized.}

String Function GetSpellDBStats() Global Native
{Get spell database statistics string (indexed count, etc.).}

; =============================================================================
; SPELL CAST MANAGER
; Supports the CastSpell action - inject a runtime-chosen Spell into a
; pre-built usemagic AI package, classify spells, and recover stuck casts.
; =============================================================================

Bool Function Native_InjectSpellIntoPackage(Package akPackage, Spell akSpell) Global Native
{Swap the Spell form inside akPackage's custom data to akSpell.
Lets a single castmagic package scaffold cast any spell the LLM names.}

Bool Function Native_IsSelfDeliveredSpell(Spell akSpell) Global Native
{True if the spell's delivery type is Self (costliest effect targets the caster).}

Bool Function Native_IsHealingSpell(Spell akSpell) Global Native
{True if the spell is non-hostile Restoration. Used to gate the heal-to-full loop.}

Int Function Native_GetEffectiveMagickaCost(Actor akCaster, Spell akSpell, Bool bDualCasting) Global Native
{Magicka cost the caster will actually pay, post skill/perk modifiers. Doubled for dual cast.}

Bool Function Native_IsCasterStillCasting(Actor akCaster) Global Native
{Poll the caster's animation graph for IsCastingLeft/IsCastingRight. Used by the stuck-charge watchdog.}

Function Native_ForceReleaseCast(Actor akCaster) Global Native
{Interrupt + fire animation release events on both hands. Recovers a caster stuck in ChargeLoop.}

Function Native_EvaluateActorPackage(Actor akActor) Global Native
{Force re-evaluation of the actor's AI package. Use after removing a package override.}

Function Native_DiagnoseCastSetup(Actor akActor, Spell akSpell) Global Native
{Logs spell properties (castingType, equipSlot, magickaCost), actor's current package,
combat state, and equipped slots. Diagnostic for figuring out why a cast won't fire.}

Function Native_EquipSpellOnActor(Actor akActor, Spell akSpell, Int aiSlot) Global Native
{Equip a spell in a hand slot. aiSlot: 0=left, 1=right, 2=voice. Mimics what bosn's
clonePackageSpell does — without an explicit equip the engine's UseMagic procedure
sometimes loses the spell-equip race against CombatStyle weapon preferences.}

Spell Function Native_CloneSpellForCast(Actor akActor, Spell akSource, Bool abDualCasting) Global Native
{Clone a spell into a fresh runtime SpellItem (mirrors bosn's clonePackageSpell).
The clone has its casting perk dropped and its equipSlot set to EitherHand. Use the
returned spell as the target of Native_InjectSpellIntoPackage so the UseMagic
procedure has a clean form to drive — the original Requiem spell carries enough
state that the procedure runs silently and never dispatches to MagicCaster.}

Bool Function Native_ForceFireSpell(Actor akActor, Spell akSpell, ObjectReference akTarget) Global Native
{Force-fire a spell from the actor's MagicCaster at the target. Bypasses the AI
package procedure entirely — projectile spawns, effects apply, animation may or
may not play. Used as a fallback when the UseMagic procedure refuses to dispatch
(diagnostic shows MagicCaster state=0 across all polls). At minimum the cast
actually happens, which is better than the alternative.}

; =============================================================================
; FOLLOWER DATA STORE (SKSE Cosave Persistence)
; Native cosave persistence for per-actor home location and combat style.
; Replaces unreliable StorageUtil string persistence with SKSE serialization.
; =============================================================================

Function Native_SetHome(Actor akActor, String location) Global Native
{Store home location in SKSE cosave. Persists reliably across save/load.}

String Function Native_GetHome(Actor akActor) Global Native
{Get home location from SKSE cosave. Returns "" if not set.}

Function Native_ClearHome(Actor akActor) Global Native
{Clear home location from SKSE cosave.}

Function Native_SetCombatStyle(Actor akActor, String style) Global Native
{Store combat style in SKSE cosave. Persists reliably across save/load.}

String Function Native_GetCombatStyle(Actor akActor) Global Native
{Get combat style from SKSE cosave. Returns "" if not set.}

Function Native_ClearCombatStyle(Actor akActor) Global Native
{Clear combat style from SKSE cosave.}

; --- Relationship values ---

Function Native_SetRelationship(Actor akActor, Float rapport, Float trust, Float loyalty, Float mood) Global Native
{Batch-set all four relationship values in SKSE cosave.}

Float Function Native_GetRapport(Actor akActor) Global Native
{Get rapport value. Returns 0.0 if not set.}

Float Function Native_GetTrust(Actor akActor) Global Native
{Get trust value. Returns 25.0 if not set.}

Float Function Native_GetLoyalty(Actor akActor) Global Native
{Get loyalty value. Returns 50.0 if not set.}

Float Function Native_GetMood(Actor akActor) Global Native
{Get mood value. Returns 50.0 if not set.}

; --- State flags ---

Function Native_SetSandboxing(Actor akActor, Bool val) Global Native
{Set sandboxing flag in SKSE cosave.}

Function Native_SetInForcedCombat(Actor akActor, Bool val) Global Native
{Set forced combat flag in SKSE cosave.}

Function Native_SetSurrendered(Actor akActor, Bool val) Global Native
{Set surrendered flag in SKSE cosave.}

; --- Travel state ---

Function Native_SetTravelState(Actor akActor, String travelState, String destination) Global Native
{Set travel state and destination in SKSE cosave. Empty strings to clear.}

; --- Package state ---

Function Native_SetPackageState(Actor akActor, Bool hasFollow, Bool hasTalkPlayer, Bool hasTalkNPC) Global Native
{Set package state flags in SKSE cosave.}

Bool Function Native_GetHasFollowPkg(Actor akActor) Global Native
{Check if actor had a follow package before save/load. Used to re-register casual follow packages on game load.}

Function Native_SetOffscreenExcluded(Actor akActor, Bool excluded) Global Native
{Set whether a follower is excluded from off-screen life events.}

Bool Function Native_GetOffscreenExcluded(Actor akActor) Global Native
{Check if a follower is excluded from off-screen life events.}

; --- Outfit exclusion ---

Function Native_SetOutfitExcluded(Actor akActor, Bool excluded) Global Native
{Set whether a follower is excluded from the entire outfit system. When true, no outfit lock, no DefaultOutfit suppression, no situation auto-switch, no alias re-equip. Allows other outfit mods to manage them freely.}

Bool Function Native_GetOutfitExcluded(Actor akActor) Global Native
{Check if a follower is excluded from the outfit system.}

; --- Roster flag ---

Function Native_SetIsFollower(Actor akActor, Bool val) Global Native
{Mark whether this actor is a registered follower (true) or just an NPC with home/data (false).}

Actor[] Function Native_GetAllTrackedFollowers() Global Native
{Returns all followers tracked in the native cosave, regardless of cell. Excludes dead actors.}

; --- Pair Relationships (inter-follower) ---

Function Native_SetPairRelationship(Actor akActor, Actor akTarget, Float affinity, Float respect, String blurb = "") Global Native
{Set how akActor feels about akTarget. Persisted in SKSE cosave. Blurb is an LLM-generated summary.}

Float Function Native_GetPairAffinity(Actor akActor, Actor akTarget) Global Native
{Get how much akActor likes akTarget (-100 to 100). Returns 0.0 if not set.}

Float Function Native_GetPairRespect(Actor akActor, Actor akTarget) Global Native
{Get how much akActor respects akTarget (0 to 100). Returns 30.0 if not set.}

String Function Native_GetAllPairJson(Actor akActor) Global Native
{Get all of akActor's inter-follower opinions as a JSON array.}

; --- Home Marker Slot Management ---

Int Function Native_AcquireHomeMarkerSlot(Actor akActor) Global Native
{Acquire the first free home marker slot (0-19) for this actor.
 Returns the slot index, or -1 if all 20 slots are in use.
 If the actor already has a slot, returns their existing slot.}

Int Function Native_GetHomeMarkerSlot(Actor akActor) Global Native
{Get this actor's home marker slot index. Returns -1 if unassigned.}

Function Native_ReleaseHomeMarkerSlot(Actor akActor) Global Native
{Release this actor's home marker slot back to the pool.}

; --- Routine Loc (Work / Play) ---

Function Native_SetWorkLoc(Actor akActor, ObjectReference marker) Global Native
{Store the Work marker FormID for this follower. Cosave-persisted.}

ObjectReference Function Native_GetWorkLoc(Actor akActor) Global Native
{Get the Work marker for this follower, or None if unset.}

Function Native_ClearWorkLoc(Actor akActor) Global Native
{Clear the stored Work marker for this follower.}

Function Native_SetPlayLoc(Actor akActor, ObjectReference marker) Global Native
{Store the Play marker FormID for this follower. Cosave-persisted.}

ObjectReference Function Native_GetPlayLoc(Actor akActor) Global Native
{Get the Play marker for this follower, or None if unset.}

Function Native_ClearPlayLoc(Actor akActor) Global Native
{Clear the stored Play marker for this follower.}

; --- Essential Status ---

Function Native_SetEssential(Actor akActor) Global Native
{Set this actor as essential (cannot die). Uses engine base data flag.}

Function Native_ClearEssential(Actor akActor) Global Native
{Remove essential status from this actor. They can die again.}

Bool Function Native_IsEssential(Actor akActor) Global Native
{Check if this actor is currently flagged as essential.}

; --- Cleanup ---

Function Native_ClearFollowerData(Actor akActor) Global Native
{Clear transient follower data (on dismiss). Preserves home + combatStyle for re-recruit.}

Function Native_RemoveFollowerData(Actor akActor) Global Native
{Fully erase ALL follower data including pair relationships (force-remove / death cleanup).}

; =============================================================================
; EQUIPMENT BLACKLIST (SKSE cosave)
; Protects specific items or entire plugins from being removed by undress.
; Global (not per-actor) — persisted via cosave record 'BLKL'.
; =============================================================================

Bool Function Native_Blacklist_IsBlacklisted(Form item) Global Native
{Check if an item is blacklisted (by FormID or by its source plugin).}

Function Native_Blacklist_AddPlugin(String pluginName) Global Native
{Blacklist all items from a plugin — they won't be removed by undress.}

Function Native_Blacklist_RemovePlugin(String pluginName) Global Native
{Remove a plugin from the blacklist.}

Function Native_Blacklist_AddItem(Form item) Global Native
{Blacklist a specific item — it won't be removed by undress.}

Function Native_Blacklist_RemoveItem(Form item) Global Native
{Remove a specific item from the blacklist.}

; =============================================================================
; OUTFIT DATA STORE (SKSE cosave)
; Native C++ data store for per-actor outfit lock + preset data.
; Uses begin/add/commit pattern — no Form[] array marshaling.
; =============================================================================

; --- Lock operations ---

Function Native_Outfit_BeginLock(Actor akActor) Global Native
{Start staging a lock update for this actor. Call AddLockedItem in a loop, then CommitLock.}

Function Native_Outfit_AddLockedItem(Actor akActor, Form item) Global Native
{Add one item to the lock staging area. Must call BeginLock first.}

Function Native_Outfit_CommitLock(Actor akActor) Global Native
{Commit staged items as the actor's locked outfit (lockActive=true).}

Function Native_Outfit_ClearLock(Actor akActor) Global Native
{Clear outfit lock entirely. Removes actor from store if no presets remain.}

Function Native_Outfit_RemoveLockedItem(Actor akActor, Form item) Global Native
{Remove a single item from an existing locked outfit.}

Function Native_Outfit_RemoveActor(Actor akActor) Global Native
{Fully erase an actor from the outfit data store (force-remove).}

Form[] Function Native_Outfit_GetLockedItems(Actor akActor) Global Native
{Get the current locked items from the native outfit store. Returns the C++ source \
of truth — use this instead of GetWornForm snapshots to avoid async race conditions.}

Bool Function Native_Outfit_IsNativeSuspended(Actor akActor) Global Native
{Check if C++ has this actor suspended (mid-equip operation). Used by OutfitAlias.}

; --- Burst strip detection ---
; Detects when external mods rapidly strip armor (3+ items in 500ms).
; Auto-suspends outfit lock for 30 seconds to avoid fighting the other mod.

Bool Function Native_Outfit_RecordExternalUnequip(Actor akActor) Global Native
{Record an external unequip event. Returns true if burst strip detected (lock should yield).}

Function Native_Outfit_ClearBurstSuppression(Actor akActor) Global Native
{Clear burst suppression for an actor (called when outfit system resumes control).}

Bool Function Native_Outfit_IsBurstSuppressed(Actor akActor) Global Native
{Check if an actor's outfit lock is currently burst-suppressed.}

Bool Function Native_Outfit_IsInAnimationScene(Actor akActor) Global Native
{Check if an actor is in a SexLab or OStim scene via EditorID-based faction lookup.
Works regardless of load order or FormID. Cached after first resolve.}

Function Native_Outfit_RestoreStashedItems(Actor akActor) Global Native
{Restore items stashed during buildOutfitEquip back to actor inventory.
Call AFTER lock sync so the alias can fight any engine auto-equip.}

Form[] Function Native_Outfit_GetPresetItems(Actor akActor, String presetName) Global Native
{Get items from a named preset in the native OutfitDataStore.}

Form[] Function Native_Outfit_GetWornArmor(Actor akActor) Global Native
{Get all currently worn armor on an actor as a Form array. Single native call
replaces the 18-slot GetWornForm Papyrus loop. Avoids async race conditions.}

; --- Preset operations ---

Function Native_Outfit_BeginPreset(Actor akActor, String presetName) Global Native
{Start staging a preset save. Call AddPresetItem in a loop, then CommitPreset.}

Function Native_Outfit_AddPresetItem(Actor akActor, Form item) Global Native
{Add one item to the preset staging area. Must call BeginPreset first.}

Function Native_Outfit_CommitPreset(Actor akActor) Global Native
{Commit staged items as a named preset for the actor.}

Function Native_Outfit_DeletePreset(Actor akActor, String presetName) Global Native
{Delete a named preset. Removes actor from store if no lock + no presets remain.}

; ── Outfit Situation System (v2) ──

Function Native_Outfit_SetActivePreset(Actor akActor, String presetName) Global Native
{Set the name of the currently active preset ("" for manual outfit).}

String Function Native_Outfit_GetActivePreset(Actor akActor) Global Native
{Get the name of the currently active preset ("" if manual).}

Function Native_Outfit_SetCurrentSituation(Actor akActor, String situation) Global Native
{Set the current detected situation for this actor.}

String Function Native_Outfit_GetCurrentSituation(Actor akActor) Global Native
{Get the current detected situation for this actor.}

Function Native_Outfit_SetAutoSwitchEnabled(Actor akActor, Bool enabled) Global Native
{Enable or disable auto-switching for this actor.}

Bool Function Native_Outfit_GetAutoSwitchEnabled(Actor akActor) Global Native
{Check if auto-switching is enabled for this actor.}

Function Native_Outfit_SetSituationPreset(Actor akActor, String situation, String presetName) Global Native
{Assign a preset to automatically wear in a given situation (town, adventure, home, sleep).}

String Function Native_Outfit_GetSituationPreset(Actor akActor, String situation) Global Native
{Get the preset assigned to a situation ("" if none).}

Function Native_Outfit_ClearSituationPreset(Actor akActor, String situation) Global Native
{Clear the preset assignment for a situation.}

; ── Survival Data Store (cosave-backed) ──

Function Native_Survival_SetNeeds(Actor akActor, Float hunger, Float fatigue, Float cold) Global Native
{Write survival needs to the native cosave-backed store (for PrismaUI fast path).}

Float Function Native_Survival_GetHunger(Actor akActor) Global Native
{Read hunger from native store.}

Float Function Native_Survival_GetFatigue(Actor akActor) Global Native
{Read fatigue from native store.}

Float Function Native_Survival_GetCold(Actor akActor) Global Native
{Read cold from native store.}

Function Native_Survival_SetExcluded(Actor akActor, Bool excluded) Global Native
{Mark actor as excluded from survival tracking.}

Bool Function Native_Survival_IsExcluded(Actor akActor) Global Native
{Check if actor is excluded from survival tracking.}

Function Native_Survival_RemoveFollower(Actor akActor) Global Native
{Remove actor from the survival data store entirely.}

Function Native_Survival_InitNearby(Actor akActor) Global Native
{Initialize or drift nearby NPC survival values in native store (C++ randomization).}

Float Function Native_Survival_GetNearbyHunger(Actor akActor) Global Native
{Read nearby NPC hunger from native store.}

Float Function Native_Survival_GetNearbyFatigue(Actor akActor) Global Native
{Read nearby NPC fatigue from native store.}

Float Function Native_Survival_GetNearbyCold(Actor akActor) Global Native
{Read nearby NPC cold from native store.}

; ── Situation Monitor ──

Function SituationMonitor_SetEnabled(Bool enabled) Global Native
{Enable or disable the situation monitor globally.}

Bool Function SituationMonitor_IsEnabled() Global Native
{Check if the situation monitor is currently enabled.}

String Function SituationMonitor_GetSituation(Actor akActor) Global Native
{Get the current detected situation for an actor (adventure, town, home, sleep).}

Function SituationMonitor_ForceEvaluate(Actor akActor) Global Native
{Force immediate situation re-evaluation for an actor, bypassing stability delay.}

Function SituationMonitor_SetScanInterval(Int ms) Global Native
{Set the scan interval in milliseconds (1000-30000, default 3000).}

Int Function SituationMonitor_GetScanInterval() Global Native
{Get the current scan interval in milliseconds.}

Function SituationMonitor_SetStabilityThreshold(Int ms) Global Native
{Set the stability threshold in milliseconds (1000-30000, default 5000).}

Int Function SituationMonitor_GetStabilityThreshold() Global Native
{Get the current stability threshold in milliseconds.}

; =============================================================================
; ARMOR CATALOG
; =============================================================================

Int Function ArmorCatalog_GetArmorCount() Global Native
{Get the total number of indexed armor records across all loaded plugins.}

Form Function ArmorCatalog_SearchByName(String query) Global Native
{Search the armor catalog by name. Returns the first matching armor form, or None if not found.}

Int Function ArmorCatalog_GetPluginCount() Global Native
{Get the number of plugins that contain armor records.}

; =============================================================================
; OFF-SCREEN LIFE DATA STORE (SKSE cosave)
; Native C++ data store for dismissed follower life events, consequences, and gossip.
; Persists across save/load via cosave record 'OSLD'.
; =============================================================================

Function Native_OffScreen_AddEvent(Actor akActor, String summary, String eventType, Float gameTime, Bool hasConsequence, String consequenceType, Int consequenceAmount, String consequenceCrime, String involvedName) Global Native
{Add a life event for a dismissed follower. Stored in ring buffer (max 20 per actor).}

Function Native_OffScreen_AddGossip(String locationName, String gossipText, Float gameTime) Global Native
{Add a gossip entry for a location. Ring buffer, max 5 per location.}

Function Native_OffScreen_ClearActor(Actor akActor) Global Native
{Remove all off-screen life data for an actor (used by PurgeFollower).}

Function Native_OffScreen_IncrementBounty(Actor akActor, Int amount) Global Native
{Increment cumulative off-screen bounty for an actor.}

Function Native_OffScreen_IncrementDebt(Actor akActor, Int amount) Global Native
{Increment cumulative off-screen debt for an actor.}

Function Native_OffScreen_IncrementGoldEarned(Actor akActor, Int amount) Global Native
{Increment total gold earned off-screen for an actor.}

Function Native_OffScreen_IncrementGoldLost(Actor akActor, Int amount) Global Native
{Increment total gold lost off-screen for an actor.}

Function Native_OffScreen_IncrementArrestCount(Actor akActor) Global Native
{Increment the off-screen arrest counter for an actor.}

Function Native_OffScreen_ClearBounty(Actor akActor) Global Native
{Clear the off-screen bounty for an actor (set to 0).}

Function Native_OffScreen_ClearDebt(Actor akActor) Global Native
{Clear the off-screen debt for an actor (set to 0).}

String Function Native_OffScreen_ParseLLMResponse(Actor akActor, String response, Float gameTime) Global Native
{Parse the raw JSON from the off-screen life LLM callback using nlohmann::json. \
Stores events directly in the native data store and returns a pipe-delimited string \
with parsed fields: summary1|type1|gossip1|summary2|type2|gossip2|conseqAction|conseqAmount| \
conseqReason|conseqCrime|conseqItem|conseqCategory|conseqCount|involved|diary. \
Returns empty string on parse failure.}

String Function Native_OffScreen_BuildContext(Actor akActor, Bool consequencesEnabled, Float consequenceCooldownSec, Float lastConsequenceGT, Float currentGameTime) Global Native
{Build the full context JSON for the off-screen life LLM prompt natively in C++. \
Reads home from FollowerDataStore, queries social graph from SkyrimNet PublicAPI, \
finds nearby dismissed followers in the same hold, and checks consequence eligibility. \
Returns a properly serialized JSON string ready for SendCustomPromptToLLM, or empty on failure.}

String Function Native_OffScreen_GetRecentLifeEvents(Actor akActor, Int maxEvents, Float currentGameTime) Global Native
{Returns formatted life events for prompt injection from the native cosave store. \
Each line: "- [time ago] summary [type] (with NPC)". Newest first, up to maxEvents (0=all). \
Returns empty string if no events exist for this actor.}

; =============================================================================
; MEMORY CREATION (SkyrimNet PublicAPI v5+)
; =============================================================================

Int Function Native_AddMemory(Actor akActor, String content, Float importance, String memoryType, String emotion, String location, String tagsJSON, String relatedActorsJSON) Global Native
{Create a memory for an actor via SkyrimNet's memory system. \
Returns memory ID (>0) on success, 0 on failure. \
memoryType: EXPERIENCE, RELATIONSHIP, KNOWLEDGE, LOCATION, SKILL, TRAUMA, JOY. \
tagsJSON: JSON array of tag strings, e.g. '["offscreen", "social"]'. \
relatedActorsJSON: JSON array of hex UUID strings for related actors.}

; =============================================================================
; PROPERTY OWNERSHIP
; Transfer cell/building ownership between actors.
; =============================================================================

Bool Function Native_TransferCellOwnership(Actor akNewOwner, String propertyName, Faction akFaction) Global Native
{Transfer ownership of a cell and all its owned references to a shared faction. \
Both akNewOwner and the original cell owner are added to akFaction. \
If propertyName is empty, uses akNewOwner's current parent cell. \
Records the transfer in PropertyStore for tracking/persistence. Returns true on success.}

Int Function Native_Property_GetOwnedCount() Global Native
{Get the number of properties owned by the player.}

String Function Native_Property_GetOwnedNames() Global Native
{Get a pipe-delimited list of owned property names.}

; ── Knowledge Store ──────────────────────────────────────────────────────────
; Conditional knowledge entries managed via PrismaUI. Groups of NPCs see
; different knowledge based on their faction membership.

Int Function Native_Knowledge_GetCount() Global Native
{Get the number of conditional knowledge entries.}

String Function Native_GetCellOwnerName(ObjectReference akRef) Global Native
{Get the display name of whoever owns the cell that akRef is in. \
Returns empty string if unowned.}

; =============================================================================
; ITEM RESOLVER
; Native item lookup by name with fuzzy matching and inventory give/take.
; Searches weapons, armor, potions, food, ingredients, misc items.
; Prefers vanilla Skyrim.esm items over mod-added forms.
; =============================================================================

Bool Function Native_GiveItemByName(Actor akActor, String itemName, String category, Int count) Global Native
{Give an item to an actor by resolving itemName to a game form.
category: "weapon", "armor", "potion", "food", "ingredient", "misc", "any"
Returns true if item was found and added. Runs on game thread.}

Bool Function Native_TakeItemByName(Actor akActor, String itemName, String category, Int count) Global Native
{Take an item from an actor by resolving itemName to a game form.
Returns false if actor doesn't have the item. Runs on game thread.}

Int Function Native_ResolveItemFormID(String itemName, String category) Global Native
{Resolve an item name to its FormID without modifying any inventory.
Returns 0 if not found. Useful for checking if an item exists.}

String Function Native_ResolveItemName(String itemName, String category) Global Native
{Resolve a fuzzy item name to the actual in-game item name.
Returns "" if not found. Useful for normalizing LLM-generated item names.}

; =============================================================================
; QUEST AWARENESS
; Presence-based quest tracking for followers. C++ monitors quest stage changes
; via TESQuestStageEvent and tracks presence (firsthand vs secondhand).
; C++ builds all JSON context — Papyrus just forwards to SendCustomPromptToLLM.
; =============================================================================

String Function Native_PopSummaryRequest() Global Native
{Pop the next queued LLM summary request. Returns pre-built JSON context string \
for passing directly to SendCustomPromptToLLM. Returns "" when queue is empty. \
Papyrus should call this in a loop until it returns "".}

String Function Native_PopCompletionEntry() Global Native
{Pop the next quest completion entry for memory creation. \
Returns a JSON string with actorFormID, editorID, summary, and isFirsthand fields. \
Returns "" when queue is empty.}

Function Native_StorePendingSummary(String response) Global Native
{Store the LLM response for the most recently popped summary request. \
Uses metadata from the FIFO pending queue set by Native_PopSummaryRequest.}

Function Native_SetQuestSummary(Actor akActor, String editorID, String summary, Bool isFirsthand) Global Native
{Store an LLM-generated personalized quest summary for a follower. \
Called from Papyrus after SendCustomPromptToLLM returns the summary text.}

Function Native_OnFollowerRecruited(Actor akActor) Global Native
{Notify the quest awareness store that a follower was recruited. \
Seeds SECONDHAND awareness of all active tracked quests and queues catch-up summaries. \
Call from RegisterFollower() in FollowerManager.}

Int Function Native_PopReputationAssessRequest() Global Native
{Pop the next NPC FormID queued for reputation assessment. \
Returns the FormID (as int) of the next NPC to assess, or 0 when queue is empty. \
Papyrus enqueues via Native_QueueReputationAssessment on the blurb-milestone check, \
then processes one at a time via LLM callback chain.}

Int Function Native_GetFamiliarityInteractions(Actor akActor) Global Native
{Return the current dialogue line count tracked by the player_familiarity decorator \
for this NPC, or -1 if the actor hasn't been evaluated yet this session. \
Used by the blurb-milestone check (first dialogue, every 100 lines after).}

Function Native_QueueReputationAssessment(Actor akActor) Global Native
{Enqueue this NPC for blurb generation and fire the SeverActions_ReputationAssess event. \
Papyrus calls this after deciding a blurb milestone (1st or every 100th line) is due.}

Int Function Native_GetFollowerAwarenessTier(Actor akActor, String editorID) Global Native

; =============================================================================
; SITUATION MONITOR
; =============================================================================

Function SituationMonitor_RescueSandboxers() Global Native
{Rescue any auto-sandboxing followers stranded in a previous cell. \
Call on cell load to bring them to the player.}

Function SituationMonitor_SetSafeInteriorEnabled(Bool enabled) Global Native
{Enable or disable safe interior auto-sandbox globally. \
Call from Papyrus to push persisted StorageUtil value to C++ on load.}

Bool Function SituationMonitor_IsSafeInteriorEnabled() Global Native
{Check if safe interior auto-sandbox is currently enabled in C++.}

Function FriendlyFireMonitor_SetEnabled(Bool enabled) Global Native
{Enable or disable follower-vs-follower damage prevention. \
Call from Papyrus to push persisted StorageUtil value to C++ on load.}

Bool Function FriendlyFireMonitor_IsEnabled() Global Native
{Check if follower-friendly-fire prevention is currently enabled in C++.}

; =============================================================================
; OUTFIT SLOT SYSTEM (NFF-style)
; Pre-built Outfit+LeveledItem+Container triples per (slot, preset). Papyrus
; populates LeveledItem from container, then SetOutfit(outfitRecord) — engine
; auto-equips on every cell load. Up to 50 slots × 8 presets = 400 triples.
; =============================================================================

Int Function Native_OutfitSlot_AssignSlot(Actor akActor) Global Native
{Assign first free outfit slot to actor. Idempotent — returns existing index if already assigned. Returns -1 if all 50 slots occupied.}

Function Native_OutfitSlot_ReleaseSlot(Actor akActor) Global Native
{Release actor's outfit slot. Does NOT restore DefaultOutfit — call SetOutfit separately.}

Int Function Native_OutfitSlot_GetSlot(Actor akActor) Global Native
{Return actor's slot index (0-49) or -1 if no slot assigned.}

Outfit Function Native_OutfitSlot_GetOutfitForm(Int slotIdx, Int presetIdx) Global Native
{Resolve the pre-built BGSOutfit record for (slot, preset). Returns None if out of range or ESP not scaffolded.}

LeveledItem Function Native_OutfitSlot_GetLvlItem(Int slotIdx, Int presetIdx) Global Native
{Resolve the pre-built LeveledItem placeholder for (slot, preset). Used for Revert()/AddForm() population.}

ObjectReference Function Native_OutfitSlot_GetContainer(Int slotIdx, Int presetIdx) Global Native
{Resolve the dynamically-spawned storage container for (slot, preset). Returns None if not yet spawned — call PlaceAtMe + SetContainerRef.}

ObjectReference Function Native_OutfitSlot_GetSatchel(Int slotIdx) Global Native
{Resolve the dynamically-spawned satchel container for this slot. Returns None if not yet spawned.}

Container Function Native_OutfitSlot_GetChestBase() Global Native
{Resolve the ESP-defined CONT record used as base for all PlaceAtMe spawns.}

Function Native_OutfitSlot_SetContainerRef(Actor akActor, Int presetIdx, ObjectReference chest) Global Native
{Register a freshly spawned container ref to this actor's slot+preset. Pass None to clear.}

Function Native_OutfitSlot_SetSatchelRef(Actor akActor, ObjectReference satchel) Global Native
{Register a freshly spawned satchel ref to this actor's slot. Pass None to clear.}

Outfit Function Native_OutfitSlot_GetBlankOutfit() Global Native
{Sentinel empty Outfit record, used to strip engine enforcement before switching.}

Outfit Function Native_OutfitSlot_GetNakedOutfit() Global Native
{Sentinel empty Outfit record used as sleepOutfit override.}

Function Native_OutfitSlot_SaveOriginalOutfit(Actor akActor) Global Native
{Snapshot the actor's current DefaultOutfit and sleepOutfit FormIDs. Idempotent per slot — no-ops if already saved.}

Outfit Function Native_OutfitSlot_GetOriginalOutfit(Actor akActor) Global Native
{Return the saved original DefaultOutfit, or None if unsaved.}

Outfit Function Native_OutfitSlot_GetOriginalSleepOutfit(Actor akActor) Global Native
{Return the saved original sleepOutfit, or None if unsaved.}

Function Native_OutfitSlot_SetPresetName(Actor akActor, Int presetIdx, String name) Global Native
{Store the user-visible preset name for UI display.}

String Function Native_OutfitSlot_GetPresetName(Actor akActor, Int presetIdx) Global Native
{Retrieve the user-visible preset name. Empty string = unused preset slot.}

Function Native_OutfitSlot_SetPresetItemCount(Actor akActor, Int presetIdx, Int count) Global Native
{Cache the item count for a preset (for UI display without reading container).}

Int Function Native_OutfitSlot_GetPresetItemCount(Actor akActor, Int presetIdx) Global Native
{Cached item count. Zero = empty/unused preset.}

Function Native_OutfitSlot_ClearPreset(Actor akActor, Int presetIdx) Global Native
{Clear preset name, item count, and situation mappings pointing to this index. Does NOT empty the container or LvlItem — caller must.}

Function Native_OutfitSlot_SetActivePreset(Actor akActor, Int presetIdx) Global Native
{Mark which preset is currently active (-1 = none/cleared).}

Int Function Native_OutfitSlot_GetActivePreset(Actor akActor) Global Native
{Return currently-active preset index, or -1 if none.}

Bool Function Native_OutfitSlot_IsPresetActive(Actor akActor) Global Native
{Fast check: does this actor have a preset currently active? Used by OutfitAlias short-circuit.}

Int Function Native_OutfitSlot_DirectEquipPreset(Actor akActor, Int presetIdx) Global Native
{Atomic C++ direct-equip path. Bypasses SetOutfit/LeveledItem auto-equip
 (which sometimes only equips one item even when LvlItem has multiple entries
 with kUseAll). Snapshots the preset chest, suspends outfit lock, strips worn
 armor, adds-if-missing + equips each preset item via ActorEquipManager,
 resumes lock, sets activePresetIdx.
 Returns count of armor items equipped, or -1 on hard error.}

; ── Catalog-Supplied Item Tracking ──
; Marks specific FormIDs as "catalog-supplied" (added by C++ from the UI catalog
; vs. items that were already in the actor's inventory at build time).
; Used by DirectEquipPreset and RemovePresetItemsFromActor for ownership-aware
; add/delete. User-owned items (not in the catalog list) are NEVER auto-deleted.

Function Native_OutfitSlot_AddCatalogSupplied(Actor akActor, Int presetIdx, Form item) Global Native
{Mark a FormID as catalog-supplied for the given preset.}

Bool Function Native_OutfitSlot_IsCatalogSupplied(Actor akActor, Int presetIdx, Form item) Global Native
{Check if a FormID is marked catalog-supplied for the given preset.}

Function Native_OutfitSlot_ClearCatalogSupplied(Actor akActor, Int presetIdx) Global Native
{Clear all catalog-supplied entries for a preset (used on preset overwrite/delete).}

Form[] Function Native_OutfitSlot_PopPendingCatalog(Actor akActor, String presetName) Global Native
{Pop the transient catalog-supplied list recorded by C++ buildOutfitSavePreset.
 Returns the FormIDs that were spawned by C++ (not in actor inventory at build time).
 Consume-once: the list is cleared after this call. Used by Papyrus BuildPreset
 to tag items via Native_OutfitSlot_AddCatalogSupplied.}

Function Native_OutfitSlot_SetSituationPreset(Actor akActor, String situation, Int presetIdx) Global Native
{Map a situation name to a preset index. Pass -1 to clear the mapping.}

Int Function Native_OutfitSlot_GetSituationPreset(Actor akActor, String situation) Global Native
{Return preset index mapped to situation, or -1 if no mapping.}

Function Native_OutfitSlot_SetAutoSwitch(Actor akActor, Bool enabled) Global Native
{Per-actor toggle for auto-switching on situation change.}

Bool Function Native_OutfitSlot_GetAutoSwitch(Actor akActor) Global Native
{Per-actor auto-switch state (default true).}

Actor[] Function Native_OutfitSlot_GetAssignedActors() Global Native
{Return all actors currently holding an outfit slot. Used by Maintenance to repopulate LvlItems on game load.}

ReferenceAlias Function Native_OutfitSlot_FindAliasByName(String aliasName) Global Native
{Look up a ReferenceAlias on the SeverActions quest by its ALID name. Returns None if not found.}

ReferenceAlias Function Native_OutfitSlot_GetAliasForSlot(Int slotIdx) Global Native
{Resolve the "OutfitSlotNN" alias for the given slot index (0-49). Returns None if slot index is out of range or the alias doesn't exist in the ESP.}

Actor[] Function Native_Outfit_GetActorsWithPresets() Global Native
{Return all actors with at least one user-named preset in the native OutfitDataStore. Used by the slot-system migration to catch presets stored only in the native store (not StorageUtil mirror).}

Int Function Native_Outfit_GetPresetCount(Actor akActor) Global Native
{Count of user-named presets for an actor in the native OutfitDataStore (filters out internal _* presets).}

String Function Native_Outfit_GetPresetNameAt(Actor akActor, Int idx) Global Native
{Get a preset name by filtered index. Use with Native_Outfit_GetPresetCount for iteration. Returns empty string if idx out of range.}

Function Native_OutfitSlot_Log(String msg) Global Native
{Log a message to SeverActionsNative.log with an [OutfitSlot] prefix. Use alongside or instead of Debug.Trace for users without Papyrus logging enabled.}

; =============================================================================
; GUARDIAN CONTAINER REGISTRY
; For compat with custom followers (e.g. Daegon) whose mods include a guardian
; alias that enforces a container-backed outfit. When a guardian container is
; registered for an actor, the slot system empties it to the satchel before
; applying a preset (so the guardian alias's GetItemCount check fails), and
; restores contents on clear.
; =============================================================================

Bool Function Native_OutfitSlot_AddGuardian(Actor akActor, ObjectReference guardianContainer) Global Native
{Register a guardian container for an actor. Returns true if newly added, false if already registered or actor has no slot.}

Function Native_OutfitSlot_RemoveGuardian(Actor akActor, ObjectReference guardianContainer) Global Native
{Unregister a guardian container.}

ObjectReference[] Function Native_OutfitSlot_GetGuardians(Actor akActor) Global Native
{List all registered guardian containers for an actor.}

Function Native_OutfitSlot_SetStowedItems(Actor akActor, ObjectReference guardianContainer, Form[] items) Global Native
{Record which items were stowed from a guardian container (so we know what to restore on clear).}

Form[] Function Native_OutfitSlot_GetStowedItems(Actor akActor, ObjectReference guardianContainer) Global Native
{Retrieve the list of items currently stowed from a guardian container.}

Function Native_OutfitSlot_ClearStowedItems(Actor akActor, ObjectReference guardianContainer) Global Native
{Clear the stowed items list for a guardian (after successful restore).}
