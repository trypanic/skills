<!--
traceflow spec tasks template.

This file is `tasks.md` inside `specs/<area>/S0NN-<slug>/`.

Holds the decomposition: small, reviewable work units. Each task
should be testable in isolation. Aim for 30-minute to 2-hour units.
Anything larger should be split.

`[P]` markers indicate tasks that can run in parallel with the
preceding tasks marked `[P]`. Sequential tasks have no marker.

Tasks reference paths from the spec's `plan.md` Owns block where
applicable. They do NOT introduce new ownership; ownership is
declared in plan.md.
-->

---
spec-id: S0NN
area: <area>
---

# Tasks: <title>

## Overview

<!--
One paragraph describing the task structure. How are tasks grouped?
Are there phases? What is the critical path? Are there parallel
streams?
-->

<overview prose>

## Phase 1: <phase name>

<!--
Each task:
- numbered globally (T01, T02, ...) for traceability
- a short imperative title
- [P] marker if parallelizable with sibling [P] tasks
- an acceptance criterion (how do you know it is done?)
- the paths it touches (from plan.md Owns block)
-->

### T01. <imperative title>

- **AC**: <observable criterion>
- **Paths**: <path/from/Owns>
- **Notes**: <optional context>

### T02. [P] <imperative title>

- **AC**: <observable criterion>
- **Paths**: <path/from/Owns>

### T03. [P] <imperative title>

- **AC**: <observable criterion>
- **Paths**: <path/from/Owns>

## Phase 2: <phase name>

### T04. <imperative title>

- **AC**: <observable criterion>
- **Paths**: <path/from/Owns>
- **Depends on**: T01, T02, T03

## Verification

<!--
Tasks that verify the spec as a whole, not individual capabilities.
Typically integration tests, end-to-end scenarios, or invariant
checks.
-->

### T-V1. Run `scripts/invariants.sh`

- **AC**: all invariants pass
- **Paths**: (none modified; verification only)

### T-V2. <integration scenario>

- **AC**: <observable outcome end-to-end>
- **Paths**: (depends on Owns)

---

## Task lifecycle

Tasks are not separately stateful in v0 of traceflow. They are
checklist items inside this file. The agent (or human) marks them
done by editing the file and updating `status.md`.

When ALL tasks have a satisfied AC, the spec is eligible to
transition `in-progress → done` (run `/traceflow:state set S0NN done`).
The state transition triggers the delta-resolution gate.
