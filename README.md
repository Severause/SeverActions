# SeverActions — SkyrimNet Action Pack

<p align="center">
  <strong>An action, prompt, and behaviour pack for SkyrimNet</strong><br>
  <em>Give NPCs the ability to act, not just talk.</em>
</p>

<p align="center">
  <code>119 Actions</code> &nbsp;&middot;&nbsp; <code>74 Context Prompts</code> &nbsp;&middot;&nbsp;
  <code>~63,000 Lines of Papyrus</code> &nbsp;&middot;&nbsp; <code>~135,000 Lines of C++</code>
</p>

---

## Overview

**SeverActions** extends SkyrimNet with actions, prompts, and a native SKSE plugin that together let
NPCs act on what they say. They follow you and travel across Skyrim, craft and cook and brew, manage
their outfits, handle gold and debt, sit down, fight, get arrested and escorted to jail, settle
disputes with fists, run businesses for you, and remember what happened.

One principle runs through all of it: **the AI decides what to do, and the mod makes it happen
in-game** — with the engine's own systems, not around them.

---

## Features

### Actions by module

Each module is a separate FOMOD option. Install only what you want.

| Module | Actions | What it does |
|---|---:|---|
| **Basic** | 18 | Follow, pick up, give/take/bring items, loot containers and corpses, read books aloud, cast and teach spells and shouts, transfer ownership |
| **Enterprises** | 26 | Hire NPCs to run mines, shops, farms, fences and guard posts. Weekly settlements, wages, arrears, loans, hold stewards, taxes, hired-thug reprisals, outlaw-camp takeovers |
| **Arrest** | 14 | Guards track bounties, dispatch across cells, escort prisoners who can plead mid-escort, investigate homes, and pass judgment |
| **Economy** | 10 | Gifts, payments, extortion, atomic item-for-gold trades, tabs, credit limits, due dates, recurring debt |
| **Follower** | 9 | Companion framework with rapport, trust, loyalty and mood; homes, work and play locations, combat styles, follow distance |
| **Outfit** | 8 | Equip/unequip by name, save and recall presets, situation outfits that switch automatically, persistent outfit locking |
| **Kidnap & Captives** | 7 | Abduct or restrain a named NPC, with ransom, interrogation, escape and consequences *(kidnap is opt-in; restrain ships on)* |
| **Crafting** | 5 | Walk to a workstation, craft/cook/brew, deliver the result; commissions matured over in-game days |
| **Combat** | 5 | Attack, cease fire, yield, and the outlaw-standoff verbs |
| **Brawl** | 4 | Non-lethal fist fights — challenge, accept, decline, forfeit. Damage routes to bleedout; weapons and spells are stripped for the duration |
| **Travel** | 3 | Navigate to named locations with a non-pausing confirmation popup, adjustable pace, and off-screen simulation |
| **Furniture** | 2 | Chairs, benches, beds and crafting stations, with automatic cleanup |
| **Adult (optional)** | 2 | OSL Aroused / SexLab Aroused arousal adjustment |
| **Sever's Hearth (bundled)** | 3 | Establish and break camp, and travel back to it |

### Context prompts

Prompts inject live game state into the AI's context, so NPCs *know* things rather than inventing
them. 74 templates across 16 installable modules — the largest being **Enterprises** (23), **Core**
(15), and **Follower** (14).

They cover: known spells · carried gold · inventory and worn gear · nearby objects and containers ·
the player's inventory · combat and brawl state · survival needs · familiarity and reputation ·
bounty and jail status · merchant stock · debts · retainer and enterprise status · commissions ·
quest memory · off-screen life · camp and truce state · relationships between companions.

### Behaviour systems

Things that run without being asked:

- **Companions with continuity** — relationships drift, companions form opinions about *each other*,
  and dismissed followers live a life while you're away that they'll tell you about.
- **Outlaw truces** — bandits and other outlaws hold their fire until provoked, so conversation is
  possible at all. Camps can be talked into working for you, by their chief or by consensus.
- **Off-screen travel** — NPCs sent somewhere actually get there, simulated across unloaded cells.
- **A working crime system** — bounties, guards, jails, escorts, evidence and judgment.
- **Survival needs** for followers, with hunger, cold and fatigue.

---

## Requirements

| | |
|---|---|
| **Required** | Skyrim SE/AE, SKSE64, [SkyrimNet](https://www.nexusmods.com/skyrimspecialedition/mods/148913), Address Library, PapyrusUtil |
| **Recommended** | PrismaUI (in-game configuration UI), SkyUI (MCM) |
| **Optional** | Nether's Follower Framework · Devious Devices · OSL/SexLab Aroused · Fertility Mode · Dynamic Book Framework · UIExtensions |

SeverActions **coexists** with Nether's Follower Framework rather than competing with it: when NFF
owns a follower, recruit/dismiss/wait/resume are routed *through* NFF's own controller, and
SeverActions never touches that follower's AI packages.

---

## Installation

Install the archive with a mod manager and pick your modules in the FOMOD installer. Load order is
not sensitive; place it after SkyrimNet.

Prompt modules are separate from action modules — a module's actions and its prompts are usually
worth installing together, but nothing breaks if you don't.

---

## Configuration

Two surfaces, covering the same settings:

- **PrismaUI** — the main in-game interface. Dashboard, companions, inventory, world map and travel,
  outfits, survival, enterprises, and settings.
- **MCM** (SkyUI) — the same settings for VR and non-PrismaUI setups: Interface, Hotkeys, Prompt
  Filters, Followers, Off-Screen Life, Outfits, Survival, Combat & Outlaws, Crime & Bounty, Economy,
  Enterprises, Travel, and Reading & Spells.

Global preferences are stored **outside the save**, so a new character or a mod update keeps your
settings.

---

## Under the hood

Four layers, each doing what it is best at:

1. **Action YAMLs** declare what the AI may do and when it is eligible.
2. **Prompt templates** inject live state into the AI's context.
3. **Papyrus** owns quest aliases, packages and anything the engine only exposes to scripts.
4. **A native SKSE plugin** (~135k lines of C++) owns the data, the heavy scans, and everything
   performance- or thread-sensitive.

State lives in the **SKSE co-save** (~40 records) rather than in Papyrus properties, behind a shared
store base that gives every store the same save/load/revert contract and an opt-in migration path
for schema changes — so updates land on existing saves without wiping anything.

---

## Credits

- **Author** — Severause
- **[SkyrimNet](https://www.nexusmods.com/skyrimspecialedition/mods/148913)** by MinLL, which this builds on
- Map artwork by Caro Tuts ([Nexus #62705](https://www.nexusmods.com/skyrimspecialedition/mods/62705))
- Hold sigils derived from CoMAP map markers by **Parapets** ([Nexus #56123](https://www.nexusmods.com/skyrimspecialedition/mods/56123)) and the Cities of the North marker pack, re-tinted to a parchment palette for the World page
- Imperial Fiscal Levy armour **meshes and textures** by **NordwarUA** ([New Legion, Nexus #30468](https://www.nexusmods.com/skyrimspecialedition/mods/30468) — Base and Textures HD archives), recoloured to a Treasury livery for the Final Audit detail
- The General's writ-blade mesh and textures by **InsanitySorrow** ([Insanity's Ebony Sword Replacer, Nexus #37645](https://www.nexusmods.com/skyrimspecialedition/mods/37645)), recoloured to match the Treasury livery
- The Legates' blades by **billyro** ([Mage Glass Sword, Nexus #38798](https://www.nexusmods.com/skyrimspecialedition/mods/38798)), re-tinted storm-blue for Livia and ember for Drusilla

---

<p align="center">
  <em>Built for SkyrimNet — where NPCs don't just talk, they act.</em>
</p>
