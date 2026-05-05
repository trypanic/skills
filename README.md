# skills

Agent-agnostic skills bundle. Works with **Claude Code**, **Codex CLI**, **OpenCode**, and any other agentic CLI that supports skills/instructions.

## Available

| Skill | Description |
|-------|-------------|
| [go-code-quality-check](go-code-quality-check/SKILL.md) | Run static-analysis + security gates on Go projects (`go vet` + `staticcheck` + `semgrep`) via bundled `scripts/staticanalysis.sh`. Returns prioritized fix plan grouped by file and severity. Read-only by default. |

## Deprecated

_None._

## Install via [skillshare](https://github.com/runkids/skillshare)

`skillshare` = single source of truth for skills, fanned out to every detected agent CLI via symlinks (junctions on Windows). Auto-detects Claude Code, Codex, OpenCode, and 60+ others — no manual path config.

```bash
# create config, central source, detect installed agents
skillshare init

# install skill from this repo into central source
skillshare install trypanic/go-code-quality-check

# fan out to all detected agent dirs (symlinks)
skillshare sync
```

After `sync`, skill is symlinked into each agent's skill dir automatically. Agents auto-discover on next session. No need to touch `.claude/`, `.codex/`, `.opencode/` by hand.
