# Governance Rules

## Reading Map

TL;DR: Two rule classes only. An **enforced** rule ships with a named check. An **advisory** rule is listed as pending and is promoted when its check ships. Never cite an advisory rule as blocking in review.

Read:

- "Enforced rules" when reviewing or designing CI.
- "Advisory rules" to know what is recommendation, not gate.
- "Registry consistency" when contracts or dependencies change.
- "Anti-drift gate" when wiring code↔knowledge synchronization.

## Enforced Rules (Tier 2 CI)

| # | Rule | Check |
| --- | --- | --- |
| E1 | Every non-reserved `.md` under `docs/` has frontmatter with a non-empty `type`. | OKF conformance lint (`validate_bundle.py`). |
| E2 | Every `contexts/<id>/context.md` frontmatter validates against the BoundedContext shape; `id` matches the directory name; `status` is valid. | Frontmatter lint (`validate_bundle.py`). |
| E3 | Every `owner.team` resolves in `docs/OWNERS`; a CODEOWNERS entry exists for the context directory. | Owner lint (`validate_bundle.py` checks OWNERS; CODEOWNERS is CI-side). |
| E4 | No schema bodies outside `contracts/published/`. | Schema-body detector over `contracts/consumed/` (`validate_bundle.py`). |
| E5 | Every consumed `id@version` resolves to a published contract declared somewhere in the bundle. | Registry / cross-context check (`validate_bundle.py` at bundle scope). |
| E6 | A published schema shape change without a corresponding version bump fails. | Schema diff for the ADR-chosen format(s) — CI-side, per format. |
| E7 | `entrypoints.source` / `entrypoints.tests` resolve to existing paths. | Path lint (`validate_bundle.py --repo-root`). |
| E8 | ADRs with `status: accepted` are immutable; changes require a superseding ADR. | Git-diff check on accepted ADR files — CI-side. |
| E9 | Generated artifacts (`index.md` listings, `registry.yaml`) match regeneration output. | CI regeneration diff. |
| E10 | A change touching paths under any context's `entrypoints.source` must also touch that context's docs **or** carry a `Knowledge-Impact: none` trailer in the PR. | CI policy gate. |

The bundled validator covers the statically checkable subset (E1–E5, E7, plus structural checks). E6, E8, E9, E10 need CI wiring; until wired for a given repo, treat them as advisory there and say so.

## Anti-Drift Gate (E10)

E10 is the anti-drift forcing function, made falsifiable:

- The mapping is mechanical: changed code paths ∩ each context's `entrypoints.source` globs.
- If a context's code changed and no file under `docs/contexts/<id>/**` changed, the PR must carry a machine-readable waiver trailer: `Knowledge-Impact: none`.
- The waiver is auditable and attributable; reviewers spot-check waivers.

It cannot catch a lie in the waiver — no check can — but it eliminates *silent* drift: every divergence has either a knowledge diff or an explicit waiver in history.

## Advisory Rules (promoted when a check ships)

| # | Rule | Missing check |
| --- | --- | --- |
| A1 | Boundary, ownership, or dependency changes require an ADR. | Semantic; review-enforced, aided by field-change detection on `owner`/`dependencies`. |
| A2 | Normative cross-context reading of internals is forbidden; depend only on published contracts. | No link-graph lint distinguishing normative vs investigative links yet. |
| A3 | Long documents begin with a reading map. | Heuristic lint possible, not built (validator warns at >300 lines). |
| A4 | One scenario per runbook/playbook; supersede ADRs, never mutate drafts. | Review. |
| A5 | Docs migration assigns a `type` to material before moving it. | Checklist. |
| A6 | Internal signals must not be treated as stable dependencies. | Review. |

## Cross-Context Reading

Two kinds:

```text
Normative reading:     using another context's knowledge as source of truth or dependency. Forbidden for internals; allowed only via published contracts.
Investigative reading: temporarily inspecting another context to understand a problem. Allowed; must not create an architectural dependency.
```

If a consumer needs stable knowledge from another context, the provider publishes a contract. That is the only durable answer.

## Registry Consistency

`docs/registry.yaml` is generated from all `context.md` frontmatter. Generation doubles as the cross-context consistency check:

- a consumed id with no publisher fails (E5);
- duplicate published contract ids fail;
- an operation declared both standalone and inside an `api` contract fails;
- dangling `dependencies.allowed.via` entries (contract id not published by the named context) fail.

Two contexts can never silently disagree about who owns what. The registry is never hand-edited (E9).
