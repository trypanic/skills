# Install the council seats — OpenCode

Copy the five agent files into an agents directory OpenCode scans:

```bash
# project-level
cp llmcouncil/adapters/opencode/council-*.md .opencode/agents/

# or global
cp llmcouncil/adapters/opencode/council-*.md ~/.config/opencode/agents/
```

The filename (minus `.md`) is the agent identifier; all seats are
`mode: subagent` with `edit`/`bash` denied.

Verify: the seats appear as invocable subagents (e.g. `@council-analyst`).

These files are GENERATED from the skill's canonical `agents/` directory.
To change a seat, edit `agents/` in the skill and run
`python3 scripts/generate_adapters.py`, then re-copy. Never edit these files
in place.
