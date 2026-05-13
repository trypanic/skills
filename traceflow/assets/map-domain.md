<!--
traceflow domain MAP template.

This file is `domain/MAP.md`.

Topology of areas + dependencies. The first thing an agent reads
after `preamble.md` and `STATUS.md` when orienting.

Keep this file under 200 lines. If it grows beyond that, split
content into per-area README.md files and keep MAP.md as a pure
topology.

The Dependencies block is structured (YAML-like) so the agent can
parse it without ambiguity.
-->

# Domain MAP

Topology of areas and their dependencies. Read this before opening
any area folder.

## Areas

<!--
One row per area. Status is informational only (the canonical state
lives in `.traceflow/STATUS.md`).

The "One-line description" must be ONE LINE. If it does not fit on
one line, the area is poorly named or the line is too verbose.
-->

| Area | Folder | Status | One-line description |
|------|--------|--------|----------------------|
| `<area>` | [`<area>/`](<area>/) | <live / drafting / dormant> | <one-line description> |

## Dependencies

<!--
Machine-parseable. Each block names an area and the areas it depends
on. Direction: "depends on" means runtime, contract, or rule
dependence; not commit-order.

If an area is self-contained, omit it from this list (its absence
is the declaration).
-->

```yaml
dependencies:
  - from: <area>
    to: <other-area>
    nature: contract       # one of: contract | data | runtime | policy
    via: ADR-NNN           # the cross-area ADR that ratifies the edge
```

## Promotion criteria

<!--
A new area is created when at least one is true. Re-stated here
because this file is the natural place to read the rule:
-->

A new area gets its own subfolder when at least one is true:

- More than one rules-equivalent file is needed (rules diverge in topic).
- Three or more strongly related entities exist that no other area touches.
- A separate state-machine surface exists (different lifecycles).
- A distinct anti-pattern or constraint set applies.

Promotion is registered HERE in MAP.md and accompanied by an ADR
of type `structure` in `decisions/_shared/`.

## Notes

<!--
Free-form. Use this for:
- one-off observations about the topology
- pointers to historical ADRs explaining why the current layout is what it is
- known tensions awaiting future resolution

Keep notes terse. Long notes belong in domain files, not the MAP.
-->

- <note>
