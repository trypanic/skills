# Layout cheatsheet — quick lookup

based on [ADR](../adr/README.md)

One-line summary per rule.

| Rule | Topic                              | Summary                                                                                                                                                                                                                                                                                                                                                                                                 |
| ---- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R-01 | Architecture                       | Pragmatic flat hexagonal. Inner layers (`domain`, `interactor`, `ports`) abstract; outer adapters concrete.                                                                                                                                                                                                                                                                                             |
| R-02 | Scope                              | Folder layout + file placement only. Out: observability, file-splitting, format, lint, tests, build.                                                                                                                                                                                                                                                                                                    |
| R-03 | Middleware                         | Lives in adapter package. `<inbound>/middleware_<concern>.go`. Promote to `<inbound>/middleware/` at 4+. No top-level `middleware/`.                                                                                                                                                                                                                                                                    |
| R-04 | API versioning                     | Suffix `<resource>_handler_v<N>.go`. Promote to `api/v<N>/` at ~5+ files; drop suffix inside.                                                                                                                                                                                                                                                                                                           |
| R-05 | Bounded context                    | Suffix `<layer>_<context>.go`. Promote to `<layer>/<context>/` at ~10+. No combined `<A>_<B>.go`.                                                                                                                                                                                                                                                                                                       |
| R-06 | Repo shape                         | Monorepo primary. Single-service uses same skeleton; collapse `services/`, `go-pkgs/`, `internal/`, `migrations/<service>/`.                                                                                                                                                                                                                                                                            |
| R-07 | Shared Go folder name              | `go-pkgs/`, never `pkg/`. Pattern `<lang>-pkgs/`.                                                                                                                                                                                                                                                                                                                                                       |
| R-08 | `go-pkgs/` content                 | Generic stdlib utilities, `<domain>x` / `<domain>kit`. Reusable infra → `go-pkgs/infra/<pkg>/` (primary), contribute to existing community SDK (secondary), or dedicated `<org>/go-sdk` repo (tertiary).                                                                                                                                                                                                |
| R-09 | Cross-service business code        | Root `internal/contracts/` (cross-service only) + `internal/kernel/`. Kernel admission: 2+ consumers, stable contract, rare changes; kernel root-only, no per-service tier.                                                                                                                                                                                                                             |
| R-10 | `go-pkgs/` files                   | One subfolder per package. Files `<action>.go`. No `_<provider>` suffix.                                                                                                                                                                                                                                                                                                                                |
| R-11 | Cross-service event payloads       | Root `internal/contracts/<subject>_<verb>_event.go`. Not `messages/`/`events/`/`dto/`.                                                                                                                                                                                                                                                                                                                  |
| R-12 | Migrations location                | Repo root `migrations/`. Shared DB: `migrations/<technology>/`. Per-service: `migrations/<service>/<technology>/` (mono) or `migrations/<technology>/` (single).                                                                                                                                                                                                                                        |
| R-13 | Config                             | Per-service. `services/<service>/config/` or `services/<service>/internal/config/`. No root `config/`.                                                                                                                                                                                                                                                                                                  |
| R-14 | Single binary                      | One `cmd/main.go` per service. All subcommands as Cobra under `cli/`.                                                                                                                                                                                                                                                                                                                                   |
| R-15 | `cli/`                             | Inbound adapter parallel to `api/`/`consumer/`. `<action>_command.go`. Logic delegates to `interactor/`.                                                                                                                                                                                                                                                                                                |
| R-16 | `data_repositories/` vs `storage/` | Schema-shaped vs blob-shaped. Not SQL/NoSQL. Not in-memory/persisted.                                                                                                                                                                                                                                                                                                                                   |
| R-17 | `external_services/<provider>/`    | Flat default `<subject>_<action>_<provider>.go`. Promote at ~10+ files / 3+ infra files / distinct lifecycle. Drop provider in filenames inside.                                                                                                                                                                                                                                                        |
| R-18 | Background work                    | Events → `consumer/`. Scheduled → `cli/` Cobra subcommand + external scheduler. Polling → `consumer/`. No `workers/`.                                                                                                                                                                                                                                                                                   |
| R-19 | `scripts/`                         | bash/python/sql only. Never Go. Go-runtime tasks → `cli/`.                                                                                                                                                                                                                                                                                                                                              |
| R-20 | Migration filename grammar         | Closed verb set: `create \| add \| drop \| alter \| rename \| backfill \| fix \| refactor \| seed`. Shared layout:`<seq>_<service\|shared>_<verb>_<desc>.<up\|down>.sql`. Per-service:`<seq>_<verb>_<desc>.<up\|down>.sql`.                                                                                                                                                                             |
| R-21 | Contract scope                     | 3 tiers by sharing scope. 1 adapter → adapter-local. 2+ components in one service → `services/<service>/internal/contracts/` (single: `internal/contracts/`), service-private. 2+ services → root `internal/contracts/` (at scale namespace by producer: `internal/contracts/<service>/`). Ladder: local→service→root. Primitive/stdlib types only; no domain/kernel/adapter imports.                   |
| R-22 | Module topology                    | Two co-equal shapes, pick by scale. A — single-module: one root `go.mod`. B — multi-module workspace: root `go.work` (no root `go.mod`) + one `go.mod` per `go-pkgs/`, `internal/`, each `services/<service>/`; services `require` the shared modules. Multi-module **requires** `go.work`; orphan per-service `go.mod` (no workspace) forbidden. Folder/layer/dep rules identical in both.             |
| R-23 | Streaming server adapter           | gRPC bidi / WebSocket / SSE = first-class inbound adapter, named by transport (`grpc/`/`ws/`/`sse/`), NOT Step 0. Owns connection-scoped state. Start `grpc/server.go`; split (`server`/`<svc>_server`/`session`/`translation`/`<name>_reclaim`) at ~400 LOC or 2nd responsibility. Session may hold/mutate a domain entity as instructed, but interactor decides when/why it moves; adapter keeps ordering, interactor keeps policy. Reconciler coupled to adapter state lives in the adapter pkg; durable transitions still go through an interactor. Stream client → `grpc/client.go`. |
| R-24 | Two interactor shapes              | `interactor/` holds use cases (`interactor_<context>.go`, ~1–3 port calls, no goroutines) AND process managers (`<role>.go` — pipeline/processor/scheduler/reconnector — loops/goroutines/mutexes/timers). Both flat until ≥10-file promote. "One convention per service" governs role names only; the no-prefix rule for process managers is **absolute** (`scheduler.go`, never `interactor_scheduler.go`). Carve-out: prefixed use cases mixed with unprefixed process managers in one flat `interactor/` **is** the convention, not an inconsistency to fix.                                                                                                       |
| R-25 | Generated contracts adapter-only   | A generated wire contract (versioned `internal/contracts/**/v<N>` or any `*.pb.go`) is importable only by adapters; forbidden in `domain`/`ports`/`interactor`. Map at the adapter edge. Enforced by `arch-checks.sh` (`inner-imports-contracts`). Refines R-21 for generated transport types.                                                                                                          |
| R-26 | Translation / ACL                  | Domain↔wire mapping lives with its adapter; never `mapper/`/`dto/`. Small → inline or `<adapter>_translation.go`. Large (>~200 LOC / >2 files) → named cluster in the promoted folder (`external_services/<provider>/payload.go`, `grpc/translation.go`). Pure, no I/O.                                                                                                                                 |
| R-27 | Port shapes                        | Port = interface (multi-method) or `func` type (single-method seam). Query/command ports → outbound adapter (common). Push/sink/trigger ports → implemented by a *driving* (inbound) adapter (stream sink, `Emit`); allowed for streaming, dep stays `adapter→ports`. File `<context>_port.go` or grouped `<adapter>.go`. Erratum (R-31): "no port without an interactor consumer" binds *outbound capability* ports only — the claim that inbound adapters never need ports is wrong; driving-adapter push/sink ports and adapter→port→adapter mediation (inbound handler invokes a capability another adapter implements, no business policy between) are sanctioned port seams.                                                                               |
| R-28 | Enforcement gate + ratchet         | `arch-checks.sh` is a gate, not a suggestion: wire into CI, run before ending any change that adds/moves/renames files; `review` mode embeds findings verbatim; detected-but-shipped = process failure — on starting work in a repo, run once and report standing violations before adding to them. Brownfield: checked-in `--json` baseline; `--baseline FILE` fails only on NEW violations, standing ones listed separately (text `## Standing violations (baseline)` \| JSON `standing` + `summary.standing`); burn the baseline down, never grow it (`references/migration.md`).      |
| R-29 | Adapters decide nothing            | Adapters observe/extract/encode/decode/transport/persist; they do not decide. Raw signals stay at the edge; status derivations, price/quantity policies, credit movements, and business retry dispositions go to `domain/` or `interactor/`. If transport sequencing must interleave with I/O, the adapter keeps ordering and delegates each decision point inward. `streaming-file-loc` warns on `grpc/`/`ws/`/`sse/` files over ~400 LOC. |
| R-30 | State-machine enforcement locus    | Exactly one declared locus per state machine — domain-enforced (`Transition`/`CanTransitionTo` on every mutation path; datastore stores, never judges) or datastore-enforced (SP/conditional-update guard; store's verdict authoritative) — never both, never neither. Declare at the transition table + owning service docs. Conformance oracle required: a `*_conformance_test.go` beside the table exercises it against the enforcing implementation. Transition API with zero non-test callers and no conformance test = decorative state machine — wire it, test it, or delete it. `arch-checks.sh` warns `decorative-state-machine` (report-only). |
| R-31 | Consumer contract hygiene + port quality | Generated-contract rule binds each service in each role: a CONSUMER of another service's versioned wire contract translates at its adapter edge (`grpc/translation.go` beside `grpc/client.go`), domain types inward — mirror of the producer's server-side translation. Missing-seam tells: port signatures naming generated types; frame constructors in `interactor/`; wire enum compared/switched outside the adapter; a second outbound adapter importing the contract because port signatures force it. Port quality: (a) capability-shaped ports, not adapter-surface mirrors; (b) no `db:`/`bson:`/wire tags under `ports/`/`domain/` (`json:` only in adapter-local DTOs + `contracts/`) — `arch-checks.sh` flags `tags-in-inner-layers`; (c) mediation erratum (see R-27); (d) interactor↔interactor seam = consumer-owned small interface beside the consumer, not a port, no shared fat interface. `inner-imports-contracts` output grouped per service, guilty layer named. |
| R-32 | Service boundaries (scope extension) | What two services must agree on has one declared owner — authoritative text in `references/service-boundaries.md`. (1) Peer datastores private: a peer read is a declared, version-pinned contract, never re-declared table/collection string literals. (2) Agreed values are contract — ladder: transmit-and-adopt → fail-on-mismatch → warn (smell) → silent config mirror (forbidden for correctness-bearing values); value sets at the contract tier (R-21), not per-service mirrors. (3) One enforcing service per cross-service state machine; non-owner keeps only a coupling table (own-state ↔ peer-state ↔ mediating messages); locus inside the owner per R-30. (4) Enum mirror requires an exhaustiveness test binding it to the generated source (contract bump breaks the lagging build). (5) Dual enforcement requires a named authority + reconciliation path. (6) Failure taxonomies classify by fault locus (work-intrinsic \| infrastructure \| peer-protocol), owned by the fault-domain service; peers translate at adapters. (7) One version authority per contract, runtime-observable. `arch-checks.sh` warns `boundary-review` (report-only heuristics: duplicate datastore-identifier consts across services; identically-suffixed env tags under different service prefixes). |
| R-33 | Incremental adoption / migration order | Assess-first, read-only-first — authoritative procedure in `references/migration.md`; `migrate` input emits an assessment report + ordered plan, NO automatic file moves. (1) Run arch-checks on the untouched repo — the standing report IS the baseline ledger (R-28); classify findings by root cause (misplacement \| missing seam \| boundary leak \| naming drift) and disposition (mechanical \| ADR-first \| Step 0) before touching anything. (2) Contexts identified empirically (PR co-change + shared vocabulary), context map recorded before the first move. (3) Strangler order outside-in: composition root (`cmd/`) → translation seams (one port per change) → policy extraction (one rule per change, characterization test first) → folder renames LAST (semantics first, spelling last). (4) ACL goes in *during* migration — both shapes flow, call sites migrate, wire path deleted; never a big-bang signature flip. (5) State machines: declare + conformance-test the current locus (R-30) before relocating any transition logic. (6) Every step build-green, behavior-identical, revertible alone; contract/peer-visible changes escalate out of migration; module-topology changes (A↔B) are their own migration class, never mixed with file moves. |

---

## Forbidden folder names

```text
pkg, shared, common, lib, utils, application, infrastructure,
interfaces, helpers, mapper, dto, gateway, workers, misc
```

Canonical alternatives:

| Forbidden           | Use instead                                                                                                                                |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `pkg/`              | `go-pkgs/<domain>x/`                                                                                                                       |
| `shared/`           | `internal/kernel/` (business) or `go-pkgs/<domain>x/` (utility)                                                                            |
| `common/`/`lib/`    | `go-pkgs/<domain>x/`                                                                                                                       |
| `utils/`/`helpers/` | domain-prefixed `go-pkgs/<domain>x/`                                                                                                       |
| `application/`      | `interactor/`                                                                                                                              |
| `infrastructure/`   | the relevant outbound adapter (`data_repositories/`, `storage/`, …)                                                                        |
| `interfaces/`       | `ports/`                                                                                                                                   |
| `mapper/`           | inline in the adapter, or `<adapter>_translation.go` / a named cluster in the promoted adapter folder (R-26)                               |
| `dto/`              | by scope: 1 adapter → adapter-local; 1 service → `services/<service>/internal/contracts/`; 2+ services → root `internal/contracts/` (R-21) |
| `gateway/`          | `external_services/<provider>/` or `api/`                                                                                                  |
| `workers/`          | `consumer/` (event/poll) + `cli/` Cobra subcommand (scheduled)                                                                             |
| `misc/`             | refuse — name what it actually is                                                                                                          |

---

## Dependency direction

### Service-internal

```text
cmd                                    → all (wiring only)
<inbound_adapter>                      → interactor, internal/contracts (service-scoped)
  e.g. api / consumer / cli
interactor                             → domain, ports, internal/contracts (service-scoped)
<outbound_adapter>                     → ports, domain, internal/contracts (service-scoped)
  e.g. external_services /
       data_repositories /
       producer / storage
services/<service>/internal/contracts  → go-pkgs (primitive/stdlib only)
```

### Monorepo-level

```text
services/<service>/internal  → services/<service>/internal/contracts (service-scoped),
                               internal/contracts (cross-service), internal/kernel,
                               go-pkgs, external SDK (if used)
internal/contracts           → go-pkgs (primitive/stdlib payloads; never internal/kernel)
internal/kernel              → go-pkgs
go-pkgs                      → (stdlib only; ideally no third-party)
go-pkgs/infra                → stdlib + necessary third-party (default home for reusable infra)
external SDK repo            → (stdlib and third-party; never imports from this repo)
```

### Disallowed

- `<layer>` (`domain`, `ports`, `interactor`) importing any adapter folder — incl. a streaming server (`grpc/`/`ws/`/`sse/`).
- `<layer>` (`domain`, `ports`, `interactor`) importing a generated wire contract (versioned `internal/contracts/**/v<N>` or any `*.pb.go`) — adapter-only (R-25).
- Service A's `internal/` importing service B's `internal/` — incl. service B's service-scoped `internal/contracts/`. Shared contracts must promote to root `internal/contracts/`.
- Service-scoped `internal/contracts/` importing `domain/`, `interactor/`, any adapter, or `internal/kernel/`.
- `internal/kernel/` importing `internal/contracts/` — and vice versa (wire payloads stay primitive/stdlib).
- `go-pkgs/` importing `internal/` or `services/`.
- External SDK repo importing this repo.
- Adapter A importing adapter B directly.
- Anything importing `cmd/`.

---

## Reusable infra placement precedence

1. **Primary — `go-pkgs/infra/<pkg>/`.** Default. In-repo, shareable across services, no premature extraction.
2. **Secondary — contribute to an existing community SDK repo** (e.g. `github.com/trypanic/go-sdk`) when the concern is already covered there and upstreaming benefits other consumers.
3. **Tertiary — dedicated org SDK repo** (`github.com/<org>/go-sdk` or named alternative) when the surface justifies its own release lifecycle, versioning, and CI. Consumed via `go.mod`. Never imports from the consumer repo.

No one is forced into a remote SDK. Default is always `go-pkgs/infra/`.

---

## Migration filename quick check

Closed verb set: `create`, `add`, `drop`, `alter`, `rename`, `backfill`, `fix`, `refactor`, `seed`.

Valid (shared):

```text
001_shared_create_auto_set_updated_at.up.sql
001_shared_create_auto_set_updated_at.down.sql
002_taobao_create_orders_table.up.sql
015_external_auth_fix_integration_lock.up.sql
003_amazon_scraping_collections.js
```

Valid (per-service):

```text
001_create_orders_table.up.sql
001_create_orders_table.down.sql
003_scraping_collections.js
```

Invalid:

```text
003_misc_stuff.up.sql                       # free-form verb
001_shared_taobao_create_table.up.sql       # shared + service combined
007_lock_fix.up.sql                         # verb as suffix
007_orders_create_alter_table.up.sql        # multiple verbs
007.fix.down.sql                            # verb as dotted segment
```
