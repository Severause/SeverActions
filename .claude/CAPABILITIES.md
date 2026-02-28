# SeverActions — Claude Code Capabilities

## Slash Commands

| Command | Description |
|---------|-------------|
| `/commit` | Smart commit with conventional message format, validation reminders, Co-Authored-By |
| `/validate` | Auto-detect changed prompts/actions/triggers and run SkyrimNet MCP validators |
| `/deploy` | Compile changed scripts and deploy all modified files to live game directory |

## Key Documentation

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Project instructions, architecture, workflow, critical rules |

## MCP Validators (via SkyrimNet)

| Tool | Validates |
|------|-----------|
| `mcp__skyrimnet__validate_prompt` | Prompt template syntax (Inja/Jinja2) |
| `mcp__skyrimnet__validate_custom_action` | Action YAML schema and structure |
| `mcp__skyrimnet__validate_custom_trigger` | Trigger YAML schema and structure |
| `mcp__skyrimnet__get_decorators` | Search available template decorators |

## Critical Rules Summary

1. Never commit/push without user asking
2. Never push to `origin` (public) without explicit confirmation
3. Always validate prompts and actions after editing
4. `executionFunctionName` must be a MEMBER function
5. Always deploy to live game after changes
6. Outfit lock: Suspend before, Resume after
7. After unequips: `RemoveFromLockedOutfit()`, never `SnapshotLockedOutfit()`
8. BuildStubs are compile-time only — never deploy
9. Normalize LLM string parameters in Papyrus
10. Papyrus compiler path has spaces — `cd` first, use forward slashes

## Quick Reference

### Compilation
```bash
cd "/z/SteamLibrary/steamapps/common/Skyrim Special Edition/Papyrus Compiler" && ./PapyrusCompiler.exe "<path>.psc" -f="<flags>" -i="<imports>" -o="<output>"
```
See CLAUDE.md for full command.

### Git Remotes
- `dev` → Private repo (Severause/SeverActions-Dev) — default push target
- `origin` → Public repo (Severause/SeverActions) — releases only
