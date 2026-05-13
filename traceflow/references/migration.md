# Migration guide

How to move an existing repo onto traceflow. Three starting points are
covered: spec-kit, OpenSpec, and ad-hoc / legacy `lifecycle.md`.

The skill explicitly does not require migrating prior content. A repo
that adopts traceflow may run both side by side for as long as
needed. The mapping below is for teams that want to converge.

---

## From spec-kit

spec-kit shape:

```
.specify/
├── memory/constitution.md
├── scripts/
├── specs/{NN-name}/
│   ├── spec.md
│   ├── plan.md
│   ├── tasks.md
│   ├── data-model.md
│   ├── research.md
│   ├── quickstart.md
│   └── contracts/
└── templates/
```

Field-by-field:

| spec-kit | traceflow | Notes |
|---|---|---|
| `.specify/memory/constitution.md` | `CLAUDE.md` + a single `conventions-adopted` ADR + relevant `domain/_shared/` entries | Constitution conflates three roles. Split: project rules → CLAUDE.md; pinned skill versions → conventions-adopted ADR; shared invariants → `_shared/` domain |
| `.specify/specs/{NN-name}/spec.md` | `specs/<area>/S0NN-<slug>/brief.md` | WHAT + WHY only. Drop technical detail from spec.md before moving |
| `.specify/specs/{NN-name}/plan.md` | `specs/<area>/S0NN-<slug>/plan.md` + cited ADRs | Long-lived architectural choices go to ADRs of type `stack` / `structure`. Per-change technical approach stays in `plan.md` |
| `.specify/specs/{NN-name}/tasks.md` | `specs/<area>/S0NN-<slug>/tasks.md` | Direct copy. Add `[P]` markers if missing |
| `.specify/specs/{NN-name}/data-model.md` | `domain/<area>/<entity-file>.md` | Move out of per-spec scope. If two specs both had a data-model.md describing the same entity, consolidate into one domain file |
| `.specify/specs/{NN-name}/research.md` | Either: an ADR (durable conclusion) OR a new ADR + transient `_research/` notes deleted on archive | Per-spec research with no decision lost is a smell. Decide. |
| `.specify/specs/{NN-name}/contracts/` | `domain/<area>/contracts/` + ADRs of type `contract` for rationale | Machine-readable contracts in domain. Decisions about them in ADRs |
| `.specify/specs/{NN-name}/quickstart.md` | Folded into `brief.md` | Quickstart is part of WHAT + HOW-TO-VALIDATE |
| `.specify/templates/` | `assets/` of this skill (flat) | Reuse traceflow's templates |
| `.specify/scripts/` | (out of scope for v0 of this skill) | Skill is read-only |

### Recommended migration order

1. Stand up the traceflow tree alongside `.specify/`. Do not delete anything yet.
2. Promote `constitution.md` content into the three traceflow homes.
3. For each spec-kit spec, ordered oldest-first:
   - Create `specs/<area>/S0NN-<slug>/` and copy `spec.md → brief.md`, `plan.md → plan.md`, `tasks.md → tasks.md`.
   - Lift `data-model.md` content into the matching `domain/<area>/<entity>.md`. Resolve duplicates by keeping one file, citing it from both specs.
   - Decide each `research.md`: either author an ADR or discard.
   - Lift `contracts/*` into `domain/<area>/contracts/` and create a `contract`-type ADR for the rationale.
   - Add the `Owns:` block to `plan.md` listing the file paths the spec touched.
   - Add the spec-deltas section (in retrospect this is mostly `NONE: refactor` or backfilled `ADDED` rows).
4. Rebuild `specs/<area>/MAP.md` from the new `Owns:` blocks.
5. Add a `conventions-adopted` ADR pinning the version of traceflow and any other skills.
6. Run `scripts/invariants.sh`. Address every drift.
7. Delete `.specify/` once invariants pass and the team has switched over.

---

## From OpenSpec

OpenSpec shape:

```
openspec/
├── specs/<capability>/spec.md
└── changes/<change-id>/
    ├── proposal.md
    ├── design.md
    ├── tasks.md
    └── specs/<affected-spec>/spec.md
```

Field-by-field:

| OpenSpec | traceflow | Notes |
|---|---|---|
| `openspec/specs/<capability>/spec.md` | `domain/<area>/<topic>.md` | OpenSpec specs are closest to traceflow's domain layer. Map each capability to a domain file. Capabilities that span areas split into multiple domain files in different areas |
| `openspec/changes/<change-id>/proposal.md` | `specs/<area>/S0NN-<slug>/brief.md` | WHAT + WHY only |
| `openspec/changes/<change-id>/design.md` | `specs/<area>/S0NN-<slug>/plan.md` + cited ADRs | Same split as spec-kit. Long-lived design → ADRs; per-change → plan.md |
| `openspec/changes/<change-id>/tasks.md` | `specs/<area>/S0NN-<slug>/tasks.md` | Add `[P]` markers |
| `openspec/changes/<change-id>/specs/<affected-spec>/spec.md` (the delta) | `specs/<area>/S0NN-<slug>/plan.md` Domain impact section | OpenSpec's ADDED / MODIFIED / REMOVED markers map directly. Re-emit them in the typed delta syntax |
| Archive folders (timestamped) | `specs/<area>/archive/S0NN-<slug>/` | Direct |

### Loss-bearing semantic change

OpenSpec has no first-class ADR layer. On migration, you will gain
one. Audit every change's `design.md` and extract:

- Stack choices → ADR type `stack`.
- Layout choices → ADR type `structure`.
- Contract definitions → ADR type `contract` + `domain/<area>/contracts/`.
- Policy or rule decisions → ADR type `policy`.

Numbering: start at ADR-001 for the freshest extracted decision and
go forward. Do not renumber to match commit dates; treat the migration
as the start of the ADR sequence.

---

## From ad-hoc / legacy `lifecycle.md`

This applies to repos that pre-date traceflow and use the original
`.traceflow/lifecycle.md` + `.traceflow/preamble.md` convention with `<integration>/`
scoping and `F0NN-name/` features.

### Renames

| Legacy | traceflow |
|---|---|
| `<integration>/` | `<area>/` |
| `features/<integration>/F0NN-name/` | `specs/<area>/S0NN-name/` |
| `features/<integration>/STATUS.md` | `specs/<area>/STATUS.md` |
| `features/<integration>/F0NN/spec.md` (inner file) | `specs/<area>/S0NN/plan.md` |
| Feature ID `F010` | Spec ID `S010` |

### Renames preserved as-is

- `domain/`, `decisions/`, `ideas/`, `_shared/` keep their names.
- `glossary.md`, `MAP.md`, `STATUS.md` keep their names.
- ADR file naming `ADR-NNN-<slug>.md` keeps as-is.

### Required additions

- Every ADR gets a `type:` frontmatter field (back-fill from this enum: `stack`, `structure`, `policy`, `operational`, `contract`, `security`, `data`, `conventions-adopted`).
- Every spec's `plan.md` gets the `## Owns` and `## Domain impact (deltas)` sections.
- Each area gets a `specs/<area>/MAP.md` derived from spec `Owns:` blocks.
- Each area decisions `INDEX.md` is rewritten with `ADR-NNN | type | one-line summary | status` rows.

### Rename script (bash, illustrative)

```bash
# From repo root. AREA is the legacy <integration> name.
AREA="amazon-scrape-system"

git mv ".traceflow/features/$AREA" ".traceflow/specs/$AREA"

for f in .traceflow/specs/$AREA/F*-*/; do
  bn=$(basename "$f")
  newbn=$(echo "$bn" | sed 's/^F/S/')
  git mv "$f" ".traceflow/specs/$AREA/$newbn"
done

for f in .traceflow/specs/$AREA/S*/spec.md; do
  git mv "$f" "$(dirname "$f")/plan.md"
done

# Manual steps:
#  - back-fill ADR type: frontmatter
#  - add Owns + Domain impact sections to each plan.md
#  - regenerate specs/$AREA/MAP.md from Owns blocks
#  - rewrite decisions/$AREA/INDEX.md rows
#  - update CLAUDE.md text references (integration -> area, features -> specs)
```

### Verify

Run `scripts/invariants.sh` after the rename. Expect failures on
invariants 3, 4, 5, 6 until the manual back-fill is done.

---

## Common to all three migration sources

After migration, regardless of starting point:

1. Add a `conventions-adopted` ADR per area pinning `traceflow@0.1.0` (or whatever version applies) and any other skills the area uses.
2. Run `scripts/invariants.sh` and resolve every drift.
3. Tag the migration commit. The ADR numbering invariant assumes no future renumbering; the tag is the anchor.
4. Delete the old folder structure only after one full sprint of using the new layout. Keep the rollback option open until the team is comfortable.
