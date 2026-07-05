# Placement rules: contexts, versions, middleware, adapters, promotion

Read this file before placing, naming, or promoting source files, or adding an
adapter. Routing flowcharts, thresholds, and the dependency/forbidden-name
invariants live in [`SKILL.md`](../SKILL.md).

## Bounded context: suffix, then promote

Default in-folder suffix:

```text
domain/
  order.go
  product.go
interactor/
  interactor_order.go
  interactor_product.go
data_repositories/
  repository_order.go
  repository_product.go
```

`domain/` files take the bare context name — `domain/<context>.go`, no
`domain_` prefix. All other layers and adapters prefix the layer noun
(`interactor_`, `repository_`, `storage_`).

Promote to subfolder when one context reaches ≥10 files in that layer
(Counting rule, SKILL.md):

```text
interactor/
  order/interactor.go            # context suffix dropped
  order/<more files>.go
  product/interactor.go
```

**Forbidden:** combined-context suffix `<contextA>_<contextB>.go`
(e.g. `order_product.go`).

**Identifying a context:** a noun that owns its invariants and lifecycle. Two
candidates that always change in the same PR are one context. A use case that
writes the state of 2+ contexts → Step 0.

**Promotion mechanics:** promotion updates all import sites in the same change.
In a repo with external consumers, promoting an exported package changes import
paths — breaking change → Step 0. Promotion state is per-layer per-service;
mixed maturity across services (one promoted, another still suffixed) is
correct — do not align. Promoted package name = context (`package order`);
importers alias by layer when two layers expose the same context package
(`orderintr`, `orderrepo`).

## Use cases and coordinators (two inner layers)

`interactor/` holds **use cases only** — Clean Architecture interactors: the
application-specific business rules. A use case describes one business
process, orchestrates entities (`domain/`) and dependency-injected `ports/`
to fulfil it, and owns the decisions that process requires — one workflow
step, ~1–3 port calls, no spawned goroutines.
File: `interactor_<context>.go`.

Long-running or concurrent coordination lives in its own inner layer,
**`coordinator/`** — process managers: a loop, goroutines, mutexes, channels,
timers, or retries coordinating several ports (and use cases) over time
(scraping pipelines, schedulers, reconnect loops, a consumer's inner engine).
File: `<role>.go` — `pipeline.go`, `processor.go`, `scheduler.go`,
`reconnector.go` — **role-named, no layer prefix** (`scheduler.go`, never
`coordinator_scheduler.go` or `interactor_scheduler.go`), because it is named
for what it runs, not a CRUD context. Settle on one role-naming style per
service (do not call the same shape `pipeline.go` in one place and
`scrape_loop.go` in another).

```text
interactor/
  interactor_order.go      # use case
  interactor_payment.go    # use case
coordinator/
  scheduler.go             # process manager (a loop over seats/ports)
  reconnector.go           # process manager (session-lifetime loop)
```

Dependency direction: `cmd/` and inbound adapters start/call coordinators;
`coordinator/` may call `interactor/` use cases at its sequence points and
use `ports/`/`domain/` directly; `interactor/` never imports `coordinator/`.
`coordinator/` is application core, not an adapter: it owns no transport and
obeys the same import invariants as `interactor/` — no adapter imports, no
generated wire contracts (enforced by `arch-checks.sh`).

A coordinator's private helper state (a ledger, an emit sink, a drain gate)
lives beside it in `coordinator/` as an unexported type; it is not a use case
and gets no file in `interactor/`.

Both layers stay flat until the ≥10-file promotion threshold (counting rule,
SKILL.md). Migrating a service that kept process managers in `interactor/` is
a mechanical move (`interactor/scheduler.go` → `coordinator/scheduler.go`,
imports updated in the same change) — ordered per `migration.md`.
(ADR-34; supersedes ADR-24's two-shapes-one-folder rule.)

### Shim interactors: enrich or delete

A use-case interactor must own at least one of: a decision, an invariant
check, a composition of ≥2 port calls, or cross-cutting policy (retry budget,
ordering, idempotency). A one-line body delegating to a same-named port —
no validation, no derivation, no composition, no policy — is a **shim
interactor**; the workflow policy the layer exists to hold is usually leaking
into an adapter or a caller instead. Two resolutions; pick one:

- **Enrich** — move the policy currently living elsewhere (often in an
  adapter or a datastore procedure) into the interactor, so it earns its
  layer: validation, derivation, or composition around the port call.
- **Delete** — remove the shim and let the inbound adapter consume the port
  directly via the sanctioned adapter→port→adapter **mediation seam** ("Port
  quality", below).

Do not keep shims to satisfy the layer diagram — that is the **shim
interactor layer** anti-pattern (SKILL.md). Worked example with both
resolutions: "Shim interactor" in [`layout-examples.md`](layout-examples.md).

**Carve-out — datastore-procedure-centric services.** When a design
intentionally hosts workflow logic in the database (stored procedures own the
policy), thin interactors are the **expected** shape, not shims to enrich:
record that choice as the enforcement-locus decision instead of wrapping
every procedure in a pass-through — declaration and conformance requirements
in "State machines: one enforcement locus" (below).

## API versioning: suffix, then promote

```text
api/
  users_handler_v1.go
  users_handler_v2.go
```

Promote when one version reaches ≥5 files:

```text
api/
  v1/users_handler.go            # version suffix dropped
  v2/users_handler.go
```

## Middleware lives with its adapter

```text
api/
  middleware_auth.go
  middleware_logging.go
```

Promote when ≥4 middleware files for one adapter:

```text
api/
  middleware/
    auth.go                      # concern suffix dropped
    logging.go
```

**No top-level `middleware/` folder.**

## Outbound adapter rules

| Adapter              | Shape                                | File form (flat)                   | Promotion                                                                                                                                   |
| -------------------- | ------------------------------------ | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `data_repositories/` | schema-shaped (PG, Mongo, Redis, ES) | `repository_<context>.go`          | per-context subfolder at ≥10 files                                                                                                          |
| `storage/`           | blob-shaped (S3, GCS, local FS)      | `storage_<context>.go`             | per-context subfolder at ≥10 files                                                                                                          |
| `external_services/` | third-party APIs                     | `<subject>_<action>_<provider>.go` | `external_services/<provider>/` at ≥10 files, ≥3 provider-specific infra files, or distinct lifecycle — drop provider from filenames inside |
| `producer/`          | outbound events                      | `<subject>_<verb>_producer.go`     | per-context subfolder                                                                                                                       |

`data_repositories/` vs `storage/` split is **by data shape**, not SQL/NoSQL or
in-memory/persisted. Decision test: accessed through a query language, typed
fields, or indexes → `data_repositories/`; opaque bytes addressed by key/path →
`storage/`. Redis with hashes/sets/typed structures → `data_repositories/`;
Redis as byte-blob cache → `storage/`.

Distinct lifecycle is the **primary** promotion trigger; the file counts are a
secondary heuristic when no distinct lifecycle exists. Distinct lifecycle = the
provider owns a resource set up/torn down per call or per task (a browser
context, a connection pool, a subscription), or needs its own client/auth/session
init or its own retry/rate-limit infra files. A "provider-specific file" =
a non-test `.go` file only that provider needs.

## Business-rule placement: adapters decide nothing

An adapter may **observe, extract, encode, decode, transport, and persist**; it
may not **decide**. Operational test: if a rule answers "what is true about the
business object" or "what should happen next" (a status derivation, a
price/quantity policy, a credit movement, a retry disposition), it belongs in
`domain/` (pure rules), `interactor/` (use-case policy), or `coordinator/`
(long-running coordination policy) — even when its inputs come from
adapter-side mechanics.

The adapter returns raw signals: booleans, counts, raw strings, presence flags,
wire frames, storage rows. An inner layer interprets them. When mechanics and
interpretation are interleaved in one function, split at the signal: extraction
stays, interpretation moves. Sequencing that must interleave with transport I/O
may remain adapter-side only if each decision point delegates to an inner-layer
function.

Comment examples for classification:

```go
// Status-derivation ladder over extracted flags/raw strings -> domain.
// Adapter: ExtractAvailabilitySignals(...)
// Domain:  ClassifyAvailability(signals)

// Credit release on settlement inside a stream server -> interactor method.
// Adapter keeps recv/send ordering, then calls interactor.SettleAndReleaseCredit(...).

// Selector table, CSS/XPath strings, field-presence probes -> adapter.
// They describe how to observe an external surface, not what the observation means.

// Retry/backoff formula for a domain retry disposition -> domain.
// Transport reconnect timing may stay adapter-local; business retry eligibility does not.
```

### Wire models do not belong in domain/

A struct whose field tags, envelope/version/status constants, or shape mirror
a published request/response schema does not belong in `domain/`, even if
only one endpoint uses it. It is an adapter-local DTO (R-21, adapter-local
tier); the handler maps domain values into it. **Tell: changing a response
contract would edit `domain/`** — if renaming or reshaping an outbound
response field forces a `domain/` edit, the domain type is a wire model, and
the response shape belongs to the adapter (translation) or the appropriate
`contracts/` tier. That is the **wire model in domain** anti-pattern
(SKILL.md).

## State machines: one enforcement locus

Every state machine has exactly **one declared enforcement locus** — the place
where an illegal transition actually fails. Two sanctioned loci; pick one,
never both, never neither:

- **Domain-enforced** — a domain type (`Transition`, `CanTransitionTo`)
  validates transitions and is invoked on every mutation path; the datastore
  stores, never judges.
- **Datastore-enforced** — a datastore guard (stored procedure, conditional
  update, constraint) rejects illegal moves; domain code treats the store's
  verdict as authoritative.

**Declaration.** The chosen locus is declared where the state machine is
defined: a comment atop the transition table plus a line in the owning service
docs. If the locus is the datastore, say so explicitly — the in-service
transition table is then a **conformance oracle**, not the enforcer.

**Conformance oracle.** Whichever locus is chosen, a test (or check) MUST
exercise the declared transition table against the enforcing implementation —
drive every legal and illegal move and assert agreement — so the declaration
cannot rot into decoration. When the locus is the datastore, the test drives
the datastore guards through the table's moves. A transition API
(`Transition`, `CanTransitionTo`) with zero non-test call sites and no
conformance test is forbidden — that is the **decorative state machine**
anti-pattern (SKILL.md).

**Conformance-test naming convention (check exemption).** A conformance test
is a `_test.go` file explicitly named `*_conformance_test.go`, living beside
the transition table it exercises. `scripts/arch-checks.sh` flags
`decorative-state-machine` (report-only) when a `domain/` dir defines
`Transition`/`CanTransitionTo` with no non-test call sites outside `domain/`
(self-calls within any `domain/` dir are the pattern itself, not coverage);
calls from a `*_conformance_test.go` file count as coverage for that check —
an ordinarily named `_test.go` does not.

## Inbound adapter rules

| Adapter             | Files                          | Notes                                                     |
| ------------------- | ------------------------------ | -------------------------------------------------------- |
| `api/`              | `<resource>_handler_v<N>.go`   | promote to `api/v<N>/` at ≥5 files                       |
| `consumer/`         | `<subject>_<verb>_consumer.go` | events + polling go here                                 |
| `cli/`              | `<action>_command.go`          | CLI subcommands, parallel to `api/`/`consumer/`          |
| `grpc/`/`ws/`/`sse/`| `server.go` (+ split, above)   | streaming server; connection-scoped state, see structure |

`api/` is HTTP only. A **streaming server** — gRPC bidi, WebSocket, SSE — is a
first-class inbound adapter kind, named by transport: `grpc/`, `ws/`, `sse/`
(GraphQL → `graphql/`). It does NOT go to Step 0. Only a transport not in this
list is a genuinely new kind → Step 0.

### Streaming adapter structure

A streaming server owns **connection-scoped mutable state**: a per-connection
session object and a registry of live connections. Start flat
(`grpc/server.go`); promote `grpc/` to a split package when one non-test file
would exceed ~400 LOC OR a second responsibility appears, whichever comes first.
Canonical split:

```text
grpc/
  server.go             # transport setup, keepalive, serve/shutdown
  <svc>_server.go       # the stream handler: recv loop, frame routing
  session.go            # connection-scoped state + the live-connection registry
  translation.go        # wire <-> domain mapping (see "Translation / ACL")
  <name>_reclaim.go     # reconciler(s) coupled to the registry (see below)
```

The per-connection session object MAY hold a domain entity (a credit ledger),
mutate it as instructed, and implement a driven port (a push/sink the interactor
calls) — that is expected for a streaming server, not a layering violation. It
may not decide **when or why** the entity moves. Decisions such as "release on
settlement", "reserve on reattach", or "which lifecycle branch on connection
loss" are interactor policy — expose them as interactor methods the adapter
calls at its sequence points. The adapter keeps the ordering; the interactor
keeps the policy. A reconciler repairing adapter-owned registry state may decide
over that state, but any durable transition it triggers goes through an
interactor. The generated wire types stay inside `grpc/` (or
`internal/contracts/**/v<N>`); never let them reach `ports/`, `interactor/`, or
`domain/`.

A stream **client** to a single upstream is an outbound adapter: `grpc/client.go`
(or `external_services/<provider>/` when it is one provider among several).

**Single binary per service**: `cmd/main.go` only. All subcommands (server,
scheduled jobs, one-off tasks, Go-runtime migrations) live inside `cli/`.
Cobra is the default for new services; if the service already uses another CLI
framework, keep it — folder rules unchanged. `cmd/` is wiring only.

**Background work routing**: events → `consumer/`. Independent scheduled job →
CLI subcommand under `cli/`, triggered externally. Polling → `consumer/`. A
**reconciler/sweeper tied to one adapter's state** — a connection registry, a
lease table, a cache it must read and repair (grace-timer reclaim, restart
replay, expiry GC) — lives **in that adapter's package** (`grpc/<name>_reclaim.go`,
`grpc/sweeper.go`) and is started from `cmd/`. Pushing it to `cli/` or
`consumer/` would sever it from the state it repairs and force that state to leak
outward. **No `workers/` folder.**

## Ports, tests, mocks

`ports/` file form: `<context>_port.go`, one port per outbound dependency the
interactor uses; no port without an interactor consumer.

**Port shapes.** A port may be an interface (multi-method) **or** a `func` type
for a single-method seam (`type Emit func(*Frame) error`). Two roles exist:

- **Query/command ports** — the interactor calls an *outbound* adapter
  (`WorkClaimer`, `EventApplier`). The common case.
- **Push/sink/trigger ports** — the interactor pushes through a sink that a
  *driving* (inbound) adapter implements (a stream server's per-connection
  `TaskSink`, an `Emit`, a `DispatchTrigger`). A driving adapter implementing a
  port is allowed and expected for streaming servers — it keeps the wire types
  out of the interactor. ("No ports for inbound adapters" applies only to
  request/response inbound handlers, not to push/sink seams.)

**File layout.** One port per file as `<context>_port.go`, OR group a small,
cohesive set by the adapter they serve as `<adapter>.go` (e.g. `coordination.go`
holding the stream + sink seams). Pick one convention per service; do not mix.

**Contracts.** A port speaks domain types. It MUST NOT import a generated wire
contract (versioned `internal/contracts/**/v<N>`, any `*.pb.go`) — that is
adapter-only (SKILL.md forbidden-imports). Translate at the adapter boundary.

### Port quality

"Speaks domain types" is necessary but not sufficient. Four rules (ADR-31):

- **Capability shape.** Ports are shaped by the *capability the interactor
  needs*, not by the adapter's surface. A port whose method set mirrors a
  repository's query/procedure inventory one-to-one, or whose doc comments
  name the persistence technology, is an adapter interface promoted inward —
  regroup by capability and describe behavior ("atomically claims the next
  unit of work"), not mechanism.
- **No serialization tags.** No serialization metadata in `ports/` or
  `domain/`: a struct with `db:`/`bson:`/wire tags is an adapter row/DTO —
  keep it in the adapter and map. `json:` tags are permitted only in
  adapter-local DTOs and `contracts/` packages. `scripts/arch-checks.sh`
  flags `db:`/`bson:` tags under `ports/`/`domain/` (`tags-in-inner-layers`).
- **Mediation erratum.** "No port without an interactor consumer" applies to
  *outbound capability* ports only; the earlier claim that inbound adapters
  never need ports is wrong. Two other seams are sanctioned: push/sink/trigger
  ports implemented by a *driving* adapter (Port shapes, above), and
  **adapter→port→adapter mediation** — an inbound handler invokes a capability
  implemented by another adapter, with no business policy in between.
- **Consumer-owned interface.** A seam between two interactors is not a port.
  When one interactor needs another, the **consumer** declares the small
  (typically unexported) interface it needs, beside itself in `interactor/`;
  the provider satisfies it. No shared fat interface.

### Translation / Anti-Corruption Layer (ACL)

Domain↔external-wire mapping is an adapter responsibility — keep it beside the
adapter that owns the wire format, never in a top-level `mapper/` or `dto/`
(both forbidden):

- Small → inline in the adapter, or `<adapter>_translation.go` next to it.
- Large (>~200 LOC or >2 files) → a named cluster inside the adapter's promoted
  folder (`external_services/<provider>/payload.go`, `payload_attributes.go`, or
  `grpc/translation.go`).

The ACL is **pure** — wire/domain in, the other out, no I/O. The HTTP/stream call
lives in a sibling client file. Forbidden `mapper/` → an adapter-local
translation file; forbidden `dto/` → the wire structs live in the adapter (or
`internal/contracts/` when shared by 2+ services).

### Contracts on the consumer side

The adapter-only rule for generated contracts binds **each service in each
role**. A service *consuming* another service's versioned wire contract treats
it exactly like any external wire format: translate at the adapter edge,
domain types inward. The consumer owns a domain vocabulary for every frame it
sends or receives and translates in its stream-client adapter
(`grpc/translation.go` beside `grpc/client.go`) — exactly mirroring the
producer's server-side translation. Worked example (incl. the sealed domain
event sum and the de-wired port signature): "Streaming client" in
[`layout-examples.md`](layout-examples.md).

Tells that the consumer-side seam is missing:

- port signatures naming generated types;
- frame constructors in `interactor/`;
- a wire enum compared or switched on outside the adapter;
- a second outbound adapter importing another service's contract because port
  signatures force it through.

`scripts/arch-checks.sh` reports `inner-imports-contracts` grouped per service
and names the guilty layer (`ports`/`interactor`/`domain`), so asymmetric
drift — one service clean, its sibling colonized — is legible in the output.

`_test.go` lives next to the code under test; `testdata/` allowed anywhere (Go
convention). Mocks of ports: `ports/<context>_port_mock.go`. Test and generated
files never count toward promotion thresholds.
