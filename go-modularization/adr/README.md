# Architecture Decision Record — Go Modularization

> **History only.** The canonical reference for the `go-modularization` skill is [`../references/adr-cheatsheet.md`](../references/adr-cheatsheet.md). This document is preserved for the historical decision record; the cheatsheet supersedes it for day-to-day use.

Go service folder/module structure in monorepos (primary) and single-service repositories (secondary).

**Placeholder convention:** `<placeholder>` denotes a slot to fill in. Common slots:

- `<service>` — service name (e.g. `orders`, `billing`)
- `<inbound_adapter>` — entry-point adapter (`api`, `consumer`, `cli`, …)
- `<outbound_adapter>` — exit-point adapter (`data_repositories`, `external_services`, `producer`, `storage`, …)
- `<layer>` — inner-layer name (`domain`, `interactor`, `ports`)
- `<context>` — bounded context / aggregate (`order`, `product`, `user`)
- `<resource>` — API resource (`users`, `invoices`)
- `<provider>` — external provider (`taobao`, `amazon`, `s3`)
- `<action>` — verb describing the operation (`publish`, `consume`, `connect`)
- `<concern>` — middleware concern (`auth`, `logging`, `ratelimit`)
- `<subject>` — domain subject of an event (`order`, `product`)
- `<verb>` — past-tense event verb (`created`, `changed`, `completed`)
- `<N>` — version integer (`1`, `2`, …)
- `<domain>` — utility domain prefix (`string`, `time`, `slice`)
- `<pkg>` — package name (folder-level)

---

## ADR-01: Pragmatic flat hexagonal architecture

Adopt a pragmatic flat hexagonal architecture for every Go service. Inner layers (`<layer>` ∈ {`domain`, `interactor`, `ports`}) are abstract and free of infrastructure. Outer layers (all adapter folders) are concrete. Inbound adapters (`<inbound_adapter>`, e.g. `api`, `consumer`, `cli`) are entry points; outbound adapters (`<outbound_adapter>`, e.g. `data_repositories`, `external_services`, `producer`, `storage`) are exit points.

## ADR-02: Scope is folder layout and file placement only

This spec defines where files go. Out of scope: observability conventions (logging, metrics, tracing setup), Go file-splitting style (per-file size, intra-package symbol grouping), formatting rules, lint configuration, test framework choice, build tooling.

## ADR-03: Middleware lives inside the adapter package it serves

Middleware lives inside the inbound or outbound adapter package it belongs to.

- File form: `<inbound_adapter>/middleware_<concern>.go` (e.g. `api/middleware_auth.go`).
- Promotion: when 4+ middleware files exist for one adapter, promote to `<inbound_adapter>/middleware/` subfolder, with files named `<concern>.go` (e.g. `api/middleware/auth.go`).
- No top-level `middleware/` folder.

## ADR-04: API versioning uses suffix-then-folder promotion

Default to file-name suffix:

- File form: `<resource>_handler_v<N>.go` (e.g. `users_handler_v1.go`, `users_handler_v2.go`).
- Promotion: when one version exceeds approximately 5 files, promote to `api/v<N>/` subfolder (e.g. `api/v1/`, `api/v2/`).
- Inside a version subfolder, drop the version suffix: `<resource>_handler.go` (e.g. `api/v1/users_handler.go`).

## ADR-05: Bounded context uses suffix; promote to folder at scale

Prefer in-folder suffix:

- File form: `<layer>_<context>.go` (e.g. `repository_product.go`, `interactor_order.go`).
- Promotion: when one context reaches roughly 10+ files within a layer, promote to per-context subfolder `<layer>/<context>/`.
- Inside a context subfolder, drop the context suffix: `<layer>.go` (e.g. `interactor/order/interactor.go`).
- Suffixes do not combine: `<contextA>_<contextB>.go` is forbidden (e.g. `order_product.go`).

## ADR-06: Monorepo is the primary target; single-service repos are supported

Monorepo is primary. Single-service repos use the same internal service shape, with the optional `services/` wrapper omitted and root-level monorepo concerns (`go-pkgs/`, `internal/contracts/`, `migrations/<service>/`) collapsed.

## ADR-07: Use `go-pkgs/` (not `pkg/`) for shared Go code in monorepos

The monorepo-root folder for shared Go code is named `go-pkgs/`, not `pkg/`. The `pkg` folder name is forbidden. Language-prefixed names scale to other languages: `<lang>-pkgs/` (e.g. `ts-pkgs/`, `py-pkgs/`).

## ADR-08: `go-pkgs/` is for reusable Go utilities organized by domain; reusable infrastructure defaults to `go-pkgs/infra/`

`go-pkgs/` holds generic, reusable Go utilities organized by domain — pure helpers with no business logic and no IO, ideally stdlib-only dependencies.

- Package form: `<domain>x` or `<domain>kit` (e.g. `stringx`, `timex`, `mathx`, `randx`, `slicex`, `errorkit`, `urlkit`).
- Domain-prefixed package names only; the generic names `utils`, `helpers`, `common`, `shared`, `lib`, `misc` are forbidden.

Reusable infrastructure (database clients, HTTP servers and clients, message brokers, observability glue, blob storage wrappers, migration runners) follows a placement precedence:

1. **Primary — `go-pkgs/infra/<pkg>/`.** Default destination. Keeps infra in-repo, shareable across services in this monorepo, no premature extraction. The skill is agnostic and open-source-friendly: no project is forced to use any specific external SDK repo.
2. **Secondary — contribute to an existing community SDK repo** (e.g. `github.com/trypanic/go-sdk`) when the concern is already covered there and upstreaming benefits other consumers.
3. **Tertiary — dedicated org-owned SDK repo** (`github.com/<org>/go-sdk` or named alternative) when the infra surface is large enough to justify its own release lifecycle, versioning, and CI. Consumed via `go.mod`; never imports from the consumer repo.

`go-pkgs/` must never contain business types, service-specific configuration shapes, or imports from `services/...` or root `internal/`.

## ADR-09: Cross-service shared business code lives under monorepo `internal/`

Cross-service business sharing lives in monorepo-root `internal/`, with two folders only:

- `internal/contracts/` — **cross-service** event/message wire payloads (shared across 2+ services). Service-private contracts do not live here — see ADR-21.
- `internal/kernel/` — shared business primitives (e.g. `Money`, IDs, common value objects).

Admission criteria for `internal/kernel/`, all required: 2+ services already consume it; stable contract (changes are rare); no service-specific logic. The kernel is cross-service by definition and has no per-service tier — unlike contracts (ADR-21).

## ADR-10: `go-pkgs/` uses one subfolder per package with action-based file names

Each package under `go-pkgs/` (and `go-pkgs/infra/` when used) gets a dedicated subfolder.

- Folder form: `go-pkgs/<pkg>/` (e.g. `go-pkgs/stringx/`).
- File form: `<action>.go` (e.g. `publish.go`, `consume.go`, `connect.go`, `format.go`, `parse.go`).
- Technology suffixes (`_<provider>`, e.g. `_rmq`, `_pg`, `_s3`) used in service outbound adapters do not apply here — the folder name already encodes the concern.

## ADR-11: Cross-service event payloads live in `internal/contracts/`

The monorepo-root folder that holds **cross-service** event/message wire payloads (shared across 2+ services) is named `internal/contracts/`. One file per event or message contract. Contracts shared only within a single service live in that service's own contracts folder — see ADR-21.

- File form: `<subject>_<verb>_event.go` (e.g. `product_changed_event.go`, `order_completed_event.go`).
- The names `internal/messages/`, `internal/events/`, `internal/dto/` are not used.

## ADR-12: Migrations live at repository root; layout depends on DB topology

Two layouts, picked by DB topology. A repository (or service) declares which it uses; mixing within one DB instance is forbidden.

**Shared DB across services** — sequence is global per technology instance, so technology is the primary axis:

- Monorepo: `migrations/<technology>/` at repo root (e.g. `migrations/postgres/`, `migrations/mysql/`, `migrations/mongo/`).
- Single-service repo: same shape; `migrations/<technology>/`.

**Per-service DB** — sequence scoped per service, so service is primary:

- Monorepo: `migrations/<service>/<technology>/` at repo root (e.g. `migrations/orders/postgres/`).
- Single-service repo: `migrations/<technology>/` (service folder collapsed).

Common rules:

- Migrations never live inside `data_repositories/` or under `services/<service>/`.
- Forward-only technologies (e.g. Mongo) produce one file per migration; no `down` companion.
- Declarative infra config is not a migration. RabbitMQ topology, queue/exchange definitions, and similar declarative configs live outside `migrations/` — at `infra/<technology>/` at repo root (e.g. `infra/rabbit/topology.json`).
- Sequence collisions in the shared-DB layout are resolved at PR/rebase time; no automated reservation.
- Cross-service writes are forbidden in shared DB. Truly cross-cutting migrations (e.g. an `auto_set_updated_at` trigger applied to all tables, an extension install) use the reserved `shared` token — see ADR-20.
- Tool-agnostic: this ADR does not mandate a specific migration runner. The `.up.sql` / `.down.sql` convention is chosen because common SQL migration tools consume it; non-SQL technologies use their native script extension.

## ADR-20: Migration filename grammar

**Shared DB layout**:

```
<seq>_<service|shared>_<verb>_<desc>.<up|down>.sql
<seq>_<service|shared>_<verb>_<desc>.<ext>      # forward-only (e.g. mongo .js)
```

**Per-service DB layout**:

```
<seq>_<verb>_<desc>.<up|down>.sql
<seq>_<verb>_<desc>.<ext>                       # forward-only
```

Slots:

- `<seq>` — zero-padded integer (`001`, `002`, …). Sequence is per-technology in the shared layout, per-service-per-technology in the per-service layout.
- `<service>` — service name (shared layout only); identifies the owning service of a service-scoped migration.
- `shared` — reserved literal token for cross-cutting migrations affecting all services in the shared-DB layout. Must not combine with a service name.
- `<verb>` — closed set: `create`, `add`, `drop`, `alter`, `rename`, `backfill`, `fix`, `refactor`, `seed`. Free-form verbs are forbidden.
- `<desc>` — snake_case noun phrase describing the target.
- `<up|down>` — required for SQL technologies (`.up.sql`, `.down.sql`). Forbidden for forward-only technologies.
- `<ext>` — `.sql` for SQL; the native script extension for forward-only technologies (e.g. `.js` for Mongo).

Examples (shared DB):

```
migrations/postgres/001_shared_create_auto_set_updated_at.up.sql
migrations/postgres/001_shared_create_auto_set_updated_at.down.sql
migrations/postgres/002_taobao_create_orders_table.up.sql
migrations/postgres/002_taobao_create_orders_table.down.sql
migrations/postgres/015_external_auth_fix_integration_lock.up.sql
migrations/postgres/015_external_auth_fix_integration_lock.down.sql
migrations/mongo/003_amazon_scraping_collections.js
infra/rabbit/topology.json
```

Examples (per-service DB):

```
migrations/orders/postgres/001_create_orders_table.up.sql
migrations/orders/postgres/001_create_orders_table.down.sql
migrations/orders/mongo/003_scraping_collections.js
```

Forbidden:

- Free-form verbs outside the closed set (e.g. `_misc`, `_stuff`, bare `_update`).
- Combining the `shared` token with a service name (e.g. `001_shared_taobao_...`).
- Verb as suffix or dotted action segment (e.g. `_lock_fix`, `.fix.down.sql`).
- Multiple verbs in one filename.

## ADR-13: Per-service config; never at monorepo root

Configuration lives within each service:

- Monorepo: `services/<service>/config/` or `services/<service>/internal/config/`.
- Single-service: `internal/config/`.

There is no monorepo-root `config/` folder.

## ADR-14: Single binary per service: `cmd/main.go` plus Cobra subcommands

Every service has exactly one binary: `cmd/main.go`. All subcommands (server, scheduled jobs, one-off tasks, migrations as a Go-runtime fallback) are Cobra subcommands implemented inside the `cli/` inbound adapter. No multi-binary services.

## ADR-15: `cli/` is an inbound adapter, parallel to `api/` and `consumer/`

`cli/` is structurally parallel to `api/` and `consumer/`.

- File form: `<action>_command.go` (e.g. `seed_command.go`, `migrate_command.go`).
- Cobra commands defined here delegate to `interactor/` like any other inbound adapter.
- Command logic does not live in `cmd/`; `cmd/` is wiring only.

## ADR-16: `data_repositories/` vs `storage/` split is schema-shaped vs blob-shaped

- `data_repositories/` — schema-shaped persistence (e.g. PostgreSQL, MongoDB, Redis, DynamoDB, Elasticsearch).
- `storage/` — blob-shaped persistence (e.g. S3, GCS, Azure Blob, persistent local filesystem).

The split is by data shape, not by SQL/NoSQL or by in-memory/persisted.

## ADR-17: `external_services/<provider>/` subfolder at promotion threshold

`external_services/` is flat by default.

- File form: `<subject>_<action>_<provider>.go` (e.g. `payment_charge_taobao.go`, `email_send_amazon.go`).
- Promotion: when one provider reaches roughly 10+ files, has 3+ provider-specific infra files, or has a distinct lifecycle, promote to `external_services/<provider>/`.
- Inside a provider subfolder, drop the provider name from filenames; keep the transport suffix: `<subject>_<action>.go` (e.g. `external_services/taobao/payment_charge.go`).

## ADR-18: Background work routes by trigger; no `workers/` folder

Route background work by trigger type:

- Events → `consumer/`.
- Scheduled work → a Cobra subcommand under `cli/`, triggered by an external scheduler.
- Polling → `consumer/`.

There is no `workers/` folder. The name `workers` is forbidden.

## ADR-19: `scripts/` holds bash, Python, and SQL only — never Go

`scripts/` holds bash, Python, and SQL files only. Go-runtime tasks become Cobra subcommands inside `cli/`.

- Monorepo: `scripts/` at the root, plus optional per-service `services/<service>/scripts/`.
- Single-service repo: `scripts/` at root.

## ADR-21: Contracts are scoped; service-private contracts live per-service, cross-service contracts at root

Refines ADR-09 and ADR-11. A contract/DTO type is placed by its **sharing scope**, not by being a DTO. Three tiers, with a one-way promotion ladder:

1. **Adapter-local** — a request/response or mapping struct used by exactly one adapter → stays in that adapter package. No shared folder. (This is the "local to adapter" half of the `dto/` ban.)
2. **Service-scoped** — a contract shared across 2+ components *within one service* (e.g. an interactor and two of its adapters) → `services/<service>/internal/contracts/` (monorepo) or `internal/contracts/` (single-service repo). Package `contracts`. Each service declares its own; a service-scoped contract is **private to its owning service** — service B must never import service A's contracts (reinforced by the cross-service import ban, ADR-09 dependency rules).
3. **Cross-service** — a wire payload shared across 2+ services → monorepo-root `internal/contracts/` (ADR-11). Monorepo only; collapses in single-service repos. At scale, namespace by the **producing** service: `internal/contracts/<service>/` (e.g. `internal/contracts/orchestrator/`, `internal/contracts/worker/`) — one subfolder per service whose API/events the contracts describe.

Promotion ladder: adapter-local → service-scoped → root. Promote only on a real consumer crossing the next boundary, never speculatively. A struct does not move to root `internal/contracts/` until a *second service* consumes it.

Constraints on service-scoped contracts (same as root contracts): primitive/stdlib field types; no imports from `domain/`, `interactor/`, adapters, or `internal/kernel/`. They are transfer shapes, not business types.

Naming collision: both the service-scoped folder and root `internal/contracts/` use package name `contracts`. When a single file imports both, alias by scope (e.g. `import ordersc ".../services/orders/internal/contracts"` and `import contracts ".../internal/contracts"`).

Single-service mapping: with no `services/` wrapper and only one service, the cross-service tier vanishes; `internal/contracts/` carries the service-scoped meaning. ADR-06's "collapse root-level `internal/contracts/`" refers to the cross-service tier disappearing, not the folder.

Kernel is unaffected: `internal/kernel/` is cross-service by its admission criteria (2+ consuming services) and has no per-service tier.

## ADR-22: Module topology — single-module or multi-module workspace

A monorepo uses one of two module topologies. Both are first-class; pick by scale. Folder layout, layer rules, and dependency direction are **identical** across both — topology governs `go.mod`/`go.work` only, not where files go.

**A — single-module.** One `go.mod` at the repo root; the whole repo is one Go module. `internal/`, `go-pkgs/`, and services are plain packages. Simplest; the default for small monorepos and for all single-service repos.

**B — multi-module workspace.** A `go.work` at the repo root (no root `go.mod`), with one `go.mod` per shareable unit:

- `go-pkgs/go.mod`
- `internal/go.mod` — the shared cross-service module (`contracts/`, `kernel/`, and any other root-`internal/` shared packages).
- `services/<service>/go.mod` — one per service.

`go.work` lists every module under `use (...)`; each service module `require`s the `internal/` and `go-pkgs/` module paths, resolved locally through the workspace (no intra-repo version publishing). Best for scaled monorepos: per-service dependency sets, independent build/test, smaller change blast radius.

**Required when multi-module:** a root `go.work` tying the modules. Per-service `go.mod` files **without** a `go.work` (orphan modules) are forbidden — they break local sharing of `internal/`/`go-pkgs/` and force version publishing inside one repo.

**Invariant unchanged by topology:** the dependency-direction rules hold in both. Under B they manifest as cross-module `require`s — a service module requires the `internal/` module; the `internal/` module never requires a service module.

Single-service repos use topology A (one service, one module); the multi-module split has nothing to separate.

## ADR-23: Streaming server is a first-class inbound adapter; split by responsibility

Streaming RPC servers — gRPC bidirectional, WebSocket, SSE — are first-class inbound adapters named by transport: `grpc/`, `ws/`, `sse/` (`graphql/` for GraphQL). They are **not** escalated as a "new adapter kind"; only a transport outside this set is genuinely new.

A streaming server owns **connection-scoped mutable state**: a per-connection session object and a registry of live connections. Start flat (`grpc/server.go`); split the package when one non-test file exceeds ~400 LOC or a second responsibility appears. Canonical split:

- `server.go` — transport setup, keepalive, serve/shutdown.
- `<svc>_server.go` — the stream handler: recv loop, frame routing.
- `session.go` — connection-scoped state + the live-connection registry.
- `translation.go` — wire↔domain mapping (ADR-26).
- `<name>_reclaim.go` — reconciler(s) coupled to the registry (below).

The per-connection object MAY hold a domain entity (a credit ledger) and implement a driven push/sink port (ADR-27); it holds **no business rules** — those stay in `domain/`/`interactor/`. A stream **client** to one upstream is an outbound adapter: `grpc/client.go` (or `external_services/<provider>/` when one provider among several).

A reconciler/sweeper coupled to one adapter's state (a connection registry, a lease table, a cache) lives **in that adapter's package** (`grpc/<name>_reclaim.go`), started from `cmd/` — not `cli/`/`consumer/`, which would sever it from the state it repairs. This refines ADR-18: independent scheduled jobs still route to `cli/`, event/poll to `consumer/`.

## ADR-24: `interactor/` holds two shapes — use cases and process managers

The application layer holds two file shapes, both flat in `interactor/` until the ≥10-file promotion (ADR-05):

- **Use-case interactor** — one workflow step, ~1–3 port calls, no spawned goroutines. File: `interactor_<context>.go`.
- **Process manager / coordinator** — long-running or concurrent (a loop, goroutines, mutexes, channels, timers, retries) coordinating several ports over time. File: `<role>.go` (`pipeline.go`, `processor.go`, `scheduler.go`, `reconnector.go`) — role-named, **no `interactor_` prefix**.

Pick one filename convention per service and apply it to both shapes consistently. A process manager's private helper state (a ledger, an emit sink, a drain gate) lives beside it as an unexported type — it is not a use case and gets no `interactor_` file of its own.

## ADR-25: Generated wire contracts are adapter-only

A **generated wire contract** — a versioned package `internal/contracts/**/v<N>` or any `*.pb.go` package — may be imported only by adapters (`api/`, `grpc/`, `ws/`, `sse/`, `consumer/`, `producer/`, `external_services/`, `data_repositories/`, `storage/`). It is forbidden in `domain/`, `ports/`, and `interactor/`. Ports speak domain types; translate wire↔domain at the adapter boundary (ADR-26).

This refines ADR-21 (which places hand-written contract/DTO types by sharing scope) by binding *generated transport types* to the edge regardless of scope. Enforced by `scripts/arch-checks.sh` (`inner-imports-contracts`).

## ADR-26: Translation / Anti-Corruption Layer lives with its adapter

Domain↔external-wire mapping is an adapter responsibility, placed with the adapter that owns the wire format — never a top-level `mapper/` or `dto/` (both forbidden, ADR forbidden-names):

- Small → inline in the adapter, or `<adapter>_translation.go` beside it.
- Large (>~200 LOC or >2 files) → a named cluster inside the adapter's promoted folder (`external_services/<provider>/payload.go`, `payload_attributes.go`, or `grpc/translation.go`).

The ACL is **pure** — wire/domain in, the other out, no I/O; the HTTP/stream call is a sibling client file. This is the positive guidance behind the `mapper/`/`dto/` ban.

## ADR-27: Port shapes — interfaces, func ports, and driving-adapter sinks

A port is an interface (multi-method) **or** a `func` type for a single-method seam (`type Emit func(...) error`). Two roles:

- **Query/command ports** — the interactor calls an *outbound* adapter (`WorkClaimer`, repository ports). The common case.
- **Push/sink/trigger ports** — the interactor pushes through a sink that a *driving* (inbound) adapter implements (a stream server's per-connection task sink, an `Emit`, a dispatch trigger). A driving adapter implementing a port is allowed and expected for streaming; the dependency stays `adapter → ports`, never `interactor → adapter`.

File layout: `<context>_port.go`, or group a small cohesive set as `<adapter>.go`; one convention per service. ("No ports for inbound adapters" in ADR-15's spirit applies to request/response handlers, not to push/sink seams.)

## ADR-28: arch-checks is a gate — CI binding and ratchet baseline

`scripts/arch-checks.sh` is a **gate, not a suggestion**. The architecture's payoff — data sources and adapters stay swappable technical detail behind ports, the core stays transport-agnostic — exists only while the dependency rules actually hold, so validation must run where shipping happens (CI), not only where authoring happens: detection without a gate lets detected violations ship, and each shipped violation erodes exactly that swappability.

Binding:

- Wire the script into CI (or the repo's task runner) so it runs on every change that touches Go files; also run it before ending any change that adds, moves, or renames files.
- In `review` mode, always include the script's findings verbatim in the report — never summarized away.
- A violation the script already detects that ships anyway is a **process failure to be raised**, not a pre-existing condition to be inherited: when starting work in a repo, run the script once and report standing violations before adding to them.

Brownfield adoption uses a **ratchet baseline** (`--baseline FILE`): a checked-in copy of the script's `--json` report. Violations whose exact check+detail pair appears in the baseline are *standing* — still reported, under a separate heading — and only *new* violations fail the run. The baseline is burned down deliberately and never grows. Operational detail: [`../references/migration.md`](../references/migration.md).

## ADR-29: Adapters decide nothing; business policy stays inside the core

Adapters are technical edges. They may observe, extract, encode, decode, transport, and persist; they do not decide business truth or next action. If a rule answers "what is true about the business object" or "what should happen next" — status derivation, price/quantity policy, credit movement, retry disposition — it belongs in `domain/` when it is pure domain logic, or `interactor/` when it is workflow policy.

The adapter/core boundary is the raw-signal boundary. Adapters return booleans, counts, raw strings, presence flags, wire frames, and storage rows; inner layers interpret them. When mechanics and interpretation are interleaved, split at the signal. Transport sequencing that must interleave with I/O may remain adapter-side only when each decision point delegates to an inner-layer method.

Streaming adapters use the same rule. A per-connection session may hold and mutate a domain entity, such as a credit ledger, as instructed by the interactor. It may not decide when or why the entity moves. The adapter keeps ordering; the interactor keeps policy. A reconciler repairing adapter-owned registry state may decide over that registry, but durable transitions still go through an interactor. `scripts/arch-checks.sh` reports `streaming-file-loc` when one non-test file under `grpc/`, `ws/`, or `sse/` exceeds ~400 LOC, because that is the point where the edge usually starts mixing transport, translation, registry, and policy.

Hexagonal-calibration note: no divergence from the reference architecture lens. Graça's Explicit Architecture places ports inside the business logic, adapters outside, and application/domain logic in the core; Netflix's production case study keeps business logic in interactors and persistence/transport details swappable behind adapters. This ADR applies those same dependency and responsibility boundaries to adapter-side extraction and streaming sequence points.

## ADR-30: One enforcement locus per state machine

Every state machine has exactly **one declared enforcement locus** — the place where an illegal transition actually fails. Two sanctioned loci; a state machine picks one, never both, never neither:

- **Domain-enforced** — a domain type (`Transition`, `CanTransitionTo`) validates transitions and is invoked on every mutation path; the datastore stores, never judges.
- **Datastore-enforced** — a datastore guard (stored procedure, conditional update, constraint) rejects illegal moves; domain code treats the store's verdict as authoritative.

**Declaration:** the chosen locus is declared where the state machine is defined — a comment atop the transition table and a line in the owning service docs. If the locus is the datastore, say so explicitly; the in-service transition table is then a **conformance oracle**, not the enforcer.

**Conformance oracle:** whichever locus is chosen, a test (or check) MUST exercise the declared transition table against the enforcing implementation — drive every legal and illegal move and assert agreement — so the declaration cannot rot into decoration. Naming convention: a conformance test is a `_test.go` file explicitly named `*_conformance_test.go`, living beside the transition table it exercises. A transition API (`Transition`, `CanTransitionTo`) with zero non-test call sites and no conformance test is forbidden.

**Anti-pattern — decorative state machine:** a domain transition table nothing calls. It documents nothing reliably (it drifts), and it actively misleads: readers and agents assume illegal transitions are rejected at runtime. Wire it, test it against the real locus, or delete it. `scripts/arch-checks.sh` reports `decorative-state-machine` (report-only) when a `domain/` dir defines `Transition`/`CanTransitionTo` with no non-test call sites outside `domain/` (self-calls within any `domain/` dir do not count) and no `*_conformance_test.go` exercising it.

Hexagonal-calibration note: Graça's Explicit Architecture and the Netflix case study both keep business rules in the core and treat persistence as a swappable detail behind ports — the domain-enforced locus is their default reading. This ADR **deliberately diverges** by sanctioning a datastore-enforced locus as first-class (common under SP-only data-access policies): when the store judges, the declaration + conformance oracle contain the divergence — the core still owns the statement of the rule, and a test binds statement to enforcement, preserving the articles' goal that the rule stays explicit and testable rather than buried, unstated, in a replaceable adapter.

## ADR-31: Consumer-side contract hygiene and port quality

**Consumer-side contract hygiene.** The adapter-only rule for generated wire contracts (ADR-25) binds **each service in each role**. A service *consuming* another service's versioned wire contract treats it exactly like any external wire format: the consumer owns a domain vocabulary for every frame it sends or receives and translates in its stream-client adapter (`grpc/translation.go` beside `grpc/client.go`) — exactly mirroring the producer's server-side translation (ADR-26). Tells that the consumer-side seam is missing: port signatures naming generated types; frame constructors in `interactor/`; a wire enum compared or switched on outside the adapter; a second outbound adapter importing another service's contract because port signatures force it through. `scripts/arch-checks.sh` reports `inner-imports-contracts` grouped per service with the guilty layer named (`ports`/`interactor`/`domain`), so asymmetric drift — a producer clean, its consumer colonized — is legible in the output.

**Port quality.** "Speaks domain types" is necessary but not sufficient. Four rules refine ADR-27:

- **(a) Capability shape** — ports are shaped by the *capability the interactor needs*, not by the adapter's surface. A port whose method set mirrors a repository's query/procedure inventory one-to-one, or whose doc comments name the persistence technology, is an adapter interface promoted inward — regroup by capability and describe behavior ("atomically claims the next unit of work"), not mechanism.
- **(b) No serialization tags** — no serialization metadata in `ports/` or `domain/`: a struct with `db:`/`bson:`/wire tags is an adapter row/DTO — keep it in the adapter and map. `json:` tags are permitted only in adapter-local DTOs and `contracts/` packages. `scripts/arch-checks.sh` enforces the `db:`/`bson:` half (`tags-in-inner-layers`).
- **(c) Mediation erratum** — "no port without an interactor consumer" applies to *outbound capability* ports only; the earlier claim that inbound adapters never need ports is wrong. Two other seams are sanctioned: push/sink/trigger ports implemented by a *driving* adapter (ADR-27), and **adapter→port→adapter mediation**, where an inbound handler invokes a capability implemented by another adapter with no business policy in between.
- **(d) Consumer-owned interface** — a seam between two interactors is not a port. The consuming interactor declares the small (typically unexported) interface it needs, beside itself in `interactor/`; the providing interactor satisfies it. No shared fat interface.

Hexagonal-calibration note: no divergence. Netflix's case study frames every external data source — "a SQL database," "REST API," even another service's API — as a swappable adapter behind a port, with entities holding no knowledge of transport or storage: that is precisely the consumer-role rule (consuming a peer's contract is just another data source to translate at the edge). Graça's Explicit Architecture states that "Ports are created to fit the Application Core needs and not simply mimic the tools APIs" — the capability-shape rule verbatim — and places ports inside the business logic with both driving and driven adapters translating at the boundary, which sanctions the driving-adapter-implements-a-port seam the erratum restates.

## ADR-32: Service-boundary rules — scope extension

The skill previously governed folder layout and file placement inside one service (ADR-02). This ADR **extends its scope** to cross-service boundary rules: what two services must agree on, and who owns each agreed thing. The authoritative rule text lives in one place, [`../references/service-boundaries.md`](../references/service-boundaries.md); SKILL.md carries only a routing row, one gotcha, and three anti-pattern entries (silent config mirror, peer-datastore reach-in, peer-enum modeling). Seven rules, summarized:

1. **Durable-state privacy** — a service's datastores (tables, collections, buckets) are private; peers get its data through its API/contract, never by reaching into its collections/tables. A peer read is a declared, version-pinned contract implemented against a schema artifact — never re-declared table/collection string literals in the reader.
2. **Agreed values are contract** — any value two services must both hold to behave correctly is contract, whatever file it lives in. Preference ladder: transmit-and-adopt → transmit-and-fail-on-mismatch → transmit-and-warn (a smell) → silent config mirroring with no runtime comparison (forbidden for correctness-bearing values). Agreed value sets prefer contract-tier constants/enums (ADR-21 ladder) over per-service mirrors.
3. **One enforcement locus per cross-service machine; coupling table for the peer** — each state machine (and each rule two services could both enforce over a shared datastore) is owned and enforced by exactly one named service; the non-owner documents only a coupling table (own-state ↔ peer-state ↔ mediating messages). Inside the owner, the locus choice follows ADR-30.
4. **Enum-mirror exhaustiveness tests** — re-modeling a closed wire enum as a domain type is correct layering only with a test round-tripping the mirror against the generated enum's name map (count + values), so a contract bump breaks the lagging mirror's build.
5. **Dual-enforcement reconciliation** — when both sides track the same numeric invariant (credits, slots, quotas), name the authoritative side and design the disagreement path (reject verdict + compensating update) up front; two ledgers with no reconciliation protocol is an incident template.
6. **Fault-locus taxonomies** — cross-boundary failure reasons classify by fault locus (work-intrinsic / infrastructure / peer-protocol), not by the executor's internal stage names; the taxonomy lives with the service owning the fault domain, and peers translate at their adapters (ADR-26).
7. **One version authority** — exactly one service owns a contract's version lifecycle, mapped to something runtime-observable; a documented SemVer with no written mapping to a wire version is a defect.

`scripts/arch-checks.sh` supports the reference with report-only `boundary-review` warnings (heuristics, never violations): cross-service duplicate datastore-identifier string constants, and identically-suffixed env-tag names under different service prefixes.

Hexagonal-calibration note. The Netflix case study is the citable rationale for rule 1: its business logic "should not depend on where we get data from", and every data source — a database, a REST API, another service — sits behind a port as a swappable adapter (they swapped a JSON API for a GraphQL data source in hours precisely because of that seam). A peer's private datastore reached directly is a data source that can never be swapped — its schema and lifecycle belong to the peer — so **a peer's datastore is never your data source**; the peer's published contract is, consumed behind your own port with adapter-edge translation (ADR-25/26/31). Graça's Explicit Architecture decouples components through events and a deliberately small shared kernel — the calibration for rule 2's preference of shared contract-tier values over silent per-service mirrors — and permits a component to query another component's data only read-only, never modify it; at service granularity this ADR tightens that read-only allowance into a declared, version-pinned contract (rule 1). That tightening is a deliberate, recorded calibration choice, not a silent divergence.

## ADR-33: Incremental adoption and migration order

The skill previously assumed greenfield placement. This ADR adds an incremental-adoption path for existing codebases; the authoritative procedure lives in [`../references/migration.md`](../references/migration.md). Migration is **assess-first and read-only-first**: an assessment report and an ordered plan come before any move, and the `migrate` input performs no automatic file moves — execution is separate, individually revertible, reviewed changes. Six ordering principles:

1. **Assess before moving** — run `arch-checks.sh` on the untouched repo; the standing-violation report is the baseline ledger (the ADR-28 ratchet needs no separate bookkeeping). Classify every finding by root-cause class (misplacement / missing seam / boundary leak / naming drift) and by disposition (mechanical drift → safe move; settled trade-off → ADR before any move, else the move re-litigates a settled decision; ambiguous guidance → Step 0) before touching anything.
2. **Empirical contexts** — bounded contexts come from PR co-change clusters and shared vocabulary, not legacy folder names; the context map is recorded before the first move, and every move cites a row in it.
3. **Strangler order, outside-in** — composition root (`cmd/`) first, translation seams next (one port de-wired per change), policy extraction third (one rule per change, characterization test written before the move), folder renames and promotions **last**. Rationale: renames are the cheapest and least risky step, so they go last despite being the most visible — semantics first, spelling last; a rename before the seams and policy are in place only decorates the leak.
4. **Anti-corruption layers go in during (not after) migration** — when an inner layer consumes a wire type, introduce the domain type + adapter-edge mapping while both shapes flow, migrate call sites, then delete the wire path; never a big-bang signature flip.
5. **State machines: locus first** — the current enforcement locus is declared and conformance-tested (ADR-30) *before* any transition logic is relocated; the conformance test is the safety net for the move.
6. **Compatibility, rollback, and topology isolation** — every step keeps the build green and behavior identical, checkpointed by arch-checks + the full test suite, and is revertible alone; anything touching a published contract or peer-visible identifier escalates out of migration into the contract-change process (ADR-32); module-topology changes (single-module ↔ workspace, ADR-24) are their own migration class, never combined with layer moves in one change.

Hexagonal-calibration note: no divergence. The strangler order works inward along the dependency rule — edges (composition, adapters, translation) before core (policy) — and the payoff Netflix reports for its hexagonal seams (swapping a data source in hours) is exactly what step 3(b)'s translation-seams-first ordering buys during a migration; Graça's boundary translation at both driving and driven adapters is what §4 installs while old and new shapes coexist.

---

## Dependency direction

### Service-internal

```
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

```
services/<service>/internal  → services/<service>/internal/contracts (service-scoped),
                               internal/contracts (cross-service), internal/kernel,
                               go-pkgs, external SDK (if used)
internal/contracts           → internal/kernel, go-pkgs
internal/kernel              → go-pkgs
go-pkgs                      → (stdlib only; ideally no third-party)
go-pkgs/infra                → stdlib + necessary third-party (default home for reusable infra)
external SDK repo            → (stdlib and third-party; never imports from this repo)
```

### Disallowed

- `<layer>` (`domain`, `ports`, `interactor`) importing any adapter folder — including a streaming server adapter (`grpc/`, `ws/`, `sse/`).
- `<layer>` (`domain`, `ports`, `interactor`) importing a **generated wire contract** (a versioned `internal/contracts/**/v<N>` package or any `*.pb.go`). Generated transport types are adapter-only (ADR-25); map at the adapter edge.
- One service's `internal/` importing another service's `internal/` — i.e. `services/<A>/internal` ⇸ `services/<B>/internal`. This includes service A importing service B's service-scoped `internal/contracts/`; genuinely shared contracts must be promoted to root `internal/contracts/` (ADR-21).
- Service-scoped `internal/contracts/` importing `domain/`, `interactor/`, any adapter, or `internal/kernel/` — transfer shapes use primitive/stdlib types only.
- `internal/kernel/` importing `internal/contracts/`.
- `go-pkgs/` importing anything from `internal/` or `services/`.
- An external SDK repo importing anything from this repo.
- Adapter A's package importing adapter B's package directly — cross-adapter coordination goes through `interactor/` or shared `ports/`.
- `cmd/` being imported by anything else.

---

## Forbidden folder names

`pkg`, `shared`, `common`, `lib`, `utils`, `application`, `infrastructure`, `interfaces`, `helpers`, `mapper`, `dto`, `gateway`, `workers`, `misc`.
