<!--
traceflow spec plan template.

This file is `plan.md` inside `specs/<area>/S0NN-<slug>/`.

Replace every `<placeholder>` and remove this comment block once filled.

This file holds HOW (technical approach + traceability artifacts).
The sibling `brief.md` holds WHAT and WHY (user-facing intent).
The sibling `tasks.md` holds the decomposition (with [P] parallel markers).
The sibling `status.md` holds the lifecycle state — NOT this file.

Required sections, parsed by `scripts/invariants.sh`. Do not rename:
- `## Owns`
- `### Paths` (under Owns)
- `### Behaviors` (under Owns)
- `## Domain impact (deltas)`

Optional sections may be deleted if empty: Architecture sketch, Open questions, Out of scope.

An example block sits at the bottom of this template. Delete the example
section once your spec is filled. The example shows valid syntax for the
deltas and Owns block.
-->

---
spec-id: S0NN
area: <area>
title: <human-readable name>
related-adrs:
  - ADR-NNN
  - ADR-MMM
promoted-from-idea: ideas/<area>/<topic>/
supersedes: null  # or S0MM
---

# Plan: <human-readable name>

## Approach

<!--
One to three paragraphs. Technical approach: WHAT the change builds and HOW.
Reference ADRs where relevant. Do NOT restate user-facing intent (that lives in brief.md).
Cite the durable artifacts the agent should keep loaded while implementing:
which ADRs, which domain files, which Owns paths from prior specs (if extending).
-->

<approach prose>

## Architecture sketch

<!--
Optional. Diagrams (mermaid, ASCII), sequence flows, component boundaries.
Delete this entire section if not needed.
-->

```mermaid
<diagram or delete the section>
```

## Owns

<!--
Exclusive ownership at the path level. No other ACTIVE spec may claim
the same path. specs/<area>/MAP.md is the projection of every active
spec's Owns block. Run /traceflow:map after this spec transitions to
done or archived.

Path conventions:
- Use repo-relative paths from the repository root.
- A path may be a file OR a directory; directories imply ownership of
  every file inside transitively.
- Behaviors are short capability names, not sentences.

Ownership transfer on closure:
- On close-with-supersede, ownership transfers to the superseding spec
  (named in the `reason:` field of status.md).
- On close-without-supersede, paths fall to the area "Unassigned"
  section of specs/<area>/MAP.md until adopted by a future spec.
-->

### Paths

- <path/to/file.ext>
- <path/to/directory/>

### Behaviors

- <capability name>
- <capability name>

## Domain impact (deltas)

<!--
Every spec MUST declare its impact on durable artifacts (domain and ADRs).
This section is the load-bearing traceability mechanism.

Gates fire on three transitions:
  draft → ready:        syntax + scoping only. ADDED targets need not exist yet.
  in-progress → done:   all paths resolve. ADR bodies untouched. No rule duplicated.
                        Per-area boundary respected.
  done → archived:      re-verify. Block on drift.

Per-area boundary: every path must start with `<this-area>/` or `_shared/`.

ALLOWED ENTRY FORMS:

  - ADDED domain/<area>/<file>.md#<heading>: <one-line reason>
  - MODIFIED domain/<area>/<file>.md#<heading>: <what changes, why>
  - REMOVED domain/<area>/<file>.md#<heading>: <why deprecated>
  - ADDED decisions/<area>/ADR-NNN-<slug>.md: <ratifies what>
  - MODIFIED decisions/_shared/ADR-NNN-<slug>.md: status header only (supersede / deprecate)
  - NONE: <typed-class> <free-text>

TYPED NONE CLASSES (free-text NONE without a class is rejected):

  - NONE: refactor   internal restructuring with no domain/ADR impact
  - NONE: typo       copy fix only
  - NONE: spike      exploratory; findings will lift to a follow-up spec
  - NONE: hotfix     emergency; deltas applied retroactively before archive
  - NONE: tooling    build, CI, lint, or local-dev change with no runtime impact

MODIFIED against an ADR is allowed ONLY for Status header changes
(supersede or deprecate). ADR bodies are append-only after acceptance.
-->

- <delta entry>

## Open questions

<!--
Items that MUST be resolved before /traceflow:state set S0NN ready.
Each question should be answerable in this spec or by opening a new ADR.
Delete this section if there are no open questions.
-->

- <open question>

## Out of scope

<!--
Explicit exclusions to prevent scope creep. Each exclusion should say
what is excluded AND why (often: tracked in another spec, deferred,
or not relevant). Delete this section if not needed.
-->

- <excluded concern>: <reason>

---

## Example (delete this section once your spec is filled)

The example below shows valid syntax for a fictitious spec
`S010-worker-downstream-consumer` in area `amazon-scrape-system`.
It is here so you can copy the shape, not the content.

### Approach (example)

Implement the consumer-side payload acknowledgement using the wire
format ratified in `ADR-025-consumer-payload-contract`. Apply the
breaker thresholds from `ADR-017-worker-retry-and-breaker`. Bridge to
the downstream consumer via the existing producer interface from
`go-pkgs/messaging`. Persist ack state through a stored procedure per
`ADR-003-postgres-with-sps`.

### Owns (example)

#### Paths (example)

- services/amazon-scrape-worker/internal/consumer/ack.go
- services/amazon-scrape-worker/internal/consumer/retry.go
- migrations/0042_add_amz_ack_state.sql

#### Behaviors (example)

- consumer payload ack semantics
- consumer-side retry on transient downstream failure
- ack state persistence

### Domain impact (deltas) (example)

- ADDED domain/amazon-scrape-system/70-contracts.md#consumer-payload: ratifies wire format from ADR-025
- MODIFIED domain/amazon-scrape-system/30-business-rules.md#retry-and-breaker: clarifies consumer-side breaker thresholds
- ADDED decisions/amazon-scrape-system/ADR-025-consumer-payload-contract.md: ratifies wire format
- MODIFIED decisions/amazon-scrape-system/ADR-017-worker-retry-and-breaker.md: status header only (clarifies scope, no body edit)

### Open questions (example)

- Should ack timeouts inherit from the orchestrator config or be locally tuned? Likely opens ADR-026.

### Out of scope (example)

- producer-side retry policy: owned by S004
- ack metric emission: deferred to S012
