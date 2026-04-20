# SeverActions Changelog

## v2.5

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
- **`0260_severactions_engaged_participants.prompt`** (both Follower and GroupMeeting copies) — stripped "1 sentence most of the time" / "1-2 sentences" / "2-3 sentences" clauses. 0260 keeps group-scene framing only ("not performing a scene", "Use names sparingly", "comfortable silence is valid"); length is 0020's job
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
