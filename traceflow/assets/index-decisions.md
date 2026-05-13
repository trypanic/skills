<!--
traceflow decisions INDEX template.

This file is `decisions/<area>/INDEX.md` (or `decisions/_shared/INDEX.md`).

One row per ADR in this bucket. The Summary column must be ONE
LINE; the agent uses this to decide whether to open the ADR body
without reading it.

Rows are APPEND-ONLY for the ADR and Title columns. The Status
column updates in place (proposed → accepted → superseded /
deprecated).
-->

# decisions/<area>/INDEX

<!--
One-line description of this INDEX's scope.

For per-area INDEX: "ADRs scoped to area <area>."
For _shared INDEX: "ADRs that cross area boundaries or apply repo-wide."
-->

<scope description>

## ADRs

| ADR | Type | Summary | Status |
|-----|------|---------|--------|
| [ADR-NNN](ADR-NNN-<slug>.md) | <type> | <one-line summary, <= 80 chars> | <proposed | accepted | superseded by ADR-MMM | deprecated> |

<!--
Type column values (from the enum):
- stack
- structure
- policy
- operational
- contract
- security
- data
- conventions-adopted

Status column values:
- proposed
- accepted
- superseded by ADR-MMM
- deprecated (<YYYY-MM-DD>, <one-line reason>)
-->

## Shared ADRs that apply to this area

<!--
Only used in per-area INDEX files (not _shared). Lists ADRs in
_shared/ that bind this area. Avoids re-stating their content;
links out for detail.

Omit this section entirely in _shared/INDEX.md.
-->

| Shared ADR | Type | Summary |
|------------|------|---------|
| [ADR-NNN](../_shared/ADR-NNN-<slug>.md) | <type> | <one-line summary> |

## Notes

<!--
Optional. Use for:
- pointers to ADRs being drafted (proposed)
- ADRs awaiting acceptance decision
- cross-references to specs that motivated an ADR

Keep notes terse. Long context belongs in the ADRs themselves.
-->

- <note>
