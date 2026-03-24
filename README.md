# SeverActions

**A comprehensive action and companion framework for [SkyrimNet](https://github.com/MinLL/SkyrimNet).** Adds 59+ NPC actions, full companion management, PrismaUI dashboard, outfit system, arrest mechanics, economy, crafting, and more — all driven by AI.

## Features

### PrismaUI Dashboard
In-game visual interface for managing every aspect of your followers and the mod.
- **Companions** — Relationships (rapport/trust/loyalty/mood), combat style, home assignment, essential toggle, inter-follower relationships
- **Inventory** — Full inventory manager with transfer, equip, destroy. Category tabs with color-coded stats
- **Stats** — View follower skills and key stats (Health, Magicka, Stamina, Level)
- **Outfits** — Equip armor from the game catalog directly onto followers with outfit lock
- **Actions** — Trigger any action manually with inline actor selectors
- **Settings** — Per-category inventory limits, diary UI scale, recruitment mode

### Companion Framework
- **Three recruitment modes** — Auto (detects NFF/EFF), SeverActions Only, Tracking Only
- **NFF compatible** — Custom followers (Inigo, Lucien, Auri) tracked without triggering NFF
- **Serana support** — Routes through DLC mental model quest for proper behavior
- **Essential by default** — Per-follower toggle to disable
- **Relationship system** — Rapport, trust, loyalty, mood tracked over time with periodic AI assessment
- **Inter-follower relationships** — Followers build affinity and respect with each other
- **Off-screen life** — Followers have events while you're away, logged as real memories
- **Home assignment** — Works for custom followers too (post-dismiss redirect)

### 59+ AI-Driven Actions
| Category | Actions |
|----------|---------|
| **Companion** | Follow, Wait, Dismiss, Recruit, Assign Home, Set Combat Style, Leave |
| **Combat** | Attack, Yield, Ceasefire |
| **Economy** | Give Gold, Collect Payment, Extort, Debt tracking |
| **Outfit** | Equip, Unequip, Dress, Undress, Save/Load Presets, Outfit Lock |
| **Items** | Pick Up, Give, Take, Loot, Use, Read Books/Diaries |
| **Arrest** | Arrest NPC/Player, Jail, Release, Bounty, Persuasion, Guard Dispatch |
| **Crafting** | Forge, Brew Potions, Cook |
| **Magic** | Teach/Learn Spells |
| **Travel** | Go to location, Escort, Lead, Fetch |
| **Survival** | Food tracking, hunger system |

### Diary Viewer
Visual popup when reading NPC diaries — browse entries by date and location, select which to read aloud. Any follower can read any character's diary.

### Prompt Enhancements
- **Player inventory** in NPC awareness (per-category limits, 0 = hidden)
- **Personality reinforcement** — Lightweight submodule keeping NPCs in character
- **Off-screen life context** — NPCs reference what they did while you were away
- **Reputation & bounty** — NPCs aware of your standing

## Requirements
- [Skyrim SE](https://store.steampowered.com/app/489830/The_Elder_Scrolls_V_Skyrim_Special_Edition/) (1.6.1170+)
- [SKSE64](https://skse.silverlock.org/)
- [SkyrimNet](https://github.com/MinLL/SkyrimNet) (beta 17+)
- [SkyUI](https://www.nexusmods.com/skyrimspecialedition/mods/12604) (for MCM)
- [PapyrusUtil](https://www.nexusmods.com/skyrimspecialedition/mods/13048)

## Installation
1. Download the latest release from [Releases](https://github.com/Severause/SeverActions/releases)
2. Install with your mod manager (MO2, Vortex) — FOMOD installer lets you pick categories
3. **Core** is required. All other categories are optional.

## Compatibility
- **Nether's Follower Framework** — Fully compatible. Custom followers with NFF ignore tokens are tracked without interference.
- **IntelEngine** — Compatible. Companion actions separated from categories to avoid travel action conflicts.
- **Custom followers** (Inigo, Lucien, Auri, Kaidan, etc.) — Supported via Tracking Only mode + SPID keyword distribution.

## Configuration
- **MCM** — SeverActions menu in Mod Configuration
- **PrismaUI** — In-game dashboard (press configured hotkey)
- **Both sync** — Changes in MCM reflect in PrismaUI and vice versa
