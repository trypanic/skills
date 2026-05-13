# Reading map: task → files

The agent MUST follow this map. Do not read files outside the listed
set for a given task unless an explicit need surfaces.

Token budgets at the top of common entry-point files:

- `.traceflow/preamble.md` ≤ 60 lines
- `.traceflow/STATUS.md` ≤ 200 lines
- `.traceflow/domain/MAP.md` ≤ 200 lines
- `.traceflow/domain/glossary.md` ≤ 500 lines
- `specs/<area>/MAP.md` ≤ 300 lines per area

If any file exceeds its budget, treat it as a drift signal. Open a
follow-up spec or partition (glossary partitions area-specific terms
to `domain/<area>/glossary.md`).

---

## Orient (cold start)

The agent has no prior context and needs to understand the repo.

Read in order:

1. `.traceflow/STATUS.md` (global phase per area)
2. `.traceflow/preamble.md` (reading map and hard rules)
3. `.traceflow/domain/MAP.md` (topology of areas + dependencies)
4. `.traceflow/domain/glossary.md` (transversal terms)

Stop. Do NOT pre-load any area's content until a specific task arrives.

---

## Fix a bug in area `<A>`

1. `.traceflow/preamble.md`
2. `.traceflow/domain/MAP.md`
3. `.traceflow/domain/glossary.md`
4. `specs/<A>/MAP.md` (reverse-index by file path to find owning spec)
5. The owning spec's `status.md` + `plan.md` (current state, technical context, Owns block)
6. Relevant domain files in `domain/<A>/` (cited in the spec's plan)
7. Relevant ADRs cited in the spec's `related-adrs` frontmatter

Skip:
- Other areas entirely.
- The full `decisions/<A>/INDEX.md` unless you cannot locate the right ADRs from the spec's frontmatter.

---

## Extend an existing capability in area `<A>`

Same as "Fix a bug" plus:

- The existing spec's `tasks.md` (to understand what was previously decomposed)
- Sibling specs whose `Owns:` blocks overlap on adjacent paths (read those `plan.md` headers only, not full bodies)

---

## Draft a new ADR in area `<A>`

1. `.traceflow/preamble.md`
2. `.traceflow/domain/MAP.md`
3. `.traceflow/domain/glossary.md`
4. `decisions/<A>/INDEX.md` (full read; agent needs the ADR landscape)
5. `decisions/_shared/INDEX.md` (cross-area context)
6. `domain/<A>/README.md` and any domain files referenced by the new ADR
7. Any ADRs flagged for supersede in the new draft

Skip: specs and ideas.

---

## Promote an idea to domain

1. `.traceflow/preamble.md`
2. The idea folder: `ideas/<area>/<topic>/README.md` and `transcript.md`
3. `domain/<area>/` (full read of target files; you must check for rule duplication before promoting)
4. `domain/glossary.md` (check if new terms collide)
5. `specs/<area>/STATUS.md` (you will append a promotion log entry)

Skip: specs, ADRs (unless the promotion necessitates a new ADR).

---

## Draft a new spec in area `<A>`

1. `.traceflow/preamble.md`
2. `.traceflow/domain/MAP.md`
3. `.traceflow/domain/glossary.md`
4. `domain/<A>/README.md` and the domain files the spec's `plan.md` will cite
5. `decisions/<A>/INDEX.md` (find existing ADRs to cite or supersede)
6. `decisions/_shared/INDEX.md`
7. `specs/<A>/MAP.md` (verify no ownership conflicts with declared `Owns:` paths)
8. `specs/<A>/STATUS.md` (find the next `S0NN` and verify naming)

Skip: ideas (the brainstorm should have been promoted already), other areas.

---

## Move a spec through state transitions

1. `references/lifecycle.md` (verify transition is legal)
2. `specs/<A>/S0NN/status.md` (current state)
3. `specs/<A>/S0NN/plan.md` (delta gates require this)
4. `scripts/invariants.sh` (run before `done` or `archived`)
5. STATUS files at the three levels:
   - `specs/<A>/STATUS.md`
   - `.traceflow/STATUS.md`

Skip: other specs unless the transition involves supersede semantics.

---

## Archive a spec

Same as "Move a spec through state transitions" plus:

- Re-run the relevant subset of `scripts/invariants.sh` before the
  `git mv`.
- After move: rebuild `specs/<A>/MAP.md` to reflect the spec moving
  to the Historical section.

---

## Run an audit (drift check)

1. `scripts/invariants.sh` (full run)

Report results. Do NOT read individual specs in response to invariant
failures unless the agent intends to open a corrective spec.

---

## Add a new area

1. `references/lifecycle.md` (promotion criteria)
2. `references/single-area-collapse.md` (the inverse: what gets unfolded)
3. `.traceflow/domain/MAP.md` (you will add a row + dependency edges)
4. `.traceflow/STATUS.md` (you will add a row for the new area)

After scaffolding, open an ADR in `decisions/_shared/` of type
`structure` to record the boundary choice.

---

## Cross-area refactor

This is the most expensive task type. The agent SHOULD push back if
the work can be split into per-area specs that coordinate via a
`_shared/` ADR.

If genuinely necessary:

1. `references/lifecycle.md` (per-area boundary section)
2. `.traceflow/domain/MAP.md` (current dependency edges)
3. `decisions/_shared/INDEX.md` (existing cross-area ADRs)
4. Per affected area:
   - The owning specs of any touched files (via `specs/<area>/MAP.md`)
   - The domain files those specs cite

Open one spec PER AREA, plus one `_shared/` ADR. Do NOT open a spec
in `_shared/`; specs are area-scoped. The `_shared/` ADR coordinates
the cross-area work; each per-area spec implements its slice.

---

## What never to do

- Read every spec in an area to find the one you want. Use `specs/<area>/MAP.md`.
- Read every ADR to find the relevant one. Use `INDEX.md`.
- Read another area's domain or specs when working in your area.
- Read `transcript.md` unless you are continuing an active brainstorm.
- Read `archive/` contents unless you are investigating supersede chains.
