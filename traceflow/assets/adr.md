<!--
traceflow ADR template.

This file is `ADR-NNN-<slug>.md` inside `decisions/<area>/` (or
`decisions/_shared/` for cross-area decisions).

Numbering is GLOBALLY UNIQUE across _shared and every per-area
bucket. /traceflow:adr allocates the next number.

This file is APPEND-ONLY after the Status header transitions to
`accepted`. Only the Status header changes thereafter (on supersede
or deprecate). NEVER edit the body of an accepted ADR.

Required frontmatter fields are parsed by `scripts/invariants.sh`.
Do not omit `type` or `status`.
-->

---
adr-id: ADR-NNN
title: <one-line title, capitalized>
type: <one of: stack | structure | policy | operational | contract | security | data | conventions-adopted>
status: proposed
date: <YYYY-MM-DD>
area: <area name, or _shared>
supersedes: null              # or ADR-MMM if this ADR supersedes another
superseded-by: null           # set when a future ADR supersedes this one
---

# ADR-NNN: <one-line title>

## Status

proposed

<!--
On transition:
  proposed -> accepted: change to "accepted", append the area's INDEX.md row
  accepted -> superseded: change to "superseded by ADR-MMM" and link both ways. BODY UNCHANGED.
  accepted -> deprecated: change to "deprecated, <YYYY-MM-DD>, <reason>". BODY UNCHANGED.
-->

## Context

<!--
Why is this decision being made now? What forces, constraints, prior
work, or events make this a decision worth recording?

Reference:
- Domain files that this ADR ratifies or constrains
- Other ADRs in the supersede chain (if applicable)
- Specs that motivated this decision (if applicable)

Avoid restating the decision in this section. The Context describes
the situation. The Decision describes the choice.
-->

<context prose>

## Decision

<!--
The decision itself. Stated declaratively, not as a recommendation.
"We will X." Not "We should consider X."

If the ADR is of a specific type, the Decision section should be
specific to that type:

- stack:                names the chosen technology and rules out alternatives explicitly
- structure:            describes the layout, boundary, or decomposition chosen
- policy:               states the rule, scope, and exceptions
- operational:          specifies the deploy / secret / topology choice
- contract:             defines the wire format / schema / interface (or references the file that does)
- security:             specifies the threat model addressed and the chosen control
- data:                 specifies the schema choice, migration approach, or storage decision
- conventions-adopted:  lists the skills + versions adopted, with an upgrade-by-supersede policy
-->

<decision prose>

## Consequences

<!--
What follows from this decision? Include both intended and unintended.
List domain or other ADRs that this decision constrains. Be explicit
about the cost of reversing the decision (if it can be reversed).
-->

<consequences prose>

## Alternatives considered

<!--
Optional but strongly recommended. Each alternative should have:
- a one-line description
- why it was rejected

Future ADRs that supersede this one will read this section first.
-->

- <alternative>: <reason for rejection>

## References

<!--
Optional. Links to external material that informed the decision:
- prior art (other ADRs in this repo or external)
- standards or RFCs
- vendor docs
- benchmarks

Internal references (other ADRs, domain files) are preferred over
external links.
-->

- <reference>
