# SeverActions — SkyrimNet Action Pack

<p align="center">
  <strong>A comprehensive action, prompt, and behavior pack for SkyrimNet</strong><br>
  <em>Give NPCs the ability to act, not just talk.</em>
</p>

<p align="center">
  <code>71 Actions</code> &nbsp;&middot;&nbsp; <code>30 Context Prompts</code> &nbsp;&middot;&nbsp; <code>301 Native C++ Functions</code> &nbsp;&middot;&nbsp; <code>~27,500 Lines of Papyrus</code>
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
| **Basic** | `StartFollowing` `StopFollowing` `Relax` `StopRelaxing` `PickUpItem` `UseItem` `GiveItem` `GiveItemTrue` `TakeItemFromPlayer` `BringItem` `LootContainer` `LootCorpse` `ReadBook` `StopReading` `LearnSpell` `TeachSpell` | Core commands — follow, relax, pick up items, give/take items (by name or reference), loot, read books aloud, and teach/learn spells |
| **Travel** | `TravelToPlace` `TravelToLocation` `ChangeTravelSpeed` `CancelTravel` | NPCs navigate to named locations (cities, inns, dungeons) using a native travel marker database |
| **Combat** | `AttackTarget` `CeaseFighting` `Yield` | Engage or disengage from combat based on conversation |
| **Outfit** | `Undress` `GetDressed` `EquipItems` `UnequipItems` `SaveOutfitPreset` `ApplyOutfitPreset` | Full outfit management — equip/unequip by name (comma-separate for multiple), save/recall presets, persistent outfit locking across cell transitions. OmniSight-aware equipment prompt shows gender-aware item names and descriptions |
| **Follower** | `SetCompanion` `DismissFollower` `CompanionWait` `CompanionFollow` `AssignHome` `SetCombatStyle` `FollowerLeaves` `AdjustRelationship` | Companion framework with relationship tracking (rapport, trust, loyalty, mood), NFF/EFF integration, combat styles, home assignment. Wait/Follow work on any NPC |
| **Furniture** | `SitOrLayDown` `StopUsingFurniture` | NPCs use chairs, benches, beds, and crafting stations with automatic cleanup |
| **Economy** | `GiveGold` `GiveGoldTrue` `CollectPayment` `ExtortGold` `AddToDebt` `CreateDebt` `CreateRecurringDebt` `ForgiveDebt` | Gold transactions and debt system — gifts, payments, extortion, tabs, credit limits, due dates, auto-growth, and faction-aware guard reporting. CollectPayment auto-reduces open debts |
| **Crafting** | `CraftItem` `CookMeal` `BrewPotion` | Full crafting pipeline — NPC walks to the nearest workstation, crafts/cooks/brews, then delivers the item |
| **Arrest** | `ArrestPlayer` `ArrestNPC` `DispatchGuardToArrest` `DispatchGuardToHome` `AddBountyToPlayer` `AcceptPersuasion` `RejectPersuasion` `FreeFromJail` `OrderJailed` `OrderRelease` | Full crime and justice system — guards track bounties, dispatch across cells, escort prisoners, investigate homes, and handle judgment |

### Context Prompts

Prompts inject real-time game state into the AI's context so NPCs *know* about the world around them:

| Prompt | What NPCs Know |
|--------|----------------|
| **Known Spells** | Their own spell repertoire, grouped by school |
| **Gold Awareness** | How much gold they're carrying |
| **Inventory** | What items they have |
| **Nearby Objects** | Surrounding items, containers, flora, and furniture |
| **Combat Status** | Whether they're in combat and against whom |
| **Survival Needs** | Hunger, cold exposure, and fatigue levels |
| **Faction Reputation** | Player's guild standings and rank with dynamic knowledge visibility |
| **Guard Bounty** | Player's bounty in the current hold |
| **Jailed Status** | That they're imprisoned and why |
| **Merchant Inventory** | Their shop stock and pricing (location-restricted or always-on) |
| **Debt Context** | Financial obligations — who owes what, due dates, credit limits, payment rules |
| **Book Reading** | Strict reading rules — NPCs read only real book text, never fabricated content |
| **Follower Context** | Relationship values (rapport/trust/loyalty/mood), LLM-generated relationship blurbs, combat style, and companion behavior guidelines. Toggleable via PrismaUI |
| **Group Awareness** | Shows traveling companions which other party members are nearby — scales naturally from duo to large group. Keeps dialogue conversational without checklist-style name-dropping |
| **Conversation Flow** | Natural speech patterns — varied sentence length, filler/hesitation, mundane lines, reactions before opinions. Anti-loop and anti-echo rules |
| **Relationship Assessment** | Periodic LLM-driven evaluation of follower relationships based on recent events, memories, and character bios. Generates unique relationship blurbs per companion. Runs on configurable game-hour cooldowns |
| **Follower Banter** | Independent banter director that periodically evaluates whether companions should start talking to each other. Considers pair affinity/respect, mood, personality, recent events. Triggers SkyrimNet's dialogue pipeline — companions speak, not the system |
| **Equipment (OmniSight)** | What they're currently wearing with OmniSight-aware item names and descriptions. Ground truth enforcement — NPCs cannot claim to wear items not in their equipment list |

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
| **Enhanced Action Selector** | `native_action_selector.prompt` | Optimized for SeverActions' streamlined YAML descriptions. Reads the full player-NPC exchange, shows parameter schemas, and includes player-intent and implicit-agreement guidelines for better action matching across all model backends |
| **Enhanced Target Selectors** | `dialogue_speaker_selector.prompt` `player_dialogue_target_selector.prompt` | Improved speaker/target routing with companion awareness tags, conversation momentum, crosshair weighting, NPC-to-NPC targeting rules, and anti-loop silence detection |

---

## Native C++ Plugin — `SeverActionsNative.dll`

The included SKSE plugin (276 native functions) replaces slow Papyrus operations with native C++ implementations, providing 100-5000x performance improvements across all major systems:

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
| **Package Manager** | Native LinkedRef management with SKSE cosave persistence — auto-restores all LinkedRefs on game load, auto-cleans on actor death. Drop-in replacement for `PO3_SKSEFunctions.SetLinkedRef` with tracking |
| **Guard Finder** | Native guard search by hold faction using `ForEachReferenceInRange` — replaces Papyrus cell iteration for cross-cell guard dispatch |
| **Dialogue Animations** | Conversation idle animations on NPCs in dialogue packages |
| **Crime Utilities** | Access to jail markers, stolen goods containers, jail outfits from crime factions |
| **Survival System** | Follower tracking, food detection, weather/cold calculation, heat source detection, armor warmth |
| **Book Utilities** | Native book text extraction — `GetBookText`, `FindBookInInventory`, `ListBooks` |
| **Yield Aggression Monitor** | TESHitEvent-based monitoring that restores yielded NPC aggression when attacked again |
| **Teammate Monitor** | Periodic scanning of loaded actors for `SetPlayerTeammate` changes — fires mod events for instant follower onboarding without save/load |
| **Orphan Cleanup** | Periodic scanning of loaded actors for stale SeverActions LinkedRef keywords — fires mod events to clear orphaned packages |
| **Fertility Mode Bridge** | Cached fertility state lookups, cycle tracking, pregnancy status |
| **NSFW Utilities** | High-performance JSON assembly for SexLab event data (500-2000x faster than Papyrus) |
| **FollowerDataStore** | Native cosave persistence for all per-follower state — home assignments, combat styles, relationship values (rapport/trust/loyalty/mood), travel state, and package state. Survives save/load without StorageUtil string reliability issues |
| **OutfitDataStore** | Native cosave persistence for outfit locks and presets — locked item lists and named outfit presets per actor. Burst strip detection yields to external mods (SexLab/OStim/bathing). Animation scene hooks via ModEvents. DefaultOutfit restoration on dismiss |
| **PrismaUI Bridge** | Bidirectional C++ ↔ React communication layer for the in-game config menu — data gathering, setting writes, and action dispatch all handled natively. Game pauses while menu is open. Teleport operations queued and executed on close |

### SKSE Cosave Persistence

The native DLL uses SKSE's cosave system (unique ID `'SVAN'`) with three specialized data stores that automatically persist and restore on save/load:

| Record | Store | What It Persists |
|--------|-------|-----------------|
| `'LREF'` | PackageManager | All LinkedRef assignments (follow targets, furniture targets, travel destinations) — auto-restored before Papyrus even runs |
| `'FLWD'` | FollowerDataStore | Per-follower home location, combat style, relationship values, travel state, package state, sandbox/combat/surrender flags |
| `'OTFT'` | OutfitDataStore | Per-actor outfit lock state, locked item FormID lists, and named outfit presets with their item lists |

This eliminates the need for Papyrus re-linking code on game load and solves StorageUtil's unreliable string persistence.

---

## PrismaUI — In-Game Config Menu

SeverActions includes a modern React-based configuration menu powered by PrismaUI, providing a visual alternative to the traditional MCM:

| Page | What It Shows |
|------|--------------|
| **Dashboard** | Mod version, active systems, framework detection status |
| **Companions** | Visual party roster with relationship bars, recruitment mode picker, combat style, home assignment, teleport, dismiss, package management |
| **World** | Per-hold bounty grid, knowledge system (conditional entries by faction/race/group), travel slots, currency settings, debt summary |
| **Settings** | Follower behavior (max followers, banter, teleport distance, relationship tracking with configurable cooldowns), dialogue animations, survival needs, book reading, spell failure, UI scale |
| **Outfits** | Per-NPC outfit lock management — snapshot current gear, clear locks, save/load named presets, view locked items and preset contents |

**Architecture**: The frontend is a React 19 + Zustand app that communicates with C++ via PrismaUI's bidirectional bridge. Settings use optimistic updates (instant UI feedback, debounced game writes). Data gathering runs entirely in C++, reading directly from native data stores and script properties for sub-20ms page loads.

---

## Key Systems

### Follower Framework

A relationship-driven companion system where NPCs remember how they feel about the player and act accordingly:

- **Relationship tracking** — Rapport, Trust, Loyalty, and Mood on -100/+100 scales (Mood 0-100), persisted via native FollowerDataStore cosave
- **Organic morality** — No rigid morality tiers. The LLM decides moral behavior organically from character personality, bio, and relationship context
- **Framework integration** — Automatically detects Nether's Follower Framework (NFF) or Extensible Follower Framework (EFF) and routes recruit/dismiss through the framework's controller when present, falls back to vanilla teammate system when neither is installed. 4-way dismiss routing: NFF > EFF > custom (preserves pre-existing teammate status) > vanilla. **NFF ignore token detection** — custom AI followers (Inigo, Lucien, Kaidan, etc.) with NFF's `nwsIgnoreToken` are automatically routed to track-only mode instead of through NFF, preventing conflicts with their custom AI. **MCM recruitment mode toggle** — "Auto" (default, uses NFF/EFF when installed, respects ignore tokens) or "SeverActions Only" (bypasses NFF/EFF entirely, uses our own alias-based follow system). Takes effect on next recruit
- **Dual follow system** — Casual follow (SkyrimNet package for guards and random NPCs) and companion follow (CK alias-based package with LinkedRef for formal companions) operate independently with strict eligibility separation
- **Instant detection** — Native C++ teammate monitor scans loaded actors every second; followers recruited via vanilla dialogue or any mod are detected and onboarded within ~1 second, no save/load required
- **Combat styles** — Aggressive, defensive, ranged, healer, or balanced — configurable per follower via MCM or PrismaUI
- **Home assignment** — NPCs can be assigned a home location and will return there when dismissed. Persisted via native cosave
- **Relationship persistence** — All relationship data survives dismissal, re-recruitment, and temporary teammate status changes; returning followers are recognized and keep their full relationship history
- **Automatic relationship assessment** — Background LLM evaluation using character bios, recent events, and memories. Generates unique relationship blurbs (e.g., "You've grown fond of them after they stood by you in that ambush near Whiterun"). Configurable cooldowns via PrismaUI
- **Inter-follower assessment** — Companions form opinions about each other based on shared events. Affinity, respect, and LLM-generated blurbs per pair
- **Follower banter** — Independent banter director triggers companion-to-companion conversations while traveling. Evaluates pair affinity, mood, personality compatibility, and recent events. Configurable frequency via PrismaUI
- **Up to 10 companions** — Default max of 10 simultaneous followers, configurable up to 20 via MCM
- **Hotkeys and wheel menu** — Dedicated hotkeys for follow toggle, dismiss all, set companion, and wait/resume. UIExtensions wheel menu with all actions in one place
- **PrismaUI companion management** — Visual roster with relationship bars, one-click teleport, dismiss, home assignment, combat style changes, and package cleanup

### Outfit Manager

NPCs can equip and unequip items by name, handle multiple items in a single action, save/recall outfit presets, and keep their outfits persistent across cell transitions:

- **Name-based equipping** — `EquipItems` / `UnequipItems` use C++ `FindItemByName` for fast inventory search, Papyrus `EquipItem` for thread-safe equipping
- **Batch operations** — "Put on steel gauntlets, iron helmet, and glass cuirass" in a single action via comma-separated item names
- **Outfit presets** — "Save what you're wearing as your combat outfit" snapshots all worn items; "Change into your home clothes" strips current gear and equips the saved preset. Presets persist via native OutfitDataStore cosave
- **Persistent outfit locking** — Locked outfits survive cell transitions, save/load, dismissal, and engine auto-equip. Uses per-follower ReferenceAlias slots with `OnLoad`/`OnCellLoad`/`OnObjectUnequipped` events with debounced re-equipping
- **Animation framework compatibility** — Outfit lock automatically yields during SexLab/OStim scenes via ModEvent hooks (`HookAnimationStart`/`ostim_start`). Burst strip detection catches other mods (bathing, etc.) that strip actors via native DLL calls. Lock reasserts on cell transition
- **MCM and PrismaUI management** — Outfit lock system can be enabled/disabled via MCM. PrismaUI Outfits page provides visual per-NPC management: snapshot current gear, clear locks, save/load named presets, view locked items and preset contents
- **Animations** — Integrates with Immersive Equipping Animations for slot-appropriate dress/undress animations
- **Hybrid architecture** — C++ for inventory searching (fast), Papyrus for equipping (thread-safe). Direct C++ `ActorEquipManager::EquipObject()` can silently fail from Papyrus worker threads

### Debt System

A full financial obligation system where NPCs can track debts, tabs, and credit:

- **Debt creation** — `CreateDebt` for one-time debts, `CreateRecurringDebt` for periodic charges (rent, services), `AddToDebt` for adding charges to existing tabs
- **Auto-debt from GiveItem** — When an NPC gives an item to someone who already has an open tab, the item's gold value is automatically added to their debt
- **Payment integration** — `CollectPayment` automatically reduces matching debts by the amount paid
- **Credit limits** — Optional per-debt credit caps that prevent further charges once exceeded
- **Due dates** — Optional deadlines tracked in game hours with overdue detection
- **Faction-aware reporting** — NPCs can report unpaid debts to guards of the appropriate hold faction
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
- **Stuck recovery** — progressive escalation from package re-evaluation to leapfrogging to door-based redirect
- **NPC Names Distributor** — guards can find NPCs by their NND-assigned names

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
- **Auto-eat** triggers at staggered 10-point brackets (50, 60, 70, 80, 90, 100) — followers attempt to eat from their inventory at each bracket
- **MCM and PrismaUI display** — Per-follower hunger, fatigue, and cold percentages with severity labels
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
| OmniSight | Gender-aware item names and descriptions in the equipment prompt |
| PrismaUI | Modern React-based in-game config menu (auto-detected; MCM works without it) |
| [Fertility Mode Reloaded](https://www.loverslab.com/) | Pregnancy and fertility cycle awareness |
| [OSL Aroused](https://www.nexusmods.com/skyrimspecialedition/mods/74037) | Arousal state awareness and modification |
| [SexLab Aroused](https://www.loverslab.com/) | Arousal state awareness and modification |

### FOMOD Installer

Install with any mod manager (MO2, Vortex). The FOMOD installer lets you pick exactly which modules you want:

1. **Page 1 — Action Modules**: Choose which actions NPCs can perform
2. **Page 2 — Prompt Modules**: Choose context awareness, optional prompt overrides (action selector, target selectors)
3. **Page 3 — Adult Content**: Optional modules for supported adult mods

The **Core** files are always installed and include all Papyrus scripts, the native DLL, the PrismaUI frontend, and the ESP plugin.

---

## Project Structure

```
SeverActions/
+-- 00 Core/                              # Always installed
|   +-- SeverActions.esp                  # Plugin file
|   +-- Interface/Translations/           # MCM translation strings
|   +-- PrismaUI/views/SeverActions/      # React config menu (HTML + JS + CSS)
|   +-- SKSE/Plugins/
|   |   +-- SeverActionsNative.dll        # Native C++ SKSE plugin (276 functions)
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
|   +-- Outfit/                           # Equip/unequip by name, batch equip, presets + OmniSight equipment prompt
|   +-- Follower/                         # Companion framework — recruit, dismiss, relationship, combat style
|   +-- Furniture/                        # Sit, lay down, stand up
|   +-- Economy/                          # Give gold, collect, extort
|   +-- Crafting/                         # Craft, cook, brew
|   +-- Arrest/                           # Arrest, dispatch, bounty, jail, judgment
|   +-- Adult-OSLAroused/                 # OSL Aroused integration
|   +-- Adult-SLOAroused/                 # SL Aroused integration
|
+-- Prompts/                              # Context prompt templates (selectable)
|   +-- Core/                             # Spells, gold, inventory, nearby, book reading, conversation flow
|   +-- Combat/                           # Combat awareness
|   +-- Survival/                         # Hunger, cold, fatigue
|   +-- Faction/                          # Guild reputation
|   +-- Arrest/                           # Bounty and jail status
|   +-- Follower/                         # Relationship context, group awareness, and relationship assessment
|   +-- Economy-Anywhere/                 # Merchant + debt context (always active)
|   +-- Economy-LocationOnly/             # Merchant + debt context (location-restricted)
|   +-- ActionSelector/                   # Optional: enhanced action selector for SeverActions YAMLs
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
| `SeverActions_Arrest` | 4,977 | Crime system — bounty tracking, guard dispatch, cross-cell escort, persuasion, judgment, jail processing |
| `SeverActions_MCM` | 1,968 | Mod Configuration Menu — toggle features, adjust settings, companion dropdown selector, per-follower relationship sliders, survival stats, outfit lock status, speaker tag toggles |
| `SeverActions_Travel` | 1,706 | Travel system — location lookup, walking packages, speed control, stuck recovery, orphan cleanup tracking |
| `SeverActions_Survival` | 1,463 | Follower survival — hunger, cold, fatigue tracking with native calculation, beverage detection |
| `SeverActions_FollowerManager` | 1,432 | Companion roster — relationship tracking, NFF/EFF routing, home/combat style, auto-assessment, morality |
| `SeverActions_Outfit` | 1,395 | Outfit management — equip/unequip by name, presets, outfit lock with suspend/resume, native cosave migration |
| `SeverActions_Combat` | 1,321 | Combat — attack commands, yield/surrender with faction conversion, ceasefire, persistence aliases |
| `SeverActions_Loot` | 1,176 | Inventory — item pickup, give, take, deliver, book reading with native text extraction |
| `SeverActions_PrismaUI` | 1,063 | PrismaUI bridge — C++ data requests, setting change handlers, action dispatch |
| `SeverActions_Debt` | 1,035 | Financial obligations — one-time and recurring debts, payments, credit limits, overdue tracking |
| `SeverActions_SpellTeach` | 974 | Spell teaching — school/level display, failure consequences, conjuration portal VFX |
| `SeverActions_Crafting` | 825 | Crafting pipeline — forge/cooking/alchemy with workstation routing and delivery |
| `SeverActions_Hotkeys` | 629 | Hotkey dispatch — configurable keybinds with crosshair/nearest/last-talked target modes |
| `SeverActions_Follow` | 585 | Dual follow system — casual follow (SkyrimNet package) and companion follow (CK alias-based with LinkedRef), sandbox management |
| `SeverActions_Init` | 566 | Mod initialization — database loading, event registration, decorator registration, framework init, outfit migration |
| `SeverActionsNative` | 495 | Native function declarations — bridge to SeverActionsNative.dll (276 functions) |
| `SeverActions_FertilityMode_Bridge` | 436 | Fertility Mode data caching bridge to native DLL |
| `SeverActions_WheelMenu` | 427 | UIExtensions wheel menu — all actions in one radial interface |
| `SeverActions_EatingAnimations` | 338 | TaberuAnimation.esp integration — keyword-based food eating animations |
| `SeverActions_Currency` | 321 | Gold transactions with conjured gold fallback, auto-debt reduction on CollectPayment |
| `SeverActions_Furniture` | 237 | Furniture interaction with native auto-cleanup |
| `SeverActions_Arousal` | 142 | OSL Aroused integration — arousal state decorator and modification |
| `SeverActions_SLOArousal` | 164 | SexLab Aroused integration |
| `SeverActions_OutfitAlias` | 91 | Per-follower ReferenceAlias for zero-flicker outfit persistence across cell transitions |
| `SeverActions_YieldAlias` | 74 | Per-slot ReferenceAlias for yielded NPC persistence — OnLoad re-applies surrender state, OnDeath frees slot |
| | **~27,100** | **Total** |

---

## Configuration

The mod is configurable through the **MCM (Mod Configuration Menu)** and the **PrismaUI in-game config menu**:

### MCM Pages
- **General** — Dialogue animations, silence chance, book reading mode, spell teaching, speaker tags
- **Hotkeys** — Configurable keybinds for follow, dismiss, wait/resume, set companion, yield, outfit, stand up. Target mode selection (crosshair, nearest NPC, last talked to)
- **Currency** — Conjured gold toggle
- **Travel** — Travel speed, marker database selection
- **Bounty** — Per-hold bounty display with clear options, arrest cooldown, persuasion time limit
- **Survival** — Hunger/cold/fatigue toggles, rates, auto-eat threshold
- **Followers** — Per-follower Rapport, Trust, Loyalty, Mood sliders, Combat Style dropdown, survival stats, outfit lock status. Max companions slider, relationship cooldown, assessment toggle/interval, recruitment mode

### PrismaUI Pages
- **Dashboard** — Mod version, active system status, framework detection
- **Companions** — Visual roster with relationship bars, teleport, dismiss, home assignment, combat style, package management
- **World** — Bounty grid, travel slots, currency settings, debt summary
- **Settings** — All configurable settings with instant visual feedback
- **Outfits** — Per-NPC outfit lock management, preset save/load, locked item viewing

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
