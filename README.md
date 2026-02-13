# SeverActions — SkyrimNet Action Pack

<p align="center">
  <strong>A comprehensive action, prompt, and behavior pack for SkyrimNet</strong><br>
  <em>Give NPCs the ability to act, not just talk.</em>
</p>

<p align="center">
  <code>52 Actions</code> &nbsp;·&nbsp; <code>18 Context Prompts</code> &nbsp;·&nbsp; <code>150+ Native C++ Functions</code> &nbsp;·&nbsp; <code>~19,000 Lines of Papyrus</code>
</p>

---

## Overview

**SeverActions** extends SkyrimNet with a full suite of actions, prompts, and a native C++ SKSE plugin that together let NPCs interact with the game world in meaningful ways. NPCs can follow you, travel across Skyrim, craft items at forges, cook meals, brew potions, read books aloud, manage their outfits, handle gold, sit in chairs, fight enemies, get arrested and escorted to jail by guards, and much more — all driven naturally through conversation.

Every system is designed around one principle: **the AI decides what to do, and the mod makes it happen in-game.**

---

## Features at a Glance

### Action Modules

| Module | Actions | Description |
|--------|---------|-------------|
| **Basic** | `StartFollowing` `StopFollowing` `WaitHere` `Relax` `StopRelaxing` `PickUpItem` `UseItem` `GiveItem` `BringItem` `LootContainer` `LootCorpse` `ReadBook` `StopReading` | Core follower commands — follow, wait, relax, pick up items, loot, and read books aloud |
| **Travel** | `TravelToPlace` `TravelToLocation` `ChangeTravelSpeed` `CancelTravel` | NPCs navigate to named locations (cities, inns, dungeons) using a native travel marker database |
| **Combat** | `AttackTarget` `CeaseFighting` `Yield` | Engage or disengage from combat based on conversation |
| **Outfit** | `Undress` `GetDressed` `EquipItemByName` `UnequipItemByName` `EquipMultipleItems` `UnequipMultipleItems` `SaveOutfitPreset` `ApplyOutfitPreset` | Full outfit management — equip/unequip by name, batch equip multiple items, save and recall outfit presets |
| **Follower** | `SetCompanion` `DismissFollower` `CompanionWait` `CompanionFollow` `AssignHome` `SetCombatStyle` `FollowerLeaves` `AdjustRelationship` | Companion framework with relationship tracking (rapport, trust, loyalty, mood), NFF integration, combat styles, and home assignment |
| **Furniture** | `SitOrLayDown` `StopUsingFurniture` | NPCs use chairs, benches, beds, and crafting stations with automatic cleanup |
| **Economy** | `GiveGold` `CollectPayment` `ExtortGold` | Gold transactions — gifts, payments, tips, and extortion with conjured gold support |
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
| **Travel Guidance** | Rules preventing NPCs from traveling without being told to |
| **Book Reading** | Strict reading rules — NPCs read only real book text, never fabricated content |
| **Follower Context** | Relationship values (rapport/trust/loyalty/mood), morality, combat style, and companion behavior guidelines with relationship-influenced moral flexibility |
| **Follower Action Guidance** | Rules for when and how to use follower framework actions |

### Adult Content Modules (Optional)

| Module | Requires | Description |
|--------|----------|-------------|
| **OSL Aroused Action + Prompt** | OSL Aroused | Arousal awareness and modification |
| **SL Aroused Action + Prompt** | SexLab Aroused | Arousal awareness and modification |
| **Fertility Status Prompt** | Fertility Mode | Pregnancy and fertility cycle awareness |
| **Abort Pregnancy Trigger** | Fertility Mode | Event trigger for pregnancy termination |

---

## Native C++ Plugin — `SeverActionsNative.dll`

The included SKSE plugin replaces slow Papyrus operations with native C++ implementations, providing 100-2000x performance improvements across all major systems:

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
| **Fertility Mode Bridge** | Cached fertility state lookups, cycle tracking, pregnancy status |
| **NSFW Utilities** | High-performance JSON assembly for SexLab event data (500-2000x faster than Papyrus) |

---

## Key Systems

### Follower Framework

A relationship-driven companion system where NPCs remember how they feel about the player and act accordingly:

- **Relationship tracking** — Rapport, Trust, Loyalty, and Mood on -100/+100 scales (Mood 0–100), persisted via StorageUtil
- **Morality system** — 4-tier morality (0=no morals, 1=violent but honest, 2=petty theft OK, 3=strict moral code) with relationship-based flexibility — NPCs with high rapport/trust/loyalty will bend their rules more for a player they care about
- **NFF integration** — Automatically detects Nether's Follower Framework and routes recruit/dismiss through NFF's controller when present, falls back to vanilla teammate system when not
- **Combat styles** — Aggressive, defensive, ranged, healer, or balanced — configurable per follower
- **Home assignment** — NPCs can be assigned a home location and will return there when dismissed
- **MCM configuration** — Per-follower sliders for all relationship values and combat style dropdown

### Outfit Manager

NPCs can equip and unequip items by name, handle multiple items in a single action, and save/recall outfit presets:

- **Name-based equipping** — "Put on the steel gauntlets" uses C++ `FindItemByName` for fast inventory search, Papyrus `EquipItem` for thread-safe equipping
- **Batch operations** — "Put on steel gauntlets, iron helmet, and glass cuirass" in a single action via comma-separated item names
- **Outfit presets** — "Save what you're wearing as your combat outfit" snapshots all worn items; "Change into your home clothes" strips current gear and equips the saved preset
- **Animations** — Integrates with Immersive Equipping Animations for slot-appropriate dress/undress animations
- **Hybrid architecture** — C++ for inventory searching (fast), Papyrus for equipping (thread-safe). Direct C++ `ActorEquipManager::EquipObject()` can silently fail from Papyrus worker threads.

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
        ↓
Guard pathfinds to target (even through load doors)
        ↓
Arrest performed (cuffs, factions, follow package)
        ↓
Guard escorts prisoner back to sender or jail
        ↓
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
        ↓
SkyrimNet AI decides an action is appropriate
        ↓
Action YAML defines parameters and eligibility
        ↓
Papyrus script executes the action in-game
        ↓
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
8. A narration event fires: *"Lydia hands Iron Sword to Dragonborn."*

### Survival Tracking

Followers track hunger, fatigue, and cold exposure on a 0–100 scale with native calculations:

- **Cold exposure** factors in weather severity, geographic region, equipped armor warmth, and proximity to heat sources (campfires, forges, hearths)
- **Auto-eat** triggers when hunger reaches threshold — followers consume food from their inventory
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
| [NPC Names Distributor](https://www.nexusmods.com/skyrimspecialedition/mods/81214) | Guard dispatch can find NPCs by their NND-assigned names |
| [Immersive Equipping Animations](https://www.nexusmods.com/skyrimspecialedition/mods/70249) | Slot-appropriate equip/unequip animations for outfit actions |
| [Fertility Mode Reloaded](https://www.loverslab.com/) | Pregnancy and fertility cycle awareness |
| [OSL Aroused](https://www.nexusmods.com/skyrimspecialedition/mods/74037) | Arousal state awareness and modification |
| [SexLab Aroused](https://www.loverslab.com/) | Arousal state awareness and modification |

### FOMOD Installer

Install with any mod manager (MO2, Vortex). The FOMOD installer lets you pick exactly which modules you want:

1. **Page 1 — Action Modules**: Choose which actions NPCs can perform
2. **Page 2 — Prompt Modules**: Choose what context NPCs are aware of
3. **Page 3 — Adult Content**: Optional modules for supported adult mods

The **Core** files are always installed and include all Papyrus scripts, the native DLL, and the ESP plugin.

---

## Project Structure

```
SeverActions/
├── 00 Core/                              # Always installed
│   ├── SeverActions.esp                  # Plugin file
│   ├── Interface/Translations/           # MCM translation strings
│   ├── SKSE/Plugins/
│   │   ├── SeverActionsNative.dll        # Native C++ SKSE plugin (150+ functions)
│   │   └── SeverActionsNative.toml       # Plugin configuration
│   ├── Scripts/                          # Compiled Papyrus scripts (.pex)
│   └── Source/
│       ├── Scripts/                      # Papyrus source scripts (.psc)
│       └── BuildStubs/                   # Compile-time stubs for soft dependencies (NFF, etc.)
│
├── Actions/                              # Action YAML configs (selectable)
│   ├── Basic/                            # Follow, wait, relax, items, loot, read books
│   ├── Travel/                           # Travel to locations
│   ├── Combat/                           # Attack, cease, yield
│   ├── Outfit/                           # Equip/unequip by name, batch equip, presets
│   ├── Follower/                         # Companion framework — recruit, dismiss, relationship, combat style
│   ├── Furniture/                        # Sit, lay down, stand up
│   ├── Economy/                          # Give gold, collect, extort
│   ├── Crafting/                         # Craft, cook, brew
│   ├── Arrest/                           # Arrest, dispatch, bounty, jail, judgment
│   ├── Adult-OSLAroused/                 # OSL Aroused integration
│   └── Adult-SLOAroused/                # SL Aroused integration
│
├── Prompts/                              # Context prompt templates (selectable)
│   ├── Core/                             # Spells, gold, inventory, nearby, book reading
│   ├── Combat/                           # Combat awareness
│   ├── Travel/                           # Travel guidance rules
│   ├── Survival/                         # Hunger, cold, fatigue
│   ├── Faction/                          # Guild reputation
│   ├── Arrest/                           # Bounty and jail status
│   ├── Follower/                         # Relationship context and action guidance
│   ├── Economy-Anywhere/                 # Merchant (always active)
│   ├── Economy-LocationOnly/             # Merchant (location-restricted)
│   ├── Adult-OSLAroused/                 # Arousal awareness (OSL)
│   ├── Adult-SLOAroused/                # Arousal awareness (SLO)
│   └── Adult-Fertility/                 # Fertility cycle awareness
│
├── Triggers/                             # Event triggers
│   └── Adult/                            # Abort Pregnancy trigger
│
└── fomod/                                # FOMOD installer config
    ├── info.xml
    └── ModuleConfig.xml
```

---

## Papyrus Scripts

| Script | Lines | Purpose |
|--------|------:|---------|
| `SeverActions_Arrest` | 4,466 | Crime system — bounty tracking, guard dispatch, cross-cell escort, persuasion, judgment, jail processing |
| `SeverActions_Travel` | 1,694 | Travel system — location lookup, walking packages, speed control, stuck recovery |
| `SeverActions_Survival` | 1,341 | Follower survival — hunger, cold, fatigue tracking with native calculation |
| `SeverActions_Loot` | 1,232 | Container looting, corpse searching, item pickup, flora harvesting, book reading |
| `SeverActions_Crafting` | 1,161 | Full crafting pipeline — forge/cooking/alchemy with native DB integration |
| `SeverActions_MCM` | 1,564 | Mod Configuration Menu — toggle features, adjust settings, per-follower relationship sliders |
| `SeverActions_Combat` | 1,080 | Combat actions — attack, cease, yield with C++ aggression restoration monitor |
| `SeverActions_FollowerManager` | 950+ | Follower framework — roster, relationships, NFF integration, combat styles, home assignment |
| `SeverActionsNative` | 803 | Native DLL function declarations (150+ functions) |
| `SeverActions_Outfit` | 740+ | Equipment management — equip/unequip by name, batch operations, outfit presets |
| `SeverActions_Hotkeys` | 540 | Hotkey registration and handling |
| `SeverActions_FertilityMode_Bridge` | 424 | Fertility Mode data caching bridge to native DLL |
| `SeverActions_Init` | 420+ | Mod initialization, database loading, event registration, follower framework init |
| `SeverActions_SpellTeach` | 380 | Spell teaching system |
| `SeverActions_WheelMenu` | 377 | Wheeler integration for quick actions |
| `SeverActions_EatingAnimations` | 338 | TaberuAnimation.esp integration — keyword-based food eating animations |
| `SeverActions_Follow` | 318 | Follower management — start/stop following, wait, relax |
| `SeverActions_Currency` | 271 | Gold transactions with conjured gold fallback |
| `SeverActions_Furniture` | 237 | Furniture interaction with native auto-cleanup |
| `SeverActions_SLOArousal` | 154 | SexLab Aroused integration |
| `SeverActions_Arousal` | 142 | OSL Aroused integration — arousal state decorator and modification |
| | **~19,000** | **Total** |

---

## Configuration

The mod is configurable through the **MCM (Mod Configuration Menu)** in-game:

- **Crafting** — Craft time duration, forge search radius, material requirements
- **Travel** — Travel speed, marker database selection
- **Furniture** — Auto-stand distance (how far the player must move before NPCs stand up)
- **Survival** — Hunger/cold/fatigue thresholds and update intervals
- **Follower** — Per-follower Rapport, Trust, Loyalty, Mood sliders, Combat Style dropdown
- **Dialogue Animations** — Enable/disable conversation idle animations
- **Debug** — Verbose logging for troubleshooting dispatch and escort behavior

---

## Version History

| Version | Changes |
|---------|---------|
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
- **[NPC Names Distributor](https://www.nexusmods.com/skyrimspecialedition/mods/81214)** — Optional NPC naming integration
- **[Nether's Follower Framework](https://www.nexusmods.com/skyrimspecialedition/mods/55653)** — Optional follower framework integration

---

<p align="center">
  <em>Built for SkyrimNet — where NPCs don't just talk, they act.</em>
</p>
