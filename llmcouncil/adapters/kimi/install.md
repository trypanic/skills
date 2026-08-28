# Install the council seats — Kimi Code CLI

Copy the five agent files into an agents directory Kimi scans:

```bash
# project-level
cp llmcouncil/adapters/kimi/council-*.md .kimi-code/agents/

# or user-level
cp llmcouncil/adapters/kimi/council-*.md ~/.kimi-code/agents/
```

Each file is markdown with YAML frontmatter (`name`, `description`,
`whenToUse`, `tools`). Kimi discovers `.md` files in these directories
recursively; the `name` field is the agent identifier.

Verify: the seats are available for sub-agent delegation (request them by
name in conversation, or run `kimi --agent council-analyst` to smoke-test
one directly).

These files are GENERATED from the skill's canonical `agents/` directory.
To change a seat, edit `agents/` in the skill and run
`python3 scripts/generate_adapters.py`, then re-copy. Never edit these files
in place.
