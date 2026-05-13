<!--
traceflow per-area STATUS template.

This file is `specs/<area>/STATUS.md`.

Operational dashboard for the area. Tracks every spec's state,
plus recent ideas and ADR activity.

Rows are APPEND-ONLY in the activity logs. The Spec table allows
in-place updates of the State column when a spec transitions.

The full per-spec state (history, reason, contexts) lives in each
spec's `status.md`. THIS file is the area-wide index.
-->

# specs/<area>/STATUS

Operational dashboard for the `<area>` area.

## Specs

<!--
One row per spec. Sorted by S0NN. Active specs first, then archived.

State values (from references/lifecycle.md):
- draft
- ready
- in-progress
- done
- closed
- archived

The State column updates in place. Other columns are append-only.
-->

| Spec | State | Title | Started | Last transition |
|------|-------|-------|---------|------------------|
| `S001-<slug>` | <state> | <one-line title> | <YYYY-MM-DD> | <YYYY-MM-DD> |

## Ideas in progress

<!--
Active idea folders (state: iterating). One row per idea.
-->

| Idea topic | Started | Last update |
|------------|---------|-------------|
| `<topic-slug>` | <YYYY-MM-DD> | <YYYY-MM-DD> |

## Ideas promoted

<!--
Append-only log. One entry per promotion. Names the idea topic,
the date, and the domain files / ADRs that absorbed its content.
-->

### <YYYY-MM-DD> — `<topic-slug>` promoted

Content lifted into:
- `domain/<area>/<file>.md`
- `decisions/<area>/ADR-NNN-<slug>.md` (if applicable)

## Ideas abandoned

<!--
Append-only log. One line per abandonment. Names the idea topic,
the date, and a brief reason.
-->

- <YYYY-MM-DD> — `<topic-slug>`: <reason for abandonment>

## ADR activity

<!--
Append-only log of ADR transitions IN THIS AREA. _shared/ ADR
activity is logged in the global STATUS.md, not here.

Each entry: timestamp + one-line description.
-->

### <YYYY-MM-DD> — ADR-NNN accepted

<one-line summary>

### <YYYY-MM-DD> — ADR-NNN superseded by ADR-MMM

<one-line reason>

## Recent activity

<!--
Optional. Append-only narrative log of meaningful events in this
area. Useful for context handoff. Not duplicated from the tables
above; this captures the soft signal (e.g. "ack pattern audit
revealed three follow-up specs", "blocked on upstream dependency").
-->

### <YYYY-MM-DD> — <one-line event>

<one-paragraph context>
