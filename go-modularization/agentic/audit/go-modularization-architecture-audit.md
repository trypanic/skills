# go-modularization architecture audit

**Date:** 2026-07-04

**Auditor role:** adversarial architecture reviewer (DDD, Hexagonal Architecture, Go monorepos, AI-oriented repository design)

**Subjects:**
- Implementation evidence: `services/amazon-scrape-worker/` and `services/amazon-scrape-orchestrator/` in `github.com/American-Crew-Group/source-integration` (multi-module workspace, topology B)
- Skill under audit: `/home/trypanic/Code/github.com/trypanic/skills/go-modularization` (SKILL.md + references/ + scripts/arch-checks.sh) — local path treated as source of truth

**Calibration sources:** the skill's own invariants (R-01…R-27), the standard Hexagonal Architecture / Dependency Inversion model (ports as domain-owned capabilities, adapters as replaceable technical detail, composition root at the edge).  Calibration proceeded from the skill text and the canonical hexagonal model. No remediation was performed; this document is evidence + skill-improvement input only.

**Method:** full read of the skill (SKILL.md, all reference files, arch-checks.sh); `arch-checks.sh` executed against the repo; three parallel deep audits (worker internals, orchestrator internals, cross-service boundary) reading actual code with import-graph verification via `go list`/grep; script defects reproduced empirically.

Finding IDs: `W-*` worker, `O-*` orchestrator, `B-*` boundary, `S-*` skill/script. Root-cause classes: `impl-drift` (implementation drift), `missing-guidance`, `ambiguous-guidance`, `tradeoff-needs-doc` (intentional but undocumented).

---

## 1. Executive summary

The two services are a natural experiment in how the `go-modularization` skill behaves under sustained AI-assisted development, and the result is sharply bimodal:

**What the skill got right.** Everything the skill states as a *mechanical, checkable* rule mostly held. The orchestrator's import graph has **zero violating edges** — no inner→adapter, no adapter→adapter, generated contracts confined to `grpc/`, `cmd/` as pure composition root. Both services inject all dependencies from `cmd/`, keep repositories policy-free in the write path, use the sanctioned streaming patterns (session-implements-sink-port, reconciler-in-adapter-package), and follow the migration/SP conventions. Folder topology is essentially correct.

**What the skill failed to prevent.** The failures cluster precisely where the skill is silent or ambiguous — *semantic* placement rather than *syntactic* placement:

1. **The wire contract colonized one consumer's core** (W-1/W-2, B-1). The worker's `ports/` and all seven interactor files import the generated proto; ports are vendor mirrors of the gRPC stream (`Send(*coordinationv1.WorkerMessage)`); the anti-corruption layer lives one layer too far in. The producer side stayed clean — proof the rule works when applied, and that nothing *enforces* it per-service. Notably, `arch-checks.sh` **does** flag this — the violation shipped anyway because the skill never binds the script to any gate.
2. **Business policy migrated into adapters** (W-3, W-4, O-3, O-4). Three production-ADR'd business rules (out-of-stock⇒zero-price, stock-quantity semantics, availability-status ladder) execute inside the browser adapter; credit-ledger policy is enacted at two grpc call sites; a JSON response model with envelope constants sits in `domain/`. The skill's "adapters hold no business rules" clause exists but gives an agent no operational test for *what counts as a business rule* when it is interleaved with extraction mechanics.
3. **Both domain layers contain decorative state machines** (W-5, O-1, B-3). Both services define transition tables + `Transition()/CanTransitionTo()` with **zero non-test callers**. The orchestrator's real machine is 37 Postgres stored procedures; the worker's real machine is ad-hoc switches with hardcoded from-states in log calls. The most dangerous artifact in the repo is code that *looks* authoritative and enforces nothing.
4. **The service boundary leaks through channels the skill doesn't name** (B-4, B-5, B-2, B-7): a correctness-bearing lease TTL agreed via silently mirrored env vars; the orchestrator reading the worker's Mongo collections against its own machine-readable `forbidden` declaration; one failure enum hand-maintained in triplicate with live drift (the worker's "closed catalog" is missing a value its own interactor emits); a peer's private session enum copied into the worker's domain.
5. **The validation script is buggy and unbound** (S-1…S-7): a greedy regex false-flags every promoted `external_services/<provider>/` subfolder as a cross-service import; promotion counting contradicts the written rule; non-Go services break a check; the root-`internal/` two-folders rule has no check at all; and nothing in the skill requires the script to run in CI or before merge.

**Primary conclusion for the skill.** The skill is strong at folder syntax and dependency direction, and nearly silent on: business-rule placement tests, state-machine enforcement loci, consumer-side contract hygiene, service-boundary/ownership rules, legacy migration, and enforcement binding. Sections 11–16 translate every failure into concrete skill changes; the highest-leverage additions are (a) an operational "decision vs. mechanics" test for adapter content, (b) a "decorative state machine" anti-pattern + check, (c) a new service-boundary rule set, and (d) fixing and *binding* `arch-checks.sh`.

---

## 2. Architecture scorecard

Grades: A (exemplary) … F (systematic violation). Split per service where they diverge.

| Dimension | Orchestrator | Worker | Evidence |
|---|---|---|---|
| Dependency direction (imports point inward) | **A** | **F** | O: zero violating edges, verified exhaustively. W: `ports/` + all 7 interactor files import `contracts/coordination/v1` (W-1, W-2) |
| Ports as domain-owned capability abstractions | **B−** | **D** | O: domain-typed but SP-surface-shaped, one `db:`-tagged row struct in ports (O-6). W: `Stream`/`Emit`/`Engine.Prime` signatures speak proto (W-1) |
| Adapters technical-only (no business invariants) | **B−** | **C−** | O: credit policy enacted at 2 grpc sites (O-3). W: three ADR'd product policies in browser adapter (W-3), priming strategy chain undocumented (W-4) |
| Composition root & DI | **A−** | **A−** | Both: all construction in `cmd/main.go`; no interactor builds a concrete. Deduction: `cmd/pprof_temp.go` logic in both (W-9, O-10) |
| Wire/domain translation at adapter edge | **B** | **F** | O: pure + adapter-side but scattered across a 931-LOC file, one domain leak (`metric.go`) (O-2, O-4). W: ACL lives in interactor; ~15 frame builders in `pipeline.go`/`processor.go` (W-2) |
| Domain richness (invariants enforced where declared) | **C** | **C** | Both: half rich (admission gates, disposition policy, redaction-by-construction, snapshot assembly), half decorative (dead transition tables, dead LinkSet, dead parsers) (O-1, W-5) |
| Use-case layer substance | **C+** | **B** | O: 7/12 interactors are 1-line pass-through shims (O-5). W: genuine process managers, but doubling as the ACL |
| Adapter-to-adapter isolation | **A** | **A** | None found in either service — verified by import inventory |
| Repository discipline (no policy in repos) | **B+** | **A** | O: ~200 LOC read-model derivation in a Mongo repo (O-11); write path clean, SP-only access airtight. W: all four repos policy-free |
| Module cohesion / bounded-context legibility | **C+** | **C+** | 18 domain files ≈ 4 real contexts (O), 15 files ≈ 3 contexts (W); flat suffix naming atomizes contexts below the promotion radar (O-Q8, W-13) |
| Service boundary explicitness | **C−** | — | Out-of-band env contract (B-4), peer-datastore read vs. `forbidden` declaration (B-5), enum ×3 with drift (B-2), peer-enum modeling (B-7) |
| AI navigability | **C+** | **C+** | Wrong-precedent attractors: frame builders in interactor, policy in extract.go, `domain/metric.go` next to nine correct handlers; name collisions (`slices` ×2, `Snapshot` ×2, identical port/interactor type names) |
| Mechanical skill compliance (names, folders, migrations) | **B** | **B−** | Both: no forbidden folders, correct streaming/reconciler placement. Deductions: `api/v1` promotion overdue at 10≥5 (O-7), provider cluster unpromoted + grammar-breaking filenames (W-7), 13 verbless migration names, root-`internal/` residents (B-6) |
| Validation tooling health | **D** (skill-side) | | arch-checks.sh: false positives, rule-divergent counts, missing checks, no gate binding (S-1…S-7) |

---

## 3. Critical architectural violations

Severity per the audit rubric. Full evidence in the per-service sections; this is the ranked ledger.

### C-1 (W-1/W-2, B-1) Worker inner core speaks the generated wire contract — Critical, `impl-drift`
- `services/amazon-scrape-worker/internal/ports/coordination.go:10` imports `coordinationv1`; `Stream.Send(*coordinationv1.WorkerMessage)` / `Recv() (*coordinationv1.OrchestratorMessage, error)` (:17–20); `ScrapePipeline.Run`/`SubmitPipeline.Run` take `*coordinationv1.AssignTask` (:58, :67). `ports/scraping.go`: `Emit func(*coordinationv1.WorkerMessage) error` (:14), `Engine.Prime(..., *coordinationv1.CookieSet)` (:147), `EngineFactory.New(ctx, *coordinationv1.Proxy)` (:170).
- All 7 interactor files import the proto. Frame builders (`taskCompleted`, `heartbeat`, `helloFrame`, …) live in `pipeline.go:611–670`, `processor.go:424–443`, `establisher.go:224–235`; wire-enum business reconciliation (`CREATED+DUPLICATE=success`) over raw `coordinationv1.SeedOutcome` in `seed.go:68–81`; terminal-frame grammar duplicated in `session.go:125–134` and `processor.go:333`.
- Violates SKILL.md forbidden-imports (R-25) and placement-rules "a port speaks domain types". Consequence: every contract bump recompiles/rewrites the inner core; ports unfakeable without protobuf; protocol grammar smeared over 7 files (observed: adding enum value 14 touched processor internals).
- Downstream symptom: `external_services/browser` consumes the *coordination* contract (`engine.go:33`, `priming.go:16`) only because port signatures force it (W-8) — the Amazon-scraping adapter is coupled to the orchestration protocol.
- Asymmetry is the key datum: the orchestrator (producer) confines the same contract to `grpc/`. Same skill, same repo, opposite outcomes ⇒ the rule is right but unenforced per-service. `arch-checks.sh` flags both edges (`inner-imports-contracts`); the violation still shipped — enforcement gap, not knowledge gap.

### C-2 (W-3) Production business invariants execute inside the browser adapter — Critical, `ambiguous-guidance`
- `browser/extract.go:27–31, 210–214`: out-of-stock ⇒ `price=0` + `status=out_of_stock` (the ADR-029 policy). `extract.go:220–236`: the availability-status derivation ladder. `extract.go:267–279`: dropdown-max ⇒ units-in-stock semantics (ADR-030). `browser/classify.go:20–41`: verdict precedence order (ADR-010).
- The port's own doc promises "no pipeline decisions" (`ports/scraping.go:139–142`) — the adapter breaks its own contract. These are the service's highest-churn business rules (each already produced a production bugfix ADR) living in the least-testable layer. A second engine implementation must re-implement them or silently diverge.
- Root cause is genuinely ambiguous guidance: the skill says selectors (volatile DOM knowledge) belong to the adapter and "no business rules" — but gives no test for where *interpretation of extracted signals* ends and *policy* begins.

### C-3 (O-1, W-5, B-3) Decorative state machines in both domains; real transitions enforced elsewhere — Critical, `tradeoff-needs-doc` (O) / `impl-drift` (W)
- Orchestrator: `domain/task.go:60–96`, `session.go`, `proxy.go`, `linkset.go` define transition tables, `CanTransitionTo/Transition`, `Parse*State`, `LinkSet.Ready` — **zero non-test callers**. Enforcement is 37 `amz_orch_*` stored procedures with inline guards (`WHERE state = 'DISPATCHED'`, disposition CASE in migration 011). Migration 010 even says "*mirrors the domain LinkSet rule*" — a hand-synced SQL copy. Guard semantics differ too: SP no-ops idempotently (`applied=false`) where the Go table would reject.
- Worker: `domain/lifecycle.go:31–63` transition table — zero production callers; phases asserted by hardcoded string literals in log calls (`recordTransition("Draining", domain.PhaseSessioned, domain.PhaseDraining)`, `processor.go:96`); `JobType.RequiresProxy`, `ParseJobType/ParseTaskType` dead while `processor.go:447–466` privately re-implements the same mapping.
- Three encodings of one machine (docs table, latent Go, SQL) with three update cadences; migration 036 added `DELISTED` and someone had to remember all the copies. An agent reading `domain/` will believe illegal transitions are rejected at runtime; they are not.

### C-4 (B-4) Correctness-bearing values agreed via silent config mirroring — Critical, `missing-guidance`
- `.env.shared.local` coordination block mirrors `TASK_LEASE_TTL`, heartbeat, keepalive across both prefixes; worker `cmd/main.go:51–61` documents its copy as "the worker's mirror of the orchestrator-owned TASK_LEASE_TTL". `ConfigSnapshot` transmits some values in-band but **not** `task_lease_ttl`; the establisher only *warns* on drift for what is transmitted (`establisher.go:195–204`).
- The worker makes an **authority decision** from its mirror: `domain/lifecycle.go:183–185 ReattachAuthoritative(reconnectElapsed, leaseTTL)` decides whether buffered results survive reconnect — judged against a local copy of a peer-owned TTL never validated in-band. Drift ⇒ wrongly-authoritative reclaimed work or discarded live work.
- Mitigations exist (adjacent-line convention, `repo:env-audit`, per-side ordering asserts) but no cross-service equality check. The skill has no concept of "mirrored config is contract".

### C-5 (B-5) Peer-datastore reach-in contradicting a machine-readable boundary declaration — Critical (governance), `missing-guidance`
- Orchestrator `data_repositories/repository_metric_event.go:16–17` re-declares by string literal and reads `amz_scrape_worker_logs` / `amz_scrape_page_captures` — collections written and *documented as owned* by the worker — while the orchestrator's `context.md` declares `dependencies.forbidden: amazon-scrape-worker … never directly`. No schema pin, no consumed-contract declaration, bson shapes re-declared by hand on both sides.
- Runtime risk Medium (read-only dashboards); governance failure Critical: any tool or agent trusting the frontmatter reasons wrongly, and the worker can no longer rename a collection safely.

### C-6 (B-2) One closed failure catalog, three hand-maintained copies, live drift — High, `missing-guidance`
- Proto `TaskFailureReason` 0–14; worker `domain/failure.go:10–29` (13 values, **missing `ASSIGNMENT_REJECTED`** that its own interactor emits via the raw proto constant at `processor.go:195`, bypassing its own closed catalog); orchestrator `domain/task.go:135–158` (15 values + disposition classes). Same triplication for JobType/TaskType. No exhaustiveness test cross-checks any mirror against the generated `_name` maps.

### C-7 (O-3) Credit-ledger policy enacted in the streaming adapter — High, `ambiguous-guidance`
- The in-flight-credit invariant has five enforcement sites in two layers. Interactor (correct): `interactor_event.go:70,93,113`. Adapter (wrong): `coordination_server.go:786–790` (seed-close credit return), `:661–665` (captcha-revoke release); `:251–256` and `:601–614` are the defensible reconciler cases. The skill's "session MAY hold the ledger / MUST hold no business rules" line does not say which side "release on Closed" falls on — and this invariant is the service's historical bug magnet (a live credit-leak incident).

### C-8 (O-4) Wire response model with envelope constants in `domain/` — High, `impl-drift`
- `domain/metric.go:7–10` (`MetricVersion="1.0"`, `MetricStatus="METRICS_SNAPSHOT"`) + 248 LOC of `json:`-tagged structs mirroring a response schema, serialized verbatim by the handler. Nine sibling handlers do it right (adapter-local DTOs) — one wrong precedent sitting beside nine right ones is an attractor for the next agent.

Additional High findings: W-4 (priming strategy chain — real ADR'd orchestration — hidden behind an opaque `Prime` call while the port claims the pipeline owns all control flow; `tradeoff-needs-doc`), W-6 (ADR'd category-expansion business algorithm parked in root `internal/slices`, shadowing stdlib `slices`, one consumer; `impl-drift`), O-5 (7 of 12 interactors are 1:1 pass-through shims — hollow hexagon as a *system* consequence of SP-centric design; `tradeoff-needs-doc`).

---

## 4. Service boundary evidence and generalized skill insights

The boundary audit found the proto contract is **not** the only coupling channel. Channels actually in use, with the generic insight each yields:

| # | Channel (evidence) | Category | Generalized insight for the skill |
|---|---|---|---|
| B-1 | Consumer's ports/interactor import the producer's generated contract (worker-wide); producer clean | contract quality | Adapter-only contract rule must be checked **per service, symmetrically**; a consumer owns its domain vocabulary and translates at its stream-*client* adapter exactly as the producer translates at its stream-server adapter. The skill's only worked example is server-side — add the client-side twin. |
| B-2 | Failure/job/task enums re-declared ×3; worker copy already incomplete vs. what it emits | duplicated-state-machine | Domain mirrors of closed wire enums are legitimate **only** with a per-service exhaustiveness test against the generated `_name` map. A mirror the service's own code bypasses is dead weight or broken layering. |
| B-3 | Task machine: docs table + latent Go table + 37 SP guards; reason→class in Go, class→state in SQL | lifecycle-authority-split | Every state machine needs **one declared enforcement locus**; parallel in-service tables must be invoked on every mutation path or conformance-tested against the locus. Cross-language splits of one decision must cite the same ADR/doc on both halves (this repo does — the mitigating pattern worth teaching). |
| B-4 | Mirrored env coordination block; lease TTL feeds an authority decision; in-band snapshot partial + warn-only | out-of-band-contract-coupling | "Any value two services must agree on is contract." Ladder: transmit-and-adopt > transmit-and-fail-on-mismatch > transmit-and-warn (smell) > silent mirror (forbidden when correctness-bearing). |
| B-5 | Orchestrator reads worker-owned Mongo collections by re-declared string constants, against its own `forbidden` frontmatter | durable-state-authority-split | A service's datastores are private. A peer read is a *contract*: declared, version-pinned, schema-backed — never string-literal table/collection names re-declared in the reader. Logical-context indirection does not exempt the physical reader. |
| B-6 | Root `internal/authintegration` + `internal/slices`: single-consumer packages at the shared root; shared Postgres fenced only by SP name prefix | shared-internal-package | Shared-root placement requires ≥2 *actual* importing services (verify with `go list`), not anticipated reuse. In a shared-DB monorepo, the migration `<service>` token is an ownership fence — check services only call SPs bearing their own prefix. |
| B-7 | Credit ceiling enforced on both sides (deliberate) with a reconciliation protocol born from an incident; worker's domain models the peer's private session enum (`OrchestratorSessionState`, consulted by nothing on the wire); wire failure reasons named after executor pipeline stages | coordination-execution-mixed | (1) Dual enforcement of one numeric invariant requires a named authority + explicit reconciliation path. (2) Never model a peer's private state machine in `domain/`; keep it a string at the adapter. (3) Cross-boundary failure taxonomies classify by fault locus, not executor stages — stage-named reasons turn internal refactors into contract bumps. |
| B-8 | Wire envelope `"1.0"` vs. docs SemVer `1.2.0` vs. `MIN_WORKER_VERSION` gate | contract quality | One version authority per contract, with a written mapping from documented SemVer to something runtime-observable. |
| B-9 | Lifecycle knowledge split across docs/proto comments/SP headers/Go comments — but consistently cross-cited; worker publishes a "state-coupling summary" table, not a second transition table | discoverability (positive) | Canonize the **coupling-table pattern**: the non-owner of a cross-service machine documents only my-state↔peer-state correlation, never a second transition table. |

Illustrative only (not for skill wording): the orchestrator's metrics read-path could be a separate read-model consumer of a published capture contract, which would dissolve B-5 — mentioned solely to show the missing rule is "peer reads need contracts", not a prescription for these services.

---

## 5. Layer-by-layer audit

### domain/
- **Worker** (15 files): import-clean (stdlib + errorkit only). Bimodal: product/attribute half is rich and exercised (`Assemble` with typed violations, `Assignment.Validate`, `PartitionAttributes`, `Backoff` as single retry formula); coordination half is a paper machine (W-5). Three latent contexts (coordination / scraping-product / delivery) share one flat folder at the promotion-audit trigger. `domain/submit.go` misnames its content (attribute partitioning, not submission).
- **Orchestrator** (18 files): same bimodality. Rich: `Admit` ordered gates, `ClassifyFailure`, `CookieSet` redaction-by-construction, concurrency-safe `Session` ledger. Dead: three transition tables, three `Parse*State`, `LinkSet`, `FreeCredits` (O-1). Wire leak: `metric.go` (O-4). `lifecycle.go` breaks the bare-context-noun rule (O-12) — the skill has no slot for cross-context domain helpers.

### interactor/
- **Worker** (8 files): behaviorally excellent process managers (drain/revoke/reconnect choreography, heavily tested) but the layer is the de-facto ACL — builds and parses protobufs in every file (W-2). `pipeline.go` 677 LOC = use-case + translation + diagnostics policy; not a god-file by responsibility once translation is evicted. At 8 files: inside the borderline band → Step 0 due on next addition.
- **Orchestrator** (12 files): bimodal. Five genuine (Scheduler with credit-bounded dispatch + rollback, EventIngester, SessionAdmitter, CooldownWaker, MetricSnapshotter); seven are delegation shims (O-5) — `Seed()` is literally one line; port and interactor even share the same type name. Process managers carry the `interactor_` prefix against R-24 (O-8) — plausibly caused by the skill's own "one convention per service" sentence.

### ports/
- **Worker**: worst layer relative to rules — 2 of 3 files are vendor mirrors of the stream (W-1); `submit.go` alone is a model port. `Engine`'s "no decisions" doc is false (W-4). `CloseLocal` has no interactor consumer; `ScrapePipeline`/`SubmitPipeline` are interactor-to-interactor seams misplaced as ports (W-11) — the consumer-owned unexported-interface pattern (`inlineShipper`) already in the codebase is the right shape.
- **Orchestrator**: domain-typed throughout (zero wire types) but SP-surface-shaped: 1:1 port-file↔repo-file↔SP-cluster; method sets mirror SP signatures; port doc comments name the persistence technology; one `db:`-tagged row struct sits in `ports/` (O-6). Two ports have adapter-only consumers — sanctioned mediation that literally contradicts the "no port without an interactor consumer" sentence (skill erratum needed). Both port-file conventions mixed in one service.

### Inbound adapters
- **Orchestrator `grpc/`**: pattern-conformant in spirit (session implements `TaskSink`; reconciler/sweeper placement textbook; direction correct) but `coordination_server.go` is 931 LOC holding four responsibilities — the R-23 split (~400 LOC) blown past with no `session.go`/`translation.go` (O-2); plus the credit-policy slices (O-3) and an `onLoss` lifecycle branch (O-9, borderline-acceptable). `arch-checks.sh` has **no LOC check** for this, its most-cited threshold.
- **Orchestrator `api/`**: thin, consistent, adapter-local DTOs, `DisallowUnknownFields` — one wrong precedent (metrics handler serializing domain, O-4). Promotion to `api/v1/` overdue at 10 ≥ 5 (O-7).
- **Worker `grpc/client.go`**: exemplary 41-LOC pure transport. Correct per flowchart 2c.

### Outbound adapters
- **Worker `external_services/`**: browser correctly promoted (distinct lifecycle) with provider-less filenames; contents hold business policy (W-3, W-4) and consume the coordination contract (W-8). The downstream provider cluster: 6 flat files, promotion triggers met (≥3 provider files + own auth lifecycle), zero filenames matching `<subject>_<action>_<provider>.go` (W-7); the ACL itself is textbook-pure (I/O-free mapping, HTTP sibling, decisions delegated to domain).
- **Repositories**: worker's four Mongo repos policy-free, domain-typed. Orchestrator's 14: Rule-6/SP-only airtight; blemish — ~200 LOC of read-model bucketing/series math in `repository_metric_event.go:164+` while sibling math lives in the interactor (O-11).

### cmd/
Both `main.go` files are high-quality pure wiring. Both services carry an untracked `cmd/pprof_temp.go` with an `init()` HTTP listener (logic in cmd, env var outside the tier files; self-labelled TEMPORARY and outliving its investigation) (W-9, O-10). Worker embeds a domain invariant (lease>heartbeat) as a config assert.

### Shared tiers
`go-pkgs/` is an **empty module** (go.mod only) while generic-looking code accreted at root `internal/` instead (`slices`, `authintegration`) — the two-folders-only rule violated with no check to catch it (B-6, S-4). `internal/contracts/coordination/v1` placement itself is correct.

---

## 6. Module-by-module audit

| Module | Verdict | Key evidence |
|---|---|---|
| worker/ports | **Vendor mirror** | `Stream`, `Emit`, `Engine.Prime`, `EngineFactory.New` all proto-typed (W-1) |
| worker/interactor | **God-role: use cases + ACL** | 15 frame builders, enum translators, terminal-frame grammar ×3 files (W-2); choreography itself excellent |
| worker/domain | **Half decorative** | Dead lifecycle table/parsers (W-5); rich product half; 3 contexts hidden flat (W-13) |
| worker/external_services/browser | **Policy-bearing adapter** | OOS/price/stock/status/verdict-precedence policies (W-3); priming chain (W-4); dead `Capture` (W-10) |
| worker/external_services (flat) | **Unpromoted provider cluster** | 6 files, triggers met, grammar-breaking names (W-7); ACL purity itself exemplary |
| worker/data_repositories | **Clean** | Domain-typed, policy pushed up (`usableChildren` correctly in interactor) |
| worker/grpc | **Exemplary** | 41-LOC pure stream client |
| orch/grpc | **Overgrown + policy slices** | 931-LOC file, 4 responsibilities (O-2); seed/captcha credit releases (O-3) |
| orch/interactor | **Bimodal: 5 real, 7 shims** | One-line `Seed()`; 8-method log-and-delegate `Reclaimer` (O-5); Scheduler/EventIngester genuine |
| orch/ports | **SP-shaped** | 1:1 with repos; `db:` tags in `reclaim_port.go:15` (O-6) |
| orch/domain | **Half decorative + wire leak** | Dead tables/LinkSet (O-1); `metric.go` JSON model (O-4); rich admission/disposition/redaction |
| orch/api | **Thin, one bad precedent** | 10 handlers correct; metrics serializes domain; v1 promotion overdue (O-7) |
| orch/data_repositories | **Clean write path** | SP-only airtight; read-model math in one Mongo repo (O-11) |
| root internal/slices | **Misplaced business rule** | ADR'd cartesian expansion, 1 consumer, shadows stdlib (W-6/B-6) |
| root internal/authintegration | **Misplaced single-consumer infra** | Worker-only token store at shared root; direct pgx import tension (B-6) |
| internal/contracts/coordination/v1 | **Correct placement; identity smell** | Envelope "1.0" vs docs 1.2.0 (B-8); proto comments carry orchestrator policy + stage-shaped reasons (B-7) |
| go-pkgs | **Empty shell** | Utilities went to root internal instead |

---

## 7. DDD assessment

- **Bounded contexts between services:** the coordination/execution split is fundamentally sound and documented (context docs, published/consumed contracts, coupling table — B-9 is near best-practice). Erosion at the edges: metrics read-path crosses the boundary physically (B-5); the wire failure taxonomy encodes the executor's pipeline stages so executor refactors become contract changes (B-7); the worker's domain imports the peer's private machine as a hand-copied enum (B-7).
- **Bounded contexts within services:** flat suffix naming atomizes real contexts. Orchestrator's 18 domain files collapse (by the skill's own "change together in the same PR" test) into ~4 contexts (task-queue, session/worker, proxy/egress, observability); the worker's 15 into ~3. File-per-workflow naming keeps each pseudo-context below the per-context promotion ratchet forever — **context blindness by fragmentation**. The de-facto navigation index is WF-numbers in doc comments, which folders cannot express.
- **Aggregates & invariants:** genuine aggregate behavior exists (Session credit ledger, Snapshot assembly, CookieSet redaction, LinkSet-as-spec) but the two flagship aggregates — Task and WorkerPhase lifecycles — do not enforce their own transitions (C-3). Invariant enforcement migrated to SQL (orchestrator, by ADR-005 design) and to scattered switches (worker, by drift).
- **Ubiquitous language:** strong on the wire and in docs (frame names, WF numbers, failure reasons cross-cited to ADRs). Weak spots: `slices` (generic name for a business rule), `submit.go` holding partitioning, `Snapshot` meaning two things, port/interactor type-name twins, `authintegration` (mechanism, not capability).
- **ACL discipline:** producer-side exemplary; consumer-side absent (C-1) — the single largest DDD failure. The downstream-payload ACL (worker→SI API) is, by contrast, textbook.

## 8. Hexagonal architecture assessment

Verdict per the calibration lenses:

- **Dependency direction:** orchestrator passes fully (verified zero bad edges — rare and creditable); worker fails at the ports/interactor↔contracts seam (C-1). No adapter→adapter coupling anywhere; no cyclic deps found.
- **Ports as capabilities:** neither service fully passes. Worker ports mirror the transport; orchestrator ports mirror the persistence surface (softly). The port layer is where both services' abstractions are weakest.
- **Composition root:** both pass. All wiring in `cmd/`; consumer-owned interface pattern present where it matters.
- **Business logic placement:** both leak — worker into the scraping adapter (C-2), orchestrator into the stream adapter (C-7) and the database (C-3, by explicit but undocumented-as-authoritative design). The hexagon's *core* is partially hollow: in the orchestrator, for 7 of ~15 workflows the "application core" is an interface hop between an HTTP handler and a stored procedure.
- **Streaming-adapter special case (R-23/R-27):** the sanctioned patterns work — session-implements-sink, reconciler-in-adapter — and both services applied them. The ambiguity in "MAY hold the ledger / MUST hold no business rules" is precisely where O-3 grew.
- **Net:** the architecture is *syntactically hexagonal, semantically porous*. The skill validated shape, not substance.

## 9. AI-oriented repository assessment

Where structure lies about intent, agents follow the lie (each already observed in this repo's ADR history):

1. **Wrong-precedent attractors.** All nine outbound frame builders live in worker interactors → the next frame builder lands there. `browser/extract.go` hosts three ADR'd policies → ADR-029/030/035 were each fixed *in the adapter*. `domain/metric.go` sits beside nine correct handlers → next read-model likely copies the wrong one. Precedent gravity outweighs written rules; the skill has no rule about "the first instance sets the pattern".
2. **Dead code that reads as authoritative.** Both `lifecycle.go` tables invite an agent to "enforce" via a table nothing calls, or to trust that illegal transitions are rejected. Decorative artifacts are worse than absent ones for agent reasoning.
3. **Name collisions taxing retrieval.** Two `slices` packages (one shadowing stdlib); `interactor.Snapshot` vs `domain.Snapshot`; `interactor.TaskRequeuer` vs `ports.TaskRequeuer` (identical names, different types); `domain/submit.go` not containing submission; `reclaim` legitimately spread over five files with no index.
4. **Machine-readable declarations that lie.** `context.md` `forbidden` vs. the shipping Mongo read (B-5): agents increasingly consume frontmatter as ground truth; a contradicted declaration poisons every downstream inference.
5. **Context size:** understanding the task lifecycle requires docs + Go + 37 SP bodies (C-3); understanding worker coordination requires the proto + 7 interactor files (C-1). Both are direct consequences of the semantic findings — fixing C-1/C-3 is also the largest navigability win.
6. **Positives worth keeping:** consistent WF/ADR cross-citations in code comments; selectors centralized with contract citations; the coupling-table doc pattern; adjacent-line env mirroring convention.

---

## 10. Root causes in the implementation

Ranked by contribution:

1. **No enforcement loop** (largest). `arch-checks.sh` catches C-1 and the promotion counts *today*, yet both shipped. Nothing binds the script to CI, pre-merge, or the repo's quality gates; the skill only says "run after scaffolding or restructuring". Violations accreted change-by-change, each diff locally small (the 931-LOC file grew across four ADRs).
2. **Spec-first domain, drift-later wiring.** Both domains were authored from specs (transition tables as faithful doc mirrors); interactors were then built against different seams (`Outcome.Phase`, SP results) without threading the domain machines through. Dead code is the fossil record of that gap.
3. **SP-centric persistence (ADR-005) never reconciled with the hexagon.** Moving transitions into SECURITY-DEFINER SPs is a legitimate, ADR'd choice — but no ADR states "SQL is the enforcement locus; the Go tables are non-enforcing mirrors", so the layer diagram and reality diverged, producing both C-3 and the shim interactors (O-5).
4. **Contract convenience gravity.** The worker adopted the generated proto as its internal language because the WF specs are written in frame vocabulary and the types were *right there*. Absent a consumer-side translation example or check, the cheapest path won.
5. **Interleaving of mechanics and policy in extraction.** DOM selectors (adapter knowledge) and interpretation rules (domain knowledge) were written in the same motion, in the same file; no test existed to force the split.
6. **Temporary artifacts outliving intent** (pprof_temp ×2, untracked, env var outside tiers) — small, but symptomatic of no expiry mechanism.

## 11. Root causes in the skill

1. **S-R1 — No binding of validation to a gate.** The skill's Verify section is advisory ("after scaffolding or restructuring"). Nothing requires arch-checks in CI, in `review` mode outputs, or before ending a change. Direct cause of C-1 shipping despite detection.
2. **S-R2 — "No business rules in adapters" has no operational test.** The clause exists (R-23 gotcha) but an agent interleaving extraction mechanics with interpretation policy gets no decision procedure (C-2), and "ledger yes / rules no" doesn't classify "release credit on Closed" (C-7). Ambiguity confirmed by both services drifting in exactly this seam.
3. **S-R3 — No state-machine placement/enforcement guidance.** The skill places files, not invariants. It has no concept of an enforcement locus, no rule about datastore-enforced transitions (SP-heavy designs are common in this ecosystem — Rule 6 makes them *mandatory* here), no "decorative state machine" anti-pattern (C-3).
4. **S-R4 — Consumer-side contract hygiene unillustrated and unchecked.** R-25 text is symmetric but the only worked example (layout-examples "Streaming service" section) is the *server* split; there is no stream-client + translation example, and arch-checks reports repo-wide, not per-service-role (C-1, B-1).
5. **S-R5 — Zero service-boundary guidance.** Nothing on durable-state privacy, mirrored config, enum mirrors, dual enforcement, peer-state modeling, version authority, failure-taxonomy shape (B-2…B-8). The audit-visible failures with the highest correctness stakes (B-4, B-5) are entirely outside current skill scope.
6. **S-R6 — Port quality rules too shallow.** "A port speaks domain types" is necessary but insufficient: SP/repo-surface-shaped ports pass it (O-6); `db:` tags in ports pass it; "no port without an interactor consumer" contradicts the sanctioned adapter→port→adapter mediation (O-6 erratum); nothing warns against interactor-to-interactor seams as ports (W-11) despite the codebase itself containing the correct consumer-owned-interface alternative.
7. **S-R7 — R-24 wording invites the observed misread.** "Pick one filename convention per service and apply it to both shapes consistently" was read as "prefix everything" (O-8). The sentence needs a carve-out: the process-manager no-prefix rule *is not* subject to the consistency clause.
8. **S-R8 — Promotion rules lack a context-identification step and an LOC check.** Per-context counting is defined but the script counts per-folder (S-2), and nothing helps an agent see that 18 one-file "contexts" are really 4 (context blindness); the ~400-LOC streaming split — the threshold both services' history most needed — has no check (O-2).
9. **S-R9 — Shared-tier placement unchecked.** Two-folders-only for root `internal/` and the ≥2-consumer ladder are stated but unverified (S-4, B-6); no stdlib-shadowing name check (W-6).
10. **S-R10 — Script defects** (all reproduced): greedy `sub(".*services/","",s)` in `svc()` matches through `external_services/` → every promoted provider subfolder becomes phantom service "browser" → false cross-service violations; `bad-main` assumes all `services/*` are Go (fails on a Bun service); migration grammar check flags helper scripts (`migrate.sh`) inside `migrations/`; `go vet` violation on an intentionally-empty module; promotion audit diverges from the written counting rule.
11. **S-R11 — No migration/legacy-adoption story** (Section 15) and no guidance for the `review` input to include the new semantic checks.

## 12. Concrete improvements to the skill

Legend — Type: **MI** mandatory invariant · **DH** decision heuristic · **EX** example · **AP** anti-pattern · **VC** validation check · **MR** migration rule. Every "Draft wording" below is final-skill-ready: generic, evidence-free. Evidence column cites this audit only.

### 12.1 SKILL.md — new invariant: business-rule placement test
- **Type:** MI + DH. **Evidence:** C-2, C-7, W-4, O-11.
- **Draft wording:** "An adapter may *observe, extract, encode, decode, transport, and persist*; it may not *decide*. Operational test: if a rule answers 'what is true about the business object' or 'what should happen next' (a status derivation, a price/quantity policy, a credit movement, a retry disposition), it belongs in `domain/` (pure rules) or `interactor/` (workflow policy) — even when its inputs come from adapter-side mechanics. The adapter returns **raw signals** (booleans, counts, raw strings, presence flags); an inner layer interprets them. When mechanics and interpretation are interleaved in one function, split at the signal: extraction stays, interpretation moves. Sequencing that must interleave with transport I/O may remain adapter-side only if each decision point delegates to an inner-layer function."
- **Effect:** gives agents the missing decision procedure at the exact seam where both audited services drifted; converts "no business rules" from aspiration to test.

### 12.2 SKILL.md + placement-rules.md — enforcement locus for state machines
- **Type:** MI + AP + VC. **Evidence:** C-3, W-5, O-1, B-3.
- **Draft wording (rule):** "Every state machine has exactly **one declared enforcement locus** — the place where an illegal transition actually fails: a domain type invoked on every mutation path, or a datastore guard (stored procedure, conditional update). If the locus is the datastore, say so in a comment atop the domain type and in the owning docs; the in-service transition table is then a **conformance oracle** and MUST be exercised by a test that drives the datastore guards through every legal and illegal move and asserts agreement. A transition API (`Transition`, `CanTransitionTo`) with zero non-test call sites and no conformance test is forbidden."
- **Draft wording (anti-pattern):** "**Decorative state machine** — a domain transition table nothing calls. It documents nothing reliably (it drifts), and it actively misleads: readers and agents assume illegal transitions are rejected at runtime. Wire it, test it against the real locus, or delete it."
- **VC:** arch-checks: for each exported `Transition`/`CanTransitionTo` in `domain/`, require ≥1 non-test call site outside `domain/` (else flag `decorative-state-machine`, report-only).
- **Effect:** directly prevents the most dangerous artifact class found; makes SP-centric designs (common with SP-only data-access policies) first-class instead of off-model.

### 12.3 placement-rules.md + layout-examples.md — consumer-side contract hygiene
- **Type:** MI (restated) + EX + VC. **Evidence:** C-1, B-1, W-8.
- **Draft wording:** "The adapter-only rule for generated contracts binds **each service in each role**. A service *consuming* a stream contract owns a domain vocabulary for every frame it sends or receives and translates in its stream-client adapter (`grpc/translation.go` beside `grpc/client.go`) — exactly mirroring the producer's server-side translation. Tells that the seam is missing: port signatures naming generated types; frame constructors in `interactor/`; a wire enum compared or switched on outside the adapter; a second outbound adapter importing the coordination contract because port signatures force it through."
- **EX (layout-examples):** add the client-side twin of the existing server split — `grpc/client.go` + `grpc/translation.go`, a sealed domain event sum type for outbound frames, before/after of a port signature de-wired.
- **VC:** report `inner-imports-contracts` **grouped per service** and mark the guilty layer (`ports`/`interactor`/`domain`), so asymmetric drift (one service clean, its sibling colonized) is legible in the output.
- **Effect:** closes the exact asymmetry observed — the rule existed, the example and the per-service accounting did not.

### 12.4 placement-rules.md — port quality rules
- **Type:** DH + AP + VC + erratum. **Evidence:** O-6, W-1, W-11.
- **Draft wording:** "(a) Ports are shaped by the *capability the interactor needs*, not by the adapter's surface. A port whose method set mirrors a repository's query/procedure inventory one-to-one, or whose doc comments name the persistence technology, is an adapter interface promoted inward — regroup by capability and describe behavior ('atomically claims the next unit of work'), not mechanism. (b) No serialization metadata in `ports/` or `domain/`: a struct with `db:`/`bson:`/wire tags is an adapter row/DTO — keep it in the adapter and map. `json:` tags are permitted only in adapter-local DTOs and `contracts/` packages. (c) Erratum: 'no port without an interactor consumer' applies to *outbound capability* ports. Two other seams are sanctioned: push/sink ports implemented by a driving adapter, and **adapter→port→adapter mediation** where an inbound handler invokes a capability implemented by another adapter without business policy in between. (d) A seam between two interactors is not a port — use a consumer-owned unexported interface beside the consumer."
- **VC:** flag struct fields with `db:`/`bson:` tags under `ports/` and `domain/`.
- **Effect:** upgrades "speaks domain types" (necessary) to capability-shaped (sufficient); removes a rule contradiction agents currently must resolve by guessing.

### 12.5 placement-rules.md — R-24 wording fix
- **Type:** clarification. **Evidence:** O-8.
- **Draft wording:** "The 'one convention per service' sentence governs the choice of *role names* only. The no-prefix rule for process managers is absolute: `scheduler.go`, never `interactor_scheduler.go`. A service always mixes prefixed use cases with unprefixed process managers — that mix *is* the convention."
- **Effect:** removes the misread that produced prefix-everything naming.

### 12.6 placement-rules.md — anemic interactor guidance
- **Type:** DH + AP. **Evidence:** O-5.
- **Draft wording:** "A use-case interactor must own at least one of: a decision, an invariant check, a composition of ≥2 port calls, or cross-cutting policy (retry budget, ordering, idempotency). A one-line body delegating to a same-named port is a **shim interactor**: either enrich it with the policy currently living elsewhere (often in an adapter or a datastore procedure) or delete it and let the inbound adapter consume the port directly via the sanctioned mediation seam. Do not keep shims to satisfy the layer diagram. When a datastore-procedure-centric design intentionally hosts workflow logic in the database, record that as the enforcement-locus decision (see state-machine rule) instead of wrapping every procedure in a pass-through."
- **Effect:** stops layer-ceremony inflation; ties the hollow-hexagon symptom to its cause and its sanctioned alternatives.

### 12.7 SKILL.md gotchas + placement-rules.md — streaming adapter: ledger vs. policy line
- **Type:** DH + VC. **Evidence:** C-7, O-2, O-9.
- **Draft wording:** "The per-connection session may hold a domain entity (e.g. a credit ledger) and *mutate it as instructed*; it may not decide **when or why** it moves. The decision ('release on settlement', 'reserve on reattach', 'which lifecycle branch on connection loss') is interactor policy — expose it as an interactor method the adapter calls at its sequence points: **the adapter keeps the ordering, the interactor keeps the policy**. Exception: a reconciler repairing adapter-owned registry state may decide over that state, but any durable transition it triggers goes through an interactor. Split the server file at ~400 LOC or the second responsibility (registry, translation, reconciler) — whichever first — into the canonical `server/<svc>_server/session/translation/<name>_reclaim` shape."
- **VC:** arch-checks: warn when any non-test file under a streaming-adapter folder (`grpc/`, `ws/`, `sse/`) exceeds ~400 LOC (`streaming-file-loc`, report-only).
- **Effect:** resolves the exact ambiguity where credit policy leaked; adds the missing check for the skill's most-cited numeric threshold.

### 12.8 placement-rules.md — wire response models
- **Type:** AP + EX. **Evidence:** C-8 (O-4).
- **Draft wording:** "**Wire model in domain** — a struct whose field tags, envelope/version/status constants, or shape mirror a published request/response schema does not belong in `domain/`, even if only one endpoint uses it. It is an adapter-local DTO (R-21 tier 1); the handler maps domain values into it. Tell: changing a response contract would edit `domain/`."
- **Effect:** removes the one wrong precedent class that sits beside correct ones and gets copied.

### 12.9 shared-code.md — occupancy proof + naming hygiene
- **Type:** MI + VC. **Evidence:** B-6, W-6, S-4.
- **Draft wording:** "Root `internal/` admits exactly two children: `contracts/` and `kernel/`. Anything else is a violation regardless of content. Placement in any shared tier (root `internal/`, `go-pkgs/`) requires **≥2 actual importing services, verified by import listing** — anticipated reuse does not qualify; single-importer packages are demoted into their consumer. A shared package name must not shadow a standard-library package name, and a package whose content encodes a business rule must carry a business name inside the owning service, never a generic name in a shared tier."
- **VC:** arch-checks: (a) flag any root-`internal/` child other than `contracts`/`kernel`; (b) for each root-`internal/` and `go-pkgs/` package, count distinct importing services via `go list`; <2 → flag; (c) flag shared package basenames colliding with the Go stdlib list.
- **Effect:** the audited repo's shared-tier drift (both packages) becomes mechanically impossible to miss.

### 12.10 NEW reference file `references/service-boundaries.md`
- **Type:** MI + DH + AP + VC (a new skill area). **Evidence:** B-2…B-9, C-4, C-5, C-6.
- **Contents (draft wording, all generic):**
  1. **Durable-state privacy.** "A service's datastores (tables, collections, buckets) are private. Another service reading them is a *contract*: declare it (consumed contract id + pinned version), implement it against a schema artifact, and never re-declare table/collection identifiers as string literals in the reader. Indirection through a logical third context does not exempt the physical reading process."
  2. **Agreed values are contract.** "Any value two services must both hold to behave correctly (lease windows, heartbeat intervals, timeouts that bound each other) is contract, whatever file it lives in. Preference ladder: (1) transmit in-band at session establishment, receiver **adopts**; (2) transmit and **fail** on mismatch; (3) transmit and warn — a smell; (4) silent config mirroring with no runtime comparison — forbidden when the value feeds a correctness decision (authority windows, idempotency, lease reclaim)."
  3. **One enforcement locus per cross-service machine; coupling table for the peer.** "Each state machine is owned and enforced by exactly one service. The non-owner documents only a *coupling table* (own-state ↔ peer-state, mediated by which messages) and never re-declares the peer's transition table or models the peer's private enum in its `domain/` — if peer state is needed for logs, keep it a string at the adapter."
  4. **Enum mirrors need exhaustiveness tests.** "Re-modeling a closed wire enum as a domain type is correct layering — *if* a test round-trips the domain set against the generated enum's name map (count + values) so a contract bump breaks the lagging mirror's build. A mirror the service's own code bypasses (emitting the raw wire constant) signals the mirror is dead or the layering is broken."
  5. **Dual enforcement requires a reconciliation story.** "When both sides of a stream track the same numeric invariant (credits, slots, quotas), name the authoritative side and design the disagreement path (reject verdict + compensating update) up front. Two ledgers with no reconciliation protocol is an incident template."
  6. **Failure taxonomies classify by fault locus.** "Cross-boundary failure reasons are classified by locus (work-intrinsic / infrastructure / peer-protocol), not by the executor's internal stage names; stage-named wire reasons make internal refactors into contract bumps. Where stage detail is kept for diagnostics, pair it with a locus class owned by the coordinator."
  7. **One version authority.** "A contract has one version identity mapped to something runtime-observable (wire field, negotiated capability, or an explicit 'additive-only within envelope N' policy written beside the envelope constant). A documented SemVer and a wire version with no written mapping is a defect."
- **VCs (arch-checks additions, all report-only initially):** cross-service duplicate datastore-identifier constants; identically-suffixed env names under different service prefixes without a waiver file; per-service SP-name-prefix call check in shared-DB repos.
- **Effect:** brings the highest-stakes failure class found (correctness-bearing boundary coupling) into skill scope for the first time. SKILL.md gains a routing row: "Designing or reviewing anything two services must agree on → read `references/service-boundaries.md`."

### 12.11 SKILL.md Verify section — enforcement binding
- **Type:** MI. **Evidence:** S-R1 (C-1 shipped despite detection).
- **Draft wording:** "arch-checks is a **gate, not a suggestion**: wire it into CI (or the repo's task runner) so it runs on every change that touches Go files, and run it before ending any change that adds, moves, or renames files. In `review` mode, always include the script's findings verbatim in the report. A violation the script already detects that ships anyway is a process failure to be raised, not a pre-existing condition to be inherited: when starting work in a repo, run the script once and report standing violations before adding to them."
- **Effect:** converts the skill's biggest observed failure mode (detected-but-shipped) into a named responsibility.

### 12.12 scripts/arch-checks.sh — defect fixes + new checks
- **Type:** VC. **Evidence:** S-1…S-6, plus checks from 12.2/12.3/12.4/12.7/12.9/12.10.
- Fixes: (a) `svc()` greedy-regex — anchor the match to the first path segment (`sub(/^services\//,"",s)` on a rooted path, or match `(^|/)services/` non-greedily) so `…/internal/external_services/<provider>` no longer yields a phantom service; (b) promotion audit: group per-context by filename stem within a layer (per the written counting rule) instead of raw per-folder counts, and mark the output as heuristic; (c) `bad-main`: skip `services/*` directories containing no `.go` files (non-Go services); (d) migration grammar: exempt non-migration helper files by extension allowlist or flag them as `misplaced-script` (scripts belong outside `migrations/`) rather than `bad-migration-name`; (e) skip build/vet for modules with zero `.go` files.
- New checks (from proposals above): `decorative-state-machine`, per-service `inner-imports-contracts` grouping, `tags-in-inner-layers` (`db:`/`bson:` under `ports|domain`), `streaming-file-loc`, `root-internal-occupancy`, `shared-tier-importer-count`, `stdlib-shadow-name`, cross-service duplicate datastore identifiers.
- **Effect:** the script stops crying wolf (false positives erode trust — a script that mislabels same-service imports as cross-service trains users to ignore it) and starts covering the semantic rules the audit shows matter most.

### 12.13 layout-examples.md — three new worked examples
- **Type:** EX. **Evidence:** C-1, C-2, O-5.
- (a) **Stream-client consumer service**: client + translation + sealed domain event sum, mirroring the existing server example. (b) **Extraction adapter with raw-signal boundary**: an adapter reading a volatile external surface (page, document, feed) returning presence flags/raw strings; the domain classifier deriving status/price/quantity; before/after showing policy moving inward. (c) **Shim-interactor counter-example**: the one-line pass-through annotated with the enrich-or-delete resolution.
- **Effect:** examples are what agents actually copy; each new example targets an observed wrong-precedent attractor.

### 12.14 adr-cheatsheet.md — new rule rows
- **Type:** doc sync. Add rows R-28…R-33 for: business-rule placement test (12.1), enforcement locus (12.2), consumer-side contract hygiene (12.3), port quality (12.4), service boundaries (12.10, one row pointing at the reference file), validation binding (12.11). Renumber nothing existing.

## 13. New rules that should become mandatory

Promoted from optional/absent to **mandatory invariant**, because the implementation proves advisory strength was insufficient:

1. **Adapters decide nothing** (12.1) — both services leaked policy into adapters under the current advisory clause.
2. **One enforcement locus per state machine; no decorative transition tables** (12.2) — both services shipped dead machines.
3. **Consumer-side wire translation at the stream-client adapter; generated types never in port/interactor signatures — checked per service** (12.3) — one service fully colonized while the sibling stayed clean.
4. **No serialization tags (`db:`/`bson:`/wire) in `ports/` or `domain/`** (12.4b) — leaked despite "speaks domain types" passing.
5. **Root `internal/` = `contracts/` + `kernel/` only; shared-tier residency requires ≥2 verified importers** (12.9) — violated invisibly for months.
6. **Peer datastores are private; reads are declared contracts** (12.10.1) — shipped against an explicit `forbidden` declaration.
7. **Correctness-bearing agreed values never live only in mirrored config** (12.10.2) — a lease-authority decision currently rides on silent mirroring.
8. **arch-checks runs as a gate on every layout-touching change** (12.11) — the only reason most of the above shipped.

## 14. Anti-patterns the skill should explicitly forbid

Named, for the SKILL.md anti-pattern list (wording generic; each was observed in evidence):

1. **Decorative state machine** — transition API with no non-test callers and no conformance test.
2. **Policy-bearing adapter** — status/price/quantity/credit/retry decisions inside an adapter, interleaved with mechanics.
3. **Wire-colonized core** — ports/interactors whose signatures or switches speak generated contract types; frame builders in use cases.
4. **Shim interactor layer** — pass-through use cases kept to satisfy the layer diagram.
5. **SP-surface port** — port method set mirroring a procedure/query inventory 1:1, docs naming the persistence technology.
6. **Row DTO promoted inward** — `db:`/`bson:`-tagged structs in `ports/`/`domain/`.
7. **Wire model in domain** — schema-mirroring tagged structs + envelope constants in `domain/`.
8. **Peer-enum modeling** — a hand-copied mirror of another service's private state machine in `domain/`.
9. **Silent config mirror** — cross-service agreed value with no in-band transmission or runtime comparison.
10. **Peer-datastore reach-in** — reading another service's tables/collections via re-declared string identifiers.
11. **Generic-name business rule in a shared tier** — business algorithms under stdlib-flavored shared package names (worse when shadowing a stdlib name).
12. **Immortal temporary** — "TEMPORARY" instrumentation files in `cmd/` with `init()` side effects, outside config tiers, outliving their investigation.

## 15. Migration extension proposal

The skill currently assumes greenfield placement. Add `references/migration.md` (skill-area name: incremental adoption) covering:

1. **Assess before moving.** Run arch-checks on the untouched repo; the standing-violation report is the baseline ledger. Classify each violation by the audit's root-cause classes; only `impl-drift` items are safe mechanical moves — `tradeoff-needs-doc` items need an ADR *before* any move (else the move re-litigates a settled decision), and `ambiguous-guidance` items go to Step 0.
2. **Identify bounded contexts empirically**, not by folder: cluster files by PR co-change history and shared vocabulary ("two candidates that always change in the same PR are one context" — already in the skill; make it the legacy-analysis tool). Record the context map as a table in the owning docs before moving anything.
3. **Strangler order — outside-in:** (a) composition root first (isolate construction in `cmd/`); (b) translation seams next (introduce `translation.go` at each adapter that owns a wire format; de-wire port signatures one port at a time — each port is an independently shippable step); (c) policy extraction third (move decisions out of adapters behind the raw-signal boundary, one rule per change, each guarded by a characterization test written *before* the move); (d) folder renames/promotions last — they are the cheapest and least urgent, despite being the most visible.
4. **Anti-corruption layers during (not after) migration:** when an inner layer currently consumes a wire type, first introduce the domain type + mapping at the adapter while *both* flow, then migrate call sites, then delete the wire path — never a big-bang signature flip.
5. **State-machine migrations:** never move an enforcement locus and refactor the code shape in one change. First make the current locus explicit (declare + conformance-test it per 12.2); only then, if desired, relocate enforcement — the conformance test is the safety net.
6. **Compatibility and rollback:** every step keeps the build green and behavior identical (arch-checks + full test suite as checkpoint after each step); promotions update all import sites in the same change (existing rule); anything touching a published contract or a peer-visible identifier escalates out of migration into the contract-change process — migration never bumps a contract as a side effect.
7. **Ratchet, don't boil.** Maintain a checked-in baseline of standing violations (the script's JSON output); CI fails only on *new* violations. Burn the baseline down deliberately; never let it grow. This is the mechanism that makes 12.11 adoptable in a brownfield repo.
8. **Repository evolution strategy:** module-topology changes (single-module → workspace) are their own migration class — do them in isolation, never combined with layer moves.

## 16. Prioritized action plan

Skill-improvement work (the audit's primary objective), ordered by leverage; implementation-repair items listed second as evidence-holders' guidance, **not** executed by this audit.

**Skill (do in this order):**
1. Fix arch-checks defects S-1…S-6 (12.12 fixes) — restore trust in the tool before adding rules to it.
2. Add enforcement binding to SKILL.md Verify (12.11) + the ratchet mechanism (15.7). Highest-leverage single change: it addresses the root cause that let everything else ship.
3. Add the business-rule placement test (12.1) + streaming ledger/policy clarification (12.7) — the two ambiguities that produced Critical/High leaks in both services.
4. Add the decorative-state-machine rule + check (12.2) — highest correctness-risk artifact class.
5. Add consumer-side contract hygiene: rule restatement, client-side example, per-service check grouping (12.3, 12.13a).
6. Add port-quality rules + erratum (12.4) and R-24 wording fix (12.5).
7. Create `references/service-boundaries.md` (12.10) + its report-only checks — new scope, biggest write.
8. Add shared-tier occupancy/importer checks (12.9), anemic-interactor heuristic (12.6), wire-model-in-domain anti-pattern (12.8), remaining examples (12.13b/c), cheatsheet rows (12.14).
9. Author `references/migration.md` (Section 15).
10. Re-run the improved arch-checks against this repo as the acceptance test: it must (a) produce zero false positives, (b) flag C-1, C-3-class, tag-leak, occupancy, and promotion findings correctly.

**Implementation (for the repo's own backlog, per its change-process rules; ordered by risk):**
1. W-1/W-2: introduce the worker's translation seam (`grpc/translation.go` + domain frame vocabulary); de-wire ports — one mechanical refactor, Critical.
2. W-3: raw-signal boundary in the browser adapter; move status/price/quantity policy into domain.
3. O-1/W-5: declare SQL (resp. document the worker's phase handling) as enforcement locus + add conformance tests; delete or wire dead helpers.
4. B-4: transmit `TASK_LEASE_TTL` in-band (ConfigSnapshot) and adopt-or-fail; B-5: declare + schema-pin the metrics read or reroute it.
5. O-3 credit-settlement methods on the interactor; O-4 metrics DTO to `api/`; B-2 enum-exhaustiveness tests.
6. Mechanical hygiene: O-2 file split, O-7 `api/v1` promotion, W-7 provider-folder promotion, W-6/B-6 demote root-internal packages, O-8 renames, pprof_temp deletion, migration-name backlog.

---

*Evidence ledger ends here. Per the audit charter: everything in Sections 12–15 labeled "Draft wording" is written to be lifted into the skill verbatim, with no reference to the audited services; all service-specific material stays in Sections 1–10 and the evidence citations.*
