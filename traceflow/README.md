# traceflow

Lifecycle-driven documentation skill with spec-delta traceability.
Agent-agnostic and stack-agnostic. Works with Claude Code, Codex,
OpenCode, Cursor, and any other agentic CLI that supports skills.

```
idea  →  domain  →  decisions  →  specs
                                    ↓
                          spec-delta back-edges
```

Four artifact axes, per-area scoping, append-only ADRs, file-path
reverse-index maps, mandatory Update Manifest at end of every
agent turn. See [`SKILL.md`](SKILL.md) for the full protocol.

---

## What this skill teaches an agent to do

- Capture a brainstorm in `ideas/<area>/<topic>/` with a Q&A
  transcript log alongside the distilled prose.
- Promote stable ideas into durable knowledge in `domain/<area>/`.
- Open and supersede ADRs with `type:` taxonomy (`stack`,
  `structure`, `policy`, `operational`, `contract`, `security`,
  `data`, `conventions-adopted`).
- Scaffold implementation slices in `specs/<area>/S0NN-<slug>/`
  with `brief`, `plan`, `tasks`, `status`.
- Declare ownership of file paths and behaviors in each spec's
  `Owns:` block. The `specs/<area>/MAP.md` is the file-path reverse
  index derived from these declarations.
- Track domain and ADR impact via the spec-delta mechanic:
  `ADDED`, `MODIFIED`, `REMOVED`, or typed `NONE`.
- Run six bash smoke tests (`scripts/invariants.sh`) to surface
  structural drift.
- Emit an Update Manifest at end of every turn so humans can see
  what changed.

## What this skill does NOT do

- Execute code. This is a docs lifecycle, not an execution tool.
- Choose a programming language, framework, or library.
- Configure CI/CD or deployment infrastructure.
- Enforce code style or run linters.

Language-specific concerns bind to a project through a single
`conventions-adopted` ADR that names the skills the project pins
(e.g. `go-modularization`, `go-design-principles`).

## Install via skillshare

```bash
skillshare init
skillshare install trypanic/traceflow
skillshare sync
```

After `sync`, the skill is symlinked into every detected agent
directory (`.claude/`, `.codex/`, `.opencode/`, etc.). Agents
auto-discover the skill on next session.

## Skill folder layout

This is the layout of THIS skill's directory (`github.com/trypanic/skills/traceflow/`). For the layout the skill creates inside user projects, see [`SKILL.md` § Repository shape](SKILL.md), which describes the `.traceflow/` outcome folder.

```
traceflow/
├── SKILL.md                                # protocol summary, agent entry point
├── README.md                               # this file
├── references/
│   ├── lifecycle.md                        # full state machines + topology
│   ├── tasks-to-files.md                   # reading map per task type
│   ├── migration.md                        # from spec-kit, OpenSpec, ad-hoc
│   ├── examples.md                         # worked Go monorepo
│   └── single-area-collapse.md             # minimum-viable layout
├── scripts/
│   └── invariants.sh                       # bash smoke tests (executable)
└── assets/                                 # all artifact templates (flat per agentskills.io spec)
    ├── idea-readme.md
    ├── idea-transcript.md
    ├── adr.md
    ├── spec-brief.md
    ├── spec-plan.md
    ├── spec-tasks.md
    ├── spec-status.md
    ├── map-domain.md
    ├── map-specs.md
    ├── status-global.md
    ├── status-area.md
    ├── index-decisions.md
    └── update-manifest.md
```

Strictly compliant with the [agentskills.io specification](https://agentskills.io/specification):
- `SKILL.md` ≤ 500 lines (instructions ≤ 5000 tokens)
- frontmatter fields: `name`, `description` ≤ 1024 chars, `license`, `compatibility` ≤ 500 chars, `metadata`
- file references one level deep from `SKILL.md` (e.g. `references/foo.md`, `assets/foo.md`)
- templates flat under `assets/`, not nested
- executable code under `scripts/` per the spec's `scripts/` clause

## Comparison to neighboring tools

| Concern | traceflow | OpenSpec | spec-kit |
|---|---|---|---|
| Ideation phase (brainstorm) | first-class (`ideas/`) | none | none |
| Durable shared knowledge | first-class (`domain/`) | partial (`specs/`) | partial (constitution) |
| ADRs | first-class, typed, append-only, globally numbered | none (folded into design.md) | none (folded into research.md) |
| Spec-deltas | mandatory, typed `NONE` | yes (ADDED / MODIFIED / REMOVED) | no |
| Per-area scoping | enforced via boundary rule | flat capabilities | flat features |
| Inter-area navigation | `domain/MAP.md` with dependency edges | none | none |
| Intra-area navigation | `specs/<area>/MAP.md` (file-path reverse index) | none | none |
| Multi-level STATUS | three levels (global, per-area, per-spec) | none | one (constitution) |
| Implementation phase | out of scope (skill is docs only) | out of scope | in scope (Implement) |

Pick spec-kit if your repo is a single product with isolated
features, short lifespan, greenfield. Pick traceflow if your repo
is a monorepo, multiple areas, or long-lived enough that the same
business rule will be touched by more than one spec over time.
traceflow's single-area mode covers spec-kit's use case without
restructuring later.

See [`references/migration.md`](references/migration.md) for
field-by-field mappings.

## Versioning

Version is recorded in `SKILL.md` frontmatter `metadata.version`.

Projects pin the version they use in their `conventions-adopted`
ADR:

```
This area adopts:
- traceflow@<version>
- ...
```

Upgrade is itself a traceable decision: a new ADR supersedes the
old conventions-adopted ADR with the new version pinned.

## License

MIT. See `SKILL.md` frontmatter.

## Open questions and v1 roadmap

v0 is skill-only. Manual checklists + Update Manifest + bash
invariants substitute for a validator. This will decay if used
casually.

v1 plans:

- Go CLI binary implementing each `/traceflow:*` command.
- Validator that enforces invariants in CI.
- Auto-generation of `specs/<area>/MAP.md` from `Owns:` blocks.
- Conflict detection at scaffold time (not only at audit time).

See the source repo issues for current status.
