<!--
traceflow idea README template.

This file is `README.md` inside `ideas/<area>/<topic-slug>/`.

The idea folder exists in state `iterating` for as long as this folder
is present. Promotion or abandonment is a deliberate commit that
deletes the folder.

A sibling `transcript.md` holds the Q&A log. This README is the
distilled prose; the transcript is the audit trail.
-->

# Idea: <topic name>

**Area**: <area>
**Started**: <YYYY-MM-DD>
**State**: iterating

## Question

<!--
One paragraph. What problem is being explored? What is currently
unclear? Avoid stating the answer here; that emerges as the idea
matures.
-->

<the open question>

## Current understanding

<!--
Prose that captures the most stable parts of the brainstorm to date.
This section grows as the team learns. Speculation should be labeled
as such.
-->

<distilled prose, multiple paragraphs as the brainstorm matures>

## Tentative entities

<!--
Optional. Names + one-line descriptions of entities that might exist
in the eventual domain model. Skip if too early.
-->

- `<entity>`: <one-line description>

## Tentative rules or invariants

<!--
Optional. Rules that seem stable. Label confidence level (high,
medium, low). These rules are NOT canonical until promoted to
`domain/<area>/`.
-->

- (high) <rule>
- (medium) <rule>
- (low) <rule, labeled speculation>

## Open questions

<!--
Questions that remain. Answer them in `transcript.md` exchanges,
then summarize the answer back into this README.
-->

- <open question>

## Promotion criteria

<!--
Conditions under which this idea should be promoted to domain.
At least one must be true:

- The content has been stable for two or more iterations.
- It has been validated against a concrete scenario.
- A downstream ADR or spec needs to reference it.

Mark each criterion as met (✓) or pending. When all are met or one is
strongly met, run /traceflow:domain to promote.
-->

- [ ] stable across two or more iterations
- [ ] validated against scenario: <scenario name>
- [ ] downstream artifact needs it: <ADR or spec name>

## Out of scope

<!--
Topics this idea explicitly excludes. Stops the brainstorm from
sprawling.
-->

- <topic>: <reason it is excluded>

---

## Workflow notes

- Every Q&A exchange between the user and an agent must append a
  timestamped entry to `transcript.md`.
- Distill prose updates into this README. Do not let the transcript
  become the source of truth for the understanding; the README is.
- When promoting, the README's "Current understanding", "Tentative
  entities", and stable rules become the basis for files under
  `domain/<area>/`.
- After promotion, this folder is deleted.
