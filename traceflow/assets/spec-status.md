<!--
traceflow spec status template.

This file is `status.md` inside `specs/<area>/S0NN-<slug>/`.

Tracks the current lifecycle state of the spec. Updated on every
state transition. Parseable frontmatter is mandatory; `scripts/invariants.sh`
reads the `state:` field.

State machine (full version in references/lifecycle.md):

  draft → ready (optional) → in-progress → done → closed → archived

`ready` may be skipped (hotfix / solo). `closed` requires `reason:`.

The Corrections log appends an entry every time the state changes
or an unexpected event occurs (e.g. a drift detected during a
delta gate).
-->

---
spec-id: S0NN
area: <area>
state: draft
state-history:
  - { state: draft, at: <YYYY-MM-DD>, by: <author or agent> }
closed-reason: null      # only set when state == closed
contexts-touched: []     # paths or behaviors actively edited; informational
adr-dependencies: []     # ADRs cited in plan.md (informational; canonical list is in plan.md frontmatter)
---

# Status: <title>

## Current state

`<draft | ready | in-progress | done | closed | archived>`

<!--
Mirror the frontmatter `state:` field here in readable form.
If state is `closed`, also restate the reason here in one line.
-->

## Contexts touched

<!--
Optional. The high-level surfaces actively touched by this spec.
Use behavior names from plan.md Owns block, plus any cross-cutting
surfaces (logging, telemetry, auth).
-->

- <surface>

## ADR dependencies

<!--
ADRs this spec relies on, cited from plan.md. If any of these is
superseded during this spec's lifetime, the spec MAY need a delta
update.
-->

- ADR-NNN — <one-line title>

## Out-of-scope reminders

<!--
Reminders the agent should keep in mind while implementing.
Often mirrors the brief's non-goals plus operational warnings.
-->

- <reminder>

## Corrections log

<!--
Append-only. Each entry has:
- timestamp
- event (state transition, drift detected, ADR superseded, etc.)
- one-line description

Newest entries at the bottom.
-->

### <YYYY-MM-DD HH:MM> — created

Spec scaffolded in `draft` state.

<!--
Subsequent entries follow this pattern. Example:

### 2026-05-13 09:14 — draft → ready

Delta syntax verified. All target paths well-formed and area-scoped.
Awaiting implementation.

### 2026-05-15 14:02 — drift detected during done gate

ADR-005 was superseded by ADR-009 during in-progress. plan.md
delta entries updated to reference ADR-009. Re-running done gate.
-->
