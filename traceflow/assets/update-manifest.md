<!--
traceflow Update Manifest template.

This is NOT a file you save anywhere. It is the structured block
the agent MUST emit at the end of every turn that performs a
traceflow action (idea, domain, adr, spec, state, archive, check,
map).

The Update Manifest substitutes for a validator in v0. It makes
the agent's side effects visible to human reviewers. Omissions
are themselves information.

Format below is the canonical shape. The agent fills in every
section. Sections that are not applicable to the action are
marked "N/A" rather than omitted.
-->

## Update Manifest

**Action**: <command name, e.g. `/traceflow:spec`>
**Target**: <area / spec-id / adr-id / N/A>
**Timestamp**: <YYYY-MM-DD HH:MM>

### State transitions

<!--
List every state change that occurred during this turn. Format:
- <artifact-id>: <from> → <to>

Examples:
- ADR-024: (new) → proposed
- ADR-017: accepted → superseded by ADR-024
- S010: in-progress → done

If no transitions occurred, write "(none)".
-->

- <state transition>

### Files written

<!--
Every file created or edited during this turn. Distinguish
created vs edited. Path is repo-relative.

Format:
- <path>: <created | edited>
-->

- <path>: <created | edited>

### Files moved

<!--
Every git mv during this turn (e.g. spec → archive).
Format:
- <from path> → <to path>

If none, write "(none)".
-->

- <from> → <to>

### Spec-deltas applied

<!--
If the action involved a spec state transition to `done` or `archived`,
list the deltas that were applied to durable artifacts.

Format:
- <delta type>: <target path>

Where delta type is one of:
ADDED, MODIFIED, REMOVED, NONE: refactor, NONE: typo, NONE: spike,
NONE: hotfix, NONE: tooling

If the action was not a `done` or `archived` transition, write "N/A".
-->

- <delta entry>

### Invariants run

<!--
List which invariants from scripts/invariants.sh were executed
during this turn, and their pass/fail status. If `/traceflow:check`
was run, all six are typically listed.

Format:
- <invariant name>: <pass | fail [details]>

If no invariants were run during this turn, write "(none)".
-->

- <invariant>: <pass | fail>

### Open items for human review

<!--
Things the agent could not do without a human decision. Examples:
- "ADR-024 in `proposed` state, awaiting acceptance review"
- "Spec S012 has conflict on path `services/foo/bar.go`; competing claim from S010"
- "Idea `ingest/batch-replay` has been stable for 3 iterations; ready to promote?"

Each item is one line. If none, write "(none)".
-->

- <open item>

### Drift detected

<!--
Failures or anomalies the agent surfaced but did NOT auto-fix.
The agent's responsibility is to surface; the human decides the
corrective action.

Format:
- <one-line description of drift>
- <affected paths / artifacts>

If no drift was detected, write "(none)".
-->

- <drift item>
