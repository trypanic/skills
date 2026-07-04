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
