<!--
traceflow specs MAP template.

This file is `specs/<area>/MAP.md`.

Generated (or hand-maintained as a projection of) every active
spec's `Owns:` block. Primary view: file path → owning spec.
Secondary view: behavior → owning spec. Archived specs in a
separate historical section.

Run /traceflow:map to rebuild from spec Owns blocks. Conflicts
(two specs claiming the same path) are reported, not silently
resolved.

Keep this file under 300 lines per area. If it exceeds, partition
by subsystem (e.g. one MAP per service inside the area).
-->

# specs/<area>/MAP.md

File-path and behavior reverse index for the `<area>` area. Use this
to answer "which spec owns this file or capability?" without reading
every spec.

## Active specs (by file path)

<!--
Primary view. Each path maps to exactly one active spec. If a path
is touched by two or more specs, /traceflow:check will fail.
Resolve before mapping.

Path conventions:
- repo-relative paths
- directories use a trailing slash; ownership is transitive over the directory's children
-->

| Path | Owner spec | Behavior |
|------|------------|----------|
| `<path>` | `S0NN-<slug>` | <one-line capability> |

## Active specs (by behavior)

<!--
Secondary view. Captures capabilities that don't map cleanly to one
path (e.g. "auth flow", "anti-detection rule set"). Each behavior
maps to exactly one active spec.
-->

| Behavior | Owner spec | Implementing paths |
|----------|------------|---------------------|
| `<behavior>` | `S0NN-<slug>` | `<paths>` |

## Unassigned

<!--
Optional. Paths or behaviors that were owned by archived specs and
have not been adopted by a new spec. When a new spec adopts one,
move the row up to the active sections and remove it here.

If this section grows, it is a strong signal that an area needs a
follow-up spec.
-->

| Path or behavior | Last owner (archived) | Notes |
|-------------------|------------------------|-------|
| `<item>` | `S0NN-<slug>` | <why unowned> |

## Historical (archived specs)

<!--
Append-only. When a spec is archived, its rows move here. If
ownership was transferred to a superseding spec, note the
successor.
-->

| Spec | Closed reason | Transferred to |
|------|----------------|----------------|
| `S0NN-<slug>` | `<reason>` | `S0MM-<slug>` (or "unassigned") |
