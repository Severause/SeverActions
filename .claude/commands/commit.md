---
description: "Smart commit with conventional message format and validation"
---

# SeverActions Commit Command

Create a well-formatted commit for SeverActions changes.

## Step 1: Analyze Changes

Run these commands to understand what changed:
```bash
git status
git diff HEAD
git log --oneline -5
```

If there are no changes, inform the user and stop.

## Step 2: Categorize Changes

Determine the commit type based on what files changed:

| Type | When to Use |
|------|-------------|
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `action` | New or modified action YAML |
| `prompt` | New or modified prompt template |
| `script` | Papyrus script changes |
| `native` | SeverActionsNative DLL changes |
| `fomod` | Installer config changes |
| `mcm` | MCM menu changes |
| `refactor` | Code restructuring without behavior change |
| `docs` | Documentation only |

## Step 3: Validate Before Committing

- If any `.yaml` action files changed, remind the user to validate with MCP validators
- If any `.prompt` files changed, remind the user to validate with MCP validators
- If any `.psc` files changed, check that corresponding `.pex` files are also staged

## Step 4: Create Commit

Format:
```
<type>: <short summary>

- Bullet point for each change
- Be specific about what and why

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

Example:
```
feat: Add outfit preset name normalization

- NormalizePresetName() strips trailing words (outfit, gear, clothes, set, armor, attire)
- Handles LLM inconsistency where "travel outfit" should match "travel" preset
- Applied in all outfit operations that accept preset names

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

## Step 5: Stage and Commit

- Stage only the relevant files (not `git add -A`)
- Never stage `.env`, credentials, or files that shouldn't be tracked
- Use a HEREDOC for the commit message to preserve formatting
- Do NOT push — the user decides when and where to push

## Step 6: Confirm

Show the user:
- The commit hash
- The files included
- Remind them to `git push dev main` (private) or `git push origin main` (public) when ready

Now execute. Parse $ARGUMENTS for any additional context about what the commit should cover.
