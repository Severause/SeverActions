# SeverActions — SkyrimNet Action Pack

<p align="center">
  <strong>A comprehensive action, prompt, and behavior pack for SkyrimNet</strong><br>
  <em>Give NPCs the ability to act, not just talk.</em>
</p>

<p align="center">
  <code>62 Actions</code> &nbsp;&middot;&nbsp; <code>29 Context Prompts</code> &nbsp;&middot;&nbsp; <code>255 Native C++ Functions</code> &nbsp;&middot;&nbsp; <code>~26,900 Lines of Papyrus</code>
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
| **Book Reading** | Strict reading rules — NPCs read only real book text, never fabricated content |
| **Follower Context** | Relationship values (rapport/trust/loyalty/mood), morality, combat style, and companion behavior guidelines with relationship-influenced moral flexibility |
| **Group Awareness** | Shows traveling companions which other party members are nearby — scales naturally from duo to large group. Keeps dialogue conversational without checklist-style name-dropping |
| **Player Inventory** | What items the player is carrying — enables NPCs to reference and request specific items from the player's inventory |
| **Conversation Flow** | Anti-loop rules that prevent NPCs from repeating the same topics or echoing previous responses in circular conversations |
| **Relationship Assessment** | Periodic LLM-driven background evaluation of follower relationships based on recent events and memories. Runs every 5 game hours per follower — adjusts rapport, trust, loyalty, and mood without competing for action slots |
| **Equipment (OmniSight)** | What they're currently wearing with OmniSight-aware item names and descriptions. Ground truth enforcement — NPCs cannot claim to wear items not in their equipment list |
| **Follower Companion** | Detailed companion context for registered followers — relationship values, behavior guidelines, and companion-specific interaction rules |
| **Embedded Actions** | Inline action descriptions injected directly into the conversation context for streamlined action selection |
| **Action Selector Drilldown** | Hierarchical action browsing — NPCs first pick a category, then drill down to specific actions within it |

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

The included SKSE plugin (255 native functions) replaces slow Papyrus operations with native C++ implementations, providing 100-2000x performance improvements across all major systems:

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
| **Orphan Cleanup** | Periodic scanning of loaded actors for stale SeverActions LinkedRef keywords (travel, furniture, follow) not backed by any tracking system — fires mod events to clear orphaned packages and LinkedRefs that cause NPCs to stand around doing nothing |
| **PrismaUI Bridge** | Native C++ JSON builder for the PrismaUI configuration interface — assembles follower data, survival stats, hotkey states, and all settings into structured JSON for the React frontend |
| **PrismaUI Data Gatherer** | Collects real-time game state (follower roster, relationship values, outfit locks, combat styles, survival needs) and serializes it for the WebUI |
| **Follower Data Store** | In-memory follower data cache with SKSE cosave persistence — tracks per-follower state for fast native access without Papyrus StorageUtil round-trips |
| **Fertility Mode Bridge** | Cached fertility state lookups, cycle tracking, pregnancy status |
| **NSFW Utilities** | High-performance JSON assembly for SexLab event data (500-2000x faster than Papyrus) |

---

## Key Systems

### Follower Framework

A relationship-driven companion system where NPCs remember how they feel about the player and act accordingly:

- **Relationship tracking** — Rapport, Trust, Loyalty, and Mood on -100/+100 scales (Mood 0-100), persisted via StorageUtil
- **Morality system** — 4-tier morality (0=no morals, 1=violent but honest, 2=petty theft OK, 3=strict moral code) with relationship-based flexibility — NPCs with high rapport/trust/loyalty will bend their rules more for a player they care about
- **Framework integration** — Automatically detects Nether's Follower Framework (NFF) or Extensible Follower Framework (EFF) and routes recruit/dismiss through the framework's controller when present, falls back to vanilla teammate system when neither is installed. 4-way dismiss routing: NFF > EFF > custom (preserves pre-existing teammate status) > vanilla. **NFF ignore token detection** — custom AI followers (Inigo, Lucien, Kaidan, etc.) with NFF's `nwsIgnoreToken` are automatically routed to track-only mode instead of through NFF, preventing conflicts with their custom AI. **MCM recruitment mode toggle** — "Auto" (default, uses NFF/EFF when installed, respects ignore tokens) or "SeverActions Only" (bypasses NFF/EFF entirely, uses our own alias-based follow system). Takes effect on next recruit
- **Dual follow system** — Casual follow (SkyrimNet package for guards and random NPCs) and companion follow (CK alias-based package with LinkedRef for formal companions) operate independently with strict eligibility separation — action YAMLs and wheel menu enforce that companions never receive casual follow actions and vice versa
- **Instant detection** — Native C++ teammate monitor scans loaded actors every second; followers recruited via vanilla dialogue or any mod are detected and onboarded within ~1 second, no save/load required
- **Auto-detection on load** — Followers recruited outside SeverActions while the mod was inactive are automatically detected and tracked on game load
- **Combat styles** — Aggressive, defensive, ranged, healer, or balanced — configurable per follower
- **Home assignment** — NPCs can be assigned a home location and will return there when dismissed
- **Relationship persistence** — All relationship data survives dismissal, re-recruitment, and temporary teammate status changes (IntelEngine, etc.); returning followers are recognized and keep their full relationship history
- **Automatic relationship assessment** — Background LLM evaluation of follower relationships every 5 game hours. The AI reviews recent events and memories, then adjusts rapport, trust, loyalty, and mood organically — no action slot needed. Configurable interval via MCM
- **Relationship cooldown** — Configurable per-actor cooldown (default 2 minutes) prevents the AI from spamming relationship changes every dialogue line
- **Outfit persistence** — Outfit locks survive dismissal — dismissed followers keep their equipped outfits when sent home
- **Up to 10 companions** — Default max of 10 simultaneous followers, configurable up to 20 via MCM
- **Hotkeys and wheel menu** — Dedicated hotkeys for follow toggle, dismiss all, set companion, and wait/resume. UIExtensions wheel menu with all actions in one place
- **MCM configuration** — Per-follower sliders for all relationship values, combat style dropdown, survival stats display, and outfit lock status

### Outfit Manager

NPCs can equip and unequip items by name, handle multiple items in a single action, save/recall outfit presets, and keep their outfits persistent across cell transitions:

- **Name-based equipping** — `EquipArmor` / `UnequipArmor` use C++ `FindItemByName` for fast inventory search, Papyrus `EquipItem` for thread-safe equipping
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
| [PrismaUI](https://www.nexusmods.com/skyrimspecialedition/mods/148718) | Modern in-game configuration interface — tabbed React UI replaces MCM for companion management, hotkeys, and all settings |
| [Nether's Follower Framework](https://www.nexusmods.com/skyrimspecialedition/mods/55653) | Follower recruit/dismiss routed through NFF when detected — prevents faction conflicts |
| [Extensible Follower Framework](https://www.nexusmods.com/skyrimspecialedition/mods/7003) | Follower recruit/dismiss routed through EFF when detected (NFF takes priority if both installed) |
| [NPC Names Distributor](https://www.nexusmods.com/skyrimspecialedition/mods/81214) | Guard dispatch can find NPCs by their NND-assigned names |
| [Immersive Equipping Animations](https://www.nexusmods.com/skyrimspecialedition/mods/70249) | Slot-appropriate equip/unequip animations for outfit actions |
| OmniSight | Gender-aware item names and descriptions in the equipment prompt — enriches NPC clothing/armor awareness |
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
|   |   +-- SeverActionsNative.dll        # Native C++ SKSE plugin (255 functions)
|   |   +-- SeverActionsNative.toml       # Plugin configuration
|   |   +-- SkyrimNet/config/plugins/     # WebUI plugin config (manifest + settings)
|   +-- PrismaUI/views/SeverActions/      # PrismaUI React frontend (built assets)
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
+-- PrismaUI-frontend/                    # PrismaUI React source (TypeScript + Vite)
|   +-- src/pages/                        # Dashboard, Companions, World, Hotkeys, Settings
|   +-- src/components/                   # Reusable UI controls (sliders, toggles, dropdowns)
|   +-- src/lib/                          # SKSE API bridge, settings sync, constants
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
| `SeverActions_MCM` | 2,299 | Mod Configuration Menu — toggle features, adjust settings, companion dropdown selector, per-follower relationship sliders, survival stats, outfit lock status, speaker tag toggles |
| `SeverActions_FollowerManager` | 2,107 | Follower framework — roster, relationships, NFF/EFF integration, 4-way dismiss routing, instant teammate detection via native DLL events, combat styles with load persistence, home assignment, outfit slot management, sleep sandbox cleanup (cell-restricted), orphan cleanup event handler, automatic LLM-based relationship assessment |
| `SeverActions_Travel` | 1,706 | Travel system — location lookup, walking packages, speed control, stuck recovery, orphan cleanup tracking |
| `SeverActions_Outfit` | 1,604 | Equipment management — equip/unequip by name, batch operations, outfit presets, persistent outfit locking with known-item lock and slot conflict detection |
| `SeverActions_Loot` | 1,487 | Container looting, corpse searching, item pickup/give/take, flora harvesting, book reading — with verified item transfers, leveled list fallback, and name-based recipient lookup |
| `SeverActions_Survival` | 1,463 | Follower survival — hunger, cold, fatigue tracking with native calculation, beverage detection |
| `SeverActions_Debt` | 1,443 | Debt/tab system — creation, tracking, auto-growth, credit limits, due dates, payment reduction, faction reporting, complaint summaries |
| `SeverActions_Combat` | 1,245 | Combat actions — attack, cease, yield with C++ aggression restoration monitor and yield persistence alias system |
| `SeverActions_Crafting` | 1,187 | Full crafting pipeline — forge/cooking/alchemy with native DB integration |
| `SeverActionsNative` | 1,062 | Native DLL function declarations (255 functions) |
| `SeverActions_PrismaUI` | 1,053 | PrismaUI configuration interface — bridges the React frontend to Papyrus, handles settings read/write, follower data serialization, and WebUI event callbacks |
| `SeverActions_SpellTeach` | 980 | Spell teaching system with school-specific failure consequences, narration sync, conjuration portal VFX, and action cooldowns |
| `SeverActions_Hotkeys` | 766 | Hotkey registration and handling — follow, dismiss, wait, companion, yield, outfit, furniture |
| `SeverActions_Init` | 640 | Mod initialization, database loading, event registration, follower framework init, WebUI plugin config sync |
| `SeverActions_Follow` | 606 | Dual follow system — casual follow (SkyrimNet package) and companion follow (CK alias-based with LinkedRef), sandbox management with self-healing priority system, unconditional sandbox cleanup, ClearPackageOverride safety nets, alias slot assignment, orphan cleanup tracking |
| `SeverActions_FertilityMode_Bridge` | 436 | Fertility Mode data caching bridge to native DLL |
| `SeverActions_WheelMenu` | 434 | UIExtensions wheel menu — all actions in one radial interface with context-aware labels, companion-aware routing |
| `SeverActions_EatingAnimations` | 338 | TaberuAnimation.esp integration — keyword-based food eating animations |
| `SeverActions_Currency` | 321 | Gold transactions with conjured gold fallback, auto-debt reduction on CollectPayment |
| `SeverActions_Furniture` | 237 | Furniture interaction with native auto-cleanup |
| `SeverActions_SLOArousal` | 164 | SexLab Aroused integration |
| `SeverActions_Arousal` | 142 | OSL Aroused integration — arousal state decorator and modification |
| `SeverActions_OutfitAlias` | 91 | Per-follower ReferenceAlias for zero-flicker outfit persistence across cell transitions |
| `SeverActions_YieldAlias` | 74 | Per-slot ReferenceAlias for yielded NPC persistence — OnLoad re-applies surrender state, OnDeath frees slot |
| | **~26,900** | **Total** |

---

## Configuration

The mod is configurable through **PrismaUI** (a modern in-game HTML/CSS/JS interface) or the classic **MCM (Mod Configuration Menu)**:

### PrismaUI Configuration (Recommended)

A tabbed React-based interface accessible in-game through PrismaUI. Pages include:

- **Dashboard** — At-a-glance overview of mod status and active systems
- **Companions** — Full companion management with relationship bars, combat style selection, survival stats, outfit lock controls, and home assignment
- **World** — Travel, crafting, economy, and survival settings
- **Hotkeys** — Visual hotkey configuration with real-time key display
- **Settings** — Global mod settings, debug toggles, and system configuration

PrismaUI requires [PrismaUI](https://www.nexusmods.com/skyrimspecialedition/mods/148718) to be installed. The MCM remains available as a fallback for users without PrismaUI.

### MCM Configuration

- **Crafting** — Craft time duration, forge search radius, material requirements
- **Travel** — Travel speed, marker database selection
- **Furniture** — Auto-stand distance (how far the player must move before NPCs stand up)
- **Survival** — Hunger/cold/fatigue thresholds and update intervals
- **Hotkeys** — Configurable keybinds for follow, dismiss, wait/resume, set companion, yield, outfit, stand up. UIExtensions wheel menu key. Target mode selection (crosshair, nearest NPC, last talked to)
- **Followers** — Per-follower Rapport, Trust, Loyalty, Mood sliders, Combat Style dropdown, survival stats (hunger/fatigue/cold percentages), outfit lock status. Max companions slider (up to 20). Relationship cooldown slider (60-300 seconds). Automatic relationship assessment toggle and interval (game hours). Outfit lock system toggle. Recruitment Mode dropdown (Auto / SeverActions Only)
- **Crime** — Per-hold bounty display with clear options
- **Dialogue Animations** — Enable/disable conversation idle animations
- **Speaker Tags** — Toggle [COMPANION], [ENGAGED], and [IN SCENE] tags in the speaker selector prompt. Disabling a tag removes it and all related AI guidance from the prompt
- **Spell Teaching** — Enable/disable the failure system, adjust failure difficulty multiplier
- **Debug** — Verbose logging for troubleshooting dispatch and escort behavior

---

## Version History

| Version | Changes |
|---------|---------|
| **0.99.9-dev** | **PrismaUI Overhaul** — Complete rewrite of the PrismaUI frontend from vanilla HTML/CSS/JS to a React + TypeScript + Vite stack. New page architecture: Dashboard, Companions, World, Hotkeys, Settings (replaces old General, Followers, Survival, Travel, Bounty, Currency, Outfits pages). Native C++ `PrismaUIDataGatherer` assembles all follower and game state data into structured JSON for the frontend. `FollowerDataStore` provides in-memory per-follower data caching with SKSE cosave persistence. UI scale support for high-DPI displays. **Survival Fixes** — Corrected survival stat calculations and food detection in the native DLL. **Hierarchical Action Categories** — New `cat_*.yaml` category actions enable drilldown prompts — the AI first picks a category (companion, inventory, magic, etc.), then selects the specific action within it. New `native_action_selector_drilldown.prompt` and `0750_embedded_actions.prompt` support the hierarchy. |
| **0.99.8-dev** | **PrismaUI React Config Menu** — First implementation of the React-based PrismaUI configuration interface with native C++ JSON builder. `SeverActions_PrismaUI.psc` (1,053 lines) bridges the frontend to Papyrus for settings read/write. WebUI plugin manifest and settings.yaml for SkyrimNet plugin config integration. **AssignHome Hotkey** — New hotkey to assign a follower's home location. Gold amount now shown in TakeItem notifications. Follower and outfit caps raised to 20. **DefaultOutfit Fallback** — Outfit system now falls back to the NPC's default outfit when no locked outfit exists, preventing naked NPCs after outfit lock disable. Home tracking and sandbox notification improvements. PreventEquip fixes for outfit lock edge cases. |
| **0.99.7-dev** | **Speaker Tag Toggles** — [COMPANION], [ENGAGED], and [IN SCENE] tags in the speaker selector prompt are now individually toggleable via MCM and WebUI. When a tag is disabled, the tag itself and all related AI guidance text (companion chattiness rules, engagement bias, scene deprioritization) are stripped from the prompt entirely. Controlled via StorageUtil keys read by the prompt template with Inja conditionals. **GiveItemTrue Action** — New `GiveItemTrue` action mirrors `GiveGoldTrue` pattern — target is specified by string name instead of Actor reference, resolved at runtime via `FindActorByName`. Delegates to existing `GiveItem_Execute` for full inventory/merchant chest lookup, animation, debt tracking, and event registration. **TakeItemFromPlayer Notifications** — `TakeItemFromPlayer_Execute` now shows `Debug.Notification` feedback when an NPC takes an item (e.g., "Lydia took Iron Sword", "Lydia took Health Potion (3)"). **WebUI Plugin Config** — Added `settings.yaml` to the FOMOD package so SkyrimNet's WebUI plugin configuration loads without a 404 error on fresh installs. Speaker tag toggles, spell teaching settings, and all existing config fields included with defaults. **Conjuration Portal VFX** — Failed conjuration teaching now spawns a purple conjuration vortex (`SummonTargetFXActivator` 0x0007CD55) before the hostile creature appears, matching vanilla conjuration ritual visuals. |
| **0.99.6-dev** | **Spell Teaching System** — New `LearnSpell` and `TeachSpell` actions let NPCs teach spells to the player or learn spells from spell tomes in their inventory. `SeverActions_SpellTeach.psc` handles spell lookup by name via native C++ `FindSpellByName`, with school/level display and duplicate detection. **Relationship Assessment — Player Dialogue** — Assessment prompt now captures both sides of player↔follower conversations. Previously only the NPC's dialogue was visible to the assessment LLM. Fixed by matching on `ev.data.speaker`/`ev.data.listener` name fields (event data uses names, not UUIDs) and capturing `dialogue_player_text`/`dialogue_player_stt` event types alongside regular `dialogue` events. Player speech is filtered to only include lines directed at the specific follower being assessed. **Dialogue Speaker Selector — Silence Softening** — Reduced excessive silence by softening the "waiting for player response" rule. Direct questions/requests to the player still prefer silence, but companions can now react to statements and speak to each other. ENGAGED tag changed from "prefer silence after they speak" to "don't let them dominate — mix in other speakers." **WebUI ↔ MCM Silence Chance Sync** — Fixed silence chance not syncing between WebUI plugin config and MCM. `SyncPluginConfig()` now writes to both StorageUtil (for prompt templates) and the MCM property. Works both on game load and mid-game via the `SkyrimNet_OnPluginConfigSaved` ModEvent callback. **Book Reading MCM Toggle** — Fixed Book Reading Style option not appearing on existing saves. `BookReadModeOptions` array is now initialized on-the-fly in `DrawGeneralPage` with a null check, handling cases where the version update event didn't fire. **Relationship Assessment Cooldown Simplification** — Removed engagement-based skip/prioritization from `CheckRelationshipAssessments`. Assessment now fires purely on a game-time cooldown per follower, picking the most overdue candidate. Eliminates the false-negative where `recentEventCountShort == 0` prevented all assessments from firing. |
| **0.99.5** | **Native PackageManager** — New C++ LinkedRef management system with SKSE cosave persistence. All `PO3_SKSEFunctions.SetLinkedRef` calls across 5 scripts (39 occurrences) replaced with native `SeverActionsNative.LinkedRef_Set`/`LinkedRef_Clear`/`LinkedRef_ClearAll`. LinkedRefs are tracked in a map and serialized to SKSE cosave — auto-restored on game load before Papyrus `Maintenance()` even runs, eliminating the need for manual re-linking code. Death auto-cleanup via `TESDeathEvent` removes all tracked LinkedRefs when an actor dies. Engine relocation approach (`RELOCATION_ID(11633, 11779)`) for safe LinkedRef manipulation — same method as PO3_SKSEFunctions. **Native GuardFinder** — Replaced Papyrus cell iteration in guard dispatch with C++ `ForEachReferenceInRange`. Guards are found by hold faction membership using native reference scanning instead of slow `cell.GetNthRef()` loops. **Companion/Casual Follow Separation** — Fixed bug where companions could receive casual follow actions (Relax, StopRelaxing, StopFollowing) from the LLM, registering SkyrimNet's FollowPlayer runtime package on top of the CK alias follow package and creating conflicting behavior. Added `is_follower == false` eligibility rules to Relax, StopRelaxing, and StopFollowing action YAMLs. **WheelMenu Companion Routing** — `HandleWait` and `HandleFollowToggle` now check `IsRegisteredFollower(target)` and route companions through `CompanionFollow`/`CompanionWait` instead of the casual follow path. Non-followers attempting wait get a notification instead of a crash. **Unconditional Sandbox Cleanup** — `CompanionStartFollowing` and `CompanionStopFollowing` no longer gate sandbox cleanup on `SkyrimNetApi.HasPackage("Sandbox")`. If SkyrimNet tracking was lost (save/load edge case), the PO3 `AddPackageOverride` with flag 1 (forced top of stack) would persist forever, blocking all other packages. Cleanup is now unconditional — `RemovePackageOverride` + `UnregisterSandboxUser` + `UnregisterPackage` always fire. **Native EvaluatePackage** — `NativeEvaluatePackage(Actor)` calls `actor->EvaluatePackage()` directly in C++, bypassing Papyrus VM overhead. |
| **0.99** | **Loot Transfer Fix** — `ProcessLootList` now reliably transfers items from containers and corpses. The "all" path uses `RemoveAllItems` for correct handling of leveled lists that `GetNthForm` can't resolve on unopened containers. The "valuables", "gold", and "specific items" paths now verify each `RemoveItem` with `GetItemCount` and fall back to `RemoveAllItems` if individual removals fail on unresolved leveled forms. **Sandbox/Follow Self-Healing Priority** — Sandbox package priority lowered to 40 (below follow at 50), making the system self-healing: orphaned FF sandbox packages from bad transitions or sleep time-skips can never block following. `Sandbox()` now explicitly removes the follow package before applying sandbox. `StartFollowing()` and `StopSandbox()` use `ClearPackageOverride` as a safety net to nuke all runtime overrides before re-applying fresh packages. **Speaker Selector Rebalance** — Merged old and new speaker selector philosophies. `zerochance` lowered from 70 to 60 (40% forced speech). Silence rules always visible regardless of zerochance roll. Softened silence directive — companions don't default to silence when they'd realistically speak. "Do NOT choose silence" expanded from 3 to 7 companion-friendly triggers. Added NPC-to-NPC targeting rule (`Vayne>Alva` instead of `Vayne>player` when NPCs are talking to each other). Anti-loop conversation detection added. **Group Conversation Rewrite** — Rewrote `0260_severactions_engaged_participants.prompt` for groups of 2+. Removed MANDATORY checklist-style participation rules. NPCs speak to whoever they're actually engaging with, use names only when it makes sense, and don't force name-dropping. Natural awareness replaces meeting-facilitator energy. **Automatic Relationship Assessment** — New LLM-driven background relationship evaluation that runs every 5 game hours (configurable). Reviews recent events and memories, then adjusts rapport, trust, loyalty, and mood organically without competing for action slots. Replaces the need for `AdjustRelationship` to fire during active conversation. Game-time-based cooldown per follower. MCM toggle and interval slider. **OmniSight Equipment Prompt** — New `0410_equipment.prompt` in the Outfit module. Shows worn equipment with OmniSight-aware gender-specific item names and descriptions. Displays weapon drawn/sheathed state. Ground truth enforcement prevents NPCs from claiming to wear items not in their equipment list. **Follow System Maintenance** — `Maintenance()` now re-applies ENGAGED faction to loaded actors with active `FollowPlayer` packages on game load (faction state doesn't persist across saves but SkyrimNet packages do). `StartFollowing`/`StopFollowing` properly manage ENGAGED state transitions. **Sleep Sandbox Cleanup** — Restricted to followers in the same cell as the player (was all followers). Non-sandboxing followers in the player's cell get `ClearPackageOverride` + `ReinforcePackages` to clear orphaned runtime packages from the sleep time-skip. **Conversation Flow** — Anti-loop rules added to `0550_severactions_conversation_flow.prompt` preventing NPCs from repeating the same conversation topics. **Action YAML Streamlining** — Outfit actions renamed (`EquipArmor` → `EquipItems`, `UnequipArmor` → `UnequipItems`). Parameter schemas fixed across multiple actions. Orphan cleanup system added to native DLL. **Removed** `0910_follower_action_guidance.prompt` — action guidance now handled entirely by YAML descriptions and relationship context prompt. |
| **0.98.5** | **Yield Persistence System** — Surrendered generic NPCs (bandits, necromancers, etc.) now persist across cell transitions and save/load via a new ReferenceAlias slot system (`YieldSlots`). When a hostile NPC yields, they're assigned a persistence slot that prevents the engine from recycling them. Each slot runs `SeverActions_YieldAlias` with an `OnLoad` event that re-zeros Aggression, re-applies SeverSurrenderedFaction membership, and re-registers with the native C++ yield monitor — fixing an issue where yielded NPCs would turn hostile again after cell transitions because the engine reset their actor values from template. `OnDeath` frees slots automatically. `ReassignYieldSlots` repopulates all slots on game load from a StorageUtil tracking list (since `ForceRefTo` is runtime-only). **Combat Style Persistence** — Combat style actor values (Confidence, Aggression) now survive save/load and dismiss/re-recruit cycles. New `ApplyCombatStyleValues` extracted function and `ReapplyCombatStyles` called from Maintenance on every game load. Returning followers get their stored combat style re-applied on re-recruit. **Sleep Sandbox Cleanup** — Followers with active sandbox packages (from relax/wait actions) now have those packages cleared automatically when the player sleeps. `OnSleepStart` iterates all followers and calls `StopSandbox` on any with an active sandbox override, preventing odd runtime packages during the sleep time-skip. **MCM Companion Selector** — Followers MCM page redesigned with a dropdown companion selector instead of listing all companions simultaneously. Shows one companion at a time with all stats, relationship sliders, survival needs, outfit lock status, and controls. **Outfit Lock Slot Conflict Fix** — `LockEquippedOutfit` now detects slot mask conflicts between newly equipped items and stale `GetWornForm` results, preventing displaced items from persisting in the lock list and fighting newly equipped gear. `ReapplyLockedOutfit` now suspends/resumes the outfit lock during re-equip to prevent recursive `OnObjectUnequipped` calls, with a re-entry guard via `SeverOutfit_Suspended`. **Equipment Ground Truth Prompt** — Added enforcement line to worn equipment prompt establishing the equipment list as canonical truth — NPCs cannot claim to wear items not in the list. **Enhanced Speaker Selector Rewrite** — Complete rewrite of `dialogue_speaker_selector.prompt`. Silence reduced from 90% to 70%. Companion behavior reframed: companions are the "core cast" encouraged to banter, react, joke, warn, and express personality freely. Silence criteria now primarily targets bystanders (merchants, guards, strangers) while companions are expected to be active party participants. Selection criteria reordered with unresolved questions at #1, companion dynamics elevated to #3 with detailed behavioral guidance. |
| **0.98** | **Debt System** — Full financial obligation tracking with 5 new actions (`AddToDebt`, `CreateDebt`, `CreateRecurringDebt`, `ForgiveDebt`, `GiveGoldTrue`). NPCs can run tabs, set credit limits, assign due dates, and report overdue debts to faction-appropriate guards. `GiveItem` auto-adds item value to existing debts (no double-charging). `CollectPayment` auto-reduces matching debts — partial payments reduce the balance, full payments clear it. Debt context prompt shows all obligations in the NPC's AI context. Removed `SettleDebt` action — LLMs naturally use `CollectPayment` instead. **Outfit Lock Race Condition Fix** — Fixed bug where outfit lock captured the old outfit instead of the newly equipped one. Root cause: Papyrus `OnObjectUnequipped` events fire on separate stacks after the equip function returns, and `GetWornForm()` returns stale data before the engine finalizes equip state. New `LockEquippedOutfit` function builds the lock from KNOWN equipped items (guaranteed fresh) merged with `GetWornForm` for unchanged slots. Rewired `EquipMultipleItems`, `EquipItemByName`, `Dress`, and `ApplyOutfitPreset`. Also fixed `Dress_Execute` early return not calling `ResumeOutfitLock` (would permanently suspend the lock). **Anti-Hallucination Prompt** — New `0600_severactions_dialogue_rules.prompt` prevents NPCs from echoing system/action text (gold amounts, debt totals, `[item_given]` tags, "X gave Y to Z" patterns) in their dialogue or narration. **AdjustRelationship Priority Fix** — Demoted from "use after EVERY exchange" to LOW PRIORITY fallback, fixing issue where models chose it over gameplay actions like `CollectPayment` or `GiveItem`. **Bounty Awareness** — New prompt gives guards awareness of player's bounty in the current hold. **FOMOD Prompt Overrides** — Two new optional modules: Strict Action Selector (reinforces one-action-per-turn, prevents duplicate action calls from models like Grok) and Enhanced Target Selectors (improved speaker/target routing with companion tags, conversation momentum, crosshair weighting). **Action YAML Audit** — All actions updated with tracking-only mode support. |
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
