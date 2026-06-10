---
name: traceflow
description: 'Lifecycle-driven documentation skill with spec-delta traceability. Governs four artifact axes (idea, domain, decisions, specs) across per-area scoping with append-only ADRs and file-path reverse-index maps. Also governs behavior-scoped diagrams as a sub-type of domain: three classes (fragment, behavior, composite) with canonical-owner enforcement and anchor-based cross-references. Use when scaffolding a new traceflow-managed repo, drafting an idea or brainstorm, promoting an idea to durable domain knowledge, proposing or accepting or superseding an ADR, drafting a new spec (implementation slice), updating lifecycle state, archiving a completed spec, running structural invariants, rebuilding navigation maps, drafting a new behavior diagram, extracting a fragment, or refactoring an end-to-end diagram into behavior + fragments. Trigger phrases include "new idea", "draft an idea", "promote idea to domain", "new ADR", "supersede ADR", "add area", "new spec", "archive spec", "check invariants", "rebuild map", "start a brainstorm", "standardize documentation lifecycle", "new diagram", "extract fragment", "decompose flow diagram", "behavior-scoped diagram". Stack-agnostic and language-agnostic by design. Out of scope, code execution, test running, deployment, build systems, language-specific conventions bound via the conventions-adopted ADR.'
license: MIT
compatibility: 'Bash 4+ required to run scripts/invariants.sh. Skill content is plain markdown otherwise; no other runtime dependencies.'
metadata:
  author: trypanic
  version: "0.2.0-draft"
  homepage: "https://github.com/trypanic/skills/tree/main/traceflow"
  outcome-folder: ".traceflow"
---

# traceflow

Lifecycle-driven authoring skill. Governs how documentation is created, structured, navigated, and retired across a project's lifetime. Stack-agnostic and language-agnostic.

The skill defines four artifact axes that an agent and a human collaborate on through a project's life:

```
idea  →  domain  →  decisions  →  specs
```

Plus the navigation, isolation, and traceability infrastructure that lets an agent operate without reading every file in the repository.

This is not Spec-Driven Development (SDD). SDD is the `specs` axis only. traceflow's other three axes (`idea`, `domain`, `decisions`) are first-class and operate on different stability tiers.

---

## When to use

Activate this skill when the user asks to:

- start a new repo with traceflow conventions ("standardize documentation lifecycle", "set up traceflow")
- capture a brainstorm or open question ("new idea", "draft an idea", "start a brainstorm")
- promote stable ideas into long-lived knowledge ("promote idea to domain")
- ratify or supersede an architectural decision ("new ADR", "supersede ADR", "add an ADR")
- scaffold or progress an implementation slice ("new spec", "draft a spec", "promote spec to ready")
- move a spec through its lifecycle ("mark spec done", "archive spec")
- rebuild or audit navigation surfaces ("rebuild map", "check invariants")
- add a new area to a multi-area repo ("add area", "promote to its own area")
- draft a new behavior diagram, extract a fragment, or refactor an end-to-end diagram into behavior + fragments ("new diagram", "extract fragment", "decompose flow diagram", "behavior-scoped diagram")

## When NOT to use

Skip this skill when the user asks to:

- write, run, or test code (this is a docs lifecycle, not an execution tool)
- pick a programming language, framework, or library
- design CI/CD or deploy infrastructure
- enforce code style or run linters (delegate to language-specific skills)

The single binding from traceflow to language-specific concerns is the `conventions-adopted` ADR. The skill itself stays language-agnostic.

---

## Hard rules (non-negotiable)

1. **Per-area isolation.** Code, decisions, ideas, and rules for one area MUST NOT leak into another. Cross-area work happens only through `_shared/`.
2. **No duplicated rules.** The same business rule lives in exactly one file. Cross-references are allowed; copy-paste is not.
3. **ADRs are append-only after acceptance.** Body never edited. Only the Status header changes on supersede or deprecate.
4. **Globally unique ADR numbers.** Across `_shared/` and every per-area bucket. A number is never reused.
5. **Domain is business knowledge only.** No stack, no infrastructure, no tooling. Those live in ADRs.
6. **Specs declare their domain impact.** Every spec lists ADDED, MODIFIED, REMOVED entries in its `plan.md`. Empty deltas require typed `NONE` justification.
7. **Three-level STATUS files must stay in sync.** Global, per-area, per-spec. Staleness in one without the others is a process bug.
8. **The agent owns documentation updates.** When an agent performs any action that changes state, it MUST emit the Update Manifest defined below.
9. **Read the right files for the task, not all of them.** Follow `references/tasks-to-files.md`. Do not pre-read areas you are not working in.
10. **Idea folder existence IS the state.** No `proposed → ready` ceremony for ideas. Promotion and abandonment are deliberate commits.
11. **Diagrams are derived consequences, not planned artifacts.** A diagram is created or updated as a consequence of an accepted ADR or a domain edit, in the same operation that performs the trigger. No separate spec is required when the only files changing are under `domain/<area>/diagrams/`. Reusable sub-sequences are extracted as fragments with exactly ONE canonical owner; behavior diagrams MUST consume fragments by anchor, not redraw them. See "Diagrams (sub-type of domain)" below.

---

## The four axes (one paragraph each)

Full state machines and topology diagrams live in `references/lifecycle.md`. Summary here.

### idea
Volatile pre-formalization brainstorm. Free-form prose + a `transcript.md` Q&A log. Lifecycle: `iterating | promoted | abandoned`. Folder existence is the state.

### domain
Durable problem-space knowledge. Entities, rules, state machines, scenarios, contracts, invariants. Append-mostly. One rule per file. No DDD doctrine implied; "domain" here means "problem space".

### decisions
Atomic architectural decisions (ADRs). Append-only after acceptance. Globally numbered. Typed via mandatory `type:` field. Types: `stack`, `structure`, `policy`, `operational`, `contract`, `security`, `data`, `conventions-adopted`.

### specs
Implementation slices. Per-area folder `specs/<area>/S0NN-name/` with four files: `brief.md` (what + why), `plan.md` (how + spec-deltas + Owns: block), `tasks.md` (decomposition with `[P]` parallel markers), `status.md` (current state). States: `draft → ready (optional) → in-progress → done → closed (terminal, requires reason) → archived`.

---

## Diagrams (sub-type of domain)

Diagrams live under `domain/<area>/diagrams/`. They inherit domain's
rules: per-area isolation, no duplicated rules, append-mostly.

### Diagrams are derived, not planned

A diagram is a **consequence** of an ADR or a domain edit, not a
first-class artifact requiring its own spec. The agent's job is to
derive diagrams from existing decisions and domain content:

- When an ADR with behavioral impact is **accepted**, the agent
  reads the ADR body and the domain content it touches, then creates
  or updates the affected diagrams in the same operation.
- When a domain edit lands (idea promoted, business rule added,
  entity defined, anti-pattern documented), the agent derives the
  matching diagram updates from that content in the same operation.
- When the diagram convention itself changes (e.g., this skill bumps
  and adopts a new fragment shape), the convention-adopting ADR
  triggers the consequent diagram refactor as a direct domain edit.

Specs continue to declare diagram deltas in their `## Domain impact`
ONLY when code work drives a new behavior or modifies an existing
one (a new flow branch from a new feature, a renamed operation in a
wire-format change, etc.). For convention-driven or
understanding-driven refactors that touch no code: **no spec
wrapper**. The triggering ADR or domain edit is the audit trail; the
activity log lives in `specs/<area>/STATUS.md`.

Concrete rule of thumb: if the only files changing are under
`domain/<area>/diagrams/`, you do not need a spec. Edit directly, log
the activity. If files outside `domain/` also change (code,
migrations, configuration), then a spec is appropriate and the
diagram changes ride on its `## Domain impact` deltas.

### Three classes

Three classes, with a strict canonical-owner rule:

| Class | Purpose | Owns | References |
|---|---|---|---|
| **Fragment** | A reusable sub-sequence (envelope, handshake, sub-transaction) | 1 named fragment | nothing |
| **Behavior** | One decision branch, outcome, or variant — only the slice unique to *this* behavior | nothing | 0..N fragments |
| **Composite** | Scenario-level rollup naming which behaviors compose into a scenario; no sequence detail | nothing | only behavior diagrams |

### File layout

```
domain/<area>/diagrams/
├── _fragments/                  # canonical fragment files (F-<slug>.md)
├── 00-<composite>.md            # optional scenario rollup
└── <NN>-<behavior-slug>.md      # behavior diagrams
```

Cross-area fragments live under `domain/_shared/diagrams/_fragments/`
and are referenced with the `_shared/` path prefix.

### Promotion bar (when does a sub-sequence become a fragment)

A sub-sequence is promoted to a fragment when at least one is true:

1. **Empirical reuse:** referenced by ≥2 behavior diagrams.
2. **ADR-anchored contract surface:** corresponds to a named contract
   in an accepted ADR (e.g. an operation envelope, a transactional
   template).

Do NOT promote single-use sub-sequences; inline them. Do NOT promote
rule chains (`ANTI-*`, `BIZ-*`, `INV-*`) — those are referenced by ID
in prose, not redrawn anywhere.

### Anchor syntax

Every diagram has mandatory `## Steps` with numbered subheadings
(`### S1.`, `### S2.`, …). Behavior diagrams reference fragments via
two surfaces, both required when a fragment is consumed:

1. **In-diagram Mermaid note** at the splice point:
   ```
   Note over <Alias1>,<Alias2>: ⟶ F-<slug> §S1-S3
   ```
   The `⟶ ` prefix is mandatory and parsed by `scripts/invariants.sh`.
2. **`## Fragments used` block** (the diagram-axis analog of `## Owns`):
   ```markdown
   - F-<slug> §S1-S3 — <one-line role>
   - F-<slug> §all — <one-line role>
   - none: standalone   # required justification when no fragments consumed
   ```

Allowed `none` classes: `standalone`, `speculative`.

### Canonical-owner rule

A fragment ID exists in exactly one file (its canonical owner under
`_fragments/`). Any behavior diagram that would otherwise redraw it
MUST consume by anchor. Diagram-axis analog of spec `Owns:`
exclusivity. Edits to a fragment's body are structural changes
recorded as spec-deltas:

```
- MODIFIED domain/<area>/diagrams/_fragments/F-<slug>.md#S2: <what changes, why>
```

### Templates

- `assets/diagram-fragment.md`
- `assets/diagram-behavior.md`
- `assets/diagram-composite.md`

Full convention, decomposition recipe, and worked example in
`references/diagrams.md`.

---

## Repository shape (outcome folder in user projects)

The skill creates and maintains a `.traceflow/` directory in the host repository. THIS is what the skill produces, NOT the skill's own folder. The dot prefix marks it as tool-managed (similar convention to `.git/`, `.specify/`).

Canonical multi-area layout:

```
.traceflow/
├── STATUS.md                              # global state
├── preamble.md                            # reading map, capped at 60 lines
├── domain/
│   ├── MAP.md                             # topology of areas + dependencies
│   ├── glossary.md                        # transversal terms, capped at 500 lines
│   ├── _shared/                           # cross-area knowledge (rare)
│   └── <area>/
│       └── ...                            # durable business knowledge
├── decisions/
│   ├── _shared/INDEX.md                   # cross-area ADRs (type+summary rows)
│   └── <area>/INDEX.md                    # area-scoped ADRs (type+summary rows)
├── ideas/
│   ├── _shared/<topic>/
│   └── <area>/<topic>/
└── specs/
    └── <area>/
        ├── STATUS.md                      # area lifecycle dashboard
        ├── MAP.md                         # file-path reverse index (primary view)
        ├── S0NN-name/
        │   ├── brief.md
        │   ├── plan.md
        │   ├── tasks.md
        │   └── status.md
        └── archive/S0NN-name/             # closed/archived specs
```

### Single-area collapse

When the repo has exactly one area, do NOT flatten. Keep the `<area>/` folder. Future growth to multiple areas then does not refactor the tree. The bloat is one folder level. Worth it.

Full collapse template in `references/single-area-collapse.md`.

---

## Commands

The skill names protocols after future tool commands. In skill-only mode (no CLI yet), the agent performs the work and emits an Update Manifest. When the tool ships, the same commands are run as CLI invocations.

### `/traceflow:idea "<topic>" [--area <area>] [--shared]`

Start a brainstorm.

**Skill behavior:**
1. Create `ideas/<area>/<topic-slug>/` (or `ideas/_shared/<topic-slug>/`).
2. Scaffold `README.md` from `assets/idea-readme.md`.
3. Scaffold empty `transcript.md` from `assets/idea-transcript.md`.
4. Run an interactive Q&A with the user. After EACH exchange, append a timestamped entry to `transcript.md` (question, answer, decisions reached).
5. As the brainstorm stabilizes, distill prose into `README.md`. The transcript stays as audit history.
6. On user signal to stop, do NOT promote. Leave the folder in `iterating` state.
7. Emit Update Manifest naming the created files.

### `/traceflow:domain [--area <area>]`

Promote one or more open ideas into durable domain knowledge.

**Skill behavior:**
1. Read the open `ideas/<area>/<topic>/README.md` content.
2. Identify the stable parts (entities, rules, state machines, scenarios, contracts, invariants).
3. Write or extend the appropriate files under `domain/<area>/`. Respect the no-duplicated-rules invariant: search before writing.
4. If a new area is being created, update `domain/MAP.md` (add a row with one-line description and dependencies block) and run the promotion checklist in `references/lifecycle.md`.
5. Delete the idea folder. Git history preserves it.
6. Append a one-line entry to `specs/<area>/STATUS.md` under "Ideas promoted".
7. Emit Update Manifest.

### `/traceflow:adr <slug> --type <type> [--area <area>] [--shared] [--supersedes ADR-NNN]`

Open a new ADR.

**Skill behavior:**
1. Scan `decisions/_shared/` and every `decisions/<area>/` for the highest ADR number. Allocate next sequential integer.
2. Create `decisions/<area>/ADR-NNN-<slug>.md` (or `decisions/_shared/`).
3. Scaffold from `assets/adr.md`. Set `type:` from CLI flag (must be one of the eight enum values). Set Status: `proposed`.
4. If `--supersedes ADR-MMM` is set: open ADR-MMM, change its Status to `superseded by ADR-NNN`, add a forward link. The new ADR's body MUST reference ADR-MMM. Never edit ADR-MMM's body.
5. After review, the user transitions Status to `accepted`. On accept: append a row to the area's `decisions/<area>/INDEX.md` with `ADR-NNN | type | one-line summary | accepted`.
6. Emit Update Manifest.

### `/traceflow:spec "<name>" --area <area>`

Draft a new spec.

**Skill behavior:**
1. Scan `specs/<area>/` for the highest `S0NN`. Allocate next sequential integer.
2. Create `specs/<area>/S0NN-<slug>/` with the four files scaffolded from `assets/`:
   - `brief.md` — WHAT and WHY only, no technical detail
   - `plan.md` — technical approach, spec-deltas section (typed entries), `Owns:` block (file paths + behaviors)
   - `tasks.md` — decomposed work with `[P]` parallel markers
   - `status.md` — Current state: `draft`
3. Update `specs/<area>/STATUS.md` with a new row (S0NN, name, current state).
4. Emit Update Manifest.

### `/traceflow:state set <id> <new-state> [--reason <reason>]`

Transition a spec, ADR, or area-promotion artifact through its lifecycle.

**Skill behavior:**
1. Read `references/lifecycle.md` to verify the requested transition is legal.
2. For spec `draft → ready`: verify `plan.md` spec-delta section parses (syntactic check only; ADDED targets need not exist yet). Verify all delta paths scope to `<area>/` or `_shared/`. Verify `Owns:` block is non-empty.
3. For spec `in-progress → done`: verify all delta targets resolve to real files. Verify no ADR body was edited (only Status headers). Verify no rule duplicated. Run the relevant subset of `scripts/invariants.sh`.
4. For spec `→ closed`: require `--reason` flag with one of: `superseded by S0NN`, `cancelled`, `obsolete`, `spike`, free-text justification.
5. For spec `→ archived`: re-verify deltas. Block on drift. `git mv` the folder to `specs/<area>/archive/`.
6. Update all three STATUS files atomically (per-spec, per-area, global). STATUS rows are append-only.
7. If the spec owns files declared in its `Owns:` block, update `specs/<area>/MAP.md` accordingly.
8. Emit Update Manifest.

### `/traceflow:archive <id>`

Shortcut for `/traceflow:state set <id> archived`. Same rules and re-verification.

### `/traceflow:check [--area <area>]`

Run the structural invariants suite.

**Skill behavior:**
1. Execute `scripts/invariants.sh`. Pipe results to the user.
2. Report per-invariant pass/fail with file paths involved.
3. Do NOT auto-fix. The agent's job is to surface drift, not to silently correct.
4. Emit Update Manifest naming any drift found.

### `/traceflow:map [--area <area>]`

Rebuild the `MAP.md` for an area from its specs' `Owns:` declarations.

**Skill behavior:**
1. Read every active spec's `plan.md` `Owns:` block under `specs/<area>/`.
2. Build the file-path reverse index (primary view): each declared path maps to its owning spec ID.
3. Build the behavior secondary index.
4. Write `specs/<area>/MAP.md` from `assets/map-specs.md`. Archived specs go in the "Historical" section.
5. Detect conflicts (two specs claim ownership of the same path). Report as failures; do NOT auto-resolve.
6. Emit Update Manifest.

---

## Spec-deltas (the load-bearing mechanic)

Every `plan.md` MUST include a `## Domain impact (deltas)` section. Each entry has one of these forms:

```
- ADDED domain/<area>/<file>.md#<heading>: <one-line reason>
- MODIFIED domain/<area>/<file>.md#<heading>: <what changes, why>
- REMOVED domain/<area>/<file>.md#<heading>: <why deprecated>
- ADDED decisions/<area>/ADR-NNN-<slug>.md: <ratifies what>
- MODIFIED decisions/_shared/ADR-NNN-<slug>.md: status header only (supersede / deprecate)
- NONE: <typed-class> <free-text>
```

`NONE` requires one of these typed classes (free-text alone is rejected):

- `NONE: refactor` — internal restructuring with no domain/ADR impact
- `NONE: typo` — copy fix only
- `NONE: spike` — exploratory; findings will lift to a follow-up spec
- `NONE: hotfix` — emergency; deltas applied retroactively before archive
- `NONE: tooling` — build, CI, lint, or local-dev change with no runtime impact

`MODIFIED` against an ADR is allowed for Status header changes only. ADR bodies are append-only.

Delta gates fire at three transitions:

| Transition | Check |
|---|---|
| `draft → ready` | Syntax + scope only. Target existence not required (ADDED is legal). |
| `in-progress → done` | Full resolution. All paths resolve. No ADR body edited. No rule duplicated. Per-area boundary respected. |
| `done → archived` | Re-verify. Block on drift. |

Full delta template in `assets/spec-plan.md`.

---

## Owns: block (the navigation source of truth)

Every `plan.md` MUST include an `## Owns` block declaring file paths and behaviors this spec owns:

```
## Owns

### Paths
- services/<svc>/internal/<pkg>/<file>.go
- migrations/0042_<verb>_<noun>.sql

### Behaviors
- <terse capability name>
- <terse capability name>
```

`specs/<area>/MAP.md` is conceptually a projection of every active spec's `Owns:` block. Run `/traceflow:map` after any spec transitions to `done` or `archived` to rebuild.

Ownership is exclusive at the path level: two specs MUST NOT claim the same path. On archive, ownership transfers to the spec that supersedes (named in `closed: reason`). If nothing supersedes, the path falls under area `_shared/` ownership and lives in `specs/<area>/MAP.md` "Unassigned" until a new spec adopts it.

---

## Reading map (task → files)

Full table in `references/tasks-to-files.md`. Quick summary:

| Task | Read order |
|---|---|
| Orient | `STATUS.md`, `domain/MAP.md`, `preamble.md`, `domain/glossary.md` |
| Fix bug in area A | preamble, MAP, glossary, `specs/A/MAP.md`, the owning spec's `status.md` + `plan.md` |
| Draft ADR in area A | preamble, MAP, glossary, `decisions/A/INDEX.md`, area domain `README.md` |
| Promote idea | preamble, area `STATUS.md`, area domain |
| Add area | preamble, `domain/MAP.md`, `references/single-area-collapse.md` (inverted), `references/lifecycle.md` |
| Audit drift | `scripts/invariants.sh` |

Skip files outside the task scope. Do NOT pre-read every area.

---

## Update Manifest (required end-of-turn output)

Every agent turn that performs any traceflow action MUST end with a structured manifest block:

```markdown
## Update Manifest

**Action**: <command name>
**Target**: <area / id / N/A>
**State transitions**:
- <id>: <from-state> → <to-state>

**Files written**:
- <path>: <created | edited>

**Files moved**:
- <from> → <to>

**Spec-deltas applied** (if action involved a state transition to `done` or `archived`):
- <path>: <ADDED | MODIFIED | REMOVED>

**Invariants run**:
- <invariant-name>: <pass | fail [+ details]>

**Open items for human review**:
- <e.g. ADR-021 awaiting accept>
```

Omissions are visible to human reviewers. The manifest substitutes for a validator in v0.

---

## Invariants

`scripts/invariants.sh` ships a set of bash one-liners that smoke-test structural invariants. Run via `/traceflow:check`. The starter set:

1. Every `S0NN` referenced in any `STATUS.md` resolves to a real spec folder.
2. ADR numbers are monotonic across `_shared/` + per-area buckets. No gaps. No reuse.
3. No two active specs claim ownership of the same path in their `Owns:` block.
4. Every delta target path in any spec `plan.md` either exists OR is part of an ADDED row OR is justified by a typed NONE entry.
5. No delta path or `Owns:` path crosses area boundaries (must start with `<this-area>/` or `_shared/`).
6. Every ADR has the mandatory `type:` frontmatter, valued from the enum.
7. Every `F-<slug> §<range>` anchor referenced by a behavior diagram resolves to a real `### S<N>` heading in the canonical fragment file.
8. Each fragment ID exists in exactly one file (single canonical owner across `_fragments/` buckets, including `_shared/`).
9. Cross-area fragment references resolve only under `domain/_shared/diagrams/_fragments/`.
10. Every behavior diagram (any non-composite, non-fragment `.md` under `domain/<area>/diagrams/`) has a `## Fragments used` block (a typed-`none` entry is allowed and satisfies the check).

Failures are reported, not silently fixed.

---

## Migration

If you are coming from spec-kit, OpenSpec, or an ad-hoc docs layout, see `references/migration.md`. It includes:

- field-by-field mapping from spec-kit (`spec.md → brief.md`, `plan.md → plan.md`, `tasks.md → tasks.md`, `data-model.md → domain/<area>/`, `research.md → ADR or transient research file`)
- field-by-field mapping from OpenSpec (`changes/<id>/* → specs/<area>/S0NN-*/*`, `specs/<capability>/spec.md → domain/<area>/` shared knowledge)
- the rename script for going from `integration / features / F0NN` legacy traceflow drafts to `area / specs / S0NN`

---

## File references

Top level of this skill:

- `references/lifecycle.md` — full state machines, topology, three legal paths (standard, hotfix, spike)
- `references/tasks-to-files.md` — reading map per task type
- `references/diagrams.md` — behavior-scoped diagram convention, decomposition recipe, worked example
- `scripts/invariants.sh` — bash invariants suite
- `references/migration.md` — from spec-kit, OpenSpec, ad-hoc, or legacy traceflow
- `references/examples.md` — worked example (multi-area Go monorepo)
- `references/single-area-collapse.md` — minimum-viable repo template
- `assets/` — all artifact templates

---

## Versioning and self-pinning

A `conventions-adopted` ADR records that **this project binds itself to traceflow and to some set of supporting skills**. That binding IS the project-level decision: it commits the repo to the lifecycle, the artifact axes, the diagram convention, and any repo-local deltas to the vendored scripts. The version number in the ADR body is a **snapshot of the moment the binding was decided**, not a frozen contract.

```
This area adopts:
- traceflow@0.1.0
- <other skills...>
```

### Skill version bumps are maintenance, not ADRs

Picking up a routine upstream skill bump (e.g., `0.1.0 → 0.2.0`, including draft / pre-release versions) is **maintenance**, not a project decision. Do NOT open a superseding `conventions-adopted` ADR for it. Instead:

1. Re-vendor any vendored scripts (e.g. `scripts/invariants.sh`) and re-apply documented repo-local deltas.
2. Log the bump as a one-line entry under `## Recent activity` (or the local equivalent) in the area `STATUS.md`. The git commit message names the files; the STATUS entry names the version delta and what changed.
3. Apply any consequent derived edits (e.g. diagram refactors per the new convention) as direct domain edits per the rules in "Diagrams (sub-type of domain)" and `references/diagrams.md §0`.

ADR-026's body will name the old version; that's fine — the body is a frozen snapshot, the project is on the upstream's current draft unless an ADR explicitly pins otherwise.

### When a skill change DOES warrant a new ADR

Open a superseding `conventions-adopted` ADR only when the upstream change forces a real project-level choice:

- **Deliberate version pin / freeze.** "We are staying on `0.1.0` because the `0.2.0` convention break is too costly for now" — that IS a decision.
- **Breaking change requiring repo-level adaptation.** A skill major bump that invalidates existing artifacts and forces a migration plan: the *migration approach* is the decision, not the version number itself.
- **Skill substitution.** Replacing one pinned skill with another (e.g. dropping a go-* skill in favor of a different one), or adding a wholly new skill to the binding.
- **Repo-local deltas to vendored scripts/assets** changing materially (a new exception to invariant 5, a new boundary allow-list entry, etc.).

In each of these cases the ADR records the *choice*, not the version pickup itself.
