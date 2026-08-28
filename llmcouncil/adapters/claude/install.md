# Install the council seats — Claude Code

Copy the five agent files into an agents directory Claude Code scans:

```bash
# project-level (recommended; check into version control)
cp llmcouncil/adapters/claude/council-*.md .claude/agents/

# or user-level (available in all your projects)
cp llmcouncil/adapters/claude/council-*.md ~/.claude/agents/
```

Verify: start a session and confirm the five `council-*` agents are listed
as available agent types (e.g. via `/agents`).

These files are GENERATED from the skill's canonical `agents/` directory.
To change a seat, edit `agents/` in the skill and run
`python3 scripts/generate_adapters.py`, then re-copy. Never edit these files
in place.
