<!--
traceflow global STATUS template.

This file is `.traceflow/STATUS.md`.

Global index. High-level phase per area + recent shared activity.
Useful for resuming work after a break, onboarding, or answering
"what is happening in this repo right now?"

Keep this file under 200 lines. If it grows beyond that, the rows
are too verbose. Each area gets ONE LINE of phase plus a "recent
activity" pointer.

The canonical operational dashboard for each area is
`specs/<area>/STATUS.md`. THIS file is the global index.
-->

# STATUS

Global view across all areas. Each row points to per-area STATUS
for detail.

## Areas

<!--
One row per area. Phases (informal; pick what fits):
- setup
- early-design
- active-development
- stable
- maintenance
- dormant

Last activity is informational; the per-area STATUS holds detail.
-->

| Area | Phase | Last activity | Per-area STATUS |
|------|-------|---------------|-----------------|
| `<area>` | <phase> | <YYYY-MM-DD, one-line summary> | [`<area>/STATUS.md`](specs/<area>/STATUS.md) |

## Recent shared activity

<!--
Append-only. Cross-area events:
- new `_shared/` ADRs
- area boundary changes (promotions, retirements)
- repo-wide convention changes

Each entry: timestamp + one line. Newest at top.
-->

### <YYYY-MM-DD> — <one-line event>

<one-line context>

## Shared ADRs

<!--
Pointer to the _shared/INDEX.md. Do NOT duplicate ADR rows here.
This block is a navigation hint.
-->

See [`decisions/_shared/INDEX.md`](decisions/_shared/INDEX.md) for
cross-area ADRs.

## Skill versions in use

<!--
Optional. Surfaces the conventions-adopted ADR's pinned skill list
at the global level so an agent can read this without opening the
ADR. Re-states the truth; the ADR is canonical.
-->

- `traceflow@<version>`
- `<other-skill>@<version>`

(Canonical: see [`decisions/_shared/ADR-NNN-conventions-adopted.md`](decisions/_shared/ADR-NNN-conventions-adopted.md))
