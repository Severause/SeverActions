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
; CRAFTING DATABASE (LEGACY - JSON based)
; Superseded by RecipeDB and AlchemyDB which scan game forms directly
; Kept for backwards compatibility - functions still work if JSON is present
; =============================================================================

Bool Function LoadCraftingDatabase(String folderPath) Global Native
{LEGACY: Load JSON crafting databases. Use RecipeDB/AlchemyDB instead.}

Form Function FindCraftableByName(String itemName) Global Native
{LEGACY: Find craftable item by name from JSON. Use FindSmithingRecipe/FindCookingRecipe instead.}

Form Function FuzzySearchCraftable(String searchTerm) Global Native
{LEGACY: Fuzzy search JSON database. Native RecipeDB handles fuzzy matching automatically.}

Form Function SearchCraftableCategory(String category, String searchTerm) Global Native
{LEGACY: Search JSON category. Not needed - RecipeDB categorizes automatically.}

String Function GetCraftingDatabaseStats() Global Native
{LEGACY: Get JSON database stats.}

Bool Function IsCraftingDatabaseLoaded() Global Native
{LEGACY: Check if JSON crafting database is loaded.}

; =============================================================================
; TRAVEL DATABASE (LEGACY - JSON based)
; Superseded by LocationResolver which scans all cells/locations from game data
; Kept for backwards compatibility - functions still work if JSON is present
; =============================================================================

Bool Function LoadTravelDatabase(String filePath) Global Native
{LEGACY: Load JSON travel markers. Use LocationResolver (auto-initialized) instead.}

String Function FindCellId(String placeName) Global Native
{LEGACY: Find cell ID from JSON. Use ResolveDestination() instead.}

ObjectReference Function GetMarkerForCell(String cellId) Global Native
{LEGACY: Get marker from JSON. Use ResolveDestination() instead.}

ObjectReference Function ResolvePlace(String placeName) Global Native
{LEGACY: Resolve place name from JSON. Use ResolveDestination(actor, name) instead.}

Bool Function IsTravelDatabaseLoaded() Global Native
{LEGACY: Check if JSON travel database is loaded.}

Int Function GetTravelMarkerCount() Global Native
{LEGACY: Get JSON travel marker count. Use GetLocationCount() instead.}

; =============================================================================
; LOCATION RESOLVER (Replaces TravelDB for new travel system)
; Auto-indexes all cells and BGSLocations at game load
; Supports fuzzy matching, semantic terms (outside/upstairs), Levenshtein typo tolerance
; =============================================================================

ObjectReference Function ResolveDestination(Actor akActor, String destination) Global Native
{Resolve any destination string to a travel target.
Handles: named places, city aliases, fuzzy matching, typo tolerance,
semantic terms (outside, upstairs, downstairs, inside).
Returns None if destination cannot be resolved.}

String Function GetLocationName(String destination) Global Native
{Get the proper display name for a destination string.
Returns the original string if not found in the database.}

Bool Function IsLocationResolverReady() Global Native
{Check if the location resolver has finished indexing.}

Int Function GetLocationCount() Global Native
{Get total number of indexed locations (cells + BGSLocations).}

String Function GetLocationResolverStats() Global Native
{Get stats string: "Cells: X, Locations: Y, Aliases: Z"}

ObjectReference Function FindDoorToActorCell(Actor akActor) Global Native
{Find the exterior door leading to an actor's current interior cell.
Returns None if actor is in an exterior cell or door can't be found.
Used by guard dispatch to navigate across cell boundaries.}

String Function GetDisambiguatedCellName(Actor akActor) Global Native
{Get a disambiguated cell name for an actor's current interior cell.
For cells with generic names like "Cellar" that appear multiple times,
appends the parent location: "Cellar (Bannered Mare)".
Returns empty string if actor is not in a named interior cell.}

ObjectReference Function FindExitDoorFromCell(Actor akActor) Global Native
{Find the interior door in the actor's current cell that leads to an exterior.
Used when a guard is inside an interior and needs to exit through the door.
Returns the interior door ObjectReference, or None if not in interior or no exit found.}

ObjectReference Function FindDoorToActorHome(Actor akActor) Global Native
{Find the exterior door leading to an NPC's home cell.
Uses the pre-built home index from sleep package scanning (works for unloaded NPCs).
Returns the door ObjectReference the guard can pathfind to.
Returns None if no home cell is known or no door exists for it.}

ObjectReference Function FindHomeInteriorMarker(Actor akActor) Global Native
{Find an XMarkerHeading or XMarker inside an NPC's home cell.
Returns a reference INSIDE the home, suitable for MoveTo (direct placement).
Prefers XMarkerHeading (has facing direction) over XMarker.
Returns None if no home cell is known, home is exterior, or no markers exist.}

ObjectReference Function FindInteriorMarkerForDoor(ObjectReference doorRef) Global Native
{Find an XMarkerHeading or XMarker inside the cell a door leads to.
Follows the door's teleport link to the destination interior cell,
then scans for markers. Returns None if not a door or leads to exterior.
Use this with ResolveDestination results that are doors (GetType() == 29).}

; =============================================================================
; ACTOR FINDER
; Find NPCs by name anywhere in the game world
; Supports fuzzy matching with Levenshtein distance for typo tolerance
; Used by guard dispatch, kidnap actions, and follower errands
; =============================================================================

Actor Function FindActorByName(String name) Global Native
{Find a named NPC anywhere in the game world.
Searches loaded actors first, then falls back to base form lookup.
Supports fuzzy matching and typo tolerance (Levenshtein distance <= 2).
Returns None if no matching actor is found.}

String Function GetActorLocationName(Actor akActor) Global Native
{Get the current location/cell name where an actor is.
Returns "unknown" if actor is null or location cannot be determined.}

ObjectReference Function FindActorHome(Actor akActor) Global Native
{Find the home of an NPC and return a travel target (exterior door or owned bed).
Strategy 1: Pre-built home index from sleep package scanning at game load.
Returns the exterior door leading to the NPC's home cell (works for unloaded NPCs).
Strategy 2: Falls back to searching current cell for owned beds (loaded NPCs only).
Returns None if no home can be determined.}

String Function GetActorHomeCellName(Actor akActor) Global Native
{Get the display name of an NPC's home cell (disambiguated).
Uses the pre-built home index from sleep package scanning.
For generic names like "House" returns "House (WhiterunLocation)" etc.
Returns empty string if no home is known for this NPC.}

Bool Function IsActorFinderReady() Global Native
{Check if the actor finder has finished indexing.}

String Function GetActorIndexedCellName(Actor akActor) Global Native
{Get the interior cell name where an NPC is placed, from the pre-built index.
Built at game load by scanning all interior cells for unique NPC references.
Returns empty string if actor is not found in the index (e.g., exterior NPCs).
Used by guard dispatch to resolve unloaded NPC locations.}

String Function GetActorFinderStats() Global Native
{Get diagnostic stats about NPC mapping coverage.
Returns: "Total unique: X, Mapped: Y, Unmapped: Z | Sources - Persist: A, Parent: B, ..."}

Int Function GetUnmappedNPCCount() Global Native
{Get the number of unique NPCs that could not be mapped to a location.
These NPCs may be mapped during the post-load rescan.}

Function ActorFinder_ForceRescan() Global Native
{Force a rescan of unmapped NPCs. Normally happens automatically on game load.
Useful for debugging or if NPCs were missed during initial load.}

; =============================================================================
; POSITION SNAPSHOTS
; Track NPC coordinates even when unloaded
; Automatically captures positions on cell unload and FindByName lookups
; =============================================================================

Float[] Function GetActorLastKnownPosition(Actor akActor) Global Native
{Get the last known (x, y, z) position of an NPC as a 3-element float array.
If the actor is loaded, returns their live position and takes a fresh snapshot.
If unloaded, returns the position from the last cell detach snapshot.
Returns [0, 0, 0] if no data is available.}

String Function GetActorWorldspaceName(Actor akActor) Global Native
{Get the worldspace name where an NPC was last seen (e.g., "Tamriel", "Sovngarde").
Returns empty string if the actor is/was in an interior cell.
If loaded, returns live data. If unloaded, returns from snapshot.}

Bool Function IsActorInExterior(Actor akActor) Global Native
{Check if an NPC is/was in an exterior worldspace (not an interior cell).
If loaded, checks live cell. If unloaded, checks snapshot.
Returns false if no data available.}

Float Function GetActorSnapshotGameTime(Actor akActor) Global Native
{Get the game time when the last position snapshot was taken.
Returns 0.0 if no snapshot exists. Compare with Utility.GetCurrentGameTime()
to determine how stale the data is.}

Bool Function HasPositionSnapshot(Actor akActor) Global Native
{Check if a position snapshot exists for this NPC.
Snapshots are taken on cell unload and FindByName lookups.}

Float Function GetDistanceBetweenActors(Actor akActor1, Actor akActor2) Global Native
{Calculate the 3D distance between two actors using last known positions.
Works even if one or both actors are unloaded (uses snapshots).
Returns -1.0 if position data is unavailable for either actor.}

Int Function GetPositionSnapshotCount() Global Native
{Get the total number of NPCs with position snapshots.
Useful for diagnostics.}

; =============================================================================
; STUCK DETECTOR
; Tracks NPC movement to detect when they're stuck during travel/escort
; Returns escalation levels for progressive recovery
; =============================================================================

Function Stuck_StartTracking(Actor akActor) Global Native
{Start tracking an actor's movement for stuck detection.
Call when an NPC begins traveling or escorting.}

Function Stuck_StopTracking(Actor akActor) Global Native
{Stop tracking an actor's movement.
Call when travel completes or is cancelled.}

Int Function Stuck_CheckStatus(Actor akActor, Float checkInterval = 3.0, Float moveThreshold = 50.0) Global Native
{Check if an actor is stuck and get the escalation level.
Returns: 0=moving normally, 1=nudge (re-evaluate packages),
         2=leapfrog (progressive teleport), 3=force teleport.
checkInterval: seconds since last check (typically 3.0).
moveThreshold: minimum distance to count as moving (default 50 units).}

Float Function Stuck_GetTeleportDistance(Actor akActor) Global Native
{Get the recommended teleport distance for stuck recovery.
Returns progressive distances: 200 -> 500 -> 2000 based on escalation level.}

Bool Function Stuck_IsTracked(Actor akActor) Global Native
{Check if an actor is currently being tracked for stuck detection.}

Function Stuck_ResetEscalation(Actor akActor) Global Native
{Reset the escalation level for an actor after successful recovery.}

Function Stuck_ClearAll() Global Native
{Clear all stuck tracking data. Useful for cleanup.}

Int Function Stuck_GetTrackedCount() Global Native
{Get the number of actors currently being tracked.}

; =============================================================================
; COLLISION UTILITIES
; Toggle NPC-NPC collision for traveling actors
; Allows NPCs to clip through other NPCs instead of getting blocked
; =============================================================================

Function SetActorBumpable(Actor akActor, Bool bumpable) Global Native
{Set whether an actor can be bumped/blocked by other NPCs.
bumpable=true: normal collision (default). bumpable=false: clip through other NPCs.
Uses bhkCharacterController kNoCharacterCollisions flag.
Only affects NPC-NPC movement collision — does not affect weapon hits or environment.}

Bool Function IsActorBumpable(Actor akActor) Global Native
{Check if an actor currently has normal NPC-NPC collision enabled.
Returns true if bumpable (normal), false if clipping through other NPCs.}

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

ObjectReference Function FindSuspiciousItem(Actor akActor, Float radius = 2000.0) Global Native
{Find the most suspicious/incriminating item near an actor in a loaded cell.
Scores items by suspiciousness: poisons/skooma (highest), lockpicks, daggers,
soul gems, jewelry, notes/letters, weapons, high-value items.
Returns the highest-scoring item reference, or None if nothing suspicious found.
Only works in loaded cells (guard + player present).
Used by evidence collection when player is watching.}

Form Function GenerateContextualEvidence(Actor akTargetNPC) Global Native
{Generate a contextual evidence base form for off-screen investigation.
Picks an appropriate item based on the target NPC's class/combat style:
  Mage -> soul gem, scroll, void salts, daedra heart
  Thief -> lockpick, dagger, gem, gold ring
  Warrior -> weapon, armor, shield
  Merchant -> gems, jewelry, valuables
  Default -> lockpick, potion, gem, dagger
Returns a Form (base object) to AddItem to the guard. Not a world reference.
Used when the player isn't present and the cell isn't loaded.}

Form Function GenerateEvidenceForReason(String reason, Actor akTargetNPC) Global Native
{Generate evidence based on investigation reason string.
Uses keyword matching on the reason to pick thematically appropriate items:
  "dibella worship" -> Dibella statue, Amulet of Dibella
  "thieving" / "stolen" -> lockpicks, gems, gold ring
  "skooma" / "moon sugar" / "drugs" -> skooma, moon sugar
  "necromancy" / "dark magic" -> black soul gem, human heart, bone meal
  "daedra" / "daedric" -> daedra heart, void salts
  "poison" -> poisons, deathbell, nightshade
  "talos" -> Amulet of Talos
  "vampire" -> human heart, human flesh, black soul gem
  "forsworn" -> briar heart, hagraven parts
  "weapon" / "smuggling" -> steel weapons
Falls back to GenerateContextualEvidence (NPC class-based) if no keywords match.
akTargetNPC can be None if no target — only reason keywords will be used.}

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

; =============================================================================
; BOOK UTILITIES
; Extract book text content for NPC reading actions
; Uses TESDescription::GetDescription to access the full DESC field
; =============================================================================

String Function GetBookText(Form akBook) Global Native
{Get the full text content of a book.
Extracts the DESC field from TESObjectBOOK via TESDescription::GetDescription.
Strips HTML formatting tags ([pagebreak], <p>, <br>, <font>, etc.) and normalizes whitespace.
Returns empty string if the form is not a book or has no text content.}

Form Function FindBookInInventory(Actor akActor, String bookName) Global Native
{Find a book in an actor's inventory by name (case-insensitive partial match).
Returns the book Form if found, None otherwise.}

Bool Function HasBooks(Actor akActor) Global Native
{Check if an actor has any books in their inventory.
Returns true if at least one book is present.}

String Function ListBooks(Actor akActor) Global Native
{Get a comma-separated list of book names in an actor's inventory.
Returns empty string if no books found.}
