Scriptname SeverActionsNative Hidden
{Papyrus declarations of the SeverActionsNative DLL's natives, the first of three native scripts.
Papyrus caps a script at 511 natives (check_release check 9): new natives go on SeverActionsNativeExt2.
Several families live on the spillover scripts SeverActionsNativeExt / Ext2 (Hold_*, Native_Jailed_*,
Stuck_*, Travel_*, Craft_*, Arrival_*); the NSFW natives are in the separate SeverActionsNSFW mod.
Author: Severause}

String Function GetPluginVersion() Global Native
{Version string of the native plugin.}

; === STRING UTILITIES ===

String Function StringToLower(String text) Global Native
{Lowercase copy of text.}

Int Function HexToInt(String hexString) Global Native
{Parse a hex string, with or without "0x" ("0x12EB7" or "12EB7").}

String Function TrimString(String text) Global Native
{text without leading and trailing whitespace.}

String Function EscapeJsonString(String text) Global Native
{Escape quotes, backslashes and control characters for a JSON string.}

Bool Function StringContains(String haystack, String needle) Global Native
{Case-insensitive substring test.}

Bool Function StringEquals(String a, String b) Global Native
{Case-insensitive equality.}

; === INVENTORY ===

Form Function FindItemByName(Actor akActor, String itemName) Global Native
{Best case-insensitive match (exact, prefix, then substring) in akActor's inventory, a player-given
item name included, or None. Returns the BASE form, which a player-modified stack shares.}

Form Function FindItemInContainer(ObjectReference akContainer, String itemName) Global Native
{The same match in a container, base names only.}

Bool Function ActorHasItemByName(Actor akActor, String itemName) Global Native
{True if akActor holds an item matching itemName.}

Form Function FindWornItemByName(Actor akActor, String itemName) Global Native
{Worn armor or equipped weapon whose name (a player-given one included) matches itemName, or None.}

Int Function GetFormGoldValue(Form akForm) Global Native
{Gold value of a form of any type.}

Int Function GetInventoryItemCount(ObjectReference akContainer) Global Native
{Number of distinct item types in akContainer.}

Bool Function IsConsumable(Form akForm) Global Native
{True for any potion, food, drink, poison or ingredient.}

Bool Function IsFood(Form akForm) Global Native
{True if akForm is food.}

Bool Function IsPoison(Form akForm) Global Native
{True if akForm is a poison.}

Bool Function IsGoldName(String itemName) Global Native
{Case-insensitive test for a gold name ("gold", "septim(s)", "coin(s)", "gold piece(s)", ...),
so an LLM-supplied item name can take the gold path.}

Form[] Function FindValuableItems(ObjectReference akContainer, Int minValue = 50) Global Native
{Items in akContainer worth at least minValue gold.}

Int Function ProcessLoot(Actor akActor, ObjectReference akSource, String itemsToTake, Int maxItems = 30) Global Native
{Move items from akSource to akActor per itemsToTake: "all"/"everything", "valuables"/"valuable",
"gold"/"septims"/"money", or a comma-separated item list. Returns the stacks moved (at most
maxItems); the GetLastLoot* natives describe the transfer. An owned source raises no vanilla crime:
the caller charges a tracked bounty from SeverActionsNativeExt.GetLastStolenValue.}

String Function GetLastLootDescription() Global Native
{Description of the last ProcessLoot transfer (e.g. "Iron Sword, Gold x12").}

Form Function GetLastLootedForm() Global Native
{Last form ProcessLoot moved (one slot), or None if the last call moved nothing.}

Int Function GetLastLootedCount() Global Native
{Count of the last form moved by ProcessLoot.}

ObjectReference Function GetMerchantContainer(Actor akMerchant) Global Native
{Merchant chest of akMerchant's first vendor faction, or None. Cached 5 s per actor.}

; === NEARBY SEARCH ===

ObjectReference Function FindNearbyItemOfType(Actor akActor, String itemType, Float radius = 1000.0) Global Native
{Nearest pickupable item within radius matching itemType, or None.}

ObjectReference Function FindNearbyContainer(Actor akActor, String containerType, Float radius = 1000.0) Global Native
{Nearest container matching containerType; "" or "any" = any container with items.}

ObjectReference Function FindNearbyForge(Actor akActor, Float radius = 2000.0) Global Native
{Nearest forge / smithing station.}

String Function GetDirectionString(Actor akActor, ObjectReference akTarget) Global Native
{Where akTarget is from akActor: "ahead", "to the right", "to the left" or "behind".}

ObjectReference Function FindSuspiciousItem(Actor akActor, Float radius = 1000.0) Global Native
{Nearest suspicious item within radius (crime investigation).}

Form Function GenerateContextualEvidence(Actor akTargetNPC) Global Native
{An evidence form suited to akTargetNPC.}

Form Function GenerateEvidenceForReason(String reason, Actor akTargetNPC) Global Native
{An evidence form for a crime reason, targeting akTargetNPC.}

; === HOME SEARCH & EVIDENCE ===

Int Function FindSearchContainers(Actor akGuard, Float radius = 3000.0) Global Native
{Find searchable containers within radius in akGuard's cell, most suspicious first, replacing the last
search. Returns the count (max 4); read them with GetSearchContainer.}

ObjectReference Function GetSearchContainer(Int index) Global Native
{Container at index from the last FindSearchContainers.}

String Function GetContainerDescription(ObjectReference akContainer) Global Native
{The last search's description of a container (e.g. "a chest near the bed"), else "a <name>".}

Form Function ScanContainerForEvidence(ObjectReference akContainer, String crimeCategory) Global Native
{Most suspicious item in akContainer for crimeCategory (finds player-planted evidence), or None.}

Function PlantEvidenceInContainer(ObjectReference akContainer, Form akItem, Int count = 1) Global Native
{Put an evidence item into a container for the guard to find.}

Function RemoveEvidenceFromContainer(ObjectReference akContainer, Actor akGuard, Form akItem, Int count = 1) Global Native
{Move evidence from a container into the guard's inventory (destroyed when akGuard is None).}

Int Function ScoreEvidenceQuality(Form akItem, ObjectReference akContainer, String crimeReason) Global Native
{How damning akItem is, from a base of 1, never below 0: in the reason's evidence pool +2 (+2 more
for a damning-tier entry), a container the last search scored >= 30 +1, an everyday item -1, worth
over 200 gold +1.}

String Function SelectEvidenceFromPool(String reason, Actor akTargetNPC) Global Native
{Pick 1-3 evidence items for a crime: one common, a rare 30% of the time, a damning one 10%.
Returns "formID1|name1||formID2|name2||..." (FormIDs as 8-digit hex).}

Int Function GetEvidenceCount() Global Native
{Number of items the last SelectEvidenceFromPool picked.}

Form Function GetEvidenceAtIndex(Int index) Global Native
{Evidence form at index from the last SelectEvidenceFromPool.}

; === FURNITURE MANAGER ===

Bool Function RegisterFurnitureUser(Actor akActor, Package akPackage, ObjectReference akFurniture, Keyword akLinkedRefKeyword, Float autoStandDistance = 500.0) Global Native
{Register akActor on a furniture package: when the player moves away or changes cells, or the actor
dies or enters combat, the DLL fires SeverActionsNative_FurnitureCleanup and Papyrus removes the package. autoStandDistance is only
logged (every user is checked against SetDefaultAutoStandDistance), so pass 0.
akLinkedRefKeyword may be None. False on a null actor or package.}

Function UnregisterFurnitureUser(Actor akActor) Global Native
{Unregister akActor (they stood up normally).}

Function ForceAllFurnitureUsersStandUp() Global Native
{Clear the registry and send cleanup for every registered actor.}

Bool Function IsFurnitureUserRegistered(Actor akActor) Global Native
{True if akActor is registered.}

Float Function GetDefaultAutoStandDistance() Global Native
{The auto-stand distance every registered user is checked against.}

Function SetDefaultAutoStandDistance(Float distance) Global Native
{Set that distance (default 500). <= 0 turns off the distance check only: dead / in-combat cleanup
and the cell-change stand-up still run. The DLL sets it from the furnitureAutoStandDistance setting.}

ObjectReference Function FindFurnitureByFormID(String formIdStr, Actor nearActor) Global Native
{Resolve a furniture FormID string (decimal or "0x" hex, full unsigned 32-bit) to a reference; a base
FormID resolves to its nearest placed instance within 500 units of nearActor, in nearActor's cell.}

Int Function GetFurnitureUserCount() Global Native
{Number of registered furniture users.}

; === CRIME FACTION DATA ===

ObjectReference Function GetFactionJailMarker(Faction akFaction) Global Native
{Interior jail marker of a crime faction (where prisoners are sent), or None.}

ObjectReference Function GetFactionWaitMarker(Faction akFaction) Global Native
{Exterior jail marker (where the released appear), or None.}

ObjectReference Function GetFactionStolenGoodsContainer(Faction akFaction) Global Native
{Stolen-goods container of a crime faction, or None.}

ObjectReference Function GetFactionPlayerInventoryContainer(Faction akFaction) Global Native
{Container a crime faction holds the player's inventory in, or None.}

Outfit Function GetFactionJailOutfit(Faction akFaction) Global Native
{Jail outfit of a crime faction, or None.}

; === RECIPE DATABASE (smithing, cooking, smelting) ===

Bool Function IsRecipeDBLoaded() Global Native
{True once the recipe database is loaded.}

Form Function FindSmithingRecipe(String itemName) Global Native
{Smithing recipe result by item name (case-insensitive).}

Form Function FindCookingRecipe(String itemName) Global Native
{Cooking recipe result by item name (case-insensitive).}

Bool Function IsOvenRecipe(String itemName) Global Native
{True if the cooking recipe needs a Hearthfire oven (BYOHCraftingOven), not a cooking pot.}

String Function GetRecipeDBStats() Global Native
{Recipe database counts (smithing / cooking / smelting).}

; === ALCHEMY DATABASE ===

Bool Function IsAlchemyDBLoaded() Global Native
{True once the alchemy database is loaded.}

Potion Function FindPotion(String itemName) Global Native
{Potion by name.}

Potion Function FindPoison(String itemName) Global Native
{Poison by name.}

String Function GetAlchemyDBStats() Global Native
{Alchemy database counts (potions / poisons).}

; === NEARBY WORKSTATIONS ===

ObjectReference Function FindNearbyCookingPot(Actor akActor, Float radius = 2000.0) Global Native
{Nearest cooking pot / spit within radius.}

ObjectReference Function FindNearbyOven(Actor akActor, Float radius = 2000.0) Global Native
{Nearest Hearthfire oven (BYOHCraftingOven) within radius, for the baked goods IsOvenRecipe names.}

ObjectReference Function FindNearbyAlchemyLab(Actor akActor, Float radius = 2000.0) Global Native
{Nearest alchemy lab within radius.}

; === SANDBOX MANAGER ===

Bool Function RegisterSandboxUser(Actor akActor, Package akPackage, Float autoStandDistance = 500.0) Global Native
{Register akActor's sandbox package: a player cell change fires SeverActionsNative_SandboxCleanup
(the only trigger; autoStandDistance is unused). True on success. Must stay Bool to match
SandboxManager's Papyrus_RegisterSandboxUser, or SKSE refuses to bind the native.}

Function UnregisterSandboxUser(Actor akActor) Global Native
{Unregister akActor.}

Function ForceAllSandboxUsersStop() Global Native
{Clear the registry and send cleanup for every registered actor.}

Bool Function IsSandboxUserRegistered(Actor akActor) Global Native
{True if akActor is registered.}

Int Function GetSandboxUserCount() Global Native
{Number of registered sandbox users.}

; === DIALOGUE ANIMATION ===

Function SetDialogueAnimEnabled(Bool enabled) Global Native
{Enable or disable dialogue animations.}

Bool Function IsDialogueAnimEnabled() Global Native
{True if dialogue animations are enabled.}

; === SURVIVAL ===

; --- Follower Tracking ---

Bool Function Survival_StartTracking(Actor akActor) Global Native
{Start tracking akActor's survival needs; true on success.}

Function Survival_StopTracking(Actor akActor) Global Native
{Stop tracking akActor.}

Bool Function Survival_IsTracked(Actor akActor) Global Native
{True if akActor is tracked.}

Int Function Survival_GetTrackedCount() Global Native
{Number of tracked actors.}

Actor[] Function Survival_GetTrackedFollowers() Global Native
{Every tracked actor.}

Actor[] Function Survival_GetCurrentFollowers() Global Native
{Living teammates in the high / middle-high process lists, plus dismissed followers with a home in
the player's cell while trackDismissedSurvival is on.}

; --- Food Detection ---

Bool Function Survival_IsFoodItem(Form akForm) Global Native
{True if akForm is food.}

Int Function Survival_GetFoodRestoreValue(Form akForm) Global Native
{Restore value of a food item.}

; --- Weather & Cold ---

Float Function Survival_GetWeatherColdFactor() Global Native
{Current weather's cold factor (0.0 warm to 1.0 freezing).}

Int Function Survival_GetWeatherClassification() Global Native
{Current weather: 0 clear or none, 1 cloudy, 2 rain, 3 snow.}

Bool Function Survival_IsSnowingWeather() Global Native
{True if it is snowing.}

Bool Function Survival_IsInColdRegion(Actor akActor) Global Native
{True in a cold region (Winterhold, the Pale, ...).}

Float Function Survival_CalculateColdExposure(Actor akActor) Global Native
{Cold exposure (0.0 to 1.0) from akActor's surroundings.}

Float Function Survival_GetArmorWarmthFactor(Actor akActor) Global Native
{Warmth of akActor's equipped armor (higher = warmer).}

; --- Heat Sources (akActor's parent cell only) ---

Bool Function Survival_IsNearHeatSource(Actor akActor, Float radius = 512.0) Global Native
{True within radius of a heat source.}

Float Function Survival_GetDistanceToNearestHeatSource(Actor akActor, Float maxRadius = 512.0) Global Native
{Distance to the nearest heat source, or -1.0 if none is within maxRadius.}

Bool Function Survival_IsNearCampfire(Actor akActor, Float radius = 512.0) Global Native
{True within radius of a campfire.}

Bool Function Survival_IsNearForge(Actor akActor, Float radius = 512.0) Global Native
{True within radius of a forge.}

Bool Function Survival_IsNearHearth(Actor akActor, Float radius = 512.0) Global Native
{True within radius of a hearth / fireplace.}

Bool Function Survival_IsInWarmInterior(Actor akActor) Global Native
{True in a warm interior (heat sources included).}

; --- Per-actor need state (times in Survival_GetGameTimeInSeconds units) ---

Float Function Survival_GetLastAteTime(Actor akActor) Global Native
{Game time akActor last ate.}

Function Survival_SetLastAteTime(Actor akActor, Float gameTime) Global Native
{Set the game time akActor last ate.}

Float Function Survival_GetLastSleptTime(Actor akActor) Global Native
{Game time akActor last slept.}

Function Survival_SetLastSleptTime(Actor akActor, Float gameTime) Global Native
{Set the game time akActor last slept.}

Float Function Survival_GetLastWarmedTime(Actor akActor) Global Native
{Game time akActor was last warmed.}

Function Survival_SetLastWarmedTime(Actor akActor, Float gameTime) Global Native
{Set the game time akActor was last warmed.}

Int Function Survival_GetHungerLevel(Actor akActor) Global Native
{Hunger level (0 = full, higher = hungrier).}

Function Survival_SetHungerLevel(Actor akActor, Int level) Global Native
{Set the hunger level.}

Int Function Survival_GetFatigueLevel(Actor akActor) Global Native
{Fatigue level (0 = rested, higher = more tired).}

Function Survival_SetFatigueLevel(Actor akActor, Int level) Global Native
{Set the fatigue level.}

Int Function Survival_GetColdLevel(Actor akActor) Global Native
{Cold level (0 = warm, higher = colder).}

Function Survival_SetColdLevel(Actor akActor, Int level) Global Native
{Set the cold level.}

Function Survival_ClearActorData(Actor akActor) Global Native
{Clear all of akActor's survival data.}

; --- Utility ---

Float Function Survival_GetGameTimeInSeconds() Global Native
{Current game time as game hours x 3631 (the scripts' SECONDS_PER_GAME_HOUR, not 3600).}

; === FERTILITY MODE BRIDGE ===

Bool Function FM_Initialize() Global Native
{Initialize the Fertility Mode bridge; true if Fertility Mode is available.}

Bool Function FM_IsInstalled() Global Native
{True if Fertility Mode is installed.}

Function FM_RefreshCache() Global Native
{Refresh the fertility cache from game data.}

Function FM_ClearActorData(Actor akActor) Global Native
{Clear akActor's cached fertility data.}

Function FM_ClearAllCache() Global Native
{Clear all cached fertility data.}

Int Function FM_GetCachedActorCount() Global Native
{Number of actors with cached fertility data.}

Function FM_SetActorData(Actor akActor, Float lastConception, Float lastBirth, Float babyAdded, Float lastOvulation, Float lastGameHours, Int lastGameHoursDelta, String currentFather) Global Native
{Push an actor's fertility data to the native cache the decorators read.}

String Function FM_GetFertilityState(Actor akActor) Global Native
{Fertility state string.}

String Function FM_GetFertilityFather(Actor akActor) Global Native
{Father's name for a pregnant actor.}

String Function FM_GetCycleDay(Actor akActor) Global Native
{Current cycle day.}

String Function FM_GetPregnantDays(Actor akActor) Global Native
{Days pregnant.}

String Function FM_GetHasBaby(Actor akActor) Global Native
{Whether akActor has a baby.}

String Function FM_GetFertilityDataBatch(Actor akActor) Global Native
{All of the above in one call: "state|father|cycleDay|pregnantDays|hasBaby".}

; === DYNAMIC BOOK FRAMEWORK (soft dependency; see GetBookText) ===

Bool Function IsDBFInstalled() Global Native
{True if Dynamic Book Framework is active. The DBF-backed natives are safe to call without it.}

Function ReloadDBFMappings() Global Native
{Re-read DBF's INI book mappings, e.g. after DBF's AppendToFile made a book. No-op without DBF.}

; === ACTOR FINDER ===
; The name index is built at kDataLoaded, the cell / home mapping on a background thread; the location
; and home natives block until that mapping is done (normally during the loading screen).

Actor Function FindActorByName(String name) Global Native
{Actor by name: the player, loaded actors, the unique-name index, then a fuzzy match (substring or
edit distance <= 2). None if nothing matches.}

String Function GetActorLocationName(Actor akActor) Global Native
{Name of akActor's current location or cell, or "unknown".}

ObjectReference Function FindActorHome(Actor akActor) Global Native
{A bed in akActor's current cell owned by them or their faction, or None. Not a home lookup for
an unloaded NPC: see GetActorHomeCellName.}

String Function GetActorHomeCellName(Actor akActor) Global Native
{Home cell name from the home index, or "".}

Bool Function IsActorFinderReady() Global Native
{True once the name index and the cell mapping are both built.}

String Function GetActorIndexedCellName(Actor akActor) Global Native
{akActor's cell name as stored in the index, or "".}

String Function GetActorFinderStats() Global Native
{Mapping coverage by source (diagnostic).}

Int Function GetUnmappedNPCCount() Global Native
{Number of unique NPCs without a location mapping.}

Function ActorFinder_ForceRescan() Global Native
{Rebuild the whole actor index (expensive).}

Float[] Function GetActorLastKnownPosition(Actor akActor) Global Native
{[x, y, z]: live when akActor is loaded (refreshing its snapshot), else the last snapshot;
[0, 0, 0] when there is none.}

String Function GetActorWorldspaceName(Actor akActor) Global Native
{akActor's worldspace name (live, else from the snapshot); "" in an interior.}

Bool Function IsActorInExterior(Actor akActor) Global Native
{True in an exterior (live, else from the snapshot).}

Float Function GetActorSnapshotGameTime(Actor akActor) Global Native
{Game time of akActor's last snapshot, or 0.}

Bool Function HasPositionSnapshot(Actor akActor) Global Native
{True if akActor has a snapshot.}

Float Function GetDistanceBetweenActors(Actor actor1, Actor actor2) Global Native
{3D distance from live or snapshot positions; -1 when either is unknown, or they are in different
worldspaces or interiors.}

Int Function GetPositionSnapshotCount() Global Native
{Number of stored snapshots.}

; === BOOKS ===

String Function GetBookText(Form akForm) Global Native
{Full text of a book, markup ([pagebreak], <p>, <font>, ...) stripped and whitespace normalized.
When DBF maps the book to a .txt file, that file's contents instead.}

Form Function FindBookInInventory(Actor akActor, String bookName) Global Native
{Book in akActor's inventory matching bookName (case-insensitive partial match), or None.}

Bool Function HasBooks(Actor akActor) Global Native
{True if akActor carries any book.}

String Function ListBooks(Actor akActor) Global Native
{Comma-separated names of the books akActor carries.}

; === COLLISION ===

Function SetActorBumpable(Actor akActor, Bool bumpable) Global Native
{Set whether other actors can bump akActor (false keeps an NPC from being pushed during a scene).}

Bool Function IsActorBumpable(Actor akActor) Global Native
{True if akActor can be bumped.}

; === LOCATION RESOLVER (place names to markers and doors) ===

ObjectReference Function ResolveDestination(Actor akActor, String destination) Global Native
{Travel marker for a destination name, resolved in akActor's context, or None.}

String Function GetLocationName(String destination) Global Native
{Canonical display name for a destination string.}

Bool Function IsLocationResolverReady() Global Native
{True once the resolver is initialized.}

Int Function GetLocationCount() Global Native
{Number of locations in the resolver database.}

String Function GetLocationResolverStats() Global Native
{Resolver statistics (diagnostic).}

String Function GetDisambiguatedCellName(Actor akActor) Global Native
{akActor's cell name, with context (e.g. the hold) added when the name is generic.}

ObjectReference Function FindDoorToActorCell(Actor akActor) Global Native
{A door leading into akActor's current cell (to path to them).}

ObjectReference Function FindDoorToActorHome(Actor akActor) Global Native
{A door leading into akActor's home cell, or None.}

ObjectReference Function FindExitDoorFromCell(Actor akActor) Global Native
{The door out of akActor's interior cell; None in an exterior.}

ObjectReference Function FindHomeInteriorMarker(Actor akActor) Global Native
{An interior marker in akActor's home cell, or None.}

ObjectReference Function FindInteriorMarkerForDoor(ObjectReference doorRef, Actor akActor = None) Global Native
{The interior marker on the far side of doorRef, or None.}

; === YIELD MONITOR ===

Function RegisterYieldedActor(Actor akActor, Float originalAggression, Faction surrenderedFaction) Global Native
{Watch a yielded actor for player hits: SetYieldHitThreshold hits revert the surrender and fire
SeverActionsNative_YieldBroken. surrenderedFaction (SeverSurrenderedFaction) is cached on first use.}

Function UnregisterYieldedActor(Actor akActor) Global Native
{Stop watching a yielded actor (ReturnToCrime, FullCleanup, dismissal).}

Bool Function IsYieldMonitored(Actor akActor) Global Native
{True while akActor is watched.}

Int Function GetYieldHitCount(Actor akActor) Global Native
{Player hits a watched actor has taken.}

Function SetYieldHitThreshold(Int threshold) Global Native
{Player hits that break a surrender (default 3, minimum 1).}

; === CEASEFIRE MONITOR ===

Function Ceasefire_Register(Actor akActor, Float originalAggression) Global Native
{Watch a ceasefire'd actor: a player hit breaks the ceasefire for it and its tracked allies, restoring
aggression and factions, and fires SeverActionsNative_CeasefireBroken for Papyrus's cleanup.}

Function Ceasefire_Unregister(Actor akActor) Global Native
{Stop watching akActor.}

Bool Function Ceasefire_IsMonitored(Actor akActor) Global Native
{True while akActor is watched.}

Function Ceasefire_ClearAll() Global Native
{Clear all ceasefire tracking.}

Actor[] Function Ceasefire_FindNearbyAllies(Actor akActor, Float radius) Global Native
{Living, loaded actors within radius in akActor's cell (neighbours not scanned) sharing one of its
base-record factions, player excluded; to spread a group ceasefire.}

; === OFF-SCREEN TRAVEL ESTIMATE (unloaded NPCs, ~18000 units per game hour) ===

Float Function OffScreen_InitTracking(Actor akActor, ObjectReference akDestination, Float minHours, Float maxHours) Global Native
{Start estimating akActor's trip from distance, clamped to [minHours, maxHours] game hours (their
midpoint when either end is unloaded). Returns the estimated arrival in game days.}

Int Function OffScreen_CheckArrival(Actor akActor, Float currentGameTime) Global Native
{1 once the estimated arrival has passed (teleport them), else 0. Pass Utility.GetCurrentGameTime().}

Function OffScreen_StopTracking(Actor akActor) Global Native
{Stop tracking akActor (dispatch finished or cancelled).}

Float Function OffScreen_GetEstimatedArrival(Actor akActor) Global Native
{Estimated arrival (game days) of a tracked actor, or 0.}

Function OffScreen_ClearAll() Global Native
{Clear all off-screen tracking.}

; === GUARD FINDER ===

Actor Function FindNearestGuard(Actor akNearActor, Float searchRadius = 3000.0) Global Native
{Nearest guard within searchRadius of akNearActor, or None.}

Actor Function FindNearestGuardWithLOS(Actor akNearActor, Float searchRadius = 3000.0) Global Native
{Nearest guard with line of sight to akNearActor, else FindNearestGuard's answer: a guard around a
corner beats a failed arrest.}

Bool Function Native_MoveToNearestNavmesh(ObjectReference akRef, Float minOffset = 0.0) Global Native
{Snap akRef onto the nearest navmesh, e.g. after a MoveTo (never Disable/Enable an actor to kick
it). True if it snapped.}

Bool Function Native_IsActorInScene(Actor akActor) Global Native
{True while akActor runs a BGSScene (the speech gates and the schedule skip such actors). Most town
NPCs are in one at any time, so arrests must not reject on it.}

Int Function Native_GetActorProcessLevel(Actor akActor) Global Native
{AI process tier: 3 high, 2 middle-high, 1 middle-low, 0 low, -1 none (not loaded). ArrestNPC
refuses -1.}

Function Native_SetActorArrested(Actor akActor, Bool arrested) Global Native
{Set or clear the engine's arrested flag so vanilla guards and arrest-aware mods see the actor in
custody (ArrestSessionStore is SeverActions-only). Clearing also stops the actor's combat and
alarm. The arrest FSM deliberately never sets it: set during the approach, it made guards stop
pursuing.}

Bool Function Native_IsActorArrested(Actor akActor) Global Native
{The engine's arrested flag, whoever set it (us, vanilla guards, another mod).}

; === ARREST SESSION STORE ('ARST' cosave) ===
; In-flight arrests keyed by prisoner. A per-state game-time watchdog, measured from the last state
; change, fires SeverActions_ArrestSessionTimeout so Papyrus can cancel. States (C++ ArrestSessionState):
; 1 Approach, 2 Arresting, 3 Escort, 4 Arrived, 5 Dispatch, 6 Judgment, 7 Persuasion, 8 EscortPlea,
; 9 Jailed (no timeout).

Function Native_ArrestSession_Begin(Actor akPrisoner, Actor akGuard, ObjectReference akJailMarker, Faction akCrimeFaction, Int aiState, Int aiDispatchPhase, Int aiFlags) Global Native
{Open a session keyed on the prisoner, replacing any existing one.}

Function Native_ArrestSession_EnsureBegin(Actor akPrisoner, Actor akGuard, ObjectReference akJailMarker, Faction akCrimeFaction, Int aiState, Int aiDispatchPhase, Int aiFlags) Global Native
{Begin if missing, else update; restarts the state's timer. For hand-offs where the previous phase
may have closed the session (judgment to escort).}

Function Native_ArrestSession_UpdateState(Actor akPrisoner, Int aiNewState, Int aiNewDispatchPhase) Global Native
{Change an existing session's state, restarting the state's timer. No-op without a session (use
EnsureBegin).}

Function Native_ArrestSession_End(Actor akPrisoner) Global Native
{Close the prisoner's session. Idempotent.}

Function Native_ArrestSession_EndAll() Global Native
{Close every session (new game, full cleanup).}

Bool Function Native_ArrestSession_HasSession(Actor akPrisoner) Global Native
{True if the prisoner has a session.}

Bool Function Native_ArrestSession_IsActorInArrest(Actor akActor) Global Native
{True while akActor is in an arrest as prisoner, arresting guard, either half of the player quest's
active pair, or either end of a live dispatch. Unlike HasSession (prisoner only), answers for guards.}

Int Function Native_ArrestSession_GetCount() Global Native
{Number of active sessions.}

Int Function Native_ArrestSession_GetState(Actor akPrisoner) Global Native
{The prisoner's session state (1-9), or 0 without a session.}

Float Function Native_ArrestSession_GetAgeHours(Actor akPrisoner) Global Native
{Game hours since the session began, or 0.}

Function Native_ArrestSession_CaptureAVs(Actor akPrisoner, Float afAggression, Float afConfidence) Global Native
{Store the prisoner's pre-arrest Aggression / Confidence on the session for RestorePrisonerStats.
Each is set only while it holds the -1.0 sentinel, so a second PerformArrest cannot overwrite them
with the zeroes it writes.}

Float Function Native_ArrestSession_GetOrigAggression(Actor akPrisoner) Global Native
{The captured pre-arrest Aggression, or -1.0 without a session or a capture.}

Float Function Native_ArrestSession_GetOrigConfidence(Actor akPrisoner) Global Native
{The captured pre-arrest Confidence, or -1.0 without a session or a capture.}

; === PERSUASION MONITOR ===
; Once a real second checks each open persuasion window (one per owner actor: the arrest's guard, the
; ambush lead, the camp challenger) and fires SeverActions_PersuasionFailed (strArg "timeout" |
; "distance" | "died", sender = the window's actor).

Function Native_Persuasion_Begin(Actor akGuard, Actor akPlayer, Float afTimeLimitSec, Float afDistanceLimit) Global Native
{Open (or restart) akGuard's persuasion window; other owners' windows are untouched.
afTimeLimitSec is real seconds, afDistanceLimit units. Every exit path must end it with
SeverActionsNativeExt2.Native_Persuasion_EndFor(akGuard).}

Function Native_Persuasion_End() Global Native
{End EVERY open persuasion window (the load reset). An owner ends only its own, with
SeverActionsNativeExt2.Native_Persuasion_EndFor.}

Bool Function Native_Persuasion_IsActive() Global Native
{True while any persuasion window is open. Diagnostic: Papyrus's InPersuasionMode is canonical.}

; === BRAWL CHALLENGE MONITOR ===
; Pending NPC<->NPC challenges, several at once, keyed by challenger. Fires
; SeverActions_BrawlChallengeExpired (sender = target, strArg "timeout" | "died" | "distance" +
; "|<challenger FormID, signed decimal>") when a wait ends without Accept or Decline.

Function Native_BrawlChallenge_Begin(Actor akChallenger, Actor akTarget, Float afTimeLimitSec, Float afDistanceLimit) Global Native
{Start a pending challenge (SeverActions_Brawl's NPC<->NPC ChallengeBrawl).}

Function Native_BrawlChallenge_End(Actor akChallenger) Global Native
{Clear the challenge keyed by this challenger. Idempotent.}

Function Native_BrawlChallenge_EndForActor(Actor akActor) Global Native
{Clear any challenge naming akActor as challenger or target (the brawl began, or was declined).}

Bool Function Native_BrawlChallenge_IsActive(Actor akChallenger) Global Native
{True if akChallenger has a pending challenge.}

Actor Function Native_BrawlChallenge_GetLastExpiredChallenger() Global Native
{Challenger of the latest expired challenge, set before the expiry event fires. Kept for an older
pex: the current OnChallengeExpired reads the challenger from the event's strArg, because one slot
misroutes two challenges expiring in the same pass.}

; === BRAWL PROMPT (UI host card) ===
; Non-pausing Accept / Decline card for a challenge aimed at the player. The answer arrives as
; SeverActions_BrawlChallengeChoice (strArg "accept" | "decline", sender = challenger) for
; SeverActions_Brawl.OnBrawlPromptChoice; the timeout declines.

Bool Function Magelight_OpenBrawlPrompt(Actor akChallenger, String asChallengerName, Int aiTimeoutMs) Global Native
{Show the card (aiTimeoutMs <= 0 = 60 s). True if it opened, or if VR immersive mode left the
challenge to dialogue; false when the host is not ready, a prompt is open or another view has
focus: fall back to SkyMessage.}

Function Magelight_CloseBrawlPrompt() Global Native
{Close the card without a choice (load cleanup). Safe when none is open.}

Bool Function Magelight_IsBrawlPromptOpen() Global Native
{True while the card shows.}

Bool Function Magelight_IsBrawlPromptAvailable() Global Native
{True when the host view is ready (or VR immersive mode is on), so the card can replace SkyMessage.}

; === ARREST PROMPT (UI host card) ===
; Non-pausing card for SeverActions_ArrestPlayer.ShowPlayerArrestMenu. JS picks the buttons from
; (lowBounty, paymentFailed, persuadeAttempted) and must mirror the Papyrus branches. The answer
; arrives as SeverActions_ArrestPromptChoice (strArg "pay_fine" | "submit" | "resist" | "bribe" |
; "persuade", numArg = bounty, sender = guard). The timeout submits; Escape closes with no choice and
; ArrestPlayer reopens the card while ConfrontingGuard is set.

Bool Function Magelight_OpenArrestPrompt(Actor akGuard, String asGuardName, \
    String asHoldName, Int aiBounty, Int aiBribeCost, \
    Bool abPaymentFailed, Bool abPersuadeAttempted, Bool abLowBounty, \
    Int aiTimeoutMs) Global Native
{Show the card (aiTimeoutMs <= 0 = 60 s). True if it opened; false when the host is not ready, a
prompt is open or another view has focus: fall back to SkyMessage.Show.}

Function Magelight_CloseArrestPrompt() Global Native
{Close the card without a choice, when the confrontation ended out of band (guard died, player fled).}

Bool Function Magelight_IsArrestPromptOpen() Global Native
{True while the card shows.}

Bool Function Magelight_IsArrestPromptAvailable() Global Native
{True when the host view is ready, so the card can replace SkyMessage.}

; === RESIST ARREST MONITOR ===
; While the player resists arrest, fires SeverActions_ResistCombatEnded with strArg "combatEnd" when the
; player leaves combat, or "timeout" if Begin's watchdog runs out first. Papyrus keeps the faction and
; bounty work.

Function Native_Resist_Begin(Float afMaxWaitSeconds) Global Native
{Start watching, replacing any active watch. afMaxWaitSeconds is the real-time watchdog
(ResistMaxWaitSeconds, 600 by default).}

Function Native_Resist_End() Global Native
{Stop watching. Idempotent.}

Bool Function Native_Resist_IsActive() Global Native
{True while a resist is watched.}

; === ESCORT PACKAGE REAPPLIER ===
; The engine drops package overrides on a cell change or combat end; on either, for the tracked guard or
; prisoner, this fires SeverActions_EscortReapplyPackages and SeverActions_Arrest re-applies them.

Function Native_EscortReapply_Begin(Actor akGuard, Actor akPrisoner) Global Native
{Track the escort pair, replacing any previous one (StartEscortPhase, RecoverActiveArrest).}

Function Native_EscortReapply_End() Global Native
{Stop tracking (ClearArrestState). Idempotent.}

Bool Function Native_EscortReapply_IsActive() Global Native
{True while a pair is tracked (diagnostic).}

Function Native_Arrest_Log(String msg) Global Native
{Write msg to SeverActionsNative.log with an [Arrest] prefix, readable without bPapyrusLog.}

; === SKYRIMNET ACTOR BUSY STATE (PublicAPI v6+) ===
; Drives the is_busy / busy_reason decorators, which keep every SkyrimNet action (other plugins'
; included) off an actor during a multi-step operation. Each returns false without the v6 API:
; treat that as a soft failure.

Bool Function Native_SkyrimNet_SetActorBusy(Actor akActor, String asReason) Global Native
{Mark akActor busy; asReason is what busy_reason() returns (e.g. "arrest").}

Bool Function Native_SkyrimNet_ClearActorBusy(Actor akActor) Global Native
{Clear akActor's busy state. Idempotent.}

Bool Function Native_SkyrimNet_IsActorBusy(Actor akActor) Global Native
{True while akActor is busy.}

; === TEAMMATE MONITOR ===
; Detects actors becoming or ceasing to be player teammates (~1 s scan) and sends
; SeverActions_NewTeammateDetected, SeverActions_TeammateRemoved or SeverActions_TeammateResumed.

Function TeammateMonitor_SetEnabled(Bool enabled) Global Native
{Enable or disable the monitor (on by default).}

Bool Function TeammateMonitor_IsEnabled() Global Native
{True if the monitor is enabled.}

Int Function TeammateMonitor_GetTrackedCount() Global Native
{Number of tracked teammates.}

Function TeammateMonitor_ClearTracking() Global Native
{Clear all tracking. The DLL does this at every session start.}

; === CONFIG MENU (Magelight UI host; no-ops without one) ===

Bool Function Magelight_IsAvailable() Global Native
{True if the UI host is present and the config menu can open.}

Bool Function Magelight_IsMenuOpen() Global Native
{True while the config menu is open.}

Function Magelight_ToggleMenu() Global Native
{Open or close the config menu.}

Function Magelight_SetMenuKey(Int keyCode, Bool requireShift) Global Native
{Bind the config-menu key in the native input sink (DX scancode, <= 0 unbinds) and record it to the
global settings file. No script calls it; kept for an older pex.}

Function Magelight_SendData(String jsonData) Global Native
{Send JSON to the config view.}

Function Magelight_CloseMenu() Global Native
{Close the config menu.}

String Function Magelight_ExtractJsonValue(String json, String key) Global Native
{Value of key in a flat JSON object, as a string. Unused; parse JSON with the Json_* natives on
SeverActionsNativeExt2.}

Function Magelight_SetPauseOnOpen(Bool enabled) Global Native
{Set whether opening the menu pauses the game (restored on load by SeverActions_Follow).}

Function Magelight_SetYieldPromptEnabled(Bool enabled) Global Native
{Set the native copy of the yield/surrender prompt toggle that the settings page reads (restored on
load by SeverActions_Follow). The 0160 combat prompt reads the StorageUtil(None) mirror instead.}

Function Magelight_SetTravelPopupEnabled(Bool enabled) Global Native
{Set the travel-destination popup toggle (restored on load by SeverActions_Follow).}

Bool Function Magelight_IsTravelPopupEnabled() Global Native
{True (default): show the confirm popup; false: travel starts at once.}

Function Magelight_SetTravelPopupFollowersOnly(Bool enabled) Global Native
{Set the popup's followers-only scope (restored on load by SeverActions_Follow).}

Bool Function Magelight_IsTravelPopupFollowersOnly() Global Native
{True: only the player's followers get the popup. Default false (everyone).}

Bool Function Magelight_IsPauseOnOpen() Global Native
{The pause-on-open setting.}

; --- Config menu data: the DLL reads script properties straight from the VM ---

Function Magelight_SetQuestRefs(Quest mcm, Quest followerMgr, Quest survival, \
    Quest arrest, Quest debt, Quest travel, Quest outfit, Quest loot, \
    Quest spellTeach, Quest hotkeys) Global Native
{Hand the data gatherer the quests whose script properties it reads. No script calls it: the
gatherer resolves the SeverActions quest by FormID itself.}

Function Magelight_RefreshPage(String page) Global Native
{Rebuild a page's data and send it to the config view, after a change to game state.}

; --- Diary viewer: a standalone popup (MagelightDiaryBridge) to pick a diary entry to read aloud ---

Function Magelight_OpenDiaryViewerForBook(Form bookForm, Actor reader) Global Native
{Open the diary viewer for a diary book: the NPC comes from the book title, the entries from
SkyrimNet's diary DB.}

Function Magelight_CloseDiaryViewer() Global Native
{Close the diary viewer.}

Bool Function Magelight_IsDiaryViewerOpen() Global Native
{True while the diary viewer is open.}

String Function Magelight_GetSelectedDiaryContent() Global Native
{Full text of the entry the player picked; valid only after the selection event.}

String Function Magelight_GetSelectedDiaryTitle() Global Native
{Title / date of the entry the player picked; valid only after the selection event.}

; --- Collect Payment prompt (non-pausing card, MagelightCollectPaymentBridge) ---
; The answer arrives as SeverActions_CollectPaymentChoice (strArg "accept" | "deny" | "denySilent",
; numArg = amount, sender = collector). The timeout accepts, so a player who walks away still pays.

Bool Function Magelight_OpenPaymentPrompt(Actor akCollector, Int aiAmount, String asCollectorName, Int aiTimeoutMs) Global Native
{Show the card (aiTimeoutMs <= 0 = 20 s). True if it opened, or if VR immersive mode accepted at once;
false when the host is not ready, a prompt is open or another view has focus: fall back to SkyMessage.}

Function Magelight_ClosePaymentPrompt() Global Native
{Close the card without a choice. No event fires, so no payment happened.}

Bool Function Magelight_IsPaymentPromptOpen() Global Native
{True while the card shows.}

Bool Function Magelight_IsPaymentPromptAvailable() Global Native
{True when the host view is ready (or VR immersive mode is on), so the card can replace SkyMessage.}

; === LINKED REFS AND PACKAGE RE-EVALUATION ===
; Linked refs are cosaved ('LREF'), re-applied on load and dropped on death. An entry not re-Set for 30
; game days is pruned: a lasting anchor uses SeverActionsNativeExt.LinkedRef_SetPermanent.

Function LinkedRef_Set(Actor akActor, ObjectReference akTarget, Keyword akKeyword) Global Native
{Set akActor's linked reference for akKeyword.}

Function LinkedRef_Clear(Actor akActor, Keyword akKeyword) Global Native
{Clear akActor's linked reference for akKeyword.}

Function LinkedRef_ClearAll(Actor akActor) Global Native
{Clear akActor's tracked linked references, except permanent ones (LinkedRef_SetPermanent).}

Int Function LinkedRef_GetTrackedCount() Global Native
{Number of actors with tracked linked references.}

Bool Function LinkedRef_HasAny(Actor akActor) Global Native
{True if akActor has a tracked linked reference.}

Function NativeEvaluatePackage(Actor akActor) Global Native
{Re-evaluate akActor's packages with immediate=true, so it takes effect now rather than on the next
AI tick.}

Function NativeResetAI(Actor akActor) Global Native
{Full AI reset plus re-evaluation, as console resetai: for actors NativeEvaluatePackage cannot move.
Also clears combat / alert state, so not for routine use.}

Function EnqueueDeferredForceEval(Actor akActor, Int delayMs) Global Native
{NativeEvaluatePackage after delayMs, to cover races with the engine's AI tick. The queue drains on
PackageManager's InputEvent heartbeat.}

Function EnqueueDeferredResetAI(Actor akActor, Int delayMs) Global Native
{NativeResetAI after delayMs, on the same queue. Clears combat / alert state.}

Function EscalatedReEvaluate(Actor akActor, Int resetDelayMs = 1500) Global
{Re-evaluate after a package swap or marker move in three steps, since none is reliable alone:
NativeEvaluatePackage now, a deferred force-eval at 500 ms (cell-transition races), a deferred AI
reset at resetDelayMs. The reset clears combat / alert state: only for actors not expected in combat.}
    If !akActor
        Return
    EndIf
    NativeEvaluatePackage(akActor)
    EnqueueDeferredForceEval(akActor, 500)
    EnqueueDeferredResetAI(akActor, resetDelayMs)
EndFunction

; === HOME SANDBOX VERIFIER ===
; An input-heartbeat scan (every 10 s by default, from plugin init) that resets the AI of dismissed
; home-sandboxed NPCs stuck on an engine fallback package or mid-procedure. These are for debugging.

Function HomeVerifier_ForceScan() Global Native
{Scan and reset now.}

Function HomeVerifier_SetEnabled(Bool enabled) Global Native
{Pause or resume the scan (on by default).}

Bool Function HomeVerifier_IsEnabled() Global Native
{True while the scan runs.}

Function HomeVerifier_SetScanIntervalSeconds(Int seconds) Global Native
{Set the scan interval, clamped to 1-600 s (default 10).}

; === ORPHAN CLEANUP ===
; Every ~5 s finds loaded actors holding a SeverActions LinkedRef keyword no system tracks (left by a
; crashed script) and fires SeverActions_OrphanCleanup for Papyrus to clear it. Off by default (settings
; row orphanCleanupEnabled); the DLL resolves its keywords and factions by FormID at kDataLoaded. The
; registries clear at every session start: a system keeping an NPC linked across a save re-registers it.

Function OrphanCleanup_Initialize(Keyword travelKW, Keyword furnitureKW, Keyword followKW) Global Native
{Push the package keywords to the scanner. Callerless: the DLL resolves them by FormID at
 kDataLoaded and ignores a push once seeded; kept for an older pex.}

Function OrphanCleanup_SetArrestKeywords(Keyword arrestFollowKW, Keyword arrestSandboxKW) Global Native
{Push the arrest LinkedRef keywords (FollowTargetKW, SandboxAnchorKW). Callerless, like
 OrphanCleanup_Initialize. Every holder is reported (strArg "arrest_follow" / "arrest_sandbox");
 SeverActions_Arrest.OnOrphanCleanup skips the legitimate ones (live arrest, jail, kidnap, brawl, bodyguard).}

Function OrphanCleanup_SetArrestFactions(Faction dispatchFaction, Faction waitingArrestFaction, Faction arrestedFaction, Faction jailedFaction) Global Native
{Push the four arrest factions to the stale-membership sweep. Callerless, like
 OrphanCleanup_Initialize. The sweep reports every member ("arrest_faction_sweep"); Arrest's own
 paths clear stale tags through ClearStaleArrestState.}

Function OrphanCleanup_RegisterTraveler(Actor akActor) Global Native
{Mark a traveller's travel link as tracked, so the scan leaves it alone.}

Function OrphanCleanup_UnregisterTraveler(Actor akActor) Global Native

Function OrphanCleanup_RegisterFollower(Actor akActor) Global Native
{Mark a follower's follow link as tracked.}

Function OrphanCleanup_MarkRosterSynced() Global Native
{Release the post-load scan hold. FollowerManager.RunDeferredMaintenance calls it once the
 roster is re-registered; until then (or 120 s) no scan runs, so no real follower is stripped.}

Function OrphanCleanup_UnregisterFollower(Actor akActor) Global Native

Function OrphanCleanup_SetEnabled(Bool enabled) Global Native
{Turn the scan on or off for this session (off by default). The settings row
 orphanCleanupEnabled is what the Authority replays on load; this is the live lever.}

Bool Function OrphanCleanup_IsEnabled() Global Native
{True while the scan is on.}

Function OrphanCleanup_ClearTracking() Global Native
{Forget every registration and hold scans until OrphanCleanup_MarkRosterSynced (120 s cap).}

; === SKYRIMNET PLUGIN CONFIG (the plugin's WebUI settings; each getter returns defaultVal without it) ===

Bool Function PluginConfig_IsAvailable() Global Native
{True if SkyrimNet's plugin config is available.}

String Function PluginConfig_GetString(String path, String defaultVal) Global Native

Bool Function PluginConfig_GetBool(String path, Bool defaultVal) Global Native

Int Function PluginConfig_GetInt(String path, Int defaultVal) Global Native

Float Function PluginConfig_GetFloat(String path, Float defaultVal) Global Native

; === SKYRIMNET PUBLIC API ===

Bool Function IsPublicAPIReady() Global Native
{True if SkyrimNet's public API is available.}

String Function GetFollowerEngagement(Actor akActor) Global Native
{A follower's engagement stats as JSON.}

; Never hold raw SkyrimNet memory JSON (tens of KB) in a Papyrus string: one caught in a save
; left it unloadable. Memory context is built natively (SeverActionsNativeExt2.Native_LLM_DispatchRelationshipAssess).

; === BOOKS (continued) ===

Bool Function IsNote(Form akForm) Global Native
{True if akForm is a note rather than a regular book.}

; === SPELL DATABASE ===

Form Function FindSpellOnActor(Actor akActor, String spellName) Global Native
{A spell akActor knows, matched by name case-insensitively, or None.}

Form Function GetLearnableSpellVariant(Form akSpell) Global Native
{The version of akSpell to grant the PLAYER: the tome-taught, either-hand one. Magic overhauls
give NPCs one-hand-locked copies under the same display name (MAG_FireboltRightHand vs
MAG_Firebolt). Returns akSpell when nothing better exists.}

Bool Function IsSpellHandLocked(Form akSpell) Global Native
{True when akSpell's equip slot is RightHand or LeftHand (EitherHand, BothHands, Voice: false).}

String Function GetTeachableSpells(Actor akTeacher, Actor akLearner) Global Native
{JSON of the spells akTeacher knows and akLearner does not.}

Bool Function IsSpellDBLoaded() Global Native
{True once the spell database is built.}

String Function GetSpellDBStats() Global Native
{Spell database statistics for logging.}

; Native_EvaluateActorPackage (CastSpell's package re-evaluation) is on SeverActionsNativeExt: the DLL
; registers it there, and a declaration here fails to link.

; === FOLLOWER DATA STORE ('FLWD' cosave, pair relationships in 'FLWR') ===

Function Native_SetHome(Actor akActor, String location) Global Native
{Store akActor's home location.}

String Function Native_GetHome(Actor akActor) Global Native
{akActor's home location, or "".}

Function Native_ClearHome(Actor akActor) Global Native
{Clear akActor's home location.}

; --- Home bed: the follower owns a bed in the home cell so their sleep package uses it; the bed and its
; original owner are cosaved, and a release restores that owner ---

Bool Function Native_BedAssignment_Claim(Actor akActor) Global Native
{Release any earlier claim, then claim a bed in the PLAYER's current cell: an unowned bed, else one
 owned by a faction other than PlayerFaction, never an NPC's own bed. True if a bed was claimed; an
 exterior cell (or none) returns false with the earlier claim already released.}

Function Native_BedAssignment_Release(Actor akActor) Global Native
{Release akActor's bed to its original owner; a no-op without one.}

Int Function Native_BedAssignment_GetBedFormID(Actor akActor) Global Native
{FormID of akActor's claimed bed, or 0.}

; Native_AmbientBanter_* are on SeverActionsNativeExt.

; --- Combat style ---

Function Native_SetCombatStyle(Actor akActor, String style) Global Native
{Store akActor's combat style.}

String Function Native_GetCombatStyle(Actor akActor) Global Native
{akActor's combat style, or "".}

Function Native_ClearCombatStyle(Actor akActor) Global Native
{Clear akActor's combat style.}

; --- Relationship values ---

Function Native_SetRelationship(Actor akActor, Float rapport, Float trust, Float loyalty, Float mood) Global Native
{Set all four relationship values.}

Float Function Native_GetRapport(Actor akActor) Global Native
{Rapport; 0.0 when unset.}

Float Function Native_GetTrust(Actor akActor) Global Native
{Trust; 25.0 when unset.}

Float Function Native_GetLoyalty(Actor akActor) Global Native
{Loyalty; 50.0 when unset.}

Float Function Native_GetMood(Actor akActor) Global Native
{Mood; 50.0 when unset.}

; --- State flags ---

Function Native_SetSandboxing(Actor akActor, Bool val) Global Native

Function Native_SetInForcedCombat(Actor akActor, Bool val) Global Native

Function Native_SetSurrendered(Actor akActor, Bool val) Global Native

; --- Travel state ---

Function Native_SetTravelState(Actor akActor, String travelState, String destination) Global Native
{Set travel state and destination; empty strings clear them.}

; --- Package state ---

Function Native_SetPackageState(Actor akActor, Bool hasFollow, Bool hasTalkPlayer, Bool hasTalkNPC) Global Native

Bool Function Native_GetHasFollowPkg(Actor akActor) Global Native
{The cosaved hasFollowPkg flag: SA put akActor on its follow package (a casual follower has it without
isFollower). Bookkeeping only: a package removed by another route leaves it set.}

Function Native_SetOffscreenExcluded(Actor akActor, Bool excluded) Global Native
{Exclude a follower from off-screen life events.}

Bool Function Native_GetOffscreenExcluded(Actor akActor) Global Native

; --- Outfit exclusion ---

Function Native_SetOutfitExcluded(Actor akActor, Bool excluded) Global Native
{Exclude akActor from the whole outfit system (lock, DefaultOutfit suppression, auto-switch, alias re-equip), so another outfit mod can manage them.}

Bool Function Native_GetOutfitExcluded(Actor akActor) Global Native

; --- Roster flag ---

Function Native_SetIsFollower(Actor akActor, Bool val) Global Native
{Mark a registered follower (true) or a plain NPC row with home/data (false). True also stamps the sticky everFollower bit.}

Actor[] Function Native_GetAllTrackedFollowers() Global Native
{Every living actor whose row is a registered follower or holds a home, in any cell.}

; --- Pair relationships (inter-follower) ---

Function Native_SetPairRelationship(Actor akActor, Actor akTarget, Float affinity, Float respect, String blurb = "") Global Native
{Set how akActor feels about akTarget; blurb is the LLM's one-line summary.}

Float Function Native_GetPairAffinity(Actor akActor, Actor akTarget) Global Native
{How much akActor likes akTarget (-100 to 100); 0.0 when unset.}

Float Function Native_GetPairRespect(Actor akActor, Actor akTarget) Global Native
{How much akActor respects akTarget (0 to 100); 30.0 when unset.}

; Native_GetPairBlurb is on SeverActionsNativeExt.

String Function Native_GetAllPairJson(Actor akActor) Global Native
{akActor's inter-follower opinions as a JSON array.}

; --- Home marker slots ---

Int Function Native_AcquireHomeMarkerSlot(Actor akActor) Global Native
{akActor's home marker slot (0-39), acquiring the first free one if needed; -1 when all 40 are in use.}

Int Function Native_GetHomeMarkerSlot(Actor akActor) Global Native
{akActor's home marker slot, or -1.}

Function Native_ReleaseHomeMarkerSlot(Actor akActor) Global Native

; --- Work / Play markers ---

Function Native_SetWorkLoc(Actor akActor, ObjectReference marker) Global Native

ObjectReference Function Native_GetWorkLoc(Actor akActor) Global Native
{akActor's Work marker, or None. An Actor here means guard mode (duty on that person).}

Function Native_ClearWorkLoc(Actor akActor) Global Native

Function Native_SetPlayLoc(Actor akActor, ObjectReference marker) Global Native

ObjectReference Function Native_GetPlayLoc(Actor akActor) Global Native
{akActor's Play marker, or None.}

Function Native_ClearPlayLoc(Actor akActor) Global Native

; --- Essential status (the flag on the actor's BASE record, marked for the save) ---

Function Native_SetEssential(Actor akActor) Global Native

Function Native_ClearEssential(Actor akActor) Global Native

Bool Function Native_IsEssential(Actor akActor) Global Native

; --- Cleanup ---

Function Native_ClearFollowerData(Actor akActor) Global Native
{Clear transient state on dismiss. Home, combat style, relationships, work/schedule assignments and the player's per-NPC choices stay for a re-recruit.}

Function Native_RemoveFollowerData(Actor akActor) Global Native
{Erase akActor's row and every pair relationship naming them (force-remove, death).}

; === EQUIPMENT BLACKLIST ('BLKL' cosave, global) ===
; Items, or whole plugins, that an undress never removes.

Bool Function Native_Blacklist_IsBlacklisted(Form item) Global Native
{True if item, or its source plugin, is blacklisted.}

Function Native_Blacklist_AddPlugin(String pluginName) Global Native

Function Native_Blacklist_RemovePlugin(String pluginName) Global Native

Function Native_Blacklist_AddItem(Form item) Global Native

Function Native_Blacklist_RemoveItem(Form item) Global Native

; === OUTFIT DATA STORE ('OTFT' cosave) ===
; Per-actor outfit lock and named presets. Item lists are staged with Begin / Add / Commit, which avoids
; marshalling a Form[] into a native.

; --- Lock ---

Function Native_Outfit_BeginLock(Actor akActor) Global Native
{Start staging akActor's lock: AddLockedItem per item, then CommitLock.}

Function Native_Outfit_AddLockedItem(Actor akActor, Form item) Global Native

Function Native_Outfit_CommitLock(Actor akActor) Global Native
{Commit the staged items as akActor's active lock.}

Function Native_Outfit_ClearLock(Actor akActor) Global Native
{Clear the lock and restore the DefaultOutfit it suppressed; drops the row when nothing else is stored.}

Function Native_Outfit_ClearLockForUndress(Actor akActor) Global Native
{Clear the lock WITHOUT restoring the DefaultOutfit, suppressing it now (unique bases) if it was not,
so the engine does not redress the stripped actor on its next evaluation. The original stays parked
for Dress or an explicit unlock. Skips the player and outfit-excluded actors.}

Function Native_Outfit_RemoveLockedItem(Actor akActor, Form item) Global Native
{Remove one item from an existing lock.}

Function Native_Outfit_RemoveActor(Actor akActor) Global Native
{Erase akActor from the store (force-remove).}

Form[] Function Native_Outfit_GetLockedItems(Actor akActor) Global Native
{The locked items: the source of truth. Use it rather than a GetWornForm snapshot, which lags an async unequip.}

Bool Function Native_Outfit_IsNativeSuspended(Actor akActor) Global Native
{True while C++ has akActor's lock suspended mid-equip (read by the OutfitAlias).}

; More Native_Outfit_* natives (the migration scalars, DressStash) are on SeverActionsNativeExt.

; --- Burst strip detection ---
; 3+ external unequips within 500 ms (a bathing or animation mod stripping the actor) suspend the lock
; until ClearBurstSuppression. Recording is SeverActionsNativeExt2.Native_Outfit_RecordExternalChange.

Function Native_Outfit_ClearBurstSuppression(Actor akActor) Global Native
{End burst suppression (when the outfit system takes control back).}

Bool Function Native_Outfit_IsBurstSuppressed(Actor akActor) Global Native

Bool Function Native_Outfit_IsInAnimationScene(Actor akActor) Global Native
{True while akActor holds rank >= 0 in SexLab's or OStim's scene faction (a stuck -1 does not count).
Factions resolved by FormID, EditorID as fallback, once. Game thread.}

Form[] Function Native_Outfit_GetPresetItems(Actor akActor, String presetName) Global Native
{The items of a named preset.}

Form[] Function Native_Outfit_GetWornArmor(Actor akActor) Global Native
{Every armor akActor wears, in one call (replaces an 18-slot GetWornForm loop).}

; --- Presets ---

Function Native_Outfit_BeginPreset(Actor akActor, String presetName) Global Native
{Start staging a preset: AddPresetItem per item, then CommitPreset.}

Function Native_Outfit_AddPresetItem(Actor akActor, Form item) Global Native

Function Native_Outfit_CommitPreset(Actor akActor) Global Native
{Commit the staged items as the named preset.}

Function Native_Outfit_DeletePreset(Actor akActor, String presetName) Global Native
{Delete a preset and the active / situation references to it; drops the row when no lock or preset remains.}

; --- Situations (town, adventure, home, sleep) ---

Function Native_Outfit_SetActivePreset(Actor akActor, String presetName) Global Native
{Set the active preset's name ("" = a manual outfit).}

String Function Native_Outfit_GetActivePreset(Actor akActor) Global Native
{The active preset's name, or "" for a manual outfit.}

Function Native_Outfit_SetCurrentSituation(Actor akActor, String situation) Global Native

String Function Native_Outfit_GetCurrentSituation(Actor akActor) Global Native

Function Native_Outfit_SetAutoSwitchEnabled(Actor akActor, Bool enabled) Global Native

Bool Function Native_Outfit_GetAutoSwitchEnabled(Actor akActor) Global Native

Function Native_Outfit_SetSituationPreset(Actor akActor, String situation, String presetName) Global Native
{The preset akActor wears automatically in a situation.}

String Function Native_Outfit_GetSituationPreset(Actor akActor, String situation) Global Native
{The preset assigned to a situation, or "".}

Function Native_Outfit_ClearSituationPreset(Actor akActor, String situation) Global Native

; === SURVIVAL DATA STORE ('SURV' cosave; what the UI reads) ===

Function Native_Survival_SetNeeds(Actor akActor, Float hunger, Float fatigue, Float cold) Global Native

Function Native_Survival_AdjustNeeds(Actor akActor, Float hungerDelta, Float fatigueDelta, Float coldDelta) Global Native
{Add signed deltas to the needs (negative = fed, rested, warmed), clamped 0-100; ignored while
survival is off (needs stay frozen). Public for other mods (Hearth's camp restoration).}

Function Magelight_SetPinnedRestStop(String label) Global Native
{Set the dashboard's "where you'll rest next" label for an external caller (camp, bedroll); "" clears it.}

Function Magelight_SetCampStatus(Bool active, String location, Int occupants) Global Native
{Set the Survival page's "At Camp - N resting - <location>" badge (SeversHearth on Establish / Break).
occupants counts the player; active=false clears it.}

; Magelight_SetCampMeta / SetCampThreats / SetCampMarked are on SeverActionsNativeExt.

Float Function Native_Survival_GetHunger(Actor akActor) Global Native

Float Function Native_Survival_GetFatigue(Actor akActor) Global Native

Float Function Native_Survival_GetCold(Actor akActor) Global Native

Function Native_Survival_SetExcluded(Actor akActor, Bool excluded) Global Native
{Exclude akActor from survival tracking.}

Bool Function Native_Survival_IsExcluded(Actor akActor) Global Native

Function Native_Survival_RemoveFollower(Actor akActor) Global Native
{Erase akActor from the survival store.}

Function Native_Survival_MarkFed(Actor akActor) Global Native
{Stamp lastFedGameTime (EatFood / OnFollowerAteFood) for the care sheet's "fed N hours ago".}

; === PROMPT AVAILABILITY ===

Bool Function Native_IsPromptAvailable(String promptName) Global Native
{True if <promptName>.prompt was found at kDataLoaded, in our SkyrimNet external layer or the loose
 prompts root; a name the DLL does not list answers true. Gate every custom-prompt dispatch on it: a
 FOMOD module left out leaves its prompts absent, and a missing prompt errors in SkyrimNet.}

; === ARMOR CATALOG ===

Int Function ArmorCatalog_GetArmorCount() Global Native
{Number of indexed armor records across all plugins.}

Form Function ArmorCatalog_SearchByName(String query) Global Native
{The first armor matching query by name, or None.}

Int Function ArmorCatalog_GetPluginCount() Global Native
{Number of plugins that contain armor.}

; === OFF-SCREEN LIFE DATA STORE ('OSLD' cosave) ===
; Dismissed followers' life events, their consequences, and per-location gossip.

Function Native_OffScreen_AddEvent(Actor akActor, String summary, String eventType, Float gameTime, Bool hasConsequence, String consequenceType, Int consequenceAmount, String consequenceCrime, String involvedName) Global Native
{Add a life event (ring buffer, 20 per actor).}

Function Native_OffScreen_AddGossip(String locationName, String gossipText, Float gameTime) Global Native
{Add a gossip entry (ring buffer, 5 per location).}

Function Native_OffScreen_ClearActor(Actor akActor) Global Native
{Erase akActor's off-screen life data.}

Function Native_OffScreen_IncrementBounty(Actor akActor, Int amount) Global Native

Function Native_OffScreen_IncrementDebt(Actor akActor, Int amount) Global Native

Function Native_OffScreen_IncrementGoldEarned(Actor akActor, Int amount) Global Native

Function Native_OffScreen_IncrementGoldLost(Actor akActor, Int amount) Global Native

Function Native_OffScreen_IncrementArrestCount(Actor akActor) Global Native

Function Native_OffScreen_ClearBounty(Actor akActor) Global Native

Function Native_OffScreen_ClearDebt(Actor akActor) Global Native

String Function Native_OffScreen_ParseLLMResponse(Actor akActor, String response, Float gameTime) Global Native
{Parse an off-screen life LLM reply, store its events, and return 15 pipe-delimited fields:
summary1|type1|gossip1|summary2|type2|gossip2|conseqAction|conseqAmount|conseqReason|conseqCrime|conseqItem|conseqCategory|conseqCount|involved|diary
("" on a parse failure).}

Bool Function Native_OffScreen_RequestLifeEventLLM(Actor akActor, String contextJson, Float gameTime) Global Native
{Send the off-screen life prompt through the SkyrimNet bridge, keeping the full reply in C++ (a
Papyrus callback truncates it at ~1024 chars). The parsed result arrives as
SeverActions_OffScreenLifeReady (sender = akActor, strArg in ParseLLMResponse's format, numArg =
success). False if the custom-prompt API is unavailable or SkyrimNet refused the request.}

String Function Native_OffScreen_BuildContext(Actor akActor, Bool consequencesEnabled, Float consequenceCooldownSec, Float lastConsequenceGT, Float currentGameTime) Global Native
{The off-screen life prompt's context JSON, built natively: home, SkyrimNet social graph, dismissed
followers nearby in the same hold, consequence eligibility. "" on failure.}

String Function Native_OffScreen_GetRecentLifeEvents(Actor akActor, Int maxEvents, Float currentGameTime) Global Native
{akActor's life events for a prompt, newest first, one "- [time ago] summary [type] (with NPC)" line
each, up to maxEvents (0 = all); "" when none.}

Float Function Native_OffScreen_GetCooldownOverride(Actor akActor) Global Native
{akActor's off-screen life cooldown in game hours; 0 = none (the global min/max window applies).}

Function Native_OffScreen_SetCooldownOverride(Actor akActor, Float hours) Global Native
{Set akActor's cooldown in game hours; 0 clears it.}

; === MEMORY CREATION (SkyrimNet PublicAPI v5+) ===

Int Function Native_AddMemory(Actor akActor, String content, Float importance, String memoryType, String emotion, String location, String tagsJSON, String relatedActorsJSON) Global Native
{Create a SkyrimNet memory for akActor; returns its id (> 0), or 0 on failure. memoryType: EXPERIENCE,
RELATIONSHIP, KNOWLEDGE, LOCATION, SKILL, TRAUMA or JOY. tagsJSON: a JSON array of tag strings.
relatedActorsJSON: a JSON array of hex UUID strings.}

; === PROPERTY OWNERSHIP ===

Bool Function Native_TransferCellOwnership(Actor akNewOwner, String propertyName, Faction akFaction) Global Native
{Give a cell and its owned references to akFaction, adding akNewOwner and the residents it displaced
(a unique NPC owner, or an owner's actors in the cell) to it, and record it in PropertyStore. An empty propertyName means akNewOwner's current cell. True on success.}

Int Function Native_Property_GetOwnedCount() Global Native
{Number of properties the player owns.}

String Function Native_Property_GetOwnedNames() Global Native
{The owned properties' names, pipe-delimited.}

; --- Knowledge store: conditional knowledge entries (edited in the UI), shown by faction ---

Int Function Native_Knowledge_GetCount() Global Native

; --- Cell ownership ---

String Function Native_GetCellOwnerName(ObjectReference akRef) Global Native
{Display name of the owner of akRef's cell, or "" when unowned.}

Bool Function Native_IsCellOwner(Actor akSpeaker, String propertyName) Global Native
{True if akSpeaker owns the named cell, as its actor owner, a member of its faction owner or the jarl
of its hold (empty propertyName = akSpeaker's current cell). Guard TransferOwnership with it, so the LLM cannot have an
NPC give away a building that is not theirs.}

; === ITEM RESOLVER (fuzzy name lookup, Skyrim.esm forms preferred) ===

Bool Function Native_GiveItemByName(Actor akActor, String itemName, String category, Int count) Global Native
{Resolve itemName and add count of it to akActor. category: "weapon", "armor", "potion", "food",
"ingredient", "misc" or "any". The give is queued: true once queued, not once resolved, so resolve
first with Native_ResolveItemName.}

String Function Native_ResolveItemName(String itemName, String category) Global Native
{The in-game name a fuzzy (LLM-supplied) item name resolves to, or "".}

; === QUEST AWARENESS ('QAWR' cosave) ===
; Firsthand quest tracking per follower from quest stage events; the DLL dispatches the LLM summaries
; and the completion memories itself.

Function Native_OnFollowerRecruited(Actor akActor) Global Native
{A no-op (awareness is firsthand only); kept because FollowerManager.RegisterFollower calls it.}

Actor Function Native_PopReputationAssessRequestActor() Global Native
{The next NPC queued for a reputation blurb, or None. The player_familiarity decorator queues NPCs
who never followed (at dialogue milestones, or when their bond with the player rises) and fires
SeverActions_ReputationAssess; SeverActions_Familiarity drains the queue one at a time. An Actor,
not an Int FormID, which would sign-extend for ESL and high-index plugins.}

Function Native_QuestAwareness_SetOutputCap(Int n) Global Native
{Quest entries shown to the LLM per follower per render, clamped 1-15 (default 5). Storage is not capped by it.}

Int Function Native_QuestAwareness_GetOutputCap() Global Native

; --- User filters (cosaved): userAllow > userDeny > built-in defaults; editor IDs match case-insensitively ---

Function Native_QuestAwareness_FilterDeny(String editorID) Global Native
{Deny a quest for every follower, overriding the default, and purge its existing entries.}

Function Native_QuestAwareness_FilterAllow(String editorID) Global Native
{Allow a quest the built-in denylist blocks (Skyshards, IntelEngine, ...). Entries come from later
stage events; nothing is seeded.}

Function Native_QuestAwareness_FilterClear(String editorID) Global Native
{Drop the quest from both lists (back to the default).}

Int Function Native_QuestAwareness_FilterState(String editorID) Global Native
{0 = default, 1 = allowed, 2 = denied.}

Function Native_QuestAwareness_RemoveQuest(Actor akActor, String editorID) Global Native
{Drop one quest from one follower's awareness; filters and other followers are untouched.}

String Function Native_QuestAwareness_ListAll() Global Native
{Every (follower, quest) row as a JSON array for the UI, capped at 200: actorFid, actorName, editorID,
questName, questType, isFirsthand, isMemorized, filter (0/1/2), summary.}

String Function Native_QuestAwareness_ListForActor(Actor akActor) Global Native
{ListAll for akActor only (the Companions page's Quest Awareness tab).}

; === FRIENDLY FIRE MONITOR ===

Function FriendlyFireMonitor_SetEnabled(Bool enabled) Global Native
{Turn follower-vs-follower damage prevention on or off (Follow pushes the saved value on load).}

Bool Function FriendlyFireMonitor_IsEnabled() Global Native

; === OUTFIT SLOT SYSTEM ===
; 100 slots x 8 presets, each an Outfit + LeveledItem + Container triple scaffolded in the ESP
; (GenerateOutfitSlots / esp generate-outfit-slots). The CONTAINER is the wardrobe: a preset is worn
; through Native_OutfitSlot_DirectEquipPreset and re-applied on cell load by the OutfitAlias, never
; through SetOutfit. SeverActions_OutfitSlot still fills the LeveledItem from the chest (BuildPreset
; and every load) and Reverts it on release.

Int Function Native_OutfitSlot_AssignSlot(Actor akActor) Global Native
{akActor's slot, assigning the first free one if needed; -1 when all 100 are taken.}

Function Native_OutfitSlot_ReleaseSlot(Actor akActor) Global Native
{Release the native slot row only (no DefaultOutfit restore, chests untouched). SeverActions_OutfitSlot.ReleaseSlotFromActor is the full teardown and calls this last.}

Int Function Native_OutfitSlot_GetSlot(Actor akActor) Global Native
{akActor's slot (0-99), or -1.}

Outfit Function Native_OutfitSlot_GetOutfitForm(Int slotIdx, Int presetIdx) Global Native
{The slot's Outfit record, or None (out of range, ESP not scaffolded). Nothing is worn through it; ApplyPresetBySlot uses it as a scaffold check.}

LeveledItem Function Native_OutfitSlot_GetLvlItem(Int slotIdx, Int presetIdx) Global Native
{The slot's LeveledItem, filled and Reverted by SeverActions_OutfitSlot; nothing equips through it.}

ObjectReference Function Native_OutfitSlot_GetContainer(Int slotIdx, Int presetIdx) Global Native
{The (slot, preset) chest, or None until spawned (PlaceAtMe, then SetContainerRef).}

ObjectReference Function Native_OutfitSlot_GetSatchel(Int slotIdx) Global Native
{The slot's satchel, or None until spawned.}

Container Function Native_OutfitSlot_GetChestBase() Global Native
{The ESP's CONT record every chest and satchel is spawned from.}

Function Native_OutfitSlot_SetContainerRef(Actor akActor, Int presetIdx, ObjectReference chest) Global Native
{Record a spawned chest for akActor's slot and preset; None clears it.}

Function Native_OutfitSlot_SetSatchelRef(Actor akActor, ObjectReference satchel) Global Native
{Record a spawned satchel for akActor's slot; None clears it.}

Outfit Function Native_OutfitSlot_GetBlankOutfit() Global Native
{The empty sentinel Outfit a preset teardown sets to break outfit enforcement before restoring the original.}

Outfit Function Native_OutfitSlot_GetNakedOutfit() Global Native
{The empty sentinel Outfit for a sleepOutfit override.}

Function Native_OutfitSlot_SaveOriginalOutfit(Actor akActor) Global Native
{Record, once per slot, the base's sleepOutfit and DefaultOutfit (or the one OutfitDataStore parked). Never the Blank or Naked sentinel as the DefaultOutfit: the release would strip the actor for good.}

Outfit Function Native_OutfitSlot_GetOriginalOutfit(Actor akActor) Global Native
{The recorded original DefaultOutfit, or None.}

Outfit Function Native_OutfitSlot_GetOriginalSleepOutfit(Actor akActor) Global Native
{The recorded original sleepOutfit, or None.}

Function Native_OutfitSlot_SetPresetName(Actor akActor, Int presetIdx, String name) Global Native

String Function Native_OutfitSlot_GetPresetName(Actor akActor, Int presetIdx) Global Native
{The preset's display name; "" = an unused preset.}

Function Native_OutfitSlot_SetPresetItemCount(Actor akActor, Int presetIdx, Int count) Global Native
{Cache a preset's item count for the UI.}

Int Function Native_OutfitSlot_GetPresetItemCount(Actor akActor, Int presetIdx) Global Native
{The cached item count; 0 = empty or unused.}

Function Native_OutfitSlot_ClearPreset(Actor akActor, Int presetIdx) Global Native
{Clear a preset's name, count and situation mappings. The caller empties the chest and LeveledItem.}

Function Native_OutfitSlot_SetActivePreset(Actor akActor, Int presetIdx) Global Native
{Set the active preset index (-1 = none).}

Int Function Native_OutfitSlot_GetActivePreset(Actor akActor) Global Native
{The active preset index, or -1.}

Bool Function Native_OutfitSlot_IsPresetActive(Actor akActor) Global Native
{True if any preset is active (the OutfitAlias short-circuit).}

Int Function Native_OutfitSlot_DirectEquipPreset(Actor akActor, Int presetIdx) Global Native
{The only way a slot preset goes on. Snapshots the chest, suspends the lock, strips worn armor
 (blacklisted pieces and Devious Devices kept) and equips each item synchronously: a catalog copy
 is granted only when the actor holds none, a user-owned piece from the copy they hold (the
 player-modified stack first). A partial apply is still ACTIVE. Leaves a 2 s grace over its own equip
 events, so the caller resumes with Native_Outfit_ResumeLockKeepGrace. Returns the armor count
 verified worn (0 = nothing went on, preset stays inactive) or -1 on a hard error. Call from Papyrus
 or a MutationLane job, never inside an SKSE task.}

; --- Catalog-supplied items ---
; FormIDs a preset got from the UI catalog rather than from the actor's inventory at build time. A
; preset's teardown takes back only these; a user-owned item is never deleted.

Function Native_OutfitSlot_AddCatalogSupplied(Actor akActor, Int presetIdx, Form item) Global Native

Bool Function Native_OutfitSlot_IsCatalogSupplied(Actor akActor, Int presetIdx, Form item) Global Native

Function Native_OutfitSlot_ClearCatalogSupplied(Actor akActor, Int presetIdx) Global Native
{Clear a preset's catalog list (on overwrite or delete).}

Form[] Function Native_OutfitSlot_PopPendingCatalog(Actor akActor, String presetName) Global Native
{Take (once) the items the UI's preset save spawned from the catalog, for BuildPreset to tag with
 Native_OutfitSlot_AddCatalogSupplied.}

Function Native_OutfitSlot_SetSituationPreset(Actor akActor, String situation, Int presetIdx) Global Native
{Map a situation to a preset index; -1 clears it.}

Int Function Native_OutfitSlot_GetSituationPreset(Actor akActor, String situation) Global Native
{The preset index mapped to a situation, or -1.}

Function Native_OutfitSlot_SetAutoSwitch(Actor akActor, Bool enabled) Global Native

Bool Function Native_OutfitSlot_GetAutoSwitch(Actor akActor) Global Native
{Per-actor auto-switch (default true).}

Actor[] Function Native_OutfitSlot_GetAssignedActors() Global Native
{Every actor holding a slot (SeverActions_OutfitSlot.GetAllAssignedActors).}

ReferenceAlias Function Native_OutfitSlot_FindAliasByName(String aliasName) Global Native
{The SeverActions quest alias with this ALID name, or None.}

ReferenceAlias Function Native_OutfitSlot_GetAliasForSlot(Int slotIdx) Global Native
{The "OutfitSlotNN" alias for a slot (0-99), or None.}

Actor[] Function Native_Outfit_GetActorsWithPresets() Global Native
{Every actor with a user-named preset in OutfitDataStore (the slot migration's source).}

Int Function Native_Outfit_GetPresetCount(Actor akActor) Global Native
{Number of akActor's user-named presets in OutfitDataStore (internal _* presets excluded).}

String Function Native_Outfit_GetPresetNameAt(Actor akActor, Int idx) Global Native
{The idx-th user-named preset (see Native_Outfit_GetPresetCount), or "".}

Function Native_OutfitSlot_Log(String msg) Global Native
{Write msg to SeverActionsNative.log with an [OutfitSlot] prefix (seen without Papyrus logging).}

; === GUARDIAN CONTAINERS ===
; Some custom followers' mods (Daegon) enforce an outfit from a container through a guardian alias.
; Before a preset applies, a registered guardian container is emptied into the satchel, so the alias's
; GetItemCount check fails; the stowed items go back when the preset is cleared.

Bool Function Native_OutfitSlot_AddGuardian(Actor akActor, ObjectReference guardianContainer) Global Native
{Register a guardian container; false if already registered or akActor has no slot.}

Function Native_OutfitSlot_RemoveGuardian(Actor akActor, ObjectReference guardianContainer) Global Native

ObjectReference[] Function Native_OutfitSlot_GetGuardians(Actor akActor) Global Native

Function Native_OutfitSlot_SetStowedItems(Actor akActor, ObjectReference guardianContainer, Form[] items) Global Native
{Record the items stowed out of a guardian container, to restore on clear.}

Form[] Function Native_OutfitSlot_GetStowedItems(Actor akActor, ObjectReference guardianContainer) Global Native

Function Native_OutfitSlot_ClearStowedItems(Actor akActor, ObjectReference guardianContainer) Global Native
{Forget the stowed list (after a restore).}

; The Healer and CellCatchup natives are on SeverActionsNativeExt: one declaration over the 511 cap and
; every native on the class fails to link, silently.
