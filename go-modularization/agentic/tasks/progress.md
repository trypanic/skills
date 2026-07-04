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

## Phase 3 — business-rule placement + streaming ledger/policy line — PASS (attempt 1) — 2026-07-04

- commit: (this commit)
- files: SKILL.md (`Adapters decide nothing` invariant; streaming gotcha rewritten from "no business rules" to ledger-mutation vs movement-decision line; Verify check list includes `streaming-file-loc`); references/placement-rules.md (operational decision test, raw-signal boundary, sequencing exception, four comment examples, streaming policy clarification); scripts/arch-checks.sh (`streaming-file-loc` report-only check under `grpc/`/`ws/`/`sse/` non-test files >400 LOC); adr/README.md ADR-29; references/adr-cheatsheet.md R-29 + R-23 streaming summary update; task checklist marked Phase 3 complete.
- gate: `bash -n scripts/arch-checks.sh` passed; `bash scripts/arch-checks.sh --help` passed; `bash scripts/arch-checks.sh --json` from the skill root exit 0 with zero violations/candidates; `git diff --check` passed; banned audited service-name search over skill text returned zero. Clean temp fixture exit 0 with zero violations/candidates. LOC temp fixture exit 0 with one promotion candidate: `streaming-file-loc` on a 402-LOC `services/orders/internal/grpc/server.go`. Ratchet regression still passed (`first=1`, baseline standing exit 0, new violation exit 1).
- consumer gate: ran read-only against `/home/trypanic/Code/github.com/American-Crew-Group/source-integration` with `GOCACHE=/tmp/phase3-gocache`; exit 1 with the expected 17 violations from Phase 2 plus one report-only candidate: `streaming-file-loc` on `./services/amazon-scrape-orchestrator/internal/grpc/coordination_server.go` at 931 LOC. Consumer worktree already had unrelated untracked files before the run and was unchanged after.
- hexagonal calibration: read Graça Explicit Architecture and Netflix Hexagonal Architecture before authoring. ADR-29 records no divergence: ports/core own business decisions; adapters remain replaceable transport/persistence edges and dependencies point inward.
- orchestrator gate-repair: the initial implementation emitted `streaming-file-loc` into the `promotion_candidates` bucket (untyped plain strings under a mislabeled heading) and did not exclude generated files. Converted at the gate to a dedicated typed warnings channel: `add_w()` accumulator, text `## Report-only findings` section, additive always-present JSON `warnings:[{check,detail}]` + `summary.warnings` (truncated considers it); `*.pb.go`/`*_gen.go` excluded; threshold named `STREAM_LOC_MAX=400`; usage() Output paragraph documents the channel. Warnings never affect the exit code and are never baselined. Phases 4/7/8 report-only checks reuse this channel.
- new surface: `streaming-file-loc` warning; JSON `warnings` + `summary.warnings` (always present); ADR-29; R-29; R-23 row coherence update.
- gate (orchestrator, post-conversion): all common checks + P1 cumulative asserts + P3 asserts passed. Fixture: 410-line `grpc/` file → exit 0, warnings 1; 400-line exact, 500-line `_test.go`, 500-line `.pb.go` → not flagged; ratchet unaffected by warnings. Consumer: 17 violations unchanged, `summary.warnings` 1 = `streaming-file-loc` naming the 931-line gRPC server file; promotion bucket free of streaming entries.
- divergences: ADR numbering remains landing order (`ADR-29`, `R-29`). Baseline parser will also ingest `check`/`detail` pairs from a report's `warnings` array (harmless: warnings are never partitioned; documented Phase-2 parser behavior).
- notes-for-later: Phase 10 should expect one consumer `streaming-file-loc` warning until the oversized stream server is split; later report-only checks (`decorative-state-machine`, `boundary-review`, `shared-tier-importer-count`) go through `add_w`.

## Phase 4 — enforcement locus / decorative state machine — PASS (attempt 1, one gate-repair) — 2026-07-04

- commit: (this commit)
- files: references/placement-rules.md (`## State machines: one enforcement locus` — domain-enforced vs datastore-enforced, declaration, conformance oracle, `*_conformance_test.go` naming convention); SKILL.md (anti-pattern "decorative state machine" + gotcha line, both appended at list end); scripts/arch-checks.sh (check 8c `decorative-state-machine` on the warnings channel); adr/README.md ADR-30 (records a deliberate calibration divergence: datastore-enforced locus sanctioned as first-class, contained by declaration + conformance oracle); adr-cheatsheet.md R-30.
- orchestrator gate-repair: initial 8c counted a caller in ANY other directory as coverage, so the two services' domain-internal `if !s.CanTransitionTo(next)` self-guards masked each other → zero consumer findings. Fixed: callers under any `domain/` path never count (self-validation IS the decorative pattern); `*_conformance_test.go` still exempts. placement-rules + ADR-30 wording aligned ("outside domain/", self-calls excluded).
- gate: all common checks + cumulative asserts (P1/P3/P4) passed. Overlays: dead table w/ domain self-call → flagged; interactor caller → not; `*_conformance_test.go` → not; same content renamed plain `_test.go` → flagged. Consumer: 17 violations unchanged; warnings 3 = 1 `streaming-file-loc` + 2 `decorative-state-machine` (one per service's `internal/domain` — the audit's C-3 expectation).
- new surface: `decorative-state-machine` warning; ADR-30; R-30.
- divergences: ADR-30's calibration divergence is deliberate and documented in the ADR itself.
- notes-for-later: Phase 10 expects 2 consumer `decorative-state-machine` warnings; heuristic can false-negative when an unrelated repo file calls a same-named method on a different type (accepted, labeled heuristic).

## Phase 5 — consumer contract hygiene + port quality — PASS (attempt 1) — 2026-07-04

- commit: (this commit)
- files: references/placement-rules.md (`### Contracts on the consumer side` — consumer-role restatement + four tells; `### Port quality` — capability shape, no-serialization-tags, mediation erratum, consumer-owned interface; "Two interactor shapes" clarified — no-prefix rule absolute, the mix IS the convention); references/layout-examples.md (`## Streaming client` — client.go + translation.go tree, sealed `StreamEvent` domain sum, before/after de-wired port signature); scripts/arch-checks.sh (`inner-imports-contracts` details grouped per service + guilty layer named, in-awk sort; new violation `tags-in-inner-layers` for `db:"`/`bson:"` under `ports/`/`domain/`, `json:` exempt); adr/README.md ADR-31; adr-cheatsheet.md R-31 appended, R-24 + R-27 rows spec-directed-updated (erratum). No SKILL.md edits (per spec).
- gate: all common checks + cumulative asserts (P1/P3/P4/P5) passed. Fixture: `db:"id"` in ports → 1 violation; `json:`-only → clean; `db:` under data_repositories → clean. Consumer: 18 violations (17 + `tags-in-inner-layers` on the orchestrator ports row file); `inner-imports-contracts` still exactly 2 edges, adjacent, layers named (`ports`, `interactor`); warnings 3 unchanged. Orchestrator touch-ups: two "the coordination contract" phrases genericized to "another service's contract" (placement-rules + ADR-31) — evidence-flavored wording.
- new surface: `tags-in-inner-layers` violation; grouped `inner-imports-contracts` detail format; ADR-31; R-31; R-24/R-27 row updates.
- calibration: both articles fetched; no divergence (Graça "ports fit the core's needs, not tool APIs" = capability rule; Netflix consumer-side translation framing cited in ADR-31).
- divergences: single-service repos report `service (root)` in grouped details; old-format inner-imports-contracts baselines won't match the new detail text (no checked-in baseline exists — non-issue).
- notes-for-later: Phase-10 consumer expectation now 18 violations + 3 warnings. SKILL.md gotcha "Pick one filename convention per service" (line ~146) and the Verify check-list (no `tags-in-inner-layers`, no grouped-format mention) need the Phase-10 coherence pass.

## Phase 6 — anemic interactors + wire-model-in-domain — PASS (attempt 1) — 2026-07-04

- commit: (this commit)
- files: references/placement-rules.md (`### Shim interactors: enrich or delete` — substance requirement, two resolutions, datastore-procedure carve-out citing the Phase-4 locus section by reference; `### Wire models do not belong in domain/` with the "changing a response contract would edit domain/" tell); SKILL.md (two anti-pattern bullets appended: shim interactor layer, wire model in domain — diff verified purely additive at list end); references/layout-examples.md (`## Shim interactor` counter-example with enrich and delete resolutions in the existing pseudocode style). Doc-only; no script/ADR/cheatsheet changes (Phase 6 not in the ADR list).
- gate: all common checks + full cumulative asserts passed; consumer unchanged at 18 violations + 3 warnings (doc-only phase).
- calibration: both articles fetched; no divergence. Noted (ledger-only, no ADR this phase): Graça's "command handlers as mere wiring" is CQRS-bus dispatch, not a pass-through over an outbound port — compatible with enrich-or-delete.
- divergences: none material.
- notes-for-later: Phase-7 anti-pattern appends go after "Wire model in domain". Phase-10 coherence: SKILL.md gotcha "thin use cases" wording slightly in tension with the substance requirement — consider "focused use cases".

## Phase 7 — service-boundaries reference — PASS (attempt 1) — 2026-07-04

- commit: (this commit)
- files: references/service-boundaries.md NEW (7 rules from audit 12.10: durable-state privacy; agreed-values ladder; one enforcement locus + coupling table; enum-mirror exhaustiveness tests; dual-enforcement reconciliation; fault-locus taxonomies; one version authority — links contract tiers + locus rules instead of restating); SKILL.md (frontmatter description extended in place — boundary coverage + 3 trigger phrases, value 1019 chars ≤1024; routing row appended; gotcha appended; 3 anti-patterns appended: silent config mirror, peer-datastore reach-in, peer-enum modeling; malformed table lines 19/23 untouched per plan); scripts/arch-checks.sh (section 8d `boundary-review` warnings ×2 heuristics: cross-service duplicate datastore-identifier consts; identically-suffixed env-tag names under different service prefixes); adr/README.md ADR-32 (scope extension, Netflix citation); adr-cheatsheet.md R-32.
- gate: all common checks + full cumulative asserts (now incl. P7) passed. Fixture: duplicated `"orders"` collection const across two services → 1 boundary-review warning, clean fixture 0; env-suffix scenario 1 warning; exit reflects violations only. Consumer: 18 violations unchanged; warnings now 5 = prior 3 + 2 real `boundary-review` datastore-identifier findings (two shared collection-name constants declared in both services — audit B-2 class).
- new surface: `boundary-review` warning (2 heuristic sub-checks); ADR-32; R-32; new frontmatter description.
- calibration: both articles fetched; ADR-32 records one deliberate tightening (Graça permits read-only peer queries; the skill requires a declared version-pinned contract at service granularity).
- divergences: description coverage phrase compact due to 1024-char limit; 8d(a) also matches typed consts and >2 services; 8d(b) also warns on identical full env values.
- notes-for-later: Phase-10 consumer expectation now 18 violations + 5 warnings. SKILL.md Verify check-list lacks `boundary-review` (Phase-10). Audit 12.10's per-service SP-name-prefix check was out of Phase-7 scope — unimplemented, flag for future work.
