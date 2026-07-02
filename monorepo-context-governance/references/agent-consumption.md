# Agent Consumption

## Reading Map

TL;DR: The baseline (Tiers 0–2) needs no custom tooling: agents read instruction files, resolve the context, read `context.md`, follow links, and classify the task before editing. `context-map.yaml` is an optional Tier 3 optimization — never a dependency of the model.

Read:

- "Baseline" when writing AGENTS.md/CLAUDE.md instructions.
- "Task classification" — the 4-way gate before any edit.
- "Tier 3 context-map" only when a team invests in routing.

## Baseline (Tiers 0–2): No Custom Tooling

Agents that exist today read instruction files and search. The bundle serves them without a loader:

1. Resolve the target context via `docs/registry.yaml` or `docs/index.md` (by id, alias, service, module, or entrypoint path).
2. Read the context's `context.md`. Treat frontmatter as authoritative facts.
3. Follow links from the body and the generated `index.md` for progressive disclosure — descend, don't bulk-load.
4. Load only touched contracts, relevant entrypoints, and relevant tests.
5. Never read another context's internals normatively. Investigative reading is allowed but must not create a dependency; if stable knowledge is needed, the owner publishes a contract.
6. Tolerate missing optional fields, unknown types, and broken links (OKF permissive consumption). Report them; do not fail on them.

Be honest about what this is: navigation conventions plus instructions, consumed by an LLM. Selection is good, not deterministic — do not claim or design for deterministic routing.

Paste `assets/agents-instructions.template.md` into the repo's `AGENTS.md` / `CLAUDE.md` to wire this up.

## Task Classification (before any edit)

| Classification | Meaning | Action |
| --- | --- | --- |
| `implementation_defect` | Code violates an existing contract, workflow, context.md fact, or ADR. | Change code/tests. Do not alter the source of truth unless it is incomplete or stale. |
| `knowledge_defect` | Implementation is reasonable; the source of truth is missing, stale, ambiguous, or contradictory. | Update the knowledge artifact first or in the same change set. Then align code if needed. |
| `contract_or_boundary_change` | The request modifies a published contract, consumed dependency, ownership, dependency, or entrypoint. | Follow versioning, impact, and ADR rules before changing implementation. |
| `ambiguous_case` | Unclear whether code or knowledge is wrong. | Do not guess silently. Surface the conflicting artifacts and propose the smallest valid change path. |

## Read Boundaries

Load:

```text
context.md (frontmatter + body)
+ task-relevant docs reached via links/index
+ touched published/consumed contracts
+ declared entrypoints and tests
```

Do not load:

```text
all docs, all references, all ADRs
other contexts' internals
```

Optimize for task-relevant context, not exhaustive reading.

## Guardrails (always)

- never redefine a consumed contract;
- never modify a published contract without a version bump;
- never depend on another context's internals;
- never change a context identity without an ADR;
- never treat references as source of truth;
- never hand-edit generated files (`index.md` listings, `registry.yaml`).

## Tier 3 (optional): `context-map.yaml`

When a team's agent workflow matures enough to invest in routing, a context may add `context-map.yaml` (`assets/context-map.template.yaml`):

- task patterns are **free strings** matched by the agent — there is no closed intent vocabulary;
- each task entry lists a read set (the allowlist — no do-not-read lists), contracts to inspect, entrypoints, and ADR triggers;
- symptom entries route to specific runbooks;
- guardrails carry over as above.

A context without a map is fully valid. The map is an optimization; never require it, never block on its absence.
