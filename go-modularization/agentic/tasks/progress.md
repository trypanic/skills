# Progress ledger — improve-go-modularization-from-audit

Orchestrator-owned. One entry per phase, appended after the phase's verification gate and before its commit. Subagents never write here.

Conventions: consumer = the audited repo (read-only acceptance target); gate evidence JSONs live in the orchestrator session scratchpad (`phase<N>-clean.json`, `phase<N>-consumer.json`); fixture = ephemeral clean tree regenerated per gate run, never committed.

## Phase 0 — setup + baseline — PASS — 2026-07-04

- commit: (this commit)
- files: agentic/ (audit, task file, this ledger) added to version control; no skill files touched
- consumer dirt-hash snapshot: `63d68ca8881e5ad964541ecc599e05ada31b8bc30a15d39b366b127ed8bd1a2c` (compared every gate; must stay unchanged)
- clean fixture vs unmodified script: exit 0, `{"violations":0,"promotion_candidates":0,"truncated":false}`
- consumer baseline (unmodified script): exit 1, 22 violations, 6 promotion candidates. Per check: `bad-main` 1 (the non-Go service — S-3 FP), `bad-migration-name` 13 (12 real closed-verb violations under `migrations/postgres/` + the S-5 helper script `migrations/mongo/migrate.sh`), `cross-service-internal` 3 (all S-1 phantom-service FPs via a promoted `external_services/` subfolder), `forbidden-folder` 2 (real: `infra/pg-setup/helpers`, `infra/common`), `go-vet` 1 (S-6 empty-module FP), `inner-imports-contracts` 2 (real — must survive every phase).
- expected post-Phase-1 consumer state: 17 violations = `bad-migration-name` 12 + `misplaced-script` 1 + `forbidden-folder` 2 + `inner-imports-contracts` 2; zero `cross-service-internal`/`bad-main`/`go-vet`.
- notes-for-later: `adapter()` in arch-checks.sh (line 140) shares the greedy-regex defect class with `svc()` but is latent on the consumer (promoted provider folder imports only domain+ports). Out of Phase-1 spec — Phase 1 adds a limitation comment only; Phase 10 re-verifies zero consumer findings and documents it.

## Phase 1 — fix arch-checks.sh defects — PASS (attempt 1) — 2026-07-04

- commit: (this commit)
- files: scripts/arch-checks.sh only (usage() checks paragraph; build/vet zero-`.go` skip; svc() leftmost boundary-anchored rewrite; adapter() limitation comment; bad-main non-Go skip + vendor/node_modules prune; migration `*)` branch grammar-first + `misplaced-script` for script extensions; promotion audit per-(dir, context-stem) heuristic grouping)
- gate: all common checks + 8/8 per-check consumer asserts passed. Consumer: exit 1, 17 violations (was 22) = `bad-migration-name` 12 + `misplaced-script` 1 + `forbidden-folder` 2 + `inner-imports-contracts` 2; zero `cross-service-internal`/`bad-main`/`go-vet`/`go-build`. Clean fixture exit 0, JSON schema unchanged. Promotion candidates: 0 per-context groups on the consumer (was 6 per-folder lines); positive path proven on a 10-file fixture context.
- new checks: `misplaced-script` (existing violations array; no new JSON keys)
- divergences: none material. Promotion stems iterate first-seen (deterministic); build/vet skips on zero `.go`, bad-main on zero non-test `.go` (per spec wording difference).
- notes-for-later: (a) with svc() fixed, `adapter-imports-adapter` could newly fire if sibling providers under one promoted `external_services/` import each other — none today; (b) SKILL.md Verify text still lacks `misplaced-script`/heuristic wording — Phase 2.1 owns it; (c) promotion entries remain plain JSON strings — Phase 2 `--baseline` subtraction over `violations` unaffected; (d) stem prefix/suffix lists are spec-fixed — Phase 8 may extend.

## Phase 2 — enforcement binding + ratchet baseline — PASS (attempt 1) — 2026-07-04

- commit: (this commit)
- files: scripts/arch-checks.sh (`--baseline FILE` flag: escape-aware awk parser over the script's own JSON emission shape; new-vs-standing partition; exit on new only; text `## Standing violations (baseline)` section; additive JSON `standing` + `summary.standing`, present only with the flag; usage() updated); SKILL.md Verify (gate wording lifted from audit 12.11, check-list refreshed for Phase-1 reality, one ratchet sentence + link); references/migration.md NEW stub (single authoritative home of the ratchet mechanism, audit 15.7 wording); adr/README.md ADR-28 appended; adr-cheatsheet.md R-28 row appended.
- gate: all common checks + P1 cumulative asserts passed. Fixture ratchet: dirty exit 1 → `--baseline` exit 0 with standing 1 → new violation exit 1 (new listed, standing kept). Missing baseline file → exit 2. Consumer: no-flag output byte-compatible (17 violations, per-check identical; no `standing` key); with fresh baseline → exit 0, standing 17. Ratchet regression test added to the common gate for all later phases.
- new surface: `--baseline FILE`; JSON `standing[]` + `summary.standing` (flag-only); ADR-28; R-28.
- divergences: baseline parser accepts any `"check"/"detail"` pair anywhere in FILE (so a ratcheted report re-baselines faithfully) — commented in script; standing overflow line uses the short promotions style; missing FILE argument also exits 2. ADR numbering = landing order (audit's indicative R-28…R-33 mapping not binding).
- notes-for-later: routing-table row for migration.md deliberately absent — Phase 9 owns it (file reachable via Verify link + ADR-28 meanwhile). Phase 9 expands migration.md; ratchet section stays the one home. If a later phase promotes a report-only check to failing, its findings become ratchetable automatically.
