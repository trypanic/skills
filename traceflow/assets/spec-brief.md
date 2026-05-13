<!--
traceflow spec brief template.

This file is `brief.md` inside `specs/<area>/S0NN-<slug>/`.

Holds WHAT and WHY (user-facing intent). NOT technical detail
(that lives in `plan.md`). NOT decomposition (that lives in `tasks.md`).
NOT state (that lives in `status.md`).

Keep this short. One screen. The brief is what gets quoted in PRs,
in stand-ups, in onboarding. If it does not fit on one screen,
either the spec is too big (split it) or the brief is over-detailed.
-->

---
spec-id: S0NN
area: <area>
title: <one-line, human readable>
priority: <high | medium | low>
related-ideas:
  - ideas/<area>/<topic>/   # or empty list if not promoted from an idea
---

# Brief: <title>

## What

<!--
One paragraph. The capability or fix this spec delivers, in
user-facing language. No technical jargon.

If a user can describe what changes after this spec ships in one
sentence, you have the brief. If not, refine.
-->

<one-paragraph WHAT>

## Why

<!--
One or two paragraphs. Why now? What problem does this solve?
What happens if this doesn't ship?

Cite domain rules or constraints by name (without restating them).
Cite the ADRs that motivated this spec.
-->

<WHY prose>

## Success criteria

<!--
What does "done" look like from a user perspective? Bullet points.
Each criterion should be:
- observable (you can tell whether it holds)
- testable (you can verify it without reading the implementation)

These are NOT technical task completion. They are outcomes.
-->

- <observable, testable outcome>
- <observable, testable outcome>

## Non-goals

<!--
What is this spec explicitly NOT doing? Often the most useful
section. Each non-goal should:
- name the thing
- explain why it is out of scope (deferred, owned by another spec, irrelevant)
-->

- <non-goal>: <reason>

## Related work

<!--
Optional. Other specs, ideas, or ADRs that overlap with or precede
this one. Lets reviewers locate context quickly.
-->

- <reference>
