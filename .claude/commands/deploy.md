---
description: "Compile changed scripts and deploy all modified files to the live game directory"
---

# SeverActions Deploy Command

Compile any changed Papyrus scripts and deploy all modified files to the live Skyrim game directory.

## Step 1: Detect Changed Files

Run:
```bash
git diff HEAD --name-only
```

Also check $ARGUMENTS — if the user specified file paths or "all", deploy those specifically.

## Step 2: Compile Changed Scripts

For each changed `.psc` file in `00 Core/Source/Scripts/`:

```bash
cd "/z/SteamLibrary/steamapps/common/Skyrim Special Edition/Papyrus Compiler" && ./PapyrusCompiler.exe "Z:/Skyrim-Mod Testing/SeverActions-0.99-FOMOD/00 Core/Source/Scripts/<ScriptName>.psc" -f="Z:/SteamLibrary/steamapps/common/Skyrim Special Edition/Data/Source/Scripts/TESV_Papyrus_Flags.flg" -i="Z:/Skyrim-Mod Testing/SeverActions-0.99-FOMOD/00 Core/Source/Scripts;Z:/Skyrim-Mod Testing/SeverActions-0.99-FOMOD/00 Core/Source/BuildStubs;Z:/SteamLibrary/steamapps/common/Skyrim Special Edition/Data/Source/Scripts" -o="Z:/Skyrim-Mod Testing/SeverActions-0.99-FOMOD/00 Core/Scripts"
```

If compilation fails, report the error and stop.

## Step 3: Deploy Files

Copy each changed file to the appropriate live game path:

| Source Pattern | Deploy To |
|----------------|-----------|
| `00 Core/Scripts/*.pex` | `Z:\SteamLibrary\steamapps\common\Skyrim Special Edition\Data\Scripts\` |
| `00 Core/Source/Scripts/*.psc` | `Z:\SteamLibrary\steamapps\common\Skyrim Special Edition\Data\Source\Scripts\` |
| `Actions/**/actions/*.yaml` | `Z:\SteamLibrary\steamapps\common\Skyrim Special Edition\Data\SKSE\Plugins\SkyrimNet\config\actions\` |
| `Prompts/**/prompts/**/*.prompt` | `Z:\SteamLibrary\steamapps\common\Skyrim Special Edition\Data\SKSE\Plugins\SkyrimNet\prompts\` (preserve subfolder structure) |
| `Triggers/**/triggers/*.yaml` | `Z:\SteamLibrary\steamapps\common\Skyrim Special Edition\Data\SKSE\Plugins\SkyrimNet\config\triggers\` |

Use `cp` to copy files. Preserve directory structure for prompts.

## Step 4: Report Results

Format:
```
## Deploy Results

### Compiled
- SeverActions_Outfit.psc → OK

### Deployed
- SeverActions_Outfit.pex → Scripts/
- SeverActions_Outfit.psc → Source/Scripts/
- equiparmor.yaml → config/actions/
- 0170_severactions_survival.prompt → prompts/submodules/

X files compiled, Y files deployed
```

If nothing changed, inform the user: "No modified files detected. Nothing to deploy."

Now execute. Parse $ARGUMENTS for specific files to deploy, or deploy all changed files if no arguments given.
