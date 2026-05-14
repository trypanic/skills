<!--
traceflow diagram-behavior template.

This file is `<NN>-<slug>.md` inside `domain/<area>/diagrams/`.

A BEHAVIOR diagram visualizes ONE decision branch, outcome, or
variant. It is the slice that is UNIQUE to this behavior; anything
shared with other behaviors is consumed by anchor reference to a
fragment under `_fragments/` (canonical-owner rule).

Hard rules for behavior diagrams:
- MUST declare a `## Fragments used` block (may state `- none` with a
  justification line, analogous to NONE in spec-deltas).
- MUST NOT redraw the canonical body of any fragment it consumes.
  Splice points appear as Mermaid `Note over` markers pointing at the
  fragment anchor.
- Cross-area fragment refs only resolve under
  `domain/_shared/diagrams/_fragments/`.

Required headings (parsed by invariants):
- `## What / When / Who`
- `## Diagram`
- `## Steps`            (numbered: ### S1., ### S2., ...)
- `## Fragments used`
- `## Cross-reference`
-->

# <NN> — <human-readable behavior name>

## What / When / Who

<!--
Three-line summary. The same shape as legacy traceflow flow files.
-->

- **What:** <one paragraph: the slice unique to THIS behavior>
- **When:** <preconditions, what triggers this branch>
- **Who:** <participants — must match the Mermaid participant block>

## Diagram

<!--
Mermaid (sequence, state, flowchart, ER, etc.). Convention applies to
ALL Mermaid kinds, not only sequence.

Splice fragments via Mermaid notes:

    Note over <Alias1>,<Alias2>: ⟶ F-<slug> §S1-S3

The note text MUST begin with `⟶ ` followed by the anchor. Invariant
7 parses this prefix to extract anchors.
-->

```mermaid
sequenceDiagram
    autonumber
    participant <Alias> as <Name>
    participant <Alias> as <Name>

    Note over <Alias1>,<Alias2>: ⟶ F-<slug> §S1-S3

    <behavior-unique steps here>

    Note over <Alias1>,<Alias2>: ⟶ F-<slug> §all
```

## Steps

<!--
Numbered breakdown of the behavior-unique steps. Steps imported from
fragments are NOT re-listed here; they are summarized by the
splice-point notes inside the diagram.

Keep labels short. Renaming an anchor breaks consumers (other
behavior diagrams or composite rollups).
-->

### S1. <short label>

<one-line description of the step unique to this behavior>

### S2. <short label>

<one-line description>

## Fragments used

<!--
The diagram-axis analog of `## Owns` in spec plans. Every fragment
the diagram consumes appears here with a step-range and a one-line
purpose. The `- none` form requires a typed justification class.

ALLOWED ENTRY FORMS:

  - F-<slug> §S<N>             (single step)
  - F-<slug> §S<N>-S<M>        (range)
  - F-<slug> §all              (entire fragment)
  - none: standalone           (justification: this behavior has no
                                reusable sub-sequences)
  - none: speculative          (a future fragment is anticipated but
                                a single consumer is insufficient to
                                promote per the promotion bar)

Cross-area fragments are referenced by their `_shared/` path
component when ambiguity exists:
  - _shared/F-<slug> §S<N>-S<M>
-->

- F-<slug> §S<N>-S<M> — <one-line role in this behavior>
- F-<slug> §all — <one-line role>

## Key notes

<!--
Optional. 2-5 bullets on semantic highlights specific to this
behavior. NOT a place to restate fragment content.
-->

- <note>

## Cross-reference

<!--
Standard cross-reference block matching legacy flow files.
-->

- Scenario: <scenario-id>
- Operations: <OP-NN>
- Decisions: <ADR-NNN>
- Rules: <BIZ-NN>
- Invariants: <INV-NN>
- Domain: <file>.md §<section>
