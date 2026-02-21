# SeverActions — SkyrimNet Action Pack

<p align="center">
  <strong>A comprehensive action, prompt, and behavior pack for SkyrimNet</strong><br>
  <em>Give NPCs the ability to act, not just talk.</em>
</p>

<p align="center">
  <code>60 Actions</code> &nbsp;&middot;&nbsp; <code>20 Context Prompts</code> &nbsp;&middot;&nbsp; <code>189 Native C++ Functions</code> &nbsp;&middot;&nbsp; <code>~21,000 Lines of Papyrus</code>
</p>

---

## Overview

**SeverActions** extends SkyrimNet with a full suite of actions, prompts, and a native C++ SKSE plugin that together let NPCs interact with the game world in meaningful ways. NPCs can follow you, travel across Skyrim, craft items at forges, cook meals, brew potions, read books aloud, manage their outfits with persistent outfit locking, handle gold and debt systems, sit in chairs, fight enemies, get arrested and escorted to jail by guards, and much more — all driven naturally through conversation.

Every system is designed around one principle: **the AI decides what to do, and the mod makes it happen in-game.**

---

## Features at a Glance

### Action Modules

| Module | Actions | Description |
|--------|---------|-------------|
| **Basic** | `StartFollowing` `StopFollowing` `Relax` `StopRelaxing` `PickUpItem` `UseItem` `GiveItem` `BringItem` `LootContainer` `LootCorpse` `ReadBook` `StopReading` | Core commands — follow, relax, pick up items, loot, and read books aloud |
| **Travel** | `TravelToPlace` `TravelToLocation` `ChangeTravelSpeed` `CancelTravel` | NPCs navigate to named locations (cities, inns, dungeons) using a native travel marker database |
| **Combat** | `AttackTarget` `CeaseFighting` `Yield` | Engage or disengage from combat based on conversation |
| **Outfit** | `Undress` `GetDressed` `EquipItemByName` `UnequipItemByName` `EquipMultipleItems` `UnequipMultipleItems` `SaveOutfitPreset` `ApplyOutfitPreset` | Full outfit management — equip/unequip by name, batch equip, save/recall presets, persistent outfit locking across cell transitions |
| **Follower** | `SetCompanion` `DismissFollower` `CompanionWait` `CompanionFollow` `AssignHome` `SetCombatStyle` `FollowerLeaves` `AdjustRelationship` | Companion framework with relationship tracking (rapport, trust, loyalty, mood), NFF/EFF integration, combat styles, home assignment. Wait/Follow work on any NPC |
| **Furniture** | `SitOrLayDown` `StopUsingFurniture` | NPCs use chairs, benches, beds, and crafting stations with automatic cleanup |
| **Economy** | `GiveGold` `GiveGoldTrue` `CollectPayment` `ExtortGold` `AddToDebt` `CreateDebt` `CreateRecurringDebt` `ForgiveDebt` | Gold transactions and debt system — gifts, payments, extortion, tabs, credit limits, due dates, auto-growth, and faction-aware guard reporting. CollectPayment auto-reduces open debts |
| **Crafting** | `CraftItem` `CookMeal` `BrewPotion` | Full crafting pipeline — NPC walks to the nearest workstation, crafts/cooks/brews, then delivers the item |
| **Arrest** | `ArrestPlayer` `ArrestNPC` `DispatchGuardToArrest` `DispatchGuardToHome` `AddBountyToPlayer` `AcceptPersuasion` `RejectPersuasion` `FreeFromJail` `OrderJailed` `OrderRelease` | Full crime and justice system — guards track bounties, dispatch across cells, escort prisoners, investigate homes, and handle judgment |

### Context Prompts

Prompts inject real-time game state into the AI's context so NPCs *know* about the world around them:

| Prompt | What NPCs Know |
|--------|----------------|
| **Known Spells** | Their own spell repertoire |
| **Gold Awareness** | How much gold they're carrying |
| **Inventory** | What items they have |
| **Nearby Objects** | Surrounding items, containers, flora, and furniture |
| **Combat Status** | Whether they're in combat and against whom |
| **Survival Needs** | Hunger, cold exposure, and fatigue levels |
| **Faction Reputation** | Player's guild standings and rank |
| **Guard Bounty** | Player's bounty in the current hold |
| **Jailed Status** | That they're imprisoned and why |
| **Merchant Inventory** | Their shop stock and pricing (location-restricted or always-on) |
| **Debt Context** | Financial obligations — who owes what, due dates, credit limits, payment rules |
| **Dialogue Rules** | Anti-hallucination — prevents NPCs from echoing system/action text in dialogue |
| **Book Reading** | Strict reading rules — NPCs read only real book text, never fabricated content |
| **Follower Context** | Relationship values (rapport/trust/loyalty/mood), morality, combat style, and companion behavior guidelines with relationship-influenced moral flexibility |
| **Follower Action Guidance** | Relationship value calibration (AdjustRelationship ranges), companion recruitment threshold, and FollowerLeaves emotional weight |

### Adult Content Modules (Optional)

| Module | Requires | Description |
|--------|----------|-------------|
| **OSL Aroused Action + Prompt** | OSL Aroused | Arousal awareness and modification |
| **SL Aroused Action + Prompt** | SexLab Aroused | Arousal awareness and modification |
| **Fertility Status Prompt** | Fertility Mode | Pregnancy and fertility cycle awareness |
| **Abort Pregnancy Trigger** | Fertility Mode | Event trigger for pregnancy termination |

### Optional Prompt Overrides

These replace SkyrimNet's default prompts with improved versions. Install via FOMOD if you experience specific issues:

| Module | What It Replaces | Why |
|--------|-----------------|-----|
| **Strict Action Selector** | `native_action_selector.prompt` | Reinforces one-action-per-turn rule. Prevents models (especially Grok, non-Claude) from outputting duplicate or triple actions |
| **Enhanced Target Selectors** | `dialogue_speaker_selector.prompt` `player_dialogue_target_selector.prompt` | Improved speaker/target routing with companion awareness tags, conversation momentum, crosshair weighting, and NPC-to-NPC dialogue support |

---

## Native C++ Plugin — `SeverActionsNative.dll`

The included SKSE plugin (189 native functions) replaces slow Papyrus operations with native C++ implementations, providing 100-2000x performance improvements across all major systems:

| System | What It Does |
|--------|--------------|
| **String Utilities** | Native `StringToLower`, `HexToInt`, `TrimString`, `EscapeJsonString`, case-insensitive search/compare |
| **Recipe Database** | Auto-scan of all COBJ records at game load — every vanilla + modded smithing/cooking/smelting recipe, instantly searchable |
| **Alchemy Database** | Auto-scan of all AlchemyItem records — potions, poisons, foods, ingredients with effect-based search |
| **Location Resolver** | Auto-scan of all cells and locations — fuzzy matching, semantic terms (*outside*, *upstairs*), Levenshtein typo tolerance |
| **Actor Finder** | NPC lookup by name across all loaded actors — fuzzy matching, home location detection, NPC Names Distributor integration |
| **Position Snapshots** | Off-screen NPC position tracking — `GetDistanceBetweenActors` works even when NPCs are unloaded |
| **Stuck Detector** | Movement tracking for traveling NPCs — progressive recovery: nudge → leapfrog → teleport |
| **Collision Manager** | Toggle NPC-NPC collision (`SetActorBumpable`) — allows escorts to clip through crowds without affecting combat |
| **Inventory Search** | Item search by name in any actor's inventory or container — `FindItemByName`, `FindWornItemByName` for equipped items |
| **Batch Equip/Unequip** | `EquipItemsByName` / `UnequipItemsByName` — comma-separated batch operations with single inventory pass |
| **Nearby Search** | Single-pass search for items, containers, forges, cooking pots, alchemy labs, flora, and evidence |
| **Furniture Manager** | Auto-removal of furniture packages when player moves away or changes cells |
| **Sandbox Manager** | Auto-removal of sandbox packages with distance/cell-change cleanup |
| **Dialogue Animations** | Conversation idle animations on NPCs in dialogue packages |
| **Crime Utilities** | Access to jail markers, stolen goods containers, jail outfits from crime factions |
| **Survival System** | Follower tracking, food detection, weather/cold calculation, heat source detection, armor warmth |
| **Book Utilities** | Native book text extraction — `GetBookText`, `FindBookInInventory`, `ListBooks` |
| **Yield Aggression Monitor** | TESHitEvent-based monitoring that restores yielded NPC aggression when attacked again |
| **Teammate Monitor** | Periodic scanning of loaded actors for `SetPlayerTeammate` changes — fires mod events for instant follower onboarding without save/load |
| **Fertility Mode Bridge** | Cached fertility state lookups, cycle tracking, pregnancy status |
| **NSFW Utilities** | High-performance JSON assembly for SexLab event data (500-2000x faster than Papyrus) |

---

## Key Systems

### Follower Framework

A relationship-driven companion system where NPCs remember how they feel about the player and act accordingly:

- **Relationship tracking** — Rapport, Trust, Loyalty, and Mood on -100/+100 scales (Mood 0-100), persisted via StorageUtil
- **Morality system** — 4-tier morality (0=no morals, 1=violent but honest, 2=petty theft OK, 3=strict moral code) with relationship-based flexibility — NPCs with high rapport/trust/loyalty will bend their rules more for a player they care about
- **Framework integration** — Automatically detects Nether's Follower Framework (NFF) or Extensible Follower Framework (EFF) and routes recruit/dismiss through the framework's controller when present, falls back to vanilla teammate system when neither is installed. 4-way dismiss routing: NFF > EFF > custom (preserves pre-existing teammate status) > vanilla. **NFF ignore token detection** — custom AI followers (Inigo, Lucien, Kaidan, etc.) with NFF's `nwsIgnoreToken` are automatically routed to track-only mode instead of through NFF, preventing conflicts with their custom AI. **MCM recruitment mode toggle** — "Auto" (default, uses NFF/EFF when installed, respects ignore tokens) or "SeverActions Only" (bypasses NFF/EFF entirely, uses our own alias-based follow system). Takes effect on next recruit
- **Dual follow system** — Casual follow (SkyrimNet package for guards and random NPCs) and companion follow (CK alias-based package with LinkedRef for formal companions) operate independently without interfering with each other
- **Instant detection** — Native C++ teammate monitor scans loaded actors every second; followers recruited via vanilla dialogue or any mod are detected and onboarded within ~1 second, no save/load required
- **Auto-detection on load** — Followers recruited outside SeverActions while the mod was inactive are automatically detected and tracked on game load
- **Combat styles** — Aggressive, defensive, ranged, healer, or balanced — configurable per follower
- **Home assignment** — NPCs can be assigned a home location and will return there when dismissed
- **Relationship persistence** — All relationship data survives dismissal, re-recruitment, and temporary teammate status changes (IntelEngine, etc.); returning followers are recognized and keep their full relationship history
- **Relationship cooldown** — Configurable per-actor cooldown (default 2 minutes) prevents the AI from spamming relationship changes every dialogue line
- **Outfit persistence** — Outfit locks survive dismissal — dismissed followers keep their equipped outfits when sent home
- **Up to 10 companions** — Default max of 10 simultaneous followers, configurable up to 20 via MCM
- **Hotkeys and wheel menu** — Dedicated hotkeys for follow toggle, dismiss all, set companion, and wait/resume. UIExtensions wheel menu with all actions in one place
- **MCM configuration** — Per-follower sliders for all relationship values, combat style dropdown, survival stats display, and outfit lock status

### Outfit Manager

NPCs can equip and unequip items by name, handle multiple items in a single action, save/recall outfit presets, and keep their outfits persistent across cell transitions:

- **Name-based equipping** — "Put on the steel gauntlets" uses C++ `FindItemByName` for fast inventory search, Papyrus `EquipItem` for thread-safe equipping
- **Batch operations** — "Put on steel gauntlets, iron helmet, and glass cuirass" in a single action via comma-separated item names
- **Outfit presets** — "Save what you're wearing as your combat outfit" snapshots all worn items; "Change into your home clothes" strips current gear and equips the saved preset
- **Persistent outfit locking** — Locked outfits survive cell transitions, save/load, dismissal, and engine auto-equip. Uses per-follower ReferenceAlias slots with `OnLoad`/`OnCellLoad`/`OnObjectUnequipped` events for zero-flicker re-equipping. Outfit-locked actors are tracked in a persistent list so alias slots are reassigned even for dismissed followers after save/load. Suspend/resume mechanism prevents the alias re-equip guard from fighting the outfit system's own equip/unequip operations (e.g., switching presets)
- **MCM toggle** — Outfit lock system can be enabled/disabled via MCM. When disabled, gear reverts to engine-default behavior on next cell transition; lock data is preserved and resumes when re-enabled
- **Animations** — Integrates with Immersive Equipping Animations for slot-appropriate dress/undress animations
- **Hybrid architecture** — C++ for inventory searching (fast), Papyrus for equipping (thread-safe). Direct C++ `ActorEquipManager::EquipObject()` can silently fail from Papyrus worker threads.

### Debt System

A full financial obligation system where NPCs can track debts, tabs, and credit:

- **Debt creation** — `CreateDebt` for one-time debts, `CreateRecurringDebt` for periodic charges (rent, services), `AddToDebt` for adding charges to existing tabs
- **Auto-debt from GiveItem** — When an NPC gives an item to someone who already has an open tab, the item's gold value is automatically added to their debt. No double-charging with `AddToDebt`
- **Payment integration** — `CollectPayment` automatically reduces matching debts by the amount paid. Partial payments reduce the balance; full payments clear the debt entirely
- **Credit limits** — Optional per-debt credit caps that prevent further charges once exceeded
- **Due dates** — Optional deadlines tracked in game hours with overdue detection
- **Auto-growth** — Debts can accumulate automatically when items are given to debtors
- **Faction-aware reporting** — NPCs can report unpaid debts to guards of the appropriate hold faction
- **Debt context prompt** — NPCs involved in debts see a summary of all financial obligations in their AI context (available in both Economy-Anywhere and Economy-LocationOnly prompt modules)
- **`GiveGoldTrue`** — Unconditional gold transfer that bypasses debt checks, for gifts, rewards, and loot distribution

### Book Reading

NPCs can read any book from their inventory aloud, using the actual in-game book text — not LLM hallucinations.

1. Player: *"Read me that book."*
2. AI selects `ReadBook` — native DLL extracts the full book text
3. Book text is injected into the prompt with strict reading rules
4. NPC reads word-for-word, continuing across multiple responses
5. When finished, NPC uses `StopReading` and can share thoughts in character

The system enforces that NPCs **never fabricate book content** — an always-visible prompt rule prevents the AI from reciting from memory before or during reading.

### Guard Dispatch & Escort

A full cross-cell arrest system that works even when the guard and target are in different cells:

```
Player tells guard to arrest someone
        |
Guard pathfinds to target (even through load doors)
        |
Arrest performed (cuffs, factions, follow package)
        |
Guard escorts prisoner back to sender or jail
        |
Judgment phase — sender decides release or jail
```

**Off-screen intelligence:**
- **Position snapshots** track NPCs even when unloaded, enabling distance-based arrival detection
- **Tiered off-screen handling** — trust AI pathfinding first (2 min), nudge toward exit door second, teleport only as last resort
- **Combat suppression** — guard aggression/confidence saved and zeroed during escort, restored on arrival
- **Rubber-band tethering** — prisoners snap back to their guard if they drift too far off-screen
- **Stuck recovery** — progressive escalation from package re-evaluation to leapfrogging to door-based redirect
- **NPC Names Distributor** — guards can find NPCs by their NND-assigned names (e.g., "Harold" for a Bandit)

### Crafting Pipeline

```
Player says something in conversation
        |
SkyrimNet AI decides an action is appropriate
        |
Action YAML defines parameters and eligibility
        |
Papyrus script executes the action in-game
        |
Events are registered back to SkyrimNet for narration
```

**Example — Crafting an Iron Sword:**
1. Player: *"Can you make me a sword?"*
2. AI selects `CraftItem` with `itemName: "iron sword"`
3. Native RecipeDB finds the iron sword COBJ record instantly
4. NPC walks to the nearest forge using AI packages
5. Crafting animation plays for a configurable duration
6. NPC walks to the player and plays a give animation
7. Iron sword is transferred to the player's inventory
8. A narration event fires confirming the item was delivered

### Survival Tracking

Followers track hunger, fatigue, and cold exposure on a 0-100 scale with native calculations:

- **Cold exposure** factors in weather severity, geographic region, equipped armor warmth, and proximity to heat sources (campfires, forges, hearths)
- **Hunger** — Food restores 40 points, beverages (ales, meads, wines) restore 15, and regular potions restore 10
- **Auto-eat** triggers at staggered 10-point brackets (50, 60, 70, 80, 90, 100) — followers attempt to eat from their inventory at each bracket, with natural gaps for AI-driven eating in between
- **MCM display** — Per-follower hunger, fatigue, and cold percentages with severity labels shown in the Followers MCM page
- **All calculations native** — 100-200x faster than equivalent Papyrus loops

---

## Installation

### Requirements

- [Skyrim Special Edition](https://store.steampowered.com/app/489830/The_Elder_Scrolls_V_Skyrim_Special_Edition/)
- [SKSE64](https://skse.silverlock.org/)
- SkyrimNet
- [PapyrusUtil SE](https://www.nexusmods.com/skyrimspecialedition/mods/13048)
- [powerofthree's Papyrus Extender](https://www.nexusmods.com/skyrimspecialedition/mods/22854)
- [JContainers SE](https://www.nexusmods.com/skyrimspecialedition/mods/16495) *(only needed for NSFW module)*

### Optional Integrations

| Mod | Integration |
|-----|-------------|
| [Nether's Follower Framework](https://www.nexusmods.com/skyrimspecialedition/mods/55653) | Follower recruit/dismiss routed through NFF when detected — prevents faction conflicts |
| [Extensible Follower Framework](https://www.nexusmods.com/skyrimspecialedition/mods/7003) | Follower recruit/dismiss routed through EFF when detected (NFF takes priority if both installed) |
| [NPC Names Distributor](https://www.nexusmods.com/skyrimspecialedition/mods/81214) | Guard dispatch can find NPCs by their NND-assigned names |
| [Immersive Equipping Animations](https://www.nexusmods.com/skyrimspecialedition/mods/70249) | Slot-appropriate equip/unequip animations for outfit actions |
| [Fertility Mode Reloaded](https://www.loverslab.com/) | Pregnancy and fertility cycle awareness |
| [OSL Aroused](https://www.nexusmods.com/skyrimspecialedition/mods/74037) | Arousal state awareness and modification |
| [SexLab Aroused](https://www.loverslab.com/) | Arousal state awareness and modification |

### FOMOD Installer

Install with any mod manager (MO2, Vortex). The FOMOD installer lets you pick exactly which modules you want:

1. **Page 1 — Action Modules**: Choose which actions NPCs can perform
2. **Page 2 — Prompt Modules**: Choose context awareness, optional prompt overrides (action selector, target selectors)
3. **Page 3 — Adult Content**: Optional modules for supported adult mods

The **Core** files are always installed and include all Papyrus scripts, the native DLL, and the ESP plugin.

---

## Project Structure

```
SeverActions/
+-- 00 Core/                              # Always installed
|   +-- SeverActions.esp                  # Plugin file
|   +-- Interface/Translations/           # MCM translation strings
|   +-- SKSE/Plugins/
|   |   +-- SeverActionsNative.dll        # Native C++ SKSE plugin (189 functions)
|   |   +-- SeverActionsNative.toml       # Plugin configuration
|   +-- Scripts/                          # Compiled Papyrus scripts (.pex)
|   +-- Source/
|       +-- Scripts/                      # Papyrus source scripts (.psc)
|       +-- BuildStubs/                   # Compile-time stubs for soft dependencies (NFF, EFF)
|
+-- Actions/                              # Action YAML configs (selectable)
|   +-- Basic/                            # Follow, wait, relax, items, loot, read books
|   +-- Travel/                           # Travel to locations
|   +-- Combat/                           # Attack, cease, yield
|   +-- Outfit/                           # Equip/unequip by name, batch equip, presets
|   +-- Follower/                         # Companion framework — recruit, dismiss, relationship, combat style
|   +-- Furniture/                        # Sit, lay down, stand up
|   +-- Economy/                          # Give gold, collect, extort
|   +-- Crafting/                         # Craft, cook, brew
|   +-- Arrest/                           # Arrest, dispatch, bounty, jail, judgment
|   +-- Adult-OSLAroused/                 # OSL Aroused integration
|   +-- Adult-SLOAroused/                 # SL Aroused integration
|
+-- Prompts/                              # Context prompt templates (selectable)
|   +-- Core/                             # Spells, gold, inventory, nearby, book reading, dialogue rules
|   +-- Combat/                           # Combat awareness
|   +-- Survival/                         # Hunger, cold, fatigue
|   +-- Faction/                          # Guild reputation
|   +-- Arrest/                           # Bounty and jail status
|   +-- Follower/                         # Relationship context and action guidance
|   +-- Economy-Anywhere/                 # Merchant + debt context (always active)
|   +-- Economy-LocationOnly/             # Merchant + debt context (location-restricted)
|   +-- ActionSelector/                   # Optional: strict action selector override
|   +-- TargetSelectors/                  # Optional: enhanced speaker/target selectors
|   +-- Adult-OSLAroused/                 # Arousal awareness (OSL)
|   +-- Adult-SLOAroused/                 # Arousal awareness (SLO)
|   +-- Adult-Fertility/                  # Fertility cycle awareness
|
+-- Triggers/                             # Event triggers
|   +-- Adult/                            # Abort Pregnancy trigger
|
+-- fomod/                                # FOMOD installer config
    +-- info.xml
    +-- ModuleConfig.xml
```

---

## Papyrus Scripts

| Script | Lines | Purpose |
|--------|------:|---------|
| `SeverActions_Arrest` | 4,879 | Crime system — bounty tracking, guard dispatch, cross-cell escort, persuasion, judgment, jail processing |
| `SeverActions_Travel` | 1,694 | Travel system — location lookup, walking packages, speed control, stuck recovery |
| `SeverActions_MCM` | 1,611 | Mod Configuration Menu — toggle features, adjust settings, per-follower relationship sliders, survival stats, outfit lock status |
| `SeverActions_Survival` | 1,441 | Follower survival — hunger, cold, fatigue tracking with native calculation, beverage detection |
| `SeverActions_Loot` | 1,236 | Container looting, corpse searching, item pickup, flora harvesting, book reading |
| `SeverActions_Crafting` | 1,187 | Full crafting pipeline — forge/cooking/alchemy with native DB integration |
| `SeverActions_FollowerManager` | 1,363 | Follower framework — roster, relationships, NFF/EFF integration, 4-way dismiss routing, instant teammate detection via native DLL events, combat styles, home assignment, outfit slot management |
| `SeverActions_Combat` | 1,076 | Combat actions — attack, cease, yield with C++ aggression restoration monitor |
| `SeverActions_Debt` | 1,272 | Debt/tab system — creation, tracking, auto-growth, credit limits, due dates, payment reduction, faction reporting, complaint summaries |
| `SeverActions_Outfit` | 1,260 | Equipment management — equip/unequip by name, batch operations, outfit presets, persistent outfit locking with known-item lock |
| `SeverActionsNative` | 799 | Native DLL function declarations (189 functions) |
| `SeverActions_Hotkeys` | 662 | Hotkey registration and handling — follow, dismiss, wait, companion, yield, outfit, furniture |
| `SeverActions_FertilityMode_Bridge` | 424 | Fertility Mode data caching bridge to native DLL |
| `SeverActions_Init` | 424 | Mod initialization, database loading, event registration, follower framework init |
| `SeverActions_SpellTeach` | 380 | Spell teaching system |
| `SeverActions_WheelMenu` | 420 | UIExtensions wheel menu — all actions in one radial interface with context-aware labels |
| `SeverActions_EatingAnimations` | 338 | TaberuAnimation.esp integration — keyword-based food eating animations |
| `SeverActions_Follow` | 506 | Dual follow system — casual follow (SkyrimNet package) and companion follow (CK alias-based with LinkedRef), sandbox management, alias slot assignment |
| `SeverActions_Currency` | 311 | Gold transactions with conjured gold fallback, auto-debt reduction on CollectPayment |
| `SeverActions_Furniture` | 237 | Furniture interaction with native auto-cleanup |
| `SeverActions_SLOArousal` | 164 | SexLab Aroused integration |
| `SeverActions_Arousal` | 142 | OSL Aroused integration — arousal state decorator and modification |
| `SeverActions_OutfitAlias` | 91 | Per-follower ReferenceAlias for zero-flicker outfit persistence across cell transitions |
| | **~21,000** | **Total** |

---

## Configuration

The mod is configurable through the **MCM (Mod Configuration Menu)** in-game:

- **Crafting** — Craft time duration, forge search radius, material requirements
- **Travel** — Travel speed, marker database selection
- **Furniture** — Auto-stand distance (how far the player must move before NPCs stand up)
- **Survival** — Hunger/cold/fatigue thresholds and update intervals
- **Hotkeys** — Configurable keybinds for follow, dismiss, wait/resume, set companion, yield, outfit, stand up. UIExtensions wheel menu key. Target mode selection (crosshair, nearest NPC, last talked to)
- **Followers** — Per-follower Rapport, Trust, Loyalty, Mood sliders, Combat Style dropdown, survival stats (hunger/fatigue/cold percentages), outfit lock status. Max companions slider (up to 20). Relationship cooldown slider (60-300 seconds). Outfit lock system toggle. Recruitment Mode dropdown (Auto / SeverActions Only)
- **Crime** — Per-hold bounty display with clear options
- **Dialogue Animations** — Enable/disable conversation idle animations
- **Debug** — Verbose logging for troubleshooting dispatch and escort behavior

---

## Version History

| Version | Changes |
|---------|---------|
| **0.98** | **Debt System** — Full financial obligation tracking with 5 new actions (`AddToDebt`, `CreateDebt`, `CreateRecurringDebt`, `ForgiveDebt`, `GiveGoldTrue`). NPCs can run tabs, set credit limits, assign due dates, and report overdue debts to faction-appropriate guards. `GiveItem` auto-adds item value to existing debts (no double-charging). `CollectPayment` auto-reduces matching debts — partial payments reduce the balance, full payments clear it. Debt context prompt shows all obligations in the NPC's AI context. Removed `SettleDebt` action — LLMs naturally use `CollectPayment` instead. **Outfit Lock Race Condition Fix** — Fixed bug where outfit lock captured the old outfit instead of the newly equipped one. Root cause: Papyrus `OnObjectUnequipped` events fire on separate stacks after the equip function returns, and `GetWornForm()` returns stale data before the engine finalizes equip state. New `LockEquippedOutfit` function builds the lock from KNOWN equipped items (guaranteed fresh) merged with `GetWornForm` for unchanged slots. Rewired `EquipMultipleItems`, `EquipItemByName`, `Dress`, and `ApplyOutfitPreset`. Also fixed `Dress_Execute` early return not calling `ResumeOutfitLock` (would permanently suspend the lock). **Anti-Hallucination Prompt** — New `0600_severactions_dialogue_rules.prompt` prevents NPCs from echoing system/action text (gold amounts, debt totals, `[item_given]` tags, "X gave Y to Z" patterns) in their dialogue or narration. **AdjustRelationship Priority Fix** — Demoted from "use after EVERY exchange" to LOW PRIORITY fallback, fixing issue where models chose it over gameplay actions like `CollectPayment` or `GiveItem`. **Bounty Awareness** — New prompt gives guards awareness of player's bounty in the current hold. **FOMOD Prompt Overrides** — Two new optional modules: Strict Action Selector (reinforces one-action-per-turn, prevents duplicate action calls from models like Grok) and Enhanced Target Selectors (improved speaker/target routing with companion tags, conversation momentum, crosshair weighting). **Action YAML Audit** — All 60 actions updated with tracking-only mode support. |
| **0.97.5** | **NFF Ignore Token Detection** — Custom AI followers (Inigo, Lucien, Kaidan, etc.) that carry NFF's `nwsIgnoreToken` (distributed via SPID) are now automatically detected and routed to track-only mode instead of through NFF. Track-only followers get full relationship tracking, outfit locking, and survival monitoring without any package or alias injection that could conflict with their custom AI. New `HasNFFIgnoreToken()` checks actor inventory for the token via `Game.GetFormFromFile(0x051CFC8D, "nwsFollowerFramework.esp")`. New `ShouldUseFramework()` provides centralized routing decisions across all 6 onboarding paths (`RegisterFollower`, `UnregisterFollower`, `OnNativeTeammateDetected`, `DetectExistingFollowers`, `Maintenance`, follow system injection). **MCM Recruitment Mode Toggle** — New "Recruitment Mode" dropdown on the Followers MCM page with two options: Auto (default — uses NFF/EFF when installed, respects ignore tokens) and SeverActions Only (bypasses NFF/EFF entirely, uses our own alias-based follow system for all followers). Takes effect on next recruit — existing followers are not live-swapped. **Fertility Mode Bridge Fix** — Fixed `Cannot cast from None to Form[]` Papyrus error when Fertility Mode's internal arrays haven't initialized yet. All FM array accesses (`TrackedActors`, `LastConception`, `LastBirth`, `BabyAdded`, `LastOvulation`, `LastGameHours`, `LastGameHoursDelta`, `CurrentFather`) are now cached to local variables with None guards before indexing, preventing cascading errors during game load. |
| **0.97** | **Returning Follower Recognition** — Followers who temporarily lose teammate status (IntelEngine tasks, mod interactions, etc.) are now recognized as returning companions instead of being treated as new recruits. Uses `StorageUtil.HasFloatValue(KEY_RAPPORT)` to detect prior relationship history — returning followers keep all rapport/trust/loyalty/mood values, skip the recruitment bonus (+5 rapport/trust), and show "has returned" instead of "has joined you as a companion." Applied consistently across all three onboarding paths (`RegisterFollower`, `OnNativeTeammateDetected`, `DetectExistingFollowers`). No `follower_recruited` event fires for returning followers, preventing the AI from treating them as strangers. **Disabled OnNativeTeammateRemoved** — The handler that reacted to `SetPlayerTeammate(false)` is now a no-op. Previously, mods like IntelEngine that temporarily strip teammate status would trigger a full `UnregisterFollower` — clearing the follower flag, removing from faction, and firing a dismissal event. When teammate status was restored, the follower was re-detected as brand new, losing all relationship history. Matches 0.95 behavior where this handler did not exist. Our own `DismissFollower` path handles cleanup when followers are actually dismissed. **Relationship Cooldown** — New per-actor cooldown on `AdjustRelationship` calls using `Utility.GetCurrentRealTime()`. Default 120 seconds (2 minutes). Prevents the AI from spamming relationship changes every dialogue line. MCM slider from 60-300 seconds in 15-second steps. **Summoned Creature Filter** — `IsCommandedActor()` checks added to `DetectExistingFollowers` and `OnNativeTeammateDetected` to prevent conjured creatures (atronachs, Durnehviir, raised dead, etc.) from entering the follower system. **Staggered Auto-Eat** — Auto-eat no longer fires every update tick once hunger passes threshold. Instead uses 10-point bracket system: first attempt at threshold (default 50), then retries at 60, 70, 80, 90, 100. Each bracket fires only once — gives the AI natural windows to choose the eat action between attempts. Bracket tracker resets when eating succeeds through any path. **Outfit Lock Toggle** — New MCM toggle to enable/disable the outfit lock system. When disabled, `SnapshotLockedOutfit` and `ReapplyLockedOutfit` are skipped — the game engine handles companion gear normally. Existing lock data is preserved in StorageUtil and resumes when re-enabled. Default: enabled. **Fertility Prompt Rewrite** — Rewrote menstrual cycle prompt blocks to use vague mood/energy language instead of clinical terms. LLMs were latching onto cycle details (pain, bleeding) too heavily in dialogue and diary entries. Menstruating → "low energy, occasional discomfort." PMS → "run-down and on edge." Ovulating → "more confident, energetic." Added explicit NEVER rules preventing cycle/period mentions in dialogue or diary entries. |
| **0.96.5** | **Relationship Persistence Fix** — Fixed critical bug where follower relationship values (rapport, trust, loyalty, mood) were reset on dismiss and re-recruit. Root cause: `OnNativeTeammateDetected` and `DetectExistingFollowers` failed to track recruitment state, causing re-detected followers to be treated as new. Fix replaces counter-based guard (`timesRecruited`) with direct `StorageUtil.HasFloatValue` check — if rapport already exists on the actor, defaults are never overwritten. **AdjustRelationship Clarity** — Rapport, trust, and loyalty descriptions now explicitly state they are specific to the player relationship (uses `{{ player.name }}` template). Mood documented as general emotional state that can change from any source (NPC arguments, environmental stress, etc.). Prevents AI from adjusting rapport/trust/loyalty based on non-player interactions. **Removed Dismissal Penalty** — Dismissing a follower no longer applies automatic -3 rapport / -1 trust hit. Relationship changes from dismissal are now handled naturally by the AI through conversation context. **Mood Decay Rate** — Reduced mood drift toward baseline from 2.0 to 1.0 points per game hour. |
| **0.96** | **Instant Teammate Detection** — Native C++ `TeammateMonitor` periodically scans loaded actors (~1 second intervals) for `SetPlayerTeammate` flag changes and fires SKSE mod events (`SeverActions_NewTeammateDetected`, `SeverActions_TeammateRemoved`) for immediate Papyrus-side onboarding. Followers recruited via vanilla dialogue or any mod are detected and fully onboarded within ~1 second — no save/load required. External dismissals (another mod calling `SetPlayerTeammate(false)`) are also caught and cleaned up automatically. **Dual Follow System** — Two completely separate follow mechanisms: casual follow (SkyrimNet `RegisterPackage` at priority 50 for guards, random NPCs, and temporary follows) and companion follow (CK alias-based package with `ForceRefTo` + `PO3_SKSEFunctions.SetLinkedRef` for formal companions). Casual follows don't consume alias slots or set LinkedRef; companion follows don't use SkyrimNet's package system. **4-Way Dismiss Routing** — `UnregisterFollower` now routes through NFF > EFF > Custom (preserves pre-existing teammate status for modded followers like Serana/Inigo) > Vanilla, with `KEY_WAS_ALREADY_TEAMMATE` StorageUtil flag tracking. **Full Auto-Onboarding** — `DetectExistingFollowers` now fully onboards detected followers (faction, outfit slot, companion follow with alias + LinkedRef) instead of just setting StorageUtil keys. Re-runs every game load and catches previously missed followers. **Removed Debug Notifications** — Cleaned up in-game `Debug.Notification` calls for LinkedRef and alias slot assignment; `Debug.Trace` log messages retained for troubleshooting. |
| **0.95** | **Outfit Persistence** — ReferenceAlias-based outfit locking system. Per-follower alias slots with `OnLoad`/`OnCellLoad`/`OnEnable`/`OnObjectUnequipped` events for zero-flicker outfit re-equipping across cell transitions. Outfit lock survives save/load, dismissal, and engine auto-equip via StorageUtil persistence + automatic alias slot reassignment on game load. Dismissed followers keep their outfits when sent home via persistent outfit-locked actor tracking list — alias slots are reassigned even for dismissed followers on save/load. MCM shows outfit lock status and locked item list per follower. **Outfit Lock Suspend/Resume** — All outfit action functions (Dress, Undress, EquipItemByName, UnequipItemByName, EquipMultiple, UnequipMultiple, ApplyOutfitPreset, RemoveClothingPiece) now suspend the `OnObjectUnequipped` re-equip guard before changing gear and resume it after. Prevents the alias from fighting the outfit system's own operations (e.g., switching between saved presets no longer snaps back to the previous outfit mid-swap). **Consolidated Wait System** — `WaitHere` removed; `CompanionWait` now works for any NPC (not just companions) and always applies sandbox package for immersive waiting behavior. `CompanionFollow` also universal. **Hotkeys & Wheel Menu** — Dedicated hotkeys for follow toggle, dismiss all, set companion, and wait/resume. UIExtensions wheel menu with 8 context-aware action slots (follow, dismiss, stand up, yield, undress, dress, wait, set companion). **Follow Priority Overhaul** — Follow package priority raised to 95 (from 10) so follow reliably overrides sandbox and other packages. Sandbox stays at 90. **Clearer Dismiss vs Wait vs Leave** — DismissFollower YAML rewritten with explicit USE/DON'T USE sections and KEY DISTINCTION block to prevent AI confusion between temporary dismissal, waiting, and permanent departure. **Prompt Null Safety** — All 6 prompts using `decnpc()` now have defensive null guards (`{% if actorUUID and actorUUID != 0 %}`) preventing `type_error.302` crashes when actor context is missing. Fixed `is_follower(actor.UUID)` → `is_follower(actorUUID)` across all prompts. **Streamlined Action Guidance** — Follower action guidance prompt trimmed to relationship calibration only (AdjustRelationship ranges, FollowerLeaves emotional weight, SetCompanion recruitment threshold); action routing now handled entirely by YAML descriptions. **EFF Integration** — Extensible Follower Framework support added alongside NFF. Priority order: NFF > EFF > Vanilla. Build stubs for both frameworks (compile-time only, never deployed). **Max Followers** — Default raised from 5 to 10, MCM slider expanded to 20. **Survival Improvements** — Beverages (ales, meads, wines) now restore 15 hunger; regular potions restore 10. Name-based beverage detection via native `StringContains`. MCM now displays per-follower hunger, fatigue, and cold percentages with severity labels. **Crafting Narrations** — Rewrote all DirectNarration calls to past tense to prevent LLMs from attempting duplicate item delivery. **MCM Fixes** — Added proper `GetVersion()` override for SkyUI version update system. Translation token support for page names. |
| **0.91** | **Follower Framework** — Full companion system with relationship tracking (rapport/trust/loyalty/mood), 4-tier morality with relationship-influenced flexibility, NFF soft integration (auto-detect and route through NFF controller), combat styles (aggressive/defensive/ranged/healer/balanced), home assignment, MCM per-follower configuration. 8 new follower actions + 2 follower prompts. **Outfit Manager Overhaul** — Replaced slot-based equip/unequip with name-based system using C++ inventory search. New actions: `EquipItemByName`, `UnequipItemByName`, `EquipMultipleItems` (comma-separated batch), `UnequipMultipleItems`, `SaveOutfitPreset`, `ApplyOutfitPreset`. Removed old `EquipClothingPiece`/`RemoveClothingPiece`. Hybrid C++/Papyrus architecture (C++ searches, Papyrus equips for thread safety). **Combat** — Yield aggression restoration via C++ TESHitEvent monitor (yielded NPCs regain aggression when attacked again). **All YAML actions** updated with SexLab/OStim eligibility guards. |
| **0.90** | Book reading system (`ReadBook`/`StopReading`) with native text extraction. Guard dispatch overhaul — tiered off-screen handling (trust AI → door nudge → teleport), combat suppression, rubber-band tethering, snapshot-based arrival detection, configurable `DispatchArrivalDistance`. Judgment phase (`OrderJailed`/`OrderRelease`). Home investigation dispatch (`DispatchGuardToHome`) with evidence generation. NPC Names Distributor integration — guards find NPCs by NND names. `SetActorBumpable` collision toggle for escorts. `FindExitDoorFromCell` for interior door navigation. Flora/ingredient scanning. Loot improvements (`LootCorpse`, selective looting). Book reading prompt with anti-hallucination rules. |
| **0.88** | Native DLL: Recipe DB, Alchemy DB, Location Resolver, Actor Finder, Stuck Detector, Survival system, Fertility Mode bridge, Crime utilities. New actions: BrewPotion, CookMeal, Guard dispatch. Removed JSON databases — all data scanned natively from game forms. |
| **0.85** | Initial FOMOD release with modular installer. Core actions, prompts, and native plugin. |

---

## Credits

- **Sever** — Mod author
- **SkyrimNet** — The AI framework that makes this possible
- **[PapyrusUtil](https://www.nexusmods.com/skyrimspecialedition/mods/13048)** — Extended Papyrus functions
- **[powerofthree's Papyrus Extender](https://www.nexusmods.com/skyrimspecialedition/mods/22854)** — Additional Papyrus functions
- **[JContainers](https://www.nexusmods.com/skyrimspecialedition/mods/16495)** — JSON data storage (NSFW module only)
- **[NPC Names Distributor](https://www.nexusmods.com/skyrimspecialedition/mods/73081)** — Optional NPC naming integration
- **[Nether's Follower Framework](https://www.nexusmods.com/skyrimspecialedition/mods/55653)** — Optional follower framework integration
- **[Extensible Follower Framework](https://www.nexusmods.com/skyrimspecialedition/mods/7003)** — Optional follower framework integration

---

<p align="center">
  <em>Built for SkyrimNet — where NPCs don't just talk, they act.</em>
</p>
