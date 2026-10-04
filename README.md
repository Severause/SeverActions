# SeverActions — SkyrimNet Action Pack

<p align="center">
  <strong>An action, prompt, and behaviour pack for SkyrimNet</strong><br>
  <em>Give NPCs the ability to act, not just talk.</em>
</p>

<p align="center">
  <code>118 Actions</code> &nbsp;&middot;&nbsp; <code>78 Prompt Templates</code> &nbsp;&middot;&nbsp;
  <code>~62,000 Lines of Papyrus</code> &nbsp;&middot;&nbsp; <code>~148,000 Lines of C++</code>
</p>

<p align="center">
  <code>Skyrim SE &middot; AE &middot; VR</code> &nbsp;&middot;&nbsp; <code>SkyrimNet 0.25+</code> &nbsp;&middot;&nbsp;
  <code>Magelight UI 0.30.5 included</code>
</p>

<p align="center">
  <a href="https://ko-fi.com/severause"><img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Support me on Ko-fi"></a>
</p>

> [!IMPORTANT]
> **SeverActions 4.x needs SkyrimNet 0.25 (beta 25) or newer.** On an older SkyrimNet, none of its actions, prompts
> or triggers load.
>
> **Upgrading from 3.9.x?** Reinstall with **Replace**; don't merge into the old mod. See
> [Installing and upgrading](#installing-and-upgrading).

**Contents:** [What's new in 4.1](#whats-new-in-41) · [What's new in 4.0](#whats-new-in-40) · [Overview](#overview) · [Features](#features) ·
[Requirements](#requirements) · [Compatibility](#compatibility) · [Installing and upgrading](#installing-and-upgrading) ·
[Settings](#settings) · [Support and troubleshooting](#support-and-troubleshooting) · [Under the hood](#under-the-hood) ·
[Credits](#credits)

---

## What's new in 4.1

- **Wait and Follow answer at the first press**, Wait All and Follow All included: a command now undoes only what
  SeverActions actually put on a follower.
- **Faster loading**: on a long-running save, start-up after a load drops from about a minute to about twelve
  seconds, and commands given right after a load no longer wait behind it.
- **Magelight UI 0.30.5**: the menus show with DLSS and frame generation behind NVIDIA Streamline, with Community
  Shaders' frame generation and with NVIDIA Smooth Motion, and a new cursor. When the UI cannot draw, the menu and
  wheel keys say so.
- **Fixes**: mouse and gamepad buttons work as the menu and quick wheel keys again, casual follow works in Tracking
  mode, and companions in the follow pool are no longer pushed back onto their follow package every few seconds.

The full list is in [CHANGELOG.md](CHANGELOG.md).

## What's new in 4.0

- **A new in-game menu on Magelight UI**, which comes in the download and installs with the core. PrismaUI and
  UIExtensions are no longer needed.
- **Skyrim VR**: the menu, its popups and the quick wheel draw in the headset.
- **Action categories**: the AI opens a category before it picks an action, and NPCs act only on what they agree to in
  the line they just spoke. Plans for later stay talk.
- **Portraits** for companions, retainers, NPCs you gave a home, and your own character.
- **Companions sit down with you**, a **friendly-fire guard** stops companions turning on you or each other over a stray
  hit, and **Walk With Me** can lead SeverActions companions.
- **Redesigned pages**: Survival, Catalog (with a 3D item inspector), Bio Blocks, and the long lists on Enterprises.
- **Sever's Hearth**: your first camp becomes the company's base, which you can upgrade twice, and the new **Small
  Camp** can be pitched indoors.
- **A quick wheel whose 8 slots you choose**, Bio Blocks other mods can add to, the Imperial Levy keeping court at the
  Blue Palace in Solitude, and a long list of fixes.

The full list is in [CHANGELOG.md](CHANGELOG.md).

---

## Overview

**SeverActions** extends SkyrimNet with actions, prompts, and native SKSE plugins that together let NPCs act on what
they say. They follow you and travel across Skyrim, craft and cook and brew, trade and lend gold, change their outfits,
read books aloud, cast and teach spells, sit down, fight, make arrests and take captives, settle disputes with fists,
run businesses for you, and live their own lives while you are away.

It happens through conversation: when an NPC agrees to or decides on something in the line they speak, SeverActions
makes it happen in the game. You can also run most actions yourself from the menu's **Actions** page, and the common
ones (follow, wait, dismiss, dress and so on) from a hotkey or the quick wheel.

One principle runs through all of it: **the AI decides what to do, and the mod makes it happen in-game**, with the
engine's own systems, not around them.

---

## Features

### AI actions by installer option

Each row is an option in the installer: the first twelve are on the Action Modules page, the arousal actions on the
Adult Content page, and Sever's Hearth on its own page. An option decides which actions the AI is offered; the scripts
behind them install either way (Sever's Hearth aside, which is the whole camp system), so leaving an option out breaks
nothing.

| Installer option | Ticked by default | Actions | What NPCs can do |
|---|:---:|---:|---|
| **Basic Actions** | Yes | 18 | Tag along with you without joining your party (and stop), pick up, use (eat or drink), give, take or bring items, search and loot containers and corpses, read books aloud, cast spells, teach you a spell or learn one from you, teach you a Shout (one Word of Power per lesson), and hand you a house or business |
| **Travel Actions** | Yes | 3 | Travel to a named place, a direction (outside, upstairs), a nearby feature (the bar, the forge) or one of your markers; change pace on the way, or call the trip off |
| **Combat Actions** | Yes | 5 | Attack someone, call off a fight, or yield; with the outlaw truce on, an outlaw who stopped you at their camp lets you pass or turns the camp on you |
| **Brawl Actions** | Yes | 4 | Non-lethal fist fights between you and an NPC, or between two NPCs: challenge, accept, decline, forfeit. Weapons and spells are taken away for the fight and given back after |
| **Outfit Actions** | Yes | 8 | Put on or take off pieces by name, undress and get dressed, save and apply outfit presets, and set the outfit an NPC changes into by themselves (town, adventure, home, sleep, combat, rain, snow) |
| **Furniture Actions** | Yes | 1 | Sit, lie down or kneel to pray at nearby chairs, benches, beds and shrines; NPCs get up by themselves when you walk away |
| **Economy Actions** | No | 10 | Give gold, ask for payment, buy or sell an item at an agreed price in one step, and keep debts: tabs, credit limits, due dates, recurring charges, repaying, reducing and forgiving |
| **Enterprises Actions** | No | 26 | Hire retainers to run ventures for you and settle their pay, raises, loans and grievances; appoint hold stewards; ease or raise hold taxes; the Imperial Treasury's Final Audit; outlaw camps sworn to you and their war bands; standoffs with hired thugs |
| **Crafting Actions** | No | 5 | Walk to a forge, alchemy lab or cooking pot and craft, brew or cook; take a commission a smith forges over a few days for you to collect |
| **Arrest Actions** | No | 15 | Guards arrest, are dispatched across cells, search homes for evidence and escort prisoners to jail (a prisoner can plead once on the way); jarls and housecarls order arrests rather than making them; delivered prisoners are judged |
| **Follower Actions** | Yes | 6 | Recruit a companion, dismiss them, tell them to wait or follow again, and assign a home; a badly treated companion may leave on their own |
| **Kidnap and Captive Actions** | No | 8 | Any NPC can restrain someone and lead them, tie a captive to furniture or release them; your companions can also move, untie and interrogate captives, and kidnap for ransom (with Enable Kidnap Actions, off by default) |
| **OSL Aroused - Modify Arousal Action** / **SL Aroused - Modify Arousal Action** | No | 1 + 1 | Adjust an NPC's arousal (pick one of the two, or none) |
| **Sever's Hearth (Camp System)** | Yes | 7 | Make and break camp, promote a camp to the base, upgrade or break the base, and go to the camp or the base |

118 actions in all. The two arousal actions are alternatives, so a single install offers at most 117.

### Context prompts

Prompts put live game state into what the AI reads, so NPCs *know* things rather than inventing them; others drive the
background AI calls (relationship assessments, quest memory, off-screen life, retainer stories) or are the bios of the
pack's own characters. There are 78 templates, most chosen on the installer's Prompt Modules page. The largest options
are **Core Awareness** (39, the Enterprises prompts included) and **Follower Companion** (14); the Outfit, Economy and
Crafting action options and Sever's Hearth carry their own.

Ticked by default: Core Awareness, NPC Familiarity & Reputation, Combat Awareness, Brawl Awareness, Follower Companion
and Group Meeting Awareness. Not ticked: Survival, Arrest/Crime, and a Merchant prompt (Show Anywhere or Location
Restricted, one or none).

They cover: known spells · carried gold · inventory and worn gear · nearby objects and containers · the player's
inventory · combat and brawl state · survival needs · familiarity and reputation · bounty and jail status · merchant
stock · debts · retainer and enterprise status · commissions · quest memory · off-screen life · camp and truce state ·
relationships between companions.

### The in-game menu

Press **Shift+8** to open it (rebind it in Settings → Interface → Hotkeys or on the MCM Hotkeys page). Escape or the
menu key closes it, the Left and Right arrows switch pages, and the game pauses while it is open (Pause Game When Menu
Opens). Every page has a **?** button that explains it.

| Page | What it is for |
|---|---|
| **Dashboard** | Your character, alerts that need you, gossip and recent events |
| **Companions** | Each follower's orders, schedule, combat style, bonds, portrait and memories |
| **Bio Blocks** | Reusable character traits for NPCs and factions |
| **Inventory** | Items, stats and spells for you and each follower |
| **Actions** | Run most actions by hand, with no AI involved |
| **World & Travel** | The hold map and bounties, arrests, knowledge, travel markers |
| **Outfits** | Dress companions and nearby NPCs; presets, situations, locks |
| **Catalog** | Armor, weapons, food, potions, ingredients and spell tomes from every plugin, in 3D, to give to your party |
| **Survival** | Hunger, cold and fatigue for your party, your camp, and the survival rules |
| **Life Tracker** | Companions' letters, rumours, fines and debts from their lives away |
| **Enterprises** | Retainers, stewards, taxes, camps, NPC labor, debts, commissions |
| **Settings** | Almost every setting, by area, with a search box |

### Companions

- **Recruiting**: ask in conversation (Follower Actions), use the Set Companion hotkey, quick-wheel slot or Actions
  page, or recruit through vanilla or your follower framework's dialogue; SeverActions picks up a new follower by
  itself within a few seconds, with no save and reload.
- **Recruitment Mode** (the Mode button under the Companions roster, or the MCM Followers page). **SeverActions** (the
  default) leads your companions with its own follow and wait. **Tracking** records everyone who joins your party,
  vanilla followers too, but leads nobody; relationships, quest awareness, off-screen life, the outfit lock, homes and
  work still apply. Max Followers defaults to 100.
- **Relationships**: each companion has rapport, trust, loyalty and mood. They change only through a background AI
  assessment (every 4-10 game hours by default) that reads what passed between you, voice and vanilla dialogue
  included. "No change" is the normal result, and the values never drift by themselves; you can also drag them on the
  Bonds tab. Companions form opinions of each other, and remember the quests they were there for.
- **Homes, work and schedules**: set a companion's Home or Relax place where you stand, or give them work through
  Enterprises. Once dismissed they work 8:00-17:00, relax 17:00-22:00 and spend the rest of the day at home; with
  Homed NPCs Sleep at Night on, they sleep in their claimed bed from 22:00 to 6:00 (work and relax times in Settings →
  Followers → Schedule; the sleep switch and its hours in Settings → Followers → Sandboxing).
- **Off-screen life**: dismissed companions you gave a home live their own lives (Auto Off-Screen Events). Their
  letters, rumours, fines and debts show on the Life Tracker page, and they can tell you about it.
- **Companions Sit When You Sit** (Settings → Followers → Behavior, on by default): take a chair, stool, bench or
  throne and the companions following you take the nearest free seats, then stand when you do.
- **Prevent Follower Friendly Fire** (same page, on by default): a companion hit by a stray Shout, spell or arrow from
  you or another companion no longer turns on you. It covers every follower, a mustered war band and retainers guarding
  someone, but not someone merely tagging along. A companion who chooses to attack you leaves your service first.
- **Keeping up**: followers who fall far behind are teleported to you and brought through load doors. Combat style
  (Healer and Coward among them) and Essential are on each companion's Profile tab.
- **Portraits**: press Add portrait on the Companions page and pick any picture with the menu's own file browser;
  Adjust frames it. A copy is kept per install, so that NPC shows it in every save, and your file is untouched.
  Retainers, NPCs you gave a home and your own character (on the Dashboard, per playthrough) can have one too; NPCs
  spawned during play cannot.
- **Bio Blocks**: reusable character traits (a quirk, a backstory beat, a way of speaking) you write once and give to
  any NPC, your companions or a whole faction. The library is shared by all saves; who carries which block is kept per
  save. Import and export it as JSON. Other mods can add read-only blocks; their guide installs to
  `Data/SKSE/Plugins/SeverActions/API/BIO_BLOCKS_API.md`.
- **Survival**: hunger, cold and fatigue for followers, tuned on the Survival page's Rules tab (Debuff Severity scales
  the penalties). Followers eat by themselves when hungry, and each companion's card has Feed, Tracked and Shares food /
  Own food.

### Outfits

- The **Outfits** page dresses companions and nearby NPCs on a live 3D preview; its Live Stage shows the NPC themselves
  (not in VR).
- Up to 8 presets per NPC, shared **Uniforms**, and **Auto-Switch**, which binds presets to situations (adventure, town,
  home, sleep, combat, rain, snow).
- **Outfit Lock** (off by default) stops Skyrim resetting an NPC to their default outfit.
- **Outfit System** (Settings → Followers → Outfit System) turns the whole system off; your presets and locks are kept
  and take hold again at the next load after you turn it back on.
- Presets put on your enchanted, tempered or renamed pieces rather than plain copies, and worn Devious Devices
  restraints are never stripped or saved into a preset.

### Travel, crime, money and captives

- **Travel**: NPCs travel to a named place, a direction, a nearby feature or one of your markers, wait for you there
  (up to 24 game hours) or go about their business, and keep moving while out of sight. **Followers Can Travel**
  (Settings → World → Travel) is off by default, so mentioning a place won't send your party off. The **Travel
  Destination Popup** (on) lets you confirm or redirect a trip. Bind Drop Named Marker to drop up to 128 markers, and
  rename them on World & Travel → Markers.
- **Crime and arrests** (Arrest Actions): only guards arrest in person; jarls and housecarls order an arrest. A guard
  won't arrest you on their own unless you owe a bounty in their hold. Under 300 gold (the default Arrest Threshold, on
  the MCM Crime & Bounty page) you pay or refuse; at or above it you submit, resist, bribe or argue your case. An
  arrested NPC can plead once on the way to jail. **LLM-Driven Trespass** (on) has occupants confront you in dialogue
  instead of the vanilla trespass reaction.
- **Money** (Economy Actions): you confirm payments, trades and debts on a card, or in conversation with Immersive
  Mode. Once a debt you owe is past due, the lender brings it up when you meet; after a day's grace it is marked
  overdue, and at 72 hours overdue the lender reports you to the guards.
- **Crafting** (Crafting Actions): smiths forge on the spot or take a commission (half now, the rest on pickup), and
  anyone can cook a dish or brew a potion.
- **Captives** (Kidnap and Captive Actions): the **Tie / Untie NPC** hotkey binds or frees the NPC you aim at; while
  you lead a captive, aim at furniture to tie them there. Kidnapping and ransom also need **Enable Kidnap Actions**
  (Settings → Followers → Behavior, off by default; holding a quest NPC can break their quests). With Leash Framework
  1.1.1+ (and FSMP) installed, a captive or prisoner being led wears a real rope at the wrists.

### Combat, brawls and outlaws

- NPCs can attack, call off a fight or yield, and a ceasefire holds and breaks as one group.
- Brawls are fists-only and non-lethal: weapons and spells are taken away for the fight and given back after.
- **Peaceful Until Provoked** (Settings → Outlaws → Truce & Camps, off by default) makes bandits hold their fire until
  provoked, so you can talk. Necromancers and Forsworn are included by default; vampires only while you are one.
- With it on, an outlaw may stop you inside a camp and ask your business, and with Enterprises Actions installed a camp
  can be sworn to you, by its chief or, if it has none, by agreement among its members. Its war band can then be
  mustered to follow you.

### Enterprises and the Imperial Levy

- **Retainers**: hire anyone with **+ Assign** on the Enterprises page, or in conversation with Enterprises Actions
  installed: 14 trades and five kinds of terms (a wage, a split, tribute and more). Every 7 game days they produce gold
  and goods (Sworn and Enslaved retainers produce nothing). Unpaid wages can make a retainer desert, and one who leaves
  wronged may send thugs after you (Retainer Grudges). Retainers also ask for raises and loans.
- **Stewards and taxes**: appoint one steward per hold to collect from the others; they keep 15% of what they collect.
  **Hold Taxes** (on) take a share of weekly profit for the hold's court, and a jarl can ease or raise them. Your renown
  limits how many ventures you run.
- **NPC Labor Market** (on): vanilla workers (court, shop and inn staff) are paid weekly by their employers; you take
  no cut.
- **The Imperial Levy**: once your enterprises draw the Treasury's eye, General Cassius Vero and his two Legates take up
  residence at the Blue Palace in Solitude as guests of Jarl Elisif's court, and twelve soldiers patrol five cities
  (four in Solitude, two in each of the others). A save that already has the detail at Dragonsreach moves it once.
  Their story is on hold for now; turn them off with **Imperial Levy** (Settings → Enterprises → Retainers, on by
  default).
- The Enterprises page copes with long lists: search boxes, filters, and sections that fold away.

### Sever's Hearth (camps)

- **Set Up Camp** (the Survival page or a hotkey) shows a ghost of the camp to place; ask a companion instead and they
  pitch it where you stand. Full camps need the outdoors.
- Your first camp becomes the company's **base**: it stands whether or not anyone is there, followers can be sent to it
  and will stay, and it holds the stash chest. Later camps are bivouacs for the road, which stand until you break them.
- Upgrade the base twice (it sleeps 2, then 4, then 6, and extra followers get bedrolls up to 12 beds) with firewood,
  leather and iron ingots from the stash or your pack. It is laid out like the vanilla Legion and Stormcloak field
  camps, with the Imperial tent if you joined the Legion.
- **Small Camp** is for you and one or two companions. You can pitch it indoors (with no tent), and it never becomes
  the base.
- No Campfire needed. With Light Placer installed, nothing in the camp is lit twice.

### Life around you

- **Follower Banter** (on): companions talk to each other while travelling.
- **Ambient NPC Banter** (on): nearby NPCs talk to each other now and then.
- **Ambient NPC Actions** (off, experimental): nearby NPCs trade, hand things over, use what they carry or challenge
  each other to a brawl.
- **Intimacy & Consent Section** (Settings → AI, on): a short section in NPC bios on how open they are to advances,
  read by the AI from your time together. Shown for women only by default, never for children; turn it off, or choose
  Everyone or Men only.

### Hotkeys and the quick wheel

- **Hotkeys**: Toggle Follow, Wait Here / Resume, Dismiss Companion, Set Companion, Assign Home Here, Clear Home
  (Target), Set Up Camp, Small Camp, Drop Named Marker, Tie / Untie NPC, Make NPC Stand Up, Use Furniture, Make NPC
  Yield, Undress NPC, Dress NPC. All start unbound: bind them in Settings → Interface → Hotkeys or the MCM (Small Camp
  only in the menu). Keyboard, mouse and gamepad buttons all work.
- They act on your crosshair target; **Target Mode** (MCM Hotkeys page) can switch to Nearest NPC or Last Talked To.
  They don't fire while a menu or dialogue is open, or while you are sitting.
- **The quick wheel** is SeverActions' own. Bind **Open Quick Wheel** first (it is unbound on flat Skyrim), then choose
  its 8 slots in Settings → Interface → Hotkeys. The default layout is Toggle Follow, Dismiss, Stand Up, Yield, Undress,
  Dress, Wait and Set Companion, and the layout is kept per save.

### Skyrim VR

- The menu, popups and quick wheel draw in the headset (SteamVR or OpenComposite). Point with the controller laser and
  pull the trigger to click.
- Menu: hold **Grip** and press **B/Y**. Quick wheel: hold **Grip** and press **A/X**. Either hand works; change them in
  Settings → Interface → Hotkeys or on the MCM Hotkeys page.
- **Immersive Mode** (Settings → Interface → UI Display) is Auto by default, which means on in VR: travel, payments,
  trades and commissions are settled in conversation instead of popup cards.
- The Outfits page has no Live Stage or Free Look in VR.

### Languages

The menu follows the game's language. French, Russian and Japanese have the menu, the MCM and the notices translated;
other languages show English. Page help and many setting descriptions are in English everywhere.

---

## Requirements

| | |
|---|---|
| **Required** | Skyrim SE 1.5.97, AE 1.6.x or 1.7.x, or Skyrim VR 1.4.15 · SKSE64 (2.3.0 or newer on 1.7.x), or SKSEVR on VR · Address Library for SKSE Plugins (the VR Address Library on VR) · [SkyrimNet](https://www.nexusmods.com/skyrimspecialedition/mods/148913) 0.25 (beta 25) or newer · PapyrusUtil · the latest Microsoft Visual C++ Redistributable 2015-2022 (x64), which the menu needs |
| **Included** | Magelight UI 0.30.5, which draws the menu, popups and quick wheel and always installs with the core · Sever's Hearth, the camp system, on its own installer page |
| **Recommended** | SkyUI, only for the MCM |
| **Optional** | See [Compatibility](#compatibility) |
| **No longer needed** | PrismaUI and UIExtensions. Papyrus MessageBox is optional now, only a fallback for when one of SeverActions' own popups can't open |

SeverActions also does not need powerofthree's Papyrus Extender, JContainers, ConsoleUtil, Papyrus Tweaks NG or
powerofthree's Tweaks.

PrismaUI can stay installed for other mods, such as SkyrimNet's chat; SeverActions won't open its menu or popups while
that chat has focus. If you also install Magelight UI as its own mod, let the newer copy win: it should be 0.30.5 or
newer.

**Load order**: place SeverActions after SkyrimNet; otherwise the order doesn't matter. `SeverActions.esp` uses a full
plugin slot; `SeversHearth.esp` and the AI Overhaul patch are ESL-flagged.

---

## Compatibility

| Mod | How SeverActions works with it |
|---|---|
| **Nether's Follower Framework** | With NFF installed, Recruitment Mode switches to Tracking once, with a notice; switch it back if you like and it stays. For anyone NFF holds, recruit, dismiss, wait and resume go through NFF's own controller, and SeverActions doesn't take over how NFF leads them (unless you turn on Include Followers Led by Other Frameworks, so they sit down with you) |
| **Serana and custom-AI followers** | Inigo, Lucien, Sofia and others on a shipped list are tracked but keep their own AI, in either mode. Take Full Control on their Companions page hands them to SeverActions; Restore Their Own AI undoes it |
| **Walk With Me** | While it leads a companion, SeverActions stops pulling them back. A SeverActions wait, trip or home order still comes first |
| **Leash Framework 1.1.1+** (with FSMP) | Captives and prisoners being led wear a real rope at the wrists; Leash Attachment (Settings → Followers) can tie it at the neck instead. 1.1.0 still works, with a neck collar |
| **NPC Names Distributor** | Actions that name an NPC also find them by their NND name |
| **Immersive Equipping Animations** | Outfit changes play its equip and unequip animations (Use Animations, on by default) |
| **Eating Animations and Sounds** | An NPC eating can play its animation for that food; no patch needed |
| **Dynamic Book Framework** | An NPC reading a book aloud uses DBF's text for it |
| **SexLab / OStim** | Actions, outfit changes and prompts stay away from NPCs mid-scene, on Skyrim VR too |
| **Devious Devices** | Worn restraints are never stripped or saved into presets |
| **Diary of Mine / Paradise Halls** | NPCs those mods hold are left for them to dress |
| **SkyrimNet Relationships** | SeverActions' Intimacy & Consent Section stands down by default |
| **SPID** | Optional: SeverActions reads its custom-AI follower list itself |
| **Light Placer** | The camp leaves out any light Light Placer already adds |
| **OSL Aroused / SL Aroused, Fertility Mode** | The Adult Content installer page: an arousal action and an arousal prompt (one of each, or none), and Fertility Mode content (a status prompt and an abort-pregnancy trigger) |
| **AI Overhaul** | The AI Overhaul Flee Patch (Compatibility Patches page): your followers, and NPCs in a forced fight, don't flee |
| **Daegon Kaekiri** | The Daegon Kaekiri Outfit Patch lets SeverActions manage her outfit; install it after Daegon |
| **Other SkyrimNet action packs** | SkyrimNet keeps one list of action names, so two actions with the same name replace each other. SeverActions keeps its names clear of SkyrimNet's own, which is why its companion wait and follow are now WaitForPlayerHere and ResumeFollowing |

---

## Installing and upgrading

### New install

Install the archive with a mod manager and pick your options in the installer. The core and Magelight UI always
install; your choices decide which actions and context prompts the AI gets, plus the compatibility patches, the adult
content and Sever's Hearth. Except for Sever's Hearth, every script installs either way, so leaving an option out
breaks nothing.

- **Ticked by default**: Basic, Travel, Combat, Brawl, Outfit, Furniture and Follower Actions; the Core Awareness,
  NPC Familiarity & Reputation, Combat, Brawl, Follower Companion and Group Meeting prompts; Sever's Hearth.
- **Not ticked by default**: Economy, Enterprises, Crafting, Arrest, and Kidnap and Captive Actions; the Survival and
  Arrest/Crime prompts; a Merchant prompt (pick one or none); the patches and the adult content. Tick these if you
  want NPCs to pay and lend gold, hire on as retainers, craft, make arrests or take captives.

Prompt options are separate from action options. An area's actions and its prompts are usually worth installing
together (Arrest Actions with the Arrest/Crime prompts, for example), but nothing breaks if you don't.

No mod manager? Follow `MANUAL_INSTALL.txt` at the root of the archive, which lists the folders to copy.

### Upgrading from 3.9.x

- **Replace** the old SeverActions mod (in MO2, choose Replace); don't merge into it. The archive's layout changed, and
  a clean replace clears out the old files. Without a mod manager, `MANUAL_INSTALL.txt` also lists the old files to
  delete by hand.
- The installer pages and choices are the same as in 3.9.14, and every choice installs at least what it did before.
- Saves carry over. On the first load, NPCs mid-journey or waiting somewhere carry on, and in Tracking mode
  SeverActions stops leading followers it was leading. If the Imperial Levy's General and Legates are at Dragonsreach,
  they move to Solitude once you are in neither Dragonsreach nor the Blue Palace and none of them is in sight, and
  their squads trade cities once you are well away from both cities. The folder of preview pictures the old outfit
  preview saved (`Data/PrismaUI/views/SeverActions/mannequin`, which under MO2 sits in the overwrite folder) is deleted,
  since nothing reads it any more.

### Removed and renamed actions

These changes are on purpose:

- **StopUsingFurniture** is gone: NPCs SeverActions sat down stand up by themselves when you walk away (Furniture
  Auto-Stand Distance, Settings → Followers → Behavior). The Make NPC Stand Up hotkey and quick-wheel slot stay.
- **AdjustRelationship** is gone: it shipped disabled, and the background relationship assessment replaced it.
- **SetCombatStyle** and **SetFollowDistance** are gone: combat style is set on the Companions page and in the MCM,
  follow distance with Follow Distance on the Actions page.
- **LeashCaptive** and **UnleashCaptive** are gone: RestrainNPC and TieCaptiveToFurniture took their place, and
  ReleaseCaptive frees a captive.
- **CompanionWait** and **CompanionFollow** are now **WaitForPlayerHere** and **ResumeFollowing**. If you changed
  either one's settings in SkyrimNet (switched it off, gave it a cooldown), set them again on the new name. Every other
  action keeps its name and your settings for it.
- If you ever edited a SeverActions action in SkyrimNet's action editor, SkyrimNet saved a full copy that stands in for
  the new one, with its old text, its old parameter names and its old place outside the categories. Delete that copy
  and redo your edit on the new version.

---

## Settings

The menu and the MCM share one set of settings. The menu's **Settings** page has almost everything, by area, with a
search box. The **MCM** (with SkyUI) has 15 pages: Interface, Hotkeys, Prompt Filters, Followers, Off-Screen Life,
Outfits, Survival, Combat & Outlaws, Crime & Bounty, Economy, Enterprises, Travel, Reading & Spells, Homes and Bio
Blocks. Some settings are only in the menu (the quick-wheel slots, Immersive Mode, Prevent Follower Friendly Fire and
Companions Sit When You Sit, for example). A few are only in the MCM: hotkey Target Mode, the Arrest Threshold and
Bribe Multiplier, Show Notifications and the Forced-Combat Cooldown, for example.

Most settings are kept outside the save, in `SeverActions_Settings.json` (`Documents\My Games\<your Skyrim>\SKSE`,
beside the logs), so a new character or a reinstall keeps them. Action hotkeys and quick-wheel slots are kept with each
save; the menu and quick-wheel keys are shared by all saves.

### Background AI

SeverActions makes some AI calls of its own: relationship assessments (with you and between companions), follower and
ambient banter, ambient actions, NPC reputation blurbs, the intimacy read, quest summaries, off-screen life, weekly
retainer stories and courier letters.

- **Background AI Calls (Master)** (Settings → AI, or the MCM Interface page) stops all of them at once. Everything
  SeverActions keeps track of keeps updating, letters fall back to templates, and talking to NPCs through SkyrimNet is
  not affected.
- Or limit them one by one in Settings → AI (off-screen life has its own switch and cooldowns in Settings → Off-Screen
  Life; courier letters only follow the master switch). **Weekly Retainer Stories** is Auto (about 40% of your roster)
  and can be set to 1-12 or Off.
- Default spacing, in game hours: each follower's relationship read 4-10, companions' opinions of each other 6-14,
  follower banter 2-5, ambient banter 3-7.
- To save tokens, send these calls to a cheaper or local model with the **LLM Overrides** in SeverActions' plugin
  settings in SkyrimNet (left empty, they use your normal model).

---

## Support and troubleshooting

Questions and community support: the [SkyrimNet Discord](https://discord.gg/skyrimnet). Bug reports:
[open an issue](https://github.com/Severause/SeverActions/issues) with your logs (below).

**NPCs don't use SeverActions' actions.**
- Check you are on SkyrimNet 0.25 or newer, installed 4.0 as a clean replace, and ticked the installer options for
  what you expect (Economy, Enterprises, Crafting, Arrest and Kidnap actions are not ticked by default).
- Delete any copy of a SeverActions action you saved in SkyrimNet's action editor (see
  [Removed and renamed actions](#removed-and-renamed-actions)).
- In SkyrimNet's action settings each SeverActions category (Journeys, Companionship, Economy and so on) has its own
  entry, and switching one off hides every action in it. To stop a single action, switch off just that action.
- Some actions are only offered to those who can use them: camp actions to your followers, arrests to guards.
- NPCs act on what they agree to in the line they just spoke; plans for later stay words.
- A setting greyed out with "prompt not installed" means that prompt was skipped in the installer.

**I asked my follower to go somewhere and nothing happened.** Followers Can Travel (Settings → World → Travel) is off
by default, and while it is off followers don't take the travel action. Turn it on, or send them with Travel To on the
Actions page.

**A message box says SeverActionsNative.dll is missing or doesn't match.** The plugin and the scripts come from
different builds (often an old 3.9.x file still winning a conflict), or the plugin did not load at all. Reinstall
SeverActions as a clean replace; if the box comes back, check that SKSE and Address Library match your game version.

**The menu won't open, or says the interface is not installed.**
- Read `Magelight.log`. "GetLastError=126" means Windows could not load the menu's runtime: check that the runtime
  files in `Data\SKSE\Plugins\Magelight\` are there, then install or repair the latest Microsoft Visual C++
  Redistributable 2015-2022 (x64).
- "SeverActions interface is not installed" means the menu files are missing: reinstall. If you also have Magelight UI
  as its own mod, let the newer copy win.
- On flat Skyrim the quick wheel does nothing until you bind its key.

**A follower is stuck or acting strange.** On their Companions page, the ⋮ menu has Clear Packages, Soft Reset (clears
packages and follow state but keeps their relationship, home and combat style; recruit them again after) and Force
Remove (erases everything SeverActions stored for them). Summon brings them to you.

**SkyrimNet.log is full of "SexLabAnimatingFaction not found" warnings.** 4.0's actions and prompts no longer cause
them. If they continue, another installed pack still looks that faction up by name.

**Which logs to send.** From `Documents\My Games\Skyrim Special Edition\SKSE` (`Skyrim VR\SKSE` on VR,
`Skyrim Special Edition GOG\SKSE` on GOG; under `OneDrive\Documents` if your Documents folder is in OneDrive):
`SeverActionsNative.log`, `Magelight.log`, `SkyrimNet.log`, and `SeversHearthNative.log` for camp problems. SeverActions',
Hearth's and Magelight's logs are overwritten every launch, so copy them before you start the game again. Add
`Papyrus.0.log` (`My Games\Skyrim Special Edition\Logs\Script`, `Skyrim VR\Logs\Script` on VR) if Papyrus logging is
on, and say which SeverActions and SkyrimNet versions you run and any related mods (NFF, AI Overhaul, outfit mods).

---

## Under the hood

Four layers, each doing what it is best at:

1. **Action YAMLs** declare what the AI may do and when it is eligible.
2. **Prompt templates** put live state into the AI's context.
3. **Papyrus** owns quest aliases, packages and anything the engine only exposes to scripts.
4. **Native SKSE plugins** (~148k lines of C++: the main one, and a smaller one for Sever's Hearth) own the data, the
   heavy scans, and everything performance- or thread-sensitive.

State lives in the **SKSE co-save** (about 50 records, each versioned) rather than in Papyrus properties, so updates
carry existing saves forward instead of starting over.

The public repository carries the packaged mod (the installer tree), the changelog and this README. The native plugins'
source and the build and release tooling live in the private development repository.

<details>
<summary>For contributors with access to the development repository</summary>

```powershell
# Build the native plugin (-Tests also builds and runs its self-tests)
.\Native\build.ps1

# Rebuild the web frontend (00 Core/Magelight/SeverActions/views, installed to Data/Magelight/SeverActions/views)
.\build-ui.ps1

# Build the installer zip - the only supported way to package it (a -dev suffix for test zips).
# It stages both native plugins and Magelight UI from their build folders, so build those first.
.\build_fomod_zip.ps1 -Version "X.Y.Z-dev"

# Lint before any release: 25 checks, each guarding a failure class that once shipped
.\check_release.ps1
```

`check_release.ps1` is the gate worth knowing about. It verifies the contract between the action YAMLs and the scripts,
prompt availability, installer coverage and the generated installer, version coherence across every surface, prompt
brace balance, known engine traps, native signature sync and the 511-natives-per-script cap, revert-hook coverage,
event-name collisions, plugin record ownership, the installer against the last public release, the settings table and
the menu's surfaces. Every check exists because that failure shipped once; the script's header block is the full list.

See `CLAUDE.md` for conventions, `RELEASING.md` for the release procedure and `ai_docs/` for design documents.

</details>

---

## Credits

- **Author** — Severause
- **[SkyrimNet](https://www.nexusmods.com/skyrimspecialedition/mods/148913)** by MinLL, which this builds on
- **Magelight UI**, bundled, draws the in-game menu. It uses the Ultralight runtime; the licences and notices install to
  `Data/SKSE/Plugins/Magelight/license`
- Map artwork by Caro Tuts ([Nexus #62705](https://www.nexusmods.com/skyrimspecialedition/mods/62705))
- Hold sigils derived from CoMAP map markers by **Parapets** ([Nexus #56123](https://www.nexusmods.com/skyrimspecialedition/mods/56123)) and the Cities of the North marker pack, re-tinted to a parchment palette for the World page
- Imperial Fiscal Levy armour **meshes and textures** by **NordwarUA** ([New Legion, Nexus #30468](https://www.nexusmods.com/skyrimspecialedition/mods/30468) — Base and Textures HD archives), recoloured to a Treasury livery for the Final Audit detail
- The General's writ-blade mesh and textures by **InsanitySorrow** ([Insanity's Ebony Sword Replacer, Nexus #37645](https://www.nexusmods.com/skyrimspecialedition/mods/37645)), recoloured to match the Treasury livery
- The Legates' blades by **billyro** ([Mage Glass Sword, Nexus #38798](https://www.nexusmods.com/skyrimspecialedition/mods/38798)), re-tinted storm-blue for Livia and ember for Drusilla
- Thanks to **DizzyDedman** (followers hearing about gear moved from the menu, and Order Arrest) and **Forsworn** (the
  Count field on the Actions page), and to everyone who reported bugs

---

<p align="center">
  <em>Built for SkyrimNet — where NPCs don't just talk, they act.</em>
</p>
