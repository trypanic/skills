# Install the council seats — Codex CLI

Copy the five agent files into an agents directory Codex scans:

```bash
# project-scoped
cp llmcouncil/adapters/codex/council-*.toml .codex/agents/

# or personal
cp llmcouncil/adapters/codex/council-*.toml ~/.codex/agents/
```

Each file defines one custom agent (`name`, `description`,
`developer_instructions`, `sandbox_mode = "read-only"`). Model and reasoning
effort inherit from the parent unless you add overrides.

Verify: ask the main agent to "spawn council-analyst" — it should resolve
the custom agent by name.

These files are GENERATED from the skill's canonical `agents/` directory.
To change a seat, edit `agents/` in the skill and run
`python3 scripts/generate_adapters.py`, then re-copy. Never edit these files
in place.
