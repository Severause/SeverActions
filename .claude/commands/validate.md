---
description: "Validate changed prompts, actions, and triggers using SkyrimNet MCP validators"
---

# SeverActions Validate Command

Automatically detect which files changed and run the appropriate SkyrimNet MCP validators.

## Step 1: Detect Changed Files

Run:
```bash
git diff HEAD --name-only
git diff --cached --name-only
```

Also check $ARGUMENTS — if the user specified file paths, validate those specifically.

## Step 2: Categorize and Validate

For each changed file, determine its type and run the appropriate validator:

### Action YAMLs (`.yaml` files in `Actions/`)
For each changed action YAML:
1. Read the file to get the full path
2. Call `mcp__skyrimnet__validate_custom_action` with the file content
3. Report pass/fail with details

### Prompt Templates (`.prompt` files in `Prompts/`)
For each changed prompt:
1. Read the file to get the full path
2. Call `mcp__skyrimnet__validate_prompt` with the file content
3. Report pass/fail — watch for mismatched `{% if %}`/`{% endif %}` blocks

### Trigger Configs (`.yaml` files in `Triggers/`)
For each changed trigger:
1. Read the file to get the full path
2. Call `mcp__skyrimnet__validate_custom_trigger` with the file content
3. Report pass/fail with details

### Papyrus Scripts (`.psc` files)
No MCP validator, but check:
- Does the script reference `executionFunctionName` functions that are actually member functions (not Global)?
- Are there matching `.pex` files that need recompilation?

## Step 3: Report Results

Format:
```
## Validation Results

| File | Type | Status | Notes |
|------|------|--------|-------|
| equiparmor.yaml | Action | PASS | |
| survival.prompt | Prompt | FAIL | Mismatched endif on line 45 |
| adult_trigger.yaml | Trigger | PASS | |

X passed, Y failed
```

If any validations fail, show the specific error and suggest a fix.

If no changed files match any validation category, inform the user:
"No action YAMLs, prompts, or triggers were modified. Nothing to validate."

Now execute. Parse $ARGUMENTS for specific files to validate, or validate all changed files if no arguments given.
