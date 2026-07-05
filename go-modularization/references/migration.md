# Migrating an existing codebase (incremental adoption)

Migration into this convention is **assess-first and read-only-first**: produce the assessment and the ordered plan before touching anything; execution then happens as separate, individually revertible, reviewed changes. The `migrate` input (SKILL.md → Inputs) enters here — it emits the assessment report and the ordered plan and performs **no automatic file moves**.

The sections below are the migration order. Skipping ahead (renaming folders before seams and policy are in place) produces a repo that *looks* converted while every boundary still leaks.

## 1. Assess before moving

Run `scripts/arch-checks.sh` on the untouched repo. The standing-violation report **is** the baseline ledger — capture it with `--json` and it becomes the ratchet baseline (§7) with no separate bookkeeping.

Classify every finding **before touching anything**, on two axes:

- **Root-cause class** — what kind of defect it is: **misplacement** (code in the wrong layer or folder — a business rule in an adapter, a reconciler in `cli/`), **missing seam** (no translation/port where one is required — inner layers consuming wire types, port signatures naming generated types), **boundary leak** (another service's datastore identifiers, enums, or agreed values re-declared locally), or **naming drift** (wrong prefix/suffix, forbidden folder name, decorative artifact). The class determines which migration step (§3) owns the fix.
- **Disposition** — how safe the fix is: pure implementation drift is a safe mechanical move; a finding that encodes a *settled trade-off* (e.g. a deliberately datastore-enforced locus) needs that decision recorded in an ADR **before** any move — otherwise the move re-litigates a settled decision; a finding where this skill's guidance is genuinely ambiguous goes to Step 0 (SKILL.md), not into the plan.

The output of this step is an assessment report: the arch-checks findings, each finding's classification, and the proposed context map (§2). No file has moved yet.

## 2. Identify bounded contexts empirically

Identify contexts from evidence, not folder names — legacy folder layout is precisely what is *not* trusted here. Cluster files by **PR co-change history** and **shared vocabulary**: two candidates that always change in the same PR are one context (the standing context test — see "Identifying a context" in [`placement-rules.md`](placement-rules.md), applied here as the legacy-analysis tool). Eighteen one-file "contexts" that co-change in four clusters are four contexts.

Record the context map as a table in the owning docs **before moving anything**. Every later move cites a row in this table; a move that cites no row is scope creep.

## 3. Strangler order — outside-in

Convert in this order; each lettered step is independently shippable and each item within it is its own change:

- **(a) Composition root first.** Isolate construction in `cmd/`: all wiring moves there, `cmd/` gains no logic. This creates the one place where old and new implementations can be swapped during every later step.
- **(b) Translation seams next.** Introduce a translation file (`<adapter>_translation.go` or `translation.go`) at each adapter that owns a wire format; de-wire port signatures **one port at a time** — each port is an independently shippable step. Mechanics in §4.
- **(c) Policy extraction third.** Move decisions out of adapters behind the raw-signal boundary ("Adapters decide nothing", SKILL.md invariant) — **one rule per change**, each guarded by a characterization test written *before* the move. State machines have an extra precondition — §5.
- **(d) Folder renames and promotions LAST.** They are the cheapest and least urgent steps, despite being the most visible. Semantics first, spelling last: a rename before (a)–(c) only decorates the leak.

## 4. Anti-corruption layers during (not after) migration

The translation seam goes in **while old and new shapes coexist** — never as a cleanup after the fact, and never as a big-bang signature flip. When an inner layer currently consumes a wire type:

1. Introduce the domain type plus the mapping at the adapter, while **both** the wire path and the domain path flow.
2. Migrate call sites to the domain type, one at a time.
3. Delete the wire path.

Each intermediate state builds and ships. The temporary duplication (two shapes flowing) is the cost of never breaking a caller mid-migration; it is deleted in step 3, not tolerated indefinitely.

## 5. State machines: locus first

Never move an enforcement locus and refactor the code shape in one change. Before relocating **any** transition logic:

1. Make the current enforcement locus explicit — declare it (domain-enforced or datastore-enforced) and prove it with a conformance test, per "State machines: one enforcement locus" in [`placement-rules.md`](placement-rules.md) — that section owns the locus rule, the declaration format, and the `*_conformance_test.go` convention; this document does not restate them.
2. Only then, if desired, relocate enforcement. The conformance test written in step 1 is the safety net: it fails the moment the new locus disagrees with the declared table.

A legacy repo commonly has *no* effective locus (a decorative table plus ad-hoc writes). That is a step-1 finding, not a license to pick a locus mid-move.

## 6. Compatibility and rollback

Every migration step keeps the build green and behavior identical:

- **Checkpoint after each step:** arch-checks (ratcheted, §7) plus the full test suite. A step that cannot pass the checkpoint is too big — split it.
- **Each step is revertible alone.** No step depends on a later step to restore correctness; reverting any single change returns to a shipped-good state.
- **Promotions update all import sites in the same change** (the existing promotion rule — see [`placement-rules.md`](placement-rules.md)).
- **Contracts never change as a side effect.** Anything touching a published contract or a peer-visible identifier (a wire schema, a shared datastore name, an agreed value — see [`service-boundaries.md`](service-boundaries.md)) escalates out of migration into the contract-change process. Migration never bumps a contract in passing.

## 7. Ratchet, don't boil — the baseline mechanism

An existing codebase has standing violations, and failing every run on all of them makes the arch-checks gate (SKILL.md → Verify) unadoptable. Ratchet instead: maintain a **checked-in baseline** of standing violations — the script's own `--json` output — and have CI fail only on **new** violations. Burn the baseline down deliberately; never let it grow. This is what makes the gate adoptable in a brownfield repo.

Concrete usage:

```bash
# 1. Capture the baseline once, from the repo root; commit the file.
bash scripts/arch-checks.sh --json --output arch-baseline.json

# 2. Every subsequent run (CI and local) ratchets against it.
bash scripts/arch-checks.sh --baseline arch-baseline.json
```

Semantics of `--baseline FILE`:

- A violation whose exact check+detail pair appears in FILE is **standing**: still reported (text: a separate `## Standing violations (baseline)` section; JSON: an additive `standing` array plus `summary.standing`, both present only when the flag is given), but it does not fail the run.
- Exit 0 iff there are zero **new** (non-baseline) violations, even with standing ones present; any new violation exits 1. `summary.violations` counts new only — it remains "what fails the run".
- A missing or unreadable FILE is a usage error (exit 2) — the run never silently ignores a bad baseline.

Burning it down: when standing violations get fixed, regenerate the baseline (`--json --output arch-baseline.json`, without `--baseline`) and commit the smaller file in the same change. Never regenerate to absorb new violations — that grows the ratchet and defeats the gate.

Each migration step (§3) should shrink the baseline; regenerating after each shipped step turns the plan's progress into a reviewable diff on `arch-baseline.json`.

## 8. Repository evolution strategy

Module-topology changes — single-module ↔ multi-module workspace (topologies A and B, SKILL.md "Module topology") — are their **own migration class**. Do them in isolation, never combined with layer moves or folder renames in one change: a topology change rewrites `go.mod`/`go.work` and import resolution across the whole repo, and mixing it with file moves makes both halves unreviewable and neither revertible alone (§6). Sequence: finish (or pause) layout migration steps, land the topology change as a standalone reviewed change with a green checkpoint, then resume.
