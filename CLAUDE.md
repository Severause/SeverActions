# SeverActions — Claude Code Project Instructions

## Project Overview
SeverActions is a comprehensive Skyrim SE mod that extends SkyrimNet (an AI-powered NPC dialogue system) with actions, prompts, and companion management. Packaged as a FOMOD installer with modular categories. Current version: **0.99**.

**Repos**:
- Public (releases): `https://github.com/Severause/SeverActions.git` — remote `origin`
- Private (dev): `https://github.com/Severause/SeverActions-Dev.git` — remote `dev`

**Stats**: 59 action YAMLs, 26 prompt templates, 24 Papyrus scripts, 1 SKSE native DLL

---

## Critical Rules

1. **NEVER commit or push without the user asking.** The user decides when to push.
2. **NEVER push to `origin` (public) without explicit confirmation.** Default push target is `dev` (private).
3. **Always validate** prompts and actions after editing — use MCP validators.
4. **`executionFunctionName` must be a MEMBER function.** SkyrimNet calls `instance.Function()`. Globals don't work.
5. **Always deploy to the live game** after compiling/editing so the user can test immediately.
6. **Outfit lock: Suspend before, Resume after.** All outfit operations must call `SuspendOutfitLock()` / `ResumeOutfitLock()`.
7. **After unequips, use `RemoveFromLockedOutfit()`** — never `SnapshotLockedOutfit()`. UnequipItem is async; GetWornForm returns stale data.
8. **BuildStubs are compile-time only.** NEVER deploy stub `.pex` files.
9. **Normalize LLM string parameters** in Papyrus — LLMs append extra words (e.g., "travel outfit" → "travel").
10. **Papyrus compiler path has spaces.** Always `cd` to the compiler directory first, use forward slashes.

---

## Anti-Patterns (Do NOT)

- **Do NOT use `SnapshotLockedOutfit()` after unequip operations** — race condition with async UnequipItem
- **Do NOT add NPCs to CurrentFollowerFaction directly** when NFF is installed — route through NFF's controller
- **Do NOT declare `executionFunctionName` as a Global function** — SkyrimNet member-calls only
- **Do NOT deploy BuildStub `.pex` files** — they're empty shells for compilation only
- **Do NOT create files unless necessary** — prefer editing existing files
- **Do NOT push to the public repo** (`origin`) unless explicitly asked

---

## Project Structure

```
SeverActions-0.99-FOMOD/          ← Repo root / FOMOD root
├── 00 Core/
│   ├── Source/Scripts/            ← Papyrus source (.psc)
│   ├── Source/BuildStubs/         ← Compile-time stubs for soft dependencies
│   ├── Scripts/                   ← Compiled output (.pex)
│   └── SeverActions.esp           ← Plugin (single quest, FormID 0x000D62)
├── Actions/<Category>/SKSE/Plugins/SkyrimNet/config/actions/   ← Action YAMLs
├── Prompts/<Category>/SKSE/Plugins/SkyrimNet/prompts/          ← Prompt templates
├── Triggers/<Category>/SKSE/Plugins/SkyrimNet/config/triggers/ ← Trigger configs
├── Native/                        ← SeverActionsNative DLL source (private dev repo only)
│   ├── src/                       ← C++ source files
│   ├── CMakeLists.txt
│   └── build.ps1
├── fomod/                         ← FOMOD installer config
│   ├── ModuleConfig.xml
│   └── info.xml
└── CLAUDE.md                      ← This file
```

### FOMOD Categories
- **Actions**: Adult-OSLAroused, Adult-SLOAroused, Arrest, Basic, Combat, Crafting, Economy, Follower, Furniture, Outfit, Travel
- **Prompts**: ActionSelector, Adult-Fertility, Adult-OSLAroused, Adult-SLOAroused, Arrest, Combat, Core, Economy-Anywhere, Economy-LocationOnly, Faction, Follower, GroupMeeting, Survival, TargetSelectors
- **Triggers**: Adult

### All 24 Scripts
SeverActions_Arousal, SeverActions_Arrest, SeverActions_Combat, SeverActions_Crafting, SeverActions_Currency, SeverActions_Debt, SeverActions_EatingAnimations, SeverActions_FertilityMode_Bridge, SeverActions_Follow, SeverActions_FollowerManager, SeverActions_Furniture, SeverActions_Hotkeys, SeverActions_Init, SeverActions_Loot, SeverActions_MCM, SeverActions_Outfit, SeverActions_OutfitAlias, SeverActions_SLOArousal, SeverActions_SpellTeach, SeverActions_Survival, SeverActions_Travel, SeverActions_WheelMenu, SeverActions_YieldAlias, SeverActionsNative

---

## Compilation

```bash
cd "/z/SteamLibrary/steamapps/common/Skyrim Special Edition/Papyrus Compiler" && ./PapyrusCompiler.exe "Z:/Skyrim-Mod Testing/SeverActions-0.99-FOMOD/00 Core/Source/Scripts/<ScriptName>.psc" -f="Z:/SteamLibrary/steamapps/common/Skyrim Special Edition/Data/Source/Scripts/TESV_Papyrus_Flags.flg" -i="Z:/Skyrim-Mod Testing/SeverActions-0.99-FOMOD/00 Core/Source/Scripts;Z:/Skyrim-Mod Testing/SeverActions-0.99-FOMOD/00 Core/Source/BuildStubs;Z:/SteamLibrary/steamapps/common/Skyrim Special Edition/Data/Source/Scripts" -o="Z:/Skyrim-Mod Testing/SeverActions-0.99-FOMOD/00 Core/Scripts"
```

**BuildStubs pattern**: For soft dependencies (e.g., NFF), place minimal stub `.psc` with just function signatures in `BuildStubs/`. Include in import path for compilation. NEVER deploy stub `.pex` files.

---

## Deploy Paths (Live Game)

| File Type | Deploy To |
|-----------|-----------|
| `.pex` (compiled scripts) | `Z:\SteamLibrary\steamapps\common\Skyrim Special Edition\Data\Scripts\` |
| `.psc` (source scripts) | `Z:\SteamLibrary\steamapps\common\Skyrim Special Edition\Data\Source\Scripts\` |
| Action YAMLs | `Z:\SteamLibrary\steamapps\common\Skyrim Special Edition\Data\SKSE\Plugins\SkyrimNet\config\actions\` |
| Prompts | `Z:\SteamLibrary\steamapps\common\Skyrim Special Edition\Data\SKSE\Plugins\SkyrimNet\prompts\` (match subfolder structure) |
| Triggers | `Z:\SteamLibrary\steamapps\common\Skyrim Special Edition\Data\SKSE\Plugins\SkyrimNet\config\triggers\` |

---

## Key Architectural Patterns

### Scripts & Quest
- **Single quest**: "SeverActions" at FormID `0x000D62` — all scripts attached to it
- **GetInstance pattern**: `Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest`
- **Per-actor persistence**: `StorageUtil.SetFloatValue(actor, "Key", val)` / `GetFloatValue()`

### SkyrimNet Integration
- **Action YAMLs**: `questEditorId: SeverActions`, `scriptName: <ScriptName>`, `executionFunctionName: <MemberFunction>`
- **Eligibility**: `decoratorName` + `comparisonOperator` + `expectedValue` with decorators
- **Prompt templates**: Inja (Jinja2-compatible) syntax with SkyrimNet decorators
- **Key decorators**: `is_follower()`, `papyrus_util()`, `decnpc()`, `get_recent_events()`, `get_relevant_memories()`, `get_latest_diary_entry()`, `get_diary_entries()`, `formid_to_uuid()`, `is_in_combat()`, `is_in_faction()`, `to_number()`, `to_string()`, `default()`, `existsIn()`, `append()`, `length()`, `random(min, max)`

### MCM System
- `SeverActions_MCM.psc` extends `SKI_ConfigBase`
- **OID system**: Declare `int OID_*` variables, use `AddToggleOption`/`AddSliderOption`/`AddMenuOption`/`AddTextOption` in Draw functions
- **Five handler events per OID**: `OnOptionSelect` (toggles/clicks), `OnOptionSliderOpen`/`OnOptionSliderAccept` (sliders), `OnOptionMenuOpen`/`OnOptionMenuAccept` (menus), `OnOptionHighlight` (tooltips), `OnOptionDefault` (reset to default)
- **Pages**: General, Hotkeys, Currency, Travel, Bounty, Survival, Followers

### Outfit System
- `SeverActions_Outfit.psc` — equip/unequip/dress/undress/presets/outfit lock
- `SeverActions_OutfitAlias.psc` — per-follower alias enforcing outfit lock via events
- **Suspend/Resume pattern**: All outfit operations call `SuspendOutfitLock(akActor)` before and `ResumeOutfitLock(akActor)` after
- **After equips**: Use `LockEquippedOutfit()` (takes known-good forms array)
- **After unequips**: Use `RemoveFromLockedOutfit()` (directly edits lock FormList)
- **NEVER after unequips**: `SnapshotLockedOutfit()` — UnequipItem is async, GetWornForm returns stale data
- **NormalizePresetName()**: Strips trailing words (outfit, gear, clothes, set, armor, attire)

### Follower Framework
- `SeverActions_FollowerManager.psc` — roster, relationships (rapport/trust/loyalty/mood), home, combat style, morality
- **NFF Integration**: Detects `nwsFollowerFramework.esp` at runtime; routes recruit/dismiss through NFF controller (FormID `0x0000434F`) when available
- **Relationship Assessment**: OnUpdate loop → game-time cooldown per follower → `SendCustomPromptToLLM` → JSON callback with rapport/trust/loyalty/mood deltas
- **Dedup tracking**: Events (`eid`), memories (`mid`), diary (`did`) — stored per actor in StorageUtil, compared in prompt template
- **YAML → Member function mapping**:
  - `setcompanion.yaml` → `RegisterFollower(Actor)`
  - `dismissfollower.yaml` → `DismissCompanion(Actor)`
  - `companionwait.yaml` → `CompanionWait(Actor)`
  - `assignhome.yaml` → `AssignHome(Actor, String)`
  - `setcombatstyle.yaml` → `SetCombatStyle(Actor, String)`
  - `followerleaves.yaml` → `FollowerLeaves(Actor)`

---

## Validation Tools

Always validate after editing prompts, actions, or triggers:
- **Prompts**: `mcp__skyrimnet__validate_prompt` — catches mismatched `{% if %}`/`{% endif %}` blocks
- **Actions**: `mcp__skyrimnet__validate_custom_action` — catches YAML schema issues
- **Triggers**: `mcp__skyrimnet__validate_custom_trigger`
- **Discover decorators**: `mcp__skyrimnet__get_decorators` — search by name or category

---

## Workflow

### Standard Change Flow
1. **Discuss the change** — understand what's needed, check existing code
2. **Edit source files** in the FOMOD directory (this IS the source of truth)
3. **Compile** if Papyrus scripts changed
4. **Validate** if prompts or YAML actions changed
5. **Deploy to live game** — copy to Skyrim Data directory for immediate testing
6. **Commit & push** when user asks (not proactively — user decides when to push)
7. **Release** only when user asks

### Git Conventions
- **Default push target**: `dev` (private repo)
- **Public pushes**: Only to `origin` when explicitly asked
- Commit messages: short summary + bullet points
- Always include `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`
- For releases: `Compress-Archive` → `gh release create` or `gh release upload --clobber`

### User Preferences
- Deploys changes to live game for immediate testing
- Prefers concise explanations with tables/bullet points
- Values community feedback — implements user suggestions
- Comfortable with architectural decisions but wants to understand reasoning
- Uses MO2 for mod management
- Git/GitHub is relatively new — be clear about what operations do

---

## Lessons Learned

- **Papyrus compiler path**: Must `cd` to compiler directory first, use forward slashes
- **NFF conflict**: NFF monitors CurrentFollowerFaction. Route through NFF's `RecruitFollower()` when installed
- **`is_follower` decorator**: Checks native CurrentFollowerFaction (`0x084D1B`), not custom factions
- **Prompt validation**: Always validate — template syntax errors are easy to miss
- **Diary dedup pattern**: Watermark approach — store last-seen ID per actor, compare in template
- **Race conditions with outfit lock**: `OnObjectUnequipped` fires async after `ResumeOutfitLock()`. Update lock list BEFORE resuming.

---

## SkyrimNet Core Development

The user is a member of the SkyrimNet dev team (MinLL/SkyrimNet), contributing directly to the C++ core.

- **Repo**: `https://github.com/MinLL/SkyrimNet.git` (private)
- **Local clone**: `Z:\Skyrim-Mod Testing\SkyrimNet-Dev\` (junction: `Z:\SkyrimNetDev\`)
- **GamePlugin**: `Z:\Skyrim-Mod Testing\SkyrimNet-GamePlugin\`
- **Build**: `cd Z:\SkyrimNetDev && powershell.exe -ExecutionPolicy Bypass -File try_build.ps1`
- **Deploy DLL**: Copy `build\release\SkyrimNet.dll` to `Z:\SteamLibrary\...\Data\SKSE\Plugins\SkyrimNet.dll`
- **Git workflow**: Branch from `dev` → commit → push → PR → review → merge (NOT direct push)
