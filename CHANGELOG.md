# SeverActions Changelog

## v3.0.7 — Mannequin fidelity, transparent-viewport fallback, outfit-menu crash fix & camp reliability

Another pass on the Outfits-mannequin preview — much closer skin, makeup, and warpaint rendering — a new transparent-viewport fallback for stubborn load orders, a fix for an outfit-menu crash on common NPCs, and a reliability fix for Sever's Hearth's "go to camp." Save-compatible; no migration.

### Outfits / Wardrobe renderer

More fidelity work on the mannequin preview. As before, these affect only the offscreen Outfits-window preview — never your follower's actual in-game appearance.

- **Per-pixel skin shading.** The preview now reads each skin's subsurface (`_sk`) and specular (`_s`) maps, so CBBE / 3BA skins render with proper soft subsurface tint and per-pixel highlights instead of a flat, uniform sheen.
- **Scars, freckles & body overlays show.** RaceMenu / SKEE overlay layers — scars, freckles, birthmarks, and overlay-based makeup — now render via a transparent decal pass instead of being dropped from the preview.
- **Makeup renders in its real color.** RaceMenu / SKEE makeup overlays with a chosen tint now show that color (eyeshadow, lip and blush tints) rather than the base texture color, by reading SKEE's per-overlay tint.
- **Warpaint & complexion show on baked-FaceGen followers.** Baked warpaint, makeup, and complexion (the FaceGen "FaceTint" layer) now composite onto the head, so follower replacers with bundled face paint look right in the preview. Resolved from the live head, and — when a wet-skin / SSS shader has taken over the head's tint slot — directly from the NPC's FaceTint file.
- **Fixed an outfit-menu crash on guards, bandits & generic NPCs.** Opening the outfit menu on a leveled / templated NPC (most guards, bandits, and generic townsfolk) could CTD on a bad form lookup. Those NPCs now open cleanly.
- **Transparent-viewport fallback for the mannequin.** A new **Settings → Interface → "Disable Mannequin Preview"** toggle for load orders where the preview won't render correctly. Instead of a blank box, it turns the doll window into a transparent cutout onto the **live game**, so you can still see — and dress — the NPC in the world; it also skips the preview bake entirely (a performance win on those load orders). A **Free Look** button hands camera control to the game so you can frame the NPC with your own camera (fully compatible with SmoothCam / True Directional Movement) — press your menu key to return. Dressing, presets, and all other controls keep working, and the setting persists across saves.

### Camp

- **"Go to camp" works reliably now.** Sending a companion (or any NPC) to a Sever's Hearth camp had stopped working on existing saves — they wouldn't move, could crash the game on the latest runtime, or got pulled back a few seconds after setting off. They now walk over and settle in by the campfire properly, and apply their camp behavior on arrival instead of standing frozen. Includes a crash fix on Skyrim **1.6.1170** and self-healing on saves where the system didn't initialize on load.

### Followers

- **"Follow" reliably pulls companions out of camp or waiting.** The wheel **Follow** action is now a clean context toggle — companions swap between resume-follow and wait, casual NPCs between start and stop following — replacing the old dead-end where a following companion couldn't be toggled. More importantly, resuming follow now actually **breaks a companion out of a camp or waiting sandbox**: it cancels the camp hold, releases them from the Sever's Hearth campfire, and re-applies their follow package, instead of leaving them parked by the fire. This also fixes a long-standing issue where **recruiting or calling a follower** didn't release them from a camp (the underlying "called by player" signal was malformed and never reached the camp system).

## v3.0.5 — Outfits, followers, arrest, survival & Life Tracker fixes

Everything since v3.0.1: a quality-of-life pass on the Companions / Life Tracker pages, a large batch of Outfits-mannequin renderer fixes, stronger follower catch-up (now with a track-only toggle), an arrest-eligibility fix, a survival master-switch fix, and several stability fixes. Save-compatible with v3.0+; the off-screen-life cosave gains two backward-compatible fields, so older saves load cleanly.

### Outfits / Wardrobe renderer

Robustness work on the mannequin preview — these only ever affected the offscreen Outfits-window baker, never your follower's actual in-game appearance. The harder-to-reproduce crashes below are best-effort fixes; the preview leans on a lot of third-party mesh and shader data, so more edge cases may still surface — please keep reporting them.

- **Addressed several mannequin crashes & freezes.** Opening the preview for certain NPCs (heavy NPC-overhaul modlists) could CTD on a face/eyes/hair buffer over-read; changing a follower's outfit could crash mid-swap (a use-after-free); and rapid edits could freeze the page with a storm of un-debounced 24-angle bakes. These paths are now guarded, serialized, and debounced — crashes should be far rarer, though the mesh-dependent ones may not be fully eliminated.
- **Reduced rendering artifacts.** BodySlide outfits bundling a reference/virtual body (a `VirtualCBBE`-style shape with no diffuse) could paint the whole body purple, and complex followers (glowing eyes, Spriggan/aura FX) could show as yellow/green glow blobs. Both should be largely resolved — phantom reference bodies are skipped and emissive is attenuated — but unusual mesh/shader setups may still need tuning.
- **Ghost presets cleaned up.** Legacy presets that showed blank yet still occupied slots (so saving a new one jumped to preset #5) are repaired — slots free and new presets fill them.
- **Blacklist respected on equip.** Equipping an outfit via the Sever UI no longer strips items from a blacklisted plugin you'd equipped outside SeverActions.
- **Faster reopen.** Reopening an unchanged outfit reuses the cached preview instead of re-baking all 24 angles, so the panel appears instantly.

### Followers

- **More reliable follower catch-up.** Followers now get pulled through city gates, load doors, *and* fast travel even when you stop and give no input — noticeably better at keeping up, though still being tuned. A new **"Catch Up Track-Only Followers"** setting (Settings → Follower Behavior, default On) extends it to NFF / custom-AI / DLC followers like Serana; turn it off to leave those to their own framework. *(Setting is runtime-only for now — resets to On each launch.)*
- **Surrendered-then-recruited followers stop getting stranded.** A follower you'd beaten into yielding and then recruited would refuse to follow through doors or fast travel — a lingering "surrendered" status kept the catch-up from moving them. They now keep up like any other companion, while followers genuinely told to wait stay put.
- **Essential toggle now works on any follower.** It set an ActorBase flag the engine ignores for templated/leveled NPCs; it now makes the actor essential at the reference level, so it works on every follower and applies live.
- **Work / Relax locations show outdoors.** Setting a follower's Work or Relax spot outdoors didn't show on the Companions page even though Set Home did; both now display correctly indoors or out.

### Arrest

- **Guards reliably offer arrest actions.** Fixed an eligibility bug that could stop guards from surfacing any arrest-related actions in conversation — arrests (NPC or player), adding bounty, jailing and releasing, and dispatching guards to investigate homes for evidence. The full arrest toolkit is now offered correctly across vanilla and mod-added guard factions.

### Survival

- **The master switch actually turns survival off now.** Toggling Survival off on the page (or in the MCM) didn't fully disable it — the survival prompt kept describing hunger/fatigue/cold in conversation, and followers kept their stat penalties. Off now means off: the prompt stops and penalties clear. Each follower's needs are **preserved** rather than wiped, so turning Survival back on resumes exactly where it left off.

### Life Tracker — character management

- **Remove a character.** A new remove (✕) button clears a character's letters and stats, hides them from the page, and stops generating new off-screen events for them — handy for cleaning up duplicated or deleted NPCs that lingered in the tracker.
- **Restore a removed character.** A new **Hidden** list lets you bring a removed character back with one click; they reappear and resume their off-screen life.
- **"Show Removed Characters" setting.** A toggle under **Settings → Off-Screen Life** hides the Hidden list entirely for a cleaner page, and brings it back when you want to restore someone.

### Stability

- **Fixed a world-map CTD** caused by dirty edits in the bundled Sever's Hearth ESP overriding the vanilla map-marker base static — a conflict that corrupted marker rendering on heavy map-mod load orders. The dirty edits are removed; the camp-on-map feature is unaffected.

## v3.0.1 — Skyrim VR support

Hotfix on top of v3.0. SeverActions and the bundled Sever's Hearth now build and run on **Skyrim VR** — the native DLLs are universal SE/AE/VR. Two small quality-of-life fixes round it out. Save-compatible with v3.0; no migration, no new requirements on SE/AE.

### Skyrim VR support

The native plugins are now compiled as universal SE/AE/VR binaries against CommonLibVR, fixing every crash and hang VR users hit on v3.0. No change for SE/AE players.

- **Now boots on VR.** v3.0's DLLs were SE/AE-only, so VR CTD'd at launch with *"failed to open address library file."* Both `SeverActionsNative` and `SeversHearthNative` are multi-targeted now and load on VR.
- **No more infinite load with SkyrimNet.** Our SkyrimNet decorators were registering before SkyrimNet finished standing up its own systems, which deadlocked its startup on VR — the main menu never appeared. Registration now happens at the correct point in load (kDataLoaded), so all decorators come up cleanly.
- **No main-menu crash.** A VR-incompatible fast-travel event sink (the event doesn't exist on VR) is now guarded, so the situation/cell monitors no longer crash at the main menu.
- **Outfit slots work on VR.** VR has no runtime-EditorID retention (no po3 Tweaks build), so the outfit system couldn't find its records by name and silently failed (*"Outfits/LvlItems FormLists missing"*). It now resolves its own records by FormID — all 800 outfit slots index correctly on VR.
- **Survival warmth** degrades gracefully on VR, falling back to armor-record warmth where the SE/AE engine API isn't available.

### Fixes

- **Fertility — insemination narration removed.** The `*<father> releases inside <target>.*` narrator line that fired on Fertility Mode insemination is gone. (Conception narration is unchanged.)
- **Dashboard date corrected.** The PrismaUI dashboard showed the wrong in-game date on a new game — *"Sundas, 1st of Morning Star"* with no year, instead of the canonical *"Fredas, 17th of Last Seed, 4E 201."* It now uses the save-anchored Skyrim calendar, so the date and year read correctly from day one and advance properly.

## v3.0 — Hearth Ledger, native cosave, arrest overhaul, brawl

The largest release in the mod's history. Six PrismaUI pages got the new "Hearth Ledger" visual identity, the outfit subsystem was rebuilt on a native cosave store, a full arrest pipeline shipped, a fist-fight brawl system arrived, and the travel / sandbox / follower-maintenance systems were rewritten for reliability. Save-compatible upgrade — pre-existing data migrates automatically on first load.

### PrismaUI — Hearth Ledger visual overhaul

Every page was rebuilt around a shared "parchment + brass + dark surface" design language, with rail / center / drawer layouts replacing the prior flat lists. The dashboard is the new front door.

- **Dashboard.** Frontispiece title strip, ex-libris bookplate with your character + Skyrim date, six **Portal Tiles** (Companions / Coffers / Holdings / Provisions / Tidings / Chronicle — each in its destination page's accent color so the dashboard reads as a true table of contents), illuminated Recent Entries with sigil portraits and drop-cap actor names, Steward's Dispatch slip quoting the latest gossip, and a marginalia portent list. Consecutive entries from the same actor collapse with a small ↳ continuation marker.
- **Outfits / Wardrobe.** Three-column layout (roster + active follower + builder). Mannequin renderer rebuilt: heads, hair, alpha-tested items, custom shader subclasses, helper meshes, and skin all render correctly. Cart-preview revert moved to native code so closing the menu without committing always reverts cleanly — no more "I closed the menu and my follower is still wearing the staged outfit."
- **Inventory.** Three-column rail / center / drawer layout, native drag-to-give between actors, per-category limits, item-stack count fixes.
- **Stats + Spells.** Stats tab redone as a character sheet (Skyrim-style attribute panel + perk count + skill bars). Spells tab redone as a grimoire (school filter chips, click for full effect breakdown, real magnitude/duration/area substitution).
- **Settings.** Full rail-nav rewrite with section search. World, Inventory, Outfits, Schedule, Currency, Debt, and Off-Screen settings all reachable from one rail — one place to tune everything.
- **World.** Parchment Skyrim atlas (Caro Tuts paper map) with hold sigil markers. Click a hold for a drawer with per-hold bounty, properties, travel, and debts. Map / Ledger toggle keeps the prior sectioned layout for power users.
- **Survival.** Redesigned around a Camp shell. Party Vitals on one side, Camp Plan journal on the other, with at-a-glance Rations / Warmth / Risk hero banner.
- **Active Arrests (new).** Visible feedback for the new arrest watchdog — see every active arrest, who's escorting whom, and how close each one is to timing out, color-coded by urgency.
- **Companions refinements.** Sub-tab structure (Profile / Bonds / Bio / Memories / Journal / Quest Awareness). **Bonds is editable** — drag rapport / trust / loyalty / mood values directly. **Bio** tab mirrors SkyrimNet's on-disk character bios. **Memories** tab shows the most recent 20 memories with proper Skyrim-calendar dates.
- **Actions Composer.** Rebuilt as `[Actor] → [Verb] → (target?) → (modifier…)` composer with spotlight typeahead, six pinned chips, and recents replay. **37 verbs across 8 categories** including the new Brawl and Travel categories. Required-param indicator + smarter confirm messages (`Execute Extort Gold as Lydia? Victim: Brand-Shei · Amount: 50` rather than just "Execute Extort Gold on Lydia?").
- **Per-page help tooltips.** A "?" button next to the close button opens a modal with help content for the current page. Audited for all 11 pages.
- **Page Help, Refresh, Scroll, and Confirm dialogs** now use in-app modals throughout (the previous browser-native `confirm()` returned `undefined` inside Ultralight and silently dropped actions).
- **Dashboard quest banner.** The dashboard front page now surfaces your active quests, each with its next incomplete objective.

### Brawl system (new)

Fist-fight system for player ↔ NPC and NPC ↔ NPC, fully integrated with the LLM and PrismaUI.

- **Challenge / Accept / Decline / Forfeit** action verbs and PrismaUI buttons. NPCs can challenge each other to brawl, and the loser yields cleanly.
- **Brawl prompt overlay.** When you receive a challenge, a PrismaUI prompt surfaces the accept/decline choice without pausing the game in a normal menu.
- **Native BrawlManager** handles the CS/DG cache, engagement watchdog, spectator pacification, and a friendly-fire exception so your other followers don't intervene.
- **Spells stripped and restored.** Magic-user followers don't fireball their brawl opponent; their spell list is temporarily removed and restored on brawl end.
- **Custom CombatStyle** (`BrawlerCS`) tuned for unarmed combat with no spells, no weapons, and no flee.
- **Tracking-only followers rejoin cleanly after a brawl.** An NFF / SPID custom-AI / Serana-style follower has their teammate flag briefly cleared during a brawl (so your other followers don't pile in); they're now reliably re-onboarded into tracking mode when it ends, instead of being stranded on idle AI.

### Arrest pipeline overhaul

A complete rewrite of how NPC arrests work, with a watchdog to catch stuck arrests and a player-facing FSM for confrontation + persuasion.

- **ArrestSessionStore.** Native watchdog tracking every active arrest with per-state in-game-hour timeouts. If a guard gets stuck escorting a prisoner across the map, the watchdog fires a timeout and forces a clean cancel instead of leaving the actor frozen forever.
- **Mid-escort plea.** Prisoners can appeal to their escorting guard mid-march (60-second window, single attempt). Guard halts, weapon stays drawn, and accepts or rejects via dialogue or LLM action. Accept = release + cleanup; reject = resume escort.
- **Scene-aware home suspend.** Vanilla quest scenes can pull your homed follower into scripted behavior (e.g. Serana searching her mother's lab during Soul Cairn). The home sandbox now detects active scenes and temporarily suspends itself so the quest scene plays correctly, then re-applies when the scene ends.
- **Player-confrontation FSM** (Persuasion). When a guard tries to arrest you, you can plead, bribe, intimidate, or resist via PrismaUI. Each branch has its own logic and timer.
- **Active Arrests panel** in PrismaUI (above) gives you live visibility into every in-flight arrest.
- **SkyrimNet busy state** integrated — actors involved in an arrest report `is_busy = "arrest"` so other plugins and our own action YAMLs gate eligibility correctly.
- **Sender-name canonicalization** — fixed cases where the LLM's authority picker sent `"Player"` literally and fuzzy-matched into NPCs whose names contained "Player".
- **OrphanCleanup** rewritten so stale faction memberships from a crashed prior arrest never block re-arrest forever.
- **PrismaUI Arrest prompt overlay** for when you're confronted by a guard, mirroring the brawl prompt pattern.

### Outfit system — rebuilt on native cosave

The whole outfit subsystem (locks, presets, situation mappings, dress/undress) moved off Papyrus StorageUtil and onto a versioned native C++ cosave store. Pre-existing saves migrate automatically on first load.

- **No more split-brain outfits.** Cases where PrismaUI showed one outfit but the NPC wore another, or where SkyrimNet thought the NPC was wearing preset X but the actor's armor said otherwise, are gone. One source of truth.
- **Dress / Undress survives a reload.** Undressing, saving, reloading, and re-dressing now correctly restores what they were wearing — including outfits applied via preset.
- **100 outfit slots** (was 20). NFF-style per-item ownership tracking + outfit alias hardening for large follower rosters.
- **Edit Preset (new).** Click `Edit` on any saved preset row — the staging card opens pre-filled with that preset's items and name. Add, remove, optionally rename, then save in place. Renames preserve the slot, container, leveled-item list, satchel, and catalog so SkyrimNet actions and the mannequin keep working.
- **Delete Preset works.** The `✕` button on preset rows previously appeared to do nothing inside Ultralight (browser `confirm()` returns undefined there). Now routes through the in-app confirm dialog and actually fires the delete.
- **Reset Outfit Data actually resets.** PrismaUI's red "Reset Outfit Data" button now wipes every situation mapping, the dress stash, and the follower-lock flag in one shot.
- **Mannequin viewport no longer stutters.** Rapid preset swaps were queuing 7+ piled-up rebakes that froze the cursor; now throttled to one bake per frame.
- **Daegon Kaekiri compat patch** updated to gate on `Native_Outfit_IsActivelyManaged` instead of a bare faction check, so flagging her as outfit-excluded properly hands ownership back to her mod's outfit dialogue.
- **Situation outfits.** Bind a preset to one of seven situations (city / outdoor / sleeping / combat / house / rainy / snowy). Auto-switches based on the active situation.
- **Outfit P0–P3 fixes from the tester report.** Saving a preset no longer auto-strips and re-equips; applying a preset preserves your existing lock state; "shadow" outfits in the cosave but absent from PrismaUI now surface as orphan rows with a Remove button; slot-mask sweep catches stray armor pieces (e.g. boots left over from a previous preset that didn't have them).
- **Managed NPCs tab.** Non-follower NPCs you've dressed get their own Managed tab on the Outfits page, with **Forget** / **Forget All** to prune an NPC's lock + presets from the cosave and restore their original look — replacing the old clipped "Other NPCs" strip.
- **Save preset from worn.** The left "Save Preset" button now snapshots whatever the follower is *currently wearing* straight into a real preset, instead of writing to a legacy store the slot-based list never showed — no need to re-stage an outfit you already put on them.
- **Modded armor on extended slots stays visible.** The inventory and outfit menus no longer hide legitimate armor parked on biped slots 49-61 — skirts, pauldrons, layered tops/underwear, capes, corsets (the pieces SkyUI marks with a generic "shield" icon). Only genuinely valueless body overlays (SOS/TNG, morph markers) are filtered now.
- **Smooth mannequin rotation.** Dragging to spin the preview no longer judders or flashes a blank frame.
- **Mannequin skin rendering hardened.** The outfit preview now renders skin faithfully across the full range of modded setups. Full-colour skin replacers (Bijin et al., whose `bodyTintColor` is ~0) no longer bake to a black silhouette; wardrobe mods that bundle a duplicate body no longer z-fight into gray blotches; SAM's junk skin specular no longer paints a gray metallic rim; a follower whose body texture simply isn't streamed to full-res yet is demand-loaded from disk instead of dropping to flat white/peach (the Lillith Maiden-Loom "white body" case); a body referencing a genuinely-missing texture (Lillith's "Unibody" overlay) is dropped instead of rendering purple; and alpha-blended skin overlays the opaque baker can't composite — SexLab fluids, RaceMenu scars/tattoos/dirt — are dropped rather than painting black or red over the body (the Saadia "black front + dark-red face" case). Skin overlays (scars, bodypaint, fluids) still don't *composite* into the preview, but now degrade to cleanly absent instead of artifacting.

### Companion + follower

- **Wait / Follow buttons** on every companion card (per-row Wait + Follow, plus Wait All + Follow All in the mass-actions row). Mirrors the hotkey and wheel-menu entry points 1:1.
- **Summon All** mass-action button.
- **Companion Wait / Sandbox reliability fixes.** Ported the sandbox approach from Sever's Hearth — adds `EvaluatePackage()` calls so wait/follow transitions happen immediately instead of on the next AI tick, bumps sandbox package priority above other follower-framework overrides, and uses a gentler AI-reset flag. No more "I told them to wait but they're still trailing me."
- **Schedule system.** Dismissed followers can be assigned per-hour Home / Work / Relax locations and they'll actually go there on the right schedule.
- **NFF-style follow package (V2).** Tiered priorities, idle behaviors, and dynamic stance — replaces the prior default template.
- **Healer combat style.** Set any follower to "healer" via PrismaUI dropdown, dialogue, or `setcombatstyle` action — they force-cast healing during combat with proper target priority, cooldowns, and a bleedout fail-safe.
- **Cell catchup.** Followers no longer get left behind through load doors. A native catch-up sweep runs 1.5s after the player's cell loads, moves any roster member who didn't follow through, evaluates their package, and randomizes positions slightly to avoid pile-ups.
- **Follower friendly-fire prevention.** Stray AoE / cloak / cone-spell hits between SA-followers no longer flip them hostile to each other.
- **Per-follower Essential toggle** properly persists across save/load.
- **Equipping a recruited NPC** now diff-strips the vanilla hunting bow + iron arrows starter kit so they don't permanently re-equip them.
- **Animated NPC spell casting** via UseMagic AI packages — `castSpell` action now produces the visible casting animation instead of just stat changes.
- **AttackTarget auto-cleanup** via ForcedCombatMonitor — combat ends cleanly when the target dies or surrenders, no stuck combat state.
- **Track-only followers no longer wander off when the player sleeps.** `OnSleepStart`'s package-override clear used to wipe the external framework's follow package on NFF / SPID custom-AI / Serana-style followers, leaving them on default idle AI. Now gated to skip tracking-only followers; their controller owns the package stack.
- **Fallen-comrade count fixed.** The Companions page no longer over-counts fallen comrades, and a **Clear Fallen & Orphaned** bulk action prunes dead and stale entries in one click.
- **Safe-interior sandbox no longer sticks.** A companion who sandboxed in a tavern (e.g. after sleeping) could get stuck on the interior package and wander off instead of resuming follow; the sandbox now releases cleanly on active companions.

### Travel system

- **TravelOrchestrator** — new unified high-level travel API that composes line-of-sight arrival, stuck escalation, preflight reachability, and graceful give-up into one state machine with a single completion event.
- **StuckDetector** now disambiguates "actually stuck" from "slowly pathing through a crowded inn" — the 30-second teleport no longer fires on actors who are navigating, just slowly.
- **LOS-aware arrival.** Travel destinations on the far side of a wall, on a different floor, or behind a closed door no longer trigger arrival from raw distance alone.
- **Graceful give-up.** When a destination has broken navmesh, fall back to the actor's editor location instead of teleporting them deeper into the broken area.

### Crafting commissions (new)

Order crafted gear now and collect it later, instead of standing at the forge while it's made.

- **Order now, collect later.** Ask a blacksmith to craft something; they quote a price, take a deposit, and you pick the finished piece up on a return visit. The smith remembers which commissions are outstanding and hands the item over when it's ready.
- **In-character pricing.** The smith names the deposit and total themselves, and the system charges exactly what was quoted — the spoken price and the gold actually moved always match.
- **Commissions ledger.** A Commissions sub-rail on the World → Ledger page tracks open orders and completed history.

### Performance + load-time

- **Save load is now visibly faster.** Heavy per-follower maintenance (essential flag, combat style application, healer registration, opinion rebuild) moved from a saturated Papyrus VM to native C++ at `kPostLoadGame`. The PrismaUI hotkey is now responsive within ~1–2 seconds of cosave restore (was ~25 seconds on heavy rosters).
- **Hearth-parity sandbox transitions.** `EvaluatePackage` calls added so wait/follow respond immediately.
- **Batched mass actions.** Wait All / Follow All now dispatch a single event that Papyrus iterates server-side, instead of firing one event per follower — keeps the engine sane for NFF/UFO setups with 10+ followers.
- **Companions page opens instantly on large rosters.** Each companion's Bio / Memories / Journal is now gathered lazily — only when you open that companion — instead of building all of it for every follower up front on page load.
- **More per-tick work moved to native C++.** Survival and Fertility cell scans, plus the follower-roster lookup, no longer run on the Papyrus VM every tick.

### Stability + crash fixes

- **Non-UTF-8 JSON crash fixed.** SkyrimNet payloads containing Cyrillic or other non-ASCII characters used to crash with a `nlohmann::json::type_error.316`. Now strings are sanitized on the boundary.
- **Survival page banner no longer shows stale followers from a previous save.** A frontend cache-merge bug surfaced characters from a prior load on a brand-new game (Daegon shown in the warmth banner with no party). All conditionally-emitted fields now emit cleared placeholders so the merge correctly reflects the current save.
- **PrismaUI menu hotkey no longer silently breaks.** When the native script class grew past Skyrim's 511-function-per-script limit, every native call on it failed at link time. Functions were split across a sibling class so the budget stays safe.
- **CommonLibSSE-NG v4.17 upgrade** — pinned via vcpkg overlay for reproducible builds, adopting native APIs that replaced ~180 lines of keyword-scanning warmth code, the legacy hand-rolled raycast, the Disable/Enable navmesh-snap pattern, and process-tier queries.
- **OutfitMigration log lines** in `Papyrus.0.log` show any conflicts between your old StorageUtil data and the new native store when the migrator runs on first load.
- **Dashboard no longer freezes the game on open.** A raw engine-member read for the compass-tracked quest banner spun forever on an unreliable lock, wedging the game thread the moment the dashboard opened. Removed — the banner now picks deterministically among your active quests.
- **Decorator render-thread crashes closed.** SkyrimNet renders decorators on worker threads; ours now read from main-thread snapshot caches instead of touching live engine state mid-render, eliminating a class of race-condition crashes.

### Prompts + content

- **Nearby objects prompt split.** General dialogue context no longer carries container contents (keeps payload bounded), but action-mode now gets the full container listing so the LLM can pick items from a chest properly.
- **Merchant inventory** prompts now render in `action` mode too, so the LLM has shop prices visible while picking buy/sell actions — not just during narration.
- **User-configurable Nearby Objects filters.** PrismaUI Settings → Prompt Filters lets you exclude object types (clutter, misc, furniture:bed, item:weapon, etc.) from the LLM's nearby-objects context.
- **Familiarity prompt eavesdrop filter.** Strangers no longer falsely claim to have overheard your name from a follower in places the follower has never spoken (Soul Cairn ghost scenario).
- **Bounty prompt** updated with full scene-coverage (same-cell arrest section, dispatch-escort section, prisoner mid-escort affordance) and explicit exclusion lists.
- **SkyrimNet character-bio Tier 1 audit** — 55 priority bios (vanilla followers, major quest characters, key faction figures) re-written to remove Tough-Guy-One-Liner speech_style priming and forward-looking quest spoilers in summary blocks. Ships as a parallel track outside the FOMOD.
- **Yield / surrender context toggle.** A new Settings → Prompt Filters → Combat Context switch suppresses the "just surrendered / received a surrender / surrender broken" guidance when it doesn't fit the moment. Ceasefire and active-combat awareness are unaffected.
- **Prior-companion context deferred to SkyrimNet.** Dropped the redundant "Past Relationship" block from the follower bio; SkyrimNet's own relationship decorator already surfaces that history, and the SA version could mis-fire for NPCs you'd only briefly traveled with.

### Miscellaneous polish

- **Brawl decorator** + split-prompt support so the LLM has structured awareness of brawl state.
- **OSL silencer** keeps OStim/SexLab scenes from spamming the LLM context.
- **CollectPayment** non-pausing PrismaUI overlay POC — collect debts without freezing the world.
- **Transfer Ownership** action on the Actions page.
- **Group Meeting** revived on SkyrimNet primitives.
- **MCM UI Scale slider** as a PrismaUI escape hatch for users who can't read the default size.
- **Off-Screen Life per-NPC cooldown overrides** + first-load staggering so dismissed-follower events don't all fire at once on save load.
- **Quest awareness** noise filter, new Companions sub-tab, C++ LLM pump, per-follower memory.
- **Holdings hold-resolution fix.** The Holdings portal tile no longer renders "Unknown × 1" for properties whose name doesn't contain the hold keyword (Breezehome, Vlindrel, Hjerim, etc.) — replaced with a three-tier resolver.
- **Claim a property (Estate).** The World → Ledger → Estate tab gained a search to bring any building into your name — houses, inns, halls, temples (caves / dungeons filtered out, with a "Show all interiors" toggle for modded homes). It uses the same faction co-ownership as the in-character deed transfer, so you and the original owner share it without trespass — ideal for backstory roleplay. Each property card's badge is a click-to-cycle flavor label (Transferred / Purchased / Inherited), and releasing a claimed property now fully reverts ownership (it was passing a null faction before).
- **NPCs no longer recite your holdings.** Removed the character-bio block that injected the player's full property list into every NPC's context.
- **Ownership-aware looting.** Taking an owned item through a SeverActions loot/pickup action no longer gives the *player* a vanilla theft bounty (the "my follower grabbed a tankard in a tavern and now I'm wanted" case) — owned items transfer silently instead of tripping the engine's theft alarm. Loot-corpse now targets the nearest matching body, and locked containers are refused outright.
- **No more critters in "nearby people."** Ambient animals (rabbits, foxes, etc.) are filtered out of the dashboard / nearby-actor lists.

### Sever's Hearth — AI camping (bundled, new)

A new AI-first camping mod ships alongside SeverActions as an **optional FOMOD module** ("Sever's Hearth (Camp System)"). It replaces Campfire outright — **no dependency required**. This is an early, foundational release: the core camping loop and LLM camp-awareness are in; survival, threats, and the off-screen follower-agency layers are still ahead.

- **Make camp on the trail.** A companion can pitch a camp at the player's position — a fire ring and bedroll for the party to rest, eat, or take watch. (Player-initiated camp placement isn't in yet; camps are established relative to the player by a follower.)
- **Establish / Break / Go-To camp actions.** The LLM can suggest making camp when the party needs to stop for the night, break it down to move on, or send a companion ahead to an existing camp.
- **Camp-aware companions.** While a camp is active, the `current_camp` decorator feeds the campsite into each follower's bio context, so they reference the fire, a shared meal, or resting here naturally in conversation — the camp becomes a known waypoint in the scene, not just props.

---

## v2.9.9

### SkyrimNet Bio Audit — Tier 1 (Parallel Track, Not In FOMOD)

Independent audit pass over the SkyrimNet character bios shipped at `Data/SKSE/Plugins/SkyrimNet/original_prompts/characters/` (3,146 bios total). Drove by the same lesson learned from the Kynreeve case: bio `speech_style` blocks that describe a character as "clipped, terse, blunt" prime the model to produce period-stopped Tough-Guy One-Liner output regardless of any prompt-level guardrails, because character-scoped voice instructions outweigh scene-scoped ones. Same applies to `summary` blocks that bake in forward-looking quest spoilers — a stranger meeting the NPC for the first time shouldn't have those framings driving the LLM's first-impression dialogue.

Wrote a triage script (`bio_triage.py` — temp, not in repo) that flagged 1,354 bios across 3,146 with at least one issue: 951 with speech_style priming only, 259 with summary spoilers only, 144 with both. Of those, 55 are flagged as priority NPCs (vanilla followers, major quest characters, key faction figures).

Processed all 55 priority bios in this pass:

- **Lydia** (worked example, hand-edited as the template): replaced "direct, concise sentences with minimal embellishment" with "measured rather than clipped — full thoughts, even when brief, with their joints intact." Removed Dragonborn-specific framings from summary; kept thaneship references (publicly bestowed honor, not a spoiler). Werewolf/Greybeards/Western-Watchtower references reframed.
- **54 additional bios** processed in 5 parallel agent batches, each given the handoff doc + Lydia's before/after as a worked template:
  - **Whiterun & Companions (11)**: aela_the_huntress, athis, balgruuf_the_greater, farkas, irileth, kodlak_whitemane, njada_stonearm, proventus_avenicci, skjor, uthgerd_the_unbroken, vilkas
  - **College & Mages (7)**: ancano, drevis_neloren, festus_krex, mirabelle_ervine, neloth, phinis_gestor, savos_aren
  - **Greybeards & War Factions (9)**: arngeir, borri, delphine, einarth, elenwen, esbern, galmar_stone-fist, paarthurnax, wulfgar
  - **Thieves Guild & Dark Brotherhood (6)**: arnbjorn, babette, karliah, mercer_frey, tonilia, vex
  - **Followers & Dawnguard DLC (21)**: ahtar, annekke_crag-jumper, argis_the_bulwark, borgakh_the_steel_heart, calder, florentius_baenius, frea, golldir, ingjard, iona, isran, jenassa, marcurio, mjoll_the_lioness, rayya, serana, sorine_jurard, teldryn_sero, valdimar, valerica, vorstag

**Approach per bio**:
- `speech_style`: rewritten to capture voice without priming. The replacement vocabulary pattern: "X, never clipped — full sentences with their joints intact" / "economical with words but always answers fully" / "speaks plainly, no flourish, no theater." Each character's accent, register, and personality preserved (Nord cadence, Dunmer formality, scholarly precision, etc.) — only the priming language was changed.
- `summary`: forward-looking quest spoilers stripped. Public-knowledge framings kept (Jarl titles, Harbinger, Greybeard membership for Greybeards themselves, public faction roles). Hidden identity reveals moved to the `background` block where the LLM still has the context for in-character behavior but the player isn't tipped off through summary-driven dialogue.
- All other blocks (`personality`, `appearance`, `aspirations`, `relationships`, `occupation`, `skills`, `interject_summary`, `background`) preserved verbatim, with the documented exception of `background` accepting relocated spoiler material from `summary` (per the handoff doc's explicit allowance).

**Spoiler decisions worth flagging**:
- Companions werewolves (Aela, Farkas, Skjor, Vilkas, Kodlak) — werewolf nature stripped from summary, preserved in background. Kodlak's "Harbinger" title kept as it's publicly known.
- Balgruuf's Talos worship — explicit "secretly" framing removed; reframed as "quietly worship in private" in background.
- Delphine's Blade identity — full reframe to Riverwood innkeeper in summary; Blade material in background.
- Esbern's Blades scholarship + Alduin expertise — full reframe; quest-specific material in background only.
- Paarthurnax's dragon-priest past + Alduin betrayal — full reframe to "ancient wise being who teaches the Way of the Voice"; quest-specific material in background.
- Mercer Frey's Karliah-betrayal arc — stripped from summary; kept in background.
- Karliah's Nightingale identity — stripped from summary; reframed as "Dunmer thief of the old school carrying a long-waiting grudge."
- Babette's vampire age and posing-as-child gotcha — stripped from summary; kept in background for behavioral fidelity.
- Serana's Daughter-of-Coldharbour lineage — softened to "vampire of unusual lineage" in summary.
- Valerica's Soul Cairn imprisonment + Elder Scroll + Tyranny-of-Sun prophecy — heavy summary reframe to "ancient vampire of unusual lineage with a long history rooted in old Nord nobility"; quest-specific material in background.
- Housecarls (Argis, Calder, Iona, Rayya, Valdimar) — false-positive spoiler hits on "thane" references; thaneship is publicly bestowed and is literally their job description, kept verbatim. Speech_style priming fixed where flagged.

**Codex spot-check**: ran `codex exec` over a 3-sample cross-section (Aela, Delphine, Valerica) for independent quality review. Verdict: PASS on all three, with two minor caveats noted (Aela's background got one new sentence relocating the werewolf-as-private-Circle-matter detail from summary — which is allowed per handoff; Valerica's "Serana's daughter" reference stayed in summary, which is fine since that relationship is revealed in the opening minutes of Dawnguard).

**Where the override bios live**:
- Live game (deployed): `Data/SKSE/Plugins/SkyrimNet/prompts/characters/<filename>.prompt` — SkyrimNet's override path; takes precedence over `original_prompts/characters/`
- Repo (captured for git): `Bios/SKSE/Plugins/SkyrimNet/prompts/characters/<filename>.prompt` — mirrors a future FOMOD module structure if we decide to package and ship publicly

**Tier 2 — additional 27 priority NPCs (next commit)**

Expanded the priority slug list in `bio_triage.py` to capture more high-traffic NPCs beyond the original Tier 1 hardcoded set. Re-running the triage surfaced 27 new priority candidates that weren't covered in Tier 1. Processed in 3 parallel agent batches:

- **Cities & shopkeepers (10)**: camilla_valerius, lucan_valerius, ysolda, viola_giordano, brunwulf_free-winter, brelyna_maryon, temba_wide-arm, morwen, niranye, calixto_corrium
- **Hold stewards & deeper Thieves Guild (8)**: anuriel, raerek, falk_firebeard, alessandra, sapphire, thrynn, cynric_endell, gallus
- **Daedric Princes & Volkihar vampires (9)**: malacath, boethiah_cultist_generic, boethiah_generic, fura_bloodmouth, garan_marethi, orthjolf, ronthil, vingalmo, rexus

**Key spoiler decisions in Tier 2**:
- **Calixto Corrium** — most spoiler-sensitive bio in the audit. He's the Butcher of Windhelm (Blood on the Ice murder mystery). Summary completely reframed to public-facing antiquities collector / curator of the House of Curiosities. Interject_summary also edited (original told the LLM to volunteer murder-adjacent commentary unprompted — itself a leak path). All Butcher details in background only.
- **Niranye** — Thieves Guild fence cover stripped from summary; reframed as Windhelm market vendor.
- **Anuriel** — Maven Black-Briar bribery / spy framing stripped from summary; reframed as competent Mistveil Keep steward.
- **Raerek** — covert Talos worship stripped from summary; reframed as Igmund's uncle and senior administrator.
- **Falk Firebeard** — false-positive thane_ref hit, no spoiler change needed (public Solitude steward).
- **Sapphire** — Mallory family lineage stripped from summary; reframed as guarded TG enforcer with hard past she does not discuss. Mallory hint preserved in background as in-world rumor without naming Glover/Delvin.
- **Gallus** — Nightingale role + Nocturnal pact + Skeleton Key bond stripped from summary; reframed as previous Guildmaster murdered ~25 years ago, mentor and lover of Karliah. Background keeps full Nightingale context.
- **Vingalmo** — "secretly plotting to take control" stripped from summary; relocated to background.
- **Volkihar court vampires (Fura, Garan, Orthjolf, Ronthil, Vingalmo)** — vampire status kept in summary (faction-public among Volkihar); specific schemes / future-plot framings moved to background.
- **Malacath** — Trinimac transformation kept (deep TES lore, scholar/Orc-known), summary lightly reframed; mostly speech_style fix.
- **Boethiah** — quest-mechanic preserved in lore framing (Prince of Plots, encourages betrayal as virtue); the follower-sacrifice mechanic of Boethiah's Calling not specifically tipped off.
- **Rexus** — Amaund Motierre's Dark Brotherhood contract framing stripped from summary; reframed as imperial attendant traveling with Amaund. DB association in background.

**Tier 3 — additional 30 priority NPCs (next commit)**

Further expansion of the priority slug list to capture Solstheim NPCs, Hold Jarls and court members, civil-war side cast, Daedric quest-givers, deeper TG/DB members, and spouse-able shopkeepers. Re-running the triage surfaced 30 new candidates beyond Tier 1+2. Processed in 3 parallel agent batches:

- **Solstheim & Telvanni (7)**: bujold_the_unworthy, mogrul, fethis_alor, ralis_sedarys, elynea_mothren, adril_arano, tilisu_severin
- **Holds politics & civil war side cast (10)**: igmund, hrongar, brina_merilis, faleen, vignar_gray-mane, idolaf_battle-born, olfina_gray-mane, ralof, yrsarald_thrice-pierced, hofgrir_horse-crusher
- **Daedric / TG side / Thalmor / spouse-ables (13)**: erandur, ennodius_papius, sarthis_idren_generic, rulindil, dirge, vipir_the_fleet, ravyn_imyan, dravynea_the_stoneweaver, grelka, mralki, maven_s_bodyguard, carcette_the_survivor_generic, runa_generic

**Key spoiler decisions in Tier 3**:
- **Tilisu Severin** — most spoiler-sensitive of T3. The Severin family in Raven Rock is actually a Morag Tong assassin team hiding under House Hlaalu identity to kill Councilor Lleril Morvayn ("Served Cold" Solstheim quest). Summary fully reframed to wealthy Dunmer matron of a respectable merchant household + community benefactor + polite-and-reserved public persona. All Morag Tong / assassination plot detail in background.
- **Ralis Sedarys** — Kolbjorn Barrow excavator who is being possessed by the dragon priest Ahzidal. Summary reframed to enthusiastic archaeologist looking for a backer. Possession/sacrifice arc in background.
- **Olfina Gray-Mane** — secret romance with Jon Battle-Born (Whiterun's Romeo-and-Juliet sub-plot). Romance moved from summary to background.
- **Erandur** — Vaermina cultist past stripped from summary. Reframed as kind priest of Mara helping with Dawnstar nightmares.
- **Ennodius Papius** — Dark-Brotherhood-actually-after-him reveal de-specified to "a Daedric cult has marked him for death" so the Boethiah's Calling sacrifice option isn't tipped off. Summary reframed to paranoid hermit.
- **Rulindil** — specific Etienne/Esbern Blade-interrogation framing stripped from summary. Reframed as Third Emissary / Elenwen's chief interrogator who runs informant networks. Esbern/Etienne specifics in background and aspirations.
- **Runa (generic)** — vampire status moved from summary opening to background. Reframed as "vivacious Nord woman" with vampiric nature as background-only detail.
- **Carcette the Survivor (generic)** — vampire/Vigil references kept (fighting vampires is the Vigilants' public mission). Speech_style only.
- **Holds & civil war (Igmund, Hrongar, Brina, Vignar, Idolaf, Ralof, Yrsarald)** — public political stances + family feuds are open lore. Speech_style fixes only, no spoiler reframes.
- **Daedric victims (Sarthis Idren)** — public framings as quest hooks (skooma dealer, etc.) preserved. Speech_style only.

**Tier 4 — Class generics (89 new bios)**

Tier 4 covers class-level generic bios — every Hold guard shares one, every bandit shares another, every vampire another, etc. Changes here propagate to dozens of NPCs at once. The user requested specific behavioral tweaks for the bandit family on top of the standard speech_style fix.

**Bandit family with tier-scaled yield/surrender behavior** (13 bios):

User-driven design: bandits should be less death-wish, should surrender when they see a no-win situation, AND there should be variance so they don't all sound the same. But higher-tier bandits should resist more. Implemented as a 3-tier scale across the bandit hierarchy:

- **Base tier — `bandit_generic`** (rank-and-file outlaws). Self-preservation overrides bravado. Yields readily once a clear no-win emerges. Five sub-archetypes (opportunist / desperate / hot-head / weary veteran / cruel one — last one used sparingly) so individual bandits read as different people. Speech_style describes voice variation, profanity as situational not punctuation, surrender lines explicitly modeled ("I yield" / "Take the gold, just walk" / "Mercy, traveler") rather than defiant last words.
- **Mid-tier — lieutenants** (4 bios: bandit_lieutenant, bandit_chief_lieutenant, bandit_raid_lieutenant, bandit_lieutenant_overseer). Between recruit and chief — more to prove than a recruit, less to lose than a chief. Yields more readily than a chief, less than a recruit. Same archetype variance pattern.
- **High-tier — chief / leadership** (3 bios: bandit_chief_generic, bandit_ringleader_generic, bandit_reaver_lord_generic). Authority-driven resistance. Will fight harder, longer, through more pain than rank-and-file before yielding. Bargains from strength rather than collapsing into terror — "a chief who calmly proposes terms with their gang dying around them is in character; a chief who collapses into stammered terror is not."
- **Elite/named-archetype — zealot tier** (5 bios: bandit_exalted_lieutenant, bandit_frostborn_disciple, bandit_finger_of_the_mountain, bandit_daughter_of_the_hammer, bandit_woman_of_the_hammer). Identity bound up in title. Yielding framed as "spiritual collapse, not just tactical defeat" — most would rather die than be the [archetype] who folded. Still leaves narrow archetype-variance room for rare exceptions, but the default is "rarely yield."

Codex spot-check on the three tier representatives (base / chief / Frostborn Disciple): PASS on all three, tier-scaling clearly distinguishes panic-tier from authority-tier from zealot-tier.

**Hold guard generics** (17 bios): Speech_style fixes only — public faction roles. Each Hold's regional flavor preserved (Whiterun's "I used to be an adventurer" lineage, Riften's Maven-quieting pattern, Markarth's tense Forsworn-shadow undertone, Eastmarch's Stormcloak conviction, etc.) without using priming words.

**Faction soldiers** (26 bios): Imperial (10), Stormcloak (5), Dawnguard (3), Forsworn (8). Speech_style fixes. Forsworn explicitly NOT given yield/surrender language — they ARE zealots (Reachman tribal religion, generations of bitterness against Nord/Imperial conquest) and that's their character, not a failure mode to correct.

**Predator / criminal class generics** (33 bios): Vampires (basic + elite tiers), Necromancers (novice through master), Mercenaries (East Empire, Black-Briar, Silver-Blood), Hunters (including Old Orc with culturally-accurate death-seeking PRESERVED — that's Malacath's tradition, not a death-wish bandit pattern), Thieves, Alik'r warriors, Orc raiders, Afflicted (Peryite cultists). Speech_style + minor reframes; vampire/necromancer class identity is the bio's class trait (not a spoiler).

**Tier 5 — Long-tail spoilers-first sweep (322 new bios)**

Tier 5 covers the remaining spoiler-bearing bios across the long tail — every bio whose `summary` block leaks forward-looking quest material, regardless of whether the NPC is named, generic, modded, or vanilla. Strategy was **Option A (spoilers-first)**: chase the spoiler vector, skip pure speech-style-only bios for now. Speech-style-only bios (~830 remaining) can be picked up in a Tier 6 / Option C full mechanical sweep if prioritized later.

Triage produced 339 spoiler-bearing bios across the sub-categories. Processed in 10 parallel agent batches across 2 waves:

**Wave 1 (5 batches, 154 bios)**:
- **S1-A / S1-B — supernatural reveals (~60 bios)**: hidden vampires, werewolves, lycanthropes among townsfolk and stranded NPCs. Major reframe targets: Saadia (Hammerfell noble identity stripped), Movarth Piquine, Hert/Hern (Half-Moon Mill vampires).
- **S1-C — hidden-identity reveals**: Sybille Stentor (Solitude court vampire reframed to Court Wizard role), Sam Guevenne (Sanguine in disguise — divine reveal stripped), the Nerevarine (Indoril Nerevar / Dagoth Ur reveals stripped to Dunmer warrior framing), Vyrthur, corrupt_agent, Bloodchill Manor staff.
- **S2-A / S2-B — supernatural + Solstheim hidden identities**: thrall/cattle types kept frank (in-faction), vampire naturalists kept open. Major reveals processed: Eltrys (Forsworn conspiracy investigator with impending death NOT spoiled in summary), Korrilan, Eldawyn, Aringoth (Aretino skooma identity), Balagog gro-Nolob — the Gourmet (public-facing chef in summary, Listener-of-the-Dark-Brotherhood / cookbook author context in background), Vendil Severin (Morag Tong assassination team identity reframed).

**Wave 2 (5 batches, 168 bios written + 17 false-positive skips)**:
- **S2-C — supernatural reveals third batch (33 bios)**: Volkihar in-faction NPCs kept frank, Falkreath hidden vampire (Raven) reframed to wealthy patron, Hunters of Hircine kept frank (in-faction), Sinding (lycanthropy moved to background, jail context preserved), Bloodchill Manor staff (Tilde / Vori — held as cover-staff with vampirism in background).
- **S3 — faction allegiance reveals (25 bios)**: Dark Brotherhood members reframed by cover persona (Mion, Vayne, Morrigan, Safia, etc.), DB initiates met inside the Sanctuary kept frank (player is Listener at that point), Thalmor agents kept frank when public (high_elf_*, thalmor_sentry, estormo, armion) and tightened when undercover (Captain Valmir cover identity); Nightingales (Llewellyn / Lyra / Pyrus / Zin Wythering) — all false positives, "Nightingale" was a stage name, surname, or self-styled epithet.
- **S4-A — Dragonborn references first half (49 bios)**: townsfolk whose summaries assumed player-as-Dragonborn, Auryen Morellus (4 FormIDs — Legacy of the Dragonborn curator with player-as-guildmaster relationship sanitized; "Dragonborn Gallery" institution name preserved as proper noun), Sovngarde heroes (Felldir / Hakon / Gormlaith) kept dragon-war-explicit but no Dragonborn-pre-spoiler, Helgen survivors with "the great black dragon" framing, Whiterun Watchtower guards reframed.
- **S4-B — Dragonborn references second half (49 bios)**: museum guards group treatment (10+ near-identical entries handled consistently), dragon NPCs kept dragon framing (Mirmulnir / Sahloknir / Nahagliiv / Odahviing / Vuljotnaak / Viinturuth / Silah) with player-pre-knowledge stripped, **Nerien** (Psijic Order spoiler reframing — first impression now "robed Altmer mystic of unclear origin"), **Shavari** (Thalmor assassin — assassination contract specifics moved out of aspirations/relationships), modded-NPC Dragonborn dependencies cleaned.
- **S5 — misc spoilers (29 bios, 12 written + 17 skipped as false positives)**: most `thane_ref` hits were public-title noise (Thane Charlotte, Thane Eirfa Four-Shoes — title literally in name). Real fixes on Bryling, Dengeir, Irnskar, Jordis, Gregor, Markus, Engar (player-as-Thane reframings + speech_style); Kjar, Lagdu, Svetlana (speech_style only with backstory betrayal kept); Pelagius the Suspicious (speech-only, paranoia preserved as character trait); Stig Salt-Plank (meta-bribe hint cleaned).

**Codex spot-check on Tier 5 representatives**: ran `codex exec` over a 10-sample cross-section (nerien, captain_valmir, raven, auryen_morellus_33F, klimmek, pelagius, nahagliiv, shavari, felldir, armion). Verdict: 7 PASS, 2 CONCERN, 1 FAIL. Patched the 3 flagged bios:

- **captain_valmir_5B7** (FAIL): `occupation` block was leaking the undercover Thalmor reveal explicitly ("Outwardly: ... Actually: an undercover Thalmor agent..."). Rewrote occupation to public-facing captain-at-camp persona only; aspirations reframed away from "advance Thalmor power" / "avoid exposure as a Thalmor spy" toward task-and-cover language; relationships reordered so Thalmor superiors became "his real superiors (private)" trailing entry rather than lead.
- **nerien_CC9** (CONCERN): relationships block had "The dragon-blooded warrior: Subject of prophecy and evaluation" as the lead entry. Removed; replaced with generic "Mortals of unusual potential: Watched, evaluated, and only ever addressed when the moment demands it."
- **shavari_E22** (CONCERN): aspirations + relationships blocks surfaced the active assassination contract too directly (Esbern as secondary target, target-as-Dragonborn-embarrassment). Reframed aspirations to "close her current high-priority assignment cleanly," removed Esbern entirely from relationships, trimmed `interject_summary` references.

After patches: all 10 sample bios PASS on spoiler containment + playability + speech style. Codex confirmed no `{% endml %}` typos across the sample — block markers all balanced.

**Tier 6 — Long-tail speech-style mechanical sweep (840 new bios)**

Tier 6 closes out the audit by sweeping every remaining bio whose `speech_style` block had priming language but whose `summary` had no spoilers (Tier 5 already swept the spoilers). Triage produced 840 bios across 14 batches of 60. Pattern distribution: 727 with `clipped`, 133 with `terse`, 77 with `blunt`, 13 misc (`brusque`, `concise/direct`, `short/sharp`, `minimal_sentences`, `economy_of_words`).

Processed in two stages:

**Stage 1 — Parallel agents (Wave 1 + partial Wave 2, 474 bios)**: 9 agents dispatched across batches T6-01 through T6-10, each with 60 bios. Wave 1 finished cleanly (T6-01 through T6-05, 300 bios). Wave 2 finished partially (T6-06: 36/60, T6-07: 36/60, T6-08: 30/60, T6-09: 32/60, T6-10: 40/60) before the org's monthly Anthropic API usage limit cut off the remaining work mid-flight. Agent rewrites are bespoke per character — accent, register, profession, mood preserved while the priming is removed and anti-priming language ("full sentences with their joints intact" / "complete thoughts, never chopped" / "compact but complete") is integrated into the existing voice.

**Stage 2 — Mechanical Python fallback (366 bios)**: Wrote a regex-driven script (`t6_finish.py`) that does pattern-based substitutions (`clipped` → `compact`, `terse` → `economical`, `blunt` → `plain`, deletes `Example: "..."` quoted bait, etc.) and appends a standardized anti-priming clause: "Sentences keep their joints intact — full thoughts, even when brief, never reduced to chopped fragments." Skips any file that already has an override (preserves agent work). Ran in seconds; covered the unfinished tail of T6-06 through T6-10 plus all of T6-11 through T6-14.

The mechanical pass is meaningfully more formulaic than the agent pass — Codex's QA observed that "agent passes integrate the anti-priming into character voice, while mechanical passes often read like the original sentence plus a standard clause." Acceptable tradeoff for the long tail of obscure modded NPCs that may rarely be encountered in play.

**Codex spot-check on Tier 6 representatives** (10-sample mix of agent + mechanical): 7 PASS, 2 CONCERN, 1 sampling miss (I gave Codex a non-existent filename). Both CONCERNs are mechanical-pass bios with residual priming-**adjacent** language that wasn't in the regex set — `paratus_decimius_41B` keeps "sentences more fragmented" (stress-response description), `patrizia_4CA` keeps "trail off into mumbles." These are situational behavioral descriptions, not blanket cadence directives, and the standardized anti-priming clause counters them. Documented as known soft-priming tail residue rather than re-processed.

No primary priming language (`clipped` / `terse` / `blunt` / `Example: "..."` quoted bait) survives in any of the 1363 deployed overrides per Codex's sample and per a final scan. Block markers all balanced (1 `{% endml %}` typo introduced by an agent on `kauanne_generic` was caught by the post-processing scan and patched).

**Total bios audited across all 6 tiers**: 1,363 (Tier 1: 55, Tier 2: 27, Tier 3: 30, Tier 4: 89, Tier 5: 322, Tier 6: 840).
**Audit coverage**: ~43% of the 3,146 SkyrimNet character bios. The remaining ~1,800 are the bios that were already clean on both the speech_style and summary axes — no priming language in speech_style, no forward-looking spoilers in summary — and don't need overrides.

The Tier 4 batch is the highest-leverage of the audit — each generic bio touches dozens to hundreds of NPCs at runtime via SkyrimNet's character resolution. Editing `bandit_generic` once changes how every rank-and-file bandit speaks across the whole game.

**Codex spot-check** on Tier 2 sample (Calixto / Sapphire / Vingalmo): three "concerns" returned, all false alarms — Codex's PowerShell terminal misread the UTF-8 em-dash bytes as mojibake (verified clean via Python byte inspection), and Codex's "spoiler material now in background" objection is exactly the documented pattern from the handoff doc. The interject_summary edit on Calixto was justified — original framing told the LLM to volunteer murder-adjacent commentary unprompted, which is itself a leak path.

**What's still pending**:
- Long-tail generic bios (1,272 flagged — bandits, generic guards, generic merchants, lower priority)
- A `Bios` FOMOD module if the user decides to ship publicly. Currently the override files live in the repo at `Bios/` but aren't included in `build_fomod_zip.ps1`.

Documented in detail at `handoff_bio_audit.md` (repo root) for future-session continuity. The handoff covers the full failure-mode taxonomy, replacement vocabulary, workflow, and explicit guardrails on what NOT to do.

This is a parallel deliverable to the dialogue-prompt fixes — neither blocks the other, neither requires the other. The bios layer their effect on top of any prompt-level dialogue guidance.

### Dialogue Anti-Patterns — Stripped In-Context Examples

Hypothesis-driven trim of the BAD/GOOD example pairs in `0505_severactions_personality.prompt`. The previous structure listed each anti-pattern with a `BAD: "..."` and `GOOD: "..."` quoted illustration — useful for human readers, but documented few-shot leakage means LLMs sometimes reproduce surface features of in-context examples regardless of the negative label, especially when the BAD example happens to align with a specific character's voice (terse Dremora, clipped guards, etc.). Observed in playtesting: a Dremora character whose own bio described "clipped, philosophical" speech started producing Tough-Guy One-Liner-shaped output, with the model pattern-matching against the prompt's BAD examples that demonstrated exactly that shape.

Removed all BAD example quotations across 11 anti-patterns. Kept the anti-pattern names (which are evocative pegs the model can hang behavior on) and rewrote each entry as descriptive prose explaining the failure mode. Where the name alone is genuinely ambiguous (Faux-Archaic Filter, Therapy Voice), kept short representative phrases inline as illustrations, not full sentences. Net effect: ~30% token reduction on this prompt, and removal of the strongest cadence-priming surface forms.

The "When You Are the Engaged Speaker" section had a BAD/GOOD example pair built around a real playtesting failure ("A Dremora. Of course you do." — the Daegon scene). Replaced with descriptive prose that captures the same lesson without giving the model two sample lines to pattern-match against.

The 0550 cross-reference that mentioned "uses BAD/GOOD examples to show substance" was updated to "describes substance" since the examples are now gone.

This is a hypothesis worth testing in play. If dialogue quality regresses (model loses its grip on what specific anti-patterns mean without examples), examples can be added back selectively — they're in git history. If it stays good or improves, we've also freed token budget for other prompt work.

Validated via `mcp__skyrimnet__validate_prompt` → `{"valid": true}`. No template syntax changes.

### Off-Screen Life — World Setting Inclusion + Active-Follower Exclusion

Two related fixes to off-screen life event generation:

**Issue #8 (kiloughs) — World setting now flows through to off-screen events.** Added `{{ render_template("submodules\\system_head\\0010_setting") }}` to the system block of `sever_offscreen_life.prompt`. SkyrimNet's `0010_setting.prompt` is the file users replace to inject their own world-tone, genre, NSFW preferences, or conversion-mod context (Enderal etc.); previously off-screen events bypassed it entirely and would happily generate vanilla-Skyrim flavor regardless of whatever bespoke setting the user had configured for live dialogue. Now matches the same pattern SkyrimNet uses in `character_profile_update`, `dynamic_bio_update`, `generate_profile`, and `generate_memory` — single line, no behavior change for users who haven't customized 0010_setting (the default base file is just a `# Setting` header).

**User-reported (Severause) — "events sometimes mention an NPC who's currently with the player".** Symptom: off-screen prompt fires for dismissed-with-home Lydia, LLM writes "Lydia and Jenassa shared dinner at the Bannered Mare" while Jenassa is actively following the player elsewhere. Root cause: the prompt's `socialGraph` (sourced from SkyrimNet's `GetRelatedActors` PublicAPI) includes ALL NPCs the subject has interacted with — past companions, faction contacts, the player's spouse, currently-active followers — without filtering. The LLM picks any of these names as a plausible co-actor for shared events. The existing `nearbyFollowers` array was correctly filtered to dismissed-only (line 869 of `OffScreenLifeDataStore::Papyrus_BuildContext`), but the LLM had access to the broader socialGraph and would draw on it.

Two-layer fix in `OffScreenLifeDataStore::Papyrus_BuildContext`:
- **Build `activeFollowers` array** of NPCs currently traveling with the player (FollowerStore entries with `isFollower=true`, alive, not the subject themselves) and pass it into the prompt context. Lowercased name set retained for filtering.
- **Filter socialGraph** entries against the active-follower lowercase set so currently-following NPCs no longer appear as social connections in the prompt at all. Case-insensitive match handles BSFixedString case quirks. If filtering empties the graph, drop the field entirely instead of passing `[]`.

Prompt-side changes in `sever_offscreen_life.prompt`:
- New "NPCs currently traveling WITH {player}" section in the system block listing the excluded names with explicit "do not write events that involve, reference, mention, or imply contact with any of them" instruction.
- Tightened the existing nearbyFollowers shared-event guidance: shared events MAY ONLY involve names from the dismissed-companions-nearby list. If no plausible co-actor is in that list, the LLM must write a solo event instead of inventing a partner from socialGraph or memory.

Net effect: shared events are constrained to the same dismissed-followers-with-homes list the player can see in PrismaUI's Companions page. NPCs the player can currently see standing next to them never show up as off-screen co-actors. Solo events for affected followers when no dismissed peer lives in the same hold (the existing solo-event path is unchanged — `nearbyFollowers` was already a positive filter).

Validated via `mcp__skyrimnet__validate_prompt` → `{"valid": true}`.

### Outfit Actions — `0410_equipment.prompt` rebased on SkyrimNet Beta19

User-reported (issue #7, dimadetroit): the override copy of `0410_equipment.prompt` in `Actions/Outfit/` shipped a snapshot taken one day before SkyrimNet Beta19 released. SkyrimNet Beta19 renamed the in-scope variable from `npc.UUID` → `actorUUID` in `character_bio` submodules, but our override still used `npc.UUID` in the first block. Result was ~32 missing-variable warnings per session in `SkyrimNet.log` (`'npc.UUID' not found at line 1844:47`, plus cascading `item.formID` / `item.equipment_slot` / `item.slot_body_area` warnings as Inja's graceful error handler rendered the empty equipment iteration). In-game behavior wasn't visibly broken, but the LLM context was missing equipment information for the affected actors, subtly degrading roleplay accuracy.

Fix: replaced 4 occurrences of `npc.UUID` with `actorUUID` in the first block (the `full / thoughts / transform / equipment / action` render-mode branch). All five SeverActions-specific improvements preserved — `render_mode == "action"` extension, `original_name` lookup via `get_item_customization(item.formID).originalName`, parenthesized `(original_name)` display, and the "ground truth" disclaimer. The second block (`dialogue_target`) was already correct (uses `responseTarget.UUID`) and didn't need changes.

Validated against the live SkyrimNet context engine — `mcp__skyrimnet__validate_prompt` returns `{"valid": true}`. Affected installs see the warnings stop appearing on the next prompt render after the fix lands.

### Convenient Horses 7.1 — Multi-Follower Conflict Fix

User-reported (issue #6, dimadetroit): with Convenient Horses 7.1 + AE Patch active and SA's `severactions` framework mode, recruiting Companion #2 would auto-dismiss Companion #1 within ~5 seconds. Doesn't reproduce without CH or with Convenient Horses With MCM v5.1 (a different mod). The 3-mod handshake breaks like this:

1. SA recruits NPC #1 via `dfScript.SetFollower(NPC1)` → vanilla `pFollowerAlias.ForceRefTo(NPC1)` → engine adds NPC1 to `CurrentFollowerFaction` (CFF) via the alias's CK auto-management config
2. CH 7.1's `chfollowerquestscript.OnUpdate` polls every 5s, scans `DialogueFollower` aliases 0-19, captures NPC1 via `localAlias.ForceRefTo(NPC1)` into its own CHFollowerAliasScript slot. The slot enters `Horseless` state and starts a 2s polling loop
3. SA recruits NPC #2 via `dfScript.SetFollower(NPC2)` → `pFollowerAlias.ForceRefTo(NPC2)` silently evicts NPC1 from the alias, and the engine auto-removes NPC1 from CFF
4. Within 2s, CH's `Horseless.OnUpdate` evaluates `GetFollowerRecruited()` = `FollowerRef.IsInFaction(CurrentFollowerFaction)` = false → calls `Clear()` on its alias → `OnFollowerRemoved()` → `FollowerRef.SetPlayerTeammate(GetFollowerRecruited())` = `SetPlayerTeammate(false)` on NPC1
5. SA's native `TeammateMonitor` catches the SetPlayerTeammate(false), fires `SeverActions_NativeTeammateRemoved`, the Papyrus handler queues NPC1 in `PendingDismissActor` and registers a 2.5s confirmation update
6. 2.5s later, OnUpdate confirms `!IsPlayerTeammate()` → `UnregisterFollower(NPC1)`. Total elapsed from NPC2 recruit: ~4.5s, matches the user's reported timing

**Fix**: in `SeverActions_FollowerManager.psc::RegisterFollower`, immediately after `RecruitViaVanillaDialogue(akActor)` runs in the non-NFF path, iterate `GetAllFollowers()` and re-add every prior SA-managed follower (≠ akActor) to `CurrentFollowerFaction` if their rank is < 0. This restores the CFF membership the alias auto-management evicted, so CH 7.1 (and any other mod gating "is recruited?" on CFF) keeps treating prior followers as recruited. ~20 lines, no-op when no prior followers exist (single-follower scenario unaffected). Track-only followers (SPID/EFF/NFF/custom) are untouched — they don't go through `RecruitViaVanillaDialogue` in the first place.

**Why this approach over alternatives**: independently verified by Codex against the same code — restoring CFF fixes the cause, not just the symptom (vs. a grace-period filter on `OnNativeTeammateRemoved`, which would mask the dismiss but leave NPC1 with stale `SetPlayerTeammate(false)` state). Skipping `dfScript.SetFollower()` entirely for subsequent recruits would also stop the eviction but break vanilla follower dialogue topics ("Follow me / Wait / Dismiss") and prevent CH from discovering the new follower at all — wider compat regression than the original bug.

**Affected saves**: existing saves where NPC1 already got dismissed before the patch landed will need a one-time re-recruit. Subsequent recruits won't re-trigger the dismiss.

### Outfit Builder Save → Auto-Apply + Auto-Map Standard Situations

User-reported (Oldcustard): "I'm seeing a few instances of followers wearing their default outfit on cell load, this is in a home cell. They don't seem to auto-switch." Log triage on the user's `SeverActionsNative.log` traced the chain to two compounding gaps that share the same root cause — the user had defined preset slots and added items to chests, but never **applied** any preset.

**The two gaps:**

1. **No locked items.** The cell-load enforcement in `OutfitDataStore` only fires for actors that have `lockedItems` set. `lockedItems` are populated when a preset is *applied* (Apply Preset button or the equivalent action), not when it's merely *saved* (chest filled, name registered). Followers with saved-but-never-applied presets had no lock on cell load → engine equipped DefaultOutfit → followers in default attire.
2. **No situation→preset mapping.** `SituationMonitor::SendSituationEvent` reads `outfitStore->GetSituationPreset(actorFormID, sitCopy)`. If the user named their preset "Home" but never separately mapped `home` situation → `Home` preset, this returns empty and the auto-switch silently no-ops. The user reasonably expected naming a preset "Home" to be sufficient.

Both gaps were silent — no log line told the user what was missing. Confirmed by grepping the log for `setSituationPreset` and `Auto-switching` events: zero of either fired in 30 minutes of gameplay despite SituationMonitor correctly detecting `home` transitions for 10 followers.

**Three changes:**

1. **`buildOutfitSavePreset` (`Native/src/PrismaUIActionHandler.h`) → save AND apply.** After the existing save-to-OutfitDataStore step and the `SeverActions_PrismaBuilderSavePreset` ModEvent that registers the preset in the slot system, the action now calls `outfitStore->ApplyPresetNative(actor, presetName)`. Same shared equip+lock+suppress-DefaultOutfit path used by the Apply button and SituationMonitor's auto-switch. Strips current armor, equips new items, locks them, sets active preset, suppresses DefaultOutfit, naked-recovery if equip fails. Builder workflow inherently means "I want to see this on her right now" — there's no longer a split between save and apply for the builder.

2. **New `SeverActions_PrismaBuilderSaveAndApply` ModEvent + Papyrus handler.** Mirrors the existing `OnPrismaBuilderEquip` StorageUtil-sync logic (rebuild lock FormList, set `SeverOutfit_LockActive=1`, track actor, ResumeOutfitLock, restore stashed items) but **preserves the active preset name**. `OnPrismaBuilderEquip` clears it (correct for ad-hoc manual outfits, wrong for named-preset save-and-apply). Without this, StorageUtil's active preset would diverge from the native store's `activePresetName` set by `ApplyPresetNative`. Three sibling handlers now exist: `OnPrismaBuilderEquip` (manual outfit, clears name), `OnPrismaBuilderSaveAndApply` (named preset, preserves name), `OnPrismaBuilderSavePreset` (legacy save-only, unchanged).

3. **Auto-map standard situation names in `buildOutfitSavePreset`.** When a saved preset's normalized name matches a known situation (`home` / `town` / `adventure` / `sleep`) AND no situation→preset mapping exists for that situation yet, the system creates the mapping automatically. Won't override a user's existing mapping (respects intent). Fires the same `SeverActions_PrismaSetSitPreset` ModEvent the explicit mapping action uses, so OutfitSlotStore + StorageUtil stay in sync. Closes the second half of Oldcustard's gap — even with apply working, auto-switch still needed the situation map.

4. **`SituationMonitor` diagnostic trace** (`Native/src/SituationMonitor.h`). When a follower's situation transitions but no preset mapping is configured, the monitor now logs:
   ```
   SituationMonitor: <Name> (FormID) transitioned to '<situation>' but no preset mapping configured — skipping auto-switch
   ```
   Self-debugging breadcrumb so future "auto-switch isn't working" reports trace immediately to the right gap (detection vs mapping vs apply).

**Net user experience after the change:** open builder → pick items → Save with name "Home" → follower is wearing the Home outfit immediately, the lock is committed, the situation map `home → home` is auto-created. Next time they enter a home cell, SituationMonitor fires `Auto-switching <Name> to 'home' for situation 'home'`. No second Apply step, no separate Map Situations step.

### Auto-Assign a Bed When a Home Is Set

User-requested (Kromryl): "Are bed assignments still being looked at? I'm reworking a few things including how homes are assigned, so I could also auto-assign an empty bed for them to actually use (assuming there's any available)."

When `AssignHome(follower, locationName)` runs, the system now scans the player's current cell for a usable bed and sets the follower as its OWNR. The follower's home sandbox sleep package finds the claimed bed at sleep hours and uses it. On `ClearHome` (or re-AssignHome to a new cell, or permanent dismiss via cosave revert), the original owner is restored — no phantom OWNR left behind.

**Bed-claim filter (in priority order):**

| Bed owner | Claim? | Reason |
|---|---|---|
| Unowned | ✅ Claim | Free for the taking |
| Specific named NPC | ❌ Skip | Don't steal personal beds |
| PlayerFaction (`0x000DB1`) | ❌ Skip | Player home — vanilla housecarl/spouse sharing already works |
| Inn faction | ✅ Claim | Per design — assigning an inn as home means renting a bed there |
| Other faction | ✅ Claim | Generic NPC factions, mod-added shared beds |

Preference order when multiple candidates exist: unowned > faction-owned. Less disruptive choice wins.

**Implementation:**

- **`Native/src/BedAssignment.h`** (new, ~200 lines) — `ClaimBedForFollower(follower, cell)`, `ReleaseBedForFollower(follower)`, `FindBestBedInCell(...)`. Bed detection via furniture-keyword check (`FurnitureBedRoll` / `IsBedRoll`) plus an editorID heuristic fallback for modded beds without standard keywords. Releases any previous claim before claiming a new one, so re-AssignHome to a different cell cleanly transfers the OWNR.
- **`Native/src/FollowerDataStore.h`** — `FollowerData` extended with `homeBedFormID` + `homeBedOriginalOwnerFormID`. Cosave bumped from v6 → v7. Both FormIDs go through `ResolveFormID` on load; if either fails (mod uninstalled, ref deleted), the field is reset to 0 — no dangling claim.
- **`Native/src/papyrus.cpp`** — registers `Native_BedAssignment_Claim`, `Native_BedAssignment_Release`, `Native_BedAssignment_GetBedFormID` on the SeverActionsNative script.
- **`SeverActions_FollowerManager.psc::AssignHome`** — calls `Native_BedAssignment_Claim(akActor)` after the home marker is moved to the player's position. Returns false silently if no usable bed is in the cell — follower will sleep on the floor or wherever the home sandbox finds, same as before.
- **`SeverActions_FollowerManager.psc::ClearHome`** — calls `Native_BedAssignment_Release(akActor)` first thing, before clearing home tracking, so the C++ side can read the bed FormID + original owner from FollowerDataStore (which still has the entry at this point) and restore the original OWNR cleanly.

**Track-only followers are NOT excluded.** Initial design proposed skipping custom AI keyword holders (Inigo, Lucien, Kaidan, Daegon-keyworded, etc.) on the theory that their mods manage sleep with custom packages. Reverted on user feedback: "If users assign them a home via my system, they'll have my package, so they should use a bed." If the player explicitly invokes AssignHome on a custom AI follower, they're opting into SeverActions managing that aspect — claim the bed. Worst case for a custom AI follower whose mod still runs its own packages: the bed sits with our OWNR record harmlessly until ClearHome releases it. The release path doesn't gate on track-only either, so no leak risk.

### CompanionWait / CompanionFollow — Track-Only Follower Fix

User-reported (severause): testing the wheel-menu Wait/Resume Follow on a custom AI follower (Daegon, with the SPID `SeverActions_CustomAIFollower` keyword) revealed that the Wait command would correctly sandbox her (via her own mod's package handling), but pressing the wheel button again to resume following would silently force SeverActions's CK alias-based follow package onto her. From that point her own mod's dismiss couldn't remove the package, and SeverActions's Tracking-mode dismiss intentionally doesn't touch packages, so she was stuck.

**Root cause:** `CompanionWait(akActor)` and `CompanionFollow(akActor)` in `SeverActions_FollowerManager.psc` checked `IsRegisteredFollower(akActor)` but NOT `IsTrackOnlyFollower(akActor)`. For a Tracking-mode follower (custom AI keyword present), `IsRegisteredFollower` returns true (she's in the FollowerStore from her Tracking-mode recruit), so the wait path called `followSys.Sandbox(akActor)` and the follow path called `followSys.CompanionStartFollowing(akActor)` — both attaching SeverActions packages on top of her own mod's packages.

The same bug surfaced via three entry points, all of which funneled through these two functions: the LLM picking `companionwait.yaml` / `companionfollow.yaml` actions during dialogue, the wheel menu's `HandleWait` / `HandleFollowToggle`, and the `HandleCompanionWait` hotkey. Single fix covers all.

**Fix:** mirrors the `RegisterFollower` track-only branch — observe-only, no SA package attachment. For track-only followers:

1. **Recovery cleanup first.** Call `followSys.CompanionStopFollowing(akActor, false)` + `followSys.StopSandbox(akActor)`. Both are safe no-ops if no SA state exists; if a prior incorrect call already attached SA's sandbox or alias-based follow package (the bug condition), this releases it. Means existing stuck Daegons recover automatically on the next wheel press — no console workaround needed.
2. **Toggle the vanilla wait flag.** `SetAV("WaitingForPlayer", 1)` for wait, `SetAV("WaitingForPlayer", 0)` for follow, then `EvaluatePackage`. The custom AI follower's own follow package respects this standard flag via the vanilla DialogueFollower hooks, so the follower transitions cleanly between wait and follow behavior under their mod's control.

Vanilla followers are unchanged — they still go through `followSys.Sandbox(akActor)` for wait and `followSys.CompanionStartFollowing(akActor)` for resume, exactly as before.

**Coverage check:** every voice/wheel/hotkey/LLM path that lets the player tell a follower to wait or resume now goes through these two patched functions. No remaining gap where a custom AI follower could pick up an SA package.

---

## v2.9.5

### Key Features

📍 **Cross-Cell Follower Teleport** — Catch-up teleport now actually fires when followers get separated by doors, exterior cell boundaries, and dungeon transitions. Previously the same-cell guard skipped exactly those cases — i.e. the most common "lost follower" scenario.

🩹 **v2.1.7 Aggression Self-Heal** — The reverted-but-not-undone v2.1.7 `AttackTarget` bug stuck the player's `Aggression` actor value at 2, causing nearby Calm-disposition NPCs to flee/cower on sight. v2.9.5 detects and resets it silently on every save load. Affected saves heal themselves the first time you load after installing.

---

### Outfit System Fixes

- **Delete preset preserved blacklisted items** — `ClearPreset` previously called `akActor.UnequipAll()`, which has no filter and stripped blacklisted gear too — directly violating the "never touch blacklisted items" contract. Replaced with a new `UnequipAllExceptBlacklisted` helper that walks worn armor via `Native_Outfit_GetWornArmor`, checks each piece against `Native_Blacklist_IsBlacklisted`, and only unequips non-blacklisted items. Same call site in `ClearPreset`, same observable behavior for non-blacklisted gear, blacklisted items now stay equipped through preset deletion as expected.
- **Outfit Builder rename support** — Pre-fix, renaming a preset in Edit mode orphaned the old name and created a duplicate under the new name with the same items. Full-stack fix: new C++ `OutfitDataStore::RenamePreset` (case-insensitive, preserves items + `activePresetName` + situation-mapping refs, rejects newName collisions), new C++ `OutfitSlotStore::RenamePresetByName` (preserves slot index, container, LvlItem, satchel, item count, catalog-supplied list — all slot-indexed not name-indexed). `buildOutfitSavePreset` action reads an optional `oldPreset` field; if present and CI-different from `preset`, runs the rename in both stores and fires `SeverActions_PrismaBuilderRenamePreset` ModEvent before falling through to the standard save (so item changes also persist under the new name in one click). New `OnPrismaBuilderRenamePreset` Papyrus handler copies the `SeverOutfit_<oldName>_<fid>` FormList to `<newName>_<fid>` and updates the per-actor StringList. Frontend Builder detects rename (CI compare against `editPresetName`) and dispatches with `oldPreset` populated; toast reads "Renamed X to Y" on rename vs. "Saved X" on save.
- **Slot orphan cleanup keeps NPCs with saved presets** — Pre-fix, building a preset on a non-follower NPC via "Save Preset" (not "Equip & Lock") wrote items to `OutfitDataStore` but did not set `lockActive`. The kPostLoadGame `ReleaseOrphanedSlots` pass criteria (`isFollower || hasExplicitLock`) failed for those NPCs, the slot got released on the next save reload, and `presetNames` / `containerFormIDs` were zeroed — while the OutfitDataStore presets (different store, untouched by orphan cleanup) survived. Symptom: PrismaUI page header showed "5 presets" against an empty slot grid, and `applyoutfitpreset` did nothing because the slot system's containers were gone. New `OutfitDataStore::HasPresets(actorID)` method (excludes synthetic `_*` names — same exclusion the UI uses) and the non-follower-lock checker in `main.cpp` now ORs `lockActive` with `HasPresets`. Any NPC the user has built outfits for survives orphan cleanup regardless of whether they were ever Equip-&-Lock'd. Existing already-orphaned saves recover by re-saving the preset; new presets persist correctly going forward.
- **Fuzzy preset name matching** — `FindPresetIndexByName` is now a two-tier ladder. Tier 1: exact CI match (preserves all prior behavior, always preferred). Tier 2: token-overlap fuzzy match — splits the query into whitespace tokens, drops stopwords (`the`, `your`, `for`, `and`, `some`, `something`, `wear`, `put`, `her`, `his`, `their`, `ours`) and tokens shorter than 3 chars, then bidirectional-prefix-checks each query token against each preset token (so `sexy` hits `sexy01`, and `sexy01` hits `sexy`). Multiple candidates → `Utility.RandomInt(0, n-1)` rolls between them. Use cases: naming presets `sexy01`/`sexy02`/`sexy03` and saying "wear something sexy" rolls between them randomly (variety-pack pattern); "wear your office outfit" matches a preset named `office attire` even when the user can't remember the full name. New helpers `TokenizeAndFilter`, `IsFillerToken`, `CountNonEmptyTokens`, `AnyTokenOverlap` live alongside `FindPresetIndexByName` in `SeverActions_OutfitSlot.psc`.

---

### Follower Catch-Up Teleport

- **Cross-cell teleport** — `SandboxManager::ProcessFollowerTeleports` now branches on cell match. Same cell + over distance threshold: existing `SetPosition` path (SMP-safe — 350u behind player's facing, no cell transition, no physics reset). Different cell: `actor->MoveTo(player)` — accepts SMP physics reset (hair/cloak pop) since the 3D was reloading anyway when the follower caught up via vanilla AI. Distance math is meaningless across cells (interiors have their own coordinate space), so the cross-cell branch teleports unconditionally subject to the global cooldown. Pre-fix, the same-cell guard skipped every cross-cell case — exactly the scenarios users actually notice (door transitions, exterior cell boundaries, dungeon-room hops). The same global cooldown (default 30s) gates both paths.
- **Teleport settings persist across game restarts** — Pre-fix, the PrismaUI Teleport Distance slider wrote to PluginConfig but `SandboxManager` never read it back at boot, so the C++ value reset to hardcoded defaults (2000u / 30s) on every restart regardless of what the user had set. The PrismaUI dashboard read from PluginConfig and displayed the saved value, so it *looked* like settings persisted while the actual gating reverted. Fix: new Papyrus property `Int Property TeleportCooldownSeconds = 30 Auto` on `SeverActions_FollowerManager`, new `SandboxManager::SyncFromPluginConfig()` reads `FollowerTeleportDistance` + `TeleportCooldownSeconds` from the FollowerManager script via VM, called via deferred `AddTask` at `kPostLoadGame`/`kNewGame` so script bindings have settled. `PrismaUISettingsHandler` writes the cooldown to Papyrus alongside the in-memory write. `PrismaUIDataGatherer` reads cooldown from Papyrus (single source of truth for restart persistence).

---

### Dialogue Prompt Revision — Three-Pass Overhaul

User feedback: brevity is good but sometimes responses are *too* short — NPCs in 1-on-1 dialogue being asked direct questions were giving 5-word reactions that left nothing to push back against. Triggered a multi-pass review of the two SeverActions dialogue prompts (`0505_severactions_personality.prompt`, `0550_severactions_conversation_flow.prompt`) that ended up substantially expanding both, then reconciling the additions against shipping SkyrimNet base prompts to remove contradictions.

**Pass 1 — Brevity counterweight.** Both dialogue prompts had stacked brevity rules with no counterweight for the engaged-speaker case. Every "GOOD" example in `0505`'s anti-pattern catalog was 0–7 words — correct for the bystander/subordinate/threatened-Jarl framings they were paired with, but the model learned "GOOD = short" with no example of an engaged speaker actually contributing. And `0550` had four cumulative shrink-rules ("people tend to say less, not more," "Don't fixate," "Not everything deserves a response," "give a short closing line and stop") that individually were correct correctives but stacked into universal "say almost nothing" pressure. Added a "When You Are the Engaged Speaker" section to `0505` and a "Brevity vs. Substance" section to `0550`, both using a real failure case from playtesting ("A Dremora. Of course you do.") as the BAD anchor.

**Pass 2 — Codex review (broad).** Ran a 21-item review against both prompts focused on missing dimensions, overlooked anti-patterns, structural critique, and risks in the new additions. Adopted everything:
- **5 new anti-patterns added to `0505`'s catalog**: The Lore Brochure (UESP-style exposition dumps), The Faux-Archaic Filter ("indeed, traveler"-style fantasy varnish on every line), The Player-Centered Orbit (auto-mythologizing the player), The Therapy Voice (modern emotionally-fluent counsellor-speak), The Proper-Noun Drumroll (stacked named entities for trailer-voiceover weight). Each gets a BAD/GOOD pair plus a one-line guidance.
- **Sharpened the omniscience guard** at the top of `0505`: explicit framing that system knowledge (inventory, quests, faction state) shapes attitude but does NOT make the NPC omniscient. Don't reference items the player hasn't shown you, don't quote quest progress they haven't told you about, don't allude to faction membership not mentioned in your presence.
- **Tightened the "ordinary doesn't mean random" rule** to prevent the brevity counterweight from reintroducing aimless chatter.
- **Reformatted narrated-action GOOD examples** (Mutual Threat Stage Direction, Loyal Lieutenant Trope) to spoken-only lines plus parenthetical scene-design explanations — the previous prose-narration examples could leak as output templates.
- **Added a blunter GOOD example** to the engaged-speaker section alongside the writerly one — substance can be polished or rough; both are valid as long as it's not a wall.
- **Compressed the Brevity vs. Substance section in `0550`** to a precedence rule + an explicit definition of "engaged" (directly addressed, directly challenged, responsible for the decision, or uniquely positioned to know — otherwise you're a bystander), plus two guardrails ("don't ask a follow-up every turn — one opinion OR one question is usually enough"; "volunteer related context only if it changes the immediate choice, feeling, or relationship").
- **Narrowed the No Meta-Commentary rule** to OOC turn-management only — in-world boundary-setting ("Keep your private matters private") is now explicitly allowed.
- **Tightened the Overhearing rule** to "Default to silence" with named exceptions (duties, safety, loyalties, reputation), instead of the previous "you may respond once."
- **New "Other Honest Failures" section** in `0550` covering six dimensions the prompts didn't address: Unknowns/uncertainty (NPCs allowed to plainly not know things), Disagreement/refusal (without escalating into a speech), Wrong beliefs (NPCs allowed to be biased/superstitious/mistaken in-character), Humor calibration (dry, brief, situational, not performed for applause), Privacy/taboo/pain (allowed to deflect or end a line), Out-of-world questions (answer from character's frame of reference or reject the premise).

**Pass 3 — Reconcile against shipping SkyrimNet base prompts.** Pulled MinLL/SkyrimNet-GamePlugin's currently shipping `system_head/0010_instructions`, `system_head/0020_format_rules`, `system_head/0400_speech_style_bio`, `guidelines/0500_roleplay_guidelines`, `user_final_instructions/0500_response_format`, `user_final_instructions/0700_extra_instructions`, and `dialogue_response.prompt`, and diffed against our additions. Codex did a second pass on the same comparison. Four contradictions surfaced — all resolved on our side (no SkyrimNet base modifications):

- **Length cap**: SkyrimNet's `0020_format_rules` caps non-combat dialogue at 1-3 sentences (60 words max). Our engaged-speaker GOOD examples were 4-5 sentences. Compressed both examples to ≤3 sentences, ~17-19 words each. Added "say it within the active length limits set by the base format rules" to the engaged-speaker closing instruction so the model doesn't read our "have something to say" as license to ignore base length caps.
- **Narration ban**: Our `0550` line 7 said "you are not writing prose, narrating actions, or describing body language — you are talking." SkyrimNet's `0500_response_format` explicitly allows asterisk-wrapped narration in non-thoughts modes when narration is enabled. Reframed our line from absolute ban to deference: "Default to actual speech, not prose. If the base format rules allow brief narration or asterisk-wrapped action for this render mode, keep it secondary and minimal — speech is the main channel, narration is flavor." The "Stacked Dramatic Chorus" anti-pattern in `0505` is unaffected since that's about excessive narration not banning it.
- **Silence vs. advance**: SkyrimNet's `0500_response_format` ends with "Each response must advance the conversation — new question, detail, realization, or decision." Our `0550` had multiple "default to silence / not everything deserves a response" rules. Two-part reconciliation: (a) added explicit clarifier under "Brevity vs. Substance" that the advance rule applies *to the response you produce* — when our prompt says be silent, the correct output is no response at all, not a manufactured advance to satisfy the rule; (b) tightened the Overhearing line to "Default to silence **when unaddressed**" with an inline note that no-output doesn't conflict with the advance rule.
- **Small talk vs. logical next step**: Our `0505` license to "make small talk that goes nowhere" and "repeat themselves" conflicted with SkyrimNet's "introduce a logical next step." Rewrote the small-talk paragraph to keep the "ordinary is fine" license but bridge to the advance rule: "every generated response turn should still add something — a fresh reaction, a small choice, a relational signal, a redirection. Ordinary doesn't mean random."

**What we deliberately kept.** Codex suggested ultra-compressed GOOD examples ("A Dremora. You said that like weather. Bound, then?" — 9 words, 3 sentences). Within length caps, but we kept the slightly longer versions (~17-19 words, 2-3 sentences) because Codex's compression collapses back into the bystander-brevity register the engaged-speaker section was designed to correct against. Our versions still demonstrate substantive engagement (skepticism, follow-up, push-back) without breaking length caps.

**Architecture is now contradiction-clean.** SkyrimNet base owns length, format, narration mechanics, `<internal_thought>` tags, and the "must advance" rule; SeverActions overrides own voice nuance, anti-patterns, engaged-speaker substance, multi-NPC etiquette, and overhearing scope. Every place our overrides could be misread as overriding base rules now has a deference clause or explicit reconciliation. None of these edits modify base SkyrimNet — all changes stayed on our side.

---

### Player State Healing

- **v2.1.7 player aggression auto-fix** — `SeverActions_Init::Initialize` now reads the player's `Aggression` actor value at the top of every `OnPlayerLoadGame` (and first-time `OnInit`), and resets it to 0 if non-zero. The v2.1.7 `AttackTarget` change had bumped both attacker AND target aggression — when the player was the target, their value got stuck at 2 ("Very Aggressive"), which causes Calm-disposition NPCs to flee/cower on sight. The cause was reverted in v2.1.8 but the corrupted Aggression value persists in saves until something explicitly overwrites it with 0. The reset is gated on `currentAggression > 0.0` so healthy saves are silent (no log spam, no redundant `SetActorValue` call). Affected saves get one diagnostic line: `[SeverActions] Healed corrupted player aggression: X -> 0`. NPCs that already fled may need a cell reload (fast travel out and back, or a few cell transitions) to re-evaluate their AI from the corrected state.

---

## v2.9

### Key Features

👗 **Outfit Slot System (NFF-style)** — Each managed follower gets a dedicated slot with up to 8 named outfit presets. Each preset is backed by a real in-game container so items physically live somewhere instead of just being remembered as FormIDs. Build presets from the PrismaUI catalog, from items the follower already owns, or both — catalog items live in the chest until applied; items the follower already owned stay in their inventory permanently and just equip/unequip between presets. Auto-switches outfits by situation (adventure / town / home / sleep), survives save/load reliably via SKSE cosave (replaces the old StorageUtil string approach), and plays nicely with custom-follower mods that ship their own outfit-enforcement systems.

🪄 **CastSpell Action — Animated NPC Casting** — New action that lets NPCs actually charge and release spells with proper animation, instead of magic appearing from nowhere. The LLM names a spell the NPC knows, optionally picks a target (named actor, "self", or aimed-no-target), and the engine's combat-AI cast pipeline runs the cast through to projectile spawn. Restoration spells auto-repeat until the target is fully healed or the caster runs out of magicka. Up to 4 concurrent casts at once.

🛠️ **Daegon Kaekiri Compat Patch** — Standalone MO2 mod patch (ships separately, not in the FOMOD) that lets the new outfit slot system coexist with Daegon's three-script outfit-enforcement system. Without it her default clothes always come back; with it, presets apply cleanly and her custom outfit container is restored on slot release.

---

### Outfit Slot System — Detail

A wardrobe-based design that replaces the old fight-the-engine unequip-loop pattern.

**How it works**

- Up to **50 followers managed concurrently**, each in their own numbered slot (0-49).
- Each slot has **8 preset bays**, each backed by a baked-in `BGSOutfit` + `LeveledItem` + `ObjectReference` chest container — 400 (slot × preset) triplets in `SeverActions.esp`.
- Apply flow mirrors NFF's `SwitchOutfit`: stow personal items to a satchel, swap the actor's `DefaultOutfit` to the preset's outfit, and let the engine itself enforce the outfit on every cell load. No re-equip loop, no lost races against `DefaultOutfit` rebuilds.
- **Per-item ownership tracking**:
  - **Catalog-supplied items** (added from the UI catalog) live in the chest. A temp copy is issued to the actor on apply, deleted on swap-out.
  - **User-owned items** (already in actor's inventory at build time) stay in inventory. The chest holds a marker only. Equip/unequip between presets, never delete.
  - Mixed presets work — build "Daedric set" from catalog + the actor's existing favorite ring, and the ring stays in their inventory forever.
- **Situation auto-switch** — each slot has a situation→preset map. When `SituationMonitor` flips a follower's situation (adventure → town → home → sleep), the engine auto-applies the matching preset.
- **Scene awareness** — SexLab/OStim animations flip a global flag that suspends all outfit re-equip system-wide, so NPCs don't flicker back into armor mid-scene.
- **Custom-follower compat** — detects guardian outfit containers from mods like `k101Daegon.esp`, stows their contents on apply, restores on slot release. Old system fought these and lost.

**Persistence**

- Cosave record `'OSLT' v3` — assignedActor, presetNames, presetItemCounts, containerFormIDs, originalDefaultOutfit, situationToPresetIdx, guardianContainerIDs, catalogSuppliedItems.
- Transactional load — stages to local containers, commits only on full successful read. Truncated/corrupt cosave returns to clean Revert state instead of half-loading.
- v2 saves load forward-compat with empty catalog lists (treats all items as user-owned, the safer fallback).
- Case-flip defense — Skyrim's `BSFixedString` pool sometimes flips case mid-flow (`"daedric"` → `"DAEDRIC"` after the engine interns an armor keyword). All preset-name comparisons go through a unified C++/Papyrus `NormalizePresetName` (lowercase + trim + strips LLM filler like `" outfit"`/`" gear"`/`" set"`) and `StringUtils::EqualsCI`.

**Ad-hoc actions don't fight presets**

Dress / Undress / EquipItemByName / UnequipItemByName / EquipMultipleItems / UnequipMultipleItems and the PrismaUI Catalog Equip & Lock / Unequip actions all call `ClearActivePresetForAdHoc` first. Without this, the slot system's alias would silently undo the LLM-driven outfit change two seconds later.

**PrismaUI Outfits page**

Now served entirely from C++ via `OutfitSlotStore` and `OutfitDataStore`. Slot index, active preset index, and per-bay name + item count populate directly into the page JSON. Old Papyrus fallback path returned `None` half the time due to script timing — gone.

**Diagnostics**

`DirectEquip` logs PRE-APPLY / POST-APPLY armor counts with a `[delta=N]` flag and emits `WARDROBE PATTERN VIOLATED` to the SKSE log if a non-preset armor leaks in or out, so any regression surfaces immediately.

---

### CastSpell Action — Detail

Drives the engine's combat-AI cast pipeline so NPCs visibly charge and release spells via the same animation path the engine uses in normal combat.

**How it works**

- 4 reusable cast slots (caster + target alias pairs) — up to 4 concurrent casts before the dispatcher reports "too busy".
- Slots own pre-built `UseMagic` AI packages. The package's Spell slot is rewritten at runtime so a single package scaffold can cast any spell the LLM names.
- Each cast clones the source spell into a fresh runtime `SpellItem` (drops perk gates, forces `EitherHand` equip), so Requiem-distributed hand-locked spell variants still cast cleanly via the procedure.
- **Heal-to-full loop** — Restoration spells re-dispatch automatically until the target reaches `GetActorValueMax("Health")` (respects Fortify Health buffs) or the caster runs out of magicka.
- Self-target via the `"self"` keyword; aimed-no-target via an auto-placed XMarker 120 units in front of the caster (lets NPCs fire a spell at training dummies, corpses, or whatever they're looking at).
- Polling state machine on the alias detects animation start, in-flight charge, and stuck-charge recovery — if the engine leaves the caster stuck in `ChargeLoop`, the watchdog force-releases the anim graph via `MLh/MRh_SpellRelease_Event`.

**Eligibility**

Only outside combat (so it doesn't fight existing AI cast logic) and only when the actor isn't currently in a SexLab/OStim animation scene.

**Action params**

- `spellName` — must be a spell the NPC actually knows. Resolved via `SpellDB::FindSpellOnActor` (exact → prefix → contains → Levenshtein) against the actor's known spell list, then routed through their unrestricted variant if one exists.
- `targetName` — display name of an actor, `"self"` for self-cast, or `"0"` / empty for aimed.
- `bDualCasting`, `bHealToFull`, `bUseMagicka` — static parameters set by the action YAML.

---

### Smaller Things

- **ForcedCombatMonitor — AttackTarget auto-cleanup** — new C++ `TESCombatEvent` sink that fires `SeverActions_ForcedCombatEnded` ModEvent the moment a forced-combat actor exits combat. Papyrus then runs `FullCleanup` (restores Confidence, removes attack/target faction, clears StorageUtil keys, clears native InForcedCombat flag). Fixes the lingering-aggressive-state bug where dismissed followers would walk off and re-engage other NPCs because their attack-faction membership and Confidence boost from `AttackTarget` were never reverted on natural combat end (only on explicit Ceasefire/Yield calls).
- **Follower friendly-fire hostility prevention** — four-layer defense against followers attacking each other when one's stray AoE / arrow / cloak / fireball clips the other. **Layer 1 (ESP)**: `SeverActions_FollowerFaction` declares itself Friendly to itself, so the engine treats intra-faction hits as non-hostile at the faction-reaction level. **Layer 2 (Papyrus)**: `RegisterFollower` and Maintenance call `Actor.IgnoreFriendlyHits(true)` on every SeverActions follower so the actor-level flag tells combat AI to ignore friendly-source damage. **Layer 3 (C++ TESHitEvent)**: synchronous 1-HP floor on intra-follower hits + target-aware combat cancel. **Layer 4 (C++ TESCombatEvent)**: catches the case Layers 1-3 miss — hostile-flagged spells (Firebolt etc.) bypass faction friendliness and IgnoreFriendlyHits because the engine routes them through a separate combat-AI scoring path. The new combat-event sink fires at the exact moment the engine flips two followers hostile to each other, then routes through the same `CancelIntraFollowerCombat` guard as the hit path — only stops combat when the actor's CURRENT combat target IS the other follower, so a follower in legitimate combat with a real enemy isn't disrupted by a stray splash from an ally. Skipped entirely when either party is `InForcedCombat` (so deliberate AttackTarget actions still work).
- **CastSpell delivery-type guidance** — expanded the action description and `spellName` / `targetName` parameter docs in `castspell.yaml` to explicitly tell the LLM that self-delivered spells (`Healing`, `Oakflesh`) ignore the target argument and only ever affect the caster. Now when the LLM wants to heal someone other than the caster it picks `Healing Hands` / `Close Wounds` / `Grand Healing` (touch / aimed / AoE), and the cast actually lands on the intended target instead of silently self-casting.
- **Cheaper-model routing for background prompts** — re-added the SkyrimNet plugin manifest at `00 Core/SKSE/Plugins/SkyrimNet/config/plugins/SeverActions/manifest.yaml` declaring a single `sever_background` LLM variant. All six of our background `SendCustomPromptToLLM` calls (relationship assessment, reputation blurb, inter-follower opinions, banter director, off-screen life, quest awareness summaries) now route through that variant. Configure it from SkyrimNet's WebUI → Plugins page — set a custom endpoint / API key / model / temperature / max tokens / timeout to point all six prompts at a cheaper or local model and save tokens on the dialogue tier; leave it empty to inherit your base OpenRouter config (no behavior change). Live dialogue is unaffected — it still uses your main model.
- **`StopFollowing` action casing fix** — `stopfollowing.yaml` had `executionFunctionName: stopfollowing` while the Papyrus function is `StopFollowing`. Papyrus is case-insensitive at runtime so manual paths (hotkey, wheel, GameDataExplorer) worked, but SkyrimNet's `QuestScriptManager` does case-sensitive symbol lookup against the VM's function table — so any LLM-driven invocation reported `function does not exist` and the action silently failed. YAML now matches the script casing.
- **Arrest aggression/confidence restore** — `PerformArrest` and `ApplyDispatchArrestEffects` now snapshot the prisoner's pre-arrest Aggression and Confidence before zeroing them. Release paths (`ReleaseFromJailCore`, `ReleasePrisoner`) call a new `RestorePrisonerStats` helper that puts the originals back via `SetAV`. Previously the release path used `RestoreAV("Aggression", 100)` which was the wrong API for a base attribute and silently did nothing — bandits walked out of jail permanently pacified, hostile NPCs walked out friendly to everyone. Also dropped the redundant `Aggression=2` bump on guards in `HandleResistArrest` (vanilla guards baseline at 1 and `StartCombat` is sufficient; the bump risked persistence on abnormal combat-end).
- **PrismaUI Outfits page wired to slot system** — slot index, active preset, and the 8 named preset bays now populate directly from `OutfitSlotStore` in C++ (~5-20 ms vs the broken Papyrus fallback's variable latency).
- **Spookys CLI outfit-slot generator** — `scripts/generate_outfit_slots.ps1` builds the 50 × 8 preset records on `SeverActions.esp` deterministically. Replaces the xEdit script for record-creation reliability.
- **Action selector prompt** — clarified the "category vs direct action" rules and added an explicit example response line so the LLM consistently includes the required `intent` parameter when picking a category.
- **Magic category description** — updated to mention casting alongside teach / learn.
- **`.gitignore`** — excludes `*.bak.*` timestamped ESP backups and `.claude/scheduled_tasks.lock` so they stop showing as untracked.

---

## v2.7.0

### Key Features

🛡️ **Possible Cowering Fix** — A few overlapping issues that could contribute to followers or random NPCs cowering during combat have been addressed. Not a guaranteed fix since the symptom has multiple paths in the engine, but the known contributors on our side are now cleaned up.

🧠 **Familiarity Cleanup** — World knowledge about you (lore entries, witnessed events, seeded facts) now appears exactly once in every dialogue prompt instead of twice. NPCs still know everything they knew before, the LLM just stops getting the same facts double-fed and over-weighting them in responses.

💬 **Prompt Stack Simplified** — Trimmed our SkyrimNet prompt overrides down to only what's needed for SeverActions' own action pipeline. The COMPANION / ENGAGED / IN SCENE tag logic now lives in an additive submodule that extends the speaker selector instead of replacing it — your MCM/PrismaUI toggles for those tags still work identically.

🔧 **PrismaUI Survival Page Fix** — The Cold settings box on the Survival page was clipping off the right edge of the three-column grid, hiding its Enabled toggle. CSS updated so Hunger / Fatigue / Cold all fit cleanly within the viewport regardless of window size.

📦 **FOMOD Installer Fix** — The installer's `Enhanced Target Selectors` option still referenced the `Prompts/TargetSelectors` folder after both prompts inside it were removed during the prompt-stack simplification. Mod managers reported a "folder not found" warning at install time. The dead option has been removed from `ModuleConfig.xml` and the empty folder pruned; installation is now clean.

See the `v2.5` section below for the detailed technical breakdown of the cowering hunt, familiarity dedup, and prompt-stack cleanup changes that ship in this release.

## v2.5

### Cowering Regression Hunt — Multi-Layer Fix
Users reported NPCs (including followers during fights) randomly cowering starting with v2.1.7. The issue persisted in v2.5 despite the 2.1.7 AIO-patch rebuild, so the root cause wasn't just one thing. A deep audit of the ESP, AIO patch, and combat script against user-reported symptoms found three independent contributors, each addressed below.

- **AIO patch rebuilt against the user's actual AI Overhaul ESP** — previous patch was generated against a different AIO variant (author `mnikjom SpiderAkiraC`, different file size). It contained two "ghost" override records (`AIOFleeSeverinFamily` at `59720E` and `AIOFleeFromDragons` at `5CED5E`) that didn't exist in the user's installed AIO, so those overrides were injecting orphan records rather than overriding anything. Also lost a condition on `AIOFleeFromCreatures` (our source had 7 OR-flagged creature conditions, LoreRim's has 8). Spec file (`xEdit Scripts/aio-severactions-patch.psd1`) now points at LoreRim's AIO and declares only the 5 records that exist across AIO variants. Patch size: 7991 → 4653 bytes
- **V2 follow template (`SeverActions_FollowPlayerTemplate`, FormID `155C91`) condition refs repaired** — the `b4717ab` commit cloned NFF's 27-entry procedure tree (Close/Standard/Far radii + Flee sub-procedure) but didn't remaster the FormID references inside the CTDA condition blocks. 1 GLOB comparison-value ref and 8 FACT parameter-1 refs pointed at FormIDs that don't exist in `SeverActions.esp` (they were NFF local IDs pasted as self-references). At runtime those conditions evaluated unpredictably, which could fire the Flee sub-procedure on followers during combat. Mapped to SeverActions equivalents via a new binary-patch script `xEdit Scripts/patch-v2-follow-conditions.ps1`: GLOB `0x030F5D30` → new `SeverActions_FleeDistance` (Float, value 12.0, matches NFF's `nwsFleeDistance`); FACT `0x03004352` → existing `SeverActions_FollowerFaction` (`0EB708`)
- **2.1.7 Confidence/Aggression changes reverted** — the 2.1.7 addition of `Aggression=2` in `PrepareForCombat` + `StoreOriginalValues(akTarget)` + `PrepareForCombat(akTarget)` was intended to fix "civilians don't fight back when attacked" but introduced the possibility of stuck elevated Aggression values when combat terminates abnormally. Reverted to pre-2.1.7 behavior: `PrepareForCombat` only sets Confidence=3 on the attacker; `AttackTarget_Execute` no longer value-manipulates the target (`StartCombat` + relationship rank -4 is sufficient); `StoreOriginalValues`/`RestoreOriginalValues` only track Confidence. Ceasefire/yield aggression paths are pre-existing pre-2.1.7 logic, left untouched
- **Kept (unrelated to the revert)** — `SeverActions_AttackFaction` / `SeverActions_TargetFaction` property declarations and add/remove logic. The AIO flee-suppression patch gates on these factions to turn off flee packages for in-combat actors; they must remain toggled around forced-combat windows
- **Known tradeoff from the revert** — Cowardly NPCs (Confidence=0 base) and Unaggressive NPCs (Aggression=0 base) may no longer fight back when `AttackTarget` is used on them. If reported, a per-action opt-in or a separate "forced combat intensity" setting can restore it

### ESP Structural Cleanup
- **Persistent flag set on 120 schedule-system XMarkers** — 40 home + 40 work + 40 relax markers added in the schedule-system commit (`eabf3c3`) were placed in `GRUP Cell Persistent Children` groups without the Persistent flag (xEdit integrity warning on every one). Engine was lenient at runtime but save/load edge cases could misbehave. New idempotent binary-patch script `xEdit Scripts/set-persistent-flag.ps1` walks the ESP, locates every `REFR`/`ACHR` under a type-8 GRUP, and OR's the `0x400` bit into its flags field (record layout unchanged, no size shifts). 172/172 REFRs now correctly flagged
- **5 orphan records deleted** — all confirmed unreferenced in scripts, native code, or other records: `nwsFollowerFollowPKGDUPLICATE001` (`155C92`), `nwsFollowerFollowPTDUPLICATE001` (`155C90`), `SeverActions_UseMagicPackage` (`020E4F`), `SkyrimNet_FollowPlayerPackage` (`000E8E`), `SkyrimNet_FollowPlayerPackageTemplate` (`000E8D`). Saved ~10.9 KB on the ESP and removed xEdit integrity noise
- **Master list reorder** — Mutagen (the spookys-automod backend) had alphabetized masters on a prior toolkit pass, putting `Skyrim.esm` at index 2 instead of 0. Manually reordered in xEdit back to conventional order (`Skyrim.esm` first). Also confirmed that `Update.esm` and `HearthFires.esm` — which Mutagen stripped as "unreferenced" — genuinely weren't referenced by any internal FormID in the ESP, so their removal is structurally clean. The `HearthFires.esm` references in `Native/src/NearbySearch.h`, `PropertyOwnership.h`, and `RecipeDB.h` resolve at runtime via SKSE's `LookupForm<T>(formID, pluginName)` and don't need master entries
- **New `SeverActions_FleeDistance` Global** — added (`155D0F`, Float, value 12.0) to support the V2 follow template fix

### Prompt Stack — Override Cleanup + Additive Submodule
In preparation for SkyrimNet's upcoming prompt refactor, trimmed the set of SkyrimNet-base prompt overrides to only the three that actually need to be overridden (action-pipeline adapters). The remaining eight overrides' 2.1.7/2.2/2.5-era fixes targeted specific bugs in old SkyrimNet prompt versions that the refactored base will handle natively; keeping stale overrides after their refactor would lock us to worse logic than upstream.

- **Removed 8 override prompts**:
  - `dialogue_response.prompt` (DialogueStyle) — listener framing / third-person narration fix, superseded
  - `submodules/system_head/0010_instructions.prompt` (DialogueStyle) — listener framing across render modes, superseded
  - `submodules/system_head/0010_setting.prompt` (DialogueStyle) — world-framing override that hard-coded vanilla Skyrim lore, fighting conversion mods like Enderal; let SkyrimNet handle this default
  - `submodules/system_head/0020_format_rules.prompt` (DialogueStyle) — word/sentence caps per render mode, superseded
  - `submodules/system_head/0400_roleplay_guidelines.prompt` (DialogueStyle) — narration gating, superseded
  - `submodules/guidelines/0900_response_format.prompt` (DialogueStyle) — format rules / narration escape hatch, superseded
  - `target_selectors/dialogue_speaker_selector.prompt` (TargetSelectors) — replaced by the new additive submodule below
  - `target_selectors/player_dialogue_target_selector.prompt` (TargetSelectors) — superseded by SkyrimNet's updated target selector
- **Kept 3 intentional overrides** (Core, action-pipeline): `native_action_selector.prompt`, `native_action_selector_drilldown.prompt`, `submodules/user_final_instructions/0750_embedded_actions.prompt`. These directly orchestrate SeverActions' custom YAML actions and must stay in sync with our action schema; will be diffed and re-ported when SkyrimNet refactors them
- ~~**New additive submodule — `submodules/character_bio/0311_severactions_interject_hints.prompt`**~~ — staged in early v3.5 then **reverted before ship** (pending design changes; full PR #145). The previous `dialogue_speaker_selector` override behavior currently has no SeverActions replacement and will be revisited.
- **Group Meeting Awareness rewritten on SkyrimNet primitives** — `0260_severactions_engaged_participants.prompt` no longer depends on the `SeverActions_ActivelyFollowing` faction. Party detection now uses `is_follower(uuid)` + `is_in_package(uuid, "SkyrimNet_PlayerFollowPackage")` from SkyrimNet's own decorators (requires SkyrimNet build with [MinLL/SkyrimNet#807](https://github.com/MinLL/SkyrimNet/pull/807) merged for the new `is_in_package` / `get_speaker_selector_settings` surface). Tag vocabulary now mirrors upstream's `dialogue_speaker_selector.prompt`: `[COMPANION]` / `[ENGAGED]` / `[IN SCENE]` so the LLM sees one consistent ontology across selector and per-NPC system_head renders. In-scene party members surface in a dedicated sub-list with explicit "do not address" guidance (mirrors upstream "Strongly deprioritize"). Player-in-scene case handled. Block gates on the dashboard's `dialogue.speakerSelector.tagEngaged` toggle so global preferences carry through.
- **DialogueStyle FOMOD module is now purely additive** — contains only `submodules/guidelines/0550_severactions_conversation_flow.prompt` and `submodules/system_head/0505_severactions_personality.prompt`, both SeverActions-original content

### Familiarity Prompt — World Knowledge Deduplication
- **Removed `get_world_knowledge` call from `0045_severactions_familiarity.prompt`** — SkyrimNet's own conditional-knowledge prompt already injects world knowledge per-character in the LLM context, and our familiarity prompt was rendering it a second time. Net effect was the same facts appearing twice in every dialogue prompt, bloating token count and (based on anecdotal reports) causing LLMs to over-weight those facts in their responses
- **Preserved in `sever_reputation_assess.prompt`** — the per-NPC impression blurb is still generated with `get_world_knowledge(npcUUID)` + `get_relevant_memories(3)` + prior blurb as raw material, so everything an NPC "knows" still gets distilled into their personal take. Live dialogue renders only the distilled blurb; the raw world-knowledge facts come through once via SkyrimNet's own path
- **Net effect**: each piece of world knowledge appears exactly once in the LLM context per dialogue — once as raw facts (via SkyrimNet's conditional-knowledge injection) and indirectly shaped into the NPC's blurb (interpretive). No more duplication

### Follower Friendly-Fire Prevention (New)
Opt-out toggle on the PrismaUI Settings page (default **ON**) that prevents follower-vs-follower combat from escalating. Three cooperating layers address the three ways friendly fire bleeds through Skyrim's vanilla protections.

- **Ally-hit aggro thresholds raised** — Skyrim's `iAllyHitCombatAllowed` (default 3) and `iAllyHitNonCombatAllowed` (default 0) game settings count hits from "friend" actors before flipping target aggression. Raised to 100 / 50 when the toggle is on, restored to defaults when off. Applied on toggle change and re-applied on game load from Maintenance (game settings aren't cosaved). Side effect: bandit-on-bandit aggro also takes longer, which is invisible in practice
- **Periodic `IgnoreFriendlyHits(true)` refresh** — the flag we already set on recruit can drop during AI state transitions (combat↔sandbox, dismiss/recruit, save/load edge cases). New `RefreshFriendlyFireFlags()` iterates `GetAllFollowers()` every 30s in the existing OnUpdate tick and re-stamps the flag. No-op when toggle is off
- **HP-floor damage refund** — new C++ `FriendlyFireMonitor` singleton (TESHitEvent sink) catches every hit and, when both aggressor and target are in `SeverActions_FollowerFaction`, clamps the target's post-hit HP at a minimum of 1. Damage still applies (bleedout/stagger visuals preserved), but allies can't outright kill each other. Synchronous with the event handler so the floor lands in the same frame as the damage. Covers AoE spells, stray arrows, cloak procs, and other cases where the `IgnoreFriendlyHits` flag fails. Engine caveat: true one-shot kills where damage brings HP to exactly 0 can still trigger the engine's death state before our floor applies — the 1-HP floor catches the common case but isn't a hard guarantee without a perk or SKSE damage hook
- **Defaults-on for new installs, explicit off preserved for opt-outs** — StorageUtil default is `1`. Users who never touched the setting get protection; users who explicitly toggled it off keep their `0`
- **Files**: new `Native/src/FriendlyFireMonitor.h`, plugin/papyrus wiring in `plugin.cpp` / `papyrus.cpp`, settings handler + data gatherer hooks, `FriendlyFireMonitor_SetEnabled` / `_IsEnabled` natives in `SeverActionsNative.psc`, `OnFriendlyFireToggle` event + Maintenance restore in `SeverActions_Follow.psc`, `RefreshFriendlyFireFlags()` in `SeverActions_FollowerManager.psc`

### Outfit Builder Overhaul
- **Full biped-slot coverage** — the builder now exposes every Skyrim slot 30 through 60 (bits 0-30), up from 18 slots. Items on modded slots like Mouth (44), Misc (48), Leg (53), Leg 2 (54), Chest 2 (56), Shoulder (57), Arm (58), Arm 2 (59), FX01 (60) are now reachable. `ArmorCatalog::SlotMaskToString` and the "Currently Worn" labeler in `getWornArmor` both expanded to name these slots; previously anything outside bits 0-13 / 15-17 / 19 displayed as "Other" or an empty "None"
- **"All Slots" button at the top of the slot grid, selected by default on open** — the builder now jumps straight into browsing every playable armor the moment it opens. Select an item and it gets keyed by its own `slotMask` (not a fixed button mask), with automatic conflict resolution: picking a new item drops any previously selected item whose slot bits overlap, so the preview panel stays accurate without double-equip states
- **Specific-slot grid is collapsed by default** — a dashed "▼ Show specific slots" toggle below "All Slots" reveals the full 30-button grid for fine-tuning. State resets to collapsed every time the menu closes (React unmount), matching the intended "advanced UI stays hidden" UX
- **Pelvis 2 (biped slot 52) hidden everywhere** — slot used by NSFW genital/underwear body mods (SoS, CBPC, etc.) that users shouldn't need to manage from here. Filtered out of: the builder slot grid, catalog search results (`QueryArmor` server-side skip), and the Currently Worn panel. The Undress action still strips slot 52 intentionally
- **Undress action expanded from 18 → 26 slots** — now strips the newly-labeled slots 44 / 48 / 53 / 54 / 56 / 58 / 59 / 60 along with everything it stripped before. Addresses a user-reported bug where gear on slots 53, 54, and 58 wouldn't come off with the dress/undress actions. Intentional exclusions preserved: slots 31 (Hair), 38 (Calves), 41 (LongHair) to protect wigs, and 50 / 51 (decapitation FX) since they're not real gear

### Dialogue Prompts — Consolidation
Rolled up user feedback about length rules stacking and redundant guidance accumulating across multiple prompts. All dialogue-pipeline prompts now have a single source of truth for each rule type.

- **New `0020_format_rules.prompt` override** (DialogueStyle FOMOD). Owns sentence/word caps for every render mode: combat (1 sentence, 14 words), dialogue (1-3 sentences, 60 words), thoughts (8-30 words), book (8-90), transform (8-45). All other SeverActions prompts stripped of their own length declarations
- **`0400_roleplay_guidelines.prompt` trimmed** — removed the "max 2-3 sentences" clause (→ moved to 0020) and the entire `inDirectConversation` narration block (→ 0900 handles it with richer examples). 0400 is now purely character-voice roleplay per render_mode, 67 → 44 lines
- **`0550_severactions_conversation_flow.prompt` slimmed** — from 7 pillars down to 5. Removed "Vary your rhythm" and "You don't always know what to say" (LLMs do these without instruction), "One thing at a time" (conflicts with per-character `speech_style` blocks; some characters genuinely stack thoughts), and "Don't narrate yourself" (→ 0900 owns narration gating). Sharpened **When to Stop** into a bulleted trigger list plus an explicit closing-line instruction — silence after a closing line is now explicitly labeled correct behavior, not a failure to respond
- **`0900_response_format.prompt`** — removed redundant "Speak in your natural voice, respond with your own thoughts" and "Do not echo what was said" lines (→ kept only in 0550). 0900 now strictly governs FORMAT (narration, asterisks, structure); 0550 owns CONTENT mechanics
- **`0260_severactions_engaged_participants.prompt`** (Follower copy; the GroupMeeting copy was removed entirely in PR #145) — stripped "1 sentence most of the time" / "1-2 sentences" / "2-3 sentences" clauses. 0260 keeps group-scene framing only ("not performing a scene", "Use names sparingly", "comfortable silence is valid"); length is 0020's job
- **`0600_severactions_dialogue_rules.prompt` deleted** — rule was "don't echo system/action text like `[item_given]`, gold totals, etc." Redundant with 0900's "Do not describe yourself, target, or anyone else — say it as speech or not at all" and modern LLMs rarely leak system text without prompting. Removed from repo, MO2, live, and zip

### Relationship Assessment — Event Leak Fix
- **Removed 3 `SkyrimNetApi.RegisterEvent` calls** in `SeverActions_FollowerManager.psc` (lines near 2813 / 3214 / 5376) that were writing mechanics text like `"Feris relationship assessed: rapport +3 trust +1"` and `"X inter-follower: Y(aff+2 res-1)"` directly into SkyrimNet's event stream. `get_recent_events` was surfacing those strings to the diary/memory LLM, which produced gameplay-meta entries like *"Feris's rapport went up after the armor. Uthgerd's went down."* in player diaries. Deleting the event writes stops the leak at the source. The in-character `SeverFollower_PlayerBlurb` and per-pair blurb storage paths are untouched — narrative-facing outputs still flow normally

### AI Overhaul Patch — Byte-Perfect Rebuild
- **`AIO-SeverActions-Patch.esp` rebuilt from scratch** via a new binary patcher script. The previous SeverForge-generated patch triggered an xEdit "Target is not persistent" warning because SeverForge (Mutagen-based) wrote masters in a non-standard order (Dawnguard → Dragonborn → Skyrim) and re-sorted the authored ANAM/UNAM data entries alphabetically by tag. The new patch copies the original AI Overhaul.esp flee packages byte-for-byte, translates FormID master indices to a standard-ordered master list (Skyrim → Dawnguard → Dragonborn → AI Overhaul → SeverActions), and appends our 3 `GetInFaction == 0` AND conditions at the end of each package's CTDA block. ESL flag / author / description preserved. xEdit Check-for-Errors now passes clean
- **Two underlying bug fixes carried over from the earlier SeverForge patch** (both already shipped in commit `4d23e4f`, re-verified in the rebuild): (1) third faction condition now references `SeverActions_TargetFaction` (0x150B8F), not the legacy unused `SeverActions_VictimFaction` (0x150B8E); (2) our AND conditions placed AFTER the original OR-chained creature/dragon checks, not before — prepending caused the first original OR-flagged condition to absorb our last AND into its OR group and evaluate as always-true, which had nuked the creature-detection gate entirely and caused merchants to cower constantly while IntelEngine-dispatched followers got stuck mid-travel
- **New `xEdit Scripts/esp-rebuild.ps1` + spec-file pattern** — reusable PowerShell library for byte-perfect ESP override patches. Takes a `.psd1` spec describing source ESP, output path, master list, TES4 metadata, and conditions to append per record. Drop-in build for the AIO case (`aio-severactions-patch.psd1`) reproduces the current patch byte-identically. README in `xEdit Scripts/` documents spec schema and current limitations (PACK records only, conditions always appended at end). Alternative to patching SeverForge upstream — gives byte-exact output for cases where Mutagen's canonicalization is the problem

### Action YAMLs — Mass Updates
- **SexLab / OStim faction checks converted from `is_in_faction` to `get_faction_rank < 0` across 62 action YAMLs** (124 condition blocks). `SexLabAnimatingFaction` and `OStimExcitementFaction` sometimes leave NPCs stuck at faction rank -1 after animations end (a "disabled" sentinel). `is_in_faction` treats rank -1 as true (still in the faction), which wrongly blocks actions for every NPC caught in that state. `get_faction_rank < 0` correctly treats both "not in faction" and "stuck at -1" as eligible, while rank ≥ 0 (actively animating) still fails the check. Fixes a class of bugs where dismissed-follower actions would stay gated even after the animation ended
- **Action-name casing fixes** — `companionfollow.yaml` (kept `CompanionFollow`), `learnspell.yaml` → lowercase `learnspell`, `stopfollowing.yaml` → lowercase `stopfollowing`. SkyrimNet's `RegisterPapyrusQuestActionInternal` function-info lookup appears to be case-sensitive per-action (not uniformly lowercase as the previous "action casing" commit assumed), and the right casing varies per-action based on load-order timing. Settled on empirical testing results: whatever case stopped the `PapyrusQuestAction: Could not get function info` log error for each specific YAML

### Immersion Triggers — Archived (pending revamp)
- **`Triggers/Immersion/` removed from the FOMOD** and moved to `archive/immersion-triggers/SKSE-tree/` for future revamp. The 12 event-driven triggers (Dragon Slain, Player Near Death, Companion Injured, Quest Completed, New City Arrival, Dungeon Entered, Night Travel, Player Commits Crime, Witnessed Crime, Powerful Enemy Slain, Player Uses Shout, Major Quest Diary) weren't where they needed to be for the next ship and are being pulled for a redesign pass. ModuleConfig.xml's "Trigger Modules (Event Reactions)" install step removed and Compatibility Patches / Adult Content pages renumbered. Archive README documents what was there and how to restore if needed

### Build & Tooling
- **`build_fomod_zip.ps1` excludes `*.bak` and `*.bak.*` files** — timestamped ESP backups produced by `esp`/patch tools were accidentally shipping in the FOMOD zip. Added to `$excludePatterns`. Zip dropped ~160 KB and got cleaner without losing anything the user needs

### Follower Schedule System (New)
Dismissed followers now follow a daily schedule, moving between home, work, and relax locations based on the in-game clock.

**Schedule hours (12-hour):**
- **Home** — 10:00 PM to 8:00 AM. Sandboxes at the assigned home; sleep triggers naturally via the existing `AllowSleeping` flag
- **Work** — 8:00 AM to 5:00 PM. Sandboxes at the player-assigned work location
- **Relax** — 5:00 PM to 10:00 PM. Sandboxes at the player-assigned relax location

**Design:**
- **No new packages, no new factions, no new CTDAs** — reuses the existing per-slot `HomeSandbox_NN` alias system. A background tick moves the follower's `HomeMarker_NN` between three anchor markers (`TrueHomeAnchor_NN`, `WorkMarker_NN`, `PlayMarker_NN`) at 8am / 5pm / 10pm boundaries. The HomeSandbox package keeps targeting HomeMarker — follower re-paths automatically with the same radius (1000) and flags (AllowSleeping, AllowSitting, AllowEating, AllowConversation, AllowIdleMarkers)
- **Work and relax are opt-in** — if no work location is set, the follower stays home during work hours (falls through to the home anchor). Same for relax. Followers without schedule data keep behaving exactly as they did in v2.2
- **Automatic migration for existing saves** — `TrueHomeAnchor_NN` syncs to the current HomeMarker position on first tick, so existing dismissed followers don't teleport when updating

**New PrismaUI ModEvents:**
- `SeverActions_PrismaSetWorkLoc` / `ClearWorkLoc` — assign or clear the follower's work location
- `SeverActions_PrismaSetPlayLoc` / `ClearPlayLoc` — same for play

**Technical:**
- 3 new FormLists (`WorkMarkerList`, `PlayMarkerList`, `TrueHomeAnchorList`) + 120 XMarkers (40 each) in the holding cell
- Schedule logic runs in Papyrus (`ProcessScheduleSwaps` called every 30s in the existing OnUpdate loop) — only teleports when the schedule type actually transitions
- Tunable hours via `SCHEDULE_WORK_START`/`_END` and `SCHEDULE_PLAY_START`/`_END` constants

### Follow Behavior
- **V2 tiered follow package** — replaced the vanilla single-radius follow template with an NFF-style procedure tree containing Close / Standard / Far radii + a Flee sub-procedure. Fixes the "backward teleport" snapping where followers would jerkily reposition when the player moved just outside the old template's single radius
- New `SeverActions_FollowPlayerTemplate` (27-entry procedure tree) and `SeverActions_FollowPlayerPackageV2` — attached to all 20 `FollowerSlot` aliases. The V2 condition preserves V1's contract (`GetActorValue("WaitingForPlayer") == 0`) so followers still respect the wait/sandbox state. V1 package kept in the ESP for rollback safety, detached from aliases

### PrismaUI
- **Fixed spell toggles not working for follower spells** — toggling a spell off for a follower used to snap back to "active" on the next UI refresh. Root cause: `HasSpell()` returns true for spells on the base NPC record even after `RemoveSpell()`, because the base spell list is immutable — only the runtime `addedSpells` list is modified. Player spells worked fine because they're mostly runtime-added (learned in-game)
- Fix: `BuildInventoryData` now cross-references the `disabledSpells` set from `FollowerDataStore` when computing the active flag. If a spell is in the disabled set, it reports inactive regardless of `HasSpell()`. Applies to both runtime `addedSpells` and base-record spell paths
- **New "Transfer Ownership" action on the Actions page** — wires the existing `TransferOwnership` action (previously only reachable via LLM dispatch / YAML) into a new `Property` action category on the PrismaUI Actions page. Target is the NPC giving ownership; the single text param is the property name (leave blank to default to the NPC's current location). Uses the shared-faction co-ownership path — both the player and the original owner retain access to beds, containers, and the home, so the giver doesn't lose their own place

### User Experience
- **Streamlined Companions page** — inline "Set Here" / "Clear" buttons next to each Home/Work/Relax row replace the crowded bottom button bar. Rare/destructive actions (Clear Packages, Soft Reset, Force Remove) moved to an overflow `⋮` menu. Same inline pattern applied to the Assigned NPCs section for consistency
- **Pause on Open toggle** — new entry in the Settings page's UI Display section: "Pause Game When Menu Opens" (default on, preserves legacy). When off, gameplay continues while the menu is open and Summon fires immediately instead of queuing until menu close
- **Summon + schedule config for dismissed followers** — the Assigned NPCs section (where dismissed homed followers live) now exposes a Summon button alongside the full Home/Work/Relax schedule config. No need to physically find a dismissed follower to reconfigure their routine or pull them to you
- **"Play" renamed to "Relax"** — clearer labeling for the 5pm–10pm leisure window on the Companions page. Internal references, save data, and ModEvent names untouched — pure display rename

### Dialogue Quality — SkyrimNet overrides
Three prompts from SkyrimNet's core dialogue pipeline are now shipped as SeverActions-side overrides (installed via the `DialogueStyle` FOMOD module at the same relative paths SkyrimNet uses — install SeverActions below SkyrimNet in MO2 to win the overwrite). Fixes NPCs producing third-person narration inside their dialogue turns (e.g. `"Dunmer merchant. Doesn't look like she's in the mood for small talk."` said as a reply *to* the Dunmer) and generic parrot-agreement patterns (`"She's not wrong." / "Aye, that's true."`).

- **`dialogue_response.prompt`** — strengthened listener framing. Adds a dedicated paragraph immediately after the speaker identity: *"You are speaking DIRECTLY TO X. Every word you produce is heard by X. Address them — do not describe them. You are IN A CONVERSATION, not narrating one."* Also appends a final-line reminder at the end of the user block: *"Your response will be HEARD BY X — speak TO them, not ABOUT them."*
- **`submodules/system_head/0010_instructions.prompt`** — unifies the listener-framing gates across `default` and `transform` render modes (the original only framed the listener in the default-dialogue branch, leaving `transform`-mode outputs without listener awareness). Replaces `"You are speaking to X"` with the directional `"Respond as Y, speaking directly to X. Your output is addressed to X and heard by them. Speak TO them; do not describe them."`
- **`submodules/system_head/0400_roleplay_guidelines.prompt`** — when a `responseTarget` is set (i.e. NPC is in a direct conversation), narration is forced OFF regardless of the user's `is_narration_enabled()` setting. Adds concrete BAD/PREFER examples in the rule block so the LLM can pattern-match against the actual failure mode. The narration-permit path still renders normally for ambient reactions and other non-conversation contexts
- **`submodules/guidelines/0900_response_format.prompt`** — closed the narration escape hatch that 0400 alone didn't catch. This prompt renders late in the stack and previously taught a 1-in-4 narration ratio plus a worked example (`"Hello." *she smiles.* "How are you?"`) that the LLM was pattern-matching even when 0400 forbade narration. Override applies the same `responseTarget` gate: in direct conversation, narration off; otherwise SkyrimNet's ambient rules unchanged
- **`submodules/guidelines/0600_severactions_dialogue_rules.prompt`** (adopted into tree) — this file prevents NPCs from echoing system/action text in dialogue (`"Hulda gave Bread to Aevar. That's the only loaf I've got whole."`). It was already shipped in some installs but orphaned from version control; now tracked as a proper SeverActions prompt
- **`submodules/system_head/0010_setting.prompt`** — strengthened the "Character Knowledge" block to match the v2.5 familiarity rework. Enumerates the four legitimate channels for an NPC to know something about the player (direct encounter, witnessed events, world-knowledge entries, memories) and explicitly rules out auto-knowing titles like Dragonborn, Harbinger, Arch-Mage, Listener, or Guild Master unless one of those channels delivered it
- Zero changes to SeverActions' own `DialogueStyle` prompts (`0550_severactions_conversation_flow.prompt`, `0505_severactions_personality.prompt`) — those were already correct; the issue was upstream-SkyrimNet rules contradicting them

### Dialogue Target Resolution
- **Speaker selector pivot rules** — expanded the targeting-rules block in `target_selectors/dialogue_speaker_selector.prompt` to explicitly permit NPCs pivoting their target back to the player after a brief NPC-to-NPC side-exchange. Previously the rule said only *"if two NPCs are mid-conversation, keep the target between them"* — which correctly preserves NPC-to-NPC flow but also suppressed legitimate pivots when an NPC's next line was actually directed at the player. New rules: NPC-to-NPC exchanges wind down after 2-3 back-and-forths; a speaker can pivot to `player` when the speaker's reason to speak is player-focused (reacting to player action, answering a prior player question, pulling player attention to something); output must always specify a target explicitly (`[speaker]>[target]`) — never output `[speaker]>` with nothing after, never leave the target ambiguous. Partially mitigates (but does not fully fix) a separate root-cause bug in SkyrimNet's `DialogueManager.cpp::GenerateResponse()` fallback where stale event `targetActorUUID` wins when the parsed target is incomplete. Proper fix requires an upstream SkyrimNet C++ patch

### Familiarity & Reputation
- **Removed hardcoded quest/guild fame** — the familiarity prompt no longer bakes in player guild progression (Harbinger, Arch-Mage, Guild Master, Listener), Main Quest milestones (High Hrothgar, Alduin, Dragonborn DLC), or quest-stage-driven knowledge gates. Facts about the player now reach NPCs **only** through three legitimate channels: entries authored in SkyrimNet's knowledge system (PrismaUI World page), memories an NPC actually has, or recent events they witnessed. NPCs no longer magically know the player climbed the 7000 Steps unless something put that knowledge in front of them
- **Integrated SkyrimNet's world-knowledge decorator** — the familiarity prompt now pulls `get_world_knowledge(actorUUID)` alongside the LLM-generated impression blurb. Conditional knowledge entries that a user authored (or SkyrimNet's semantic retrieval matches) surface as "what this NPC has heard / knows" context without manual wiring per guild
- **New blurb regen cadence** — the per-NPC impression blurb now regenerates after the **first dialogue exchange** and **every 100 lines** thereafter. Replaces the old tier-change + fame-change triggers (both removed). Decision moved from C++ to Papyrus so the StorageUtil-persisted blurb-at-count drives the check authoritatively across save/load
- **Blurb generator rewrite** — `sever_reputation_assess.prompt` now takes `get_world_knowledge` + `get_relevant_memories(3)` + prior blurb as raw material. The LLM is explicitly told not to invent facts outside those sources, so an NPC's impression reflects what they actually have reason to know (or not know). 287 → 97 lines
- **Familiarity prompt slimmed** — `0045_severactions_familiarity.prompt` dropped ~270 lines of quest-stage/fame calculations. Shared-guild framing is kept for relationship tone ("you're both in the Companions"), but guild titles only surface if a world-knowledge entry provides them. 450 → 185 lines
- **Dead code removal** — `SkyrimNetBridge.h` no longer caches the 24 fame-relevant quest pointers or tracks a player fame hash. Removed: `FameQuests` struct, `PlayerFameCache`, `InitializeFameQuests()`, `SafeQuestStage()`, `RefreshPlayerFame()`, plus the `fameHash` / `pendingFire` fields on `FamiliarityState`. Net: -170 lines of C++
- **New Papyrus-callable Natives**: `Native_GetFamiliarityInteractions(Actor) → Int` (current line count) and `Native_QueueReputationAssessment(Actor)` (enqueue + fire event). These support the Papyrus-side milestone check in `OnFamiliarityTimestamp`

### Safe-Interior Auto-Sandbox
- **Default changed from ON to OFF** — the "auto-sandbox companions on safe-interior entry" feature (inns, homes, etc.) now defaults to disabled. Users who had it enabled keep their setting (the StorageUtil persistence key is untouched); only first-time installs and users who never touched the toggle see the new default. Can still be opted into via PrismaUI at any time
- **Reason** — user testing surfaced residual race conditions between `SituationMonitor`'s 3s scan cycle, SkyrimNet's `PackageOverrideHook` returning its own `FollowPlayer`, cell partial-load states where `IsInSafeInterior` flaps briefly during a transition, and `EvaluatePackage` timing vs SkyrimNet's package-registration queue. These occasionally left companions stuck on an engine fallback or the sandbox package after exit. Disabling by default avoids surprising behavior until a proper stability debounce is in place

---

## v2.2

### NPC Knowledge System — Rewrite
Every NPC now gets a single "What You Know" block that combines personal familiarity (have you met?) with public reputation (what have you heard?). Replaces the old separate familiarity and reputation prompts.

**Familiarity (personal relationship):**
- Rewrote the C++ decorator — replaced broken `PublicGetPlayerContext` with `PublicGetRecentDialogue` (direct per-NPC FormID query). Familiarity no longer stuck on "stranger"
- Five tiers based on dialogue line count: stranger (0), passing (1-200, name unknown), recent acquaintance (1-200, name known), known acquaintance (201-1000), familiar (1001+)
- Player name tracking via dialogue text scan + SkyrimNet memory search fallback. NPCs won't use your name until they've actually heard it
- Per-NPC caching (30s TTL) replaces the old bulk all-NPC cache
- Followers skip this entirely — they use the relationship system (rapport/trust/loyalty/mood) instead

**Reputation (public knowledge):**
- NPC role classification — innkeepers, bards, guards, merchants, jarls, bandits, fences each have a connectedness score (1-5) determining what rumors reach them
- Guild progression — tracks player rank in Companions, College, Thieves Guild, Dark Brotherhood via faction checks + quest stage fallback. Fame 1-5 per guild with descriptive titles
- Main Quest fame — five tiers from dragon slayer to world savior
- Dawnguard & Dragonborn DLC — three fame tiers each
- Knowledge filtering — guild members know at fame 1, locals at fame 1, connected NPCs at fame 3-4, everyone at fame 5
- Role-flavored text — guild members speak from direct knowledge, innkeepers relay gossip, guards cite official channels, criminals share underworld whispers
- Locality via faction checks (`TownRiftenFaction`, etc.) instead of fragile location string matching

**Interaction between the two:**
- Shared guild members get combined text — familiarity tier + rank woven together naturally
- Guild dedup prevents the reputation block from repeating what the familiarity block already covered
- Heading shows player name only when the NPC knows it; strangers see "What You Know About This Person"
- Familiar tier skips familiarity text but still shows reputation
- Removed civil war section per community feedback
- Old `0115_severactions_reputation.prompt` removed from FOMOD

### Furniture
- **Fixed auto-stand distance slider** — setting the PrismaUI slider to 0 (disabled) now actually disables distance-based auto-stand globally

### PrismaUI
- **FormID-based summon** — Summon button now passes FormID, preferring exact match over name lookup. Fixes teleporting the wrong actor for multi-form custom followers

---

## v2.0.7

### Outfit System
- **Per-follower outfit exclusion** — new "Outfit System" toggle on the PrismaUI Companions page. When disabled, the entire outfit system bypasses that follower: no lock enforcement, no DefaultOutfit suppression, no situation auto-switch, no alias re-equip events. Allows other outfit mods (NFF, SPID) to manage them freely
- **Fixed infinite re-equip loop** — equip/unequip operations could trigger `TESObjectLoadedEvent` cascades, causing the same actor to be stripped and re-equipped dozens of times in a single frame. Added per-actor re-entry guard with RAII cleanup
- **Fixed naked followers from stale lock data** — if locked items no longer resolve to valid armor forms (removed mods, lost items), the system now skips stripping instead of removing all gear with nothing to replace it
- **Fixed outfit lock completely non-functional** — OutfitDataStore's 26 Papyrus-callable functions were never registered with the SKSE VM. Every `OnObjectUnequipped` call in OutfitAlias hit "unbound native function" errors and silently failed, meaning outfit lock never re-equipped stripped items
- **Fixed manual lock outfit revert on cell change** — DefaultOutfit suppression was only applied for preset-based locks. Manual locks (lock-what-you're-wearing) now correctly suppress DefaultOutfit, preventing the engine from re-applying default gear on cell transitions. Previously caused outfit flicker and default items reappearing in inventory
- **Fixed PrismaUI outfit builder locks not persisting** — the builder left the outfit suspend flag set after committing a new lock. Cell transitions saw the suspend flag and skipped enforcement entirely, causing locked outfits to revert
- **Fixed survival prompt template error** — mismatched `{% if %}`/`{% endif %}` blocks in the cold section caused silent template failures

### Combat System
- **Aggression boost for forced combat** — `AttackTarget` now sets both Confidence (3) and Aggression (2) on attacker AND target. Previously only the attacker got Confidence — targets with Aggression 0 would flee instead of fighting back. Both values are stored and restored when combat ends
- **New factions for combat state** — `SeverActions_AttackFaction` and `SeverActions_TargetFaction` track which NPCs are in forced combat, used by the AIO flee patch

### AI Overhaul Compatibility
- **Optional AIO flee suppression patch** — new FOMOD option under "Compatibility Patches". Overrides AI Overhaul's 7 flee packages with conditions that skip fleeing for SeverActions followers and NPCs in forced combat. ESL-flagged, no load order slot used
- Without this patch, AI Overhaul gives most civilian NPCs flee packages that override all combat behavior

### NPC Familiarity System (New)
- **Player familiarity decorator** — `player_familiarity(actorUUID)` queries SkyrimNet's event database and vanilla relationship rank to determine if an NPC has actually met the player. Returns tier: stranger, met_once, acquainted, or familiar
- **First meeting prompt** — new `0045_severactions_familiarity.prompt` prevents NPCs from acting like old friends on first encounter. Strangers don't know the player's name, don't act familiar, and address them generically. Familiarity is earned through actual conversation history
- Uses multiple signals: SkyrimNet interaction count via `PublicGetPlayerContext`, vanilla relationship rank via `BGSRelationship`, and SeverActions follower status

### Dialogue Quality
- **Anti-meta-commentary rules** — NPCs no longer say "Not my business", "That has nothing to do with me", or "They weren't talking to me". These robotic dismissals are explicitly banned. NPCs either react naturally or stay silent
- **Bystander response guidance** — witnesses react once (briefly, in character), then return to their own life. No repeated commentary on the same event
- **Dialogue texture** — new guidance for mixing meaningful dialogue with mundane texture (weather complaints, idle observations, grumbles). Prevents every line from feeling dramatic
- **Emotional speech rules** — NPCs show emotion through HOW they speak (snapping, trailing off, going quiet) rather than announcing feelings ("I'm angry")
- Moved personality and conversation flow prompts out of Core — they now only exist in the DialogueStyle optional FOMOD module

### Actions
- **Arousal actions uncategorized** — ModifyArousal (OSL) and ModifyArousalSLO no longer require the adult category to be enabled. They now appear as normal actions

### Prompts
- **Removed Faction/Guild Reputation prompt** — the 374-line reputation template (`0115_severactions_reputation.prompt`) is now redundant with the conditional knowledge system. Removed from FOMOD installer

### OSL Arousal
- **Native C++ arousal decorator** — `get_arousal_state` now calls `OSLAroused.dll` directly via `GetProcAddress`, bypassing the Papyrus VM entirely. Fixes arousal data not showing up for users (Papyrus decorator had timing/reliability issues)
- **Expanded arousal prompt** — 5 tiers of arousal awareness (0-9 silent, 10-24 faint background, 25-49 low warmth, 50-74 persistent distraction, 75-89 hard to concentrate, 90-100 overwhelming). Previously only triggered at 75+
- Arousal described as a physical state that colors personality, not a personality replacement. A reserved person stays reserved but fidgets more
- Third-person observations only visible at 50+ (you can't see someone's internal state at low arousal)
- Removed `in_scene` field (handled by NSFW mod's activity prompts)

### Dialogue Quality
- **Rewrote conversation flow prompt** — removed all specific dialogue examples that LLMs were repeating as templates ("Ha. Yeah, that sounds about right." → spammed). Removed instructions to make sounds/gestures that TTS reads aloud. All guidance now describes the quality of speech rather than giving copyable examples
- **Rewrote personality prompt** — removed filler examples ("Hm.", "I suppose.") that got spammed. Emotion guidance reframed as "let mood bleed into words" rather than listing physical reactions (snapping, barking) that become stage directions
- Added "Don't narrate yourself" rule — no asterisks, no stage directions, no action descriptions. Only spoken words

### Hotkeys
- **Default PrismaUI hotkey** — Shift+8 opens PrismaUI config menu out of the box. Previously required manual MCM setup
- **MCM Shift modifier toggle** — new "Require Shift" toggle in MCM Hotkeys page. Users on existing saves can enable Shift+key for the config menu without starting a new game
- Default reset now resets to Shift+8 instead of disabled

### Prompts Removed
- **Removed Conditional Knowledge prompt** — `0130_conditional_knowledge.prompt` removed from Core. SkyrimNet's native knowledge system now handles conditional knowledge injection directly

### FOMOD
- New install page: **Compatibility Patches** (between Triggers and Adult Content)
- Removed "Faction/Guild Reputation Prompt" option from Prompts page
- Added `Patches/` directory to build system

---

## v2.0.6

### Outfit System
- Fixed intermittent naked followers on cell change — manual locks (locking default gear without applying a preset) no longer suppress DefaultOutfit, letting the engine help dress followers instead of racing with it
- Only preset-based outfit locks suppress DefaultOutfit now

### Auto-Sandbox
- Fixed crash (mutex deadlock) when entering player homes — the safe interior flag was being set under a lock that was already held
- Followers now spawn 250 units in front of the player when rescued from auto-sandbox, preventing them from walking back through the door
- Cross-cell rescues use MoveTo + deferred SetPosition offset for reliable positioning away from doors

### Dialogue
- Added direct address rule — NPCs now use "you/your" when speaking to someone directly instead of "she/he/they" (fixes NPCs talking about someone who is standing right in front of them)

### Triggers
- Disabled quest completion triggers (Quest Completed, Major Quest Diary) — will be reworked in a future update

---

## v2.0.5

### Outfit Builder
- **Inventory Only mode** — toggle between browsing the full armor catalog or only items in the follower's inventory. Prominent segmented toggle at the top of the builder (All Items / Inventory)
- **Equip/Unequip instant feedback** — Inventory page now shows optimistic UI updates when equipping or unequipping items, with toast notifications. No longer requires closing PrismaUI to see changes

### Follower System
- **Soft Reset button** — new option on the Companions page that clears factions, packages, aliases, and follow state but keeps relationship data, home, and combat style. Use to unstick followers without losing history
- **Teleport positioning fix** — catch-up teleport now places followers 350 units behind the player's facing direction instead of in front (was causing bump dialogue and collision)
- **Global teleport cooldown** — replaced per-follower cooldown with a single global cooldown, adjustable in PrismaUI Settings (5-120 seconds, default 30s)
- **Auto-sandbox rescue fix** — all followers now get tagged for rescue the moment auto-sandbox starts, fixing the timing issue where some of 8+ followers would get left behind
- Cleaned up "Recruit via vanilla dialogue" notifications — now just shows "is now being tracked"

### Survival System
- **Dismissed follower tracking** — dismissed followers at home now have survival needs that drift with each off-screen life event and tick in real-time when you visit their cell
- **Auto-initialization** — followers with zero survival values get seeded with random starting values on first tick instead of staying blank
- **Vampire blood support** — blood potions now reduce hunger for vampire followers (40 points). Detects vampires via keyword and race name
- **Track Dismissed Followers toggle** — new setting in PrismaUI Settings to enable/disable dismissed follower survival tracking
- **Fixed PrismaUI survival toggle** — toggling survival tracking on/off for individual followers in PrismaUI now properly syncs to MCM (was silently failing due to FormID parsing bug in all 3 event handlers)
- **Fixed PrismaUI display for dismissed followers** — survival page now shows actual values for dismissed followers instead of zeros

### Outfit System
- **Enhanced cell-load logging** — detailed logging for outfit lock enforcement on cell change, showing exactly why a follower's outfit state changed (lock active/inactive, suspended, items empty, stripped/re-equipped counts)

### Actions
- **Tightened category action selection** — LLMs can no longer add extra keys alongside "intent" when selecting category actions, preventing silent action failures

---

## v2.0

### Quest Awareness System (New)
- Followers now track the player's quests with presence-based awareness — companions who were there know details, those who weren't only hear vague rumors
- Three awareness tiers: **Firsthand** (actively following during quest progress), **Secondhand** (in roster but not present), and **Unaware** (not yet recruited)
- Objective-driven tracking — summaries generate only when new quest objectives appear, not on every internal stage change
- Personalized LLM-generated narratives per follower — each companion describes quest events through their own personality and voice
- Quest awareness prompt includes recent vanilla dialogue context from SkyrimNet's event system for grounded summaries
- Summaries build incrementally — each new objective adds a sentence, creating a natural narrative of the follower's quest experience
- On quest completion, the follower's quest awareness becomes a permanent SkyrimNet memory (EXPERIENCE for firsthand, KNOWLEDGE for secondhand)
- Proximity-aware: only followers loaded in the world and near the player receive awareness updates
- Recently recruited followers are seeded with knowledge of active quests but no fabricated details — summaries build naturally as objectives change

### Relationship Display Overhaul
- Follower relationship context is now a single LLM-generated paragraph instead of separate rigid threshold lines
- The assessment blurb naturally weaves together rapport, trust, loyalty, and mood into one cohesive inner monologue
- Each assessment produces a 3-5 sentence personality-rich description that references specific shared experiences
- New followers see a natural "still forming impressions" message instead of clinical default values

### Outfit Builder (New)
- Visual outfit builder — select armor pieces from the catalog by slot, preview selections, and equip on any follower
- Equip & Lock — equip selected items and lock the outfit to prevent engine resets on cell changes. Presets are exclusive — only preset items are worn, all other armor is stripped
- Save as Preset — save selected items as a named preset without equipping. Items are added to the follower's inventory for later use
- Hide Helmet toggle — hide head/hair slot armor per-follower
- Live search — outfit builder search results update as you type (300ms debounce)

### Situation Auto-Switch (New)
- Assign outfit presets to situations: adventure, town, home, sleep, combat, rain, snow
- Fully native C++ switching — no Papyrus dependency, instant response on location change
- Default outfit auto-save — captures current outfit before first switch, restores when entering unmapped situations
- Weather-aware detection — rain and snow situations trigger when outdoors in matching weather (only if mapped)
- Combat detection — auto-switches to combat preset during fights
- All 7 situation slots visible in PrismaUI Outfits page

### Outfit Lock System
- Outfit context now visible in follower prompts — active preset name and situation mappings read directly from the native C++ store via `outfit_context` decorator (previously broken due to StorageUtil sync gap)
- Exclusive presets — applying a preset strips ALL other armor, locks only the preset items
- Cell-load enforcement — strips non-locked armor and re-equips locked items on every cell transition
- DefaultOutfit suppression — prevents engine from restoring base outfit on cell load or during preset apply
- Native C++ preset apply — Apply Preset button and situation auto-switch share the same reliable code path
- Native GetWornArmor — single C++ call replaces 18-slot Papyrus loop for preset saves
- Items auto-added to inventory if missing when applying presets

### PrismaUI Overhaul
- All native dropdowns replaced with consistent modal pickers across the entire UI
- Catalog page: modal filter pickers for plugin (with search), slot (grid), and type selection
- Dedicated Blacklist Manager modal with Plugins/Items tabs for managing undress protection
- Reusable PickerModal component used across Outfits, Companions, Settings, Actions, and World pages

### Auto-Sandbox at Home (New)
- Followers automatically sandbox (wander naturally) when entering player-owned homes
- Reliably follows the player when leaving — detects player exiting safe interior even when returning to the same exterior cell (e.g., Honeyside → Riften)
- PrismaUI toggle: "Auto-Sandbox at Home" in Follower Behavior settings
- Won't override manual wait/sandbox commands

### Combat Style Overhaul
- 10 real combat styles replacing the old 5 abstract names: Melee, Berserker (dual-wield), Tank, Archer, Mage, Spellsword, Battlemage, Champion, Brawler, Companion
- Default is "No Combat Style" — doesn't interfere with an NPC's native combat behavior
- Overrides the ActorBase CombatStyle form — changes actual AI (flee thresholds, attack patterns, dual-wield), not just actor values
- Original combat style saved and restored on dismiss
- Old styles (balanced, aggressive, etc.) auto-migrate

### Follower System
- Reduced follower position jitter — removed 7 redundant EvaluatePackage calls that caused followers to snap backward when near the player
- Fixed non-followers (guards, Irileth) being teleported to the player — teleport now requires roster membership
- SMP-safe teleport — uses SetPosition instead of MoveTo for same-cell repositioning, preserving SMP hair/body physics
- Custom follower tracking fix — prevent re-registration loop, clean dismiss path for SPID/NFF followers
- Off-screen life exclusion — per-follower opt-out via PrismaUI
- Vanilla hunting bow removal — strip hunting bow/arrows automatically added on recruit
- Cowardly companions get minimum Brave confidence + Aggressive + Helps Allies on recruit
- Framework mode migration fix — Tracking mode no longer reverts to SeverActions mode on reload

### Furniture
- Native C++ lookup — fixes "furniture not found" for modded furniture from plugins with many active ESPs

### Actions & Compatibility
- Tightened category action selection prompt — LLMs can no longer add extra keys (like "target") alongside "intent" when selecting a category, which could cause the action to fail silently
- LearnSpell / CompanionFollow — fixes actions failing silently on some users' installations
- Dialogue style prompts — separated into optional FOMOD module

### Immersion Triggers
- Location/travel narrations now reference the player by name instead of "the party"
- Trigger audience narrowed to nearby NPCs only — random townsfolk no longer react to arrivals

### Performance & Stability
- Lazy-loaded databases — crafting, alchemy, spell, armor, weapon, and location databases initialize on first use instead of at startup (saves ~1-2s on game load)
- Background actor indexing — heavy NPC cell mapping runs on a background thread instead of blocking the loading screen (saves ~2-4s on game load)
- Internal code cleanup — consolidated shared utilities, removed dead code, fixed thread safety issues, and hardened cosave persistence against data corruption

### Bug Fixes
- Fixed stale "In Combat" badge persisting indefinitely on companion cards
- PrismaUI crash on Life Tracker for non-English users
- Off-screen life garbled text in follower memories
- Outfit lock race condition with SPID keyword
- ESL FormID compatibility for relationship assessments
- Float precision for high load order plugins in catalog equip
- Active outfit preset now shown in follower prompts
- Preset name casing mismatch between C++ and Papyrus — all preset names now normalized to lowercase
- Unmapped outfit situations no longer trigger jarring default outfit restore

---

## v1.95
- Follower banter system (auto-banter between followers)
- Outfit compatibility improvements
- Dialogue refinement (anti-fixation, topic passthrough)
- PrismaUI pause when open
- Relationship assessment with character bio
- LLM-generated relationship blurb
- ShowFollowerContext toggle
- Injection mode toggle (Always vs Semantic) for knowledge entries
- Spell school toggles on spell tab
- Follower teleport system
- SkyrimNet v7 knowledge migration
- Custom faction groups, SkyrimNet v7 dual-write

## v1.9
- Conditional Knowledge system (KnowledgeStore, cosave, decorator)
- World page revamp (bounties, debts, knowledge sections)
- Outfit fixes

## v1.8
- Property ownership system
- Two-mode follower refactor (SeverActions Mode vs Tracking Mode)
- Off-screen life improvements
- Essential toggle, assign home for custom followers, stats tab
- NFF-safe follower recruitment

## v1.6
- Inventory Manager with transfer, equip, destroy
- Vanilla recruitment routing
- Actions page overhaul

## v1.1
- Custom AI detection
- PrismaUI improvements

## v1.0
- PrismaUI config dashboard
- Home system
- Inter-follower relationships

## v0.99
- Loot transfer, self-healing follow, speaker selector
- Relationship assessment, group conversation rewrite

## v0.98
- Debt system, outfit lock, anti-duplicate actions

## v0.95
- Outfit persistence, consolidated wait, hotkeys, wheel menu, EFF support

## v0.91
- Follower Framework, Outfit Manager overhaul, Yield monitor

## v0.90
- Book reading, guard dispatch overhaul, NND integration

## v0.88
- Initial release
