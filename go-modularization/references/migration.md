# Migrating an existing codebase (incremental adoption)

This reference currently covers the ratchet-baseline mechanism only; fuller migration guidance (assessment, strangler order, anti-corruption layers during moves) is planned.

## Ratchet, don't boil — the baseline mechanism

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
