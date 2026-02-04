# SeverActions — SkyrimNet Action Pack

<p align="center">
  <strong>A comprehensive action, prompt, and behavior pack for <a href="https://www.nexusmods.com/skyrimspecialedition/mods/136016">SkyrimNet</a></strong><br>
  <em>Give NPCs the ability to act, not just talk.</em>
</p>

---

## Overview

**SeverActions** extends [SkyrimNet](https://www.nexusmods.com/skyrimspecialedition/mods/136016) with **38 actions**, **15 context prompts**, and a **native C++ SKSE plugin** that together let NPCs interact with the game world in meaningful ways. NPCs can follow you, travel across Skyrim, craft items at forges, cook meals, brew potions, manage their outfits, handle gold, sit in chairs, fight enemies, get arrested by guards, and much more — all driven naturally through conversation.

Every system is designed around one principle: **the AI decides what to do, and the mod makes it happen in-game.**

---

## Features

### Action Modules

| Module | Actions | Description |
|--------|---------|-------------|
| **Basic** | `StartFollowing` `StopFollowing` `WaitHere` `Relax` `StopRelaxing` `PickUpItem` `UseItem` `GiveItem` `BringItem` `LootContainer` | Core follower commands — follow, wait, relax, pick up and use items |
| **Travel** | `TravelToPlace` `TravelToLocation` `ChangeTravelSpeed` `CancelTravel` | NPCs navigate to named locations (cities, inns, dungeons) using a travel marker database |
| **Combat** | `AttackTarget` `CeaseFighting` `Yield` | Engage or disengage from combat based on conversation |
| **Outfit** | `EquipClothingPiece` `RemoveClothingPiece` `GetDressed` `Undress` | NPCs change their equipment — equip specific pieces or swap entire outfits |
| **Furniture** | `SitOrLayDown` `StopUsingFurniture` | NPCs use chairs, benches, beds, and crafting stations with automatic cleanup |
| **Economy** | `GiveGold` `CollectPayment` `ExtortGold` | Gold transactions — gifts, payments, tips, and extortion with conjured gold support |
| **Crafting** | `CraftItem` `CookMeal` `BrewPotion` | Full crafting pipeline — NPC walks to the nearest workstation, crafts/cooks/brews, then delivers the item to the recipient |
| **Arrest** | `ArrestPlayer` `ArrestNPC` `AddBountyToPlayer` `AcceptPersuasion` `RejectPersuasion` `FreeFromJail` | Crime and justice system — guards track bounties, confront criminals, escort prisoners to jail |

### Context Prompts

Prompts inject real-time game state into the AI's context so NPCs *know* about the world around them:

| Prompt | What NPCs Know |
|--------|----------------|
| **Known Spells** | Their own spell repertoire |
| **Gold Awareness** | How much gold they're carrying |
| **Inventory** | What items they have |
| **Nearby Objects** | Surrounding items, containers, and furniture |
| **Combat Status** | Whether they're in combat and against whom |
| **Survival Needs** | Hunger, cold exposure, and fatigue levels |
| **Faction Reputation** | Player's guild standings and rank |
| **Guard Bounty** | Player's bounty in the current hold |
| **Jailed Status** | That they're imprisoned and why |
| **Merchant Inventory** | Their shop stock and pricing (location-restricted or always-on) |
| **Travel Guidance** | Rules preventing NPCs from traveling without being told to |

### Adult Content Modules (Optional)

| Module | Requires | Description |
|--------|----------|-------------|
| **OSL Aroused Action + Prompt** | OSL Aroused | Arousal awareness and modification |
| **SL Aroused Action + Prompt** | SexLab Aroused | Arousal awareness and modification |
| **Fertility Status Prompt** | Fertility Mode | Pregnancy and fertility cycle awareness |
| **Abort Pregnancy Trigger** | Fertility Mode | Event trigger for pregnancy termination |

---

## Native C++ Plugin — `SeverActionsNative.dll`

The included SKSE plugin replaces slow Papyrus operations with native C++ implementations for massive performance gains:

| System | Speedup | What It Does |
|--------|---------|--------------|
| **String Utilities** | 2,000–10,000x | `StringToLower`, `HexToInt`, `TrimString`, `EscapeJsonString`, case-insensitive search/compare |
| **Crafting Database** | 500x | O(1) item lookup by name with fuzzy search, loaded from JSON files |
| **Recipe Database** | Auto-scanned | Reads all COBJ records at game load — every vanilla + modded smithing/cooking/smelting recipe, instantly searchable |
| **Alchemy Database** | Auto-scanned | Reads all AlchemyItem records — potions, poisons, foods, ingredients with effect-based search |
| **Travel Database** | 500x | O(1) location lookup with alias support ("whiterun" → `WhiterunBanneredMare`) |
| **Inventory Search** | 100–200x | Find items by name in any actor's inventory or container |
| **Nearby Search** | 10+ calls → 1 | Single-pass search for items, containers, forges, cooking pots, alchemy labs |
| **Furniture Manager** | Native | Auto-removes furniture packages when player moves away or changes cells |
| **Sandbox Manager** | Native | Auto-removes sandbox packages with distance/cell-change cleanup |
| **Dialogue Animations** | Native | Plays conversation idle animations on NPCs in dialogue packages |
| **Crime Utilities** | Native | Access jail markers, stolen goods containers, jail outfits from crime factions |
| **Survival System** | Native | Follower tracking, food detection, weather/cold calculation, heat source detection, armor warmth |
| **Fertility Mode Bridge** | Native | O(1) cached fertility state lookups, cycle tracking, pregnancy status |
| **NSFW JSON Builders** | 500–2,000x | High-performance JSON assembly for SexLab event data |

---

## How It Works

### The Action Pipeline

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

### The Prompt Pipeline

```
SkyrimNet requests NPC context
        ↓
Decorator functions query game state via native DLL
        ↓
Data is formatted as JSON and injected into the prompt
        ↓
AI responds with awareness of the NPC's actual situation
```

---

## Installation

### Requirements

- [Skyrim Special Edition](https://store.steampowered.com/app/489830/The_Elder_Scrolls_V_Skyrim_Special_Edition/)
- [SKSE64](https://skse.silverlock.org/)
- [SkyrimNet](https://www.nexusmods.com/skyrimspecialedition/mods/136016)
- [JContainers SE](https://www.nexusmods.com/skyrimspecialedition/mods/16495)
- [PapyrusUtil SE](https://www.nexusmods.com/skyrimspecialedition/mods/13048)
- [powerofthree's Papyrus Extender](https://www.nexusmods.com/skyrimspecialedition/mods/22854)

### FOMOD Installer

Install with any mod manager (MO2, Vortex). The FOMOD installer lets you pick exactly which modules you want:

1. **Page 1 — Action Modules**: Choose which actions NPCs can perform
2. **Page 2 — Prompt Modules**: Choose what context NPCs are aware of
3. **Page 3 — Adult Content**: Optional modules for supported adult mods

The **Core** files are always installed and include all Papyrus scripts, the native DLL, the ESP plugin, and JSON databases.

---

## Project Structure

```
SeverActions/
├── 00 Core/                          # Always installed
│   ├── SeverActions.esp              # Plugin file
│   ├── SKSE/Plugins/
│   │   ├── SeverActionsNative.dll    # Native C++ SKSE plugin
│   │   └── SeverActions/
│   │       ├── CraftingDB/           # Craftable item databases (JSON)
│   │       └── TravelDB/            # Travel marker databases (JSON)
│   ├── Scripts/                      # Compiled Papyrus scripts (.pex)
│   └── Source/Scripts/               # Papyrus source scripts (.psc)
│
├── Actions/                          # Action YAML configs (selectable)
│   ├── Basic/                        # Follow, wait, relax, items
│   ├── Travel/                       # Travel to locations
│   ├── Combat/                       # Attack, cease, yield
│   ├── Outfit/                       # Equip, remove, dress, undress
│   ├── Furniture/                    # Sit, lay down, stand up
│   ├── Economy/                      # Give gold, collect, extort
│   ├── Crafting/                     # Craft, cook, brew
│   ├── Arrest/                       # Arrest, bounty, jail
│   ├── Adult-OSLAroused/             # OSL Aroused integration
│   └── Adult-SLOAroused/            # SL Aroused integration
│
├── Prompts/                          # Context prompt templates (selectable)
│   ├── Core/                         # Spells, gold, inventory, nearby
│   ├── Combat/                       # Combat awareness
│   ├── Travel/                       # Travel guidance rules
│   ├── Survival/                     # Hunger, cold, fatigue
│   ├── Faction/                      # Guild reputation
│   ├── Arrest/                       # Bounty and jail status
│   ├── Economy-Anywhere/             # Merchant (always active)
│   ├── Economy-LocationOnly/         # Merchant (location-restricted)
│   ├── Adult-OSLAroused/             # Arousal awareness (OSL)
│   ├── Adult-SLOAroused/            # Arousal awareness (SLO)
│   └── Adult-Fertility/             # Fertility cycle awareness
│
├── Triggers/                         # Event triggers
│   └── Adult/                        # Abort Pregnancy trigger
│
└── fomod/                            # FOMOD installer config
    ├── info.xml
    └── ModuleConfig.xml
```

---

## Papyrus Scripts

| Script | Lines | Purpose |
|--------|-------|---------|
| `SeverActionsNative` | 543 | Native DLL function declarations — string ops, databases, inventory, nearby search, furniture, survival, fertility, NSFW |
| `SeverActions_Init` | — | Mod initialization, database loading, event registration |
| `SeverActions_MCM` | — | Mod Configuration Menu — toggle features, adjust settings |
| `SeverActions_Hotkeys` | — | Hotkey registration and handling |
| `SeverActions_Follow` | — | Follower management — start/stop following, wait, relax, sandbox |
| `SeverActions_Travel` | — | Travel system — location lookup, walking packages, speed control |
| `SeverActions_Combat` | — | Combat actions — attack, cease, yield with package management |
| `SeverActions_Crafting` | 1509 | Full crafting pipeline — forge/cooking/alchemy with native DB integration |
| `SeverActions_Currency` | 272 | Gold transactions with conjured gold fallback |
| `SeverActions_Outfit` | — | Equipment management — equip/remove individual pieces or full outfits |
| `SeverActions_Furniture` | — | Furniture interaction with native auto-cleanup |
| `SeverActions_Loot` | — | Container looting and item pickup |
| `SeverActions_Arrest` | — | Crime system — bounty tracking, jail escort, persuasion |
| `SeverActions_Survival` | — | Follower survival — hunger, cold, fatigue tracking |
| `SeverActions_SpellTeach` | — | Spell teaching system |
| `SeverActions_WheelMenu` | — | Wheeler integration for quick actions |
| `SeverActions_EatingAnimations` | 339 | TaberuAnimation.esp integration — keyword-based food eating animations |
| `SeverActions_Arousal` | 143 | OSL Aroused integration — arousal state decorator and modification |
| `SeverActions_SLOArousal` | — | SexLab Aroused integration |
| `SeverActions_FertilityMode_Bridge` | — | Fertility Mode data caching bridge to native DLL |

---

## Configuration

The mod is configurable through the **MCM (Mod Configuration Menu)** in-game. Key settings include:

- **Crafting**: Craft time duration, forge search radius, material requirements
- **Travel**: Travel speed, marker database selection
- **Furniture**: Auto-stand distance (how far the player must move before NPCs stand up)
- **Survival**: Hunger/cold/fatigue thresholds and update intervals
- **Dialogue Animations**: Enable/disable conversation idle animations

---

## Extending the Mod

### Adding Custom Crafting Recipes

Add JSON files to `Data/SKSE/Plugins/SeverActions/CraftingDB/`. All `.json` files in the folder are automatically loaded and merged. Later files override earlier ones.

```json
{
    "weapons": {
        "dragonbone sword": "Dragonborn.esm|0x0401C014"
    },
    "armor": {
        "dragonscale armor": "Dragonborn.esm|0x0401C012"
    },
    "misc": {
        "gold ingot": "Skyrim.esm|0x0005AD9E"
    }
}
```

### Adding Travel Markers

Edit or add JSON files in `Data/SKSE/Plugins/SeverActions/TravelDB/`. Format:

```json
{
    "places": {
        "WhiterunBreezehome": {
            "name": "Breezehome",
            "aliases": ["breezehome", "my house in whiterun"],
            "marker": "0x00012345"
        }
    }
}
```

---

## Version History

| Version | Changes |
|---------|---------|
| **0.88** | Native DLL: Recipe DB, Alchemy DB, Survival system, Fertility Mode bridge, NSFW JSON builders. New actions: BrewPotion, CookMeal. Unified crafting pipeline. |
| **0.85** | Initial FOMOD release with modular installer. Core actions, prompts, and native plugin. |

---

## Credits

- **Sever** — Mod author
- **[SkyrimNet](https://www.nexusmods.com/skyrimspecialedition/mods/136016)** — The AI framework that makes this possible
- **[JContainers](https://www.nexusmods.com/skyrimspecialedition/mods/16495)** — JSON data storage
- **[PapyrusUtil](https://www.nexusmods.com/skyrimspecialedition/mods/13048)** — Extended Papyrus functions
- **[powerofthree's Papyrus Extender](https://www.nexusmods.com/skyrimspecialedition/mods/22854)** — Additional Papyrus functions

---

<p align="center">
  <em>Built for SkyrimNet — where NPCs don't just talk, they act.</em>
</p>
