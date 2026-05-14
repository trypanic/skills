<!--
traceflow diagram-fragment template.

This file is `_fragments/F-<slug>.md` inside `domain/<area>/diagrams/`
(or `domain/_shared/diagrams/_fragments/F-<slug>.md` for cross-area
fragments).

A FRAGMENT is a reusable sub-sequence — an envelope, a handshake, a
sub-transaction — referenced (never redrawn) by behavior diagrams.

Hard rules for fragments:
- Exactly ONE canonical-owner file per fragment ID.
- Steps are numbered (`### S1.`, `### S2.`, ...) so behavior diagrams
  can anchor by step-range (e.g. `F-announce-start §S1-S3`).
- Cross-area consumption requires the fragment to live under
  `domain/_shared/diagrams/_fragments/`.
- Fragments do NOT declare `## Fragments used` (they do not consume
  other fragments). A fragment that grows another fragment-shaped
  surface should be split.

Required headings (parsed by invariants):
- `## Purpose`
- `## Participants`
- `## Diagram`
- `## Steps`  (with `### S1.` ... `### SN.` subheadings)
-->

# F-<slug> — <one-line fragment title>

## Purpose

<!--
One sentence: what semantic surface this fragment represents.
Cite the ADR or contract that anchors it, if any.
-->

<purpose-sentence>

## Anchored by

<!--
Optional. ADR or contract reference that makes this a stable surface
(satisfies the ADR-anchored arm of the promotion bar). Omit if
qualifying only by the two-consumers arm.
-->

- <ADR-NNN-slug> §<section>

## Participants

<!--
Mermaid participant block, declared once. Behavior diagrams that
consume this fragment MUST declare the same participants with the
same aliases.
-->

```mermaid
participant <Alias> as <Name>
participant <Alias> as <Name>
```

## Diagram

<!--
The canonical body of the fragment. This is what behavior diagrams
otherwise WOULD redraw — by referencing this fragment they avoid
duplication.

Keep the diagram minimal: only the steps this fragment represents.
Do not extend the fragment with downstream/upstream context.
-->

```mermaid
sequenceDiagram
    autonumber
    <fragment body>
```

## Steps

<!--
Numbered breakdown of the diagram steps. Each `### SN.` subheading
is anchorable from behavior diagrams as `F-<slug> §SN` or as a range
`§S1-S3`. Keep labels short and stable — renaming an anchor breaks
every consumer.
-->

### S1. <short label>

<one-line description of the step>

### S2. <short label>

<one-line description of the step>

## Consumers

<!--
Optional but recommended. List behavior diagrams that consume this
fragment. Maintained manually; reverse-indexed by invariant.
-->

- `<NN>-<behavior-slug>.md`
- `<NN>-<behavior-slug>.md`

## Cross-reference

<!--
Standard cross-reference block matching other diagrams.
-->

- Operations: <OP-NN>
- Decisions: <ADR-NNN>
- Rules: <BIZ-NN>
- Invariants: <INV-NN>
