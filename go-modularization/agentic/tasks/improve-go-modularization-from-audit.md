# Task: improve go-modularization from the 2026-07-04 architecture audit

**Status:** IN PROGRESS — execution tracked per phase in [`progress.md`](progress.md); completed phases are checked off below.
**Audit artifact (single source of findings):** [`../audit/go-modularization-architecture-audit.md`](../audit/go-modularization-architecture-audit.md) — all proposal IDs below (`12.x`), rule lists (`13.x`), anti-patterns (`14.x`), and the migration outline (`15.x`) refer to that document's sections.

**Reference resources (hexagonal-architecture calibration):** the originally referenced `domain-driven-hexagon.jpg` no longer exists; these two articles replace it as the external calibration lens. Read both before authoring or revising any hexagonal-architecture rule text, and use them to reinforce and cross-check every claim the skill makes about layering, ports/adapters, and dependency direction:

- Herberto Graça — *DDD, Hexagonal, Onion, Clean, CQRS: How I put it all together* (Explicit Architecture): <https://herbertograca.com/2017/11/16/explicit-architecture-01-ddd-hexagonal-onion-clean-cqrs-how-i-put-it-all-together/> — authoritative synthesis of layer responsibilities, primary/secondary (driving/driven) adapters, ports as application-owned interfaces, and the dependency rule. Use it to validate the wording of Phases 3–6 (business-rule placement, ports quality, adapter boundaries, application-core substance).
- Netflix Tech Blog — *Ready for changes with Hexagonal Architecture*: <https://netflixtechblog.com/ready-for-changes-with-hexagonal-architecture-b315ec967749> — production case study: business logic isolated from data sources, data sources as swappable adapters behind ports, transport-agnostic core. Use it for the practical framing of "adapters are replaceable technical detail" and the consumer-side translation rules (Phase 5), and as a citable rationale in new rule text and the Phase-7 ADR.

Where new or revised skill text asserts a hexagonal-architecture principle, it must be consistent with both articles; on conflict between an article and the skill's established conventions, keep the skill's convention and note the divergence in the phase's ADR rather than silently diverging.
**Scope guard:** changes touch only the skill (`SKILL.md`, `references/*`, `scripts/arch-checks.sh`, `adr/`). No changes to any consumer repository. All new rule text must be generic — lift the audit's "Draft wording" blocks, which are already evidence-free; never copy service names, file paths, or incident narratives from the audit's evidence sections into skill files.

## Global acceptance checks (apply to every phase)

- [ ] No skill text references `amazon-scrape-worker`, `amazon-scrape-orchestrator`, `source-integration`, or any file path from the audited repo.
- [ ] SKILL.md stays a routing + invariants file: task detail goes to `references/`, SKILL.md gets only the invariant/gotcha/flowchart line and a routing-table row.
- [ ] Every new rule appears in exactly one authoritative place; other files link to it (the skill's own "if this file and a reference disagree, this file wins" model is preserved).
- [ ] `adr/README.md` gains an append-only ADR per phase that introduces a new rule class (phases 2, 3, 4, 5, 7, 9); `references/adr-cheatsheet.md` rows updated in the same phase.
- [ ] `bash scripts/arch-checks.sh --help` and `--json` still work; script stays POSIX-bash + awk/find only (no new dependencies).

---

## Phase 1 — Fix arch-checks.sh defects (audit 12.12 fixes; evidence S-1…S-6)

Restore trust before adding new checks. File: `scripts/arch-checks.sh`.

- [x] 1.1 Fix `svc()` greedy regex (`sub(".*services/","",s)`) so paths containing `external_services/` (or any `*services/` segment) resolve to the true service segment. Anchor to the leading `services/` path component.
- [x] 1.2 Promotion audit: count per-context within a layer (group countable files by context stem per the SKILL.md counting rule), not per-folder totals; label output as heuristic needing context confirmation.
- [x] 1.3 `bad-main`: skip `services/*` dirs containing no non-test `.go` files (non-Go services).
- [x] 1.4 Migration check: files under `migrations/` that are not migration files (e.g. helper shell scripts) get flagged `misplaced-script`, not `bad-migration-name`.
- [x] 1.5 Build/vet: skip modules containing zero `.go` files.
- **Acceptance:** run against the audited repo (read-only): zero `cross-service-internal` false positives on promoted `external_services/` subfolders; fakeapi not flagged `bad-main`; `migrate.sh` reported as `misplaced-script`; empty `go-pkgs` module produces no `go-vet` violation; the two real `inner-imports-contracts` findings still reported. Also run against a minimal clean fixture tree (create under a temp dir in the test, not in the skill repo): exit 0.

## Phase 2 — Enforcement binding (audit 12.11, 15.7; evidence S-R1)

- [x] 2.1 SKILL.md Verify section: add the gate wording (arch-checks in CI / before ending layout-touching changes; `review` mode always embeds script findings; standing violations reported before adding to them).
- [x] 2.2 Add ratchet-baseline mechanism description (checked-in JSON baseline, CI fails only on new violations) — wording in audit 15.7; place the operational detail in the new `references/migration.md` stub (created fully in Phase 9) or Verify section, one home only.
- [x] 2.3 arch-checks: add `--baseline FILE` flag — subtract baseline violations from the failure verdict, still list them under a "standing" heading.
- **Acceptance:** `--baseline` produces exit 0 when only baseline violations exist and exit 1 on any new one; SKILL.md Verify contains the gate + standing-violations wording.

## Phase 3 — Business-rule placement + streaming ledger/policy line (audit 12.1, 12.7; evidence C-2, C-7, W-4, O-2)

- [ ] 3.1 SKILL.md: new invariant block "Adapters decide nothing" using audit 12.1 draft wording (observe/extract/encode/decode/transport/persist vs. decide; raw-signal boundary; interleave-split rule).
- [ ] 3.2 placement-rules.md: expand with the operational test + the sequencing exception (adapter keeps ordering, inner layer keeps policy).
- [ ] 3.3 placement-rules.md streaming section + SKILL.md gotcha: replace the bare "MUST hold no business rules" with audit 12.7 wording (ledger mutation vs. movement decisions; reconciler exception; interactor-method-at-sequence-points pattern).
- [ ] 3.4 arch-checks: add `streaming-file-loc` report-only check (~400 LOC threshold for non-test files under `grpc/`, `ws/`, `sse/`).
- **Acceptance:** an agent reading only SKILL.md can classify these four cases correctly (add as comment-examples in placement-rules): status-derivation ladder in an extractor (→ domain), credit release on settlement in a stream server (→ interactor method), selector table (→ adapter), retry/backoff formula (→ domain). LOC check fires on a fixture file >400 LOC.

## Phase 4 — Enforcement locus / decorative state machine (audit 12.2; evidence C-3)

- [ ] 4.1 placement-rules.md: new section "State machines: one enforcement locus" — audit 12.2 rule wording (domain-enforced vs. datastore-enforced; conformance-oracle requirement; declaration comment + docs).
- [ ] 4.2 SKILL.md: anti-pattern list gains "decorative state machine" (audit 14.1 wording); gotcha line pointing to the reference section.
- [ ] 4.3 arch-checks: `decorative-state-machine` report-only check — exported `Transition`/`CanTransitionTo` in `domain/` with zero non-test call sites outside `domain/`.
- **Acceptance:** check flags a fixture with a dead transition table; does not flag one whose `Transition` is called from `interactor/` or covered by a `_test.go` explicitly named `*_conformance_test.go` (document the naming convention in 4.1).

## Phase 5 — Consumer-side contract hygiene + port quality (audit 12.3, 12.4, 12.5; evidence C-1, O-6, O-8, W-11)

- [ ] 5.1 placement-rules.md Contracts section: add consumer-role restatement + the four "tells" (audit 12.3 wording).
- [ ] 5.2 layout-examples.md: add the stream-client consumer example (client.go + translation.go + sealed domain event sum; before/after de-wired port signature) mirroring the existing server example.
- [ ] 5.3 arch-checks: group `inner-imports-contracts` output per service and name the guilty layer.
- [ ] 5.4 placement-rules.md Ports section: capability-shape rule, no-serialization-tags rule, the mediation erratum, consumer-owned-interface rule for interactor↔interactor seams (audit 12.4 a–d).
- [ ] 5.5 arch-checks: `tags-in-inner-layers` check (`db:`/`bson:` struct tags under `ports/` or `domain/`).
- [ ] 5.6 placement-rules.md R-24: apply audit 12.5 clarification (no-prefix rule absolute; the mix is the convention).
- **Acceptance:** tag check flags a fixture `ports/x_port.go` with a `db:"col"` tag; R-24 section contains the carve-out sentence; cheatsheet R-27 row updated to include the erratum.

## Phase 6 — Anemic interactors + wire-model-in-domain (audit 12.6, 12.8; evidence O-5, O-4)

- [ ] 6.1 placement-rules.md interactor section: shim-interactor heuristic (enrich-or-delete; datastore-procedure-centric carve-out citing the Phase-4 locus rule).
- [ ] 6.2 SKILL.md anti-pattern list: "shim interactor layer", "wire model in domain" (audit 14.4, 14.7 wording); placement-rules gets the wire-model tell ("changing a response contract would edit domain/").
- [ ] 6.3 layout-examples.md: shim-interactor counter-example with both resolutions shown.
- **Acceptance:** examples compile-shaped (pseudocode fine, consistent with existing example style); anti-pattern list alphabetically or thematically ordered as it currently is — no reordering of existing entries.

## Phase 7 — Service boundaries reference (audit 12.10; evidence B-2…B-9, C-4, C-5, C-6)

- [ ] 7.1 Create `references/service-boundaries.md` with the seven rules (durable-state privacy; agreed-values ladder; enforcement locus + coupling table; enum-mirror exhaustiveness tests; dual-enforcement reconciliation; fault-locus taxonomies; one version authority) — lift audit 12.10 draft wording.
- [ ] 7.2 SKILL.md: routing-table row + one-line invariant pointers; anti-pattern list gains "silent config mirror", "peer-datastore reach-in", "peer-enum modeling" (audit 14.8–14.10).
- [ ] 7.3 arch-checks report-only checks: cross-service duplicate datastore-identifier string constants; identically-suffixed env-tag names under different service prefixes (emit as `boundary-review` items, clearly marked heuristic).
- [ ] 7.4 New ADR in `adr/` for the scope extension (the skill now covers boundary rules, previously folder-layout only) + cheatsheet rows.
- **Acceptance:** SKILL.md description frontmatter updated to mention service-boundary coverage (it drives skill triggering); heuristic checks produce zero findings on the clean fixture and ≥1 on a fixture with a duplicated collection-name constant.

## Phase 8 — Shared-tier occupancy + naming hygiene (audit 12.9; evidence B-6, W-6, S-4)

- [ ] 8.1 shared-code.md: two-children rule hardened; ≥2-verified-importers requirement; stdlib-shadow + business-name rules (audit 12.9 wording).
- [ ] 8.2 arch-checks: `root-internal-occupancy` (any root-`internal/` child ≠ `contracts|kernel`), `shared-tier-importer-count` (go list-based, report-only), `stdlib-shadow-name`.
- **Acceptance:** occupancy check flags a fixture `internal/util/`; importer-count marks a single-importer root package; stdlib-shadow flags a shared package named `slices`.

## Phase 9 — Migration/incremental-adoption reference (audit Section 15)

- [ ] 9.1 Create `references/migration.md` from the audit's Section 15 outline (assess-first with root-cause classes; empirical context identification; outside-in strangler order; ACL-during-migration; state-machine locus-first rule; compatibility/rollback checkpoints; ratchet; topology changes isolated).
- [ ] 9.2 SKILL.md: routing row ("Adopting the convention in an existing codebase / migrating legacy layout → read references/migration.md"); Inputs section gains a `migrate` argument sketch (assessment report + ordered plan, no auto-moves).
- **Acceptance:** migration.md cross-references Phase-2 baseline mechanism and Phase-4 locus rule rather than restating them; `migrate` input documented as read-only-first.

## Phase 10 — Final validation

- [ ] 10.1 Re-run improved arch-checks against the audited repo: zero false positives; correctly reports (at minimum) the two `inner-imports-contracts` edges grouped under one service, decorative-state-machine candidates in both services' `domain/`, tags-in-inner-layers on the ports row struct, root-internal occupancy ×2, streaming-file-loc ×1.
- [ ] 10.2 Documentation coherence pass: flowcharts, gotchas, anti-pattern list, cheatsheet, and references all agree; no rule stated in two places with different wording.
- [ ] 10.2b Hexagonal-calibration pass: every new/revised statement about layering, ports/adapters, or dependency direction checked against the two reference resources listed at the top (Graça Explicit Architecture; Netflix hexagonal case study); divergences documented in the relevant ADR, none silent.
- [ ] 10.3 Regression: original clean-fixture run still exits 0; `--json` schema unchanged except additive fields.

## Ordering rationale

Phases 1–2 first: a trusted, gate-bound checker is the multiplier for every later rule (the audit's core root cause was detected-but-shipped). Phases 3–5 carry the Critical-severity rule gaps. 6–8 are High/Medium hardening. 9 is new scope, independent. 10 is the exit gate. Phases 3–9 are internally independent and can be reordered if needed; 1→2 and everything→10 are hard edges.
