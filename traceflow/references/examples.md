# Worked example: a Go monorepo with two areas

This example shows what a traceflow-managed Go monorepo looks like
after two areas have been established and several specs have moved
through the lifecycle. The numbers and names are illustrative.

The example deliberately uses Go because it demonstrates how
`conventions-adopted` ADRs bind language-specific skills (such as
`go-modularization`, `go-design-principles`, `go-sdk-bootstrap`)
without leaking into the core traceflow skill itself.

---

## Tree (abbreviated)

```
repo-root/
├── CLAUDE.md
├── .traceflow/
│   ├── STATUS.md
│   ├── preamble.md
│   ├── domain/
│   │   ├── MAP.md
│   │   ├── glossary.md
│   │   ├── _shared/
│   │   │   └── 00-cross-area-invariants.md
│   │   ├── ingest/
│   │   │   ├── README.md
│   │   │   ├── 10-entities.md
│   │   │   ├── 20-state-machines.md
│   │   │   ├── 30-business-rules.md
│   │   │   └── contracts/
│   │   │       └── ingest-payload.json
│   │   └── billing/
│   │       ├── README.md
│   │       ├── 10-entities.md
│   │       └── 20-state-machines.md
│   ├── decisions/
│   │   ├── _shared/
│   │   │   ├── INDEX.md
│   │   │   ├── ADR-001-conventions-adopted.md
│   │   │   ├── ADR-002-area-boundary-ingest-billing.md
│   │   │   └── ADR-007-shared-error-envelope.md
│   │   ├── ingest/
│   │   │   ├── INDEX.md
│   │   │   ├── ADR-003-postgres-with-sps.md
│   │   │   ├── ADR-005-payload-contract.md
│   │   │   └── ADR-008-retry-and-breaker.md
│   │   └── billing/
│   │       ├── INDEX.md
│   │       ├── ADR-004-stripe-as-pg.md
│   │       └── ADR-006-double-entry-ledger.md
│   ├── ideas/
│   │   └── ingest/
│   │       └── batch-replay/
│   │           ├── README.md
│   │           └── transcript.md
│   └── specs/
│       ├── ingest/
│       │   ├── STATUS.md
│       │   ├── MAP.md
│       │   ├── S001-payload-ack/
│       │   │   ├── brief.md
│       │   │   ├── plan.md
│       │   │   ├── tasks.md
│       │   │   └── status.md
│       │   ├── S002-retry-policy/
│       │   │   └── ...
│       │   └── archive/
│       │       └── S000-initial-pipeline/
│       └── billing/
│           ├── STATUS.md
│           ├── MAP.md
│           └── S001-invoice-issuance/
│               └── ...
├── services/
│   ├── ingest-orchestrator/
│   ├── ingest-worker/
│   └── billing-api/
├── go-pkgs/
├── migrations/
└── go.work
```

---

## Notable patterns

### ADR-001-conventions-adopted (in `_shared/`)

This is the cross-area conventions adoption. Single ADR pins the
versions of every skill the repo uses.

```markdown
---
adr-id: ADR-001
title: Conventions adopted
type: conventions-adopted
status: accepted
date: 2026-01-15
---

## Status

accepted

## Context

This monorepo adopts a set of agent-skills and cross-cutting
conventions. Pinning them here makes upgrades a traceable decision
rather than a silent drift.

## Decision

The repo adopts the following skills at these versions:

- `traceflow@0.1.0` (this doc lifecycle)
- `go-modularization@v1.2`
- `go-design-principles@v0.3`
- `go-sdk-bootstrap@v0.4`
- `go-code-quality-check@v0.2`

Any upgrade supersedes this ADR with a new ADR-NNN that lists the new
versions and the rationale.

## Consequences

- Each area inherits these conventions unless an area-scoped ADR of
  type `conventions-adopted` overrides specific entries.
- The skills above are the canonical source for their respective
  topics; this ADR's body does not restate their rules.
```

### ADR-002-area-boundary-ingest-billing (in `_shared/`, type `structure`)

The boundary-defining ADR. Created when the second area was promoted
out of an originally single-area repo.

### Spec S001-payload-ack in `ingest/`

Walks through every section of the templates with realistic content.
Open the actual files in `assets/` to see the shape.

The `plan.md` for this spec declares:

```yaml
---
spec-id: S001
area: ingest
title: Consumer-side payload acknowledgement
related-adrs:
  - ADR-005   # payload contract
  - ADR-008   # retry and breaker
promoted-from-idea: null
supersedes: null
---
```

Owns block:

```markdown
## Owns

### Paths

- services/ingest-worker/internal/consumer/ack.go
- services/ingest-worker/internal/consumer/retry.go
- migrations/0042_add_ack_state.sql

### Behaviors

- consumer payload ack semantics
- consumer-side retry on transient downstream failure
- ack state persistence
```

Domain impact:

```markdown
## Domain impact (deltas)

- ADDED domain/ingest/30-business-rules.md#ack-semantics: ratifies consumer-side ack rules per ADR-005
- MODIFIED domain/ingest/20-state-machines.md#consumer-state: adds the ACKED transition
- MODIFIED decisions/ingest/ADR-008-retry-and-breaker.md: status header only (no body edit)
```

### Idea `ingest/batch-replay/`

Active brainstorm. Two files:

- `README.md` — distilled prose. The current state of the team's understanding.
- `transcript.md` — append-only Q&A log. Every question the agent asked, every answer the user gave, timestamped.

When the team is ready to promote, the prose lifts into one or more
files under `domain/ingest/`. The transcript is preserved in git
history but the folder is deleted.

### specs/ingest/MAP.md

A file-path reverse index generated from every active spec's `Owns:`
block. Looks like:

```markdown
# specs/ingest/MAP.md

## Active specs (by file path)

| Path | Owner spec |
|---|---|
| services/ingest-orchestrator/internal/dispatcher/ | S003-dispatcher |
| services/ingest-worker/internal/consumer/ack.go | S001-payload-ack |
| services/ingest-worker/internal/consumer/retry.go | S001-payload-ack |
| services/ingest-worker/internal/scraper/ | S002-retry-policy |
| migrations/0042_add_ack_state.sql | S001-payload-ack |

## Active specs (by behavior)

| Behavior | Owner spec |
|---|---|
| consumer payload ack semantics | S001-payload-ack |
| consumer-side retry on transient failure | S001-payload-ack |
| dispatcher fairness | S003-dispatcher |
| ack state persistence | S001-payload-ack |

## Historical (archived specs)

| Spec | Closed reason | Archived owners (paths) |
|---|---|---|
| S000-initial-pipeline | superseded by S001-payload-ack and S002-retry-policy | services/ingest-worker/internal/consumer/ack.go (transferred to S001) |
```

---

## How an agent uses this

Suppose a user asks "fix the consumer ack timing in ingest worker".

The agent reads, in order:

1. `.traceflow/preamble.md`
2. `.traceflow/STATUS.md`
3. `.traceflow/domain/MAP.md` (sees `ingest` exists, no cross-area deps)
4. `.traceflow/domain/glossary.md`
5. `.traceflow/specs/ingest/MAP.md` → finds `services/ingest-worker/internal/consumer/ack.go` is owned by S001
6. `.traceflow/specs/ingest/S001-payload-ack/status.md` → state is `done`
7. `.traceflow/specs/ingest/S001-payload-ack/plan.md` → reads the approach and related ADRs
8. `.traceflow/decisions/ingest/ADR-005-payload-contract.md`
9. `.traceflow/decisions/ingest/ADR-008-retry-and-breaker.md`

The agent does NOT read:

- `.traceflow/specs/billing/` or any billing content
- `.traceflow/decisions/billing/` content
- Any other spec under `specs/ingest/` (only S001 is relevant)
- Any idea folder

Once the fix is scoped, the agent decides whether this is:

- A small in-place fix → open a new spec in `ingest/` of small scope, follow standard path. Its `Owns:` block extends or transfers from S001.
- A regression in S001's behavior → open a `hotfix` spec, follow hotfix path, retroactively reconcile deltas before archive.
- A discovery that S001 was wrong about ADR-008 → open a new ADR proposing the supersede, then a follow-up spec.

In every case, the Update Manifest at end-of-turn names exactly which
files changed.
