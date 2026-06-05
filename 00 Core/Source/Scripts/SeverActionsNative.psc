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

Bool Function IsGoldName(String itemName) Global Native
{Case-insensitive check for "gold", "septim(s)", "coin(s)", "gold piece(s)", etc.
Use when an LLM-supplied item name needs to be routed to gold-special-case handling.}

Form[] Function FindValuableItems(ObjectReference akContainer, Int minValue = 50) Global Native
{Return all items in container with gold value >= minValue. Default threshold is 50.}

Int Function ProcessLoot(Actor akActor, ObjectReference akSource, String itemsToTake, Int maxItems = 30) Global Native
{Transfer items from a source ref to an actor based on a loot-request string.
Modes: "all" / "everything", "valuables" / "valuable", "gold" / "septims" / "money",
or a comma-separated list of specific item names. Returns the count of stacks moved.
Reads the human-readable description and last form/count via GetLastLootDescription /
GetLastLootedForm / GetLastLootedCount.}

String Function GetLastLootDescription() Global Native
{Description of the most recent ProcessLoot transfer (e.g. "Iron Sword, Gold x12").}

Form Function GetLastLootedForm() Global Native
{Last form moved by ProcessLoot — single-slot. None if the last call moved nothing.}

Int Function GetLastLootedCount() Global Native
{Count of the last form moved by ProcessLoot.}

ObjectReference Function GetMerchantContainer(Actor akMerchant) Global Native
{Resolve the merchant chest for an actor by walking their factions.
Returns the first vendor faction's merchantContainer, or None if the actor
isn't a vendor. Results are cached for 5 seconds per actor FormID.}

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
; HOLD RESOLVER + JAILED NPC STORE — MOVED TO SeverActionsNativeExt (PR-A / PR-B)
; The main class is at the ~511-function VM limit; adding more here marks the
; whole class invalid. See SeverActionsNativeExt.psc for the declarations.
; =============================================================================

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

Bool Function RegisterSandboxUser(Actor akActor, Package akPackage, Float autoStandDistance = 500.0) Global Native
{Register an actor with a sandbox package for automatic cleanup. Returns True on
 success. The return type MUST match SandboxManager.cpp's Papyrus_RegisterSandboxUser
 (bool) — a void/bool mismatch makes SKSE refuse to bind the native at load.}

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

; =============================================================================
; PRE-FLIGHT REACHABILITY (alandtse v4.4+ — Actor::CanNavigateToPosition)
; Use BEFORE BeginTravel/StartTracking. Drops unreachable destinations up front
; instead of burning the full stuck-escalation cycle (9s → 18s → 30s) on a
; destination that was never reachable.
; =============================================================================

; =============================================================================
; TRAVEL-ABORT SIGNAL (alandtse v4.4+ — combined degraded-state check)
; Poll alongside Stuck_CheckStatus. Returns true if continued travel monitoring
; is wasted work (actor is dead, in killmove, on a mount, summoned, etc.) —
; caller should Stuck_StopTracking and cancel any ArrivalMonitor entry.
; =============================================================================

; =============================================================================
; GRACEFUL GIVE-UP RECOVERY (alandtse v4.4+ — TESObjectREFR::MoveToEditorLocation)
; Alternative to escalation-level-3 force-teleport-to-destination. When the
; destination itself has broken navmesh (actor would be stranded after teleport),
; sending them back to their editor-defined home location is more deterministic.
; =============================================================================

; NOTE: TravelOrchestrator natives (Travel_*) live in SeverActionsNativeExt
; for the same 511-function-limit reason as Craft_* / Heal_* / Cell_*.
; See SeverActionsNativeExt.psc for the full declaration set.
; Callers invoke via SeverActionsNativeExt.Travel_Begin(...) etc.

; NOTE: Crafting orchestrator natives (Craft_*) live in SeverActionsNativeExt,
; not here — the main class is at the 511-function VM limit and overflowing
; silently breaks every native on the class. See SeverActionsNativeExt.psc.

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

; alandtse v4.4+ — LOS-aware arrival mode. Distance ≤ threshold isn't enough;
; the actor must also have unobstructed Actor::CalculateLOS to the destination
; position. Catches actors who are geometrically close but on the wrong side
; of a wall, on a different floor, or behind a closed door. Use for interior
; destinations where distance-only false-positives wrong-side arrivals.
;
; Skips the LOS check when the actor isn't 3D-loaded (falls back to distance
; behaviour for that tick — LOS resumes on next tick when actor reloads).

; =============================================================================
; GUARD FINDER
; Fast native search for nearby guard actors
; =============================================================================

Actor Function FindNearestGuard(Actor akNearActor, Float searchRadius = 3000.0) Global Native
{Find the nearest guard actor within searchRadius units of akNearActor. Returns None if no guard found.}

Actor Function FindNearestGuardWithLOS(Actor akNearActor, Float searchRadius = 3000.0) Global Native
{Wave 3 / CommonLib v4.14+: prefer a guard that has clear line of sight to
 akNearActor — eliminates the "guard around the corner who has to pathfind
 through a building" failure mode. Falls back to FindNearestGuard if no
 LOS-having guard is in range, so this never returns null where the no-LOS
 variant would have succeeded.}

Bool Function Native_MoveToNearestNavmesh(ObjectReference akRef, Float minOffset = 0.0) Global Native
{Wave 3: snap a reference to the nearest navmesh cell. Replaces the
 Disable/Enable hack in arrest's OnArrivedAtJail and post-leapfrog teleport
 cleanup. Returns true if the snap succeeded.}

Bool Function Native_IsActorInScene(Actor akActor) Global Native
{Wave 8: returns true if the actor is currently bound to a vanilla scripted
 BGSScene. Scene-bound actors ignore script package overrides, so the arrest
 entry points refuse to start when this returns true and instead bail with
 a debug notification — issuing the arrest while a scene runs would silently
 no-op and leave the FSM hung.}

Int Function Native_GetActorProcessLevel(Actor akActor) Global Native
{Wave 3: return AI process tier — 3=High, 2=MidHigh, 1=MidLow, 0=Low, -1=None.
 Caller refuses to issue arrest commands against actors at tier <=0; they
 aren't loaded into AI processing, so packages won't actually run on them.
 Registered by the DLL via GuardFinder::RegisterFunctions on the main
 SeverActionsNative class — moved here from SeverActionsNativeExt.psc to
 match. Callers should use `SeverActionsNative.Native_GetActorProcessLevel`.}

Function Native_SetActorArrested(Actor akActor, Bool arrested) Global Native
{Wave 8: toggle the engine-native AIProcess::IsArrested bit. Set true when
 our session opens (PerformArrest), false on completion or cancellation.
 Lets vanilla guards / Acheron / other arrest-aware mods recognize the
 suspect as in-custody — without this, the Wave 4 ArrestSessionStore is
 purely script-side and the rest of Skyrim's law-enforcement pipeline
 doesn't see the apprehension.}

Bool Function Native_IsActorArrested(Actor akActor) Global Native
{Wave 8: read the engine-native arrest flag. Useful for cross-mod arrest
 detection (was this actor arrested by us OR by vanilla guards OR by
 Acheron / etc.).}

; =============================================================================
; ARREST SESSION STORE (Wave 4)
; Native cosave-backed tracking of in-flight arrests with per-state game-time
; timeout watchdog. Fires the SeverActions_ArrestSessionTimeout mod event when
; a session exceeds its threshold so Papyrus can cancel-and-clean.
;
; State enum mirrors the Papyrus side:
;   1=Approach  2=Arresting  3=Escort  4=Arrived
;   5=Dispatch  6=Judgment   7=Persuasion
; =============================================================================

Function Native_ArrestSession_Begin(Actor akPrisoner, Actor akGuard, ObjectReference akJailMarker, Faction akCrimeFaction, Int aiState, Int aiDispatchPhase, Int aiFlags) Global Native
{Open a new arrest session keyed on the prisoner. Replaces any existing entry.}

Function Native_ArrestSession_EnsureBegin(Actor akPrisoner, Actor akGuard, ObjectReference akJailMarker, Faction akCrimeFaction, Int aiState, Int aiDispatchPhase, Int aiFlags) Global Native
{Begin-if-missing / update-if-exists. Use this on handoff points where the
 previous phase may have closed the session (judgment→escort) and the next
 phase still needs a tracked record. Refreshes the per-state transition timer.}

Function Native_ArrestSession_UpdateState(Actor akPrisoner, Int aiNewState, Int aiNewDispatchPhase) Global Native
{Update the state of an existing session. Resets the per-state transition timer
 so a phase change buys fresh time on the watchdog. No-op if no session exists —
 use Native_ArrestSession_EnsureBegin if you need recreate-on-handoff semantics.}

Function Native_ArrestSession_End(Actor akPrisoner) Global Native
{Close the arrest session for this prisoner. Idempotent — safe to call
 unconditionally on every cleanup path.}

Function Native_ArrestSession_EndAll() Global Native
{Close every active arrest session. For new-game / nuclear cleanup paths.}

Bool Function Native_ArrestSession_HasSession(Actor akPrisoner) Global Native
{Returns true if a session is currently tracked for this prisoner.}

Int Function Native_ArrestSession_GetCount() Global Native
{Total number of active arrest sessions across the load.}

Int Function Native_ArrestSession_GetState(Actor akPrisoner) Global Native
{Returns the state enum value (1..7) for the prisoner's session, or 0 if
 not tracked.}

Float Function Native_ArrestSession_GetAgeHours(Actor akPrisoner) Global Native
{Returns the in-game elapsed hours since the session started, or 0 if not tracked.}

Function Native_ArrestSession_CaptureAVs(Actor akPrisoner, Float afAggression, Float afConfidence) Global Native
{Capture the prisoner's pre-arrest Aggression / Confidence on the active
 ArrestSession entry, so RestorePrisonerStats can put them back on release.
 Replaces the legacy StorageUtil "SeverArrest_OrigAggression" / "_OrigConfidence"
 keys. Idempotent — only sets each field when it still holds the sentinel
 -1.0, so a double-PerformArrest call won't clobber the original values
 with the zeroes that PerformArrest is about to write.}

Float Function Native_ArrestSession_GetOrigAggression(Actor akPrisoner) Global Native
{Returns the captured pre-arrest Aggression for this prisoner, or -1.0 if
 no session exists / capture never happened (legacy save migrated mid-arrest,
 or capture lost across the v1→v2 cosave bump).}

Float Function Native_ArrestSession_GetOrigConfidence(Actor akPrisoner) Global Native
{Returns the captured pre-arrest Confidence for this prisoner, or -1.0 if
 no session exists / capture never happened.}

; ─────────────────────────────────────────────────────────────────────────────
; PERSUASION MONITOR (Phase 2.2)
; Replaces SeverActions_ArrestPlayer.CheckPersuasionProgress's 1Hz OnUpdate
; tick. Native side checks timeout / distance / death once per real second,
; fires the SeverActions_PersuasionFailed ModEvent with a reason string
; ("timeout", "distance", or "died") when any trip fires.
; ─────────────────────────────────────────────────────────────────────────────

Function Native_Persuasion_Begin(Actor akGuard, Actor akPlayer, Float afTimeLimitSec, Float afDistanceLimit) Global Native
{Begin tracking a persuasion attempt. Single-active: a subsequent Begin
 overwrites the previous entry. Time limit is in real seconds; distance
 limit is in Skyrim units (matches PersuasionFollowDistance default of 1500).
 Call Native_Persuasion_End on every persuasion exit path.}

Function Native_Persuasion_End() Global Native
{Clear the active persuasion entry. Idempotent — safe to call from every
 persuasion exit path (success, reject, fail, cancel).}

Bool Function Native_Persuasion_IsActive() Global Native
{Returns true if the native monitor still holds an active persuasion entry.
 Diagnostic / sanity-check use only — Papyrus owns the canonical
 InPersuasionMode flag.}

; ─────────────────────────────────────────────────────────────────────────────
; BRAWL CHALLENGE MONITOR
; ─────────────────────────────────────────────────────────────────────────────
; Heartbeat tick for NPC↔NPC brawl-challenge wait. Multiple concurrent
; pending challenges supported (different tavern brawls in different cells),
; keyed by challenger FormID. Fires SeverActions_BrawlChallengeExpired
; (sender = target, strArg = "timeout"|"died"|"distance") when a wait ends
; without the target picking Accept/Decline.

Function Native_BrawlChallenge_Begin(Actor akChallenger, Actor akTarget, Float afTimeLimitSec, Float afDistanceLimit) Global Native
{Start tracking a pending brawl challenge. Call from SeverActions_Brawl on
 NPC↔NPC ChallengeBrawl. The native tick will resolve the wait via the
 SeverActions_BrawlChallengeExpired ModEvent if Accept/Decline doesn't come
 in time.}

Function Native_BrawlChallenge_End(Actor akChallenger) Global Native
{Clear the active challenge entry keyed by this challenger. Call on Accept,
 Decline, or successful Brawl_Begin. Idempotent.}

Function Native_BrawlChallenge_EndForActor(Actor akActor) Global Native
{Clear any pending challenge entry where this actor is either challenger or
 target. Used when a brawl actually begins (both sides leave the wait state).}

Bool Function Native_BrawlChallenge_IsActive(Actor akChallenger) Global Native
{True iff there's a pending challenge with this actor as challenger.}

Actor Function Native_BrawlChallenge_GetLastExpiredChallenger() Global Native
{The challenger of the most-recently-expired challenge. Set by the native
 monitor inside CheckAll before SeverActions_BrawlChallengeExpired fires.
 Papyrus OnChallengeExpired reads this so it can clean up the follow package
 on the challenger even if the StorageUtil ChallengeFrom key was cleared.}

; ─────────────────────────────────────────────────────────────────────────────
; PRISMAUI BRAWL PROMPT BRIDGE
; ─────────────────────────────────────────────────────────────────────────────
; Non-pausing PrismaUI HUD card for the player-target brawl challenge popup.
; Replaces SkyMessage when PrismaUI is installed. Pattern mirrors PR #146's
; CollectPayment overlay.
;
; Open flow: Papyrus calls PrismaUI_OpenBrawlPrompt(challenger, name, ms).
; Player clicks Accept or Decline (or 60s timeout auto-declines). C++ fires
; SeverActions_BrawlChallengeChoice ModEvent (strArg = "accept"|"decline",
; sender = challenger). SeverActions_Brawl.OnBrawlPromptChoice dispatches
; to AcceptBrawl_Execute / DeclineBrawl_Execute on the player's behalf.

Bool Function PrismaUI_OpenBrawlPrompt(Actor akChallenger, String asChallengerName, Int aiTimeoutMs) Global Native
{Show the brawl challenge popup. Returns true if the overlay opened — caller
 waits for SeverActions_BrawlChallengeChoice. Returns false if PrismaUI isn't
 ready / another view has focus / another prompt is already open; caller
 should fall back to SkyMessage.}

Function PrismaUI_CloseBrawlPrompt() Global Native
{Dismiss any open brawl prompt without firing a choice. Used on player-load
 cleanup. Safe to call when nothing's open.}

Bool Function PrismaUI_IsBrawlPromptOpen() Global Native
{True iff the brawl prompt is currently showing.}

Bool Function PrismaUI_IsBrawlPromptAvailable() Global Native
{True iff the bridge has acquired the PrismaUI API and the view is DOM-ready.
 Check before calling PrismaUI_OpenBrawlPrompt to know whether the overlay
 path is usable in this load order.}

; ─────────────────────────────────────────────────────────────────────────────
; PRISMA UI ARREST PROMPT
; Non-pausing HUD card replacing the SkyMessage.Show chain in
; SeverActions_ArrestPlayer.ShowPlayerArrestMenu. Buttons are rendered
; dynamically based on the (lowBounty, paymentFailed, persuadeAttempted)
; state triple — frontend mirrors the Papyrus branching logic exactly.
;
; Open flow: Papyrus calls PrismaUI_OpenArrestPrompt(guard, name, hold,
;   bounty, bribeCost, paymentFailed, persuadeAttempted, lowBounty, ms).
; Player clicks one of up to 4 buttons (or 60s timeout / Escape auto-fires
; "submit"). C++ fires SeverActions_ArrestPromptChoice ModEvent
;   (strArg = "pay_fine"|"submit"|"resist"|"bribe"|"persuade",
;    sender  = guard, numArg = bounty).
;
; SeverActions_ArrestPlayer subscribes to that ModEvent and routes to the
; matching Handle*() function.

Bool Function PrismaUI_OpenArrestPrompt(Actor akGuard, String asGuardName, \
    String asHoldName, Int aiBounty, Int aiBribeCost, \
    Bool abPaymentFailed, Bool abPersuadeAttempted, Bool abLowBounty, \
    Int aiTimeoutMs) Global Native
{Show the arrest prompt overlay. Returns true if the overlay opened — caller
 waits for SeverActions_ArrestPromptChoice. Returns false if PrismaUI isn't
 available, another prompt is open, or another view has focus — caller falls
 back to SkyMessage.Show.}

Function PrismaUI_CloseArrestPrompt() Global Native
{Close the arrest prompt without firing a choice event. Caller uses this when
 the underlying confrontation has been cancelled out-of-band (guard died,
 player fled, etc.).}

Bool Function PrismaUI_IsArrestPromptOpen() Global Native
{True iff the arrest prompt is currently showing.}

Bool Function PrismaUI_IsArrestPromptAvailable() Global Native
{True iff the bridge has acquired the PrismaUI API and the view is DOM-ready.
 Check before calling PrismaUI_OpenArrestPrompt to know whether the overlay
 path is usable in this load order.}

; ─────────────────────────────────────────────────────────────────────────────
; RESIST ARREST MONITOR (Phase 2.1)
; Replaces the post-resist OnUpdate poll in SeverActions_ArrestPlayer.psc.
; Native side sinks TESCombatEvent — the moment the player transitions to
; ACTOR_COMBAT_STATE::kNone, we fire SeverActions_ResistCombatEnded with
; reason="combatEnd". A 10-minute (configurable) real-time watchdog fires
; the same event with reason="timeout" if the engine combat flag never
; clears (B16 combat-lockout safety net). The Papyrus handler owns the
; faction handle and bounty re-absorption logic.
; ─────────────────────────────────────────────────────────────────────────────

Function Native_Resist_Begin(Float afMaxWaitSeconds) Global Native
{Begin tracking post-resist combat-end. Single-active — a subsequent Begin
 resets the watchdog clock. afMaxWaitSeconds is the watchdog budget for
 combat-lockout fallback (default 600s).}

Function Native_Resist_End() Global Native
{Clear the active resist-tracking entry. Idempotent.}

Bool Function Native_Resist_IsActive() Global Native
{Returns true if the native monitor still holds an active resist entry.}

; ─────────────────────────────────────────────────────────────────────────────
; ESCORT PACKAGE REAPPLIER (Phase 2.3a)
; Eliminates the per-tick AddPackageOverride re-apply in CheckEscortProgress.
; Native sinks TESCellAttachDetachEvent + TESCombatEvent (state→kNone) on
; the active guard+prisoner pair and fires SeverActions_EscortReapplyPackages
; ModEvent when the package needs reasserting. Papyrus handler does the
; AddPackageOverride + EvaluatePackage on both actors.
; ─────────────────────────────────────────────────────────────────────────────

Function Native_EscortReapply_Begin(Actor akGuard, Actor akPrisoner) Global Native
{Begin tracking the escort pair. Subsequent Begin overwrites the previous
 entry (single-active). Call from PerformArrest / StartEscortPhase.}

Function Native_EscortReapply_End() Global Native
{Clear the active escort-tracking entry. Idempotent — safe to call from
 every escort exit path (OnArrivedAtJail, CancelCurrentArrest, etc.).}

Bool Function Native_EscortReapply_IsActive() Global Native
{Diagnostic — returns true if the native side is still tracking.}

Function Native_Arrest_Log(String msg) Global Native
{Log a message to SeverActionsNative.log with an [Arrest] prefix. Mirrors
 Native_OutfitSlot_Log — use alongside or instead of Debug.Trace for users
 without Papyrus logging enabled. Centralizes arrest-subsystem diagnostics
 into the SKSE log so they can be inspected without enabling bPapyrusLog.}

; =============================================================================
; SKYRIMNET v6+ ACTOR BUSY STATE
; Drives the is_busy / busy_reason decorators that gate action eligibility.
; Use this to block all SkyrimNet action selection on an actor for the
; duration of a multi-step operation (arrest, escort, judgment) — including
; actions defined by unrelated plugins, which our own faction-based filters
; cannot reach. Returns false if the v6 PublicAPI isn't available (older
; SkyrimNet); callers should treat that as a soft-fail rather than a fatal.
; =============================================================================

Bool Function Native_SkyrimNet_SetActorBusy(Actor akActor, String asReason) Global Native
{Mark an actor as busy with a multi-step action. asReason is queryable via
 the busy_reason() decorator (e.g. "arrest", "crafting", "travel").}

Bool Function Native_SkyrimNet_ClearActorBusy(Actor akActor) Global Native
{Clear an actor's busy state. Idempotent — safe to call when not busy.}

Bool Function Native_SkyrimNet_IsActorBusy(Actor akActor) Global Native
{Query whether an actor is currently busy.}

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

Function PrismaUI_SetYieldPromptEnabled(Bool enabled) Global Native
{Set whether the yield/surrender combat-prompt guidance is exposed. Pushes the \
StorageUtil-persisted value to the C++ atomic the settings gather reads. The \
0160 combat prompt reads the StorageUtil(None) mirror directly.}

Bool Function PrismaUI_IsPauseOnOpen() Global Native
{Return the current pause-on-open setting from C++.}

; ── PrismaUI Data Builder ───────────────────────────────────────────
; C++ JSON builder — call these instead of Papyrus string concatenation.
; nlohmann_json produces correct booleans (true/false), escaped strings, etc.

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

; ── Collect Payment prompt (non-pausing HUD overlay) ─────────────────────────
; Wired to PrismaUICollectPaymentBridge — replaces the SkyMessage.Show modal
; that the CollectPayment action used to ask "Lydia is requesting 75 gold.
; Pay them? Yes / No / No (Silent)". Game keeps running, NPC AI keeps ticking,
; visible drain bar at the bottom auto-accepts on expiry. The player's choice
; (or auto-accept) arrives back via the SeverActions_CollectPaymentChoice
; ModEvent — handlers receive strArg=("accept"|"deny"|"denySilent"),
; numArg=amount, sender=collectorActor.

Bool Function PrismaUI_OpenPaymentPrompt(Actor akCollector, Int aiAmount, String asCollectorName, Int aiTimeoutMs) Global Native
{Open the non-pausing payment-prompt overlay. Returns True if the overlay was \
shown (caller waits for SeverActions_CollectPaymentChoice ModEvent), False if \
the bridge is unavailable, another prompt is already open, or another PrismaUI \
view has focus. Caller should fall back to SkyMessage on False. timeoutMs <= 0 \
defaults to 20000 (20s).}

Function PrismaUI_ClosePaymentPrompt() Global Native
{Dismiss the payment prompt without firing a choice. Used by external "cancel \
this in-flight prompt" paths. No ModEvent fires — caller treats absent \
SeverActions_CollectPaymentChoice as "no payment occurred."}

Bool Function PrismaUI_IsPaymentPromptOpen() Global Native
{Returns True while the payment-prompt overlay is currently displayed.}

Bool Function PrismaUI_IsPaymentPromptAvailable() Global Native
{Returns True if the bridge is initialized AND the view has finished its DOM- \
ready handshake. Check before calling PrismaUI_OpenPaymentPrompt to know \
whether to take the PrismaUI path or fall back to SkyMessage.}

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

Function OrphanCleanup_SetArrestKeywords(Keyword arrestFollowKW, Keyword arrestSandboxKW) Global Native
{Register arrest LinkedRef keywords (FollowTargetKW + SandboxAnchorKW) with the
 orphan scanner. Scan fires SeverActions_OrphanCleanup mod event with strArg
 "arrest_follow" or "arrest_sandbox"; the SeverActions_Arrest.psc OnOrphanCleanup
 handler filters via faction membership before deciding to clean up.}

Function OrphanCleanup_SetArrestFactions(Faction dispatchFaction, Faction waitingArrestFaction, Faction arrestedFaction, Faction jailedFaction) Global Native
{Register arrest factions for stale-membership sweep. Catches actors stuck in
 dispatch Phase 1 (Travel) or any path that sets a faction tag *before* applying
 a LinkedRef package — without this sweep, the keyword-only orphan scan would
 miss those actors and the action YAML eligibility filter
 `is_in_faction(SeverActions_DispatchFaction) == false` would lock the speaker
 out of every arrest action permanently. Scan fires SeverActions_OrphanCleanup
 mod event with strArg "arrest_faction_sweep" for any actor in any of the four
 factions; the OnOrphanCleanup handler in SeverActions_Arrest.psc then runs the
 same active-state filter (FSM slots + native session) and scrubs stale
 memberships when no live arrest matches.}

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

; Native_EvaluateActorPackage moved to SeverActionsNativeExt.psc — the DLL
; registers it under SeverActionsNativeExt (SpellCastManager lives there
; because of the 511-function-limit workaround). Declaring it here used
; to throw a "could find no matching static function on linked type
; SeverActionsNative" error at load.

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

; =============================================================================
; HOME BED AUTO-ASSIGNMENT
; When a follower is assigned a home cell, scan the cell for a usable bed and
; SetActorOwner to the follower so their sleep package finds it during sleep
; hours. Releases on home reassignment / dismiss. Cosave-persisted via
; FollowerDataStore (v7+).
; =============================================================================

Bool Function Native_BedAssignment_Claim(Actor akActor) Global Native
{Try to claim a bed for the follower in their CURRENT parent cell. Returns
 true if a bed was claimed. Releases any previous bed claim first. Skips
 beds owned by specific named NPCs and PlayerFaction; claims unowned and
 inn/generic-faction-owned beds.}

Function Native_BedAssignment_Release(Actor akActor) Global Native
{Release the follower's currently assigned bed (restores original owner).
 Safe to call with no assignment (no-op).}

Int Function Native_BedAssignment_GetBedFormID(Actor akActor) Global Native
{Returns the FormID of the currently assigned bed, or 0 if none.}

; =============================================================================
; AMBIENT NPC BANTER SCANNER
; Find non-follower / non-player NPC pairs near the player who could
; spontaneously banter. Hostile-cell guard returns 0 if any nearby actor is
; hostile to the player (skips dungeons, bandit camps, under-attack settlements).
; =============================================================================

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

; Native_GetPairBlurb lives on SeverActionsNativeExt to avoid pushing this
; class against the 511-function-per-class Papyrus VM ceiling. See ext file.

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

; --- Phase 1/2/4/5 outfit-migration scalars + DressStash moved to
;     SeverActionsNativeExt to keep us under the ~511-function-per-script
;     Papyrus VM limit. See SeverActionsNativeExt.psc for declarations.
;     All Papyrus callers reference SeverActionsNativeExt.Native_Outfit_* now.

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

Function Native_Survival_AdjustNeeds(Actor akActor, Float hungerDelta, Float fatigueDelta, Float coldDelta) Global Native
{Read-modify-write needs by signed deltas. Negative = reduce need (good — actor is
 being fed / rested / warmed). Output clamped 0–100. Public API exposed for
 external mods (camp restoration, future furniture restoration, etc.).}

Function PrismaUI_SetPinnedRestStop(String label) Global Native
{Set the dashboard "pinned rest stop" label. Empty string clears the pin. The
 entry point for external callers (camp, bedroll, etc.) to surface a "where
 you'll rest next" hint without the menu being open.}

Function PrismaUI_SetCampStatus(Bool active, String location, Int occupants) Global Native
{Set the camp-status indicator surfaced on the Survival page header.
 Called by external mods (SeversHearth on Establish/Break). occupants is the
 total count including the player. Pass `active=false` to clear. Renders as
 a "🏕 At Camp · N resting · <location>" badge while active.}

; NOTE: PrismaUI_SetCampMeta / SetCampThreats / SetCampMarked live in
; SeverActionsNativeExt (same 511-limit reason as Travel_* / Craft_*).
; Callers (SeversHearth_Camp.psc) invoke via SeverActionsNativeExt.PrismaUI_SetCamp*.
; The older PrismaUI_SetPinnedRestStop + PrismaUI_SetCampStatus stay here
; because they're already in wide use and migrating them would mean rebuilding
; saves; the new three are fresh adds with no live callers in saved games.

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

Function Native_Survival_MarkFed(Actor akActor) Global Native
{Stamp lastFedGameTime in the native store. Called from EatFood / OnFollowerAteFood
 so the PrismaUI Survival care sheet can show "fed N hours ago".}

; =============================================================================
; PROMPT AVAILABILITY — File-system check for shipped .prompt files
; Scanned once at kDataLoaded by C++ PromptAvailability::Scan(); cached in
; an unordered_map for O(1) lookup. Call from EVERY SendCustomPromptToLLM
; site so missing FOMOD modules don't generate failed LLM calls.
; =============================================================================

Bool Function Native_IsPromptAvailable(String promptName) Global Native
{True if Data\SKSE\Plugins\SkyrimNet\prompts\<promptName>.prompt was found
 at game load. Use as the first guard before SkyrimNetApi.SendCustomPromptToLLM
 so missing FOMOD modules silently skip rather than logging errors.}

Function Native_Survival_InitNearby(Actor akActor) Global Native
{Initialize or drift nearby NPC survival values in native store (C++ randomization).}

Float Function Native_Survival_GetNearbyHunger(Actor akActor) Global Native
{Read nearby NPC hunger from native store.}

Float Function Native_Survival_GetNearbyFatigue(Actor akActor) Global Native
{Read nearby NPC fatigue from native store.}

Float Function Native_Survival_GetNearbyCold(Actor akActor) Global Native
{Read nearby NPC cold from native store.}

; ── Situation Monitor ──

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

Bool Function Native_OffScreen_RequestLifeEventLLM(Actor akActor, String contextJson, Float gameTime) Global Native
{Send the off-screen life prompt to SkyrimNet's v8 C++ LLM API (PublicSendCustomPromptToLLM). \
Bypasses Papyrus's 1024-char BSFixedString cap on responses by keeping the full LLM \
response in std::string all the way to the parser — required after the prompt added \
`rumorText` alongside `summary` per event. Fires SeverActions_OffScreenLifeReady ModEvent \
when parsing completes. Returns true if the request was queued, false if SkyrimNet v8 \
PublicSendCustomPromptToLLM API isn't available.}

String Function Native_OffScreen_BuildContext(Actor akActor, Bool consequencesEnabled, Float consequenceCooldownSec, Float lastConsequenceGT, Float currentGameTime) Global Native
{Build the full context JSON for the off-screen life LLM prompt natively in C++. \
Reads home from FollowerDataStore, queries social graph from SkyrimNet PublicAPI, \
finds nearby dismissed followers in the same hold, and checks consequence eligibility. \
Returns a properly serialized JSON string ready for SendCustomPromptToLLM, or empty on failure.}

String Function Native_OffScreen_GetRecentLifeEvents(Actor akActor, Int maxEvents, Float currentGameTime) Global Native
{Returns formatted life events for prompt injection from the native cosave store. \
Each line: "- [time ago] summary [type] (with NPC)". Newest first, up to maxEvents (0=all). \
Returns empty string if no events exist for this actor.}

Float Function Native_OffScreen_GetCooldownOverride(Actor akActor) Global Native
{Per-NPC off-screen life cooldown override in game-hours. 0 = no override (use global min/max window).}

Function Native_OffScreen_SetCooldownOverride(Actor akActor, Float hours) Global Native
{Set per-NPC off-screen life cooldown override in game-hours. Pass 0 to clear and fall back to the global window.}

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

Bool Function Native_IsCellOwner(Actor akSpeaker, String propertyName) Global Native
{True if akSpeaker is the owner of the named cell — either directly \
(actor base matches cell.GetActorOwner) or via faction membership \
(speaker is in cell.GetFactionOwner). Empty propertyName falls back \
to speaker's current parent cell. False if cell can't be resolved or \
has no owner. Use as a guard before TransferOwnership so the LLM \
can't have an NPC give away a building they don't actually own \
(issue #12 public — Maven shouldn't be able to transfer Haelga's \
Bunkhouse).}

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

; Native_StorePendingSummary REMOVED. The C++ side no longer stashes routing
; metadata in a FIFO across the Pop → SendCustomPromptToLLM → callback round-
; trip — early returns in the legacy Papyrus pump used to leak metadata and
; misroute later responses. Papyrus now reads its own routing fields out of
; the JSON returned by Native_PopSummaryRequest and calls Native_SetQuestSummary
; directly. On SkyrimNet v8+ the C++ side dispatches the LLM call itself and
; this whole pump path stays dormant.

Function Native_SetQuestSummary(Actor akActor, String editorID, String summary, Bool isFirsthand) Global Native
{Store an LLM-generated personalized quest summary for a follower. \
Called from Papyrus after SendCustomPromptToLLM returns the summary text.}

Function Native_OnFollowerRecruited(Actor akActor) Global Native
{Notify the quest awareness store that a follower was recruited. \
Seeds SECONDHAND awareness of all active tracked quests and queues catch-up summaries. \
Call from RegisterFollower() in FollowerManager.}

Actor Function Native_PopReputationAssessRequestActor() Global Native
{Pop the next NPC queued for reputation assessment. \
Returns the Actor reference, or None when the queue is empty. \
C++ enqueues from the player_familiarity decorator when a blurb milestone fires \
(first dialogue or every +100 lines, owned by FamiliarityStore); Papyrus drains \
the queue one at a time via the SeverActions_ReputationAssess ModEvent and \
SendCustomPromptToLLM("sever_reputation_assess"). \
Returns Actor directly (rather than FormID-as-int) to dodge Papyrus's signed-int \
sign-extension on ESL / high-mod-index plugin FormIDs.}

Int Function Native_GetFollowerAwarenessTier(Actor akActor, String editorID) Global Native

Function Native_QuestAwareness_SetOutputCap(Int n) Global Native
{Set the cap on quest awareness entries emitted to the prompt per follower. \
Clamped to 1-15. Storage cap (per-follower max retained quests) is unaffected — \
this only controls how many entries the LLM sees per render. Default 5.}

Int Function Native_QuestAwareness_GetOutputCap() Global Native
{Return the current quest awareness output cap. Default 5.}

Function Native_QuestAwareness_MarkMemorized(Actor akActor, String questEditorID) Global Native
{Mark a follower's quest awareness entry as memorized — the canonical KNOWLEDGE/\
EXPERIENCE memory has been created in SkyrimNet. The decorator stops emitting \
this entry to the prompt; storage retains it for cap-eviction preference and \
save/load resilience. Idempotent.}

; ── User filter layer (v4+) ──
; Three-tier resolution: userAllow > userDeny > hardcoded defaults. Editor IDs
; are matched case-insensitively. Filters persist via cosave.

Function Native_QuestAwareness_FilterDeny(String editorID) Global Native
{Permanently deny a quest from appearing in any follower's awareness, \
overriding the hardcoded default. Retroactively purges all existing awareness \
entries for this editorID across all followers.}

Function Native_QuestAwareness_FilterAllow(String editorID) Global Native
{Permanently allow a quest to appear in awareness, overriding the hardcoded \
denylist (Skyshards, IntelEngine, etc.). Future stage events will populate \
naturally — no retroactive seeding.}

Function Native_QuestAwareness_FilterClear(String editorID) Global Native
{Remove this quest from both allow and deny lists, returning to default behavior.}

Int Function Native_QuestAwareness_FilterState(String editorID) Global Native
{Return the current filter state for this editor ID: \
0 = default, 1 = explicitly allowed, 2 = explicitly denied.}

Function Native_QuestAwareness_RemoveQuest(Actor akActor, String editorID) Global Native
{Surgical per-follower remove. Drops one quest entry from one follower's \
awareness without touching global filters or any other follower's data.}

String Function Native_QuestAwareness_ListAll() Global Native
{Return a JSON array of all (follower, quest) awareness entries for UI display. \
Each entry has actorFid, actorName, editorID, questName, questType, isFirsthand, \
isMemorized, and filter state (0/1/2). Capped at 200 entries.}

String Function Native_QuestAwareness_ListForActor(Actor akActor) Global Native
{Per-follower variant of ListAll — returns only akActor's awareness rows. \
Powers the Companions page Quest Awareness sub-tab.}

; =============================================================================
; SITUATION MONITOR
; =============================================================================

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

; ============================================================================
; HEALER POLL + CELL CATCHUP natives MOVED to SeverActionsNativeExt.psc
; ============================================================================
; Skyrim's Papyrus VM has a hard ~511-function limit per script class. This
; class previously overflowed (523 functions), causing the engine to mark
; SeverActionsNative as invalid at link time and silently fail every native
; call from it (PrismaUI_ToggleMenu, FM_Initialize, etc.).
;
; Recently-added Healer + CellCatchup natives now live on SeverActionsNativeExt
; (call as `SeverActionsNativeExt.Native_RegisterHealer(akActor)`). Future
; additions should also extend SeverActionsNativeExt or new sibling classes.
